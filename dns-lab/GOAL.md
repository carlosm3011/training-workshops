# DNS Lab

## Goal

A hands-on lab environment for the "DNS y DNSSEC para Operadores" course (`../dns-dnssec-for-operators/`). Each group of students gets its own containers running authoritative DNS software (BIND to start with), reachable from a web page, so the course's exercises can be done for real: setting up primary and secondary servers, signing a zone with KASP, publishing a DS in a parent zone, validating, troubleshooting, and running a hidden signer.

## Requirements

- **Nodes.** Students work on containers named `groupNN-0`, `groupNN-1` and `groupNN-2`: three per group (`group01-0` … `group06-2` by default).
- **Size.** The number of groups is a parameter of each environment. Default: 6 groups, i.e. 18 nodes.
- **Network.** All containers are attached to one Docker network called `dns-lab`.
- **Config on the host.** Each container has its own bind mount, named after the container, holding its BIND configuration and data, so it survives restarts and can be backed up.
- **Master.** One special container, the master, also runs DNS software and is attached to `dns-lab`, but it is the only one also connected to the Internet. Every other container reaches the Internet through it.
- **Web page.** A lab page lists the running containers. Clicking one opens a web terminal on it in a new tab. Each container has Start, Stop and Restart buttons, so students can make the DNS software pick up configuration changes or recover a broken node.
- **Lifecycle.** A justfile initializes a new environment, removes an environment completely, and backs up the configuration students produced.
- **Host.** The lab runs on a host with Docker preinstalled. The host is a parameter; default `kobe.labs.lacnic.net`.

## Decisions

Agreed on 2026-11-25.

| Topic | Decision | Why |
|---|---|---|
| Size parameter | Counts **groups**, not containers. Default 6 groups = 18 nodes + master. | Matches how a class is organized; container count is always a multiple of 3. |
| Node roles | All three nodes in a group are **identical and blank**: bind9 installed, nothing configured. | Students build each role themselves (primary, secondary, hidden signer), as in modules 3–6. |
| Node image | **Ubuntu 24.04 with systemd** and apt's `bind9`, `bind9utils`, `bind9-dnsutils`. | Paths, packages, `systemctl`, `journalctl` and `rndc` match the course text exactly. |
| Master's DNS role | Authoritative for a lab-only **`lab.` TLD** that delegates `groupNN.lab.` to each group's three nodes, plus a **validating resolver** for the lab with `lab.`'s key as trust anchor. | Students can publish a DS in a real parent and see validation succeed or fail end to end (module 4). |
| Master's network role | NAT gateway: `dns-lab` is an internal network, and nodes route to the Internet only through the master. | As required; stopping the master cuts the nodes off, with no bypass. |
| Addressing | Fixed **IPv4 and IPv6** per node. | Exercises can hardcode `allow-transfer`, `also-notify` and AAAA glue. |
| DS publication | A registrar-style **form on the web page**. The web app applies it to `lab.` with a TSIG key the nodes never see, limited to DS records under the group's own name. | Mirrors publishing a DS through a registrar's panel. |
| Web access | **Per-group login**: a group sees only its own three nodes; an instructor login sees all nodes and the master. | Groups can't break each other's nodes. |
| Web terminal | **xterm.js** in the browser, bridged over a websocket to `docker exec` on the host. | One small service, with authorization handled in the same app. |
| Buttons | Start/Stop/Restart act on the **container** (`docker start/stop/restart`). | Also recovers a node a student broke. Routine reloads stay inside the node (`rndc`, `systemctl`). |
| HTTPS | **Caddy** in front of the web app, with an automatic **Let's Encrypt** certificate for the host name (#11). Until then, a **self-signed** certificate (#20). | Group passwords never cross the network in the clear. Let's Encrypt needs ports 80 and 443 reachable from the Internet. |
| Where `just` runs | **On the lab host itself** (clone the repo on kobe). The host parameter sets the web page's name and certificate. | Bind mounts, backups and the web app all live on the host. |
| Environments per host | **One.** The network is literally `dns-lab`; `init` refuses to run if one exists. | Simple; matches the requirement's fixed network name. |
| Backup | A timestamped tarball of every node's configuration, zones and keys (including KASP `.state` files), the master's state and the credentials, kept on the host. | Key material and zone state are what students lose otherwise. |
| Code and issues | Here, in `dns-lab/` of this repository; GitHub milestone **M0-Initial-Lab**. | The lab lives next to the course it serves. |

### Defaults pending confirmation

Chosen while planning and written into the issues; change them here first if needed.

- **Addresses:** network `10.53.0.0/16` and `fd53::/64`. Master `10.53.0.1` / `fd53::1`. Node `groupGG-N` is `10.53.GG.(10+N)` / `fd53::GG:(10+N)`, e.g. `group01-0` is `10.53.1.10` / `fd53::1:10`. This caps the lab at 99 groups (two-digit names).
- **IPv6** is lab-internal only in M0. Nodes reach the Internet over IPv4 through the master's NAT. The master's resolver therefore never queries IPv6 servers (`server ::/0 { bogus yes; };`), but still answers the lab over IPv6.
- **Master's DNS on one address** (#4): `10.53.0.1` is both the `lab.` authoritative server and the lab's resolver. Two BIND views split them: recursive queries from the lab go to a validating resolver, everything else to the authoritative `lab.` zone. The resolver finds `lab.` through a static-stub pointing back at the master.
- **lab.'s trust anchor and delv** (#4): the master generates `lab.`'s key on first boot and publishes its DS to `/etc/dnslab/lab-anchor.conf`, shared read-only with the nodes. `delv` needs that anchor for `lab.` names, so nodes have a `delv-lab` wrapper; `dig` needs nothing, since the resolver validates.
- **Where lab. is generated** (#4): the `lab.` zone, views and web page TSIG key are generated by the master on the environment's first boot, from the group count `just init` passes in, not by `init` itself. The host needs no BIND tools. Changing the number of groups means a new environment.
- **Routing via the master** (#3): `dns-lab` is a Docker internal network. The master also joins a normal bridge, `dns-lab-uplink`, and masquerades the lab out through it. Nodes get `NET_ADMIN` so a boot service can set their default route via `10.53.0.1`. Their `/etc/resolv.conf` points straight at the master, so Docker's embedded DNS (container names) isn't used.
- **systemd without `--privileged`** (#2): nodes run with `--cap-add SYS_ADMIN --security-opt apparmor=unconfined` and a private cgroup namespace, so the entrypoint can remount the container's own cgroup subtree read-write for systemd. Narrower than `--privileged`, but more than a default container; the alternatives (sysbox, user-namespace remapping) change the host's Docker setup. Details in `images/node/README.md`.
- **Web app stack:** Python (FastAPI with the Docker SDK) in a container with the Docker socket mounted, not attached to `dns-lab`.
- **Web page** (#8): UI in Spanish. Credentials in `state/credentials`, one `name password` line for `instructor` and each `groupNN`, in clear text so `just credentials` can print them. Lab containers carry `dnslab.role` and `dnslab.group` labels, and the app authorizes by label, never by what the browser sends. It listens only on `127.0.0.1:8080` (tests, SSH tunnels); the public entry point is Caddy. The app has the Docker socket, which is root on the host, so it is kept minimal.
- **Terminals** (#9): xterm.js 5.5, served by the web app (fetched at build time, pinned by checksum), not from a CDN. Closing a terminal tab hangs up the shell, because Docker would otherwise keep exec'd shells running.
- **DS form** (#10): the form takes the line `dnssec-dsfromkey` prints (one or more DS lines, digest type 1, 2 or 4). The app checks the owner name and parses the record itself, so it can say what's wrong, then runs `nsupdate` with the `dnslab-webapp` key inside the master via `docker exec`; the web container stays off `dns-lab`. After each change it flushes the resolver's cache under that zone (`rndc flushtree`), so validation reflects the change at once instead of after `lab.`'s 60 s TTLs.
- **Self-signed certificate** (#20): until #11, `just` generates one certificate per environment with `openssl` (P-256, one year, `CN` and SAN = `host`) in `state/caddy/`, and Caddy serves it. Caddy's own internal CA was not used because it reissues its certificates every 12 hours, so students would see the browser warning again each time. A one-year certificate means one warning per environment. Switching to Let's Encrypt means dropping the `tls` line from `caddy/Caddyfile`. The session cookie gets the Secure flag on HTTPS requests, but not on the loopback port.
- **`just init`** (#5): refuses to run if any part of an environment exists (lab containers, its three networks, or state files other than backups), so it never half-overwrites one. It records the group count and host in `state/env`, which `status` reads and `backup`/`destroy` will too.
- **`just destroy`** backs up first and asks for confirmation; it keeps the images unless asked to remove them.
- **Credentials:** `just init` generates one password per group plus an instructor password, stored on the host in `state/credentials` (mode 600).

## Out of scope for M0

- Authoritative software other than BIND.
- Internet access over IPv6 from the nodes.
- Several environments on one host.
- Publishing lab zones on the real Internet.

## How we work

- Plans and progress are tracked on GitHub with `gh`, in milestone **M0-Initial-Lab** (issues #1–#12).
- Every issue has acceptance criteria.
- Issues are closed only with Carlos's OK.
