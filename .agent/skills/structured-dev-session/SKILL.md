---
name: structured-dev-session
description: >-
  UrhoX Lua 游戏项目的结构化开发任务管理器。
  灵感源自 clawhub code-dev 的 Git 分支开发流程，适配为 UrhoX 沙箱环境下的
  门控式开发 Session 管理。将"接到任务 → 分析 → 理解代码 → 实施 → 审查 → 保存版本"
  编排为强制阶段流水线，每个阶段有明确准入/准出标准，防止跳步导致低质量交付。
  Use when users need to
  (1) 开发一个预估工作量较大的功能（涉及 3+ 文件或 30+ 分钟）,
  (2) 修复一个复杂 bug 需要系统性调研,
  (3) 重构现有代码结构,
  (4) 用户说"开发"、"实现"、"新功能"、"修复"、"重构"且任务复杂度较高,
  (5) 用户说"按流程开发"、"结构化开发"、"走完整流程",
  (6) 需要确保开发过程有审查和版本保存。
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  tags: [development-workflow, code-quality, structured-process, task-management]
---

# Structured Dev Session — 结构化开发任务管理

> 灵感源自 [clawhub code-dev](https://clawhub.ai/luciuscao/code-dev) 的 Git 分支工作流，
> 适配为 UrhoX 沙箱环境下的门控式开发 Session 管理。
>
> 核心理念：**每个开发任务都是一个 Session，每个 Session 必须走完所有阶段。**

## 核心价值

| 问题 | 本 Skill 解决方案 |
|------|-----------------|
| 拿到需求就直接写代码，漏看已有实现 | Phase 2 强制代码库理解 |
| 改了 bug 没找到根因，改一处坏三处 | Phase 3 强制根因调研 |
| 代码写完就交付，没有自审 | Phase 6 强制 Code Review |
| 改完代码忘记保存版本 | Phase 7 强制版本保存 |
| 不确定任务是否需要走完整流程 | 复杂度路由自动判断 |

## 触发条件

**同时满足以下条件时触发**：

1. **意图关键词**：用户提到"开发"、"实现"、"新功能"、"修复"、"重构"、"提交"
2. **复杂度门槛**（满足其一）：
   - 预估涉及 **3 个以上文件** 的修改
   - 预估工作量 **超过 30 分钟**
   - 用户明确要求走完整流程

**不触发**（转交其他 skill）：

| 场景 | 转交 |
|------|------|
| 单文件小改动、配置更新、简单 bug | 直接修改，无需本 Skill |
| 用户说"保存代码"、"git save" | `@org_git-save` |
| 用户说"同步到 GitHub" | `github-git-sync` |
| 用户说"review 我的游戏"、"给我打分" | `game-review-improve` |
| 用户说"帮我做一个游戏"（从零开始） | `game-dev-planner` |
| 用户说"帮我调试这个 bug"（已知 bug） | `game-debugging` |
| 代码重构/命名/模块化 建议 | `software-engineering-lua` |

## 七阶段流水线

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase 1  ANALYZE    任务分析 — 确定类型、范围、分类标签        │
│  Phase 2  UNDERSTAND 代码库理解 — 已有实现、可复用模块、影响面   │ ← feature/refactor 必需
│  Phase 3  DIAGNOSE   根因调研 — Bug 表现、触发条件、根因定位     │ ← fix 必需
│  Phase 4  SNAPSHOT   快照当前状态 — 开发前版本存档               │
│  Phase 5  IMPLEMENT  开发实施 — 最小修改、遵循引擎规则、构建验证  │
│  Phase 6  REVIEW     代码审查 — 自审清单、修复问题、循环直到通过  │
│  Phase 7  SAVE       版本保存 — 提交描述、版本存档               │
└─────────────────────────────────────────────────────────────────┘
```

**门控规则**：
- Phase 2 仅 **feature/refactor** 类型需要执行
- Phase 3 仅 **fix** 类型需要执行
- Phase 4-7 所有类型都必须执行
- **不得跳过任何必需阶段**

---

## Phase 1: ANALYZE — 任务分析

**目标**：理解任务全貌，确定分类和范围。

**步骤**：

1. **解析用户需求**，提取关键信息
2. **确定任务类型**：

| 类型 | 标签 | 说明 |
|------|------|------|
| 新功能 | `feature` | 增加新的游戏功能或系统 |
| 修复 | `fix` | 修复已有 bug 或错误行为 |
| 重构 | `refactor` | 改善代码结构，不改变外部行为 |
| 文档 | `docs` | 更新或新增项目文档 |

3. **评估影响范围**：列出可能涉及的文件
4. **生成 Session 标签**（用于日志和版本提交）：

```
格式: {type}/{short-name}
示例: feature/enemy-ai-patrol
      fix/jump-collision-ground
      refactor/split-main-modules
      docs/api-reference
```

5. **输出 Session 概要**，请用户确认后进入下一阶段

**准出标准**：
- [ ] 任务类型已确定
- [ ] Session 标签已生成
- [ ] 影响范围已初步评估
- [ ] 用户已确认理解无误

---

## Phase 2: UNDERSTAND — 代码库理解（feature/refactor 必需）

**目标**：充分理解现有代码，避免重复造轮子或破坏已有功能。

**步骤**：

1. **阅读全部相关文件**（不是 skim，是完整阅读）：
   ```
   scripts/          ← 用户游戏代码（核心）
   assets/           ← 资源文件（如涉及）
   ```

2. **检查可复用资源**：
   - `urhox-libs/` 中是否有现成工具
   - 项目内是否有可复用的 helper/util 函数
   - `examples/` 中是否有类似实现可参考

3. **分析影响面**：
   - 新功能会影响哪些现有系统？
   - 是否有事件订阅/全局状态会被影响？
   - 是否需要修改 UI 布局？

4. **记录发现**（以注释或简要笔记形式）

**准出标准**：
- [ ] 所有相关源文件已完整阅读
- [ ] 可复用模块已识别
- [ ] 影响面已分析，无遗漏
- [ ] 如有架构疑问，已与用户确认

---

## Phase 3: DIAGNOSE — 根因调研（fix 必需）

**目标**：找到 bug 的真正根因，而非表面症状。

> 安全规则：未找到根因前，不得开始修复代码。盲目修复 = 制造新 bug。

**步骤**：

1. **确认 Bug 表现**：
   - 预期行为 vs 实际行为
   - 错误信息（完整复制）
   - 复现步骤

2. **定位触发条件**：
   - 什么操作触发？（输入事件、时序、边界值）
   - 是否每次都复现？（确定性 vs 随机性）

3. **追踪根因**：
   - 从错误点向上追溯调用链
   - 检查状态变量的值变化
   - 添加诊断日志 `print("[DEBUG]", ...)`

4. **验证假设**：
   - 提出根因假设
   - 设计最小验证实验
   - 确认根因

**准出标准**：
- [ ] 根因已定位到具体行/函数
- [ ] 触发条件已明确
- [ ] 修复方案已设计（不引入新问题）
- [ ] 向用户报告根因和修复方案

---

## Phase 4: SNAPSHOT — 开发前快照

**目标**：在修改代码前保存当前状态，确保可回退。

**步骤**：

1. **调用 `@org_git-save` 或 `github-git-sync`**（如已配置远程仓库）
   - 提交信息格式：`snapshot: before {session-label}`
   - 示例：`snapshot: before feature/enemy-ai-patrol`

2. **如果未配置远程仓库**，至少做本地 git commit：
   ```bash
   cd /workspace
   git add -A
   git commit -m "snapshot: before {session-label}"
   ```

3. **记录当前文件状态**（用于 Phase 6 对比）

**准出标准**：
- [ ] 当前代码已保存（git commit 或远程推送）
- [ ] 提交信息包含 Session 标签

---

## Phase 5: IMPLEMENT — 开发实施

**目标**：高质量实现需求，遵循引擎规则。

**核心原则**：

| 原则 | 说明 |
|------|------|
| **最小修改范围** | 只改必须改的，不顺手重构无关代码 |
| **遵循引擎规则** | 严格遵守 CLAUDE.md 中的所有规则 |
| **边界清晰** | 新功能的边界在哪？不越界 |
| **添加日志** | 首次交付必须有调试日志 |

**步骤**：

1. **编写代码**：
   - 基于 Phase 2/3 的分析结果
   - 遵循项目现有的代码风格
   - 新增模块放在 `scripts/` 目录

2. **引擎规则检查**：
   - 文件放在 `scripts/` 目录
   - 使用 `urhox-libs/UI` 而非原生 UI
   - NanoVG 使用 `NanoVGRender` 事件
   - 数组索引从 1 开始
   - 使用枚举值而非数字
   - eventData 正确访问
   - 类型标注完整

3. **构建验证**：
   - **必须调用 UrhoX MCP `build` 工具**
   - 修复所有构建错误
   - 确认无运行时异常

4. **记录变更**：
   - 列出所有新增/修改的文件
   - 简要说明每个文件的变更内容

**准出标准**：
- [ ] 代码已编写完成
- [ ] 引擎规则全部通过
- [ ] 构建成功（已调用 build 工具）
- [ ] 变更清单已记录

---

## Phase 6: REVIEW — 代码审查

**目标**：自审代码质量，发现并修复问题。

> 灵感源自 code-dev 的 "code review → 循环直到无问题" 机制。

**审查清单**（完整清单见 `references/review-checklist.md`）：

### 正确性
- [ ] 逻辑处理了所有边界情况（nil、空表、索引越界）
- [ ] 错误处理明确，不静默吞掉异常
- [ ] 状态管理安全（无竞态、无悬空引用）

### 引擎合规
- [ ] 无 `SetMode` 调用
- [ ] 无 `io.` 调用（使用 `File` 替代）
- [ ] 数组索引从 1 开始
- [ ] 使用枚举常量而非数字
- [ ] eventData 使用 `GetInt()`/`GetFloat()` 模式
- [ ] 无 `Urho3D` 提及

### 游戏质量
- [ ] 游戏重启安全（状态正确重置）
- [ ] 资源路径正确（不加 `assets/` 或 `scripts/` 前缀）
- [ ] UI 使用 `urhox-libs/UI` 组件
- [ ] 内存安全（事件订阅有对应取消、定时器有清理）

### 代码质量
- [ ] 无魔法数字（硬编码常量）
- [ ] 无超长函数（>50 行应拆分）
- [ ] 无重复代码段（>5 行应提取）
- [ ] 命名清晰（变量名能表达意图）

**审查流程**：

```
执行审查清单
  ↓
发现问题？
  ├─ 是 → 修复问题 → 重新构建 → 再次审查（循环）
  └─ 否 → 进入 Phase 7
```

**循环上限**：最多 3 轮审查。如第 3 轮仍有问题，记录遗留问题并告知用户。

**准出标准**：
- [ ] 审查清单全部通过（或遗留问题已记录）
- [ ] 最终构建成功
- [ ] 向用户报告审查结果

---

## Phase 7: SAVE — 版本保存

**目标**：保存开发成果，生成变更摘要。

**步骤**：

1. **生成提交描述**：
   ```
   格式: {type}: {简要描述}

   示例:
     feature: 添加敌人巡逻 AI 系统
     fix: 修复跳跃落地检测偶发失败
     refactor: 将 main.lua 拆分为模块化结构
     docs: 添加游戏配置说明文档
   ```

2. **调用版本保存**：
   - 优先使用 `@org_git-save` 或 `github-git-sync`（如已配置）
   - 否则做本地 git commit
   - 提交信息使用上述格式

3. **输出 Session 报告**：

   ```
   ═══════════════════════════════════
   Session 完成: {session-label}
   ═══════════════════════════════════
   类型: {feature/fix/refactor/docs}
   描述: {一句话总结}
   ───────────────────────────────────
   变更文件:
     + scripts/enemy/patrol.lua      (新增, 120行)
     ~ scripts/main.lua              (修改, +15/-3)
     ~ scripts/game/spawner.lua      (修改, +8/-2)
   ───────────────────────────────────
   审查结果: 通过 (2轮)
   版本保存: 已提交
   ═══════════════════════════════════
   ```

**准出标准**：
- [ ] 代码已保存到版本控制
- [ ] Session 报告已输出
- [ ] 用户已确认交付

---

## 复杂度路由

不是所有任务都需要走完整 7 阶段流程。

| 复杂度 | 判定标准 | 走哪些阶段 |
|--------|---------|-----------|
| **简单** | 单文件修改、<10行改动、配置更新 | 不触发本 Skill，直接修改 |
| **中等** | 2-3 文件、明确需求、无需调研 | Phase 1 → 5 → 6 → 7（跳过 2/3/4） |
| **复杂** | 3+ 文件、需理解现有代码、高影响面 | 全部 7 阶段 |

**自动判定逻辑**：

```
涉及文件数 > 3 或 预估 > 30 分钟？
  ├─ 是 → 完整流程（7 阶段）
  └─ 否 → 精简流程（4 阶段）
         └─ 用户是否要求"走完整流程"？
              ├─ 是 → 完整流程
              └─ 否 → 维持精简流程
```

---

## 与其他 Skill 的协作

| 阶段 | 可协作的 Skill | 协作方式 |
|------|--------------|---------|
| Phase 2 (理解) | `software-engineering-lua` | 识别代码异味，建议改进点 |
| Phase 3 (调研) | `game-debugging` | 使用系统化调试方法论 |
| Phase 4/7 (快照/保存) | `@org_git-save` / `github-git-sync` | 执行实际版本控制 |
| Phase 5 (实施) | `auto-workflow` | 自动生成样板代码 |
| Phase 5 (实施) | `game-design-patterns` | 选择合适的架构模式 |
| Phase 6 (审查) | `game-review-improve` | 扩展审查到游戏体验层面 |

**关键区别**：
- 本 Skill 是**流程编排器**，负责"按什么顺序做"
- 其他 Skill 是**专项工具**，负责"某一步怎么做好"
- 本 Skill 调度其他 Skill，而非替代它们

---

## 实战示例

### 示例 1: feature — 添加敌人巡逻 AI

```
用户: "给我的游戏加一个敌人巡逻功能，敌人在几个路径点之间来回走"

Phase 1 (ANALYZE):
  类型: feature
  标签: feature/enemy-patrol
  范围: scripts/main.lua, 新增 scripts/enemy/patrol.lua

Phase 2 (UNDERSTAND):
  阅读 main.lua — 发现已有 spawnEnemy() 函数
  检查 urhox-libs/ — 无现成巡逻组件
  分析影响面 — 需要在 HandleUpdate 中调用巡逻更新

Phase 4 (SNAPSHOT):
  git commit "snapshot: before feature/enemy-patrol"

Phase 5 (IMPLEMENT):
  创建 scripts/enemy/patrol.lua — PatrolController 模块
  修改 scripts/main.lua — 集成巡逻逻辑
  调用 build — 构建成功

Phase 6 (REVIEW):
  第 1 轮: 发现魔法数字 (速度 5.0) → 提取为 Config
  第 2 轮: 全部通过

Phase 7 (SAVE):
  git commit "feature: 添加敌人巡逻 AI 系统"
  Session 报告输出
```

### 示例 2: fix — 修复跳跃落地检测

```
用户: "角色跳跃后有时候落地检测失败，会穿过地面"

Phase 1 (ANALYZE):
  类型: fix
  标签: fix/jump-ground-detection
  范围: scripts/player/movement.lua

Phase 3 (DIAGNOSE):
  复现条件: 高速下落 + 薄平台
  根因: RigidBody2D 的 CCD 未开启，高速穿透
  修复方案: 设置 body.bullet = true

Phase 4 (SNAPSHOT):
  git commit "snapshot: before fix/jump-ground-detection"

Phase 5 (IMPLEMENT):
  修改 scripts/player/movement.lua — 添加 CCD
  调用 build — 构建成功

Phase 6 (REVIEW):
  第 1 轮: 全部通过

Phase 7 (SAVE):
  git commit "fix: 开启 CCD 修复高速跳跃穿透地面"
```

---

## 引用

- 完整代码审查清单 → `references/review-checklist.md`
- 开发 Session 详细指南 → `references/dev-session-guide.md`
