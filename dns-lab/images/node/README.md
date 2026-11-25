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

## Run flags

```sh
docker run -d --name group01-0 --hostname group01-0 \
  --cgroupns=private --cap-add SYS_ADMIN --security-opt apparmor=unconfined \
  --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
  -v …/etc-bind:/etc/bind -v …/var-cache-bind:/var/cache/bind -v …/var-lib-bind:/var/lib/bind \
  dnslab-node
```

The justfile keeps these flags in `node_run_flags`. The image sets `STOPSIGNAL SIGRTMIN+3`, so `docker stop` shuts systemd down cleanly in a couple of seconds.

### Why SYS_ADMIN and no AppArmor profile

Docker mounts `/sys/fs/cgroup` read-only unless a container is `--privileged`, and systemd can't start without writing there. The entrypoint, `dnslab-init.sh`, remounts it read-write, then starts systemd. With `--cgroupns=private`, that mount is only the container's own cgroup subtree, not the host's. The remount needs `CAP_SYS_ADMIN`, and Docker's default AppArmor profile forbids it even with the capability.

This is much narrower than `--privileged`: no host devices, the default seccomp profile, and the other capabilities stay dropped. It is still more than a default container, and students have root in their nodes. On kobe's kernel (6.8), the known cgroup `release_agent` escape (CVE-2022-0492) is fixed. The cleaner alternatives, a systemd-aware runtime such as sysbox or Docker user-namespace remapping, change the host's Docker setup and are left out of M0.

### Differences from a real Ubuntu server

- named isn't confined by AppArmor in the container, so module 3's note about AppArmor restricting named's directories doesn't reproduce here.
- There is no network configuration inside the node: Docker assigns addresses, and #3 sets the route through the master.
