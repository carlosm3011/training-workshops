# The lab's master: the node image (systemd, bind9, seeded bind mounts)
# plus NAT, so the nodes on the internal dns-lab network reach the
# Internet through it, and its DNS roles: the lab. parent zone and the
# lab's validating resolver (see README.md).
# Build the node image first: `just build` does both in order.
FROM dnslab-node

RUN apt-get update \
 && apt-get install -y --no-install-recommends iptables \
 && rm -rf /var/lib/apt/lists/*

# Seeded into an empty /etc/bind instead of Ubuntu's stock files.
COPY named.conf named.conf.options /usr/local/share/dnslab/seed/etc-bind/

COPY dnslab-nat.sh /usr/local/sbin/dnslab-nat
COPY dnslab-master-setup.sh /usr/local/sbin/dnslab-master-setup
COPY dnslab-lab-anchor.sh /usr/local/sbin/dnslab-lab-anchor
COPY dnslab-nat.service dnslab-master-setup.service dnslab-lab-anchor.service /etc/systemd/system/
RUN chmod 755 /usr/local/sbin/dnslab-nat /usr/local/sbin/dnslab-master-setup /usr/local/sbin/dnslab-lab-anchor \
 && systemctl enable dnslab-nat.service dnslab-master-setup.service dnslab-lab-anchor.service
