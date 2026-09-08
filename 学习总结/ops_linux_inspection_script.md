# Linux 巡检脚本首版总结

## 本节位置

本节属于 Linux 运维强化阶段的落地产物，承接前面已经学过的 `systemctl`、`ss`、`curl`、`free`、`df`、`df -i`、Shell 条件判断、函数、日志和退出码。

## 1. 脚本目标

把一次日常巡检固化成可重复执行的脚本，做到：

```text
终端实时输出
同时追加写入日志
只检查，不自动修复
用退出码表示巡检结果
```

脚本路径：

```text
/opt/scripts/system_inspection.sh
```

日志路径：

```text
/var/log/system_inspection.log
```

## 2. 检查范围

首版脚本检查：

```text
服务：nginx、mariadb、backend-demo、crond、firewalld、sshd
HTTP：127.0.0.1:80、127.0.0.1:8080
内存：available 百分比
磁盘：根分区容量使用率
文件系统：根分区 inode 使用率
```

这五类检查分别回答：

```text
服务是否活着
入口是否可用
内存是否够
磁盘是否快满
文件数量是否异常
```

## 3. 核心函数

### `log_message`

负责统一输出格式：

```text
[时间] [级别] 内容
```

同时写入终端和日志文件。

### `check_service`

用 `systemctl is-active --quiet` 判断服务是否运行。

### `check_http`

用 `curl` 获取 HTTP 状态码，`200` 记为 `OK`，其他状态记为 `FAIL`。

### `check_memory`

用 `free -m` 取总内存和 `available`，计算百分比：

```text
available_pct = available * 100 / total
```

阈值：

```text
available_pct < 20%  -> WARN
```

### `check_filesystem`

用 `df -P /` 和 `df -Pi /` 取根分区容量与 inode 使用率。

阈值：

```text
容量使用率 >= 80%  -> WARN
inode 使用率 >= 80% -> WARN
```

## 4. 判断级别

脚本使用三种结果：

```text
OK   正常
WARN 达到预警阈值
FAIL 检查失败或服务不可用
```

当前约定：

```text
服务不是 active          -> FAIL
HTTP 状态不是 200        -> FAIL
内存 available < 20%      -> WARN
根分区使用率 >= 80%       -> WARN
根分区 inode >= 80%       -> WARN
```

## 5. 退出码

```text
exit 0  全部正常
exit 1  有 WARN，没有 FAIL
exit 2  有 FAIL
```

如果同时出现 `WARN` 和 `FAIL`，优先返回 `2`。

查看退出码：

```bash
echo $?
```

## 6. 实际验证结果

2026-09-07 首版巡检结果：

```text
[INFO] inspection started
[OK] service nginx is active
[OK] service mariadb is active
[OK] service backend-demo is active
[OK] service crond is active
[OK] service firewalld is active
[OK] service sshd is active
[OK] http nginx status=200
[OK] http backend status=200
[OK] memory available=44%
[OK] root filesystem usage=33%
[OK] root filesystem inode_usage=2%
[INFO] inspection finished: warned=0 failed=0
```

退出码：

```text
0
```

日志文件中也出现了同样记录，说明：

```text
终端输出正常
日志追加正常
退出码正常
```

## 7. 常用验证命令

```bash
sudo bash -n /opt/scripts/system_inspection.sh
sudo bash /opt/scripts/system_inspection.sh
echo $?
sudo tail -n 20 /var/log/system_inspection.log
```

含义：

```text
bash -n  只检查语法，不执行脚本
bash     真正执行脚本
echo $?  查看上一条命令退出码
tail     查看日志末尾内容
```

## 8. 排障思路

如果脚本没有输出：

```text
先看 bash -n 是否有语法错误
```

如果服务检查失败：

```text
systemctl status 服务名
journalctl -u 服务名
ss -lntp
```

如果 HTTP 检查失败：

```text
curl -I 地址
ss -lntp
firewall-cmd --list-all
Nginx error.log
```

如果内存告警：

```text
free -h
vmstat 1 5
ps -eo pid,user,%mem,cmd --sort=-%mem | head
```

如果磁盘或 inode 告警：

```text
df -h
df -ih
du -x --max-depth=1 -h 目录
```

## 9. 当前结论

Linux 巡检脚本首版已经完成，能够覆盖：

```text
服务
HTTP
内存
磁盘容量
inode
日志
退出码
```

后续可以继续演进：

```text
加入 CPU 负载
加入日志轮转
加入定时任务
加入告警通知
```

但当前版本已经满足“Linux 运维强化阶段”的可交付要求。

## 10. HTTP 状态码复习

本轮复习了 HTTP 状态码的五类含义：

```text
1xx：信息响应
2xx：请求成功
3xx：重定向或缓存
4xx：客户端请求问题
5xx：服务器处理问题
```

运维中重点区分：

```text
401：未认证，需要登录或提供凭据。
403：已识别请求，但没有访问权限。
404：请求的文件、页面或接口不存在。
500：服务器内部程序或配置异常。
502：Nginx 等代理无法取得有效后端响应。
503：服务暂时不可用，可能停止、维护或过载。
504：代理等待后端响应超时。
```

其他常见状态码：

```text
200：成功。
201：创建资源成功。
204：成功但没有响应正文。
301：永久重定向。
302：临时重定向。
304：资源未修改，使用缓存。
400：请求格式或参数错误。
405：请求方法不允许。
429：请求过于频繁，被限流。
```
