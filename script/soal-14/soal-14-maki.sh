#!/bin/bash
# Soal 14 - maki: Nginx + PHP-FPM frontend worker
# hanya menerima trafik dari Gojo (192.229.1.4)
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

NODE="maki"
DOMAIN="jujutsu.k-36.com"
PROXY_IP="192.229.1.4"
BACKUP_DIR="/root/backup-soal14/${NODE}"

if [[ $EUID -ne 0 ]]; then echo "ERROR: jalankan sebagai root."; exit 1; fi
if [[ "$(hostname -s)" != "$NODE" ]]; then
    echo "ERROR: script khusus node $NODE (hostname sekarang: $(hostname -s))."
    exit 1
fi

mkdir -p "$BACKUP_DIR"
if [[ ! -f "$BACKUP_DIR/backup-captured" ]]; then
    [[ -f /etc/nginx/sites-available/jujutsu ]] && cp -a /etc/nginx/sites-available/jujutsu "$BACKUP_DIR/jujutsu.site.original"
    [[ -e /etc/nginx/sites-enabled/default || -L /etc/nginx/sites-enabled/default ]] && cp -a /etc/nginx/sites-enabled/default "$BACKUP_DIR/default.enabled.original"
    [[ -f /var/www/frontend/index.php ]] && cp -a /var/www/frontend/index.php "$BACKUP_DIR/index.php.original"
    touch "$BACKUP_DIR/backup-captured"
fi

echo "[1/6] Menyiapkan DNS sementara untuk instalasi paket"
printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf

echo "[2/6] Menginstal Nginx, PHP-FPM, dan curl"
apt-get -o Acquire::ForceIPv4=true update
apt-get install -y nginx php-fpm php-mysql curl

PHPV="$(find /etc/php -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1)"
if [[ -z "$PHPV" ]]; then echo "ERROR: versi PHP tidak ditemukan di /etc/php."; exit 1; fi
SOCK="/run/php/php${PHPV}-fpm.sock"
echo "PHP version: $PHPV; socket: $SOCK"

mkdir -p /var/www/frontend /run/php
cat > /var/www/frontend/index.php <<'PHP'
<?php
$host = gethostname();
header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="id">
<head><meta charset="UTF-8"><title>Jujutsu High - Frontend</title></head>
<body>
  <h1>Jujutsu High Frontend</h1>
  <p>Dilayani oleh worker: <b><?php echo htmlspecialchars($host, ENT_QUOTES, 'UTF-8'); ?></b></p>
  <p>Hostname sistem: <?php echo htmlspecialchars(gethostname(), ENT_QUOTES, 'UTF-8'); ?></p>
</body>
</html>
PHP
chown -R www-data:www-data /var/www/frontend

echo "[3/6] Mengonfigurasi virtual host dan ACL"
cat > /etc/nginx/sites-available/jujutsu <<EOF
server {
    listen 80 default_server;
    server_name $DOMAIN www.$DOMAIN _;

    root /var/www/frontend;
    index index.php;

    # Frontend hanya menerima trafik dari Gojo dan self-test localhost.
    allow 127.0.0.1;
    allow $PROXY_IP;
    deny all;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$SOCK;
    }

    access_log /var/log/nginx/frontend_access.log;
    error_log  /var/log/nginx/frontend_error.log;
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/jujutsu /etc/nginx/sites-enabled/jujutsu

echo "[4/6] Memulai PHP-FPM"
if command -v service >/dev/null 2>&1; then service "php${PHPV}-fpm" start >/dev/null 2>&1 || true; fi
if ! pgrep -f 'php-fpm: master process' >/dev/null 2>&1; then
    if command -v "php-fpm${PHPV}" >/dev/null 2>&1; then "php-fpm${PHPV}" -D; fi
fi
for i in $(seq 1 15); do [[ -S "$SOCK" ]] && break; sleep 1; done
if [[ ! -S "$SOCK" ]]; then
    echo "ERROR: PHP-FPM socket belum tersedia: $SOCK"
    ps aux | grep '[p]hp-fpm' || true
    exit 1
fi

echo "[5/6] Validasi dan jalankan Nginx"
nginx -t
if pgrep -x nginx >/dev/null 2>&1; then nginx -s reload; else nginx; fi
sleep 1

echo "[6/6] Self-test melalui localhost"
HTTP_CODE="$(curl -sS -o /tmp/soal14-frontend-test.html -w '%{http_code}' -H "Host: $DOMAIN" http://127.0.0.1/ || true)"
echo "HTTP status: $HTTP_CODE"
cat /tmp/soal14-frontend-test.html 2>/dev/null || true
if [[ "$HTTP_CODE" != "200" ]]; then
    echo "ERROR: self-test frontend bukan HTTP 200. Periksa /var/log/nginx/frontend_error.log."
    exit 1
fi

echo
echo "Selesai: $NODE"
echo "Akses langsung dari client seharusnya ditolak (403); Gojo $PROXY_IP diizinkan."
