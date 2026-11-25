# Node image

The container every student node runs: Ubuntu 24.04 with systemd as PID 1 and BIND 9.18 from apt, so `/etc/bind`, `systemctl … bind9`, `journalctl -u named`, `rndc` and the DNSSEC tools behave exactly as the course describes.

Build and check it from `dns-lab/`:

```sh
just build        # docker build -t dnslab-node images/node
just test-node    # boot a throwaway node and run the checks from issue #2
```

## What's inside

- **Packages:** `bind9`, `bind9-utils` (named-checkconf/zone, dnssec-keygen/signzone/verify/settime/dsfromkey, rndc), `bind9-dnsutils` (dig, delv, nsupdate), `ldnsutils` (drill), plus iproute2, ping, tcpdump, curl, vim, nano and less.
- **systemd** trimmed for a container: consoles, udev, networkd, resolved, timesyncd and logind are masked.
- **BIND is installed but blank:** Ubuntu's stock `/etc/bind` and no zones of ours. `named.service`, also reachable as `bind9`, is enabled.

## Bind mounts and first boot

Each node's directory on the host, `state/nodes/<container>/`, is mounted over BIND's three directories:

| Host | Container |
|---|---|
| `etc-bind/` | `/etc/bind` |
| `var-cache-bind/` | `/var/cache/bind` |
| `var-lib-bind/` | `/var/lib/bind` |

An empty bind mount hides what the image has at that path, so `dnslab-seed.service` runs before named on every boot:
- It fills each **empty** directory with the package's stock contents, kept in the image under `/usr/local/share/dnslab/seed/`. A directory that already has files is never touched, so students' work survives restarts.
- It sets the Debian package's ownership and modes.
- If `/etc/bind/rndc.key` is missing, it generates one, so every node has its own key. The key the package created at build time is removed from the image.

On the host, files owned by the container's `bind` user show a host account name with the same numeric ID (on kobe, group `_ssh`). Only the displayed name differs.

## Routing and resolver

The `dns-lab` network is internal: Docker gives nodes no default route and points `/etc/resolv.conf` at its own embedded resolver. `dnslab-net.service` fixes both on every boot, from variables passed with `docker run -e`:

| Variable | Effect |
|---|---|
| `DNSLAB_GW4` | `ip route replace default via …` (the master, `10.53.0.1`). Unset on the master itself. |
| `DNSLAB_RESOLVER` | Rewrites `/etc/resolv.conf` to use only this resolver (the master; `127.0.0.1` on the master). |

systemd services don't inherit the container's environment, so the script reads PID 1's. Nodes have no IPv6 default route: IPv6 is lab-internal in M0.

## Validating lab. names with delv

`lab.` isn't in the real root, so `delv`'s built-in root anchor can't validate it. The master publishes `lab.`'s trust anchor in `/etc/dnslab/lab-anchor.conf`, mounted read-only on every node, and the image has a wrapper:

```sh
delv-lab @10.53.0.1 group01.lab. SOA      # = delv -a /etc/dnslab/lab-anchor.conf +root=lab …
```

Where the course runs `delv @127.0.0.1 example.com A`, students run `delv-lab` on their `groupNN.lab.` names. `dig` needs nothing special: the master's resolver validates and sets the `ad` flag.

## Run flags

```sh
docker run -d --name group01-0 --hostname group01-0 \
  --cgroupns=private --cap-add SYS_ADMIN --cap-add NET_ADMIN --security-opt apparmor=unconfined \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
  --network dns-lab --ip 10.53.1.10 --ip6 fd53::1:10 \
  -e DNSLAB_GW4=10.53.0.1 -e DNSLAB_RESOLVER=10.53.0.1 \
  -v …/etc-bind:/etc/bind -v …/var-cache-bind:/var/cache/bind -v …/var-lib-bind:/var/lib/bind \
  -v …/shared:/etc/dnslab:ro \
  dnslab-node
```

The justfile keeps the security flags in `node_run_flags`, and its `_node` recipe adds the rest. `NET_ADMIN` lets `dnslab-net` set the default route. It only affects the node's own network namespace, so a student can break their own node's routing but nobody else's. The image sets `STOPSIGNAL SIGRTMIN+3`, so `docker stop` shuts systemd down cleanly in a couple of seconds.

### Why SYS_ADMIN and no AppArmor profile

Docker mounts `/sys/fs/cgroup` read-only unless a container is `--privileged`, and systemd can't start without writing there. The entrypoint, `dnslab-init.sh`, remounts it read-write, then starts systemd. With `--cgroupns=private`, that mount is only the container's own cgroup subtree, not the host's. The remount needs `CAP_SYS_ADMIN`, and Docker's default AppArmor profile forbids it even with the capability.

This is much narrower than `--privileged`: no host devices, the default seccomp profile, and the other capabilities stay dropped. It is still more than a default container, and students have root in their nodes. On kobe's kernel (6.8), the known cgroup `release_agent` escape (CVE-2022-0492) is fixed. The cleaner alternatives, a systemd-aware runtime such as sysbox or Docker user-namespace remapping, change the host's Docker setup and are left out of M0.

### Differences from a real Ubuntu server

- named isn't confined by AppArmor in the container, so module 3's note about AppArmor restricting named's directories doesn't reproduce here.
- There is no network configuration inside the node: Docker assigns the addresses, and `dnslab-net` sets the route and resolver.
- Container names don't resolve between nodes: `/etc/resolv.conf` points at the master, not Docker's embedded DNS. Use addresses, or the lab's own names (`ns0.group01.lab.` …).
- `delv` on `lab.` names needs `delv-lab` (above).
