-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

    -- P1-3 V2.4: 指挥官加成
    commanderBonus_   = opts.commanderBonus or nil
    commanderFleetId_ = opts.commanderFleetId or nil
    -- P2-2b: 舰队名称（用于战斗日志）
    fleetName_ = opts.fleetName or "舰队"
    cmdSkillActive_   = false
    cmdSkillTimer_    = 0
    cmdSkillDef_      = nil

    -- 加载舰船纹理
    local imageFlags = NVG_IMAGE_PREMULTIPLIED
    shipImages_["SCOUT"]         = nvgCreateImage(vg_, "image/ship_scout_20260511185829.png",         imageFlags)
    shipImages_["FRIGATE"]       = nvgCreateImage(vg_, "image/ship_frigate_20260511185830.png",       imageFlags)
    shipImages_["DESTROYER"]     = nvgCreateImage(vg_, "image/ship_destroyer_20260511185818.png",     imageFlags)
    shipImages_["BATTLECRUISER"] = nvgCreateImage(vg_, "image/ship_battlecruiser_20260512164935.png", imageFlags)
    shipImages_["MINER"]         = nvgCreateImage(vg_, "image/ship_miner_20260511185819.png",         imageFlags)
    shipImages_["ENGINEER"]      = nvgCreateImage(vg_, "image/ship_engineer_20260512071656.png",      imageFlags)
    shipImages_["EXPLORER"]      = nvgCreateImage(vg_, "image/ship_explorer_20260512071647.png",      imageFlags)
    shipImages_["CARRIER"]       = nvgCreateImage(vg_, "image/ship_carrier_20260513074052.png",       imageFlags)
    shipImages_["INTERCEPTOR"]   = nvgCreateImage(vg_, "image/ship_interceptor_20260513074045.png",   imageFlags)
    print("[BattleScene] 舰船纹理加载完成")

    -- P3-1: 重置星场，让 Reset() 重新生成
    bgStars_   = {}
    bgScrollX_ = 0
    bgScrollY_ = 0
    -- P2-2: 全新战斗 — 重置技能等级/点数/弹窗
    BattleSkills.FullReset()
    -- P2-3: 应用成就奖励中的技能加成
    do
        local activeRewards = Achievement.GetActiveRewards()
        for _, entry in ipairs(activeRewards) do
            local r = entry.reward
            if r.type == "skill_point" then
                BattleSkills.AddPoints(r.value)
            elseif r.type == "skill_level" then
                local curLv = BattleSkills.GetLevel(r.value.skill)
                BattleSkills.SetLevel(r.value.skill, math.max(curLv, r.value.level))
            end
        end
    end
    skillUpgradeCards_    = nil
    skillUpgradeCardBtns_ = {}

    -- P3-1a: 初始化 BattleAI 模块（传入所有表引用）
    BattleAI.Init({
        makeShip        = makeShip,
        playerFleet     = playerFleet_,
        enemyFleet      = enemyFleet_,
        projectiles     = projectiles_,
        floatTexts      = floatTexts_,
        explParticles   = explParticles_,
        hitSparks       = hitSparks_,
        shockRings      = shockRings_,
        fwParticles     = fwParticles_,
        SK              = SK_,
        RF              = RF_,
        battleStats     = battleStats_,
        FORMATION_CONFIG = FORMATION_CONFIG,
        COMBO_LEVELS    = COMBO_LEVELS,
        rm              = rm_,
        SHIP_TYPES      = Systems.SHIP_TYPES,
    })

    BattleScene.Reset()
    print("[BattleScene] 初始化完成")
end

