------------------------------------------------------------
-- battle/BattleContext.lua
-- 战场共享状态上下文 —— 集中所有可变状态为单一 table
-- 各子模块通过 ctx = BattleContext 访问/修改字段
------------------------------------------------------------

local BattleContext = {}

--- 初始化所有战场状态字段为默认值
function BattleContext.Reset()
    local ctx = BattleContext

    -- 渲染上下文
    ctx.vg      = nil
    ctx.screenW = 0
    ctx.screenH = 0

    -- 舰队与弹道
    ctx.playerFleet = {}
    ctx.enemyFleet  = {}
    ctx.projectiles = {}
    ctx.floatTexts  = {}

    -- 移动指令
    ctx.moveTarget      = nil
    ctx.moveTargetTimer = 0

    -- 联赛加成
    ctx.leagueAttackMult = 1.0

    -- 状态机
    ctx.state          = "init"   -- init / fighting / win / lose
    ctx.stateTimer     = 0
    ctx.battleEndFired = false

    -- 射击音效节流
    ctx.shootSfxTimer = 0

    -- 战败按钮区域
    ctx.loseBtn1 = nil
    ctx.loseBtn2 = nil

    -- 波次与星级
    ctx.initialPlayerCount = 0
    ctx.currentWaveStar    = 0
    ctx.starAnim           = 0

    -- 外部回调/引用
    ctx.notifyFn    = nil
    ctx.onBattleEnd = nil
    ctx.player      = nil
    ctx.rm          = nil   -- ResourceManager
    ctx.rs          = nil   -- ResourceSystem
    ctx.spq         = nil   -- ShipProductionQueue

    -- 指挥官系统
    ctx.commanderBonus   = nil
    ctx.commanderFleetId = nil
    ctx.cmdSkillActive   = false
    ctx.cmdSkillTimer    = 0
    ctx.cmdSkillDef      = nil

    -- 波次管理
    ctx.waveNum       = 0
    ctx.WAVE_GAP      = 5.0
    ctx.waveGapTimer  = 0
    ctx.prepSkipped   = false

    -- Boss
    ctx.BOSS_WAVE_INTERVAL = 5
    ctx.bossWarningActive  = false  -- P1-6: Boss 预警阶段激活
    ctx.bossWarningTimer   = 0
    ctx.bossWarningType    = nil    -- P1-6: "BATTLECRUISER" | "CARRIER" | "VOID_LORD"
    ctx.bossWarningWave    = 0      -- P1-6: 预警的 Boss 波次号
    ctx.bossWarningDuration = 10    -- P1-6: 预警阶段总时长
    ctx.BOSS_WARNING_DUR   = 2.5
    ctx.bossDefeated       = false

    -- 待产舰船
    ctx.pendingShips = {}

    -- 粒子系统
    ctx.fireParticles = {}
    ctx.fireTimer     = 0
    ctx.explParticles = {}
    ctx.hitSparks     = {}
    ctx.shockRings    = {}

    -- 屏幕震动
    ctx.SK = { timer = 0, dur = 0, strength = 0, offX = 0, offY = 0 }

    -- 烟花
    ctx.fwParticles   = {}
    ctx.fwLaunchTimer = 0

    -- 拦截舰引擎音效
    ctx.interceptorEngineTimer = 0

    -- Boss 闪光/横幅
    ctx.bossFlashAlpha = 0
    ctx.bossFlashTimer = 0
    ctx.BOSS_BANNER_DUR = 2.0

    -- 无尽模式 / 里程碑
    ctx.endlessRound          = 0
    ctx.milestoneFlashAlpha   = 0
    ctx.milestoneBannerTimer  = 0
    ctx.MILESTONE_BANNER_DUR  = 3.0
    ctx.milestoneRound        = 0

    -- 血量闪烁
    ctx.hpBlinkTimer = 0

    -- 撤退/增援
    ctx.retreatUsed        = false
    ctx.retreatBtn         = nil
    ctx.reinforceBtn       = nil
    ctx.reinforceCooldown  = 0
    ctx.REINFORCE_COST_METAL   = 200
    ctx.REINFORCE_COST_CRYSTAL = 100
    ctx.RETREAT_COST_ENERGY    = 50

    -- 技能升级
    ctx.skillUpgradeCards    = nil
    ctx.skillUpgradeCardBtns = {}

    -- 夹击波次
    ctx.isPincerWave       = false
    ctx.pincerDefended     = false
    ctx.pincerAnnounceTimer = 0
    ctx.PINCER_ANNOUNCE_DUR = 2.5

    -- 宿敌系统
    ctx.nemesisActive        = false
    ctx.nemesisAnnounceTimer = 0
    ctx.NEMESIS_ANNOUNCE_DUR = 3.0
    ctx.nemesisResult        = nil
    ctx.nemesisResultTimer   = 0
    ctx.NEMESIS_RESULT_DUR   = 4.0

    -- 异常通知
    ctx.anomalyNotify      = nil
    ctx.anomalyNotifyTimer = 0
    ctx.ANOMALY_NOTIFY_DUR = 3.0

    -- 增援系统
    ctx.RF = {
        pending = false, warning = false, spawned = false,
        remain = 0, defeated = false, startEnemyCnt = 0,
        WARN_DUR = 3.0, PROB = 0.25, MIN_WAVE = 3,
    }

    -- 被动舰型
    ctx.scoutAuraApplied     = false
    ctx.engineerHealTimer    = 0
    ctx.ENGINEER_HEAL_INTERVAL = 3.0
    ctx.ENGINEER_HEAL_AMOUNT   = 20
    ctx.explorerMarkTarget   = nil
    ctx.DESTROYER_PIERCE_COUNT = 2
    ctx.INTERCEPTOR_SPD_MULT   = 1.6
    ctx.FRIGATE_SHARE_RATIO    = 0.15
    ctx.BATTLECRUISER_BLOCK    = 0.25
    ctx.CARRIER_FIGHTER_LIFE   = 10.0

    -- 模块/变异映射
    ctx.moduleMap = {}
    ctx.mutantMap = {}

    -- 背景星空
    ctx.bgStars   = {}
    ctx.bgScrollX = 0
    ctx.bgScrollY = 0
    ctx.BG_SCROLL_VX = -8
    ctx.BG_SCROLL_VY = -3

    -- 战场环境
    ctx.BATTLE_ENVIRONMENTS = nil  -- 由 Init 填充
    ctx.ENV_POOL        = nil
    ctx.currentEnv      = nil
    ctx.envParticles    = {}
    ctx.envTimer        = 0
    ctx.envAsteroidTimer = 0
    ctx.envAnnounceAlpha = 0
    ctx.envAnnounceTimer = 0
    ctx.ENV_ANNOUNCE_DUR = 2.5

    -- 要塞
    ctx.fortressRegenTimer = 0

    -- 波次统计
    ctx.waveKills     = 0
    ctx.waveMaxCombo  = 0
    ctx.waveDmgDealt  = 0
    ctx.waveShipsLost = 0
    ctx.waveSummary   = nil
    ctx.waveEnemyTotal = 0
    ctx.waveKillTotal  = 0
    ctx.WAVE_SUMMARY_DUR = 4.0

    -- 选中/集火
    ctx.selectedShip = nil
    ctx.focusTarget  = nil
    ctx.focusHudBtn  = nil

    -- 连锁反应
    ctx.chainCount      = 0
    ctx.CHAIN_RADIUS    = 80
    ctx.CHAIN_AOE_PCT   = 0.15
    ctx.CHAIN_MIN_KILLS = 3

    -- 阵型
    ctx.currentFormation = "default"
    ctx.formationBtn     = {}
    ctx.formationLocked  = false
    ctx.FORMATION_CONFIG = nil  -- 由 Init 填充

    -- 连击系统
    ctx.COMBO_RESET_TIME = 5.0
    ctx.COMBO_LEVELS     = nil  -- 由 Init 填充
    ctx.comboCount       = 0
    ctx.comboTimer       = 0
    ctx.comboDisplayTimer = 0

    -- 战斗统计
    ctx.battleStats = {
        dmgDealt       = 0,
        dmgTaken       = 0,
        enemiesKilled  = 0,
        wavesCleared   = 0,
        shipsLost      = 0,
        overkillMax    = 0,
        focusBossKill  = false,
        focusKillCount = 0,
        maxCombo       = 0,
        chainCount     = 0,
        reinforceWin   = false,
        bestSurvivor   = nil,
    }
    ctx.BATTLE_LOG_MAX = 50
    ctx.battleLog      = {}
    ctx.fleetName      = "我方舰队"

    -- 舰船图像
    ctx.shipImages = {}
end

return BattleContext
