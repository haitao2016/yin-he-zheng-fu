---
name: team-dev
description: >-
  多任务编排与结构化开发会话管理器，灵感源自 clawhub Dev Team 多智能体工作流。
  在 UrhoX 单 Agent 沙箱环境下，将大型游戏开发需求拆解为可追踪的子任务队列，
  按 PLAN → SPAWN → BUILD → REVIEW → FIXUP → ARCHIVE 六阶段流水线执行，
  每阶段有准入/准出门控、自动审查清单和任务状态机，防止跳步导致低质量交付。
  Use when users need to
  (1) 开发一个包含 3+ 独立功能模块的大型游戏项目,
  (2) 用户说"团队开发"、"多任务开发"、"并行开发"、"任务编排",
  (3) 用户说"dev team"、"team dev"、"task queue",
  (4) 用户提供了多个功能需求并希望系统化地逐步实现,
  (5) 项目代码预计超过 1000 行需要模块化拆分,
  (6) 用户希望每个功能模块都经过审查再合并,
  (7) 用户说"结构化开发"、"流水线开发"、"质量门控"。
metadata:
  version: "1.0.0"
  author: "vintlin"
  source: "https://clawhub.ai/vintlin/team-dev"
  tags: [task-orchestration, multi-task, structured-workflow, quality-gate, dev-team]
---

# Team Dev — 多任务编排与结构化开发

## 核心理念

将 **clawhub Dev Team 多智能体工作流** 适配到 UrhoX 单 Agent 沙箱环境：

| Dev Team 原版（多智能体） | Team Dev Skill（单 Agent 适配） |
|--------------------------|-------------------------------|
| 多 Agent 并行执行任务 | 单 Agent 按优先级串行切换子任务 |
| Git Worktree 隔离工作区 | 模块化文件隔离 `scripts/<module>/` |
| GitHub PR + CI 验证 | MCP `build` 工具 + LSP 检查 |
| `active-tasks.json` | `scripts/docs/task-registry.json` |
| PR 3 人 Review | 三维度自审（正确性/引擎合规/游戏品质） |
| Feishu/Slack 通知 | 终端输出 + 交付报告 |

## 六阶段流水线

```
┌───────┐    ┌───────┐    ┌───────┐    ┌────────┐    ┌───────┐    ┌─────────┐
│ PLAN  │───▶│ SPAWN │───▶│ BUILD │───▶│ REVIEW │───▶│ FIXUP │───▶│ ARCHIVE │
│ 规划  │    │ 执行  │    │ 构建  │    │ 审查   │    │ 修复  │    │ 归档    │
└───────┘    └───────┘    └───────┘    └────────┘    └───────┘    └─────────┘
   │              │            │            │             │             │
   ▼              ▼            ▼            ▼             ▼             ▼
 拆解需求     编写代码     调用build    三维度审查     修复问题     交付报告
 创建队列     模块隔离     LSP检查     合规检测      最多3轮     更新注册表
```

---

## 阶段 1: PLAN（规划）

### 准入条件
- 用户提供了明确的游戏开发需求

### 执行步骤

1. **需求分析**：理解用户的完整需求，识别独立功能模块
2. **任务拆解**：将需求拆分为 3-10 个可独立实现的子任务
3. **依赖排序**：识别任务间的依赖关系，确定执行顺序
4. **创建任务注册表**：在 `scripts/docs/task-registry.json` 创建任务队列

### 任务注册表结构

```json
{
  "projectName": "项目名称",
  "createdAt": "2025-01-01T00:00:00Z",
  "tasks": [
    {
      "taskId": "T001",
      "phase": "PLAN",
      "label": "任务简称",
      "description": "详细描述",
      "status": "queued",
      "priority": 1,
      "dependencies": [],
      "targetFiles": ["scripts/module/file.lua"],
      "acceptanceCriteria": ["验收条件1", "验收条件2"],
      "reviewResult": null,
      "reviewRounds": 0,
      "fixupCount": 0,
      "timestamps": {
        "queued": "2025-01-01T00:00:00Z",
        "started": null,
        "completed": null
      }
    }
  ],
  "summary": {
    "total": 0,
    "queued": 0,
    "running": 0,
    "done": 0,
    "failed": 0,
    "skipped": 0
  }
}
```

### 任务状态机

```
queued → running → done
                 → failed → queued (重试)
                 → skipped
```

### 准出条件
- 任务注册表已创建且所有任务状态为 `queued`
- 用户确认任务拆解合理
- 使用 TodoWrite 同步任务到 todo 列表

---

## 阶段 2: SPAWN（执行）

### 准入条件
- PLAN 阶段完成，任务注册表存在
- 当前无 `running` 状态的任务

### 执行步骤

1. **选取任务**：按优先级从队列中取出第一个 `queued` 任务
2. **状态更新**：将任务状态改为 `running`，记录开始时间
3. **模块隔离**：
   - 每个功能模块放在独立目录：`scripts/<module>/`
   - 主入口文件通过 `require` 引入各模块
   - 共享工具放在 `scripts/utils/`
4. **编写代码**：
   - 遵循 UrhoX 引擎核心规则 #0 ~ #14
   - 基于脚手架起手（规则 #2）
   - 代码存放在 `scripts/` 目录（规则 #1）
   - 添加日志（首次交付）
5. **TodoWrite 同步**：将当前任务标记为 `in_progress`

### 模块化目录规范

```
scripts/
├── main.lua                    # 主入口
├── docs/
│   └── task-registry.json      # 任务注册表
├── core/                       # 核心系统
│   ├── game_manager.lua
│   └── config.lua
├── player/                     # 玩家模块
│   ├── controller.lua
│   └── inventory.lua
├── enemy/                      # 敌人模块
│   ├── ai.lua
│   └── spawner.lua
├── ui/                         # UI 模块
│   ├── hud.lua
│   └── menu.lua
└── utils/                      # 共享工具
    └── helpers.lua
```

### 准出条件
- 代码已编写完成，文件放在正确目录
- 代码遵循引擎核心规则（特别关注规则 #1, #3, #4, #6, #10, #12）

---

## 阶段 3: BUILD（构建）

### 准入条件
- SPAWN 阶段的代码已编写完成

### 执行步骤

1. **调用 MCP build 工具**：这是 **强制步骤**，不可跳过
2. **检查构建结果**：
   - 构建成功 → 进入 REVIEW
   - 构建失败 → 修复错误，重新构建
3. **记录构建状态**

### 关键规则

```
🔴 每次代码修改后必须调用 build 工具！
   ✅ 写代码 → 调用 build → 检查结果
   ❌ 写代码 → 直接跳到 REVIEW（禁止！）
```

### 准出条件
- MCP build 工具调用成功
- 无 LSP 错误或警告（或已确认为误报）

---

## 阶段 4: REVIEW（审查）

### 准入条件
- BUILD 阶段通过

### 三维度审查

对当前任务的代码进行三个维度的审查：

#### 维度 1: 正确性审查

| 检查项 | 说明 |
|--------|------|
| 功能完整性 | 验收条件是否全部满足 |
| 边界处理 | nil 值、空数组、除零等 |
| 内存安全 | 无泄漏（每帧创建对象、未释放订阅等） |
| 逻辑正确 | 条件判断、循环边界、状态转换 |

#### 维度 2: 引擎合规审查

| 规则 | 检查内容 |
|------|---------|
| #0 长度单位 | 数值是否合理（米为单位） |
| #3 eventData | 使用 `GetInt()`/`GetFloat()` 而非直接索引 |
| #4 数组索引 | 从 1 开始，非 0 |
| #6 NanoVG 事件 | 使用 `NanoVGRender` 事件 |
| #7 NanoVG 字体 | `nvgCreateFont` 只调用一次 |
| #9.1 模型尺寸 | 使用 `boundingBox` 或查文档 |
| #9.6 材质路径 | 使用 `PBRNoTexture` 系列 |
| #10 UI 系统 | 使用 `urhox-libs/UI`，非原生 UI |
| #12 枚举值 | 使用 `MOUSEB_LEFT` 等枚举，非数字 |

#### 维度 3: 游戏品质审查

| 检查项 | 说明 |
|--------|------|
| 可玩性 | 操作手感、反馈是否流畅 |
| 视觉效果 | 无 Z-fighting、模型穿模等 |
| 性能 | 无每帧重复创建对象，无冗余计算 |
| 代码质量 | 命名规范、模块职责清晰 |

### 审查结果

```
PASS   → 进入 ARCHIVE
FIXUP  → 进入 FIXUP（附修复建议列表）
REJECT → 任务标记 failed，回到队列重新规划
```

### 详细审查清单
→ 见 `references/review-checklist.md`

### 准出条件
- 三维度审查全部 PASS
- 或标记为 FIXUP/REJECT 并记录原因

---

## 阶段 5: FIXUP（修复）

### 准入条件
- REVIEW 阶段结果为 FIXUP

### 执行步骤

1. **读取修复建议列表**
2. **逐项修复**
3. **重新 BUILD**（必须再次调用 build 工具）
4. **重新 REVIEW**

### 轮次限制

```
最多 3 轮 FIXUP
  第 1 轮: 修复 → BUILD → REVIEW
  第 2 轮: 修复 → BUILD → REVIEW
  第 3 轮: 修复 → BUILD → REVIEW → 若仍 FIXUP → 标记 failed，向用户报告
```

### 准出条件
- REVIEW 结果为 PASS
- 或达到 3 轮上限，标记 failed

---

## 阶段 6: ARCHIVE（归档）

### 准入条件
- REVIEW 结果为 PASS

### 执行步骤

1. **更新任务注册表**：
   - 任务状态改为 `done`
   - 记录完成时间
   - 更新 summary 计数
2. **更新 TodoWrite**：标记任务为 `completed`
3. **检查队列**：
   - 还有 `queued` 任务 → 回到 SPAWN 处理下一个
   - 队列为空 → 生成交付报告
4. **移除调试日志**（最终交付时）

### 交付报告模板

```markdown
# 项目交付报告

## 概览
- 项目名称: {projectName}
- 总任务数: {total}
- 完成: {done} | 失败: {failed} | 跳过: {skipped}

## 任务清单
| ID | 名称 | 状态 | 审查轮次 | 修复次数 |
|----|------|------|---------|---------|
| T001 | xxx | done | 1 | 0 |
| T002 | xxx | done | 2 | 1 |

## 文件结构
- scripts/core/ — 核心系统
- scripts/player/ — 玩家模块
- scripts/ui/ — UI 模块

## 注意事项
- {已知限制或后续建议}
```

### 准出条件
- 任务注册表 summary 无 `running` 状态
- 交付报告已生成（全部任务完成时）

---

## 与其他 Skill 的协作

| 阶段 | 可协作 Skill | 说明 |
|------|-------------|------|
| PLAN | `game-dev-planner` | 复杂项目可先用 planner 做顶层设计 |
| PLAN | `@zy_game-architect-v2` | 系统架构设计参考 |
| SPAWN | `materials` | 材质选择与配置 |
| SPAWN | `setup-fsm` | 动画状态机配置 |
| SPAWN | `audio-manager` | 音频系统集成 |
| REVIEW | `dev-tools-pack` | 代码审查增强 |
| ARCHIVE | `@org_git-save` | 版本保存 |

---

## 使用流程

### 快速开始

用户说"我要做一个包含 XX、YY、ZZ 功能的游戏"时：

1. 触发 Team Dev skill
2. 进入 PLAN 阶段，拆解为子任务队列
3. 用户确认后，按 SPAWN → BUILD → REVIEW → FIXUP → ARCHIVE 循环执行
4. 全部完成后输出交付报告

### 中途调整

- **添加任务**：在任务注册表追加新条目，状态为 `queued`
- **跳过任务**：将任务状态改为 `skipped`，记录原因
- **调整优先级**：修改 `priority` 字段，下次 SPAWN 自动生效
- **暂停/恢复**：当前 `running` 任务保持状态，下次会话继续

### 会话恢复

如果会话中断后恢复：

1. 读取 `scripts/docs/task-registry.json`
2. 找到 `running` 状态的任务 → 继续执行
3. 若无 `running` → 取下一个 `queued` 任务
4. 若全部 `done` → 检查是否需要最终交付

---

## 注意事项

1. **本 Skill 是流程管理层**，不覆盖引擎核心规则 #0 ~ #14，而是在 REVIEW 阶段验证合规性
2. **单文件不超过 1500 行**（规则 #13），超过时在 PLAN 阶段就应拆分为多模块
3. **每次代码修改后必须 BUILD**（规则 #1），这在流水线中是强制门控
4. **任务粒度建议**：每个子任务对应 1-3 个文件，100-500 行代码
5. **不要跳过 REVIEW**：即使时间紧迫，三维度审查是质量保障的核心
