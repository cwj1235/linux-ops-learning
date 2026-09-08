# 运维学习命令履历

归档位置：`项目记录/ops_command_history.md`。

用途：让新线程或其他模型快速知道我已经实际敲过哪些命令、验证过哪些结果、排过哪些故障。

最后更新：2026-07-11

说明：

```text
这不是完整聊天记录，而是“已实践命令清单”。
后续模型不要让我重复所有旧命令，除非是为了复习或验证当前状态。
```

## 1. 系统和网络环境确认

已经执行过：

```bash
cat /etc/os-release
whoami
hostname
ip addr
ip route
ping -c 4 baidu.com
sudo -v
```

学到的结论：

```text
系统：CentOS Linux 7
用户：atguigu
主机名：centos100
Linux IP：192.168.6.100/24
网卡：ens33
网关：192.168.6.2
DNS：192.168.6.2
```

## 2. 网络基础命令

已经执行过：

```bash
ping -c 4 127.0.0.1
ping -c 4 192.168.6.100
ping -c 4 192.168.6.2
ping -c 4 8.8.8.8
ping -c 4 baidu.com
ip route get 192.168.6.2
ip route get 8.8.8.8
ip route get 192.168.122.1
cat /etc/resolv.conf
nslookup baidu.com
dig +short baidu.com
```

学到的结论：

```text
127.0.0.1 是本机回环地址。
192.168.6.100 是 Linux 虚拟机 IP。
192.168.6.2 是 VMware NAT 网关和 DNS。
同网段直接访问，不同网段走网关。
域名访问需要 DNS 解析。
```

## 3. Windows 和 VMware 网络

Windows 执行过：

```cmd
ipconfig
ping 192.168.6.100
```

Linux 执行过：

```bash
ping -c 4 192.168.6.1
ping -c 4 192.168.6.2
```

学到的结论：

```text
Windows VMnet8：192.168.6.1
Linux VM：192.168.6.100
VMware NAT 网关：192.168.6.2
Windows 能 ping 通 Linux。
Linux ping 192.168.6.1 不通可能是 Windows 防火墙阻止 ICMP，不代表网络一定坏。
```

## 4. yum 和 Nginx 安装

遇到过 yum mirrorlist 解析失败：

```text
Could not resolve host: mirrorlist.centos.org
Cannot find a valid baseurl for repo: base/7/x86_64
```

后续执行成功：

```bash
sudo yum makecache
sudo yum install -y epel-release
sudo yum install -y nginx
```

学到的结论：

```text
CentOS 7 安装 Nginx 需要 EPEL 仓库。
yum makecache 用于建立/刷新 yum 元数据缓存。
```

## 5. firewalld 防火墙

已经执行过：

```bash
sudo firewall-cmd --state
sudo firewall-cmd --list-all
sudo firewall-cmd --list-services
sudo firewall-cmd --list-ports
sudo firewall-cmd --info-service=http
sudo firewall-cmd --info-service=ssh
sudo firewall-cmd --query-service=http
sudo firewall-cmd --query-service=ssh
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --remove-service=http
sudo firewall-cmd --add-service=http
sudo firewall-cmd --add-port=8080/tcp
sudo firewall-cmd --remove-port=8080/tcp
sudo firewall-cmd --query-port=8080/tcp
```

学到的结论：

```text
http 服务对应 80/tcp。
ssh 服务对应 22/tcp。
firewalld 控制 Linux 本机端口是否允许外部访问。
临时规则不加 --permanent，重载后可能失效。
反向代理场景下，外部通常只开放 80/443，不直接开放后端 8080。
```

## 6. Nginx 服务管理

已经执行过：

```bash
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl status nginx
sudo systemctl reload nginx
sudo nginx -t
ss -lntp | grep :80
sudo ss -lntp | grep -E ':22|:80'
curl -I http://192.168.6.100
curl http://192.168.6.100
```

学到的结论：

```text
systemctl 管理服务。
nginx -t 用于检查配置语法。
ss -lntp 查看监听端口和进程。
curl -I 只看响应头和状态码。
```

## 7. Nginx 静态网站

已经执行过：

```bash
ls -l /usr/share/nginx/html
curl http://192.168.6.100
sudo grep -nE "listen|server_name|root|index|error_page" /etc/nginx/nginx.conf
ls -ld /var/www /var/www/ops-site
ls -l /var/www/ops-site
```

创建过：

```text
/var/www/ops-site/index.html
/usr/share/nginx/html/notfound.html
```

学到的结论：

```text
Nginx 根据 root 指定的网站目录找文件。
网页显示自己写的内容，是因为 Nginx 读到了对应目录下的 index.html。
```

## 8. Nginx 日志和状态码

已经执行过：

```bash
sudo tail -n 5 /var/log/nginx/access.log
sudo tail -n 20 /var/log/nginx/error.log
curl -I http://192.168.6.100/notfound.html
curl http://192.168.6.100/notfound.html
curl -I http://192.168.6.100/not-exist.html
```

见过的状态码：

```text
200 OK
304 Not Modified
403 Forbidden
404 Not Found
502 Bad Gateway
```

学到的结论：

```text
access.log 看谁访问了什么、返回什么状态码。
error.log 看失败原因。
404 通常是文件或路径不存在。
403 常见于权限或 SELinux。
502 通常是 Nginx 后端服务连不上。
```

## 9. SELinux

已经执行过：

```bash
getenforce
ls -Z /var/www/ops-site/index.html
ls -Zd /var/www/ops-site
sudo chcon -R -t httpd_sys_content_t /var/www/ops-site
getsebool httpd_can_network_connect
sudo setsebool -P httpd_can_network_connect on
```

学到的结论：

```text
getenforce 查看 SELinux 状态。
Enforcing 表示 SELinux 正在强制执行。
ls -Z / ls -Zd 查看 SELinux 上下文。
chcon 修复 Nginx 读取本地静态文件权限。
setsebool -P httpd_can_network_connect on 允许 Nginx 连接后端网络服务。
```

## 10. Shell 脚本基础

已经执行过：

```bash
NAME="nginx"
echo $NAME
echo "service name is $NAME"
echo 'service name is $NAME'
[ -f /var/log/nginx_check.log ]; echo $?
[ -d /var/log ]; echo $?
[ -f /var/log ]; echo $?
if [ -f /var/log/nginx_check.log ]; then echo "log file exists"; else echo "log file not found"; fi
LOG_FILE="/var/log/nginx_check.log"
stat -c%s "$LOG_FILE"
LOG_SIZE=$(stat -c%s "$LOG_FILE")
echo $LOG_SIZE
MAX_SIZE=$[ 1024 * 1024]
if [ "$LOG_SIZE" -gt "$MAX_SIZE" ]; then echo "log is too large"; else echo "log size is ok"; fi
echo "${LOG_FILE}.$(date '+%Y%m%d%H%M%S').bak"
```

学到的结论：

```text
变量赋值等号两边不能有空格。
双引号会解析变量，单引号不会。
-f 判断文件，-d 判断目录。
$? 是上一条命令的退出状态，0 表示成功。
$(命令) 是命令替换。
stat -c%s 查看文件大小。
-gt 是数值大于比较。
```

## 11. Shell 日志和函数

已经执行过：

```bash
TEST_LOG="/tmp/shell_test.log"
echo "[$(date '+%F %T')] hello shell" >> "$TEST_LOG"
cat "$TEST_LOG"
LOG_FILE="/tmp/shell_test.log"
log() {
    echo "[$(date '+%F %T')] $1" >> "$LOG_FILE"
}
log "hello function"
log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}
log nginx service is running
log "website check OK, http_code=200"
```

学到的结论：

```text
> 覆盖写入，>> 追加写入。
date '+%F %T' 生成时间戳。
函数可以封装重复逻辑。
$1 表示第一个参数，$* 表示所有参数。
```

## 12. curl 和 HTTP 状态码脚本

已经执行过：

```bash
URL="http://192.168.6.100"
curl -o /dev/null -s -w "%{http_code}\n" $URL
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" $URL)
echo $HTTP_CODE
echo $(HTTP_CODE)
if [ "$HTTP_CODE" = "200" ]; then echo "website check OK"; else echo "website check FAILED"; fi
HTTP_CODE="404"
HTTP_CODE="500"
HTTP_CODE_AFTER_RESTART="200"
```

学到的结论：

```text
/dev/null 会丢弃输出。
curl -o 指定输出文件。
curl -O 使用远程文件名下载。
curl -s 静默模式。
curl -w "%{http_code}" 输出 HTTP 状态码。
$HTTP_CODE 是取变量值。
$(HTTP_CODE) 是执行名为 HTTP_CODE 的命令，会报错。
```

## 13. Nginx 健康检查脚本

脚本位置：

```bash
/opt/scripts/check_nginx.sh
```

日志位置：

```bash
/var/log/nginx_check.log
```

已经执行过：

```bash
sudo cat /opt/scripts/check_nginx.sh
bash -n /opt/scripts/check_nginx.sh
sudo /opt/scripts/check_nginx.sh
sudo tail -n 30 /var/log/nginx_check.log
```

学到的结论：

```text
bash -n 只检查语法，不真正执行脚本。
sudo /opt/scripts/check_nginx.sh 会真正执行脚本。
脚本能检查 nginx 是否运行，检查网站状态码，并写入日志。
```

## 14. crontab 定时任务

已经执行过：

```bash
crontab -l
sudo crontab -l
```

root 定时任务曾经是：

```cron
* * * * * /opt/scripts/check_nginx.sh
```

学过的表达式：

```cron
*/10 * * * * command
0 3 * * * command
30 2 * * 1 command
0 9,12,18 * * * command
0 9-10 * * * command
0 9-18 * * * command
```

学到的结论：

```text
crontab 用来定时执行任务。
sudo crontab 是 root 的定时任务。
普通 crontab 是当前用户的定时任务。
```

## 15. Python 后端服务

已经执行过：

```bash
python --version
python3 --version
which python
which python3
python -m SimpleHTTPServer 8080
curl http://127.0.0.1:8080
curl http://192.168.6.100:8080
ss -lntp | grep :8080
ps -fp 6451
kill 6451
```

学到的结论：

```text
CentOS 7 默认有 Python 2.7.5。
python -m SimpleHTTPServer 8080 可以临时启动一个 HTTP 服务。
8080 被占用时，systemd 后端服务无法再启动同一个端口。
ps -fp PID 查看进程详情。
kill PID 停止进程。
```

## 16. systemd 后端服务

创建过服务文件：

```bash
/etc/systemd/system/backend-demo.service
```

内容：

```ini
[Unit]
Description=Backend Demo Python HTTP Server
After=network.target

[Service]
Type=simple
User=atguigu
WorkingDirectory=/opt/backend-demo
ExecStart=/usr/bin/python -m SimpleHTTPServer 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

已经执行过：

```bash
sudo systemctl daemon-reload
sudo systemctl start backend-demo
sudo systemctl status backend-demo
sudo systemctl enable backend-demo
sudo systemctl stop backend-demo
```

验证过：

```bash
curl http://127.0.0.1:8080
curl http://192.168.6.100
```

成功结果：

```text
Hello from systemd backend 8080
```

学到的结论：

```text
daemon-reload 让 systemd 重新读取服务文件。
start 是现在启动。
enable 是开机自启动。
status 看当前服务状态。
```

## 17. Nginx 反向代理

已经查看/配置过：

```bash
sudo grep -nE "server|listen|server_name|root|index|location|proxy_pass" /etc/nginx/nginx.conf
sudo nginx -t
sudo systemctl reload nginx
curl http://192.168.6.100
```

关键配置：

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
}
```

后来补充过：

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
```

学到的结论：

```text
proxy_pass 把请求转发给后端。
proxy_set_header 把用户原始 Host 和真实 IP 传给后端。
Nginx 配置改完要先 nginx -t，再 reload。
```

## 18. 502 故障演练

已经执行过：

```bash
sudo systemctl stop backend-demo
curl -I http://192.168.6.100
sudo tail -n 10 /var/log/nginx/error.log
sudo systemctl start backend-demo
curl http://192.168.6.100
```

看到过：

```text
HTTP/1.1 502 Bad Gateway
connect() failed (111: Connection refused) while connecting to upstream
```

学到的结论：

```text
502 = Nginx 活着，但后端服务挂了或连不上。
排查顺序：Nginx 状态 -> 后端服务状态 -> 端口 -> error.log。
```

## 19. Nginx location / 日志 / 常见故障

已经学过：

```text
location = /xxx
location ^~ /xxx
location ~ /xxx
location /xxx
root 继承
proxy_set_header Host $host
proxy_set_header X-Real-IP $remote_addr
access.log 字段
GET 和 HEAD 区别
403 / 404 / 502 / 504 排查
proxy_connect_timeout
proxy_read_timeout
proxy_send_timeout
```

学到的结论：

```text
location 决定请求由哪段配置处理。
access.log 看访问结果。
error.log 看失败原因。
403 查权限/SELinux。
404 查路径/文件。
502 查后端挂没挂。
504 查后端是否太慢或超时配置。
```

## 20. 当前下一步

不要重新开始。

当前真实进度：

```text
Linux 基础完成
网络基础第一阶段完成
Shell 第一阶段完成
crontab 第一阶段完成
Nginx 第一阶段完成
MySQL/MariaDB 系统运维已开始
```

## 21. MySQL/MariaDB 安装和服务检查

已经执行过：

```bash
rpm -qa | grep -Ei 'mysql|mariadb'
systemctl status mariadb
ss -lntp | grep :3306
sudo yum install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl status mariadb
ss -lntp | grep :3306
sudo ss -lntp | grep :3306
sudo systemctl enable mariadb
mysql -uroot -e "SELECT VERSION();"
```

看到过：

```text
安装前只有 mariadb-libs，没有 mariadb.service，3306 没有监听。
安装后 mariadb.service Active: active (running)。
3306 由 mysqld 进程监听。
版本是 5.5.68-MariaDB。
```

学到的结论：

```text
mariadb-libs 只是依赖库，不等于数据库服务端。
mariadb-server 才提供数据库服务。
服务名是 mariadb，进程名常见是 mysqld，客户端命令是 mysql。
active 表示现在运行，enabled 表示开机自启动。
```

## 22. MySQL/MariaDB 数据目录、配置和日志

已经执行过：

```bash
sudo systemctl is-enabled mariadb
sudo systemctl is-active mariadb
mysql -uroot -e "SHOW DATABASES;"
mysql -uroot -e "SHOW VARIABLES LIKE 'datadir';"
sudo ls -ld /var/lib/mysql
sudo ls -l /var/lib/mysql
rpm -qc mariadb-server
sudo grep -RniE "datadir|socket|port|bind-address" /etc/my.cnf /etc/my.cnf.d
sudo ls -l /var/log/mariadb/
sudo tail -n 30 /var/log/mariadb/mariadb.log
```

看到过：

```text
enabled
active
默认库：information_schema、mysql、performance_schema、test
datadir=/var/lib/mysql/
/var/lib/mysql 属主属组是 mysql mysql
/etc/my.cnf 里有 datadir=/var/lib/mysql 和 socket=/var/lib/mysql/mysql.sock
日志里有 ready for connections、port: 3306、Server socket created on IP: '0.0.0.0'
```

学到的结论：

```text
/var/lib/mysql 是数据库真实数据目录，不要手动乱删。
/var/log/mariadb/mariadb.log 是 MariaDB 日志。
daemon 是后台守护进程，前面 nginx/crond/systemd 服务也都和这个概念有关。
```

## 23. MySQL 用户、Host 和基础 SQL

已经执行过：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
sudo firewall-cmd --list-all
mysql -uroot -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -h127.0.0.1 -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -e "CREATE DATABASE ops_demo;"
mysql -uroot -e "SHOW DATABASES;"
mysql -uroot -e "CREATE TABLE servers(id INT PRIMARY KEY AUTO_INCREMENT,hostname VARCHAR(50),ip VARCHAR(50), role VARCHAR(50));"
mysql -uroot ops_demo -e "CREATE TABLE servers(id INT PRIMARY KEY AUTO_INCREMENT,hostname VARCHAR(50),ip VARCHAR(50), role VARCHAR(50));"
mysql -uroot ops_demo -e "SHOW TABLES;"
mysql -uroot ops_demo -e "INSERT INTO servers(hostname,ip,role) VALUES ('centos100','192.168.6.100','nginx-mysql-backend');"
mysql -uroot ops_demo -e "SELECT * FROM servers;"
mysql -uroot ops_demo -e "SELECT hostname,ip FROM servers;"
mysql -uroot ops_demo -e "SELECT * FROM servers WHERE ip='192.168.6.100';"
mysql -uroot ops_demo -e "UPDATE servers SET role='all-in-one' WHERE hostname='centos100';"
mysql -uroot ops_demo -e "INSERT INTO servers (hostname, ip, role) VALUES ('test-host', '192.168.6.200', 'test');"
mysql -uroot ops_demo -e "DELETE FROM servers WHERE hostname='test-host';"
mysql -uroot ops_demo -e "SELECT * FROM servers;"
```

遇到过：

```text
ERROR 1046 (3D000) at line 1: No database selected
```

原因和修复：

```text
创建表之前没有选择数据库。
修复方式是在 mysql 命令里加上 ops_demo：mysql -uroot ops_demo -e "CREATE TABLE ..."
```

最终数据：

```text
ops_demo 数据库存在。
servers 表存在。
最终保留一行：
id=1, hostname=centos100, ip=192.168.6.100, role=all-in-one
```

学到的结论：

```text
MySQL 账号要看 User + Host。
远程访问不只看 3306 端口，还要看 firewalld 和 MySQL 用户 Host 权限。
USER() 是请求登录身份，CURRENT_USER() 是最终匹配到的权限身份。
基础 SQL 用于运维检查数据库、表、数据、权限和备份恢复结果。
UPDATE 和 DELETE 必须小心 WHERE，避免修改或删除整张表。
```

## 24. 当前下一步

下一步：

```text
MySQL/MariaDB 备份恢复
```

MySQL 模块必须串联前面内容：

```text
systemctl 管理数据库服务
ss 查看 3306 端口
firewalld 判断能否远程访问
Shell 写备份脚本
crontab 定时备份
日志排查数据库故障
```

建议下一条命令：

```bash
which mysqldump
mysqldump --version
```

## 25. MySQL/MariaDB 备份恢复

已经执行过：

```bash
which mysqldump
mysqldump --version
mkdir -p ~/mysql_backup
mysqldump -uroot ops_demo > ~/mysql_backup/ops_demo.sql
ls -lh ~/mysql_backup/ops_demo.sql
head -n 30 ~/mysql_backup/ops_demo.sql
grep -n "INSERT INTO" ~/mysql_backup/ops_demo.sql
mysql -uroot -e "CREATE DATABASE ops_demo_restore;"
mysql -uroot ops_demo_restore < ~/mysql_backup/ops_demo.sql
mysql -uroot ops_demo_restore -e "SELECT * FROM servers;"
mysql -uroot -e "SHOW DATABASES LIKE 'ops_demo%';"
mysql -uroot ops_demo_restore -e "SELECT COUNT(*) FROM servers;"
mysql -uroot ops_demo_restore -e "DELETE FROM servers;"
mysql -uroot ops_demo_restore -e "SELECT COUNT(*) FROM servers;"
mysql -uroot ops_demo_restore < ~/mysql_backup/ops_demo.sql
mysql -uroot ops_demo_restore -e "SELECT * FROM servers;"
```

看到过：

```text
mysqldump 路径：/usr/bin/mysqldump
备份文件：/home/atguigu/mysql_backup/ops_demo.sql，大小约 2.0K
备份文件里有 DROP TABLE、CREATE TABLE、INSERT INTO。
ops_demo_restore 恢复后 servers 表有 1 行数据。
DELETE FROM servers 后 COUNT(*) 变成 0。
再次导入备份后数据恢复成功。
```

学到的结论：

```text
mysqldump -uroot ops_demo > 文件：备份。
mysql -uroot 库名 < 文件：恢复。
恢复后要查库、查表、查行数、查关键数据。
备份不是目的，能恢复并验证才算真正备份成功。
DELETE 不写 WHERE 会删除整张表数据。
```

## 26. 带时间戳备份和变量

已经执行过：

```bash
DATE=$(date '+%Y%m%d_%H%M%S')
echo $DATE
mysqldump -uroot ops_demo > ~/mysql_backup/ops_demo_${DATE}.sql
ls -lh ~/mysql_backup/
BACKUP_FILE=~/mysql_backup/ops_demo_${DATE}.sql
echo $BACKUP_FILE
DB_NAME="ops_demo"
BACKUP_DIR="$HOME/mysql_backup"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql"
echo $DB_NAME
echo $BACKUP_DIR
echo $BACKUP_FILE
DATE=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql"
mysqldump -uroot "$DB_NAME" > "$BACKUP_FILE"
ls -lh "$BACKUP_FILE"
ls -lh "$BACKUP_DIR"
```

遇到过：

```bash
ls -lh "BACKUP_FILE"
```

报错：

```text
ls: 无法访问BACKUP_FILE: 没有那个文件或目录
```

原因：

```text
"BACKUP_FILE" 是普通字符串。
"$BACKUP_FILE" 才是取变量值。
```

学到的结论：

```text
$变量名 是取变量值。
${变量名} 更适合和其他字符拼接。
DATE 变量赋值后不会自动变化，需要重新执行 date 才会更新时间。
```

## 27. MySQL 备份脚本和日志

创建过：

```bash
~/backup_ops_demo.sh
```

已经执行过：

```bash
vim ~/backup_ops_demo.sh
bash -n ~/backup_ops_demo.sh
bash ~/backup_ops_demo.sh
echo $?
cat ~/backup_ops_demo.sh
tail -n 5 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup/
```

脚本功能：

```text
定义 DB_NAME、BACKUP_DIR、DATE、BACKUP_FILE。
创建备份目录。
执行 mysqldump。
用 STATUS=$? 保存 mysqldump 结果。
成功时输出和记录 backup finished。
失败时输出和记录 backup failed。
写入日志 /home/atguigu/mysql_backup/backup.log。
```

看到过：

```text
backup finished: /home/atguigu/mysql_backup/ops_demo_20260709_192928.sql
[2026-07-09 19:29:28] start backup: db=ops_demo file=/home/atguigu/mysql_backup/ops_demo_20260709_192928.sql
[2026-07-09 19:29:28] backup finished: /home/atguigu/mysql_backup/ops_demo_20260709_192928.sql
```

学到的结论：

```text
bash -n 没输出，说明脚本语法基本没问题。
bash 脚本名 会真正执行脚本。
$? 只表示紧挨着它前面那条命令的退出状态。
STATUS=$? 要紧跟 mysqldump，避免状态被后面的 echo/log 覆盖。
脚本放入 crontab 前，最好先让脚本自己写日志。
```

## 28. crontab 定时备份验证

已经执行过：

```bash
which bash
which mysqldump
crontab -l
crontab -e
crontab -l
tail -n 10 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup/
```

看到过：

```text
/usr/bin/bash
/usr/bin/mysqldump
no crontab for atguigu
* * * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

验证结果：

```text
backup.log 出现 19:41:01 和 19:42:01 的自动备份记录。
mysql_backup 目录出现 ops_demo_20260709_194101.sql 和 ops_demo_20260709_194201.sql。
说明普通用户 atguigu 的 crontab 每分钟自动执行脚本成功。
```

学到的结论：

```text
crontab 环境更简陋，建议写绝对路径。
crontab 里不要依赖 ~，推荐写 /home/atguigu。
谁的 crontab 执行，脚本就以谁的身份运行。
定时任务是否成功，要同时看日志和结果文件。
```

最终已确认：

```bash
crontab -l
```

已经从测试用的每分钟：

```cron
* * * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

改成每天凌晨 3 点：

```cron
0 3 * * * /usr/bin/bash /home/atguigu/backup_ops_demo.sh
```

学到的结论：

```text
每分钟是测试频率，测试成功后要改成合理的正式频率。
当前普通用户 atguigu 的 MySQL 备份任务已设置为每天凌晨 3 点执行。
```

## 29. MySQL 备份保留策略

已经执行过：

```bash
du -sh ~/mysql_backup
find ~/mysql_backup -name "*.sql" -mtime +7
find ~/mysql_backup -name "*.sql" -mtime -1
vim ~/backup_ops_demo.sh
bash -n ~/backup_ops_demo.sh
bash ~/backup_ops_demo.sh
tail -n 5 ~/mysql_backup/backup.log
ls -lh ~/mysql_backup | tail
```

看到过：

```text
60K    /home/atguigu/mysql_backup

find ~/mysql_backup -name "*.sql" -mtime +7
  -> 没有输出，说明当前没有超过 7 天的 .sql 旧备份。

[2026-07-09 20:29:12] start backup: db=ops_demo file=/home/atguigu/mysql_backup/ops_demo_20260709_202912.sql
[2026-07-09 20:29:12] backup finished: /home/atguigu/mysql_backup/ops_demo_20260709_202912.sql
[2026-07-09 20:29:12] old backups cleaned: keep last 7 days

ops_demo_20260709_202912.sql 存在。
```

脚本中新增的清理逻辑：

```bash
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql" -mtime +7 -delete
log "old backups cleaned: keep last 7 days"
```

学到的结论：

```text
du -sh 查看目录总占用。
find ... -mtime +7 查找超过 7 天的文件。
find ... -mtime -1 查找 1 天以内的文件。
find ... -delete 会真实删除匹配文件，执行前要先预览。
脚本里只匹配 ${DB_NAME}_*.sql，比直接删除所有 *.sql 更安全。
清理旧备份应放在备份成功之后，避免旧备份删了、新备份失败。
当前 MySQL 备份脚本已经完成：备份、日志、crontab、7 天保留策略。
```

## 30. 当前下一步

下一步：

```text
MySQL 用户权限和安全加固。
```

建议从这些命令开始：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
mysql -uroot -e "SHOW GRANTS FOR 'root'@'localhost';"
```

## 31. MySQL 用户权限和安全加固

已经执行过：

```bash
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
mysql -uroot -e "SHOW GRANTS FOR 'root'@'localhost';"
mysql -e "SELECT USER(),CURRENT_USER();"
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='';"
mysql -uroot -e "SHOW GRANTS FOR ''@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR ''@'centos100';"
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='';"
mysql -uroot -e "SELECT User,Host FROM mysql.user WHERE User='ops_user';"
mysql -uroot -e "SELECT User,Host FROM mysql.user;"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
mysql -uops_user -p -e "SHOW DATABASES;"
mysql -uroot -e "GRANT SELECT,INSERT,UPDATE,DELETE ON ops_demo.* TO 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

注意：

```text
创建 ops_user 时使用过练习密码，但命令履历不保存明文密码。
SHOW GRANTS 输出过密码哈希，但命令履历不保存哈希。
```

看到过：

```text
root@127.0.0.1
root@::1
root@centos100
root@localhost

匿名用户：
''@centos100
''@localhost

匿名用户权限：
GRANT USAGE ON *.* TO ''@'localhost'
GRANT USAGE ON *.* TO ''@'centos100'

清理后再次查询匿名用户：
没有输出。

ops_user 创建后：
ops_user@localhost

ops_user 初始权限：
USAGE

ops_user 授权前执行 SHOW DATABASES：
information_schema
test

ops_user 授权后：
GRANT SELECT, INSERT, UPDATE, DELETE ON `ops_demo`.* TO 'ops_user'@'localhost'
```

学到的结论：

```text
MySQL 用户要看完整形式：'User'@'Host'。
User 表示谁，Host 表示从哪里来。
127.0.0.1 是 IPv4 本机 TCP。
::1 是 IPv6 本机。
localhost 通常走本地 socket。
centos100 是当前 Linux 主机名。
USAGE 表示账号存在，但没有实际业务库权限。
匿名用户虽然权限很小，但生产环境一般要删除。
业务程序不应该使用 root，而应该创建普通业务用户。
最小权限原则：只给业务需要的库和操作权限。
```

## 32. 当前下一步

下一步：

```text
验证 ops_user 对 ops_demo 的授权是否生效。
```

建议命令：

```bash
mysql -uops_user -p ops_demo -e "SELECT * FROM servers;"
```

## 33. MySQL 业务用户权限验证与 REVOKE

已经执行过：

```bash
mysql -uops_user -p ops_demo -e "SELECT * FROM servers;"
mysql -uops_user -p -e "SELECT User,Host FROM mysql.user;"
mysql -uops_user -p -e "SHOW GRANTS;"
mysql -uroot -e "REVOKE DELETE ON ops_demo.* FROM 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
mysql -uops_user -p ops_demo -e "DELETE FROM servers WHERE hostname='permission-test-not-exist';"
mysql -uroot -e "GRANT DELETE ON ops_demo.* TO 'ops_user'@'localhost';"
mysql -uroot -e "SHOW GRANTS FOR 'ops_user'@'localhost';"
```

看到过：

```text
ops_user 成功查询 servers，读到 centos100 / 192.168.6.100 / all-in-one。
查询 mysql.user 时收到 ERROR 1142 (42000): SELECT command denied。
撤销 DELETE 后，SHOW GRANTS 只剩 SELECT、INSERT、UPDATE。
实际执行 DELETE 测试时收到 ERROR 1142，现有数据未被修改。
重新授予 DELETE 后，最终权限恢复为 SELECT、INSERT、UPDATE、DELETE。
```

学到的结论：

```text
SHOW GRANTS 用于查看权限配置，实际 SQL 用于验证权限是否真正生效。
REVOKE 权限 ON 数据库.* FROM 用户，用于撤销权限。
GRANT 权限 ON 数据库.* TO 用户，用于授予权限。
业务用户应该能访问授权业务库，但不能读取 mysql.user 等系统权限表。
密码和密码哈希不写入命令履历。
```

## 34. 当前下一步

```text
MySQL 常见故障排查小练习，然后完成 MySQL 第一阶段总结。
```

## 35. Windows 本地 Git 仓库初始化

在 Windows PowerShell 中执行过：

```powershell
cd "C:\Users\陈伟钜\Documents\Codex\2026-06-13\new-chat"
git status
git init -b main
git status
git add .
git add .gitattributes
git add --renormalize .
git status
git config user.name "陈伟钜"
git config user.email "cwj@localhost"
git config --local --list
git commit -m "初始化运维学习项目"
git status
```

看到过：

```text
初始化前：fatal: not a git repository。
初始化后：Initialized empty Git repository。
当前分支：main。
当前状态：No commits yet，项目文件均为 Untracked files。
```

学到的结论：

```text
.git 目录存在后，当前文件夹才成为 Git 仓库。
Untracked 表示文件存在，但 Git 还没有开始跟踪。
git init 只初始化仓库，不会自动提交文件。
git add . 把项目文件加入暂存区，但还没有创建正式版本。
.gitattributes 用于统一跨平台文本换行格式，Linux 配置和 Shell 脚本使用 LF。
git add --renormalize . 按照换行规则重新规范暂存区文件。
当前 13 个项目文件已经进入 Changes to be committed，下一步创建第一次提交。
当前仓库已设置本地作者身份 `陈伟钜 <cwj@localhost>`，不使用 `--global`，不会影响其他仓库。
第一次提交成功：`35ec417 初始化运维学习项目`。
第一次提交包含 13 个文件，共记录 8521 行新增内容。
提交后 `git status` 显示 `nothing to commit, working tree clean`。
```

## 2026-09-05 Linux 运维强化基础检查

- 进程与信号：实际使用 `pgrep -a mysqld`、`ps -p 1299,1574 -o pid,ppid,user,stat,cmd`、`ps --forest`、`pstree -p 1`，确认 `mysqld_safe(1299) -> mysqld(1574)` 的父子关系；用 `sleep 300 &`、`kill -STOP`、`kill -CONT`、`kill -TERM` 和 `wait` 验证 `T -> S -> 结束`，退出码为 `143 = 128 + SIGTERM(15)`。
- 资源检查：`nproc` 为 4；`uptime` 负载为 `0.00, 0.01, 0.05`；`vmstat 1 5` 显示 `id=100%`、`si/so=0`、`wa=0`；根分区容量使用约 33%，inode 使用约 2%。
- 磁盘定位：`du` 显示 `/usr` 约 3.9G、`/var` 约 1.4G；`/var/cache/yum` 约 1.3G，其中 `updates` 约 968M；未执行 `yum clean all`。
- 文件元数据：`stat /etc/nginx/nginx.conf` 验证大小 2461 字节、权限 0644、root:root、inode 17757760、SELinux 类型 `httpd_config_t`；`stat -f` 验证根文件系统为 XFS、块大小 4096。
- SSH 与防火墙：`sshd` 为 active/enabled，监听 `0.0.0.0:22` 和 `[::]:22`；生效配置允许 root 密码登录、密码认证和公钥认证。firewalld 运行中，`ens33` 使用 `public`，`ssh` 和 `http` 已放行。
- SELinux：状态为 `Enforcing`、策略为 `targeted`；网站目录类型为 `httpd_sys_content_t`，`httpd_can_network_connect` 为 `on`；`ausearch -m AVC -ts recent` 返回 `<no matches>`。
- 阶段结论：Linux 运维强化基础检查完成。SSH 密钥加固、复杂 firewalld 规则和深度 SELinux 策略尚未实操，后续再作为安全专项处理。

## 2026-09-07 Linux 巡检脚本首版验证

执行过：

```bash
sudo bash /opt/scripts/system_inspection.sh
echo $?
```

看到过：

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
echo $? = 0
```

结论：

```text
Linux 巡检脚本首版已跑通。
服务、HTTP、内存、根分区容量和 inode 检查均正常。
退出码 0 表示本次巡检没有 WARN 和 FAIL。
```

## 2026-09-08 HTTP 状态码复习问答

复习范围：

```text
1xx 信息响应
2xx 成功响应
3xx 重定向和缓存
4xx 客户端错误
5xx 服务器错误
```

答题结果：

```text
401：未认证；403：已识别但没有权限。
400：请求格式或参数错误；404：资源不存在。
500：服务器内部程序错误；503：服务暂时不可用。
502：代理无法取得有效后端响应；504：等待后端响应超时。
301：永久重定向；302：临时重定向；304：使用缓存；429：请求过于频繁。
综合题 403/404/502/504 -> B-C-D-A，全部正确。
```
