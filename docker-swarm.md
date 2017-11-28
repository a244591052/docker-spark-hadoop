## Docker Swarm

### Swarm背景
现实中我们的应用可能会有很多，应用本身也可能很复杂，单个Docker Engine所能提供的资源未必能够满足要求。而且应用本身也会有可靠性的要求，希望避免单点故障，这样的话势必需要分布在多个Docker Engine。在这样一个大背景下，Docker社区就产生了Swarm项目。

### Swarm简介
Swarm这个项目名称特别贴切。在Wiki的解释中，Swarm behavior是指动物的群集行为。比如我们常见的蜂群，鱼群，秋天往南飞的雁群都可以称作Swarm behavior。
![Alt text](https://github.com/a244591052/docker-spark-hadoop/blob/master/images/docker-swarm.JPG)

Swarm项目正是这样，通过把多个Docker Engine聚集在一起，形成一个大的docker-engine，对外提供容器的集群服务。同时这个集群对外提供Swarm API，用户可以像使用Docker Engine一样使用Docker集群。

### Swarm 特点
- 对外以Docker API接口呈现，这样带来的好处是，如果现有系统使用Docker Engine，则可以平滑将Docker Engine切到Swarm上，无需改动现有系统。
- Swarm对用户来说，之前使用Docker的经验可以继承过来。非常容易上手，学习成本和二次开发成本都比较低。同时Swarm本身专注于Docker集群管理，非常轻量，占用资源也非常少。 *“Batteries included but swappable”，简单说，就是插件化机制，Swarm中的各个模块都抽象出了API，可以根据自己一些特点进行定制实现。
- Swarm自身对Docker命令参数支持的比较完善，Swarm目前与Docker是同步发布的。Docker的新功能，都会第一时间在Swarm中体现。

### Swarm 集群管理
1. 在管理节点上初始化swarm
```powershell
[root@master docker-spark-master]# docker swarm init
Swarm initialized: current node (n7o0o1xl5q4r7lahggc5hseju) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-1ujkotzvkhpvrzwq3hstwpcxsrf84taz47wzyzju0atapcxdd7-4ciso6e5ox3mi7tgraobuo9tu 192.168.235.100:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
```
2. 将所有worker节点加入到该swarm集群中

```
# 在所有worker节点
docker swarm join --token SWMTKN-1-1ujkotzvkhpvrzwq3hstwpcxsrf84taz47wzyzju0atapcxdd7-4ciso6e5ox3mi7tgraobuo9tu 192.168.235.100:2377
```
3. 在管理节点上查看集群各节点状态

```
[root@master docker-spark-master]# docker node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
n7o0o1xl5q4r7lahggc5hseju *   master              Ready               Active              Leader
0gbvgkqz99q1ooc92yvj0ygoi     slave1              Ready               Active              
maysdjlg2zin9lfzztjvnln98     slave2              Ready               Active              
```
 到这一步我们docker swarm就搭建成功了，接下来要做的就是在集群上跑服务了
 但在此之前我们补充一些知识点，那就是docker网络与服务发现。
 
### Docker 网络
#### docker network ls
这个命令用于列出所有当前主机上或Swarm集群上的网络：
```
$ docker network ls
NETWORK ID NAME DRIVER
6e6edc3eee42 bridge bridge
1caa9a605df7 none null
d34a6dec29d3 host host
```


在默认情况下会看到三个网络，它们是Docker Deamon进程创建的。它们实际上分别对应了Docker过去的三种『网络模式』：

- bridge：容器使用独立网络Namespace，并连接到docker0虚拟网卡（默认模式）
- none：容器没有任何网卡，适合不需要与外部通过网络通信的容器
- host：容器与主机共享网络Namespace，拥有与主机相同的网络设备

在docker1.9版本引入libnetwork后，它们不再是固定的『网络模式』了，而只是三种不同『网络插件』的实体。说它们是实体，是因为现在用户可以利用Docker的网络命令创建更多与默认网络相似的网络，每一个都是特定类型网络插件的实体。

由此可以看出，libnetwork带来的最直观变化实际上是：docker0不再是唯一的容器网络了，用户可以创建任意多个与docker0相似的网络来隔离容器之间的通信。然而，要仔细来说，用户自定义的网络和默认网络还是有不一样的地方。

默认的三个网络是不能被删除的，而用户自定义的网络可以用『docker networkrm』命令删掉；

**连接到默认的bridge网络连接的容器需要明确的在启动时使用『–link』参数相互指定，才能在容器里使用容器名称连接到对方。而连接到自定义网络的容器，不需要任何配置就可以直接使用容器名连接到任何一个属于同一网络中的容器。这样的设计即方便了容器之间进行通信，又能够有效限制通信范围，增加网络安全性；**

**在Docker 1.9文档中已经明确指出，不再推荐容器使用默认的bridge网卡，它的存在仅仅是为了兼容早期设计。而容器间的『–link』通信方式也已经被标记为『过时的』功能，并可能会在将来的某个版本中被彻底移除。**

**在Docker的1.9中版本中正式加入了官方支持的跨节点通信解决方案，而这种内置的跨节点通信技术正是使用了Overlay网络的方法。**

#### Overlay网络的特点
swarm模式的overlay network有以下特征:
   - 支持多个跨节点服务连接到同一个网络中。
   - 默认情况下，Overlay网络的服务发现机制给swarm集群中的每个服务都分配一个虚拟IP地址和一个DNS条目，所以在同一网络中的任何一个容器可以通过服务名称跨节点访问其他服务。

#### Swarm服务发现
将容器应用部署到集群时，其服务地址，即IP和端口, 是由集群系统动态分配的。那么，当我们需要访问这个服务时，如何确定它的地址呢？这时，就需要服务发现(Service Discovery)了。

官方推荐是使用Etcd、ZooKeeper、Consul等第三方插件解决swarm集群的服务发现，而我们为了方便，使用了Overlay固定主机名的方法变相的实现了swarm集群的服务发现。


### 实战：使用swarm启动spark+hdfs+yarn集群


#### 创建overlay网络
```
docker network create -d overlay hadoopv1
```
#### 创建本地镜像库
如果我们使用swarm来启动服务，那么各种服务是分布在很多不同服务器节点上的，难道每个节点都要build所需要的镜像，或者说把image拷贝到所有节点上？
当然不用，这个时候我们要用到本地镜像仓库docker registry，用于保存images，每个节点首先在本地寻找目标镜像，如果没有的就去本地镜像拉取所需要的image即可。

##### 部署镜像库
1. 启动本地镜像库服务
```
docker service create --name registry --publish 5000:5000 \
--mount type=bind,source=/root/registry,destination=/var/lib/registry \
--constraint 'node.hostname==master' registry:2
```
> - mount参数将镜像存储目录映射出宿主机，实现服务启动后镜像库不丢失镜像,source是宿主机路径，des为容器内路径。
> - constraint参数将该服务固定在某台主机上，这样所有的镜像都可以使用一个固定的地址。

2. 修改所有节点的的配置文件
```
1. 创建或者修改 /etc/docker/daemon.json 文件，添加下面一行
    { "insecure-registries":["master:5000"] }
2. 重启docker
    sudo /etc/init.d/docker restart
```

3. 验证registry服务工作是否正常
`curl master:5000/v2/_catalog`
返回{"repositories":[]} 说明registry服务工作正常.

##### 测试本地镜像仓库
1. 首先需要将想要上传的镜像重命名为`<registry>/<image name>:<tag>`：

```
[root@node01 ~]# docker tag hadoop:v1 master:5000/hadoop:v1
[root@node01 ~]# docker images
REPOSITORY               TAG                 IMAGE ID     
...
hadoop                   v1              4e38e38c8ce0 
master:5000/hadoop   	 v1              4e38e38c8ce0 
```
2. 上传镜像

```
[root@node01 ~]# docker push master:5000/hadoop:v1
The push refers to a repository [master:5000/hadoop:v1]
4fe15f8d0ae6: Pushed
latest: digest: sha256:dc89ce8401da81f24f7ba3f0ab2914ed9013608bdba0b7e7e5d964817067dc06 
```
3. 查看上传镜像

```
[root@master ~]# curl master:5000/v2/_catalog
{"repositories":["hadoop"]}
```
可以看到hadoop镜像，已经在我们的本地镜像库中了。

4. 使用镜像库
上传完之后就可以在该集群的任何主机上使用该镜像啦。
```
version: "3"
services:
  namenode:
    image: master:5000/hadoop:v1
```

#### 使用swarm集群启动docker-compse编排后的hadoop+hdfs集群

> 注：spark historyserver存储和展示的路径`hdfs:/spark/history`需要提前创建。

```
version: "3"

services:
  namenode:
    image: master:5000/hadoop:v1
    command: [
      "hdfs",
      "namenode",
      "-Dfs.defaultFS=hdfs://0.0.0.0:9000",
      "-Ddfs.namenode.name.dir=/root/hadoop/dfs/name",
      "-Ddfs.replication=3",
      "-Ddfs.namenode.datanode.registration.ip-hostname-check=false",
      "-Ddfs.permissions.enabled=false",
      "-Ddfs.namenode.safemode.threshold-pct=0"
      ]
    hostname: namenode
    ports:
      - "50070:50070"
    networks:
      - hadoopv1
    volumes:
      - /root/hadoop/dfs/name:/root/hadoop/dfs/name
	# 将namenode服务绑定在集群中某一个主机上
    deploy:
      placement:
        constraints:
          - node.hostname == master


  datanode:
    image: master:5000/hadoop:v1
    command: [
      "hdfs",
      "datanode",
      "-fs", "hdfs://namenode:9000",
      "-Ddfs.datanode.data.dir=/root/hadoop/dfs/data",
      "-Ddfs.permissions.enabled=false"
      ]
    # 创建3各节点，按照每10s创建2各节点的速度扩展
    deploy:
      replicas: 3
      update_config:
        parallelism: 2
        delay: 10s
      restart_policy:
        condition: on-failure
    networks:
      - hadoopv1



  master:
    image: master:5000/spark:2.2.0
    command: bin/spark-class org.apache.spark.deploy.master.Master -h master
    hostname: master
    environment:
      MASTER: spark://master:7077
      SPARK_MASTER_OPTS: "-Dspark.eventLog.dir=hdfs://namenode:9000/spark/history"
      SPARK_PUBLIC_DNS: master
    ports:
      - 8080:8080
    networks:
      - hadoopv1
    deploy:
      placement:
        constraints:
          - node.hostname == master



  worker:
    image: master:5000/spark:2.2.0
    command: bin/spark-class org.apache.spark.deploy.worker.Worker spark://master:7077
    environment:
      SPARK_WORKER_CORES: 1
      SPARK_WORKER_MEMORY: 1g
      SPARK_WORKER_PORT: 8881
      SPARK_WORKER_WEBUI_PORT: 8081
      SPARK_PUBLIC_DNS: master
    networks:
      - hadoopv1
    deploy:
      replicas: 2
      update_config:
        parallelism: 2
        delay: 10s
      restart_policy:
        condition: on-failure


  historyServer:
    image: master:5000/spark:2.2.0
    command: bin/spark-class org.apache.spark.deploy.history.HistoryServer
    hostname: historyServer
    environment:
      MASTER: spark://master:7077
      SPARK_PUBLIC_DNS: master
      SPARK_HISTORY_OPTS: "-Dspark.history.ui.port=18080 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://namenode:9000/spark/history"
    ports:
      - 18080:18080
    networks:
      - hadoopv1
    deploy:
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - node.hostname == master


  ResourceManager:
    image: master:5000/hadoop:v1
    command: [
      "yarn",
      "resourcemanager",
      "-Dfs.defaultFS=hdfs://namenode:9000",
      "-Dyarn.nodemanager.aux-services=mapreduce_shuffle",
      "-Ddfs.namenode.datanode.registration.ip-hostname-check=false",
      "-Ddfs.permissions.enabled=false -Dmapreduce.framework.name=yarn",
      "-Dyarn.resourcemanager.webapp.address=0.0.0.0:8088"
        ]
    hostname: ResourceManager
    ports:
      - "8088:8088"
    networks:
      - hadoopv1
    deploy:
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - node.hostname == master

  nodemanager:
    image: master:5000/hadoop:v1
    command: [
      "yarn",
      "nodemanager",
      "-Dyarn.resourcemanager.hostname=ResourceManager",
      "-Dyarn.nodemanager.resource.memory-mb=1024",
      "-Dyarn.nodemanager.aux-services=mapreduce_shuffle",
      "-Ddfs.namenode.datanode.registration.ip-hostname-check=false",
      "-Dmapreduce.framework.name=yarn",
      "-Ddfs.permissions.enabled=false"
      ]
    networks:
      - hadoopv1
    deploy:
      replicas: 3
      update_config:
        parallelism: 2
        delay: 10s
      restart_policy:
        condition: on-failure

networks:
  hadoopv1:
    driver: overlay
```
> 注意：Swarm只支持docker-compose v3版本。

编排好各集群服务后，我们就可以使用docker swarm来部署啦
```
  # swarm启动服务
  $ docker stack deploy -c docker-compose.yml <stack name>
  # 查看服务列表和状态
  $ docker service ls
  # 查看具体某一个服务的状态（运行在哪一台主机上，状态如何）
  $ docker service ps <service name>
  # 删除服务
  $ docker stack rm <service name>
```

```
[root@master docker-spark-master]# docker stack deploy -c docker-compose.yml test1
Creating network test1_hadoopv1
Creating service test1_namenode
Creating service test1_datanode
Creating service test1_master
Creating service test1_worker
Creating service test1_historyServer
Creating service test1_ResourceManager
Creating service test1_nodemanager
[root@master docker-spark-master]# docker service ls
ID                  NAME                    MODE                REPLICAS            IMAGE               PORTS
8njt9ve5uat8        test1_ResourceManager   replicated          1/1                 hadoop:v1           *:8088->8088/tcp
m189redu2ta9        test1_datanode          replicated          3/3                 hadoop:v1           
ot1odc92qt3g        test1_historyServer     replicated          1/1                 spark:2.2.0         *:18080->18080/tcp
l6gre8dddwjy        test1_master            replicated          1/1                 spark:2.2.0         *:8080->8080/tcp
1zw4vnxwn3gt        test1_namenode          replicated          1/1                 hadoop:v1           *:50070->50070/tcp
q9hwdeqqyazo        test1_nodemanager       replicated          2/3                 hadoop:v1           
rcx81uciwrps        test1_worker            replicated          2/2                 spark:2.2.0         
[root@master docker-spark-master]# docker service ps test1_datanode
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE           ERROR               PORTS
49krv0ckjn1a        test1_datanode.1    hadoop:v1           master              Running             Running 2 minutes ago                       
zfj1k00ue8gg        test1_datanode.2    hadoop:v1           slave1              Running             Running 2 minutes ago                       
3eq1nhrb8qae        test1_datanode.3    hadoop:v1           slave2              Running             Running 2 minutes ago                       
```
既然服务已经全部启动了，那接下来我们就要在集群上跑程序测试啦

####在swarm集群运行spark程序

> 由于swarm集群不能和宿主机实现互通，因此跑任务时将程序封装成镜像单独启动一个容器，在swarm集群中运行。

```
$ docker service create --restart-condition=none --network hadoopv1 master:5000/spark:v1 \
--master spark://master:7077 --class org.apache.spark.examples.SparkPi ./examples/jars/spark-examples_2.11-2.0.2.jar

# or

$ docker service create --name spark_job \
--entrypoint "bin/spark-submit  --class org.apache.spark.examples.SparkPi  --master spark://master:7077 examples/jars/spark-examples_2.11-2.2.0.jar 10" \
--network hadoopv1 --restart-condition none master:5000/spark:v1

# 由于server会循环执行，故添加[--restart-condition=none]
```
> 由于restart-condition参数默认是any，这样会造成程序执行完重复执行，所以这里设置为none，表示容器退出后不重新启动。

#### 在swarm集群运行spark on yarn 程序

> 由于该程序需要spark、hadoop环境，因此封装镜像时需要配置这两个环境

```powershell
 $ docker service create --name yarn_job \
    -e HADOOP_CONF_DIR=/usr/hadoop/etc/hadoop \
    --entrypoint "bin/spark-submit  --class org.apache.spark.examples.SparkPi  --master yarn --deploy-mode cluster --driver-memory 512M  --executor-memory 512M examples/jars/spark-examples_2.11-2.2.0.jar 10" \
    --network hadoopv1 --restart-condition none \
    [有程序环境的镜像名]
```
至此我们使用swarm搭建hadoop+spark大数据集群任务已经全部完成。

> 注：使用swarm搭建大数据集群存在一个难以解决的问题就是需要挂载文件系统的服务不支持一键扩展，因为一个宿主机挂载点不支持同时被多个服务挂载。比如说对于datanode来说，如果想要扩展节点，只能一个个手动设置不同的挂载目录，这样才能实现数据的持久化。如果想要解决这个问题，可以尝试使用Kubernetes。



