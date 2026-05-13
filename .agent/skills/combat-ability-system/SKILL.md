# Combat Ability System — UrhoX Lua 战斗能力系统框架

基于 [skills-for-antigravity](https://github.com/omer-metin/skills-for-antigravity) 的反重力战斗技能系统设计，
提炼为通用的游戏战斗能力框架，适用于 ARPG、MOBA、Roguelike、动作游戏等类型。

## Trigger

当用户需要以下功能时触发：
1. 实现技能/能力系统（定义技能、冷却、能量消耗、施法）
2. 实现 Buff/Debuff 系统
3. 实现技能树/解锁系统
4. 实现连招/Combo 系统
5. 实现元素交互/协同/克制系统
6. 实现资源/能量管理（MP、怒气、能量条）
7. 用户提到"技能系统"、"能力"、"Buff"、"冷却"、"Combo"、"技能树"

## Context

本 Skill 提供完整的战斗能力系统架构，包括：
- **AbilityDefinition**: 技能数据定义（消耗、冷却、范围、伤害参数）
- **AbilityManager**: 技能运行时管理（激活、冷却追踪、能量校验）
- **ResourceSystem**: 多资源池管理（生命、能量、怒气等）
- **CooldownManager**: 冷却计时与冷却缩减
- **BuffSystem**: Buff/Debuff 堆叠、持续时间、效果应用
- **SkillTree**: 技能解锁、前置条件、技能点分配
- **ComboSystem**: 输入序列检测、连招窗口、连招奖励
- **ElementSystem**: 元素反应、协同加成、克制关系
- **SynergyEngine**: 技能组合增效与反制计算

---

## §1 技能定义框架 (AbilityDefinition)

每个技能用一张 Lua table 定义，字段标准化：

```lua
---@class AbilityDef
---@field id string           技能唯一标识
---@field name string         显示名称
---@field type string         "active"|"passive"|"toggle"|"channeled"
---@field cost number         资源消耗
---@field costType string     "energy"|"mana"|"rage"|"health"
---@field cooldown number     冷却时间（秒）
---@field duration number     持续时间（秒），0=瞬发
---@field range number        施放距离（米）
---@field castTime number     施法时间（秒），0=即时
---@field params table        技能特有参数

-- 示例：重力反转技能（来自 antigravity 仓库）
local GravityInversion = {
    id = "gravity_inversion",
    name = "重力反转",
    type = "active",
    cost = 30,
    costType = "energy",
    cooldown = 8.0,
    duration = 5.0,
    range = 15.0,
    castTime = 0.0,
    params = {
        forceMultiplier = -1.0,     -- 反转重力方向
        areaRadius = 5.0,           -- 影响范围（米）
        maxTargets = 10,            -- 最大影响目标数
        rampTime = 0.3,             -- 达到最大力度的时间
    },
}

-- 示例：元素融合技能（多模式）
local ElementalFusion = {
    id = "elemental_fusion",
    name = "元素融合",
    type = "active",
    cost = 35,  -- 基础消耗，随元素变化
    costType = "energy",
    cooldown = 10.0,
    duration = 0,
    range = 12.0,
    castTime = 0.5,
    params = {
        elements = {
            fire  = { cost = 35, damage = 40, burnDps = 8, burnDuration = 4.0, levitateOnHit = true },
            ice   = { cost = 40, damage = 30, slowPercent = 0.5, freezeStacks = 3, freezeDuration = 2.0 },
            lightning = { cost = 45, damage = 55, chainCount = 4, chainRange = 8.0 },
            earth = { cost = 55, damage = 70, stunDuration = 1.5, areaRadius = 6.0, gravityWellDuration = 3.0 },
        },
        chargeLevel = { min = 0.5, max = 1.0 },  -- 蓄力倍率
    },
}
```

### 技能注册表

```lua
local AbilityRegistry = {}
AbilityRegistry.abilities = {}

function AbilityRegistry:Register(def)
    assert(def.id, "技能必须有 id")
    assert(def.cooldown and def.cooldown >= 0, "cooldown 必须 >= 0")
    self.abilities[def.id] = def
end

function AbilityRegistry:Get(id)
    return self.abilities[id]
end

-- 批量注册
function AbilityRegistry:RegisterAll(defs)
    for _, def in ipairs(defs) do
        self:Register(def)
    end
end
```

---

## §2 资源系统 (ResourceSystem)

管理多种资源池（生命、能量、怒气等），支持上限、再生、衰减：

```lua
local ResourceSystem = {}
ResourceSystem.__index = ResourceSystem

---@class ResourcePool
---@field current number
---@field max number
---@field regen number       每秒再生量
---@field decay number       每秒衰减量（如怒气消退）

function ResourceSystem:New()
    local o = setmetatable({}, self)
    o.pools = {}
    return o
end

function ResourceSystem:AddPool(name, max, regen, decay)
    self.pools[name] = {
        current = max,
        max = max,
        regen = regen or 0,
        decay = decay or 0,
    }
end

function ResourceSystem:GetCurrent(name)
    local pool = self.pools[name]
    return pool and pool.current or 0
end

function ResourceSystem:GetMax(name)
    local pool = self.pools[name]
    return pool and pool.max or 0
end

function ResourceSystem:GetPercent(name)
    local pool = self.pools[name]
    if not pool or pool.max == 0 then return 0 end
    return pool.current / pool.max
end

--- 消耗资源，成功返回 true
function ResourceSystem:Spend(name, amount)
    local pool = self.pools[name]
    if not pool then return false end
    if pool.current < amount then return false end
    pool.current = pool.current - amount
    return true
end

--- 恢复资源
function ResourceSystem:Restore(name, amount)
    local pool = self.pools[name]
    if not pool then return end
    pool.current = math.min(pool.max, pool.current + amount)
end

--- 每帧更新再生与衰减
function ResourceSystem:Update(dt)
    for _, pool in pairs(self.pools) do
        if pool.regen > 0 then
            pool.current = math.min(pool.max, pool.current + pool.regen * dt)
        end
        if pool.decay > 0 then
            pool.current = math.max(0, pool.current - pool.decay * dt)
        end
    end
end

-- 使用示例：
-- local resources = ResourceSystem:New()
-- resources:AddPool("energy", 100, 5, 0)   -- 100上限，5/秒再生
-- resources:AddPool("health", 500, 1, 0)   -- 500上限，1/秒再生
-- resources:AddPool("rage", 100, 0, 2)     -- 100上限，2/秒衰减
```

---

## §3 冷却管理器 (CooldownManager)

追踪所有技能冷却，支持冷却缩减(CDR)：

```lua
local CooldownManager = {}
CooldownManager.__index = CooldownManager

function CooldownManager:New()
    local o = setmetatable({}, self)
    o.cooldowns = {}   -- { [abilityId] = remainingTime }
    o.cdr = 0          -- 全局冷却缩减 (0~1)，0.3 = 30% CDR
    return o
end

--- 触发冷却
function CooldownManager:Trigger(abilityId, baseCooldown)
    local effectiveCD = baseCooldown * (1 - math.min(self.cdr, 0.75))  -- 上限75% CDR
    self.cooldowns[abilityId] = effectiveCD
end

--- 检查是否可用
function CooldownManager:IsReady(abilityId)
    local remaining = self.cooldowns[abilityId]
    return not remaining or remaining <= 0
end

--- 获取剩余冷却
function CooldownManager:GetRemaining(abilityId)
    return math.max(0, self.cooldowns[abilityId] or 0)
end

--- 获取冷却进度 (0~1，1=完全就绪)
function CooldownManager:GetProgress(abilityId, baseCooldown)
    local remaining = self.cooldowns[abilityId]
    if not remaining or remaining <= 0 then return 1.0 end
    local effectiveCD = baseCooldown * (1 - math.min(self.cdr, 0.75))
    return 1.0 - (remaining / effectiveCD)
end

--- 重置特定技能冷却
function CooldownManager:Reset(abilityId)
    self.cooldowns[abilityId] = nil
end

--- 减少冷却时间（如击杀返还）
function CooldownManager:ReduceCooldown(abilityId, amount)
    if self.cooldowns[abilityId] then
        self.cooldowns[abilityId] = math.max(0, self.cooldowns[abilityId] - amount)
    end
end

--- 每帧更新
function CooldownManager:Update(dt)
    for id, remaining in pairs(self.cooldowns) do
        remaining = remaining - dt
        if remaining <= 0 then
            self.cooldowns[id] = nil
        else
            self.cooldowns[id] = remaining
        end
    end
end
```

---

## §4 Buff/Debuff 系统

支持效果堆叠、持续时间、定时刷新和效果回调：

```lua
local BuffSystem = {}
BuffSystem.__index = BuffSystem

---@class BuffDef
---@field id string
---@field name string
---@field type string          "buff"|"debuff"
---@field duration number       持续时间（秒）
---@field maxStacks number      最大堆叠层数
---@field tickInterval number   周期性触发间隔（秒），0=不触发
---@field onApply function      应用回调 (target, stacks)
---@field onTick function       周期回调 (target, stacks, dt)
---@field onExpire function     过期回调 (target, stacks)
---@field onStack function      堆叠回调 (target, oldStacks, newStacks)

function BuffSystem:New()
    local o = setmetatable({}, self)
    o.activeBuffs = {}   -- { [targetId] = { [buffId] = BuffInstance } }
    o.definitions = {}
    return o
end

function BuffSystem:RegisterBuff(def)
    self.definitions[def.id] = def
end

function BuffSystem:Apply(targetId, buffId, target)
    local def = self.definitions[buffId]
    if not def then return end

    if not self.activeBuffs[targetId] then
        self.activeBuffs[targetId] = {}
    end

    local existing = self.activeBuffs[targetId][buffId]
    if existing then
        -- 堆叠或刷新
        local oldStacks = existing.stacks
        existing.stacks = math.min(existing.stacks + 1, def.maxStacks or 1)
        existing.remaining = def.duration  -- 刷新持续时间
        if def.onStack then
            def.onStack(target, oldStacks, existing.stacks)
        end
    else
        -- 首次应用
        local instance = {
            stacks = 1,
            remaining = def.duration,
            tickTimer = 0,
        }
        self.activeBuffs[targetId][buffId] = instance
        if def.onApply then
            def.onApply(target, 1)
        end
    end
end

function BuffSystem:Remove(targetId, buffId, target)
    local targetBuffs = self.activeBuffs[targetId]
    if not targetBuffs then return end
    local instance = targetBuffs[buffId]
    if not instance then return end

    local def = self.definitions[buffId]
    if def and def.onExpire then
        def.onExpire(target, instance.stacks)
    end
    targetBuffs[buffId] = nil
end

function BuffSystem:HasBuff(targetId, buffId)
    local targetBuffs = self.activeBuffs[targetId]
    if not targetBuffs then return false end
    return targetBuffs[buffId] ~= nil
end

function BuffSystem:GetStacks(targetId, buffId)
    local targetBuffs = self.activeBuffs[targetId]
    if not targetBuffs then return 0 end
    local instance = targetBuffs[buffId]
    return instance and instance.stacks or 0
end

function BuffSystem:Update(dt, getTarget)
    for targetId, buffs in pairs(self.activeBuffs) do
        local target = getTarget(targetId)
        local toRemove = {}
        for buffId, instance in pairs(buffs) do
            local def = self.definitions[buffId]
            -- 持续时间倒计时
            instance.remaining = instance.remaining - dt
            if instance.remaining <= 0 then
                toRemove[#toRemove + 1] = buffId
            elseif def.tickInterval and def.tickInterval > 0 then
                -- 周期性触发
                instance.tickTimer = instance.tickTimer + dt
                if instance.tickTimer >= def.tickInterval then
                    instance.tickTimer = instance.tickTimer - def.tickInterval
                    if def.onTick then
                        def.onTick(target, instance.stacks, dt)
                    end
                end
            end
        end
        for _, buffId in ipairs(toRemove) do
            self:Remove(targetId, buffId, target)
        end
    end
end

-- 使用示例：
-- buffSys:RegisterBuff({
--     id = "burn", name = "燃烧", type = "debuff",
--     duration = 4.0, maxStacks = 3, tickInterval = 1.0,
--     onApply = function(t, s) print(t.name .. " 着火了！") end,
--     onTick = function(t, s, dt) t.health = t.health - 8 * s end,
--     onExpire = function(t, s) print(t.name .. " 火焰熄灭") end,
-- })
```

---

## §5 能力管理器 (AbilityManager)

核心运行时，整合注册表、资源、冷却，处理技能施放的完整流程：

```lua
local AbilityManager = {}
AbilityManager.__index = AbilityManager

function AbilityManager:New(registry, resources, cooldowns, buffSystem)
    local o = setmetatable({}, self)
    o.registry = registry
    o.resources = resources
    o.cooldowns = cooldowns
    o.buffSystem = buffSystem
    o.casting = nil       -- 当前施法中的技能
    o.castTimer = 0
    o.channeling = nil    -- 当前引导中的技能
    o.channelTimer = 0
    o.toggles = {}        -- 激活中的切换技能 { [id] = true }
    return o
end

--- 尝试激活技能
---@return boolean success
---@return string|nil reason  失败原因
function AbilityManager:Activate(abilityId, params)
    local def = self.registry:Get(abilityId)
    if not def then return false, "unknown_ability" end

    -- 检查冷却
    if not self.cooldowns:IsReady(abilityId) then
        return false, "on_cooldown"
    end

    -- 检查资源
    local cost = def.cost
    if params and params.element and def.params.elements then
        local elemData = def.params.elements[params.element]
        if elemData and elemData.cost then cost = elemData.cost end
    end
    if not self.resources:Spend(def.costType, cost) then
        return false, "insufficient_resource"
    end

    -- 检查施法中/引导中冲突
    if self.casting then return false, "already_casting" end

    -- 根据类型处理
    if def.type == "toggle" then
        return self:_handleToggle(abilityId, def)
    elseif def.castTime and def.castTime > 0 then
        return self:_startCast(abilityId, def, params)
    else
        -- 即时施放
        self.cooldowns:Trigger(abilityId, def.cooldown)
        return true, nil
    end
end

function AbilityManager:_handleToggle(abilityId, def)
    if self.toggles[abilityId] then
        self.toggles[abilityId] = nil
        self.cooldowns:Trigger(abilityId, def.cooldown)
        return true, nil  -- 关闭
    else
        self.toggles[abilityId] = true
        return true, nil  -- 开启
    end
end

function AbilityManager:_startCast(abilityId, def, params)
    self.casting = { id = abilityId, def = def, params = params }
    self.castTimer = def.castTime
    return true, nil
end

--- 取消施法
function AbilityManager:CancelCast()
    if self.casting then
        -- 返还部分资源
        local def = self.casting.def
        self.resources:Restore(def.costType, def.cost * 0.5)
        self.casting = nil
        self.castTimer = 0
    end
end

--- 每帧更新
function AbilityManager:Update(dt)
    -- 更新施法
    if self.casting then
        self.castTimer = self.castTimer - dt
        if self.castTimer <= 0 then
            local def = self.casting.def
            self.cooldowns:Trigger(self.casting.id, def.cooldown)
            self.casting = nil
            self.castTimer = 0
        end
    end

    -- 更新切换技能的持续消耗
    for id in pairs(self.toggles) do
        local def = self.registry:Get(id)
        if def then
            local costPerSec = def.cost  -- Toggle 的 cost 按每秒算
            if not self.resources:Spend(def.costType, costPerSec * dt) then
                self.toggles[id] = nil   -- 资源耗尽自动关闭
            end
        end
    end

    self.cooldowns:Update(dt)
    self.resources:Update(dt)
end
```

---

## §6 技能树系统 (SkillTree)

管理技能解锁、前置条件、技能点分配：

```lua
local SkillTree = {}
SkillTree.__index = SkillTree

---@class SkillNode
---@field id string            技能ID
---@field tier number          层级（1=起始）
---@field prerequisites string[] 前置技能ID列表
---@field pointCost number     解锁所需技能点
---@field maxRank number       最大等级
---@field rankBonuses table    每级加成 { [rank] = { field = value } }

function SkillTree:New()
    local o = setmetatable({}, self)
    o.nodes = {}          -- { [id] = SkillNode }
    o.unlocked = {}       -- { [id] = currentRank }
    o.skillPoints = 0
    return o
end

function SkillTree:AddNode(node)
    self.nodes[node.id] = node
    node.maxRank = node.maxRank or 1
    node.pointCost = node.pointCost or 1
    node.prerequisites = node.prerequisites or {}
end

function SkillTree:AddPoints(amount)
    self.skillPoints = self.skillPoints + amount
end

--- 检查是否可解锁/升级
function SkillTree:CanUnlock(nodeId)
    local node = self.nodes[nodeId]
    if not node then return false, "unknown_node" end

    local currentRank = self.unlocked[nodeId] or 0
    if currentRank >= node.maxRank then return false, "max_rank" end
    if self.skillPoints < node.pointCost then return false, "insufficient_points" end

    -- 检查前置条件
    for _, preId in ipairs(node.prerequisites) do
        if not self.unlocked[preId] or self.unlocked[preId] < 1 then
            return false, "prerequisite_" .. preId
        end
    end

    return true, nil
end

--- 解锁/升级技能
function SkillTree:Unlock(nodeId)
    local ok, reason = self:CanUnlock(nodeId)
    if not ok then return false, reason end

    local node = self.nodes[nodeId]
    self.skillPoints = self.skillPoints - node.pointCost
    self.unlocked[nodeId] = (self.unlocked[nodeId] or 0) + 1
    return true, self.unlocked[nodeId]
end

--- 获取技能当前等级
function SkillTree:GetRank(nodeId)
    return self.unlocked[nodeId] or 0
end

--- 重置所有技能点
function SkillTree:ResetAll()
    local refund = 0
    for id, rank in pairs(self.unlocked) do
        local node = self.nodes[id]
        if node then refund = refund + node.pointCost * rank end
    end
    self.unlocked = {}
    self.skillPoints = self.skillPoints + refund
    return refund
end

-- 使用示例（反重力技能树）：
-- tree:AddNode({ id = "gravity_inversion", tier = 1, prerequisites = {} })
-- tree:AddNode({ id = "blade_dance",       tier = 2, prerequisites = {"gravity_inversion"} })
-- tree:AddNode({ id = "null_gravity_zone",  tier = 2, prerequisites = {"gravity_inversion"} })
-- tree:AddNode({ id = "force_field",        tier = 2, prerequisites = {"gravity_inversion"} })
-- tree:AddNode({ id = "quantum_leap",       tier = 3, prerequisites = {"blade_dance", "null_gravity_zone", "force_field"} })
-- tree:AddNode({ id = "elemental_fusion",   tier = 4, prerequisites = {"quantum_leap"} })
```

---

## §7 连招系统 (ComboSystem)

检测输入序列，管理连招窗口和连招奖励：

```lua
local ComboSystem = {}
ComboSystem.__index = ComboSystem

---@class ComboSequence
---@field id string
---@field name string
---@field steps string[]       按顺序的技能ID序列
---@field windowTime number    每步之间的最大间隔（秒）
---@field bonusDamage number   连招完成的伤害加成倍率
---@field onComplete function  连招完成回调

function ComboSystem:New()
    local o = setmetatable({}, self)
    o.combos = {}          -- 已注册的连招
    o.inputHistory = {}    -- 输入历史 { { id = abilityId, time = timestamp } }
    o.currentTime = 0
    o.maxHistorySize = 10
    return o
end

function ComboSystem:RegisterCombo(combo)
    combo.windowTime = combo.windowTime or 2.0
    combo.bonusDamage = combo.bonusDamage or 1.5
    self.combos[combo.id] = combo
end

--- 记录一次技能使用
function ComboSystem:RecordInput(abilityId)
    self.inputHistory[#self.inputHistory + 1] = {
        id = abilityId,
        time = self.currentTime,
    }
    -- 裁剪过长历史
    while #self.inputHistory > self.maxHistorySize do
        table.remove(self.inputHistory, 1)
    end
    -- 检查连招触发
    return self:_checkCombos()
end

function ComboSystem:_checkCombos()
    local triggered = {}
    for comboId, combo in pairs(self.combos) do
        if self:_matchSequence(combo) then
            triggered[#triggered + 1] = combo
            if combo.onComplete then combo.onComplete() end
        end
    end
    return triggered
end

function ComboSystem:_matchSequence(combo)
    local steps = combo.steps
    local stepCount = #steps
    local histLen = #self.inputHistory
    if histLen < stepCount then return false end

    -- 从历史末尾向前匹配
    local histIdx = histLen
    for stepIdx = stepCount, 1, -1 do
        if histIdx < 1 then return false end
        local entry = self.inputHistory[histIdx]
        if entry.id ~= steps[stepIdx] then return false end
        -- 检查窗口时间（除第一步外）
        if stepIdx < stepCount then
            local nextEntry = self.inputHistory[histIdx + 1]
            if nextEntry.time - entry.time > combo.windowTime then
                return false
            end
        end
        histIdx = histIdx - 1
    end
    return true
end

function ComboSystem:Update(dt)
    self.currentTime = self.currentTime + dt
    -- 清理过期的输入
    local cutoff = self.currentTime - 10.0  -- 10秒过期
    while #self.inputHistory > 0 and self.inputHistory[1].time < cutoff do
        table.remove(self.inputHistory, 1)
    end
end

-- 使用示例（反重力连招）：
-- combo:RegisterCombo({
--     id = "gravity_storm",
--     name = "重力风暴",
--     steps = {"gravity_inversion", "null_gravity_zone", "elemental_fusion"},
--     windowTime = 3.0,
--     bonusDamage = 2.0,
--     onComplete = function() print("连招触发：重力风暴！") end,
-- })
```

---

## §8 元素系统 (ElementSystem)

管理元素反应、协同加成、克制关系：

```lua
local ElementSystem = {}
ElementSystem.__index = ElementSystem

function ElementSystem:New()
    local o = setmetatable({}, self)
    -- 元素克制关系 { [攻击元素] = { [防御元素] = 倍率 } }
    o.effectiveness = {
        fire      = { ice = 0.5, earth = 2.0, lightning = 1.0 },
        ice       = { fire = 2.0, earth = 1.0, lightning = 0.5 },
        lightning  = { fire = 1.0, ice = 2.0, earth = 0.5 },
        earth     = { fire = 0.5, ice = 1.0, lightning = 2.0 },
    }
    -- 元素反应（两种元素碰撞产生的效果）
    o.reactions = {
        ["fire+ice"]       = { id = "steam",    name = "蒸汽", damageBonus = 1.3, aoeRadius = 4.0 },
        ["fire+earth"]     = { id = "magma",    name = "熔岩", damageBonus = 1.5, dot = 10, dotDuration = 3.0 },
        ["ice+lightning"]   = { id = "shatter",  name = "碎裂", damageBonus = 2.0, stunDuration = 1.0 },
        ["lightning+earth"] = { id = "magnetic", name = "磁场", pullForce = 300, pullDuration = 2.0 },
    }
    return o
end

--- 计算元素伤害倍率
function ElementSystem:GetEffectiveness(attackElement, defenseElement)
    if not attackElement or not defenseElement then return 1.0 end
    local row = self.effectiveness[attackElement]
    if not row then return 1.0 end
    return row[defenseElement] or 1.0
end

--- 检查两种元素是否触发反应
function ElementSystem:CheckReaction(elemA, elemB)
    if not elemA or not elemB or elemA == elemB then return nil end
    -- 排序保证查找一致性
    local key1 = elemA .. "+" .. elemB
    local key2 = elemB .. "+" .. elemA
    return self.reactions[key1] or self.reactions[key2]
end

--- 注册自定义元素反应
function ElementSystem:RegisterReaction(elemA, elemB, reaction)
    local key = elemA .. "+" .. elemB
    self.reactions[key] = reaction
end

--- 注册自定义克制关系
function ElementSystem:SetEffectiveness(attackElem, defenseElem, multiplier)
    if not self.effectiveness[attackElem] then
        self.effectiveness[attackElem] = {}
    end
    self.effectiveness[attackElem][defenseElem] = multiplier
end
```

---

## §9 协同引擎 (SynergyEngine)

管理技能之间的协同和克制关系：

```lua
local SynergyEngine = {}
SynergyEngine.__index = SynergyEngine

---@class SynergyRule
---@field abilities string[]    参与的技能ID
---@field type string           "amplify"|"extend"|"chain"|"counter"
---@field modifier table        效果修改 { damageMultiplier, durationExtend, etc. }
---@field condition function    触发条件（可选）

function SynergyEngine:New()
    local o = setmetatable({}, self)
    o.rules = {}
    return o
end

function SynergyEngine:AddRule(rule)
    self.rules[#self.rules + 1] = rule
end

--- 查询给定两个技能之间的协同
function SynergyEngine:GetSynergies(abilityA, abilityB)
    local results = {}
    for _, rule in ipairs(self.rules) do
        local found = {}
        for _, id in ipairs(rule.abilities) do
            found[id] = true
        end
        if found[abilityA] and found[abilityB] then
            if not rule.condition or rule.condition() then
                results[#results + 1] = rule
            end
        end
    end
    return results
end

--- 计算协同后的伤害倍率
function SynergyEngine:CalcDamageMultiplier(abilityId, activeAbilities)
    local multiplier = 1.0
    for _, rule in ipairs(self.rules) do
        if rule.type == "amplify" and rule.modifier.damageMultiplier then
            local hasAbility = false
            local hasPartner = false
            for _, id in ipairs(rule.abilities) do
                if id == abilityId then hasAbility = true end
                for _, activeId in ipairs(activeAbilities) do
                    if id == activeId and id ~= abilityId then hasPartner = true end
                end
            end
            if hasAbility and hasPartner then
                multiplier = multiplier * rule.modifier.damageMultiplier
            end
        end
    end
    return multiplier
end

-- 使用示例（反重力系统的协同规则）：
-- synergy:AddRule({
--     abilities = {"gravity_inversion", "null_gravity_zone"},
--     type = "amplify",
--     modifier = { damageMultiplier = 1.5, description = "双重重力混乱" },
-- })
-- synergy:AddRule({
--     abilities = {"blade_dance", "gravity_inversion"},
--     type = "extend",
--     modifier = { durationExtend = 3.0, description = "反重力下无限滞空" },
-- })
-- synergy:AddRule({
--     abilities = {"force_field", "null_gravity_zone"},
--     type = "amplify",
--     modifier = { damageMultiplier = 1.3, description = "零重力护盾增幅" },
-- })
```

---

## §10 UrhoX 集成示例

完整的 UrhoX Lua 集成，展示如何将上述系统接入游戏场景：

```lua
-- === main.lua: 战斗能力系统集成 ===

-- 初始化各子系统
local registry  = AbilityRegistry
local resources = ResourceSystem:New()
local cooldowns = CooldownManager:New()
local buffs     = BuffSystem:New()
local manager   = AbilityManager:New(registry, resources, cooldowns, buffs)
local tree      = SkillTree:New()
local combo     = ComboSystem:New()
local elements  = ElementSystem:New()
local synergy   = SynergyEngine:New()

function Start()
    -- 设置资源池
    resources:AddPool("energy", 100, 5, 0)   -- 100上限，5/秒再生
    resources:AddPool("health", 500, 1, 0)

    -- 注册技能
    registry:RegisterAll({
        GravityInversion,  -- 来自 §1 定义
        ElementalFusion,
    })

    -- 配置技能树
    tree:AddNode({ id = "gravity_inversion", tier = 1 })
    tree:AddNode({ id = "elemental_fusion",  tier = 2, prerequisites = {"gravity_inversion"} })
    tree:AddPoints(5)  -- 初始技能点

    -- 注册 Buff
    buffs:RegisterBuff({
        id = "burn", name = "燃烧", type = "debuff",
        duration = 4.0, maxStacks = 3, tickInterval = 1.0,
        onTick = function(target, stacks)
            if target and target.health then
                target.health = target.health - 8 * stacks
            end
        end,
    })

    -- 注册连招
    combo:RegisterCombo({
        id = "gravity_storm",
        name = "重力风暴",
        steps = {"gravity_inversion", "elemental_fusion"},
        windowTime = 3.0,
        bonusDamage = 2.0,
    })

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    manager:Update(dt)
    buffs:Update(dt, function(id) return enemies[id] end)
    combo:Update(dt)
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_1 then
        local ok, reason = manager:Activate("gravity_inversion", {
            target = Vector3(0, 0, 10),
        })
        if ok then
            combo:RecordInput("gravity_inversion")
        else
            print("施放失败: " .. (reason or ""))
        end
    elseif key == KEY_2 then
        local ok, reason = manager:Activate("elemental_fusion", {
            element = "fire",
            target = Vector3(0, 0, 10),
        })
        if ok then
            local triggered = combo:RecordInput("elemental_fusion")
            for _, c in ipairs(triggered) do
                print("连招触发: " .. c.name .. " (x" .. c.bonusDamage .. " 伤害)")
            end
        end
    end
end
```

---

## §11 反制系统 (Counter System)

每个技能都应有明确的反制方式，保证战斗平衡：

```lua
local CounterSystem = {}
CounterSystem.__index = CounterSystem

function CounterSystem:New()
    local o = setmetatable({}, self)
    -- { [abilityId] = { conditions } }
    o.counters = {}
    return o
end

---@class CounterRule
---@field abilityId string        被反制的技能
---@field counterType string      "resist"|"immune"|"reflect"|"absorb"
---@field condition function      判断条件 (target) -> boolean
---@field description string      描述

function CounterSystem:AddCounter(abilityId, rule)
    if not self.counters[abilityId] then
        self.counters[abilityId] = {}
    end
    self.counters[abilityId][#self.counters[abilityId] + 1] = rule
end

--- 检查目标是否反制了该技能
---@return string|nil counterType, string|nil description
function CounterSystem:Check(abilityId, target)
    local rules = self.counters[abilityId]
    if not rules then return nil end
    for _, rule in ipairs(rules) do
        if rule.condition(target) then
            return rule.counterType, rule.description
        end
    end
    return nil
end

-- 使用示例（反重力系统的反制规则）：
-- counters:AddCounter("gravity_inversion", {
--     counterType = "resist",
--     condition = function(t) return t.mass and t.mass > 500 end,
--     description = "质量 > 500kg 的物体抵抗重力反转",
-- })
-- counters:AddCounter("gravity_inversion", {
--     counterType = "immune",
--     condition = function(t) return t.anchored == true end,
--     description = "锚定实体免疫重力效果",
-- })
-- counters:AddCounter("quantum_leap", {
--     counterType = "immune",
--     condition = function(t) return t.antiTeleportZone == true end,
--     description = "反传送区域内无法量子跃迁",
-- })
```

---

## §12 伤害计算管线

将元素、Buff、协同、反制整合的完整伤害计算：

```lua
--- 计算最终伤害
---@param baseDamage number      基础伤害
---@param abilityId string       技能ID
---@param attackElement string|nil 攻击元素
---@param target table           目标数据
---@param activeAbilities string[] 当前活跃的其他技能
---@return number finalDamage
---@return table details         计算明细
local function CalculateDamage(baseDamage, abilityId, attackElement, target, activeAbilities)
    local details = { base = baseDamage }
    local damage = baseDamage

    -- 1. 反制检查
    local counterType = CounterSystem:Check(abilityId, target)
    if counterType == "immune" then
        return 0, { base = baseDamage, counter = "immune", final = 0 }
    elseif counterType == "resist" then
        damage = damage * 0.3
        details.resist = 0.3
    elseif counterType == "reflect" then
        details.reflected = true
    elseif counterType == "absorb" then
        details.absorbed = true
        return 0, details
    end

    -- 2. 元素克制
    local elemMult = elements:GetEffectiveness(attackElement, target.element)
    damage = damage * elemMult
    details.elementMultiplier = elemMult

    -- 3. 协同加成
    local synergyMult = synergy:CalcDamageMultiplier(abilityId, activeAbilities)
    damage = damage * synergyMult
    details.synergyMultiplier = synergyMult

    -- 4. Buff/Debuff 修正
    local vulnStacks = buffs:GetStacks(target.id, "vulnerability")
    if vulnStacks > 0 then
        local buffMult = 1.0 + 0.1 * vulnStacks  -- 每层 +10%
        damage = damage * buffMult
        details.vulnerabilityMultiplier = buffMult
    end

    -- 5. 连招加成（由外部传入）
    -- 实际使用时从 ComboSystem 获取

    -- 6. 元素反应
    local reaction = elements:CheckReaction(attackElement, target.element)
    if reaction then
        damage = damage * (reaction.damageBonus or 1.0)
        details.reaction = reaction.id
    end

    details.final = math.floor(damage)
    return details.final, details
end
```

---

## §13 快速集成检查清单

将战斗能力系统接入 UrhoX 项目的步骤：

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 定义技能表 | 按 §1 格式为每个技能创建 AbilityDef |
| 2 | 初始化资源池 | §2 ResourceSystem 配置 HP/MP/Energy 等 |
| 3 | 注册技能到注册表 | §1 AbilityRegistry:Register() |
| 4 | 配置冷却管理器 | §3 CooldownManager，设置全局 CDR |
| 5 | 注册 Buff/Debuff | §4 BuffSystem，定义效果回调 |
| 6 | 创建 AbilityManager | §5 连接各子系统 |
| 7 | (可选) 配置技能树 | §6 SkillTree 定义解锁路线 |
| 8 | (可选) 注册连招 | §7 ComboSystem 定义连招序列 |
| 9 | (可选) 配置元素系统 | §8 ElementSystem 设置克制/反应 |
| 10 | (可选) 设置协同规则 | §9 SynergyEngine 定义增效/反制 |
| 11 | HandleUpdate 中更新 | manager:Update(dt), buffs:Update(dt), combo:Update(dt) |
| 12 | 输入事件中激活 | manager:Activate(abilityId, params) |

---

## §14 常见问题与排错

| 问题 | 原因 | 解决 |
|------|------|------|
| 技能无法施放 | 冷却未就绪或资源不足 | 检查 CooldownManager:IsReady() 和 ResourceSystem:GetCurrent() |
| Buff 不生效 | 忘记在 Update 中调用 BuffSystem:Update() | 确保每帧更新 |
| 连招不触发 | windowTime 太短或步骤顺序错误 | 加大 windowTime，检查 steps 数组顺序 |
| 技能树解锁失败 | 前置条件未满足 | 检查 prerequisites 列表 |
| 切换技能自动关闭 | 资源耗尽 | 检查 Toggle 的每秒消耗与再生速率 |
| CDR 无效 | cdr 值设置错误 | cdr 取值 0~1（0.3 = 30%减CD），上限 75% |
| 元素反应未触发 | 键名不匹配 | 确保两个元素名称与 reactions 表键一致 |
| 伤害为 0 | 目标有 immune 反制 | 检查 CounterSystem 的 condition |

---

## §15 设计原则（来自 Anti-Gravity Combat System）

以下平衡原则源自 skills-for-antigravity 仓库：

1. **无单一技能主导** — 每个技能都有明确的优势和局限
2. **协同奖励技巧** — 组合使用比单一技能强，但需要操作精度
3. **攻防对等** — 每种进攻手段都有防御反制
4. **资源管理产生策略** — 能量有限，选择使用时机是核心决策
5. **克制关系形成生态** — 元素/能力之间的三角克制保持多样性
6. **升级路线提供深度** — 技能树让玩家定制专属玩法
7. **连招奖励执行力** — 正确的技能序列获得额外收益

