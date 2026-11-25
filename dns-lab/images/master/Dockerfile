# The lab's master: the node image (systemd, bind9, seeded bind mounts)
# plus NAT, so the nodes on the internal dns-lab network reach the
# Internet through it. Its DNS roles (lab. zone, resolver) come in #4.
# Build the node image first: `just build` does both in order.
FROM dnslab-node

RUN apt-get update \
 && apt-get install -y --no-install-recommends iptables \
 && rm -rf /var/lib/apt/lists/*

COPY named.conf.options /usr/local/share/dnslab/seed/etc-bind/named.conf.options
COPY dnslab-nat.sh /usr/local/sbin/dnslab-nat
COPY dnslab-nat.service /etc/systemd/system/
RUN chmod 755 /usr/local/sbin/dnslab-nat \
 && systemctl enable dnslab-nat.service
