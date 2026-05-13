# GitHub Git Database REST API 参考

本文档描述本 Skill 使用的 GitHub Git Database API 端点。所有请求需携带 `Authorization: Bearer <token>` 头。

> 官方文档: https://docs.github.com/en/rest/git

## 1. Blobs（文件对象）

存储单个文件的内容，返回 SHA-1 哈希。

### 创建 Blob

```
POST /repos/{owner}/{repo}/git/blobs
```

**请求体**:
```json
{
  "content": "<base64编码的文件内容>",
  "encoding": "base64"
}
```

**响应** (201):
```json
{
  "sha": "abc123...",
  "url": "https://api.github.com/repos/{owner}/{repo}/git/blobs/abc123..."
}
```

**说明**: encoding 支持 `"utf-8"` (文本) 和 `"base64"` (二进制)。游戏资源（图片、音频）必须用 base64。

---

## 2. Trees（目录结构）

定义文件和目录的层次关系，类似文件系统的目录树。

### 创建 Tree

```
POST /repos/{owner}/{repo}/git/trees
```

**请求体**:
```json
{
  "base_tree": "<可选: 父 tree 的 SHA，增量更新时使用>",
  "tree": [
    {
      "path": "scripts/main.lua",
      "mode": "100644",
      "type": "blob",
      "sha": "<blob SHA>"
    },
    {
      "path": "scripts/utils.lua",
      "mode": "100644",
      "type": "blob",
      "sha": "<blob SHA>"
    }
  ]
}
```

**mode 值**:
| mode | 含义 |
|------|------|
| `100644` | 普通文件 |
| `100755` | 可执行文件 |
| `040000` | 子目录 |
| `120000` | 符号链接 |
| `160000` | Git 子模块 |

**关键**: 提供 `base_tree` 时为增量更新（仅修改列出的文件），不提供则为全量替换。本 Skill 使用增量模式以保留仓库中可能存在的其他文件。

---

## 3. Commits（提交）

创建一个新的提交对象，指向特定的 Tree 和父提交。

### 创建 Commit

```
POST /repos/{owner}/{repo}/git/commits
```

**请求体**:
```json
{
  "message": "feat: 新增背包系统",
  "tree": "<tree SHA>",
  "parents": ["<父 commit SHA>"]
}
```

**首次提交**（空仓库）: `parents` 传空数组 `[]`。

**响应** (201):
```json
{
  "sha": "def456...",
  "tree": { "sha": "..." },
  "parents": [{ "sha": "..." }],
  "message": "feat: 新增背包系统",
  "author": { "name": "...", "email": "...", "date": "..." }
}
```

---

## 4. References（引用 / 分支指针）

管理分支和标签的指针。

### 获取引用

```
GET /repos/{owner}/{repo}/git/refs/heads/{branch}
```

**响应**:
```json
{
  "ref": "refs/heads/main",
  "object": {
    "type": "commit",
    "sha": "abc123..."
  }
}
```

### 创建引用（新分支/标签）

```
POST /repos/{owner}/{repo}/git/refs
```

```json
{
  "ref": "refs/heads/main",
  "sha": "<commit SHA>"
}
```

### 更新引用（推进分支）

```
PATCH /repos/{owner}/{repo}/git/refs/heads/{branch}
```

```json
{
  "sha": "<新 commit SHA>"
}
```

---

## 5. Tags（标签）

创建 annotated tag（带消息的标签），用于标记游戏版本。

### 创建 Tag 对象

```
POST /repos/{owner}/{repo}/git/tags
```

```json
{
  "tag": "v1.0.0",
  "message": "首个可玩版本",
  "object": "<commit SHA>",
  "type": "commit",
  "tagger": {
    "name": "Maker",
    "email": "maker@example.com",
    "date": "2026-01-01T00:00:00Z"
  }
}
```

创建 Tag 对象后，还需创建对应的引用：

```
POST /repos/{owner}/{repo}/git/refs
```

```json
{
  "ref": "refs/tags/v1.0.0",
  "sha": "<tag object SHA>"
}
```

---

## 6. 完整同步流程示意

```
┌─────────────┐
│  本地文件     │
│  scripts/    │
│  assets/     │
└──────┬──────┘
       │ 1. 读取文件内容 + base64 编码
       ▼
┌─────────────┐
│  Blobs API   │  POST /git/blobs  (每个文件一次)
│  创建文件对象 │  → 返回 blob SHA
└──────┬──────┘
       │ 2. 收集所有 blob SHA + 路径
       ▼
┌─────────────┐
│  Trees API   │  POST /git/trees  (一次)
│  组装目录树   │  → 返回 tree SHA
└──────┬──────┘
       │ 3. 指定 tree + parent commit
       ▼
┌─────────────┐
│  Commits API │  POST /git/commits (一次)
│  创建提交     │  → 返回 commit SHA
└──────┬──────┘
       │ 4. 更新分支指针
       ▼
┌─────────────┐
│  Refs API    │  PATCH /git/refs/heads/{branch} (一次)
│  推进分支     │  → 分支指向新提交
└─────────────┘
```

## 7. 速率限制

| 认证方式 | 限制 |
|---------|------|
| Personal Access Token | 5,000 次/小时 |
| 未认证 | 60 次/小时 |

单次 sync 消耗: `N(文件数) × 1(blob) + 1(tree) + 1(commit) + 1(ref) = N + 3` 次请求。

## 8. 错误处理

| HTTP 状态码 | 含义 | 处理方式 |
|------------|------|---------|
| 401 | Token 无效或过期 | 重新生成 Token |
| 403 | 权限不足或速率限制 | 检查 Token 权限 / 等待限制重置 |
| 404 | 仓库或引用不存在 | 检查 owner/repo 拼写 |
| 409 | 引用冲突 | 先获取最新 ref 再更新 |
| 422 | 请求体格式错误 | 检查 JSON 格式和必填字段 |
