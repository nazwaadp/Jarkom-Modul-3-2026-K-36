# Jarkom-Modul-3-2026-K-36

**Kelompok** : K-36

**Anggota** :

| Nama                    | NRP        |
| ----------------------- | ---------- |
| Nazwa Aulia Dwi Purnomo | 5027251018 |
| Putri Permata Sabila    | 5027251047 |

## Soal 11 — DNS Master dan DNS Slave

Utahime dan Shoko ditugaskan membangun sistem penamaan domain resmi agar seluruh pos tidak perlu menghafal alamat IP mentah. Konfigurasikan BIND9 pada **utahime** sebagai **DNS Master** dan **shoko** sebagai **DNS Slave** untuk mengelola domain **jujutsu.<xxxx>.com**. Atur SOA record, NS delegasi untuk kedua server, dan terapkan **allow-transfer** dari Master ke Slave. Pastikan file zona berhasil tersinkronisasi otomatis ke shoko saat nomor serial di utahime dinaikkan, lalu buktikan dengan melakukan query **dig** ke kedua server dari salah satu client.

### Tujuan

- Mengonfigurasi Utahime sebagai DNS Master dan Shoko sebagai DNS Slave.
- Membuat record SOA dan NS untuk domain `jujutsu.k-36.com`.
- Mengatur transfer zona dari Master ke Slave.
- Membuktikan sinkronisasi serial zona dan menguji query DNS dari client.

### Langkah Pengerjaan

#### A. DNS Master — Utahime

IP Utahime adalah `192.229.1.2`, sedangkan IP Shoko adalah `192.229.1.3`.

Konfigurasi zona di `/etc/bind/named.conf.local`:

```conf
zone "jujutsu.k-36.com" {
    type master;
    file "/etc/bind/db.jujutsu.k-36.com";
    allow-transfer { 192.229.1.3; };
    also-notify { 192.229.1.3; };
    notify yes;
};
```

File `/etc/bind/db.jujutsu.k-36.com` berisi record SOA, NS untuk kedua DNS, dan A record untuk alamat server.

```dns
$TTL 86400
@ IN SOA ns1.jujutsu.k-36.com. hostmaster.jujutsu.k-36.com. (
    2026101401
    3600
    900
    1209600
    86400
)

@   IN NS ns1.jujutsu.k-36.com.
@   IN NS ns2.jujutsu.k-36.com.

ns1 IN A 192.229.1.2
ns2 IN A 192.229.1.3
```

Validasi konfigurasi:

```bash
named-checkconf -z
named-checkzone jujutsu.k-36.com /etc/bind/db.jujutsu.k-36.com
```

**Expected:** zona berhasil dimuat dan hasil `named-checkzone` berakhir dengan `OK`.

![1](image/SS11-01-validasi-master.png)

Periksa konfigurasi transfer:

```bash
cat /etc/bind/named.conf.local
```

**Expected:** terlihat `type master` dan `allow-transfer { 192.229.1.3; };`.

![2](image/SS11-02-konfigurasi-master.png)

#### B. DNS Slave — Shoko

Konfigurasi di `/etc/bind/named.conf.local`:

```conf
zone "jujutsu.k-36.com" {
    type slave;
    file "/var/cache/bind/db.jujutsu.k-36.com";
    masters { 192.229.1.2; };
};
```

Validasi konfigurasi:

```bash
named-checkconf
```

Periksa file zona hasil transfer:

```bash
ls -lh /var/cache/bind/
```

**Expected:** file `db.jujutsu.k-36.com` tersedia setelah transfer berhasil.

![3](image/SS11-03-konfigurasi-slave.png) <br>
![4](image/SS11-04-file-zona-slave.png)

#### C. Pengujian sinkronisasi serial

Di Utahime, periksa serial awal:

```bash
dig @192.229.1.2 jujutsu.k-36.com SOA +noall +answer
```

Serial awal: `2026101401`.

![5](image/SS11-05-serial-sebelum.png)

Setelah memastikan serial saat ini benar-benar `2026101401`, naikkan menjadi `2026101402` pada file zona dan validasi kembali:

```bash
sed -i 's/2026101401/2026101402/' /etc/bind/db.jujutsu.k-36.com
named-checkzone jujutsu.k-36.com /etc/bind/db.jujutsu.k-36.com
```

**Expected:** hasil validasi menampilkan serial `2026101402` dan `OK`.

Setelah validasi berhasil, muat ulang zona Master menggunakan mekanisme BIND yang berjalan pada node, kemudian periksa kembali:

```bash
dig @192.229.1.2 jujutsu.k-36.com SOA +noall +answer
```

**Expected:** serial Master berubah menjadi `2026101402`.

![6](image/SS11-06-serial-sesudah-master.png)

Di Shoko, periksa serial:

```bash
dig @192.229.1.3 jujutsu.k-36.com SOA +noall +answer
```

**Expected:** serial Shoko ikut menjadi `2026101402`.

![7](image/SS11-07-sinkronisasi-slave.png)

#### D. Pengujian dari client

Dari client yang sudah terhubung ke jaringan, jalankan:

```bash
dig @192.229.1.2 jujutsu.k-36.com SOA +noall +answer
dig @192.229.1.3 jujutsu.k-36.com SOA +noall +answer
```

**Expected:** kedua server memberikan jawaban SOA dengan serial yang sama. Client harus memiliki alamat IPv4 dan rute yang benar agar dapat menjangkau Network 1.

![8](image/SS11-08-query-dari-client.png)

### Hasil dan Analisis

Konfigurasi dinyatakan berhasil apabila Utahime dapat melayani zona `jujutsu.k-36.com`, Shoko menerima file zona melalui transfer DNS, dan serial pada kedua server sama setelah pembaruan. Query `dig` dari client juga harus berhasil pada kedua server.

Jika file zona belum tersedia atau serial Shoko belum berubah, periksa log BIND dan aturan `allow-transfer` sebelum menyatakan pengujian berhasil.

### Kesimpulan

Pada praktikum ini, Utahime dikonfigurasi sebagai DNS Master dan Shoko sebagai DNS Slave. Record SOA dan NS digunakan untuk mendefinisikan zona, sedangkan `allow-transfer` membatasi penerima transfer zona. Keberhasilan sinkronisasi dibuktikan dengan kesamaan serial SOA setelah pembaruan dan keberhasilan query DNS dari client.

## Soal 12 — A Record, CNAME, Reverse DNS (PTR), dan DNS Forwarder

Peta domain harus memetakan pintu masuk utama dan tetap bisa mencari alamat di luar kawasan Shibuya. Pada **utahime**, buat A record `jujutsu.<xxxx>.com` yang mengarah ke gojo, serta CNAME `www` yang merujuk ke domain utama tersebut. Buat pula Reverse DNS (zona PTR) untuk melacak IP gojo kembali ke domain resminya, dan aktifkan fitur DNS Forwarder pada BIND9 mengarah ke IP gateway internet (`192.168.122.1`). Uji dari client dengan `dig` untuk mengecek CNAME, PTR, dan buktikan client tetap bisa melakukan ping ke domain internet seperti `google.com`.

### Tujuan

- Memetakan domain utama `jujutsu.k-36.com` ke IP Gojo menggunakan A record.
- Membuat alias `www` menggunakan CNAME.
- Membuat reverse DNS (PTR) untuk IP Gojo.
- Mengaktifkan DNS Forwarder ke `192.168.122.1` untuk query domain eksternal.
- Membuktikan hasil DNS dari client melalui `dig` dan menguji resolusi serta konektivitas `google.com`.

### Informasi konfigurasi

| Komponen             | Nilai                    |
| -------------------- | ------------------------ |
| Kelompok             | K-36                     |
| Domain               | `jujutsu.k-36.com`       |
| Utahime (DNS Master) | `192.229.1.2`            |
| Shoko (DNS Slave)    | `192.229.1.3`            |
| Gojo                 | `192.229.1.4`            |
| DNS Forwarder        | `192.168.122.1`          |
| Reverse zone         | `1.229.192.in-addr.arpa` |

### Langkah pengerjaan

#### A. Utahime — DNS Master

Salin script `soal-12.sh` ke `/root/` pada node Utahime, kemudian jalankan:

```bash
chmod +x /root/soal-12.sh
/root/soal-12.sh
```

Script mengatur DNS forwarder ke `192.168.122.1`, mendeklarasikan forward zone dan reverse zone, membuat A record untuk domain utama, CNAME `www`, dan record PTR untuk IP Gojo. Script lalu memvalidasi konfigurasi dan menampilkan hasil query awal.

Validasi manual yang digunakan:

```bash
named-checkconf -z
named-checkzone jujutsu.k-36.com /etc/bind/db.jujutsu.k-36.com
named-checkzone 1.229.192.in-addr.arpa /etc/bind/db.192.229.1
```

**Expected:** `named-checkconf -z` tidak menampilkan error; kedua perintah `named-checkzone` memuat zona masing-masing dan berakhir dengan `OK`.

#### B. Shoko — DNS Slave

Setelah Utahime berhasil, salin `soal-12.sh` ke `/root/` pada node Shoko, kemudian jalankan:

```bash
chmod +x /root/soal-12.sh
/root/soal-12.sh
```

Script mengatur forward zone dan reverse zone sebagai Slave dengan Utahime (`192.229.1.2`) sebagai Master, lalu mengaktifkan konfigurasi DNS forwarder. File zona Slave diharapkan diterima melalui zone transfer dan berada di `/var/cache/bind/`.

Periksa dengan:

```bash
named-checkconf
ls -lh /var/cache/bind/
```

#### C. Pengujian DNS dan forwarder dari client

Jalankan tes berikut pada client yang sudah memiliki IPv4, gateway, dan koneksi ke Network 1. Contoh menggunakan Utahime sebagai server DNS yang ditanya.

**A record:**

```bash
dig @192.229.1.2 jujutsu.k-36.com A +noall +answer
```

Expected: record A mengembalikan IP Gojo, yaitu `192.229.1.4`.

**CNAME `www`:**

```bash
dig @192.229.1.2 www.jujutsu.k-36.com CNAME +noall +answer
```

Expected: CNAME `www.jujutsu.k-36.com.` mengarah ke `jujutsu.k-36.com.`.

**PTR Gojo:**

```bash
dig @192.229.1.2 -x 192.229.1.4 +noall +answer
```

Expected: PTR untuk `4.1.229.192.in-addr.arpa.` mengarah ke `jujutsu.k-36.com.`.

**DNS forwarder dan ping:**

```bash
dig @192.229.1.2 google.com A +noall +answer
ping -c 4 google.com
```

Expected: query `google.com` mengembalikan satu atau lebih alamat IP. Ping harus dapat melakukan resolusi nama; balasan ICMP bergantung pada konektivitas dan apakah host tujuan mengizinkan ICMP.

### Dokumentasi screenshot

#### Validasi DNS dan konfigurasi forwarder

**Node:** Utahime. Screenshot harus menampilkan `hostname`, hasil `named-checkconf -z`, hasil validasi forward dan reverse zone, serta konfigurasi forwarder.

Perintah:

```bash
hostname
named-checkconf -z
named-checkzone jujutsu.k-36.com /etc/bind/db.jujutsu.k-36.com
named-checkzone 1.229.192.in-addr.arpa /etc/bind/db.192.229.1
grep -E 'forwarders|forward first' /etc/bind/named.conf.options
```

Expected: kedua zona valid dengan hasil `OK`; forwarder menunjukkan `192.168.122.1`.

![1](image/SS12-01-validasi-dns-utahime.png)

#### Pengujian A record, CNAME, dan PTR dari client

**Node:** client yang sudah terkoneksi. Screenshot harus menampilkan hasil ketiga query berikut.

```bash
hostname
dig @192.229.1.2 jujutsu.k-36.com A +noall +answer
dig @192.229.1.2 www.jujutsu.k-36.com CNAME +noall +answer
dig @192.229.1.2 -x 192.229.1.4 +noall +answer
```

Expected: A record mengarah ke IP Gojo; CNAME `www` mengarah ke domain utama; PTR IP Gojo mengarah ke `jujutsu.k-36.com.`.

![2](image/SS12-02-pengujian-a-cname-ptr.png)

#### Pengujian DNS forwarder dan ping Google

**Node:** client yang sama. Screenshot harus menampilkan query ke `google.com` dan hasil ping.

```bash
dig @192.229.1.2 google.com A +noall +answer
ping -c 4 google.com
```

Expected: query DNS mengembalikan alamat IP. Ping melakukan resolusi nama; balasan paket bergantung pada konektivitas dan kebijakan ICMP tujuan.

![3](image/SS12-03-forwarder-ping-google.png)

### Analisis dan kesimpulan

A record memetakan domain utama ke IP Gojo, CNAME menjadikan `www` alias dari domain utama, dan PTR memungkinkan pencarian balik dari IP Gojo ke nama domain. DNS forwarder meneruskan query eksternal ke `192.168.122.1`.

Soal dinyatakan berhasil apabila validasi forward dan reverse zone tidak menunjukkan error, ketiga query A/CNAME/PTR mengembalikan record yang diharapkan, serta query `google.com` melalui Utahime berhasil. Pengujian dari client harus dilakukan setelah konektivitas client ke DNS berfungsi. Cantumkan hasil aktual dan jangan menyatakan pengujian sukses apabila output belum sesuai expected.

## Soal 13 — MariaDB Master dan Slave

Kepala Sekolah Yaga dan Inumaki mendirikan database terpusat yang redundan agar log aktivitas kutukan tetap aman tersimpan. Konfigurasikan MariaDB pada **yaga** sebagai **DB-Master** dan **inumaki** sebagai **DB-Slave**. Buat database `db_shibuya_<xxxx>` beserta tabel `request_logs` di Master, aktifkan binary logging (`log-bin`, `server-id`), lalu hubungkan Inumaki sebagai Slave yang menyalin data secara realtime dengan `CHANGE MASTER TO`. Berikan hak akses remote bagi seluruh node di Network 4, lalu buktikan replikasi berhasil dengan memasukkan data baru di Master dan memeriksa hasilnya di Slave.

### Tujuan

- Menyiapkan Yaga sebagai MariaDB Master dan Inumaki sebagai MariaDB Slave.
- Membuat database `db_shibuya_K36` dan tabel `request_logs`.
- Mengaktifkan binary logging dan menetapkan `server-id` yang unik.
- Memberikan hak remote untuk node Network 4 dan hak replikasi bagi Inumaki.
- Membuktikan replikasi melalui status Slave dan pengujian data baru.

### Informasi Node

| Komponen             | Nilai            |
| -------------------- | ---------------- |
| Kelompok             | K-36             |
| Yaga (Master)        | `192.229.4.17`   |
| Inumaki (Slave)      | `192.229.4.18`   |
| Database             | `db_shibuya_K36` |
| Tabel                | `request_logs`   |
| Master `server-id`   | `1`              |
| Slave `server-id`    | `2`              |
| User replikasi       | `repl`           |
| User aplikasi remote | `k36user`        |

### Langkah Pengerjaan

#### A. Konfigurasi Master — Yaga

Simpan script `soal-13.sh` di `/root` pada node Yaga, lalu jalankan:

```bash
chmod +x /root/soal-13.sh
/root/soal-13.sh
```

Script memasang MariaDB jika belum ada, menyiapkan konfigurasi `bind-address = 0.0.0.0`, `server-id = 1`, `log_bin`, dan `binlog_format = ROW`. Script juga membuat database `db_shibuya_K36`, tabel `request_logs`, user replikasi `repl`, dan user remote `k36user` yang dibatasi untuk host Network 4 (`192.229.4.%`).

Validasi di Yaga:

```bash
mysql -e "SHOW GLOBAL VARIABLES WHERE Variable_name IN ('server_id','log_bin','bind_address','binlog_format');"
mysql -e "SHOW MASTER STATUS\\G"
mysql -e "SHOW DATABASES LIKE 'db_shibuya_K36'; USE db_shibuya_K36; DESCRIBE request_logs;"
mysql -e "SELECT User, Host FROM mysql.user WHERE User IN ('repl','k36user');"
```

**Expected:** `server_id` bernilai `1`, `log_bin` bernilai `ON`, `bind_address` bernilai `0.0.0.0`, `SHOW MASTER STATUS` menampilkan file dan posisi binary log, dan tabel `request_logs` tersedia.

![1](image/SS13-01-validasi-master-yaga.png) <br>
![2](image/SS13-02-database-user-yaga.png)

#### B. Konfigurasi Slave — Inumaki

Jalankan script Yaga sampai selesai terlebih dahulu. Setelah itu, simpan `soal-13.sh` di `/root` pada node Inumaki, lalu jalankan:

```bash
chmod +x /root/soal-13.sh
/root/soal-13.sh
```

Script memasang MariaDB jika diperlukan, menetapkan `server-id = 2`, mengaktifkan `relay_log`, mengatur `read_only = 1`, membuat schema dan tabel lokal yang sesuai, mengambil posisi binary log dari Master, lalu mengatur replikasi menggunakan `CHANGE MASTER TO` dengan `MASTER_LOG_FILE` dan `MASTER_LOG_POS`.

Validasi status replikasi di Inumaki:

```bash
mysql -e "SHOW SLAVE STATUS\\G" | grep -E 'Master_Host:|Master_User:|Master_Log_File:|Read_Master_Log_Pos:|Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:|Last_IO_Error:|Last_SQL_Error:'
```

**Expected:** `Master_Host` adalah `192.229.4.17`, `Slave_IO_Running: Yes`, `Slave_SQL_Running: Yes`, dan tidak ada pesan error pada `Last_IO_Error` maupun `Last_SQL_Error`. `Seconds_Behind_Master` umumnya `0` atau mendekati `0` saat tidak ada antrean.

![3](image/SS13-03-status-slave-inumaki.png)

#### C. Uji replikasi data

Lakukan pengujian dari Inumaki. Perintah pertama mengirim `INSERT` melalui koneksi remote ke Yaga menggunakan user aplikasi, kemudian perintah kedua memeriksa apakah baris yang sama sudah muncul pada database lokal Inumaki.

```bash
MYSQL_PWD='K36_pass' mysql --protocol=tcp -h 192.229.4.17 -uk36user db_shibuya_K36 -e "INSERT INTO request_logs(worker,client_ip,request_path) VALUES ('soal13-test','192.229.4.18','/soal13-replication-test'); SELECT id,worker,client_ip,request_path,created_at FROM request_logs WHERE request_path='/soal13-replication-test' ORDER BY id DESC LIMIT 1;"

sleep 2
mysql -e "SELECT id,worker,client_ip,request_path,created_at FROM db_shibuya_K36.request_logs WHERE request_path='/soal13-replication-test' ORDER BY id DESC LIMIT 5;"
```

**Expected:** perintah pertama menampilkan baris yang baru dimasukkan ke Master. Setelah replikasi diproses, query lokal pada Inumaki menampilkan baris dengan `worker = soal13-test` dan `request_path = /soal13-replication-test`.

Jika baris belum muncul, jalankan `SHOW SLAVE STATUS\\G` dan periksa `Last_IO_Error` serta `Last_SQL_Error`; jangan menyimpulkan replikasi berhasil sebelum data tampak pada Slave.

![4](image/SS13-04-uji-replikasi-data.png)

### Analisis

Yaga bertindak sebagai sumber utama data. Binary logging merekam perubahan yang terjadi pada Master, sedangkan Inumaki menggunakan konfigurasi replikasi untuk membaca dan menerapkan perubahan tersebut. `server-id` dibuat berbeda (`1` pada Yaga dan `2` pada Inumaki) agar kedua server dapat dibedakan dalam topologi replikasi.

User `repl` diberi hak replikasi dari Network 4, sedangkan `k36user` diberi akses ke database `db_shibuya_K36` dari alamat dalam subnet `192.229.4.0/24`. Replikasi dinyatakan berhasil jika kedua thread Slave berstatus `Yes` dan data uji yang dimasukkan melalui Master akhirnya dapat dibaca di Slave.

Script menggunakan posisi file dan posisi binary log dari `SHOW MASTER STATUS` pada `CHANGE MASTER TO`. Karena posisi diambil setelah schema awal disiapkan, script juga memastikan database dan tabel yang sama tersedia pada Inumaki sebelum replikasi dimulai.

### Kesimpulan

MariaDB pada Yaga dikonfigurasi sebagai Master dengan binary logging, database `db_shibuya_K36`, dan tabel `request_logs`. Inumaki dikonfigurasi sebagai Slave dengan `server-id` yang berbeda dan relay log. Keberhasilan dibuktikan melalui status replikasi `Slave_IO_Running: Yes` dan `Slave_SQL_Running: Yes`, serta data uji yang dimasukkan pada Master dan muncul pada Slave.

## Soal 14 — Frontend dan API Worker dengan Nginx, PHP-FPM, dan MariaDB

Para penyihir lapangan bersiaga di Data Center sebagai pekerja backend untuk memproses aplikasi. Pasang Nginx dan PHP-FPM pada **maki** dan **panda** untuk menyajikan web frontend yang menampilkan hostname masing-masing. Pada **nanami**, **todo**, dan **kirara**, siapkan layanan API yang mencatat log request ke database **yaga**. Konfigurasikan virtual host agar worker merespons domain layanan yang ditentukan. Batasi akses langsung dari klien ke worker, web worker hanya menerima trafik melalui jalur proxy web yang ditentukan, sedangkan worker API hanya menerima trafik melalui **geto**. Uji bahwa akses langsung dari klien ditolak, sementara akses melalui reverse proxy tetap berhasil.

### Tujuan

- Memasang Nginx dan PHP-FPM pada Maki serta Panda untuk frontend yang menampilkan hostname worker.
- Membuat API di Nanami, Todo, dan Kirara yang mencatat request ke `yaga`.
- Menyediakan virtual host untuk `jujutsu.k-36.com` dan `www.jujutsu.k-36.com`.
- Membatasi frontend agar hanya menerima trafik dari Gojo (`192.229.1.4`) dan API dari Geto (`192.229.4.11`), dengan localhost diizinkan untuk self-test.
- Membuktikan akses langsung dari client ditolak dan jalur melalui proxy berhasil.

### Node dan konfigurasi

| Node                 | Fungsi          | Nilai penting                                                   |
| -------------------- | --------------- | --------------------------------------------------------------- |
| Maki, Panda          | Frontend worker | Allowed proxy: Gojo `192.229.1.4`                               |
| Nanami, Todo, Kirara | API worker      | Allowed proxy: Geto `192.229.4.11`                              |
| Yaga                 | MariaDB         | `192.229.4.17`, database `db_shibuya_K36`, tabel `request_logs` |
| Virtual host         | Domain layanan  | `jujutsu.k-36.com`, `www.jujutsu.k-36.com`                      |

### Prasyarat

1. Soal 13 di Yaga telah berhasil dan `db_shibuya_K36.request_logs` tersedia.
2. User remote `k36user` dapat mengakses database dari worker Network 4.
3. IP Gojo `192.229.1.4`, Geto `192.229.4.11`, dan Yaga `192.229.4.17` sesuai alokasi kelompok.
4. Routing antarjaringan aktif dan setiap worker memiliki alamat IPv4 yang benar.
5. Gojo/Geto akan menjadi proxy yang diizinkan oleh ACL. Pengujian end-to-end melalui proxy dilakukan setelah konfigurasi Soal 15–16 tersedia.

### Script per node

| Node     | File script         |
| -------- | ------------------- |
| `maki`   | `soal-14-maki.sh`   |
| `panda`  | `soal-14-panda.sh`  |
| `nanami` | `soal-14-nanami.sh` |
| `todo`   | `soal-14-todo.sh`   |
| `kirara` | `soal-14-kirara.sh` |

Untuk setiap node, salin isi file script yang sesuai ke `/root`. Contoh pada Maki:

```bash
nano /root/soal-14-maki.sh
chmod +x /root/soal-14-maki.sh
/root/soal-14-maki.sh
```

### Penjelasan script

#### A. Maki dan Panda — frontend

Script melakukan pemeriksaan root/hostname, membuat backup konfigurasi yang ada, memasang Nginx, PHP-FPM, dan `curl`, lalu membuat `/var/www/frontend/index.php`. Halaman PHP menampilkan hostname sistem menggunakan `gethostname()`.

Virtual host menggunakan domain `jujutsu.k-36.com` dan `www.jujutsu.k-36.com`. Aturan Nginx `allow 127.0.0.1`, `allow 192.229.1.4`, dan `deny all` memungkinkan self-test localhost dan trafik dari Gojo, sekaligus menolak sumber lain.

Script kemudian memulai PHP-FPM, menjalankan `nginx -t`, memulai atau me-reload Nginx, dan melakukan self-test melalui localhost. Expected: HTTP 200 dan isi halaman menampilkan `maki` atau `panda` sesuai node.

#### B. Nanami, Todo, dan Kirara — API

Script memasang Nginx, PHP-FPM, `php-mysql`, `curl`, dan `mariadb-client`; lalu membuat `/var/www/api/api.php`. Endpoint `/api` membaca hostname worker, alamat sumber yang terlihat oleh worker, dan path request. Endpoint kemudian memasukkan data ke tabel `request_logs` pada Yaga melalui database `db_shibuya_K36` dan user `k36user`.

Virtual host mengizinkan localhost untuk self-test dan Geto (`192.229.4.11`) untuk trafik API, sedangkan sumber lain ditolak dengan `deny all`. Script memvalidasi sintaks PHP dan konfigurasi Nginx, memeriksa koneksi DB, lalu meminta endpoint lokal `/api`.

Expected saat seluruh dependency tersedia: HTTP 200 dan JSON dengan `status: ok`, hostname worker yang benar, dan `logged: true`. Jika DB tidak dapat dijangkau, API akan melaporkan error dan HTTP 500; periksa Soal 13, grant remote, routing, dan log. Pada Soal 14, `client_ip` mencatat IP sumber yang terlihat worker (biasanya Geto ketika melalui Geto). Penerusan IP asli dikerjakan pada Soal 17.

### Cara cek setiap node

#### Maki

```bash
hostname
ip -4 -br addr
nginx -t
pgrep -a nginx
pgrep -af 'php-fpm: master process'
curl -i -H 'Host: jujutsu.k-36.com' http://127.0.0.1/
```

Expected: `nginx -t` menampilkan `syntax is ok` dan `test is successful`; self-test memberi HTTP `200 OK` dan HTML menampilkan hostname `maki`.

#### Panda

```bash
hostname
ip -4 -br addr
nginx -t
curl -i -H 'Host: jujutsu.k-36.com' http://127.0.0.1/
```

Expected: HTTP `200 OK` dan HTML menampilkan hostname `panda`.

#### Nanami

```bash
hostname
ip -4 -br addr
nginx -t
php -l /var/www/api/api.php
MYSQL_PWD='K36_pass' mysql --connect-timeout=3 -h 192.229.4.17 -u k36user db_shibuya_K36 -e 'SELECT 1 AS db_connection;'
curl -i -H 'Host: jujutsu.k-36.com' http://127.0.0.1/api
```

Expected: PHP menyatakan `No syntax errors detected`, query DB mengembalikan `1`, dan API mengembalikan HTTP 200 dengan JSON `status: ok`, `worker: nanami`, `logged: true`.

#### Todo dan Kirara

Jalankan pada node masing-masing:

```bash
hostname
ip -4 -br addr
nginx -t
php -l /var/www/api/api.php
MYSQL_PWD='K36_pass' mysql --connect-timeout=3 -h 192.229.4.17 -u k36user db_shibuya_K36 -e 'SELECT 1 AS db_connection;'
curl -i -H 'Host: jujutsu.k-36.com' http://127.0.0.1/api
```

Expected JSON untuk Todo menampilkan `worker: todo`; untuk Kirara menampilkan `worker: kirara`. Keduanya diharapkan `status: ok` dan `logged: true` jika koneksi database berhasil.

### Uji pembatasan akses

#### A. Catat IP worker

Jalankan `ip -4 -br addr` pada node terkait. Ganti `<IP_MAKI>` dan `<IP_NANAMI>` berikut dengan IP aktual dari Master Sheet, tanpa tanda `< >`:

```bash
curl -i --max-time 5 -H 'Host: jujutsu.k-36.com' http://<IP_MAKI>/
curl -i --max-time 5 -H 'Host: jujutsu.k-36.com' http://<IP_NANAMI>/api
```

Jalankan dari client yang memiliki routing menuju Network 4. Expected jika request mencapai Nginx: `HTTP/1.1 403 Forbidden`. Timeout atau `network unreachable` berarti konektivitas/routing belum benar dan **bukan** bukti ACL berhasil.

#### B. Uji jalur proxy yang diizinkan

Frontend mengizinkan Gojo (`192.229.1.4`); API mengizinkan Geto (`192.229.4.11`). Setelah routing antarjaringan aktif, uji dari node Gojo ke IP Maki/Panda dan dari node Geto ke IP Nanami/Todo/Kirara. Expected dari sumber proxy yang diizinkan: frontend HTTP 200, API HTTP 200 serta JSON sukses.

Pengujian end-to-end melalui domain publik dilakukan setelah Soal 15–16 (Geto load balancer dan Gojo reverse proxy) selesai. Dari client:

```bash
curl -i -H 'Host: jujutsu.k-36.com' http://192.229.1.4/
curl -i -H 'Host: jujutsu.k-36.com' http://192.229.1.4/api
```

Expected setelah konfigurasi proxy tersedia: `/` menampilkan halaman dari Maki/Panda dan `/api` menampilkan JSON dari worker API.

### Bukti request tersimpan di Yaga

Setelah endpoint API merespons sukses, pada Yaga jalankan:

```bash
mysql db_shibuya_K36 -e "SELECT id,worker,client_ip,request_path,created_at FROM request_logs ORDER BY id DESC LIMIT 10;"
```

Expected: baris request terbaru muncul di tabel `request_logs`, dengan nilai `worker` sesuai node API yang melayani request.

### Dokumentasi screenshot

#### Frontend Maki

Buktikan `nginx -t`, self-test localhost HTTP 200, dan hostname `maki`.

![1](image/SS14-01a-frontend-maki.png)

#### Frontend Panda

Buktikan self-test localhost HTTP 200 dan hostname `panda`.

![2](image/SS14-01b-frontend-panda.png)

#### API workers

Ambil bukti self-test API pada Nanami, Todo, dan Kirara dengan JSON sukses serta `logged: true`. Bisa berupa tiga hasil terminal yang digabung dalam bagian yang sama.

![3](image/SS14-02-api-workers.png)

#### Request log di Yaga

Buktikan request dari endpoint API benar-benar tersimpan di tabel `request_logs`.

![4](image/SS14-03-request-logs-yaga.png)

#### Akses langsung ditolak

Buktikan client yang tidak diizinkan mendapatkan HTTP 403 ketika mengakses langsung satu frontend worker dan satu API worker. Pastikan hasilnya bukan timeout atau network unreachable.

![5](image/SS14-04-direct-access-403.png)

#### Akses melalui proxy

Ambil setelah konfigurasi Soal 15–16 selesai. Bukti harus menunjukkan `/` berhasil melalui Gojo dan `/api` berhasil melalui Geto/Gojo sesuai konfigurasi proxy.

![6-after-15&16](image/SS14-05-proxy-access-success.png)

### Analisis

Maki dan Panda menyajikan halaman frontend yang menunjukkan hostname masing-masing. ACL Nginx mengizinkan sumber Gojo dan menolak client lain. Nanami, Todo, dan Kirara menyajikan endpoint `/api` dan mencatat worker, alamat sumber yang terlihat, serta path request ke database Yaga. ACL API mengizinkan Geto sebagai jalur masuk dan localhost untuk self-test.

Jika API menghasilkan HTTP 500 atau `logged: false`, endpoint sudah terpanggil tetapi pencatatan database gagal. Pemeriksaan harus difokuskan pada status Yaga, akses remote user `k36user`, routing worker ke Yaga, serta log API/Nginx.

HTTP 403 saat koneksi mencapai worker membuktikan ACL menolak sumber yang tidak diizinkan. Timeout dan `network unreachable` adalah masalah jaringan, bukan bukti penolakan ACL. Pengujian jalur proxy dilakukan setelah konfigurasi terkait pada Soal 15–16 siap.

### Kesimpulan

Maki dan Panda dikonfigurasi sebagai frontend worker menggunakan Nginx dan PHP-FPM, sedangkan Nanami, Todo, dan Kirara menyediakan API yang mencatat request ke `db_shibuya_K36.request_logs` pada Yaga. Virtual host menggunakan `jujutsu.k-36.com`, dengan ACL yang membatasi frontend hanya untuk Gojo dan API hanya untuk Geto (selain localhost untuk self-test). Keberhasilan akhir dibuktikan melalui self-test, pencatatan database, akses langsung yang ditolak, dan akses melalui proxy yang berhasil setelah konfigurasi proxy terkait tersedia.

## Soal 15 — Nginx Internal Load Balancer dengan Weighted Round Robin

Geto bertugas mengendalikan pembagian beban request API di internal Data Center agar server tidak tumbang bersamaan. Konfigurasikan **Nginx pada geto sebagai Load Balancer internal** dengan upstream `api_cluster` yang mengarahkan trafik ke **nanami** dan **todo**. Terapkan algoritma **Weighted Round Robin** dengan bobot **3:1**, di mana nanami menerima porsi beban tiga kali lebih banyak daripada todo. Buktikan distribusi beban ini dengan melakukan loop request berulang kali ke geto dari jaringan lokal Data Center dan periksa rasio responsnya.

### Tujuan

- Mengonfigurasi Nginx pada Geto sebagai internal load balancer.
- Mengarahkan request ke worker API Nanami dan Todo melalui upstream `api_cluster`.
- Menerapkan Weighted Round Robin dengan bobot Nanami:Todo sebesar 3:1.
- Menguji banyak request ke Geto dan menghitung worker yang melayani request.
- Memeriksa access log Geto untuk memastikan distribusi request benar-benar menuju kedua upstream.

### Informasi node

| Komponen               | Hostname | IP yang digunakan script |
| ---------------------- | -------- | ------------------------ |
| Internal load balancer | `geto`   | `192.229.4.11`           |
| API worker utama 1     | `nanami` | `192.229.4.14`           |
| API worker utama 2     | `todo`   | `192.229.4.15`           |
| Domain Host header     | —        | `jujutsu.k-36.com`       |

### Konfigurasi dan cara menjalankan

Simpan script di `/root/soal-15.sh` pada node **Geto**. Cara membuat file:

```bash
nano /root/soal-15.sh
```

Tempel isi script `soal-15.sh`, simpan dengan `Ctrl+O`, tekan `Enter`, lalu keluar menggunakan `Ctrl+X`. Setelah itu jalankan:

```bash
chmod +x /root/soal-15.sh
/root/soal-15.sh
```

Script memeriksa hostname dan IP Geto, memasang Nginx serta curl jika belum tersedia, membuat backup konfigurasi `api_lb` sebelumnya, menyiapkan upstream dan access log, memvalidasi konfigurasi dengan `nginx -t`, lalu menjalankan Nginx.

Konfigurasi inti upstream:

```nginx
upstream api_cluster {
    server 192.229.4.14:80 weight=3;
    server 192.229.4.15:80 weight=1;
}
```

- `192.229.4.14 weight=3` membuat Nanami menerima bobot tiga.
- `192.229.4.15 weight=1` membuat Todo menerima bobot satu.
- `proxy_pass http://api_cluster;` meneruskan request ke kumpulan worker tersebut.
- Nginx menggunakan Weighted Round Robin secara default jika metode balancing lain tidak ditentukan.
- Log `/var/log/nginx/geto_lb.log` menyimpan alamat upstream untuk setiap request.

Script juga melakukan self-test 40 request menuju `http://127.0.0.1/api`, lalu menghitung HTTP status dan nama worker pada JSON respons. Pastikan Nanami dan Todo sudah aktif serta endpoint API masing-masing sudah lolos pengujian Soal 14 sebelum menjalankan pengujian distribusi.

### Pemeriksaan konfigurasi

Di Geto, jalankan:

```bash
hostname
nginx -t
cat /etc/nginx/sites-available/api_lb
```

Expected:

- `hostname` menghasilkan `geto`.
- `nginx -t` menampilkan `syntax is ok` dan `test is successful`.
- Konfigurasi memperlihatkan upstream `api_cluster` dengan `weight=3` untuk Nanami dan `weight=1` untuk Todo.

Periksa juga proses Nginx:

```bash
pgrep -a nginx
```

### Pengujian distribusi beban

Jalankan dari Geto setelah konfigurasi aktif:

```bash
for i in $(seq 1 40); do
    curl -sS --connect-timeout 3 --max-time 8 \
      -H 'Host: jujutsu.k-36.com' http://127.0.0.1/api
    echo
done | grep -oE '"worker":"(nanami|todo)"' | sort | uniq -c
```

Expected output ideal untuk 40 request yang seluruhnya berhasil:

```text
     30 "worker":"nanami"
     10 "worker":"todo"
```

Ini merepresentasikan rasio 3:1 (sekitar 75% request ke Nanami dan 25% ke Todo). Catat hasil aktual. Jika angkanya berbeda, jangan langsung mengklaim distribusi sesuai; periksa apakah ada request gagal, respons API bukan JSON sukses, atau salah satu worker tidak tersedia.

Untuk melihat status HTTP dan respons worker secara jelas, jalankan:

```bash
for i in $(seq 1 10); do
    curl -sS -o /tmp/geto-api.out -w 'HTTP %{http_code}\n' \
      -H 'Host: jujutsu.k-36.com' http://127.0.0.1/api
    cat /tmp/geto-api.out
    echo
done
```

Expected: masing-masing request sukses dengan HTTP `200`, serta JSON menampilkan `"status":"ok"`, nama worker (`nanami` atau `todo`), dan `"logged":true` jika pencatatan ke database Yaga berhasil.

### Pemeriksaan access log

Setelah loop request, jalankan di Geto:

```bash
tail -n 20 /var/log/nginx/geto_lb.log
```

Expected: baris log menampilkan request `/api`, status HTTP, dan `upstream=192.229.4.14:80` atau `upstream=192.229.4.15:80`.

Hitung jumlah request pada log yang mengarah ke setiap worker:

```bash
grep -c 'upstream=192.229.4.14:80' /var/log/nginx/geto_lb.log
grep -c 'upstream=192.229.4.15:80' /var/log/nginx/geto_lb.log
```

Perintah `grep -c` menghitung semua baris yang cocok di file log, bukan hanya pengujian terakhir. Jika ingin menghitung percobaan tertentu saja, bersihkan atau salin log terlebih dahulu sebelum loop pengujian baru, atau gunakan file log terpisah untuk pengujian tersebut.

### Dokumentasi screenshot

#### Validasi dan konfigurasi upstream

Jalankan di Geto:

```bash
clear
hostname
nginx -t
grep -A5 -B1 'upstream api_cluster' /etc/nginx/sites-available/api_lb
```

Expected: hostname `geto`, validasi Nginx sukses, dan konfigurasi menampilkan Nanami `weight=3` serta Todo `weight=1`.

![1](image/SS15-01-validasi-upstream-geto.png)

#### Distribusi 40 request

Jalankan loop 40 request pada Bagian 6. Pastikan output jumlah worker terlihat.

![2](image/SS15-02-distribusi-40-request.png)

#### Access log Geto

Jalankan:

```bash
 tail -n 20 /var/log/nginx/geto_lb.log
```

Expected: log menunjukkan alamat upstream Nanami dan Todo, request `/api`, serta status HTTP.

![3](image/SS15-03-access-log-geto.png)

### Analisis hasil

Weighted Round Robin membagikan request berdasarkan bobot yang ditetapkan. Dengan bobot Nanami 3 dan Todo 1, proporsi teoritisnya adalah 3/4 atau 75% untuk Nanami dan 1/4 atau 25% untuk Todo. Untuk 40 request sukses, distribusi idealnya adalah 30 request ke Nanami dan 10 request ke Todo.

Respons JSON dari worker membuktikan node yang melayani tiap request, sedangkan access log Geto memperlihatkan alamat upstream yang dipilih Nginx. Kedua bukti tersebut perlu konsisten. Jika jumlah request sukses kurang dari 40 atau salah satu worker gagal, hasil aktual harus dilaporkan apa adanya dan kendalanya dianalisis.

### Kesimpulan

Nginx pada Geto dikonfigurasi sebagai internal load balancer menggunakan upstream `api_cluster`. Bobot Nanami dan Todo diatur 3:1 dengan metode Weighted Round Robin. Keberhasilan diuji melalui validasi Nginx, loop 40 request dari Geto, pemeriksaan JSON worker, dan access log upstream. Load balancing dapat dinyatakan sesuai rancangan apabila kedua worker menerima request dan distribusi aktual mendekati rasio bobot 3:1 tanpa kegagalan request yang tidak terjelaskan.

## Soal 16 — Public Reverse Proxy Gojo dengan Path-Based Routing

Gojo berdiri di perbatasan DMZ sebagai gerbang publik tunggal bagi seluruh client dari luar maupun dalam. Konfigurasikan **Nginx** pada **gojo** untuk melayani domain **jujutsu.<xxxx>.com** dan **www.jujutsu.<xxxx>.com** menggunakan metode **Path-Based Routing**. Atur agar request root (`/`) diteruskan secara Round Robin ke worker frontend (maki dan panda), sedangkan request ke path `/api` diteruskan langsung ke geto. Uji dari client Divisi A atau B bahwa akses ke web utama dibalas oleh Maki/Panda, sedangkan akses ke `/api` diteruskan dan dijawab oleh Nanami/Todo.

### Tujuan

- Mengonfigurasi Gojo sebagai public reverse proxy Nginx.
- Meneruskan request `/` secara Round Robin ke Maki dan Panda.
- Meneruskan request `/api` ke Geto sebagai internal load balancer.
- Membuktikan routing melalui pengujian client dan access log Gojo.

### IP dan domain

| Komponen | IP / nilai         |
| -------- | ------------------ |
| Domain   | `jujutsu.k-36.com` |
| Gojo     | `192.229.1.4`      |
| Maki     | `192.229.4.12`     |
| Panda    | `192.229.4.13`     |
| Geto     | `192.229.4.11`     |

### Script dan cara menjalankan

Script dijalankan **hanya di node `gojo`**. Simpan file yang disediakan sebagai `/root/soal-16.sh`:

```bash
nano /root/soal-16.sh
```

Salin isi file `soal-16.sh`, lalu simpan (`Ctrl+O`, `Enter`, `Ctrl+X`). Jalankan:

```bash
chmod +x /root/soal-16.sh
/root/soal-16.sh
```

Script memasang Nginx/curl jika belum tersedia, membuat upstream frontend dan Geto, memvalidasi Nginx dengan `nginx -t`, menyalakan atau me-reload Nginx, lalu menjalankan self-test.

### Penjelasan konfigurasi

- `upstream frontend_cluster` berisi Maki (`192.229.4.12`) dan Panda (`192.229.4.13`). Karena tidak diberi bobot khusus, Nginx menggunakan Round Robin secara default.
- `upstream geto_lb` mengarahkan request API ke Geto (`192.229.4.11`).
- `location ^~ /api` meneruskan request `/api` ke Geto.
- `location /` meneruskan request frontend ke `frontend_cluster`.
- `proxy_set_header Host $host` meneruskan hostname request ke backend.
- `gojo_access.log` mencatat request, status HTTP, serta upstream yang dipilih.

### Pengujian dan dokumentasi screenshot

#### Validasi konfigurasi Gojo

**Node:** `gojo`

```bash
clear
hostname
nginx -t
grep -nE 'server_name|upstream frontend_cluster|server 192\.229\.4\.(12|13|11)|location \^~ /api|location /|proxy_pass' /etc/nginx/sites-available/gojo
```

**Expected output:** hostname `gojo`; `nginx -t` menunjukkan `syntax is ok` dan `test is successful`; konfigurasi memperlihatkan upstream Maki/Panda, upstream Geto, dan dua aturan routing.
![1](image/SS16-01-validasi-gojo.png)

#### Pengujian routing dari client

**Node:** client Network 2 atau Network 3 yang sudah terhubung.

Jalankan beberapa request frontend untuk melihat Round Robin:

```bash
for i in 1 2 3 4; do
  echo "===== FRONTEND REQUEST $i ====="
  curl -sS --connect-timeout 3 --max-time 10 \
    -H 'Host: jujutsu.k-36.com' "http://192.229.1.4/?test=$i"
  echo
done
```

Kemudian uji API:

```bash
curl -i --connect-timeout 3 --max-time 15 \
  -H 'Host: jujutsu.k-36.com' http://192.229.1.4/api
```

**Expected output:** request `/` mengembalikan HTTP 200 dan HTML menyebut worker `maki` atau `panda`; request `/api` mengembalikan respons API sukses dengan HTTP 200 dan JSON menyebut worker API (misalnya `nanami` atau `todo`) serta `logged: true`. Jika muncul timeout, `network unreachable`, 403 yang tidak diharapkan, 500, atau 502, jangan menyatakan pengujian berhasil—periksa konektivitas, ACL worker, Geto, serta database.

![2](image/SS16-02-client-path-routing.png)

#### Verifikasi access log Gojo

**Node:** `gojo`

Setelah pengujian client dilakukan, jalankan:

```bash
tail -n 30 /var/log/nginx/gojo_access.log
```

**Expected output:** baris log menunjukkan path dan status request serta `ups=` dengan alamat upstream. Request frontend harus diarahkan ke Maki/Panda, sedangkan request `/api` diarahkan ke Geto (`192.229.4.11`).

![3](image/SS16-03-access-log-gojo.png)

### Analisis dan kesimpulan

Gojo menggunakan Nginx sebagai public reverse proxy dengan Path-Based Routing. Request ke `/` diteruskan ke Maki dan Panda menggunakan Round Robin, sedangkan request `/api` diteruskan ke Geto untuk diproses oleh worker API. Hasil pengujian client dan access log digunakan untuk memeriksa jalur request yang aktual. Kesimpulan bahwa konfigurasi berhasil hanya dibuat jika hasil nyata sesuai expected output.
