# MySQL/MariaDB 系统运维笔记

用途：记录 MySQL/MariaDB 第一阶段学习内容，方便复习、交接给其他模型、后续写备份脚本和简历项目。

最后更新：2026-07-11

## 1. 本阶段位置

当前模块是 MySQL 系统运维。

它和前面知识的关系：

```text
Linux 基础
  -> 安装软件、查看文件、管理目录权限。

systemd
  -> 用 systemctl 管理 mariadb 服务，和管理 nginx/backend-demo 一样。

网络基础
  -> MySQL 默认端口是 3306，要会用 ss 判断端口是否监听。

firewalld
  -> 如果以后要远程连接 MySQL，需要判断 3306 是否放行。

Shell + crontab
  -> 后面会用 mysqldump 写备份脚本，再用 crontab 定时执行。

日志排查
  -> MySQL/MariaDB 也有日志，和 Nginx error.log 一样用于定位问题。
```

一句话记住：

```text
MySQL 运维不是只会写 SQL，而是会安装、启动、看端口、看配置、看数据目录、看用户权限、备份恢复和排故。
```

## 2. MySQL 和 MariaDB 的关系

在 CentOS 7 里，系统仓库默认常见的是 MariaDB。

```text
MySQL
  -> 原始主线数据库产品。

MariaDB
  -> 从 MySQL 分出来的兼容分支。
  -> 基础命令、SQL、端口、备份恢复大部分和 MySQL 通用。
```

本机安装的是：

```text
MariaDB 5.5.68
```

学习时可以把它当成 MySQL 入门和运维练习环境。

## 3. 安装前检查

执行过：

```bash
rpm -qa | grep -Ei 'mysql|mariadb'
systemctl status mariadb
ss -lntp | grep :3306
```

语法说明：

```text
rpm -qa
  -> 查询系统已经安装的 rpm 软件包。

grep -Ei 'mysql|mariadb'
  -> 从输出里筛选 mysql 或 mariadb。
  -> -E 表示扩展正则，可以用 | 表示“或者”。
  -> -i 表示忽略大小写。

systemctl status mariadb
  -> 查看 mariadb 服务状态。

ss -lntp | grep :3306
  -> 查看是否有 TCP 服务监听 3306 端口。
```

当时结果：

```text
只看到 mariadb-libs。
mariadb.service could not be found。
3306 没有监听。
```

结论：

```text
系统只有 MariaDB 客户端依赖库，没有安装数据库服务端。
```

## 4. 安装 MariaDB 服务端

执行过：

```bash
sudo yum install -y mariadb-server
```

语法说明：

```text
sudo
  -> 用管理员权限执行。

yum install
  -> 用 yum 安装软件包。

-y
  -> 自动回答 yes。

mariadb-server
  -> MariaDB 服务端软件包。
```

安装结果：

```text
安装了 mariadb-server.x86_64 1:5.5.68-1.el7。
同时安装了 mariadb、perl-DBI、perl-DBD-MySQL 等依赖。
```

一句话记住：

```text
mariadb-libs 只是库，真正提供数据库服务的是 mariadb-server。
```

## 5. 启动、查看状态和端口

执行过：

```bash
sudo systemctl start mariadb
sudo systemctl status mariadb
ss -lntp | grep :3306
sudo ss -lntp | grep :3306
```

语法说明：

```text
systemctl start mariadb
  -> 现在启动 mariadb 服务。

systemctl status mariadb
  -> 查看服务当前状态。

ss -lntp
  -> -l：只看监听中的端口。
  -> -n：数字显示端口，不解析成服务名。
  -> -t：只看 TCP。
  -> -p：显示进程名，需要 sudo 才能看完整。

grep :3306
  -> 只筛选 MySQL/MariaDB 默认端口 3306。
```

看到的关键结果：

```text
Active: active (running)
*:3306
users:(("mysqld",pid=7704,fd=14))
```

结论：

```text
MariaDB 服务已经运行，mysqld 进程正在监听 3306 端口。
```

注意：

```text
服务名是 mariadb。
真正的数据库进程名常见是 mysqld。
登录数据库的客户端命令是 mysql。
```

## 6. 设置开机自启动和查看版本

执行过：

```bash
sudo systemctl enable mariadb
mysql -uroot -e "SELECT VERSION();"
```

语法说明：

```text
systemctl enable mariadb
  -> 设置 mariadb 开机自启动。

mysql
  -> MySQL/MariaDB 客户端命令。

-u root
  -> 使用数据库 root 用户登录。

-e "SQL"
  -> 直接执行一条 SQL，然后退出。

SELECT VERSION();
  -> 查看数据库版本。
```

结果：

```text
5.5.68-MariaDB
```

一句话记住：

```text
active 表示现在正在运行，enabled 表示开机自动启动。
```

## 7. 检查服务状态、数据库列表和数据目录

执行过：

```bash
sudo systemctl is-enabled mariadb
sudo systemctl is-active mariadb
mysql -uroot -e "SHOW DATABASES;"
mysql -uroot -e "SHOW VARIABLES LIKE 'datadir';"
```

语法说明：

```text
systemctl is-enabled mariadb
  -> 查看是否开机自启动。

systemctl is-active mariadb
  -> 查看当前是否运行。

SHOW DATABASES;
  -> 查看当前有哪些数据库。

SHOW VARIABLES LIKE 'datadir';
  -> 查看数据库变量里 datadir 的值。
  -> datadir 是数据库真实数据目录。
```

结果：

```text
is-enabled -> enabled
is-active -> active

默认数据库：
information_schema
mysql
performance_schema
test

datadir：
/var/lib/mysql/
```

说明：

```text
information_schema
  -> 元数据数据库，记录库、表、字段等信息。

mysql
  -> 系统库，保存用户、权限等重要信息。

performance_schema
  -> 性能相关信息。

test
  -> 默认测试库。
```

## 8. 查看数据目录

执行过：

```bash
sudo ls -ld /var/lib/mysql
sudo ls -l /var/lib/mysql
```

语法说明：

```text
ls -ld /var/lib/mysql
  -> 查看目录本身的信息。

ls -l /var/lib/mysql
  -> 查看目录里面的文件。
```

看到的关键结果：

```text
/var/lib/mysql 属主和属组是 mysql mysql。
目录里有 ibdata1、ib_logfile0、ib_logfile1、mysql、performance_schema、test、mysql.sock。
```

常见文件说明：

```text
ibdata1
  -> InnoDB 数据文件。

ib_logfile0 / ib_logfile1
  -> InnoDB 日志文件。

mysql/
  -> 系统库目录，保存用户权限等信息。

mysql.sock
  -> 本地 socket 文件，本机 mysql 客户端可通过它连接数据库。
```

注意：

```text
/var/lib/mysql 是数据库真实数据目录，不要手动乱删。
```

## 9. 查看配置文件和日志文件位置

执行过：

```bash
rpm -qc mariadb-server
sudo grep -RniE "datadir|socket|port|bind-address" /etc/my.cnf /etc/my.cnf.d
```

语法说明：

```text
rpm -qc mariadb-server
  -> 查询 mariadb-server 这个软件包安装的配置文件。
  -> -q 表示 query 查询。
  -> -c 表示 config 配置文件。

grep -RniE
  -> -R：递归搜索目录。
  -> -n：显示行号。
  -> -i：忽略大小写。
  -> -E：扩展正则。

datadir|socket|port|bind-address
  -> 查数据目录、socket、端口、绑定地址这些关键配置。
```

结果：

```text
/etc/logrotate.d/mariadb
/etc/my.cnf.d/server.cnf
/var/log/mariadb/mariadb.log

/etc/my.cnf:2:datadir=/var/lib/mysql
/etc/my.cnf:3:socket=/var/lib/mysql/mysql.sock
```

结论：

```text
当前数据目录是 /var/lib/mysql。
当前本地 socket 文件是 /var/lib/mysql/mysql.sock。
没有显式配置 port 和 bind-address，结合日志和 ss 可知当前监听 3306，并监听 0.0.0.0。
```

## 10. 查看 MariaDB 日志

执行过：

```bash
sudo ls -l /var/log/mariadb/
sudo tail -n 30 /var/log/mariadb/mariadb.log
```

语法说明：

```text
tail -n 30
  -> 查看文件最后 30 行。

/var/log/mariadb/mariadb.log
  -> MariaDB 日志文件。
```

看到的关键日志：

```text
Starting mysqld daemon with databases from /var/lib/mysql
Server socket created on IP: '0.0.0.0'
ready for connections
socket: '/var/lib/mysql/mysql.sock'  port: 3306
```

解释：

```text
daemon
  -> 后台守护进程。
  -> 前面 systemd、nginx、crond 都属于这类长期运行的后台服务。

0.0.0.0
  -> 监听所有 IPv4 地址。

ready for connections
  -> 数据库已经准备好接受连接。
```

## 11. 用户、Host 和远程访问判断

执行过：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
sudo firewall-cmd --list-all
```

结果：

```text
root@127.0.0.1
root@::1
root@centos100
root@localhost
匿名用户 @centos100
匿名用户 @localhost

firewalld 只放行：
dhcpv6-client http ssh
没有放行 3306。
```

结论：

```text
本机可以连接数据库。
远程连接还没有准备好，因为至少要同时满足：
1. mysqld 监听 3306。
2. firewalld 放行 3306。
3. MySQL 用户 Host 允许远程来源。
4. 网络本身可达。
```

一句话记住：

```text
MySQL 账号不是只有用户名，还要看 User + Host。
```

## 12. USER() 和 CURRENT_USER()

执行过：

```bash
mysql -uroot -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -h127.0.0.1 -e "SELECT USER(),CURRENT_USER();"
```

语法说明：

```text
USER()
  -> 客户端请求登录时使用的身份。

CURRENT_USER()
  -> MySQL 最终匹配到的权限身份。
```

结果：

```text
USER()         -> root@localhost
CURRENT_USER() -> root@localhost
```

结论：

```text
当前登录最终匹配到 root@localhost 的权限。
```

## 13. 创建业务库

执行过：

```bash
mysql -uroot -e "CREATE DATABASE ops_demo;"
mysql -uroot -e "SHOW DATABASES;"
```

语法说明：

```text
CREATE DATABASE ops_demo;
  -> 创建名为 ops_demo 的数据库。

SHOW DATABASES;
  -> 查看数据库列表，确认创建成功。
```

结果：

```text
数据库列表中出现 ops_demo。
```

## 14. 创建表和 No database selected

一开始执行过：

```bash
mysql -uroot -e "CREATE TABLE servers(id INT PRIMARY KEY AUTO_INCREMENT,hostname VARCHAR(50),ip VARCHAR(50), role VARCHAR(50));"
```

报错：

```text
ERROR 1046 (3D000) at line 1: No database selected
```

原因：

```text
创建表必须先选中一个数据库。
上面命令没有告诉 MySQL 要在哪个数据库里创建 servers 表。
```

修正后执行：

```bash
mysql -uroot ops_demo -e "CREATE TABLE servers(id INT PRIMARY KEY AUTO_INCREMENT,hostname VARCHAR(50),ip VARCHAR(50), role VARCHAR(50));"
mysql -uroot ops_demo -e "SHOW TABLES;"
```

语法说明：

```text
mysql -uroot ops_demo
  -> 使用 root 登录，并直接选中 ops_demo 数据库。

CREATE TABLE servers(...)
  -> 创建 servers 表。

id INT PRIMARY KEY AUTO_INCREMENT
  -> id 是整数主键，并且自动递增。

hostname VARCHAR(50)
  -> hostname 字段，最多 50 个字符。

ip VARCHAR(50)
  -> ip 字段，最多 50 个字符。

role VARCHAR(50)
  -> role 字段，最多 50 个字符。
```

结果：

```text
SHOW TABLES 显示 servers。
```

## 15. INSERT 插入数据

执行过：

```bash
mysql -uroot ops_demo -e "INSERT INTO servers(hostname,ip,role) VALUES ('centos100','192.168.6.100','nginx-mysql-backend');"
```

语法说明：

```text
INSERT INTO servers(hostname,ip,role)
  -> 往 servers 表的 hostname、ip、role 三个字段插入数据。

VALUES (...)
  -> 具体插入的值。
```

说明：

```text
id 字段没有手动写，因为它是 AUTO_INCREMENT，会自动生成。
```

## 16. SELECT 查询数据

执行过：

```bash
mysql -uroot ops_demo -e "SELECT * FROM servers;"
mysql -uroot ops_demo -e "SELECT hostname,ip FROM servers;"
mysql -uroot ops_demo -e "SELECT * FROM servers WHERE ip='192.168.6.100';"
```

语法说明：

```text
SELECT * FROM servers;
  -> 查询 servers 表所有字段、所有行。

SELECT hostname,ip FROM servers;
  -> 只查询 hostname 和 ip 两列。

WHERE ip='192.168.6.100'
  -> 只查询 ip 等于 192.168.6.100 的行。
```

看到的数据：

```text
id=1
hostname=centos100
ip=192.168.6.100
role=nginx-mysql-backend
```

## 17. UPDATE 修改数据

执行过：

```bash
mysql -uroot ops_demo -e "UPDATE servers SET role='all-in-one' WHERE hostname='centos100';"
mysql -uroot ops_demo -e "SELECT * FROM servers;"
```

语法说明：

```text
UPDATE servers
  -> 修改 servers 表。

SET role='all-in-one'
  -> 把 role 字段改成 all-in-one。

WHERE hostname='centos100'
  -> 只修改 hostname 为 centos100 的行。
```

结果：

```text
role 从 nginx-mysql-backend 变成 all-in-one。
```

注意：

```text
UPDATE 一定要小心 WHERE。
没有 WHERE 可能会修改整张表。
```

## 18. DELETE 删除数据

执行过：

```bash
mysql -uroot ops_demo -e "INSERT INTO servers (hostname, ip, role) VALUES ('test-host', '192.168.6.200', 'test');"
mysql -uroot ops_demo -e "SELECT * FROM servers;"
mysql -uroot ops_demo -e "DELETE FROM servers WHERE hostname='test-host';"
mysql -uroot ops_demo -e "SELECT * FROM servers;"
```

语法说明：

```text
DELETE FROM servers
  -> 从 servers 表删除数据。

WHERE hostname='test-host'
  -> 只删除 hostname 为 test-host 的行。
```

最终结果：

```text
servers 表只剩一行：
id=1, hostname=centos100, ip=192.168.6.100, role=all-in-one
```

注意：

```text
DELETE 一定要小心 WHERE。
没有 WHERE 可能会删除整张表。
```

## 19. 运维为什么要会基础 SQL

运维不一定天天写复杂 SQL，但必须会基础检查：

```text
检查业务库是否存在
  -> SHOW DATABASES;

确认表是否存在
  -> SHOW TABLES;

确认表里有没有数据
  -> SELECT * FROM 表名 LIMIT 10;
  -> SELECT COUNT(*) FROM 表名;

排查账号权限
  -> SELECT User,Host FROM mysql.user;

验证备份恢复是否正常
  -> 恢复后查库、查表、查数据行数、查关键数据。
```

一句话记住：

```text
基础 SQL 是运维判断“数据库到底有没有、表到底有没有、数据到底还在不在”的工具。
```

## 20. 当前状态

当前 MariaDB 状态：

```text
mariadb.service 已安装。
mariadb.service 已启动。
mariadb.service 已设置开机自启动。
3306 端口正在监听。
ops_demo 数据库已创建。
servers 表已创建。
最终保留一条数据：
centos100 / 192.168.6.100 / all-in-one
```

## 21. 下一步

下一节从备份恢复开始。

先执行：

```bash
which mysqldump
mysqldump --version
```

目标：

```text
1. 确认 mysqldump 备份工具是否存在。
2. 备份 ops_demo 数据库。
3. 查看备份 SQL 文件内容。
4. 模拟删除/恢复。
5. 验证恢复后的数据。
6. 后面再写 Shell 备份脚本，并用 crontab 定时执行。
```

## 22. mysqldump 备份工具检查

执行过：

```bash
which mysqldump
mysqldump --version
```

结果：

```text
/usr/bin/mysqldump
mysqldump  Ver 10.14 Distrib 5.5.68-MariaDB, for Linux (x86_64)
```

说明：

```text
mysqldump 已安装。
它是 MariaDB 5.5.68 配套的数据库导出工具。
```

一句话记住：

```text
mysqldump 是把数据库导出成 SQL 文本文件的备份工具。
```

## 23. 手动备份 ops_demo

执行过：

```bash
mkdir -p ~/mysql_backup
mysqldump -uroot ops_demo > ~/mysql_backup/ops_demo.sql
ls -lh ~/mysql_backup/ops_demo.sql
```

语法说明：

```text
mkdir -p ~/mysql_backup
  -> 创建备份目录；目录已存在也不报错。

mysqldump -uroot ops_demo
  -> 用数据库 root 用户导出 ops_demo 数据库。

>
  -> 输出重定向，把导出的 SQL 内容写入文件。

~/mysql_backup/ops_demo.sql
  -> 备份文件路径。

ls -lh
  -> 查看文件详细信息，-h 用人类易读单位显示大小。
```

验证结果：

```text
/home/atguigu/mysql_backup/ops_demo.sql 存在。
大小约 2.0K。
```

## 24. 查看备份文件内容

执行过：

```bash
head -n 30 ~/mysql_backup/ops_demo.sql
grep -n "INSERT INTO" ~/mysql_backup/ops_demo.sql
```

看到过：

```sql
DROP TABLE IF EXISTS `servers`;
CREATE TABLE `servers` (
...
INSERT INTO `servers` VALUES (1,'centos100','192.168.6.100','all-in-one');
```

结论：

```text
备份文件里包含表结构：CREATE TABLE。
备份文件里包含表数据：INSERT INTO。
```

一句话记住：

```text
mysqldump 备份文件通常包含“建表语句 + 插入数据语句”。
```

## 25. 恢复到新库并验证

为了不动原始库，先恢复到新库 `ops_demo_restore`。

执行过：

```bash
mysql -uroot -e "CREATE DATABASE ops_demo_restore;"
mysql -uroot ops_demo_restore < ~/mysql_backup/ops_demo.sql
mysql -uroot ops_demo_restore -e "SELECT * FROM servers;"
mysql -uroot -e "SHOW DATABASES LIKE 'ops_demo%';"
mysql -uroot ops_demo_restore -e "SELECT COUNT(*) FROM servers;"
```

语法说明：

```text
<
  -> 输入重定向，把 SQL 文件内容交给 mysql 执行。

mysql -uroot ops_demo_restore < ops_demo.sql
  -> 把备份文件恢复到 ops_demo_restore 数据库。

COUNT(*)
  -> 统计表里的总行数。
```

验证结果：

```text
ops_demo 和 ops_demo_restore 都存在。
ops_demo_restore.servers 有 1 行数据。
数据为 centos100 / 192.168.6.100 / all-in-one。
```

一句话记住：

```text
mysqldump 备份用 > 导出，mysql 恢复用 < 导入。
```

## 26. 模拟误删并恢复

只在恢复库里模拟误删，不动原始库。

执行过：

```bash
mysql -uroot ops_demo_restore -e "DELETE FROM servers;"
mysql -uroot ops_demo_restore -e "SELECT COUNT(*) FROM servers;"
mysql -uroot ops_demo_restore < ~/mysql_backup/ops_demo.sql
mysql -uroot ops_demo_restore -e "SELECT * FROM servers;"
```

结果：

```text
DELETE 后 COUNT(*) 变成 0。
重新导入备份文件后，servers 表数据恢复成功。
```

重要提醒：

```text
DELETE 不写 WHERE，会删除整张表的数据。
真实生产环境非常危险。
```

一句话记住：

```text
备份不是目的，能恢复并验证数据才算真正备份成功。
```

## 27. 带时间戳的备份文件名

执行过：

```bash
DATE=$(date '+%Y%m%d_%H%M%S')
echo $DATE
mysqldump -uroot ops_demo > ~/mysql_backup/ops_demo_${DATE}.sql
ls -lh ~/mysql_backup/
```

学到的点：

```text
DATE=$(date '+%Y%m%d_%H%M%S')
  -> 把当前时间保存到 DATE 变量。

${DATE}
  -> 更明确地取变量值，适合和其他字符拼接文件名。

ops_demo_${DATE}.sql
  -> 生成不会重复的备份文件名。
```

注意：

```text
变量赋值后不会自动变化。
如果想更新时间戳，就要重新执行 DATE=$(date ...)。 
```

## 28. MySQL 备份脚本

创建过脚本：

```bash
~/backup_ops_demo.sh
```

基础版脚本做过：

```text
定义数据库名 DB_NAME。
定义备份目录 BACKUP_DIR。
生成时间 DATE。
拼接备份文件 BACKUP_FILE。
执行 mysqldump。
输出 backup finished。
```

检查和执行过：

```bash
bash -n ~/backup_ops_demo.sh
bash ~/backup_ops_demo.sh
echo $?
ls -lh ~/mysql_backup/
```

学到的点：

```text
bash -n
  -> 只检查语法，不真正执行。

bash 脚本名
  -> 用 bash 执行脚本，不要求脚本本身有执行权限。

sudo ~/backup_ops_demo.sh
  -> 让 root 直接执行脚本，需要执行权限，而且 HOME 可能变成 /root。

$?
  -> 只保存上一条命令的退出状态。
  -> 想判断某条命令是否成功，echo $? 必须紧跟在那条命令后面。
```

后续加过成功/失败判断：

```bash
mysqldump -uroot "$DB_NAME" > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "backup finished: $BACKUP_FILE"
else
    echo "backup failed"
fi
```

更稳的写法是：

```bash
mysqldump -uroot "$DB_NAME" > "$BACKUP_FILE"
STATUS=$?
```

因为：

```text
$? 很容易被下一条命令覆盖。
STATUS=$? 是把 mysqldump 的执行结果先保存起来。
```

## 29. 带日志版备份脚本

后续把脚本升级为带日志版，新增：

```bash
LOG_FILE="$BACKUP_DIR/backup.log"

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}
```

语法说明：

```text
LOG_FILE
  -> 日志文件路径，当前是 /home/atguigu/mysql_backup/backup.log。

log()
  -> 自定义函数，用来统一写日志。

date '+%F %T'
  -> 生成类似 2026-07-09 19:29:28 的时间。

$*
  -> 函数接收到的所有参数。

>>
  -> 追加写入日志，不覆盖旧日志。
```

执行并验证过：

```bash
bash ~/backup_ops_demo.sh
tail -n 5 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup/
```

看到过：

```text
[2026-07-09 19:29:28] start backup: db=ops_demo file=/home/atguigu/mysql_backup/ops_demo_20260709_192928.sql
[2026-07-09 19:29:28] backup finished: /home/atguigu/mysql_backup/ops_demo_20260709_192928.sql
```

结论：

```text
脚本执行成功。
新备份文件生成成功。
backup.log 日志记录成功。
```

一句话记住：

```text
脚本放进 crontab 前，最好先让它自己会写日志，否则定时任务失败时不好排查。
```

## 30. crontab 定时备份验证

为了让 crontab 更稳定，先查看了命令绝对路径：

```bash
which bash
which mysqldump
```

结果：

```text
/usr/bin/bash
/usr/bin/mysqldump
```

原因：

```text
crontab 执行任务时环境更简陋，不要过度依赖 PATH 和 ~。
推荐写绝对路径。
```

查看普通用户 crontab：

```bash
crontab -l
```

一开始看到：

```text
no crontab for atguigu
```

后来添加测试任务：

```cron
* * * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

验证过：

```bash
tail -n 10 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup/
```

看到过：

```text
[2026-07-09 19:41:01] start backup...
[2026-07-09 19:41:01] backup finished...
[2026-07-09 19:42:01] start backup...
[2026-07-09 19:42:01] backup finished...
ops_demo_20260709_194101.sql
ops_demo_20260709_194201.sql
```

结论：

```text
普通用户 atguigu 的 crontab 每分钟自动执行脚本成功。
日志和备份文件都证明了定时任务生效。
```

注意：

```text
每分钟备份只是测试用，不能长期保留，否则备份文件会越来越多。
下一步应把它改成每天凌晨 3 点：
0 3 * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

最终已确认：

```bash
crontab -l
```

输出已经是：

```cron
0 3 * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

结论：

```text
测试用的每分钟备份任务已经改成每天凌晨 3 点执行。
```

## 31. 备份保留策略

为什么需要保留策略：

```text
如果每天都生成一个 .sql 备份文件，时间久了会越来越多。
备份文件太多会占用磁盘，严重时可能把系统或数据盘写满。
所以运维通常会设置保留策略，比如只保留最近 7 天。
```

先查看备份目录大小：

```bash
du -sh ~/mysql_backup
```

语法说明：

```text
du
  -> 查看磁盘占用。

-s
  -> summary，只显示总大小。

-h
  -> human readable，用 K/M/G 这种易读单位显示。

~/mysql_backup
  -> MySQL 备份目录。
```

看到过：

```text
60K    /home/atguigu/mysql_backup
```

说明：

```text
当前备份目录很小，只有 60K。
```

预览超过 7 天的旧备份：

```bash
find ~/mysql_backup -name "*.sql" -mtime +7
```

语法说明：

```text
find
  -> 查找文件。

~/mysql_backup
  -> 从备份目录开始找。

-name "*.sql"
  -> 只匹配 .sql 结尾的文件。

-mtime +7
  -> 修改时间超过 7 天。
```

当时没有输出：

```text
说明当前没有超过 7 天的 .sql 备份文件。
没有输出不一定是错误，也可能表示没有符合条件的文件。
```

为了理解时间条件，又学习了：

```bash
find ~/mysql_backup -name "*.sql" -mtime -1
```

含义：

```text
-mtime -1
  -> 最近 1 天以内修改过的文件。

-mtime +7
  -> 超过 7 天的文件。
```

真正删除旧备份的命令是：

```bash
find ~/mysql_backup -name "*.sql" -mtime +7 -delete
```

但是更安全的脚本写法是：

```bash
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql" -mtime +7 -delete
```

为什么更安全：

```text
"$BACKUP_DIR"
  -> 只在备份目录里查找。

-name "${DB_NAME}_*.sql"
  -> 只匹配 ops_demo_*.sql 这种自动备份文件。
  -> 不会误删手动保存的 ops_demo.sql。

-mtime +7
  -> 只处理超过 7 天的旧文件。

-delete
  -> 删除匹配到的文件。
```

脚本中的位置：

```bash
if [ "$STATUS" -eq 0 ]; then
    log "backup finished: $BACKUP_FILE"
    echo "backup finished: $BACKUP_FILE"
    find "$BACKUP_DIR" -name "${DB_NAME}_*.sql" -mtime +7 -delete
    log "old backups cleaned: keep last 7 days"
else
    log "backup failed: db=$DB_NAME"
    echo "backup failed"
fi
```

为什么放在备份成功之后：

```text
如果先删除旧备份，再执行新备份，而新备份失败，就可能出现“旧备份删了，新备份也没成功”的风险。
所以更稳的顺序是：先备份成功，再清理旧备份。
```

验证过：

```bash
bash -n ~/backup_ops_demo.sh
bash ~/backup_ops_demo.sh
tail -n 5 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup | tail
```

看到过：

```text
[2026-07-09 20:29:12] start backup: db=ops_demo file=/home/atguigu/mysql_backup/ops_demo_20260709_202912.sql
[2026-07-09 20:29:12] backup finished: /home/atguigu/mysql_backup/ops_demo_20260709_202912.sql
[2026-07-09 20:29:12] old backups cleaned: keep last 7 days
ops_demo_20260709_202912.sql
```

结论：

```text
备份脚本已经具备：
1. 生成带时间戳的新备份。
2. 写入 backup.log。
3. 只在备份成功后清理超过 7 天的 ops_demo_*.sql。
4. 通过 crontab 每天凌晨 3 点自动执行。
```

一句话记住：

```text
危险命令先预览，再执行；备份清理要放在备份成功之后。
```

## 32. 下一步

下一节进入 MySQL 用户权限和安全加固。

目标：

```text
1. 理解 User + Host。
2. 清理或理解匿名用户风险。
3. 创建普通业务用户。
4. 授予最小权限。
5. 验证用户能不能登录、能不能访问指定库。
6. 了解远程连接要同时满足网络、端口、防火墙和 MySQL 权限。
```

## 33. MySQL 用户权限和安全加固

本节位置：

```text
MySQL/MariaDB 系统运维中的用户权限和安全基础。
```

和前面知识的关系：

```text
网络基础
  -> MySQL 远程连接要看 IP、端口、来源主机。

firewalld
  -> 远程连接 3306 还要看防火墙是否放行。

Shell / crontab
  -> 备份脚本不应该随便使用超级权限账号。

Nginx / 后端服务
  -> 真实项目里后端程序连接数据库时，应该使用普通业务用户，不应该使用 root。
```

一句话记住：

```text
MySQL 用户不是只看用户名，而是看完整的 'User'@'Host'。
```

### 33.1 查看用户和来源

执行过：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
```

看到过：

```text
root@127.0.0.1
root@::1
root@centos100
root@localhost
匿名用户 ''@centos100
匿名用户 ''@localhost
```

含义：

```text
User
  -> 谁登录。

Host
  -> 从哪里登录。

127.0.0.1
  -> IPv4 本机地址，通常表示本机 TCP 连接。

::1
  -> IPv6 本机地址。

localhost
  -> 本机名称，MySQL 客户端连接 localhost 时通常走本地 socket。

centos100
  -> 当前 Linux 主机名。
```

### 33.2 root 权限

执行过：

```bash
mysql -uroot -e "SHOW GRANTS FOR 'root'@'localhost';"
```

看到过：

```text
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION
```

语法说明：

```text
ALL PRIVILEGES
  -> 所有权限。

ON *.*
  -> 所有数据库、所有表。

WITH GRANT OPTION
  -> 可以把自己的权限再授权给别人。
```

结论：

```text
root@localhost 是本机数据库超级管理员。
业务程序不应该直接使用 root 连接数据库。
```

### 33.3 匿名用户

执行过：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='';"
mysql -uroot -e "SHOW GRANTS FOR ''@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR ''@'centos100';"
```

看到过：

```text
''@'localhost'
''@'centos100'

GRANT USAGE ON *.* TO ''@'localhost'
GRANT USAGE ON *.* TO ''@'centos100'
```

说明：

```text
'' 表示空用户名，也就是匿名用户。

USAGE 表示账号存在，但没有实际库表读写权限。
```

结论：

```text
匿名用户即使权限很小，也属于不必要账号，生产环境一般要清理。
```

已经删除匿名用户，并验证：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='';"
```

结果：

```text
没有输出，说明匿名用户已不存在。
```

### 33.4 创建普通业务用户

已经创建：

```text
ops_user@localhost
```

注意：

```text
创建用户时设置过练习密码，但笔记不记录明文密码。
SHOW GRANTS 输出过密码哈希，但笔记不记录哈希。
```

验证用户：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='ops_user';"
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
```

看到过：

```text
ops_user | localhost
```

说明：

```text
ops_user 只允许从 localhost 登录。
```

### 33.5 初始权限和登录验证

执行过：

```bash
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

看到过：

```text
GRANT USAGE ON *.* TO 'ops_user'@'localhost' ...
```

说明：

```text
刚创建的用户只有 USAGE，能登录，但没有业务库权限。
```

用 `ops_user` 登录查看数据库：

```bash
mysql -uops_user -p -e "SHOW DATABASES;"
```

看到过：

```text
information_schema
test
```

结论：

```text
ops_user 能登录，但还看不到 ops_demo，说明没有业务库权限。
```

### 33.6 授予最小业务权限

执行过：

```bash
mysql -uroot -e "GRANT SELECT,INSERT,UPDATE,DELETE ON ops_demo.* TO 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

看到过：

```text
GRANT SELECT, INSERT, UPDATE, DELETE ON `ops_demo`.* TO 'ops_user'@'localhost'
```

语法说明：

```text
GRANT
  -> 授权。

SELECT
  -> 查询。

INSERT
  -> 插入。

UPDATE
  -> 修改。

DELETE
  -> 删除。

ON ops_demo.*
  -> 只对 ops_demo 数据库里的所有表生效。

TO 'ops_user'@'localhost'
  -> 授权给本机业务用户。
```

没有授予：

```text
DROP
  -> 不能删库删表。

CREATE
  -> 不能建库建表。

GRANT OPTION
  -> 不能把权限再授权给别人。

mysql.*
  -> 不能管理 MySQL 系统用户表。
```

一句话记住：

```text
业务用户只给业务需要的权限，不给超级权限，这叫最小权限原则。
```

## 34. 当前停点

当前已经完成：

```text
匿名用户清理。
ops_user@localhost 创建。
ops_user 登录验证。
ops_user 对 ops_demo.* 的 SELECT、INSERT、UPDATE、DELETE 授权。
```

下一步验证授权是否真的生效：

```bash
mysql -uops_user -p ops_demo -e "SELECT * FROM servers;"
```

预期：

```text
能查到 servers 表里的 centos100 / 192.168.6.100 / all-in-one。
```

## 35. 验证业务用户授权

执行过：

```bash
mysql -uops_user -p ops_demo -e "SELECT * FROM servers;"
```

结果：

```text
成功查询到：centos100 / 192.168.6.100 / all-in-one。
```

说明：

```text
ops_user@localhost 登录成功。
ops_demo 数据库可以访问。
servers 表的 SELECT 权限实际生效。
```

## 36. 验证系统表访问被拒绝

执行过：

```bash
mysql -uops_user -p -e "SELECT User,Host FROM mysql.user;"
```

结果：

```text
ERROR 1142 (42000): SELECT command denied to user 'ops_user'@'localhost' for table 'user'
```

结论：

```text
ops_user 能登录，但不能读取 mysql.user 系统用户表。
这证明最小权限边界正确。
```

## 37. SHOW GRANTS、REVOKE 与权限恢复

查看当前用户权限：

```bash
mysql -uops_user -p -e "SHOW GRANTS;"
```

临时撤销 DELETE：

```bash
mysql -uroot -e "REVOKE DELETE ON ops_demo.* FROM 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

撤权后，权限变为：

```text
SELECT、INSERT、UPDATE
```

使用不会匹配现有数据的条件验证 DELETE：

```bash
mysql -uops_user -p ops_demo -e "DELETE FROM servers WHERE hostname='permission-test-not-exist';"
```

结果：

```text
ERROR 1142 (42000): DELETE command denied
```

恢复 DELETE 权限：

```bash
mysql -uroot -e "GRANT DELETE ON ops_demo.* TO 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

最终状态：

```text
ops_user@localhost 对 ops_demo.* 拥有 SELECT、INSERT、UPDATE、DELETE。
```

一句话记住：

```text
GRANT 用 TO 授权，REVOKE 用 FROM 撤权；SHOW GRANTS 看配置，实际 SQL 验证效果。
```

## 38. 下一步

```text
进入 MySQL 常见故障排查小练习，然后完成 MySQL 第一阶段总结。
```

