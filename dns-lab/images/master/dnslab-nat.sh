#!/bin/sh
# Runs once per boot (dnslab-nat.service). Masquerade traffic from the lab
# network (DNSLAB_LAB4, set with `docker run -e`) out through the uplink,
# the interface holding the master's default route. IPv4 forwarding is
# enabled with `docker run --sysctl net.ipv4.ip_forward=1`.
set -eu

eval "$(tr '\0' '\n' < /proc/1/environ | grep -E '^DNSLAB_[A-Z0-9_]+=[0-9A-Fa-f.:/]*$' | sed 's/^/export /')"
: "${DNSLAB_LAB4:?DNSLAB_LAB4 not set}"

uplink=$(ip -4 route show default | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
[ -n "$uplink" ] || { echo "dnslab-nat: no default route, is the uplink network attached?" >&2; exit 1; }

[ "$(cat /proc/sys/net/ipv4/ip_forward)" = 1 ] \
    || { echo "dnslab-nat: net.ipv4.ip_forward is off" >&2; exit 1; }

rule="POSTROUTING -s $DNSLAB_LAB4 -o $uplink -j MASQUERADE"
# shellcheck disable=SC2086  # $rule is a list of iptables arguments
iptables -t nat -C $rule 2>/dev/null || iptables -t nat -A $rule
echo "dnslab-nat: masquerading $DNSLAB_LAB4 out of $uplink"
