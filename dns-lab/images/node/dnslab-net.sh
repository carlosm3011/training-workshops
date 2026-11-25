#!/bin/sh
# Runs once per boot (dnslab-net.service). The dns-lab network is
# internal, so Docker gives nodes no default route and points
# /etc/resolv.conf at its own embedded resolver. Route through the master
# instead and use its resolver, as set by `docker run -e`:
#   DNSLAB_GW4       IPv4 default gateway (the master); unset on the master
#   DNSLAB_RESOLVER  resolver for /etc/resolv.conf
# systemd units don't inherit the container's environment, so read PID 1's.
set -eu

eval "$(tr '\0' '\n' < /proc/1/environ | grep -E '^DNSLAB_[A-Z0-9_]+=[0-9A-Fa-f.:]*$' | sed 's/^/export /')"

if [ -n "${DNSLAB_GW4:-}" ]; then
    echo "dnslab-net: default route via $DNSLAB_GW4"
    ip route replace default via "$DNSLAB_GW4"
fi

if [ -n "${DNSLAB_RESOLVER:-}" ]; then
    echo "dnslab-net: resolver $DNSLAB_RESOLVER"
    # Docker bind-mounts this file; overwrite it in place, don't replace it.
    printf 'nameserver %s\noptions edns0 trust-ad\n' "$DNSLAB_RESOLVER" > /etc/resolv.conf
fi
