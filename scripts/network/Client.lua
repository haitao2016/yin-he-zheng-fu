-- ============================================================================
-- network/Client.lua  -- 银河征服 客户端
-- ============================================================================

local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local PirateAI    = require("game.PirateAI")

local GameUI      = require("game.GameUI")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local UICommon    = require("game.ui.UICommon")
local ClientMenus = require("network.ClientMenus")

local Client = {}

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_           = nil
local screenW_      = 800
local screenH_      = 600
local uiScale_      = 1.0   -- nvgScale 缩放比，由 getScreenSize() 每帧更新

-- ============================================================================
-- 游戏时间限制
-- ============================================================================
local BASE_LIMIT      = 7200   -- 基础时长：2小时（秒）
local EXTRA_PER_AD    = 3600   -- 每次看广告增加：1小时（秒）
local MAX_EXTRA       = 7200   -- 最多可增加：2小时（秒）

local playTime_       = 0      -- 已游玩总时长（秒）
local lastDt_         = 0.016  -- 上一帧 dt（传给 RenderHUD 驱动动画）
local extraTime_      = 0      -- 通过广告获得的额外时长（秒）
local timeoutTriggered_ = false  -- 是否已触发超时流程
local adWatching_     = false  -- 是否正在播放广告（防止重复点击）

-- 剩余可看广告次数（最多 MAX_EXTRA / EXTRA_PER_AD = 2 次）
local function getAdCount()
    return math.floor((MAX_EXTRA - extraTime_) / EXTRA_PER_AD)
end

-- 剩余游玩时间（秒）
local function getRemainingTime()
    return math.max(0, BASE_LIMIT + extraTime_ - playTime_)
end

local currentScene_   = "galaxy"
local refreshTimer_   = 0
local selectedPlanet_ = nil
local lastShownRemaining_ = -1   -- 上次传给 UI 的整秒值，相同时跳过调用

-- 游戏系统实例
local rm_      = Sys.ResourceManager.new()
local bs_      = Sys.BuildingSystem.new(rm_)       -- 行星建造系统
local bbs_     = Sys.BaseBuildingSystem.new(rm_)   -- 基地建造系统（独立）
local rs_      = Sys.ResearchSystem.new(rm_, bs_)
local ms_      = Sys.MarketSystem.new(rm_)
local player_  = Sys.PlayerProfile.new()
local spq_     = Sys.ShipProductionQueue.new(rm_)
local fm_      = Sys.FleetManager.new()
local activeFleetId_       = 1
local explorerColonizeMode_ = false   -- true 时点击未殖民星球将自动使用储备探索舰殖民
-- P1-1: 中立势力外交系统实例（setupSceneAndUI 后初始化）
---@type table
local ds_      = nil

-- 基地模块效果脏标记（true=需要重算，避免每帧全量重算）
local baseEffectsDirty_ = true

-- 海盗 AI 实例（Init 时创建）
---@type table
local pirateAI_ = nil
-- 当前海盗进攻信息（nil=非海盗战斗）
local pirateAttackInfo_ = nil  -- { pirateLevel, baseId, targetName }
local pirateWarnPlayed_ = false  -- 海盗预警音效触发标记（避免每帧重复播放）

-- 结算状态
local endGameTriggered_ = false   -- 防止重复触发结算
local piratesKilled_    = 0       -- 累计击败海盗次数（战斗胜利计数）
-- 广告奖励：下一局资源加成
local adBonusNext_    = false  -- true=下局开始时给予资源加成
local adBonusApplied_ = false  -- 本局已应用加成（用于给玩家显示提示）
-- 奖励数值
local AD_BONUS = { metal=300, esource=150, nuclear=80 }
-- 前向声明（被提前引用的局部函数）
local checkStageGoals
local battleStatsCache_ = {}      -- 战斗统计缓存（在 onBattleEnd 时快照，供 triggerEndGame 读取）
local totalResearch_    = 0       -- 累计完成科技数（成就用）
-- P2-3: 隐藏成就追踪统计
local hiddenStats_ = {
    totalShipsLostCampaign = 0,  -- 整局累计损失舰船数（战役级别）
    focusKills             = 0,  -- 集火击杀数
    focusBossKill          = false, -- 是否集火击杀过 BOSS
    totalCardsChosen       = 0,  -- 无尽模式累计选卡数
    totalExplored          = 0,  -- 累计完成探索任务数
    exploreTypesFound      = {}, -- 已触发的探索事件类型集合（set）
}

-- P3-3: 动态难度调整（DDA）——仅在非 custom 难度下生效
local dda_ = {
    enabled       = true,     -- custom 难度时设为 false
    baseFactor    = 1.0,      -- 所选难度的基准 attackIntervalFactor（setupSceneAndUI 时写入）
    currentFactor = 1.0,      -- 当前动态倍率（实时作用于 pirateAI_）
    recentResults = {},       -- 最近 MAX_HISTORY 次战斗记录：{win=bool, lossRatio=number}
    MAX_HISTORY   = 5,        -- 滚动窗口长度
    evalTimer     = 0,        -- 定期轻微调整计时器
    EVAL_INTERVAL = 90,       -- 每 90s 基于基地 HP 做一次微调
    adjustCount   = 0,        -- 本局累计调整次数（通知节流：每隔 2 次才提示）
    -- 调整幅度与边界（相对 baseFactor 的倍率范围）
    STEP_BATTLE   = 0.10,     -- 战斗后每次调整步长
    STEP_PERIODIC = 0.04,     -- 定期微调步长
    MIN_MULT      = 0.60,     -- 最难上限：baseFactor × 0.60（进攻更频繁）
    MAX_MULT      = 1.55,     -- 最松上限：baseFactor × 1.55（进攻更缓慢）
}

-- P2-1: 生涯战绩（跨局持久化，存入 galaxy_career.json 独立文件）
local careerStats_ = {
    totalGames    = 0,
    totalWins     = 0,
    bestWave      = 0,
    totalKills    = 0,
    totalColonies = 0,
    bestMvpShip   = "",
    playtime      = 0,
}

-- 成就跨局持久化（softReset 时保存，setupSceneAndUI 时恢复）
local savedAchievements_ = nil   ---@type string[]|nil
local savedRedeemed_     = nil   ---@type string[]|nil  P2-3: 已兑换奖励跨局保留

-- 主菜单
local mainMenuActive_   = true    -- true=显示主菜单
local hasSave_          = false   -- 是否有本地存档
local mainMenuHover_    = nil     -- 当前悬停按钮 "new"|"continue"|nil
local skipSaveLoad_     = false   -- true=新游戏（跳过读档）

-- 难度选择
local difficultyChosen_ = false   -- false=正在显示难度选择屏幕
local menuT_            = 0       -- P3-3: 菜单界面累计时间（驱动粒子背景）
local difficulty_       = "normal"
local diffHoverBtn_     = nil     -- 当前悬停的难度按钮 key
-- P1-1: 玩家昵称
local playerName_         = "指挥官"  -- 玩家昵称（默认"指挥官"）
local nicknameInputActive_ = false    -- 昵称输入框是否处于激活（聚焦）状态
local nicknameCursorT_     = 0        -- 光标闪烁计时器
-- P2-3: 局内统计面板
local statsOpen_           = false    -- Tab 键切换开/关
local statsMouseX_         = 0        -- 鼠标 X（用于面板内热区）
local statsMouseY_         = 0        -- 鼠标 Y
-- P1-2: 自定义难度模式状态
local customDiff_ = {
    attackFactor = 1.0,   -- 进攻间隔倍率：0.5(快)~2.5(慢)，默认1.0=普通
    initResBonus = 0,     -- 初始资源加成：-500~+1000
    maxThreat    = 5,     -- 最大威胁等级：1~8
}
local customDiffSlider_  = nil   -- 当前拖拽中的滑块名 ("attackFactor"|"initResBonus"|"maxThreat")
local customDiffSliderX0_ = 0    -- 拖拽时滑块轨道左端 X（用于计算值映射）
local customDiffSliderW_  = 0    -- 拖拽时滑块轨道宽度

-- 无尽征服模式
local isEndlessMode_    = false   -- 是否处于无尽模式（无时限，海盗基地摧毁后重生）
local endlessRound_     = 0       -- 当前无尽模式轮次（每轮 +1，难度递增）
-- P2-1 V2.0: 连胜计数（连续≥80%全消3轮触发资源×1.5）
local endlessStreak_    = 0       -- 当前连胜轮数
local endlessStreakBuff_= false   -- 本轮是否激活连胜资源加成
-- P2-1: 累积卡牌加成（叠加应用到 baseBonus 的额外倍率/数值）
local endlessCardBonuses_ = {
    shipDmgMult    = 0,  -- 攻击力加成（相加后 ×1 补正到 baseBonus）
    shipHealthMult = 0,  -- 生命值加成
    aoeRadiusMult  = 0,  -- AOE 半径加成
    miningRateMult = 0,  -- 矿产速率加成
    energyRateMult = 0,  -- 能源速率加成
    nuclearRateMult= 0,  -- 核能速率加成
    nuclearCapBonus= 0,  -- 核能上限额外值
    shipyardSpeedMult=0, -- 造舰速度加成
    fleetCapBonus  = 0,  -- 编队数量额外值
    waveRepairPct  = 0,  -- 每波开始维修比例
    explorerDurMult= 0,  -- 探索任务时长倍率（负值=缩短）
    intelRateMult  = 0,  -- 情报速率加成
}

-- EXPLORER 舰探索任务系统
-- task = { id, label, targetName, duration, elapsed, reward, done }
local explorerTasks_    = {}      -- 当前进行中或已完成待领取的任务列表
local explorerTaskSeq_  = 0       -- 任务 ID 序号
local MAX_EXPLORER_TASKS = 3      -- 同时最多派遣数

-- 探索任务模板（完成时随机选一种）
local EXPLORER_TASK_TEMPLATES = {
    { label="扫描异常信号",  minDur=30, maxDur=45,
      rewards={ {res="minerals",amt=300}, {res="esource",amt=200} },
      expGain=60,  icon="📡", eventType="scan" },
    { label="探测矿脉地层",  minDur=40, maxDur=60,
      rewards={ {res="minerals",amt=500}, {res="crystal",amt=80} },
      expGain=80,  icon="⛏", eventType="mining" },
    { label="回收遗落飞船",  minDur=25, maxDur=40,
      rewards={ {res="esource",amt=350} },
      expGain=50,  icon="🛸", eventType="salvage" },
    { label="侦察海盗据点",  minDur=35, maxDur=50,
      rewards={ {res="credits",amt=150} },
      expGain=100, icon="🔍", pirateIntel=true, eventType="intel" },
    { label="测绘深空星云",  minDur=50, maxDur=75,
      rewards={ {res="nuclear",amt=120}, {res="crystal",amt=60} },
      expGain=120, icon="🌌", eventType="survey" },
    { label="捕获宇宙物质",  minDur=20, maxDur=35,
      rewards={ {res="esource",amt=200}, {res="minerals",amt=150} },
      expGain=40,  icon="✨" },
    -- P1-3: 扩展至 20 条
    { label="破译古代信标",  minDur=60, maxDur=90,
      rewards={ {res="credits",amt=400}, {res="crystal",amt=100} },
      expGain=150, icon="📜" },
    { label="援救漂流舱",    minDur=15, maxDur=25,
      rewards={ {res="minerals",amt=200}, {res="esource",amt=100} },
      expGain=30,  icon="🆘" },
    { label="测试新型推进器", minDur=45, maxDur=65,
      rewards={ {res="nuclear",amt=200}, {res="credits",amt=100} },
      expGain=90,  icon="🚀" },
    { label="追踪中子脉冲",  minDur=55, maxDur=80,
      rewards={ {res="nuclear",amt=150}, {res="esource",amt=150} },
      expGain=110, icon="⚡" },
    { label="采集暗物质云",  minDur=70, maxDur=100,
      rewards={ {res="crystal",amt=200}, {res="esource",amt=300} },
      expGain=180, icon="🌀" },
    { label="勘察宜居行星",  minDur=40, maxDur=60,
      rewards={ {res="minerals",amt=400}, {res="credits",amt=200} },
      expGain=100, icon="🌍" },
    { label="清除太空碎片",  minDur=20, maxDur=30,
      rewards={ {res="minerals",amt=250}, {res="credits",amt=80} },
      expGain=45,  icon="🗑" },
    { label="监听通讯频道",  minDur=30, maxDur=45,
      rewards={ {res="credits",amt=250} },
      expGain=80,  icon="📻", pirateIntel=true },
    { label="修复中继卫星",  minDur=35, maxDur=55,
      rewards={ {res="esource",amt=300}, {res="credits",amt=150} },
      expGain=90,  icon="🛰" },
    { label="猎杀游荡无人机", minDur=25, maxDur=40,
      rewards={ {res="nuclear",amt=80},  {res="credits",amt=180} },
      expGain=70,  icon="🤖" },
    { label="提取恒星风能",  minDur=50, maxDur=70,
      rewards={ {res="esource",amt=450} },
      expGain=120, icon="☀" },
    { label="解析虫洞坐标",  minDur=75, maxDur=110,
      rewards={ {res="crystal",amt=150}, {res="nuclear",amt=180}, {res="credits",amt=300} },
      expGain=200, icon="🕳" },
    { label="回传量子探测数据", minDur=65, maxDur=90,
      rewards={ {res="esource",amt=250}, {res="crystal",amt=80} },
      expGain=140, icon="🔭" },
    { label="突袭补给卫星",  minDur=30, maxDur=50,
      rewards={ {res="minerals",amt=600}, {res="nuclear",amt=100} },
      expGain=110, icon="💥", pirateIntel=true },
}

-- ============================================================================
-- P2-1: 无尽模式强化卡牌池（15张，每轮随机抽3张供选择）
-- rarity: "common"|"rare"|"epic"
-- effect: 注入到 rm_.baseBonus 的字段变更表
-- ============================================================================
local ENDLESS_CARD_POOL = {
    -- 战斗类（6张）
    { key="dmg_up_sm",    rarity="common", icon="⚔",  label="火力强化 I",
      desc="舰队攻击力+15%",
      effect={ shipDmgMult=0.15 } },
    { key="dmg_up_lg",    rarity="rare",   icon="⚔",  label="火力强化 II",
      desc="舰队攻击力+30%，击杀时有10%概率双倍伤害",
      effect={ shipDmgMult=0.30 } },
    { key="hp_up_sm",     rarity="common", icon="🛡",  label="装甲加固 I",
      desc="所有舰船生命值+20%",
      effect={ shipHealthMult=0.20 } },
    { key="hp_up_lg",     rarity="rare",   icon="🛡",  label="装甲加固 II",
      desc="所有舰船生命值+40%，旗舰额外+10%",
      effect={ shipHealthMult=0.40 } },
    { key="aoe_up",       rarity="rare",   icon="💥",  label="爆破扩散",
      desc="AOE武器爆炸范围+40%",
      effect={ aoeRadiusMult=0.40 } },
    { key="double_edge",  rarity="epic",   icon="⚡",  label="双刃战术",
      desc="攻击力+50%，舰船生命值-15%，高风险高回报",
      effect={ shipDmgMult=0.50, shipHealthMult=-0.15 } },

    -- 生产类（5张）
    { key="prod_metal",   rarity="common", icon="⛏",  label="矿脉开采协议",
      desc="矿产采集速率+25%",
      effect={ miningRateMult=0.25 } },
    { key="prod_energy",  rarity="common", icon="⚡",  label="能源超频",
      desc="能源生产速率+25%",
      effect={ energyRateMult=0.25 } },
    { key="prod_nuclear", rarity="rare",   icon="☢",  label="核融合炉",
      desc="核能生产速率+40%，储量上限+200",
      effect={ nuclearRateMult=0.40, nuclearCapBonus=200 } },
    { key="prod_all",     rarity="epic",   icon="🌟",  label="全面增产",
      desc="所有资源生产速率+20%",
      effect={ miningRateMult=0.20, energyRateMult=0.20, nuclearRateMult=0.20 } },
    { key="shipyard_up",  rarity="rare",   icon="🚢",  label="快速造舰",
      desc="造舰速度+35%",
      effect={ shipyardSpeedMult=0.35 } },

    -- 战略类（4张）
    { key="fleet_cap",    rarity="rare",   icon="🛸",  label="编队扩编",
      desc="最大编队数量+2",
      effect={ fleetCapBonus=2 } },
    { key="repair_field", rarity="common", icon="🔧",  label="战场维修",
      desc="战斗中舰船每波开始前恢复15%生命值",
      effect={ waveRepairPct=0.15 } },
    { key="intel_net",    rarity="common", icon="📡",  label="情报网络",
      desc="海盗基地情报获取速度+50%，探索任务时长-20%",
      effect={ explorerDurMult=-0.20, intelRateMult=0.50 } },
    { key="quantum_leap", rarity="epic",   icon="🌀",  label="量子跃迁",
      desc="所有生产+30%，攻击+20%，生命值+20%，史诗级全面强化",
      effect={ miningRateMult=0.30, energyRateMult=0.30, nuclearRateMult=0.30,
               shipDmgMult=0.20, shipHealthMult=0.20 } },

    -- P2-1 V2.0: 15张史诗扩展卡（橙色边框，5轮起必保一张）────────────────
    -- 战斗史诗（5张）
    { key="void_blade",    rarity="epic", icon="🌑", label="虚空刃",
      desc="攻击力+60%，但舰船HP-20%；极限输出流核心",
      effect={ shipDmgMult=0.60, shipHealthMult=-0.20 } },
    { key="titan_shield",  rarity="epic", icon="🛡", label="泰坦护盾",
      desc="舰船HP+60%，每波维修+10%，铁壁防守必备",
      effect={ shipHealthMult=0.60, waveRepairPct=0.10 } },
    { key="chain_reaction",rarity="epic", icon="⚛", label="链式反应",
      desc="AOE+60%，攻击+25%，核能产率+20%，爆炸覆盖极广",
      effect={ aoeRadiusMult=0.60, shipDmgMult=0.25, nuclearRateMult=0.20 } },
    { key="berserker",     rarity="epic", icon="🔥", label="狂战士",
      desc="攻击+80%，HP-30%，造舰速度+40%，疯狂进攻流",
      effect={ shipDmgMult=0.80, shipHealthMult=-0.30, shipyardSpeedMult=0.40 } },
    { key="phoenix_fire",  rarity="epic", icon="🦅", label="浴火凤凰",
      desc="每波维修+25%，攻击+30%，生命+30%，涅槃重生",
      effect={ waveRepairPct=0.25, shipDmgMult=0.30, shipHealthMult=0.30 } },
    -- 生产史诗（4张）
    { key="dyson_ring",    rarity="epic", icon="☀", label="戴森环",
      desc="能源产率+80%，核能储量+400，能源帝国核心",
      effect={ energyRateMult=0.80, nuclearCapBonus=400 } },
    { key="crystal_lattice",rarity="epic",icon="💎",label="晶格结构",
      desc="所有资源+35%，晶石产率额外+20%，完美平衡",
      effect={ miningRateMult=0.35, energyRateMult=0.35, nuclearRateMult=0.35 } },
    { key="mega_shipyard", rarity="epic", icon="🏭", label="巨型船坞",
      desc="造舰速度+70%，编队+3，快速成军之道",
      effect={ shipyardSpeedMult=0.70, fleetCapBonus=3 } },
    { key="stellar_forge", rarity="epic", icon="⭐", label="恒星熔炉",
      desc="矿石+50%，核能+50%，攻击+20%，工业军事双强",
      effect={ miningRateMult=0.50, nuclearRateMult=0.50, shipDmgMult=0.20 } },
    -- 战略史诗（6张）
    { key="armada",        rarity="epic", icon="🚀", label="无敌舰队",
      desc="编队+5，攻击+20%，生命+20%，钢铁洪流",
      effect={ fleetCapBonus=5, shipDmgMult=0.20, shipHealthMult=0.20 } },
    { key="war_economy",   rarity="epic", icon="💰", label="战争经济",
      desc="所有资源+25%，攻击+25%，造舰+25%，全能强化",
      effect={ miningRateMult=0.25, energyRateMult=0.25, nuclearRateMult=0.25,
               shipDmgMult=0.25, shipyardSpeedMult=0.25 } },
    { key="singularity",   rarity="epic", icon="🌌", label="奇点突破",
      desc="所有加成×1.2叠加（对已有卡效果额外+20%）",
      effect={ shipDmgMult=0.20, shipHealthMult=0.20, miningRateMult=0.20,
               energyRateMult=0.20, nuclearRateMult=0.20, shipyardSpeedMult=0.20 } },
    { key="logistics_net", rarity="epic", icon="📦", label="后勤网络",
      desc="造舰+50%，维修+20%，探索时长-40%，后勤为王",
      effect={ shipyardSpeedMult=0.50, waveRepairPct=0.20, explorerDurMult=-0.40 } },
    { key="apex_predator", rarity="epic", icon="👑", label="顶点掠食者",
      desc="攻击+45%，AOE+45%，每波维修+15%，猎手之巅",
      effect={ shipDmgMult=0.45, aoeRadiusMult=0.45, waveRepairPct=0.15 } },
    { key="omega_protocol",rarity="epic", icon="Ω",  label="Ω协议",
      desc="全属性+40%，最终形态，无尽的终极传说卡",
      effect={ shipDmgMult=0.40, shipHealthMult=0.40, miningRateMult=0.40,
               energyRateMult=0.40, nuclearRateMult=0.40, shipyardSpeedMult=0.40,
               fleetCapBonus=2, waveRepairPct=0.10 } },
}

local DIFFICULTY_CONFIGS = {
    -- attackFactor = 进攻间隔倍率（>1 越慢，<1 越快）
    -- 实际首攻窗口 = 210 × attackFactor × (0.75~1.30)
    -- initRes = 游戏开始时叠加到 ResourceManager 初始值的额外资源
    easy   = { label="简单", color={80,200,120},  attackFactor=2.2, maxThreat=2,
               desc="海盗进攻频率大幅降低，初始资源充裕，适合初次体验",
               initRes = { metal=800, esource=500, nuclear=200 } },
    normal = { label="普通", color={100,160,255}, attackFactor=1.0, maxThreat=5,
               desc="标准游戏体验，攻守均衡" },
    hard   = { label="困难", color={220,80,80},   attackFactor=0.65, maxThreat=5,
               desc="海盗进攻频繁，考验战略布局",
               initRes = { metal=-300, esource=-200 } },  -- 困难：初始资源削减
    custom = { label="自定义", color={200,180,255}, attackFactor=1.0, maxThreat=5,
               desc="自由调整海盗强度和初始资源" },  -- P1-2: 自定义难度
}
local DIFF_ORDER = {"easy", "normal", "hard", "custom"}

-- 网络状态
local scene_          = nil   -- 网络同步用 Scene
local serverConn_     = nil   -- 服务器连接
-- 云存档状态
local saveTimer_      = 0     -- 自动存档计时器
local AUTO_SAVE_INTERVAL = 60  -- 每 60 秒自动存档一次
local saveInProgress_ = false  -- 防止重复提交
local saveGame        -- 前向声明，函数体在网络部分定义

-- ============================================================================
-- 工具
-- ============================================================================
local function getDpr()
    return graphics:GetDPR()
end

local function getScreenSize()
    local w, h = UICommon.getVirtualSize()   -- 同时更新 UICommon.uiScale
    uiScale_ = UICommon.uiScale
    return w, h
end

-- ============================================================================
-- 基地模块效果应用
-- ============================================================================
--- 标记基地模块效果需要重算（下一帧 update 时执行）
local function markBaseEffectsDirty()
    baseEffectsDirty_ = true
end

--- 根据当前已安装的基地模块重新计算 rm_ 的速率加成和上限
--- 设计：通过 markBaseEffectsDirty() 延迟到 update 执行，避免每帧全量重算
local function applyBaseModuleEffects()
    if not baseEffectsDirty_ then return end
    baseEffectsDirty_ = false
    local base = GalaxyScene.GetBase()
    -- 先撤销上次由基地模块写入 rates 的加成（捕获旧值后再重置）
    local oldEsource = (rm_.baseBonus and rm_.baseBonus.esource) or 0
    local oldEnergy  = (rm_.baseBonus and rm_.baseBonus.energy)  or 0
    rm_.rates.energy  = (rm_.rates.energy  or 0) - oldEnergy
    rm_.rates.esource = (rm_.rates.esource or 0) - oldEsource
    -- S1 COLONY_BIOTECH: 撤销上次科技人口速率增量
    local oldTechPopDelta = (rm_.baseBonus and rm_.baseBonus.techPopRateDelta) or 0
    rm_.rates.population  = (rm_.rates.population or 0) - oldTechPopDelta
    -- 重置所有资源上限到基础值（精炼资源 + 原矿资源，避免模块效果叠加）
    local BASE_CAPS = { metal=99999, esource=99999, nuclear=9999, credits=9999999 }
    for res, cap in pairs(BASE_CAPS) do
        rm_.caps[res] = cap
    end
    -- 重置原矿上限（材料仓库模块影响这三项）
    rm_.caps.minerals = 9999
    rm_.caps.energy   = 9999
    rm_.caps.crystal  = 2000   -- 水晶上限提升至2000（避免新手快速满仓）
    rm_.baseBonus = {
        energy=0, esource=0,
        defense=0,           -- 防御炮台：每级 +50 基地防御力
        shield=0,            -- 护盾发生器：每级 +200 护盾值（科技SHIELD_REINFORCE叠加）
        shieldBonus=0,       -- 护盾强化科技额外护盾值
        defenseBonus=0,      -- 护盾强化科技额外防御比例
        researchMult=1.0,    -- 科研中心：每级 ×1.2 科研速度
        buildMult=1.0,       -- 行星探索中心：每级 ×0.75 建造时间
        shipyardMult=1.0,    -- 星际造船厂：每级 ×1.5 舰船建造速度
        fleetSpeedMult=1.0,  -- 曲速引擎科技/曲速闸门：舰队速度加成
        hasWarpGate=false,   -- 是否安装了曲速闸门
        -- P1-2: Lv8-10 专属模块
        hasWarpGatePrime=false,   -- 主曲速门：舰队瞬移
        -- 冷却时间跨 applyBaseModuleEffects 保留，不在此清零
        warpGatePrimeCooldown = (rm_.baseBonus and rm_.baseBonus.warpGatePrimeCooldown) or 0,
        hasStellarFortress=false, -- 恒星要塞：防御翻倍+敌方损失加成
    }

    if not base or not base.colonized then
        rm_.refineryMult = 0
        return
    end

    -- 精炼厂：只判断存在与否（0=无，1=有），无倍率效果
    local refineryMult  = 0
    local commandLevels = 0   -- 所有指挥中枢等级之和

    for _, b in ipairs(base.buildings) do
        local lvl = b.level or 1
        if b.key == "ENERGY_CORE" then
            -- 能量核心：直接精炼所有原矿，精炼倍率 +0.5×/级（与精炼厂叠加）
            refineryMult = refineryMult + 0.5 * lvl
        elseif b.key == "SOLAR_ARRAY" then
            -- 太阳能阵列：直接产出能源 +3/s/级（无需精炼）
            rm_.baseBonus.esource = rm_.baseBonus.esource + 3 * lvl
        elseif b.key == "MINERAL_SILO" then
            -- 资源仓储：原矿存储上限 ×2^级（minerals/energy/crystal）
            local mult = 2 ^ lvl
            rm_.caps.minerals = rm_.caps.minerals * mult
            rm_.caps.energy   = rm_.caps.energy   * mult
            rm_.caps.crystal  = rm_.caps.crystal  * mult
        elseif b.key == "MATERIAL_DEPOT" then
            -- 材料仓库：精炼资源上限 ×2^级（metal/esource/nuclear）
            local mult = 2 ^ lvl
            rm_.caps.metal    = rm_.caps.metal    * mult
            rm_.caps.esource  = rm_.caps.esource  * mult
            rm_.caps.nuclear  = rm_.caps.nuclear  * mult
        elseif b.key == "REFINERY" then
            -- 精炼厂：Lv.1=1×  Lv.2=1.5×  Lv.3=2×  每级+0.5×
            refineryMult = 1.0 + 0.5 * (lvl - 1)
        elseif b.key == "COMMAND_CENTER" then
            -- 指挥中枢：每级 +1 编队上限（上限 10）
            commandLevels = commandLevels + lvl
        elseif b.key == "DEFENSE_CANNON" then
            -- 防御炮台：每级 +50 基地防御力（海盗攻击时减伤）
            rm_.baseBonus.defense = rm_.baseBonus.defense + 50 * lvl
        elseif b.key == "BASE_SHIELD" then   -- L3: 原SHIELD_GEN，已重命名避免与行星建筑冲突
            -- 护盾发生器：每级 +200 护盾值（先于HP承伤）
            rm_.baseBonus.shield = rm_.baseBonus.shield + 200 * lvl
        elseif b.key == "RESEARCH_CENTER" then
            -- 科研中心：每级科研速度 ×1.2（累乘）
            rm_.baseBonus.researchMult = rm_.baseBonus.researchMult * (1.2 ^ lvl)
        elseif b.key == "BUILD_CENTER" then
            -- 行星探索中心：每级建造时间 ×0.75（累乘，最低为25%原时间）
            rm_.baseBonus.buildMult = math.max(0.25, rm_.baseBonus.buildMult * (0.75 ^ lvl))
        elseif b.key == "SHIPYARD" then
            -- 星际造船厂：每级舰船建造速度 ×1.5（累乘）
            rm_.baseBonus.shipyardMult = rm_.baseBonus.shipyardMult * (1.5 ^ lvl)
        elseif b.key == "WARP_GATE" then
            -- 曲速闸门：解锁舰队快速移动（速度×2），与WARP_DRIVE科技叠加
            rm_.baseBonus.hasWarpGate  = true
            rm_.baseBonus.fleetSpeedMult = rm_.baseBonus.fleetSpeedMult * (2.0 ^ lvl)
        -- P1-2: Lv8-10 专属模块效果
        elseif b.key == "PARTICLE_ACCELERATOR" then
            -- 粒子加速器：科研速度×2.5，精炼速率+50%（通过refineryMult在后续乘算）
            rm_.baseBonus.researchMult = rm_.baseBonus.researchMult * (2.5 ^ lvl)
            rm_.baseBonus.particleAccelRefineMult = (2.5 ^ lvl)  -- 后续应用到 refineryMult
        elseif b.key == "WARP_GATE_PRIME" then
            -- 主曲速门：舰队瞬移（保留已有冷却进度，仅标记激活）
            rm_.baseBonus.hasWarpGatePrime = true
            -- 冷却时间在 handleUpdate 中递减，此处不重置（避免每帧刷新清零）
        elseif b.key == "STELLAR_FORTRESS" then
            -- 恒星要塞：防御力×2（在所有防御炮台计算完毕后翻倍），标记敌方损失加成
            rm_.baseBonus.hasStellarFortress = true
        end
    end

    -- 保留已解锁科技的加成（避免被重置清除）
    -- S1: 统一重放所有已解锁科技的特殊 bonus 到 baseBonus
    local techBonus = rm_.baseBonus
    if rs_ and rs_.unlocked then
        for id, _ in pairs(rs_.unlocked) do
            local td = TECHS[id]
            if td and td.bonus then
                local b = td.bonus
                -- WARP_DRIVE: 舰队速度
                if b.fleetSpeedMult then
                    techBonus.fleetSpeedMult = techBonus.fleetSpeedMult * b.fleetSpeedMult
                end
                -- SHIELD_REINFORCE: 护盾/防御
                if b.shieldBonus then
                    techBonus.shieldBonus  = (techBonus.shieldBonus  or 0) + b.shieldBonus
                    techBonus.defenseBonus = (techBonus.defenseBonus or 0) + (b.defenseBonus or 0)
                end
                -- HULL_ALLOY: 舰船最大耐久倍率
                if b.shipHealthMult then
                    techBonus.shipHealthMult = (techBonus.shipHealthMult or 1.0) * b.shipHealthMult
                end
                -- ADVANCED_WEAPONS: 舰船攻击力倍率
                if b.shipDmgMult then
                    techBonus.shipDmgMult = (techBonus.shipDmgMult or 1.0) * b.shipDmgMult
                end
                -- RAPID_REFINE: 全局精炼速率倍率
                if b.globalRefineMult then
                    techBonus.globalRefineMult = (techBonus.globalRefineMult or 1.0) * b.globalRefineMult
                end
                -- CRYSTAL_PROCESS: 水晶→核能精炼效率
                if b.refineMult == "crystal" then
                    techBonus.crystalRefineMult = (techBonus.crystalRefineMult or 1.0) * (b.val or 1.0)
                end
                -- COLONY_BIOTECH: 人口增长速率倍率
                if b.colonyPopMult then
                    techBonus.colonyPopMult = (techBonus.colonyPopMult or 1.0) * b.colonyPopMult
                end
                -- QUANTUM_CORE: 核心升级费用折扣 & 科研速度
                if b.coreUpgradeCostMult then
                    techBonus.coreUpgradeCostMult = (techBonus.coreUpgradeCostMult or 1.0) * b.coreUpgradeCostMult
                end
                if b.researchSpeedMult then
                    techBonus.researchSpeedMult = (techBonus.researchSpeedMult or 1.0) * b.researchSpeedMult
                end
            end
        end
    end

    -- 人口影响舰队上限：每100人口额外+1编队（最多+3）
    local popBonus = math.min(3, math.floor((rm_.resources.population or 0) / 100))

    -- 应用指挥中枢效果：基础 5 + 所有指挥中枢等级之和 + 人口加成，上限 10
    fm_:setMaxFleets(5 + commandLevels + popBonus)

    -- 应用太阳能阵列加成（直接写入精炼资源层，无需精炼）
    rm_.rates.esource = (rm_.rates.esource or 0) + rm_.baseBonus.esource

    -- 星航基地核心 Lv.2+ 提供基础精炼能力（mult=0.3 → 矿石2.1/s）
    -- 若 REFINERY 已安装则取较大值（Lv.1=1.0×/7/s，Lv.2=1.5×/10.5/s，Lv.3=2.0×/14/s）
    local coreLevel = (base and base.coreLevel) or 1
    if coreLevel >= 2 then
        local coreRefineMult = 0.3
        refineryMult = math.max(refineryMult, coreRefineMult)
    end

    -- 更新精炼倍率
    rm_.refineryMult = refineryMult

    -- P1-2 PARTICLE_ACCELERATOR: 精炼速率额外×1.5（叠加到已有精炼倍率上）
    if rm_.baseBonus.particleAccelRefineMult then
        rm_.refineryMult = rm_.refineryMult * 1.5
    end

    -- P1-2 STELLAR_FORTRESS: 防御力翻倍（在防御炮台计算完毕后应用）
    if rm_.baseBonus.hasStellarFortress then
        rm_.baseBonus.defense = rm_.baseBonus.defense * 2
    end

    -- H1 修复：Gas Giant esourceMult 加成 —— 乘以精炼倍率（在所有模块计算完成后）
    -- applyPlanetTypeBonus 将 esourceMult 存入 rm_.baseBonus.esourceMult，这里才真正生效
    if rm_.baseBonus.esourceMult and rm_.baseBonus.esourceMult > 1.0 then
        rm_.refineryMult = rm_.refineryMult * rm_.baseBonus.esourceMult
    end

    -- S1 COLONY_BIOTECH: 人口增长速率倍率（累乘方式，避免与行星加成冲突）
    local colPopMult = techBonus.colonyPopMult or 1.0
    if colPopMult ~= 1.0 then
        local baseRate   = rm_.rates.population or 0
        local techDelta  = baseRate * (colPopMult - 1.0)
        rm_.rates.population          = baseRate + techDelta
        techBonus.techPopRateDelta    = techDelta
    else
        techBonus.techPopRateDelta    = 0
    end

    -- P2-1: 叠加无尽模式选卡累积加成
    local cb = endlessCardBonuses_
    if cb.shipDmgMult    ~= 0 then rm_.baseBonus.shipDmgMult    = (rm_.baseBonus.shipDmgMult    or 1.0) * (1 + cb.shipDmgMult)    end
    if cb.shipHealthMult ~= 0 then rm_.baseBonus.shipHealthMult = (rm_.baseBonus.shipHealthMult or 1.0) * (1 + cb.shipHealthMult) end
    if cb.aoeRadiusMult  ~= 0 then rm_.baseBonus.aoeRadiusMult  = (rm_.baseBonus.aoeRadiusMult  or 1.0) * (1 + cb.aoeRadiusMult)  end
    if cb.shipyardSpeedMult ~= 0 then rm_.baseBonus.shipyardMult = rm_.baseBonus.shipyardMult * (1 + cb.shipyardSpeedMult) end
    if cb.fleetCapBonus  ~= 0 then
        local cur = fm_ and fm_:getMaxFleets() or 5
        fm_:setMaxFleets(cur + cb.fleetCapBonus)
    end
    if cb.nuclearCapBonus ~= 0 then
        rm_.caps.nuclear = (rm_.caps.nuclear or 9999) + cb.nuclearCapBonus
    end
    -- 生产速率：在 baseBonus 计算完毕后乘倍（通过修改 rates 的增量部分）
    -- P2-1 V2.0: 连胜狂潮 buff 叠加 ×1.5 资源产出
    local streakMult = (endlessStreakBuff_ and isEndlessMode_) and 1.5 or 1.0
    rm_.baseBonus.cardMiningMult  = (1 + cb.miningRateMult)  * streakMult
    rm_.baseBonus.cardEnergyMult  = (1 + cb.energyRateMult)  * streakMult
    rm_.baseBonus.cardNuclearMult = (1 + cb.nuclearRateMult) * streakMult
    -- 其他效果存入 baseBonus 供其他系统读取
    rm_.baseBonus.waveRepairPct   = cb.waveRepairPct   or 0
    rm_.baseBonus.explorerDurMult = cb.explorerDurMult or 0
    rm_.baseBonus.intelRateMult   = cb.intelRateMult   or 0
end

-- ============================================================================
-- P2-1: 无尽模式选卡 — 从卡池随机抽 3 张（避免重复），玩家选择后应用
-- ============================================================================
--- 从 ENDLESS_CARD_POOL 随机不重复抽取 count 张卡
--- P2-1 V2.0: 每5轮起必保至少1张史诗卡
local function drawEndlessCards(count)
    local pool  = {}
    for _, c in ipairs(ENDLESS_CARD_POOL) do pool[#pool+1] = c end
    -- Fisher-Yates 洗牌
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local result = {}
    for i = 1, math.min(count, #pool) do result[#result+1] = pool[i] end

    -- P2-1 V2.0: 第5轮起，若抽出结果中无史诗卡，则强制换入一张
    if endlessRound_ >= 5 then
        local hasEpic = false
        for _, c in ipairs(result) do
            if c.rarity == "epic" then hasEpic = true; break end
        end
        if not hasEpic then
            -- 从完整卡池中随机选一张史诗卡替换最后一张
            local epics = {}
            for _, c in ipairs(ENDLESS_CARD_POOL) do
                if c.rarity == "epic" then epics[#epics+1] = c end
            end
            if #epics > 0 then
                result[#result] = epics[math.random(1, #epics)]
            end
        end
    end
    return result
end

--- 将选中卡牌的 effect 累加到 endlessCardBonuses_，然后触发重算
local function applyEndlessCard(cardKey)
    local chosen = nil
    for _, c in ipairs(ENDLESS_CARD_POOL) do
        if c.key == cardKey then chosen = c; break end
    end
    if not chosen then return end

    local eff = chosen.effect
    local cb  = endlessCardBonuses_
    for field, delta in pairs(eff) do
        cb[field] = (cb[field] or 0) + delta
    end

    -- 重新计算基地模块效果（将会在末尾叠加卡牌加成）
    markBaseEffectsDirty()

    -- P2-3: 隐藏成就 — 无尽选卡统计
    hiddenStats_.totalCardsChosen = hiddenStats_.totalCardsChosen + 1
    Achievement.Check("endless_card", {
        totalCardsChosen = hiddenStats_.totalCardsChosen,
        lastCardRarity   = chosen.rarity,
    })

    GameUI.Notify(string.format("✅ 已获得「%s」！", chosen.label), "success")
    Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
end

-- ============================================================================
-- 结算触发
-- ============================================================================
--- 计算总游戏时长（秒），由 handleUpdate 中的 totalPlayTime_ 维护
local totalPlayTime_ = 0

-- 前向声明（函数体在后面定义）
local softReset
local setupSceneAndUI
local onGameReady

--- 触发结算界面（只触发一次，防止重复）
local function triggerEndGame(gameType)
    if endGameTriggered_ then return end
    endGameTriggered_ = true

    -- 收集统计数据
    local colonized = 0
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}) do
        if p.colonized then colonized = colonized + 1 end
    end

    -- P3-3: 星级评分计算（1-3星）
    -- 标准：① 用时≤8分钟 +1; ② 损失比（受/造）≤0.4 +1; ③ 殖民≥3颗 +1
    local dmgDealt   = battleStatsCache_.dmgDealt  or 0
    local dmgTaken   = battleStatsCache_.dmgTaken  or 0
    local playMin    = (totalPlayTime_ or 0) / 60
    local lossRatio  = (dmgDealt > 0) and (dmgTaken / dmgDealt) or 1.0
    local stars = 1
    if playMin <= 8   then stars = stars + 1 end
    if lossRatio <= 0.4 then stars = stars + 1 end
    if gameType ~= "win" then stars = 1 end   -- 失败最多1星
    -- MVP 舰种（伤害最高的，用 bestSurvivor 作为代理）
    local mvpShip = battleStatsCache_.bestSurvivor

    local stats = {
        playTime      = totalPlayTime_,   -- 秒数，由 GameUI 格式化
        colonized     = colonized,
        piratesKilled = piratesKilled_,
        level         = (player_ and player_.level) or 1,
        rank          = (player_ and player_.rank)  or "指挥官",
        -- 战斗详情统计（从 battleStatsCache_ 读取，由 onBattleEnd 快照）
        dmgDealt      = dmgDealt,
        dmgTaken      = dmgTaken,
        enemiesKilled = battleStatsCache_.enemiesKilled or 0,
        wavesCleared  = battleStatsCache_.wavesCleared  or 0,
        bestSurvivor  = battleStatsCache_.bestSurvivor,
        -- P3-3 新增
        stars         = stars,
        mvpShip       = mvpShip,
        -- P3-2: 雷达图维度
        totalResearch = totalResearch_,
        totalColonized = colonized,   -- 别名，与 colonized 同值
    }

    -- 结算时停止自动存档、暂停海盗 AI
    if pirateAI_ then pirateAI_.paused = true end

    -- 提交本局得分到排行榜
    -- 得分公式：（殖民地×100 + 击败海盗×50 - 用时分钟）× 星级权重
    -- P3-3: 星级权重 1星×1.0 / 2星×1.3 / 3星×1.6
    local starMult = (stars == 3) and 1.6 or (stars == 2) and 1.3 or 1.0
    local scoreVal = math.floor((colonized * 100
                   + piratesKilled_ * 50
                   - math.floor((totalPlayTime_ or 0) / 60))
                   * starMult)
    scoreVal = math.max(0, scoreVal)
    -- 只有高于历史最高分才提交（避免刷低分）
    clientCloud:Get("galaxy_score", {
        ok = function(_, iscores)
            local best = iscores.galaxy_score or 0
            if scoreVal > best then
                clientCloud:BatchSet()
                    :SetInt("galaxy_score",   scoreVal)
                    :SetInt("galaxy_colonized", colonized)
                    :SetInt("galaxy_kills",   piratesKilled_)
                    :Save("结算提交", {
                        ok = function()
                            print(string.format("[Client] 排行榜分数已更新: %d (旧 %d)", scoreVal, best))
                        end,
                        error = function(_, reason)
                            print("[Client] 排行榜提交失败: " .. tostring(reason))
                        end,
                    })
            end
        end,
        error = function() end,
        timeout = function() end,
    })

    -- P2-1: 累计生涯战绩
    careerStats_.totalGames    = careerStats_.totalGames + 1
    if gameType == "win" then
        careerStats_.totalWins = careerStats_.totalWins + 1
    end
    local wavesNow = battleStatsCache_.wavesCleared or 0
    if wavesNow > careerStats_.bestWave then
        careerStats_.bestWave = wavesNow
    end
    careerStats_.totalKills    = careerStats_.totalKills    + (battleStatsCache_.enemiesKilled or 0)
    careerStats_.totalColonies = careerStats_.totalColonies + (colonized or 0)
    careerStats_.playtime      = careerStats_.playtime      + math.floor(totalPlayTime_ or 0)
    if mvpShip and mvpShip ~= "" then
        careerStats_.bestMvpShip = mvpShip
    end
    -- 持久化战绩到独立文件（与普通存档分离，新游戏不覆盖）
    local ok2, err2 = pcall(function()
        local cFile = File("galaxy_career.json", FILE_WRITE)
        if cFile:IsOpen() then
            -- P2-3: 同时保存已兑换奖励列表
            local saveData = {}
            for k, v in pairs(careerStats_) do saveData[k] = v end
            saveData.redeemed = Achievement.GetRedeemed()
            cFile:WriteString(cjson.encode(saveData))
            cFile:Close()
        end
    end)
    if not ok2 then print("[Career] 战绩保存失败: " .. tostring(err2)) end
    GameUI.SetCareerStats(careerStats_)
    print(string.format("[Career] 战绩更新: %d局/%d胜/最高%d波/总击杀%d",
        careerStats_.totalGames, careerStats_.totalWins,
        careerStats_.bestWave,   careerStats_.totalKills))

    GameUI.ShowEndGame(gameType, stats, function()
        GameUI.HideEndGame()
        softReset()   -- 完整重置所有系统，开始新游戏
    end)
end

-- ============================================================================
-- EXPLORER 舰探索任务系统
-- ============================================================================

--- 派遣一艘 EXPLORER 舰执行探索任务
local function startExplorerTask()
    -- 检查储备池中是否有 EXPLORER 舰
    local cnt = fm_ and fm_.reserve and (fm_.reserve["EXPLORER"] or 0) or 0
    if cnt <= 0 then
        GameUI.Notify("储备池中没有探索舰可派遣", "error"); return
    end
    -- 检查任务槽位
    local activeCount = 0
    for _, t in ipairs(explorerTasks_) do
        if not t.done then activeCount = activeCount + 1 end
    end
    if activeCount >= MAX_EXPLORER_TASKS then
        GameUI.Notify(string.format("探索任务已满（最多 %d 条同时进行）", MAX_EXPLORER_TASKS), "error")
        return
    end

    -- 消耗一艘 EXPLORER
    fm_.reserve["EXPLORER"] = cnt - 1
    if fm_.reserve["EXPLORER"] <= 0 then fm_.reserve["EXPLORER"] = nil end
    GameUI.RefreshFleetPanel(fm_, nil)

    -- 随机选择任务模板
    local tmpl = EXPLORER_TASK_TEMPLATES[math.random(1, #EXPLORER_TASK_TEMPLATES)]
    local dur  = tmpl.minDur + math.random() * (tmpl.maxDur - tmpl.minDur)

    -- 随机选一个目标星球名（未殖民优先，无则用系统名）
    local targetName = "未知星域"
    local planets = GalaxyScene and GalaxyScene.GetAllPlanets and GalaxyScene.GetAllPlanets() or {}
    local candidates = {}
    for _, p in ipairs(planets) do
        if not p.colonized then candidates[#candidates+1] = p end
    end
    if #candidates > 0 then
        local pick = candidates[math.random(1, #candidates)]
        targetName = pick.name
    elseif #planets > 0 then
        targetName = planets[math.random(1, #planets)].name
    end

    explorerTaskSeq_ = explorerTaskSeq_ + 1
    local task = {
        id         = explorerTaskSeq_,
        icon       = tmpl.icon,
        label      = tmpl.label,
        targetName = targetName,
        duration   = dur,
        elapsed    = 0,
        rewards    = tmpl.rewards,
        expGain    = tmpl.expGain or 0,
        pirateIntel= tmpl.pirateIntel or false,
        done       = false,
        rewarded   = false,
    }
    explorerTasks_[#explorerTasks_+1] = task

    GameUI.Notify(string.format("%s 探索舰出发 → %s（预计 %ds）",
        tmpl.icon, targetName, math.floor(dur)), "info")
    GameUI.RefreshExplorerTasks(explorerTasks_)
    print(string.format("[ExploreTask] 任务#%d 开始: %s → %s (%.0fs)",
        task.id, tmpl.label, targetName, dur))
end

-- ============================================================================
-- P3-3: DDA 动态难度调整核心逻辑
-- ============================================================================

--- 将当前 dda_.currentFactor 应用到活跃的 pirateAI_
local function ddaApply()
    if pirateAI_ then
        pirateAI_.attackIntervalFactor = dda_.currentFactor
    end
end

--- 战斗结束后评估并调整难度
---@param isWin     boolean  本次战斗是否获胜
---@param lossRatio number   受伤/输出伤害比（0=零伤，1+=损失惨重）
local function ddaEvaluateBattle(isWin, lossRatio)
    if not dda_.enabled or difficulty_ == "custom" then return end

    -- 记入滚动窗口
    local hist = dda_.recentResults
    table.insert(hist, { win = isWin, lossRatio = lossRatio })
    while #hist > dda_.MAX_HISTORY do table.remove(hist, 1) end

    -- 计算本次调整方向
    local delta = 0
    if isWin then
        if lossRatio < 0.25 then
            delta = -dda_.STEP_BATTLE        -- 大胜：增加难度
        elseif lossRatio < 0.55 then
            delta = -dda_.STEP_BATTLE * 0.5  -- 小胜：轻微增加难度
        else
            delta = dda_.STEP_BATTLE * 0.3   -- 险胜：轻微降低难度
        end
    else
        delta = dda_.STEP_BATTLE * 1.2       -- 战败：明显降低难度
    end

    -- 若最近连续失败（≥2次），加大缓解幅度
    local recentLoses = 0
    for _, r in ipairs(hist) do if not r.win then recentLoses = recentLoses + 1 end end
    if recentLoses >= 2 and not isWin then
        delta = delta * 1.4
    end

    local minF = dda_.baseFactor * dda_.MIN_MULT
    local maxF = dda_.baseFactor * dda_.MAX_MULT
    local newF = math.max(minF, math.min(maxF, dda_.currentFactor + delta))
    local changed = math.abs(newF - dda_.currentFactor) > 0.01
    dda_.currentFactor = newF
    ddaApply()

    if changed then
        dda_.adjustCount = dda_.adjustCount + 1
        -- 每隔2次调整才提示，避免刷屏
        if dda_.adjustCount % 2 == 1 then
            if delta < 0 then
                GameUI.Notify("海盗侦察你的战术，正在强化部署…", "warn")
            else
                GameUI.Notify("海盗损失惨重，暂时收缩兵力。", "info")
            end
        end
        print(string.format("[DDA] 战斗后调整: %.2f → %.2f (delta=%.2f, win=%s, lossRatio=%.2f)",
            dda_.currentFactor - delta, dda_.currentFactor,
            delta, tostring(isWin), lossRatio))
    end
end

--- 定期（每 EVAL_INTERVAL 秒）基于基地 HP 做轻微微调
local function ddaPeriodicCheck()
    if not dda_.enabled or difficulty_ == "custom" then return end
    if endGameTriggered_ or currentScene_ ~= "galaxy" then return end

    local base = GalaxyScene.GetBase and GalaxyScene.GetBase()
    if not base then return end
    local hp    = base.hp    or base.currentHP or 100
    local maxHp = base.maxHp or 100
    local hpPct = hp / math.max(1, maxHp)

    local delta = 0
    if hpPct < 0.30 then
        delta = dda_.STEP_PERIODIC          -- 基地岌岌可危：放慢进攻
    elseif hpPct > 0.85 then
        -- 基地血满：若最近多赢，轻微加速
        local wins = 0
        for _, r in ipairs(dda_.recentResults) do if r.win then wins = wins + 1 end end
        if wins >= 2 then delta = -dda_.STEP_PERIODIC * 0.5 end
    end

    if math.abs(delta) > 0.001 then
        local minF  = dda_.baseFactor * dda_.MIN_MULT
        local maxF  = dda_.baseFactor * dda_.MAX_MULT
        dda_.currentFactor = math.max(minF, math.min(maxF, dda_.currentFactor + delta))
        ddaApply()
        print(string.format("[DDA] 定期微调: factor=%.2f, hpPct=%.0f%%", dda_.currentFactor, hpPct * 100))
    end
end

--- 更新所有探索任务进度（每帧调用）
local function updateExplorerTasks(dt)
    if #explorerTasks_ == 0 then return end
    local changed = false
    for _, task in ipairs(explorerTasks_) do
        if not task.done then
            task.elapsed = task.elapsed + dt
            if task.elapsed >= task.duration then
                task.done = true
                task.rewarded = false
                changed = true

                -- 发放奖励
                local parts = {}
                for _, r in ipairs(task.rewards) do
                    rm_:add(r.res, r.amt)
                    parts[#parts+1] = r.res .. "+" .. r.amt
                end
                -- EXP 奖励
                if task.expGain > 0 and player_ then
                    player_.exp = (player_.exp or 0) + task.expGain
                    parts[#parts+1] = "EXP+" .. task.expGain
                end
                -- 海盗情报：揭露最近威胁基地的位置/倒计时，并延缓进攻
                local extra = ""
                if task.pirateIntel and pirateAI_ then
                    local report = pirateAI_:RevealMostThreateningBase(120)
                    extra = " [获得海盗情报]"
                    GameUI.Notify("📡 侦察报告：" .. report .. "\n进攻已延缓30秒，情报有效120s", "warn")
                end

                -- 归还探索舰到储备池
                fm_:addToReserve("EXPLORER")
                GameUI.RefreshFleetPanel(fm_, nil)

                -- P1-3: 推送探索日志记录
                local rewardStr = table.concat(parts, " ")
                local mins = math.floor(task.duration / 60)
                local secs = math.floor(task.duration % 60)
                local timeStr = mins > 0
                    and string.format("%dm%ds", mins, secs)
                    or  string.format("%ds", secs)
                GameUI.PushExploreLog({
                    icon      = task.icon or "🔭",
                    label     = task.label or task.targetName or "未知",
                    rewardStr = rewardStr,
                    timeStr   = timeStr,
                })

                -- P2-3: 隐藏成就 — 探索统计
                hiddenStats_.totalExplored = hiddenStats_.totalExplored + 1
                if task.eventType then
                    hiddenStats_.exploreTypesFound[task.eventType] = true
                end
                local typesCount = 0
                for _ in pairs(hiddenStats_.exploreTypesFound) do typesCount = typesCount + 1 end
                Achievement.Check("explore_done", {
                    totalExplored    = hiddenStats_.totalExplored,
                    exploreTypesFound = typesCount,
                })

                GameUI.Notify(string.format("✅ 探索完成：%s\n%s%s",
                    task.label, table.concat(parts, "  "), extra), "success")
                print(string.format("[ExploreTask] 任务#%d 完成: %s (%s)",
                    task.id, task.label, table.concat(parts, ", ")))
            end
        end
    end
    -- 清理已完成超过 30 秒的任务记录（保留 5 条最新的）
    if changed then
        GameUI.RefreshExplorerTasks(explorerTasks_)
        -- 移除已完成任务（只保留最近 5 条）
        local keep = {}
        for i = #explorerTasks_, 1, -1 do
            if not explorerTasks_[i].done or #keep < 5 then
                table.insert(keep, 1, explorerTasks_[i])
            end
        end
        explorerTasks_ = keep
    end
end

--- 无尽模式：实际执行新一轮启动（选卡完成后调用）
local function doStartEndlessRound()
    print(string.format("[Endless] 进入第 %d 轮，重生海盗基地", endlessRound_))

    -- 提升 AI 威胁上限（每轮 +1，最多无上限）
    if pirateAI_ then
        pirateAI_.maxThreatLevel = 5 + endlessRound_
        pirateAI_.paused = false
        -- 重新生成海盗基地（世界半径与 GalaxyScene 保持一致）
        local worldRange = 2000
        pirateAI_:generateBases(worldRange)
        -- 每轮所有基地初始威胁等级提升
        for _, base in ipairs(pirateAI_.bases) do
            base.level = math.min(5, 1 + endlessRound_)
            -- 加速首次进攻（每轮减 15%）
            local factor = pirateAI_.attackIntervalFactor * (0.85 ^ endlessRound_)
            base.attackTimer = base.attackTimer * math.max(0.2, factor)
        end
    end

    -- 通知玩家
    local msg = string.format("⚔️ 无尽第 %d 轮开始！新海盗基地已重生，威胁等级 +%d",
        endlessRound_, endlessRound_)
    GameUI.Notify(msg, "error")

    -- 更新 GameUI 轮次显示
    GameUI.SetEndlessRound(endlessRound_)
end

--- P2-1: 无尽模式：弹出选卡面板，选完后执行下一轮（Roguelike 3选1）
local function startEndlessNextRound()
    -- P2-1 V2.0: 连胜判定（根据本轮战斗击杀率）
    endlessStreakBuff_ = false
    local killRate = 0
    if battleStatsCache_.waveEnemyTotal and battleStatsCache_.waveEnemyTotal > 0 then
        killRate = (battleStatsCache_.waveKillTotal or 0) / battleStatsCache_.waveEnemyTotal
    end
    if killRate >= 0.8 then
        endlessStreak_ = endlessStreak_ + 1
    else
        endlessStreak_ = 0
    end
    if endlessStreak_ >= 3 then
        endlessStreakBuff_ = true
        GameUI.Notify(string.format(
            "🔥 连胜狂潮！连续 %d 轮全消 (%.0f%%)，本轮资源收益 ×1.5！",
            endlessStreak_, killRate * 100), "success")
        print(string.format("[Endless] 连胜狂潮激活: streak=%d killRate=%.2f", endlessStreak_, killRate))
    elseif endlessStreak_ > 0 then
        GameUI.Notify(string.format(
            "⚡ 全消 %.0f%%！连胜进度 %d/3", killRate * 100, endlessStreak_), "info")
    end

    endlessRound_ = endlessRound_ + 1

    -- P2-1 V2.0: 无尽模式排行榜 — 提交本轮轮次（分数 = 完成轮次数）
    local endlessScore = endlessRound_ - 1  -- 刚完成的轮次
    if endlessScore > 0 then
        clientCloud:Get("endless_score", {
            ok = function(_, iscores)
                local best = iscores.endless_score or 0
                if endlessScore > best then
                    clientCloud:BatchSet()
                        :SetInt("endless_score", endlessScore)
                        :Save("无尽排行榜提交", {
                            ok    = function() print(string.format("[Endless] 排行榜分数已更新: %d 轮", endlessScore)) end,
                            error = function(_, r) print("[Endless] 排行榜提交失败: " .. tostring(r)) end,
                        })
                end
            end,
            error   = function() end,
            timeout = function() end,
        })
    end

    -- P2-3: 隐藏成就 — 无尽模式波次
    Achievement.Check("endless_wave", { endlessWave = endlessRound_ })

    -- 抽 3 张随机卡牌
    local cards = drawEndlessCards(3)

    -- 显示选卡面板；选择完成后立即应用效果并启动新一轮
    GameUI.ShowCardDraft(cards, function(cardKey)
        applyEndlessCard(cardKey)
        doStartEndlessRound()
    end)

    -- 暂停 AI，等待玩家选卡（最多 30 秒后自动选第一张）
    if pirateAI_ then pirateAI_.paused = true end
end

--- 检查是否满足胜利条件：所有海盗基地均已摧毁（active == false）
local function checkVictory()
    if endGameTriggered_ then return end
    if not pirateAI_ or not pirateAI_.bases then return end
    local allDestroyed = true
    for _, b in ipairs(pirateAI_.bases) do
        if b.active then allDestroyed = false; break end
    end
    if not allDestroyed then return end

    -- 无尽模式：不结算，重生新一轮
    if isEndlessMode_ then
        Achievement.Check("victory", {
            victory                = true,
            playTime               = playTime_,
            totalShipsLostCampaign = hiddenStats_.totalShipsLostCampaign,  -- P2-3
        })
        Audio.Play(Audio.SFX.VICTORY)
        startEndlessNextRound()
        return
    end

    -- 普通模式：正常胜利结算
    print("[Game] 胜利！所有海盗基地已摧毁")
    Achievement.Check("victory", {
        victory                = true,
        playTime               = playTime_,
        totalShipsLostCampaign = hiddenStats_.totalShipsLostCampaign,  -- P2-3
    })
    Audio.StopBGM()
    Audio.Play(Audio.SFX.VICTORY)
    -- 播放胜利 fanfare（单次，不循环）
    Audio.PlayBGM(Audio.BGM.VICTORY_FANFARE, 0, false)
    triggerEndGame("win")
end

--- 检查是否满足失败条件：星航基地 HP ≤ 0
local function checkDefeat()
    if endGameTriggered_ then return end
    local base = GalaxyScene.GetBase and GalaxyScene.GetBase()
    if not base then return end
    local hp = base.hp or base.currentHP or (base.colonized and 100 or nil)
    if hp ~= nil and hp <= 0 then
        print("[Game] 失败！星航基地被摧毁")
        Audio.Play(Audio.SFX.BATTLE_LOSE)
        triggerEndGame("lose")
    end
end

-- ============================================================================
-- 场景切换
-- ============================================================================
local function switchScene(name)
    currentScene_ = name
    local hasPlanet = (GalaxyScene.GetSelected() ~= nil)
    GameUI.ShowScene(name, hasPlanet)
    -- BGM 随场景切换（P3-3: 切回银河时同步重置音调，防止残留 Boss 高调）
    if name == "battle" then
        Audio.ResetBGMPitch()
        Audio.PlayBGM(Audio.BGM.BATTLE_THEME, 1.5)
    elseif name == "galaxy" then
        Audio.ResetBGMPitch()
        Audio.PlayBGM(Audio.BGM.GALAXY_MAIN, 1.5)
    end
end

-- ============================================================================
-- 海盗：获取玩家所有可被攻击的目标位置
-- ============================================================================
local function getPlayerTargets()
    local targets = {}
    -- 已殖民行星
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        -- 使用行星在星系中的世界坐标
        local wx = p.system and (p.system.x + math.cos(p.angle) * p.orbitRadius) or 0
        local wy = p.system and (p.system.y + math.sin(p.angle) * p.orbitRadius) or 0
        targets[#targets+1] = { x=wx, y=wy, name=p.name }
    end
    -- 星航基地（已展开时才是目标）
    local base = GalaxyScene.GetBase()
    if base and base.colonized then
        targets[#targets+1] = { x=base.x or 0, y=base.y or 0, name="星航基地" }
    end
    return targets
end

-- ============================================================================
-- 海盗进攻触发：切入战斗场景
-- ============================================================================
local BattleScene = require("game.BattleScene")

local function onPirateAttack(pirateLevel, baseId, targetName)
    -- 记录此次进攻信息，战斗结束后根据胜负处理
    pirateAttackInfo_ = { pirateLevel=pirateLevel, baseId=baseId, targetName=targetName }

    -- P1-2 STELLAR_FORTRESS: 恒星要塞使敌方来袭波次-1（代表损失20%舰队预先退缩）
    local effectivePirateLevel = pirateLevel
    if rm_ and rm_.baseBonus and rm_.baseBonus.hasStellarFortress then
        effectivePirateLevel = math.max(1, pirateLevel - 1)
        GameUI.Notify("恒星要塞震慑：敌方舰队损失20%！", "success")
    end

    -- 以海盗等级作为起始波次初始化战斗场景
    BattleScene.Init({
        vg          = vg_,
        notifyFn    = GameUI.Notify,
        player      = player_,
        rm          = rm_,
        rs          = rs_,
        spq         = spq_,
        startWave   = effectivePirateLevel,
        onBattleEnd = function(result)
            -- 快照战斗统计（在场景切换前记录）
            battleStatsCache_ = BattleScene.GetStats and BattleScene.GetStats() or {}
            -- P2-3: 隐藏成就 — 集火击杀统计累计
            if battleStatsCache_.focusKillCount and battleStatsCache_.focusKillCount > 0 then
                hiddenStats_.focusKills = hiddenStats_.focusKills + battleStatsCache_.focusKillCount
                if battleStatsCache_.focusBossKill then hiddenStats_.focusBossKill = true end
                Achievement.Check("focus_kill", {
                    focusKills    = hiddenStats_.focusKills,
                    focusBossKill = hiddenStats_.focusBossKill,
                })
            end
            -- P2-3: 隐藏成就 — 损失舰船（战役累计）
            hiddenStats_.totalShipsLostCampaign = hiddenStats_.totalShipsLostCampaign
                + (battleStatsCache_.shipsLost or 0)
            if result == "win" then
                Audio.Play(Audio.SFX.VICTORY)
                piratesKilled_ = piratesKilled_ + 1
                Achievement.Check("pirate_kill", { piratesKilled = piratesKilled_ })
                -- P2-3: 隐藏成就 — 战斗结果检查
                Achievement.Check("battle_result", {
                    victory   = true,
                    shipsLost = battleStatsCache_.shipsLost or 0,
                    overkillMax = battleStatsCache_.overkillMax or 0,
                    ddaLevel  = dda_.adjustCount,  -- P3-3
                    totalShipsLostCampaign = hiddenStats_.totalShipsLostCampaign,
                })
                -- 玩家胜利：削弱海盗基地
                if pirateAI_ and pirateAttackInfo_ then
                    pirateAI_:weakenBase(pirateAttackInfo_.baseId)
                end
                GameUI.Notify("击退海盗！返回星图", "success")
                checkStageGoals()  -- 战斗胜利后检查（击杀/波次相关目标）
                checkVictory()
            elseif result == "retreat" then
                -- P1-2: 战略撤退 — 轻微惩罚（5%），海盗基地不强化
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                local penalty = 0.05
                local lostParts = {}
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = rm_.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then
                        rm_:add(res, -loss)
                        lostParts[#lostParts+1] = (RES_LABELS and RES_LABELS[res] or res) .. "-" .. loss
                    end
                end
                local lostStr = #lostParts > 0
                    and ("轻微损失(5%): " .. table.concat(lostParts, " "))
                    or "无资源损失"
                GameUI.Notify("战略撤退成功！" .. lostStr, "warn")
            else
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                -- 玩家战败：扣除资源（基础惩罚15%，防御/护盾可减伤）
                -- 防御炮台：每50防御力减1%惩罚（上限 -10%）
                -- 护盾发生器/护盾强化：每200护盾值减1%惩罚（上限 -5%）
                local defVal    = (rm_.baseBonus and rm_.baseBonus.defense) or 0
                local shldVal   = (((rm_.baseBonus and rm_.baseBonus.shield) or 0)
                               + ((rm_.baseBonus and rm_.baseBonus.shieldBonus) or 0))
                               * ((rm_.baseBonus and rm_.baseBonus.shieldMaxMult) or 1.0)  -- P1-1 FORTRESS_PROTOCOL
                local defReduce   = math.min(0.10, math.floor(defVal  / 50)  * 0.01)
                local shldReduce  = math.min(0.05, math.floor(shldVal / 200) * 0.01)
                local penalty = math.max(0.02, 0.15 - defReduce - shldReduce)
                local lostParts = {}
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = rm_.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then
                        rm_:add(res, -loss)
                        lostParts[#lostParts+1] = (RES_LABELS and RES_LABELS[res] or res) .. "-" .. loss
                    end
                end
                -- 海盗基地强化
                if pirateAI_ and pirateAttackInfo_ then
                    pirateAI_:strengthenBase(pirateAttackInfo_.baseId)
                end
                local penaltyPct = math.floor(penalty * 100)
                local lostStr = #lostParts > 0
                    and ("资源损失(" .. penaltyPct .. "%): " .. table.concat(lostParts, " "))
                    or "无资源损失"
                GameUI.Notify("舰队覆灭！" .. lostStr, "error")
                checkDefeat()
            end
            -- P3-3: DDA 战斗后评估
            do
                local dealt = battleStatsCache_.dmgDealt or 0
                local taken = battleStatsCache_.dmgTaken or 0
                local lr = dealt > 0 and (taken / dealt) or (taken > 0 and 1.0 or 0.0)
                -- 撤退视为失败
                ddaEvaluateBattle(result == "win", lr)
            end
            pirateAttackInfo_ = nil
            -- 切回星图
            switchScene("galaxy")
            saveGame()
        end,
    })

    -- 将玩家编队中的舰船加入战斗
    if fm_ then
        for i = 1, fm_.maxFleets do
            local fl = fm_.fleets[i]
            if fl then
                for _, entry in ipairs(fl.ships) do
                    for _ = 1, entry.count do
                        BattleScene.AddProductionShip(entry.shipType)
                    end
                end
            end
        end
    end

    switchScene("battle")
    Audio.Play(Audio.SFX.BATTLE_START)
    GameUI.Notify(string.format("海盗Lv%d 进犯 %s！进入战斗！", pirateLevel, targetName), "error")
end

-- ============================================================================
-- 玩家主动突袭海盗基地（编队到达海盗基地时触发）
-- ============================================================================
local function onFleetSiegeBase(fleetId, baseId)
    -- 找到对应基地
    local base = nil
    if pirateAI_ then
        for _, b in ipairs(pirateAI_.bases) do
            if b.id == baseId then base = b; break end
        end
    end
    if not base or not base.active then
        GameUI.Notify("海盗基地已被摧毁，编队返航", "info")
        return
    end

    -- 记录突袭信息（siege=true 标记区别于被动防守）
    pirateAttackInfo_ = { pirateLevel=base.level, baseId=baseId, targetName="海盗基地", fleetId=fleetId, siege=true }

    BattleScene.Init({
        vg          = vg_,
        notifyFn    = GameUI.Notify,
        player      = player_,
        rm          = rm_,
        rs          = rs_,
        spq         = spq_,
        startWave   = base.level,
        onBattleEnd = function(result)
            -- 快照战斗统计
            battleStatsCache_ = BattleScene.GetStats and BattleScene.GetStats() or {}
            -- P2-3: 隐藏成就 — 集火击杀统计累计（突袭战斗）
            if battleStatsCache_.focusKillCount and battleStatsCache_.focusKillCount > 0 then
                hiddenStats_.focusKills = hiddenStats_.focusKills + battleStatsCache_.focusKillCount
                if battleStatsCache_.focusBossKill then hiddenStats_.focusBossKill = true end
                Achievement.Check("focus_kill", {
                    focusKills    = hiddenStats_.focusKills,
                    focusBossKill = hiddenStats_.focusBossKill,
                })
            end
            hiddenStats_.totalShipsLostCampaign = hiddenStats_.totalShipsLostCampaign
                + (battleStatsCache_.shipsLost or 0)
            if result == "win" then
                Audio.Play(Audio.SFX.VICTORY)
                piratesKilled_ = piratesKilled_ + 1
                Achievement.Check("pirate_kill", { piratesKilled = piratesKilled_ })
                -- P2-3: 隐藏成就 — 战斗结果检查（突袭）
                Achievement.Check("battle_result", {
                    victory   = true,
                    shipsLost = battleStatsCache_.shipsLost or 0,
                    overkillMax = battleStatsCache_.overkillMax or 0,
                    ddaLevel  = dda_.adjustCount,  -- P3-3
                    totalShipsLostCampaign = hiddenStats_.totalShipsLostCampaign,
                })
                -- 突袭胜利：双倍削弱（主动突袭比被动防守伤害更大）
                if pirateAI_ and pirateAttackInfo_ then
                    pirateAI_:weakenBase(pirateAttackInfo_.baseId)
                    pirateAI_:weakenBase(pirateAttackInfo_.baseId)
                end
                GameUI.Notify("突袭成功！海盗基地受到重创！", "success")
                checkVictory()
            elseif result == "retreat" then
                -- P1-2: 战略撤退 — 5% 资源惩罚，舰队损失减半（10%）
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                local penalty = 0.05
                local lostParts = {}
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = rm_.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then
                        rm_:add(res, -loss)
                        lostParts[#lostParts+1] = (RES_LABELS and RES_LABELS[res] or res) .. "-" .. loss
                    end
                end
                -- 撤退时舰队仅损失 10%（比失败的 50% 轻微）
                if pirateAttackInfo_ and pirateAttackInfo_.fleetId and fm_ then
                    local fid = pirateAttackInfo_.fleetId
                    local fl  = fm_.fleets[fid]
                    if fl then
                        local toRemove = {}
                        for _, entry in ipairs(fl.ships) do
                            local loss = math.floor(entry.count * 0.1)
                            for _ = 1, loss do
                                toRemove[#toRemove+1] = entry.shipType
                            end
                        end
                        for _, st in ipairs(toRemove) do
                            fm_:removeShip(fid, st)
                        end
                        GalaxyScene.InvalidateFleetColor(fid)
                        GameUI.RefreshFleetPanel(fm_, fid)
                    end
                end
                local lostStr = #lostParts > 0
                    and ("轻微损失(5%): " .. table.concat(lostParts, " "))
                    or "无资源损失"
                GameUI.Notify("战略撤退成功！" .. lostStr, "warn")
            else
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                -- 突袭失败：该编队损失约 50% 舰船
                if pirateAttackInfo_ and pirateAttackInfo_.fleetId and fm_ then
                    local fid = pirateAttackInfo_.fleetId
                    local fl  = fm_.fleets[fid]
                    if fl then
                        -- 收集需要移除的舰船（避免遍历时修改）
                        local toRemove = {}
                        for _, entry in ipairs(fl.ships) do
                            local loss = math.max(1, math.floor(entry.count * 0.5))
                            for _ = 1, loss do
                                toRemove[#toRemove+1] = entry.shipType
                            end
                        end
                        for _, st in ipairs(toRemove) do
                            fm_:removeShip(fid, st)
                        end
                        GalaxyScene.InvalidateFleetColor(fid)
                        GameUI.RefreshFleetPanel(fm_, fid)
                    end
                end
                GameUI.Notify("突袭失败！舰队损失惨重！", "error")
            end
            -- P3-3: DDA 战斗后评估（突袭战斗）
            do
                local dealt = battleStatsCache_.dmgDealt or 0
                local taken = battleStatsCache_.dmgTaken or 0
                local lr = dealt > 0 and (taken / dealt) or (taken > 0 and 1.0 or 0.0)
                ddaEvaluateBattle(result == "win", lr)
            end
            pirateAttackInfo_ = nil
            switchScene("galaxy")
            saveGame()
        end,
    })

    -- 将该编队的舰船加入战斗（突袭只用派出的编队，不用全部舰队）
    if fm_ then
        local fl = fm_.fleets[fleetId]
        if fl then
            for _, entry in ipairs(fl.ships) do
                for _ = 1, entry.count do
                    BattleScene.AddProductionShip(entry.shipType)
                end
            end
        end
    end

    switchScene("battle")
    Audio.Play(Audio.SFX.BATTLE_START)
    GameUI.Notify(string.format("突袭海盗基地 Lv%d！进入战斗！", base.level), "error")
end

-- ============================================================================
-- 升级奖励处理
-- ============================================================================
local function handleLevelUp(leveled, newLevel, newRank, rewards)
    if not leveled then return end
    Audio.Play(Audio.SFX.LEVELUP)
    rm_:add("metal",   rewards.metal)
    rm_:add("esource", rewards.esource)
    rm_:add("nuclear", rewards.nuclear)
    local isMilestone = (newLevel % 5 == 0)
    local tag = isMilestone and "里程碑晋升" or "晋升"
    GameUI.Notify(
        tag .. " Lv." .. newLevel .. " [" .. newRank .. "]  奖励: 金属+" ..
        rewards.metal .. " 能源+" .. rewards.esource .. " 核能+" .. rewards.nuclear,
        isMilestone and "success" or "info"
    )
end

-- ============================================================================
-- 阶段性目标检测
-- ============================================================================
local completedGoals_ = {}   -- 已完成的目标 id 集合
local totalShipsBuilt_ = 0   -- 累计造船数量
local shipTypeBuilt_   = {}  -- 各舰型造船数 { DESTROYER=1, BATTLECRUISER=0, ... }
local resMilestoneTimer_ = 0 -- 资源里程碑检查节流（每 10 秒检查一次）
local resWarnTimer_      = 0 -- P2-1: 资源危机预警检查节流（每 5 秒）
local lowResWarnSent_    = {} -- P2-1: 已发送预警的资源（每局重置）
-- P3-2: 星球产量历史（每 30s 采样一次，保留最近 10 个点）
local planetProdHistory_ = {}  -- {[planetName]={minerals={...},energy={...},crystal={...}}}
local prodSampleTimer_   = 0   -- 采样计时器（每 30 秒触发）
local PROD_SAMPLE_INTERVAL = 30
local PROD_MAX_SAMPLES     = 10

checkStageGoals = function()
    if not STAGE_GOALS then return end
    -- 构建 gameState 快照（按需填充）
    local battleStats = BattleScene and BattleScene.GetStats and BattleScene.GetStats() or {}
    local gameState = {
        profile        = player_,
        base           = GalaxyScene.GetBase(),
        rs             = rs_,
        rm             = rm_,
        totalShipsBuilt    = totalShipsBuilt_,
        shipTypeBuilt      = shipTypeBuilt_,
        totalEnemiesKilled = battleStats.enemiesKilled or 0,
        totalWavesCleared  = battleStats.wavesCleared  or 0,
        endlessRound       = endlessRound_ or 0,   -- P2-3: 无尽模式轮次
        colonizedPlanets   = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {},
        piratesKilled      = piratesKilled_ or 0,
    }
    for _, goal in ipairs(STAGE_GOALS) do
        if not completedGoals_[goal.id] then
            local callOk, checkResult = pcall(goal.check, gameState)
            if callOk and checkResult then   -- checkResult 是 goal.check 返回的布尔值
                completedGoals_[goal.id] = true
                -- 发放奖励
                local rewardStr = ""
                if goal.reward then
                    local parts = {}
                    for res, amt in pairs(goal.reward) do
                        rm_:add(res, amt)
                        local label = RES_LABELS and RES_LABELS[res] or res
                        parts[#parts+1] = label .. "+" .. amt
                    end
                    rewardStr = " 奖励: " .. table.concat(parts, " ")
                end
                GameUI.Notify("✓ 目标达成: " .. goal.title .. rewardStr, "success")
                print("[Goal] 完成: " .. goal.id)
                -- P1-3: 每次有新目标完成，同步到 GameUI
                GameUI.SetCompletedGoals(completedGoals_)
            end
        end
    end
end

-- ============================================================================
-- 回调
-- ============================================================================
local function onBuildCb(key, isUpgrade, bldIdx)
    if key == "__switch_galaxy" then switchScene("galaxy"); return end
    local planet = GalaxyScene.GetSelected()
    if not planet then GameUI.Notify("请先选择一个已探索星球", "warn"); return end
    local ok, reason
    if isUpgrade then
        ok, reason = bs_:upgrade(bldIdx, planet)
    else
        ok, reason = bs_:build(key, planet)
    end
    if ok then
        Audio.Play(Audio.SFX.BUILD_START)
        GameUI.Notify("开始" .. (isUpgrade and "升级" or "建造") .. ": " .. BUILDINGS[key].name, "info")
        GameUI.RefreshPlanetPanel(planet)
    else
        GameUI.Notify((isUpgrade and "升级" or "建造") .. "失败: " .. (reason or ""), "error")
    end
end

local function onBaseBuildCb(key, isUpgrade, bldIdx)
    local base = GalaxyScene.GetBase()
    if not base or not base.colonized then
        GameUI.Notify("基地尚未建立", "warn"); return
    end
    local ok, reason
    if isUpgrade then
        ok, reason = bbs_:upgrade(bldIdx, base)
    else
        ok, reason = bbs_:build(key, base)
    end
    if ok then
        Audio.Play(Audio.SFX.BUILD_START)
        local modName = BASE_MODULES[key] and BASE_MODULES[key].name or key
        GameUI.Notify("开始" .. (isUpgrade and "升级" or "安装") .. ": " .. modName, "info")
        GameUI.RefreshPlanetPanel(base)
    else
        GameUI.Notify((isUpgrade and "升级" or "安装") .. "失败: " .. (reason or ""), "error")
    end
end

local function onCoreUpgradeCb()
    local base = GalaxyScene.GetBase()
    if not base or not base.colonized then
        GameUI.Notify("基地尚未建立", "warn"); return
    end
    local ok, reason = bbs_:upgradeCore(base)
    if ok then
        local nextLv = (base.coreLevel or 1)   -- upgradeCore 已入队，level 在完成时写入
        GameUI.Notify("核心升级已启动 → Lv." .. nextLv + 1 .. " (建造中…)", "info")
        GameUI.RefreshPlanetPanel(base)
    else
        GameUI.Notify("核心升级失败: " .. (reason or ""), "error")
    end
end

local function onResearchCb(id)
    local ok, reason = rs_:start(id)
    if ok then
        Audio.Play(Audio.SFX.RESEARCH_START)
        GameUI.Notify("开始研发: " .. TECHS[id].name, "info")
        GameUI.RefreshTechPanel()
    else
        GameUI.Notify("研发失败: " .. (reason or ""), "error")
    end
end

local function onMarketCb(action, res, amount)
    local ok, val
    if action == "sell" then
        ok, val = ms_:sell(res, amount)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("出售 " .. RES_LABELS[res] .. "×" .. amount .. "  +★" .. val, "success")
        else GameUI.Notify("出售失败: " .. (val or ""), "error") end
    else
        ok, val = ms_:buy(res, amount)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("购买 " .. RES_LABELS[res] .. "×" .. amount .. "  -★" .. val, "success")
        else GameUI.Notify("购买失败: " .. (val or ""), "error") end
    end
    GameUI.RefreshMarketPanel()
    GameUI.RefreshResourceBar()
end

--- 应用星球类型加成到资源速率（幂等设计：每次调用前先撤销旧加成再重新应用）
--- planet.appliedBonus 存储上次已应用的加成量，避免重复叠加
local function applyPlanetTypeBonus(planet)
    local ptype = planet.ptype
    if not ptype or not PLANET_TYPE_BONUS then return end
    local bonus = PLANET_TYPE_BONUS[ptype]
    if not bonus then return end

    -- 先撤销上次对该行星应用过的加成（幂等保障）
    local prev = planet.appliedBonus or {}
    if prev.mineralsDelta then
        rm_.rates.minerals = (rm_.rates.minerals or 0) - prev.mineralsDelta
    end
    if prev.crystalDelta then
        rm_.rates.crystal = (rm_.rates.crystal or 0) - prev.crystalDelta
    end
    -- buildCostMult / nuclearMult / esourceMult 在 reapplyAllPlanetBonuses 中统一重置

    planet.appliedBonus = {}
    local ab = planet.appliedBonus

    -- 矿石产量加成（Terran / Desert）
    if bonus.mineralMult then
        local delta = 0
        for _, b in ipairs(planet.buildings or {}) do
            if b.key == "MINE" and b.currentProd then
                delta = delta + (b.currentProd.minerals or 0) * (bonus.mineralMult - 1.0)
            end
        end
        if delta ~= 0 then
            rm_.rates.minerals = (rm_.rates.minerals or 0) + delta
            ab.mineralsDelta = delta
        end
    end
    -- 水晶产量加成（Oceanic）
    if bonus.crystalMult then
        local base_rate = 2.0   -- ResourceManager.new() 中的 crystal rate 基准
        local delta = base_rate * (bonus.crystalMult - 1.0)
        rm_.rates.crystal = (rm_.rates.crystal or 0) + delta
        ab.crystalDelta = delta
    end
    -- 核能精炼加成（Volcanic）：标记到 baseBonus，由 applyBaseModuleEffects 读取
    if bonus.nuclearMult then
        rm_.baseBonus = rm_.baseBonus or {}
        rm_.baseBonus.nuclearMult = (rm_.baseBonus.nuclearMult or 1.0) * bonus.nuclearMult
    end
    -- 建造费用折扣（Barren）：累乘到 baseBonus.buildCostMult，由 BuildingSystem 读取
    if bonus.buildCostMult then
        rm_.baseBonus = rm_.baseBonus or {}
        rm_.baseBonus.buildCostMult = (rm_.baseBonus.buildCostMult or 1.0) * bonus.buildCostMult
    end
    -- 能源精炼加成（Gas Giant）：标记到 baseBonus，由 applyBaseModuleEffects 读取
    if bonus.esourceMult then
        rm_.baseBonus = rm_.baseBonus or {}
        rm_.baseBonus.esourceMult = (rm_.baseBonus.esourceMult or 1.0) * bonus.esourceMult
    end
    print("[Colony] 星球类型加成 " .. ptype .. " → " .. (bonus.label or ""))
end

--- 重新对所有已殖民行星应用类型加成（读档后调用，确保速率一致）
local function reapplyAllPlanetBonuses()
    -- 先清空所有行星的 appliedBonus，让 applyPlanetTypeBonus 从零开始
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        p.appliedBonus = nil
    end
    -- 重置需要累乘的 baseBonus 字段（避免多次重叠加）
    if rm_.baseBonus then
        rm_.baseBonus.esourceMult   = nil
        rm_.baseBonus.nuclearMult   = nil
        rm_.baseBonus.buildCostMult = nil
    end
    -- 逐一重新应用
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        applyPlanetTypeBonus(p)
    end
    markBaseEffectsDirty()
end

-- 内部殖民执行（消耗资源 + 调用 GalaxyScene）
local function doColonize(planet)
    if not planet or planet.colonized then return false end
    local cost = { metal = 200, esource = 100 }
    if not rm_:canAfford(cost) then
        GameUI.Notify("资源不足: 探索需要 金属×200 能源×100", "error")
        return false
    end
    rm_:spend(cost)
    local leveled, newLevel, newRank, rewards = GalaxyScene.Colonize(planet)
    Audio.Play(Audio.SFX.COLONIZE_SUCCESS)
    -- 成就检查：殖民类
    do
        local colonized = #(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {})
        Achievement.Check("colonize", { totalColonized = colonized })
    end
    -- 应用星球类型加成
    applyPlanetTypeBonus(planet)
    local ptypeLabel = (PLANET_TYPE_BONUS and planet.ptype and PLANET_TYPE_BONUS[planet.ptype]) and
                       ("  [" .. (PLANET_TYPE_BONUS[planet.ptype].label or planet.ptype) .. "]") or ""
    GameUI.Notify("探索成功: " .. planet.name .. ptypeLabel .. "  (金属-200  能源-100)", "success")
    handleLevelUp(leveled, newLevel, newRank, rewards)
    GameUI.RefreshPlanetPanel(planet)
    checkStageGoals()   -- 殖民后检查阶段目标
    saveGame()
    return true
end

--- 检查指定编队是否含有探索舰
local function fleetHasExplorer(fleetId)
    if not fm_ then return false end
    local fl = fm_.fleets[fleetId]
    if not fl then return false end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "EXPLORER" and e.count > 0 then return true end
    end
    return false
end

-- 探索舰殖民回调（由 GameUI 储备面板"殖民"按钮触发）
-- 现在触发条件改为：储备中有探索舰（直接消耗储备池）
local function onExplorerColonizeCb()
    -- 检查储备中有探索舰
    local cnt = fm_.reserve and (fm_.reserve["EXPLORER"] or 0) or 0
    if cnt <= 0 then
        GameUI.Notify("储备中没有探索舰", "warn"); return
    end
    local sel = GalaxyScene.GetSelected()
    if sel and not sel.colonized and not sel.isBase then
        -- 已选中未殖民星球，直接殖民
        local ok = doColonize(sel)
        if ok then
            fm_.reserve["EXPLORER"] = cnt - 1
            if fm_.reserve["EXPLORER"] <= 0 then fm_.reserve["EXPLORER"] = nil end
            explorerColonizeMode_ = false
            GameUI.RefreshReservePanel(fm_)
        end
    else
        -- 进入殖民选择模式，提示玩家点击目标星球
        explorerColonizeMode_ = true
        GameUI.Notify("已选择探索舰 — 请点击一个未探索星球执行探索", "info")
        GameUI.SetExplorerColonizeMode(true)
    end
end

local function onShipCancelCb(index)
    if spq_:cancel(index) then
        GameUI.Notify("已取消建造", "info")
        GameUI.RefreshShipyardPanel()
    end
end

local function onShipPromoteCb(index)
    spq_:promote(index)
    GameUI.RefreshShipyardPanel()
end

local function onShipQueueCb(shipType)
    local planet = GalaxyScene.GetSelected()
    -- 若未选中星球，尝试用基地
    if not planet then
        local base = GalaxyScene.GetBase()
        if base and base.colonized then planet = base end
    end
    if not planet then GameUI.Notify("请先选择有造船厂的星球或基地", "warn"); return end
    local ok, reason = spq_:queue(shipType, planet)
    if ok then
        GameUI.Notify("加入建造队列: " .. SHIP_TYPES[shipType].name, "info")
        GameUI.RefreshShipyardPanel()
    else
        GameUI.Notify("造船失败: " .. (reason or ""), "error")
    end
end

local function onPlanetSelect(planet)
    selectedPlanet_ = planet
    -- 探索舰殖民模式：点击未殖民星球直接执行殖民
    if explorerColonizeMode_ and planet and not planet.colonized and not planet.isBase then
        local cnt = fm_.reserve and (fm_.reserve["EXPLORER"] or 0) or 0
        if cnt > 0 then
            local ok = doColonize(planet)
            if ok then
                fm_.reserve["EXPLORER"] = cnt - 1
                if fm_.reserve["EXPLORER"] <= 0 then fm_.reserve["EXPLORER"] = nil end
                GameUI.RefreshReservePanel(fm_)
            end
        end
        explorerColonizeMode_ = false
        GameUI.SetExplorerColonizeMode(false)
    end
    GameUI.RefreshPlanetPanel(planet)
    GameUI.RefreshShipyardPanel()
    GameUI.ShowScene("galaxy", planet ~= nil)
end

-- ============================================================================
-- 云存档：序列化当前游戏状态为 JSON
-- ============================================================================
local function buildSaveData()
    local galaxyData   = GalaxyScene.GetSaveData()
    local GalaxyEvents = require("game.GalaxyEvents")
    local saveData = {
        version   = 1,
        difficulty = difficulty_,                    -- 保存当前难度，继续游戏时恢复
        resources = rm_:serialize().resources,
        research  = rs_:serialize(),
        player    = player_:serialize(),
        shipQueue = spq_:serialize(),
        fleet     = fm_:serialize(),
        planets   = galaxyData.planets,
        base      = galaxyData.base,
        pirate       = pirateAI_ and pirateAI_:serialize() or nil,
        tutorial     = GameUI.TutorialSerialize(),   -- 教程完成进度
        achievements = Achievement.GetUnlocked(),    -- 已解锁成就列表
        playerName    = playerName_,                 -- P1-1: 玩家昵称
        totalShipsBuilt = totalShipsBuilt_,          -- 累计造船数（阶段目标用）
        shipTypeBuilt   = shipTypeBuilt_,            -- 各舰型造船数
        completedGoals  = completedGoals_,           -- 已完成目标 id 集合（防止重复奖励）
        totalResearch   = totalResearch_,            -- 累计科技数（成就用）
        -- P1-3: 链式事件状态
        galaxyEvents = GalaxyEvents.Serialize(),
        -- P1-1: 外交系统状态
        diplomacy    = ds_ and ds_:serialize() or nil,
    }
    return cjson.encode(saveData)
end

-- 保存到本地文件
saveGame = function()
    if saveInProgress_ then return end
    saveInProgress_ = true
    -- H3: 用 pcall 包裹，任何异常都不会导致 saveInProgress_ 永久锁死
    local ok, err = pcall(function()
        local jsonStr = buildSaveData()
        local file = File("galaxy_save.json", FILE_WRITE)
        if file:IsOpen() then
            file:WriteString(jsonStr)
            file:Close()
        end
    end)
    saveInProgress_ = false   -- 无论成败都清除，防止锁死
    if not ok then
        print("[Save] 存档失败: " .. tostring(err))
    end
end

-- 从存档数据恢复游戏状态
local function restoreGame(jsonStr)
    if not jsonStr or jsonStr == "" then
        print("[Client] 新玩家，使用初始状态")
        return
    end
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or not data then
        print("[Client] 存档解析失败，使用初始状态")
        return
    end
    print("[Client] 恢复存档 v" .. (data.version or 0))

    -- 恢复难度设置（老存档无此字段则保持 normal）
    if data.difficulty and DIFFICULTY_CONFIGS[data.difficulty] then
        difficulty_       = data.difficulty
        difficultyChosen_ = true
        print("[Client] 恢复难度: " .. difficulty_)
    end

    -- P1-1: 恢复玩家昵称
    if type(data.playerName) == "string" and #data.playerName > 0 then
        playerName_ = data.playerName
        print("[Client] 恢复昵称: " .. playerName_)
    end

    -- 先恢复星图（会重建行星 buildings），然后恢复资源（保留存档值）
    GalaxyScene.LoadSaveData({ planets = data.planets, base = data.base }, rm_)
    markBaseEffectsDirty()
    applyBaseModuleEffects()   -- 恢复基地模块对 rates/caps 的效果
    rm_:deserialize({ resources = data.resources })
    rs_:deserialize(data.research)
    player_:deserialize(data.player)

    -- 造船队列恢复（需要行星引用）
    local planetLookup = {}
    for _, p in ipairs(GalaxyScene.GetAllPlanets()) do
        planetLookup[p.id] = p
    end
    spq_:deserialize(data.shipQueue, function(id) return planetLookup[id] end)
    fm_:deserialize(data.fleet)

    -- 恢复海盗AI状态
    if pirateAI_ and data.pirate then
        pirateAI_:deserialize(data.pirate)
    end

    -- 恢复教程完成进度（已完成则不再弹窗）
    if data.tutorial then
        GameUI.TutorialDeserialize(data.tutorial)
    end

    -- 恢复成就已解锁列表
    if data.achievements then
        Achievement.SetUnlocked(data.achievements)
        GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())
    end

    -- 恢复阶段目标进度（防止重复奖励 / 成就计数归零）
    totalShipsBuilt_ = data.totalShipsBuilt or 0
    totalResearch_   = data.totalResearch   or 0
    shipTypeBuilt_   = type(data.shipTypeBuilt) == "table" and data.shipTypeBuilt or {}
    if type(data.completedGoals) == "table" then
        completedGoals_ = data.completedGoals
    end

    -- P1-3: 恢复链式事件队列
    if data.galaxyEvents then
        local GalaxyEvents = require("game.GalaxyEvents")
        GalaxyEvents.Deserialize(data.galaxyEvents)
    end

    -- P1-1: 恢复外交系统状态（需在行星数据恢复后执行，以同步 neutralFaction 字段）
    if ds_ and data.diplomacy then
        ds_:deserialize(data.diplomacy, GalaxyScene.GetAllPlanets())
        print("[Client] 外交系统已恢复")
    end

    -- H2 修复：读档后重新应用所有殖民行星的类型加成（之前只恢复了基地模块效果）
    reapplyAllPlanetBonuses()

    -- 同步 UI 状态
    if GalaxyScene.IsDeployed() then
        GameUI.SetDeployed(true)
        local base = GalaxyScene.GetBase()
        if base then GameUI.RefreshPlanetPanel(base) end
    end
    GameUI.RefreshTechPanel()
    GameUI.RefreshResourceBar()
    GameUI.Notify("存档已恢复", "success")
end

-- ============================================================================
-- 网络连接就绪后初始化
-- ============================================================================
onGameReady = function()
    -- 新游戏流程：跳过读档
    if skipSaveLoad_ then
        skipSaveLoad_ = false
        print("[Client] 新游戏：跳过存档加载")
        return
    end
    -- 继续游戏：从本地文件加载存档
    if fileSystem:FileExists("galaxy_save.json") then
        local file = File("galaxy_save.json", FILE_READ)
        if file:IsOpen() then
            local jsonStr = file:ReadString()
            file:Close()
            restoreGame(jsonStr)
            return
        end
    end
    print("[Client] 无本地存档，新游戏开始")
end

-- ============================================================================
-- 主菜单屏幕 & 难度选择屏幕（渲染委托给 ClientMenus）
-- ============================================================================

local function menuCtx()
    return {
        hover            = diffHoverBtn_,
        customDiffSlider = customDiffSlider_,
        customDiff       = customDiff_,
        DIFF_ORDER       = DIFF_ORDER,
        DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS,
        menuT            = menuT_,         -- P3-3: 粒子背景时间
        -- P1-1: 昵称输入框
        playerName       = playerName_,
        nicknameActive   = nicknameInputActive_,
        nicknameCursorT  = nicknameCursorT_,
        nicknameHover    = diffHoverBtn_ == "nickname_input",
    }
end

local function getCustomPanelVisible()
    return ClientMenus.GetCustomPanelVisible({ hover=diffHoverBtn_, customDiffSlider=customDiffSlider_ })
end

local function getCustomPanelLayout(sw, sh)
    return ClientMenus.GetCustomPanelLayout(sw, sh)
end

local function getCustomSliderRects(sw, sh)
    return ClientMenus.GetCustomSliderRects(sw, sh, { customDiff=customDiff_ })
end

local function getEndlessBtnLayout(sw, sh)
    return ClientMenus.GetEndlessBtnLayout(sw, sh, menuCtx())
end

local function getDifficultyHit(mx, my, sw, sh)
    return ClientMenus.GetDifficultyHit(mx, my, sw, sh, menuCtx())
end

local function getMainMenuHit(mx, my, sw, sh)
    return ClientMenus.GetMainMenuHit(mx, my, sw, sh, hasSave_)
end

local function renderMainMenu(sw, sh)
    ClientMenus.RenderMainMenu(vg_, sw, sh, { hover=mainMenuHover_, hasSave=hasSave_, menuT=menuT_ })
end

local function renderDifficultyScreen(sw, sh)
    ClientMenus.RenderDifficultyScreen(vg_, sw, sh, menuCtx())
end

--- 玩家在主菜单点击按钮
local function onMainMenuSelect(key)
    if key == "new" then
        skipSaveLoad_   = true
        mainMenuActive_ = false
        print("[Client] 主菜单：选择新游戏")
    elseif key == "continue" and hasSave_ then
        mainMenuActive_ = false
        difficultyChosen_ = true
        print("[Client] 主菜单：选择继续游戏")
        setupSceneAndUI()
        onGameReady()
        GameUI.Notify("欢迎回来，指挥官！", "info")
    end
end

--- 玩家点击选择难度
local function onDifficultySelect(key)
    difficulty_       = key
    difficultyChosen_ = true
    isEndlessMode_    = false
    endlessRound_     = 0
    for k in pairs(endlessCardBonuses_) do endlessCardBonuses_[k] = 0 end  -- P2-1
    if key == "custom" then
        DIFFICULTY_CONFIGS.custom.attackFactor = customDiff_.attackFactor
        DIFFICULTY_CONFIGS.custom.maxThreat    = math.floor(customDiff_.maxThreat)
    end
    local cfg = DIFFICULTY_CONFIGS[key]
    print(string.format("[Client] 难度已选择: %s (attackFactor=%.1f, maxThreat=%d)",
        cfg.label, cfg.attackFactor, cfg.maxThreat))
    setupSceneAndUI()
    onGameReady()
    if key == "custom" then
        local freqLabel = customDiff_.attackFactor < 0.8 and "极快"
            or customDiff_.attackFactor < 1.2 and "普通"
            or customDiff_.attackFactor < 1.8 and "较慢" or "很慢"
        local resStr = customDiff_.initResBonus > 0
            and string.format("+%d", customDiff_.initResBonus)
            or customDiff_.initResBonus < 0
            and tostring(customDiff_.initResBonus)
            or "标准"
        GameUI.Notify(string.format(
            "自定义难度：进攻%s · 初始资源%s · 威胁Lv%d",
            freqLabel, resStr, math.floor(customDiff_.maxThreat)), "info")
    else
        GameUI.Notify("难度: " .. cfg.label .. " —— 征服银河！", "info")
    end
    if adBonusApplied_ then
        adBonusApplied_ = false
        GameUI.Notify(string.format("🎬 广告加成已生效！金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear), "success")
    end
end

--- 玩家点击无尽征服模式
local function onEndlessModeSelect()
    difficulty_       = "normal"
    difficultyChosen_ = true
    isEndlessMode_    = true
    endlessRound_     = 0
    for k in pairs(endlessCardBonuses_) do endlessCardBonuses_[k] = 0 end  -- P2-1
    print("[Client] 无尽征服模式已启动")
    setupSceneAndUI()
    onGameReady()
    GameUI.SetEndlessRound(0)
    GameUI.Notify("⚔️ 无尽征服模式 —— 歼灭所有敌人，战至最后一刻！", "success")
    if adBonusApplied_ then
        adBonusApplied_ = false
        GameUI.Notify(string.format("🎬 广告加成已生效！金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear), "success")
    end
end
-- ============================================================================
-- ============================================================================
-- P2-3: 局内统计面板渲染（Tab 键触发，全屏半透明覆盖）
-- ============================================================================
local function renderStatsPanel(sw, sh)
    if not statsOpen_ then return end

    local vg = vg_

    -- ① 全屏半透明遮罩（点击关闭）
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(0, 0, 20, 190))
    nvgFill(vg)

    -- ② 面板主体：居中 600×420
    local PW, PH = 620, 430
    local px = (sw - PW) * 0.5
    local py = (sh - PH) * 0.5

    -- 背景卡片
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 12)
    nvgFillColor(vg, nvgRGBA(15, 20, 45, 235))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 220, 180))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 标题栏
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 255))
    nvgText(vg, px + PW * 0.5, py + 22, "📊  本局统计")

    -- 关闭按钮（右上角 ×）
    local closeX = px + PW - 20
    local closeY = py + 18
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local cx, cy = statsMouseX_, statsMouseY_
    local closeDist = math.sqrt((cx - closeX)^2 + (cy - closeY)^2)
    nvgFillColor(vg, closeDist < 14 and nvgRGBA(255,100,100,255) or nvgRGBA(180,180,180,200))
    nvgText(vg, closeX, closeY, "✕")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 36)
    nvgLineTo(vg, px + PW - 16, py + 36)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 220, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- ③ 采集统计数据
    -- 殖民
    local allPlanets  = GalaxyScene.GetAllPlanets and GalaxyScene.GetAllPlanets() or {}
    local totalPlanets = 0
    local colonized   = 0
    for _, p in ipairs(allPlanets) do
        if not p.deepSpace then
            totalPlanets = totalPlanets + 1
            if p.colonized then colonized = colonized + 1 end
        end
    end

    -- 科技
    local techResearched = 0
    local techTotal      = 0
    for _ in pairs(TECHS) do techTotal = techTotal + 1 end
    for _ in pairs(rs_.unlocked) do techResearched = techResearched + 1 end

    -- 战斗
    local waves    = piratesKilled_ or 0
    local kills    = (battleStatsCache_ and battleStatsCache_.totalEnemiesKilled) or 0
    local shipsLost= (battleStatsCache_ and battleStatsCache_.shipsLost) or 0
    local maxCombo = (battleStatsCache_ and battleStatsCache_.maxCombo) or 0

    -- 资源（显示主要3种精炼资源）
    local metal   = math.floor(rm_.resources.metal   or 0)
    local esource = math.floor(rm_.resources.esource or 0)
    local nuclear = math.floor(rm_.resources.nuclear or 0)
    local rMetal  = math.floor(rm_.rates.metal   or 0)
    local rEsrc   = math.floor(rm_.rates.esource or 0)
    local rNucl   = math.floor(rm_.rates.nuclear or 0)

    -- 成就
    local achUnlocked = #(Achievement.GetUnlocked())
    local achTotal    = Achievement.GetTotal()

    -- 时间
    local played  = math.floor(playTime_ or 0)
    local remain  = math.floor(getRemainingTime())
    local function fmtTime(s)
        local h = math.floor(s/3600)
        local m = math.floor((s%3600)/60)
        local sc= s%60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, sc)
        else           return string.format("%d:%02d", m, sc) end
    end

    -- ④ 6 个数据卡片（2列 × 3行）
    local CARDS = {
        { icon="🌍", title="殖民版图",
          lines = {
            string.format("已殖民: %d / %d", colonized, totalPlanets),
          },
          progress = totalPlanets > 0 and (colonized / totalPlanets) or 0,
          pcolor   = {80, 200, 120},
        },
        { icon="⚔️", title="战斗战绩",
          lines = {
            string.format("击败海盗: %d 波", waves),
            string.format("歼灭: %d  损失: %d 艘", kills, shipsLost),
            maxCombo > 0 and string.format("最高连击: x%d", maxCombo) or "最高连击: 尚无",
          },
        },
        { icon="🔬", title="科技进度",
          lines = {
            string.format("已研究: %d / %d", techResearched, techTotal),
          },
          progress = techTotal > 0 and (techResearched / techTotal) or 0,
          pcolor   = {100, 160, 255},
        },
        { icon="💰", title="经济概览",
          lines = {
            string.format("金属: %d  (+%d/s)", metal,   rMetal),
            string.format("能源: %d  (+%d/s)", esource, rEsrc),
            string.format("核料: %d  (+%d/s)", nuclear, rNucl),
          },
        },
        { icon="🏆", title="成就进度",
          lines = {
            string.format("已解锁: %d / %d", achUnlocked, achTotal),
          },
          progress = achTotal > 0 and (achUnlocked / achTotal) or 0,
          pcolor   = {255, 200, 60},
        },
        { icon="⏱️", title="游戏时间",
          lines = {
            "已游玩: " .. fmtTime(played),
            "剩余时间: " .. fmtTime(remain),
          },
          progress = (BASE_LIMIT + extraTime_) > 0
              and (1 - remain / math.max(1, BASE_LIMIT + extraTime_)) or 0,
          pcolor   = remain < 600 and {255, 100, 100} or {160, 180, 255},
        },
    }

    local COLS   = 2
    local ROWS   = 3
    local CW     = (PW - 32 - (COLS-1)*10) / COLS   -- 卡片宽度
    local CH     = (PH - 56 - (ROWS-1)*8)  / ROWS   -- 卡片高度
    for ci, card in ipairs(CARDS) do
        local col = (ci-1) % COLS
        local row = math.floor((ci-1) / COLS)
        local cx2 = px + 16 + col * (CW + 10)
        local cy2 = py + 46 + row * (CH + 8)

        -- 卡片背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx2, cy2, CW, CH, 7)
        nvgFillColor(vg, nvgRGBA(25, 35, 70, 200))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 90, 160, 120))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 图标+标题
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(140, 170, 255, 220))
        nvgText(vg, cx2 + 8, cy2 + 7, card.icon .. " " .. card.title)

        -- 数据行
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(210, 225, 255, 240))
        local lineY = cy2 + 24
        for _, ln in ipairs(card.lines) do
            nvgText(vg, cx2 + 8, lineY, ln)
            lineY = lineY + 16
        end

        -- 进度条（可选）
        if card.progress then
            local barY  = cy2 + CH - 14
            local barX  = cx2 + 8
            local barW  = CW - 16
            local ratio = math.max(0, math.min(1, card.progress))
            local pc    = card.pcolor or {100, 160, 255}
            -- 背景轨道
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW, 6, 3)
            nvgFillColor(vg, nvgRGBA(40, 50, 90, 200))
            nvgFill(vg)
            -- 填充
            if ratio > 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, barX, barY, barW * ratio, 6, 3)
                nvgFillColor(vg, nvgRGBA(pc[1], pc[2], pc[3], 220))
                nvgFill(vg)
            end
        end
    end

    -- ⑤ 底部提示
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(120, 140, 200, 150))
    nvgText(vg, px + PW * 0.5, py + PH - 5, "按 Tab 或点击遮罩关闭")
end

-- NanoVGRender 主渲染
-- ============================================================================
local function handleNanoVGRender(eventType, eventData)
    local dpr  = getDpr()
    local logW = graphics:GetWidth()  / dpr
    local logH = graphics:GetHeight() / dpr
    screenW_, screenH_ = getScreenSize()   -- 虚拟坐标，同时更新 uiScale_

    nvgBeginFrame(vg_, logW, logH, dpr)   -- 逻辑分辨率（帧缓冲对齐）
    nvgSave(vg_)
    nvgScale(vg_, uiScale_, uiScale_)     -- 虚拟坐标系（所有绘制在此空间内）

    -- 主菜单（最高优先级）
    if mainMenuActive_ then
        renderMainMenu(screenW_, screenH_)
        nvgRestore(vg_)
        nvgEndFrame(vg_)
        return
    end

    -- 难度选择界面（游戏正式开始前全屏覆盖）
    if not difficultyChosen_ then
        renderDifficultyScreen(screenW_, screenH_)
        nvgRestore(vg_)
        nvgEndFrame(vg_)
        return
    end

    if currentScene_ == "battle" then
        BattleScene.Render()
    else
        GalaxyScene.Render()
        GameUI.RenderProgressBars(selectedPlanet_)
    end

    GameUI.RenderTopBar()
    GameUI.RenderSceneTitle()
    GameUI.RenderHUD(lastDt_)   -- P3-2: 传入 dt 驱动全屏战绩页入场动画
    GameUI.RenderNotifications()

    -- P2-3: 局内统计面板（最顶层）
    if statsOpen_ and difficultyChosen_ and not mainMenuActive_ then
        renderStatsPanel(screenW_, screenH_)
    end

    nvgRestore(vg_)
    nvgEndFrame(vg_)
end

-- ============================================================================
-- 广告延时：看完广告后执行
-- ============================================================================
---@diagnostic disable-next-line: undefined-global
local sdk_ = sdk  -- 引擎全局 SDK 对象

-- 安全包装：sdk_ 为 nil 时直接回调失败，避免崩溃和 Loading 永久锁死
local function showRewardAd(callback)
    if not sdk_ then
        callback({ success = false, msg = "广告SDK不可用" })
        return
    end
    sdk_:ShowRewardVideoAd(callback)
end

local function onWatchAdClicked()
    if adWatching_ then return end
    if getAdCount() <= 0 then return end

    adWatching_ = true
    GameUI.Notify("广告加载中，请稍候...", "info")

    showRewardAd(function(result)
        adWatching_ = false
        if result.success then
            extraTime_ = math.min(MAX_EXTRA, extraTime_ + EXTRA_PER_AD)
            local newAdCount = getAdCount()
            GameUI.UpdateTimeoutAdCount(newAdCount)
            GameUI.Notify(
                "广告观看完成！已延长1小时。剩余可延长次数：" .. newAdCount,
                "success"
            )
            if getRemainingTime() > 0 then
                -- 恢复游戏
                timeoutTriggered_ = false
                GameUI.HideTimeoutScreen()
            end
        else
            GameUI.Notify("广告未完整观看 (" .. (result.msg or "") .. ")，无法获得奖励", "warn")
        end
    end)
end

local function handleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    lastDt_ = dt   -- 保存帧时间，供 NanoVGRender 传给 RenderHUD

    Audio.Update(dt)

    -- P3-3: 菜单阶段时间累计（驱动粒子背景动画）
    if not difficultyChosen_ then
        menuT_ = menuT_ + dt
        -- P1-1: 光标闪烁计时器
        if nicknameInputActive_ then
            nicknameCursorT_ = nicknameCursorT_ + dt
        end
        return
    end

    -- ---- 总游戏时长（结算统计用，不受超时暂停影响）----
    if not endGameTriggered_ then
        totalPlayTime_ = totalPlayTime_ + dt
    end

    -- ---- 游戏时间追踪（无尽模式跳过超时限制）----
    if not timeoutTriggered_ and not isEndlessMode_ then
        playTime_ = playTime_ + dt
        local secRemaining = math.floor(getRemainingTime())
        if secRemaining ~= lastShownRemaining_ then
            lastShownRemaining_ = secRemaining
            GameUI.SetRemainingTime(secRemaining)
        end

        -- 检测超时
        if getRemainingTime() <= 0 then
            timeoutTriggered_ = true
            -- 显示超时覆盖层
            GameUI.ShowTimeoutScreen(getAdCount(), onWatchAdClicked)
            print("[Client] 游戏时间到期")
        end

        -- 剩余30分钟提示
        local remaining = getRemainingTime()
        if remaining <= 1800 and remaining > 1798 then
            GameUI.Notify("在线时间剩余30分钟，观看广告可延长1小时", "warn")
        elseif remaining <= 300 and remaining > 298 then
            GameUI.Notify("警告：在线时间仅剩5分钟！", "error")
        end
    end

    rm_:update(dt)
    ms_:update(dt)

    -- P1-1: 外交系统 tick（贸易收益 + 宣战衰减 + 殖民清除）
    if ds_ and currentScene_ == "galaxy" and not endGameTriggered_ then
        local dipEvts = ds_:tick(dt, rm_, GalaxyScene.GetAllPlanets())
        for _, ev in ipairs(dipEvts or {}) do
            GameUI.Notify(ev.msg, ev.msgType or "info")
        end
    end

    -- P2-1: 资源危机预警（节流：每 5 秒检查一次，每种资源每局只提示一次）
    resWarnTimer_ = (resWarnTimer_ or 0) + dt
    if resWarnTimer_ >= 5 and not endGameTriggered_ then
        resWarnTimer_ = 0
        local warnCfg = {
            metal   = { min=200, msg="⚠️ 金属储量不足（<200）！建议建造矿石精炼厂或殖民矿物星球" },
            esource = { min=100, msg="⚠️ 能源储量不足（<100）！建议研究太阳能效率或殖民海洋星球" },
            nuclear = { min=50,  msg="⚠️ 核能储量不足（<50）！建议研究深层采矿或殖民火山星球" },
        }
        for res, cfg in pairs(warnCfg) do
            if (rm_.resources[res] or 0) < cfg.min and not lowResWarnSent_[res] then
                lowResWarnSent_[res] = true
                GameUI.Notify(cfg.msg, "warn")
            end
        end
    end

    -- 资源里程碑成就检查（节流：每 10 秒检查一次）
    resMilestoneTimer_ = resMilestoneTimer_ + dt
    if resMilestoneTimer_ >= 10 then
        resMilestoneTimer_ = 0
        Achievement.Check("resource_milestone", {
            metal   = rm_.resources.metal   or 0,
            esource = rm_.resources.esource or 0,
            nuclear = rm_.resources.nuclear or 0,
        })
    end

    -- P3-3: DDA 定期微调（每 EVAL_INTERVAL 秒检查一次基地 HP）
    dda_.evalTimer = dda_.evalTimer + dt
    if dda_.evalTimer >= dda_.EVAL_INTERVAL then
        dda_.evalTimer = 0
        ddaPeriodicCheck()
    end

    -- P3-2: 产量历史采样（每 30 秒采集一次所有已殖民星球的产量）
    prodSampleTimer_ = prodSampleTimer_ + dt
    if prodSampleTimer_ >= PROD_SAMPLE_INTERVAL then
        prodSampleTimer_ = 0
        local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
        local base    = GalaxyScene.GetBase and GalaxyScene.GetBase()
        -- 也采样基地
        local allPlanets = {}
        for _, p in ipairs(planets) do allPlanets[#allPlanets+1] = p end
        if base and base.colonized then allPlanets[#allPlanets+1] = base end
        for _, p in ipairs(allPlanets) do
            local key = p.name or ""
            if key ~= "" then
                if not planetProdHistory_[key] then
                    planetProdHistory_[key] = { minerals={}, energy={}, crystal={} }
                end
                -- 汇总该星球本次产量
                local sum = { minerals=0, energy=0, crystal=0 }
                for _, b in ipairs(p.buildings or {}) do
                    for res, val in pairs(b.currentProd or {}) do
                        if sum[res] ~= nil then sum[res] = sum[res] + val end
                    end
                end
                local hist = planetProdHistory_[key]
                for _, res in ipairs({"minerals","energy","crystal"}) do
                    hist[res][#hist[res]+1] = sum[res]
                    -- 超出上限时移除最旧点
                    if #hist[res] > PROD_MAX_SAMPLES then
                        table.remove(hist[res], 1)
                    end
                end
            end
        end
    end

    -- 自动存档（H3 修复：去掉 serverConn_ 判断，单机模式也会自动存档）
    saveTimer_ = saveTimer_ + dt
    if saveTimer_ >= AUTO_SAVE_INTERVAL then
        saveTimer_ = 0
        saveGame()
    end

    local techDone = rs_:update(dt)
    if techDone then
        Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
        totalResearch_ = totalResearch_ + 1
        Achievement.Check("research_complete", {
            totalResearch = totalResearch_,
            unlockedTechs = rs_.unlocked,   -- P2-3: hidden_full_tech 需要完整解锁表
        })
        GameUI.Notify("科技完成: " .. TECHS[techDone].name, "success")
        GameUI.TriggerTechComplete(techDone)  -- P1-2: 粒子特效
        GameUI.RefreshTechPanel()
        checkStageGoals()   -- 科技完成后检查阶段目标
        saveGame()   -- 科技完成立即存档
    end

    local shipDone = spq_:update(dt)
    if shipDone then
        local st = SHIP_TYPES[shipDone.shipType]
        fm_:addToReserve(shipDone.shipType)
        totalShipsBuilt_ = totalShipsBuilt_ + 1
        shipTypeBuilt_[shipDone.shipType] = (shipTypeBuilt_[shipDone.shipType] or 0) + 1
        Audio.Play(Audio.SFX.BUILD_COMPLETE)
        GalaxyScene.InvalidateFleetColor(activeFleetId_)  -- 储备池变化，主编队颜色可能改变
        GameUI.Notify("舰船建造完成: " .. st.name .. "  → 已进入储备池", "success")
        -- 成就检查：首次造船、累计造船数、母舰成就
        Achievement.Check("ship_built", {
            totalShipsBuilt = totalShipsBuilt_,
            lastBuiltType   = shipDone.shipType,
        })
        GameUI.RefreshFleetPanel(fm_, activeFleetId_)
        GameUI.RefreshReservePanel(fm_)
        GameUI.RefreshShipyardPanel()
        checkStageGoals()   -- 造船完成后检查阶段目标
    end

    if currentScene_ == "battle" then
        BattleScene.Update(dt)
    end

    if currentScene_ == "galaxy" then
        GalaxyScene.Update(dt)
        -- 行星建造队列更新（仅遍历已殖民行星，跳过全量扫描）
        for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
            local done = bs_:update(dt, p)
            if done then
                Audio.Play(Audio.SFX.BUILD_COMPLETE)
                -- 建筑完工后重新应用星球特产加成（新建筑产量已进入 rates，需要同步加成 delta）
                applyPlanetTypeBonus(p)
                GameUI.Notify("建造完成: " .. BUILDINGS[done].name, "success")
                GameUI.RefreshPlanetPanel(GalaxyScene.GetSelected())
                if done == "SHIPYARD" then GameUI.SetShipyardBuilt(true) end
                saveGame()   -- 建造完成立即存档
            end
        end
        -- 基地模块建造队列更新（独立系统）
        local base = GalaxyScene.GetBase()
        if base and base.colonized then
            local done = bbs_:update(dt, base)
            if done then
                if done == "__CORE_UPGRADE__" then
                    -- 核心等级升级完成（base.coreLevel 已在 update 内写入新值）
                    Audio.Play(Audio.SFX.BUILD_COMPLETE)
                    local newLv = base.coreLevel or 1
                    local unlocked = BASE_CORE_UNLOCK_PREVIEW[newLv] or {}
                    local names = {}
                    for _, k in ipairs(unlocked) do
                        names[#names+1] = BASE_MODULES[k] and BASE_MODULES[k].name or k
                    end
                    local unlockStr = #names > 0 and ("解锁: " .. table.concat(names, " / ")) or ""
                    -- Lv.2 额外提示：解锁原矿精炼能力（矿石/能量块/水晶 → 精炼资源）
                    if newLv == 2 then
                        unlockStr = unlockStr .. "  ＋基础精炼能力（0.3×）"
                    end
                    GameUI.Notify("★ 核心升级完成！已达 Lv." .. newLv
                        .. (#unlockStr > 0 and "  " .. unlockStr or ""), "success")
                    markBaseEffectsDirty()
                    applyBaseModuleEffects()   -- 核心升级后重算模块效果（含编队上限）
                    checkStageGoals()          -- 核心升级后检查阶段目标
                    saveGame()
                else
                    Audio.Play(Audio.SFX.BUILD_COMPLETE)
                    local modName = BASE_MODULES[done] and BASE_MODULES[done].name or done
                    GameUI.Notify("模块安装完成: " .. modName, "success")
                    if done == "SHIPYARD" then GameUI.SetShipyardBuilt(true) end
                    markBaseEffectsDirty()
                    applyBaseModuleEffects()   -- 应用新模块效果
                    checkStageGoals()          -- 模块完成后检查阶段目标
                    saveGame()   -- 基地模块完成立即存档
                end
            end
            local sel = GalaxyScene.GetSelected()
            if sel and sel.isBase then
                GameUI.RefreshPlanetPanel(base)
            end
        end
    end

    -- P1-2 WARP_GATE_PRIME: 瞬移冷却倒计时（任意场景均需递减）
    if rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGatePrime then
        local cd = rm_.baseBonus.warpGatePrimeCooldown or 0
        if cd > 0 then
            rm_.baseBonus.warpGatePrimeCooldown = math.max(0, cd - dt)
        end
    end

    GameUI.UpdateNotifications(dt)
    Achievement.Update(dt)   -- 成就合并通知刷新

    -- 探索任务进度更新
    updateExplorerTasks(dt)

    -- 海盗进攻预警：每帧更新最近倒计时
    if pirateAI_ then
        local minT = math.huge
        for _, b in ipairs(pirateAI_.bases) do
            if b.active and b.attackTimer and b.attackTimer < minT then
                minT = b.attackTimer
            end
        end
        GameUI.SetPirateWarning(minT)
        -- 首次进入预警阈值时播放音效
        if minT <= 30 and not pirateWarnPlayed_ then
            pirateWarnPlayed_ = true
            Audio.Play(Audio.SFX.PIRATE_WARNING)
        elseif minT > 30 then
            pirateWarnPlayed_ = false  -- 威胁解除后重置，下次可再次触发
        end
    end

    refreshTimer_ = refreshTimer_ + dt
    if refreshTimer_ >= 0.5 then
        refreshTimer_ = 0
        GameUI.RefreshResourceBar()
        local sel = GalaxyScene.GetSelected()
        if sel and currentScene_ == "galaxy" then
            GameUI.RefreshPlanetPanel(sel)
        end
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================
local function handleMouseButtonDown(eventType, eventData)
    if mainMenuActive_ then return end
    local btn = eventData["Button"]:GetInt()
    if btn ~= MOUSEB_LEFT then return end
    local dpr = getDpr()
    local mx  = eventData["X"]:GetInt() / dpr / uiScale_
    local my  = eventData["Y"]:GetInt() / dpr / uiScale_

    -- P2-3: 统计面板打开时，点击任意位置关闭（面板内的关闭按钮优先）
    if statsOpen_ then
        local PW, PH = 620, 430
        local px = (screenW_ - PW) * 0.5
        local py = (screenH_ - PH) * 0.5
        local closeX = px + PW - 20
        local closeY = py + 18
        -- 点击面板外 或 点击关闭按钮 → 关闭面板
        local insidePanel = mx >= px and mx <= px+PW and my >= py and my <= py+PH
        local onCloseBtn  = math.sqrt((mx-closeX)^2 + (my-closeY)^2) < 14
        if not insidePanel or onCloseBtn then
            statsOpen_ = false
        end
        return   -- 面板打开时吞掉所有点击
    end

    -- P1-1: 难度选择屏幕 - 昵称输入框点击激活/失活
    if not difficultyChosen_ then
        local ni = ClientMenus.GetNicknameInputLayout(screenW_, screenH_)
        if mx >= ni.x and mx <= ni.x + ni.w and my >= ni.y and my <= ni.y + ni.h then
            nicknameInputActive_ = true
            input.textInputEnabled = true   -- 打开系统软键盘（移动端）
            return
        else
            nicknameInputActive_ = false
            input.textInputEnabled = false
        end
    end

    -- P1-2: 难度选择屏幕 - 自定义滑块拖拽检测
    if not difficultyChosen_ and getCustomPanelVisible() then
        local sliders = getCustomSliderRects(screenW_, screenH_)
        for _, sl in ipairs(sliders) do
            local rawVal = customDiff_[sl.name]
            local norm   = (rawVal - sl.vmin) / (sl.vmax - sl.vmin)
            norm = math.max(0, math.min(1, norm))
            local handleX = sl.x + norm * sl.w
            local handleY = sl.y + sl.h / 2
            -- 检测是否点击了滑块手柄（12px 热区）或轨道
            if math.abs(my - handleY) <= 12 and mx >= sl.x - 10 and mx <= sl.x + sl.w + 10 then
                customDiffSlider_  = sl.name
                customDiffSliderX0_ = sl.x
                customDiffSliderW_  = sl.w
                -- 立即更新值到点击位置
                local newNorm = math.max(0, math.min(1, (mx - sl.x) / sl.w))
                if sl.name == "maxThreat" then
                    customDiff_.maxThreat = math.floor(sl.vmin + newNorm * (sl.vmax - sl.vmin) + 0.5)
                elseif sl.name == "initResBonus" then
                    local raw = sl.vmin + newNorm * (sl.vmax - sl.vmin)
                    customDiff_.initResBonus = math.floor(raw / 50 + 0.5) * 50  -- 50 步进
                else
                    customDiff_.attackFactor = sl.vmin + newNorm * (sl.vmax - sl.vmin)
                    customDiff_.attackFactor = math.floor(customDiff_.attackFactor * 10 + 0.5) / 10
                end
                return
            end
        end
        return  -- 在难度屏幕但未点击滑块，不传递给游戏
    end

    if not difficultyChosen_ then return end
    if currentScene_ == "galaxy" then GalaxyScene.OnMouseDown(mx, my) end
end

local function handleMouseButtonUp(eventType, eventData)
    local btn = eventData["Button"]:GetInt()
    if btn ~= MOUSEB_LEFT then return end
    local dpr = getDpr()
    local mx  = eventData["X"]:GetInt() / dpr / uiScale_
    local my  = eventData["Y"]:GetInt() / dpr / uiScale_
    -- 主菜单点击
    if mainMenuActive_ then
        local hit = getMainMenuHit(mx, my, screenW_, screenH_)
        print(string.format("[Mouse] mainMenu click: mx=%.1f my=%.1f hit=%s", mx, my, tostring(hit)))
        if hit then onMainMenuSelect(hit) end
        return
    end
    -- 难度选择屏幕点击
    if not difficultyChosen_ then
        -- P1-2: 如果正在拖拽滑块，松手时结束拖拽
        if customDiffSlider_ then
            customDiffSlider_ = nil
            return
        end
        local hit = getDifficultyHit(mx, my, screenW_, screenH_)
        if hit == "endless" then
            onEndlessModeSelect()
        elseif hit then
            onDifficultySelect(hit)
        end
        return
    end
    if GameUI.OnClick(mx, my) then return end
    if currentScene_ == "battle" then
        BattleScene.OnClick(mx, my)
    else
        GalaxyScene.OnMouseUp(mx, my)
    end
end

local function handleMouseMove(eventType, eventData)
    local dpr = getDpr()
    local mx  = eventData["X"]:GetInt() / dpr / uiScale_
    local my  = eventData["Y"]:GetInt() / dpr / uiScale_
    -- P2-3: 更新统计面板鼠标坐标（用于关闭按钮 hover 渲染）
    statsMouseX_, statsMouseY_ = mx, my
    -- 主菜单悬停
    if mainMenuActive_ then
        mainMenuHover_ = getMainMenuHit(mx, my, screenW_, screenH_)
        return
    end
    -- 难度选择屏幕悬停
    if not difficultyChosen_ then
        -- P1-2: 如果正在拖拽滑块，更新值
        if customDiffSlider_ then
            local norm = math.max(0, math.min(1, (mx - customDiffSliderX0_) / customDiffSliderW_))
            -- 找到当前滑块的 vmin/vmax
            local sliders = getCustomSliderRects(screenW_, screenH_)
            for _, sl in ipairs(sliders) do
                if sl.name == customDiffSlider_ then
                    if sl.name == "maxThreat" then
                        customDiff_.maxThreat = math.floor(sl.vmin + norm * (sl.vmax - sl.vmin) + 0.5)
                    elseif sl.name == "initResBonus" then
                        local raw = sl.vmin + norm * (sl.vmax - sl.vmin)
                        customDiff_.initResBonus = math.floor(raw / 50 + 0.5) * 50
                    else
                        local raw = sl.vmin + norm * (sl.vmax - sl.vmin)
                        customDiff_.attackFactor = math.floor(raw * 10 + 0.5) / 10
                    end
                    break
                end
            end
            return
        end
        diffHoverBtn_ = getDifficultyHit(mx, my, screenW_, screenH_)
        return
    end
    if currentScene_ == "galaxy" then GalaxyScene.OnMouseMove(mx, my) end
end

local function handleMouseWheel(eventType, eventData)
    if not difficultyChosen_ then return end
    if currentScene_ ~= "galaxy" then return end
    local dpr   = getDpr()
    local wheel = eventData["Wheel"]:GetInt()
    local pos   = input:GetMousePosition()
    local mx    = pos.x / dpr / uiScale_
    local my    = pos.y / dpr / uiScale_
    if GameUI.OnScroll(mx, my, wheel) then return end
    GalaxyScene.OnMouseWheel(mx, my, wheel)
end

local function handleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    -- P1-1: 昵称输入框激活时处理退格/回车/Escape
    if nicknameInputActive_ then
        if key == KEY_BACKSPACE then
            -- UTF-8 退格：找到最后一个字符边界并删除
            local s = playerName_
            if #s > 0 then
                local lastStart = 1
                local i = 1
                while i <= #s do
                    lastStart = i
                    local b = s:byte(i)
                    if b < 0x80 then i = i + 1
                    elseif b < 0xE0 then i = i + 2
                    elseif b < 0xF0 then i = i + 3
                    else i = i + 4 end
                end
                playerName_ = s:sub(1, lastStart - 1)
            end
            return
        elseif key == KEY_RETURN or key == KEY_ESCAPE then
            nicknameInputActive_ = false
            return
        end
        return  -- 其他按键交给 TextInput 事件处理
    end
    if not difficultyChosen_ then return end
    -- 飞船展开前：WASD/方向键/空格键全部转发给 GalaxyScene
    if currentScene_ == "galaxy" and not GalaxyScene.IsDeployed() then
        GalaxyScene.OnKeyDown(key)
        return  -- 展开前不响应场景切换等快捷键
    end
    -- P2-3: Tab 键切换局内统计面板
    if key == KEY_TAB then
        if currentScene_ == "galaxy" or currentScene_ == "battle" then
            statsOpen_ = not statsOpen_
        end
        return
    end

    -- P3-2: G 键打开生涯战绩全屏页面
    if key == KEY_G then
        if currentScene_ == "galaxy" and difficultyChosen_ and not mainMenuActive_ then
            GameUI.ShowCareerPage()
        end
        return
    end

    -- Escape 同时关闭统计面板
    if key == KEY_ESCAPE then
        if statsOpen_ then
            statsOpen_ = false
            return
        end
        if explorerColonizeMode_ then
            explorerColonizeMode_ = false
            GameUI.SetExplorerColonizeMode(false)
            GameUI.Notify("已取消探索模式", "info")
            return
        end
    end

end

local function handleKeyUp(eventType, eventData)
    if not difficultyChosen_ then return end
    local key = eventData["Key"]:GetInt()
    GalaxyScene.OnKeyUp(key)
end

-- ============================================================================
-- 场景与UI初始化（供 Start 和 softReset 复用）
-- ============================================================================
setupSceneAndUI = function()
    -- 读取当前难度配置
    local diffCfg = DIFFICULTY_CONFIGS[difficulty_] or DIFFICULTY_CONFIGS["normal"]

    -- P3-3: 初始化 DDA 状态（基于选定难度的基准倍率）
    dda_.enabled       = (difficulty_ ~= "custom")
    dda_.baseFactor    = diffCfg.attackFactor
    dda_.currentFactor = diffCfg.attackFactor
    dda_.recentResults = {}
    dda_.evalTimer     = 0
    dda_.adjustCount   = 0

    -- 初始化海盗 AI（generateBases 由 GalaxyScene.Init 内部调用）
    pirateAI_ = PirateAI.new({
        notifyFn           = GameUI.Notify,
        onAttack           = onPirateAttack,
        getTargets         = getPlayerTargets,
        attackIntervalFactor = dda_.currentFactor,   -- P3-3: 使用 DDA 当前值
        maxThreatLevel       = diffCfg.maxThreat,
        getProgress = function()
            local colonized = 0
            local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
            for _, p in ipairs(planets) do
                if p.colonized then colonized = colonized + 1 end
            end
            return {
                colonized     = colonized,
                gameTime      = playTime_,
                piratesKilled = piratesKilled_,
            }
        end,
    })

    -- 初始化游戏场景
    GalaxyScene.Init({
        vg             = vg_,
        bs             = bs_,
        rm             = rm_,
        fm             = fm_,
        player         = player_,
        notifyFn       = GameUI.Notify,
        onPlanetSelect = onPlanetSelect,
        onFleetSelect  = function(fleetId)
            -- 地图上点击编队图标：同步到 UI 面板选中状态（含地图选中橙色高亮）
            activeFleetId_ = fleetId  -- nil 也允许（取消选中）
            GameUI.RefreshFleetPanel(fm_, fleetId)
            GameUI.SetMapSelectedFleet(fleetId)  -- 更新 tab 橙色高亮
        end,
        onFleetContactPlanet = function(fleetId, planet)
            -- 含探索舰的编队到达未殖民行星 → 进入殖民选择模式
            if not fleetHasExplorer(fleetId) then return end
            if planet.colonized then return end
            -- 自动选中该行星并触发殖民
            selectedPlanet_ = planet
            GameUI.RefreshPlanetPanel(planet)
            local ok = doColonize(planet)
            if ok then
                -- 消耗编队中一艘探索舰
                fm_:removeShip(fleetId, "EXPLORER")
                GameUI.RefreshFleetPanel(fm_, fleetId)
            else
                GameUI.Notify("编队抵达 " .. planet.name .. " — 点击面板探索或继续前进", "info")
            end
        end,
        onSeedDeploy   = function(wx, wy, base)
            Audio.Play(Audio.SFX.FLEET_DEPLOY)
            -- 飞船展开完成：解锁全部 UI 面板
            GameUI.SetDeployed(true)
            -- 选中基地，显示模块建造面板（base.colonized 已由 GalaxyScene 设为 true）
            selectedPlanet_ = base
            GameUI.ShowScene("galaxy", true)
            GameUI.RefreshPlanetPanel(base)
            -- 新玩家首次展开基地：赠予 4 艘工程舰（储备池为空时视为新玩家）
            local totalReserve = 0
            if fm_.reserve then
                for _, n in pairs(fm_.reserve) do totalReserve = totalReserve + n end
            end
            if totalReserve == 0 then
                for i = 1, 4 do fm_:addToReserve("ENGINEER") end
                GameUI.RefreshReservePanel(fm_)
                GameUI.Notify("星航基地已建立！获得 4 艘工程舰，可在右侧面板建造功能模块", "success")
            else
                GameUI.Notify("星航基地已建立！可在右侧面板建造功能模块", "success")
            end
        end,
        pirateAI = pirateAI_,
        onFleetContactPirateBase = onFleetSiegeBase,
        onFleetMove = function() Audio.Play(Audio.SFX.FLEET_MOVE) end,
        onGalaxyEvent = function(ev)
            local GalaxyEvents = require("game.GalaxyEvents")
            -- P2-1: 强制事件 — 无选项，直接触发效果
            if ev.isForced and ev.forcedEffect then
                local fe = ev.forcedEffect
                if fe.buffKey and fe.buffDur then
                    GalaxyEvents.AddBuff(fe.buffKey, fe.buffDur, fe.magnitude or 1.0,
                        ev.label)
                end
                if fe.specialAction == "ROGUE_AI_SPAWN" then
                    -- 叛乱AI：对最近编队施加短暂减速惩罚（简化实现：debuff 60s）
                    GalaxyEvents.AddBuff("FLEET_SLOW", 60, 0.30, "叛乱AI干扰")
                end
                GameUI.Notify(ev.icon .. " " .. (fe.notifyMsg or ev.label), fe.notifyType or "danger")
                return
            end
            -- P2-1: 被动事件 — 无选项，自动激活增益
            if ev.isPassive and ev.passiveEffect then
                local pe = ev.passiveEffect
                if pe.buffKey and pe.buffDur then
                    GalaxyEvents.AddBuff(pe.buffKey, pe.buffDur, pe.magnitude or 1.0,
                        ev.label)
                end
                GameUI.Notify(ev.icon .. " " .. (pe.notifyMsg or ev.label), pe.notifyType or "success")
                return
            end
            -- 普通选择事件
            GameUI.ShowEventPopup(ev, function(choiceIdx)
                local ch = ev.choices[choiceIdx]
                if not ch then return end
                if ch.cost then
                    for res, val in pairs(ch.cost) do
                        if (rm_:get(res) or 0) < val then
                            GameUI.Notify("资源不足，无法选择该选项", "error"); return
                        end
                    end
                    for res, val in pairs(ch.cost) do rm_:add(res, -val) end
                end
                local parts = {}
                if ch.gain then
                    for res, val in pairs(ch.gain) do
                        rm_:add(res, val); parts[#parts+1] = res .. "+" .. val
                    end
                end
                -- P2-1: 随机范围奖励（如 CRYSTAL_SURGE）
                if ch.gainRandom then
                    for res, range in pairs(ch.gainRandom) do
                        local val = range[1] + math.random(0, range[2] - range[1])
                        rm_:add(res, val); parts[#parts+1] = res .. "+" .. val
                    end
                end
                if ch.res and ch.amount and ch.amount > 0 then
                    rm_:add(ch.res, ch.amount); parts[#parts+1] = ch.res .. "+" .. ch.amount
                end
                if ch.hpLoss then
                    local loss = 20
                    rm_:add("minerals", -math.min(loss, rm_:get("minerals") or 0))
                    parts[#parts+1] = "矿石-" .. loss .. "(辐射损耗)"
                end
                -- P1-3: 护盾受损（危机事件撤离惩罚）
                if ch.shieldLoss then
                    local shieldPenalty = 30
                    rm_:add("esource", -math.min(shieldPenalty, rm_:get("esource") or 0))
                    parts[#parts+1] = "能源-" .. shieldPenalty .. "(护盾受损)"
                end
                if ch.expGain and ch.expGain > 0 then
                    player_.exp = (player_.exp or 0) + ch.expGain
                    parts[#parts+1] = "EXP+" .. ch.expGain
                end
                -- P1-3: 链式事件触发
                if ch.chainEvent then
                    GalaxyEvents.ScheduleChain(ch.chainEvent, ev.x, ev.y)
                    parts[#parts+1] = "⛓ 链式事件已触发"
                end
                -- P2-1: 选项级 buff 激活（如 DERELICT_SHIP 修复引擎、PIRATE_DEFECTOR 收编）
                if ch.buffKey and (ch.buffDur or 0) > 0 then
                    GalaxyEvents.AddBuff(ch.buffKey, ch.buffDur,
                        ch.buffAmt or 1.0, ev.label)
                    local buffNames = {
                        SHIELD_BOOST = "临时护盾+",
                        TEMP_FLEET   = "临时舰船+",
                    }
                    parts[#parts+1] = (buffNames[ch.buffKey] or ch.buffKey) ..
                        string.format("%ds", ch.buffDur)
                end
                -- P2-1: 特殊行动
                if ch.specialAction == "BOUNTY_KILL" then
                    -- 赏金猎人：消灭一个海盗基地（随机选最弱的）
                    if pirateAI_ and #pirateAI_.bases > 0 then
                        local weakest = nil
                        for _, b in ipairs(pirateAI_.bases) do
                            if b.active and (not weakest or b.level < weakest.level) then
                                weakest = b
                            end
                        end
                        if weakest then
                            weakest.active = false
                            parts[#parts+1] = "已消灭海盗基地 Lv" .. weakest.level
                        end
                    end
                elseif ch.specialAction == "ARTIFACT_RESEARCH" then
                    -- 异星文物：随机大奖励
                    local roll = math.random(3)
                    if roll == 1 then
                        rm_:add("crystal", 200); parts[#parts+1] = "晶石+200（随机奖励）"
                    elseif roll == 2 then
                        player_.exp = (player_.exp or 0) + 300
                        parts[#parts+1] = "EXP+300（随机奖励）"
                    else
                        rm_:add("nuclear", 120); rm_:add("esource", 120)
                        parts[#parts+1] = "核能+120 能源+120（随机奖励）"
                    end
                elseif ch.specialAction == "TECH_BOOST" then
                    -- 古代遗迹 解码数据核心：加速当前科技研究 20%
                    -- 通过缩短 spq_（生产队列）中第一个科研任务的剩余时间实现
                    if spq_ and spq_.queue and #spq_.queue > 0 then
                        local q0 = spq_.queue[1]
                        if q0.timeLeft then
                            q0.timeLeft = q0.timeLeft * 0.80
                            parts[#parts+1] = "科研进度+20%"
                        end
                    else
                        -- 无在研任务时改为给予经验
                        player_.exp = (player_.exp or 0) + 100
                        parts[#parts+1] = "EXP+100（无在研科技）"
                    end
                end
                -- P1-2 V2.0: 灾害事件惩罚（最差选项扣除资源）
                if ch.penalty then
                    for res, val in pairs(ch.penalty) do
                        local cur  = rm_:get(res) or 0
                        local loss = math.min(val, cur)
                        if loss > 0 then
                            rm_:add(res, -loss)
                            parts[#parts+1] = res .. "-" .. loss .. "(灾害损失)"
                        end
                    end
                end
                if #parts > 0 then
                    GameUI.Notify(ev.label .. "：" .. table.concat(parts, "  "), "success")
                else
                    GameUI.Notify(ev.label .. "：已处理", "info")
                end
            end)
        end,
    })
    rs_:setPlanetGetter(GalaxyScene.GetAllPlanets)

    -- P1-1: 初始化外交系统（GalaxyScene.Init 后才有行星数据）
    ds_ = Sys.DiplomacySystem.new()
    ds_:initFactions(GalaxyScene.GetAllPlanets(), 0.35)
    print(string.format("[Client] 外交系统初始化完成"))

    -- P1-3: 注册危机事件超时惩罚回调
    local GalaxyEvents = require("game.GalaxyEvents")
    GalaxyEvents.onCrisisExpired = function(ev)
        local penalty = 40
        rm_:add("esource", -math.min(penalty, rm_:get("esource") or 0))
        GameUI.Notify("⚡ " .. ev.label .. " 超时未处理！能源 -" .. penalty, "error")
        print(string.format("[Crisis] 危机事件 %s 超时，能源惩罚 -%d", ev.typeKey, penalty))
    end
    GameUI.Init({
        vg              = vg_,
        rm              = rm_,
        bs              = bs_,
        bbs             = bbs_,
        rs              = rs_,
        ms              = ms_,
        player          = player_,
        spq             = spq_,
        fm              = fm_,
        pirateAI        = pirateAI_,   -- P1-3: 情报面板数据源
        onBuildCb       = onBuildCb,
        onBaseBuildCb   = onBaseBuildCb,
        onCoreUpgradeCb = onCoreUpgradeCb,
        onResearchCb    = onResearchCb,
        onMarketCb      = onMarketCb,
        onExchangeCb    = function(fromRes, toRes)
            local ok, result = rm_:exchange(fromRes, toRes)
            if ok then
                local fromLabel = RES_LABELS[fromRes]
                local toLabel   = RES_LABELS[toRes]
                GameUI.Notify(fromLabel .. " -" .. EXCHANGE_AMOUNT ..
                    "  →  " .. toLabel .. " +" .. result, "success")
            else
                GameUI.Notify("互换失败: " .. (result or ""), "error")
            end
        end,
        onShipQueueCb          = onShipQueueCb,
        onShipCancelCb         = onShipCancelCb,
        onShipPromoteCb        = onShipPromoteCb,
        onExplorerColonizeCb   = onExplorerColonizeCb,
        onExplorerTaskCb       = startExplorerTask,
        explorerTasks          = explorerTasks_,
        onFleetSelectCb = function(selectedFid)
            activeFleetId_ = selectedFid
            GameUI.RefreshFleetPanel(fm_, selectedFid)
            -- 同步地图上的编队选中状态，使点击地图空地可直接移动该编队
            GalaxyScene.SelectFleet(selectedFid)
        end,
        onFleetMoveShipCb = function(srcId, dstId, shipType)
            local ok, reason = fm_:moveShip(srcId, dstId, shipType)
            if ok then
                GalaxyScene.InvalidateFleetColor(srcId)   -- 舰船移出，源编队颜色可能改变
                GalaxyScene.InvalidateFleetColor(dstId)   -- 舰船移入，目标编队颜色可能改变
                GameUI.Notify("已将 " .. SHIP_TYPES[shipType].name ..
                    " 从编队" .. srcId .. " 移入编队" .. dstId, "success")
                GameUI.RefreshFleetPanel(fm_, activeFleetId_)
            else
                GameUI.Notify("移动失败: " .. (reason or ""), "error")
            end
        end,
        onAssignReserveCb = function(shipType)
            local ok, reason = fm_:assignFromReserve(shipType, activeFleetId_)
            if ok then
                GalaxyScene.InvalidateFleetColor(activeFleetId_)  -- 舰船加入编队，颜色可能改变
                GameUI.Notify(SHIP_TYPES[shipType].name .. " 已加入编队 " .. activeFleetId_, "success")
                GameUI.RefreshFleetPanel(fm_, activeFleetId_)
                GameUI.RefreshReservePanel(fm_)
            else
                GameUI.Notify("加入编队失败: " .. (reason or ""), "warn")
            end
        end,
        -- 星币加速建造：M6 修复：1★/10秒，上限50★，最少5★
        onSpeedUpBuildCb = function(target)
            -- target 是 planet 或 base 对象
            if not target or not target.constructing then
                GameUI.Notify("当前没有建造中的项目", "warn"); return
            end
            local remaining = target.constructing.remaining or 0
            if remaining <= 0 then GameUI.Notify("已接近完成", "info"); return end
            local cost = math.max(5, math.min(50, math.ceil(remaining / 10)))  -- 1★/10s，上限50★
            if not rm_:canAfford({ credits = cost }) then
                GameUI.Notify("星币不足（需要 ★" .. cost .. "）", "error"); return
            end
            rm_:spend({ credits = cost })
            target.constructing.remaining = 0
            target.constructing.progress  = 1.0
            GameUI.Notify("★ 使用 " .. cost .. " 星币立即完成建造！", "success")
            GameUI.RefreshPlanetPanel(target)
        end,
        -- 星币购买核能（市场快速入口）
        onBuyNuclearCb = function(amount)
            local pricePerUnit = (ms_ and ms_.rates and ms_.rates.nuclear and ms_.rates.nuclear.buy) or 10.0
            local totalCost = math.ceil(amount * pricePerUnit)
            if not rm_:canAfford({ credits = totalCost }) then
                GameUI.Notify("星币不足（需要 ★" .. totalCost .. "）", "error"); return
            end
            rm_:spend({ credits = totalCost })
            rm_:add("nuclear", amount)
            GameUI.Notify("购买核能×" .. amount .. "  消耗 ★" .. totalCost, "success")
            GameUI.RefreshResourceBar()
        end,
        -- 全部征收：对所有已殖民星球按建筑产量给予一次性奖励（= 60s 产量）
        onHarvestAllCb = function()
            local planets = GalaxyScene.GetColonizedPlanets()
            if not planets or #planets == 0 then
                GameUI.Notify("没有已殖民的星球", "warn"); return
            end
            local gain = { minerals=0, energy=0, crystal=0 }
            for _, p in ipairs(planets) do
                if not p.isBase then
                    for _, b in ipairs(p.buildings) do
                        if b.currentProd then
                            for res, val in pairs(b.currentProd) do
                                if gain[res] then
                                    gain[res] = gain[res] + val * 60  -- 60s 产量
                                end
                            end
                        end
                    end
                end
            end
            local parts = {}
            if gain.minerals > 0 then rm_:add("minerals", gain.minerals); parts[#parts+1] = "矿石+" .. gain.minerals end
            if gain.energy   > 0 then rm_:add("energy",   gain.energy);   parts[#parts+1] = "能量块+" .. gain.energy end
            if gain.crystal  > 0 then rm_:add("crystal",  gain.crystal);  parts[#parts+1] = "水晶+" .. gain.crystal end
            if #parts > 0 then
                GameUI.Notify("全部征收！" .. table.concat(parts, "  "), "success")
            else
                GameUI.Notify("当前殖民地暂无产出建筑", "info")
            end
        end,
        getConquestProgress = function()
            local allPlanets    = GalaxyScene.GetAllPlanets()
            local colonized     = GalaxyScene.GetColonizedPlanets()
            local total         = allPlanets and #allPlanets or 0
            local colCount      = colonized  and #colonized  or 0
            local piratesTotal  = 0
            local piratesKilled = 0
            if pirateAI_ and pirateAI_.bases then
                for _, b in ipairs(pirateAI_.bases) do
                    piratesTotal = piratesTotal + 1
                    if not b.active then piratesKilled = piratesKilled + 1 end
                end
            end
            -- 计算当前海盗最高威胁等级（供 HUD 显示）
            local maxThreat = 0
            if pirateAI_ and pirateAI_.bases then
                for _, b in ipairs(pirateAI_.bases) do
                    if b.active and b.level > maxThreat then
                        maxThreat = b.level
                    end
                end
            end
            return {
                colonized     = colCount,
                total         = total,
                piratesKilled = piratesKilled,
                piratesTotal  = piratesTotal,
                pirateThreat  = maxThreat,
            }
        end,
        onShowLeaderboard = function(callback)
            -- 并行拉取：排行榜列表 + 本人排名
            local rankList   = nil
            local myRank     = nil
            local myScore    = nil
            local nicksReady = false
            local rankReady  = false

            local function tryAssemble()
                if not (nicksReady and rankReady) then return end
                callback(rankList, myRank, myScore)
            end

            -- 1. 拉取排行榜（附带 galaxy_colonized / galaxy_kills 扩展字段）
            clientCloud:GetRankList("galaxy_score", 0, 10, {
                ok = function(_, rows)
                    -- rows: { {userId, iscores={galaxy_score=N, galaxy_colonized=N, galaxy_kills=N}}, ... }
                    local userIds = {}
                    for _, row in ipairs(rows) do
                        table.insert(userIds, row.userId)
                    end
                    -- 2. 批量拉取昵称
                    GetUserNickname({
                        userIds   = userIds,
                        onSuccess = function(nickMap)
                            rankList = {}
                            for rank, row in ipairs(rows) do
                                table.insert(rankList, {
                                    rank      = rank,
                                    userId    = row.userId,
                                    name      = nickMap[tostring(row.userId)] or ("玩家" .. tostring(row.userId):sub(-4)),
                                    score     = (row.iscores and row.iscores.galaxy_score)     or 0,
                                    colonized = (row.iscores and row.iscores.galaxy_colonized) or 0,
                                    kills     = (row.iscores and row.iscores.galaxy_kills)     or 0,
                                })
                            end
                            nicksReady = true
                            tryAssemble()
                        end,
                        onError = function()
                            -- 昵称获取失败，用占位名继续
                            rankList = {}
                            for rank, row in ipairs(rows) do
                                table.insert(rankList, {
                                    rank      = rank,
                                    userId    = row.userId,
                                    name      = "玩家" .. tostring(row.userId):sub(-4),
                                    score     = (row.iscores and row.iscores.galaxy_score)     or 0,
                                    colonized = (row.iscores and row.iscores.galaxy_colonized) or 0,
                                    kills     = (row.iscores and row.iscores.galaxy_kills)     or 0,
                                })
                            end
                            nicksReady = true
                            tryAssemble()
                        end,
                    })
                end,
                error = function()
                    rankList   = {}
                    nicksReady = true
                    tryAssemble()
                end,
                timeout = function()
                    rankList   = {}
                    nicksReady = true
                    tryAssemble()
                end,
            }, "galaxy_colonized", "galaxy_kills")

            -- 3. 拉取本人排名（独立请求，与上面并行）
            local selfId = clientCloud.userId
            if selfId then
                clientCloud:GetUserRank(selfId, "galaxy_score", {
                    ok = function(_, rankInfo)
                        myRank  = rankInfo and rankInfo.rank
                        myScore = rankInfo and rankInfo.score
                        rankReady = true
                        tryAssemble()
                    end,
                    error = function()
                        rankReady = true
                        tryAssemble()
                    end,
                    timeout = function()
                        rankReady = true
                        tryAssemble()
                    end,
                })
            else
                rankReady = true
            end
        end,
        -- P2-1: 殖民优先标记
        onTogglePriorityCb = function(planet)
            GalaxyScene.TogglePriority(planet)
            -- 刷新面板以反映新标记状态
            GameUI.RefreshPlanetPanel(planet)
        end,
        getIsPriorityCb = function(planet)
            return GalaxyScene.IsPriority(planet)
        end,
        -- P1-2 WARP_GATE_PRIME: 舰队瞬移至目标星球
        onWarpFleetCb = function(targetPlanet)
            if not (rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGatePrime) then
                GameUI.Notify("需要主曲速门模块（Lv9解锁）", "error")
                return
            end
            local cd = rm_.baseBonus.warpGatePrimeCooldown or 0
            if cd > 0 then
                GameUI.Notify(string.format("主曲速门冷却中（还需 %.0f 秒）", cd), "warn")
                return
            end
            local ok = GalaxyScene.WarpFleetToPlanet(targetPlanet)
            if ok then
                rm_.baseBonus.warpGatePrimeCooldown = 120
                GameUI.Notify("⚡ 舰队瞬移完成！冷却 120s", "success")
                Audio.Play(Audio.SFX.FLEET_MOVE)
            else
                GameUI.Notify("当前没有可瞬移的编队", "warn")
            end
        end,
        -- P3-1: 快捷信号发送（多人模式可扩展为广播；单机模式显示本地通知）
        onSendSignalCb = function(sig)
            -- 播放轻音效反馈
            Audio.Play(Audio.SFX.FLEET_MOVE)
            -- 单机模式下信号由 GameUI 已自动 Notify，此处可扩展多人广播
            print(string.format("[Signal] 发送信号: %s %s", sig.icon, sig.label))
        end,
        -- P1-3: 取消建造队列中的任务，退还资源
        onCancelQueuedCb = function(qIdx, planet)
            local ok = bs_:cancelQueued(qIdx, planet)
            if ok then
                GameUI.Notify("🗑 已取消排队建造任务，资源已退还", "info")
                GameUI.RefreshPlanetPanel(planet)
            else
                GameUI.Notify("取消失败：任务不存在", "warn")
            end
        end,
        -- P2-1: 驻守编队到指定星球
        onGarrisonFleetCb = function(fleetId, planet)
            local ok, reason = GalaxyScene.GarrisonFleet(fleetId, planet)
            if ok then
                GameUI.Notify("🏴 编队 " .. fleetId .. " 已驻守 " .. (planet.name or "?"), "success")
            else
                GameUI.Notify("驻守失败: " .. (reason or "未知原因"), "error")
            end
        end,
        -- P2-1: 召回驻守编队
        onRecallGarrisonCb = function(fleetId)
            GalaxyScene.RecallGarrison(fleetId)
            GameUI.Notify("编队 " .. fleetId .. " 驻守已召回", "info")
        end,
        -- P2-1: 查询编队驻守信息（返回 {garrisonedPlanet, colonizedPlanets}）
        getGarrisonInfoCb = function(fleetId)
            local garrisonedPlanet = GalaxyScene.GetGarrisonedPlanet(fleetId)
            local colonizedPlanets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
            return { garrisonedPlanet = garrisonedPlanet, colonizedPlanets = colonizedPlanets }
        end,
        -- P3-2: 查询星球产量历史（返回 {minerals={...}, energy={...}, crystal={...}} 或 nil）
        getPlanetProdHistoryCb = function(planetName)
            return planetProdHistory_[planetName] or nil
        end,
        -- P1-1: 外交送礼
        onSendGift = function(planetId)
            if not ds_ then return end
            local ok, msg = ds_:sendGift(planetId, rm_)
            if ok then
                GameUI.Notify("🎁 " .. msg, "success")
                GameUI.RefreshPlanetPanel(selectedPlanet_)
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,
        -- P2-3: 设置建筑专精
        onSetSpec = function(planetId, bldIdx, specKey)
            if not selectedPlanet_ or selectedPlanet_.id ~= planetId then return end
            local ok, msg = bs_:setSpec(bldIdx, selectedPlanet_, specKey)
            if ok then
                GameUI.Notify("✦ " .. msg, "success")
                GameUI.RefreshPlanetPanel(selectedPlanet_)
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,
        -- P1-1: 查询外交状态（返回带 factionDef 的完整状态，或 nil）
        getDiplomacyState = function(planetId)
            if not ds_ then return nil end
            local st = ds_:getState(planetId)
            if not st then return nil end
            local fdef = ds_:getFactionDef(st.factionKey) or {}
            return {
                factionKey = st.factionKey,
                factionDef = fdef,
                favor      = st.favor,
                atWar      = st.atWar,
                military   = st.military,
                tradeTimer = st.tradeTimer,
            }
        end,
    })

    GameUI.ShowScene("galaxy", false)

    -- 注入"在此展开基地"按钮回调：等价于玩家按下空格键
    GameUI.SetDeployCallback(function()
        if not GalaxyScene.IsDeployed() then
            GalaxyScene.OnKeyDown(KEY_SPACE)
        end
    end)

    -- 注入结算界面广告回调
    GameUI.SetAdCallback(function(onResult)
        showRewardAd(function(result)
            if result.success then
                adBonusNext_ = true   -- 标记下局给予资源加成
                onResult(true, result.msg)
            else
                onResult(false, result.msg)
            end
        end)
    end)

    -- 注入建造加速广告回调（星币不足时免费完成建造）
    GameUI.SetSpeedUpAdCallback(function(target, onResult)
        showRewardAd(function(result)
            if result.success then
                if target and target.constructing then
                    target.constructing.remaining = 0
                    target.constructing.progress  = 1.0
                    GameUI.Notify("🎬 广告奖励：建造立即完成！", "success")
                    GameUI.ForceRefreshPanel(target)  -- 强制刷新，避免同引用不更新
                end
                if onResult then onResult(true, result.msg) end
            else
                if onResult then onResult(false, result.msg) end
            end
        end)
    end)

    -- 注入科技研究加速广告回调（看广告加速5分钟）
    GameUI.SetTechSpeedAdCallback(function(onResult)
        showRewardAd(function(result)
            if result.success then
                if rs_ and rs_.active then
                    rs_.active.remaining = math.max(0, (rs_.active.remaining or 0) - 300)
                    GameUI.Notify("🎬 广告奖励：研究进度加速 5 分钟！", "success")
                end
                if onResult then onResult(true, result.msg) end
            else
                if onResult then onResult(false, result.msg) end
            end
        end)
    end)

    -- 注入中期资源补给广告回调（每局最多3次）
    GameUI.SetTopBarAdCallback(function(onResult)
        showRewardAd(function(result)
            if result.success then
                rm_:add("metal",   500)
                rm_:add("esource", 200)
                rm_:add("nuclear", 100)
                GameUI.Notify("🎬 广告奖励：获得资源补给包！", "success")
                if onResult then onResult(true, result.msg) end
            else
                if onResult then onResult(false, result.msg) end
            end
        end)
    end)

    -- 触发新手引导（start 阶段；若已完成教程则静默跳过）
    GameUI.TutorialTriggerStart()

    -- 初始化成就系统：跨局保留已解锁成就；云存档读档后由 SetUnlocked 覆盖
    Achievement.Init({
        notifyFn = GameUI.Notify,
        unlocked = savedAchievements_,   -- nil = 全新游戏；非 nil = 再来一局时恢复
        redeemed = savedRedeemed_,       -- P2-3: 恢复已兑换奖励
        onAudio  = function() Audio.Play(Audio.SFX.ACHIEVEMENT_UNLOCK) end,
        onUnlock = function(id, list)
            -- 成就解锁时刷新 UI 面板
            GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())
            -- 同步到云端（忽略网络错误，不影响游戏流程）
            local cjson = require("cjson")
            local ok, jsonStr = pcall(cjson.encode, list)
            if not ok then return end
            clientCloud:SetString("galaxy_achievements", jsonStr, function(success)
                if success then
                    print("[Achievement] 云端同步成功: " .. id)
                else
                    print("[Achievement] 云端同步失败（已忽略）: " .. id)
                end
            end)
        end,
    })
    savedAchievements_ = nil   -- 消费后清空，避免影响后续流程
    savedRedeemed_     = nil   -- P2-3: 消费后清空

    -- P2-3: 应用所有已兑换成就奖励（开局加成）
    do
        local activeRewards = Achievement.GetActiveRewards()
        local bonusSkillPts = 0
        for _, entry in ipairs(activeRewards) do
            local r = entry.reward
            if r.type == "resource" then
                for res, delta in pairs(r.value) do
                    rm_.resources[res] = (rm_.resources[res] or 0) + delta
                end
            elseif r.type == "reserve_ship" then
                for _ = 1, r.value.count do
                    fm_:addToReserve(r.value.shipType)
                end
            elseif r.type == "skill_point" then
                bonusSkillPts = bonusSkillPts + r.value
            elseif r.type == "skill_level" then
                -- BattleScene 初始化时通过 GetActiveRewards 自行应用，此处仅记日志
            end
        end
        if #activeRewards > 0 then
            print(string.format("[P2-3] 应用成就奖励: %d 项, 额外技能点 %d", #activeRewards, bonusSkillPts))
        end
        -- 注册兑换回调：玩家点击兑换 → 持久化 + 刷新 UI
        GameUI.SetRedeemCallback(function(id)
            local ok, reward = Achievement.Redeem(id)
            if not ok then
                GameUI.Notify("兑换失败: " .. tostring(reward), "error")
                return
            end
            -- 即时应用奖励
            local r = reward
            if r.type == "resource" then
                for res, delta in pairs(r.value) do
                    rm_.resources[res] = (rm_.resources[res] or 0) + delta
                end
                GameUI.Notify("🎁 成就奖励已激活！", "success")
            elseif r.type == "reserve_ship" then
                for _ = 1, r.value.count do
                    fm_:addToReserve(r.value.shipType)
                end
                GameUI.Notify("🎁 成就奖励：储备舰队已补充！", "success")
            elseif r.type == "skill_point" then
                GameUI.Notify("🎁 成就奖励：下局战斗获得额外技能点！", "success")
            elseif r.type == "skill_level" then
                GameUI.Notify("🎁 成就奖励：下场战斗技能初始等级提升！", "success")
            end
            -- 持久化：立即写回 career 文件
            local ok3, _ = pcall(function()
                local cFile = File("galaxy_career.json", FILE_WRITE)
                if cFile:IsOpen() then
                    local saveData = {}
                    for k, v in pairs(careerStats_) do saveData[k] = v end
                    saveData.redeemed = Achievement.GetRedeemed()
                    cFile:WriteString(cjson.encode(saveData))
                    cFile:Close()
                end
            end)
            if not ok3 then print("[P2-3] 兑换持久化失败") end
            -- 刷新成就面板数据
            GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())
        end)
    end

    -- 初始化成就面板数据
    GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())

    -- P1-3: 初始同步已完成目标（新局为空）
    GameUI.SetCompletedGoals(completedGoals_)

    -- P2-1: 同步生涯战绩到 UI
    GameUI.SetCareerStats(careerStats_)

    -- 启动星系探索 BGM
    Audio.PlayBGM(Audio.BGM.GALAXY_MAIN, 2.0)
end

-- ============================================================================
-- 软重启（再来一局）
-- ============================================================================
--- 重置所有游戏系统，重新开始一局（不销毁 vg_/scene_ 等引擎资源）
softReset = function()
    print("[Client] softReset: 开始软重启...")

    -- 0. 保存已解锁成就（跨局保留，不随新局重置）
    savedAchievements_ = Achievement.GetUnlocked()
    savedRedeemed_     = Achievement.GetRedeemed()   -- P2-3: 保存已兑换奖励
    print("[Client] softReset: 保存成就 " .. #savedAchievements_ .. " 条, 已兑换 " .. #savedRedeemed_ .. " 项")

    -- 1. 关闭旧 UI（释放 UI 树，但保留 vg_）
    GameUI.Shutdown()

    -- 2. 关闭旧场景（释放地图/舰队数据，但保留 vg_）
    if GalaxyScene.Shutdown then GalaxyScene.Shutdown() end

    -- 3. 重建所有游戏系统实例
    rm_      = Sys.ResourceManager.new()
    -- 按难度调整初始资源
    local diffInitRes = (DIFFICULTY_CONFIGS[difficulty_] or {}).initRes
    -- P1-2: 自定义难度的初始资源加成（来自 initResBonus 滑块）
    if difficulty_ == "custom" and customDiff_.initResBonus ~= 0 then
        local bonus = customDiff_.initResBonus
        diffInitRes = {
            metal   = math.floor(bonus * 0.50),   -- 金属 50%
            esource = math.floor(bonus * 0.35),   -- 能源 35%
            nuclear = math.floor(bonus * 0.15),   -- 核燃料 15%
        }
    end
    if diffInitRes then
        for res, delta in pairs(diffInitRes) do
            local cur = rm_.resources[res] or 0
            rm_.resources[res] = math.max(0, cur + delta)
        end
        print(string.format("[Client] 难度 %s 初始资源已调整", difficulty_))
    end
    -- 广告奖励：若上一局看了广告，新局额外获得资源
    adBonusApplied_ = false
    if adBonusNext_ then
        adBonusNext_    = false
        adBonusApplied_ = true
        for res, bonus in pairs(AD_BONUS) do
            rm_.resources[res] = (rm_.resources[res] or 0) + bonus
        end
        print(string.format("[Client] 广告资源加成已应用: 金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear))
    end
    bs_      = Sys.BuildingSystem.new(rm_)
    bbs_     = Sys.BaseBuildingSystem.new(rm_)
    rs_      = Sys.ResearchSystem.new(rm_, bs_)
    ms_      = Sys.MarketSystem.new(rm_)
    player_  = Sys.PlayerProfile.new()
    spq_     = Sys.ShipProductionQueue.new(rm_)
    fm_      = Sys.FleetManager.new()

    -- 4. 重置游戏状态变量
    currentScene_         = "galaxy"
    selectedPlanet_       = nil
    activeFleetId_        = 1
    explorerColonizeMode_ = false
    refreshTimer_         = 0
    lastShownRemaining_   = -1
    baseEffectsDirty_     = true
    endGameTriggered_     = false
    piratesKilled_        = 0
    battleStatsCache_     = {}
    totalResearch_        = 0
    totalShipsBuilt_      = 0
    resMilestoneTimer_    = 0
    resWarnTimer_         = 0        -- P2-1: 重置资源预警计时器
    lowResWarnSent_       = {}       -- P2-1: 重置已发送预警记录
    pirateAttackInfo_     = nil
    pirateWarnPlayed_     = false
    playTime_             = 0
    totalPlayTime_        = 0
    extraTime_            = 0
    timeoutTriggered_     = false
    saveTimer_            = 0
    saveInProgress_       = false

    -- 4b. P2-3: 重置跨局隐藏统计（新局从零开始）
    hiddenStats_.totalShipsLostCampaign = 0
    hiddenStats_.focusKills             = 0
    hiddenStats_.focusBossKill          = false
    hiddenStats_.totalCardsChosen       = 0
    hiddenStats_.totalExplored          = 0
    hiddenStats_.exploreTypesFound      = {}

    -- 4c. P3-3: 重置 DDA（新局重新计算，不携带上局历史）
    dda_.recentResults = {}
    dda_.evalTimer     = 0
    dda_.adjustCount   = 0
    -- P2-1: 清除驻守状态（新局开始，所有编队驻守关系重置）
    if GalaxyScene.ClearGarrisons then GalaxyScene.ClearGarrisons() end
    -- baseFactor / currentFactor / enabled 由 setupSceneAndUI 在选择难度后重写，此处不重置

    -- 5. 重置无尽模式状态
    isEndlessMode_     = false
    endlessRound_      = 0
    endlessStreak_     = 0      -- P2-1 V2.0: 重置连胜计数
    endlessStreakBuff_ = false  -- P2-1 V2.0: 重置连胜资源加成
    for k in pairs(endlessCardBonuses_) do endlessCardBonuses_[k] = 0 end  -- P2-1
    GameUI.SetEndlessRound(0)   -- 同步清除 TopBar 无尽轮次显示

    -- 6b. 重置探索任务
    explorerTasks_    = {}
    explorerTaskSeq_  = 0
    GameUI.RefreshExplorerTasks({})

    -- 6. 返回主菜单（刷新存档状态，让玩家重新选择）
    difficultyChosen_     = false
    diffHoverBtn_         = nil
    customDiffSlider_     = nil   -- P1-2: 清除滑块拖拽状态
    mainMenuActive_       = true
    mainMenuHover_    = nil
    hasSave_          = fileSystem:FileExists("galaxy_save.json")
    print("[Client] softReset: 完成，返回主菜单")
end

-- ============================================================================
-- Start / Stop
-- ============================================================================
function Client.Start()
    print("=== Galactic Conquest Client Start ===")

    -- 初始化 NanoVG 渲染上下文（整个生命周期只创建一次）
    vg_      = nvgCreate(1)
    screenW_, screenH_ = UICommon.getVirtualSize()
    uiScale_ = UICommon.uiScale

    -- 初始化音频（需要 Scene 节点挂载 SoundSource）
    scene_   = Scene()
    Audio.Init(scene_)

    -- 检测本地存档（决定主菜单是否显示"继续游戏"）
    hasSave_ = fileSystem:FileExists("galaxy_save.json")

    -- P2-1: 加载生涯战绩（独立文件，跨局持久）
    if fileSystem:FileExists("galaxy_career.json") then
        local ok3, err3 = pcall(function()
            local cFile = File("galaxy_career.json", FILE_READ)
            if cFile:IsOpen() then
                local s = cFile:ReadString()
                cFile:Close()
                local d = cjson.decode(s)
                if type(d) == "table" then
                    careerStats_.totalGames    = d.totalGames    or 0
                    careerStats_.totalWins     = d.totalWins     or 0
                    careerStats_.bestWave      = d.bestWave      or 0
                    careerStats_.totalKills    = d.totalKills    or 0
                    careerStats_.totalColonies = d.totalColonies or 0
                    careerStats_.bestMvpShip   = d.bestMvpShip   or ""
                    careerStats_.playtime      = d.playtime      or 0
                    -- P2-3: 读取已兑换奖励列表
                    if type(d.redeemed) == "table" then
                        savedRedeemed_ = d.redeemed
                    end
                end
            end
        end)
        if not ok3 then print("[Career] 战绩加载失败: " .. tostring(err3)) end
    end
    print("[Client] 存档状态: " .. (hasSave_ and "有存档" or "无存档"))

    -- 创建 NanoVG 字体（主菜单/难度屏幕/游戏 UI 共用）
    nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 订阅引擎事件（只注册一次，softReset 不重复注册）
    -- 注意：setupSceneAndUI 由玩家在难度选择屏幕点击后由 onDifficultySelect 调用
    SubscribeToEvent("NanoVGRender",    handleNanoVGRender)
    SubscribeToEvent("Update",          handleUpdate)
    SubscribeToEvent("MouseButtonDown", handleMouseButtonDown)
    SubscribeToEvent("MouseButtonUp",   handleMouseButtonUp)
    SubscribeToEvent("MouseMove",       handleMouseMove)
    SubscribeToEvent("MouseWheel",      handleMouseWheel)
    SubscribeToEvent("KeyDown",         handleKeyDown)
    SubscribeToEvent("KeyUp",           handleKeyUp)
    -- P1-1: 昵称文本输入
    SubscribeToEvent("TextInput", function(_, ed)
        if not nicknameInputActive_ then return end
        local ch = ed["Text"]:GetString()
        -- 限制长度（最多12个汉字/24字节）
        if #playerName_ < 24 then
            playerName_ = playerName_ .. ch
        end
    end)

    -- 触摸事件（移动端双指缩放 + 单指拖拽）
    SubscribeToEvent("TouchBegin", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        -- 菜单期间不传递给游戏模块，避免 GalaxyScene 在未初始化时注册拖拽状态
        if mainMenuActive_ or not difficultyChosen_ then return end
        local tx  = ed["X"]:GetInt() / uiScale_   -- 预除 uiScale，模块内再 /dpr = 虚拟坐标
        local ty  = ed["Y"]:GetInt() / uiScale_
        if GameUI.OnTouchBegin(tid, tx, ty) then return end
        if currentScene_ == "battle" then return end  -- 战斗场景无需 TouchBegin（单指移动在 TouchEnd 处理）
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchBegin(tid, tx, ty)
    end)
    SubscribeToEvent("TouchMove", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        if mainMenuActive_ or not difficultyChosen_ then return end
        local tx  = ed["X"]:GetInt() / uiScale_
        local ty  = ed["Y"]:GetInt() / uiScale_
        if GameUI.OnTouchMove(tid, tx, ty) then return end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchMove(tid, tx, ty)
    end)
    SubscribeToEvent("TouchEnd", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        -- 虚拟坐标（/dpr/uiScale），与 handleMouseButtonUp 保持一致，用于主菜单/难度命中检测
        local dpr = getDpr()
        local mx  = ed["X"]:GetInt() / dpr / uiScale_
        local my  = ed["Y"]:GetInt() / dpr / uiScale_
        -- 主菜单点击（手机端）
        if mainMenuActive_ then
            local hit = getMainMenuHit(mx, my, screenW_, screenH_)
            print(string.format("[Touch] mainMenu tap: mx=%.1f my=%.1f sw=%d sh=%d hit=%s dpr=%.1f uiScale=%.2f",
                mx, my, screenW_, screenH_, tostring(hit), dpr, uiScale_))
            if hit then onMainMenuSelect(hit) end
            return
        end
        -- 难度选择屏幕点击（手机端）
        if not difficultyChosen_ then
            local hit = getDifficultyHit(mx, my, screenW_, screenH_)
            if hit == "endless" then
                onEndlessModeSelect()
            elseif hit then
                onDifficultySelect(hit)
            end
            return
        end
        -- 游戏内触摸（/uiScale_，模块内部再 /dpr）
        local tx  = ed["X"]:GetInt() / uiScale_
        local ty  = ed["Y"]:GetInt() / uiScale_
        if GameUI.OnTouchEnd(tid, tx, ty) then return end
        if currentScene_ == "battle" then
            -- 触摸坐标需要转到与 OnClick 一致的虚拟坐标系（/dpr/uiScale）
            BattleScene.OnClick(mx, my)
            return
        end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchEnd(tid, tx, ty)
    end)

    -- 游戏就绪（等待玩家在难度选择界面点击后正式开始）
    print("=== 就绪 | 等待难度选择... ===")
end

function Client.Stop()
    GameUI.Shutdown()
    if vg_ then nvgDelete(vg_); vg_ = nil end
    print("=== Galactic Conquest Client Stop ===")
end

-- P2-1: 暴露生涯战绩供 GameUI 读取
function Client.GetCareerStats()
    return careerStats_
end

--- P1-1: 获取玩家昵称
function Client.GetPlayerName()
    return playerName_
end

return Client
