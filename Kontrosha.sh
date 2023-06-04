#!/bin/bash
#This script will help you complete the final test effortlessly, everything is configured automatically and without your participation. 
#You will only need to specify passwords for user accounts
#Author: Griban Ilya
#All rights belong to him)

#All very ugly variables
#Network ifaces
network="
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
        address 10.0.0.1
        netmask 255.255.255.0

auto eth2
iface eth2 inet static
        address 172.16.0.1
        netmask 255.255.255.0"
#DHCP config
DHCP="
subnet 172.16.0.0 netmask 255.255.255.0 {
        range 172.16.0.2 172.16.0.10;
        option routers 172.16.0.1;
        option domain-name-servers 172.16.0.1;
}

subnet 10.0.0.0 netmask 255.255.255.0 {
        range 10.0.0.2 10.0.0.10;
        option routers 10.0.0.1;
        option domain-name-servers 10.0.0.1;
}"
#SMB config
SMB="
[students]
comment = students
path = /data/students
public = no
writable = yes
read only = no
guest ok = no
valid users = admin, teacher, student
create mask = 0777
directory mask = 0777
force create mode = 0777
force directory mode = 0777

[teachers]
comment = teachers
path = /data/teachers
public = no
writable = yes
read only = no
guest ok = no
valid users = teacher, admin 
create mask = 0777
directory mask = 0777
force create mode = 0777
force directory mode = 0777

[apps]
comment = apps
path = /data/apps
public = no
writable = yes
read only = no
guest ok = no
valid users = admin 
create mask = 0777
directory mask = 0777
force create mode = 0777
force directory mode = 0777
"


#Start huge fun and all the action
#Configuring network repositories
echo "deb https://mirror.yandex.ru/debian bullseye main contrib non-free
deb https://mirror.yandex.ru/debian bullseye-backports main contrib non-free
deb https://mirror.yandex.ru/debian bullseye-updates main contrib non-free
" > /etc/apt/sources.list
#Installing the necessary packages
apt update;
apt install unzip bind9 nginx openssl php7.4 php7.4-fpm php7.4-mysql mariadb-server isc-dhcp-server samba -y;


#Configuring network ifaces
echo "$network" > /etc/network/interfaces
#Config Router mode
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
#Network subsystem reboot
systemctl restart networking.service;
#Configuration DHCP
sed -i 's/INTERFACESv4=""/INTERFACESv4="eth1 eth2"/' /etc/default/isc-dhcp-server
echo "$DHCP" > /etc/dhcp/dhcpd.conf
systemctl enable isc-dhcp-server;
systemctl restart isc-dhcp-server;


#Config SSH for root login and "22 port?)"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
systemctl restart sshd;


#Make new directories
mkdir -p /data/students/ & chmod 777 /data/students;
mkdir –p /data/teachers/ & chmod 777 /data/teachers;
mkdir –p /data/apps/ & chmod 777 /data/apps;
#Make new userss
echo "Set passwd -> P@ssw0rd"
adduser student
adduser teacher
adduser admin
smbpasswd -a student;
smbpasswd -a teacher;
smbpasswd -a admin;
#Config samba
echo "${SMB}" >> /etc/samba/smb.conf
systemctl restart smbd;


#Config DNS
echo '
zone "mgok" {
        type master;
        file "/etc/bind/db.mgok";
}; ' >> /etc/bind/named.conf.default-zones

echo "
;
; BIND data file for local loopback interface
;
$TTL    604800
@       IN      SOA     srv. root.srv. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      srv.
@       IN      A       10.0.0.1
it-school       IN      A       10.0.0.1
" > /etc/bind/db.mgok
systemctl restart bind9;

#Config NGINX
echo 'server {
    listen              443 ssl;
    server_name         it-school.mgok;
    set $root_path /data/site;
    ssl_certificate     /var/www/cert.pem;
    ssl_certificate_key /var/www/privkey.pem;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
	location / {
		root $root_path;
		index index.php;
	}

	location ~\.php$ {
		fastcgi_pass unix:/run/php/php7.4-fpm.sock;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME $root_path$fastcgi_script_name;
		include fastcgi_params;
		fastcgi_param DOCUMENT_ROOT $root_path;
		fastcgi_read_timeout 300;
	}
}' > /etc/nginx/sites-available/default
systemctl restart nginx.service;