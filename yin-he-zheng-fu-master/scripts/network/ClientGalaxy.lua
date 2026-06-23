---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-- ============================================================================
-- network/ClientGalaxy.lua  -- 银河征服 建造/殖民/市场/外交回调
-- 从 Client.lua 拆分而来（P3-1c）
-- ============================================================================

local Sys              = require("game.Systems")
local Audio            = require("game.AudioManager")
local Achievement      = require("game.AchievementSystem")
local Campaign         = require("game.CampaignSystem")
local Commander        = require("game.CommanderSystem")
local GalaxyScene      = require("game.GalaxyScene")
local GameUI           = require("game.GameUI")
local QuestBoard       = require("game.QuestBoard")
local GalactopediaSystem = require("game.GalactopediaSystem")

local M = {}  -- 模块公开接口
local S = {}  -- 共享状态（由 M.Init 注入）

-- ============================================================================
-- 初始化：接收宿主 Client.lua 的共享状态代理
-- ============================================================================
function M.Init(state)
    S = state
end

-- ============================================================================
-- 建造回调
-- ============================================================================

function M.OnBuild(key, isUpgrade, bldIdx)
    if key == "__switch_galaxy" then
        local ClientBattle = require("network.ClientBattle")
        ClientBattle.SwitchScene("galaxy")
        return
    end
    local planet = GalaxyScene.GetSelected()
    if not planet then GameUI.Notify("请先选择一个已探索星球", "warn"); return end
    local ok, reason
    if isUpgrade then
        ok, reason = S.bs:upgrade(bldIdx, planet)
    else
        ok, reason = S.bs:build(key, planet)
    end
    if ok then
        Audio.Play(Audio.SFX.BUILD_START)
        GameUI.Notify("开始" .. (isUpgrade and "升级" or "建造") .. ": " .. BUILDINGS[key].name, "info")
        GameUI.RefreshPlanetPanel(planet)
    else
        GameUI.Notify((isUpgrade and "升级" or "建造") .. "失败: " .. (reason or ""), "error")
    end
end

function M.OnBatchUpgrade(bldIdx)
    local planet = GalaxyScene.GetSelected()
    if not planet then GameUI.Notify("请先选择一个已探索星球", "warn"); return end
    local count = 0
    for _ = 1, 20 do
        local ok = S.bs:upgrade(bldIdx, planet)
        if not ok then break end
        count = count + 1
    end
    if count > 0 then
        Audio.Play(Audio.SFX.BUILD_START)
        local b = planet.buildings[bldIdx]
        local bName = BUILDINGS[b.key] and BUILDINGS[b.key].name or b.key
        GameUI.Notify(string.format("批量升级 %s ×%d 级", bName, count), "info")
        GameUI.RefreshPlanetPanel(planet)
    else
        GameUI.Notify("无法继续升级（资源或条件不足）", "error")
    end
end

function M.OnBaseBuild(key, isUpgrade, bldIdx)
    local base = GalaxyScene.GetBase()
    if not base or not base.colonized then
        GameUI.Notify("基地尚未建立", "warn"); return
    end
    local ok, reason
    if isUpgrade then
        ok, reason = S.bbs:upgrade(bldIdx, base)
    else
        ok, reason = S.bbs:build(key, base)
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

function M.OnCoreUpgrade()
    local base = GalaxyScene.GetBase()
    if not base or not base.colonized then
        GameUI.Notify("基地尚未建立", "warn"); return
    end
    local ok, reason = S.bbs:upgradeCore(base)
    if ok then
        local nextLv = (base.coreLevel or 1)
        GameUI.Notify("核心升级已启动 → Lv." .. nextLv + 1 .. " (建造中…)", "info")
        GameUI.RefreshPlanetPanel(base)
    else
        GameUI.Notify("核心升级失败: " .. (reason or ""), "error")
    end
end

-- ============================================================================
-- 科研回调
-- ============================================================================

function M.OnResearch(id)
    local ok, reason = S.rs:start(id)
    if ok then
        if S.evBonus._challengeSlowResearch and S.rs.current then
            S.rs.current.remaining = (S.rs.current.remaining or 0) * 2
            print("[DailyChallenge] 科研减速×0.5 已应用")
        end
        Audio.Play(Audio.SFX.RESEARCH_START)
        GameUI.Notify("开始研发: " .. TECHS[id].name, "info")
        GameUI.RefreshTechPanel()
    else
        GameUI.Notify("研发失败: " .. (reason or ""), "error")
    end
end

-- ============================================================================
-- 市场回调
-- ============================================================================

function M.OnMarket(action, res, amount)
    if S.evBonus._challengeNoMarket then
        GameUI.Notify("🎯 今日挑战限制：市场暂停交易", "error"); return
    end
    local ok, val
    if action == "sell" then
        ok, val = S.ms:sell(res, amount)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("出售 " .. RES_LABELS[res] .. "×" .. amount .. "  +★" .. val, "success")
        else GameUI.Notify("出售失败: " .. (val or ""), "error") end
    else
        ok, val = S.ms:buy(res, amount)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("购买 " .. RES_LABELS[res] .. "×" .. amount .. "  -★" .. val, "success")
        else GameUI.Notify("购买失败: " .. (val or ""), "error") end
    end
    GameUI.RefreshResourceBar()
end

-- ============================================================================
-- 黑市走私网络回调
-- ============================================================================

function M.OnBlackMarket(action, ...)
    if action == "buy" then
        local shopIdx = ...
        local ok, reason = S.bm:buyItem(shopIdx)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("🕵️ 购入走私货物", "success")
        else GameUI.Notify("购入失败: " .. (reason or ""), "error") end
    elseif action == "sell" then
        local cargoIdx = ...
        local ok, gain = S.bm:sellDirect(cargoIdx)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("🕵️ 直接出售  +★" .. (gain or 0), "success")
            local stats = S.bm:getStats()
            Achievement.Check("smuggle_trade", stats)
        else GameUI.Notify("出售失败: " .. (gain or ""), "error") end
    elseif action == "startRoute" then
        local routeIdx, cargoIdx = ...
        local ok, reason = S.bm:startRoute(routeIdx, cargoIdx)
        if ok then
            Audio.Play(Audio.SFX.FLEET_LAUNCH)
            GameUI.Notify("🚀 走私航线已出发", "success")
        else GameUI.Notify("发货失败: " .. (reason or ""), "error") end
    elseif action == "cancelRoute" then
        local ok = S.bm:cancelRoute()
        if ok then GameUI.Notify("走私航线已取消", "info")
        else GameUI.Notify("无活跃航线", "warn") end
    elseif action == "refresh" then
        local ok, reason = S.bm:manualRefresh()
        if ok then
            Audio.Play(Audio.SFX.UI_CLICK)
            GameUI.Notify("🔄 黑市已刷新", "success")
        else GameUI.Notify("刷新失败: " .. (reason or ""), "error") end
    elseif action == "hireCommander" then
        if not Commander.CanRecruit() then
            GameUI.Notify("指挥官编制已满", "warn")
        elseif S.rm:getCredits() < Sys.COMMANDER_MARKET_COST then
            GameUI.Notify("星币不足（需要★" .. Sys.COMMANDER_MARKET_COST .. "）", "error")
        else
            S.rm:addCredits(-Sys.COMMANDER_MARKET_COST)
            local newCmd = Commander.Recruit("market")
            if newCmd then
                Audio.Play(Audio.SFX.MARKET_TRADE)
                GameUI.Notify("🎖️ 雇佣了指挥官 " .. newCmd.name .. "！", "success")
            end
        end
    elseif action == "routeComplete" then
        local result = ...
        if result and result.success then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("🎉 走私成功！获得 ★" .. (result.profit or 0), "success")
            QuestBoard.OnMarketTrade()
            QuestBoard.OnCreditsEarned(result.profit or 0)
        else
            Audio.Play(Audio.SFX.PIRATE_ALERT)
            GameUI.Notify("💀 走私被截获！罚款 ★" .. (result.fine or 0), "error")
        end
        local stats = S.bm:getStats()
        Achievement.Check("smuggle_trade", stats)
    end
    GameUI.RefreshBlackMarketPanel()
    GameUI.RefreshResourceBar()
end

-- ============================================================================
-- 星球类型加成
-- ============================================================================

--- 应用星球类型加成到资源速率（幂等：先撤旧再重新应用）
function M.ApplyPlanetTypeBonus(planet)
    local ptype = planet.ptype
    if not ptype or not PLANET_TYPE_BONUS then return end
    local bonus = PLANET_TYPE_BONUS[ptype]
    if not bonus then return end

    -- 先撤销上次对该行星应用过的加成（幂等保障）
    local prev = planet.appliedBonus or {}
    if prev.mineralsDelta then
        S.rm.rates.minerals = (S.rm.rates.minerals or 0) - prev.mineralsDelta
    end
    if prev.crystalDelta then
        S.rm.rates.crystal = (S.rm.rates.crystal or 0) - prev.crystalDelta
    end

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
            S.rm.rates.minerals = (S.rm.rates.minerals or 0) + delta
            ab.mineralsDelta = delta
        end
    end
    -- 水晶产量加成（Oceanic）
    if bonus.crystalMult then
        local base_rate = 2.0
        local delta = base_rate * (bonus.crystalMult - 1.0)
        S.rm.rates.crystal = (S.rm.rates.crystal or 0) + delta
        ab.crystalDelta = delta
    end
    -- 核能精炼加成（Volcanic）
    if bonus.nuclearMult then
        S.rm.baseBonus = S.rm.baseBonus or {}
        S.rm.baseBonus.nuclearMult = (S.rm.baseBonus.nuclearMult or 1.0) * bonus.nuclearMult
    end
    -- 建造费用折扣（Barren）
    if bonus.buildCostMult then
        S.rm.baseBonus = S.rm.baseBonus or {}
        S.rm.baseBonus.buildCostMult = (S.rm.baseBonus.buildCostMult or 1.0) * bonus.buildCostMult
    end
    -- 能源精炼加成（Gas Giant）
    if bonus.esourceMult then
        S.rm.baseBonus = S.rm.baseBonus or {}
        S.rm.baseBonus.esourceMult = (S.rm.baseBonus.esourceMult or 1.0) * bonus.esourceMult
    end
    print("[Colony] 星球类型加成 " .. ptype .. " → " .. (bonus.label or ""))
end

--- 重新对所有已殖民行星应用类型加成（读档后调用）
function M.ReapplyAllPlanetBonuses()
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        p.appliedBonus = nil
    end
    if S.rm.baseBonus then
        S.rm.baseBonus.esourceMult   = nil
        S.rm.baseBonus.nuclearMult   = nil
        S.rm.baseBonus.buildCostMult = nil
    end
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        M.ApplyPlanetTypeBonus(p)
    end
    S.markBaseEffectsDirty()
end

-- ============================================================================
-- 殖民
-- ============================================================================

--- 核心殖民执行（消耗资源 + 调用 GalaxyScene）
function M.DoColonize(planet)
    if not planet or planet.colonized then return false end
    local cost = { metal = 200, esource = 100 }
    if not S.rm:canAfford(cost) then
        GameUI.Notify("资源不足: 探索需要 金属×200 能源×100", "error")
        return false
    end
    S.rm:spend(cost)
    local leveled, newLevel, newRank, rewards = GalaxyScene.Colonize(planet)
    Audio.Play(Audio.SFX.COLONIZE_SUCCESS)
    -- 成就检查：殖民类
    do
        local colonized = #(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {})
        Achievement.Check("colonize", { totalColonized = colonized })
        if colonized == 2 then
            local TutorialSystem = require("game.ui.TutorialSystem")
            TutorialSystem.TriggerPhase("expansion")
        end
    end
    -- 银河百科 — 殖民数达3时解锁
    do
        local colCount = #(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {})
        if colCount >= 3 then
            local gpCol = GalactopediaSystem.TryUnlock("colonize_3")
            if gpCol then GameUI.Notify("📖 百科解锁: " .. gpCol, "info") end
        end
    end
    -- 应用星球类型加成
    M.ApplyPlanetTypeBonus(planet)
    local ptypeLabel = (PLANET_TYPE_BONUS and planet.ptype and PLANET_TYPE_BONUS[planet.ptype]) and
                       ("  [" .. (PLANET_TYPE_BONUS[planet.ptype].label or planet.ptype) .. "]") or ""
    GameUI.Notify("探索成功: " .. planet.name .. ptypeLabel .. "  (金属-200  能源-100)", "success")
    S.handleLevelUp(leveled, newLevel, newRank, rewards)
    GameUI.RefreshPlanetPanel(planet)
    QuestBoard.OnColonize()
    S.checkStageGoalsFn()
    S.saveGame()
    -- 战役模式首次殖民触发剧情对话
    if S.campaignMode and not S.campaignFirstColonize then
        S.campaignFirstColonize = true
        Campaign.TriggerDialogue("on_first_colonize")
    end
    return true
end

-- ============================================================================
-- 星球升级
-- ============================================================================

function M.UpgradePlanet(planet)
    if not planet or not planet.colonized or planet.isBase then
        return false, "无法升级此星球"
    end
    local lv = planet.level or 1
    if lv >= 5 then return false, "已达最高等级 Lv.5" end
    local cost = S.PLANET_UPGRADE_COSTS[lv + 1]
    if not cost then return false, "升级配置缺失" end
    if not S.rm:canAfford(cost) then
        local parts = {}
        for res, amt in pairs(cost) do
            local RES_LABEL = { metal="金属", crystal="晶体", esource="能源", nuclear="核能" }
            parts[#parts+1] = (RES_LABEL[res] or res) .. "×" .. amt
        end
        return false, "资源不足 (" .. table.concat(parts, "  ") .. ")"
    end
    S.rm:spend(cost)
    planet.level = lv + 1
    for i = 1, #planet.buildings do
        S.bs:_recalcBuildingProd(planet.buildings[i], planet)
    end
    return true, string.format("%s 升级到 Lv.%d！建筑槽+1，产量+5%%", planet.name, planet.level)
end

-- ============================================================================
-- 舰队/造船
-- ============================================================================

function M.FleetHasExplorer(fleetId)
    if not S.fm then return false end
    local fl = S.fm.fleets[fleetId]
    if not fl then return false end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "EXPLORER" and e.count > 0 then return true end
    end
    return false
end

function M.OnExplorerColonize()
    local cnt = S.fm.reserve and (S.fm.reserve["EXPLORER"] or 0) or 0
    if cnt <= 0 then
        GameUI.Notify("储备中没有探索舰", "warn"); return
    end
    local sel = GalaxyScene.GetSelected()
    if sel and not sel.colonized and not sel.isBase then
        local ok = M.DoColonize(sel)
        if ok then
            S.fm.reserve["EXPLORER"] = cnt - 1
            if S.fm.reserve["EXPLORER"] <= 0 then S.fm.reserve["EXPLORER"] = nil end
            S.explorerColonizeMode = false
            GameUI.RefreshReservePanel(S.fm)
        end
    else
        S.explorerColonizeMode = true
        GameUI.Notify("已选择探索舰 — 请点击一个未探索星球执行探索", "info")
        GameUI.SetExplorerColonizeMode(true)
    end
end

function M.OnShipCancel(index)
    if S.spq:cancel(index) then
        GameUI.Notify("已取消建造", "info")
        GameUI.RefreshShipyardPanel()
    end
end

function M.OnShipPromote(index)
    S.spq:promote(index)
    GameUI.RefreshShipyardPanel()
end

function M.OnShipQueue(shipType)
    if S.evBonus._challengeNoCapital then
        local banned = { CARRIER=true, BATTLECRUISER=true, DESTROYER=true }
        if banned[shipType] then
            GameUI.Notify("🎯 今日挑战限制：不可建造大型舰", "error"); return
        end
    end
    local planet = GalaxyScene.GetSelected()
    if not planet then
        local base = GalaxyScene.GetBase()
        if base and base.colonized then planet = base end
    end
    if not planet then GameUI.Notify("请先选择有造船厂的星球或基地", "warn"); return end
    local ok, reason = S.spq:queue(shipType, planet)
    if ok then
        GameUI.Notify("加入建造队列: " .. SHIP_TYPES[shipType].name, "info")
        GameUI.RefreshShipyardPanel()
    else
        GameUI.Notify("造船失败: " .. (reason or ""), "error")
    end
end

-- ============================================================================
-- 星球选择
-- ============================================================================

function M.OnPlanetSelect(planet)
    S.selectedPlanet = planet
    -- 探索舰殖民模式：点击未殖民星球直接执行殖民
    if S.explorerColonizeMode and planet and not planet.colonized and not planet.isBase then
        local cnt = S.fm.reserve and (S.fm.reserve["EXPLORER"] or 0) or 0
        if cnt > 0 then
            local ok = M.DoColonize(planet)
            if ok then
                S.fm.reserve["EXPLORER"] = cnt - 1
                if S.fm.reserve["EXPLORER"] <= 0 then S.fm.reserve["EXPLORER"] = nil end
                GameUI.RefreshReservePanel(S.fm)
            end
        end
        S.explorerColonizeMode = false
        GameUI.SetExplorerColonizeMode(false)
    end
    GameUI.RefreshPlanetPanel(planet)
    GameUI.RefreshShipyardPanel()
    GameUI.ShowScene("galaxy", planet ~= nil)
end

-- ============================================================================
-- 注册黑市路线完成回调
-- ============================================================================

function M.RegisterBlackMarketCallback()
    S.bm.onRouteComplete = function(result)
        M.OnBlackMarket("routeComplete", result)
    end
end

return M
