# GET /openapi/hackathon_story/detail

根据作品 ID 获取会员小说的章节详情，包括章节名称、作者信息、导语和正文内容。

## 接口信息

| 说明 | 值 |
|------|------|
| HTTP URL | `https://openapi.zhihu.com/openapi/hackathon_story/detail` |
| HTTP Method | GET |
| 鉴权 | 需要签名鉴权（见 [README](../README.md#鉴权说明)） |

## 请求参数

### Query Parameters

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| work_id | int64 | 是 | 内容库中的作品 ID，如 `1644038836790169600` |

### 请求头

| 请求头 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| X-App-Key | string | 是 | 应用标识 |
| X-Timestamp | string | 是 | 当前时间戳（秒级） |
| X-Log-Id | string | 是 | 请求日志 ID |
| X-Sign | string | 是 | 签名 |
| X-Extra-Info | string | 是 | 额外信息，可为空 |

## 响应数据

### 成功响应示例

```json
{
  "status": 0,
  "msg": "success",
  "data": {
    "work_id": "1644038836790169600",
    "chapter_name": "第一章",
    "author_avatar": "https://picx.zhimg.com/v2-0efdb326ae699d43ea7abc895f7608b5.jpg",
    "author_name": "六酒",
    "labels": ["科幻", "脑洞", "穿越", "爽文", "历史"],
    "introduction": "导语文本",
    "content": "第一段正文\n第二段正文"
  }
}
```

### 失败响应示例

```json
{
  "status": 1,
  "msg": "story not found",
  "data": null
}
```

```json
{
  "status": 1,
  "msg": "work_id is required",
  "data": null
}
```

### 顶层字段

| 字段名 | 类型 | 说明 |
|--------|------|------|
| status | int | 状态码，0 表示成功，1 表示失败 |
| msg | string | 响应消息 |
| data | object | 响应数据 |

### data 字段

| 字段名 | 类型 | 说明 |
|--------|------|------|
| work_id | string | 作品 ID |
| chapter_name | string | 章节名称 |
| author_avatar | string | 作者头像 URL |
| author_name | string | 作者姓名 |
| labels | array[string] | 内容标签 |
| introduction | string | 导语 |
| content | string | 正文内容，保留段落换行，最多返回 3000 字 |

### 错误说明

| 场景 | 处理 |
|------|------|
| work_id 不在固定内容库中 | 返回 `story not found` |
| 内容服务查询失败 | 透传下游错误 |
| 作品或小节资源缺失 | 返回 `story not found` |

## curl 示例

```bash
#!/bin/bash

APP_KEY="your_app_key"
APP_SECRET="your_app_secret"
DOMAIN="https://openapi.zhihu.com"
WORK_ID="1644038836790169600"

TIMESTAMP=$(date +%s)
LOG_ID="test-${TIMESTAMP}"

SIGN_STR="app_key:${APP_KEY}|ts:${TIMESTAMP}|logid:${LOG_ID}|extra_info:"
SIGN=$(echo -n "$SIGN_STR" | openssl dgst -sha256 -hmac "$APP_SECRET" -binary | base64)

curl -s "${DOMAIN}/openapi/hackathon_story/detail?work_id=${WORK_ID}" \
  -H "X-App-Key: ${APP_KEY}" \
  -H "X-Timestamp: ${TIMESTAMP}" \
  -H "X-Sign: ${SIGN}" \
  -H "X-Log-Id: ${LOG_ID}" \
  -H "X-Extra-Info: "
```
