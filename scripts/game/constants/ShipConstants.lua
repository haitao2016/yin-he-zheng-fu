--[[
Constants/ShipConstants.lua
舰船、舰船类型、模块、伤害相关常量
]]

local M = {}

-- ============================================================================
-- 舰船类型
-- ============================================================================

M.SHIP_TYPES = {
    FIGHTER = { name = "战斗机", cost = 100, buildTime = 2, health = 50, attack = 15, defense = 5, size = 8, speed = 200 },
    CORVETTE = { name = "护卫舰", cost = 200, buildTime = 4, health = 100, attack = 25, defense = 10, size = 12, speed = 160 },
    DESTROYER = { name = "驱逐舰", cost = 500, buildTime = 8, health = 200, attack = 50, defense = 20, size = 18, speed = 120 },
    BATTLECRUISER = { name = "战列巡洋舰", cost = 1200, buildTime = 15, health = 500, attack = 120, defense = 50, size = 24, speed = 90 },
    CARRIER = { name = "航母", cost = 2000, buildTime = 25, health = 600, attack = 60, defense = 30, size = 28, speed = 70 },
    VOID_LORD = { name = "虚空领主", cost = 5000, buildTime = 50, health = 1500, attack = 300, defense = 120, size = 36, speed = 50 },
    DEVASTATOR = { name = "毁灭者", cost = 10000, buildTime = 80, health = 3000, attack = 500, defense = 200, size = 40, speed = 40 },
    ENGINEER = { name = "工程维修舰", cost = 800, buildTime = 12, health = 200, attack = 10, defense = 25, size = 16, speed = 140, special = "REPAIR" },
    STEALTH = { name = "隐形突击舰", cost = 1500, buildTime = 20, health = 150, attack = 180, defense = 15, size = 14, speed = 220, special = "STEALTH" },
    RAILGUN = { name = "轨道炮舰", cost = 2500, buildTime = 30, health = 400, attack = 250, defense = 40, size = 20, speed = 100, special = "RAILGUN" },
}

M.SHIP_TYPE_KEYS = {
    "FIGHTER", "CORVETTE", "DESTROYER", "BATTLECRUISER", "CARRIER",
    "VOID_LORD", "DEVASTATOR", "ENGINEER", "STEALTH", "RAILGUN",
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

return M
