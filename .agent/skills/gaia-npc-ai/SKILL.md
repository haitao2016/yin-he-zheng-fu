---
skill_name: "gaia-npc-ai"
version: "1.0.0"
description: "GAIA — 通用人工智能代理系统，为 NPC 赋予属性驱动的人格化行为、动态亲密度系统和程序化任务生成能力"
author: "UrhoX Skill Builder"
tags: ["npc", "ai", "agent", "affinity", "procedural-quest", "fsm", "game-ai"]
triggers:
  - "NPC AI"
  - "NPC 行为"
  - "NPC 人格"
  - "亲密度系统"
  - "程序化任务"
  - "NPC 互动"
  - "动态 NPC"
  - "gaia"
  - "npc agent"
---

# GAIA — 通用人工智能代理 NPC 系统

> **Generic Artificial Intelligence Agent for UrhoX Lua Games**
>
> 灵感来源：[victorqribeiro/gaia](https://github.com/victorqribeiro/gaia)
>
> 为游戏 NPC 赋予属性驱动的人格化行为，通过动态亲密度系统让玩家与 NPC 建立真实关系，
> 并基于 NPC 状态自动生成程序化任务。

---

## §1 Use When 触发条件

**Use when** users need to:

1. 为游戏 NPC 创建属性驱动的行为系统（饥饿、年龄、生命值影响行为决策）
2. 实现玩家与 NPC 的动态亲密度/好感度系统（喂食增加好感、攻击降低好感）
3. 基于 NPC 当前状态自动生成程序化任务/交互选项
4. 让 NPC 拥有"生活感"——自主狩猎、进食、衰老、死亡的生命周期
5. 设计 RPG/开放世界中的交互式 NPC 生态系统
6. 用户提到 "GAIA"、"NPC 人格"、"好感度"、"亲密度"、"程序化任务"、"动态 NPC"

**NOT for**（与其他 skill 区分）：

| 需求 | 推荐 Skill |
|------|-----------|
| 通用行为树/决策树 AI 架构 | `behavior-tree-ai` |
| 角色动画状态机（走/跑/跳） | `setup-fsm` |
| 游戏数值平衡/经济系统 | `game-balancing` |
| 完整游戏设计文档 | `game-forge-design` |

---

## §2 系统概览

GAIA 系统由四大核心模块组成：

```
┌──────────────────────────────────────────────────┐
│                  GAIA NPC 系统                    │
│                                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │  属性引擎   │  │ 状态机引擎  │  │ 亲密度引擎  │ │
│  │ Attributes │  │    FSM     │  │  Affinity  │ │
│  │            │←→│            │←→│            │ │
│  │ HP/饥饿/   │  │ idle/hunt/ │  │ 好感度计算  │ │
│  │ 年龄/食物  │  │ dead/trade │  │ 阵营系统   │ │
│  └────────────┘  └────────────┘  └────────────┘ │
│         ↕               ↕               ↕        │
│  ┌──────────────────────────────────────────────┐│
│  │            程序化任务生成器                     ││
│  │         Procedural Quest Generator            ││
│  │  NPC 状态 + 属性 + 亲密度 → 可用任务列表       ││
│  └──────────────────────────────────────────────┘│
└──────────────────────────────────────────────────┘
```

---

## §3 核心数据结构

### §3.1 Agent 定义

每个 NPC Agent 由以下属性驱动：

```lua
-- scripts/npc/AgentDef.lua
-- GAIA Agent 数据定义

---@class GaiaAgentDef
---@field name string          NPC 名称
---@field title string         NPC 头衔/职业
---@field age number           年龄（影响能力判定）
---@field maxAge number        最大寿命
---@field hp number            当前生命值
---@field maxHp number         最大生命值
---@field hunger number        饥饿度（0=饱，100=饥饿极限）
---@field food number          携带食物数量
---@field affinity number      对玩家的亲密度（-100 ~ 100）
---@field states table         可用状态列表
---@field currentState string  当前状态
---@field traits table         性格特征（影响行为倾向）

local AgentDef = {}

--- 创建默认 Agent 定义
---@param overrides table|nil  覆盖默认值
---@return GaiaAgentDef
function AgentDef.Create(overrides)
    local def = {
        name = "Unnamed",
        title = "Villager",
        age = 25,
        maxAge = 80,
        hp = 100,
        maxHp = 100,
        hunger = 0,
        food = 5,
        affinity = 0,       -- 中立
        states = { "idle", "hunting", "eating", "trading", "fleeing", "dead" },
        currentState = "idle",
        traits = {
            aggression = 0.3,    -- 攻击倾向 0~1
            friendliness = 0.5,  -- 友善倾向 0~1
            bravery = 0.5,       -- 勇气 0~1
        },
    }
    if overrides then
        for k, v in pairs(overrides) do
            def[k] = v
        end
    end
    return def
end

return AgentDef
```

### §3.2 属性约束规则

| 属性 | 范围 | 影响 |
|------|------|------|
| `age` | 0 ~ maxAge | 年龄 <10 或 >50 时，狩猎成功率降低 50% |
| `hp` | 0 ~ maxHp | HP ≤ 0 → 进入 `dead` 状态 |
| `hunger` | 0 ~ 100 | hunger > 70 → 自动切换到 `hunting` 状态 |
| `food` | 0 ~ ∞ | food > 0 时可进食恢复饥饿度 |
| `affinity` | -100 ~ 100 | 决定 NPC 对玩家的态度和可用交互 |

---

## §4 状态机引擎

### §4.1 状态定义

```lua
-- scripts/npc/AgentFSM.lua
-- GAIA Agent 状态机

local AgentFSM = {}

--- 状态转换规则表
--- 每个状态定义：进入条件、每帧更新逻辑、退出条件
AgentFSM.States = {
    -- ========== 空闲状态 ==========
    idle = {
        enter = function(agent)
            log:Write(LOG_DEBUG, agent.name .. " enters idle state")
        end,

        update = function(agent, dt)
            -- 饥饿度缓慢增加
            agent.hunger = math.min(100, agent.hunger + dt * 2.0)

            -- 饥饿度过高 → 狩猎
            if agent.hunger > 70 then
                if agent.food > 0 then
                    return "eating"    -- 有食物就吃
                else
                    return "hunting"   -- 没食物就猎
                end
            end

            -- 生命值过低 → 逃跑
            if agent.hp < agent.maxHp * 0.2 then
                return "fleeing"
            end

            return nil  -- 保持当前状态
        end,

        exit = function(agent) end,
    },

    -- ========== 狩猎状态 ==========
    hunting = {
        enter = function(agent)
            agent._huntTimer = 0
            agent._huntDuration = 3.0 + math.random() * 2.0  -- 3~5秒
            log:Write(LOG_DEBUG, agent.name .. " starts hunting")
        end,

        update = function(agent, dt)
            agent._huntTimer = agent._huntTimer + dt
            -- 饥饿继续增加（狩猎消耗体力）
            agent.hunger = math.min(100, agent.hunger + dt * 1.0)

            if agent._huntTimer >= agent._huntDuration then
                -- 狩猎成功率：年龄影响
                local successRate = 0.6
                if agent.age < 10 or agent.age > 50 then
                    successRate = successRate * 0.5  -- 年幼/年老降低成功率
                end
                -- 性格影响
                successRate = successRate + agent.traits.bravery * 0.2

                if math.random() < successRate then
                    agent.food = agent.food + math.random(1, 3)
                    log:Write(LOG_DEBUG, agent.name .. " hunt success\! food=" .. agent.food)
                else
                    log:Write(LOG_DEBUG, agent.name .. " hunt failed")
                end
                return "idle"
            end

            -- HP 过低中断狩猎
            if agent.hp < agent.maxHp * 0.15 then
                return "fleeing"
            end

            return nil
        end,

        exit = function(agent)
            agent._huntTimer = nil
            agent._huntDuration = nil
        end,
    },

    -- ========== 进食状态 ==========
    eating = {
        enter = function(agent)
            agent._eatTimer = 0
            log:Write(LOG_DEBUG, agent.name .. " starts eating")
        end,

        update = function(agent, dt)
            agent._eatTimer = agent._eatTimer + dt
            if agent._eatTimer >= 1.5 then
                if agent.food > 0 then
                    agent.food = agent.food - 1
                    agent.hunger = math.max(0, agent.hunger - 30)
                    agent.hp = math.min(agent.maxHp, agent.hp + 5)
                    log:Write(LOG_DEBUG, agent.name .. " ate food. hunger=" .. agent.hunger)
                end
                return "idle"
            end
            return nil
        end,

        exit = function(agent)
            agent._eatTimer = nil
        end,
    },

    -- ========== 交易状态 ==========
    trading = {
        enter = function(agent)
            log:Write(LOG_DEBUG, agent.name .. " is ready to trade")
        end,

        update = function(agent, dt)
            -- 交易状态由外部交互驱动，不会自动退出
            -- 饥饿继续增加
            agent.hunger = math.min(100, agent.hunger + dt * 0.5)
            if agent.hunger > 90 then
                return "hunting"  -- 太饿了，中断交易
            end
            return nil
        end,

        exit = function(agent) end,
    },

    -- ========== 逃跑状态 ==========
    fleeing = {
        enter = function(agent)
            agent._fleeTimer = 0
            log:Write(LOG_DEBUG, agent.name .. " is fleeing\!")
        end,

        update = function(agent, dt)
            agent._fleeTimer = agent._fleeTimer + dt
            -- 逃跑 5 秒后尝试恢复
            if agent._fleeTimer > 5.0 then
                if agent.hp > agent.maxHp * 0.3 then
                    return "idle"
                end
            end
            return nil
        end,

        exit = function(agent)
            agent._fleeTimer = nil
        end,
    },

    -- ========== 死亡状态 ==========
    dead = {
        enter = function(agent)
            log:Write(LOG_INFO, agent.name .. " has died")
            agent.hp = 0
        end,

        update = function(agent, dt)
            return nil  -- 死亡是终态
        end,

        exit = function(agent) end,
    },
}

--- 执行状态转换
---@param agent GaiaAgentDef
---@param newState string
function AgentFSM.TransitionTo(agent, newState)
    if agent.currentState == newState then return end
    if agent.currentState == "dead" then return end  -- 死亡不可逆

    local oldStateDef = AgentFSM.States[agent.currentState]
    local newStateDef = AgentFSM.States[newState]

    if not newStateDef then
        log:Write(LOG_WARNING, "Unknown state: " .. newState)
        return
    end

    if oldStateDef and oldStateDef.exit then
        oldStateDef.exit(agent)
    end

    agent.currentState = newState

    if newStateDef.enter then
        newStateDef.enter(agent)
    end
end

--- 每帧更新 Agent 状态
---@param agent GaiaAgentDef
---@param dt number 帧间隔（秒）
function AgentFSM.Update(agent, dt)
    -- 全局检查：HP 耗尽 → 死亡
    if agent.hp <= 0 and agent.currentState ~= "dead" then
        AgentFSM.TransitionTo(agent, "dead")
        return
    end

    -- 年龄增长（可选，配合游戏时间系统）
    -- agent.age = agent.age + dt * AGE_SPEED

    local stateDef = AgentFSM.States[agent.currentState]
    if stateDef and stateDef.update then
        local nextState = stateDef.update(agent, dt)
        if nextState then
            AgentFSM.TransitionTo(agent, nextState)
        end
    end
end

return AgentFSM
```

---

## §5 亲密度引擎

### §5.1 亲密度等级

```lua
-- scripts/npc/AffinitySystem.lua
-- GAIA 亲密度系统

local AffinitySystem = {}

--- 亲密度等级定义
AffinitySystem.Tiers = {
    { name = "sworn_enemy",  min = -100, max = -60, label = "死敌"   },
    { name = "hostile",      min = -59,  max = -20, label = "敌对"   },
    { name = "unfriendly",   min = -19,  max = -1,  label = "冷淡"   },
    { name = "neutral",      min = 0,    max = 20,  label = "中立"   },
    { name = "friendly",     min = 21,   max = 50,  label = "友好"   },
    { name = "close_friend", min = 51,   max = 80,  label = "亲密"   },
    { name = "devoted",      min = 81,   max = 100, label = "忠诚"   },
}

--- 获取当前亲密度等级
---@param affinity number
---@return table tier
function AffinitySystem.GetTier(affinity)
    for _, tier in ipairs(AffinitySystem.Tiers) do
        if affinity >= tier.min and affinity <= tier.max then
            return tier
        end
    end
    return AffinitySystem.Tiers[4]  -- 默认中立
end

--- 玩家对 NPC 执行正面互动（如喂食）
---@param agent GaiaAgentDef
---@param amount number 好感变化量
---@param reason string 原因描述
function AffinitySystem.PositiveInteraction(agent, amount, reason)
    local oldAffinity = agent.affinity
    -- 友善性格的 NPC 好感度增加更快
    local multiplier = 1.0 + agent.traits.friendliness * 0.5
    agent.affinity = math.min(100, agent.affinity + amount * multiplier)

    local oldTier = AffinitySystem.GetTier(oldAffinity)
    local newTier = AffinitySystem.GetTier(agent.affinity)

    if oldTier.name ~= newTier.name then
        log:Write(LOG_INFO, string.format(
            "%s affinity changed: %s → %s (reason: %s)",
            agent.name, oldTier.label, newTier.label, reason or "unknown"
        ))
    end
end

--- 玩家对 NPC 执行负面互动（如攻击）
---@param agent GaiaAgentDef
---@param amount number 好感变化量（正数，内部取负）
---@param reason string 原因描述
function AffinitySystem.NegativeInteraction(agent, amount, reason)
    local oldAffinity = agent.affinity
    -- 攻击性格的 NPC 好感度降低更慢（更能容忍冲突）
    local multiplier = 1.0 - agent.traits.aggression * 0.3
    agent.affinity = math.max(-100, agent.affinity - amount * multiplier)

    local oldTier = AffinitySystem.GetTier(oldAffinity)
    local newTier = AffinitySystem.GetTier(agent.affinity)

    if oldTier.name ~= newTier.name then
        log:Write(LOG_INFO, string.format(
            "%s affinity changed: %s → %s (reason: %s)",
            agent.name, oldTier.label, newTier.label, reason or "unknown"
        ))
    end
end

--- 获取 NPC 对玩家可用的交互列表
---@param agent GaiaAgentDef
---@return table interactions
function AffinitySystem.GetAvailableInteractions(agent)
    local tier = AffinitySystem.GetTier(agent.affinity)
    local interactions = {}

    -- 所有等级都可对话
    table.insert(interactions, { id = "talk", label = "对话", icon = "chat" })

    -- 中立及以上可交易
    if agent.affinity >= 0 then
        table.insert(interactions, { id = "trade", label = "交易", icon = "trade" })
    end

    -- 友好及以上可赠送/请求帮助
    if agent.affinity >= 21 then
        table.insert(interactions, { id = "give_gift", label = "赠送", icon = "gift" })
        table.insert(interactions, { id = "ask_help", label = "请求帮助", icon = "help" })
    end

    -- 亲密及以上可获得特殊任务
    if agent.affinity >= 51 then
        table.insert(interactions, { id = "special_quest", label = "特殊委托", icon = "quest" })
    end

    -- 忠诚等级可招募为同伴
    if agent.affinity >= 81 then
        table.insert(interactions, { id = "recruit", label = "招募同伴", icon = "recruit" })
    end

    -- 负面互动始终可用
    table.insert(interactions, { id = "feed", label = "喂食", icon = "food" })
    table.insert(interactions, { id = "attack", label = "攻击", icon = "sword" })

    return interactions
end

return AffinitySystem
```

---

## §6 玩家互动系统

### §6.1 核心互动接口

```lua
-- scripts/npc/PlayerInteraction.lua
-- 玩家与 NPC 的互动处理

local AffinitySystem -- = require("scripts路径") 实际使用时引入
local AgentFSM       -- = require("scripts路径") 实际使用时引入

local PlayerInteraction = {}

--- 喂食 NPC
---@param agent GaiaAgentDef
---@param foodAmount number 喂食数量（默认1）
---@return boolean success
---@return string message
function PlayerInteraction.Feed(agent, foodAmount)
    if agent.currentState == "dead" then
        return false, agent.name .. " 已经死了"
    end

    foodAmount = foodAmount or 1
    agent.food = agent.food + foodAmount
    agent.hunger = math.max(0, agent.hunger - 20 * foodAmount)
    agent.hp = math.min(agent.maxHp, agent.hp + 3 * foodAmount)

    -- 喂食增加好感
    AffinitySystem.PositiveInteraction(agent, 10 * foodAmount, "fed")

    local tier = AffinitySystem.GetTier(agent.affinity)
    return true, string.format(
        "%s 感激地接受了食物 (好感: %s, %d)",
        agent.name, tier.label, agent.affinity
    )
end

--- 攻击 NPC
---@param agent GaiaAgentDef
---@param damage number 伤害值
---@return boolean killed
---@return string message
function PlayerInteraction.Attack(agent, damage)
    if agent.currentState == "dead" then
        return false, agent.name .. " 已经死了"
    end

    damage = damage or 10
    agent.hp = math.max(0, agent.hp - damage)

    -- 攻击大幅降低好感
    AffinitySystem.NegativeInteraction(agent, 25, "attacked")

    if agent.hp <= 0 then
        AgentFSM.TransitionTo(agent, "dead")
        return true, agent.name .. " 被杀死了"
    end

    -- NPC 可能反击或逃跑
    if agent.traits.bravery > 0.6 and agent.hp > agent.maxHp * 0.3 then
        -- 勇敢且血量充足 → 反击状态（可扩展）
        return false, agent.name .. " 愤怒地准备反击！"
    else
        AgentFSM.TransitionTo(agent, "fleeing")
        return false, agent.name .. " 恐惧地逃跑了"
    end
end

--- 与 NPC 交易
---@param agent GaiaAgentDef
---@return boolean canTrade
---@return string message
function PlayerInteraction.Trade(agent)
    if agent.currentState == "dead" then
        return false, agent.name .. " 已经死了"
    end

    local tier = AffinitySystem.GetTier(agent.affinity)
    if agent.affinity < 0 then
        return false, agent.name .. " 拒绝与你交易（好感: " .. tier.label .. "）"
    end

    -- NPC 在狩猎中不可交易
    if agent.currentState == "hunting" then
        return false, agent.name .. " 正忙于狩猎，无暇交易"
    end

    AgentFSM.TransitionTo(agent, "trading")
    return true, agent.name .. " 愿意与你交易"
end

return PlayerInteraction
```

---

## §7 程序化任务生成器

### §7.1 任务生成逻辑

NPC 的当前状态 + 属性 + 亲密度共同决定可生成的任务：

```lua
-- scripts/npc/QuestGenerator.lua
-- GAIA 程序化任务生成

local AffinitySystem -- = require(...) 实际引入

local QuestGenerator = {}

---@class GaiaQuest
---@field id string          任务唯一 ID
---@field title string       任务标题
---@field description string 任务描述
---@field npcName string     发布者 NPC
---@field type string        任务类型
---@field requirements table 完成条件
---@field rewards table      奖励

--- 根据 NPC 当前状态生成可用任务
---@param agent GaiaAgentDef
---@return GaiaQuest[]
function QuestGenerator.Generate(agent)
    local quests = {}
    local tier = AffinitySystem.GetTier(agent.affinity)

    -- ===== 基于 NPC 状态的任务 =====

    -- 场景1: NPC 饥饿 → 寻找食物任务
    if agent.hunger > 50 and agent.food <= 0 then
        table.insert(quests, {
            id = "feed_" .. agent.name,
            title = "帮助饥饿的" .. agent.title,
            description = string.format(
                "%s (%s) 非常饥饿，需要食物。为他带来一些食物吧。",
                agent.name, agent.title
            ),
            npcName = agent.name,
            type = "deliver",
            requirements = { item = "food", amount = 3 },
            rewards = { affinity = 15, gold = 20 },
        })
    end

    -- 场景2: NPC 受伤 → 治疗任务
    if agent.hp < agent.maxHp * 0.5 and agent.currentState ~= "dead" then
        table.insert(quests, {
            id = "heal_" .. agent.name,
            title = "治疗受伤的" .. agent.title,
            description = string.format(
                "%s 受了重伤（HP: %d/%d），需要草药或治疗。",
                agent.name, agent.hp, agent.maxHp
            ),
            npcName = agent.name,
            type = "deliver",
            requirements = { item = "herb", amount = 2 },
            rewards = { affinity = 20, gold = 30 },
        })
    end

    -- 场景3: NPC 在狩猎但年龄不适合 → 代为狩猎
    if agent.currentState == "hunting" and (agent.age < 10 or agent.age > 50) then
        table.insert(quests, {
            id = "hunt_for_" .. agent.name,
            title = "为" .. agent.name .. "代猎",
            description = string.format(
                "%s 年事已高（%d岁），狩猎力不从心。帮他猎取猎物吧。",
                agent.name, agent.age
            ),
            npcName = agent.name,
            type = "kill",
            requirements = { target = "prey", amount = 2 },
            rewards = { affinity = 25, food = 5 },
        })
    end

    -- ===== 基于亲密度的任务 =====

    -- 友好及以上: NPC 提供特殊信息/线索
    if agent.affinity >= 21 then
        table.insert(quests, {
            id = "info_" .. agent.name,
            title = agent.name .. "的秘密消息",
            description = string.format(
                "%s 信任你，愿意分享一条重要线索。",
                agent.name
            ),
            npcName = agent.name,
            type = "talk",
            requirements = {},
            rewards = { clue = true, mapMarker = true },
        })
    end

    -- 亲密及以上: 护送任务
    if agent.affinity >= 51 then
        table.insert(quests, {
            id = "escort_" .. agent.name,
            title = "护送" .. agent.name,
            description = string.format(
                "%s 希望你护送他前往安全地带。",
                agent.name
            ),
            npcName = agent.name,
            type = "escort",
            requirements = { destination = "safe_zone" },
            rewards = { affinity = 30, gold = 100, specialItem = true },
        })
    end

    return quests
end

return QuestGenerator
```

### §7.2 经典任务场景（GAIA 原始设计）

| 场景 | NPC 状态 | 玩家行为 | 结果 |
|------|---------|---------|------|
| 商人忙于狩猎 | hunting | 等待/帮助狩猎 | 商人回归交易状态 |
| 商人忙于狩猎 | hunting | 杀死商人 | 获得物品但失去交易渠道 |
| 船夫在钓鱼 | hunting(fish) | 提供鱼 | 船夫恢复摆渡服务 |
| 流浪者饥饿 | idle(hungry) | 喂食 | 好感度大增，未来回报 |
| 老猎人体力不济 | hunting(弱) | 代为狩猎 | 获得猎人的特殊奖励 |

---

## §8 完整集成示例

### §8.1 3D 场景中的 GAIA NPC

以下展示如何在 UrhoX 3D 游戏中集成 GAIA 系统：

```lua
-- scripts/main.lua
-- GAIA NPC AI 完整集成示例

require "LuaScripts/Utilities/Sample"

-- 引入 GAIA 模块
local AgentDef = require "npc.AgentDef"
local AgentFSM = require "npc.AgentFSM"
local AffinitySystem = require "npc.AffinitySystem"
local PlayerInteraction = require "npc.PlayerInteraction"
local QuestGenerator = require "npc.QuestGenerator"

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type GaiaAgentDef[]
local agents_ = {}
---@type table<string, Node>
local agentNodes_ = {}

function Start()
    SampleStart()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    CreateScene()
    CreateNPCs()
    SetupCamera()
    SetupUI()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function CreateScene()
    -- 地面
    local floor = scene_:CreateChild("Floor")
    floor.position = Vector3(0, -0.5, 0)
    floor.scale = Vector3(50, 1, 50)
    local model = floor:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")

    -- 光照
    local lightNode = scene_:CreateChild("Light")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.brightness = 1.0
end

function CreateNPCs()
    -- 创建多个不同性格的 NPC
    local npcDefs = {
        { name = "老王", title = "猎人", age = 55, traits = { aggression = 0.2, friendliness = 0.7, bravery = 0.6 } },
        { name = "小李", title = "商人", age = 28, traits = { aggression = 0.1, friendliness = 0.9, bravery = 0.3 } },
        { name = "阿强", title = "战士", age = 35, traits = { aggression = 0.7, friendliness = 0.3, bravery = 0.9 } },
    }

    for i, def in ipairs(npcDefs) do
        local agent = AgentDef.Create(def)
        table.insert(agents_, agent)

        -- 创建 3D 节点
        local node = scene_:CreateChild(agent.name)
        node.position = Vector3((i - 2) * 5, 0, 10)
        local model = node:CreateComponent("AnimatedModel")
        model.model = cache:GetResource("Model", "Models/Mutant/Mutant.mdl")
        model.material = cache:GetResource("Material", "Models/Mutant/Materials/mutant_M.xml")

        agentNodes_[agent.name] = node
    end
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 8, -15)
    cameraNode_:LookAt(Vector3(0, 0, 5))
    local camera = cameraNode_:CreateComponent("Camera")
    camera.fov = 45.0

    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
end

function SetupUI()
    -- 使用 UrhoX UI 组件显示 NPC 信息
    local UI = require("urhox-libs/UI")
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })
    -- UI 面板将在 HandleUpdate 中动态更新
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 更新所有 NPC 的状态机
    for _, agent in ipairs(agents_) do
        AgentFSM.Update(agent, dt)

        -- 根据状态更新 3D 节点位置/动画
        local node = agentNodes_[agent.name]
        if node and agent.currentState == "hunting" then
            -- 狩猎时移动
            local dir = Vector3(math.random() - 0.5, 0, math.random() - 0.5):Normalized()
            node:Translate(dir * dt * 2.0)
        end
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- 按 1/2/3 选择 NPC，F 喂食，H 攻击
    if key == KEY_1 or key == KEY_2 or key == KEY_3 then
        local idx = key - KEY_1 + 1
        if agents_[idx] then
            selectedAgent_ = agents_[idx]
            log:Write(LOG_INFO, "Selected: " .. selectedAgent_.name)
        end
    end

    if selectedAgent_ then
        if key == KEY_F then
            local ok, msg = PlayerInteraction.Feed(selectedAgent_)
            log:Write(LOG_INFO, msg)
        elseif key == KEY_H then
            local killed, msg = PlayerInteraction.Attack(selectedAgent_, 15)
            log:Write(LOG_INFO, msg)
        elseif key == KEY_Q then
            local quests = QuestGenerator.Generate(selectedAgent_)
            for _, q in ipairs(quests) do
                log:Write(LOG_INFO, "Quest: " .. q.title .. " - " .. q.description)
            end
        end
    end
end

function Stop()
end
```

---

## §9 NPC 管理器（批量管理）

### §9.1 AgentManager

对于管理大量 NPC 的场景，使用管理器模式：

```lua
-- scripts/npc/AgentManager.lua
-- GAIA Agent 批量管理器

local AgentDef = require "npc.AgentDef"
local AgentFSM = require "npc.AgentFSM"
local AffinitySystem = require "npc.AffinitySystem"

local AgentManager = {
    agents = {},         -- name → agent
    agentList = {},      -- 有序列表
}

--- 注册新 NPC
---@param def table Agent 定义参数
---@return GaiaAgentDef
function AgentManager.Register(def)
    local agent = AgentDef.Create(def)
    AgentManager.agents[agent.name] = agent
    table.insert(AgentManager.agentList, agent)
    return agent
end

--- 按名称获取 NPC
---@param name string
---@return GaiaAgentDef|nil
function AgentManager.Get(name)
    return AgentManager.agents[name]
end

--- 每帧更新所有 NPC
---@param dt number
function AgentManager.UpdateAll(dt)
    for _, agent in ipairs(AgentManager.agentList) do
        AgentFSM.Update(agent, dt)
    end
end

--- 获取所有存活的 NPC
---@return GaiaAgentDef[]
function AgentManager.GetAlive()
    local alive = {}
    for _, agent in ipairs(AgentManager.agentList) do
        if agent.currentState ~= "dead" then
            table.insert(alive, agent)
        end
    end
    return alive
end

--- 获取指定亲密度范围的 NPC
---@param minAffinity number
---@param maxAffinity number|nil
---@return GaiaAgentDef[]
function AgentManager.GetByAffinity(minAffinity, maxAffinity)
    maxAffinity = maxAffinity or 100
    local result = {}
    for _, agent in ipairs(AgentManager.agentList) do
        if agent.affinity >= minAffinity and agent.affinity <= maxAffinity then
            table.insert(result, agent)
        end
    end
    return result
end

--- 保存所有 NPC 状态到文件
---@param filename string 相对路径，如 "saves/npc_state.json"
function AgentManager.SaveState(filename)
    local cjson = require "cjson"
    local data = {}
    for _, agent in ipairs(AgentManager.agentList) do
        -- 只保存持久化字段，跳过临时字段（以 _ 开头）
        local save = {}
        for k, v in pairs(agent) do
            if type(k) == "string" and k:sub(1,1) ~= "_" then
                save[k] = v
            end
        end
        table.insert(data, save)
    end

    local jsonStr = cjson.encode(data)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(jsonStr)
        file:Close()
        log:Write(LOG_INFO, "NPC state saved to " .. filename)
    end
end

--- 从文件加载 NPC 状态
---@param filename string
function AgentManager.LoadState(filename)
    local cjson = require "cjson"
    if not fileSystem:FileExists(filename) then
        log:Write(LOG_WARNING, "Save file not found: " .. filename)
        return false
    end

    local file = File(filename, FILE_READ)
    if not file then return false end

    local jsonStr = file:ReadLine()
    file:Close()

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        log:Write(LOG_ERROR, "Failed to parse save: " .. tostring(data))
        return false
    end

    -- 恢复 NPC 状态
    AgentManager.agents = {}
    AgentManager.agentList = {}
    for _, saveData in ipairs(data) do
        local agent = AgentDef.Create(saveData)
        AgentManager.agents[agent.name] = agent
        table.insert(AgentManager.agentList, agent)
    end

    log:Write(LOG_INFO, "NPC state loaded, count=" .. #AgentManager.agentList)
    return true
end

return AgentManager
```

---

## §10 自定义状态扩展

### §10.1 添加新状态

开发者可通过扩展 `AgentFSM.States` 表添加自定义状态：

```lua
-- scripts/npc/CustomStates.lua
-- 自定义 NPC 状态扩展

local AgentFSM = require "npc.AgentFSM"

-- 添加"守卫"状态
AgentFSM.States.guarding = {
    enter = function(agent)
        agent._guardPost = agent._currentPosition  -- 记录守卫位置
        log:Write(LOG_DEBUG, agent.name .. " is now guarding")
    end,

    update = function(agent, dt)
        agent.hunger = math.min(100, agent.hunger + dt * 1.5)

        -- 饥饿时暂离去觅食
        if agent.hunger > 80 then
            return "hunting"
        end
        return nil
    end,

    exit = function(agent)
        agent._guardPost = nil
    end,
}

-- 添加"睡眠"状态
AgentFSM.States.sleeping = {
    enter = function(agent)
        agent._sleepTimer = 0
        agent._sleepDuration = 5.0 + math.random() * 3.0
        log:Write(LOG_DEBUG, agent.name .. " falls asleep")
    end,

    update = function(agent, dt)
        agent._sleepTimer = agent._sleepTimer + dt
        -- 睡眠恢复 HP 和降低饥饿感知
        agent.hp = math.min(agent.maxHp, agent.hp + dt * 2.0)

        if agent._sleepTimer >= agent._sleepDuration then
            return "idle"
        end
        -- 被攻击时醒来（由外部交互触发状态转换）
        return nil
    end,

    exit = function(agent)
        agent._sleepTimer = nil
        agent._sleepDuration = nil
    end,
}
```

---

## §11 状态持久化与存档

### §11.1 状态文件格式

NPC 状态保存为 JSON，存储在 `scripts/` 可访问的路径下：

```json
[
  {
    "name": "老王",
    "title": "猎人",
    "age": 55,
    "maxAge": 80,
    "hp": 85,
    "maxHp": 100,
    "hunger": 45,
    "food": 3,
    "affinity": 35,
    "currentState": "idle",
    "traits": {
      "aggression": 0.2,
      "friendliness": 0.7,
      "bravery": 0.6
    }
  }
]
```

使用 `AgentManager.SaveState("saves/npc_data.json")` 和 `AgentManager.LoadState("saves/npc_data.json")` 进行存取。

详见：`engine-docs/recipes/file-storage.md`（文件读写沙箱规则）
详见：`engine-docs/recipes/json.md`（JSON 编解码推荐 cjson）

---

## §12 与 UrhoX 3D 场景集成

### §12.1 NPC 节点创建

```lua
--- 为 Agent 创建 3D 场景节点
---@param scene Scene 场景对象
---@param agent GaiaAgentDef
---@param position Vector3 初始位置
---@return Node
function CreateAgentNode(scene, agent, position)
    local node = scene:CreateChild(agent.name)
    node.position = position

    -- 模型（使用搜索到的 prefab 或内置模型）
    local model = node:CreateComponent("AnimatedModel")
    model.model = cache:GetResource("Model", "Models/Mutant/Mutant.mdl")
    model.material = cache:GetResource("Material",
        "Models/Mutant/Materials/mutant_M.xml")

    -- 添加动画控制器
    node:CreateComponent("AnimationController")

    -- 可选：添加碰撞体用于交互检测
    local body = node:CreateComponent("RigidBody")
    body:SetMass(0)  -- 静态用于触发检测
    body.collisionLayer = 2
    local shape = node:CreateComponent("CollisionShape")
    shape:SetCapsule(0.5, 1.8, Vector3(0, 0.9, 0))

    return node
end
```

### §12.2 状态驱动动画

```lua
--- 根据 NPC 状态播放对应动画
---@param node Node NPC 节点
---@param agent GaiaAgentDef
local function UpdateAgentAnimation(node, agent)
    local ctrl = node:GetComponent("AnimationController")
    if not ctrl then return end

    local animMap = {
        idle     = "Models/Mutant/Mutant_Idle.ani",
        hunting  = "Models/Mutant/Mutant_Run.ani",
        eating   = "Models/Mutant/Mutant_Idle.ani",
        trading  = "Models/Mutant/Mutant_Idle.ani",
        fleeing  = "Models/Mutant/Mutant_Run.ani",
        dead     = "Models/Mutant/Mutant_Death.ani",
    }

    local anim = animMap[agent.currentState]
    if anim then
        ctrl:PlayExclusive(anim, 0, agent.currentState ~= "dead", 0.3)
    end
end
```

---

## §13 UI 显示集成

### §13.1 NPC 信息面板（使用 UrhoX UI 组件）

```lua
-- 使用 UrhoX UI 组件显示 NPC 信息
local UI = require("urhox-libs/UI")

--- 创建 NPC 信息面板
---@param agent GaiaAgentDef
---@return table UIPanel
function CreateNPCInfoPanel(agent)
    local tier = AffinitySystem.GetTier(agent.affinity)

    -- 亲密度颜色映射
    local affinityColor
    if agent.affinity >= 51 then
        affinityColor = "#4CAF50"  -- 绿色（友好）
    elseif agent.affinity >= 0 then
        affinityColor = "#FFC107"  -- 黄色（中立）
    else
        affinityColor = "#F44336"  -- 红色（敌对）
    end

    return UI.Panel {
        width = 280, padding = 12,
        backgroundColor = "rgba(0,0,0,0.8)",
        borderRadius = 8,
        children = {
            UI.Label {
                text = agent.name .. " (" .. agent.title .. ")",
                fontSize = 18, fontColor = "#FFFFFF",
            },
            UI.Label {
                text = "年龄: " .. agent.age .. " | 状态: " .. agent.currentState,
                fontSize = 14, fontColor = "#CCCCCC",
            },
            UI.ProgressBar {
                value = agent.hp / agent.maxHp * 100,
                height = 8, backgroundColor = "#333",
                fillColor = "#E53935",  -- 红色 HP 条
            },
            UI.Label {
                text = string.format("HP: %d/%d", agent.hp, agent.maxHp),
                fontSize = 12, fontColor = "#FFFFFF",
            },
            UI.ProgressBar {
                value = (100 - agent.hunger),
                height = 8, backgroundColor = "#333",
                fillColor = "#FF9800",  -- 橙色饱食度条
            },
            UI.Label {
                text = string.format("好感: %s (%d)", tier.label, agent.affinity),
                fontSize = 14, fontColor = affinityColor,
            },
        }
    }
end
```

---

## §14 构建与调试

### §14.1 文件结构

```
scripts/
├── main.lua                 # 入口文件
└── npc/
    ├── AgentDef.lua          # Agent 数据定义
    ├── AgentFSM.lua          # 状态机引擎
    ├── AffinitySystem.lua    # 亲密度系统
    ├── PlayerInteraction.lua # 玩家互动接口
    ├── QuestGenerator.lua    # 程序化任务生成
    ├── AgentManager.lua      # 批量管理器
    └── CustomStates.lua      # 自定义状态扩展（可选）
```

### §14.2 构建命令

每次修改代码后，**必须调用构建工具**确保代码正确：

- 使用 UrhoX MCP `build` 工具进行构建
- 入口文件设置为 `main.lua`

### §14.3 调试建议

1. **首次运行**：在关键函数中添加 `log:Write(LOG_INFO, ...)` 输出
2. **状态观察**：按 Q 键查看当前 NPC 可用任务
3. **亲密度测试**：反复按 F（喂食）观察亲密度等级变化
4. **边界测试**：反复按 H（攻击）测试 NPC 死亡和负面好感

---

## §15 设计原则

### §15.1 GAIA 核心哲学

1. **NPC 不是道具**：每个 NPC 有自己的需求和生活节奏
2. **行为即叙事**：NPC 的状态自然产生故事（饥饿的猎人、逃跑的商人）
3. **关系有后果**：玩家行为通过亲密度系统产生持久影响
4. **涌现式任务**：任务由 NPC 状态自然生成，而非预设脚本

### §15.2 扩展建议

| 扩展方向 | 描述 |
|---------|------|
| NPC-NPC 关系 | 添加 NPC 之间的社交网络和互动 |
| 日夜周期 | NPC 根据时间切换活动（白天工作、夜晚睡觉） |
| 经济系统 | NPC 交易价格受亲密度和稀缺度影响 |
| 阵营系统 | NPC 归属不同阵营，阵营好感度联动 |
| 记忆系统 | NPC 记住玩家过去的行为，影响长期态度 |
| 对话系统 | 根据亲密度等级解锁不同对话选项 |

---

## §16 与其他 Skill 协作

| Skill | 协作方式 |
|-------|---------|
| `behavior-tree-ai` | GAIA 的状态机可作为 BT 叶节点使用 |
| `setup-fsm` | GAIA 管理游戏逻辑状态，setup-fsm 管理动画状态 |
| `materials` | NPC 视觉效果（材质切换表示状态变化） |
| `audio-manager` | NPC 状态变化触发音效（受伤、死亡、交易） |

---

## §17 API 速查

| 模块 | 关键函数 | 说明 |
|------|---------|------|
| `AgentDef` | `Create(overrides)` | 创建 NPC 定义 |
| `AgentFSM` | `Update(agent, dt)` | 每帧更新状态 |
| `AgentFSM` | `TransitionTo(agent, state)` | 手动切换状态 |
| `AffinitySystem` | `GetTier(affinity)` | 获取亲密度等级 |
| `AffinitySystem` | `PositiveInteraction(agent, amount, reason)` | 正面互动 |
| `AffinitySystem` | `NegativeInteraction(agent, amount, reason)` | 负面互动 |
| `AffinitySystem` | `GetAvailableInteractions(agent)` | 获取可用交互列表 |
| `PlayerInteraction` | `Feed(agent, amount)` | 喂食 NPC |
| `PlayerInteraction` | `Attack(agent, damage)` | 攻击 NPC |
| `PlayerInteraction` | `Trade(agent)` | 发起交易 |
| `QuestGenerator` | `Generate(agent)` | 生成程序化任务 |
| `AgentManager` | `Register(def)` | 注册 NPC |
| `AgentManager` | `UpdateAll(dt)` | 批量更新 |
| `AgentManager` | `SaveState(filename)` | 保存状态 |
| `AgentManager` | `LoadState(filename)` | 加载状态 |
