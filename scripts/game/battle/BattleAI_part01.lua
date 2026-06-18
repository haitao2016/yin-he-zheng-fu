-- Auto-split from BattleAI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function BattleAI.Init(refs)
    makeShip_        = refs.makeShip
    playerFleet_     = refs.playerFleet
    enemyFleet_      = refs.enemyFleet
    projectiles_     = refs.projectiles
    floatTexts_      = refs.floatTexts
    explParticles_   = refs.explParticles
    hitSparks_       = refs.hitSparks
    shockRings_      = refs.shockRings
    fwParticles_     = refs.fwParticles
    SK_              = refs.SK
    RF_              = refs.RF
    battleStats_     = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    COMBO_LEVELS     = refs.COMBO_LEVELS
    rm_              = refs.rm
    SHIP_TYPES_      = refs.SHIP_TYPES
end
