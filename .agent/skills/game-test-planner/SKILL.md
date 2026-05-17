---
name: game-test-planner
description: |
  游戏测试用例规划与执行编排器，灵感源自 multi-agent-game-tester 的
  Plan-Rank-Execute 三阶段多 Agent 流水线。为 UrhoX Lua 游戏项目
  自动生成结构化测试用例（输入验证、物理碰撞、UI 交互、音频播放、
  性能边界、状态机转换等），按优先级/可行性排序，输出可人工执行的
  测试步骤清单与预期结果，最终汇总为测试报告。

  Use when users need to (1) 为游戏自动生成测试用例,
  (2) 对游戏功能进行系统性测试规划,
  (3) 按优先级排列测试任务,
  (4) 生成可执行的测试步骤清单,
  (5) 对发布前的游戏进行覆盖度检查,
  (6) 为特定模块（物理/UI/输入/音频）规划专项测试,
  (7) 检测游戏中可能遗漏的边界条件。

  MUST trigger when:
    - 用户说"生成测试用例"、"测试规划"、"测试计划"
    - 用户说"test plan"、"test cases"、"generate tests"
    - 用户说"帮我测试一下游戏"、"全面测试"、"系统性测试"
    - 用户说"测试覆盖"、"边界测试"、"回归测试"
    - 用户说"plan tests"、"test coverage"

  trigger-keywords:
    - 测试用例
    - 测试规划
    - 测试计划
    - 生成测试
    - test plan
    - test cases
    - generate tests
    - 全面测试
    - 系统性测试
    - 测试覆盖
    - 边界测试
    - 回归测试
    - 测试步骤
    - test coverage
    - plan tests
    - 测试清单
version: "1.0"
metadata:
  categories: [game-development, testing, quality-assurance]
  tags: [urho, lua, test, planning, prioritization, coverage, qa]
---

# Game Test Planner — 游戏测试用例规划与执行编排器

> **灵感来源**: [multi-agent-game-tester](https://github.com/prithvi-18/multi-agent-game-tester) — 多 Agent 自动化游戏测试系统
>
> **核心理念**: 将 Plan → Rank → Execute 三阶段流水线适配到 UrhoX Lua 游戏开发中，
> 由 AI 扮演 Planner（规划者）、Ranker（排序者）、Executor（执行者）三个 Agent 角色，
> 自动生成测试用例、按优先级排序、输出可操作的测试执行清单与验收标准。

---

## 目录

1. [概述与定位](#1-概述与定位)
2. [与现有 Skill 的边界](#2-与现有-skill-的边界)
3. [三阶段流水线架构](#3-三阶段流水线架构)
4. [Phase 1: Planner — 测试用例生成](#4-phase-1-planner--测试用例生成)
5. [Phase 2: Ranker — 优先级排序](#5-phase-2-ranker--优先级排序)
6. [Phase 3: Executor — 测试执行清单](#6-phase-3-executor--测试执行清单)
7. [测试分类体系](#7-测试分类体系)
8. [引擎规则交叉验证矩阵](#8-引擎规则交叉验证矩阵)
9. [测试报告模板](#9-测试报告模板)
10. [快速测试模式](#10-快速测试模式)
11. [自定义测试配置](#11-自定义测试配置)
12. [使用示例](#12-使用示例)
13. [引擎规则速查表](#13-引擎规则速查表)

---

## 1. 概述与定位

### 1.1 这个 Skill 做什么

Game Test Planner 将 multi-agent-game-tester 的三阶段流水线适配到 UrhoX 游戏开发中：

| 阶段 | Agent 角色 | 职责 | 对标原项目 |
|------|-----------|------|-----------|
| **Phase 1** | Planner（规划者） | 扫描代码，生成 8-20 个结构化测试用例 | PlannerAgent |
| **Phase 2** | Ranker（排序者） | 按重要性/可行性/风险评分排序 | RankerAgent |
| **Phase 3** | Executor（执行者） | 输出可人工执行的测试步骤清单 | ExecutorAgent |
| **编排** | Orchestrator（协调者） | 协调三阶段流程，汇总最终报告 | OrchestratorAgent |

### 1.2 核心价值

- **系统性**: 从 9 个维度自动发现测试盲点，不依赖开发者的测试直觉
- **优先级驱动**: 高风险用例优先测试，有限时间内覆盖最关键路径
- **引擎感知**: 内置 UrhoX 引擎的 16 条关键规则检查，发现引擎特有的陷阱
- **可执行**: 输出的测试步骤精确到操作+预期结果，可直接交给测试人员

### 1.3 不做什么

| 不做 | 应该用 |
|------|--------|
| 自动修复代码 BUG | `game-bug-checker` Skill |
| 静态代码扫描（17 类 BUG 模式） | `game-bug-checker` Skill |
| RPG 子系统专项测试（Trie/骰子/决策树） | `ai-game-tester` Skill |
| 运行时指标采集与人机对比 | `game-tester-ai` Skill |
| 发布前合规检查（50+ 规则） | `pre-release-check` Skill |
| 事后 BUG 调试方法论 | `game-debugging` Skill |
| 性能 Profiling 与优化 | `game-performance` Skill |
| 多角色专家评审 | `game-studio-review` Skill |

---

## 2. 与现有 Skill 的边界

### 2.1 定位对比

```
测试生命周期:

  代码编写 ─→ 静态扫描 ─→ [测试规划] ─→ 运行测试 ─→ 发布检查
                 │             │              │            │
            game-bug-checker  本Skill    game-tester-ai  pre-release-check
                              ↑
                         当前所在环节
```

### 2.2 详细边界

| Skill | 焦点 | 本 Skill 的差异 |
|-------|------|----------------|
| `game-bug-checker` | 代码**静态**扫描，模式匹配 17 类 BUG | 本 Skill 生成**行为级**测试用例，验证功能正确性 |
| `ai-game-tester` | RPG 专属测试（法术/骰子/决策树） | 本 Skill 覆盖**通用**游戏类型（2D/3D/UI/物理/输入） |
| `game-tester-ai` | 运行时**指标采集**与人机行为识别 | 本 Skill 在运行**之前**规划测试策略 |
| `pre-release-check` | 发布前**合规**检查（屏幕适配/硬件交互） | 本 Skill 关注**功能**测试覆盖，非合规条目 |
| `game-debugging` | 已知 BUG 的**事后**调查流程 | 本 Skill 是**事前**主动发现潜在问题 |
| `game-performance` | 性能**瓶颈定位**与优化方案 | 本 Skill 包含性能边界测试但不做优化 |

### 2.3 协作模式

```
推荐的测试全流程:

  game-bug-checker    →  game-test-planner  →  人工测试执行  →  pre-release-check
  (静态扫描修复)         (规划测试用例)          (按清单测试)       (发布合规检查)
                              ↓
                      game-tester-ai (可选：运行时指标)
```

---

## 3. 三阶段流水线架构

### 3.1 流程总览

```
                    ┌──────────────┐
                    │ Orchestrator │  ← 协调整个流程
                    │  （协调者）   │
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         v                 v                 v
   ┌───────────┐    ┌───────────┐    ┌───────────┐
   │  Phase 1  │    │  Phase 2  │    │  Phase 3  │
   │  Planner  │ →  │  Ranker   │ →  │ Executor  │
   │ (规划者)  │    │ (排序者)  │    │ (执行者)  │
   └───────────┘    └───────────┘    └───────────┘
        │                │                │
   生成8-20个         按3维度          输出可执行
   测试用例           评分排序         测试步骤
```

### 3.2 映射关系

| 原项目组件 | 本 Skill 适配 | 说明 |
|-----------|--------------|------|
| PlannerAgent + GPT-3.5 | AI 扫描代码 + 9 类测试模板 | 用引擎知识替代 LLM 泛化能力 |
| RankerAgent + 评分算法 | 3 维度加权评分（重要性/可行性/风险） | 适配游戏开发优先级 |
| ExecutorAgent + Playwright | 人工可执行的测试步骤清单 | UrhoX 无浏览器自动化，改为人工操作指南 |
| OrchestratorAgent + FastAPI | AI 顺序协调三阶段 | 单会话内完成，无需异步 |
| `test_count` 参数 | 用例数量配置（默认 12） | 保留原项目配置理念 |
| `execute_top_n` 参数 | 执行 Top-N 高优先级用例（默认 6） | 保留原项目筛选机制 |

---

## 4. Phase 1: Planner — 测试用例生成

### 4.1 输入

Planner 扫描用户游戏代码，提取以下信息：

```
扫描目标:
├── scripts/*.lua          # 用户游戏代码（主要）
├── scripts/**/*.lua       # 子目录模块
└── .project/settings.json # 多人/单机模式配置

提取信息:
├── 游戏类型识别（2D/3D/UI/混合）
├── 使用的引擎子系统（物理/输入/音频/NanoVG/UI）
├── 事件订阅列表（SubscribeToEvent 调用）
├── 状态机/游戏状态流转
├── 资源引用（纹理/模型/音效/字体）
├── 输入处理方式（轮询/事件/触摸）
└── 多人模式判断（multiplayer.enabled）
```

### 4.2 用例生成模板

每个测试用例包含以下结构（对标原项目 PlannerAgent 输出格式）：

```markdown
### TC-{ID}: {测试用例标题}

- **分类**: {9 类之一，见第7章}
- **目标**: {验证什么功能/行为}
- **前置条件**: {测试前需要的状态}
- **测试步骤**:
  1. {具体操作步骤}
  2. {具体操作步骤}
  3. ...
- **预期结果**: {应该观察到什么}
- **失败标准**: {什么情况算测试失败}
- **关联引擎规则**: {对应的 CLAUDE.md 规则编号，如 Rule #3}
```

### 4.3 智能生成策略

Planner 根据代码分析结果，自动选择测试侧重点：

| 代码特征 | 自动增加的测试类型 |
|---------|-------------------|
| 检测到 `SubscribeToEvent("NodeCollision"...)` | 碰撞边界测试 |
| 检测到 `input:GetKeyDown` / `input:GetMouseButtonDown` | 输入组合测试 |
| 检测到 `nvgBeginFrame` | NanoVG 渲染测试 |
| 检测到 `UI.Init` / `UI.Panel` | UI 布局适配测试 |
| 检测到 `cache:GetResource("Sound"...)` | 音频播放测试 |
| 检测到 `RigidBody` / `RigidBody2D` | 物理行为测试 |
| 检测到 `multiplayer.enabled = true` | 多人同步测试 |
| 检测到 `scene_:GetComponent("PhysicsWorld")` | 3D 物理测试 |
| 检测到 `scene_:GetComponent("PhysicsWorld2D")` | 2D 物理测试 |
| 代码超过 1000 行 | 模块间集成测试 |

---

## 5. Phase 2: Ranker — 优先级排序

### 5.1 三维度评分模型

对标原项目 RankerAgent 的评分机制，适配游戏开发场景：

| 维度 | 权重 | 评分标准（1-5） | 说明 |
|------|------|----------------|------|
| **重要性** (Importance) | 40% | 5=核心玩法路径, 1=装饰性功能 | 功能对游戏体验的影响程度 |
| **风险度** (Risk) | 35% | 5=涉及引擎陷阱/边界条件, 1=简单直觉性功能 | 出错概率与影响 |
| **可行性** (Feasibility) | 25% | 5=无需特殊环境可立即测试, 1=需要复杂前置 | 测试执行的难易度 |

### 5.2 评分公式

```
综合分 = 重要性 × 0.40 + 风险度 × 0.35 + 可行性 × 0.25
```

### 5.3 排序规则

1. 按综合分**降序**排列
2. 综合分相同时，**风险度**高的优先
3. 标记 Top-N（默认 6）为"必测"，其余为"建议测试"

### 5.4 风险度加权因子

以下场景自动获得风险加分：

| 场景 | 风险加分 | 原因 |
|------|---------|------|
| 涉及 `eventData` 访问 | +1 | Rule #3: tolua++ 绑定的特殊访问方式 |
| 涉及数组索引运算 | +1 | Rule #4: Lua 索引从 1 开始 |
| 使用了鼠标按钮判断 | +1 | Rule #12: MOUSEB_LEFT=1 不是 0 |
| NanoVG 渲染代码 | +1 | Rule #6: 必须在 NanoVGRender 事件中 |
| 使用 `SetMode()` | +2 | Rule #0.8: 已被禁用 |
| Box2D 碰撞形状 | +1 | 必须在同一 RigidBody2D 节点上 |
| 第三人称相机 | +1 | Rule #13.5: 必须使用 ThirdPersonCamera 库 |
| 多人/单机模式切换 | +1 | Rule #14: 必须读 settings.json |

---

## 6. Phase 3: Executor — 测试执行清单

### 6.1 输出格式

Executor 将排序后的 Top-N 测试用例转化为可执行的测试清单：

```markdown
## 测试执行清单

**项目**: {游戏名称}
**生成日期**: {日期}
**用例总数**: {N} 个（必测 {top_n} 个 + 建议 {rest} 个）
**预估测试时间**: {估算}

---

### [必测] TC-001: {标题} (综合分: 4.5)

**操作步骤**:
1. 启动游戏，等待主菜单加载完成
2. {具体操作...}
3. 观察 {预期行为...}

**预期结果**: {精确描述}

**通过标准**:
- [ ] {检查点 1}
- [ ] {检查点 2}

**失败时**: 记录截图，标记为 BUG，关联 Rule #{X}

---

### [建议] TC-007: {标题} (综合分: 2.8)
...
```

### 6.2 测试结果记录模板

```markdown
## 测试结果记录

| ID | 标题 | 优先级 | 结果 | 备注 |
|----|------|--------|------|------|
| TC-001 | {标题} | 必测 | PASS/FAIL/SKIP | {备注} |
| TC-002 | {标题} | 必测 | PASS/FAIL/SKIP | {备注} |
| ... | ... | ... | ... | ... |

**总结**:
- 通过: X / Y
- 失败: X / Y
- 跳过: X / Y
- 覆盖率: X%
```

---

## 7. 测试分类体系

### 7.1 九大测试分类

基于 UrhoX 引擎特性定义的 9 个测试分类：

| # | 分类 | 说明 | 典型测试内容 |
|---|------|------|-------------|
| C1 | **输入处理** | 键盘/鼠标/触摸输入 | 按键响应、鼠标模式切换、多点触控 |
| C2 | **物理碰撞** | 2D/3D 物理系统 | 碰撞检测、触发器、地面判定、刚体行为 |
| C3 | **UI 交互** | 界面元素行为 | 按钮点击、滑块拖动、列表滚动、布局适配 |
| C4 | **音频播放** | 声音系统 | BGM 切换、SFX 触发、音量控制、Web 自动播放 |
| C5 | **视觉渲染** | 图形渲染 | NanoVG 绘制、材质显示、相机视角、模型尺寸 |
| C6 | **状态流转** | 游戏状态 | 菜单→游戏→暂停→结束、分数统计、存档加载 |
| C7 | **性能边界** | 资源与性能 | 大量实体、快速创建/销毁、内存增长、帧率 |
| C8 | **数据持久化** | 存档/云同步 | 本地保存/加载、云变量同步、排行榜 |
| C9 | **多人同步** | 网络相关 | 客户端/服务端一致性、断线重连、延迟容忍 |

### 7.2 各分类的引擎规则关联

| 分类 | 关联的引擎规则 |
|------|--------------|
| C1 输入处理 | Rule #9（鼠标模式）、Rule #12（枚举值） |
| C2 物理碰撞 | `engine-docs/api/physics.md`、`engine-docs/api/Physics2D.md` |
| C3 UI 交互 | Rule #10（新 UI 系统）、Rule #0.8（分辨率） |
| C4 音频播放 | `engine-docs/api/audio.md`（Web 自动播放） |
| C5 视觉渲染 | Rule #6（NanoVG 事件）、Rule #7（字体创建）、Rule #9.1（模型尺寸）、Rule #9.6（材质 Technique） |
| C6 状态流转 | `engine-docs/principles.md`（状态机模式） |
| C7 性能边界 | `engine-docs/principles.md`（无逐帧分配、deltaTime） |
| C8 数据持久化 | `engine-docs/recipes/file-storage.md`、`engine-docs/recipes/client-cloud-score.md` |
| C9 多人同步 | Rule #14（多人模式判断） |

---

## 8. 引擎规则交叉验证矩阵

Planner 在生成测试用例时，自动交叉检查以下引擎规则：

### 8.1 必检规则（所有游戏类型）

| 检查项 | 规则来源 | 测试方法 |
|--------|---------|---------|
| eventData 使用 `["Key"]:GetType()` 语法 | Rule #3, `engine-docs/lua-scripting-guide.md` | 代码审查 + 事件触发验证 |
| 数组索引从 1 开始 | Rule #4, `engine-docs/lua-scripting-guide.md` | 数组遍历边界测试 |
| 鼠标按钮使用 `MOUSEB_LEFT` 等枚举 | Rule #12, `engine-docs/api/enums.md` | 鼠标点击响应测试 |
| 不使用 `graphics:SetMode()` | Rule #0.8, `engine-docs/lua-scripting-guide.md` | 代码审查 |
| UI 使用 `urhox-libs/UI` 而非原生 UI | Rule #10, `engine-docs/recipes/ui.md` | 代码审查 |
| 移动/速度计算乘以 deltaTime | `engine-docs/principles.md` | 不同帧率下行为一致性 |

### 8.2 条件检查规则

| 条件 | 检查项 | 规则来源 |
|------|--------|---------|
| 使用 NanoVG | 渲染在 NanoVGRender 事件中 | Rule #6 |
| 使用 NanoVG 文本 | `nvgCreateFont` 只调用一次 | Rule #7 |
| FPS/TPS 游戏 | 鼠标模式设为 MM_RELATIVE | Rule #9 |
| 使用 3D 模型 | 通过 boundingBox 获取尺寸 | Rule #9.1 |
| 程序化材质 | 使用 PBRNoTexture 系列 | Rule #9.6 |
| 第三人称相机 | 使用 ThirdPersonCamera 库 | Rule #13.5 |
| 多人游戏 | 先读 settings.json 判断模式 | Rule #14 |
| Box2D 物理 | 碰撞形状在同一节点 | `engine-docs/api/Physics2D.md` |
| 3D 物理 | 碰撞层/掩码正确配置 | `engine-docs/api/physics.md` |
| UI Flexbox | flexShrink 设为 1 防溢出 | `engine-docs/recipes/ui.md` |

### 8.3 常见错误模式检测

基于 `engine-docs/lua-scripting-guide.md` 常见错误信息：

| 错误模式 | 症状 | 对应测试 |
|---------|------|---------|
| `attempt to call method 'GetInt'` | eventData 访问方式错误 | C1/C6 事件处理测试 |
| `attempt to index a nil value` | 数组索引从 0 开始 | C6 数据遍历测试 |
| `Null pointer access` | 资源未找到或组件未创建 | C5/C6 资源加载测试 |
| `Stack index X out of range` | 函数参数类型/数量错误 | C1/C2 API 调用测试 |
| `Resource not found` | 资源路径错误 | C5/C4 资源引用测试 |
| NanoVG 文本不显示 | 未创建字体 | C5 NanoVG 渲染测试 |
| 按空格无法跳跃 | 碰撞体不在同一节点 | C2 物理碰撞测试 |
| 鼠标左键无响应 | 使用数字 0 而非 MOUSEB_LEFT | C1 输入响应测试 |

---

## 9. 测试报告模板

### 9.1 完整报告

```markdown
# 游戏测试报告

## 基本信息

| 项目 | 值 |
|------|------|
| **游戏名称** | {name} |
| **游戏类型** | {2D/3D/混合} |
| **文件数** | {N} 个 Lua 文件 |
| **代码行数** | {总行数} |
| **多人模式** | {是/否} |
| **使用子系统** | {物理/UI/NanoVG/音频/...} |

## 阶段 1: 测试用例清单 (Planner)

共生成 {total} 个测试用例，分布如下：

| 分类 | 数量 | 覆盖范围 |
|------|------|---------|
| C1 输入处理 | {n} | {覆盖的输入类型} |
| C2 物理碰撞 | {n} | {覆盖的物理场景} |
| ... | ... | ... |

{逐个列出测试用例}

## 阶段 2: 优先级排序 (Ranker)

| 排名 | ID | 标题 | 重要性 | 风险度 | 可行性 | 综合分 | 级别 |
|------|-----|------|--------|--------|--------|--------|------|
| 1 | TC-{X} | {标题} | 5 | 4 | 5 | 4.60 | 必测 |
| 2 | TC-{X} | {标题} | 4 | 5 | 4 | 4.35 | 必测 |
| ... | ... | ... | ... | ... | ... | ... | ... |

## 阶段 3: 测试执行清单 (Executor)

{逐个输出可执行测试步骤}

## 覆盖度分析

### 功能覆盖

| 维度 | 覆盖 | 未覆盖 |
|------|------|--------|
| 核心玩法路径 | {列举} | {列举} |
| 边界条件 | {列举} | {列举} |
| 错误处理 | {列举} | {列举} |

### 引擎规则覆盖

| 规则 | 已覆盖 | 未覆盖（不适用） |
|------|--------|-----------------|
| Rule #3 eventData | {是/否} | {原因} |
| Rule #4 数组索引 | {是/否} | {原因} |
| ... | ... | ... |
```

### 9.2 精简报告

```markdown
# 测试快报

**项目**: {name} | **类型**: {type} | **日期**: {date}

## 必测用例 ({top_n} 个)

| # | 标题 | 分类 | 综合分 | 关键检查点 |
|---|------|------|--------|-----------|
| 1 | {标题} | C{X} | 4.60 | {一句话描述} |
| 2 | {标题} | C{X} | 4.35 | {一句话描述} |
| ... | ... | ... | ... | ... |

## 建议测试用例 ({rest} 个)

{列表}

## 风险提示

- {引擎规则相关风险}
- {业务逻辑风险}
```

---

## 10. 快速测试模式

### 10.1 触发条件

当用户说"快速测试"、"简单测试一下"时，进入快速模式：

### 10.2 快速模式流程

```
快速模式: 扫描 → 生成5个核心用例 → 直接输出执行清单（跳过详细排序）
```

快速模式只关注：
1. 核心玩法路径（能否正常运行）
2. 引擎规则合规（6 项必检规则）
3. 最明显的边界条件（3 项）

### 10.3 快速报告模板

```markdown
# 快速测试清单

**文件**: {files}
**类型**: {type}

## 核心测试 (5 项)

| # | 测试 | 步骤 | 预期 | 通过 |
|---|------|------|------|------|
| 1 | 游戏能否启动 | 加载游戏 | 无报错，画面正常 | [ ] |
| 2 | 核心操作响应 | {具体操作} | {预期响应} | [ ] |
| 3 | 引擎规则检查 | 代码审查 | 无规则违反 | [ ] |
| 4 | 边界条件 | {具体操作} | {预期行为} | [ ] |
| 5 | 游戏结束/重启 | {具体操作} | {预期行为} | [ ] |

## 发现的问题

{如有引擎规则违反，列出}
```

---

## 11. 自定义测试配置

### 11.1 用例数量

用户可以指定生成的测试用例数量：

```
"生成20个测试用例"     → test_count = 20
"少量测试就行"         → test_count = 5（快速模式）
"完整测试"             → test_count = 16（默认完整模式）
```

对标原项目 `test_count` 参数，默认值 12。

### 11.2 执行数量

用户可以指定执行 Top-N 高优先级用例：

```
"只测最重要的3个"       → execute_top_n = 3
"全部都要测"           → execute_top_n = 全部
"按默认来"             → execute_top_n = 6
```

对标原项目 `execute_top_n` 参数，默认值 6。

### 11.3 指定分类

用户可以指定只关注某些测试分类：

```
"只测物理相关"          → 仅 C2
"UI和输入测试"          → C1 + C3
"网络同步专项"          → C9
"除了音频都测"          → C1-C8（跳过 C4）
```

### 11.4 指定深度

```
"浅层测试"              → 每分类最多 1 个用例
"标准测试"              → 每分类 1-3 个用例（默认）
"深度测试"              → 每分类 2-5 个用例
```

---

## 12. 使用示例

### 12.1 完整测试规划

**用户输入**: "帮我生成测试用例"

**AI 执行流程**:

```
Step 1: 扫描 scripts/ 目录，识别游戏类型和使用的引擎子系统
Step 2: [Planner] 根据代码分析生成 12 个测试用例
Step 3: [Ranker] 按重要性/风险/可行性三维度评分排序
Step 4: [Executor] 输出 Top-6 必测用例的执行清单
Step 5: 汇总测试报告
```

### 12.2 专项测试

**用户输入**: "测试一下物理碰撞"

**AI 执行流程**:

```
Step 1: 扫描代码中物理相关的代码
Step 2: [Planner] 生成 5-8 个 C2 分类测试用例
   - 碰撞检测准确性
   - 触发器进入/离开
   - 地面检测（foot sensor / raycast）
   - 碰撞层配置
   - 刚体类型（Static/Dynamic/Kinematic）
Step 3: [Ranker] 排序
Step 4: [Executor] 输出执行清单
```

### 12.3 快速烟雾测试

**用户输入**: "快速测试一下能不能玩"

**AI 执行流程**:

```
Step 1: 扫描核心文件
Step 2: 生成 5 个核心测试
Step 3: 直接输出快速清单（跳过排序细节）
```

---

## 13. 引擎规则速查表

以下是测试用例生成中最常引用的引擎规则：

### 13.1 高频引用规则

| 规则 | 说明 | 典型测试点 |
|------|------|-----------|
| #0 | 长度单位是米 | 物体尺寸/移动距离合理性 |
| #0.5 | Y-up 左手坐标系 | 方向/旋转计算正确性 |
| #0.8 | SetMode 已禁用 | 分辨率获取方式 |
| #3 | eventData 访问 | 事件处理函数正确性 |
| #4 | 数组索引从 1 | 循环/索引边界 |
| #6 | NanoVG 渲染事件 | NanoVG 图形显示 |
| #7 | NanoVG 字体创建 | 文本显示正确性 |
| #9 | 鼠标模式 | FPS/TPS 控制体验 |
| #9.1 | 模型尺寸 | 3D 物体定位准确性 |
| #10 | 新 UI 系统 | UI 组件使用 |
| #12 | 枚举值 | 输入事件处理 |
| #13.5 | 第三人称相机 | 相机跟随行为 |
| #14 | 多人模式判断 | 单机/多人代码分离 |

### 13.2 规则来源文档

| 规则编号 | 来源文档 |
|---------|---------|
| #0, #0.5, #0.8 | `engine-docs/lua-scripting-guide.md` |
| #3, #4, #4.5 | `engine-docs/lua-scripting-guide.md` |
| #6, #7 | `engine-docs/lua-scripting-guide.md`, `engine-docs/api/nanovg.md` |
| #9 | `engine-docs/api/input.md` |
| #9.1 | `engine-docs/built-in-models.md` |
| #9.6 | `.claude/skills/materials/SKILL.md` |
| #10 | `engine-docs/recipes/ui.md` |
| #12 | `engine-docs/api/enums.md` |
| #13.5 | `engine-docs/recipes/camera.md` |
| #14 | `engine-docs/lua-scripting-guide.md` |
| 物理 3D | `engine-docs/api/physics.md` |
| 物理 2D | `engine-docs/api/Physics2D.md` |
| 音频 | `engine-docs/api/audio.md` |
| 开发原则 | `engine-docs/principles.md` |

---

## 安全声明

本 Skill 仅执行代码分析和测试规划，不使用以下任何功能：
- 不使用 `eval`、`exec`、`subprocess`、`loadstring` 或动态执行函数
- 不使用 base64 编码/解码
- 不请求外部网络资源
- 不修改用户代码（只读分析）
- 不访问文件系统敏感路径
- 不生成可执行代码片段（输出的是人工操作步骤，非代码）

所有技术规则引用均来自以下引擎文档：
- `engine-docs/principles.md`
- `engine-docs/lua-scripting-guide.md`
- `engine-docs/recipes/ui.md`
- `engine-docs/recipes/camera.md`
- `engine-docs/recipes/file-storage.md`
- `engine-docs/recipes/client-cloud-score.md`
- `engine-docs/api/input.md`
- `engine-docs/api/audio.md`
- `engine-docs/api/physics.md`
- `engine-docs/api/Physics2D.md`
- `engine-docs/api/enums.md`
- `engine-docs/api/nanovg.md`
- `engine-docs/built-in-models.md`
- `.claude/skills/materials/SKILL.md`

---

*灵感来源: [multi-agent-game-tester](https://github.com/prithvi-18/multi-agent-game-tester) — Plan-Rank-Execute multi-agent game testing pipeline*
*适配引擎: UrhoX (Lua)*
*版本: 1.0*
*创建日期: 2026-05-16*
