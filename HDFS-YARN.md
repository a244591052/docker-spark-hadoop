## 关于HDFS与YARN的镜像封装

### DockerFile源代码
```
# HDFS、YARN镜像封装
FROM openjdk:8u131-jre-alpine
MAINTAINER <YiWei KeJi>
# 设置一些系统环境变量（字符集和时区）
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TZ=Asia/Shanghai

# 安装一些必需的软件包，同步时区
RUN apk --update add wget bash tzdata \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone
    
# 设置HADOOP相关的环境变量，这里我们使用2.7.4版本
ENV HADOOP_VERSION 2.7.4
ENV HADOOP_PACKAGE hadoop-${HADOOP_VERSION}
ENV HADOOP_HOME=/usr/hadoop
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# Hadoop安装
RUN wget http://www.apache.org/dist/hadoop/common/${HADOOP_PACKAGE}/${HADOOP_PACKAGE}.tar.gz && \
    tar -xzvf $HADOOP_PACKAGE.tar.gz && \
    mv $HADOOP_PACKAGE /usr/hadoop && \
    # 删除安装包，减少镜像大小
    rm $HADOOP_PACKAGE.tar.gz && \
    # 创建一系列HDFS需要的文件目录
    mkdir -p /root/hadoop/tmp && \
    mkdir -p /root/hadoop/var && \
    mkdir -p /root/hadoop/dfs/name && \
    mkdir -p /root/hadoop/dfs/data && \
    mkdir $HADOOP_HOME/logs && \
    # 格式化NameNode元数据
    $HADOOP_HOME/bin/hdfs namenode -format

WORKDIR $HADOOP_HOME
```

### DockerFile代码注意事项
#### 源镜像选择
通常我们封装镜像时，一般都采用Centos或Ubuntu的源镜像，但是这样做有一个很大的缺点就是封装后的镜像体积太大，所以为了减少镜像体积，我们使用了体积小巧的alpine作为源镜像，同时考虑到HDFS和YARN都需要JAVA环境，所以最终我们使用了自带JDK的openjdk:8u131-jre-alpine。
> 注：最终镜像大小只有500M左右

#### 时区同步
源镜像默认是CTS时区，所以需要添加tzdata包获取各时区的相关数据，以更改为中国上海的时区。
> 注: tzdata安装更改时区后不可卸载，否则时区会变回CTS。

#### NameNode格式化
HDFS NameNode必须初始格式化后才可工作，所以这里直接在镜像中格式化，该条命令仅对NameNode生效，所以该条命令并不影响其他服务的使用。
> 优化: 这里可以使用脚本获取格式化路径，并判断是否需要格式化，这样做会使镜像变得更加灵活。

### 单独启动各服务容器
1. 启动NameNode服务

```powershell
docker run -d --name namenode \
-p 50070:50070 -h namenode \
-v /root/hadoop/dfs/name:/root/hadoop/dfs/name \
hadoop:v1 hdfs namenode \
-Dfs.defaultFS=hdfs://0.0.0.0:9000 \
-Ddfs.namenode.name.dir=/root/hadoop/dfs/name \
-Ddfs.replication=3 \
-Ddfs.namenode.datanode.registration.ip-hostname-check=false \
-Ddfs.permissions.enabled=false \
-Ddfs.namenode.safemode.threshold-pct=0
```
> 注：使用HDFS命令后面的-D参数传递配置信息，这样可以使得镜像更加灵活；

2. 启动DataNode服务并连接上NameNode

```powershell
docker run -d --name datanode -p 50075:50075 \
-v /root/hadoop/dfs/data:/root/hadoop/dfs/data \
--link namenode \
hadoop:v1 hdfs datanode \
-fs hdfs://namenode:9000 \
-Ddfs.datanode.data.dir=/root/hadoop/dfs/data \
-Ddfs.permissions.enabled=false
```
> 注：--link <目标容器名> 该参数的主要意思是本容器需要使用目标容器的服务，所以指定了容器的启动顺序，并且在该容器的hosts文件中添加目标容器名的DNS。

3. 启动ResourceManager服务
```powershell
docker run -d --name resourcemanager \
-p 8088:8088 -h ResourceManager \
hadoop:v1 yarn resourcemanager \
-Dfs.defaultFS=hdfs://namenode:9000 \
-Dmapreduce.framework.name=yarn \
-Dyarn.resourcemanager.hostname=ResourceManager \
-Dyarn.resourcemanager.webapp.address=0.0.0.0:8088
```


4. 启动NodeManager服务
```powershell
docker run -d --name nodemanager \
--link resourcemanager \
hadoop:v1 yarn nodemanager \
-Dfs.defaultFS=hdfs://namenode:9000 \
-Dmapreduce.framework.name=yarn \
-Dyarn.resourcemanager.hostname=ResourceManager \
-Dyarn.nodemanager.aux-services=mapreduce_shuffle \
-Dyarn.nodemanager.resource.memory-mb=2048 \
-Dyarn.nodemanager.resource.cpu-vcores=1 \
-Dyarn.nodemanager.vmem-check-enabled=false
```