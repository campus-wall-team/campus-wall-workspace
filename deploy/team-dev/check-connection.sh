#!/usr/bin/env bash
# ============================================================
# 团队成员自检：能否连到 GB10 中间件服务器
# 用法：bash deploy/team-dev/check-connection.sh [服务器IP]
#   默认服务器 IP = 172.21.160.212
# ============================================================
SERVER="${1:-172.21.160.212}"
echo "检查到中间件服务器 $SERVER 的连通性 ..."
echo ""

bad=0
check_port() {
  if timeout 3 bash -c "echo > /dev/tcp/$SERVER/$1" 2>/dev/null; then
    printf "  \033[32m✓\033[0m %-9s (%s) 端口可达\n" "$2" "$1"
  else
    printf "  \033[31m✗\033[0m %-9s (%s) 不可达\n" "$2" "$1"; bad=$((bad+1))
  fi
}
check_port 3306 "MySQL"
check_port 6379 "Redis"
check_port 9000 "MinIO"
check_port 8001 "GraphRAG"

echo ""
printf "  GraphRAG 健康检查: "
H=$(curl -s --noproxy '*' --max-time 5 "http://$SERVER:8001/health" 2>/dev/null)
[ -n "$H" ] && echo "$H" || { echo "无响应"; bad=$((bad+1)); }

echo ""
if [ "$bad" -eq 0 ]; then
  echo "✅ 全部可达，可以开始后端开发。下一步：把 backend.env.example 配到 campus_wall/.env 并启动后端。"
else
  echo "⚠️  有 $bad 项不可达，依次排查："
  echo "    1) 你和服务器是否在同一局域网（$SERVER 同网段）？"
  echo "    2) 服务器中间件是否在运行？（管理员在服务器执行 docker ps | grep campus-）"
  echo "    3) 服务器 IP 是否变了？（管理员 hostname -I 查看，变了就传新 IP：bash 本脚本 <新IP>）"
fi
