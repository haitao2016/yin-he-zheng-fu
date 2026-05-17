---
title: "指令集设计指南"
description: "为不同游戏类型设计自定义指令集的完整参考"
skill: genetic-code-evolution
---

# 指令集设计指南

## 1. 设计原则

### 1.1 指令集大小与搜索空间

指令集大小直接影响遗传搜索的效率：

| 指令数 | 搜索空间（10 步程序） | 适用场景 |
|--------|----------------------|---------|
| 4      | 4^10 ≈ 100 万        | 极简任务，快速收敛 |
| 8      | 8^10 ≈ 10 亿         | 基础程序合成 |
| 16     | 16^10 ≈ 10^12        | 游戏 NPC 行为 |
| 24     | 24^10 ≈ 10^13        | 复杂策略 |
| 32+    | 爆炸级               | 仅推荐高级用户 |

**经验法则**：指令数 ≤ 16 时收敛速度最佳，超过 24 需要增大种群和代数。

### 1.2 指令分类框架

每条指令属于以下类别之一：

```
┌─────────────────────────────────────┐
│         指令分类框架                 │
├─────────────┬───────────────────────┤
│ 移动类      │ 改变实体位置/方向      │
│ 感知类      │ 读取环境信息           │
│ 动作类      │ 与环境交互             │
│ 数据类      │ 操作内部存储           │
│ 控制流类    │ 改变执行顺序           │
│ 通信类      │ 实体间信息传递         │
└─────────────┴───────────────────────┘
```

### 1.3 最小完备性原则

一个可用的指令集至少需要：

1. **至少 1 条移动指令** — 否则实体无法与环境交互
2. **至少 1 条感知指令** — 否则行为完全随机
3. **至少 1 条控制流指令** — 否则程序无法做决策
4. **至少 1 条动作指令** — 否则无法完成目标任务

## 2. 核心三层指令集详解

### 2.1 Tier-1 Core（8 条）

源自 Brainfuck，提供图灵完备的最小指令集：

```lua
local TIER1_CORE = {
    [0] = "ptr_inc",      -- 数据指针右移
    [1] = "ptr_dec",      -- 数据指针左移
    [2] = "val_inc",      -- 当前单元值 +1
    [3] = "val_dec",      -- 当前单元值 -1
    [4] = "output",       -- 输出当前单元值
    [5] = "input",        -- 读取输入到当前单元
    [6] = "loop_start",   -- 当前值为0则跳到匹配的 loop_end
    [7] = "loop_end",     -- 当前值非0则跳回匹配的 loop_start
}
```

**适用场景**：纯字符串生成、数学计算验证、教学演示。

**设计要点**：
- `loop_start` / `loop_end` 必须成对出现
- 未匹配的括号应被 VM 安全忽略（不要崩溃）
- 内存空间建议 256 单元，值范围 0-255

### 2.2 Tier-2 GameAction（+8 条，共 16 条）

在 Tier-1 基础上增加游戏世界交互：

```lua
local TIER2_GAME = {
    -- 继承 Tier-1 全部 8 条
    [8]  = "move_forward",   -- 沿当前朝向前进 1 格
    [9]  = "move_backward",  -- 沿当前朝向后退 1 格
    [10] = "turn_left",      -- 左转 90 度
    [11] = "turn_right",     -- 右转 90 度
    [12] = "sense_ahead",    -- 探测前方格子（结果存入当前单元）
    [13] = "sense_distance", -- 探测到最近目标的距离
    [14] = "attack",         -- 攻击前方实体
    [15] = "grab",           -- 拾取当前格子物品
}
```

**适用场景**：迷宫寻路、物品收集、简单战斗 AI。

**感知值编码**：

| sense_ahead 返回值 | 含义 |
|-------------------|------|
| 0                 | 空地 |
| 1                 | 墙壁 |
| 2                 | 物品 |
| 3                 | 敌人 |
| 4                 | 出口/目标 |

### 2.3 Tier-3 Extended（+8 条，共 24 条）

增加高级能力：

```lua
local TIER3_EXTENDED = {
    -- 继承 Tier-1 + Tier-2 全部 16 条
    [16] = "move_up",       -- 跳跃/上移
    [17] = "wait",          -- 等待 1 回合
    [18] = "sense_entity",  -- 探测周围实体数量
    [19] = "sense_health",  -- 读取自身生命值
    [20] = "signal",        -- 广播信号给附近实体
    [21] = "receive",       -- 接收信号
    [22] = "func_define",   -- 标记子程序起点
    [23] = "func_call",     -- 调用已定义的子程序
}
```

**适用场景**：群体协作、生存策略、多实体交互。

## 3. 游戏类型专用指令集配方

### 3.1 塔防 AI

```lua
--- 塔防守卫指令集（12 条）
local TowerDefenseSet = {
    -- 基础
    [0] = "wait",            -- 等待
    [1] = "rotate_cw",       -- 顺时针旋转
    [2] = "rotate_ccw",      -- 逆时针旋转
    -- 感知
    [3] = "sense_nearest",   -- 最近敌人距离 → 当前单元
    [4] = "sense_count",     -- 范围内敌人数量 → 当前单元
    [5] = "sense_health",    -- 自身能量 → 当前单元
    -- 动作
    [6] = "fire_primary",    -- 主武器射击
    [7] = "fire_secondary",  -- 副武器射击
    [8] = "activate_shield", -- 激活护盾
    -- 数据 + 控制流
    [9]  = "val_inc",
    [10] = "val_dec",
    [11] = "loop_start",
    [12] = "loop_end",
}
```

**适配的适应度函数**：

```lua
local function TowerDefenseFitness(vm, env)
    local score = 0
    score = score + env.enemiesKilled * 100    -- 击杀奖励
    score = score + env.turnsAlive * 1         -- 生存奖励
    score = score - env.damageReceived * 10    -- 受伤惩罚
    score = score - env.ammoWasted * 5         -- 浪费弹药惩罚
    return score
end
```

### 3.2 资源采集 AI

```lua
--- 资源采集指令集（14 条）
local ResourceGatherSet = {
    -- 移动
    [0] = "move_forward",
    [1] = "turn_left",
    [2] = "turn_right",
    -- 感知
    [3] = "sense_resource",     -- 最近资源方向 → 当前单元
    [4] = "sense_inventory",    -- 背包已用容量 → 当前单元
    [5] = "sense_base_dir",     -- 基地方向 → 当前单元
    -- 动作
    [6] = "harvest",            -- 采集当前格资源
    [7] = "deposit",            -- 在基地存放资源
    [8] = "craft",              -- 合成物品
    -- 数据
    [9]  = "ptr_inc",
    [10] = "ptr_dec",
    [11] = "val_inc",
    -- 控制流
    [12] = "loop_start",
    [13] = "loop_end",
}
```

### 3.3 格斗 AI

```lua
--- 格斗指令集（16 条）
local FightingSet = {
    -- 移动
    [0] = "move_forward",
    [1] = "move_backward",
    [2] = "jump",
    [3] = "crouch",
    -- 感知
    [4] = "sense_distance",     -- 对手距离
    [5] = "sense_opponent_state", -- 对手状态（攻击中/防御/空闲）
    [6] = "sense_health",       -- 自身生命值
    [7] = "sense_stamina",      -- 自身体力值
    -- 攻击
    [8]  = "punch",
    [9]  = "kick",
    [10] = "special_attack",
    -- 防御
    [11] = "block",
    [12] = "dodge",
    -- 控制流
    [13] = "val_inc",
    [14] = "loop_start",
    [15] = "loop_end",
}
```

### 3.4 探索 AI

```lua
--- 地图探索指令集（12 条）
local ExplorationSet = {
    -- 移动
    [0] = "move_forward",
    [1] = "move_backward",
    [2] = "turn_left",
    [3] = "turn_right",
    -- 感知
    [4] = "sense_ahead",       -- 前方地形
    [5] = "sense_visited",     -- 当前格是否已访问
    [6] = "sense_unexplored",  -- 最近未探索区域方向
    -- 动作
    [7] = "mark_tile",         -- 标记当前格
    [8] = "interact",          -- 与当前格物体交互
    -- 控制流
    [9]  = "val_inc",
    [10] = "loop_start",
    [11] = "loop_end",
}
```

## 4. 自定义指令集设计流程

### 4.1 五步法

```
步骤 1: 定义目标行为
  "NPC 需要做什么？" → 列出期望的行为清单

步骤 2: 识别必要感知
  "NPC 需要知道什么？" → 列出需要的环境信息

步骤 3: 映射动作
  "NPC 可以做什么？" → 列出可执行的动作

步骤 4: 添加控制流
  loop_start / loop_end 是最小控制流
  复杂行为可能需要 func_define / func_call

步骤 5: 平衡指令比例
  移动:感知:动作:控制流 ≈ 3:3:3:2（经验比例）
```

### 4.2 使用 InstructionSet.Extend()

```lua
local InstructionSet = require("scripts.GeneticEvolution.InstructionSet")

-- 基于 Tier-2 扩展
local customSet = InstructionSet.Extend(2, {
    { name = "cast_spell",    category = "action",  desc = "施放法术" },
    { name = "sense_mana",    category = "sense",   desc = "感知法力值" },
    { name = "meditate",      category = "action",  desc = "冥想恢复法力" },
    { name = "teleport",      category = "move",    desc = "传送到随机位置" },
})
-- customSet.size = 20（16 + 4）
-- customSet.names[16] = "cast_spell"
-- customSet.names[17] = "sense_mana"
-- ...
```

### 4.3 VM 回调注册

每条自定义指令都需要在 Interpreter 中注册执行回调：

```lua
local Interpreter = require("scripts.GeneticEvolution.Interpreter")

-- 为自定义指令注册回调
local vm = Interpreter.CreateVM(customSet, {
    onGameAction = function(vm, instrName, env)
        if instrName == "cast_spell" then
            if env.mana >= 10 then
                env.mana = env.mana - 10
                -- 在前方 2 格施放法术
                local fx, fy = env:GetForwardPos(2)
                env:DamageAt(fx, fy, 30)
                return true  -- 动作成功
            end
            return false  -- 法力不足
        elseif instrName == "sense_mana" then
            vm.memory[vm.dataPtr] = math.min(env.mana, 255)
            return true
        elseif instrName == "meditate" then
            env.mana = math.min(env.mana + 5, env.maxMana)
            return true
        elseif instrName == "teleport" then
            local x = math.random(1, env.gridWidth)
            local y = math.random(1, env.gridHeight)
            if env.grid[y][x] == 0 then
                env.entityX = x
                env.entityY = y
                return true
            end
            return false
        end
    end,
})
```

## 5. 指令集验证清单

设计完指令集后，逐项检查：

- [ ] **最小完备性**：至少包含移动、感知、动作、控制流各 1 条
- [ ] **指令数量**：≤ 24（推荐），超过则需增大种群
- [ ] **无冗余**：没有功能完全相同的两条指令
- [ ] **感知有用**：每个感知值都对决策有意义
- [ ] **动作可验证**：每个动作的效果可被适应度函数衡量
- [ ] **控制流完整**：loop_start 和 loop_end 成对定义
- [ ] **VM 回调齐全**：每条自定义指令都有对应的 onGameAction 处理
- [ ] **值域安全**：所有感知返回值在 0-255 范围内
- [ ] **命名清晰**：指令名能直观反映功能

## 6. 常见设计陷阱

### 陷阱 1：指令过多

```
❌ 40 条指令 → 搜索空间爆炸，几百代都无法收敛
✅ 先用 12 条核心指令验证，确认可行后再逐步扩展
```

### 陷阱 2：感知信息冗余

```
❌ sense_north + sense_south + sense_east + sense_west（4 条做了 1 条的事）
✅ sense_ahead（1 条，配合 turn 指令即可感知四方向）
```

### 陷阱 3：缺少"什么都不做"

```
❌ 所有指令都会改变状态 → 程序无法"等待最佳时机"
✅ 添加 wait / noop 指令，让进化发现"不动"也是策略
```

### 陷阱 4：动作无反馈

```
❌ attack 指令执行但结果不可感知
✅ attack 后自动更新某个内存单元为命中/未命中
   或添加 sense_last_action_result 指令
```

### 陷阱 5：忽略方向系统

```
❌ move_north/south/east/west（绝对方向，需要 4 条指令）
✅ move_forward + turn_left + turn_right（相对方向，仅需 3 条指令）
```
