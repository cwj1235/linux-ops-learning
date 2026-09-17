# Codex 项目记忆

语言：中文。

范围：本文件只属于当前 Linux 运维与云运维学习项目。

归档位置：`项目记录/memory.md`。

## 历史接续点（2026-09-15 Redis allkeys-lru 小节；最新进度见文件末尾）

- 2026-09-14 内存基线与运行时上限小节：调整前内存快照：整机 total=1980 MiB、used=936、free=247、buff/cache=796、available=866（约 44%），Swap 2047 MiB、used=0；Redis used_memory=812936 字节（793.88K）、RSS=6045696 字节（5.77M）、碎片率=7.44，maxmemory=0、策略 noeviction。 本次快照未见明显内存压力；小内存实例的高 RSS/used_memory 比率不单独判作泄漏或严重碎片。用户执行 `redis-cli -p 6379 CONFIG SET maxmemory 134217728` 返回 `OK`，随后 CONFIG GET 返回 `maxmemory` 与 `134217728`，确认正式实例运行时上限为 128 MiB。本次只修改 maxmemory，没有修改淘汰策略。 128 MiB 是学习用预算，不是生产通用值、预分配量或进程 RSS 硬上限。
- `/etc/redis.conf` 第 537 行已写入 `maxmemory 134217728`，修改前备份为 `/etc/redis.conf.before-maxmemory-20260914-165752`。2026-09-14 17:10:21 CST 正式 redis 服务重启后为 `active (running)`，主进程 PID 9261，ExecStop 为 `0/SUCCESS`，仍为 enabled；用户未重新 CONFIG SET，直接 CONFIG GET maxmemory 返回 `134217728`，128 MiB 上限的服务重启加载验收通过。 不再重复 CONFIG SET、文件编辑或服务重启；原运行值 0 和备份保留为回滚参考，未执行回滚、CONFIG REWRITE 或内核参数调整。
- 本轮重启后，用户执行 `redis-cli -p 6379 MGET practice:rdb-check practice:aof-check`，依次读回 `rdb-ok`、`aof-ok`；`redis-cli -p 6379 CONFIG GET maxmemory-policy` 返回 `noeviction`。结合此前 maxmemory 读回，正式实例当前为 128 MiB 上限、noeviction 策略。仅确认两个指定字符串键与策略值，未重读 Hash 或 AOF 加载日志，也未验证全部键完整性、整机重启或超限拒写。
- 2026-09-14 noeviction 隔离超限演练已完成：6381 端口先确认空闲；隔离实例目录 `/var/lib/redis-noeviction-20260914`，`maxmemory=1048576`、策略 noeviction、AOF 与自动保存关闭。写入 65536 字节 value 时，前 6 个 key 成功，第 7 个开始返回 OOM 拒写；已有键仍可读，DEL 后写入恢复。`GET practice:noeviction` 为 nil 是 key 名少了编号，不是读取失败。
- 查询时 `used_memory=923152 < maxmemory=1048576` 不推翻第 7 次 OOM：INFO 是事后值，不是写入瞬间峰值。旧版 Redis 3.2 的 `redis-cli` 收到服务端 OOM 时退出码可能仍为 0，不能用 `||` 依赖退出码判断业务失败。用户已执行 `SHUTDOWN NOSAVE`，6381 连接拒绝、6379 返回 PONG。随后只读检查 `/var/lib/redis-noeviction-20260914`：目录属主 `redis:redis`，仅剩 2745 字节 `redis.log`，无 RDB/AOF/pid 文件；`--save ""`、`--appendonly no` 和正常退出后的 pid 清理均符合预期。
- noeviction 临时目录最终清理已完成：`rm -i` 确认删除 `redis.log`，`rmdir` 删除空目录，`ls -ld` 返回“没有那个文件或目录”；6381 仍拒绝连接，6379 仍返回 PONG。不要重做该实验或再次清理该目录，不填满正式 `6379`，不重做已结束的 `6380` 回灌实验。
- 2026-09-15 allkeys-lru 小节已完成：6381 端口先确认空闲；隔离目录 `/var/lib/redis-allkeys-lru-20260915`，配置为 1 MiB maxmemory、allkeys-lru、AOF 与自动保存关闭。30 次 65536 字节 value 写入全部成功，`evicted_keys=24`，最终 `DBSIZE=6`，仅剩 `practice:allkeys-lru:25` 至 `practice:allkeys-lru:30`。`SHUTDOWN NOSAVE` 后 6381 拒绝连接、6379 返回 PONG；`rm -i` 删除日志、`rmdir` 删除目录并确认目录不存在。不要重做该实验或再次清理该目录。
- 2026-09-14 启动警告只读核验完成：用户只读实测 `net.core.somaxconn=128`、`vm.overcommit_memory=0`，THP 输出 `[always] madvise never`，当前生效选项为 `always`。三项与此前启动警告一致，但不能据此认定当前内存不足或已出现性能故障。 `sysctl` 与 `systemctl` 的区别已讲解。本轮未调整内核参数、配置开机持久化或重启服务。随后整机和 Redis 内存快照及 128 MiB 运行时上限也已验证，内核参数仍未修改。
- 2026-09-14 指定 RDB 回灌已收尾：恢复原理、启动方式和 `sudo -u redis` 已讲解；`6380` 的 GET/HGETALL 读回 `rdb-ok` 与 `ip=192.168.6.100`，随后 `SHUTDOWN NOSAVE`、`6380` 连接被拒绝和 `6379 PONG` 已验证。用户又核对临时目录仅有 158 字节的 RDB 副本和 2.8K 日志、原始备份仍为 158 字节；对两个临时文件分别确认 `rm -i` 删除，`rmdir` 后 ls 返回目录不存在，临时目录清理完成。原始备份和正式数据/AOF 不在删除范围。后续三项内核参数只读核验也已完成，尚未修改参数。本次按小节统一记录，助手未连接虚拟机，也未提交或推送。
- 已按本项目目录筛选并核对 18 条历史交互会话（不含当前任务），对应 40 份原始/恢复记录，包含归档会话；没有使用其他项目的记忆。早期章节保留为历史，不能将其中的“下一步”当成最新停点。
- 主线已经进入阶段 3“服务运维深化”的 Redis 入门，不是还在 Python，也不是准备首次安装 Redis。阶段 0、1 的基础复习与巡检产物已完成；Git/Python 基础脚本闭环已完成，但不代表所有进阶知识都已学完。
- 最新进度来自 2026-09-14 用户回传：AOF 配置查询、在线启用、AOF 文件生成、配置文件持久化、写入测试、重启后键读回及 `DB loaded from append only file` 启动日志均已验证；随后使用临时目录和端口 `6380` 实际加载指定 RDB 备份，读回 2 个键并在日志中看到 `DB loaded from disk`，本次按小节统一记录。三项启动警告的内核参数只读核验已完成，断电恢复和内存/性能调优仍未完成。AOF 练习键暂不清理；隔离 `6380` 已读回具体键值并验证关闭，临时副本、日志与目录也已清理并确认目录不存在；助手未代替用户运行虚拟机命令。
- Redis 已实际安装 `3.2.12-2.el7`，启动并设置开机自启；当时为 `active (running)` / `enabled`，监听 `127.0.0.1:6379`，`redis-cli ping` 返回 `PONG`。
- 已实际验证 String 的 `SET/GET/DEL`、`SET ... EX 30` 与 `TTL`、计数器 `INCR/INCRBY/DECR`，以及 Hash 的 `HSET/HGET/HGETALL/HDEL`。
- 用户分别用 `HGET` 读到 `ip=192.168.6.100`、`role=all-in-one`，并用 `HGETALL` 核对两个字段。误输入 `HDET` 收到未知命令错误，改为 `HDEL server:centos100 role` 后返回 `1`；最后 `HGETALL` 仅剩 `ip=192.168.6.100`，整个键未被删除。
- 键/字段检查已实测：`EXISTS server:centos100` 返回 `1`，`HEXISTS server:centos100 role` 返回 `0`；最新 `TYPE server:centos100` 返回 `hash`、`HLEN server:centos100` 返回 `1`。类型和字段数量与此前仅保留 `ip` 的结果一致；存在性检查的 `0` 不是命令失败，也不是 Shell 的 `$?` 退出码。
- List 基础小节已验证：`RPUSH practice:checks nginx mariadb` 返回 `2`，`LRANGE` 显示 `nginx → mariadb`；两次 `LPOP` 依次取出 `nginx`、`mariadb`，`LLEN` 分别返回 `1`、`0`，最后 `EXISTS practice:checks` 返回 `0`。已验证右端加入、左端取出的 FIFO 和取空后键自动消失；没有执行 `DEL`，只是名称数据练习，没有实际运行巡检。
- Set 基础小节已验证 `SADD/SMEMBERS/SCARD/SISMEMBER/SREM`、去重、成员判断和删除。`practice:services` 初始传入重复的 `nginx`，实际新增 2 个成员；最后删除 `mariadb` 返回 `1`，`SMEMBERS` 返回 `(empty list or set)`，`EXISTS` 返回 `0`，集合键已自动消失。最后检查用的是 `SMEMBERS`，没有回传取空后的 `SCARD` 结果，不能补记为 `SCARD=0`。
- ZSet 基础小节已验证 `ZADD/ZRANGE/ZSCORE/ZCARD/ZREVRANGE/ZREM`。`practice:priority` 首次新增三个成员；把已有 `nginx` 的分数从 `20` 改成 `5` 时，`ZADD` 返回 `0`，`ZSCORE` 返回 `"5"`、`ZCARD` 仍为 `3`。升序为 `nginx(5) → mariadb(10) → redis(30)`，倒序相反，确认更新分数不会新增成员，但会改变排序。
- ZSet 收尾已实测：`ZREM practice:priority nginx mariadb redis` 返回 `3`，随后 `ZCARD` 返回 `0`、`EXISTS` 返回 `0`；键随全部成员删除而自动消失。已结束的 `practice:checks`、`practice:services`、`practice:priority` 三个练习键均已确认不存在；后续新建的 RDB 练习键不在此清理结论内。本节只操作名称和分数，没有修改真实服务优先级。
- 配置路径已核对：systemd 的 `ExecStart` 和运行中的 `INFO server` 均指向 `/etc/redis.conf`；`CONFIG GET` 的 `bind=127.0.0.1`、`port=6379`、`logfile=/var/log/redis/redis.log` 与文件第 61、84、163 行一致，只核对了这三项，不是审计全部配置。
- 重启前保护模式查询为 `yes`，`ss` 返回 `LISTEN 0 128 127.0.0.1:6379 *:*`，进程 `redis-server`、`pid=1207`、`fd=4`。这是重启前的回环监听证据，重启后没有重跑 ss；对端列 `*:*` 不表示监听所有网卡，队列值和文件描述符都不是客户端数。
- 配置与日志小节曾读取末尾 20 行，看到 9 月 13 日四轮 RDB 自动保存成功，最后结束于 `14:27:39.157`；该部分是历史日志核验，不是手动实验。该小节当时未修改配置、重启或开放端口；随后 RDB 小节已实际重启，相同日志重复粘贴不另记执行次数。
- RDB 运行配置已查明：`save="900 1 300 10 60 10000"`、`dir=/var/lib/redis`、`dbfilename=dump.rdb`。保存规则每组内部为“且”，三组之间为“或”。131 字节、14:27 是写入练习键前的文件基线；随后重启前核对源文件和备份均为 158 字节、`redis/redis`、修改时间 17:35。重启后未再次检查文件大小或内容一致性。
- 手动保存阶段：用户写入 `practice:rdb-check=rdb-ok`，误敲 GRT 后改为 GET；BGSAVE 启动后，INFO 的 in_progress=0、status=ok、changes=0 确认保存成功，当时 `rdb_last_save_time=1789292105`、`aof_enabled=0`。后续正常重启后另一次 GET 仍返回 `rdb-ok`，不要把两次读取混为一条证据；练习键没有清理，继续保留。
- 快照复制和重启前比对已验证：备份为 `/var/lib/redis/dump.rdb.before-restart-20260913-183303`，不带 `-s` 的 `sudo cmp` 无输出，紧随其后的 `echo $?` 返回 `0`，确认当时逐字节一致。早期只贴出的 `cmp -s ... && echo ... || echo ...` 不计为执行；该写法会混淆不同与报错，整行结束后的 `$?` 通常又变成 echo 的状态。
- 正常重启已验证：`systemctl restart redis` 后状态为 `active (running)`，启动时间 `2026-09-13 23:45:36 CST`，主进程 `3047`，ExecStop 为 `status=0/SUCCESS`，开机自启仍是 enabled。`vendor preset: disabled` 是默认策略，不抵消当前 enabled；重启后的 GET 返回 `rdb-ok`。
- 重启后 INFO 返回 `loading=0`、`rdb_changes_since_last_save=0`、`rdb_bgsave_in_progress=0`、`rdb_last_save_time=1789314336`、`rdb_last_bgsave_status=ok`、`aof_enabled=0`。两项 RDB 保存耗时为 `-1`，不能当作失败或新进程已执行过 BGSAVE；更新时间戳也不单独证明又做了一次后台保存。
- PID 3047 的启动日志显示 `DB loaded from disk: 0.000 seconds` 和接受 6379 连接的就绪信息；结合 AOF 关闭及重启后的 GET，确认正常启动加载 RDB 并读回练习数据。正常停止可能再次保存 RDB，因此不能声称已验证指定备份回灌、宕机/断电恢复或全部键的完整性；备份与练习键均未清理。
- 启动日志曾提示请求 backlog=511 而 somaxconn=128、overcommit_memory=0、THP 开启；本任务已只读核实内核值为 128、0、always。它们是连接排队、内存分配和延迟风险提示，不是启动或加载失败，也不是当前资源不足的直接证据；尚未修改参数，先检查整机和 Redis 内存，再评估整机级改动。
- cp/scp 区别及 `cp -anv`、时间文件名已讲解；cp 用于当前系统可直接访问的路径，scp 主要经 SSH 跨主机复制，两者参数不能照搬。真实 Redis 快照的 cp 已有结果，但此前用于讲解的示例文件复制及 scp 上传仍没有实操证据。
- AOF 小节已完成：`CONFIG GET appendonly` 返回 `no`、`appendfsync` 返回 `everysec`；旧版 Redis 3.2 的 `CONFIG GET appendfilename` 返回空，实际配置文件第 597 行确认 `appendfilename "appendonly.aof"`。启用前 AOF 文件不存在，根分区可用约 12G、使用率 34%，配置备份为 `/etc/redis.conf.before-aof-20260914-094538`。
- `CONFIG SET appendonly yes` 返回 `OK`，INFO 显示 `aof_enabled:1`、重写未进行、最近重写与写入状态均为 `ok`；AOF 文件生成，大小 139 字节。`CONFIG REWRITE` 因 Redis 用户无 `/etc` 目录写权限返回 `Permission denied`，随后管理员用 `sed` 将 `/etc/redis.conf` 第 593 行改为 `appendonly yes`，完成磁盘配置持久化。
- 写入 `practice:aof-check=aof-ok` 后重启，GET 返回 `aof-ok`；启动日志明确显示 `DB loaded from append only file`，确认 AOF 恢复。指定 RDB 恢复、具体键值与临时实例关闭均已验证；临时目录亦已清理；三项启动警告已完成只读核验；内存基线和 128 MiB 运行值也已验证；128 MiB 上限已写入配置文件并备份，服务重启后的加载验收也已通过；本轮重启后的两个练习字符串键与 noeviction 策略也已读回。当时“先检查 6381”的停点已经完成，后续 noeviction、allkeys-lru 超限演练和最终清理也已收尾；下一步优先做 `volatile-lru` 隔离实验，再评估内核参数调整、故障与巡检集成，最后进入 Docker/Compose；保留 CentOS 7 隔离实验环境，不暴露旧版 Redis 到公网。
- 本地此前漏记了 9 月 12 日晚的 Redis 课程；现已补入 `学习总结/ops_redis_basics.md`、命令履历、交接和首页。Python 归档后的记录提交 `22b3b24` 也有用户成功推送及 clean 输出，不需要重复完成旧步骤。

## 2026-09-13 项目文件全文复核

- 已全文阅读当前 23 份项目正文：11 篇学习笔记、4 份项目记录、2 份脚本、2 份巡检设计/计划文档及 4 份根目录文本；不含 `.git` 内部对象、Codex 本地运行目录和 `%SystemDrive%` 下的 Windows 缓存。
- 已修正 Python 阶段总结中“尚未提交”的过期描述；`d573677` 和后续补档 `22b3b24` 均有成功推送记录。后续修改以实时 `git status` 为准，不把历史 clean 当作当前状态。
- 全文复核当时的停点是 Redis Hash 的 `HGET`、`HDEL`，之后的用户实操进度以顶部为准。已讲解或已规划的内容不等于实操完成；该次复核仅修正文档，未连接虚拟机、未执行新实验，也未提交或推送。

## 稳定背景

- 用户是本科生，正在从零学习 Linux 运维与云运维，目标是明年具备寻找运维实习的能力。
- 默认使用中文教学。文件正文使用中文；命令、路径、配置项、SQL、日志和必要技术术语保留原样，并配中文解释。
- 学习目标不是单纯看完教程，而是能够安装、配置、维护服务，查看状态、端口和日志，并排查常见故障。
- 视频只作为补充，主线采用系统知识、实际操作、故障演练和阶段复盘。
- 不要过早堆复杂项目。每个新模块都要与已经学过的 Linux、网络、Shell、crontab、Nginx、systemd、firewalld、SELinux 和日志知识串联。

## 教学方法

- 固定节奏：概念 → 命令 → 用户执行 → 解释输出 → 总结 → 下一步。
- 每次优先给 1～3 条命令，避免一次堆太多内容。
- 响应偏好（2026-09-13 明确）：希望更快回复，但不缩短讲解或降低准确性。减少不必要的重复查阅，保留必要核对；依据实际输出区分已验证、待验证和推测，不编补缺失结果，也不为提速提前推进。
- 响应偏好（2026-09-17 明确）：给答复和教学内容前要先认真思考，不要不思考就快速给答案；先判断真实状态、说明判断依据，明确区分已验证、待验证和推测，宁可先把判断过程讲清楚，也不要给泛泛的即时回答。
- 每条命令解释用途、语法和参数。
- 用户问“什么意思”时，先暂停进度并解释清楚。
- 用户发回命令输出后，必须根据真实结果判断状态，不能假设执行成功。
- 记录频率（2026-09-13 用户调整）：不再每完成一条命令或收到一次输出就修改文件；完成一个小节的讲解、练习和验证后，再统一更新模块笔记、命令履历、交接和记忆。小节进行中先在会话里保留待汇总要点，只解释结果并继续教学。
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
6379/tcp：Redis（最近实测监听 127.0.0.1）
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

## 历史进度（2026-07-11）

```text
Linux 基础第一阶段：完成
网络基础第一阶段：完成
Shell 第一阶段：完成
crontab 第一阶段：完成
Nginx 第一阶段：完成
MySQL 安装、基础 SQL、备份恢复、脚本、定时备份、保留策略：完成
MySQL 用户权限、最小权限、GRANT、REVOKE 验证：完成
```

## 历史路线调整（2026-08-26，当前已推进）

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

## 2026-09-10 Python stderr 捕获验证

- 使用 `ls /not-exist` 验证 `stdout=subprocess.PIPE`、`stderr=subprocess.PIPE` 和 `universal_newlines=True`。
- 实际结果：`stdout` 为空字符串，`stderr` 为 `'ls: 无法访问/not-exist: 没有那个文件或目录\n'`，`returncode` 为 `2`。
- 已理解 `repr()` 的调试作用：能显示字符串引号、换行符和空字符串，便于判断真实内容。
- 下一步：把 `stderr` 捕获加入 `run_command()`，失败时输出错误信息。

## 2026-09-10 Python format 花括号讲解

- 已解释 `"{}: {}".format(name, output)` 中 `{}` 是占位符，`format()` 按顺序把参数填入花括号。
- 已用 `hostname: centos100` 和 `hostname_returncode: 0` 举例说明替换过程。

## 2026-09-10 Python run_command 捕获 stderr

- 已在 `run_command()` 中加入 `stderr=subprocess.PIPE`，并使用 `if result.stderr:` 判断是否输出错误信息。
- `python3 -m py_compile` 通过；脚本执行后 `hostname` 和 `uptime` 均正常，未出现 `stderr`，退出码为 `0`。
- 下一步：临时调用一个失败命令，验证 `stderr` 输出分支。

## 2026-09-10 Python 失败命令脚本验证

- `system_info.py` 实际执行 `ls /not-exist`，得到错误输出和 `ls_returncode: 2`。
- 随后的 `echo $?` 为 `0`，已理解子命令退出码与 Python 脚本自身退出码是两层不同结果。
- 当前脚本没有使用 `sys.exit()` 传递失败状态；下一步学习脚本整体退出码设计。

## 2026-09-10 Python 清理临时失败测试

- 删除 `run_command(["ls", "/not-exist"])` 后，`system_info.py` 恢复正常输出。
- `hostname`、`uptime` 的子命令退出码均为 `0`，脚本后的 `echo $?` 为 `0`。
- 下一步学习 `sys.exit()`，设计脚本整体成功或失败退出码。

## 2026-09-10 Python sys.exit 成功分支验证

- `system_info.py` 已加入 `sys.exit(1)` 和 `sys.exit(0)`。
- `python3 -m py_compile` 无输出；`hostname`、`uptime` 子命令及脚本自身退出码均为 `0`。
- 下一步临时制造一个子命令失败，验证脚本整体退出码是否为 `1`，然后恢复命令。

## 2026-09-11 Python sys.exit 失败分支验证

- 临时将 `uptime` 替换为 `false`，实际得到 `false_returncode: 1`。
- 脚本最后的 `echo $?` 为 `1`，证明 `sys.exit(1)` 已将失败状态传递给 Shell。
- 下一步恢复 `uptime` 并验证成功分支，避免测试命令残留。

## 2026-09-11 Python 恢复正式命令验证

- 已将 `false` 恢复为 `uptime`，并重新完成语法检查和脚本执行。
- `hostname_returncode`、`uptime_returncode` 和脚本自身退出码均为 `0`。
- Python subprocess 基础闭环完成：执行命令、捕获 stdout/stderr、读取 returncode、使用 `sys.exit()` 返回整体状态。
- 下一步总结当前脚本，再学习参数化或日志记录设计。

## 2026-09-11 Python sys.argv 参数实验

- 已执行 `python3 -c 'import sys; print(sys.argv)' hostname uptime`。
- 实际输出 `['-c', 'hostname', 'uptime']`，已理解 `sys.argv` 是命令行参数列表，用户参数从索引 `1` 开始。
- 下一步在 `.py` 文件中观察 `sys.argv[0]`，再把参数用于脚本逻辑。

## 2026-09-11 Python 文件参数验证

- 已创建并运行 `/home/atguigu/args_demo.py hostname uptime`。
- 实际确认 `sys.argv[0]` 是脚本路径，`sys.argv[1:]` 为 `['hostname', 'uptime']`。
- 下一步学习使用 `for` 循环逐个处理参数。

## 2026-09-11 Python for 循环参数验证

- `args_demo.py` 已通过 `for argument in sys.argv[1:]` 逐个输出命令行参数。
- 实际输入 `hostname uptime`，成功分别输出两个参数。
- 下一步将循环参数交给 `subprocess.run()` 执行。

## 2026-09-11 Python 参数执行命令验证

- `args_demo.py` 已使用 `[argument]` 将命令行参数交给 `subprocess.run()`。
- 实际执行 `hostname uptime`，两个命令均返回 `0`。
- 输出中标签与值之间少一个空格，仅是格式问题。
- 下一步传入 `false`，验证参数化脚本的失败命令结果。

## 2026-09-11 Python 参数失败命令验证

- `args_demo.py false` 实际得到 `false returncode:1`，证明参数化脚本取得了失败子命令的退出码。
- 用户在 `python3` 和 `echo $?` 之间执行了 `vim`，因此显示的 `0` 是 `vim` 的退出码。
- 下一步连续执行 Python 脚本与 `echo $?`，验证脚本自身退出码。

## 2026-09-11 Python 参数脚本整体退出码验证

- 连续执行 `args_demo.py false` 和 `echo $?`，实际得到子命令退出码 `1`、脚本退出码 `0`。
- 已理解参数脚本当前只打印结果，没有使用 `sys.exit()` 传递失败。
- 下一步增加失败标记和整体退出码逻辑。

## 2026-09-11 Python 参数脚本失败状态传递

- `args_demo.py` 已通过 `has_failure` 汇总命令结果，并使用 `sys.exit(1)` 返回失败。
- 实际执行 `false` 后，子命令退出码和脚本自身退出码均为 `1`。
- 下一步验证多个命令中部分失败时的执行和最终状态。

## 2026-09-11 Python 多命令结果汇总验证

- `args_demo.py false uptime` 实际执行时，`false` 返回 `1`，`uptime` 仍继续执行并返回 `0`。
- 最终脚本退出码为 `1`，证明任意命令失败都会使整体状态失败，同时不会中断后续检查。
- 下一步验证全部命令成功时整体退出码为 `0`。

## 2026-09-11 Python 全部成功参数验证

- 执行 `args_demo.py hostname uptime`，`hostname` 和 `uptime` 子命令均返回 `0`，输出正常。
- 本次尚未执行紧接的 `echo $?`，脚本自身退出码待确认。
- 下一步直接执行 `echo $?`，确认整体成功状态。

## 2026-09-11 Python 参数化脚本三种状态完成

- 补充执行 `echo $?` 得到 `0`，确认全部命令成功时脚本整体返回 `0`。
- 已验证全部成功、任意失败、部分失败后继续执行三种状态。
- `args_demo.py` 的基础参数化和退出码汇总逻辑完成。
- 下一步学习 `argparse`，增加规范的参数说明和帮助信息。

## 2026-09-11 Python argparse 代码讲解

- 已讲解 `ArgumentParser`、`description`、位置参数、`nargs="+"`、`help`、`parse_args()` 和 `args.commands` 的作用。
- 本次只完成概念和代码结构讲解，尚未实际验证新的 `argparse` 版本。
- 下一步执行 `args_demo.py --help`，观察帮助信息。

## 2026-09-11 Python argparse help 验证

- 实际执行 `python3 /home/atguigu/args_demo.py --help`，自动显示 usage、`commands` 参数和 `-h/--help`。
- 已确认 `--help` 只显示帮助并结束，不执行命令循环。
- 下一步测试不传命令时的 `nargs="+"` 参数校验。

## 2026-09-11 Python argparse 必填参数验证

- 不传命令运行 `args_demo.py` 时，`argparse` 提示 `commands` 必填。
- 实际 `echo $?` 为 `2`，已理解这是参数解析错误，不是子命令执行失败。
- 下一步验证合法参数的 `argparse` 正常执行路径。

## 2026-09-11 Python argparse 合法参数验证

- 实际执行 `args_demo.py hostname uptime`，两个子命令退出码均为 `0`。
- 脚本最后的 `echo $?` 为 `0`，合法参数路径验证成功。
- `argparse` 基础验证完成：帮助、参数缺失错误和正常执行。
- 下一步增加可选参数，例如详细输出开关或命令超时。

## 2026-09-11 Python argparse 未知选项验证

- 尝试使用未注册的 `--verbose`，`argparse` 报错 `unrecognized arguments`。
- 已理解选项必须先使用 `add_argument()` 定义。
- 下一步加入 `--verbose` 和 `action="store_true"`，验证可选开关。

## 2026-09-12 Python argparse verbose 验证

- `args_demo.py` 已加入 `--verbose` 和 `action="store_true"`。
- 实际执行 `--verbose hostname uptime` 时，在每个命令前输出 `executing:`，两个命令均成功。
- 已理解 verbose 只控制过程提示，不改变子命令结果。
- 下一步验证不带 `--verbose` 的普通输出。

## 2026-09-12 Python argparse 普通模式验证

- 不带 `--verbose` 执行 `args_demo.py hostname uptime`，不显示 `executing:`，但两个命令均返回 `0`。
- 脚本最后的 `echo $?` 为 `0`，普通模式验证成功。
- verbose 与普通模式对比完成；下一步学习 `subprocess.run()` 的 `timeout` 超时控制。

## 2026-09-12 Python subprocess timeout 验证

- `args_demo.py` 已加入 `timeout=3` 和 `TimeoutExpired` 异常处理。
- 实际执行 `hostname yes`，`hostname` 成功，`yes` 超时，脚本整体退出码为 `1`。
- 超时逻辑正确；提示输出的 `{}` 与 `yes` 分离，下一步修正为 `format()` 格式化写法。

## 2026-09-12 Python timeout 提示格式修正

- 超时提示已改为 `"{} timeout after 3 seconds".format(argument)`，实际显示 `yes timeout after 3 seconds`。
- 脚本仍返回 `1`，超时逻辑没有改变。
- `^[[A` 是终端方向键控制序列；最后一次编辑后仍需重新运行 `py_compile`。

## 2026-09-12 Python timeout 修改后完整验证

- 修改后的 `args_demo.py` 已重新通过 `python3 -m py_compile`。
- 实际执行 `hostname yes`：`hostname` 成功，`yes` 在 3 秒后超时，提示格式正确。
- 脚本整体退出码为 `1`，超时处理完成验证。
- 下一步恢复正常命令测试，并总结当前 Python 参数脚本。

## 2026-09-12 Python 参数脚本阶段完成

- 恢复正常命令后重新执行 `hostname uptime`，两个子命令及脚本整体退出码均为 `0`。
- 当前脚本已验证 `argparse`、帮助和参数校验、verbose、stdout/stderr 捕获、失败汇总、timeout 和 `sys.exit()`。
- 下一步整理 Python 阶段总结，再加入日志记录或纳入 Git。

## 2026-09-12 Python logging 基础验证

- 已实际执行 `logging.basicConfig()`，验证 `INFO`、`WARNING`、`ERROR` 三种级别。
- 已理解 `level=logging.INFO` 和 `format="%(levelname)s: %(message)s"` 的作用。
- 当前日志只显示在终端；下一步学习写入日志文件。

## 2026-09-12 Python logging 文件验证

- 使用 `filename="/home/atguigu/python_demo.log"` 实际写入日志。
- `cat` 查看确认日志包含时间、级别和消息。
- 文件日志验证完成；下一步将 logging 集成到 `args_demo.py`。

## 2026-09-12 Python args_demo logging 集成验证

- `args_demo.py` 已加入 logging，并记录 `command started`、`command succeeded`。
- 实际执行 `hostname uptime`，两个命令均成功，日志文件正确写入四条过程记录。
- 已区分终端结果输出与日志文件过程记录。
- 下一步验证失败和超时命令的 `ERROR` 日志。

## 2026-09-12 Python logging 失败与超时验证

- 实际执行 `false yes`：`false` 返回 `1`，`yes` 超时，脚本整体退出码为 `1`。
- 日志文件正确记录 `ERROR: command failed: false returncode=1` 和 `ERROR: command timeout: yes`。
- Python logging 集成的成功、失败、超时路径均已验证。
- 下一步总结 Python 阶段并纳入 Git。

## 2026-09-12 Python 运维脚本阶段完整总结

- 已完整记录 Python 3 运维脚本学习：版本和 shebang、`subprocess.run()`、`PIPE`、stdout/stderr、`universal_newlines=True`、`returncode`、函数封装、`sys.exit()`、`sys.argv`、`for`、`argparse`、`--verbose`、`timeout` 和 `logging`。
- `system_info.py` 已完成主机名、uptime、错误输出和整体退出码验证；`args_demo.py` 已完成多命令执行、失败汇总、参数校验、详细模式、超时和日志验证。
- 已验证退出码规则：正常为 `0`，命令失败或超时为 `1`，`argparse` 参数错误为 `2`。
- 当前 Python 脚本和日志在 CentOS 上，`args_demo.py` 已复制到 Windows Git 仓库的 `scripts/args_demo.py`；Python 笔记及记录存在未提交修改。
- `.log` 被 `.gitignore` 忽略，不直接纳入 Git；下一步复制 `args_demo.py` 到仓库 `scripts/`，检查后提交并推送。

## 2026-09-12 Python 脚本复制到仓库

- 已通过 `scp` 将 `/home/atguigu/args_demo.py` 复制为仓库文件 `scripts/args_demo.py`。
- 实际文件大小为 1532 字节，Git 状态显示为未跟踪文件。
- Python 学习笔记、命令履历、交接文件和记忆文件均有未提交修改。
- 日志文件仍只保留在 CentOS，因 `*.log` 忽略规则不复制进 Git。
- 下一步检查 `args_demo.py` 和四份记录的暂存差异，再提交推送。

## 2026-09-12 Python 阶段 Git 提交完成

- `scripts/args_demo.py`、Python 学习笔记和三份项目记录已完成暂存检查并提交。
- 提交号为 `d573677`，提交说明为“完成 Python 运维脚本阶段记录”，共 5 个文件、1732 行新增内容。
- 已成功推送到 `origin/main`，远程从 `144be20` 更新到 `d573677`。
- 最终工作区干净，本地 `main` 与 `origin/main` 同步。
- Python 脚本和完整学习记录已纳入 GitHub；日志文件因 `*.log` 规则仍不纳入版本库。

## 2026-09-15 Redis volatile-lru 小节完成

- 已在 `127.0.0.1:6381` 使用独立目录 `/var/lib/redis-volatile-lru-20260915` 完成 `volatile-lru` 隔离演练。
- 验证配置：`maxmemory=1048576`、`maxmemory-policy=volatile-lru`、`appendonly=no`、`save=""`。
- 先写入 3 个无 TTL key，再写入 30 个使用 `EX 86400` 的 key，每个 value 为 65536 字节；带 TTL key 全部写入成功。
- 结果：`evicted_keys=27`、`DBSIZE=6`，保留 3 个无 TTL key 和 `ttl:28`、`ttl:29`、`ttl:30`。
- 结论：`volatile-lru` 只淘汰带 TTL 的 key；无 TTL key 即使更旧也不会被淘汰。`TTL=-1` 表示 key 存在但没有过期时间，不是错误。
- `SHUTDOWN NOSAVE` 后 6381 已停止，6379 正常，临时目录已删除；本节不要重做。
- 下一步：依次评估 `net.core.somaxconn`、`vm.overcommit_memory`、THP，再整理 Redis 巡检手册，之后进入 Docker/Compose。

## 2026-09-15 Redis 内核参数调优完成

- 正式 6379 调整前为 `tcp-backlog=511`、`net.core.somaxconn=128`、`vm.overcommit_memory=0`、THP `[always]`。
- 已写入 `/etc/sysctl.d/99-redis.conf`：`net.core.somaxconn=1024`、`vm.overcommit_memory=1`；已创建 `/etc/tmpfiles.d/redis-disable-thp.conf` 持久化关闭 THP。
- 复核结果：`somaxconn=1024`、`vm.overcommit_memory=1`、THP 为 `always madvise [never]`。
- 重启 Redis 后 `PING=PONG`，监听队列 `Send-Q` 从 `128` 变为 `511`，证明 `tcp-backlog=511` 已真正生效。
- 本节已完成，不要重做。下一步整理 Redis 巡检手册，再衔接 Docker/Compose。

## 2026-09-15 Redis 巡检手册完成

- 正式 6379 巡检通过：`active`、`enabled`、监听 `127.0.0.1:6379`、`Send-Q=511`、`PING=PONG`、`DBSIZE=3`。
- 配置确认：128 MiB 上限、`noeviction`、AOF 开启、`appendfsync=everysec`、RDB 自动保存策略和数据目录均正常。
- 持久化确认：RDB/AOF 状态均为 `ok`，无后台任务执行；`dump.rdb` 与 `appendonly.aof` 均存在，`LASTSAVE` 为 `2026-09-15 15:49:46 CST`。
- 内存与日志确认：当前内存 793.88K、无淘汰、无拒绝连接，最近 24 小时 Redis 错误日志为空。
- 本节已完成，不要重做。下一步进入 Docker/Compose。

## 2026-09-15 Docker 安装与容器生命周期完成

- CentOS 7 上已通过阿里云 Docker CE 仓库安装 Docker `26.1.4`、containerd `1.6.33` 和 Compose `2.27.1`，服务已设置开机自启。
- Docker Hub 直连超时，已配置 `/etc/docker/daemon.json` 使用 `https://docker.m.daocloud.io`，`hello-world` 拉取和运行成功。
- 已完成 Alpine 容器的后台运行、状态检查、`docker exec`、停止、删除容器和删除镜像验证；练习容器和镜像已清理。
- 本节不要重做。下一步学习 Docker 数据卷、端口映射、Dockerfile，然后进入 Compose。

## 2026-09-15 Docker 数据卷验证完成

- 已创建并验证 `practice-volume`，宿主机路径为 `/var/lib/docker/volumes/practice-volume/_data`。
- 第一个临时 Alpine 容器写入 `/data/check.txt` 后自动删除，第二个新容器挂载同一卷后成功读出 `docker-volume-ok`。
- 结论：容器删除后数据卷数据仍存在；删除数据卷需使用 `docker volume rm`。
- `practice-volume` 和 `alpine:latest` 已清理。本节不要重做，下一步学习端口映射。

## 2026-09-15 Docker 端口映射验证完成

- 首次运行 `nginx:alpine` 时容器退出，日志为 `pwrite() "/run/nginx.pid" failed (1: Operation not permitted)`；该问题不是端口映射导致。
- CentOS 7 内核 `3.10` 环境下改用 `nginx:1.24-alpine` 后正常运行。
- 已验证 `0.0.0.0:18080->80/tcp`，`curl` 返回 `HTTP/1.1 200 OK`。
- 练习容器 `practice-nginx` 和 `nginx:1.24-alpine` 镜像已清理。本节不要重做，下一步学习 Dockerfile。

## 2026-09-15 Dockerfile 自定义镜像完成

- 已基于 `nginx:1.24-alpine` 编写 Dockerfile，通过 `COPY` 替换 Nginx 默认首页，通过 `CMD` 前台运行 Nginx。
- 构建命令必须带构建上下文：`sudo docker build -t practice-nginx-image:1.0 .`。
- 自定义镜像运行后，`curl http://127.0.0.1:18081` 成功返回 `Dockerfile build success`。
- 练习容器和镜像已删除，最终 `docker images` 为空；`~/dockerfile-practice` 源文件目录保留。
- 本节不要重做。下一步进入 Docker Compose。

## 2026-09-15 Docker Compose 编排完成

- 已用 `docker-compose.yml` 编排 `web` 和 `cache` 两个服务：Nginx 映射 `18082:80` 并挂载自定义首页，Redis 仅在 Compose 内部网络使用。
- `docker compose config`、`up -d`、`ps`、`exec`、`logs`、`down` 均已验证。
- Web 返回 `HTTP/1.1 200 OK` 和 `Docker Compose success`；Redis 返回 `PONG`，并成功写入、读回 `compose:practice`。
- 容器、默认网络和练习镜像均已清理，最终 `docker images` 为空；`~/compose-practice` 源文件目录保留。
- Docker/Compose 阶段 7 节全部完成，不要重做。下一步提交学习记录。

## 2026-09-16 Ansible 安装与 Inventory 完成

- 已在 CentOS 7 上通过 EPEL 安装 Ansible `2.9.27`，控制端 Python 为 `2.7.5`。
- `/root` 下执行 Ansible 会因目录权限报 `Permission denied: '.'`，切到 `/home/atguigu` 后本机 `ping` 成功。
- 已创建 `~/ansible-practice/inventory.ini`，定义 `[local]` 组和 `localhost ansible_connection=local`。
- Inventory 解析、`ansible local -i inventory.ini -m ping`、`setup` 发行版信息筛选均验证成功。
- 本节不要重做。下一步学习 Ansible Ad-hoc 命令。

## 2026-09-16 Ansible Ad-hoc 命令完成

- 已验证 `command`、`file`、`copy`、`stat` 模块。
- `file` 创建目录、`copy` 写入文件均验证了幂等性：第一次 `changed=true`，第二次 `changed=false`。
- 已读取 `hello.txt` 内容 `ansible adhoc ok`，并用 `stat` 确认文件属性。
- 已用 `file` 模块删除练习目录，并用 `stat` 确认 `exists=false`。
- 本节不要重做。下一步学习 Ansible Playbook 基础。

## 2026-09-16 Ansible Playbook 基础完成

- 已创建并执行 `~/ansible-practice/site.yml`，包含目录创建、文件写入、文件读取和 `debug` 输出。
- `--syntax-check` 通过；第一次执行 `ok=4 changed=2`，第二次执行 `ok=4 changed=0`，幂等性验证通过。
- `stat` 确认 `hello.txt` 存在且权限为 `0644`。
- 已删除 `playbook-demo` 目录并确认 `exists=false`。
- 本节不要重做。下一步学习 Ansible 变量和模板。

## 2026-09-16 Ansible 变量和模板完成

- 变量来源与优先级已验证：inventory 主机变量 / playbook `vars` / facts 与 `register` / 命令行 `-e`，优先级为 inventory/facts -> `vars` -> `-e`；未定义变量会让任务直接 `FAILED!`（`'app_port' is undefined`），不是空值。
- 已创建 `~/ansible-practice/templates/app.conf.j2` 和 `vars-template.yml`；`--syntax-check` 通过，第一次 `ok=4 changed=2`，第二次 `ok=4 changed=0`，`template` 幂等性通过，`cat` 读到渲染后的三行配置。
- 加 `-e "app_port=18091"` 后第一次 `ok=4 changed=1` 且 debug 显示 18091，第二次 `changed=0`，变量覆盖生效且重复执行不再变更。
- 已知边界：`--syntax-check` 不校验 Jinja2 模板内容；`debug: var=` 把换行显示成 `\n`；模板相对路径与 `-i` 都依赖当前目录，须先 `cd ~/ansible-practice`。
- `template-demo` 是练习产物待删除；`templates/` 目录和 `vars-template.yml` 保留。
- 本节不要重做。下一步学习 Ansible handlers。

## 2026-09-17 Ansible handlers 完成

- handler 机制已验证：任务 `changed` 且 `notify` 才入队；handler 在所有任务结束后执行；无变更时不出现 `RUNNING HANDLER`。三次结果：首次 `ok=4 changed=3`、无改动 `ok=3 changed=0`、`-e app_port=18092` 时 `ok=4 changed=2`。
- 排查到真实 bug：handler 用 `command` 模块做 `>>` 重定向时任务报 `changed` 却不生成文件。对照实验证明 `command` 不经过 shell、`>>` 只是普通参数；`shell` 模块才真正重定向（生成 12 字节 `redir-shell.txt`）。
- 修复命令 `sed -i 's/command:/shell:/' handlers-demo.yml`，复验通过：修复后 `handler.log` 出现 1 行，无改动再跑无 handler，`-e app_port=18091` 再触发后累计 2 行。
- 关键结论：`changed` 不证明副作用发生；判断 handler 是否执行看有没有 `RUNNING HANDLER` 段落；生产 handler 应使用 `systemd` 等模块而非 shell 重定向。
- 保留复用文件 `handlers-demo.yml`、`templates/app.conf.j2`、`handlers-demo/`；练习残留 `redir-shell.txt` 待清理。
- 本节不要重做。下一步：真实服务重启（Nginx reload）。

## 2026-09-17 Ansible handler 对接真实服务（Nginx reload）完成

- 已创建 `templates/ops-handler-demo.conf.j2` 和 `handlers-nginx.yml`：`become: true`，template 渲染到 `/etc/nginx/conf.d/ops-handler-demo.conf` 并 `notify: reload nginx`，handler 为 `systemd: name=nginx state=reloaded`；另有 `command: /usr/sbin/nginx -t` 配 `changed_when: false` 用于校验。执行需带 `-K`。
- 首次执行 `ok=4 changed=2`、`RUNNING HANDLER` 正常出现、`nginx -t` 通过，但服务不生效（18099 无监听、curl 拒绝连接、worker PID 未变）。这是本阶段第三次证明「`changed` 不等于副作用发生」。
- 根因：SELinux 未放行 18099。error.log 有 `bind() to 127.0.0.1:18099 failed (13: Permission denied)`；`http_port_t` 白名单为 `80, 81, 443, 488, 8008, 8009, 8443, 9000`；audit.log 有 `avc: denied { name_bind } ... tcontext=unreserved_port_t ... tclass=tcp_socket permissive=0`。排查顺序：服务错误日志 → 内核 AVC 记录 → 策略清单。
- 对照实验 `-e "nginx_demo_port=8008"` 立即可用，master 仍 1314、worker 换为 8809/8810/8812/8813，证明唯一变量是端口，且走的是 reload 热加载。
- 修复：`sudo semanage port -a -t http_port_t -p tcp 18099` 后重跑，18099 正常监听、curl 返回 `handler demo ok, version=1`，master 仍 1314、worker 换为 9088/9089/9090/9091。
- 已讲清的知识点：`pgrep -a` 含义与退出码语义、`semanage <对象> <动作>` 语法与 `-a/-m/-d`、`semanage`（改策略存储，持久）与 `chcon`（改单文件标签，临时）的区别、`curl -sS` 中 `-S` 的必要性、reload 与 restart 的进程级区别。
- 收尾已完成：`file` 模块删除练习配置（changed=true）→ `systemd` reload（changed=true，MainPID 仍 1314，ExecReload=`/usr/sbin/nginx -s reload`）→ 18099 不再监听、curl 拒绝连接、worker 换为 9563-9566；`handlers-demo/` 已删（changed=true）；`redir-shell.txt` 返回 changed=false（此前已不存在）；`sudo semanage port -d -t http_port_t -p tcp 18099` 已撤销端口标签，环境回到最初状态。
- 新知：`systemd` 模块输出里的 `ExecReload` 直接印证「reload 就是给 master 发 HUP，MainPID 不变」；`state: reloaded` 的 ad-hoc 任务同样报 `changed=true`，说明模块层 `changed` 也不等于业务生效；`file` 模块删不存在的路径返回 `changed=false` 不报错，这是幂等清理的安全前提。
- 自检增强（2026-09-17 补充）：`handlers-nginx.yml` 在 `nginx -t` 之后加 `meta: flush_handlers`，再加 `wait_for`（port=`{{ nginx_demo_port }}`、state=started、timeout=5）。默认 18099 实测 `ok=4 changed=2 failed=1`，`RUNNING HANDLER` 出现在输出中间（flush_handlers 的签名），`wait_for` 报 `Timeout when waiting for 127.0.0.1:18099`，自动复现了 SELinux 拒绑；`-e nginx_demo_port=8008` 实测 `ok=5 changed=2 failed=0`，ss 显示 `LISTEN 127.0.0.1:8008`，curl 返回 `handler demo ok, version=1`，master 仍 1314、worker 换为 12412-12415。
- 关键结论：两次 `changed` 完全相同（2），只有 `failed` 不同（1 → 0）；`changed` 表示「做了动作」，`failed` 表示「结果对不对」。业务面验证应写进 playbook，不要靠人工翻日志。
- 自检实验残留已清理：删除 `/etc/nginx/conf.d/ops-handler-demo.conf`（changed=true）+ reload（MainPID 仍 1314）；ss 确认 8008 与 18099 均不再监听，worker 换为 12616-12619。已定端口约定：练习统一用白名单内 8008；18099 保持被 SELinux 拦截，作为可复现的故障演练场，不要 `semanage port -a` 放行。
- 唯一未单独复验项：18099 路径的「无改动重跑 changed=0」。
- 本节不要重做。下一步：清理残留、学 `block/rescue` 错误处理与多主机部署，最后做「一键部署 Nginx」完整 playbook。

## 2026-09-17 Ansible block 与 rescue 错误处理完成

- 已实测「没有 rescue」的后果：默认 18099 重跑 `ok=4 changed=2 failed=1 rescued=0`，`/etc/nginx/conf.d/ops-handler-demo.conf`（204 字节）留在磁盘上；worker 12616-12619 一个未换 → nginx 绑定失败会放弃新配置、继续用旧配置跑。
- `handlers-nginx.yml` 已改写为 `block` + `rescue`：rescue 里用 `file` 删 conf、`systemd` reload、末尾 `fail:` 重新抛错。关键点：rescue 中直接调模块不用 `notify`（救援必须无条件立即执行）；只删文件不够，还要 reload 才能回退运行状态；不写 `fail:` 时 Ansible 会认为已被救回、play 报成功。
- 实测失败路径 `ok=5 changed=2 failed=1 rescued=1`。**本轮 `Render` 是 `ok` 不是 `changed`**（上一轮残留文件与本次渲染内容相同，checksum 命中）→ 没有 RUNNING HANDLER；但 `wait_for` 仍失败并触发 rescue，因为它检查的是「端口在不在监听」这一持续状态。结论：**handler 对本轮变更负责，`wait_for` 对最终状态负责**。
- 回滚后现场干净：conf 不存在、nginx active、18099 无监听、worker 换为 13290-13293。
- 预估纠正：先前预计 `ok=6 changed=4`，实际 `ok=5 changed=2`。
- 成功路径对照：`-e nginx_demo_port=8008` 实测 `ok=5 changed=2 failed=0 rescued=0`，ss 显示 `LISTEN 127.0.0.1:8008`，curl 返回 `handler demo ok, version=1`，master 1314、worker 13472-13475。失败路径 `rescued=1`、成功路径 `rescued=0`。同一份代码 `Render` 在不同路径下分别报 `ok`/`changed`，差别来自当前状态与目标状态的差异。
- 残留已清理：删除 conf（changed=true）+ reload（MainPID 仍 1314）；8008 与 18099 均不再监听，nginx active，worker 换为 13631-13634。18099 的 SELinux 标签保持撤销状态。
- 本节不要重做。下一步：多主机部署与 `when` 条件（单机限制下可用 Docker 容器充当第二台被管节点，`ansible_connection: docker`），最后做「一键部署 Nginx」完整 playbook。
