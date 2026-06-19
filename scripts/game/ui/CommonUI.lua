local CommonUI = {}

local Audio       = require("game.AudioManager")
local UICommon    = require("game.ui.UICommon")
local NotifyPanel = require("game.ui.NotifyPanel")
local EndGamePanel = require("game.ui.EndGamePanel")
local SettingsPanel = require("game.ui.SettingsPanel")
local TimeoutPanel  = require("game.ui.TimeoutPanel")
local AchievementPanel = require("game.ui.AchievementPanel")
local ReplayPlayer   = require("game.ui.ReplayPlayer")
local GalaxyPanels   = require("game.ui.GalaxyPanels")
local Overlays       = require("game.ui.Overlays")
local TopBar         = require("game.ui.TopBar")
local TutorialSystem = require("game.ui.TutorialSystem")

local TOPBAR_H  = 44

local vg_            = nil
local screenW_       = 800
local screenH_       = 600

local resIcons_      = {}

local rm_            = nil
local bs_            = nil
local bbs_           = nil
local rs_            = nil
local ms_            = nil
local player_        = nil
local spq_           = nil

local displayRes_ = {}
local flashRes_   = {}
local SCROLL_SPEED_FACTOR = 8.0
local FLASH_DURATION      = 0.55

local resTrendDir_    = {}
local resTrendSample_ = {}
local resTrendTimer_  = 0
local RES_TREND_INTERVAL = 8.0
local RES_TREND_THRESHOLD = 5

local ripples_         = {}
local RIPPLE_DURATION  = 0.35
local RIPPLE_MAX_R     = 28

local techCompleteEffects_ = {}
local TECH_EFFECT_DURATION = 2.2

local pirateWarningTime_ = math.huge
local PIRATE_WARN_THRESH = 30
local pirateWarnBlink_   = 0

local RES_CRISIS_THRESHOLDS = {
    metal   = 200,
    esource = 100,
    nuclear = 80,
}
local RES_CRISIS_ADVICE = {
    metal   = "建议升级矿场或征收更多殖民星球",
    esource = "建议研究高效炼化或建造能源站",
    nuclear = "建议研究深层采矿或升级精炼厂",
}
local resCrisisState_    = {}
local resCrisisNotified_ = {}
local resCrisisBlink_    = 0

local slotFlashTimer_ = 0
local SLOT_FLASH_DURATION = 0.6

local remainingTime_  = 7200

local dailyChallengeBanner_ = nil
local leagueHud_ = nil

local topBarAdCb_      = nil
local topBarAdCount_   = 0
local topBarAdLoading_ = false
local TOP_BAR_AD_MAX   = 3

local harvestAllCD_    = 0
local HARVEST_ALL_CD   = 60
local getConquestProgress_ = nil
local onHarvestAllCb_  = nil

local SIGNAL_CD = 5
local statsVisible_ = false
local signalOpen_ = false
local signalCooldown_ = 0
local diploRelVisible_ = false
local questVisible_ = false

local deployed_ = false

local gameTime_ = 0

local hitAreas_ = {}
local scrollAreas_ = {}

local touchDragActive_ = false
local touchDragId_     = 0
local touchDragLastY_  = 0
local touchDragScrollFn_ = nil

local function clr(r,g,b,a) return nvgRGBA(r,g,b,a or 255) end
local function clrC(c) return nvgRGBA(c[1], c[2], c[3], c[4] or 255) end

local function panel(x, y, w, h, r, bg, border)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, r)
    nvgFillColor(vg_, nvgRGBA(bg[1],bg[2],bg[3],bg[4] or 230))
    nvgFill(vg_)
    if border then
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x+0.5, y+0.5, w-1, h-1, r)
        nvgStrokeColor(vg_, nvgRGBA(border[1],border[2],border[3],border[4] or 180))
        nvgStrokeWidth(vg_, 1.2)
        nvgStroke(vg_)
    end
end

local function text(x, y, str, size, r,g,b,a, align)
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, size)
    nvgTextAlign(vg_, align or (NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE))
    nvgFillColor(vg_, nvgRGBA(r,g,b,a or 255))
    nvgText(vg_, x, y, tostring(str))
end

local function addHit(x, y, w, h, fn)
    local cx, cy = x + w * 0.5, y + h * 0.5
    local wrapped = fn and function()
        Audio.Play(Audio.SFX.BTN_CLICK, 0.6)
        if #ripples_ < 8 then
            ripples_[#ripples_+1] = {
                x = cx, y = cy,
                maxR  = math.max(RIPPLE_MAX_R, math.max(w, h) * 0.5),
                timer = RIPPLE_DURATION,
            }
        end
        fn()
    end or nil
    hitAreas_[#hitAreas_+1] = { x=x, y=y, w=w, h=h, fn=wrapped }
end

local function addScroll(x, y, w, h, fn)
    scrollAreas_[#scrollAreas_+1] = { x=x, y=y, w=w, h=h, fn=fn }
end

function CommonUI.Notify(msg, ntype)
    Audio.PlayNotify(ntype)
    NotifyPanel.Push(msg, ntype)
end

---@param vg userdata
---@param sw number
---@param sh number
function CommonUI.init(vg, sw, sh)
    vg_ = vg
    screenW_ = sw or 800
    screenH_ = sh or 600
    resIcons_ = {}
    if vg_ then
        local f = NVG_IMAGE_PREMULTIPLIED
        resIcons_["minerals"]   = nvgCreateImage(vg_, "image/icon_minerals_20260511191023.png",  f)
        resIcons_["energy"]     = nvgCreateImage(vg_, "image/icon_energy_20260511190704.png",    f)
        resIcons_["crystal"]    = nvgCreateImage(vg_, "image/icon_crystal_20260511190706.png",   f)
        resIcons_["population"] = nvgCreateImage(vg_, "image/icon_population_20260511190825.png",f)
        resIcons_["credits"]    = nvgCreateImage(vg_, "image/icon_credits_20260511190705.png",   f)
        resIcons_["metal"]   = resIcons_["minerals"]
        resIcons_["esource"] = resIcons_["energy"]
        resIcons_["nuclear"] = resIcons_["crystal"]
    end
    UICommon.vg = vg_
    UICommon.bindFns({
        clr         = clr,
        clrC        = clrC,
        panel       = panel,
        text        = text,
        addHit      = addHit,
        addScroll   = addScroll,
    })
end

---@param data table
function CommonUI.setGameData(data)
    data = data or {}
    rm_      = data.rm
    bs_      = data.bs
    bbs_     = data.bbs
    rs_      = data.rs
    ms_      = data.ms
    player_  = data.player
    spq_     = data.spq
    UICommon.rm     = rm_
    UICommon.bs     = bs_
    UICommon.bbs    = bbs_
    UICommon.rs     = rs_
    UICommon.ms     = ms_
    UICommon.player = player_
    UICommon.spq    = spq_
    UICommon.resIcons = resIcons_
    getConquestProgress_ = data.getConquestProgress
    onHarvestAllCb_ = data.onHarvestAllCb
end

function CommonUI.resetPerRun()
    resCrisisNotified_ = {}
    resCrisisState_    = {}
    resTrendDir_    = {}
    resTrendSample_ = {}
    resTrendTimer_  = 0
    statsVisible_   = false
    signalOpen_     = false
    signalCooldown_ = 0
    topBarAdCount_  = 0
    topBarAdLoading_ = false
    displayRes_ = {}
    flashRes_   = {}
    ripples_    = {}
    techCompleteEffects_ = {}
end

function CommonUI.update(dt)
    gameTime_ = gameTime_ + dt
    UICommon.animUpdate(dt)
    EndGamePanel.Update(dt)
    ReplayPlayer.Update(dt)
    GalaxyPanels.Update(dt)
    Overlays.Update(dt)

    if pirateWarningTime_ <= PIRATE_WARN_THRESH then
        pirateWarnBlink_ = pirateWarnBlink_ + dt
    end

    if rm_ then
        resCrisisBlink_ = resCrisisBlink_ + dt
        for res, thresh in pairs(RES_CRISIS_THRESHOLDS) do
            local val = rm_.resources[res] or 0
            local isCrisis = val < thresh
            resCrisisState_[res] = isCrisis
            if isCrisis and not resCrisisNotified_[res] then
                resCrisisNotified_[res] = true
                local nameMap = { metal = "金属", esource = "能源块", nuclear = "核燃料" }
                local name = nameMap[res] or res
                local advice = RES_CRISIS_ADVICE[res] or "建议补充资源"
                CommonUI.Notify(string.format("⚠ %s不足（%d）\n%s", name, math.floor(val), advice), "error")
                Audio.Play(Audio.SFX.NOTIFY_WARN, 0.7)
            end
        end
    end

    if rm_ then
        resTrendTimer_ = resTrendTimer_ + dt
        if resTrendTimer_ >= RES_TREND_INTERVAL then
            resTrendTimer_ = 0
            if RES_ORDER then
                for _, res in ipairs(RES_ORDER) do
                    local cur = rm_.resources[res] or 0
                    local prev = resTrendSample_[res]
                    if prev then
                        local delta = cur - prev
                        if delta > RES_TREND_THRESHOLD then
                            resTrendDir_[res] = 1
                        elseif delta < -RES_TREND_THRESHOLD then
                            resTrendDir_[res] = -1
                        else
                            resTrendDir_[res] = 0
                        end
                    end
                    resTrendSample_[res] = cur
                end
            end
        end
    end

    if slotFlashTimer_ > 0 then
        slotFlashTimer_ = slotFlashTimer_ - dt
    end

    if harvestAllCD_ > 0 then
        harvestAllCD_ = math.max(0, harvestAllCD_ - dt)
    end

    NotifyPanel.Update(dt)
    NotifyPanel.SetGameTime(gameTime_)
    TutorialSystem.Update(dt)

    local n = #ripples_
    local i = 1
    while i <= n do
        ripples_[i].timer = ripples_[i].timer - dt
        if ripples_[i].timer <= 0 then
            ripples_[i] = ripples_[n]
            ripples_[n] = nil
            n = n - 1
        else
            i = i + 1
        end
    end

    if rm_ then
        local ALL_RES = { "metal", "esource", "nuclear", "minerals", "energy", "crystal" }
        for _, res in ipairs(ALL_RES) do
            local real = rm_.resources[res] or 0
            local disp = displayRes_[res] or real
            local diff = real - disp
            if math.abs(diff) < 0.5 then
                displayRes_[res] = real
            else
                local fl = flashRes_[res]
                if not fl or fl.timer <= 0 then
                    local dir = diff > 0 and 1 or -1
                    flashRes_[res] = { timer = FLASH_DURATION, dir = dir }
                end
                local step = diff * SCROLL_SPEED_FACTOR * dt
                if math.abs(step) < 1 then step = (diff > 0) and 1 or -1 end
                displayRes_[res] = disp + step
            end
            if flashRes_[res] then
                flashRes_[res].timer = flashRes_[res].timer - dt
            end
        end
    end

    for id, eff in pairs(techCompleteEffects_) do
        eff.timer = eff.timer + dt
        if eff.timer >= TECH_EFFECT_DURATION then
            techCompleteEffects_[id] = nil
        end
    end
end

---@param techId string
function CommonUI.triggerTechComplete(techId)
    techCompleteEffects_[techId] = { timer = 0 }
end

---@param flag boolean
function CommonUI.setDeployed(flag)
    deployed_ = flag == true
end

---@param seconds number
function CommonUI.setRemainingTime(seconds)
    remainingTime_ = math.max(0, seconds)
end

---@param minTime number
function CommonUI.setPirateWarning(minTime)
    pirateWarningTime_ = minTime or math.huge
end

---@param challenge table
function CommonUI.showDailyChallengeHint(challenge)
    if not challenge then return end
    local dur = 5.5
    dailyChallengeBanner_ = { challenge = challenge, timer = dur, duration = dur }
end

---@param data table
function CommonUI.setLeagueHud(data)
    leagueHud_ = data
end

---@param fn function
function CommonUI.setTopBarAdCallback(fn)
    topBarAdCb_ = fn
end

function CommonUI.resetTopBarAdCount()
    topBarAdCount_ = 0
    topBarAdLoading_ = false
end

---@return table
function CommonUI.getSharedState()
    return {
        displayRes           = displayRes_,
        flashRes             = flashRes_,
        FLASH_DURATION       = FLASH_DURATION,
        resCrisisState       = resCrisisState_,
        resCrisisBlink       = resCrisisBlink_,
        resTrendDir          = resTrendDir_,
        statsVisible         = statsVisible_,
        signalOpen           = signalOpen_,
        signalCooldown       = signalCooldown_,
        SIGNAL_CD            = SIGNAL_CD,
        diploRelVisible      = diploRelVisible_,
        questVisible         = questVisible_,
        deployed             = deployed_,
        currentScene         = "galaxy",
        harvestAllCD         = harvestAllCD_,
        HARVEST_ALL_CD       = HARVEST_ALL_CD,
        onHarvestAll         = function()
            harvestAllCD_ = HARVEST_ALL_CD
            if onHarvestAllCb_ then onHarvestAllCb_() end
        end,
        getConquestProgress  = getConquestProgress_,
        remainingTime        = remainingTime_,
        pirateWarningTime    = pirateWarningTime_,
        pirateWarnBlink      = pirateWarnBlink_,
        dailyChallengeBanner = dailyChallengeBanner_,
        leagueHud            = leagueHud_,
        topBarAdCb           = topBarAdCb_,
        topBarAdCount        = topBarAdCount_,
        topBarAdLoading      = topBarAdLoading_,
        TOP_BAR_AD_MAX       = TOP_BAR_AD_MAX,
        techCompleteEffects  = techCompleteEffects_,
    }
end

---@param key string
---@return any
function CommonUI.getState(key)
    if key == "statsVisible" then return statsVisible_ end
    if key == "signalOpen" then return signalOpen_ end
    if key == "signalCooldown" then return signalCooldown_ end
    if key == "diploRelVisible" then return diploRelVisible_ end
    if key == "questVisible" then return questVisible_ end
    if key == "deployed" then return deployed_ end
    if key == "dailyChallengeBanner" then return dailyChallengeBanner_ end
    if key == "leagueHud" then return leagueHud_ end
    return nil
end

---@param key string
---@param value any
function CommonUI.toggleFlag(key)
    if key == "statsVisible" then statsVisible_ = not statsVisible_; return end
    if key == "signalOpen" then
        if signalCooldown_ <= 0 then signalOpen_ = not signalOpen_ end
        return
    end
    if key == "questVisible" then questVisible_ = not questVisible_; return end
    if key == "diploRelVisible" then diploRelVisible_ = not diploRelVisible_; return end
end

---@param vg userdata
function CommonUI.renderTopBar()
    if not rm_ or not player_ then return end
    screenW_, screenH_ = UICommon.getVirtualSize()

    hitAreas_    = {}
    scrollAreas_ = {}

    TopBar.Render(CommonUI.getSharedState())
end

---@param text string
---@param level string|nil
function CommonUI.pushNotification(text, level)
    CommonUI.Notify(text, level)
end

---@param mx number
---@param my number
---@param delta number
---@return boolean
function CommonUI.onScroll(mx, my, delta)
    for i = #scrollAreas_, 1, -1 do
        local s = scrollAreas_[i]
        if mx >= s.x and mx <= s.x+s.w and my >= s.y and my <= s.y+s.h then
            if s.fn then s.fn(delta) end
            return true
        end
    end
    return false
end

---@param id number
---@param rawX number
---@param rawY number
---@return boolean
function CommonUI.onTouchBegin(id, rawX, rawY)
    local dpr = graphics:GetDPR()
    local mx = rawX / dpr
    local my = rawY / dpr
    if SettingsPanel.IsVisible() then
        if SettingsPanel.OnTouchBegin(id, mx, my) then return true end
    end
    for i = #scrollAreas_, 1, -1 do
        local s = scrollAreas_[i]
        if mx >= s.x and mx <= s.x+s.w and my >= s.y and my <= s.y+s.h then
            touchDragActive_   = true
            touchDragId_       = id
            touchDragLastY_    = my
            touchDragScrollFn_ = s.fn
            return true
        end
    end
    return false
end

---@param id number
---@param rawX number
---@param rawY number
---@return boolean
function CommonUI.onTouchMove(id, rawX, rawY)
    if SettingsPanel.OnTouchMove(id, rawX / graphics:GetDPR()) then return true end
    if not touchDragActive_ or touchDragId_ ~= id then return false end
    local dpr = graphics:GetDPR()
    local my = rawY / dpr
    local dy = my - touchDragLastY_
    touchDragLastY_ = my
    if touchDragScrollFn_ and dy ~= 0 then
        touchDragScrollFn_(dy * 0.8)
    end
    return true
end

---@param id number
---@param rawX number
---@param rawY number
---@return boolean
function CommonUI.onTouchEnd(id, rawX, rawY)
    if touchDragId_ == id then
        touchDragActive_   = false
        touchDragId_       = 0
        touchDragScrollFn_ = nil
    end
    if SettingsPanel.OnTouchEnd(id) then return true end
    local dpr = graphics:GetDPR()
    local mx = rawX / dpr
    local my = rawY / dpr
    for i = #hitAreas_, 1, -1 do
        local h = hitAreas_[i]
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
            if h.fn then h.fn() end
            return true
        end
    end
    return false
end

---@param mx number
---@param my number
---@return boolean
function CommonUI.onClick(mx, my)
    for i = #hitAreas_, 1, -1 do
        local h = hitAreas_[i]
        if mx >= h.x and mx <= h.x+h.w and my >= h.y and my <= h.y+h.h then
            if h.fn then h.fn() end
            return true
        end
    end
    return false
end

function CommonUI.renderRipples()
    if #ripples_ == 0 then return end
    for _, rp in ipairs(ripples_) do
        local t = 1 - rp.timer / RIPPLE_DURATION
        local r = rp.maxR * t
        local alpha = math.floor(120 * (1 - t))
        nvgBeginPath(vg_); nvgCircle(vg_, rp.x, rp.y, r)
        nvgStrokeColor(vg_, nvgRGBA(160, 200, 255, alpha))
        nvgStrokeWidth(vg_, math.max(0.5, 2.5 * (1 - t)))
        nvgStroke(vg_)
    end
end

function CommonUI.renderGlobalPopups()
    NotifyPanel.RenderCenter()
    TutorialSystem.Render()
    Overlays.RenderCampaignDialogue()
    Overlays.RenderEventPopup()
    TimeoutPanel.Render()
    Overlays.RenderCardDraft()
    EndGamePanel.Render()
    EndGamePanel.RenderLeaderboard()
    ReplayPlayer.Render()
    AchievementPanel.Render()
    SettingsPanel.Render()
end

function CommonUI.clearAll()
    displayRes_ = {}
    flashRes_   = {}
    ripples_    = {}
    Overlays.ClearEventPopup()
end

function CommonUI.setVg(vg, w, h)
    vg_ = vg
    screenW_ = w or screenW_
    screenH_ = h or screenH_
end

return CommonUI
