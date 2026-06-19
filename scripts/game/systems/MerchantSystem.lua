--[[
MerchantSystem.lua - 商人系统
V2.7 P1-7
随机出现的商人出售稀有物品
]]

local MerchantSystem = {}

-- 商人类型
MerchantSystem.MERCHANT_TYPES = {
    {
        id = "WEAPONS_DEALER",
        name = "军火商",
        icon = "⚔️",
        color = { 200, 80, 80 },
        items = {
            { id = "WEAPON_UPGRADE", name = "武器升级模块", cost = 100, desc = "所有舰船攻击 +10%", rare = "blueCrystal" },
            { id = "DESTROYER_SPEC", name = "驱逐舰强化剂", cost = 50, desc = "驱逐舰攻击 +15%", rare = "blueCrystal" },
            { id = "BOSS_KEY", name = "Boss 钥匙", cost = 300, desc = "召唤一个 Boss", rare = "purpleCrystal" },
        },
    },
    {
        id = "TECH_DEALER",
        name = "科技贩子",
        icon = "🔬",
        color = { 80, 80, 200 },
        items = {
            { id = "SKILL_RESET", name = "技能重置券", cost = 80, desc = "重置所有技能点", rare = "blueCrystal" },
            { id = "RESEARCH_BOOST", name = "科研加速卡", cost = 120, desc = "下一次研究时间减半", rare = "blueCrystal" },
            { id = "TIER5_HINT", name = "T5 科技线索", cost = 500, desc = "随机解锁一个 T5 科技", rare = "purpleCrystal" },
        },
    },
    {
        id = "RESOURCE_DEALER",
        name = "资源商人",
        icon = "💎",
        color = { 200, 150, 50 },
        items = {
            { id = "METAL_BUNDLE", name = "金属束", cost = 10, desc = "获得 1000 金属", rare = "blueCrystal" },
            { id = "BLUE_BUNDLE", name = "蓝晶束", cost = 50, desc = "获得 50 蓝晶石", rare = "blueCrystal" },
            { id = "PURPLE_BUNDLE", name = "紫晶束", cost = 200, desc = "获得 20 紫晶石", rare = "purpleCrystal" },
        },
    },
}

-- 商人出现概率
MerchantSystem.APPEAR_CHANCE = 0.10  -- 10% 概率每波出现

-- 检查商人是否出现
---@param playerState table
---@return boolean
function MerchantSystem.checkAppear(playerState)
    if playerState.merchantActive then return true end
    if math.random() < MerchantSystem.APPEAR_CHANCE then
        MerchantSystem.spawnMerchant(playerState)
        return true
    end
    return false
end

-- 生成商人
---@param playerState table
function MerchantSystem.spawnMerchant(playerState)
    local merchantType = MerchantSystem.MERCHANT_TYPES[math.random(#MerchantSystem.MERCHANT_TYPES)]
    
    playerState.merchantActive = true
    playerState.merchantType = merchantType.id
    playerState.merchantName = merchantType.name
    playerState.merchantIcon = merchantType.icon
    playerState.merchantColor = merchantType.color
    playerState.merchantItems = merchantType.items
    playerState.merchantAppearTime = os.time()
    
    -- 商人持续时间（3 分钟）
    playerState.merchantExpireTime = os.time() + 180
end

-- 获取当前商人
---@param playerState table
---@return table|nil
function MerchantSystem.getCurrentMerchant(playerState)
    if not playerState.merchantActive then return nil end
    
    -- 检查是否过期
    if os.time() > (playerState.merchantExpireTime or 0) then
        MerchantSystem.closeMerchant(playerState)
        return nil
    end
    
    local merchantType = nil
    for _, mt in ipairs(MerchantSystem.MERCHANT_TYPES) do
        if mt.id == playerState.merchantType then
            merchantType = mt
            break
        end
    end
    
    return {
        type = merchantType,
        items = playerState.merchantItems,
        remainingTime = (playerState.merchantExpireTime or 0) - os.time(),
    }
end

-- 购买商品
---@param playerState table
---@param itemId string
---@param rm table
---@param notifyFn function
---@return boolean, string
function MerchantSystem.purchase(playerState, itemId, rm, notifyFn)
    local merchant = MerchantSystem.getCurrentMerchant(playerState)
    if not merchant then return false, "商人已离开" end
    
    local item = nil
    for _, it in ipairs(merchant.items) do
        if it.id == itemId then item = it; break end
    end
    if not item then return false, "商品不存在" end
    
    -- 检查资源
    local currency = item.rare or "blueCrystal"
    if currency == "blueCrystal" or currency == "purpleCrystal" or currency == "rainbowCrystal" then
        if not (rm.rareResources and (rm.rareResources[currency] or 0) >= item.cost) then
            return false, "资源不足"
        end
        rm:spendRare(currency, item.cost)
    else
        if not rm:canAfford(currency, item.cost) then
            return false, "资源不足"
        end
        rm:spendResources({ [currency] = item.cost })
    end
    
    -- 应用效果
    MerchantSystem.applyItemEffect(itemId, playerState, rm)
    
    -- 移除已购买的商品
    for i, it in ipairs(merchant.items) do
        if it.id == itemId then
            table.remove(merchant.items, i)
            break
        end
    end
    
    if notifyFn then
        notifyFn("购买成功: " .. item.name, "success")
    end
    
    return true, "购买成功"
end

-- 应用商品效果
---@param itemId string
---@param playerState table
---@param rm table
function MerchantSystem.applyItemEffect(itemId, playerState, rm)
    if itemId == "WEAPON_UPGRADE" then
        playerState.globalDmgBonus = (playerState.globalDmgBonus or 0) + 0.10
    elseif itemId == "DESTROYER_SPEC" then
        playerState.destroyerDmgBonus = (playerState.destroyerDmgBonus or 0) + 0.15
    elseif itemId == "SKILL_RESET" then
        playerState.skillPoints = playerState.maxSkillPoints or 6
        for _, ship in ipairs(playerState.fleet or {}) do
            ship.skillLevel = 1
        end
    elseif itemId == "RESEARCH_BOOST" then
        playerState.researchBoostActive = true
    elseif itemId == "METAL_BUNDLE" then
        rm:addResource("metal", 1000)
    elseif itemId == "BLUE_BUNDLE" then
        rm:addRare("BLUE_CRYSTAL", 50)
    elseif itemId == "PURPLE_BUNDLE" then
        rm:addRare("PURPLE_CRYSTAL", 20)
    end
end

-- 关闭商人
---@param playerState table
function MerchantSystem.closeMerchant(playerState)
    playerState.merchantActive = false
    playerState.merchantType = nil
    playerState.merchantName = nil
    playerState.merchantItems = nil
end

return MerchantSystem