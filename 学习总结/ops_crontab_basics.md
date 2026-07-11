# 运维 crontab 定时任务基础笔记

归档分类：学习总结。

适用环境：CentOS 7。

你的当前项目：

```bash
/opt/scripts/check_nginx.sh
```

当前 root 定时任务：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

含义：

```text
每分钟用 root 身份执行一次 Nginx 健康检查脚本。
```

## 1. crontab 是什么

`crontab` 用来设置定时任务。

它可以让 Linux 在指定时间自动执行命令或脚本。

例如：

```text
每分钟检查一次 Nginx
每天凌晨 2 点备份数据库
每周一清理日志
每 5 分钟检查一次网站状态
```

一句话记住：

```text
crontab = Linux 的定时任务表。
```

## 2. cron、crond、crontab 的区别

这几个名字很像，但含义不同。

```text
cron      定时任务机制的统称
crond     cron 的后台服务进程，真正负责按时间执行任务
crontab   管理定时任务的命令
```

关系：

```text
你用 crontab 写任务
crond 服务负责定时执行任务
```

所以如果 `crond` 没运行，`crontab` 里写了任务也不会执行。

## 3. 查看 crond 服务状态

命令：

```bash
sudo systemctl status crond
```

参数说明：

```text
sudo       用管理员权限执行
systemctl  管理 systemd 服务
status     查看服务状态
crond      定时任务服务名
```

重点看：

```text
Active: active (running)
```

如果看到这个，说明 `crond` 正在运行。

## 4. 启动 crond

命令：

```bash
sudo systemctl start crond
```

含义：

```text
立即启动 crond 服务。
```

适合情况：

```text
crond 当前没有运行，需要马上启动。
```

验证：

```bash
sudo systemctl status crond
```

看到：

```text
active (running)
```

就说明启动成功。

## 5. 停止 crond

命令：

```bash
sudo systemctl stop crond
```

含义：

```text
立即停止 crond 服务。
```

注意：

```text
停止 crond 后，所有 crontab 定时任务都不会自动执行。
```

验证：

```bash
sudo systemctl status crond
```

如果看到：

```text
inactive (dead)
```

说明已经停止。

运维注意：

```text
生产环境不要随便 stop crond。
它可能负责备份、巡检、日志清理等重要任务。
```

## 6. 重启 crond

命令：

```bash
sudo systemctl restart crond
```

含义：

```text
先停止 crond，再启动 crond。
```

适合情况：

```text
crond 状态异常
修改了和 crond 服务有关的配置
想重新拉起定时任务服务
```

一般情况下，使用 `crontab -e` 修改用户定时任务后，不需要手动重启 `crond`。

## 7. 设置 crond 开机自启

命令：

```bash
sudo systemctl enable crond
```

含义：

```text
让 crond 服务在系统开机后自动启动。
```

检查是否开机自启：

```bash
sudo systemctl is-enabled crond
```

可能输出：

```text
enabled
disabled
```

含义：

```text
enabled    已设置开机自启
disabled   没有设置开机自启
```

## 8. 关闭 crond 开机自启

命令：

```bash
sudo systemctl disable crond
```

含义：

```text
取消 crond 开机自启。
```

注意：

```text
disable 只是不让它开机自动启动。
如果 crond 现在正在运行，它不会立刻停止。
```

如果想立刻停止，还要执行：

```bash
sudo systemctl stop crond
```

## 9. 当前用户和 root 用户的 crontab

`crontab` 是分用户的。

查看当前用户的定时任务：

```bash
crontab -l
```

你的普通用户是：

```text
atguigu
```

所以：

```bash
crontab -l
```

查看的是 `atguigu` 用户的定时任务。

查看 root 用户的定时任务：

```bash
sudo crontab -l
```

因为你的脚本需要：

```text
写 /var/log/nginx_check.log
启动 nginx
重启 nginx
移动日志文件
```

这些更适合用 root 权限，所以你的 Nginx 健康检查脚本应该放在 root 的 crontab 里。

## 10. 查看定时任务

查看当前用户：

```bash
crontab -l
```

参数说明：

```text
-l   list，列出当前用户的 crontab
```

查看 root：

```bash
sudo crontab -l
```

示例输出：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

含义：

```text
root 用户每分钟执行一次 /opt/scripts/check_nginx.sh
```

如果没有定时任务，可能看到：

```text
no crontab for atguigu
```

意思是：

```text
atguigu 用户还没有 crontab。
```

## 11. 编辑定时任务

编辑当前用户：

```bash
crontab -e
```

编辑 root 用户：

```bash
sudo crontab -e
```

参数说明：

```text
-e   edit，编辑 crontab
```

如果进入 vim：

```text
按 i 进入编辑模式
输入定时任务
按 Esc
输入 :wq
回车保存退出
```

例子：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

保存后检查：

```bash
sudo crontab -l
```

应该看到：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

## 12. 删除定时任务

推荐方式：编辑删除某一行。

```bash
sudo crontab -e
```

进入后删除这一行：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

保存退出。

然后检查：

```bash
sudo crontab -l
```

不推荐初学者直接用：

```bash
crontab -r
sudo crontab -r
```

参数说明：

```text
-r   remove，删除当前用户所有 crontab
```

风险：

```text
crontab -r 会删除当前用户的全部定时任务，不是删除某一条。
sudo crontab -r 会删除 root 的全部定时任务。
```

所以你现在记住：

```text
删除某一条任务，用 crontab -e 手动删行，不要随便用 crontab -r。
```

## 13. crontab 时间格式

基本格式：

```bash
分 时 日 月 周 命令
```

也就是：

```bash
* * * * * command
```

五列含义：

```text
第 1 列：分钟，0-59
第 2 列：小时，0-23
第 3 列：日期，1-31
第 4 列：月份，1-12
第 5 列：星期，0-7，0 和 7 都表示星期日
```

## 14. crontab 常用符号

```text
*        每一个时间单位
*/5      每隔 5 个单位
1,3,5    指定多个值
1-5      指定范围
```

示例：

```bash
* * * * * command
```

每分钟执行。

```bash
*/5 * * * * command
```

每 5 分钟执行。

```bash
0 9,12,18 * * * command
```

每天 9:00、12:00、18:00 执行。

```bash
0 9-18 * * * command
```

每天 9 点到 18 点之间，每个整点执行。

## 15. 每分钟执行

命令：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

解析：

```text
第 1 个 *   每分钟
第 2 个 *   每小时
第 3 个 *   每天
第 4 个 *   每月
第 5 个 *   每个星期
```

含义：

```text
每分钟执行一次脚本。
```

你的练习环境现在就是这个。

## 16. 每 5 分钟执行

命令：

```bash
*/5 * * * * /opt/scripts/check_nginx.sh
```

解析：

```text
*/5   分钟列，每隔 5 分钟
*     每小时
*     每天
*     每月
*     每个星期
```

实际执行分钟：

```text
00、05、10、15、20、25、30、35、40、45、50、55
```

生产环境中，健康检查常用每 5 分钟一次，比每分钟更稳妥。

## 17. 每 10 分钟执行

命令：

```bash
*/10 * * * * /opt/scripts/check_nginx.sh
```

实际执行分钟：

```text
00、10、20、30、40、50
```

含义：

```text
每隔 10 分钟执行一次脚本。
```

## 18. 每天凌晨 3 点执行

命令：

```bash
0 3 * * * /opt/scripts/check_nginx.sh
```

解析：

```text
0     第 0 分钟
3     凌晨 3 点
*     每天
*     每月
*     每个星期
```

含义：

```text
每天凌晨 3:00 执行一次。
```

## 19. 每周一凌晨 2:30 执行

命令：

```bash
30 2 * * 1 /opt/scripts/check_nginx.sh
```

解析：

```text
30    第 30 分钟
2     凌晨 2 点
*     每天日期
*     每月
1     星期一
```

含义：

```text
每周一凌晨 2:30 执行一次。
```

## 20. 每天多个整点执行

命令：

```bash
0 9,12,18 * * * /opt/scripts/check_nginx.sh
```

解析：

```text
0          第 0 分钟
9,12,18    9 点、12 点、18 点
*          每天
*          每月
*          每个星期
```

含义：

```text
每天 9:00、12:00、18:00 各执行一次。
```

逗号：

```text
9,12,18 表示多个指定值。
```

## 21. 每天 9 点到 18 点每个整点执行

命令：

```bash
0 9-18 * * * /opt/scripts/check_nginx.sh
```

解析：

```text
0       第 0 分钟
9-18    9 点到 18 点
*       每天
*       每月
*       每个星期
```

含义：

```text
每天 9:00 到 18:00，每小时整点执行一次。
```

实际执行时间：

```text
09:00
10:00
11:00
12:00
13:00
14:00
15:00
16:00
17:00
18:00
```

注意：

```text
它不是 9:00 到 18:00 一直执行。
它只在每个整点执行。
```

## 22. 每天 9 点到 18 点每分钟执行

命令：

```bash
* 9-18 * * * /opt/scripts/check_nginx.sh
```

解析：

```text
*       每分钟
9-18    9 点到 18 点
*       每天
*       每月
*       每个星期
```

含义：

```text
每天 9:00 到 18:59 之间，每分钟执行一次。
```

注意：

```text
这里会一直执行到 18:59。
如果只想到 18:00 整点，就要另外设计规则。
```

## 23. 工作日上班时间每 10 分钟执行

命令：

```bash
*/10 9-18 * * 1-5 /opt/scripts/check_nginx.sh
```

解析：

```text
*/10    每 10 分钟
9-18    9 点到 18 点
*       每天日期
*       每月
1-5     周一到周五
```

含义：

```text
周一到周五，9 点到 18 点之间，每 10 分钟执行一次。
```

这类写法比较像公司上班时间巡检。

## 24. 验证 crontab 是否执行

你的脚本会写日志：

```bash
/var/log/nginx_check.log
```

所以验证方式：

```bash
sudo tail -n 20 /var/log/nginx_check.log
```

如果看到每分钟都有类似内容：

```text
[2026-07-07 14:39:01] Start checking nginx...
[2026-07-07 14:39:01] nginx service is running.
[2026-07-07 14:39:01] website check OK, http_code=200
[2026-07-07 14:39:01] Check finished.
```

说明定时任务执行成功。

重点看时间：

```text
14:39:01
14:40:01
14:41:01
14:42:01
```

每分钟都有新日志，就说明 cron 正在自动执行。

## 25. 查看 cron 系统日志

CentOS 7 通常可以查看：

```bash
sudo tail -n 50 /var/log/cron
```

参数说明：

```text
tail       查看文件末尾
-n 50      查看最后 50 行
/var/log/cron   cron 服务日志
```

可以看到类似：

```text
CROND[1234]: (root) CMD (/opt/scripts/check_nginx.sh)
```

含义：

```text
root 用户的 cron 执行了 /opt/scripts/check_nginx.sh。
```

## 26. crontab 常见坑：环境变量少

cron 执行任务时，环境变量比你手动登录终端少。

所以脚本里最好使用完整路径。

例如：

```bash
/usr/bin/curl
/usr/bin/systemctl
/usr/bin/date
```

不过在 CentOS 7 常见默认 PATH 下，你当前脚本一般也能正常执行：

```bash
curl
systemctl
date
stat
mv
touch
```

如果以后遇到 cron 手动能跑、定时不跑，可以先怀疑：

```text
PATH 环境变量问题
权限问题
脚本没有执行权限
工作目录不同
日志没有写出来
```

更稳的 crontab 写法可以指定 PATH：

```bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
* * * * * /opt/scripts/check_nginx.sh
```

## 27. crontab 常见坑：脚本权限

如果 crontab 里直接写：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

脚本需要有执行权限。

查看权限：

```bash
ls -l /opt/scripts/check_nginx.sh
```

如果看到：

```text
-rwxr-xr-x
```

说明有执行权限。

添加执行权限：

```bash
sudo chmod +x /opt/scripts/check_nginx.sh
```

参数说明：

```text
chmod   修改权限
+x      添加可执行权限
```

另一种写法是不依赖执行权限：

```bash
* * * * * /bin/bash /opt/scripts/check_nginx.sh
```

含义：

```text
让 /bin/bash 来执行脚本。
```

## 28. crontab 常见坑：输出没人接

如果 cron 任务有标准输出或错误输出，可能会发邮件或丢失，不方便排查。

建议把输出重定向到日志：

```bash
* * * * * /opt/scripts/check_nginx.sh >> /var/log/check_nginx_cron.log 2>&1
```

参数说明：

```text
>> /var/log/check_nginx_cron.log   把标准输出追加到日志
2>&1                               把错误输出也合并到标准输出
```

你的脚本本身已经写 `/var/log/nginx_check.log`，所以当前可以不用额外加这一段。

但以后写其他 cron 任务时，这个很常用。

## 29. crontab 常见排查流程

如果定时任务没有执行，按这个顺序查：

1. 查看 crond 是否运行：

```bash
sudo systemctl status crond
```

2. 查看定时任务是否存在：

```bash
sudo crontab -l
```

3. 手动执行脚本是否正常：

```bash
sudo /opt/scripts/check_nginx.sh
```

4. 检查脚本语法：

```bash
bash -n /opt/scripts/check_nginx.sh
```

5. 检查脚本权限：

```bash
ls -l /opt/scripts/check_nginx.sh
```

6. 查看脚本自己的日志：

```bash
sudo tail -n 20 /var/log/nginx_check.log
```

7. 查看 cron 系统日志：

```bash
sudo tail -n 50 /var/log/cron
```

## 30. 当前项目推荐配置

练习阶段：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

优点：

```text
每分钟执行，方便马上看到效果。
```

真实环境更推荐：

```bash
*/5 * * * * /opt/scripts/check_nginx.sh
```

优点：

```text
每 5 分钟检查一次，频率更合理，日志增长也没那么快。
```

如果要改成每 5 分钟：

```bash
sudo crontab -e
```

把：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

改成：

```bash
*/5 * * * * /opt/scripts/check_nginx.sh
```

保存后检查：

```bash
sudo crontab -l
```

## 31. crontab 一句话总结

```text
crontab 负责写任务，crond 负责执行任务。
```

```text
先确认 crond 运行，再确认 crontab 存在，再看脚本日志和 cron 日志。
```

```text
练习用每分钟，真实环境常用每 5 分钟或更低频率。
```
