# docker-spark-hadoop


## 常用命令

### 查看本地镜像库内容
`curl master:5000/v2/_catalog`

### swarm模式不支持的命令
- build
- cgroup_parent
- container_name
- devices
- dns
- dns_search
- tmpfs
- external_links
- links
- network_mode
- security_opt
- stop_signal
- sysctls
- userns_mode

### swarm 常用命令

- docker swarm：集群管理，子命令有init, join, leave, update。（docker swarm --help查看帮助）
- docker service：服务创建，子命令有create, inspect, update, remove, tasks。（docker service--help查看帮助）
- docker node：节点管理，子命令有accept, promote, demote, inspect, update, tasks, ls, rm。（docker node --help查看帮助）

- 部署compose服务
`docker stack deploy -c docker-compose.yml hadoop1`

- 删除compose服务
`docker stack rm hadoop1`



### 服务发现
1. overlay（swarm自带）
    
    虚拟出一个内部的网段，当服务指定为该网络时，该服务就从该网段内分配一个地址，所以是互联互通的。（但是是怎么提供dns的呢？）
    
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

### HDFS、YARN  使用-D参数指定配置，使得镜像更加灵活
```-Dfs.defaultFS=hdfs://namenode:9000 -Ddfs.name.dir=/root/hadoop/dfs/name -Ddfs.data.dir=/root/hadoop/dfs/data -Ddfs.replication=1 -Ddfs.permissions=false -Ddfs.namenode.datanode.registration.ip-hostname-check=false -Dmapreduce.framework.name=yarn -Dyarn.resourcemanager.hostname=ResourceManager -Dyarn.nodemanager.aux-services=mapreduce_shuffle -Dyarn.scheduler.maximum-allocation-mb=2048 -Dyarn.nodemanager.resource.memory-mb=1024 -Dyarn.nodemanager.resource.cpu-vcores=1 -Dyarn.nodemanager.vmem-check-enabled=false```

### spark 使用env参数配置
`SPARK_HISTORY_OPTS: "-Dspark.history.ui.port=18080 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=/root/spark/history -Dspark.eventLog.enabled=true -Dspark.eventLog.dir=hdfs://namenode:9000/spark/history"
`

### NameNode退出安全模式
`hadoop dfsadmin -safemode leave`

### spark-submit 提交任务

`bin/spark-submit  --class org.apache.spark.examples.SparkPi  --master spark://master:7077 examples/jars/spark-examples_2.11-2.2.0.jar 10`

### 镜像库
```
docker service create --name registry --publish 5000:5000 \
--mount source=registry-vol,type=volume,target=/root/registry \
--constraint 'node.hostname==master' registry:2
```
- curl master:5000/v2/_catalog