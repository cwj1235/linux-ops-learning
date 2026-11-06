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

### 5.5 默认配置与体检（2026-10-23 已完成，结果见第六节 6.1）

```bash
cd ~/prometheus-2.53.0.linux-amd64
cat prometheus.yml
./promtool check config prometheus.yml
```

- 期望默认配置里 `global` 有 `scrape_interval: 15s`、`evaluation_interval: 15s`，`scrape_configs` 有一个 `job_name: "prometheus"` 抓 `localhost:9090`（**还没装完时它抓的是自己**，这是自监控）。
- `promtool check config` 相当于 `nginx -t`：只查语法和语义，不启动服务。成功输出 `SUCCESS: prometheus.yml is valid prometheus config file syntax`。

## 六、Prometheus 系统化安装与 systemd 托管（2026-10-23 完成）

### 6.1 默认配置体检结果

```bash
cd ~/prometheus-2.53.0.linux-amd64
./promtool check config prometheus.yml
```

输出 `Checking prometheus.yml` + `SUCCESS: prometheus.yml is valid prometheus config file syntax`。

回传文本里 `global` 下面两行看着"没了缩进"，那是粘贴丢空格，不是文件坏了。**反证**：Prometheus 用严格 YAML 解码，若 `scrape_interval` 真顶格，它就变成顶层未知字段，`promtool` 必报 `field scrape_interval not found in type config.plain`，不可能给 SUCCESS。想眼见为实用：

```bash
sed -n '1,10p' prometheus.yml | cat -A
```

`cat -A` 把空格显示成可见字符、行尾显示成 `$`。**YAML 里缩进不是排版，是语法**——两个空格代表"属于上一级"。

默认配置四块：

| 块 | 内容 | 含义 |
|---|---|---|
| `global` | `scrape_interval: 15s`、`evaluation_interval: 15s` | 抓取周期、规则评估周期；注释说默认各 1 分钟，这里显式改成 15s |
| | `# scrape_timeout` 被注释 | 注释写明"跟随全局默认 10s"。**超时必须小于抓取间隔**，否则上轮没抓完下轮又来 |
| `alerting` | `alertmanagers: - static_configs: - targets:` | 结构在，`targets` 下只有一个被注释掉的 `alertmanager:9093` → 空列表，**当前没有告警接收方** |
| `rule_files` | 只有两行注释 | 一条规则都没加载 |
| `scrape_configs` | `job_name: "prometheus"` → `targets: ["localhost:9090"]` | 唯一在干活的块：抓自己，即**自监控** |

- `job_name` 会成为该任务所有数据的 `job="..."` 标签，所以后面加任务时起名 `node_exporter`，就能用 `job="node_exporter"` 精确筛选。
- `metrics_path` 默认 `/metrics`、`scheme` 默认 `http`（都在注释里写明），node_exporter 正好符合默认值，不用改。

### 6.2 目录三分法与账号

| 目录 | 属主 | 放什么 | 为什么 |
|---|---|---|---|
| `/usr/local/prometheus` | root | 二进制 + `consoles/` + `console_libraries/` | 服务只读、只执行，**改不了自己的二进制** |
| `/etc/prometheus` | root | `prometheus.yml` | 服务只读配置。能改自己配置的服务 = 被拿下就有持久化后门 |
| `/var/lib/prometheus` | prometheus | TSDB（`wal/`、`chunks_head/`） | 唯一必须写的地方 |

```bash
sudo useradd --system --no-create-home --shell /bin/false prometheus
sudo mkdir -p /usr/local/prometheus /etc/prometheus /var/lib/prometheus
sudo cp prometheus promtool /usr/local/prometheus/
sudo cp -r consoles console_libraries /usr/local/prometheus/
sudo cp prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /var/lib/prometheus
```

- `--system` → `uid=985 gid=978`，落在系统账号区间（201–999；普通用户从 1000 起）。
- `--shell /bin/false` → 登不进去。服务账号的原则是**能跑服务、不能登录**。
- `--no-create-home` → 不建家目录，"家"由 unit 的 `WorkingDirectory` 指定。
- 三目录 `ls -ld` 显示大小 `6`，是 **xfs 空目录特征**（ext4 才显示 4096），不是没建成功。
- `cp` 保留执行位 → `-rwxr-xr-x root root`。只 chown 数据目录，程序与配置**故意留 root**。这与 MySQL 那节「服务账号不该有 DBA 权限」是同一条最小权限原则在文件系统层的等价形式：多给的权限就是未来的漏洞入口。

### 6.3 unit 文件与逐行职责

```ini
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
WorkingDirectory=/usr/local/prometheus
ExecStart=/usr/local/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/ --web.console.templates=/usr/local/prometheus/consoles --web.console.libraries=/usr/local/prometheus/console_libraries
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

| 行 | 作用 |
|---|---|
| `After=` / `Wants=network-online.target` | `After` 只管启动顺序，`Wants` 才把依赖拉起来，**两个都要** |
| `Type=simple` | `ExecStart` 起的进程本身就是主进程，systemd 直接盯，不需要 fork |
| `User=` / `Group=` | 以 prometheus 身份跑 → 前面那套文件权限才真正生效 |
| `WorkingDirectory=` | **相对路径的基准**。`--web.console.templates` 默认相对 `./consoles`，靠它才不会找错；本例同时写了绝对路径，双保险 |
| `Restart=on-failure` + `RestartSec=5` | 自愈；`RestartSec` 防"秒崩—重启"打满 CPU |
| `WantedBy=multi-user.target` | `enable` 时据此建开机软链接 |

写入手法（单引号 heredoc 防 shell 替换，保证文件里的 `$` 不被吃掉）：

```bash
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
...（内容同上）
EOF
```

`ExecStart` 特意写成一整行、不用 `\` 续行：续行是合法语法，但粘贴时最容易坏。文件属主保持 root、644——**它改不了自己的启动参数**。

### 6.4 启动与四项验证（全部实测）

```bash
systemctl cat prometheus                          # 先看 systemd 读到的内容对不对
sudo systemctl daemon-reload                      # 新增/改 unit 后必做
sudo systemctl enable --now prometheus
systemctl status prometheus --no-pager
sudo ss -lntp | grep 9090
curl -s 127.0.0.1:9090/-/healthy; echo
curl -s 127.0.0.1:9090/api/v1/targets | grep -o '"health":"[a-z]*"'
sudo ls -l /var/lib/prometheus
```

实测结果：

| 项 | 实际输出 | 判读 |
|---|---|---|
| status | `active (running)`、MainPID 6471、`Tasks: 9`、`Memory: 18.1M`、`enabled` | `Tasks` 是**线程数**（Go 调度 + GC），进程只有 1 个；`vendor preset: disabled` 是 CentOS 出厂默认，自启是我们开的 |
| ss | `LISTEN 0 1024 [::]:9090 users:(("prometheus",pid=6471,fd=7))` | 非 root 跑 `ss -lntp` 进程列为空，**不是没监听，是权限不足看不到** |
| healthy | `Prometheus Server is Healthy.` | 存活探针。`/-/ready` 含义不同：还要求 TSDB 加载完、能接查询。生产上分别对应 liveness / readiness |
| targets | `"health":"up"` | 抓取成功的机器可读证据；失败看同份 JSON 的 `lastError`。脚本巡检优先用它 |
| 数据目录 | `chunks_head/`、`lock`(0)、`queries.active`(20001)、`wal/` | TSDB 落地：从"内存里一个数"变成"磁盘上有块目录" |

### 6.5 三个能直接记住的细节

1. **`fd=7`** 与 node_exporter 实测的「常驻 7 + 并发连接数」模型一致 → Go 服务基础 fd 占用同构（stdin/out/err、epoll、信号管道、监听 socket 等）。两个独立程序对上同一个数，说明模型可靠。
2. **`queries.active` 20001 字节** = 1 字节文件头 + 20 槽 × 1000 字节，正好对应默认 `--query.max-concurrency=20`（槽里存正在跑的查询语句，最长 1000 字节）。**一个文件大小把启动参数暴露了**。
3. **`lock`（0 字节）是单实例锁**：第二个 Prometheus 打开同一数据目录会直接报错退出，防止两个进程同时写坏 TSDB。

存储机制串起来：

```text
抓取 → wal/（预写日志，追加写，崩溃不丢最近数据）
     → chunks_head/（内存块，攒约 2 小时）
     → 01BK.../ 块目录（压缩落盘，默认保留 15 天，到期整块删除）
```

### 6.6 安全边界与后续

- 监听 `[::]:9090` = **所有网卡**，且**无任何认证**（无 basic auth、无 TLS、无反向代理）。这台机器必须保持隔离；要收敛就加 `--web.listen-address=127.0.0.1:9090`（和 node_exporter 那条"未做（可选）：监听地址收敛"同一件事）。
- 未设 `LimitNOFILE`：现在 2 个目标远够；目标上百才是问题，与 fd 模型同源。
- 未加 `--web.enable-lifecycle`：所以 `curl -X POST 127.0.0.1:9090/-/reload` 会被拒（403）。改配置只有两条路——`systemctl restart`（简单，有短暂中断），或加该参数后用 `/-/reload`（热加载，但这个端点会变成任何人都能触发）。
- 未做：Grafana（3000）、Alertmanager（9093）、告警规则、`/targets` 网页验收。

### 6.7 下一步

把 `127.0.0.1:9100` 加为第二个 job：末尾追加、`-` 前 2 空格对齐 `scrape_configs` 列表，`promtool check config` 通过后再重启，最后用 `up` 指标确认两个目标都 UP。
- 之后的目录规划（**尚未执行**）：程序 `/usr/local/prometheus/`、配置 `/etc/prometheus/prometheus.yml`、数据 `/var/lib/prometheus/`、账号 `prometheus`；unit 里必须有 `WorkingDirectory=` 或把 `--web.console.templates` / `--web.console.libraries` 写成绝对路径。

> 本节 6.7 的内容已于 2026-10-24 执行完毕，结果见第七节。

## 七、抓取任务接入与第一条 PromQL（2026-10-24 完成）

### 7.1 配置长什么样

`prometheus.yml` 里决定"抓谁"的是 `scrape_configs` 列表。默认只有一个 job：

```yaml
scrape_configs:
  - job_name: "prometheus"          # 2 空格 + "- "，即列表项
    static_configs:                 # 4 空格
      - targets: ["localhost:9090"] # 6 空格
```

追加第二个 job，缩进必须与上面完全同级（`- job_name` 前 2 空格、`static_configs` 前 4、`- targets` 前 6）：

```yaml
  - job_name: "node_exporter"
    static_configs:
      - targets: ["127.0.0.1:9100"]
```

用 `sudo tee -a ... > /dev/null <<'EOF'` 追加。单引号 heredoc 的作用是禁止变量替换，否则配置里出现 `$` 会被 shell 吃掉；`> /dev/null` 是因为 `tee` 默认把内容也打到屏幕，追加时没必要刷屏。

**缩进错一格的后果**：`- job_name` 若与 `scrape_configs:` 齐平，就变成顶层的另一个键，Prometheus 会报 unknown field；若多缩进，则可能被当成上一个 job 的字段，出现"两个 job 合并成一个"这种更难查的错。所以改完必须 `tail -n 8 ... | cat -A` 回读，`cat -A` 把行尾显示成 `$`，缩进和漏换行一眼可见。

### 7.2 `promtool check config` 验证的是什么、不验证什么

```text
SUCCESS: /etc/prometheus/prometheus.yml is valid prometheus config file syntax
```

- **验证**：YAML 语法、字段名是否合法、类型是否对、正则能否编译、必填项是否缺失。
- **不验证**：目标是否可达、9100 是否在监听、抓取会不会超时。**语法通过 ≠ 能抓到数据**，这两件事必须分开验收。

这就是为什么流程固定为「check config → restart → 看日志 → 查 `up`」，四步各自负责一段。

### 7.3 重启后的日志证据链

`systemctl restart prometheus` 之后，`journalctl -u prometheus` 按顺序出现（截取关键行）：

```text
msg="Found healthy block" ... ulid=01M5P612XYVJKT1VEAWPB7KEXV
msg="Replaying WAL, this may take a while"
msg="WAL replay completed" ... total_replay_duration=281.801809ms
msg="TSDB started"
msg="Loading configuration file" filename=/etc/prometheus/prometheus.yml
msg="updated GOGC" old=100 new=75
msg="Completed loading of configuration file" ... scrape=1.814627ms
msg="Server is ready to receive web requests."
```

逐条含义：

| 日志 | 说明 |
|---|---|
| `Found healthy block` | 磁盘上已有的块目录被校验通过。本次 **4 条** |
| `Replaying WAL` / `WAL replay completed` | 把预写日志里尚未压缩的最新数据补回内存，本次 281.8ms |
| `TSDB started` | 时序库就绪 |
| `Loading configuration file` → `Completed ...` | 配置重新加载，`scrape=1.81ms` 是解析耗时 |
| `Server is ready to receive web requests.` | 可以对外服务 |

**这组日志是"重启不丢数据"的实证**：块 + WAL 都成功加载，说明上次运行写入的数据在磁盘上完好。

两个容易误判的点：

1. `updated GOGC old=100 new=75` —— 2.53 启动时按自身内存策略把 GC 目标从 Go 默认的 100 调到 75（更积极地回收），是版本行为，不是配置错误。
2. `MainPID 6471 → 3917` —— `systemctl restart` 本质是 stop + start，**必然产生新进程新 PID**。看到 PID 变化不要当成异常；要确认服务身份应看 unit 名，而不是记 PID。

### 7.4 块的时间跨度与断档

四条 `Found healthy block` 的 `mint` / `maxt` 都是毫秒时间戳，换算后：

| ulid | 覆盖区间（CST） |
|---|---|
| `01M5P6131NQYBNQJCB11DESMKS` | 10-23 17:55 → 20:00 |
| `01M5P612XYVJKT1VEAWPB7KEXV` | 10-23 20:00 → 22:00 |
| `01M5P612Z5VWRVESKRBJE9966Y` | 10-23 22:00 → 10-24 00:00 |
| `01M5PCWT53GYFV286H6B798PK8` | 10-24 12:27 → 14:00 |

`maxt - mint = 7200000 ms = 2 小时`，**实测印证**了第六节那句"`chunks_head` 攒约 2 小时压缩成一个块目录"——不再只是文档转述。

注意块覆盖在 00:00 之后直接跳到 12:27，而当天 journal 从 `13:26:28` 才开始。这说明中间虚拟机没在运行（或开机时时钟未同步）。**Prometheus 不回填停机期间的数据**，重启后从当前时刻继续写入；查询该时段会看到空段，这是正常现象，不是采集丢失。

### 7.5 `up` 指标：第一条 PromQL

```bash
curl -s '127.0.0.1:9090/api/v1/query?query=up'
```

返回两条序列：

```json
{"metric":{"__name__":"up","instance":"localhost:9090","job":"prometheus"},"value":[1792827833.710,"1"]}
{"metric":{"__name__":"up","instance":"127.0.0.1:9100","job":"node_exporter"},"value":[1792827833.710,"1"]}
```

要理解三个概念：

1. **`up` 不是被监控端提供的指标**，而是 Prometheus 自己**每次抓取后生成**的合成指标：抓到 = 1，失败 = 0。所以它是最可靠的"链路是否通"信号。
2. **`job` 标签**来自配置里的 `job_name`；**`instance` 标签**来自 `targets` 里的地址**字面值**——写 `localhost:9090` 就显示 `localhost:9090`，写 `127.0.0.1:9100` 就显示 `127.0.0.1:9100`。两者指向同一台机器，标签却不同，说明 Prometheus 不做地址规范化。
3. **一条序列（series）= 指标名 + 完整标签集**。两条 `up` 的指标名相同、标签不同，所以是两条独立序列，各有自己的历史。

`value` 数组是 `[时间戳, 数值字符串]`，时间戳 `1792827833.710` = 2026-10-24 15:43:53 CST，单位秒、带毫秒小数。注意数值是**字符串** `"1"` 而非数字 1，这是 Prometheus HTTP API 的约定（避免浮点精度丢失）。

### 7.6 下一步

数据面验收 → Grafana。选版需注意：官方 requirements 只写「Red Hat / RHEL / Fedora」，未点名 CentOS 7；本机内核 `3.10.0-1160.el7` 这组环境有 Grafana 10.4.x 的成功部署记录，倾向 10.4.x 而非最新版，下载后先 `--version` 验证再安装。

### 7.7 HTTP API 调用方式（`curl -G` 与 `--data-urlencode`）

Prometheus 的查询接口是 HTTP API，`curl` 只是客户端。完整链路：

```text
curl（终端） → GET /api/v1/query → PromQL 引擎解析 → TSDB 取样本 → JSON 返回终端
```

两种写法等价，但适用场景不同：

```bash
# 写法一：查询简单，可手工拼
curl -s '127.0.0.1:9090/api/v1/query?query=node_load1'

# 写法二：查询含空格/花括号/引号，必须自动编码
curl -sG 127.0.0.1:9090/api/v1/query --data-urlencode 'query=count({__name__=~"node_.*"})'
```

- `--data-urlencode` 默认把数据放进**请求体**（POST）；加 `-G` 后改为拼到 URL 的 `?` 后面（GET）。两个参数必须一起用。
- `--data-urlencode` 负责百分号编码：空格 → `%20`、`{` → `%7B`、`"` → `%22`。手写编码必错，一律交给 curl。
- 单引号防止 shell 解析 `{`、`}`、`"`、`=`。

`-G` 的作用位置用 `-v` 可直接看到（实测输出）：

```text
# 不加 -G
> POST http://127.0.0.1:18089/api/v1/query HTTP/1.1
> Content-Length: 16
> Content-Type: application/x-www-form-urlencoded
   （body 里是 query=node_load1，正好 16 字节）

# 加 -G
> GET http://127.0.0.1:18089/api/v1/query?query=node_load1 HTTP/1.1
   （没有 Content-Length / Content-Type，因为请求体为空）
```

三处可见差异：① 方法 `POST` → `GET`；② URL 末尾多出 `?query=node_load1`；③ 少了两个 body 相关请求头。

**重要澄清**：Prometheus 的 API 端点**同时接受 GET 和 POST**（POST 要求参数 URL 编码后放 body），所以 `-G` 不影响查询能否成功，它只决定"参数放 URL 还是放请求体"。坚持用 `-G` 的实际理由有三条：① URL 自包含，可直接贴浏览器、贴 Grafana、贴给别人；② GET 是只读幂等语义，部分代理/缓存只放行 GET；③ 排查时一眼看到完整查询，不用翻 body。

代价：URL 有长度上限（常见 2KB～8KB），超长 PromQL 反而应去掉 `-G` 用 POST。`--get` 是 `-G` 的长写法。

编码差距有多大，看这个例子：

```text
原始：count({__name__=~"node_.*"})
编码：count%28%7B__name__%3D~%22node_.%2A%22%7D%29
```

`node_load1` 这种纯字母数字手工拼没问题；一旦有 `{ } " = *`，手工拼几乎必然出错。

响应骨架固定：

```json
{"status":"success",
 "data":{"resultType":"vector",
         "result":[{"metric":{"__name__":"node_load1","instance":"127.0.0.1:9100","job":"node_exporter"},
                    "value":[1792827833.710,"0.08"]}]}}
```

| 字段 | 含义 |
|---|---|
| `status` | `success` / `error`；**查询语法错时这里仍是 success**，错误在 `errorType` 与 `error` |
| `resultType` | `vector`（瞬时）/ `matrix`（区间，`query_range` 返回）/ `scalar` / `string` |
| `result` | 数组，每个元素一条序列 |
| `metric` | 该序列的完整标签集 |
| `value` | `[时间戳, 数值]`，数值是**字符串**——float64 转 JSON 数字会丢精度，故统一输出字符串 |

### 7.8 序列（series）的定义：为什么 `count()` 是千位

**一条序列 = 指标名 + 一整套标签值**，任一标签值不同即另一条序列。

```text
node_cpu_seconds_total{cpu="0",mode="idle"}  → 第 1 条
node_cpu_seconds_total{cpu="0",mode="user"}  → 第 2 条
node_cpu_seconds_total{cpu="1",mode="idle"}  → 第 3 条
```

`node_cpu_seconds_total` 的 `mode` 有 8 种（idle/iowait/irq/nice/softirq/steal/system/user），2 核就是 16 条；磁盘按 `device`、网卡按 `device`、文件系统按 `mountpoint` 再各自分裂。

**这里有一个容易说反的地方（2026-10-27 实测修正）**：`/metrics` 里每一行是**一条序列的当前样本**，不是"一个指标名"。所以 `grep -c '^node_'` 数出的 681 就是**序列数**，与 `count({__name__=~"node_.*"})` 的 681 完全相等。指标**名**数远小于 681（`node_cpu_seconds_total` 只算 1 个名字，却贡献 16 条序列）。正确的区分是：

| 数法 | 得到什么 |
|---|---|
| `grep -c '^node_'`（在 `/metrics` 上） | 序列数（每行一个序列的样本） |
| `count({__name__=~"node_.*"})` | 序列数（同一个数，互相印证） |
| 指标名数 | 需要 `count(count by (__name__) (...))` 才数得出来，量级小得多 |

选择器语法要点：

- `{__name__=~"node_.*"}`：`__name__` 是"指标名"这个特殊标签；`=~` 是正则匹配且**完全锚定**（等价 `^node_.*$`）。
- 指标名单独写（如 `node_load1`）等价于 `{__name__="node_load1"}`。
- `count(...)` 数的是**序列条数**，不是样本点数。

### 7.9 数据面验收的三层

`up=1` 只证明「HTTP 抓取拿到 200」，不能证明数据可用。验收分三层，各验一次：

| 层 | 命令 | 验证什么 |
|---|---|---|
| 目标状态 | `/api/v1/targets` | `scrapeUrl` / `health` / `lastError` / `scrapeInterval` |
| 入库规模 | `count({__name__=~"node_.*"})` | 序列确实写进了 TSDB，量级合理 |
| 数值可信 | `node_memory_MemAvailable_bytes / 1024 / 1024` 对照 `free -m` | 采集→存储→查询全链路无偏差 |

第三层最关键：只有监控数字和系统命令对得上，才排除了"解析失败、时间戳错位、样本被丢"这类 `up` 看不出来的问题。

### 7.10 三层验收实测结果（2026-10-27 全部通过）

**第一层：目标状态**

```text
"scrapeUrl":"http://127.0.0.1:9100/metrics"   "lastError":""  "health":"up"  "scrapeInterval":"15s"
"scrapeUrl":"http://localhost:9090/metrics"   "lastError":""  "health":"up"  "scrapeInterval":"15s"
```

两个目标都 up、都无历史错误、都是 15s。`scrapeUrl` 的构成是 `协议 + instance + metrics_path`，`/metrics` 是默认路径。第二个目标是 Prometheus **抓自己**——Prometheus 同样暴露 `/metrics`，所以能监控自身（`prometheus_*` 指标）。

**第二层：入库规模**

```text
count({__name__=~"node_.*"}) → 681
```

与 node_exporter 页面上 `grep -c '^node_'` 的 681 精确相等，两条独立路径互相印证。

**第三层：数值可信**

```text
PromQL: node_memory_MemAvailable_bytes / 1024 / 1024 → 1152.6640625
free -m available                                      → 1152
```

两者吻合。`free -m` 的整数是截断显示，PromQL 保留了小数部分，所以 `1152.6640625` 向下取整正好是 1152。这一条通过，等于把"采集 → 存储 → 查询"整条链路验完了。

### 7.11 两个 PromQL 细节

**① 算术运算会丢掉指标名。**

`node_memory_MemAvailable_bytes / 1024 / 1024` 的返回里 `metric` 只有 `instance` 和 `job`，**没有 `__name__`**：

```json
{"metric":{"instance":"127.0.0.1:9100","job":"node_exporter"},"value":[1793089843.222,"1152.6640625"]}
```

原因：除完之后结果已不是"可用内存字节数"这个指标，数值单位变了，名字继续挂着会误导。PromQL 的规则是**任何算术运算都清除指标名**（标签保留）。所以后续要按名字筛选结果，必须用 `label_replace` 或 `by (instance)` 之类显式指定。

**② 聚合函数返回的 `metric` 是空对象。**

`count(...)` 的返回是 `"metric":{}`——因为 `count()` 把所有标签都聚合掉了，结果是一条无标签的标量型序列。想看"每个实例各多少条"，要写 `count by (instance) (...)`。

**③ 预测与实测的偏差（记一笔）。**

上一轮我判断"序列数是千位量级"，实测 681，**预测偏高约 30%**。机理（标签分裂）没错，量级估算是拍脑袋的。结论：涉及具体数字时，先量再说，不要用"量级"糊过去。

### 7.12 下载参数 `-L` 与 `-O`（`-LO` 是两个开关）

`-LO` 不是一个参数，是 `-L` 和 `-O` 两个独立开关的连写，顺序无关。它们管两件不相干的事：

| 开关 | 长写法 | 管什么 |
|---|---|---|
| `-L` | `--location` | 遇到 3xx 跳转时**继续跟过去** |
| `-O` | `--remote-name` | 把响应体**存成文件**，文件名取 URL 最后一段 |
| `-o 名字` | `--output` | 存成文件，**文件名自己指定**（小写，别和大写混） |

本机实测（自建 302 跳转服务，curl 8.21）：

```text
A. curl -o /dev/null /redir              → HTTP 302，url_effective 仍是 /redir，不跟
B. curl -L -o /dev/null /redir           → HTTP 200，url_effective 变成跳转后的地址
C. curl /file.tar.gz                     → 内容直接打到屏幕，磁盘无文件
D. curl -O /file.tar.gz                  → 生成 file.tar.gz
```

**`-L` 的实际必要性**：下载站常把请求 302 到 CDN，不加 `-L` 只能拿到一个空的跳转响应。但本次实测 `https://dl.grafana.com/oss/release/grafana-10.4.19.linux-amd64.tar.gz` 返回 `200`、`重定向次数 0`，即**这个地址本身不跳转**，`-L` 属于防御性写法（加了不吃亏，不加也通）。默认最多跟 50 次跳转，可用 `--max-redirs` 限制；跟到别的域也照样跟，这是它的安全边界。

**`-O` 的规则**：文件名来自 **URL 路径的最后一段**，与服务器的 `Content-Disposition` 无关。所以 URL 末尾带不带文件名，直接决定落盘叫什么。

**坑（版本相关）**：URL 带查询串时，`-O` 的文件名处理随 curl 版本变化。本机 curl 8.21 实测 `...tar.gz?v=10.4.19` 落盘为 `grafana-10.4.19.linux-amd64.tar.gz`（查询串被剥掉）；CentOS 7 自带的是 **curl 7.29**，行为不保证一致。结论：**URL 带 `?` 时一律用 `-o 文件名` 显式命名**，不要依赖 `-O` 的猜测。

下载大文件的标准组合：

```bash
curl -LO <url>          # 跟跳转 + 按 URL 名字落盘
ls -l <文件名>          # 核对字节数是否等于 Content-Length
```

`-C -` 断点续传同样可以叠加：`curl -LO -C - <url>`。注意 `-C -` 必须与 `-O` 一起用，且目标文件已存在时才能续。

**续传前提**：服务端必须支持 Range 请求。实测 `dl.grafana.com` 对 `Range: bytes=0-99` 返回 `HTTP 206` + 100 字节，说明**支持断点续传**，`-C -` 与 `wget -c` 都能用。

**坑：`--retry` 默认不覆盖所有错误码（2026-10-27 实测踩中）。**

Windows 侧下载 Grafana 包时，在 8,708,852 字节（7%）处中断：

```text
curl: (56) schannel: server closed abruptly (missing close_notify)
完成: HTTP 200 大小 8708852 字节 用时 211.8s 平均 41120 B/s
```

- `(56)` = `CURLE_RECV_ERROR`，接收数据阶段连接被对端掐断。
- `schannel` 是 **Windows 自带的 TLS 后端**（Linux 用 OpenSSL/GnuTLS）。它要求 TLS 关闭时收到规范的 `close_notify` 告警，CDN/代理直接断链就会报这条。**同一个地址在 Linux 上通常不报这个错**——这是平台差异，不是文件坏了。
- 加了 `--retry 3` 仍然没重试，因为 **`--retry` 只覆盖少数错误码**（超时、5xx、部分连接错误），**不含 56**。要覆盖必须加 `--retry-all-errors`（curl 7.71+ 才有，CentOS 7 的 7.29 没有）。

可靠写法是「外层循环 + 续传」：

```bash
T=120000970
for i in $(seq 1 40); do
  cur=$(stat -c %s pkg.tar.gz 2>/dev/null || echo 0)
  [ "$cur" -ge "$T" ] && break
  curl -L -C - --retry 5 --retry-all-errors --retry-delay 5 -o pkg.tar.gz "<url>"
  sleep 2
done
```

**方法论**：`--retry` 是"有限重试"，不是"无限重试"；断线重连这类场景，循环 + `-C -` 比任何单条参数都可靠。这与早前 Prometheus 下载的结论一致。

**国内镜像探测结果（2026-10-27）**：`mirrors.tuna.tsinghua.edu.cn/grafana` 连不上（HTTP 000）、`mirrors.ustc.edu.cn/grafana` 与 `mirrors.aliyun.com/grafana` 均 404。**Grafana 没有主流国内镜像**，只能走 `dl.grafana.com`。

**续传最终结果（2026-10-27）**：累计约 1 小时 17 分下到 114,445,451 字节（95.4%），最后 5,555,519 字节用 4 分 29 秒续完，终态 `120000970`，`certutil` 计算的 SHA256 与官方值完全一致。

**判断进度的正确依据**：看**本地文件大小**（`stat -c %s` / `ls -l`），不要用 curl 报的 `end of response with N bytes missing` 去反推总量——那条 `(18)` 只是某一轮的瞬时快照。本次曾据此误判为"只下了 51%"，实际已到 95.4%。

**Windows 与 Linux 的行为差异汇总**：

| 现象 | Windows（schannel + curl 8.21） | Linux（OpenSSL + curl 7.29） |
|---|---|---|
| TLS 被对端强断 | `curl: (56) schannel: server closed abruptly` | 通常静默结束或报 `(18)` |
| 全错误码重试 | 有 `--retry-all-errors` | **7.29 无此参数**，只能外层循环 |
| `-O` 遇查询串 | 8.21 会剥掉 `?` 之后部分 | 7.29 行为不保证一致 |

### 7.13 其他下载方式对比

| 方式 | 典型命令 | 优势 | 局限 |
|---|---|---|---|
| `wget` | `wget -c <url>` | CentOS 7 自带；**默认跟随跳转、默认按 URL 名存盘**，无需 `-L`/`-O` | 单线程，慢链路无解 |
| `curl` | `curl -LO -C - <url>` | 通用，可精确控制请求头与编码 | 需显式加 `-L`、`-O` |
| `aria2c` | `aria2c -x16 -s16 <url>` | 多线程分段下载，对限速链路提速明显 | 需 `epel-release` + `aria2` |
| `yum` | `yum install grafana` | 依赖自动解决，自带 systemd unit | 版本受仓库限制，路径与手工 tarball 不同 |
| `scp` / `rz` | `scp 包 atguigu@host:~` | 绕开虚拟机出网慢，用本机带宽 | 需先在本机下好，且 SSH 可达 |

**`wget` 与 `curl` 的关键差异**：`wget <url>` 一条命令就完成了"跟跳转 + 按 URL 名存盘"，而 `curl` 必须写 `-LO`。所以纯下载场景 `wget` 更省事；需要改请求头、控制编码、看详细请求时用 `curl`。

**`wget -c` 比 `curl -C -` 更稳**：`wget -c` 在文件已完整时会提示"文件已下载完毕"并退出，不会重复传输；`curl -C -` 需要自己判断起始偏移。断线重连场景优先 `wget -c`。

**`aria2c` 装法（CentOS 7）**：

```bash
sudo yum install -y epel-release
sudo yum install -y aria2
aria2c -x 16 -s 16 -k 1M <url>
```

`-x16` = 每个服务器最多 16 个连接，`-s16` = 分成 16 段，`-k1M` = 每段 1 MiB。对 44 KB/s 那种被限速的单连接，多连接常能提升数倍。

**Grafana 官方 yum 仓库**（`https://rpm.grafana.com/gpg.key` 实测 200 可达）：写入 `/etc/yum.repos.d/grafana.repo` 后 `yum install grafana`。但仓库只保留较新版本，10.4.19 未必还在；且 yum 安装会自带 unit 与默认路径（`/etc/grafana`、`/var/lib/grafana`、`/usr/share/grafana`），与本项目"手工 tarball + 自建 unit"的教学路线不一致。**作为备选，不作主路线。**

### 7.14 Windows 侧下载 + 传入虚拟机（推荐用于慢链路）

虚拟机出网慢时，用本机带宽下载再传进去，比在虚拟机里硬扛省时间。

**第一步：在 Windows 下载**

浏览器直接点，或用 Windows 自带的 `curl.exe`：

```powershell
cd $env:USERPROFILE\Downloads
curl.exe -LO https://dl.grafana.com/oss/release/grafana-10.4.19.linux-amd64.tar.gz
```

**坑**：PowerShell 里 `curl` 是 `Invoke-WebRequest` 的别名，参数体系完全不同。必须写 **`curl.exe`** 才是真正的 curl。

**第二步：校验（比看大小更可靠）**

Grafana 为每个包提供 `.sha256` 旁文件（实测 200 可下）：

```text
https://dl.grafana.com/oss/release/grafana-10.4.19.linux-amd64.tar.gz.sha256
→ 110006a65a90195bcb7fe5a8b53ca152a26b6179454a5fd137be093c24244ef8
```

Windows 自带 `certutil` 算哈希：

```powershell
certutil -hashfile grafana-10.4.19.linux-amd64.tar.gz SHA256
```

两个值逐字符相同才算下载完整。**大小对得上但哈希不对，说明文件被中间设备改过或拼接错误**，哈希是更强的证据。

**第三步：传进虚拟机**

在 Windows 侧执行（Win10 1803+ 自带 OpenSSH）：

```powershell
scp "C:\Users\<用户名>\Downloads\grafana-10.4.19.linux-amd64.tar.gz" atguigu@<虚拟机IP>:~/
```

虚拟机 IP 用 `hostname -I` 或 `ip addr` 查。备选方案：Xshell/SecureCRT 的 ZMODEM（虚拟机装 `lrzsz` 后执行 `rz -y`，终端弹出发送对话框）。

**坑：`hostname -I` 会一次返回多个地址，不能全粘进 scp。**

本机实测 `hostname -I` 输出 `192.168.6.100 192.168.122.1 172.17.0.1`，三个地址含义完全不同：

| 地址 | 归属 | Windows 能否连 |
|---|---|---|
| `192.168.6.100` | 主网卡（eth0/ens33），与 Windows 同网段 | **能** |
| `192.168.122.1` | libvirt 网桥 `virbr0`，给嵌套虚拟机当网关 | 不能 |
| `172.17.0.1` | docker0 网桥，容器网络 | 不能 |

实测 22 端口只有 `192.168.6.100` 可连通，另两个超时。判断方法：看 Windows 本机 `ipconfig` 的网段，选同网段的那个；或直接探端口。

```powershell
# 正确写法：单个目标 + 冒号 + 路径
scp "$env:USERPROFILE\Downloads\grafana-10.4.19.linux-amd64.tar.gz" atguigu@192.168.6.100:~/
```

两个易错点：① **必须只写一个目标**，多写几个会被 scp 当成多个参数，最后尝试的那个超时就报 `Connection timed out`；② **IP 后面必须有冒号**（`主机:路径`），漏了冒号 scp 会把 `atguigu@192.168.6.100` 当成本地文件名。

若报 `subsystem request failed`，加 `-O` 强制用旧 SCP 协议：`scp -O 源 目标`。

**Git Bash 的额外坑**：中文用户名会让 `ssh` 写 `known_hosts` 失败（实测报 `Failed to add the host to the list of known hosts (/c/Users/\263\302\316\260\356\322/.ssh/known_hosts)`，路径被 GBK 编码破坏）。**传输统一用 PowerShell 的 `scp`**，它走 `C:\Windows\System32\OpenSSH`，不经过 Git Bash 的路径转换。

**坑：解压目录名 ≠ 压缩包文件名（2026-10-27 实测）。**

```text
压缩包：grafana-10.4.19.linux-amd64.tar.gz
解压后：grafana-v10.4.19/          ← 多一个 v，少了 .linux-amd64
```

用户按包名拼路径 `./grafana-10.4.19.linux-amd64/bin/grafana`，bash 报“没有那个文件或目录”。**哈希校验已通过、文件完好**，纯粹是路径写错。

包内实际结构（`tar -tzf` 核对）：

| 路径 | 大小 | 说明 |
|---|---|---|
| `bin/grafana` | 203,779,136 | 主程序，前端资源已编译进二进制 |
| `bin/grafana-server` | 2,463,936 | 兼容旧入口 |
| `bin/grafana-cli` | 2,463,904 | 插件管理 |
| `conf/` | — | `sample.ini`、`ldap.toml`、`provisioning/` |
| `tools/zoneinfo.zip` | — | 时区数据，容器场景用 |

**通用做法**：不要用压缩包名猜解压目录。解压前 `tar -tzf 包.tar.gz | head -3`，解压后 `ls -d ~/grafana-*/`，两步任一都能确认真名。Grafana 的命名规律是 `grafana-v<版本>`，与 `-linux-amd64` 后缀无关。

**第四步：虚拟机侧二次校验**

```bash
ls -l grafana-10.4.19.linux-amd64.tar.gz      # 期望 120000970
sha256sum grafana-10.4.19.linux-amd64.tar.gz  # 期望 110006a6...
```

`scp` 本身有完整性校验，但跨系统传输（尤其经中文路径）仍建议复核一次——`tar -xzf` 报"异常的 EOF"时才回头查，代价更大。

## 八、Grafana 10.4.19 安装与 systemd 托管（2026-10-27 完成）

### 8.1 包结构：目录名不等于包名

```text
包名：grafana-10.4.19.linux-amd64.tar.gz
解压：grafana-v10.4.19/          ← 多 v、少 -linux-amd64
```

包内顶层：`bin/`、`conf/`、`public/`、`plugins-bundled/`、`npm-artifacts/`、`storybook/`、`VERSION`、`LICENSE`、`NOTICE.md`、`README.md`、`Dockerfile`。

`conf/` 里有 `defaults.ini`（**运行时必需**）、`sample.ini`（配置模板）、`ldap.toml`、`provisioning/`。

| 二进制 | 大小 | 用途 |
|---|---|---|
| `bin/grafana` | 203,779,136 | 主程序，前端资源编译进二进制 |
| `bin/grafana-server` | 2,463,936 | 兼容旧入口 |
| `bin/grafana-cli` | 2,463,904 | 插件管理 |

`npm-artifacts/`、`storybook/` 是开发文档与前端构建产物，运行不需要，可不拷。

### 8.2 目录三分法与账号

```bash
sudo useradd --system --no-create-home --shell /bin/false grafana   # uid=984 gid=977
sudo mkdir -p /usr/local/grafana /etc/grafana /var/lib/grafana
```

| 目录 | 内容 | 属主 |
|---|---|---|
| `/usr/local/grafana` | 程序、`public/`、`plugins-bundled/`、`conf/defaults.ini` | root |
| `/etc/grafana` | `grafana.ini` | root |
| `/var/lib/grafana` | SQLite 库、插件、会话 | **grafana** |

与 Prometheus 完全同构：服务账号不能改自己的二进制和启动参数。

**坑：`cp -a` 会保留源属主。** 从 `atguigu` 解压的目录拷过去，文件属主仍是 `atguigu`：

```text
-rwxr-xr-x. 1 atguigu atguigu 203779136 grafana   ← 不对
```

修法 `sudo chown -R root:root /usr/local/grafana`。之前装 Prometheus 用的是不带 `-a` 的 `cp`，属主自动变 root，所以没暴露这个问题。

### 8.3 配置：只改三处

```bash
sudo cp /usr/local/grafana/conf/sample.ini /etc/grafana/grafana.ini
sudo sed -i 's|^;data = /var/lib/grafana$|data = /var/lib/grafana|' /etc/grafana/grafana.ini
sudo sed -i 's|^;reporting_enabled = true$|reporting_enabled = false|' /etc/grafana/grafana.ini
sudo sed -i 's|^;check_for_updates = true$|check_for_updates = false|' /etc/grafana/grafana.ini
```

**为什么 `data` 必须改**：`defaults.ini` 里 `data = data` 是相对 homepath 的，会落到 `/usr/local/grafana/data`——root 的目录，`grafana` 账号写不进去，启动直接失败。

后两条关掉对 grafana.com 的遥测与版本检查；隔离环境下这些请求只会超时等待。

### 8.4 unit：为什么用 `Type=simple` 而不是 `notify`

```ini
[Unit]
Description=Grafana
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=grafana
Group=grafana
WorkingDirectory=/usr/local/grafana
ExecStart=/usr/local/grafana/bin/grafana server --homepath /usr/local/grafana --config /etc/grafana/grafana.ini
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Grafana 官方 RPM 用 `Type=notify`，要求服务主动向 systemd 发就绪信号。systemd 219 对这套机制容错差，信号没发到会卡在 `activating` 直到超时。`simple` 不依赖握手，行为可预测，`Restart=on-failure` 照样生效。

`--homepath` 指向 `/usr/local/grafana` 是必需的：Grafana 按它找 `conf/defaults.ini`、`public/`、`plugins-bundled/`。

### 8.5 启动与验证（实测结果）

```text
Active: active (running) since 二 2026-10-27 20:18:24 CST; 17s ago
Loaded: loaded (/etc/systemd/system/grafana-server.service; enabled; vendor preset: disabled)
Main PID: 5091 (grafana)
Tasks: 12
Memory: 205.3M

LISTEN 0 1024 [::]:3000 [::]:* users:(("grafana",pid=5091,fd=9))

{"commit": "5e7a8b16...", "database": "ok", "version": "10.4.19"}
```

| 项 | 判读 |
|---|---|
| `Memory: 205.3M` | 比 Prometheus 的 18.1M 重一个数量级，Grafana 内存开销不可忽视 |
| `Tasks: 12` | 线程数，不是进程数 |
| `fd=9` | 比 Prometheus 的 `fd=7` 多 2 个，监听端口更多（3000 + 内部） |
| `database: ok` | **最关键的信号**：SQLite 建库成功，证明 `data` 路径与目录权限都对了 |
| `enabled` | 开机自启已开 |

### 8.6 SELinux 与 firewalld 的实际情况

- `getenforce` = `Enforcing`，但 Grafana 绑 3000、写 `/var/lib/grafana` **都没被拦**。原因：`/usr/local` 下二进制标签是 `usr_t`，systemd 启动的进程落在 `unconfined_service_t`，不受策略约束。**不是 SELinux 失效**——Nginx 被拦是因为它跑在 `httpd_t` 域。判断方法看 `ps -eZ`，不要猜。
- `firewalld` = `active`，从 Windows 访问 `192.168.6.100:3000` 返回 `HTTP 000`（连接未建立）。放行：

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

**区分 `HTTP 000` 与 `HTTP 5xx`**：`000` 是 TCP 都没连上（防火墙/端口未监听），`5xx` 是连上了但服务出错。两者排查方向完全不同。

### 8.7 数据源配置与面板导入

**加 Prometheus 数据源**：`连接 → 数据源 → 添加数据源 → Prometheus`，只填一个字段：

```text
Connection URL:  http://127.0.0.1:9090
```

同机走回环，比填 `192.168.6.100` 更快且不受 firewalld 影响。`保存并测试` 期望 `Successfully queried the Prometheus API.`

**Explore 验证**（中文界面路径）：

1. `探索` → 数据源选 `prometheus`
2. 点 `+ 添加查询` —— **不加查询会一直显示"没有数据"**
3. 查询行最右侧把 `生成器` 切到 `代码` —— 生成器只能点选，敲不了 PromQL
4. 输入 `up`，`Shift + Enter` 或点右上蓝色运行按钮

实测结果：`A 即时: 2 条`，`Expr: up`，`Step: 15s`，响应 213 行。**`2 条` 就是两条 `up` 序列，说明三段链路全通。**

两个判读细节：① `Step: 15s` 与 Prometheus 的 `scrapeInterval` 一致，说明数据源配置合理；② 图表看起来空白，是因为底部 `查询检查器` 把图表压扁了，关掉才看得到完整曲线。

**导入 Node Exporter Full（ID 1860）**：

这台机器出网慢，让 Grafana 自己去 grafana.com 拉 JSON 容易卡住。可靠做法是在 Windows 侧下好再上传：

```bash
curl -sL -o node-exporter-full-1860.json \
  https://grafana.com/api/dashboards/1860/revisions/latest/download
```

实测 468,600 字节、revision 45、**110 个 timeseries 面板**。

导入：`http://<host>:3000/dashboard/import` → 上传 JSON 文件 → 数据源下拉选 `prometheus` → `导入`。

**关键检查**：该面板**没有硬编码 `job="node"`**（`grep -c 'job=\"node\"'` = 0），`job` 由 `label_values(node_uname_info, job)` 自动发现，所以 `job_name` 叫 `node_exporter` 也能匹配。面板描述里写的 "default job_name: node" 只是推荐配置，不是过滤条件。

**看板阅读建议**：110 个面板信息密度极高，先只看四块——CPU（使用率/iowait）、Memory（available/缓存/Swap）、Disk（空间/IO 延迟）、Network（带宽/丢包/错误）。这四块覆盖日常 80% 的排查场景。

### 面板导入验收（2026-11-02 执行，2026-11-06 复看通过）

按上节步骤在 Windows 浏览器完成导入：`http://192.168.6.100:3000/dashboard/import` → 上传 `node-exporter-full-1860.json` → 数据源下拉选 `prometheus` → 导入。

验收结果（两轮回传截图）：

- 面板正常加载，无报错页；CPU、内存、磁盘、网络四个区块均有实时曲线，无 "No data"。
- 能出数即证明 `job` 变量匹配成功：1860 的查询都带 `job="$job"` 过滤，`label_values(node_uname_info, job)` 若发现不了 `node_exporter`，面板会是空的。下拉框取值未单独截图核对，此为推断而非直读。
- 下拉区块复看（11-06）：读数与既有基线一致——根分区使用率约 38%、Swap 0、负载接近 0（对应 10-10 基线）；内存 available 的图形版就是此前用 `node_memory_MemAvailable_bytes/1024/1024` 查的同一份数据。
- 曲线中的平直空段对应 10-24～10-27 虚拟机停机，Prometheus 不回填，不是故障。

**至此监控栈四层闭环：node_exporter 采集（9100）→ Prometheus 存储查询（9090）→ Grafana 展示（3000）。** 前两层用 `up` 与 `count()` 验证、第三层用 `free -m` 互证、第四层以视觉验收收尾——四种验证方式对应四种岗位场景，可作为面试讲法。

一句话记住：**面板不是用来看"现在好不好"，而是看"和平时一不一样"**；下一节的告警规则，本质就是把"不一样"写成 PromQL 条件让机器替你盯。

本节收尾，不要重做。下一步：Alertmanager（9093）+ 告警规则 → 故障演练（停 node_exporter 看 `up` 变 0、观察 `for` 抑制）。