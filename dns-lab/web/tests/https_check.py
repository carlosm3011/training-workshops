"""HTTPS checks for #20, run by `just test-https` in a throwaway container
on the dns-lab-front network, with the lab's host name pointing at Caddy
and the self-signed certificate mounted at /ca.pem:

    docker run --rm -i --network dns-lab-front --add-host HOST:CADDY_IP \
        -v …/cert.pem:/ca.pem:ro -e DNSLAB_HOST=HOST -e PW_GROUP01=… dnslab-web python - < web/tests/https_check.py

Logs in over HTTPS, then opens a terminal over wss:// on group01-0.
Prints "ok …" lines and exits non-zero on the first failure.
"""

import http.cookiejar
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request

from websockets.sync.client import connect

HOST = os.environ["DNSLAB_HOST"]
BASE = f"https://{HOST}"
tls = ssl.create_default_context(cafile="/ca.pem")  # verifies the self-signed certificate


def ok(msg):
    print(f"ok   {msg}", flush=True)


def fail(msg):
    print(f"FAIL {msg}", flush=True)
    sys.exit(1)


jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar),
                                     urllib.request.HTTPSHandler(context=tls))
data = urllib.parse.urlencode({"username": "group01", "password": os.environ["PW_GROUP01"]}).encode()
opener.open(f"{BASE}/login", data)
cookie = "; ".join(f"{c.name}={c.value}" for c in jar)
if not cookie:
    fail("no session cookie after logging in over HTTPS")

with connect(f"wss://{HOST}/ws/terminal/group01-0", origin=BASE, ssl=tls,
             additional_headers={"Cookie": cookie}, open_timeout=10) as ws:
    ws.send(b"echo host=$(hostname)\r")
    buf, deadline = b"", time.monotonic() + 10
    while not re.search(rb"\rhost=group01-0\r\n", buf):
        if time.monotonic() > deadline:
            fail(f"no shell output over wss: {buf[-200:]!r}")
        buf += ws.recv(timeout=max(0.05, deadline - time.monotonic()))
ok("terminal over wss:// through Caddy: shell on group01-0")
