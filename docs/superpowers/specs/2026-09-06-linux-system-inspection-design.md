# Linux 主机巡检脚本设计

日期：2026-09-06

## 目标

创建一个函数化 Bash 巡检脚本，复用已学习的 `systemctl`、`curl`、`free`、`df` 和 inode 检查命令，对当前 CentOS 主机的核心服务、Web 链路和基础资源进行只读检查。

## 范围

脚本路径：`/opt/scripts/system_inspection.sh`

日志路径：`/var/log/system_inspection.log`

检查项目：

- systemd 服务：`nginx`、`mariadb`、`backend-demo`、`crond`、`firewalld`、`sshd`。
- 本机 HTTP：`http://127.0.0.1`（Nginx 80）和 `http://127.0.0.1:8080`（Python 后端）。
- 内存：`free` 输出中的 `available` 百分比。
- 根文件系统：`df -P / ` 的容量使用率。
- 根文件系统 inode：`df -Pi / ` 的 inode 使用率。

## 输出与行为

每条结果同时写到终端并追加到日志，格式包含时间和级别：

```text
[2026-09-06 20:00:00] [OK] service nginx is active
[2026-09-06 20:00:00] [WARN] root filesystem usage=82%
[2026-09-06 20:00:00] [FAIL] http backend status=502
```

脚本只读检查，不启动、停止或重启任何服务，也不修改配置和数据。

资源阈值：

- 内存 `available < 20%`：`WARN`。
- 根分区容量使用率 `>= 80%`：`WARN`。
- 根分区 inode 使用率 `>= 80%`：`WARN`。

失败条件：

- 服务状态不是 `active`：`FAIL`。
- HTTP 状态码不是 `200`，或 curl 请求失败：`FAIL`。

退出码：

- `0`：没有 WARN 或 FAIL。
- `1`：至少有 WARN，没有 FAIL。
- `2`：至少有 FAIL；如果同时有 WARN 和 FAIL，仍返回 `2`。

## 结构

脚本使用函数划分职责：

- `log_message`：统一输出到终端和日志。
- `check_service`：检查一个 systemd 服务。
- `check_http`：检查一个 URL 的 HTTP 状态。
- `check_memory`：计算并判断 available 百分比。
- `check_filesystem`：检查根分区容量和 inode。
- 主流程：初始化日志目录和状态变量，依次调用检查函数，输出汇总并返回退出码。

## 错误处理

- 使用绝对路径调用命令。
- 对命令输出进行必要的格式解析。
- curl 设置连接和总超时，避免巡检脚本永久阻塞。
- 脚本自身无法写入日志时，应在终端给出错误并退出。
- 脚本不因单项检查失败而中途退出，继续完成其余检查。

## 验证计划

在虚拟机上依次验证：

1. `bash -n` 检查脚本语法。
2. 正常环境执行，确认服务和 HTTP 返回 `OK`，资源指标正常。
3. 暂停 `backend-demo` 后执行，确认后端 HTTP 标记 `FAIL`，脚本返回 `2`；验证完成后恢复服务。
4. 检查日志文件同时包含终端输出。
5. 查看 `df`、`free` 和 `systemctl` 命令失败时的记录。

## 暂不包含

- 自动修复、自动重启服务。
- 外部 DNS、网关和公网检查。
- SSH 密钥加固。
- 复杂 firewalld rich rules 和深度 SELinux 策略。
