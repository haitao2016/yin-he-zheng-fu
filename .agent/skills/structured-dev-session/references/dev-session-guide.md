# 开发会话管理指南

> 结构化开发会话（Structured Dev Session）的详细操作指南。
> 本文档是 SKILL.md 的补充参考，提供每个阶段的具体执行细节。

---

## 1. 会话生命周期

### 1.1 会话状态机

```
[未启动] ──触发──→ [Phase 1: ANALYZE]
                        │
                        ▼
              [Phase 2: UNDERSTAND]  ← feature/refactor 时执行
                        │
                        ▼
              [Phase 3: DIAGNOSE]    ← fix 时执行
                        │
                        ▼
              [Phase 4: SNAPSHOT]
                        │
                        ▼
              [Phase 5: IMPLEMENT]
                        │
                        ▼
              [Phase 6: REVIEW] ◄──不通过──┐
                        │                  │
                     通过？─── 否 ─────────┘ (最多 3 轮)
                        │
                       是
                        ▼
              [Phase 7: SAVE]
                        │
                        ▼
                     [完成]
```

### 1.2 会话标签规范

会话标签贯穿整个生命周期，用于追踪和提交描述。

**格式**: `{type}/{short-name}`

| 类型 | 前缀 | 适用场景 | 示例 |
|------|------|---------|------|
| 新功能 | `feature/` | 添加新功能或系统 | `feature/enemy-patrol-ai` |
| 修复 | `fix/` | 修复已知 Bug | `fix/jump-ground-detection` |
| 重构 | `refactor/` | 代码结构改进 | `refactor/split-main-modules` |
| 文档 | `docs/` | 文档更新 | `docs/add-api-comments` |

**命名规则**：
- 使用英文小写 + 短横线分隔
- 简洁但具描述性（3-5 个单词）
- 不要使用日期或序号

```
✅ feature/enemy-patrol-ai
✅ fix/player-fall-through-floor
❌ feature/task1（太模糊）
❌ fix/20260513-bug（不要用日期）
❌ feature/add-new-enemy-patrol-artificial-intelligence-system（太长）
```

### 1.3 复杂度路由

在 Phase 1 (ANALYZE) 中确定任务复杂度，决定执行路径：

| 复杂度 | 判断条件 | 执行阶段 |
|--------|---------|---------|
| **简单** | 改动 ≤ 1 个文件，逻辑清晰 | 1 → 5 → 7（跳过理解/诊断/快照/审查） |
| **中等** | 改动 2-3 个文件，有一定复杂度 | 1 → 2/3 → 5 → 6 → 7（跳过快照） |
| **复杂** | 改动 > 3 个文件，或涉及架构变更 | 完整 7 阶段 |

**复杂度判断清单**：
- [ ] 涉及几个文件？（1 / 2-3 / >3）
- [ ] 是否涉及架构变更？（是→复杂）
- [ ] 是否需要理解多个模块的交互？（是→至少中等）
- [ ] 是否有回归风险？（是→至少中等）

---

## 2. 各阶段详细操作

### 2.1 Phase 1: ANALYZE（任务分析）

**目标**: 明确任务的类型、范围和复杂度。

**输入**: 用户的需求描述

**操作步骤**:

1. **确定任务类型**
   ```
   用户说"添加/实现/新增" → feature
   用户说"修复/Bug/报错"  → fix
   用户说"重构/拆分/优化结构" → refactor
   用户说"注释/文档/说明" → docs
   ```

2. **生成会话标签**
   - 从用户描述中提取核心关键词
   - 按 `{type}/{keywords}` 格式生成

3. **评估复杂度**
   - 根据上方复杂度判断清单评估
   - 确定执行路径

4. **列出影响范围**
   - 预判需要修改的文件列表
   - 识别可能的依赖关系

**出口条件（Gate）**:
- [ ] 任务类型已确定（feature/fix/refactor/docs）
- [ ] 会话标签已生成
- [ ] 复杂度已评估（简单/中等/复杂）
- [ ] 影响范围已列出

**输出**: TodoWrite 任务列表 + 会话标签

### 2.2 Phase 2: UNDERSTAND（代码库理解）

> 仅 feature/refactor 类型执行此阶段

**目标**: 充分理解现有代码，避免重复实现或破坏已有功能。

**操作步骤**:

1. **定位相关代码**
   - 使用 Grep/Glob 搜索相关关键词
   - 阅读直接相关的文件（完整阅读，不跳过）

2. **检查可复用资源**
   - 搜索 `urhox-libs/` 是否有已封装的功能
   - 检查 `examples/` 是否有类似实现
   - 检查 `engine-docs/recipes/` 是否有现成方案

3. **绘制影响图**
   - 列出将被修改的文件
   - 标注每个文件中将被修改的函数/区域
   - 识别下游依赖（谁调用了这些函数）

4. **记录发现**
   - 可复用的模块/函数
   - 需要注意的约束
   - 潜在的冲突点

**出口条件（Gate）**:
- [ ] 已阅读所有相关文件
- [ ] 已检查 urhox-libs 和 examples
- [ ] 影响范围已明确
- [ ] 可复用资源已列出

### 2.3 Phase 3: DIAGNOSE（根因调研）

> 仅 fix 类型执行此阶段

**目标**: 定位 Bug 的根本原因，避免表面修复。

**操作步骤**:

1. **复现问题**
   - 确认问题的触发条件
   - 确认预期行为 vs 实际行为

2. **追踪调用链**
   - 从问题表现出发，反向追踪调用链
   - 使用 Grep 搜索相关函数和变量

3. **验证假设**
   - 提出可能的根因假设
   - 通过阅读代码验证或排除每个假设
   - 确定最终根因

4. **设计修复方案**
   - 确定最小修改范围
   - 评估修复是否会引入新问题

**出口条件（Gate）**:
- [ ] Bug 根因已定位
- [ ] 修复方案已确定
- [ ] 修复范围是最小化的
- [ ] 评估了回归风险

### 2.4 Phase 4: SNAPSHOT（快照存档）

> 仅复杂任务执行此阶段

**目标**: 在开始修改代码前，保存当前状态作为回退点。

**操作步骤**:

1. **调用版本管理 Skill**
   - 优先使用 `@org_git-save`（如果已配置远程仓库）
   - 或使用 `github-git-sync`（如果使用 GitHub）
   - 提交描述: `snapshot: {会话标签} 开发前存档`

2. **记录快照标识**
   - 记录提交信息或版本标识
   - 作为后续回退的参考点

**出口条件（Gate）**:
- [ ] 当前代码已保存版本
- [ ] 快照标识已记录

### 2.5 Phase 5: IMPLEMENT（开发实施）

**目标**: 按照分析结果实现功能或修复 Bug。

**核心原则**:
- **最小修改**: 只改必须改的，不附带"顺手优化"
- **引擎合规**: 遵循所有 UrhoX 引擎规则（见 CLAUDE.md）
- **构建验证**: 每次有意义的修改后调用 build 工具

**操作步骤**:

1. **按 TodoWrite 任务列表逐项实施**
   - 每完成一项，立即标记为 completed
   - 发现新子任务时，添加到列表

2. **遵循引擎规则**（关键检查项）
   - 代码放在 `scripts/` 目录
   - 使用 `require "urhox-libs.XXX"` 引用库
   - NanoVG 使用 `NanoVGRender` 事件
   - 数组索引从 1 开始
   - 使用枚举常量而非数字
   - UI 使用 `urhox-libs/UI` 而非原生 UI

3. **构建验证**
   - 调用 UrhoX MCP `build` 工具
   - 检查构建输出是否有错误
   - 修复所有构建错误后再继续

**出口条件（Gate）**:
- [ ] 所有计划的修改已完成
- [ ] 构建通过（无错误）
- [ ] 所有 TodoWrite 任务已完成

### 2.6 Phase 6: REVIEW（代码审查）

**目标**: 系统性检查代码质量，确保无遗漏。

**操作步骤**:

1. **执行审查清单**
   - 按 `references/review-checklist.md` 逐项检查
   - 记录发现的问题

2. **分类问题**
   - 🔴 阻断（必须修复才能继续）
   - 🟡 建议（应该修复，但不阻断）
   - 🟢 优化（可选改进）

3. **修复阻断问题**
   - 修复所有 🔴 问题
   - 尽量修复 🟡 问题
   - 重新构建验证

4. **循环检查**
   - 如果修复引入了新问题，再次审查
   - 最多 3 轮循环
   - 第 3 轮后仍有问题，记录到报告中

**出口条件（Gate）**:
- [ ] 审查清单已完成
- [ ] 所有 🔴 问题已修复
- [ ] 构建通过
- [ ] 审查轮数 ≤ 3

### 2.7 Phase 7: SAVE（版本保存）

**目标**: 保存最终代码并生成会话报告。

**操作步骤**:

1. **生成提交描述**
   ```
   格式: {type}: {简要描述}
   
   示例:
     feature: 添加敌人巡逻 AI 系统
     fix: 修复跳跃落地检测偶发失败
     refactor: 拆分 main.lua 为模块化结构
   ```

2. **调用版本管理 Skill**
   - 使用 `@org_git-save` 或 `github-git-sync`
   - 提交描述使用上方格式

3. **输出会话报告**
   ```
   ## 开发会话报告
   
   **会话标签**: {type}/{short-name}
   **任务类型**: {feature/fix/refactor/docs}
   **复杂度**: {简单/中等/复杂}
   
   ### 变更摘要
   - {文件1}: {变更描述}
   - {文件2}: {变更描述}
   
   ### 审查结果
   - 审查轮数: {N}
   - 遗留问题: {无/列表}
   
   ### 版本信息
   - 提交描述: {commit message}
   ```

---

## 3. 跨会话任务处理

当一个任务跨越多个对话会话时：

### 3.1 会话恢复

1. **读取上下文**
   - 检查 TodoWrite 列表中的未完成任务
   - 检查 `scripts/` 目录中的代码状态
   - 读取用户之前的会话记录（如有）

2. **确定当前阶段**
   - 根据代码状态和任务列表判断当前所处阶段
   - 从该阶段继续执行

3. **不要重复已完成的工作**
   - 如果 ANALYZE 已完成，直接进入下一阶段
   - 如果代码已修改但未审查，进入 REVIEW

### 3.2 大型任务拆分

对于需要多个会话才能完成的大型任务：

1. **在 Phase 1 中识别**
   - 如果预估改动 > 10 个文件或涉及多个独立子系统
   - 标记为"大型任务"

2. **拆分为子会话**
   - 每个子会话处理一个独立子系统
   - 每个子会话有独立的会话标签
   - 例: `feature/combat-system-core`, `feature/combat-system-ui`, `feature/combat-system-balance`

3. **子会话间的协调**
   - 每个子会话独立执行完整流水线
   - 后续子会话在 Phase 2 中需要理解前序子会话的变更

---

## 4. 与其他 Skill 的协作模式

### 4.1 协作矩阵

| 阶段 | 协作 Skill | 协作方式 |
|------|-----------|---------|
| Phase 2 UNDERSTAND | `game-debugging` | 借助其代码追踪能力理解调用链 |
| Phase 3 DIAGNOSE | `game-debugging` | 使用其 Bug 诊断方法论 |
| Phase 4 SNAPSHOT | `@org_git-save` / `github-git-sync` | 调用其版本保存能力 |
| Phase 5 IMPLEMENT | `auto-workflow` | 使用其代码生成模板 |
| Phase 5 IMPLEMENT | `materials` | 材质相关实现参考 |
| Phase 6 REVIEW | `game-review-improve` | 使用其游戏质量审查视角 |
| Phase 6 REVIEW | `software-engineering-lua` | 使用其代码质量检查清单 |
| Phase 7 SAVE | `@org_git-save` / `github-git-sync` | 调用其版本保存能力 |

### 4.2 协作调用示例

```
── Phase 3 DIAGNOSE ──
   ├── 使用 game-debugging 的"五步定位法"：
   │   1. 日志定位
   │   2. 断点排查（添加日志输出）
   │   3. 最小复现
   │   4. 二分排除
   │   5. 根因确认
   └── 输出: 根因分析报告

── Phase 6 REVIEW ──
   ├── 使用 review-checklist.md 自审
   ├── 可选: 触发 game-review-improve 做深度审查
   └── 输出: 审查结果 + 修复记录
```

---

## 5. 常见场景示例

### 5.1 场景: 添加计分系统（中等复杂度）

```
Phase 1 ANALYZE
  类型: feature
  标签: feature/score-system
  复杂度: 中等（2 个文件，无架构变更）
  路径: 1 → 2 → 5 → 6 → 7

Phase 2 UNDERSTAND
  - 阅读 scripts/main.lua 理解现有游戏循环
  - 检查 urhox-libs/UI 了解 UI.Label 用法
  - 检查 examples/11-client-cloud-score-leaderboard-api.lua 了解云存储
  - 确认: 需要修改 main.lua + 新建 scripts/ScoreManager.lua

Phase 5 IMPLEMENT
  - 创建 scripts/ScoreManager.lua（计分逻辑）
  - 修改 scripts/main.lua（集成计分系统）
  - 调用 build 工具验证

Phase 6 REVIEW
  - 执行审查清单
  - 确认无引擎规则违反
  - 构建通过

Phase 7 SAVE
  - 提交: "feature: 添加计分系统与云端排行榜"
  - 输出会话报告
```

### 5.2 场景: 修复角色穿墙 Bug（复杂）

```
Phase 1 ANALYZE
  类型: fix
  标签: fix/character-wall-clip
  复杂度: 复杂（涉及物理、碰撞、角色控制器 3+ 文件）
  路径: 完整 7 阶段

Phase 3 DIAGNOSE
  - 复现: 角色高速移动时穿过薄墙
  - 追踪: CharacterController → RigidBody → CollisionShape
  - 假设1: 碰撞体太小 → 排除（尺寸正确）
  - 假设2: CCD 未启用 → 确认（根因）
  - 方案: 启用 CCD（Continuous Collision Detection）

Phase 4 SNAPSHOT
  - 调用 @org_git-save: "snapshot: fix/character-wall-clip 开发前存档"

Phase 5 IMPLEMENT
  - 修改物理配置启用 CCD
  - 调用 build 验证

Phase 6 REVIEW
  - 检查 CCD 参数是否合理
  - 确认无性能影响
  - 构建通过

Phase 7 SAVE
  - 提交: "fix: 启用 CCD 修复高速移动穿墙问题"
  - 输出会话报告
```

---

## 6. 反模式警告

### ❌ 不要做

| 反模式 | 问题 | 正确做法 |
|--------|------|---------|
| 跳过 ANALYZE 直接写代码 | 可能方向错误，浪费时间 | 先分析再动手 |
| UNDERSTAND 阶段只看文件名 | 遗漏关键约束或可复用资源 | 完整阅读相关文件 |
| 修 Bug 不找根因 | 表面修复，问题复发 | 完成 DIAGNOSE 再修复 |
| IMPLEMENT 中顺手重构 | 引入不相关变更，增加回归风险 | 严格限制在任务范围内 |
| REVIEW 发现问题但不修 | 技术债积累 | 至少修复所有 🔴 问题 |
| 跳过 SAVE 阶段 | 丢失版本记录 | 每次会话结束都保存版本 |

---

*版本: v1.0*
*最后更新: 2026-05-13*
