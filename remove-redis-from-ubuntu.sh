#########################################################################
# File Name: remove-redis-from-server.sh
# Author: leollon
# mail: mssm.good@outlook.com
# Created Time: Saturday, June 23, 2018 PM06:34:08 CST
#########################################################################
#!/bin/bash

systemctl stop redis

REDIS_CONF_DIR="/etc/redis"
REDIS_VAR_DIR="/var/lib/redis"
REDIS_SERVICE_FILE="/etc/systemd/system/redis.service"

deluser redis

rm -f /usr/local/bin/redis-*
rm -rf $REDIS_CONF_DIR $REDIS_VAR_DIR $REDIS_SERVICE_FILE
rm -f /etc/systemd/system/multi-user.target.wants/redis.service

