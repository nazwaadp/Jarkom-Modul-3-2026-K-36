# di jichi (router)

#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y isc-dhcp-relay

cat <<EOF > /etc/default/isc-dhcp-relay
SERVERS="192.229.4.10"
INTERFACES="eth2 eth3 eth4"
OPTIONS=""
EOF

echo 1 > /proc/sys/net/ipv4/ip_forward
service isc-dhcp-relay restart