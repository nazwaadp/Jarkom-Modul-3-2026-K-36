# Network 4 (lokal, tanpa pool dinamis)
subnet 192.229.4.0 netmask 255.255.255.0 {
}

#Penambahan unttuk nomor 4
# Network 2 (Divisi A)
class "pool1" {
    match if substring(hardware, 1, 6) = 02:42:17:b9:c8:00 or
             substring(hardware, 1, 6) = 02:42:a2:57:11:00;
}

class "pool2" {
    match if substring(hardware, 1, 6) = 02:42:86:ff:fd:00 or
             substring(hardware, 1, 6) = 02:42:70:fc:e9:00;
}

subnet 192.229.2.0 netmask 255.255.255.0 {
    option routers 192.229.2.1;
    option broadcast-address 192.229.2.255;

    pool {
        allow members of "pool1";
        range 192.229.2.10 192.229.2.35;
    }

    pool {
        allow members of "pool2";
        range 192.229.2.70 192.229.2.95;
    }
}
