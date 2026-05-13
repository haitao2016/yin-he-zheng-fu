---
name: game-dev-project-tracker
description: >-
  按功能/里程碑维度管理 UrhoX 游戏项目全生命周期文档。
  创建功能目录、记录日常开发进展、追踪问题、管理变更、自动蒸馏归档。
  跨会话持久化，让每次开发都有迹可循。
  Use when users need to
  (1) 为新功能/新需求创建文档目录,
  (2) 记录每日开发进展或工作日志,
  (3) 追踪项目中的 bug 和待解决问题,
  (4) 记录功能变更或设计决策,
  (5) 归档已完成功能的文档,
  (6) 查看项目整体状态或进展看板,
  (7) 用户说"新需求"、"建个目录"、"记一下进展"、"这个功能上线了"、"项目状态",
  (8) 用户说"创建需求目录"、"记录进展"、"项目归档"、"蒸馏项目"、"查看项目"。
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  source: "https://clawhub.ai/huangliujiao-tal/dev-project-tracker"
  tags: [project-management, documentation, lifecycle, tracking, game-dev]
---

# Game Dev Project Tracker

按功能/里程碑一站式管理 UrhoX 游戏项目文档，覆盖从创建到归档的完整生命周期。

> **定位**: 持久化项目文档管理系统。与 `structured-dev-session`（单任务执行流水线）、
> `game-dev-planner`（前置需求规划）互补——本 Skill 负责**跨会话记录开发过程**，
> 让每次迭代的进展、问题、变更都有据可查。

---

## 1. 核心概念

### 1.1 项目与功能

- **项目 (Project)**: 一个 UrhoX 游戏项目（通常对应一个 `/workspace/scripts/` 目录）
- **功能 (Feature)**: 项目中的一个独立功能模块或里程碑（如"战斗系统"、"UI重构"、"v1.0发布"）
- 每个功能拥有独立的文档目录，记录其完整开发生命周期

### 1.2 生命周期

```
🟢 开发中 (Active)
  │  正在开发，频繁更新 WORK_LOG 和 ISSUES
  │
  ▼  功能上线/完成后 2 周
🟡 已蒸馏 (Distilled)
  │  压缩日志，只保留关键决策和最终方案
  │
  ▼  蒸馏后 3 个月
🔴 已归档 (Archived)
  │  压缩为单文件 ARCHIVE.md，删除原始文件
```

---

## 2. 目录结构规范

```
docs/                              # 项目文档根目录
└── <project>/                     # 项目名（如 my-rpg-game）
    └── <feature>/                 # 功能/里程碑名（如 combat-system）
        ├── README.md              # 功能总览：目标、范围、状态、负责人
        ├── WORK_LOG.md            # 日常开发进展（日期倒序）
        ├── DIVISION.md            # 分工与任务拆解
        ├── ISSUES.md              # 问题追踪（Bug/TODO/风险）
        ├── CHANGES.md             # 变更记录（设计变更、方案调整）
        ├── tech/                  # 技术方案文档
        └── design/                # 设计稿/参考资料链接
```

### 2.1 为什么用 `docs/` 而非 `projects/`

- `scripts/` 是游戏代码目录（Rule #1）
- `assets/` 是资源文件目录（Rule #1.5）
- `docs/` 专门存放项目文档，不与引擎目录冲突
- 文档和代码分离，便于归档和清理

---

## 3. 操作指南

### 3.1 创建功能目录

**触发**: 用户说"新需求"、"建个目录"、"新建功能文档"

**流程**:

1. 确认项目名和功能名（如 `my-game/combat-system`）
2. 创建目录 `docs/<project>/<feature>/`
3. 从模板生成 6 个文件（见 `references/templates/`）
4. 在 README.md 中填写功能概述

```
# 示例：创建 "战斗系统" 功能目录
docs/my-game/combat-system/
├── README.md        # 状态: 🟢开发中 | 目标: 实现回合制战斗
├── WORK_LOG.md      # （空模板，等待记录）
├── DIVISION.md      # 任务拆解
├── ISSUES.md        # （空模板）
├── CHANGES.md       # （空模板）
├── tech/            # 技术方案
└── design/          # 设计参考
```

**关键**: 功能名使用 kebab-case（如 `combat-system`、`ui-refactor`、`v1-release`）

### 3.2 记录日常进展

**触发**: 用户说"记一下进展"、"今天做了什么"、"更新日志"

**流程**:

1. 打开对应功能的 `WORK_LOG.md`
2. 在文件**顶部**插入新记录（日期倒序，最新在最前）
3. 格式如下：

```markdown
## 2026-05-13

### 完成
- 实现了基础伤害计算公式
- 添加了 3 种武器类型（剑/弓/法杖）

### 进行中
- 技能冷却系统（预计明天完成）

### 阻塞
- 等待美术提供技能图标

### 备注
- 发现 Box2D 碰撞检测有性能问题，需要后续优化
```

**规则**:
- 每条记录必须包含日期标题
- `完成` 部分必填，其他可选
- 涉及 UrhoX API 的技术细节建议记录具体 API 名称，方便后续查阅

### 3.3 追踪问题

**触发**: 用户说"记个 bug"、"有个问题"、"添加 issue"

**流程**:

1. 打开对应功能的 `ISSUES.md`
2. 在表格中添加新行

```markdown
| ID | 状态 | 优先级 | 描述 | 发现日期 | 解决方案 |
|----|------|--------|------|----------|----------|
| I-003 | 🔴待解决 | P0 | 角色跳跃时穿透地面 | 2026-05-13 | |
| I-002 | 🟡处理中 | P1 | UI 在横屏下错位 | 2026-05-12 | 使用 UIScaler 适配 |
| I-001 | 🟢已解决 | P2 | NanoVG 文本不显示 | 2026-05-10 | 需先调用 nvgCreateFont |
```

**状态流转**: 🔴待解决 → 🟡处理中 → 🟢已解决

**优先级**:
- P0: 阻塞开发，必须立即修复
- P1: 重要但不阻塞，尽快修复
- P2: 低优先级，有空再修

### 3.4 记录变更

**触发**: 用户说"方案改了"、"设计变更"、"记一下变更"

**流程**:

1. 打开对应功能的 `CHANGES.md`
2. 在文件**顶部**插入新记录

```markdown
## [C-002] 2026-05-13 | 相机系统改为第三人称

### 变更内容
- 原方案: 使用自定义相机跟随逻辑
- 新方案: 改用 ThirdPersonCamera 库（Rule #13.5）

### 变更原因
- 自定义实现在符号处理上容易出错
- ThirdPersonCamera 库已封装完善，减少维护成本

### 影响范围
- `scripts/camera.lua` 需要重写
- `scripts/player.lua` 中的相机更新逻辑需调整

### 关联 Issue
- I-005（相机旋转方向错误）
```

### 3.5 生命周期管理

#### 蒸馏 (Active → Distilled)

**触发**: 用户说"这个功能上线了"、"蒸馏一下"、"功能做完了"

**流程**:

1. 更新 README.md 状态为 `🟡已蒸馏`，记录完成日期
2. 压缩 WORK_LOG.md：
   - 删除日常琐碎记录
   - 只保留关键里程碑和重要决策
   - 合并重复内容
3. 关闭所有 ISSUES：
   - 🔴待解决 → 标注为"遗留"并说明原因
   - 🟡处理中 → 标注最终状态
4. 在 CHANGES.md 末尾添加"蒸馏总结"

#### 归档 (Distilled → Archived)

**触发**: 用户说"归档这个功能"、"这个可以归档了"

**流程**:

1. 生成 `ARCHIVE.md`：合并所有文件的精华内容
2. 删除原始文件（README.md、WORK_LOG.md 等）
3. 只保留 `ARCHIVE.md` 和 `tech/` 中的技术方案

归档后目录结构：
```
docs/<project>/<feature>/
├── ARCHIVE.md       # 合并后的完整记录
└── tech/            # 保留技术方案（可能被后续功能参考）
```

### 3.6 查看项目状态

**触发**: 用户说"项目状态"、"看看进展"、"看板"

**流程**:

1. 扫描 `docs/` 目录下所有功能
2. 读取每个功能的 README.md 获取状态
3. 生成看板视图：

```
📊 项目状态看板 — my-game
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🟢 开发中 (3)
  ├── combat-system    | 战斗系统      | 进度 60%
  ├── ui-refactor      | UI 重构       | 进度 30%
  └── sound-effects    | 音效系统      | 进度 10%

🟡 已蒸馏 (1)
  └── player-movement  | 角色移动      | 2026-04-20 完成

🔴 已归档 (2)
  ├── prototype-v1     | 原型验证      | 2026-02-15 归档
  └── scene-setup      | 场景搭建      | 2026-03-01 归档

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 待解决问题: 2 | 🟡 处理中: 1 | 总功能: 6
```

**实现方式**: 使用 Lua 风格的伪代码逻辑（非 shell 脚本）：
- 遍历 `docs/<project>/` 下所有子目录
- 读取每个子目录的 README.md 第一行获取状态标记
- 读取 ISSUES.md 统计问题数量
- 格式化输出看板

---

## 4. 与其他 Skill 的协作

| 场景 | 本 Skill 职责 | 协作 Skill |
|------|--------------|-----------|
| 开始新功能开发 | 创建功能目录、记录技术方案 | `structured-dev-session` 管理代码开发流程 |
| 从想法到游戏 | 记录需求迭代历史 | `game-dev-planner` 做前期规划 |
| 功能完成后 | 蒸馏日志、归档文档 | `dev-tools-pack` 生成 changelog |
| 多功能并行开发 | 每个功能独立文档目录 | `@vintlin_team-dev` 编排开发任务 |

---

## 5. UrhoX 游戏开发适配

### 5.1 常见功能分类参考

创建功能目录时，可参考以下分类命名：

| 类别 | 功能名示例 | 说明 |
|------|----------|------|
| 核心玩法 | `combat-system`, `puzzle-logic` | 游戏核心机制 |
| 角色系统 | `player-controller`, `npc-ai` | 角色控制与 AI |
| UI 系统 | `main-menu`, `hud-design`, `inventory-ui` | 使用 urhox-libs/UI |
| 物理系统 | `physics-2d-platformer`, `3d-collision` | Box2D 或 3D 物理 |
| 渲染效果 | `particle-effects`, `shader-water` | 视觉效果 |
| 音频系统 | `bgm-system`, `sfx-manager` | 音效与音乐 |
| 网络多人 | `multiplayer-lobby`, `sync-system` | 多人联机 |
| 基础设施 | `save-system`, `config-manager` | 存档、配置等 |
| 里程碑 | `v1-alpha`, `v1-release`, `v2-planning` | 版本里程碑 |

### 5.2 技术方案模板（tech/ 目录）

在 `tech/` 目录中记录 UrhoX 相关的技术方案时，建议包含：

```markdown
# 技术方案: [功能名]

## 使用的引擎 API
- 列出主要使用的 UrhoX API（如 StaticModel、RigidBody2D、NanoVG 等）

## 关键设计决策
- 为什么选择这个方案（如：用 UI 组件而非 raw NanoVG）

## 已知限制
- 当前方案的已知限制和后续优化方向

## 参考文档
- 列出参考的 engine-docs/ 和 examples/
```

### 5.3 代码目录映射

文档目录与代码目录的对应关系：

```
docs/my-game/combat-system/     ←→  scripts/combat/
docs/my-game/ui-refactor/       ←→  scripts/ui/
docs/my-game/save-system/       ←→  scripts/save/
```

文档中引用代码路径时，使用 `scripts/` 前缀（遵循 Rule #1）。

---

## 6. 模板文件

所有模板位于 `references/templates/` 目录：

| 模板文件 | 用途 | 创建时机 |
|---------|------|---------|
| `README.md` | 功能总览 | 创建目录时 |
| `WORK_LOG.md` | 日常进展 | 创建目录时 |
| `DIVISION.md` | 分工与任务拆解 | 创建目录时 |
| `ISSUES.md` | 问题追踪 | 创建目录时 |
| `CHANGES.md` | 变更记录 | 创建目录时 |
| `TECH_SPEC.md` | 技术方案 | 按需放入 tech/ |

---

## 7. 注意事项

### 7.1 文件存放规则

- 文档放在 `docs/` 目录（不是 `scripts/` 或 `assets/`）
- 文档是纯 Markdown 文件，不包含可执行代码
- 不要在 `docs/` 中存放游戏资源（贴图、音效等）

### 7.2 命名规范

- 项目名: kebab-case（如 `my-rpg-game`）
- 功能名: kebab-case（如 `combat-system`）
- 文件名: 大写（如 `README.md`、`WORK_LOG.md`）

### 7.3 日期格式

- 统一使用 ISO 8601 格式: `YYYY-MM-DD`（如 `2026-05-13`）

### 7.4 编码规范

- 所有文档使用 UTF-8 编码
- Markdown 标题层级从 `#` 开始
- 表格使用标准 Markdown 表格语法
