FROM redis:latest
LABEL CasterHsu

# 將自定義啟動腳本覆制到容器內
COPY conf/base_redis.conf /base_redis.conf
COPY replaceConf.sh /replaceConf.sh

# keep container alive
CMD ["/replaceConf.sh"]