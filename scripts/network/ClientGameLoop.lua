---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-----------------------------------------------------------------------
-- ClientGameLoop.lua — 主游戏循环 update / render / 输入分发
-- 职责:
--   * handleNanoVGRender: 主菜单 / 难度选择 / 战斗 / 星系场景渲染
--   * handleUpdate: 游戏时间、自动存档、DDA 微调、资源里程碑、
--                   远征结算、巨构/任务/外交 tick、探索任务 tick
--   * handleMouse* / handleKey* / handleMouseWheel: 转发给 ClientInput
--   * handleInput: 输入焦点、触摸/文本等引擎事件订阅
--   * Subscribe(host): 注册到引擎事件系统（由 Client.Start 调用一次）
--
-- 与 Client.lua 的协作:
--   子模块不 require("network.Client")，而是通过 init(host) 接受
--   一个"host context table"。
--   Host 暴露两类成员:
--     * Table 引用(直接读写共享): rm_ bs_ bbs_ rs_ ms_ bm_ spq_ fm_
--         dda_ player_ hiddenStats_ evBonus_ battleStatsCache_
--         careerStats_ endlessCardBonuses_ endlessCardBonuses_
--         explorerTasks_ lastExpedition_ PLANET_UPGRADE_COSTS
--         DIFFICULTY_CONFIGS GP_ TL customDiff_ pirateAttackInfo_
--     * Scalar 读写(通过 __index/__newindex 元方法):
--         pirateAI_ ds_ selectedPlanet_ activeFleetId_
--         explorerColonizeMode_ campaignMode_
--         campaignFirstColonize_ campaignVictoryPending_
--         campaignResetTimer_ endlessRound_ piratesKilled_
--         endGameTriggered_ explorerTaskSeq_ endlessStreakBuff_
--         totalPlayTime_ totalResearch_ isEndlessMode_ leagueMode_
--         difficulty_ currentScene_ pendingDiploEvent_ adBonusNext_
--         baseEffectsDirty_ savedAchievements_ savedRedeemed_
--         skipSaveLoad_ dailyChallengeMode_ vg_ screenW_ screenH_
--         uiScale_ mainMenuActive_ hasSave_ difficultyChosen_
--         menuT_ diffHoverBtn_ playerName_ nicknameInputActive_
--         statsOpen_ fleetOverviewHeld_ statsMouse_ scene_
--         endlessStreak_ endlessLegendaryBuff_ pirateWarnPlayed_
--         refreshTimer_ lastShownRemaining_ saveTimer_
--         customDiffSlider_name heritageOpen_ heritageHover_
--         mainMenuHover_ adBonusApplied_ evBonus_
--     * 函数回调:
--         saveGame saveCareer softReset markBaseEffectsDirty
--         handleLevelUp applyBaseModuleEffects checkStageGoals
--         showRewardAd getAdCount getRemainingTime getDpr
--         getScreenSize renderMainMenu renderDifficultyScreen
--         renderStatsPanel setupSceneAndUI onGameReady
--         getMainMenuHit getDifficultyHit getCustomSliderRects
--         getCustomPanelVisible getEvolutionUnlockedCount
--         onMainMenuSelect onDifficultySelect onEndlessModeSelect
--         buildMenuCtx handleCrisisChoice getTodayStr
--         getDailyCountdown generateDailyChallenge
-----------------------------------------------------------------------
local GalaxyScene = require("game.GalaxyScene")
local BattleScene = require("game.BattleScene")
local GameUI      = require("game.GameUI")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local QuestBoard  = require("game.QuestBoard")
local Campaign    = require("game.CampaignSystem")
local GalaxyEvents = require("game.GalaxyEvents")
local MegastructureSystem = require("game.MegastructureSystem")
local Commander   = require("game.CommanderSystem")
local GalactopediaSystem = require("game.GalactopediaSystem")
local LiverySystem = require("game.LiverySystem")
local LegacySystem = require("game.LegacySystem")
local ClientMenus = require("network.ClientMenus")
local ClientStats = require("network.ClientStats")
local ClientBattle = require("network.ClientBattle")
local ClientGalaxy = require("network.ClientGalaxy")
local ClientInput  = require("network.ClientInput")
local ClientSetup  = require("network.ClientSetup")

local M = {}

local H_ = nil

---@param host table
function M.init(host)
    H_ = host
end

local function H() return H_ end

local function accessTbl(key)
    local h = H()
    if not h then return nil end
    return rawget(h, key)
end

local function access(key)
    local h = H()
    if not h then return nil end
    return h[key]
end

---@return number
function M.getDpr()
    return graphics:GetDPR()
end

function M.getScreenSize()
    local w, h = UICommon.getVirtualSize()
    H().uiScale_ = UICommon.uiScale
    H().screenW_ = w
    H().screenH_ = h
    return w, h
end

local function buildMenuCtx()
    local h = H()
    return {
        hover            = h.diffHoverBtn_,
        customDiffSlider = h.customDiffSlider_name,
        customDiff       = accessTbl("customDiff_"),
        DIFF_ORDER       = {"easy", "normal", "hard", "custom"},
        DIFFICULTY_CONFIGS = accessTbl("DIFFICULTY_CONFIGS"),
        menuT            = h.menuT_,
        playerName       = h.playerName_,
        nicknameActive   = h.nicknameInputActive_,
        nicknameCursorT  = h.nicknameCursorT_ or 0,
        nicknameHover    = h.diffHoverBtn_ == "nickname_input",
    }
end

function M.renderMainMenu(sw, sh)
    local h = H()
    if h.heritageOpen_ then
        ClientMenus.RenderHeritagePanel(h.vg_, sw, sh, {
            evolutionTree     = accessTbl("EVOLUTION_TREE_"),
            evolutionPoints   = h.evolutionPoints_,
            evolutionUnlocked = accessTbl("evolutionUnlocked_"),
            hover             = h.heritageHover_,
            menuT             = h.menuT_,
            onUnlock = function(nodeId)
                local tree = accessTbl("EVOLUTION_TREE_") or {}
                local unlocked = accessTbl("evolutionUnlocked_") or {}
                for _, node in ipairs(tree) do
                    if node.id == nodeId and not unlocked[nodeId] then
                        if (h.evolutionPoints_ or 0) >= node.unlockCost then
                            local prereqOk = true
                            if node.tier > 1 then
                                for _, n2 in ipairs(tree) do
                                    if n2.line == node.line and n2.tier == node.tier - 1 then
                                        prereqOk = unlocked[n2.id] == true
                                        break
                                    end
                                end
                            end
                            if prereqOk then
                                h.evolutionPoints_ = (h.evolutionPoints_ or 0) - node.unlockCost
                                unlocked[nodeId] = true
                                pcall(function()
                                    local cFile = File("galaxy_career.json", FILE_WRITE)
                                    if cFile:IsOpen() then
                                        local sd = {}
                                        for k, v in pairs(accessTbl("careerStats_") or {}) do sd[k] = v end
                                        sd.evolutionPoints = h.evolutionPoints_
                                        local ul = {}
                                        for nid in pairs(unlocked) do ul[#ul+1] = nid end
                                        sd.evolutionUnlocked = ul
                                        sd.redeemed = Achievement.GetRedeemed()
                                        cFile:WriteString(cjson.encode(sd))
                                        cFile:Close()
                                    end
                                end)
                                Achievement.Check("heritage_points", {
                                    evolutionPoints = h.evolutionPoints_,
                                    unlockedCount   = M.getEvolutionUnlockedCount(),
                                })
                            end
                        end
                    end
                end
            end,
        })
    else
        ClientMenus.RenderMainMenu(h.vg_, sw, sh, {
            hover             = h.mainMenuHover_,
            hasSave           = h.hasSave_,
            menuT             = h.menuT_,
            evolutionPoints   = h.evolutionPoints_,
            unlockedCount     = M.getEvolutionUnlockedCount(),
            dailyCompleted    = (h.lastChallengeDate_ == M.getTodayStr()),
            dailyCountdown    = M.getDailyCountdown(),
        })
    end
end

function M.renderDifficultyScreen(sw, sh)
    ClientMenus.RenderDifficultyScreen(H().vg_, sw, sh, buildMenuCtx())
end

function M.renderStatsPanel(sw, sh)
    local h = H()
    ClientStats.Render(h.vg_, sw, sh, {
        statsOpen        = h.statsOpen_,
        statsMouse       = accessTbl("statsMouse_"),
        rs               = h.rs_,
        rm               = h.rm_,
        piratesKilled    = h.piratesKilled_,
        battleStatsCache = accessTbl("battleStatsCache_"),
        TL               = accessTbl("TL"),
        getRemainingTime = function() return M.getRemainingTime() end,
    })
end

function M.getRemainingTime()
    local TL = accessTbl("TL")
    return math.max(0, (TL.BASE_LIMIT or 7200) + (TL.extraTime or 0) - (TL.playTime or 0))
end

function M.getAdCount()
    local TL = accessTbl("TL")
    return math.floor(((TL.MAX_EXTRA or 7200) - (TL.extraTime or 0)) / (TL.EXTRA_PER_AD or 3600))
end

function M.getEvolutionUnlockedCount()
    local unlocked = accessTbl("evolutionUnlocked_") or {}
    local n = 0
    for _ in pairs(unlocked) do n = n + 1 end
    return n
end

function M.getTodayStr()
    local t = os.date("*t")
    return string.format("%04d%02d%02d", t.year, t.month, t.day)
end

function M.getDailyCountdown()
    local t = os.date("*t")
    local secsToday = t.hour * 3600 + t.min * 60 + t.sec
    return math.max(0, 86400 - secsToday)
end

function M.getMainMenuHit(mx, my, sw, sh)
    return ClientMenus.GetMainMenuHit(mx, my, sw, sh, H().hasSave_)
end

function M.getDifficultyHit(mx, my, sw, sh)
    return ClientMenus.GetDifficultyHit(mx, my, sw, sh, buildMenuCtx())
end

function M.getCustomSliderRects(sw, sh)
    return ClientMenus.GetCustomSliderRects(sw, sh, { customDiff = accessTbl("customDiff_") })
end

function M.getCustomPanelVisible()
    local h = H()
    return ClientMenus.GetCustomPanelVisible({ hover = h.diffHoverBtn_, customDiffSlider = h.customDiffSlider_name })
end

function M.getEndlessBtnLayout(sw, sh)
    return ClientMenus.GetEndlessBtnLayout(sw, sh, buildMenuCtx())
end

function M.onLeagueModeSelect()
    local h = H()
    local LS = require("game.LeagueSystem")
    LS.CheckWeekRollover()
    h.difficulty_       = "normal"
    h.difficultyChosen_ = true
    h.isEndlessMode_    = false
    h.leagueMode_       = true
    h.endlessRound_     = 0
    local cbs = accessTbl("endlessCardBonuses_") or {}
    for k in pairs(cbs) do cbs[k] = 0 end
    h.skipSaveLoad_     = true
    h.mainMenuActive_   = false
    if h.setupSceneAndUI then h.setupSceneAndUI() end
    if h.onGameReady then h.onGameReady() end
    local mod = LS.GetWeekModifier()
    local status = LS.GetStatus()
    local rank = LS.GetRank()
    GameUI.SetLeagueHud({
        rankIcon  = rank.icon,
        rankName  = rank.name,
        weekKey   = status.weekKey,
        modLabel  = mod.label,
        bestScore = status.bestScore or 0,
    })
    GameUI.Notify(string.format("🏆 星际联赛 %s — %s %s",
        status.weekKey, mod.label, mod.desc), "success")
    if h.adBonusApplied_ then
        h.adBonusApplied_ = false
        local AD_BONUS = accessTbl("AD_BONUS") or { metal = 300, esource = 150, nuclear = 80 }
        GameUI.Notify(string.format("🎬 广告加成已生效！金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear), "success")
    end
end

function M.onMainMenuSelect(key)
    local h = H()
    if key == "new" then
        h.skipSaveLoad_       = true
        h.dailyChallengeMode_ = false
        h.mainMenuActive_     = false
        print("[Client] 主菜单：选择新游戏")
    elseif key == "continue" and h.hasSave_ then
        h.mainMenuActive_     = false
        h.dailyChallengeMode_ = false
        h.difficultyChosen_   = true
        print("[Client] 主菜单：选择继续游戏")
        if h.setupSceneAndUI then h.setupSceneAndUI() end
        if h.onGameReady then h.onGameReady() end
        GameUI.Notify("欢迎回来，指挥官！", "info")
    elseif key == "campaign" then
        h.campaignMode_       = true
        h.dailyChallengeMode_ = false
        h.skipSaveLoad_       = true
        h.mainMenuActive_     = false
        local targetIdx = 1
        for i = 1, #Campaign.GetLevels() do
            if not Campaign.IsLevelCompleted(i) then
                targetIdx = i; break
            end
        end
        Campaign.StartLevel(targetIdx)
        h.campaignFirstColonize_ = false
        local level = Campaign.GetCurrentLevel()
        h.difficulty_       = level and level.difficulty or "normal"
        h.difficultyChosen_ = true
        h.isEndlessMode_    = false
        h.endlessRound_     = 0
        print(string.format("[Campaign] 进入战役关卡 %d (%s)", targetIdx, h.difficulty_))
        if h.setupSceneAndUI then h.setupSceneAndUI() end
        if h.onGameReady then h.onGameReady() end
        Campaign.TriggerDialogue("intro")
        GameUI.Notify("⚔ " .. (level and level.name or "战役") .. " 开始！", "success")
    elseif key == "daily" then
        local todayStr = M.getTodayStr()
        if h.lastChallengeDate_ == todayStr then
            if GameUI then GameUI.Notify("今日挑战已完成，明天再来！", "info") end
            return
        end
        h.todayChallenge_     = M.generateDailyChallenge(todayStr)
        h.dailyChallengeMode_ = true
        h.skipSaveLoad_       = true
        h.mainMenuActive_     = false
        print(string.format("[DailyChallenge] 今日挑战: 限制=%s 强化=%s",
            h.todayChallenge_ and h.todayChallenge_.restriction or "?",
            h.todayChallenge_ and h.todayChallenge_.boost or "?"))
    elseif key == "league" then
        M.onLeagueModeSelect()
    end
end

function M.onDifficultySelect(key)
    local h = H()
    if h.dailyChallengeMode_ then key = "normal" end
    h.difficulty_           = key
    h.difficultyChosen_     = true
    h.isEndlessMode_        = false
    h.endlessRound_         = 0
    h.endlessLegendaryBuff_ = nil
    local cbs = accessTbl("endlessCardBonuses_") or {}
    for k in pairs(cbs) do cbs[k] = 0 end
    local diffCfg = accessTbl("DIFFICULTY_CONFIGS") or {}
    if key == "custom" then
        local cd = accessTbl("customDiff_") or {}
        diffCfg.custom = diffCfg.custom or {}
        diffCfg.custom.attackFactor = cd.attackFactor
        diffCfg.custom.maxThreat    = math.floor(cd.maxThreat or 5)
    end
    local cfg = diffCfg[key]
    print(string.format("[Client] 难度已选择: %s (attackFactor=%.1f, maxThreat=%d)",
        cfg.label, cfg.attackFactor, cfg.maxThreat))
    if h.setupSceneAndUI then h.setupSceneAndUI() end
    if h.onGameReady then h.onGameReady() end
    if h.dailyChallengeMode_ and h.todayChallenge_ then
        GameUI.ShowDailyChallengeHint(h.todayChallenge_)
        GameUI.Notify(string.format("🎯 每日挑战开始！限制：%s", h.todayChallenge_.restrictDesc), "warn")
    end
    if key == "custom" then
        local cd = accessTbl("customDiff_") or {}
        local freqLabel = cd.attackFactor < 0.8 and "极快"
            or cd.attackFactor < 1.2 and "普通"
            or cd.attackFactor < 1.8 and "较慢" or "很慢"
        local resStr = cd.initResBonus > 0
            and string.format("+%d", cd.initResBonus)
            or cd.initResBonus < 0
            and tostring(cd.initResBonus)
            or "标准"
        GameUI.Notify(string.format(
            "自定义难度：进攻%s · 初始资源%s · 威胁Lv%d",
            freqLabel, resStr, math.floor(cd.maxThreat or 5)), "info")
    else
        GameUI.Notify("难度: " .. cfg.label .. " —— 征服银河！", "info")
    end
    if h.adBonusApplied_ then
        h.adBonusApplied_ = false
        local AD_BONUS = accessTbl("AD_BONUS") or { metal = 300, esource = 150, nuclear = 80 }
        GameUI.Notify(string.format("🎬 广告加成已生效！金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear), "success")
    end
end

function M.onEndlessModeSelect()
    local h = H()
    h.difficulty_       = "normal"
    h.difficultyChosen_ = true
    h.isEndlessMode_    = true
    h.endlessRound_     = 0
    local cbs = accessTbl("endlessCardBonuses_") or {}
    for k in pairs(cbs) do cbs[k] = 0 end
    print("[Client] 无尽征服模式已启动")
    if h.setupSceneAndUI then h.setupSceneAndUI() end
    if h.onGameReady then h.onGameReady() end
    GameUI.SetEndlessRound(0)
    GameUI.Notify("⚔️ 无尽征服模式 —— 歼灭所有敌人，战至最后一刻！", "success")
    if h.adBonusApplied_ then
        h.adBonusApplied_ = false
        local AD_BONUS = accessTbl("AD_BONUS") or { metal = 300, esource = 150, nuclear = 80 }
        GameUI.Notify(string.format("🎬 广告加成已生效！金属+%d 能源+%d 核燃料+%d",
            AD_BONUS.metal, AD_BONUS.esource, AD_BONUS.nuclear), "success")
    end
end

function M.generateDailyChallenge(dateStr)
    local seed = 0
    for i = 1, #dateStr do
        seed = seed * 31 + string.byte(dateStr, i)
    end
    local function lcgRand(s) return (s * 16645251 + 1013904223) % 0x7FFFFFFF end
    local restrictions = {
        { id = "no_capital",    restrictDesc = "禁止建造大型舰（CARRIER/BATTLECRUISER/DESTROYER）",
          apply = function(cfg) cfg._noCapital = true end },
        { id = "slot_minus1",   restrictDesc = "星球建筑槽上限 -1",
          apply = function(cfg) cfg._slotMinus1 = true end },
        { id = "slow_research", restrictDesc = "科技研究速度 ×0.5",
          apply = function(cfg) cfg._slowResearch = true end },
        { id = "no_market",     restrictDesc = "市场交易关闭",
          apply = function(cfg) cfg._noMarket = true end },
        { id = "less_fleet",    restrictDesc = "编队容量上限 -2",
          apply = function(cfg) cfg._lessFleet = true end },
    }
    local boosts = {
        { id = "free_tech1",  boostDesc = "随机免费解锁一项 Tier2 科技",
          apply = function(cfg) cfg._freeTier2Tech = true end },
        { id = "delay_wave",  boostDesc = "首波延迟 +30 秒",
          apply = function(cfg) cfg._delayFirstWave = 30 end },
        { id = "best_market", boostDesc = "市场汇率固定为最优",
          apply = function(cfg) cfg._bestMarket = true end },
        { id = "init_bonus",  boostDesc = "初始资源 +300 金属 +200 能源",
          apply = function(cfg) cfg._initBonus = { metal = 300, esource = 200 } end },
        { id = "fast_build",  boostDesc = "建造速度 ×1.5（首波前）",
          apply = function(cfg) cfg._fastBuildBoost = true end },
    }
    local s1 = lcgRand(seed)
    local s2 = lcgRand(s1 + 7919)
    local ri = (s1 % #restrictions) + 1
    local bi = (s2 % #boosts) + 1
    local cfg = {}
    restrictions[ri].apply(cfg)
    boosts[bi].apply(cfg)
    cfg.restriction  = restrictions[ri].id
    cfg.boost        = boosts[bi].id
    cfg.restrictDesc = restrictions[ri].restrictDesc
    cfg.boostDesc    = boosts[bi].boostDesc
    cfg.dateStr      = dateStr
    return cfg
end

function M.handleCrisisChoice(choiceIdx)
    local h = H()
    local rm_ = h.rm_
    local pre = GalaxyEvents.GetEndgameCrisis()
    if not pre then return end
    local ch = pre.choices and pre.choices[choiceIdx]
    local ok = GalaxyEvents.AdvanceCrisisPhase(choiceIdx)
    if not ok then return end
    if ch and ch.cost then
        for res, val in pairs(ch.cost) do
            if val > 0 then rm_:add(res, -val) end
        end
    end
    if ch and ch.penalty then
        for res, val in pairs(ch.penalty) do
            if val > 0 then rm_:add(res, -math.min(val, rm_:get(res) or 0)) end
        end
    end
    if ch and ch.expGain then
        local p = h.player_
        p.exp = (p.exp or 0) + ch.expGain
    end
    local post = GalaxyEvents.GetEndgameCrisis()
    if not post then return end
    if not post.resolved then
        GameUI.Notify(post.icon .. " " .. post.name ..
            " — 阶段 " .. post.phase .. " 开始！", "warn")
        GameUI.ShowEndgameCrisisPanel(post, function(idx) M.handleCrisisChoice(idx) end)
    end
end

---@param eventType string
---@param eventData table
function M.handleNanoVGRender(eventType, eventData)
    local h = H()
    local dpr  = M.getDpr()
    local logW = graphics:GetWidth()  / dpr
    local logH = graphics:GetHeight() / dpr
    local sw, sh = M.getScreenSize()
    local vg_ = h.vg_

    nvgBeginFrame(vg_, logW, logH, dpr)
    nvgSave(vg_)
    nvgScale(vg_, h.uiScale_ or 1, h.uiScale_ or 1)

    if h.mainMenuActive_ then
        M.renderMainMenu(sw, sh)
        nvgRestore(vg_)
        nvgEndFrame(vg_)
        return
    end

    if not h.difficultyChosen_ then
        M.renderDifficultyScreen(sw, sh)
        nvgRestore(vg_)
        nvgEndFrame(vg_)
        return
    end

    if h.currentScene_ == "battle" then
        BattleScene.Render()
    else
        GalaxyScene.Render()
        GameUI.RenderProgressBars(h.selectedPlanet_)
    end

    GameUI.RenderTopBar()
    GameUI.RenderSceneTitle()
    GameUI.RenderHUD(h.lastDt_ or 0)
    GameUI.RenderNotifications()

    local TL = accessTbl("TL")
    if TL and TL.bgPaused then
        nvgBeginPath(vg_)
        nvgRect(vg_, 0, 0, sw, sh)
        nvgFillColor(vg_, nvgRGBA(0, 0, 0, 180))
        nvgFill(vg_)
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 28)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(180, 220, 255, 240))
        nvgText(vg_, sw / 2, sh / 2 - 10, "⏸ 游戏已暂停")
        nvgFontSize(vg_, 13)
        nvgFillColor(vg_, nvgRGBA(140, 180, 220, 180))
        nvgText(vg_, sw / 2, sh / 2 + 22, "返回窗口自动恢复")
    end
    if TL and TL.bgPauseNotifyT and TL.bgPauseNotifyT > 0 then
        local alpha = math.min(1, TL.bgPauseNotifyT / 0.5) * 200
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 14)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(80, 220, 160, math.floor(alpha)))
        nvgText(vg_, sw / 2, 40, "▶ 游戏已恢复")
    end

    if h.statsOpen_ and h.difficultyChosen_ and not h.mainMenuActive_ then
        M.renderStatsPanel(sw, sh)
    end

    nvgRestore(vg_)
    nvgEndFrame(vg_)
end

---@param eventType string
---@param eventData table
function M.handleUpdate(eventType, eventData)
    local h = H()
    local dt = eventData["TimeStep"]:GetFloat()
    h.lastDt_ = dt

    Audio.Update(dt)

    local TL = accessTbl("TL")
    if TL and TL.bgPaused then return end
    if TL and TL.bgPauseNotifyT and TL.bgPauseNotifyT > 0 then
        TL.bgPauseNotifyT = TL.bgPauseNotifyT - dt
    end

    if not h.difficultyChosen_ then
        h.menuT_ = (h.menuT_ or 0) + dt
        return
    end

    if not h.endGameTriggered_ then
        h.totalPlayTime_ = (h.totalPlayTime_ or 0) + dt
    end

    if (h.campaignResetTimer_ or 0) > 0 then
        h.campaignResetTimer_ = h.campaignResetTimer_ - dt
        if h.campaignResetTimer_ <= 0 then
            h.campaignResetTimer_ = 0
            if h.softReset then h.softReset() end
        end
    end

    if not (TL and TL.timeoutTriggered) and not h.isEndlessMode_ then
        TL.playTime = (TL.playTime or 0) + dt
        local secRemaining = math.floor(M.getRemainingTime())
        if secRemaining ~= h.lastShownRemaining_ then
            h.lastShownRemaining_ = secRemaining
            GameUI.SetRemainingTime(secRemaining)
        end
        if M.getRemainingTime() <= 0 then
            TL.timeoutTriggered = true
            GameUI.ShowTimeoutScreen(M.getAdCount(), function()
                if TL.adWatching then return end
                if M.getAdCount() <= 0 then return end
                TL.adWatching = true
                GameUI.Notify("广告加载中，请稍候...", "info")
                local sdk_ = _G.sdk
                if not sdk_ then
                    TL.adWatching = false
                    return
                end
                sdk_:ShowRewardVideoAd(function(result)
                    TL.adWatching = false
                    if result.success then
                        TL.extraTime = math.min(TL.MAX_EXTRA, TL.extraTime + TL.EXTRA_PER_AD)
                        GameUI.UpdateTimeoutAdCount(M.getAdCount())
                        GameUI.Notify(
                            "广告观看完成！已延长1小时。剩余可延长次数：" .. M.getAdCount(),
                            "success")
                        if M.getRemainingTime() > 0 then
                            TL.timeoutTriggered = false
                            GameUI.HideTimeoutScreen()
                        end
                    else
                        GameUI.Notify("广告未完整观看 (" .. (result.msg or "") .. ")，无法获得奖励", "warn")
                    end
                end)
            end)
            print("[Client] 游戏时间到期")
        end
        local remaining = M.getRemainingTime()
        if remaining <= 1800 and remaining > 1798 then
            GameUI.Notify("在线时间剩余30分钟，观看广告可延长1小时", "warn")
        elseif remaining <= 300 and remaining > 298 then
            GameUI.Notify("警告：在线时间仅剩5分钟！", "error")
        end
    end

    local rm_ = h.rm_
    local rs_ = h.rs_
    local bm_ = h.bm_
    local ms_ = h.ms_
    local spq_ = h.spq_
    local fm_ = h.fm_
    rm_:update(dt)
    ms_:update(dt)
    bm_:update(dt)

    do
        local buildMult = rm_.baseBonus and rm_.baseBonus.buildMult or 1.0
        local completed = MegastructureSystem.Update(dt, buildMult)
        if completed then
            Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
            GameUI.Notify("🏗️ 巨构工程阶段完工: " .. completed, "success")
            if h.applyBaseModuleEffects then h.applyBaseModuleEffects() end
            Achievement.Check("megastructure_phase", { id = completed })
            if h.saveGame then h.saveGame() end
        end
    end

    if not h.endGameTriggered_ then
        local completedQuest = QuestBoard.Update(dt, rm_, h.ds_)
        if completedQuest then
            Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
            local r = completedQuest.reward
            if r.metal   and r.metal > 0   then rm_:add("metal", r.metal) end
            if r.energy  and r.energy > 0  then rm_:add("esource", r.energy) end
            if r.salvage and r.salvage > 0 and fm_ then fm_:addSalvage(r.salvage) end
            if completedQuest.elite then rm_:addCredits(200) end
            local parts = {}
            if r.metal   and r.metal > 0   then parts[#parts+1] = "金属+"..r.metal end
            if r.energy  and r.energy > 0  then parts[#parts+1] = "能源+"..r.energy end
            if r.salvage and r.salvage > 0 then parts[#parts+1] = "🔩+"..r.salvage end
            if completedQuest.elite then parts[#parts+1] = "★+200" end
            local tag = completedQuest.elite and "⭐精英任务" or "📋任务"
            GameUI.Notify(tag .. "完成: " .. completedQuest.desc .. "  奖励: " .. table.concat(parts, " "), "success")
            Achievement.Check("quest_complete", { totalQuests = QuestBoard.GetCompletedCount() })
            GameUI.RefreshResourceBar()
            if h.saveGame then h.saveGame() end
        end
    end

    if h.ds_ and h.currentScene_ == "galaxy" and not h.endGameTriggered_ then
        local dipEvts = h.ds_:tick(dt, rm_, GalaxyScene.GetAllPlanets())
        for _, ev in ipairs(dipEvts or {}) do
            if ev.type == "long_trade" then
                local parts = {}
                for res, amt in pairs(ev.gain) do
                    local LABEL = { metal = "金属", crystal = "晶体", esource = "能源" }
                    parts[#parts+1] = (LABEL[res] or res) .. "+" .. amt
                end
                GameUI.Notify(string.format("%s %s 协议购入：%s",
                    ev.icon, ev.factionName, table.concat(parts, " ")), "trade")
            elseif ev.type == "long_trade_break" then
                GameUI.Notify(string.format("📋 与 %s 的长期协议已中断（好感度过低）", ev.factionName), "warn")
            elseif ev.type == "blockade_end" then
                local fd = Sys and Sys.NEUTRAL_FACTIONS and Sys.NEUTRAL_FACTIONS[ev.factionKey]
                GameUI.Notify(string.format("🚫 对 %s 的贸易封锁已到期", fd and fd.name or "?"), "info")
            elseif ev.type == "diplo_request" then
                h.pendingDiploEvent_ = ev
                GameUI.ShowDiploEvent(ev)
            elseif ev.type == "diplo_dispute" then
                h.pendingDiploEvent_ = ev
                GameUI.ShowDiploEvent(ev)
            elseif ev.type == "diplo_warning" then
                GameUI.Notify(ev.desc, "warn")
            elseif ev.type == "diplo_opportunity" then
                h.pendingDiploEvent_ = ev
                GameUI.ShowDiploEvent(ev)
            elseif ev.msg then
                GameUI.Notify(ev.msg, ev.msgType or "info")
            end
            if ev.factionKey then
                local gpF = GalactopediaSystem.TryUnlock("meet_faction_" .. ev.factionKey)
                if gpF then GameUI.Notify("📖 百科解锁: " .. gpF, "info") end
            end
        end
        local diploSyncT = (h.diploSyncTimer_ or 0) + dt
        h.diploSyncTimer_ = diploSyncT
        if diploSyncT >= 2.0 then
            h.diploSyncTimer_ = 0
            if GalaxyScene.SetDiploRelations then
                GalaxyScene.SetDiploRelations(h.ds_:getAllRelations(), h.ds_:getAgreements())
            end
        end
    end

    local GP_ = accessTbl("GP_") or {}
    GP_.resWarnTimer = (GP_.resWarnTimer or 0) + dt
    if GP_.resWarnTimer >= 5 and not h.endGameTriggered_ then
        GP_.resWarnTimer = 0
        local warnCfg = {
            metal   = { min = 200, msg = "⚠️ 金属储量不足（<200）！建议建造矿石精炼厂或殖民矿物星球" },
            esource = { min = 100, msg = "⚠️ 能源储量不足（<100）！建议研究太阳能效率或殖民海洋星球" },
            nuclear = { min = 50,  msg = "⚠️ 核能储量不足（<50）！建议研究深层采矿或殖民火山星球" },
        }
        for res, cfg in pairs(warnCfg) do
            if (rm_:get(res) or 0) < cfg.min and not (GP_.lowResWarnSent and GP_.lowResWarnSent[res]) then
                if not GP_.lowResWarnSent then GP_.lowResWarnSent = {} end
                GP_.lowResWarnSent[res] = true
                GameUI.Notify(cfg.msg, "warn")
            end
        end
    end

    GP_.resMilestoneTimer = (GP_.resMilestoneTimer or 0) + dt
    if GP_.resMilestoneTimer >= 10 then
        GP_.resMilestoneTimer = 0
        Achievement.Check("resource_milestone", {
            metal   = rm_.resources.metal or 0,
            esource = rm_.resources.esource or 0,
            nuclear = rm_.resources.nuclear or 0,
        })
    end

    local dda_ = accessTbl("dda_") or {}
    dda_.evalTimer = (dda_.evalTimer or 0) + dt
    if dda_.evalTimer >= (dda_.EVAL_INTERVAL or 90) then
        dda_.evalTimer = 0
        ClientBattle.DdaPeriodicCheck()
    end

    if (h.totalPlayTime_ or 0) >= 600 and not GalaxyEvents.HasEndgameCrisisTriggered() then
        GalaxyEvents.TriggerEndgameCrisis()
        local crisis = GalaxyEvents.GetEndgameCrisis()
        if crisis then
            GameUI.Notify(crisis.icon .. " 终局危机：" .. crisis.name .. " — 阶段 1 开始！", "danger")
            GameUI.ShowEndgameCrisisPanel(crisis, function(idx) M.handleCrisisChoice(idx) end)
        end
    end

    local expeditions = accessTbl("expeditions_") or {}
    if #expeditions > 0 and h.currentScene_ == "galaxy" then
        local finished = {}
        for i, exp in ipairs(expeditions) do
            exp.elapsed = (exp.elapsed or 0) + dt
            if exp.elapsed >= exp.duration then
                finished[#finished + 1] = i
            end
        end
        for j = #finished, 1, -1 do
            local idx = finished[j]
            ClientBattle.SettleExpedition(expeditions[idx])
            table.remove(expeditions, idx)
        end
        if GalaxyScene.SetExpeditions then
            GalaxyScene.SetExpeditions(expeditions)
        end
        local activeBases = {}
        if h.pirateAI_ then
            for _, b in ipairs(h.pirateAI_.bases) do
                if b.active then activeBases[#activeBases + 1] = b end
            end
        end
        GameUI.SetExpeditions(expeditions, activeBases, accessTbl("lastExpedition_"))
    end

    GP_.prodSampleTimer = (GP_.prodSampleTimer or 0) + dt
    if GP_.prodSampleTimer >= (GP_.PROD_SAMPLE_INTERVAL or 30) then
        GP_.prodSampleTimer = 0
        local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
        local base = GalaxyScene.GetBase and GalaxyScene.GetBase()
        local allPlanets = {}
        for _, p in ipairs(planets) do allPlanets[#allPlanets+1] = p end
        if base and base.colonized then allPlanets[#allPlanets+1] = base end
        if not GP_.planetProdHistory then GP_.planetProdHistory = {} end
        for _, p in ipairs(allPlanets) do
            local key = p.name or ""
            if key ~= "" then
                if not GP_.planetProdHistory[key] then
                    GP_.planetProdHistory[key] = { minerals = {}, energy = {}, crystal = {} }
                end
                local sum = { minerals = 0, energy = 0, crystal = 0 }
                for _, b in ipairs(p.buildings or {}) do
                    for res, val in pairs(b.currentProd or {}) do
                        if sum[res] ~= nil then sum[res] = sum[res] + val end
                    end
                end
                local hist = GP_.planetProdHistory[key]
                for _, res in ipairs({"minerals", "energy", "crystal"}) do
                    hist[res][#hist[res]+1] = sum[res]
                    if #hist[res] > (GP_.PROD_MAX_SAMPLES or 10) then
                        table.remove(hist[res], 1)
                    end
                end
            end
        end
    end

    h.saveTimer_ = (h.saveTimer_ or 0) + dt
    if h.saveTimer_ >= (h.AUTO_SAVE_INTERVAL or 60) then
        h.saveTimer_ = 0
        if h.saveGame then h.saveGame() end
    end

    local techDone = rs_:update(dt)
    if techDone then
        Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
        h.totalResearch_ = (h.totalResearch_ or 0) + 1
        Achievement.Check("research_complete", {
            totalResearch = h.totalResearch_,
            unlockedTechs = rs_.unlocked,
        })
        GameUI.Notify("科技完成: " .. TECHS[techDone].name, "success")
        GameUI.TriggerTechComplete(techDone)
        local gpUnlocked = GalactopediaSystem.TryUnlock("research_" .. techDone)
        if gpUnlocked then GameUI.Notify("📖 百科解锁: " .. gpUnlocked, "info") end
        GameUI.RefreshTechPanel()
        if h.checkStageGoals then h.checkStageGoals() end
        if h.saveGame then h.saveGame() end
    end

    local shipDone = spq_:update(dt)
    if shipDone then
        fm_:addToReserve(shipDone.shipType)
        GP_.totalShipsBuilt = (GP_.totalShipsBuilt or 0) + 1
        if not GP_.shipTypeBuilt then GP_.shipTypeBuilt = {} end
        GP_.shipTypeBuilt[shipDone.shipType] = (GP_.shipTypeBuilt[shipDone.shipType] or 0) + 1
        Audio.Play(Audio.SFX.BUILD_COMPLETE)
        if GalaxyScene.InvalidateFleetColor then
            GalaxyScene.InvalidateFleetColor(h.activeFleetId_ or 1)
        end
        GameUI.Notify("舰船建造完成: " .. SHIP_TYPES[shipDone.shipType].name .. "  → 已进入储备池", "success")
        Achievement.Check("ship_built", {
            totalShipsBuilt = GP_.totalShipsBuilt,
            lastBuiltType   = shipDone.shipType,
        })
        local gpShip = GalactopediaSystem.TryUnlock("build_ship_" .. shipDone.shipType)
        if gpShip then GameUI.Notify("📖 百科解锁: " .. gpShip, "info") end
        GameUI.RefreshFleetPanel(fm_, h.activeFleetId_ or 1)
        GameUI.RefreshReservePanel(fm_)
        GameUI.RefreshShipyardPanel()
        if h.checkStageGoals then h.checkStageGoals() end
    end

    if h.currentScene_ == "battle" then
        BattleScene.Update(dt)
    end

    if h.currentScene_ == "galaxy" then
        GalaxyScene.Update(dt)
        for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
            local bs_ = h.bs_
            local done = bs_:update(dt, p)
            if done then
                Audio.Play(Audio.SFX.BUILD_COMPLETE)
                ClientGalaxy.ApplyPlanetTypeBonus(p)
                GameUI.Notify("建造完成: " .. BUILDINGS[done].name, "success")
                if PlanetPanel.TriggerHighlight then
                    PlanetPanel.TriggerHighlight(p.id, done)
                end
                GameUI.RefreshPlanetPanel(GalaxyScene.GetSelected())
                if done == "SHIPYARD" then GameUI.SetShipyardBuilt(true) end
                if h.saveGame then h.saveGame() end
            end
        end
        local base = GalaxyScene.GetBase()
        if base and base.colonized then
            local bbs_ = h.bbs_
            local done = bbs_:update(dt, base)
            if done then
                if done == "__CORE_UPGRADE__" then
                    Audio.Play(Audio.SFX.BUILD_COMPLETE)
                    local newLv = base.coreLevel or 1
                    local unlocked = BASE_CORE_UNLOCK_PREVIEW[newLv] or {}
                    local names = {}
                    for _, k in ipairs(unlocked) do
                        names[#names+1] = BASE_MODULES[k] and BASE_MODULES[k].name or k
                    end
                    local unlockStr = #names > 0 and ("解锁: " .. table.concat(names, " / ")) or ""
                    if newLv == 2 then
                        unlockStr = unlockStr .. "  ＋基础精炼能力（0.3×）"
                    end
                    GameUI.Notify("★ 核心升级完成！已达 Lv." .. newLv
                        .. (#unlockStr > 0 and "  " .. unlockStr or ""), "success")
                    if h.markBaseEffectsDirty then h.markBaseEffectsDirty() end
                    if h.applyBaseModuleEffects then h.applyBaseModuleEffects() end
                    if h.checkStageGoals then h.checkStageGoals() end
                    if h.saveGame then h.saveGame() end
                else
                    Audio.Play(Audio.SFX.BUILD_COMPLETE)
                    local modName = BASE_MODULES[done] and BASE_MODULES[done].name or done
                    GameUI.Notify("模块安装完成: " .. modName, "success")
                    if done == "SHIPYARD" then GameUI.SetShipyardBuilt(true) end
                    if h.markBaseEffectsDirty then h.markBaseEffectsDirty() end
                    if h.applyBaseModuleEffects then h.applyBaseModuleEffects() end
                    if h.checkStageGoals then h.checkStageGoals() end
                    if h.saveGame then h.saveGame() end
                end
            end
            local sel = GalaxyScene.GetSelected()
            if sel and sel.isBase then
                GameUI.RefreshPlanetPanel(base)
            end
        end
    end

    if rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGatePrime then
        local cd = rm_.baseBonus.warpGatePrimeCooldown or 0
        if cd > 0 then
            rm_.baseBonus.warpGatePrimeCooldown = math.max(0, cd - dt)
        end
    end

    GameUI.UpdateNotifications(dt)
    Achievement.Update(dt)

    ClientBattle.UpdateExplorerTasks(dt)

    if h.pirateAI_ then
        local minT = math.huge
        for _, b in ipairs(h.pirateAI_.bases) do
            if b.active and b.attackTimer and b.attackTimer < minT then
                minT = b.attackTimer
            end
        end
        GameUI.SetPirateWarning(minT)
        if minT <= 30 and not h.pirateWarnPlayed_ then
            h.pirateWarnPlayed_ = true
            Audio.Play(Audio.SFX.PIRATE_WARNING)
        elseif minT > 30 then
            h.pirateWarnPlayed_ = false
        end
    end

    h.refreshTimer_ = (h.refreshTimer_ or 0) + dt
    if h.refreshTimer_ >= 0.5 then
        h.refreshTimer_ = 0
        GameUI.RefreshResourceBar()
        local sel = GalaxyScene.GetSelected()
        if sel and h.currentScene_ == "galaxy" then
            GameUI.RefreshPlanetPanel(sel)
        end
    end
end

---@param eventType string
---@param eventData table
function M.handleMouseButtonDown(eventType, eventData)
    ClientInput.OnMouseButtonDown(eventType, eventData)
end
function M.handleMouseButtonUp(eventType, eventData)
    ClientInput.OnMouseButtonUp(eventType, eventData)
end
function M.handleMouseMove(eventType, eventData)
    ClientInput.OnMouseMove(eventType, eventData)
end
function M.handleMouseWheel(eventType, eventData)
    ClientInput.OnMouseWheel(eventType, eventData)
end
function M.handleKeyDown(eventType, eventData)
    ClientInput.OnKeyDown(eventType, eventData)
end
function M.handleKeyUp(eventType, eventData)
    ClientInput.OnKeyUp(eventType, eventData)
end

---@param host table
function M.handleInput(host)
    local h = H()

    SubscribeToEvent("InputFocus", function(_, ed)
        local focused = ed["Focus"]:GetBool()
        local minimized = ed["Minimized"]:GetBool()
        local Settings = require("game.ui.SettingsPanel")
        if not Settings.GetAutoPause() then return end
        if (not focused) or minimized then
            if h.difficultyChosen_ and not h.endGameTriggered_ then
                local TL = accessTbl("TL")
                if TL then TL.bgPaused = true end
                print("[AutoPause] 游戏已暂停 (切后台)")
            end
        else
            local TL = accessTbl("TL")
            if TL and TL.bgPaused then
                TL.bgPaused = false
                TL.bgPauseNotifyT = 2.5
                print("[AutoPause] 游戏已恢复")
            end
        end
    end)

    SubscribeToEvent("TextInput", function(_, ed)
        local ch = ed["Text"]:GetString()
        if GameUI.IsFleetNaming() then
            GameUI.OnFleetNamingText(ch)
            return
        end
        if not h.nicknameInputActive_ then return end
        if #(h.playerName_ or "") < 24 then
            h.playerName_ = (h.playerName_ or "") .. ch
        end
    end)

    SubscribeToEvent("TouchBegin", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        if h.mainMenuActive_ or not h.difficultyChosen_ then return end
        local tx  = ed["X"]:GetInt() / (h.uiScale_ or 1)
        local ty  = ed["Y"]:GetInt() / (h.uiScale_ or 1)
        if GameUI.OnTouchBegin(tid, tx, ty) then return end
        if h.currentScene_ == "battle" then return end
        if h.currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchBegin(tid, tx, ty)
    end)
    SubscribeToEvent("TouchMove", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        if h.mainMenuActive_ or not h.difficultyChosen_ then return end
        local tx  = ed["X"]:GetInt() / (h.uiScale_ or 1)
        local ty  = ed["Y"]:GetInt() / (h.uiScale_ or 1)
        if GameUI.OnTouchMove(tid, tx, ty) then return end
        if h.currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchMove(tid, tx, ty)
    end)
    SubscribeToEvent("TouchEnd", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        local dpr = M.getDpr()
        local mx  = ed["X"]:GetInt() / dpr / (h.uiScale_ or 1)
        local my  = ed["Y"]:GetInt() / dpr / (h.uiScale_ or 1)
        if h.mainMenuActive_ then
            local hit = M.getMainMenuHit(mx, my, h.screenW_ or 800, h.screenH_ or 600)
            print(string.format("[Touch] mainMenu tap: mx=%.1f my=%.1f sw=%d sh=%d hit=%s dpr=%.1f uiScale=%.2f",
                mx, my, h.screenW_ or 800, h.screenH_ or 600, tostring(hit), dpr, h.uiScale_ or 1))
            if hit then M.onMainMenuSelect(hit) end
            return
        end
        if not h.difficultyChosen_ then
            local hit = M.getDifficultyHit(mx, my, h.screenW_ or 800, h.screenH_ or 600)
            if hit == "endless" then
                M.onEndlessModeSelect()
            elseif hit then
                M.onDifficultySelect(hit)
            end
            return
        end
        local tx  = ed["X"]:GetInt() / (h.uiScale_ or 1)
        local ty  = ed["Y"]:GetInt() / (h.uiScale_ or 1)
        if GameUI.OnTouchEnd(tid, tx, ty) then return end
        if h.currentScene_ == "battle" then
            BattleScene.OnClick(mx, my)
            return
        end
        if h.currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchEnd(tid, tx, ty)
    end)
end

---@param host table
function M.Subscribe(host)
    M.init(host)
    SubscribeToEvent("NanoVGRender",    function(t, d) M.handleNanoVGRender(t, d) end)
    SubscribeToEvent("Update",          function(t, d) M.handleUpdate(t, d) end)
    SubscribeToEvent("MouseButtonDown", function(t, d) M.handleMouseButtonDown(t, d) end)
    SubscribeToEvent("MouseButtonUp",   function(t, d) M.handleMouseButtonUp(t, d) end)
    SubscribeToEvent("MouseMove",       function(t, d) M.handleMouseMove(t, d) end)
    SubscribeToEvent("MouseWheel",      function(t, d) M.handleMouseWheel(t, d) end)
    SubscribeToEvent("KeyDown",         function(t, d) M.handleKeyDown(t, d) end)
    SubscribeToEvent("KeyUp",           function(t, d) M.handleKeyUp(t, d) end)
    M.handleInput(host)
end

return M
