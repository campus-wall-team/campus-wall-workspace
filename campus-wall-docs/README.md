# 校园墙项目开发文档

欢迎来到校园墙项目开发文档中心！本文档体系旨在帮助团队成员快速了解项目、上手开发。

---

## 快速开始

**新成员？** 从 [新人快速上手](00-project-overview/04-新人快速上手.md) 开始，30 分钟内完成环境搭建并运行项目。

**想了解项目？** 阅读 [项目介绍](00-project-overview/00-项目介绍.md) 和 [系统架构](00-project-overview/02-系统架构.md)。

**想查看技术栈？** 查看 [技术栈总览](00-project-overview/01-技术栈总览.md)。

---

## 文档导航

### 项目总览

| 文档 | 说明 |
|------|------|
| [项目介绍](00-project-overview/00-项目介绍.md) | 项目背景、愿景、核心功能、目标用户 |
| [技术栈总览](00-project-overview/01-技术栈总览.md) | 完整技术栈矩阵、各服务对照表、版本信息 |
| [系统架构](00-project-overview/02-系统架构.md) | 整体架构图、7个服务职责、服务间通信、部署拓扑 |
| [数据流图](00-project-overview/03-数据流图.md) | 发帖、AI问答、内容审核、私信、数据管道、监控告警流程 |
| [新人快速上手](00-project-overview/04-新人快速上手.md) | 环境搭建、一键启动、验证完整链路、第一个开发任务 |
| [项目进度与完成度](00-project-overview/05-项目进度.md) | 各模块完成度矩阵、当前可运行 Demo、已知 TODO、未来功能占位区 |

### 开发规范

| 文档 | 说明 |
|------|------|
| [开发规范](01-development-standards/00-开发规范.md) | Git规范、Commit规范、Java/TS/Python代码规范、代码审查Checklist |
| [目录结构规范](01-development-standards/01-目录结构规范.md) | 7个仓库的标准目录结构、新增文件规范 |
| [API设计规范](01-development-standards/02-API设计规范.md) | RESTful API规范、统一响应格式、分页、认证、错误码、WebSocket |
| [数据库规范](01-development-standards/03-数据库规范.md) | 表/字段/索引命名、字段设计、Flyway迁移、SQL规范 |

### Git & GitHub 协作指南

| 文档 | 说明 |
|------|------|
| [协作指南导航](02-git-github-guide/README.md) | 按水平推荐阅读路径、快速跳转索引 |
| [完整协作开发指南](02-git-github-guide/git-github协作开发完整指南.md) | 零基础手把手教程：概念 → 安装 → 日常流程 → PR → 多仓库协作 → 故障排除 |

### 各仓库开发文档

| 仓库 | 文档 | AI辅助文档 |
|------|------|------------|
| campus_wall | [开发文档](10-backend/开发文档.md) | [.claude/CLAUDE.md](../campus_wall/.claude/CLAUDE.md) |
| campus-wall-frontend | [开发文档](11-frontend/开发文档.md) | [.claude/CLAUDE.md](../campus-wall-frontend/.claude/CLAUDE.md) |
| campus-wall-monitor-ui | [开发文档](12-monitor-ui/开发文档.md) | [.claude/CLAUDE.md](../campus-wall-monitor-ui/.claude/CLAUDE.md) |
| campus-wall-graphrag | [开发文档](13-graphrag/开发文档.md) | [.claude/CLAUDE.md](../campus-wall-graphrag/.claude/CLAUDE.md) |
| campus-wall-data-pipeline | [开发文档](14-data-pipeline/开发文档.md) | [.claude/CLAUDE.md](../campus-wall-data-pipeline/.claude/CLAUDE.md) |
| campus-wall-alert-adapter | [开发文档](15-alert-adapter/开发文档.md) | [.claude/CLAUDE.md](../campus-wall-alert-adapter/.claude/CLAUDE.md) |
| campus-wall-ops | [开发文档](16-ops/开发文档.md) | [.claude/CLAUDE.md](../campus-wall-ops/.claude/CLAUDE.md) |

### 功能模块文档

| 文档 | 说明 |
|------|------|
| [Emoji 表情模块](40-emoji-module/emoji-module-spec.md) | 跨前后端功能规格：占位符编码、统一渲染、前后端开发指南、API设计 |

### 运维文档

| 文档 | 说明 |
|------|------|
| [部署指南](20-operation/00-部署指南.md) | 开发/测试/生产环境部署流程、服务启动顺序、备份策略、升级回滚 |
| [监控告警指南](20-operation/01-监控告警指南.md) | Prometheus指标、Grafana面板、Alertmanager告警规则、常用PromQL |
| [常见问题排查](20-operation/02-常见问题排查.md) | 服务启动、数据库、AI服务、网络、性能、安全等常见问题 |
| [团队内网开发指南](20-operation/03-团队内网开发指南.md) | 中间件部署在本地 GB10 服务器、团队成员连内网开发、配置模板与排错 |

### Claude Code AI 辅助开发

| 文档 | 说明 |
|------|------|
| [如何使用Claude Code](30-claude-code-guide/00-如何使用Claude%20Code.md) | 安装配置、常用命令、高效使用技巧、费用控制 |
| [各仓库AI辅助开发策略](30-claude-code-guide/01-各仓库AI辅助开发策略.md) | 各仓库适合AI辅助的场景、提示词模板、效率对比 |

---

## 项目架构速览

```
校园墙 Campus Wall
│
├── 用户端 (H5/微信小程序)
│   └── campus-wall-frontend  [Vue 3 + uni-app]
│       ├── 圈子（帖子浏览/发布）
│       ├── 发现（分类/搜索）
│       ├── AI学长（智能问答）
│       ├── 私信（实时聊天）
│       └── 我的（个人中心）
│
├── 管理后台 (Web)
│   └── campus-wall-monitor-ui  [Vue 3 + Element Plus]
│       ├── 数据概览
│       └── 内容审核
│
├── 主后端服务
│   └── campus_wall  [Java 17 + Spring Boot 3]
│       ├── 用户认证（微信OAuth2 + JWT）
│       ├── 社区（帖子/评论/搜索）
│       ├── AI代理（转发GraphRAG）
│       ├── 私信（WebSocket）
│       ├── 内容审核（敏感词+AI复审）
│       └── 管理API
│
├── AI 知识图谱服务
│   └── campus-wall-graphrag  [Python + FastAPI + Neo4j]
│       ├── 文档索引 → 知识图谱
│       └── 知识问答 ← GraphRAG检索+LLM生成
│
├── 数据管道
│   └── campus-wall-data-pipeline  [Python ETL]
│       ├── 提取（MySQL帖子数据）
│       ├── 清洗（去噪/去广告）
│       ├── 脱敏（PII移除）
│       └── 推送 → GraphRAG
│
├── 告警适配器
│   └── campus-wall-alert-adapter  [Python + FastAPI]
│       └── Alertmanager → 企微/钉钉
│
└── 运维基础设施
    └── campus-wall-ops  [Docker Compose]
        ├── 数据层：MySQL, Redis, MinIO, Neo4j, Chroma
        ├── 监控层：Prometheus + Grafana + Alertmanager
        └── 代理层：Nginx
```

---

## 技术栈速查

| 层级 | 技术 | 版本 |
|------|------|------|
| 后端 | Java + Spring Boot | 17 + 3.3.7 |
| 前端 | Vue 3 + uni-app | 3.4 + 3.0 |
| 管理后台 | Vue 3 + Element Plus | 3.5 + 2.8 |
| AI服务 | Python + FastAPI + Neo4j | 3.12 + 0.115 + 5 |
| 数据库 | MySQL + Redis + MinIO | 8.0 + 7.0 + latest |
| 监控 | Prometheus + Grafana | 2.54 + 11.2 |
| 部署 | Docker Compose | - |

---

## 贡献文档

发现文档有误或需要补充？请：
1. 修改对应文档文件
2. 遵循 [开发规范](01-development-standards/00-开发规范.md) 中的 Git 规范提交
3. 简要说明修改内容

---

*本文档体系最后更新：2026-05-31*
