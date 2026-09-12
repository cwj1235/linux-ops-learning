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

## 10. 捕获 stderr 错误输出

当命令可能失败时，可以同时捕获标准输出和错误输出：

```python
result = subprocess.run(
    ["ls", "/not-exist"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    universal_newlines=True,
)
```

本次实际结果：

```text
stdout: ''
stderr: 'ls: 无法访问/not-exist: 没有那个文件或目录\n'
returncode: 2
```

含义：

```text
stdout：正常输出，这里是空字符串。
stderr：错误输出，包含错误消息和末尾换行。
returncode：退出码，2 表示 ls 执行失败。
```

`repr()` 用于调试时查看字符串的真实结构，例如空字符串会显示为 `''`，换行会显示为 `\n`。

## 11. 字符串 format 与花括号

`"{}: {}".format(name, output)` 中的 `{}` 是占位符，表示“这里以后填入一个值”。

```python
name = "hostname"
output = "centos100"
print("{}: {}".format(name, output))
```

执行时按顺序替换：

```text
第 1 个 {} ← name，也就是 hostname
第 2 个 {} ← output，也就是 centos100
```

最终输出：

```text
hostname: centos100
```

所以：

```python
print("{}_returncode: {}".format(name, result.returncode))
```

会变成：

```text
hostname_returncode: 0
```

## 12. 在 run_command 中处理 stderr

`run_command()` 可以同时捕获正常输出和错误输出：

```python
def run_command(command):
    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    name = command[0]

    print("{}: {}".format(name, result.stdout.strip()))

    if result.stderr:
        print("{}_stderr: {}".format(name, result.stderr.strip()))

    print("{}_returncode: {}".format(name, result.returncode))
```

`if result.stderr:` 表示：只有错误输出不为空时，才打印错误信息。成功命令通常 `stderr` 为空字符串，所以不会显示这一行。

## 13. 子命令退出码与脚本退出码

实际执行脚本时，失败命令输出：

```text
ls_stderr: ls: 无法访问/not-exist: 没有那个文件或目录
ls_returncode: 2
```

这里的 `2` 是子命令 `ls` 的退出码，表示这条命令失败。随后执行 `echo $?` 得到 `0`，这是 Python 脚本自身的退出码。因为当前脚本只是打印 `ls_returncode`，没有使用 `sys.exit()` 传递失败状态，所以脚本整体仍然返回 0。

一句话记住：子命令的 `returncode` 说明子命令结果，Shell 的 `$?` 说明刚刚结束的 Python 脚本结果；两者可能不同。

## 14. 清理临时失败测试

删除临时的 `run_command(["ls", "/not-exist"])` 后，脚本重新执行成功：

```text
hostname_returncode: 0
uptime_returncode: 0
echo $? -> 0
```

说明当前两个系统命令和 Python 脚本自身都返回成功。下一步使用 `sys.exit()` 明确设计脚本整体退出码。

## 15. 使用 sys.exit 返回脚本状态

脚本加入 `sys.exit()` 后完成成功分支验证：

```text
python3 -m py_compile 无输出
hostname_returncode: 0
uptime_returncode: 0
echo $? -> 0
```

`sys.exit(0)` 明确表示脚本成功；如果任意一个被检查命令的 `returncode` 不为 0，脚本将执行 `sys.exit(1)`，把失败状态交给 Shell 或定时任务。

## 16. 验证 sys.exit 失败分支

临时把 `uptime` 替换为 `false` 后，实际结果为：

```text
false_returncode: 1
echo $? -> 1
```

`false` 的退出码为 `1`，满足失败条件，因此脚本执行 `sys.exit(1)`。这次验证证明脚本能够把子命令失败转换为脚本整体失败。验证完成后应把命令恢复为 `uptime`。

## 17. 恢复正式命令并验证成功分支

已将临时的 `false` 恢复为 `uptime`，再次验证结果：

```text
python3 -m py_compile 无输出
hostname_returncode: 0
uptime_returncode: 0
echo $? -> 0
```

至此，脚本已经完成一次成功和一次失败的退出码验证，并恢复到正常版本。

## 18. sys.argv 命令行参数

实际执行：

```bash
python3 -c 'import sys; print(sys.argv)' hostname uptime
```

结果：

```text
['-c', 'hostname', 'uptime']
```

`sys.argv` 是保存命令行参数的列表。使用 `-c` 时，`sys.argv[0]` 是 `-c`；`sys.argv[1]` 是第一个参数 `hostname`；`sys.argv[2]` 是第二个参数 `uptime`。通常从 `sys.argv[1]` 开始读取用户传入的参数。

## 19. 在 Python 文件中读取参数

创建 `/home/atguigu/args_demo.py` 并执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
```

实际输出：

```text
program: /home/atguigu/args_demo.py
argument: ['hostname', 'uptime']
```

运行 `.py` 文件时，`sys.argv[0]` 是脚本路径；`sys.argv[1:]` 使用列表切片取得所有用户参数，不包含脚本路径。

## 20. for 循环逐个处理参数

将参数放入 `for` 循环后：

```python
for argument in sys.argv[1:]:
    print("argument:", argument)
```

实际输出：

```text
argument: hostname
argument: uptime
```

循环会依次把列表中的每个元素赋值给 `argument`，然后执行缩进的代码块。列表有两个元素，代码块就执行两次。

## 21. 使用参数执行系统命令

在循环中使用 `subprocess.run([argument])` 后，命令行参数可以直接变成要执行的命令：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
```

实际结果显示 `hostname` 和 `uptime` 均执行成功，两个命令的退出码都是 `0`。`[argument]` 将单个字符串包装成 `subprocess.run()` 需要的命令列表，例如 `hostname` 变成 `["hostname"]`。输出中 `output:centos100` 少一个空格只属于显示格式问题，不影响执行结果。

## 22. 参数化脚本的失败命令验证

传入 `false` 后，实际得到：

```text
false output:
false returncode:1
```

说明 `false` 子命令确实返回失败码 `1`。本次在执行 Python 后又执行了 `vim`，最后才运行 `echo $?`，因此显示的 `0` 是 `vim` 的退出码，不是 Python 脚本的退出码。要查看 Python 的退出码，必须紧接着运行 `echo $?`。

## 23. 参数化脚本整体退出码

连续执行：

```bash
python3 /home/atguigu/args_demo.py false
echo $?
```

实际结果为 `false returncode: 1`，但脚本退出码为 `0`。原因是 `args_demo.py` 当前只打印每个命令的结果，没有根据失败命令调用 `sys.exit(1)`。下一步为循环增加失败标记，让任意一个命令失败时脚本整体返回 `1`。

## 24. 使用失败标记返回整体状态

脚本增加 `has_failure = False`，遇到非零退出码时设置为 `True`，循环结束后调用 `sys.exit(1)`。实际验证：

```text
false returncode: 1
echo $? -> 1
```

这证明子命令失败已经能够转换为参数化脚本的整体失败状态。

## 25. 多个命令的结果汇总

实际传入 `false uptime` 后，`false` 返回 `1`，循环仍继续执行 `uptime`，且 `uptime` 返回 `0`。最终脚本退出码仍为 `1`。

这说明当前逻辑不会在第一个失败处停止，而是执行完所有参数；只要任意命令失败，`has_failure` 就保持为 `True`，最终脚本返回失败。

## 26. 全部命令成功的参数验证

实际传入 `hostname uptime` 后，两个命令的退出码均为 `0`，输出均正常。此时还需要紧接着执行 `echo $?`，才能确认参数化脚本自身通过 `sys.exit(0)` 返回成功。

实际执行 `echo $?` 得到 `0`，确认全部命令成功时，参数化脚本会通过 `sys.exit(0)` 返回成功。

至此，`args_demo.py` 已验证三种情况：全部成功返回 `0`、任意失败返回 `1`、部分失败时仍继续执行后续命令但最终返回 `1`。

## 27. argparse 参数解析代码

本节只完成代码讲解，尚未验证新的 `argparse` 版本。

```python
import argparse
```

导入 Python 标准库中的参数解析模块。

```python
parser = argparse.ArgumentParser(
    description="执行多个系统命令并汇总结果"
)
```

创建参数解析器，并设置脚本说明。用户执行 `--help` 时会看到这段说明。

```python
parser.add_argument(
    "commands",
    nargs="+",
    help="要执行的命令名称"
)
```

定义一个名为 `commands` 的位置参数。`nargs="+"` 表示至少需要一个参数，可以传入多个命令；`help` 是帮助信息。

```python
args = parser.parse_args()
```

读取并检查用户输入，解析后的命令列表保存为 `args.commands`。它相当于以前的 `sys.argv[1:]`，但增加了格式检查和帮助信息。

```python
for argument in args.commands:
```

逐个取出解析后的命令，后面的 `subprocess.run([argument])`、失败标记和 `sys.exit()` 逻辑保持不变。`sys` 仍然保留，因为脚本还要使用 `sys.argv[0]` 和 `sys.exit()`。

实际执行 `python3 /home/atguigu/args_demo.py --help` 后，`argparse` 自动显示 usage、`commands` 位置参数和 `-h/--help` 选项。`--help` 只显示帮助并结束，不执行命令循环。

## 28. argparse 必填参数校验

不提供任何命令时，实际输出：

```text
args_demo.py: error: the following arguments are required: commands
echo $? -> 2
```

`nargs="+"` 至少要求一个 `commands` 参数。退出码 `2` 表示命令行参数使用错误，属于参数解析阶段失败；它不同于命令已经执行但返回非零退出码的情况。

## 29. argparse 合法参数验证

传入合法参数后，实际执行结果为：

```text
hostname returncode: 0
uptime returncode: 0
echo $? -> 0
```

说明 `argparse` 已正确解析多个位置参数，命令循环、失败汇总和脚本整体成功退出均正常。帮助、缺少参数、合法执行三条路径已经完成验证。

## 30. 未定义可选参数的错误

尝试传入尚未定义的 `--verbose`：

```text
args_demo.py: error: unrecognized arguments: --verbose
```

这说明 `argparse` 会拒绝未通过 `add_argument()` 注册的选项。要支持 `--verbose`，必须先定义：

```python
parser.add_argument(
    "--verbose",
    action="store_true",
    help="显示详细执行信息"
)
```

`action="store_true"` 表示：不写 `--verbose` 时 `args.verbose` 为 `False`，写上时为 `True`。

## 31. verbose 详细输出开关

已在脚本中注册 `--verbose`，并用下面的判断控制额外输出：

```python
if args.verbose:
    print("executing:", argument)
```

执行：

```bash
python3 /home/atguigu/args_demo.py --verbose hostname uptime
```

实际结果在每个命令执行前显示：

```text
executing: hostname
executing: uptime
```

`--verbose` 不改变命令本身的执行结果，只增加过程信息，方便观察进度和排查问题。不加该选项时，脚本仍执行命令，但不显示 `executing:` 行。

## 32. verbose 普通模式对比

不加 `--verbose` 执行：

```bash
python3 /home/atguigu/args_demo.py hostname uptime
echo $?
```

实际结果没有 `executing:` 过程提示，但两个命令仍正常执行，退出码均为 `0`，脚本整体退出码也为 `0`。因此 `--verbose` 只改变显示内容，不改变执行逻辑。

## 33. subprocess 超时处理

在 `subprocess.run()` 中加入 `timeout=3`，并捕获 `subprocess.TimeoutExpired` 后进行实际验证：

```bash
python3 -m py_compile /home/atguigu/args_demo.py
python3 /home/atguigu/args_demo.py hostname yes
echo $?
```

结果：`hostname` 返回 `0`；持续输出的 `yes` 在 3 秒后超时；脚本最终退出码为 `1`。这证明超时可以被纳入失败汇总。

本次超时提示显示为 `{} timeout after 3 seconds yes`，功能正确但格式不规范。应使用：

```python
print("{} timeout after 3 seconds".format(argument))
```

不要写成：

```python
print("{} timeout after 3 seconds", argument)
```

后者会把两个参数分别打印，中间自动加空格，不能替换花括号。

修改后实际输出为：

```text
yes timeout after 3 seconds
```

超时逻辑仍使脚本返回 `1`。输出中的 `^[[A` 是终端上方向键的 ANSI 控制序列，不是 Python 脚本输出。本次 `py_compile` 在最后一次 `vim` 修改之前执行，修改后的语法检查需要重新执行。

重新执行修改后的语法检查和超时测试：`py_compile` 无输出，`hostname` 返回 `0`，`yes` 显示 `yes timeout after 3 seconds`，脚本整体退出码为 `1`。说明格式修正后的脚本语法和超时处理均已验证。

## 34. timeout 正常路径验证

恢复为正常命令后再次执行：

```text
python3 -m py_compile 无输出
hostname returncode: 0
uptime returncode: 0
echo $? -> 0
```

说明正常命令不会触发超时异常，脚本仍通过 `sys.exit(0)` 返回成功。

当前 Python 参数脚本已完成：`argparse` 参数解析、`--help`、参数校验、verbose 过程输出、stdout/stderr 捕获、失败汇总、timeout 超时处理和整体退出码。

## 35. Python logging 基础验证

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

说明 `logging` 已按级别输出信息，并使用配置的格式显示级别和消息。本次日志只显示在终端，尚未写入文件。

## 36. Python logging 写入文件

实际配置：

```python
logging.basicConfig(
    filename="/home/atguigu/python_demo.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s"
)
```

实际查看日志得到：

```text
2026-09-12 11:42:42,205 INFO: inspection started
2026-09-12 11:42:42,205 ERROR: backend check failed
```

`filename` 使日志写入文件，`%(asctime)s` 自动记录时间。本次文件日志验证成功。

## 37. 将 logging 集成到参数脚本

`args_demo.py` 已加入文件日志配置，并在命令开始和成功后分别记录 `INFO` 日志。实际执行正常命令后，日志内容为：

```text
INFO: command started: hostname
INFO: command succeeded: hostname
INFO: command started: uptime
INFO: command succeeded: uptime
```

这形成了命令执行的基本审计轨迹：开始执行 -> 执行成功。终端仍显示命令输出，日志文件保存过程记录。

## 38. logging 失败与超时验证

实际执行 `false yes` 后：

```text
false returncode: 1
yes timeout after 3 seconds
echo $? -> 1
```

日志文件中对应记录：

```text
ERROR: command failed: false returncode=1
ERROR: command timeout: yes
```

说明失败命令和超时命令都能在终端显示结果、在日志文件留下 `ERROR` 记录，并使脚本整体返回失败状态。

## 39. Python 运维脚本阶段完整总结

### 39.1 环境与脚本原则

CentOS 当前 Python 环境：

```text
python：Python 2.7.5
python3：Python 3.6.8
```

本阶段新脚本统一使用 Python 3，不修改系统默认的 `python` 命令，避免影响 CentOS 7 的系统工具。`system_info.py` 使用：

```python
#!/usr/bin/env python3
```

并通过 `chmod +x` 验证了直接执行时 shebang 会选择 Python 3。

### 39.2 `subprocess` 命令执行链

已经掌握并实际验证：

```text
subprocess.run()       执行外部 Linux 命令
stdout=PIPE            捕获标准输出
stderr=PIPE            捕获错误输出
universal_newlines=True 将输出按 str 处理
result.stdout         读取标准输出
result.stderr         读取标准错误
result.returncode     读取子命令退出码
strip()               去掉输出末尾换行
```

`PIPE` 是 Python 的输出管道设置，不等同于 Shell 的 `|`。当前 Python 3.6.8 使用 `universal_newlines=True`，没有使用较新版本中的 `text=True`。

### 39.3 函数和错误处理

已经把重复的 `subprocess.run()` 逻辑整理为 `run_command(command)`，并理解：

```python
return result
```

用于把 `CompletedProcess` 对象返回给调用方，调用方才能读取 `.returncode`。

失败命令 `ls /not-exist` 的实际结果是：标准输出为空、错误信息进入 `stderr`、退出码为 `2`。随后通过 `sys.exit()` 区分两层状态：

```text
子命令 returncode：说明单条命令是否成功
sys.exit(0)：脚本整体成功
sys.exit(1)：脚本整体失败
Shell 的 echo $?：读取刚刚结束的脚本退出码
```

已经验证临时失败命令、恢复正式命令和成功/失败两条脚本路径。

### 39.4 命令行参数与循环

已经掌握：

```text
sys.argv[0]：程序名或脚本路径
sys.argv[1:]：用户传入的参数列表
for：逐个处理列表元素
[argument]：把单个命令名包装成 subprocess.run() 的命令列表
```

`args_demo.py` 已实际执行 `hostname`、`uptime`、`false` 和持续运行的 `yes`，并验证全部成功、部分失败和超时三种情况。

### 39.5 `argparse` 参数解析

已经实际验证：

```python
parser = argparse.ArgumentParser(description="...")
parser.add_argument("commands", nargs="+", help="...")
args = parser.parse_args()
```

关键行为：

```text
--help：自动显示 usage 和参数说明
不传 commands：解析阶段失败，退出码 2
未注册选项：显示 unrecognized arguments，退出码 2
合法命令：进入执行循环
```

`nargs="+"` 表示至少需要一个 `commands`，也可以传入多个。

### 39.6 `--verbose` 详细模式

已经加入并验证：

```python
parser.add_argument(
    "--verbose",
    action="store_true",
    help="显示详细执行信息"
)
```

```python
if args.verbose:
    print("executing:", argument)
```

不加 `--verbose` 时，脚本仍然执行命令，只隐藏过程提示；加上后显示当前正在执行的命令，不改变命令结果。

### 39.7 timeout 超时保护

已经加入并验证：

```python
try:
    result = subprocess.run(..., timeout=3)
except subprocess.TimeoutExpired:
    print("{} timeout after 3 seconds".format(argument))
    has_failure = True
    continue
```

使用持续运行的 `yes` 验证了 3 秒超时。超时会被纳入失败汇总，脚本最终返回 `1`。同时修正了 Python `print()` 逗号不会替换 `{}` 的格式问题。

### 39.8 logging 日志记录

已经掌握并验证：

```python
logging.basicConfig(
    filename="/home/atguigu/args_demo.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s"
)
```

日志级别：

```text
DEBUG：调试细节
INFO：正常运行信息
WARNING：警告
ERROR：错误
```

`args_demo.py` 已实现：

```text
命令开始：INFO command started
命令成功：INFO command succeeded
命令失败：ERROR command failed
命令超时：ERROR command timeout
```

终端负责显示当前命令结果，`/home/atguigu/args_demo.log` 负责保存带时间的执行记录。成功、失败和超时日志均已实际验证。

### 39.9 本阶段已实际验证的命令

```bash
python --version
python3 --version
python3 -c 'print("hello from python3")'
python3 -c 'import subprocess; subprocess.run(["hostname"])'
python3 -m py_compile /home/atguigu/system_info.py
/home/atguigu/system_info.py
python3 -c 'import sys; print(sys.argv)' hostname uptime
python3 /home/atguigu/args_demo.py --help
python3 /home/atguigu/args_demo.py hostname uptime
python3 /home/atguigu/args_demo.py false
python3 /home/atguigu/args_demo.py false uptime
python3 /home/atguigu/args_demo.py hostname yes
python3 /home/atguigu/args_demo.py --verbose hostname uptime
cat /home/atguigu/args_demo.log
tail -n 10 /home/atguigu/args_demo.log
```

### 39.10 当前准确状态

```text
system_info.py：已完成 subprocess 基础示例和 sys.exit() 验证。
args_demo.py：已完成参数解析、命令执行、错误捕获、失败汇总、verbose、timeout 和 logging。
Python 学习笔记：已完整记录本阶段 1～38 节和本总览。
Windows Git 仓库：Python 记录文件有未提交修改。
CentOS：args_demo.py 和日志文件已实际存在；args_demo.py 已复制到 Windows Git 仓库的 `scripts/args_demo.py`，但尚未提交。
日志文件：*.log 已被项目 .gitignore 忽略，不应直接提交日志内容。
```

一句话记住：

```text
Python 运维脚本 = 参数解析 + 命令执行 + 输出捕获 + 超时保护 + 日志记录 + 退出码汇总。
```
