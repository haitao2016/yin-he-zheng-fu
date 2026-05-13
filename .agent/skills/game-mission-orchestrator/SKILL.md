---
name: game-mission-orchestrator
description: >
  UrhoX Lua 游戏开发任务编排器。将复杂游戏开发需求分解为里程碑阶段，
  设置质量门禁，支持中断恢复和跨会话进度追踪。
  灵感来源于 Agent Studio (github.com/oimiragieo/agent-studio) 的
  Mission Orchestrator 架构和 Quality Gate 验证体系。
  Use when users need to:
  (1) 开发一个需要多轮对话、多阶段实现的大型游戏项目,
  (2) 将复杂游戏需求拆解为可管理的开发阶段（如核心玩法→UI→音效→打磨）,
  (3) 在开发过程中跟踪哪些功能已完成、哪些待开发、哪些被阻塞,
  (4) 跨会话恢复开发进度（用户说「继续上次的项目」「恢复进度」「我们上次做到哪了」）,
  (5) 对每阶段完成的功能进行质量检查（构建通过？逻辑正确？性能达标？）,
  (6) 用户说「拆解任务」「制定开发计划」「分阶段开发」「mission plan」「开发路线图」,
  (7) 用户说「项目进度」「查看进度」「开发状态」「mission status」,
  (8) 用户说「保存进度」「保存快照」「save progress」「checkpoint」,
  (9) 游戏项目代码已超过 500 行且还有大量功能待实现时主动建议使用,
  (10) 用户描述了一个包含 3 个以上子系统的游戏需求时主动建议使用。
  MUST trigger when: 用户明确要求制定开发计划、分阶段开发、或恢复之前的开发进度。
  Should proactively suggest when: 游戏需求复杂度超过单次会话能完成的范围。
---

# Game Mission Orchestrator

将复杂 UrhoX Lua 游戏开发任务分解为里程碑阶段，通过质量门禁验证每阶段交付，
支持中断恢复和跨会话进度追踪。

---

## 核心概念

| 概念 | 说明 |
|------|------|
| **Mission** | 一个完整的游戏开发目标（如「制作塔防游戏」） |
| **Phase** | 开发阶段（如「核心玩法」「UI系统」「音效打磨」） |
| **Milestone** | 阶段内的具体交付物（如「敌人寻路」「生命值HUD」） |
| **Quality Gate** | 阶段完成时的验证检查点 |
| **Snapshot** | 进度快照，用于中断恢复 |

---

## 工作流程

### §1 需求分析与任务分解

收到复杂游戏开发需求时：

1. **识别复杂度信号**
   - 用户描述包含 3+ 子系统（如战斗+背包+对话）
   - 预估代码量超过 800 行
   - 涉及多种技术领域（物理+UI+AI+网络）

2. **拆解为 Phase**
   按以下标准顺序拆分（可根据需求调整）：

   | Phase | 内容 | 典型里程碑数 |
   |-------|------|-------------|
   | P0-Foundation | 脚手架搭建、场景初始化、基础架构 | 2-3 |
   | P1-Core | 核心玩法循环、主要交互机制 | 3-5 |
   | P2-Content | 关卡、敌人、道具等内容系统 | 2-4 |
   | P3-UI | HUD、菜单、设置界面 | 2-3 |
   | P4-Audio | BGM、音效、空间音频 | 1-2 |
   | P5-Polish | 特效、屏幕震动、过渡动画 | 2-3 |
   | P6-Balance | 数值平衡、难度曲线 | 1-2 |

3. **每个 Milestone 必须包含**
   - 明确的完成标准（「能看到什么/能做什么」）
   - 依赖关系（哪些 Milestone 必须先完成）
   - 预估复杂度：`S`(简单) / `M`(中等) / `L`(复杂)

### §2 执行与质量门禁

每完成一个 Phase 时，执行质量门禁检查：

```
Quality Gate 检查清单：
[ ] 代码能通过 build（调用 UrhoX MCP build 工具）
[ ] 新增功能在 Preview 中可验证
[ ] 无引入的回归问题（已有功能仍正常）
[ ] 代码遵循 UrhoX 规则（脚手架、UI组件、枚举值等）
[ ] 单文件未超过 1500 行（超过则按规则 #13 拆分）
```

**门禁结果**：

| 结果 | 动作 |
|------|------|
| PASS | 更新快照，进入下一 Phase |
| PARTIAL | 记录未通过项，评估是否可带入下一 Phase |
| FAIL | 修复问题后重新检查，不进入下一 Phase |

### §3 进度快照与中断恢复

#### 保存快照

在以下时机保存快照到 `scripts/.mission/snapshot.json`：

- 每个 Phase 完成且通过质量门禁时
- 用户明确要求保存进度时
- 会话即将结束时（如果有未保存的进度）

快照格式详见 [references/phase-templates.md](references/phase-templates.md)。

#### 恢复进度

当用户说「继续」「恢复」「上次做到哪了」时：

1. 读取 `scripts/.mission/snapshot.json`
2. 展示进度摘要（已完成/进行中/待开发）
3. 读取相关源文件，理解当前代码状态
4. 从 `in_progress` 的 Milestone 继续

### §4 进度报告

用户请求查看进度时，生成简洁报告：

```
Mission: 塔防游戏

Phase           Status      Milestones
P0-Foundation   Done        2/2
P1-Core         Done        3/3
P2-Content      Active      1/3  <-- current
P3-UI           Pending     0/3
P4-Audio        Pending     0/2
P5-Polish       Pending     0/2

Current: P2-Content > 多种敌人类型 (M)
Next: 完成敌人变种，然后实现波次系统
```

---

## 与 UrhoX 引擎规则的兼容保证

本 Skill 不修改任何引擎行为，仅提供项目管理层面的编排：

| 引擎规则 | 本 Skill 的遵守方式 |
|----------|-------------------|
| 规则 #1: 代码放 scripts/ | 快照文件放 `scripts/.mission/`，不创建外层目录 |
| 规则 #2: 脚手架起手 | P0-Foundation 阶段强制要求使用脚手架 |
| Build after change | 每个 Quality Gate 必须调用 build 工具 |
| 规则 #10: UI 用 urhox-libs/UI | Quality Gate 检查包含 UI 规则合规项 |
| 规则 #13: 模块化 | 当文件超过 1000 行时在进度报告中提示拆分 |
| 安全规则 | 不写入 dist/，不泄露引擎内部文件 |

---

## 决策树

```
用户需求到达
  |
  +-- 简单需求（单功能、<300行）
  |   -> 不使用本 Skill，直接开发
  |
  +-- 中等需求（2-3个功能、300-800行）
  |   -> 可选使用，提供轻量级 Phase 划分
  |
  +-- 复杂需求（3+子系统、>800行预估）
      -> 建议使用本 Skill
      |
      +-- 用户同意 -> 进入 §1 需求分析与任务分解
      +-- 用户拒绝 -> 尊重用户选择，按常规流程开发
```

---

## 高级功能

### 依赖管理

Milestone 之间的依赖用 `depends_on` 字段表示。执行时自动检查依赖是否已完成，未完成则跳过并提示。

### 风险标记

对高复杂度或不确定性大的 Milestone 标记风险等级。高风险项建议提前原型验证。

### 作用域变更

当用户在开发过程中追加需求时：
1. 评估对现有 Phase 的影响
2. 新增 Milestone 或调整 Phase
3. 更新快照
4. 告知用户变更影响

---

## 详细参考

- **Phase 拆解模板与游戏类型案例**: 见 [references/phase-templates.md](references/phase-templates.md)
- **质量门禁详细检查项**: 见 [references/quality-gates.md](references/quality-gates.md)
