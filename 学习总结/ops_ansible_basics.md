# Ansible 自动化部署学习记录

当前属于阶段 5：Ansible 自动化部署。

## 一、安装与本机连通性（已完成）

### 环境检查

```bash
ansible --version
python3 --version
yum repolist enabled | grep -iE 'epel|ansible'
```

关键结果：

```text
bash: ansible: 未找到命令...
Python 3.6.8
epel/x86_64  Extra Packages for Enterprise Linux 7 - x86_64
```

结论：

- Ansible 未安装。
- Python 3.6.8 可用。
- EPEL 源已启用。

### 安装 Ansible

```bash
sudo yum install -y ansible
```

安装后版本：

```bash
ansible --version
```

关键结果：

```text
ansible 2.9.27
config file = /etc/ansible/ansible.cfg
python version = 2.7.5
```

说明：

- 本机使用的是 CentOS 7 EPEL 源里的 Ansible 2.9.27。
- Ansible 2.9.27 使用的 Python 解释器是系统 Python 2.7.5。

### 本机连通性测试

在 `/root` 目录执行时出现：

```text
OSError: [Errno 13] Permission denied: '.'
```

原因是当前目录权限不允许 Ansible 正常访问，不是 Ansible 安装失败。

切换到用户家目录后执行：

```bash
cd /home/atguigu
ansible localhost -m ping
```

关键结果：

```text
localhost | SUCCESS => changed=false, ping=pong
```

结论：

- Ansible 控制端正常。
- 本机作为受管节点正常。
- `ping` 模块返回 `pong`，说明本机链路可用。

## 二、Inventory 主机清单（已完成）

### 创建练习目录

```bash
mkdir -p ~/ansible-practice
cd ~/ansible-practice
```

### 创建 inventory.ini

```ini
[local]
localhost ansible_connection=local
```

解释：

- `[local]`：主机组名。
- `localhost`：受管主机名。
- `ansible_connection=local`：使用本地连接，不通过 SSH。

### 查看 Inventory 解析结果

```bash
ansible-inventory -i inventory.ini --list
```

关键结果：

```text
localhost 的 hostvars 包含 ansible_connection=local
all 包含 local 和 ungrouped
local 包含 localhost
```

结论：

- `localhost` 被加入 `local` 组。
- `ansible_connection=local` 正确生效。
- `all` 组包含 `local` 和 `ungrouped`。

### 使用 Inventory 执行 ping

```bash
ansible local -i inventory.ini -m ping
```

关键结果：

```text
localhost | SUCCESS => discovered_interpreter_python=/usr/bin/python, changed=false, ping=pong
```

结论：

- `local` 组匹配成功。
- Inventory 文件使用成功。
- Ansible 使用的 Python 解释器为 `/usr/bin/python`。

### 使用 setup 模块收集系统信息

```bash
ansible local -i inventory.ini -m setup -a 'filter=ansible_distribution*'
```

关键结果：

```text
ansible_distribution: CentOS
ansible_distribution_file_parsed: true
ansible_distribution_file_path: /etc/redhat-release
ansible_distribution_file_variety: RedHat
ansible_distribution_major_version: 7
ansible_distribution_release: Core
ansible_distribution_version: 7.9
```

结论：

- `setup` 模块可收集受管主机 facts。
- `filter=ansible_distribution*` 只筛选发行版相关信息。
- 本机识别为 CentOS 7.9。

## 三、Ad-hoc 命令（已完成）

Ad-hoc 命令用于临时执行单个任务，不写成 Playbook。

### command 模块

```bash
ansible local -i inventory.ini -m command -a 'pwd'
```

关键结果：

```text
/home/atguigu/ansible-practice
```

结论：`command` 模块可在受管主机上执行普通命令。

### file 模块创建目录

第一次执行：

```bash
ansible local -i inventory.ini -m file \
  -a 'path=/home/atguigu/ansible-practice/adhoc state=directory mode=0755'
```

关键结果：

```text
changed=true
state=directory
mode=0755
owner=atguigu
group=atguigu
```

第二次执行同一条命令：

```text
changed=false
state=directory
mode=0755
```

结论：

- 第一次创建目录，状态变为 `changed=true`。
- 第二次目录已存在且权限正确，状态为 `changed=false`。
- 这就是 Ansible 的幂等性。

### copy 模块写入文件

第一次执行：

```bash
ansible local -i inventory.ini -m copy \
  -a 'content="ansible adhoc ok" dest=/home/atguigu/ansible-practice/adhoc/hello.txt mode=0644'
```

关键结果：

```text
changed=true
dest=/home/atguigu/ansible-practice/adhoc/hello.txt
mode=0644
size=16
```

第二次执行同一条命令：

```text
changed=false
checksum=7d408a1de12b84b6b768b0ab9f1818a434d23a0b
mode=0644
size=16
```

结论：

- 第一次创建文件并写入内容。
- 第二次内容一致，不再修改，返回 `changed=false`。
- `checksum` 用于判断文件内容是否一致。

### 读取文件内容

```bash
ansible local -i inventory.ini -m command \
  -a 'cat /home/atguigu/ansible-practice/adhoc/hello.txt'
```

关键结果：

```text
ansible adhoc ok
```

### stat 模块检查文件状态

```bash
ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/adhoc/hello.txt'
```

关键结果：

```text
exists=true
isreg=true
mode=0644
readable=true
writeable=true
executable=false
```

结论：

- 文件存在。
- 是普通文件。
- 权限为 `0644`。
- 属主可读写，其他用户只读。

### 清理练习目录

```bash
ansible local -i inventory.ini -m file \
  -a 'path=/home/atguigu/ansible-practice/adhoc state=absent'
```

关键结果：

```text
changed=true
state=absent
```

确认删除：

```bash
ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/adhoc'
```

关键结果：

```text
exists=false
```

本节结论：

- `command` 适合执行简单命令。
- `file` 适合管理目录、文件和权限。
- `copy` 适合写入文件内容。
- `stat` 适合检查文件是否存在及其属性。
- `changed=true/false` 可判断操作是否真正改变了系统状态。
- 本节 Ad-hoc 命令验证和清理已完成，不需要重做。

## 四、Playbook 基础（已完成）

Playbook 用于把多个任务按顺序写成一个 YAML 剧本，实现可重复执行。

### 创建 site.yml

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

解释：

- `hosts: local`：对 inventory 中的 `local` 组执行。
- `connection: local`：使用本地连接。
- `gather_facts: false`：本任务不需要收集系统 facts，可加快执行。
- `vars`：定义变量。
- `tasks`：任务列表，按顺序执行。
- `file`：创建目录。
- `copy`：写入文件。
- `command`：读取文件内容。
- `register`：把命令结果保存到变量。
- `changed_when: false`：声明该读取命令不改变系统状态。
- `debug`：输出变量内容。

### 语法检查

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
```

关键结果：

```text
playbook: site.yml
```

结论：YAML 语法和 Playbook 结构检查通过。

### 第一次执行

```bash
ansible-playbook -i inventory.ini site.yml
```

关键结果：

```text
TASK [Create practice directory] changed
TASK [Create practice file] changed
TASK [Read practice file] ok
TASK [Show practice file content] ok
file_content.stdout = ansible playbook ok

PLAY RECAP
ok=4
changed=2
unreachable=0
failed=0
```

结论：目录和文件第一次被创建，所以两个任务为 `changed`。

### 第二次执行，验证幂等性

```bash
ansible-playbook -i inventory.ini site.yml
```

关键结果：

```text
TASK [Create practice directory] ok
TASK [Create practice file] ok
TASK [Read practice file] ok
TASK [Show practice file content] ok

PLAY RECAP
ok=4
changed=0
unreachable=0
failed=0
```

结论：

- 第二次执行时目录已存在、文件内容一致。
- `changed=0` 说明 Playbook 具备幂等性。
- 重复执行不会重复修改系统状态。

### 检查文件状态

```bash
ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/playbook-demo/hello.txt'
```

关键结果：

```text
exists=true
isreg=true
mode=0644
size=20
readable=true
writeable=true
executable=false
```

结论：文件存在，是普通文件，权限为 `0644`。

### 清理练习目录

```bash
ansible local -i inventory.ini -m file \
  -a 'path=/home/atguigu/ansible-practice/playbook-demo state=absent'
```

关键结果：

```text
changed=true
state=absent
```

确认删除：

```bash
ansible local -i inventory.ini -m stat \
  -a 'path=/home/atguigu/ansible-practice/playbook-demo'
```

关键结果：

```text
exists=false
```

本节结论：

- Playbook 可以把多个任务组织成可重复执行的剧本。
- `--syntax-check` 只检查语法，不执行任务。
- `changed=2` 表示第一次实际创建了目录和文件。
- `changed=0` 表示第二次执行没有实际变更，幂等性正常。
- 本节 Playbook 基础验证和清理已完成，不需要重做。

## 五、变量和模板（已完成）

### 变量来源与优先级

```text
inventory 主机变量：inventory.ini 里的 ansible_connection=local
playbook 变量：剧本 vars 段里的 app_port: 18090
运行期变量：facts（如 ansible_distribution）和 register 注册的返回值
命令行变量：执行时用 -e "app_port=18091"
```

优先级从低到高：inventory/facts -> playbook `vars:` -> 命令行 `-e`。越靠近执行现场，优先级越高。

### 未定义变量会直接失败

```bash
cd /home/atguigu/ansible-practice
ansible local -i inventory.ini -m debug -a "msg={{ app_port }}" -e "app_port=18090"
ansible local -i inventory.ini -m debug -a "msg={{ app_port }}"
```

关键结果：

```text
localhost | SUCCESS => { "msg": "18090" }
localhost | FAILED! => { "msg": "The task includes an option with an undefined variable. The error was: 'app_port' is undefined" }
```

结论：

- `-e` 现场传入的变量能正常渲染。
- 不传变量时 Ansible 直接 `FAILED!`，不会代之以空字符串；在自动化脚本里这表现为非 0 退出码。
- YAML 中以 `{{` 开头的值必须加引号，例如 `config_file: "{{ practice_dir }}/app.conf"`。

### 模板文件与 Playbook

`templates/app.conf.j2`：

```ini
# Managed by Ansible
app_name={{ app_name }}
app_port={{ app_port }}
app_owner={{ app_owner }}
```

`vars-template.yml` 关键结构：

```yaml
vars:
  app_name: demo-app
  app_port: 18090
  app_owner: atguigu
  practice_dir: /home/atguigu/ansible-practice/template-demo
  config_file: "{{ practice_dir }}/app.conf"

tasks:
  - file 模块：path={{ practice_dir }} state=directory mode='0755'
  - template 模块：src=templates/app.conf.j2 dest={{ config_file }} mode='0644'
  - command 模块：cat {{ config_file }}，register 到 app_config，changed_when: false
  - debug 模块：var=app_config.stdout
```

要点：

- 模板文件放在 playbook 同级的 `templates/` 目录；`src` 和 `-i` 都是相对路径，执行前先 `cd ~/ansible-practice`。
- `mode` 的值加引号，避免 YAML 把 `0644` 当数字处理。
- `changed_when: false` 让只读的 `cat` 任务不计入 changed。
- heredoc 写成 `<<'EOF'`（EOF 带单引号），`{{ }}` 才会原样写入并交给 Jinja2。

### 渲染、幂等与变量覆盖

```bash
ansible-playbook -i inventory.ini vars-template.yml --syntax-check
ansible-playbook -i inventory.ini vars-template.yml
cat /home/atguigu/ansible-practice/template-demo/app.conf
ansible-playbook -i inventory.ini vars-template.yml
ansible-playbook -i inventory.ini vars-template.yml -e "app_port=18091"
ansible-playbook -i inventory.ini vars-template.yml -e "app_port=18091"
```

关键结果：

```text
语法检查          : playbook: vars-template.yml
第一次            : ok=4 changed=2   建目录 + 渲染模板
第二次            : ok=4 changed=0   内容一致，不重复写入
-e 18091 第一次   : ok=4 changed=1   只有配置文件内容变化
-e 18091 第二次   : ok=4 changed=0   同一组变量值重复执行不再变更
```

`cat` 结果：

```ini
# Managed by Ansible
app_name=demo-app
app_port=18090
app_owner=atguigu
```

### 小节结论

- `template` 模块 = `copy` + 变量替换：读 `.j2` 模板、渲染、写到 `dest`。
- 幂等性由 checksum 比对保证，同一组变量值重复执行返回 `changed=0`。
- `--syntax-check` 不校验 Jinja2 模板内容，模板写错要到真正执行时才暴露。
- `debug: var=` 的输出把换行显示成 `\n`，看起来挤成一行属正常；要看真实文件内容用 `cat`。
- `template-demo` 是本节练习产物，收尾时用 `file` 模块 `state=absent` 删除。
- 本节不要重做。

## 六、handlers（已完成）

### 概念

- `notify` 写在任务里，写的是 handler 的**名字**，名字必须和 handler 完全一致；写错不报错，但永远不触发。
- `handlers` 是单独一段，只有任务报 `changed` 且 notify 了它时才入队。
- handler 在整个 play 的所有 task 跑完之后才执行；多个任务 notify 同一个 handler 只执行一次。
- 任务 `changed=false` 时不入队，handler 完全不执行，输出里也不会出现 `RUNNING HANDLER` 段落。
- 前面的任务失败时 handler 默认不执行，除非加 `--force-handlers`；想在 play 中途触发要用 `meta: flush_handlers`。

### 练习 Playbook

`handlers-demo.yml` 关键结构：

```yaml
tasks:
  - file 模块：创建 {{ practice_dir }} 目录
  - template 模块：渲染 app.conf，并 notify: write handler log
  - debug 模块：打印 "config prepared: {{ config_file }}"

handlers:
  - name: write handler log
    shell: "echo handler triggered >> {{ practice_dir }}/handler.log"
```

### 执行结果

```text
第一次（建目录 + 渲染）    : ok=4 changed=3，出现 RUNNING HANDLER [write handler log]
第二次（无任何改动）      : ok=3 changed=0，完全不出现 RUNNING HANDLER
第三次（-e app_port=18092）: ok=4 changed=2，handler 再次触发
修好重定向后重跑          : handler.log 出现第 1 行
无改动再跑一次            : ok=3 changed=0，无 handler
-e app_port=18091         : ok=4 changed=2，handler 触发，handler.log 累计 2 行
```

### command 与 shell 的重定向差异（本节排查结论）

最初用 `command` 写日志时，handler 报 `changed` 但文件不存在。对照实验：

```bash
ansible local -i inventory.ini -m command -a 'echo command测试 >> /home/atguigu/ansible-practice/redir-command.txt'
ansible local -i inventory.ini -m shell   -a 'echo shell测试 >> /home/atguigu/ansible-practice/redir-shell.txt'
```

关键结果：

```text
command：stdout 原样输出 "command测试 >> /home/atguigu/ansible-practice/redir-command.txt"，redir-command.txt 不存在
shell  ：redir-shell.txt 生成，12 字节，内容为 shell测试
```

结论：

- `command` 模块不经过 shell，`>>`、`|`、`;` 会被当成普通参数，重定向不生效，但退出码仍为 0，所以任务照样报 `changed`。
- `shell` 模块经过 shell，重定向生效。
- **`changed` 只表示任务执行过了，不证明副作用真的发生**；要确认结果必须自己查文件、状态或日志。

### 小节结论

- handler 的触发条件是「任务真的改了系统」，不是「任务里写了 notify」。
- 判断 handler 有没有执行，看输出里有没有 `RUNNING HANDLER` 段落，而不是看 handler 自己的 changed。
- 生产里 handler 应使用模块（例如 `systemd: name=nginx state=reloaded`），不要用 shell 重定向。
- 本节不要重做。

## 七、handler 对接真实服务：Nginx reload（已完成）

### 目标

把上一节「往日志文件追加一行」换成真实生产动作：模板渲染出的 nginx 配置文件发生变化时，用 `systemd` 模块 reload Nginx，并验证「配置没变就不 reload」。

### 练习文件

`templates/ops-handler-demo.conf.j2`：

```nginx
# Managed by Ansible: handlers practice

server {
    listen 127.0.0.1:{{ nginx_demo_port }};
    server_name _;

    location / {
        default_type text/plain;
        return 200 "handler demo ok, version={{ demo_version }}";
    }
}
```

`handlers-nginx.yml` 关键结构：

```yaml
become: true

vars:
  nginx_demo_port: 18099
  demo_version: 1
  demo_conf: /etc/nginx/conf.d/ops-handler-demo.conf

tasks:
  - template 模块：渲染到 {{ demo_conf }}，并 notify: reload nginx
  - command 模块：/usr/sbin/nginx -t，register: nginx_test，changed_when: false
  - debug 模块：打印 nginx_test.stderr_lines

handlers:
  - name: reload nginx
    systemd:
      name: nginx
      state: reloaded
```

要点：

- `become: true` 必须加（写 `/etc/nginx/conf.d/` 需要 root）；本机 `sudo` 需要密码，所以执行时带 `-K`。
- `command` 模块不经过 shell、不读 `PATH`，要写绝对路径 `/usr/sbin/nginx -t`。
- `nginx -t` 只做检查、不改系统，所以加 `changed_when: false`，避免每次误报 `changed`。
- `nginx -t` 的输出走 stderr，所以看 `stderr_lines` 而不是 `stdout`。

### 现象：reload 执行了，但服务不生效

`ok=4 changed=2`，`RUNNING HANDLER [reload nginx]` 正常出现，`nginx -t` 输出 `syntax is ok` / `test is successful`。但是：

```text
ss -lntp | grep 18099            -> 无输出
curl -sS http://127.0.0.1:18099  -> curl: (7) Failed connect ... 拒绝连接
pgrep -a nginx                   -> worker 仍是 1316-1319，一个都没换
```

### 排查过程（按序排除）

1. `ls -Z /etc/nginx/conf.d/ops-handler-demo.conf` → `root root 0644 system_u:object_r:httpd_config_t:s0`，权限和文件上下文都正常，**排除文件侧**。
2. `sudo tail -n 30 /var/log/nginx/error.log` → 决定性证据：

```text
2026/09/17 12:32:02 [notice] 8410#8410: signal process started
2026/09/17 12:32:02 [emerg] 1314#1314: bind() to 127.0.0.1:18099 failed (13: Permission denied)
```

3. `sudo semanage port -l | grep http_port_t` → 白名单里没有 18099：

```text
http_port_t   tcp   80, 81, 443, 488, 8008, 8009, 8443, 9000
```

4. `sudo grep name_bind /var/log/audit/audit.log | tail -n 3` → SELinux 原始拒绝记录：

```text
type=AVC msg=audit(1789619522.576:633): avc: denied { name_bind } for pid=1314 comm="nginx" src=18099 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```

字段含义：

- `{ name_bind }`：被拒的动作是绑定端口。
- `pid=1314 comm="nginx"`：与 error.log 里的 `1314#1314` 是同一个 master 进程。
- `scontext=...:httpd_t:s0`：主体，nginx 进程所在的 SELinux 域。
- `tcontext=...:unreserved_port_t:s0`：客体，18099 的端口标签是「未预留端口」。
- `tclass=tcp_socket`：客体类别；`permissive=0`：强制（enforcing）模式，直接拒绝。

### 根因

SELinux 策略里本来就有这条规则：

```text
allow httpd_t http_port_t:tcp_socket name_bind;
```

它表示 `httpd_t` 域只能绑定带 `http_port_t` 标签的 TCP 端口。18099 的标签是 `unreserved_port_t`，匹配不上这条 allow，落到默认拒绝，`bind()` 返回 `EACCES`。master 于是放弃新配置、继续用旧配置服务，端口从未被监听。

关键判断：**nginx 以 root 运行，root 绑端口不受「1024 以下需特权」限制；root 还能拿到 EACCES，基本只剩 SELinux。**

还要记住：`nginx -t` 只校验语法，不校验端口能否绑定；`reload` 的退出码只反映信号是否发出，不反映新配置是否生效。

### 对照实验（证明是端口问题）

```bash
ansible-playbook -i inventory.ini handlers-nginx.yml -e "nginx_demo_port=8008" -K
ss -lntp | grep 8008 ; curl -sS http://127.0.0.1:8008 ; echo ; pgrep -a nginx
```

```text
LISTEN     0      511    127.0.0.1:8008
handler demo ok, version=1
1314 nginx: master process /usr/sbin/nginx
8809 / 8810 / 8812 / 8813 nginx: worker process
```

模板和 playbook 一个字没改，8008 通、18099 不通 → **SELinux 端口白名单实锤**。另外 master 仍是 1314、worker 全部换新 PID，证明走的是 **reload（热加载）而不是 restart**。

### 修复（生产标准做法）

```bash
sudo semanage port -a -t http_port_t -p tcp 18099
sudo semanage port -l | grep http_port_t
ansible-playbook -i inventory.ini handlers-nginx.yml -K
ss -lntp | grep 18099 ; curl -sS http://127.0.0.1:18099 ; echo ; pgrep -a nginx
```

```text
http_port_t  tcp  18099, 80, 81, 443, 488, 8008, 8009, 8443, 9000
LISTEN     0      511    127.0.0.1:18099
handler demo ok, version=1
1314 nginx: master process /usr/sbin/nginx
9088 / 9089 / 9090 / 9091 nginx: worker process
```

同一个配置文件，从「拒绝连接」变成「正常响应」，唯一变化是端口标签，因果链闭合。

### 三种处理方式

- 换白名单内端口（8008、81、9000……）：零副作用，但等于让业务迁就 SELinux；生产上端口常由上游、防火墙或监控约定，不能随便改。
- `sudo semanage port -a -t http_port_t -p tcp <端口>`：**生产标准做法**，让策略认可业务端口。`-a` 加、`-m` 改、`-d` 删。
- `sudo setenforce 0`：临时切到 permissive，**只能用来一次性确认「是不是 SELinux 的锅」**，确认后必须切回 `Enforcing`，不能留在环境里。

### 命令语法小结

```bash
pgrep -a nginx          # -a 打印完整命令行；不加只输出 PID 数字
                        # 退出码：找到返回 0，没找到返回 1，可直接用于 shell 判断
semanage <对象> <动作>   # 对象如 port / fcontext / boolean；动作 -l 列、-a 加、-m 改、-d 删
                        # -t 指定 SELinux 类型标签，-p 指定协议
curl -sS                # -s 静默；-S 在静默下依然打印错误，排查时必须写 -sS
```

`semanage` 改的是**策略存储**（持久生效），`chcon` 只改单个文件标签（临时，会被 `restorecon` 覆盖）。正经修复用 `semanage`。

### 收尾清理与最终状态

```bash
ansible local -i inventory.ini -b -K -m file -a 'path=/etc/nginx/conf.d/ops-handler-demo.conf state=absent'
ansible local -i inventory.ini -b -K -m systemd -a 'name=nginx state=reloaded'
ss -lntp | grep 18099 ; curl -sS http://127.0.0.1:18099 ; echo ; pgrep -a nginx
ansible local -i inventory.ini -m file -a 'path=/home/atguigu/ansible-practice/redir-shell.txt state=absent'
ansible local -i inventory.ini -m file -a 'path=/home/atguigu/ansible-practice/handlers-demo state=absent'
sudo semanage port -d -t http_port_t -p tcp 18099
```

```text
file 删练习配置    ：changed=true
systemd reload    ：changed=true，MainPID 仍 1314
                     ExecReload = /usr/sbin/nginx -s reload（pid=9087，code=exited，status=0）
删除后验证         ：ss 无输出；curl 拒绝连接（预期，服务已被主动撤掉）
                     master 仍 1314；worker 换为 9563-9566
删 redir-shell.txt ：changed=false（此前就已经不存在，幂等的 no-op）
删 handlers-demo/  ：changed=true
semanage port -d   ：无输出（撤销成功，18099 恢复为 unreserved_port_t）
```

三个额外收获：

- `systemd` 模块的输出里有 `ExecReload = { path=/usr/sbin/nginx ; argv[]=/usr/sbin/nginx -s reload ... }`，**直接印证了之前对 error.log 里 `signal process started` 的解释**：reload 就是用 `nginx -s reload` 给 master 发 HUP 信号，所以 `MainPID` 1314 全程不变。
- `state: reloaded` 的 ad-hoc 任务同样报 `changed=true`——模块只知道「我执行了 reload 动作」，不知道「配置是否真的生效」。**模块层的 `changed` 同样不等于业务生效**，这是本节主题的第四次印证。
- `file` 模块删除一个不存在的路径返回 `changed=false` 而不报错，这正是「幂等清理」写法安全的前提：重复执行不会失败。

最终状态：18099 的端口标签已撤销，练习配置文件和目录已删除，环境回到最初状态。**后续实测确认**：按默认变量（18099）重跑会复现最初的 SELinux 拒绝，详见下面的补充小节。

### 补充：给 playbook 加自检（meta: flush_handlers + wait_for）

这一节的 playbook 原本有一个盲区：**没有任何任务在验证「服务真的起来了」**，所以 SELinux 拒绑这件事在代码内部完全不可见。补两处即可让 playbook 自己报错：

```yaml
  tasks:
    - name: Render nginx demo config
      template: ...
      notify: reload nginx

    - name: Check nginx config
      command: /usr/sbin/nginx -t
      register: nginx_test
      changed_when: false

    - name: Show nginx test result
      debug:
        var: nginx_test.stderr_lines

    - name: Flush handlers to reload nginx now
      meta: flush_handlers          # 新增①：立刻执行排队中的 handler

    - name: Verify demo port is listening
      wait_for:                     # 新增②：主动探测端口，超时即失败
        host: 127.0.0.1
        port: "{{ nginx_demo_port }}"
        state: started
        timeout: 5

  handlers:
    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded
```

- `meta` 不是普通模块，它是**给 Ansible 引擎的指令**。默认 handler 要等 play 结束才执行，`meta: flush_handlers` 让它在此刻执行。
- 两处必须配套：**没有 `flush_handlers`，`wait_for` 会排在 handler 之前跑，验的是旧状态，等于白验。**
- 任务顺序刻意排成「先查语法 → 再 flush 触发 reload → 最后验证端口」。语法有问题时 play 会在 flush 之前停下，根本不去碰 nginx，这正是 handler「失败时不执行」的安全设计。

#### 实测一：默认端口 18099（复现故障）

```bash
ansible-playbook -i inventory.ini handlers-nginx.yml --syntax-check
ansible-playbook -i inventory.ini handlers-nginx.yml -K
```

```text
syntax-check                        ：playbook: handlers-nginx.yml
TASK [Render nginx demo config]     ：changed
TASK [Check nginx config]           ：ok
TASK [Show nginx test result]       ：ok，stderr_lines 显示 syntax is ok / test is successful
RUNNING HANDLER [reload nginx]      ：changed（跑在输出中间，不是末尾）
TASK [Verify demo port is listening]：fatal: FAILED!
                                      {"changed": false, "elapsed": 5,
                                       "msg": "Timeout when waiting for 127.0.0.1:18099"}
PLAY RECAP                          ：ok=4 changed=2 unreachable=0 failed=1
```

**`RUNNING HANDLER` 出现在输出中间而不是末尾，就是 `meta: flush_handlers` 生效的可视化签名。**

#### 实测二：`-e nginx_demo_port=8008`（对照组）

```bash
ansible-playbook -i inventory.ini handlers-nginx.yml -e "nginx_demo_port=8008" -K
ss -lntp | grep 8008 ; curl -sS http://127.0.0.1:8008 ; echo ; pgrep -a nginx
```

```text
TASK [Render nginx demo config]     ：changed
TASK [Check nginx config]           ：ok
TASK [Show nginx test result]       ：ok
RUNNING HANDLER [reload nginx]      ：changed
TASK [Verify demo port is listening]：ok（这次通了）
PLAY RECAP                          ：ok=5 changed=2 unreachable=0 failed=0

ss     ：LISTEN 127.0.0.1:8008
curl   ：handler demo ok, version=1
pgrep  ：1314 master；worker 换为 12412-12415
```

#### 两次对比的结论

```text
               changed   failed   业务状态
18099（被拦）      2        1      端口没监听
8008 （放行）      2        0      端口正常监听
```

- 两次的 `changed` **完全一样**（Render + handler 各一个），只有 `failed` 不同。**`changed` 回答的是「我做了动作没有」，`failed` 回答的是「结果对不对」。** 这是「changed 不等于生效」这条铁律在代码层面的最终形态——以前靠人工 `cat`/`ss`/`curl` 判断，现在固化成 `failed`，交给自动化把关。
- 同一份 playbook、同一个故障、同样的 `changed=2`，只换端口就让 `failed` 从 1 变 0，说明 `wait_for` 的判定真实有效，既不误报也不漏报。
- 生产写法应把「配置改动 → reload → 业务面验证」当成固定组合，验证手段按服务类型选：端口用 `wait_for`，HTTP 接口用 `uri`，数据库用对应模块的连接检测。

#### 自检实验后的清理（已完成）

```bash
ansible local -i inventory.ini -b -K -m file -a 'path=/etc/nginx/conf.d/ops-handler-demo.conf state=absent'
ansible local -i inventory.ini -b -K -m systemd -a 'name=nginx state=reloaded'
ss -lntp | grep -E ':8008|:18099' ; curl -sS http://127.0.0.1:8008 ; echo ; pgrep -a nginx
```

```text
file           ：changed=true
systemd reload ：changed=true，MainPID 仍 1314
                 ExecReload = /usr/sbin/nginx -s reload（pid=12411，status=0）
ss             ：无输出（8008 与 18099 都不再监听）
curl           ：拒绝连接（预期，服务已被主动撤掉）
pgrep          ：1314 master；worker 换为 12616-12619
```

**端口约定（本项目后续遵守）**：练习统一使用白名单内的 8008；**18099 保持被 SELinux 拦截**，作为「可复现的故障演练场」，留给下一节的 `block/rescue` 错误处理当教材。

### 小节结论

- `changed` 不证明副作用真的发生，这是本阶段的第三次验证（前两次：`command` 的 `>>` 失效、模板幂等误读）。要确认真实生效必须查业务面：`ss` 看监听、`curl` 看响应、`pgrep` 看进程。
- 进一步把业务面验证**写进 playbook**：`meta: flush_handlers` + `wait_for`。两次运行 `changed` 相同（2）而 `failed` 不同（1 → 0），说明「动作」和「结果」必须分开判断。
- 配置不生效时的排查顺序：先看服务自己的错误日志 → 再看内核层拒绝记录（AVC）→ 最后查策略清单。
- SELinux 管的是标签，不是权限；给端口打标签远比关掉 SELinux 正确。
- master PID 不变 + worker 全换 = reload（服务不中断）；master 也换 = restart（有瞬断）。生产配置变更优先 reload。
- 本节不要重做。

## 八、block 与 rescue 错误处理（已完成）

### 目标

让 playbook 在业务面验证失败后**自动回滚**，不在磁盘上留下半成品配置。

### 先确认「没有 rescue」的后果

```bash
ansible-playbook -i inventory.ini handlers-nginx.yml -K
ls -l /etc/nginx/conf.d/ops-handler-demo.conf
ss -lntp | grep 18099 ; pgrep -a nginx
```

```text
playbook ：ok=4 changed=2 failed=1 rescued=0
ls -l    ：-rw-r--r--. 1 root root 204 9月 17 19:57 /etc/nginx/conf.d/ops-handler-demo.conf
           → 任务失败了，半成品文件却仍留在磁盘上
ss       ：无输出（18099 未被监听）
pgrep    ：1314 master + worker 12616-12619（一个都没换）
```

结论：**nginx 绑定失败时会放弃新配置、连 worker 都不切换，继续用旧配置跑**。这次的残留文件暂时无害（18099 本来就绑不上），但换一种失败类型（语法合法、逻辑错误）就会在下一次 reload 时引爆。所以「失败时不能留下脏现场」。

### 带回滚的 playbook

```yaml
  tasks:
    - name: Apply nginx demo config with rollback
      block:
        - name: Render nginx demo config
          template:
            src: templates/ops-handler-demo.conf.j2
            dest: "{{ demo_conf }}"
            mode: '0644'
          notify: reload nginx

        - name: Check nginx config
          command: /usr/sbin/nginx -t
          register: nginx_test
          changed_when: false

        - name: Show nginx test result
          debug:
            var: nginx_test.stderr_lines

        - name: Flush handlers to reload nginx now
          meta: flush_handlers

        - name: Verify demo port is listening
          wait_for:
            host: 127.0.0.1
            port: "{{ nginx_demo_port }}"
            state: started
            timeout: 5

      rescue:
        - name: Remove the broken config file
          file:
            path: "{{ demo_conf }}"
            state: absent

        - name: Reload nginx to drop the broken config
          systemd:
            name: nginx
            state: reloaded

        - name: Report the rollback and fail
          fail:
            msg: "{{ nginx_demo_port }} 未能生效，已回滚 {{ demo_conf }}"
```

三个关键点：

- `block` 是正常流程；`rescue` 里的任务**只在 block 中有任务失败时才执行**。（另有关键字 `always`，无论成败都执行，适合上报监控或写审计日志。）
- `rescue` 里**直接调用模块，不用 `notify`**：救援动作必须「无条件、立即执行」，走 handler 就又多了一个「依赖 changed 才触发」的失效条件。
- `rescue` 除了清理磁盘（删文件）还要**回退运行状态**（reload）。如果某次故障是「nginx 已成功 reload 了坏配置」，光删文件不够，运行中的 nginx 还在用坏配置跑。
- 末尾的 `fail:` **必须有**。不写的话 rescue 顺利跑完，Ansible 会认为「这台主机已被救回来」，play 继续并最终报成功，CI/CD 会误判部署成功。

### 实测：18099 失败路径

```text
TASK [Render nginx demo config]                ：ok        ← 注意：不是 changed
TASK [Check nginx config]                      ：ok
TASK [Show nginx test result]                  ：ok
（完全没有 RUNNING HANDLER）
TASK [Verify demo port is listening]           ：fatal
                                                 Timeout when waiting for 127.0.0.1:18099
TASK [Remove the broken config file]           ：changed
TASK [Reload nginx to drop the broken config]  ：changed
TASK [Report the rollback and fail]            ：fatal
                                                 "18099 未能生效，已回滚 /etc/nginx/conf.d/ops-handler-demo.conf"
PLAY RECAP                                     ：ok=5 changed=2 failed=1 rescued=1

清理后验证：
ls        ：没有那个文件或目录（半成品已被删除）
systemctl ：active
ss        ：18099 无监听
pgrep     ：1314 master；worker 换为 13290-13293（rescue 里 reload 过）
```

`rescued=1` 是 rescue 被触发的签名；`failed=1` 说明 `fail:` 把失败重新抛了出去；`ok=5 changed=2`。

### 最重要的一条：这次没有出现 RUNNING HANDLER

本轮 `Render` 报的是 `ok` 而不是 `changed`，因此 **handler 完全没有触发**。原因是上一轮失败留下的残留文件，其内容与本次渲染结果**完全相同**，checksum 一致 → 不写文件 → 不 notify → 不 reload。

但它**仍然失败并触发了 rescue**——因为 `wait_for` 检查的是「18099 端口在不在监听」这个**持续存在的事实**，而不是「本轮有没有改动」。

由此得到两条认识：

- **handler 只对「本轮的变更」负责，`wait_for` 对「最终状态」负责**，两者职责不同、互相补充。
- 这个 playbook 是**状态导向（声明式）**而不是动作导向：不管本轮有没有改东西，只要最终状态不对，就要报错并回滚。这正是 Ansible 声明式模型的含义。

顺带纠正一个预估错误：此前按「文件会被重写」预计 `ok=6 changed=4`，实际是 `ok=5 changed=2`，原因就是这次 checksum 命中了。

### 实测：成功路径对照组（`-e nginx_demo_port=8008`）

```bash
ansible-playbook -i inventory.ini handlers-nginx.yml -e "nginx_demo_port=8008" -K
ss -lntp | grep 8008 ; curl -sS http://127.0.0.1:8008 ; echo ; pgrep -a nginx
```

```text
TASK [Render nginx demo config]                ：changed（上一轮 rescue 已删掉文件，这次要重新创建）
TASK [Check nginx config]                      ：ok
TASK [Show nginx test result]                  ：ok
RUNNING HANDLER [reload nginx]                 ：changed
TASK [Verify demo port is listening]           ：ok
PLAY RECAP                                     ：ok=5 changed=2 failed=0 rescued=0

ss    ：LISTEN 127.0.0.1:8008
curl  ：handler demo ok, version=1
pgrep ：1314 master；worker 换为 13472-13475
```

**`rescued=0` 就是「rescue 完全没介入」的判据**：同一个 playbook，失败路径 `rescued=1`、成功路径 `rescued=0`，两种表现都正确。

注意这里 `Render` 又变回 `changed` 了——因为上一轮 rescue 已经把文件删掉，这次需要重新创建。同一份代码在不同状态下报 `changed` 还是 `ok`，取决于**当前系统状态与目标状态的差异**，而不是代码本身。

### 本节收尾清理（已完成）

```bash
ansible local -i inventory.ini -b -K -m file -a 'path=/etc/nginx/conf.d/ops-handler-demo.conf state=absent'
ansible local -i inventory.ini -b -K -m systemd -a 'name=nginx state=reloaded'
ss -lntp | grep -E ':8008|:18099' ; systemctl is-active nginx ; pgrep -a nginx
```

```text
file           ：changed=true
systemd reload ：changed=true，MainPID 仍 1314，ExecReload pid=13471 status=0
ss             ：无输出（8008 与 18099 都不再监听）
systemctl      ：active
pgrep          ：1314 master；worker 换为 13631-13634
```

最终状态：练习配置文件已删除，nginx 只保留原有 80 端口的服务，18099 的 SELinux 标签保持撤销状态。

### 小节结论

- 失败处理的三步：**清理磁盘 → 回退运行状态 → 明确报红**。缺最后一步，自动化会误判成功。
- `rescue` 的语义是「把系统恢复到可用状态」，不一定是「撤销本轮改动」；本例中两者恰好重合。
- 「已回滚」≠「部署成功」，必须用 `fail:` 区分清楚。
- `changed` 会因为救援动作而增加，说明「部署失败」和「什么都没发生」不是一回事。
- 同一个 playbook 失败路径 `rescued=1`、成功路径 `rescued=0`，rescue 只在需要时才介入；`Render` 报 `changed` 还是 `ok` 取决于当前状态与目标状态的差异，而非代码本身。
- 本节不要重做。

## 九、后续学习与验收

1. 多主机部署与 `when` 条件。
2. 最终完成「一键部署 Nginx 及基础配置」的完整 playbook。

当前 Ansible 安装、本机连通性、Inventory、Ad-hoc 命令、Playbook 基础、变量与模板、handlers、handler 对接 Nginx reload（含 SELinux 端口排查）、`block`/`rescue` 错误处理均已完成，后续不要重做。
