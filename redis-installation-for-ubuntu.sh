#########################################################################
# File Name: redis-installation-for-ubuntu.sh
# Author: leollon
# mail: mssm.good@outlook.com
# Created Time: Saturday, June 23, 2018 PM06:05:04 CST
#########################################################################
#!/bin/bash
set -e

REDIS_VERSION="redis-stable"
REDIS_CONF_DIR="/etc/redis"
REDIS_VAR_DIR="/var/lib/redis"
REDIS_CONF_FILE="$REDIS_CONF_DIR/redis.conf"
REDIS_LOGFILE="\/var\/log\/redis_6379.log"
PIDFile="/var/run/redis_6379.pid"


apt install build-essential tcl

curl -O http://download.redis.io/$(REDIS_VERSION).tar.gz

tar xzvf REDIS_VERSION.tar.gz

cd $(REDIS_VERSION)

make && make test

make install

mkdir $REDIS_CONF_DIR $REDIS_VAR_DIR

cp ./redis.conf $REDIS_CONF_DIR

sed -i "s/supervised\ no/supervised systemd/g" $REDIS_CONF_FILE

sed -i "s/\.\//\/var\/lib\/redis/g" $REDIS_CONF_FILE

sed -i "s/logfile\ \"\"/logfile \"$REDIS_LOGFILE\"/g" $REDIS_CONF_FILE


echo -e "[Unit]
Description=Redis In-Memory Data Store
After=network.target\n
[Service]
User=redis
Group=redis
PIDFile=/var/run/redis_6379.pid
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always\n
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/redis.service

adduser --system --group --no-create-home redis

chown redis.redis $REDIS_VAR_DIR

chmod 770 $REDIS_VAR_DIR -R

touch $PIDFile

chown redis:redis /var/log/redis_6379.log $PIDFile

systemctl start redis

systemctl enable redis

systemctl status redis
