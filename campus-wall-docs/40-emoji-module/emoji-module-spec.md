# Emoji 表情模块开发文档

## 文档定位

本文档是 **Emoji 表情模块** 的跨前后端功能规格说明书，供后端和前端开发人员同时参考使用。

> 涉及仓库：`campus_wall`（后端）、`campus-wall-frontend`（前端）

---

## 目录

- [一、功能概述](#一功能概述)
- [二、技术方案](#二技术方案)
  - [2.1 核心原理：占位符编码 + 统一渲染](#21-核心原理占位符编码--统一渲染)
  - [2.2 业界参考](#22-业界参考)
  - [2.3 占位符规范](#23-占位符规范)
- [三、数据库设计](#三数据库设计)
- [四、后端开发指南](#四后端开发指南)
  - [4.1 新增文件](#41-新增文件)
  - [4.2 修改文件](#42-修改文件)
  - [4.3 EmojiUtil 工具类](#43-emojiutil-工具类)
  - [4.4 API 接口](#44-api-接口)
- [五、前端开发指南](#五前端开发指南)
  - [5.1 新增文件](#51-新增文件)
  - [5.2 修改文件](#52-修改文件)
  - [5.3 Emoji 工具函数](#53-emoji-工具函数)
  - [5.4 EmojiPicker 组件](#54-emojipicker-组件)
  - [5.5 EmojiText 渲染组件](#55-emojitext-渲染组件)
- [六、数据流](#六数据流)
- [七、边界情况处理](#七边界情况处理)
- [八、测试验证](#八测试验证)
- [九、文件清单](#九文件清单)
- [十、后续扩展](#十后续扩展)

---

## 一、功能概述

在校园墙项目中，为以下三个核心场景添加 Emoji 表情支持：

| 场景 | 页面/组件 | 当前状态 |
|------|-----------|----------|
| 私信聊天 | `chat-detail.vue` + `chat-input-bar.vue` | 有 emoji 按钮占位，无面板实现 |
| 发布帖子 | `publish.vue` | 纯文本输入，无 emoji |
| 发表评论 | `useComments.js` + 评论弹窗 | 纯文本输入，无 emoji |

用户可以通过点击输入框旁的 emoji 按钮，弹出表情选择面板，选择表情后插入到输入内容中。表情在聊天消息、帖子正文、评论内容中均可正常显示。

---

## 二、技术方案

### 2.1 核心原理：占位符编码 + 统一渲染

采用三层分离架构：

```
用户输入层          存储/传输层            展示层
┌─────────┐        ┌─────────────┐       ┌─────────┐
│ 你好😊  │  encode │ 你好[smile] │ decode│ 你好😊  │
└─────────┘ ──────→ └─────────────┘ ────→ └─────────┘
```

1. **存储层**：所有含 emoji 的文本在入库前将 Unicode emoji 转义为占位符（如 `你好😊` → `你好[smile]`）。自定义 emoji 直接以占位符形式存在。
2. **传输层**：API 请求/响应中的 `content` 字段统一使用占位符格式。前后端通过占位符进行数据交换，与渲染细节解耦。
3. **展示层**：前端在渲染文本时，将占位符解析回对应的 Unicode emoji 字符或自定义图片进行显示。

**为什么不用 Unicode 直接存储？**
- Unicode emoji 是多字节字符，在某些数据库排序、索引、搜索场景中可能产生意外行为
- 占位符方案便于后期扩展自定义图片表情，前后端映射关系清晰
- 敏感词过滤可以在编码前执行，避免 emoji 干扰检测逻辑
- 占位符可读性高，便于日志排查和数据审计

### 2.2 业界参考

| 产品 | 方案 | 本模块借鉴点 |
|------|------|-------------|
| **微信** | Unicode + 自定义图片表情，使用 `[微笑]` 类占位符 | 占位符编码方案的行业标杆 |
| **QQ** | Unicode + QQ 专属 gif 表情 | 专属表情走独立通道的设计思想 |
| **Discord/Slack** | `:emoji_name:` 语法 + Unicode 原生共存 | 统一渲染组件、服务端动态获取 emoji 列表 |
| **微博/小红书** | Unicode 直接存储 + 系统字体渲染 | 简单直接但平台显示不一致，本模块不采用 |

本方案取各家之长：存储方式参考微信（占位符编码），渲染方式参考 Discord（统一渲染组件），技术栈利用 uni-app 跨平台能力确保 H5 和微信小程序 emoji 显示一致。

### 2.3 占位符规范

#### 格式定义

```
[emoji_name]
```

- 必须以 `[` 开头，`]` 结尾
- `emoji_name` 使用**小写英文字母 + 下划线**，如 `smile`、`doge`、`jxu_coffee`
- Unicode emoji 的占位符名称参照微信/通用命名
- 自定义校园墙特色 emoji 以 `jxu_` 为前缀

#### 映射表（前后端必须保持一致）

| 占位符 | Unicode 字符 | 显示名称 | 类型 |
|--------|-------------|---------|------|
| `[smile]` | `😊` | 微笑 | Unicode |
| `[laugh]` | `😂` | 笑哭 | Unicode |
| `[cry]` | `😭` | 大哭 | Unicode |
| `[heart]` | `❤️` | 红心 | Unicode |
| `[broken_heart]` | `💔` | 心碎 | Unicode |
| `[doge]` | `🐶` | 狗头 | Unicode |
| `[cat]` | `🐱` | 猫咪 | Unicode |
| `[fire]` | `🔥` | 火 | Unicode |
| `[thumbs_up]` | `👍` | 赞 | Unicode |
| `[ok]` | `👌` | OK | Unicode |
| `[wave]` | `👋` | 挥手 | Unicode |
| `[clap]` | `👏` | 鼓掌 | Unicode |
| `[rose]` | `🌹` | 玫瑰 | Unicode |
| `[coffee]` | `☕` | 咖啡 | Unicode |
| `[cake]` | `🎂` | 蛋糕 | Unicode |
| `[gift]` | `🎁` | 礼物 | Unicode |
| `[party]` | `🎉` | 庆祝 | Unicode |
| `[muscle]` | `💪` | 加油 | Unicode |
| `[thinking]` | `🤔` | 思考 | Unicode |
| `[sleep]` | `😴` | 睡觉 | Unicode |
| `[angry]` | `😡` | 生气 | Unicode |
| `[cool]` | `😎` | 酷 | Unicode |
| `[shy]` | `😳` | 害羞 | Unicode |
| `[sweat]` | `😓` | 流汗 | Unicode |
| `[kiss]` | `😘` | 飞吻 | Unicode |
| `[dizzy]` | `😵` | 晕 | Unicode |
| `[wink]` | `😉` | 眨眼 | Unicode |
| `[sad]` | `😞` | 难过 | Unicode |
| `[hug]` | `🤗` | 拥抱 | Unicode |
| `[sun]` | `☀️` | 太阳 | Unicode |
| `[moon]` | `🌙` | 月亮 | Unicode |
| `[star]` | `⭐` | 星星 | Unicode |
| `[rainbow]` | `🌈` | 彩虹 | Unicode |
| `[book]` | `📚` | 书本 | Unicode |
| `[graduation]` | `🎓` | 毕业 | Unicode |
| `[basketball]` | `🏀` | 篮球 | Unicode |
| `[soccer]` | `⚽` | 足球 | Unicode |
| `[music]` | `🎵` | 音乐 | Unicode |
| `[phone]` | `📱` | 手机 | Unicode |
| `[computer]` | `💻` | 电脑 | Unicode |
| `[money]` | `💰` | 钱 | Unicode |
| `[clock]` | `⏰` | 闹钟 | Unicode |
| `[location]` | `📍` | 定位 | Unicode |
| `[100]` | `💯` | 满分 | Unicode |
| `[jxu_doge]` | 图片资源 | 嘉大狗头 | 自定义 |
| `[jxu_coffee]` | 图片资源 | 嘉大咖啡 | 自定义 |
| `[jxu_library]` | 图片资源 | 图书馆 | 自定义 |

> **约定**：上表中的 Unicode emoji 映射关系维护在前后端常量文件中（`EmojiConstants.java` / `EMOJI_MAP`）。自定义 emoji 资源由后端 API 动态返回，前端无需硬编码。

#### 编码规则

| 场景 | 处理方式 |
|------|---------|
| 用户从面板选择 emoji | 直接插入占位符文本，如 `[smile]` |
| 用户直接输入 Unicode emoji（手机键盘） | 前端发送前调用 `encodeEmoji()` 转换为占位符 |
| 后端接收到的 content 含 Unicode | 后端 `EmojiUtil.encode()` 二次保障转换（幂等） |
| 后端返回给前端的 content | 统一为占位符格式，前端 `decodeEmoji()` 渲染 |
| 用户输入 `[xxx]` 但不是有效 emoji | 保留原样，不转换 |

---

## 三、数据库设计

### 新增表：custom_emoji

用于管理自定义校园墙特色 emoji。Unicode emoji 的映射关系通过前后端常量维护，不需要数据库表。

```sql
-- ============================================
-- Emoji 模块：自定义 emoji 配置表
-- Flyway 迁移版本：V2.1__add_custom_emoji_table.sql
-- ============================================

CREATE TABLE IF NOT EXISTS custom_emoji
(
    id          bigint auto_increment primary key comment '主键ID',
    code        varchar(50)  not null comment '占位符编码，如 jxu_doge（不含[]）',
    name        varchar(50)  not null comment '显示名称，如"嘉大狗头"',
    description varchar(255) default '' comment '描述说明',
    object_name varchar(500) not null comment 'MinIO 对象存储名称',
    sort_order  int          default 0 comment '排序权重，越大越靠前',
    is_enabled  tinyint(1)   default 1 comment '是否启用: 0-禁用 1-启用',
    create_time datetime     default CURRENT_TIMESTAMP comment '创建时间',
    update_time datetime     default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP comment '更新时间',
    constraint uk_code unique (code) comment '占位符编码唯一'
) charset = utf8mb4 comment '自定义 emoji 配置表';

CREATE INDEX idx_enabled_sort ON custom_emoji (is_enabled, sort_order);
```

### 现有表是否需要修改？

**不需要修改现有表结构**。

帖子（`post.content`）、评论（`comment.content`）、聊天消息（`chat_message.content`）的 `content` 字段均为 `text` 类型，足以存储占位符文本。

`chat_message.message_type` 字段已预留 `3-表情`：当消息**仅包含单个占位符且无其他文本**时，标记为 `messageType = 3`；否则标记为 `messageType = 1`（文本）。此逻辑供前端做大表情展示时参考，非强制要求。

---

## 四、后端开发指南

### 4.1 新增文件

| 序号 | 文件路径 | 说明 |
|------|----------|------|
| 1 | `common/constant/EmojiConstants.java` | Unicode emoji 映射常量（占位符 → Unicode 字符） |
| 2 | `common/util/EmojiUtil.java` | emoji 编码/解码工具类 |
| 3 | `social/entity/CustomEmoji.java` | 自定义 emoji 实体类 |
| 4 | `social/mapper/CustomEmojiMapper.java` | MyBatis-Plus Mapper |
| 5 | `social/service/ICustomEmojiService.java` | Service 接口 |
| 6 | `social/service/impl/CustomEmojiServiceImpl.java` | Service 实现 |
| 7 | `social/controller/EmojiController.java` | 获取 emoji 列表 API |
| 8 | `db/migration/V2.1__add_custom_emoji_table.sql` | Flyway 迁移脚本 |

### 4.2 修改文件

| 序号 | 文件路径 | 修改内容 |
|------|----------|----------|
| 1 | `social/service/impl/ChatServiceImpl.java` | 发送消息前调用 `EmojiUtil.encode()` |
| 2 | `social/service/impl/MessageServiceImpl.java` | 返回消息前调用 `EmojiUtil.decode()`（如需） |
| 3 | `community/service/impl/PostPublishService.java` | 发布帖子前调用 `EmojiUtil.encode()` |
| 4 | `community/service/impl/CommentServiceImpl.java` | 发表评论前调用 `EmojiUtil.encode()` |

### 4.3 EmojiUtil 工具类

```java
package com.jyu.campus.common.util;

import com.jyu.campus.common.constant.EmojiConstants;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Emoji 工具类
 * 提供 Unicode emoji 与占位符之间的编码/解码功能
 */
public class EmojiUtil {

    /**
     * 匹配占位符的正则：如 [smile]、[jxu_doge]
     */
    private static final Pattern PLACEHOLDER_PATTERN = Pattern.compile("\\[([a-zA-Z0-9_]+)]");

    /**
     * Unicode emoji → 占位符编码
     * 将文本中的 Unicode emoji 字符替换为对应的占位符
     * 已经是占位符的内容不会被二次转换（幂等）
     *
     * @param text 原始文本
     * @return 编码后的文本
     */
    public static String encode(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < text.length(); ) {
            int codePoint = text.codePointAt(i);
            String unicodeChar = new String(Character.toChars(codePoint));
            String placeholder = EmojiConstants.UNICODE_TO_PLACEHOLDER.get(unicodeChar);
            if (placeholder != null) {
                result.append("[").append(placeholder).append("]");
            } else {
                result.append(unicodeChar);
            }
            i += Character.charCount(codePoint);
        }
        return result.toString();
    }

    /**
     * 占位符 → Unicode emoji 解码
     * 将文本中的占位符替换为对应的 Unicode emoji 字符
     *
     * @param text 含占位符的文本
     * @return 解码后的文本
     */
    public static String decode(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        Matcher matcher = PLACEHOLDER_PATTERN.matcher(text);
        StringBuffer sb = new StringBuffer();
        while (matcher.find()) {
            String placeholder = matcher.group(1).toLowerCase();
            String unicode = EmojiConstants.PLACEHOLDER_TO_UNICODE.get(placeholder);
            if (unicode != null) {
                matcher.appendReplacement(sb, unicode);
            }
            // 如果找不到映射（可能是自定义 emoji），保留原占位符
        }
        matcher.appendTail(sb);
        return sb.toString();
    }

    /**
     * 判断文本是否仅包含 emoji（用于确定 messageType）
     * 当文本trim后只剩一个占位符时返回 true
     *
     * @param text 文本
     * @return 是否纯 emoji
     */
    public static boolean isPureEmoji(String text) {
        if (text == null || text.isEmpty()) {
            return false;
        }
        String trimmed = text.trim();
        Matcher matcher = PLACEHOLDER_PATTERN.matcher(trimmed);
        return matcher.matches();
    }

    /**
     * 提取文本中的所有 emoji 占位符编码
     *
     * @param text 文本
     * @return 占位符编码列表（不含[]）
     */
    public static List<String> extractEmojis(String text) {
        List<String> emojis = new ArrayList<>();
        if (text == null || text.isEmpty()) {
            return emojis;
        }
        Matcher matcher = PLACEHOLDER_PATTERN.matcher(text);
        while (matcher.find()) {
            emojis.add(matcher.group(1).toLowerCase());
        }
        return emojis;
    }
}
```

### 4.4 API 接口

#### GET /api/v1/emojis/list

获取 emoji 列表，返回 Unicode emoji 映射和自定义 emoji 配置。

**请求参数**：无

**响应示例**：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "unicode": [
      { "code": "smile", "char": "😊", "name": "微笑" },
      { "code": "laugh", "char": "😂", "name": "笑哭" },
      { "code": "cry", "char": "😭", "name": "大哭" },
      { "code": "heart", "char": "❤️", "name": "红心" },
      { "code": "doge", "char": "🐶", "name": "狗头" },
      ...
    ],
    "custom": [
      {
        "code": "jxu_doge",
        "url": "https://minio.example.com/campus-wall/emoji/jxu_doge.png",
        "name": "嘉大狗头"
      },
      {
        "code": "jxu_coffee",
        "url": "https://minio.example.com/campus-wall/emoji/jxu_coffee.png",
        "name": "嘉大咖啡"
      }
    ]
  }
}
```

**字段说明**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `unicode` | Array | Unicode emoji 列表，code 与前端 `EMOJI_MAP` 保持一致 |
| `unicode[].code` | String | 占位符编码，如 `smile` |
| `unicode[].char` | String | Unicode 字符，如 `😊` |
| `unicode[].name` | String | 显示名称，如 `微笑` |
| `custom` | Array | 自定义 emoji 列表，从数据库 `custom_emoji` 表查询 |
| `custom[].code` | String | 占位符编码，如 `jxu_doge` |
| `custom[].url` | String | 图片 URL，通过 MinIO 获取完整访问地址 |
| `custom[].name` | String | 显示名称，如 `嘉大狗头` |

---

## 五、前端开发指南

### 5.1 新增文件

| 序号 | 文件路径 | 说明 |
|------|----------|------|
| 1 | `src/utils/emoji.js` | emoji 编码/解码/渲染工具函数 |
| 2 | `src/components/emoji-picker/index.vue` | emoji 选择面板组件 |
| 3 | `src/components/emoji-text/index.vue` | emoji 文本渲染组件 |

### 5.2 修改文件

| 序号 | 文件路径 | 修改内容 |
|------|----------|----------|
| 1 | `src/components/chat-input-bar/chat-input-bar.vue` | 接入 `emoji-picker`，点击 emoji 图标弹出面板 |
| 2 | `src/pages/message/chat-detail.vue` | 消息内容使用 `emoji-text` 组件渲染 |
| 3 | `src/pages/publish/publish.vue` | 输入框旁添加 emoji 按钮，接入 `emoji-picker` |
| 4 | `src/composables/useComments.js` | 评论输入支持 emoji，提交前调用 `encodeEmoji()` |
| 5 | `src/components/post-card/index.vue` | 帖子正文使用 `emoji-text` 组件渲染 |
| 6 | `src/api/social.js`（或 `src/api/index.js`） | 添加 `emojiApi.getEmojiList()` |

### 5.3 Emoji 工具函数

```javascript
// src/utils/emoji.js

/**
 * Unicode emoji → 占位符编码
 * 将用户输入的 Unicode emoji 转换为占位符格式
 * @param {string} text - 原始文本
 * @returns {string} 编码后的文本
 */
export function encodeEmoji(text) {
  if (!text) return text
  let result = text
  // 遍历映射表，将 Unicode 字符替换为占位符
  for (const [code, char] of Object.entries(EMOJI_MAP)) {
    // 使用全局替换
    result = result.split(char).join(`[${code}]`)
  }
  return result
}

/**
 * 解析含占位符的文本，返回可渲染的片段数组
 * @param {string} text - 含占位符的文本
 * @returns {Array} 渲染片段数组
 */
export function parseEmojiText(text) {
  if (!text) return [{ type: 'text', content: '' }]

  const parts = []
  const regex = /\[([a-zA-Z0-9_]+)]/g
  let lastIndex = 0
  let match

  while ((match = regex.exec(text)) !== null) {
    // 匹配位置前的普通文本
    if (match.index > lastIndex) {
      parts.push({
        type: 'text',
        content: text.slice(lastIndex, match.index)
      })
    }

    const code = match[1].toLowerCase()
    const unicode = EMOJI_MAP[code]

    if (unicode) {
      // Unicode emoji
      parts.push({
        type: 'unicode',
        code,
        char: unicode
      })
    } else if (CUSTOM_EMOJI_MAP[code]) {
      // 自定义 emoji 图片
      parts.push({
        type: 'custom',
        code,
        url: CUSTOM_EMOJI_MAP[code]
      })
    } else {
      // 未知占位符，保留原样
      parts.push({
        type: 'text',
        content: match[0]
      })
    }

    lastIndex = regex.lastIndex
  }

  // 剩余普通文本
  if (lastIndex < text.length) {
    parts.push({
      type: 'text',
      content: text.slice(lastIndex)
    })
  }

  return parts
}

/**
 * 判断文本是否仅包含单个 emoji 占位符
 * @param {string} text
 * @returns {boolean}
 */
export function isPureEmoji(text) {
  if (!text) return false
  const trimmed = text.trim()
  return /^\[[a-zA-Z0-9_]+\]$/.test(trimmed)
}

/**
 * 判断文本是否包含 emoji 占位符
 * @param {string} text
 * @returns {boolean}
 */
export function hasEmoji(text) {
  if (!text) return false
  return /\[[a-zA-Z0-9_]+\]/.test(text)
}

/**
 * Unicode emoji 映射表（与后端 EmojiConstants 保持一致）
 */
export const EMOJI_MAP = {
  'smile': '😊',
  'laugh': '😂',
  'cry': '😭',
  'heart': '❤️',
  'broken_heart': '💔',
  'doge': '🐶',
  'cat': '🐱',
  'fire': '🔥',
  'thumbs_up': '👍',
  'ok': '👌',
  'wave': '👋',
  'clap': '👏',
  'rose': '🌹',
  'coffee': '☕',
  'cake': '🎂',
  'gift': '🎁',
  'party': '🎉',
  'muscle': '💪',
  'thinking': '🤔',
  'sleep': '😴',
  'angry': '😡',
  'cool': '😎',
  'shy': '😳',
  'sweat': '😓',
  'kiss': '😘',
  'dizzy': '😵',
  'wink': '😉',
  'sad': '😞',
  'hug': '🤗',
  'sun': '☀️',
  'moon': '🌙',
  'star': '⭐',
  'rainbow': '🌈',
  'book': '📚',
  'graduation': '🎓',
  'basketball': '🏀',
  'soccer': '⚽',
  'music': '🎵',
  'phone': '📱',
  'computer': '💻',
  'money': '💰',
  'clock': '⏰',
  'location': '📍',
  '100': '💯',
}

/**
 * 自定义 emoji 映射表（从后端 API 动态获取后更新）
 */
export const CUSTOM_EMOJI_MAP = {}

/**
 * 从后端加载自定义 emoji 列表
 * @param {Array} customEmojis - 后端返回的自定义 emoji 数组
 */
export function loadCustomEmojis(customEmojis) {
  CUSTOM_EMOJI_MAP = {}
  for (const emoji of customEmojis) {
    CUSTOM_EMOJI_MAP[emoji.code] = emoji.url
  }
}
```

### 5.4 EmojiPicker 组件

```vue
<!-- src/components/emoji-picker/index.vue -->
<template>
  <view class="emoji-picker" v-show="visible">
    <!-- 分类 Tab -->
    <view class="emoji-tabs">
      <view
        v-for="tab in tabs"
        :key="tab.key"
        class="tab-item"
        :class="{ active: activeTab === tab.key }"
        @click="activeTab = tab.key"
      >
        <text>{{ tab.name }}</text>
      </view>
    </view>

    <!-- Emoji 网格 -->
    <scroll-view scroll-y class="emoji-grid">
      <view class="emoji-grid-inner">
        <view
          v-for="emoji in currentEmojis"
          :key="emoji.code"
          class="emoji-item"
          @click="selectEmoji(emoji)"
        >
          <text v-if="emoji.type === 'unicode'" class="unicode-emoji">{{ emoji.char }}</text>
          <image
            v-else
            :src="emoji.url"
            class="custom-emoji"
            mode="aspectFit"
          />
        </view>
      </view>
    </scroll-view>

    <!-- 底部指示器 -->
    <view class="emoji-footer">
      <text class="footer-text">校园墙 Emoji</text>
    </view>
  </view>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { EMOJI_MAP } from '@/utils/emoji.js'
import { get } from '@/utils/request.js'
import { emojiApi } from '@/api/index.js'

const props = defineProps({
  visible: { type: Boolean, default: false }
})

const emit = defineEmits(['select'])

const activeTab = ref('recent')
const recentEmojis = ref([])
const customEmojis = ref([])

const tabs = [
  { key: 'recent', name: '最近' },
  { key: 'unicode', name: '表情' },
  { key: 'custom', name: '校园' },
]

// 将 EMOJI_MAP 转换为数组
const unicodeEmojiList = computed(() => {
  return Object.entries(EMOJI_MAP).map(([code, char]) => ({
    code,
    char,
    type: 'unicode',
    name: code
  }))
})

const currentEmojis = computed(() => {
  switch (activeTab.value) {
    case 'recent':
      return recentEmojis.value
    case 'unicode':
      return unicodeEmojiList.value
    case 'custom':
      return customEmojis.value
    default:
      return []
  }
})

const selectEmoji = (emoji) => {
  emit('select', emoji)
  // 添加到最近使用
  addToRecent(emoji)
}

const addToRecent = (emoji) => {
  const exists = recentEmojis.value.findIndex(e => e.code === emoji.code)
  if (exists > -1) {
    recentEmojis.value.splice(exists, 1)
  }
  recentEmojis.value.unshift(emoji)
  if (recentEmojis.value.length > 20) {
    recentEmojis.value = recentEmojis.value.slice(0, 20)
  }
  // 持久化到本地
  try {
    uni.setStorageSync('recent_emojis', JSON.stringify(recentEmojis.value))
  } catch (e) { /* ignore */ }
}

// 加载自定义 emoji
onMounted(async () => {
  // 加载最近使用
  try {
    const stored = uni.getStorageSync('recent_emojis')
    if (stored) {
      recentEmojis.value = JSON.parse(stored)
    }
  } catch (e) { /* ignore */ }

  // 从后端加载自定义 emoji
  try {
    const response = await get(emojiApi.getEmojiList().url)
    if (response.code === 200 && response.data) {
      customEmojis.value = (response.data.custom || []).map(e => ({
        ...e,
        type: 'custom'
      }))
      // 更新工具函数中的自定义映射
      const { loadCustomEmojis } = await import('@/utils/emoji.js')
      loadCustomEmojis(response.data.custom || [])
    }
  } catch (error) {
    console.error('加载自定义 emoji 失败:', error)
  }
})
</script>

<style scoped lang="scss">
.emoji-picker {
  background: #fff;
  border-top: 1rpx solid #eee;
  height: 500rpx;
}

.emoji-tabs {
  display: flex;
  border-bottom: 1rpx solid #f0f0f0;
  padding: 0 20rpx;
}

.tab-item {
  padding: 20rpx 30rpx;
  font-size: 28rpx;
  color: #999;
  position: relative;
}

.tab-item.active {
  color: #333;
  font-weight: 600;
}

.tab-item.active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 30rpx;
  right: 30rpx;
  height: 4rpx;
  background: #ff8fa3;
  border-radius: 2rpx;
}

.emoji-grid {
  height: 380rpx;
}

.emoji-grid-inner {
  display: flex;
  flex-wrap: wrap;
  padding: 20rpx;
}

.emoji-item {
  width: 12.5%;
  height: 80rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.unicode-emoji {
  font-size: 48rpx;
}

.custom-emoji {
  width: 56rpx;
  height: 56rpx;
}

.emoji-footer {
  height: 60rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-top: 1rpx solid #f5f5f5;
}

.footer-text {
  font-size: 22rpx;
  color: #ccc;
}
</style>
```

### 5.5 EmojiText 渲染组件

```vue
<!-- src/components/emoji-text/index.vue -->
<template>
  <text v-if="!hasEmojiContent" class="emoji-text">{{ text }}</text>
  <view v-else class="emoji-text emoji-text-inline">
    <template v-for="(part, index) in parsedParts" :key="index">
      <text v-if="part.type === 'text'" class="text-part">{{ part.content }}</text>
      <text v-else-if="part.type === 'unicode'" class="unicode-part">{{ part.char }}</text>
      <image
        v-else-if="part.type === 'custom'"
        class="custom-emoji-img"
        :src="part.url"
        mode="aspectFit"
      />
    </template>
  </view>
</template>

<script setup>
import { computed } from 'vue'
import { parseEmojiText, hasEmoji } from '@/utils/emoji.js'

const props = defineProps({
  text: { type: String, default: '' }
})

const hasEmojiContent = computed(() => hasEmoji(props.text))
const parsedParts = computed(() => parseEmojiText(props.text))
</script>

<style scoped lang="scss">
.emoji-text {
  display: inline;
}

.emoji-text-inline {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: center;
}

.text-part {
  display: inline;
}

.unicode-part {
  font-size: inherit;
  display: inline;
}

.custom-emoji-img {
  width: 1.2em;
  height: 1.2em;
  display: inline-block;
  vertical-align: middle;
}
</style>
```

---

## 六、数据流

### 场景一：私信聊天发送含 emoji 的消息

```
用户输入："你好😊，下午图书馆见！"
         │
         ▼ 前端 encodeEmoji()
         │
    "你好[smile]，下午图书馆见！"
         │
         ▼ POST /api/v1/messages/chat/send
         │    { receiverId: 123, content: "你好[smile]，下午图书馆见！", messageType: 1 }
         │
         ▼ 后端 EmojiUtil.encode()（幂等，无变化）
         │
    存入 chat_message.content = "你好[smile]，下午图书馆见！"
         │
         ▼ 前端接收响应 / WebSocket 推送
         │
    前端 decodeEmoji() / EmojiText 组件渲染
         │
         ▼
    展示："你好😊，下午图书馆见！"
```

### 场景二：发布含 emoji 的帖子

```
用户在 publish.vue 输入："出二手教材📚，线代50元"
         │
         ▼ 前端 encodeEmoji()
         │
    "出二手教材[book]，线代50元"
         │
         ▼ POST /api/v1/posts/publish
         │
         ▼ 后端 EmojiUtil.encode()
         │
    存入 post.content = "出二手教材[book]，线代50元"
         │
         ▼ 帖子列表/详情查询返回
         │
    前端 EmojiText 组件渲染
         │
         ▼
    展示："出二手教材📚，线代50元"
```

### 场景三：评论含 emoji

```
用户在评论弹窗输入："我也有同款👍"
         │
         ▼ useComments.js 中 submitReply() 调用 encodeEmoji()
         │
    "我也有同款[thumbs_up]"
         │
         ▼ POST /api/v1/comments/add
         │
         ▼ 后端 EmojiUtil.encode()
         │
    存入 comment.content = "我也有同款[thumbs_up]"
         │
         ▼ 评论列表查询返回
         │
    前端 EmojiText 组件渲染
         │
         ▼
    展示："我也有同款👍"
```

---

## 七、边界情况处理

| 场景 | 处理方案 |
|------|---------|
| 用户直接用手机键盘输入 Unicode emoji | 前端发送前 `encodeEmoji()` 自动转换；后端接收后二次 `encode()` 做幂等保障 |
| 用户输入 `[smile]` 这类文本（非 emoji） | 只有匹配到 `EMOJI_MAP` 中存在的 key 才转换，否则保留原样 |
| 自定义 emoji 图片加载失败 | 显示占位符文本（如 `[jxu_doge]`）或显示默认缺失图标 |
| 后端/前端映射表版本不一致 | Unicode emoji 映射表通过常量文件同步管理；自定义 emoji 通过 API 动态获取 |
| 微信小程序包体积限制 | Unicode emoji 零体积成本；自定义 emoji 图片走 CDN/MinIO 外链，不打包进小程序 |
| 搜索功能中的 emoji | 占位符可搜索（如搜 `"[微笑]"`），搜索关键词也可先做 encode 转换 |
| 敏感词过滤与 emoji | 敏感词过滤在 `encode()` **之前**执行，避免用户用 emoji 绕过检测 |
| 占位符嵌套（如 `[[smile]]`） | 正则只匹配单层 `[xxx]`，嵌套情况按普通文本处理 |
| 超长文本含大量 emoji | 文本长度统计以占位符形式为准，数据库 `text` 类型无压力 |
| H5 与小程序 emoji 显示差异 | Unicode emoji 依赖系统字体渲染，不同平台显示风格略有差异属于正常；自定义图片 emoji 完全一致 |

---

## 八、测试验证

### 8.1 后端单元测试

```java
// EmojiUtilTest.java

@Test
public void testEncodeUnicodeEmoji() {
    assertEquals("你好[smile]", EmojiUtil.encode("你好😊"));
    assertEquals("[heart][cry]", EmojiUtil.encode("❤️😭"));
}

@Test
public void testDecodePlaceholder() {
    assertEquals("你好😊", EmojiUtil.decode("你好[smile]"));
    assertEquals("❤️😭", EmojiUtil.decode("[heart][cry]"));
}

@Test
public void testEncodeIdempotent() {
    // 已经是占位符的不再转换
    assertEquals("你好[smile]", EmojiUtil.encode("你好[smile]"));
}

@Test
public void testEncodeMixedContent() {
    assertEquals("出二手教材[book]，线代50元", EmojiUtil.encode("出二手教材📚，线代50元"));
}

@Test
public void testUnknownPlaceholder() {
    // 未知占位符保留原样
    assertEquals("这是[unknown]占位符", EmojiUtil.decode("这是[unknown]占位符"));
}

@Test
public void testIsPureEmoji() {
    assertTrue(EmojiUtil.isPureEmoji("[smile]"));
    assertTrue(EmojiUtil.isPureEmoji("  [smile]  "));
    assertFalse(EmojiUtil.isPureEmoji("你好[smile]"));
    assertFalse(EmojiUtil.isPureEmoji("[smile]你好"));
    assertFalse(EmojiUtil.isPureEmoji(""));
}

@Test
public void testExtractEmojis() {
    List<String> emojis = EmojiUtil.extractEmojis("你好[smile]，下午[library]见！");
    assertEquals(Arrays.asList("smile", "library"), emojis);
}
```

### 8.2 前端单元测试

```javascript
// emoji.test.js

import { encodeEmoji, parseEmojiText, isPureEmoji, hasEmoji } from '@/utils/emoji.js'

describe('emoji utils', () => {
  test('encodeEmoji', () => {
    expect(encodeEmoji('你好😊')).toBe('你好[smile]')
    expect(encodeEmoji('📚📱')).toBe('[book][phone]')
    expect(encodeEmoji('纯文本')).toBe('纯文本')
  })

  test('parseEmojiText', () => {
    const parts = parseEmojiText('你好[smile]')
    expect(parts).toEqual([
      { type: 'text', content: '你好' },
      { type: 'unicode', code: 'smile', char: '😊' }
    ])
  })

  test('isPureEmoji', () => {
    expect(isPureEmoji('[smile]')).toBe(true)
    expect(isPureEmoji('  [smile]  ')).toBe(true)
    expect(isPureEmoji('你好[smile]')).toBe(false)
  })

  test('hasEmoji', () => {
    expect(hasEmoji('你好[smile]')).toBe(true)
    expect(hasEmoji('纯文本')).toBe(false)
  })
})
```

### 8.3 集成测试 Checklist

| 测试项 | 步骤 | 预期结果 |
|--------|------|---------|
| 聊天发送 emoji | 在聊天页面输入含 emoji 的消息，点击发送 | 消息正常发送，对方收到后正确显示 emoji |
| 聊天历史渲染 | 刷新聊天页面，查看历史消息 | 历史消息中的 emoji 正确渲染 |
| 帖子发布 emoji | 在发布页面添加 emoji 后发布 | 帖子成功发布，列表页正确显示 emoji |
| 帖子详情 emoji | 进入帖子详情页 | 帖子正文中的 emoji 正确渲染 |
| 评论 emoji | 在评论中添加 emoji 后提交 | 评论成功，列表中正确显示 emoji |
| 回复评论 emoji | 在回复中添加 emoji | 回复正确显示 emoji |
| 跨端一致性 | 在 H5 发布含 emoji 的帖子，用微信小程序查看 | emoji 显示一致 |
| 自定义 emoji | 添加自定义校园 emoji 后发送 | 自定义 emoji 正确显示图片 |
| 最近使用 | 多次使用不同 emoji | "最近"Tab 正确记录并排序 |
| 纯 emoji 消息 | 发送仅含单个 `[smile]` 的消息 | `messageType` 可为 3（表情） |
| 混合文本 emoji | 发送 "你好[smile]再见" | `messageType` 为 1（文本） |
| 搜索含 emoji | 搜索 `[smile]` 关键词 | 能搜到含该 emoji 的内容 |
| 敏感词 + emoji | 在敏感词中间插入 emoji | 敏感词仍能正确检测 |

---

## 九、文件清单

### 9.1 新增文件

**后端（campus_wall）**：

| # | 路径 | 类型 |
|---|------|------|
| 1 | `src/main/java/com/jyu/campus/common/constant/EmojiConstants.java` | 常量类 |
| 2 | `src/main/java/com/jyu/campus/common/util/EmojiUtil.java` | 工具类 |
| 3 | `src/main/java/com/jyu/campus/social/entity/CustomEmoji.java` | 实体类 |
| 4 | `src/main/java/com/jyu/campus/social/mapper/CustomEmojiMapper.java` | Mapper |
| 5 | `src/main/java/com/jyu/campus/social/service/ICustomEmojiService.java` | Service 接口 |
| 6 | `src/main/java/com/jyu/campus/social/service/impl/CustomEmojiServiceImpl.java` | Service 实现 |
| 7 | `src/main/java/com/jyu/campus/social/controller/EmojiController.java` | Controller |
| 8 | `src/main/resources/db/migration/V2.1__add_custom_emoji_table.sql` | Flyway 迁移 |

**前端（campus-wall-frontend）**：

| # | 路径 | 类型 |
|---|------|------|
| 1 | `src/utils/emoji.js` | 工具函数 |
| 2 | `src/components/emoji-picker/index.vue` | 组件 |
| 3 | `src/components/emoji-text/index.vue` | 组件 |

### 9.2 修改文件

**后端（campus_wall）**：

| # | 路径 | 修改点 |
|---|------|--------|
| 1 | `social/service/impl/ChatServiceImpl.java` | 发送/查询消息时 encode/decode |
| 2 | `community/service/impl/PostPublishService.java` | 发布帖子前 encode |
| 3 | `community/service/impl/CommentServiceImpl.java` | 发表评论前 encode |

**前端（campus-wall-frontend）**：

| # | 路径 | 修改点 |
|---|------|--------|
| 1 | `src/components/chat-input-bar/chat-input-bar.vue` | 接入 emoji-picker |
| 2 | `src/pages/message/chat-detail.vue` | 消息渲染改用 emoji-text |
| 3 | `src/pages/publish/publish.vue` | 添加 emoji 按钮 |
| 4 | `src/composables/useComments.js` | 评论 encode + emoji 输入 |
| 5 | `src/components/post-card/index.vue` | 帖子内容渲染改用 emoji-text |
| 6 | `src/api/social.js`（或 `index.js`） | 添加 emojiApi |

---

## 十、后续扩展

1. **用户最近使用 emoji**
   - 本地 Storage 缓存用户最近使用的 20 个 emoji
   - 在 picker 面板顶部展示"最近使用"分类
   - 可按使用频次排序

2. **自定义 emoji 管理后台**
   - 在 `campus-wall-monitor-ui` 管理后台中增加 emoji 管理页面
   - 支持上传自定义 emoji 图片（自动上传到 MinIO）
   - 支持启用/禁用、排序调整

3. **Emoji 反应（Reactions）**
   - 参考 Slack/Discord，支持对帖子/评论快速添加 emoji 反应
   - 不发送评论，以「👍 23」形式展示在内容下方
   - 需新增 `post_reaction`、`comment_reaction` 表

4. **动画 emoji**
   - 自定义 emoji 支持 GIF / APNG 格式
   - 前端使用 `image` 组件的 `webp` / `gif` 支持

5. **Emoji 快捷键**
   - 输入 `:smile:` 自动联想转换为 `[smile]`
   - 类似 Discord/Slack 的输入体验

6. **Emoji 数据统计**
   - 统计各 emoji 使用频次
   - 分析校园用户最喜欢的表情

---

*本文档版本：v1.0*  
*最后更新：2026-06-03*  
*维护者：前后端开发团队*
