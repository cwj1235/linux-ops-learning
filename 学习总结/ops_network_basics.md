# 运维网络基础笔记

归档分类：学习总结。

适用环境：CentOS 7 虚拟机，VMware NAT 网络。

你的当前环境：

```text
Linux 用户：atguigu
主机名：centos100
系统：CentOS Linux 7
网卡：ens33
Linux IP：192.168.6.100/24
Linux 回环地址：127.0.0.1
VMware NAT 网关：192.168.6.2
Windows VMnet8：192.168.6.1
DNS：192.168.6.2
Nginx 端口：80
网站目录：/var/www/ops-site
```

## 1. IP 地址

IP 用来定位一台机器。

常见地址：

```text
127.0.0.1       本机回环地址，Linux 访问自己
192.168.6.100   你的 Linux 虚拟机地址
192.168.6.1     Windows 的 VMnet8 地址
192.168.6.2     VMware NAT 网关
8.8.8.8         Google 公共 DNS，也常用来测试外网 IP 连通性
```

一句话记住：

```text
IP 找机器，端口找服务。
```

示例：

```bash
ping -c 4 127.0.0.1
ping -c 4 192.168.6.100
ping -c 4 192.168.6.2
ping -c 4 8.8.8.8
```

参数说明：

```text
ping          测试网络是否能到达目标
-c 4          只发送 4 个 ICMP 包，避免一直 ping 下去
```

结果判断：

```text
0% packet loss     网络可达
100% packet loss   没收到回复，但不一定是网络完全不通，也可能是对方防火墙禁 ping
```

## 2. 127.0.0.1 和 192.168.6.100

`127.0.0.1` 是 loopback，意思是 Linux 自己访问自己，不经过真实网卡。

`192.168.6.100` 是你的 Linux 网卡 `ens33` 上的 IP，Windows 也能通过这个 IP 访问你的 Linux。

查看命令：

```bash
ip addr
```

常见输出重点：

```text
lo              回环网卡
inet 127.0.0.1  本机回环地址
ens33           真实网卡
inet 192.168.6.100/24  Linux 虚拟机 IP
```

## 3. 子网和 /24

`192.168.6.100/24` 里的 `/24` 是子网前缀。

在你当前环境里：

```text
192.168.6.0/24
```

大致表示：

```text
192.168.6.1 到 192.168.6.254 属于同一个网段
```

同网段可以直接通信，不同网段通常要经过网关。

示例：

```text
192.168.6.100 和 192.168.6.2     同网段
192.168.6.100 和 8.8.8.8         不同网段
```

## 4. 路由和网关

路由表决定数据包往哪里走。

查看命令：

```bash
ip route
```

你见过的核心输出：

```text
default via 192.168.6.2 dev ens33
192.168.6.0/24 dev ens33 proto kernel scope link src 192.168.6.100
```

含义：

```text
default via 192.168.6.2 dev ens33
```

如果目标地址不在本地网段，就交给 `192.168.6.2` 这个网关，从 `ens33` 出去。

```text
192.168.6.0/24 dev ens33
```

访问 `192.168.6.x` 这个网段，直接从 `ens33` 走。

查看访问某个目标会怎么走：

```bash
ip route get 192.168.6.2
ip route get 8.8.8.8
```

结果示例：

```text
192.168.6.2 dev ens33 src 192.168.6.100
8.8.8.8 via 192.168.6.2 dev ens33 src 192.168.6.100
```

解释：

```text
访问 192.168.6.2：同网段，直接走 ens33
访问 8.8.8.8：外网，先交给网关 192.168.6.2
```

一句话记住：

```text
同网段直接走，不同网段找网关。
```

## 5. DNS

DNS 的作用是把域名解析成 IP。

例如：

```text
baidu.com -> 110.242.74.102
```

查看 DNS 配置：

```bash
cat /etc/resolv.conf
```

你当前看到的是：

```text
nameserver 192.168.6.2
```

意思是：Linux 把 DNS 查询交给 VMware NAT 网关 `192.168.6.2`。

测试 DNS：

```bash
nslookup baidu.com
dig +short baidu.com
```

命令说明：

```text
nslookup     查询域名解析结果，输出比较详细
dig          更专业的 DNS 查询工具
+short       只显示简短结果，通常只显示 IP
```

故障判断：

```text
ping 8.8.8.8 能通，但 ping baidu.com 不通
```

优先怀疑 DNS。

排查命令：

```bash
cat /etc/resolv.conf
nslookup baidu.com
dig +short baidu.com
```

## 6. TCP、UDP、ICMP

常见协议：

```text
TCP   可靠连接，常用于 HTTP、SSH、MySQL、Redis
UDP   更轻量，常用于 DNS、NTP
ICMP  网络探测，ping 用的就是 ICMP
```

一句话记住：

```text
ping 通不等于网站一定通，因为 ping 是 ICMP，网站用的是 TCP 80/443。
```

## 7. 端口

端口用来定位一台机器上的具体服务。

常见端口：

```text
22/tcp     SSH
80/tcp     HTTP
443/tcp    HTTPS
3306/tcp   MySQL
6379/tcp   Redis
8080/tcp   常见后端服务端口
```

查看监听端口：

```bash
ss -lntp
```

参数说明：

```text
ss     查看 socket/网络连接
-l     listening，只看监听中的端口
-n     numeric，不把端口解析成服务名，直接显示数字
-t     TCP，只看 TCP
-p     process，显示哪个进程占用端口
```

过滤常见端口：

```bash
sudo ss -lntp | grep -E ':22|:80|:443|:3306|:6379|:8080'
```

参数说明：

```text
sudo       用管理员权限查看完整进程信息
grep       过滤文本
-E         使用扩展正则表达式
|          管道，把前一个命令输出交给后一个命令
```

结果示例：

```text
*:80        Nginx 监听所有 IPv4 地址的 80 端口
[::]:80     Nginx 监听 IPv6 的 80 端口
*:22        SSH 监听所有 IPv4 地址的 22 端口
```

## 8. curl 和 HTTP

`curl` 是命令行 HTTP 客户端，可以访问网页、查看状态码、下载文件。

查看网页内容：

```bash
curl http://192.168.6.100
```

只看响应头：

```bash
curl -I http://192.168.6.100
```

参数说明：

```text
-I     只请求响应头，不下载网页正文
```

获取状态码并丢弃正文：

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://192.168.6.100
```

参数说明：

```text
-o /dev/null        把响应正文写到 /dev/null，也就是丢弃
-s                  silent 静默模式，不显示进度条
-w "%{http_code}"   输出 curl 内置变量 http_code，也就是 HTTP 状态码
\n                  换行
```

下载文件：

```bash
curl -o local.html http://example.com/index.html
curl -O http://example.com/index.html
```

区别：

```text
-o local.html   保存成你指定的文件名
-O              使用远程服务器上的原文件名保存
```

设置连接超时：

```bash
curl -I --connect-timeout 5 http://192.168.6.100
```

参数说明：

```text
--connect-timeout 5   最多等待 5 秒建立连接
```

## 9. HTTP 状态码

常见状态码：

```text
200 OK              成功
304 Not Modified    浏览器缓存，内容没变化
403 Forbidden       禁止访问，常见原因是权限或 SELinux
404 Not Found       文件或路径不存在
500                 服务内部错误
502 Bad Gateway     Nginx 活着，但它代理的后端服务异常
504 Gateway Timeout 后端服务超时
```

判断方法：

```bash
curl -I http://192.168.6.100
curl -I http://192.168.6.100/not-exist.html
```

## 10. Nginx 基础

Nginx 是 Web 服务器，也可以做反向代理。

在你当前项目里，Nginx 做的是：

```text
接收浏览器请求 -> 根据配置找到网站目录 -> 返回 index.html
```

配置文件位置：

```text
/etc/nginx/nginx.conf
/etc/nginx/conf.d/
```

常见配置：

```nginx
server {
    listen       80;
    server_name  _;
    root         /var/www/ops-site;
    index        index.html;
    error_page 404 /404.html;
}
```

配置含义：

```text
listen 80                  监听 80 端口
server_name _              默认匹配
root /var/www/ops-site     网站根目录
index index.html           默认首页文件
error_page 404 /404.html   404 时显示的错误页面
```

检查配置语法：

```bash
sudo nginx -t
```

参数说明：

```text
-t   test configuration，测试 Nginx 配置文件语法
```

启动、停止、重启、重载：

```bash
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx
sudo systemctl status nginx
```

含义：

```text
start     启动服务
stop      停止服务
restart   重启服务，先停再启
reload    重新加载配置，通常不中断已有连接
status    查看服务状态
```

## 11. Nginx 日志

访问日志：

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

错误日志：

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

参数说明：

```text
tail       查看文件末尾内容
-n 20      查看最后 20 行
```

访问日志能看：

```text
谁访问了
访问了什么路径
返回了什么状态码
使用了什么客户端
```

错误日志能看：

```text
文件不存在
权限不足
SELinux 阻止
后端连接失败
配置问题
```

## 12. 文件和目录查看

查看目录内容：

```bash
ls -l /var/www/ops-site
```

查看目录本身：

```bash
ls -ld /var/www /var/www/ops-site
```

参数说明：

```text
-l   long，显示详细信息
-d   directory，显示目录本身，而不是目录里面的内容
```

查看 SELinux 上下文：

```bash
ls -Z /var/www/ops-site/index.html
ls -Zd /var/www/ops-site
```

参数说明：

```text
-Z   显示 SELinux context
-d   显示目录本身的 context
```

## 13. grep 过滤配置

查看 Nginx 关键配置：

```bash
sudo grep -nE "listen|server_name|root|index|error_page" /etc/nginx/nginx.conf
```

参数说明：

```text
grep       文本搜索
-n         显示行号
-E         使用扩展正则表达式
listen|root  | 表示或者，匹配 listen 或 root 等关键词
```

## 14. firewalld 防火墙

CentOS 7 默认常用 `firewalld`。

查看状态：

```bash
sudo firewall-cmd --state
```

查看当前规则：

```bash
sudo firewall-cmd --list-all
sudo firewall-cmd --list-services
sudo firewall-cmd --list-ports
```

参数说明：

```text
--state           查看 firewalld 是否运行
--list-all        查看当前 zone 的完整规则
--list-services   查看允许的服务名
--list-ports      查看直接开放的端口
```

查看服务对应端口：

```bash
sudo firewall-cmd --info-service=http
sudo firewall-cmd --info-service=ssh
```

结果：

```text
http -> 80/tcp
ssh  -> 22/tcp
```

查询服务是否开放：

```bash
sudo firewall-cmd --query-service=http
sudo firewall-cmd --query-service=ssh
```

结果：

```text
yes   已开放
no    未开放
```

临时开放 HTTP：

```bash
sudo firewall-cmd --add-service=http
```

永久开放 HTTP：

```bash
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload
```

移除 HTTP：

```bash
sudo firewall-cmd --remove-service=http
```

参数说明：

```text
--add-service=http       允许 http 服务，也就是 80/tcp
--remove-service=http    移除 http 服务
--permanent              写入永久配置
--reload                 重新加载防火墙配置
```

一句话记住：

```text
服务监听 + 防火墙放行 + 网络可达 = 外部能访问。
```

## 15. SELinux

SELinux 是 Linux 的强制访问控制机制。文件权限看起来正确时，它仍然可能阻止 Nginx 访问文件。

查看状态：

```bash
getenforce
```

状态含义：

```text
Enforcing    正在强制执行，会阻止不符合策略的访问
Permissive   只记录，不阻止
Disabled     关闭
```

临时修改：

```bash
sudo setenforce 0
sudo setenforce 1
```

含义：

```text
setenforce 0   临时切到 Permissive
setenforce 1   临时切回 Enforcing
```

永久配置文件：

```bash
/etc/selinux/config
```

常见配置：

```text
SELINUX=enforcing
SELINUX=permissive
SELINUX=disabled
```

修改网站目录 SELinux 类型：

```bash
sudo chcon -R -t httpd_sys_content_t /var/www/ops-site
```

参数说明：

```text
chcon                   change context，修改 SELinux 上下文
-R                      recursive，递归处理目录和目录下所有文件
-t httpd_sys_content_t  设置类型为 Nginx/Apache 可读取的 Web 内容类型
```

注意：

```text
-R 是大写 R，表示递归。
有些命令里 -r 也可能表示递归，但不是所有命令都一样，具体要看命令帮助。
```

## 16. VMware 网络模式

NAT：

```text
虚拟机通过 VMware NAT 网关借用 Windows 的网络上网。
适合当前学习。
```

桥接：

```text
虚拟机像局域网里的一台真实机器。
学校或公司 WiFi 下可能不稳定。
```

Host-only：

```text
虚拟机只能和宿主机通信，通常不能上外网。
```

你当前是 NAT：

```text
Windows VMnet8：192.168.6.1
VMware 网关：192.168.6.2
Linux VM：192.168.6.100
```

Linux ping Windows `192.168.6.1` 失败，不一定说明网络坏了，可能只是 Windows 防火墙不回复 ICMP。

## 17. 常见故障判断

如果 IP 能 ping 通，但 curl 网站失败：

```text
不要先查 DNS。
优先查服务、端口、防火墙。
```

命令：

```bash
sudo systemctl status nginx
sudo ss -lntp | grep :80
sudo firewall-cmd --list-all
curl -I http://192.168.6.100
```

如果 `ping 8.8.8.8` 通，但 `ping baidu.com` 不通：

```text
优先怀疑 DNS。
```

命令：

```bash
cat /etc/resolv.conf
nslookup baidu.com
dig +short baidu.com
```

如果返回 403：

```text
查权限、目录权限、SELinux、error.log。
```

命令：

```bash
ls -l /var/www/ops-site
ls -Z /var/www/ops-site/index.html
getenforce
sudo tail -n 20 /var/log/nginx/error.log
```

如果返回 404：

```text
查 root 配置、文件是否存在、error.log。
```

命令：

```bash
sudo grep -nE "root|index|error_page" /etc/nginx/nginx.conf
ls -l /var/www/ops-site
sudo tail -n 20 /var/log/nginx/error.log
```

如果返回 502：

```text
Nginx 自己活着，但代理的后端服务可能挂了。
```

排查方向：

```text
后端服务是否运行
后端端口是否监听
proxy_pass 是否写对
Nginx error.log 是否有 connect failed
```

## 18. 运维排查顺序

推荐顺序：

```text
IP -> 网关 -> DNS -> 端口 -> 防火墙 -> 服务 -> 日志
```

常用命令：

```bash
ip addr
ip route
ping -c 4 192.168.6.2
cat /etc/resolv.conf
nslookup baidu.com
sudo ss -lntp | grep :80
sudo firewall-cmd --list-all
sudo systemctl status nginx
curl -I http://192.168.6.100
sudo tail -n 20 /var/log/nginx/error.log
```
