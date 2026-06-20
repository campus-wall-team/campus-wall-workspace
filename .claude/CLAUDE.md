# campus-wall（根 workspace）- Claude Code 开发指南

## 项目概述

校园墙 Campus Wall 的**根聚合仓库**，采用 **Git Submodule 多仓库**结构：根仓库只锁定各子项目版本指针与跨项目文档（`PROJECT.md` / `README.md` / `campus-wall-docs/` / `deploy/`），业务代码分散在 **6 个子模块**中，各自拥有独立分支与提交历史。

> 根仓库在 `master` 分支；6 个子仓库都在 `main` 分支（见 `.gitmodules`）。
> 团队决定**保留 submodule 多仓聚合**（不迁 monorepo），因不需要仓级权限隔离。

## 6 个子模块（职责一句话 + 端口）

| 子模块 | 技术栈 | 职责 | 端口 |
|--------|--------|------|------|
| `campus_wall` | Java 17 + Spring Boot 3.4.2 | 主后端单体：用户/帖子/评论/AI学长/私信/审核/管理端 RBAC | **8080**（宿主机 systemd / IDE） |
| `campus-wall-ai` | Python + FastAPI + LangGraph + Neo4j | AI 微服务（**已吸收原 GraphRAG 全部能力**）：知识图谱索引、知识问答、找帖、AI 发帖、异步记忆 | **8011** |
| `campus-wall-frontend` | uni-app 3 + Vue 3 + TS | C 端学生前端，**主端微信小程序**（圈子/发现/AI学长/私信/我的） | 仅调 Java :8080 |
| `campus-wall-monitor-ui` | Vue 3 + Element Plus | 运营管理后台 SPA：看板/监控/审核/举报反馈认证/用户/RBAC/审计/配置 | **8090**（ops nginx 容器 / preview） |
| `campus-wall-data-pipeline` | Python ETL | 从 MySQL/微信导出抽知识 → 清洗脱敏 → 推送 AI 服务 `/index` 建图谱（默认 dry-run） | — |
| `campus-wall-ops` | Docker Compose | 运维基础设施即代码：数据层 + 监控告警 + nginx 反代 + **alert-adapter**（已并入，:9094） | 见各服务 |

> ⚠️ **不是 7 个子模块**：`alert-adapter` 早前已并入 `campus-wall-ops/alert-adapter`（不再是独立子仓，原仓 archived）；`graphrag` 早前已并入 `campus-wall-ai`（旧 graphrag 容器 :8001 已下线，统一到 :8011）。当前固定 6 个子模块。

> `campus-wall-docs` 是跨项目文档目录，**属于根仓库 master，不是子模块**。

## 机器分工

- **A 机（GB10 / `172.21.160.212` / 121G 内存 / 主机名 spark-ab42）**：跑**所有中间件**（MySQL / Redis / MinIO / Neo4j 多实例）+ **AI 服务容器**（`campus-wall-ai` ai-api + memory-worker）+ 本地模型（**bge-m3 / Ollama 只绑 A 机 localhost，未对 LAN 暴露**）。AI 服务连 Neo4j/Redis/bge-m3 一律走 `localhost`。
- **B 机（开发机）**：跑 **Java 后端 + 前端**，连 A 机中间件用内网 IP `172.21.160.212`。dev 每人一套。
- **`172.21.160.101:8003`**：内网 **Qwen3.6-35B**（`/chat` 走它）；与 A 机分开的另一台 GPU 机。

> 拓扑要点：AI 服务**跑在 A 机**（容器 host 网络），故它连本地中间件用 `localhost`；Java 后端**跑在 B 机**，连 A 机中间件用 `172.21.160.212`。开发机若挂梯子/VPN 会劫持内网连接致转发挂起，需关梯子或配 `NO_PROXY` LAN bypass。

## 三环境隔离 dev / test / prod 与切换入口

团队约定：**dev 每人一套，test / prod 全队共享**（2 人 = 2 dev + 1 test + 1 prod）。

| 资源 | prod | dev | test |
|------|------|-----|------|
| **Neo4j**（社区版单库→多实例隔离） | 7688 `campus-neo4j` | 7691 `campus-neo4j-dev` | 7689 `campus-neo4j-test` |
| **MySQL 库** | `campus_wall` | `campus_wall_dev_a` / `_dev_b` | `campus_wall_test` |
| **Redis 逻辑库** | DB 0 | DB 1 / DB 2 | DB 15 |
| **MinIO bucket** | `campus-wall` | `campus-dev-a` / `campus-dev-b` | `campus-test` |

> Neo4j 三实例均已纳入 ops `docker-compose.yml`（服务 `neo4j-dev` / `neo4j-test`，`restart: unless-stopped`）；MinIO bucket 由 Java `MinioUtil` 启动时自动建。

**切环境入口：**
- **AI 服务（`campus-wall-ai`）**：`APP_ENV=dev|test|prod`，`app/config.py` 自动加载 `.env.<env>`（本地实配）→ 回退 `.env.<env>.example`（模板）。模板：`campus-wall-ai/.env.{dev,test,prod}.example`。VSCode 见 `campus-wall-ai/.vscode/launch.json`（内置 dev/test/prod + 评测共 4 个运行配置）。
- **Java 后端（`campus_wall`）**：`SPRING_PROFILES_ACTIVE=dev|test|prod` + `application-{dev,test,prod}.yaml`（`application-test.yaml` → `campus_wall_test` / Redis DB 15 / bucket `campus-test` / AI 服务 `172.21.160.212:8011`）。IDEA 用 Spring profiles 或 Run Config 环境变量。
- **连通性自检**：`deploy/team-dev/check_env.py <env>`（深度：按环境真连具体库/Redis DB/Neo4j 实例，A 机/管理员机跑）；`deploy/team-dev/check-connection.sh`（端口级，B 机成员用）。

## 多仓提交顺序（铁律）

子模块改动必须**先提交子仓、再在根仓库前进指针**：

```bash
# 1) 进入子模块，在 main 分支提交并推送
cd campus-wall-ai && git add -p && git commit -m "feat(...): ..." && git push

# 2) 回根仓库，前进该子模块指针并提交
cd .. && git add campus-wall-ai && git commit -m "chore(submodule): 前进 campus-wall-ai 指针（...）"
```

- 根提交信息惯例：`chore(submodule): 前进 <子模块> 指针（一句话说明）`。
- **勿跑 `git submodule sync`**：子模块已配 `github-campus-wall` SSH 别名，本机直接在子目录里 git 操作即可（详见自动记忆 github-push-access）。
- 切勿"先前进根指针、后提交子仓"——会让根指向一个尚未推送的 commit。

## 关键文档索引（指向 `campus-wall-docs/`）

| 主题 | 文档 |
|------|------|
| 总览·系统架构 | `00-project-overview/02-系统架构.md`（6 个服务职责、部署拓扑） |
| 总览·导航 | `campus-wall-docs/README.md`（全文档地图） |
| 新人上手 | `00-project-overview/04-新人快速上手.md` |
| 全栈开发流程 + 三环境切换 | `01-development-standards/全栈开发流程与三环境切换.md` |
| 团队协作流程（小白友好） | `01-development-standards/团队开发流程指南.md` |
| Agent 开发与评测闭环 | `13-graphrag/Agent开发与评测闭环指南.md` |
| 团队内网开发 | `20-operation/03-团队内网开发指南.md` |

> 工作区级总技术参考另见根目录 `PROJECT.md`（深入）与 `README.md`（简要总览）。

## AI agent 现状（`campus-wall-ai`，2026-06 基线）

- **架构**：LangGraph **Plan-Execute + 单次条件 replan**（不是纯 ReAct）；Embedding = **bge-m3 / 1024 维**锁定；Chat = 内网 **Qwen3.6-35B**（`.101:8003`）。
- **评测体系**：`evals/`（金标集 intent / post_search / knowledge_qa + `metrics.py` 纯函数 + `run.py` 对 `baseline.json` 比涨跌）。跑法（仓根、能连 Neo4j/.101:8003/本地 7b 的机器）：
  ```bash
  APP_ENV=test python -m evals.run            # 全量，对基线涨跌
  APP_ENV=test python -m evals.run --only post_search
  ```
  > 与 `tests/`（全 mock、秒级、进 pre-push 钩子）不同，`evals/` 跑真实在线服务，**不进 git 钩子，手动跑**。
- **已落地优化**：全局 `AGENT_WALL_CLOCK_BUDGET_SECONDS` 预算 + `over_budget` 节点优雅降级；`match_posts(with_reason=)` 把 reason 下沉到判定后省 LLM 调用；`app/cache.py`（Redis SETEX 精确缓存）；`app/metrics.py`（prometheus-client）+ `GET /metrics` 端点；记忆冲突消解（supersede + event 软过期）；注入防护 + `custom_prompt` 护栏；`/ingest` 入库 PII 脱敏。
- **暂缓**：Reranker / Hybrid Search；**跳过**：检索式记忆。

## 注意事项

- **一切以子模块实际代码/配置为准**：改动前 Read/Grep 核验，端口/库名/命令必须真实可用。
- **绝不硬编码密钥**：所有密码/Key 走环境变量或各仓 `.env`（已 `.gitignore`，工作区硬编码密码已清除并轮换）。
- **改 AI 服务行为**（提示词、检索参数、判定闸）前，先跑 `evals` 确认没把命中率/防幻觉基线改坏。
- **梯子劫持内网**：开发机挂代理/VPN 会劫持后端→内网中间件连接致转发挂起，关梯子或配 LAN bypass / `NO_PROXY`。
- **prod 环境慎连**：切 `APP_ENV=prod` / `SPRING_PROFILES_ACTIVE=prod` 即直连生产中间件，全队共享，操作前确认。
