#!/bin/sh
# Container entrypoint. Docker mounts /sys/fs/cgroup read-only unless the
# container is --privileged, and systemd can't start without writing to
# it. With --cgroupns=private, /sys/fs/cgroup here is only this
# container's own subtree, so remount it read-write and hand over to
# systemd. Needs --cap-add SYS_ADMIN and --security-opt apparmor=unconfined
# (Docker's AppArmor profile forbids the remount); see README.md.
set -eu

if ! grep -q '^0::/$' /proc/self/cgroup; then
    echo "dnslab-init: run with --cgroupns=private" >&2
    exit 1
fi
mount -o remount,rw /sys/fs/cgroup
exec /sbin/init "$@"
