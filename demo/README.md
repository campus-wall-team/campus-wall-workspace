# Campus Wall — 「AI 学长」本地 Demo

> 注：原独立服务 campus-wall-graphrag 已并入 **campus-wall-ai**（端口 8011），本 demo 现基于 campus-wall-ai 运行；GraphRAG 问答链路与端点不变。

这是 Campus Wall 校园墙项目的**最小可跑通 demo**：一套**离线、零成本**的 GraphRAG 知识问答链路，作为后续扩展其它模块的核心地基。

它把 16 篇校园知识（选课、宿舍、图书馆、食堂、奖学金、四六级……）灌入 Neo4j 知识图谱，再用本机 Ollama 大模型做向量检索 + 答案生成，**不依赖任何云端 API key**。

整条链路在小程序里的入口是「AI 学长」：

```
小程序 → 后端 POST /api/v1/ai-senior/chat → campus-wall-ai :8011 /query
       → bge-m3 向量化问题 → Neo4j 向量检索 Top-K → 图遍历补充事实
       → qwen2.5 生成答案 → 回传（带来源引用）
```

---

## 1. 依赖

| 依赖 | 说明 | 启动方式 |
|------|------|----------|
| **Neo4j 5**（`campus-neo4j` 容器） | 知识图谱 + 向量索引，Bolt 对外 `:7688` | `cd campus-wall-ops && docker compose up -d neo4j` |
| **Ollama**（本机 `:11434`） | 本地 LLM `qwen2.5:7b` + 嵌入 `bge-m3` | `ollama pull qwen2.5:7b && ollama pull bge-m3` |
| **Python venv** | campus-wall-ai 服务依赖 | `campus-wall-ai/.venv`（见该项目 README） |

---

## 2. 文件说明

| 文件 | 作用 |
|------|------|
| `run-graphrag.sh` | 启动脚本：加载 `demo/.env` → 清理 socks 代理 → 设 Neo4j / Chat / Embed 环境变量 → `uvicorn app.main:app --port 8011`（跑 campus-wall-ai） |
| `seed-knowledge.json` | 16 篇校园知识种子（`{documents:[{title, source, content}]}`，`source` 形如 `seed:course` 用作幂等 doc id） |
| `seed.py` | 逐篇灌库脚本，每篇 `id=source` 幂等可重跑，跳过已完成项 |
| `.env.example` | 配置模板（**复制为 `.env` 后填真实密码**） |
| `.env` | 本地真实密钥，**已被 `.gitignore` 忽略，不入库** |
| `logs/` | `graphrag.log`（服务日志）、`seed.log`（灌库进度），`*.log` 已被忽略 |

---

## 3. 一步步跑通

```bash
cd /home/nvidia/Desktop/campus-wall

# 0) 首次：准备本地密钥（demo/.env 不会被提交）
cp demo/.env.example demo/.env
#   编辑 demo/.env，把 NEO4J_PASSWORD 改成真实密码

# 1) 启动 GraphRAG 服务（后台，日志进 demo/logs/graphrag.log）
nohup bash demo/run-graphrag.sh >> demo/logs/graphrag.log 2>&1 & disown

# 2) 健康检查（本机有 socks 代理，curl 加 --noproxy '*'）
curl --noproxy '*' http://localhost:8011/health
#    预期：{"status":"ok","neo4j":true}

# 3) 灌入知识库（幂等，可重跑）
python3 demo/seed.py

# 4) 端到端问答测试
curl --noproxy '*' -X POST http://localhost:8011/query \
  -H 'Content-Type: application/json' \
  -d '{"question":"四级多少分才能报六级？","topK":4}'
#    预期：返回 answer + sources（带来源引用）
```

> 注：本机设了全局 socks 代理（`ALL_PROXY`），httpx 不支持会崩溃。`run-graphrag.sh` 已统一清理代理变量；用 `curl` 测试时加 `--noproxy '*'`。

---

## 4. 如何扩展这个 demo

- **加知识**：往 `seed-knowledge.json` 的 `documents` 里追加 `{title, source, content}`（`source` 用新的 `seed:xxx`），再跑 `python3 demo/seed.py`。同 `source` 会幂等覆盖。
- **换模型**：在 `demo/.env` 里覆盖 `CHAT_MODEL` / `EMBED_MODEL`（或指向云端 DashScope 的 `CHAT_BASE_URL` / `CHAT_API_KEY`）。
- **接全栈**：后端 `application-dev.yaml` 的 `GRAPHRAG_BASE_URL` 默认指向 `http://localhost:8011`，启动 Spring Boot 后即可通过 `/api/v1/ai-senior/chat` 走完整链路。

更完整的架构、端口、部署说明见根目录 [`PROJECT.md`](../PROJECT.md)；模块完成度与路线图见 [`campus-wall-docs/00-project-overview/05-项目进度.md`](../campus-wall-docs/00-project-overview/05-项目进度.md)。
