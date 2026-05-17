#!/usr/bin/env bash
# ============================================================================
# 开发计划自动保存脚本
# 用法:
#   bash docs/plans/auto_save_plan.sh                      # 自动检测最新计划并提交
#   bash docs/plans/auto_save_plan.sh "feat: 完成 P1-1"   # 自定义 commit message
#   bash docs/plans/auto_save_plan.sh --status             # 只查看计划状态，不提交
# ============================================================================

set -e

PLANS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$PLANS_DIR/../.." && pwd)"
INDEX_FILE="$PLANS_DIR/index.md"

# ── 颜色输出 ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[plan]${NC} $*"; }
success() { echo -e "${GREEN}[plan]${NC} $*"; }
warn()    { echo -e "${YELLOW}[plan]${NC} $*"; }
error()   { echo -e "${RED}[plan]${NC} $*"; exit 1; }

# ── 查看状态模式 ──────────────────────────────────────────────────────────────
if [[ "$1" == "--status" ]]; then
    echo -e "${BOLD}═══ 开发计划状态 ═══${NC}"
    if [[ -f "$INDEX_FILE" ]]; then
        cat "$INDEX_FILE"
    else
        warn "index.md 不存在"
    fi
    echo ""
    echo -e "${BOLD}═══ 最新计划文件 ═══${NC}"
    LATEST=$(ls -t "$PLANS_DIR"/*.plan.md 2>/dev/null | head -1)
    if [[ -n "$LATEST" ]]; then
        echo -e "${CYAN}文件:${NC} $(basename "$LATEST")"
        # 提取状态行
        STATUS_LINE=$(grep "^> 状态:" "$LATEST" 2>/dev/null || echo "状态未知")
        echo -e "${CYAN}状态:${NC} $STATUS_LINE"
        # 统计任务完成情况
        TOTAL=$(grep -c "^| .[⬜✅❌]." "$LATEST" 2>/dev/null || echo 0)
        DONE=$(grep -c "^| .✅." "$LATEST" 2>/dev/null || echo 0)
        echo -e "${CYAN}进度:${NC} $DONE / $TOTAL 任务完成"
    else
        warn "未找到任何 .plan.md 文件"
    fi
    exit 0
fi

# ── 找到最新计划文件 ──────────────────────────────────────────────────────────
LATEST_PLAN=$(ls -t "$PLANS_DIR"/*.plan.md 2>/dev/null | head -1)
if [[ -z "$LATEST_PLAN" ]]; then
    error "未找到任何 .plan.md 文件，请先创建计划"
fi

PLAN_NAME=$(basename "$LATEST_PLAN" .plan.md)
info "检测到最新计划: ${BOLD}$PLAN_NAME${NC}"

# ── 提取当前计划状态 ──────────────────────────────────────────────────────────
PLAN_STATUS=$(grep "^> 状态:" "$LATEST_PLAN" 2>/dev/null | sed 's/^> 状态: //' || echo "未知")
TOTAL_TASKS=$(grep -c "^| .[⬜✅❌]." "$LATEST_PLAN" 2>/dev/null || echo 0)
DONE_TASKS=$(grep -c "^| .✅." "$LATEST_PLAN" 2>/dev/null || echo 0)

info "计划状态: $PLAN_STATUS"
info "任务进度: $DONE_TASKS / $TOTAL_TASKS"

# ── 生成备份（仅当状态为"已完成"时归档）────────────────────────────────────────
if echo "$PLAN_STATUS" | grep -q "已完成"; then
    ARCHIVE_DIR="$PLANS_DIR/archive"
    mkdir -p "$ARCHIVE_DIR"
    ARCHIVE_FILE="$ARCHIVE_DIR/${PLAN_NAME}.v_$(date +%Y%m%d_%H%M%S).plan.md"
    cp "$LATEST_PLAN" "$ARCHIVE_FILE"
    success "已归档到: $(basename "$ARCHIVE_FILE")"
fi

# ── 进入 git 根目录 ───────────────────────────────────────────────────────────
cd "$ROOT_DIR"

# 检查是否为 git 仓库
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "当前目录不是 git 仓库: $ROOT_DIR"
fi

# ── 暂存计划相关文件 ──────────────────────────────────────────────────────────
info "暂存计划文件..."
git add docs/plans/ 2>/dev/null || warn "docs/plans/ 暂存失败，可能无变更"

# 检查是否有变更
if git diff --cached --quiet; then
    warn "计划文件无变更，跳过提交"
    exit 0
fi

# ── 生成 commit message ───────────────────────────────────────────────────────
if [[ -n "$1" && "$1" != "--"* ]]; then
    COMMIT_MSG="$1"
else
    # 自动生成
    if echo "$PLAN_STATUS" | grep -q "已完成"; then
        COMMIT_MSG="docs(plan): 结项归档 ${PLAN_NAME} [${DONE_TASKS}/${TOTAL_TASKS}]"
    elif [[ "$DONE_TASKS" -gt 0 ]]; then
        COMMIT_MSG="docs(plan): 更新 ${PLAN_NAME} 进度 [${DONE_TASKS}/${TOTAL_TASKS}]"
    else
        COMMIT_MSG="docs(plan): 新建开发计划 ${PLAN_NAME}"
    fi
fi

# ── 提交 ──────────────────────────────────────────────────────────────────────
git commit -m "$COMMIT_MSG"
success "已提交: $COMMIT_MSG"

# ── 推送（可选，检测是否配置了 remote）───────────────────────────────────────
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -n "$REMOTE_URL" ]]; then
    info "推送到远程仓库..."
    if git push origin HEAD 2>&1; then
        success "推送成功 → $REMOTE_URL"
    else
        warn "推送失败，已本地提交。请手动执行: git push origin HEAD"
    fi
else
    warn "未配置远程仓库，已本地提交"
fi

echo ""
success "✓ 计划保存完成: ${BOLD}$PLAN_NAME${NC}"
