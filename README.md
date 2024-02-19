---
description: >-
  在這份文件中，我們將使用 Docker Compose、Dockerfile 以及 Shell 腳本來建立一個 Redis
  Cluster。以下是相關的設定檔案和步驟。
---

# Create Redis Cluster Using Docker

### 1. Docker Compose 設定 (`docker-compose.yml`)

定義一個包含 Redis Cluster 的 Docker Compose 服務：

```yaml
version: '3.7'

services:
  redis1:
    image: i_redis_node_1
    build: 
      context: ./DockerFile
      dockerfile: redis.Dockerfile
    container_name: redis-node1
    ports:
      - "${NODE_1_PORT}:${NODE_1_PORT}"
      - "${NODE_1_BUS_PORT}:${NODE_1_BUS_PORT}"
    environment:
      NODE_NO: 1
      EXTERNAL_IP: ${EXTERNAL_IP}
      PORT: ${NODE_1_PORT}
      BUS_PORT: ${NODE_1_BUS_PORT}
    volumes:
      - ./data/node1:/data
    healthcheck:
      test: [ "CMD", "redis-cli", "-p", "7001", "cluster", "info" ]
      interval: 1s
      timeout: 3s
      retries: 30

  # 其他 redis2 到 redis6 的節點與相同配置類似

  redis-cluster-creator:
    image: redis
    entrypoint: [/bin/sh,-c,'echo "yes" | redis-cli --cluster create redis1:7001 redis2:7002 redis3:7003 redis4:7004 redis5:7005 redis6:7006 --cluster-replicas 1']
    depends_on:
      redis1:
        condition: service_healthy
      # 其他 redis2 到 redis6 的節點與相同配置類似
```

這份檔案定義了七個服務：

1. `redis1` 到 `redis6`: 每個服務代表 Redis Cluster 中的一個節點，包括了映像、構建配置、容器名稱、端口映射、環境變數、數據卷、健康檢查等設定。
2. `redis-cluster-creator`: 這個服務負責創建 Redis Cluster。它使用 Redis 映像，並在啟動時使用 entrypoint 腳本建立集群。此服務的健康檢查依賴於所有其他節點的健康狀態。一旦所有節點健康，該服務就會執行創建 Redis Cluster 的命令。

環境變數部分包括：

* `NODE_NO`: 節點編號。
* `EXTERNAL_IP`: 節點的外部 IP。
* `PORT`: 節點端口。
* `BUS_PORT`: Redis Cluster 總線通訊使用的端口。

#### 環境變數檔案 golbal.env.local

```
EXTERNAL_IP=172.20.160.120
NODE_1_PORT=7001
NODE_1_BUS_PORT=17001
NODE_2_PORT=7002
NODE_2_BUS_PORT=17002
NODE_3_PORT=7003
NODE_3_BUS_PORT=17003
NODE_4_PORT=7004
NODE_4_BUS_PORT=17004
NODE_5_PORT=7005
NODE_5_BUS_PORT=17005
NODE_6_PORT=7006
NODE_6_BUS_PORT=17006
```

### 2. Dockerfile (`Dockerfile`)

```Dockerfile
FROM redis:latest
MAINTAINER CasterHsu

COPY conf/base_redis.conf /base_redis.conf
COPY replaceConf.sh /replaceConf.sh

CMD ["/replaceConf.sh"]
```

這份 Dockerfile 用於構建 Redis 映像，以下是對檔案內容的詳細解釋：

1. `FROM redis:latest`: 這一行指定了基礎映像。在這種情況下，`redis:latest` 表示使用最新版本的 Redis 映像作為基礎。
2. `COPY conf/base_redis.conf /base_redis.conf`: 這行複製本地機器上的 `conf/base_redis.conf` 文件到映像的 `/base_redis.conf` 路徑。這是為了將預先配置的 Redis 配置文件添加到映像中。
3. `COPY replaceConf.sh /replaceConf.sh`: 這行複製本地機器上的 `replaceConf.sh` 腳本到映像的 `/replaceConf.sh` 路徑。這是一個腳本，將替換 Redis 配置文件中的特定變數。
4. `CMD ["/replaceConf.sh"]`: 這一行設定了容器啟動時要執行的默認命令。在這種情況下，它執行 `replaceConf.sh` 腳本。這確保了在容器啟動時會應用對配置文件的修改。

而 `base_redis.conf` 其實有針對 cluster 設定做了一些調整，後續的 `replaceConf.sh` 會根據特定字串進行取代動作。

Dockerfile 用於構建一個基於最新版本的 Redis 映像，並向其中添加了一些特定的配置文件和腳本，以定制 Redis 的行為。

### 3. Shell 腳本 (`replaceConf.sh`)

```bash
#!/bin/bash

nodeNumber=$NODE_NO
externalIp=$EXTERNAL_IP
port=$PORT
busPort=$BUS_PORT

echo "nodeNumber:"$nodeNumber ", port:" $port ", busPort:" $busPort ", externalIp:" $externalIp

# 原始文件路径
input_file="/base_redis.conf"

# 新文件路径
output_file="/data/redis.conf"

# 读取文件内容并进行替换
sed -e "s/_port/${port}/g" -e "s/_clusterEnable/yes/g" -e "s/_clusterAnnounceIp/${externalIp}/g" -e "s/_clusterAnnouncePort/${port}/g" -e "s/_clusterAnnounceBusPort/${busPort}/g" "$input_file" > "$output_file"

echo "replace completes"

redis-server $output_file
```

腳本用於替換 Redis 配置文件中的特定變數，然後啟動 Redis 服務。

* `#!/bin/bash`: 這是腳本的 shebang 行，指定了使用 Bash 解釋器執行腳本。
* `nodeNumber=$NODE_NO` 到 `busPort=$BUS_PORT`: 這一系列的行讀取了環境變數，其中包括 Node 的編號 (`NODE_NO`)、外部 IP (`EXTERNAL_IP`)、Port (`PORT`) 以及 Bus Port (`BUS_PORT`)。
* `echo "nodeNumber:"$nodeNumber ", port:" $port ", busPort:" $busPort ", externalIp:" $externalIp`: 這行用於在執行腳本時輸出上述讀取的變數值，以便於調試。
* `input_file="/base_redis.conf"` 和 `output_file="/data/redis.conf"`: 這裡定義了原始 Redis 配置文件的路徑 (`input_file`) 和新配置文件的路徑 (`output_file`)。
* `sed -e ...`: 這一行使用 `sed` 工具來進行文件替換。具體而言，它通過 `-e` 選項指定了一系列替換操作，替換了配置文件中的一些占位符。例如，`_port` 會被替換為實際的 Port 數值。
* `"$input_file" > "$output_file"`: 這行將替換後的內容寫入到新的配置文件中。
* `echo "replace complates"`: 這是一條輸出訊息，表示替換過程完成。
* `redis-server $output_file`: 最後一行啟動 Redis 服務，使用修改後的配置文件。

這個腳本的作用是根據環境變數替換 Redis 配置文件中的特定變數，然後使用修改後的配置文件啟動 Redis 服務。

### 4. 啟動測試

#### 最後目錄結構

```log
DockerRedisCluster
├─ docker-compose.yml
│  
├─DockerFile
│  ├─ redis.Dockerfile
│  ├─ replaceConf.sh
│  │  
│  └─conf
│     └─ base_redis.conf
│          
└─environments
   └─ golbal.env.local
```

#### 執行docker-compose

```bash
docker-compose --env-file ./environments/golbal.env.local up -d
```

```bash
docker-compose --env-file ./environments/golbal.env.local up -d
[+] Running 8/8
 - Network dockerrediscluster_default                    Created                                                   0.7s
 - Container redis-node2                                 Healthy                                                   7.5s
 - Container redis-node3                                 Healthy                                                   6.5s
 - Container redis-node5                                 Healthy                                                   6.5s
 - Container redis-node4                                 Healthy                                                   7.0s
 - Container redis-node1                                 Healthy                                                   6.5s
 - Container redis-node6                                 Healthy                                                   6.6s
 - Container dockerrediscluster-redis-cluster-creator-1  Started                                                   8.1s
```

#### 查看 redis-cluster-creator log

```bash
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica redis5:7005 to redis1:7001
Adding replica redis6:7006 to redis2:7002
Adding replica redis4:7004 to redis3:7003
M: 0c50049838b2cd3c62b20b1b4e7da10666821d23 redis1:7001
   slots:[0-5460] (5461 slots) master
M: 77fb92949f3892f8fb7f5dceca9c35fdd04e5568 redis2:7002
   slots:[5461-10922] (5462 slots) master
M: 68be4c2ba1800365a7872415a9e55374dd625c44 redis3:7003
   slots:[10923-16383] (5461 slots) master
S: 76c5839cbc452369f6b4b62c22a0e7971fe2304b redis4:7004
   replicates 68be4c2ba1800365a7872415a9e55374dd625c44
S: b87d9fd0b2b4a1aa02d55f55563abef405c6536c redis5:7005
   replicates 0c50049838b2cd3c62b20b1b4e7da10666821d23
S: 5be02b0293a6230bd4cb278bee6a1ebadfd2e898 redis6:7006
   replicates 77fb92949f3892f8fb7f5dceca9c35fdd04e5568
Can I set the above configuration? (type 'yes' to accept): >>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
>>> Performing Cluster Check (using node redis1:7001)
M: 0c50049838b2cd3c62b20b1b4e7da10666821d23 redis1:7001
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
S: 5be02b0293a6230bd4cb278bee6a1ebadfd2e898 172.20.160.120:7006
   slots: (0 slots) slave
   replicates 77fb92949f3892f8fb7f5dceca9c35fdd04e5568
M: 77fb92949f3892f8fb7f5dceca9c35fdd04e5568 172.20.160.120:7002
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
M: 68be4c2ba1800365a7872415a9e55374dd625c44 172.20.160.120:7003
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: 76c5839cbc452369f6b4b62c22a0e7971fe2304b 172.20.160.120:7004
   slots: (0 slots) slave
   replicates 68be4c2ba1800365a7872415a9e55374dd625c44
S: b87d9fd0b2b4a1aa02d55f55563abef405c6536c 172.20.160.120:7005
   slots: (0 slots) slave
   replicates 0c50049838b2cd3c62b20b1b4e7da10666821d23
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

就兩個字！完美！！

以上配置將建立一個包含多個 Redis 節點的 Redis Cluster，每個節點都將在不同的端口上運行。通過 Docker Compose 可以簡化整個 Redis Cluster 的建置和配置過程，這樣就可以自行在本機模擬不同環境Redis Server 的配置。

GitHub：[前往](https://github.com/MinchangHsu/DockerRedisCluster)