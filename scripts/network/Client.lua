---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-- ============================================================================
-- network/Client.lua — 银河征服 客户端（薄包装层）
--   主逻辑已委托至子模块：
--     * network.ClientGameLoop    — update/render/输入/主菜单/难度选择
--     * network.ClientDataManager — 存档/读档/生涯战绩/基地模块效果
--     * network.ClientSave        — 序列化与反序列化
--     * network.ClientStats       — 局内统计面板渲染
--     * network.ClientBattle      — 战斗、远征、探索任务、DDA
--     * network.ClientGalaxy      — 行星建造/殖民/外交/市场
--     * network.ClientSetup       — 场景与 UI 初始化（GameUI.Init 回调装配）
--     * network.ClientInput       — 鼠标/键盘/菜单命中检测
-- ============================================================================

local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local GameUI      = require("game.GameUI")
local Audio       = require("game.AudioManager")
local UICommon    = require("game.ui.UICommon")

local ClientSave        = require("network.ClientSave")
local ClientStats       = require("network.ClientStats")
local ClientBattle      = require("network.ClientBattle")
local ClientGalaxy      = require("network.ClientGalaxy")
local ClientSetup       = require("network.ClientSetup")
local ClientInput       = require("network.ClientInput")
local ClientMenus       = require("network.ClientMenus")
local ClientGameLoop    = require("network.ClientGameLoop")
local ClientDataManager = require("network.ClientDataManager")

local Client = {}

-- ============================================================================
-- 共享状态（Host Context 源）——保留原样，子模块通过 host 表访问
-- ============================================================================
local vg_           = nil
local screenW_      = 800
local screenH_      = 600
local uiScale_      = 1.0

local TL = {
    BASE_LIMIT      = 7200,
    EXTRA_PER_AD    = 3600,
    MAX_EXTRA       = 7200,
    playTime        = 0,
    extraTime       = 0,
    timeoutTriggered = false,
    adWatching      = false,
    bgPaused        = false,
    bgPauseNotifyT  = 0,
}
local lastDt_ = 0.016

local currentScene_   = "galaxy"
local refreshTimer_   = 0
local selectedPlanet_ = nil
local lastShownRemaining_ = -1

local rm_      = Sys.ResourceManager.new()
local bs_      = Sys.BuildingSystem.new(rm_)
local bbs_     = Sys.BaseBuildingSystem.new(rm_)
local rs_      = Sys.ResearchSystem.new(rm_, bs_)
local ms_      = Sys.MarketSystem.new(rm_)
local bm_      = require("game.BlackmarketSystem") and (require("game.BlackmarketSystem").new and require("game.BlackmarketSystem").new(rm_)) or nil
if not bm_ then
    local BM = require("game.BlackMarketSystem")
    bm_ = BM.new and BM.new(rm_) or nil
end
local player_  = Sys.PlayerProfile.new()
local spq_     = Sys.ShipProductionQueue.new(rm_)
local fm_      = Sys.FleetManager.new()
local activeFleetId_       = 1
local explorerColonizeMode_ = false
local ds_      = nil
local pendingDiploEvent_ = nil

local baseEffectsDirty_ = true
local pirateAI_ = nil
local pirateAttackInfo_ = nil
local pirateWarnPlayed_ = false
local endGameTriggered_ = false
local piratesKilled_    = 0
local adBonusNext_    = false
local adBonusApplied_ = false
local AD_BONUS = { metal = 300, esource = 150, nuclear = 80 }
local evBonus_ = {}
local PLANET_UPGRADE_COSTS = {
    [2] = { metal = 200 },
    [3] = { metal = 500, crystal = 200 },
    [4] = { metal = 500, crystal = 500, esource = 500 },
    [5] = { metal = 1000, crystal = 1000, esource = 1000 },
}
local battleStatsCache_ = {}
local totalResearch_    = 0
local hiddenStats_ = {
    totalShipsLostCampaign = 0,
    focusKills             = 0,
    focusBossKill          = false,
    totalCardsChosen       = 0,
    totalExplored          = 0,
    exploreTypesFound      = {},
}

local expeditions_ = {}
local lastExpedition_ = {}

local dda_ = {
    enabled       = true,
    baseFactor    = 1.0,
    currentFactor = 1.0,
    recentResults = {},
    MAX_HISTORY   = 5,
    evalTimer     = 0,
    EVAL_INTERVAL = 90,
    adjustCount   = 0,
    STEP_BATTLE   = 0.10,
    STEP_PERIODIC = 0.04,
    MIN_MULT      = 0.60,
    MAX_MULT      = 1.55,
}

local careerStats_ = {
    totalGames    = 0,
    totalWins     = 0,
    bestWave      = 0,
    totalKills    = 0,
    totalColonies = 0,
    bestMvpShip   = "",
    playtime      = 0,
    bestDiff      = "",
    curStreak     = 0,
    maxStreak     = 0,
    shipKills     = {},
    recentWins    = {},
}

local EVOLUTION_TREE = {
    { id = "mil_1", line = "military", tier = 1, unlockCost = 2,
      name = "久战之师", icon = "⚔", desc = "首波攻击+8%",
      apply = function(cfg) cfg._mil1 = true end },
    { id = "mil_2", line = "military", tier = 2, unlockCost = 5,
      name = "钢铁洪流", icon = "🛡", desc = "驱逐舰/战巡HP+10%",
      apply = function(cfg) cfg._mil2 = true end },
    { id = "mil_3", line = "military", tier = 3, unlockCost = 10,
      name = "连击共鸣", icon = "💥", desc = "连锁触发阈值3→2",
      apply = function(cfg) cfg._mil3 = true end },
    { id = "mil_4", line = "military", tier = 4, unlockCost = 18,
      name = "精英旗舰", icon = "🚀", desc = "CARRIER建造时间-20%",
      apply = function(cfg) cfg._mil4 = true end },
    { id = "eco_1", line = "economy", tier = 1, unlockCost = 2,
      name = "勤劳星民", icon = "⛏", desc = "初始金属+200",
      apply = function(cfg) cfg._eco1 = true end },
    { id = "eco_2", line = "economy", tier = 2, unlockCost = 5,
      name = "高效精炼", icon = "⚗", desc = "精炼速率+15%",
      apply = function(cfg) cfg._eco2 = true end },
    { id = "eco_3", line = "economy", tier = 3, unlockCost = 10,
      name = "市场老手", icon = "💰", desc = "市场交易折扣+10%",
      apply = function(cfg) cfg._eco3 = true end },
    { id = "eco_4", line = "economy", tier = 4, unlockCost = 18,
      name = "帝国基建", icon = "🏗", desc = "首个建筑免费",
      apply = function(cfg) cfg._eco4 = true end },
    { id = "sci_1", line = "science", tier = 1, unlockCost = 2,
      name = "求知欲",   icon = "🔬", desc = "首项科技研究速度+25%",
      apply = function(cfg) cfg._sci1 = true end },
    { id = "sci_2", line = "science", tier = 2, unlockCost = 5,
      name = "技术储备", icon = "📡", desc = "初始解锁一项Tier1科技",
      apply = function(cfg) cfg._sci2 = true end },
    { id = "sci_3", line = "science", tier = 3, unlockCost = 10,
      name = "分叉洞见", icon = "🔀", desc = "专精科技两路各解锁一次",
      apply = function(cfg) cfg._sci3 = true end },
    { id = "sci_4", line = "science", tier = 4, unlockCost = 18,
      name = "量子突破", icon = "⚛", desc = "Tier4科技费用-30%",
      apply = function(cfg) cfg._sci4 = true end },
}
local evolutionPoints_  = 0
local evolutionUnlocked_ = {}
local heritageOpen_     = false
local heritageHover_    = nil
local savedAchievements_ = nil
local savedRedeemed_     = nil

local campaignMode_           = false
local campaignFirstColonize_  = false
local campaignVictoryPending_ = false
local campaignResetTimer_     = 0

local dailyChallengeMode_ = false
local todayChallenge_     = nil
local challengeStreak_    = 0
local lastChallengeDate_  = ""

local mainMenuActive_   = true
local hasSave_          = false
local mainMenuHover_    = nil
local skipSaveLoad_     = false
local difficultyChosen_ = false
local menuT_            = 0
local difficulty_       = "normal"
local diffHoverBtn_     = nil
local playerName_       = "指挥官"
local nicknameInputActive_ = false
local nicknameCursorT_     = 0
local statsOpen_           = false
local fleetOverviewHeld_   = false
local statsMouse_          = { 0, 0 }

local customDiff_ = {
    attackFactor = 1.0,
    initResBonus = 0,
    maxThreat    = 5,
}
local customDiffSlider_ = { name = nil, x0 = 0, w0 = 0 }
local leagueMode_ = false
local isEndlessMode_ = false
local endlessRound_  = 0
local endlessStreakBuff_ = false
local endlessLegendaryBuff_ = nil
local endlessCardBonuses_ = {
    shipDmgMult       = 0,
    shipHealthMult    = 0,
    aoeRadiusMult     = 0,
    miningRateMult    = 0,
    energyRateMult    = 0,
    nuclearRateMult   = 0,
    nuclearCapBonus   = 0,
    shipyardSpeedMult = 0,
    fleetCapBonus     = 0,
    waveRepairPct     = 0,
    explorerDurMult   = 0,
    intelRateMult     = 0,
}

local explorerTasks_   = {}
local explorerTaskSeq_ = 0

local DIFFICULTY_CONFIGS = {
    easy   = { label = "简单", color = { 80, 200, 120 }, attackFactor = 2.2, maxThreat = 2,
               desc = "海盗进攻频率大幅降低，初始资源充裕，适合初次体验",
               initRes = { metal = 800, esource = 500, nuclear = 200 } },
    normal = { label = "普通", color = { 100, 160, 255 }, attackFactor = 1.0, maxThreat = 5,
               desc = "标准游戏体验，攻守均衡" },
    hard   = { label = "困难", color = { 220, 80, 80 }, attackFactor = 0.65, maxThreat = 5,
               desc = "海盗进攻频繁，考验战略布局",
               initRes = { metal = -300, esource = -200 } },
    custom = { label = "自定义", color = { 200, 180, 255 }, attackFactor = 1.0, maxThreat = 5,
               desc = "自由调整海盗强度和初始资源" },
}
local DIFF_ORDER = { "easy", "normal", "hard", "custom" }

local scene_      = nil
local saveTimer_  = 0
local AUTO_SAVE_INTERVAL = 60
local diploSyncTimer_ = 0

local GP_ = {
    completedGoals    = {},
    totalShipsBuilt   = 0,
    shipTypeBuilt     = {},
    resMilestoneTimer = 0,
    resWarnTimer      = 0,
    lowResWarnSent    = {},
    planetProdHistory = {},
    prodSampleTimer   = 0,
    PROD_SAMPLE_INTERVAL = 30,
    PROD_MAX_SAMPLES    = 10,
}

-- ============================================================================
-- Host Context 构建器 ——将本地 upvalue 暴露给子模块
-- ============================================================================

local function buildCommonHost()
    local scalars = {
        vg_                     = function() return vg_ end,
        screenW_                = function() return screenW_ end,
        screenH_                = function() return screenH_ end,
        uiScale_                = function() return uiScale_ end,
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
        adBonusApplied_         = function() return adBonusApplied_ end,
        baseEffectsDirty_       = function() return baseEffectsDirty_ end,
        savedAchievements_      = function() return savedAchievements_ end,
        savedRedeemed_          = function() return savedRedeemed_ end,
        skipSaveLoad_           = function() return skipSaveLoad_ end,
        dailyChallengeMode_     = function() return dailyChallengeMode_ end,
        todayChallenge_         = function() return todayChallenge_ end,
        evolutionPoints_        = function() return evolutionPoints_ end,
        mainMenuActive_         = function() return mainMenuActive_ end,
        hasSave_                = function() return hasSave_ end,
        difficultyChosen_       = function() return difficultyChosen_ end,
        menuT_                  = function() return menuT_ end,
        diffHoverBtn_           = function() return diffHoverBtn_ end,
        playerName_             = function() return playerName_ end,
        nicknameInputActive_    = function() return nicknameInputActive_ end,
        statsOpen_              = function() return statsOpen_ end,
        fleetOverviewHeld_      = function() return fleetOverviewHeld_ end,
        customDiffSlider_name   = function() return customDiffSlider_.name end,
        heritageOpen_           = function() return heritageOpen_ end,
        heritageHover_          = function() return heritageHover_ end,
        mainMenuHover_          = function() return mainMenuHover_ end,
        endlessLegendaryBuff_   = function() return endlessLegendaryBuff_ end,
        pirateWarnPlayed_       = function() return pirateWarnPlayed_ end,
        refreshTimer_           = function() return refreshTimer_ end,
        lastShownRemaining_     = function() return lastShownRemaining_ end,
        saveTimer_              = function() return saveTimer_ end,
        lastDt_                 = function() return lastDt_ end,
        evBonus_                = function() return evBonus_ end,
        lastChallengeDate_      = function() return lastChallengeDate_ end,
        challengeStreak_        = function() return challengeStreak_ end,
        AUTO_SAVE_INTERVAL      = function() return AUTO_SAVE_INTERVAL end,
    }
    local writers = {
        vg_                     = function(v) vg_ = v end,
        screenW_                = function(v) screenW_ = v end,
        screenH_                = function(v) screenH_ = v end,
        uiScale_                = function(v) uiScale_ = v end,
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
        adBonusApplied_         = function(v) adBonusApplied_ = v end,
        baseEffectsDirty_       = function(v) baseEffectsDirty_ = v end,
        savedAchievements_      = function(v) savedAchievements_ = v end,
        savedRedeemed_          = function(v) savedRedeemed_ = v end,
        skipSaveLoad_           = function(v) skipSaveLoad_ = v end,
        dailyChallengeMode_     = function(v) dailyChallengeMode_ = v end,
        todayChallenge_         = function(v) todayChallenge_ = v end,
        evolutionPoints_        = function(v) evolutionPoints_ = v end,
        mainMenuActive_         = function(v) mainMenuActive_ = v end,
        hasSave_                = function(v) hasSave_ = v end,
        difficultyChosen_       = function(v) difficultyChosen_ = v end,
        menuT_                  = function(v) menuT_ = v end,
        diffHoverBtn_           = function(v) diffHoverBtn_ = v end,
        playerName_             = function(v) playerName_ = v end,
        nicknameInputActive_    = function(v) nicknameInputActive_ = v end,
        statsOpen_              = function(v) statsOpen_ = v end,
        fleetOverviewHeld_      = function(v) fleetOverviewHeld_ = v end,
        customDiffSlider_name   = function(v) customDiffSlider_.name = v end,
        heritageOpen_           = function(v) heritageOpen_ = v end,
        heritageHover_          = function(v) heritageHover_ = v end,
        mainMenuHover_          = function(v) mainMenuHover_ = v end,
        endlessLegendaryBuff_   = function(v) endlessLegendaryBuff_ = v end,
        pirateWarnPlayed_       = function(v) pirateWarnPlayed_ = v end,
        refreshTimer_           = function(v) refreshTimer_ = v end,
        lastShownRemaining_     = function(v) lastShownRemaining_ = v end,
        saveTimer_              = function(v) saveTimer_ = v end,
        lastDt_                 = function(v) lastDt_ = v end,
        evBonus_                = function(v) evBonus_ = v end,
        lastChallengeDate_      = function(v) lastChallengeDate_ = v end,
        challengeStreak_        = function(v) challengeStreak_ = v end,
    }
    local host = {
        -- table refs (direct)
        rm_ = rm_, bs_ = bs_, bbs_ = bbs_, rs_ = rs_, ms_ = ms_, bm_ = bm_,
        spq_ = spq_, fm_ = fm_, dda_ = dda_, player_ = player_,
        hiddenStats_ = hiddenStats_, battleStatsCache_ = battleStatsCache_,
        careerStats_ = careerStats_, endlessCardBonuses_ = endlessCardBonuses_,
        explorerTasks_ = explorerTasks_, lastExpedition_ = lastExpedition_,
        PLANET_UPGRADE_COSTS = PLANET_UPGRADE_COSTS,
        DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS,
        GP_ = GP_, TL = TL, customDiff_ = customDiff_, pirateAttackInfo_ = pirateAttackInfo_,
        statsMouse_ = statsMouse_, EVOLUTION_TREE_ = EVOLUTION_TREE,
        evolutionUnlocked_ = evolutionUnlocked_, AD_BONUS = AD_BONUS,
        expeditions_ = expeditions_,
        -- globals (convenience)
        clientCloud = _G.clientCloud,
        -- callback functions populated after submodules init
        saveGame = function() ClientDataManager.saveData() end,
        saveCareer = function() ClientDataManager.saveCareer() end,
        softReset = function() Client.softReset() end,
        markBaseEffectsDirty = function() ClientDataManager.markBaseEffectsDirty() end,
        handleLevelUp = function(leveled, newLevel, newRank, rewards)
            ClientDataManager.handleLevelUp(leveled, newLevel, newRank, rewards)
        end,
        applyBaseModuleEffects = function() ClientDataManager.applyBaseModuleEffects() end,
        checkStageGoals = function() ClientDataManager.checkStageGoals() end,
        showRewardAd = function(callback)
            local sdk = _G.sdk
            if not sdk then callback({ success = false, msg = "广告SDK不可用" }); return end
            sdk:ShowRewardVideoAd(callback)
        end,
        setupSceneAndUI = function() Client.setupSceneAndUI() end,
        onGameReady = function() Client.onGameReady() end,
        getAdCount = function()
            return math.floor((TL.MAX_EXTRA - TL.extraTime) / TL.EXTRA_PER_AD)
        end,
        getRemainingTime = function()
            return math.max(0, TL.BASE_LIMIT + TL.extraTime - TL.playTime)
        end,
        getDpr = function() return graphics:GetDPR() end,
        getScreenSize = function()
            local w, h = UICommon.getVirtualSize()
            uiScale_ = UICommon.uiScale
            screenW_ = w; screenH_ = h
            return w, h
        end,
        handleCrisisChoice = function(idx) ClientGameLoop.handleCrisisChoice(idx) end,
        getTodayStr = function()
            local t = os.date("*t")
            return string.format("%04d%02d%02d", t.year, t.month, t.day)
        end,
        getDailyCountdown = function()
            local t = os.date("*t")
            return math.max(0, 86400 - (t.hour * 3600 + t.min * 60 + t.sec))
        end,
        generateDailyChallenge = function(dateStr)
            return ClientGameLoop.generateDailyChallenge(dateStr)
        end,
        renderMainMenu = function(sw, sh) ClientGameLoop.renderMainMenu(sw, sh) end,
        renderDifficultyScreen = function(sw, sh) ClientGameLoop.renderDifficultyScreen(sw, sh) end,
        renderStatsPanel = function(sw, sh) ClientGameLoop.renderStatsPanel(sw, sh) end,
        onMainMenuSelect = function(key) ClientGameLoop.onMainMenuSelect(key) end,
        onEndlessModeSelect = function() ClientGameLoop.onEndlessModeSelect() end,
        onDifficultySelect = function(key) ClientGameLoop.onDifficultySelect(key) end,
        onLeagueModeSelect = function() ClientGameLoop.onLeagueModeSelect() end,
        getMainMenuHit = function(mx, my, sw, sh) return ClientMenus.GetMainMenuHit(mx, my, sw, sh, hasSave_) end,
        getDifficultyHit = function(mx, my, sw, sh)
            return ClientMenus.GetDifficultyHit(mx, my, sw, sh, {
                hover = diffHoverBtn_, customDiffSlider = customDiffSlider_.name,
                customDiff = customDiff_, DIFF_ORDER = DIFF_ORDER,
                DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS, menuT = menuT_,
                playerName = playerName_, nicknameActive = nicknameInputActive_,
                nicknameCursorT = nicknameCursorT_, nicknameHover = diffHoverBtn_ == "nickname_input",
            })
        end,
        getCustomSliderRects = function(sw, sh)
            return ClientMenus.GetCustomSliderRects(sw, sh, { customDiff = customDiff_ })
        end,
        getCustomPanelVisible = function()
            return ClientMenus.GetCustomPanelVisible({ hover = diffHoverBtn_, customDiffSlider = customDiffSlider_.name })
        end,
        getEndlessBtnLayout = function(sw, sh)
            return ClientMenus.GetEndlessBtnLayout(sw, sh, {
                hover = diffHoverBtn_, customDiffSlider = customDiffSlider_.name,
                customDiff = customDiff_, DIFF_ORDER = DIFF_ORDER,
                DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS, menuT = menuT_,
            })
        end,
        buildMenuCtx = function()
            return {
                hover            = diffHoverBtn_,
                customDiffSlider = customDiffSlider_.name,
                customDiff       = customDiff_,
                DIFF_ORDER       = DIFF_ORDER,
                DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS,
                menuT            = menuT_,
                playerName       = playerName_,
                nicknameActive   = nicknameInputActive_,
                nicknameCursorT  = nicknameCursorT_,
                nicknameHover    = diffHoverBtn_ == "nickname_input",
            }
        end,
        getEvolutionUnlockedCount = function()
            local n = 0
            for _ in pairs(evolutionUnlocked_) do n = n + 1 end
            return n
        end,
    }
    setmetatable(host, {
        __index = function(_, k)
            local getter = scalars[k]
            if getter then return getter() end
            return nil
        end,
        __newindex = function(_, k, v)
            local writer = writers[k]
            if writer then writer(v); return end
            rawset(host, k, v)
        end,
    })
    return host
end

local host_ = nil

local function getHost()
    if not host_ then
        host_ = buildCommonHost()
        ClientDataManager.init(host_)
    end
    return host_
end

-- ============================================================================
-- 转发 API
-- ============================================================================

function Client.setupSceneAndUI()
    ClientSetup.Init(getHost())
end

function Client.onGameReady()
    ClientDataManager.onGameReady()
end

function Client.softReset()
    local saved = require("game.AchievementSystem")
    savedAchievements_ = saved.GetUnlocked()
    savedRedeemed_     = saved.GetRedeemed()

    GameUI.Shutdown()
    if GalaxyScene.Shutdown then GalaxyScene.Shutdown() end

    rm_  = Sys.ResourceManager.new()
    local diffInitRes = (DIFFICULTY_CONFIGS[difficulty_] or {}).initRes
    if difficulty_ == "custom" and customDiff_.initResBonus ~= 0 then
        diffInitRes = {
            metal   = math.floor(customDiff_.initResBonus * 0.50),
            esource = math.floor(customDiff_.initResBonus * 0.35),
            nuclear = math.floor(customDiff_.initResBonus * 0.15),
        }
    end
    if diffInitRes then
        for res, delta in pairs(diffInitRes) do
            rm_.resources[res] = math.max(0, (rm_.resources[res] or 0) + delta)
        end
    end
    local evBonus = ClientDataManager.buildEvolutionBonus()
    evBonus_ = evBonus
    if evBonus._eco1 then rm_.resources.metal = (rm_.resources.metal or 0) + 200 end
    if evBonus._eco2 then rm_.rates = rm_.rates or {}; rm_.evolutionEsourceBonus = 0.15 end
    if evBonus._eco4 then rm_._heritageFirstBuildFree = true end

    local LegacySystem = require("game.LegacySystem")
    local legacyBonus = LegacySystem.GetBonuses()
    if legacyBonus.resourceBonus > 0 then
        for res, val in pairs(rm_.resources) do
            rm_.resources[res] = math.floor(val * (1 + legacyBonus.resourceBonus))
        end
    end
    if legacyBonus.buildSpeedBonus > 0 then rm_._legacyBuildSpeedBonus = legacyBonus.buildSpeedBonus end
    if legacyBonus.blackMarketDiscount > 0 then rm_._legacyMarketDiscount = legacyBonus.blackMarketDiscount end
    if legacyBonus.extraFleets > 0 then evBonus_._legacyExtraFleets = legacyBonus.extraFleets end
    if legacyBonus.extraModSlot > 0 then evBonus_._legacyExtraModSlot = legacyBonus.extraModSlot end
    if legacyBonus.skillCdReduction > 0 then evBonus_._legacySkillCdReduction = legacyBonus.skillCdReduction end
    if legacyBonus.commanderStartLevel > 1 then evBonus_._legacyCommanderStartLv = legacyBonus.commanderStartLevel end
    if legacyBonus.bossDmgBonus > 0 then evBonus_._legacyBossDmgBonus = legacyBonus.bossDmgBonus end
    if legacyBonus.factionFavorBonus > 0 then evBonus_._legacyFactionFavor = legacyBonus.factionFavorBonus end
    if legacyBonus.colonizeSpeedBonus > 0 then rm_._legacyColonizeSpeedBonus = legacyBonus.colonizeSpeedBonus end
    if legacyBonus.megaPhaseReduction > 0 then evBonus_._legacyMegaPhaseReduction = legacyBonus.megaPhaseReduction end
    evBonus_._legacyBonuses = legacyBonus

    adBonusApplied_ = false
    if adBonusNext_ then
        adBonusNext_ = false
        adBonusApplied_ = true
        for res, bonus in pairs(AD_BONUS) do rm_.resources[res] = (rm_.resources[res] or 0) + bonus end
    end
    if dailyChallengeMode_ and todayChallenge_ then
        local ch = todayChallenge_
        if ch._initBonus then for res, delta in pairs(ch._initBonus) do rm_.resources[res] = (rm_.resources[res] or 0) + delta end end
        if ch._noCapital    then evBonus_._challengeNoCapital    = true end
        if ch._slotMinus1   then evBonus_._challengeSlotMinus1   = true end
        if ch._slowResearch then evBonus_._challengeSlowResearch = true end
        if ch._noMarket     then evBonus_._challengeNoMarket     = true end
        if ch._lessFleet    then evBonus_._challengeLessFleet    = true end
        if ch._bestMarket   then evBonus_._challengeBestMarket   = true end
        if ch._fastBuildBoost then evBonus_._challengeFastBuild  = true end
        if ch._delayFirstWave then evBonus_._challengeDelayWave  = ch._delayFirstWave end
        if ch._freeTier2Tech  then evBonus_._challengeFreeTech   = true end
    end

    bs_  = Sys.BuildingSystem.new(rm_)
    bbs_ = Sys.BaseBuildingSystem.new(rm_)
    rs_  = Sys.ResearchSystem.new(rm_, bs_)
    ms_  = Sys.MarketSystem.new(rm_)
    player_ = Sys.PlayerProfile.new()
    spq_ = Sys.ShipProductionQueue.new(rm_)
    fm_  = Sys.FleetManager.new()

    currentScene_ = "galaxy"
    selectedPlanet_ = nil
    activeFleetId_ = 1
    explorerColonizeMode_ = false
    refreshTimer_ = 0
    lastShownRemaining_ = -1
    baseEffectsDirty_ = true
    endGameTriggered_ = false
    piratesKilled_ = 0
    battleStatsCache_ = {}
    totalResearch_ = 0
    GP_.totalShipsBuilt = 0
    GP_.resMilestoneTimer = 0
    GP_.resWarnTimer = 0
    GP_.lowResWarnSent = {}
    GP_.planetProdHistory = {}
    GP_.prodSampleTimer = 0
    pirateAttackInfo_ = nil
    pirateWarnPlayed_ = false
    TL.playTime = 0
    totalPlayTime_ = 0
    TL.extraTime = 0
    TL.timeoutTriggered = false
    saveTimer_ = 0
    ClientSave.ResetProgress()

    hiddenStats_.totalShipsLostCampaign = 0
    hiddenStats_.focusKills = 0
    hiddenStats_.focusBossKill = false
    hiddenStats_.totalCardsChosen = 0
    hiddenStats_.totalExplored = 0
    hiddenStats_.exploreTypesFound = {}

    dda_.recentResults = {}
    dda_.evalTimer = 0
    dda_.adjustCount = 0
    if GalaxyScene.ClearGarrisons then GalaxyScene.ClearGarrisons() end

    isEndlessMode_ = false
    endlessRound_ = 0
    endlessStreakBuff_ = false
    endlessLegendaryBuff_ = nil
    for k in pairs(endlessCardBonuses_) do endlessCardBonuses_[k] = 0 end
    GameUI.SetEndlessRound(0)

    for k in pairs(explorerTasks_) do explorerTasks_[k] = nil end
    explorerTaskSeq_ = 0
    GameUI.RefreshExplorerTasks({})

    difficultyChosen_ = false
    diffHoverBtn_ = nil
    customDiffSlider_.name = nil
    mainMenuActive_ = true
    mainMenuHover_ = nil
    hasSave_ = fileSystem:FileExists("galaxy_save.json")
    dailyChallengeMode_ = false
    todayChallenge_ = nil
    leagueMode_ = false
    GameUI.SetLeagueHud(nil)
    campaignMode_ = false
    campaignFirstColonize_ = false
    campaignVictoryPending_ = false
    campaignResetTimer_ = 0
    local Campaign = require("game.CampaignSystem")
    Campaign.Abort()

    print("[Client] softReset: 完成，返回主菜单")
end

function Client.mainMenu()
    mainMenuActive_ = true
    hasSave_ = fileSystem:FileExists("galaxy_save.json")
end

function Client.update(dt)
    ClientGameLoop.handleUpdate("update", { TimeStep = { GetFloat = function() return dt end } })
end

function Client.render()
    ClientGameLoop.handleNanoVGRender("render", {})
end

function Client.handleInput()
    ClientGameLoop.handleInput(getHost())
end

function Client.GetCareerStats()
    return ClientDataManager.getStats()
end

function Client.GetPlayerName()
    return playerName_
end

function Client.Start()
    print("=== Galactic Conquest Client Start ===")

    vg_ = nvgCreate(1)
    local w, h = UICommon.getVirtualSize()
    uiScale_ = UICommon.uiScale
    screenW_ = w; screenH_ = h

    scene_ = Scene()
    Audio.Init(scene_)

    hasSave_ = fileSystem:FileExists("galaxy_save.json")

    if fileSystem:FileExists("galaxy_career.json") then
        local ok, err = pcall(function()
            local f = File("galaxy_career.json", FILE_READ)
            if f:IsOpen() then
                local s = f:ReadString()
                f:Close()
                local d = cjson.decode(s)
                if type(d) == "table" then
                    careerStats_.totalGames    = d.totalGames    or 0
                    careerStats_.totalWins     = d.totalWins     or 0
                    careerStats_.bestWave      = d.bestWave      or 0
                    careerStats_.totalKills    = d.totalKills    or 0
                    careerStats_.totalColonies = d.totalColonies or 0
                    careerStats_.bestMvpShip   = d.bestMvpShip   or ""
                    careerStats_.playtime      = d.playtime      or 0
                    careerStats_.bestDiff      = d.bestDiff      or ""
                    careerStats_.curStreak     = d.curStreak     or 0
                    careerStats_.maxStreak     = d.maxStreak     or 0
                    careerStats_.shipKills     = type(d.shipKills) == "table" and d.shipKills or {}
                    careerStats_.recentWins    = type(d.recentWins) == "table" and d.recentWins or {}
                    if type(d.redeemed) == "table" then savedRedeemed_ = d.redeemed end
                    evolutionPoints_ = d.evolutionPoints or 0
                    evolutionUnlocked_ = {}
                    if type(d.evolutionUnlocked) == "table" then
                        for _, nid in ipairs(d.evolutionUnlocked) do evolutionUnlocked_[nid] = true end
                    end
                    challengeStreak_   = d.challengeStreak   or 0
                    lastChallengeDate_ = d.lastChallengeDate or ""
                    local Campaign = require("game.CampaignSystem")
                    if type(d.campaign) == "table" then Campaign.LoadSaveData(d.campaign) end
                    local LS = require("game.LeagueSystem")
                    if type(d.leagueData) == "table" then LS.Deserialize(d.leagueData) end
                    local Commander = require("game.CommanderSystem")
                    if type(d.commanders) == "table" then Commander.Deserialize(d.commanders) end
                    local Livery = require("game.LiverySystem")
                    if type(d.livery) == "table" then Livery.Deserialize(d.livery) end
                    local Galacto = require("game.GalactopediaSystem")
                    if type(d.galactopedia) == "table" then Galacto.Deserialize(d.galactopedia) end
                end
            end
        end)
        if not ok then print("[Career] 战绩加载失败: " .. tostring(err)) end
    end
    print("[Client] 存档状态: " .. (hasSave_ and "有存档" or "无存档"))

    nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    ClientInput.Init(getHost())

    -- 注册引擎事件（主循环由 ClientGameLoop 承担）
    SubscribeToEvent("NanoVGRender", function(evType, evData) ClientGameLoop.handleNanoVGRender(evType, evData) end)
    SubscribeToEvent("Update",       function(evType, evData) ClientGameLoop.handleUpdate(evType, evData) end)
    SubscribeToEvent("MouseButtonDown", function(evType, evData) ClientInput.OnMouseButtonDown(evType, evData) end)
    SubscribeToEvent("MouseButtonUp",   function(evType, evData) ClientInput.OnMouseButtonUp(evType, evData) end)
    SubscribeToEvent("MouseMove",       function(evType, evData) ClientInput.OnMouseMove(evType, evData) end)
    SubscribeToEvent("MouseWheel",      function(evType, evData) ClientInput.OnMouseWheel(evType, evData) end)
    SubscribeToEvent("KeyDown",         function(evType, evData) ClientInput.OnKeyDown(evType, evData) end)
    SubscribeToEvent("KeyUp",           function(evType, evData) ClientInput.OnKeyUp(evType, evData) end)

    SubscribeToEvent("InputFocus", function(_, ed)
        local focused = ed["Focus"]:GetBool()
        local minimized = ed["Minimized"]:GetBool()
        local Settings = require("game.ui.SettingsPanel")
        if not Settings.GetAutoPause() then return end
        if (not focused) or minimized then
            if difficultyChosen_ and not endGameTriggered_ then TL.bgPaused = true end
        else
            if TL.bgPaused then TL.bgPaused = false; TL.bgPauseNotifyT = 2.5 end
        end
    end)
    SubscribeToEvent("TextInput", function(_, ed)
        local ch = ed["Text"]:GetString()
        if GameUI.IsFleetNaming() then GameUI.OnFleetNamingText(ch); return end
        if not nicknameInputActive_ then return end
        if #playerName_ < 24 then playerName_ = playerName_ .. ch end
    end)
    SubscribeToEvent("TouchBegin", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        if mainMenuActive_ or not difficultyChosen_ then return end
        local tx = ed["X"]:GetInt() / uiScale_
        local ty = ed["Y"]:GetInt() / uiScale_
        if GameUI.OnTouchBegin(tid, tx, ty) then return end
        if currentScene_ == "battle" then return end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchBegin(tid, tx, ty)
    end)
    SubscribeToEvent("TouchMove", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        if mainMenuActive_ or not difficultyChosen_ then return end
        local tx = ed["X"]:GetInt() / uiScale_
        local ty = ed["Y"]:GetInt() / uiScale_
        if GameUI.OnTouchMove(tid, tx, ty) then return end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchMove(tid, tx, ty)
    end)
    SubscribeToEvent("TouchEnd", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        local dpr = graphics:GetDPR()
        local mx  = ed["X"]:GetInt() / dpr / uiScale_
        local my  = ed["Y"]:GetInt() / dpr / uiScale_
        if mainMenuActive_ then
            local hit = ClientMenus.GetMainMenuHit(mx, my, screenW_, screenH_, hasSave_)
            print(string.format("[Touch] mainMenu tap: mx=%.1f my=%.1f sw=%d sh=%d hit=%s dpr=%.1f uiScale=%.2f",
                mx, my, screenW_, screenH_, tostring(hit), dpr, uiScale_))
            if hit then ClientGameLoop.onMainMenuSelect(hit) end
            return
        end
        if not difficultyChosen_ then
            local ctx = {
                hover = diffHoverBtn_, customDiffSlider = customDiffSlider_.name,
                customDiff = customDiff_, DIFF_ORDER = DIFF_ORDER,
                DIFFICULTY_CONFIGS = DIFFICULTY_CONFIGS, menuT = menuT_,
                playerName = playerName_, nicknameActive = nicknameInputActive_,
                nicknameCursorT = nicknameCursorT_, nicknameHover = diffHoverBtn_ == "nickname_input",
            }
            local hit = ClientMenus.GetDifficultyHit(mx, my, screenW_, screenH_, ctx)
            if hit == "endless" then ClientGameLoop.onEndlessModeSelect()
            elseif hit then ClientGameLoop.onDifficultySelect(hit) end
            return
        end
        local tx = ed["X"]:GetInt() / uiScale_
        local ty = ed["Y"]:GetInt() / uiScale_
        if GameUI.OnTouchEnd(tid, tx, ty) then return end
        if currentScene_ == "battle" then
            local BattleScene = require("game.BattleScene")
            BattleScene.OnClick(mx, my)
            return
        end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchEnd(tid, tx, ty)
    end)

    print("=== 就绪 | 等待难度选择... ===")
end

function Client.Stop()
    GameUI.Shutdown()
    if vg_ then nvgDelete(vg_); vg_ = nil end
    print("=== Galactic Conquest Client Stop ===")
end

return Client
