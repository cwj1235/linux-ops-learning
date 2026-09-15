# Redis 基础运维学习笔记

更新日期：2026-09-14。保留本项目会话“继续”中 2026-09-12 19:45～20:53（北京时间）的历史补档；本次根据用户连续回传，统一归档备份比对、9 月 13 日 23:45 的正常重启、数据读回及加载日志。助手未代替用户连接虚拟机执行命令。

当前小节：RDB 查询、手动保存、快照复制与比对、AOF 在线启用、配置持久化、重启恢复及指定 RDB 备份隔离回灌均已验证。RDB 备份为 `dump.rdb.before-restart-20260913-183303`，练习键 `practice:rdb-check` 仍保留；AOF 练习键 `practice:aof-check` 重启后读到 `aof-ok`。三条启动警告已只读核实为 somaxconn=128、overcommit_memory=0、THP=always；内存基线及 128 MiB 运行时上限设置已验证，配置已备份且文件第 537 行已写入该值；17:10:21 服务重启后已直接读回 134217728，加载验收通过；超限行为、断电恢复和性能调优仍未完成。 本任务又完成隔离实例具体键值读回及关闭验证：`6380` 连接被拒绝、正式 `6379` 返回 `PONG`；临时文件与目录也已安全清理，ls 已确认目录不存在。

## 一、在学习路线中的位置

当前属于阶段 3：服务运维深化。

前面已经学习 Linux 服务、端口、日志、Nginx、MariaDB、Shell 巡检、Git 与 Python 基础脚本。Redis 继续沿用“概念 → 少量命令 → 用户执行 → 解释真实输出 → 总结”的节奏，不重复已完成的安装或 Python 归档。

Redis 是主要在内存中操作数据的键值数据库，常用于缓存、登录会话、计数器和简单任务队列，也支持持久化。它不等于 Web 服务器，也不意味着数据一定可以丢弃。

与已有服务的关系：

- Nginx：接收 HTTP 请求、反向代理。
- 后端程序：处理业务逻辑，可以按需访问 MariaDB 或 Redis。
- MariaDB：关系型数据库，适合有结构、事务需求的业务数据。
- Redis：提供快速的键值与数据结构操作，常用于缓存或临时状态。

上述关系是架构讲解；当前 `backend-demo` 尚未实际接入 Redis，不能记为已经完成联合部署。

## 二、已经验证的环境

| 项目 | 历史实测结果 |
|---|---|
| 实验系统 | VMware 中的 CentOS 7，主机名 `centos100` |
| 普通用户 | `atguigu` |
| Redis 软件包 | `redis-3.2.12-2.el7.x86_64`，来源 EPEL |
| 同时安装的依赖 | `jemalloc-3.6.0-1.el7.x86_64` |
| systemd 服务名 | `redis` |
| 服务端进程 | `redis-server` |
| 命令行客户端 | `redis-cli` |
| 服务状态 | `active (running)` |
| 开机自启 | `enabled` |
| 监听地址 | `127.0.0.1:6379` |
| 应用响应 | `redis-cli ping` 返回 `PONG` |

上表来自 9 月 12 日的初始核验。9 月 13 日用 `ss` 确认进程 `1207` 监听 `127.0.0.1:6379`；后来正常重启，status 又确认 active/enabled，主进程变为 `3047`，启动时间为 `2026-09-13 23:45:36 CST`。重启后没有重新执行 ss 或 PING，不把历史检查当作未来状态保证。CentOS 7 与 Redis 3.2 均属于旧版本实验环境，不直接暴露到公网；当前没有为了练习开放 Redis 的远程访问。9 月 15 日已补充验证：`noeviction` 超限拒写、`allkeys-lru` 自动淘汰、`volatile-lru` 只淘汰带 TTL key。

## 后续计划

1. 评估 `net.core.somaxconn`
2. 评估 `vm.overcommit_memory`
3. 评估 THP
4. 整理 Redis 巡检手册
5. 之后进入 Docker/Compose

9 月 13 日已核对配置文件路径、`bind/port/logfile` 的运行值与文件内容，读取日志并查询保护模式。随后完成 RDB 规则查询、文件检查、手动保存、复制备份和重启前内容比对；9 月 14 日又完成 AOF 配置核对、在线启用、配置文件持久化、写入测试和重启恢复，并在临时端口 `6380` 隔离加载指定 RDB 备份，确认其中 2 个键实际读回。随后核对内存基线并验证 128 MiB 运行时上限；上限也已写入配置文件并备份；服务重启后上限已读回确认。noeviction、allkeys-lru 与 volatile-lru 的超限行为也已用 6381 隔离实例验证；断电恢复与内核参数调优仍未验证。

## 三、安装和服务管理

实际先后执行过：

```bash
rpm -qa | grep -i '^redis'
yum info redis
sudo yum install -y redis
```

- `rpm -qa`：`-q` 表示查询，`-a` 表示全部，查看已安装的软件包。
- `grep -i '^redis'`：忽略大小写，筛选以 `redis` 开头的行；`^` 表示行首。
- `yum info redis`：查看软件源提供的包信息，不等于已经安装。
- `yum install -y redis`：安装软件，`-y` 自动确认；`sudo` 用于取得管理员权限。

最初曾把 `-qa` 写成 `_qa`，导致显示 RPM 用法。修正后无匹配包；服务单元不存在、6379 无监听。随后安装成功，不能继续用安装前的结果判断当前进度。

实际服务操作：

```bash
sudo systemctl start redis
systemctl status redis --no-pager
sudo systemctl enable redis
```

- `start`：启动当前服务，不自动设置开机自启。
- `status`：查看服务状态；`--no-pager` 不进入分页器。
- `enable`：设置开机自启，不等于启动当前服务。

用户安装后先看到 `inactive (dead)` / `disabled`，启动后看到 `active (running)`，设置自启后 `status` 显示 `enabled`。实际执行 `systemctl is-active redis` 返回 `active`。

`systemctl is-enabled redis` 曾被建议执行，但没有收到这条命令的输出；开机自启的结论来自用户实际返回的 `status` 和创建符号链接结果。

## 四、端口和客户端

已执行：

```bash
sudo ss -lntp | grep ':6379'
redis-cli ping
```

`ss` 的 `-l` 查看监听，`-n` 显示数字地址/端口，`-t` 筛选 TCP，`-p` 显示进程。实际找到 `redis-server` 监听 `127.0.0.1:6379`，随后收到 `PONG`。

`redis-server` 是服务端，`redis-cli` 是客户端。默认执行 `redis-cli ping`，会向本机 Redis 发送 `PING`。监听 `127.0.0.1` 表示此监听入口只接受本机连接，不要误以为 Windows 上的 `127.0.0.1` 是这台虚拟机。

## 五、String：写入、读取、删除

已执行并验证：

```bash
redis-cli SET app:status healthy
redis-cli GET app:status
redis-cli DEL app:status
```

结果依次为 `OK`、`"healthy"`、`(integer) 1`。随后再次执行 `GET app:status`，返回 `(nil)`。

- `SET key value`：保存键值。
- `GET key`：读取值，键不存在时返回空值，客户端显示 `(nil)`。
- `DEL key`：删除整个键，返回本次实际删除的键数量。
- `app:status` 是键名，冒号只是常见命名习惯，不是目录层级。

## 六、过期时间：EX 和 TTL

已执行：

```bash
redis-cli SET app:cache "temporary-data" EX 30
redis-cli TTL app:cache
redis-cli GET app:cache
```

实际结果是 `OK`、`(integer) 16`，再读取时为 `(nil)`，说明读取前键已经过期。

- `EX 30`：`SET` 的选项，为键设置 30 秒有效期，不是独立命令。
- `TTL`：Time To Live，查看键的剩余有效秒数；并不要求刚查时一定是 29 秒。
- `TTL` 的 `-1` 表示键存在但未设置过期，`-2` 表示键不存在。这两个特殊值已讲解，尚未单独实操验证。

## 七、计数器

已执行的起始实验：

```bash
redis-cli SET page:views 0
redis-cli INCR page:views
redis-cli GET page:views
```

实际返回 `OK`、`(integer) 1`、`"1"`。

后续实际执行：

```bash
redis-cli INCRBY page:views 5
redis-cli DECR page:views
redis-cli GET page:views
```

实际结果是 `7`、`6`、`"6"`，不是此前按旧值预测的 `5`。这说明 `INCRBY` 执行前保存的值是 `2`；不能据此断言用户额外执行了哪一条没有贴出的命令。

- `INCR`：increment，每次增加 1。
- `INCRBY key amount`：按指定数值增加。
- `DECR`：decrement，每次减少 1。

随后用户执行 `DEL page:views` 返回 `1`，再 `GET page:views` 返回 `(nil)`，测试键已清理。

## 八、Hash：保存一组相关字段

9 月 12 日创建练习 Hash 时已执行并验证：

```bash
redis-cli HSET server:centos100 ip 192.168.6.100
redis-cli HSET server:centos100 role all-in-one
redis-cli HGETALL server:centos100
```

两次 `HSET` 都返回 `(integer) 1`，表示各新增一个字段。`HGETALL` 返回以下字段与值：

```text
ip   -> 192.168.6.100
role -> all-in-one
```

- `server:centos100`：整个 Hash 的键名。
- `ip`、`role`：Hash 内部的字段。
- `HSET key field value`：写入一个字段和值。本实验使用 Redis 3.2 兼容的单字段写法，不照搬新版本的多字段 `HSET` 示例。
- `HGETALL key`：读取全部字段和值，展示顺序不应当作为业务依赖。

### 2026-09-13 单字段读取与删除验证

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli HGET server:centos100 ip` | 返回字符串 `192.168.6.100` |
| `redis-cli HGET server:centos100 role` | 返回字符串 `all-in-one` |
| `redis-cli HGETALL server:centos100` | 显示 `ip`、`role` 两个字段及对应值 |
| `redis-cli HDET server:centos100 role` | `(error) ERR unknown command 'HDET'` |
| `redis-cli HDEL server:centos100 role` | `(integer) 1` |
| 再次 `redis-cli HGETALL server:centos100` | 仅剩 `ip=192.168.6.100` |

- `HGET key field`：读取指定 Hash 中一个字段的值。
- `HDET`：拼写错误，不是有效 Redis 命令，因此此次调用被拒绝，没有删除字段；用户已经自行改为 `HDEL`。
- `HDEL key field`：删除指定字段，返回本次实际删除的字段数量；这里的 `1` 表示成功删除了 1 个字段，不是字段值。
- 本次只删除了 `role`，`ip` 仍在，整个 `server:centos100` 键仍存在；`DEL key` 则删除整个键。
- 补充概念（本次未演练）：如果删除 Hash 的最后一个字段，Redis 会同时移除这个空 Hash 键。

### 2026-09-13 键与字段存在性验证

业务读取不到数据时，要区分“整个键不存在”和“Hash 中某个字段不存在”。前面 `HGET` 查看值，这次学习检查对象是否存在：

```bash
redis-cli EXISTS server:centos100
redis-cli HEXISTS server:centos100 role
```

- `EXISTS key`：检查整个键是否存在，此处键名是 `server:centos100`。
- `HEXISTS key field`：检查 Hash 中指定字段是否存在，此处字段名是 `role`。
- 这里都是单对象检查，返回 `1` 表示存在、`0` 表示不存在；不等同于 `HDEL` 返回删除数量。

用户实际执行后，`EXISTS server:centos100` 返回 `(integer) 1`，`HEXISTS server:centos100 role` 返回 `(integer) 0`。这证明整个键还在，但 `role` 字段不存在，与前面的删除结果一致。

这里的 `0` 表示字段不存在，不是命令执行失败。这是 Redis 返回的数据，与之前 Shell/Python 学习中的 `$?` 退出状态不是同一概念。

### 2026-09-13 键类型与 Hash 字段数量验证

排查数据访问问题时，先确认键保存的类型，再选择对应的命令；检查 Hash 时还可以统计字段数量，而不必读取全部字段和值。

```bash
redis-cli TYPE server:centos100
redis-cli HLEN server:centos100
```

- `TYPE key`：查看键对应的数据类型，例如 String 或 Hash；命令后面跟键名。
- `HLEN key`：查看指定 Hash 中的字段数量，不是某个字段值的字符串长度，也不是整个数据库的键数量。

实际输出：`TYPE server:centos100` 返回 `hash`，`HLEN server:centos100` 返回 `(integer) 1`。这确认该键是 Hash，并包含 1 个字段，与此前仅保留 `ip` 的结果一致；本次并未重新读取字段值。

## 九、List：有顺序的列表（基础小节已验证）

Hash 按字段名保存相关信息；List 则在一个键中按顺序保存多个元素，可以从两端添加或取出。运维场景中，可以用它模拟简单的待巡检任务队列；这里仅保存服务名称，不会真的执行巡检或管理服务。

本小节使用练习键 `practice:checks`，没有操作已有的 `server:centos100`。首先执行：

```bash
redis-cli RPUSH practice:checks nginx mariadb
redis-cli LRANGE practice:checks 0 -1
```

- `RPUSH key element [element ...]`：向列表右端依次追加元素；这里保存 `nginx`、`mariadb` 两个字符串。返回追加后列表的总元素数，不是本次新增数量。
- `LRANGE key start stop`：读取指定索引范围的元素，包含开始和结束位置；索引从 `0` 开始，`-1` 代表最后一个元素，所以 `0 -1` 查看整个练习列表。
- `LPOP key`：从列表左端取出并返回一个元素，同时将该元素从列表删除，不是只读查看，也不会实际执行同名服务。
- `LLEN key`：查看列表元素数量，不是字符串字符数；对不存在的键返回 `0`。
- List 允许重复元素。再次执行 `RPUSH` 会继续追加，不能把它当作覆盖写入；本节仅解释了这个概念，没有单独实测重复追加。

### 本小节实际操作与输出

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli RPUSH practice:checks nginx mariadb` | `(integer) 2` |
| `redis-cli LRANGE practice:checks 0 -1` | 依次显示 `nginx`、`mariadb` |
| `redis-cli LPOP practice:checks` | 返回字符串 `nginx` |
| `redis-cli LRANGE practice:checks 0 -1` | 仅显示 `mariadb` |
| `redis-cli LLEN practice:checks` | `(integer) 1` |
| `redis-cli LPOP practice:checks` | 返回字符串 `mariadb` |
| `redis-cli LLEN practice:checks` | `(integer) 0` |
| `redis-cli EXISTS practice:checks` | `(integer) 0` |

### 小节结论

- `RPUSH` 右端加入、`LPOP` 左端取出，实现先进先出（FIFO）：先加入的 `nginx` 先被取出，随后取出 `mariadb`。
- 最后的 `LLEN = 0` 表示没有剩余元素，`EXISTS = 0` 进一步确认整个键已经不存在；这里的 `0` 不是命令执行失败。
- Redis 在列表最后一个元素被取出后自动删除该列表键，不保留空列表键。本次没有执行 `DEL`，也无需为了清理练习再删除其他键。
- 本次只是名称数据的入队、查看和出队练习，不是已经建成真实巡检任务系统；未验证的扩展功能不能写成完成。

一句话记住：右边加入、左边取出是先进先出；取走最后一个元素后，列表键自动消失。

## 十、Set：不重复的集合（基础小节已验证）

List 有顺序、允许重复；Set 中成员唯一，不保证按插入顺序展示，适合保存不重复的服务名称或主机 IP。这里的 Set 是数据类型，不是写入 String 的 `SET key value` 命令。

本节使用练习键 `practice:services`，只保存和删除服务名称，不实际操作服务。

### 命令用途与名称

- `SADD key member [member ...]`：添加成员，返回本次实际新增的成员数量，不是集合总数。
- `SMEMBERS key`：查看集合全部成员；不能依赖其输出顺序。
- `SCARD key`：查看成员总数。`S` 表示 Set，`CARD` 来自 cardinality，数学上叫基数，在这里就是集合成员数。
- `SISMEMBER key member`：检查指定成员是否存在，`1` 表示存在，`0` 表示不存在；不是检查服务是否安装或运行。
- `SREM key member [member ...]`：按成员值删除，返回本次实际删除的成员数量，不是剩余数量。`REM` 来自 remove，意思是移除。

### 本小节实际操作与输出

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli SADD practice:services nginx mariadb nginx` | `(integer) 2` |
| `redis-cli SMEMBERS practice:services` | 显示 `mariadb`、`nginx`，重复名称只保留一份 |
| `redis-cli SCARD practice:services` | `(integer) 2` |
| `redis-cli SISMEMBER practice:services nginx` | `(integer) 1` |
| `redis-cli SISMEMBER practice:services redis` | `(integer) 0` |
| `redis-cli SREM practice:services nginx` | `(integer) 1` |
| `redis-cli SISMEMBER practice:services nginx` | `(integer) 0` |
| `redis-cli SMEMBERS practice:services` | 仅显示 `mariadb` |
| `redis-cli SREM practice:services mariadb` | `(integer) 1` |
| `redis-cli SMEMBERS practice:services` | `(empty list or set)` |
| `redis-cli EXISTS practice:services` | `(integer) 0` |

### 小节结论

- 第一次传入三个名称，其中 `nginx` 重复，实际只新增两个成员，验证 Set 去重。
- `SCARD` 查成员总数，`SISMEMBER` 查指定成员是否存在，`SREM` 返回本次删除数量；这些整数回复不等同于 Shell 的 `$?` 退出码。
- 删除 `nginx` 后只剩 `mariadb`；删除最后的 `mariadb` 后，`SMEMBERS` 返回空结果，`EXISTS=0` 确认整个键已自动删除。
- `(empty list or set)` 是当前版本 `redis-cli` 对空集合类回复的通用显示，不是报错，也不是 Set 变成了 List。对不存在的 Set 键执行 `SMEMBERS` 同样会返回空结果。
- 最后用户使用 `SMEMBERS` 检查取空结果，没有回传取空后的 `SCARD` 输出，因此不将 `SCARD=0` 写成实操结果。
- 本节没有执行 `DEL`，也无需额外清理其他键；没有实际停止 Nginx 或 MariaDB 服务。

一句话记住：Set 存不重复的成员，不依赖输出顺序；最后一个成员被删除后，集合键自动消失。

## 十一、ZSet：按分数排序的集合（基础小节已验证）

ZSet（Sorted Set，有序集合）的成员唯一，每个成员关联一个分数，按分数排序。与普通 Set 不同，它可以按排序位置读取成员，适合排行榜等场景；更新已有成员的分数不会再添加一份同名成员。

本节使用 `practice:priority` 保存服务名称和练习分数，只验证数据操作，没有实际设置服务启动顺序或执行巡检任务。

### 命令用途与参数

- `ZADD key score member [score member ...]`：按“分数、成员”成对添加；成员已经存在时更新其分数。默认返回本次新增成员数，不是发生变化的成员数，也不是集合总数。
- `ZRANGE key start stop [WITHSCORES]`：按分数从小到大，读取指定索引范围内的成员。索引从 `0` 开始，结束位置包含在内，`-1` 表示最后一个位置；`0 -1` 表示全部成员，不是分数范围。
- `WITHSCORES`：同时显示分数，输出按“成员、分数”成对出现；本节六行结果对应三个成员，不是六个成员。
- `ZSCORE key member`：读取指定成员的分数。
- `ZCARD key`：查看成员总数；`CARD` 来自 cardinality（基数）。
- `ZREVRANGE key start stop [WITHSCORES]`：按分数从大到小读取指定索引范围；`REV` 来自 reverse（反向）。本节采用 Redis 3.2 支持的命令语法。
- `ZREM key member [member ...]`：按成员名称删除，可以一次指定多个成员；`REM` 来自 remove（移除），返回实际删除的成员数，不是剩余数量。

### 本小节实际操作与输出

范围查询的结果在下表按“成员 / 分数”简写，保留用户实际输出的顺序。

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli ZADD practice:priority 20 nginx 10 mariadb 30 redis` | `(integer) 3` |
| `redis-cli ZRANGE practice:priority 0 -1 WITHSCORES` | `mariadb / 10`、`nginx / 20`、`redis / 30` |
| `redis-cli ZADD practice:priority 5 nginx` | `(integer) 0` |
| `redis-cli ZSCORE practice:priority nginx` | `"5"` |
| `redis-cli ZRANGE practice:priority 0 -1 WITHSCORES` | `nginx / 5`、`mariadb / 10`、`redis / 30` |
| `redis-cli ZCARD practice:priority` | `(integer) 3` |
| `redis-cli ZREVRANGE practice:priority 0 -1 WITHSCORES` | `redis / 30`、`mariadb / 10`、`nginx / 5` |
| `redis-cli ZREM practice:priority nginx mariadb redis` | `(integer) 3` |
| `redis-cli ZCARD practice:priority` | `(integer) 0` |
| `redis-cli EXISTS practice:priority` | `(integer) 0` |

### 小节结论

- 首次 `ZADD` 新增三个成员；再次添加已有的 `nginx` 时返回 `0`，表示没有新增成员，不是操作失败。`ZSCORE` 返回 `"5"`，确认分数已从 `20` 改为 `5`。
- 更新分数后，`nginx` 在升序结果中排到最前；`ZCARD=3` 确认成员数没有增加。倒序查询实际显示 `redis(30) → mariadb(10) → nginx(5)`。
- 最后的 `ZREM=3` 表示本次实际删除三个成员，`ZCARD=0` 表示无剩余成员，`EXISTS=0` 进一步确认键已不存在；不是保留了一个空 ZSet 键。
- Redis 在 ZSet 最后一个成员被删除后自动删除该键。本节没有执行 `DEL`，也没有启动、停止或调整同名服务。

一句话记住：ZSet 成员不重复、按分数排序；更新分数不会新增成员，删空后键自动消失。

## 十二、配置、日志与本机监听（基础小节已验证）

本节把 Redis 与已有的 systemd、端口和日志知识串起来：先定位配置，再核对运行值与文件，最后查看日志和实际监听。全部是只读检查，没有修改配置、重启服务或开放端口。

### 1. 定位实际配置文件

```bash
systemctl cat redis --no-pager
redis-cli INFO server | grep '^config_file:'
```

- `systemctl cat` 显示服务单元及补充配置；`--no-pager` 直接输出，不进入分页界面。
- 服务单元为 `/usr/lib/systemd/system/redis.service`，`ExecStart=/usr/bin/redis-server /etc/redis.conf --supervised systemd`。Redis 的实际配置文件是 `/etc/redis.conf`，不是 systemd 的服务单元文件。
- `INFO server` 查询运行中的服务端信息；`grep '^config_file:'` 筛选以该字段名开头的行，实际返回 `config_file:/etc/redis.conf`，与启动命令指定路径一致。
- 服务单元声明 `Type=notify`、`User=redis`、`Group=redis`；`--supervised systemd` 配合通知机制。这里读到的是单元定义，不等于另外验证了进程实际身份。
- 补充配置 `/etc/systemd/system/redis.service.d/limit.conf` 声明 `LimitNOFILE=10240`。它是文件描述符上限设置，不是 Redis 最大客户端连接数；本轮未查询进程实际资源限制或 `maxclients`。

### 2. 对照运行值与磁盘文件

```bash
redis-cli CONFIG GET bind
redis-cli CONFIG GET port
redis-cli CONFIG GET logfile
sudo grep -nE '^[[:space:]]*(bind|port|logfile)[[:space:]]' /etc/redis.conf
```

`CONFIG GET 配置项` 只读查询当前运行值，返回配置项名称和对应值。`grep -nE` 用扩展正则筛选并显示行号；行首允许空白，匹配指定的未注释配置项，`|` 表示“或”。`sudo` 用于取得读取权限。

| 配置项 | 运行值 | 配置文件实际输出 |
|---|---|---|
| `bind` | `127.0.0.1` | `61:bind 127.0.0.1` |
| `port` | `6379` | `84:port 6379` |
| `logfile` | `/var/log/redis/redis.log` | `163:logfile /var/log/redis/redis.log` |

本次核对的三项一致，不代表已经检查全部配置。磁盘文件和运行值可能不同，不能只看文件就断言当前生效值。这里的本机指 CentOS 虚拟机，不是 Windows。

### 3. 日志中的 RDB 后台保存

```bash
sudo tail -n 20 /var/log/redis/redis.log
```

`tail -n 20` 读取日志末尾 20 行，不清空或修改日志。本次输出包含 9 月 13 日 `13:32:16`、`13:57:37`、`14:12:38`、`14:27:39` 四轮后台保存；每轮都有写盘成功和后台保存成功结束的记录。最后一轮为：

```text
1207:M 13 Sep 14:27:39.055 * 1 changes in 900 seconds. Saving...
1207:M 13 Sep 14:27:39.057 * Background saving started by pid 6082
6082:C 13 Sep 14:27:39.059 * DB saved on disk
6082:C 13 Sep 14:27:39.059 * RDB: 2 MB of memory used by copy-on-write
1207:M 13 Sep 14:27:39.157 * Background saving terminated with success
```

- RDB 可以先理解为把某一时刻的数据保存成磁盘快照。
- `1 changes in 900 seconds. Saving...` 表示触发“距上次保存约 900 秒、且至少有一次数据修改”的自动保存条件，不是无论是否修改数据都固定每 900 秒保存。随后通过 `CONFIG GET save` 查询了完整自动保存规则，见第十三节。
- `Background saving started by pid ...` 表示启动后台保存子进程；`DB saved on disk` 和 `Background saving terminated with success` 表示该次写盘和后台保存成功结束。
- `copy-on-write` 是写时复制；日志报告的 `2 MB` 或 `4 MB` 是相关内存用量，不是快照文件大小。
- 结论仅针对返回的这 20 行日志，不能据此断言全部历史日志都无错误。观察到保存成功，不等于快照文件位置、备份有效性或重启恢复已经验证。

### 4. 保护模式与实际监听

```bash
redis-cli CONFIG GET protected-mode
sudo ss -lntp | grep ':6379'
```

第一条返回 `protected-mode` / `yes`，确认运行中的保护模式开启；本节未核对该项在配置文件中的对应行。Redis 3.2 的保护模式在未显式配置绑定地址且未设置认证密码等条件下限制非本机访问，不能代替绑定限制、防火墙和认证，也不能由 `yes` 推断已经配置了密码。

第二条实际返回：

```text
LISTEN     0      128    127.0.0.1:6379                     *:*                   users:(("redis-server",pid=1207,fd=4))
```

- `ss` 查看套接字；`-l` 只看监听，`-n` 显示数字地址和端口，`-t` 筛选 TCP，`-p` 显示进程。`sudo` 用于读取完整进程信息，`grep` 筛选含 `:6379` 的行。
- `LISTEN` 表示监听状态，本地地址为 `127.0.0.1:6379`，与本次核对的 `bind`、`port` 一致。该监听入口绑定 IPv4 回环地址，不是虚拟机的所有网卡地址。
- 后面的 `*:*` 位于对端地址列，不表示 Redis 监听所有网卡；判断监听范围要看本地地址列。
- 进程为 `redis-server`，`pid=1207` 与日志主进程号一致；`fd=4` 是该进程的文件描述符编号，不是连接数。
- `0`、`128` 是监听队列相关信息，不是 Redis 当前客户端数和最大客户端数。系统实际资源限制、认证配置和外部连通性未作单独测试。

一句话记住：配置文件、运行值、实际监听和日志相互核对；保存成功与恢复成功是两回事。

## 十三、RDB 持久化（手动保存、备份核对与正常重启读回已验证）

本节从“日志里出现保存成功”推进到查询真实规则、手动保存、备份内容核对及正常重启读回。RDB 是某一时刻的数据快照，不是每次修改数据就立即更新一次快照文件。本节没有把备份文件复制回正式位置，也没有做断电实验。

### 1. 自动保存规则与文件位置

| 用户实际执行 | 实际返回值 |
|---|---|
| `redis-cli CONFIG GET save` | `900 1 300 10 60 10000` |
| `redis-cli CONFIG GET dir` | `/var/lib/redis` |
| `redis-cli CONFIG GET dbfilename` | `dump.rdb` |

这些是运行中的配置查询，没有修改配置，也不是执行保存。`save` 的值要分成三组理解：

| 规则 | 含义 |
|---|---|
| `900 1` | 距上次成功保存约 900 秒，且累计至少 1 次数据变更 |
| `300 10` | 距上次成功保存约 300 秒，且累计至少 10 次数据变更 |
| `60 10000` | 距上次成功保存约 60 秒，且累计至少 10000 次数据变更 |

每组内部是“并且”，三组之间是“或者”：满足任意一组，就具备触发自动保存的规则条件。变更次数不是必须修改这么多个不同的键，也不是没有变更还固定定时保存。前面日志的 `1 changes in 900 seconds` 对应第一组。

目录与文件名组合得到 `/var/lib/redis/dump.rdb`。配置给出路径，不等于文件已经存在，因此又实际执行了：

```bash
sudo ls -lh /var/lib/redis/dump.rdb
```

实际看到普通文件，权限显示为 `-rw-r--r--.`，属主和属组均为 `redis`，大小 `131` 字节，修改时间为 `9月 13 14:27`。`-l` 查看详细信息，`-h` 使用易读的大小单位；这里没有单位后缀的 `131` 表示字节，与日志中的写时复制内存大小不是一回事。

这次 `ls` 发生在 SET/BGSAVE 之前，只是当时的文件基线。后来重启前核对源文件和备份，二者均为 158 字节、修改时间 17:35；不能继续把 131 字节当作最新大小，也不能把重启前的核对当成重启后的复查。

### 2. 练习键与手动后台保存

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli SET practice:rdb-check rdb-ok` | `OK` |
| `redis-cli GRT practice:rdb-check` | `(error) ERR unknown command 'GRT'` |
| `redis-cli GET practice:rdb-check` | `"rdb-ok"` |
| `redis-cli BGSAVE` | `Background saving started` |
| `redis-cli INFO persistence` | 后台保存已结束，最近一次保存成功；关键字段见下表 |

- 练习键未在 SET 命令中设置过期时间，保留用于后续恢复验证；尚无删除该键的操作记录。
- `GRT` 是 `GET` 的拼写错误，改正后读到正确值，不影响已经写入的数据。这里的 GET 在 BGSAVE 之前，不是重启恢复后的读回结果。
- `BGSAVE` 的 `BG` 来自 background，表示后台保存。它为整个 Redis 实例的数据生成快照并更新 RDB 文件，不是只保存这个练习键。
- `Background saving started` 仅表示启动成功，必须再看完成状态；`INFO persistence` 查询持久化信息，不触发保存。

| 实际状态字段 | 本次结果与解释 |
|---|---|
| `loading` | `0`，当前没有正在加载数据；不代表已经做过恢复实验 |
| `rdb_changes_since_last_save` | `0`，当前没有尚未保存的数据变更 |
| `rdb_bgsave_in_progress` | `0`，没有后台保存任务正在进行 |
| `rdb_last_save_time` | `1789292105`，最近成功保存的 Unix 时间戳 |
| `rdb_last_bgsave_status` | `ok`，最近一次后台保存成功 |
| `rdb_last_bgsave_time_sec` | `0`，按整数秒记录的耗时，不表示没有执行 |
| `rdb_current_bgsave_time_sec` | `-1`，当前没有正在进行的后台保存任务 |
| `aof_enabled` | `0`，当前运行中的 AOF 没有开启 |

结合 BGSAVE 的启动回复和随后返回的完成状态，已确认本次手动后台保存完成且成功。不能仅凭 `aof_*:ok` 字段声称做过 AOF 保存或恢复；此表是手动保存后的状态，后续重启后的独立检查见第 6 小节。

### 3. cp 与 scp（概念已讲解，真实快照复制已验证）

- `cp` 来自 copy，用于当前系统能直接访问的路径之间的复制，不建立 SSH 连接。
- `scp` 来自 secure copy，主要通过 SSH 在不同主机间复制文件，需要 SSH 连通并完成认证，通常使用 22 端口，不是 Redis 的 6379 端口。
- 两者默认保留源文件；参数含义不完全相同，不能把 `cp -anv` 直接替换为 `scp -anv`。
- “本机”指执行命令的机器。在 Windows 通过终端登录 CentOS 后，CentOS 内的两个路径仍属于同一台机器；本次快照和备份都在 CentOS 内，应使用 cp。
- 对 `cp /home/atguigu/test.txt /home/atguigu/test.txt.bak` 和从 Windows 上传 `C:\Temp\test.txt` 的 scp 命令只做了语法演示，没有收到执行输出；不能记录为实际复制或上传成功，也不需要创建这些示例文件。

### 4. 快照复制与内容核对（已验证）

已执行的快照复制命令：

```bash
sudo cp -anv /var/lib/redis/dump.rdb "/var/lib/redis/dump.rdb.before-restart-$(date +%Y%m%d-%H%M%S)"
```

- `-a` 保留权限、属主和时间等属性，`-n` 不覆盖同名文件，`-v` 显示复制信息；`$(date ...)` 将时间加入备份文件名。
- 命令的目标是保留当前快照，不是删除原文件或重启 Redis；若目标文件已存在，`-n` 可能跳过复制，需要依据实际输出判断，不把无报错自动当作新备份完成。
- 另一条会话的用户回传已确认复制输出：`"/var/lib/redis/dump.rdb" -> "/var/lib/redis/dump.rdb.before-restart-20260913-183303"`。此前归档停在 cp 讲解，尚未纳入这次成功结果，本次复核补齐。
- 早期仅贴出的 cmp 命令不算执行；后来用户实际执行 `sudo ls -lh` 检查源文件和备份，二者均为 158 字节、属主/属组 `redis/redis`、修改时间 `9月 13 17:35`。`cp -a` 保留修改时间，不能把显示的 17:35 当作备份创建时间。
- 实际执行不带 `-s` 的 `sudo cmp` 后没有输出，紧接着 `echo $?` 返回 `0`，确认当时两个文件逐字节一致；大小相同本身不够，cmp 结果才是内容核对证据。
- cmp 的 0/1/2 分别表示一致/不同/出错。原先的 `&& echo ... || echo ...` 会把不同和出错混淆；整行结束后再查看 `$?`，通常得到的是最后一个 echo 的状态，不能当作 cmp 的退出码。
- 比对发生在下述重启之前。源快照可能随正常停止或自动保存更新，不能保证此后两个文件一直相同；不同也不直接等于备份损坏。练习键和备份尚未清理。

### 5. 正常重启与练习数据读回（已验证）

用户依次执行：

```bash
sudo systemctl restart redis
sudo systemctl status redis --no-pager -l
redis-cli GET practice:rdb-check
```

| 核验项 | 实际结果与解释 |
|---|---|
| 服务状态 | `active (running)`，启动时间 `2026-09-13 23:45:36 CST` |
| 当前主进程 | `3047 (redis-server)`，不是此前 ss 中的 1207 |
| 停止命令 | `ExecStop ... status=0/SUCCESS`，旧服务的停止命令成功，不是当前进程失败 |
| 开机自启 | `enabled`；`vendor preset: disabled` 是软件包默认策略，不抵消实际 enabled |
| 数据读回 | GET 返回 `"rdb-ok"`；重启后没有重新 SET，因此是原练习值的读回 |

`restart` 只重启 Redis 服务，不重启 CentOS；过程中 Redis 连接会短暂中断。`--no-pager` 不分页，`-l` 不截断长行。status 中的启动参数不是重新运行 ss 的监听验证。

### 6. 重启后的持久化状态与启动日志（已验证）

用户实际执行 `redis-cli INFO persistence` 和 `sudo tail -n 20 /var/log/redis/redis.log`。

| INFO 字段 | 重启后实际值与含义 |
|---|---|
| `loading` | `0`，当前没有正在加载数据；单独这一项不能证明加载成功 |
| `rdb_changes_since_last_save` | `0`，当前没有计入的未保存变更 |
| `rdb_bgsave_in_progress` | `0`，当前没有后台保存任务 |
| `rdb_last_save_time` | `1789314336`，本次报告的时间戳；新进程初始化也会设置该字段，不能单凭变化证明又执行了 BGSAVE |
| `rdb_last_bgsave_status` | `ok`；必须结合操作与日志解读，不能据此虚构新进程已执行过 BGSAVE |
| `rdb_last_bgsave_time_sec` | `-1`，新进程尚无可报告的后台保存耗时，不表示失败 |
| `rdb_current_bgsave_time_sec` | `-1`，当前没有后台保存任务 |
| `aof_enabled` | `0`，本次启动后 AOF 仍关闭；其他 aof 状态为 ok 也不代表做过 AOF 实验 |

本次启动的关键日志：

```text
3047:M 13 Sep 23:45:36.212 # Server started, Redis version 3.2.12
3047:M 13 Sep 23:45:36.212 * DB loaded from disk: 0.000 seconds
3047:M 13 Sep 23:45:36.212 * The server is now ready to accept connections on port 6379
```

`0.000 seconds` 是日志的耗时显示精度，不代表没有加载。结合 `aof_enabled=0`、磁盘加载日志和重启后的 GET，确认本次正常启动加载了 RDB，并读回练习数据。

日志同时出现三条 WARNING：

| 日志观察 | 风险与处理边界 |
|---|---|
| Redis 请求 TCP backlog=511，内核 somaxconn=128 | 连接突增时的等待队列容量受限，不是只能有 128 个客户端，也不说明当前队列已满 |
| overcommit_memory=0 | 内存紧张时，后台保存等 fork 操作可能失败；不代表本次保存或启动已经失败 |
| THP 开启 | 可能带来延迟波动和额外内存开销，需要结合环境评估 |

这些是启动时日志提示的配置状态，不是本次读取内核文件的结果。尚未修改 sysctl、THP 或开机配置；不直接照日志改整机参数。后续在内存与性能小节先核验实际配置，再说明影响和持久化方案。

### 7. 本小节结论与验证边界

已经完成“规则查询 → 手动保存 → 快照复制 → 内容核对 → 正常重启 → 练习值读回与加载日志”的基础验证。

正常停止 Redis 可能再次保存 RDB，因此不能据此证明 `dump.rdb.before-restart-20260913-183303` 已被实际用于恢复。指定备份回灌、宕机/断电恢复、所有键的完整性和性能调优仍未验证；备份与练习键继续保留。

一句话记住：文件存在、后台保存成功、备份成功和恢复成功是四个不同的验证点，不能互相替代。

## 十四、AOF 在线启用与重启恢复（已验证）

### 1. 配置查询与启用前检查

用户实际查询到：

```text
CONFIG GET appendonly -> no
CONFIG GET appendfilename -> (empty list or set)
CONFIG GET appendfsync -> everysec
```

旧版 Redis 3.2 的 `CONFIG GET appendfilename` 未返回匹配项，因此改查实际配置文件：

```text
/etc/redis.conf 第 597 行：appendfilename "appendonly.aof"
```

结合 `dir=/var/lib/redis`，预期文件路径为 `/var/lib/redis/appendonly.aof`。启用前检查确认该文件不存在；`df -h /var/lib/redis` 显示根分区容量 17G、已用 5.8G、可用 12G、使用率 34%。

配置备份已成功创建：

```text
/etc/redis.conf.before-aof-20260914-094538
```

### 2. 在线启用与 AOF 初始生成

```bash
redis-cli CONFIG SET appendonly yes
```

返回 `OK`，说明当前运行中的 Redis 已启用 AOF；这一步本身不修改 `/etc/redis.conf`。

随后 INFO 结果为：

```text
aof_enabled:1
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:0
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_last_write_status:ok
```

并生成文件：

```text
/var/lib/redis/appendonly.aof
大小 139 字节，属主 redis:redis
```

`aof_last_rewrite_time_sec:0` 表示初始重写很快完成，不表示 AOF 未启用；`aof_current_rewrite_time_sec:-1` 表示当前没有正在进行的重写。

### 3. 配置持久化与权限故障

执行 `redis-cli CONFIG REWRITE` 返回：

```text
(error) ERR Rewriting config file: Permission denied
```

排查结果：

```text
/etc/redis.conf：-rw-r-----. 1 redis root ...
/etc：drwxr-xr-x. ... root root
redis-server：USER=redis，GROUP=redis
```

配置文件本身的属主允许 Redis 用户写入，但 Redis 用户没有 `/etc` 目录的写权限，无法创建临时文件并重命名替换配置文件。因此没有修改目录权限，而是使用管理员权限手动修改有效配置行：

```bash
sudo sed -i 's/^appendonly no$/appendonly yes/' /etc/redis.conf
```

随后 `grep` 确认：

```text
593:appendonly yes
```

`CONFIG SET` 负责当前运行时，`sed` 负责磁盘配置；两者都为 `yes` 后，重启才会继续启用 AOF。

### 4. 写入测试与重启恢复

用户写入测试键：

```bash
redis-cli SET practice:aof-check aof-ok
```

返回 `OK`，随后 INFO 显示 `aof_enabled:1`、`aof_rewrite_in_progress:0`、`aof_last_bgrewrite_status:ok`、`aof_last_write_status:ok`。

重启 Redis 后，没有重新 SET，直接执行 `GET practice:aof-check` 返回：

```text
"aof-ok"
```

启动日志明确记录：

```text
5519:M 14 Sep 11:44:30.922 * DB loaded from append only file: 0.000 seconds
5519:M 14 Sep 11:44:30.922 * The server is now ready to accept connections on port 6379
```

因此已验证：配置文件持久化成功、Redis 重启后保持 AOF 开启，并从 AOF 加载练习数据。日志中的 backlog、`overcommit_memory` 和 THP WARNING 仍只是待核验项，本次没有修改内核参数。

一句话记住：`CONFIG SET` 改运行时，配置文件决定重启后的状态，启动日志和重启后数据读回才是 AOF 恢复验证证据。

## 十五、指定 RDB 备份文件隔离回灌验证（已验证）

正常重启加载的是当前正式数据目录中的 RDB，不能代替“指定某个历史备份文件并加载它”的回灌验证。本次使用临时目录和端口 `6380`，没有停止正式 `6379` 实例，也没有删除当前 AOF。

### 1. 备份文件预检与准备

```bash
sudo redis-check-rdb /var/lib/redis/dump.rdb.before-restart-20260913-183303
```

实际结果为 `Checksum OK`、`RDB looks OK!`、`2 keys read`、`0 expires`。随后将该文件复制到 `/var/lib/redis-rdb-restore-20260914/dump.rdb`，并设置目录与文件属主为 `redis:redis`。第一次 `sudo` 密码输入错误，第二次认证成功，命令均完成。

### 2. 隔离实例加载

使用 `sudo -u redis redis-server` 在 `127.0.0.1:6380` 启动临时实例，指定临时目录、`dump.rdb`，并设置 `--appendonly no`、`--save ""`，避免 AOF 或自动保存干扰验证。

### 3. 实际结果

```bash
redis-cli -p 6380 INFO keyspace
```

返回：

```text
db0:keys=2,expires=0,avg_ttl=0
```

```bash
redis-cli -p 6380 KEYS '*'
```

列出两个键：`server:centos100`、`practice:rdb-check`。临时实例日志显示：

```text
DB loaded from disk: 0.000 seconds
The server is now ready to accept connections on port 6380
```

因此确认：指定的历史 RDB 备份已被 Redis 实际加载，备份中的 2 个键成功回灌。该验证不等于断电恢复，也不证明所有业务键都在备份中；备份文件本身只包含 2 个键。

### 4. 恢复动作与运行身份（已讲解）

- `cp` 只是准备备份文件；启动指定 `--dir`、`--dbfilename` 且关闭 AOF 的 Redis 时，Redis 才读取 RDB 并重建内存数据，后续 GET/HGETALL 只是查询结果。
- `--save ""` 关闭自动生成快照的规则，不阻止启动时读取已有 RDB；`--daemonize yes` 只表示后台运行，不等于开机自启。
- `sudo -u redis` 表示以 Linux 系统用户 `redis` 执行后面的命令，不是指定 Redis 数据库用户；不指定 `-u` 时 sudo 默认通常使用 root。
- 正式 `6379` 由 systemd 管理，之前已验证开机自启；临时 `6380` 本次手动启动。启动方式与恢复来源不同：正式实例此前从 AOF 加载，本次临时实例从指定 RDB 加载。

### 5. 具体键值与关闭验证（已验证）

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli -p 6380 GET practice:rdb-check` | `"rdb-ok"` |
| `redis-cli -p 6380 HGETALL server:centos100` | 字段 `ip`，值 `192.168.6.100`，只有这一组字段和值 |
| `redis-cli -p 6380 SHUTDOWN NOSAVE` | 无文字输出，返回 Shell 提示符 |
| `redis-cli -p 6380 PING` | `Could not connect to Redis at 127.0.0.1:6380: Connection refused` |
| `redis-cli -p 6379 PING` | `PONG` |

`SHUTDOWN NOSAVE` 关闭目标实例，关闭前不额外保存 RDB，也不会删除已有备份。单凭无输出不能判断关闭成功；后续 `6380` 连接被拒绝且 `6379` 返回 `PONG`，验证了临时实例停止和正式实例响应。后续临时目录核对与清理见下一小节，不应重复启动或关闭实验实例。

### 6. 临时文件核对与安全清理（已验证）

| 用户实际执行 | 实际结果 |
|---|---|
| `sudo ls -lah /var/lib/redis-rdb-restore-20260914` | 临时目录内只有 `dump.rdb`（158 字节）和 `redis.log`（2.8K），属主与属组均为 `redis:redis` |
| `sudo ls -lh /var/lib/redis/dump.rdb.before-restart-20260913-183303` | 原始备份存在，158 字节，属主与属组为 `redis:redis` |
| `sudo rm -i -- /var/lib/redis-rdb-restore-20260914/dump.rdb /var/lib/redis-rdb-restore-20260914/redis.log` | 分别询问删除两个普通文件，用户均输入 `y` |
| `sudo rmdir /var/lib/redis-rdb-restore-20260914` | 无报错，返回 Shell 提示符 |
| `sudo ls -ld /var/lib/redis-rdb-restore-20260914` | 提示“没有那个文件或目录” |

`rm -i` 在删除每个指定文件前询问，`--` 表示其后为路径；`rmdir` 只删除空目录，不强制递归删除。先确认临时实例停止、核对文件与保留的原始备份，再删除明确指定的两个临时文件和空目录。

临时文件与空目录清理已验证完成，最后 ls 提示不存在是预期检查结果，不是清理失败。删除目标只包含实验副本、实验日志和临时目录；原始备份在清理前已确认存在，正式数据目录和 AOF 不在删除范围。本轮没有再次读取原始备份内容或重新执行正式实例 PING，也没有修改内核参数。

## 十六、启动警告与内核参数核验（只读已验证）

`sysctl` 查询或修改 Linux 内核运行参数，`systemctl` 管理服务。本次 sysctl 后只提供参数名，属于查询，不会修改配置。

### 1. 实际命令与输出

```bash
sysctl net.core.somaxconn vm.overcommit_memory
cat /sys/kernel/mm/transparent_hugepage/enabled
```

```text
net.core.somaxconn = 128
vm.overcommit_memory = 0
[always] madvise never
```

### 2. 与 Redis 日志对照

- `net.core.somaxconn=128`：内核对等待应用接受的连接队列设置上限；此前 Redis 请求 backlog=511，内核值较低，因此产生警告。这不是 Redis 只能连接 128 个客户端，也不表示本次已发生连接故障。
- `vm.overcommit_memory=0`：内核采用启发式策略判断内存申请。Redis 后台保存或重写涉及 fork，在内存紧张时可能受到提交检查限制；0 不是当前内存不足的证明，也不表示禁用虚拟内存。
- `[always] madvise never`：方括号内的 always 当前生效，THP 允许为符合条件的内存使用透明大页。老版本 Redis 的延迟与内存开销可能受影响；仅有这项设置不足以证明已发生性能故障。

### 3. 当前边界与下一步

三项实测值与已有日志警告一致，只读核验完成，参数调整与效果验证尚未进行。这些设置属于整台 Linux，不是 Redis 专属配置，后续改动需评估其他服务的影响并准备回滚。

整机和 Redis 内存查询现已实际完成，结果见下一节；三项内核参数仍未调整，本次没有关闭 THP 或重启 Redis。

## 十七、内存上限与淘汰策略（已验证）

### 1. 修改前的内存快照

实际执行 `free -m` 和 `redis-cli -p 6379 INFO memory`：

| 调整前指标 | 用户实际输出 |
|---|---|
| 系统内存（MiB） | total=1980、used=936、free=247、shared=15、buff/cache=796、available=866 |
| Swap（MiB） | total=2047、used=0、free=2047 |
| Redis used_memory | 812936 字节，793.88K |
| Redis used_memory_rss | 6045696 字节，5.77M |
| Redis used_memory_peak | 812936 字节，793.88K |
| total_system_memory | 2076565504 字节，1.93G，指整机总内存 |
| 调整前 maxmemory / policy | 0 / noeviction |
| mem_fragmentation_ratio / allocator | 7.44 / jemalloc-3.6.0 |

available 约为总内存的 44%，考虑了预计可回收的缓存；不能只因 free=247 就判定内存紧张，也不要把 buff/cache 再加到 available 上。Swap 已用 0 只说明这次快照没有占用 Swap，不代表历史上从未使用。

used_memory 包含 Redis 分配器统计的数据与内部结构，RSS 还受代码、共享库、栈及分配器保留空间等影响。比率约为 RSS/used_memory；当前分配量不到 1 MiB，7.44 不能单独证明严重碎片或泄漏，不以此为由清数据或重启。

### 2. 上限与策略的区别

修改前 maxmemory=0 表示 Redis 没有设置自身的内存上限，不是占用 0 字节，也不代表机器内存无限。noeviction 表示内存超限时不自动淘汰键，而是拒绝可能申请内存的写入类命令，通常返回 OOM；本轮没有验证超限拒写。

### 3. 在线设置与读回

```bash
redis-cli -p 6379 CONFIG SET maxmemory 134217728
redis-cli -p 6379 CONFIG GET maxmemory
```

```text
OK
1) "maxmemory"
2) "134217728"
```

134217728=128×1024×1024，即 128 MiB。本次使用学习预算，明显高于已有分配量，未更改淘汰策略；这不是生产通用值，也不是预先分配 128 MiB，更不是进程 RSS 的硬上限，仍需为额外开销及其他服务留空间。

在线设置、文件写入和重启加载是三个不同检查点，本轮均已验证。重启后直接读取运行值，没有再次 CONFIG SET；未执行 CONFIG REWRITE、放宽 `/etc` 权限或回滚。

### 4. 配置文件备份与写入（已验证）

| 用户实际回传的命令 | 实际结果 |
|---|---|
| `sudo grep -n 'maxmemory' /etc/redis.conf` | 第 537 行为 maxmemory 注释示例，第 560 行 maxmemory-policy、第 571 行 maxmemory-samples 也为注释 |
| `sudo cp -av /etc/redis.conf "/etc/redis.conf.before-maxmemory-$(date +%Y%m%d-%H%M%S)"` | `"/etc/redis.conf" -> "/etc/redis.conf.before-maxmemory-20260914-165752"` |
| `sudo grep -n '^maxmemory ' /etc/redis.conf` | `537:maxmemory 134217728` |

带 `#` 的配置行是注释；本次目标是把 maxmemory 示例改为生效行，不修改策略或采样参数。编辑前先复制整份当前配置，保留已配置的其他选项作为回滚参考；备份路径为 `/etc/redis.conf.before-maxmemory-20260914-165752`。用户随后回传第 537 行已是无注释的 `maxmemory 134217728`，确认文件写入结果。

### 5. 服务重启加载验收（已验证）

| 用户实际执行 | 实际结果 |
|---|---|
| `sudo systemctl restart redis` | 未报错，随后用状态与运行值验证 |
| `sudo systemctl status redis --no-pager -l` | `active (running)`，启动于 `2026-09-14 17:10:21 CST`，Main PID=9261，ExecStop=`0/SUCCESS`，enabled |
| `redis-cli -p 6379 CONFIG GET maxmemory` | 返回 `maxmemory` 和 `134217728` |

重启后先直接查询，没有用 CONFIG SET 再次补值。新进程仍返回 134217728，确认 128 MiB 上限通过启动配置保留。配置修改流程已完成运行值设置、备份、文件写入和服务重启读回，不是只验证了内存中的临时设置。

`enabled` 表示当前已配置开机自启；vendor preset 的 disabled 是系统默认预设，与它不矛盾。status 的 Drop-In 只表明存在附加配置，本轮没有读取 limit.conf 内容，不能据名字判断它是内存限制。

随后两个练习字符串键和当前策略已读回，见下一小节；本轮没有重新查看 AOF 加载日志，也不是整机重启、断电恢复或全部键完整性验证。

### 6. 重启后练习数据与 noeviction 策略（读回已验证）

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli -p 6379 MGET practice:rdb-check practice:aof-check` | 依次返回 `"rdb-ok"`、`"aof-ok"` |
| `redis-cli -p 6379 CONFIG GET maxmemory-policy` | 返回 `"maxmemory-policy"` 和 `"noeviction"` |

结合 maxmemory 读回，正式实例当前为 128 MiB 上限、noeviction 策略；两个指定字符串键在本轮服务重启后仍可读取。键名中的 rdb/aof 是练习标签，单凭 MGET 不能证明这次启动分别从哪个持久化文件加载。

策略含义与验证边界：

- noeviction 不会为腾出空间而自动淘汰键；内存超限时，可能申请内存的写入类命令会被拒绝并返回 OOM，不是所有命令都停止工作。
- 读取和 DEL 等释放内存的操作通常仍可用；正常 TTL 到期删除不属于内存淘汰，noeviction 不会禁止过期。
- 上述行为已在隔离实例 `127.0.0.1:6381` 完成实测；实验目录为 `/var/lib/redis-noeviction-20260914`，实例配置为 1 MiB maxmemory、noeviction、AOF 关闭、自动保存关闭，不影响正式 6379。

### 7. noeviction 隔离超限演练（已验证）

用户先确认 6381 端口空闲，再启动隔离实例：

```bash
sudo -u redis redis-server \
  --bind 127.0.0.1 \
  --port 6381 \
  --dir /var/lib/redis-noeviction-20260914 \
  --appendonly no \
  --save "" \
  --maxmemory 1048576 \
  --maxmemory-policy noeviction \
  --daemonize yes \
  --pidfile /var/lib/redis-noeviction-20260914/redis.pid \
  --logfile /var/lib/redis-noeviction-20260914/redis.log \
  --supervised no
```

`PING` 返回 `PONG`，三个配置项分别读回 `maxmemory=1048576`、`maxmemory-policy=noeviction`、`appendonly=no`。随后写入 65536 字节 value 的循环中，前 6 个 key 写入成功，第 7 个开始返回 `OOM command not allowed when used memory > 'maxmemory'`，`DBSIZE=6`。

关键结论：

- 已有数据仍可读：`STRLEN practice:noeviction:1` 返回 65536。
- `GET practice:noeviction` 返回 `(nil)` 不是超限导致读取失败，而是 key 名少了编号；应读取 `practice:noeviction:1` 这样的完整 key。
- 删除 `practice:noeviction:1` 后，`SET practice:noeviction:after-del small` 成功并读回 `small`，证明释放内存后写入恢复。
- `INFO memory` 显示 `used_memory=923152` 小于 `maxmemory=1048576`，与第 7 次 OOM 不矛盾：INFO 是事后查询值，不是写入瞬间尝试申请内存后的峰值。
- 旧版 Redis 3.2 的 `redis-cli` 收到服务端 OOM 错误时退出码可能仍为 0，因此脚本里的 `|| { ...; break; }` 没触发；判断业务失败要解析返回输出，不能只看退出码。
- 用户执行 `SHUTDOWN NOSAVE` 后，6381 `PING` 连接拒绝，正式 6379 `PING` 返回 `PONG`，确认临时实例关闭且正式实例正常。

### 8. noeviction 临时目录核验与清理（已完成）

用户执行 `sudo ls -la /var/lib/redis-noeviction-20260914` 和 `sudo find /var/lib/redis-noeviction-20260914 -maxdepth 1 -type f -printf '%f %s bytes\n'`，确认目录属主为 `redis:redis`，只包含 2745 字节的 `redis.log`。随后 `redis-cli -p 6381 PING` 仍返回 `Connection refused`。

最终清理时，用户执行 `sudo rm -i /var/lib/redis-noeviction-20260914/redis.log` 并确认 `y`，再用 `sudo rmdir /var/lib/redis-noeviction-20260914` 删除空目录。`sudo ls -ld /var/lib/redis-noeviction-20260914` 返回“没有那个文件或目录”，随后 6381 仍拒绝连接，6379 返回 `PONG`。

结论：

- `redis.log` 是本次隔离实例的运行日志，不是业务数据。
- 无 `dump.rdb` 和 `appendonly.aof`，说明 `--save ""` 与 `--appendonly no` 确实生效。
- 无 `redis.pid` 是正常现象：Redis 正常退出后会清理 pidfile。
- 6381 拒绝连接表示临时实例已关闭，不是新故障；正式 6379 此前已验证仍返回 `PONG`。
- `rm -i` 和 `rmdir` 的最终清理已完成，目录复核为不存在；没有操作 `/var/lib/redis` 和正式 6379 的数据。

### 9. allkeys-lru 隔离演练与清理（已完成）

本轮继续使用 `127.0.0.1:6381` 隔离实例，目录为 `/var/lib/redis-allkeys-lru-20260915`，配置为 `maxmemory=1048576`、`maxmemory-policy=allkeys-lru`、AOF 关闭、自动保存关闭。启动前 `ss` 无输出确认端口空闲；启动后 `PING` 返回 `PONG`，三个关键配置均读回预期值。

写入 30 个 65536 字节 value 时全部返回 `OK`。随后 `INFO memory` 显示 `used_memory=923568`、`maxmemory=1048576`、策略为 allkeys-lru；`INFO stats` 显示 `evicted_keys=24`，`DBSIZE=6`。扫描确认仅剩 `practice:allkeys-lru:25` 至 `practice:allkeys-lru:30`；`EXISTS` 验证 `:1` 和 `:24` 已被淘汰，`:25` 和 `:30` 仍存在，`STRLEN :30` 返回 65536。

这说明 allkeys-lru 在内存不足时会自动淘汰旧 key 腾出空间，因此新写入继续成功；与 noeviction 的直接 OOM 拒写形成对比。`SHUTDOWN NOSAVE` 后 6381 拒绝连接，正式 6379 返回 `PONG`。临时目录只遗留 `redis.log 2745 bytes`，用户用 `rm -i` 删除日志、`rmdir` 删除目录，并确认目录不存在。

### 10. volatile-lru 隔离演练与清理（已完成）

- 隔离实例：`127.0.0.1:6381`
- 临时目录：`/var/lib/redis-volatile-lru-20260915`
- 配置：`maxmemory=1048576`、`maxmemory-policy=volatile-lru`、`appendonly=no`、`save=""`

写入数据：

```bash
value=$(printf 'A%.0s' $(seq 1 65536))

for i in $(seq 1 3); do
  redis-cli -p 6381 SET "practice:volatile-lru:no-ttl:$i" "$value"
done

for i in $(seq 1 30); do
  redis-cli -p 6381 SET "practice:volatile-lru:ttl:$i" "$value" EX 86400
done
```

验证结果：

```bash
redis-cli -p 6381 INFO stats | grep -E '^(evicted_keys:)'
redis-cli -p 6381 DBSIZE
redis-cli -p 6381 --scan --pattern 'practice:volatile-lru:*' | sort -V
```

```text
evicted_keys:27
(integer) 6
practice:volatile-lru:no-ttl:1
practice:volatile-lru:no-ttl:2
practice:volatile-lru:no-ttl:3
practice:volatile-lru:ttl:28
practice:volatile-lru:ttl:29
practice:volatile-lru:ttl:30
```

结论：

- `volatile-lru` 只淘汰设置了 TTL 的 key。
- 无 TTL key 即使更旧，也不会被 `volatile-lru` 淘汰。
- `EX 86400` 表示设置 24 小时过期时间。
- `TTL=-1` 表示 key 存在但没有过期时间，不是异常。
- 本节实验、关闭实例和目录清理均已完成，后续不要重做。

### 11. 内核参数调优（已完成）

本节针对正式 Redis 实例 `127.0.0.1:6379` 评估并调整三项系统参数。调整前状态：

```text
Redis tcp-backlog = 511
net.core.somaxconn = 128
vm.overcommit_memory = 0
transparent_hugepage = [always]
```

问题分析：

- Redis 希望 TCP 监听队列达到 `511`，但内核 `somaxconn=128` 会把实际队列限制为 `128`。
- `vm.overcommit_memory=0` 在内存紧张时可能导致 Redis 执行 `BGSAVE` 或 AOF 重写时 `fork()` 失败。
- THP 处于 `[always]`，可能放大 Redis fork 后写时复制的延迟，Redis 推荐关闭。

调整前先备份：

```bash
sudo cp -a /etc/sysctl.conf "/etc/sysctl.conf.bak-$(date +%Y%m%d-%H%M%S)"
```

写入独立 sysctl 配置：

```bash
sudo tee /etc/sysctl.d/99-redis.conf >/dev/null <<'EOF'
net.core.somaxconn = 1024
vm.overcommit_memory = 1
EOF
```

立即加载并验证：

```bash
sudo sysctl --system
sysctl net.core.somaxconn
sysctl vm.overcommit_memory
```

关键结果：

```text
net.core.somaxconn = 1024
vm.overcommit_memory = 1
```

立即关闭透明大页，并通过 tmpfiles 保持重启后关闭：

```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/enabled

sudo tee /etc/tmpfiles.d/redis-disable-thp.conf >/dev/null <<'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - never
EOF
```

结果：

```text
always madvise [never]
```

`somaxconn` 的值立即生效，但 Redis 已创建的监听 socket 是在旧值下创建的，因此需要重启 Redis 才能让 `tcp-backlog=511` 完整生效。

重启前：

```bash
sudo ss -lntp 'sport = :6379'
```

关键输出：

```text
LISTEN 0 128 127.0.0.1:6379 ... redis-server
```

重启并验证：

```bash
sudo systemctl restart redis
redis-cli -p 6379 PING
sudo ss -lntp 'sport = :6379'
redis-cli -p 6379 CONFIG GET tcp-backlog
```

关键输出：

```text
PONG
LISTEN 0 511 127.0.0.1:6379 ... redis-server
tcp-backlog 511
```

最终复核：

```bash
sysctl net.core.somaxconn
sysctl vm.overcommit_memory
cat /sys/kernel/mm/transparent_hugepage/enabled
```

结果：

```text
net.core.somaxconn = 1024
vm.overcommit_memory = 1
always madvise [never]
```

结论：

- `net.core.somaxconn=1024` 已解除 Redis `tcp-backlog=511` 的系统限制。
- Redis 重启后实际监听队列从 `128` 变为 `511`。
- `vm.overcommit_memory=1` 已生效，可降低 Redis fork 失败风险。
- THP 已关闭，并写入 tmpfiles 配置保证重启后仍为 `never`。
- 本节调整和验证完成，不需要重复执行。

### 12. Redis 巡检手册（已完成）

巡检对象为正式实例 `127.0.0.1:6379`。本节只检查状态，不修改 Redis 配置。

#### 服务与监听巡检

```bash
systemctl is-active redis
systemctl is-enabled redis
sudo ss -lntp 'sport = :6379'
redis-cli -p 6379 PING
redis-cli -p 6379 DBSIZE
```

关键结果：

```text
active
enabled
LISTEN 0 511 127.0.0.1:6379
PONG
(integer) 3
```

结论：服务运行、开机自启、监听地址、监听端口、连接响应和实际监听队列均正常。

#### 核心配置巡检

```bash
redis-cli -p 6379 CONFIG GET maxmemory
redis-cli -p 6379 CONFIG GET maxmemory-policy
redis-cli -p 6379 CONFIG GET appendonly
redis-cli -p 6379 CONFIG GET save
redis-cli -p 6379 CONFIG GET dir
redis-cli -p 6379 CONFIG GET dbfilename
```

关键结果：

```text
maxmemory 134217728
maxmemory-policy noeviction
appendonly yes
save 900 1 300 10 60 10000
dir /var/lib/redis
dbfilename dump.rdb
```

结论：

- 内存上限为 128 MiB。
- 当前策略为 `noeviction`。
- AOF 开启。
- RDB 自动保存策略为 `900 1`、`300 10`、`60 10000`。
- 数据目录为 `/var/lib/redis`。

注意：`CONFIG GET apendonly` 返回空是拼写错误，正确参数是 `appendonly`。这台 Redis 3.2 的 `CONFIG GET appendfilename` 返回空，不能据此判断 AOF 文件异常，应改用 `CONFIG GET 'append*'` 和实际文件检查。

#### 进程、客户端与持久化状态巡检

```bash
redis-cli -p 6379 INFO server | grep -E '^(redis_version:|process_id:|uptime_in_seconds:|uptime_in_days:)'
redis-cli -p 6379 INFO clients | grep -E '^(connected_clients:|blocked_clients:)'
redis-cli -p 6379 CONFIG GET 'append*'
redis-cli -p 6379 INFO persistence | grep -E '^(rdb_last_bgsave_status:|rdb_last_save_time:|rdb_bgsave_in_progress:|aof_enabled:|aof_last_write_status:|aof_rewrite_in_progress:)'
```

关键结果：

```text
redis_version:3.2.12
process_id:18184
uptime_in_seconds:1926
uptime_in_days:0
connected_clients:1
blocked_clients:0
appendfsync everysec
appendonly yes
rdb_bgsave_in_progress:0
rdb_last_bgsave_status:ok
aof_enabled:1
aof_rewrite_in_progress:0
aof_last_write_status:ok
```

结论：RDB 和 AOF 均无正在执行的后台任务，最近一次 RDB 保存和 AOF 写入状态均正常。

#### 持久化文件巡检

```bash
sudo ls -lh /var/lib/redis
sudo find /var/lib/redis -maxdepth 1 -type f -printf '%f %s bytes %TY-%Tm-%Td %TH:%TM\n'
redis-cli -p 6379 LASTSAVE
date -d "@$(redis-cli -p 6379 LASTSAVE)" '+%F %T %Z'
```

关键结果：

```text
appendonly.aof 212 bytes 2026-09-14 11:41
dump.rdb 185 bytes 2026-09-15 15:49
dump.rdb.before-restart-20260913-183303 158 bytes 2026-09-13 17:35
LASTSAVE 1789458586
2026-09-15 15:49:46 CST
```

结论：

- 当前 RDB 文件为 `dump.rdb`，最后保存时间为 `2026-09-15 15:49:46 CST`。
- AOF 文件为 `appendonly.aof`，AOF 开启且写入状态正常。
- `dump.rdb.before-restart-20260913-183303` 是历史备份文件，不是当前加载的 RDB 文件。
- AOF 文件时间早于当前 RDB 文件不代表异常，只说明近期没有新的写命令追加。

#### 内存、淘汰与日志巡检

```bash
redis-cli -p 6379 INFO memory | grep -E '^(used_memory_human:|used_memory_peak_human:|maxmemory_human:|maxmemory_policy:|mem_fragmentation_ratio:)'
redis-cli -p 6379 INFO stats | grep -E '^(evicted_keys:|rejected_connections:|keyspace_hits:|keyspace_misses:)'
redis-cli -p 6379 INFO keyspace
sudo journalctl -u redis -p err..alert --since "24 hours ago" --no-pager
```

关键结果：

```text
used_memory_human:793.88K
used_memory_peak_human:793.88K
maxmemory_human:128.00M
maxmemory_policy:noeviction
mem_fragmentation_ratio:3.29
evicted_keys:0
rejected_connections:0
keyspace_hits:0
keyspace_misses:0
db0:keys=3,expires=0,avg_ttl=0
-- No entries --
```

结论：

- 当前内存远低于 128 MiB 上限。
- 没有发生 key 淘汰和连接拒绝。
- `mem_fragmentation_ratio=3.29` 在数据量只有 793.88K 时不作为异常，固定进程开销会放大该比率。
- 当前 3 个 key 都没有 TTL，`expires=0` 是描述结果，不是错误。
- 最近 24 小时 Redis 错误日志为空。

#### 系统参数巡检

```bash
sysctl net.core.somaxconn
sysctl vm.overcommit_memory
cat /sys/kernel/mm/transparent_hugepage/enabled
```

关键结果：

```text
net.core.somaxconn = 1024
vm.overcommit_memory = 1
always madvise [never]
```

结论：Redis 相关系统参数保持为调优后的目标状态。

本节巡检手册已完成，后续巡检按上述命令和判断标准执行，不需要重复教学验证。

## 十八、后续学习与验收

1. 进入 Docker/Compose，优先完成 Docker 安装、镜像、容器、端口映射和数据卷基础。
2. 断电恢复、高可用仍未验证；AOF 基础启用与重启恢复、指定 RDB 备份隔离回灌、三种淘汰策略实验、内核参数调优、Redis 巡检手册均已完成，不再列为待执行步骤。

断电恢复和高可用仍未验证；性能调优、内核参数调整、AOF 基础启用与重启恢复、指定 RDB 备份隔离回灌、淘汰策略实验和巡检手册均已完成。
