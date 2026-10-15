#!/bin/bash

apt-get update
apt-get install -y isc-dhcp-server

# Interface yang melayani DHCP
cat <<EOF > /etc/default/isc-dhcp-server
INTERFACESv4="eth0"
INTERFACESv6=""
EOF

cat <<EOF > /etc/dhcp/dhcpd.conf
ddns-update-style none;
authoritative;
default-lease-time 600;
max-lease-time 7200;

# Network 4 (lokal, tanpa pool dinamis)
subnet 192.229.4.0 netmask 255.255.255.0 {
}

# Network 2 (Divisi A)
subnet 192.229.2.0 netmask 255.255.255.0 {
    range 192.229.2.10 192.229.2.35;
    option routers 192.229.2.1;
    option broadcast-address 192.229.2.255;
}

# Network 3 (Divisi B)
subnet 192.229.3.0 netmask 255.255.255.0 {
    range 192.229.3.10 192.229.3.89;
    option routers 192.229.3.1;
    option broadcast-address 192.229.3.255;
}
EOF

touch /var/lib/dhcp/dhcpd.leases
dhcpd -t -cf /etc/dhcp/dhcpd.conf
service isc-dhcp-server restart