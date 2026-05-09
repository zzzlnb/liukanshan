#!/bin/bash
#
# Zhihu Community API Authentication Helper
#
# Generates HMAC-SHA256 signatures and common headers for API requests.
#
# Usage:
#   source auth.sh
#   set_auth
#   curl "${DOMAIN}/openapi/ring/detail?ring_id=..." \
#     -H "X-App-Key: ${APP_KEY}" \
#     -H "X-Timestamp: ${AUTH_TIMESTAMP}" \
#     -H "X-Log-Id: ${AUTH_LOG_ID}" \
#     -H "X-Sign: ${AUTH_SIGN}" \
#     -H "X-Extra-Info: ${AUTH_EXTRA_INFO}"
#

# Configuration - set these before sourcing
APP_KEY="${APP_KEY:-}"        # Zhihu user token
APP_SECRET="${APP_SECRET:-}"  # App secret
DOMAIN="https://openapi.zhihu.com"
AUTH_EXTRA_INFO="${AUTH_EXTRA_INFO:-}"

# generate_auth - generates timestamp, log_id, and signature
# Sets AUTH_TIMESTAMP, AUTH_LOG_ID, AUTH_SIGN, AUTH_EXTRA_INFO
generate_auth() {
    AUTH_TIMESTAMP=$(date +%s)
    AUTH_LOG_ID="req_$(date +%s%N | md5sum | cut -c1-16)"
    AUTH_EXTRA_INFO="${AUTH_EXTRA_INFO:-}"

    local sign_str="app_key:${APP_KEY}|ts:${AUTH_TIMESTAMP}|logid:${AUTH_LOG_ID}|extra_info:${AUTH_EXTRA_INFO}"
    AUTH_SIGN=$(echo -n "$sign_str" | openssl dgst -sha256 -hmac "$APP_SECRET" -binary | base64)
}

# api_get - make a GET request with auth headers
# Usage: api_get <path> [query_string]
api_get() {
    local path="$1"
    local query="$2"
    local url="${DOMAIN}${path}"

    if [ -n "$query" ]; then
        url="${url}?${query}"
    fi

    generate_auth

    curl -s "${url}" \
      -H "X-App-Key: ${APP_KEY}" \
      -H "X-Timestamp: ${AUTH_TIMESTAMP}" \
      -H "X-Log-Id: ${AUTH_LOG_ID}" \
      -H "X-Sign: ${AUTH_SIGN}" \
      -H "X-Extra-Info: ${AUTH_EXTRA_INFO}"
}
