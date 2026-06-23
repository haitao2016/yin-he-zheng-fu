---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
ShipStarSystem.lua - 舰船升星系统
V2.7 P2-4
消耗重复舰船提升星级
]]

local ShipStarSystem = {}

-- 星级定义（最高5星）
ShipStarSystem.STAR_LEVELS = {
    { stars = 1, name = "★", bonus = { health = 1.0, dmg = 1.0 } },
    { stars = 2, name = "★★", bonus = { health = 1.1, dmg = 1.05 }, fuseCost = 1 },
    { stars = 3, name = "★★★", bonus = { health = 1.2, dmg = 1.1 }, fuseCost = 2 },
    { stars = 4, name = "★★★★", bonus = { health = 1.35, dmg = 1.2 }, fuseCost = 3 },
    { stars = 5, name = "★★★★★", bonus = { health = 1.5, dmg = 1.3 }, fuseCost = 5 },
}

-- 获取舰船星级
function ShipStarSystem.getStarLevel(ship)
    return ship.starLevel or 1
end

-- 获取星级名称
function ShipStarSystem.getStarName(ship)
    local level = ShipStarSystem.getStarLevel(ship)
    local starLevel = ShipStarSystem.STAR_LEVELS[level]
    return starLevel and starLevel.name or "★"
end

-- 升星
function ShipStarSystem.upgradeStar(ship, playerState)
    local currentLevel = ShipStarSystem.getStarLevel(ship)
    if currentLevel >= 5 then return false, "已达最高星级" end
    
    local nextLevel = ShipStarSystem.STAR_LEVELS[currentLevel + 1]
    if not nextLevel then return false, "无法升星" end
    
    local fuseCost = nextLevel.fuseCost or 1
    
    -- 检查是否有足够同类舰船用于融合
    local available = 0
    for _, s in ipairs(playerState.fleet or {}) do
        if s.stype == ship.stype and s ~= ship and not s.isFused then
            available = available + 1
        end
    end
    
    if available < fuseCost then
        return false, "需要 " .. fuseCost .. " 艘同类舰船进行融合"
    end
    
    -- 执行融合
    local fused = 0
    for i = #playerState.fleet, 1, -1 do
        local s = playerState.fleet[i]
        if s.stype == ship.stype and s ~= ship and not s.isFused and fused < fuseCost then
            s.isFused = true
            s.health = 0  -- 标记为已融合
            table.remove(playerState.fleet, i)
            fused = fused + 1
        end
    end
    
    -- 升级星级
    ship.starLevel = currentLevel + 1
    ship.starName = nextLevel.name
    
    -- 应用星级加成
    ship.health = ship.health * nextLevel.bonus.health
    ship.maxHealth = ship.maxHealth * nextLevel.bonus.health
    ship.dmg = ship.dmg * nextLevel.bonus.dmg
    
    return true, "升星成功！当前星级: " .. ship.starName
end

-- 获取星级加成描述
function ShipStarSystem.getStarBonusDesc(level)
    local starLevel = ShipStarSystem.STAR_LEVELS[level] or ShipStarSystem.STAR_LEVELS[1]
    return "生命 +" .. math.floor((starLevel.bonus.health - 1) * 100) .. "%, 攻击 +" .. math.floor((starLevel.bonus.dmg - 1) * 100) .. "%"
end

-- 获取升星所需融合数量
function ShipStarSystem.getFuseCost(currentLevel)
    if currentLevel >= 5 then return 0 end
    local nextLevel = ShipStarSystem.STAR_LEVELS[currentLevel + 1]
    return nextLevel and (nextLevel.fuseCost or 1) or 0
end

-- 获取舰船当前星级加成倍率
function ShipStarSystem.getStarBonus(ship)
    local level = ShipStarSystem.getStarLevel(ship)
    local starLevel = ShipStarSystem.STAR_LEVELS[level]
    return starLevel and starLevel.bonus or { health = 1.0, dmg = 1.0 }
end

-- 检查是否可以升星
function ShipStarSystem.canUpgrade(ship, playerState)
    local currentLevel = ShipStarSystem.getStarLevel(ship)
    if currentLevel >= 5 then return false, 0, 0 end
    
    local fuseCost = ShipStarSystem.getFuseCost(currentLevel)
    local available = 0
    for _, s in ipairs(playerState.fleet or {}) do
        if s.stype == ship.stype and s ~= ship and not s.isFused then
            available = available + 1
        end
    end
    
    return available >= fuseCost, fuseCost, available
end

-- 获取所有星级定义（用于UI显示）
function ShipStarSystem.getAllStarLevels()
    local list = {}
    for i, level in ipairs(ShipStarSystem.STAR_LEVELS) do
        list[i] = {
            stars = level.stars,
            name = level.name,
            bonus = level.bonus,
            fuseCost = level.fuseCost or 0,
            desc = ShipStarSystem.getStarBonusDesc(i),
        }
    end
    return list
end

-- 应用星级加成到舰船属性（用于新建舰船时）
function ShipStarSystem.applyStarBonusToShip(ship, level)
    local starLevel = ShipStarSystem.STAR_LEVELS[level] or ShipStarSystem.STAR_LEVELS[1]
    ship.starLevel = level
    ship.starName = starLevel.name
    -- 注意：此函数不修改 health/maxHealth/dmg，仅设置星级标记
    -- 实际加成应在战斗或属性计算时通过 getStarBonus 获取
end

return ShipStarSystem