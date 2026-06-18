# Campus Wall 校园墙 — 项目完整文档

> 本文档是 Campus Wall 工作区的**完整技术总文档**，覆盖系统架构、6 个子模块、数据存储、AI 问答链路、监控告警、端口规划、本地启动与部署。内容以仓库源码和当前真实运行状态为准（含本地 GraphRAG 知识库 demo）。
>
> 根目录 [`README.md`](./README.md) 是面向新成员的简要总览；本文件是深入的技术参考。

---

## 目录

1. [项目简介](#1-项目简介)
2. [系统架构](#2-系统架构)
3. [技术栈总览](#3-技术栈总览)
4. [子模块详解](#4-子模块详解)
5. [数据存储](#5-数据存储)
6. [AI 问答链路（GraphRAG）](#6-ai-问答链路graphrag)
7. [监控告警体系](#7-监控告警体系)
8. [端口规划总表](#8-端口规划总表)
9. [本地启动与部署](#9-本地启动与部署)
10. [环境变量总览](#10-环境变量总览)
11. [安全与合规](#11-安全与合规)
12. [开发协作（Submodule 工作流）](#12-开发协作submodule-工作流)

---

## 1. 项目简介

Campus Wall（校园墙）是一个面向高校学生的**匿名社交与信息互助平台**，集帖子发布、AI 智能问答（"AI 学长"）、实时私信、内容审核、数据分析与运维监控于一体。

工作区采用 **Git Submodule 多仓库**结构：根仓库只锁定各子项目版本与跨项目文档，业务代码分散在 6 个独立子仓库中，各自拥有分支与提交历史。

**核心能力：**
- 用户端微信小程序：帖子社区、AI 学长问答、私信聊天、个人中心
- Java 后端：用户/帖子/评论/私信/AI/审核全业务
- GraphRAG 知识引擎：把校园知识灌入 Neo4j 知识图谱，向量检索 + LLM 生成精准问答
- 数据管道：从校园墙 MySQL / 微信导出抽取知识，清洗脱敏后入库
- 运维监控：Prometheus + Grafana + Alertmanager 全栈观测，告警转发企业微信/钉钉
- 管理后台：独立 admin_user RBAC 权限体系、运营看板、内容审核/举报/反馈/学生认证、用户与权限管理、内嵌 Grafana 看板

---

## 2. 系统架构

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                            用户 / 运营层                          │
│   微信小程序 (campus-wall-frontend)   管理后台 (campus-wall-monitor-ui) │
└─────────────────────────────────────────────────────────────────┘
                  │ HTTPS / WSS                  │ HTTP（同源反代 /api /grafana）
┌─────────────────────────────────────────────────────────────────┐
│                         网关 / 反向代理层                         │
│        Nginx（monitor-ui 容器，8090）：/ SPA · /api · /grafana   │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┴───────────────────────┐
        │ 业务服务层                                    │ AI / 数据层
┌───────────────────────────────┐         ┌──────────────────────────────┐
│ campus_wall（Java/Spring Boot）│  HTTP   │ campus-wall-ai（FastAPI）      │
│ 用户·帖子·私信·AI 学长 agent·  │ ──────► │ 知识图谱检索 + LLM 问答/帖子匹配│
│ 审核·RBAC  宿主机 :8080(systemd)│ :8011   │ Neo4j + Ollama 优先/DashScope │
└───────────────────────────────┘         └──────────────────────────────┘
        │                                          ▲
        │                          ┌───────────────┘ POST /index · /ingest-post
        │                  ┌──────────────────────────────┐
        │                  │ campus-wall-data-pipeline     │
        │                  │ 导出·清洗·脱敏·知识单元入库   │
        │                  └──────────────────────────────┘
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                          基础设施 / 数据层                        │
│  MySQL 8 · Redis 7 · MinIO · Neo4j 5                             │
└─────────────────────────────────────────────────────────────────┘
                              │ 指标采集
┌─────────────────────────────────────────────────────────────────┐
│                          监控告警层                               │
│  Prometheus → Grafana（看板） / Alertmanager → alert-adapter      │
│  exporters: node · mysqld · redis · blackbox（· cadvisor）        │
│  alert-adapter → 企业微信 / 钉钉群机器人                          │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 部署拓扑（当前真实运行状态）

- **宿主机直接运行**（不在 Docker 内）：
  - Spring Boot 后端 `:8080`（生产用 systemd `campus-wall.service` 托管）
  - Ollama `:11434`（本地 LLM `qwen2.5:7b` + 嵌入 `bge-m3`）
  - campus-wall-ai demo（`demo/run-graphrag.sh` → `:8011`，本地直跑，见 §6）
- **Docker Compose 编排**（`campus-wall-ops`）：MySQL、Redis、MinIO、Neo4j、Prometheus、Grafana、Alertmanager、各 exporter、alert-adapter、monitor-ui(nginx)。
- 容器访问宿主机服务统一用 `host.docker.internal`（如 nginx 代理 `/api` → `host.docker.internal:8080`，campus-wall-ai 连 Ollama）。
- 为避开宿主机已占用端口，Neo4j 对外映射为 **7475(HTTP) / 7688(Bolt)**（容器内仍是 7474/7687）。

### 2.3 关键数据流

**① 用户问 AI 学长（单一入口，轻量 Planner-Executor agent）：**
```
小程序 → POST /api/v1/ai-senior/agent（JWT 鉴权，@RequestAttribute userId）
       → Java AgentService：读短期记忆 → 指代消解(QuestionContextualizer)
         → 规划(Planner) → 执行只读工具(ToolExecutor)
              · search_posts 工具 → HTTP POST :8011/match-posts（找帖）
              · knowledge_qa 工具 → HTTP POST :8011/query（知识库）
         → RelevanceJudge 反幻觉判定（结构化输出 List<Long>，从严放行相关帖）
         → 严格接地合成(Synthesizer) → 异步沉淀长期用户记忆
       → 回传 {success, answer, posts(匹配帖卡片), plan(调试), conversationId}
       → 小程序展示（带来源引用与匹配帖子卡片）
```
> 对话记忆双层：短期上下文（`ConversationMemoryService` → `ai_chat_record`）+ 长期用户记忆（`AiUserMemoryService` + `MemoryExtractor` 异步抽取 → `ai_user_memory`）。旧端点 `/ai-senior/chat`、`/chat/stream` 已下线。

**② 知识入库：**
```
MySQL post+comment / 微信导出
  → data-pipeline: clean → desensitize（脱敏）→ KnowledgeUnit
  → POST :8011/index → chunk → bge-m3 嵌入 + LLM 实体抽取 → 写入 Neo4j
```

**③ 私信：**
```
小程序 ⇄ WebSocket ws://host/ws/chat/{userId}（实时推送）
       + HTTP /api/v1/messages/chat/*（历史、发送、撤回、已读）
```

**④ 监控告警：**
```
各服务 → exporters / actuator → Prometheus 抓取（15s）
       → 命中告警规则 → Alertmanager 分组/抑制
       → webhook → alert-adapter :9094 → 企业微信/钉钉
Grafana 读 Prometheus → 看板（经 nginx /grafana 内嵌到管理后台）
```

---

## 3. 技术栈总览

| 子模块 | 语言/框架 | 关键依赖与版本 | 职责 |
|--------|-----------|----------------|------|
| `campus_wall` | Java 17 · Spring Boot 3.4.2 | MyBatis-Plus 3.5.9 · Spring AI 1.0.8（`spring-ai-starter-model-openai`，BOM 1.0.8） · JJWT 0.11.5 · MinIO 8.5.7 · Flyway · WebSocket · Micrometer Prometheus · AOP（审计） · bucket4j 8.10（限流） · spring-security-crypto（BCrypt） | 核心业务后端 |
| `campus-wall-frontend` | uni-app 3.0 · Vue 3.4.21 · TS 4.9 | Vite 5.2 · Sass 1.99 · marked 18（Markdown） · tailwindcss 3.4 + weapp-tailwindcss · vue-i18n 9.1（已装未用） | 微信小程序用户端 |
| `campus-wall-ai` | Python 3.12 · FastAPI 0.115 · LangGraph | neo4j 5.27 驱动（graph_store.py 自实现） · OpenAI SDK 1.59（兼容内网 Qwen/DashScope/Ollama） · LangGraph · SQLAlchemy · Redis · PyJWT · Pydantic 2.10 | AI 微服务 v2（已吸收原 graphrag）：QA agent · AI 发帖 · 知识问答/帖子匹配 · SSE · 异步记忆 |
| `campus-wall-data-pipeline` | Python 3.x | PyMySQL 1.1.1 · requests 2.32 | ETL：导出·清洗·脱敏·入库（本机导出，非爬虫） |
| `campus-wall-monitor-ui` | Vue 3.5.10 · JS | Element Plus 2.8.4 · Vue Router 4.4 · Pinia 2.2 · Axios 1.7 · Vite 5.4 | 运营管理后台 |
| `campus-wall-ops` | Docker Compose | MySQL 8.0 · Redis 7.0 · Neo4j 5 · Prometheus v2.54 · Grafana 11.2 · Alertmanager v0.27 · Nginx 1.27 · alert-adapter(FastAPI) | 编排与监控基建（含 `alert-adapter/` 告警转发，原独立子模块已并入） |

---

## 4. 子模块详解

### 4.1 `campus_wall` — Java 核心后端

Spring Boot 3.4.2 / Java 17 单体应用（Spring AI 1.0.8），按领域分包：`social`（用户/关注/私信/通知/表情）、`community`（帖子/评论/分类/搜索/浏览历史/板块/排行榜/学生认证）、`ai`（AI 学长 agent/偏好/记忆，含 `ai.agent` 规划执行包与 `ai.memory` 长期记忆包）、`admin`（独立 RBAC 鉴权/审核/举报/反馈/审计/运营看板/系统配置/文件/Redis 迁移）、`infrastructure`（WebSocket）。

- **应用名** `campus-wall-backend`，端口默认 **8080**，profile 默认 `dev`。
- **统一响应** `Result<T> = { code, message, data }`（成功 `code === 200`）。
- **鉴权**：JWT（微信 code 换 token），请求头 `Authorization: Bearer <token>`。

**主要 REST 接口（前缀 `/api/v1`）：**

| 控制器 | 前缀 | 职责 |
|--------|------|------|
| UserController | `/users` | 微信登录、当前用户、详情、更新 |
| UserFollowController | `/follow` | 关注/取关、关注列表、粉丝列表 |
| PostController | `/posts` | 发布、列表（含 scope/campus/regionScope 区域筛选）、时间线、热帖、排行榜、详情、点赞、收藏、浏览、组队 join/leave、二手联系卖家 |
| CommentController | `/comments` | 评论增删、列表、点赞 |
| CategoryController / SearchController | `/categories` `/search` | 分类话题、搜帖、热搜 |
| RankController | `/ranks` | 排行榜：`/posts` 热帖榜（period day/week/month、scope 本校/跨校/全省）、`/search-hot` 热搜榜 |
| StudentVerificationController | `/verification` | 学生认证 upload/submit/status（学生证 OCR + AI 置信度 + 人工复核） |
| BrowseHistoryController | `/browse-history` | 浏览历史记录/清空 |
| MessageController | `/messages` | 通知、私信会话/消息/发送/撤回/已读 |
| NotificationController | `/notifications` | 评论/点赞通知 |
| UniversityController / RegionController | `/universities` `/regions` | 高校搜索、行政区划级联（选学校用） |
| EmojiController | `/emojis` | 自定义表情列表 |
| **AgentController** | `/ai-senior/agent` | **AI 学长统一入口**：Planner-Executor agent（规划→只读工具→RelevanceJudge 判定→接地合成），JWT 鉴权 |
| **AiSeniorController** | `/ai-senior` | knowledge/*（导入/批量导入/列表/删除/导入文本/清空）+ history/*（列表/详情） |
| AiPreferenceController | `/ai-preference` | AI 偏好（get/save）、系统提示词 |
| **AdminAuthController** | `/admin` | 管理员登录 `/admin/login`（查 admin_user 签发 admin token）、`/admin/auth/me`、登出 |
| AdminManageController | `/admin` | 管理员/角色/权限 CRUD（/admins、/roles、/permissions、/roles/{id}/permissions） |
| AdminUserMgmtController | `/admin/users` | 用户封禁/解封 |
| StatController（运营看板） | `/admin/stat` | overview/trend/active/distribution/top-posts（stat:view，配 stat_daily 每日快照） |
| AdminSysConfigController | `/admin/configs` | 系统配置 GET/PUT（sys:config / sys:config-save） |
| AuditLogController | `/admin/audit` | 操作审计日志查询（audit:view，`@OperationLog` AOP → admin_oper_log） |
| AdminModerationController | `/admin` | 审核队列、扫描、通过/驳回、瞬时统计 `/admin/stats`（已迁出登录，需 `@RequirePermission`） |
| FileController | `/files` | MinIO 文件上传（帖子图/附件、头像、聊天图/语音、AI 文件、通知横幅等） |
| FeedbackController | `/feedback` | 用户反馈 |
| RedisMigrationController | `/redis/migration` | 点赞/收藏/搜索/时间线数据迁移到 Redis |

**WebSocket**：配置类 `WebSocketConfig`（`ServerEndpointExporter`），端点 `ChatWebSocketHandler` 路径 `/ws/chat/{userId}`，会话管理默认 `InMemorySessionManager`（单机内存，可换 Redis 分布式实现）。

**数据库**：Flyway 管理迁移，基线已重置为 `V3.0__baseline`（含 22 表），其后 **V3.0~V4.4 共 15 个脚本**（V3.1 初始化数据、V3.2 板块重映射、V3.3 post 板块字段、V3.4 标签表、V3.5 team_member、V3.6 team_max_members、V3.7 post_campus、V3.8 排行榜+学生认证、V3.9 ai_user_memory、V4.0 admin RBAC 五表、V4.1 RBAC 预置数据、V4.2 admin_audit/report/user、V4.3 stat_daily、V4.4 sys_config），库 `campus_wall`（utf8mb4），**当前共约 37 张表**（见 §5）。MySQL 8 用 information_schema + PREPARE 守卫实现幂等加列/索引。

**管理端独立 RBAC（V4.0/V4.1）**：物理隔离的独立管理员账号体系（**不是给 C 端 `user` 加 role**）。5 张表 admin_user / admin_role / admin_permission / admin_user_role / admin_role_permission；3 预置角色 superadmin（全权）/ moderator（内容审核员）/ viewer（只读运营）；权限码形如 `module:action`（moderation:queue、stat:view、user:ban、role:assign、sys:config、audit:view 等）。鉴权 = `AdminAuthInterceptor` + `@RequirePermission(权限码)` + 独立 `AdminJwtUtil`（后端是鉴权权威）。审计靠 `@OperationLog` AOP 切面落 `admin_oper_log`（V4.2）；运营看板配 `stat_daily` 每日快照（V4.3，DAU HLL 去重）；系统配置配 `sys_config`（V4.4）。

**社区端新增能力**：板块分类（`BoardType` 5 值：RECOMMEND 推荐 / SECONDHAND 二手交易 requirePrice / PARTTIME 兼职 requireSalary / PROMOTION 推广 / TEAM 组队）；post 新增 is_top/price(NULL=面议)/salary/info_fee/contact/banner_object_name/is_sold；标签 tag/post_tag、组队 team_member、跨校 post_campus；排行榜（RankController + hot_rank_config，V3.8）；学生认证（student_verification 表 + user.student_verified/student_no，学生证 OCR 正反面 + AI 置信度 + 人工复核状态机）；发现页区域筛选（scope/campus/regionScope/locationKeywords）。

**外部依赖配置**：DashScope（`qwen-plus`，兼容模式）、campus-wall-ai（原 GraphRAG，默认 `http://localhost:8011`，超时 120s）、MinIO（bucket `campus-wall`）、Redis（多级缓存 TTL：用户 2h / 帖子详情 30m / 帖子列表 5m 等）。

> ⚠️ `application-dev.yaml` 中数据源/Redis/MinIO 指向了一个公网 IP（`121.43.119.5`）与若干默认值，敏感项一律走环境变量（`MYSQL_PASSWORD`、`DASHSCOPE_API_KEY`、`MINIO_SECRET_KEY` 等），生产 profile 强制环境变量注入。

### 4.2 `campus-wall-frontend` — 微信小程序

uni-app 3 + Vue 3 + TypeScript，5 个底部 Tab（圈子 / 发现 / AI / 私信 / 我的），31 个页面。

- **页面分组**：`index`(帖子列表/板块化)、`discover`(分类)、`ai`(问答/历史/偏好)、`message`(私信/通知/点赞/粉丝)、`user`(个人中心/选学校/我的帖子收藏点赞/学生认证/设置等)、`post/detail`(含二手联系卖家、组队 join/leave)、`publish`(按板块表单)、`search`、`login`、`leaderboard`、`hot-posts`、`rank`(排行榜)。
- **请求层** `src/utils/request.js`：基址经 `src/config/index.ts`（`config.apiBaseUrl`）注入，自动注入 JWT，401 清登录态。API 集中于 `src/api/index.js` 聚合（community / social / ai / admin / aiPreference / browseHistory / feedback 等模块统一导出，不再四拆分散文件）。
- **WebSocket** `src/utils/websocket.js`：`ws://host/ws/chat/{userId}`，30s 心跳，断线自动重连（最多 5 次）。
- **样式**：tailwindcss 3 + weapp-tailwindcss 原子化 CSS（小程序）；marked 18 渲染 AI 回答 Markdown。
- **构建脚本**：`dev:mp-weixin` / `build:mp-weixin`（微信小程序）、`dev:h5` / `build:h5`。
- 环境变量在 `.env.local`（由 `.env.example` 复制）配 `VITE_API_BASE_URL`、`VITE_WS_BASE_URL`。
- 根目录附多篇中文功能说明（聊天重构、选学校级联对接、发布页位置信息、主题样式统一、微信小程序配置、连接测试指南）。

### 4.3 `campus-wall-ai` — AI 微服务 v2（含 GraphRAG 引擎）

详见 §6。FastAPI + LangGraph 服务（**已吸收原 `campus-wall-graphrag` 全部能力**），监听 **:8011**。在原 GraphRAG（Neo4j 知识图谱 + 双向量索引 + 三角色 LLM 本地优先/云端降级）之上，新增 LangGraph QA agent、AI 发帖子图、SSE 流式、Redis Streams 异步记忆。对外仍保留 graphrag HTTP 契约 **9 端点**：`/health` `/index` `/query` `/query/stream`（SSE）`/ingest-post`（发帖入图谱）`/match-posts`（帖子匹配）`DELETE /posts/{id}` `/documents` `DELETE /documents/{id}`；另有 `/ai/*` 用户面端点。

### 4.4 `campus-wall-data-pipeline` — 数据管道（ETL）

把校园墙/微信原始数据，清洗、**脱敏**、转成「问题—参考答案」知识单元，灌入 campus-wall-ai（原 graphrag，`POST /index`）。

- **流程**：`数据源 → clean（去噪/广告/问候、问答检测）→ desensitize（PII 抹除 + 发言人假名化）→ KnowledgeUnit → /index`。
- **数据源**：`sources/campus_wall.py`（MySQL post+comment → 问答线程）、`sources/wechat.py`（WeChatMsg 本地导出目录/CSV/JSON → 滑窗 Q&A）。
- **CLI**：`python ingest.py --source campus_wall --out out/campus.jsonl --limit 50`（默认 dry-run 落 JSONL）；人工核对脱敏质量后 `--push` 才真正入库。
- **脱敏覆盖**：手机号/身份证/银行卡/邮箱/QQ/微信号/学号/宿舍门牌/链接/`wxid_`前缀/`@提及`/`#接龙`点名；真实人名靠 `NAME_BLACKLIST_FILE` 花名册精确替换。
- ⚠️ **合规前提**：不爬微信，由账号持有者本机导出自己可见记录；脱敏先行；先抽检后入库。

### 4.5 `campus-wall-monitor-ui` — 运营管理后台

Vue 3.5 + Element Plus 桌面 SPA，**约 12 个权限驱动菜单页 + 403**：`dashboard`（运营看板）/ `overview`（系统监控）/ `moderation`（内容审核）/ `reports`（举报处理）/ `feedbacks`（意见反馈）/ `verification`（学生认证）/ `users`（用户管理）/ `admins`（管理员）/ `roles`（角色权限）/ `configs`（系统配置）/ `audit`（操作审计）+ `forbidden`（403）。

- **RBAC 前端框架**：Pinia `useUserStore`（token/roles/permissions、hasPerm）+ `v-permission` 指令（无权限移除 DOM）+ router `meta.perms` 守卫（无 token 跳登录、刷新拉 `/v1/admin/auth/me` 重建权限、perms 不满足跳 /forbidden）+ MainLayout 按 hasPerm 渲染菜单。后端是鉴权权威，前端仅 UI 隐藏。
- **运营看板 `Dashboard.vue`**：KPI 卡（总用户/DAU/今日新增含环比/总帖/今日新增帖/总评论/AI 提问总数/待审积压）+ 7/30/90 天趋势折线 + 分布饼图（category/campus/feedbackType/moderationStatus）+ 热帖 Top10；图表统一封装 `BaseChart.vue`（vue-echarts）。
- 所有后端调用走**相对路径**，由 nginx 同源反代（`/api` → Java 8080，`/grafana` → Grafana 3000），避免 CORS、不硬编码端口。
- 构建产物 `dist/` 由 ops 的 nginx 容器（`campus-monitor-ui`，宿主 **8090**）托管，`try_files ... /index.html` 支持 history 路由；另有 **preview 模式**（`vite preview` 托管已 build 的 dist，dev 5173 / preview 8090，给 B 机部署用，改 A 机 IP 只动 GRAFANA_TARGET 一处）。
- 调用接口：`/api/v1/admin/login`、运营看板 `/api/v1/admin/stat/{overview,trend,active,distribution,top-posts}`、以及 `/api/v1/admin/*`（moderation/reports/feedbacks/verification/users/admins/roles/permissions/configs/audit）。
- Grafana 内嵌看板 UID 已对接真实值 `campus-business / host-system / jvm-app`（`src/config.js` 整页 kiosk 内嵌，已弃用 panelId 单面板占位方案）。

### 4.6 `campus-wall-ops/alert-adapter` — 告警转发（ops 子服务）

单文件 FastAPI 微服务，把 Alertmanager webhook 转成**企业微信/钉钉** markdown 消息转发。**原独立子模块 `campus-wall-alert-adapter` 已并入 `campus-wall-ops/alert-adapter/`**（与监控栈同仓，compose `build: ./alert-adapter` 自洽）。

- `POST /alert` 接收并转发到 `ALERT_WEBHOOK`；`GET /health` 健康检查。容器端口 **9094**。
- `ALERT_CHANNEL`：`wecom`（默认）或 `dingtalk`，决定包体格式。
- **防御设计**：`ALERT_WEBHOOK` 留空则只记日志不崩溃；下游发送失败不阻塞；支持 `send_resolved`（恢复通知）。

### 4.7 `campus-wall-ops` — 运维编排与监控基建

Docker Compose 统一编排所有基础设施与监控栈。

- **主编排** `docker-compose.yml`：数据层（mysql/redis/minio/neo4j）、应用层（campus-wall-ai api + 记忆 worker，`network_mode: host`）、监控采集（prometheus/node-exporter/redis-exporter/mysqld-exporter/blackbox-exporter）、可视化告警（grafana/alertmanager/alert-adapter）、展示层（monitor-ui nginx）。**15 个活跃服务**（cadvisor 整段注释，国内拉取失败）。
- campus-wall-ai 服务：`build.context = ../campus-wall-ai`（含 Dockerfile + app 代码）、`image: campus-wall-ai:2.0.0`、`network_mode: host`（host 网络下用 localhost 直达 Ollama/后端、局域网直连内网 LLM），端口由 `AI_SERVICE_PORT` 决定（默认 **8011**），env 含 `NEO4J_URI=bolt://localhost:7688`、`BACKEND_BASE_URL=http://localhost:8080`、VLM_*、POST_VECTOR_INDEX_NAME，CHAT 走内网 Qwen3.6-35B（172.21.160.101:8003）；另起同镜像 `campus-wall-ai-worker` 进程消费 Redis Streams 做异步记忆。`env_file = ./ai-service/.env`（该目录仅存部署侧 `.env`，密钥不入库）。
- **资源限制覆盖** `docker-compose.override.yml`：按 4 核 8G 服务器分配（总约 5.5GB），如 neo4j 1.5g、mysql 1g、campus-wall-ai/prometheus 各 512m。`docker-compose.demo.yml` 为 demo 精简版。
- **监控配置** `monitoring/`：Prometheus 抓取（15s，含 `host.docker.internal:8080` 的 Spring Boot `/actuator/prometheus`、blackbox 探针 MinIO/campus-wall-ai/Neo4j）；Grafana 数据源 + 3 个预置看板（business / host-system / jvm-app）；Alertmanager 单 route → `campus-webhook`（`alert-adapter:9094`）；8 条告警规则（ServiceDown、BlackboxProbeFailed、Host CPU/内存/磁盘、JvmHeapHigh、HttpServerErrorRateHigh[severity=**warning**]、ModerationBacklog[指标 `campus_moderation_pending`]）。
- **nginx** `monitoring/nginx/monitor-ui.conf`：`/` SPA、`/api/` → `host.docker.internal:8080`、`/grafana/` → `campus-grafana:3000`（支持 WebSocket）。
- **部署** `deploy/campus-wall.service`：systemd 托管宿主机 Spring Boot jar（`-Xms1g -Xmx1.5g`，失败自动重启）。
- `alert-adapter/` 子目录含完整源码（`app.py` + Dockerfile，原独立子模块已并入，`build: ./alert-adapter` 自洽）；campus-wall-ai 构建上下文指向同级 `../campus-wall-ai`。

---

## 5. 数据存储

| 存储 | 用途 | 端口（对外） |
|------|------|--------------|
| **MySQL 8.0** (`campus-mysql`) | 业务主数据库 `campus_wall` | 3306 |
| **Redis 7.0** (`campus-redis`) | 多级缓存、点赞/收藏/搜索/时间线、会话 | 6379 |
| **MinIO** (`campus-minio`) | 对象存储（帖子图、头像、聊天文件，bucket `campus-wall`） | 9000(API) / 9001(Console) |
| **Neo4j 5** (`campus-neo4j`) | GraphRAG 知识图谱 + 原生向量索引（cosine, 1024 维） | 7475(HTTP) / 7688(Bolt) |

**MySQL 主要表（当前约 37 张）**：业务核心 `region` `university` `user` `post` `comment` `user_interaction` `user_follow` `topic` `notification` `browse_history` `search_record` `chat_session` `chat_message` `message` `ai_chat_record` `ai_preference` `moderation_log` `feedback` `user_like` `custom_emoji`；板块/排行/认证 `tag` `post_tag` `team_member` `post_campus` `hot_rank_config` `student_verification`；AI 长期记忆 `ai_user_memory`；管理端 RBAC `admin_user` `admin_role` `admin_permission` `admin_user_role` `admin_role_permission`；审计/看板/配置 `admin_oper_log` `stat_daily` `sys_config`。

**Neo4j 图模型**：
- 知识库子图：`Document`（约束 `id` 唯一）—`HAS_CHUNK`→`Chunk`（带 `embedding` 向量）；`Document`—`MENTIONS`→`Entity`（约束 `name` 唯一）；`Entity`—`RELATED{type}`→`Entity`（实体关系三元组）。
- 帖子子图（新）：`Post`—`DESCRIBES`→`Item`、`Post`—`HAS_INTENT`→`Intent`、`Post`—`IN_CATEGORY`→`Category`、`Post`—`TAGGED`→`Tag`。
- **两个向量索引**（均 cosine、1024 维）：`campus_chunk_vector`（FOR Chunk）+ `campus_post_vector`（FOR Item）。

---

## 6. AI 问答链路（GraphRAG）

### 6.1 架构

`campus-wall-ai`（原 `campus-wall-graphrag`）是 AI 学长的核心引擎，被 Java 后端通过 HTTP 调用。

**三角色 LLM + 本地优先/云端降级 failover**（`app/llm.py` 的 `_with_fallback`，三个独立 OpenAI 兼容客户端）：
- **chat**：primary 本地 Ollama `qwen2.5:7b` → fallback 云端 `qwen-plus`（默认开）。负责意图识别 / 三元组抽取 / 答案合成 / 匹配理由。
- **embed**：本地 Ollama `bge-m3`（1024 维）→ fallback 默认关（向量已存 Neo4j，降级须同模型同维）。
- **vlm**（新）：本地 Ollama `qwen2.5vl:7b` → fallback 云端 `qwen-vl-plus`（默认开），`describe_image` 读图。
- ⚠️ 区分两条链路：campus-wall-ai **自身代码默认本地 Ollama 优先**、云端 DashScope 仅兜底；**容器部署侧**（ops `ai-service/.env`）把 chat 改走**内网 Qwen3.6-35B（172.21.160.101:8003）**、其云端降级默认关；本地 demo（`run-graphrag.sh`）才用 `qwen2.5:7b`。
- 入库前经 `app/sanitize.py` 统一 PII 脱敏（用户文字 + VLM 图片描述抹除手机号/微信号/学号等）。

**Graph + Vector 混合检索**：Neo4j 存 Document/Chunk/Entity + Post/Item/Intent/Category/Tag；两个原生向量索引 `campus_chunk_vector`(FOR Chunk) + `campus_post_vector`(FOR Item)，均 cosine、1024 维。检索 = 向量相似度 Top-K → 图遍历补充相关事实 → 拼 prompt → LLM 生成。

**HTTP 契约（9 端点，`app/main.py`）**：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | Neo4j 连通性 → `{status, neo4j}` |
| POST | `/index` | 文档入库（chunk → 嵌入 → 实体抽取 → 写 Neo4j）。按 `doc_id` 幂等 upsert |
| POST | `/query` | 问答：`{question, conversationId?, topK=5}` → `{answer, sources[], conversationId}`；命中为空答「暂无相关校园信息」 |
| POST | `/query/stream` | SSE 流式问答（`text/event-stream`，逐 token，末帧 `done:true`） |
| POST | `/ingest-post` | 发帖异步入图谱：`{post_id,intent,category?,text,images,tags}` → `{post_id,item_id,description,indexed}` |
| POST | `/match-posts` | 帖子匹配：`{question,intent?,topK=5}` → `{intent, matches[{post_id,score,...,reason}], prompt, conversationId}` |
| DELETE | `/posts/{post_id}` | 删帖同步删图谱 → `{deleted, post_id}` |
| GET | `/documents` | 文档列表 |
| DELETE | `/documents/{doc_id}` | 删除文档 |

> intent 合法值：`lost_found` / `second_hand` / `part_time` / `team_up` / `daily`。

**配置（全部走环境变量，无硬编码 key；端口由 `AI_SERVICE_PORT` 决定，默认 8011）**：`NEO4J_URI`（默认 `bolt://localhost:7688`）`NEO4J_USER` `NEO4J_PASSWORD`；`CHAT_*`（BASE_URL/API_KEY/MODEL/TIMEOUT）+ `CHAT_FALLBACK_*`（ENABLED/BASE_URL/API_KEY/MODEL）；`EMBED_*` + `EMBED_FALLBACK_*` + `EMBED_DIM=1024`；`VECTOR_INDEX_NAME=campus_chunk_vector` + `POST_VECTOR_INDEX_NAME=campus_post_vector`；`VLM_*`（ENABLED/BASE_URL/API_KEY/MODEL=qwen2.5vl:7b/IMAGE_MODE/TIMEOUT）+ `VLM_FALLBACK_*`；`BACKEND_BASE_URL`（拼 `/api/v1/files/view` 取帖子图片）。

### 6.2 本地 Demo 运行（已就绪）

工作区 `demo/` 下提供了一套**离线、零成本**的本地运行方案（不依赖云端 key，只连本机服务）：

| 文件 | 作用 |
|------|------|
| `demo/run-graphrag.sh` | 启动脚本：清理 socks 代理 → 设 Neo4j(`bolt://localhost:7688`) / Chat(`qwen2.5:7b`) / Embed(`bge-m3`) 环境变量 → `uvicorn app.main:app --port 8011`（跑 campus-wall-ai） |
| `demo/seed-knowledge.json` | 16 篇校园知识种子（选课、宿舍、图书馆、食堂、奖学金、转专业、四六级、快递、医保、重修、综测、体测、成绩、校园卡、新生报到、社团） |
| `demo/seed.py` | 逐篇灌库脚本（每篇 `id=source` 幂等可重跑，跳过已完成项） |
| `demo/logs/` | `graphrag.log`（服务日志）、`seed.log`（灌库进度） |

**启动与灌库：**
```bash
# 1. 启动服务（后台，日志进 demo/logs/graphrag.log）
cd /home/nvidia/Desktop/campus-wall/campus-wall-ai
nohup bash ../demo/run-graphrag.sh >> ../demo/logs/graphrag.log 2>&1 & disown

# 2. 健康检查
curl --noproxy '*' http://localhost:8011/health   # {"status":"ok","neo4j":true}

# 3. 灌入知识库（幂等）
cd ../demo && python3 seed.py

# 4. 问答测试
curl --noproxy '*' -X POST http://localhost:8011/query \
  -H 'Content-Type: application/json' \
  -d '{"question":"四级多少分才能报六级？","topK":4}'
```

**当前状态**：16 篇文档已全部入库（Neo4j：16 Document / 16 Chunk / 200 Entity），端到端问答验证通过（答案准确并带来源引用）。

> 注：本机设了全局 socks 代理（`ALL_PROXY`），httpx 不支持会崩溃；脚本/curl 已统一清理代理变量或加 `--noproxy '*'`。

---

## 7. 监控告警体系

```
exporters / actuator ──► Prometheus（抓取 15s，留存 15d）
                              │
                ┌─────────────┼──────────────┐
                ▼                             ▼
            Grafana（看板）           Alertmanager（分组/抑制/路由）
            business / host /                 │ webhook
            jvm 三块看板                       ▼
            （经 nginx /grafana 内嵌）   alert-adapter :9094 ──► 企业微信 / 钉钉
```

- **抓取目标**：node/mysqld/redis exporter、Spring Boot `/actuator/prometheus`、blackbox 探针（MinIO/campus-wall-ai/Neo4j 健康，3 目标）。cadvisor 容器已注释（国内拉取失败），但 `prometheus.yml` 的 cadvisor job 残留会永久 DOWN。
- **告警规则（8 条 / 分 4 组：service-availability / host-resources / application / business）**：`ServiceDown`(up==0, critical)、`BlackboxProbeFailed`(critical)、`HostHighMemory/Disk/CPU`(>90%/85%/90%, warning，磁盘带 `{fstype!~"tmpfs|overlay|squashfs"}` 过滤)、`JvmHeapHigh`(>90%)、`HttpServerErrorRateHigh`(5xx>5%, **severity=warning**)、`ModerationBacklog`(指标 `campus_moderation_pending` 待审>50, 10m)。
- **Alertmanager**：单 route 分组键 `[alertname, job]`，去重 5m、分组等待 30s、重复 4h（无 severity 子路由）；critical 抑制同源 warning；接收器 `campus-webhook` → `alert-adapter:9094/alert`。
- **可视化入口**：管理后台（8090）内嵌 Grafana 看板；Grafana 开启匿名只读 + 允许嵌入，root URL 子路径 `/grafana/`。

---

## 8. 端口规划总表

| 端口 | 服务 | 运行位置 | 用途/访问 |
|------|------|----------|-----------|
| **8080** | Spring Boot 后端 | 宿主机(systemd) | 业务 API、WebSocket、actuator |
| **11434** | Ollama | 宿主机 | 本地 LLM `qwen2.5:7b` + 嵌入 `bge-m3` |
| **8011** | campus-wall-ai (FastAPI) | 宿主机/容器 | AI 学长 + 知识问答 / 帖子匹配（含原 graphrag 9 端点，见 §6.1） |
| **8090** | monitor-ui (nginx) | 容器 | **统一入口**：管理后台 SPA + `/api` + `/grafana` |
| **3306** | MySQL 8.0 | 容器 | 业务数据库 |
| **6379** | Redis 7.0 | 容器 | 缓存 |
| **9000 / 9001** | MinIO | 容器 | 对象存储 API / Console |
| **7475 / 7688** | Neo4j 5 | 容器 | HTTP Browser / Bolt（`bolt://localhost:7688`） |
| **3000** | Grafana | 容器 | 看板（内部，经 nginx 内嵌） |
| **9090** | Prometheus | 容器 | 指标 UI |
| **9093** | Alertmanager | 容器 | 告警 UI |
| **9094** | alert-adapter | 容器 | 接收 Alertmanager webhook |
| **9100 / 9104 / 9121 / 9115** | node / mysqld / redis / blackbox exporter | 容器 | 指标导出（Prometheus 抓取） |
| **8081** | cadvisor | 容器（已注释停用） | 容器资源指标（国内拉取失败，整段注释） |
| **5173** | monitor-ui dev | 本地开发 | Vite dev server |

---

## 9. 本地启动与部署

### 9.1 克隆工作区（含子模块）

```bash
git clone --recurse-submodules <workspace-repo-url>
cd campus-wall
# 若子目录为空：
git submodule update --init --recursive
```

### 9.2 启动基础设施与监控（Docker）

```bash
cd campus-wall-ops
cp .env.example .env && vim .env        # 填 MySQL/Redis/MinIO 密码、告警 webhook 等
# 生产/常规（含资源限制）：
docker compose up -d
# Demo 精简：
docker compose -f docker-compose.yml -f docker-compose.demo.yml up -d
```

### 9.3 启动 Java 后端

```bash
cd campus_wall
cp .env.example .env && vim .env        # 数据源、Redis、DASHSCOPE_API_KEY、MinIO、微信 appid/secret、admin
./mvnw spring-boot:run                  # 开发（默认 profile=dev，:8080）
# 生产：./mvnw clean package 后用 deploy/campus-wall.service systemd 托管 jar
```

### 9.4 启动 campus-wall-ai（本地 demo）

见 §6.2（`demo/run-graphrag.sh` + `demo/seed.py`）。需本机 Ollama 已拉取 `qwen2.5:7b` 和 `bge-m3`，且 Neo4j 容器在跑。

### 9.5 前端

```bash
cd campus-wall-frontend
npm install
npm run dev:mp-weixin          # 微信开发者工具导入 dist/dev/mp-weixin
# 配置 .env.development 的 VITE_API_BASE_URL / VITE_WS_BASE_URL 指向后端
```

### 9.6 管理后台

```bash
cd campus-wall-monitor-ui
npm install && npm run build   # 产物 dist/ 由 ops nginx 托管
docker compose restart monitor-ui   # 在 ops 目录执行
# 访问 http://localhost:8090
```

---

## 10. 环境变量总览

各子项目的 `.env` **绝不提交**（已被 `.gitignore` 忽略），参考各自 `.env.example`。

**campus_wall（必需）**：`MYSQL_URL` `MYSQL_USER` `MYSQL_PASSWORD`、`REDIS_HOST` `REDIS_PORT` `REDIS_PASSWORD`、`DASHSCOPE_API_KEY`、`MINIO_ENDPOINT` `MINIO_ACCESS_KEY` `MINIO_SECRET_KEY`、`WX_APPID` `WX_SECRET`、`ADMIN_USER` `ADMIN_PASS` `ADMIN_USER_ID`。可选：`GRAPHRAG_BASE_URL`(默认 `http://localhost:8011`，配置键名沿用 graphrag.* 减少改动面) `GRAPHRAG_TIMEOUT_MS`(120000) `LLM_MODEL`(qwen-plus) `MINIO_BUCKET`(campus-wall)。

**campus-wall-ai**（端口 `AI_SERVICE_PORT` 默认 8011）：`NEO4J_URI/USER/PASSWORD`、`CHAT_*` + `CHAT_FALLBACK_*`、`EMBED_*` + `EMBED_FALLBACK_*` + `EMBED_DIM`、`VLM_*` + `VLM_FALLBACK_*`、`VECTOR_INDEX_NAME` + `POST_VECTOR_INDEX_NAME`、`BACKEND_BASE_URL`；v2 另需 `DB_URL`(MySQL ai_* 表)、`REDIS_*`(记忆 streams)、`JWT_SECRET`(验签转发用户 JWT)。详见 `ai-service/.env.example`。

**data-pipeline**：`CW_MYSQL_*`（HOST/PORT/USER/PASSWORD/DB）、`GRAPHRAG_URL`、`NAME_BLACKLIST_FILE`。

**alert-adapter**：`ALERT_WEBHOOK`、`ALERT_CHANNEL`(wecom/dingtalk)。

**前端**：`VITE_API_BASE_URL`、`VITE_WS_BASE_URL`。

---

## 11. 安全与合规

- **密钥零硬编码**：所有 API Key / 密码走环境变量；`.env`、`.claude/settings.local.json` 不入库。
- **数据脱敏先行**：data-pipeline 入库前抹除 PII 并假名化发言人；默认 dry-run，人工核对后才 `--push`。
- **微信数据合规**：不爬服务器，仅由账号持有者本机导出自己可见记录；需确认授权覆盖被采集的全部成员。
- **内容审核**：敏感词库 + 审核队列（`moderation_log`），管理后台人工通过/驳回，`ModerationBacklog` 告警兜底。
- **泄露应急**：若敏感信息误入 Git，立即用 `git-filter-repo` / BFG 清理历史并轮换密钥。

---

## 12. 开发协作（Submodule 工作流）

```bash
# 进入某子项目独立开发（拥有自己的分支/历史）
cd campus_wall
git checkout -b feature/xxx
# 开发 → 提交 → 推送 → 在该子仓库提 PR

# 更新所有子项目到各自远程最新
git submodule update --remote

# 根仓库只负责：文档变更、锁定子模块版本指针
```

详见根 `README.md` 与 `campus-wall-docs/02-git-github-guide/`。跨项目文档统一维护在 [`campus-wall-docs/`](./campus-wall-docs/)（项目概览、开发规范、各模块文档、运营手册、商业计划）。

---

*文档基于仓库源码与当前运行状态整理。各子模块的更细节文档见对应目录的 `README.md` 与 `.claude/CLAUDE.md`。*
