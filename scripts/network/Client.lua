---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-- ============================================================================
-- network/Client.lua  -- 银河征服 客户端
-- ============================================================================

local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local PirateAI    = require("game.PirateAI")

local GameUI      = require("game.GameUI")
local PlanetPanel = require("game.ui.PlanetPanel")  -- P3-2: 微动画触发
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local UICommon    = require("game.ui.UICommon")
local ClientMenus = require("network.ClientMenus")
local Campaign    = require("game.CampaignSystem")  -- P2-2: 战役模式
local NemesisSystem = require("game.NemesisSystem")  -- P1-2: 宿敌系统
local BlackMarket   = require("game.BlackMarketSystem") -- P2-2: 黑市走私网络
local Commander     = require("game.CommanderSystem")    -- P1-3 V2.4: 指挥官系统
local QuestBoard    = require("game.QuestBoard")         -- P2-1 V2.4: 程序化任务板
local GalaxyEvents  = require("game.GalaxyEvents")       -- P1-2 V2.4: 终局危机
local MegastructureSystem = require("game.MegastructureSystem") -- P2-2 V2.4: 巨构工程
local LiverySystem = require("game.LiverySystem")               -- P2-3 V2.4: 舰队涂装
local GalactopediaSystem = require("game.GalactopediaSystem")   -- P3-1 V2.4: 银河百科
local LegacySystem = require("game.LegacySystem")               -- P1-3 V2.5: 文明遗产
local ModuleRegistry = require("game.ModuleRegistry")            -- V3.0: 扩展模块注册器
local ClientSave  = require("network.ClientSave")   -- 存档/读档逻辑
local ClientStats = require("network.ClientStats")  -- 统计面板渲染
local ClientBattle = require("network.ClientBattle") -- P3-1b: 战斗/波次/结算/远征/探索/DDA
local ClientGalaxy = require("network.ClientGalaxy") -- P3-1c: 建造/殖民/市场/外交
local BattleScene  = require("game.BattleScene")     -- 战术场景渲染/更新/点击
local ClientSetup  = require("network.ClientSetup")  -- P3-1d: setupSceneAndUI 逻辑
local ClientInput  = require("network.ClientInput")  -- P3-1d: 输入处理逻辑
-- P2-1: AnomalySystem 使用 inline require 以避免 upvalue 上限

local Client = {}

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_           = nil
local screenW_      = 800
local screenH_      = 600
local uiScale_      = 1.0   -- nvgScale 缩放比，由 getScreenSize() 每帧更新

-- ============================================================================
-- 游戏时间限制（合并为单表以节省 upvalue 槽位）
-- ============================================================================
local TL = {
    BASE_LIMIT      = 7200,   -- 基础时长：2小时（秒）
    EXTRA_PER_AD    = 3600,   -- 每次看广告增加：1小时（秒）
    MAX_EXTRA       = 7200,   -- 最多可增加：2小时（秒）
    playTime        = 0,      -- 已游玩总时长（秒）
    extraTime       = 0,      -- 通过广告获得的额外时长（秒）
    timeoutTriggered = false, -- 是否已触发超时流程
    adWatching      = false,  -- 是否正在播放广告（防止重复点击）
    -- P3-3: 自动暂停
    bgPaused       = false,  -- 切后台暂停中
    bgPauseNotifyT = 0,      -- "已暂停" 通知显示倒计时（秒）
}
local lastDt_         = 0.016  -- 上一帧 dt（传给 RenderHUD 驱动动画）

-- 剩余可看广告次数（最多 MAX_EXTRA / EXTRA_PER_AD = 2 次）
local function getAdCount()
    return math.floor((TL.MAX_EXTRA - TL.extraTime) / TL.EXTRA_PER_AD)
end

-- 剩余游玩时间（秒）
local function getRemainingTime()
    return math.max(0, TL.BASE_LIMIT + TL.extraTime - TL.playTime)
end

local currentScene_   = "galaxy"
local refreshTimer_   = 0
local selectedPlanet_ = nil
local lastShownRemaining_ = -1   -- 上次传给 UI 的整秒值，相同时跳过调用

-- 游戏系统实例（防御：确保模块 .new 存在，避免局部变量溢出导致的 nil）
assert(Sys.ResourceManager and Sys.ResourceManager.new, "[Client] ResourceManager.new missing")
assert(Sys.ResearchSystem and Sys.ResearchSystem.new, "[Client] ResearchSystem.new missing")
local rm_      = Sys.ResourceManager.new()
local bs_      = Sys.BuildingSystem.new(rm_)       -- 行星建造系统
local bbs_     = Sys.BaseBuildingSystem.new(rm_)   -- 基地建造系统（独立）
local rs_      = Sys.ResearchSystem.new(rm_, bs_)
local ms_      = Sys.MarketSystem.new(rm_)
local bm_      = BlackMarket.new(rm_)          -- P2-2: 黑市走私网络
local player_  = Sys.PlayerProfile.new()
local spq_     = Sys.ShipProductionQueue.new(rm_)
local fm_      = Sys.FleetManager.new()
local activeFleetId_       = 1
local explorerColonizeMode_ = false   -- true 时点击未殖民星球将自动使用储备探索舰殖民
-- P1-1: 中立势力外交系统实例（setupSceneAndUI 后初始化）
---@type table
local ds_      = nil
local pendingDiploEvent_ = nil  -- P1-1: 当前待处理的外交事件

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
-- P1-1: 当前局传承加成配置（buildEvolutionBonus() 结果，每局 softReset 重算）
local evBonus_ = {}
-- P1-2: 星球升级费用表（key = 目标等级，即从 Lv(key-1) 升到 Lv(key)）
local PLANET_UPGRADE_COSTS = {
    [2] = { metal=200 },
    [3] = { metal=500, crystal=200 },
    [4] = { metal=500, crystal=500, esource=500 },
    [5] = { metal=1000, crystal=1000, esource=1000 },
}
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

-- P1-2: 主动远征系统（自动结算，无战斗 UI）
local expeditions_ = {}  -- { {fleetId, baseId, startT, duration, baseLevel, baseX, baseY, startX, startY} }
-- P3-3.1: 远征重复记忆 { [fleetId] = baseId }
local lastExpedition_ = {}

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
    -- P3-1: 排行榜战绩详情新增字段
    bestDiff      = "",   -- 胜利时的最高难度 ("easy"|"normal"|"hard"|"custom")
    curStreak     = 0,    -- 当前连胜数
    maxStreak     = 0,    -- 历史最高连胜
    shipKills     = {},   -- 按舰型累计击杀数 {FIGHTER=N, CARRIER=N, ...}
    recentWins    = {},   -- 最近3场胜利记录 [{waves,duration,diff}, ...]
}

-- ============================================================================
-- P1-1: 星际文明传承系统（跨局永久进化层）
-- ============================================================================
-- 文明树节点定义：3条路线，每条4个节点，共12项永久被动加成
-- unlockCost = 解锁所需文明积分
local EVOLUTION_TREE = {
    -- 军事路线 (军事线)
    { id="mil_1", line="military", tier=1, unlockCost=2,
      name="久战之师",   icon="⚔",
      desc="首波攻击+8%",
      apply = function(cfg) cfg._mil1 = true end },
    { id="mil_2", line="military", tier=2, unlockCost=5,
      name="钢铁洪流",   icon="🛡",
      desc="驱逐舰/战巡HP+10%",
      apply = function(cfg) cfg._mil2 = true end },
    { id="mil_3", line="military", tier=3, unlockCost=10,
      name="连击共鸣",   icon="💥",
      desc="连锁触发阈值3→2",
      apply = function(cfg) cfg._mil3 = true end },
    { id="mil_4", line="military", tier=4, unlockCost=18,
      name="精英旗舰",   icon="🚀",
      desc="CARRIER建造时间-20%",
      apply = function(cfg) cfg._mil4 = true end },
    -- 经济路线 (经济线)
    { id="eco_1", line="economy", tier=1, unlockCost=2,
      name="勤劳星民",   icon="⛏",
      desc="初始金属+200",
      apply = function(cfg) cfg._eco1 = true end },
    { id="eco_2", line="economy", tier=2, unlockCost=5,
      name="高效精炼",   icon="⚗",
      desc="精炼速率+15%",
      apply = function(cfg) cfg._eco2 = true end },
    { id="eco_3", line="economy", tier=3, unlockCost=10,
      name="市场老手",   icon="💰",
      desc="市场交易折扣+10%",
      apply = function(cfg) cfg._eco3 = true end },
    { id="eco_4", line="economy", tier=4, unlockCost=18,
      name="帝国基建",   icon="🏗",
      desc="首个建筑免费",
      apply = function(cfg) cfg._eco4 = true end },
    -- 科研路线 (科研线)
    { id="sci_1", line="science", tier=1, unlockCost=2,
      name="求知欲",     icon="🔬",
      desc="首项科技研究速度+25%",
      apply = function(cfg) cfg._sci1 = true end },
    { id="sci_2", line="science", tier=2, unlockCost=5,
      name="技术储备",   icon="📡",
      desc="初始解锁一项Tier1科技",
      apply = function(cfg) cfg._sci2 = true end },
    { id="sci_3", line="science", tier=3, unlockCost=10,
      name="分叉洞见",   icon="🔀",
      desc="专精科技两路各解锁一次",
      apply = function(cfg) cfg._sci3 = true end },
    { id="sci_4", line="science", tier=4, unlockCost=18,
      name="量子突破",   icon="⚛",
      desc="Tier4科技费用-30%",
      apply = function(cfg) cfg._sci4 = true end },
}
-- 文明积分和已解锁节点（随 careerStats_ 一起存入 galaxy_career.json）
local evolutionPoints_  = 0          -- 累计文明积分
local evolutionUnlocked_ = {}        -- Set: { [nodeId] = true }
-- 传承树面板状态（主菜单层）
local heritageOpen_     = false      -- 是否显示传承树面板
local heritageHover_    = nil        -- 当前悬停的节点id或"close"/"back"

--- 计算当前已解锁节点总加成配置表（每局 setupScene 时调用）
local function buildEvolutionBonus()
    local cfg = {}
    for _, node in ipairs(EVOLUTION_TREE) do
        if evolutionUnlocked_[node.id] then
            node.apply(cfg)
        end
    end
    return cfg
end

--- 获取已解锁节点数量
local function getEvolutionUnlockedCount()
    local n = 0
    for _ in pairs(evolutionUnlocked_) do n = n + 1 end
    return n
end

-- 成就跨局持久化（softReset 时保存，setupSceneAndUI 时恢复）
local savedAchievements_ = nil   ---@type string[]|nil
local savedRedeemed_     = nil   ---@type string[]|nil  P2-3: 已兑换奖励跨局保留

-- ── P2-2: 战役模式 ────────────────────────────────────────────────────────────
local campaignMode_            = false   -- 当前是否处于战役模式
local campaignFirstColonize_   = false   -- 是否已触发首次殖民对话
local campaignVictoryPending_  = false   -- 战役胜利对话结束后触发 softReset
local campaignResetTimer_      = 0       -- >0 时倒计时，到 0 执行 softReset

-- ── P2-1: 每日星际挑战 ────────────────────────────────────────────────────────
local dailyChallengeMode_ = false   -- 当前是否处于每日挑战模式
local todayChallenge_     = nil     -- 今日挑战配置 { restriction, boost, restrictDesc, boostDesc, ... }
local challengeStreak_    = 0       -- 连续完成天数
local lastChallengeDate_  = ""      -- 上次完成挑战的日期字符串 "YYYYMMDD"

--- 从当前系统时间获取 "YYYYMMDD" 格式的日期字符串（客户端日期）
local function getTodayStr()
    local t = os.date("*t")
    return string.format("%04d%02d%02d", t.year, t.month, t.day)
end

--- 计算到今日午夜（次日0点）的剩余秒数
local function getDailyCountdown()
    local t  = os.date("*t")
    local secsToday = t.hour * 3600 + t.min * 60 + t.sec
    return math.max(0, 86400 - secsToday)
end

--- 根据日期字符串（作为种子）确定性地生成今日挑战配置
--- restriction 选 1 个，boost 选 1 个，两者不能抵消
local CHALLENGE_RESTRICTIONS = {
    { id="no_capital",    restrictDesc="禁止建造大型舰（CARRIER/BATTLECRUISER/DESTROYER）",
      apply = function(cfg) cfg._noCapital = true end },
    { id="slot_minus1",   restrictDesc="星球建筑槽上限 -1",
      apply = function(cfg) cfg._slotMinus1 = true end },
    { id="slow_research", restrictDesc="科技研究速度 ×0.5",
      apply = function(cfg) cfg._slowResearch = true end },
    { id="no_market",     restrictDesc="市场交易关闭",
      apply = function(cfg) cfg._noMarket = true end },
    { id="less_fleet",    restrictDesc="编队容量上限 -2",
      apply = function(cfg) cfg._lessFleet = true end },
}
local CHALLENGE_BOOSTS = {
    { id="free_tech1",  boostDesc="随机免费解锁一项 Tier2 科技",
      apply = function(cfg) cfg._freeTier2Tech = true end },
    { id="delay_wave",  boostDesc="首波延迟 +30 秒",
      apply = function(cfg) cfg._delayFirstWave = 30 end },
    { id="best_market", boostDesc="市场汇率固定为最优",
      apply = function(cfg) cfg._bestMarket = true end },
    { id="init_bonus",  boostDesc="初始资源 +300 金属 +200 能源",
      apply = function(cfg) cfg._initBonus = { metal=300, esource=200 } end },
    { id="fast_build",  boostDesc="建造速度 ×1.5（首波前）",
      apply = function(cfg) cfg._fastBuildBoost = true end },
}

local function generateDailyChallenge(dateStr)
    -- 把日期字符串转换为数字种子
    local seed = 0
    for i = 1, #dateStr do
        seed = seed * 31 + string.byte(dateStr, i)
    end
    -- 确定性伪随机：LCG
    local function lcgRand(s) return (s * 1664525 + 1013904223) & 0x7FFFFFFF end
    local s1 = lcgRand(seed)
    local s2 = lcgRand(s1 + 7919)
    local ri = (s1 % #CHALLENGE_RESTRICTIONS) + 1
    local bi = (s2 % #CHALLENGE_BOOSTS) + 1
    local r  = CHALLENGE_RESTRICTIONS[ri]
    local b  = CHALLENGE_BOOSTS[bi]
    local cfg = {}
    r.apply(cfg)
    b.apply(cfg)
    cfg.restriction  = r.id
    cfg.boost        = b.id
    cfg.restrictDesc = r.restrictDesc
    cfg.boostDesc    = b.boostDesc
    cfg.dateStr      = dateStr
    return cfg
end
-- ─────────────────────────────────────────────────────────────────────────────

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
local fleetOverviewHeld_   = false    -- P3-3.5: Tab 按住时显示舰队速览
local statsMouse_          = {0, 0}   -- {X, Y} 鼠标坐标（用于面板内热区）
-- P1-2: 自定义难度模式状态
local customDiff_ = {
    attackFactor = 1.0,   -- 进攻间隔倍率：0.5(快)~2.5(慢)，默认1.0=普通
    initResBonus = 0,     -- 初始资源加成：-500~+1000
    maxThreat    = 5,     -- 最大威胁等级：1~8
}
local customDiffSlider_  = { name=nil, x0=0, w=0 }  -- 当前拖拽滑块状态

-- P1-3: 星际联赛模式
local leagueMode_      = false   -- 是否处于联赛模式

-- 无尽征服模式
local isEndlessMode_    = false   -- 是否处于无尽模式（无时限，海盗基地摧毁后重生）
local endlessRound_     = 0       -- 当前无尽模式轮次（每轮 +1，难度递增）
-- P2-1 V2.0: 连胜计数（连续≥80%全消3轮触发资源×1.5）
local endlessStreak_    = 0       -- 当前连胜轮数
local endlessStreakBuff_= false   -- 本轮是否激活连胜资源加成
-- P2-3: 传奇加成（第20层+里程碑激活，本局永久，不持久化）
local endlessLegendaryBuff_ = nil  -- { shipType, atkMult, hpMult, count } 或 nil
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
local saveGame        -- 前向声明，函数体在网络部分定义
local saveCareer      -- P2-2: 跨局战绩/战役保存前向声明

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
        tradeHubLevel=0,         -- P2-2: 贸易中心等级（降低黑市截获率）
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
        elseif b.key == "TRADE_HUB" then
            -- P2-2: 贸易中心：每级降低黑市截获率（BlackMarketSystem读取此值）
            rm_.baseBonus.tradeHubLevel = rm_.baseBonus.tradeHubLevel + lvl
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

    -- P2-1: 每日挑战编队容量-2
    if evBonus_._challengeLessFleet then
        local cur = fm_:getMaxFleets()
        fm_:setMaxFleets(math.max(1, cur - 2))
    end

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

    -- P2-1: 每日挑战标志传播到 rm_.baseBonus（供 Systems.lua 读取）
    if evBonus_._challengeSlotMinus1  then rm_.baseBonus.challengeSlotMinus1  = true end
    if evBonus_._challengeBestMarket  then rm_.baseBonus.challengeBestMarket  = true end
    if evBonus_._challengeFastBuild   then
        rm_.baseBonus.buildMult = rm_.baseBonus.buildMult * (1.0 / 1.5)  -- 建造时间×0.67 ≈ 速度×1.5
    end

    -- P2-2 V2.4: 巨构工程加成叠加
    local megaBonus = MegastructureSystem.CalcBonuses()
    if megaBonus.esourceRate > 0 then
        rm_.baseBonus.energy = rm_.baseBonus.energy + megaBonus.esourceRate
    end
    if megaBonus.researchMult > 0 then
        rm_.baseBonus.researchMult = rm_.baseBonus.researchMult + megaBonus.researchMult
    end
    if megaBonus.fleetSpeedMult > 0 then
        rm_.baseBonus.fleetSpeedMult = rm_.baseBonus.fleetSpeedMult + megaBonus.fleetSpeedMult
    end
    if megaBonus.instantWarp then
        rm_.baseBonus.hasWarpGatePrime = true
    end
    if megaBonus.defense > 0 then
        rm_.baseBonus.defense = rm_.baseBonus.defense + megaBonus.defense
    end
    if megaBonus.shield > 0 then
        rm_.baseBonus.shield = rm_.baseBonus.shield + megaBonus.shield
    end
    if megaBonus.defenseMult > 0 then
        rm_.baseBonus.defenseBonus = (rm_.baseBonus.defenseBonus or 0) + megaBonus.defenseMult
    end
end

-- ============================================================================
-- 前向声明（原位于战斗代码块内，拆分后移至此处）
-- ============================================================================
--- 计算总游戏时长（秒），由 handleUpdate 中的 totalPlayTime_ 维护
local totalPlayTime_ = 0
local softReset
local setupSceneAndUI
local onGameReady

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
-- 阶段目标 / 产量追踪（合并为单表以节省 upvalue 槽位）
local GP_ = {
    completedGoals     = {},   -- 已完成的目标 id 集合
    totalShipsBuilt    = 0,    -- 累计造船数量
    shipTypeBuilt      = {},   -- 各舰型造船数 { DESTROYER=1, ... }
    resMilestoneTimer  = 0,    -- 资源里程碑检查节流（每 10 秒检查一次）
    resWarnTimer       = 0,    -- P2-1: 资源危机预警检查节流（每 5 秒）
    lowResWarnSent     = {},   -- P2-1: 已发送预警的资源（每局重置）
    -- P3-2: 星球产量历史（每 30s 采样一次，保留最近 10 个点）
    planetProdHistory  = {},   -- {[planetName]={minerals={...},energy={...},crystal={...}}}
    prodSampleTimer    = 0,    -- 采样计时器
    PROD_SAMPLE_INTERVAL = 30,
    PROD_MAX_SAMPLES     = 10,
}

checkStageGoals = function()
    if not STAGE_GOALS then return end
    -- 构建 gameState 快照（按需填充）
    local battleStats = BattleScene and BattleScene.GetStats and BattleScene.GetStats() or {}
    local gameState = {
        profile        = player_,
        base           = GalaxyScene.GetBase(),
        rs             = rs_,
        rm             = rm_,
        totalShipsBuilt    = GP_.totalShipsBuilt,
        shipTypeBuilt      = GP_.shipTypeBuilt,
        totalEnemiesKilled = battleStats.enemiesKilled or 0,
        totalWavesCleared  = battleStats.wavesCleared  or 0,
        endlessRound       = endlessRound_ or 0,   -- P2-3: 无尽模式轮次
        colonizedPlanets   = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {},
        piratesKilled      = piratesKilled_ or 0,
    }
    for _, goal in ipairs(STAGE_GOALS) do
        if not GP_.completedGoals[goal.id] then
            local callOk, checkResult = pcall(goal.check, gameState)
            if callOk and checkResult then   -- checkResult 是 goal.check 返回的布尔值
                GP_.completedGoals[goal.id] = true
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
                GameUI.SetCompletedGoals(GP_.completedGoals)
            end
        end
    end
end

-- ============================================================================
-- 云存档：序列化 / 读档（委托给 network.ClientSave）
-- ============================================================================
local function buildSaveData()
    return ClientSave.BuildSaveData({
        rm=rm_, rs=rs_, player=player_, spq=spq_, fm=fm_, pirateAI=pirateAI_,
        ds=ds_, bm=bm_, GP=GP_,
        difficulty=difficulty_, playerName=playerName_, totalResearch=totalResearch_,
    })
end

saveGame = function()
    ClientSave.SaveGame({
        rm=rm_, rs=rs_, player=player_, spq=spq_, fm=fm_, pirateAI=pirateAI_,
        ds=ds_, bm=bm_, GP=GP_,
        difficulty=difficulty_, playerName=playerName_, totalResearch=totalResearch_,
    })
end

saveCareer = function()
    ClientSave.SaveCareer({
        careerStats       = careerStats_,
        evolutionPoints   = evolutionPoints_,
        evolutionUnlocked = evolutionUnlocked_,
        challengeStreak   = challengeStreak_,
        lastChallengeDate = lastChallengeDate_,
    })
end

local function restoreGame(jsonStr)
    local restored = ClientSave.RestoreGame(jsonStr, {
        rm=rm_, rs=rs_, player=player_, spq=spq_, fm=fm_,
        pirateAI=pirateAI_, ds=ds_, bm=bm_, GP=GP_,
        DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS,
        callbacks = {
            markBaseEffectsDirty    = markBaseEffectsDirty,
            applyBaseModuleEffects  = applyBaseModuleEffects,
            reapplyAllPlanetBonuses = function() ClientGalaxy.ReapplyAllPlanetBonuses() end,
        },
    })
    if restored then
        if restored.difficulty       then difficulty_       = restored.difficulty end
        if restored.difficultyChosen then difficultyChosen_ = restored.difficultyChosen end
        if restored.playerName       then playerName_       = restored.playerName end
        if restored.totalResearch    then totalResearch_    = restored.totalResearch end
    end
    -- P1-2 V2.5: 变异舰船系统独立持久化，读档时也需加载
    local MSysRestore = require("game.MutantShipSystem")
    MSysRestore.Init()
    -- P2-1 V2.5: 阵型编辑器独立持久化
    local FERestore = require("game.ui.FormationEditor")
    FERestore.Init()
    -- P2-3 V2.5: 蓝图系统独立持久化
    local BPRestore = require("game.BlueprintSystem")
    BPRestore.Init()
end

-- ============================================================================
-- 网络连接就绪后初始化
-- ============================================================================
onGameReady = function()
    -- 新游戏流程：跳过读档
    if skipSaveLoad_ then
        skipSaveLoad_ = false
        -- P1-2: 新游戏初始化宿敌系统
        NemesisSystem.Init()
        -- P1-2 V2.5: 新游戏初始化变异舰船系统
        local MutantShip = require("game.MutantShipSystem")
        MutantShip.Init()
        -- P2-1: 新游戏初始化异象系统
        local AnomSys = require("game.AnomalySystem")
        AnomSys.Init()
        -- P3-2: 新游戏初始化星图天气
        local SW = require("game.StarWeather")
        SW.Init()
        -- P2-1 V2.4: 新游戏初始化任务板
        QuestBoard.Reset()
        -- P2-2 V2.4: 新游戏重置巨构工程
        MegastructureSystem.Reset()
        -- P1-3 V2.4: 新游戏赠送初始指挥官
        Commander.Recruit("academy")  -- 军校毕业生
        local starter = Commander.GetAll()[1]
        if starter then Commander.AssignToFleet(starter.id, 1) end
        -- P3-1 V2.4: 新游戏初始化银河百科
        GalactopediaSystem.Init()
        -- P2-1 V2.5: 新游戏初始化阵型编辑器
        local FE = require("game.ui.FormationEditor")
        FE.Init()
        -- P2-3 V2.5: 新游戏初始化蓝图系统
        local BPNew = require("game.BlueprintSystem")
        BPNew.Init()
        print("[Client] 新游戏：跳过存档加载，宿敌/异象/天气/任务板系统已初始化")
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
        customDiffSlider = customDiffSlider_.name,
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
    return ClientMenus.GetCustomPanelVisible({ hover=diffHoverBtn_, customDiffSlider=customDiffSlider_.name })
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
    -- P1-1: 若传承树面板已打开，传递数据给 ClientMenus 渲染
    if heritageOpen_ then
        ClientMenus.RenderHeritagePanel(vg_, sw, sh, {
            evolutionTree     = EVOLUTION_TREE,
            evolutionPoints   = evolutionPoints_,
            evolutionUnlocked = evolutionUnlocked_,
            hover             = heritageHover_,
            menuT             = menuT_,
            onUnlock = function(nodeId)
                -- 在主菜单解锁传承节点
                for _, node in ipairs(EVOLUTION_TREE) do
                    if node.id == nodeId and not evolutionUnlocked_[nodeId] then
                        if evolutionPoints_ >= node.unlockCost then
                            -- 检查前置节点（同路线上一Tier必须先解锁）
                            local prereqOk = true
                            if node.tier > 1 then
                                for _, n2 in ipairs(EVOLUTION_TREE) do
                                    if n2.line == node.line and n2.tier == node.tier - 1 then
                                        prereqOk = evolutionUnlocked_[n2.id] == true
                                        break
                                    end
                                end
                            end
                            if prereqOk then
                                evolutionPoints_ = evolutionPoints_ - node.unlockCost
                                evolutionUnlocked_[nodeId] = true
                                print(string.format("[Heritage] 解锁节点 %s，剩余积分=%d",
                                    node.name, evolutionPoints_))
                                -- 立即存档
                                pcall(function()
                                    local cFile = File("galaxy_career.json", FILE_WRITE)
                                    if cFile:IsOpen() then
                                        local sd = {}
                                        for k, v in pairs(careerStats_) do sd[k] = v end
                                        sd.evolutionPoints = evolutionPoints_
                                        local ul = {}
                                        for nid in pairs(evolutionUnlocked_) do ul[#ul+1]=nid end
                                        sd.evolutionUnlocked = ul
                                        sd.redeemed = Achievement.GetRedeemed()
                                        cFile:WriteString(cjson.encode(sd))
                                        cFile:Close()
                                    end
                                end)
                                -- 检查传承成就
                                Achievement.Check("heritage_points", {
                                    evolutionPoints = evolutionPoints_,
                                    unlockedCount   = getEvolutionUnlockedCount(),
                                })
                            end
                        end
                    end
                end
            end,
        })
    else
        ClientMenus.RenderMainMenu(vg_, sw, sh, {
            hover             = mainMenuHover_,
            hasSave           = hasSave_,
            menuT             = menuT_,
            evolutionPoints   = evolutionPoints_,
            unlockedCount     = getEvolutionUnlockedCount(),
            -- P2-1: 每日挑战状态
            dailyCompleted    = (lastChallengeDate_ == getTodayStr()),
            dailyCountdown    = getDailyCountdown(),
        })
    end
end

local function renderDifficultyScreen(sw, sh)
    ClientMenus.RenderDifficultyScreen(vg_, sw, sh, menuCtx())
end

--- P1-3: 玩家点击星际联赛模式
local function onLeagueModeSelect()
    local LS = require("game.LeagueSystem")
    LS.CheckWeekRollover()
    difficulty_       = "normal"
    difficultyChosen_ = true
    isEndlessMode_    = false
    leagueMode_       = true
    endlessRound_     = 0
    for k in pairs(endlessCardBonuses_) do endlessCardBonuses_[k] = 0 end
    skipSaveLoad_     = true
    mainMenuActive_   = false
    print("[Client] 星际联赛模式已启动 seed=" .. tostring(LS.GetWeekSeed()))
    setupSceneAndUI()
    onGameReady()
    local mod = LS.GetWeekModifier()
    local status = LS.GetStatus()
    local rank = LS.GetRank()
    -- P1-3: 设置联赛 HUD 徽章
    GameUI.SetLeagueHud({
        rankIcon  = rank.icon,
        rankName  = rank.name,
        weekKey   = status.weekKey,
        modLabel  = mod.label,
        bestScore = status.bestScore or 0,
    })
    GameUI.Notify(string.format("🏆 星际联赛 %s — %s %s",
        status.weekKey, mod.label, mod.desc), "success")
    if adBonusApplied_ then
        adBonusApplied_ = false
        GameUI.Notify(string.format("🎬 广告加成已生效！金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear), "success")
    end
end

--- 玩家在主菜单点击按钮
local function onMainMenuSelect(key)
    if key == "new" then
        skipSaveLoad_       = true
        dailyChallengeMode_ = false
        mainMenuActive_     = false
        print("[Client] 主菜单：选择新游戏")
    elseif key == "continue" and hasSave_ then
        mainMenuActive_     = false
        dailyChallengeMode_ = false
        difficultyChosen_   = true
        print("[Client] 主菜单：选择继续游戏")
        setupSceneAndUI()
        onGameReady()
        GameUI.Notify("欢迎回来，指挥官！", "info")
    elseif key == "campaign" then
        -- P2-2: 进入战役模式（跳过难度选择，直接启动第一个未完成关卡）
        campaignMode_       = true
        dailyChallengeMode_ = false
        skipSaveLoad_       = true
        mainMenuActive_     = false
        -- 找到第一个未完成的关卡
        local targetIdx = 1
        for i = 1, #Campaign.GetLevels() do
            if not Campaign.IsLevelCompleted(i) then
                targetIdx = i; break
            end
        end
        Campaign.StartLevel(targetIdx)
        campaignFirstColonize_ = false
        -- 使用关卡定义的难度，跳过难度选择屏直接进入游戏
        local level = Campaign.GetCurrentLevel()
        difficulty_       = level and level.difficulty or "normal"
        difficultyChosen_ = true
        isEndlessMode_    = false
        endlessRound_     = 0
        print(string.format("[Campaign] 进入战役关卡 %d (%s)", targetIdx, difficulty_))
        setupSceneAndUI()
        onGameReady()
        -- 触发序章对话
        Campaign.TriggerDialogue("intro")
        GameUI.Notify("⚔ " .. (level and level.name or "战役") .. " 开始！", "success")
    elseif key == "daily" then
        -- P2-1: 进入每日挑战模式
        local todayStr = getTodayStr()
        if lastChallengeDate_ == todayStr then
            if GameUI then GameUI.Notify("今日挑战已完成，明天再来！", "info") end
            return
        end
        todayChallenge_     = generateDailyChallenge(todayStr)
        dailyChallengeMode_ = true
        skipSaveLoad_       = true
        mainMenuActive_     = false
        print(string.format("[DailyChallenge] 今日挑战: 限制=%s 强化=%s",
            todayChallenge_.restriction, todayChallenge_.boost))
    elseif key == "league" then
        -- P1-3: 进入星际联赛模式
        onLeagueModeSelect()
    end
end

--- 玩家点击选择难度
local function onDifficultySelect(key)
    -- P2-1: 每日挑战强制使用普通难度
    if dailyChallengeMode_ then key = "normal" end
    difficulty_           = key
    difficultyChosen_     = true
    isEndlessMode_        = false
    endlessRound_         = 0
    endlessLegendaryBuff_ = nil    -- P2-3: 重置传奇加成
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
    -- P2-1: 每日挑战横幅提示（在场景初始化完成后显示）
    if dailyChallengeMode_ and todayChallenge_ then
        GameUI.ShowDailyChallengeHint(todayChallenge_)
        GameUI.Notify(string.format("🎯 每日挑战开始！限制：%s", todayChallenge_.restrictDesc), "warn")
    end
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
-- P2-3: 局内统计面板渲染（委托给 network.ClientStats）
-- ============================================================================
local function renderStatsPanel(sw, sh)
    ClientStats.Render(vg_, sw, sh, {
        statsOpen        = statsOpen_,
        statsMouse       = statsMouse_,
        rs               = rs_,
        rm               = rm_,
        piratesKilled    = piratesKilled_,
        battleStatsCache = battleStatsCache_,
        TL               = TL,
        getRemainingTime = getRemainingTime,
    })
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

    -- P3-3: 自动暂停覆盖层
    if TL.bgPaused then
        nvgBeginPath(vg_)
        nvgRect(vg_, 0, 0, screenW_, screenH_)
        nvgFillColor(vg_, nvgRGBA(0, 0, 0, 180))
        nvgFill(vg_)
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 28)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(180, 220, 255, 240))
        nvgText(vg_, screenW_ / 2, screenH_ / 2 - 10, "⏸ 游戏已暂停")
        nvgFontSize(vg_, 13)
        nvgFillColor(vg_, nvgRGBA(140, 180, 220, 180))
        nvgText(vg_, screenW_ / 2, screenH_ / 2 + 22, "返回窗口自动恢复")
    end
    -- P3-3: "已恢复" 通知（焦点恢复后短暂提示）
    if TL.bgPauseNotifyT > 0 then
        local alpha = math.min(1, TL.bgPauseNotifyT / 0.5) * 200
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 14)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(80, 220, 160, math.floor(alpha)))
        nvgText(vg_, screenW_ / 2, 40, "▶ 游戏已恢复")
    end

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
    if TL.adWatching then return end
    if getAdCount() <= 0 then return end

    TL.adWatching = true
    GameUI.Notify("广告加载中，请稍候...", "info")

    showRewardAd(function(result)
        TL.adWatching = false
        if result.success then
            TL.extraTime = math.min(TL.MAX_EXTRA, TL.extraTime + TL.EXTRA_PER_AD)
            local newAdCount = getAdCount()
            GameUI.UpdateTimeoutAdCount(newAdCount)
            GameUI.Notify(
                "广告观看完成！已延长1小时。剩余可延长次数：" .. newAdCount,
                "success"
            )
            if getRemainingTime() > 0 then
                -- 恢复游戏
                TL.timeoutTriggered = false
                GameUI.HideTimeoutScreen()
            end
        else
            GameUI.Notify("广告未完整观看 (" .. (result.msg or "") .. ")，无法获得奖励", "warn")
        end
    end)
end

-- P1-2 V2.4: 终局危机选择回调（可递归展示下一阶段）
local function handleCrisisChoice_(choiceIdx)
    -- 获取当前阶段数据（选择前）用于扣费
    local pre = GalaxyEvents.GetEndgameCrisis()
    if not pre then return end
    local ch = pre.choices and pre.choices[choiceIdx]

    -- 执行选择
    local ok, err = GalaxyEvents.AdvanceCrisisPhase(choiceIdx)
    if not ok then return end

    -- 扣除资源费用
    if ch and ch.cost then
        for res, val in pairs(ch.cost) do
            if val > 0 then rm_:add(res, -val) end
        end
    end
    -- 施加选项自带惩罚
    if ch and ch.penalty then
        for res, val in pairs(ch.penalty) do
            if val > 0 then rm_:add(res, -math.min(val, rm_:get(res) or 0)) end
        end
    end
    -- 发放经验
    if ch and ch.expGain then
        player_.exp = (player_.exp or 0) + ch.expGain
    end

    -- 获取选择后状态
    local post = GalaxyEvents.GetEndgameCrisis()
    if not post then return end

    if post.resolved then
        -- 奖励由 GalaxyEvents.onCrisisResolved 回调统一处理
        -- （AdvanceCrisisPhase 内部已触发回调）
    else
        -- 进入下一阶段 → 展示新面板
        GameUI.Notify(post.icon .. " " .. post.name ..
            " — 阶段 " .. post.phase .. " 开始！", "warn")
        GameUI.ShowEndgameCrisisPanel(post, handleCrisisChoice_)
    end
end

local function handleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    lastDt_ = dt   -- 保存帧时间，供 NanoVGRender 传给 RenderHUD

    Audio.Update(dt)

    -- P3-3: 自动暂停 — 切后台时冻结游戏逻辑
    if TL.bgPaused then return end
    -- P3-3: "已暂停" 通知倒计时衰减
    if TL.bgPauseNotifyT > 0 then
        TL.bgPauseNotifyT = TL.bgPauseNotifyT - dt
    end

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

    -- P2-2: 战役胜利后延迟返回主菜单
    if campaignResetTimer_ > 0 then
        campaignResetTimer_ = campaignResetTimer_ - dt
        if campaignResetTimer_ <= 0 then
            campaignResetTimer_ = 0
            softReset()
        end
    end

    -- ---- 游戏时间追踪（无尽模式跳过超时限制）----
    if not TL.timeoutTriggered and not isEndlessMode_ then
        TL.playTime = TL.playTime + dt
        local secRemaining = math.floor(getRemainingTime())
        if secRemaining ~= lastShownRemaining_ then
            lastShownRemaining_ = secRemaining
            GameUI.SetRemainingTime(secRemaining)
        end

        -- 检测超时
        if getRemainingTime() <= 0 then
            TL.timeoutTriggered = true
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
    bm_:update(dt)

    -- P2-2 V2.4: 巨构工程 tick
    do
        local buildMult = rm_.baseBonus and rm_.baseBonus.buildMult or 1.0
        local completed = MegastructureSystem.Update(dt, buildMult)
        if completed then
            Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
            local megaKey = type(completed) == "table" and completed.key or tostring(completed)
            GameUI.Notify("🏗️ 巨构工程阶段完工: " .. megaKey, "success")
            applyBaseModuleEffects()  -- 刷新加成
            Achievement.Check("megastructure_phase", { id = megaKey })
            -- V2.5: 标记巨构建成（供文明遗产 LP 计分）
            local isFullComplete = type(completed) == "table" and completed.isComplete or false
            if isFullComplete then
                battleStatsCache_.builtMegastructure = true
            end
            saveGame()
        end
    end

    -- P2-1 V2.4: 任务板 tick（生成 + 超时 + 完成检测）
    if not endGameTriggered_ then
        local completedQuest = QuestBoard.Update(dt, rm_, ds_, fm_)
        if completedQuest then
            Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
            -- 发放奖励
            local r = completedQuest.reward
            if r.metal   and r.metal > 0   then rm_:add("metal", r.metal) end
            if r.energy  and r.energy > 0  then rm_:add("esource", r.energy) end
            if r.salvage and r.salvage > 0 and fm_ then fm_:addSalvage(r.salvage) end
            -- 精英任务额外星币奖励
            if completedQuest.elite then rm_:addCredits(200) end
            local rewardParts = {}
            if r.metal   and r.metal > 0   then rewardParts[#rewardParts+1] = "金属+"..r.metal end
            if r.energy  and r.energy > 0  then rewardParts[#rewardParts+1] = "能源+"..r.energy end
            if r.salvage and r.salvage > 0 then rewardParts[#rewardParts+1] = "🔩+"..r.salvage end
            if completedQuest.elite then rewardParts[#rewardParts+1] = "★+200" end
            local tag = completedQuest.elite and "⭐精英任务" or "📋任务"
            GameUI.Notify(tag .. "完成: " .. completedQuest.desc .. "  奖励: " .. table.concat(rewardParts, " "), "success")
            Achievement.Check("quest_complete", { totalQuests = QuestBoard.GetCompletedCount() })
            GameUI.RefreshResourceBar()
            saveGame()
        end
    end

    -- P1-1: 外交系统 tick（贸易收益 + 宣战衰减 + 殖民清除）
    if ds_ and currentScene_ == "galaxy" and not endGameTriggered_ then
        local dipEvts = ds_:tick(dt, rm_, GalaxyScene.GetAllPlanets())
        for _, ev in ipairs(dipEvts or {}) do
            if ev.type == "long_trade" then
                -- P2-2: 长期贸易自动购入通知
                local parts = {}
                for res, amt in pairs(ev.gain) do
                    local LABEL = { metal="金属", crystal="晶体", esource="能源" }
                    parts[#parts+1] = (LABEL[res] or res) .. "+" .. amt
                end
                GameUI.Notify(string.format("%s %s 协议购入：%s",
                    ev.icon, ev.factionName, table.concat(parts, " ")), "trade")
            elseif ev.type == "long_trade_break" then
                -- P2-2: 好感下降导致协议中断
                GameUI.Notify(string.format("📋 与 %s 的长期协议已中断（好感度过低）", ev.factionName), "warn")
            elseif ev.type == "blockade_end" then
                -- P1-1: 封锁到期
                local fd = Sys.NEUTRAL_FACTIONS[ev.factionKey]
                GameUI.Notify(string.format("🚫 对 %s 的贸易封锁已到期", fd and fd.name or "?"), "info")
            elseif ev.type == "diplo_request" then
                -- P1-1: 外交事件—派系请求（弹框二选一）
                pendingDiploEvent_ = ev
                GameUI.ShowDiploEvent(ev)
            elseif ev.type == "diplo_dispute" then
                -- P1-1: 外交事件—贸易纠纷
                pendingDiploEvent_ = ev
                GameUI.ShowDiploEvent(ev)
            elseif ev.type == "diplo_warning" then
                -- P1-1: 背叛警告
                GameUI.Notify(ev.desc, "warn")
            elseif ev.type == "diplo_opportunity" then
                -- P1-1: 贸易机会
                pendingDiploEvent_ = ev
                GameUI.ShowDiploEvent(ev)
            elseif ev.msg then
                GameUI.Notify(ev.msg, ev.msgType or "info")
            end
            -- P3-1: 银河百科 — 派系遭遇解锁
            if ev.factionKey then
                local gpF = GalactopediaSystem.TryUnlock("meet_faction_" .. ev.factionKey)
                if gpF then GameUI.Notify("📖 百科解锁: " .. gpF, "info") end
            end
        end
        -- P1-1: 同步关系数据给 GalaxyScene 绘制弧线（节流：每 2 秒同步一次）
        diploSyncTimer_ = (diploSyncTimer_ or 0) + dt
        if diploSyncTimer_ >= 2.0 then
            diploSyncTimer_ = 0
            if GalaxyScene.SetDiploRelations then
                GalaxyScene.SetDiploRelations(ds_:getAllRelations(), ds_:getAgreements())
            end
        end
    end

    -- P2-1: 资源危机预警（节流：每 5 秒检查一次，每种资源每局只提示一次）
    GP_.resWarnTimer = (GP_.resWarnTimer or 0) + dt
    if GP_.resWarnTimer >= 5 and not endGameTriggered_ then
        GP_.resWarnTimer = 0
        local warnCfg = {
            metal   = { min=200, msg="⚠️ 金属储量不足（<200）！建议建造矿石精炼厂或殖民矿物星球" },
            esource = { min=100, msg="⚠️ 能源储量不足（<100）！建议研究太阳能效率或殖民海洋星球" },
            nuclear = { min=50,  msg="⚠️ 核能储量不足（<50）！建议研究深层采矿或殖民火山星球" },
        }
        for res, cfg in pairs(warnCfg) do
            if (rm_.resources[res] or 0) < cfg.min and not GP_.lowResWarnSent[res] then
                GP_.lowResWarnSent[res] = true
                GameUI.Notify(cfg.msg, "warn")
            end
        end
    end

    -- 资源里程碑成就检查（节流：每 10 秒检查一次）
    GP_.resMilestoneTimer = GP_.resMilestoneTimer + dt
    if GP_.resMilestoneTimer >= 10 then
        GP_.resMilestoneTimer = 0
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
        ClientBattle.DdaPeriodicCheck()
    end

    -- P1-2 V2.4: 终局危机触发检测（游戏时间 ≥ 600 秒且未触发过）
    if totalPlayTime_ >= 600 and not GalaxyEvents.HasEndgameCrisisTriggered() then
        GalaxyEvents.TriggerEndgameCrisis()
        local crisis = GalaxyEvents.GetEndgameCrisis()
        if crisis then
            GameUI.Notify(crisis.icon .. " 终局危机：" .. crisis.name .. " — 阶段 1 开始！", "danger")
            GameUI.ShowEndgameCrisisPanel(crisis, handleCrisisChoice_)
        end
    end

    -- P1-2: 远征计时 & 结算
    if #expeditions_ > 0 and currentScene_ == "galaxy" then
        local finished = {}
        for i, exp in ipairs(expeditions_) do
            exp.elapsed = exp.elapsed + dt
            if exp.elapsed >= exp.duration then
                finished[#finished + 1] = i
            end
        end
        -- 逆序移除已完成的远征
        for j = #finished, 1, -1 do
            local idx = finished[j]
            ClientBattle.SettleExpedition(expeditions_[idx])
            table.remove(expeditions_, idx)
        end
        -- 同步给 GalaxyScene 做路径动画
        if GalaxyScene.SetExpeditions then
            GalaxyScene.SetExpeditions(expeditions_)
        end
        -- 同步给 GameUI（FleetPanel 渲染用）
        local activeBases = {}
        if pirateAI_ then
            for _, b in ipairs(pirateAI_.bases) do
                if b.active then activeBases[#activeBases + 1] = b end
            end
        end
        GameUI.SetExpeditions(expeditions_, activeBases, lastExpedition_)
    end

    -- P3-2: 产量历史采样（每 30 秒采集一次所有已殖民星球的产量）
    GP_.prodSampleTimer = GP_.prodSampleTimer + dt
    if GP_.prodSampleTimer >= GP_.PROD_SAMPLE_INTERVAL then
        GP_.prodSampleTimer = 0
        local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
        local base    = GalaxyScene.GetBase and GalaxyScene.GetBase()
        -- 也采样基地
        local allPlanets = {}
        for _, p in ipairs(planets) do allPlanets[#allPlanets+1] = p end
        if base and base.colonized then allPlanets[#allPlanets+1] = base end
        for _, p in ipairs(allPlanets) do
            local key = p.name or ""
            if key ~= "" then
                if not GP_.planetProdHistory[key] then
                    GP_.planetProdHistory[key] = { minerals={}, energy={}, crystal={} }
                end
                -- 汇总该星球本次产量
                local sum = { minerals=0, energy=0, crystal=0 }
                for _, b in ipairs(p.buildings or {}) do
                    for res, val in pairs(b.currentProd or {}) do
                        if sum[res] ~= nil then sum[res] = sum[res] + val end
                    end
                end
                local hist = GP_.planetProdHistory[key]
                for _, res in ipairs({"minerals","energy","crystal"}) do
                    hist[res][#hist[res]+1] = sum[res]
                    -- 超出上限时移除最旧点
                    if #hist[res] > GP_.PROD_MAX_SAMPLES then
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
        -- P3-1: 银河百科解锁
        local gpUnlocked = GalactopediaSystem.TryUnlock("research_" .. techDone)
        if gpUnlocked then GameUI.Notify("📖 百科解锁: " .. gpUnlocked, "info") end
        GameUI.RefreshTechPanel()
        checkStageGoals()   -- 科技完成后检查阶段目标
        saveGame()   -- 科技完成立即存档
    end

    local shipDone = spq_:update(dt)
    if shipDone then
        local st = SHIP_TYPES[shipDone.shipType]
        fm_:addToReserve(shipDone.shipType)
        GP_.totalShipsBuilt = GP_.totalShipsBuilt + 1
        GP_.shipTypeBuilt[shipDone.shipType] = (GP_.shipTypeBuilt[shipDone.shipType] or 0) + 1
        Audio.Play(Audio.SFX.BUILD_COMPLETE)
        GalaxyScene.InvalidateFleetColor(activeFleetId_)  -- 储备池变化，主编队颜色可能改变
        GameUI.Notify("舰船建造完成: " .. st.name .. "  → 已进入储备池", "success")
        -- 成就检查：首次造船、累计造船数、母舰成就
        Achievement.Check("ship_built", {
            totalShipsBuilt = GP_.totalShipsBuilt,
            lastBuiltType   = shipDone.shipType,
        })
        -- P3-1: 银河百科解锁（舰型）
        local gpShip = GalactopediaSystem.TryUnlock("build_ship_" .. shipDone.shipType)
        if gpShip then GameUI.Notify("📖 百科解锁: " .. gpShip, "info") end
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
                ClientGalaxy.ApplyPlanetTypeBonus(p)
                GameUI.Notify("建造完成: " .. BUILDINGS[done].name, "success")
                -- P3-2: 触发对应建筑行高亮动画
                PlanetPanel.TriggerHighlight(p.id, done)
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
    ClientBattle.UpdateExplorerTasks(dt)

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

    -- V3.0: 扩展模块统一帧更新
    ModuleRegistry.UpdateAll(dt, {
        rm = rm_, rs = rs_, fm = fm_, player = player_,
        currentScene = currentScene_, evBonus = evBonus_,
    })
end

-- ============================================================================
-- 输入处理（委派至 ClientInput 模块）
-- ============================================================================
local function handleMouseButtonDown(eventType, eventData)
    ClientInput.OnMouseButtonDown(eventType, eventData)
end
local function handleMouseButtonUp(eventType, eventData)
    ClientInput.OnMouseButtonUp(eventType, eventData)
end
local function handleMouseMove(eventType, eventData)
    ClientInput.OnMouseMove(eventType, eventData)
end
local function handleMouseWheel(eventType, eventData)
    ClientInput.OnMouseWheel(eventType, eventData)
end
local function handleKeyDown(eventType, eventData)
    ClientInput.OnKeyDown(eventType, eventData)
end
local function handleKeyUp(eventType, eventData)
    ClientInput.OnKeyUp(eventType, eventData)
end
--- 构建 Host context table (供 ClientSetup.Init 使用)
--- metatable 模式: 标量变量通过 __index/__newindex 保持与 Client.lua upvalues 同步
local function buildSetupHost()
    local scalars = {
        pirateAI_               = function() return pirateAI_ end,
        ds_                     = function() return ds_ end,
        selectedPlanet_         = function() return selectedPlanet_ end,
        activeFleetId_          = function() return activeFleetId_ end,
        explorerColonizeMode_   = function() return explorerColonizeMode_ end,
        campaignMode_           = function() return campaignMode_ end,
        campaignFirstColonize_  = function() return campaignFirstColonize_ end,
        campaignVictoryPending_ = function() return campaignVictoryPending_ end,
        campaignResetTimer_     = function() return campaignResetTimer_ end,
        endlessRound_           = function() return endlessRound_ end,
        piratesKilled_          = function() return piratesKilled_ end,
        endGameTriggered_       = function() return endGameTriggered_ end,
        explorerTaskSeq_        = function() return explorerTaskSeq_ end,
        endlessStreakBuff_      = function() return endlessStreakBuff_ end,
        totalPlayTime_          = function() return totalPlayTime_ end,
        totalResearch_          = function() return totalResearch_ end,
        isEndlessMode_          = function() return isEndlessMode_ end,
        leagueMode_             = function() return leagueMode_ end,
        difficulty_             = function() return difficulty_ end,
        currentScene_           = function() return currentScene_ end,
        pendingDiploEvent_      = function() return pendingDiploEvent_ end,
        adBonusNext_            = function() return adBonusNext_ end,
        baseEffectsDirty_       = function() return baseEffectsDirty_ end,
        savedAchievements_      = function() return savedAchievements_ end,
        savedRedeemed_          = function() return savedRedeemed_ end,
        skipSaveLoad_           = function() return skipSaveLoad_ end,
        dailyChallengeMode_     = function() return dailyChallengeMode_ end,
        vg_                     = function() return vg_ end,
    }
    local writers = {
        pirateAI_               = function(v) pirateAI_ = v end,
        ds_                     = function(v) ds_ = v end,
        selectedPlanet_         = function(v) selectedPlanet_ = v end,
        activeFleetId_          = function(v) activeFleetId_ = v end,
        explorerColonizeMode_   = function(v) explorerColonizeMode_ = v end,
        campaignMode_           = function(v) campaignMode_ = v end,
        campaignFirstColonize_  = function(v) campaignFirstColonize_ = v end,
        campaignVictoryPending_ = function(v) campaignVictoryPending_ = v end,
        campaignResetTimer_     = function(v) campaignResetTimer_ = v end,
        endlessRound_           = function(v) endlessRound_ = v end,
        piratesKilled_          = function(v) piratesKilled_ = v end,
        endGameTriggered_       = function(v) endGameTriggered_ = v end,
        explorerTaskSeq_        = function(v) explorerTaskSeq_ = v end,
        endlessStreakBuff_      = function(v) endlessStreakBuff_ = v end,
        totalPlayTime_          = function(v) totalPlayTime_ = v end,
        totalResearch_          = function(v) totalResearch_ = v end,
        isEndlessMode_          = function(v) isEndlessMode_ = v end,
        leagueMode_             = function(v) leagueMode_ = v end,
        difficulty_             = function(v) difficulty_ = v end,
        currentScene_           = function(v) currentScene_ = v end,
        pendingDiploEvent_      = function(v) pendingDiploEvent_ = v end,
        adBonusNext_            = function(v) adBonusNext_ = v end,
        baseEffectsDirty_       = function(v) baseEffectsDirty_ = v end,
        savedAchievements_      = function(v) savedAchievements_ = v end,
        savedRedeemed_          = function(v) savedRedeemed_ = v end,
        skipSaveLoad_           = function(v) skipSaveLoad_ = v end,
        dailyChallengeMode_     = function(v) dailyChallengeMode_ = v end,
    }
    return setmetatable({
        -- Table refs (direct)
        rm_ = rm_, bs_ = bs_, bbs_ = bbs_, rs_ = rs_, ms_ = ms_, bm_ = bm_,
        spq_ = spq_, fm_ = fm_, dda_ = dda_, player_ = player_,
        hiddenStats_ = hiddenStats_, evBonus_ = evBonus_,
        battleStatsCache_ = battleStatsCache_, careerStats_ = careerStats_,
        endlessCardBonuses_ = endlessCardBonuses_,
        explorerTasks_ = explorerTasks_, lastExpedition_ = lastExpedition_,
        PLANET_UPGRADE_COSTS = PLANET_UPGRADE_COSTS,
        DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS, GP_ = GP_, TL = TL,
        customDiff_ = customDiff_, pirateAttackInfo_ = pirateAttackInfo_,
        -- Functions
        saveGame = saveGame, saveCareer = saveCareer, softReset = softReset,
        markBaseEffectsDirty = markBaseEffectsDirty,
        handleLevelUp = handleLevelUp,
        applyBaseModuleEffects = applyBaseModuleEffects,
        checkStageGoals = checkStageGoals,
        showRewardAd = showRewardAd,
        -- Globals (convenience)
        clientCloud = clientCloud,
    }, {
        __index = function(_, k)
            local getter = scalars[k]
            if getter then return getter() end
            return nil
        end,
        __newindex = function(_, k, v)
            local writer = writers[k]
            if writer then writer(v) return end
            rawset(_, k, v)  -- fallback for unknown keys
        end,
    })
end

-- ============================================================================
-- buildInputHost: 为 ClientInput 构建 Host 代理表
-- ============================================================================
local function buildInputHost()
    -- table 类型直接引用（共享写入）
    local H = {
        customDiff       = customDiff_,
        customDiffSlider = customDiffSlider_,
        statsMouse       = statsMouse_,
        EVOLUTION_TREE   = EVOLUTION_TREE,
        SHIP_QUEUE_ORDER = SHIP_QUEUE_ORDER,
        -- 函数引用
        getDpr                   = getDpr,
        getMainMenuHit           = getMainMenuHit,
        getDifficultyHit         = getDifficultyHit,
        getCustomSliderRects     = getCustomSliderRects,
        getCustomPanelVisible    = getCustomPanelVisible,
        getEvolutionUnlockedCount = getEvolutionUnlockedCount,
        onMainMenuSelect         = onMainMenuSelect,
        onEndlessModeSelect      = onEndlessModeSelect,
        onDifficultySelect       = onDifficultySelect,
    }
    -- scalar 读写代理
    local scalars = {
        mainMenuActive      = function() return mainMenuActive_ end,
        difficultyChosen    = function() return difficultyChosen_ end,
        currentScene        = function() return currentScene_ end,
        screenW             = function() return screenW_ end,
        screenH             = function() return screenH_ end,
        uiScale             = function() return uiScale_ end,
        statsOpen           = function() return statsOpen_ end,
        nicknameInputActive = function() return nicknameInputActive_ end,
        heritageOpen        = function() return heritageOpen_ end,
        heritageHover       = function() return heritageHover_ end,
        mainMenuHover       = function() return mainMenuHover_ end,
        diffHoverBtn        = function() return diffHoverBtn_ end,
        evolutionPoints     = function() return evolutionPoints_ end,
        evolutionUnlocked   = function() return evolutionUnlocked_ end,
        careerStats         = function() return careerStats_ end,
        playerName          = function() return playerName_ end,
        fleetOverviewHeld   = function() return fleetOverviewHeld_ end,
        explorerColonizeMode = function() return explorerColonizeMode_ end,
        fm                  = function() return fm_ end,
    }
    local writers = {
        statsOpen           = function(v) statsOpen_ = v end,
        nicknameInputActive = function(v) nicknameInputActive_ = v end,
        heritageOpen        = function(v) heritageOpen_ = v end,
        heritageHover       = function(v) heritageHover_ = v end,
        mainMenuHover       = function(v) mainMenuHover_ = v end,
        diffHoverBtn        = function(v) diffHoverBtn_ = v end,
        evolutionPoints     = function(v) evolutionPoints_ = v end,
        playerName          = function(v) playerName_ = v end,
        fleetOverviewHeld   = function(v) fleetOverviewHeld_ = v end,
        explorerColonizeMode = function(v) explorerColonizeMode_ = v end,
    }
    return setmetatable(H, {
        __index = function(_, k)
            local getter = scalars[k]
            if getter then return getter() end
            return nil
        end,
        __newindex = function(_, k, v)
            local writer = writers[k]
            if writer then writer(v) return end
            rawset(_, k, v)
        end,
    })
end

-- ============================================================================
-- 场景与UI初始化（供 Start 和 softReset 复用）
-- ============================================================================
setupSceneAndUI = function()
    ClientSetup.Init(buildSetupHost())
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
    -- P1-1: 应用传承加成（每局 softReset 时重算）
    local evBonus = buildEvolutionBonus()
    if evBonus._eco1 then
        rm_.resources.metal = (rm_.resources.metal or 0) + 200
        print("[Heritage] 勤劳星民: 初始金属+200")
    end
    if evBonus._eco2 then
        rm_.rates = rm_.rates or {}
        rm_.evolutionEsourceBonus = 0.15   -- 精炼速率+15%（由ResourceManager.Update读取）
        print("[Heritage] 高效精炼: 精炼速率+15%")
    end
    if evBonus._eco4 then
        rm_._heritageFirstBuildFree = true  -- 首个建筑免费（BuildingSystem.Build 检查）
        print("[Heritage] 帝国基建: 首个建筑免费")
    end
    -- 军事线/科研线加成在相应系统初始化时通过 evBonus_ 读取
    evBonus_ = evBonus   -- 暴露给 BattleScene、ResearchSystem 等

    -- P1-3 V2.5: 应用文明遗产加成
    local legacyBonus = LegacySystem.GetBonuses()
    if legacyBonus.resourceBonus > 0 then
        -- 经济L1: 初始资源 +15%
        for res, val in pairs(rm_.resources) do
            rm_.resources[res] = math.floor(val * (1 + legacyBonus.resourceBonus))
        end
        print(string.format("[Legacy] 经济L1: 初始资源 +%d%%", legacyBonus.resourceBonus * 100))
    end
    if legacyBonus.buildSpeedBonus > 0 then
        rm_._legacyBuildSpeedBonus = legacyBonus.buildSpeedBonus
        print(string.format("[Legacy] 经济L2: 建造速度 +%d%%", legacyBonus.buildSpeedBonus * 100))
    end
    if legacyBonus.blackMarketDiscount > 0 then
        rm_._legacyMarketDiscount = legacyBonus.blackMarketDiscount
        print(string.format("[Legacy] 经济L3: 黑市折扣 %d%%", legacyBonus.blackMarketDiscount * 100))
    end
    if legacyBonus.extraFleets > 0 then
        evBonus_._legacyExtraFleets = legacyBonus.extraFleets
        print(string.format("[Legacy] 军事L1: 初始舰队 +%d", legacyBonus.extraFleets))
    end
    if legacyBonus.extraModSlot > 0 then
        evBonus_._legacyExtraModSlot = legacyBonus.extraModSlot
        print("[Legacy] 军事L2: 改装槽位 +1")
    end
    if legacyBonus.skillCdReduction > 0 then
        evBonus_._legacySkillCdReduction = legacyBonus.skillCdReduction
        print(string.format("[Legacy] 军事L3: 技能CD -%d%%", legacyBonus.skillCdReduction * 100))
    end
    if legacyBonus.commanderStartLevel > 1 then
        evBonus_._legacyCommanderStartLv = legacyBonus.commanderStartLevel
        print(string.format("[Legacy] 军事L4: 指挥官初始Lv%d", legacyBonus.commanderStartLevel))
    end
    if legacyBonus.bossDmgBonus > 0 then
        evBonus_._legacyBossDmgBonus = legacyBonus.bossDmgBonus
        print(string.format("[Legacy] 军事L5: Boss首击 +%d%%", legacyBonus.bossDmgBonus * 100))
    end
    if legacyBonus.factionFavorBonus > 0 then
        evBonus_._legacyFactionFavor = legacyBonus.factionFavorBonus
        print(string.format("[Legacy] 外交L1: 初始好感 +%d", legacyBonus.factionFavorBonus))
    end
    if legacyBonus.colonizeSpeedBonus > 0 then
        rm_._legacyColonizeSpeedBonus = legacyBonus.colonizeSpeedBonus
        print(string.format("[Legacy] 经济L4: 殖民速度 +%d%%", legacyBonus.colonizeSpeedBonus * 100))
    end
    if legacyBonus.megaPhaseReduction > 0 then
        evBonus_._legacyMegaPhaseReduction = legacyBonus.megaPhaseReduction
        print(string.format("[Legacy] 经济L5: 巨构阶段 -%ds", legacyBonus.megaPhaseReduction))
    end
    if legacyBonus.agreementCdReduction > 0 then
        evBonus_._legacyAgreementCdReduction = legacyBonus.agreementCdReduction
        if ds_ then ds_._legacyAgreementCdReduction = legacyBonus.agreementCdReduction end
        print(string.format("[Legacy] 外交L2: 协议CD -%d%%", legacyBonus.agreementCdReduction * 100))
    end
    if legacyBonus.diploPositiveBonus > 0 then
        evBonus_._legacyDiploPositiveBonus = legacyBonus.diploPositiveBonus
        if ds_ then ds_._legacyDiploPositiveBonus = legacyBonus.diploPositiveBonus end
        print(string.format("[Legacy] 外交L3: 正面事件 +%d%%", legacyBonus.diploPositiveBonus * 100))
    end
    if legacyBonus.questRefreshReduction > 0 then
        rm_._legacyQuestRefreshReduction = legacyBonus.questRefreshReduction
        print(string.format("[Legacy] 外交L4: 任务刷新CD -%ds", legacyBonus.questRefreshReduction))
    end
    if legacyBonus.crisisCountdownBonus > 0 then
        evBonus_._legacyCrisisCountdownBonus = legacyBonus.crisisCountdownBonus
        GalaxyEvents._crisisCountdownBonus = legacyBonus.crisisCountdownBonus
        print(string.format("[Legacy] 外交L5: 危机倒计时 +%ds", legacyBonus.crisisCountdownBonus))
    end
    evBonus_._legacyBonuses = legacyBonus  -- 完整暴露给子系统

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
    -- P2-1: 应用每日挑战奖励（在系统实例化前调整资源，限制标志由各系统读取 evBonus_）
    if dailyChallengeMode_ and todayChallenge_ then
        local ch = todayChallenge_
        -- 初始资源加成
        if ch._initBonus then
            for res, delta in pairs(ch._initBonus) do
                rm_.resources[res] = (rm_.resources[res] or 0) + delta
            end
            print(string.format("[DailyChallenge] 初始资源加成已应用"))
        end
        -- 将挑战标志注入 evBonus_，供各子系统使用
        if ch._noCapital    then evBonus_._challengeNoCapital    = true end
        if ch._slotMinus1   then evBonus_._challengeSlotMinus1   = true end
        if ch._slowResearch then evBonus_._challengeSlowResearch = true end
        if ch._noMarket     then evBonus_._challengeNoMarket     = true end
        if ch._lessFleet    then evBonus_._challengeLessFleet    = true end
        if ch._bestMarket   then evBonus_._challengeBestMarket   = true end
        if ch._fastBuildBoost then evBonus_._challengeFastBuild  = true end
        if ch._delayFirstWave then evBonus_._challengeDelayWave  = ch._delayFirstWave end
        if ch._freeTier2Tech  then evBonus_._challengeFreeTech   = true end
        print(string.format("[DailyChallenge] 限制=%s 加成=%s",
            ch.restriction, ch.boost))
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
    GP_.totalShipsBuilt      = 0
    GP_.resMilestoneTimer    = 0
    GP_.resWarnTimer         = 0        -- P2-1: 重置资源预警计时器
    GP_.lowResWarnSent       = {}       -- P2-1: 重置已发送预警记录
    pirateAttackInfo_     = nil
    pirateWarnPlayed_     = false
    TL.playTime           = 0
    totalPlayTime_        = 0
    TL.extraTime          = 0
    TL.timeoutTriggered   = false
    saveTimer_            = 0
    ClientSave.ResetProgress()          -- 清除跨局存档锁

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
    isEndlessMode_        = false
    endlessRound_         = 0
    endlessStreak_        = 0      -- P2-1 V2.0: 重置连胜计数
    endlessStreakBuff_    = false  -- P2-1 V2.0: 重置连胜资源加成
    endlessLegendaryBuff_ = nil    -- P2-3: 重置传奇加成
    for k in pairs(endlessCardBonuses_) do endlessCardBonuses_[k] = 0 end  -- P2-1
    GameUI.SetEndlessRound(0)   -- 同步清除 TopBar 无尽轮次显示

    -- 6b. 重置探索任务
    explorerTasks_    = {}
    explorerTaskSeq_  = 0
    GameUI.RefreshExplorerTasks({})

    -- 6. 返回主菜单（刷新存档状态，让玩家重新选择）
    difficultyChosen_     = false
    diffHoverBtn_         = nil
    customDiffSlider_.name = nil   -- P1-2: 清除滑块拖拽状态
    mainMenuActive_       = true
    mainMenuHover_    = nil
    hasSave_          = fileSystem:FileExists("galaxy_save.json")
    -- P2-1: 重置每日挑战临时状态（连续天数/日期由 gameEnd 持久化，此处只清运行时标志）
    dailyChallengeMode_ = false
    todayChallenge_     = nil
    -- P1-3: 重置联赛模式状态
    leagueMode_ = false
    GameUI.SetLeagueHud(nil)
    -- P2-2: 重置战役模式状态
    campaignMode_           = false
    campaignFirstColonize_  = false
    campaignVictoryPending_ = false
    campaignResetTimer_     = 0
    Campaign.Abort()
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
                    -- P3-1: 恢复新增战绩字段
                    careerStats_.bestDiff   = d.bestDiff   or ""
                    careerStats_.curStreak  = d.curStreak  or 0
                    careerStats_.maxStreak  = d.maxStreak  or 0
                    careerStats_.shipKills  = (type(d.shipKills) == "table") and d.shipKills or {}
                    careerStats_.recentWins = (type(d.recentWins) == "table") and d.recentWins or {}
                    -- P2-3: 读取已兑换奖励列表
                    if type(d.redeemed) == "table" then
                        savedRedeemed_ = d.redeemed
                    end
                    -- P1-1: 读取文明积分和已解锁传承节点（向前兼容旧存档）
                    evolutionPoints_ = d.evolutionPoints or 0
                    evolutionUnlocked_ = {}
                    if type(d.evolutionUnlocked) == "table" then
                        for _, nid in ipairs(d.evolutionUnlocked) do
                            evolutionUnlocked_[nid] = true
                        end
                    end
                    print(string.format("[Heritage] 文明积分=%d 已解锁=%d项",
                        evolutionPoints_, getEvolutionUnlockedCount()))
                    -- P2-1: 读取每日挑战连胜数据
                    challengeStreak_   = d.challengeStreak   or 0
                    lastChallengeDate_ = d.lastChallengeDate or ""
                    print(string.format("[DailyChallenge] 连续=%d天 上次=%s",
                        challengeStreak_, lastChallengeDate_))
                    -- P2-2: 恢复战役进度
                    if type(d.campaign) == "table" then
                        Campaign.LoadSaveData(d.campaign)
                        local completed = d.campaign.completed or {}
                        print(string.format("[Campaign] 已完成关卡=%d", #completed))
                    end
                    -- P1-3: 恢复联赛数据
                    if type(d.leagueData) == "table" then
                        local LS = require("game.LeagueSystem")
                        LS.Deserialize(d.leagueData)
                    end
                    -- P1-3 V2.4: 恢复指挥官数据
                    if type(d.commanders) == "table" then
                        Commander.Deserialize(d.commanders)
                    end
                    -- P2-3 V2.4: 恢复舰队涂装数据
                    if type(d.livery) == "table" then
                        LiverySystem.Deserialize(d.livery)
                    end
                    -- P3-1 V2.4: 恢复银河百科解锁进度
                    if type(d.galactopedia) == "table" then
                        GalactopediaSystem.Deserialize(d.galactopedia)
                    end
                end
            end
        end)
        if not ok3 then print("[Career] 战绩加载失败: " .. tostring(err3)) end
    end
    print("[Client] 存档状态: " .. (hasSave_ and "有存档" or "无存档"))

    -- 创建 NanoVG 字体（主菜单/难度屏幕/游戏 UI 共用）
    nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 初始化输入模块（传递 Host context）
    ClientInput.Init(buildInputHost())

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
    -- P3-3: 自动暂停 — 切后台/最小化时暂停游戏
    SubscribeToEvent("InputFocus", function(_, ed)
        local focused = ed["Focus"]:GetBool()
        local minimized = ed["Minimized"]:GetBool()
        -- 检查设置面板的自动暂停开关
        local Settings = require("game.ui.SettingsPanel")
        if not Settings.GetAutoPause() then return end
        if (not focused) or minimized then
            -- 仅在游戏进行中暂停（菜单/难度选择无需暂停）
            if difficultyChosen_ and not endGameTriggered_ then
                TL.bgPaused = true
                print("[AutoPause] 游戏已暂停 (切后台)")
            end
        else
            -- 恢复焦点
            if TL.bgPaused then
                TL.bgPaused = false
                TL.bgPauseNotifyT = 2.5  -- 显示 "已恢复" 提示 2.5 秒
                print("[AutoPause] 游戏已恢复")
            end
        end
    end)

    -- P1-1: 昵称文本输入 / P2-2a: 舰队命名文本输入
    SubscribeToEvent("TextInput", function(_, ed)
        local ch = ed["Text"]:GetString()
        -- P2-2a: 舰队命名优先（模态覆盖时拦截）
        if GameUI.IsFleetNaming() then
            GameUI.OnFleetNamingText(ch)
            return
        end
        if not nicknameInputActive_ then return end
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

    -- V3.0: 注册并初始化所有扩展模块
    ModuleRegistry.RegisterAll()
    ModuleRegistry.InitAll({
        rm = rm_, rs = rs_, fm = fm_, player = player_,
        evBonus = evBonus_, ds = ds_,
    })

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
