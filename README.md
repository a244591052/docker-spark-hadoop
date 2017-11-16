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
    external: true  # 这个命令表示该配置项事先已经定义，可以使用docker config命令事先定义
```