# Phase 拆解模板

按游戏类型提供预设的 Phase 拆解方案，可直接复用或按需调整。

---

## 快照格式规范

```json
{
  "mission": "游戏名称",
  "genre": "游戏类型",
  "created_at": "ISO 8601 时间戳",
  "updated_at": "ISO 8601 时间戳",
  "current_phase": "当前 Phase ID",
  "phases": [
    {
      "id": "P0-Foundation",
      "status": "completed | in_progress | pending | blocked",
      "milestones": [
        {
          "name": "里程碑名称",
          "status": "completed | in_progress | pending | blocked",
          "complexity": "S | M | L",
          "depends_on": [],
          "risk": "low | medium | high",
          "risk_note": "风险说明（可选）",
          "completion_criteria": "完成标准描述"
        }
      ],
      "quality_gate": {
        "passed": true,
        "checked_at": "ISO 8601 时间戳",
        "issues": ["未通过的检查项描述"]
      }
    }
  ],
  "files": ["scripts/main.lua"],
  "notes": "当前状态备注"
}
```

**字段说明**：

| 字段 | 必填 | 说明 |
|------|------|------|
| mission | 是 | 项目名称 |
| genre | 否 | 游戏类型，用于选择默认模板 |
| current_phase | 是 | 当前活跃的 Phase ID |
| phases[].id | 是 | Phase 标识，格式 `P{N}-{Name}` |
| phases[].status | 是 | 状态枚举 |
| milestones[].complexity | 是 | S=简单(1功能点), M=中等(2-3功能点), L=复杂(4+功能点) |
| milestones[].depends_on | 否 | 依赖的其他 Milestone 名称列表 |
| files | 是 | 项目涉及的源文件列表 |

---

## 类型 A: 2D 休闲游戏

适用：Flappy Bird、贪吃蛇、打砖块、消消乐等

```
P0-Foundation (2 milestones, ~S)
  - 脚手架搭建（scaffold-2d.lua）
  - NanoVG 渲染管线初始化

P1-Core (3 milestones, S~M)
  - 主角控制与核心操作
  - 障碍/目标物生成逻辑
  - 碰撞检测与游戏规则

P2-Content (2 milestones, S~M)
  - 难度递增机制
  - 计分与最高分系统

P3-UI (2 milestones, S)
  - 开始/结束/暂停界面
  - 游戏内 HUD（分数、生命）

P4-Audio (1 milestone, S)
  - 背景音乐与音效

P5-Polish (2 milestones, S~M)
  - 视觉特效（粒子、屏幕闪烁）
  - 动画过渡与手感优化
```

**脚手架**: `templates/scaffold-2d.lua`
**参考示例**: `examples/03-flappy-bird-game.lua`

---

## 类型 B: 2D 平台跳跃

适用：马里奥、Celeste、洞窟物语等

```
P0-Foundation (2 milestones, S)
  - 脚手架搭建（scaffold-2d-physics.lua）
  - Box2D 物理世界配置

P1-Core (4 milestones, M~L)
  - 角色移动与物理控制
  - 跳跃系统（含 coyote time、jump buffer）
  - 地面/墙壁碰撞检测
  - 基础关卡地形

P2-Content (3 milestones, M)
  - 敌人类型与 AI 行为
  - 收集物与道具系统
  - 多关卡或关卡生成

P3-UI (2 milestones, S~M)
  - 生命/金币/关卡 HUD
  - 关卡选择与主菜单

P4-Audio (1 milestone, S)
  - 跳跃/拾取/受伤音效 + BGM

P5-Polish (2 milestones, M)
  - 角色动画与粒子效果
  - 相机跟随与屏幕震动
```

**脚手架**: `templates/scaffold-2d-physics.lua`
**参考示例**: `examples/04-box2d-platformer.lua`, `examples/05-super-mario-game.lua`

---

## 类型 C: 3D 角色动作游戏

适用：第三人称射击、动作冒险、Fall Guys 风格

```
P0-Foundation (3 milestones, S~M)
  - 脚手架搭建（scaffold-3d-character.lua）
  - 场景与光照配置
  - 第三人称相机（ThirdPersonCamera 库）

P1-Core (4 milestones, M~L)
  - 角色移动与物理控制
  - 动画状态机（FSM）
  - 核心交互机制（射击/攻击/技能）
  - 目标/敌人基础 AI

P2-Content (3 milestones, M~L)
  - 多种敌人类型与行为
  - 武器/装备系统
  - 关卡/区域设计

P3-UI (3 milestones, M)
  - 游戏 HUD（生命、弹药、准星）
  - 主菜单与暂停菜单
  - 背包/装备界面

P4-Audio (2 milestones, S~M)
  - 射击/爆炸/脚步音效
  - 自适应 BGM

P5-Polish (3 milestones, M)
  - 命中反馈与屏幕效果
  - 粒子特效系统
  - 过渡动画与镜头效果

P6-Balance (2 milestones, M)
  - 伤害/生命数值平衡
  - 难度曲线调整
```

**脚手架**: `templates/scaffold-3d-character.lua`
**参考示例**: `examples/22-third-person-shooter`

---

## 类型 D: 塔防/策略游戏

适用：植物大战僵尸、Kingdom Rush 风格

```
P0-Foundation (2 milestones, S)
  - 脚手架搭建（2D 或 3D）
  - 网格/地图系统初始化

P1-Core (4 milestones, M~L)
  - 地图网格与路径系统
  - 塔/单位放置机制
  - 敌人生成与寻路
  - 塔攻击与伤害计算

P2-Content (3 milestones, M)
  - 多种塔类型（攻击/减速/范围）
  - 多种敌人类型
  - 波次系统与难度递增

P3-UI (3 milestones, M)
  - 塔选择面板与建造菜单
  - 游戏 HUD（金币、波次、生命）
  - 升级/出售界面

P4-Audio (1 milestone, S)
  - 战斗音效与 BGM

P5-Polish (2 milestones, M)
  - 塔攻击特效
  - 波次过渡动画

P6-Balance (2 milestones, M~L)
  - 经济系统平衡（金币收入/塔造价）
  - 敌人强度曲线
```

---

## 类型 E: RPG / JRPG

适用：回合制 RPG、动作 RPG

```
P0-Foundation (2 milestones, S~M)
  - 脚手架搭建
  - 数据驱动架构搭建（角色/物品/技能数据表）

P1-Core (5 milestones, M~L)
  - 角色移动与地图探索
  - 战斗系统（回合制/实时）
  - 技能/魔法系统
  - 经验值与等级系统
  - 基础 NPC 对话

P2-Content (4 milestones, M~L)
  - 多角色与队伍管理
  - 物品/装备系统
  - 任务/剧情系统
  - 多区域地图

P3-UI (3 milestones, M~L)
  - 战斗 HUD
  - 背包/装备/状态界面
  - 对话/任务界面

P4-Audio (2 milestones, S~M)
  - 战斗/探索/城镇 BGM
  - 技能/打击/菜单音效

P5-Polish (2 milestones, M)
  - 战斗特效与动画
  - 过渡与 UI 动画

P6-Balance (2 milestones, L)
  - 战斗数值平衡（伤害公式、成长曲线）
  - 经济平衡（金币获取/消耗）
```

---

## 自定义 Phase 模板

当预设模板不完全适合时，按以下原则自定义：

1. **P0 始终是 Foundation** — 脚手架 + 基础架构
2. **P1 始终是 Core** — 核心玩法循环（可玩的最小原型）
3. **中间 Phase 按「依赖顺序」排列** — 被依赖的系统先做
4. **Audio/Polish 放后面** — 不影响核心功能
5. **Balance 放最后** — 需要所有系统就绪后才有意义

**每个 Phase 的理想大小**：3-5 个 Milestone，单 Phase 实现不超过 300-500 行新代码。

---

## 项目文档模板（PLAN.md）

制定开发计划后自动生成 `docs/PLAN.md`，使用以下模板。
后续每完成一个 Milestone / Phase / 质量门禁，都**同步更新**此文件。

### 完整模板

````markdown
# {mission} — 开发计划

> 类型: {genre} | 创建: {created_at} | 更新: {updated_at}
> 当前阶段: {current_phase}

---

## 总览

{用 2-3 句话描述游戏核心玩法和开发目标。}

## 进度

{progress_bar} {completed_phases}/{total_phases} 阶段完成 ({percent}%)

## 阶段详情

{对每个 Phase 按以下格式输出：}

### {phase_icon} {phase_id} — {phase_name} {current_marker}

{对每个 Milestone 输出勾选框：}
- [{check}] {milestone_name} `[{complexity}]` {status_marker}

{如果有依赖：}
  - 依赖: {depends_on_list}

{如果有风险标记：}
  - ⚠️ 风险: {risk_note}

> 门禁: {gate_status}

## 文件清单

| 文件 | 职责 |
|------|------|
| {file_path} | {file_role} |

## 风险与待决策

{列出高风险项、未确定的技术选型、需要用户决策的事项}

## 变更记录

| 日期 | 变更 |
|------|------|
| {date} | 初始计划制定 |

````

### 字段替换规则

| 占位符 | 来源 | 示例 |
|--------|------|------|
| `{mission}` | snapshot.mission | 塔防游戏 |
| `{genre}` | snapshot.genre | 策略/塔防 |
| `{created_at}` | snapshot.created_at | 2026-05-13 |
| `{updated_at}` | 当前时间 | 2026-05-13 |
| `{current_phase}` | snapshot.current_phase | P2-Content |
| `{progress_bar}` | 计算生成 | ████░░░░░░ |
| `{phase_icon}` | Phase 状态映射 | ✅ / 🔵 / ⬚ / 🚫 |
| `{current_marker}` | 当前 Phase 标记 | ← 当前 |
| `{check}` | Milestone 状态 | x（完成）或空格（未完成） |
| `{status_marker}` | Milestone 进行中标记 | ← 进行中 |
| `{gate_status}` | quality_gate 结果 | PASS (2026-05-13) / 未执行 |

### 进度条生成算法

```
completed_count = 已完成的 Phase 数量
total_count     = 全部 Phase 数量
filled          = math.floor(completed_count / total_count * 10)
empty           = 10 - filled
bar             = string.rep("█", filled) .. string.rep("░", empty)
percent         = math.floor(completed_count / total_count * 100)

输出: "{bar} {completed_count}/{total_count} 阶段完成 ({percent}%)"
```

### Phase 状态图标映射

| status | 图标 | 含义 |
|--------|------|------|
| completed | ✅ | 已完成并通过质量门禁 |
| in_progress | 🔵 | 当前正在开发 |
| pending | ⬚ | 等待开始 |
| blocked | 🚫 | 被阻塞（依赖未满足或存在技术障碍） |

### 同步触发点总结

以下每个事件发生时，必须同步更新 PLAN.md：

| 事件 | 更新内容 |
|------|---------|
| 任务分解完成（§1） | **创建** PLAN.md 全文 |
| Milestone 完成 | 将对应 `- [ ]` 改为 `- [x]`，移除 `← 进行中` |
| 开始新 Milestone | 在对应项后追加 `← 进行中` |
| Phase 质量门禁通过 | Phase 图标改为 ✅，追加门禁日期 |
| Phase 质量门禁失败 | 在门禁行追加 `FAIL: {issues}` |
| 进入下一 Phase | 新 Phase 图标改为 🔵 + `← 当前` |
| 保存快照 | 更新 `updated_at` 时间戳 + 进度条 |
| 作用域变更 | 追加/修改阶段和里程碑 + 在变更记录追加条目 |
| 恢复进度 | 不修改 PLAN.md，仅读取展示给用户 |

### 示例：完整的 PLAN.md 输出

````markdown
# 太空塔防 — 开发计划

> 类型: 策略/塔防 | 创建: 2026-05-13 | 更新: 2026-05-13
> 当前阶段: P2-Content

---

## 总览

一款太空主题的塔防游戏。玩家在小行星上部署防御塔，抵御外星虫群的多波次进攻。
核心循环为"赚取矿石 → 建造/升级防御塔 → 抵御虫潮 → 下一波"。

## 进度

███░░░░░░░ 2/7 阶段完成 (28%)

## 阶段详情

### ✅ P0-Foundation — 基础搭建
- [x] 脚手架搭建 `[S]`
- [x] 网格地图系统 `[M]`
> 门禁: PASS (2026-05-13)

### ✅ P1-Core — 核心玩法
- [x] 防御塔放置与射击 `[M]`
- [x] 敌人寻路与移动 `[M]`
- [x] 伤害计算与生命系统 `[M]`
> 门禁: PASS (2026-05-13)

### 🔵 P2-Content — 内容系统 ← 当前
- [x] 3 种防御塔类型 `[M]`
- [ ] 5 种敌人变体 `[M]` ← 进行中
- [ ] 波次生成器 `[L]`
> 门禁: 未执行

### ⬚ P3-UI — 用户界面
- [ ] 建造面板 `[M]`
- [ ] 波次/金币 HUD `[S]`
- [ ] 主菜单 `[S]`
> 门禁: 未执行

### ⬚ P4-Audio — 音效
- [ ] 射击/爆炸音效 `[S]`
- [ ] 战斗 BGM `[S]`
> 门禁: 未执行

### ⬚ P5-Polish — 打磨
- [ ] 爆炸粒子特效 `[M]`
- [ ] 波次过渡动画 `[S]`
> 门禁: 未执行

### ⬚ P6-Balance — 数值平衡
- [ ] 经济平衡（矿石收入/塔造价） `[M]`
- [ ] 敌人强度曲线 `[M]`
> 门禁: 未执行

## 文件清单

| 文件 | 职责 |
|------|------|
| scripts/main.lua | 入口，场景初始化，网格系统 |
| scripts/towers.lua | 防御塔类型与射击逻辑 |
| scripts/enemies.lua | 敌人类型与寻路 |

## 风险与待决策

- ⚠️ 波次生成器 (L) 复杂度较高，可能需要数据驱动设计
- 待定: 是否支持防御塔升级（影响 P3-UI 和 P6-Balance）

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-05-13 | 初始计划制定 |
| 2026-05-13 | P0、P1 完成 |
| 2026-05-13 | P2 开始，3种防御塔完成 |
````
