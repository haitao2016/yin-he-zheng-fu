---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
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
        commandRadius = 300,  -- 指挥范围
    },

    -- 舰种额外加成（P1-2: 增强所有舰种）
    DESTROYER = { speedMult = 1.25, aoeDmgMult = 1.20, skillCooldownMult = 0.85 },
    BATTLECRUISER = { armorPen = 0.20, aoeRadius = 1.30, critChanceBonus = 0.10 },
    CARRIER = { spawnRateMult = 1.50, fighterCount = 2, fighterHealthMult = 1.30 },
    STEALTH = { stealthDmgMult = 1.50, evasionMult = 1.30, critChanceBonus = 0.15 },
    SUPPORT = { healMult = 1.40, buffRadiusMult = 1.50, shieldRegenBonus = 0.30 },
    DREADNOUGHT = { healthMult = 1.40, dmgMult = 1.25, armorBonus = 0.20 },
    -- P1-2: 新增舰种
    MEDICAL = { healMult = 1.60, healRadiusMult = 1.50, shieldRegenBonus = 0.50, teamHealthMult = 1.10 },
    ELECTRONIC = { enemyDebuffMult = 1.50, jamRangeMult = 1.60, skillCooldownMult = 0.70, enemyAccuracyDebuff = 0.25 },
    FLAGSHIP = { healthMult = 1.50, dmgMult = 1.30, teamDmgBonus = 0.15, teamHealthBonus = 0.10, commandRadiusMult = 1.50 },
    VOID_LORD = { healthMult = 1.45, dmgMult = 1.35, voidDamageBonus = 0.30, critDamageMult = 1.50 },
    DEVASTATOR = { healthMult = 1.60, dmgMult = 1.40, armorPen = 0.30, aoeRadiusMult = 1.40 },
    RAILGUN = { armorPen = 0.40, rangeBonus = 0.30, critDamageMult = 1.40, fireRateMult = 1.15 },
    ENGINEER = { repairSpeedMult = 1.50, teamHealthBonus = 0.08, resourceBonusMult = 1.20 },
}

-- P1-2: 旗舰技能定义
FlagshipSystem.FLAGSHIP_SKILLS = {
    -- 主动技能：所有旗舰都有一个指挥技能
    RALLYING_CRY = {
        name = "集结号令",
        desc = "立即恢复舰队 20% 最大生命值，提升攻击力 15% 持续 10 秒",
        cooldown = 60,
        duration = 10,
        effect = { healPct = 0.20, dmgMult = 1.15 },
    },
    SHIELD_WALL = {
        name = "护盾墙",
        desc = "为舰队提供 30% 最大生命值的临时护盾，持续 8 秒",
        cooldown = 75,
        duration = 8,
        effect = { shieldPct = 0.30 },
    },
    SHOCKWAVE = {
        name = "震荡波",
        desc = "对所有敌人造成 50% 攻击力伤害，并眩晕 2 秒",
        cooldown = 90,
        duration = 2,
        effect = { aoeDmgMult = 0.50, stunDuration = 2 },
    },
    FOCUS_FIRE = {
        name = "集火指令",
        desc = "标记一个目标，全队对其伤害 +50% 持续 8 秒",
        cooldown = 50,
        duration = 8,
        effect = { focusDmgMult = 1.50 },
    },
    TACTICAL_RETREAT = {
        name = "战术撤退",
        desc = "全队移动速度 +80%，受到伤害 -40%，持续 6 秒",
        cooldown = 100,
        duration = 6,
        effect = { speedMult = 1.80, dmgTakenMult = 0.60 },
    },
}

-- P1-2: 不同舰种的默认旗舰技能
FlagshipSystem.SHIP_TYPE_SKILL = {
    FIGHTER = "RALLYING_CRY",
    CORVETTE = "RALLYING_CRY",
    DESTROYER = "SHOCKWAVE",
    BATTLECRUISER = "FOCUS_FIRE",
    CARRIER = "SHIELD_WALL",
    VOID_LORD = "SHOCKWAVE",
    DEVASTATOR = "FOCUS_FIRE",
    ENGINEER = "RALLYING_CRY",
    STEALTH = "FOCUS_FIRE",
    RAILGUN = "FOCUS_FIRE",
    MEDICAL = "SHIELD_WALL",
    ELECTRONIC = "SHOCKWAVE",
    FLAGSHIP = "TACTICAL_RETREAT",
}

-- 运行时状态
local activeSkillCooldowns = {}

-- 设置旗舰
---@param ship table
---@param playerState table
---@return boolean, string
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
---@param playerState table
---@param fleet table
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
---@param shipType string
---@return table
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
---@param ship table
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
---@param playerState table
---@param fleet table
---@return table|nil
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
---@param playerState table
---@param ally table
function FlagshipSystem.applyLeadership(playerState, ally)
    if not playerState.flagshipBonus or not playerState.flagshipBonus.leadership then
        return
    end

    ally.leadershipBonus = (ally.leadershipBonus or 0) + 0.10
end

-- P1-2: 获取舰船类型对应的技能 ID
---@param shipType string
---@return string
function FlagshipSystem.getSkillForShipType(shipType)
    return FlagshipSystem.SHIP_TYPE_SKILL[shipType] or "RALLYING_CRY"
end

-- P1-2: 使用旗舰技能
---@param playerState table
---@param fleet table
---@param battleState table
---@return boolean, string
function FlagshipSystem.useSkill(playerState, fleet, battleState)
    if not playerState or not playerState.flagshipId then
        return false, "没有旗舰"
    end
    local skillId = FlagshipSystem.getSkillForShipType(playerState.flagshipType or "FIGHTER")
    local skill = FlagshipSystem.FLAGSHIP_SKILLS[skillId]
    if not skill then return false, "未知技能" end
    local cdKey = playerState.flagshipId .. "_" .. skillId
    local remaining = activeSkillCooldowns[cdKey] or 0
    if remaining > 0 then
        return false, "技能冷却中 " .. string.format("%.1fs", remaining)
    end
    activeSkillCooldowns[cdKey] = skill.cooldown
    -- 应用效果
    if battleState and fleet then
        local e = skill.effect
        for _, ship in ipairs(fleet) do
            if e.healPct and ship.maxHealth and ship.health then
                ship.health = math.min(ship.maxHealth, ship.health + ship.maxHealth * e.healPct)
            end
            if e.shieldPct and ship.maxHealth then
                ship.shield = (ship.shield or 0) + ship.maxHealth * e.shieldPct
                ship.shieldDuration = skill.duration
            end
            if e.dmgMult and battleState.shipBuffs then
                battleState.shipBuffs[ship.id] = battleState.shipBuffs[ship.id] or {}
                battleState.shipBuffs[ship.id].dmgMult = e.dmgMult
                battleState.shipBuffs[ship.id].duration = skill.duration
            end
        end
    end
    print("[FlagshipSystem] 使用技能: " .. skill.name)
    return true, skill.name
end

-- P1-2: 每帧更新技能冷却
---@param dt number
function FlagshipSystem.update(dt)
    for key, cd in pairs(activeSkillCooldowns) do
        if cd > 0 then
            activeSkillCooldowns[key] = math.max(0, cd - dt)
        end
    end
end

-- P1-2: 获取技能冷却状态
---@param playerState table
---@return number
function FlagshipSystem.getSkillCooldown(playerState)
    if not playerState or not playerState.flagshipId then return 0 end
    local skillId = FlagshipSystem.getSkillForShipType(playerState.flagshipType or "FIGHTER")
    local cdKey = playerState.flagshipId .. "_" .. skillId
    return activeSkillCooldowns[cdKey] or 0
end

-- P1-2: 序列化/反序列化技能冷却
---@return table
function FlagshipSystem.serialize()
    return { cooldowns = activeSkillCooldowns }
end

---@param data table
function FlagshipSystem.deserialize(data)
    if data and data.cooldowns then
        activeSkillCooldowns = data.cooldowns
    end
end

return FlagshipSystem
