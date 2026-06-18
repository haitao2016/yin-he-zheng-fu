-- Auto-split from Client.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


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
