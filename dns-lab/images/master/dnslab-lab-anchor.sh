#!/bin/sh
# Runs after named on every boot (dnslab-lab-anchor.service). Waits for
# named to sign lab., then writes the DS of its key-signing key as a
# static trust anchor to /etc/dnslab/lab-anchor.conf and reloads named
# if it changed. The resolver view includes that file, and the nodes get
# the same directory read-only, for delv (see delv-lab in the node image).
# lab. uses dnssec-policy default: one CSK with an unlimited lifetime, so
# the anchor is written once per environment.
set -eu

anchor=/etc/dnslab/lab-anchor.conf

for _ in $(seq 60); do
    ds=$(dig +norec +time=1 +tries=1 @127.0.0.1 lab. DNSKEY 2>/dev/null \
        | dnssec-dsfromkey -2 -f - lab. 2>/dev/null | head -1) || true
    [ -n "$ds" ] && break
    sleep 1
done
[ -n "$ds" ] || { echo "dnslab-lab-anchor: lab. not signed after 60 s" >&2; exit 1; }

# "lab. IN DS 21944 13 2 AAFA..." -> trust-anchors { lab. static-ds 21944 13 2 "AAFA..."; };
new=$(echo "$ds" | awk '{ printf "trust-anchors {\n\tlab. static-ds %s %s %s \"%s\";\n};\n", $4, $5, $6, $7 }')
if [ "$new" != "$(cat "$anchor" 2>/dev/null)" ]; then
    printf '%s\n' "$new" > "$anchor.tmp"
    chmod 644 "$anchor.tmp"
    mv "$anchor.tmp" "$anchor"
    echo "dnslab-lab-anchor: wrote $anchor, reloading named"
    rndc reconfig
fi
