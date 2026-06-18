-- Auto-split from ClientSetup.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
            H.selectedPlanet_ = p
            GameUI.ShowPlanetPanel(p)
        end,
        onFleetSelect = function(fid)
            H.activeFleetId_ = fid
            GameUI.ShowFleetPanel(fid)
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
            ClientBattle.StartBattle(fleet, base)
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
                GameUI.ShowEventChoices(ev, function(choiceIdx)
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
                    -- 链式事件
                    if choice.chainEvent then
                        GalaxyEvents.TriggerChain(choice.chainEvent)
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
        onExplorerTaskCb    = function(...) ClientGalaxy.OnExplorerTask(...) end,

        -- Fleet select
        onFleetSelectCb = function(selectedFid)
            H.activeFleetId_ = selectedFid
            GameUI.ShowFleetPanel(selectedFid)
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

        -- Batch build
        onBatchBuild = function(...) ClientGalaxy.OnBatchBuild(...) end,

        -- Planet jump
        onPlanetJump = function(planet)
            GalaxyScene.JumpToPlanet(planet)
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
