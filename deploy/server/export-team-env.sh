#!/usr/bin/env bash
# ============================================================
# 【服务器管理员用】生成「团队可分发」的后端本地配置 application-local.yaml（内网 IP + 真实密码）
#
# 用法：bash deploy/server/export-team-env.sh [B机IP] [GB10_IP]
#   [B机IP]   可选：该队友 B 机的局域网 IP，用于填 app.base-url（不填则留占位，队友自己改一行）
#   [GB10_IP] 可选：中间件服务器 IP，默认 172.21.160.212
#
# 生成的 deploy/team-dev/application-local.yaml 含【真实密钥】，已被 .gitignore 忽略。
# 请通过安全渠道（企业微信/钉钉/U盘，切勿 git 提交）发给队友，
# 让其放到自己的 campus_wall/application-local.yaml，然后在 campus_wall/ 目录启动后端即可。
#
# 密码来源：campus-wall-ops/.env（中间件统一口令的权威来源）。
# ============================================================
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS_ENV="$ROOT/campus-wall-ops/.env"
OUT="$ROOT/deploy/team-dev/application-local.yaml"
B_IP="${1:-}"
SERVER_IP="${2:-${SERVER_IP:-172.21.160.212}}"

[ -f "$OPS_ENV" ] || { echo "❌ 找不到 $OPS_ENV（请在 GB10 中间件服务器上运行本脚本）"; exit 1; }

# 从 ops/.env 取值
getenv() { grep -E "^$1=" "$OPS_ENV" | head -1 | cut -d= -f2-; }
# YAML 单引号转义（把 ' 变成 ''），整体用单引号包裹，避免 @ : 等特殊字符歧义
yq() { printf "'%s'" "${1//\'/\'\'}"; }

MYSQL_PW="$(getenv MYSQL_ROOT_PASSWORD)"
REDIS_PW="$(getenv REDIS_PASSWORD)"
MINIO_SK="$(getenv MINIO_SECRET_KEY)"

[ -n "$MYSQL_PW" ] || echo "⚠️  未从 ops/.env 读到 MYSQL_ROOT_PASSWORD，请检查。"

if [ -n "$B_IP" ]; then
  APP_BASE="http://$B_IP:8080"
else
  APP_BASE="http://<改成你这台B机的IP>:8080"
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<YAML
# ============================================================
# 由 deploy/server/export-team-env.sh 自动生成（含真实密钥，勿提交 git）
# 放到 campus_wall/application-local.yaml，在 campus_wall/ 目录启动后端即可：
#   java -jar target/campus-wall-0.0.1-SNAPSHOT.jar --spring.profiles.active=dev
# 中间件服务器 IP：$SERVER_IP
# ============================================================
spring:
  datasource:
    url: jdbc:mysql://$SERVER_IP:3306/campus_wall?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true
    username: root
    password: $(yq "$MYSQL_PW")
  data:
    redis:
      host: $SERVER_IP
      port: 6379
      password: $(yq "$REDIS_PW")
      database: 0
minio:
  endpoint: http://$SERVER_IP:9000
  access-key: root
  secret-key: $(yq "$MINIO_SK")
  bucket-name: campus-wall
graphrag:
  base-url: http://$SERVER_IP:8011
app:
  base-url: $APP_BASE
YAML

echo "✅ 已生成 $OUT"
echo "   中间件服务器 IP = $SERVER_IP"
if [ -n "$B_IP" ]; then
  echo "   已填 app.base-url = $APP_BASE"
else
  echo "   ⚠️  app.base-url 留了占位，队友收到后需把 <改成你这台B机的IP> 改成自己 B 机 IP（也可重跑本脚本传入 B 机 IP 一键填好）。"
fi
echo "⚠️  该文件含真实密钥，请通过安全渠道分发，切勿提交 git（已在 .gitignore 中忽略）。"
