"""Terminal checks for #9, run by `just test-web` inside the dnslab-web
container (it has the websockets client, the Docker SDK and the socket):

    docker exec -i -e PW_GROUP01=… -e PW_INSTRUCTOR=… dnslab-web python - < web/tests/terminal_check.py

Needs nodes group01-0..2 and group02-0..2 running. Prints "ok …" lines
and exits non-zero on the first failure.
"""

import http.cookiejar
import json
import os
import re
import sys
import threading
import time
import urllib.parse
import urllib.request

import docker
from websockets.sync.client import connect

BASE = "http://127.0.0.1:8000"
WS = "ws://127.0.0.1:8000"
docker_api = docker.from_env().api


def ok(msg):
    print(f"ok   {msg}", flush=True)


def fail(msg):
    print(f"FAIL {msg}", flush=True)
    sys.exit(1)


def login(user, password):
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    data = urllib.parse.urlencode({"username": user, "password": password}).encode()
    opener.open(f"{BASE}/login", data)
    return "; ".join(f"{c.name}={c.value}" for c in jar)


def open_term(cookie, node, origin=BASE):
    return connect(f"{WS}/ws/terminal/{node}", origin=origin,
                   additional_headers={"Cookie": cookie}, open_timeout=10)


def send(ws, text):
    ws.send(text.encode())


def read_until(ws, pattern, timeout=10):
    """Read output until ``pattern`` (bytes regex) matches; return the text."""
    buf = b""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            msg = ws.recv(timeout=max(0.05, deadline - time.monotonic()))
        except TimeoutError:
            break
        buf += msg if isinstance(msg, bytes) else msg.encode()
        if re.search(pattern, buf):
            return buf.decode("utf-8", errors="replace")
    raise AssertionError(f"timed out waiting for {pattern!r}; got {buf[-300:]!r}")


def node_exec(node, cmd):
    ex = docker_api.exec_create(node, ["sh", "-c", cmd])
    return docker_api.exec_start(ex["Id"]).decode()


g1 = login("group01", os.environ["PW_GROUP01"])

# Root shell on the right node, PID mark stripped
with open_term(g1, "group01-0") as ws:
    send(ws, "echo user=$(id -un) host=$(hostname) cwd=$PWD\r")
    out = read_until(ws, rb"user=\w+ host=[\w-]+ cwd=\S+")
    if "user=root host=group01-0 cwd=/root" not in out:
        fail(f"unexpected shell: {out[-200:]!r}")
    if "dnslab-pid" in out:
        fail("PID mark leaked into the terminal")
    ok("terminal opens a root login shell in group01-0 (no PID mark in the output)")

    send(ws, "echo ñandú-€-ü\r")
    read_until(ws, "ñandú-€-ü\r\n".encode())
    ok("UTF-8 (ñ, ú, €, ü) round-trips")

    ws.send(json.dumps({"type": "resize", "cols": 132, "rows": 43}))
    send(ws, "stty size\r")
    read_until(ws, rb"\r43 132\r\n")
    ok("resize reaches the shell (stty size: 43 132)")

    send(ws, "sleep 100; echo SLEPT\r")
    time.sleep(0.5)
    send(ws, "\x03")
    send(ws, "echo AFTER-CTRL-C\r")
    out = read_until(ws, rb"\rAFTER-CTRL-C\r\n", timeout=5)
    if re.search(r"\rSLEPT\r\n", out):  # output line, not the echoed command
        fail("Ctrl-C didn't interrupt sleep")
    ok("Ctrl-C interrupts a running command")

    send(ws, "journalctl -u named -f --no-pager -n 2\r")
    read_until(ws, rb"named\[\d+\]")
    send(ws, "\x03")
    send(ws, "echo AFTER-JOURNAL\r")
    read_until(ws, rb"\rAFTER-JOURNAL\r\n")
    ok("journalctl -f streams, and Ctrl-C ends it")

# Closing the tab ends the shell and its jobs
with open_term(g1, "group01-1") as ws:
    send(ws, "sleep 4242 & echo BASHPID=$$\r")
    pid = re.search(r"BASHPID=(\d+)", read_until(ws, rb"BASHPID=\d+")).group(1)
time.sleep(3)
# "[s]leep" so the check's own command line doesn't match itself
left = node_exec("group01-1", f"ps -o pid=,args= -p {pid}; ps -eo pid=,args= | grep '[s]leep 4242' || true").strip()
if left:
    fail(f"processes left after closing the terminal: {left!r}")
ok("closing the terminal ends the shell and its background jobs")

# Authorization
for node, cookie, origin, why in [
    ("group02-0", g1, BASE, "another group's node"),
    ("dnslab-master", g1, BASE, "the master"),
    ("dnslab-web", g1, BASE, "the web container"),
    ("group01-0", "", BASE, "no session"),
    ("group01-0", g1, "https://evil.example", "a foreign Origin"),
]:
    try:
        with open_term(cookie, node, origin=origin) as ws:
            ws.recv(timeout=2)
        fail(f"terminal opened for {why}")
    except Exception as e:  # rejected handshake or immediate close
        if "terminal opened" in str(e):
            raise
ok("terminal refused for another group's node, the master, the web container, no session, foreign Origin")

inst = login("instructor", os.environ["PW_INSTRUCTOR"])
with open_term(inst, "dnslab-master") as ws:
    send(ws, "hostname\r")
    read_until(ws, rb"\rdnslab-master\r\n")
ok("instructor gets a terminal on the master")

# 18 terminals at once: 3 on each of the six nodes, each round trip timed
nodes = [f"group0{g}-{n}" for g in (1, 2) for n in (0, 1, 2)]
cookies = {"group01": g1, "group02": login("group02", os.environ["PW_GROUP02"])}
results, errors = [], []


def session(node, i):
    try:
        with open_term(cookies[node[:7]], node) as ws:
            read_until(ws, rb"[#$] $")  # prompt
            for k in range(5):
                t0 = time.monotonic()
                send(ws, f"echo rt-{i}-{k}\r")
                read_until(ws, f"\rrt-{i}-{k}\r\n".encode())
                results.append(time.monotonic() - t0)
    except Exception as e:  # noqa: BLE001
        errors.append(f"{node}: {e}")


threads = [threading.Thread(target=session, args=(node, i)) for i, node in enumerate(nodes * 3)]
for t in threads:
    t.start()
for t in threads:
    t.join()
if errors:
    fail(f"concurrent terminals failed: {errors[:3]}")
results.sort()
p95 = results[int(len(results) * 0.95) - 1]
if p95 > 0.5:
    fail(f"18 concurrent terminals too slow: p95 round trip {p95 * 1000:.0f} ms")
ok(f"18 concurrent terminals: {len(results)} round trips, p95 {p95 * 1000:.0f} ms, max {results[-1] * 1000:.0f} ms")
print("all terminal checks passed")
