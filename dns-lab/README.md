# DNS Lab

A containerized lab for the hands-on parts of [DNS y DNSSEC para Operadores](../dns-dnssec-for-operators/README.md). Each student group gets three BIND nodes on a shared `dns-lab` network, reachable through a web page with browser terminals. A master container is the lab's gateway to the Internet, its `lab.` parent zone and its validating resolver.

[GOAL.md](GOAL.md) holds the requirements and every design decision. Work is tracked in the [M0-Initial-Lab milestone](https://github.com/carlosm3011/training-workshops/milestone/1).

> **Status:** in development. Done: the node and master images, the network, the master's DNS roles, and the web page's login, controls, terminals and DS form, served over HTTPS by Caddy with a self-signed certificate `just init` brings up a complete environment. `backup` and `destroy` still only print what they will do.

## Usage

Run everything on the lab host itself (default `kobe.labs.lacnic.net`), from this directory. It needs Docker and [just](https://just.systems).

```sh
just                # list the recipes
just status         # show the parameters and the environment's containers
just init           # create a new environment
just credentials    # print the web page's passwords
just cert           # print the web page's certificate: path, expiry, SHA-256 fingerprint
just backup         # save every node's config, zones and keys
just destroy        # back up, then remove the environment completely
just build          # build the lab images
just test-node      # boot a throwaway node and check it
just test-net       # bring up master + 2 groups, check addressing and routing, tear down
just test-master    # bring up master + group01, check lab., the resolver and DS publishing, tear down
just test-web       # bring up master + 2 groups + web page, check login, controls, DS form, terminals and authorization, tear down
just test-https     # bring up master + group01-0 + web page + Caddy, check HTTPS, tear down
just test-init      # run the real init with 2 groups, check it and status, tear down
```

`just init` takes about 40 seconds for 6 groups on kobe:
- it builds any missing images, then creates the networks;
- it starts the master and waits until its resolver validates `lab.`;
- it starts the nodes, the web page and Caddy;
- it records the group count and host in `state/env`.

It refuses to run, and changes nothing, if any part of an environment exists: lab containers, the networks, or state files other than backups. `just status` lists every lab container with its state and fixed addresses; stopped nodes show their addresses too. Until `just destroy` exists (#7), `just _teardown` removes an environment: containers, networks and `state/`, except `state/backups/`.

The `test-*` recipes (except `test-node`) use the real names (`dns-lab`, `dnslab-master`, `group01-0` …), so it refuses to run while an environment exists.

The host also needs [just](https://just.systems) 1.15 or later; Ubuntu 24.04's package (`sudo apt install just`) is enough.

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
  backups/            tarballs from `just backup`
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
