# Linux 运维强化基础检查

## 本节位置

本节属于 Linux 运维强化阶段，承接前面已经学过的 Linux、网络、Shell、systemd、日志、Nginx 和 firewalld 基础。

## 1. 进程与父子关系

常用命令：`ps`、`pgrep -a`、`ps -p`、`ps --forest`、`pstree -p 1`。

关键概念：

- `PID` 是当前进程编号，`PPID` 是父进程编号。
- PID 会随着进程重启而变化，不能长期把某个 PID 当成服务身份。
- `systemd` 通常是 PID 1，负责启动和管理系统服务。
- 实际确认：`mysqld_safe(1299) -> mysqld(1574)`。
- `pstree` 和 `--forest` 用树形方式显示父子关系；`{name}` 通常表示线程。

## 2. STAT 和信号

常见主状态：

`R` 运行或等待 CPU，`S` 可中断睡眠，`D` 不可中断睡眠，`T` 被暂停，`Z` 僵尸进程。

常见附加标记：

`s` 会话首进程，`l` 多线程进程，`<` 高优先级，`+` 前台进程组。

实际用 `sleep 300 &` 验证：

```bash
kill -STOP PID
# STAT 变为 T
kill -CONT PID
# STAT 恢复为 S
kill -TERM PID
# 进程结束
```

`SIGTERM` 编号是 15，Shell 等待被信号结束的进程时常见退出码为 `128 + 15 = 143`。通常先使用 `SIGTERM`，再考虑 `SIGKILL`。

僵尸和孤儿的区别：

```text
僵尸：子进程已结束，父进程还没有 wait 回收。
孤儿：父进程已结束，子进程仍在运行，通常由 PID 1 接管。
```

## 3. CPU、内存和系统负载

```bash
nproc
uptime
vmstat 1 5
free -h
```

真实结果：

```text
nproc = 4
load average = 0.00, 0.01, 0.05
vmstat 的 id = 100%，si/so = 0，wa = 0
```

判断方法：

- `nproc` 查看当前可用逻辑 CPU 数量。
- `uptime` 的负载数值分别是最近 1、5、15 分钟平均负载；4 个逻辑 CPU 上长期负载高于 4 才需要重点关注排队。
- `vmstat` 中 `r` 是运行队列，`b` 是不可中断睡眠进程；`si/so` 是 Swap 交换；`wa` 是 I/O 等待；`id` 是 CPU 空闲比例。
- `free -h` 判断内存时重点看 `available` 和 Swap 使用量，不要只看 `free`。

## 4. 磁盘、目录和 inode

```bash
df -h
df -ih
du -sh /var
sudo du -x --max-depth=1 -h / 2>/dev/null | sort -h
```

区别：

```text
df -h  查看文件系统整体容量和剩余空间
df -ih 查看 inode 数量和使用率
du -sh 查看目录及其内容占用
du -x 统计时不跨到其他挂载点
```

真实结果：根分区总容量约 17G，已用约 5.5G，使用率 33%；inode 使用率约 2%。`/usr` 约 3.9G，`/var` 约 1.4G；`/var/cache/yum` 约 1.3G，主要是 `updates` 约 968M。当前没有执行缓存清理。

## 5. stat 文件元数据

```bash
stat /etc/nginx/nginx.conf
stat -c%s /etc/nginx/nginx.conf
stat -f /etc/nginx/nginx.conf
```

- `stat` 查看文件大小、权限、所有者、inode、时间和 SELinux 上下文。
- `stat -c%s` 只输出文件大小，单位为字节，适合脚本。
- `stat -f` 查看文件所在文件系统的类型、块和 inode 信息。
- `Access` 是访问时间，`Modify` 是内容修改时间，`Change` 是元数据变化时间；`Change` 不是创建时间。

实际的 Nginx 配置文件为 2461 字节、权限 0644、root:root、类型 `httpd_config_t`；根文件系统为 XFS，块大小 4096。

## 6. SSH 服务

```bash
sudo systemctl status sshd --no-pager -l
sudo ss -lntp 'sport = :22'
sudo sshd -T | grep -E '^(port|listenaddress|permitrootlogin|passwordauthentication|pubkeyauthentication) '
```

真实结果：`sshd` 为 `active (running)` 且 `enabled`，监听 `0.0.0.0:22` 和 `[::]:22`。生效配置为：

```text
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
```

SSH 密钥登录和关闭 root/密码登录的流程已经理解，但本阶段没有执行配置修改。正式加固时应先验证普通用户密钥登录，保留当前会话，使用 `sshd -t` 检查语法，再 `systemctl reload sshd`。

## 7. firewalld

```bash
sudo firewall-cmd --state
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --permanent --zone=public --list-all
sudo firewall-cmd --get-default-zone
```

真实结果：firewalld 运行中，`ens33` 使用 `public` 区域；`services` 中有 `dhcpv6-client http ssh`，`ports` 为空，因此 SSH 22 和 HTTP 80 通过预定义服务放行，8080 没有明确对外放行。CentOS 7 不支持 `--permanent --get-default-zone` 的组合，普通 `--get-default-zone` 返回 `public`。

## 8. SELinux

```bash
getenforce
sestatus
ls -Zd /etc/nginx/nginx.conf /var/www/ops-site
getsebool httpd_can_network_connect
sudo ausearch -m AVC -ts recent
```

真实结果：SELinux 为 `Enforcing`，策略为 `targeted`；Nginx 配置类型为 `httpd_config_t`，网站目录类型为 `httpd_sys_content_t`，`httpd_can_network_connect` 为 `on`，最近 AVC 查询为 `<no matches>`。

排障原则：

```text
403 优先检查权限和 SELinux 文件类型。
502 优先检查后端服务、端口和 httpd_can_network_connect。
不要把关闭 SELinux 当作第一解决方案。
```

## 阶段总结

本阶段已完成 Linux 资源与基础安全检查的实操验证。下一步先进行阶段复盘和能力检查，再制作 Linux 巡检脚本。SSH 密钥加固、复杂防火墙规则和深度 SELinux 策略分析作为后续安全专项。
