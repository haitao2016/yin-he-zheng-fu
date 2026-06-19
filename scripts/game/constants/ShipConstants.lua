--[[
Constants/ShipConstants.lua
舰船、舰船类型、模块、伤害相关常量
]]

local M = {}

-- ============================================================================
-- 舰船类型
-- ============================================================================

M.SHIP_TYPES = {
    -- 基础舰船：攻防比约 0.25-0.30
    FIGHTER = { name = "战斗机", cost = 100, buildTime = 2, health = 50, attack = 15, defense = 5, size = 8, speed = 200 },
    CORVETTE = { name = "护卫舰", cost = 200, buildTime = 4, health = 100, attack = 25, defense = 10, size = 12, speed = 160 },
    DESTROYER = { name = "驱逐舰", cost = 500, buildTime = 8, health = 200, attack = 50, defense = 20, size = 18, speed = 120 },
    -- 主力舰：攻防比约 0.20-0.24
    BATTLECRUISER = { name = "战列巡洋舰", cost = 1200, buildTime = 15, health = 500, attack = 120, defense = 50, size = 24, speed = 90 },
    CARRIER = { name = "航母", cost = 2000, buildTime = 25, health = 800, attack = 120, defense = 40, size = 28, speed = 70, special = "CARRIER_SQUADRON" },  -- P2-P2-1: 攻击上调至 120，航母应有一定输出
    -- 终极舰：攻防比约 0.17-0.20
    VOID_LORD = { name = "虚空领主", cost = 5000, buildTime = 50, health = 1500, attack = 300, defense = 120, size = 36, speed = 50 },
    DEVASTATOR = { name = "毁灭者", cost = 10000, buildTime = 80, health = 3000, attack = 500, defense = 200, size = 40, speed = 40 },
    -- 特殊舰：按其定位调整
    ENGINEER = { name = "工程维修舰", cost = 800, buildTime = 12, health = 300, attack = 20, defense = 40, size = 16, speed = 140, special = "REPAIR" },  -- P2-P2-1: 攻击上调至 20，但仍为辅助定位
    STEALTH = { name = "隐形突击舰", cost = 1500, buildTime = 20, health = 200, attack = 150, defense = 15, size = 14, speed = 220, special = "STEALTH" },  -- P2-P2-1: 生命上调至 200（从 150），攻击下调至 150（从 180）
    RAILGUN = { name = "轨道炮舰", cost = 2500, buildTime = 30, health = 500, attack = 200, defense = 40, size = 20, speed = 100, special = "RAILGUN" },  -- P2-P2-1: 生命上调至 500（从 400），攻击下调至 200（从 250）
    -- P3-P1-1: 新增舰种
    MEDICAL = { name = "医疗舰", cost = 1200, buildTime = 15, health = 350, attack = 10, defense = 30, size = 18, speed = 110, special = "HEAL" },  -- 治疗型支援舰，治疗范围内友舰
    ELECTRONIC = { name = "电子战舰", cost = 1500, buildTime = 18, health = 250, attack = 40, defense = 25, size = 16, speed = 130, special = "JAMMING" },  -- 干扰型舰船，削弱敌方命中率和护盾效率
    FLAGSHIP = { name = "旗舰", cost = 8000, buildTime = 60, health = 2500, attack = 200, defense = 150, size = 38, speed = 45, special = "COMMAND" },  -- 指挥型舰船，提供全局伤害和速度加成
}

M.SHIP_TYPE_KEYS = {
    "FIGHTER", "CORVETTE", "DESTROYER", "BATTLECRUISER", "CARRIER",
    "VOID_LORD", "DEVASTATOR", "ENGINEER", "STEALTH", "RAILGUN",
    "MEDICAL", "ELECTRONIC", "FLAGSHIP",  -- P3-P1-1: 新增 3 种舰船
}

M.DEFAULT_SHIP_TYPE = "FIGHTER"

-- 阵型
M.FORMATIONS = {
    VANGUARD = { name = "前卫阵型", desc = "舰船分散布置，减小AOE伤害" },
    PHALANX = { name = "方阵", desc = "紧密排列，火力集中" },
    FLANK = { name = "两翼包抄", desc = "从侧翼进攻，机动性提升" },
    CRESCENT = { name = "新月阵型", desc = "弧形布置，兼顾攻防" },
    PINZHER = { name = "钳形攻势", desc = "前后夹击，优先集火" },
    SKIRMISH = { name = "游击阵型", desc = "保持距离，边打边退" },
}

M.CURRENT_FORMATION = "VANGUARD"

-- ============================================================================
-- 舰船模块
-- ============================================================================

M.SHIP_MODULES = {}
M.SHIP_MODULES_BY_CAT = { attack = {}, defense = {}, utility = {} }
M.MODULE_CAT = { ATTACK = "attack", DEFENSE = "defense", UTILITY = "utility" }

-- ============================================================================
-- 战斗环境
-- ============================================================================

M.BATTLE_ENVIRONMENTS = {
    ASTEROID_FIELD = { name = "小行星带", desc = "移动速度-30%，但提供20%掩体防护" },
    NEBULA = { name = "星云区", desc = "隐形效果+50%，但探测范围-30%" },
    SOLAR_STORM = { name = "太阳风暴", desc = "护盾效率-40%，能源恢复-20%" },
    GRAVITY_WELL = { name = "重力井", desc = "所有舰船和弹药速度减半" },
    DEBRIS_FIELD = { name = "残骸区", desc = "提供40%掩体，20%几率从残骸获取资源" },
    ION_STORM = { name = "离子风暴", desc = "护盾恢复-50%，技能冷却+30%" },
    WARP_ZONE = { name = "曲速区", desc = "移动速度翻倍，技能冷却-30%" },
    CRYSTAL_FIELD = { name = "晶体区", desc = "护盾效率+30%，15%几率额外获得晶石" },
}

M.BATTLE_PHASES = {
    PHASE1 = { name = "阶段一", hpThreshold = 0.66, damageMult = 1.0 },
    PHASE2 = { name = "阶段二", hpThreshold = 0.33, damageMult = 1.3 },
    PHASE3 = { name = "阶段三", hpThreshold = 0.0,  damageMult = 1.6 },
}

---@param SHIP_DEFS table
---@param SHIP_TYPES table
---@param SHIP_NAMES table
---@param C table
---@return table, table, table, table
local function applyBalanceTuning(SHIP_DEFS, SHIP_TYPES, SHIP_NAMES, C)
    local BALANCE_TUNING = {
        BASIC = {
            BATTLESHIP = { maxHealth = 1.03, damage = 0.97, speed = 1.03 },
            CRUISER    = { maxHealth = 0.97, damage = 1.03, speed = 1.00 },
            DESTROYER  = { maxHealth = 1.00, damage = 0.97, speed = 1.03 },
            FRIGATE    = { maxHealth = 1.03, damage = 1.00, speed = 0.97 },
            SCOUT      = { maxHealth = 0.97, damage = 1.03, speed = 1.03 },
        },
        FLAGSHIP = { maxHealth = 1.5, damage = 1.3, speed = 0.8 },
        SPECIAL = {
            MINER  = { maxHealth = 1.2, damage = 0.6, speed = 0.9 },
            REPAIR = { maxHealth = 1.1, damage = 0.5, speed = 1.0 },
            SUPPORT = { maxHealth = 1.15, damage = 0.7, speed = 0.95 },
            EWAR   = { maxHealth = 0.9, damage = 0.8, speed = 1.15 },
        },
        RARE = {
            TITAN       = { maxHealth = 1.8, damage = 1.5, speed = 0.75 },
            DREADNOUGHT = { maxHealth = 2.0, damage = 1.6, speed = 0.70 },
            RAIDER      = { maxHealth = 0.95, damage = 1.4, speed = 1.20 },
            CARRIER     = { maxHealth = 1.6, damage = 1.2, speed = 0.80 },
        },
    }

    local function apply(def, t)
        if not def or not t then return end
        if t.maxHealth and def.maxHealth then def.maxHealth = def.maxHealth * t.maxHealth end
        if t.damage    and def.damage    then def.damage    = def.damage    * t.damage    end
        if t.speed     and def.speed     then def.speed     = def.speed     * t.speed     end
    end

    for key, tune in pairs(BALANCE_TUNING.BASIC) do
        if SHIP_DEFS and SHIP_DEFS[key] then apply(SHIP_DEFS[key], tune) end
        if SHIP_TYPES and SHIP_TYPES[key] then apply(SHIP_TYPES[key], tune) end
        if C and C[key] then apply(C[key], tune) end
    end
    if SHIP_DEFS and SHIP_DEFS.FLAGSHIP then apply(SHIP_DEFS.FLAGSHIP, BALANCE_TUNING.FLAGSHIP) end
    if SHIP_TYPES and SHIP_TYPES.FLAGSHIP then apply(SHIP_TYPES.FLAGSHIP, BALANCE_TUNING.FLAGSHIP) end
    if C and C.FLAGSHIP then apply(C.FLAGSHIP, BALANCE_TUNING.FLAGSHIP) end
    for key, tune in pairs(BALANCE_TUNING.SPECIAL) do
        if SHIP_DEFS and SHIP_DEFS[key] then apply(SHIP_DEFS[key], tune) end
        if SHIP_TYPES and SHIP_TYPES[key] then apply(SHIP_TYPES[key], tune) end
        if C and C[key] then apply(C[key], tune) end
    end
    for key, tune in pairs(BALANCE_TUNING.RARE) do
        if SHIP_DEFS and SHIP_DEFS[key] then apply(SHIP_DEFS[key], tune) end
        if SHIP_TYPES and SHIP_TYPES[key] then apply(SHIP_TYPES[key], tune) end
        if C and C[key] then apply(C[key], tune) end
    end

    if print then print("[Balance] balance tuning applied") end

    return SHIP_DEFS, SHIP_TYPES, SHIP_NAMES, C
end

applyBalanceTuning(M.SHIP_DEFS or {}, M.SHIP_TYPES or {}, M.SHIP_NAMES or {}, M)

return M
