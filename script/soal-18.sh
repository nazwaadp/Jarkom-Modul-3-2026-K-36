#!/bin/bash
# ============================================================
# Soal 18 - GETO
# Internal Load Balancer
#
# Primary:
#   Nanami = 192.229.4.14 weight 3
#   Todo   = 192.229.4.15 weight 1
#
# Backup:
#   Kirara = 192.229.4.16
#
# Health:
#   max_fails=2
#   fail_timeout=5s
#
# Domain:
#   jujutsu.k-36.com
# ============================================================

export DEBIAN_FRONTEND=noninteractive

NANAMI_IP="192.229.4.14"
TODO_IP="192.229.4.15"
KIRARA_IP="192.229.4.16"

echo "============================================================"
echo " SOAL 18 - GETO API LOAD BALANCER"
echo "============================================================"

echo "[1/4] Cek Nginx"

if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx belum terinstall."
    echo "Install terlebih dahulu:"
    echo "apt-get update -y && apt-get install -y nginx curl"
    exit 1
fi

echo "[2/4] Membuat konfigurasi API Load Balancer"

cat > /etc/nginx/sites-available/api_lb <<'EOF'
log_format lb_log 'peer=$remote_addr verified=$verified_client_ip -> upstream=$upstream_addr ust=$upstream_status "$request" $status';

# ============================================================
# TRUSTED PROXY
# Hanya Gojo yang boleh mengirim X-Real-IP sebagai IP client.
# ============================================================

geo $trusted_proxy {
    default         0;
    192.229.1.4/32  1;
}

map $trusted_proxy $verified_client_ip {
    1       $http_x_real_ip;
    default $remote_addr;
}

# ============================================================
# API CLUSTER
#
# Nanami + Todo = PRIMARY
# Kirara          = BACKUP
# ============================================================

upstream api_cluster {

    server 192.229.4.14 weight=3 max_fails=2 fail_timeout=5s;
    server 192.229.4.15 weight=1 max_fails=2 fail_timeout=5s;

    server 192.229.4.16 backup;
}

server {
    listen 80 default_server;

    server_name jujutsu.k-36.com www.jujutsu.k-36.com _;

    access_log /var/log/nginx/geto_lb.log lb_log;
    error_log  /var/log/nginx/geto_error.log;

    location / {

        proxy_pass http://api_cluster;

        proxy_set_header Host $host;

        # IP client yang sudah diverifikasi
        proxy_set_header X-Real-IP $verified_client_ip;

        # Forwarded IP chain
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_connect_timeout 2s;

        # Jika primary gagal, coba upstream berikutnya.
        # Jika seluruh primary gagal, backup Kirara digunakan.
        proxy_next_upstream error timeout http_502 http_503 http_504;

        proxy_next_upstream_tries 3;
    }
}
EOF

ln -sf /etc/nginx/sites-available/api_lb \
       /etc/nginx/sites-enabled/api_lb

echo "[3/4] Validasi konfigurasi"

nginx -t || {
    echo "ERROR: konfigurasi Nginx gagal."
    exit 1
}

echo "[4/4] Reload Nginx"

if pgrep -x nginx >/dev/null; then
    nginx -s reload
else
    nginx
fi

sleep 1

echo ""
echo "============================================================"
echo " HASIL KONFIGURASI SOAL 18"
echo "============================================================"

echo "--- Hostname ---"
hostname

echo "--- Nginx Test ---"
nginx -t

echo ""
echo "--- Upstream ---"
grep -nE 'upstream api_cluster|192\.229\.4\.14|192\.229\.4\.15|192\.229\.4\.16|weight=|backup|max_fails|fail_timeout' \
/etc/nginx/sites-available/api_lb

echo ""
echo "--- Trusted Proxy ---"
grep -nE 'trusted_proxy|192\.229\.1\.4|verified_client_ip|X-Real-IP|X-Forwarded-For' \
/etc/nginx/sites-available/api_lb

echo ""
echo "SOAL 18 GETO SELESAI."
