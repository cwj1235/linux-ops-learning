# Nginx 反向代理 + systemd 后端服务笔记

归档分类：学习总结。

适用环境：CentOS 7 虚拟机 `centos100`，用户 `atguigu`，服务器 IP `192.168.6.100`。

## 1. 这节课做了什么

这节课把 Nginx 从“静态网站模式”改成了“反向代理模式”。

旧的静态网站模式：

```text
浏览器 / curl
  -> http://192.168.6.100:80
  -> Nginx
  -> /var/www/ops-site/index.html
```

新的反向代理模式：

```text
浏览器 / curl
  -> http://192.168.6.100:80
  -> Nginx
  -> proxy_pass
  -> http://127.0.0.1:8080
  -> backend-demo.service
  -> /opt/backend-demo/index.html
```

一句话记住：

```text
Nginx 反向代理 = 用户访问 Nginx，Nginx 再把请求转发给后端服务。
```

## 2. 核心概念

### 2.1 Nginx

Nginx 是网站入口。它既可以直接返回静态文件，也可以把请求转发给后端服务。

常见作用：

```text
静态 Web 服务器
反向代理
负载均衡
HTTPS 入口
```

这节课里，Nginx 用作反向代理。

### 2.2 后端服务

后端服务就是 Nginx 后面真正提供业务内容的程序。

这次练习里，后端服务是 Python 2 的简单 HTTP 服务：

```bash
/usr/bin/python -m SimpleHTTPServer 8080
```

它监听 `8080` 端口。

### 2.3 127.0.0.1

`127.0.0.1` 表示“当前这台机器自己”，但要看它在哪里使用。

```text
Windows 浏览器访问 127.0.0.1 -> Windows 自己
Linux 终端访问 127.0.0.1 -> Linux 虚拟机自己
Nginx 配置里写 127.0.0.1 -> 运行 Nginx 的这台 Linux 虚拟机
```

所以这段配置：

```nginx
proxy_pass http://127.0.0.1:8080;
```

意思是：

```text
Nginx 把请求转发到同一台 Linux 虚拟机的 8080 端口。
```

## 3. 后端目录

创建后端工作目录：

```bash
sudo mkdir -p /opt/backend-demo
sudo chown -R atguigu:atguigu /opt/backend-demo
echo "Hello from systemd backend 8080" > /opt/backend-demo/index.html
ls -l /opt/backend-demo
```

### 3.1 命令解释

```bash
sudo mkdir -p /opt/backend-demo
```

创建 `/opt/backend-demo` 目录。

`-p` 的意思：

```text
如果上级目录不存在，就一起创建；如果目录已经存在，也不报错。
```

```bash
sudo chown -R atguigu:atguigu /opt/backend-demo
```

修改目录的所有者和所属组。

```text
chown      修改所有者
-R         递归处理目录和目录里的所有内容
atguigu    所有者用户
atguigu    所属组
```

```bash
echo "Hello from systemd backend 8080" > /opt/backend-demo/index.html
```

把内容写入 `index.html`。

`>` 表示覆盖写入或创建文件。

## 4. 端口检查

启动服务前，要先确认 `8080` 端口有没有被占用：

```bash
ss -lntp | grep :8080
```

示例输出：

```text
LISTEN 0 5 *:8080 *:* users:(("python",pid=6451,fd=3))
```

含义：

```text
LISTEN       有服务正在监听
*:8080       8080 端口监听在所有 IPv4 地址上
python       占用端口的进程名
pid=6451     进程号
```

查看进程详情：

```bash
ps -fp 6451
```

语法：

```text
ps       查看进程状态
-f       full format，显示完整格式
-p 6451  查看 PID 为 6451 的进程
```

停止旧的前台 Python 进程：

```bash
kill 6451
```

再检查：

```bash
ss -lntp | grep :8080
```

没有输出，说明 `8080` 端口已经空出来。

## 5. systemd 服务文件

服务文件路径：

```bash
/etc/systemd/system/backend-demo.service
```

文件内容：

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

### 5.1 Unit 部分

```ini
[Unit]
Description=Backend Demo Python HTTP Server
After=network.target
```

`[Unit]` 保存服务的基本信息。

```text
Description    服务描述，给人看的
After          表示在某个 target/service 之后启动
network.target 基础网络环境
```

### 5.2 Service 部分

```ini
[Service]
Type=simple
User=atguigu
WorkingDirectory=/opt/backend-demo
ExecStart=/usr/bin/python -m SimpleHTTPServer 8080
Restart=always
RestartSec=3
```

`[Service]` 定义服务怎么运行。

```text
Type=simple
```

表示 `ExecStart` 启动的进程就是主进程。Python SimpleHTTPServer 适合这种类型。

```text
User=atguigu
```

表示用 `atguigu` 用户运行服务，不用 root 跑。

```text
WorkingDirectory=/opt/backend-demo
```

启动命令前，systemd 先进入这个目录。

这很重要，因为 Python SimpleHTTPServer 会把当前目录当成网站目录。

```text
ExecStart=/usr/bin/python -m SimpleHTTPServer 8080
```

真正的启动命令。

大致等价于：

```bash
cd /opt/backend-demo
/usr/bin/python -m SimpleHTTPServer 8080
```

```text
Restart=always
```

服务退出后，systemd 自动重启它。

```text
RestartSec=3
```

服务退出后等 3 秒再重启。

### 5.3 Install 部分

```ini
[Install]
WantedBy=multi-user.target
```

用于开机自启动。

`multi-user.target` 可以理解为 Linux 正常的多用户命令行运行状态。

## 6. systemctl 常用命令

创建或修改 `.service` 文件后，先执行：

```bash
sudo systemctl daemon-reload
```

含义：

```text
让 systemd 重新读取服务配置文件。
```

启动服务：

```bash
sudo systemctl start backend-demo
```

查看服务状态：

```bash
sudo systemctl status backend-demo
```

重点看：

```text
Active: active (running)
```

设置开机自启动：

```bash
sudo systemctl enable backend-demo
```

设置后，`status` 里应该能看到：

```text
Loaded: loaded (...; enabled; ...)
```

几个命令的区别：

```text
start    现在启动
enable   开机自动启动
stop     现在停止
disable  取消开机自动启动
status   查看状态
```

## 7. Nginx 反向代理配置

配置文件：

```bash
/etc/nginx/nginx.conf
```

搜索关键配置：

```bash
sudo grep -nE "server|listen|server_name|root|index|location|proxy_pass" /etc/nginx/nginx.conf
```

语法解释：

```text
grep        搜索文本
-n          显示行号
-E          使用扩展正则表达式
"a|b|c"     匹配 a 或 b 或 c
```

关键配置：

```nginx
root /var/www/ops-site;

location / {
    proxy_pass http://127.0.0.1:8080;
}
```

### 7.1 location

```nginx
location / {
    ...
}
```

意思是：

```text
当请求路径以 / 开头时，使用这个配置块。
```

几乎所有 URL 路径都以 `/` 开头，所以 `location /` 常用作兜底规则。

### 7.2 proxy_pass

```nginx
proxy_pass http://127.0.0.1:8080;
```

意思是：

```text
把匹配到的请求转发给后端 http://127.0.0.1:8080。
```

语法拆解：

```text
proxy_pass  Nginx 反向代理指令
http://     使用 HTTP 协议
127.0.0.1   后端主机，也就是这台 Linux 虚拟机自己
8080        后端端口
;           Nginx 指令必须用分号结尾
```

### 7.3 root 和 proxy_pass 同时存在

如果同时存在：

```nginx
root /var/www/ops-site;

location / {
    proxy_pass http://127.0.0.1:8080;
}
```

对于匹配 `location /` 的请求，`proxy_pass` 会接管处理，Nginx 会转发到后端，而不是从 `root` 目录读文件。

`root` 仍然可能被其他 location、错误页、静态文件路径使用。

## 8. SELinux 问题

之前静态文件 403 的修复命令：

```bash
sudo chcon -R -t httpd_sys_content_t /var/www/ops-site
```

它解决的是 Nginx 读取 `/var/www/ops-site` 文件的问题。

含义：

```text
chcon                 修改 SELinux 上下文
-R                    递归处理
-t                    设置 SELinux 类型
httpd_sys_content_t   Web 服务允许读取的文件类型
/var/www/ops-site     目标路径
```

反向代理时遇到的 SELinux 问题：

```bash
getsebool httpd_can_network_connect
sudo setsebool -P httpd_can_network_connect on
```

含义：

```text
getsebool                       查看 SELinux 布尔开关
setsebool                       设置 SELinux 布尔开关
-P                              持久生效，重启后仍然有效
httpd_can_network_connect       允许 Nginx/httpd 类型服务连接网络后端
on                              开启
```

区别：

```text
chcon 修的是“读取本地文件”的权限。
setsebool httpd_can_network_connect 修的是“连接后端网络服务”的权限。
```

## 9. firewalld 相关点

如果 Windows 直接访问：

```text
http://192.168.6.100:8080
```

Linux 防火墙必须允许 `8080/tcp`：

```bash
sudo firewall-cmd --add-port=8080/tcp
sudo firewall-cmd --query-port=8080/tcp
```

关闭 `8080/tcp`：

```bash
sudo firewall-cmd --remove-port=8080/tcp
sudo firewall-cmd --query-port=8080/tcp
```

但是在反向代理场景里：

```text
外部用户通常只需要访问 Nginx 的 80/443。
后端 8080 不需要直接暴露给用户。
```

## 10. 验证命令

直接检查后端：

```bash
curl http://127.0.0.1:8080
```

预期结果：

```text
Hello from systemd backend 8080
```

检查 Nginx 反向代理：

```bash
curl http://192.168.6.100
```

预期结果：

```text
Hello from systemd backend 8080
```

检查端口：

```bash
ss -lntp | grep :8080
```

检查 Nginx 配置语法：

```bash
sudo nginx -t
```

查看 Nginx 日志：

```bash
sudo tail -n 10 /var/log/nginx/access.log
sudo tail -n 10 /var/log/nginx/error.log
```

## 11. 502 故障排查

我们模拟过后端故障：

```bash
sudo systemctl stop backend-demo
curl -I http://192.168.6.100
```

结果：

```text
HTTP/1.1 502 Bad Gateway
```

错误日志：

```text
connect() failed (111: Connection refused) while connecting to upstream
upstream: "http://127.0.0.1:8080/"
```

含义：

```text
Nginx 自己是活的。
Nginx 想连接后端 127.0.0.1:8080。
backend-demo 已经被停止。
8080 端口没有服务接收连接。
所以 Nginx 返回 502。
```

排查流程：

```text
用户访问出现 502
  -> 检查 Nginx 状态
  -> 检查后端服务状态
  -> 检查后端 8080 端口
  -> 查看 Nginx error.log
  -> 启动后端服务
  -> 再次测试访问
```

命令：

```bash
sudo systemctl status nginx
sudo systemctl status backend-demo
ss -lntp | grep :8080
sudo tail -n 20 /var/log/nginx/error.log
sudo systemctl start backend-demo
curl http://192.168.6.100
```

一句话记住：

```text
502 = Nginx 在运行，但后端/upstream 挂了或连不上。
```

## 12. 当前最终状态

当前成功状态：

```text
backend-demo.service：enabled，并且 active (running)
Nginx：把 80 端口请求转发到 127.0.0.1:8080
curl http://192.168.6.100 返回 Hello from systemd backend 8080
```

当前重要文件：

```text
/etc/nginx/nginx.conf
/etc/systemd/system/backend-demo.service
/opt/backend-demo/index.html
/var/log/nginx/access.log
/var/log/nginx/error.log
```

## 13. 面试 / 简历表达

可以这样描述这个项目：

```text
在 CentOS 7 环境中搭建 Nginx 反向代理练习环境，使用 systemd 管理后端服务，通过 proxy_pass 将 80 端口请求转发到 8080 后端服务；处理 SELinux 对反向代理连接的限制，使用 curl、ss、systemctl 和 Nginx 日志完成服务验证，并模拟 502 Bad Gateway 故障进行日志排查和服务恢复。
```

简短版本：

```text
完成 Nginx 反向代理到 systemd 后端服务的配置，并实践 502 upstream 故障排查。
```

## 14. 必须记住

```text
start 表示现在启动。
enable 表示开机自启动。
proxy_pass 表示转发请求。
502 通常表示后端服务有问题。
error.log 能说明 Nginx 为什么失败。
```
