-- ============================================================================
-- game/battle/BattleState.lua
-- 战斗场景共享状态表（BattleScene ↔ BattleRender 共享读取）
-- BattleScene 每帧写入，BattleRender 只读引用
-- ============================================================================

---@class BattleState
local BS = {
    -- NanoVG 上下文 & 屏幕尺寸
    vg       = nil,   ---@type userdata
    screenW  = 800,
    screenH  = 600,

    -- 舰队 & 投射物
    playerFleet = {},   ---@type table[]
    enemyFleet  = {},   ---@type table[]
    projectiles = {},   ---@type table[]
    floatTexts  = {},   ---@type table[]

    -- 粒子系统
    fireParticles = {},
    explParticles = {},
    hitSparks     = {},
    shockRings    = {},
    fwParticles   = {},

    -- 状态
    state      = "fighting",
    stateTimer = 0,
    waveNum    = 1,

    -- 屏幕震动
    SK = { timer = 0, dur = 0, strength = 0, offX = 0, offY = 0 },

    -- Boss
    bossWarningActive     = false, -- P1-6: Boss 预警阶段激活
    bossWarningTimer      = 0,     -- P1-6: Boss 预警倒计时（秒）
    bossWarningType       = nil,   -- P1-6: 预警的 Boss 类型（BATTLECRUISER/CARRIER/VOID_LORD）
    bossWarningWave       = 0,     -- P1-6: 预警的 Boss 波次编号
    bossWarningDuration   = 10,    -- P1-6: 预警阶段总时长
    bossFlashAlpha        = 0,
    bossFlashTimer        = 0,
    bossDefeated          = false,
    bossPhaseBannerTimer  = 0,    -- P0-3: Boss 阶段转换横幅倒计时
    bossPhaseBannerTotal  = 2.5,  -- P0-3: Boss 阶段转换横幅总时长
    bossPhaseBannerText   = nil,  -- P0-3: Boss 阶段转换横幅文字
    BOSS_WAVE_INTERVAL    = 5,
    BOSS_WARNING_DUR      = 2.5,
    BOSS_BANNER_DUR       = 2.5,

    -- 连击
    comboCount        = 0,
    comboTimer        = 0,
    comboDisplayTimer = 0,
    COMBO_LEVELS      = nil,  -- 引用 COMBO_LEVELS 表
    COMBO_RESET_TIME  = 5.0,

    -- 波次信息
    waveGapTimer     = 0,
    prepSkipped      = false,
    WAVE_GAP         = 8.0,

    -- 背景 & 环境
    bgStars       = {},
    bgScrollX     = 0,
    bgScrollY     = 0,
    currentEnv    = nil,   ---@type table
    envParticles  = {},
    envAnnounceAlpha = 0,
    envAnnounceTimer = 0,
    ENV_ANNOUNCE_DUR = 2.0,

    -- 移动目标
    moveTarget      = nil,
    moveTargetTimer = 0,

    -- 船图像
    shipImages = {},

    -- 选中 & 集火
    selectedShip = nil,
    focusTarget  = nil,
    focusHudBtn  = nil,

    -- 阵型
    currentFormation = "wedge",
    formationBtn     = {},
    formationLocked  = false,
    FORMATION_CONFIG = nil,  -- 引用

    -- 撤退/增援 UI
    retreatUsed       = false,
    retreatBtn        = nil,
    reinforceBtn      = nil,
    reinforceCooldown = 0,
    REINFORCE_COST_METAL   = 50,
    REINFORCE_COST_CRYSTAL = 50,
    RETREAT_COST_ENERGY    = 30,

    -- 技能升级
    skillUpgradeCards    = nil,
    skillUpgradeCardBtns = {},

    -- 宿敌
    nemesisActive         = false,
    nemesisAnnounceTimer  = 0,
    NEMESIS_ANNOUNCE_DUR  = 3.5,
    nemesisResult         = nil,
    nemesisResultTimer    = 0,
    NEMESIS_RESULT_DUR    = 4.0,

    -- 夹击
    isPincerWave        = false,
    pincerAnnounceTimer = 0,
    PINCER_ANNOUNCE_DUR = 2.2,

    -- 异象
    anomalyNotify      = nil,
    anomalyNotifyTimer = 0,
    ANOMALY_NOTIFY_DUR = 3.5,

    -- 增援 RF
    RF = nil,  -- 引用 RF_ 表

    -- 无尽/里程碑
    endlessRound           = 0,
    milestoneFlashAlpha    = 0,
    milestoneBannerTimer   = 0,
    MILESTONE_BANNER_DUR   = 4.0,
    milestoneRound         = 0,

    -- 波次摘要
    waveSummary    = nil,
    WAVE_SUMMARY_DUR = 2.8,

    -- 星级评分
    currentWaveStar = 0,
    starAnim        = 0,

    -- 血条闪烁
    hpBlinkTimer = 0,

    -- 战斗统计
    battleStats = nil,
    initialPlayerCount = 0,  -- 本波开始时我方舰队数量

    -- 战败按钮
    loseBtn1 = nil,
    loseBtn2 = nil,

    -- 被动技能
    explorerMarkTarget = nil,

    -- 涂装
    LiverySystem = nil,

    -- 战斗技能模块引用
    BattleSkills = nil,

    -- 资源管理器引用（供增援按钮判断）
    rm = nil,

    -- 技能系统引用（供 BattleSkills.Draw 调用）
    rs = nil,

    -- 回调/工具
    notifyFn = nil,

    -- 辅助函数引用（BattleScene 写入，BattleRender 调用）
    getComboLevel      = nil,  ---@type fun():table|nil
    getNextWavePreview = nil,  ---@type fun(wave:number):table

    -- 舰型配置引用
    SHIP_TYPES = nil,  -- 引用 Systems.SHIP_TYPES

    -- NemesisSystem / AnomalySystem 模块引用
    NemesisSystem = nil,
    AnomalySystem = nil,
}

return BS
