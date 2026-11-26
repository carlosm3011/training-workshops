# Web page

The lab's web page, `dnslab-web`: students log in, see their nodes, open terminals on them, and start, stop or restart them, and publish their zone's DS in `lab.`. The UI is in Spanish, like the course.

## What it does

- **Login** with the passwords in `state/credentials`. Each group (`group01`, `group02` …) sees only its own three nodes; `instructor` sees every node and the master. Sessions are signed cookies (SameSite=strict) that last 12 hours; **Salir** ends them. Over HTTPS the cookie is also marked Secure (a small middleware adds the flag when Caddy's `X-Forwarded-Proto` says `https`), so the browser never sends it in the clear. The loopback port stays plain HTTP, for the tests and SSH tunnels.
- **Node list:** name, state, IPv4 and IPv6 on `dns-lab`, and time since start. The page polls every 2 s, so changes show without reloading. A stopped container has no addresses, so those columns are empty while it's down.
- **Iniciar / Detener / Reiniciar** run `docker start`, `stop` and `restart` on the container. A config change inside a node still needs `rndc reload` or `systemctl restart bind9`; the buttons are for whole-container restarts and for recovering a broken node.

## Terminals

Clicking a running node's name opens `/terminal/<name>` in a new tab: a root login shell (`bash -l` in `/root`) in that node, rendered with [xterm.js](https://xtermjs.org/) 5.5. The page's websocket, `/ws/terminal/<name>`, is bridged to `docker exec`:

- Binary frames carry terminal bytes both ways (UTF-8); text frames carry JSON control messages from the browser, so far only `{"type": "resize", "cols": …, "rows": …}`. The page refits the terminal when the window changes size and tells the shell, so vim, less and `journalctl -f` lay out correctly.
- The websocket needs the same session as the page, the same per-node authorization, and an `Origin` matching the host, so a page on another site can't open a shell even if the browser sent the cookie.
- **Closing the tab ends the shell.** Docker keeps an exec'd process running when its connection drops, which would leave shells and their jobs behind. So the shell first reports its PID in an OSC escape sequence (`ESC ] 777;dnslab-pid;<pid> BEL`), which the bridge strips from the output. When the websocket closes, the bridge sends that PID SIGHUP (bash passes it on to its jobs), then SIGKILL a second later if it's still there.
- xterm.js is fetched at image build time from jsDelivr, pinned by SHA-256 (`ADD --checksum` in the Dockerfile), and served by the app, so students' browsers only need to reach the lab.

## DS form

Below the node list, **DS en lab.** works like a registrar's panel for `groupNN.lab.`: it lists the DS records `lab.` serves for the group's zone, takes new ones, and removes them one at a time. The instructor picks any group from a menu.

- **Publishing:** paste the line `dnssec-dsfromkey` prints (`group01.lab. IN DS 31028 13 2 3F8A…`); a TTL, several lines, and `;` comments are fine. The app parses each line with dnspython and refuses, with a message in Spanish, anything whose owner isn't the group's own zone, that isn't a DS, or whose digest doesn't parse or doesn't match its type's length (types 1, 2 and 4). All lines are applied or none are. A DS that is already published is left alone.
- **Applying:** the app runs `nsupdate -k /etc/bind/dnslab-webapp.key` inside the master (`docker exec`, the script passed as an argument, not through a shell). The master's `update-policy` lets that key change only DS records at `groupNN.lab.` names, a second fence behind the app's own check. Records are added with lab.'s TTL, 60 s.
- **Seeing the result at once:** after each change the app runs `rndc flushtree groupNN.lab. resolver` on the master, so the lab's resolver drops what it cached under the zone. Otherwise a `dig` just before publishing would keep the zone insecure for up to a minute.
- **API:** `GET /api/ds/<group>` lists, `POST /api/ds/<group>` with `{"text": "…"}` publishes, `POST /api/ds/<group>/delete` with `{"record": "<key tag> <alg> <type> <digest>"}` removes. A group may only use its own name. Requests are JSON, so a page on another site can't post them without a CORS preflight the app never grants, on top of the SameSite cookie.

## Authorization

The browser only ever sends a container name; the server decides. Lab containers carry labels set by the justfile:

| Label | Values |
|---|---|
| `dnslab.role` | `master`, `node`, `web` |
| `dnslab.group` | `groupNN`, on nodes |

A group may act only on containers with `dnslab.role=node` and its own `dnslab.group`; the instructor on any `node` or `master`. Nothing else on the host is reachable through the app, the web container itself included. Unknown and forbidden names both get 403, so a group can't probe what exists.

## Running it

`just build` builds the image (`python:3.12-slim`, FastAPI, the Docker SDK). The justfile's `_web` recipe starts it:

```sh
docker run -d --name dnslab-web --restart unless-stopped \
  --network dns-lab-front -p 127.0.0.1:8080:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v …/state/credentials:/run/dnslab/credentials:ro \
  -v …/state/web/session-secret:/run/dnslab/session-secret:ro \
  -e DNSLAB_CREDENTIALS=/run/dnslab/credentials \
  -e DNSLAB_SESSION_SECRET=/run/dnslab/session-secret \
  -e DNSLAB_NETWORK=dns-lab \
  --label dnslab.role=web dnslab-web
```

Students reach it through Caddy at `https://<host>/` (see `../caddy/Caddyfile` and the main README). The app itself listens on the host's loopback and on `dns-lab-front`, where Caddy proxies to `dnslab-web:8000`. For a quick look without Caddy, use an SSH tunnel:

```sh
ssh -N -L 8080:127.0.0.1:8080 kobe.labs.lacnic.net    # then open http://127.0.0.1:8080
```

**The Docker socket is root on the host.** Whoever controls this app controls Docker, so the app is deliberately small: it only lists, starts, stops and restarts labelled lab containers, opens shells in them and changes DS records in `lab.`, behind the login. Never publish it without Caddy's TLS in front.

## Credentials

`state/credentials`, generated by the justfile (`_credentials`, called by `init` in #5) and printed by `just credentials`:

```
# Lab web page logins: name password
instructor xxxxxxxxxxxx
group01 xxxxxxxxxxxx
…
```

Passwords are 12 random characters from an alphabet without look-alikes (no `l`, `o`, `0`, `1`), kept in clear text so the instructor can hand them out. The file is mode 600. The app reads it at startup, so after editing it, restart `dnslab-web`.

## Checking it

`just test-web` brings up the master, groups 1–2 and the web page, then checks login, what each user sees, the buttons, authorization and logout through the same HTTP API the page uses, and tears everything down. The DS checks sign `group01.lab.` on `group01-0` (with `-1` and `-2` as secondaries), then check:
- before publishing, `delv-lab` doesn't validate the zone;
- rejections leave `lab.` unchanged: another group's name or form, a malformed or short digest, NS and A records, garbage;
- publishing `dnssec-dsfromkey`'s line shows in `dig @10.53.0.1 group01.lab. DS +norec`, and then `delv-lab` reports the zone fully validated;
- duplicates, a second DS, and removing one or both;
- the instructor publishing for another group.

It then runs `tests/terminal_check.py` inside the web container, a websocket client that checks the terminals:
- root shell on the right node, with no PID mark in the output;
- UTF-8, resize and Ctrl-C (including ending `journalctl -f`);
- closing the terminal ends the shell and its jobs;
- refusals: another group's node, the master, the web container, no session, a foreign Origin;
- the instructor gets a shell on the master;
- 18 terminals at once, with round-trip times.
