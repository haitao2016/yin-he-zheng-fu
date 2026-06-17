--[[
MarketSystem.lua - 动态市场系统
V2.7 P1-4
资源价格随供需波动，可进行交易
]]

local MarketSystem = {}

-- 市场配置
MarketSystem.MARKET_CONFIG = {
    updateInterval = 60,     -- 价格更新间隔（秒）
    volatility = 0.15,       -- 价格波动幅度
    basePrice = {
        metal = 1,           -- 基础价格
        esource = 2,
        nuclear = 5,
        blueCrystal = 50,
        purpleCrystal = 200,
    },
    priceRange = {
        min = 0.5,           -- 最低为基础价的 50%
        max = 2.0,           -- 最高为基础价的 200%
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

-- 初始化市场
function MarketSystem.init(playerState)
    playerState.marketPrices = playerState.marketPrices or MarketSystem.getInitialPrices()
    playerState.marketLastUpdate = playerState.marketLastUpdate or os.time()
end

-- 获取初始价格
function MarketSystem.getInitialPrices()
    local prices = {}
    for res, base in pairs(MarketSystem.MARKET_CONFIG.basePrice) do
        prices[res] = base
    end
    return prices
end

-- 更新市场价格
function MarketSystem.updateMarket(playerState)
    local now = os.time()
    if playerState.marketLastUpdate and (now - playerState.marketLastUpdate) < MarketSystem.MARKET_CONFIG.updateInterval then
        return
    end
    
    playerState.marketLastUpdate = now
    
    -- 更新每个资源的价格
    for res, base in pairs(MarketSystem.MARKET_CONFIG.basePrice) do
        local current = playerState.marketPrices[res] or base
        local volatility = MarketSystem.MARKET_CONFIG.volatility
        
        -- 随机波动
        local change = 1 + (math.random() - 0.5) * 2 * volatility
        local newPrice = current * change
        
        -- 限制范围
        local minPrice = base * MarketSystem.MARKET_CONFIG.priceRange.min
        local maxPrice = base * MarketSystem.MARKET_CONFIG.priceRange.max
        newPrice = math.max(minPrice, math.min(maxPrice, newPrice))
        
        playerState.marketPrices[res] = math.floor(newPrice * 100) / 100
    end
end

-- 购买资源
function MarketSystem.buy(playerState, resource, amount, rm)
    local price = playerState.marketPrices[resource]
    if not price then return false, "资源不存在" end
    
    local totalCost = math.floor(price * amount)
    
    -- 检查资源是否足够（用另一种资源支付，这里用 metal 作为通用货币）
    local currency = "metal"
    if not rm:canAfford(currency, totalCost) then
        return false, "货币不足，需要 " .. totalCost .. " 金属"
    end
    
    -- 扣除货币
    rm:spendResources({ [currency] = totalCost })
    
    -- 添加资源
    if resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal" then
        rm:addRare(resource, amount)
    else
        rm:addResource(resource, amount)
    end
    
    -- 记录交易
    playerState.marketTransactions = playerState.marketTransactions or {}
    table.insert(playerState.marketTransactions, {
        type = "buy",
        resource = resource,
        amount = amount,
        price = price,
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
    if resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal" then
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
    if resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal" then
        rm:spendRare(resource, amount)
    else
        rm:spendResources({ [resource] = amount })
    end
    
    -- 添加金属
    rm:addResource("metal", sellPrice)
    
    -- 记录交易
    playerState.marketTransactions = playerState.marketTransactions or {}
    table.insert(playerState.marketTransactions, {
        type = "sell",
        resource = resource,
        amount = amount,
        price = price,
        time = os.time(),
    })
    
    return true, "出售成功！出售 " .. amount .. " " .. (MarketSystem.RESOURCE_NAMES[resource] or resource) .. "，获得 " .. sellPrice .. " 金属"
end

-- 获取市场信息
function MarketSystem.getMarketInfo(playerState)
    return {
        prices = playerState.marketPrices,
        lastUpdate = playerState.marketLastUpdate,
        nextUpdateIn = MarketSystem.MARKET_CONFIG.updateInterval - ((os.time() - (playerState.marketLastUpdate or os.time())) % MarketSystem.MARKET_CONFIG.updateInterval),
    }
end

return MarketSystem