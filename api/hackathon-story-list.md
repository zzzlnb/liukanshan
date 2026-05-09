# GET /openapi/hackathon_story/list

获取会员小说开放内容库的故事概要列表，返回顺序与内容库固定表顺序一致。

> 特对2026年黑客松活动特殊开放。

## 接口信息

| 说明 | 值 |
|------|------|
| HTTP URL | `https://openapi.zhihu.com/openapi/hackathon_story/list` |
| HTTP Method | GET |
| 鉴权 | 需要签名鉴权（见 [README](../README.md#鉴权说明)） |

## 请求参数

无请求参数。

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
  "data": [
    {
      "work_id": "1644038836790169600",
      "title": "秦始皇登月计划",
      "artwork": "https://picx.zhimg.com/v2-94b785c4dfea061b9673cdd2c3dfd81a.jpg",
      "tab_artwork": "https://picx.zhimg.com/v2-6f4055c2f245914940b0a03e07a4ccef.jpg",
      "description": "一觉醒来，我自带系统穿越到秦始皇身边...",
      "labels": ["科幻", "脑洞", "穿越", "爽文", "历史"]
    },
    {
      "work_id": "1487746545537290240",
      "title": "人脸解锁失败",
      "artwork": "https://pica.zhimg.com/v2-c43076796bc5c70d07a02986764acfe0.jpg",
      "tab_artwork": "https://pic1.zhimg.com/v2-14879d7176f411cf0e8f4b4e28e66fad.jpg",
      "description": "「人脸解锁失败。」凌晨三点...",
      "labels": ["悬疑", "惊悚", "犯罪", "无限流", "现代"]
    }
  ]
}
```

### 失败响应示例

```json
{
  "status": 1,
  "msg": "failed to get story list",
  "data": null
}
```

### 顶层字段

| 字段名 | 类型 | 说明 |
|--------|------|------|
| status | int | 状态码，0 表示成功，1 表示失败 |
| msg | string | 响应消息 |
| data | array | 故事概要列表 |

### data 数组中的对象

| 字段名 | 类型 | 说明 |
|--------|------|------|
| work_id | string | 作品 ID，用于详情接口入参 |
| title | string | 作品名称 |
| artwork | string | 横版封面图 URL |
| tab_artwork | string | 竖版封面图 URL |
| description | string | 作品简介 |
| labels | array[string] | 内容标签 |

## curl 示例

```bash
#!/bin/bash

APP_KEY="your_app_key"
APP_SECRET="your_app_secret"
DOMAIN="https://openapi.zhihu.com"

TIMESTAMP=$(date +%s)
LOG_ID="test-${TIMESTAMP}"

SIGN_STR="app_key:${APP_KEY}|ts:${TIMESTAMP}|logid:${LOG_ID}|extra_info:"
SIGN=$(echo -n "$SIGN_STR" | openssl dgst -sha256 -hmac "$APP_SECRET" -binary | base64)

curl -s "${DOMAIN}/openapi/hackathon_story/list" \
  -H "X-App-Key: ${APP_KEY}" \
  -H "X-Timestamp: ${TIMESTAMP}" \
  -H "X-Sign: ${SIGN}" \
  -H "X-Log-Id: ${LOG_ID}" \
  -H "X-Extra-Info: "
```
