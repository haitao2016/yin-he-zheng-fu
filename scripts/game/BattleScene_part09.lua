-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function BattleScene.StartNextWave()
    waveNum_ = waveNum_ + 1
    -- P2-1: 推进异象状态（上一波结束）
    local newAnomaly = AnomalySystem.OnWaveEnd(waveNum_ - 1)
    if newAnomaly then
        anomalyNotify_      = newAnomaly
        anomalyNotifyTimer_ = ANOMALY_NOTIFY_DUR
        if notifyFn_ then
            notifyFn_(newAnomaly.icon .. " " .. newAnomaly.name .. " — " .. newAnomaly.desc, "info")
        end
        print(string.format("[P2-1] 新异象: %s 持续%d波", newAnomaly.name, newAnomaly.duration))
    end
    -- 保留存活玩家舰船
    local survivors = playerFleet_
    screenW_, screenH_ = UICommon.getVirtualSize()
    playerFleet_ = survivors
    -- 加入排队新舰
    for _, ps in ipairs(pendingShips_) do
        local x = 80 + math.random() * 60
        local y = screenH_*0.2 + math.random() * screenH_*0.6
        playerFleet_[#playerFleet_+1] = makeShip(ps, x, y, "player")
    end
    pendingShips_     = {}
    -- P2-2: 先确定是否为夹击波次（25%概率；Boss波不触发夹击）
    isPincerWave_   = (waveNum_ % BOSS_WAVE_INTERVAL ~= 0) and (math.random() < 0.25)
    pincerDefended_ = false
    pincerAnnounceTimer_ = isPincerWave_ and PINCER_ANNOUNCE_DUR or 0
    -- P1-2: 宿敌遭遇判定（非Boss波时检查）
    nemesisActive_ = false
    nemesisAnnounceTimer_ = 0
    nemesisResult_        = nil
    nemesisResultTimer_   = 0
    local nemesisCaptainId = NemesisSystem.CheckEncounter(waveNum_)
    syncAIVars()
    if nemesisCaptainId then
        -- 触发宿敌遭遇：替换常规敌舰队
        NemesisSystem.StartEncounter(nemesisCaptainId, waveNum_)
        nemesisActive_ = true
        nemesisAnnounceTimer_ = NEMESIS_ANNOUNCE_DUR
        enemyFleet_ = BattleAI.BuildNemesisWave(nemesisCaptainId)
        -- 宿敌波不触发夹击
        isPincerWave_ = false
        pincerAnnounceTimer_ = 0
    else
        enemyFleet_ = BattleAI.BuildEnemyWave(waveNum_)
    end
    waveEnemyTotal_   = waveEnemyTotal_ + #enemyFleet_  -- P2-1: 累积本场敌人总数
    projectiles_      = {}
    floatTexts_       = {}
    hitSparks_        = {}
    shockRings_       = {}
    moveTarget_       = nil
    moveTargetTimer_  = 0
    state_            = "fighting"
    stateTimer_       = 0
    battleEndFired_   = false
    waveGapTimer_     = 0
    formationLocked_  = true   -- P2-3: 战斗开始锁定阵型
    prepSkipped_      = false  -- P2-3: 重置跳过标记
    initialPlayerCount_ = #playerFleet_
    currentWaveStar_    = 0
    starAnim_           = 0
    -- Boss 波状态重置
    bossDefeated_     = false
    -- P1-1: 新波次开始，重置本波统计
    waveKills_     = 0
    waveMaxCombo_  = 0
    waveDmgDealt_  = 0
    waveShipsLost_ = 0
    -- P3-2: 存活舰船的 MVP 统计字段随波次清零
    for _, ps in ipairs(playerFleet_) do
        ps.statDmg   = 0
        ps.statKills = 0
    end
    local isBossW = (waveNum_ % BOSS_WAVE_INTERVAL == 0)
    bossWarningTimer_ = isBossW and BOSS_WARNING_DUR or 0
    -- P3-1: 注册新舰船到回放系统（新波次的新增舰船）
    for _, ship in ipairs(playerFleet_) do
        if not ship._replayId then BattleReplaySystem.RegisterShip(ship) end
    end
    for _, ship in ipairs(enemyFleet_) do
        BattleReplaySystem.RegisterShip(ship)
    end
    if nemesisActive_ then
        -- P1-2: 宿敌遭遇优先级最高的通知
        Audio.Play(Audio.SFX.WAVE_INCOMING)
        Audio.SetBGMPitch(1.08)  -- 宿敌波更紧张的音调
        local capInfo = NemesisSystem.GetActiveCaptain()
        local capName = capInfo and capInfo.name or "宿敌"
        local lvl     = capInfo and capInfo.level or 1
        local isFinale = capInfo and capInfo.isFinale
        if isFinale then
            if notifyFn_ then notifyFn_("☠ 最终决战 — " .. capName .. " 再次现身！", "error") end
        else
            if notifyFn_ then notifyFn_("⚔ 宿敌来袭 — " .. capName .. " [Lv." .. lvl .. "]", "error") end
        end
    elseif isBossW then
        Audio.Play(Audio.SFX.WAVE_INCOMING)
        -- P3-3: Boss波次音调提升5%，增强紧张感
        Audio.SetBGMPitch(1.05)
        if notifyFn_ then notifyFn_("⚠️ 第 " .. waveNum_ .. " 波 — 旗舰Boss来袭！", "error") end
    else
        Audio.Play(Audio.SFX.WAVE_INCOMING)
        -- P3-3: 非Boss波恢复正常音调
        Audio.ResetBGMPitch()
        if notifyFn_ then notifyFn_("第 " .. waveNum_ .. " 波敌军来袭！", "warn") end
    end
    -- P2-2b: 记录新波次开始
    logBattleEvent(string.format("第 %d 波战斗开始 — %s 迎战", waveNum_, fleetName_))
    -- P2-2: 夹击波次通知
    if isPincerWave_ and notifyFn_ then
        notifyFn_("↕ 上下夹击！敌军从两侧突袭", "error")
    end
    -- P1-1: 新波次按阵型重新排布（仅对新加入的舰船；存活舰船保持原位）
    syncAIVars(); syncAIRefs()
    BattleAI.ApplyFormationPositions(playerFleet_)
    -- P1-1: 触发波次开始型被动（SCOUT/EXPLORER/CARRIER/ENGINEER）
    BattleAI.ApplyWaveStartPassives()
    syncAIVarsBack()
    -- P1-1 NOVA_CANNON: 新波次开始时预充能技能
    if rm_ and rm_.baseBonus and rm_.baseBonus.battleStartSkillCharge then
        BattleSkills.PreChargeOnWaveStart(rm_.baseBonus.battleStartSkillCharge)
    end
    -- P1-1 FORTRESS_PROTOCOL: 护盾回复计时器清零
    fortressRegenTimer_ = 0

    -- P2-1: 应用星域异象修正到双方舰船
    local anomMods = AnomalySystem.GetBattleModifiers()
    if anomMods.damageMult ~= 1.0 or anomMods.speedMult ~= 1.0 or anomMods.hpMult ~= 1.0 or anomMods.shieldMult ~= 1.0 then
        for _, ship in ipairs(playerFleet_) do
            ship.dmg   = ship.dmg * anomMods.damageMult
            ship.speed = ship.speed * anomMods.speedMult
            if anomMods.hpMult ~= 1.0 then
                local newMax = math.max(1, math.floor(ship.maxHealth * anomMods.hpMult))
                local ratio  = ship.maxHealth > 0 and (ship.health / ship.maxHealth) or 1.0
                ship.maxHealth = newMax
                ship.health    = math.max(1, math.floor(newMax * ratio))
            end
        end
    end
    if anomMods.enemyDamageMult ~= 1.0 or anomMods.enemySpeedMult ~= 1.0 or anomMods.hpMult ~= 1.0 then
        for _, ship in ipairs(enemyFleet_) do
            ship.dmg   = ship.dmg * anomMods.enemyDamageMult
            ship.speed = ship.speed * anomMods.enemySpeedMult
            if anomMods.hpMult ~= 1.0 then
                local newMax = math.max(1, math.floor(ship.maxHealth * anomMods.hpMult))
                local ratio  = ship.maxHealth > 0 and (ship.health / ship.maxHealth) or 1.0
                ship.maxHealth = newMax
                ship.health    = math.max(1, math.floor(newMax * ratio))
            end
        end
    end
    -- 存储首轮伤害倍率(首次射击后恢复)
    if anomMods.firstStrikeMult ~= 1.0 then
        for _, ship in ipairs(playerFleet_) do ship.firstStrikeMult = anomMods.firstStrikeMult end
        for _, ship in ipairs(enemyFleet_) do  ship.firstStrikeMult = anomMods.firstStrikeMult end
    end

    -- P1-3: 联赛敌人攻击力修正
    if leagueAttackMult_ ~= 1.0 then
        for _, ship in ipairs(enemyFleet_) do
            ship.dmg = ship.dmg * leagueAttackMult_
        end
    end

    -- P1-2: 新波次重新随机环境
    if math.random() < 0.30 then
        currentEnv_ = BATTLE_ENVIRONMENTS.NONE
    else
        local key = ENV_POOL[math.random(#ENV_POOL)]
        currentEnv_ = BATTLE_ENVIRONMENTS[key]
    end
    envParticles_     = {}
    envAsteroidTimer_ = currentEnv_.asteroidInterval or 2.0
    envAnnounceTimer_ = (currentEnv_.key ~= "NONE") and ENV_ANNOUNCE_DUR or 0
    envAnnounceAlpha_ = (currentEnv_.key ~= "NONE") and 255 or 0
    if currentEnv_.key ~= "NONE" and notifyFn_ then
        notifyFn_(currentEnv_.icon .. " 进入" .. currentEnv_.label .. "区域！" .. currentEnv_.desc, "info")
    end
    -- P2-1: 新波次增援状态重置（Boss波不触发，wave < RF_.MIN_WAVE 不触发）
    local isBossThisWave = (waveNum_ % BOSS_WAVE_INTERVAL == 0)
    ---@diagnostic disable-next-line: undefined-global
    RF_.pending    = not isBossThisWave and waveNum_ >= RF_.MIN_WAVE and math.random() < RF_.PROB
    RF_.warning    = 0
    RF_.spawned    = false
    RF_.remain     = 0
    RF_.defeated   = false
    RF_.startEnemyCnt = #enemyFleet_
    if RF_.pending then
        print(string.format("[P2-1] Wave%d 将触发增援（Boss波=%s）", waveNum_, tostring(isBossThisWave)))
    end
    print("[BattleScene] Wave " .. waveNum_ .. " 开始  敌方: " .. #enemyFleet_ .. "  阵型: " .. currentFormation_)
end

-- ============================================================================
-- 逻辑更新
-- ============================================================================
--- 将本地状态推入共享上下文 ctx（每帧 Update 开始时调用）
--- 表字段为引用拷贝（子模块对内容的修改自动可见）；标量为值拷贝；常量每帧覆盖
local function pushToCtx()
    -- 表（引用拷贝，内容修改自动可见）
    ctx.playerFleet   = playerFleet_
    ctx.enemyFleet    = enemyFleet_
    ctx.projectiles   = projectiles_
    ctx.floatTexts    = floatTexts_
    ctx.fireParticles = fireParticles_
    ctx.explParticles = explParticles_
    ctx.hitSparks     = hitSparks_
    ctx.shockRings    = shockRings_
    ctx.fwParticles   = fwParticles_
    ctx.bgStars       = bgStars_
    ctx.envParticles  = envParticles_
    ctx.battleStats   = battleStats_
    ctx.battleLog     = battleLog_
    ctx.SK            = SK_
    ctx.RF            = RF_
    ctx.FORMATION_CONFIG = FORMATION_CONFIG
    ctx.COMBO_LEVELS  = COMBO_LEVELS
    ctx.currentEnv    = currentEnv_
    -- 外部引用
    ctx.rm          = rm_
    ctx.rs          = rs_
    ctx.player      = player_
    ctx.notifyFn    = notifyFn_
    ctx.onBattleEnd = onBattleEnd_
    ctx.fleetName   = fleetName_
    -- 常量（每帧覆盖 BattleContext 默认值，确保用 BattleScene 真实值）
    ctx.WAVE_GAP               = WAVE_GAP
    ctx.BOSS_BANNER_DUR        = BOSS_BANNER_DUR
    ctx.MILESTONE_BANNER_DUR   = MILESTONE_BANNER_DUR
    ctx.NEMESIS_RESULT_DUR     = NEMESIS_RESULT_DUR
    ctx.BG_SCROLL_VX           = BG_SCROLL_VX
    ctx.BG_SCROLL_VY           = BG_SCROLL_VY
    ctx.DESTROYER_PIERCE_COUNT = DESTROYER_PIERCE_COUNT
    ctx.FRIGATE_SHARE_RATIO    = FRIGATE_SHARE_RATIO
    ctx.BATTLECRUISER_BLOCK    = BATTLECRUISER_BLOCK
    ctx.CHAIN_RADIUS           = CHAIN_RADIUS
    ctx.CHAIN_AOE_PCT          = CHAIN_AOE_PCT
    ctx.CHAIN_MIN_KILLS        = CHAIN_MIN_KILLS
    ctx.COMBO_RESET_TIME       = COMBO_RESET_TIME
    ctx.ENGINEER_HEAL_INTERVAL = ENGINEER_HEAL_INTERVAL
    ctx.ENGINEER_HEAL_AMOUNT   = ENGINEER_HEAL_AMOUNT
    ctx.BATTLE_LOG_MAX         = BATTLE_LOG_MAX
    -- 标量 + 可空引用
    ctx.screenW            = screenW_
    ctx.screenH            = screenH_
    ctx.shootSfxTimer      = shootSfxTimer_
    ctx.reinforceCooldown  = reinforceCooldown_
    ctx.state              = state_
    ctx.stateTimer         = stateTimer_
    ctx.battleEndFired     = battleEndFired_
    ctx.waveGapTimer       = waveGapTimer_
    ctx.prepSkipped        = prepSkipped_
    ctx.waveNum            = waveNum_
    ctx.bossDefeated       = bossDefeated_
    ctx.bossWarningTimer   = bossWarningTimer_
    ctx.bossFlashAlpha     = bossFlashAlpha_
    ctx.bossFlashTimer     = bossFlashTimer_
    ctx.milestoneFlashAlpha  = milestoneFlashAlpha_
    ctx.milestoneBannerTimer = milestoneBannerTimer_
    ctx.milestoneRound     = milestoneRound_
    ctx.endlessRound       = endlessRound_
    ctx.hpBlinkTimer       = hpBlinkTimer_
    ctx.interceptorEngineTimer = interceptorEngineTimer_
    ctx.fireTimer          = fireTimer_
    ctx.fwLaunchTimer      = fwLaunchTimer_
    ctx.bgScrollX          = bgScrollX_
    ctx.bgScrollY          = bgScrollY_
    ctx.currentWaveStar    = currentWaveStar_
    ctx.starAnim           = starAnim_
    ctx.initialPlayerCount = initialPlayerCount_
    ctx.engineerHealTimer  = engineerHealTimer_
    ctx.chainCount         = chainCount_
    ctx.envAnnounceAlpha   = envAnnounceAlpha_
    ctx.envAnnounceTimer   = envAnnounceTimer_
    ctx.envAsteroidTimer   = envAsteroidTimer_
    ctx.fortressRegenTimer = fortressRegenTimer_
    ctx.pincerAnnounceTimer = pincerAnnounceTimer_
    ctx.pincerDefended     = pincerDefended_
    ctx.isPincerWave       = isPincerWave_
    ctx.nemesisActive      = nemesisActive_
    ctx.nemesisAnnounceTimer = nemesisAnnounceTimer_
    ctx.nemesisResult      = nemesisResult_
    ctx.nemesisResultTimer = nemesisResultTimer_
    ctx.anomalyNotify      = anomalyNotify_
    ctx.anomalyNotifyTimer = anomalyNotifyTimer_
    ctx.moveTarget         = moveTarget_
    ctx.moveTargetTimer    = moveTargetTimer_
    ctx.cmdSkillActive     = cmdSkillActive_
    ctx.cmdSkillTimer      = cmdSkillTimer_
    ctx.cmdSkillDef        = cmdSkillDef_
    ctx.commanderFleetId   = commanderFleetId_
    ctx.currentFormation   = currentFormation_
    ctx.formationLocked    = formationLocked_
    ctx.focusTarget        = focusTarget_
    ctx.explorerMarkTarget = explorerMarkTarget_
    ctx.skillUpgradeCards  = skillUpgradeCards_
    ctx.waveSummary        = waveSummary_
    ctx.waveKills          = waveKills_
    ctx.waveKillTotal      = waveKillTotal_
    ctx.waveMaxCombo       = waveMaxCombo_
    ctx.waveDmgDealt       = waveDmgDealt_
    ctx.waveShipsLost      = waveShipsLost_
    ctx.comboCount         = comboCount_
    ctx.comboTimer         = comboTimer_
    ctx.comboDisplayTimer  = comboDisplayTimer_
end

--- 将 ctx 中被子模块修改的标量/可空引用拉回本地状态（每帧 Update 结束时调用）
--- 纯表/常量/只读引用无需拉回（表为同一对象，常量不变）
local function pullFromCtx()
    screenW_            = ctx.screenW
    screenH_            = ctx.screenH
    shootSfxTimer_      = ctx.shootSfxTimer
    reinforceCooldown_  = ctx.reinforceCooldown
    state_              = ctx.state
    stateTimer_         = ctx.stateTimer
    battleEndFired_     = ctx.battleEndFired
    waveGapTimer_       = ctx.waveGapTimer
    prepSkipped_        = ctx.prepSkipped
    waveNum_            = ctx.waveNum
    bossDefeated_       = ctx.bossDefeated
    bossWarningTimer_   = ctx.bossWarningTimer
    bossFlashAlpha_     = ctx.bossFlashAlpha
    bossFlashTimer_     = ctx.bossFlashTimer
    milestoneFlashAlpha_  = ctx.milestoneFlashAlpha
    milestoneBannerTimer_ = ctx.milestoneBannerTimer
    milestoneRound_     = ctx.milestoneRound
    endlessRound_       = ctx.endlessRound
    hpBlinkTimer_       = ctx.hpBlinkTimer
    interceptorEngineTimer_ = ctx.interceptorEngineTimer
    fireTimer_          = ctx.fireTimer
    fwLaunchTimer_      = ctx.fwLaunchTimer
    bgScrollX_          = ctx.bgScrollX
    bgScrollY_          = ctx.bgScrollY
    currentWaveStar_    = ctx.currentWaveStar
    starAnim_           = ctx.starAnim
    initialPlayerCount_ = ctx.initialPlayerCount
    engineerHealTimer_  = ctx.engineerHealTimer
    chainCount_         = ctx.chainCount
    envAnnounceAlpha_   = ctx.envAnnounceAlpha
    envAnnounceTimer_   = ctx.envAnnounceTimer
    envAsteroidTimer_   = ctx.envAsteroidTimer
    fortressRegenTimer_ = ctx.fortressRegenTimer
    pincerAnnounceTimer_ = ctx.pincerAnnounceTimer
    pincerDefended_     = ctx.pincerDefended
    isPincerWave_       = ctx.isPincerWave
    nemesisActive_      = ctx.nemesisActive
    nemesisAnnounceTimer_ = ctx.nemesisAnnounceTimer
    nemesisResult_      = ctx.nemesisResult
    nemesisResultTimer_ = ctx.nemesisResultTimer
    anomalyNotify_      = ctx.anomalyNotify
    anomalyNotifyTimer_ = ctx.anomalyNotifyTimer
    moveTarget_         = ctx.moveTarget
    moveTargetTimer_    = ctx.moveTargetTimer
    cmdSkillActive_     = ctx.cmdSkillActive
    cmdSkillTimer_      = ctx.cmdSkillTimer
    cmdSkillDef_        = ctx.cmdSkillDef
    commanderFleetId_   = ctx.commanderFleetId
    currentFormation_   = ctx.currentFormation
    formationLocked_    = ctx.formationLocked
    focusTarget_        = ctx.focusTarget
    explorerMarkTarget_ = ctx.explorerMarkTarget
    skillUpgradeCards_  = ctx.skillUpgradeCards
    waveSummary_        = ctx.waveSummary
    waveKills_          = ctx.waveKills
    waveKillTotal_      = ctx.waveKillTotal
    waveMaxCombo_       = ctx.waveMaxCombo
    waveDmgDealt_       = ctx.waveDmgDealt
    waveShipsLost_      = ctx.waveShipsLost
    comboCount_         = ctx.comboCount
    comboTimer_         = ctx.comboTimer
    comboDisplayTimer_  = ctx.comboDisplayTimer
end

--- 主逻辑更新：sync 桥 + 委托战斗子模块
function BattleScene.Update(dt)
    pushToCtx()

    -- 已结束状态守卫（win/lose）：处理倒计时/烟花，跳过战斗逻辑
    local handled, startNext = BattleWinLose.UpdateGuard(dt, ctx)
    if handled then
        pullFromCtx()
        if startNext then BattleScene.StartNextWave() end
        return
    end

    -- 计时器/背景/环境粒子/连击衰减/增援/自适应音乐/指挥官技能/要塞回复
    BattleTimers.Update(dt, ctx, makeShip)
    -- 玩家舰队战斗（移动/集火/模块/词缀/伤害）
    BattleCombatPlayer.Update(dt, ctx)
    -- 敌方 AI 战斗（移动/索敌/伤害/阵型/反弹）
    BattleCombatEnemy.Update(dt, ctx)
    -- 死亡清理 + 击杀归属 + 连击 + Boss奖励 + 连锁反应
    BattleDeath.Update(dt, ctx, makeShip)
    -- 视觉/音效更新（子弹/飘字/粒子/震动/被动治疗等）
    BattleVFX.Update(dt, ctx)
    -- 胜负检测与结算（资源奖励/星级/技能卡）
    BattleWinLose.Detect(dt, ctx)

    pullFromCtx()
end

-- ============================================================================
-- 渲染（委托给 BattleRender 模块）
-- ============================================================================
function BattleScene.Render()
    -- 同步状态到 BattleState 共享表
    local BS = BattleState
    BS.vg       = vg_
    BS.screenW  = screenW_
    BS.screenH  = screenH_

    BS.playerFleet = playerFleet_
    BS.enemyFleet  = enemyFleet_
    BS.projectiles = projectiles_
    BS.floatTexts  = floatTexts_

    BS.fireParticles = fireParticles_
    BS.explParticles = explParticles_
    BS.hitSparks     = hitSparks_
    BS.shockRings    = shockRings_
    BS.fwParticles   = fwParticles_

    BS.state      = state_
    BS.stateTimer = stateTimer_
    BS.waveNum    = waveNum_

    BS.SK = SK_

    BS.bossWarningTimer  = bossWarningTimer_
    BS.bossFlashAlpha    = bossFlashAlpha_
    BS.bossFlashTimer    = bossFlashTimer_
    BS.bossDefeated      = bossDefeated_
    BS.BOSS_WAVE_INTERVAL = BOSS_WAVE_INTERVAL

    BS.comboCount        = comboCount_
    BS.comboTimer        = comboTimer_
    BS.comboDisplayTimer = comboDisplayTimer_
    BS.COMBO_LEVELS      = COMBO_LEVELS

    BS.waveGapTimer = waveGapTimer_
    BS.prepSkipped  = prepSkipped_
    BS.WAVE_GAP     = WAVE_GAP

    BS.bgStars   = bgStars_
    BS.bgScrollX = bgScrollX_
    BS.bgScrollY = bgScrollY_
    BS.currentEnv    = currentEnv_
    BS.envParticles  = envParticles_
    BS.envAnnounceAlpha = envAnnounceAlpha_
    BS.envAnnounceTimer = envAnnounceTimer_

    BS.moveTarget      = moveTarget_
    BS.moveTargetTimer = moveTargetTimer_

    BS.shipImages = shipImages_

    BS.selectedShip = selectedShip_
    BS.focusTarget  = focusTarget_

    BS.currentFormation = currentFormation_
    BS.formationLocked  = formationLocked_
    BS.FORMATION_CONFIG = FORMATION_CONFIG

    BS.retreatUsed       = retreatUsed_
    BS.reinforceCooldown = reinforceCooldown_

    BS.skillUpgradeCards = skillUpgradeCards_

    BS.nemesisActive        = nemesisActive_
    BS.nemesisAnnounceTimer = nemesisAnnounceTimer_
    BS.nemesisResult        = nemesisResult_
    BS.nemesisResultTimer   = nemesisResultTimer_

    BS.isPincerWave        = isPincerWave_
    BS.pincerAnnounceTimer = pincerAnnounceTimer_

    BS.anomalyNotify      = anomalyNotify_
    BS.anomalyNotifyTimer = anomalyNotifyTimer_

    BS.RF = RF_

    BS.endlessRound        = endlessRound_
    BS.milestoneFlashAlpha = milestoneFlashAlpha_
    BS.milestoneBannerTimer = milestoneBannerTimer_
    BS.milestoneRound      = milestoneRound_

    BS.waveSummary = waveSummary_

    BS.currentWaveStar = currentWaveStar_
    BS.starAnim        = starAnim_
    BS.hpBlinkTimer    = hpBlinkTimer_

    BS.battleStats        = battleStats_
    BS.initialPlayerCount = initialPlayerCount_

    BS.explorerMarkTarget = explorerMarkTarget_

    -- 模块/函数引用（仅首次或变化时需要，但每帧赋值开销极低）
    BS.LiverySystem  = LiverySystem
    BS.BattleSkills  = BattleSkills
    BS.rm            = rm_
    BS.rs            = rs_
    BS.notifyFn      = notifyFn_
    BS.getComboLevel      = getComboLevel
    BS.getNextWavePreview = BattleAI.GetNextWavePreview
    BS.SHIP_TYPES    = Systems.SHIP_TYPES
    BS.NemesisSystem = NemesisSystem
    BS.AnomalySystem = AnomalySystem

    -- 执行渲染
    BattleRender.Render()

    -- 回写：渲染函数可能修改的按钮区域/选中状态
    formationBtn_         = BS.formationBtn
    retreatBtn_           = BS.retreatBtn
    reinforceBtn_         = BS.reinforceBtn
    focusHudBtn_          = BS.focusHudBtn
    skillUpgradeCardBtns_ = BS.skillUpgradeCardBtns
    selectedShip_         = BS.selectedShip
    loseBtn1_             = BS.loseBtn1
    loseBtn2_             = BS.loseBtn2
end


-- ============================================================================
-- 状态查询
-- ============================================================================
function BattleScene.GetState()       return state_ end
function BattleScene.GetWave()        return waveNum_ end
function BattleScene.GetPlayerCount() return #playerFleet_ end
function BattleScene.GetEnemyCount()  return #enemyFleet_ end
function BattleScene.GetStats()
    -- P3-1: 从回放系统获取 MVP 数据
    local replayMVP = BattleReplaySystem.GetMVP()
    local mvpShip = nil
    local mvpReason = nil
    local mvpScore = 0
    if replayMVP then
        mvpShip   = replayMVP.stype
        mvpReason = replayMVP.reason
        mvpScore  = replayMVP.score
    end

    return {
        dmgDealt       = battleStats_.dmgDealt,
        dmgTaken       = battleStats_.dmgTaken,
        enemiesKilled  = battleStats_.enemiesKilled,
        wavesCleared   = battleStats_.wavesCleared,
        bestSurvivor   = battleStats_.bestSurvivor,
        -- P2-3: 隐藏成就字段
        shipsLost      = battleStats_.shipsLost,
        overkillMax    = battleStats_.overkillMax,
        focusBossKill  = battleStats_.focusBossKill,
        focusKillCount = battleStats_.focusKillCount or 0,
        -- P3-1: 最高连击 & MVP
        maxCombo       = battleStats_.maxCombo or 0,
        mvpShip        = mvpShip,
        mvpReason      = mvpReason,
        mvpScore       = mvpScore,
        -- P2-1 V2.0: 全场击杀率计算字段
        waveEnemyTotal = waveEnemyTotal_,
        waveKillTotal  = waveKillTotal_,
        -- P1-3: 连锁反应次数
        chainCount     = battleStats_.chainCount,
        -- P2-1: 是否全歼增援
        reinforceWin   = battleStats_.reinforceWin or false,
        -- P2-2b: 战斗日志
        battleLog      = battleLog_,
    }
end

--- P2-2b: 获取战斗日志（供 EndGamePanel 调用）
---@return table[] {{wave=number, text=string}, ...}
function BattleScene.GetBattleLog()
    return battleLog_
end

--- P3-1: 获取回放数据（供 EndGamePanel 调用）
---@return table {highlights, mvp, duration, frameCount, eventCount}
function BattleScene.GetReplayData()
    return {
        highlights  = BattleReplaySystem.GetHighlights(),
        mvp         = BattleReplaySystem.GetMVP(),
        duration    = BattleReplaySystem.GetDuration(),
        frameCount  = #BattleReplaySystem.GetFrames(),
        eventCount  = #BattleReplaySystem.GetEvents(),
    }
end

-- ============================================================================
-- 输入（由 main.lua 调用）
-- ============================================================================
function BattleScene.OnClick(mx, my)
    -- P2-2: 技能升级弹窗期间优先处理卡片点击，屏蔽其他输入
    if skillUpgradeCards_ and #skillUpgradeCards_ > 0 and state_ == "win" then
        for _, btn in ipairs(skillUpgradeCardBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                BattleSkills.UpgradeSkill(btn.skillIdx)
                local lv = BattleSkills.GetLevel(btn.skillIdx)
                if notifyFn_ then
                    notifyFn_(BattleSkills.GetIcon(btn.skillIdx) .. " " ..
                        BattleSkills.GetName(btn.skillIdx) .. " 升至 Lv" .. lv, "success")
                end
                skillUpgradeCards_    = nil
                skillUpgradeCardBtns_ = {}
                return
            end
        end
        return  -- 点击弹窗以外区域也吃掉，不传递
    end

    -- M2: 战败画面触屏按钮处理
    if state_ == "lose" then
        local function inBtn(b)
            return b and mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h
        end
        if inBtn(loseBtn1_) then
            -- 重新战斗：重置战场
            BattleScene.Reset()
            return
        elseif inBtn(loseBtn2_) then
            -- 返回星图：触发战败回调
            if onBattleEnd_ and not battleEndFired_ then
                battleEndFired_ = true
                onBattleEnd_("lose")
            end
            return
        end
        return  -- 战败时屏蔽其他区域点击
    end
    if state_ ~= "fighting" then return end

    -- P2-2: 检测集火取消按钮（顶部状态条右侧 ✕）
    if focusHudBtn_ then
        local b = focusHudBtn_
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            focusTarget_ = nil
            return
        end
    end

    -- P2-2: 舰船点击检测（我方 + 敌方，点击舰船显示信息面板）
    local SHIP_HIT_RADIUS = 14  -- 点击热区半径（px）
    local clickedShip = nil
    -- 优先检测我方（玩家通常想了解自己的舰船）
    for _, s in ipairs(playerFleet_) do
        local dx, dy = mx - s.x, my - s.y
        if dx*dx + dy*dy <= SHIP_HIT_RADIUS * SHIP_HIT_RADIUS then
            clickedShip = s; break
        end
    end
    if not clickedShip then
        for _, s in ipairs(enemyFleet_) do
            local dx, dy = mx - s.x, my - s.y
            if dx*dx + dy*dy <= SHIP_HIT_RADIUS * SHIP_HIT_RADIUS then
                clickedShip = s; break
            end
        end
    end
    if clickedShip then
        if clickedShip.team == "enemy" then
            -- P2-2: 点击敌方舰船 → 设置/取消集火目标
            if focusTarget_ == clickedShip then
                focusTarget_ = nil   -- 再次点击同一敌方 → 取消集火
            else
                focusTarget_ = clickedShip
            end
        end
        -- 同时更新信息面板选中
        if selectedShip_ == clickedShip then
            selectedShip_ = nil
        else
            selectedShip_ = clickedShip
        end
        return
    end

    -- P1-2: 撤退按钮点击
    if retreatBtn_ then
        local b = retreatBtn_
        if mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h then
            local energy = rm_ and (rm_.resources.energy or 0) or 0
            if energy < RETREAT_COST_ENERGY then
                if notifyFn_ then notifyFn_(string.format("能源不足（需%d）", RETREAT_COST_ENERGY), "warn") end
            else
                rm_:add("energy", -RETREAT_COST_ENERGY)
                retreatUsed_    = true
                battleEndFired_ = true
                if onBattleEnd_ then onBattleEnd_("retreat") end
            end
            return
        end
    end

    -- P1-2: 增援按钮点击
    if reinforceBtn_ then
        local b = reinforceBtn_
        if mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h then
            if not b.canDo then
                if notifyFn_ then
                    notifyFn_(string.format("增援需金属%d 晶体%d", REINFORCE_COST_METAL, REINFORCE_COST_CRYSTAL), "warn")
                end
            else
                rm_:add("metal",   -REINFORCE_COST_METAL)
                rm_:add("crystal", -REINFORCE_COST_CRYSTAL)
                reinforceCooldown_ = 12  -- 12秒内不能再次增援
                -- 派入 2 艘 FRIGATE
                for _ = 1, 2 do
                    local x = 60 + math.random() * 50
                    local y = screenH_ * 0.2 + math.random() * screenH_ * 0.6
                    playerFleet_[#playerFleet_+1] = makeShip("FRIGATE", x, y, "player")
                end
                if notifyFn_ then notifyFn_("紧急增援！2艘护卫舰抵达战场！", "success") end
            end
            return
        end
    end

    -- P1-1: 阵型按钮点击判断
    for _, btn in ipairs(formationBtn_) do
        if mx >= btn.x and mx <= btn.x+btn.w and my >= btn.y and my <= btn.y+btn.h then
            if btn.locked then return end  -- P2-1: 锁定状态不响应点击
            BattleScene.SetFormation(btn.key)
            return
        end
    end

    -- 技能按钮点击判断
    local function inBtn(b)
        return b and mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h
    end
    if BattleSkills.OnClick(mx, my, {
        rs          = rs_,
        notifyFn    = notifyFn_,
        playerFleet = playerFleet_,
        enemyFleet  = enemyFleet_,
        floatTexts  = floatTexts_,
        battleStats = battleStats_,
        screenW     = screenW_,
        screenH     = screenH_,
        onShake     = function(dur, str)
            SK_.timer = dur; SK_.dur = dur; SK_.strength = str
        end,
    }) then return end

    -- 普通点击：移动指令（同时取消单舰选中）
    selectedShip_ = nil
    for i, s in ipairs(playerFleet_) do
        local spread = (#playerFleet_ > 1) and (i - (#playerFleet_+1)/2) * 28 or 0
        s.target = { x=mx, y=my + spread }
    end
    moveTarget_ = { x=mx, y=my }
end

return BattleScene
