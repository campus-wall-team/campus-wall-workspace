# Campus Wall 校园墙 — 工作区总览

校园墙（Campus Wall）是一个面向高校学生的匿名社交与信息互助平台，集帖子发布、AI 智能问答、实时私信、内容审核、数据分析和运维监控于一体。

本仓库为**工作区根仓库**，通过 Git Submodules 聚合校园墙项目下的各个独立服务。它本身不存放业务代码，只维护：
- 统一的工作区目录结构
- 各子项目的版本锁定（Submodule 指针）
- 跨项目文档（`campus-wall-docs/`）

---

## 系统架构

```
+-------------------------------------------------------------+
|                         用户层                               |
|   微信小程序 (campus-wall-frontend)  +  管理后台 (campus-wall-monitor-ui) |
+-------------------------------------------------------------+
                              |
+-------------------------------------------------------------+
|                       网关 / 负载均衡                         |
|              Nginx (campus-wall-ops/nginx)                  |
+-------------------------------------------------------------+
                              |
+-----------------------------+-------------------------------+
|        业务服务层            |         AI / 数据层            |
|  campus_wall (Java 后端)    |  campus-wall-graphrag (RAG)   |
|  用户 · 帖子 · 私信 · 审核   |  知识库 · LLM 问答代理         |
+-----------------------------+-------------------------------+
|  campus-wall-data-pipeline  |  campus-wall-alert-adapter    |
|  数据清洗 · 脱敏 · 入库      |  告警推送 · 企业微信机器人      |
+-----------------------------+-------------------------------+
                              |
+-------------------------------------------------------------+
|                      基础设施层                              |
|  MySQL 8  ·  Redis 7  ·  MinIO  ·  Prometheus  ·  Grafana   |
|           (campus-wall-ops 统一编排)                         |
+-------------------------------------------------------------+
```

---

## 工作区目录结构

```
campus-wall-workspace/
├── campus-wall-docs/              # 项目文档中心（见下方说明）
│
├── campus-wall-alert-adapter/     # 告警适配器（Python）
│   └── 企业微信机器人推送
│
├── campus-wall-data-pipeline/     # 数据管道（Python）
│   └── 爬虫 · 清洗 · 脱敏 · 入库
│
├── campus-wall-frontend/          # 微信小程序前端（uni-app + Vue3 + TS）
│   └── 用户端小程序
│
├── campus-wall-graphrag/          # 智能问答服务（Python + FastAPI）
│   └── GraphRAG · 阿里云百炼 LLM
│
├── campus-wall-monitor-ui/        # 监控管理后台（Vue3）
│   └── 运营人员管理界面
│
├── campus-wall-ops/               # 运维部署（Docker Compose）
│   └── Nginx · Prometheus · Grafana · Alertmanager
│
├── campus_wall/                   # 主后端服务（Java + Spring Boot）
│   └── 用户 · 帖子 · 评论 · 私信 · AI聊天 · 审核
│
├── .gitmodules                    # Submodule 配置
└── README.md                      # 本文件
```

> 除 `campus-wall-docs/`、`README.md`、`.gitignore`、`.gitmodules` 外，其余目录均为 **Git Submodule**，指向各自独立的远程仓库。

---

## 快速开始

### 1. 克隆整个工作区（含所有子项目）

```bash
git clone --recurse-submodules https://github.com/campus-wall-team/campus-wall-workspace.git
cd campus-wall-workspace
```

如果已经克隆了根仓库但子目录为空：

```bash
git submodule update --init --recursive
```

### 2. 更新所有子项目到最新版本

```bash
git submodule update --remote
```

### 3. 单独进入某个子项目开发

```bash
cd campus_wall
# 在这里执行日常 git 操作（add / commit / push）
# 子项目完全独立，拥有自己的分支和提交历史
```

---

## 各子项目简介

| 子项目 | 技术栈 | 职责 |
|--------|--------|------|
| `campus_wall` | Java 17, Spring Boot 3, MyBatis-Plus, MySQL, Redis | 核心业务后端：用户认证、帖子、评论、私信、AI聊天、内容审核 |
| `campus-wall-frontend` | uni-app, Vue3, TypeScript | 微信小程序用户端 |
| `campus-wall-graphrag` | Python, FastAPI, Neo4j | AI 问答代理，基于 GraphRAG 实现知识库问答 |
| `campus-wall-data-pipeline` | Python | 数据采集、清洗、脱敏、结构化入库 |
| `campus-wall-alert-adapter` | Python, Flask | 告警通知适配，对接企业微信机器人 |
| `campus-wall-monitor-ui` | Vue3, Element Plus | 运营监控管理后台 |
| `campus-wall-ops` | Docker, Docker Compose, Nginx, Prometheus, Grafana | 生产环境部署编排与监控基础设施 |

各子项目的详细技术文档、API 说明和开发规范请进入对应目录查看其 `README.md`。

---

## 文档中心

跨项目文档统一维护在 `campus-wall-docs/` 目录：

| 目录 | 内容 |
|------|------|
| `00-project-overview/` | 项目概览、架构图、需求文档 |
| `01-development-standards/` | 编码规范、接口规范、数据库设计规范 |
| `02-git-github-guide/` | Git 工作流、Submodule 操作指南、PR 规范 |
| `10-backend/` | 后端 API 文档、数据库设计、部署说明 |
| `11-frontend/` | 前端开发文档、组件说明、样式规范 |
| `12-monitor-ui/` | 管理后台开发文档 |
| `13-graphrag/` | GraphRAG 服务文档、知识库维护 |
| `14-data-pipeline/` | 数据管道设计、数据源说明 |
| `15-alert-adapter/` | 告警规则、通知模板 |
| `16-ops/` | 运维手册、Docker 部署指南 |
| `20-operation/` | 运营手册、内容审核标准 |
| `30-claude-code-guide/` | AI 辅助开发指南 |
| `50-business-plan/` | 商业计划书 |

---

## 安全提醒

- **`.env` 文件（含真实密码、API Key）绝对不要提交到 Git**。各子项目的 `.gitignore` 已配置忽略 `.env`，请遵守。
- **`.claude/settings.local.json`** 为本地 Claude Code 配置，不应共享。
- 团队成员之间通过安全渠道（加密消息、密码管理工具）传递环境变量文件。
- 如意外将敏感信息提交到 Git，请立即联系管理员进行历史清理（`git-filter-repo` 或 BFG）。

---

## 贡献指南

1. 进入你要修改的子项目目录
2. 创建功能分支：`git checkout -b feature/xxx`
3. 开发、测试、提交
4. 推送分支并到对应子项目的 GitHub 仓库提 Pull Request
5. Code Review 通过后合并

根仓库的更新（如文档变更、Submodule 版本锁定）直接在根仓库提交即可。

---

## 许可证

本项目为校园墙团队内部项目，未经授权不得对外传播。
