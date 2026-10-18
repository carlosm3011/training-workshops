#!/bin/sh
# Apply a lab's finished configuration to its running routers.
#
#   ./load-solution.sh lab-2            # all routers in the lab
#   ./load-solution.sh lab-2 r1 r2      # only some of them
#
# The lab must already be deployed with containerlab. Each
# <lab>/solution/<node>.conf is copied into clab-<lab name>-<node> and
# applied with `vtysh -f`, on top of whatever is configured there.
# Set DOCKER=podman to use podman instead of docker.
set -eu

DOCKER=${DOCKER:-docker}
lab=${1:?usage: $0 <lab-dir> [node...]}
shift
cd "$(dirname "$0")/$lab"

name=$(sed -n 's/^name: *//p' ./*.clab.yml)
[ $# -gt 0 ] || set -- $(cd solution && ls ./*.conf | sed 's#^\./##; s/\.conf$//')

for node in "$@"; do
    c="clab-$name-$node"
    echo "== $c"
    $DOCKER cp "solution/$node.conf" "$c:/tmp/solution.conf"
    $DOCKER exec "$c" vtysh -f /tmp/solution.conf >/dev/null 2>&1 ||
        { echo "vtysh failed to apply solution/$node.conf on $c" >&2; exit 1; }
done
