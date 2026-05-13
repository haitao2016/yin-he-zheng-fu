#\!/bin/bash
# github_api.sh — GitHub Git Database REST API 交互脚本
# 通过纯 HTTP API 实现游戏项目的远程版本管理，不依赖 git CLI。
#
# 用法:
#   bash github_api.sh check                     # 验证 API 连通性
#   bash github_api.sh sync "提交信息"            # 同步代码到 GitHub
#   bash github_api.sh tag "v1.0.0" "标签说明"    # 创建版本标签
#   bash github_api.sh log [N]                    # 查看最近 N 条提交
#   bash github_api.sh tags                       # 列出所有标签
#   bash github_api.sh init "owner" "repo" "token" [branch]  # 初始化配置

set -euo pipefail

# ── 颜色 ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── 配置文件路径 ──
CONFIG_FILE="/workspace/.project/github-sync.json"
WORKSPACE="/workspace"

# ── 同步白名单（只同步这些目录/文件） ──
SYNC_INCLUDES=(
    "scripts"
    "assets"
    "docs"
)
# 单独包含的文件
SYNC_FILES=(
    ".project/project.json"
)
# 排除模式
SYNC_EXCLUDES=(
    "*.tmp"
    "*.log"
    ".DS_Store"
    "Thumbs.db"
)

# ── 工具函数 ──
log_info()  { echo -e "${GREEN}[GitHub Sync]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[警告]${NC} $*"; }
log_error() { echo -e "${RED}[错误]${NC} $*"; }
log_step()  { echo -e "${CYAN}  →${NC} $*"; }

# 读取配置
load_config() {
    if [ \! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        echo "请先运行: bash $0 init <owner> <repo> <token> [branch]"
        exit 1
    fi

    OWNER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['owner'])")
    REPO=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['repo'])")
    TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['token'])")
    BRANCH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('branch', 'main'))")
    PROXY=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('proxy', 'http://127.0.0.1:1080'))")

    API_BASE="https://api.github.com/repos/${OWNER}/${REPO}"
}

# GitHub API 请求
gh_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local url
    if [[ "$endpoint" == https://* ]]; then
        url="$endpoint"
    else
        url="${API_BASE}${endpoint}"
    fi

    local curl_args=(
        -s -S
        -X "$method"
        -H "Authorization: Bearer ${TOKEN}"
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28"
        --proxy "$PROXY"
        --connect-timeout 15
        --max-time 60
    )

    if [ -n "$data" ]; then
        curl_args+=(-H "Content-Type: application/json" -d "$data")
    fi

    curl "${curl_args[@]}" "$url"
}

# ── 命令: init ──
cmd_init() {
    local owner="${1:?用法: init <owner> <repo> <token> [branch]}"
    local repo="${2:?用法: init <owner> <repo> <token> [branch]}"
    local token="${3:?用法: init <owner> <repo> <token> [branch]}"
    local branch="${4:-main}"

    mkdir -p "$(dirname "$CONFIG_FILE")"

    python3 -c "
import json
config = {
    'owner': '$owner',
    'repo': '$repo',
    'token': '$token',
    'branch': '$branch',
    'proxy': 'http://127.0.0.1:1080'
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print('配置已保存到 $CONFIG_FILE')
"

    log_info "配置初始化完成"
    log_step "仓库: ${owner}/${repo}"
    log_step "分支: ${branch}"

    # 自动验证
    cmd_check
}

# ── 命令: check ──
cmd_check() {
    load_config
    log_info "验证 API 连通性..."
    log_step "仓库: ${OWNER}/${REPO}"

    local response
    response=$(gh_api GET "" 2>&1) || {
        log_error "API 请求失败，请检查代理和网络"
        echo "$response"
        exit 1
    }

    local repo_name
    repo_name=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('full_name',''))" 2>/dev/null) || true

    if [ -n "$repo_name" ]; then
        log_info "连接成功\! 仓库: ${repo_name}"

        # 检查分支是否存在
        local branch_resp
        branch_resp=$(gh_api GET "/git/refs/heads/${BRANCH}" 2>/dev/null) || true
        local branch_sha
        branch_sha=$(echo "$branch_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('object',{}).get('sha',''))" 2>/dev/null) || true

        if [ -n "$branch_sha" ]; then
            log_step "分支 '${BRANCH}' 存在, HEAD: ${branch_sha:0:7}"
        else
            log_warn "分支 '${BRANCH}' 不存在（仓库可能为空，首次 sync 将自动创建）"
        fi
    else
        local msg
        msg=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','未知错误'))" 2>/dev/null) || true
        log_error "验证失败: ${msg}"
        exit 1
    fi
}

# ── 命令: sync ──
cmd_sync() {
    local commit_msg="${1:-auto: 自动同步 $(date '+%Y-%m-%d %H:%M:%S')}"
    load_config

    log_info "开始同步到 ${OWNER}/${REPO}..."

    # 1. 收集要同步的文件
    log_step "收集文件..."
    local files=()
    local file_paths=()

    cd "$WORKSPACE"

    for dir in "${SYNC_INCLUDES[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' file; do
                local skip=false
                for pattern in "${SYNC_EXCLUDES[@]}"; do
                    if [[ "$(basename "$file")" == $pattern ]]; then
                        skip=true
                        break
                    fi
                done
                if [ "$skip" = false ]; then
                    file_paths+=("$file")
                fi
            done < <(find "$dir" -type f -print0 2>/dev/null)
        fi
    done

    for f in "${SYNC_FILES[@]}"; do
        if [ -f "$f" ]; then
            file_paths+=("$f")
        fi
    done

    if [ ${#file_paths[@]} -eq 0 ]; then
        log_warn "没有找到需要同步的文件"
        exit 0
    fi

    log_step "共 ${#file_paths[@]} 个文件"

    # 2. 获取当前分支 HEAD（如果存在）
    local parent_sha=""
    local base_tree_sha=""
    local branch_ref_resp
    branch_ref_resp=$(gh_api GET "/git/refs/heads/${BRANCH}" 2>/dev/null) || true
    parent_sha=$(echo "$branch_ref_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('object',{}).get('sha',''))" 2>/dev/null) || true

    if [ -n "$parent_sha" ]; then
        # 获取父提交的 tree
        local commit_resp
        commit_resp=$(gh_api GET "/git/commits/${parent_sha}")
        base_tree_sha=$(echo "$commit_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['tree']['sha'])" 2>/dev/null) || true
        log_step "基于已有分支 HEAD: ${parent_sha:0:7}"
    else
        log_step "空仓库，将创建初始提交"
    fi

    # 3. 为每个文件创建 Blob
    log_step "上传文件 (Blobs API)..."
    local tree_items="["
    local first=true

    for fpath in "${file_paths[@]}"; do
        local content_b64
        content_b64=$(base64 -w 0 "$fpath")

        local blob_resp
        blob_resp=$(gh_api POST "/git/blobs" "{\"content\":\"${content_b64}\",\"encoding\":\"base64\"}")

        local blob_sha
        blob_sha=$(echo "$blob_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")

        if [ "$first" = true ]; then
            first=false
        else
            tree_items+=","
        fi

        # 判断文件是否可执行
        local mode="100644"
        if [ -x "$fpath" ]; then
            mode="100755"
        fi

        tree_items+="{\"path\":\"${fpath}\",\"mode\":\"${mode}\",\"type\":\"blob\",\"sha\":\"${blob_sha}\"}"
    done
    tree_items+="]"

    # 4. 创建 Tree
    log_step "创建目录树 (Trees API)..."
    local tree_payload
    if [ -n "$base_tree_sha" ]; then
        tree_payload="{\"base_tree\":\"${base_tree_sha}\",\"tree\":${tree_items}}"
    else
        tree_payload="{\"tree\":${tree_items}}"
    fi

    local tree_resp
    tree_resp=$(gh_api POST "/git/trees" "$tree_payload")
    local new_tree_sha
    new_tree_sha=$(echo "$tree_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")

    # 5. 创建 Commit
    log_step "创建提交 (Commits API)..."
    local commit_payload
    if [ -n "$parent_sha" ]; then
        commit_payload="{\"message\":\"${commit_msg}\",\"tree\":\"${new_tree_sha}\",\"parents\":[\"${parent_sha}\"]}"
    else
        commit_payload="{\"message\":\"${commit_msg}\",\"tree\":\"${new_tree_sha}\",\"parents\":[]}"
    fi

    local new_commit_resp
    new_commit_resp=$(gh_api POST "/git/commits" "$commit_payload")
    local new_commit_sha
    new_commit_sha=$(echo "$new_commit_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")

    # 6. 更新/创建分支引用
    log_step "更新分支引用 (References API)..."
    if [ -n "$parent_sha" ]; then
        gh_api PATCH "/git/refs/heads/${BRANCH}" "{\"sha\":\"${new_commit_sha}\"}" > /dev/null
    else
        gh_api POST "/git/refs" "{\"ref\":\"refs/heads/${BRANCH}\",\"sha\":\"${new_commit_sha}\"}" > /dev/null
    fi

    log_info "同步完成\!"
    log_step "提交: ${new_commit_sha:0:7} — ${commit_msg}"
    log_step "文件: ${#file_paths[@]} 个"
    log_step "仓库: https://github.com/${OWNER}/${REPO}/tree/${BRANCH}"
}

# ── 命令: tag ──
cmd_tag() {
    local tag_name="${1:?用法: tag <标签名> [标签说明]}"
    local tag_msg="${2:-Release ${tag_name}}"
    load_config

    log_info "创建标签: ${tag_name}..."

    # 1. 获取当前分支最新 commit
    local ref_resp
    ref_resp=$(gh_api GET "/git/refs/heads/${BRANCH}")
    local commit_sha
    commit_sha=$(echo "$ref_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['object']['sha'])")

    # 2. 创建 annotated tag 对象
    log_step "创建 Tag 对象 (Tags API)..."
    local tag_payload="{\"tag\":\"${tag_name}\",\"message\":\"${tag_msg}\",\"object\":\"${commit_sha}\",\"type\":\"commit\",\"tagger\":{\"name\":\"Maker\",\"email\":\"maker@example.com\",\"date\":\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\"}}"

    local tag_resp
    tag_resp=$(gh_api POST "/git/tags" "$tag_payload")
    local tag_sha
    tag_sha=$(echo "$tag_resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")

    # 3. 创建引用
    log_step "创建引用 (References API)..."
    gh_api POST "/git/refs" "{\"ref\":\"refs/tags/${tag_name}\",\"sha\":\"${tag_sha}\"}" > /dev/null

    log_info "标签创建完成\!"
    log_step "标签: ${tag_name}"
    log_step "提交: ${commit_sha:0:7}"
    log_step "说明: ${tag_msg}"
    log_step "查看: https://github.com/${OWNER}/${REPO}/releases/tag/${tag_name}"
}

# ── 命令: log ──
cmd_log() {
    local count="${1:-5}"
    load_config

    log_info "最近 ${count} 条提交:"
    echo ""

    local resp
    resp=$(gh_api GET "/commits?sha=${BRANCH}&per_page=${count}")

    echo "$resp" | python3 -c "
import sys, json
commits = json.load(sys.stdin)
if isinstance(commits, dict) and 'message' in commits:
    print(f'  错误: {commits[\"message\"]}')
    sys.exit(1)
for c in commits:
    sha = c['sha'][:7]
    msg = c['commit']['message'].split('\n')[0]
    date = c['commit']['author']['date'][:10]
    author = c['commit']['author']['name']
    print(f'  \033[0;36m{sha}\033[0m {msg}')
    print(f'         {date} by {author}')
    print()
"
}

# ── 命令: tags ──
cmd_tags() {
    load_config

    log_info "标签列表:"
    echo ""

    local resp
    resp=$(gh_api GET "/tags?per_page=20")

    echo "$resp" | python3 -c "
import sys, json
tags = json.load(sys.stdin)
if isinstance(tags, dict) and 'message' in tags:
    print(f'  错误: {tags[\"message\"]}')
    sys.exit(1)
if not tags:
    print('  (暂无标签)')
else:
    for t in tags:
        name = t['name']
        sha = t['commit']['sha'][:7]
        print(f'  \033[0;33m{name}\033[0m → {sha}')
"
}

# ── 入口 ──
case "${1:-help}" in
    init)   shift; cmd_init "$@" ;;
    check)  cmd_check ;;
    sync)   shift; cmd_sync "$@" ;;
    tag)    shift; cmd_tag "$@" ;;
    log)    shift; cmd_log "$@" ;;
    tags)   cmd_tags ;;
    help|*)
        echo "GitHub Git Sync — 游戏项目 GitHub 版本管理"
        echo ""
        echo "用法:"
        echo "  bash $0 init <owner> <repo> <token> [branch]  初始化配置"
        echo "  bash $0 check                                 验证连通性"
        echo "  bash $0 sync \"提交信息\"                       同步代码"
        echo "  bash $0 tag \"v1.0.0\" \"标签说明\"               创建版本标签"
        echo "  bash $0 log [N]                               查看最近 N 条提交"
        echo "  bash $0 tags                                  列出标签"
        ;;
esac
