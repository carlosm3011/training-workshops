#!/bin/sh
# Runs after named on every boot (dnslab-warm-cache.service). Warms the
# lab resolver's cache by resolving a few names until each answers (#40).
# With a cold cache, names whose nameservers live in other domains
# (archive.ubuntu.com, pypi.org …) cost so many upstream queries that the
# resolver gives up with SERVFAIL: every attempt at an unreachable IPv6
# server address counts, and BIND 9.18 can't be told not to try them.
# Once the TLD servers' addresses are cached (for up to two days), they
# resolve at once. Never fails: a lab without Internet still works.
set -u

for q in "com NS" "net NS" "org NS" "archive.ubuntu.com A" "security.ubuntu.com A"; do
    for _ in $(seq 30); do
        # shellcheck disable=SC2086 # $q is "name type"
        dig +time=5 +tries=1 @127.0.0.1 $q 2>/dev/null | grep -q "status: NOERROR" && break
        sleep 1
    done || true
done
dig +time=5 +tries=1 @127.0.0.1 archive.ubuntu.com A 2>/dev/null | grep -q "status: NOERROR" \
    || echo "dnslab-warm-cache: archive.ubuntu.com still doesn't resolve; does the host reach the Internet?" >&2
exit 0
