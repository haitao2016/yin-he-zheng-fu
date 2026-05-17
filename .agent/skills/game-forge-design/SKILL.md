---
name: game-forge-design
version: 1.0.0
description: >
  结构化多阶段游戏设计文档生成管线（Game Forge），支持跨会话状态持久化、
  质量门禁自动审查、ID 可追溯性和 6 种游戏类型配置。
  灵感来源于 Citronetic/game-designer 项目，为 UrhoX Lua 引擎深度适配。
author: UrhoX Skill Builder
tags:
  - game-design
  - GDD
  - pipeline
  - multi-session
  - quality-gates
  - traceability
---

# Game Forge — 结构化游戏设计管线

> **Use when:** 用户需要 (1) 从零开始系统性设计一款游戏（概念→系统→数据→量化→制作规格），
> (2) 生成完整的游戏设计文档(GDD)并持久化到项目中，
> (3) 跨多次会话渐进式完善游戏设计（恢复上次进度），
> (4) 用户说"帮我设计一个游戏"/"游戏策划"/"GDD"/"设计文档"/"game forge"/"gf-"开头的命令，
> (5) 需要结构化的质量审查来确保设计完整性，
> (6) 需要从设计文档自动生成 Lua 配置数据表。
>
> **不适用于：** 已有明确需求只需直接写代码的场景（那属于 `game-dev-planner` 或 `game-creation-workflow`）。
> 本 skill 专注于**设计阶段**——在写代码之前把游戏想清楚。

---

## §1 核心理念

Game Forge 是一个 **4 阶段渐进式游戏设计管线**，将模糊的游戏创意转化为可执行的设计文档和数据配置。

### 与现有 Skill 的定位区分

| Skill | 定位 | Game Forge 差异 |
|-------|------|----------------|
| `interactive-game-designer` | 引导式对话生成 GDD | Game Forge 有 4 阶段正式流水线、质量门禁、跨会话状态 |
| `game-dev-planner` | 7 阶段开发全周期 | Game Forge 专注设计阶段，有 ID 追溯、数据表生成、章节跳过 |
| `game-creation-workflow` | 4 阶段从创意到成品 | Game Forge 更深入设计文档，不直接生成代码 |
| `game-balancing` | 经济/数值平衡 | Game Forge 的 Stage 3B 涵盖平衡，但作为管线一环 |
| `dev-tools-pack` | 一次性 GDD 生成器 | Game Forge 支持多会话迭代、质量审查、持久化 |

**Game Forge 独有能力：**
1. **跨会话状态持久化** — `docs/gdd/STATE.md` 记录精确进度
2. **质量门禁** — 阶段间自动审查，检查遗漏/矛盾/深度不足
3. **ID 追溯系统** — 每个设计元素有唯一 ID，跨阶段引用可追踪
4. **游戏类型配置** — 6 种类型自动跳过无关章节
5. **数据表生成** — 自动生成 Lua 配置表（可直接用于 `scripts/config/`）
6. **15 章概念文档** — 结构化章节覆盖游戏设计全维度

---

## §2 四阶段管线总览

```
┌─────────────┐    质量门禁     ┌─────────────┐    质量门禁     ┌─────────────┐    质量门禁     ┌─────────────┐
│  Stage 1    │ ─────────────→ │  Stage 2    │ ─────────────→ │  Stage 3    │ ─────────────→ │  Stage 4    │
│  概念设计    │    REVIEW-1    │  系统设计    │    REVIEW-2    │ 数据+平衡    │    REVIEW-3    │  制作规格    │
│  15 章文档   │               │  SYS-*.md   │               │ 3A+3B       │               │ ART/UI/TECH │
└─────────────┘               └─────────────┘               └─────────────┘               └─────────────┘
```

### Stage 1: 概念设计（Concept）
- **输出**：15 章概念文档（详见 §4）
- **目标**：定义游戏是什么、给谁玩、怎么玩
- **交互**：逐章引导用户，AI 提供建议和模板

### Stage 2: 系统设计（System Design）
- **输出**：`SYS-*.md` 系统规格文档 + `CONTENT-RHYTHM.md`
- **目标**：将概念拆解为可实现的游戏系统
- **前置**：Stage 1 质量门禁通过

### Stage 3A: 数据模式（Data Schema）
- **输出**：数据表定义 + 枚举 + 关系 + Lua 配置文件
- **目标**：将系统设计转化为数据结构

### Stage 3B: 数值平衡（Balance）
- **输出**：难度曲线、经济模型、调优参数
- **目标**：确保游戏数值合理可控

### Stage 4: 制作规格（Production）
- **输出**：美术规格、UI 规格、技术规格
- **目标**：为实现阶段提供明确指引

---

## §3 游戏类型配置

Game Forge 支持 6 种游戏类型，每种类型自动跳过不相关的章节：

| 类型 | 标识 | 跳过章节 | UrhoX 脚手架 |
|------|------|---------|-------------|
| 2D 休闲 | `casual` | ch08(变现)、ch12(数据分析)、ch13(ROI) | `templates/scaffold-2d.lua` |
| RPG | `rpg` | 无跳过（全章节） | `templates/scaffold-3d-character.lua` |
| 解谜 | `puzzle` | ch14(多人) | `templates/scaffold-2d.lua` |
| 策略 | `strategy` | ch13(ROI) | `templates/scaffold-3d-scene.lua` |
| 放置 | `idle` | ch04(关卡)、ch14(多人) | `templates/scaffold-2d.lua` |
| 动作 | `action` | 无跳过（全章节） | `templates/scaffold-3d-character.lua` 或 `scaffold-2d-physics.lua` |

用户初始化项目时选择类型，后续阶段自动适配。

---

## §4 Stage 1: 概念设计 — 15 章详解

每章生成独立的 Markdown 文件，存储在 `docs/gdd/stages/01-concept/`。

### 章节列表

| # | 章节 | 文件名 | 必填 | 说明 |
|---|------|--------|------|------|
| 1 | 目标用户 | `ch01-target-users.md` | ✅ | 玩家画像、平台偏好、游戏习惯 |
| 2 | 核心玩法 | `ch02-core-gameplay.md` | ✅ | 30秒体验描述、操控方式、核心乐趣 |
| 3 | 游戏循环 | `ch03-game-loops.md` | ✅ | 核心循环→中期循环→长期循环 |
| 4 | 关卡设计 | `ch04-level-design.md` | 按类型 | 关卡结构、节奏、难度递进 |
| 5 | 难度系统 | `ch05-difficulty.md` | ✅ | 难度曲线、自适应难度、挫败感控制 |
| 6 | 新手引导 | `ch06-onboarding.md` | ✅ | 教程设计、渐进式功能解锁 |
| 7 | 留存设计 | `ch07-retention.md` | ✅ | 日/周/月留存机制、回流钩子 |
| 8 | 商业化 | `ch08-monetization.md` | 按类型 | 付费模型、广告策略(TapTap广告) |
| 9 | 美术方向 | `ch09-art-direction.md` | ✅ | 美术风格、色彩方案、参考图 |
| 10 | UI/UX | `ch10-ui-ux.md` | ✅ | 界面布局、交互流程、用 urhox-libs/UI |
| 11 | 技术需求 | `ch11-tech-requirements.md` | ✅ | 脚手架选择、物理引擎、渲染方案 |
| 12 | 数据分析 | `ch12-analytics.md` | 按类型 | 关键指标、埋点方案 |
| 13 | 投资回报 | `ch13-roi.md` | 按类型 | 开发成本估算、回报预期 |
| 14 | 多人模式 | `ch14-multiplayer.md` | 按类型 | C/S架构、同步方案、云变量 |
| 15 | 平台集成 | `ch15-platform-integration.md` | ✅ | TapTap发布、排行榜、云存档 |

### 章节编写流程

```
对于每个章节：
1. AI 展示章节模板（含必填项和可选项）
2. 用户提供输入或选择 AI 建议
3. AI 生成完整章节内容
4. 为每个关键设计元素分配 ID（格式：C-XX-NNN）
5. 将 ID 注册到追溯表
6. 保存到 docs/gdd/stages/01-concept/chXX-*.md
7. 更新 docs/gdd/STATE.md 进度
```

### UrhoX 特定适配

**ch10 UI/UX 章节**必须包含：
- 使用 `urhox-libs/UI` 组件库（不使用原生 UI）
- Yoga Flexbox 布局方案
- 屏幕适配策略（设计分辨率 vs 系统逻辑分辨率）
- 参考 `engine-docs/recipes/ui.md`

**ch11 技术需求章节**必须包含：
- 脚手架选择（2D/2D物理/3D场景/3D角色）
- 物理引擎选择（Box2D for 2D / Bullet for 3D）
- 渲染方案（NanoVG for 2D 自绘 / 3D PBR）
- 代码模块化方案（单文件 vs 多模块）
- 构建和发布流程（使用 UrhoX MCP build 工具）

**ch14 多人模式章节**（如适用）：
- 读取 `.project/settings.json` 的 `multiplayer.enabled`
- C/S 架构：`scripts/network/Client.lua` + `scripts/network/Server.lua`
- 云变量：`clientCloud` / `serverCloud`
- 参考 `examples/11-client-cloud-score-leaderboard-api.lua`

**ch15 平台集成章节**必须包含：
- TapTap 发布配置（`taptap_publish` 字段）
- 云存档（`clientCloud`）
- 排行榜（cloud score API）
- 广告集成（`get_ad_config`，如适用）

---

## §5 Stage 2: 系统设计

### 输入
- Stage 1 概念文档（通过质量门禁）

### 输出文件

```
docs/gdd/stages/02-system-design/
├── systems/
│   ├── SYS-CORE.md          # 核心玩法系统
│   ├── SYS-COMBAT.md        # 战斗系统（如有）
│   ├── SYS-PROGRESSION.md   # 进度/成长系统
│   ├── SYS-ECONOMY.md       # 经济系统（如有）
│   ├── SYS-UI.md             # UI 系统
│   ├── SYS-INPUT.md          # 输入系统
│   ├── SYS-AUDIO.md          # 音频系统
│   └── SYS-*.md              # 其他系统
└── CONTENT-RHYTHM.md         # 内容节奏规划
```

### 系统规格文档模板

每个 `SYS-*.md` 包含：

```markdown
# SYS-XXX: 系统名称

## 概述
- ID: SYS-XXX
- 依赖: [引用其他 SYS-* ID]
- 对应概念章节: [引用 C-XX-NNN ID]

## 职责
- 该系统负责什么

## 接口
- 输入：接收什么数据/事件
- 输出：产生什么数据/事件

## 状态
- 该系统管理哪些状态

## UrhoX 实现方案
- 使用哪些 UrhoX 组件/API
- 代码放在 scripts/ 的哪个文件
- 模块依赖关系

## 数据需求
- 需要哪些配置数据（关联 Stage 3A）
```

### UrhoX 系统映射

| 游戏系统 | UrhoX 实现 |
|---------|-----------|
| 核心玩法 | `scripts/main.lua` 或 `scripts/game/GameManager.lua` |
| 渲染/场景 | Scene/Node/Component 体系 |
| 物理 | Box2D (2D) 或 Bullet (3D) |
| 输入 | `urhox-libs/Platform/InputManager` |
| UI | `urhox-libs/UI` (Yoga Flexbox) |
| 音频 | `audio-manager` skill |
| 动画 | FSM + BlendSpace (`setup-fsm` skill) |
| 网络 | Client/Server 架构 |
| 存储 | `File` API (`recipes/file-storage.md`) |
| 云服务 | `clientCloud` / `serverCloud` |

---

## §6 Stage 3A: 数据模式

### 输出文件

```
docs/gdd/stages/03a-data-schema/
├── tables.md                  # 所有数据表定义
├── relationships.md           # 表间关系
├── enums.md                   # 枚举定义
└── configs/                   # 可直接使用的 Lua 配置
    ├── monsters.lua           # 示例：怪物配置表
    ├── items.lua              # 示例：道具配置表
    ├── levels.lua             # 示例：关卡配置表
    └── balance.lua            # 示例：数值平衡表
```

### 数据表定义格式

`tables.md` 中每张表定义：

```markdown
### TBL-MONSTERS

| 字段 | 类型 | 必填 | 说明 | 引用 |
|------|------|------|------|------|
| id | string | ✅ | 唯一标识 | — |
| name | string | ✅ | 显示名 | — |
| hp | number | ✅ | 生命值 | BAL-HP-CURVE |
| atk | number | ✅ | 攻击力 | BAL-ATK-CURVE |
| type | MonsterType | ✅ | 怪物类型 | ENUM-MONSTER-TYPE |
| drop_table | string | ❌ | 掉落表ID | TBL-DROPS.id |
```

### Lua 配置生成

Stage 3A 自动生成可直接放入 `scripts/config/` 的 Lua 文件：

```lua
-- scripts/config/monsters.lua
-- 由 Game Forge 自动生成，可手动编辑
-- 关联设计文档: docs/gdd/stages/03a-data-schema/tables.md#TBL-MONSTERS

local Monsters = {}

Monsters.data = {
    {
        id = "slime_green",
        name = "绿色史莱姆",
        hp = 30,
        atk = 5,
        type = "normal",
        drop_table = "drop_common",
    },
    {
        id = "goblin_warrior",
        name = "哥布林战士",
        hp = 80,
        atk = 15,
        type = "elite",
        drop_table = "drop_elite",
    },
}

-- 按 ID 索引（运行时使用）
Monsters.byId = {}
for _, v in ipairs(Monsters.data) do
    Monsters.byId[v.id] = v
end

return Monsters
```

---

## §7 Stage 3B: 数值平衡

### 输出文件

```
docs/gdd/stages/03b-balance/
├── difficulty.md        # 难度曲线定义
├── economy.md           # 经济模型
├── monetization.md      # 付费/广告数值（如适用）
└── tuning.md            # 调优参数汇总
```

### 平衡参数模板

`tuning.md` 汇总所有需要调优的参数：

```markdown
### BAL-PLAYER-STATS
| 参数 | 初始值 | 最大值 | 成长公式 | 说明 |
|------|--------|--------|---------|------|
| hp | 100 | 9999 | base * (1 + level * 0.15) | 生命值 |
| atk | 10 | 999 | base * (1 + level * 0.12) | 攻击力 |
| speed | 5.0 | 8.0 | — | 移动速度(米/秒) |
| jump_force | 7.0 | 10.0 | — | 跳跃初速度(米/秒) |
```

注意：UrhoX 使用**米**作为长度单位，重力为 -9.81 m/s²，角色高度通常 1.5-2.0 米。

---

## §8 Stage 4: 制作规格

### 输出文件

```
docs/gdd/stages/04-production/
├── ART-SPEC.md       # 美术制作规格
├── UI-SPEC.md        # UI 制作规格
└── TECH-SPEC.md      # 技术制作规格
```

### ART-SPEC.md 包含
- 美术风格详细定义（含参考图描述）
- 角色/场景/道具的资源清单
- 动画需求清单（FSM 状态定义）
- 材质方案（PBR 材质参数，参考 `materials` skill）
- AI 图像生成提示词（用于 `generate_image` / `batch_generate_images`）

### UI-SPEC.md 包含
- 完整界面流程图（screen flow）
- 每个界面的布局描述（使用 `urhox-libs/UI` 组件）
- 组件选用清单（参考 `examples/14-ui-widgets-gallery.lua`）
- 交互动画说明（参考 `soyoyo_tween` skill）

### TECH-SPEC.md 包含
- 项目目录结构（`scripts/` 下的文件组织）
- 模块依赖图
- 脚手架选择和理由
- 性能预算和优化策略
- 构建配置（入口文件、多人模式设置等）
- 构建流程：使用 UrhoX MCP `build` 工具

---

## §9 质量门禁系统

### 门禁触发时机

每个阶段完成时，自动执行质量门禁审查：

```
Stage 1 完成 → REVIEW-1（概念审查）
Stage 2 完成 → REVIEW-2（系统审查）
Stage 3 完成 → REVIEW-3（数据审查）
Stage 4 完成 → FINAL-REVIEW（最终审查）
```

### 审查维度

| 维度 | 检查内容 |
|------|---------|
| **完整性** | 所有必填章节/系统是否已完成 |
| **一致性** | 跨章节引用是否一致（ID 追溯） |
| **深度** | 每个章节是否达到最低深度要求 |
| **可行性** | 技术方案是否与 UrhoX 能力匹配 |
| **矛盾检测** | 不同章节间是否存在矛盾 |

### REVIEW 文件格式

```markdown
# REVIEW-1: 概念阶段审查

## 审查结果: ✅ 通过 / ⚠️ 有建议 / ❌ 阻断

### 完整性检查
- [x] ch01 目标用户 — 已完成
- [x] ch02 核心玩法 — 已完成
- [ ] ch04 关卡设计 — 已跳过（类型:idle）
...

### 一致性检查
- [x] 核心循环(C-03-001)与核心玩法(C-02-001)一致
- [⚠️] 留存设计(C-07-003)提到的"公会系统"在核心玩法中未提及

### 深度检查
- [x] 所有章节超过 200 字
- [⚠️] ch09 美术方向缺少色彩方案详细定义

### 建议
1. 在 ch02 补充"公会系统"描述，或从 ch07 移除引用
2. 在 ch09 添加主色/辅助色/强调色的 HEX 值
```

### 审查文件存储

```
docs/gdd/reviews/
├── REVIEW-1.md      # 概念审查
├── REVIEW-2.md      # 系统审查
├── REVIEW-3.md      # 数据审查
└── FINAL-REVIEW.md  # 最终审查
```

---

## §10 ID 追溯系统

### ID 格式规范

| 阶段 | ID 前缀 | 格式 | 示例 |
|------|---------|------|------|
| Stage 1 概念 | C | `C-XX-NNN` | `C-02-001` (核心玩法第1个元素) |
| Stage 2 系统 | SYS | `SYS-XXX` | `SYS-COMBAT` |
| Stage 3A 数据 | TBL/ENUM | `TBL-XXX` / `ENUM-XXX` | `TBL-MONSTERS` |
| Stage 3B 平衡 | BAL | `BAL-XXX` | `BAL-HP-CURVE` |
| Stage 4 制作 | PRD | `PRD-XXX-NNN` | `PRD-ART-001` |

### 追溯注册表

`docs/gdd/traceability/id-registry.md` 记录所有 ID 及其跨阶段引用：

```markdown
# ID 注册表

| ID | 名称 | 阶段 | 文件 | 被引用于 |
|----|------|------|------|---------|
| C-02-001 | 核心战斗循环 | Stage 1 | ch02-core-gameplay.md | SYS-COMBAT, BAL-DMG-FORMULA |
| SYS-COMBAT | 战斗系统 | Stage 2 | SYS-COMBAT.md | TBL-MONSTERS, TBL-SKILLS |
| TBL-MONSTERS | 怪物数据表 | Stage 3A | tables.md | BAL-HP-CURVE, PRD-ART-001 |
```

---

## §11 跨会话状态管理

### STATE.md 格式

`docs/gdd/STATE.md` 是 Game Forge 的核心状态文件：

```markdown
# Game Forge State

## 项目信息
- **项目名**: 星际冒险
- **游戏类型**: action
- **创建时间**: 2026-05-14
- **最后更新**: 2026-05-14

## 当前进度
- **当前阶段**: Stage 1 — 概念设计
- **当前章节**: ch05 — 难度系统
- **完成度**: 4/15 章节完成

## 阶段状态
| 阶段 | 状态 | 完成度 | 最后操作 |
|------|------|--------|---------|
| Stage 1 概念 | 🔄 进行中 | 4/15 | 2026-05-14 |
| Stage 2 系统 | ⏳ 未开始 | — | — |
| Stage 3A 数据 | ⏳ 未开始 | — | — |
| Stage 3B 平衡 | ⏳ 未开始 | — | — |
| Stage 4 制作 | ⏳ 未开始 | — | — |

## 章节详情（Stage 1）
| # | 章节 | 状态 | ID 数量 |
|---|------|------|---------|
| 1 | 目标用户 | ✅ 完成 | 3 |
| 2 | 核心玩法 | ✅ 完成 | 5 |
| 3 | 游戏循环 | ✅ 完成 | 4 |
| 4 | 关卡设计 | ✅ 完成 | 6 |
| 5 | 难度系统 | 🔄 进行中 | 0 |
| 6-15 | ... | ⏳ 未开始 | — |

## 质量门禁
| 门禁 | 状态 | 日期 |
|------|------|------|
| REVIEW-1 | ⏳ 待执行 | — |
| REVIEW-2 | ⏳ 待执行 | — |
| REVIEW-3 | ⏳ 待执行 | — |
| FINAL | ⏳ 待执行 | — |
```

### 恢复会话流程

当用户使用 `/gf-resume` 或说"继续上次的设计"时：

1. 读取 `docs/gdd/STATE.md`
2. 解析当前阶段和章节
3. 读取已完成的章节内容（了解上下文）
4. 读取 ID 注册表（了解已有设计元素）
5. 向用户汇报进度
6. 从上次中断处继续

---

## §12 命令参考

### /gf-new — 初始化新项目

```
用户: /gf-new

AI 执行:
1. 询问游戏名称
2. 询问游戏类型（casual/rpg/puzzle/strategy/idle/action）
3. 询问一句话描述
4. 创建 docs/gdd/ 目录结构
5. 初始化 STATE.md 和 PROJECT.md
6. 初始化 ID 注册表
7. 引导进入 Stage 1 第一章
```

### /gf-concept — 进入/继续概念设计

```
用户: /gf-concept

AI 执行:
1. 读取 STATE.md 确定当前章节
2. 如果有未完成章节 → 继续该章节
3. 如果全部完成 → 执行 REVIEW-1 质量门禁
4. 每完成一章自动保存到文件并更新 STATE.md
```

### /gf-systems — 进入系统设计

```
用户: /gf-systems

AI 执行:
1. 检查 REVIEW-1 是否通过
2. 未通过 → 提示用户先完成概念阶段
3. 已通过 → 读取概念文档，开始系统拆解
4. 逐个系统引导设计，生成 SYS-*.md
```

### /gf-data — 生成数据模式

```
用户: /gf-data

AI 执行:
1. 检查 REVIEW-2 是否通过
2. 读取所有 SYS-*.md 提取数据需求
3. 生成表定义、关系、枚举
4. 生成 Lua 配置文件到 scripts/config/
5. 使用 UrhoX MCP build 工具验证 Lua 语法
```

### /gf-balance — 数值平衡设计

```
用户: /gf-balance

AI 执行:
1. 读取数据表定义
2. 设计难度曲线和公式
3. 设计经济模型（如适用）
4. 填充调优参数
5. 更新 scripts/config/ 中的数值
```

### /gf-production — 生成制作规格

```
用户: /gf-production

AI 执行:
1. 检查 REVIEW-3 是否通过
2. 生成 ART-SPEC.md（含 AI 图像生成提示词）
3. 生成 UI-SPEC.md（使用 urhox-libs/UI 组件）
4. 生成 TECH-SPEC.md（含项目结构和构建配置）
```

### /gf-progress — 查看进度

```
用户: /gf-progress

AI 执行:
1. 读取 STATE.md
2. 格式化展示当前进度
3. 列出已完成/进行中/待开始的内容
4. 显示 ID 注册表统计
```

### /gf-resume — 恢复上次进度

```
用户: /gf-resume

AI 执行:
1. 读取 STATE.md
2. 加载上下文（已完成章节、ID 注册表）
3. 汇报进度并从中断处继续
```

### /gf-export — 导出设计文档

```
用户: /gf-export

AI 执行:
1. 汇总所有阶段文档
2. 生成 docs/gdd/EXPORT.md（单文件汇总版）
3. 列出所有 scripts/config/ 生成的 Lua 文件
4. 显示完成度和剩余工作
```

---

## §13 文件结构总览

Game Forge 生成的完整文件结构：

```
项目根目录/
├── docs/
│   └── gdd/                          # Game Forge 设计文档根目录
│       ├── STATE.md                   # 📌 跨会话状态（核心文件）
│       ├── PROJECT.md                 # 项目概述
│       ├── EXPORT.md                  # 导出汇总（/gf-export 生成）
│       ├── stages/
│       │   ├── 01-concept/
│       │   │   ├── ch01-target-users.md
│       │   │   ├── ch02-core-gameplay.md
│       │   │   ├── ... (共 15 章)
│       │   │   └── ch15-platform-integration.md
│       │   ├── 02-system-design/
│       │   │   ├── systems/
│       │   │   │   ├── SYS-CORE.md
│       │   │   │   └── SYS-*.md
│       │   │   └── CONTENT-RHYTHM.md
│       │   ├── 03a-data-schema/
│       │   │   ├── tables.md
│       │   │   ├── relationships.md
│       │   │   ├── enums.md
│       │   │   └── configs/          # Lua 配置源文件
│       │   ├── 03b-balance/
│       │   │   ├── difficulty.md
│       │   │   ├── economy.md
│       │   │   ├── monetization.md
│       │   │   └── tuning.md
│       │   └── 04-production/
│       │       ├── ART-SPEC.md
│       │       ├── UI-SPEC.md
│       │       └── TECH-SPEC.md
│       ├── reviews/
│       │   ├── REVIEW-1.md
│       │   ├── REVIEW-2.md
│       │   ├── REVIEW-3.md
│       │   └── FINAL-REVIEW.md
│       └── traceability/
│           └── id-registry.md
│
└── scripts/
    └── config/                        # 📌 Game Forge 生成的 Lua 配置
        ├── monsters.lua
        ├── items.lua
        ├── levels.lua
        └── balance.lua
```

---

## §14 工作流程详细指南

### 完整流程（从零开始）

```
Step 1: /gf-new
  → 初始化项目、选择游戏类型
  → 创建 docs/gdd/ 目录
  → 初始化 STATE.md

Step 2: /gf-concept（循环）
  → 逐章填写概念文档
  → 每章分配 ID，注册到追溯表
  → 每章保存后更新 STATE.md
  → 全部完成后执行 REVIEW-1

Step 3: /gf-systems
  → 基于概念拆解游戏系统
  → 每个系统生成 SYS-*.md
  → 映射到 UrhoX 实现方案
  → 完成后执行 REVIEW-2

Step 4: /gf-data
  → 提取数据需求生成表定义
  → 生成 Lua 配置到 scripts/config/
  → 使用 build 工具验证语法

Step 5: /gf-balance
  → 设计数值公式和曲线
  → 更新配置文件中的数值
  → 完成后执行 REVIEW-3

Step 6: /gf-production
  → 生成美术/UI/技术规格
  → 技术规格包含完整项目结构
  → 完成后执行 FINAL-REVIEW

Step 7: /gf-export（可选）
  → 导出完整设计文档
  → 汇总所有配置文件清单
```

### 快速流程（小型游戏）

对于简单的休闲游戏，可以简化：

```
/gf-new → 选择 casual 类型
/gf-concept → 只填核心章节（自动跳过 ch08/ch12/ch13）
/gf-systems → 2-3 个核心系统即可
/gf-data → 简单配置表
/gf-production → 直接生成 TECH-SPEC.md
```

---

## §15 AI 行为准则

### 主动建议

AI 在每个阶段应**主动提供建议**，而非只被动等待用户输入：

1. **概念阶段**：根据游戏类型推荐核心循环模式、参考游戏
2. **系统阶段**：建议系统拆分方式、识别潜在的系统耦合
3. **数据阶段**：推荐数据结构、识别缺失的配置项
4. **平衡阶段**：提供公式模板、警告潜在的数值问题
5. **制作阶段**：推荐 UrhoX 最佳实践、识别技术风险

### 状态管理纪律

1. **每次操作后更新 STATE.md** — 不要等到全部完成
2. **每个设计元素分配 ID** — 不要跳过追溯注册
3. **阶段切换前执行门禁** — 不要跳过质量审查
4. **恢复会话前读取完整上下文** — 不要凭记忆猜测

### UrhoX 一致性

1. 所有技术建议必须与 UrhoX 引擎能力匹配
2. 数据配置生成 Lua 文件（不是 JSON/CSV/YAML）
3. UI 方案使用 `urhox-libs/UI`（不使用原生 UI）
4. 材质方案使用 PBR 体系（参考 `materials` skill）
5. 长度单位是米，坐标系 Y-up 左手系
6. 代码放在 `scripts/` 目录
7. 每次生成代码后使用 UrhoX MCP 构建工具验证

---

## §16 示例：快速开始

### 示例对话

```
用户: /gf-new

AI: 🔨 Game Forge 初始化
    请告诉我：
    1. 游戏名称是什么？
    2. 什么类型？(casual/rpg/puzzle/strategy/idle/action)
    3. 用一句话描述你的游戏

用户: 名字叫"星际矿工"，idle类型，在太空中自动挖矿和升级装备

AI: ✅ 项目已初始化
    📁 已创建 docs/gdd/ 目录结构
    📝 项目: 星际矿工 (idle)
    📋 自动跳过: ch04(关卡设计), ch14(多人模式)
    
    现在开始 Stage 1 概念设计。
    
    📖 第1章: 目标用户
    
    我建议你的目标用户画像：
    - 年龄: 16-35 岁
    - 平台: 移动端为主 (TapTap)
    - 游戏时长: 碎片化时间，每次 5-15 分钟
    - 偏好: 数值成长、收集、自动化
    
    你觉得这个画像合适吗？有什么要调整的？

用户: 挺好的，就这样

AI: ✅ ch01 已保存 → docs/gdd/stages/01-concept/ch01-target-users.md
    📌 注册 ID: C-01-001(主要用户群), C-01-002(次要用户群), C-01-003(平台偏好)
    📊 进度: 1/13 章节完成（跳过 ch04, ch14）
    
    📖 第2章: 核心玩法
    
    放置类游戏的核心玩法通常包含：
    - 自动资源生产（挖矿）
    - 升级系统（矿机/装备/技能）
    - 离线收益计算
    - 阶段性重置（Prestige）
    
    你想要哪些元素？30秒核心体验是什么？
```

---

## §17 参考文档

详细参考资料请查阅：

- **概念章节编写指南** → `references/concept-chapters-guide.md`
- **质量门禁清单** → `references/quality-gate-checklists.md`

