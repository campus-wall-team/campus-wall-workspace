#!/usr/bin/env bash
# ============================================================================
# campus-wall-ai 一键远程部署：在【B机/开发机】跑，把 AI 代码送到【A机/GB10】重建容器
# ----------------------------------------------------------------------------
# 背景拓扑：AI 服务(campus-wall-ai)以容器常驻 A机(GB10/172.21.160.212)，由
#   campus-wall-ops/docker-compose.yml 的 ai-api + ai-memory-worker 编排，
#   镜像 campus-wall-ai:2.0.0 由 `build: ../campus-wall-ai` 在 A机本地构建。
#   所以"部署" = 把最新代码弄到 A机的仓库目录 + 在 A机重建镜像并滚动重启容器。
#
# 两种把代码送上 A机 的方式：
#   git   (默认, 推荐发布用)：你已在子仓 push、前进根指针 push → A机 git pull 取最新
#   rsync (WIP 调试用)：直接把本机工作树同步到 A机, 不用 commit, 适合还没想提交的草稿
#
# 用法（在 B机 campus-wall 仓根目录跑）：
#   bash deploy/server/deploy-ai.sh             # git 模式(默认)
#   bash deploy/server/deploy-ai.sh rsync       # rsync 模式(同步未提交的本地代码)
#   A_HOST=nvidia@172.21.160.212 bash deploy/server/deploy-ai.sh   # 覆盖 A机地址
#
# 回滚：每次 git 模式部署会把 BEFORE/AFTER SHA 追加到 A机 deploy/server/.ai-deploy-history。
#   ① 临时回滚(仅 A机 立即止血,不动 git 历史)：
#        ssh A机 → cd campus-wall-ai && git checkout <BEFORE_SHA>   # detached HEAD
#        cd ../campus-wall-ops && docker compose build ai-api && \
#          docker compose up -d --no-deps --force-recreate ai-api ai-memory-worker
#        ⚠️ 切勿用 `bash deploy/server/deploy-ai.sh git` 回滚——它会 submodule update --force
#           把子仓重置回根指针锁定的(新)commit，当场撤销你的回滚。
#   ② 正式回滚(让回滚成为稳定状态,守多仓铁律)：在 B机 把子仓 main reset 到旧 SHA 并 push、
#        再回根仓库前进指针 push，然后正常 `deploy-ai.sh git` 部署。
# ============================================================================
set -euo pipefail

# ---- 可覆盖参数 ----
A_HOST="${A_HOST:-nvidia@172.21.160.212}"          # A机 SSH 目标(用户@IP)
A_REPO="${A_REPO:-/home/nvidia/Desktop/campus-wall}" # A机 上 campus-wall 仓库根
OPS_DIR="$A_REPO/campus-wall-ops"                    # ops(compose) 目录
AI_DIR_LOCAL="${AI_DIR_LOCAL:-./campus-wall-ai}"     # B机 本地 AI 子仓路径
SERVICES="ai-api ai-memory-worker"
MODE="${1:-git}"

say() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

[ -d "$AI_DIR_LOCAL" ] || die "找不到本地 AI 子仓 $AI_DIR_LOCAL —— 请在 campus-wall 仓根目录运行本脚本。"

say "目标 A机: $A_HOST   仓库: $A_REPO   模式: $MODE"
ssh -o ConnectTimeout=8 "$A_HOST" 'echo "  SSH OK: $(hostname) / $(hostname -I | awk "{print \$1}")"' \
  || die "SSH 连不上 A机。检查：① 是否在内网/关了梯子(NO_PROXY)；② ssh 公钥已加到 A机；③ A_HOST 是否正确。"

# ---- 1) 把代码送上 A机 ----
case "$MODE" in
  git)
    # 守多仓铁律：git 模式部署的是【根仓库锁定的 submodule 指针】，故下面 4 道闸全过才放行
    #  ① 子仓工作树/暂存区/未跟踪文件全干净(porcelain 三类全报告，diff --quiet 漏检 untracked)
    if [ -n "$(git -C "$AI_DIR_LOCAL" status --porcelain)" ]; then
      die "本地 campus-wall-ai 有未提交/未跟踪改动。git 模式只部署已 push 的代码；要部署草稿请用：bash deploy/server/deploy-ai.sh rsync"
    fi
    #  ② 子仓 HEAD 已 push(否则 A机 fetch 不到)
    if [ -n "$(git -C "$AI_DIR_LOCAL" log @{u}..HEAD --oneline 2>/dev/null)" ]; then
      die "本地 campus-wall-ai 有已 commit 未 push 的提交。请先在子仓 push 到 main 再部署。"
    fi
    #  ③ 根仓库锁定的指针 == 子仓 HEAD(即你已『前进指针』，否则 A机会部署旧的锁定版本)
    SUB_HEAD="$(git -C "$AI_DIR_LOCAL" rev-parse HEAD)"
    ROOT_PIN="$(git rev-parse "HEAD:$(basename "$AI_DIR_LOCAL")" 2>/dev/null || echo '')"
    if [ "$SUB_HEAD" != "$ROOT_PIN" ]; then
      die "根指针($ROOT_PIN) ≠ campus-wall-ai HEAD($SUB_HEAD)。请先前进根指针：git add $(basename "$AI_DIR_LOCAL") && git commit && git push"
    fi
    #  ④ 根仓库 HEAD 已 push(否则 A机 git pull 取不到新指针)
    if [ -n "$(git log @{u}..HEAD --oneline 2>/dev/null)" ]; then
      die "根仓库有未 push 的提交(可能是刚前进的指针)。请先 git push 再部署。"
    fi
    say "A机 按根仓库锁定的 submodule 指针取代码(git pull + submodule update --force)"
    ssh "$A_HOST" "set -e
      cd '$A_REPO'
      BEFORE=\$(git -C campus-wall-ai rev-parse --short HEAD); echo \"  BEFORE_SHA(ai)=\$BEFORE\"
      git pull --ff-only                                   # 前进根仓库 + 更新 gitlink 指针
      git -C campus-wall-ai fetch origin --quiet           # 确保锁定的 commit 已在本地
      git submodule update --init --force campus-wall-ai   # 检出到根指针锁定的 commit(顺带清掉 rsync 残留)
      AFTER=\$(git -C campus-wall-ai rev-parse --short HEAD); echo \"  AFTER_SHA(ai) =\$AFTER\"
      printf '%s mode=git BEFORE=%s AFTER=%s\n' \"\$(date -Is)\" \"\$BEFORE\" \"\$AFTER\" >> '$A_REPO/deploy/server/.ai-deploy-history'"
    ;;
  rsync)
    say "rsync 本地 AI 工作树 → A机(排除 .git/缓存/.env/sqlite/venv)"
    rsync -az --delete \
      --exclude '.git' --exclude '__pycache__' --exclude '*.pyc' --exclude '.pytest_cache' \
      --exclude '.env' --exclude '.env.*' --exclude '*.db' --exclude '.venv' --exclude 'node_modules' \
      "$AI_DIR_LOCAL"/ "$A_HOST:$A_REPO/campus-wall-ai/"
    ssh "$A_HOST" "printf '%s mode=rsync from=%s\n' \"\$(date -Is)\" \"\$(hostname)\" >> '$A_REPO/deploy/server/.ai-deploy-history'" || true
    ;;
  *) die "未知模式 '$MODE'，只支持 git | rsync";;
esac

# ---- 2) A机 重建镜像 + 滚动重启容器（不动数据卷/不动依赖中间件）----
say "A机 docker compose 重建并重启：$SERVICES"
ssh "$A_HOST" "set -e
  cd '$OPS_DIR'
  docker compose build ai-api
  docker compose up -d --no-deps --force-recreate $SERVICES
  docker compose ps $SERVICES"

# ---- 3) 健康检查 ----
say "健康检查 A机 :8011/health"
ssh "$A_HOST" "curl -fsS --max-time 10 http://localhost:8011/health && echo" \
  && printf '\n\033[1;32m✔ AI 服务部署完成并健康。\033[0m\n' \
  || { ssh "$A_HOST" "docker logs --tail 60 campus-wall-ai"; die "健康检查失败，已打印日志。可回滚到 BEFORE_SHA。"; }
