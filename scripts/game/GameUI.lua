local GameUI = {}

local Audio            = require("game.AudioManager")
local UICommon         = require("game.ui.UICommon")
local NotifyPanel      = require("game.ui.NotifyPanel")
local FleetPanel       = require("game.ui.FleetPanel")
local TechPanel        = require("game.ui.TechPanel")
local PlanetPanel      = require("game.ui.PlanetPanel")
local BasePanel        = require("game.ui.BasePanel")
local TutorialSystem   = require("game.ui.TutorialSystem")
local SettingsPanel    = require("game.ui.SettingsPanel")
local AchievementPanel  = require("game.ui.AchievementPanel")
local EndGamePanel      = require("game.ui.EndGamePanel")
local MegaPanel        = require("game.ui.MegaPanel")
local LiveryPanel      = require("game.ui.LiveryPanel")
local GalactopediaPanel = require("game.ui.GalactopediaPanel")
local GalaxyScene     = require("game.GalaxyScene")
local EmpirePanel      = require("game.ui.EmpirePanel")
local LogPanel         = require("game.ui.LogPanel")
local CareerPanel      = require("game.ui.CareerPanel")
local NemesisRenderPanel = require("game.ui.NemesisRenderPanel")
local LegacyPanel      = require("game.ui.LegacyPanel")
local FormationEditor  = require("game.ui.FormationEditor")
local GalaxyPanels       = require("game.ui.GalaxyPanels")
local Overlays         = require("game.ui.Overlays")
local TopBar           = require("game.ui.TopBar")
local GalaxyHud        = require("game.ui.GalaxyHud")
local CommonUI         = require("game.ui.CommonUI")
local GalaxyUI          = require("game.ui.GalaxyUI")
local BattleUI          = require("game.ui.BattleUI")

local vg_ = nil

function GameUI.Init(opts)
    vg_ = opts.vg
    CommonUI.init(vg_, opts.screenW or 800, opts.screenH or 600)
    GalaxyUI.init(vg_, opts.screenW or 800, opts.screenH or 600)
    BattleUI.init(vg_, opts.screenW or 800, opts.screenH or 600)

    CommonUI.setGameData({
        rm                     = opts.rm,
        bs                     = opts.bs,
        bbs                    = opts.bbs,
        rs                     = opts.rs,
        ms                     = opts.ms,
        player                 = opts.player,
        spq                    = opts.spq,
        pirateAI               = opts.pirateAI,
        getConquestProgress    = opts.getConquestProgress,
        onHarvestAllCb        = opts.onHarvestAllCb,
    })

    GalaxyUI.setGameData({
        fm                     = opts.fm,
        pirateAI               = opts.pirateAI,
        player                 = opts.player,
        rm                     = opts.rm,
        onBuildCb              = opts.onBuildCb,
        onBatchUpgradeCb       = opts.onBatchUpgradeCb,
        onBaseBuildCb          = opts.onBaseBuildCb,
        onCoreUpgradeCb        = opts.onCoreUpgradeCb,
        onResearchCb           = opts.onResearchCb,
        onHarvestAllCb       = opts.onHarvestAllCb,
        onTogglePriorityCb     = opts.onTogglePriorityCb,
        getIsPriorityCb      = opts.getIsPriorityCb,
        onCancelQueuedCb      = opts.onCancelQueuedCb,
        onWarpFleetCb        = opts.onWarpFleetCb,
        onFleetSelectCb       = opts.onFleetSelectCb,
        onFleetMoveShipCb   = opts.onFleetMoveShipCb,
        onAssignReserveCb     = opts.onAssignReserveCb,
        onExplorerColonizeCb = opts.onExplorerColonizeCb,
        onExplorerTaskCb    = opts.onExplorerTaskCb,
        onGarrisonFleetCb   = opts.onGarrisonFleetCb,
        onRecallGarrisonCb  = opts.onRecallGarrisonCb,
        getGarrisonInfoCb   = opts.getGarrisonInfoCb,
        getPlanetProdHistoryCb = opts.getPlanetProdHistoryCb,
        onSendGiftCb         = opts.onSendGiftCb,
        getDiplomacyStateCb = opts.getDiplomacyStateCb,
        onActivateLongTradeCb = opts.onActivateLongTradeCb,
        onSetSpecCb          = opts.onSetSpecCb,
        onUpgradePlanetCb    = opts.onUpgradePlanetCb,
        onMegaStartPhaseCb = opts.onMegaStartPhaseCb,
        speedUpAdCb         = opts.speedUpAdCb,
        techSpeedAdCb        = opts.techSpeedAdCb,
    })

    SettingsPanel.SetAudio(Audio)
    SettingsPanel.Load()
    EndGamePanel.SetNotifyFn(GameUI.Notify)
    EndGamePanel.SetLeaderboardCallback(opts.onShowLeaderboard)

    if vg_ then
        nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")
    end

    CommonUI.resetPerRun()
    GalaxyUI.resetPerRun()

    UICommon.galaxyScene = GalaxyScene
    UICommon.bindFns({
        panel = function() end,
        text  = function() end,
    })

    GalaxyPanels.Init({
        onMarketCb            = opts.onMarketCb,
        onBlackMarketCb       = opts.onBlackMarketCb,
        onExchangeCb          = opts.onExchangeCb,
        onShipQueueCb         = opts.onShipQueueCb,
        onShipCancelCb        = opts.onShipCancelCb,
        onShipPromoteCb       = opts.onShipPromoteCb,
        getDiploRelationsCb = opts.getDiploRelationsCb,
        onActivateIntelCb     = opts.onActivateIntelCb,
        onActivateAllianceCb = opts.onActivateAllianceCb,
        onActivateBlockadeCb = opts.onActivateBlockadeCb,
        onActivateMediationCb = opts.onActivateMediationCb,
        onSendSignalCb     = opts.onSendSignalCb,
        notifyFn             = GameUI.Notify,
        onEndlessChallengeCb = GameUI.OpenEndlessModePanel,
        onDailyChallengeCb = GameUI.OpenDailyChallengePanel,
        onBossRushCb       = GameUI.OpenBossRushPanel,
    })
    Overlays.Init({
        onCampaignDialogueDone = opts.onCampaignDialogueDone,
        onDiploEventChoice   = opts.onDiploEventChoice,
    })
end

function GameUI.Shutdown()
    CommonUI.clearAll()
end

function GameUI.Notify(msg, ntype)
    Audio.PlayNotify(ntype)
    NotifyPanel.Push(msg, ntype)
end

function GameUI.UpdateNotifications(dt)
    CommonUI.update(dt)
end

function GameUI.RenderTopBar()
    CommonUI.renderTopBar()
end

function GameUI.RenderHUD(dt)
    GalaxyUI.render(dt)
    CommonUI.renderRipples()
    CommonUI.renderGlobalPopups()
end

function GameUI.ShowEventPopup(ev, onChoice)
    Overlays.ShowEventPopup(ev, onChoice)
end

function GameUI.ShowDiploEvent(ev)
    Overlays.ShowDiploEvent(ev)
end

function GameUI.ShowCardDraft(cards, onSelect)
    Overlays.ShowCardDraft(cards, onSelect)
end

function GameUI.HideCardDraft()
    Overlays.HideCardDraft()
end

function GameUI.OnScroll(mx, my, delta)
    return CommonUI.onScroll(mx, my, delta)
end

function GameUI.OnTouchBegin(id, rawX, rawY)
    return CommonUI.onTouchBegin(id, rawX, rawY)
end

function GameUI.OnTouchMove(id, rawX, rawY)
    return CommonUI.onTouchMove(id, rawX, rawY)
end

function GameUI.OnTouchEnd(id, rawX, rawY)
    return CommonUI.onTouchEnd(id, rawX, rawY)
end

function GameUI.OnClick(mx, my)
    if CommonUI.onClick(mx, my) then return true end
    if GalaxyUI.onClick(mx, my) then return true end
    if BattleUI.onClick(mx, my) then return true end
    return false
end

function GameUI.SetPirateWarning(minTime)
    CommonUI.setPirateWarning(minTime)
end

function GameUI.RefreshResourceBar()
end

function GameUI.RefreshPlanetPanel(planet)
    GalaxyUI.refreshPlanetPanel(planet)
end

function GameUI.ForceRefreshPanel(planet)
    GalaxyUI.forceRefreshPanel(planet)
end

function GameUI.RefreshFleetPanel(fm, activeId)
    GalaxyUI.refreshFleetPanel(fm, activeId)
end

function GameUI.SetExpeditions(exps, bases, lastExp)
    GalaxyUI.setExpeditions(exps, bases, lastExp)
end

function GameUI.SetMapSelectedFleet(fleetId)
    GalaxyUI.setMapSelectedFleet(fleetId)
end

function GameUI.RefreshExplorerTasks(tasks)
    GalaxyUI.refreshExplorerTasks(tasks)
end

function GameUI.PushExploreLog(entry)
    GalaxyUI.pushExploreLog(entry)
end

function GameUI.SetCompletedGoals(completed)
    GalaxyUI.setCompletedGoals(completed)
end

function GameUI.SetCareerStats(stats)
    if type(stats) ~= "table" then return end
    GalaxyPanels.SetCareerStats(stats)
    EndGamePanel.SetCareerStats(stats)
    CareerPanel.SetStats(stats)
end

function GameUI.SetAchievements(data, total)
    AchievementPanel.SetData(data, total)
end

function GameUI.SetRedeemCallback(fn)
    AchievementPanel.SetRedeemCallback(fn)
end

function GameUI.GetRedeemableCount()
    return AchievementPanel.GetRedeemableCount()
end

function GameUI.SetEndlessRound(round)
    GalaxyUI.setEndlessRound(round)
end

function GameUI.ShowDailyChallengeHint(challenge)
    CommonUI.showDailyChallengeHint(challenge)
end

function GameUI.SetLeagueHud(data)
    CommonUI.setLeagueHud(data)
end

function GameUI.SetDeployed(flag)
    CommonUI.setDeployed(flag)
    if flag then
        TutorialSystem.TriggerDeployed()
    end
end

function GameUI.ShowScene(scene, hasPlanet)
    GalaxyUI.showScene(scene, hasPlanet)
end

function GameUI.ShowEndGame(gameType, stats, onRetry)
    EndGamePanel.Show(gameType, stats, onRetry)
end

function GameUI.HideEndGame()
    EndGamePanel.Hide()
    CommonUI.resetTopBarAdCount()
end

function GameUI.SetAdCallback(fn)
    EndGamePanel.SetAdCallback(fn)
end

function GameUI.SetSpeedUpAdCallback(fn)
end

function GameUI.SetTechSpeedAdCallback(fn)
end

function GameUI.SetTopBarAdCallback(fn)
    CommonUI.setTopBarAdCallback(fn)
end

function GameUI.TutorialDeserialize(list)
    TutorialSystem.Deserialize(list)
end

function GameUI.TutorialSerialize()
    return TutorialSystem.Serialize()
end

function GameUI.TutorialTriggerStart()
    TutorialSystem.TriggerStart()
end

function GameUI.SetRemainingTime(seconds)
    CommonUI.setRemainingTime(seconds)
end

function GameUI.ShowTimeoutScreen(adCount, onWatch)
    SettingsPanel.Show and SettingsPanel.Show()
end

function GameUI.UpdateTimeoutAdCount(adCount)
end

function GameUI.HideTimeoutScreen()
end

function GameUI.RefreshTechPanel()
end

function GameUI.SetVg(vg, w, h)
    CommonUI.setVg(vg, w, h)
    GalaxyUI.init(vg, w, h)
    BattleUI.setVg(vg, w, h)
end

function GameUI.IsFleetNaming()
    return FleetPanel.IsNaming()
end

function GameUI.OnFleetNamingText(text)
    FleetPanel.OnTextInput(text)
end

function GameUI.OnFleetNamingBackspace()
    FleetPanel.OnBackspace()
end

function GameUI.OnFleetNamingEnter()
    FleetPanel.OnEnter()
end

function GameUI.SetFleetOverview(show, fleetMgr)
    GalaxyUI.setFleetOverview(show, fleetMgr)
end

function GameUI.SetExplorerColonizeMode(active)
    GalaxyUI.setExplorerColonizeMode(active)
end

function GameUI.RefreshShipyardPanel()
end

function GameUI.SetShipyardBuilt(built)
end

function GameUI.RefreshReservePanel(fm)
end

function GameUI.RefreshBlackMarketPanel()
end

function GameUI.ShowCareerPage()
    CareerPanel.Show()
end

function GameUI.HideCareerPage()
    CareerPanel.Hide()
end

function GameUI.ToggleEmpirePanel()
    EmpirePanel.Toggle()
end

function GameUI.ToggleLegacyPanel()
    LegacyPanel.Toggle()
end

function GameUI.ShowEndgameCrisisPanel(crisis, onChoice)
    if not crisis then return end
    local r, g, b = crisis.color[1], crisis.color[2], crisis.color[3]
    local popupChoices = {}
    for _, ch in ipairs(crisis.choices or {}) do
        local costStr = ""
        if ch.cost then
            local parts = {}
            for k, v in pairs(ch.cost) do
                if v > 0 then parts[#parts + 1] = k .. "x" .. v end
            end
            if #parts > 0 then costStr = " [" .. table.concat(parts, ", ") .. "]" end
        end
        popupChoices[#popupChoices + 1] = { text = ch.text .. costStr }
    end
    Overlays.ShowEventPopup({
        color = { r, g, b },
        icon = crisis.icon,
        label = crisis.name,
        desc = crisis.phaseDesc,
        choices = popupChoices,
    }, onChoice)
end

function GameUI.RenderProgressBars(selectedPlanet)
end

function GameUI.OpenEndlessModePanel()
    local panel = require("game.ui.EndlessPanel")
    if panel and panel.Show then panel.Show() end
end

function GameUI.OpenDailyChallengePanel()
    local panel = require("game.ui.ChallengePanel")
    if panel and panel.open then
        local p = panel.open()
        if p and p.draw then p.draw(vg_) end
    end
end

function GameUI.OpenBossRushPanel()
    local panel = require("game.ui.BossRushPanel")
    if panel and panel.Show then panel.Show() end
end

function GameUI.TriggerTechComplete(techId)
    CommonUI.triggerTechComplete(techId)
end

function GameUI.RenderSceneTitle()
end

return GameUI
