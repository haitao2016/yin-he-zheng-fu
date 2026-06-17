--[[
FlagshipSystem.lua - 旗舰系统
V2.7 P1-5
选择一艘舰船作为旗舰，获得额外加成
]]

local FlagshipSystem = {}

-- 旗舰加成定义
FlagshipSystem.FLAGSHIP_BONUS = {
    -- 基础加成（所有旗舰）
    base = {
        healthMult = 1.20,    -- 生命 +20%
        dmgMult = 1.15,       -- 攻击 +15%
        leadership = true,    -- 鼓舞友军 +10%
    },
    
    -- 舰种额外加成
    DESTROYER = { speedMult = 1.25, aoeDmgMult = 1.20 },
    BATTLECRUISER = { armorPen = 0.20, aoeRadius = 1.30 },
    CARRIER = { spawnRateMult = 1.50, fighterCount = 2 },
    STEALTH = { stealthDmgMult = 1.50, evasionMult = 1.30 },
    SUPPORT = { healMult = 1.40, buffRadiusMult = 1.50 },
    DREADNOUGHT = { healthMult = 1.40, dmgMult = 1.25 },
}

-- 设置旗舰
function FlagshipSystem.setFlagship(ship, playerState)
    playerState.flagshipId = ship.id
    playerState.flagshipType = ship.stype
    playerState.flagshipBonus = FlagshipSystem.calculateBonus(ship.stype)
    
    -- 标记舰船为旗舰
    ship.isFlagship = true
    
    -- 应用旗舰加成
    FlagshipSystem.applyBonus(ship)
    
    return true, "旗舰设置成功: " .. ship.name
end

-- 清除旗舰
function FlagshipSystem.clearFlagship(playerState, fleet)
    -- 清除旧旗舰标记
    if playerState.flagshipId and fleet then
        for _, s in ipairs(fleet) do
            if s.id == playerState.flagshipId then
                s.isFlagship = nil
                break
            end
        end
    end
    
    playerState.flagshipId = nil
    playerState.flagshipType = nil
    playerState.flagshipBonus = nil
end

-- 计算旗舰加成
function FlagshipSystem.calculateBonus(shipType)
    local bonus = {}
    
    -- 复制基础加成
    for k, v in pairs(FlagshipSystem.FLAGSHIP_BONUS.base) do
        bonus[k] = v
    end
    
    -- 添加舰种加成
    local typeBonus = FlagshipSystem.FLAGSHIP_BONUS[shipType]
    if typeBonus then
        for k, v in pairs(typeBonus) do
            bonus[k] = v
        end
    end
    
    return bonus
end

-- 应用旗舰加成
function FlagshipSystem.applyBonus(ship)
    local playerState = UICommon and UICommon.playerState
    if not playerState or not playerState.flagshipBonus then return end
    
    local bonus = playerState.flagshipBonus
    
    if bonus.healthMult then
        ship.maxHealth = ship.maxHealth * bonus.healthMult
        ship.health = math.min(ship.health, ship.maxHealth)
    end
    if bonus.dmgMult then
        ship.dmg = ship.dmg * bonus.dmgMult
    end
    if bonus.speedMult then
        ship.speed = ship.speed * bonus.speedMult
    end
end

-- 获取当前旗舰
function FlagshipSystem.getFlagship(playerState, fleet)
    if not playerState.flagshipId then return nil end
    
    for _, ship in ipairs(fleet or {}) do
        if ship.id == playerState.flagshipId then
            return ship
        end
    end
    
    -- 旗舰不在舰队中，清除
    FlagshipSystem.clearFlagship(playerState, fleet)
    return nil
end

-- 旗舰鼓舞效果（应用于友军）
function FlagshipSystem.applyLeadership(playerState, ally)
    if not playerState.flagshipBonus or not playerState.flagshipBonus.leadership then
        return
    end
    
    ally.leadershipBonus = (ally.leadershipBonus or 0) + 0.10
end

return FlagshipSystem
