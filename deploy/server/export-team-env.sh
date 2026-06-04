#!/usr/bin/env bash
# ============================================================
# 【服务器管理员用】从本机后端 .env 生成「团队可分发」的 backend.env（内网 IP 版）
#
# 用法：bash deploy/server/export-team-env.sh [服务器IP]
#   默认服务器 IP = 172.21.160.212
#
# 生成的 deploy/team-dev/backend.env 含【真实密钥】，已被 .gitignore 忽略。
# 请通过安全渠道（企业微信/钉钉/U盘，切勿 git 提交）发给队友，
# 让其覆盖到自己的 campus_wall/.env。
# ============================================================
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/campus_wall/.env"
OUT="$ROOT/deploy/team-dev/backend.env"
SERVER_IP="${1:-172.21.160.212}"

[ -f "$SRC" ] || { echo "❌ 找不到 $SRC（请先在服务器上配好后端 .env）"; exit 1; }

# localhost → 服务器 IP；并修正 characterEncoding 与 SSL
sed -E \
  -e "s#//localhost:3306#//$SERVER_IP:3306#g" \
  -e "s#//127.0.0.1:3306#//$SERVER_IP:3306#g" \
  -e "s#^REDIS_HOST=.*#REDIS_HOST=$SERVER_IP#" \
  -e "s#http://localhost:9000#http://$SERVER_IP:9000#g" \
  -e "s#http://localhost:8001#http://$SERVER_IP:8001#g" \
  -e "s#characterEncoding=utf8mb4#characterEncoding=utf8#g" \
  "$SRC" > "$OUT"

echo "✅ 已生成 $OUT"
echo "   服务器 IP = $SERVER_IP"
echo "⚠️  该文件含真实密钥，请通过安全渠道分发，切勿提交 git（已在 .gitignore 中忽略）。"
