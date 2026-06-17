--[[
ShipSpecializationSystem.lua - 舰船专精系统
V2.7 P1-3
每艘舰船独立的技能树/强化路线
]]

local ShipSpecializationSystem = {}

-- 专精路线定义
ShipSpecializationSystem.SPECIALIZATIONS = {
    -- 驱逐舰专精
    DESTROYER = {
        {
            id = "DESTROYER_OFFENSE",
            name = "火力专精",
            tier = 1,
            cost = { blueCrystal = 10 },
            effect = { dmgMult = 1.15 },
            desc = "攻击力 +15%",
            requires = {},
        },
        {
            id = "DESTROYER_SPEED",
            name = "机动专精",
            tier = 1,
            cost = { blueCrystal = 10 },
            effect = { speedMult = 1.20 },
            desc = "速度 +20%",
            requires = {},
        },
        {
            id = "DESTROYER_ARMOR",
            name = "装甲专精",
            tier = 2,
            cost = { blueCrystal = 25 },
            effect = { healthMult = 1.25 },
            desc = "生命 +25%",
            requires = {"DESTROYER_OFFENSE"},
        },
        {
            id = "DESTROYER_ASSAULT",
            name = "突击专精",
            tier = 3,
            cost = { purpleCrystal = 10 },
            effect = { aoeRadius = 1.5, aoeDmgMult = 1.30 },
            desc = "AOE 范围 +50%，AOE 伤害 +30%",
            requires = {"DESTROYER_OFFENSE", "DESTROYER_ARMOR"},
        },
    },
    
    -- 战列巡洋舰专精
    BATTLECRUISER = {
        {
            id = "BC_HEAVY_ARMOR",
            name = "重甲专精",
            tier = 1,
            cost = { blueCrystal = 15 },
            effect = { healthMult = 1.30 },
            desc = "生命 +30%",
            requires = {},
        },
        {
            id = "BC_NAVAL_GUN",
            name = "舰炮专精",
            tier = 1,
            cost = { blueCrystal = 15 },
            effect = { dmgMult = 1.20 },
            desc = "攻击 +20%",
            requires = {},
        },
        {
            id = "BC_ARMORED_HULL",
            name = "装甲船体",
            tier = 2,
            cost = { blueCrystal = 30 },
            effect = { shieldMult = 1.50 },
            desc = "护盾 +50%",
            requires = {"BC_HEAVY_ARMOR"},
        },
        {
            id = "BC_DREADNOUGHT",
            name = "战列专精",
            tier = 3,
            cost = { purpleCrystal = 15 },
            effect = { healthMult = 1.50, dmgMult = 1.30 },
            desc = "生命 +50%，攻击 +30%",
            requires = {"BC_HEAVY_ARMOR", "BC_NAVAL_GUN"},
        },
    },
    
    -- 隐形舰专精
    STEALTH = {
        {
            id = "STEALTH_CLOAK",
            name = "隐形强化",
            tier = 1,
            cost = { blueCrystal = 12 },
            effect = { stealthDurationMult = 1.50 },
            desc = "隐形持续时间 +50%",
            requires = {},
        },
        {
            id = "STEALTH_DAMAGE",
            name = "隐形攻击",
            tier = 1,
            cost = { blueCrystal = 12 },
            effect = { stealthDmgBonus = 1.30 },
            desc = "隐形后第一击伤害 +30%",
            requires = {},
        },
        {
            id = "STEALTH_EVASION",
            name = "闪避专精",
            tier = 2,
            cost = { blueCrystal = 25 },
            effect = { evasionChance = 0.25 },
            desc = "25% 概率闪避攻击",
            requires = {"STEALTH_CLOAK"},
        },
        {
            id = "STEALTH_ASSASSIN",
            name = "刺客专精",
            tier = 3,
            cost = { purpleCrystal = 12 },
            effect = { stealthDmgBonus = 2.0, critChance = 0.20 },
            desc = "隐形攻击 +100%，20% 暴击率",
            requires = {"STEALTH_CLOAK", "STEALTH_DAMAGE"},
        },
    },
    
    -- 支援舰专精
    SUPPORT = {
        {
            id = "SUPPORT_HEAL",
            name = "治疗强化",
            tier = 1,
            cost = { blueCrystal = 12 },
            effect = { healAmountMult = 1.30 },
            desc = "治疗量 +30%",
            requires = {},
        },
        {
            id = "SUPPORT_RANGE",
            name = "范围强化",
            tier = 1,
            cost = { blueCrystal = 12 },
            effect = { healRadiusMult = 1.50 },
            desc = "治疗范围 +50%",
            requires = {},
        },
        {
            id = "SUPPORT_SHIELD",
            name = "护盾支援",
            tier = 2,
            cost = { blueCrystal = 25 },
            effect = { shieldHeal = true },
            desc = "治疗同时恢复护盾",
            requires = {"SUPPORT_HEAL"},
        },
        {
            id = "SUPPORT_BUFF",
            name = "增益专精",
            tier = 3,
            cost = { purpleCrystal = 12 },
            effect = { buffDmgMult = 1.25, buffSpeedMult = 1.20 },
            desc = "增益效果: 友军攻击 +25%，速度 +20%",
            requires = {"SUPPORT_HEAL", "SUPPORT_RANGE"},
        },
    },
}

-- 获取舰船专精列表
function ShipSpecializationSystem.getSpecializations(shipType)
    return ShipSpecializationSystem.SPECIALIZATIONS[shipType] or {}
end

-- 获取舰船已解锁的专精
function ShipSpecializationSystem.getUnlockedSpec(ship)
    return ship.specUnlocked or {}
end

-- 检查是否可以解锁专精（不消耗资源）
function ShipSpecializationSystem.canUnlockSpec(ship, specId)
    local specs = ShipSpecializationSystem.SPECIALIZATIONS[ship.stype]
    if not specs then return false end
    
    local spec = nil
    for _, s in ipairs(specs) do
        if s.id == specId then spec = s; break end
    end
    if not spec then return false end
    
    -- 检查是否已解锁
    if ship.specUnlocked and ship.specUnlocked[specId] then
        return false
    end
    
    -- 检查前置
    if spec.requires and #spec.requires > 0 then
        for _, req in ipairs(spec.requires) do
            if not (ship.specUnlocked and ship.specUnlocked[req]) then
                return false
            end
        end
    end
    
    -- 检查资源
    local rm = UICommon and UICommon.rm
    if rm and rm.canAffordRare then
        for res, amount in pairs(spec.cost) do
            if not rm:canAfford(res, amount) then
                return false
            end
        end
    end
    
    return true
end

-- 解锁专精
function ShipSpecializationSystem.unlockSpec(ship, specId, playerState)
    local specs = ShipSpecializationSystem.SPECIALIZATIONS[ship.stype]
    if not specs then return false, "舰船类型无专精" end
    
    local spec = nil
    for _, s in ipairs(specs) do
        if s.id == specId then spec = s; break end
    end
    if not spec then return false, "专精不存在" end
    
    -- 检查是否已解锁
    if ship.specUnlocked and ship.specUnlocked[specId] then
        return false, "已解锁此专精"
    end
    
    -- 检查前置
    if spec.requires and #spec.requires > 0 then
        for _, req in ipairs(spec.requires) do
            if not (ship.specUnlocked and ship.specUnlocked[req]) then
                return false, "需要前置专精"
            end
        end
    end
    
    -- 检查资源
    local rm = UICommon and UICommon.rm
    if rm and rm.canAffordRare then
        for res, amount in pairs(spec.cost) do
            if not rm:canAfford(res, amount) then
                return false, "资源不足"
            end
        end
    end
    
    -- 消耗资源
    if rm and rm.spendRare then
        for res, amount in pairs(spec.cost) do
            rm:spendRare(res, amount)
        end
    end
    
    -- 解锁专精
    ship.specUnlocked = ship.specUnlocked or {}
    ship.specUnlocked[specId] = true
    
    -- 应用效果
    ShipSpecializationSystem.applySpecEffects(ship)
    
    return true, "专精解锁成功"
end

-- 应用专精效果到舰船
function ShipSpecializationSystem.applySpecEffects(ship)
    local specs = ShipSpecializationSystem.SPECIALIZATIONS[ship.stype]
    if not specs or not ship.specUnlocked then return end
    
    -- 重置效果
    ship.specDmgMult = 1.0
    ship.specHealthMult = 1.0
    ship.specSpeedMult = 1.0
    ship.specShieldMult = 1.0
    ship.specHealMult = 1.0
    ship.specHealRadius = 1.0
    ship.specAoeRadius = 1.0
    ship.specAoeDmgMult = 1.0
    ship.specEvasion = 0
    ship.specCrit = 0
    ship.specBuffDmg = 1.0
    ship.specBuffSpeed = 1.0
    ship.specStealthMult = 1.0
    ship.specStealthDmg = 1.0
    
    for specId, _ in pairs(ship.specUnlocked) do
        for _, spec in ipairs(specs) do
            if spec.id == specId and spec.effect then
                local eff = spec.effect
                if eff.dmgMult then ship.specDmgMult = ship.specDmgMult * eff.dmgMult end
                if eff.healthMult then ship.specHealthMult = ship.specHealthMult * eff.healthMult end
                if eff.speedMult then ship.specSpeedMult = ship.specSpeedMult * eff.speedMult end
                if eff.shieldMult then ship.specShieldMult = ship.specShieldMult * eff.shieldMult end
                if eff.healAmountMult then ship.specHealMult = ship.specHealMult * eff.healAmountMult end
                if eff.healRadiusMult then ship.specHealRadius = ship.specHealRadius * eff.healRadiusMult end
                if eff.aoeRadius then ship.specAoeRadius = ship.specAoeRadius * eff.aoeRadius end
                if eff.aoeDmgMult then ship.specAoeDmgMult = ship.specAoeDmgMult * eff.aoeDmgMult end
                if eff.evasionChance then ship.specEvasion = (ship.specEvasion or 0) + eff.evasionChance end
                if eff.critChance then ship.specCrit = (ship.specCrit or 0) + eff.critChance end
                if eff.buffDmgMult then ship.specBuffDmg = ship.specBuffDmg * eff.buffDmgMult end
                if eff.buffSpeedMult then ship.specBuffSpeed = ship.specBuffSpeed * eff.buffSpeedMult end
                if eff.stealthDurationMult then ship.specStealthMult = ship.specStealthMult * eff.stealthDurationMult end
                if eff.stealthDmgBonus then ship.specStealthDmg = eff.stealthDmgBonus end
            end
        end
    end
end

return ShipSpecializationSystem
