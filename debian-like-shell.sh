#!/bin/bash

# run under debian-like X86_64 bit distribution

user=$USER
uuid=$(uuidgen)
server_ip=$(ifconfig eth0 | grep 'inet addr' | cut -d ':' -f 2 | tr -d ' [a-zA-Z]')
v2ray_port=18989

if [ $USER != 'root' ]
then
    echo "run as root user."
    exit 1
fi

# upgrade OS
apt-get update > /dev/null 2>&1
apt-get upgrade -y > /dev/null

# basic software
apt-get install -y  vim openssh-server \
                    curl sudo ufw fail2ban \
                    tcptrack htop zsh

# nginx webserver
echo "Install nginx public key"
curl -fsSL http://nginx.org/keys/nginx_signing.key -o - | apt-key add -

# docker-related
echo "Installing docker"
apt-get install -y  apt-transport-https \
                    ca-certificates gnupg2 \
                    software-properties-common > /dev/null 2>&1

# docker gpg key
echo "Installing gpg public key"
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -

add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$ \
                    (. /etc/os-release; echo "$ID") \
                    $(lsb_release -cs) stable"

apt-get update > /dev/null 2>&1

echo "Installing nginx and docker-ce"
apt-get install -y  nginx \
                    docker-ce > /dev/null 2>&1

# Installing v2ray
echo "Installing v2ray"
bash <(curl -L -s https://install.direct/go.sh) > /dev/null 2>&1

# back up v2ray config.json
echo "Backup v2ray config.json"
if [ -f /etc/v2ray/config.json.backup ]
then
    echo "Have backed up config.json"
else
    mv /etc/v2ray/config.json /etc/v2ray/config.json.backup
fi

curl -fsSL https://raw.githubusercontent.com/leollon/my-new-debian-like-on-server/master/server-config.json -o ./config.json


# iptables
ufw enable default
ufw allow 80           # used by nginx webserver
ufw allow 443          # used by https
ufw allow 8080         # used by some test
ufw allow 12022        # used by ssh server
ufw allow $v2ray_port  # used by v2ray


# add customized uuid
sed -i "s/\"id\": \"[a-z0-9_\-]*\"/\"id\": \"$(uuid)\"/" ./config.json
sed -i "s/\"port\": [a-z0-9_]*/\"port\": $(v2ray_port)/" ./config.json
mv ./config.json /etc/v2ray/

# upgrade linux kernel
echo "Downloading and Upgrading linux kernel 4.9.76 for BBR"
curl -fL http://kernel.ubuntu.com//~kernel-ppa/mainline/v4.9.76/linux-image-4.9.76-040976-generic_4.9.76-040976.201801100432_amd64.deb -O
dpkg -i linux-image-4.9.76-040976-generic_4.9.76-040976.201801100432_amd64.deb
update-grub > /dev/null 2>&1
kernel_version=$(uname -r | cut -d '-' -f 1)

# Use BBR algorithm
echo "Use BBR algorithm"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control
lsmod | grep bbr

# Some service automatically start on boot
systemctl enable v2ray.service
systemctl enable ufw.service
systemctl enable fail2ban.service

echo    "                      upgrade os and installation over.           "
echo    "Installed:   'vim, openssh-server, docker-ce, nginx, curl, htop'"
echo -e "\t         'tcptrack, sudo, fail2ban, ufw, v2ray, zsh'"
echo    "port allowed：  webserver port, https port, test port, ssh port"
echo -e "\t\t\t    80         443       8080     12022"
echo -e "v2ray:\t\t  v2ray_server_ip, v2ray_server_port, v2ray_uuid"
echo -e "\t\t\t  $server_ip          $v2ray_port     $uuid\n"
echo -e "\t\t\t  linux kernel version\n"
echo -e "\t\t\t  $kernel_version\n"
echo -e "\t\t\t  shell script over, see ya!\n"
echo -e "\t\t\t  Don't forget to reboot OS！"
exit 0