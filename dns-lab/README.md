# DNS Lab

A containerized lab for the hands-on parts of [DNS y DNSSEC para Operadores](../dns-dnssec-for-operators/README.md). Each student group gets three BIND nodes on a shared `dns-lab` network, reachable through a web page with browser terminals. A master container is the lab's gateway to the Internet, its `lab.` parent zone and its validating resolver.

**Students:** the lab guide is a chapter of the course book, [08-Guia-del-Laboratorio.md](../dns-dnssec-for-operators/08-Guia-del-Laboratorio.md) (Spanish): logging in, the certificate warning, each group's nodes and addresses, and modules 3, 4 and 6 done in the lab, with `delv-lab` to check the chain of trust.

[GOAL.md](GOAL.md) holds the requirements and every design decision. Work is tracked in the [M0-Initial-Lab milestone](https://github.com/carlosm3011/training-workshops/milestone/1).

> **Status:** usable for courses. Modules 3, 4 and 6 of the student guide have been run end to end in the lab. Open: NS and glue changes from the web page (#33, needed for module 6 without hand edits), the guide as HTML in the web page (#32), Let's Encrypt (#11).

## Instructor guide

The rest of this README is reference. This section is the order of things for running a course.

### Setting up a lab host (once)

- **Ubuntu 24.04** (other Linux hosts with cgroup v2 should work, but only Ubuntu 24.04 is tested) with **Docker** and your user in the `docker` group, and `sudo`. A running group takes about 120 MB of RAM (40 MB per node); kobe (4 CPUs, 8 GB) runs 6 groups using under 1 GB in all.
- **[just](https://just.systems) 1.15 or later**: `sudo apt install just`.
- A **DNS name** for the host, and **ports 80 and 443** reachable from where the students are. Nothing else needs to be open; the web app's port 8080 listens on loopback only.
- Clone this repository on the host and work in `dns-lab/`. Optionally, put the defaults for this host in `dns-lab/.env` ([Parameters](#parameters)).
- `just init` raises the host's inotify limits the first time it runs (see below); nothing else on the host needs setting up.

### Before a course

```sh
cd ~/training-workshops && git pull && cd dns-lab
just build                 # rebuild the images: picks up changes and fresh apt package lists
just groups=6 init         # one group per 2-3 students; about 40 s
just status                # every container running, with its addresses
just credentials           # one line per group, plus the instructor
just cert                  # the certificate's SHA-256 fingerprint
```

- `init` only builds images that are missing, so run `just build` first to get image changes (for example `htop` or apt's package lists) into a new lab.
- Hand each group its line from `just credentials` and the URL, `https://<host>/`. The `instructor` login sees every node and the master, and its DS panel has a menu to act for any group.
- Show the students the fingerprint from `just cert`: until #11, the certificate is self-signed, and the student guide tells them to compare the fingerprint before accepting the browser's warning.
- Point the students to the student guide, chapter 08 of the book ([08-Guia-del-Laboratorio.md](../dns-dnssec-for-operators/08-Guia-del-Laboratorio.md), also in the book's PDF).
- Log in once as a group yourself and open a terminal, to check the page end to end from the students' network.

### During a course

- **Back up at the end of each day**: `just backup`, then copy the tarball off the host (`scp`). It holds every group's keys and zones, and the passwords.
- **A node that misbehaves**: **Reiniciar** in the page (or `docker restart groupNN-N`). Everything students configured survives a restart.
- **A node a group wants back to blank**: its configuration lives in `state/nodes/groupNN-N/`. Stop it, set the old directories aside, and start it with empty ones; it boots like a new node (stock config, new rndc key):

  ```sh
  docker stop group03-1
  sudo mv state/nodes/group03-1 state/nodes/group03-1.old-$(date +%Y%m%d-%H%M)
  mkdir -p state/nodes/group03-1/{etc-bind,var-cache-bind,var-lib-bind}
  docker start group03-1
  ```

  `just backup` doesn't include the set-aside directory; delete it when it's no longer needed. A DS the group published stays in `lab.` until they remove it in the page.
- **A group's DS**: the instructor login can list, publish and remove any group's DS in the page, which also clears the resolver's cache for that zone.
- **Common student problems**:
  - `systemctl` fails with `Too many open files`: the host's inotify limits are too low (see below). `init` fixes this on new labs.
  - `apt install` says `Unable to locate package`: run `apt update` first (images built before #30 have no package lists).
  - A closed terminal tab kills the shell and its jobs; long-running commands need the tab left open.
  - `delv` on `lab.` names needs `delv-lab`, and `+cdflag` to see where a broken chain fails (see the student guide).

### Changing lab. by hand (module 6, until #33)

Module 6 removes `ns0.groupNN.lab.` from the group's delegation in `lab.`, which the web page can't do yet (#33). `lab.` is a dynamic, signed zone, so the edit goes through `rndc freeze`/`thaw`. **`rndc freeze` reports success before named has written the zone file**, so wait until the file's serial matches the one named serves before editing; otherwise the edit goes into an old file and the thaw discards every DS change since that file was written. While `lab.` is frozen, no group can publish a DS, so keep it short.

```sh
docker exec -it dnslab-master bash
rndc freeze lab in authoritative
live=$(dig +short @127.0.0.1 lab SOA | awk '{print $3}')
until grep -qE "^\s+$live\s+; serial" /var/lib/bind/db.lab; do sleep 1; done; echo "file at serial $live"
cp /var/lib/bind/db.lab /root/db.lab.$(date +%H%M%S)      # a copy, just in case
vi /var/lib/bind/db.lab
named-checkzone lab /var/lib/bind/db.lab
rndc thaw lab in authoritative
rndc flushtree groupNN.lab resolver
```

In the file, named has rewritten everything with `$ORIGIN` lines and relative names. To remove `ns0` from group 02:
- under `$ORIGIN lab.`, delete the line `NS ns0.group02` in the `group02` block; if that line carries the owner name `group02`, move the name onto the next line;
- under `$ORIGIN group02.lab.`, delete `ns0` and its `A` and `AAAA` lines;
- increase the number on the `; serial` line;
- leave every `RRSIG`, `NSEC` and `DNSKEY` alone: named re-signs what changed.

Records you add must use fully qualified names ending in a dot. Afterwards, check that the thaw loaded your serial and kept the journal: `journalctl -u named -n 20` must not say `has gone backwards` or `journal file is out of date`. Then `dig +norec @127.0.0.1 group02.lab NS` shows the new referral.

### After a course

```sh
just destroy               # asks, backs up, removes containers, networks and state (not backups)
```

Copy the last backup off the host if the students' work matters. `just restore` puts a backup back into a matching environment ([Restoring](#restoring)).

### Security notes

- The web app has the Docker socket, which is root on the host. Never publish port 8080; Caddy on 443 is the only way in.
- `state/credentials` and the backups hold passwords and private keys in clear text (mode 600). Treat the host's `dns-lab/state/` like a password file.
- Students are `root` in their nodes, and every node can reach every other group's nodes: the lab is for a class that trusts itself, not an isolation boundary.

## Usage

Run everything on the lab host itself (default `kobe.labs.lacnic.net`), from this directory. It needs Docker and [just](https://just.systems).

```sh
just                # list the recipes
just status         # show the parameters and the environment's containers
just init           # create a new environment
just credentials    # print the web page's passwords
just cert           # print the web page's certificate: path, expiry, SHA-256 fingerprint
just backup         # save every node's config, zones and keys, the master's state and the passwords
just restore FILE   # put a backup back into a matching environment
just destroy        # ask, back up, then remove the environment completely
just build          # build the lab images
just test-node      # boot a throwaway node and check it
just test-net       # bring up master + 2 groups, check addressing and routing, tear down
just test-master    # bring up master + group01, check lab., the resolver and DS publishing, tear down
just test-web       # bring up master + 2 groups + web page, check login, controls, DS form, terminals and authorization, tear down
just test-https     # bring up master + group01-0 + web page + Caddy, check HTTPS, tear down
just test-init      # run the real init with 2 groups, check it and status, tear down
just test-destroy   # destroy with no environment, answering no, destroy + init again, options; removes the images
just test-backup    # init, sign a group zone, back up, tear down, init, restore, check it validates, tear down
```

`just init` takes about 40 seconds for 6 groups on kobe:
- it builds any missing images, then creates the networks;
- it starts the master and waits until its resolver validates `lab.`;
- it starts the nodes, the web page and Caddy;
- it records the group count and host in `state/env`.

It refuses to run, and changes nothing, if any part of an environment exists: lab containers, the networks, or state files other than backups. `just status` lists every lab container with its state and fixed addresses; stopped nodes show their addresses too. `just destroy` removes it:
- it lists what it will remove and asks you to type `yes`; any other answer, or no answer, changes nothing;
- it runs `just backup`, then removes every lab container, the three networks, and everything under `state/` except `state/backups/`;
- it keeps the images, so the next `init` starts in seconds.

Options: `just yes=true destroy` doesn't ask, `skip_backup=true` doesn't back up, `images=true` also removes the lab images (`init` builds or pulls them again). With no environment, it says so and exits.

The `test-*` recipes (except `test-node`) use the real names (`dns-lab`, `dnslab-master`, `group01-0` …), so it refuses to run while an environment exists.

The host also needs [just](https://just.systems) 1.15 or later; Ubuntu 24.04's package (`sudo apt install just`) is enough.

Every lab container runs systemd as root, and they all share the host's per-user inotify limits. Ubuntu's default of 128 instances runs out at about 19 containers, and `systemctl` inside a node then fails with `Failed to allocate directory watch: Too many open files`. So `just init` first makes sure `fs.inotify.max_user_instances` is at least 8192 and `fs.inotify.max_user_watches` at least 524288. If either is lower, it writes `/etc/sysctl.d/90-dns-lab.conf`, applies it with `sudo` and says so; it never lowers a higher value. On a host where a lab is already running, the same can be done by hand, without restarting anything:

```sh
printf 'fs.inotify.max_user_instances = 8192\nfs.inotify.max_user_watches = 524288\n' | sudo tee /etc/sysctl.d/90-dns-lab.conf
sudo sysctl -p /etc/sysctl.d/90-dns-lab.conf
```

### Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `groups` | `6` | Number of student groups, 1–99. Each gets nodes `groupNN-0`, `groupNN-1` and `groupNN-2`. |
| `host` | `kobe.labs.lacnic.net` | Public name of the lab host: the web page's URL and certificate. |

Set them on the command line (`just groups=3 host=lab.example.org init`) or, to make them stick on a host, in a `.env` file next to the justfile:

```sh
DNSLAB_GROUPS=3
DNSLAB_HOST=lab.example.org
```

The command line wins over `.env`, which wins over the defaults.

## Backups

`just backup` writes `state/backups/dns-lab-<host>-<YYYYmmdd-HHMMSS>.tar.gz`, mode 600 because it holds private keys, and prints its path and size. Containers can be running or stopped. The tarball holds the environment's part of `state/`, with paths relative to it:

```
env  credentials
nodes/groupNN-N/{etc-bind,var-cache-bind,var-lib-bind}/   config, zones, journals, KASP keys and .state files
master/                                                   lab. (with every published DS), its keys, the web page's TSIG key
shared/lab-anchor.conf                                    lab.'s trust anchor, which must match master/'s keys
web/  caddy/                                              session secret, certificate
```

KASP keys live in BIND's working directory, `var-cache-bind`, unless a student sets `key-directory`; any of the three directories is covered. Files keep their numeric owners, so the containers' `bind` user owns them again after a restore. A backup of a running lab is taken while named works; BIND replays its journals, so a zone updated mid-backup comes back at the state its journal reached.

### Restoring

`just restore state/backups/<file>.tar.gz` puts a backup back into an environment with the **same group count and host** (it compares `env`); otherwise it says which `init` to run first. It:
1. runs `just backup`, so the state it replaces can be restored in turn;
2. stops every lab container;
3. replaces `state/`'s environment files with the tarball's (backups untouched);
4. starts the master, waits for its resolver, starts the nodes, the web page and Caddy.

Nodes that were stopped at backup time come back running. After `just destroy` (or on another host), first create a matching environment:

```sh
tar -xzOf state/backups/<file>.tar.gz env        # the backup's DNSLAB_GROUPS and DNSLAB_HOST
just groups=N host=H init
just restore state/backups/<file>.tar.gz
```

The passwords, the certificate and `lab.`'s key are the backup's again, so students keep their logins, and published DS records still match their zones. `just test-backup` checks this whole cycle.

## Layout

```
justfile        lifecycle recipes (init, destroy, backup, status, credentials)
GOAL.md         requirements and design decisions
images/node/    node image: Ubuntu 24.04, systemd, bind9 (see its README)
images/master/  master image: NAT gateway, lab. zone, resolver (see its README)
web/            web page: login, node list, controls, terminals, DS form (see its README)
caddy/          Caddyfile: HTTPS for the web page on ports 80 and 443
state/          generated per environment, gitignored:
  env                 the environment's group count and host, written by init
  nodes/<container>/  each node's bind mount (/etc/bind, /var/cache/bind, /var/lib/bind)
  master/             the master's bind mount, incl. the lab. zone and the web page's TSIG key
  shared/             mounted at /etc/dnslab: lab.'s trust anchor (master rw, nodes ro)
  credentials         web page logins: instructor and one per group (mode 600)
  web/session-secret  signs the web page's session cookies
  caddy/              the web page's self-signed certificate and key, until #11
  backups/            tarballs from `just backup` (never removed by the recipes)
```

Directories marked with an issue number are created by that issue.

## Network and addressing

```
            Internet
               │
     dns-lab-uplink (Docker bridge, NAT by Docker)
               │
        ┌──────┴───────┐
        │ dnslab-master│  NAT for 10.53.0.0/16, lab. zone, resolver
        └──────┬───────┘
               │ 10.53.0.1 / fd53::1
   dns-lab (internal: no route out except via the master)
     ┌─────────┼──────────┬── … ──┐
 group01-0  group01-1  group01-2   groupNN-N
```

| Container | IPv4 | IPv6 |
|---|---|---|
| master | `10.53.0.1` | `fd53::1` |
| `groupGG-N` | `10.53.GG.(10+N)` | `fd53::GG:(10+N)` |
| e.g. `group01-0` | `10.53.1.10` | `fd53::1:10` |
| host's end of the bridge | `10.53.255.254` | `fd53::ffff` |

- Nodes route to the Internet only through the master, and use it as their resolver. If the master is stopped, the nodes are cut off.
- IPv6 works between all containers on `dns-lab`, but there's no IPv6 route to the Internet in M0.
- All nodes share one subnet, so groups can reach each other's nodes directly.
- Each group's zone is `groupNN.lab.`, delegated from the master's `lab.` zone to `ns0`, `ns1` and `ns2.groupNN.lab.`, the group's three nodes in order. Students publish their DS in `lab.` through the web page's DS form.
- The master's resolver validates `lab.` names with `lab.`'s own trust anchor. `dig` shows the `ad` flag as usual; for `delv`, use the nodes' `delv-lab` wrapper (see [images/node](images/node/README.md)).

## Web page

The page is at `https://<host>/` (`https://kobe.labs.lacnic.net/` by default): Caddy (`dnslab-caddy`) listens on ports 443 and 80, redirects HTTP to HTTPS and proxies to `dnslab-web` over a small bridge network, `dns-lab-front`, which the lab can't reach. Until Let's Encrypt (#11), the certificate is self-signed, generated per environment for `host` and valid for a year, so students accept the browser's warning once. `just cert` prints its SHA-256 fingerprint, so you can tell students what the warning should show. `dnslab-web` itself only listens on `127.0.0.1:8080`, for the tests and SSH tunnels. Groups log in with the passwords from `just credentials` and see only their own nodes; the instructor sees everything. Clicking a node's name opens a root shell on it in a new tab. Below the nodes, **DS en lab.** lists, publishes and removes the DS records of the group's zone. See [web/README.md](web/README.md).

## DNS names in the lab

| Name | Served by | Points to |
|---|---|---|
| `lab.` | master (`ns.lab.`, `10.53.0.1`) | lab-only TLD, signed |
| `groupNN.lab.` | the group's nodes, once students configure them | delegated to `ns0-2.groupNN.lab.` |
| `ns0.groupNN.lab.` … `ns2.groupNN.lab.` | glue in `lab.` | `10.53.NN.10-12`, `fd53::NN:10-12` |
