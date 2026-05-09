# GET /openapi/comment/list

获取想法的评论列表或评论的回复列表。

## 接口信息

| 说明 | 值 |
|------|------|
| HTTP URL | `https://openapi.zhihu.com/openapi/comment/list` |
| HTTP Method | GET |

## 请求参数

### Query Parameters

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| content_token | string | 是 | 想法id / 评论id |
| content_type | string | 是 | `pin`（想法）或 `comment`（评论） |
| page_num | int | 否 | 页码，默认：1 |
| page_size | int | 否 | 每页条数，默认：10，最多：50 |

> offset + limit 总数量最多 1000 条

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
    "comments": [
      {
        "comment_id": "11387042978",
        "content": "我也试用了，感觉跟gemini的deep research差不多...",
        "author_name": "javaichiban",
        "author_token": "rockswang",
        "like_count": 8,
        "reply_count": 0,
        "publish_time": 1767772323
      }
    ],
    "has_more": true
  }
}
```

### 失败响应示例

```json
{
  "status": 1,
  "msg": "content_token is required",
  "data": null
}
```

### 顶层字段

| 字段名 | 类型 | 说明 |
|--------|------|------|
| status | int | 状态码，0表示成功，1表示失败 |
| msg | string | 响应消息 |
| data | object | 响应数据 |

### data 字段

| 字段名 | 类型 | 说明 |
|--------|------|------|
| comments | array | 评论列表 |
| has_more | bool | 是否还有更多数据 |

### comments 数组中的对象

| 字段名 | 类型 | 说明 |
|--------|------|------|
| comment_id | string | 评论ID |
| content | string | 评论内容（HTML格式） |
| author_name | string | 作者名称 |
| author_token | string | 作者token |
| like_count | int | 点赞数 |
| reply_count | int | 回复数 |
| reply_to | string | 回复的评论ID（一级评论无此字段） |
| publish_time | int | 发布时间戳 |

## curl 示例

```bash
#!/bin/bash

APP_KEY="your_app_key"
APP_SECRET="your_app_secret"
DOMAIN="https://openapi.zhihu.com"

# 用法:
#   获取想法的一级评论: $0 pin <content_token> [page_num] [page_size]
#   获取评论的二级评论: $0 comment <content_token> [page_num] [page_size]

CONTENT_TYPE="$1"
CONTENT_TOKEN="$2"
PAGE_NUM=${3:-1}
PAGE_SIZE=${4:-10}

TIMESTAMP=$(date +%s)
LOG_ID="test-${TIMESTAMP}"

SIGN_STR="app_key:${APP_KEY}|ts:${TIMESTAMP}|logid:${LOG_ID}|extra_info:"
SIGN=$(echo -n "$SIGN_STR" | openssl dgst -sha256 -hmac "$APP_SECRET" -binary | base64)

QUERY_PARAMS="content_token=${CONTENT_TOKEN}&content_type=${CONTENT_TYPE}&page_num=${PAGE_NUM}&page_size=${PAGE_SIZE}"

curl -s "${DOMAIN}/openapi/comment/list?${QUERY_PARAMS}" \
  -H "X-App-Key: ${APP_KEY}" \
  -H "X-Timestamp: ${TIMESTAMP}" \
  -H "X-Sign: ${SIGN}" \
  -H "X-Log-Id: ${LOG_ID}" \
  -H "X-Extra-Info: "
```
