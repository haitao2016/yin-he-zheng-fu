---
name: game-content-factory
description: >-
  UrhoX Lua 游戏内容工厂——一次代码分析，批量生成全套发布内容。
  灵感来自 clawhub.ai dev-tools-pack 的自动化管线模式，将"独立工具"升级为"端到端管线"。
  通过三阶段管线（SCAN → GENERATE → DELIVER）自动从游戏代码中提取信息，
  批量生成 GDD、商店文案、开发日志、推广文案、更新公告等多格式内容产物。
  Use when users need to
  (1) 一键生成游戏全套发布文案（商店描述+推广+更新公告）,
  (2) 从代码自动提取游戏信息生成设计文档,
  (3) 批量生成多种内容（不想逐个手动触发 dev-tools-pack 的 6 个工具）,
  (4) 发布前一站式准备所有文字资产,
  (5) 用户说"一键生成"、"批量生成文案"、"全套内容"、"内容工厂"、"content factory",
  (6) 用户说"帮我准备发布内容"、"生成所有发布材料"、"一次搞定所有文案",
  (7) 用户说"分析我的代码然后生成文档"、"从代码生成描述",
  (8) 游戏开发完成后需要快速产出全套配套文字资产。
  与 dev-tools-pack 的区别：dev-tools-pack 是 6 个独立工具（逐个触发），
  本 Skill 是端到端管线（一次触发、批量输出、上下文共享）。
---

# Game Content Factory — 游戏内容工厂

一次代码分析，批量生成全套发布内容。

## 核心理念

传统方式：分别调用 GDD 生成器、商店文案生成器、推广文案生成器…… 每次都要重新分析代码。

**内容工厂方式**：一次深度扫描 → 构建游戏画像 → 批量渲染所有内容模板。

```
┌─────────┐    ┌──────────┐    ┌──────────┐
│  SCAN   │ →  │ GENERATE │ →  │ DELIVER  │
│ 代码分析 │    │ 批量生成  │    │ 输出交付  │
└─────────┘    └──────────┘    └──────────┘
```

## 三阶段管线

### 阶段 1: SCAN — 代码分析与游戏画像

扫描 `scripts/` 目录，提取游戏核心信息，构建**游戏画像**（Game Profile）。

**扫描清单**：

| 提取项 | 来源 | 画像字段 |
|--------|------|---------|
| 游戏类型 | 脚手架类型、物理引擎使用 | `genre` |
| 核心玩法 | Update 循环、输入处理逻辑 | `coreMechanic` |
| 屏幕方向 | 布局代码、相机设置 | `orientation` |
| 技术栈 | require 引用、组件使用 | `techStack[]` |
| 游戏系统 | 模块文件列表、CONFIG 表 | `systems[]` |
| 美术风格 | 材质类型、NanoVG/UI 使用 | `artStyle` |
| 多人模式 | `.project/settings.json` | `multiplayer` |
| 数值特征 | CONFIG 常量、数值公式 | `balanceHints` |

**画像输出格式**（内部使用，不写文件）：

```lua
local profile = {
    title       = "推断的游戏名称",
    genre       = "platformer",
    coreMechanic = "跳跃+收集",
    orientation = "landscape",
    techStack   = {"Box2D", "NanoVG", "UI"},
    systems     = {"PlayerController", "EnemyAI", "ScoreManager"},
    artStyle    = "像素风",
    multiplayer = false,
    codeStats   = { files = 5, totalLines = 1200 },
}
```

**用户确认**：扫描完成后，向用户展示画像摘要并确认，再进入生成阶段。

### 阶段 2: GENERATE — 批量内容生成

基于游戏画像，按用户选择批量生成内容产物。

**可选产物菜单**（用户可选全部或子集）：

| # | 产物 | 输出文件 | 说明 |
|---|------|---------|------|
| A | **游戏设计文档** | `docs/gdd.md` | 结构化 GDD |
| B | **商店描述** | `docs/store-listing.md` | TapTap 文案 + JSON 配置 |
| C | **开发日志** | `docs/devlog.md` | 当前版本变更记录 |
| D | **推广文案集** | `docs/promo-copy.md` | 推介/公告/功能介绍 |
| E | **代码审查报告** | `docs/review-report.md` | 质量评分 + 修复建议 |
| F | **技术摘要** | `docs/tech-summary.md` | 架构、依赖、模块关系 |

**默认全选**——用户说"一键生成"时产出 A-F 全部内容。

**生成规则**：

1. 所有产物共享同一份游戏画像（避免重复分析）
2. 产物之间保持信息一致（GDD 中的游戏名称 = 商店描述中的名称）
3. 每个产物遵循对应模板（详见 `references/content-templates.md`）
4. 商店描述额外输出 `taptap_publish` JSON 片段

### 阶段 3: DELIVER — 输出交付

1. **写入文件**：所有产物写入 `docs/` 目录
2. **交付摘要**：输出一份总览表，列出已生成的文件和字数统计
3. **后续建议**：提示用户可进行的后续操作

**交付摘要格式**：

```markdown
## 内容工厂 — 生成完成

| 产物 | 文件 | 字数 | 状态 |
|------|------|------|------|
| GDD | docs/gdd.md | ~1200 | 已生成 |
| 商店描述 | docs/store-listing.md | ~300 | 已生成 |
| 开发日志 | docs/devlog.md | ~200 | 已生成 |
| 推广文案 | docs/promo-copy.md | ~400 | 已生成 |
| 审查报告 | docs/review-report.md | ~500 | 已生成 |
| 技术摘要 | docs/tech-summary.md | ~300 | 已生成 |

后续可执行:
- 运行 build 工具发布游戏
- 使用 generate_game_material 生成图标/截图
- 将 taptap_publish 配置写入 .project/project.json
```

---

## 快捷模式

### 模式 1: 全量生成（默认）

```
用户: "帮我一键生成所有发布内容"
→ SCAN → GENERATE(A-F) → DELIVER
```

### 模式 2: 选择性生成

```
用户: "只生成商店描述和推广文案"
→ SCAN → GENERATE(B+D) → DELIVER
```

### 模式 3: 增量更新

```
用户: "我改了代码，更新一下开发日志"
→ SCAN(增量) → GENERATE(C) → DELIVER(追加)
```

增量模式下：
- 读取已有 `docs/devlog.md`，新条目追加到顶部
- 读取已有 `docs/gdd.md`，仅更新变更的章节

---

## 引擎兼容性

| 规则 | 遵循方式 |
|------|---------|
| 代码在 `scripts/` | SCAN 仅扫描 `scripts/` + 用户目录 |
| 文档在 `docs/` | 所有产物写入 `docs/` |
| 不写 `dist/` | 禁止写入发布产物目录 |
| 忽略引擎目录 | 不扫描 `engine-docs/`、`urhox-libs/` 等 |
| 多人模式判断 | 读取 `.project/settings.json` |
| 枚举不猜数字 | 审查报告检查此项 |

---

## 与其他 Skill 的关系

| Skill | 关系 |
|-------|------|
| `dev-tools-pack` | **互补**——dev-tools-pack 提供单工具详细模板；本 Skill 提供批量管线编排 |
| `game-creation-workflow` | **前置**——创建游戏用 workflow，发布准备用 content-factory |
| `game-bug-checker` | **审查引用**——产物 E 的审查逻辑参考 bug-checker 检查项 |
| `urhox-mobile-launch` | **互补**——mobile-launch 处理性能技术问题；本 Skill 处理文字内容 |

---

## 内容模板与写作规范

详细的产物模板、字段定义和写作规范参见 [references/content-templates.md](references/content-templates.md)。

包含：GDD 结构模板、商店描述模板、开发日志格式、推广文案类型、审查评分标准、技术摘要结构。
