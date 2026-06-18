-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function BattleScene.Reset()
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- 基础玩家舰队
    local midY = (screenH_ + 88) / 2   -- 战场中线（排除顶部标题区）
    playerFleet_ = {
        makeShip("FRIGATE",  100, midY,      "player"),
        makeShip("SCOUT",    120, midY - 55, "player"),
        makeShip("SCOUT",    120, midY + 55, "player"),
    }
    -- 加入已生产的舰船
    for _, ps in ipairs(pendingShips_) do
        local x = 80 + math.random() * 60
        local y = screenH_*0.2 + math.random() * screenH_*0.6
        playerFleet_[#playerFleet_+1] = makeShip(ps, x, y, "player")
    end
    pendingShips_    = {}
    -- P2-2: 先确定是否为夹击波次（25%概率；Boss波不触发夹击）
    isPincerWave_   = (waveNum_ % BOSS_WAVE_INTERVAL ~= 0) and (math.random() < 0.25)
    pincerDefended_ = false
    pincerAnnounceTimer_ = isPincerWave_ and PINCER_ANNOUNCE_DUR or 0
    -- 根据波次生成敌方舰队
    syncAIVars()
    enemyFleet_      = BattleAI.BuildEnemyWave(waveNum_)
    -- P2-1: 增援状态重置（wave1 不触发，重新开局时清空）
    RF_.pending  = false
    RF_.warning  = 0
    RF_.spawned  = false
    RF_.remain   = 0
    RF_.defeated = false
    RF_.startEnemyCnt = #enemyFleet_
    waveEnemyTotal_  = waveEnemyTotal_ + #enemyFleet_  -- P2-1: 累积本场敌人总数
    projectiles_     = {}
    floatTexts_      = {}
    fireParticles_   = {}
    fireTimer_       = 0
    explParticles_   = {}
    hitSparks_       = {}
    shockRings_      = {}
    SK_.timer      = 0
    SK_.strength   = 0
    SK_.offX       = 0
    SK_.offY       = 0
    fwParticles_            = {}
    fwLaunchTimer_          = 0
    interceptorEngineTimer_ = 0
    -- P3-1: 初始化背景星星（只在首次或全局重置时生成）
    if #bgStars_ == 0 then
        bgStars_ = {}
        bgScrollX_ = 0
        bgScrollY_ = 0
        -- P3-3: 画质缩放（低=0.5, 中=1.0, 高=1.5）
        local qScale = SettingsPanel.GetQualityScale()
        local n1 = math.max(10, math.floor(60 * qScale))
        local n2 = math.max(6,  math.floor(35 * qScale))
        local n3 = math.max(3,  math.floor(12 * qScale))
        -- layer 1: 远景小星（慢速，暗淡）
        for _ = 1, n1 do
            bgStars_[#bgStars_+1] = {
                x            = math.random() * (screenW_ + 200),
                y            = math.random() * screenH_,
                r            = 0.6 + math.random() * 0.8,
                alpha        = 80  + math.floor(math.random() * 80),
                twinklePhase = math.random() * math.pi * 2,
                twinkleSpeed = 0.5 + math.random() * 1.0,
                layer        = 1,
            }
        end
        -- layer 2: 中景中星（中速，中亮）
        for _ = 1, n2 do
            bgStars_[#bgStars_+1] = {
                x            = math.random() * (screenW_ + 200),
                y            = math.random() * screenH_,
                r            = 1.0 + math.random() * 1.2,
                alpha        = 120 + math.floor(math.random() * 80),
                twinklePhase = math.random() * math.pi * 2,
                twinkleSpeed = 0.8 + math.random() * 1.5,
                layer        = 2,
            }
        end
        -- layer 3: 近景大星（快速，明亮，带十字光晕）
        for _ = 1, n3 do
            bgStars_[#bgStars_+1] = {
                x            = math.random() * (screenW_ + 200),
                y            = math.random() * screenH_,
                r            = 1.8 + math.random() * 1.5,
                alpha        = 180 + math.floor(math.random() * 60),
                twinklePhase = math.random() * math.pi * 2,
                twinkleSpeed = 1.2 + math.random() * 2.0,
                layer        = 3,
            }
        end
    end
    -- 连击系统重置（每次完整开局清零）
    comboCount_        = 0
    comboTimer_        = 0
    comboDisplayTimer_ = 0
    -- 战斗统计清零（仅在完全重置时清零，波次间累计）
    battleStats_.dmgDealt      = 0
    battleStats_.dmgTaken      = 0
    battleStats_.enemiesKilled = 0
    battleStats_.wavesCleared  = 0
    battleStats_.bestSurvivor  = nil
    battleStats_.shipsLost      = 0     -- P2-3
    battleStats_.overkillMax    = 0     -- P2-3
    battleStats_.focusBossKill  = false -- P2-3
    battleStats_.focusKillCount = 0     -- P2-3
    battleLog_ = {}  -- P2-2b: 重置战斗日志
    -- P1-1: 每波统计清零
    waveKills_     = 0
    waveMaxCombo_  = 0
    waveDmgDealt_  = 0
    waveShipsLost_ = 0
    waveSummary_   = nil
    -- P2-1 V2.0: 全场击杀率追踪（整场战斗从第1波开始累积）
    waveEnemyTotal_ = 0
    waveKillTotal_  = 0
    selectedShip_  = nil  -- P2-2: 重置时取消选中
    focusTarget_   = nil  -- P2-2: 重置集火目标
    initialPlayerCount_  = #playerFleet_
    currentWaveStar_     = 0
    -- P3-1: 战斗回放系统启动录制
    BattleReplaySystem.StartRecording()
    for _, ship in ipairs(playerFleet_) do
        BattleReplaySystem.RegisterShip(ship)
    end
    for _, ship in ipairs(enemyFleet_) do
        BattleReplaySystem.RegisterShip(ship)
    end
    starAnim_            = 0
    moveTarget_             = nil
    moveTargetTimer_ = 0
    state_           = "fighting"
    stateTimer_      = 0
    battleEndFired_  = false
    waveGapTimer_    = 0
    formationLocked_ = true  -- P2-3: 战斗开始锁定阵型
    -- P1-2: 撤退/增援状态重置
    retreatUsed_       = false
    retreatBtn_        = nil
    reinforceBtn_      = nil
    reinforceCooldown_ = 0
    -- P2-2: 技能升级弹窗重置（新波次开始时关闭弹窗）
    skillUpgradeCards_     = nil
    skillUpgradeCardBtns_  = {}
    -- 技能状态重置（跨波次保留冷却，不重置激活效果）
    BattleSkills.Reset()
    -- P1-1 NOVA_CANNON: 每波开始时预充能技能
    if rm_ and rm_.baseBonus and rm_.baseBonus.battleStartSkillCharge then
        BattleSkills.PreChargeOnWaveStart(rm_.baseBonus.battleStartSkillCharge)
    end
    -- P1-1 FORTRESS_PROTOCOL: 护盾回复计时器清零
    fortressRegenTimer_ = 0
    -- Boss 波状态重置
    bossDefeated_        = false
    bossFlashAlpha_      = 0
    bossFlashTimer_      = 0
    milestoneFlashAlpha_ = 0
    milestoneBannerTimer_= 0
    hpBlinkTimer_    = 0  -- P3-2 V2.0: 低血闪烁计时器重置
    if waveNum_ % BOSS_WAVE_INTERVAL == 0 then
        bossWarningTimer_ = BOSS_WARNING_DUR
    else
        bossWarningTimer_ = 0
    end
    -- P1-1: 按当前阵型重新排布玩家舰队位置和属性
    syncAIVars(); syncAIRefs()
    BattleAI.ApplyFormationPositions(playerFleet_)
    -- P1-1: 触发波次开始型被动（SCOUT/EXPLORER/CARRIER/ENGINEER）
    BattleAI.ApplyWaveStartPassives()
    syncAIVarsBack()

    -- P1-2: 随机选择战斗环境（70% 有环境，30% 无）
    local function selectEnv()
        if math.random() < 0.30 then
            currentEnv_ = BATTLE_ENVIRONMENTS.NONE
        else
            local key = ENV_POOL[math.random(#ENV_POOL)]
            currentEnv_ = BATTLE_ENVIRONMENTS[key]
        end
        envParticles_    = {}
        envAsteroidTimer_ = currentEnv_.asteroidInterval or 2.0
        envAnnounceTimer_ = (currentEnv_.key ~= "NONE") and ENV_ANNOUNCE_DUR or 0
        envAnnounceAlpha_ = (currentEnv_.key ~= "NONE") and 255 or 0
        print("[BattleScene] P1-2 环境: " .. currentEnv_.key)
    end
    selectEnv()

    print("[BattleScene] 重置 Wave " .. waveNum_ .. "  我方: " .. #playerFleet_ .. "  敌方: " .. #enemyFleet_ .. "  阵型: " .. currentFormation_)
end
