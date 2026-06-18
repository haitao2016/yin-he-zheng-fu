#!/usr/bin/env bash
# 代码健康度检查 - 定时任务入口
# 用法:
#   ./run_code_health.sh                    # 仅生成报告（默认）
#   ./run_code_health.sh --split            # 生成报告并实际拆分大文件
#   ./run_code_health.sh --split-dry-run    # 生成报告并预览拆分计划
# 每小时自动运行一次，输出到 reports/ 目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCAN_DIR="${2:-$PROJECT_ROOT/scripts}"
REPORT_DIR="${PROJECT_ROOT}/reports"
LOG_FILE="${REPORT_DIR}/code_health.log"
LATEST_LINK="${REPORT_DIR}/latest.md"

EXTRA_ARGS="${1:-}"  # --split / --split-dry-run / 空

mkdir -p "${REPORT_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始代码健康度检查 (args: ${EXTRA_ARGS:-默认模式})" | tee -a "${LOG_FILE}"
echo "  扫描目录: ${SCAN_DIR}" | tee -a "${LOG_FILE}"

# 执行 Python 脚本（总是先默认跑一次生成基础报告）
python3 "${SCRIPT_DIR}/code_health_check.py" \
    --dir "${SCAN_DIR}" \
    ${EXTRA_ARGS} 2>&1 | tee -a "${LOG_FILE}"

# 创建 latest 符号链接，方便查看最新报告
NEW_REPORT=$(ls -t "${REPORT_DIR}"/code_health_*.md 2>/dev/null | head -1)
if [ -n "${NEW_REPORT}" ]; then
    ln -sf "${NEW_REPORT}" "${LATEST_LINK}"
    echo "  最新报告: ${LATEST_LINK} -> ${NEW_REPORT}" | tee -a "${LOG_FILE}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查完成" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"
