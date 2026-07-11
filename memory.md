# Codex 项目记忆

语言：中文。

范围：本文件只属于当前 Linux 运维与云运维学习项目。

## 稳定背景

- 用户是本科生，正在从零学习 Linux 运维与云运维，目标是明年具备寻找运维实习的能力。
- 默认使用中文教学。文件正文使用中文；命令、路径、配置项、SQL、日志和必要技术术语保留原样，并配中文解释。
- 学习目标不是单纯看完教程，而是能够安装、配置、维护服务，查看状态、端口和日志，并排查常见故障。
- 视频只作为补充，主线采用系统知识、实际操作、故障演练和阶段复盘。
- 不要过早堆复杂项目。每个新模块都要与已经学过的 Linux、网络、Shell、crontab、Nginx、systemd、firewalld、SELinux 和日志知识串联。

## 教学方法

- 固定节奏：概念 → 命令 → 用户执行 → 解释输出 → 总结 → 下一步。
- 每次优先给 1～3 条命令，避免一次堆太多内容。
- 每条命令解释用途、语法和参数。
- 用户问“什么意思”时，先暂停进度并解释清楚。
- 用户发回命令输出后，必须根据真实结果判断状态，不能假设执行成功。
- 每节课开头说明：本节位置、与前面知识的关系、真实运维场景、今天目标。
- 用户经常回复“好的”表示继续下一步。
- 用户喜欢“一句话记住”、判断题式排障和结合当前虚拟机环境的说明。

## 模块覆盖要求

每个主要模块都应系统覆盖：

```text
知识地图
核心概念
常用命令和参数
配置文件
服务管理
端口和网络
日志
安全
常见故障
排查流程
实战练习
复习总结
简历和面试表达
```

## 学习路线

```text
Linux 基础
→ 网络基础
→ Shell
→ crontab
→ Nginx
→ MySQL/MariaDB
→ Redis
→ 月度综合练习
→ 云服务器真实部署
→ Docker 与 Docker Compose
→ 监控、日志和告警
→ 简单 CI/CD
→ 项目文档、简历、面试与实习准备
```

## 当前虚拟机环境

```text
虚拟化软件：VMware
系统：CentOS Linux 7
普通用户：atguigu
主机名：centos100
主网卡：ens33
Linux 地址：192.168.6.100/24
回环地址：127.0.0.1
VMware NAT 网关和 DNS：192.168.6.2
Windows VMnet8：192.168.6.1/24
```

主要端口：

```text
22/tcp：SSH
80/tcp：Nginx
8080/tcp：backend-demo 后端服务
3306/tcp：MariaDB/MySQL
6379/tcp：后续 Redis
```

## 已完成：Linux 与网络基础第一阶段

- 已完成尚硅谷 Linux 零基础课程 77 集。
- 已学习 IP、子网、网关、DNS、TCP、UDP、ICMP、端口和 VMware NAT。
- 已使用 `ip addr`、`ip route`、`ip route get`、`ping`、`nslookup`、`dig`、`ss -lntp`、`curl` 和 `firewall-cmd`。
- 已理解：IP 找机器，端口找服务；同网段直接通信，不同网段通过网关；域名访问依赖 DNS。
- 当前排障顺序：IP → 网关 → DNS → 端口 → 防火墙 → 服务 → 日志。

## 已完成：Shell 与 crontab 第一阶段

- 已围绕 `/opt/scripts/check_nginx.sh` 学习变量、引号、条件判断、文件测试、退出状态、命令替换、数值比较、函数和重定向。
- 健康检查脚本可以检查 Nginx 服务和网站 HTTP 状态，失败时尝试恢复，并写入 `/var/log/nginx_check.log`。
- 已学习 `bash -n`、`systemctl is-active --quiet`、`curl -o /dev/null -s -w "%{http_code}"` 和日志轮转逻辑。
- 已学习普通用户与 root 的 crontab、常用时间表达式、cron 日志和定时任务排查。

## 已完成：Nginx 第一阶段

- 已安装并启动 Nginx，开放 80 端口，部署静态网站 `/var/www/ops-site`。
- 已处理 403、404 和配置语法错误。
- 已通过 `chcon -R -t httpd_sys_content_t /var/www/ops-site` 处理静态文件的 SELinux 类型。
- 已创建 `/opt/backend-demo` 和 `backend-demo.service`，由 systemd 管理 Python 8080 后端。
- Nginx 已通过 `proxy_pass http://127.0.0.1:8080;` 反向代理后端。
- 已通过 `setsebool -P httpd_can_network_connect on` 允许 Nginx 连接后端。
- 已模拟后端停止并排查 `502 Bad Gateway`。
- 已学习 location 匹配、配置继承、`proxy_set_header`、access.log、error.log、GET、HEAD 和 403/404/502/504 排查。

## MySQL/MariaDB 当前环境

```text
数据库：MariaDB 5.5.68
服务名：mariadb
进程名：mysqld
客户端命令：mysql
端口：3306/tcp
数据目录：/var/lib/mysql/
日志：/var/log/mariadb/mariadb.log
业务库：ops_demo
业务表：servers
恢复练习库：ops_demo_restore
业务用户：ops_user@localhost
```

`servers` 表当前关键数据：

```text
id=1
hostname=centos100
ip=192.168.6.100
role=all-in-one
```

## 已完成：MySQL/MariaDB 基础运维

- 已完成 MariaDB 安装、启动、状态检查、3306 端口检查和开机自启动。
- 已查看配置文件、数据目录、socket 和 MariaDB 日志。
- 已理解 `User + Host`、`USER()` 和 `CURRENT_USER()`。
- 已创建 `ops_demo`、`servers` 表，并练习 INSERT、SELECT、UPDATE 和 DELETE。
- 曾遇到 `ERROR 1046: No database selected`，通过在 mysql 命令中指定 `ops_demo` 解决。
- 已完成 `mysqldump` 手动备份、恢复到新库、模拟误删和再次恢复。
- 已创建 `/home/atguigu/backup_ops_demo.sh`，具备时间戳备份、执行状态判断和日志记录。
- 普通用户 crontab 已设置每天凌晨 3 点执行备份脚本。
- 备份脚本只在备份成功后清理超过 7 天的 `ops_demo_*.sql`。

## 2026-07-11 MySQL 权限验证与撤权练习

- 已删除匿名数据库用户。
- 已创建 `ops_user@localhost`。
- 已授予 `ops_user` 对 `ops_demo.*` 的 SELECT、INSERT、UPDATE、DELETE 权限。
- 已用 `ops_user` 查询 `ops_demo.servers`，成功读到业务数据，证明 SELECT 权限实际生效。
- 已用 `ops_user` 查询 `mysql.user`，收到 `ERROR 1142 (42000): SELECT command denied`，证明业务用户不能读取系统权限表。
- 已分别以 root 和 `ops_user` 使用 `SHOW GRANTS` 核对权限。
- 已使用 `REVOKE DELETE ON ops_demo.* FROM 'ops_user'@'localhost'` 临时撤销 DELETE。
- 已使用不会匹配现有数据的 DELETE 语句验证撤权，收到 `ERROR 1142`，现有数据没有被修改。
- 已重新授予 DELETE，并用 `SHOW GRANTS` 确认最终恢复 SELECT、INSERT、UPDATE、DELETE。
- 不记录练习密码或密码哈希。

## 当前准确进度

```text
Linux 基础第一阶段：完成
网络基础第一阶段：完成
Shell 第一阶段：完成
crontab 第一阶段：完成
Nginx 第一阶段：完成
MySQL 安装、基础 SQL、备份恢复、脚本、定时备份、保留策略：完成
MySQL 用户权限、最小权限、GRANT、REVOKE 验证：完成
```

## 下一步

```text
1. 建立 MariaDB 正常状态基线：服务、3306 端口、SQL 查询。
2. 进行 MySQL 常见故障排查小练习。
3. 完成 MySQL 第一阶段总结。
4. 进入 Redis 系统运维。
5. 完成 Shell + Nginx + MySQL + Redis 月度综合练习。
```

## 2026-07-11 Git 仓库初始化

- 当前学习项目目录已执行 `git init -b main`，成功初始化为本地 Git 仓库。
- 当前分支是 `main`，尚未创建第一次提交。
- 已创建 `.gitignore`，用于排除 Windows、编辑器、临时文件、本地环境变量以及 Codex 本地隐藏运行目录。
- 已创建 `.gitattributes`，统一 Markdown、配置文件和 Shell 脚本使用 Linux 的 LF 换行格式。
- 已执行 `git add .` 和 `git add --renormalize .`，当前 13 个项目文件均已进入暂存区。
- 当前仓库已配置本地作者身份：`陈伟钜 <cwj@localhost>`，只作用于本仓库，不使用真实邮箱。
- 下一步：创建第一次提交，然后用 `git status` 验证工作区干净。

## 项目记录文件分工

```text
memory.md
  → 长期项目背景、稳定偏好、准确进度和下一步。

ops_handoff.md
  → 新线程或其他模型接手时的交接文件。

ops_command_history.md
  → 用户实际执行过的命令、关键输出和结论。

ops_模块名.md
  → 各模块的系统复习笔记。
```

更新这些文件时，不保存完整聊天记录，不记录密码、密码哈希、密钥、令牌或无关个人信息。
