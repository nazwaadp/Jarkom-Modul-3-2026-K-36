#!/bin/bash
# Soal 14 - kirara: Nginx + PHP-FPM API worker, mencatat request ke Yaga
# hanya menerima trafik dari Geto (192.229.4.11)
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

NODE="kirara"
DOMAIN="jujutsu.k-36.com"
LB_IP="192.229.4.11"
DB_HOST="192.229.4.17"
DB_NAME="db_shibuya_K36"
DB_USER="k36user"
DB_PASS="K36_pass"
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
    [[ -f /var/www/api/api.php ]] && cp -a /var/www/api/api.php "$BACKUP_DIR/api.php.original"
    touch "$BACKUP_DIR/backup-captured"
fi

echo "[1/6] Menyiapkan DNS sementara untuk instalasi paket"
printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf

echo "[2/6] Menginstal Nginx, PHP-FPM, driver MySQL, dan client MariaDB"
apt-get -o Acquire::ForceIPv4=true update
apt-get install -y nginx php-fpm php-mysql curl mariadb-client

PHPV="$(find /etc/php -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1)"
if [[ -z "$PHPV" ]]; then echo "ERROR: versi PHP tidak ditemukan di /etc/php."; exit 1; fi
SOCK="/run/php/php${PHPV}-fpm.sock"
echo "PHP version: $PHPV; socket: $SOCK"

mkdir -p /var/www/api /run/php
cat > /var/www/api/api.php <<'PHP'
<?php
header('Content-Type: application/json; charset=UTF-8');
$worker = gethostname();
$client_ip = $_SERVER['REMOTE_ADDR'] ?? null;
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$logged = false;
$error = null;
try {
    $pdo = new PDO(
        'mysql:host=__DB_HOST__;dbname=__DB_NAME__;charset=utf8mb4',
        '__DB_USER__', '__DB_PASS__',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 3]
    );
    $st = $pdo->prepare('INSERT INTO request_logs (worker, client_ip, request_path) VALUES (?, ?, ?)');
    $st->execute([$worker, $client_ip, $path]);
    $logged = true;
} catch (Throwable $e) {
    http_response_code(500);
    $error = $e->getMessage();
}
echo json_encode([
    'status' => $logged ? 'ok' : 'error',
    'worker' => $worker,
    'client_ip' => $client_ip,
    'request_path' => $path,
    'logged' => $logged,
    'error' => $error
], JSON_UNESCAPED_SLASHES) . PHP_EOL;
PHP
sed -i \
    -e "s#__DB_HOST__#$DB_HOST#g" \
    -e "s#__DB_NAME__#$DB_NAME#g" \
    -e "s#__DB_USER__#$DB_USER#g" \
    -e "s#__DB_PASS__#$DB_PASS#g" \
    /var/www/api/api.php
chown -R www-data:www-data /var/www/api
php -l /var/www/api/api.php

echo "[3/6] Mengonfigurasi virtual host dan ACL"
cat > /etc/nginx/sites-available/jujutsu <<EOF
server {
    listen 80 default_server;
    server_name $DOMAIN www.$DOMAIN _;
    root /var/www/api;

    # API hanya menerima trafik dari Geto dan self-test localhost.
    allow 127.0.0.1;
    allow $LB_IP;
    deny all;

    location = /api {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/api/api.php;
        fastcgi_pass unix:$SOCK;
    }

    location ^~ /api/ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/api/api.php;
        fastcgi_pass unix:$SOCK;
    }

    access_log /var/log/nginx/api_access.log;
    error_log  /var/log/nginx/api_error.log;
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

echo "[6/6] Cek koneksi database dan self-test API"
if MYSQL_PWD="$DB_PASS" mysql --connect-timeout=3 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e 'SELECT 1 AS db_connection;' 2>/dev/null; then
    echo "Koneksi database: OK"
else
    echo "WARNING: worker belum dapat mengakses database. Periksa Yaga, grant user, dan koneksi Network 4."
fi
HTTP_CODE="$(curl -sS -o /tmp/soal14-api-test.json -w '%{http_code}' -H "Host: $DOMAIN" http://127.0.0.1/api || true)"
echo "HTTP status: $HTTP_CODE"
cat /tmp/soal14-api-test.json 2>/dev/null || true
if [[ "$HTTP_CODE" != "200" ]]; then
    echo "WARNING: self-test API bukan HTTP 200. Periksa /var/log/nginx/api_error.log dan koneksi DB."
fi

echo
echo "Selesai: $NODE"
echo "Akses langsung dari client seharusnya ditolak (403); Geto $LB_IP diizinkan."
