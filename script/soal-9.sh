# Di jichi:

service isc-dhcp-relay stop

# Di itadori (Network 2), hapus alamat lama lalu minta lease baru:

killall udhcpc
ip addr flush dev eth0
udhcpc -i eth0

# Di jichi:

service isc-dhcp-relay start

# Di itadori:

udhcpc -i eth0
ip route