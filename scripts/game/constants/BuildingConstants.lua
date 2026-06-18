--[[
Constants/BuildingConstants.lua
基地建筑、模块、升级相关常量
]]

local M = {}

-- ============================================================================
-- 基地建筑
-- ============================================================================

M.BUILDINGS = {
    MINE        = { name = "自动化矿井",   cost = { metal = 100, resource = 50 },             prod = { minerals = 10 },  buildTime = 5,  upgradeK = 1.5 },
    POWER_PLANT = { name = "太阳能阵列",   cost = { metal = 80 },                              prod = { energy = 15 },    buildTime = 3,  upgradeK = 1.4 },
    SHIELD_GEN  = { name = "护盾发生器",   cost = { metal = 300, resource = 400, nuclear = 100 }, prod = {},                buildTime = 12, upgradeK = 1.8 },
    TRADE_HUB   = { name = "星际交易所",   cost = { metal = 500, resource = 300, nuclear = 80 }, prod = { credits = 5 },   buildTime = 15, upgradeK = 1.6 },
}

M.BUILD_ORDER = { "MINE", "POWER_PLANT", "SHIELD_GEN", "TRADE_HUB" }
M.BUILDING_SPECS = {
    MINE        = { name = "自动化矿井",   cost = { metal = 100, resource = 50 },             prod = { minerals = 10 },  buildTime = 5,  upgradeK = 1.5 },
    POWER_PLANT = { name = "太阳能阵列",   cost = { metal = 80 },                              prod = { energy = 15 },    buildTime = 3,  upgradeK = 1.4 },
    SHIELD_GEN  = { name = "护盾发生器",   cost = { metal = 300, resource = 400, nuclear = 100 }, prod = {},                buildTime = 12, upgradeK = 1.8 },
    TRADE_HUB   = { name = "星际交易所",   cost = { metal = 500, resource = 300, nuclear = 80 }, prod = { credits = 5 },   buildTime = 15, upgradeK = 1.6 },
}

-- ============================================================================
-- 基地模块
-- ============================================================================

M.BASE_MODULES = {
    POWER_PLANT = { name = "电站",         level = 1, cost = { minerals = 100 },     prod = { energy = 5 },   unlockLevel = 1, desc = "基础能源供给" },
    MINING_RIG = { name = "采矿设施",     level = 1, cost = { minerals = 150 },     prod = { minerals = 3 }, unlockLevel = 1, desc = "基础采矿设施" },
    RESEARCH_LAB = { name = "科研实验室",  level = 1, cost = { minerals = 200, energy = 100 }, prod = { research = 5 }, unlockLevel = 2, desc = "基础科研设施" },
    SHIPYARD = { name = "船坞",          level = 1, cost = { minerals = 300, energy = 200 }, prod = {},               unlockLevel = 2, desc = "舰船建造设施" },
    DEFENSE_TOWER = { name = "防御塔",    level = 1, cost = { minerals = 400, crystal = 50 },  prod = { defense = 10 },  unlockLevel = 3, desc = "基地防御设施" },
    WAREHOUSE = { name = "仓库",         level = 1, cost = { minerals = 250 },     prod = { storageCapMult = 1.5 }, unlockLevel = 2, desc = "资源存储设施" },
}

M.BASE_MODULE_ORDER = { "POWER_PLANT", "MINING_RIG", "RESEARCH_LAB", "SHIPYARD", "DEFENSE_TOWER", "WAREHOUSE" }
M.BASE_MODULE_UNLOCK_LEVEL = { POWER_PLANT = 1, MINING_RIG = 1, RESEARCH_LAB = 2, SHIPYARD = 2, DEFENSE_TOWER = 3, WAREHOUSE = 2 }
M.BASE_CORE_MAX_LEVEL = 10

-- 基地核心升级费用
M.BASE_CORE_UPGRADE_COSTS = {
    [1] = { minerals = 300,  energy = 100,  buildTime = 30 },
    [2] = { minerals = 500,  energy = 200,  crystal = 50,  buildTime = 45 },
    [3] = { minerals = 800,  energy = 350,  crystal = 100, buildTime = 60 },
    [4] = { minerals = 1200, energy = 500,  crystal = 150, buildTime = 80 },
    [5] = { minerals = 1800, energy = 800,  crystal = 250, nuclear = 50,  buildTime = 100 },
    [6] = { minerals = 2500, energy = 1200, crystal = 400, nuclear = 100, buildTime = 120 },
    [7] = { minerals = 3500, energy = 1800, crystal = 600, nuclear = 200, buildTime = 150 },
    [8] = { minerals = 5000, energy = 2500, crystal = 900, nuclear = 400, buildTime = 200 },
    [9] = { minerals = 7000, energy = 3500, crystal = 1300, nuclear = 700, buildTime = 250 },
}

return M
