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
| DS publication | A registrar-style **form on the web page**. The web app applies it to `lab.` with a TSIG key only it holds, limited to DS records under the group's own name. | Mirrors publishing a DS through a registrar's panel. |
| Web access | **Per-group login**: a group sees only its own three nodes; an instructor login sees all nodes and the master. | Groups can't break each other's nodes. |
| Web terminal | **xterm.js** in the browser, bridged over a websocket to `docker exec` on the host. | One small service, with authorization handled in the same app. |
| Buttons | Start/Stop/Restart act on the **container** (`docker start/stop/restart`). | Also recovers a node a student broke. Routine reloads stay inside the node (`rndc`, `systemctl`). |
| HTTPS | **Caddy** in front of the web app, with an automatic **Let's Encrypt** certificate for the host name. | Group passwords never cross the network in the clear. Needs ports 80 and 443 reachable from the Internet. |
| Where `just` runs | **On the lab host itself** (clone the repo on kobe). The host parameter sets the web page's name and certificate. | Bind mounts, backups and the web app all live on the host. |
| Environments per host | **One.** The network is literally `dns-lab`; `init` refuses to run if one exists. | Simple; matches the requirement's fixed network name. |
| Backup | A timestamped tarball of every node's configuration, zones and keys (including KASP `.state` files), the master's state and the credentials, kept on the host. | Key material and zone state are what students lose otherwise. |
| Code and issues | Here, in `dns-lab/` of this repository; GitHub milestone **M0-Initial-Lab**. | The lab lives next to the course it serves. |

### Defaults pending confirmation

Chosen while planning and written into the issues; change them here first if needed.

- **Addresses:** network `10.53.0.0/16` and `fd53::/64`. Master `10.53.0.1` / `fd53::1`. Node `groupGG-N` is `10.53.GG.(10+N)` / `fd53::GG:(10+N)`, e.g. `group01-0` is `10.53.1.10` / `fd53::1:10`. This caps the lab at 99 groups (two-digit names).
- **IPv6** is lab-internal only in M0. Nodes reach the Internet over IPv4 through the master's NAT.
- **systemd without `--privileged`** (#2): nodes run with `--cap-add SYS_ADMIN --security-opt apparmor=unconfined` and a private cgroup namespace, so the entrypoint can remount the container's own cgroup subtree read-write for systemd. Narrower than `--privileged`, but more than a default container; the alternatives (sysbox, user-namespace remapping) change the host's Docker setup. Details in `images/node/README.md`.
- **Web app stack:** Python (FastAPI with the Docker SDK) in a container with the Docker socket mounted, not attached to `dns-lab`.
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
