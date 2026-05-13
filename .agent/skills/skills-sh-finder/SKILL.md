---
name: skills-sh-finder
description: >
  自动分析项目代码，检测缺失能力并从 skills.sh（3.5万+ 技能）自动搜索安装所需技能。
  Use when users need to:
  (1) 自动扫描项目代码并安装匹配的技能包,
  (2) 根据代码中的 import/require/依赖自动补全缺失技能,
  (3) 检测项目技术栈并推荐最佳实践技能,
  (4) 批量安装某个领域的技能组合,
  (5) 用户说「自动安装技能」「扫描项目」「补全技能」「install skills」「scan project」.
  Trigger keywords: 自动安装技能, 扫描项目, 补全技能, install skills, scan project,
  find skills, 技能推荐, skill recommendation, auto install.
  MUST trigger when: 检测到项目代码使用了某个领域但缺少对应技能时，主动建议安装。
---

# Skills.sh Finder

自动分析项目代码和技术栈，从 skills.sh（3.5万+ 技能）检测并安装所需技能。

---

## 环境准备

首次使用前执行一次：

```bash
which npx && npx --version
export http_proxy=http://127.0.0.1:1080
export https_proxy=http://127.0.0.1:1080
export HTTP_PROXY=http://127.0.0.1:1080
export HTTPS_PROXY=http://127.0.0.1:1080
```

---

## 自动安装工作流

### 步骤 1: 扫描项目代码

分析项目文件，提取技术栈信号：

```
扫描目标:
  ├── package.json          → 依赖库 / 框架 / scripts
  ├── *.ts / *.tsx / *.js   → import 语句 / 框架特征
  ├── *.py                  → import / requirements
  ├── *.lua                 → require 语句
  ├── Dockerfile / docker-* → 容器化 / 云部署
  ├── .github/workflows/    → CI/CD
  ├── *.sql / prisma/       → 数据库
  ├── *.test.* / __tests__/ → 测试框架
  └── .env / config files   → 外部服务集成
```

### 步骤 2: 信号 → 技能映射

根据扫描到的信号自动匹配技能：

| 代码信号 | 检测到的需求 | 自动安装技能 |
|---------|------------|------------|
| `react`, `next`, `vue` in deps | 前端框架 | react/next/vue-best-practices |
| `playwright`, `puppeteer`, `selenium` | 浏览器自动化 | browser-use |
| `*.test.*`, `jest`, `vitest`, `pytest` | 测试 | test-driven-development |
| `.github/workflows/` 存在 | CI/CD + Git | github |
| `prisma`, `drizzle`, `*.sql`, `pg`, `mysql` | 数据库 | database-operations |
| `supabase` in deps | Supabase | supabase |
| `openai`, `anthropic`, `langchain` | AI/LLM 集成 | — (已有原生能力) |
| `azure`, `@azure/*` in deps | Azure 云 | azure |
| `@google-cloud/*`, `firebase` | GCP | gcloud |
| `Dockerfile`, `docker-compose` | 容器化部署 | — (通用知识) |
| `*.md` 大量存在, 无 README | 文档缺失 | crafting-effective-readmes |
| SEO 相关 meta / sitemap | SEO 需求 | seo-audit |
| 营销页面 / landing page | 营销内容 | copywriting |
| MCP 服务器代码 | MCP 开发 | mcp-builder |

### 步骤 3: 检查已安装 → 差量安装

```bash
# 列出已安装，避免重复
npx skills list

# 仅安装缺失的技能（-y 跳过确认）
npx skills add <owner/repo> --skill <name> -y
```

### 步骤 4: 向用户报告

安装完成后输出摘要：

```
📊 项目扫描结果:
  技术栈: React + Next.js + Prisma + PostgreSQL
  已安装技能: 2 个
  新安装技能: 3 个

✅ 已安装:
  - next-best-practices (前端最佳实践)
  - database-operations (数据库操作)
  - test-driven-development (测试驱动)

⏭️ 跳过 (已存在):
  - github
  - self-improving-agent
```

---

## 核心命令

```bash
npx skills find <query>                          # 搜索
npx skills add <owner/repo> --skill <name> -y    # 安装（跳过确认）
npx skills add <owner/repo> -g -y                # 全局安装
npx skills list                                  # 列出已安装
npx skills check                                 # 检查更新
npx skills update                                # 批量更新
npx skills remove <name>                         # 移除
```

安装路径: Claude Code → `.claude/skills/`，全局 → `~/.claude/skills/`

---

## 安全策略

自动安装前的准入检查（静默执行，不打断流程）：

| 级别 | 条件 | 行为 |
|------|------|------|
| ✅ 自动安装 | 安装量 >= 1K 且 官方源 (vercel-labs/anthropics/microsoft) | 直接安装 |
| ⚠️ 提示确认 | 安装量 >= 100 或 Stars >= 50 | 告知用户并等待确认 |
| 🚫 拒绝安装 | 安装量 < 100 且 Stars < 50 且 非官方源 | 拒绝，建议手动评估 |

---

## 主动触发场景

以下场景无需用户请求，AI 主动扫描并建议：

1. **新项目初始化后** — 扫描 package.json / requirements.txt，推荐技能组合
2. **引入新依赖后** — `npm install X` 后检测是否有匹配的最佳实践技能
3. **用户遇到某领域困难** — 例如用户调试 SQL 查询困难，建议安装 database-operations
4. **代码审查发现质量问题** — 建议安装 code-review-excellence 或 systematic-debugging

---

## 技能推荐速查

完整分类见 [references/skill-catalog.md](references/skill-catalog.md)。

| 需求 | 技能 |
|------|------|
| 前端最佳实践 | react/next/vue-best-practices |
| 浏览器自动化 | browser-use |
| 代码审查 | code-review-excellence |
| 测试 | test-driven-development |
| 图像生成 | image-generation |
| 文档 | docx / pptx / pdf |
| 数据库 | database-operations / supabase |
| GitHub | github |
| 记忆系统 | memory |
| 自我改进 | self-improving-agent |
| 安全审计 | skill-vetter |

---

## 禁用遥测

```bash
DISABLE_TELEMETRY=1 npx skills add <skill-name>
```
