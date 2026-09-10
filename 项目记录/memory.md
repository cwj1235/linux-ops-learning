# Codex 项目记忆

语言：中文。

范围：本文件只属于当前 Linux 运维与云运维学习项目。

归档位置：`项目记录/memory.md`。

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
阶段 0：已学内容复习与能力体检
→ 阶段 1：Linux 运维强化
→ 阶段 2：Git/GitHub 与运维脚本（Shell + 必要 Python）
→ 阶段 3：Nginx、MySQL/MariaDB、Redis 服务运维
→ 阶段 4：Docker 与 Docker Compose
→ 阶段 5：Ansible 自动化部署
→ 阶段 6：监控、日志、告警与故障响应
→ 阶段 7：云服务器、安全组、域名、HTTPS 和备份
→ 阶段 8：基础 CI/CD
→ 阶段 9：综合项目、文档、简历和面试
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
旧的“MySQL 故障排查 -> Redis”顺序暂停直接推进。

新的主线：
1. 先评估现有运维学习方向是否符合运维实习目标。
2. 对 Linux、网络、Shell、crontab、Nginx、MySQL 做一轮实操复习和能力体检。
3. 根据体检结果补缺，不按课程章节机械重学。
4. 再安排 Redis、Git/GitHub、Docker/Compose、Ansible、监控、云服务器和综合项目。
5. 最终形成可用于简历、面试和实习投递的项目证据。
```

## 2026-08-26 路线重新评估

- 用户要求重新判断当前 Linux/云运维学习方向是否适合未来寻找运维实习，并修正不合理之处。
- 用户要求先复习前面已经学过的内容，再继续新模块。
- 复习方式继续遵守：概念 -> 少量命令 -> 用户执行 -> 根据真实输出判断 -> 故障题 -> 总结。
- 复习不是从零重讲，而是通过状态检查、命令默写、真实故障排查和小任务确认是否真正掌握。
- 当前项目上下文只能读取本目录的 `项目记录/` 与 `学习总结/`，不得混入其他项目目录的记忆。

### 已确定的路线调整

- 现有方向总体正确，但原路线缺少 Git/GitHub、Python 运维自动化、Docker/Compose、Ansible、监控告警、云服务器安全和 CI/CD，因此不能只按“MySQL -> Redis”继续。
- 前面 Linux、网络、Shell、crontab、Nginx、MySQL 不从零重讲；改为“知识回顾 + 命令默写 + 状态验证 + 故障演练 + 小产物”。
- Git/GitHub 提前到中前期，用来保存每个阶段的脚本、配置、故障报告和 README，形成可展示证据。
- Docker 放在本地服务基础和 Git 之后，先用 Docker Compose 串起 Nginx、后端、MySQL、Redis，再迁移到云服务器。
- Kubernetes、Kafka、ELK、Terraform、微服务、高可用集群和复杂云原生内容暂不作为主线，避免超过实习阶段的学习承载能力。
- 推荐总周期为 16～20 周，每周约 8～10 小时；可压缩到 12 周，但必须减少扩展内容，不能跳过复习、故障演练和综合项目。

### 新路线阶段目标

```text
阶段 0（2 周）：复习体检
Linux/网络 -> Shell/crontab -> Nginx/systemd -> MySQL。
产物：基础命令清单、故障排查记录、能力缺口表。

阶段 1（2～3 周）：Linux 运维强化
进程、磁盘、权限、SSH、systemd、journalctl、firewalld、SELinux、资源检查。
产物：Linux 巡检脚本和故障排查手册。

阶段 2（1～2 周）：Git/GitHub 与自动化脚本
分支、提交、远程仓库、README、Issue；Shell 规范化，补必要 Python（subprocess、requests、argparse、logging、YAML）。
产物：ops-toolkit 运维脚本仓库。

阶段 3（2 周）：服务运维深化
Nginx 配置和日志、MySQL 连接/权限/备份/恢复/锁与慢查询基础、Redis 配置/持久化/内存和故障排查。
产物：Nginx + MySQL + Redis 服务运行手册。

阶段 4（2～3 周）：Docker/Compose
镜像、容器、网络、卷、日志、健康检查、重启策略和 Compose 多服务编排。
产物：可一键启动的 Web 服务栈。

阶段 5（1～2 周）：Ansible
inventory、playbook、变量、模板、handlers、幂等性和多机部署思路。
产物：一键部署 Nginx/后端/基础配置的 playbook。

阶段 6（2 周）：监控、日志和告警
先掌握指标/日志/告警概念，再用 node_exporter、Prometheus、Grafana 做主机和服务监控，结合故障演练。
产物：监控面板、告警规则和一次故障复盘。

阶段 7（2 周）：云服务器实战
公网/私网 IP、安全组、SSH 密钥、最小权限、域名 DNS、Nginx HTTPS、备份和恢复。
产物：公网可访问但已做基本加固的部署记录。

阶段 8（1～2 周）：基础 CI/CD
GitHub Actions 或同类流水线，实现测试、构建、镜像或发布、部署和回滚说明。
产物：一个可解释的 CI/CD pipeline。

阶段 9（2～3 周）：综合项目与求职
把 Nginx、后端、MySQL、Redis、Docker、监控、备份和部署文档串起来，整理简历项目描述、面试题和演示脚本。
产物：项目 README、架构图、运行手册、故障报告、简历条目和面试问答。
```

## 2026-07-11 Git 仓库初始化

- 当前学习项目目录已执行 `git init -b main`，成功初始化为本地 Git 仓库。
- 当前分支是 `main`，尚未创建第一次提交。
- 已创建 `.gitignore`，用于排除 Windows、编辑器、临时文件、本地环境变量以及 Codex 本地隐藏运行目录。
- 已创建 `.gitattributes`，统一 Markdown、配置文件和 Shell 脚本使用 Linux 的 LF 换行格式。
- 已执行 `git add .` 和 `git add --renormalize .`，当前 13 个项目文件均已进入暂存区。
- 当前仓库已配置本地作者身份：`陈伟钜 <cwj@localhost>`，只作用于本仓库，不使用真实邮箱。
- 已创建第一次提交：`35ec417 初始化运维学习项目`，共提交 13 个文件。
- 已用 `git status` 验证：当前位于 `main` 分支，提交完成时工作区为 `working tree clean`。
- Git 仓库初始化任务已经完成；后续学习笔记发生变化时，使用 `git status → git add → git commit` 保存新版本。

## 2026-08-03 Git 提交记录复查

- 当前仓库共有 3 次提交，均为 2026-07-11 创建：

```text
35ec417  初始化运维学习项目     （13 个文件，新增 8521 行）
298ebbd  记录 Git 仓库初始化结果
3ab09d2  整理项目目录结构       （笔记移入 学习总结/，记录移入 项目记录/，新增 README.md 和中文归档结构）
```

- 当前分支 `main`，工作区 `working tree clean`。
- `git ls-files` 共跟踪 14 个文件：README、AGENTS、.gitignore、.gitattributes、学习总结 6 篇、项目记录 4 个。
- 无远程仓库、无 tag、未启用任何 Git 钩子。

## 2026-07-11 项目文件归档

- 根目录只保留 `README.md`、`AGENTS.md`、`.gitignore` 和 `.gitattributes` 等项目入口与 Git 规则文件。
- 六份模块笔记已统一移动到 `学习总结/`。
- `memory.md`、`ops_handoff.md`、`ops_command_history.md` 和 `config.toml` 已统一移动到 `项目记录/`。
- `AGENTS.md` 已改为读取和维护 `项目记录/memory.md`，并同步更新交接、命令履历和模块笔记路径。
- 已创建中文 `README.md`，提供目录结构、文件职责、阅读顺序、当前进度和 Git 使用方法。
- 两个归档目录都位于项目可写工作区内，文件可以正常读取、修改、移动和通过 Git 管理。

## 项目记录文件分工

```text
项目记录/memory.md
  → 长期项目背景、稳定偏好、准确进度和下一步。

项目记录/ops_handoff.md
  → 新线程或其他模型接手时的交接文件。

项目记录/ops_command_history.md
  → 用户实际执行过的命令、关键输出和结论。

学习总结/ops_模块名.md
  → 各模块的系统复习笔记。
```

更新这些文件时，不保存完整聊天记录，不记录密码、密码哈希、密钥、令牌或无关个人信息。

## 2026-09-05 Linux 运维强化基础检查

- 完成进程、CPU、内存、磁盘、inode、SSH、firewalld 和 SELinux 的一轮实操复习。
- 进程方面：使用 `ps`、`pgrep`、`pstree` 查看 PID、PPID、STAT、父子关系和线程；验证了 `mysqld_safe(1299)` 是 `mysqld(1574)` 的父进程，二者都由 `mysql` 用户运行。
- 信号方面：用 `sleep` 实际验证 `SIGSTOP` 将状态变为 `T`，`SIGCONT` 恢复为 `S`，`SIGTERM` 结束进程；理解退出码 `143 = 128 + 15`。
- 已理解僵尸进程和孤儿进程：僵尸是子进程结束但父进程未回收，孤儿是父进程结束但子进程仍运行并被 PID 1 接管。
- 资源方面：`nproc` 显示 4 个逻辑 CPU；`uptime` 负载为 `0.00, 0.01, 0.05`；`vmstat` 显示 CPU 空闲、无 Swap 交换和 I/O 等待；根分区容量使用约 33%，inode 使用约 2%。
- 磁盘方面：`du` 定位到 `/var/cache/yum` 约 1.3G，其中 `updates` 约 968M；已理解 `df` 看文件系统、`du` 看目录、`stat` 看文件元数据、`stat -f` 看所在文件系统。
- SSH 方面：`sshd` 正常运行并监听 IPv4/IPv6 的 22 端口；生效配置为 `PermitRootLogin yes`、`PasswordAuthentication yes`、`PubkeyAuthentication yes`。密钥登录和安全加固只完成概念说明，尚未实操。
- firewalld 方面：服务运行中，`ens33` 使用 `public` 区域；`ssh` 和 `http` 服务已放行，8080 未明确对外放行；已区分运行配置和永久配置，确认默认区域为 `public`。
- SELinux 方面：状态为 `Enforcing`，策略为 `targeted`；Nginx 配置为 `httpd_config_t`，网站目录为 `httpd_sys_content_t`，`httpd_can_network_connect` 为 `on`，最近 AVC 查询无匹配。
- 当前阶段状态：Linux 运维强化的基础检查完成；后续可进入阶段复盘和 Linux 巡检脚本产物。SSH 密钥加固、更多 SELinux 策略和复杂防火墙规则留作后续安全专项。

## 2026-09-07 Linux 巡检脚本进度

- 会话“上次说到哪里”已定位并完整回顾。
- 当前脚本：`/opt/scripts/system_inspection.sh`。
- 已完成：脚本骨架、`log_message` 日志函数、6 个服务检查、2 个 HTTP 检查。
- 正在添加：`check_memory` 和 `check_filesystem`。
- 两个资源检查函数已写入脚本并加入主流程。
- 2026-09-07 实际巡检结果：6 个服务全部 active，Nginx 和后端 HTTP 均为 200，内存 available 为 44%，根分区使用率 33%，inode 使用率 2%。
- 脚本已输出 `inspection finished: warned=0 failed=0`，`echo $?` 返回 `0`。
- Linux 巡检脚本首版已完成。
- 阶段总结笔记已保存到 `学习总结/ops_linux_inspection_script.md`。

## 2026-09-08 HTTP 状态码复习

- 完成 `1xx` 到 `5xx` 常见 HTTP 状态码复习。
- 已正确区分：`401` 是未认证，`403` 是已识别但无权限；`400` 是请求格式或参数错误，`404` 是资源不存在。
- 已正确区分：`500` 是服务器内部程序错误，`503` 是服务暂时不可用；`502` 是代理无法取得有效后端响应，`504` 是等待后端超时。
- 已理解 `301` 永久重定向、`302` 临时重定向、`304` 使用缓存、`429` 请求过于频繁。
- 综合题 `403/404/502/504` 对应关系回答为 `B-C-D-A`，全部正确。
- 当前状态：常见 HTTP 状态码基础复习完成，下一步可继续 Git/GitHub 与运维脚本版本管理。

## 2026-09-08 Git 分支基础复习

- 在 PowerShell 项目仓库中验证了 `git status`、`git diff`、`git diff --cached`、`git show` 和 `git diff HEAD~1 HEAD`。
- 已理解工作区、暂存区、版本库，以及 `git restore` 和 `git restore --staged` 的区别。
- 创建并切换到 `git-practice`，在该分支提交 `da254fb`，再切回 `main` 验证分支隔离。
- 使用 `git merge git-practice` 将练习提交合并到 `main`，实际结果为 `Fast-forward`。
- 已使用 `git branch --merged` 和 `git branch -d git-practice` 清理已合并分支，当前仅保留 `main`。
- 下一步：演练两个分支修改同一内容时产生的合并冲突。

## 2026-09-08 Git 合并冲突复习

- 创建 `conflict-a` 和 `conflict-b`，让两个分支修改同一个文件的同一行，成功触发 `CONFLICT (content)`。
- 已查看 `<<<<<<< HEAD`、`=======`、`>>>>>>> conflict-b` 冲突标记，并手动保留“部署状态：维护中”。
- 使用 `git add` 标记冲突解决，提交合并结果 `28b57d6`。
- 使用 `git switch main` 和 `git branch -D conflict-a conflict-b` 清理临时分支，当前仅保留 `main`，工作区干净。
- Git 分支基础、Fast-forward 合并和冲突处理已完成；下一步学习 `.gitignore` 和远程仓库。

## 2026-09-09 GitHub 远程仓库

- 创建公开远程仓库 `linux-ops-learning`。
- 已配置远程别名 `origin`，地址为 `https://github.com/cwj1235/linux-ops-learning.git`。
- 已执行 `git push -u origin main`，本地 `main` 成功推送到远程 `origin/main`。
- `git branch -vv` 已显示 `[origin/main]`，说明本地分支已建立上游关联。
- 下一步：学习 `git pull`、远程更新同步和克隆仓库。

## 2026-09-09 Git clone 验证

- 直接执行 `git clone` 时曾因连接 GitHub 的 HTTPS 请求被重置而失败。
- Windows PowerShell 当前会话设置 `HTTP_PROXY` 和 `HTTPS_PROXY` 为 `http://127.0.0.1:7890` 后，`git clone --depth 1` 成功。
- 克隆目录为 `..\linux-ops-learning-clone-2`，其 `git status` 干净，并已配置正确的 `origin` 远程地址。
- 已理解 `Test-NetConnection` 的 TCP 连通不等于 Git HTTPS 请求一定成功，代理可以解决应用层连接问题。

## 2026-09-09 Git 远程协作同步

- 在第二个克隆目录修改 `README.md`，提交 `e499889`。
- 因远程已有主项目的新提交，第一次直接 push 被拒绝，提示 `fetch first`。
- 使用 `git pull --rebase origin main` 获取远程更新并重放本地提交，生成新提交 `71ead6e`。
- 第二个克隆目录 push 成功后，主项目执行 `git pull`，以 `Fast-forward` 更新到 `71ead6e`。
- 主项目最终显示与 `origin/main` 同步，工作区干净；已完成双目录协作同步演练。

## 2026-09-09 运维脚本纳入 Git

- 将 CentOS `/opt/scripts/system_inspection.sh` 复制到仓库 `scripts/system_inspection.sh`。
- 文件大小约 2580 字节，共 122 行，已被 Git 跟踪。
- 提交 `624b2f1 加入 Linux 系统巡检脚本` 已成功推送到 `origin/main`。
- 使用 `git ls-files` 和 `git log -- scripts/system_inspection.sh` 验证文件跟踪状态和提交历史。
- 下一步：学习脚本修改后的 diff、提交和部署同步流程。

## 2026-09-09 Git `.gitignore` 与跟踪清理补充

- 实际执行临时日志验证：`git status --short` 不显示 `git-ignore-demo.log`，`git check-ignore -v` 显示 `.gitignore` 第 16 行的 `*.log` 规则，随后删除测试文件并恢复 clean。
- 已讲解 `git rm --cached`：取消 Git 跟踪但保留本地文件，适用于文件已被跟踪后才加入 `.gitignore` 的情况。
- `git rm --cached` 本次只完成讲解，尚未实际执行；已明确区分 `git rm` 与 `git rm --cached`。

## 2026-09-09 运维脚本修改与部署验证

- 在仓库脚本中将开始日志改为 `inspection started: script=system_inspection`。
- 使用 `git diff --check` 检查空白问题，结果无输出；提交 `d6eb2be 标记巡检脚本开始日志` 并推送到 `origin/main`。
- 通过 `scp` 复制到 CentOS `/home/atguigu/system_inspection.sh`，使用 `bash -n` 检查语法，结果无输出。
- 部署到 `/opt/scripts/system_inspection.sh` 后执行成功：6 个服务 active，两个 HTTP 均为 200，内存 available 42%，根分区 33%，inode 2%，warned=0，failed=0。
- 使用 `grep` 验证新开始日志已写入 `/var/log/system_inspection.log`。

## 2026-09-10 Python 运维脚本起步

- CentOS 默认 `python` 为 Python 2.7.5，`python3` 为 Python 3.6.8；新脚本明确使用 `python3`，未修改系统默认 `python`。
- 创建 `/home/atguigu/system_info.py`，内容为 Python 3 shebang 和一条 `print`。
- 使用 `python` 和 `python3` 分别执行成功，退出码为 0；已理解显式指定解释器时由命令决定运行版本。
- 使用 `chmod +x` 后直接执行脚本成功，证明 shebang `#!/usr/bin/env python3` 生效。
- 下一步：学习 Python 使用 `subprocess` 执行系统命令。

## 2026-09-10 Python subprocess 初次验证

- 在 CentOS 使用 `python3 -c 'import subprocess; subprocess.run(["hostname"])'` 调用系统命令。
- 实际输出为 `centos100`，说明 Python 3 可以通过 `subprocess.run` 执行 Linux 命令。
- 下一步：学习捕获命令输出并读取退出码。

## 2026-09-10 Python subprocess 输出对象

- 使用 `stdout=subprocess.PIPE` 捕获 `hostname` 输出，得到 `output: centos100` 和 `returncode: 0`。
- 已理解 `result.stdout` 是命令输出，`strip()` 去除末尾换行，`result.returncode` 是退出码。
- 直接打印 `result` 会显示 `CompletedProcess` 对象，其中包含 `args`、`returncode` 和 `stdout`。
- 新增 Python 学习笔记：`学习总结/ops_python_basics.md`。
- 下一步：执行一个成功命令和一个失败命令，观察 Python 如何读取不同退出码。

## 2026-09-10 Python `subprocess.PIPE` 讲解

- 已解释 `stdout=subprocess.PIPE`：为子进程标准输出创建管道，使 Python 可以通过 `result.stdout` 读取和处理输出。
- 已区分未设置 `stdout` 时输出通常直接显示在终端，以及 `stderr=subprocess.PIPE` 用于捕获错误输出。
- 已说明 Python 的 `PIPE` 不等同于 Shell 的 `|`；本次只完成概念讲解，未单独执行新的 PIPE 实验。

## 2026-09-10 Python 文本输出与退出码

- 已讲解 `universal_newlines=True`：将捕获输出作为 `str`，未设置时通常得到 `bytes`；当前 Python 3.6.8 使用该写法而不是较新的 `text=True`。
- 实际执行 `false` 和 `true`：分别得到 `returncode: 1` 与 `returncode: 0`。
- 已建立 Python `result.returncode` 与 Shell `$?` 的对应关系。
- 下一步：把 `subprocess` 调用写入 `/home/atguigu/system_info.py`，形成可重复运行的脚本。

## 2026-09-10 Python system_info 脚本验证

- 已将 `subprocess.run(["hostname"])` 写入 `/home/atguigu/system_info.py`。
- 脚本直接执行成功，实际输出 `hostname: centos100` 和 `returncode: 0`。
- 说明 shebang、执行权限、标准输出捕获和退出码读取均正常。
- 下一步：解释脚本结构，再增加一项系统信息检查。

## 2026-09-10 Python uptime 检查

- 在 `system_info.py` 中增加 `subprocess.run(["uptime"])`。
- 实际输出显示系统已运行 3 小时 18 分、2 个登录用户，负载为 `0.01, 0.04, 0.05`。
- `uptime_returncode: 0`，说明命令执行成功。
- 下一步：解释 uptime 字段，并整理重复的 subprocess 代码。

## 2026-09-10 Python subprocess 函数复用

- 已将 `system_info.py` 中重复的 `subprocess.run` 调用整理为 `run_command()` 函数。
- `python3 -m py_compile /home/atguigu/system_info.py` 无输出，语法检查通过。
- 直接执行脚本成功：`hostname: centos100`、`hostname_returncode: 0`、`uptime` 正常输出、`uptime_returncode: 0`，脚本退出码为 `0`。
- 下一步：学习 `stderr=subprocess.PIPE`，捕获并处理失败命令的错误输出。
