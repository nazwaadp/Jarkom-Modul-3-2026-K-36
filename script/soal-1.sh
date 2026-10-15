1. jichi (/root/init.sh)

sh
#!/bin/bash

cat <<EOF > /etc/network/interfaces
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address 192.229.1.1
    netmask 255.255.255.0

auto eth2
iface eth2 inet static
    address 192.229.2.1
    netmask 255.255.255.0

auto eth3
iface eth3 inet static
    address 192.229.3.1
    netmask 255.255.255.0

auto eth4
iface eth4 inet static
    address 192.229.4.1
    netmask 255.255.255.0
EOF

echo 1 > /proc/sys/net/ipv4/ip_forward
apt-get update
apt-get install -y iptables
iptables -t nat -F
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

sh

# sama templatenya ke client
#!/bin/bash

cat <<EOF > /etc/network/interfaces
auto eth0
iface eth0 inet static
    address ALAMAT
    netmask 255.255.255.0
    gateway GATEWAY
    up echo nameserver 192.168.122.1 > /etc/resolv.conf
EOF

Host	ALAMAT	GATEWAY
utahime	192.229.1.2	192.229.1.1
shoko	192.229.1.3	192.229.1.1
gojo	192.229.1.4	192.229.1.1
tengen	192.229.4.10	192.229.4.1
geto	192.229.4.11	192.229.4.1
maki	192.229.4.12	192.229.4.1
panda	192.229.4.13	192.229.4.1
nanami	192.229.4.14	192.229.4.1
todo	192.229.4.15	192.229.4.1
kirara	192.229.4.16	192.229.4.1
yaga	192.229.4.17	192.229.4.1
inumaki	192.229.4.18	192.229.4.1