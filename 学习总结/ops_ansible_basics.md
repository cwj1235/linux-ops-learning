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

## 九、多主机部署与 when 条件（已完成）

### 为什么以及怎么模拟多主机

之前的练习全是单机（`hosts: local`）。Ansible 的价值在于「一次编写、批量下发」，所以必须先有「多台被管节点」。本机只有一台 CentOS 虚拟机，因此用**两个 managed node 指向同一台机器**来模拟：

- `localhost` —— 走 local 连接（不经 SSH）
- `centos100` —— 走 SSH 连接，连到 `127.0.0.1`

### 免密 SSH 登录（Ansible 的前置基本功）

现状探测：

```bash
systemctl is-active sshd ; ls -la ~/.ssh/
ssh -o BatchMode=yes localhost true ; echo "退出码=$?"
```

```text
sshd     ：active
~/.ssh   ：没有那个文件或目录
ssh 自连 ：退出码=255，Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password)
```

配置：

```bash
cd ~
mkdir -p ~/.ssh ; chmod 700 ~/.ssh
ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys ; chmod 600 ~/.ssh/authorized_keys
ssh -o BatchMode=yes localhost 'hostname; whoami' ; echo "退出码=$?"
```

```text
centos100
atguigu
退出码=0
```

要点：

- `ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa`：`-t` 类型、`-b` 位数、`-N ''` 空 passphrase（Ansible 才能无人值守调用）、`-f` 保存路径。生成 `id_rsa`（私钥，权限 600，绝不外传）与 `id_rsa.pub`（公钥，可公开）。
- 免密原理：公钥放进目标机 `~/.ssh/authorized_keys`；登录时服务器用公钥出题、客户端用私钥解答，全程不传密码。
- 必须用 `>>` 追加，不能用 `>`（会清掉已有授权公钥）。
- 本机同用户可直接 `cat >>`；**远程机器的标准做法是 `ssh-copy-id user@host`**。
- `chmod 600 authorized_keys` 不能省：sshd 的 `StrictModes` 会拒绝 group/other 可写的授权文件，表现为「密钥明明放对了却还要输密码」。
- `BatchMode=yes` 禁止交互输密码，既能验证免密，也能避免脚本卡在密码提示上。
- 第一次 ssh 会提示接受主机指纹并写入 `~/.ssh/known_hosts`；`ssh-keygen` 输出的 randomart 图是指纹的可视化，用于人工比对。

### 多主机 inventory

```ini
[local]
localhost ansible_connection=local

[ssh_nodes]
centos100 ansible_host=127.0.0.1 ansible_user=atguigu

[practice:children]
local
ssh_nodes

[practice:vars]
practice_root=/home/atguigu/ansible-practice/multi-demo
```

- `[practice:children]` 是**组的嵌套**（组的组），大型 inventory 的主要组织手段；`[practice:vars]` 给组内所有主机设变量。
- `ansible_connection` 默认就是 `ssh`，所以 `centos100` 不用写；`localhost` 必须显式写 `local`。

**先接受主机指纹**（Ansible 高频坑）：

```bash
ssh -o StrictHostKeyChecking=no 127.0.0.1 'hostname; whoami' ; echo "预热退出码=$?"
```

```text
Warning: Permanently added '127.0.0.1' (ECDSA) to the list of known hosts.
centos100 / atguigu / 预热退出码=0
```

`localhost` 早已在 `known_hosts` 里，但 `127.0.0.1` 对 SSH 来说是另一台「主机」（按主机名做键）。Ansible 首次连未知主机会卡在 `Are you sure you want to continue connecting?`。生产做法是先用一次非 BatchMode 的 ssh 接受指纹——**把需要人确认的步骤提前消灭**。

解析与连通性：

```bash
ansible-inventory -i inventory-multi.ini --graph
ansible -i inventory-multi.ini all -m ping
```

```text
@all:
  |--@practice:
  |  |--@local:      → localhost
  |  |--@ssh_nodes:  → centos100
  |--@ungrouped:     （空）

两台均 SUCCESS / pong，discovered_interpreter_python 都是 /usr/bin/python
```

`ansible-inventory --graph` 不改任何东西，专门用来看「Ansible 到底把这份 inventory 解析成了什么」，是排查「任务没跑在我以为的主机上」的第一个命令。

### 多主机 playbook

`multi-host.yml` 关键结构：

```yaml
- name: Multi host practice
  hosts: practice          # 目标是组，不是单台
  gather_facts: true       # 多主机必须打开；when 与模板常依赖 facts
  tasks:
    - debug：打印 inventory_hostname / ansible_host / ansible_hostname / distribution / memtotal_mb / python
    - debug：打印组变量 practice_root
    - file ：创建 {{ practice_root }}/{{ inventory_hostname }} 目录
    - copy ：写入 {{ practice_root }}/{{ inventory_hostname }}/info.txt
    - debug + when: inventory_hostname in groups['ssh_nodes']
    - debug + when: inventory_hostname in groups['local']
```

```bash
ansible-playbook -i inventory-multi.ini multi-host.yml --syntax-check
ansible-playbook -i inventory-multi.ini multi-host.yml --list-hosts
ansible-playbook -i inventory-multi.ini multi-host.yml
```

```text
--syntax-check：playbook: multi-host.yml
--list-hosts  ：hosts (2): centos100 / localhost（pattern: [u'practice']，u'' 是 Python 2 的 unicode 表示法，不是错误）
```

关键执行输出：

```text
TASK [Gathering Facts]               ok: [localhost] / ok: [centos100]
TASK [Show per-host identity]
  localhost => inventory_hostname=localhost  ansible_host=localhost  ansible_hostname=centos100 distribution=CentOS 7.9 memtotal_mb=1980 python=2.7.5
  centos100 => inventory_hostname=centos100  ansible_host=127.0.0.1  ansible_hostname=centos100 distribution=CentOS 7.9 memtotal_mb=1980 python=2.7.5
TASK [Show group variable]           两台都读到 /home/atguigu/ansible-practice/multi-demo
TASK [Create per-host directory]     changed: [localhost] / changed: [centos100]
TASK [Write per-host info file]      changed: [localhost] / changed: [centos100]
TASK [Task only for the SSH group]   skipping: [localhost] / ok: [centos100]
TASK [Task only for the local group] ok: [localhost] / skipping: [centos100]

PLAY RECAP
centos100 : ok=6 changed=2 unreachable=0 failed=0 skipped=1 rescued=0 ignored=0
localhost : ok=6 changed=2 unreachable=0 failed=0 skipped=1 rescued=0 ignored=0
```

### 三个主机名变量的区别

| 变量 | 含义 | 谁定义 |
| --- | --- | --- |
| `inventory_hostname` | Ansible 里的主机名 | 写在 inventory 里的 |
| `ansible_host` | 真实连接地址 | 显式指定；未指定时默认等于 `inventory_hostname` |
| `ansible_hostname` | 远端机器自己报出的主机名 | 远端 facts |

本例中 `inventory_hostname` 不同（`localhost` vs `centos100`），但 `ansible_hostname` 都是 `centos100`——**同一台机器两个身份的直接证据**。生产里前两者常等于第三个，但概念完全不同；三者对比是发现「连错机器」最快的手段。

补充：`ansible_host | default('local')` 里的 `default` 不会触发，因为 `ansible_host` 永不为空（Ansible 自动填 `inventory_hostname`），写兜底是多余的。

### `--limit`

```bash
ansible-playbook -i inventory-multi.ini multi-host.yml --limit centos100 --list-hosts
ansible-playbook -i inventory-multi.ini multi-host.yml --limit centos100
```

```text
--list-hosts：hosts (1): centos100
执行        ：PLAY RECAP 只有 centos100 一行，ok=6 changed=0 skipped=1
```

- `--limit` 临时缩小执行范围，不改 inventory；生产上用于灰度发布与定点修复。
- **先 `--list-hosts` 确认范围再执行**：`--limit` 写错一个字母，可能从「只改一台」变成「全量变更」。
- 也支持组名（`--limit ssh_nodes`）和逗号列表（`--limit centos100,localhost`）。
- `--limit` 只限制**执行范围**，不改变每台主机自己的 `when` 判断：centos100 依旧被 local 组的任务跳过。
- 本轮 `changed=0`：上一轮全量执行已把目录与文件建好，这次复查发现目标状态已达成、一个动作都不做。**幂等性在多主机上就是「两台各自幂等、互不干扰」。**

### 已知限制与未验证项

- 物理上只有一台机器，两个 managed node 读到的 facts **完全相同**，所以「按 facts 分支」的 `when` 看不出差异；能区分的只有 inventory 与变量。等以后有第二台真机或容器，这套 playbook 可原样复用。
- `multi-demo/localhost/info.txt` 与 `multi-demo/centos100/info.txt` 的实际内容已在后续补做 `cat` 与 `find` 核对（见命令履历 2026-09-18 小节）：两台的 `inventory_hostname`/`ansible_host` 不同、`ansible_hostname` 相同，站点内容与预期一致。第九节「尚未 cat」的未验证项就此关闭；`multi-demo/` 已在第十节收尾时清理。

### 小节结论

- 多主机能力建立在「免密 SSH + 结构化 inventory」两个基础上，这两件事本身就是运维基本功。
- `inventory_hostname` / `ansible_host` / `ansible_hostname` 含义不同，混用会导致「连错机器」或「判断错主机」。
- 多主机是并行执行的，输出顺序不保证；判断结果看 `PLAY RECAP`，不要看顺序。
- `skipped` 是多主机里最主要的新信息；`--list-hosts` 是防误操作的第一道闸。
- 本节不要重做。

## 十、一键部署 Nginx 完整 playbook（已完成）

### 目标

把前九节的能力串成一条完整流水线：装 nginx → 建站点目录 → 部署首页 → 部署站点配置 → 热加载 → HTTP 自检 → 失败回滚，并要求幂等、可回滚、可移植（换一台机器也能一次跑对）。

### 新增文件

`inventory-prod.ini`（两台机器的差异只写在 inventory 里）：

```ini
[web]
localhost ansible_connection=local site_port=8008
centos100 ansible_host=127.0.0.1 ansible_user=atguigu site_port=8009
```

`templates/index.html.j2`：

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>{{ site_name }} @ {{ inventory_hostname }}</title>
</head>
<body>
  <h1>{{ site_name }}</h1>
  <ul>
    <li>inventory_hostname: {{ inventory_hostname }}</li>
    <li>ansible_hostname: {{ ansible_hostname }}</li>
    <li>listen port: {{ site_port }}</li>
    <li>distribution: {{ ansible_distribution }} {{ ansible_distribution_version }}</li>
    <li>site_root: {{ site_root }}</li>
  </ul>
</body>
</html>
```

`templates/nginx-site.conf.j2`：

```nginx
# Managed by Ansible. Do not edit by hand.
# inventory_hostname: {{ inventory_hostname }}

server {
    listen 127.0.0.1:{{ site_port }};
    server_name _;

    root {{ site_root }};
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

`nginx-deploy.yml`：

```yaml
---
- name: Deploy nginx site
  hosts: web
  gather_facts: true
  become: true
  serial: 1

  vars:
    site_name: ops-demo
    site_root: "/var/www/{{ site_name }}-{{ inventory_hostname }}"
    conf_file: "/etc/nginx/conf.d/{{ site_name }}-{{ inventory_hostname }}.conf"

  tasks:
    - name: Show target node info
      debug:
        msg: "node={{ inventory_hostname }} port={{ site_port }} root={{ site_root }}"

    - name: Install nginx
      yum:
        name: nginx
        state: present
      when: ansible_os_family == "RedHat"

    - name: Create site root
      file:
        path: "{{ site_root }}"
        state: directory
        mode: '0755'
        setype: httpd_sys_content_t

    - name: Deploy index page
      template:
        src: templates/index.html.j2
        dest: "{{ site_root }}/index.html"
        mode: '0644'

    - name: Apply nginx site config with rollback
      block:
        - name: Deploy nginx site config
          template:
            src: templates/nginx-site.conf.j2
            dest: "{{ conf_file }}"
            mode: '0644'
          notify: reload nginx

        - name: Flush handlers to apply config now
          meta: flush_handlers

        - name: Verify site is serving
          uri:
            url: "http://127.0.0.1:{{ site_port }}/"
            return_content: true
          register: site_resp
          failed_when: site_name not in site_resp.content

        - name: Show verification result
          debug:
            msg: "{{ inventory_hostname }} HTTP {{ site_resp.status }}，页面已包含站点名 {{ site_name }}"

      rescue:
        - name: Remove the broken site config
          file:
            path: "{{ conf_file }}"
            state: absent

        - name: Reload nginx after rollback
          systemd:
            name: nginx
            state: reloaded

        - name: Report rollback and fail
          fail:
            msg: "{{ inventory_hostname }} 站点验证失败，已回滚 {{ conf_file }}"

  handlers:
    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded
```

### 变量优先级：为什么 `site_port` 只写在 inventory 里

- 实测两台分别打印 `node=localhost port=8008` 与 `node=centos100 port=8009`，同一份 playbook、两种参数。
- 关键设计：`site_port` **只**定义在 inventory 的主机变量里，playbook 的 `vars` 里故意不写。因为 playbook `vars` 的优先级**高于** inventory 主机变量，一旦在 `vars` 里写了 `site_port: 8008`，centos100 的 8009 就会被覆盖。
- 所以「一份 playbook 服务多台机器」的正确做法是：**差异放进 inventory（主机变量/组变量），共性放进 playbook `vars`**（本例共性只有 `site_name`，派生量 `site_root`/`conf_file` 用 `inventory_hostname` 拼出来）。

### `serial: 1`：滚动更新的雏形

- `serial: 1` 表示「一次只在一台（批）主机上跑完整流程」，于是输出里出现**两次** `PLAY [Deploy nginx site]`，每台一段。
- 价值：一台跑完并且自检通过，才轮到下一台；某台失败时后面的机器不会被牵连。配合 `--limit` 就能只对指定机器发布（本节两个实验都用了它）。

### `--list-tasks` 能看到什么

- 只列出 7 个任务。`meta: flush_handlers` **不是任务**（它是执行控制），`rescue` 里的任务也不在正常路径中列出。

### 四次执行的结果

| 场景 | 命令 | 结果 |
|---|---|---|
| 首次部署（两台） | `ansible-playbook -i inventory-prod.ini nginx-deploy.yml -K` | 两次 PLAY，两台各 `ok=9 changed=4`；8008/8009 各返回 200，页面含各自的端口与站点根目录 |
| 幂等复跑（两台） | 同上 | 两台各 `ok=8 changed=0`，无 `RUNNING HANDLER` |
| 标签被改坏后自愈 | `sudo chcon -t var_t /var/www/ops-demo-localhost` 再 `--limit localhost` | `ok=8 changed=1`，`Create site root` 报 changed，标签回到 `httpd_sys_content_t` |
| 目录从零重建 | `sudo rm -rf /var/www/ops-demo-centos100 /etc/nginx/conf.d/ops-demo-centos100.conf` 再 `--limit centos100` | `ok=9 changed=4`（与首跑一致），目录一出生即 `httpd_sys_content_t`，8009 返回 200 |

- `ok=9` 与 `ok=8` 差的那 1 个就是 handler：首跑有 `RUNNING HANDLER [reload nginx]`，幂等复跑没有。所以 **9 = 8 个任务 + 1 个 handler**。
- **`ok` 是「成功执行次数」，包含发生变更的那些**（`ok=9 changed=4` = 9 次执行里有 4 次做了动作）。看「有没有干活」看 `changed`，看「跑了几个任务」看 `ok`。
- 第 3 行那次 `changed=1` **完全来自 SELinux 标签**：内容、属主、权限、mode 全都没变。结论：`changed` 是「任何被声明的属性不一致」，标签也算在内；幂等的前提是**所有属性（含标签）都对齐**。
- 第 4 行附带一个推理技巧：`Create site root` 与 `Deploy index page` 报 `changed`，即可确认目录是被重建的（内容一致却报 changed，只可能是「从不存在到存在」），不必额外 `ls` 确认 `rm -rf` 是否生效。

### 自检与回滚（继承第八节）

- `uri` 模块 + `failed_when: site_name not in site_resp.content`：不满足于 HTTP 200，还要求页面内容含站点名，避免「服务通了但发错站点」。
- `meta: flush_handlers` 放在校验之前：先 reload 再校验，否则校验的是旧配置。
- `rescue` 三步：删掉坏配置 → `systemd: state=reloaded` 回退运行状态 → `fail:` 明确报红。「已回滚」不等于「部署成功」。

### SELinux 标签加固（本节最值钱的发现）

现象：部署成功后 `index.html` 标签正确（`system_u:object_r:httpd_sys_content_t:s0`），但站点目录 `/var/www/ops-demo-*` 是 `unconfined_u:object_r:var_t:s0`；`matchpathcon -V` 判定目录 `has context ...var_t:s0, should be ...httpd_sys_content_t:s0`。

排查与定案（前四步全部只读，最后才动手）：

1. `ls -ldZ /var/www` → `/var/www` 自身就是 `var_t`，所以「继承父目录类型」得到的就是 `var_t`。
2. `sudo semanage fcontext -l | grep '^/var/www'` → 策略数据库里**已有** `/var/www(/.*)?  all files  system_u:object_r:httpd_sys_content_t:s0`，说明目录标签确实不符合策略预期。
3. `sudo matchpathcon -V <路径>` → 权威判官，直接给出「实际值 vs 策略默认值」。
4. `sudo grep -i 'denied' /var/log/audit/audit.log | tail -n 5` → 最新一条 denial 是前一天 nginx 绑 18099 的 `name_bind`，**本次部署零 AVC**。所以「现在还能 200」不是被拒绝后放行，而是当前策略压根没拒绝（具体由哪条 allow 规则兜着**未做 `sesearch` 验证，不猜**）。
5. 对照实验一：`sudo mkdir -p /var/www/labeltest-bash` → `var_t`（没人套标签时，新目录继承父目录类型）。
6. 对照实验二：`ansible -m file -a 'path=/var/www/labeltest state=directory mode=0755'` → 返回值 `"secontext": "unconfined_u:object_r:var_t:s0"`；`ansible -m file -a 'path=/var/www/touchtest state=touch'` → 同样是 `var_t`。
7. 对照实验三：`ansible -m copy -a 'content="hello" dest=/var/www/labeltest/index.html mode=0644'` → 返回值 `"secontext": "system_u:object_r:httpd_sys_content_t:s0"`。

结论：

- **`copy` / `template` 落地文件时会自动套策略默认 SELinux 标签；`file` 模块不会自动套**（建目录、建文件都不套）。分界线是「**模块**」，不是「目录 vs 文件」——`file` 建文件（`state=touch`）实测也没套。
- `file` 模块**有** SELinux 能力（参数 `setype`/`seuser`/`serole`/`selevel`），只是不会自动补默认值。所以用 `file` 建的目录必须显式写 `setype`，否则换机器或重建目录时标签必错（100% 复现，不是偶发）。
- 三个命令的分工要分清：
  - `semanage fcontext -a -t <类型> "<路径正则>"`：改**策略数据库里的规则**，用于自建的非标准路径（如 `/srv/www`）。
  - `restorecon -Rv <路径>`：把规则**盖到磁盘上**；`-n` 是 dry-run。**本例策略里已有 `/var/www(/.*)?` 规则，所以不需要 `semanage fcontext`，`restorecon` 就够。**
  - `chcon -t <类型> <路径>`：只改当前文件标签、不写进策略，会被下一次 `restorecon`/`fixfiles` 冲掉；适合临时验证，也正好用来制造故障。
  - `restorecon` 默认只改 **type**，不动 user/role/range（连 user/role 一起改要加 `-F`）。SELinux 的访问决策看的是 **type**，所以 `unconfined_u:object_r:httpd_sys_content_t:s0` 与 `system_u:object_r:httpd_sys_content_t:s0` 都能正常工作。
- 落地加固：给 `Create site root` 加一行 `setype: httpd_sys_content_t`，此后「标签被改坏」与「目录从零创建」两条路径都实测通过。这一行只声明 type，user 部分仍是 `unconfined_u`——Ansible 只替换你显式给出的字段。
- 另一个观察：`matchpathcon -V /var/www` 显示 `/var/www` 自身也不符合策略（`var_t` vs `httpd_sys_content_t`）。这是**机器基线偏差**、不是本次引入的，也不影响本站点访问，故意没有动它（想对齐可用 `sudo restorecon -v /var/www`）。

### 清理与最终状态

- 清理：只删运行时产物 `multi-demo/`（与之前删掉的 `template-demo/`、`handlers-demo/` 同类）。所有 `.yml` / `.ini` / `templates/*.j2` 保留作为教案；`/var/www/ops-demo-*` 与 `/etc/nginx/conf.d/ops-demo-*.conf` 保留作为可 `curl` 演示的成品。
- 最终状态：nginx master 仍是 `1314`；`127.0.0.1:8008`（localhost 身份）与 `127.0.0.1:8009`（centos100 身份）各返回 200；两台全量复跑 `ok=8 changed=0`；`18099` 仍保持被 SELinux 拦截，`http_port_t` 白名单里没有它。

### 小节结论

- 一份生产可用的部署 playbook = **被声明全的幂等条件**（内容、权限、标签、服务状态）+ **差异放进 inventory** + **滚动更新（`serial`）** + **自检（`uri` + `failed_when`）** + **失败回滚（`rescue`）** + **明确报红（`fail`）**。
- 「Ansible 跑绿了」只代表它**声明的**那些属性对齐了；没声明的属性（本例的 SELinux 标签）它会如实留给你。所以每引入一类资源，都要问一句「这个模块会不会顺手把这类属性也管起来」，不确定就用返回值里的 `secontext`、`ls -Z`、`matchpathcon -V` 验证。
- 判断结果只看 `PLAY RECAP` 的 `ok/changed/failed/rescued/skipped`，再叠加业务面验证（`ss`、`curl`、`ls -Z`）。
- 本节不要重做。

## 十一、后续学习与验收

Ansible 阶段十个小节全部完成：安装与本机连通性、Inventory、Ad-hoc 命令、Playbook 基础、变量与模板、handlers、handler 对接 Nginx reload（含 SELinux 端口排查）、`block`/`rescue` 错误处理、多主机与 `when` 条件、一键部署 Nginx 完整 playbook（含 SELinux 标签加固）。以上内容不要重做。

尚未开始的下一步方向（待用户选择，不属于已验收范围）：Roles 与 `ansible-galaxy`、Ansible Vault、动态 inventory、`ansible-lint`/CI 集成、在第二台真实机器或容器上验证滚动发布。
