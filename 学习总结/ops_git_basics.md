# Git 基础复习

## 本节位置

本节属于 Git/GitHub 与自动化脚本阶段，承接 Linux 运维学习项目的脚本、配置和故障记录管理。

## 1. Git 三个区域

```text
工作区：实际编辑的文件。
暂存区：通过 git add 准备提交的内容。
版本库：通过 git commit 保存的历史版本，位于 .git 中。
```

常用流程：

```text
修改文件 -> git diff -> git add -> git diff --cached -> git commit
```

## 2. 查看和撤销

```powershell
git status
git diff
git diff --cached
git show --stat --oneline HEAD
git show HEAD -- README.md
git diff HEAD~1 HEAD
git diff HEAD
git restore README.md
git restore --staged README.md
```

```text
git diff：查看未暂存修改。
git diff --cached：查看已暂存修改。
git show：查看提交及其内容。
git restore 文件：丢弃工作区未提交修改。
git restore --staged 文件：取消暂存但保留文件修改。
```

## 3. 分支和合并

已验证：

```text
创建 git-practice 分支并提交 da254fb。
切回 main 后确认练习内容未立即出现。
git merge git-practice 返回 Fast-forward。
删除已合并的练习分支。
```

分支用于隔离开发和实验；合并后目标分支才包含源分支提交。

## 4. 合并冲突

当两个分支修改同一个文件的同一部分时，Git 可能无法自动合并。

冲突标记：

```text
<<<<<<< HEAD
当前分支内容
=======
被合并分支内容
>>>>>>> branch-name
```

处理流程：

```text
git merge branch-name
查看冲突文件
手动保留正确内容并删除冲突标记
git add 文件
git commit
```

本次保留了“部署状态：维护中”，生成合并提交 `28b57d6`，之后删除了临时冲突分支。

## 5. 换行提示

```text
CRLF will be replaced by LF
```

这是 Git 根据 `.gitattributes` 统一文本换行格式的提示，不是提交失败。

## 6. 远程仓库

```text
origin：远程仓库的默认别名。
git push：把本地提交上传到远程。
git pull：获取并合并远程更新。
git clone：复制远程仓库到本地。
```

本次已完成：

```powershell
git remote add origin https://github.com/cwj1235/linux-ops-learning.git
git push -u origin main
git branch -vv
```

结果：本地 `main` 已推送到 `origin/main`，并建立上游分支关联。以后在本地有新提交时可以直接执行 `git push`。

## 7. 克隆与网络代理

`git clone` 第一次复制远程仓库到本地。若 TCP 端口可达，但 Git HTTPS 请求仍被重置，可能需要配置本地代理：

```powershell
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
git clone --depth 1 https://github.com/cwj1235/linux-ops-learning.git ..\linux-ops-learning-clone-2
```

本次设置代理后克隆成功。`$env:` 设置只作用于当前 PowerShell 会话，关闭终端后通常不会自动保留。

## 8. 双目录协作同步

当远程仓库已经有其他提交时，直接 push 可能被拒绝：

```text
远程领先本地 -> push 被拒绝 -> pull --rebase -> push
```

本次使用：

```powershell
git pull --rebase origin main
git push
```

随后主项目执行 `git pull`，以 `Fast-forward` 获取第二个克隆目录推送的 README 更新。`Fast-forward` 表示当前分支可以直接向前移动，不需要创建额外合并提交。

## 9. 运维脚本版本管理

把 CentOS 上实际运行的脚本复制到 Git 仓库后，脚本就可以拥有版本历史：

```text
复制脚本 -> git status -> git add -> git diff --cached --stat -> git commit -> git push
```

本次脚本：

```text
CentOS 源文件：/opt/scripts/system_inspection.sh
仓库文件：scripts/system_inspection.sh
提交：624b2f1 加入 Linux 系统巡检脚本
```

Git 仓库中的脚本是源代码和版本依据，CentOS 上的文件是部署副本。后续修改应先在仓库中提交，再同步到 CentOS 并执行验证。
