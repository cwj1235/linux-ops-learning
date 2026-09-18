# 运维学习交接文件

归档位置：`项目记录/ops_handoff.md`。

用途：重开 Codex 线程、切换到 DeepSeek/GLM/Claude Code，或之后复习时，让新模型快速接上当前学习进度。

最后更新：2026-09-16

## 历史接续点（Redis noeviction 小节，最新停点见文件末尾的 Ansible 小节）

此前已复核 18 条历史会话及其 40 份原始/恢复记录；本次依据用户连续回传，统一归档 AOF 配置查询、在线启用、配置文件持久化、写入测试、9 月 14 日重启和 AOF 加载日志，以及指定 RDB 备份的隔离回灌验证。RDB 基础、AOF 基础和指定备份回灌均已完成，三项内核参数只读核验也已完成，但断电恢复和性能调优仍未完成。助手未连接虚拟机代做实验；本次 Redis 操作均由用户在 CentOS 执行。

- AOF 初始查询：`appendonly=no`、`appendfsync=everysec`；旧版 Redis 3.2 的 `CONFIG GET appendfilename` 返回空，配置文件第 597 行确认 `appendfilename "appendonly.aof"`。
- 启用前检查：AOF 文件原先不存在；`/var/lib/redis` 所在根分区可用约 12G、使用率 34%；配置备份为 `/etc/redis.conf.before-aof-20260914-094538`。
- `redis-cli CONFIG SET appendonly yes` 返回 `OK`；INFO 显示 `aof_enabled:1`、重写未进行、最近重写与写入状态均为 `ok`；AOF 文件生成，大小 139 字节、属主 `redis:redis`。
- `redis-cli CONFIG REWRITE` 返回 `ERR Rewriting config file: Permission denied`。原因是 Redis 用户虽为配置文件属主，但没有 `/etc` 目录的写权限来创建临时文件；没有放宽目录权限。
- 管理员执行 `sudo sed -i 's/^appendonly no$/appendonly yes/' /etc/redis.conf`，随后确认第 593 行为 `appendonly yes`，完成磁盘配置持久化；不需要再次执行 `CONFIG SET` 或 `CONFIG REWRITE`。
- 写入 `practice:aof-check=aof-ok` 后状态为 `aof_last_write_status:ok`。重启后未重新 SET，`GET practice:aof-check` 返回 `"aof-ok"`；PID 5519 的启动日志显示 `DB loaded from append only file: 0.000 seconds`，确认从 AOF 加载。
- 启动日志中的 backlog/somaxconn、`overcommit_memory`、THP 三项警告已在本任务中完成只读参数核验，结果为 128、0、always；尚未调整内核参数，不能当作调优已经完成。AOF 练习键暂不清理。
- 指定备份 `/var/lib/redis/dump.rdb.before-restart-20260913-183303` 已通过 `sudo redis-check-rdb` 校验：`Checksum OK`、`RDB looks OK!`、读取 2 个键、0 个过期键。
- 为避免影响正式 `6379` 实例，已创建 `/var/lib/redis-rdb-restore-20260914`，复制备份为 `dump.rdb`，并设置目录和文件属主为 `redis:redis`。
- 已用 `redis-server` 在 `127.0.0.1:6380` 启动隔离实例，指定该目录和 RDB 文件，关闭 AOF 与自动保存。`redis-cli -p 6380 INFO keyspace` 返回 `db0:keys=2`；`KEYS '*'` 列出 `server:centos100`、`practice:rdb-check`；日志显示 `DB loaded from disk` 和已监听 6380，确认指定 RDB 实际回灌成功。
- 恢复原理疑问已在本任务中讲解：`cp` 只准备备份文件，启动指定目录和文件、关闭 AOF 的 `redis-server` 时才自动加载 RDB 到内存；`--save ""` 不阻止启动加载。正式实例由 systemd 管理并已设置开机自启，临时实例本次手动启动；`--daemonize yes` 不等于开机自启，`sudo -u redis` 指 Linux 运行用户。
- 用户已在 `6380` 实测 `GET practice:rdb-check` 返回 `rdb-ok`、`HGETALL server:centos100` 返回唯一字段 `ip=192.168.6.100`。随后 `SHUTDOWN NOSAVE` 无输出，`6380 PING` 返回 `Connection refused`，正式 `6379 PING` 返回 `PONG`，确认临时实例关闭且正式实例仍正常响应。
- 临时目录清理已验证：先 ls 确认其中只有 158 字节的 `dump.rdb` 和 2.8K 的 `redis.log`，同时核对原始备份存在且为 158 字节；再对两个临时文件分别用 `rm -i` 确认删除，`rmdir` 删除空目录，最后 ls 返回“没有那个文件或目录”。不要再要求启动、关闭或清理这个实验目录；原始备份、正式数据目录与 AOF 不在删除范围。
- 新的 noeviction 演练已完成：用户先执行 `sudo ss -lntp 'sport = :6381'`，无输出确认拟用端口空闲；随后以 Redis 用户启动隔离实例 `127.0.0.1:6381`，目录为 `/var/lib/redis-noeviction-20260914`，参数为 `maxmemory=1048576`、`maxmemory-policy=noeviction`、`appendonly no`、`save ""`。
- 用户写入 30 个 65536 字节 value 的循环：前 6 次 `SET` 成功，key 为 `practice:noeviction:1` 至 `practice:noeviction:6`；第 7 次开始返回 `OOM command not allowed when used memory > 'maxmemory'`，最终 `DBSIZE=6`。查询时 `used_memory=923152`、`maxmemory=1048576`、策略为 noeviction、碎片率 5.71；查询值小于上限不推翻 OOM，因为 OOM 发生在第 7 次写入申请内存的瞬间，而 INFO 是事后查询值。
- 超限后的边界已验证：`GET practice:noeviction` 返回 `(nil)` 是 key 名写错，实际完整 key 带编号；`STRLEN practice:noeviction:1` 返回 65536，证明已有键仍可读；`DEL practice:noeviction:1` 后，`SET practice:noeviction:after-del small` 成功并可读回，证明释放内存后写入恢复。
- Redis 3.2 旧版 `redis-cli` 收到服务端 OOM 错误时退出码可能仍为 0，因此脚本中的 `|| { ...; break; }` 没有触发；不能依赖 redis-cli 退出码判断业务失败，需要解析输出或使用支持退出码的新版本。
- 用户执行 `redis-cli -p 6381 SHUTDOWN NOSAVE` 后，6381 `PING` 返回 `Connection refused`，正式 6379 `PING` 返回 `PONG`，确认临时实例关闭且正式实例正常。随后只读检查 `/var/lib/redis-noeviction-20260914`：目录属主 `redis:redis`，仅剩 2745 字节 `redis.log`，无 RDB/AOF/pid 文件。
- noeviction 临时目录最终清理已完成：用户用 `sudo rm -i` 确认删除 `redis.log`，`sudo rmdir` 删除空目录，`sudo ls -ld` 返回“没有那个文件或目录”；随后 6381 仍拒绝连接，6379 仍返回 `PONG`。不要用 `rm -rf`，也不要再要求启动、关闭或清理这个实验目录；正式数据目录不在删除范围。
- 用户只读实测 `net.core.somaxconn=128`、`vm.overcommit_memory=0`，THP 输出 `[always] madvise never`，当前生效选项为 `always`。三项与此前启动警告一致，但不能据此认定当前内存不足或已出现性能故障。 已解释：somaxconn 是连接等待队列限制，不是客户端总数；overcommit=0 为启发式内存分配判断，不代表当前内存不足；THP 的方括号标记当前选项。
- 调整前内存快照：整机 total=1980 MiB、used=936、free=247、buff/cache=796、available=866（约 44%），Swap 2047 MiB、used=0；Redis used_memory=812936 字节（793.88K）、RSS=6045696 字节（5.77M）、碎片率=7.44，maxmemory=0、策略 noeviction。 available 与 Swap 未显示明显内存压力；7.44 的比率受小分配量及进程额外开销影响，不能只凭它认定泄漏或强制重启。该快照在上限修改之前，不代表修改后的重新测量。
- 用户执行 `redis-cli -p 6379 CONFIG SET maxmemory 134217728` 返回 `OK`，随后 CONFIG GET 返回 `maxmemory` 与 `134217728`，确认正式实例运行时上限为 128 MiB。本次只修改 maxmemory，没有修改淘汰策略。 在线设置时未单独读取策略；本轮重启后已查询确认 noeviction。128 MiB 只作学习预算，未验证超限拒写或淘汰行为。
- 用户已核对 `/etc/redis.conf` 第 537 行由 maxmemory 注释示例变为 `maxmemory 134217728`；当前运行值与该文件中的上限均为 128 MiB。配置备份为 `/etc/redis.conf.before-maxmemory-20260914-165752`，复制输出已回传。17:10:21 服务重启后已直接读回 134217728，加载验收通过。 第 560 行 maxmemory-policy 与第 571 行 maxmemory-samples 在修改前均为注释，不把注释当作新配置生效证据。
- 2026-09-14 17:10:21 CST 正式 redis 服务重启后为 `active (running)`，主进程 PID 9261，ExecStop 为 `0/SUCCESS`，仍为 enabled；用户未重新 CONFIG SET，直接 CONFIG GET maxmemory 返回 `134217728`，128 MiB 上限的服务重启加载验收通过。 vendor preset 的 disabled 是默认策略，不是当前开机自启状态；status 显示的 limit.conf 附加配置未读取内容，不能仅据文件名解释其限制。
- 本轮重启后已执行 `redis-cli -p 6379 MGET practice:rdb-check practice:aof-check`，依次返回 `rdb-ok`、`aof-ok`；`redis-cli -p 6379 CONFIG GET maxmemory-policy` 返回 `noeviction`。两个指定字符串键和当前策略复核通过，结合上限读回，正式实例为 128 MiB + noeviction；没有新读回 Hash、核对 AOF 加载日志、验证全部键完整性或执行整机重启。
- 历史停点说明：当时曾计划先检查 6381 端口；该检查、隔离实例启动、noeviction 超限拒写、已有键读取、删除后恢复写入、实例关闭和临时目录最终清理均已完成。`allkeys-lru` 与 `volatile-lru` 隔离实验也已完成，当前下一步是依次评估 `net.core.somaxconn`、`vm.overcommit_memory`、THP，并整理 Redis 巡检手册，最后衔接 Docker/Compose。不向正式 `6379` 填充大量数据，不重做已结束的 `6380` 回灌。

- Linux/网络/Shell/Nginx/MariaDB 基础、Linux 运维强化基础检查与巡检脚本、Git/Python 基础脚本流程均已有学习和验证记录。
- Python 已归档推送；用户随后又成功提交并推送 `22b3b24 记录 Python 阶段提交结果`。不要重新要求复制或提交旧 Python 脚本。
- 当前处于阶段 3“服务运维深化”的 Redis 入门。Redis `3.2.12-2.el7` 已安装，实测 `active (running)`、`enabled`、监听 `127.0.0.1:6379`，`PING` 返回 `PONG`。
- 已验证：`SET/GET/DEL`、`EX/TTL`、`INCR/INCRBY/DECR`、`HSET/HGET/HGETALL/HDEL`。不要把 Redis 当作尚未开始的模块。
- 用户先成功读取 `ip` 和 `role`；误输入 `HDET` 被 Redis 以未知命令拒绝，随后自行改为 `HDEL`，返回删除字段数 `1`。
- 最后实测 Hash：`server:centos100` 仅剩 `ip=192.168.6.100`；`role` 已删除，整个键仍存在。
- 已实际执行 `EXISTS server:centos100` 返回 `1`、`HEXISTS server:centos100 role` 返回 `0`；键和字段的存在性检查已验证，不再作为待执行步骤。
- 已实际执行 `TYPE server:centos100` 返回 `hash`、`HLEN server:centos100` 返回 `1`；Hash 类型与字段数量已验证，本轮未重新读取字段值。

List 基础小节已经完成：

- `RPUSH practice:checks nginx mariadb` 返回 `2`，`LRANGE practice:checks 0 -1` 显示 `nginx`、`mariadb`，顺序与追加一致。
- 第一次 `LPOP` 返回 `nginx`，随后 `LRANGE` 只剩 `mariadb`，`LLEN` 返回 `1`。
- 第二次 `LPOP` 返回 `mariadb`，随后 `LLEN` 返回 `0`、`EXISTS practice:checks` 返回 `0`；练习键已随最后一个元素取出而自动消失，不需要再手动删除。
- 已验证 `RPUSH` 右端加入、`LPOP` 左端取出的先进先出（FIFO），以及列表范围读取、长度和取空行为。这里只保存并取出名称，没有执行真实巡检；重复元素仅讲过概念，没有单独实测重复追加。

Set 基础小节已经完成：

- `SADD practice:services nginx mariadb nginx` 返回 `2`，`SMEMBERS` 显示 `mariadb`、`nginx`，验证去重，输出不能按插入顺序理解。
- `SCARD` 返回 `2`；`SISMEMBER` 查询 `nginx` 返回 `1`、查询 `redis` 返回 `0`，只说明名称是否在集合里，不代表服务运行状态。
- 删除 `nginx` 的 `SREM` 返回 `1`；再次查成员返回 `0`，`SMEMBERS` 只剩 `mariadb`。
- 删除最后的 `mariadb` 返回 `1`，随后用户实际执行的是 `SMEMBERS`，返回 `(empty list or set)`；`EXISTS practice:services` 返回 `0`，集合键已自动消失。没有回传取空后的 `SCARD` 输出，不能记成已验证 `SCARD=0`。
- 已解释命令名称：`SCARD` 的 `CARD` 来自 cardinality（基数，即成员总数），`SREM` 的 `REM` 来自 remove（移除），前缀 `S` 表示 Set。`SREM` 返回本次删除数量，不是剩余成员数。

ZSet 基础小节已经完成：

- `ZADD practice:priority 20 nginx 10 mariadb 30 redis` 返回 `3`；`ZRANGE ... 0 -1 WITHSCORES` 按升序显示 `mariadb(10) → nginx(20) → redis(30)`。`WITHSCORES` 按成员、分数成对输出，六行对应三个成员。
- `ZADD practice:priority 5 nginx` 返回 `0`，表示没有新增成员，不是更新失败；`ZSCORE` 返回 `"5"`，升序变为 `nginx(5) → mariadb(10) → redis(30)`，`ZCARD` 仍为 `3`。
- `ZREVRANGE practice:priority 0 -1 WITHSCORES` 实际显示 `redis(30) → mariadb(10) → nginx(5)`，降序读取已经验证；`0 -1` 是索引范围，不是分数范围。
- `ZREM practice:priority nginx mariadb redis` 返回 `3`，随后 `ZCARD` 返回 `0`、`EXISTS` 返回 `0`。删除全部成员后键已自动消失，不保留空 ZSet 键，也不需要再次清理。
- 本节只操作服务名称和分数，没有修改真实服务启动顺序或优先级。命令采用 Redis 3.2 支持的语法，不直接照搬新版本命令。

配置、日志与本机监听小节已经完成：

- `systemctl cat redis --no-pager` 显示启动参数使用 `/etc/redis.conf --supervised systemd`，`INFO server` 的 `config_file` 同样为 `/etc/redis.conf`。补充单元中的 `LimitNOFILE=10240` 是文件描述符上限设置，不是已验证的最大客户端数。
- `CONFIG GET bind/port/logfile` 是分别执行的三条命令，返回 `127.0.0.1`、`6379`、`/var/log/redis/redis.log`；只读筛选配置文件第 61、84、163 行，三项与运行值一致。不要向 Redis 3.2 布置多配置项参数的新版本查询语法。
- 日志末尾 20 行包含 9 月 13 日四轮 RDB 自动后台保存成功，最后结束于 `14:27:39.157`。当时已解释保存条件、后台子进程及写时复制内存不是快照文件大小；后续文件检查和手动保存见下方 RDB 进度，重启恢复仍未验证。
- `CONFIG GET protected-mode` 返回 `yes`；随后 `ss` 实测 `LISTEN 0 128 127.0.0.1:6379 *:*`，进程为 `redis-server`、`pid=1207`、`fd=4`。实际本地监听与配置一致，对端列的 `*:*` 不等于开放所有网卡，队列数和 `fd` 不是客户端数。
- 全程未改配置、重启服务、开放端口或检查认证密码。重复粘贴的同一段配置和日志只记录一次，不补造执行次数，也不把复制转义当成新故障。

RDB 小节当前已验证：

- 分别查询 `save`、`dir`、`dbfilename`，返回 `900 1 300 10 60 10000`、`/var/lib/redis`、`dump.rdb`。三组保存规则内部为“且”，组间为“或”；不是必须修改不同的键，也不是固定无条件定时保存。
- 手动保存前用 `sudo ls -lh /var/lib/redis/dump.rdb` 查到 131 字节、修改时间 `9月 13 14:27`；随后重启前检查源文件和备份，均为 158 字节、`redis/redis`、修改时间 `17:35`。131 字节是早期基线，158 字节和内容一致性是重启前结果，不当作重启后的复查。
- `SET practice:rdb-check rdb-ok` 返回 OK；误输入 GRT 后修正为 GET，读到 `rdb-ok`。该 GET 在 BGSAVE 之前，不是恢复后的读回；没有删除练习键的记录。
- BGSAVE 返回 `Background saving started`；随后的 INFO 中 `rdb_bgsave_in_progress=0`、`rdb_last_bgsave_status=ok`、`rdb_changes_since_last_save=0`、`rdb_last_save_time=1789292105`、`aof_enabled=0`，确认手动后台保存成功，当前 AOF 未开启。相同输出重复贴出不另记执行次数。
- 已解释 cp/scp：当前快照和备份均在 CentOS 内，应使用 cp；scp 主要通过 SSH 跨主机复制。示例文件和示例上传没有实操，不当作已经完成的备份或传输。

快照复制已有用户成功回传：

```text
"/var/lib/redis/dump.rdb" -> "/var/lib/redis/dump.rdb.before-restart-20260913-183303"
```

早期仅贴出的 `cmp -s ... && echo ... || echo ...` 不算执行；本次用户已实际运行不带 `-s` 的 `sudo cmp`，无输出，紧接着 `echo $?` 返回 `0`。结合两个文件均为 158 字节，确认重启前逐字节一致。cp 的 `-a` 保留修改时间，备份显示 17:35 不代表在 17:35 创建。

正常重启与数据加载已验证：

- 用户执行 `sudo systemctl restart redis`，随后 status 为 `active (running)`，启动时间 `2026-09-13 23:45:36 CST`，主进程 `3047`，ExecStop 为 `status=0/SUCCESS`，仍为 enabled。vendor preset 的 disabled 是默认策略，不是关闭了当前自启。
- 重启后未重新 SET，`GET practice:rdb-check` 返回 `rdb-ok`，说明原练习值可以读回；没有删除练习键或备份。
- 重启后 INFO：`loading=0`、`rdb_changes_since_last_save=0`、`rdb_bgsave_in_progress=0`、`rdb_last_save_time=1789314336`、`rdb_last_bgsave_status=ok`、`aof_enabled=0`。RDB 两项耗时为 -1，不代表失败，也不能据此或 last_save_time 声称新进程做过一次 BGSAVE。
- 最新 tail 输出中，PID 3047 在 `23:45:36.212` 记录 `DB loaded from disk: 0.000 seconds` 和端口 6379 的就绪信息。结合 AOF 关闭和 GET，确认正常启动加载 RDB；状态输出里的进程参数及日志不是重启后重新运行 ss 的证据。

本次三条启动 WARNING 已记录为待检查项：请求 backlog=511、somaxconn=128；overcommit_memory=0；THP 开启。它们提示连接排队、低内存下后台保存及延迟/内存风险，不是本次服务启动或加载失败。尚未读取对应内核文件、调整参数或配置持久化，后续在内存与性能小节逐项核验，不直接照日志修改整机配置。

验证边界：正常停止 Redis 可能再次保存 RDB，这次没有把备份文件复制回正式位置，也没有宕机或断电实验；不能称为指定备份恢复通过或全部键完整性已验证。源快照可能在重启时更新，之前 cmp=0 也不是重启后的持续一致性保证。

下一步讲清 RDB 快照与 AOF 写操作日志的区别，然后在 CentOS 只读查询以下三项；尚未收到结果，不提前开启 AOF：

```bash
redis-cli CONFIG GET appendonly
redis-cli CONFIG GET appendfilename
redis-cli CONFIG GET appendfsync
```

本次按已完成的 RDB 基础小节统一记录，继续采用概念、少量命令、用户回传、解释输出的节奏。保留练习键和备份；后续安排 AOF 启用/恢复、备份文件恢复专项、内存限制/淘汰、警告核验、故障演练和巡检集成。SSH 密钥加固、MySQL 慢查询/锁等仍属于后续补缺，不因基础阶段完成就视为全部掌握。

课程正文与状态见 `学习总结/ops_redis_basics.md`，实际命令见 `项目记录/ops_command_history.md` 的 Redis 小节。下方保留早期交接，不再代表当前停点。

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
- 回复要更快，但不要因此缩短讲解、跳过必要核对或乱给信息；减少不必要的重复查阅，明确区分已验证、待验证与推测。这是用户于 2026-09-13 补充强调的偏好。
- 用户于 2026-09-17 进一步明确：每次答复和教学内容都要先认真思考再给，不要不思考就给答案；先说明判断依据和不确定的地方，再给结论和命令，不接受泛泛的即时回答。
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

按小节统一维护记录：完成一个小节的讲解、练习和验证后，再同步更新本地文件；小节进行中只解释输出、继续教学，不要每完成一条命令或每收到一次回传就修改文件。这是用户于 2026-09-13 明确调整的记录频率。

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

## 2026-09-08 Git 合并冲突复习

- 已创建两个临时分支并修改同一文件同一行，实际触发内容冲突。
- 已理解 `<<<<<<< HEAD`、`=======`、`>>>>>>> branch-name` 的含义。
- 手动保留正确内容后执行 `git add` 和 `git commit`，生成合并提交 `28b57d6`。
- 已删除 `conflict-a` 和 `conflict-b`，当前分支为 `main`，工作区干净。
- Git 分支和合并冲突基础完成；下一步进入 `.gitignore` 与远程仓库。

## 2026-09-09 GitHub 远程仓库

- 已创建公开 GitHub 仓库 `linux-ops-learning`。
- 已配置 `origin` 并执行 `git push -u origin main` 成功。
- 当前 `git branch -vv` 显示 `main a2071cd [origin/main]`，本地 `main` 与远程分支已关联。
- 下一步学习远程更新同步、`git pull` 和 `git clone`。

## 2026-09-09 Git clone 验证

- 直接 clone GitHub 时 HTTPS 连接被重置。
- 在当前 PowerShell 会话设置 `HTTP_PROXY`、`HTTPS_PROXY` 为 `http://127.0.0.1:7890` 后，`git clone --depth 1` 成功。
- 克隆目录 `..\linux-ops-learning-clone-2` 状态干净，`origin` 地址正确。
- 远程仓库、push、pull、clone 基础流程已验证；下一步可学习远程分支更新和实际协作流程。

## 2026-09-09 Git 远程协作同步

- 第二个克隆目录修改 README 并提交，直接 push 因远程领先而被拒绝。
- 使用 `git pull --rebase origin main` 成功整合远程提交，之后 push 到 `origin/main` 成功。
- 主项目执行 `git pull`，结果为 `Fast-forward`，README 已出现第二个克隆目录的更新。
- 主项目和第二个克隆目录均已验证工作区干净且与远程同步。
- Git 远程基础和双目录协作同步完成；下一步可进入运维脚本的 Git 管理实战。

## 2026-09-09 运维脚本纳入 Git

- 已通过 `scp` 将 CentOS `/opt/scripts/system_inspection.sh` 复制到仓库 `scripts/system_inspection.sh`。
- 脚本共 122 行，已提交为 `624b2f1 加入 Linux 系统巡检脚本` 并推送到 GitHub。
- `git ls-files scripts/system_inspection.sh` 和文件专属 `git log` 均验证成功。
- 下一步学习修改脚本、查看差异、提交版本并同步到 CentOS。

## 2026-09-09 Git `.gitignore` 与跟踪清理补充

- 已实际验证 `*.log` 忽略规则：`git status --short` 无输出，`git check-ignore -v` 定位到 `.gitignore` 第 16 行，测试文件随后已删除。
- 已讲解 `git rm --cached` 的作用：取消 Git 跟踪但保留本地文件；本次尚未实际执行。
- Git 记录需区分实际执行命令和概念讲解；下一步继续脚本修改和部署同步。

## 2026-09-09 运维脚本修改与部署验证

- 修改仓库中的开始日志，提交 `d6eb2be` 并成功推送。
- 通过 `scp` 传到 CentOS，`bash -n` 检查通过，再复制到 `/opt/scripts/system_inspection.sh`。
- 实际巡检结果正常：6 个服务 active、两个 HTTP 为 200、内存 42%、根分区 33%、inode 2%，warned=0、failed=0。
- `grep` 已确认新开始日志写入 `/var/log/system_inspection.log`。
- 本次完成 Git 修改到 CentOS 部署和日志验证的闭环；下一步继续脚本版本管理或进入下一 Git 小节。

## 2026-09-10 Python 运维脚本起步

- 已确认 CentOS 上 `python` 是 2.7.5，`python3` 是 3.6.8。
- 创建 `/home/atguigu/system_info.py`，使用 `#!/usr/bin/env python3` 和 `print`。
- 显式使用 `python3` 执行成功；增加执行权限后直接执行也成功，shebang 生效，退出码为 0。
- 之前用 `python` 执行也成功，但只是因为这段简单代码同时兼容 Python 2 和 Python 3。
- 下一步讲解 Python `subprocess` 和系统命令调用。

## 2026-09-10 Python subprocess 初次验证

- 已执行 `python3 -c 'import subprocess; subprocess.run(["hostname"])'`。
- 实际输出 `centos100`，验证 Python 3 能通过 `subprocess.run` 执行系统命令。
- 下一步学习读取命令输出和退出码。

## 2026-09-10 Python subprocess 输出对象

- 已用 `stdout=subprocess.PIPE` 获取 `hostname` 输出，实际为 `centos100`，退出码为 `0`。
- 已区分 `result.stdout`、`result.returncode` 和直接打印 `CompletedProcess` 对象的效果。
- Python 笔记已新增到 `学习总结/ops_python_basics.md`。
- 下一步观察成功命令和失败命令的退出码。

## 2026-09-10 Python `subprocess.PIPE` 讲解

- 已讲解 `stdout=subprocess.PIPE`：让 Python 通过 `result.stdout` 获取子进程输出。
- 已区分 `stdout`、`stderr` 和 Shell 管道符 `|`；本次没有单独执行新的 PIPE 实验。
- 下一步继续成功/失败命令退出码实验。

## 2026-09-10 Python 文本输出与退出码

- 已讲解 `universal_newlines=True` 将捕获结果作为字符串处理；当前 Python 3.6.8 使用该写法。
- 实际验证 `false` 返回 1、`true` 返回 0，并与 Shell `$?` 对应。
- 下一步把 `subprocess` 写入 `system_info.py`。

## 2026-09-10 Python system_info 脚本验证

- `/home/atguigu/system_info.py` 已写入 `subprocess.run(["hostname"])`。
- 直接执行得到 `hostname: centos100`、`returncode: 0`。
- 下一步先解释代码结构，再添加新的系统信息检查。

## 2026-09-10 Python uptime 检查

- `system_info.py` 已增加 uptime 调用。
- 实际输出：运行 3 小时 18 分、2 users、load average `0.01, 0.04, 0.05`，退出码 0。
- 下一步解释输出字段并学习用函数减少重复代码。

## 2026-09-10 Python subprocess 函数复用

- `system_info.py` 已用 `run_command()` 统一封装命令执行、标准输出读取和退出码输出。
- 语法检查通过，脚本直接执行成功，`hostname` 和 `uptime` 的退出码均为 `0`。
- 下一步学习 `stderr=subprocess.PIPE`，处理失败命令的错误输出。

## 2026-09-10 Python stderr 捕获验证

- 已执行 `ls /not-exist`，同时捕获 `stdout`、`stderr` 和退出码。
- 实际结果：`stdout=''`，`stderr='ls: 无法访问/not-exist: 没有那个文件或目录\n'`，`returncode=2`。
- 已解释 `repr()` 用于调试时查看字符串真实结构。
- 下一步把错误输出处理加入 `run_command()`。

## 2026-09-10 Python format 花括号讲解

- 已解释 `format()` 字符串中的 `{}` 占位符和按顺序替换规则。
- 用户理解后继续修改 `run_command()`。

## 2026-09-10 Python run_command 捕获 stderr

- `run_command()` 已加入 `stderr=subprocess.PIPE` 和错误输出判断。
- 语法检查和正常执行均通过，成功命令不会输出 `stderr`。
- 下一步用失败命令验证错误分支。

## 2026-09-10 Python 失败命令脚本验证

- 失败命令 `ls /not-exist` 实际输出错误信息，`ls_returncode` 为 `2`。
- 随后 Shell 的 `echo $?` 为 `0`，确认这是 Python 脚本自身退出码，不是 `ls` 的退出码。
- 当前脚本只打印子命令失败结果，没有使用 `sys.exit()` 传递失败状态。
- 下一步学习如何设计脚本整体退出码，再把结果用于自动化巡检判断。

## 2026-09-10 Python 清理临时失败测试

- 已删除临时的 `ls /not-exist` 测试行。
- 脚本重新执行成功，`hostname_returncode` 和 `uptime_returncode` 均为 `0`，Shell 的 `echo $?` 也为 `0`。
- 下一步学习 `sys.exit()`，让脚本整体退出码反映检查结果。

## 2026-09-10 Python sys.exit 成功分支验证

- `system_info.py` 已加入 `sys.exit(1)` 失败分支和 `sys.exit(0)` 成功分支。
- 语法检查无输出，`hostname`、`uptime` 均返回 `0`，脚本后的 `echo $?` 为 `0`。
- 下一步临时让一个命令失败，验证脚本整体是否返回 `1`，验证后恢复正确命令。

## 2026-09-11 Python sys.exit 失败分支验证

- 临时将 `uptime` 命令替换为 `false`，语法检查通过。
- 实际得到 `false_returncode: 1`，随后 Shell 的 `echo $?` 为 `1`。
- 已验证 `sys.exit(1)` 能把子命令失败传递为脚本整体失败。
- 下一步将命令恢复为 `uptime`，再做一次成功验证。

## 2026-09-11 Python 恢复正式命令验证

- 已把临时失败命令 `false` 恢复为正式命令 `uptime`。
- 语法检查通过，`hostname` 和 `uptime` 均返回 `0`，Shell 的 `echo $?` 为 `0`。
- `system_info.py` 当前处于正常版本。
- 下一步：总结当前 Python subprocess 脚本，再进入参数化或日志记录设计。

## 2026-09-11 Python sys.argv 参数实验

- 已完成 `python3 -c 'import sys; print(sys.argv)' hostname uptime`。
- 实际得到 `['-c', 'hostname', 'uptime']`，已理解 `sys.argv[0]` 和用户参数从 `sys.argv[1]` 开始的关系。
- 下一步在实际 `.py` 文件中观察 `sys.argv[0]`，再学习读取命令行参数。

## 2026-09-11 Python 文件参数验证

- 已创建 `/home/atguigu/args_demo.py`。
- 执行时 `sys.argv[0]` 输出脚本路径，`sys.argv[1:]` 输出 `['hostname', 'uptime']`。
- 下一步学习 `for` 循环，逐个读取和处理命令行参数。

## 2026-09-11 Python for 循环参数验证

- `args_demo.py` 已使用 `for argument in sys.argv[1:]` 逐个输出参数。
- 实际传入 `hostname uptime` 后，两个参数分别输出，循环验证成功。
- 下一步让循环中的参数进入 `subprocess.run()`，实际执行命令。

## 2026-09-11 Python 参数执行命令验证

- `args_demo.py` 已在循环中使用 `[argument]` 调用 `subprocess.run()`。
- 实际执行 `hostname uptime`，两个命令的 `returncode` 均为 `0`。
- 输出标签少一个空格，但不影响命令执行。
- 下一步传入 `false`，验证参数化脚本如何显示失败退出码。

## 2026-09-11 Python 参数失败命令验证

- 执行 `args_demo.py false` 后得到 `false returncode:1`，子命令失败结果验证成功。
- 用户随后执行了 `vim`，再执行 `echo $?`；该 `0` 是 `vim` 的退出码，不是 Python 脚本退出码。
- 下一步连续执行 Python 脚本和 `echo $?`，确认当前脚本整体仍返回 `0`。

## 2026-09-11 Python 参数脚本整体退出码验证

- 连续执行 `args_demo.py false` 和 `echo $?`，得到 `false returncode: 1`、脚本退出码 `0`。
- 已确认参数脚本当前只打印子命令结果，没有把失败状态传给 Shell。
- 下一步增加失败标记和 `sys.exit()`，让任意命令失败时脚本整体返回 `1`。

## 2026-09-11 Python 参数脚本失败状态传递

- `args_demo.py` 已增加 `has_failure` 标记和 `sys.exit()`。
- 语法检查通过；执行 `false` 后，子命令和脚本整体退出码均为 `1`。
- 下一步使用成功、失败、成功三个命令，验证循环是否继续执行且最终仍返回失败。

## 2026-09-11 Python 多命令结果汇总验证

- 实际执行参数 `false uptime`，第一个命令返回 `1`，第二个命令仍继续执行并返回 `0`。
- 脚本最终退出码为 `1`，确认 `has_failure` 能汇总整轮命令结果。
- 下一步只传入成功命令，验证整体退出码恢复为 `0`。

## 2026-09-11 Python 全部成功参数验证

- 执行 `args_demo.py hostname uptime`，两个命令均返回 `0`，输出正常。
- 本次尚未执行 `echo $?`，脚本整体成功退出码待确认。
- 下一步直接执行 `echo $?`，确认整体返回 `0`。

## 2026-09-11 Python 参数化脚本三种状态完成

- 补充执行 `echo $?` 得到 `0`，确认全部成功时脚本整体返回 `0`。
- 已验证全部成功、任意失败、部分失败后继续执行三种情况。
- `args_demo.py` 的基础参数化和退出码汇总逻辑完成。
- 下一步学习标准库 `argparse`，为脚本增加规范的参数说明和帮助信息。

## 2026-09-11 Python argparse 代码讲解

- 已讲解 `argparse.ArgumentParser`、`description`、`add_argument`、`nargs="+"`、`help`、`parse_args()` 和 `args.commands`。
- 已明确区分：本次只完成代码讲解，新的 `argparse` 版本尚未实际验证。
- 下一步执行 `python3 /home/atguigu/args_demo.py --help`，观察自动生成的帮助信息。

## 2026-09-11 Python argparse help 验证

- 实际执行 `python3 /home/atguigu/args_demo.py --help`，成功看到 usage、`commands` 位置参数和 `-h/--help` 说明。
- 已验证 `argparse` 自动生成帮助信息，`--help` 不进入命令执行循环。
- 下一步不传入任何命令，验证 `nargs="+"` 的必填参数校验。

## 2026-09-11 Python argparse 必填参数验证

- 不传入命令时，`argparse` 提示 `commands` 为必填参数。
- 实际退出码为 `2`，确认参数解析错误发生在命令执行之前。
- 已区分参数使用错误的退出码 `2` 与子命令失败的退出码 `1`。
- 下一步传入合法命令，验证 `argparse` 版本的正常执行路径。

## 2026-09-11 Python argparse 合法参数验证

- 实际传入 `hostname uptime`，两个命令均返回 `0`。
- 紧接执行 `echo $?` 得到 `0`，确认脚本整体成功退出。
- `argparse` 基础路径已完成：`--help`、缺少必填参数、合法参数执行。
- 下一步可给脚本增加可选参数，例如 `--verbose` 或命令超时设置。

## 2026-09-11 Python argparse 未知选项验证

- 尝试传入尚未定义的 `--verbose`，`argparse` 报告 `unrecognized arguments`。
- 已理解可选参数必须先通过 `add_argument()` 注册。
- 下一步正式加入 `--verbose`，使用 `action="store_true"` 控制详细输出。

## 2026-09-12 Python argparse verbose 验证

- 已注册 `--verbose`，并通过 `if args.verbose` 输出当前正在执行的命令。
- 语法检查通过；执行 `--verbose hostname uptime` 时实际看到 `executing: hostname` 和 `executing: uptime`，两个命令均返回 `0`。
- 已理解 verbose 只增加过程信息，不改变命令本身结果。
- 下一步验证不加 `--verbose` 的普通输出，随后可学习命令超时设置。

## 2026-09-12 Python argparse 普通模式验证

- 不加 `--verbose` 执行 `hostname uptime`，没有显示 `executing:`，但两个命令均返回 `0`。
- `echo $?` 为 `0`，确认普通模式脚本整体成功。
- 已完成 verbose 与普通模式对比；下一步学习 `subprocess.run()` 的 `timeout` 参数。

## 2026-09-12 Python subprocess timeout 验证

- 已在 `subprocess.run()` 中加入 `timeout=3` 和 `subprocess.TimeoutExpired` 处理。
- 执行 `hostname yes` 时，`hostname` 成功，`yes` 超时，脚本整体退出码为 `1`。
- 超时功能验证成功；提示文字因逗号打印出现 `{}` 和参数分离，下一步修正为 `format()` 写法。

## 2026-09-12 Python timeout 提示格式修正

- 已将超时提示修正为 `"{} timeout after 3 seconds".format(argument)`。
- 实际显示为 `yes timeout after 3 seconds`，脚本退出码仍为 `1`。
- 输出中的 `^[[A` 是终端方向键控制序列，不属于脚本逻辑。
- 注意：最后一次 `vim` 修改后，需要重新执行 `python3 -m py_compile` 再确认语法。

## 2026-09-12 Python timeout 修改后完整验证

- 修改后的 `args_demo.py` 已重新通过 `python3 -m py_compile`。
- 执行 `hostname yes` 时，`hostname` 返回 `0`，`yes` 显示正确超时提示并在 3 秒后结束。
- 脚本整体退出码为 `1`，超时处理验证完成。
- 下一步恢复正常命令测试，并总结 `argparse`、verbose 和 timeout。

## 2026-09-12 Python 参数脚本阶段完成

- 已恢复正常命令并重新验证：`hostname`、`uptime` 均返回 `0`，脚本整体退出码为 `0`。
- 当前脚本已完成 `argparse`、`--help`、参数校验、`--verbose`、stdout/stderr、失败汇总、timeout 和 `sys.exit()`。
- 下一步整理本阶段总结，再考虑加入日志记录或将脚本纳入 Git 仓库。

## 2026-09-12 Python logging 基础验证

- 已通过 `python3 -c` 实际验证 `logging.INFO`、`logging.WARNING` 和 `logging.ERROR`。
- `format="%(levelname)s: %(message)s"` 生效，日志按级别显示在终端。
- 下一步学习使用 `filename` 将日志写入文件。

## 2026-09-12 Python logging 文件验证

- 使用 `filename="/home/atguigu/python_demo.log"` 实际写入日志。
- `cat` 查看确认日志包含时间、`INFO`/`ERROR` 级别和消息内容。
- 文件日志验证完成；下一步将 logging 集成到 `args_demo.py`。

## 2026-09-12 Python args_demo logging 集成验证

- `args_demo.py` 已加入 logging 配置，并记录命令开始和成功事件。
- 语法检查通过；执行 `hostname uptime` 后，`args_demo.log` 中出现两组 `command started` 和 `command succeeded`。
- 终端输出与日志文件职责已分开：终端显示结果，文件保存过程记录。
- 下一步传入失败命令和超时命令，验证 `ERROR` 日志。

## 2026-09-12 Python logging 失败与超时验证

- 执行 `false yes` 后，`false` 返回 `1`，`yes` 超时，脚本整体退出码为 `1`。
- `args_demo.log` 成功记录 `command failed: false returncode=1` 和 `command timeout: yes`。
- logging 集成验证完成：成功、失败、超时均有对应日志。
- 下一步总结 Python 阶段，并将脚本和学习记录纳入 Git。

## 2026-09-12 Python 阶段完整记录完成

- 已完整核对并补充 `学习总结/ops_python_basics.md`，覆盖 Python 版本、shebang、subprocess、PIPE、stdout/stderr、退出码、函数、sys.argv、for、argparse、verbose、timeout 和 logging。
- 已区分实际执行结果与纯代码讲解，并保留成功、失败、混合命令和超时验证结果。
- 当前 CentOS 上 `system_info.py`、`args_demo.py` 和对应日志文件均已实际验证；正常路径返回 `0`，失败或超时路径返回 `1`，参数解析错误返回 `2`。
- Windows Git 仓库中的 Python 笔记和项目记录尚未提交；CentOS 的 `args_demo.py` 尚未复制进仓库。
- `.log` 文件受 `.gitignore` 的 `*.log` 规则忽略，不直接提交日志文件。
- 下一步：通过 `scp` 将 `args_demo.py` 复制到仓库 `scripts/`，检查内容和语法，再提交 Python 阶段记录并推送。

## 2026-09-15 Redis allkeys-lru 小节完成

- 已使用隔离实例 `127.0.0.1:6381` 完成 `allkeys-lru` 演练，工作目录为 `/var/lib/redis-allkeys-lru-20260915`。
- 实例配置验证为 `maxmemory=1048576`、`maxmemory-policy=allkeys-lru`、`appendonly no`，且 `save ""` 生效。
- 连续写入 30 个约 65536 字节的 `practice:allkeys-lru:$i` value，全部返回 `OK`；`evicted_keys=24`，`DBSIZE=6`。
- 最终保留 key 为 `practice:allkeys-lru:25` 至 `practice:allkeys-lru:30`；`:1` 和 `:24` 已被淘汰，`:25` 和 `:30` 仍存在，`:30` 的 `STRLEN=65536`。
- `SHUTDOWN NOSAVE` 后 6381 拒绝连接，6379 返回 `PONG`；实验目录最终仅剩 `redis.log`，用户已确认删除日志并移除目录。
- 对比结论：`allkeys-lru` 在内存不足时淘汰旧 key，使新写入继续成功；这与 `noeviction` 的 OOM 拒写形成对比。
- 下一步：进入 `volatile-lru` 演练，重点验证它只淘汰设置了 TTL 的 key。

## 2026-09-12 Python 脚本复制状态

- 已通过 Windows PowerShell 的 `scp` 将 CentOS `/home/atguigu/args_demo.py` 复制到仓库 `scripts/args_demo.py`。
- 文件检查显示大小为 1532 字节，内容包含 argparse、verbose、timeout、logging 和退出码逻辑。
- `git status --short` 显示 `?? scripts/args_demo.py`，说明文件已存在但尚未跟踪。
- Python 学习记录四个文件也尚未提交；下一步先检查差异和暂存内容，再提交推送。

## 2026-09-12 Python 阶段 Git 提交完成

- `scripts/args_demo.py` 与四份 Python 学习记录已通过 `git diff --cached --check` 检查并提交。
- 提交为 `d573677 完成 Python 运维脚本阶段记录`，共 5 个文件、1732 行新增内容。
- 已执行 `git push`，远程 `main` 从 `144be20` 更新到 `d573677`。
- `git status` 显示 `Your branch is up to date with 'origin/main'` 和 `nothing to commit, working tree clean`。
- Python 阶段资料已纳入 Git 并同步到 GitHub；下一步进入后续运维自动化或服务运维模块。

## 2026-09-15 Redis volatile-lru 小节完成

- 隔离实例：`127.0.0.1:6381`，临时目录：`/var/lib/redis-volatile-lru-20260915`。
- 已验证 `maxmemory=1048576`、`maxmemory-policy=volatile-lru`、`appendonly=no`、`save=""`。
- 写入 3 个无 TTL key 和 30 个 `EX 86400` key；结果 `evicted_keys=27`、`DBSIZE=6`。
- 保留 3 个无 TTL key 与 `ttl:28`、`ttl:29`、`ttl:30`，证明 `volatile-lru` 只在设置过期时间的 key 中淘汰。
- `no-ttl:1 TTL=-1` 表示无过期时间；`ttl:28` 到 `ttl:30` 均能读出 TTL，长度仍为 65536 字节。
- 实例已 `SHUTDOWN NOSAVE`，6381 拒绝连接，6379 返回 `PONG`，临时目录已清理。

## 当时下一步（历史记录）

1. 整理 Redis 巡检手册，纳入状态、端口、应用响应、持久化状态和内核参数。
2. 之后进入 Docker/Compose。

## 2026-09-15 Redis 内核参数调优完成

- 调整前确认：Redis `tcp-backlog=511`，但 `net.core.somaxconn=128`；`vm.overcommit_memory=0`；THP 为 `[always]`。
- 已备份 `/etc/sysctl.conf`，并创建 `/etc/sysctl.d/99-redis.conf`，写入 `net.core.somaxconn=1024`、`vm.overcommit_memory=1`。
- `sudo sysctl --system` 后复核两项参数分别为 `1024`、`1`。
- 已运行时关闭 THP，并创建 `/etc/tmpfiles.d/redis-disable-thp.conf`，THP 复核为 `always madvise [never]`。
- 重启 Redis 前监听队列 `Send-Q=128`；`sudo systemctl restart redis` 后 `PING=PONG`、`Send-Q=511`、`tcp-backlog=511`。
- 本节不需要重做。下一步整理 Redis 巡检手册，再衔接 Docker/Compose。

## 2026-09-15 Redis 巡检手册完成

- 巡检结果：Redis `active`、`enabled`、监听 `127.0.0.1:6379`、`Send-Q=511`、`PING=PONG`、`DBSIZE=3`。
- 配置结果：`maxmemory=134217728`、`maxmemory-policy=noeviction`、`appendonly=yes`、`appendfsync=everysec`、`save="900 1 300 10 60 10000"`、`dir=/var/lib/redis`、`dbfilename=dump.rdb`。
- 持久化状态：`rdb_last_bgsave_status=ok`、`aof_last_write_status=ok`，RDB/AOF 后台任务均不在执行中。
- 文件结果：`appendonly.aof` 212 字节，`dump.rdb` 185 字节，`LASTSAVE` 为 `2026-09-15 15:49:46 CST`；`dump.rdb.before-restart-20260913-183303` 是历史备份。
- 内存与日志：`used_memory=793.88K`、上限 `128.00M`、`evicted_keys=0`、`rejected_connections=0`，最近 24 小时错误日志为空。
- `CONFIG GET apendonly` 是拼写错误；Redis 3.2 下 `appendfilename` 查询为空时用 `append*` 和实际文件检查判断，不视为异常。
- 本节巡检手册已完成，不要重做。下一步进入 Docker/Compose。

## 当前下一步（最新）

1. 进入 Docker/Compose。
2. 优先完成 Docker 安装、镜像、容器、端口映射和数据卷基础。

## 2026-09-15 Docker 安装与容器生命周期完成

- 系统为 CentOS 7，内核 `3.10.0-1160.el7.x86_64`；安装前 Docker 不存在。
- Docker 官方仓库访问失败后，已改用阿里云 Docker CE 仓库并成功安装。
- 已安装 `docker-ce 26.1.4`、`docker-ce-cli 26.1.4`、`containerd.io 1.6.33`、`docker-compose-plugin 2.27.1`。
- `sudo systemctl enable --now docker` 已执行，Docker 客户端和服务端均正常。
- Docker Hub 首次拉取 `hello-world` 超时；配置 `/etc/docker/daemon.json` 使用 `https://docker.m.daocloud.io` 后拉取和运行成功。
- 已完成 `hello-world` 与 `alpine:latest` 的镜像拉取、容器运行、状态检查、`docker exec`、停止、删除容器和删除镜像验证。
- Alpine 容器停止状态为 `Exited (137)`，原因是 `docker stop` 超时后发送 `SIGKILL`；容器随后已删除，练习镜像也已清理。
- 本节不要重做。下一步学习 Docker 数据卷和端口映射，再进入 Dockerfile 与 Compose。

## 当前下一步（最新）

1. 学习 Docker 数据卷，验证容器删除后宿主机数据仍保留。
2. 学习端口映射，验证宿主机端口访问容器内服务。
3. 再学习 Dockerfile 基础和 Docker Compose。

## 2026-09-15 Docker 数据卷验证完成

- 已创建 `practice-volume`，`docker volume inspect` 确认宿主机路径为 `/var/lib/docker/volumes/practice-volume/_data`。
- 第一个 `--rm` Alpine 容器向 `/data/check.txt` 写入 `docker-volume-ok` 后退出并自动删除。
- 第二个新的 `--rm` Alpine 容器挂载同一个数据卷，成功读出 `docker-volume-ok`。
- 结论：数据保存在 volume 中，不随容器删除而丢失。
- 已执行 `docker volume rm practice-volume`，并删除 `alpine:latest`，练习环境已清理。
- 本节不要重做。下一步学习 Docker 端口映射。

## 当前下一步（最新）

1. 学习 Docker 端口映射，验证宿主机端口可以访问容器内服务。
2. 再学习 Dockerfile 基础和 Docker Compose。

## 2026-09-15 Docker 端口映射验证完成

- 宿主机 `18080` 端口启动前为空闲；首次使用 `nginx:alpine` 创建容器成功但退出，`ExitCode=1`、`OOM=false`。
- 失败日志为 `pwrite() "/run/nginx.pid" failed (1: Operation not permitted)`；判断为应用启动失败，不是端口映射失败。
- 该环境为 CentOS 7、内核 `3.10`、Docker `26.1.4`，改用固定版本 `nginx:1.24-alpine` 后正常。
- 成功状态：容器 `Up`，端口映射 `0.0.0.0:18080->80/tcp`，`curl -I http://127.0.0.1:18080` 返回 `HTTP/1.1 200 OK`。
- 已停止并删除 `practice-nginx`，并删除 `nginx:1.24-alpine` 镜像。
- 本节不要重做。下一步学习 Dockerfile，再进入 Compose。

## 当前下一步（最新）

1. 学习 Dockerfile 基础，制作并运行一个简单自定义镜像。
2. 再进入 Docker Compose。

## 2026-09-15 Dockerfile 自定义镜像完成

- 已在 `~/dockerfile-practice` 创建 `Dockerfile` 和 `index.html`，基于 `nginx:1.24-alpine` 构建自定义镜像。
- Dockerfile 使用 `FROM`、`COPY`、`EXPOSE`、`CMD`；已区分 `COPY` 构建时复制文件和 `CMD` 运行时默认命令。
- 第一次 `docker build` 少了构建上下文 `.`，报 `requires exactly 1 argument`；改为 `sudo docker build -t practice-nginx-image:1.0 .` 后构建成功。
- 已运行自定义镜像并映射 `18081:80`，`curl` 能读回自定义页面 `Dockerfile build success`。
- 已停止并删除 `practice-nginx-image` 容器，删除 `practice-nginx-image:1.0` 镜像，最终 `docker images` 为空。
- `sudo docker image` 单独执行显示帮助是正常现象，查看列表应使用 `docker images`。
- `~/dockerfile-practice` 源文件目录保留。本节不要重做。下一步进入 Docker Compose。

## 当前下一步（最新）

1. 进入 Docker Compose，编写并运行一个简单多容器编排。

## 2026-09-15 Docker Compose 编排完成

- 已在 `~/compose-practice` 创建 `index.html` 和 `docker-compose.yml`，定义 `web` 与 `cache` 两个服务。
- `web` 使用 `nginx:1.24-alpine`，映射 `18082:80`，只读挂载自定义首页；`cache` 使用 `redis:7.2-alpine`，不暴露宿主机端口。
- `docker compose config` 解析出项目名 `compose-practice`、默认网络 `compose-practice_default` 和 `depends_on` 启动顺序。
- `docker compose up -d` 成功创建默认网络并启动 `practice-compose-cache`、`practice-compose-web`，两个服务均为 `Up`。
- Web 验证：`curl -I` 返回 `HTTP/1.1 200 OK`，页面返回 `Docker Compose success`。
- Cache 验证：Redis `PING` 返回 `PONG`，`SET` 返回 `OK`，`GET compose:practice` 返回 `"ok"`。
- 第一次 `GET` 命令多传了 `ok` 参数导致 `wrong number of arguments`，去掉多余参数后验证成功。
- Redis 容器日志提示容器网络命名空间内 `somaxconn=128`，与宿主机正式 Redis 的 `1024` 不同；不影响本节基础验证，未调整。
- `docker compose down` 已删除两个容器和默认网络，`nginx:1.24-alpine`、`redis:7.2-alpine` 镜像也已删除，最终 `docker images` 为空。
- `~/compose-practice` 源文件目录保留。本节不要重做。下一步提交 Docker/Compose 阶段记录。

## 当前下一步（最新）

1. 检查并提交 Docker/Compose 阶段学习记录。
2. 推送到远程仓库后，再规划下一阶段学习内容。

## 2026-09-16 Ansible 安装与 Inventory 完成

- 已通过 EPEL 在 CentOS 7 上安装 Ansible `2.9.27`，控制端 Python 为 `2.7.5`。
- 在 `/root` 执行 `ansible localhost -m ping` 曾出现 `Permission denied: '.'`；切换到 `/home/atguigu` 后成功返回 `pong`，确认是目录权限问题。
- 已创建 `~/ansible-practice/inventory.ini`，定义 `[local]` 组，包含 `localhost ansible_connection=local`。
- `ansible-inventory -i inventory.ini --list` 解析出 `local` 组和 `ansible_connection=local`。
- `ansible local -i inventory.ini -m ping` 返回 `pong`。
- `setup` 模块筛选 `ansible_distribution*`，识别系统为 CentOS 7.9。
- 本节不要重做。下一步学习 Ansible Ad-hoc 命令。

## 当前下一步（最新）

1. 学习 Ansible Ad-hoc 命令。
2. 再学习 Playbook、变量、模板、handlers 和幂等性。

## 2026-09-16 Ansible Ad-hoc 命令完成

- 已验证 `command` 模块执行 `pwd` 和 `cat`，能读回 `/home/atguigu/ansible-practice` 和 `ansible adhoc ok`。
- 已验证 `file` 模块创建 `/home/atguigu/ansible-practice/adhoc` 目录，权限 `0755`；第一次 `changed=true`，第二次 `changed=false`，幂等性验证通过。
- 已验证 `copy` 模块写入 `hello.txt`，权限 `0644`，内容 `ansible adhoc ok`；第一次 `changed=true`，第二次 `changed=false`，幂等性验证通过。
- 已验证 `stat` 模块确认文件存在、为普通文件、权限为 `0644`。
- 已用 `file` 模块 `state=absent` 删除练习目录，并用 `stat` 确认 `exists=false`。
- 本节不要重做。下一步学习 Playbook、变量、模板、handlers 和幂等性。

## 当前下一步（最新）

1. 学习 Ansible Playbook 基础。
2. 再学习变量、模板、handlers 和幂等性。

## 2026-09-16 Ansible Playbook 基础完成

- 已创建 `~/ansible-practice/site.yml`，使用 `hosts: local`、`connection: local`、`vars` 和 4 个任务。
- Playbook 任务包括：创建目录、写入文件、读取文件、输出内容。
- `ansible-playbook -i inventory.ini site.yml --syntax-check` 通过，输出 `playbook: site.yml`。
- 第一次执行结果：`ok=4 changed=2`，目录和文件被创建，`debug` 输出 `ansible playbook ok`。
- 第二次执行结果：`ok=4 changed=0`，证明 Playbook 幂等性正常。
- `stat` 验证 `hello.txt` 存在、为普通文件、权限 `0644`、大小 20 字节。
- 已用 `file` 模块删除 `playbook-demo` 目录，并用 `stat` 确认 `exists=false`。
- 本节不要重做。下一步学习变量、模板和 handlers。

## 当前下一步（最新）

1. 把 handler 换成真实服务：用 `systemd` 模块在配置变化时 reload/restart Nginx，并验证「配置没变就不重启」。
2. 再学多主机部署、错误处理和幂等性强化。
3. 最后完成一键部署 Nginx 和基础配置的 playbook。

## 2026-09-16 Ansible 变量与模板完成

- 变量来源与优先级已验证：inventory 主机变量 / playbook `vars` / facts 与 `register` / 命令行 `-e`，优先级为 inventory/facts -> `vars` -> `-e`。
- 未定义变量会硬失败：`ansible local -i inventory.ini -m debug -a "msg={{ app_port }}"` 返回 `FAILED!` 和 `'app_port' is undefined`；加 `-e "app_port=18090"` 后返回 `18090`。
- 已创建 `~/ansible-practice/templates/app.conf.j2` 和 `~/ansible-practice/vars-template.yml`，两个文件保留，作为后续模板与 handlers 的基础。
- `--syntax-check` 通过；第一次执行 `ok=4 changed=2`（建目录 + 渲染模板）；`cat template-demo/app.conf` 读到渲染后的三行配置；第二次执行 `ok=4 changed=0`，模板幂等性验证通过。
- 变量覆盖验证：加 `-e "app_port=18091"` 后第一次 `ok=4 changed=1` 且 `debug` 显示 `app_port=18091`，第二次同参数 `ok=4 changed=0`。
- 已知边界：`--syntax-check` 不校验 Jinja2 模板内容；`debug: var=` 把换行显示成 `\n`；模板相对路径和 `-i` 都依赖当前目录，须先 `cd ~/ansible-practice`。
- `template-demo` 是本节练习产物，收尾时用 `file` 模块 `state=absent` 删除。
- 本节不要重做。下一步学习 handlers。

## 2026-09-17 Ansible handlers 完成

- handler 机制已实测：任务报 `changed` 且写了 `notify` 才入队；handler 在所有 task 结束后执行；无变更时完全不出现 `RUNNING HANDLER`。
- 三次执行结果：第一次 `ok=4 changed=3`（建目录 + 渲染 + handler），无改动第二次 `ok=3 changed=0`，`-e app_port=18092` 第三次 `ok=4 changed=2`。
- 排查并定位了一个真实 bug：handler 用 `command` 模块写 `>>` 重定向时，任务报 `changed` 但文件不生成。对照实验证明 `command` 不经过 shell，`>>` 被当成普通参数；`shell` 模块才会真正重定向（`redir-shell.txt` 12 字节生成）。
- 修复方式：`sed -i 's/command:/shell:/' handlers-demo.yml`，随后复验通过——修复后 `handler.log` 出现第 1 行，无改动再跑 `changed=0` 且无 handler，`-e app_port=18091` 再触发后追加到 2 行。
- 重要结论：`changed` 只表示任务执行过了，不证明副作用真的发生；判断 handler 是否执行要看有没有 `RUNNING HANDLER` 段落。
- 生产写法应使用模块而非 shell 重定向，例如 `systemd: name=nginx state=reloaded`；这是下一节要做的。
- 保留下一步要复用的文件：`handlers-demo.yml`、`templates/app.conf.j2`、`handlers-demo/`；练习残留 `redir-shell.txt` 可清理。
- 本节不要重做。下一步：真实服务重启（Nginx reload）。

## 2026-09-17 handler 对接真实服务（Nginx reload）完成

- 已创建 `templates/ops-handler-demo.conf.j2`（渲染 `listen 127.0.0.1:{{ nginx_demo_port }}` 与 `return 200 "handler demo ok, version={{ demo_version }}"`）和 `handlers-nginx.yml`（`become: true`；template + `notify: reload nginx`、`command: /usr/sbin/nginx -t` 配 `register` 和 `changed_when: false`、debug；handler 用 `systemd: name=nginx state=reloaded`）。
- 执行必须带 `-K`（`--ask-become-pass`），本机 `sudo` 对 `atguigu` 需要密码，提示 `BECOME password:` 且输入不回显。不要把密码写进任何记录。
- 首次执行 `ok=4 changed=2`，`RUNNING HANDLER` 出现、`nginx -t` 通过，但服务不生效：18099 无监听、`curl` 拒绝连接、worker PID 未变。
- 根因是 SELinux 未放行 18099：`/var/log/nginx/error.log` 有 `bind() to 127.0.0.1:18099 failed (13: Permission denied)`；`sudo semanage port -l | grep http_port_t` 显示白名单为 `80, 81, 443, 488, 8008, 8009, 8443, 9000`；audit 日志有 `avc: denied { name_bind } ... tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0`。
- 对照实验：`-e "nginx_demo_port=8008"`（白名单内端口）立即可用，master 仍 1314、worker 换为 8809/8810/8812/8813 → 唯一变量是端口，同时证明走的是 reload 而非 restart。
- 修复：`sudo semanage port -a -t http_port_t -p tcp 18099`，白名单变为 `18099, 80, 81, 443, 488, 8008, 8009, 8443, 9000`；不带 `-e` 重跑后 18099 正常监听、`curl` 返回 `handler demo ok, version=1`，master 仍 1314、worker 换为 9088/9089/9090/9091。
- 关键结论：`changed` 不证明副作用发生（本阶段第三次验证）；配置不生效的排查顺序是「服务错误日志 → 内核 AVC 记录 → 策略清单」；SELinux 管的是标签不是权限；master PID 不变 + worker 全换 = reload。
- 收尾已完成（2026-09-17）：`file` 模块删除 `/etc/nginx/conf.d/ops-handler-demo.conf`（changed=true）→ `systemd` 模块 reload（changed=true，MainPID 仍 1314，ExecReload 显示 `/usr/sbin/nginx -s reload`）→ 验证 18099 不再监听、curl 拒绝连接、worker 换为 9563-9566。`handlers-demo/` 已删除（changed=true）；`redir-shell.txt` 返回 changed=false（此前已不存在）。
- `sudo semanage port -d -t http_port_t -p tcp 18099` 已执行（无输出），18099 恢复为 `unreserved_port_t`，环境回到最初状态；按默认变量重跑 `handlers-nginx.yml` 会再次被 SELinux 拒绝（未实测）。
- 保留资产：`inventory.ini`、`site.yml`、`vars-template.yml`、`handlers-nginx.yml`、`templates/app.conf.j2`、`templates/ops-handler-demo.conf.j2`。
- 唯一未单独复验项：18099 路径的「无改动重跑 changed=0」；同一 playbook 在 8008 下已实测 `ok=3 changed=0` 且无 RUNNING HANDLER。
- 本节不要重做。

## 2026-09-17 补充：handler playbook 加自检（meta: flush_handlers + wait_for）

- `handlers-nginx.yml` 已升级：在 `nginx -t` 之后加 `meta: flush_handlers`，再加 `wait_for`（`host: 127.0.0.1`、`port: {{ nginx_demo_port }}`、`state: started`、`timeout: 5`）验证端口真的在监听。
- 实测默认 18099：`ok=4 changed=2 failed=1`，`RUNNING HANDLER` 出现在输出中间（`flush_handlers` 生效的可视化签名），`wait_for` 报 `Timeout when waiting for 127.0.0.1:18099` → 自动复现了之前的 SELinux 拒绑故障。
- 实测 `-e nginx_demo_port=8008`：`ok=5 changed=2 failed=0`，`ss` 显示 `LISTEN 127.0.0.1:8008`，`curl` 返回 `handler demo ok, version=1`，master 仍 1314、worker 换为 12412-12415。
- 核心结论：两次 `changed` 完全相同（2），只有 `failed` 不同（1 → 0）。`changed` 表示「做了动作」，`failed` 表示「结果对不对」。
- 残留已清理（2026-09-17）：删除 `/etc/nginx/conf.d/ops-handler-demo.conf`（changed=true）并 reload（changed=true，MainPID 仍 1314）；`ss` 确认 8008 与 18099 都不再监听，worker 换为 12616-12619。
- 已决定端口约定：练习统一用白名单内的 8008；18099 保持被 SELinux 拦截，作为「可复现的故障演练场」，供下一节 `block/rescue` 使用。不要执行 `semanage port -a` 放行 18099。

## 当前下一步（最新）

## 2026-09-17 block 与 rescue 错误处理完成

- 先确认「没有 rescue」的后果：默认 18099 重跑后 `ok=4 changed=2 failed=1 rescued=0`，`/etc/nginx/conf.d/ops-handler-demo.conf`（204 字节）仍留在磁盘上；worker 12616-12619 一个未换，说明 nginx 绑定失败时会放弃新配置、继续用旧配置跑。
- `handlers-nginx.yml` 已改写为 `block`（template + notify、`nginx -t`、debug、`meta: flush_handlers`、`wait_for`）+ `rescue`（`file` 删除 conf、`systemd` reload、`fail` 重新抛错）。
- 实测失败路径：`ok=5 changed=2 failed=1 rescued=1`。`Render` 本轮是 `ok` 而非 `changed`（上一轮残留文件内容与本次渲染完全相同，checksum 命中），因此**没有 RUNNING HANDLER**；但 `wait_for` 仍然失败并触发 rescue，因为它检查的是「端口在不在监听」这一持续状态。
- 回滚后现场干净：conf 文件已不存在、nginx `active`、18099 无监听、worker 换为 13290-13293。
- 关键结论：**handler 对本轮变更负责，`wait_for` 对最终状态负责**；失败处理三步是「清理磁盘 → 回退运行状态 → 明确报红（`fail:`）」；「已回滚」≠「部署成功」。
- 预估纠正：先前按「文件会被重写」预计 `ok=6 changed=4`，实际为 `ok=5 changed=2`。

## 2026-09-17 block/rescue 对照组与本节收尾（已完成）

- 成功路径对照：`-e nginx_demo_port=8008` 实测 `ok=5 changed=2 failed=0 rescued=0`，`RUNNING HANDLER` 出现在中间，`Verify` 通过；`ss` 显示 `LISTEN 127.0.0.1:8008`，`curl` 返回 `handler demo ok, version=1`，master 1314、worker 13472-13475。失败路径 `rescued=1`、成功路径 `rescued=0`，rescue 只在需要时介入。
- 同一份代码，`Render` 在失败路径报 `ok`、在成功路径报 `changed`，差别来自「当前状态与目标状态的差异」，不是代码本身。
- 残留已清理：删除 `/etc/nginx/conf.d/ops-handler-demo.conf`（changed=true）+ reload（MainPID 仍 1314）；`ss` 确认 8008 与 18099 均不再监听，nginx `active`，worker 换为 13631-13634。
- 当前环境状态：nginx 只保留原有 80 端口服务；18099 的 SELinux 标签保持**撤销**状态（未放行），作为可复现的故障演练场。

## 当前下一步（最新）

## 2026-09-18 免密 SSH 与多主机（已完成）

- 免密 SSH 已配置：`ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa` → `cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys` → `chmod 600`。`ssh -o BatchMode=yes localhost 'hostname; whoami'` 返回 `centos100` / `atguigu`，退出码 0。
- 主机指纹已预热：`ssh -o StrictHostKeyChecking=no 127.0.0.1 ...`（`localhost` 与 `127.0.0.1` 在 known_hosts 里是两个条目，Ansible 首次连 `127.0.0.1` 会卡在指纹确认）。
- 新建 `inventory-multi.ini`：`[local]`（localhost，`ansible_connection=local`）、`[ssh_nodes]`（centos100，`ansible_host=127.0.0.1`、`ansible_user=atguigu`）、`[practice:children]` 组嵌套、`[practice:vars] practice_root=.../multi-demo`。
- 新建 `multi-host.yml`：`hosts: practice`、`gather_facts: true`、按 `{{ inventory_hostname }}` 分别建目录和写 `info.txt`、两个用 `when: inventory_hostname in groups['...']` 分支的任务。
- 实测：`--list-hosts` 两台；执行后两台各 `ok=6 changed=2 skipped=1`；`Gathering Facts` 成为独立任务。
- 关键观察：`inventory_hostname` 两台不同（localhost / centos100），但 `ansible_hostname` 都是 `centos100` → 同一台机器两个身份；两台 facts 完全相同，能区分的只有 inventory 与变量。
- `--limit centos100`：`--list-hosts` 只列 1 台，执行后 RECAP 只有 centos100，`ok=6 changed=0 skipped=1`。`--limit` 只缩范围、不改变 `when` 判断。
- 新增文件：`inventory-multi.ini`、`multi-host.yml`、`multi-demo/localhost/`、`multi-demo/centos100/`（练习产物，收尾时清理）。

## 当前下一步（最新）

1. 补做产物验证：`cat multi-demo/*/info.txt` 确认两台内容差异符合预期。
2. 最终完成「一键部署 Nginx 及基础配置」的完整 playbook。
## 2026-09-18 一键部署 Nginx 完整 playbook 与 SELinux 标签加固（已完成）

- 新增 `inventory-prod.ini`、`templates/index.html.j2`、`templates/nginx-site.conf.j2`、`nginx-deploy.yml`（完整代码见 `学习总结/ops_ansible_basics.md` 第十节）。
- 关键设计：`site_port` 只写在 inventory 主机变量（playbook `vars` 会覆盖 inventory 主机变量）；`serial: 1` 实现滚动更新（输出出现两次 PLAY）；`block` 内 `template`+notify → `meta: flush_handlers` → `uri` + `failed_when: site_name not in site_resp.content` 自检；`rescue` 三步删 conf → reload → `fail`。
- 实测：首跑两台各 `ok=9 changed=4`；幂等复跑两台各 `ok=8 changed=0` 且无 handler；`chcon -t var_t` 破坏后 `--limit localhost` 得 `ok=8 changed=1` 并自愈；删目录+conf 后 `--limit centos100` 得 `ok=9 changed=4`，新目录一出生即 `httpd_sys_content_t`，8009 返回 200。
- SELinux 定案：`copy`/`template` 会自动套策略默认标签，`file` 模块（目录/文件）都不会自动套；`file` 必须显式 `setype: httpd_sys_content_t`。修复既有偏差用 `restorecon -Rv`（策略已有 `/var/www(/.*)?` 规则，无需 `semanage fcontext`）；`chcon` 只是临时的。
- 环境最终状态：nginx master 仍 1314；`127.0.0.1:8008` 与 `127.0.0.1:8009` 各返回 200；`/var/www/ops-demo-*` 与 `/etc/nginx/conf.d/ops-demo-*.conf` 保留；`18099` 仍被 SELinux 拦截（`http_port_t` 白名单未加）；`multi-demo/` 已删除；`/var/www` 自身 `var_t` 属机器基线偏差，未动。

## 当前下一步（最新）

1. 本轮记录已写入 `学习总结/ops_ansible_basics.md`（第十节）、`项目记录/memory.md`、`项目记录/ops_handoff.md`、`项目记录/ops_command_history.md` 与 `README.md`，等待用户提交（PowerShell + 代理）。
2. Ansible 阶段主线结束。可选方向：Roles 与 `ansible-galaxy`、Ansible Vault、动态 inventory、`ansible-lint`/CI、在第二台真实节点上验证滚动发布。
3. `README.md` 末尾「下一步：只读检查 `/var/lib/redis-noeviction-20260914` …」是 Redis 阶段的历史停点、已经过时，是否清理由用户决定。
