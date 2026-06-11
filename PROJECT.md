# Campus Wall 校园墙 — 项目完整文档

> 本文档是 Campus Wall 工作区的**完整技术总文档**，覆盖系统架构、7 个子模块、数据存储、AI 问答链路、监控告警、端口规划、本地启动与部署。内容以仓库源码和当前真实运行状态为准（含本地 GraphRAG 知识库 demo）。
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

工作区采用 **Git Submodule 多仓库**结构：根仓库只锁定各子项目版本与跨项目文档，业务代码分散在 7 个独立子仓库中，各自拥有分支与提交历史。

**核心能力：**
- 用户端微信小程序：帖子社区、AI 学长问答、私信聊天、个人中心
- Java 后端：用户/帖子/评论/私信/AI/审核全业务
- GraphRAG 知识引擎：把校园知识灌入 Neo4j 知识图谱，向量检索 + LLM 生成精准问答
- 数据管道：从校园墙 MySQL / 微信导出抽取知识，清洗脱敏后入库
- 运维监控：Prometheus + Grafana + Alertmanager 全栈观测，告警转发企业微信/钉钉
- 管理后台：内容审核、数据概览、内嵌 Grafana 看板

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
│ campus_wall（Java/Spring Boot）│  HTTP   │ campus-wall-graphrag（FastAPI）│
│ 用户·帖子·评论·私信·AI代理·审核│ ──────► │ 知识图谱检索 + LLM 问答       │
│ 宿主机 :8080（systemd）        │ :8001   │ Neo4j + Ollama / DashScope    │
└───────────────────────────────┘         └──────────────────────────────┘
        │                                          ▲
        │                          ┌───────────────┘ POST /index
        │                  ┌──────────────────────────────┐
        │                  │ campus-wall-data-pipeline     │
        │                  │ 抽取·清洗·脱敏·知识单元入库   │
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
  - GraphRAG demo（`demo/run-graphrag.sh` → `:8001`，本地直跑，见 §6）
- **Docker Compose 编排**（`campus-wall-ops`）：MySQL、Redis、MinIO、Neo4j、Prometheus、Grafana、Alertmanager、各 exporter、alert-adapter、monitor-ui(nginx)。
- 容器访问宿主机服务统一用 `host.docker.internal`（如 nginx 代理 `/api` → `host.docker.internal:8080`，graphrag 连 Ollama）。
- 为避开宿主机已占用端口，Neo4j 对外映射为 **7475(HTTP) / 7688(Bolt)**（容器内仍是 7474/7687）。

### 2.3 关键数据流

**① 用户问 AI 学长：**
```
小程序 → POST /api/v1/ai-senior/chat → Java AiSeniorService
       → HTTP POST :8001/query（GraphRAG）
       → bge-m3 向量化问题 → Neo4j 向量检索 Top-K → 图遍历补充事实
       → qwen LLM 生成答案 → 回传 → 小程序展示（带来源引用）
```

**② 知识入库：**
```
MySQL post+comment / 微信导出
  → data-pipeline: clean → desensitize（脱敏）→ KnowledgeUnit
  → POST :8001/index → chunk → bge-m3 嵌入 + LLM 实体抽取 → 写入 Neo4j
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
| `campus_wall` | Java 17 · Spring Boot 3.4.2 | MyBatis-Plus 3.5.9 · Spring AI 1.0.0-M6 · JJWT 0.11.5 · MinIO 8.5.7 · Flyway · WebSocket · Micrometer Prometheus | 核心业务后端 |
| `campus-wall-frontend` | uni-app 3.0 · Vue 3.4.21 · TS 4.9 | Vite 5.2 · Sass 1.99 · vue-i18n 9.1 | 微信小程序用户端 |
| `campus-wall-graphrag` | Python 3.12 · FastAPI 0.115 | neo4j-graphrag 1.4.1 · OpenAI SDK 1.59（兼容 DashScope/Ollama） · Pydantic 2.10 | GraphRAG 问答引擎 |
| `campus-wall-data-pipeline` | Python 3.x | PyMySQL 1.1.1 · requests 2.32 | ETL：抽取·清洗·脱敏·入库 |
| `campus-wall-monitor-ui` | Vue 3.5.10 · JS | Element Plus 2.8.4 · Vue Router 4.4 · Pinia 2.2 · Axios 1.7 · Vite 5.4 | 运营管理后台 |
| `campus-wall-alert-adapter` | Python 3.12 · FastAPI 0.115 | uvicorn 0.34 · httpx 0.28 | 告警转发（企微/钉钉） |
| `campus-wall-ops` | Docker Compose | MySQL 8.0 · Redis 7.0 · Neo4j 5 · Prometheus v2.54 · Grafana 11.2 · Alertmanager v0.27 · Nginx 1.27 | 编排与监控基建 |

---

## 4. 子模块详解

### 4.1 `campus_wall` — Java 核心后端

Spring Boot 3.4.2 / Java 17 单体应用，按领域分包：`social`（用户/关注/私信/通知/表情）、`community`（帖子/评论/分类/搜索/浏览历史）、`ai`（AI 学长/偏好）、`admin`（审核/文件/反馈/Redis 迁移）、`infrastructure`（WebSocket）。

- **应用名** `campus-wall-backend`，端口默认 **8080**，profile 默认 `dev`。
- **统一响应** `Result<T> = { code, message, data }`（成功 `code === 200`）。
- **鉴权**：JWT（微信 code 换 token），请求头 `Authorization: Bearer <token>`。

**主要 REST 接口（前缀 `/api/v1`）：**

| 控制器 | 前缀 | 职责 |
|--------|------|------|
| UserController | `/users` | 微信登录、当前用户、详情、更新 |
| UserFollowController | `/follow` | 关注/取关、关注列表、粉丝列表 |
| PostController | `/posts` | 发布、列表、时间线、热帖、排行榜、详情、点赞、收藏、浏览 |
| CommentController | `/comments` | 评论增删、列表、点赞 |
| CategoryController / SearchController | `/categories` `/search` | 分类话题、搜帖、热搜 |
| BrowseHistoryController | `/browse-history` | 浏览历史记录/清空 |
| MessageController | `/messages` | 通知、私信会话/消息/发送/撤回/已读 |
| NotificationController | `/notifications` | 评论/点赞通知 |
| UniversityController / RegionController | `/universities` `/regions` | 高校搜索、行政区划级联（选学校用） |
| EmojiController | `/emojis` | 自定义表情列表 |
| **AiSeniorController** | `/ai-senior` | AI 问答、流式问答、知识库导入/列表/删除/清空、聊天历史 |
| AiPreferenceController | `/ai-preference` | AI 偏好、系统提示词 |
| AdminModerationController | `/admin` | 管理员登录、审核队列、扫描、通过/驳回、统计 |
| FileController | `/files` | MinIO 文件上传（帖子图/附件、头像、聊天图/语音、AI 文件、通知横幅等） |
| FeedbackController | `/feedback` | 用户反馈 |
| RedisMigrationController | `/redis/migration` | 点赞/收藏/搜索/时间线数据迁移到 Redis |

**WebSocket**：配置类 `WebSocketConfig`（`ServerEndpointExporter`），端点 `ChatWebSocketHandler` 路径 `/ws/chat/{userId}`，会话管理默认 `InMemorySessionManager`（单机内存，可换 Redis 分布式实现）。

**数据库**：Flyway 管理迁移（`V1.0__init_schema.sql` 初始化、`V2.1__add_custom_emoji_table.sql` 表情表），库 `campus_wall`（utf8mb4），约 19 张表（见 §5）。

**外部依赖配置**：DashScope（`qwen-plus`，兼容模式）、GraphRAG（默认 `http://localhost:8001`，超时 120s）、MinIO（bucket `campus-wall`）、Redis（多级缓存 TTL：用户 2h / 帖子详情 30m / 帖子列表 5m 等）。

> ⚠️ `application-dev.yaml` 中数据源/Redis/MinIO 指向了一个公网 IP（`121.43.119.5`）与若干默认值，敏感项一律走环境变量（`MYSQL_PASSWORD`、`DASHSCOPE_API_KEY`、`MINIO_SECRET_KEY` 等），生产 profile 强制环境变量注入。

### 4.2 `campus-wall-frontend` — 微信小程序

uni-app 3 + Vue 3 + TypeScript，5 个底部 Tab（圈子 / 发现 / AI / 私信 / 我的），30+ 页面。

- **页面分组**：`index`(帖子列表)、`discover`(分类)、`ai`(问答/历史/偏好)、`message`(私信/通知/点赞/粉丝)、`user`(个人中心/选学校/我的帖子收藏点赞/设置等)、`post/detail`、`publish`、`search`、`login`、`leaderboard`、`hot-posts`。
- **请求层** `src/utils/request.js`：基址 `import.meta.env.VITE_API_BASE_URL`（默认 `http://localhost:8080`），自动注入 JWT，401 清登录态。API 分 `community.js / social.js / ai.js / admin.js`。
- **WebSocket** `src/utils/websocket.js`：`ws://host/ws/chat/{userId}`，30s 心跳，断线自动重连（最多 5 次）。
- **构建脚本**：`dev:mp-weixin` / `build:mp-weixin`（微信小程序）、`dev:h5` / `build:h5`。
- 环境变量在 `.env.development` / `.env.production` 配 `VITE_API_BASE_URL`、`VITE_WS_BASE_URL`。
- 根目录附多篇中文功能说明（聊天重构、选学校级联对接、发布页位置信息、主题样式统一、微信小程序配置、连接测试指南）。

### 4.3 `campus-wall-graphrag` — GraphRAG 问答引擎

详见 §6。FastAPI 服务，Neo4j 知识图谱 + 向量索引 + 双 LLM（Chat 抽取/生成、Embedding 向量化）。HTTP 契约：`/health` `/index` `/query` `/documents`。

### 4.4 `campus-wall-data-pipeline` — 数据管道（ETL）

把校园墙/微信原始数据，清洗、**脱敏**、转成「问题—参考答案」知识单元，灌入 GraphRAG（`POST /index`）。

- **流程**：`数据源 → clean（去噪/广告/问候、问答检测）→ desensitize（PII 抹除 + 发言人假名化）→ KnowledgeUnit → /index`。
- **数据源**：`sources/campus_wall.py`（MySQL post+comment → 问答线程）、`sources/wechat.py`（WeChatMsg 本地导出目录/CSV/JSON → 滑窗 Q&A）。
- **CLI**：`python ingest.py --source campus_wall --out out/campus.jsonl --limit 50`（默认 dry-run 落 JSONL）；人工核对脱敏质量后 `--push` 才真正入库。
- **脱敏覆盖**：手机号/身份证/银行卡/邮箱/QQ/微信号/学号/宿舍门牌/链接/`wxid_`前缀/`@提及`/`#接龙`点名；真实人名靠 `NAME_BLACKLIST_FILE` 花名册精确替换。
- ⚠️ **合规前提**：不爬微信，由账号持有者本机导出自己可见记录；脱敏先行；先抽检后入库。

### 4.5 `campus-wall-monitor-ui` — 运营管理后台

Vue 3.5 + Element Plus 桌面 SPA，3 个页面：`Login`（拿 JWT）、`Overview`（业务统计卡片 + 服务存活 + 内嵌 Grafana iframe）、`Moderation`（审核队列、立即扫描、行内通过/驳回）。

- 所有后端调用走**相对路径**，由 nginx 同源反代（`/api` → Java 8080，`/grafana` → Grafana 3000），避免 CORS、不硬编码端口。
- 构建产物 `dist/` 由 ops 的 nginx 容器（`campus-monitor-ui`，宿主 **8090**）托管，`try_files ... /index.html` 支持 history 路由。
- 调用接口：`/api/v1/users/login`、`/api/v1/admin/stats`、`/api/v1/admin/moderation/{queue,scan,{id}/approve,{id}/reject}`。
- Grafana 内嵌看板 UID/panelId 在 `src/config.js` 占位，待 ops 提供真实值后改配置重新 build。

### 4.6 `campus-wall-alert-adapter` — 告警转发

单文件 FastAPI 微服务，把 Alertmanager webhook 转成**企业微信/钉钉** markdown 消息转发。

- `POST /alert` 接收并转发到 `ALERT_WEBHOOK`；`GET /health` 健康检查。容器端口 **9094**。
- `ALERT_CHANNEL`：`wecom`（默认）或 `dingtalk`，决定包体格式。
- **防御设计**：`ALERT_WEBHOOK` 留空则只记日志不崩溃；下游发送失败不阻塞；支持 `send_resolved`（恢复通知）。

### 4.7 `campus-wall-ops` — 运维编排与监控基建

Docker Compose 统一编排所有基础设施与监控栈。

- **主编排** `docker-compose.yml`：数据层（mysql/redis/minio/neo4j）、应用层（graphrag）、监控采集（prometheus/node-exporter/redis-exporter/mysqld-exporter/blackbox-exporter）、可视化告警（grafana/alertmanager/alert-adapter）、展示层（monitor-ui nginx）。
- **资源限制覆盖** `docker-compose.override.yml`：按 4 核 8G 服务器分配（总约 5.5GB），如 neo4j 1.5g、mysql 1g、graphrag/prometheus 各 512m。`docker-compose.demo.yml` 为 demo 精简版。
- **监控配置** `monitoring/`：Prometheus 抓取（15s，含 `host.docker.internal:8080` 的 Spring Boot `/actuator/prometheus`、blackbox 探针 MinIO/GraphRAG/Neo4j）；Grafana 数据源 + 3 个预置看板（business / host-system / jvm-app）；Alertmanager 路由到 `alert-adapter:9094`；8 条告警规则（ServiceDown、BlackboxProbeFailed、Host CPU/内存/磁盘、JvmHeapHigh、HttpServerErrorRateHigh、ModerationBacklog）。
- **nginx** `monitoring/nginx/monitor-ui.conf`：`/` SPA、`/api/` → `host.docker.internal:8080`、`/grafana/` → `campus-grafana:3000`（支持 WebSocket）。
- **部署** `deploy/campus-wall.service`：systemd 托管宿主机 Spring Boot jar（`-Xms1g -Xmx1.5g`，失败自动重启）。
- `graphrag-service/`、`alert-adapter/` 子目录含各自 Dockerfile（构建上下文）。

---

## 5. 数据存储

| 存储 | 用途 | 端口（对外） |
|------|------|--------------|
| **MySQL 8.0** (`campus-mysql`) | 业务主数据库 `campus_wall` | 3306 |
| **Redis 7.0** (`campus-redis`) | 多级缓存、点赞/收藏/搜索/时间线、会话 | 6379 |
| **MinIO** (`campus-minio`) | 对象存储（帖子图、头像、聊天文件，bucket `campus-wall`） | 9000(API) / 9001(Console) |
| **Neo4j 5** (`campus-neo4j`) | GraphRAG 知识图谱 + 原生向量索引（cosine, 1024 维） | 7475(HTTP) / 7688(Bolt) |

**MySQL 主要表（约 19 张）**：`region` `university` `user` `post` `comment` `user_interaction` `user_follow` `topic` `notification` `browse_history` `search_record` `chat_session` `chat_message` `message` `ai_chat_record` `ai_preference` `moderation_log` `feedback` `user_like` `custom_emoji`。

**Neo4j 图模型**：`Document`（文档，约束 `id` 唯一）—`HAS_CHUNK`→`Chunk`（带 `embedding` 向量）；`Document`—`MENTIONS`→`Entity`（约束 `name` 唯一）；`Entity`—`RELATED{type}`→`Entity`（实体关系三元组）。向量索引名 `campus_chunk_vector`。

---

## 6. AI 问答链路（GraphRAG）

### 6.1 架构

`campus-wall-graphrag` 是 AI 学长的核心引擎，被 Java 后端通过 HTTP 调用。

**双 LLM 架构**（两个独立 OpenAI 兼容客户端，可分别替换）：
- **Chat LLM**：实体/关系抽取 + 答案生成。生产可用云端 DashScope `qwen-plus`；本地 demo 用 Ollama `qwen2.5:7b`。
- **Embedding LLM**：向量化。Ollama `bge-m3`（1024 维）。

**Graph + Vector 混合检索**：Neo4j 存 Document/Chunk/Entity；Chunk 带原生向量索引（cosine, 1024 维）。检索 = 向量相似度 Top-K → 图遍历补充相关事实 → 拼 prompt → LLM 生成。

**HTTP 契约**（`app/main.py`）：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | Neo4j 连通性 |
| POST | `/index` | 文档入库（chunk → 嵌入 → 实体抽取 → 写 Neo4j）。`index_document` 按 `doc_id` 幂等 upsert（同 id 会先删旧 chunk/实体再重建） |
| POST | `/query` | 问答：`{question, conversationId?, topK=5}` → `{answer, sources[], conversationId}`；命中为空答「暂无相关校园信息」 |
| GET | `/documents` | 文档列表 |
| DELETE | `/documents/{doc_id}` | 删除文档 |

**配置（全部走环境变量，无硬编码 key）**：`NEO4J_URI`（默认 `bolt://localhost:7688`）`NEO4J_USER` `NEO4J_PASSWORD`；`CHAT_BASE_URL` `CHAT_API_KEY` `CHAT_MODEL`；`EMBED_BASE_URL` `EMBED_API_KEY` `EMBED_MODEL` `EMBED_DIM=1024`；`GRAPHRAG_PORT=8001`；`VECTOR_INDEX_NAME`。兼容回退到 legacy `LLM_*` 变量。

### 6.2 本地 Demo 运行（已就绪）

工作区 `demo/` 下提供了一套**离线、零成本**的本地运行方案（不依赖云端 key，只连本机服务）：

| 文件 | 作用 |
|------|------|
| `demo/run-graphrag.sh` | 启动脚本：清理 socks 代理 → 设 Neo4j(`bolt://localhost:7688`) / Chat(`qwen2.5:7b`) / Embed(`bge-m3`) 环境变量 → `uvicorn app.main:app --port 8001` |
| `demo/seed-knowledge.json` | 16 篇校园知识种子（选课、宿舍、图书馆、食堂、奖学金、转专业、四六级、快递、医保、重修、综测、体测、成绩、校园卡、新生报到、社团） |
| `demo/seed.py` | 逐篇灌库脚本（每篇 `id=source` 幂等可重跑，跳过已完成项） |
| `demo/logs/` | `graphrag.log`（服务日志）、`seed.log`（灌库进度） |

**启动与灌库：**
```bash
# 1. 启动服务（后台，日志进 demo/logs/graphrag.log）
cd /home/nvidia/Desktop/campus-wall/campus-wall-graphrag
nohup bash ../demo/run-graphrag.sh >> ../demo/logs/graphrag.log 2>&1 & disown

# 2. 健康检查
curl --noproxy '*' http://localhost:8001/health   # {"status":"ok","neo4j":true}

# 3. 灌入知识库（幂等）
cd ../demo && python3 seed.py

# 4. 问答测试
curl --noproxy '*' -X POST http://localhost:8001/query \
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

- **抓取目标**：node/mysqld/redis exporter、cadvisor（容器，yml 中可选）、Spring Boot `/actuator/prometheus`、blackbox 探针（MinIO/GraphRAG/Neo4j 健康）。
- **告警规则（8 条）**：`ServiceDown`(up==0, critical)、`BlackboxProbeFailed`(critical)、`HostHighMemory/Disk/CPU`(>90%/85%/90%, warning)、`JvmHeapHigh`(>90%)、`HttpServerErrorRateHigh`(5xx>5%)、`ModerationBacklog`(待审>50, 10m)。
- **Alertmanager**：分组键 `[alertname, job]`，去重 5m、分组等待 30s、重复 4h；critical 抑制同源 warning；接收器 `campus-webhook` → `alert-adapter:9094/alert`。
- **可视化入口**：管理后台（8090）内嵌 Grafana 看板；Grafana 开启匿名只读 + 允许嵌入，root URL 子路径 `/grafana/`。

---

## 8. 端口规划总表

| 端口 | 服务 | 运行位置 | 用途/访问 |
|------|------|----------|-----------|
| **8080** | Spring Boot 后端 | 宿主机(systemd) | 业务 API、WebSocket、actuator |
| **11434** | Ollama | 宿主机 | 本地 LLM `qwen2.5:7b` + 嵌入 `bge-m3` |
| **8001** | GraphRAG (FastAPI) | 宿主机/容器 | 知识问答 `/query` `/index` |
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
| **8081** | cadvisor | 容器（可选） | 容器资源指标 |
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

### 9.4 启动 GraphRAG（本地 demo）

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

**campus_wall（必需）**：`MYSQL_URL` `MYSQL_USER` `MYSQL_PASSWORD`、`REDIS_HOST` `REDIS_PORT` `REDIS_PASSWORD`、`DASHSCOPE_API_KEY`、`MINIO_ENDPOINT` `MINIO_ACCESS_KEY` `MINIO_SECRET_KEY`、`WX_APPID` `WX_SECRET`、`ADMIN_USER` `ADMIN_PASS` `ADMIN_USER_ID`。可选：`GRAPHRAG_BASE_URL`(默认 `http://localhost:8001`) `GRAPHRAG_TIMEOUT_MS`(120000) `LLM_MODEL`(qwen-plus) `MINIO_BUCKET`(campus-wall)。

**graphrag**：`NEO4J_URI/USER/PASSWORD`、`CHAT_BASE_URL/API_KEY/MODEL`、`EMBED_BASE_URL/API_KEY/MODEL/DIM`、`GRAPHRAG_PORT`。

**data-pipeline**：`MYSQL_*`、`GRAPHRAG_URL`、`NAME_BLACKLIST_FILE`。

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
