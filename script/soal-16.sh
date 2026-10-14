#!/bin/bash
# Soal 16 - Gojo: Public Reverse Proxy / Path-Based Routing
# Network 1: Gojo 192.229.1.4
# /    -> Round Robin Maki/Panda
# /api -> Geto (internal load balancer)
set -Eeuo pipefail

DOMAIN="jujutsu.k-36.com"
GOJO_IP="192.229.1.4"
MAKI_IP="192.229.4.12"
PANDA_IP="192.229.4.13"
GETO_IP="192.229.4.11"

if [[ "$(hostname -s)" != "gojo" ]]; then
    echo "ERROR: Jalankan script ini di node gojo. Hostname sekarang: $(hostname -s)"
    exit 1
fi

if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${GOJO_IP}/24"; then
    echo "PERINGATAN: ${GOJO_IP}/24 tidak ditemukan pada Gojo. Periksa IP aktual:"
    ip -4 -br addr
    echo "Sesuaikan GOJO_IP pada script jika Master Sheet berbeda."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Menyiapkan DNS sementara dan memasang Nginx/curl bila diperlukan"
printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
if ! command -v nginx >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    apt-get -o Acquire::ForceIPv4=true update
    apt-get install -y nginx curl
fi

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# Backup konfigurasi Gojo yang ada sebelum mengganti konfigurasi Soal 16
if [[ -f /etc/nginx/sites-available/gojo && ! -f /root/gojo-soal16.before.bak ]]; then
    cp -a /etc/nginx/sites-available/gojo /root/gojo-soal16.before.bak
fi

# Pastikan default site tidak mengambil alih port 80
rm -f /etc/nginx/sites-enabled/default

echo "[2/4] Membuat konfigurasi path-based routing"
cat > /etc/nginx/sites-available/gojo <<EOF
log_format gojo_log 'ip=\$remote_addr time=[\$time_local] host=\$host req="\$request" status=\$status bytes=\$body_bytes_sent rt=\$request_time ups=\$upstream_addr ust=\$upstream_status';

upstream frontend_cluster {
    # Round Robin default
    server ${MAKI_IP}:80;
    server ${PANDA_IP}:80;
}

upstream geto_lb {
    server ${GETO_IP}:80;
}

server {
    listen 80 default_server;
    server_name ${DOMAIN} www.${DOMAIN} _;

    access_log /var/log/nginx/gojo_access.log gojo_log;
    error_log  /var/log/nginx/gojo_error.log;

    # /api dan /api/... diarahkan ke Geto
    location ^~ /api {
        proxy_set_header Host \$host;
        proxy_connect_timeout 3s;
        proxy_read_timeout 15s;
        proxy_pass http://geto_lb;
    }

    # Path lainnya (termasuk /) diarahkan ke Maki/Panda Round Robin
    location / {
        proxy_set_header Host \$host;
        proxy_connect_timeout 3s;
        proxy_read_timeout 15s;
        proxy_pass http://frontend_cluster;
    }
}
EOF

ln -sfn /etc/nginx/sites-available/gojo /etc/nginx/sites-enabled/gojo

echo "[3/4] Validasi konfigurasi Nginx"
nginx -t

echo "[4/4] Menjalankan atau reload Nginx"
if pgrep -x nginx >/dev/null 2>&1; then
    nginx -s reload
else
    nginx
fi
sleep 1

echo
echo "=== KONFIGURASI ROUTING ==="
grep -nE 'server_name|upstream frontend_cluster|server 192\.229\.4\.(12|13|11)|location \^~ /api|location /|proxy_pass' /etc/nginx/sites-available/gojo

echo
echo "=== SELF TEST FRONTEND (4 REQUEST) ==="
for i in 1 2 3 4; do
    echo "Request $i:"
    curl -sS --connect-timeout 3 --max-time 10 \
      -H "Host: ${DOMAIN}" "http://127.0.0.1/?test=$i" || true
    echo
done

echo
echo "=== SELF TEST API VIA GETO ==="
curl -i -sS --connect-timeout 3 --max-time 15 \
  -H "Host: ${DOMAIN}" http://127.0.0.1/api || true

echo
echo "Selesai. Jika self-test gagal, periksa worker Maki/Panda, Geto, dan log Gojo."
