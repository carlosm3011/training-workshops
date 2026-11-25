"""The lab web page: login, the node list, and container controls.

A group logs in and sees only its own three nodes; the instructor sees
every node and the master. All container access goes through
``allowed()``: the browser only ever names a container, and the server
decides whether this session may touch it.

Configuration (environment, set by the justfile):
  DNSLAB_CREDENTIALS     path to the credentials file: one "name password"
                         per line, names "instructor" and "groupNN"
  DNSLAB_SESSION_SECRET  path to a file holding the session-signing secret
  DNSLAB_NETWORK         Docker network whose addresses are shown (dns-lab)
"""

import asyncio
import json
import os
import re
import secrets
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

import docker
from docker.errors import NotFound
from fastapi import FastAPI, Form, HTTPException, Request, WebSocket
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware

HERE = Path(__file__).parent
NETWORK = os.environ.get("DNSLAB_NETWORK", "dns-lab")
GROUP_RE = re.compile(r"^group\d{2}$")
ACTIONS = {"start", "stop", "restart"}


def load_credentials(path: str) -> dict[str, str]:
    creds = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, password = line.split(None, 1)
        if name == "instructor" or GROUP_RE.match(name):
            creds[name] = password
    return creds


CREDENTIALS = load_credentials(os.environ["DNSLAB_CREDENTIALS"])
SECRET = Path(os.environ["DNSLAB_SESSION_SECRET"]).read_text().strip()

client = docker.from_env()
app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
# SameSite=strict: a page on another site can't make a logged-in browser
# start or stop containers.
app.add_middleware(SessionMiddleware, secret_key=SECRET, same_site="strict",
                   https_only=False, max_age=12 * 3600)
app.mount("/static", StaticFiles(directory=HERE / "static"), name="static")
templates = Jinja2Templates(directory=HERE / "templates")


def current_user(request: Request) -> str | None:
    user = request.session.get("user")
    return user if user in CREDENTIALS else None


def require_user(request: Request) -> str:
    user = current_user(request)
    if user is None:
        raise HTTPException(status_code=401, detail="not logged in")
    return user


def lab_containers():
    """Every container the lab created (labels set by the justfile)."""
    return client.containers.list(all=True, filters={"label": "dnslab.role"})


def allowed(user: str, container) -> bool:
    labels = container.labels
    role = labels.get("dnslab.role")
    if user == "instructor":
        return role in ("node", "master")
    return role == "node" and labels.get("dnslab.group") == user


def describe(container) -> dict:
    attrs = container.attrs
    net = attrs["NetworkSettings"]["Networks"].get(NETWORK, {})
    state = attrs["State"]
    started = None
    if state.get("Running"):
        # Docker gives nanoseconds ("…T19:44:03.123456789Z"); seconds will do.
        started = datetime.strptime(state["StartedAt"][:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)
    return {
        "name": container.name,
        "role": container.labels.get("dnslab.role"),
        "group": container.labels.get("dnslab.group"),
        "status": state.get("Status"),
        "ipv4": net.get("IPAddress") or "",
        "ipv6": net.get("GlobalIPv6Address") or "",
        "uptime": int((datetime.now(timezone.utc) - started).total_seconds()) if started else None,
    }


def get_allowed(user: str, name: str):
    """The container called ``name`` if this user may touch it; 403 otherwise.
    Unknown and forbidden names get the same answer, so a group can't probe
    which containers exist."""
    try:
        container = client.containers.get(name)
    except NotFound:
        container = None
    if container is None or not allowed(user, container):
        raise HTTPException(status_code=403, detail="forbidden")
    return container


@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    user = current_user(request)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    return templates.TemplateResponse(request, "index.html", {"user": user})


@app.get("/login", response_class=HTMLResponse)
def login_form(request: Request):
    return templates.TemplateResponse(request, "login.html", {"error": None})


@app.post("/login")
def login(request: Request, username: str = Form(...), password: str = Form(...)):
    expected = CREDENTIALS.get(username.strip())
    # Compare against a dummy for unknown users so timing doesn't reveal names.
    ok = secrets.compare_digest(password.encode(), (expected or secrets.token_hex(16)).encode())
    if expected is None or not ok:
        return templates.TemplateResponse(
            request, "login.html", {"error": "Usuario o contraseña incorrectos."}, status_code=401)
    request.session.clear()
    request.session["user"] = username.strip()
    return RedirectResponse("/", status_code=303)


@app.post("/logout")
def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/login", status_code=303)


@app.get("/api/nodes")
def api_nodes(request: Request):
    user = require_user(request)
    nodes = [describe(c) for c in lab_containers() if allowed(user, c)]
    # Master first, then nodes in name order.
    nodes.sort(key=lambda n: (n["role"] != "master", n["name"]))
    return {"user": user, "nodes": nodes}


@app.post("/api/nodes/{name}/{action}")
def api_action(request: Request, name: str, action: str):
    user = require_user(request)
    if action not in ACTIONS:
        raise HTTPException(status_code=404, detail="unknown action")
    container = get_allowed(user, name)
    if action == "start":
        container.start()
    elif action == "stop":
        container.stop(timeout=10)
    else:
        container.restart(timeout=10)
    container.reload()
    return JSONResponse(describe(container))


# --- Terminals ---------------------------------------------------------------
#
# /terminal/<name> is an xterm.js page; its websocket, /ws/terminal/<name>,
# is bridged to `docker exec -it <name> bash -l`. Binary frames carry
# terminal bytes both ways; text frames carry JSON control messages from
# the browser ({"type": "resize", "cols": …, "rows": …}).
#
# Docker keeps an exec'd process running when its connection closes, so a
# closed tab would leave the shell and its jobs behind. The shell therefore
# starts by reporting its PID in an OSC escape sequence the bridge strips
# from the output, and the bridge hangs it up when the websocket closes.

PID_MARK = re.compile(rb"\x1b\]777;dnslab-pid;(\d+)\x07")
SHELL = ["bash", "-c", r"printf '\033]777;dnslab-pid;%s\007' $$; exec bash -l"]


@app.get("/terminal/{name}", response_class=HTMLResponse)
def terminal_page(request: Request, name: str):
    user = current_user(request)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    get_allowed(user, name)
    return templates.TemplateResponse(request, "terminal.html", {"name": name})


def same_origin(ws: WebSocket) -> bool:
    """Refuse websockets opened by pages on other sites (cross-site
    websocket hijacking); the SameSite cookie is the first line."""
    origin = ws.headers.get("origin")
    return origin is not None and urlsplit(origin).netloc == ws.headers.get("host")


def hang_up(container, pid: int) -> None:
    """SIGHUP the shell (bash passes it on to its jobs), SIGKILL if it lingers."""
    ex = client.api.exec_create(container.id, ["sh", "-c",
        f"kill -HUP {pid} 2>/dev/null || exit 0; sleep 1; kill -KILL {pid} 2>/dev/null; true"])
    client.api.exec_start(ex["Id"])


@app.websocket("/ws/terminal/{name}")
async def terminal_ws(ws: WebSocket, name: str):
    user = ws.session.get("user")
    if user not in CREDENTIALS or not same_origin(ws):
        await ws.close(code=4401)
        return
    try:
        container = await asyncio.to_thread(get_allowed, user, name)
    except HTTPException:
        await ws.close(code=4403)
        return
    await ws.accept()

    api = client.api
    ex = await asyncio.to_thread(api.exec_create, container.id, SHELL, tty=True, stdin=True,
                                 workdir="/root", environment={"TERM": "xterm-256color"})
    conn = await asyncio.to_thread(api.exec_start, ex["Id"], tty=True, socket=True)
    sock = conn._sock
    sock.setblocking(False)
    loop = asyncio.get_running_loop()
    pid = None

    async def container_to_browser():
        nonlocal pid
        head = b""  # output held back until the PID mark has been stripped
        while data := await loop.sock_recv(sock, 65536):
            if pid is None:
                head += data
                if m := PID_MARK.search(head):
                    pid, data = int(m.group(1)), head[:m.start()] + head[m.end():]
                elif len(head) < 512:
                    continue
                else:  # no mark: send everything, give up on hanging up
                    pid, data = 0, head
            if data:
                await ws.send_bytes(data)

    async def browser_to_container():
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                return
            if msg.get("bytes"):
                await loop.sock_sendall(sock, msg["bytes"])
            elif msg.get("text"):
                ctl = json.loads(msg["text"])
                if ctl.get("type") == "resize":
                    cols, rows = int(ctl["cols"]), int(ctl["rows"])
                    if 0 < cols <= 1000 and 0 < rows <= 1000:
                        await asyncio.to_thread(api.exec_resize, ex["Id"], height=rows, width=cols)

    tasks = [asyncio.create_task(container_to_browser()), asyncio.create_task(browser_to_container())]
    try:
        await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    finally:
        for t in tasks:
            t.cancel()
        sock.close()
        if pid:
            await asyncio.to_thread(hang_up, container, pid)
        try:
            await ws.close()
        except RuntimeError:
            pass  # already closed by the browser
