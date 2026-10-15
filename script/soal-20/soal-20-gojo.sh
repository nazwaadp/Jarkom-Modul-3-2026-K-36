#!/bin/bash
# Soal 20 - gojo: toggle rate limit dan analisis access/error log.
# Pemakaian: bash soal-20-gojo.sh off | on | analyze
set -euo pipefail
LOG=/var/log/nginx/gojo_access.log
ERR=/var/log/nginx/gojo_error.log
SNIP=/etc/nginx/snippets/gojo_ratelimit.conf

if [ "$(id -u)" -ne 0 ]; then
  echo "Jalankan sebagai root."
  exit 1
fi

reload_n() {
  nginx -t
  nginx -s reload
  sleep 1
  : > "$LOG"
  : > "$ERR"
  echo "Nginx direload dan log dikosongkan untuk pengujian berikutnya."
}

analyze() {
  echo "================ ANALISIS ACCESS LOG GOJO ================"
  echo "Total request tercatat: $(wc -l < "$LOG")"
  echo
  echo "-- Jumlah per status code (semua path) --"
  grep -oE ' status=[0-9]+' "$LOG" | sort | uniq -c || true
  echo
  echo "-- Path / (frontend) --"
  grep 'req="GET / ' "$LOG" | grep -oE ' status=[0-9]+' | sort | uniq -c || true
  echo "Cache status:"
  grep 'req="GET / ' "$LOG" | grep -oE ' cache=[A-Z-]+' | sort | uniq -c || true
  echo
  echo "-- Path /api --"
  grep 'req="GET /api' "$LOG" | grep -oE ' status=[0-9]+' | sort | uniq -c || true
  echo
  echo "========== KLASIFIKASI =========="
  echo "Ditolak rate limit (429): $(grep -c ' status=429 ' "$LOG" || true)"
  echo "Gagal aplikasi (500): $(grep -c ' status=500 ' "$LOG" || true)"
  echo "Gagal koneksi/proxy (502/504/499): $(grep -cE ' status=(502|504|499) ' "$LOG" || true)"
  echo "Sukses 2xx: $(grep -cE ' status=2[0-9][0-9] ' "$LOG" || true)"
  echo
  echo "-- Indikasi pada error.log --"
  echo "Pesan rate limiting: $(grep -c 'limiting requests' "$ERR" || true)"
  echo "Connect failed/timeout: $(grep -cE 'connect\\(\\) failed|timed out' "$ERR" || true)"
  echo
  echo "Catatan: status 500 menunjukkan error aplikasi/upstream; 502/504/499 mengindikasikan masalah proxy/koneksi atau klien terputus."
}

case "${1:-}" in
  off)
    printf '# Rate limit /api dinonaktifkan untuk baseline\n' > "$SNIP"
    reload_n
    echo "Rate limit OFF."
    ;;
  on)
    printf 'limit_req zone=api_limit burst=5 nodelay;\nlimit_req_status 429;\n' > "$SNIP"
    reload_n
    echo "Rate limit ON: 10r/s per IP, burst=5, nodelay, status penolakan 429."
    ;;
  analyze)
    analyze
    ;;
  *)
    echo "Pemakaian: $0 {off|on|analyze}"
    exit 2
    ;;
esac
