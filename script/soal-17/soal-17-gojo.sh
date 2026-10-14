#!/bin/bash
# ============================================================
# Soal 17 - GOJO (PUBLIC REVERSE PROXY)
# - /     -> frontend_cluster (Maki + Panda)
# - /api  -> Geto
# - Meneruskan IP client asli melalui:
#     X-Real-IP
#     X-Forwarded-For
# ============================================================

export DEBIAN_FRONTEND=noninteractive

echo "============================================================"
echo " SOAL 17 - KONFIGURASI GOJO"
echo "============================================================"

echo "[1/4] Set nameserver dan install Nginx"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

apt-get update -y
apt-get install -y nginx curl

echo "[2/4] Bersihkan konfigurasi default"
rm -f /etc/nginx/sites-enabled/default
mkdir -p /etc/nginx/snippets

echo "[3/4] Membuat konfigurasi Gojo"

cat > /etc/nginx/sites-available/gojo <<'EOF'
log_format gojo_log 'ip=$remote_addr time=[$time_local] host=$host req="$request" status=$status bytes=$body_bytes_sent rt=$request_time ups=$upstream_addr ust=$upstream_status uct=$upstream_connect_time cache=$upstream_cache_status rl=$limit_req_status xff="$http_x_forwarded_for"';

# ============================================================
# FRONTEND CLUSTER
# Maki + Panda
# Round Robin
# ============================================================

upstream frontend_cluster {
    server 192.229.4.12;
    server 192.229.4.13;
}

# ============================================================
# API CLUSTER
# Gojo -> Geto
# ============================================================

upstream geto_lb {
    server 192.229.4.11;
}

server {
    listen 80 default_server;

    server_name jujutsu.k-36.com www.jujutsu.k-36.com _;

    access_log /var/log/nginx/gojo_access.log gojo_log;
    error_log  /var/log/nginx/gojo_error.log;

    # ========================================================
    # /api -> GETO
    # ========================================================

    location ~ ^/api(/|$) {

        proxy_set_header Host $host;

        # IP client asli
        proxy_set_header X-Real-IP $remote_addr;

        # Forwarded client IP
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_connect_timeout 3s;

        proxy_pass http://geto_lb;
    }

    # ========================================================
    # / -> MAKI + PANDA
    # ========================================================

    location / {

        proxy_set_header Host $host;

        # IP client asli
        proxy_set_header X-Real-IP $remote_addr;

        # Forwarded client IP
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_connect_timeout 3s;

        proxy_pass http://frontend_cluster;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gojo \
       /etc/nginx/sites-enabled/gojo

echo "[4/4] Validasi dan reload Nginx"

nginx -t || {
    echo "ERROR: konfigurasi Nginx gagal."
    exit 1
}

if pgrep -x nginx >/dev/null; then
    nginx -s reload
else
    nginx
fi

sleep 1

echo ""
echo "============================================================"
echo " HASIL KONFIGURASI GOJO"
echo "============================================================"

echo "--- Hostname ---"
hostname

echo "--- IP ---"
ip -4 -br addr

echo "--- Nginx Test ---"
nginx -t

echo "--- Header & Proxy ---"
grep -nE 'X-Real-IP|X-Forwarded-For|proxy_pass' \
    /etc/nginx/sites-available/gojo

echo ""
echo "--- Port 80 ---"
ss -lntp | grep ':80' || echo "WARNING: port 80 belum LISTEN"

echo ""
echo "SOAL 17 GOJO SELESAI."