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

| Komponen | Nilai |
|---|---|
| Kelompok | K-36 |
| Domain | `jujutsu.k-36.com` |
| Utahime (DNS Master) | `192.229.1.2` |
| Shoko (DNS Slave) | `192.229.1.3` |
| Gojo | `192.229.1.4` |
| DNS Forwarder | `192.168.122.1` |
| Reverse zone | `1.229.192.in-addr.arpa` |

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

| Komponen | Nilai |
|---|---|
| Kelompok | K-36 |
| Yaga (Master) | `192.229.4.17` |
| Inumaki (Slave) | `192.229.4.18` |
| Database | `db_shibuya_K36` |
| Tabel | `request_logs` |
| Master `server-id` | `1` |
| Slave `server-id` | `2` |
| User replikasi | `repl` |
| User aplikasi remote | `k36user` |

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

