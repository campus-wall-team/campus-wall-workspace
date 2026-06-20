# campus-wall-frontend - 多端前端

这是校园墙项目的用户端前端应用，基于 Vue 3 + uni-app 开发，支持 H5 和微信小程序等多端部署。技术栈在 Vue 3 / uni-app / TypeScript / Vite 之外，还引入了 Tailwind CSS（配 weapp-tailwindcss 适配小程序）做原子化样式、`marked` 渲染 AI 回复的 Markdown。

## 功能概览

- **板块化发布**：按板块（二手交易 / 兼职发布 / 推广 / 组队 / 推荐）动态切换字段区与校验，例如二手填价格（可面议）、兼职填薪资 + 信息费、推广上传 Banner 大图。
- **集市与组队**：二手/推广帖支持一键复制卖家联系方式；组队帖支持 join / leave，成员头像叠放展示。
- **AI 学长（单一入口）**：AI 问答统一收口到 `POST /api/v1/ai-senior/agent`，由后端 LangGraph agent（Plan-Execute + 单次条件 replan）自主判断查知识库 / 查帖子并接地合成答案，回复用 Markdown 渲染；另支持 AI 偏好设置（`/api/v1/ai-preference/*`）。另支持对话内联 AI 发帖（在 `pages/ai/chat.vue` 内联出草稿卡片，说一句需求、学长出草稿，确认 / 改稿后发布，走 `aiApi.startDraft` / `resumeDraft` / `cancelDraft` → `/api/v1/ai-senior/posts/draft` | `posts/resume/{id}` | `posts/draft/{id}`）与对话内配图找帖（聊天里 ＋ 上传图片，`aiApi.agent` 的 `images` 参数把图片 object name 传给后端，VLM 看图说话后并入检索匹配）。
- **排行榜**：热帖榜 / 热搜榜（`/api/v1/ranks/*`，支持 day/week/month 与本校/跨校/全省等范围）。
- **发现与社交**：发现页支持「附近大学」区域筛选；私信基于 WebSocket 实时收发；另含搜索、关注、评论、通知、学生认证等。

底部为自定义 5 Tab（圈子 / 发现 / AI / 私信 / 我的）。

## 快速链接

- [开发文档](./开发文档.md) - 详细开发指南
- [仓库路径](../../campus-wall-frontend/)
