## 部署本地镜像仓库
### 背景与意义
如果我们使用swarm来启动服务，那么各种服务是分布在很多不同服务器节点上的，难道每个节点都要build所需要的镜像，或者说把image拷贝到所有节点上？
当然不用，这个时候我们要用到本地镜像仓库docker registry，用于保存images，每个节点首先在本地寻找目标镜像，如果没有的就去本地镜像拉取所需要的image即可。

### 部署镜像库
1. 启动本地镜像库服务
```
docker service create --name registry --publish 5000:5000 \
--mount type=bind,source=/root/registry,destination=/var/lib/registry/ \
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

### 测试本地镜像仓库
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