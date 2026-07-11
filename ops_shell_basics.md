# 运维 Shell 基础笔记

学习主线：围绕 `/opt/scripts/check_nginx.sh` 这个 Nginx 健康检查脚本理解 Shell 语法。

脚本目标：

```text
检查 Nginx 是否运行
检查网站 HTTP 状态码是否为 200
失败时尝试启动或重启 Nginx
把检查过程写入日志
日志过大时自动备份
```

## 1. 变量

变量用于保存值。

语法：

```bash
变量名="值"
```

示例：

```bash
NAME="nginx"
echo "$NAME"
echo "service name is $NAME"
```

结果：

```text
nginx
service name is nginx
```

注意：

```bash
NAME = "nginx"
```

这种写法是错的。Shell 变量赋值时等号两边不能有空格。

建议：

```bash
"$变量名"
```

原因：如果变量内容里有空格，用双引号更安全。

## 2. 单引号和双引号

双引号会解析变量：

```bash
NAME="nginx"
echo "service name is $NAME"
```

输出：

```text
service name is nginx
```

单引号不会解析变量：

```bash
echo 'service name is $NAME'
```

输出：

```text
service name is $NAME
```

一句话记住：

```text
双引号会替换变量，单引号原样输出。
```

## 3. 变量边界：$VAR 和 ${VAR}

普通情况：

```bash
echo "$LOG_FILE"
```

变量后面要拼接字符时，建议用 `{}` 明确变量边界：

```bash
echo "${LOG_FILE}.bak"
```

示例：

```bash
LOG_FILE="/var/log/nginx_check.log"
echo "${LOG_FILE}.$(date '+%Y%m%d%H%M%S').bak"
```

输出类似：

```text
/var/log/nginx_check.log.20260706210006.bak
```

## 4. 文件测试

文件测试用于判断文件或目录是否存在。

语法：

```bash
[ 条件 ]
```

注意：`[` 和 `]` 两边要有空格。

正确：

```bash
[ -f "$LOG_FILE" ]
```

错误：

```bash
["$LOG_FILE" -gt "$MAX_SIZE"]
```

常用测试：

```text
-f   存在并且是普通文件
-d   存在并且是目录
-e   文件或目录存在
-r   当前用户可读
-w   当前用户可写
-x   当前用户可执行
```

示例：

```bash
[ -f /var/log/nginx_check.log ]; echo $?
[ -d /var/log ]; echo $?
[ -f /var/log ]; echo $?
```

结果含义：

```text
0   条件成立，true
1   条件不成立，false
```

## 5. 退出状态 $?

`$?` 表示上一条命令的退出状态。

示例：

```bash
[ -f /var/log/nginx_check.log ]
echo $?
```

含义：

```text
0      成功，条件成立
非 0   失败，条件不成立
```

在 `if` 里，Shell 就是根据退出状态判断走 `then` 还是 `else`。

## 6. if 判断

基本语法：

```bash
if 条件; then
    条件成立执行这里
else
    条件不成立执行这里
fi
```

示例：

```bash
if [ -f /var/log/nginx_check.log ]; then
    echo "log file exists"
else
    echo "log file not found"
fi
```

`fi` 是 `if` 反过来写，表示 if 结束。

## 7. 字符串比较

语法：

```bash
[ "$A" = "$B" ]
[ "$A" != "$B" ]
```

示例：

```bash
HTTP_CODE="200"

if [ "$HTTP_CODE" = "200" ]; then
    echo "website check OK"
else
    echo "website check FAILED"
fi
```

说明：

```text
=    字符串相等
!=   字符串不相等
```

你的脚本里：

```bash
[ "$HTTP_CODE" = "200" ]
```

意思是判断 HTTP 状态码是不是 200。

## 8. 数值比较

数字不能用 `>` 或 `<` 直接比较，Shell 常用这些参数：

```text
-eq   equal，等于
-ne   not equal，不等于
-gt   greater than，大于
-lt   less than，小于
-ge   greater or equal，大于等于
-le   less or equal，小于等于
```

示例：

```bash
LOG_SIZE=5521
MAX_SIZE=$((1024 * 1024))

if [ "$LOG_SIZE" -gt "$MAX_SIZE" ]; then
    echo "log is too large"
else
    echo "log size is ok"
fi
```

说明：

```text
-gt 用于数字大于比较
=   用于字符串比较
```

## 9. 算术运算

推荐语法：

```bash
MAX_SIZE=$((1024 * 1024))
```

含义：

```text
1024 * 1024 = 1048576
```

也就是 1 MB。

你也试过旧写法：

```bash
MAX_SIZE=$[ 1024 * 1024]
```

能用，但推荐使用：

```bash
$(( ))
```

## 10. 命令替换

命令替换用于把命令输出保存到变量里。

语法：

```bash
变量=$(命令)
```

示例：

```bash
LOG_SIZE=$(stat -c%s "$LOG_FILE")
echo "$LOG_SIZE"
```

含义：

```text
先执行 stat -c%s "$LOG_FILE"
再把输出结果保存到 LOG_SIZE
```

注意区分：

```bash
echo "$HTTP_CODE"
```

这是读取变量。

```bash
echo "$(HTTP_CODE)"
```

这是尝试执行一个叫 `HTTP_CODE` 的命令，会报错。

## 11. stat 查看文件大小

查看文件信息：

```bash
stat /var/log/nginx_check.log
```

只查看文件大小：

```bash
stat -c%s "$LOG_FILE"
```

参数说明：

```text
stat        查看文件详细状态
-c          format，按指定格式输出
%s          文件大小，单位是字节
```

示例：

```bash
LOG_FILE="/var/log/nginx_check.log"
stat -c%s "$LOG_FILE"
LOG_SIZE=$(stat -c%s "$LOG_FILE")
echo "$LOG_SIZE"
```

## 12. date 时间格式

常用：

```bash
date '+%F %T'
```

输出类似：

```text
2026-07-07 14:16:51
```

格式说明：

```text
%F   年-月-日，等价于 %Y-%m-%d
%T   时:分:秒，等价于 %H:%M:%S
%Y   四位年份
%m   月
%d   日
%H   小时
%M   分钟
%S   秒
```

用于备份文件名：

```bash
date '+%Y%m%d%H%M%S'
```

输出类似：

```text
20260706210006
```

## 13. 重定向：> 和 >>

覆盖写入：

```bash
echo "hello" > /tmp/test.log
```

追加写入：

```bash
echo "hello" >> /tmp/test.log
```

区别：

```text
>    覆盖原文件内容
>>   追加到文件末尾
```

你的脚本用：

```bash
echo "[$(date '+%F %T')] Start checking nginx..." >> "$LOG_FILE"
```

意思是把日志追加到日志文件末尾。

## 14. /dev/null

`/dev/null` 是 Linux 的黑洞文件。

写进去的内容会被丢弃。

示例：

```bash
curl -o /dev/null http://192.168.6.100
```

含义：

```text
访问网页，但不要保存网页正文。
```

在你的脚本中：

```bash
curl -o /dev/null -s -w "%{http_code}" "$URL"
```

因为只需要状态码，所以网页正文直接丢掉。

## 15. curl 状态码

你的脚本核心命令：

```bash
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
```

完整解释：

```text
HTTP_CODE=                 定义变量
$(...)                     执行括号里的命令，并把输出保存到变量
curl                       访问 URL
-o /dev/null               把网页正文丢掉
-s                         静默模式，不显示进度条
-w "%{http_code}"          输出 HTTP 状态码
"$URL"                     要访问的地址
```

常用 curl 参数：

```text
-I                    只看响应头
-o 文件名             保存响应正文到指定文件
-O                    使用远程文件名保存
-s                    静默模式
-w FORMAT             按格式输出信息
--connect-timeout 秒   设置连接超时时间
```

`-w` 里的变量不是随便写的，只能用 curl 支持的内置变量。

常见：

```text
%{http_code}       HTTP 状态码
%{time_total}      总耗时
%{remote_ip}       远端 IP
%{size_download}   下载大小
```

示例：

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://192.168.6.100
curl -o /dev/null -s -w "code=%{http_code}, time=%{time_total}\n" http://192.168.6.100
```

## 16. systemctl 判断服务

显示服务状态：

```bash
systemctl is-active nginx
```

输出可能是：

```text
active
inactive
failed
unknown
```

静默判断：

```bash
systemctl is-active --quiet nginx
echo $?
```

参数说明：

```text
is-active   判断服务是否 active
--quiet     不输出文字，只返回退出状态
```

结果：

```text
0     服务 active
非 0  服务不是 active
```

用于 if：

```bash
if systemctl is-active --quiet nginx; then
    echo "nginx service is running."
else
    echo "nginx service is not running."
fi
```

## 17. systemctl 管理服务

常用命令：

```bash
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx
sudo systemctl status nginx
sudo systemctl enable nginx
sudo systemctl disable nginx
```

含义：

```text
start     启动
stop      停止
restart   重启，先 stop 再 start
reload    重新加载配置
status    查看状态
enable    设置开机自启
disable   取消开机自启
```

## 18. mv 和 touch

备份旧日志：

```bash
mv "$LOG_FILE" "${LOG_FILE}.$(date '+%Y%m%d%H%M%S').bak"
```

含义：

```text
mv              移动或重命名文件
"$LOG_FILE"     原日志文件
"${LOG_FILE}..." 新日志备份文件名
```

创建新空日志：

```bash
touch "$LOG_FILE"
```

`touch` 的作用：

```text
文件不存在：创建空文件
文件存在：更新文件时间
```

## 19. 函数

函数用于封装重复逻辑。

语法：

```bash
函数名() {
    命令
}
```

你的日志函数：

```bash
log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}
```

调用：

```bash
log "Start checking nginx..."
log "website check OK, http_code=200"
```

等价于：

```bash
echo "[当前时间] Start checking nginx..." >> "$LOG_FILE"
echo "[当前时间] website check OK, http_code=200" >> "$LOG_FILE"
```

函数参数：

```text
$1   第一个参数
$2   第二个参数
$*   所有参数合起来
$@   所有参数，保留参数边界，进阶再学
```

示例：

```bash
log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

log nginx service is running
log "website check OK, http_code=200"
```

注意：

```text
函数必须先定义，再调用。
```

## 20. 嵌套 if

嵌套 if 就是 if 里面再写 if。

示例：

```bash
if [ "$HTTP_CODE" = "200" ]; then
    log "website check OK, http_code=$HTTP_CODE"
else
    log "website check FAILED, http_code=$HTTP_CODE, restarting nginx..."
    systemctl restart nginx

    HTTP_CODE_AFTER_RESTART=$(curl -o /dev/null -s -w "%{http_code}" "$URL")

    if [ "$HTTP_CODE_AFTER_RESTART" = "200" ]; then
        log "website recovered after restart, http_code=$HTTP_CODE_AFTER_RESTART"
    else
        log "website still FAILED after restart, http_code=$HTTP_CODE_AFTER_RESTART"
    fi
fi
```

执行逻辑：

```text
第一次检查是 200：
    记录正常，结束

第一次检查不是 200：
    记录失败
    重启 Nginx
    再检查一次
    如果第二次是 200，记录恢复
    如果第二次仍然不是 200，记录仍然失败
```

## 21. bash -n 语法检查

语法检查：

```bash
bash -n /opt/scripts/check_nginx.sh
```

参数说明：

```text
bash   Bash 解释器
-n     no execute，只检查语法，不执行脚本
```

能检查：

```text
if 和 fi 是否匹配
引号是否闭合
then/else 是否写对
括号是否完整
```

不会执行：

```text
不会写日志
不会 curl 网站
不会启动 Nginx
不会重启 Nginx
不会移动文件
```

没有输出通常表示语法没问题。

## 22. bash、sudo、./、source

只检查语法：

```bash
bash -n script.sh
```

用当前用户执行：

```bash
bash script.sh
```

直接执行脚本：

```bash
./script.sh
```

要求：

```text
脚本要有执行权限
脚本第一行最好有 #!/bin/bash
```

添加执行权限：

```bash
chmod +x script.sh
```

用 root 执行：

```bash
sudo ./script.sh
sudo bash script.sh
sudo /opt/scripts/check_nginx.sh
```

当前 shell 加载执行：

```bash
source script.sh
. script.sh
```

区别：

```text
bash script.sh     新 shell 执行，变量不会留在当前终端
./script.sh        新 shell 执行，需要执行权限
source script.sh   当前 shell 执行，变量会留在当前终端
```

你的 `check_nginx.sh` 不建议用 `source`，因为它是运维执行脚本，不是环境变量配置文件。

推荐：

```bash
bash -n /opt/scripts/check_nginx.sh
sudo /opt/scripts/check_nginx.sh
```

## 23. crontab 定时任务

查看 root 的定时任务：

```bash
sudo crontab -l
```

你当前有：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

五个星号含义：

```text
第 1 个 *   分钟，0-59
第 2 个 *   小时，0-23
第 3 个 *   日期，1-31
第 4 个 *   月份，1-12
第 5 个 *   星期，0-7，0 和 7 都可表示星期日
```

所以：

```bash
* * * * * /opt/scripts/check_nginx.sh
```

意思是：

```text
每分钟执行一次 /opt/scripts/check_nginx.sh
```

常见例子：

```bash
*/5 * * * * /opt/scripts/check_nginx.sh
```

每 5 分钟执行一次。

```bash
0 2 * * * /opt/scripts/check_nginx.sh
```

每天凌晨 2 点执行一次。

```bash
30 1 * * 1 /opt/scripts/check_nginx.sh
```

每周一凌晨 1:30 执行一次。

## 24. check_nginx.sh 函数优化版

完整脚本：

```bash
#!/bin/bash

LOG_FILE="/var/log/nginx_check.log"
URL="http://192.168.6.100"
MAX_SIZE=$((1024 * 1024))

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE")

    if [ "$LOG_SIZE" -gt "$MAX_SIZE" ]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date '+%Y%m%d%H%M%S').bak"
        touch "$LOG_FILE"
    fi
fi

log "Start checking nginx..."

if systemctl is-active --quiet nginx; then
    log "nginx service is running."
else
    log "nginx service is not running, starting nginx..."
    systemctl start nginx
fi

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")

if [ "$HTTP_CODE" = "200" ]; then
    log "website check OK, http_code=$HTTP_CODE"
else
    log "website check FAILED, http_code=$HTTP_CODE, restarting nginx..."
    systemctl restart nginx

    HTTP_CODE_AFTER_RESTART=$(curl -o /dev/null -s -w "%{http_code}" "$URL")

    if [ "$HTTP_CODE_AFTER_RESTART" = "200" ]; then
        log "website recovered after restart, http_code=$HTTP_CODE_AFTER_RESTART"
    else
        log "website still FAILED after restart, http_code=$HTTP_CODE_AFTER_RESTART"
    fi
fi

log "Check finished."
```

验证流程：

```bash
bash -n /opt/scripts/check_nginx.sh
sudo /opt/scripts/check_nginx.sh
sudo tail -n 20 /var/log/nginx_check.log
```

含义：

```text
先检查语法
再正式执行
最后看日志确认结果
```

