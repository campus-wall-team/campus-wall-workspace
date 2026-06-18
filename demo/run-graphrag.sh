#!/usr/bin/env bash
# 本地运行 campus-wall-ai（原 graphrag 已并入；chat=本机 Ollama qwen2.5:7b，
# embedding=本机 Ollama bge-m3，Neo4j=已有 campus-neo4j 容器）。离线、零成本、不碰云端 key。
# 首次需建 venv：cd campus-wall-ai && python -m venv .venv && .venv/bin/pip install -r requirements.txt
#
# 用法：
#   cp demo/.env.example demo/.env     # 首次：填入真实 NEO4J_PASSWORD
#   bash demo/run-graphrag.sh          # 启动服务（前台），监听 :8011
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$(cd "$SCRIPT_DIR/../campus-wall-ai" && pwd)"

# 本地密钥（NEO4J_PASSWORD 等）从 demo/.env 读取；该文件已被 .gitignore 忽略，不入库。
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

# 机器全局设了 socks 代理（ALL_PROXY=socks://...），httpx 不支持会崩溃；
# graphrag 只连本地服务，清掉所有代理变量。
unset ALL_PROXY all_proxy HTTP_PROXY http_proxy HTTPS_PROXY https_proxy
export NO_PROXY=localhost,127.0.0.1
export no_proxy=localhost,127.0.0.1

export NEO4J_URI="${NEO4J_URI:-bolt://localhost:7688}"
export NEO4J_USER="${NEO4J_USER:-neo4j}"
: "${NEO4J_PASSWORD:?未设置 NEO4J_PASSWORD：请 cp demo/.env.example demo/.env 并填入真实密码}"
export NEO4J_PASSWORD

# Chat：本机 Ollama 本地大模型（离线、零成本、不碰泄露 key）
export CHAT_BASE_URL="${CHAT_BASE_URL:-http://localhost:11434/v1}"
export CHAT_API_KEY="${CHAT_API_KEY:-ollama}"
export CHAT_MODEL="${CHAT_MODEL:-qwen2.5:7b}"

# Embedding：本机 Ollama bge-m3（1024 维）
export EMBED_BASE_URL="${EMBED_BASE_URL:-http://localhost:11434/v1}"
export EMBED_API_KEY="${EMBED_API_KEY:-ollama}"
export EMBED_MODEL="${EMBED_MODEL:-bge-m3}"
export EMBED_DIM="${EMBED_DIM:-1024}"

export AI_SERVICE_PORT="${AI_SERVICE_PORT:-8011}"
export VECTOR_INDEX_NAME="${VECTOR_INDEX_NAME:-campus_chunk_vector}"

cd "$AI_DIR"
exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port "$AI_SERVICE_PORT"
