#!/bin/bash
# Soal 17 - kirara: simpan client IP terverifikasi dari Geto ke MariaDB.
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

WORKER="kirara"
WORKER_IP="192.229.4.18"
GETO_IP="192.229.4.11"
DB_HOST="192.229.4.17"
DOMAIN="jujutsu.k-36.com"

[[ "$(hostname -s)" == "$WORKER" ]] || { echo "ERROR: jalankan di $WORKER, hostname saat ini $(hostname -s)"; exit 1; }
if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${WORKER_IP}/24"; then
  echo "WARNING: IP ${WORKER_IP}/24 tidak ditemukan. IP aktual:"; ip -br addr
fi

printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
if ! command -v nginx >/dev/null 2>&1 || ! command -v php >/dev/null 2>&1; then
  apt-get -o Acquire::ForceIPv4=true update
  apt-get -o Acquire::ForceIPv4=true install -y nginx php-fpm php-mysql curl mariadb-client
fi
PHPV=$(ls /etc/php | sort -V | tail -1)
SOCK="/run/php/php${PHPV}-fpm.sock"
mkdir -p /run/php /var/www/api

mkdir -p /root/backup-soal17-${WORKER}
if [[ -f /var/www/api/api.php && ! -f /root/backup-soal17-${WORKER}/api.php.before ]]; then
  cp -a /var/www/api/api.php /root/backup-soal17-${WORKER}/api.php.before
fi
if [[ -f /etc/nginx/sites-available/jujutsu && ! -f /root/backup-soal17-${WORKER}/jujutsu.before ]]; then
  cp -a /etc/nginx/sites-available/jujutsu /root/backup-soal17-${WORKER}/jujutsu.before
fi

cat > /var/www/api/api.php <<'PHP'
<?php
header('Content-Type: application/json');

$worker = 'kirara';
$trusted = ['192.229.4.11']; // Hanya Geto yang dipercaya sebagai peer.
$peer = $_SERVER['REMOTE_ADDR'] ?? '';
$client_ip = $peer;

// X-Real-IP hanya dipercaya jika koneksi TCP benar-benar berasal dari Geto
// dan nilainya merupakan alamat IP yang valid.
if (in_array($peer, $trusted, true) && !empty($_SERVER['HTTP_X_REAL_IP'])) {
    $xri = trim($_SERVER['HTTP_X_REAL_IP']);
    if (filter_var($xri, FILTER_VALIDATE_IP)) {
        $client_ip = $xri;
    }
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$logged = false;
$error = null;
try {
    $pdo = new PDO(
        'mysql:host=192.229.4.17;dbname=db_shibuya_K36;charset=utf8mb4',
        'k36user', 'K36_pass',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 3]
    );
    $stmt = $pdo->prepare('INSERT INTO request_logs (worker, client_ip, request_path) VALUES (?, ?, ?)');
    $stmt->execute([$worker, $client_ip, $path]);
    $logged = true;
} catch (Throwable $e) {
    http_response_code(500);
    $error = $e->getMessage();
}

echo json_encode([
    'status' => $logged ? 'ok' : 'error',
    'worker' => $worker,
    'client_ip' => $client_ip,
    'proxy_ip' => $peer,
    'logged' => $logged,
    'error' => $error
], JSON_UNESCAPED_SLASHES), "\n";

PHP

chown -R www-data:www-data /var/www/api

cat > /etc/nginx/sites-available/jujutsu <<'NGINX'
server {
    listen 80 default_server;
    server_name jujutsu.k-36.com www.jujutsu.k-36.com _;

    # Client langsung ditolak; Geto dan localhost (self-test) diizinkan.
    allow 127.0.0.1;
    allow 192.229.4.11;
    deny all;

    location ~ ^/api(/.*)?$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /var/www/api/api.php;
        fastcgi_pass unix:@SOCKET@;
    }

    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;
}
NGINX
sed -i "s#@SOCKET@#${SOCK}#g" /etc/nginx/sites-available/jujutsu
ln -sf /etc/nginx/sites-available/jujutsu /etc/nginx/sites-enabled/jujutsu
rm -f /etc/nginx/sites-enabled/default

if ! pgrep -f 'php-fpm: master' >/dev/null 2>&1; then
  service "php${PHPV}-fpm" start >/dev/null 2>&1 || "php-fpm${PHPV}" -D
fi
nginx -t
if pgrep -x nginx >/dev/null 2>&1; then nginx -s reload; else nginx; fi
sleep 1

php -l /var/www/api/api.php
echo "=== Self-test localhost (REMOTE_ADDR/client_ip seharusnya 127.0.0.1) ==="
curl -sS --connect-timeout 3 --max-time 10 -H "Host: ${DOMAIN}" -w '\nHTTP: %{http_code}\n' http://127.0.0.1/api || true
echo "Access log: /var/log/nginx/api_access.log"
