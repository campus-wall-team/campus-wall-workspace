# campus-wall-graphrag - AI 知识图谱服务

> ⚠️ 本服务已并入 campus-wall-ai（端口 8011），本目录作为历史/实现参考保留。

这是校园墙项目的 AI 核心引擎，基于 Python FastAPI + Neo4j 构建，实现 GraphRAG（知识图谱检索增强生成）。

除知识问答外，还覆盖：VLM 读图（帖子图片物体识别 / 结构化标注）、帖子知识入库与智能推荐（自然语言诉求 → 意图识别 + 向量匹配 + 匹配理由）、流式问答（SSE）；三套 LLM 角色（chat / embed / vlm）统一**本地优先 + 云端降级**，本地 Ollama 不可用时自动兜底云端。共对外 9 个 HTTP 端点。

## 快速链接

- [开发文档](./开发文档.md) - 详细开发指南
- [仓库路径（已并入 campus-wall-ai）](../../campus-wall-ai/)
