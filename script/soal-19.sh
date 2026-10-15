#!/bin/bash
# Soal 19 - gojo (192.229.1.4)
# Nginx reverse proxy: frontend cache 10 menit + X-Cache-Status,
# rate limit /api sebesar 10 request/detik per IP.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "Jalankan sebagai root: bash soal-19.sh"
  exit 1
fi

echo "[1/4] Konfigurasi DNS sementara dan instalasi paket"
if [ -f /etc/resolv.conf ]; then cp -n /etc/resolv.conf /etc/resolv.conf.soal19.bak || true; fi
echo "nameserver 192.168.122.1" > /etc/resolv.conf
apt-get update -y
apt-get install -y nginx curl
rm -f /etc/nginx/sites-enabled/default
mkdir -p /etc/nginx/snippets /var/cache/nginx/gojo
chown -R www-data:www-data /var/cache/nginx/gojo

cat > /etc/nginx/snippets/gojo_ratelimit.conf <<'EOF'
limit_req zone=api_limit burst=5 nodelay;
limit_req_status 429;
EOF

echo "[2/4] Tulis konfigurasi Nginx Gojo"
cat > /etc/nginx/sites-available/gojo <<'EOF'
log_format gojo_log 'ip=$remote_addr time=[$time_local] host=$host req="$request" status=$status bytes=$body_bytes_sent rt=$request_time ups=$upstream_addr ust=$upstream_status uct=$upstream_connect_time cache=$upstream_cache_status rl=$limit_req_status xff="$http_x_forwarded_for"';

proxy_cache_path /var/cache/nginx/gojo levels=1:2 keys_zone=web_cache:10m max_size=100m inactive=10m use_temp_path=off;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

upstream frontend_cluster {
    server 192.229.4.12; # maki
    server 192.229.4.13; # panda
}

upstream geto_lb {
    server 192.229.4.11; # geto
}

server {
    listen 80 default_server;
    server_name jujutsu.k-36.com www.jujutsu.k-36.com _;

    access_log /var/log/nginx/gojo_access.log gojo_log;
    error_log /var/log/nginx/gojo_error.log;

    location ~ ^/api(/|$) {
        include /etc/nginx/snippets/gojo_ratelimit.conf;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_pass http://geto_lb;
    }

    location / {
        proxy_cache web_cache;
        proxy_cache_key "$scheme$host$request_uri";
        proxy_cache_valid 200 10m;
        add_header X-Cache-Status $upstream_cache_status always;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_pass http://frontend_cluster;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gojo /etc/nginx/sites-enabled/gojo

echo "[3/4] Validasi dan jalankan Nginx"
nginx -t
if pgrep -x nginx >/dev/null 2>&1; then
  nginx -s reload
else
  systemctl enable --now nginx 2>/dev/null || nginx
fi
sleep 1

echo "[4/4] Self-test lokal"
CACHE_TEST_URL="http://127.0.0.1/?soal19_test=cache-check"
echo "Cache test pertama (expected MISS):"
curl -sS -D /tmp/soal19-first.headers -o /tmp/soal19-first.body -H 'Host: jujutsu.k-36.com' "$CACHE_TEST_URL"
grep -i '^X-Cache-Status:' /tmp/soal19-first.headers || true
echo "Cache test kedua (expected HIT; URL sama):"
curl -sS -D /tmp/soal19-second.headers -o /tmp/soal19-second.body -H 'Host: jujutsu.k-36.com' "$CACHE_TEST_URL"
grep -i '^X-Cache-Status:' /tmp/soal19-second.headers || true
echo "API smoke test:"
curl -sS -i --max-time 5 -H 'Host: jujutsu.k-36.com' http://127.0.0.1/api || true
echo
echo "Selesai. Log: /var/log/nginx/gojo_access.log"
