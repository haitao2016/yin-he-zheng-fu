---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/TradeRouteSystem.lua -- 贸易路线系统
-- V3.2 P1-3
-- 玩家可派遣舰队在不同星系航线上进行贸易，获取资源与稀有奖励
-- ============================================================================

local TradeRouteSystem = {}

-- ============================================================================
-- 航线配置
-- ============================================================================

TradeRouteSystem.ROUTES = {
    {
        id = "COASTAL_RUN",
        name = "沿岸航线",
        desc = "短途低风险，适合新手",
        travelTime = 30,          -- 秒
        riskLevel = 1,
        minFleetPower = 100,
        baseRewards = { metal = 200, esource = 50 },
        rareChance = 0.05,         -- 5% 获得稀有资源
        rareReward = { purpleCrystal = 1 },
        unlockWave = 0,
    },
    {
        id = "MERCHANT_LANE",
        name = "商人航道",
        desc = "中等距离，常规贸易路线",
        travelTime = 90,
        riskLevel = 2,
        minFleetPower = 300,
        baseRewards = { metal = 500, esource = 200, nuclear = 30 },
        rareChance = 0.15,
        rareReward = { blueCrystal = 3, purpleCrystal = 1 },
        unlockWave = 10,
    },
    {
        id = "DEEP_SPACE",
        name = "深空贸易线",
        desc = "危险但收益丰厚，适合有经验的指挥官",
        travelTime = 180,
        riskLevel = 4,
        minFleetPower = 800,
        baseRewards = { metal = 1500, esource = 600, nuclear = 150 },
        rareChance = 0.35,
        rareReward = { blueCrystal = 10, purpleCrystal = 4, rainbowCrystal = 1 },
        unlockWave = 30,
    },
    {
        id = "PIRATE_BORDER",
        name = "海盗边境线",
        desc = "高风险高回报，可能触发战斗",
        travelTime = 240,
        riskLevel = 5,
        minFleetPower = 1500,
        baseRewards = { metal = 3000, esource = 1200, nuclear = 400 },
        rareChance = 0.55,
        rareReward = { purpleCrystal = 10, rainbowCrystal = 3 },
        unlockWave = 50,
        encounterChance = 0.4,   -- 40% 战斗遭遇
    },
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local TradeState = {
    activeRoute = nil,           -- 当前正在航行的航线 id
    startTime = 0,               -- 出发时间戳
    fleetOnMission = {},         -- 派遣的舰队配置
    completedCount = 0,          -- 成功完成贸易次数
    history = {},                -- 历史记录（最近 20 次）
}

-- ============================================================================
-- 航线查询
-- ============================================================================

function TradeRouteSystem.getAllRoutes()
    local currentWave = playerState and playerState.currentWave or 0
    local result = {}
    for _, route in ipairs(TradeRouteSystem.ROUTES) do
        table.insert(result, {
            id = route.id,
            name = route.name,
            desc = route.desc,
            travelTime = route.travelTime,
            riskLevel = route.riskLevel,
            minFleetPower = route.minFleetPower,
            baseRewards = route.baseRewards,
            rareChance = route.rareChance,
            rareReward = route.rareReward,
            unlocked = currentWave >= route.unlockWave,
            unlockWave = route.unlockWave,
        })
    end
    return result
end

function TradeRouteSystem.getRoute(routeId)
    for _, route in ipairs(TradeRouteSystem.ROUTES) do
        if route.id == routeId then
            return route
        end
    end
    return nil
end

-- ============================================================================
-- 航线派遣
-- ============================================================================

function TradeRouteSystem.isBusy()
    return TradeState.activeRoute ~= nil
end

function TradeRouteSystem.getActiveMission()
    if not TradeState.activeRoute then return nil end
    local route = TradeRouteSystem.getRoute(TradeState.activeRoute)
    if not route then return nil end
    local now = os.time()
    local elapsed = now - TradeState.startTime
    local remaining = math.max(0, route.travelTime - elapsed)
    return {
        routeId = TradeState.activeRoute,
        routeName = route.name,
        totalTime = route.travelTime,
        elapsed = elapsed,
        remaining = remaining,
        progress = math.min(1.0, elapsed / route.travelTime),
        riskLevel = route.riskLevel,
        encounterChance = route.encounterChance or 0,
    }
end

function TradeRouteSystem.sendFleet(routeId, power, fleet)
    if TradeRouteSystem.isBusy() then
        return false, "舰队正在执行任务中"
    end

    local route = TradeRouteSystem.getRoute(routeId)
    if not route then
        return false, "航线不存在"
    end

    local currentWave = playerState and playerState.currentWave or 0
    if currentWave < route.unlockWave then
        return false, "需要通关 " .. route.unlockWave .. " 波次才能解锁此航线"
    end

    if (power or 0) < route.minFleetPower then
        return false, "舰队战力不足（需要 " .. route.minFleetPower .. "）"
    end

    TradeState.activeRoute = routeId
    TradeState.startTime = os.time()
    TradeState.fleetOnMission = fleet or { power = power }
    TradeRouteSystem.saveState()
    return true, "舰队已出发：" .. route.name
end

-- ============================================================================
-- 结算
-- ============================================================================

local function rollRareRewards(route, powerFactor)
    if math.random() > (route.rareChance or 0) * (1 + (powerFactor - 1) * 0.3) then
        return {}
    end
    local rewards = {}
    for res, amount in pairs(route.rareReward) do
        rewards[res] = math.max(1, math.floor(amount * powerFactor))
    end
    return rewards
end

function TradeRouteSystem.completeMission()
    if not TradeState.activeRoute then return false, "无进行中的任务" end

    local route = TradeRouteSystem.getRoute(TradeState.activeRoute)
    if not route then
        TradeState.activeRoute = nil
        return false, "航线数据损坏"
    end

    -- 战力加成系数（超出部分提升奖励上限）
    local power = TradeState.fleetOnMission and TradeState.fleetOnMission.power or route.minFleetPower
    local powerFactor = math.min(2.0, 1.0 + (power - route.minFleetPower) / (route.minFleetPower * 2))

    -- 基础奖励
    local rewards = {}
    for res, amount in pairs(route.baseRewards) do
        rewards[res] = math.floor(amount * powerFactor)
    end

    -- 稀有资源
    local rareRewards = rollRareRewards(route, powerFactor)
    for res, amount in pairs(rareRewards) do
        rewards[res] = amount
    end

    -- 可能遭遇海盗战斗
    local encountered = false
    if route.encounterChance and math.random() < route.encounterChance then
        encountered = true
    end

    -- 风险惩罚：高风险航线有一定概率损失部分资源
    local riskLoss = 0
    if route.riskLevel >= 4 and math.random() < 0.2 then
        riskLoss = math.random(10, 30)
        for res, _ in pairs(rewards) do
            rewards[res] = math.floor(rewards[res] * (100 - riskLoss) / 100)
        end
    end

    -- 记录历史
    table.insert(TradeState.history, 1, {
        routeId = route.id,
        routeName = route.name,
        completedAt = os.time(),
        rewards = rewards,
        encountered = encountered,
        riskLoss = riskLoss,
    })
    while #TradeState.history > 20 do
        table.remove(TradeState.history)
    end

    TradeState.completedCount = TradeState.completedCount + 1
    TradeState.activeRoute = nil
    TradeState.startTime = 0
    TradeState.fleetOnMission = {}
    TradeRouteSystem.saveState()

    return true, {
        rewards = rewards,
        rareRewards = rareRewards,
        encountered = encountered,
        riskLoss = riskLoss,
        powerFactor = powerFactor,
    }
end

-- 强制取消当前任务（无奖励）
function TradeRouteSystem.cancelMission()
    if not TradeState.activeRoute then
        return false, "无进行中的任务"
    end
    TradeState.activeRoute = nil
    TradeState.startTime = 0
    TradeState.fleetOnMission = {}
    TradeRouteSystem.saveState()
    return true, "舰队已召回"
end

-- ============================================================================
-- 历史记录与统计
-- ============================================================================

function TradeRouteSystem.getHistory()
    return TradeState.history or {}
end

function TradeRouteSystem.getStats()
    local total = TradeState.completedCount or 0
    local totalReward = {}
    for _, entry in ipairs(TradeState.history or {}) do
        for res, amount in pairs(entry.rewards or {}) do
            totalReward[res] = (totalReward[res] or 0) + amount
        end
    end
    return {
        completedCount = total,
        totalReward = totalReward,
        isBusy = TradeRouteSystem.isBusy(),
        activeMission = TradeRouteSystem.getActiveMission(),
    }
end

-- ============================================================================
-- 每帧更新（用于检测任务完成 & 自动结算）
-- ============================================================================

function TradeRouteSystem.update()
    if not TradeState.activeRoute then return nil end
    local mission = TradeRouteSystem.getActiveMission()
    if mission and mission.remaining <= 0 then
        local ok, result = TradeRouteSystem.completeMission()
        return {
            completed = true,
            ok = ok,
            result = result,
        }
    end
    return {
        completed = false,
        mission = mission,
    }
end

-- ============================================================================
-- 存档
-- ============================================================================

function TradeRouteSystem.saveState()
    if playerState then
        playerState.tradeRouteState = {
            activeRoute = TradeState.activeRoute,
            startTime = TradeState.startTime,
            fleetOnMission = TradeState.fleetOnMission,
            completedCount = TradeState.completedCount,
            history = TradeState.history,
        }
    end
end

function TradeRouteSystem.loadState(data)
    if data then
        TradeState.activeRoute = data.activeRoute
        TradeState.startTime = data.startTime or 0
        TradeState.fleetOnMission = data.fleetOnMission or {}
        TradeState.completedCount = data.completedCount or 0
        TradeState.history = data.history or {}
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return TradeRouteSystem
