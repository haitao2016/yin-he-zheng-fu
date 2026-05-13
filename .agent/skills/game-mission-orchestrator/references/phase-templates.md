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
