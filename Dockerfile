FROM openjdk:8u131-jre-alpine
MAINTAINER <Sparks Li>


ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TZ=Asia/Shanghai


RUN apk --update add wget bash tzdata \
    && cp /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \

ENV HADOOP_VERSION 2.7.4
ENV HADOOP_PACKAGE hadoop-${HADOOP_VERSION}
ENV HADOOP_HOME=/usr/hadoop
ENV PATH=$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

# install hadoop
RUN wget http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/${HADOOP_PACKAGE}/${HADOOP_PACKAGE}.tar.gz && \
    tar -xzvf $HADOOP_PACKAGE.tar.gz && \
    mv $HADOOP_PACKAGE /usr/hadoop && \
    rm $HADOOP_PACKAGE.tar.gz && \
    mkdir -p /root/hadoop/tmp && \
    mkdir -p /root/hadoop/var && \
    mkdir -p /root/hadoop/dfs/name && \
    mkdir -p /root/hadoop/dfs/data && \
    mkdir $HADOOP_HOME/logs


RUN mv /tmp/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh && \
    mv /tmp/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml && \
    mv /tmp/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml && \
    mv /tmp/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml && \
    mv /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml && \
    mv /tmp/slaves $HADOOP_HOME/etc/hadoop/slaves && \
    $HADOOP_HOME/bin/hdfs namenode -format

WORKDIR $HADOOP_HOME

