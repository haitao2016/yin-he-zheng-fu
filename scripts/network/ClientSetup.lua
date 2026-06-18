---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-----------------------------------------------------------------------
-- ClientSetup.lua  —  setupSceneAndUI 逻辑（从 Client.lua 提取）
-- 负责: 初始化DDA、创建battleState_/galaxyState_代理、
--       pirateAI_创建、GalaxyScene.Init、GameUI.Init (所有回调)、
--       Achievement.Init、广告回调注入、教程触发、BGM启动
-----------------------------------------------------------------------
local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local PirateAI    = require("game.PirateAI")
local GameUI      = require("game.GameUI")
local PlanetPanel = require("game.ui.PlanetPanel")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local ClientBattle = require("network.ClientBattle")
local ClientGalaxy = require("network.ClientGalaxy")
local GalaxyEvents = require("game.GalaxyEvents")
local MegastructureSystem = require("game.MegastructureSystem")
local QuestBoard    = require("game.QuestBoard")
local GalactopediaSystem = require("game.GalactopediaSystem")
local LegacySystem = require("game.LegacySystem")
local cjson = require("cjson")

local M = {}

-----------------------------------------------------------------------
--- M.Init(H)
--- H: host context table built by Client.lua's buildSetupHost()
---   Tables (direct refs): rm_, bs_, bbs_, rs_, ms_, bm_, spq_, fm_,
---       dda_, hiddenStats_, evBonus_, battleStatsCache_, careerStats_,
---       endlessCardBonuses_, explorerTasks_, lastExpedition_, player_,
---       PLANET_UPGRADE_COSTS, DIFFICULTY_CONFIGS, GP_, TL, customDiff_
---   Scalars via metatable __index/__newindex:
---       pirateAI_, ds_, selectedPlanet_, activeFleetId_,
---       explorerColonizeMode_, campaignMode_, campaignFirstColonize_,
---       campaignVictoryPending_, campaignResetTimer_,
---       endlessRound_, piratesKilled_, endGameTriggered_,
---       explorerTaskSeq_, endlessStreakBuff_, totalPlayTime_,
---       totalResearch_, isEndlessMode_, leagueMode_, difficulty_,
---       currentScene_, pendingDiploEvent_, adBonusNext_,
---       baseEffectsDirty_, savedAchievements_, savedRedeemed_,
---       skipSaveLoad_, dailyChallengeMode_
---   Functions:
---       saveGame, saveCareer, softReset, markBaseEffectsDirty,
---       handleLevelUp, applyBaseModuleEffects, checkStageGoals,
---       showRewardAd
---   Globals (convenience): clientCloud
-----------------------------------------------------------------------
function M.Init(H)
    -- Unpack frequently used refs
    local rm_  = H.rm_
    local bs_  = H.bs_
    local bbs_ = H.bbs_
    local rs_  = H.rs_
    local ms_  = H.ms_
    local bm_  = H.bm_
    local spq_ = H.spq_
    local fm_  = H.fm_
    local dda_ = H.dda_
    local player_ = H.player_
    local hiddenStats_ = H.hiddenStats_
    local evBonus_ = H.evBonus_
    local battleStatsCache_ = H.battleStatsCache_
    local careerStats_ = H.careerStats_
    local endlessCardBonuses_ = H.endlessCardBonuses_
    local explorerTasks_ = H.explorerTasks_
    local lastExpedition_ = H.lastExpedition_
    local PLANET_UPGRADE_COSTS = H.PLANET_UPGRADE_COSTS
    local DIFFICULTY_CONFIGS = H.DIFFICULTY_CONFIGS
    local GP_ = H.GP_
    local TL = H.TL

    -- Functions
    local saveGame = H.saveGame
    local saveCareer = H.saveCareer
    local softReset = H.softReset
    local markBaseEffectsDirty = H.markBaseEffectsDirty
    local handleLevelUp = H.handleLevelUp
    local applyBaseModuleEffects = H.applyBaseModuleEffects
    local checkStageGoals = H.checkStageGoals
    local showRewardAd = H.showRewardAd

    -- Global
    local clientCloud = H.clientCloud or _G.clientCloud

    -------------------------------------------------------------------
    -- DDA Init
    -------------------------------------------------------------------
    LegacySystem.Init()
    local difficulty_ = H.difficulty_
    local diffCfg = DIFFICULTY_CONFIGS[difficulty_] or DIFFICULTY_CONFIGS["normal"]
    dda_.enabled = (difficulty_ ~= "custom")
    dda_.baseFactor = diffCfg.attackFactor
    dda_.currentFactor = diffCfg.attackFactor
    dda_.recentResults = {}
    dda_.evalTimer = 0
    dda_.adjustCount = 0

    -------------------------------------------------------------------
    -- battleState_ proxy → ClientBattle.Init
    -------------------------------------------------------------------
    local battleState_ = setmetatable({
        rm = rm_, rs = rs_, spq = spq_, fm = fm_, player = player_, dda = dda_,
        hiddenStats = hiddenStats_, endlessCardBonuses = endlessCardBonuses_,
        pirateAttackInfo = H.pirateAttackInfo_,
        lastExpedition = lastExpedition_,
        explorerTasks = explorerTasks_, evBonus = evBonus_,
        battleStatsCache = battleStatsCache_, career = careerStats_,
        dailyChallenge = setmetatable({}, {
            __index = function(_, k)
                if k == "mode" then return H.dailyChallengeMode_ end
                return nil
            end,
            __newindex = function(_, k, v)
                if k == "mode" then H.dailyChallengeMode_ = v end
            end,
        }),
        RES_LABELS  = RES_LABELS,
        TECHS       = TECHS,
        clientCloud  = clientCloud,
        markBaseEffectsDirty = function() markBaseEffectsDirty() end,
        saveGame     = function() saveGame() end,
        softReset    = function() softReset() end,
        saveCareer   = function() saveCareer() end,
        checkStageGoalsFn = function() checkStageGoals() end,
    }, {
        __index = function(_, k)
            if k == "pirateAI" then return H.pirateAI_ end
            if k == "vg" then return H.vg_ end
            if k == "endlessRound" then return H.endlessRound_ end
            if k == "piratesKilled" then return H.piratesKilled_ end
            if k == "endGameTriggered" then return H.endGameTriggered_ end
            if k == "explorerTaskSeq" then return H.explorerTaskSeq_ end
            if k == "endlessStreakBuff" then return H.endlessStreakBuff_ end
            if k == "totalPlayTime" then return H.totalPlayTime_ end
            if k == "totalResearch" then return H.totalResearch_ end
            if k == "isEndlessMode" then return H.isEndlessMode_ end
            if k == "campaignMode" then return H.campaignMode_ end
            if k == "leagueMode" then return H.leagueMode_ end
            if k == "difficulty" then return H.difficulty_ end
            if k == "currentScene" then return H.currentScene_ end
            return nil
        end,
        __newindex = function(_, k, v)
            if k == "endlessRound" then H.endlessRound_ = v
            elseif k == "piratesKilled" then H.piratesKilled_ = v
            elseif k == "endGameTriggered" then H.endGameTriggered_ = v
            elseif k == "explorerTaskSeq" then H.explorerTaskSeq_ = v
            elseif k == "endlessStreakBuff" then H.endlessStreakBuff_ = v
            elseif k == "totalPlayTime" then H.totalPlayTime_ = v
            elseif k == "totalResearch" then H.totalResearch_ = v
            elseif k == "currentScene" then H.currentScene_ = v
            elseif k == "careerStats" then -- full replacement
                for ck, cv in pairs(v) do careerStats_[ck] = cv end
            elseif k == "pirateAttackInfo" then H.pirateAttackInfo_ = v
            else rawset(_, k, v)
            end
        end,
    })
    ClientBattle.Init(battleState_)

    -------------------------------------------------------------------
    -- galaxyState_ proxy → ClientGalaxy.Init
    -------------------------------------------------------------------
    local galaxyState_ = setmetatable({
        rm = rm_, bs = bs_, bbs = bbs_, rs = rs_, ms = ms_, bm = bm_,
        spq = spq_, fm = fm_,
        evBonus = evBonus_, PLANET_UPGRADE_COSTS = PLANET_UPGRADE_COSTS,
        handleLevelUp = handleLevelUp, markBaseEffectsDirty = markBaseEffectsDirty,
        saveGame = function() saveGame() end,
        checkStageGoalsFn = function() checkStageGoals() end,
    }, {
        __index = function(_, k)
            if k == "explorerColonizeMode" then return H.explorerColonizeMode_ end
            if k == "selectedPlanet" then return H.selectedPlanet_ end
            if k == "campaignMode" then return H.campaignMode_ end
            if k == "campaignFirstColonize" then return H.campaignFirstColonize_ end
            return nil
        end,
        __newindex = function(_, k, v)
            if k == "explorerColonizeMode" then H.explorerColonizeMode_ = v
            elseif k == "selectedPlanet" then H.selectedPlanet_ = v
            elseif k == "campaignMode" then H.campaignMode_ = v
            elseif k == "campaignFirstColonize" then H.campaignFirstColonize_ = v
            else rawset(_, k, v)
            end
        end,
    })
    ClientGalaxy.Init(galaxyState_)
    ClientGalaxy.RegisterBlackMarketCallback()

    -------------------------------------------------------------------
    -- pirateAI_ creation
    -------------------------------------------------------------------
    local pirateAI = PirateAI.new({
        notifyFn = GameUI.Notify,
        onAttack = function(...) ClientBattle.OnPirateAttack(...) end,
        getTargets = function() return ClientBattle.GetPlayerTargets() end,
        attackIntervalFactor = dda_.currentFactor,
        maxThreatLevel = diffCfg.maxThreat,
        getProgress = function()
            local colonized = 0
            local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
            for _, p in ipairs(planets) do if p.colonized then colonized = colonized + 1 end end
            return { colonized = colonized, gameTime = TL.playTime, piratesKilled = H.piratesKilled_ }
        end,
    })
    H.pirateAI_ = pirateAI

    -------------------------------------------------------------------
    -- preReadSeed: 尝试从已有存档中读取种子
    -------------------------------------------------------------------
    local preReadSeed = nil
    if not H.skipSaveLoad_ and fileSystem:FileExists("galaxy_save.json") then
        local f = File("galaxy_save.json", FILE_READ)
        if f:IsOpen() then
            local ok, data = pcall(cjson.decode, f:ReadString())
            f:Close()
            if ok and data and data.galaxySeed then preReadSeed = data.galaxySeed end
        end
    end

    -------------------------------------------------------------------
    -- GalaxyScene.Init
    -------------------------------------------------------------------
    GalaxyScene.Init({
        vg = H.vg_,
        rm = rm_, bs = bs_, fm = fm_, rs = rs_, spq = spq_, bbs = bbs_,
        player = player_,
        pirateAI = pirateAI,
        onPlanetSelect = function(p)
            ClientGalaxy.OnPlanetSelect(p)
        end,
        onFleetSelect = function(fid)
            H.activeFleetId_ = fid
            GameUI.RefreshFleetPanel(fm_, fid)
            GameUI.SetMapSelectedFleet(fid)
        end,
        onFleetContactPlanet = function(fleet, planet)
            if H.explorerColonizeMode_ then
                ClientGalaxy.DoColonize(planet)
                H.explorerColonizeMode_ = false
            end
        end,
        onSeedDeploy = function(wx, wy, base)
            Audio.Play(Audio.SFX.FLEET_DEPLOY)
            -- 种子飞船展开完成：解锁全部 UI 面板
            GameUI.SetDeployed(true)
            -- 选中基地，显示模块建造面板（base.colonized 已由 GalaxyScene 设为 true）
            H.selectedPlanet_ = base
            GameUI.ShowScene("galaxy", true)
        end,
        onFleetContactPirateBase = function(fleet, base)
            ClientBattle.OnFleetSiegeBase(fleet.id, base.id)
        end,
        onFleetMove = function(fid, dest)
            Audio.Play(Audio.SFX.FLEET_MOVE)
        end,
        onGalaxyEvent = function(ev)
            if ev.forced then
                -- 强制被动事件（无需选择）
                if ev.effect then
                    for res, delta in pairs(ev.effect) do
                        if delta > 0 then rm_:add(res, delta)
                        elseif delta < 0 then rm_:spend({ [res] = -delta }) end
                    end
                end
                if ev.buff then
                    evBonus_[ev.buff.key] = (evBonus_[ev.buff.key] or 0) + ev.buff.value
                    if ev.buff.duration then
                        -- 定时移除
                        local bk, bv = ev.buff.key, ev.buff.value
                        local timer = 0
                        SubscribeToEvent("Update", function(_, ed)
                            timer = timer + ed:GetFloat("TimeStep")
                            if timer >= ev.buff.duration then
                                evBonus_[bk] = (evBonus_[bk] or 0) - bv
                                UnsubscribeFromEvent("Update")
                            end
                        end)
                    end
                end
                GameUI.Notify(ev.text or "银河事件", ev.notifyType or "info")
                return
            end
            -- 选择事件
            if ev.choices then
                GameUI.ShowEventPopup(ev, function(choiceIdx)
                    local choice = ev.choices[choiceIdx]
                    if not choice then return end
                    -- 花费
                    if choice.cost then
                        if not rm_:canAfford(choice.cost) then
                            GameUI.Notify("资源不足", "warn")
                            return
                        end
                        rm_:spend(choice.cost)
                    end
                    -- 收益
                    if choice.gain then
                        for res, delta in pairs(choice.gain) do rm_:add(res, delta) end
                    end
                    -- Buff
                    if choice.buff then
                        evBonus_[choice.buff.key] = (evBonus_[choice.buff.key] or 0) + choice.buff.value
                        if choice.buff.duration then
                            local bk2, bv2 = choice.buff.key, choice.buff.value
                            local t2 = 0
                            SubscribeToEvent("Update", function(_, ed2)
                                t2 = t2 + ed2:GetFloat("TimeStep")
                                if t2 >= choice.buff.duration then
                                    evBonus_[bk2] = (evBonus_[bk2] or 0) - bv2
                                    UnsubscribeFromEvent("Update")
                                end
                            end)
                        end
                    end
                    -- 链式事件（延迟调度，坐标取事件位置或随机）
                    if choice.chainEvent then
                        local wx = ev.wx or math.random() * 800
                        local wy = ev.wy or math.random() * 600
                        GalaxyEvents.ScheduleChain(choice.chainEvent, wx, wy)
                    end
                    -- 特殊行动
                    if choice.action then
                        if choice.action == "BOUNTY_KILL" then
                            H.piratesKilled_ = H.piratesKilled_ + (choice.actionValue or 1)
                        elseif choice.action == "ARTIFACT_RESEARCH" then
                            if rs_ and rs_.active then
                                rs_.active.remaining = math.max(0, (rs_.active.remaining or 0) - (choice.actionValue or 120))
                            end
                        elseif choice.action == "TECH_BOOST" then
                            if rs_ then rs_:applyBoost(choice.actionValue) end
                        end
                    end
                    -- 惩罚
                    if choice.penalty then
                        for res, amt in pairs(choice.penalty) do
                            rm_:spend({ [res] = amt })
                        end
                    end
                    GameUI.Notify(choice.resultText or "已选择", choice.notifyType or "info")
                    saveGame()
                end)
                return
            end
        end,
        seed = preReadSeed,
        difficulty = difficulty_,
        diffCfg = diffCfg,
        isEndlessMode = H.isEndlessMode_,
        campaignMode = H.campaignMode_,
        leagueMode = H.leagueMode_,
    })

    -------------------------------------------------------------------
    -- DiplomacySystem
    -------------------------------------------------------------------
    rs_:setPlanetGetter(GalaxyScene.GetAllPlanets)
    local ds = Sys.DiplomacySystem.new()
    ds:initFactions(GalaxyScene.GetAllPlanets(), 0.35)
    ds:initTriangleRelations()
    H.ds_ = ds

    -- Crisis callbacks
    GalaxyEvents.onCrisisExpired = function(ev)
        GameUI.Notify("⚠️ 银河危机未响应: " .. (ev.title or "?"), "warn")
    end
    GalaxyEvents.onCrisisPhaseTimeout = function(crisis, phaseIdx)
        GameUI.Notify(string.format("🔥 危机阶段 %d 超时: %s", phaseIdx, crisis.title or "?"), "error")
        if crisis.onPhaseFail then crisis.onPhaseFail(phaseIdx, rm_) end
    end
    GalaxyEvents.onCrisisResolved = function(crisis, result)
        if result == "success" then
            GameUI.Notify("✅ 危机解除: " .. (crisis.title or "?"), "success")
            if crisis.reward then
                for res, amt in pairs(crisis.reward) do rm_:add(res, amt) end
            end
        else
            GameUI.Notify("❌ 危机失败: " .. (crisis.title or "?"), "error")
        end
        saveGame()
    end

    -------------------------------------------------------------------
    -- GameUI.Init (所有回调)
    -------------------------------------------------------------------
    GameUI.Init({
        vg = H.vg_,
        rm = rm_, bs = bs_, bbs = bbs_, rs = rs_, ms = ms_, bm = bm_,
        spq = spq_, fm = fm_, player = player_,
        evBonus = evBonus_,
        GP = GP_,
        difficulty = difficulty_,
        diffCfg = diffCfg,
        isEndlessMode = H.isEndlessMode_,
        campaignMode = H.campaignMode_,
        leagueMode = H.leagueMode_,
        pirateAI = pirateAI,
        ds = ds,

        -- Campaign dialogue done
        onCampaignDialogueDone = function()
            if H.campaignVictoryPending_ then
                H.campaignVictoryPending_ = false
                saveCareer()
                H.campaignResetTimer_ = 3.0
            end
        end,

        -- Building/research/market delegates → ClientGalaxy
        onBuildCb          = function(...) ClientGalaxy.OnBuild(...) end,
        onBatchUpgradeCb   = function(...) ClientGalaxy.OnBatchUpgrade(...) end,
        onBaseBuildCb      = function(...) ClientGalaxy.OnBaseBuild(...) end,
        onCoreUpgradeCb    = function(...) ClientGalaxy.OnCoreUpgrade(...) end,
        onResearchCb       = function(...) ClientGalaxy.OnResearch(...) end,
        onMarketCb         = function(...) ClientGalaxy.OnMarket(...) end,
        onBlackMarketCb    = function(...) ClientGalaxy.OnBlackMarket(...) end,

        -- Exchange
        onExchangeCb = function(fromRes, toRes)
            local EXCHANGE_AMOUNT = 100
            local ok, msg = rm_:exchange(fromRes, toRes, EXCHANGE_AMOUNT)
            if ok then
                GameUI.Notify(msg, "success")
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Ship queue delegates
        onShipQueueCb       = function(...) ClientGalaxy.OnShipQueue(...) end,
        onShipCancelCb      = function(...) ClientGalaxy.OnShipCancel(...) end,
        onShipPromoteCb     = function(...) ClientGalaxy.OnShipPromote(...) end,
        onExplorerColonizeCb= function(...) ClientGalaxy.OnExplorerColonize(...) end,
        onExplorerTaskCb    = function(...) ClientBattle.StartExplorerTask(...) end,

        -- Fleet select
        onFleetSelectCb = function(selectedFid)
            H.activeFleetId_ = selectedFid
            GameUI.RefreshFleetPanel(fm_, selectedFid)
            GameUI.SetMapSelectedFleet(selectedFid)
        end,

        -- Fleet move ship
        onFleetMoveShipCb = function(shipIdx, fromFid, toFid)
            fm_:moveShip(shipIdx, fromFid, toFid)
            GameUI.RefreshFleetPanel(H.activeFleetId_)
        end,

        -- Assign reserve
        onAssignReserveCb = function(shipType, toFid)
            fm_:assignFromReserve(shipType, toFid)
            GameUI.RefreshFleetPanel(toFid)
        end,

        -- Speed up build (star coins)
        onSpeedUpBuildCb = function(target)
            if not target or not target.constructing then return end
            local remaining = target.constructing.remaining or 0
            local cost = math.max(1, math.ceil(remaining / 30))
            if (rm_.starCoins or 0) < cost then
                GameUI.Notify(string.format("星币不足（需要 %d）", cost), "warn")
                return
            end
            rm_.starCoins = rm_.starCoins - cost
            target.constructing.remaining = 0
            target.constructing.progress  = 1.0
            GameUI.Notify(string.format("⚡ 建造加速完成（消耗 %d 星币）", cost), "success")
            GameUI.ForceRefreshPanel(target)
            saveGame()
        end,

        -- Buy nuclear
        onBuyNuclearCb = function()
            local ok, msg = ms_:buyNuclear(rm_)
            if ok then
                GameUI.Notify(msg, "success")
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Harvest all
        onHarvestAllCb = function()
            local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
            local total = { metal = 0, esource = 0, crystal = 0 }
            for _, p in ipairs(planets) do
                if p.colonized and p.production then
                    for res, rate in pairs(p.production) do
                        local gain = rate * 60
                        rm_:add(res, gain)
                        total[res] = (total[res] or 0) + gain
                    end
                end
            end
            local parts = {}
            for res, amt in pairs(total) do
                if amt > 0 then parts[#parts + 1] = string.format("%s+%d", RES_LABELS[res] or res, amt) end
            end
            if #parts > 0 then
                GameUI.Notify("📦 全部收割: " .. table.concat(parts, " "), "success")
            else
                GameUI.Notify("暂无可收割星球", "info")
            end
        end,

        -- Conquest progress
        getConquestProgress = function()
            local allPlanets = GalaxyScene.GetAllPlanets and GalaxyScene.GetAllPlanets() or {}
            local total      = #allPlanets
            local colonized  = 0
            for _, p in ipairs(allPlanets) do if p.colonized then colonized = colonized + 1 end end
            -- 海盗据点统计 + 最高威胁等级
            local piratesTotal, piratesKilled, maxThreat = 0, 0, 0
            if pirateAI and pirateAI.bases then
                for _, b in ipairs(pirateAI.bases) do
                    piratesTotal = piratesTotal + 1
                    if not b.active then
                        piratesKilled = piratesKilled + 1
                    elseif b.level and b.level > maxThreat then
                        maxThreat = b.level
                    end
                end
            end
            return {
                colonized     = colonized,
                total         = total,
                piratesKilled = piratesKilled,
                piratesTotal  = piratesTotal,
                pirateThreat  = maxThreat,
            }
        end,
        getColonizedPlanets = function()
            return GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
        end,

        -- Batch build（实际为批量升级）
        onBatchBuild = function(...) ClientGalaxy.OnBatchUpgrade(...) end,

        -- Planet jump（选中星球，即时模式渲染自动聚焦）
        onPlanetJump = function(planet)
            GalaxyScene.SelectPlanet(planet)
        end,

        -- Leaderboard
        onShowLeaderboard = function(callback)
            local rankList, myRank, myScore
            local nicksReady, rankReady = false, false

            local function buildSelfExtra()
                return {
                    colonized = #(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}),
                    kills     = H.piratesKilled_,
                    difficulty = difficulty_,
                    wave      = careerStats_.bestWave or 0,
                }
            end

            local function tryAssemble()
                if not nicksReady or not rankReady then return end
                -- 给列表中 isMe 项附加 extra
                local selfId = clientCloud and clientCloud.userId
                for _, entry in ipairs(rankList or {}) do
                    if selfId and entry.userId == selfId then
                        entry.isMe       = true
                        entry.extra      = buildSelfExtra()
                        entry.extraReady = true
                    else
                        entry.isMe         = false
                        entry.extra        = nil
                        entry.extraReady   = false
                        entry.extraLoading = false
                    end
                end
                callback(rankList, myRank, myScore)
            end

            -- 1. 拉取排行榜
            clientCloud:GetRankList("galaxy_score", 0, 10, {
                ok = function(_, rows)
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

            -- 3. 拉取本人排名
            local selfId = clientCloud and clientCloud.userId
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

        -- Priority toggle
        onTogglePriorityCb = function(planet)
            GalaxyScene.TogglePriority(planet)
            GameUI.RefreshPlanetPanel(planet)
        end,
        getIsPriorityCb = function(planet)
            return GalaxyScene.IsPriority(planet)
        end,

        -- Warp fleet
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

        -- Signal
        onSendSignalCb = function(sig)
            Audio.Play(Audio.SFX.FLEET_MOVE)
            print(string.format("[Signal] 发送信号: %s %s", sig.icon, sig.label))
        end,

        -- Cancel queued build
        onCancelQueuedCb = function(qIdx, planet)
            local ok = bs_:cancelQueued(qIdx, planet)
            if ok then
                GameUI.Notify("🗑 已取消排队建造任务，资源已退还", "info")
                GameUI.RefreshPlanetPanel(planet)
            else
                GameUI.Notify("取消失败：任务不存在", "warn")
            end
        end,

        -- Garrison
        onGarrisonFleetCb = function(fleetId, planet)
            local ok, reason = GalaxyScene.GarrisonFleet(fleetId, planet)
            if ok then
                GameUI.Notify("🏴 编队 " .. fleetId .. " 已驻守 " .. (planet.name or "?"), "success")
            else
                GameUI.Notify("驻守失败: " .. (reason or "未知原因"), "error")
            end
        end,
        onRecallGarrisonCb = function(fleetId)
            GalaxyScene.RecallGarrison(fleetId)
            GameUI.Notify("编队 " .. fleetId .. " 驻守已召回", "info")
        end,
        getGarrisonInfoCb = function(fleetId)
            local garrisonedPlanet = GalaxyScene.GetGarrisonedPlanet(fleetId)
            local colonizedPlanets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
            return { garrisonedPlanet = garrisonedPlanet, colonizedPlanets = colonizedPlanets }
        end,

        -- Planet production history
        getPlanetProdHistoryCb = function(planetName)
            return GP_.planetProdHistory[planetName] or nil
        end,

        -- Diplomacy: send gift
        onSendGift = function(planetId)
            if not ds then return end
            local ok, msg = ds:sendGift(planetId, rm_)
            if ok then
                GameUI.Notify("🎁 " .. msg, "success")
                GameUI.RefreshPlanetPanel(H.selectedPlanet_)
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Set building spec
        onSetSpec = function(planetId, bldIdx, specKey)
            if not H.selectedPlanet_ or H.selectedPlanet_.id ~= planetId then return end
            local ok, msg = bs_:setSpec(bldIdx, H.selectedPlanet_, specKey)
            if ok then
                GameUI.Notify("✦ " .. msg, "success")
                PlanetPanel.TriggerGlow(planetId, bldIdx)
                GameUI.RefreshPlanetPanel(H.selectedPlanet_)
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Upgrade planet
        onUpgradePlanetCb = function(planet)
            local ok, msg = ClientGalaxy.UpgradePlanet(planet)
            if ok then
                Audio.Play(Audio.SFX.BUILD_START)
                GameUI.Notify(msg, "success")
                GameUI.RefreshPlanetPanel(planet)
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Diplomacy state query
        getDiplomacyState = function(planetId)
            if not ds then return nil end
            local st = ds:getState(planetId)
            if not st then return nil end
            local fdef = ds:getFactionDef(st.factionKey) or {}
            return {
                factionKey = st.factionKey,
                factionDef = fdef,
                favor      = st.favor,
                atWar      = st.atWar,
                military   = st.military,
                tradeTimer = st.tradeTimer,
                longTrade  = st.longTrade or false,
                hasIntel     = ds:hasIntel(st.factionKey),
                hasAlliance  = ds:hasAlliance(st.factionKey),
                isBlockaded  = ds:isBlockaded(st.factionKey),
            }
        end,

        -- Long trade
        onActivateLongTrade = function(planetId)
            if not ds then return end
            local ok, msg = ds:activateLongTrade(planetId, rm_)
            if ok then
                Audio.Play(Audio.SFX.BUILD_START)
                GameUI.Notify(msg, "success")
                QuestBoard.OnTradeAgreement()
                GameUI.RefreshPlanetPanel(H.selectedPlanet_)
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,
        getLongTradeList = function()
            if not ds then return {} end
            return ds:getLongTradeList()
        end,

        -- Triangle relations
        getDiploRelations = function()
            if not ds then return {}, {} end
            return ds:getAllRelations(), ds:getAgreements()
        end,

        -- Intel
        onActivateIntel = function(factionKey)
            if not ds then return end
            local ok, msg = ds:activateIntel(factionKey)
            if ok then
                GameUI.Notify("🔍 " .. msg, "success")
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Alliance
        onActivateAlliance = function(factionKey)
            if not ds then return end
            local ok, msg = ds:activateAlliance(factionKey)
            if ok then
                GameUI.Notify("⚔️ " .. msg, "success")
                Achievement.Check("alliance_formed", {})
                local gpA = GalactopediaSystem.TryUnlock("alliance_any")
                if gpA then GameUI.Notify("📖 百科解锁: " .. gpA, "info") end
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Blockade
        onActivateBlockade = function(factionKey, targetKey)
            if not ds then return end
            local ok, msg = ds:activateBlockade(factionKey, targetKey, rm_)
            if ok then
                GameUI.Notify("🚫 " .. msg, "success")
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Mediation
        onActivateMediation = function(fk1, fk2)
            if not ds then return end
            local ok, msg = ds:activateMediation(fk1, fk2, rm_)
            if ok then
                GameUI.Notify("🕊️ " .. msg, "success")
                saveGame()
            else
                GameUI.Notify(msg, "warn")
            end
        end,

        -- Diplo event choice
        onDiploEventChoice = function(choiceIdx)
            local ev = H.pendingDiploEvent_
            if not ev then return end
            H.pendingDiploEvent_ = nil
            if ev.type == "diplo_request" then
                local choice = (choiceIdx == 1) and ev.choiceA or ev.choiceB
                if ds then
                    for _, st in pairs(ds.planets) do
                        if st.factionKey == ev.factionKey then
                            st.favor = math.max(-20, math.min(100, st.favor + choice.favorDelta))
                        end
                    end
                end
                GameUI.Notify(string.format("%s %s → 好感 %+d",
                    ev.icon, ev.factionName, choice.favorDelta),
                    choice.favorDelta > 0 and "success" or "warn")
            elseif ev.type == "diplo_dispute" then
                local choice = (choiceIdx == 1) and ev.choiceA or ev.choiceB
                if ds then
                    for _, st in pairs(ds.planets) do
                        if st.factionKey == ev.factionKey then
                            st.favor = math.max(-20, math.min(100, st.favor + choice.favorDeltaSelf))
                        elseif st.factionKey == ev.competitorKey then
                            st.favor = math.max(-20, math.min(100, st.favor + choice.favorDeltaOther))
                        end
                    end
                end
                if choice.favorDeltaSelf ~= 0 then
                    GameUI.Notify(string.format("支持 %s: 好感 %+d / %s 好感 %+d",
                        ev.factionName, choice.favorDeltaSelf,
                        ev.competitorName, choice.favorDeltaOther), "info")
                else
                    GameUI.Notify("保持中立，关系未变", "info")
                end
            elseif ev.type == "diplo_opportunity" then
                if choiceIdx == 1 then
                    if rm_:canAfford(ev.cost) then
                        rm_:spend(ev.cost)
                        if ds then
                            for _, st in pairs(ds.planets) do
                                if st.factionKey == ev.factionKey then
                                    st.favor = math.min(100, st.favor + ev.favorDelta)
                                end
                            end
                        end
                        GameUI.Notify(string.format("%s 合作成功！好感 +%d",
                            ev.factionName, ev.favorDelta), "success")
                    else
                        GameUI.Notify("资源不足，无法接受提议", "warn")
                    end
                else
                    GameUI.Notify("已拒绝合作提议", "info")
                end
            end
            saveGame()
        end,

        -- Expedition
        onLaunchExpedition = function(fleetId, baseId)
            ClientBattle.LaunchExpedition(fleetId, baseId)
        end,

        -- Megastructure
        onMegaStartPhase = function(megaId)
            local ok, msg = MegastructureSystem.StartPhase(megaId, rm_)
            if ok then
                Audio.Play(Audio.SFX.BUILD)
                GameUI.Notify("🏗️ 巨构工程启动: " .. megaId, "success")
                applyBaseModuleEffects()
                saveGame()
            else
                GameUI.Notify(msg or "无法启动建造", "warning")
            end
        end,
    })

    -------------------------------------------------------------------
    -- Post-GameUI.Init
    -------------------------------------------------------------------
    GameUI.ShowScene("galaxy", false)

    -- Deploy callback
    GameUI.SetDeployCallback(function()
        if not GalaxyScene.IsDeployed() then
            GalaxyScene.OnKeyDown(KEY_SPACE)
        end
    end)

    -- Ad callbacks
    GameUI.SetAdCallback(function(onResult)
        showRewardAd(function(result)
            if result.success then
                H.adBonusNext_ = true
                onResult(true, result.msg)
            else
                onResult(false, result.msg)
            end
        end)
    end)

    GameUI.SetSpeedUpAdCallback(function(target, onResult)
        showRewardAd(function(result)
            if result.success then
                if target and target.constructing then
                    target.constructing.remaining = 0
                    target.constructing.progress  = 1.0
                    GameUI.Notify("🎬 广告奖励：建造立即完成！", "success")
                    GameUI.ForceRefreshPanel(target)
                end
                if onResult then onResult(true, result.msg) end
            else
                if onResult then onResult(false, result.msg) end
            end
        end)
    end)

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

    -- Tutorial
    GameUI.TutorialTriggerStart()

    -------------------------------------------------------------------
    -- Achievement.Init
    -------------------------------------------------------------------
    Achievement.Init({
        notifyFn = GameUI.Notify,
        unlocked = H.savedAchievements_,
        redeemed = H.savedRedeemed_,
        onAudio  = function() Audio.Play(Audio.SFX.ACHIEVEMENT_UNLOCK) end,
        onUnlock = function(id, list)
            GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())
            if not clientCloud or not clientCloud.SetString then return end
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
    H.savedAchievements_ = nil
    H.savedRedeemed_     = nil

    -------------------------------------------------------------------
    -- Apply redeemed achievement rewards
    -------------------------------------------------------------------
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
            end
        end
        if #activeRewards > 0 then
            print(string.format("[P2-3] 应用成就奖励: %d 项, 额外技能点 %d", #activeRewards, bonusSkillPts))
        end

        -- Redeem callback
        GameUI.SetRedeemCallback(function(id)
            local ok2, reward = Achievement.Redeem(id)
            if not ok2 then
                GameUI.Notify("兑换失败: " .. tostring(reward), "error")
                return
            end
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
            -- Persist
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
            GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())
        end)
    end

    -- Achievement panel data
    GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())

    -- Stage goals sync
    GameUI.SetCompletedGoals(GP_.completedGoals)

    -- Career stats sync
    GameUI.SetCareerStats(careerStats_)

    -------------------------------------------------------------------
    -- Daily challenge post-init
    -------------------------------------------------------------------
    if evBonus_._challengeDelayWave and pirateAI and pirateAI.bases then
        local extra = evBonus_._challengeDelayWave
        for _, base in ipairs(pirateAI.bases) do
            base.attackTimer = (base.attackTimer or 0) + extra
        end
        print(string.format("[DailyChallenge] 首波延迟 +%ds 已应用", extra))
    end

    if evBonus_._challengeFreeTech and rs_ then
        local TIER2_IDS = {"SHIELD_REINFORCE","RAPID_REFINE","COLONY_BIOTECH","NANO_REPAIR"}
        local candidates = {}
        for _, tid in ipairs(TIER2_IDS) do
            if not rs_.unlocked[tid] then
                candidates[#candidates + 1] = tid
            end
        end
        if #candidates > 0 then
            local pick = candidates[math.random(1, #candidates)]
            rs_.unlocked[pick] = true
            local techName = Sys.TECHS[pick] and Sys.TECHS[pick].name or pick
            GameUI.Notify(string.format("🎁 每日挑战奖励：免费解锁科技「%s」", techName), "success")
            print(string.format("[DailyChallenge] 免费 Tier2 科技: %s", pick))
        end
    end

    -- BGM
    Audio.PlayBGM(Audio.BGM.GALAXY_MAIN, 2.0)
end

return M
