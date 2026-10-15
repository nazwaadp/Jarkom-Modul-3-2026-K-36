# di tengen
tcpdump -i eth0 -n -vvv -l -c 4 port 67 or port 68 | grep -E "BOOTP|DHCP-Message|Gateway-IP|Client-Ethernet-Address|Your-IP|Server-ID|Lease-Time"

# itadori
ip addr flush dev eth0
udhcpc -i eth0