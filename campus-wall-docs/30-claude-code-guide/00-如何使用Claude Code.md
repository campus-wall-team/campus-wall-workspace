# 如何使用 Claude Code

Claude Code 是 Anthropic 推出的 AI 编程助手 CLI 工具，可以帮助你更高效地开发校园墙项目。

## 安装与配置

### 1. 安装 Claude Code

```bash
# macOS / Linux
npm install -g @anthropic-ai/claude-code

# Windows (使用 PowerShell)
npm install -g @anthropic-ai/claude-code
```

### 2. 登录

```bash
claude
```

首次运行会提示登录，按提示在浏览器中完成授权。

### 3. 进入项目

```bash
cd ~/workspace/campus-wall-workspace/campus_wall
claude
```

Claude Code 会自动读取 `.claude/CLAUDE.md` 文件了解项目上下文。

## 常用命令

### 基础命令

| 命令 | 说明 |
|------|------|
| `/help` | 显示帮助信息 |
| `/clear` | 清空当前对话 |
| `/config` | 查看和修改配置 |
| `/cost` | 查看本次会话的费用 |
| `/exit` | 退出 Claude Code |

### 文件操作

```bash
# 查看文件
claude: read src/main/java/com/jyu/campus/community/PostController.java

# 编辑文件
claude: edit PostController.java 将列表查询的默认分页大小改为 20

# 搜索代码
claude: grep "@RestController" 查找所有控制器

# 运行命令
claude: run mvn test
```

### 使用技能 (Skills)

Claude Code 支持预定义的技能，校园墙项目配置了以下常用技能：

```bash
# 代码审查
claude: /code-review

# 验证修改
claude: /verify

# 运行项目
claude: /run
```

## 高效使用技巧

### 1. 提供充足上下文

**不好**：
```
帮我修复一个 bug
```

**好**：
```
在 PostService.java 的 getPostById 方法中，当帖子不存在时返回了 null，导致前端出现空指针异常。请修改为抛出 NotFoundException。
```

### 2. 使用具体文件路径

```
请查看 src/main/java/com/jyu/campus/common/util/JwtUtil.java 中的 generateToken 方法，我怀疑 token 过期时间计算有问题。
```

### 3. 逐步迭代

```
# 第一步：理解代码
请解释 PostController 中的 publish 方法的逻辑

# 第二步：提出修改
我想在这个方法中添加图片数量限制，最多 9 张

# 第三步：实施修改
请帮我实现这个限制，并在超出时返回 400 错误

# 第四步：验证
请写一个简单的测试验证这个限制
```

### 4. 利用 AI 文档

每个仓库的 `.claude/CLAUDE.md` 已配置项目上下文。你可以：

```
根据项目的架构模式，帮我创建一个新的模块 "activity"，包含帖子活动相关的增删改查接口。
```

Claude Code 会自动读取 `.claude/CLAUDE.md` 了解：
- 项目的目录结构规范
- 编码约定（Controller-Service-Mapper）
- 命名规范
- 常见开发任务模式

### 5. 代码审查

```
请审查我最近修改的代码，关注：
1. 是否有潜在的 NPE
2. 是否有 SQL 注入风险
3. 是否有性能问题
4. 是否符合项目的编码规范
```

### 6. 生成文档

```
请为 PostService 类中的所有 public 方法生成 Javadoc 注释
```

### 7. 重构建议

```
我觉得 CommentService 中的这个方法太长了，请帮我重构，提取一些私有方法
```

## 最佳实践

### Do's

- **明确需求**：描述清楚你想要什么
- **提供上下文**：提及相关文件和代码位置
- **逐步迭代**：复杂任务分步骤完成
- **验证结果**：让 Claude 运行测试或检查代码
- **保存配置**：常用配置写入 `.claude/CLAUDE.md`

### Don'ts

- **不要提供密钥**：不要在对话中粘贴 API Key、密码等
- **不要盲目接受**：AI 生成的代码需要人工审查
- **不要期望完美**：AI 可能犯错，重要逻辑需人工确认
- **不要一次性问太多**：复杂任务拆分为多个小问题

## 费用控制

Claude Code 按 token 使用量计费：

| 操作 | 大致费用 |
|------|----------|
| 简单问答 | $0.01 - $0.05 |
| 代码生成 | $0.05 - $0.20 |
| 大型重构 | $0.20 - $1.00 |

**节省费用技巧**：
1. 使用 `/clear` 清理不相关的对话历史
2. 避免上传大文件
3. 使用 `/cost` 关注费用
4. 设置预算提醒

## 常见问题

### Q: Claude Code 和 ChatGPT 有什么区别？

Claude Code 是专为编程设计的 CLI 工具，可以：
- 直接读取和编辑本地文件
- 运行本地命令
- 理解项目上下文（通过 CLAUDE.md）
- 集成到开发工作流中

### Q: 我的代码会被发送到云端吗？

是的，Claude Code 需要将代码发送到 Anthropic 的服务器进行处理。请勿上传包含敏感信息的代码。

### Q: 可以离线使用吗？

不可以，Claude Code 需要联网才能工作。

### Q: 如何更新 Claude Code？

```bash
npm update -g @anthropic-ai/claude-code
```

## 相关资源

- [Claude Code 官方文档](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [项目 AI 辅助开发策略](./01-各仓库AI辅助开发策略.md)
