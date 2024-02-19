#!/bin/bash

nodeNumber=$NODE_NO
externalIp=$EXTERNAL_IP
port=$PORT
busPort=$BUS_PORT
# busPort=$((port + 10000))

echo "nodeNumber:"$nodeNumber ", port:" $port ", busPort:" $busPort ", externalIp:" $externalIp

# 原始文件路径
input_file="/base_redis.conf"

# 新文件路径
output_file="/data/redis.conf"

# 读取文件内容并进行替换
sed -e "s/_port/${port}/g" -e "s/_clusterEnable/yes/g" -e "s/_clusterAnnounceIp/${externalIp}/g" -e "s/_clusterAnnouncePort/${port}/g" -e "s/_clusterAnnounceBusPort/${busPort}/g" "$input_file" > "$output_file"

echo "replace complates"

redis-server $output_file

# 保持容器运行
# tail -f /dev/null

# read -n 1