# 监控、日志与告警学习记录

当前属于阶段 6，承接已完成的 Ansible 部署与现有 Linux 巡检脚本。

## 一、资源与监听端口基线（2026-10-10 已采集）

### 本节位置与目标

Ansible 管理期望部署状态；监控用于持续采集运行状态、保存历史并发现异常。指标是可量化的数值，日志记录事件细节，告警是在满足规则时主动通知。这里先确认资源余量与已有监听，不立即安装整套软件。

本节目标：读懂内存、根分区和 TCP 监听快照，明确权限与验证边界，为后续组件选择提供依据。

### 用户实际执行的命令

```bash
free -h
free
df -h /
ss -lnt
ss -lntp
```

### 内存与磁盘结果

| 项目 | 当前快照 | 判断 |
|---|---|---|
| 总内存 | 约 1.9 GiB | 小内存实验机，分步部署 |
| used | 627 MiB | 采样时的使用情况，不是峰值 |
| free | 864 MiB | 完全空闲部分，不是全部可用内存 |
| buff/cache | 487 MiB | 缓冲和缓存，有一部分可回收 |
| available | 约 1.2 GiB | 判断可供新负载使用的余量时更有参考价值 |
| Swap | 2.0 GiB，使用 0 | 当前没有占用，不证明历史从未发生交换 |
| 根分区 | 17 GiB，已用 6.4 GiB，可用约 11 GiB，38% | 本次未见容量紧张 |

`free -h` 按易读单位显示；默认 `free` 在当前工具环境中以 KiB 显示。用户第二次读取 total=2027896、available=1219968，对应约 1.9 GiB 总量和约 1.2 GiB available。两次采样、动态变化与显示舍入都会造成表面数值差异。

不能把 buff/cache 全当作浪费，也不能把 available 当成永远能分配给监控的固定预算。当前余量适合从轻量主机指标采集开始，不能据此保证 Prometheus、Grafana 与既有数据库长期同时运行都无压力；后续需要控制负载、数据保留与磁盘增长。

### TCP 监听结果

| 监听地址 | 已核实的范围 |
|---|---|
| 127.0.0.1:8008、8009 | 与 Ansible 练习站点配置吻合，当前只见回环监听 |
| 127.0.0.1:6379 | 与既有 Redis 配置吻合，进程身份仍需本轮提权回读 |
| *:3306、*:80、*:8080 | 通配监听，不能直接等同于公网可达 |
| *:22、[::]:22 | 当前存在 SSH 常用端口的监听，进程待核对 |
| 192.168.122.1:53 | 仅凭端口不能确定具体进程 |
| 111、631、25、6010 等 | 保留为已有监听，不凭常见端口号断定服务归属 |

本次 TCP 列表未见 9100、9090、3000、9093 的监听，可作为后续监控候选端口；不等于已经验证防火墙放行，也不等于相关软件一定未安装。回环监听通常只接受来自本机的连接，通配监听的外部可达性还取决于网络路径和防火墙。

`ss -lnt` 的参数：`-l` 只看监听，`-n` 数字显示地址/端口，`-t` TCP。`-p` 请求显示关联进程，但不会自动提权。LISTEN 行的 Recv-Q 表示等待应用 accept 的连接队列，Send-Q 表示监听 backlog 上限，不能把 511 等数值理解成当前连接数或流量。

### 为什么加 -p 仍看不到大部分进程

用户提示符是 `[atguigu@centos100 root]$`：atguigu 是用户，root 是当前目录名，不代表 root 身份。普通用户读取其他用户进程信息时可能受权限限制。

实际只有 8080 行显示 python、PID 1219、fd=3；这与此前 Python 后端实现相符，但其他端口没有进程字段不表示没有进程。下一步用 sudo ss -lntp 核对真实关联，不先修改或停止任何服务。

### 当前结论与下一步

- 资源与 TCP 监听基线已采集；只代表 2026-10-10 本次快照，不是长期性能结论。
- 本轮尚未安装监控组件，未调整服务、端口、内存上限或防火墙。
- 平台兼容性核对已完成并归档，输出与结论见下一节“二”。
- 安装路线为 node_exporter → Prometheus → Grafana → 告警与故障演练。CentOS 7 保持隔离，已核对兼容性，不能直接照搬最新版或一次装齐所有组件。

## 二、平台兼容性与监听进程核对（2026-10-10 已回传）

```bash
uname -mr
ldd --version | head -n 1
sudo ss -lntp
```

### 输出与判断

- `uname -mr` 返回 `3.10.0-1160.el7.x86_64 x86_64`：CentOS 7（el7）、内核 3.10.0-1160、x86_64，组件统一下载 linux-amd64。
- `ldd --version | head -n 1` 返回 `ldd (GNU libc) 2.17`：glibc 很旧，动态链接且要求 GLIBC_2.18+ / 2.28+ / 2.34+ 的新二进制无法运行；但 node_exporter / Prometheus 是纯 Go 静态编译，不受 glibc 限制，真正要防的是新版 Go(1.24+) 构建产物要求内核≥3.17，本机 3.10 同样不能追最新版。
- `sudo ss -lntp` 补齐进程：8008/8009/80=nginx（pid 1312 起共 5 个，master+4 worker 共享监听，fd=7/6/8）；6379=redis-server 1212；3306=mysqld 1553；8080=python 1219；192.168.122.1:53=dnsmasq 1743；22=sshd 1201；25=postfix master 1643；631=cupsd 1215；6010=当前 SSH 会话的 sshd 2327；111=rpcbind 743。IPv6 行是同一服务的 v6 监听。
- 仍未出现 9100/9090/3000/9093 → 监控栈未安装，候选端口未占用。

### 兼容性结论与版本策略

- 平台：CentOS 7、内核 3.10.0-1160、glibc 2.17、x86_64。
- node_exporter 选 v1.8.2（linux-amd64，旧构建线、对内核要求低），不用 1.9+ 追新。
- 每个组件解压后第一步都是执行 `--version` 验证能在本机运行，再配置 systemd 与采集。

## 三、node_exporter 安装与 systemd 托管（2026-10-13 完成，2026-10-14 补 fd 实测）

### 完整操作顺序（可复现 runbook）

```bash
# 1. 下载（必须在可写目录；cwd 落在 /root 会报「权限不够」）
cd ~
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
ls -lh node_exporter-1.8.2.linux-amd64.tar.gz        # 期望约 11M，与 curl 报的 10.1M 是同一大小

# 2. 解压并先验证兼容性（顺序很重要：先验证再安装）
tar -xzf node_exporter-1.8.2.linux-amd64.tar.gz
cd node_exporter-1.8.2.linux-amd64
./node_exporter --version

# 3. 建专用账号并安装二进制
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo cp ~/node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
ls -l /usr/local/bin/node_exporter
sudo restorecon -v /usr/local/bin/node_exporter      # 建议补充，本次未执行（SELinux 开着时更稳）

# 4. 写 unit 文件
sudo vi /etc/systemd/system/node_exporter.service

# 5. 回读 -> 生效 -> 启动 -> 验证
systemctl cat node_exporter
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
systemctl status node_exporter
systemctl is-enabled node_exporter
sudo ss -lntp | grep 9100
curl -s http://127.0.0.1:9100/metrics | head -n 12
curl -s http://127.0.0.1:9100/metrics | grep -c '^node_'

# 6. 故障演练：强杀看是否自动拉起
pid=$(systemctl show -p MainPID node_exporter | cut -d= -f2)
sudo kill -9 $pid
sleep 3
systemctl status node_exporter
journalctl -u node_exporter -n 30 --no-pager -l

# 7. 清理下载物（二进制已装到 /usr/local/bin）
rm -f ~/node_exporter-1.8.2.linux-amd64.tar.gz
rm -rf ~/node_exporter-1.8.2.linux-amd64
```

### unit 文件内容

```ini
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

注意区分两种「配置」：这个 unit 是 **systemd 管进程**的配置；node_exporter 自身**没有配置文件**，它的可调项全部是命令行参数，写在 `ExecStart=` 那一行。Prometheus 才是下一个真正带应用配置文件（`prometheus.yml`）的组件。

### 每步的成功判断标准

| 步骤 | 成功标志 |
|---|---|
| 下载 | `ls -lh` 约 11M，与 curl 报告的总量一致 |
| 兼容性 | `--version` 打印 version 1.8.2 / go1.22.5 / linux/amd64，无 GLIBC 报错 |
| 安装 | `/usr/local/bin/node_exporter` 存在且可执行 |
| unit 生效 | `systemctl cat` 内容与预期一致 |
| 启动 | `active (running)`、`is-enabled`=enabled、`ss` 显示 `[::]:9100`、pid 与 MainPID 一致 |
| 采集 | `/metrics` 有 `# HELP` 注释，`grep -c '^node_'` 数百行（本次 681） |
| 自愈 | 强杀后仍 `active (running)`，MainPID 变号，日志出现 `Scheduled restart job` |

### 本次实测数据

- `--version`：version 1.8.2、revision f1e0e8360aa60b6cb5e5cc1560bed348fc2c1895、go version go1.22.5、platform linux/amd64、build date 20240714-11:53:45。
- MainPID 变化：2955（10-11）-> 1219（10-13 重新登录后）-> 强杀 -> 4887 -> 强杀 -> 4912。低 PID 提示期间发生过重启，与 `enabled` 自启结论一致。
- 采集量：`node_*` 681 行；内存快照 3.9M / 7.8M / 2.5M（波动属正常）。
- fd：空闲 7、50 个 curl 并发抓取期间 24、结束后回落 7。
- 监听：`[::]:9100`（IPv6 通配，`bindv6only=0` 时同时收 IPv4，故 `127.0.0.1` 可通）。

### 明确不做的项及理由

- `LimitNOFILE`：实测空闲 7 个 fd、上限 1024，余量约 146 倍，加了就是抄一个用不到的数字。若将来挂载点/网卡大幅增加或出现 `Too many open files`，再回来加。
- `RestartSec`：保持默认 100ms。
- 监听地址收敛到 `127.0.0.1`：暂不改，保持默认通配；firewalld 默认只放行 ssh，外部不可达，等跨机抓取时再定。

### 本节踩过的坑

- `curl` 报 `权限不够`：cwd 落在 `/root`，根因是 `su atguigu`（非登录式）保留了 root 的工作目录；正解 `su - atguigu`。
- `systemctl show -p MainPID --value`：`--value` 需 systemd 230，CentOS 7 是 219，报「无法识别的选项」；改用 `systemctl show -p MainPID node_exporter | cut -d= -f2`。
- `systemctl status` 只反映当前状态，自动重启后旧 `failed` 记录被新实例覆盖，历史必须查 `journalctl`。
- `grep -c` 数的是匹配行数，不是指标种类数（同一指标不同 label 各占一行）。
- 不要硬编码 PID：会被系统回收复用，且重启后就失效；用 unit 名动态取。
- 并发实验里刷屏的 `[1] 2455` 是 bash 作业号加 curl 自身 PID，不是 node_exporter 的 fd。
- 判断 fd 是否泄漏的关键是「抓取结束后有没有回落」，不是峰值有多高。

### 交叉复核结果（2026-10-14 完成）

**复核 1：PID 三来源一致**

```bash
pid=$(systemctl show -p MainPID node_exporter | cut -d= -f2)
echo $pid                              # 1220
pgrep -a node_exporter                 # 1220 /usr/local/bin/node_exporter
ps -o user,pid,cmd -C node_exporter     # node_ex+ 1220 /usr/local/bin/node_exporter
```

三条独立来源都报 1220，确认此前 `ls /proc/$pid/fd` 量的就是 node_exporter。`ps` 的 USER 列显示 `node_ex+` 是 procps 默认把该列截断为 8 字符、多余部分用 `+` 标记，不是错误；要看全名用 `ps -o user:16,pid,cmd -C node_exporter`。

PID 从 10-13 的 4912 变成 1220 且号很小，最可能是中间重启过机器；若确为重启，服务自动恢复即 `systemctl enable` 开机自启的实证。用 `uptime` 区分「重启机器」与「仅重启服务」。

**复核 2：静态链接三重确认**

| 工具 | 输出 | 结论 |
|---|---|---|
| `ldd` | `不是动态可执行文件` | 不依赖任何 .so |
| `file` | `ELF 64-bit LSB executable, x86-64, statically linked, not stripped` | 静态链接 |
| `readelf -d` | `There is no dynamic section in this file.` | 无动态段，即无 NEEDED |

结论：node_exporter 不调用系统 glibc，准确说法是 glibc 兼容性「绕过」而非「通过」；内核可加载并启动 Go runtime 这一关是真实验证过的。`not stripped` 仅表示符号表保留，不影响运行。

**复核 3：`/dev/tcp` 并发对照实验（fd 精确模型）**

```bash
pid=$(systemctl show -p MainPID node_exporter | cut -d= -f2)
sudo ls /proc/$pid/fd | wc -l                                          # 7（基线）
for i in $(seq 100); do (exec 3<>/dev/tcp/127.0.0.1/9100; sleep 5) & done
sleep 1; sudo ls /proc/$pid/fd | wc -l                                 # 107（峰值）
wait;    sudo ls /proc/$pid/fd | wc -l                                 # 7（回落）
```

结果：基线 7 → 峰值 **107** = 7 + 100，与预测完全吻合 → 回落 7。

由此得到**精确模型：fd = 常驻 7 个 + 每条活跃连接 1 个**，没有隐藏开销。上限 1024 要撑到需要担心，得同时有 1000+ 并发连接，单机场景基本不会出现——`LimitNOFILE` 不加的依据从「别人也没加」升级为可量化计算。

附带确认：只建连接不发请求时，服务端等足 5 秒未主动断开，说明 `--web.read-timeout`（默认 5 分钟）没有在 5 秒内介入。

一处记录在案的判断失误：预测 `set +m` 能屏蔽 `[1] 6814` 这类后台作业提示，实测**仍会打印**；但它确实抑制了作业**结束**时的「完成」通知——可见 `set +m` 管的是结束通知，管不了创建提示。


## 四、基础知识补充（服务账号、安装位置、fd、常用参数）

这一节把 node_exporter 那一堆零散问题收成可复用的知识，后面 Prometheus / Grafana 建账号、装程序、看 fd 都用同一套。

### 4.1 为什么要建专用服务账号

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

- **最小权限**：node_exporter 只读 `/proc`、`/sys` 并监听 9100，不需要 root。用专用低权限账号跑，进程即使被攻破也拿不到 root。
- **`--no-create-home`**：不建家目录。服务账号不存个人数据、不需要 `.bashrc`，少一个可写目录就少一处风险。
- **`--shell /bin/false`**：把这个账号的登录 shell 设成 `/bin/false`，它一登录就立刻退出（返回 1），人类无法拿它当普通账号用。对比 `/sbin/nologin`：后者也会拒绝登录，但会打印一句提示。
- **关键点**：`useradd` 只负责建账号；真正让它生效的是 unit 里的 `User=node_exporter` / `Group=node_exporter`。systemd 在 `exec` 前先 `setuid/setgid`，所以进程从第一行代码起就不是 root。**unit 里不写 `User=`，默认还是 root 跑**——建了账号不等于用上了账号。

### 4.2 账号存在哪、怎么查

| 文件 | 内容 | 权限 |
|---|---|---|
| `/etc/passwd` | 账号基本信息（人人可读） | 644 |
| `/etc/shadow` | 密码哈希、有效期（仅 root） | 000/600 |
| `/etc/group` | 组与成员 | 644 |

`/etc/passwd` 每行 7 个字段，用冒号分隔：

```text
node_exporter:x:997:995::/home/node_exporter:/bin/false
   ①          ② ③  ④ ⑤      ⑥              ⑦
```

① 用户名 ② 密码占位（`x` 表示在 shadow 里）③ UID ④ GID ⑤ 注释/GECOS ⑥ 家目录 ⑦ 登录 shell

查单个账号（三种写法都行，推荐 `getent`）：

```bash
getent passwd node_exporter        # 走 NSS，也能查到 LDAP/sssd 里的账号
id node_exporter                   # UID/GID/附加组一次看全
grep '^node_exporter:' /etc/passwd # 只看本地文件
```

查所有账号：

```bash
awk -F: '{print $1}' /etc/passwd                                  # 只要用户名
awk -F: '$3>=1000 && $3<65534 {print $1, $3, $6, $7}' /etc/passwd # 只看普通用户
```

- `awk -F:`：`-F` 指定字段分隔符为冒号，默认是空白。
- `$3` 是第 3 字段（UID）；`$3>=1000` 是普通用户的分界，CentOS 7 的 `UID_MIN` 就是 1000，1～999 留给系统账号，65534 是 `nobody`。
- 所以 `node_exporter` 的 UID 在 900 多，属于**系统账号**，`ls -l` 里显示成用户名而不是数字，是正常的。

### 4.3 为什么装到 `/usr/local/bin`

```bash
sudo cp ~/node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
```

- **FHS 约定**：`/usr/bin` 归包管理器（yum/rpm）管，`yum update` 可能覆盖或产生文件冲突；`/usr/local` 是留给管理员自己装的软件。两者分开，升级系统不会动你的东西。
- **在默认 PATH 里**：`/usr/local/bin` 对 root 和普通用户都在 `PATH` 中，装进去就能直接敲命令名。验证：`echo $PATH`、`command -v node_exporter`。
- **不是硬性要求**：放 `/opt/node_exporter/` 也完全可以。真正的硬要求是 **unit 的 `ExecStart=` 必须写绝对路径**——systemd 给服务的 PATH 是编译进去的固定短列表（通常是 `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin`），不是登录 shell 那套，不要赌它能找到。

### 4.4 fd（file descriptor，文件描述符）

- 定义：进程打开一个"文件"时，内核发给它的一个**小整数句柄**。之后所有读写都用这个整数，不用路径。
- Linux 里"一切皆文件"：普通文件、目录、socket、pipe、设备、`epoll` 实例，全都用 fd 表示。所以一个监听 9100 的进程，它的网络连接也占 fd。
- **0/1/2 是约定好的**：`0`=stdin、`1`=stdout、`2`=stderr。它们由父进程（shell 或 systemd）在 `fork`+`exec` 之前就打开好，子进程直接继承，所以任何程序一起来就有这三个。**`3` 开始才是程序自己开的**。
- 看某个进程开了什么：

```bash
pid=$(systemctl show -p MainPID node_exporter | cut -d= -f2)
sudo ls -l /proc/$pid/fd
```

输出是符号链接，指向真实对象：`/dev/null`、`pipe:[12345]`、`socket:[67890]`（后面的数字是内核 inode，不是端口）。

**soft / hard 限制**（一个进程能开多少 fd）：

| 概念 | 含义 | 谁能改 |
|---|---|---|
| soft limit | 当前生效的上限，超了报 `Too many open files` | 进程自己可以在 hard 以内调高 |
| hard limit | 天花板 | 只有 root 能提高 |

```bash
ulimit -n          # 当前 shell 的 soft
ulimit -Hn         # 当前 shell 的 hard
cat /proc/$(systemctl show -p MainPID node_exporter | cut -d= -f2)/limits | grep 'Max open files'
```

最后一条输出两列数字，分别是 soft 和 hard。systemd 的 `LimitNOFILE=` 改的就是这个值。

- fd 号**会被复用**：关掉 5 号再开一个，可能还是 5 号。所以判断泄漏看"总数是否回落"，不看具体号码。

### 4.5 几个常用参数

```bash
systemctl show -p MainPID node_exporter | cut -d= -f2
```

- `cut -d= -f2`：`-d=` 把分隔符定为 `=`，`-f2` 取第 2 段。`MainPID=1220` → `1220`。
- 注意：如果某行里根本没有 `=`，`cut` 默认会**原样输出整行**（加 `-s` 才跳过这类行），所以要先确认输出格式是 `Key=Value`。

```bash
curl -s http://127.0.0.1:9100/metrics | head -n 12
curl -sS http://127.0.0.1:9100/metrics
curl -s http://127.0.0.1:9100/metrics | grep -c '^node_'
```

| 参数 | 作用 |
|---|---|
| `-s`（silent） | 不打印进度条，也不打印错误信息 |
| `-S`（show-error） | 配合 `-s` 使用时，仍然打印错误信息 → 所以常用 `-sS` |
| `-L` | 跟随重定向；GitHub 下载链接会 302，缺了它只能拿到空响应 |
| `-O` | 用远端的文件名保存到当前目录 |
| `-o /dev/null` | 丢弃响应体，只关心成功与否 |
| `-C -` | 断点续传，从本地已有字节数接着下（见第五节） |

- `grep -c` 是 **count**：数匹配的**行数**，不是指标种类数。
- `stat -c %s 文件` 输出文件的**字节数**（`%s` = size），比 `ls -lh` 的四舍五入精确，适合核对下载完整性。

## 五、Prometheus 2.53.0 下载、解压与版本验证（2026-10-15 完成）

### 5.1 选版与下载

```bash
cd ~
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
stat -c %s prometheus-2.53.0.linux-amd64.tar.gz     # 完整应为 104192065 字节
```

- 选 2.53.0（LTS 线）而不是最新版：构建 Go 版本是本机能不能跑的第一道关，2.53.0 用 go1.22.4 构建，与 node_exporter 的 go1.22.5 同档，已在 3.10 内核 + glibc 2.17 上验证过这一档可用。
- 包体约 99.3 MiB（curl 口径）/ 104,192,065 字节（字节口径）。**同一个文件两种单位会看起来差几 M，属正常**：curl 按 1024 进制显示，`ls -lh` 也是，但四舍五入到 1 位小数。
- Prometheus 比 node_exporter 大一个数量级：二进制里既有 TSDB 又有 Web UI，包里还带模板和 `promtool`。

### 5.2 坑：下载被掐断 → tar 报"异常的 EOF"

症状：

```text
gzip: stdin: unexpected end of file
tar: 归档文件中异常的 EOF
tar: Error is not recoverable: exiting now
```

**机理**：gzip 流末尾固定 8 字节，存着 CRC32 和解压后的原始长度。文件被截断时这 8 字节不存在，gzip 无法收尾 → 报 `unexpected end of file`；tar 接着读到一半没数据 → 报 `异常的 EOF`。两条错是同一件事的两层表现。

**两种成因，报错完全一样**：
1. 下载还没跑完就去 `tar`（包括中途 Ctrl+C 或 ssh 断开）；
2. 下载在 30%、70% 处被链路掐断。

**只能靠大小区分**，所以顺序永远是：先量大小 → 再校验 → 最后解压。**文件不完整时 `tar` 跑一百次都是同一个错**，它不会自己变好。

**修复：断点续传**

```bash
curl -LO -C - https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
```

- `-C -` 先看本地文件已有多少字节，再发 `Range: bytes=<已有>-`，服务端从断点接着发。**不带它就从 0 重来**。
- 前提是服务端支持 Range（GitHub 支持）。若报 `curl: (33) HTTP server doesn't seem to support byte ranges`，说明续传不可用，只能重下。
- 本次实测：30.5M → 70M 时被掐，报 `curl: (18) transfer closed with 30791745 bytes remaining to read`。`(18)` = `CURLE_PARTIAL_FILE`，含义是**已收到的数据有效，只是没传完**，所以继续 `-C -` 就是对的做法。
- CentOS 7 自带 curl 7.29 较老，`--retry` 覆盖的错误码有限，不一定接得住 `(18)` 这种"传到一半断开"；要自动化就用外层循环。

**用"已收 + 剩余"反推总大小**（本次最有用的技巧）：

```text
ls -lh 显示 70M（= 70 × 1048576 = 73,400,320 字节）
curl 说还差 30,791,745 字节
→ 总大小 ≈ 104,192,065 字节
```

与最初 curl 报的 `Total 99.3M` 精确吻合，说明这个推算可靠。以后再遇到"下到一半断了"，不用猜，用这两个数就能知道还差多少、有没有下完。

**断线重试循环**（限次数，避免无限循环）：

```bash
URL=https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.53.0/sha256sums.txt
SUM=$(grep ' prometheus-2.53.0.linux-amd64.tar.gz$' sha256sums.txt | awk '{print $1}')
for i in $(seq 30); do
  [ "$(sha256sum prometheus-2.53.0.linux-amd64.tar.gz | awk '{print $1}')" = "$SUM" ] && break
  echo "--- 第 $i 次续传 ---"
  curl -LO -C - "$URL"
  sleep 2
done
sha256sum prometheus-2.53.0.linux-amd64.tar.gz
```

成功标准只有一条：**sha256 与 `sha256sums.txt` 中的值完全一致**。文件不完整时哈希必然不匹配，所以循环会一直补。

### 5.3 解压与包内容

```bash
tar -xzf prometheus-2.53.0.linux-amd64.tar.gz && echo EXTRACT_OK
cd prometheus-2.53.0.linux-amd64
ls -l
```

本次结果（总用量 261312 KiB）：

| 文件/目录 | 大小 | 作用 |
|---|---|---|
| `prometheus` | 137,821,861（约 131M） | 主程序，静态链接 |
| `promtool` | 129,737,825（约 124M） | 配置体检、规则测试、查询调试工具 |
| `prometheus.yml` | 934 字节 | **默认配置**，Prometheus 第一个真正的应用配置文件 |
| `consoles/` | — | `/graph` 等页面的模板资源 |
| `console_libraries/` | — | 模板用到的 JS 库 |
| `LICENSE` / `NOTICE` | — | 许可证 |
| ~~`data/`~~ | **不存在** | TSDB 数据目录必须自己建、自己用参数指 |

- 对 `.tar.gz` 来说，**`tar -xzf` 成功本身就等于完整性校验**：gzip 会验尾部 CRC32 + ISIZE，截断必然报错。所以 `EXTRACT_OK` 不是"勉强解开了"，而是校验通过。sha256 校验属于独立来源的交叉验证，更稳但非必需。
- **必须 `cd` 进目录再运行**：`consoles/`、`console_libraries/` 是按**相对当前工作目录**找的资源。这也直接决定了 systemd unit 里 `WorkingDirectory=` 不能省。

### 5.4 版本验证

```bash
./prometheus --version
./promtool --version
```

本次输出：

```text
prometheus, version 2.53.0 (branch: HEAD, revision: 4c35b9250afefede41c5f5acd76191f90f625898)
  build user:       root@7f8d89cbbd64
  build date:       20240619-07:39:12
  go version:       go1.22.4
  platform:         linux/amd64
  tags:             netgo,builtinassets,stringlabels
```

逐项含义：

| 字段 | 含义 | 本次判断 |
|---|---|---|
| `version` | 版本号 | 2.53.0，LTS 线 |
| `revision` | 构建时的 git commit | 用于排错时对齐源码 |
| `go version` | 编译用的 Go 版本 | go1.22.4，与 node_exporter 同档 |
| `platform` | 目标平台 | linux/amd64，与本机一致 |
| `tags` | 构建标签 | 见下 |

三个构建标签：

- **`netgo`**：DNS 解析用 Go 自带的纯 Go 实现，不走 cgo → 不调用系统 glibc 的 `getaddrinfo`。这条让 glibc 2.17 的问题**彻底绕开**，和 node_exporter 静态链接是同一个方向的结论。
- **`builtinassets`**：把 Web UI 静态资源编译进了二进制，所以即使模板目录缺失，`/graph` 页面也还能用一份内置的。
- **`stringlabels`**：标签集内部用字符串存储的实现，属于构建期的内存/性能取舍。

`promtool` 的 `revision` 与 `prometheus` 完全相同 → 同一次构建产物，用它校验配置不会出现版本不匹配的问题。

### 5.5 下一步：默认配置与体检

```bash
cd ~/prometheus-2.53.0.linux-amd64
cat prometheus.yml
./promtool check config prometheus.yml
```

- 期望默认配置里 `global` 有 `scrape_interval: 15s`、`evaluation_interval: 15s`，`scrape_configs` 有一个 `job_name: "prometheus"` 抓 `localhost:9090`（**还没装完时它抓的是自己**，这是自监控）。
- `promtool check config` 相当于 `nginx -t`：只查语法和语义，不启动服务。成功输出 `SUCCESS: prometheus.yml is valid prometheus config file syntax`。
- 之后的目录规划（**尚未执行**）：程序 `/usr/local/prometheus/`、配置 `/etc/prometheus/prometheus.yml`、数据 `/var/lib/prometheus/`、账号 `prometheus`；unit 里必须有 `WorkingDirectory=` 或把 `--web.console.templates` / `--web.console.libraries` 写成绝对路径。