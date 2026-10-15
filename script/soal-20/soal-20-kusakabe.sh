#!/bin/sh
# Soal 20 - kusakabe: Apache Benchmark, 600 request dengan concurrency 30.
# Pemakaian: sh soal-20-kusakabe.sh baseline
set -eu
LABEL=${1:-run}
OUT=/root/hasil-ab
DOMAIN=jujutsu.k-36.com
mkdir -p "$OUT"

if ! command -v ab >/dev/null 2>&1; then
  echo "[install] Memasang Apache Benchmark (apache2-utils)"
  if command -v apk >/dev/null 2>&1; then
    cp /etc/resolv.conf /tmp/resolv.soal20.bak
    echo "nameserver 192.168.122.1" > /etc/resolv.conf
    apk add --no-cache apache2-utils curl
    cp /tmp/resolv.soal20.bak /etc/resolv.conf
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y apache2-utils curl
  else
    echo "Package manager tidak dikenali; instal Apache Benchmark (ab) terlebih dahulu."
    exit 1
  fi
fi

summ() {
  echo "----- $1 -----"
  grep -E 'Complete requests|Failed requests|Non-2xx responses|Requests per second|Time per request|Time taken for tests' "$2" || true
  grep -E '^ +(50|95|99|100)%' "$2" || true
}

echo "### [$LABEL] Benchmark WEB: ab -l -n 600 -c 30 http://$DOMAIN/"
ab -l -n 600 -c 30 "http://$DOMAIN/" > "$OUT/$LABEL-web.txt" 2>&1 || true
summ "WEB ($LABEL)" "$OUT/$LABEL-web.txt"

echo
echo "### [$LABEL] Benchmark API: ab -l -n 600 -c 30 http://$DOMAIN/api"
ab -l -n 600 -c 30 "http://$DOMAIN/api" > "$OUT/$LABEL-api.txt" 2>&1 || true
summ "API ($LABEL)" "$OUT/$LABEL-api.txt"

echo
echo "Hasil lengkap:"
echo "  $OUT/$LABEL-web.txt"
echo "  $OUT/$LABEL-api.txt"
echo "Pastikan DNS /etc/hosts pada Kusakabe memetakan $DOMAIN ke IP Gojo (192.229.1.4)."
