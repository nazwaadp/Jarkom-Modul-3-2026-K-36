#!/bin/bash
# Soal 11 - utahime (DNS MASTER) 
# Simpan di /root/soal-11.sh lalu jalankan: bash /root/soal-11.sh

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Set nameserver sementara untuk install paket"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

echo "[2/6] Install BIND9"
apt-get update -y
apt-get install -y bind9 bind9-utils bind9-dnsutils

echo "[3/6] Konfigurasi options"
mkdir -p /etc/bind/jujutsu /run/named
chown bind:bind /run/named
cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.229.0.0/16; };
    allow-transfer { none; };
    dnssec-validation no;
    auth-nxdomain no;
};
EOF

echo "[4/6] Deklarasi zona MASTER + allow-transfer ke shoko"
cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K36.com" {
    type master;
    file "/etc/bind/jujutsu/db.jujutsu.K36.com";
    allow-transfer { 192.229.1.3; };
    also-notify { 192.229.1.3; };
    notify yes;
};
EOF

echo "[5/6] Buat file zona (SOA + NS untuk kedua server)"
cat > /etc/bind/jujutsu/db.jujutsu.K36.com <<'EOF'
$TTL    604800
@       IN      SOA     ns1.jujutsu.K36.com. admin.jujutsu.K36.com. (
                        2026101401      ; Serial (YYYYMMDDNN) - NAIKKAN tiap ubah zona
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL
; --- Name Server ---
@       IN      NS      ns1.jujutsu.K36.com.
@       IN      NS      ns2.jujutsu.K36.com.
; --- Glue record untuk NS ---
ns1     IN      A       192.229.1.2
ns2     IN      A       192.229.1.3
EOF

echo "[6/6] Validasi & jalankan named"
named-checkconf || exit 1
named-checkzone jujutsu.K36.com /etc/bind/jujutsu/db.jujutsu.K36.com || exit 1
service named restart 2>/dev/null || service bind9 restart 2>/dev/null || { pkill named; sleep 1; named -u bind; }
sleep 2

echo "=== Self test ==="
dig @127.0.0.1 jujutsu.K36.com SOA +short
dig @127.0.0.1 jujutsu.K36.com NS +short

#!/bin/bash
# Soal 11 - shoko (DNS SLAVE)
# Jalankan SETELAH utahime selesai.
export DEBIAN_FRONTEND=noninteractive

echo "[1/5] Set nameserver sementara"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

echo "[2/5] Install BIND9"
apt-get update -y
apt-get install -y bind9 bind9-utils bind9-dnsutils

echo "[3/5] Konfigurasi options"
mkdir -p /run/named /var/cache/bind
chown bind:bind /run/named /var/cache/bind
cat > /etc/bind/named.conf.options <<'EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.229.0.0/16; };
    allow-transfer { none; };
    dnssec-validation no;
    auth-nxdomain no;
};
EOF

echo "[4/5] Deklarasi zona SLAVE (masters = utahime)"
cat > /etc/bind/named.conf.local <<'EOF'
zone "jujutsu.K36.com" {
    type slave;
    masters { 192.229.1.2; };
    file "/var/cache/bind/db.jujutsu.K36.com";
};
EOF

echo "[5/5] Validasi & jalankan named"
named-checkconf || exit 1
service named restart 2>/dev/null || service bind9 restart 2>/dev/null || { pkill named; sleep 1; named -u bind; }
sleep 4

echo "=== Self test (zona harus sudah tersinkron dari master) ==="
ls -l /var/cache/bind/
dig @127.0.0.1 jujutsu.K36.com SOA +short
dig @127.0.0.1 jujutsu.K36.com NS +short