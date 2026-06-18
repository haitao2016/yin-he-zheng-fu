--[[
GameConstants.lua - 统一常量分发器
V3.0 拆分重构 - 向后兼容所有调用方
所有常量从此处重新导出，实际定义在各 constants/ 子模块中
]]

local ShipConstants     = require("game.constants.ShipConstants")
local BuildingConstants = require("game.constants.BuildingConstants")
local TechConstants     = require("game.constants.TechConstants")
local CampaignConstants = require("game.constants.CampaignConstants")
local SeasonConstants   = require("game.constants.SeasonConstants")
local CommanderConstants = require("game.constants.CommanderConstants")
local GuildConstants    = require("game.constants.GuildConstants")
local AchievementConstants = require("game.constants.AchievementConstants")
local GalaxyEventConstants = require("game.constants.GalaxyEventConstants")

-- ============================================================================
-- 舰船、舰船类型、模块、伤害
-- ============================================================================
SHIP_TYPES = ShipConstants.SHIP_TYPES
SHIP_TYPE_KEYS = ShipConstants.SHIP_TYPE_KEYS
DEFAULT_SHIP_TYPE = ShipConstants.DEFAULT_SHIP_TYPE
FORMATIONS = ShipConstants.FORMATIONS
CURRENT_FORMATION = ShipConstants.CURRENT_FORMATION
SHIP_MODULES = ShipConstants.SHIP_MODULES
SHIP_MODULES_BY_CAT = ShipConstants.SHIP_MODULES_BY_CAT
MODULE_CAT = ShipConstants.MODULE_CAT
BOSS_PHASES = ShipConstants.BATTLE_PHASES

-- ============================================================================
-- 基地建筑、模块、升级
-- ============================================================================
BUILDINGS = BuildingConstants.BUILDINGS
BUILD_ORDER = BuildingConstants.BUILD_ORDER
BUILDING_SPECS = BuildingConstants.BUILDING_SPECS
BASE_MODULES = BuildingConstants.BASE_MODULES
BASE_MODULE_ORDER = BuildingConstants.BASE_MODULE_ORDER
BASE_MODULE_UNLOCK_LEVEL = BuildingConstants.BASE_MODULE_UNLOCK_LEVEL
BASE_CORE_MAX_LEVEL = BuildingConstants.BASE_CORE_MAX_LEVEL
BASE_CORE_UPGRADE_COSTS = BuildingConstants.BASE_CORE_UPGRADE_COSTS

-- ============================================================================
-- 科技树、关卡难度、指挥官
-- ============================================================================
STAGE_DIFFICULTY = TechConstants.STAGE_DIFFICULTY
COMMANDER_MAX_LEVEL = TechConstants.COMMANDER_MAX_LEVEL
COMMANDER_MAX_SLOTS = TechConstants.COMMANDER_MAX_SLOTS
COMMANDER_RETIRE_REWARD = TechConstants.COMMANDER_RETIRE_REWARD
COMMANDER_EXP_TABLE = TechConstants.COMMANDER_EXP_TABLE
COMMANDER_SPECS = TechConstants.COMMANDER_SPECS
COMMANDER_NAMES = TechConstants.COMMANDER_NAMES
COMMANDER_SOURCE = TechConstants.COMMANDER_SOURCE
COMMANDER_MARKET_COST = TechConstants.COMMANDER_MARKET_COST
TECHS = TechConstants.TECHS

-- ============================================================================
-- 战役系统
-- ============================================================================
STAGE_OBJECTIVES = CampaignConstants.STAGE_OBJECTIVES
CAMPAIGN_CHAPTERS = CampaignConstants.CAMPAIGN_CHAPTERS
CAMPAIGN_DIALOGUE = CampaignConstants.CAMPAIGN_DIALOGUE
CAMPAIGN_BRANCHES = CampaignConstants.CAMPAIGN_BRANCHES

-- ============================================================================
-- 赛季系统
-- ============================================================================
SEASONS = SeasonConstants.SEASONS
SEASON_POINT_REWARDS = SeasonConstants.SEASON_POINT_REWARDS
SEASON_STATE = SeasonConstants.SEASON_STATE

-- ============================================================================
-- 指挥官系统
-- ============================================================================
COMMANDERS = CommanderConstants.COMMANDERS
COMMANDER_RECRUITMENT = CommanderConstants.COMMANDER_RECRUITMENT
CURRENT_COMMANDER = CommanderConstants.CURRENT_COMMANDER
COMMANDER_SKILL_COOLDOWNS = CommanderConstants.COMMANDER_SKILL_COOLDOWNS

-- ============================================================================
-- 公会系统
-- ============================================================================
GUILD_LEVEL_REWARDS = GuildConstants.GUILD_LEVEL_REWARDS
GUILD_JOIN_TYPES = GuildConstants.GUILD_JOIN_TYPES
GUILD_ROLES = GuildConstants.GUILD_ROLES
GUILD_DAILY_TASKS = GuildConstants.GUILD_DAILY_TASKS
GUILD_WEEKLY_TASKS = GuildConstants.GUILD_WEEKLY_TASKS
RUNTIME_GUILDS = GuildConstants.RUNTIME_GUILDS
RUNTIME_PLAYER_GUILD = GuildConstants.RUNTIME_PLAYER_GUILD

-- ============================================================================
-- 成就与资源
-- ============================================================================
ACHIEVEMENT_DEFINITIONS = AchievementConstants.ACHIEVEMENT_DEFINITIONS
ACHIEVEMENT_CHAINS = AchievementConstants.ACHIEVEMENT_CHAINS
RESOURCE_TYPES = AchievementConstants.RESOURCE_TYPES
GAME_BALANCE = AchievementConstants.GAME_BALANCE
BATTLE_ENVIRONMENTS = AchievementConstants.BATTLE_ENVIRONMENTS
MAP_VARIANT_ENV_WEIGHTS = AchievementConstants.MAP_VARIANT_ENV_WEIGHTS

-- ============================================================================
-- 银河事件
-- ============================================================================
GALAXY_EVENTS = GalaxyEventConstants.GALAXY_EVENTS
ACTIVE_GALAXY_EVENTS = GalaxyEventConstants.ACTIVE_GALAXY_EVENTS

-- ============================================================================
-- 阵型系统常量（保留为 SHIP_FORMATIONS 别名以保持兼容）
-- ============================================================================
SHIP_FORMATIONS = {
    {
        id = "VANGUARD", name = "前卫阵型", desc = "舰船分散布置，减小AOE伤害",
        icon = "formation_vanguard", effect = { aoeReduction = 0.2, spreadBonus = 0.1 },
        shipOrder = { "DESTROYER", "BATTLECRUISER" },
    },
    {
        id = "PHALANX", name = "方阵", desc = "紧密排列，火力集中",
        icon = "formation_phalanx", effect = { dmgBonus = 0.15, aoeExposure = 0.3 },
        shipOrder = { "BATTLECRUISER", "DESTROYER", "CARRIER" },
    },
    {
        id = "FLANK", name = "两翼包抄", desc = "从侧翼进攻，机动性提升",
        icon = "formation_flank", effect = { speedBonus = 0.2, sideDmgBonus = 0.25 },
        shipOrder = { "STEALTH", "DESTROYER", "CORVETTE" },
    },
    {
        id = "CRESCENT", name = "新月阵型", desc = "弧形布置，兼顾攻防",
        icon = "formation_crescent", effect = { defenseBonus = 0.15, dmgBonus = 0.1 },
        shipOrder = { "BATTLECRUISER", "SUPPORT", "DESTROYER" },
    },
    {
        id = "PINZHER", name = "钳形攻势", desc = "前后夹击，优先集火",
        icon = "formation_pinzher", effect = { focusFireBonus = 0.3, frontBackDmg = 0.2 },
        shipOrder = { "DESTROYER", "CARRIER", "DESTROYER" },
    },
    {
        id = "SKIRMISH", name = "游击阵型", desc = "保持距离，边打边退",
        icon = "formation_skirmish", effect = { retreatSpeedBonus = 0.3, hitAndRunDmg = 0.4 },
        shipOrder = { "STEALTH", "CORVETTE", "STEALTH" },
    },
}

-- 银河事件效果应用状态（运行时）
GALAXY_EVENT_EFFECTS = {
    travelSpeedMult = 1.0,
    tradeBonus = 0.0,
    mineOutputMult = 1.0,
    shieldPenalty = 1.0,
    stealthBonus = 1.0,
    noTax = false,
    researchSpeedMult = 1.0,
}
