# API 设计规范

本文档规定校园墙项目的 API 接口设计规范。

## 基础规范

### URL 设计

- **基础路径**：所有 API 以 `/api/v1/` 开头
- **资源命名**：使用名词复数，小写，下划线分隔
- **HTTP 方法**：对应 CRUD 操作

```
GET    /api/v1/posts              # 列表查询
GET    /api/v1/posts/{id}         # 详情查询
POST   /api/v1/posts              # 创建
PUT    /api/v1/posts/{id}         # 全量更新
PATCH  /api/v1/posts/{id}         # 部分更新
DELETE /api/v1/posts/{id}         # 删除
```

### HTTP 状态码

| 状态码 | 使用场景 |
|--------|----------|
| 200 | 请求成功 |
| 201 | 创建成功 |
| 204 | 删除成功（无返回体）|
| 400 | 请求参数错误 |
| 401 | 未认证（Token 缺失或无效）|
| 403 | 无权限 |
| 404 | 资源不存在 |
| 409 | 资源冲突 |
| 422 | 业务逻辑校验失败 |
| 429 | 请求过于频繁 |
| 500 | 服务器内部错误 |

## 统一响应格式

### 成功响应

```json
{
    "code": 200,
    "message": "success",
    "data": {
        // 具体数据
    }
}
```

### 列表响应

```json
{
    "code": 200,
    "message": "success",
    "data": {
        "list": [
            { "id": 1, "title": "...", "content": "..." },
            { "id": 2, "title": "...", "content": "..." }
        ],
        "total": 100,
        "page": 1,
        "size": 10
    }
}
```

### 错误响应

```json
{
    "code": 400,
    "message": "参数错误：标题不能为空",
    "data": null
}
```

```json
{
    "code": 401,
    "message": "登录已过期，请重新登录",
    "data": null
}
```

## 分页规范

### 请求参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | int | 否 | 1 | 页码，从 1 开始 |
| size | int | 否 | 10 | 每页条数，最大 50 |

### 请求示例

```
GET /api/v1/posts?page=1&size=20
```

### 响应格式

```json
{
    "code": 200,
    "message": "success",
    "data": {
        "list": [...],
        "total": 256,
        "page": 1,
        "size": 20,
        "pages": 13,
        "hasNext": true,
        "hasPrevious": false
    }
}
```

## 认证规范

### Token 传递

所有需要认证的接口在请求头中携带 JWT Token：

```
Authorization: Bearer <token>
```

### 登录响应

```json
{
    "code": 200,
    "message": "success",
    "data": {
        "token": "eyJhbGciOiJIUzI1NiIs...",
        "expiresIn": 7200,
        "user": {
            "id": 1,
            "nickname": "用户昵称",
            "avatar": "https://..."
        }
    }
}
```

## 接口分类示例

### 帖子相关 (/api/v1/posts)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/list` | 帖子列表 | 可选 |
| GET | `/hot` | 热帖列表 | 可选 |
| GET | `/detail/{id}` | 帖子详情 | 可选 |
| POST | `/publish` | 发布帖子 | 是 |
| POST | `/like/{id}` | 点赞/取消点赞 | 是 |
| POST | `/collect/{id}` | 收藏/取消收藏 | 是 |
| DELETE | `/delete/{id}` | 删除帖子 | 是 |

### 评论相关 (/api/v1/comments)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/list` | 评论列表 | 可选 |
| POST | `/add` | 发表评论 | 是 |
| DELETE | `/delete/{id}` | 删除评论 | 是 |

### 用户相关 (/api/v1/users)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/login` | 微信登录 | 否 |
| GET | `/info` | 用户信息 | 是 |
| PUT | `/update` | 更新信息 | 是 |
| GET | `/follows` | 关注列表 | 是 |
| POST | `/follow/{id}` | 关注/取消关注 | 是 |

### AI 相关 (/api/v1/ai)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/chat` | AI 对话 | 是 |
| GET | `/history` | 对话历史 | 是 |
| GET | `/preference` | AI 偏好设置 | 是 |
| PUT | `/preference` | 更新偏好 | 是 |

### 管理后台 (/api/v1/admin)

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/moderation/pending` | 待审核列表 | 是(管理员) |
| POST | `/moderation/{id}/approve` | 审核通过 | 是(管理员) |
| POST | `/moderation/{id}/reject` | 审核拒绝 | 是(管理员) |
| GET | `/stats/overview` | 数据概览 | 是(管理员) |

## 错误码规范

### 系统级错误码

| 错误码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未登录或 Token 过期 |
| 403 | 无权限访问 |
| 404 | 资源不存在 |
| 500 | 系统内部错误 |
| 503 | 服务暂不可用 |

### 业务级错误码（4xx 范围）

| 错误码 | 说明 |
|--------|------|
| 4001 | 参数校验失败 |
| 4002 | 资源不存在 |
| 4003 | 资源已存在 |
| 4004 | 操作不允许（如删除他人帖子）|
| 4005 | 内容包含敏感词 |
| 4006 | 上传文件过大 |
| 4007 | 上传文件格式不支持 |
| 4008 | 操作过于频繁 |
| 4009 | AI 服务调用失败 |

## WebSocket 规范

### 连接

```
ws://host/ws/chat
Headers: Authorization: Bearer <token>
```

### 消息格式

```json
{
    "type": "TEXT",
    "toUserId": 123,
    "content": "消息内容",
    "timestamp": 1704067200000
}
```

### 消息类型

| 类型 | 说明 |
|------|------|
| TEXT | 文本消息 |
| IMAGE | 图片消息 |
| SYSTEM | 系统通知 |
| READ_RECEIPT | 已读回执 |

## 版本控制

API 版本通过 URL 路径控制：

```
/api/v1/...     # 当前版本
/api/v2/...     # 未来新版本（不破坏 v1）
```

版本升级原则：
- 新增字段：兼容升级，不需要改版本号
- 删除字段 / 修改字段类型：需要升级版本号
- 删除接口：保留旧版本至少 3 个月
