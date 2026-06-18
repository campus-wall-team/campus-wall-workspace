# campus_wall - 主后端服务

这是校园墙项目的核心业务后端服务。

**技术栈**：Spring Boot 3.4.2 / Java 17 / Spring AI 1.0.8 / MyBatis-Plus 3.5.9（搭配 MySQL 8 + Redis 7 + MinIO + Flyway）。

**核心能力**：

- **社区**：帖子 / 评论 / 点赞收藏 / 搜索，5 类板块（推荐 / 二手 / 兼职 / 推广 / 组队），区域筛选与组队加入退出。
- **AI 学长 Agent**：单一入口 `POST /api/v1/ai-senior/agent`，Planner-Executor 架构 + RelevanceJudge 反幻觉判定 + 双层对话记忆，经 campus-wall-ai（端口 8011，原 GraphRAG 服务已并入）找帖与知识库问答。
- **管理端 RBAC**：独立 `admin_user` 账号体系，角色 superadmin / moderator / viewer，`@RequirePermission` 鉴权 + `@OperationLog` 审计 + 运营看板。
- **排行榜**：热帖榜 / 热搜榜。
- **学生认证**：学生证 OCR + AI 置信度 + 人工复核。

## 快速链接

- [开发文档](./开发文档.md) - 详细开发指南（技术栈、目录结构、接口列表、配置说明）
- [仓库路径](../../campus_wall/)
