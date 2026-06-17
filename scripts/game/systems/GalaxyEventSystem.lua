---@diagnostic disable: assign-type-mismatch, return-type-mismatch
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
        if GS then
            local planets = {}
            for id, planet in pairs(GS.planets or {}) do
                if planet.type ~= "HOME" then
                    table.insert(planets, id)
                end
            end
            if #planets > 0 then
                local targetPlanet = planets[math.random(#planets)]
                GS.planets[targetPlanet].underRaid = true
                GS.planets[targetPlanet].raidEndTime = os.time() + 120
            end
        end

    elseif effect.type == "RARE_NODE" then
        -- 稀有矿物发现
        if GS then
            local planets = {}
            for id, planet in pairs(GS.planets or {}) do
                if planet.type == "RESOURCE_RICH" or planet.type == "MINING" then
                    table.insert(planets, id)
                end
            end
            if #planets > 0 then
                local targetPlanet = planets[math.random(#planets)]
                GS.planets[targetPlanet].rareMineral = true
                GS.planets[targetPlanet].rareMineralEnd = os.time() + (effect.duration or 300)
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
    }
end

-- ============================================================================
-- 导出
-- ============================================================================

return GalaxyEventSystem
