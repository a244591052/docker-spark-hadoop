# 关于Spark集群的容器封装与部署

### 封装Spark镜像
```
  FROM openjdk:8u131-jre-alpine
  # openjdk:8u131-jre-alpine作为基础镜像，体积小，自带jvm环境。
  MAINTAINER <eway>
  # 切换root用户避免权限问题，utf8字符集，bash解释器。安装一个同步为上海时区的时间
  USER root
  ENV LANG=C.UTF-8
  RUN apk add --no-cache  --update-cache bash
  ENV TZ=Asia/Shanghai
  RUN apk --update add wget bash tzdata \
      && cp /usr/share/zoneinfo/$TZ /etc/localtime \
      && echo $TZ > /etc/timezone
  # 下载解压spark
  WORKDIR /usr/local
  RUN wget "http://www.apache.org/dist/spark/spark-2.0.2/spark-2.0.2-bin-hadoop2.7.tgz" \
     && tar -zxvf spark-*  \
     && mv spark-2.0.2-bin-hadoop2.7 spark \
     && rm -rf spark-2.0.2-bin-hadoop2.7.tgz

  # 配置环境变量、暴露端口
  ENV SPARK_HOME=/usr/local/spark
  ENV JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
  ENV PATH=${PATH}:${JAVA_HOME}/bin:${SPARK_HOME}/bin

  EXPOSE 6066 7077 8080 8081 4044
  WORKDIR $SPARK_HOME
  CMD ["/bin/bash"]
```
dockerfile 编写完后我们就可以基于此构建镜像了
```powershell
# 构建Dockerfile构建镜像
$ docker build -f Dockerfile -t spark:v1 .
```
### 在本地启动服务

```powershell
# 启动 master 容器
$ docker run -itd --name spark-master -p 6066:6066 -p 7077:7077 -p 8080:8080 hzy/spark:v1 spark-class org.apache.spark.deploy.master.Master 

# 启动 worker 容器
$ docker run -itd  -P --link spark-master:worker01 hzy/spark:v1 spark-class org.apache.spark.deploy.worker.Worker spark://spark-master:7077

# 启动 historyserver 容器
$ docker run -itd --name spark-history -p 18080:18080 \ 
-e SPARK_HISTORY_OPTS="-Dspark.history.ui.port=18080 \
-Dspark.history.retainedApplications=10 \
-Dspark.history.fs.logDirectory=hdfs://namenode:9000/user/spark/history" \
hzy/spark:v1  spark-class org.apache.spark.deploy.history.HistoryServer

# 运行spark程序
$ spark-submit --conf spark.eventLog.enabled=true \
--conf spark.eventLog.dir=hdfs://namenode:9000/user/spark/history \
--master spark://namenode:7077 --class org.apache.spark.examples.SparkPi ./examples/jars/spark-examples_2.11-2.0.2.jar 
```


### 使用docker-compose部署服务
```
version: "2"
  master:
    image: spark:v1
    command: bin/spark-class org.apache.spark.deploy.master.Master -h master
    hostname: master
    environment:
      MASTER: spark://master:7077
      SPARK_MASTER_OPTS: "-Dspark.eventLog.dir=hdfs://namenode:9000/user/spark/history"
      SPARK_PUBLIC_DNS: master
    ports:
      - 4040:4040
      - 6066:6066
      - 7077:7077
      - 8080:8080

  worker:
    image: hzy/spark:v1
    command: bin/spark-class org.apache.spark.deploy.worker.Worker spark://master:7077
    hostname: worker
    environment:
      SPARK_WORKER_CORES: 1
      SPARK_WORKER_MEMORY: 1g
      SPARK_WORKER_PORT: 8881
      SPARK_WORKER_WEBUI_PORT: 8081
      SPARK_PUBLIC_DNS: master
    links:
      - master
    ports:
      - 8081:8081
      
 historyServer:
    image: hzy/spark:v1
    command: spark-class org.apache.spark.deploy.history.HistoryServer
    hostname: historyServer
    environment:
      MASTER: spark://master:7077
      SPARK_PUBLIC_DNS: master
      SPARK_HISTORY_OPTS: "-Dspark.history.ui.port=18080 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark/history"
    links:
      - master
    expose:
      - 18080
    ports:
      - 18080:18080
```

```
  # 通过docker-compose一键启动spark集群
  $ docker-compose -f docker-compose.yml up -d
  # 一键扩展worker服务到5个
  $ docker-compose scale worker=5
```