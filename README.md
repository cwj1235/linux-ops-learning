# Linux 运维与云运维学习项目

这是一个面向运维实习目标的长期学习项目，采用“系统知识 + 实际操作 + 故障排查 + 阶段总结”的方式推进。

## 目录结构

```text
new-chat/
├── README.md                 项目首页和文件索引
├── AGENTS.md                 Codex 项目规则
├── .gitignore                Git 忽略规则
├── .gitattributes            Git 换行格式规则
├── 学习总结/
│   ├── ops_network_basics.md
│   ├── ops_shell_basics.md
│   ├── ops_crontab_basics.md
│   ├── ops_nginx_reverse_proxy.md
│   ├── ops_nginx_stage1.md
│   ├── ops_mysql_basics.md
│   ├── ops_linux_ops_stage1.md
│   ├── ops_linux_inspection_script.md
│   ├── ops_git_basics.md
│   ├── ops_python_basics.md
│   ├── ops_redis_basics.md
│   ├── ops_docker_basics.md
│   └── ops_ansible_basics.md
├── scripts/                  已纳入版本管理的运维脚本
└── 项目记录/
    ├── memory.md
    ├── ops_handoff.md
    ├── ops_command_history.md
    └── config.toml
```

## 两个归档目录的职责

### 学习总结

`学习总结/` 保存各个技术模块的系统复习笔记：

- [网络基础](学习总结/ops_network_basics.md)
- [Shell 基础](学习总结/ops_shell_basics.md)
- [crontab 基础](学习总结/ops_crontab_basics.md)
- [Nginx 反向代理](学习总结/ops_nginx_reverse_proxy.md)
- [Nginx 第一阶段总结](学习总结/ops_nginx_stage1.md)
- [MySQL/MariaDB 基础](学习总结/ops_mysql_basics.md)
- [Linux 运维强化](学习总结/ops_linux_ops_stage1.md)
- [Linux 巡检脚本](学习总结/ops_linux_inspection_script.md)
- [Git 基础](学习总结/ops_git_basics.md)
- [Python 运维脚本](学习总结/ops_python_basics.md)
- [Redis 基础运维](学习总结/ops_redis_basics.md)
- [Docker 基础运维](学习总结/ops_docker_basics.md)
- [Ansible 自动化部署](学习总结/ops_ansible_basics.md)

### 项目记录

`项目记录/` 保存维持学习连续性所需的文件：

- [项目记忆](项目记录/memory.md)：长期背景、稳定偏好、准确进度和下一步。
- [学习交接](项目记录/ops_handoff.md)：新线程或其他模型接手时优先阅读。
- [命令履历](项目记录/ops_command_history.md)：已经实际执行过的命令、输出和结论。
- [配置记录](项目记录/config.toml)：保存曾使用的 Codex 配置内容；实际运行权限以 Codex 应用下发的权限为准。

这些文件均位于项目工作区内，可以正常读取、修改、移动和通过 Git 管理。

## 推荐阅读顺序

新线程或重新开始学习时，按以下顺序读取：

```text
1. README.md
2. AGENTS.md
3. 项目记录/ops_handoff.md
4. 项目记录/memory.md
5. 项目记录/ops_command_history.md
6. 学习总结中的当前模块笔记
```

## 当前进度

2026-09-18：Ansible 一键部署 Nginx 完整 playbook 已完成。新增 `inventory-prod.ini`（`[web]` 两台主机各自的 `site_port`）、`templates/index.html.j2`、`templates/nginx-site.conf.j2` 与 `nginx-deploy.yml`（`serial: 1` 滚动发布、`yum` 幂等装包、`file` 建站点目录、`template` 部署首页与站点配置、`block` + `uri` 自检、`rescue` 回滚 + `fail` 报红）。实测首跑两台各 `ok=9 changed=4`、幂等复跑 `ok=8 changed=0`、`chcon -t var_t` 破坏后复跑 `changed=1` 自愈、删除目录后重建 `ok=9 changed=4` 且新目录标签立即正确。关键发现：`copy`/`template` 落地文件会自动套策略默认 SELinux 标签，`file` 模块建目录和建文件都不会，必须显式 `setype: httpd_sys_content_t`；修复既有偏差用 `restorecon`（策略里已有 `/var/www(/.*)?` 规则，无需 `semanage fcontext`），`chcon` 只用于临时验证。至此 Ansible 阶段十个小节全部完成。

2026-09-18：Ansible 免密 SSH 与多主机部署已完成。配置了 `ssh-keygen` + `authorized_keys` 免密登录（`BatchMode=yes` 验证退出码 0），并预热 `127.0.0.1` 主机指纹；新建 `inventory-multi.ini`（`[local]` + `[ssh_nodes]` + `[practice:children]` 组嵌套 + 组变量）与 `multi-host.yml`（`hosts: practice`、`gather_facts: true`、按 `inventory_hostname` 分别建目录写文件、两个 `when: inventory_hostname in groups[...]` 分支任务）。实测两台各 `ok=6 changed=2 skipped=1`，`--limit centos100` 时 `changed=0` 验证幂等。关键概念：`inventory_hostname`（inventory 名字）、`ansible_host`（真实连接地址）、`ansible_hostname`（远端 facts）三者含义不同；本例前者不同、后者相同，正是「同一台机器两个身份」。下一步：做「一键部署 Nginx 及基础配置」的完整 playbook。

2026-09-17：Ansible `block`/`rescue` 错误处理已完成。先用 18099 确认「没有 rescue」的后果——任务报红，但 204 字节的半成品配置留在 `/etc/nginx/conf.d/` 里，worker 一个没换（nginx 绑定失败会放弃新配置、继续用旧配置跑）。改写为 `block` + `rescue`（删文件 → reload 回退 → `fail:` 明确报红）后实测 `ok=5 changed=2 failed=1 rescued=1`，回滚后文件已删、nginx 仍 active。意外收获：本轮 `Render` 是 `ok` 而非 `changed`（上一轮残留文件与本次渲染内容一致，checksum 命中），因此没有触发 handler，但 `wait_for` 仍抓到了坏状态——**handler 对本轮变更负责，`wait_for` 对最终状态负责**。成功路径对照 `-e nginx_demo_port=8008` 实测 `rescued=0 failed=0`，证明 rescue 只在需要时介入；残留已清理，nginx 只保留原有 80 端口服务。下一步：多主机部署与 `when` 条件。

2026-09-17：给 handler playbook 加上了自检（`meta: flush_handlers` + `wait_for`）。默认端口 18099 重跑时 `ok=4 changed=2 failed=1`，`wait_for` 在 5 秒内自动报出 SELinux 拒绑——同一个故障，旧代码一路绿灯，新代码当场拦下；换成 `-e nginx_demo_port=8008` 后 `ok=5 changed=2 failed=0`。两次 `changed` 完全相同、只有 `failed` 不同，实证「`changed` 表示做了动作，`failed` 表示结果对不对」。自检实验残留已清理，nginx 上 8008 与 18099 均不再监听。端口约定：练习用白名单内 8008，18099 保持被 SELinux 拦截作为故障演练场。下一步：学习 `block/rescue` 错误处理与多主机部署。

2026-09-17：Ansible handler 对接真实服务已完成。用 `systemd: state=reloaded` 在 nginx 配置变化时热加载，并排查了「reload 报 changed 但服务不生效」的真实故障：`nginx -t` 通过、信号已发出，但 `bind() to 127.0.0.1:18099 failed (13: Permission denied)`；AVC 记录显示 SELinux 拒绝 `name_bind`，18099 的标签是 `unreserved_port_t`。执行 `sudo semanage port -a -t http_port_t -p tcp 18099` 放行后 18099 正常响应，并用白名单内的 8008 做对照实验证明唯一变量是端口。master PID 不变 + worker 全换 = reload 而非 restart。收尾已清理练习配置与目录，并用 `semanage port -d` 撤销 18099 标签，环境回到最初状态。下一步：多主机部署、`when` 条件与 `block/rescue` 错误处理，最后完成一键部署 Nginx 的完整 playbook。

2026-09-17：Ansible handlers 已完成。`handlers-demo.yml` 实测「有变更才触发、无变更不触发、多次触发追加写入」三种情况；排查并定位了 `command` 模块不做重定向导致 handler 报 `changed` 却不生成文件的问题，改用 `shell` 后修复，顺带确认「`changed` 不等于副作用发生」。下一步：用 `systemd` 模块在配置变化时 reload Nginx。

2026-09-16：Ansible 阶段已完成五节——安装与本机连通性、Inventory、Ad-hoc 命令、Playbook 基础、变量与模板。变量来源与优先级（inventory/facts -> playbook `vars` -> 命令行 `-e`）已实测，未定义变量会直接 `FAILED!`；`templates/app.conf.j2` 与 `vars-template.yml` 已完成渲染、幂等（`changed=2` -> `changed=0`）和 `-e` 覆盖（`changed=1` -> `changed=0`）验证。下一步：Ansible handlers。下方 2026-09-14 段落里的“下一步”是 Redis 阶段的历史停点。

2026-09-14：AOF 加载、指定 RDB 隔离回灌、临时实验清理、正式实例 128 MiB 上限及 noeviction 超限行为均已验证。正式 Redis 重启后 maxmemory=134217728、策略为 noeviction，两个练习键可读回；隔离实例 `127.0.0.1:6381` 以 1 MiB 上限实测，前 6 个 65536 字节键写入成功，第 7 个开始返回 OOM 拒写，已有键仍可读，DEL 释放空间后写入恢复。6381 已通过 `SHUTDOWN NOSAVE` 关闭，正式 6379 仍返回 PONG。

```text
Linux 基础第一阶段：完成
网络基础第一阶段：完成
Shell 第一阶段：完成
crontab 第一阶段：完成
Nginx 第一阶段：完成
MySQL 基础 SQL、备份恢复、脚本、定时备份和保留策略：完成
MySQL 用户权限、最小权限、GRANT 和 REVOKE：完成
Linux 运维强化基础检查、巡检脚本与基础排障复习：完成
Git 分支、冲突、远程同步与脚本部署：已验证
Python subprocess、argparse、timeout、logging、退出码：已验证并归档
当前阶段 3：Redis 基础运维
Redis 安装、自启、监听与 PING、String、过期、计数器：已验证
Redis Hash：HSET/HGET/HGETALL/HDEL 已验证，TYPE 返回 hash，HLEN 返回 1
Hash 键与字段检查：EXISTS/HEXISTS 已验证，server:centos100 存在、role 字段不存在
Redis List：RPUSH/LRANGE/LPOP/LLEN、FIFO 与取空后键消失已验证
Redis Set：SADD/SMEMBERS/SCARD/SISMEMBER/SREM、去重与删除最后成员后键消失已验证
Redis ZSet：ZADD/ZRANGE/ZSCORE/ZCARD/ZREVRANGE/ZREM、分数更新与排序、删空后键消失已验证
Redis 配置：实际配置路径为 /etc/redis.conf，bind/port/logfile 的运行值与文件内容一致
Redis 访问边界（重启前检查）：protected-mode=yes，ss 实测 redis-server（pid=1207）监听 127.0.0.1:6379
Redis 日志：PID 3047 的启动日志显示 DB loaded from disk 和 ready to accept connections
Redis RDB：save=900 1 300 10 60 10000，快照路径 /var/lib/redis/dump.rdb，手动 BGSAVE 已验证成功
Redis 持久化状态（AOF 重启后）：aof_enabled=1、aof_rewrite_in_progress=0、aof_last_bgrewrite_status=ok、aof_last_write_status=ok
Redis RDB 备份：/var/lib/redis/dump.rdb.before-restart-20260913-183303；重启前源与备份均为 158 字节，cmp 退出码为 0
Redis 正常重启：23:45:36 CST 启动，active (running)、enabled，主进程 3047；GET practice:rdb-check 返回 rdb-ok
Redis 启动警告：sysctl 实测 somaxconn=128、overcommit_memory=0，THP 当前为 always；只读核验完成，尚未修改参数
Redis 内存上限：128 MiB 已写入配置文件，2026-09-14 17:10 服务重启后直接读回 134217728，验收通过
已结束练习：practice:checks、practice:services、practice:priority 均已确认不存在，无需再次清理
当前练习键：practice:rdb-check 在正常重启后仍读到 rdb-ok，与备份一并保留，尚未清理
Redis AOF：`appendonly yes` 已写入 `/etc/redis.conf`；`/var/lib/redis/appendonly.aof` 已生成，重启日志确认从 AOF 加载，`practice:aof-check` 读回 `aof-ok`
Docker 安装、镜像加速、容器生命周期、数据卷、端口映射、Dockerfile 与 Compose 编排：已完成
Ansible 安装与 Inventory、Ad-hoc 命令、Playbook 基础、变量与模板、handlers、handler 对接 Nginx reload（含 SELinux 端口排查）、block/rescue 错误处理、多主机与 when 条件、一键部署 Nginx（含 SELinux 标签加固）：已完成
```

下一步：只读检查 `/var/lib/redis-noeviction-20260914` 的目录内容，并再次确认 6381 无残留监听；用户确认目录只包含本次实验文件后，再指导安全清理该临时目录。正式 6379 的 128 MiB 上限、练习键和 noeviction 策略均已验收，不再重复设置或重启；配置备份 `/etc/redis.conf.before-maxmemory-20260914-165752` 保留。性能调优、断电恢复和高可用尚未验证，原始数据备份与 AOF 保留。

## Git 保存流程

每次完成一节课或修改重要记录后：

```powershell
git status
git add .
git commit -m "填写本次学习内容"
```

查看最近提交：

```powershell
git log --oneline
```

## 记录原则

- 正文使用中文。
- 命令、路径、SQL、配置项和日志原文保留技术形式，并配中文说明。
- 不保存密码、密码哈希、密钥、令牌或无关个人信息。
- 记忆文件保持精简，详细命令放入命令履历，系统知识放入学习总结。

Git 版本管理学习记录。

Git 分支练习记录。

来自第二个克隆目录的更新。
