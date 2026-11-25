#!/bin/sh
# delv for lab. names. lab. isn't in the real root, so delv's built-in
# root anchor can't validate it: use the lab.'s own trust anchor, which the
# master publishes in /etc/dnslab (mounted read-only on every node).
#   delv-lab @10.53.0.1 group01.lab. SOA
exec delv -a /etc/dnslab/lab-anchor.conf +root=lab "$@"
