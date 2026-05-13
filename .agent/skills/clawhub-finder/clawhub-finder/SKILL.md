---
name: clawhub-finder
description: >
  自动分析项目代码，检测缺失能力并从 ClawHub.ai（13,000+ 技能）自动搜索安装所需技能。
  Use when users need to:
  (1) 自动扫描项目代码并安装匹配的技能包,
  (2) 根据代码中的 import/require/依赖自动补全缺失技能,
  (3) 检测项目技术栈并推荐最佳实践技能,
  (4) 批量安装某个领域的技能组合,
  (5) 用户说「自动安装技能」「扫描项目」「补全技能」「install skills」「scan project」.
  Trigger keywords: 自动安装技能, 扫描项目, 补全技能, install skills, scan project, find skills, 技能推荐, skill recommendation, auto install, clawhub.
  MUST trigger when: 检测到项目代码使用了某个领域但缺少对应技能时，主动建议安装。
---

# ClawHub 自动技能发现与安装

根据项目代码自动检测所需技能，从 ClawHub.ai 搜索并安装。

## 环境准备

首次使用前检查 CLI：

```bash
# 检查是否安装
which clawhub || npm i -g clawhub

# 验证
clawhub --version
```

## 自动工作流（4 步）

### Step 1: 扫描项目代码

扫描以下信号源，识别项目技术栈和需求：

| 信号源 | 检测方法 |
|--------|---------|
| package.json | `dependencies` / `devDependencies` 键名 |
| import/require | `grep -rn "import\|require\|from " src/ lib/ app/` |
| 配置文件 | `.env`, `docker-compose.yml`, `Dockerfile`, `*.tf`, `CI/*.yml` |
| 框架标志 | `next.config`, `nuxt.config`, `angular.json`, `vite.config` |
| 语言文件 | `*.py`, `*.rs`, `*.go`, `*.java`, `*.rb`, `*.swift` |
| AI/ML | `openai`, `langchain`, `transformers`, `torch`, `rag`, `embeddings` |
| 数据库 | `prisma/`, `drizzle/`, `*.sql`, `mongoose`, `typeorm` |
| 测试 | `jest.config`, `vitest`, `pytest`, `.mocharc`, `cypress/` |
| 文档 | `docs/`, `README.md`, `CHANGELOG.md`, `*.mdx` |

### Step 2: 信号→技能映射

根据扫描结果，查阅 `references/skill-catalog.md` 匹配技能。

核心映射表（高频）：

| 代码信号 | 推荐技能搜索词 | 分类 |
|---------|---------------|------|
| React/Next.js/Vue | `react`, `nextjs`, `vue` | Web & Frontend |
| Python/FastAPI/Django | `python`, `fastapi`, `django` | Coding Agents |
| Docker/K8s/Terraform | `docker`, `kubernetes`, `terraform` | DevOps & Cloud |
| OpenAI/LangChain/RAG | `ai agent`, `rag`, `langchain` | AI & ML |
| PostgreSQL/MongoDB | `postgres`, `mongodb`, `database` | Database |
| Jest/Pytest/Cypress | `testing`, `jest`, `pytest` | Testing & QA |
| GitHub Actions/CI | `ci cd`, `github actions` | DevOps & Cloud |
| Markdown/Docs | `documentation`, `readme` | Content & Docs |
| Auth/JWT/OAuth | `authentication`, `security` | Security |
| Stripe/Payment | `stripe`, `payment` | API & Integration |
| Mobile/React Native | `react native`, `mobile` | Mobile Dev |
| Rust/Go/Java | `rust`, `golang`, `java` | Coding Agents |

### Step 3: 增量安装

```bash
# 查看已安装技能
clawhub list

# 搜索候选
clawhub search "<keyword>"

# 安装（仅安装未安装的）
clawhub install <author>/<skill-name>

# 批量安装
clawhub install <a1>/<s1> <a2>/<s2> <a3>/<s3>
```

安装前对比 `clawhub list` 输出，仅安装缺失项。

### Step 4: 报告

安装完成后，向用户报告：

```
[ClawHub 技能安装报告]
扫描: package.json, src/, .env, docker-compose.yml
已安装: 3 个技能
  ✅ author/nextjs-expert (Web & Frontend)
  ✅ author/prisma-db (Database)
  ✅ author/jest-testing (Testing & QA)
跳过: 2 个（已存在）
  ⏭️ author/typescript-guru
  ⏭️ author/eslint-config
```

## 安全策略

三级信任机制：

| 级别 | 操作 | 示例 |
|------|------|------|
| 自动安装 | 高相关性 + 高下载量技能 | 代码有 `next.config.js` → 安装 Next.js 技能 |
| 询问确认 | 中等相关性或多选项 | 检测到 Python → 问用户选 Django 还是 FastAPI |
| 不安装 | 低相关性或可疑 | 仅文件名匹配、无代码使用证据 |

## 核心命令速查

```bash
clawhub search <query>              # 搜索技能
clawhub install <author>/<name>     # 安装技能
clawhub list                        # 已安装列表
clawhub update [author/name]        # 更新技能
clawhub remove <author>/<name>      # 卸载技能
```

## 主动触发场景

以下场景主动建议扫描安装：

1. 用户首次打开含 `package.json` 或框架配置的项目
2. 用户安装新依赖（`npm install`, `pip install`）后
3. 用户说「这个库怎么用」但无对应技能时
4. 用户遇到反复出错、缺少领域知识时
5. 检测到 `.clawhub/lock.json` 不存在（说明从未安装过技能）

## 分类参考

完整 32 分类技能索引见 `references/skill-catalog.md`。
按代码信号匹配分类后，在对应分类下搜索具体技能。
