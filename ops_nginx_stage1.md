# Nginx 运维第一阶段总结笔记

适用环境：CentOS 7 虚拟机，VMware NAT 网络。

你的当前环境：

```text
Linux 用户：atguigu
主机名：centos100
系统：CentOS Linux 7
Linux IP：192.168.6.100/24
Nginx 端口：80/tcp
Nginx 网站根目录：/var/www/ops-site
后端服务：backend-demo（8080/tcp，systemd 管理）
后端目录：/opt/backend-demo
```

## 1. 知识地图：Nginx 第一阶段学了什么

```text
Nginx 第一阶段
 │
 ├── 1. Nginx 是什么                   Web 服务器 / 反向代理
 ├── 2. 安装                            yum install nginx
 ├── 3. 服务管理                        systemctl start/stop/status ...
 ├── 4. 配置文件 nginx.conf             结构、关键指令
 ├── 5. 静态网站                        root + index + 404/403 排障
 ├── 6. 配置文件语法检查                nginx -t
 ├── 7. location 匹配规则               = / ^~ / ~ / 普通前缀
 ├── 8. 反向代理                        proxy_pass
 ├── 9. 转发请求头                      proxy_set_header
 ├── 10. 日志                           access.log + error.log
 ├── 11. 故障排查                       403 / 404 / 502 / 504
 └── 12. SELinux 相关                   chcon / setsebool
```

## 2. Nginx 是什么

Nginx 是一个 Web 服务器，也可以做反向代理。

```text
Web 服务器：    浏览器请求网页 → Nginx 从磁盘读取文件 → 返回文件给浏览器
反向代理：      浏览器请求网页 → Nginx 转发给后端服务 → 后端处理完 → Nginx 返回给浏览器
```

### 一句话记住

> Nginx 要么直接返回文件（静态网站），要么转发给后端（反向代理）。

---

## 3. 安装 Nginx

```bash
sudo yum install -y epel-release
sudo yum install -y nginx
```

参数说明：

```text
yum             包管理器，从软件仓库下载并安装软件
install -y      安装软件包，-y 自动回答 yes，不需要手动确认
epel-release    EPEL 扩展仓库，Nginx 不在 CentOS 默认仓库里，需要先装它
nginx           要安装的软件包名
```

### 一句话记住

> CentOS 7 装 Nginx 要先装 EPEL 仓库，再装 nginx。

---

## 4. 服务管理（systemctl）

```bash
sudo systemctl start nginx       # 启动 Nginx
sudo systemctl stop nginx        # 停止 Nginx
sudo systemctl restart nginx     # 重启 Nginx（先停再启）
sudo systemctl reload nginx      # 重载配置（不中断服务）
sudo systemctl status nginx      # 查看 Nginx 状态
sudo systemctl enable nginx      # 开机自启
sudo systemctl disable nginx     # 取消开机自启
```

参数说明：

```text
systemctl    管理 systemd 服务的命令
start        立即启动服务
stop         立即停止服务
restart      先停止，再启动（适合改配置或重启服务）
reload       重新加载配置文件，不中断当前连接（适合改配置后用）
status       查看服务当前状态
enable       设置开机自动启动
disable      取消开机自动启动
```

查看状态时重点看：

```text
Active: active (running)      ← 服务正在运行
Active: inactive (dead)       ← 服务已停止
Loaded: loaded (...; enabled) ← 已设置开机自启
Loaded: loaded (...; disabled) ← 未设置开机自启
```

### 一句话记住

> start = 现在启动，enable = 开机自启，reload = 不中断服务地重载配置。

---

## 5. 配置文件 nginx.conf

```bash
sudo vim /etc/nginx/nginx.conf
```

查看关键配置：

```bash
sudo grep -nE "server|listen|server_name|root|index|location|proxy_pass" /etc/nginx/nginx.conf
```

参数说明：

```text
grep       文本搜索命令
-n         显示行号，方便定位到具体行
-E         使用扩展正则表达式，支持 |（或者）
"a|b|c"    匹配 a 或 b 或 c 中的任意一个
```

你当前配置的结构：

```nginx
server {
    listen       80;              # 监听 IPv4 的 80 端口
    listen       [::]:80;         # 监听 IPv6 的 80 端口
    server_name  _;               # 匹配所有域名

    root         /var/www/ops-site;   # 网站根目录

    location / {
        proxy_pass http://127.0.0.1:8080;      # 转发给后端
        proxy_set_header Host $host;           # 传递原始域名
        proxy_set_header X-Real-IP $remote_addr;  # 传递真实 IP
    }

    location = /404.html {
        # 精确匹配 /404.html，继承 root /var/www/ops-site
    }

    location = /50x.html {
        # 精确匹配 /50x.html，继承 root /var/www/ops-site
    }
}
```

关键指令解释：

```text
server { }          定义一个虚拟主机
listen 80           监听 80 端口
server_name _       匹配所有域名（默认兜底）
root /var/www/ops-site    网站根目录
index index.html    默认首页文件名
location / { }      匹配路径的规则块
proxy_pass http://...     把请求转发给后端
proxy_set_header    设置转发时携带的请求头
```

### 一句话记住

> nginx.conf 是 Nginx 的大脑，server 定义站点，location 定义规则，proxy_pass 定义转发目标。

---

## 6. 语法检查 nginx -t

修改配置文件后，先检查语法再重载：

```bash
sudo nginx -t
```

参数说明：

```text
nginx -t    test configuration，测试配置文件语法是否正确
```

可能输出：

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

看到这个说明语法正确，可以放心 reload。

如果语法错误，会提示具体哪一行有问题：

```text
nginx: [emerg] unknown directive "proxy pass" in /etc/nginx/nginx.conf:45
```

### 一句话记住

> 改完配置先 `nginx -t`，通过再 `reload`，不要直接 restart。

---

## 7. 查看端口（ss）

确认 Nginx 是否在监听端口：

```bash
ss -lntp | grep :80
```

参数说明：

```text
ss      查看网络连接/端口信息
-l      listening，只看正在监听的端口
-n      numeric，不解析服务名，直接显示端口数字
-t      TCP，只看 TCP 协议
-p      process，显示占用端口的进程名
grep :80   过滤出包含 ":80" 的行
```

预期输出：

```text
LISTEN 0 128 *:80 *:* users:(("nginx",pid=1234,fd=6))
```

各部分含义：

```text
LISTEN      正在监听状态
*:80        监听所有 IP 地址的 80 端口
nginx       这个端口被 Nginx 占用
pid=1234    进程 ID
```

### 一句话记住

> `ss -lntp` 查看所有监听端口，`grep :80` 只看 80 端口。

---

## 8. location 匹配规则

### 四种匹配类型

```text
写法              名称        优先级    含义
─────────────────────────────────────────────────
location = /xxx   精确匹配      最高     路径必须完全等于 /xxx
location ^~ /xxx  前缀停正则     高      以 /xxx 开头，命中后不再查正则
location ~ /xxx   正则匹配      中      用正则表达式匹配（区分大小写）
location /xxx     普通前缀      低      以 /xxx 开头就匹配
```

### 你的配置对应

```nginx
location = /404.html { }    ← 精确匹配，只有 /404.html 才走这条
location = /50x.html { }    ← 精确匹配，只有 /50x.html 才走这条
location / {                ← 普通前缀，所有未命中精确匹配的都走这条
    proxy_pass http://127.0.0.1:8080;
}
```

### 优先级规则

```text
请求进来
  ↓
① 精确匹配 location = /xxx      → 命中就返回，不再继续查
② 无精确匹配命中
  ↓
③ 找最长的前缀匹配
  - 如果命中 location ^~ /xxx   → 直接使用它，不再检查正则
  - 如果只是普通前缀 location /xxx → 先记住这个候选结果
  ↓
④ 检查正则匹配 location ~ /xxx
  - 如果正则命中 → 使用正则 location
  - 如果正则不命中 → 使用第 ③ 步记住的最长普通前缀
```

你当前配置里没有 `^~` 和 `~`，所以实际判断会简化成：

```text
先看 location = /404.html、location = /50x.html。
如果没有命中精确匹配，就走 location /。
```

### 继承规则

```text
location 块里没写的指令，继承 server 块的设置。

例如：
server {
    root /var/www/ops-site;          ← server 层定义

    location = /404.html { }         ← 没写 root，继承 server 的 root
}
```

### 验证命令

检查请求 /404.html 走了哪条规则：

```bash
curl -I http://192.168.6.100/404.html
```

```text
200 → 文件存在，走了 location = /404.html，从 /var/www/ops-site/404.html 返回
404 → 文件不存在，走了 location = /404.html 但找不到文件
```

### 一句话记住

> `=` 精确匹配最优先；`^~` 会阻止正则继续抢；正则 `~` 可以覆盖普通前缀；普通 `location /` 常用作兜底。

---

## 9. 反向代理（proxy_pass）

### 配置

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
}
```

### 请求流程

```text
浏览器 / curl
  → http://192.168.6.100:80          ← 访问 Nginx
  → Nginx 收到请求，匹配 location /
  → proxy_pass http://127.0.0.1:8080  ← 转发给后端
  → 后端处理（Python SimpleHTTPServer）
  → 返回响应给 Nginx
  → Nginx 返回给用户
```

### proxy_pass 参数

```text
proxy_pass          反向代理指令
http://             使用 HTTP 协议连接后端
127.0.0.1           后端地址（这里 127.0.0.1 表示本机）
8080                后端端口
;                   每条 Nginx 指令必须以分号结尾
```

### 一句话记住

> proxy_pass = Nginx 把请求转发给后端，用户访问 Nginx 的端口，Nginx 帮你转给后端处理。

---

## 10. 转发请求头（proxy_set_header）

### 为什么需要

不加 proxy_set_header 时，后端收到的请求：

```text
Host: 127.0.0.1:8080    ← 后端以为用户访问的是 127.0.0.1
X-Real-IP: 无            ← 后端不知道用户的真实 IP
```

加上后：

```text
Host: 192.168.6.100      ← 后端知道用户访问的是 192.168.6.100
X-Real-IP: 192.168.6.100 ← 后端知道用户的真实 IP
```

### 配置

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;              # 传递原始域名
    proxy_set_header X-Real-IP $remote_addr;  # 传递真实 IP
}
```

### 参数说明

```text
proxy_set_header         设置转发时添加的 HTTP 请求头
Host                     要设置的请求头名字（HTTP 的 Host 头）
$host                    Nginx 内置变量，用户请求里的域名或 IP
X-Real-IP                约定俗成的请求头名字，放用户真实 IP
$remote_addr             Nginx 内置变量，用户的真实 IP 地址
```

### 一句话记住

> proxy_set_header = 转发时把用户的信息（域名、真实 IP）原样传给后端，不让后端蒙在鼓里。

---

## 11. SELinux 相关

### 静态网站文件访问权限

```bash
sudo chcon -R -t httpd_sys_content_t /var/www/ops-site
```

参数说明：

```text
chcon                    change context，修改 SELinux 上下文
-R                       recursive，递归处理目录下所有文件
-t httpd_sys_content_t   设置类型为 Web 服务器可读取的内容类型
/var/www/ops-site        目标目录
```

### 反向代理连接后端权限

```bash
sudo setsebool -P httpd_can_network_connect on
```

参数说明：

```text
setsebool                  设置 SELinux 布尔值
-P                         persistent，持久化，重启后不丢失
httpd_can_network_connect  Nginx 能否发起网络连接（连接后端服务）
on                         开启
```

查看当前状态：

```bash
getsebool httpd_can_network_connect
```

```text
getsebool   查看 SELinux 布尔值
```

### 区别

```text
chcon                         解决 Nginx 读本地文件的问题
setsebool httpd_can_network_connect   解决 Nginx 连接后端服务的问题
```

### 一句话记住

> 403 先看 SELinux：查 `getenforce`，静态用 `chcon`，反代用 `setsebool`。

---

## 12. Firewalld 防火墙

### 查看防火墙状态

```bash
sudo firewall-cmd --state
```

### 查看当前规则

```bash
sudo firewall-cmd --list-all
```

```text
--state        查看 firewalld 是否运行（running / not running）
--list-all     查看当前 zone 的完整规则
```

### 开放 HTTP 服务（80 端口）

```bash
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
```

```text
--add-service=http    允许 HTTP 服务（80/tcp）
--permanent           写入永久配置，重启不丢失
--reload              重新加载防火墙规则
```

### 开放指定端口

```bash
sudo firewall-cmd --add-port=8080/tcp
sudo firewall-cmd --query-port=8080/tcp
```

```text
--add-port=8080/tcp   开放 8080 端口，TCP 协议
--query-port=8080/tcp 查询 8080 端口是否开放
```

### 移除规则

```bash
sudo firewall-cmd --remove-service=http
sudo firewall-cmd --remove-port=8080/tcp
```

```text
--remove-service=http    移除 HTTP 服务
--remove-port=8080/tcp   移除 8080 端口
```

### 一句话记住

> 服务监听 + 防火墙放行 + 网络可达 = 外部能访问。

---

## 13. 日志

### access.log（访问日志）

查看：

```bash
sudo tail -n 10 /var/log/nginx/access.log
```

```text
tail -n 10   查看文件末尾 10 行
```

日志格式（每列含义）：

```text
192.168.6.100 - - [08/Jul/2026:14:44:40 +0800] "GET / HTTP/1.1" 200 32 "-" "curl/7.29.0" "-"
```

逐列拆解：

```text
第 1 列：192.168.6.100             客户端 IP 地址
第 2 列：-                         标识符（未使用）
第 3 列：-                         用户名（HTTP 认证，未使用）
第 4 列：[08/Jul/2026:14:44:40 +0800]  请求时间（+0800 是东八区）
第 5 列："GET / HTTP/1.1"          请求方法 + 路径 + HTTP 协议版本
第 6 列：200                        HTTP 状态码
第 7 列：32                         返回的响应正文大小（字节）
第 8 列："-"                         Referer，从哪个页面跳过来的
第 9 列："curl/7.29.0"              User-Agent，客户端工具/浏览器
第10列："-"                          X-Forwarded-For，代理链真实 IP
```

### error.log（错误日志）

查看：

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

```text
tail -n 20   查看文件末尾 20 行
```

常见错误信息：

```text
文件不存在：      open() "/var/www/ops-site/xxx" failed (2: No such file or directory)
权限不足：        open() "/var/www/ops-site" failed (13: Permission denied)
SELinux 阻止：    connect() to 127.0.0.1:8080 failed (13: Permission denied)
后端连接失败：    connect() failed (111: Connection refused) while connecting to upstream
后端超时：        upstream timed out (110: Connection timed out) while reading response header
```

### 一句话记住

> access.log 看谁访问了什么、状态码多少；error.log 看为什么失败。

---

## 14. curl 命令

### 常用参数

```bash
curl http://192.168.6.100              # 正常访问，显示网页内容
curl -I http://192.168.6.100           # 只看响应头（HEAD 请求）
curl -v http://192.168.6.100           # 显示完整通信过程（verbose）
curl -o /dev/null -s -w "%{http_code}"  # 只获取状态码
```

参数说明：

```text
curl                    命令行 HTTP 客户端
-I                      只请求响应头（HEAD 请求），不下载正文
-v                      verbose，显示完整的请求头和响应头，包括连接过程
-o /dev/null            把响应正文写到 /dev/null（丢弃）
-s                      silent，静默模式，不显示进度条
-w "%{http_code}"       输出指定的内置变量，这里输出 HTTP 状态码
-H "Host: xxx"          自定义请求头
```

### GET 和 HEAD 的区别

```text
GET：  要完整响应（请求头 + 响应正文），curl 不加参数默认发 GET
HEAD： 只要响应头，不要正文，curl -I 发 HEAD
```

### 一句话记住

> curl 测试网站最常用：`curl -I` 看状态码，`curl -v` 看完整通信。

---

## 15. 常见故障排查

### 完整排查流程

```text
用户说网站打不开
  ↓
① 确认网络没问题
   ip addr         → 看 IP 地址
   ip route        → 看网关
   ping 192.168.6.2 → 看网关通不通
   ping 8.8.8.8    → 看外网通不通
   nslookup baidu.com → 看 DNS 解析正不正常
  ↓
② 确认 Nginx 服务正常
   sudo systemctl status nginx
   sudo ss -lntp | grep :80
  ↓
③ 确认防火墙放行
   sudo firewall-cmd --list-all
  ↓
④ 确认配置语法正确
   sudo nginx -t
  ↓
⑤ curl 测试
   curl -I http://192.168.6.100
  ↓
⑥ 看日志
   sudo tail -n 20 /var/log/nginx/error.log
   sudo tail -n 20 /var/log/nginx/access.log
```

### 403 Forbidden

```text
原因：    文件权限不足 或 SELinux 阻止
排查：
  ls -l /var/www/ops-site/              → 看文件权限
  getenforce                            → 看 SELinux 状态
  ls -Z /var/www/ops-site/              → 看 SELinux 上下文
  sudo tail -n 20 /var/log/nginx/error.log  → 看错误日志
修复：
  sudo chcon -R -t httpd_sys_content_t /var/www/ops-site
```

### 404 Not Found

```text
原因：    请求的文件或路径不存在
排查：
  curl -I http://192.168.6.100/somefile  → 看状态码
  ls -l /var/www/ops-site/              → 看文件是否存在
  sudo grep root /etc/nginx/nginx.conf   → 看 root 配置对不对
  sudo tail -n 20 /var/log/nginx/error.log  → 看错误日志
修复：
  创建缺少的文件，或修正 root 路径
```

### 502 Bad Gateway

```text
原因：    Nginx 活着，但后端服务挂了或连不上
排查：
  sudo systemctl status backend-demo     → 看后端服务状态
  sudo ss -lntp | grep :8080             → 看后端端口
  curl http://127.0.0.1:8080             → 直接测后端
  sudo tail -n 20 /var/log/nginx/error.log  → 看 error.log
      error.log 会看到：
      connect() failed (111: Connection refused) while connecting to upstream
修复：
  sudo systemctl start backend-demo      → 启动后端
```

### 504 Gateway Timeout

```text
原因：    后端活着，但处理太久，Nginx 等超时了
排查：
  sudo systemctl status backend-demo     → 看后端活着
  curl http://127.0.0.1:8080             → 直接测后端（可能很慢）
  sudo tail -n 20 /var/log/nginx/error.log  → 看 error.log
      error.log 会看到：
      upstream timed out (110: Connection timed out) while reading response header
修复：
  - 优化后端代码（处理太快一点）
  - 调大 proxy_read_timeout 配置
```

### 一句话记住

```text
403 查权限（文件 + SELinux）
404 查路径（文件 + root 配置）
502 查后端挂了（systemctl + ss + curl 后端）
504 查后端太慢（日志 + 优化代码 + 调大超时）
```

---

## 16. 面试 / 简历表达

### 简短版

```text
在 CentOS 7 上部署 Nginx 作为 Web 服务器和反向代理，配置了静态网站和
systemd 管理的后端服务，实现了 location 路径匹配规则和请求头转发，
并通过 403/404/502/504 等故障排查积累了日志分析和 SELinux 处理经验。
```

### 完整版

```text
在 CentOS 7 虚拟机上使用 Nginx 搭建 Web 服务环境，包括：

- 静态网站部署：配置 root、index、error_page，处理 403（SELinux chcon）
  和 404 等常见问题。
- 反向代理：配置 proxy_pass 将请求转发到 systemd 管理的 Python 后端服务，
  处理 SELinux httpd_can_network_connect 权限问题。
- Location 匹配：掌握精确匹配（=）、普通前缀等规则和优先级，理解
  配置继承关系。
- 请求头转发：使用 proxy_set_header 传递用户原始域名（Host）和真实 IP
  （X-Real-IP）。
- 日志分析：通过 access.log 查看访问来源和状态码，通过 error.log 排查
  各类错误。
- 故障排查：建立系统化的排查流程（IP→网关→DNS→端口→防火墙→服务→日志），
  能独立处理 403、404、502、504 四类常见 HTTP 错误。
```

### 简历关键词

```text
Nginx | 反向代理 | systemd | SELinux | 日志分析 | 故障排查 | HTTP 状态码
```

---

## 17. 必记命令速查表

```text
查看 Nginx 状态：          sudo systemctl status nginx
启动 Nginx：               sudo systemctl start nginx
停止 Nginx：               sudo systemctl stop nginx
重启 Nginx：               sudo systemctl restart nginx
重载配置：                 sudo systemctl reload nginx
检查语法：                 sudo nginx -t
查看端口：                 ss -lntp | grep :80
查看防火墙：               sudo firewall-cmd --list-all
查看访问日志：             sudo tail -n 20 /var/log/nginx/access.log
查看错误日志：             sudo tail -n 20 /var/log/nginx/error.log
HTTP 测试：                curl -I http://192.168.6.100
完整通信查看：             curl -v http://192.168.6.100
```

## 18. 核心概念一句话记住

```text
IP 找机器，端口找服务。
Nginx = Web 服务器 / 反向代理。
start = 现在启动，enable = 开机自启。
精确匹配 = 优先，location / 是兜底。
proxy_pass = 转发请求给后端。
proxy_set_header = 把用户信息传给后端。
access.log 看结果，error.log 看原因。
403 查权限，404 查路径，502 查后端挂了，504 查后端太慢。
```
