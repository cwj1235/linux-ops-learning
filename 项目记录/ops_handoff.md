# 运维学习交接文件

归档位置：`项目记录/ops_handoff.md`。

用途：重开 Codex 线程、切换到 DeepSeek/GLM/Claude Code，或之后复习时，让新模型快速接上当前学习进度。

最后更新：2026-07-11

## 1. 学习目标

我是从零开始学习 Linux 运维/云运维的学生，目标是明年能找运维实习。

学习目标不是“看完教程”，而是能真正上手做基础运维工作：

- 能看懂 Linux 服务状态、端口、日志、配置文件。
- 能部署和维护 Nginx、MySQL、Redis、Docker 等基础服务。
- 能排查常见故障，比如 403、404、502、端口不通、DNS 问题、权限/SELinux 问题。
- 能把项目整理成简历和面试能讲清楚的内容。

## 2. 教学方式要求

请严格按这个节奏教：

```text
概念 -> 命令 -> 我执行 -> 解释输出 -> 总结 -> 下一步
```

规则：

- 用中文。
- 我是纯小白，不要默认我懂。
- 一次不要给太多命令，最好 1 到 3 条。
- 等我执行完、确认懂了，再进入下一步。
- 每个命令都要解释语法、参数、作用。
- 我问“什么意思”时，先停下来解释，不要继续往后推。
- 我发命令输出时，要根据输出判断当前状态，再告诉我下一步。
- 不要只带我做项目，也要系统讲知识点。
- 每个模块都要覆盖：
  - 知识地图
  - 核心概念
  - 常用命令
  - 参数解释
  - 配置文件
  - 服务管理
  - 端口网络
  - 日志
  - 常见故障
  - 排查流程
  - 实战练习
  - 复习总结
  - 面试/简历表达

## 2.1 记忆和交接文件维护要求

以后每次学习结束或阶段结束，都要同步维护本地文件，不能只在聊天里说完就结束。

必须维护这些信息：

```text
1. 当前学到哪个模块、哪个小节
2. 已经实际敲过哪些命令
3. 每条关键命令验证到了什么结果
4. 遇到过什么报错或故障
5. 最后是怎么排查和修复的
6. 这节内容和前面 Linux / 网络 / Shell / crontab / Nginx / systemd / 日志 有什么关系
7. 哪些知识点已经完成
8. 哪些知识点只是后续再补，不要现在展开
9. 下一步明确学什么
10. 学习笔记正文必须用中文，命令、配置、路径、日志字段保留原样
```

文件分工：

```text
项目记录/memory.md
  -> 记录长期上下文、当前进度、用户偏好、下一步方向。

项目记录/ops_handoff.md
  -> 给新线程/其他模型看的交接文件，必须能让对方快速知道当前路线和下一步。

项目记录/ops_command_history.md
  -> 记录已经实际敲过的命令、关键输出、学到的结论，避免其他模型重复旧练习或误判基础。

学习总结/ops_模块名.md
  -> 每个模块的系统复习笔记，例如 network/shell/crontab/nginx/mysql。
```

更新原则：

```text
不要保存完整聊天记录。
不要记录密码、密钥、隐私账号。
不要只写“学了 Nginx”，要写清楚学了哪些命令、哪些配置、哪些故障、下一步是什么。
如果用备用模型学习，学完后也要按这个格式总结，之后交给 Codex 检查和校准。
```

## 3. 当前环境

虚拟机环境：

```text
VMware
CentOS 7
用户：atguigu
主机名：centos100
Linux IP：192.168.6.100/24
网关：192.168.6.2
DNS：192.168.6.2
Windows VMnet8：192.168.6.1
```

主要服务：

```text
Nginx：80/tcp
backend-demo：8080/tcp
SSH：22/tcp
MariaDB/MySQL：3306/tcp
```

重要文件：

```text
/etc/nginx/nginx.conf
/var/log/nginx/access.log
/var/log/nginx/error.log
/opt/scripts/check_nginx.sh
/var/log/nginx_check.log
/etc/systemd/system/backend-demo.service
/opt/backend-demo/index.html
/etc/my.cnf
/etc/my.cnf.d/
/var/lib/mysql
/var/log/mariadb/mariadb.log
```

## 4. 已完成内容

### 4.1 Linux 基础第一阶段

已完成尚硅谷《Linux零基础教程，linux安装部署（虚拟机、Shell脚本、云服务器）》77 集。

后续不是单纯继续看视频，而是按“系统知识 + 实操 + 排障 + 总结”的方式推进。

### 4.2 网络基础第一阶段

已经讲过并练习：

```text
127.0.0.1
192.168.6.100
192.168.6.1
192.168.6.2
/24
网关
DNS
ping
ip addr
ip route
ip route get
nslookup
dig
TCP
UDP
ICMP
端口
ss -lntp
firewalld
curl -I
HTTP 状态码
```

关键理解：

```text
IP 找机器，端口找服务。
同网段直接访问，不同网段走网关。
域名访问先经过 DNS 解析。
127.0.0.1 永远表示当前机器自己。
```

### 4.3 Nginx 静态网站

已完成：

- 安装 Nginx。
- 启动 Nginx。
- 开放 80 端口。
- 浏览器访问 `http://192.168.6.100`。
- 修改网站目录到 `/var/www/ops-site`。
- 创建静态网页。
- 查看 access.log 和 error.log。
- 练习 403、404、200、500、502 等状态码。
- 处理 SELinux 文件上下文问题。

关键命令：

```bash
sudo systemctl status nginx
ss -lntp | grep :80
curl -I http://192.168.6.100
sudo nginx -t
sudo tail -n 20 /var/log/nginx/error.log
sudo chcon -R -t httpd_sys_content_t /var/www/ops-site
```

关键理解：

```text
403 常见原因：权限/SELinux。
404 常见原因：路径或文件不存在。
502 常见原因：Nginx 后面的后端服务挂了或连不上。
```

### 4.4 Shell 第一阶段

围绕 `/opt/scripts/check_nginx.sh` 学过：

```text
变量
单引号/双引号
if 判断
-f 文件测试
-d 目录测试
$? 退出状态
命令替换 $()
stat -c%s
数值比较 -gt
curl -o /dev/null -s -w "%{http_code}"
systemctl is-active --quiet
日志追加 >>
函数 log()
bash -n
手动执行脚本
```

脚本功能：

```text
检查 Nginx 是否运行。
如果没运行，自动启动。
检查网站 HTTP 状态码。
如果不是 200，重启 Nginx 后再检查。
日志写入 /var/log/nginx_check.log。
日志超过 1MB 时备份并新建。
```

### 4.5 crontab 第一阶段

已完成：

```bash
sudo crontab -l
crontab -l
```

root crontab 曾配置：

```cron
* * * * * /opt/scripts/check_nginx.sh
```

学过定时表达式：

```text
每分钟
每 10 分钟
每天凌晨 3 点
每周一凌晨 2 点 30 分
每天 9 点、12 点、18 点
每天 9 点到 18 点
```

关键理解：

```text
crontab 用来定时执行任务。
sudo crontab 是 root 的定时任务。
普通 crontab 是当前用户的定时任务。
```

### 4.6 Nginx 反向代理 + systemd 后端服务

已完成：

- 创建后端目录 `/opt/backend-demo`。
- 创建后端页面 `/opt/backend-demo/index.html`。
- 用 Python 2 的 `SimpleHTTPServer` 提供 8080 后端服务。
- 创建 systemd 服务 `backend-demo.service`。
- Nginx 通过 `proxy_pass http://127.0.0.1:8080;` 转发到后端。
- 处理 SELinux 反向代理限制。
- 设置后端服务开机自启动。
- 模拟后端挂掉，观察 Nginx 返回 502。
- 查看 Nginx error.log 中的 upstream 错误。
- 恢复后端服务，确认访问恢复。

当前成功状态：

```text
backend-demo.service：enabled
backend-demo.service：active (running)
curl http://192.168.6.100
返回：Hello from systemd backend 8080
```

关键配置：

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
}
```

关键 systemd 文件：

```ini
[Unit]
Description=Backend Demo Python HTTP Server
After=network.target

[Service]
Type=simple
User=atguigu
WorkingDirectory=/opt/backend-demo
ExecStart=/usr/bin/python -m SimpleHTTPServer 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

关键 SELinux 命令：

```bash
sudo setsebool -P httpd_can_network_connect on
```

关键理解：

```text
Nginx 反向代理 = 用户访问 Nginx，Nginx 再转发给后端。
502 = Nginx 活着，但后端服务挂了或连不上。
start = 现在启动。
enable = 开机自启动。
```

### 4.7 Nginx location 匹配规则 + proxy_set_header + access.log + 故障排查

已完成：

- location 四种匹配前缀：`=` 精确匹配（最高优先）、`^~` 前缀优先、`~` 正则匹配、普通前缀匹配（兜底）。
- 继承规则：location 没写的指令可以从 server 块继承，例如 `root`。
- 验证了 `location = /404.html` 精确匹配后继承 `root` 返回本地文件。
- `>` / `>>` / `tee`：
  - `>` 覆盖写入。
  - `>>` 追加写入。
  - `sudo echo "x" > file` 可能失败，因为 `sudo` 只作用在 `echo`，不作用在 shell 重定向。
  - `echo "x" | sudo tee file` 可以用 root 权限写入文件。
  - `tee -a` 表示追加。
- `proxy_set_header Host $host`：把用户访问时的原始域名/IP 传给后端。
- `proxy_set_header X-Real-IP $remote_addr`：把用户真实 IP 传给后端。
- access.log 常见字段逐列解释：客户端 IP、时间、请求行、状态码、响应大小、referer、user-agent、x-forwarded-for 等。
- GET vs HEAD：
  - GET 返回响应头和响应体。
  - HEAD 只返回响应头。
  - `curl -I` 使用 HEAD 请求。
- 403/404/502/504 四种状态码的排查流程。
- 504 超时概念：`proxy_connect_timeout`、`proxy_read_timeout`、`proxy_send_timeout`。
- 域名、服务器、服务、DNS 等核心概念。
- Nginx 阶段总结，创建了 `ops_nginx_stage1.md`。

### 4.8 MySQL/MariaDB 系统运维第一阶段

当前正在学习 MySQL/MariaDB 系统运维，已经完成安装、启动、服务检查、端口检查、配置/数据目录/日志查看、用户 Host 概念和基础 SQL。

已经执行并理解：

```bash
rpm -qa | grep -Ei 'mysql|mariadb'
systemctl status mariadb
ss -lntp | grep :3306
sudo yum install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl status mariadb
sudo systemctl enable mariadb
mysql -uroot -e "SELECT VERSION();"
sudo systemctl is-enabled mariadb
sudo systemctl is-active mariadb
mysql -uroot -e "SHOW DATABASES;"
mysql -uroot -e "SHOW VARIABLES LIKE 'datadir';"
sudo ls -ld /var/lib/mysql
sudo ls -l /var/lib/mysql
rpm -qc mariadb-server
sudo grep -RniE "datadir|socket|port|bind-address" /etc/my.cnf /etc/my.cnf.d
sudo tail -n 30 /var/log/mariadb/mariadb.log
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
mysql -uroot -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -h127.0.0.1 -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -e "CREATE DATABASE ops_demo;"
mysql -uroot ops_demo -e "CREATE TABLE servers(id INT PRIMARY KEY AUTO_INCREMENT,hostname VARCHAR(50),ip VARCHAR(50), role VARCHAR(50));"
mysql -uroot ops_demo -e "INSERT INTO servers(hostname,ip,role) VALUES ('centos100','192.168.6.100','nginx-mysql-backend');"
mysql -uroot ops_demo -e "SELECT * FROM servers;"
mysql -uroot ops_demo -e "UPDATE servers SET role='all-in-one' WHERE hostname='centos100';"
mysql -uroot ops_demo -e "INSERT INTO servers (hostname, ip, role) VALUES ('test-host', '192.168.6.200', 'test');"
mysql -uroot ops_demo -e "DELETE FROM servers WHERE hostname='test-host';"
```

当前 MariaDB 状态：

```text
mariadb.service 已安装。
mariadb.service 已启动。
mariadb.service 已设置开机自启动。
3306 端口正在监听。
版本是 5.5.68-MariaDB。
数据目录是 /var/lib/mysql/。
日志文件是 /var/log/mariadb/mariadb.log。
业务库 ops_demo 已创建。
servers 表已创建。
最终数据：centos100 / 192.168.6.100 / all-in-one。
```

已经遇到并解决：

```text
ERROR 1046 (3D000): No database selected

原因：
创建表时没有选择数据库。

修复：
使用 mysql -uroot ops_demo -e "CREATE TABLE ..."
```

关键理解：

```text
MariaDB 是 MySQL 兼容分支，CentOS 7 常用它作为 MySQL 学习和运维环境。
服务名是 mariadb，进程名常见是 mysqld，客户端命令是 mysql。
active 表示当前运行，enabled 表示开机自启动。
MySQL 账号要看 User + Host。
远程连接 MySQL 需要同时满足：3306 监听、firewalld 放行、MySQL 用户 Host 允许、网络可达。
基础 SQL 用于运维检查库、表、数据、权限和备份恢复结果。
UPDATE/DELETE 必须小心 WHERE。
```

## 5. 本地笔记文件索引

项目目录：

```text
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat
```

核心记忆文件：

```text
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\项目记录\memory.md
```

复习笔记：

```text
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\学习总结\ops_network_basics.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\学习总结\ops_shell_basics.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\学习总结\ops_crontab_basics.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\学习总结\ops_nginx_reverse_proxy.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\学习总结\ops_nginx_stage1.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\学习总结\ops_mysql_basics.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\项目记录\ops_command_history.md
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\项目记录\ops_handoff.md
```

读取顺序建议：

```text
1. 项目记录/ops_handoff.md
2. 项目记录/memory.md
3. 项目记录/ops_command_history.md
4. 当前模块笔记，当前是 学习总结/ops_mysql_basics.md
5. 如果缺前置知识，再读 network/shell/crontab 笔记
```

## 6. 当前准确进度

2026-08-26 用户要求重新评估整条运维学习路线是否符合实习目标，并先复习前面内容，再继续新模块。后续不得直接按旧的“MySQL 常见故障 -> Redis”顺序推进；应先做基础能力体检和复习，再根据结果补齐 Git/GitHub、Docker/Compose、Ansible、监控、云主机和综合项目等实习能力。

现在正在 MySQL/MariaDB 系统运维模块，不要重新开始。

已经完成：

```text
MariaDB 安装
mariadb 服务启动、状态检查、开机自启动
3306 端口检查
MariaDB 版本查看
默认数据库查看
数据目录 /var/lib/mysql 查看
配置文件和日志位置查看
User + Host 权限概念
USER() / CURRENT_USER()
创建 ops_demo 数据库
创建 servers 表
INSERT / SELECT / UPDATE / DELETE 基础 SQL
No database selected 报错排查
mysqldump 手动备份和恢复
模拟 DELETE 误删后恢复验证
Shell 备份脚本
backup.log 日志记录
普通用户 crontab 每天凌晨 3 点定时备份
备份保留策略：只清理 7 天前的 ops_demo_*.sql
MySQL 用户权限和安全加固已开始
匿名用户已删除并验证没有输出
已创建 ops_user@localhost
已验证 ops_user 初始只有 USAGE 权限
已验证授权前 ops_user 只能看到 information_schema 和 test
已授予 ops_user@localhost 对 ops_demo.* 的 SELECT、INSERT、UPDATE、DELETE 权限
已通过 SHOW GRANTS 验证授权成功
```

旧的下一步建议（已暂停直接推进）：

```text
1. MySQL 常见故障排查小练习。
2. 完成 MySQL 第一阶段总结。
3. Redis 系统运维。
4. 月总结（Shell + Nginx + MySQL + Redis 串成小运维环境）。
5. 云服务器实操。
6. Docker 与 Docker Compose。
7. 监控、日志、告警和简单 CI/CD。
8. 项目文档、简历和面试准备。
```

## 7. 知识串联关系

后续教学不能把 MySQL、Redis、Docker、云服务器当成孤立知识点讲。每进入一个新模块，都要主动说明它和前面内容的关系。

### 7.1 前面已学内容的作用

```text
Linux 基础
  -> 所有服务都跑在 Linux 上
  -> 后面安装、启动、查看文件、改配置、查日志都依赖它

网络基础
  -> 判断 IP、端口、网关、DNS、连接拒绝、连接超时
  -> 后面 MySQL 3306、Redis 6379、Docker 端口映射、云服务器安全组都依赖它

Shell
  -> 写巡检脚本、备份脚本、日志清理脚本
  -> 后面 MySQL 备份、Redis 检查、监控告警都会用

crontab
  -> 定时执行 Shell 脚本
  -> 后面 MySQL 定时备份、日志清理、服务巡检都会用

Nginx
  -> 网站入口
  -> 反向代理后端服务
  -> 后面云服务器上线、Docker 多服务代理、HTTPS 都会继续用

systemd
  -> 管理服务生命周期
  -> Nginx、backend-demo、MySQL、Redis 都要用 systemctl 管理

firewalld / 安全组
  -> 控制端口能不能被访问
  -> 本地练 firewalld，云服务器阶段对应安全组

日志
  -> 判断故障原因
  -> Nginx 看 access.log/error.log，MySQL/Redis 后面也要看各自日志

SELinux
  -> 解释“权限看起来对，但服务还是访问失败”
  -> Nginx 已遇到，后面改数据目录或服务访问时也可能遇到
```

### 7.2 后续模块怎么和前面串起来

MySQL 模块必须这样串：

```text
安装 MySQL/MariaDB
  -> 用 yum，延续 Linux 软件安装

启动数据库
  -> 用 systemctl，和 nginx/backend-demo 一样

查看 3306 端口
  -> 用 ss -lntp，和查看 80/8080 一样

判断能不能远程连接
  -> IP + 端口 + firewalld + MySQL 用户权限

备份数据库
  -> mysqldump + Shell 变量 + date 命令替换

定时备份
  -> crontab

排查数据库故障
  -> systemctl + ss + 日志 + 配置文件 + 权限
```

Redis 模块必须这样串：

```text
启动 Redis
  -> systemctl

查看 6379 端口
  -> ss -lntp

判断连接失败
  -> 网络 + 端口 + bind 配置 + 防火墙

查看持久化
  -> 配置文件 + 数据目录

写巡检
  -> Shell + crontab
```

Docker 模块必须这样串：

```text
容器端口映射
  -> 网络基础里的 IP + 端口

Docker Compose 多服务
  -> Nginx 反向代理 + MySQL + Redis + 后端服务

容器自启动
  -> 类比 systemd 的服务管理思想

容器日志
  -> 类比 Nginx/MySQL/Redis 日志排障
```

云服务器模块必须这样串：

```text
公网 IP / 私网 IP
  -> 网络基础

安全组
  -> 类比 firewalld

域名解析
  -> DNS

HTTPS
  -> Nginx 进阶

真实部署
  -> Nginx + 后端 + MySQL + Redis + Shell 备份
```

监控日志模块必须这样串：

```text
服务是否存活
  -> systemctl

端口是否监听
  -> ss

网站是否正常
  -> curl 状态码

日志是否有错误
  -> tail / grep / awk

定时巡检
  -> Shell + crontab
```

### 7.3 每节课开头必须说明

后续每节课建议按这个开头：

```text
本节位置：
说明当前属于哪个模块。

和前面知识的关系：
说明会用到 Linux / 网络 / Shell / crontab / Nginx / systemd / 日志里的哪些东西。

真实运维场景：
说明工作里什么时候会遇到。

今天目标：
说明学完要会什么。

开始命令：
一次只给 1-3 条命令。
```

例如 MySQL 第一节应该这样开：

```text
本节位置：
MySQL 系统运维第一节。

和前面知识的关系：
- 用 systemctl 管理数据库服务，和管理 nginx/backend-demo 一样。
- 用 ss 看 3306 端口，和看 80/8080 一样。
- 用 firewalld 判断能不能远程访问，和开放 80/8080 一样。
- 后面备份会用 Shell 变量、date、crontab。
- MySQL 是后端服务的数据存储，和 Nginx/后端组成完整网站链路。

真实运维场景：
网站能打开，但登录/查询失败，可能不是 Nginx 问题，而是后端连不上数据库。
```

## 8. 重开线程开场白

新线程可以直接复制：

```text
我正在从零学习 Linux 运维/云运维，目标是明年能找运维实习。

请先读取：
C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat\项目记录\ops_handoff.md

如果你不能读取文件，我会把内容贴给你。

请严格按这个节奏教：
概念 -> 命令 -> 我执行 -> 解释输出 -> 总结 -> 下一步。

不要重新开始。我的当前进度是：
Linux 基础、网络基础、Shell、crontab 已完成第一阶段；
Nginx 静态网站、Nginx 反向代理、systemd 后端服务、502 排障已完成。

当前 backend-demo.service 已经 enabled，并且 curl http://192.168.6.100 返回：
Hello from systemd backend 8080

请先告诉我你理解的当前进度，然后从 MySQL 开始，慢慢讲。
```

## 9. 给备用模型的限制

如果使用 DeepSeek、GLM、Claude Code 等备用模型，请要求它：

```text
不要重新规划整条路线。
不要一次给很多命令。
不要跳到 Docker、K8s、云服务器。
当前 Nginx 第一阶段已完成，MySQL/MariaDB 的基础 SQL、备份恢复、定时备份、保留策略和用户权限练习已经完成；最新停点是 MySQL 常见故障排查。
如果不确定上下文，先问，不要猜。
```

## 10. 最重要的一句话

```text
这条学习路线的核心不是追模型，而是保证上下文、笔记、练习闭环不断。
```

## 11. 2026-07-09 MySQL/MariaDB 最新进度

MySQL/MariaDB 已经从“基础 SQL”推进到“备份恢复 + 脚本化 + crontab 定时备份验证 + 7 天保留策略”。

已经完成：

```text
mysqldump 工具检查。
手动备份 ops_demo。
查看备份 SQL 文件内容。
恢复到新库 ops_demo_restore。
验证恢复后的库、表、行数和关键数据。
在 ops_demo_restore 中模拟 DELETE 误删。
用备份文件再次恢复数据。
使用 DATE 时间戳生成不会覆盖旧文件的备份名。
创建 ~/backup_ops_demo.sh 备份脚本。
用 bash -n 检查脚本语法。
手动执行脚本并确认生成新备份。
加入 STATUS=$? 成功/失败判断。
加入 log() 函数和 /home/atguigu/mysql_backup/backup.log 日志。
用普通用户 crontab 每分钟执行一次脚本并验证成功。
把测试 crontab 改为每天凌晨 3 点正式执行。
学习 du 和 find 查找备份目录空间与旧备份。
学习 -mtime +7、-mtime -1 和 -delete。
把“只清理 7 天前 ops_demo_*.sql”的逻辑加入备份脚本。
手动执行脚本并验证 backup.log 出现 old backups cleaned。
```

关键命令和结果：

```bash
which mysqldump
mysqldump --version
mysqldump -uroot ops_demo > ~/mysql_backup/ops_demo.sql
mysql -uroot ops_demo_restore < ~/mysql_backup/ops_demo.sql
mysql -uroot ops_demo_restore -e "SELECT COUNT(*) FROM servers;"
bash -n ~/backup_ops_demo.sh
bash ~/backup_ops_demo.sh
tail -n 10 ~/mysql_backup/backup.log
crontab -l
du -sh ~/mysql_backup
find ~/mysql_backup -name "*.sql" -mtime +7
find ~/mysql_backup -name "*.sql" -mtime -1
tail -n 5 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup | tail
```

关键结果：

```text
mysqldump 路径：/usr/bin/mysqldump
bash 路径：/usr/bin/bash
备份目录：/home/atguigu/mysql_backup
备份脚本：/home/atguigu/backup_ops_demo.sh
日志文件：/home/atguigu/mysql_backup/backup.log
恢复库：ops_demo_restore
测试 crontab：* * * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
crontab 验证成功：19:41 和 19:42 都自动生成了备份日志和 .sql 文件。
正式 crontab：0 3 * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
备份目录大小：60K
最新手动备份文件：ops_demo_20260709_202912.sql
保留策略日志：old backups cleaned: keep last 7 days
```

重要理解：

```text
mysqldump -uroot ops_demo > 文件
  -> 备份。

mysql -uroot 库名 < 文件
  -> 恢复。

备份不是目的，能恢复并验证才算真正备份成功。

crontab 是否成功，不能只看 crontab -l，要看日志和结果文件。

crontab 环境更简陋，推荐使用 /usr/bin/bash 和 /home/atguigu/backup_ops_demo.sh 这种绝对路径。

危险命令先预览，再执行；能先查就不要先删。

find ... -mtime +7 用于查找超过 7 天的旧文件。

find ... -delete 会真的删除匹配文件，执行前必须确认目录、文件名规则和时间条件。

备份清理逻辑应放在备份成功之后，避免旧备份删了、新备份又失败。
```

已确认的最后一步：

```bash
crontab -l
```

输出已经改成：

```cron
0 3 * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

说明测试用的每分钟备份任务已经改为每天凌晨 3 点执行。

下一步学习建议：

```text
1. 建立 MariaDB 正常状态基线。
2. 完成 MySQL 常见故障排查小练习。
3. 完成 MySQL 第一阶段总结。

新的下一步：

```text
1. 先做 Linux/网络/服务状态基线体检。
2. 按 Linux -> 网络 -> Shell/crontab -> Nginx -> MySQL 顺序复习，边复习边做故障题。
3. 根据体检结果补缺，再进入 Redis 和 Git/GitHub。
4. 后续补 Docker/Compose、Ansible、监控、云服务器和综合项目。
```

### 2026-08-26 确定的新学习路线

```text
阶段 0：前置知识复习与能力体检（2 周）
阶段 1：Linux 运维强化（2～3 周）
阶段 2：Git/GitHub + Shell 规范化 + 必要 Python（1～2 周）
阶段 3：Nginx + MySQL/MariaDB + Redis 服务运维深化（2 周）
阶段 4：Docker 与 Docker Compose（2～3 周）
阶段 5：Ansible 自动化部署（1～2 周）
阶段 6：Prometheus/Grafana、日志、告警与故障响应（2 周）
阶段 7：云服务器、安全组、域名、HTTPS、备份恢复（2 周）
阶段 8：基础 CI/CD（1～2 周）
阶段 9：综合项目、项目文档、简历和面试（2～3 周）
```

路线原则：

```text
前面的知识不从零重讲，通过实际命令和故障题复习。
每个阶段必须留下脚本、配置、日志、验证结果或故障报告。
Git/GitHub 提前，用于持续保存项目证据。
Docker 在掌握本地服务后学习；云服务器在 Docker 和监控后进行真实部署。
Kubernetes、Kafka、ELK、Terraform、微服务和高可用集群暂不作为当前主线。
```
4. 进入 Redis 系统运维。
```

## 12. 2026-07-09 MySQL 用户权限和安全最新进度

MySQL 用户权限和安全加固已经完成第一阶段，不要从安装、备份或授权重新讲。已经验证业务访问、系统表拒绝、REVOKE 撤权和权限恢复；下一步是 MySQL 常见故障排查。

已经完成：

```text
查看 mysql.user 中的 User + Host。
解释 root@127.0.0.1、root@::1、root@centos100、root@localhost。
解释 localhost、127.0.0.1、::1、centos100 在 MySQL Host 字段中的含义。
查看 root@localhost 的权限。
查看匿名用户。
查看匿名用户的 USAGE 权限。
删除匿名用户，并验证匿名用户已不存在。
创建普通业务用户 ops_user@localhost。
验证 ops_user@localhost 已存在。
查看 ops_user 初始权限，确认只有 USAGE。
使用 ops_user 登录，执行 SHOW DATABASES，只能看到 information_schema 和 test。
给 ops_user@localhost 授予 ops_demo.* 上的 SELECT、INSERT、UPDATE、DELETE 权限。
用 SHOW GRANTS 验证授权成功。
```

重要安全说明：

```text
练习过程中设置过 ops_user 的练习密码，但交接文件不记录明文密码。
SHOW GRANTS 输出过密码哈希，但交接文件不记录哈希。
后续如果需要登录 ops_user，由用户自己输入练习密码。
```

关键理解：

```text
MySQL 用户必须看完整形式：'User'@'Host'。
User 决定“谁”，Host 决定“从哪里来”。
localhost 通常是本机 socket。
127.0.0.1 是 IPv4 本机 TCP。
::1 是 IPv6 本机。
centos100 是当前 Linux 主机名。
USAGE 表示账号存在，但没有实际库表读写权限。
root@localhost 拥有 ALL PRIVILEGES ON *.*，是本机超级管理员。
业务程序不应该用 root 连接数据库，应该创建普通业务用户并授予最小权限。
```

已经执行过的关键命令：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
mysql -uroot -e "SHOW GRANTS FOR 'root'@'localhost';"
mysql -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='';"
mysql -uroot -e "SHOW GRANTS FOR ''@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR ''@'centos100';"
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='';"
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='ops_user';"
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
mysql -uops_user -p -e "SHOW DATABASES;"
mysql -uroot -e "GRANT SELECT,INSERT,UPDATE,DELETE ON ops_demo.* TO 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

注意：

```text
创建 ops_user 的命令里包含练习密码，不写入交接文件。
删除匿名用户的 DROP USER 命令不必重复执行；当前验证结果已经显示匿名用户不存在。
```

当前停点：

```text
ops_user 已成功查询 ops_demo.servers。
ops_user 查询 mysql.user 时被 ERROR 1142 拒绝。
已完成 SHOW GRANTS、REVOKE DELETE、实际撤权验证和 DELETE 权限恢复。
最终权限为 SELECT、INSERT、UPDATE、DELETE ON ops_demo.*。
下一步进入 MySQL 常见故障排查。
```

## 13. 2026-07-11 MySQL 权限验证与撤权练习

已经完成：

```text
使用 ops_user 查询 ops_demo.servers，成功读取业务数据。
使用 ops_user 查询 mysql.user，收到 ERROR 1142，确认不能读取系统用户表。
使用 SHOW GRANTS 查看当前用户权限。
使用 REVOKE 临时撤销 DELETE 权限。
实际执行安全的 DELETE 测试，收到 ERROR 1142，确认撤权生效。
重新授予 DELETE 权限，并用 SHOW GRANTS 确认恢复成功。
```

最终权限状态：

```text
ops_user@localhost 对 ops_demo.* 拥有 SELECT、INSERT、UPDATE、DELETE。
ops_user 无权读取 mysql.user。
```

关键理解：

```text
MySQL 权限配置既要验证“应该做的能做”，也要验证“不应该做的做不了”。
GRANT 使用 TO，REVOKE 使用 FROM。
GRANT/REVOKE 会立即生效，不需要重启 MariaDB，也不需要额外执行 FLUSH PRIVILEGES。
SHOW GRANTS 看配置，实际执行 SQL 验证真实效果。
```

下一步：

```text
MySQL 常见故障排查小练习，然后完成 MySQL 第一阶段总结。
```

## 14. 2026-07-11 项目 Git 仓库初始化

```text
分支：main
本地作者：陈伟钜 <cwj@localhost>
第一次提交：35ec417 初始化运维学习项目
提交文件数：13
提交完成状态：nothing to commit, working tree clean
```

截至 2026-08-03 复查，该仓库共有 3 次提交：

```text
35ec417  初始化运维学习项目     （13 个文件，新增 8521 行）
298ebbd  记录 Git 仓库初始化结果
3ab09d2  整理项目目录结构       （笔记移入 学习总结/，记录移入 项目记录/，新增 README.md）
```

当前 `git ls-files` 跟踪 14 个文件，无远程仓库，无 tag。

已配置：

```text
.gitignore：排除系统、编辑器、临时文件、环境变量和 Codex 本地隐藏运行目录。
.gitattributes：Markdown、配置和 Shell 脚本统一使用 LF 换行。
```

后续保存学习文件版本的基本流程：

```text
git status
git add 文件名
git commit -m "中文提交说明"
```

## 36. 2026-09-05 Linux 运维强化基础检查（最新状态）

本节优先于前文旧的“当前下一步”描述。用户已按“概念 -> 少量命令 -> 实际输出 -> 解释”完成以下复习：

### 进程与信号

```text
ps -eo ...、ps -p、pgrep -a、pstree -p 1
```

- 掌握 PID、PPID、STAT、CMD，以及 `--forest` 和 `pstree` 的父子树展示。
- 实际确认：`mysqld_safe(1299)` 的 PPID 是 1，`mysqld(1574)` 的 PPID 是 1299。
- `mysqld_safe` 是管理包装进程，`mysqld` 是真正数据库进程。
- 使用 `sleep` 验证 `SIGSTOP` -> `STAT=T`、`SIGCONT` -> `STAT=S`、`SIGTERM` -> 进程结束。
- 理解 `wait` 返回 143 的原因：`128 + SIGTERM(15)`。
- 已理解僵尸进程和孤儿进程，未专门制造僵尸进程。

### CPU、内存和磁盘

```text
nproc = 4
uptime = load average 0.00, 0.01, 0.05
vmstat = id 100%，si/so 0，wa 0
```

- 系统当前 CPU、内存、Swap 和 I/O 均正常。
- `df -h`：根分区 17G，已用约 5.5G，使用率 33%。
- `df -ih`：根分区 inode 使用率约 2%。
- `du -x --max-depth=1 -h /` 定位到 `/usr` 3.9G、`/var` 1.4G。
- `/var/cache/yum` 约 1.3G，主要是 `updates` 约 968M；没有执行清理。
- `stat`、`stat -c%s`、`stat -f` 已理解，包含文件大小、权限、inode、SELinux 上下文和文件系统块信息。

### SSH、firewalld 和 SELinux

- `sshd.service` 为 `active (running)` 且 `enabled`，监听 `0.0.0.0:22` 和 `[::]:22`。
- `sshd -T` 显示：`PermitRootLogin yes`、`PasswordAuthentication yes`、`PubkeyAuthentication yes`。
- SSH 密钥登录和关闭 root/密码登录的安全加固流程已解释，但按用户要求暂不执行。
- firewalld 为 `active (running)`，`ens33` 的活动区域为 `public`；`ssh`、`http` 服务已放行，`ports` 为空。
- SELinux 为 `Enforcing`、`targeted`；Nginx 配置和网站目录类型正确，`httpd_can_network_connect --> on`，`ausearch -m AVC -ts recent` 返回 `<no matches>`。

### 当前停点与下一步

Linux 运维强化基础检查已经完成。下一步可先做一次阶段复盘和能力检查，再制作 Linux 巡检脚本。SSH 密钥加固、复杂 firewalld 规则和 SELinux 策略分析不在本次实操中展开。

## 2026-09-07 Linux 巡检脚本进度

- 当前脚本：`/opt/scripts/system_inspection.sh`。
- 已完成：脚本骨架、日志函数、6 个服务检查、2 个 HTTP 检查。
- 正在添加：`check_memory` 和 `check_filesystem`。
- 两个资源检查函数已写入脚本并加入主流程。
- 2026-09-07 巡检结果：6 个服务全部 active，2 个 HTTP 均为 200，内存 available 44%，根分区 33%，inode 2%。
- 脚本输出 `inspection finished: warned=0 failed=0`，退出码为 `0`。
- Linux 巡检脚本首版已完成。
- 阶段总结笔记：`学习总结/ops_linux_inspection_script.md`。

## 2026-09-08 HTTP 状态码复习

- 已复习常见 `1xx`、`2xx`、`3xx`、`4xx`、`5xx` 状态码及其运维含义。
- 用户能正确区分 `401/403`、`400/404`、`500/503`、`502/504`。
- 用户已理解 `301/302` 重定向、`304` 缓存、`429` 限流。
- 综合题 `403/404/502/504` 回答 `B-C-D-A`，全部正确。
- 状态码复习完成；后续继续 Git/GitHub 和运维脚本版本管理。

## 2026-09-08 Git 分支基础复习

- 已验证工作区、暂存区、版本库和撤销操作：`git diff`、`git add`、`git diff --cached`、`git restore`、`git restore --staged`。
- 创建 `git-practice` 分支并提交 `da254fb 练习Git分支提交`。
- 切回 `main` 验证练习内容未立即出现在主线。
- 执行 `git merge git-practice`，结果为 `Fast-forward`，随后用 `git branch -d git-practice` 删除已合并分支。
- 当前分支为 `main`，下一步进入合并冲突演练。

