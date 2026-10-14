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
| Gojo (sesuai konfigurasi script; verifikasi dengan Master Sheet) | `192.229.1.4` |
| DNS Forwarder | `192.168.122.1` |
| Reverse zone | `1.229.192.in-addr.arpa` |

> Pastikan IP Gojo `192.229.1.4` sesuai tabel alokasi IP kelompok. Jika berbeda, sesuaikan `GOJO_IP` dan record PTR sebelum menjalankan script.

### Langkah pengerjaan

#### A. Utahime — DNS Master

Salin script `soal-12-utahime.sh` ke `/root/` pada node Utahime, kemudian jalankan:

```bash
chmod +x /root/soal-12-utahime.sh
/root/soal-12-utahime.sh
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

Setelah Utahime berhasil, salin `soal-12-shoko.sh` ke `/root/` pada node Shoko, kemudian jalankan:

```bash
chmod +x /root/soal-12-shoko.sh
/root/soal-12-shoko.sh
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

Expected: record A mengembalikan IP Gojo, yaitu `192.229.1.4` jika sesuai tabel IP kelompok.

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
clear
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
clear
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

