#!/bin/bash
# Soal 15 - Geto sebagai Internal Load Balancer
# Kelompok K-36 | Weighted Round Robin: Nanami:Todo = 3:1
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

EXPECTED_NODE="geto"
GETO_IP="192.229.4.11"
NANAMI_IP="192.229.4.14"
TODO_IP="192.229.4.15"
DOMAIN="jujutsu.k-36.com"
SITE="/etc/nginx/sites-available/api_lb"
LOG="/var/log/nginx/geto_lb.log"

if [[ "$(hostname -s)" != "$EXPECTED_NODE" ]]; then
    echo "ERROR: Jalankan script ini pada node geto (hostname sekarang: $(hostname -s))."
    exit 1
fi

if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${GETO_IP}/24"; then
    echo "ERROR: IP ${GETO_IP}/24 tidak ditemukan pada geto."
    ip -4 -br addr
    exit 1
fi

echo "=================================================="
echo "Soal 15 - Internal Load Balancer di Geto"
echo "Domain : ${DOMAIN}"
echo "Nanami : ${NANAMI_IP} (weight 3)"
echo "Todo   : ${TODO_IP} (weight 1)"
echo "=================================================="

# Install package only when Nginx or curl is missing.
if ! command -v nginx >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "[1/5] Menyiapkan DNS sementara untuk instalasi paket"
    if [[ -f /etc/resolv.conf && ! -f /root/resolv.conf.soal15.bak ]]; then
        cp -a /etc/resolv.conf /root/resolv.conf.soal15.bak
    fi
    printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
    apt-get -o Acquire::ForceIPv4=true update
    apt-get install -y nginx curl
else
    echo "[1/5] Nginx dan curl sudah tersedia"
fi

mkdir -p /root/backup-soal15 /etc/nginx/sites-available /etc/nginx/sites-enabled /var/log/nginx
if [[ -f "$SITE" && ! -f /root/backup-soal15/api_lb.before-soal15 ]]; then
    cp -a "$SITE" /root/backup-soal15/api_lb.before-soal15
fi

cat > "$SITE" <<'NGINX'
log_format geto_lb_log '$remote_addr -> upstream=$upstream_addr "$request" $status';

upstream api_cluster {
    server 192.229.4.14:80 weight=3;
    server 192.229.4.15:80 weight=1;
}

server {
    listen 80 default_server;
    server_name jujutsu.k-36.com www.jujutsu.k-36.com _;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
    }

    access_log /var/log/nginx/geto_lb.log geto_lb_log;
    error_log  /var/log/nginx/geto_error.log;
}
NGINX

echo "[2/5] Mengaktifkan konfigurasi upstream Weighted Round Robin"
rm -f /etc/nginx/sites-enabled/default
ln -sfn "$SITE" /etc/nginx/sites-enabled/api_lb

echo "[3/5] Validasi Nginx"
nginx -t

# Ensure Nginx is running inside the container.
if pgrep -x nginx >/dev/null 2>&1; then
    nginx -s reload
else
    nginx
fi
sleep 1

echo "[4/5] Uji koneksi backend dari Geto"
for backend in "$NANAMI_IP" "$TODO_IP"; do
    code="$(curl -sS --connect-timeout 3 --max-time 5 -o /tmp/soal15-backend-test.out -w '%{http_code}' "http://${backend}/api" 2>/dev/null || true)"
    echo "Backend ${backend}: HTTP ${code:-000}"
    if [[ -s /tmp/soal15-backend-test.out ]]; then
        cat /tmp/soal15-backend-test.out
        echo
    fi
done

echo "[5/5] Uji 40 request ke Geto dan hitung distribusi worker"
STATUS_FILE="$(mktemp)"
WORKER_FILE="$(mktemp)"
RESP_FILE="$(mktemp)"
trap 'rm -f "$STATUS_FILE" "$WORKER_FILE" "$RESP_FILE" /tmp/soal15-backend-test.out' EXIT

for i in $(seq 1 40); do
    : > "$RESP_FILE"
    code="$(curl -sS --connect-timeout 3 --max-time 8 -o "$RESP_FILE" -w '%{http_code}' \
        -H "Host: ${DOMAIN}" http://127.0.0.1/api 2>/dev/null || true)"
    echo "${code:-000}" >> "$STATUS_FILE"
    if grep -q '"worker":"nanami"' "$RESP_FILE"; then
        echo "nanami" >> "$WORKER_FILE"
    elif grep -q '"worker":"todo"' "$RESP_FILE"; then
        echo "todo" >> "$WORKER_FILE"
    fi
done

echo "--- Ringkasan HTTP status dari 40 request ---"
sort "$STATUS_FILE" | uniq -c || true
echo "--- Ringkasan worker yang menjawab ---"
if [[ -s "$WORKER_FILE" ]]; then
    sort "$WORKER_FILE" | uniq -c
else
    echo "Belum ada JSON worker nanami/todo yang berhasil dikenali. Periksa backend dan log."
fi

echo "--- Contoh request terakhir pada access log Geto ---"
tail -n 10 "$LOG" 2>/dev/null || true

echo "Selesai. Target teoritis untuk 40 request sukses: Nanami sekitar 30, Todo sekitar 10. Gunakan hasil aktual untuk laporan."
