# NPC 原型预设库

> GAIA NPC AI — 常用 NPC 原型的属性和行为预设

---

## 1. 原型总览

| 原型 | 职业 | 核心特征 | 推荐状态 | 典型亲密度起点 |
|------|------|---------|---------|--------------|
| 友善商人 | Merchant | 友善、和平 | idle/trading | 10（偏友好） |
| 老猎人 | Hunter | 勇敢、年迈 | idle/hunting | 0（中立） |
| 村庄守卫 | Guard | 勇敢、攻击性 | guarding | -5（略冷淡） |
| 流浪旅人 | Traveler | 友善、胆小 | idle/fleeing | 5（微偏友好） |
| 山贼头目 | Bandit | 攻击性、勇敢 | hunting | -30（敌对） |
| 治疗师 | Healer | 友善、智慧 | idle | 15（友好） |
| 铁匠 | Blacksmith | 中性、坚韧 | idle/trading | 0（中立） |
| 孩童 | Child | 友善、胆小 | idle | 20（偏友好） |

---

## 2. 原型定义

### 2.1 友善商人

```lua
local merchantDef = AgentDef.Create({
    name = "赵掌柜",
    title = "商人",
    age = 42,
    maxAge = 75,
    hp = 80,
    maxHp = 80,
    hunger = 20,
    food = 10,
    affinity = 10,
    states = { "idle", "trading", "hunting", "fleeing", "dead" },
    currentState = "idle",
    traits = {
        aggression = 0.1,      -- 极少攻击
        friendliness = 0.85,   -- 非常友善
        bravery = 0.25,        -- 容易逃跑
    },
})
```

**行为特点**：
- 大部分时间处于 `idle` 或 `trading` 状态
- 饥饿时会短暂狩猎，但成功率一般
- 受到攻击后立即逃跑（bravery 低）
- 好感度变化快（friendliness 高 → 正面互动加成大）

### 2.2 老猎人

```lua
local hunterDef = AgentDef.Create({
    name = "老王",
    title = "猎人",
    age = 58,
    maxAge = 70,
    hp = 90,
    maxHp = 120,
    hunger = 30,
    food = 3,
    affinity = 0,
    states = { "idle", "hunting", "eating", "fleeing", "dead" },
    currentState = "idle",
    traits = {
        aggression = 0.3,
        friendliness = 0.6,
        bravery = 0.7,
    },
})
```

**行为特点**：
- 经常狩猎但因年龄（>50）成功率降低 50%
- 适合触发"代为狩猎"类任务
- 中等友善度，需要多次正面互动才能达到"亲密"
- 受伤后仍会坚持（bravery 较高）

### 2.3 村庄守卫

```lua
local guardDef = AgentDef.Create({
    name = "铁卫",
    title = "守卫",
    age = 32,
    maxAge = 65,
    hp = 150,
    maxHp = 150,
    hunger = 15,
    food = 5,
    affinity = -5,
    states = { "idle", "guarding", "hunting", "fleeing", "dead" },
    currentState = "guarding",
    traits = {
        aggression = 0.65,
        friendliness = 0.25,
        bravery = 0.85,
    },
})
```

**行为特点**：
- 默认处于 `guarding` 状态（需扩展自定义状态）
- 高 HP、高勇气，不轻易逃跑
- 攻击性较高，被攻击后可能反击
- 低友善度 → 好感增长慢，但一旦达到友好会提供强力帮助

### 2.4 流浪旅人

```lua
local travelerDef = AgentDef.Create({
    name = "阿飘",
    title = "旅人",
    age = 25,
    maxAge = 80,
    hp = 60,
    maxHp = 60,
    hunger = 65,
    food = 1,
    affinity = 5,
    states = { "idle", "hunting", "eating", "fleeing", "dead" },
    currentState = "idle",
    traits = {
        aggression = 0.05,
        friendliness = 0.75,
        bravery = 0.15,
    },
})
```

**行为特点**：
- 经常处于饥饿状态（初始 hunger=65）
- 极易被喂食感动（高 friendliness）
- 极其胆小（bravery=0.15），一有危险就逃
- 适合触发"帮助饥饿的旅人"任务

### 2.5 山贼头目

```lua
local banditDef = AgentDef.Create({
    name = "黑风",
    title = "山贼头目",
    age = 38,
    maxAge = 55,
    hp = 130,
    maxHp = 130,
    hunger = 25,
    food = 8,
    affinity = -30,
    states = { "idle", "hunting", "fleeing", "dead" },
    currentState = "idle",
    traits = {
        aggression = 0.8,
        friendliness = 0.1,
        bravery = 0.9,
    },
})
```

**行为特点**：
- 初始为"敌对"等级（affinity=-30）
- 极高攻击性和勇气，几乎不会逃跑
- 极低友善度 → 正面互动增益很小
- 需要大量努力才能改善关系（挑战性 NPC）

### 2.6 治疗师

```lua
local healerDef = AgentDef.Create({
    name = "药婆",
    title = "治疗师",
    age = 50,
    maxAge = 90,
    hp = 70,
    maxHp = 70,
    hunger = 10,
    food = 6,
    affinity = 15,
    states = { "idle", "trading", "eating", "fleeing", "dead" },
    currentState = "idle",
    traits = {
        aggression = 0.0,
        friendliness = 0.95,
        bravery = 0.3,
    },
})
```

**行为特点**：
- 零攻击性，绝不主动伤害
- 极高友善度，好感度增长最快
- 初始就是"中立偏友好"（affinity=15）
- 适合提供治疗类任务和物品

---

## 3. 使用方式

### 3.1 在 AgentManager 中批量注册

```lua
local AgentManager = require "npc.AgentManager"

-- 批量注册原型 NPC
local npcList = {
    { name = "赵掌柜", title = "商人", age = 42, traits = { aggression = 0.1, friendliness = 0.85, bravery = 0.25 } },
    { name = "老王", title = "猎人", age = 58, traits = { aggression = 0.3, friendliness = 0.6, bravery = 0.7 } },
    { name = "铁卫", title = "守卫", age = 32, hp = 150, maxHp = 150, affinity = -5,
      traits = { aggression = 0.65, friendliness = 0.25, bravery = 0.85 } },
}

for _, def in ipairs(npcList) do
    local agent = AgentManager.Register(def)
    -- 为每个 NPC 创建 3D 节点...
end
```

### 3.2 创建自定义原型

开发者可基于现有原型创建变体：

```lua
--- 创建原型变体
---@param baseDef table 基础原型定义
---@param overrides table 覆盖参数
---@return GaiaAgentDef
function CreateVariant(baseDef, overrides)
    local def = {}
    for k, v in pairs(baseDef) do
        if type(v) == "table" then
            def[k] = {}
            for kk, vv in pairs(v) do
                def[k][kk] = vv
            end
        else
            def[k] = v
        end
    end
    for k, v in pairs(overrides) do
        if type(v) == "table" and type(def[k]) == "table" then
            for kk, vv in pairs(v) do
                def[k][kk] = vv
            end
        else
            def[k] = v
        end
    end
    return AgentDef.Create(def)
end

-- 示例：基于商人原型创建"黑市商人"
local blackMarketDef = CreateVariant(merchantDef, {
    name = "暗商",
    title = "黑市商人",
    affinity = -10,
    traits = { friendliness = 0.4, aggression = 0.4 },
})
```

---

## 4. 原型设计原则

1. **性格决定行为**：traits 三维度（aggression/friendliness/bravery）组合出不同性格
2. **初始状态暗示身份**：商人以 idle/trading 起始，守卫以 guarding 起始
3. **亲密度起点反映立场**：友方 NPC 正值，敌方 NPC 负值，中立 NPC 接近 0
4. **年龄影响能力**：老年 NPC 狩猎弱 → 自然产生需要帮助的任务
5. **HP 反映职业**：战斗型 NPC 高 HP，学者/商人型 NPC 低 HP

---

## 5. 代码放置与构建

所有 NPC 原型定义文件放在 `scripts/npc/archetypes/` 目录下：

```
scripts/
├── main.lua
└── npc/
    ├── AgentDef.lua
    ├── AgentFSM.lua
    ├── AffinitySystem.lua
    ├── PlayerInteraction.lua
    ├── QuestGenerator.lua
    ├── AgentManager.lua
    └── archetypes/
        ├── merchant.lua
        ├── hunter.lua
        ├── guard.lua
        └── traveler.lua
```

每次修改后使用 UrhoX MCP `build` 工具构建验证。
