# Master image

The lab's master, `dnslab-master`: the [node image](../node/README.md) plus what makes it the nodes' only way out.

- **NAT gateway.** The master sits on the internal `dns-lab` network at `10.53.0.1` / `fd53::1`, and on `dns-lab-uplink`, a normal Docker bridge, for the Internet. `dnslab-nat.service` masquerades traffic from `10.53.0.0/16` out through the uplink. The uplink is whichever interface holds the default route; its name (eth0 or eth1) can change between starts.
- **Resolver.** For now, BIND with Ubuntu's stock options, which answers recursive queries from the master's local networks. One addition, in `named.conf.options`: `server ::/0 { bogus yes; };`. The master has a lab-internal IPv6 address but no IPv6 route to the Internet, so without it named tries IPv6 root and TLD servers, and cold-cache lookups can fail.
- **Coming in #4:** the `lab.` parent zone, resolver ACLs, the `lab.` trust anchor and the web app's TSIG key.

`just build` builds this image after the node image it derives from.

## Run flags

On top of the node's flags (`node_run_flags` in the justfile):

```sh
docker create --name dnslab-master … --network dns-lab --ip 10.53.0.1 --ip6 fd53::1 \
  --sysctl net.ipv4.ip_forward=1 -e DNSLAB_LAB4=10.53.0.0/16 -e DNSLAB_RESOLVER=127.0.0.1 …
docker network connect dns-lab-uplink dnslab-master
docker start dnslab-master
```

The uplink is connected before the first start so `dnslab-nat` finds the default route. The justfile's `_master` recipe does all of this, then waits until the resolver actually answers: named is up a few seconds before it can resolve.
