#!/bin/bash
# Soal 12 - Utahime: A, CNAME, Reverse DNS PTR, DNS Forwarder
set -Eeuo pipefail

DOMAIN="jujutsu.k-36.com"
GOJO_IP="192.229.1.4"
SHOKO_IP="192.229.1.3"
MASTER_ZONE="/etc/bind/db.jujutsu.k-36.com"
REVERSE_ZONE="/etc/bind/db.192.229.1"

if [[ "$(hostname -s)" != "utahime" ]]; then
  echo "ERROR: Jalankan script ini hanya di node utahime."
  exit 1
fi
if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq '192.229.1.2/24'; then
  echo "ERROR: IP 192.229.1.2/24 tidak ditemukan di utahime."
  ip -4 -br addr
  exit 1
fi
if ! command -v named >/dev/null 2>&1 || ! command -v dig >/dev/null 2>&1; then
  echo "ERROR: BIND9/dnsutils belum tersedia. Instal paket dahulu."
  exit 1
fi

BACKUP="/root/backup-soal12-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in /etc/bind/named.conf.options /etc/bind/named.conf.local "$MASTER_ZONE" "$REVERSE_ZONE"; do
  if [[ -f "$f" ]]; then cp -a "$f" "$BACKUP/"; fi
done
echo "Backup konfigurasi lama: $BACKUP"

mkdir -p /var/cache/bind

echo "[1/5] Mengatur DNS options dan forwarder..."
cat > /etc/bind/named.conf.options <<'OPTIONS_EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.229.0.0/16; };
    allow-transfer { none; };
    forwarders { 192.168.122.1; };
    forward first;
    dnssec-validation no;
    auth-nxdomain no;
};
OPTIONS_EOF

echo "[2/5] Mendeklarasikan forward zone dan reverse zone..."
cat > /etc/bind/named.conf.local <<EOF
zone "${DOMAIN}" {
    type master;
    file "${MASTER_ZONE}";
    allow-transfer { ${SHOKO_IP}; };
    also-notify { ${SHOKO_IP}; };
    notify yes;
};

zone "1.229.192.in-addr.arpa" {
    type master;
    file "${REVERSE_ZONE}";
    allow-transfer { ${SHOKO_IP}; };
    also-notify { ${SHOKO_IP}; };
    notify yes;
};
EOF

echo "[3/5] Membuat forward zone (A dan CNAME)..."
cat > "$MASTER_ZONE" <<EOF
\$TTL 604800
@ IN SOA ns1.${DOMAIN}. admin.${DOMAIN}. (
    2026101410
    604800
    86400
    2419200
    604800
)
@   IN NS ns1.${DOMAIN}.
@   IN NS ns2.${DOMAIN}.
ns1 IN A 192.229.1.2
ns2 IN A 192.229.1.3
@   IN A ${GOJO_IP}
www IN CNAME ${DOMAIN}.
EOF
chmod 0644 "$MASTER_ZONE"
chown root:bind "$MASTER_ZONE"

echo "[4/5] Membuat reverse zone PTR untuk Network 1..."
cat > "$REVERSE_ZONE" <<EOF
\$TTL 604800
@ IN SOA ns1.${DOMAIN}. admin.${DOMAIN}. (
    2026101401
    604800
    86400
    2419200
    604800
)
@ IN NS ns1.${DOMAIN}.
@ IN NS ns2.${DOMAIN}.
2 IN PTR ns1.${DOMAIN}.
3 IN PTR ns2.${DOMAIN}.
4 IN PTR ${DOMAIN}.
EOF
chmod 0644 "$REVERSE_ZONE"
chown root:bind "$REVERSE_ZONE"

echo "[5/5] Validasi konfigurasi dan zona..."
named-checkconf
named-checkzone "$DOMAIN" "$MASTER_ZONE"
named-checkzone 1.229.192.in-addr.arpa "$REVERSE_ZONE"
named-checkconf -z

if pgrep -x named >/dev/null 2>&1; then
  pkill -HUP -x named
else
  nohup named -g -u bind -c /etc/bind/named.conf > /root/soal-12-named.log 2>&1 &
fi
sleep 2
if ! pgrep -x named >/dev/null 2>&1; then
  echo "ERROR: named tidak berjalan. Log:"
  tail -n 40 /root/soal-12-named.log 2>/dev/null || true
  exit 1
fi

echo
echo "=== A record apex ==="
dig @127.0.0.1 "$DOMAIN" A +noall +answer || true
echo "=== CNAME www ==="
dig @127.0.0.1 "www.${DOMAIN}" CNAME +noall +answer || true
echo "=== PTR Gojo ==="
dig @127.0.0.1 -x "$GOJO_IP" +noall +answer || true
echo "=== Forwarder test google.com ==="
dig @127.0.0.1 google.com A +short || true

echo
echo "Soal 12 Utahime selesai. Periksa output query di atas; tes client dilakukan setelah Shoko dan jaringan client siap."

#!/bin/bash
# Soal 12 - Shoko: Slave forward/reverse zones plus DNS forwarder
set -Eeuo pipefail

DOMAIN="jujutsu.k-36.com"
UTAHIME_IP="192.229.1.2"
SHOKO_IP="192.229.1.3"

if [[ "$(hostname -s)" != "shoko" ]]; then
  echo "ERROR: Jalankan script ini hanya di node shoko."
  exit 1
fi
if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${SHOKO_IP}/24"; then
  echo "ERROR: IP ${SHOKO_IP}/24 tidak ditemukan di shoko."
  ip -4 -br addr
  exit 1
fi
if ! command -v named >/dev/null 2>&1 || ! command -v dig >/dev/null 2>&1; then
  echo "ERROR: BIND9/dnsutils belum tersedia. Instal paket dahulu."
  exit 1
fi
MASTER_SOA="$(dig @${UTAHIME_IP} "$DOMAIN" SOA +short +time=3 +tries=1 2>/dev/null || true)"
if [[ -z "$MASTER_SOA" ]]; then
  echo "ERROR: Utahime tidak memberikan jawaban SOA untuk ${DOMAIN}. Perbaiki Master dahulu."
  exit 1
fi

BACKUP="/root/backup-soal12-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in /etc/bind/named.conf.options /etc/bind/named.conf.local; do
  if [[ -f "$f" ]]; then cp -a "$f" "$BACKUP/"; fi
done
echo "Backup konfigurasi lama: $BACKUP"

mkdir -p /var/cache/bind
chown bind:bind /var/cache/bind

echo "[1/3] Mengatur DNS forwarder..."
cat > /etc/bind/named.conf.options <<'OPTIONS_EOF'
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { 127.0.0.1; 192.229.0.0/16; };
    allow-transfer { none; };
    forwarders { 192.168.122.1; };
    forward first;
    dnssec-validation no;
    auth-nxdomain no;
};
OPTIONS_EOF

echo "[2/3] Mengatur forward zone dan reverse zone sebagai Slave..."
cat > /etc/bind/named.conf.local <<EOF
zone "${DOMAIN}" {
    type slave;
    masters { ${UTAHIME_IP}; };
    file "/var/cache/bind/db.jujutsu.k-36.com";
};

zone "1.229.192.in-addr.arpa" {
    type slave;
    masters { ${UTAHIME_IP}; };
    file "/var/cache/bind/db.192.229.1";
};
EOF

named-checkconf

echo "[3/3] Memuat ulang atau menjalankan BIND9..."
if pgrep -x named >/dev/null 2>&1; then
  pkill -HUP -x named
else
  nohup named -g -u bind -c /etc/bind/named.conf > /root/soal-12-named.log 2>&1 &
fi
sleep 3
if ! pgrep -x named >/dev/null 2>&1; then
  echo "ERROR: named tidak berjalan. Log:"
  tail -n 40 /root/soal-12-named.log 2>/dev/null || true
  exit 1
fi

echo "=== File cache zona Slave ==="
ls -lh /var/cache/bind/ || true
echo "=== A record via Shoko ==="
dig @${SHOKO_IP} "$DOMAIN" A +noall +answer || true
echo "=== CNAME via Shoko ==="
dig @${SHOKO_IP} "www.${DOMAIN}" CNAME +noall +answer || true
echo "=== PTR via Shoko ==="
dig @${SHOKO_IP} -x 192.229.1.4 +noall +answer || true
echo "=== Forwarder test via Shoko ==="
dig @${SHOKO_IP} google.com A +short || true

echo "Soal 12 Shoko selesai. Jika file cache zona belum terlihat, periksa /root/soal-12-named.log dan transfer dari Utahime."

