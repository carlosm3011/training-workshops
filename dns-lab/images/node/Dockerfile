# Student node: Ubuntu 24.04 with systemd as PID 1 and BIND from apt, so
# paths, packages, systemctl, journalctl and rndc match the course text.
# Run it with the flags in ../../justfile (node_run_flags); see README.md.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    container=docker

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus \
      bind9 bind9-utils bind9-dnsutils ldnsutils \
      iproute2 iputils-ping tcpdump curl ca-certificates \
      vim nano less bash-completion man-db \
 && rm -rf /var/lib/apt/lists/*

# Keep systemd to what a container needs: no consoles, no udev, no
# network or clock management (Docker does those).
RUN systemctl mask \
      getty.target console-getty.service \
      systemd-udevd.service systemd-udev-trigger.service \
      systemd-networkd.service systemd-networkd.socket \
      systemd-timesyncd.service systemd-resolved.service \
      systemd-logind.service \
      sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount \
      dev-hugepages.mount

# Pristine copies of the directories that are bind-mounted from the host,
# used to seed an empty mount on first boot. The rndc key the package
# generated at build time is dropped so each node gets its own.
RUN rm -f /etc/bind/rndc.key \
 && mkdir -p /usr/local/share/dnslab/seed \
 && cp -a /etc/bind       /usr/local/share/dnslab/seed/etc-bind \
 && cp -a /var/cache/bind /usr/local/share/dnslab/seed/var-cache-bind \
 && cp -a /var/lib/bind   /usr/local/share/dnslab/seed/var-lib-bind

COPY dnslab-init.sh /usr/local/sbin/dnslab-init
COPY dnslab-seed.sh /usr/local/sbin/dnslab-seed
COPY dnslab-seed.service /etc/systemd/system/
RUN chmod 755 /usr/local/sbin/dnslab-init /usr/local/sbin/dnslab-seed \
 && systemctl enable dnslab-seed.service named.service

# systemd shuts down cleanly on SIGRTMIN+3, not on Docker's default SIGTERM.
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/sbin/dnslab-init"]
