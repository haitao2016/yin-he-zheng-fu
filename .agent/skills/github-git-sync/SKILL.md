---
name: github-git-sync
description: >
  通过 GitHub Git Database REST API 实现游戏项目的远程版本管理与发布。
  Use when:
  (1) 用户说"同步到GitHub"、"推送到GitHub"、"备份到GitHub"、"上传GitHub",
  (2) 用户说"创建版本"、"打tag"、"发布版本"、"release",
  (3) 用户要求配置 GitHub 远程仓库、设置 GitHub Token,
  (4) 用户提供了 GitHub Token 或仓库地址要求配置,
  (5) 用户需要查看 GitHub 仓库的提交历史、分支、标签,
  (6) 用户说 /github-git-sync 或 /github-save,
  (7) 用户需要通过 API 方式（非 git CLI）与 GitHub 仓库交互。
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  tags: [git, github, version-control, backup, release, api]
---

# GitHub Git Sync — 游戏项目 GitHub 版本管理

通过 GitHub Git Database REST API，在沙箱环境中实现游戏代码的远程备份、版本标签和发布管理。**不依赖 git CLI**，纯 HTTP API 驱动。

## 适用场景

| 场景 | 操作 |
|------|------|
| 用户说"同步/推送/备份到 GitHub" | 执行 Sync 流程 |
| 用户说"创建版本/打 tag/发布" | 执行 Tag 流程 |
| 用户提供 GitHub Token + 仓库信息 | 执行初始化配置 |
| 用户想查看远程提交历史 | 执行 Query 流程 |

## SKIP 条件

- 用户使用阿里云效 Codeup → 转交 `@org_git-save` skill
- 用户只需本地 git 操作（commit、diff）→ 直接用 bash git 命令
- 用户说"保存代码"但未提及 GitHub → 优先询问目标平台

## 前置条件

用户需提供：
1. **GitHub Personal Access Token (PAT)**：需具有 `repo` 权限
2. **目标仓库**：`owner/repo` 格式（如 `myname/my-game`）

Token 获取方式：GitHub → Settings → Developer settings → Personal access tokens → Generate new token → 勾选 `repo` 权限。

## 工作流程

```
初始化(仅首次)              日常开发
───────────                ──────────
1. 获取用户 Token + 仓库    1. 开发完成后: github sync
2. 写入本地配置文件          2. 里程碑版本: github tag v1.0
3. 验证 API 连通性          3. 查看历史: github log
```

### Step 1: 初始化配置

收到 Token 和仓库信息后，将配置写入 `.project/github-sync.json`：

```json
{
  "owner": "username",
  "repo": "my-game",
  "token": "ghp_xxxxxxxxxxxx",
  "branch": "main",
  "proxy": "http://127.0.0.1:1080"
}
```

> **安全规则**：Token 仅存储在 `.project/` 内（已被 .gitignore 排除），不会泄露到代码仓库。

验证连通性：

```bash
bash /workspace/.agent/skills/github-git-sync/scripts/github_api.sh check
```

### Step 2: 同步代码（Sync）

将 `scripts/` 和 `assets/` 目录的内容推送到 GitHub 仓库：

```bash
bash /workspace/.agent/skills/github-git-sync/scripts/github_api.sh sync "feat: 新增背包系统"
```

**内部流程**（基于 GitHub Git Database API）：
1. 遍历需同步的文件，调用 Blobs API 创建文件对象
2. 调用 Trees API 组装目录结构
3. 调用 Commits API 创建提交（自动挂载到当前分支最新 commit）
4. 调用 References API 更新分支指针

**同步范围**（仅同步用户代码，排除引擎目录）：

| 包含 | 排除 |
|------|------|
| `scripts/` | `engine-docs/`, `examples/`, `templates/` |
| `assets/` | `urhox-libs/`, `.emmylua/`, `schemas/` |
| `docs/`（如果存在） | `dist/`, `.build/`, `.tmp/`, `logs/` |
| `.project/project.json` | `.project/github-sync.json`（含 Token） |

### Step 3: 创建版本标签（Tag）

```bash
bash /workspace/.agent/skills/github-git-sync/scripts/github_api.sh tag "v1.0.0" "首个可玩版本"
```

**内部流程**：
1. 获取当前分支最新 commit SHA
2. 调用 Tags API 创建 annotated tag 对象
3. 调用 References API 创建 `refs/tags/v1.0.0` 引用

### Step 4: 查看历史（Log）

```bash
bash /workspace/.agent/skills/github-git-sync/scripts/github_api.sh log 5
```

返回最近 N 条提交记录（默认 5 条），包含 SHA、消息、时间、作者。

### Step 5: 查看标签列表（Tags）

```bash
bash /workspace/.agent/skills/github-git-sync/scripts/github_api.sh tags
```

## 提交信息规范

| 时机 | 前缀 | 示例 |
|------|------|------|
| 开发前快照 | `backup:` | `backup: V0.5 开发前备份` |
| 新功能完成 | `feat:` | `feat: 新增角色选择界面` |
| 修复 BUG | `fix:` | `fix: 修复碰撞检测偶发失败` |
| 优化/重构 | `refactor:` | `refactor: 拆分主文件为模块` |
| 资源更新 | `assets:` | `assets: 添加新角色贴图` |

## 注意事项

1. **沙箱代理**：所有 API 请求通过 `http://127.0.0.1:1080` 代理发出
2. **文件大小限制**：单个文件不超过 100MB（GitHub API 限制），大型资源建议使用外部存储
3. **速率限制**：GitHub API 每小时 5000 次请求（含 Token），单次同步消耗约 N*2+3 次（N=文件数）
4. **与 @org_git-save 共存**：本 Skill 使用 HTTP API，不影响本地 git 仓库；两个 Skill 可同时使用
5. **仅同步用户代码**：引擎内部目录（engine-docs、urhox-libs 等）绝不同步，符合安全规则
6. **Token 安全**：配置文件位于 `.project/`，该目录不参与代码同步

## API 参考

详细的 GitHub Git Database API 端点说明见 [references/github-api-reference.md](references/github-api-reference.md)。
