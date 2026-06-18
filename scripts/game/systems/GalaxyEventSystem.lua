---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/systems/GalaxyEventSystem.lua -- 银河事件系统
-- V2.8 P0-7
-- ============================================================================

local GalaxyEventSystem = {}

-- ============================================================================
-- 银河事件运行时状态
-- ============================================================================

local EventState = {
    activeEvents = {},
    eventHistory = {},
    lastEventCheck = 0,
    eventCooldowns = {},
}

-- 事件效果应用状态
local EventEffects = {
    travelSpeedMult = 1.0,
    tradeBonus = 0.0,
    mineOutputMult = 1.0,
    shieldPenalty = 1.0,
    stealthBonus = 1.0,
    noTax = false,
    researchSpeedMult = 1.0,
    -- 新增效果字段
    enemyWaveBoostMult = 1.0,
    rareDropChance = 0.0,
    bountyBonus = 0.0,
    reputationGain = 0.0,
    temporaryAlly = nil,
    ambushChance = 0.0,
    fleetDefenseBonus = 0.0,
    explorationBonus = nil,
    scavengeBonus = nil,
    resourceBonus = nil,
    creditsBonus = 0.0,
    energyBoost = 1.0,
    explorationRange = 1.0,
    warpInstability = 0.0,
    discoveryChance = 0.0,
    newStargateFound = false,
    hiddenSystemRevealed = false,
    guildBonus = 0.0,
    freeResources = nil,
    voidEnergy = 0.0,
    allResourceMult = 1.0,
    tradeFluctuation = 0.0,
    energyDrain = 1.0,
}

-- 事件冷却时间（秒）
local EVENT_CHECK_INTERVAL = 30
local EVENT_COOLDOWN = 60

-- ============================================================================
-- 事件查询
-- ============================================================================

-- 获取所有事件类型
function GalaxyEventSystem.getEventTypes()
    local events = {}
    for id, event in pairs(GALAXY_EVENTS) do
        table.insert(events, {
            id = id,
            name = event.name,
            desc = event.desc,
            duration = event.duration,
            icon = event.icon,
            effects = event.effects,
        })
    end
    return events
end

-- 获取活跃事件
function GalaxyEventSystem.getActiveEvents()
    return EventState.activeEvents
end

-- 检查事件是否活跃
function GalaxyEventSystem.isEventActive(eventId)
    for _, event in ipairs(EventState.activeEvents) do
        if event.id == eventId then
            return true
        end
    end
    return false
end

-- 获取事件详情
function GalaxyEventSystem.getEvent(eventId)
    return GALAXY_EVENTS[eventId]
end

-- ============================================================================
-- 事件触发
-- ============================================================================

-- 随机检查事件触发
function GalaxyEventSystem.checkRandomEvent()
    local now = os.time()

    -- 检查冷却
    if now - EventState.lastEventCheck < EVENT_CHECK_INTERVAL then
        return nil
    end

    EventState.lastEventCheck = now

    -- 检查每个事件的冷却
    for eventId, cooldownEnd in pairs(EventState.eventCooldowns) do
        if now < cooldownEnd then
            return nil
        end
    end

    -- 检查最大活跃事件数（最多同时 2 个）
    if #EventState.activeEvents >= 2 then
        return nil
    end

    -- 随机触发事件
    local candidates = {}
    for id, event in pairs(GALAXY_EVENTS) do
        if not GalaxyEventSystem.isEventActive(id) then
            table.insert(candidates, { id = id, weight = event.probability })
        end
    end

    if #candidates == 0 then
        return nil
    end

    -- 按概率随机
    local roll = math.random()
    local accumulated = 0

    for _, candidate in ipairs(candidates) do
        accumulated = accumulated + candidate.weight
        if roll <= accumulated then
            -- 触发事件
            local success, result = GalaxyEventSystem.triggerEvent(candidate.id)
            if success then
                return result
            end
            return nil
        end
    end

    return nil
end

-- 手动触发事件（测试用）
function GalaxyEventSystem.triggerEvent(eventId)
    local eventDef = GALAXY_EVENTS[eventId]
    if not eventDef then
        return false, "事件不存在"
    end

    -- 检查是否已激活
    if GalaxyEventSystem.isEventActive(eventId) then
        return false, "事件已在进行中"
    end

    -- 创建事件实例
    local activeEvent = {
        id = eventId,
        startTime = os.time(),
        endTime = eventDef.duration > 0 and (os.time() + eventDef.duration) or nil,
        effects = eventDef.effects,
        processedEffects = {},
    }

    -- 添加到活跃事件
    table.insert(EventState.activeEvents, activeEvent)

    -- 应用事件效果
    GalaxyEventSystem.applyEventEffects(eventDef.effects)

    -- 设置冷却
    EventState.eventCooldowns[eventId] = os.time() + EVENT_COOLDOWN

    -- 记录历史
    table.insert(EventState.eventHistory, {
        eventId = eventId,
        startTime = os.time(),
        endTime = activeEvent.endTime,
    })

    -- 显示通知
    if NotifyPanel then
        NotifyPanel.push({
            type = "EVENT",
            title = "⚠ " .. eventDef.name,
            message = eventDef.desc,
            icon = eventDef.icon,
            duration = 5,
        })
    end

    -- 保存
    GalaxyEventSystem.saveState()

    return true, activeEvent
end

-- ============================================================================
-- 事件效果应用
-- ============================================================================

-- 应用事件效果
function GalaxyEventSystem.applyEventEffects(effects)
    if not effects then return end

    for _, effect in ipairs(effects) do
        GalaxyEventSystem.applyEffect(effect)
    end
end

-- 应用单个效果
function GalaxyEventSystem.applyEffect(effect)
    if not effect then return end

    if effect.type == "TRAVEL_SPEED" then
        EventEffects.travelSpeedMult = EventEffects.travelSpeedMult * effect.value

    elseif effect.type == "TRADE_BONUS" then
        EventEffects.tradeBonus = EventEffects.tradeBonus + effect.value

    elseif effect.type == "MINE_OUTPUT" then
        EventEffects.mineOutputMult = EventEffects.mineOutputMult * effect.value

    elseif effect.type == "SHIELD_PENALTY" then
        EventEffects.shieldPenalty = EventEffects.shieldPenalty * effect.value

    elseif effect.type == "STEALTH_BONUS" then
        EventEffects.stealthBonus = EventEffects.stealthBonus * effect.value

    elseif effect.type == "NO_TAX" then
        EventEffects.noTax = true

    elseif effect.type == "RESEARCH_SPEED" then
        EventEffects.researchSpeedMult = EventEffects.researchSpeedMult * effect.value

    elseif effect.type == "PLANET_RAID" then
        -- 海盗袭击 - 随机星球遭受袭击
        if GS and GS.planets then
            local planets = {}
            for id, planet in pairs(GS.planets) do
                if planet and planet.type ~= "HOME" then
                    table.insert(planets, id)
                end
            end
            if #planets > 0 then
                local targetId = planets[math.random(#planets)]
                local targetPlanet = GS.planets[targetId]
                if targetPlanet then
                    targetPlanet.underRaid = true
                    targetPlanet.raidEndTime = os.time() + 120
                end
            end
        end

    elseif effect.type == "RARE_NODE" then
        -- 稀有矿物发现
        if GS and GS.planets then
            local planets = {}
            for id, planet in pairs(GS.planets) do
                if planet and (planet.type == "RESOURCE_RICH" or planet.type == "MINING") then
                    table.insert(planets, id)
                end
            end
            if #planets > 0 then
                local targetId = planets[math.random(#planets)]
                local targetPlanet = GS.planets[targetId]
                if targetPlanet then
                    targetPlanet.rareMineral = true
                    targetPlanet.rareMineralEnd = os.time() + (effect.duration or 300)
                end
            end
        end

    elseif effect.type == "NEW_PATH" then
        -- 虫洞 - 创建新路径
        if GS and effect.planets then
            -- (虫洞路径创建逻辑)
        end

    elseif effect.type == "RANDOM_TECH" then
        -- 外星接触 - 随机获得科技
        -- (科技赠送逻辑)

    -- ========================================================================
    -- 新增事件效果类型
    -- ========================================================================

    elseif effect.type == "ENEMY_WAVE_BOOST" then
        -- 敌人群攻加成（虚空裂隙等）
        EventEffects.enemyWaveBoostMult = (EventEffects.enemyWaveBoostMult or 1.0) * (effect.mult or 1.0)
        EventEffects.rareDropChance = (EventEffects.rareDropChance or 0) + (effect.value or 0)

    elseif effect.type == "BOUNTY_HUNTER_BONUS" then
        -- 海盗悬赏金加成
        EventEffects.bountyBonus = (EventEffects.bountyBonus or 0) + (effect.value or 0)

    elseif effect.type == "REPUTATION_GAIN" then
        -- 声望获取加成
        EventEffects.reputationGain = (EventEffects.reputationGain or 0) + (effect.value or 0)

    elseif effect.type == "TEMPORARY_ALLY" then
        -- 佣兵临时协助（仅记录状态，战斗时由 FleetManager 处理）
        EventEffects.temporaryAlly = { shipType = effect.shipType, count = effect.count }

    elseif effect.type == "ENEMY_AMBUSH_CHANCE" then
        -- 伏击预警（记录状态，战斗时判定）
        EventEffects.ambushChance = (EventEffects.ambushChance or 0) + (effect.value or 0)

    elseif effect.type == "FLEET_DEFENSE_BONUS" then
        -- 舰队防御加成
        EventEffects.fleetDefenseBonus = (EventEffects.fleetDefenseBonus or 0) + (effect.value or 0)

    elseif effect.type == "EXPLORATION_REWARD" then
        -- 探索奖励（探索类事件触发时发放）
        EventEffects.explorationBonus = effect.bonus or {}

    elseif effect.type == "SCAVENGE_REWARD" then
        -- 打捞奖励（废弃舰队事件）
        EventEffects.scavengeBonus = effect.bonus or {}

    elseif effect.type == "RESOURCE_BONUS" then
        -- 指定资源加成
        if effect.resource then
            EventEffects.resourceBonus = EventEffects.resourceBonus or {}
            EventEffects.resourceBonus[effect.resource] = (EventEffects.resourceBonus[effect.resource] or 1.0) * (effect.value or 1.0)
        else
            -- 全资源加成
            EventEffects.allResourceMult = (EventEffects.allResourceMult or 1.0) * (effect.value or 1.0)
        end

    elseif effect.type == "CREDITS_BONUS" then
        -- 星币奖励
        EventEffects.creditsBonus = (EventEffects.creditsBonus or 0) + (effect.value or 0)

    elseif effect.type == "ENERGY_BOOST" then
        -- 能量加成
        EventEffects.energyBoost = (EventEffects.energyBoost or 1.0) * (effect.value or 1.0)

    elseif effect.type == "EXPLORATION_RANGE" then
        -- 探索范围加成
        EventEffects.explorationRange = (EventEffects.explorationRange or 1.0) * (effect.value or 1.0)

    elseif effect.type == "WARP_INSTABILITY" then
        -- 曲速不稳定
        EventEffects.warpInstability = (EventEffects.warpInstability or 0) + (effect.value or 0)

    elseif effect.type == "DISCOVERY_CHANCE" then
        -- 发现概率加成
        EventEffects.discoveryChance = (EventEffects.discoveryChance or 0) + (effect.value or 0)

    elseif effect.type == "TRADE_PENALTY" then
        -- 贸易惩罚
        EventEffects.tradeBonus = EventEffects.tradeBonus + (effect.value or 0)

    elseif effect.type == "NEW_STARGATE" then
        -- 发现新星门
        EventEffects.newStargateFound = true

    elseif effect.type == "REVEAL_HIDDEN_SYSTEM" then
        -- 揭示隐藏星系
        EventEffects.hiddenSystemRevealed = true

    elseif effect.type == "GUILD_BONUS" then
        -- 公会加成
        EventEffects.guildBonus = (EventEffects.guildBonus or 0) + (effect.value or 0)

    elseif effect.type == "FREE_RESOURCES" then
        -- 免费资源（外交礼物等）
        EventEffects.freeResources = EventEffects.freeResources or {}
        for k, v in pairs(effect.bonus or {}) do
            EventEffects.freeResources[k] = (EventEffects.freeResources[k] or 0) + v
        end

    elseif effect.type == "VOID_ENERGY" then
        -- 虚空能量（传说事件）
        EventEffects.voidEnergy = (EventEffects.voidEnergy or 0) + (effect.value or 0)

    elseif effect.type == "ALL_RESOURCES" then
        -- 全资源加成
        EventEffects.allResourceMult = (EventEffects.allResourceMult or 1.0) * (effect.value or 1.0)

    elseif effect.type == "TRADE_RANDOM_FLUCTUATION" then
        -- 贸易随机波动
        EventEffects.tradeFluctuation = (EventEffects.tradeFluctuation or 0) + (effect.range or 0)

    elseif effect.type == "ENERGY_DRAIN" then
        -- 能量消耗
        EventEffects.energyDrain = (EventEffects.energyDrain or 1.0) * (effect.value or 1.0)
    end
end

-- 移除事件效果
function GalaxyEventSystem.removeEventEffects(effects)
    if not effects then return end

    for _, effect in ipairs(effects) do
        GalaxyEventSystem.removeEffect(effect)
    end
end

-- 移除单个效果
function GalaxyEventSystem.removeEffect(effect)
    if not effect then return end

    if effect.type == "TRAVEL_SPEED" then
        EventEffects.travelSpeedMult = EventEffects.travelSpeedMult / effect.value

    elseif effect.type == "TRADE_BONUS" then
        EventEffects.tradeBonus = EventEffects.tradeBonus - effect.value

    elseif effect.type == "MINE_OUTPUT" then
        EventEffects.mineOutputMult = EventEffects.mineOutputMult / effect.value

    elseif effect.type == "SHIELD_PENALTY" then
        EventEffects.shieldPenalty = EventEffects.shieldPenalty / effect.value

    elseif effect.type == "STEALTH_BONUS" then
        EventEffects.stealthBonus = EventEffects.stealthBonus / effect.value

    elseif effect.type == "NO_TAX" then
        EventEffects.noTax = false

    elseif effect.type == "RESEARCH_SPEED" then
        EventEffects.researchSpeedMult = EventEffects.researchSpeedMult / effect.value

    -- ========================================================================
    -- 新增事件效果类型的移除逻辑
    -- ========================================================================

    elseif effect.type == "ENEMY_WAVE_BOOST" then
        EventEffects.enemyWaveBoostMult = EventEffects.enemyWaveBoostMult / (effect.mult or 1.0)
        EventEffects.rareDropChance = EventEffects.rareDropChance - (effect.value or 0)

    elseif effect.type == "BOUNTY_HUNTER_BONUS" then
        EventEffects.bountyBonus = EventEffects.bountyBonus - (effect.value or 0)

    elseif effect.type == "REPUTATION_GAIN" then
        EventEffects.reputationGain = EventEffects.reputationGain - (effect.value or 0)

    elseif effect.type == "TEMPORARY_ALLY" then
        EventEffects.temporaryAlly = nil

    elseif effect.type == "ENEMY_AMBUSH_CHANCE" then
        EventEffects.ambushChance = EventEffects.ambushChance - (effect.value or 0)

    elseif effect.type == "FLEET_DEFENSE_BONUS" then
        EventEffects.fleetDefenseBonus = EventEffects.fleetDefenseBonus - (effect.value or 0)

    elseif effect.type == "EXPLORATION_REWARD" then
        EventEffects.explorationBonus = nil

    elseif effect.type == "SCAVENGE_REWARD" then
        EventEffects.scavengeBonus = nil

    elseif effect.type == "RESOURCE_BONUS" then
        if effect.resource and EventEffects.resourceBonus then
            EventEffects.resourceBonus[effect.resource] = EventEffects.resourceBonus[effect.resource] / (effect.value or 1.0)
        else
            EventEffects.allResourceMult = EventEffects.allResourceMult / (effect.value or 1.0)
        end

    elseif effect.type == "CREDITS_BONUS" then
        EventEffects.creditsBonus = EventEffects.creditsBonus - (effect.value or 0)

    elseif effect.type == "ENERGY_BOOST" then
        EventEffects.energyBoost = EventEffects.energyBoost / (effect.value or 1.0)

    elseif effect.type == "EXPLORATION_RANGE" then
        EventEffects.explorationRange = EventEffects.explorationRange / (effect.value or 1.0)

    elseif effect.type == "WARP_INSTABILITY" then
        EventEffects.warpInstability = EventEffects.warpInstability - (effect.value or 0)

    elseif effect.type == "DISCOVERY_CHANCE" then
        EventEffects.discoveryChance = EventEffects.discoveryChance - (effect.value or 0)

    elseif effect.type == "TRADE_PENALTY" then
        EventEffects.tradeBonus = EventEffects.tradeBonus - (effect.value or 0)

    elseif effect.type == "NEW_STARGATE" then
        EventEffects.newStargateFound = false

    elseif effect.type == "REVEAL_HIDDEN_SYSTEM" then
        EventEffects.hiddenSystemRevealed = false

    elseif effect.type == "GUILD_BONUS" then
        EventEffects.guildBonus = EventEffects.guildBonus - (effect.value or 0)

    elseif effect.type == "FREE_RESOURCES" then
        EventEffects.freeResources = nil

    elseif effect.type == "VOID_ENERGY" then
        EventEffects.voidEnergy = EventEffects.voidEnergy - (effect.value or 0)

    elseif effect.type == "ALL_RESOURCES" then
        EventEffects.allResourceMult = EventEffects.allResourceMult / (effect.value or 1.0)

    elseif effect.type == "TRADE_RANDOM_FLUCTUATION" then
        EventEffects.tradeFluctuation = EventEffects.tradeFluctuation - (effect.range or 0)

    elseif effect.type == "ENERGY_DRAIN" then
        EventEffects.energyDrain = EventEffects.energyDrain / (effect.value or 1.0)
    end
end

-- ============================================================================
-- 事件更新
-- ============================================================================

-- 更新事件状态
function GalaxyEventSystem.update(dt)
    local now = os.time()
    local toRemove = {}

    for i, event in ipairs(EventState.activeEvents) do
        -- 检查是否到期
        if event.endTime and now >= event.endTime then
            table.insert(toRemove, i)
        end
    end

    -- 移除到期事件
    for i = #toRemove, 1, -1 do
        local event = EventState.activeEvents[toRemove[i]]
        GalaxyEventSystem.endEvent(event)
        table.remove(EventState.activeEvents, toRemove[i])
    end

    -- 随机检查新事件
    GalaxyEventSystem.checkRandomEvent()
end

-- 结束事件
function GalaxyEventSystem.endEvent(event)
    -- 移除效果
    GalaxyEventSystem.removeEventEffects(event.effects)

    -- 显示结束通知
    local eventDef = GALAXY_EVENTS[event.id]
    if eventDef and NotifyPanel then
        NotifyPanel.push({
            type = "EVENT_END",
            title = "事件结束",
            message = eventDef.name .. " 已结束",
            icon = eventDef.icon,
        })
    end

    -- 清除星球特殊状态
    if GS and GS.planets then
        for id, planet in pairs(GS.planets) do
            if planet.underRaid and planet.raidEndTime and os.time() >= planet.raidEndTime then
                planet.underRaid = nil
                planet.raidEndTime = nil
            end
            if planet.rareMineral and planet.rareMineralEnd and os.time() >= planet.rareMineralEnd then
                planet.rareMineral = nil
                planet.rareMineralEnd = nil
            end
        end
    end

    GalaxyEventSystem.saveState()
end

-- ============================================================================
-- 事件效果查询
-- ============================================================================

-- 获取当前所有效果加成
function GalaxyEventSystem.getEffectBonuses()
    return {
        travelSpeedMult = EventEffects.travelSpeedMult,
        tradeBonus = EventEffects.tradeBonus,
        mineOutputMult = EventEffects.mineOutputMult,
        shieldPenalty = EventEffects.shieldPenalty,
        stealthBonus = EventEffects.stealthBonus,
        noTax = EventEffects.noTax,
        researchSpeedMult = EventEffects.researchSpeedMult,
        -- 新增效果字段
        enemyWaveBoostMult = EventEffects.enemyWaveBoostMult,
        rareDropChance = EventEffects.rareDropChance,
        bountyBonus = EventEffects.bountyBonus,
        reputationGain = EventEffects.reputationGain,
        ambushChance = EventEffects.ambushChance,
        fleetDefenseBonus = EventEffects.fleetDefenseBonus,
        creditsBonus = EventEffects.creditsBonus,
        energyBoost = EventEffects.energyBoost,
        explorationRange = EventEffects.explorationRange,
        warpInstability = EventEffects.warpInstability,
        discoveryChance = EventEffects.discoveryChance,
        newStargateFound = EventEffects.newStargateFound,
        hiddenSystemRevealed = EventEffects.hiddenSystemRevealed,
        guildBonus = EventEffects.guildBonus,
        voidEnergy = EventEffects.voidEnergy,
        allResourceMult = EventEffects.allResourceMult,
        tradeFluctuation = EventEffects.tradeFluctuation,
        energyDrain = EventEffects.energyDrain,
        resourceBonus = EventEffects.resourceBonus,
        freeResources = EventEffects.freeResources,
    }
end

-- 获取旅行速度加成
function GalaxyEventSystem.getTravelSpeedBonus()
    return EventEffects.travelSpeedMult
end

-- 获取贸易加成
function GalaxyEventSystem.getTradeBonus()
    return EventEffects.tradeBonus
end

-- 获取采矿加成
function GalaxyEventSystem.getMineOutputBonus()
    return EventEffects.mineOutputMult
end

-- 获取护盾惩罚
function GalaxyEventSystem.getShieldPenalty()
    return EventEffects.shieldPenalty
end

-- 获取隐形加成
function GalaxyEventSystem.getStealthBonus()
    return EventEffects.stealthBonus
end

-- 是否免税
function GalaxyEventSystem.isTaxFree()
    return EventEffects.noTax
end

-- 获取研究速度加成
function GalaxyEventSystem.getResearchSpeedBonus()
    return EventEffects.researchSpeedMult
end

-- ============================================================================
-- 事件奖励（海盗袭击等）
-- ============================================================================

-- 击败海盗奖励
function GalaxyEventSystem.onPirateDefeated(bounty)
    local reward = {
        metal = math.floor(bounty * 0.6),
        credits = math.floor(bounty * 0.4),
    }

    if playerState then
        playerState.metal = (playerState.metal or 0) + reward.metal
        playerState.credits = (playerState.credits or 0) + reward.credits
    end

    if NotifyPanel then
        NotifyPanel.push({
            type = "REWARD",
            title = "悬赏金",
            message = "获得: 金属×" .. reward.metal .. ", 星币×" .. reward.credits,
        })
    end

    return reward
end

-- ============================================================================
-- 存档
-- ============================================================================

function GalaxyEventSystem.saveState()
    if playerState then
        playerState.galaxyEventState = {
            eventHistory = EventState.eventHistory,
            eventCooldowns = EventState.eventCooldowns,
            lastEventCheck = EventState.lastEventCheck,
        }
    end
end

function GalaxyEventSystem.loadState(data)
    if data then
        EventState.eventHistory = data.eventHistory or {}
        EventState.eventCooldowns = data.eventCooldowns or {}
        EventState.lastEventCheck = data.lastEventCheck or 0
    end
end

-- 重置事件状态
function GalaxyEventSystem.reset()
    EventState.activeEvents = {}
    EventState.eventCooldowns = {}

    EventEffects = {
        travelSpeedMult = 1.0,
        tradeBonus = 0.0,
        mineOutputMult = 1.0,
        shieldPenalty = 1.0,
        stealthBonus = 1.0,
        noTax = false,
        researchSpeedMult = 1.0,
        -- 新增效果字段
        enemyWaveBoostMult = 1.0,
        rareDropChance = 0.0,
        bountyBonus = 0.0,
        reputationGain = 0.0,
        temporaryAlly = nil,
        ambushChance = 0.0,
        fleetDefenseBonus = 0.0,
        explorationBonus = nil,
        scavengeBonus = nil,
        resourceBonus = nil,
        creditsBonus = 0.0,
        energyBoost = 1.0,
        explorationRange = 1.0,
        warpInstability = 0.0,
        discoveryChance = 0.0,
        newStargateFound = false,
        hiddenSystemRevealed = false,
        guildBonus = 0.0,
        freeResources = nil,
        voidEnergy = 0.0,
        allResourceMult = 1.0,
        tradeFluctuation = 0.0,
        energyDrain = 1.0,
    }
end

-- ============================================================================
-- 导出
-- ============================================================================

return GalaxyEventSystem
