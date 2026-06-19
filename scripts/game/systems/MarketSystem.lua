--[[
MarketSystem.lua - 动态市场系统（V3.2 P0-4 扩展版）
资源价格随供需波动，支持稀有资源交易、价格趋势、市场事件
]]

local MarketSystem = {}

-- 市场配置
MarketSystem.MARKET_CONFIG = {
    updateInterval = 60,     -- 价格更新间隔（秒）
    volatility = 0.15,       -- 价格波动幅度
    eventChance = 0.1,        -- 每次更新时有 10% 概率触发市场事件
    eventDuration = 120,      -- 事件持续时间（秒）
    maxPriceHistory = 20,     -- 保留最近 20 个采样点
    dailyTradeLimit = 5000,   -- 每日交易限额（以金属计价）
    basePrice = {
        metal = 1,
        esource = 2,
        nuclear = 5,
        blueCrystal = 50,
        purpleCrystal = 200,
        rainbowCrystal = 1000,
    },
    priceRange = {
        min = 0.5,
        max = 2.0,
    },
}

-- 资源名称映射
MarketSystem.RESOURCE_NAMES = {
    metal = "金属",
    esource = "能源晶体",
    nuclear = "核燃料",
    blueCrystal = "蓝晶石",
    purpleCrystal = "紫晶石",
    rainbowCrystal = "彩虹晶",
}

-- 市场事件类型定义
local MARKET_EVENT_TYPES = {
    SHORTAGE = {
        id = "SHORTAGE",
        name = "资源短缺",
        desc = "供应紧张，价格显著上涨",
        priceMult = 1.5,
        affectedResources = { "esource", "nuclear" },
    },
    SURPLUS = {
        id = "SURPLUS",
        name = "供应过剩",
        desc = "市场充斥，价格下跌",
        priceMult = 0.7,
        affectedResources = { "metal", "esource" },
    },
    WAR_DEMAND = {
        id = "WAR_DEMAND",
        name = "战争需求",
        desc = "战略物资价格飙升",
        priceMult = 1.8,
        affectedResources = { "nuclear", "blueCrystal" },
    },
    RARE_DISCOVERY = {
        id = "RARE_DISCOVERY",
        name = "稀有矿脉发现",
        desc = "稀有资源价格短暂下降",
        priceMult = 0.8,
        affectedResources = { "purpleCrystal", "rainbowCrystal" },
    },
}

-- 判断是否为稀有资源
local function isRareResource(resource)
    return resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal"
end

-- 获取今日日期（字符串），用于每日限额追踪
local function todayKey()
    return os.date("%Y-%m-%d", os.time())
end

-- 初始化市场
function MarketSystem.init(playerState)
    playerState.marketPrices = playerState.marketPrices or MarketSystem.getInitialPrices()
    playerState.marketLastUpdate = playerState.marketLastUpdate or os.time()
    playerState.marketPriceHistory = playerState.marketPriceHistory or {}
    playerState.marketEvents = playerState.marketEvents or {}
    playerState.dailyTradeStats = playerState.dailyTradeStats or { date = todayKey(), totalBought = 0, totalSold = 0 }

    -- 确保每个资源至少有基础历史记录
    for res, _ in pairs(MarketSystem.MARKET_CONFIG.basePrice) do
        playerState.marketPriceHistory[res] = playerState.marketPriceHistory[res] or { playerState.marketPrices[res] or MarketSystem.MARKET_CONFIG.basePrice[res] }
    end

    -- 检查是否需要重置每日限额
    if playerState.dailyTradeStats.date ~= todayKey() then
        playerState.dailyTradeStats = { date = todayKey(), totalBought = 0, totalSold = 0 }
    end
end

-- 获取初始价格
function MarketSystem.getInitialPrices()
    local prices = {}
    for res, base in pairs(MarketSystem.MARKET_CONFIG.basePrice) do
        prices[res] = base
    end
    return prices
end

-- 记录价格历史
local function appendPriceHistory(playerState, resource, price)
    local history = playerState.marketPriceHistory[resource] or {}
    table.insert(history, price)
    while #history > MarketSystem.MARKET_CONFIG.maxPriceHistory do
        table.remove(history, 1)
    end
    playerState.marketPriceHistory[resource] = history
end

-- 检查并清理过期事件
local function cleanExpiredEvents(playerState)
    local now = os.time()
    local activeEvents = {}
    for _, evt in ipairs(playerState.marketEvents or {}) do
        if now < evt.expireTime then
            table.insert(activeEvents, evt)
        end
    end
    playerState.marketEvents = activeEvents
end

-- 获取资源当前的事件加成倍率
local function getEventMultiplier(playerState, resource)
    local mult = 1.0
    for _, evt in ipairs(playerState.marketEvents or {}) do
        for _, affected in ipairs(evt.affectedResources or {}) do
            if affected == resource then
                mult = mult * (evt.priceMult or 1.0)
            end
        end
    end
    return mult
end

-- 随机触发市场事件
local function tryTriggerMarketEvent(playerState)
    if math.random() > MarketSystem.MARKET_CONFIG.eventChance then return end

    local eventKeys = {}
    for key, _ in pairs(MARKET_EVENT_TYPES) do table.insert(eventKeys, key) end
    local chosenKey = eventKeys[math.random(1, #eventKeys)]
    local template = MARKET_EVENT_TYPES[chosenKey]

    table.insert(playerState.marketEvents, {
        id = template.id,
        name = template.name,
        desc = template.desc,
        priceMult = template.priceMult,
        affectedResources = template.affectedResources,
        startTime = os.time(),
        expireTime = os.time() + MarketSystem.MARKET_CONFIG.eventDuration,
    })
end

-- 更新市场价格
function MarketSystem.updateMarket(playerState)
    local now = os.time()
    if playerState.marketLastUpdate and (now - playerState.marketLastUpdate) < MarketSystem.MARKET_CONFIG.updateInterval then
        cleanExpiredEvents(playerState)
        return
    end

    playerState.marketLastUpdate = now
    cleanExpiredEvents(playerState)
    tryTriggerMarketEvent(playerState)

    -- 更新每个资源的价格
    for res, base in pairs(MarketSystem.MARKET_CONFIG.basePrice) do
        local current = playerState.marketPrices[res] or base
        local volatility = MarketSystem.MARKET_CONFIG.volatility

        -- 随机波动
        local change = 1 + (math.random() - 0.5) * 2 * volatility
        local newPrice = current * change

        -- 应用事件倍率
        local eventMult = getEventMultiplier(playerState, res)
        newPrice = newPrice * eventMult

        -- 限制范围
        local minPrice = base * MarketSystem.MARKET_CONFIG.priceRange.min
        local maxPrice = base * MarketSystem.MARKET_CONFIG.priceRange.max
        newPrice = math.max(minPrice, math.min(maxPrice, newPrice))

        newPrice = math.floor(newPrice * 100) / 100
        playerState.marketPrices[res] = newPrice
        appendPriceHistory(playerState, res, newPrice)
    end
end

-- 检查每日限额
local function checkDailyLimit(playerState, totalValue)
    local stats = playerState.dailyTradeStats
    if stats.date ~= todayKey() then
        playerState.dailyTradeStats = { date = todayKey(), totalBought = 0, totalSold = 0 }
        return true
    end
    return (stats.totalBought + totalValue) <= MarketSystem.MARKET_CONFIG.dailyTradeLimit
end

-- 购买资源
function MarketSystem.buy(playerState, resource, amount, rm)
    local price = playerState.marketPrices[resource]
    if not price then return false, "资源不存在" end

    local totalCost = math.floor(price * amount)
    if not checkDailyLimit(playerState, totalCost) then
        return false, "今日交易限额不足（限额 " .. MarketSystem.MARKET_CONFIG.dailyTradeLimit .. " 金属）"
    end

    -- 检查资源是否足够（用另一种资源支付，这里用 metal 作为通用货币）
    local currency = "metal"
    if not rm:canAfford(currency, totalCost) then
        return false, "货币不足，需要 " .. totalCost .. " 金属"
    end

    -- 扣除货币
    rm:spendResources({ [currency] = totalCost })

    -- 添加资源
    if isRareResource(resource) then
        rm:addRare(resource, amount)
    else
        rm:addResource(resource, amount)
    end

    -- 更新每日统计
    playerState.dailyTradeStats.totalBought = playerState.dailyTradeStats.totalBought + totalCost

    -- 记录交易
    playerState.marketTransactions = playerState.marketTransactions or {}
    table.insert(playerState.marketTransactions, {
        type = "buy",
        resource = resource,
        amount = amount,
        price = price,
        totalValue = totalCost,
        time = os.time(),
    })

    return true, "购买成功！花费 " .. totalCost .. " 金属，获得 " .. amount .. " " .. (MarketSystem.RESOURCE_NAMES[resource] or resource)
end

-- 出售资源
function MarketSystem.sell(playerState, resource, amount, rm)
    local price = playerState.marketPrices[resource]
    if not price then return false, "资源不存在" end

    -- 检查资源是否足够
    local hasEnough = false
    if isRareResource(resource) then
        hasEnough = rm.rareResources and (rm.rareResources[resource] or 0) >= amount
    else
        hasEnough = rm:canAfford(resource, amount)
    end

    if not hasEnough then
        return false, "资源不足"
    end

    -- 出售价格（略低于购买价）
    local sellPrice = math.floor(price * amount * 0.9)

    -- 扣除资源
    if isRareResource(resource) then
        rm:spendRare(resource, amount)
    else
        rm:spendResources({ [resource] = amount })
    end

    -- 添加金属
    rm:addResource("metal", sellPrice)

    -- 更新每日统计
    playerState.dailyTradeStats.totalSold = playerState.dailyTradeStats.totalSold + sellPrice

    -- 记录交易
    playerState.marketTransactions = playerState.marketTransactions or {}
    table.insert(playerState.marketTransactions, {
        type = "sell",
        resource = resource,
        amount = amount,
        price = price,
        totalValue = sellPrice,
        time = os.time(),
    })

    return true, "出售成功！出售 " .. amount .. " " .. (MarketSystem.RESOURCE_NAMES[resource] or resource) .. "，获得 " .. sellPrice .. " 金属"
end

-- 获取价格趋势
function MarketSystem.getPriceTrend(playerState, resource)
    local history = playerState.marketPriceHistory and playerState.marketPriceHistory[resource]
    if not history or #history == 0 then
        return 0, "stable", {}
    end
    local first = history[1]
    local last = history[#history]
    local change = (last - first) / first
    local trend = "stable"
    if change > 0.05 then trend = "up"
    elseif change < -0.05 then trend = "down"
    end
    return change, trend, history
end

-- 获取市场分析报告
function MarketSystem.getMarketAnalysis(playerState)
    local analysis = {}
    for res, _ in pairs(MarketSystem.MARKET_CONFIG.basePrice) do
        local change, trend, history = MarketSystem.getPriceTrend(playerState, res)
        table.insert(analysis, {
            resource = res,
            name = MarketSystem.RESOURCE_NAMES[res] or res,
            currentPrice = playerState.marketPrices[res] or MarketSystem.MARKET_CONFIG.basePrice[res],
            changePercent = math.floor(change * 100 + 0.5),
            trend = trend,
            isRare = isRareResource(res),
        })
    end
    return {
        resources = analysis,
        events = playerState.marketEvents or {},
        dailyStats = playerState.dailyTradeStats,
        dailyLimit = MarketSystem.MARKET_CONFIG.dailyTradeLimit,
    }
end

-- 获取最近交易历史
function MarketSystem.getTradeHistory(playerState, limit)
    limit = limit or 10
    local txs = playerState.marketTransactions or {}
    local result = {}
    for i = #txs, math.max(1, #txs - limit + 1), -1 do
        local tx = txs[i]
        if tx then
            table.insert(result, {
                type = tx.type,
                resource = tx.resource,
                resourceName = MarketSystem.RESOURCE_NAMES[tx.resource] or tx.resource,
                amount = tx.amount,
                price = tx.price,
                totalValue = tx.totalValue or (tx.price and math.floor(tx.price * tx.amount) or 0),
                time = tx.time,
            })
        end
    end
    return result
end

-- 获取市场信息
function MarketSystem.getMarketInfo(playerState)
    return {
        prices = playerState.marketPrices,
        lastUpdate = playerState.marketLastUpdate,
        nextUpdateIn = MarketSystem.MARKET_CONFIG.updateInterval - ((os.time() - (playerState.marketLastUpdate or os.time())) % MarketSystem.MARKET_CONFIG.updateInterval),
        dailyStats = playerState.dailyTradeStats,
        dailyLimit = MarketSystem.MARKET_CONFIG.dailyTradeLimit,
    }
end

return MarketSystem