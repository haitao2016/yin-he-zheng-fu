------------------------------------------------------------
-- battle------------------------------------------------------------
-- battle/BattleAICombat.lua
--------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAI------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleRe------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_P------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATT------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemy------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shield------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockR------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(ref------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   =------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    project------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORM------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SH------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 =========------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo,------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function find------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil,------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipSte------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            --------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10,------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 4------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 1------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(5------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255;------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ +------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) *------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife =------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r =------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random()------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShock------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockR------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x,------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width =------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRU------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, max------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g =------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g =------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(6------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6,------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang)------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() *------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() * 0.6), maxLife = life,
            r = r, g = g, b------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() * 0.6), maxLife = life,
            r = r, g = g, b = b, size = 2 + math.random() * (isBig and 4 or------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() * 0.6), maxLife = life,
            r = r, g = g, b = b, size = 2 + math.random() * (isBig and 4 or 2),
        }
    end
    local str = isBig and 6.0------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() * 0.6), maxLife = life,
            r = r, g = g, b = b, size = 2 + math.random() * (isBig and 4 or 2),
        }
    end
    local str = isBig and 6.0 or 2.5
    local dur = isBig and 0.28 or------------------------------------------------------------
-- battle/BattleAICombat.lua
-- 战斗更新：玩家舰队 / 敌方舰队 每帧逻辑
------------------------------------------------------------

local BattleAICombat = {}
local BattleSkills = require("game.BattleSkills")
local BattleReplaySystem = require("game.BattleReplaySystem")

local DESTROYER_PIERCE_COUNT = 5
local INTERCEPTOR_SPD_MULT   = 1.30
local FRIGATE_SHARE_RATIO    = 0.20
local BATTLECRUISER_BLOCK    = 0.10
local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0 },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0 },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60 },
}

local playerFleet_
local enemyFleet_
local projectiles_
local floatTexts_
local explParticles_
local hitSparks_
local shockRings_
local SK_
local battleStats_
local FORMATION_CONFIG
local rm_
local SHIP_TYPES_
local vars_

function BattleAICombat.Init(refs)
    playerFleet_   = refs.playerFleet
    enemyFleet_    = refs.enemyFleet
    projectiles_   = refs.projectiles
    floatTexts_    = refs.floatTexts
    explParticles_ = refs.explParticles
    hitSparks_     = refs.hitSparks
    shockRings_    = refs.shockRings
    SK_            = refs.SK
    battleStats_   = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    rm_            = refs.rm
    SHIP_TYPES_    = refs.SHIP_TYPES
end

function BattleAICombat.SyncVarsIn(v)
    vars_ = v
end

function BattleAICombat.GetVarsOut()
    return vars_
end

-- ============ 内部工具函数 ============

local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local spd = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r = 100 + math.random(80); g = 200 + math.random(55); b = 255
    else
        r = 255; g = 120 + math.random(80); b = math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 6, y = y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = 0.2 + math.random() * 0.15, maxLife = 0.35,
            r = r, g = g, b = b, size = 1.5 + math.random() * 1.5,
        }
    end
end

local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y, radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur, r = r, g = g, b = b, width = 2,
    }
end

local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45

    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12, ptype = "flash"
    }
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r = 200 + math.random(55)
        local g = 80 + math.random(120)
        local b = math.random(60)
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6, y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() * 0.6), maxLife = life,
            r = r, g = g, b = b, size = 2 + math.random() * (isBig and 4 or 2),
        }
    end
    local str = isBig and 6.0 or 2.5
    local dur = isBig and 0.28 or 0.14
    if str > SK_.strength or SK_.timer <= 0 then