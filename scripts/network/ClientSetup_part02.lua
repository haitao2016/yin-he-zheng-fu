-- Auto-split from ClientSetup.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
