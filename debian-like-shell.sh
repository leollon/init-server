#!/bin/bash
# run under debian-like x86_64 bit distribution

set -e # The forked shell exits instantly when one command\'s returned value is not zero.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NOCOLOR='\033[0m'
username=''
password=''

if [ "${USER}" != "root" ]
then
    echo -e "${RED}run as root user.${NOCOLOR}"
    exit 1
fi

# upgrade OS
apt-get update && apt-get upgrade -y && apt-get autoremove --purge -y

# basic software
apt-get install -qq  vim openssh-server uuid-runtime \
                    curl sudo ufw fail2ban \
                    tcptrack htop zsh
echo -e "${GREEN}OK, basic software installed.${NOCOLOR}"

UUID=$(uuidgen)
CODENAME=$(lsb_release -cs)
ID=$(grep -i "^id=" /etc/os-release | cut -d '=' -f2)
V2RAY_CLIENT_PORT=1080
V2RAY_SERVER_PORT=18989
SERVER_IP=$(curl http://ipinfo.io/ip)

# nginx gpg public key
echo -e "${YELLOW}adding nginx gpg public key.${NOCOLOR}"
curl -fsSL http://nginx.org/keys/nginx_signing.key -o - | apt-key add -
echo -e "${GREEN}OK, nginx gpg pulick key added.${NOCOLOR}"

# nginx's source.list
echo -e "deb http://nginx.org/packages/mainline/debian/ $CODENAME nginx\ndeb-src http://nginx.org/packages/mainline/debian/ $CODENAME nginx" > /etc/apt/sources.list.d/nginx.list

# docker gpg key
echo -e "${YELLOW}adding gpg public key."
curl -fsSL https://download.docker.com/linux/"${ID}"/gpg | apt-key add -
echo -e "${GREEN}OK, docker gpg public key added.${NOCOLOR}"

# docker-related
echo -e "${GREEN}Installing docker-related.${NOCOLOR}"
apt-get install -qq  apt-transport-https \
                    ca-certificates gnupg2 \
                    software-properties-common
echo -e "${GREEN}OK, docker-related installed.${NOCOLOR}"

echo -e "${YELLOW}add docker repository.${NOCOLOR}"
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/${ID} ${CODENAME} stable"
echo -e "${GREEN}OK, docker repository added.${NOCOLOR}"

echo -e "${YELLOW}Installing nginx and docker-ce.${NOCOLOR}"
apt update && apt-get install -qq  nginx docker-ce
echo -e "${GREEN}OK, Installed nginx, docker-ce.${NOCOLOR}"

# Installing v2ray
echo -e "${YELLOW}Installing v2ray.${NOCOLOR}"
bash <(curl -sL https://install.direct/go.sh) > /dev/null 2>&1
echo -e "${GREEN}OK, v2ray installed.${NOCOLOR}"

# back up v2ray config.json
echo -e "${YELLOW}Backup v2ray config.json.${NOCOLOR}"
if [ -f /etc/v2ray/config.json.backup ]
then
    echo -e "${YELLOW}Have backed up config.json.${NOCOLOR}"
else
    mv /etc/v2ray/config.json /etc/v2ray/config.json.backup
    echo -e "${GREEN}OK, Backed up over.${NOCOLOR}"
fi

echo -e "${YELLOW}get new v2ray config.json.${NOCOLOR}"
curl -fsSL https://raw.githubusercontent.com/leollon/my-new-debian-like-on-server/master/server-config.json -O
curl -fsSL https://raw.githubusercontent.com/leollon/my-new-debian-like-on-server/master/client-config.json -o ./config.json
echo -e "${GREEN}OK, Done.${NOCOLOR}"

# iptables
echo -e "${YELLOW}firewall setting.${NOCOLOR}"
ufw enable
ufw allow 22                      # used by ssh server
ufw allow 80                      # used by nginx webserver
ufw allow 443                     # used by https
ufw allow 8080                    # used by some test
ufw allow ${V2RAY_SERVER_PORT}    # used by v2ray
echo -e "${GREEN}OK,firewall set.${NOCOLOR}"


# add customized UUID
echo -e "${YELLOW}set v2ray config.json.${NOCOLOR}"

# config v2ray server
sed -i "s/\"id\": \"[a-z0-9_\-]*\"/\"id\": \"${UUID}\"/" ./server-config.json
sed -i "s/\"port\": [a-z0-9_]*/\"port\": ${V2RAY_SERVER_PORT}/" ./server-config.json

# config v2ray client
sed -i "s/\"port\": V2RAY_CLIENT_PORT/\"port\": ${V2RAY_CLIENT_PORT}/" ./config.json
sed -i "s/\"address\": \"[A-Z0-9_]*\"/\"address\": \"${SERVER_IP}\"/" ./config.json
sed -i "s/\"port\": V2RAY_SERVER_PORT/\"port\": ${V2RAY_SERVER_PORT}/" ./config.json
sed -i "s/\"id\": \"[a-z0-9_\-]*\"/\"id\": \"${UUID}\"/" ./client-config.json
mv ./server-config.json /etc/v2ray/config.json
echo -e "${GREEN}OK, config.json set.${NOCOLOR}"

# upgrade linux kernel
echo -e "${YELLOW}Downloading and Upgrading linux kernel 4.9.76 for BBR.${NOCOLOR}"
curl -fL http://kernel.ubuntu.com//~kernel-ppa/mainline/v4.9.76/linux-image-4.9.76-040976-generic_4.9.76-040976.201801100432_amd64.deb -O
dpkg -i linux-image-4.9.76-040976-generic_4.9.76-040976.201801100432_amd64.deb
update-grub
kernel_version=$(uname -r | cut -d '-' -f 1)
echo -e "${GREEN}OK, Downloaded and Installed.${NOCOLOR}"

# Use bbr algorithm
echo -e "${GREEN}Use BBR algorithm.${NOCOLOR}"
echo -e "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo -e "${RED}Have to reboot make bbr usable.${NOCOLOR}"

# Some service automatically start on boot
echo -e "${YELLOW}auto-start service on boot.${NOCOLOR}"
systemctl enable v2ray.service
systemctl enable ufw.service
systemctl enable fail2ban.service
systemctl enable docker.service
echo -e "${GREEN}OK, service set.${NOCOLOR}"

echo -e "${YELLOW}create a non-root user?${NOCOLOR}"
read username
echo -e "${RED}Password for ${username}: ${NOCOLOR}"
read password
if [ "${username}" != "" ] && [ "${password}" != "" ]
then
    echo "${username}:${password} | chpasswd"
    useradd -s "$(which zsh)" -m "${username}"
    echo -e "${GREEN}${username} created.${NOCOLOR}"
    echo -e "${YELLOW}add ${username} to sudo and docker group?[y/n]${NOCOLOR}"
    answer=''
    read answer
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]
    then
        usermod -aG sudo,docker "${username}"
    else
        echo -e "${RED}username is not in sudo, docker group.${NOCOLOR}"
    fi
fi

echo -e "${GREEN}upgrade os and installation over."
echo -e "Installed: vim, uuid-runtime, openssh-server, docker-ce, nginx, curl, htop, tcptrack, sudo, fail2ban, ufw, v2ray, zsh, git"
echo -e "Allowed port: web: 80 and 443, test: 8080, ssh: 22, v2ray: ${V2RAY_SERVER_PORT}"
echo -e "v2ray_server_ip: ${SERVER_IP}, v2ray_server_port: ${V2RAY_SERVER_PORT}, v2ray_uuid: ${UUID}"
echo -e "Linux kernel: ${kernel_version}, non-root-user: ${username:-not-set}, ${username:-not-set}'s password: ${password:-not-set}"
echo -e "Over, see ya!${NOCOLOR}"
echo -e "${YELLOW}Do not forget to reboot OS!!${NOCOLOR}"

exit 0

