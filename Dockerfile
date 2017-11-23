# 用于提交spark on yarn程序时所使用的镜像
FROM hadoop:v1
MAINTAINER <Sparks Li>

RUN apk --update add curl unzip bash


# SPARK
ENV SPARK_VERSION 2.2.0
ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-hadoop2.7
ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
# ENV CLASS_PATH $CLASS_PATH:${SPARK_HOME}/jars
ENV PATH $PATH:${SPARK_HOME}/bin
ENV SPARK_HISTORY_HOME=/root/spark/history


RUN curl -sL --retry 3 \
  "http://d3kbcqa49mib13.cloudfront.net/${SPARK_PACKAGE}.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/$SPARK_PACKAGE $SPARK_HOME \
 && chown -R root:root $SPARK_HOME \
 && mkdir -p $SPARK_HISTORY_HOME

ADD spark-defaults.conf $SPARK_HOME/conf/spark-defaults.conf


WORKDIR $SPARK_HOME

