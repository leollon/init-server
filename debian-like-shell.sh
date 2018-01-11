#!/bin/bash
# run under debian-like x86_64 bit distribution

set -e # The forked shell exits instantlly when one command's returned value is not zero.

user=$USER

if [ $USER != 'root' ]
then
    echo "run as root user."
    exit 1
fi

# upgrade OS
apt update
apt upgrade -y

# basic software
apt install -y  vim openssh-server uuid-runtime\
                    curl sudo ufw fail2ban \
                    tcptrack htop zsh
echo "OK, basic software."

uuid=$(uuidgen)
server_ip=$(ifconfig eth0 | grep 'inet addr' | cut -d ':' -f 2 | tr -d ' [a-zA-Z]')
v2ray_port=18989

# nginx webserver
echo "add nginx public key"
curl -fsSL http://nginx.org/keys/nginx_signing.key -o - | apt-key add -
echo "OK, nginx pulick key added."

# docker-related
echo "Installing docker-related"
apt install -y  apt-transport-https \
                    ca-certificates gnupg2 \
                    software-properties-common > /dev/null 2>&1
echo "OK, docker-reladted installed"

# docker gpg key
echo "Installing gpg public key"
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | apt-key add -
echo "OK, public key added."

echo "add docker repository."
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/$ \
                    (. /etc/os-release; echo "$ID") \
                    $(lsb_release -cs) stable"
echo "OK, docker repository added"

apt update

echo "Installing nginx and docker-ce"
apt install -y  nginx \
                    docker-ce > /dev/null 2>&1
echo "OK, Installed nginx, docker-ce"

# Installing v2ray
echo "Installing v2ray"
bash <(curl -L -s https://install.direct/go.sh) > /dev/null 2>&1
echo "OK, v2ray installed."

# back up v2ray config.json
echo "Backup v2ray config.json"
if [ -f /etc/v2ray/config.json.backup ]
then
    echo "Have backed up config.json"
else
    mv /etc/v2ray/config.json /etc/v2ray/config.json.backup
    echo "OK, Backed up over"
fi

echo "get new v2ray config.json"
curl -fsSL https://raw.githubusercontent.com/leollon/my-new-debian-like-on-server/master/server-config.json -o ./config.json
echo "OK, Done."

# iptables
echo "firewall setting."
ufw enable default
ufw allow 80           # used by nginx webserver
ufw allow 443          # used by https
ufw allow 8080         # used by some test
ufw allow 12022        # used by ssh server
ufw allow $v2ray_port  # used by v2ray
echo "OK,firewall set."


# add customized uuid
echo "set v2ray config.json"
sed -i "s/\"id\": \"[a-z0-9_\-]*\"/\"id\": \"$(uuid)\"/" ./config.json
sed -i "s/\"port\": [a-z0-9_]*/\"port\": $(v2ray_port)/" ./config.json
mv ./config.json /etc/v2ray/
echo "OK, config.json set."

# upgrade linux kernel
echo "Downloading and Upgrading linux kernel 4.9.76 for BBR"
curl -fL http://kernel.ubuntu.com//~kernel-ppa/mainline/v4.9.76/linux-image-4.9.76-040976-generic_4.9.76-040976.201801100432_amd64.deb -O
dpkg -i linux-image-4.9.76-040976-generic_4.9.76-040976.201801100432_amd64.deb
update-grub > /dev/null 2>&1
kernel_version=$(uname -r | cut -d '-' -f 1)
echo "OK, Downloaded and Installed."

# Use BBR algorithm
echo "Use BBR algorithm"
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control
lsmod | grep bbr
echo "OK, BBR usable."

# Some service automatically start on boot
echo "auto-start service on boot."
systemctl enable v2ray.service
systemctl enable ufw.service
systemctl enable fail2ban.service
echo "OK, service set."

echo -e 'create a non-root user?\n'
username=''
read username
echo -e "Remember that password!\n"
echo -e "Remember that password!\n"
echo -e "Remember that password!\n"
useradd $username
echo -e "$username created.\n"
echo "add $username to sudo group?[y/n]"
answer=''
read answer
if [ answer == 'y' ] || [ answer == 'Y' ]
then
    usermod -aG sudo $username
else
    echo -e "$username is not in sudo group."
fi

echo    "                      upgrade os and installation over.           "
echo    "Installed:   'vim, uuid-runtime, openssh-server, docker-ce, nginx, curl'"
echo -e "\t       'htop, tcptrack, sudo, fail2ban, ufw, v2ray, zsh'"
echo    "port allowed：  webserver port, https port, test port, ssh port"
echo -e "\t\t\t    80         443       8080     12022"
echo -e "v2ray:\t\t  v2ray_server_ip, v2ray_server_port, v2ray_uuid"
echo -e "\t\t\t  $server_ip          $v2ray_port     $uuid"
echo -e "\t\t  linux kernel version    non-root-user"
echo -e "\t\t  $kernel_version           $username"
echo -e "\t\t\t  shell script over, see ya!"
echo -e "\t\t\t  Don't forget to reboot OS！"
exit 0