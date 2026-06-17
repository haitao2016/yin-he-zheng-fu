---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/Systems.lua  -- 薄包装器：加载全局常量 + require 各子模块 + 导出
-- 拆分后仅做 re-export，所有逻辑已迁移至 game/systems/*.lua
-- ============================================================================

-- 加载全局常量（BUILDINGS, TECHS, SHIP_TYPES, COMMANDER_* 等）
require("game.GameConstants")

-- require 各子模块
local ResourceManager     = require("game.systems.ResourceManager")
local BuildingSystem      = require("game.systems.BuildingSystem")
local BaseBuildingSystem  = require("game.systems.BaseBuildingSystem")
local ResearchSystem      = require("game.systems.ResearchSystem")
local MarketSystem        = require("game.systems.MarketSystem")
local PlayerProfile       = require("game.systems.PlayerProfile")
local ShipProductionQueue = require("game.systems.ShipProductionQueue")
local FleetManager        = require("game.systems.FleetManager")
local DiplomacySystem     = require("game.systems.DiplomacySystem")

-- ============================================================================
-- 导出（与原始版本完全一致的 key-value 结构）
-- ============================================================================
return {
    -- 9 个类
    ResourceManager      = ResourceManager,
    BuildingSystem       = BuildingSystem,
    BaseBuildingSystem   = BaseBuildingSystem,
    ResearchSystem       = ResearchSystem,
    MarketSystem         = MarketSystem,
    PlayerProfile        = PlayerProfile,
    ShipProductionQueue  = ShipProductionQueue,
    FleetManager         = FleetManager,
    DiplomacySystem      = DiplomacySystem,
    -- 外交常量（来自 DiplomacySystem 模块）
    NEUTRAL_FACTIONS         = DiplomacySystem.NEUTRAL_FACTIONS,
    TRADE_THRESHOLD          = DiplomacySystem.TRADE_THRESHOLD,
    MILITARY_THRESHOLD       = DiplomacySystem.MILITARY_THRESHOLD,
    LONG_TRADE_THRESHOLD     = DiplomacySystem.LONG_TRADE_THRESHOLD,
    LONG_TRADE_BREAK_FAVOR   = DiplomacySystem.LONG_TRADE_BREAK_FAVOR,
    LONG_TRADE_COST          = DiplomacySystem.LONG_TRADE_COST,
    LONG_TRADE_INTERVAL      = DiplomacySystem.LONG_TRADE_INTERVAL,
    MAX_LONG_TRADES          = DiplomacySystem.MAX_LONG_TRADES,
    INTEL_THRESHOLD          = DiplomacySystem.INTEL_THRESHOLD,
    ALLIANCE_THRESHOLD       = DiplomacySystem.ALLIANCE_THRESHOLD,
    BLOCKADE_THRESHOLD       = DiplomacySystem.BLOCKADE_THRESHOLD,
    MEDIATE_THRESHOLD        = DiplomacySystem.MEDIATE_THRESHOLD,
    BLOCKADE_COST            = DiplomacySystem.BLOCKADE_COST,
    MEDIATE_COST             = DiplomacySystem.MEDIATE_COST,
    BLOCKADE_DURATION        = DiplomacySystem.BLOCKADE_DURATION,
    DIPLO_EVENT_INTERVAL     = DiplomacySystem.DIPLO_EVENT_INTERVAL,
    REL_COMPETE              = DiplomacySystem.REL_COMPETE,
    REL_NEUTRAL              = DiplomacySystem.REL_NEUTRAL,
    REL_COOPERATE            = DiplomacySystem.REL_COOPERATE,
    -- 全局常量（来自 GameConstants.lua，已作为全局变量加载）
    TECHS                    = TECHS,
    SHIP_MODULES             = SHIP_MODULES,
    SHIP_MODULES_BY_CAT      = SHIP_MODULES_BY_CAT,
    MODULE_CAT               = MODULE_CAT,
    COMMANDER_MAX_LEVEL      = COMMANDER_MAX_LEVEL,
    COMMANDER_MAX_SLOTS      = COMMANDER_MAX_SLOTS,
    COMMANDER_RETIRE_REWARD  = COMMANDER_RETIRE_REWARD,
    COMMANDER_EXP_TABLE      = COMMANDER_EXP_TABLE,
    COMMANDER_SPECS          = COMMANDER_SPECS,
    COMMANDER_NAMES          = COMMANDER_NAMES,
    COMMANDER_SOURCE         = COMMANDER_SOURCE,
    COMMANDER_MARKET_COST    = COMMANDER_MARKET_COST,
    -- V2.6 新增常量
    BOSS_PHASES              = BOSS_PHASES,
    SHIP_TYPES               = SHIP_TYPES,
}
