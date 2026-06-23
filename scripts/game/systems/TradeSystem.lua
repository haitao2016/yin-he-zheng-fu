---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
TradeSystem.lua - 星际贸易系统
V2.7 P0-5
]]

require "game.GameConstants"

local TradeSystem = {}

-- 初始化贸易系统
function TradeSystem.init(playerState)
    playerState.tradeRoutes = playerState.tradeRoutes or {}
    playerState.tradeCooldowns = playerState.tradeCooldowns or {}
    playerState.tradeRewards = playerState.tradeRewards or {}
end

-- 建立贸易路线
function TradeSystem.establishRoute(fromPlanet, toPlanet, routeDef, playerState)
    -- 检查条件
    if not playerState.tradeRoutes then TradeSystem.init(playerState) end

    local existingRoutes = #playerState.tradeRoutes
    if existingRoutes >= TRADE_ROUTE_REQUIREMENTS.maxRoutes then
        return false, "已达到最大贸易路线数（" .. TRADE_ROUTE_REQUIREMENTS.maxRoutes .. "）"
    end

    -- 检查距离
    local dx = toPlanet.x - fromPlanet.x
    local dy = toPlanet.y - fromPlanet.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < TRADE_ROUTE_REQUIREMENTS.minDistance then
        return false, "星球距离太近（需>" .. TRADE_ROUTE_REQUIREMENTS.minDistance .. "）"
    end

    -- 检查星际交易所
    local hasTradeHub = false
    if fromPlanet.buildings then
        for _, b in ipairs(fromPlanet.buildings) do
            if b.key == "TRADE_HUB" then hasTradeHub = true; break end
        end
    end
    if not hasTradeHub and TRADE_ROUTE_REQUIREMENTS.hasTradeHub then
        return false, "需要星际交易所"
    end

    -- 建立路线
    local routeId = fromPlanet.id .. "_" .. toPlanet.id
    table.insert(playerState.tradeRoutes, {
        id = routeId,
        from = fromPlanet.id,
        to = toPlanet.id,
        resource = routeDef.resource,
        amount = routeDef.amount,
        cooldown = routeDef.cooldown,
        profit = routeDef.profit,
        established = os.time(),
    })

    playerState.tradeCooldowns[routeId] = 0

    return true, "贸易路线建立成功！"
end

-- 更新贸易系统（每帧调用）
function TradeSystem.update(dt, playerState, rm)
    if not playerState.tradeRoutes then return end

    for _, route in ipairs(playerState.tradeRoutes) do
        local routeId = route.id
        playerState.tradeCooldowns[routeId] = (playerState.tradeCooldowns[routeId] or 0) + dt

        -- 检查是否达到产出时间
        if playerState.tradeCooldowns[routeId] >= route.cooldown then
            playerState.tradeCooldowns[routeId] = 0

            -- 计算产出
            local amount = math.floor(route.amount * route.profit)

            -- 发放资源
            if rm and rm.addResource then
                rm:addResource(route.resource, amount)
            end

            -- 记录奖励
            playerState.tradeRewards[routeId] = (playerState.tradeRewards[routeId] or 0) + amount
        end
    end
end

-- 获取贸易路线状态
function TradeSystem.getRouteStatus(routeId, playerState)
    if not playerState.tradeCooldowns then return nil end

    local cooldown = playerState.tradeCooldowns[routeId] or 0
    local route = nil
    for _, r in ipairs(playerState.tradeRoutes) do
        if r.id == routeId then route = r; break end
    end

    if not route then return nil end

    local progress = math.min(1.0, cooldown / route.cooldown)
    local remaining = math.max(0, route.cooldown - cooldown)

    return {
        cooldown = cooldown,
        total = route.cooldown,
        progress = progress,
        remaining = remaining,
        nextReward = math.floor(route.amount * route.profit),
        resource = route.resource,
    }
end

-- 获取所有贸易路线
function TradeSystem.getAllRoutes(playerState)
    return playerState.tradeRoutes or {}
end

-- 取消贸易路线
function TradeSystem.cancelRoute(routeId, playerState)
    if not playerState.tradeRoutes then return false end

    for i, route in ipairs(playerState.tradeRoutes) do
        if route.id == routeId then
            table.remove(playerState.tradeRoutes, i)
            playerState.tradeCooldowns[routeId] = nil
            playerState.tradeRewards[routeId] = nil
            return true
        end
    end

    return false
end

return TradeSystem