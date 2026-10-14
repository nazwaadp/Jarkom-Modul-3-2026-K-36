#!/bin/bash
# Soal 17 - Geto: percaya X-Real-IP hanya jika peer adalah Gojo
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

DOMAIN="jujutsu.k-36.com"
GETO_IP="192.229.4.11"
GOJO_IP="192.229.1.4"
NANAMI_IP="192.229.4.14"
TODO_IP="192.229.4.15"

[[ "$(hostname -s)" == "geto" ]] || { echo "ERROR: jalankan di geto, hostname saat ini $(hostname -s)"; exit 1; }
if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${GETO_IP}/24"; then
  echo "ERROR: IP ${GETO_IP}/24 tidak ditemukan di Geto"; ip -br addr; exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
  apt-get -o Acquire::ForceIPv4=true update
  apt-get -o Acquire::ForceIPv4=true install -y nginx curl
fi

mkdir -p /root/backup-soal17-geto
if [[ -f /etc/nginx/sites-available/api_lb && ! -f /root/backup-soal17-geto/api_lb.before ]]; then
  cp -a /etc/nginx/sites-available/api_lb /root/backup-soal17-geto/api_lb.before
fi

cat > /etc/nginx/sites-available/api_lb <<'NGINX'
# Hanya IP Gojo yang dianggap reverse proxy tepercaya.
geo $trusted_proxy {
    default        0;
    192.229.1.4/32 1;
}

# X-Real-IP dipercaya hanya jika koneksi TCP benar-benar berasal dari Gojo.
map $trusted_proxy $verified_client_ip {
    1       $http_x_real_ip;
    default $remote_addr;
}

# Log alamat peer, X-Real-IP yang diterima, IP hasil verifikasi, dan upstream.
log_format lb_ip_log 'peer=$remote_addr xri="$http_x_real_ip" verified=$verified_client_ip request="$request" status=$status upstream=$upstream_addr upstream_status=$upstream_status';

upstream api_cluster {
    server 192.229.4.14 weight=3;
    server 192.229.4.15 weight=1;
}

server {
    listen 80 default_server;
    server_name jujutsu.k-36.com www.jujutsu.k-36.com _;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $verified_client_ip;
        # Teruskan hanya IP client yang telah diverifikasi.
        proxy_set_header X-Forwarded-For $verified_client_ip;
    }

    access_log /var/log/nginx/geto_lb.log lb_ip_log;
    error_log  /var/log/nginx/geto_error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/api_lb /etc/nginx/sites-enabled/api_lb
rm -f /etc/nginx/sites-enabled/default

nginx -t
if pgrep -x nginx >/dev/null 2>&1; then nginx -s reload; else nginx; fi
sleep 1

echo "=== Self-test via Geto ==="
curl -sS --connect-timeout 3 --max-time 15 -H "Host: ${DOMAIN}" -w '\nHTTP: %{http_code}\n' http://127.0.0.1/api || true
echo "Access log: /var/log/nginx/geto_lb.log"
