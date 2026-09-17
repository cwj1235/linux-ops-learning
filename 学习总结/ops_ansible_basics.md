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

## 七、后续学习与验收

1. 把 handler 换成真实服务：配置变化时用 `systemd` 模块 reload/restart Nginx，并验证「配置没变就不重启」。
2. 继续强化幂等性、多主机部署和错误处理。
3. 最终完成一键部署 Nginx/基础配置的 playbook。

当前 Ansible 安装、本机连通性、Inventory、Ad-hoc 命令、Playbook 基础、变量与模板、handlers 均已完成，后续不要重做。
