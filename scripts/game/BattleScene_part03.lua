-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function syncAIRefs()
    BattleAI.SyncRefs({
        playerFleet   = playerFleet_,
        enemyFleet    = enemyFleet_,
        projectiles   = projectiles_,
        floatTexts    = floatTexts_,
        explParticles = explParticles_,
        hitSparks     = hitSparks_,
        shockRings    = shockRings_,
        fwParticles   = fwParticles_,
    })
end
