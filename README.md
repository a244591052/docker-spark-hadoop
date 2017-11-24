## 大数据架构微服务
使用docker封装spark、hdfs、yarn等大数据生态圈的各组件，对各个组件进行解耦，保证一个服务一个容器，使用docker swarm管理编排集群，使得整个大数据架构更加轻量级，集群扩展也变得相当方便和快速。

### 使用DockerFile封装各组件镜像
- 使用openjdk:8u131-jre-alpine作为源镜像，不仅体积小，而且自带jdk8，推荐！
- 为了使得镜像更加灵活，尽量在后期启动的时候传入配置文件而不是镜像中写死。

### 使用docker-compose编排服务集群
- 在这里使用version3版本的docker-compose
- 所有的服务使用同一个overlay网络，便于服务发现，当然你也可以使用第三方插件。
- 在各服务启动的时候可以传入参数，使得镜像更加灵活

### 使用docker swarm部署管理集群

```shell
# 使用swarm部署docker-compose编排的服务
docker stack deploy -c docker-compose.yml <service name>
# 查看服务列表
docker service ls
# 删除服务
docker stack rm <service name>
```


### spark-submit 提交任务

`bin/spark-submit  --class org.apache.spark.examples.SparkPi  --master spark://master:7077 examples/jars/spark-examples_2.11-2.2.0.jar 10`

```
- 提交spark程序
docker service create --name spark_job \
    --entrypoint "bin/spark-submit  --class org.apache.spark.examples.SparkPi  --master spark://master:7077 examples/jars/spark-examples_2.11-2.2.0.jar 10" \
    --network test_hadoopv1 \
    --restart-condition none \
    master:5000/spark:2.2.0_empty

- 提交到Yarn
docker service create --name yarn_job1 \
    -e HADOOP_CONF_DIR=/usr/hadoop/etc/hadoop \
    --entrypoint "bin/spark-submit  --class org.apache.spark.examples.SparkPi  --master yarn --deploy-mode cluster --driver-memory 512M  --executor-memory 512M examples/jars/spark-examples_2.11-2.2.0.jar 10" \
    --network test_hadoopv1 \
    --restart-condition none \
    --constraint 'node.hostname==master' \
    spark_submit:yarn
```




### swarm overlay服务发现
    
> 虚拟出一个内部的网段，当服务指定为该网络时，该服务就从该网段内分配一个地址，所以是互联互通的。内部实现一个127.0.0.11地址的DNS服务器，由此同一个网络内的所有都可以使用主机名访问服务。
    
### compose configs 命令 踩坑
经过大量实验得出的结论：
1. 只适合一个节点的集群，一旦有多个节点，配置根本不生效，官网的例子也是单节点单服务
> Note: These examples use a single-Engine swarm and unscaled services for simplicity. The examples use Linux containers, but Windows containers also support configs.

> Note: Docker configs are only available to swarm services, not to standalone containers. To use this feature, consider adapting your container to run as a service with a scale of 1.
2. 如果说只需要在集群中特定的主机上添加配置文件，那么这个命令是可以使用的
```dockerfile
version: "3.3"
services:
  redis:
    image: redis:latest
    deploy:
      replicas: 1
    configs:
      - source: my_config  # 配置项的名称，具体实现在下面
        target: /redis_config  # 容器内部的路径
        uid: '103'
        gid: '103'
        mode: 0440
configs:
  my_config: # 上面引用配置项的具体实现
    file: ./my_config.txt # 宿主机上的配置文件路径
  my_other_config:
    external: true  # 这个命令表示该配置项事先已经定义，可以使用docker config命令事先定义，否则会出错
```

