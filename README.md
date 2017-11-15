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

docker swarm：集群管理，子命令有init, join, leave, update。（docker swarm --help查看帮助）
docker service：服务创建，子命令有create, inspect, update, remove, tasks。（docker service--help查看帮助）
docker node：节点管理，子命令有accept, promote, demote, inspect, update, tasks, ls, rm。（docker node --help查看帮助）