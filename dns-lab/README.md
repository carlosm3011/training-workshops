# DNS Lab

A containerized lab for the hands-on parts of [DNS y DNSSEC para Operadores](../dns-dnssec-for-operators/README.md). Each student group gets three BIND nodes on a shared `dns-lab` network, reachable through a web page with browser terminals. A master container is the lab's gateway to the Internet, its `lab.` parent zone and its validating resolver.

[GOAL.md](GOAL.md) holds the requirements and every design decision. Work is tracked in the [M0-Initial-Lab milestone](https://github.com/carlosm3011/training-workshops/milestone/1).

> **Status:** in development. The node image is done (`just build`, `just test-node`); the lifecycle recipes still only print what they will do.

## Usage

Run everything on the lab host itself (default `kobe.labs.lacnic.net`), from this directory. It needs Docker and [just](https://just.systems).

```sh
just                # list the recipes
just status         # show the parameters and the environment's containers
just init           # create a new environment
just credentials    # print the web page's passwords
just backup         # save every node's config, zones and keys
just destroy        # back up, then remove the environment completely
just build          # build the lab images
just test-node      # boot a throwaway node and check it
```

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
images/master/  master image: NAT gateway, lab. zone, resolver (#4)
web/            web page, terminals and DS form (#8-#10)
templates/      config templates rendered by `just init`
state/          generated per environment, gitignored:
  nodes/<container>/  each node's bind mount (/etc/bind, /var/cache/bind, /var/lib/bind)
  credentials         group and instructor passwords (mode 600)
  backups/            tarballs from `just backup`
```

Directories marked with an issue number are created by that issue.

## Addressing

| Container | IPv4 | IPv6 |
|---|---|---|
| master | `10.53.0.1` | `fd53::1` |
| `groupGG-N` | `10.53.GG.(10+N)` | `fd53::GG:(10+N)` |
| e.g. `group01-0` | `10.53.1.10` | `fd53::1:10` |

Each group's zone is `groupNN.lab.`, delegated from the master's `lab.` zone to the group's three nodes.
