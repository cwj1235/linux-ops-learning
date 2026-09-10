# Python 运维脚本基础

## 1. Python 版本与脚本执行

CentOS 上当前环境：

```text
python：Python 2.7.5
python3：Python 3.6.8
```

新写的运维脚本使用 `python3`，不修改系统默认的 `python` 命令。

脚本使用：

```python
#!/usr/bin/env python3
```

并增加执行权限后，可以直接运行。系统会根据 shebang 自动选择 Python 3。

## 2. 使用 subprocess 执行命令

直接执行命令：

```python
import subprocess
subprocess.run(["hostname"])
```

`subprocess.run()` 用于执行外部系统命令；列表中的第一个元素是命令名，后续元素是参数。

## 3. 获取命令输出和退出码

```python
result = subprocess.run(
    ["hostname"],
    stdout=subprocess.PIPE,
    universal_newlines=True,
)
print("output:", result.stdout.strip())
print("returncode:", result.returncode)
```

本次实际结果：

```text
output: centos100
returncode: 0
```

含义：

```text
stdout=subprocess.PIPE：把标准输出交给 Python 保存。
universal_newlines=True：按字符串处理输出。
result.stdout：命令输出，原始值带末尾换行。
strip()：去掉开头和结尾的空白及换行。
result.returncode：命令退出码，0 通常表示成功。
```

如果直接打印 `result`：

```text
CompletedProcess(args=['hostname'], returncode=0, stdout='centos100\n')
```

这表示打印的是 `CompletedProcess` 对象本身，而不是只打印其中的 `stdout` 字段。对象同时包含命令参数、退出码和标准输出。

## 4. `subprocess.PIPE`

`subprocess.PIPE` 表示为子进程创建一条管道，让 Python 可以接收子进程的输出或错误信息。

```python
result = subprocess.run(["hostname"], stdout=subprocess.PIPE, universal_newlines=True)
```

这里的 `stdout=subprocess.PIPE` 会把命令的标准输出保存到 `result.stdout`，而不是只直接显示在终端。

```text
不设置 stdout：输出通常直接显示在终端。
设置 stdout=PIPE：Python 可以读取和处理输出。
设置 stderr=PIPE：Python 可以读取错误输出。
```

`PIPE` 是 Python 的管道设置，不是 Shell 中的 `|`。本次只完成概念讲解，尚未单独执行新的 PIPE 实验。

## 5. `universal_newlines=True`

`universal_newlines=True` 让 `subprocess` 捕获的输出以 Python 字符串处理。

```text
设置后：result.stdout 类似 "centos100\n"，类型是 str。
不设置：result.stdout 通常类似 b"centos100\n"，类型是 bytes。
```

字符串可以直接使用 `strip()`、`splitlines()` 等方法。较新的 Python 可以使用 `text=True`，但当前 CentOS 的 Python 3.6.8 使用 `universal_newlines=True` 更合适。

## 6. 退出码验证

实际执行：

```python
subprocess.run(["false"]).returncode
subprocess.run(["true"]).returncode
```

实际结果：

```text
false：returncode=1
true：returncode=0
```

Python 中的 `returncode` 对应 Shell 中紧邻上一条命令的 `$?`。通常 `0` 表示成功，非 `0` 表示失败或其他状态。

## 7. system_info 脚本

已将 `hostname` 调用写入 `/home/atguigu/system_info.py`，并通过直接执行验证：

```text
hostname: centos100
returncode: 0
```

这次验证同时覆盖了 Python 3 shebang、脚本执行权限、`stdout` 捕获、字符串处理和退出码读取。

## 8. uptime 系统信息

脚本增加 `subprocess.run(["uptime"])` 后，实际得到：

```text
13:34:04 up 3:18, 2 users, load average: 0.01, 0.04, 0.05
```

字段含义：当前时间为 13:34:04；系统已运行 3 小时 18 分；当前有 2 个登录会话；三个负载值分别代表最近 1、5、15 分钟的平均负载。命令退出码为 0。

## 9. 用函数复用 subprocess 逻辑

当多个检查都需要执行命令、读取输出和退出码时，可以把重复逻辑封装成函数：

```python
def run_command(command):
    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        universal_newlines=True,
    )
    name = command[0]
    print("{}: {}".format(name, result.stdout.strip()))
    print("{}_returncode: {}".format(name, result.returncode))
```

然后分别调用：

```python
run_command(["hostname"])
run_command(["uptime"])
```

本次验证结果：

```text
hostname: centos100
hostname_returncode: 0
uptime: 17:22:15 up 7:07, 2 users, load average: 0.00, 0.01, 0.05
uptime_returncode: 0
```

这样做的好处是：新增系统检查时只需要增加一行 `run_command(...)`，不用重复编写 `subprocess.run`、输出处理和退出码输出。
