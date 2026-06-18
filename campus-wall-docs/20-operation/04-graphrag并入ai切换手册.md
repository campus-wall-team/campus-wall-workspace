# graphrag 并入 campus-wall-ai —— 部署切换手册（蓝绿 + 回滚）

> 背景：`campus-wall-graphrag` 独立服务已并入 **campus-wall-ai**（端口 8011），代码迁入 `campus-wall-ai/app/graphrag/`。
> 旧 graphrag 容器监听 8001、新 ai 服务监听 8011，二者**共用同一个 Neo4j 与向量索引**（`campus_chunk_vector`/`campus_post_vector`，bge-m3/1024），可并行双跑、无需数据迁移。
> 本手册把消费方从 8001 切到 8011 并下线旧容器。
>
> ⚠️ **核心铁律：先起新 → 再切配置 → 最后停旧。切勿先停旧**，否则 8001 真空会同时打断 Java 问答 / 发帖入图谱 / ETL 灌库 / 监控探活。

## 0. 前置：在 GB10(172.21.160.212) 建部署 .env

```bash
cd campus-wall-ops
cp ai-service/.env.example ai-service/.env
```

填入真实值（关键项）：
- `NEO4J_PASSWORD` = ops `.env` 的同值（真实值见各机 `.env`，勿写入文档/勿提交）——**不一致会连不上**
- `REDIS_URL` 里的密码 = ops `REDIS_PASSWORD`
- `DB_URL` = `mysql+pymysql://<user>:<pass>@localhost:3306/campus_wall?charset=utf8mb4` —— **必须 MySQL，不能用默认 sqlite**，否则草稿/记忆不与 Java 共库
- `JWT_SECRET` = campus_wall 的同值（Base64）
- `CHAT_BASE_URL` = `http://172.21.160.101:8003/v1`（Qwen3.6-35B 新端点）

## 1. 起新（8011），与旧 graphrag(8001) 并行双跑

```bash
cd campus-wall-ops
docker compose up -d --build ai-api ai-memory-worker

# 健康检查（host 网络，本机直查）
curl -s http://localhost:8011/health        # 期望 {"status":"ok","neo4j":true,"redis":true}

# 契约端点自测（结果应与旧 8001 一致）
curl -s -X POST http://localhost:8011/query      -H 'Content-Type: application/json' -d '{"question":"图书馆几点关门？","topK":3}'
curl -s -X POST http://localhost:8011/match-posts -H 'Content-Type: application/json' -d '{"question":"丢了校园卡","topK":3}'
```

## 2. 逐个切消费方到 8011（每切一个验一次）

| 消费方 | 改什么 | 验证 |
|---|---|---|
| Java 后端 | `GRAPHRAG_BASE_URL=http://172.21.160.212:8011`（ops `.env` 与 campus_wall 部署 env），重启 | AI 学长问答 + 发帖入图谱 + 找帖 |
| data-pipeline | `GRAPHRAG_URL=http://172.21.160.212:8011`，跑一次 `--push` | `/index` 灌库成功 |
| Prometheus | compose 已改 target 为 `host.docker.internal:8011`，热加载 | blackbox probe `campus-wall-ai` 为 UP |

```bash
# Prometheus 热加载
docker compose exec prometheus kill -HUP 1   # 或 curl -X POST http://localhost:9090/-/reload
```

## 3. 观察期（建议 ≥1 个发布周期）

- **写只走一端**：`/index`、`/ingest-post`、`DELETE` 只指向 8011，避免新旧对同一 Neo4j 双写。
- 核对 Neo4j 节点计数稳定，无重复 ingest。

## 4. 下线旧 graphrag

```bash
cd campus-wall-ops
# 本仓库 compose 已把 graphrag 块替换为 ai-api/ai-memory-worker；
# 若 GB10 上仍跑着旧 campus-graphrag 容器：
docker stop campus-graphrag && docker rm campus-graphrag
# 若旧 graphrag 是 host 直跑的 systemd（装过 campus-graphrag.service）：
sudo systemctl disable --now campus-graphrag
```

## 5. 回滚（出问题时）

- 消费方默认值改回 `:8001` 并重启；重新起旧 graphrag 容器/进程即可。
- 新旧契约字节级一致、共用同一 Neo4j → **回滚无数据迁移**。
- ⚠️ 无单一开关：回滚要**同时**改回 Java `GRAPHRAG_BASE_URL`、data-pipeline `GRAPHRAG_URL`、Prometheus target 三处，否则半新半旧脑裂。

## 6. 收尾

- GitHub 上 **Archive** `campus-wall-graphrag` 仓库（设为只读）。
- 确认稳定后，可删除 `campus-wall-ops/graphrag-service/` 目录。
