# Linux 主机巡检脚本 Implementation Plan

> **For agentic workers:** 按步骤执行本计划；本项目采用用户在 CentOS 手动编写和验证的方式，不直接代写虚拟机脚本。

**Goal:** 用户亲手创建一个函数化 Bash 巡检脚本，检查核心服务、本机 HTTP、内存、根分区容量和 inode，并同时输出终端和日志。

**Architecture:** 单文件 Bash 脚本按函数划分职责。脚本只读检查，不自动修复；完成全部检查后根据 WARN/FAIL 返回退出码。

**Tech Stack:** Bash、systemctl、curl、free、df、awk、CentOS 7。

## Global Constraints

- 脚本路径：/opt/scripts/system_inspection.sh。
- 日志路径：/var/log/system_inspection.log。
- 检查服务：nginx、mariadb、backend-demo、crond、firewalld、sshd。
- 检查 URL：http://127.0.0.1 和 http://127.0.0.1:8080。
- 内存 available 小于 20%、根分区容量或 inode 使用率大于等于 80% 时输出 WARN。
- 服务非 active 或 HTTP 非 200 时输出 FAIL。
- 不启动、停止或重启任何服务。
- 退出码：0=正常，1=只有 WARN，2=存在 FAIL。

## Task 1：文件骨架和日志函数

用户在 CentOS 创建 /opt/scripts/system_inspection.sh，写入解释器、LOG_FILE、WARN_COUNT、FAIL_COUNT 和 log_message 函数。函数接收级别与消息，用 date 生成时间，同时 echo 到终端并追加到 LOG_FILE。

验证：

```bash
sudo chmod 755 /opt/scripts/system_inspection.sh
sudo bash -n /opt/scripts/system_inspection.sh
echo $?
```

临时调用 log_message INFO "inspection skeleton works"，运行脚本并用 sudo tail 检查日志，确认终端和日志各出现一条记录；验证后删除临时调用。

## Task 2：服务检查

用户编写 check_service 函数，参数为服务名。用 systemctl is-active --quiet 判断，active 输出 OK，否则输出 FAIL 并增加 FAIL_COUNT；函数不得执行 start、stop 或 restart。

主流程循环调用 nginx、mariadb、backend-demo、crond、firewalld、sshd。用 bash -n 和脚本执行验证六个服务的结果。

## Task 3：HTTP 检查

用户编写 check_http 函数，参数为名称和 URL。使用 curl --connect-timeout 5 --max-time 10 -o /dev/null -sS -w "%{http_code}" 获取状态码。状态码为 200 输出 OK，否则输出 FAIL 并增加 FAIL_COUNT。

调用 nginx 的 127.0.0.1 URL 和 backend 的 127.0.0.1:8080 URL，验证正常环境均为 OK。

## Task 4：内存和文件系统检查

用户编写 check_memory：用 free -m 和 awk 读取 Mem 行的 total、available，计算 available 百分比；无法读取或 total 为 0 时输出 FAIL；低于 20% 输出 WARN，否则 OK。

用户编写 check_filesystem：用 df -P / 和 df -Pi / 配合 awk 读取容量及 inode 使用率；无法读取时输出 FAIL；使用率大于等于 80% 输出 WARN，否则 OK。

调用两个函数并在当前虚拟机执行，确认资源结果为 OK。

## Task 5：汇总、退出码和故障演练

主流程最后输出 failed 和 warned 汇总：存在 FAIL 返回 2；没有 FAIL 但有 WARN 返回 1；全部正常返回 0。

正常环境执行并用 echo $? 验证返回 0，用 sudo tail 检查日志持续追加。

故障演练：

```bash
sudo systemctl stop backend-demo
sudo bash /opt/scripts/system_inspection.sh
echo $?
```

预期 backend-demo 服务和后端 HTTP 都为 FAIL，退出码为 2，且脚本不自动启动服务。验证后立即执行：

```bash
sudo systemctl start backend-demo
systemctl is-active backend-demo
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080
```

预期服务为 active，HTTP 为 200。

## 完成标准

- 用户能解释每个函数、变量、阈值、命令替换和退出码。
- 正常环境返回 0。
- 后端停止演练返回 2，并且只报警、不自动修复。
- 恢复后服务和 HTTP 返回正常。
- 终端输出与日志内容均可追溯。
