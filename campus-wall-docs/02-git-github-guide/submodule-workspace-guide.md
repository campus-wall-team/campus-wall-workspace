# 校园墙工作区 Submodule 操作指南（新手入门）

> 本文档面向校园墙团队的新成员，帮助你理解本工作区的仓库组织方式，并掌握日常开发所需的 Git Submodules 操作。

---

## 一、我们为什么用 Git Submodules？

校园墙项目由 7 个独立服务组成（后端、前端、AI、数据管道、告警、运维、监控后台）。每个服务：
- 技术栈不同（Java / Python / Vue / uni-app）
- 有自己的版本迭代节奏
- 由不同成员主要负责

如果把所有代码硬塞进一个仓库，会造成仓库臃肿、CI 混乱、权限难以划分。

**Git Submodules** 让我们既能：
- 通过一个"根仓库"统一管理整个工作区的结构
- 又保持各子项目完全独立的版本控制

你可以把 Submodule 理解为**"仓库里的快捷方式"**——根仓库只记录快捷方式指向哪里，真正的代码还在各自的仓库里。

---

## 二、工作区结构速览

```
campus-wall-workspace/          ← 你克隆下来的根目录（根仓库）
├── campus-wall-docs/           ← 文档（直接存在根仓库里）
│
├── campus-wall-frontend/       ← Submodule（微信小程序前端）
├── campus_wall/                ← Submodule（Java 主后端）
├── campus-wall-ai/             ← Submodule（AI 问答服务；原 campus-wall-graphrag 已并入，端口 8011）
├── campus-wall-data-pipeline/  ← Submodule（数据管道）
├── campus-wall-alert-adapter/  ← Submodule（告警推送）
├── campus-wall-monitor-ui/     ← Submodule（监控后台）
├── campus-wall-ops/            ← Submodule（运维部署）
│
├── .gitmodules                 ← Submodule 的配置清单
└── README.md                   ← 根仓库说明
```

**区分方法**：进入任意子目录，执行 `git remote -v`：
- 如果有远程地址 → 这是一个独立的仓库（Submodule）
- 如果报错 "not a git repository" → 这是根仓库的直接目录（如 docs）

---

## 三、第一次加入团队：如何克隆项目？

### 方法 A：一次性克隆（推荐）

```bash
git clone --recurse-submodules https://github.com/campus-wall-team/campus-wall-workspace.git
```

这条命令会自动：
1. 下载根仓库
2. 读取 `.gitmodules`
3. 把所有 7 个子项目也下载下来

### 方法 B：先克隆根仓库，再拉子项目

如果你已经克隆了根仓库，但子目录是空的：

```bash
cd campus-wall-workspace

git submodule update --init --recursive
```

---

## 四、日常开发操作

### 4.1 进入子项目开发（最常用）

```bash
cd campus_wall

# 查看当前分支
git branch

# 创建功能分支
git checkout -b feature/add-emoji-support

# ... 写代码 ...

# 提交（和平时完全一样）
git add .
git commit -m "feat(emoji): 添加自定义表情功能"

# 推送到远程
git push origin feature/add-emoji-support

# 然后去 GitHub 提 Pull Request
```

> **重要**：在子目录里的 `git add`、`git commit`、`git push` 只影响该子项目，不会影响根仓库。

### 4.2 修改根仓库内容（如文档）

```bash
# 在根目录（或 campus-wall-docs/ 目录）
cd campus-wall-docs

# 编辑文档 ...

# 回到根目录提交
cd ..
git add campus-wall-docs/
git commit -m "docs: 更新 API 接口文档"
git push origin main
```

> 根仓库的提交只记录：文档变更、README 变更、以及各 Submodule 指向哪个版本。

### 4.3 更新子项目到最新版

团队成员在其他子项目中合并了新功能，你想把本地工作区的子项目同步到最新：

```bash
# 更新所有子项目
git submodule update --remote

# 或者只更新某一个
git submodule update --remote campus_wall

# 然后锁定新版本到根仓库
git add campus_wall
git commit -m "chore: 更新 campus_wall 到最新版"
git push origin main
```

### 4.4 查看子项目当前指向的版本

```bash
git submodule status
```

输出示例：

```
 4a3b2c1d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3 campus-wall-alert-adapter (v1.2.0)
 7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6 campus-wall-data-pipeline (v2.1.0-5-gabcd123)
```

每行前面的哈希值就是根仓库锁定的子项目提交版本。

---

## 五、常见问题和解决办法

### Q1：子目录是空的，没有代码？

**原因**：克隆时没加 `--recurse-submodules`。

**解决**：

```bash
git submodule update --init --recursive
```

### Q2：我在子项目里改了代码，但根仓库 `git status` 看不到变化？

**原因**：子项目是独立仓库，根仓库只能感知"子项目当前指向哪个提交"，看不到子项目内部的文件改动。

**解决**：
1. 先在子项目里正常 `add` / `commit` / `push`
2. 回到根目录，执行 `git add <子目录名>`
3. 根仓库会记录子项目的新版本指针

### Q3：如何删除一个 Submodule？

```bash
# 1. 取消注册
git submodule deinit -f campus-wall-xxx

# 2. 从工作区删除
git rm -f campus-wall-xxx

# 3. 清理 .git/modules 中的缓存
rm -rf .git/modules/campus-wall-xxx
```

### Q4：子项目切换分支会影响根仓库吗？

**不会**。你在子项目里切分支、做实验、甚至 `git reset`，都不会影响根仓库。只有当你回到根目录执行 `git add <子目录>` 时，根仓库才会记录子项目的新指针。

### Q5：根仓库的 `.gitignore` 和子项目的 `.gitignore` 是什么关系？

**完全独立**。根仓库的 `.gitignore` 只管理根目录级别的文件（如根目录下误放的 `.env`）。每个子项目有自己的 `.gitignore`，管理各自的编译产物、依赖目录等。

---

## 六、安全红线（必读）

| 禁止行为 | 后果 | 正确做法 |
|----------|------|----------|
| `git add -f .env` 强制提交环境变量文件 | 密码、API Key 泄露到公开仓库 | 永远相信 `.gitignore`，通过安全渠道传递 `.env` |
| 在子项目里提交 `.claude/settings.local.json` | 泄露本地 IDE 配置 | 已添加到 `.gitignore`，勿强制提交 |
| 把根仓库的 `.gitignore` 当万能盾牌 | 子项目可能有独立规则 | 每个仓库都要检查自己的 `.gitignore` |
| 用 `git commit -a` 大批量提交不检查 | 可能夹带敏感文件或编译产物 | 养成 `git add -p` 或逐文件检查的习惯 |

### 如果不小心提交了敏感文件怎么办？

**第一步**：不要慌，立刻联系团队管理员。

**第二步**：管理员使用以下工具清理 Git 历史（普通 `git rm` 无法删除历史记录）：

```bash
# 方法 1：BFG Repo-Cleaner（推荐，操作简单）
bfg --delete-files .env

# 方法 2：git-filter-repo（更强大）
git filter-repo --path .env --invert-paths
```

**第三步**：所有团队成员重新克隆仓库（不要 pull，因为历史已被重写）。

**第四步**：到 GitHub 设置中撤销泄露的 API Key / 密码，并更换新密钥。

---

## 七、团队协作工作流总结

```
1. 克隆工作区
   git clone --recurse-submodules <根仓库地址>

2. 日常开发（以 campus_wall 为例）
   cd campus_wall
   git checkout -b feature/xxx
   # ... coding ...
   git add .
   git commit -m "feat: xxx"
   git push origin feature/xxx
   # → GitHub 提 PR → Code Review → 合并

3. 同步最新代码
   git pull origin main                # 在子项目里拉取最新
   或
   git submodule update --remote       # 在根目录更新所有子项目

4. 锁定版本到根仓库（一般由负责人操作）
   cd ..
   git add campus_wall
   git commit -m "chore: bump campus_wall"
   git push origin main
```

---

## 八、延伸阅读

- [Git 官方文档 - Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- 本工作区的 `.gitmodules` 文件（可直接查看配置）
- 各子项目的 `README.md`（技术细节和开发规范）

---

> 如有疑问，请在团队群聊中 @ 管理员，或在对应子项目的 GitHub Issues 中提问。
