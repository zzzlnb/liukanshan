# 刘看山的"如果世界" — 技术方案 v0.2

> **赛道：** 🦊 刘看山（知乎 × IP）
> **技术栈：** Flask（后端）+ React + Vite（前端）+ SQLite
> **约束：** 无生图，Agent 直接调用 API
> **版本：** v0.3 — 2026-05-09（聊天器形式 + 并发队列设计）

---

## 一、产品形态

### 核心理念

一个**聊天器形式**的"如果世界"——用户进入后，看到的不是静态页面，而是一个**活跃的群聊**，历史人物、虚构角色、甚至刘看山都在里面讨论、聊天、发朋友圈。用户选择成为其中一个角色，参与讨论。

### 用户流程

```
1. 首页：选择/搜索"如果世界"主题
   ↓
2. 世界创建：AI 根据主题 + 知乎内容，自动生成 2-100 个角色
   ↓
3. 角色选择：用户选择"成为谁"（也可以让 AI 推荐一个）
   ↓
4. 进入群聊：看到角色们在讨论，用户以选中角色的身份参与
   ↓
5. 社交：@某人 → 触发对方回复；私聊；加好友
   ↓
6. 看朋友圈：切换到朋友圈 tab，浏览角色们的动态
   ↓
7. 导出回答：将精彩讨论导出为知乎回答格式
```

---

## 二、系统架构

```
┌────────────────────────────────────────────────────┐
│                    前端 (React + Vite)              │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │首页/世界  │→ │角色选择  │→ │群聊 + 朋友圈     │  │
│  │选择      │  │成为谁    │  │(@私聊好友导出)   │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
└──────────────────────┬─────────────────────────────┘
                       │ HTTP + SSE
┌──────────────────────▼─────────────────────────────┐
│                    后端 (Flask)                     │
│                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │世界管理   │ │角色管理  │ │消息管理          │   │
│  │(创建/列表)│ │(生成/选择)│ │(群聊/私聊/@触发) │   │
│  └──────────┘ └──────────┘ └──────────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │朋友圈管理 │ │社交关系  │ │导出              │   │
│  │(动态/点赞)│ │(好友/私聊)│ │(回答导出)        │   │
│  └──────────┘ └──────────┘ └──────────────────┘   │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │          Agent 层 (直接调用 API)              │  │
│  │  ┌──────────────┐  ┌─────────────────────┐  │  │
│  │  │知乎 API 调用  │  │自有 LLM API 调用     │  │  │
│  │  │(搜索/热榜/   │  │(角色生成/对话生成/   │  │  │
│  │  │ 故事/圈子)   │  │ 朋友圈生成)          │  │  │
│  │  └──────────────┘  └─────────────────────┘  │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │              SQLite 数据库                    │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 三、核心功能详细设计

### 3.1 世界创建

**入口：** 用户在首页输入"如果……"的主题（如"如果秦始皇有微信"），或从预置世界中选择。

**流程：**

```
1. 用户输入主题: "如果秦始皇有微信"
   ↓
2. 后端调用知乎搜索 API: 搜索"秦始皇"相关讨论
   ↓
3. 后端调用知乎热榜 API: 检查是否有相关热榜话题
   ↓
4. 后端调用自有 LLM API:
   - 基于搜索结果，生成世界背景设定
   - 生成 5-20 个角色（每个有名字、身份、性格、说话风格）
   - 生成开场话题
   ↓
5. 返回世界设定 + 角色列表给前端
   ↓
6. 用户选择"成为谁"
   ↓
7. 进入群聊
```

**角色生成 prompt 设计：**

```
主题：如果秦始皇有微信

请根据以下知乎讨论素材，生成这个"如果世界"中的角色列表。

要求：
1. 角色数量：{count} 个（5-20 个）
2. 每个角色包含：
   - name: 角色名（如"秦始皇"、"李斯"、"赵高"）
   - role: 身份描述（如"大秦皇帝"、"丞相"、"中车府令"）
   - personality: 性格特点（如"威严多疑"、"圆滑世故"）
   - speaking_style: 说话风格（如"简短威严，喜欢用'朕'"、"长篇大论，引经据典"）
   - avatar: 默认 emoji 或颜色标识
   - system_prompt: 完整的 system prompt（用于后续对话生成）

3. 角色应覆盖：
   - 核心历史人物（秦始皇、李斯、赵高、蒙恬等）
   - 配角（太监、将军、谋士等）
   - 刘看山（作为这个世界的观察者/记录者）
   - 可加入 1-2 个现代人角色（如"穿越而来的程序员"）

4. 每个角色的 system_prompt 应包含：
   - 你是谁、你的身份
   - 你的性格和说话风格
   - 你在这个"如果世界"中的处境
   - 你对其他角色的态度
   - 发言规则（保持角色一致性、不 OOC）

知乎素材：
{search_results}

请返回 JSON 格式的角色列表。
```

### 3.2 群聊

**设计要点：**

- 默认是一个群聊界面，所有角色都在里面
- 用户以选中的角色身份参与
- AI 角色会自动发言（受@触发或主动发言）
- 聊天记录持久化

**消息类型：**

```json
{
  "id": 1,
  "world_id": 1,
  "character_id": 3,
  "content": "朕今日统一了度量衡，诸卿有何感想？",
  "type": "group",       // group | private
  "reply_to": null,      // 回复某条消息的 ID
  "mention_ids": [5, 8], // @了哪些角色
  "is_user": false,      // 是否是用户发送的
  "created_at": "2026-05-09T19:00:00Z"
}
```

**@机制：**

当用户在消息中 @某角色（如 `@李斯 你觉得呢？`）：
1. 前端解析 @标记，提取被@的角色 ID
2. 后端收到消息后，触发该角色的 AI 回复
3. AI 角色在 2-5 秒内回复（模拟"正在输入..."效果，通过 SSE 推送状态）
4. 回复内容存入数据库，通过 SSE 推送给前端

**AI 主动发言机制：**

- 当群聊沉寂超过 30 秒（可配置），随机选择一个活跃角色发言
- 发言内容基于当前聊天上下文 + 角色 system prompt
- 防止 AI 角色连续发言：同一角色 60 秒内最多发言 1 次

### 3.3 私聊

用户可以与任一角色私聊：

- 从群聊中点击角色头像 → "私聊"
- 或在角色列表中选择
- 私聊消息 type = "private"，仅用户和该角色可见
- 回复机制同群聊（AI 自动回复）

### 3.4 好友系统

- 用户可以"加"角色为好友
- 好友列表显示在侧边栏
- 好友角色在线状态（模拟）
- 快速发起私聊

### 3.5 朋友圈

**设计要点：**

- 切换到"朋友圈"tab，看到角色们发布的动态
- 每条动态：角色头像 + 昵称 + 内容 + 时间 + 点赞数
- 用户可以点赞、评论
- 评论会触发角色回复（类似@机制）

**朋友圈内容来源：**

- **预生成 + 实时生成混合模式：**
  - 世界创建时预生成 3-5 条初始动态
  - 用户访问朋友圈时，AI 根据角色性格和近期群聊内容，实时生成新动态
  - 每个角色有自己的发帖频率和风格（如秦始皇爱发"工作动态"，赵高发"阴阳怪气"的吐槽）

### 3.6 导出回答

- 用户可以选择群聊中的一段讨论或一条朋友圈动态
- 点击"导出为知乎回答"
- 后端调用 LLM，将对话内容整理为知乎回答格式：
  - 标题
  - 正文（结构化整理讨论内容）
  - 标注来源（"本内容来自'如果世界'项目"）
- 用户可复制导出内容，手动发布到知乎圈子/想法

---

## 四、API 设计

### 4.1 后端 API（Flask）

#### 世界管理

```
POST   /api/worlds/create          # 创建新世界（输入主题，返回世界+角色列表）
GET    /api/worlds                 # 获取世界列表（预置+用户创建）
GET    /api/worlds/{id}            # 获取世界详情
```

**POST /api/worlds/create**
```json
// Request
{
  "theme": "如果秦始皇有微信",
  "character_count": 8,        // 2-100，默认 8
  "zhihu_topic": "秦始皇"      // 可选，用于搜索素材
}

// Response
{
  "world_id": 1,
  "theme": "如果秦始皇有微信",
  "background": "在大秦帝国...",
  "characters": [
    {
      "id": 1,
      "name": "秦始皇",
      "role": "大秦皇帝",
      "personality": "威严多疑",
      "speaking_style": "简短威严，喜欢用'朕'",
      "avatar": "🐉",
      "system_prompt": "你是秦始皇嬴政..."
    },
    // ...
  ]
}
```

#### 角色选择

```
POST   /api/worlds/{id}/join      # 选择角色加入世界
GET    /api/worlds/{id}/characters # 获取角色列表
```

**POST /api/worlds/{id}/join**
```json
// Request
{
  "character_id": 3
}

// Response
{
  "world_id": 1,
  "character_id": 3,
  "welcome_message": "欢迎来到大秦帝国工作群..."
}
```

#### 消息

```
GET    /api/worlds/{id}/messages     # 获取群聊消息列表
POST   /api/worlds/{id}/messages     # 发送消息
GET    /api/worlds/{id}/sse          # SSE 实时推送
```

**POST /api/worlds/{id}/messages**
```json
// Request
{
  "content": "@李斯 你觉得呢？",
  "type": "group",           // group | private
  "reply_to": null,          // 可选
  "private_to": null         // 私聊对象 ID，可选
}

// Response
{
  "id": 42,
  "character_id": 3,
  "content": "@李斯 你觉得呢？",
  "type": "group",
  "is_user": true,
  "created_at": "2026-05-09T19:00:00Z"
}
```

#### 朋友圈

```
GET    /api/worlds/{id}/moments     # 获取朋友圈动态
POST   /api/worlds/{id}/moments/{moment_id}/like   # 点赞
POST   /api/worlds/{id}/moments/{moment_id}/comment # 评论
```

#### 社交

```
GET    /api/worlds/{id}/friends           # 获取好友列表
POST   /api/worlds/{id}/friends           # 添加好友
DELETE /api/worlds/{id}/friends/{char_id}  # 删除好友
```

#### 导出

```
POST   /api/worlds/{id}/export           # 导出为知乎回答
```

**POST /api/worlds/{id}/export**
```json
// Request
{
  "message_ids": [10, 11, 12, 13],   // 要导出的消息 ID 列表
  "title": "如果秦始皇有微信，他会发什么朋友圈？"  // 可选
}

// Response
{
  "title": "如果秦始皇有微信，他会发什么朋友圈？",
  "content": "这是一个有趣的问题。让我们从大秦帝国工作群的聊天记录来回答...\n\n...",
  "format": "markdown"
}
```

---

## 五、数据库设计

### 5.1 Schema

```sql
-- 世界
CREATE TABLE worlds (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    theme       TEXT NOT NULL,          -- "如果秦始皇有微信"
    background  TEXT,                    -- 世界背景设定
    zhihu_topic TEXT,                    -- 用于搜索的知乎话题
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 角色
CREATE TABLE characters (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id      INTEGER NOT NULL REFERENCES worlds(id),
    name          TEXT NOT NULL,
    role          TEXT,                   -- 身份描述
    personality   TEXT,
    speaking_style TEXT,
    avatar        TEXT,                   -- emoji 或颜色
    system_prompt TEXT,                   -- 完整的 system prompt
    is_liukanshan BOOLEAN DEFAULT 0,     -- 是否是刘看山
    activity_level INTEGER DEFAULT 5,    -- 活跃度 1-10
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
    is_user     BOOLEAN DEFAULT 0,       -- 是否是用户发送
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 消息 @关联
CREATE TABLE message_mentions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id  INTEGER NOT NULL REFERENCES messages(id),
    character_id INTEGER NOT NULL REFERENCES characters(id)
);

-- 好友关系
CREATE TABLE friendships (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id    INTEGER NOT NULL REFERENCES worlds(id),
    character_id INTEGER NOT NULL REFERENCES characters(id),
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(world_id, character_id)
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
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    moment_id   INTEGER NOT NULL REFERENCES moments(id),
    character_id INTEGER REFERENCES characters(id),  -- 角色点赞
    is_user     BOOLEAN DEFAULT 0,                    -- 用户点赞
    UNIQUE(moment_id, character_id, is_user)
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

---

## 六、Agent 对话流程

### 6.1 用户发消息后的 AI 回复流程

```
用户: "@李斯 你觉得呢？"
  │
  ▼
后端解析 @李斯 → character_id=5
  │
  ▼
构建 prompt:
  system: 李斯的 system prompt
  context: 最近 20 条群聊消息
  user_message: "@李斯 你觉得呢？"
  │
  ▼
调用自有 LLM API → 获取回复内容
  │
  ▼
存入 messages 表
  │
  ▼
SSE 推送给前端 → 消息出现
```

### 6.2 AI 主动发言流程

```
群聊沉寂 > 30 秒
  │
  ▼
后端选择活跃角色（非刘看山，非用户角色，60 秒内未发言）
  │
  ▼
构建 prompt:
  system: 角色的 system prompt
  context: 最近 20 条群聊消息
  instruction: "根据以上讨论，以你的风格自然地发言"
  │
  ▼
调用自有 LLM API → 获取发言内容
  │
  ▼
存入 messages 表 → SSE 推送
```

### 6.3 朋友圈生成流程

```
用户访问朋友圈
  │
  ▼
检查缓存：最近 10 分钟内是否有生成的动态
  │
  ├── 有 → 直接返回
  │
  └── 没有 → 触发新动态生成
       │
       ▼
       选择 2-3 个活跃角色
       │
       ▼
       构建 prompt:
         system: 角色 personality + speaking_style
         context: 该角色最近的群聊发言
         instruction: "以你的风格发一条朋友圈动态"
       │
       ▼
       调用自有 LLM API → 获取动态内容
       │
       ▼
       存入 moments 表 → 返回给前端
```

---

## 七、知乎 API 调用策略

### 7.1 世界创建时

| API | 用途 | 调用时机 |
|-----|------|----------|
| 知乎搜索 API | 搜索主题相关讨论 | 世界创建时调用 1-3 次 |
| 知乎热榜 API | 获取当前热点 | 世界创建时调用 1 次 |
| 直答 AGENT | 生成背景知识摘要 | 世界创建时调用 1 次 |

### 7.2 日常使用中

| API | 用途 | 调用时机 |
|-----|------|----------|
| 知乎搜索 API | 用户搜索新话题 | 按需调用 |
| 知乎圈子 API | 发布导出内容 | 用户主动导出时 |
| 知乎故事 API | 基于故事创建世界 | 用户选择故事主题时 |

### 7.3 调用量控制

- 世界创建是最耗 API 的操作（3-5 次调用），建议缓存已创建的世界
- 对话生成只用自有 LLM API，不调用知乎 API
- 知乎搜索 API 日限 1000 次，完全够用

---

## 八、前端设计

### 8.1 页面结构

```
┌─────────────────────────────────────────────────┐
│ 首页                                            │
│                                                 │
│  🦊 刘看山的如果世界                              │
│                                                 │
│  🔥 预置世界                                     │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │如果秦始  │ │如果李白  │ │如果量子  │          │
│  │皇有微信  │ │有朋友圈  │ │力学有    │          │
│  │          │ │         │ │社交号    │          │
│  └─────────┘ └─────────┘ └─────────┘          │
│                                                 │
│  ✨ 创建新世界                                   │
│  ┌──────────────────────────────────────┐      │
│  │ 输入你的"如果……"                      │ [创建] │
│  └──────────────────────────────────────┘      │
│  角色数量: [  8  ] 人 (2-100)                   │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ 角色选择页                                       │
│                                                 │
│  🦊 "欢迎来到 如果秦始皇有微信 世界"               │
│  世界背景：在大秦帝国...                          │
│                                                 │
│  选择你要成为的角色：                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐          │
│  │🐉    │ │📜    │ │🎭    │ │🗡️    │          │
│  │秦始皇│ │李斯  │ │赵高  │ │蒙恬  │          │
│  │威严  │ │圆滑  │ │阴险  │ │忠勇  │          │
│  └──────┘ └──────┘ └──────┘ └──────┘          │
│  ┌──────┐ ┌──────┐                            │
│  │🦊    │ │💻    │                            │
│  │刘看山│ │程序员│                            │
│  │好奇  │ │穿越者│                            │
│  └──────┘ └──────┘                            │
│                                                 │
│  [🎲 随机推荐一个角色]                            │
│                                                 │
│  [进入世界]                                     │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ 主界面（群聊 + 朋友圈）                            │
│                                                 │
│ ┌─────┬──────────────────────────┬────────────┐ │
│ │侧边栏│ 聊天区域                  │ 角色面板   │ │
│ │     │                          │            │ │
│ │[群聊]│ 🐉 秦始皇 19:00           │ 在线角色:   │ │
│ │[朋友圈]│ 朕今日统一了度量衡       │ 🐉 秦始皇   │ │
│ │     │                          │ 📜 李斯     │ │
│ │好友  │ 📜 李斯 19:01            │ 🎭 赵高     │ │
│ │列表  │ 陛下圣明！臣以为...       │ 🗡️ 蒙恬    │ │
│ │     │                          │ 🦊 刘看山   │ │
│ │     │ 💻 程序员 19:02           │ 💻 程序员   │ │
│ │     │ 这就是大秦帝国的微信群？    │ (你)       │ │
│ │     │                          │            │ │
│ │     │ 🎭 赵高 19:03            │            │ │
│ │     │ 呵呵，度量衡统一了        │            │ │
│ │     │ 那以后贪污也好算账了~     │            │ │
│ │     │                          │            │ │
│ │     │ [输入框: @李斯 你觉得呢？] │            │ │
│ │     │ [发送]                    │            │ │
│ └─────┴──────────────────────────┴────────────┘ │
│                                                 │
│ 切换到朋友圈 Tab:                                │
│ ┌─────────────────────────────────────────────┐ │
│ │ 🐉 秦始皇  2小时前                           │ │
│ │ 今日巡视了长城，风吹日晒，但朕很欣慰。         │ │
│ │ [赞 12] [评论 3]                            │ │
│ │                                             │ │
│ │ 🎭 赵高  1小时前                             │ │
│ │ 有些人以为统一了度量衡就能统一人心，天真。     │ │
│ │ [赞 8] [评论 5]                             │ │
│ │                                             │ │
│ │ 🦊 刘看山  30分钟前                          │ │
│ │ 在大秦当史官的第三天，发现这里的人比我        │ │
│ │ 想象的有趣多了。晚上去吃烧烤（如果秦朝有的话）│ │
│ │ [赞 23] [评论 7]                            │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### 8.2 前端组件结构

```
src/
├── components/
│   ├── WorldSelector.jsx      # 首页：世界选择/创建
│   ├── CharacterPicker.jsx    # 角色选择页
│   ├── ChatWindow.jsx         # 群聊窗口
│   ├── MessageBubble.jsx      # 单条消息气泡
│   ├── MomentFeed.jsx         # 朋友圈动态流
│   ├── MomentCard.jsx         # 单条朋友圈卡片
│   ├── CharacterList.jsx      # 侧边角色列表
│   ├── FriendList.jsx         # 好友列表
│   ├── PrivateChat.jsx        # 私聊窗口
│   ├── ExportDialog.jsx       # 导出对话框
│   └── InputBox.jsx           # 消息输入框（支持 @）
├── hooks/
│   ├── useSSE.js              # SSE 实时推送 hook
│   ├── useWorld.js            # 世界数据 hook
│   └── useCharacter.js        # 角色数据 hook
├── pages/
│   ├── Home.jsx               # 首页
│   ├── CharacterSelect.jsx    # 角色选择页
│   ├── World.jsx              # 世界主界面
│   └── Moments.jsx            # 朋友圈页面
├── api/                       # API 请求封装
└── utils/                     # 工具函数（@解析等）
```

### 8.3 技术选型理由

- **React + Vite:** 快速开发热更新，组件化开发消息气泡/朋友圈卡片等复用组件
- **TailwindCSS:** 快速样式开发
- **SSE (Server-Sent Events):** 单向实时推送（服务端→客户端），比 WebSocket 简单，完全满足聊天需求

---

## 九、项目文件结构

```
liukanshan/
├── backend/
│   ├── app.py                 # Flask 入口
│   ├── config.py              # 配置（API key, 数据库路径等）
│   ├── models.py              # 数据库模型
│   ├── routes/
│   │   ├── world.py           # 世界管理 API
│   │   ├── message.py         # 消息 API
│   │   ├── moment.py          # 朋友圈 API
│   │   ├── friend.py          # 好友 API
│   │   └── export.py          # 导出 API
│   ├── agents/
│   │   ├── world_builder.py   # 世界/角色生成 Agent
│   │   ├── chat_agent.py      # 对话生成 Agent
│   │   └── moment_agent.py    # 朋友圈生成 Agent
│   ├── services/
│   │   ├── zhihu_api.py       # 知乎 API 调用封装
│   │   └── llm_api.py         # 自有 LLM API 调用封装
│   ├── requirements.txt
│   └── init_db.py             # 数据库初始化
├── frontend/
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   ├── tailwind.config.js
│   └── src/
│       ├── main.jsx
│       ├── App.jsx
│       ├── components/
│       ├── hooks/
│       ├── pages/
│       ├── api/
│       └── utils/
├── api/                       # 知乎 API 文档（已有）
├── examples/                  # 示例脚本（已有）
└── README.md                  # 项目说明
```

---

## 十、并发与队列设计

### 10.1 两类排队场景

系统中有两个需要排队的场景：

1. **世界生成排队**：多个用户同时创建世界，需要排队依次处理（知乎搜索 + LLM 角色生成）
2. **LLM 请求排队**：群聊中的 AI 回复、朋友圈生成、导出等操作都需要调用 LLM，需要控制并发数

### 10.2 世界生成队列

```
用户A 创建"如果秦始皇有微信" ──┐
用户B 创建"如果李白有朋友圈" ──┼──→ 世界生成队列（FIFO）──→ 串行处理
用户C 创建"如果量子力学"   ──┘
```

**实现方案：** 基于 Redis 列表或内存队列的 FIFO 任务队列

```python
# 简化版实现（内存队列，适合小规模并发）
import threading
from queue import Queue
import uuid

world_queue = Queue(maxsize=10)  # 最多排队 10 个
generating = {}  # task_id -> {"status": "queued|processing|done|failed", "world_id": ..., "error": ...}
lock = threading.Lock()

@app.route('/api/worlds/create', methods=['POST'])
def create_world():
    task_id = str(uuid.uuid4())
    with lock:
        world_queue.put(task_id)
        generating[task_id] = {"status": "queued"}

    # 返回 task_id，前端轮询状态
    return jsonify({"task_id": task_id, "status": "queued"})

# 后台消费者线程
def world_consumer():
    while True:
        task_id = world_queue.get()
        with lock:
            generating[task_id]["status"] = "processing"

        try:
            # 1. 知乎搜索获取素材
            # 2. LLM 生成角色
            # 3. 存入数据库
            world_id = build_world(task_data)

            with lock:
                generating[task_id] = {"status": "done", "world_id": world_id}
        except Exception as e:
            with lock:
                generating[task_id] = {"status": "failed", "error": str(e)}

        world_queue.task_done()

# 启动时启动消费者线程
threading.Thread(target=world_consumer, daemon=True).start()

@app.route('/api/worlds/<task_id>/status')
def check_world_status(task_id):
    with lock:
        return jsonify(generating.get(task_id, {"status": "not_found"}))
```

**前端体验：**
- 用户提交创建后，返回 `task_id`，前端进入"排队中"状态
- 前端每 2 秒轮询 `/api/worlds/{task_id}/status`
- 排队时显示："当前有 N 个世界正在生成，你排在第 M 位"
- 完成后自动跳转到角色选择页

**队列容量控制：**
- `maxsize=10`，超过返回 `503 Too Many Requests`
- 队列深度通过 `world_queue.qsize()` 获取

### 10.3 LLM 请求队列（限流 + 排队）

群聊中的 AI 回复、朋友圈生成、导出等操作都需要调用 LLM API，需要控制并发数避免：
- 触发 LLM API 频率限制
- 同时太多请求导致响应慢
- 资源耗尽（内存/CPU）

**实现方案：** 基于 `threading.Semaphore` 的并发控制 + 任务队列

```python
import threading
from queue import Queue, Empty
import json

class LLMWorker:
    def __init__(self, max_concurrent=5):
        self.semaphore = threading.Semaphore(max_concurrent)
        self.result_queue = Queue()  # 存放生成结果
        self.pending_tasks = {}  # task_id -> {"callback": ..., "data": ...}
        self.lock = threading.Lock()

    def submit(self, task_data):
        """提交 LLM 任务，立即返回 task_id"""
        task_id = str(uuid.uuid4())
        event = threading.Event()

        with self.lock:
            self.pending_tasks[task_id] = {
                "data": task_data,
                "event": event,
                "result": None,
                "error": None
            }

        # 将任务放入工作队列
        self.result_queue.put(task_id)
        return task_id

    def wait_result(self, task_id, timeout=30):
        """等待任务完成（SSE 场景下用轮询替代）"""
        with self.lock:
            task = self.pending_tasks.get(task_id)
        if not task:
            return None
        task["event"].wait(timeout=timeout)
        with self.lock:
            return self.pending_tasks.pop(task_id)

    def worker(self):
        """工作线程消费者"""
        while True:
            task_id = self.result_queue.get()

            # 获取并发许可
            self.semaphore.acquire()

            try:
                with self.lock:
                    task = self.pending_tasks[task_id]
                    task_data = task["data"]

                # 调用 LLM API
                result = call_llm_api(task_data)

                with self.lock:
                    task["result"] = result
                    task["event"].set()

                # 通知等待的 SSE 连接
                broadcast_result(task_id, result)

            except Exception as e:
                with self.lock:
                    task["error"] = str(e)
                    task["event"].set()

                broadcast_error(task_id, str(e))

            finally:
                self.semaphore.release()
                self.result_queue.task_done()

# 全局 LLM worker
llm_worker = LLMWorker(max_concurrent=5)

# 启动工作线程
for _ in range(max_concurrent):
    threading.Thread(target=llm_worker.worker, daemon=True).start()

@app.route('/api/worlds/<int:world_id>/messages', methods=['POST'])
def send_message(world_id):
    """用户发送消息"""
    data = request.json
    content = data["content"]

    # 保存用户消息
    msg_id = save_message(world_id, user_character_id, content)

    # 解析 @提及
    mentions = parse_mentions(content)

    results = []
    for char_id in mentions:
        task_id = llm_worker.submit({
            "type": "chat_reply",
            "world_id": world_id,
            "character_id": char_id,
            "context": get_chat_context(world_id),
            "user_message": content
        })
        results.append({"task_id": task_id, "character_id": char_id})

    return jsonify({"msg_id": msg_id, "pending_tasks": results})

@app.route('/api/llm/tasks/<task_id>')
def check_llm_task(task_id):
    """轮询 LLM 任务状态"""
    with llm_worker.lock:
        task = llm_worker.pending_tasks.get(task_id)
    if not task:
        return jsonify({"status": "not_found"})
    if task["event"].is_set():
        return jsonify({
            "status": "done",
            "result": task["result"],
            "error": task["error"]
        })
    return jsonify({"status": "processing"})
```

**并发控制参数：**

| 参数 | 默认值 | 说明 |
|------|:---:|------|
| `max_concurrent` | 5 | 同时最多 5 个 LLM 请求 |
| 超时时间 | 30s | 单个 LLM 请求超时上限 |
| 队列容量 | 50 | 最多排队 50 个任务，超过返回 429 |

### 10.4 SSE + 任务轮询的协同

SSE 负责推送"已完成"的消息，但任务提交时是异步的，前端需要：

```
1. 用户发送消息 → POST /api/worlds/{id}/messages
   → 返回 {msg_id, pending_tasks: [{task_id, character_id}]}

2. 前端立即显示用户消息（is_user=true）
   → 同时显示"秦始皇 正在输入..."（从 pending_tasks 获取）

3. 前端轮询 /api/llm/tasks/{task_id}
   → 返回 done 后，通过 SSE 收到新消息
   → 或前端直接拿到 result 显示（二选一）

4. 如果多个 @，会返回多个 task_id
   → 前端对每个 task_id 独立轮询
   → 每个完成后分别显示
```

**推荐方案：** SSE 推送为主，轮询为辅

- 正常流程：LLM worker 生成结果后 → 存入数据库 → SSE 推送新消息 → 前端自动渲染
- 兜底方案：前端轮询 `/api/llm/tasks/{task_id}` 获取状态，如果 SSE 断开可以恢复

### 10.5 SQLite 并发

- 启用 WAL 模式：`PRAGMA journal_mode=WAL;`
- 写操作串行化（SQLite 天然支持）
- 读操作可并发
- 对于高并发写场景，消息保存加写锁：

```python
db_lock = threading.Lock()

def save_message(world_id, character_id, content):
    with db_lock:
        cursor.execute("INSERT INTO messages ...", (world_id, character_id, content))
        conn.commit()
        return cursor.lastrowid
```

---

## 十一、风险与应对

| 风险 | 影响 | 应对 |
|------|:---:|------|
| AI 角色回复 OOC | 体验差 | 精细 system prompt + 多轮调优 |
| LLM 延迟高（>5s） | 对话不流畅 | 队列 + "正在输入..."动画 + 流式输出 |
| 世界生成排队过长 | 用户流失 | 预置世界不走队列 + 排队进度提示 |
| LLM 并发过高 | API 限频/超时 | Semaphore 限流 + 队列排队 |
| 知乎 API 调用超限 | 无法创建世界 | 缓存已创建世界 + 预置世界不走 API |
| 角色太多（100个） | 聊天混乱 | 默认 5-8 个，用户可调范围 |
