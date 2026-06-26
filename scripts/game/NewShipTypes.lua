---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/NewShipTypes.lua -- V3.0 新舰种扩展
-- 定义 ENGINEER / STEALTH / RAILGUN 三种新舰类型
-- ============================================================================

local NewShipTypes = {}

-- ============================================================================
-- 新舰种全局表
-- ============================================================================

NEW_SHIP_TYPES = {
    {
        id = "ENGINEER",
        name = "工程维修舰",
        nameEn = "Engineer Repair Ship",
        description = "低攻击力但拥有极高生存能力的支援舰。周期性为友舰修复生命值，是舰队中不可或缺的后勤保障。",
        stats = {
            health     = 800,
            damage     = 40,
            speed      = 60,
            shield     = 400,
            range      = 180,
            buildTime  = 18,
            cost       = { metal = 120, energy = 80, blueCrystal = 5 },
        },
        skills = {
            {
                skillId  = "REPAIR_AURA",
                name     = "范围治疗",
                cooldown = 8,
                duration = 2,
                effect   = { healAmount = 60, healRadius = 220 },
            },
        },
        unlockRequirement = { techId = "ADVANCED_ENGINEERING", coreLevel = 3 },
        formationRole = "后排",
    },

    {
        id = "STEALTH",
        name = "隐形突击舰",
        nameEn = "Stealth Assault Ship",
        description = "高爆发低生存的隐形刺客。周期性进入隐形状态，攻击时解除隐身但造成额外伤害，适合进行精准打击。",
        stats = {
            health     = 350,
            damage     = 280,
            speed      = 110,
            shield     = 120,
            range      = 160,
            buildTime  = 22,
            cost       = { metal = 150, energy = 120, purpleCrystal = 8 },
        },
        skills = {
            {
                skillId  = "PHASE_SHIFT",
                name     = "相位隐形",
                cooldown = 12,
                duration = 5,
                effect   = { stealthDamageBonus = 2.0, invulnerable = true },
            },
        },
        unlockRequirement = { techId = "STEALTH_TECHNOLOGY", coreLevel = 4 },
        formationRole = "侧翼",
    },

    {
        id = "RAILGUN",
        name = "轨道炮舰",
        nameEn = "Railgun Capital Ship",
        description = "超远程单体高伤的重炮平台。充能后发射轨道炮，对单一目标造成巨额伤害，但射速缓慢，需要前排护航。",
        stats = {
            health     = 900,
            damage     = 900,
            speed      = 35,
            shield     = 350,
            range      = 500,
            buildTime  = 30,
            cost       = { metal = 280, energy = 220, purpleCrystal = 12 },
        },
        skills = {
            {
                skillId  = "HYPER_RAILGUN",
                name     = "轨道炮击",
                cooldown = 10,
                duration = 3,
                effect   = { chargeTime = 3, damageMult = 3.5, armorPierce = 0.8 },
            },
        },
        unlockRequirement = { techId = "RAILGUN_WEAPONRY", coreLevel = 5 },
        formationRole = "后排",
    },
}

-- ============================================================================
-- 索引表（按 id 快速查找）
-- ============================================================================

local SHIP_BY_ID = {}
for _, ship in ipairs(NEW_SHIP_TYPES) do
    SHIP_BY_ID[ship.id] = ship
end

-- ============================================================================
-- 导出函数
-- ============================================================================

--- 按 id 获取舰种定义
---@param shipId string @ "ENGINEER" | "STEALTH" | "RAILGUN"
---@return table|nil
function NewShipTypes.get(shipId)
    if not shipId then return nil end
    return SHIP_BY_ID[shipId]
end

--- 获取所有新舰种定义
---@return table
function NewShipTypes.getAll()
    return NEW_SHIP_TYPES
end

--- 根据玩家已解锁的科技，返回可用的新舰种列表
---@param researchedTechs table @ 已解锁科技表 { TECH_ID = true, ... }
---@return table @ 当前可建造的新舰种数组
function NewShipTypes.getUnlockedShips(researchedTechs)
    local unlocked = {}
    researchedTechs = researchedTechs or {}

    for _, ship in ipairs(NEW_SHIP_TYPES) do
        local req = ship.unlockRequirement
        if req and req.techId and researchedTechs[req.techId] then
            table.insert(unlocked, ship)
        end
    end
    return unlocked
end

--- 检查某舰种是否解锁（便捷函数）
---@param shipId string
---@param researchedTechs table
---@return boolean, string @ (是否解锁, 未解锁原因)
function NewShipTypes.isUnlocked(shipId, researchedTechs)
    local ship = SHIP_BY_ID[shipId]
    if not ship then return false, "未知舰种" end
    researchedTechs = researchedTechs or {}
    local req = ship.unlockRequirement
    if req and req.techId and not researchedTechs[req.techId] then
        return false, "需要科技: " .. tostring(req.techId)
    end
    return true, ""
end

return NewShipTypes
