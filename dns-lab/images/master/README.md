# Master image

The lab's master, `dnslab-master`: the [node image](../node/README.md) plus the three roles that make it the center of the lab.

1. **NAT gateway.** The master sits on the internal `dns-lab` network at `10.53.0.1` / `fd53::1`, and on `dns-lab-uplink`, a normal Docker bridge, for the Internet. `dnslab-nat.service` masquerades traffic from `10.53.0.0/16` out through the uplink. The uplink is whichever interface holds the default route; its name (eth0 or eth1) can change between starts.
2. **The `lab.` parent zone.** A lab-only TLD, signed with `dnssec-policy default` (one ECDSAP256SHA256 CSK, unlimited lifetime). It delegates each group's zone, `groupNN.lab.`, to `ns0`, `ns1` and `ns2.groupNN.lab.` (the group's three nodes), with A and AAAA glue. The delegations stay lame until students configure their nodes; that's the exercise.
3. **The lab's validating resolver**, for `10.53.0.0/16`, `fd53::/64` and the master itself. It resolves the Internet normally, and resolves and validates `lab.` using `lab.`'s own key as a trust anchor.

`just build` builds this image after the node image it derives from. `just test-master` checks all of the above, including a group signing its zone and publishing its DS.

## One address, two views

Both DNS roles answer on `10.53.0.1`. `named.conf.lab` splits them with two views:

| View | Matches | Does |
|---|---|---|
| `resolver` | recursive queries (RD=1) from the lab (`match-recursive-only yes`) | Validating recursion. Finds `lab.` through a `static-stub` zone pointing back at `10.53.0.1`, trusts it via `/etc/dnslab/lab-anchor.conf`, and never synthesizes `lab.` answers from the real root's NSEC records (`synth-from-dnssec no`). |
| `authoritative` | everything else | Serves the signed `lab.` zone, never recurses. |

So:
- `dig @10.53.0.1 lab. SOA +dnssec` from a node gets a validated answer (`ad`) from the resolver view.
- `dig @10.53.0.1 group01.lab. NS +norec` gets the authoritative referral with glue.
- The resolver's own non-recursive queries to `10.53.0.1` land in the authoritative view.
- A recursive query from outside the lab, such as the uplink side, falls to the authoritative view and is REFUSED.

The resolver never queries IPv6 servers (`server ::/0 { bogus yes; };` in `named.conf.options`). The master has a lab-internal IPv6 address but no IPv6 route to the Internet, so cold-cache lookups would otherwise fail. It still answers the lab over IPv6.

## First boot and every boot

| Service | When | What |
|---|---|---|
| `dnslab-seed` (node image) | before named | Seeds empty bind mounts. For the master, `named.conf` and `named.conf.options` come from this image instead of Ubuntu's stock files. |
| `dnslab-master-setup` | before named | On the environment's **first** boot only: generates the web page's TSIG key (`/etc/bind/dnslab-webapp.key`), `named.conf.lab` and the `lab.` zone (`/var/lib/bind/db.lab`) for `DNSLAB_GROUPS` groups. Later boots leave them alone: `lab.` is a dynamic zone named owns, and published DS records must survive restarts. |
| `dnslab-lab-anchor` | after named | Waits until `lab.` is signed, writes its key's DS as a `static-ds` trust anchor to `/etc/dnslab/lab-anchor.conf`, and runs `rndc reconfig` if it changed. |
| `dnslab-nat` | boot | NAT, as above. |

`/etc/dnslab` is the host's `state/shared/`, mounted read-write on the master and read-only on every node, so nodes have the same trust anchor (see `delv-lab` in the node image).

Changing the number of groups means a new environment: `named.conf.lab` and `lab.` are only generated once.

## Publishing DS records

`lab.` accepts dynamic updates only when signed with the `dnslab-webapp` TSIG key, and its `update-policy` only allows DS records at each `groupNN.lab.` name:

```sh
nsupdate -k /etc/bind/dnslab-webapp.key <<'EOF'
update add group01.lab. 60 IN DS 12345 13 2 0123…
send
EOF
```

The web page's DS form (#10) does this, running `nsupdate` inside the master with `docker exec`, then `rndc flushtree groupNN.lab. resolver` so the resolver forgets the old answers. The key stays on the master (`state/master/etc-bind/dnslab-webapp.key` on the host) and is never visible to the nodes.

## Run flags

On top of the node's flags (`node_run_flags` in the justfile):

```sh
docker create --name dnslab-master … --network dns-lab --ip 10.53.0.1 --ip6 fd53::1 \
  --sysctl net.ipv4.ip_forward=1 \
  -e DNSLAB_LAB4=10.53.0.0/16 -e DNSLAB_RESOLVER=127.0.0.1 -e DNSLAB_GROUPS=6 \
  -v …/shared:/etc/dnslab …
docker network connect dns-lab-uplink dnslab-master
docker start dnslab-master
```

The uplink is connected before the first start so `dnslab-nat` finds the default route. The justfile's `_master` recipe does all of this. It then waits until the resolver answers and validates `lab.`: named is up a few seconds before it can resolve, and the trust anchor is only loaded once `lab.` is signed.
