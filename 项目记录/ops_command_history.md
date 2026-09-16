# 运维学习命令履历

归档位置：`项目记录/ops_command_history.md`。

用途：让新线程或其他模型快速知道我已经实际敲过哪些命令、验证过哪些结果、排过哪些故障。

最后更新：2026-09-14

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

## 2026-09-08 Git 分支基础复习

执行并验证：

```powershell
git branch
git switch -c git-practice
git branch --show-current
Add-Content -Path .\README.md -Value "`nGit 分支练习记录。"
git add README.md
git commit -m "练习Git分支提交"
git switch main
git merge git-practice
git branch --merged
git branch -d git-practice
git branch
```

关键结果：

```text
git-practice 提交为 da254fb。
git merge git-practice 返回 Fast-forward。
合并后 main 和 git-practice 曾共同指向 da254fb。
删除已合并分支后当前仅保留 main。
```

## 2026-09-08 Git 合并冲突演练

执行并验证：

```powershell
git switch -c conflict-a
Set-Content -Path .\git-conflict-demo.txt -Value "部署状态：正常"
git add git-conflict-demo.txt
git commit -m "添加冲突演练文件"
git switch -c conflict-b
Set-Content -Path .\git-conflict-demo.txt -Value "部署状态：异常"
git add git-conflict-demo.txt
git commit -m "在冲突分支修改部署状态"
git switch conflict-a
Set-Content -Path .\git-conflict-demo.txt -Value "部署状态：维护中"
git add git-conflict-demo.txt
git commit -m "在主冲突分支修改部署状态"
git merge conflict-b
Get-Content .\git-conflict-demo.txt
git add git-conflict-demo.txt
git commit -m "完成合并冲突演练"
git switch main
git branch -D conflict-a conflict-b
git branch
git status
```

关键结果：

```text
产生 CONFLICT (content)。
解决后生成合并提交 28b57d6。
最终文件内容为“部署状态：维护中”。
当前仅保留 main，工作区 clean。
```

## 2026-09-09 GitHub 远程仓库推送

执行并验证：

```powershell
git remote add origin https://github.com/cwj1235/linux-ops-learning.git
git remote set-url origin https://github.com/cwj1235/linux-ops-learning.git
git remote -v
git push -u origin main
git branch -vv
```

关键结果：

```text
远程仓库：linux-ops-learning。
推送结果：main -> origin/main。
跟踪状态：main a2071cd [origin/main]。
```

## 2026-09-09 Git clone 与代理验证

执行并验证：

```powershell
Test-NetConnection github.com -Port 443
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
git clone --depth 1 https://github.com/cwj1235/linux-ops-learning.git ..\linux-ops-learning-clone-2
git -C ..\linux-ops-learning-clone-2 status
git -C ..\linux-ops-learning-clone-2 remote -v
```

关键结果：

```text
设置本地代理后 clone 成功。
克隆目录状态为 clean。
origin fetch/push 地址均为 linux-ops-learning 仓库。
```

## 2026-09-09 Git 远程协作同步

第二个克隆目录先产生本地提交，随后完成远程同步：

```powershell
git -C ..\linux-ops-learning-clone-2 commit -m "从第二个克隆目录更新 README"
git -C ..\linux-ops-learning-clone-2 push
git -C ..\linux-ops-learning-clone-2 pull --rebase origin main
git -C ..\linux-ops-learning-clone-2 push
git pull
git status
```

关键结果：

```text
第一次 push 因远程领先被拒绝，提示 fetch first。
rebase 后生成提交 71ead6e，并成功推送。
主项目 git pull 返回 Fast-forward，README 更新成功。
最终主项目与 origin/main 同步，工作区 clean。
```

## 2026-09-09 运维脚本纳入 Git

执行并验证：

```powershell
New-Item -ItemType Directory -Force .\scripts
scp atguigu@192.168.6.100:/opt/scripts/system_inspection.sh .\scripts\system_inspection.sh
Get-Item .\scripts\system_inspection.sh
git status --short
git add .\scripts\system_inspection.sh
git diff --cached --stat
git commit -m "加入 Linux 系统巡检脚本"
git push
git ls-files scripts/system_inspection.sh
git log --oneline -- scripts/system_inspection.sh
```

关键结果：

```text
脚本复制成功，大小约 2580 字节，共 122 行。
提交为 624b2f1，已推送到 origin/main。
git ls-files 和文件专属 git log 验证成功。
```

## 2026-09-09 `.gitignore` 验证与跟踪清理讲解

实际执行：

```powershell
Set-Content -Path .\git-ignore-demo.log -Value "temporary log"
git status --short
git check-ignore -v .\git-ignore-demo.log
Remove-Item .\git-ignore-demo.log
git status
```

关键结果：

```text
临时日志未出现在 git status --short 中。
git check-ignore -v 定位到 .gitignore 第 16 行的 *.log 规则。
测试文件已删除，工作区 clean。
```

概念讲解但未实际执行：

```powershell
git rm --cached 文件名
```

结论：保留本地文件，只取消 Git 跟踪；适用于已被跟踪后才加入 `.gitignore` 的文件。`git rm` 则会删除本地文件并取消跟踪。

## 2026-09-09 运维脚本修改与部署验证

实际执行步骤：

```text
Select-String 定位 inspection started/finished。
用 notepad 修改开始日志。
git diff 查看修改，git diff --check 检查空白，git add 后用 git diff --cached 复核。
提交 d6eb2be 并 git push。
scp 复制到 /home/atguigu/system_inspection.sh。
bash -n 检查语法，sudo cp 部署到 /opt/scripts，sudo bash 执行巡检。
sudo tail 查看末尾日志，sudo grep 验证新的开始日志。
```

关键结果：

```text
bash -n 无输出，语法检查通过。
巡检执行正常：6 个服务 active、两个 HTTP 为 200、memory available=42%、root usage=33%、inode_usage=2%、warned=0、failed=0。
grep 验证新开始日志已写入 system_inspection.log。
```

## 2026-09-10 Python 运维脚本起步

CentOS 上执行并验证：

```bash
python --version
python3 --version
python3 -c 'print("hello from python3")'
vim /home/atguigu/system_info.py
cat /home/atguigu/system_info.py
python /home/atguigu/system_info.py
echo $?
python3 /home/atguigu/system_info.py
chmod +x /home/atguigu/system_info.py
ls -lh /home/atguigu/system_info.py
/home/atguigu/system_info.py
echo $?
```

关键结果：

```text
python = Python 2.7.5。
python3 = Python 3.6.8。
脚本通过 python、python3 和直接执行均成功，退出码为 0。
直接执行依靠 #!/usr/bin/env python3 选择 Python 3。
```

## 2026-09-10 Python subprocess 初次验证

执行：

```bash
python3 -c 'import subprocess; subprocess.run(["hostname"])'
```

结果：

```text
centos100
```

结论：`subprocess.run` 成功执行 `hostname`，命令输出直接显示在终端。

## 2026-09-10 Python subprocess 输出捕获

执行并验证：

```bash
python3 -c 'import subprocess; result=subprocess.run(["hostname"], stdout=subprocess.PIPE, universal_newlines=True); print("output:", result.stdout.strip()); print("returncode:", result.returncode)'
python3 -c 'import subprocess; result=subprocess.run(["hostname"], stdout=subprocess.PIPE, universal_newlines=True); print("output:", result); print("returncode:", result.returncode)'
```

关键结果：

```text
output: centos100
returncode: 0
CompletedProcess(args=['hostname'], returncode=0, stdout='centos100\n')
```

结论：读取 `result.stdout` 可获得命令输出；读取 `result.returncode` 可获得退出码；直接打印 `result` 会显示完整的 `CompletedProcess` 对象。

## 2026-09-10 Python `subprocess.PIPE` 讲解

本次只进行概念讲解，未单独执行新的实验：

```text
stdout=subprocess.PIPE：为标准输出创建管道，Python 可通过 result.stdout 读取输出。
stderr=subprocess.PIPE：为标准错误创建管道，Python 可通过 result.stderr 读取错误。
未设置 PIPE：输出通常直接显示到终端。
PIPE 与 Shell 的 | 不是同一个概念。
```

## 2026-09-10 Python 文本输出与退出码

概念讲解：

```text
universal_newlines=True：将 subprocess 捕获的输出作为 str，而不是 bytes。
当前 Python 3.6.8 使用该参数；较新 Python 可使用 text=True。
```

实际执行：

```bash
python3 -c 'import subprocess; result=subprocess.run(["false"]); print("returncode:", result.returncode)'
python3 -c 'import subprocess; result=subprocess.run(["true"]); print("returncode:", result.returncode)'
```

实际结果：

```text
false -> returncode: 1
true  -> returncode: 0
```

## 2026-09-10 Python system_info 脚本执行

实际执行：

```bash
/home/atguigu/system_info.py
```

实际结果：

```text
hostname: centos100
returncode: 0
```

结论：脚本通过 shebang 使用 Python 3，成功捕获 `hostname` 输出并读取退出码。

## 2026-09-10 Python uptime 检查

执行：

```bash
/home/atguigu/system_info.py
```

结果：

```text
hostname: centos100
returncode: 0
uptime: 13:34:04 up 3:18, 2 users, load average: 0.01, 0.04, 0.05
uptime_returncode: 0
```

结论：Python 成功调用 `uptime`，获取运行时间、登录用户数和 1/5/15 分钟平均负载。

## 2026-09-10 Python subprocess 函数复用验证

执行：

```bash
python3 -m py_compile /home/atguigu/system_info.py
/home/atguigu/system_info.py
echo $?
```

结果：

```text
hostname: centos100
hostname_returncode: 0
uptime: 17:22:15 up 7:07, 2 users, load average: 0.00, 0.01, 0.05
uptime_returncode: 0
0
```

结论：`run_command()` 成功复用命令执行逻辑；语法检查、标准输出读取和退出码输出均正常。

## 2026-09-10 Python stderr 捕获验证

执行：

```bash
python3 -c 'import subprocess; result=subprocess.run(["ls", "/not-exist"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True); print("stdout:", repr(result.stdout)); print("stderr:", repr(result.stderr)); print("returncode:", result.returncode)'
```

结果：

```text
stdout: ''
stderr: 'ls: 无法访问/not-exist: 没有那个文件或目录\n'
returncode: 2
```

结论：命令失败时，正常输出为空字符串，错误信息进入 `stderr`，退出码为非 0；`repr()` 便于观察字符串的真实结构。

## 2026-09-10 Python run_command 正常路径验证

执行：

```bash
python3 -m py_compile /home/atguigu/system_info.py
/home/atguigu/system_info.py
echo $?
```

结果：

```text
hostname: centos100
hostname_returncode: 0
uptime: 19:03:57 up 8:48, 2 users, load average: 0.00, 0.01, 0.05
uptime_returncode: 0
0
```

结论：加入 `stderr=subprocess.PIPE` 后，成功命令不会输出 `stderr`；脚本语法和执行均正常。

## 2026-09-10 Python 失败命令脚本验证

实际执行：

```bash
/home/atguigu/system_info.py
echo $?
```

关键结果：

```text
ls_stderr: ls: 无法访问/not-exist: 没有那个文件或目录
ls_returncode: 2
0
```

结论：`ls_returncode: 2` 是子命令 `ls` 的失败退出码；最后的 `0` 是 Python 脚本自身退出码。当前脚本只打印子命令结果，还没有使用 `sys.exit()` 将失败状态传递给 Shell。

## 2026-09-10 Python 清理临时失败测试

实际删除临时的 `run_command(["ls", "/not-exist"])` 后执行：

```bash
/home/atguigu/system_info.py
echo $?
```

结果：`hostname_returncode: 0`、`uptime_returncode: 0`，脚本退出码为 `0`。结论：脚本已恢复正常路径验证。

## 2026-09-10 Python sys.exit 成功分支验证

实际执行：

```bash
python3 -m py_compile /home/atguigu/system_info.py
/home/atguigu/system_info.py
echo $?
```

结果：语法检查无输出，`hostname_returncode: 0`、`uptime_returncode: 0`，脚本退出码为 `0`。结论：`sys.exit(0)` 成功分支已验证。

## 2026-09-11 Python sys.exit 失败分支验证

实际把脚本中的：

```python
uptime_result = run_command(["uptime"])
```

临时改为：

```python
uptime_result = run_command(["false"])
```

执行结果：

```text
hostname_returncode: 0
false_returncode: 1
echo $? -> 1
```

结论：`false` 失败后，条件判断执行 `sys.exit(1)`，Python 脚本的失败状态已成功传递给 Shell。该临时命令需要恢复为 `uptime`。

## 2026-09-11 Python 恢复正式命令验证

已将：

```python
uptime_result = run_command(["false"])
```

恢复为：

```python
uptime_result = run_command(["uptime"])
```

实际执行语法检查和脚本，`hostname_returncode: 0`、`uptime_returncode: 0`，最后 `echo $?` 为 `0`。结论：失败测试已清理，脚本恢复正常版本。

## 2026-09-11 Python sys.argv 参数实验

实际执行：

```bash
python3 -c 'import sys; print(sys.argv)' hostname uptime
```

实际输出：

```text
['-c', 'hostname', 'uptime']
```

结论：`sys.argv` 保存命令行参数；使用 `-c` 时第 0 项是 `-c`，第 1、2 项分别是 `hostname` 和 `uptime`。

## 2026-09-11 Python 文件参数验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
```

实际输出：

```text
program: /home/atguigu/args_demo.py
argument: ['hostname', 'uptime']
```

结论：实际脚本的 `sys.argv[0]` 是脚本路径，`sys.argv[1:]` 是用户传入的全部参数。

## 2026-09-11 Python for 循环参数验证

修改 `/home/atguigu/args_demo.py` 后执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
```

实际输出：

```text
program: /home/atguigu/args_demo.py
argument: hostname
argument: uptime
```

结论：`for` 循环成功逐个读取 `sys.argv[1:]` 中的参数。

## 2026-09-11 Python 参数执行命令验证

执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
```

实际结果：

```text
hostname output:centos100
hostname returncode:0
uptime output:09:17:30 up 37 min, 2 users, load average: 0.01, 0.02, 0.04
uptime returncode:0
```

结论：`sys.argv` 中的参数已通过 `[argument]` 交给 `subprocess.run()` 实际执行，两个命令均成功。`output:` 和结果之间少空格只是输出格式问题。

## 2026-09-11 Python 参数失败命令验证

执行：

```bash
python3 /home/atguigu/args_demo.py false
```

实际输出：

```text
false output:
false returncode:1
```

结论：参数 `false` 被成功执行并返回 `1`。之后先执行了 `vim`，再执行 `echo $?`，所以 `0` 表示 `vim` 成功，不能作为 Python 脚本退出码。

## 2026-09-11 Python 参数脚本整体退出码验证

连续执行：

```bash
python3 /home/atguigu/args_demo.py false
echo $?
```

实际结果：

```text
false output:
false returncode: 1
0
```

结论：`false` 子命令返回 `1`，但 `args_demo.py` 当前没有 `sys.exit()` 失败逻辑，因此脚本自身仍返回 `0`。

## 2026-09-11 Python 参数脚本失败状态传递

实际执行：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py false
echo $?
```

实际结果：语法检查无输出，`false returncode: 1`，脚本整体退出码为 `1`。结论：`has_failure` 与 `sys.exit(1)` 已成功将失败状态传给 Shell。

## 2026-09-11 Python 多命令结果汇总验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py false uptime
echo $?
```

实际结果：`false returncode: 1`，随后 `uptime returncode: 0`，最终脚本退出码为 `1`。结论：循环会继续执行后续命令，但任意一次失败都会使整体状态保持失败。

## 2026-09-11 Python 全部成功参数验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
```

实际结果：`hostname returncode: 0`、`uptime returncode: 0`，两个命令输出正常。本次尚未执行紧接的 `echo $?`，因此脚本整体成功退出码待补充验证。

补充执行：

```bash
echo $?
```

结果为 `0`。结论：全部命令成功时，`args_demo.py` 整体退出码也为 `0`。

## 2026-09-11 Python argparse help 验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py --help
```

关键输出：

```text
usage: args_demo.py [-h] commands [commands ...]
positional arguments:
  commands    要执行的命令名称
optional arguments:
  -h, --help  show this help message and exit
```

结论：`argparse` 已自动生成用法、参数说明和帮助选项；`--help` 只展示帮助，不执行命令循环。

## 2026-09-11 Python argparse 必填参数验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py
echo $?
```

实际结果：

```text
args_demo.py: error: the following arguments are required: commands
2
```

结论：未提供位置参数时，`argparse` 在执行命令前拒绝输入，退出码为 `2`，表示参数使用错误。

## 2026-09-11 Python argparse 合法参数验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
echo $?
```

结果：`hostname returncode: 0`、`uptime returncode: 0`，最后脚本退出码为 `0`。结论：`argparse` 合法参数路径验证成功。

## 2026-09-11 Python argparse 未知选项验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py --verbose hostname uptime
```

实际结果：

```text
args_demo.py: error: unrecognized arguments: --verbose
```

结论：`--verbose` 尚未通过 `add_argument()` 注册，`argparse` 拒绝未知选项，命令没有进入执行循环。

## 2026-09-12 Python argparse verbose 验证

实际执行：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py --verbose hostname uptime
```

关键结果：

```text
executing: hostname
hostname returncode: 0
executing: uptime
uptime returncode: 0
```

结论：`--verbose` 已注册并生效，只增加命令执行前的过程提示，不改变命令执行结果。

## 2026-09-12 Python argparse 普通模式验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
echo $?
```

实际结果：没有 `executing:` 过程提示，`hostname returncode: 0`、`uptime returncode: 0`，脚本整体退出码为 `0`。结论：不加 `--verbose` 时仍正常执行，只隐藏过程提示。

## 2026-09-12 Python subprocess timeout 验证

实际执行：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py hostname yes
echo $?
```

实际结果：`hostname returncode: 0`，`yes` 超过 3 秒后触发超时，脚本退出码为 `1`。超时提示显示为 `{} timeout after 3 seconds yes`，说明超时逻辑正确但提示字符串使用了逗号打印，后续需改为 `"{} timeout after 3 seconds".format(argument)`。

补充验证：

```text
yes timeout after 3 seconds
1
```

结论：超时提示格式已修正，脚本仍正确返回 `1`。本次修改后的 `py_compile` 需要单独重新执行；`^[[A` 是终端按键控制序列，不是脚本输出。

## 2026-09-12 Python 修改后 timeout 完整验证

实际执行：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py hostname yes
echo $?
```

结果：修改后的语法检查无输出；`hostname returncode: 0`；`yes timeout after 3 seconds`；脚本退出码为 `1`。结论：格式修正、语法检查和超时失败处理均验证成功。

## 2026-09-12 Python timeout 正常路径验证

实际执行：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py hostname uptime
echo $?
```

结果：语法检查无输出，`hostname` 和 `uptime` 均返回 `0`，脚本整体退出码为 `0`。结论：正常命令不会触发 timeout，成功路径验证完成。

## 2026-09-12 Python logging 基础验证

实际执行：

```bash
python3 -c 'import logging; logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s"); logging.info("inspection started"); logging.warning("memory is low"); logging.error("backend check failed")'
```

实际输出：

```text
INFO: inspection started
WARNING: memory is low
ERROR: backend check failed
```

结论：`logging` 级别和格式配置生效，日志当前只输出到终端。

## 2026-09-12 Python logging 文件验证

实际执行：

```bash
python3 -c 'import logging; logging.basicConfig(filename="/home/atguigu/python_demo.log", level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s"); logging.info("inspection started"); logging.error("backend check failed")'
cat /home/atguigu/python_demo.log
```

实际结果：

```text
2026-09-12 11:42:42,205 INFO: inspection started
2026-09-12 11:42:42,205 ERROR: backend check failed
```

结论：日志成功写入 `/home/atguigu/python_demo.log`，时间、级别和消息均正常记录。

## 2026-09-12 Python args_demo logging 集成验证

实际执行：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py hostname uptime
cat /home/atguigu/args_demo.log
```

终端中的两个命令均返回 `0`。日志实际记录：

```text
INFO: command started: hostname
INFO: command succeeded: hostname
INFO: command started: uptime
INFO: command succeeded: uptime
```

结论：`args_demo.py` 已成功把命令开始和成功事件写入日志文件。

## 2026-09-12 Python logging 失败与超时验证

实际执行：

```bash
python3 /home/atguigu/args_demo.py false yes
echo $?
tail -n 10 /home/atguigu/args_demo.log
```

实际结果：`false returncode: 1`，`yes timeout after 3 seconds`，脚本退出码为 `1`。日志中出现：

```text
ERROR: command failed: false returncode=1
ERROR: command timeout: yes
```

结论：失败和超时事件均已正确写入 `ERROR` 日志。

## 2026-09-12 Python 运维脚本阶段总复盘

本次总复盘依据前面各节已经实际执行的命令和输出整理，不新增虚构的执行结果。已完成并验证的范围：

```text
Python 2/3 环境识别与 Python 3 shebang
subprocess.run、stdout、stderr、PIPE、universal_newlines
CompletedProcess、returncode、strip、format 花括号
函数封装、sys.argv、for 循环、argparse
--help、必填参数、未知参数和合法参数
--verbose 普通/详细模式
失败汇总、sys.exit(0/1)、timeout=3
logging 终端输出、文件日志、成功/失败/超时记录
```

阶段结论：`system_info.py` 和 `args_demo.py` 均已在 CentOS 实际运行；成功、失败、混合命令和超时路径均已验证。当前下一步是把脚本复制到 Windows Git 仓库，补充文档后提交并推送；日志文件因 `.gitignore` 的 `*.log` 规则不纳入版本库。

## 2026-09-12 Python 脚本复制到 Git 仓库

Windows PowerShell 实际执行：

```powershell
scp atguigu@192.168.6.100:/home/atguigu/args_demo.py .\scripts\args_demo.py
Get-Item .\scripts\args_demo.py
git status --short
```

结果：文件成功复制到 `scripts/args_demo.py`，大小为 1532 字节；Git 将其显示为未跟踪文件 `?? scripts/args_demo.py`。四份 Python 学习记录仍为已修改但未提交状态。

## 2026-09-12 Python 阶段 Git 提交与推送

实际执行：

```powershell
git add .\scripts\args_demo.py .\学习总结\ops_python_basics.md .\项目记录\memory.md .\项目记录\ops_command_history.md .\项目记录\ops_handoff.md
git diff --cached --check
git diff --cached --stat
git commit -m "完成 Python 运维脚本阶段记录"
git push
git status
```

关键结果：

```text
git diff --cached --check：无输出
[main d573677] 完成 Python 运维脚本阶段记录
5 files changed, 1732 insertions(+)
144be20..d573677 main -> main
Your branch is up to date with 'origin/main'.
nothing to commit, working tree clean
```

结论：Python 阶段脚本和学习记录已成功提交并推送到 GitHub。

## 2026-09-12 Python 归档后记录提交

以下内容于 2026-09-13 从本项目原始会话补登记，不是本次重新执行。

用户实际执行：

```powershell
git add 项目记录/memory.md 项目记录/ops_command_history.md 项目记录/ops_handoff.md
git diff --cached --check
git commit -m "记录 Python 阶段提交结果"
git push
git status
```

结果：格式检查无输出；提交 `22b3b24`，3 个文件新增 42 行；推送显示 `d573677..22b3b24 main -> main`，随后工作区干净并与 `origin/main` 同步。Python 基础阶段已经完整归档，不需要重新完成旧提交。

## 2026-09-12 Redis 安装前检查和安装

来源：会话“继续”中当晚的用户终端输出，2026-09-13 补档。所有状态仅代表当时检查结果。

- 最初误输入 `rpm _qa`，RPM 显示用法，不能用这一次结果判断安装状态。
- 修正为 `rpm -qa | grep -i '^redis'` 后无输出。
- `systemctl status redis --no-pager` 返回 `Unit redis.service could not be found.`。
- `ss -lntp | grep ':6379'` 无输出。
- `yum info redis` 显示 EPEL 提供版本 `3.2.12`、发布号 `2.el7`。

随后实际安装：

```bash
sudo yum install -y redis
```

关键结果：

```text
Transaction test succeeded
redis.x86_64 0:3.2.12-2.el7
jemalloc.x86_64 0:3.6.0-1.el7
完毕！
```

结论：Redis 及依赖已安装成功。安装前的“服务不存在”不是最新状态。

## 2026-09-12 Redis 启动、监听、自启和应用响应

安装后实际执行 `systemctl status redis`，服务已经存在，但为 `disabled`、`inactive (dead)`。服务单元位于 `/usr/lib/systemd/system/redis.service`，还显示 `limit.conf` 的 drop-in；尚未查看其内容。

随后实际执行：

```bash
sudo systemctl start redis
systemctl status redis --no-pager
sudo ss -lntp | grep ':6379'
redis-cli ping
sudo systemctl enable redis
systemctl status redis --no-pager
systemctl is-active redis
```

关键结果：

```text
Active: active (running)
LISTEN ... 127.0.0.1:6379 ... redis-server
PONG
Created symlink ... multi-user.target.wants/redis.service ...
Loaded: loaded (...; enabled; vendor preset: disabled)
active
```

结论：服务启动、回环地址监听、本机客户端响应、开机自启均已验证。`systemctl is-enabled redis` 仅曾被布置，未收到这条命令的输出；自启依据实际 `status` 中的 `enabled` 判断。没有验证重启后的启动或数据恢复。

## 2026-09-12 Redis String 读写删除

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli SET app:status healthy` | `OK` |
| `redis-cli GET app:status` | `"healthy"` |
| `redis-cli DEL app:status` | `(integer) 1` |
| 再次 `redis-cli GET app:status` | `(nil)` |

结论：基本写入、读取、删除及删除后复查完成。

## 2026-09-12 Redis 自动过期

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli SET app:cache "temporary-data" EX 30` | `OK` |
| `redis-cli TTL app:cache` | `(integer) 16` |
| 随后 `redis-cli GET app:cache` | `(nil)` |

结论：设置 30 秒过期、读取剩余秒数及过期后取不到数据均已验证。`TTL` 返回 `-1` / `-2` 的含义只完成讲解，未单独验证。

## 2026-09-12 Redis 计数器和清理

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli SET page:views 0` | `OK` |
| `redis-cli INCR page:views` | `(integer) 1` |
| `redis-cli GET page:views` | `"1"` |
| 后续 `redis-cli INCRBY page:views 5` | `(integer) 7` |
| `redis-cli DECR page:views` | `(integer) 6` |
| `redis-cli GET page:views` | `"6"` |
| `redis-cli DEL page:views` | `(integer) 1` |
| 再次 `redis-cli GET page:views` | `(nil)` |

结论：以实际的 `7 → 6` 为准，不用早先值 `1` 推导出未发生的结果；测试计数器已删除。未贴出的操作不记为已执行。

## 2026-09-12 Redis Hash 与准确停点

最后实际执行（北京时间约 20:53）：

```bash
redis-cli HSET server:centos100 ip 192.168.6.100
redis-cli HSET server:centos100 role all-in-one
redis-cli HGETALL server:centos100
```

两个 `HSET` 均返回 `(integer) 1`，`HGETALL` 实际显示字段 `ip` / `role`，值为 `192.168.6.100` / `all-in-one`。

随后仅讲解并布置 `HGET server:centos100 ip` 和 `HDEL server:centos100 role`，没有收到执行输出。下一次从这两条接续，再用 `HGETALL` 核对字段；不能把预期输出记成已经完成。

## 2026-09-13 历史会话核对补档

- 按项目目录筛选并核对 16 条历史交互会话，包括归档与同一会话的恢复记录；没有使用其他项目记忆。
- 发现本地笔记停在 Python，而 9 月 12 日晚已继续 Redis；已补齐本文件的实际命令、Redis 模块笔记、当前交接和首页。
- 本次未连接虚拟机、未执行 Redis 命令、未修改业务脚本，也未提交或推送 Git。

## 2026-09-13 Redis Hash 单字段读取、删除与拼写纠错

以下根据用户本次回传的 CentOS 终端输出记录，不是助手代为执行：

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli HGET server:centos100 ip` | 返回 IP 字符串 `192.168.6.100` |
| `redis-cli HGET server:centos100 role` | 返回角色字符串 `all-in-one` |
| `redis-cli HGETALL server:centos100` | 显示 `ip=192.168.6.100`、`role=all-in-one` 两个字段与值 |
| `redis-cli HDET server:centos100 role` | `(error) ERR unknown command 'HDET'` |
| `redis-cli HDEL server:centos100 role` | `(integer) 1` |
| 再次 `redis-cli HGETALL server:centos100` | 仅剩 `ip=192.168.6.100` |

结论：`HGET` 单字段读取成功；`HDET` 是拼写错误，此次调用被拒绝、没有删除字段。改为 `HDEL` 后实际删除了 1 个字段，后续 `HGETALL` 确认 `role` 已删除、`ip` 保留，整个 Hash 键仍存在。Hash 单字段读取和删除已完成验证；本轮没有新的服务状态、监听或持久化测试结果。

## 2026-09-13 Redis 键与字段存在性验证

用户实际执行并回传：

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli EXISTS server:centos100` | `(integer) 1` |
| `redis-cli HEXISTS server:centos100 role` | `(integer) 0` |

结论：整个 `server:centos100` 键仍存在，Hash 中的 `role` 字段不存在，与之前删除 `role` 后的结果一致。这里的 `0` 表示字段不存在，不是命令执行失败；Redis 返回的整数结果与 Shell 的 `$?` 退出码是不同概念。本次没有重新读取 `ip` 值，也没有进行服务配置或持久化测试。

## 2026-09-13 Redis 键类型与 Hash 字段数量验证

用户实际执行并回传：

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli TYPE server:centos100` | `hash` |
| `redis-cli HLEN server:centos100` | `(integer) 1` |

结论：该键的数据类型为 Hash，包含 1 个字段，与此前 `HGETALL` 仅显示 `ip` 的结果一致。`HLEN` 统计字段个数，不是字符串字符数，也不是数据库键总数；本次没有重新读取字段值。类型与字段数量检查已经完成验证。

## 2026-09-13 Redis List 基础小节统一记录

根据用户本小节连续回传的实际输出，在小节完成后统一整理，未由助手代为执行：

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli RPUSH practice:checks nginx mariadb` | `(integer) 2` |
| `redis-cli LRANGE practice:checks 0 -1` | 依次显示 `nginx`、`mariadb` |
| `redis-cli LPOP practice:checks` | 返回字符串 `nginx` |
| `redis-cli LRANGE practice:checks 0 -1` | 仅显示 `mariadb` |
| `redis-cli LLEN practice:checks` | `(integer) 1` |
| `redis-cli LPOP practice:checks` | 返回字符串 `mariadb` |
| `redis-cli LLEN practice:checks` | `(integer) 0` |
| `redis-cli EXISTS practice:checks` | `(integer) 0` |

结论：右端追加、范围查看、左端取出并删除、元素数量及取空后键不存在均已验证。先加入的 `nginx` 先被取出，完成 FIFO 演示；最后一个元素 `mariadb` 被取出后，列表键自动消失，没有额外执行 `DEL`。这些操作只修改练习列表，不实际执行服务巡检；本小节没有重复追加、阻塞消费或真实任务执行的验证结果。

## 2026-09-13 Redis Set 基础小节统一记录

以下依据用户在小节中回传的实际输出统一整理，未由助手代为执行：

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli SADD practice:services nginx mariadb nginx` | `(integer) 2` |
| `redis-cli SMEMBERS practice:services` | 显示 `mariadb`、`nginx`，重复名称只保留一份 |
| `redis-cli SCARD practice:services` | `(integer) 2` |
| `redis-cli SISMEMBER practice:services nginx` | `(integer) 1` |
| `redis-cli SISMEMBER practice:services redis` | `(integer) 0` |
| `redis-cli SREM practice:services nginx` | `(integer) 1` |
| `redis-cli SISMEMBER practice:services nginx` | `(integer) 0` |
| `redis-cli SMEMBERS practice:services` | 仅显示 `mariadb` |
| `redis-cli SREM practice:services mariadb` | `(integer) 1` |
| `redis-cli SMEMBERS practice:services` | `(empty list or set)` |
| `redis-cli EXISTS practice:services` | `(integer) 0` |

结论：Set 的添加、去重、查看、成员总数、存在性判断、按值删除及删除最后成员后的键消失均已验证。取空后用户实际回传的是 `SMEMBERS` 的空结果与 `EXISTS=0`，没有取空后的 `SCARD` 输出，不补记 `SCARD=0`。这里仅操作服务名称数据，没有启动、停止或巡检真实服务，也没有额外执行 `DEL`。

## 2026-09-13 Redis ZSet 基础小节统一记录

以下依据用户在本小节连续回传的实际输出统一整理，未由助手代为执行；范围查询结果按“成员 / 分数”简写，保留实际顺序：

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `redis-cli ZADD practice:priority 20 nginx 10 mariadb 30 redis` | `(integer) 3` |
| `redis-cli ZRANGE practice:priority 0 -1 WITHSCORES` | `mariadb / 10`、`nginx / 20`、`redis / 30` |
| `redis-cli ZADD practice:priority 5 nginx` | `(integer) 0` |
| `redis-cli ZSCORE practice:priority nginx` | `"5"` |
| `redis-cli ZRANGE practice:priority 0 -1 WITHSCORES` | `nginx / 5`、`mariadb / 10`、`redis / 30` |
| `redis-cli ZCARD practice:priority` | `(integer) 3` |
| `redis-cli ZREVRANGE practice:priority 0 -1 WITHSCORES` | `redis / 30`、`mariadb / 10`、`nginx / 5` |
| `redis-cli ZREM practice:priority nginx mariadb redis` | `(integer) 3` |
| `redis-cli ZCARD practice:priority` | `(integer) 0` |
| `redis-cli EXISTS practice:priority` | `(integer) 0` |

结论：新增成员、更新分数、升序/降序读取、查询单个分数与成员数、多成员删除及删空后键消失均已验证。更新已有的 `nginx` 时，`ZADD=0` 表示没有新增成员，`ZSCORE="5"` 和新的排序确认更新成功；`ZCARD` 仍为 `3`。最后 `ZREM=3` 表示删除三个成员，随后 `ZCARD=0`、`EXISTS=0` 确认无剩余成员且练习键已自动消失，无需再次清理。这里只操作名称和分数，没有修改真实服务优先级或执行 `DEL`；Redis 配置、日志与持久化仍未实操。

## 2026-09-13 Redis 配置、日志与本机监听小节统一记录

以下依据用户本小节回传的实际结果整理，助手未连接虚拟机代为执行。命令按标准写法列出；同一段配置和日志的重复粘贴只归档一次，不据此推断重新执行过，也不把消息复制转义当成新故障。

| 用户回传的命令（按首次出现顺序） | 实际结果 |
|---|---|
| `systemctl cat redis --no-pager` | 显示 `/usr/lib/systemd/system/redis.service` 和 `/etc/systemd/system/redis.service.d/limit.conf`；`ExecStart=/usr/bin/redis-server /etc/redis.conf --supervised systemd` |
| `redis-cli INFO server \| grep '^config_file:'` | `config_file:/etc/redis.conf` |
| `redis-cli CONFIG GET bind` | `bind` / `127.0.0.1` |
| `redis-cli CONFIG GET port` | `port` / `6379` |
| `redis-cli CONFIG GET logfile` | `logfile` / `/var/log/redis/redis.log` |
| `sudo grep -nE '^[[:space:]]*(bind\|port\|logfile)[[:space:]]' /etc/redis.conf` | `61:bind 127.0.0.1`、`84:port 6379`、`163:logfile /var/log/redis/redis.log` |
| `sudo tail -n 20 /var/log/redis/redis.log` | 四轮 RDB 后台保存记录，均包含 `DB saved on disk` 与 `Background saving terminated with success` |
| `redis-cli CONFIG GET protected-mode` | `protected-mode` / `yes` |
| `sudo ss -lntp \| grep ':6379'` | `LISTEN`，本地地址 `127.0.0.1:6379`，对端列 `*:*`，进程 `redis-server`，`pid=1207`，`fd=4`，队列列为 `0` / `128` |

- 运行中的配置文件路径与服务启动命令一致；本次核对的三个配置项在运行值和磁盘文件中一致。服务单元还声明 `Type=notify`、`User=redis`、`Group=redis` 和 `LimitNOFILE=10240`，没有另查进程实际身份或资源限制。
- 日志四轮时间分别为 9 月 13 日 `13:32:16`、`13:57:37`、`14:12:38`、`14:27:39`；后台子进程号依次为 `5485`、`5735`、`5934`、`6082`，写时复制内存报告依次为 `4 MB`、`4 MB`、`2 MB`、`2 MB`。每轮由 `1 changes in 900 seconds. Saving...` 开始并成功结束；这些是日志记录，不是新做了四次手动保存实验。
- 读取配置时 sudo 认证曾两次未通过，随后成功；这是认证重试现象，不是 Redis 报错，未修改密码或 sudo 配置，不记录任何凭据。
- 最新 `ss` 已重新验证本机回环监听；对端列 `*:*` 不等于监听所有网卡，`0/128` 不是客户端数，`fd=4` 不是四个连接。保护模式已开启，但不能代替绑定限制、认证与防火墙。
- 本节没有修改配置、重启服务、开放端口或重新检查 systemd active/enabled、`PING`。只观察到 RDB 保存成功，完整保存规则、快照目录与文件名、AOF 状态、文件检查及重启恢复仍未验证；下一小节再继续。

## 2026-09-13 Redis RDB 规则、文件与手动保存阶段记录

用户明确要求记录到目前为止的学习，本次在 RDB 小节中途归档，不表示备份或恢复完成。以下按回传顺序整理；中断后再次贴出的相同 SET/GET/BGSAVE/INFO 输出只作为一次证据归档，不推断重复执行次数。助手未连接虚拟机执行操作。

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli CONFIG GET save` | `save` / `900 1 300 10 60 10000` |
| `redis-cli CONFIG GET dir` | `dir` / `/var/lib/redis` |
| `redis-cli CONFIG GET dbfilename` | `dbfilename` / `dump.rdb` |
| `sudo ls -lh /var/lib/redis/dump.rdb` | 文件存在，权限 `-rw-r--r--.`，属主/属组 `redis/redis`，大小 `131` 字节，修改时间 `9月 13 14:27`；发生在下列手动保存之前 |
| `redis-cli SET practice:rdb-check rdb-ok` | `OK` |
| `redis-cli GRT practice:rdb-check` | `(error) ERR unknown command 'GRT'` |
| `redis-cli GET practice:rdb-check` | `"rdb-ok"` |
| `redis-cli BGSAVE` | `Background saving started` |
| `redis-cli INFO persistence` | 返回以下持久化状态 |

```text
loading:0
rdb_changes_since_last_save:0
rdb_bgsave_in_progress:0
rdb_last_save_time:1789292105
rdb_last_bgsave_status:ok
rdb_last_bgsave_time_sec:0
rdb_current_bgsave_time_sec:-1
aof_enabled:0
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:-1
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_last_write_status:ok
```

结论：三组自动保存规则已查明，每组内部是时间和变更次数同时满足，三组之间为“或”；快照路径为 `/var/lib/redis/dump.rdb`。`GRT` 拼写错误已改成 GET，保存前读到 `rdb-ok`。结合 BGSAVE 启动回复与随后的 `in_progress=0`、`status=ok`、`changes=0`，手动后台保存已完成且成功；当前 `aof_enabled=0`。文件的 131 字节大小是保存前基线，保存后尚未复查大小/修改时间，也未重启恢复或清理练习键。

### 快照复制备份（2026-09-13 历史会话复核补档）

```bash
sudo cp -anv /var/lib/redis/dump.rdb "/var/lib/redis/dump.rdb.before-restart-$(date +%Y%m%d-%H%M%S)"
```

此前中途归档尚未收到复制结果；本次按项目目录核对历史会话，找到用户于 2026-09-13 20:11（会话北京时间）回传的真实复制输出：

```text
"/var/lib/redis/dump.rdb" -> "/var/lib/redis/dump.rdb.before-restart-20260913-183303"
```

结论：快照复制已完成，目标文件名已明确。文件名中的时间来自 CentOS 的 date，不能用它代替会话回传时间；当时尚未收到文件大小核对或重启后的 GET，后续验证见下一小节。此次只补记历史证据，助手没有执行新的虚拟机命令。

用户随后贴出的是下面的命令文本，而非执行结果；恢复记录中的重复文本不算多次执行，也不证明内容一致：

```bash
sudo cmp -s /var/lib/redis/dump.rdb /var/lib/redis/dump.rdb.before-restart-20260913-183303 && echo "backup identical" || echo "backup differs"
```

当时安排的下一步是核对已复制快照的大小、属性和内容，不重做 cp、SET/BGSAVE。比较需要区分 cmp 的 0（一致）、1（不同）、2（出错），不把权限或路径错误归为内容不同；该核对及后续重启现已完成，实际回传统一归档如下。

cp/scp 的用途、源文件默认保留、参数不能照搬及时间文件名已讲解。真实快照复制已有证据，但早先用于语法演示的示例文件复制与 scp 上传仍未实操，不加入已执行清单。

## 2026-09-14 统一归档：RDB 备份核对、正常重启与加载验证

以下来自用户在本任务中的连续实操回传；重启及启动日志的时间明确为 `2026-09-13 23:45:36 CST`，归档日期不代表重新执行。助手只整理记录，没有连接虚拟机代做操作。

### 1. 重启前的备份文件与内容核对

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `sudo ls -lh /var/lib/redis/dump.rdb /var/lib/redis/dump.rdb.before-restart-20260913-183303` | 两个文件均为 `-rw-r--r--.`、属主/属组 `redis/redis`、158 字节、修改时间 `9月 13 17:35` |
| `sudo cmp /var/lib/redis/dump.rdb /var/lib/redis/dump.rdb.before-restart-20260913-183303` | 没有输出 |
| 紧接着执行 `echo $?` | `0` |

结论：当时源文件与备份逐字节一致，不只是大小相同。`cp -a` 保留源文件修改时间，17:35 不是备份创建时间。158 字节是重启前结果；重启后没有重新查看大小或比较内容，不能当作持续不变的状态。

另外讲解了原先单行命令的两个局限：`&& echo ... || echo ...` 会把内容不同与命令报错混淆；整行执行后再查看 `$?`，通常得到最后一个 echo 的退出码，而不是 cmp 的退出码。再次单独贴出的旧命令不计为新的执行证据。

### 2. 正常重启、服务状态与数据读回

| 用户实际执行（按顺序） | 实际结果 |
|---|---|
| `sudo systemctl restart redis` | 未显示错误，随后继续用服务状态和数据读取验证 |
| `sudo systemctl status redis --no-pager -l` | `active (running)`，启动于 `2026-09-13 23:45:36 CST`；主进程 `3047 (redis-server)`；ExecStop 为 `status=0/SUCCESS`；开机自启为 enabled |
| `redis-cli GET practice:rdb-check` | `"rdb-ok"` |

重启后没有重新执行 SET，因此读到的是原练习值。ExecStop 成功指旧服务的停止命令正常完成；vendor preset 的 disabled 只是默认策略，与当前 enabled 不矛盾。重启的是 Redis 服务，不是 CentOS；没有回传重启后重新运行 ss 或 PING 的结果。

### 3. 重启后持久化状态和启动日志

用户实际执行：

```bash
redis-cli INFO persistence
sudo tail -n 20 /var/log/redis/redis.log
```

INFO 中的关键原始字段：

```text
loading:0
rdb_changes_since_last_save:0
rdb_bgsave_in_progress:0
rdb_last_save_time:1789314336
rdb_last_bgsave_status:ok
rdb_last_bgsave_time_sec:-1
rdb_current_bgsave_time_sec:-1
aof_enabled:0
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:-1
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_last_write_status:ok
```

当前无加载或后台保存任务，AOF 未启用。新进程的 RDB 上次耗时为 -1 不表示失败；不能只凭 status=ok 或 last_save_time 更新声称新进程做过 BGSAVE。AOF 的 ok 状态也不证明执行过 AOF 实验。

本次启动关键日志：

```text
3047:M 13 Sep 23:45:36.212 # Server started, Redis version 3.2.12
3047:M 13 Sep 23:45:36.212 * DB loaded from disk: 0.000 seconds
3047:M 13 Sep 23:45:36.212 * The server is now ready to accept connections on port 6379
```

三条 WARNING 同时提示：Redis 请求 backlog=511，而内核 somaxconn=128；overcommit_memory=0；THP 开启。分别涉及连接排队容量、低内存时后台保存的 fork 风险、延迟及内存开销，不是这次启动或加载失败。这里只读取日志，尚未直接读取相应内核文件、修改参数或配置开机持久化。

### 4. 本段完成范围与下一步

结合 AOF 关闭、磁盘加载日志和重启后的 GET，确认 RDB 正常启动加载与练习值读回通过。正常停止可能再次保存 RDB；没有将备份复制回正式位置，不能声称指定备份回灌、断电恢复或全部键完整性已验证。备份和练习键仍保留。

本次按小节统一归档，不再逐条命令改文件。下一步学习 AOF 概念并只读查询 appendonly、appendfilename、appendfsync，尚无这三项 CONFIG GET 的执行输出；之后再安排启用、恢复和内存/性能警告核验。没有启用 AOF、改内核参数、清理数据、提交或推送 Git。

## 2026-09-14 Redis AOF 在线启用与重启恢复验证

本小节在 RDB 基础验证之后完成。用户先只读查询 AOF 配置，再在线启用、解决配置持久化权限问题，最后通过重启后的数据读取和启动日志确认 AOF 加载。

### 1. 配置查询与启用前检查

```bash
redis-cli CONFIG GET appendonly
redis-cli CONFIG GET appendfilename
redis-cli CONFIG GET appendfsync
sudo grep -n 'appendfilename' /etc/redis.conf
sudo ls -lh /var/lib/redis/appendonly.aof
df -h /var/lib/redis
```

关键结果：

```text
appendonly = no
appendfilename CONFIG GET 返回 (empty list or set)
appendfsync = everysec
/etc/redis.conf 第 597 行：appendfilename "appendonly.aof"
/var/lib/redis/appendonly.aof：文件不存在
根分区：17G 总容量，5.8G 已用，12G 可用，34% 使用率
```

配置文件备份：

```bash
sudo cp -anv /etc/redis.conf "/etc/redis.conf.before-aof-$(date +%Y%m%d-%H%M%S)"
```

实际输出：

```text
"/etc/redis.conf" -> "/etc/redis.conf.before-aof-20260914-094538"
```

### 2. 在线启用与文件生成

```bash
redis-cli CONFIG SET appendonly yes
```

返回 `OK`。随后：

```text
aof_enabled:1
aof_rewrite_in_progress:0
aof_rewrite_scheduled:0
aof_last_rewrite_time_sec:0
aof_current_rewrite_time_sec:-1
aof_last_bgrewrite_status:ok
aof_last_write_status:ok
```

`sudo ls -lh /var/lib/redis/appendonly.aof` 确认文件生成，大小 139 字节，属主 `redis:redis`。

### 3. CONFIG REWRITE 权限失败与手动持久化

```bash
redis-cli CONFIG REWRITE
```

返回：

```text
(error) ERR Rewriting config file: Permission denied
```

进一步核对：

```text
/etc/redis.conf：-rw-r-----. 1 redis root ...
/etc：drwxr-xr-x. ... root root
redis-server：USER=redis，GROUP=redis
```

结论：Redis 用户虽是配置文件属主，但无权在 `/etc` 目录中创建 `CONFIG REWRITE` 需要的临时文件；没有使用 `chmod` 或修改目录属主。管理员手动修改有效配置行：

```bash
sudo sed -i 's/^appendonly no$/appendonly yes/' /etc/redis.conf
sudo grep -nE '^[[:space:]]*appendonly[[:space:]]+' /etc/redis.conf
```

实际确认：

```text
593:appendonly yes
```

### 4. 写入测试与重启恢复

```bash
redis-cli SET practice:aof-check aof-ok
redis-cli INFO persistence | grep -E '^(aof_enabled|aof_last_write_status|aof_rewrite_in_progress|aof_last_bgrewrite_status):'
```

结果：`SET` 返回 `OK`；`aof_enabled:1`、`aof_rewrite_in_progress:0`、`aof_last_bgrewrite_status:ok`、`aof_last_write_status:ok`。

重启后未重新 SET，`redis-cli GET practice:aof-check` 返回 `"aof-ok"`。启动日志显示：

```text
5519:M 14 Sep 11:44:30.922 * DB loaded from append only file: 0.000 seconds
5519:M 14 Sep 11:44:30.922 * The server is now ready to accept connections on port 6379
```

结论：AOF 已在线启用，配置已写入 `/etc/redis.conf`，AOF 文件已生成，写入状态正常，Redis 重启后成功从 AOF 加载练习键。三条启动 WARNING（backlog/somaxconn、`overcommit_memory`、THP）仍待只读核验，未修改内核参数。AOF 练习键 `practice:aof-check` 暂不清理。

## 2026-09-14 Redis 指定 RDB 备份隔离回灌验证

为不影响正式 `6379` 实例和现有 AOF，使用临时目录与端口验证指定的历史 RDB 备份。用户实际执行：

```bash
sudo mkdir /var/lib/redis-rdb-restore-20260914
sudo cp -av /var/lib/redis/dump.rdb.before-restart-20260913-183303 /var/lib/redis-rdb-restore-20260914/dump.rdb
sudo chown redis:redis /var/lib/redis-rdb-restore-20260914 /var/lib/redis-rdb-restore-20260914/dump.rdb
```

第一次 `sudo` 密码输入错误，第二次认证成功；目录创建、文件复制和属主设置均完成。未删除正式 `/var/lib/redis/dump.rdb`，未停止 `redis.service`。

启动隔离实例：

```bash
sudo -u redis redis-server \
  --bind 127.0.0.1 \
  --port 6380 \
  --dir /var/lib/redis-rdb-restore-20260914 \
  --dbfilename dump.rdb \
  --appendonly no \
  --save "" \
  --daemonize yes \
  --pidfile /var/lib/redis-rdb-restore-20260914/redis.pid \
  --logfile /var/lib/redis-rdb-restore-20260914/redis.log \
  --supervised no
```

验证命令及实际结果：

```bash
redis-cli -p 6380 INFO keyspace
```

返回 `db0:keys=2,expires=0,avg_ttl=0`。

```bash
redis-cli -p 6380 KEYS '*'
```

列出：`server:centos100`、`practice:rdb-check`。

```bash
sudo tail -n 10 /var/lib/redis-rdb-restore-20260914/redis.log
```

日志显示 `DB loaded from disk: 0.000 seconds`，随后显示实例已在端口 `6380` 接受连接。结合此前 `redis-check-rdb` 的 `Checksum OK`、`RDB looks OK!`、`2 keys read`，确认指定 RDB 已被 Redis 实际加载，回灌验证完成。

### 具体键值与关闭验证（本任务补充）

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli -p 6380 GET practice:rdb-check` | `"rdb-ok"` |
| `redis-cli -p 6380 HGETALL server:centos100` | 字段 `ip`，值 `192.168.6.100`，只有这一组字段和值 |
| `redis-cli -p 6380 SHUTDOWN NOSAVE` | 无文字输出，返回 Shell 提示符 |
| `redis-cli -p 6380 PING` | `Could not connect to Redis at 127.0.0.1:6380: Connection refused` |
| `redis-cli -p 6379 PING` | `PONG` |

指定备份中这两个练习键的具体内容已读回。结合关闭命令和后续连接被拒绝，确认临时实例已停止；正式实例的 PING 仍正常。后续临时目录核对与清理见下一小节；本节未修改内核参数；原始备份不作为清理目标。启动日志中的 backlog/somaxconn、`overcommit_memory`、THP WARNING 仍待只读核验。

## 2026-09-14 临时 RDB 恢复目录核对与安全清理

| 用户实际执行 | 实际结果 |
|---|---|
| `sudo ls -lah /var/lib/redis-rdb-restore-20260914` | 临时目录内只有 `dump.rdb`（158 字节）和 `redis.log`（2.8K），属主与属组均为 `redis:redis` |
| `sudo ls -lh /var/lib/redis/dump.rdb.before-restart-20260913-183303` | 原始备份存在，158 字节，属主与属组为 `redis:redis` |
| `sudo rm -i -- /var/lib/redis-rdb-restore-20260914/dump.rdb /var/lib/redis-rdb-restore-20260914/redis.log` | 分别询问删除两个普通文件，用户均输入 `y` |
| `sudo rmdir /var/lib/redis-rdb-restore-20260914` | 无报错，返回 Shell 提示符 |
| `sudo ls -ld /var/lib/redis-rdb-restore-20260914` | 提示“没有那个文件或目录” |

临时文件与空目录清理已验证完成，最后 ls 提示不存在是预期检查结果，不是清理失败。删除目标只包含实验副本、实验日志和临时目录；原始备份在清理前已确认存在，正式数据目录和 AOF 不在删除范围。本轮没有再次读取原始备份内容或重新执行正式实例 PING，也没有修改内核参数。

## 2026-09-14 Redis 启动警告对应内核参数只读核验

用户实际执行：

```bash
sysctl net.core.somaxconn vm.overcommit_memory
cat /sys/kernel/mm/transparent_hugepage/enabled
```

实际输出依次为：

```text
net.core.somaxconn = 128
vm.overcommit_memory = 0
[always] madvise never
```

用户只读实测 `net.core.somaxconn=128`、`vm.overcommit_memory=0`，THP 输出 `[always] madvise never`，当前生效选项为 `always`。三项与此前启动警告一致，但不能据此认定当前内存不足或已出现性能故障。 仅查询内核参数和读取状态文件，没有执行赋值、写配置、关闭 THP 或重启服务。后续内存查询与上限修改的实际输出见下一小节。

## 2026-09-14 整机与 Redis 内存基线、128 MiB 运行时上限

用户先实际执行：

```bash
free -m
redis-cli -p 6379 INFO memory
```

| 调整前指标 | 用户实际输出 |
|---|---|
| 系统内存（MiB） | total=1980、used=936、free=247、shared=15、buff/cache=796、available=866 |
| Swap（MiB） | total=2047、used=0、free=2047 |
| Redis used_memory | 812936 字节，793.88K |
| Redis used_memory_rss | 6045696 字节，5.77M |
| Redis used_memory_peak | 812936 字节，793.88K |
| total_system_memory | 2076565504 字节，1.93G，指整机总内存 |
| 调整前 maxmemory / policy | 0 / noeviction |
| mem_fragmentation_ratio / allocator | 7.44 / jemalloc-3.6.0 |

随后实际执行：

```bash
redis-cli -p 6379 CONFIG SET maxmemory 134217728
redis-cli -p 6379 CONFIG GET maxmemory
```

输出依次为：

```text
OK
1) "maxmemory"
2) "134217728"
```

已确认运行时上限为 128 MiB。此次只更改 maxmemory，没有写配置文件、CONFIG REWRITE、服务重启或内核参数修改，也没有超限写入测试。后续磁盘配置核对与写入结果见下一小节；INFO memory 的统计来自修改前，未声称改变上限后 RSS 或碎片率有所下降。

## 2026-09-14 maxmemory 配置文件备份与写入核对

| 用户实际回传的命令 | 实际结果 |
|---|---|
| `sudo grep -n 'maxmemory' /etc/redis.conf` | 第 537 行为 maxmemory 注释示例，第 560 行 maxmemory-policy、第 571 行 maxmemory-samples 也为注释 |
| `sudo cp -av /etc/redis.conf "/etc/redis.conf.before-maxmemory-$(date +%Y%m%d-%H%M%S)"` | `"/etc/redis.conf" -> "/etc/redis.conf.before-maxmemory-20260914-165752"` |
| `sudo grep -n '^maxmemory ' /etc/redis.conf` | `537:maxmemory 134217728` |

配置文件中的 maxmemory 已确认是非注释的 134217728，文件写入结果通过。本任务提供了 sed 修改方法，但用户未单独回传该编辑命令原文，因此不把它另记为已执行命令；以编辑前后 grep 结果记录文件状态变化。本段只记录文件写入，后续服务重启与运行值读回见下一小节。未执行 CONFIG REWRITE、回滚或内核参数调整。

## 2026-09-14 17:10 Redis 128 MiB 上限服务重启验收

| 用户实际执行 | 实际结果 |
|---|---|
| `sudo systemctl restart redis` | 未报错，随后用状态与运行值验证 |
| `sudo systemctl status redis --no-pager -l` | `active (running)`，启动于 `2026-09-14 17:10:21 CST`，Main PID=9261，ExecStop=`0/SUCCESS`，enabled |
| `redis-cli -p 6379 CONFIG GET maxmemory` | 返回 `maxmemory` 和 `134217728` |

重启与查询之间未重新执行 CONFIG SET，结合新进程状态和直接读回结果，确认启动后的 maxmemory 仍为 128 MiB，上限的文件配置与服务重启加载验收通过。状态中的 vendor preset disabled 不推翻当前 enabled；Drop-In 仅显示 `/etc/systemd/system/redis.service.d/limit.conf`，未读取内容或判断它限制什么。

本小节先完成服务状态与上限读回；随后练习键和策略的实际复核见下一小节。仅凭 active 状态和 maxmemory 返回值，不能推断数据完整性、AOF 加载来源或整机重启已经验证；未执行回滚或内核参数调整。

## 2026-09-14 重启后练习键与 noeviction 策略复核

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli -p 6379 MGET practice:rdb-check practice:aof-check` | 依次返回 `"rdb-ok"`、`"aof-ok"` |
| `redis-cli -p 6379 CONFIG GET maxmemory-policy` | 返回 `"maxmemory-policy"` 和 `"noeviction"` |

本轮服务重启后的两个指定字符串键已读回，当前策略重新确认为 noeviction；结合此前 maxmemory=134217728 的读回，上限、数据抽查与策略复核完成。没有新读回 Hash、核对 AOF 加载日志、验证全部键完整性或执行超限写入。新隔离内存实验尚未启动，端口检查也尚无执行回传。

## 2026-09-14 Redis 6381 隔离 noeviction 超限演练与关闭

| 用户实际执行 | 实际结果 |
|---|---|
| `sudo ss -lntp 'sport = :6381'` | 无监听输出，确认拟用端口空闲 |
| `sudo -u redis redis-server --bind 127.0.0.1 --port 6381 --dir /var/lib/redis-noeviction-20260914 --appendonly no --save "" --maxmemory 1048576 --maxmemory-policy noeviction --daemonize yes --pidfile /var/lib/redis-noeviction-20260914/redis.pid --logfile /var/lib/redis-noeviction-20260914/redis.log --supervised no` | 命令返回提示符，实例随后可响应 |
| `redis-cli -p 6381 PING` | `PONG` |
| `redis-cli -p 6381 CONFIG GET maxmemory` | 返回 `maxmemory` 和 `1048576` |
| `redis-cli -p 6381 CONFIG GET maxmemory-policy` | 返回 `maxmemory-policy` 和 `noeviction` |
| `redis-cli -p 6381 CONFIG GET appendonly` | 返回 `appendonly` 和 `no` |

随后用户构造 65536 字节的 value，并循环尝试写入 `practice:noeviction:1` 至 `practice:noeviction:30`：

```bash
value=$(printf 'A%.0s' $(seq 1 65536))
for i in $(seq 1 30); do
  redis-cli -p 6381 SET "practice:noeviction:$i" "$value" || {
    echo "FIRST_FAILED_INDEX=$i"
    break
  }
done
```

前 6 次 `SET` 返回 `OK`，第 7 次开始连续返回 `OOM command not allowed when used memory > 'maxmemory'`。脚本没有输出 `FIRST_FAILED_INDEX`，原因是旧版 Redis 3.2 的 `redis-cli` 收到服务端错误时退出码可能仍为 0，`||` 分支未触发；不能依赖退出码判断业务失败。

| 用户实际执行 | 实际结果 |
|---|---|
| `redis-cli -p 6381 INFO memory \| grep -E '^(used_memory:\|used_memory_human:\|maxmemory:\|maxmemory_human:\|maxmemory_policy:\|mem_fragmentation_ratio:)'` | `used_memory=923152`（901.52K）、`maxmemory=1048576`（1.00M）、策略 `noeviction`、碎片率 `5.71` |
| `redis-cli -p 6381 DBSIZE` | `6` |
| `redis-cli -p 6381 GET practice:noeviction` | `(nil)`；原因是 key 名少了编号，实际 key 为 `practice:noeviction:1` 等 |
| `redis-cli -p 6381 STRLEN practice:noeviction:1` | `65536`，证明已有键仍可读 |
| `redis-cli -p 6381 DEL practice:noeviction:1` | `1` |
| `redis-cli -p 6381 SET practice:noeviction:after-del small` | `OK` |
| `redis-cli -p 6381 GET practice:noeviction:after-del` | `"small"`，证明释放内存后写入恢复 |
| `redis-cli -p 6381 SHUTDOWN NOSAVE` | 无输出；随后 6381 连接拒绝，确认实例关闭 |
| `redis-cli -p 6381 PING` | `Could not connect to Redis at 127.0.0.1:6381: Connection refused` |
| `redis-cli -p 6379 PING` | `PONG`，正式实例仍正常 |

结论：noeviction 在内存不足时拒绝可能增加内存的写入，已有数据仍可读，删除数据释放空间后写入恢复。`used_memory=923152 < maxmemory=1048576` 与第 7 次 OOM 不矛盾，因为 INFO 是事后查询值，不是第 7 次写入瞬间的内存峰值。临时目录 `/var/lib/redis-noeviction-20260914` 已完成只读核验和最终清理。

### 2026-09-15 noeviction 临时目录只读核验与最终清理

| 用户实际执行 | 实际结果 |
|---|---|
| `sudo ls -la /var/lib/redis-noeviction-20260914` | 目录属主 `redis:redis`，仅包含 `redis.log`，无 `.`/`..` 之外的目录项 |
| `sudo find /var/lib/redis-noeviction-20260914 -maxdepth 1 -type f -printf '%f %s bytes\n'` | 仅 `redis.log 2745 bytes` |
| `redis-cli -p 6381 PING` | `Connection refused`，符合临时实例已停止的预期 |
| `sudo rm -i /var/lib/redis-noeviction-20260914/redis.log` | 确认 `y` 后删除成功 |
| `sudo rmdir /var/lib/redis-noeviction-20260914` | 删除空目录成功 |
| `sudo ls -ld /var/lib/redis-noeviction-20260914` | 返回“没有那个文件或目录”，确认目录已不存在 |
| `redis-cli -p 6381 PING` | `Connection refused`，临时实例仍处于关闭状态 |
| `redis-cli -p 6379 PING` | `PONG`，正式实例仍正常 |

结论：无 `dump.rdb` 和 `appendonly.aof`，说明本次 `--save ""` 与 `--appendonly no` 生效；无 `redis.pid` 说明正常退出后 pidfile 已清理；`redis.log` 是唯一遗留实验日志。最终清理后目录已不存在，6381 仍拒绝连接，6379 仍返回 `PONG`。noeviction 小节已完整收尾。

## 2026-09-15 Redis 6381 隔离 allkeys-lru 演练与清理

- `sudo ss -lntp 'sport = :6381'`：无监听，确认 6381 空闲。
- `sudo install -d -o redis -g redis -m 700 /var/lib/redis-allkeys-lru-20260915`：创建 redis 属主的隔离实验目录。
- 使用 `sudo -u redis redis-server` 启动 6381，配置 `127.0.0.1`、`maxmemory=1048576`、`maxmemory-policy=allkeys-lru`、`appendonly no`、`save ""`、daemon 模式和专用日志目录。
- `redis-cli -p 6381 PING` 返回 `PONG`；`CONFIG GET maxmemory`、`CONFIG GET maxmemory-policy`、`CONFIG GET appendonly` 分别确认 `1048576`、`allkeys-lru`、`no`。
- 循环写入 30 个 `practice:allkeys-lru:$i`，每个 value 为 65536 个 `A`，全部返回 `OK`。
- `INFO memory` 显示 `used_memory=923568`、`maxmemory=1048576`、策略 `allkeys-lru`；`INFO stats` 显示 `evicted_keys=24`；`DBSIZE=6`。
- `--scan --pattern 'practice:allkeys-lru:*' | sort -V` 显示保留 `:25` 至 `:30`；`EXISTS` 显示 `:1=0`、`:24=0`、`:25=1`、`:30=1`；`STRLEN :30=65536`。
- `SHUTDOWN NOSAVE` 后 6381 拒绝连接，6379 返回 `PONG`；目录仅剩 `redis.log 2745 bytes`。
- 用户用 `sudo rm -i` 删除日志、`sudo rmdir` 删除空目录，并确认目录不存在。
- 结论：`allkeys-lru` 在内存不足时淘汰旧 key，新写入仍可成功；与 `noeviction` 内存不足时 OOM 拒写形成对比。

### 本节实际命令

```bash
# 1. 检查 6381 是否空闲
sudo ss -lntp 'sport = :6381'

# 2. 创建隔离目录
sudo install -d -o redis -g redis -m 700 /var/lib/redis-allkeys-lru-20260915

# 3. 启动隔离实例
sudo -u redis redis-server \
  --bind 127.0.0.1 \
  --port 6381 \
  --dir /var/lib/redis-allkeys-lru-20260915 \
  --appendonly no \
  --save "" \
  --maxmemory 1048576 \
  --maxmemory-policy allkeys-lru \
  --daemonize yes \
  --pidfile /var/lib/redis-allkeys-lru-20260915/redis.pid \
  --logfile /var/lib/redis-allkeys-lru-20260915/redis.log \
  --supervised no

# 4. 验证连通性和关键配置
redis-cli -p 6381 PING
redis-cli -p 6381 CONFIG GET maxmemory
redis-cli -p 6381 CONFIG GET maxmemory-policy
redis-cli -p 6381 CONFIG GET appendonly

# 5. 生成 65536 字节测试 value
value=$(printf 'A%.0s' $(seq 1 65536))

# 6. 连续写入 30 个大 value，并显示每次结果
for i in $(seq 1 30); do
  result=$(redis-cli -p 6381 SET "practice:allkeys-lru:$i" "$value")
  printf '%02d %s\n' "$i" "$result"
done

# 7. 查看内存、淘汰数量和最终 key 数
redis-cli -p 6381 INFO memory | grep -E '^(used_memory:|used_memory_human:|maxmemory:|maxmemory_human:|maxmemory_policy:)'
redis-cli -p 6381 INFO stats | grep -E '^(evicted_keys:)'
redis-cli -p 6381 DBSIZE

# 8. 查看保留下来的 key
redis-cli -p 6381 --scan --pattern 'practice:allkeys-lru:*' | sort -V

# 9. 验证旧 key 被淘汰、新 key 保留
for i in 1 24 25 30; do
  result=$(redis-cli -p 6381 EXISTS "practice:allkeys-lru:$i")
  printf 'practice:allkeys-lru:%s EXISTS=%s\n' "$i" "$result"
done

# 10. 验证保留 key 的 value 长度
redis-cli -p 6381 STRLEN practice:allkeys-lru:30

# 11. 关闭临时实例并确认状态
redis-cli -p 6381 SHUTDOWN NOSAVE
redis-cli -p 6381 PING
redis-cli -p 6379 PING

# 12. 确认目录内遗留文件
sudo ls -la /var/lib/redis-allkeys-lru-20260915
sudo find /var/lib/redis-allkeys-lru-20260915 -maxdepth 1 -type f -printf '%f %s bytes\n'

# 13. 手动确认后清理
sudo rm -i /var/lib/redis-allkeys-lru-20260915/redis.log
sudo rmdir /var/lib/redis-allkeys-lru-20260915
sudo ls -ld /var/lib/redis-allkeys-lru-20260915
```
## 2026-09-15 Redis 6381 隔离 volatile-lru 演练与清理

### 概述

- 目的：验证 `volatile-lru` 在内存达到上限时，只淘汰设置了 TTL 的 key，不淘汰无 TTL key。
- 实例：`127.0.0.1:6381`
- 临时目录：`/var/lib/redis-volatile-lru-20260915`
- 实验结束后已关闭实例并清理目录。

### 启动前检查与创建目录

```bash
sudo ss -lntp 'sport = :6381'
```

输出显示没有进程监听 `6381`。

```bash
sudo install -d -o redis -g redis -m 700 /var/lib/redis-volatile-lru-20260915
```

### 启动隔离实例并验证配置

```bash
sudo -u redis redis-server \
  --bind 127.0.0.1 \
  --port 6381 \
  --dir /var/lib/redis-volatile-lru-20260915 \
  --appendonly no \
  --save "" \
  --maxmemory 1048576 \
  --maxmemory-policy volatile-lru \
  --daemonize yes \
  --pidfile /var/lib/redis-volatile-lru-20260915/redis.pid \
  --logfile /var/lib/redis-volatile-lru-20260915/redis.log \
  --supervised no
```

```bash
redis-cli -p 6381 PING
redis-cli -p 6381 CONFIG GET maxmemory
redis-cli -p 6381 CONFIG GET maxmemory-policy
```

关键输出：

```text
PONG
maxmemory
1048576
maxmemory-policy
volatile-lru
```

### 写入测试数据

```bash
value=$(printf 'A%.0s' $(seq 1 65536))

for i in $(seq 1 3); do
  redis-cli -p 6381 SET "practice:volatile-lru:no-ttl:$i" "$value"
done

for i in $(seq 1 30); do
  redis-cli -p 6381 SET "practice:volatile-lru:ttl:$i" "$value" EX 86400
done
```

关键输出：

```text
OK
```

说明：

- 每个 value 为 65536 字节。
- 无 TTL key：`practice:volatile-lru:no-ttl:1` 到 `:3`
- 带 TTL key：`practice:volatile-lru:ttl:1` 到 `:30`
- `EX 86400` 表示过期时间为 86400 秒，即 24 小时。

### 验证淘汰结果

```bash
redis-cli -p 6381 INFO stats
redis-cli -p 6381 INFO stats | grep -E '^(evicted_keys:)'
redis-cli -p 6381 DBSIZE
redis-cli -p 6381 --scan --pattern 'practice:volatile-lru:*' | sort -V
```

关键输出：

```text
evicted_keys:27
(integer) 6
practice:volatile-lru:no-ttl:1
practice:volatile-lru:no-ttl:2
practice:volatile-lru:no-ttl:3
practice:volatile-lru:ttl:28
practice:volatile-lru:ttl:29
practice:volatile-lru:ttl:30
```

结论：

- 总共写入 30 个带 TTL key，最后保留 3 个。
- 被淘汰数量：`30 - 3 = 27`
- 无 TTL key 全部保留，即使它们写入时间更早。
- `volatile-lru` 只在设置了 TTL 的 key 中执行淘汰。

### 验证 TTL 与数据长度

```bash
for key in \
  practice:volatile-lru:no-ttl:1 \
  practice:volatile-lru:ttl:28 \
  practice:volatile-lru:ttl:29 \
  practice:volatile-lru:ttl:30
do
  printf '%s TTL=%s\n' "$key" "$(redis-cli -p 6381 TTL "$key")"
done

redis-cli -p 6381 STRLEN practice:volatile-lru:no-ttl:1
redis-cli -p 6381 STRLEN practice:volatile-lru:ttl:30
```

关键输出：

```text
practice:volatile-lru:no-ttl:1 TTL=-1
practice:volatile-lru:ttl:28 TTL=86135
practice:volatile-lru:ttl:29 TTL=86135
practice:volatile-lru:ttl:30 TTL=86135
(integer) 65536
(integer) 65536
```

说明：

- `TTL=-1` 表示 key 存在但没有设置过期时间。
- `TTL=86135` 表示 key 存在且还有剩余过期时间。
- 两个 key 的 `STRLEN` 都是 65536，数据长度未被截断。

### 验证内存状态

```bash
redis-cli -p 6381 INFO memory | grep -E '^(used_memory:|used_memory_human:|maxmemory:|maxmemory_human:|maxmemory_policy:)'
```

关键输出：

```text
used_memory:923472
used_memory_human:901.83K
maxmemory:1048576
maxmemory_human:1.00M
maxmemory_policy:volatile-lru
```

### 关闭实例并验证

```bash
redis-cli -p 6381 SHUTDOWN NOSAVE
redis-cli -p 6381 PING
redis-cli -p 6379 PING
```

关键输出：

```text
Could not connect to Redis at 127.0.0.1:6381: Connection refused
PONG
```

结论：6381 临时实例已停止，正式 6379 实例正常。

### 清理临时目录

```bash
sudo ls -la /var/lib/redis-volatile-lru-20260915
sudo find /var/lib/redis-volatile-lru-20260915 -maxdepth 1 -type f -printf '%f %s bytes\n'
```

关键输出：

```text
redis.log 2745 bytes
```

```bash
sudo rm -i /var/lib/redis-volatile-lru-20260915/redis.log
sudo rmdir /var/lib/redis-volatile-lru-20260915
sudo ls -ld /var/lib/redis-volatile-lru-20260915
```

关键输出：

```text
ls: 无法访问/var/lib/redis-volatile-lru-20260915: 没有那个文件或目录
```

结论：临时日志和空目录已清理，清理目标不涉及正式 `6379`、`/var/lib/redis`、AOF 或 RDB。

## 2026-09-15 Redis 内核参数调整与验证

### 调整前检查

```bash
redis-cli -p 6379 PING
redis-cli -p 6379 CONFIG GET tcp-backlog
sysctl net.core.somaxconn
sysctl vm.overcommit_memory
cat /sys/kernel/mm/transparent_hugepage/enabled
```

关键输出：

```text
PONG
tcp-backlog 511
net.core.somaxconn = 128
vm.overcommit_memory = 0
[always] madvise never
```

### 备份并写入 sysctl 配置

```bash
sudo cp -a /etc/sysctl.conf "/etc/sysctl.conf.bak-$(date +%Y%m%d-%H%M%S)"
sudo tee /etc/sysctl.d/99-redis.conf >/dev/null <<'EOF'
net.core.somaxconn = 1024
vm.overcommit_memory = 1
EOF
sudo sysctl --system
```

关键输出：

```text
- Applying /etc/sysctl.d/99-redis.conf ...
  net.core.somaxconn = 1024
  vm.overcommit_memory = 1
```

复核：

```bash
sysctl net.core.somaxconn
sysctl vm.overcommit_memory
```

```text
net.core.somaxconn = 1024
vm.overcommit_memory = 1
```

### 关闭并持久化 THP 配置

```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/enabled

sudo tee /etc/tmpfiles.d/redis-disable-thp.conf >/dev/null <<'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - never
EOF
```

关键输出：

```text
never
always madvise [never]
```

### 重启 Redis 验证监听队列

```bash
sudo ss -lntp 'sport = :6379'
sudo systemctl restart redis
redis-cli -p 6379 PING
sudo ss -lntp 'sport = :6379'
redis-cli -p 6379 CONFIG GET tcp-backlog
```

关键输出：

```text
LISTEN 0 128 127.0.0.1:6379
PONG
LISTEN 0 511 127.0.0.1:6379
tcp-backlog 511
```

### 最终复核

```bash
sysctl net.core.somaxconn
sysctl vm.overcommit_memory
cat /sys/kernel/mm/transparent_hugepage/enabled
```

关键输出：

```text
net.core.somaxconn = 1024
vm.overcommit_memory = 1
always madvise [never]
```

结论：三项内核参数调整完成；Redis 重启后实际监听队列从 `128` 变为 `511`，服务仍返回 `PONG`。

## 2026-09-15 Redis 巡检手册验证

### 服务、监听与基础配置

```bash
systemctl is-active redis
systemctl is-enabled redis
sudo ss -lntp 'sport = :6379'
redis-cli -p 6379 PING
redis-cli -p 6379 DBSIZE
redis-cli -p 6379 CONFIG GET maxmemory
redis-cli -p 6379 CONFIG GET maxmemory-policy
redis-cli -p 6379 CONFIG GET appendonly
redis-cli -p 6379 CONFIG GET save
redis-cli -p 6379 CONFIG GET dir
redis-cli -p 6379 CONFIG GET dbfilename
```

关键输出：

```text
active
enabled
LISTEN 0 511 127.0.0.1:6379
PONG
(integer) 3
maxmemory 134217728
maxmemory-policy noeviction
appendonly yes
save 900 1 300 10 60 10000
dir /var/lib/redis
dbfilename dump.rdb
```

### 进程、客户端、持久化与内存状态

```bash
redis-cli -p 6379 INFO server | grep -E '^(redis_version:|process_id:|uptime_in_seconds:|uptime_in_days:)'
redis-cli -p 6379 INFO clients | grep -E '^(connected_clients:|blocked_clients:)'
redis-cli -p 6379 CONFIG GET 'append*'
redis-cli -p 6379 INFO persistence | grep -E '^(rdb_last_bgsave_status:|rdb_last_save_time:|rdb_bgsave_in_progress:|aof_enabled:|aof_last_write_status:|aof_rewrite_in_progress:)'
redis-cli -p 6379 INFO memory | grep -E '^(used_memory_human:|used_memory_peak_human:|maxmemory_human:|maxmemory_policy:|mem_fragmentation_ratio:)'
redis-cli -p 6379 INFO stats | grep -E '^(evicted_keys:|rejected_connections:|keyspace_hits:|keyspace_misses:)'
```

关键输出：

```text
redis_version:3.2.12
process_id:18184
uptime_in_seconds:1926
uptime_in_days:0
connected_clients:1
blocked_clients:0
appendfsync everysec
appendonly yes
rdb_bgsave_in_progress:0
rdb_last_bgsave_status:ok
aof_enabled:1
aof_rewrite_in_progress:0
aof_last_write_status:ok
used_memory_human:793.88K
used_memory_peak_human:793.88K
maxmemory_human:128.00M
maxmemory_policy:noeviction
mem_fragmentation_ratio:3.29
evicted_keys:0
rejected_connections:0
```

### 持久化文件、key 分布与日志

```bash
sudo ls -lh /var/lib/redis
sudo find /var/lib/redis -maxdepth 1 -type f -printf '%f %s bytes %TY-%Tm-%Td %TH:%TM\n'
redis-cli -p 6379 LASTSAVE
date -d "@$(redis-cli -p 6379 LASTSAVE)" '+%F %T %Z'
redis-cli -p 6379 INFO keyspace
sudo journalctl -u redis -p err..alert --since "24 hours ago" --no-pager
```

关键输出：

```text
appendonly.aof 212 bytes 2026-09-14 11:41
dump.rdb 185 bytes 2026-09-15 15:49
dump.rdb.before-restart-20260913-183303 158 bytes 2026-09-13 17:35
LASTSAVE 1789458586
2026-09-15 15:49:46 CST
db0:keys=3,expires=0,avg_ttl=0
-- No entries --
```

结论：服务、监听、配置、RDB/AOF 状态、持久化文件、内存、key 分布和错误日志巡检全部通过。

## 2026-09-15 Docker 安装与容器生命周期验证

### 系统检查与安装

```bash
cat /etc/os-release
uname -r
docker --version
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

关键结果：

```text
CentOS Linux 7 (Core)
3.10.0-1160.el7.x86_64
bash: docker: 未找到命令...
curl#35 - "TCP connection reset by peer"
```

改用阿里云仓库并安装：

```bash
sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo yum makecache fast
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

关键安装版本：

```text
docker-ce 26.1.4-1.el7
docker-ce-cli 26.1.4-1.el7
containerd.io 1.6.33-3.1.el7
docker-compose-plugin 2.27.1-1.el7
```

验证：

```bash
sudo docker version
sudo docker info
docker compose version
```

关键结果：

```text
Client: Docker Engine - Community 26.1.4
Server: Docker Engine - Community 26.1.4
Storage Driver: overlay2
Backing Filesystem: xfs
Docker Root Dir: /var/lib/docker
Docker Compose version v2.27.1
```

### 镜像加速与 hello-world

```bash
sudo docker run --rm hello-world
```

首次失败：

```text
Get "https://registry-1.docker.io/v2/": dial tcp 104.244.43.248:443: i/o timeout
```

配置加速器：

```bash
sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
EOF

sudo systemctl restart docker
```

重新验证：

```bash
sudo docker run --rm hello-world
```

关键结果：

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

### 镜像与容器生命周期

```bash
sudo docker images
sudo docker ps
sudo docker ps -a
sudo docker run -d --name practice-alpine alpine:latest sleep 300
sudo docker ps --filter name=practice-alpine
sudo docker inspect practice-alpine --format 'Name={{.Name}} State={{.State.Status}} Image={{.Config.Image}}'
sudo docker exec practice-alpine cat /etc/os-release
sudo docker stop practice-alpine
sudo docker ps -a --filter name=practice-alpine
sudo docker rm practice-alpine
sudo docker ps -a --filter name=practice-alpine
sudo docker rmi alpine:latest hello-world:latest
sudo docker images
```

关键结果：

```text
practice-alpine State=running
Alpine Linux v3.24
Exited (137)
practice-alpine
最终 docker images 为空
```

结论：Docker 镜像拉取、容器运行、状态检查、容器内执行命令、停止、删除容器和删除镜像均验证完成。

## 2026-09-15 Docker 数据卷验证

### 创建并查看数据卷

```bash
sudo docker volume create practice-volume
sudo docker volume inspect practice-volume --format '{{.Name}} {{.Mountpoint}}'
```

关键输出：

```text
practice-volume
practice-volume /var/lib/docker/volumes/practice-volume/_data
```

### 用两个独立容器验证数据持久化

第一个容器写入：

```bash
sudo docker run --rm \
  -v practice-volume:/data \
  alpine sh -c 'echo docker-volume-ok > /data/check.txt'
```

关键输出：

```text
Status: Downloaded newer image for alpine:latest
```

第二个新容器读取：

```bash
sudo docker run --rm \
  -v practice-volume:/data \
  alpine cat /data/check.txt
```

关键输出：

```text
docker-volume-ok
```

结论：第一个容器已删除，但第二个新容器仍能读出数据，证明数据保存在 `practice-volume` 中。

### 清理数据卷和镜像

```bash
sudo docker volume ls --filter name=practice-volume
sudo docker volume rm practice-volume
sudo docker volume ls --filter name=practice-volume
sudo docker rmi alpine:latest
```

关键输出：

```text
local     practice-volume
practice-volume
Untagged: alpine:latest
Deleted: ...
```

最终 `practice-volume` 不存在，`alpine:latest` 镜像已删除。

## 2026-09-15 Docker 端口映射验证

### 检查端口并首次运行

```bash
sudo ss -lntp 'sport = :18080'
sudo docker run -d \
  --name practice-nginx \
  -p 18080:80 \
  nginx:alpine
```

首次运行后容器退出，检查：

```bash
sudo docker ps -a --filter name=practice-nginx
sudo docker inspect practice-nginx \
  --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} OOM={{.State.OOMKilled}}'
sudo docker logs --tail 50 practice-nginx
```

关键输出：

```text
Exited (1)
Status=exited ExitCode=1 Error= OOM=false
pwrite() "/run/nginx.pid" failed (1: Operation not permitted)
```

结论：应用启动失败，不是端口映射失败。

### 改用固定版本

```bash
sudo docker run -d \
  --name practice-nginx \
  -p 18080:80 \
  nginx:1.24-alpine
```

验证：

```bash
sudo docker ps --filter name=practice-nginx
sudo docker logs --tail 20 practice-nginx
sudo docker port practice-nginx
curl -I http://127.0.0.1:18080
```

关键输出：

```text
nginx:1.24-alpine   Up   0.0.0.0:18080->80/tcp, :::18080->80/tcp
nginx/1.24.0
start worker processes
80/tcp -> 0.0.0.0:18080
80/tcp -> [::]:18080
HTTP/1.1 200 OK
Server: nginx/1.24.0
```

### 清理

```bash
sudo docker stop practice-nginx
sudo docker rm practice-nginx
sudo docker rmi nginx:1.24-alpine
```

关键输出：

```text
practice-nginx
practice-nginx
Untagged: nginx:1.24-alpine
Deleted: ...
```

结论：宿主机 `18080` 到容器 `80` 的端口映射验证完成，练习容器和镜像已清理。

## 2026-09-15 Dockerfile 自定义镜像验证

### 创建文件

```bash
mkdir -p ~/dockerfile-practice
cd ~/dockerfile-practice
```

`index.html` 内容：

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Dockerfile Practice</title>
</head>
<body>
  <h1>Dockerfile build success</h1>
</body>
</html>
```

`Dockerfile` 内容：

```dockerfile
FROM nginx:1.24-alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### 构建镜像

第一次缺少构建上下文：

```bash
sudo docker build -t practice-nginx-image:1.0
```

关键报错：

```text
ERROR: "docker buildx build" requires exactly 1 argument.
```

正确命令：

```bash
sudo docker build -t practice-nginx-image:1.0 .
```

### 运行并验证

```bash
sudo ss -lntp 'sport = :18081'

sudo docker run -d \
  --name practice-nginx-image \
  -p 18081:80 \
  practice-nginx-image:1.0

sudo docker ps --filter name=practice-nginx-image
sudo docker port practice-nginx-image
curl -I http://127.0.0.1:18081
curl http://127.0.0.1:18081
```

关键输出：

```html
<h1>Dockerfile build success</h1>
```

结论：自定义镜像构建、运行、端口映射和页面读回全部成功。

### 清理

```bash
sudo docker stop practice-nginx-image
sudo docker rm practice-nginx-image
sudo docker rmi practice-nginx-image:1.0
sudo docker images
```

关键输出：

```text
practice-nginx-image
practice-nginx-image
Untagged: practice-nginx-image:1.0
Deleted: ...
```

最终镜像列表为空；`~/dockerfile-practice` 源文件目录保留。

## 2026-09-15 Docker Compose 编排验证

### 创建配置

```bash
mkdir -p ~/compose-practice
cd ~/compose-practice
```

`index.html` 关键内容：

```html
<h1>Docker Compose success</h1>
```

`docker-compose.yml` 内容：

```yaml
services:
  web:
    image: nginx:1.24-alpine
    container_name: practice-compose-web
    ports:
      - "18082:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
    depends_on:
      - cache
    restart: unless-stopped

  cache:
    image: redis:7.2-alpine
    container_name: practice-compose-cache
    restart: unless-stopped
```

### 检查配置并启动

```bash
sudo docker compose config
sudo ss -lntp 'sport = :18082'
sudo docker compose up -d
```

关键输出：

```text
name: compose-practice
networks:
  default:
    name: compose-practice_default
Network compose-practice_default Created
Container practice-compose-cache Started
Container practice-compose-web Started
```

### 验证服务

```bash
sudo docker compose ps
sudo docker ps --filter name=practice-compose
curl -I http://127.0.0.1:18082
curl http://127.0.0.1:18082
sudo docker compose exec cache redis-cli PING
sudo docker compose exec cache redis-cli SET compose:practice ok
sudo docker compose exec cache redis-cli GET compose:practice
sudo docker compose logs --tail 20 web
sudo docker compose logs --tail 20 cache
```

关键输出：

```text
practice-compose-cache   Up   6379/tcp
practice-compose-web     Up   0.0.0.0:18082->80/tcp
HTTP/1.1 200 OK
Docker Compose success
PONG
OK
"ok"
```

注意：`GET compose:practice ok` 会报 `wrong number of arguments for 'get' command`，因为 `GET` 只接受一个 key。

### 清理

```bash
sudo docker compose down
sudo docker compose ps
sudo docker network ls | grep compose-practice
sudo docker images
sudo docker rmi nginx:1.24-alpine redis:7.2-alpine
sudo docker images
```

关键输出：

```text
Container practice-compose-web Removed
Container practice-compose-cache Removed
Network compose-practice_default Removed
Untagged: nginx:1.24-alpine
Untagged: redis:7.2-alpine
Deleted: ...
```

最终 `docker compose ps` 和 `docker images` 均为空；`~/compose-practice` 源文件目录保留。

## 2026-09-16 Ansible 安装与 Inventory 验证

### 环境检查

```bash
ansible --version
python3 --version
yum repolist enabled | grep -iE 'epel|ansible'
```

关键输出：

```text
bash: ansible: 未找到命令...
Python 3.6.8
epel/x86_64  Extra Packages for Enterprise Linux 7 - x86_64
```

### 安装并验证

```bash
sudo yum install -y ansible
ansible --version
```

关键输出：

```text
ansible 2.9.27
config file = /etc/ansible/ansible.cfg
python version = 2.7.5
```

### 本机连通性

```bash
cd /home/atguigu
ansible localhost -m ping
```

关键输出：

```text
localhost | SUCCESS => changed=false, ping=pong
```

### Inventory

```bash
mkdir -p ~/ansible-practice
cd ~/ansible-practice
cat > inventory.ini <<'EOF'
[local]
localhost ansible_connection=local
EOF
```

解析：

```bash
ansible-inventory -i inventory.ini --list
```

关键输出：

```text
localhost 的 hostvars 包含 ansible_connection=local
all 包含 local 和 ungrouped
local 包含 localhost
```

验证：

```bash
ansible local -i inventory.ini -m ping
ansible local -i inventory.ini -m setup -a 'filter=ansible_distribution*'
```

关键输出：

```text
localhost | SUCCESS => discovered_interpreter_python=/usr/bin/python, changed=false, ping=pong
ansible_distribution: CentOS
ansible_distribution_version: 7.9
```

## 2026-09-16 Ansible Ad-hoc 命令验证

### command 模块

```bash
ansible local -i inventory.ini -m command -a 'pwd'
```

关键输出：

```text
/home/atguigu/ansible-practice
```

### file 模块创建目录并验证幂等性

```bash
ansible local -i inventory.ini -m file \
  -a 'path=/home/atguigu/ansible-practice/adhoc state=directory mode=0755'
```

第一次关键输出：

```text
changed=true
state=directory
mode=0755
```

第二次关键输出：

```text
changed=false
state=directory
mode=0755
```

### copy 模块写入文件并验证幂等性

```bash
ansible local -i inventory.ini -m copy \
  -a 'content="ansible adhoc ok" dest=/home/atguigu/ansible-practice/adhoc/hello.txt mode=0644'
```

第一次关键输出：

```text
changed=true
dest=/home/atguigu/ansible-practice/adhoc/hello.txt
mode=0644
size=16
```

第二次关键输出：

```text
changed=false
mode=0644
size=16
```

### 读取文件和检查状态

```bash
ansible local -i inventory.ini -m command \
  -a 'cat /home/atguigu/ansible-practice/adhoc/hello.txt'

ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/adhoc/hello.txt'
```

关键输出：

```text
ansible adhoc ok
exists=true
isreg=true
mode=0644
readable=true
writeable=true
executable=false
```

### 清理

```bash
ansible local -i inventory.ini -m file \
  -a 'path=/home/atguigu/ansible-practice/adhoc state=absent'

ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/adhoc'
```

关键输出：

```text
changed=true
state=absent
exists=false
```

## 2026-09-16 Ansible Playbook 基础验证

### 创建 Playbook

```bash
cd /home/atguigu/ansible-practice
```

`site.yml` 关键内容：

```yaml
---
- name: Practice basic playbook
  hosts: local
  connection: local
  gather_facts: false

  vars:
    practice_dir: /home/atguigu/ansible-practice/playbook-demo
    practice_file: "{{ practice_dir }}/hello.txt"
    practice_content: "ansible playbook ok\n"

  tasks:
    - name: Create practice directory
      file:
        path: "{{ practice_dir }}"
        state: directory
        mode: '0755'

    - name: Create practice file
      copy:
        content: "{{ practice_content }}"
        dest: "{{ practice_file }}"
        mode: '0644'

    - name: Read practice file
      command: "cat {{ practice_file }}"
      register: file_content
      changed_when: false

    - name: Show practice file content
      debug:
        var: file_content.stdout
```

### 语法检查

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
```

关键输出：

```text
playbook: site.yml
```

### 第一次执行

```bash
ansible-playbook -i inventory.ini site.yml
```

关键输出：

```text
TASK [Create practice directory] changed
TASK [Create practice file] changed
TASK [Read practice file] ok
TASK [Show practice file content] ok

PLAY RECAP
localhost : ok=4 changed=2 unreachable=0 failed=0
```

### 第二次执行，验证幂等性

```bash
ansible-playbook -i inventory.ini site.yml
```

关键输出：

```text
TASK [Create practice directory] ok
TASK [Create practice file] ok
TASK [Read practice file] ok
TASK [Show practice file content] ok

PLAY RECAP
localhost : ok=4 changed=0 unreachable=0 failed=0
```

### 文件状态验证

```bash
ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/playbook-demo/hello.txt'
```

关键输出：

```text
exists=true
isreg=true
mode=0644
size=20
```

### 清理

```bash
ansible local -i inventory.ini -m file \
  -a 'path=/home/atguigu/ansible-practice/playbook-demo state=absent'

ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/playbook-demo'
```

关键输出：

```text
changed=true
state=absent
exists=false
```

## 2026-09-16 Ansible 变量与模板验证

### 变量来源与优先级

```bash
cd /home/atguigu/ansible-practice
ansible local -i inventory.ini -m debug -a "msg={{ app_port }}" -e "app_port=18090"
ansible local -i inventory.ini -m debug -a "msg={{ app_port }}"
```

关键输出：

```text
localhost | SUCCESS => { "msg": "18090" }
localhost | FAILED! => { "msg": "The task includes an option with an undefined variable. The error was: 'app_port' is undefined" }
```

结论：命令行 `-e` 传的变量优先级高于 playbook `vars`；未定义变量会直接让任务失败，不会当成空字符串。

### 创建模板与 Playbook

```bash
cd /home/atguigu/ansible-practice
mkdir -p templates
cat > templates/app.conf.j2 <<'EOF'
# Managed by Ansible
app_name={{ app_name }}
app_port={{ app_port }}
app_owner={{ app_owner }}
EOF

cat > vars-template.yml <<'EOF'
---
- name: Practice variables and template
  hosts: local
  connection: local
  gather_facts: false

  vars:
    app_name: demo-app
    app_port: 18090
    app_owner: atguigu
    practice_dir: /home/atguigu/ansible-practice/template-demo
    config_file: "{{ practice_dir }}/app.conf"

  tasks:
    - name: Create template practice directory
      file:
        path: "{{ practice_dir }}"
        state: directory
        mode: '0755'

    - name: Render app config
      template:
        src: templates/app.conf.j2
        dest: "{{ config_file }}"
        mode: '0644'

    - name: Read app config
      command: "cat {{ config_file }}"
      register: app_config
      changed_when: false

    - name: Show app config
      debug:
        var: app_config.stdout
EOF
```

说明：`<<'EOF'` 的单引号保留原样写入，`{{ }}` 才会交给 Jinja2 渲染。

### 语法检查、渲染与幂等

```bash
ansible-playbook -i inventory.ini vars-template.yml --syntax-check
ansible-playbook -i inventory.ini vars-template.yml
cat /home/atguigu/ansible-practice/template-demo/app.conf
ansible-playbook -i inventory.ini vars-template.yml
```

关键输出：

```text
语法检查：playbook: vars-template.yml
第一次  ：ok=4 changed=2 unreachable=0 failed=0
cat     ：# Managed by Ansible / app_name=demo-app / app_port=18090 / app_owner=atguigu
第二次  ：ok=4 changed=0 unreachable=0 failed=0
```

结论：`template` 模块按模板渲染生成配置文件；第二次内容一致，返回 `changed=0`，幂等性成立。

### 命令行变量覆盖模板内容

```bash
ansible-playbook -i inventory.ini vars-template.yml -e "app_port=18091"
ansible-playbook -i inventory.ini vars-template.yml -e "app_port=18091"
```

关键输出：

```text
第一次：ok=4 changed=1，debug 显示 app_port=18091
第二次：ok=4 changed=0
```

结论：`-e` 覆盖 playbook 内变量后渲染结果随之变化；同一组变量值重复执行不再产生变更。
