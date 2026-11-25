#!/bin/sh
# Runs once per boot before named (dnslab-seed.service). /etc/bind,
# /var/cache/bind and /var/lib/bind are bind mounts from the host, empty
# on a new node: fill each empty one with the package's stock contents,
# and make sure the node has its own rndc key. Never touches a directory
# that already has files, so students' work is left alone.
set -eu

seed=/usr/local/share/dnslab/seed

for pair in etc-bind:/etc/bind var-cache-bind:/var/cache/bind var-lib-bind:/var/lib/bind; do
    src="$seed/${pair%%:*}"
    dst="${pair#*:}"
    mkdir -p "$dst"
    if [ -z "$(ls -A "$dst")" ]; then
        echo "dnslab-seed: seeding $dst"
        cp -a "$src/." "$dst/"
    fi
done

# Ownership as the Debian package sets it: config readable by group bind,
# working directories writable by named.
chown root:bind /etc/bind
chmod 2755 /etc/bind
chown bind:bind /var/cache/bind /var/lib/bind
chmod 775 /var/cache/bind /var/lib/bind

if [ ! -s /etc/bind/rndc.key ]; then
    echo "dnslab-seed: generating /etc/bind/rndc.key"
    rndc-confgen -a -c /etc/bind/rndc.key
    chown root:bind /etc/bind/rndc.key
    chmod 640 /etc/bind/rndc.key
fi
