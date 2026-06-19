---@diagnostic disable: assign-type-mismatch, need-check-nil
-- ============================================================================
-- BattleOrchestrator.lua — 战斗循环编排器
-- 负责：主战斗 Update 流程（暂停/战斗速度/胜负判定/波次调度/
--       无尽模式/Boss Rush/超级 Boss/指令系统 等）。
-- 设计：通过 SyncIn 接收 BattleScene 传入的表引用与回调工厂；
--       通过 Update(dt) 推进战斗；通过 GetOut() 返回更新后的标量。
--       与 BattleWinLose / BattleCombat* 协作（由 BattleScene 代为调用）。
-- ============================================================================

local BattleOrchestrator = {}

-- ============================================================================
-- 内部常量（由 BattleScene 持有；本模块仅在内部使用副本）
-- ============================================================================
local BOSS_WAVE_INTERVAL   = 5
local WAVE_GAP             = 8.0
local BOSS_WARNING_DUR     = 2.5
local BOSS_BANNER_DUR      = 2.5
local MILESTONE_BANNER_DUR = 4.0
local RETREAT_COST_ENERGY  = 30
local REINFORCE_COST_METAL   = 50
local REINFORCE_COST_CRYSTAL = 50

-- ============================================================================
-- 无尽模式 & Boss Rush 默认常量（与原 BattleScene 保持一致）
-- ============================================================================
local ENDLESS_MODES_DEFAULT = {
    CLASSIC  = { startWave = 1 },
    SURVIVAL = { startWave = 1 },
    SPEEDRUN = { startWave = 1 },
}

local ENDLESS_REWARDS_DEFAULT = {
    every10Wave = { blueCrystal = { 20, 40 } },
    every25Wave = { purpleCrystal = 100 },
    milestone   = { [10] = { blueCrystal = 50 } },
}

local BOSS_RUSH_DEFAULT = {
    bosses           = {},
    healthBonus      = 500,
    scorePerBoss     = 200,
    timeBonus        = 50,
    restInterval     = 8,
    rewards = {
        perBoss  = { blueCrystal = 30 },
        perfect  = { purpleCrystal = 100 },
        completion = { blueCrystal = 50 },
    },
}

local AUTO_BATTLE_DEFAULT = {
    stealthWhenIdle       = true,
    retreatThreshold      = 0.15,
    useSkillsAutomatically = false,
}

-- ============================================================================
-- 注入的表引用与回调
-- ============================================================================
local makeShipFn_   = nil   ---@type function
local playerFleet_  = nil   ---@type table
local enemyFleet_   = nil   ---@type table
local projectiles_  = nil   ---@type table
local floatTexts_   = nil   ---@type table
local notifyFn_     = nil   ---@type function
local onBattleEnd_  = nil   ---@type function
local rm_           = nil   ---@type table
local rs_           = nil   ---@type table

-- 子模块引用（由 BattleScene 传入）
local BattleWinLose_      = nil
local BattleCombatPlayer_ = nil
local BattleCombatEnemy_  = nil
local BattleTimers_       = nil
local BattleDeath_        = nil
local BattleVFX_          = nil
local BattleContext_      = nil
local cmdSys_             = nil   ---@type table|nil 战斗指令系统实例

-- 子模块开关：为 true 时在 Update 中自动调用同名子模块的 Update(dt, ctx)
local autoCombat_     = true
local autoTimers_     = true
local autoDeath_      = true
local autoVFX_        = true
local autoWinLose_    = true

-- ============================================================================
-- 标量状态（每帧 SyncIn 刷新，修改后通过 GetOut 回写）
-- ============================================================================
local S = {}

--- 同步输入状态（每次 BattleScene Update 开头调用）
--- 所有 table 类型为引用（子模块内部修改 → 主模块可见）；标量拷贝到 S
---@param opts table { makeShip, playerFleet, enemyFleet, projectiles, floatTexts,
---                    notifyFn, onBattleEnd, rm, rs,
---                    BattleWinLose, BattleCombatPlayer, BattleCombatEnemy,
---                    BattleTimers, BattleDeath, BattleVFX, BattleContext,
---                    cmdSys,
---                    vars = { 所有标量 } }
function BattleOrchestrator.SyncIn(opts)
    makeShipFn_   = opts.makeShip
    playerFleet_  = opts.playerFleet
    enemyFleet_   = opts.enemyFleet
    projectiles_  = opts.projectiles
    floatTexts_   = opts.floatTexts
    notifyFn_     = opts.notifyFn
    onBattleEnd_  = opts.onBattleEnd
    rm_           = opts.rm
    rs_           = opts.rs

    BattleWinLose_      = opts.BattleWinLose
    BattleCombatPlayer_ = opts.BattleCombatPlayer
    BattleCombatEnemy_  = opts.BattleCombatEnemy
    BattleTimers_       = opts.BattleTimers
    BattleDeath_        = opts.BattleDeath
    BattleVFX_          = opts.BattleVFX
    BattleContext_      = opts.BattleContext
    cmdSys_             = opts.cmdSys

    -- 子模块自动调用开关（默认全开；调用方也可设置）
    autoCombat_  = opts.autoCombat  ~= false
    autoTimers_  = opts.autoTimers  ~= false
    autoDeath_   = opts.autoDeath   ~= false
    autoVFX_     = opts.autoVFX     ~= false
    autoWinLose_ = opts.autoWinLose ~= false

    local v = opts.vars or {}
    S.screenW            = v.screenW            or 800
    S.screenH            = v.screenH            or 600
    S.state              = v.state              or "fighting"
    S.stateTimer         = v.stateTimer         or 0
    S.battleEndFired     = v.battleEndFired     or false
    S.shootSfxTimer      = v.shootSfxTimer      or 0
    S.reinforceCooldown  = v.reinforceCooldown  or 0
    S.waveNum            = v.waveNum            or 1
    S.waveGapTimer       = v.waveGapTimer       or 0
    S.prepSkipped        = v.prepSkipped        or false
    S.bossDefeated       = v.bossDefeated       or false

    -- Boss 预警
    S.bossWarningActive  = v.bossWarningActive  or false
    S.bossWarningTimer   = v.bossWarningTimer   or 0
    S.bossWarningType    = v.bossWarningType
    S.bossWarningWave    = v.bossWarningWave    or 0
    S.bossFlashAlpha     = v.bossFlashAlpha     or 0
    S.bossFlashTimer     = v.bossFlashTimer     or 0
    S.bossPhaseBannerTimer = v.bossPhaseBannerTimer or 0
    S.bossPhaseBannerTotal  = v.bossPhaseBannerTotal  or 2.5
    S.bossPhaseBannerText   = v.bossPhaseBannerText

    -- 超级 Boss
    S.superBossWarning     = v.superBossWarning     or false
    S.superBossType        = v.superBossType
    S.superBossName        = v.superBossName
    S.superBossWarningTimer = v.superBossWarningTimer or 0
    S.superBossPending     = v.superBossPending     or false

    -- 里程碑
    S.milestoneFlashAlpha = v.milestoneFlashAlpha or 0
    S.milestoneBannerTimer = v.milestoneBannerTimer or 0
    S.milestoneRound      = v.milestoneRound      or 0
    S.endlessRound        = v.endlessRound        or 0

    -- 无尽模式
    S.endlessMode         = v.endlessMode
    S.endlessWave         = v.endlessWave         or 1
    S.endlessRecord       = v.endlessRecord       or 0
    S.endlessDifficulty   = v.endlessDifficulty   or 1.0
    S.endlessStartTime    = v.endlessStartTime

    -- Boss Rush
    S.bossRushMode        = v.bossRushMode        or false
    S.bossRushState       = v.bossRushState
    S.bossRushCurrent     = v.bossRushCurrent     or 1
    S.bossRushRestTimer   = v.bossRushRestTimer   or 0
    S.bossRushScore       = v.bossRushScore       or 0
    S.bossRushResult      = v.bossRushResult
    S.bossRushBosses      = v.bossRushBosses      or {}
    S.bossRushHealthBonus = v.bossRushHealthBonus or 0
    S.bossRushStartTime   = v.bossRushStartTime   or 0

    -- 其他
    S.hpBlinkTimer        = v.hpBlinkTimer        or 0
    S.interceptorEngineTimer = v.interceptorEngineTimer or 0
    S.fireTimer           = v.fireTimer           or 0
    S.fwLaunchTimer       = v.fwLaunchTimer       or 0
    S.bgScrollX           = v.bgScrollX           or 0
    S.bgScrollY           = v.bgScrollY           or 0
    S.currentWaveStar     = v.currentWaveStar     or 0
    S.starAnim            = v.starAnim            or 0
    S.initialPlayerCount  = v.initialPlayerCount  or #(playerFleet_ or {})
    S.engineerHealTimer   = v.engineerHealTimer   or 0
    S.chainCount          = v.chainCount          or 0
    S.envAnnounceAlpha    = v.envAnnounceAlpha    or 0
    S.envAnnounceTimer    = v.envAnnounceTimer    or 0
    S.envAsteroidTimer    = v.envAsteroidTimer    or 0
    S.fortressRegenTimer  = v.fortressRegenTimer  or 0
    S.pincerAnnounceTimer = v.pincerAnnounceTimer or 0
    S.pincerDefended      = v.pincerDefended      or false
    S.isPincerWave        = v.isPincerWave        or false
    S.nemesisActive       = v.nemesisActive       or false
    S.nemesisAnnounceTimer = v.nemesisAnnounceTimer or 0
    S.nemesisResult       = v.nemesisResult
    S.nemesisResultTimer  = v.nemesisResultTimer  or 0
    S.anomalyNotify       = v.anomalyNotify
    S.anomalyNotifyTimer  = v.anomalyNotifyTimer  or 0
    S.moveTarget          = v.moveTarget
    S.moveTargetTimer     = v.moveTargetTimer     or 0
    S.cmdSkillActive      = v.cmdSkillActive      or false
    S.cmdSkillTimer       = v.cmdSkillTimer       or 0
    S.cmdSkillDef         = v.cmdSkillDef
    S.commanderFleetId    = v.commanderFleetId
    S.currentFormation    = v.currentFormation    or "wedge"
    S.formationLocked     = v.formationLocked     or false
    S.focusTarget         = v.focusTarget
    S.explorerMarkTarget  = v.explorerMarkTarget
    S.skillUpgradeCards   = v.skillUpgradeCards
    S.waveSummary         = v.waveSummary
    S.waveKills           = v.waveKills           or 0
    S.waveKillTotal       = v.waveKillTotal       or 0
    S.waveMaxCombo        = v.waveMaxCombo        or 0
    S.waveDmgDealt        = v.waveDmgDealt        or 0
    S.waveShipsLost       = v.waveShipsLost       or 0
    S.comboCount          = v.comboCount          or 0
    S.comboTimer          = v.comboTimer          or 0
    S.comboDisplayTimer   = v.comboDisplayTimer   or 0
    S.paused              = v.paused              or false
    S.battleSpeed         = v.battleSpeed         or 1.0
    S.battleSpeedId       = v.battleSpeedId       or "NORMAL"
    S.autoBattleEnabled   = v.autoBattleEnabled   or false
    S.autoBattleKeyDown   = v.autoBattleKeyDown   or false
    S.commandKeyDown      = v.commandKeyDown
    S.loseBtn1            = v.loseBtn1
    S.loseBtn2            = v.loseBtn2
    S.formationBtn        = v.formationBtn        or {}
    S.retreatBtn          = v.retreatBtn
    S.reinforceBtn        = v.reinforceBtn
    S.focusHudBtn         = v.focusHudBtn
    S.skillUpgradeCardBtns = v.skillUpgradeCardBtns or {}
    S.selectedShip        = v.selectedShip
    S.pendingShips        = v.pendingShips        or {}
    S.loseTriggered       = v.loseTriggered       or false
    S.retreatUsed         = v.retreatUsed         or false
    S.SK                  = v.SK                  or { timer = 0, dur = 0, strength = 0, offX = 0, offY = 0 }
    S.RF                  = v.RF                  or { pending = false, warning = 0, spawned = false, remain = 0, defeated = false, startEnemyCnt = 0, WARN_DUR = 3, PROB = 0.15, MIN_WAVE = 5 }
    S.battleStats         = v.battleStats         or {}
    S.FORMATION_CONFIG    = v.FORMATION_CONFIG
    S.COMBO_LEVELS        = v.COMBO_LEVELS
    S.currentEnv          = v.currentEnv
    S.moduleMap           = v.moduleMap           or {}
    S.mutantMap           = v.mutantMap           or {}
    S.leagueAttackMult    = v.leagueAttackMult    or 1.0
    S.scoutAuraApplied    = v.scoutAuraApplied    or false
    S.bgStars             = v.bgStars             or {}
    S.fireParticles       = v.fireParticles       or {}
    S.explParticles       = v.explParticles       or {}
    S.hitSparks           = v.hitSparks           or {}
    S.shockRings          = v.shockRings          or {}
    S.fwParticles         = v.fwParticles         or {}
    S.envParticles        = v.envParticles        or {}
    S.waveStartTimer      = v.waveStartTimer      or 0
end

--- 获取回写表（每次 BattleScene Update 结尾调用）
---@return table 包含所有标量的浅拷贝
function BattleOrchestrator.GetOut()
    return {
        screenW               = S.screenW,
        screenH               = S.screenH,
        state                 = S.state,
        stateTimer            = S.stateTimer,
        battleEndFired        = S.battleEndFired,
        shootSfxTimer         = S.shootSfxTimer,
        reinforceCooldown     = S.reinforceCooldown,
        waveNum               = S.waveNum,
        waveGapTimer          = S.waveGapTimer,
        prepSkipped           = S.prepSkipped,
        bossDefeated          = S.bossDefeated,
        bossWarningActive     = S.bossWarningActive,
        bossWarningTimer      = S.bossWarningTimer,
        bossWarningType       = S.bossWarningType,
        bossWarningWave       = S.bossWarningWave,
        bossFlashAlpha        = S.bossFlashAlpha,
        bossFlashTimer        = S.bossFlashTimer,
        bossPhaseBannerTimer  = S.bossPhaseBannerTimer,
        bossPhaseBannerTotal  = S.bossPhaseBannerTotal,
        bossPhaseBannerText   = S.bossPhaseBannerText,
        superBossWarning      = S.superBossWarning,
        superBossType         = S.superBossType,
        superBossName         = S.superBossName,
        superBossWarningTimer = S.superBossWarningTimer,
        superBossPending      = S.superBossPending,
        milestoneFlashAlpha   = S.milestoneFlashAlpha,
        milestoneBannerTimer  = S.milestoneBannerTimer,
        milestoneRound        = S.milestoneRound,
        endlessRound          = S.endlessRound,
        endlessMode           = S.endlessMode,
        endlessWave           = S.endlessWave,
        endlessRecord         = S.endlessRecord,
        endlessDifficulty     = S.endlessDifficulty,
        endlessStartTime      = S.endlessStartTime,
        bossRushMode          = S.bossRushMode,
        bossRushState         = S.bossRushState,
        bossRushCurrent       = S.bossRushCurrent,
        bossRushRestTimer     = S.bossRushRestTimer,
        bossRushScore         = S.bossRushScore,
        bossRushResult        = S.bossRushResult,
        bossRushBosses        = S.bossRushBosses,
        bossRushHealthBonus   = S.bossRushHealthBonus,
        bossRushStartTime     = S.bossRushStartTime,
        hpBlinkTimer          = S.hpBlinkTimer,
        interceptorEngineTimer = S.interceptorEngineTimer,
        fireTimer             = S.fireTimer,
        fwLaunchTimer         = S.fwLaunchTimer,
        bgScrollX             = S.bgScrollX,
        bgScrollY             = S.bgScrollY,
        currentWaveStar       = S.currentWaveStar,
        starAnim              = S.starAnim,
        initialPlayerCount    = S.initialPlayerCount,
        engineerHealTimer     = S.engineerHealTimer,
        chainCount            = S.chainCount,
        envAnnounceAlpha      = S.envAnnounceAlpha,
        envAnnounceTimer      = S.envAnnounceTimer,
        envAsteroidTimer      = S.envAsteroidTimer,
        fortressRegenTimer    = S.fortressRegenTimer,
        pincerAnnounceTimer   = S.pincerAnnounceTimer,
        pincerDefended        = S.pincerDefended,
        isPincerWave          = S.isPincerWave,
        nemesisActive         = S.nemesisActive,
        nemesisAnnounceTimer  = S.nemesisAnnounceTimer,
        nemesisResult         = S.nemesisResult,
        nemesisResultTimer    = S.nemesisResultTimer,
        anomalyNotify         = S.anomalyNotify,
        anomalyNotifyTimer    = S.anomalyNotifyTimer,
        moveTarget            = S.moveTarget,
        moveTargetTimer       = S.moveTargetTimer,
        cmdSkillActive        = S.cmdSkillActive,
        cmdSkillTimer         = S.cmdSkillTimer,
        cmdSkillDef           = S.cmdSkillDef,
        commanderFleetId      = S.commanderFleetId,
        currentFormation      = S.currentFormation,
        formationLocked       = S.formationLocked,
        focusTarget           = S.focusTarget,
        explorerMarkTarget    = S.explorerMarkTarget,
        skillUpgradeCards     = S.skillUpgradeCards,
        waveSummary           = S.waveSummary,
        waveKills             = S.waveKills,
        waveKillTotal         = S.waveKillTotal,
        waveMaxCombo          = S.waveMaxCombo,
        waveDmgDealt          = S.waveDmgDealt,
        waveShipsLost         = S.waveShipsLost,
        comboCount            = S.comboCount,
        comboTimer            = S.comboTimer,
        comboDisplayTimer     = S.comboDisplayTimer,
        paused                = S.paused,
        battleSpeed           = S.battleSpeed,
        battleSpeedId         = S.battleSpeedId,
        autoBattleEnabled     = S.autoBattleEnabled,
        autoBattleKeyDown     = S.autoBattleKeyDown,
        commandKeyDown        = S.commandKeyDown,
        loseBtn1              = S.loseBtn1,
        loseBtn2              = S.loseBtn2,
        formationBtn          = S.formationBtn,
        retreatBtn            = S.retreatBtn,
        reinforceBtn          = S.reinforceBtn,
        focusHudBtn           = S.focusHudBtn,
        skillUpgradeCardBtns  = S.skillUpgradeCardBtns,
        selectedShip          = S.selectedShip,
        loseTriggered         = S.loseTriggered,
        retreatUsed           = S.retreatUsed,
        waveStartTimer        = S.waveStartTimer,
    }
end

-- ============================================================================
-- 内部辅助：构造 ctx（与 BattleScene.pushToCtx 语义等价）
-- ============================================================================
local function buildCtx()
    if not BattleContext_ then return {} end
    local ctx = BattleContext_
    -- 表引用：已在 BattleContext_ 内持有，这里确保能被下游子模块访问
    ctx.playerFleet   = playerFleet_
    ctx.enemyFleet    = enemyFleet_
    ctx.projectiles   = projectiles_
    ctx.floatTexts    = floatTexts_
    ctx.fireParticles = S.fireParticles
    ctx.explParticles = S.explParticles
    ctx.hitSparks     = S.hitSparks
    ctx.shockRings    = S.shockRings
    ctx.fwParticles   = S.fwParticles
    ctx.bgStars       = S.bgStars
    ctx.envParticles  = S.envParticles
    ctx.battleStats   = S.battleStats
    ctx.SK            = S.SK
    ctx.RF            = S.RF
    ctx.FORMATION_CONFIG = S.FORMATION_CONFIG
    ctx.COMBO_LEVELS  = S.COMBO_LEVELS
    ctx.currentEnv    = S.currentEnv
    ctx.rm            = rm_
    ctx.rs            = rs_
    ctx.notifyFn      = notifyFn_
    ctx.onBattleEnd   = onBattleEnd_
    ctx.WAVE_GAP               = WAVE_GAP
    ctx.BOSS_BANNER_DUR        = BOSS_BANNER_DUR
    ctx.MILESTONE_BANNER_DUR   = MILESTONE_BANNER_DUR
    ctx.BOSS_WAVE_INTERVAL     = BOSS_WAVE_INTERVAL
    ctx.BOSS_WARNING_DUR       = BOSS_WARNING_DUR
    ctx.screenW            = S.screenW
    ctx.screenH            = S.screenH
    ctx.shootSfxTimer      = S.shootSfxTimer
    ctx.reinforceCooldown  = S.reinforceCooldown
    ctx.state              = S.state
    ctx.stateTimer         = S.stateTimer
    ctx.battleEndFired     = S.battleEndFired
    ctx.waveGapTimer       = S.waveGapTimer
    ctx.prepSkipped        = S.prepSkipped
    ctx.waveNum            = S.waveNum
    ctx.bossDefeated       = S.bossDefeated
    ctx.bossWarningActive  = S.bossWarningActive
    ctx.bossWarningTimer   = S.bossWarningTimer
    ctx.bossWarningType    = S.bossWarningType
    ctx.bossWarningWave    = S.bossWarningWave
    ctx.bossWarningDuration = BOSS_WARNING_DUR
    ctx.bossFlashAlpha     = S.bossFlashAlpha
    ctx.bossFlashTimer     = S.bossFlashTimer
    ctx.bossPhaseBannerTimer = S.bossPhaseBannerTimer
    ctx.bossPhaseBannerTotal = S.bossPhaseBannerTotal
    ctx.bossPhaseBannerText  = S.bossPhaseBannerText
    ctx.milestoneFlashAlpha = S.milestoneFlashAlpha
    ctx.milestoneBannerTimer = S.milestoneBannerTimer
    ctx.milestoneRound     = S.milestoneRound
    ctx.endlessRound       = S.endlessRound
    ctx.endlessMode        = S.endlessMode
    ctx.endlessWave        = S.endlessWave
    ctx.endlessRecord      = S.endlessRecord
    ctx.endlessDifficulty  = S.endlessDifficulty
    ctx.bossRushMode       = S.bossRushMode
    ctx.bossRushState      = S.bossRushState
    ctx.bossRushCurrent    = S.bossRushCurrent
    ctx.bossRushRestTimer  = S.bossRushRestTimer
    ctx.bossRushScore      = S.bossRushScore
    ctx.bossRushResult     = S.bossRushResult
    ctx.hpBlinkTimer       = S.hpBlinkTimer
    ctx.interceptorEngineTimer = S.interceptorEngineTimer
    ctx.fireTimer          = S.fireTimer
    ctx.fwLaunchTimer      = S.fwLaunchTimer
    ctx.bgScrollX          = S.bgScrollX
    ctx.bgScrollY          = S.bgScrollY
    ctx.currentWaveStar    = S.currentWaveStar
    ctx.starAnim           = S.starAnim
    ctx.initialPlayerCount = S.initialPlayerCount
    ctx.engineerHealTimer  = S.engineerHealTimer
    ctx.chainCount         = S.chainCount
    ctx.envAnnounceAlpha   = S.envAnnounceAlpha
    ctx.envAnnounceTimer   = S.envAnnounceTimer
    ctx.envAsteroidTimer   = S.envAsteroidTimer
    ctx.fortressRegenTimer = S.fortressRegenTimer
    ctx.pincerAnnounceTimer = S.pincerAnnounceTimer
    ctx.pincerDefended     = S.pincerDefended
    ctx.isPincerWave       = S.isPincerWave
    ctx.nemesisActive      = S.nemesisActive
    ctx.nemesisAnnounceTimer = S.nemesisAnnounceTimer
    ctx.nemesisResult      = S.nemesisResult
    ctx.nemesisResultTimer = S.nemesisResultTimer
    ctx.anomalyNotify      = S.anomalyNotify
    ctx.anomalyNotifyTimer = S.anomalyNotifyTimer
    ctx.moveTarget         = S.moveTarget
    ctx.moveTargetTimer    = S.moveTargetTimer
    ctx.cmdSkillActive     = S.cmdSkillActive
    ctx.cmdSkillTimer      = S.cmdSkillTimer
    ctx.cmdSkillDef        = S.cmdSkillDef
    ctx.commanderFleetId   = S.commanderFleetId
    ctx.currentFormation   = S.currentFormation
    ctx.formationLocked    = S.formationLocked
    ctx.focusTarget        = S.focusTarget
    ctx.explorerMarkTarget = S.explorerMarkTarget
    ctx.skillUpgradeCards  = S.skillUpgradeCards
    ctx.waveSummary        = S.waveSummary
    ctx.waveKills          = S.waveKills
    ctx.waveKillTotal      = S.waveKillTotal
    ctx.waveMaxCombo       = S.waveMaxCombo
    ctx.waveDmgDealt       = S.waveDmgDealt
    ctx.waveShipsLost      = S.waveShipsLost
    ctx.comboCount         = S.comboCount
    ctx.comboTimer         = S.comboTimer
    ctx.comboDisplayTimer  = S.comboDisplayTimer
    ctx.paused             = S.paused
    ctx.battleSpeed        = S.battleSpeed
    ctx.autoBattleEnabled  = S.autoBattleEnabled
    return ctx
end

--- 将 ctx 中的标量字段反向同步回 S（子模块可能通过 ctx 修改标量）
local function pullFromCtx(ctx)
    if not ctx then return end
    local keys = {
        "screenW","screenH","shootSfxTimer","reinforceCooldown","state",
        "stateTimer","battleEndFired","waveGapTimer","prepSkipped","waveNum",
        "bossDefeated","bossWarningActive","bossWarningTimer","bossWarningType",
        "bossWarningWave","bossFlashAlpha","bossFlashTimer","bossPhaseBannerTimer",
        "bossPhaseBannerTotal","bossPhaseBannerText","milestoneFlashAlpha",
        "milestoneBannerTimer","milestoneRound","endlessRound","endlessMode",
        "endlessWave","endlessRecord","endlessDifficulty","bossRushMode",
        "bossRushState","bossRushCurrent","bossRushRestTimer","bossRushScore",
        "bossRushResult","hpBlinkTimer","interceptorEngineTimer","fireTimer",
        "fwLaunchTimer","bgScrollX","bgScrollY","currentWaveStar","starAnim",
        "initialPlayerCount","engineerHealTimer","chainCount","envAnnounceAlpha",
        "envAnnounceTimer","envAsteroidTimer","fortressRegenTimer",
        "pincerAnnounceTimer","pincerDefended","isPincerWave","nemesisActive",
        "nemesisAnnounceTimer","nemesisResult","nemesisResultTimer",
        "anomalyNotify","anomalyNotifyTimer","moveTarget","moveTargetTimer",
        "cmdSkillActive","cmdSkillTimer","cmdSkillDef","commanderFleetId",
        "currentFormation","formationLocked","focusTarget","explorerMarkTarget",
        "skillUpgradeCards","waveSummary","waveKills","waveKillTotal",
        "waveMaxCombo","waveDmgDealt","waveShipsLost","comboCount","comboTimer",
        "comboDisplayTimer","paused","battleSpeed",
    }
    for _, k in ipairs(keys) do
        if ctx[k] ~= nil then S[k] = ctx[k] end
    end
end

-- ============================================================================
-- 自动战斗 AI（与原 BattleScene.updateAutoBattle 保持一致）
-- ============================================================================
local function updateAutoBattle(dt)
    if not S.autoBattleEnabled or not playerFleet_ then return end
    local cfg = AUTO_BATTLE_DEFAULT
    for _, ship in ipairs(playerFleet_) do
        if ship.health and ship.health > 0 and not ship.isDead then
            if ship.stype == "STEALTH" and cfg.stealthWhenIdle then
                if not ship.target or ship.target.isDead then
                    ship.isStealthed = true
                else
                    ship.isStealthed = false
                end
            end
            local hpRatio = (ship.maxHealth and ship.maxHealth > 0) and (ship.health / ship.maxHealth) or 1
            if hpRatio < cfg.retreatThreshold and not ship.isRetreating then
                ship.isRetreating = true
                ship.retreatTimer = 2.0
            end
            if ship.isRetreating then
                ship.retreatTimer = ship.retreatTimer - dt
                if ship.retreatTimer <= 0 or hpRatio > 0.5 then
                    ship.isRetreating = false
                end
            end
        end
    end
end

-- ============================================================================
-- 主 Update：由 BattleScene.Update 作为主循环
-- ============================================================================

--- 主战斗循环（返回 startBoss 与 startNext 两个 boolean 供 BattleScene 做波次跳转）
---@param dt number 帧时间（未缩放）
---@return boolean startBoss, boolean startNext
function BattleOrchestrator.Update(dt)
    local ctx = buildCtx()

    -- 暂停逻辑由调用方（BattleScene.Update）前置处理；
    -- 此处不重复判断 paused，保持单一职责。

    local scaledDt = dt * S.battleSpeed

    -- 已结束状态守卫：win / lose / bossWarning 等
    local startBoss = false
    local startNext = false
    if autoWinLose_ and BattleWinLose_ and BattleWinLose_.UpdateGuard then
        local handled
        handled, startNext, startBoss = BattleWinLose_.UpdateGuard(scaledDt, ctx)
        if handled then
            pullFromCtx(ctx)
            return startBoss, startNext
        end
    end

    -- 战斗指令系统
    if cmdSys_ and cmdSys_.update then cmdSys_:update(scaledDt, ctx) end

    -- 计时器 / 环境粒子 / 连击衰减 / 增援 / 自适应音乐 / 要塞回复
    if autoTimers_ and BattleTimers_ and BattleTimers_.Update then
        BattleTimers_.Update(scaledDt, ctx, makeShipFn_)
    end
    if autoCombat_ then
        if BattleCombatPlayer_ and BattleCombatPlayer_.Update then
            BattleCombatPlayer_.Update(scaledDt, ctx)
        end
        if BattleCombatEnemy_ and BattleCombatEnemy_.Update then
            BattleCombatEnemy_.Update(scaledDt, ctx)
        end
    end
    if autoDeath_ and BattleDeath_ and BattleDeath_.Update then
        BattleDeath_.Update(scaledDt, ctx, makeShipFn_)
    end
    if autoVFX_ and BattleVFX_ and BattleVFX_.Update then
        BattleVFX_.Update(scaledDt, ctx)
    end
    if autoWinLose_ and BattleWinLose_ and BattleWinLose_.Detect then
        BattleWinLose_.Detect(scaledDt, ctx)
    end

    updateAutoBattle(scaledDt)

    pullFromCtx(ctx)
    return startBoss, startNext
end

-- ============================================================================
-- 胜负结算的薄包装（保持与原 BattleScene.onBattleEnd_ 触发一致）
-- ============================================================================

--- 手动触发战斗结束回调（由 UI 按钮或战败画面调用）
---@param result string "win" | "lose" | "retreat"
function BattleOrchestrator.TriggerBattleEnd(result)
    S.battleEndFired = true
    if onBattleEnd_ then onBattleEnd_(result) end
end

-- ============================================================================
-- 撤退 / 增援（与 BattleScene.OnClick 逻辑等价）
-- ============================================================================

--- 尝试撤退：扣除能源、设置结束标志并回调
---@return boolean ok, string|nil reason
function BattleOrchestrator.TryRetreat()
    if S.retreatUsed then return false, "已撤退" end
    local energy = (rm_ and rm_.resources and rm_.resources.energy) or 0
    if energy < RETREAT_COST_ENERGY then return false, "能源不足" end
    if rm_ and rm_.add then rm_:add("energy", -RETREAT_COST_ENERGY) end
    S.retreatUsed    = true
    S.battleEndFired = true
    if onBattleEnd_ then onBattleEnd_("retreat") end
    return true
end

--- 尝试增援：消耗资源并生成 2 艘护卫舰
---@return boolean ok, string|nil reason
function BattleOrchestrator.TryReinforce()
    if not rm_ or not rm_.resources then return false, "未就绪" end
    if (rm_.resources.metal or 0) < REINFORCE_COST_METAL   then return false, "金属不足" end
    if (rm_.resources.crystal or 0) < REINFORCE_COST_CRYSTAL then return false, "晶体不足" end
    if rm_.add then
        rm_:add("metal",   -REINFORCE_COST_METAL)
        rm_:add("crystal", -REINFORCE_COST_CRYSTAL)
    end
    if makeShipFn_ and playerFleet_ then
        for _ = 1, 2 do
            local x = 60 + math.random() * 50
            local y = S.screenH * 0.2 + math.random() * (S.screenH * 0.6)
            playerFleet_[#playerFleet_ + 1] = makeShipFn_("FRIGATE", x, y, "player")
        end
    end
    S.reinforceCooldown = 12
    return true
end

--- 获取撤退/增援的冷却与可用状态（供 HUD 渲染使用）
---@return table { canRetreat, retreatCostEnergy, canReinforce, reinforceCooldown, reinforceCost }
function BattleOrchestrator.GetRetreatReinforceStatus()
    local energy = (rm_ and rm_.resources and rm_.resources.energy) or 0
    return {
        canRetreat        = not S.retreatUsed and energy >= RETREAT_COST_ENERGY,
        retreatCostEnergy = RETREAT_COST_ENERGY,
        canReinforce      = S.reinforceCooldown <= 0 and
                            (rm_ and rm_.resources and rm_.resources.metal or 0) >= REINFORCE_COST_METAL and
                            (rm_ and rm_.resources and rm_.resources.crystal or 0) >= REINFORCE_COST_CRYSTAL,
        reinforceCooldown = S.reinforceCooldown,
        reinforceCost     = { metal = REINFORCE_COST_METAL, crystal = REINFORCE_COST_CRYSTAL },
    }
end

-- ============================================================================
-- 战斗速度 / 自动战斗（输入处理辅助）
-- ============================================================================

--- 切换战斗速度（返回新的 speed 和 speedId）
---@return number speed, string speedId
function BattleOrchestrator.NextBattleSpeed()
    local order = { 1.0, 1.5, 2.0, 3.0 }
    local names = { [1.0] = "NORMAL", [1.5] = "FAST", [2.0] = "FASTER", [3.0] = "FASTEST" }
    local cur = S.battleSpeed
    for i, v in ipairs(order) do
        if v >= cur then
            local next = order[(i % #order) + 1]
            S.battleSpeed   = next
            S.battleSpeedId = names[next]
            return next, names[next]
        end
    end
    S.battleSpeed   = 1.0
    S.battleSpeedId = "NORMAL"
    return 1.0, "NORMAL"
end

--- 直接设置战斗速度
---@param speed number
function BattleOrchestrator.SetBattleSpeed(speed)
    S.battleSpeed = speed or 1.0
    S.battleSpeedId = (S.battleSpeed == 1.0 and "NORMAL")
                   or (S.battleSpeed == 1.5 and "FAST")
                   or (S.battleSpeed == 2.0 and "FASTER")
                   or (S.battleSpeed == 3.0 and "FASTEST")
                   or "NORMAL"
end

--- 切换自动战斗
function BattleOrchestrator.ToggleAutoBattle()
    S.autoBattleEnabled = not S.autoBattleEnabled
    return S.autoBattleEnabled
end

--- 暂停切换
function BattleOrchestrator.TogglePause()
    S.paused = not S.paused
    return S.paused
end

-- ============================================================================
-- 战斗指令系统（执行/冷却/可用性查询）
-- ============================================================================

---@param commandId string
---@return boolean ok, string|nil reason
function BattleOrchestrator.ExecuteCommand(commandId)
    if not cmdSys_ then return false, "指令系统未初始化" end
    local ctx = buildCtx()
    local ok, reason = cmdSys_:execute(commandId, ctx)
    pullFromCtx(ctx)
    return ok, reason
end

---@return table
function BattleOrchestrator.GetCommandCooldowns()
    if not cmdSys_ then return {} end
    return cmdSys_:getCooldowns()
end

---@param commandId string
---@return boolean ok, string|nil reason
function BattleOrchestrator.CanUseCommand(commandId)
    if not cmdSys_ then return false, "指令系统未初始化" end
    local ctx = buildCtx()
    local ok, reason = cmdSys_:canUse(commandId, ctx)
    return ok, reason
end

-- ============================================================================
-- 无尽模式 API
-- ============================================================================

---@param mode string "CLASSIC" | "SURVIVAL" | "SPEEDRUN"
function BattleOrchestrator.StartEndlessMode(mode)
    local m = ENDLESS_MODES_DEFAULT[mode] and mode or "CLASSIC"
    S.endlessMode = m
    S.endlessWave = ENDLESS_MODES_DEFAULT[m].startWave or 1
    S.endlessDifficulty = 1.0
    if m == "SPEEDRUN" then S.endlessStartTime = os.time() end
    print("[BattleOrchestrator] 开始无尽模式: " .. m .. " 从波次 " .. S.endlessWave .. " 开始")
end

---@return table
function BattleOrchestrator.GetEndlessState()
    return {
        mode       = S.endlessMode,
        wave       = S.endlessWave,
        record     = S.endlessRecord,
        difficulty = S.endlessDifficulty,
    }
end

function BattleOrchestrator.IsEndlessMode() return S.endlessMode ~= nil end

-- ============================================================================
-- Boss Rush API
-- ============================================================================

---@param bossCount number|nil
function BattleOrchestrator.StartBossRush(bossCount)
    bossCount = bossCount or 5
    S.bossRushMode = true
    S.bossRushBosses = {}
    S.bossRushCurrent = 1
    S.bossRushScore = 0
    S.bossRushStartTime = os.time()
    S.bossRushHealthBonus = 0
    local allBosses = BOSS_RUSH_DEFAULT.bosses
    if #allBosses == 0 then
        allBosses = {
            { id = "BATTLECRUISER", name = "战列巡洋舰", healthMult = 1.0, phaseCount = 1 },
            { id = "CARRIER",       name = "母舰",         healthMult = 1.2, phaseCount = 1 },
        }
    end
    for i = 1, bossCount do
        local idx = math.random(#allBosses)
        local boss = allBosses[idx]
        local difficultyMult = 1.0 + (i - 1) * 0.15
        S.bossRushBosses[#S.bossRushBosses + 1] = {
            id = boss.id,
            name = boss.name,
            healthMult = boss.healthMult * difficultyMult,
            phaseCount = boss.phaseCount,
            isSuper = boss.isSuper,
            defeated = false,
        }
    end
    S.bossRushState = "intro"
    S.waveNum = 1
    S.state = "fighting"
    S.stateTimer = 0
    S.battleEndFired = false
    print("[BattleOrchestrator] 开始 Boss Rush: " .. bossCount .. " 个 Boss")
    return true
end

function BattleOrchestrator.GetBossRushState()
    return {
        mode      = S.bossRushMode,
        current   = S.bossRushCurrent,
        total     = #S.bossRushBosses,
        state     = S.bossRushState,
        restTimer = S.bossRushRestTimer,
        score     = S.bossRushScore,
        result    = S.bossRushResult,
    }
end

function BattleOrchestrator.IsBossRushMode() return S.bossRushMode end

return BattleOrchestrator
