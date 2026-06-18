# Git & GitHub 协作开发完整指南

> 本指南面向**完全零基础**的新人，从 Git 是什么讲起，手把手带你完成从安装到日常协作的全流程。
>
> 校园墙项目采用**多仓库模块化开发**模式，第 9 章专门讲解多仓库协作的注意事项，是本指南的核心章节。

---

## 目录

- [第 1 章：为什么要用 Git？（概念篇）](#第-1-章为什么要用-git概念篇)
- [第 2 章：环境安装与初始化配置](#第-2-章环境安装与初始化配置)
- [第 3 章：克隆仓库与搭建工作区](#第-3-章克隆仓库与搭建工作区)
- [第 4 章：日常开发标准工作流](#第-4-章日常开发标准工作流)
- [第 5 章：分支操作详解](#第-5-章分支操作详解)
- [第 6 章：提交与 Commit Message 规范](#第-6-章提交与-commit-message-规范)
- [第 7 章：Pull Request 全流程](#第-7-章pull-request-全流程)
- [第 8 章：代码审查与合并](#第-8-章代码审查与合并)
- [第 9 章：多仓库模块化开发 ⭐](#第-9-章多仓库模块化开发)
- [第 10 章：常见错误与故障排除](#第-10-章常见错误与故障排除)

---

## 第 1 章：为什么要用 Git？（概念篇）

### 1.1 没有 Git 的时候，我们怎么写代码？

想象一下这个场景——你正在写毕业论文：

```
毕业论文_v1.doc
毕业论文_v2_导师修改.doc
毕业论文_v3_加了图表.doc
毕业论文_最终版.doc
毕业论文_最终版_真的最终版.doc
毕业论文_最终版_这次真的不改了.doc
```

每个人应该都经历过这种事。问题是：

- **不知道改了什么**：打开两个版本对比，眼睛都要瞎了
- **改错了回不去**：删了一段发现还是原来的好，但已经保存覆盖了
- **多人改同一份**：A 改完发给 B，B 改完发给 C，最后不知道谁的版本是最新的

写代码比写论文更复杂——一个项目有几十上百个文件，三个人同时改不同文件，怎么合并到一起？

**Git 就是用来解决这些问题的。**

### 1.2 Git 是什么？

Git 是一个**分布式版本控制系统**。别被这个词吓到，用人话解释：

> Git 就像一台**时光机**，它记录你每一次保存（我们叫"提交"），你可以随时回到过去的任意一个时间点。
>
> 每个开发者的电脑上都有完整的"时光机"副本，所以叫"分布式"——即使 GitHub 网站挂了，你本地的历史记录依然完整。

Git 的核心能力就三个：

1. **记录历史**：谁、什么时间、改了哪些文件、改了什么内容
2. **随时回退**：改错了？一秒回到修改前的状态
3. **多人并行**：两个人同时改不同功能，最后自动合并

### 1.3 Git 的三个区域

理解 Git 的关键是理解它的三个区域：

```
┌─────────────┐    git add    ┌─────────────┐   git commit   ┌─────────────┐   git push   ┌─────────────┐
│   工作区     │  ───────────→ │   暂存区     │ ─────────────→ │  本地仓库    │ ───────────→ │  远程仓库    │
│  (你正在编辑  │              │  (购物车)    │              │  (历史档案馆) │             │  (GitHub)   │
│   的文件夹)   │              │              │              │              │             │             │
└─────────────┘              └─────────────┘              └─────────────┘             └─────────────┘
```

用购物来比喻：

| 区域 | 比喻 | 实际含义 |
|------|------|----------|
| **工作区** | 超市货架 | 你电脑上的项目文件夹，随便改 |
| **暂存区** | 购物车 | 你挑好的文件，准备结账（提交） |
| **本地仓库** | 家里的冰箱 | 已经买回家存好了，有完整记录 |
| **远程仓库** | 云备份盘 | 推到 GitHub 上，队友也能看到 |

**关键理解**：`git add` 和 `git commit` 是两个独立步骤！

- `git add` = 把商品放进购物车（还没结账）
- `git commit` = 结账，把购物车的东西存进冰箱（正式记录）
- `git push` = 上传到云端，分享给队友

新手最容易犯的错误：以为 `git add` 就是提交了，结果第二天发现代码"丢"了。

### 1.4 GitHub 是什么？

很多人以为 Git 和 GitHub 是一回事，其实不是：

```
Git  ≠  GitHub
 工具     网站/平台
```

| | Git | GitHub |
|------|-----|--------|
| 是什么 | 版本控制**工具**（安装在电脑上） | 代码托管**网站**（gitub.com） |
| 类比 | 相机的拍照功能 | 云端相册（Google Photos） |
| 谁维护 | 开源社区（Linus Torvalds 创建） | 微软 |
| 能干什么 | 本地记录历史、分支管理 | 云端存储、Pull Request、Issue 跟踪、CI/CD |

**类似的关系**：
- GitLab、Gitee（码云）也是代码托管平台，用的是同一个 Git 工具
- 就好比照片可以传到 Google Photos，也可以传到 iCloud，拍照的都是同一个相机

GitHub 提供的额外能力（Git 本身没有的）：
- **Pull Request**："我改好了，请审查后合并"——团队协作的核心
- **Issue**：Bug 跟踪、功能需求、任务分配
- **Actions**：自动化测试、自动部署（CI/CD）
- **Projects**：看板，可视化管理任务进度

### 1.5 核心名词速查表

在继续之前，先记住这些名词，后面会反复用到：

| 名词 | 一句话解释 |
|------|-----------|
| **Repository（仓库）** | 一个项目的 Git 版本控制目录，包含所有文件和历史 |
| **Clone（克隆）** | 把 GitHub 上的仓库下载到本地 |
| **Branch（分支）** | 一条独立的开发线，从主线上分叉出来，开发完了再合并回去 |
| **Commit（提交）** | 一次保存操作，记录了你改了哪些文件 |
| **Push（推送）** | 把本地的提交上传到 GitHub |
| **Pull（拉取）** | 把 GitHub 上别人的提交下载到本地 |
| **Merge（合并）** | 把一个分支的改动合并到另一个分支 |
| **Pull Request（PR）** | 在 GitHub 上请求把你的分支合并到 main |
| **Fork（复刻）** | 把别人的仓库复制一份到你自己名下（开源项目协作常用） |
| **Remote（远程）** | 远程仓库的地址别名，默认叫 `origin` |
| **origin** | 你克隆的那个 GitHub 仓库的默认别名 |
| **main** | 默认的主分支名（以前叫 `master`） |

### 1.6 校园墙项目的 GitHub 使用概况

校园墙项目由 **6 个独立模块**组成，每个模块是一个独立的 Git 仓库：

| 仓库 | 技术栈 | 说明 |
|------|--------|------|
| `campus_wall` | Java 17 + Spring Boot | 主后端服务 |
| `campus-wall-frontend` | Vue 3 + uni-app | 用户端前端（H5 + 微信小程序） |
| `campus-wall-monitor-ui` | Vue 3 + Element Plus | 管理后台前端 |
| `campus-wall-ai` | Python + FastAPI | AI 知识图谱/问答服务（原 campus-wall-graphrag 已并入，端口 8011） |
| `campus-wall-data-pipeline` | Python ETL | 数据管道（爬虫/清洗/写入） |
| `campus-wall-ops` | Docker Compose | 运维基础设施配置（含告警适配器 alert-adapter，原独立仓库 campus-wall-alert-adapter 已并入） |

每个仓库采用统一的[分支规范](../01-development-standards/00-开发规范.md)，通过 Pull Request 进行协作。详细的模块化开发说明见[第 9 章](#第-9-章多仓库模块化开发)。

---

## 第 2 章：环境安装与初始化配置

### 2.1 安装 Git（Windows）

#### 下载

1. 打开 Git 官网：https://git-scm.com/downloads/win
2. 点击 "Click here to download" 下载最新版安装包
3. 下载完成后双击运行

#### 安装步骤（重要选项说明）

安装过程中会有一系列选项页面，大部分保持默认即可。以下是几个**需要特别注意**的步骤：

**① Select Components（选择组件）**

确保勾选以下选项：
- `Git Bash Here` — 右键菜单添加"在此打开 Git Bash"
- `Git GUI Here` — 右键菜单添加"在此打开 Git GUI"
- `(optional) Add a Git Bash Profile to Windows Terminal` — 推荐勾选

其他保持默认。

**② Choosing the default editor（选择默认编辑器）**

**推荐选择 `Use Visual Studio Code as Git's default editor`**。

如果没有 VS Code，选 `Nano`（最简单的终端编辑器）。不要选 Vim——如果你不知道 Vim 怎么退出，你会被困住。

**③ Adjusting the name of the initial branch（初始分支名）**

选择 **`Override the default branch name for new repositories`**，在输入框中填 `main`。

这是为了让新建仓库的默认分支名和 GitHub 保持一致（GitHub 从 2020 年起默认分支名从 `master` 改为了 `main`）。

**④ Adjusting your PATH environment（PATH 环境变量）**

选择 **`Git from the command line and also from 3rd-party software`**（推荐选项）。

这个选项让你在 PowerShell、命令提示符中都能直接使用 git 命令。

**⑤ Choosing the SSH executable（SSH 执行程序）**

选择 **`Use bundled OpenSSH`**（默认即可）。

**⑥ Choosing HTTPS transport backend（HTTPS 传输后端）**

选择 **`Use the OpenSSL library`**（默认即可）。

**⑦ Configuring the line ending conversions（换行符转换）**

选择 **`Checkout Windows-style, commit Unix-style line endings`**（默认推荐）。

> Windows 用 `\r\n` 换行，Linux/Mac 用 `\n` 换行。这个选项让你在本地看到 Windows 格式，提交时自动转成 Unix 格式，避免跨平台协作时出现满屏的换行符差异。

**⑧ Configuring the terminal emulator（终端模拟器）**

选择 **`Use Windows' default console window`** 或 **`Use MinTTY`** 都可以。推荐 MinTTY（默认选项）。

**⑨ Default behavior of `git pull`（git pull 默认行为）**

选择 **`Fast-forward or merge`**（默认即可）。

**⑩ Configuring extra options（额外选项）**

保持默认，直接 Next 安装。

#### 验证安装

安装完成后，打开 PowerShell 或命令提示符，输入：

```bash
git --version
```

如果看到类似 `git version 2.47.0.windows.1` 的输出，说明安装成功。

### 2.2 全局配置（必须做！）

在你提交任何代码之前，必须先告诉 Git 你是谁。每次提交都会附带这个信息。

打开终端（PowerShell 或 Git Bash），输入：

```bash
git config --global user.name "你的姓名拼音"
git config --global user.email "你的邮箱@example.com"
```

例如：

```bash
git config --global user.name "Zhang San"
git config --global user.email "zhangsan@gmail.com"
```

> **注意**：邮箱填你在 GitHub 注册时用的邮箱，这样 GitHub 才能把提交和你的账号关联起来，在贡献图表上显示你的头像。

验证配置：

```bash
git config --list
```

应该能看到你刚才设置的 `user.name` 和 `user.email`。

### 2.3 注册 GitHub 账号

1. 打开 https://github.com
2. 点击 "Sign up" 注册
3. 填写用户名、邮箱、密码
4. 验证邮箱
5. 完成注册后，把用户名发给项目管理员，让他把你加入组织的仓库

### 2.4 配置 SSH Key（连接 GitHub 的安全方式）

有了 SSH Key，你就可以安全地连接到 GitHub，不需要每次都输密码。

#### 第 1 步：生成 SSH Key

打开终端（PowerShell 或 Git Bash），输入：

```bash
ssh-keygen -t ed25519 -C "你的邮箱@example.com"
```

程序会问你三个问题，全部**直接按回车**使用默认值即可：

```
Enter file in which to save the key (C:\Users\你的用户名/.ssh/id_ed25519):  ← 直接回车
Enter passphrase (empty for no passphrase):                               ← 直接回车
Enter same passphrase again:                                              ← 直接回车
```

> 如果你不设密码（passphrase），任何能访问你电脑的人都能用这个 key。如果担心安全，可以设一个密码，但每次 push 都要输。对初学者来说，直接留空即可。

#### 第 2 步：找到公钥文件

公钥文件在 `C:\Users\你的用户名\.ssh\id_ed25519.pub`。

用记事本打开它：

```bash
notepad C:\Users\你的用户名\.ssh\id_ed25519.pub
```

内容类似这样（以 `ssh-ed25519` 开头，以你的邮箱结尾）：

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... 你的邮箱@example.com
```

**全选复制**这段内容。

#### 第 3 步：添加到 GitHub

1. 打开 GitHub 网站，点击右上角头像 → **Settings**
2. 左侧菜单选择 **SSH and GPG keys**
3. 点击 **New SSH key**
4. Title 随便填（比如 "我的笔记本"）
5. Key type 选 **Authentication Key**
6. Key 框中粘贴刚才复制的内容
7. 点击 **Add SSH key**

#### 第 4 步：测试连接

在终端输入：

```bash
ssh -T git@github.com
```

如果看到：

```
Hi 你的用户名! You've successfully authenticated, but GitHub does not provide shell access.
```

恭喜，SSH 配置成功！看到 "successfully authenticated" 就是成功了，后面的 "does not provide shell access" 是正常的（GitHub 不允许你远程登录它的服务器）。

如果看到 `Permission denied (publickey)`，回头看第 2、3 步是否有遗漏。详细排查见[第 10 章](#1012-permission-denied-publickey——ssh-连接失败)。

### 2.5 VS Code 推荐插件

VS Code 是开发的主要编辑器，以下插件能让 Git 操作更方便：

| 插件 | 用途 |
|------|------|
| **GitLens** | 查看每行代码是谁写的、什么时候改的、为什么改的 |
| **Git Graph** | 可视化分支图，直观看到分支的合并历史 |
| **Git History** | 查看文件的修改历史 |

安装方法：VS Code 左侧 Extensions（Ctrl+Shift+X），搜索插件名，点击 Install。

### 2.6 GitHub Desktop（可选——命令行恐惧症的替代方案）

如果你对命令行感到恐惧，可以先安装 GitHub Desktop：

1. 下载：https://desktop.github.com/
2. 安装后登录你的 GitHub 账号
3. 基本操作都可以通过图形界面完成

**但强烈建议同时学习命令行**，因为：
- 遇到问题时，网上的解决方案 99% 是命令行
- 命令行更快，熟练后效率远超 GUI
- 有些高级操作 GUI 不支持

### 2.7 本章检查清单

安装配置完成后，逐条确认：

- [ ] `git --version` 能正常输出版本号
- [ ] `git config --list` 能看到 `user.name` 和 `user.email`
- [ ] `ssh -T git@github.com` 返回 "successfully authenticated"
- [ ] VS Code 已安装 GitLens 和 Git Graph 插件
- [ ] GitHub 账号已注册并告知管理员

全部通过？进入第 3 章。

---

## 第 3 章：克隆仓库与搭建工作区

### 3.1 获取仓库地址

1. 打开浏览器，登录 GitHub
2. 进入你被邀请加入的组织页面
3. 找到对应的仓库（比如 `campus_wall`）
4. 点击绿色的 **Code** 按钮
5. 选择 **SSH** 标签
6. 点击复制按钮（图标是两张纸叠在一起）

复制到的地址格式类似：

```
git@github.com:your-org/campus_wall.git
```

### 3.2 建议的本地目录结构

在开始克隆之前，先规划好本地的工作目录结构。建议如下：

```
E:\Code\project\campus-wall-workspace\    ← 工作空间根目录（手动创建）
├── campus_wall\                           ← 主后端
├── campus-wall-frontend\                  ← 用户端前端
├── campus-wall-monitor-ui\                ← 管理后台
├── campus-wall-ai\                        ← AI 服务（原 campus-wall-graphrag 已并入，端口 8011）
├── campus-wall-data-pipeline\             ← 数据管道
├── campus-wall-ops\                       ← 运维配置（含告警适配器 alert-adapter，原 campus-wall-alert-adapter 已并入）
└── docs\                                  ← 项目文档（本指南所在目录）
```

### 3.3 逐仓库克隆

打开终端（PowerShell），依次执行：

```powershell
# 创建并进入工作空间
New-Item -ItemType Directory -Force -Path E:\Code\project\campus-wall-workspace
Set-Location E:\Code\project\campus-wall-workspace

# 克隆每个仓库（⚠ 请把地址替换成你实际的仓库地址）
git clone git@github.com:your-org/campus_wall.git
git clone git@github.com:your-org/campus-wall-frontend.git
git clone git@github.com:your-org/campus-wall-monitor-ui.git
git clone git@github.com:your-org/campus-wall-ai.git      # AI 服务（原 campus-wall-graphrag 已并入，端口 8011）
git clone git@github.com:your-org/campus-wall-data-pipeline.git
git clone git@github.com:your-org/campus-wall-ops.git    # 运维配置（含告警适配器 alert-adapter，原 campus-wall-alert-adapter 已并入）
```

> **如果你的团队还没有在 GitHub 上创建这些仓库**，你需要先由管理员创建好仓库，再克隆。或者你可以先跳过本章，在本地开发，等仓库创建好后再关联远程。

### 3.4 克隆后验证

进入每个仓库，确认克隆成功：

```bash
cd campus_wall

# 查看远程仓库地址
git remote -v
# 预期输出：
# origin  git@github.com:your-org/campus_wall.git (fetch)
# origin  git@github.com:your-org/campus_wall.git (push)

# 查看最近的提交记录
git log --oneline -5

# 查看所有分支（本地 + 远程）
git branch -a
```

### 3.5 VS Code 多根工作区配置

校园墙项目有 6 个独立仓库，在 VS Code 中可以配置"多根工作区"，让所有仓库同时显示在侧边栏。

**操作方法**：

1. 打开 VS Code
2. 点击 **File** → **Open Folder...**
3. 选择 `E:\Code\project\campus-wall-workspace`
4. 点击 **File** → **Save Workspace As...**
5. 保存为 `campus-wall.code-workspace`（放在 workspace 根目录）

或者手动创建工作区文件 `campus-wall.code-workspace`：

```json
{
    "folders": [
        { "name": "后端 campus_wall", "path": ".\\campus_wall" },
        { "name": "用户端 campus-wall-frontend", "path": ".\\campus-wall-frontend" },
        { "name": "管理后台 campus-wall-monitor-ui", "path": ".\\campus-wall-monitor-ui" },
        { "name": "AI campus-wall-ai", "path": ".\\campus-wall-ai" },
        { "name": "数据管道 campus-wall-data-pipeline", "path": ".\\campus-wall-data-pipeline" },
        { "name": "运维 campus-wall-ops", "path": ".\\campus-wall-ops" },
        { "name": "文档 docs", "path": ".\\docs" }
    ]
}
```

> 环境搭建（Docker、数据库、启动服务等）详见[新人快速上手](../00-project-overview/04-新人快速上手.md)。本章只涉及 Git 层面的仓库克隆。

---

## 第 4 章：日常开发标准工作流

### 4.1 一天的标准流程全景图

```
早上开始工作
    │
    ▼
┌──────────────────────────────┐
│ git checkout main            │  切换到 main 分支
│ git pull origin main         │  拉取队友最新代码
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ git checkout -b feature/xxx  │  从最新 main 创建功能分支
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ 写代码 + 跑测试              │  反复循环，直到功能完成
│ （中间随时 git status 检查）  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ git status                   │  查看改了什么
│ git diff                     │  查看具体改了什么内容
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ git add 文件名               │  把改动加入暂存区（购物车）
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ git commit -m "feat: xxx"    │  提交到本地仓库（结账）
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ git push -u origin feature/xxx│ 推送到 GitHub
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ 在 GitHub 上创建 Pull Request│  请求合并到 main
└──────────────────────────────┘
```

下面逐步详解每一步。

### 4.2 开始工作前：同步最新代码

每天开始工作前，先同步团队的最新代码：

```bash
# 1. 切换到 main 分支
git checkout main

# 2. 拉取最新代码
git pull origin main

# 3. 查看最新提交，了解队友做了什么
git log --oneline -10
```

> **为什么先切到 main 再 pull？** 确保你基于最新的 main 创建新分支。如果你在功能分支上 pull main，容易产生混乱的合并记录。

### 4.3 创建功能分支

**永远不要在 main 分支上直接写代码！**

```bash
# 从最新的 main 切出一个功能分支
git checkout -b feature/你的功能名
```

例如：

```bash
git checkout -b feature/post-pin-to-top
```

分支命名规范详见[第 5 章](#第-5-章分支操作详解)。

### 4.4 写代码 + 查看状态

写代码的过程中，随时可以查看当前状态：

```bash
# 查看哪些文件被修改/新增/删除
git status

# 紧凑模式（更简洁）
git status -s
```

`git status` 的输出解读：

```
Changes to be committed:        ← 绿色，已在暂存区（git add 过了）
  modified:   src/main/java/PostController.java

Changes not staged for commit:  ← 红色，已修改但未暂存（还没 git add）
  modified:   src/main/java/PostService.java

Untracked files:                ← 红色，新文件，Git 还没追踪
  src/main/java/NewFeature.java
```

查看具体改了什么内容：

```bash
# 查看工作区未暂存的改动
git diff

# 查看已暂存（git add 过）的改动
git diff --staged

# 查看某个文件的改动
git diff src/main/java/PostController.java
```

### 4.5 暂存改动：git add

```bash
# 添加单个文件
git add src/main/java/com/jyu/campus/community/controller/PostController.java

# 添加整个目录
git add src/main/java/com/jyu/campus/community/

# 添加所有修改过的文件（⚠ 谨慎使用，会添加所有改动，包括你不想要的）
git add -A

# 交互式暂存 —— 逐块选择要添加的内容（进阶技巧）
git add -p
```

> **推荐**：使用 `git add 具体文件名`，逐个添加。这样可以避免不小心把调试代码、临时文件也提交了。

### 4.6 取消暂存

如果 `git add` 错了文件：

```bash
# 取消单个文件的暂存
git restore --staged 文件名

# 取消所有暂存
git restore --staged .
```

### 4.7 丢弃工作区修改

⚠ **危险操作！丢弃后无法恢复！**

```bash
# 丢弃单个文件的修改（恢复到最后一次 git add 或 git commit 的状态）
git restore 文件名

# 丢弃所有修改
git restore .
```

> 在执行 `git restore .` 之前，先 `git status` 确认你要丢弃的文件中没有重要改动。

### 4.8 提交：git commit

```bash
# 单行提交（简单功能）
git commit -m "feat(post): 添加帖子置顶功能"

# 打开编辑器写多行提交（推荐用于复杂功能）
git commit
```

Commit Message 的格式和规范详见[第 6 章](#第-6-章提交与-commit-message-规范)。

### 4.9 推送：git push

```bash
# 首次推送（建立本地分支和远程分支的追踪关系）
git push -u origin feature/你的功能名

# 后续推送（已经建立追踪关系后）
git push
```

`-u` 参数（`--set-upstream` 的缩写）只在第一次推送时需要。之后直接 `git push` 即可。

### 4.10 完整示例：修改一个后端 API

假设你要在帖子列表接口中增加一个 `viewCount`（浏览量）字段。以下是完整的 Git 操作流程：

```bash
# === 早上开始工作 ===

# 1. 切换到 main 并同步最新代码
cd E:\Code\project\campus-wall-workspace\campus_wall
git checkout main
git pull origin main

# 2. 创建功能分支
git checkout -b feature/post-view-count

# 3. 写代码...（在 IDEA 中编辑文件）
#    修改 PostController.java - 在返回的 PostVO 中增加 viewCount 字段
#    修改 PostService.java - 查询时增加浏览量字段
#    修改 PostMapper.xml - SQL 查询增加 view_count 字段

# 4. 查看状态
git status
# 输出：
#   modified:   src/main/java/.../controller/PostController.java
#   modified:   src/main/java/.../service/PostService.java
#   modified:   src/main/resources/mapper/PostMapper.xml

# 5. 查看具体改动
git diff

# 6. 确认无误，暂存并提交
git add src/main/java/com/jyu/campus/community/controller/PostController.java
git add src/main/java/com/jyu/campus/community/service/PostService.java
git add src/main/resources/mapper/PostMapper.xml

# 再次确认暂存区的内容
git diff --staged

# 7. 提交
git commit -m "feat(post): 帖子列表增加浏览量字段

- PostVO 新增 viewCount 字段
- PostService 查询时增加 view_count 字段
- PostMapper 对应 SQL 更新"

# 8. 推送到 GitHub
git push -u origin feature/post-view-count

# 9. 去 GitHub 网站创建 Pull Request（详见第 7 章）
```

### 4.11 中途保存进度（还没做完但需要暂停）

如果功能还没做完，但需要临时切到别的分支处理事情：

```bash
# 方法 1：git stash（暂存工作现场）
git stash                    # 暂存所有未提交的改动
git checkout 其他分支         # 去做别的事
git checkout feature/xxx     # 回来
git stash pop                # 恢复之前暂存的改动

# 方法 2：临时提交（还没做完也可以提交）
git add -A
git commit -m "WIP: 帖子置顶功能开发中"
# 之后继续开发...
git add -A
git commit -m "feat(post): 完成帖子置顶功能"
# 后续可以用 rebase 合并这两个提交（见第 6 章）
```

---

## 第 5 章：分支操作详解

### 5.1 分支是什么？

用人话解释：**分支就是一条独立的开发线**。

想象你在玩 RPG 游戏。在某个存档点，你决定尝试两条不同的路线：

```
        ┌→ 路线 A：走正门，结果被守卫抓了（game over，放弃这条线）
存档点 ─┤
        └→ 路线 B：翻墙进去，成功了！
             └→ 继续推进主线 ← 这条线变成了新的主线
```

Git 分支就是这个意思：

```
        ┌→ feature/login（开发登录功能）
main ──┤
        ├→ feature/post（开发帖子功能）──→ 合并回 main ──→ main 继续前进
        │
        └→ hotfix/bug（紧急修 bug）──→ 合并回 main ↗
```

- `main` 是主线（稳定版本，随时可以部署）
- 每个功能从 main 分叉出来，在自己的分支上独立开发
- 开发完成后合并回 main
- **分支之间互不影响**：你改你的登录功能，我改我的帖子功能，各干各的

### 5.2 校园墙项目分支规范

校园墙项目采用简化版 Git Flow，详见[开发规范](../01-development-standards/00-开发规范.md)。

| 分支类型 | 命名规则 | 用途 | 从哪切出 | 合并到哪 |
|----------|----------|------|----------|----------|
| **主分支** | `main` | 稳定版本，可直接部署 | — | — |
| **功能分支** | `feature/功能描述` | 开发新功能 | main | main |
| **热修复** | `hotfix/问题描述` | 紧急修复线上 Bug | main | main |
| **重构** | `refactor/重构描述` | 代码重构，不改功能 | main | main |

### 5.3 分支命名最佳实践

**好的命名**（见名知意）：

```
feature/post-pin-to-top        ← 帖子置顶功能
feature/user-avatar-upload      ← 用户头像上传
hotfix/login-token-expired      ← 登录 Token 过期
hotfix/comment-xss-fix          ← 评论 XSS 漏洞修复
refactor/post-service-layer     ← 重构帖子服务层
```

**不好的命名**（不知道干嘛的）：

```
feature/test          ← 测试什么？
my-branch             ← 谁的？干嘛的？
fix-bug               ← 修什么 bug？
zhangsan-branch       ← 不要用人名命名，用功能描述
feature/修改           ← 用英文命名，避免编码问题
```

**命名约定**：
- 全小写英文
- 单词之间用连字符 `-` 分隔，不要用下划线（`feature/post_pin` ❌）
- 简短但有描述性，控制在 3-5 个单词
- 如果功能对应某个 Issue，可以加编号：`feature/123-post-pin`

### 5.4 分支操作命令速查

```bash
# === 查看分支 ===
git branch                 # 查看本地分支列表，当前分支前有 * 号
git branch -a              # 查看所有分支（含远程）
git branch -r              # 仅查看远程分支

# === 创建分支 ===
git branch 分支名          # 创建分支（但不切换过去）
git checkout -b 分支名     # 创建并切换到新分支
git checkout -b feature/xxx main  # 从 main 切出新功能分支

# === 切换分支 ===
git checkout 分支名        # 切换到已有分支
git switch 分支名          # 新版 Git 推荐用法，和 checkout 等效

# === 删除分支 ===
git branch -d 分支名       # 安全删除（如果分支有未合并的内容会警告）
git branch -D 分支名       # 强制删除（⚠ 有未合并内容也会删除）
git push origin --delete 分支名  # 删除远程分支

# === 分支信息 ===
git branch -v              # 查看各分支最新提交
git branch --merged        # 查看已合并到当前分支的分支
git branch --no-merged     # 查看未合并到当前分支的分支
```

### 5.5 核心操作：在正确的时间创建正确的分支

```bash
# 场景 1：接到新功能任务 → 从 main 切出 feature 分支
git checkout main
git pull origin main
git checkout -b feature/post-pin

# 场景 2：线上出 Bug → 从 main 切出 hotfix 分支
git checkout main
git pull origin main
git checkout -b hotfix/login-token-expired

# 场景 3：需要重构旧代码 → 从 main 切出 refactor 分支
git checkout main
git pull origin main
git checkout -b refactor/post-service-cleanup
```

### 5.6 常见分支场景应对

#### 场景 A："糟糕，我忘记切分支，直接在 main 上改了代码！"

这是新手最容易犯的错误。别慌，代码不会丢：

```bash
# 1. 先暂存你的改动
git stash

# 2. 创建新分支
git checkout -b feature/my-feature

# 3. 恢复改动到新分支
git stash pop

# 现在你的改动在新分支上了，main 还是干净的
```

> 如果已经 `git commit` 了，用 `git reset HEAD~1` 撤销最近一次提交（改动保留在工作区），然后按上面步骤操作。

#### 场景 B："我切错分支了，在新分支上写了代码"

```bash
# 1. 暂存改动
git stash

# 2. 切换到正确分支
git checkout 正确的分支名

# 3. 恢复改动
git stash pop
```

> 如果正确分支还不存在，先创建它：`git checkout -b 正确的分支名 main`

#### 场景 C："功能分支开发了很久，main 已经更新了很多新代码"

```bash
# 在功能分支上执行：把 main 的最新代码合并进来
git checkout feature/my-feature
git merge main

# 或者用 rebase（保持提交历史线性，推荐）
git checkout feature/my-feature
git rebase main
```

> 如果 merge/rebase 出现冲突，不要慌，看[第 10 章第 4 节](#104-合并冲突最让人头疼的问题)。

### 5.7 分支生命周期图解

```
时间线 →

main:     ●────A────B──────────────●────C────●────D
          │                       ↑        ↑
          │           feature/login   hotfix/bug
          │              │              │
feature:  └──●──●──●──●──┘              │
                                        │
hotfix:                                 └──●──┘

A, B, C, D = main 上的合并提交（由 PR 合并产生）
```

1. 从 main 的某个点切出 `feature/login` 分支
2. 在 feature 分支上做了 4 次提交
3. 合并回 main，产生合并提交 B
4. 线上出了 bug，从 main 切出 `hotfix/bug`
5. 修了一行代码，合并回 main
6. main 继续前进

---

## 第 6 章：提交与 Commit Message 规范

### 6.1 为什么 Commit Message 很重要？

`git log` 就是项目的日记本。三个月后，没人记得当初为什么改那行代码。这时候只能翻 commit log。

**好的 commit message**：

```
feat(post): 添加帖子置顶功能

管理员可通过后台将帖子设为置顶，置顶帖在列表最前面展示。
新增 is_pinned 字段，通过 Redis 缓存置顶帖列表。
```

→ 一看就知道：加了什么功能、怎么实现的。

**坏的 commit message**：

```
fix bug
update
修改了一些东西
改
。
```

→ 三周后自己都看不懂当初改了什么。

### 6.2 校园墙 Commit Message 规范

采用 Conventional Commits 规范。详见[开发规范](../01-development-standards/00-开发规范.md)。

**格式**：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**各字段说明**：

| 字段 | 必需？ | 说明 |
|------|--------|------|
| **type** | ✅ 必需 | 改动类型，见下表 |
| **scope** | 推荐 | 改动范围（仓库 + 模块），见下表 |
| **subject** | ✅ 必需 | 简短描述（不超过 50 字），中文 |
| **body** | 可选 | 详细描述做了什么、为什么这样做 |
| **footer** | 可选 | 关联 Issue（`Closes #123`）、破坏性变更（`BREAKING CHANGE:`） |

### 6.3 Type 类型速查

| Type | 说明 | 使用场景 |
|------|------|----------|
| `feat` | 新功能 | 新增 API、新增页面、新增模块 |
| `fix` | 修复 Bug | 修了登录失败、修了数据错误 |
| `docs` | 文档更新 | 改了 README、开发文档 |
| `style` | 代码格式 | 统一缩进、删空格、加逗号（不影响逻辑） |
| `refactor` | 重构 | 重命名函数、提取公共逻辑、改目录结构 |
| `perf` | 性能优化 | 加缓存、优化 SQL、减少请求 |
| `test` | 测试 | 加单元测试、修改测试用例 |
| `chore` | 杂务 | 升级依赖、改配置文件、加 `.gitignore` |
| `ci` | CI/CD | 改 GitHub Actions 工作流 |

### 6.4 Scope 范围速查

#### campus_wall（后端）

| Scope | 对应模块 |
|-------|----------|
| `auth` | 认证授权（登录、JWT、微信 OAuth） |
| `post` | 帖子模块 |
| `comment` | 评论模块 |
| `user` | 用户模块 |
| `ai` | AI 模块（转发 campus-wall-ai，原 GraphRAG 已并入） |
| `admin` | 管理后台 API |
| `chat` | 私信/WebSocket |
| `config` | 配置相关（application.yml、环境变量） |

#### 前端仓库（campus-wall-frontend / campus-wall-monitor-ui）

| Scope | 对应模块 |
|-------|----------|
| `page/页面名` | 具体页面（如 `page/home`、`page/profile`） |
| `component/组件名` | 具体组件（如 `component/PostCard`） |
| `api` | 接口层 |
| `utils` | 工具函数 |
| `style` | 样式/主题 |

#### Python 仓库（campus-wall-ai / data-pipeline / alert-adapter）

| Scope | 说明 |
|-------|------|
| `api` | API 接口 |
| `core` | 核心逻辑 |
| `config` | 配置 |
| `data` | 数据处理 |

### 6.5 正反示例对比

**✅ 好的 commit message**：

```bash
# 1. 标准功能提交
git commit -m "feat(post): 添加帖子置顶功能

- Post 实体新增 is_pinned 字段
- 帖子列表查询时置顶帖优先排序
- 管理员可在后台操作置顶/取消置顶

Closes #42"

# 2. 简洁的 Bug 修复
git commit -m "fix(auth): 修复 JWT 过期后不自动刷新的问题

将 token 刷新逻辑从拦截器移到前端 axios 拦截器"

# 3. 重构——不改功能
git commit -m "refactor(post): 将帖子查询逻辑从 Controller 提取到 Service

Controller 层只负责参数校验和响应格式化，
业务逻辑全部移到 PostService"

# 4. 文档
git commit -m "docs: 添加 Git 协作开发指南"

# 5. 跨模块修改
git commit -m "feat(ai): AI 问答支持多轮对话

- 前端 ai 页面增加对话历史展示
- 后端 /ai/chat 接口增加 conversationId 参数
- campus-wall-ai（原 GraphRAG）服务增加 /chat/history 接口"
```

**❌ 坏的 commit message**（禁止使用）：

```bash
git commit -m "fix"              # fix 什么？
git commit -m "update"           # update 什么？
git commit -m "改了一些东西"     # 改了什么？
git commit -m "修改"             # 毫无信息量
git commit -m "111"              # ？？？
git commit -m "WIP"              # 开发中的临时提交可以，但合并前应当整理
git commit -m "feat: 新增功能"   # 缺少 scope
```

### 6.6 实用命令

```bash
# 单行提交（简单的改动）
git commit -m "feat(post): 添加帖子置顶功能"

# 多行提交（复杂的改动，推荐）
git commit
# 这会打开你配置的默认编辑器（VS Code），你可以写详细的 body

# 合并到上一次提交（用于修正笔误或补加漏掉的文件）
git add 漏掉的文件
git commit --amend --no-edit    # 追加到上一次提交，不改 message
git commit --amend              # 追加到上一次提交，并修改 message

# ⚠ git commit --amend 只适用于还没 push 的提交
# 如果已经 push 了，且其他人可能已经基于你的提交工作，绝对不要 amend！
```

### 6.7 查看提交历史

```bash
# 完整历史（按 j/k 翻页，按 q 退出）
git log

# 一行一提交（最常用）
git log --oneline

# 最近 10 条
git log --oneline -10

# 显示分支图
git log --oneline --graph --all

# 只看某个人的提交
git log --oneline --author="Zhang San"

# 只看某个文件的提交历史
git log --oneline -- src/main/java/PostController.java

# 查看某次提交的详细内容
git show 提交哈希值
# 例如：git show a1b2c3d
```

### 6.8 提交频率建议

- **不要太频繁**：不要每改一行就 commit 一次
- **不要太少**：不要攒了 3 天的代码才 commit 一次
- **好的粒度**：完成一个可独立描述的小功能点就 commit 一次
  - 比如"增加了数据库字段 + Mapper 查询"可以是一个 commit
  - "增加了接口 + Service 逻辑 + 测试"可以是下一个 commit
- **保证每个 commit 都能编译通过**：不要提交一个编译报错的中间状态

---

## 第 7 章：Pull Request 全流程

### 7.1 Pull Request 是什么？

Pull Request（简称 PR）是 GitHub 上团队协作的核心机制。

**用生活场景解释**：

> 你是一个班里的学生，老师（main 分支）只接受经过班长审查的作业。
>
> 你写完作业后，不是直接塞到老师的办公桌上，而是：
> 1. 先提交一份"请求批改"
> 2. 班长（Reviewer）检查你的作业
> 3. 有错就改，没错就通过
> 4. 班长把通过的作业交到老师桌上（合并到 main）

PR 就是那个"请求批改"的流程。

### 7.2 PR 的完整生命周期

```
创建 PR → 等待 Review → Reviewer 提修改意见 → 你改代码并 push → PR 自动更新
                                                              ↓
                                         Reviewer 再次审查 → 通过 → 合并到 main
                                                              ↓
                                                         删除功能分支（清理）
```

### 7.3 创建 PR 的前置条件

在创建 PR 之前，确保你已经：

1. 在功能分支上完成了开发
2. 本地测试通过
3. 已经把分支 push 到 GitHub：`git push -u origin feature/xxx`

### 7.4 创建 PR 步骤

#### Step 1：打开 GitHub 仓库页面

进入你的仓库页面（比如 `github.com/your-org/campus_wall`）。

Push 之后，GitHub 通常会在页面顶部显示一个黄色提示条：

> `feature/post-pin` had recent pushes less than a minute ago
>
> [Compare & pull request]

点击 **Compare & pull request** 按钮即可。

如果没有提示条，手动操作：

1. 点击顶部的 **Pull requests** 标签
2. 点击绿色的 **New pull request** 按钮

#### Step 2：选择分支

- **base**（目标）：选择 `main` — 你要合并到哪个分支
- **compare**（来源）：选择你的功能分支，如 `feature/post-pin`

GitHub 会展示两个分支之间的差异（diff），你可以在这里预览所有的改动。

#### Step 3：填写 PR 信息

**标题**：与 commit message 的 subject 保持一致

```
feat(post): 添加帖子置顶功能
```

**描述**：使用以下模板填写

```markdown
## 做了什么

- Post 实体新增 is_pinned 字段
- 帖子列表查询时置顶帖优先排序
- 管理员可在后台操作置顶/取消置顶

## 为什么这样做

运营需求：社团活动帖、重要通知帖需要长期置顶在列表顶部

## 测试情况

- [x] 本地测试通过（Postman 接口测试）
- [x] 数据库迁移正常（Flyway 脚本已验证）
- [x] Redis 缓存逻辑正常
- [x] 管理员后台置顶/取消置顶流程完整体验

## 截图

（如果是 UI 改动，粘贴前后对比截图）

## 关联 Issue

Closes #42
```

#### Step 4：创建 PR

点击绿色的 **Create pull request** 按钮。

如果是开发中、还没完全做完的 PR，点击下拉箭头选择 **Create draft pull request**（草稿 PR）。

### 7.5 Draft PR（草稿 PR）

**什么时候用 Draft PR**：

- 功能还在开发中，想提前让队友看到代码思路
- 需要队友在开发过程中给出早期反馈
- 表示"我知道还不完整，别急着合并"

**操作**：

- 创建 PR 时，点击 "Create pull request" 旁边的下拉箭头，选择 **Create draft pull request**
- Draft PR 无法被合并
- 开发完成后，点击 PR 页面上的 **Ready for review** 转为正式 PR

### 7.6 PR 创建后的追踪

创建 PR 后，你会看到：

- **Reviewers**：谁被指定审查（通常自动分配或手动指定）
- **Labels**：标签（如 `backend`、`frontend`）
- **Checks**：如果配置了 CI/CD（GitHub Actions），会自动运行测试

关注以下状态：

| 状态 | 含义 |
|------|------|
| 🟡 黄色圆点 | CI 正在运行 |
| 🟢 绿色勾 | CI 通过 |
| 🔴 红色叉 | CI 失败，需要修复 |
| 💬 评论图标 | 有人提了 Review 意见 |
| 🔒 锁定图标 | 有 unresolved 的评论 |

### 7.7 更新 PR（收到修改意见后）

Reviewer 提了修改意见后，你需要在本地修改代码，然后推送更新：

```bash
# 1. 确保在正确的功能分支上
git checkout feature/post-pin

# 2. 修改代码...

# 3. 提交
git add .
git commit -m "fix: 根据 review 意见修改置顶排序逻辑"

# 4. 推送
git push
# 推送后，PR 会自动更新！不需要重新创建 PR
```

在 PR 页面上回复 Reviewer 的评论：点击评论旁边的回复按钮，说明你做了什么修改。

**沟通礼仪**：

- 收到批评不要 defensive（防卫心态），Review 是互相学习的过程
- 如果你认为自己的做法有道理，礼貌地解释设计理由
- 如果 Reviewer 说的对，大方承认并修改
- 不确定的可以讨论，达成共识后再改

---

## 第 8 章：代码审查与合并

### 8.1 为什么要做 Code Review？

- **发现 Bug**：自己写的 bug 自己最难发现，第二双眼睛能看出你疏忽的问题
- **知识分享**：Reviewer 了解你在做什么，你也从 Reviewer 的建议中学习
- **代码风格统一**：保证项目代码风格一致，不会出现"这段一看就是张三写的"
- **新人成长**：Review 是新成员熟悉项目最快的方式之一

### 8.2 Reviewer 操作指南

#### Step 1：打开 PR

1. 在 GitHub 仓库页面点击 **Pull requests**
2. 找到需要审查的 PR
3. 先读 PR 描述，了解这个 PR 是干什么的

#### Step 2：查看改动

点击 **Files changed** 标签页，这里显示所有的代码改动。

- 🟢 绿色背景 = 新增的代码
- 🔴 红色背景 = 删除的代码

#### Step 3：添加评论

**行内评论**（针对某一行的具体问题）：

1. 鼠标悬停在代码行号上，会出现一个蓝色 `+` 按钮
2. 点击 `+` 按钮，输入你的评论
3. 点击 **Start a review**（开始一次审查）或 **Add single comment**（仅添加一条评论）

**文件级评论**（针对整个文件）：

在文件 diff 的标题栏右侧，点击评论图标。

**总评论**（综合意见）：

在 PR 页面的 Conversation 标签页底部，有一个评论框。

#### Step 4：提交 Review 决定

在 Files changed 页面，点击右上角绿色的 **Review changes** 按钮：

| 选项 | 含义 | 什么时候用 |
|------|------|-----------|
| **Comment** | 仅评论，不表态 | 随便看看，提点建议，不做审批决定 |
| **Approve** | 批准，可以合并 | 代码没问题，同意合并 |
| **Request changes** | 要求修改 | 有必须修改的问题，不修不能合并 |

> 注意：Request changes 会阻止 PR 合并。只在有明确需要修改的问题时使用。小建议、可选的优化用 Comment。

### 8.3 Reviewer 审查要点

参考[开发规范](../01-development-standards/00-开发规范.md)中的审查 Checklist：

- [ ] 代码符合命名规范（Java 小驼峰、Vue 组件大驼峰等）
- [ ] 关键逻辑有注释说明（复杂算法、业务规则）
- [ ] 无硬编码密钥、密码、Token（使用环境变量）
- [ ] 异常处理完善（不会因为一个数据异常导致整个服务挂了）
- [ ] 无 `System.out.println`（Java 后端用日志框架）
- [ ] 数据库查询有索引支持（新增的 WHERE 条件字段需要检查）
- [ ] 敏感操作有权限校验（管理员操作检查角色）
- [ ] Commit message 符合规范
- [ ] 逻辑是否正确（边界条件考虑了没？null 处理了没？）
- [ ] 是否有安全风险（SQL 注入、XSS、未脱敏的用户数据）

### 8.4 Author 如何响应 Review

收到 Review 意见后：

1. **逐条回复**：在每一条评论下回复，说明你的处理方式
2. **修改代码**：在本地功能分支上改代码
3. **重新推送**：`git add` → `git commit` → `git push`
4. **请求重新审查**：在 PR 页面的评论区 `@reviewer` 告知已修改
5. **标记已解决**：如果 Reviewer 的评论已处理，点击 **Resolve conversation**

### 8.5 合并 PR 的三种方式

当 Review 通过后，PR 页面上会出现绿色的 **Merge pull request** 按钮。点击下拉箭头可以选择合并方式：

| 方式 | 效果 | 历史记录 | 推荐场景 |
|------|------|----------|----------|
| **Create a merge commit** | 创建一个合并提交，保留所有原始提交 | 完整但可能杂乱 | 功能分支有多个人协作时 |
| **Squash and merge** | 把所有提交压缩成一个，再合并 | 干净，一个 PR 一个 commit | ✅ **本项目推荐方式** |
| **Rebase and merge** | 把分支上的提交"重放"到 main 顶端 | 线性，无合并提交 | 想保持完全线性历史时 |

**校园墙项目推荐使用 Squash and merge**，原因：

- main 分支干净整洁，一个功能一个 commit
- 即使你开发过程中有 "WIP"、"fix typo" 的琐碎提交，合并后都会被压缩成一个规范的 commit
- 方便回溯：看到 main 上的每个 commit 就代表一个完整功能

### 8.6 合并后清理分支

PR 合并后，GitHub 通常会提示 Delete branch，点击即可删除远程分支。

本地清理：

```bash
# 1. 切换到 main
git checkout main

# 2. 拉取最新 main（包含你刚合并的 PR）
git pull origin main

# 3. 删除本地功能分支
git branch -d feature/post-pin

# 4. 查看本地还有哪些已合并的分支
git branch --merged

# 5. 清理远程已合并的分支（如果 GitHub 上没有自动删除）
git push origin --delete feature/post-pin
```

### 8.7 合并冲突简介

当两个人改了同一个文件的同一行代码时，Git 不知道应该保留谁的版本，这就是**冲突（Conflict）**。

```
你改了 PostController.java 的第 42 行
队友也改了 PostController.java 的第 42 行
→ Git 说："我不知道留谁的！" → 冲突
```

关于冲突的详细解决步骤，见[第 10 章第 4 节](#104-合并冲突最让人头疼的问题)。

---

## 第 9 章：多仓库模块化开发

> ⭐ 本章是校园墙项目协作的**核心章节**。如果你只认真读一章，就读这章。

### 9.1 校园墙 6 仓库结构总览

校园墙项目采用"多仓库模块化"架构，每个子模块有独立的 Git 仓库：

```
┌──────────────────────────────────────────────────────┐
│                    GitHub 组织                         │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ campus_wall  │  │ frontend     │  │ monitor-ui │ │
│  │   (后端)     │  │  (用户端)    │  │  (管理后台) │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │ campus-wall-ai│  │ data-pipeline│  │     ops     │ │
│  │ (AI服务:8011) │  │  (数据管道)  │  │  (运维配置) │ │
│  └──────────────┘  └──────────────┘  └────────────┘ │
│                                                      │
│  注：告警适配器 alert-adapter 已并入 ops/alert-adapter/ │
└──────────────────────────────────────────────────────┘
```

**为什么是多仓库而不是一个仓库？**

| 对比 | 单仓库（Monorepo） | 多仓库（当前方案） |
|------|-------------------|-------------------|
| 权限控制 | 所有人能看所有代码 | 可以按模块分配权限 |
| 独立部署 | 耦合在一起 | ✅ 各模块独立部署 |
| 技术栈隔离 | Java 和 Python 混在一个仓库 | ✅ 每个仓库独立的技术栈 |
| 提交历史 | 所有人的提交混在一起 | ✅ 每个仓库的提交历史干净 |
| 协作复杂度 | 冲突概率低 | ⚠ 跨仓库改动需要协调 |

### 9.2 模块分工表

| 仓库 | 建议负责人数 | 主要职责 |
|------|-------------|----------|
| `campus_wall` | 1-2 人 | 后端核心业务逻辑、API 接口 |
| `campus-wall-frontend` | 1-2 人 | 用户端 H5 + 微信小程序 |
| `campus-wall-monitor-ui` | 1 人 | 管理后台（数据概览 + 审核） |
| `campus-wall-ai` | 1 人 | AI 知识图谱 + 问答接口（原 campus-wall-graphrag 已并入，端口 8011） |
| `campus-wall-data-pipeline` | 1 人 | 数据采集、清洗、脱敏、写入 |
| `campus-wall-ops` | 1 人 | Docker Compose、Nginx、监控面板、告警通知转发（alert-adapter，原 campus-wall-alert-adapter 已并入） |

> 初期可以一人负责 1-2 个模块。后端和前端的负责人需要密切沟通 API 接口格式。

### 9.3 日常多仓库操作

#### VS Code 多根工作区

在第 3 章已经配置了多根工作区，所有 6 个仓库都在同一个 VS Code 窗口中可见。

**重要习惯**：每次在终端执行 git 命令前，先确认当前在哪个仓库目录下！

```bash
# 切换仓库前，先 pwd 确认当前位置
pwd
# 输出：E:\Code\project\campus-wall-workspace\campus_wall

# 要操作前端仓库，需要先 cd 过去
cd ..\campus-wall-frontend
```

> 多仓库环境下最常见的错误：以为在后端目录，实际在前端目录，然后 `git push` 推到错误的仓库。

#### 每个仓库独立操作

每个仓库有独立的 Git 历史、独立的分支、独立的 PR。操作流程完全一样：

```bash
# 在 campus_wall 中开发后端功能
cd campus_wall
git checkout -b feature/post-pin main
# ... 写代码 ...
git add .
git commit -m "feat(post): 添加帖子置顶功能"
git push -u origin feature/post-pin
# 去 GitHub campus_wall 仓库创建 PR

# 然后在 campus-wall-frontend 中开发对应的前端功能
cd ..\campus-wall-frontend
git checkout -b feature/post-pin-ui main
# ... 写代码 ...
git add .
git commit -m "feat(page/home): 首页帖子列表支持置顶展示"
git push -u origin feature/post-pin-ui
# 去 GitHub campus-wall-frontend 仓库创建 PR
```

### 9.4 跨仓库协作关键场景

#### 场景 A：后端新增 API，前端对接

这是最常见的跨仓库协作场景。

**正确流程**：

1. 先在 GitHub Issue 中确定 API 接口格式
   ```
   Issue: [后端+前端] 添加帖子置顶功能
   
   API: POST /api/admin/post/{id}/pin
   参数: { "pinned": true }
   返回: { "code": 200, "message": "success", "data": { "id": 123, "isPinned": true } }
   ```

2. 后端同学在 `campus_wall` 开发并提 PR
3. 前端同学在 `campus-wall-frontend` 开发对应页面并提 PR
4. 两个 PR 可以独立合并，先后顺序无所谓（前端可以先用 Mock 数据）

**错误做法**：

- 后端默默改完接口，不说一声 → 前端发现调用失败 → 沟通成本加倍
- 前后端都没定接口格式就开始各写各的 → 最后发现对不上 → 返工

#### 场景 B：campus-wall-ai（原 GraphRAG 已并入）接口变更，后端需要同步

```
┌─────────────────────┐          ┌─────────────────────┐
│   campus-wall-ai     │          │     campus_wall      │
│   (原 GraphRAG:8011) │          │                     │
│  /query 接口变更     │ ──────→ │  AiService.java     │
│  返回格式变了         │  通知    │  解析逻辑需要更新     │
└─────────────────────┘          └─────────────────────┘
```

**流程**：

1. campus-wall-ai 负责人在 PR 描述中说明接口变更的具体内容
2. 后端负责人在 Issue 下回复确认收到
3. campus-wall-ai 的 PR 合并后，后端立即更新对应的解析代码
4. 后端的 Commit Message 中注明：`fix(ai): 适配 campus-wall-ai /query 接口 v2 格式`

#### 场景 C：运维配置变更，需要通知全员

```bash
# campus-wall-ops 修改了 docker-compose.yml
# 比如改了 MySQL 端口从 3306 → 3307
```

**流程**：

1. Ops 负责人修改后提 PR，在描述中说明影响范围
2. 合并后，**在团队群聊中公告**："MySQL 端口已改为 3307，所有人拉取最新 campus-wall-ops，重启 Docker"
3. 所有开发者执行：
   ```bash
   cd campus-wall-ops
   git pull origin main
   docker-compose down && docker-compose up -d
   ```

### 9.5 端口分配速查表

各服务的默认端口，开发时避免冲突：

| 服务 | 端口 | 所属仓库 |
|------|------|----------|
| 主后端 API | 8080 | campus_wall |
| 用户端前端 Dev Server | 5173 | campus-wall-frontend |
| 管理后台 Dev Server | 5174 | campus-wall-monitor-ui |
| AI 服务 API | 8011 | campus-wall-ai（原 GraphRAG :8001 已并入/下线） |
| 告警适配器 | 8002 | campus-wall-ops（alert-adapter，原 campus-wall-alert-adapter 已并入） |
| MySQL | 3306 | campus-wall-ops |
| Redis | 6379 | campus-wall-ops |
| MinIO API | 9000 | campus-wall-ops |
| MinIO Console | 9001 | campus-wall-ops |
| Neo4j HTTP | 7475 | campus-wall-ops |
| Neo4j Bolt | 7688 | campus-wall-ops |
| Prometheus | 9090 | campus-wall-ops |
| Grafana | 3000 | campus-wall-ops |
| Alertmanager | 9093 | campus-wall-ops |
| Nginx (监控代理) | 8090 | campus-wall-ops |
| Ollama | 11434 | 本地安装 |

> **规则**：新增服务时，先在 teams 里确认端口不冲突，再写进代码。

### 9.6 跨仓库 Commit Message 关联建议

如果一次功能涉及多个仓库，在各自的 commit body 中注明关联的仓库和 PR 编号：

**后端 commit**：

```
feat(post): 添加帖子置顶功能

- Post 实体新增 is_pinned 字段
- 新增 POST /api/admin/post/{id}/pin 接口

前端对应 PR: campus-wall-frontend#78
```

**前端 commit**：

```
feat(page/home): 首页帖子列表支持置顶展示

- PostCard 组件增加置顶标识
- 置顶帖带红色置顶角标

后端对应 PR: campus_wall#156
```

### 9.7 新人上手顺序建议

新加入团队时，不需要一下子了解所有 6 个仓库。建议按以下顺序逐步深入：

```
第 1 步：环境搭建（1 天）
├── 安装 Docker、JDK、Node.js、Python
├── 克隆 campus-wall-ops，启动基础设施
└── 确认 MySQL、Redis、MinIO 都能访问

第 2 步：熟悉核心后端（2-3 天）
├── 克隆 campus_wall
├── 在 IDEA 中启动后端服务
├── 了解 Controller → Service → Mapper 的调用链路
└── 第一个任务：在现有 API 中增加一个小字段

第 3 步：熟悉前端（按分配决定，2-3 天）
├── 如果你负责用户端 → campus-wall-frontend
├── 如果你负责管理后台 → campus-wall-monitor-ui
└── 第一个任务：修改一个页面样式或增加一个展示字段

第 4 步：了解其他模块（按需，1-2 天）
├── 按你的任务分配到 campus-wall-ai / data-pipeline / campus-wall-ops（含 alert-adapter）
└── 阅读对应仓库的 README.md 和 CLAUDE.md
```

### 9.8 多仓库常见陷阱

> 以下是团队成员在实际开发中最容易踩的坑，先看完再开始写代码。

#### 陷阱 1：在错误的仓库目录下执行 Git 命令

```bash
# 你以为在后端目录
cd campus_wall
git checkout -b feature/login

# 但实际光标还在前端目录（cd 命令没执行成功或忘了 cd）
# → 在前端仓库创建了 feature/login 分支！
```

**预防**：
- 执行 git 命令前，看一眼终端提示符显示的当前目录
- VS Code 状态栏左下角会显示当前仓库名
- 养成习惯：重要操作（commit、push）前先 `pwd` 确认

#### 陷阱 2：忘记拉取某个仓库的最新 main

```bash
# 你基于 3 天前的 campus_wall main 写了新功能
# 但这 3 天里队友已经合并了 5 个 PR
# → 你的分支落后了，合并时可能出冲突
```

**预防**：
- 每天开始工作前，对你负责的所有仓库执行 `git pull origin main`
- 如果你负责多个仓库，写一个简单的批处理脚本

#### 陷阱 3：前后端接口格式不一致

```
后端返回: { "data": { "postId": 1, "title": "hello" } }
前端期望: { "data": { "id": 1, "title": "hello" } }
→ 前端取不到数据，排查半天发现字段名对不上
```

**预防**：
- 开 Issue 约定接口格式，把请求参数和响应字段都写清楚
- 后端改响应格式时，在 PR 描述中醒目说明
- 前端对接时，先 `console.log` 或 debug 看一下实际返回的数据

#### 陷阱 4：Docker 端口冲突

```
你本地跑了一个 MySQL 在 3306
campus-wall-ops 的 docker-compose 也启动了一个 MySQL 在 3306
→ 端口冲突，一个启动失败
```

**预防**：
- 启动 Docker 前确认端口未被占用：`netstat -ano | findstr 3306`
- 如果冲突，修改 `campus-wall-ops/.env` 中的端口映射

---

## 第 10 章：常见错误与故障排除

> 本章是急救手册。遇到问题时，先来这里翻。每个错误都包含：错误信息 → 原因分析 → 解决步骤。

### 10.1 `fatal: not a git repository`

**错误信息**：

```
fatal: not a git repository (or any of the parent directories): .git
```

**原因**：你在一个不是 Git 仓库的目录下执行了 git 命令。

**解决**：

```bash
# 1. 确认当前目录
pwd

# 2. cd 到正确的仓库目录
cd E:\Code\project\campus-wall-workspace\campus_wall

# 3. 确认这里有 .git 文件夹
ls .git
# 或用 dir（PowerShell）：
Get-ChildItem .git -Force
```

> 每个 Git 仓库的根目录下都有一个隐藏的 `.git` 文件夹，它是 Git 的数据库。如果没有这个文件夹，说明你不在仓库里，或者还没克隆。

### 10.2 `remote origin already exists`

**错误信息**：

```
error: remote origin already exists.
```

**原因**：已经关联过远程仓库了，不能重复添加。

**解决**：

```bash
# 查看当前远程地址
git remote -v

# 如果需要修改远程地址
git remote set-url origin git@github.com:your-org/新地址.git

# 如果需要删除重新添加
git remote remove origin
git remote add origin git@github.com:your-org/仓库名.git
```

### 10.3 `failed to push some refs`（远程有更新）

**错误信息**：

```
error: failed to push some refs to 'git@github.com:your-org/campus_wall.git'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

**原因**：你 push 之前，别人已经往同一个分支推送了新提交。你的本地版本落后了。

**解决**：

```bash
# 方法 1：先拉取再推送（推荐）
git pull --rebase origin main
git push

# 方法 2：如果 pull 有冲突，先处理冲突再 push
git pull origin main
# 处理冲突...
git add .
git commit -m "merge: 合并远程 main 更新"
git push
```

### 10.4 合并冲突（最让人头疼的问题）

#### 什么是冲突

当两个人改了**同一个文件的同一行**，Git 无法自动判断应该保留谁的版本。

```
Git 视角：
  "张三把第 42 行改成了 A"
  "李四也把第 42 行改成了 B"
  "我不知道该留哪个！人类，你来决定！"
```

#### 冲突长什么样

发生冲突后，打开文件会看到这样的标记：

```java
<<<<<<< HEAD
    System.out.println("Debug: user token = " + token);  // 你当前的代码
=======
    log.debug("用户登录成功, userId={}", userId);          // 别人合并进来的代码
>>>>>>> main
```

冲突标记的含义：

```
<<<<<<< HEAD         ← 冲突开始，下面是"你的版本"
（你当前分支的代码）
=======              ← 分隔线
（要合并进来的代码）
>>>>>>> main        ← 冲突结束，这是"别人的版本"的标签
```

#### 解决冲突的步骤

**方法 A：手动编辑（最可靠）**

```bash
# 1. 查看哪些文件有冲突
git status
# 标红且显示 "both modified" 的就是冲突文件

# 2. 在 VS Code 中打开冲突文件
# VS Code 会自动高亮冲突区域，并提供按钮：
#   - "Accept Current Change"  ← 保留你的
#   - "Accept Incoming Change" ← 保留别人的
#   - "Accept Both Changes"    ← 两个都要
#   - "Compare Changes"        ← 对比查看

# 3. 逐文件解决冲突后，标记为已解决
git add 冲突文件名

# 4. 所有冲突解决后，继续合并
git commit -m "merge: 合并 main 到 feature/post-pin"
# 或者如果是 rebase：
git rebase --continue
```

**方法 B：VS Code 图形界面（推荐新手使用）**

1. 打开冲突文件
2. VS Code 会用不同颜色高亮冲突区域
3. 点击 `Accept Current Change` 或 `Accept Incoming Change` 按钮
4. 保存文件
5. 在 Source Control 面板中点击 `+` 暂存已解决的冲突文件

#### 放弃合并

如果冲突太复杂，你暂时不想处理：

```bash
# 放弃 merge
git merge --abort

# 放弃 rebase
git rebase --abort
```

回到冲突前的状态，之后找队友一起处理。

#### 预防冲突

- 每天开始工作前 `git pull`，保持本地最新
- 不要在一个分支上攒太久才合并
- 多人操作同一模块时，提前沟通谁在改什么文件

### 10.5 `detached HEAD` 状态

**错误信息**：

```
You are in 'detached HEAD' state.
HEAD is now at a1b2c3d feat(post): 添加帖子置顶功能
```

**原因**：你 checkout 到了某个具体的 commit，而不是一个分支名。HEAD 指向了一个具体的提交，不跟在任何分支后面。

**危险**：在 detached HEAD 状态下的提交可能会丢失（当切换到其他分支后，没有指针指向这些提交）。

**解决**：

```bash
# 如果还没做任何提交
git checkout main

# 如果已经做了提交，先创建分支保存工作
git checkout -b 临时分支名
# 现在你的提交都在这个分支上了，安全了

# 如果已经切换走了，用 reflog 找回
git reflog
# 找到你之前提交的哈希值
git checkout -b 恢复分支 提交哈希值
```

### 10.6 误提交了不该提交的文件

**场景**：不小心把 `.env`（含密钥）、`node_modules/`、大文件等提交了。

**解决方案（按严重程度递进）**：

```bash
# 情况 1：还没 push，只是本地 commit
# 撤销最近一次 commit，改动回到暂存区
git reset --soft HEAD~1
# 然后把不该提交的文件从暂存区移除
git restore --staged .env
git restore --staged node_modules/
# 修改 .gitignore 加上这些文件
echo ".env" >> .gitignore
echo "node_modules/" >> .gitignore
# 重新提交
git add .gitignore
git commit -m "chore: 更新 .gitignore，排除敏感文件"

# 情况 2：已经 push 了，但只有你一个人用这个分支
git reset --soft HEAD~1
git restore --staged .env  # 移除敏感文件
git commit -m "chore: 移除误提交的敏感文件"
git push --force-with-lease
# ⚠ force push 有风险，仅在确认没有别人基于你的分支工作时使用！

# 情况 3：已经 push 且合并了，或者有别人在协作
# 使用 git revert 创建新的"反向提交"
git revert HEAD
git push
# 然后在 GitHub 上确认敏感文件已经不在仓库中
```

> ⚠ 如果敏感信息（密钥、密码、Token）已经推送到 GitHub，即使删除了文件，它仍然存在于 git 历史中。需要立即轮换（更换）泄露的密钥。GitHub 有 secrets scanning 会自动检测到。

### 10.7 `git pull` 后出现奇怪的合并提交

**场景**：你本地有未 push 的 commit，直接 `git pull` 后多了一个自动生成的合并提交：

```
Merge branch 'main' of github.com:your-org/campus_wall
```

**原因**：`git pull` = `git fetch` + `git merge`。当本地和远程都有各自的提交时，Git 自动创建合并。

**预防**（养成好习惯）：

```bash
# 使用 rebase 代替 merge，保持历史线性
git pull --rebase

# 或者在 push 之前先 pull
git pull --rebase origin main
git push
```

### 10.8 push 了错误的 Commit Message

**场景**：commit message 打错字了，或者忘了加 scope。

```bash
# 情况 1：还没 push（仅本地）
git commit --amend -m "feat(post): 添加帖子置顶功能（修正）"

# 情况 2：已经 push，但只有你一个人用这个分支
git commit --amend -m "feat(post): 添加帖子置顶功能（修正）"
git push --force-with-lease
# ⚠ 小心！force push 可能覆盖队友的提交

# 情况 3：已经 push 且已合并到 main
# 不要 amend 了。main 历史不应被改写。
# 做个新的 fixup commit：
# 就当没看见那个 typo...（只要不是严重影响理解的错误）
```

> **`git push --force-with-lease` vs `git push --force`**：`--force-with-lease` 更安全，如果有人在你上次 pull 之后推送了新提交到同一个分支，它会拒绝 force push，防止你意外覆盖队友的代码。

### 10.9 checkout 时提示有未保存的修改

**错误信息**：

```
error: Your local changes to the following files would be overwritten by checkout:
    src/main/java/PostController.java
Please commit your changes or stash them before you switch branches.
```

**原因**：你改了文件但还没 commit，直接切换到别的分支会覆盖你的改动。

**解决**：

```bash
# 方法 1：暂存改动（最常用）
git stash                     # 暂存
git checkout 目标分支          # 切换
git stash pop                 # 恢复

# 方法 2：先临时提交
git add -A
git commit -m "WIP: 临时保存"
git checkout 目标分支

# 方法 3：放弃改动（⚠ 不可恢复）
git restore .
git checkout 目标分支
```

### 10.10 想撤销已经 push 的 commit

```bash
# 安全方法：git revert（推荐）
# 创建一个"反向提交"来撤销，不修改历史
git revert 提交哈希值
git push
# 例如：git revert a1b2c3d
# 效果：创建一个新 commit，内容是 a1b2c3d 的逆向操作

# 危险方法：git reset + force push（仅限 solo 分支！）
# 直接删除提交历史
git reset --hard HEAD~1  # 删除最近 1 个 commit
git push --force-with-lease
# ⚠ 如果有人已经基于被你删除的提交工作，会造成大麻烦
```

**原则**：
- main 分支上的提交 → 用 `git revert`（绝不 force push main）
- 只有你自己用的功能分支 → 可以用 `git reset` + `force push`

### 10.11 `.gitignore` 不生效

**场景**：在 `.gitignore` 中加了 `*.log`，但 `git status` 还是显示 log 文件被追踪。

**原因**：`.gitignore` 只对**未被 Git 追踪**的文件生效。文件一旦被 `git add` 过，就会一直被 Git 追踪，即使你后来把它加到 `.gitignore` 中。

**解决**：

```bash
# 先从 Git 追踪中移除（但不删文件）
git rm --cached 文件名

# 批量移除一类文件
git rm --cached *.log

# 然后提交这个移除
git commit -m "chore: 停止追踪 log 文件"
```

### 10.12 `Permission denied (publickey)` —— SSH 连接失败

**错误信息**：

```
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

**原因**：SSH 认证失败，GitHub 不认识你的电脑。

**排查步骤**：

```bash
# 1. 检查是否有 SSH Key
ls ~/.ssh/id_ed25519.pub
# 如果文件不存在，说明没生成过 SSH Key，回到第 2 章第 4 节

# 2. 检查 SSH agent 是否运行
ssh-add -l
# 如果显示 "Could not open a connection to your authentication agent"
# 启动 SSH agent：
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_ed25519

# 3. 测试 GitHub 连接
ssh -T git@github.com
# 预期输出：Hi xxx! You've successfully authenticated...

# 4. 确认公钥已添加到 GitHub
get-content ~/.ssh/id_ed25519.pub
# 复制输出内容，到 GitHub → Settings → SSH and GPG keys 对比

# 5. 检查 remote URL 是否使用 SSH 协议
git remote -v
# 应该是 git@github.com:... 开头
# 如果是 https:// 开头，需要改：
git remote set-url origin git@github.com:your-org/campus_wall.git
```

### 10.13 在错误的仓库目录下操作（多仓库特有问题）

**场景**：你有 6 个仓库在同一个 workspace 下，经常犯的错误是把 A 仓库的改动 push 到了 B 仓库。

**症状自查**：

```bash
# 执行 git status，看到不该出现在这个仓库的文件
# 比如在 campus-wall-ai 目录下看到了 Java 文件

# 执行 git remote -v，发现 origin 指向你没想到的仓库
```

**预防**：

1. **终端提示符显示当前目录**：确保提示符清楚显示当前路径
2. **VS Code 颜色区分**：多根工作区中不同文件夹有不同的颜色标识
3. **重要操作前确认**：push 前先执行 `pwd` + `git remote -v`
4. **使用 VS Code 终端面板**：每个仓库的终端固定在对应的面板中

### 10.14 不同仓库端口冲突

**症状**：启动前端 Dev Server 时报错端口被占用。

**排查**：

```powershell
# 查看端口占用情况
netstat -ano | findstr 5173

# 如果端口被占用，查看是哪个进程
# 记下 PID（最后一列的数字），然后：
tasklist | findstr PID号

# 停止占用的进程，或修改你当前服务的端口
```

**预防**：记住[端口分配表](#95-端口分配速查表)，启动服务前确认端口未被占用。

### 10.15 修改 campus-wall-ops 配置后忘记重启 Docker

**症状**：改了 `docker-compose.yml` 或 `.env`，但服务行为没变化。

**原因**：修改配置文件后，Docker 容器不会自动重启。需要手动操作。

**解决**：

```bash
cd campus-wall-ops

# 方式 1：重启所有服务
docker-compose down
docker-compose up -d

# 方式 2：仅重建并重启修改了的服务（更温和）
docker-compose up -d --build 服务名
# 例如：docker-compose up -d --build mysql
```

### 10.16 急救速查表

| 症状 | 可能原因 | 快速解决命令 |
|------|----------|-------------|
| push 失败 | 远程有新的提交 | `git pull --rebase` → `git push` |
| 文件出现 `<<<<<<<` 标记 | 合并冲突 | 编辑文件 → 删标记 → `git add` → `git commit` |
| 改错了想撤回（未 add） | 误修改 | `git restore 文件名` |
| 改错了想撤回（已 add） | 误暂存 | `git restore --staged 文件名` |
| 改错了想撤回（已 commit，未 push） | 误提交 | `git reset --soft HEAD~1` |
| commit message 写错（未 push） | 手误 | `git commit --amend -m "新message"` |
| 在 main 上改了代码 | 忘记切分支 | `git stash` → 创建分支 → `git stash pop` |
| 切不了分支 | 有未保存修改 | `git stash` → 切分支 → `git stash pop` |
| `.gitignore` 不生效 | 文件已被追踪 | `git rm --cached 文件名` → commit |
| detached HEAD | checkout 了某个 commit | `git checkout main` 或创建新分支保存 |
| SSH 连不上 | key 问题 | 本章第 12 节排查步骤 |
| 仓库目录搞混了 | 多仓库环境 | `pwd` + `git remote -v` 确认 |
| 端口冲突 | 多个服务抢端口 | `netstat -ano \| findstr 端口号` 排查 |
| Docker 配置不生效 | 忘了重启 | `docker-compose down && docker-compose up -d` |

---

## 附录 A：常用 Git 命令速查

| 命令 | 作用 |
|------|------|
| `git status` | 查看当前状态（改了哪些文件） |
| `git status -s` | 紧凑模式 |
| `git diff` | 查看未暂存的改动 |
| `git diff --staged` | 查看已暂存的改动 |
| `git add 文件名` | 暂存文件 |
| `git add -A` | 暂存所有改动 |
| `git restore 文件名` | 丢弃工作区改动（⚠ 不可恢复） |
| `git restore --staged 文件名` | 取消暂存 |
| `git commit -m "message"` | 提交 |
| `git commit --amend` | 追加到上一次提交 |
| `git push` | 推送到远程 |
| `git push -u origin 分支名` | 首次推送并建立追踪 |
| `git pull` | 拉取并合并远程更新 |
| `git pull --rebase` | 拉取并以 rebase 方式合并 |
| `git fetch` | 拉取远程更新但不合并 |
| `git log --oneline` | 查看提交历史 |
| `git log --oneline --graph --all` | 查看所有分支图 |
| `git checkout 分支名` | 切换分支 |
| `git checkout -b 分支名` | 创建并切换分支 |
| `git branch` | 查看本地分支 |
| `git branch -a` | 查看所有分支 |
| `git branch -d 分支名` | 删除本地分支 |
| `git merge 分支名` | 合并指定分支到当前分支 |
| `git rebase 分支名` | 变基到指定分支 |
| `git stash` | 暂存工作现场 |
| `git stash pop` | 恢复暂存的工作现场 |
| `git stash list` | 查看 stash 列表 |
| `git reset --soft HEAD~1` | 撤销最近一次 commit（保留改动） |
| `git reset --hard HEAD~1` | 撤销最近一次 commit（⚠ 丢弃改动） |
| `git revert 提交哈希` | 创建反向提交（安全撤销） |
| `git reflog` | 查看所有操作历史（救命稻草） |
| `git remote -v` | 查看远程仓库地址 |
| `git remote add origin 地址` | 关联远程仓库 |
| `git remote set-url origin 地址` | 修改远程仓库地址 |
| `git rm --cached 文件名` | 停止追踪文件但保留本地文件 |
| `git config --list` | 查看 Git 配置 |

---

## 附录 B：与项目其他文档的关系

| 文档 | 内容 | 何时阅读 |
|------|------|----------|
| [开发规范](../01-development-standards/00-开发规范.md) | Git 分支规范、Commit Message 规范、代码规范 | 本指南的第 5、6 章的规范出处 |
| [新人快速上手](../00-project-overview/04-新人快速上手.md) | 环境搭建、Docker、各服务启动 | 读本指南第 3 章时参考 |
| [系统架构](../00-project-overview/02-系统架构.md) | 6 个服务的详细职责和通信方式 | 读本指南第 9 章前建议了解 |
| [部署指南](../20-operation/00-部署指南.md) | 环境部署流程、备份策略 | 需要部署时参考 |
| [目录结构规范](../01-development-standards/01-目录结构规范.md) | 各仓库的标准目录结构 | 创建新文件/模块时参考 |

---

> **最后的话**：Git 是程序员最重要的工具之一。刚开始用会手忙脚乱，每个人都是这么过来的。
>
> 记住三条原则：
>
> 1. **不要慌**：Git 几乎不会丢失你的代码。即使你 `reset --hard` 了，还有 `git reflog` 可以找回
> 2. **勤提交**：完成一个小功能点就 commit，不要攒 3 天的代码
> 3. **永远不要在 main 上直接开发**：从 main 切出分支，开发完通过 PR 合并回去
>
> 遇到问题先翻第 10 章，找不到答案就在团队群聊里问。
