---
name: dev-tools-pack
description: >-
  UrhoX Lua 游戏开发者生产力工具集，提供六大自动化工具加速开发流程。
  灵感来自 Web 开发者工具链，为游戏开发场景深度定制。
  Use when users need to
  (1) 生成游戏模块脚手架/模板代码（背包系统、对话系统、存档系统、敌人AI、状态管理等常用子系统）,
  (2) 审查/review 游戏代码质量（检查常见 UrhoX Lua 陷阱、性能问题、最佳实践合规性）,
  (3) 生成游戏设计文档/GDD（核心玩法、进度系统、技术架构、系统交互图）,
  (4) 生成 TapTap 商店描述和发布文案（游戏简介、特色亮点、分类标签建议）,
  (5) 生成开发日志/变更记录（记录开发进度、版本迭代、功能变更摘要）,
  (6) 生成游戏推广文案（社交媒体推文、版本更新公告、特色功能介绍）,
  (7) 用户说 "dev tools"、"开发工具"、"生成模块"、"代码审查"、"review"、"设计文档"、"GDD"、
      "商店描述"、"开发日志"、"changelog"、"推广文案"、"宣传语",
  (8) 用户需要快速搭建游戏子系统的标准化代码框架,
  (9) 用户说 "帮我写个 XX 系统" 且该系统是通用游戏子系统（非核心玩法逻辑）。
---

# Dev Tools Pack — UrhoX Lua 游戏开发者工具集

六大生产力工具，覆盖游戏开发全生命周期：编码 → 审查 → 设计 → 发布 → 记录 → 推广。

## 工具总览

| # | 工具 | 对应场景 | 触发关键词 |
|---|------|---------|-----------|
| 1 | **Game Module Scaffold** | 生成通用游戏模块模板代码 | "生成模块"、"XX系统"、"scaffold" |
| 2 | **Game Code Review** | 审查代码质量和 UrhoX 合规性 | "review"、"审查"、"检查代码" |
| 3 | **Game Design Doc** | 生成结构化游戏设计文档 | "设计文档"、"GDD"、"策划案" |
| 4 | **TapTap Store Listing** | 生成商店页面文案 | "商店描述"、"发布文案"、"游戏简介" |
| 5 | **Dev Log Generator** | 生成开发日志/变更记录 | "开发日志"、"changelog"、"更新日志" |
| 6 | **Game Promo Copy** | 生成推广文案 | "推广文案"、"宣传语"、"更新公告" |

---

## Tool 1: Game Module Scaffold — 游戏模块脚手架生成器

根据用户需求生成标准化的 Lua 游戏子系统模块，遵循 UrhoX 最佳实践。

### 触发条件

用户需要创建通用游戏子系统（非核心玩法逻辑），如：
- 背包/物品管理、对话系统、存档/加载、敌人 AI
- 成就系统、任务系统、商店系统、buff/debuff 管理
- 场景切换、对象池、事件总线

### 生成规范

1. **输出位置**: `scripts/` 目录下，按功能分子目录
2. **命名规范**: PascalCase 模块名（如 `InventoryManager.lua`）
3. **模块结构**: 统一使用 `local M = {}` / `return M` 模式
4. **类型标注**: 所有 nil 初始化的变量必须加 `---@type` 注解
5. **事件清理**: 提供 `M.Cleanup()` 函数释放资源和取消事件订阅

### 标准模块模板

```lua
-- scripts/Systems/ModuleName.lua
-- 模块简述（一行说明）

local M = {}

-- ─── 配置 ─────────────────────────────────────────────
local CONFIG = {
    -- 可调参数集中在此
}

-- ─── 内部状态 ─────────────────────────────────────────
---@type Scene
local scene_ = nil

-- ─── 公共接口 ─────────────────────────────────────────

--- 初始化模块
---@param scene Scene
---@param opts? table
function M.Init(scene, opts)
    scene_ = scene
    opts = opts or {}
    for k, v in pairs(opts) do CONFIG[k] = v end
end

--- 每帧更新（如需要）
---@param dt number
function M.Update(dt)
end

--- 清理资源
function M.Cleanup()
    scene_ = nil
end

return M
```

### 可用模块模板

详细的模块模板（对象池、事件总线、状态机管理器、存档系统等）参见 [references/module-templates.md](references/module-templates.md)。

---

## Tool 2: Game Code Review — UrhoX Lua 代码审查

对游戏代码进行系统性审查，聚焦 UrhoX 特有的陷阱和 Lua 最佳实践。

### 触发条件

用户请求代码审查、review、质量检查、检查代码问题。

### 审查流程

```
1. READ    — 完整阅读 scripts/ 下所有用户代码
2. CHECK   — 逐项检查审查清单
3. SCORE   — 按类别评分（1-5）
4. REPORT  — 输出结构化报告 + 修复建议
```

**关键规则**: 仅审查 `scripts/` 及用户自建目录，忽略 `engine-docs/`、`urhox-libs/`、`examples/` 等引擎目录。

### 审查清单（按优先级）

#### P0: 致命问题（必修复）

| 检查项 | 常见错误 | 正确做法 |
|--------|---------|---------|
| 数组索引 | `array[0]` 返回 nil | 从 `1` 开始 |
| eventData 访问 | 直接索引 `eventData.X` | `eventData["X"]:GetInt()` |
| NanoVG 渲染事件 | 在 Update 中绘制 | 使用 `NanoVGRender` 事件 |
| NanoVG 字体 | 每帧调用 `nvgCreateFont` | 仅初始化时创建一次 |
| 鼠标按钮判断 | `button == 0` | `button == MOUSEB_LEFT` |
| 碰撞体位置 | 碰撞体在子节点 | Box2D 碰撞体与 RigidBody2D 同节点 |
| nil 变量访问 | `local x = nil; x:Method()` | 加 `---@type` 或初始化赋值 |

#### P1: 重要问题（强烈建议修复）

| 检查项 | 说明 |
|--------|------|
| 禁用分辨率 API | 不要调用已禁用的分辨率设置，改用 `GetWidth()/GetHeight()/GetDPR()` |
| 资源路径前缀 | 不应加 `assets/` 或 `scripts/` 前缀 |
| 硬编码数字枚举 | 使用 `KEY_*`、`MOUSEB_*`、`BT_*` 等枚举 |
| 手动第三人称相机 | 使用 `ThirdPersonCamera` 库 |
| 原生 UI 系统 | 已废弃，使用 `urhox-libs/UI` |
| 单文件超 1500 行 | 需拆分为模块 |

#### P2: 建议优化

| 检查项 | 说明 |
|--------|------|
| table.unpack 位置 | 仅在表构造器最后位置完全展开 |
| 全局变量污染 | 使用 `local` 限制作用域 |
| 重复代码 | 提取为函数或模块 |
| 魔法数字 | 提取为 CONFIG 常量 |
| 缺少 Cleanup | 事件订阅未取消、资源未释放 |

### 报告格式

```markdown
## 代码审查报告

### 评分总览
| 类别 | 得分 | 说明 |
|------|------|------|
| 正确性 | ?/5 | API 使用是否正确 |
| 安全性 | ?/5 | 无崩溃/nil 风险 |
| 架构   | ?/5 | 模块化、职责分离 |
| 性能   | ?/5 | 无明显性能瓶颈 |
| 规范性 | ?/5 | 遵循 UrhoX 最佳实践 |

### P0 致命问题（共 N 项）
[文件:行号] 问题描述 → 修复建议

### P1 重要问题（共 N 项）
...

### P2 建议优化（共 N 项）
...

### 推荐行动
1. 优先修复 P0 项
2. ...
```


完整的审查清单和评分标准参见 [references/review-checklist.md](references/review-checklist.md)。
---

## Tool 3: Game Design Doc — 游戏设计文档生成器

根据用户的游戏想法生成结构化的游戏设计文档（GDD）。

### 触发条件

用户需要 GDD、设计文档、策划案，或描述了游戏想法需要整理成文档。

### 生成流程

```
1. INTERVIEW — 收集关键信息（类型、平台、核心玩法）
2. GENERATE  — 生成 GDD 到 docs/gdd.md
3. REVIEW    — 与用户确认，迭代修改
```

### 必要信息收集（未提供则询问）

| 信息 | 示例 |
|------|------|
| 游戏类型 | 平台跳跃、射击、RPG、益智 |
| 核心玩法一句话 | "用手势切水果得分" |
| 屏幕方向 | 横屏 / 竖屏 |
| 单机/多人 | 单机 / 多人对战 / 多人合作 |

### GDD 标准结构

```markdown
# [游戏名称] — 游戏设计文档

## 1. 概述
- 一句话描述 / 游戏类型 / 屏幕方向 / 目标平台
- 核心体验关键词（3-5个）

## 2. 核心玩法
- 游戏循环（输入 → 反馈 → 目标）
- 操作方式 / 胜负条件

## 3. 游戏系统
- 系统列表及交互关系
- 每个系统的核心规则

## 4. 进度与经济
- 成长路径 / 资源类型与获取消耗

## 5. 内容规划
- 关卡/场景列表 / 角色/物品列表

## 6. 技术方案
- 脚手架选择 / 模块划分 / 第三方库

## 7. 里程碑
- MVP 功能列表 / 迭代计划（不含时间估算）
```

**输出位置**: `docs/gdd.md`

GDD 完整模板和信息收集清单参见 [references/gdd-and-publishing-guide.md](references/gdd-and-publishing-guide.md)。

---

## Tool 4: TapTap Store Listing — 商店页面文案生成器

为 TapTap 发布生成专业的游戏描述和元数据。

### 触发条件

用户准备发布游戏、需要商店描述、填写 `taptap_publish` 配置。

### 生成流程

1. 阅读 `scripts/` 中的游戏代码理解玩法
2. 若有 `docs/gdd.md` 则参考
3. 生成描述文案 + `taptap_publish` JSON 配置

### 描述模板

```
[一句话 Hook — 吸引注意力]

【核心玩法】
简述核心玩法循环，2-3 句话。

【游戏特色】
★ 特色1 — 简短描述
★ 特色2 — 简短描述
★ 特色3 — 简短描述

【适合谁玩】
目标玩家群体描述。
```

### 输出格式

文案文本 + `taptap_publish` JSON 配置片段：

```json
{
  "taptap_publish": {
    "title": "游戏名称",
    "description": "生成的描述...",
    "category": "推荐分类",
    "screen_orientation": "landscape 或 portrait"
  }
}
```

**支持的分类**: rpg, casual, action, strategy, simulation, trivia, arcade, adventure, card, sports, racing, puzzle, educational, music, word, board

商店文案模板和分类选择建议参见 [references/gdd-and-publishing-guide.md](references/gdd-and-publishing-guide.md)。

---

## Tool 5: Dev Log Generator — 开发日志生成器

根据代码变更生成结构化的开发日志。

### 触发条件

用户需要开发日志、changelog、更新记录，或完成了一轮开发迭代。

### 日志分类标签

| 标签 | 含义 | 示例 |
|------|------|------|
| `[新增]` | 新功能 | 添加背包系统 |
| `[修复]` | Bug 修复 | 修复跳跃时穿墙 |
| `[优化]` | 性能/体验优化 | 减少 Draw Call |
| `[调整]` | 数值/配置变更 | 提高移动速度 |
| `[重构]` | 代码结构调整 | 拆分为模块化架构 |
| `[美术]` | 视觉相关更新 | 更新角色贴图 |

### 输出格式

```markdown
## 开发日志 — YYYY-MM-DD

### 本次更新摘要
一句话总结核心变更。

### 变更详情
- [新增] 功能描述
- [修复] 修复内容描述
- [优化] 优化内容描述

### 技术备注
技术决策或架构变更（如有）。
```

**输出位置**: `docs/devlog.md`（追加到文件末尾）

开发日志分类标签和格式模板参见 [references/gdd-and-publishing-guide.md](references/gdd-and-publishing-guide.md)。

---

## Tool 6: Game Promo Copy — 游戏推广文案生成器

生成面向玩家的推广文本。

### 触发条件

用户需要推广文案、宣传语、更新公告、社交媒体文案。

### 文案类型

| 类型 | 格式 | 风格 |
|------|------|------|
| **游戏推介** | 3-5 条系列文案，每条 50-100 字 | 突出核心玩法，制造好奇心 |
| **版本更新公告** | 标题 + 亮点列表 + 号召语 | 简洁、信息密度高 |
| **特色功能介绍** | 功能名 + 一句话 + 体验描述 | 聚焦单一卖点 |

### 写作原则

1. **玩家视角**: 描述体验而非技术实现
2. **具体生动**: "一刀 999" 优于 "高伤害"
3. **简洁有力**: 每句不超过 20 字
4. **动词优先**: "冲刺、跳跃、斩杀" 优于 "拥有冲刺功能"
5. **无 emoji**: 除非用户明确要求

推广文案模板（推介/公告/功能介绍）参见 [references/gdd-and-publishing-guide.md](references/gdd-and-publishing-guide.md)。

---

## 与其他 Skill 的协作

| 需求 | 路由到 |
|------|--------|
| 具体 bug 修复 | `game-debugging` |
| 深度性能优化 | `game-performance` |
| 系统架构设计 | `game-architect-v2` |
| 游戏质量评审 + 改进 | `game-review-improve` |
| 音频系统搭建 | `audio-manager` |
| UI 界面开发 | 使用 `urhox-libs/UI` 组件 |
| 动画状态机配置 | `setup-fsm` |
| 材质/贴图设置 | `materials` |

## 重要约束

1. **Lua 代码输出到 `scripts/`** — 禁止写入发布产物目录，禁止生成 HTML
2. **文档输出到 `docs/`** — GDD、devlog 等 Markdown 文件
3. **遵循 UrhoX 引擎规则** — 代码生成符合 CLAUDE.md 全部规则
4. **生成代码后必须 build** — 调用 UrhoX MCP build 工具
