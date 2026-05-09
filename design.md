# 刘看山的"如果世界" — 初始设计文档

> **赛道：** 🦊 刘看山（知乎 × IP）
> **版本：** v0.1 — 2026-05-09

---

## 一、宏观需求

### 产品定义

一个**聊天器形式**的"如果世界"应用。用户输入"如果……"主题（如"如果秦始皇有微信"），AI 基于知乎内容自动生成一群角色（2-100 个），用户选择成为其中一个角色，进入群聊参与讨论。

### 核心功能

| 功能 | 说明 | 优先级 |
|------|------|:---:|
| 世界创建 | 输入主题 → AI 自动生成角色（2-100 个） | P0 |
| 角色选择 | 用户选择"成为谁" | P0 |
| 群聊 | 多角色讨论，用户以选中角色身份参与 | P0 |
| @触发回复 | @某角色 → 触发该角色 AI 回复 | P0 |
| 朋友圈 | 角色动态浏览，点赞/评论 | P1 |
| 私聊 | 与角色 1v1 对话 | P1 |
| 好友 | 加角色为好友，快速私聊 | P2 |
| 导出回答 | 将讨论导出为知乎回答格式 | P2 |
| 预置世界 | 预置 3 个经典世界，免创建直接玩 | P0 |

### 用户流程

```
首页选择/创建世界 → 选择角色 → 进入群聊 → 聊天/@/看朋友圈 → 导出分享
```

### 三项评估标准

- **帮助创作者**：创作者可创建自己的"如果世界"在圈子分享；优质讨论被"活化"后获得全新展示形式
- **帮助消费者**：把"刷知乎"变成"探索平行宇宙"，知识获取变沉浸式体验
- **赋能业务**："如果"类内容天然有讨论度和传播力，站外分享为知乎引流

---

## 二、技术选型

| 组件 | 选型 | 说明 |
|------|------|------|
| **前端** | React + Vite + TailwindCSS | SPA，组件化开发，热更新 |
| **后端** | Flask (Python) | 轻量，适合快速迭代 |
| **LLM** | OpenAI 兼容接口 + 自动重试 | 支持任意 OpenAI-style API，带重试/退避机制 |
| **数据库** | SQLite | MVP 全部数据 + 缓存均用 SQLite 磁盘存储 |
| **实时推送** | SSE (Server-Sent Events) | 服务端→客户端单向推送，比 WebSocket 简单 |

### LLM 接口规范（OpenAI 风格 + 重试）

```python
# 支持任意 OpenAI 兼容的 LLM 服务
LLM_BASE_URL = "https://api.openai.com/v1"  # 可替换
LLM_MODEL = "gpt-4o"  # 可配置

# 重试策略
RETRY_CONFIG = {
    "max_retries": 3,
    "backoff_factor": 1.0,      # 退避：1s, 2s, 4s
    "retry_on_status": [429, 500, 502, 503],  # 限频/服务器错误重试
    "timeout": 60,              # 单次请求超时
}
```

使用 `tenacity` 或 `httpx` 的 `RetryingTransport` 实现自动重试。

### SQLite 使用范围

- 所有业务数据（世界、角色、消息、朋友圈、好友关系）
- 世界创建缓存（相同主题不重复调知乎 API）
- LLM 响应缓存（相同 prompt 不重复调 LLM）
- 知乎搜索结果缓存

---

## 三、详细设计（概要，后续细化）

### 3.1 世界生成逻辑

**输入：** 用户输入的主题（如"如果秦始皇有微信"），可选角色数量。

**流程：**

```
1. 检查缓存：相同主题是否已创建过世界
   ├── 有 → 直接返回缓存结果
   └── 没有 → 继续
       ↓
2. 调用知乎搜索 API：搜索关键词相关讨论
   - API: GET /api/v1/content/zhihu_search?q={keyword}
   - 缓存搜索结果到 SQLite
       ↓
3. （可选）调用知乎热榜 API：获取当前热点作为补充素材
       ↓
4. 调用 LLM 生成世界设定：
   - system: "你是一个世界构建师..."
   - user: 主题 + 知乎搜索结果
   - 输出: JSON {background, characters: [...]}
       ↓
5. 存入数据库：worlds + characters 表
6. 缓存结果到 SQLite
7. 返回世界 + 角色列表
```

**角色生成 prompt 概要：**

```
基于以下知乎讨论素材，为主题 "{theme}" 生成一个"如果世界"的角色列表。

要求：
- 角色数量: {count} 个
- 每个角色包含: name, role, personality, speaking_style, avatar(emoji), system_prompt
- 角色应覆盖: 核心人物、配角、刘看山(观察者)
- system_prompt 包含: 身份、性格、说话风格、对其它角色的态度、发言规则(不OOC)

知乎素材: {search_results}

返回 JSON。
```

**TODO 后续细化：** prompt 模板优化、知乎搜索结果截断策略、角色数量上下限、角色多样性控制。

### 3.2 时间线推进

**核心概念：** 每个世界有一条"群聊时间线"，所有消息按时间顺序排列。

```
时间线 = messages 表按 created_at 排序
每条消息: {id, world_id, character_id, content, type, reply_to, is_user, created_at}
```

**推进机制：**

1. **用户发送消息** → 插入时间线 → 触发@的角色回复
2. **@触发回复** → 角色 AI 生成内容 → 插入时间线 → SSE 推送
3. **主动发言**（群聊沉寂 > N 秒）→ 随机选择角色发言 → 插入时间线 → SSE 推送

**TODO 后续细化：** 主动发言的触发条件、角色活跃度权重、防止刷屏的策略、消息分页加载。

### 3.3 进度推进（AI 回复生成）

```
用户消息到达后端
    │
    ├── 保存消息到 messages 表
    ├── 解析 @提及，提取需要回复的角色列表
    │
    └── 对每个被@角色:
         │
         ├── 提交到 LLM 工作队列（Semaphore 限流）
         ├── 立即返回 task_id 给前端
         │
         └── Worker 线程:
              ├── 获取并发许可 (semaphore.acquire)
              ├── 构建 prompt (system + 最近 N 条上下文 + 用户消息)
              ├── 调用 LLM API（带重试）
              ├── 保存回复到 messages 表
              ├── SSE 推送新消息
              └── 释放并发许可 (semaphore.release)
```

**TODO 后续细化：** LLM 队列大小、prompt 上下文窗口大小、重试策略细节、错误处理。

---

## 四、后端 API 设计

### 4.1 核心接口（已确定）

#### 世界管理

```
POST   /api/worlds/create              # 创建新世界
GET    /api/worlds                     # 世界列表
GET    /api/worlds/{world_id}          # 世界详情
GET    /api/worlds/{world_id}/characters  # 角色列表
POST   /api/worlds/{world_id}/join     # 选择角色加入
```

#### 聊天

```
GET    /api/worlds/{world_id}/messages        # 获取消息列表（分页）
POST   /api/worlds/{world_id}/messages        # 发送消息
GET    /api/worlds/{world_id}/sse             # SSE 实时推送
```

**POST /api/worlds/{world_id}/messages**
```json
// Request
{
  "content": "@李斯 你觉得呢？",
  "type": "group",       // group | private
  "reply_to": null,      // 可选
  "private_to": null     // 私聊对象 ID，可选
}

// Response
{
  "msg_id": 42,
  "pending_tasks": [
    {"task_id": "xxx", "character_id": 5, "character_name": "李斯"}
  ]
}
```

**GET /api/worlds/{world_id}/sse**

SSE 事件流：
```
event: message
data: {"id": 43, "character_id": 5, "content": "陛下圣明...", "is_user": false}

event: typing
data: {"character_id": 5, "status": "started"}

event: error
data: {"message": "LLM 请求超时"}
```

#### 朋友圈

```
GET    /api/worlds/{world_id}/moments              # 获取朋友圈动态
POST   /api/worlds/{world_id}/moments/{id}/like    # 点赞
POST   /api/worlds/{world_id}/moments/{id}/comment # 评论
```

#### 任务状态

```
GET    /api/tasks/{task_id}          # 查询 LLM/世界生成任务状态
```

### 4.2 非核心接口（后续设计）

```
# 社交关系
GET/POST/DELETE  /api/worlds/{world_id}/friends          # 好友管理

# 导出
POST   /api/worlds/{world_id}/export                     # 导出为知乎回答

# 预置世界
GET    /api/worlds/preset                                # 获取预置世界列表
POST   /api/worlds/preset/{id}/clone                     # 克隆预置世界

# 管理
DELETE /api/worlds/{world_id}                            # 删除世界
PUT    /api/worlds/{world_id}                            # 更新世界设定
```

---

## 五、数据库设计

### 核心表

```sql
-- 世界
CREATE TABLE worlds (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    theme       TEXT NOT NULL,
    background  TEXT,
    zhihu_topic TEXT,
    status      TEXT DEFAULT 'ready',   -- creating | ready
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 角色
CREATE TABLE characters (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id      INTEGER NOT NULL REFERENCES worlds(id),
    name          TEXT NOT NULL,
    role          TEXT,
    personality   TEXT,
    speaking_style TEXT,
    avatar        TEXT,
    system_prompt TEXT,
    is_liukanshan BOOLEAN DEFAULT 0,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 消息
CREATE TABLE messages (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id    INTEGER NOT NULL REFERENCES worlds(id),
    character_id INTEGER NOT NULL REFERENCES characters(id),
    content     TEXT NOT NULL,
    type        TEXT NOT NULL DEFAULT 'group',  -- group | private
    reply_to    INTEGER REFERENCES messages(id),
    is_user     BOOLEAN DEFAULT 0,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 消息 @关联
CREATE TABLE message_mentions (
    message_id  INTEGER NOT NULL REFERENCES messages(id),
    character_id INTEGER NOT NULL REFERENCES characters(id),
    PRIMARY KEY (message_id, character_id)
);

-- 朋友圈动态
CREATE TABLE moments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id    INTEGER NOT NULL REFERENCES worlds(id),
    character_id INTEGER NOT NULL REFERENCES characters(id),
    content     TEXT NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 朋友圈点赞
CREATE TABLE moment_likes (
    moment_id   INTEGER NOT NULL REFERENCES moments(id),
    character_id INTEGER REFERENCES characters(id),
    is_user     BOOLEAN DEFAULT 0,
    PRIMARY KEY (moment_id, character_id, is_user)
);

-- 朋友圈评论
CREATE TABLE moment_comments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    moment_id   INTEGER NOT NULL REFERENCES moments(id),
    character_id INTEGER REFERENCES characters(id),
    is_user     BOOLEAN DEFAULT 0,
    content     TEXT NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 缓存表

```sql
-- 世界创建缓存（相同主题不重复生成）
CREATE TABLE world_cache (
    theme_hash    TEXT PRIMARY KEY,      -- theme 的 hash
    world_id      INTEGER REFERENCES worlds(id),
    zhihu_results TEXT,                   -- JSON 存储搜索结果
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- LLM 响应缓存
CREATE TABLE llm_cache (
    prompt_hash   TEXT PRIMARY KEY,
    response      TEXT NOT NULL,
    model         TEXT,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 知乎搜索缓存
CREATE TABLE zhihu_cache (
    query_hash    TEXT PRIMARY KEY,
    result        TEXT NOT NULL,          -- JSON 存储结果
    api_type      TEXT,                   -- search | hotlist
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 六、项目结构

```
liukanshan/
├── backend/
│   ├── app.py                 # Flask 入口 + 路由注册
│   ├── config.py              # 配置（LLM, 数据库路径, API key 等）
│   ├── db.py                  # 数据库初始化 + 连接管理
│   ├── models.py              # 数据访问层（CRUD 封装）
│   ├── llm.py                 # LLM 调用（OpenAI 风格 + 重试）
│   ├── zhihu.py               # 知乎 API 调用封装
│   ├── queue_manager.py       # 世界生成队列 + LLM 工作队列
│   ├── sse.py                 # SSE 推送管理
│   └── routes/
│       ├── world.py           # 世界管理路由
│       ├── message.py         # 消息路由
│       └── moment.py          # 朋友圈路由
├── frontend/
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   └── src/
│       ├── main.jsx
│       ├── App.jsx
│       ├── pages/
│       ├── components/
│       ├── api/               # API 请求封装
│       └── hooks/             # SSE hook 等
├── api/                       # 知乎 API 文档
└── README.md                  # 项目概要
```
