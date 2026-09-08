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
│   └── ops_mysql_basics.md
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

```text
Linux 基础第一阶段：完成
网络基础第一阶段：完成
Shell 第一阶段：完成
crontab 第一阶段：完成
Nginx 第一阶段：完成
MySQL 基础 SQL、备份恢复、脚本、定时备份和保留策略：完成
MySQL 用户权限、最小权限、GRANT 和 REVOKE：完成
```

下一步：MySQL 常见故障排查，然后完成 MySQL 第一阶段总结并进入 Redis。

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
