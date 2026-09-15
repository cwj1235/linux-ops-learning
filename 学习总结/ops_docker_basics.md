# Docker 基础运维学习记录

## 一、环境检查与安装（已完成）

### 系统环境

```bash
cat /etc/os-release
uname -r
```

关键结果：

```text
CentOS Linux 7 (Core)
3.10.0-1160.el7.x86_64
```

结论：系统为 CentOS 7，内核为 `3.10`，满足 Docker CE 安装的基础条件。

### Docker 安装

安装前检查：

```bash
docker --version
```

结果：

```text
bash: docker: 未找到命令...
```

结论：安装前 Docker 不存在。

先安装 Yum 仓库管理工具：

```bash
sudo yum install -y yum-utils
```

尝试添加 Docker 官方仓库：

```bash
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

结果失败：

```text
Could not fetch/save url ... curl#35 - "TCP connection reset by peer"
```

结论：访问 Docker 官方源被中断，改用阿里云 Docker CE 仓库。

添加阿里云仓库：

```bash
sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

安装 Docker：

```bash
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

关键安装结果：

```text
docker-ce 26.1.4-1.el7
docker-ce-cli 26.1.4-1.el7
containerd.io 1.6.33-3.1.el7
docker-compose-plugin 2.27.1-1.el7
```

启动并设置开机自启：

```bash
sudo systemctl enable --now docker
```

注意：`systemctl enabled` 是错误写法，正确命令是 `systemctl enable`。

版本验证：

```bash
sudo docker version
docker compose version
```

关键结果：

```text
Client: Docker Engine - Community 26.1.4
Server: Docker Engine - Community 26.1.4
Docker Compose version v2.27.1
```

### Docker 运行环境

```bash
sudo docker info
```

关键结果：

```text
Storage Driver: overlay2
Backing Filesystem: xfs
Supports d_type: true
Cgroup Driver: cgroupfs
Cgroup Version: 1
Docker Root Dir: /var/lib/docker
Total Memory: 1.934GiB
```

结论：

- Docker 客户端和服务端均正常。
- 存储驱动为 `overlay2`。
- 文件系统为 `xfs`，且支持 `d_type`。
- CentOS 7 使用 cgroup v1 属于正常现象。
- Docker 数据目录为 `/var/lib/docker`。

## 二、镜像加速配置（已完成）

首次拉取镜像：

```bash
sudo docker run --rm hello-world
```

失败结果：

```text
Get "https://registry-1.docker.io/v2/": dial tcp 104.244.43.248:443: i/o timeout
```

结论：Docker Hub 访问超时，需要配置镜像加速。

配置文件：

```bash
sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
EOF
```

重启 Docker：

```bash
sudo systemctl restart docker
```

重新测试：

```bash
sudo docker run --rm hello-world
```

成功结果：

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

结论：

- Docker Hub 原始地址不可用。
- 配置 `https://docker.m.daocloud.io` 镜像加速后，镜像拉取和容器运行成功。
- `--rm` 表示容器退出后自动删除容器，但不会删除镜像。

## 三、镜像与容器生命周期（已完成）

### 查看现有镜像和容器

```bash
sudo docker images
sudo docker ps
sudo docker ps -a
```

关键结果：

```text
hello-world   latest   e2ac70e7319a   10.1kB
```

```text
无运行中容器
无已停止容器
```

结论：`hello-world` 镜像存在，但使用 `--rm` 运行的容器已自动删除。

### 创建并运行 Alpine 容器

```bash
sudo docker run -d --name practice-alpine alpine:latest sleep 300
```

解释：

- `run`：创建并启动容器
- `-d`：后台运行
- `--name practice-alpine`：指定容器名
- `alpine:latest`：使用 Alpine Linux 镜像
- `sleep 300`：让容器主进程睡眠 300 秒，避免立即退出

运行结果：

```text
05446b08fcd7620df6de7c07aef5810b1195370be865c82c2f02a8fd19233aef
```

这是新容器的完整 ID。

### 查看运行中的容器

```bash
sudo docker ps --filter name=practice-alpine
```

关键结果：

```text
CONTAINER ID   IMAGE           COMMAND       STATUS        NAMES
05446b08fcd7   alpine:latest   "sleep 300"   Up            practice-alpine
```

结论：容器正在后台运行。

### 查看容器详细信息

```bash
sudo docker inspect practice-alpine --format 'Name={{.Name}} State={{.State.Status}} Image={{.Config.Image}}'
```

结果：

```text
Name=/practice-alpine State=running Image=alpine:latest
```

结论：容器名为 `practice-alpine`，状态为 `running`，使用的镜像是 `alpine:latest`。

### 在运行中的容器内执行命令

```bash
sudo docker exec practice-alpine cat /etc/os-release
```

关键结果：

```text
NAME="Alpine Linux"
VERSION_ID=3.24.1
PRETTY_NAME="Alpine Linux v3.24"
```

结论：`docker exec` 可以在不进入交互 shell 的情况下，在已运行容器内执行命令。

### 停止容器

```bash
sudo docker stop practice-alpine
```

停止后查看：

```bash
sudo docker ps -a --filter name=practice-alpine
```

关键结果：

```text
STATUS
Exited (137) 21 seconds ago
```

结论：

- 容器已停止，但容器记录仍然存在。
- `docker ps` 只显示运行中的容器。
- `docker ps -a` 显示所有容器，包括已停止容器。
- `Exited (137)` 表示退出码为 `137`，即 `128 + 9`，通常表示进程收到 `SIGKILL`。`docker stop` 会先发送 `SIGTERM`，超时后再发送 `SIGKILL`；Alpine 的 `sleep` 进程未及时响应终止信号时，就可能出现该状态。

### 删除容器

```bash
sudo docker rm practice-alpine
sudo docker ps -a --filter name=practice-alpine
```

结果：

```text
practice-alpine
```

随后列表为空。

结论：容器已删除。

### 删除镜像

```bash
sudo docker rmi alpine:latest hello-world:latest
sudo docker images
```

结果：

```text
Untagged: alpine:latest
Deleted: ...
Untagged: hello-world:latest
Deleted: ...
```

最终镜像列表为空。

结论：

- `docker rm` 删除容器。
- `docker rmi` 删除镜像。
- 镜像删除前，依赖该镜像的容器必须先删除。
- 本节完成了镜像拉取、容器运行、状态检查、容器内执行命令、停止、删除容器和删除镜像的完整生命周期验证。

## 四、数据卷（已完成）

数据卷用于把数据保存在容器外部，避免容器删除后数据丢失。

### 创建数据卷

```bash
sudo docker volume create practice-volume
```

结果：

```text
practice-volume
```

### 查看数据卷信息

```bash
sudo docker volume inspect practice-volume --format '{{.Name}} {{.Mountpoint}}'
```

结果：

```text
practice-volume /var/lib/docker/volumes/practice-volume/_data
```

解释：

- `practice-volume` 是数据卷名称。
- `/var/lib/docker/volumes/practice-volume/_data` 是 Docker 在宿主机上保存该数据卷数据的真实目录。
- 容器内挂载路径由命令中的 `/data` 决定。

### 第一个容器写入数据

```bash
sudo docker run --rm \
  -v practice-volume:/data \
  alpine sh -c 'echo docker-volume-ok > /data/check.txt'
```

解释：

- `--rm`：容器执行完命令退出后自动删除。
- `-v practice-volume:/data`：把名为 `practice-volume` 的数据卷挂载到容器内的 `/data`。
- `sh -c 'echo docker-volume-ok > /data/check.txt'`：在容器内创建 `/data/check.txt` 并写入 `docker-volume-ok`。
- 必须通过 `sh -c` 执行，因为 `>` 重定向需要由容器内的 shell 解释。

执行时本地没有 `alpine:latest`，Docker 自动重新拉取镜像。

### 第二个容器读取数据

```bash
sudo docker run --rm \
  -v practice-volume:/data \
  alpine cat /data/check.txt
```

结果：

```text
docker-volume-ok
```

结论：

- 第一个容器已经退出并被删除。
- 第二个容器是新创建的容器。
- 新容器仍能读到第一个容器写入的文件，说明数据保存在 `practice-volume` 中，而不是保存在某个容器里。

### 查看和清理数据卷

```bash
sudo docker volume ls --filter name=practice-volume
sudo docker volume rm practice-volume
sudo docker volume ls --filter name=practice-volume
```

删除前：

```text
DRIVER    VOLUME NAME
local     practice-volume
```

删除后列表为空。

最后清理 Alpine 镜像：

```bash
sudo docker rmi alpine:latest
```

本节验证结论：

- `docker volume create` 创建数据卷。
- `docker volume inspect` 查看数据卷在宿主机上的挂载点。
- `-v 卷名:容器路径` 把数据卷挂载进容器。
- 容器删除后，数据卷仍然存在。
- `docker volume rm` 才会删除数据卷。
- 本节数据卷和 Alpine 镜像均已清理，不需要重做。

## 五、端口映射（已完成）

端口映射用于把宿主机端口转发到容器内端口，让外部流量可以访问容器里的服务。

本节目标：

```text
宿主机 18080 -> 容器 80
```

### 检查宿主机端口

```bash
sudo ss -lntp 'sport = :18080'
```

结果没有输出，说明宿主机 `18080` 端口空闲。

### 第一次使用 nginx:alpine 失败

```bash
sudo docker run -d \
  --name practice-nginx \
  -p 18080:80 \
  nginx:alpine
```

容器创建成功，但随后退出：

```bash
sudo docker ps -a --filter name=practice-nginx
```

关键结果：

```text
STATUS
Exited (1)
```

进一步检查：

```bash
sudo docker inspect practice-nginx \
  --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} OOM={{.State.OOMKilled}}'
```

结果：

```text
Status=exited ExitCode=1 Error= OOM=false
```

查看日志：

```bash
sudo docker logs --tail 50 practice-nginx
```

关键错误：

```text
pwrite() "/run/nginx.pid" failed (1: Operation not permitted)
```

结论：

- 容器不是端口映射失败，而是 Nginx 启动失败。
- `ExitCode=1` 表示应用启动失败。
- `OOM=false` 表示不是内存不足。
- 该环境为 CentOS 7、内核 `3.10`、Docker `26.1.4`，最新的 `nginx:alpine` 在该环境中出现兼容问题。
- 学习和生产中都不建议依赖 `latest` 标签，应使用明确版本。

### 改用固定版本 nginx:1.24-alpine

```bash
sudo docker run -d \
  --name practice-nginx \
  -p 18080:80 \
  nginx:1.24-alpine
```

解释：

- `-d`：后台运行。
- `--name practice-nginx`：指定容器名。
- `-p 18080:80`：宿主机 `18080` 映射到容器 `80`。
- `nginx:1.24-alpine`：使用固定的 Nginx 1.24 Alpine 版本，避免使用 `latest` 带来的不可预期变化。

### 验证容器运行

```bash
sudo docker ps --filter name=practice-nginx
```

关键结果：

```text
IMAGE               STATUS        PORTS                                     NAMES
nginx:1.24-alpine   Up            0.0.0.0:18080->80/tcp, :::18080->80/tcp   practice-nginx
```

查看日志：

```bash
sudo docker logs --tail 20 practice-nginx
```

关键结果：

```text
nginx/1.24.0
start worker processes
```

结论：Nginx 已正常启动。

### 验证端口映射

```bash
sudo docker port practice-nginx
```

结果：

```text
80/tcp -> 0.0.0.0:18080
80/tcp -> [::]:18080
```

从宿主机访问：

```bash
curl -I http://127.0.0.1:18080
```

关键结果：

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0
```

结论：

- 宿主机 `18080` 已成功转发到容器内 `80`。
- `curl` 返回 `200 OK`，说明端口映射和 Nginx 服务均正常。

### 清理练习环境

```bash
sudo docker stop practice-nginx
sudo docker rm practice-nginx
sudo docker rmi nginx:1.24-alpine
```

结果：

```text
practice-nginx
practice-nginx
Untagged: nginx:1.24-alpine
Deleted: ...
```

结论：端口映射练习容器和固定版本镜像已清理。

本节验证结论：

- `-p 宿主机端口:容器端口` 用于端口映射。
- `docker ps` 只能判断容器是否正在运行，不能证明服务可用。
- 服务是否可用要用 `curl`、`docker port`、`docker logs` 共同判断。
- 容器退出时，应先用 `docker ps -a`、`docker inspect` 和 `docker logs` 查原因。
- 镜像标签应尽量固定版本，避免 `latest` 在老内核环境中引入兼容风险。

## 六、Dockerfile 自定义镜像（已完成）

Dockerfile 用于描述如何构建自定义镜像。本节目标是制作一个自定义 Nginx 镜像，并替换默认首页。

### 创建练习目录

```bash
mkdir -p ~/dockerfile-practice
cd ~/dockerfile-practice
```

### 创建自定义首页

```bash
cat > index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Dockerfile Practice</title>
</head>
<body>
  <h1>Dockerfile build success</h1>
</body>
</html>
EOF
```

### 创建 Dockerfile

```dockerfile
FROM nginx:1.24-alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

指令解释：

- `FROM nginx:1.24-alpine`：指定基础镜像。CentOS 7 内核 `3.10` 环境下已验证该版本可用，不使用 `latest`。
- `COPY index.html /usr/share/nginx/html/index.html`：构建镜像时，把当前目录的 `index.html` 复制到镜像内的 Nginx 默认首页路径。
- `EXPOSE 80`：声明容器内使用 80 端口。它只是声明，不等于端口映射；实际访问仍需要 `docker run -p`。
- `CMD ["nginx", "-g", "daemon off;"]`：指定容器默认启动命令，让 Nginx 前台运行，防止主进程退出导致容器退出。

### 构建镜像

第一次执行时少了构建上下文：

```bash
sudo docker build -t practice-nginx-image:1.0
```

报错：

```text
ERROR: "docker buildx build" requires exactly 1 argument.
```

正确命令必须在最后加上当前目录 `.`：

```bash
sudo docker build -t practice-nginx-image:1.0 .
```

解释：

- `-t practice-nginx-image:1.0`：镜像名为 `practice-nginx-image`，标签为 `1.0`。
- `.`：使用当前目录作为构建上下文，Docker 会从该目录读取 `Dockerfile` 和 `COPY` 引用的文件。

### 查看镜像

```bash
sudo docker images practice-nginx-image
sudo docker history practice-nginx-image:1.0
```

### 运行自定义镜像

```bash
sudo ss -lntp 'sport = :18081'

sudo docker run -d \
  --name practice-nginx-image \
  -p 18081:80 \
  practice-nginx-image:1.0
```

解释：

- `-d`：后台运行。
- `--name practice-nginx-image`：指定容器名。
- `-p 18081:80`：宿主机 `18081` 映射到容器内 `80`。
- `practice-nginx-image:1.0`：运行刚构建的自定义镜像。

### 验证自定义页面

```bash
sudo docker ps --filter name=practice-nginx-image
sudo docker port practice-nginx-image
curl -I http://127.0.0.1:18081
curl http://127.0.0.1:18081
```

关键结果：

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Dockerfile Practice</title>
</head>
<body>
  <h1>Dockerfile build success</h1>
</body>
</html>
```

结论：

- 镜像构建成功。
- `COPY` 成功把本地 `index.html` 复制进镜像。
- Nginx 正常启动。
- 端口映射 `18081 -> 80` 生效。
- 自定义页面可以正常访问。

### 清理练习环境

```bash
sudo docker stop practice-nginx-image
sudo docker rm practice-nginx-image
sudo docker rmi practice-nginx-image:1.0
sudo docker images
```

结果：

```text
practice-nginx-image
practice-nginx-image
Untagged: practice-nginx-image:1.0
Deleted: ...
```

最终镜像列表为空。

注意：

```bash
sudo docker image
```

单独执行只会显示 `docker image` 子命令帮助；查看镜像列表应使用：

```bash
sudo docker images
```

`~/dockerfile-practice` 目录仍保留，里面包含 `Dockerfile` 和 `index.html` 源文件。它不是 Docker 运行资源，可按需保留或删除。

本节结论：

- `COPY` 在构建镜像时复制文件。
- `CMD` 指定容器默认启动命令。
- `EXPOSE` 只是声明端口，实际访问仍需要 `-p`。
- 构建命令最后的 `.` 是构建上下文，不能省略。
- 自定义镜像构建、运行、访问和清理均已完成。

## 七、Docker Compose 编排（已完成）

Docker Compose 用于通过一个 `docker-compose.yml` 定义和管理多个容器。本节目标是用 Compose 同时启动 Nginx Web 服务和 Redis Cache 服务。

### 创建练习目录

```bash
mkdir -p ~/compose-practice
cd ~/compose-practice
```

### 创建自定义首页

```bash
cat > index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Compose Practice</title>
</head>
<body>
  <h1>Docker Compose success</h1>
</body>
</html>
EOF
```

### 创建 docker-compose.yml

```yaml
services:
  web:
    image: nginx:1.24-alpine
    container_name: practice-compose-web
    ports:
      - "18082:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
    depends_on:
      - cache
    restart: unless-stopped

  cache:
    image: redis:7.2-alpine
    container_name: practice-compose-cache
    restart: unless-stopped
```

配置解释：

- `services`：定义多个服务。
- `web`：Nginx Web 服务。
- `cache`：Redis Cache 服务。
- `image`：指定服务使用的镜像。
- `container_name`：固定容器名。
- `ports`：宿主机端口映射。本节只把 Web 的 `18082` 映射到容器 `80`。
- `volumes`：把当前目录的 `index.html` 只读挂载到 Nginx 默认首页路径。
- `depends_on`：控制启动顺序，先启动 `cache`，再启动 `web`。
- `restart: unless-stopped`：容器异常退出时自动重启，手动停止后不自动重启。
- `cache` 没有配置 `ports`，Redis 只在 Compose 内部网络中使用，不暴露宿主机端口。
- 未写 `version`，因为当前 Compose v2 不再要求该字段。

### 检查配置

```bash
sudo docker compose config
```

关键结果：

```text
name: compose-practice
services:
  cache:
    image: redis:7.2-alpine
  web:
    image: nginx:1.24-alpine
    depends_on:
      cache:
        condition: service_started
networks:
  default:
    name: compose-practice_default
```

结论：YAML 语法有效，Compose 自动解析出项目名、默认网络和服务依赖。

### 检查宿主机端口

```bash
sudo ss -lntp 'sport = :18082'
```

结果没有输出，说明宿主机 `18082` 端口空闲。

### 启动服务

```bash
sudo docker compose up -d
```

关键结果：

```text
Network compose-practice_default Created
Container practice-compose-cache Started
Container practice-compose-web Started
```

结论：Compose 自动创建默认网络，并按依赖顺序启动两个服务。

### 查看服务状态

```bash
sudo docker compose ps
sudo docker ps --filter name=practice-compose
```

关键结果：

```text
practice-compose-cache   redis:7.2-alpine    Up   6379/tcp
practice-compose-web     nginx:1.24-alpine   Up   0.0.0.0:18082->80/tcp
```

结论：

- 两个服务均正常运行。
- Redis 只显示容器内部端口 `6379/tcp`，没有映射到宿主机。
- Nginx 将宿主机 `18082` 映射到容器 `80`。

### 验证 Web 服务

```bash
curl -I http://127.0.0.1:18082
curl http://127.0.0.1:18082
```

关键结果：

```text
HTTP/1.1 200 OK
Server: nginx/1.24.0
```

```html
<h1>Docker Compose success</h1>
```

结论：Web 服务和只读挂载的自定义首页均正常。

### 验证 Redis 服务

```bash
sudo docker compose exec cache redis-cli PING
sudo docker compose exec cache redis-cli SET compose:practice ok
sudo docker compose exec cache redis-cli GET compose:practice
```

关键结果：

```text
PONG
OK
"ok"
```

注意：第一次执行时误写成：

```bash
sudo docker compose exec cache redis-cli GET compose:practice ok
```

报错：

```text
ERR wrong number of arguments for 'get' command
```

原因是 `GET` 只接受一个 key，末尾多传了 `ok`。去掉多余参数后成功读回 `"ok"`。

### 查看日志

```bash
sudo docker compose logs --tail 20 web
sudo docker compose logs --tail 20 cache
```

Web 日志显示 Nginx 正常启动，并记录了 `HEAD /` 和 `GET /` 两条 `200` 访问日志。

Cache 日志显示 Redis `7.2.16` 正常启动并准备接受连接。

Redis 容器日志中有一条警告：

```text
The TCP backlog setting of 511 cannot be enforced because somaxconn is set to 128
```

说明 Redis 容器所在网络命名空间中的 `somaxconn` 为 `128`。这与宿主机正式 Redis 实例的 `somaxconn=1024` 是不同环境，不影响本节 Compose 基础验证，未做调整。

### 清理 Compose 环境

```bash
sudo docker compose down
sudo docker compose ps
sudo docker network ls | grep compose-practice
sudo docker images
```

关键结果：

```text
Container practice-compose-web Removed
Container practice-compose-cache Removed
Network compose-practice_default Removed
```

随后 `docker compose ps` 为空。

删除练习镜像：

```bash
sudo docker rmi nginx:1.24-alpine redis:7.2-alpine
sudo docker images
```

关键结果：

```text
Untagged: nginx:1.24-alpine
Untagged: redis:7.2-alpine
Deleted: ...
```

最终镜像列表为空。

`~/compose-practice` 目录仍保留，包含 `docker-compose.yml` 和 `index.html` 源文件，可用于回看配置。

本节结论：

- `docker compose config` 可检查 YAML 配置。
- `docker compose up -d` 可一次性启动多个服务。
- `docker compose ps` 查看服务状态。
- `docker compose exec` 可在指定服务容器内执行命令。
- `docker compose logs` 查看服务日志。
- `docker compose down` 停止并删除容器和默认网络。
- Compose 基础编排、验证和清理已完成。

## 八、后续学习与验收

1. 提交并推送 Docker/Compose 阶段学习记录。
2. 再规划下一阶段学习内容。

当前 Docker 安装、镜像加速、镜像与容器基础生命周期、数据卷、端口映射、Dockerfile 自定义镜像、Docker Compose 编排均已完成，后续不要重做。
