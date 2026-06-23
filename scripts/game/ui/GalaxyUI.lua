---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found, undefined-doc-param, missing-parameter, access-invisible
local GalaxyUI = {}

local Audio         = require("game.AudioManager")
local UICommon      = require("game.ui.UICommon")
local NotifyPanel   = require("game.ui.NotifyPanel")
local FleetPanel    = require("game.ui.FleetPanel")
local TechPanel     = require("game.ui.TechPanel")
local PlanetPanel   = require("game.ui.PlanetPanel")
local BasePanel     = require("game.ui.BasePanel")
local MegaPanel     = require("game.ui.MegaPanel")
local LiveryPanel   = require("game.ui.LiveryPanel")
local GalactopediaPanel = require("game.ui.GalactopediaPanel")
local GalaxyScene   = require("game.GalaxyScene")
local EmpirePanel   = require("game.ui.EmpirePanel")
local LogPanel      = require("game.ui.LogPanel")
local CareerPanel   = require("game.ui.CareerPanel")
local NemesisRenderPanel = require("game.ui.NemesisRenderPanel")
local LegacyPanel   = require("game.ui.LegacyPanel")
local FormationEditor = require("game.ui.FormationEditor")
local GalaxyHud     = require("game.ui.GalaxyHud")
local GalaxyPanels  = require("game.ui.GalaxyPanels")
local Overlays      = require("game.ui.Overlays")
local EndGamePanel  = require("game.ui.EndGamePanel")
local SettingsPanel = require("game.ui.SettingsPanel")
local AchievementPanel = require("game.ui.AchievementPanel")
local TutorialSystem = require("game.ui.TutorialSystem")
local CommonUI      = require("game.ui.CommonUI")

local TOPBAR_H  = 44

local vg_            = nil
local screenW_       = 800
local screenH_       = 600
local cursorX_       = 0
local cursorY_       = 0

local fm_            = nil
local pirateAI_      = nil
local player_        = nil
local rm_            = nil

local onBuildCb_          = nil
local onBatchUpgradeCb_   = nil
local onBaseBuildCb_      = nil
local onCoreUpgradeCb_    = nil
local onResearchCb_       = nil
local onHarvestAllCb_     = nil
local onTogglePriorityCb_ = nil
local getIsPriorityCb_    = nil
local onCancelQueuedCb_   = nil
local onWarpFleetCb_      = nil
local onFleetSelectCb_    = nil
local onFleetMoveShipCb_  = nil
local onAssignReserveCb_  = nil
local onExplorerColonizeCb_ = nil
local onExplorerTaskCb_ = nil
local onGarrisonFleetCb_  = nil
local onRecallGarrisonCb_ = nil
local getGarrisonInfoCb_  = nil
local getPlanetProdHistoryCb_ = nil
local onSendGiftCb_       = nil
local getDiplomacyStateCb_ = nil
local onActivateLongTradeCb_ = nil
local onSetSpecCb_        = nil
local onUpgradePlanetCb_  = nil
local onMegaStartPhaseCb_ = nil
local speedUpAdCb_        = nil
local techSpeedAdCb_      = nil
local speedUpAdLoading_   = false
local techSpeedAdLoading_ = false

local currentScene_ = "galaxy"
local hasPlanet_    = false
local selectedPlanet_ = nil
local endlessRound_ = 0

local fleetOverviewShow_ = false
local fleetOverviewData_ = nil

local explorerColonizeMode_ = false
local explorerTasks_UI_ = {}
local expeditions_UI_ = {}
local pirateBases_UI_ = {}
local lastExpedition_UI_ = {}

local exploreLog_ = {}
local completedGoals_UI_ = {}

local hitAreas_ = {}

---@param vg userdata
---@param sw number
---@param sh number
function GalaxyUI.init(vg, sw, sh)
    vg_ = vg
    screenW_ = sw or 800
    screenH_ = sh or 600
end

---@param data table
function GalaxyUI.setGameData(data)
    data = data or {}
    fm_       = data.fm
    pirateAI_ = data.pirateAI
    player_   = data.player
    rm_       = data.rm

    onBuildCb_            = data.onBuildCb
    onBatchUpgradeCb_     = data.onBatchUpgradeCb
    onBaseBuildCb_        = data.onBaseBuildCb
    onCoreUpgradeCb_      = data.onCoreUpgradeCb
    onResearchCb_         = data.onResearchCb
    onHarvestAllCb_       = data.onHarvestAllCb
    onTogglePriorityCb_   = data.onTogglePriorityCb
    getIsPriorityCb_      = data.getIsPriorityCb
    onCancelQueuedCb_     = data.onCancelQueuedCb
    onWarpFleetCb_        = data.onWarpFleetCb
    onFleetSelectCb_      = data.onFleetSelectCb
    onFleetMoveShipCb_    = data.onFleetMoveShipCb
    onAssignReserveCb_    = data.onAssignReserveCb
    onExplorerColonizeCb_ = data.onExplorerColonizeCb
    onExplorerTaskCb_     = data.onExplorerTaskCb
    onGarrisonFleetCb_    = data.onGarrisonFleetCb
    onRecallGarrisonCb_   = data.onRecallGarrisonCb
    getGarrisonInfoCb_    = data.getGarrisonInfoCb
    getPlanetProdHistoryCb_ = data.getPlanetProdHistoryCb
    onSendGiftCb_         = data.onSendGiftCb
    getDiplomacyStateCb_  = data.getDiplomacyStateCb
    onActivateLongTradeCb_ = data.onActivateLongTradeCb
    onSetSpecCb_          = data.onSetSpecCb
    onUpgradePlanetCb_    = data.onUpgradePlanetCb
    onMegaStartPhaseCb_   = data.onMegaStartPhaseCb
    speedUpAdCb_          = data.speedUpAdCb
    techSpeedAdCb_        = data.techSpeedAdCb
    speedUpAdLoading_     = false
    techSpeedAdLoading_   = false

    UICommon.fm = fm_
    UICommon.pirateAI = pirateAI_
    if fm_ then
        FleetPanel.SetActiveId(1)
    end
end

function GalaxyUI.resetPerRun()
    LogPanel.Reset()
    EmpirePanel.Reset()
    exploreLog_ = {}
    completedGoals_UI_ = {}
    fleetOverviewShow_ = false
    fleetOverviewData_ = nil
    explorerColonizeMode_ = false
    selectedPlanet_ = nil
    hasPlanet_ = false
end

---@param show boolean
---@param fleetMgr table
function GalaxyUI.setFleetOverview(show, fleetMgr)
    fleetOverviewShow_ = show
    fleetOverviewData_ = fleetMgr
end

---@param active boolean
function GalaxyUI.setExplorerColonizeMode(active)
    explorerColonizeMode_ = active == true
end

---@param planet table|nil
function GalaxyUI.refreshPlanetPanel(planet)
    if planet ~= selectedPlanet_ then
        PlanetPanel.ResetScroll()
        TechPanel.ResetScroll()
    end
    selectedPlanet_ = planet
end

---@param planet table|nil
function GalaxyUI.forceRefreshPanel(planet)
    selectedPlanet_ = nil
    selectedPlanet_ = planet
end

---@param fleet table
function GalaxyUI.setMapSelectedFleet(fleetId)
    FleetPanel.SetMapSelected(fleetId)
end

---@param tasks table
function GalaxyUI.refreshExplorerTasks(tasks)
    explorerTasks_UI_ = tasks or {}
end

---@param entry table
function GalaxyUI.pushExploreLog(entry)
    table.insert(exploreLog_, 1, entry)
    if #exploreLog_ > 20 then
        table.remove(exploreLog_)
    end
end

---@param completed table
function GalaxyUI.setCompletedGoals(completed)
    completedGoals_UI_ = completed or {}
end

---@param exps table
---@param bases table
---@param lastExp table
function GalaxyUI.setExpeditions(exps, bases, lastExp)
    expeditions_UI_ = exps or {}
    pirateBases_UI_ = bases or {}
    lastExpedition_UI_ = lastExp or {}
end

---@param fm table
---@param activeId number|nil
function GalaxyUI.refreshFleetPanel(fm, activeId)
    fm_ = fm
    UICommon.fm = fm
    if activeId then
        FleetPanel.SetActiveId(activeId)
    end
end

---@param scene string
---@param hasPlanet boolean
function GalaxyUI.showScene(scene, hasPlanet)
    currentScene_ = scene
    hasPlanet_ = hasPlanet == true
    NemesisRenderPanel.Hide()
end

---@param name string
function GalaxyUI.switchPanel(name)
    if name == "empire" then EmpirePanel.Toggle()
    elseif name == "nemesis" then NemesisRenderPanel.Toggle()
    elseif name == "livery" then LiveryPanel.Toggle()
    elseif name == "galactopedia" then GalactopediaPanel.Toggle()
    elseif name == "mega" then MegaPanel.Toggle()
    elseif name == "legacy" then LegacyPanel.Toggle()
    elseif name == "log" then LogPanel.Toggle()
    elseif name == "stats" then
        local v = not CommonUI.getState("statsVisible")
        CommonUI.toggleFlag("statsVisible")
    elseif name == "signal" then
        CommonUI.toggleFlag("signalOpen")
    elseif name == "quest" then
        CommonUI.toggleFlag("questVisible")
    elseif name == "diplo" then
        CommonUI.toggleFlag("diploRelVisible")
    end
end

---@param panel table
local function drawButton(x, y, w, h, label, r, g, b, onClick)
    local mx = x + w / 2
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, 4)
    nvgFillColor(vg_, nvgRGBA(r, g, b, 60))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x + 0.5, y + 0.5, w - 1, h - 1, 4)
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, 180))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 10)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(r + 60, g + 60, b + 60, 240))
    nvgText(vg_, mx, y + h / 2, label)
    if onClick then
        hitAreas_[#hitAreas_ + 1] = { x = x, y = y, w = w, h = h, fn = onClick }
    end
    return y + h + 3
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param pct number
---@param label string|nil
---@param barR number
---@param barG number
---@param barB number
local function progressBar(x, y, w, h, pct, label, barR, barG, barB)
    pct = math.max(0, math.min(1, pct))
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, h / 2)
    nvgFillColor(vg_, nvgRGBA(15, 20, 35, 180))
    nvgFill(vg_)
    if pct > 0.01 then
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x, y, w * pct, h, h / 2)
        nvgFillColor(vg_, nvgRGBA(barR, barG, barB, 210))
        nvgFill(vg_)
    end
    if label then
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, h - 2)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(220, 230, 255, 210))
        nvgText(vg_, x + w / 2, y + h / 2, label)
    end
end

---@param dt number
function GalaxyUI.render(dt)
    dt = dt or 0
    PlanetPanel.Update(dt)
    screenW_, screenH_ = UICommon.getVirtualSize()
    local mpos = input:GetMousePosition()
    local dpr = graphics:GetDPR()
    cursorX_ = mpos.x / dpr / UICommon.uiScale
    cursorY_ = mpos.y / dpr / UICommon.uiScale
    UICommon.screenW = screenW_
    UICommon.screenH = screenH_
    UICommon.cursorX = cursorX_
    UICommon.cursorY = cursorY_

    if currentScene_ ~= "galaxy" then return end

    local state = CommonUI.getSharedState()
    state.fleetOverviewShow = fleetOverviewShow_
    state.fleetOverviewData = fleetOverviewData_
    state.dt = dt

    local banner = GalaxyHud.Render(state)
    if banner then CommonUI.showDailyChallengeHint(banner.challenge) end

    if CommonUI.getState("deployed") then
        GalaxyPanels.RenderIntel()
        NemesisRenderPanel.Render()
        GalaxyPanels.RenderCareerStats()
        GalaxyPanels.RenderSignal()
        GalaxyPanels.RenderQuest()
        CareerPanel.Render(dt)
        LogPanel.Render(completedGoals_UI_, exploreLog_)

        TechPanel.Render({
            selectedPlanet = selectedPlanet_,
            onResearch = onResearchCb_,
            techCompleteEffects = state.techCompleteEffects,
            onResearchSpeedAd = techSpeedAdLoading_ and nil or (techSpeedAdCb_ and function(onResult)
                techSpeedAdLoading_ = true
                techSpeedAdCb_(function(ok, msg)
                    techSpeedAdLoading_ = false
                    if onResult then onResult(ok, msg) end
                end)
            end),
        })

        GalaxyPanels.RenderMarket()
        GalaxyPanels.RenderBlackMarket()
        GalaxyPanels.RenderDiploRel()
        GalaxyPanels.RenderChallengeButtons()

        local garrisonInfo = getGarrisonInfoCb_ and getGarrisonInfoCb_(FleetPanel.GetActiveId()) or {}
        FleetPanel.Render({
            explorerColonizeMode = explorerColonizeMode_,
            onFleetSelect        = onFleetSelectCb_,
            onFleetMoveShip      = onFleetMoveShipCb_,
            onExplorerColonize   = onExplorerColonizeCb_,
            onAssignReserve      = onAssignReserveCb_,
            baseBonus            = rm_ and rm_.baseBonus or nil,
            onExplorerTask       = onExplorerTaskCb_,
            explorerTasks        = explorerTasks_UI_,
            garrisonedPlanet     = garrisonInfo.garrisonedPlanet,
            colonizedPlanets     = garrisonInfo.colonizedPlanets or {},
            onGarrisonFleet      = onGarrisonFleetCb_,
            onRecallGarrison     = onRecallGarrisonCb_,
            expeditions          = expeditions_UI_,
            pirateBases          = pirateBases_UI_,
            onLaunchExpedition   = onLaunchExpeditionCb_,
            lastExpedition       = lastExpedition_UI_,
        })

        if hasPlanet_ and selectedPlanet_ then
            if selectedPlanet_.isBase then
                local bph = BasePanel.Render(selectedPlanet_, {
                    onBuild = onBaseBuildCb_,
                    onCoreUpgrade = onCoreUpgradeCb_,
                    onSpeedUpBuild = onSpeedUpBuildCb_,
                    onSpeedUpBuildAd = speedUpAdLoading_ and nil or (speedUpAdCb_ and function(target)
                        speedUpAdLoading_ = true
                        speedUpAdCb_(target, function(ok, msg)
                            speedUpAdLoading_ = false
                        end)
                    end),
                    slotFlashTimer = 0,
                    slotFlashDuration = 0.6,
                    progressBar = progressBar,
                    shipyardMult = rm_ and rm_.baseBonus and rm_.baseBonus.shipyardMult or 1.0,
                    hasWarpGate = rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGatePrime or false,
                    warpCooldown = rm_ and rm_.baseBonus and rm_.baseBonus.warpGatePrimeCooldown or 0,
                    onWarpFleet = onWarpFleetCb_,
                })
                GalaxyPanels.RenderExchange(selectedPlanet_, bph)
                GalaxyPanels.RenderShipyard(selectedPlanet_)
            else
                PlanetPanel.Render(selectedPlanet_, {
                    onBuild = onBuildCb_,
                    onBatchUpgrade = onBatchUpgradeCb_,
                    onSpeedUpBuild = onSpeedUpBuildCb_,
                    onSpeedUpBuildAd = speedUpAdLoading_ and nil or (speedUpAdCb_ and function(target)
                        speedUpAdLoading_ = true
                        speedUpAdCb_(target, function(ok, msg)
                            speedUpAdLoading_ = false
                        end)
                    end),
                    progressBar = progressBar,
                    onTogglePriority = onTogglePriorityCb_,
                    isPriority = getIsPriorityCb_ and getIsPriorityCb_(selectedPlanet_),
                    onCancelQueued = onCancelQueuedCb_,
                    prodHistory = getPlanetProdHistoryCb_ and getPlanetProdHistoryCb_(selectedPlanet_.name),
                    onSendGift = onSendGiftCb_,
                    diplomacyState = getDiplomacyStateCb_ and getDiplomacyStateCb_(selectedPlanet_.id),
                    onActivateLongTrade = onActivateLongTradeCb_,
                    onSetSpec = onSetSpecCb_,
                    onUpgradePlanetCb = onUpgradePlanetCb_,
                })
                GalaxyPanels.RenderShipyard(selectedPlanet_)
            end
        end

        MegaPanel.Render({
            coreLevel = (GalaxyScene.GetBase and GalaxyScene.GetBase() or {}).coreLevel or 1,
            resources = rm_ and rm_.resources or {},
            buildMult = rm_ and rm_.baseBonus and rm_.baseBonus.buildMult or 1.0,
            onStartPhase = onMegaStartPhaseCb_,
        })

        LiveryPanel.Render()
        GalactopediaPanel.Render()
        LegacyPanel.Render()
        FormationEditor.Update(dt)
        FormationEditor.Render()
        FleetPanel.RenderNamingModal()
        EmpirePanel.Render(nil, nil, nil)
    end
end

---@param mx number
---@param my number
---@return boolean
function GalaxyUI.onClick(mx, my)
    for i = #hitAreas_, 1, -1 do
        local h = hitAreas_[i]
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
            if h.fn then h.fn() end
            return true
        end
    end
    return false
end

function GalaxyUI.refreshGalaxyHud()
    fleetOverviewShow_ = not fleetOverviewShow_
end

---@param key string
---@return any
function GalaxyUI.getState(key)
    if key == "selectedPlanet" then return selectedPlanet_ end
    if key == "hasPlanet" then return hasPlanet_ end
    if key == "currentScene" then return currentScene_ end
    if key == "endlessRound" then return endlessRound_ end
    if key == "exploreLog" then return exploreLog_ end
    if key == "completedGoals" then return completedGoals_UI_ end
    return nil
end

---@param round number
function GalaxyUI.setEndlessRound(round)
    endlessRound_ = round or 0
end

return GalaxyUI
