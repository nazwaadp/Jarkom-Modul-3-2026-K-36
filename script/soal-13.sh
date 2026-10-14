#!/bin/bash
# Soal 13 - yaga: MariaDB Master (192.229.4.17)
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

MASTER_IP="192.229.4.17"
SLAVE_IP="192.229.4.18"
DB_NAME="db_shibuya_K36"
REPL_USER="repl"
REPL_PASS="K36_repl"
APP_USER="k36user"
APP_PASS="K36_pass"
NODE="$(hostname -s)"

if [[ "$NODE" != "yaga" ]]; then
  echo "ERROR: Jalankan script ini pada node yaga (hostname sekarang: $NODE)."
  exit 1
fi
if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${MASTER_IP}/24"; then
  echo "ERROR: IP ${MASTER_IP}/24 tidak ditemukan di yaga."
  ip -4 -br addr
  exit 1
fi

echo "=== SOAL 13: MARIADB MASTER / YAGA ==="
echo "[1/5] Menyiapkan DNS untuk instalasi bila diperlukan..."
if ! command -v mariadbd >/dev/null 2>&1 || ! command -v mysql >/dev/null 2>&1; then
  if [[ ! -e /root/resolv.conf.before-soal13 ]]; then
    cp -a /etc/resolv.conf /root/resolv.conf.before-soal13
  fi
  printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
  apt-get -o Acquire::ForceIPv4=true update
  apt-get install -y mariadb-server mariadb-client
fi

mkdir -p /root/backup-soal13 /run/mysqld /var/log/mysql
chown mysql:mysql /run/mysqld /var/log/mysql
CONFIG="/etc/mysql/mariadb.conf.d/99-k36-master.cnf"
if [[ -f "$CONFIG" && ! -f /root/backup-soal13/99-k36-master.cnf.original ]]; then
  cp -a "$CONFIG" /root/backup-soal13/99-k36-master.cnf.original
fi

echo "[2/5] Mengatur konfigurasi Master..."
cat > "$CONFIG" <<'CNF'
[mysqld]
bind-address = 0.0.0.0
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
CNF
chown root:root "$CONFIG"
chmod 0644 "$CONFIG"

# Inisialisasi hanya jika datadir memang belum pernah dibuat.
if [[ ! -d /var/lib/mysql/mysql ]]; then
  if command -v mariadb-install-db >/dev/null 2>&1; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
  else
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
  fi
fi

start_or_restart_db() {
  # Hentikan instance lama terlebih dahulu agar konfigurasi baru benar-benar dibaca.
  if mysqladmin ping >/dev/null 2>&1; then
    mysqladmin shutdown >/dev/null 2>&1 || true
    for _ in $(seq 1 10); do
      mysqladmin ping >/dev/null 2>&1 || break
      sleep 1
    done
  fi
  if command -v service >/dev/null 2>&1; then
    service mariadb start >/dev/null 2>&1 || service mysql start >/dev/null 2>&1 || true
  fi
  if ! mysqladmin ping >/dev/null 2>&1; then
    if command -v mariadbd-safe >/dev/null 2>&1; then
      nohup mariadbd-safe --user=mysql >/root/soal-13-mariadb.log 2>&1 &
    elif command -v mysqld_safe >/dev/null 2>&1; then
      nohup mysqld_safe --user=mysql >/root/soal-13-mariadb.log 2>&1 &
    else
      echo "ERROR: Tidak menemukan mariadbd-safe/mysqld_safe."
      exit 1
    fi
  fi
  for _ in $(seq 1 30); do
    mysqladmin ping >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "ERROR: MariaDB belum siap. Log terakhir:"
  tail -n 50 /root/soal-13-mariadb.log 2>/dev/null || true
  exit 1
}

start_or_restart_db

echo "[3/5] Membuat database, tabel, dan user remote/replikasi..."
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE TABLE IF NOT EXISTS \`${DB_NAME}\`.request_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  worker VARCHAR(50) NOT NULL,
  client_ip VARCHAR(45) DEFAULT NULL,
  request_path VARCHAR(255) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE USER IF NOT EXISTS '${REPL_USER}'@'192.229.4.%' IDENTIFIED BY '${REPL_PASS}';
ALTER USER '${REPL_USER}'@'192.229.4.%' IDENTIFIED BY '${REPL_PASS}';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${REPL_USER}'@'192.229.4.%';
CREATE USER IF NOT EXISTS '${APP_USER}'@'192.229.4.%' IDENTIFIED BY '${APP_PASS}';
ALTER USER '${APP_USER}'@'192.229.4.%' IDENTIFIED BY '${APP_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${APP_USER}'@'192.229.4.%';
FLUSH PRIVILEGES;
SQL

echo "[4/5] Memverifikasi binary logging dan konfigurasi..."
mysql -N -e "SHOW GLOBAL VARIABLES WHERE Variable_name IN ('server_id','log_bin','bind_address','binlog_format');"
LOG_BIN="$(mysql -N -e "SHOW GLOBAL VARIABLES LIKE 'log_bin';" | awk '{print $2}')"
if [[ "$LOG_BIN" != "ON" ]]; then
  echo "ERROR: log_bin belum ON. Periksa konfigurasi MariaDB dan log startup."
  exit 1
fi

mysql -e "SHOW MASTER STATUS\\G"
echo
echo "=== DATABASE DAN TABEL ==="
mysql -e "SHOW DATABASES LIKE '${DB_NAME}'; USE \`${DB_NAME}\`; SHOW TABLES; DESCRIBE request_logs;"
echo
echo "=== USER REMOTE/REPLIKASI ==="
mysql -e "SELECT User, Host FROM mysql.user WHERE User IN ('${REPL_USER}','${APP_USER}');"
echo
echo "Selesai: Yaga siap sebagai MariaDB Master. Jalankan script Inumaki setelah ini."

#!/bin/bash
# Soal 13 - inumaki: MariaDB Slave (192.229.4.18)
# Dijalankan SETELAH Yaga berhasil.
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

MASTER_IP="192.229.4.17"
SLAVE_IP="192.229.4.18"
DB_NAME="db_shibuya_K36"
REPL_USER="repl"
REPL_PASS="K36_repl"
NODE="$(hostname -s)"

if [[ "$NODE" != "inumaki" ]]; then
  echo "ERROR: Jalankan script ini pada node inumaki (hostname sekarang: $NODE)."
  exit 1
fi
if ! ip -o -4 addr show | awk '{print $4}' | grep -Fxq "${SLAVE_IP}/24"; then
  echo "ERROR: IP ${SLAVE_IP}/24 tidak ditemukan di inumaki."
  ip -4 -br addr
  exit 1
fi

echo "=== SOAL 13: MARIADB SLAVE / INUMAKI ==="
echo "[1/5] Menyiapkan DNS untuk instalasi bila diperlukan..."
if ! command -v mariadbd >/dev/null 2>&1 || ! command -v mysql >/dev/null 2>&1; then
  if [[ ! -e /root/resolv.conf.before-soal13 ]]; then
    cp -a /etc/resolv.conf /root/resolv.conf.before-soal13
  fi
  printf 'nameserver 192.168.122.1\n' > /etc/resolv.conf
  apt-get -o Acquire::ForceIPv4=true update
  apt-get install -y mariadb-server mariadb-client
fi

mkdir -p /root/backup-soal13 /run/mysqld /var/log/mysql
chown mysql:mysql /run/mysqld /var/log/mysql
CONFIG="/etc/mysql/mariadb.conf.d/99-k36-slave.cnf"
if [[ -f "$CONFIG" && ! -f /root/backup-soal13/99-k36-slave.cnf.original ]]; then
  cp -a "$CONFIG" /root/backup-soal13/99-k36-slave.cnf.original
fi

echo "[2/5] Mengatur konfigurasi Slave..."
cat > "$CONFIG" <<'CNF'
[mysqld]
bind-address = 0.0.0.0
server-id = 2
relay_log = /var/log/mysql/relay-bin
read_only = 1
CNF
chown root:root "$CONFIG"
chmod 0644 "$CONFIG"

if [[ ! -d /var/lib/mysql/mysql ]]; then
  if command -v mariadb-install-db >/dev/null 2>&1; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
  else
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
  fi
fi

start_or_restart_db() {
  # Hentikan instance lama terlebih dahulu agar konfigurasi baru benar-benar dibaca.
  if mysqladmin ping >/dev/null 2>&1; then
    mysqladmin shutdown >/dev/null 2>&1 || true
    for _ in $(seq 1 10); do
      mysqladmin ping >/dev/null 2>&1 || break
      sleep 1
    done
  fi
  if command -v service >/dev/null 2>&1; then
    service mariadb start >/dev/null 2>&1 || service mysql start >/dev/null 2>&1 || true
  fi
  if ! mysqladmin ping >/dev/null 2>&1; then
    if command -v mariadbd-safe >/dev/null 2>&1; then
      nohup mariadbd-safe --user=mysql >/root/soal-13-mariadb.log 2>&1 &
    elif command -v mysqld_safe >/dev/null 2>&1; then
      nohup mysqld_safe --user=mysql >/root/soal-13-mariadb.log 2>&1 &
    else
      echo "ERROR: Tidak menemukan mariadbd-safe/mysqld_safe."
      exit 1
    fi
  fi
  for _ in $(seq 1 30); do
    mysqladmin ping >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "ERROR: MariaDB belum siap. Log terakhir:"
  tail -n 50 /root/soal-13-mariadb.log 2>/dev/null || true
  exit 1
}

start_or_restart_db

echo "[3/5] Memastikan database dan tabel tersedia di Slave..."
# Schema dibuat di Slave juga karena replication dimulai dari posisi binlog saat ini,
# setelah database/tabel awal sudah dibuat pada Master.
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE TABLE IF NOT EXISTS \`${DB_NAME}\`.request_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  worker VARCHAR(50) NOT NULL,
  client_ip VARCHAR(45) DEFAULT NULL,
  request_path VARCHAR(255) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# Tunggu Master dapat dijangkau melalui user replikasi dan dapat membaca posisi binlog.
echo "[4/5] Mengambil posisi binary log dari Master..."
MASTER_STATUS=""
for I in $(seq 1 10); do
  MASTER_STATUS="$(MYSQL_PWD="$REPL_PASS" mysql --protocol=tcp --connect-timeout=3 -h "$MASTER_IP" -u"$REPL_USER" -N -B -e "SHOW MASTER STATUS" 2>/dev/null || true)"
  if [[ -n "$MASTER_STATUS" ]]; then
    break
  fi
  echo "Menunggu Master... ($I/10)"
  sleep 2
done

if [[ -z "$MASTER_STATUS" ]]; then
  echo "ERROR: Tidak bisa mengambil SHOW MASTER STATUS dari Yaga."
  echo "Pastikan script Yaga berhasil, user repl diizinkan, dan port TCP 3306 dapat dijangkau."
  exit 1
fi
MASTER_LOG_FILE="$(awk 'NR==1 {print $1}' <<< "$MASTER_STATUS")"
MASTER_LOG_POS="$(awk 'NR==1 {print $2}' <<< "$MASTER_STATUS")"
if [[ -z "$MASTER_LOG_FILE" || ! "$MASTER_LOG_POS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Posisi binlog tidak terbaca. Output SHOW MASTER STATUS:"
  printf '%s\n' "$MASTER_STATUS"
  exit 1
fi
printf 'Master log file: %s\nMaster log position: %s\n' "$MASTER_LOG_FILE" "$MASTER_LOG_POS"

# Konfigurasi replikasi menggunakan file/posisi binlog klasik MariaDB.
mysql -e "STOP SLAVE;" >/dev/null 2>&1 || true
mysql -e "RESET SLAVE ALL;" >/dev/null 2>&1 || true
mysql <<SQL
CHANGE MASTER TO
  MASTER_HOST='${MASTER_IP}',
  MASTER_PORT=3306,
  MASTER_USER='${REPL_USER}',
  MASTER_PASSWORD='${REPL_PASS}',
  MASTER_LOG_FILE='${MASTER_LOG_FILE}',
  MASTER_LOG_POS=${MASTER_LOG_POS},
  MASTER_CONNECT_RETRY=5;
START SLAVE;
SQL

sleep 4
echo "[5/5] Status replikasi Slave..."
STATUS="$(mysql -e "SHOW SLAVE STATUS\\G")"
printf '%s\n' "$STATUS" | grep -E 'Master_Host:|Master_User:|Master_Log_File:|Read_Master_Log_Pos:|Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:|Last_IO_Error:|Last_SQL_Error:' || true
if ! grep -q 'Slave_IO_Running: Yes' <<< "$STATUS" || ! grep -q 'Slave_SQL_Running: Yes' <<< "$STATUS"; then
  echo "PERINGATAN: Kedua thread Slave belum berstatus Yes. Periksa Last_IO_Error/Last_SQL_Error di SHOW SLAVE STATUS\\G."
  exit 1
fi

echo
echo "=== DATABASE DAN TABEL SLAVE ==="
mysql -e "SHOW DATABASES LIKE '${DB_NAME}'; USE \`${DB_NAME}\`; SHOW TABLES;"
echo "Selesai: Inumaki aktif sebagai MariaDB Slave."
