# Pada tengen, soal2.sh memasang dan menyalakan DHCP Server dengan konfigurasi lengkap:

echo 'bash /root/soal2.sh' >> /root/.bashrc

# Pada jichi, init.sh mengaktifkan IP forwarding dan NAT, lalu soal3.sh menyalakan DHCP Relay:

echo 'bash /root/init.sh' >> /root/.bashrc
echo 'bash /root/soal3.sh' >> /root/.bashrc

# Restart node-> Verifikasi dari client
Pada itadori (Network 2), alamat lama dihapus agar client harus meminta lease baru dari awal:

ip addr flush dev eth0
udhcpc -i eth0
