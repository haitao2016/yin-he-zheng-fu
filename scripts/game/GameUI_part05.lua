-- Auto-split from GameUI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function GameUI.UpdateNotifications(dt)
    gameTime_ = gameTime_ + dt
    -- 结算/排行榜动画计时
    EndGamePanel.Update(dt)
    -- P3-2: 战斗回放播放器计时
    ReplayPlayer.Update(dt)
    -- P3-1b: 子模块更新
    GalaxyPanels.Update(dt)
    Overlays.Update(dt)
    -- 海盗预警闪烁
    if pirateWarningTime_ <= PIRATE_WARN_THRESH then
        pirateWarnBlink_ = pirateWarnBlink_ + dt
    end
    -- 资源危机预警检测
    if rm_ then
        resCrisisBlink_ = resCrisisBlink_ + dt
        local RES_NAMES = { metal="金属", esource="能源块", nuclear="核燃料" }
        for res, thresh in pairs(RES_CRISIS_THRESHOLDS) do
            local val      = rm_.resources[res] or 0
            local isCrisis = val < thresh
            resCrisisState_[res] = isCrisis
            -- P2-1: 首次进入危机时推送一次建议通知，本局不再重复
            if isCrisis and not resCrisisNotified_[res] then
                resCrisisNotified_[res] = true
                local name   = RES_NAMES[res] or res
                local advice = RES_CRISIS_ADVICE[res] or "建议补充资源"
                GameUI.Notify(
                    string.format("⚠ %s不足（%d）\n%s", name, math.floor(val), advice),
                    "error")
                -- P3-3.2: 资源危机音效
                Audio.Play(Audio.SFX.NOTIFY_WARN, 0.7)
            end
        end
    end
    -- P1-2: 资源趋势采样（每 RES_TREND_INTERVAL 秒）
    if rm_ then
        resTrendTimer_ = resTrendTimer_ + dt
        if resTrendTimer_ >= RES_TREND_INTERVAL then
            resTrendTimer_ = 0
            for _, res in ipairs(RES_ORDER) do
                local cur  = rm_.resources[res] or 0
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

    if slotFlashTimer_ > 0 then
        slotFlashTimer_ = slotFlashTimer_ - dt
    end
    -- 全部征收冷却倒计时
    if harvestAllCD_ > 0 then
        harvestAllCD_ = math.max(0, harvestAllCD_ - dt)
    end

    -- 结算界面进场动画（由 EndGamePanel.Update 内部处理）
    NotifyPanel.Update(dt)
    NotifyPanel.SetGameTime(gameTime_)
    -- 教程动画更新
    TutorialSystem.Update(dt)
    -- 涟漪动画更新（swap-remove O(1)，避免 table.remove 的 O(n) 移位）
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
    -- 资源数字滚动动画更新
    if rm_ then
        local ALL_RES = { "metal", "esource", "nuclear", "minerals", "energy", "crystal" }
        for _, res in ipairs(ALL_RES) do
            local real = rm_.resources[res] or 0
            local disp = displayRes_[res] or real
            local diff = real - disp
            if math.abs(diff) < 0.5 then
                displayRes_[res] = real  -- 足够接近时直接对齐
            else
                -- 方向检测：触发闪光
                local fl = flashRes_[res]
                if not fl or fl.timer <= 0 then
                    local dir = diff > 0 and 1 or -1
                    flashRes_[res] = { timer = FLASH_DURATION, dir = dir }
                end
                -- 指数追赶：大差距快、小差距慢
                local step = diff * SCROLL_SPEED_FACTOR * dt
                -- 保证每帧至少追赶 1 单位防止卡死
                if math.abs(step) < 1 then step = (diff > 0) and 1 or -1 end
                displayRes_[res] = disp + step
            end
            -- 倒计时闪光
            if flashRes_[res] then
                flashRes_[res].timer = flashRes_[res].timer - dt
            end
        end
    end
    -- P1-2: 科技完成粒子特效计时器推进
    for id, eff in pairs(techCompleteEffects_) do
        eff.timer = eff.timer + dt
        if eff.timer >= TECH_EFFECT_DURATION then
            techCompleteEffects_[id] = nil
        end
    end
end

-- ============================================================================
-- P1-2: 科技完成粒子特效触发接口
-- ============================================================================
--- 触发指定科技节点的完成粒子爆炸特效
--- @param techId string 科技 ID
function GameUI.TriggerTechComplete(techId)
    techCompleteEffects_[techId] = { timer = 0 }
end

-- ============================================================================
-- 工具函数
-- ============================================================================
local function clr(r,g,b,a) return nvgRGBA(r,g,b,a or 255) end
-- 从颜色常量表生成 nvgColor，例: clrC(C.panelBg)
local function clrC(c) return nvgRGBA(c[1], c[2], c[3], c[4] or 255) end

local function panel(x, y, w, h, r, bg, border)
    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, r)
    nvgFillColor(vg_, nvgRGBA(bg[1],bg[2],bg[3],bg[4] or 230))
    nvgFill(vg_)
    -- 边框
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

-- 注册可点击区域（自动注入按钮点击音效 + 涟漪效果）
local function addHit(x, y, w, h, fn)
    local cx, cy = x + w * 0.5, y + h * 0.5   -- 按钮中心（用于涟漪）
    local wrapped = fn and function()
        Audio.Play(Audio.SFX.BTN_CLICK, 0.6)
        -- 生成涟漪（限制最多同时 8 个，防止内存堆积）
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

-- 注册滚动区域
local function addScroll(x, y, w, h, fn)
    scrollAreas_[#scrollAreas_+1] = { x=x, y=y, w=w, h=h, fn=fn }
end

-- 滚动事件分发（供 Client.lua 调用）
function GameUI.OnScroll(mx, my, delta)
    for i = #scrollAreas_, 1, -1 do
        local s = scrollAreas_[i]
        if mx >= s.x and mx <= s.x+s.w and my >= s.y and my <= s.y+s.h then
            if s.fn then s.fn(delta) end
            return true
        end
    end
    return false
end

-- 触摸拖拽滚动接口（供 Client.lua 调用）
function GameUI.OnTouchBegin(id, rawX, rawY)
    local dpr = graphics:GetDPR()
    local mx = rawX / dpr
    local my = rawY / dpr
    -- 设置面板滑块触摸拖拽（委托给 SettingsPanel）
    if SettingsPanel.IsVisible() then
        if SettingsPanel.OnTouchBegin(id, mx, my) then
            return true
        end
    end
    -- 检测是否在某个滚动区域内
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

function GameUI.OnTouchMove(id, rawX, rawY)
    -- 设置面板滑块触摸拖拽跟随（委托给 SettingsPanel）
    if SettingsPanel.OnTouchMove(id, rawX / graphics:GetDPR()) then
        return true
    end
    if not touchDragActive_ or touchDragId_ ~= id then return false end
    local dpr = graphics:GetDPR()
    local my = rawY / dpr
    local dy = my - touchDragLastY_
    touchDragLastY_ = my
    if touchDragScrollFn_ and dy ~= 0 then
        -- delta 与鼠标滚轮方向一致：向下拖动 → 正 delta（向上滚内容）
        touchDragScrollFn_(dy * 0.8)
    end
    return true
end

function GameUI.OnTouchEnd(id, rawX, rawY)
    local consumed = false

    -- 清理滚动拖拽状态
    if touchDragId_ == id then
        touchDragActive_   = false
        touchDragId_       = 0
        touchDragScrollFn_ = nil
    end

    -- 结束设置面板滑块触摸拖拽（委托给 SettingsPanel）
    if SettingsPanel.OnTouchEnd(id) then
        return true
    end

    -- 点击（非拖拽）→ 检查命中区域，消费事件
    local dpr = graphics:GetDPR()
    local mx  = rawX / dpr
    local my  = rawY / dpr
    for i = #hitAreas_, 1, -1 do
        local h = hitAreas_[i]
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
            if h.fn then h.fn() end
            consumed = true
            break
        end
    end

    return consumed
end

-- 绘制小按钮，返回底部 y
local function drawButton(x, y, w, h, label, r,g,b, onClick)
    local mx = x+w/2
    panel(x, y, w, h, 4, {r,g,b,60}, {r,g,b,180})
    text(mx, y+h/2, label, 10, r+60,g+60,b+60,240, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    if onClick then addHit(x, y, w, h, onClick) end
    return y + h + 3
end

-- 进度条
local function progressBar(x, y, w, h, pct, label, barR,barG,barB)
    pct = math.max(0, math.min(1, pct))
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, h/2)
    nvgFillColor(vg_, clr(15,20,35,180))
    nvgFill(vg_)
    if pct > 0.01 then
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x, y, w*pct, h, h/2)
        nvgFillColor(vg_, clr(barR,barG,barB,210))
        nvgFill(vg_)
    end
    if label then
        nvgFontFace(vg_, "sans"); nvgFontSize(vg_, h-2)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, clr(220,230,255,210))
        nvgText(vg_, x+w/2, y+h/2, label)
    end
end

-- ============================================================================
-- 布局常量（按 867×390 20:9 手机横屏优化）
-- TopBar: 44px，面板顶部: 48px
-- ============================================================================
local TOPBAR_H  = 44    -- 顶部资源栏高度
local PANEL_TOP = 48    -- 所有面板的顶部起始 y（TopBar 下方留 4px 间隔）

-- ============================================================================
-- 1. 顶部资源栏 + EXP（手机紧凑版，高度 44px）
-- ============================================================================
function GameUI.RenderTopBar()
    if not rm_ or not player_ then return end
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- 每帧开始清空可点击/滚动区域（TopBar 是每帧第一个渲染的 UI）
    hitAreas_    = {}
    scrollAreas_ = {}

    TopBar.Render({
        displayRes       = displayRes_,
        flashRes         = flashRes_,
        FLASH_DURATION   = FLASH_DURATION,
        resCrisisState   = resCrisisState_,
        resCrisisBlink   = resCrisisBlink_,
        resTrendDir      = resTrendDir_,
        statsVisible     = statsVisible_,
        signalOpen       = signalOpen_,
        signalCooldown   = signalCooldown_,
        SIGNAL_CD        = SIGNAL_CD,
        diploRelVisible  = diploRelVisible_,
        questVisible     = questVisible_,
        deployed         = deployed_,
        currentScene     = currentScene_,
        harvestAllCD     = harvestAllCD_,
        HARVEST_ALL_CD   = HARVEST_ALL_CD,
        onHarvestAll     = function()
            harvestAllCD_ = HARVEST_ALL_CD
            if onHarvestAllCb_ then onHarvestAllCb_() end
        end,
        getConquestProgress = getConquestProgress_,
        remainingTime    = remainingTime_,
        endlessRound     = endlessRound_,
        completedGoals   = completedGoals_UI_,
        topBarAdCb       = topBarAdCb_,
        topBarAdCount    = topBarAdCount_,
        topBarAdLoading  = topBarAdLoading_,
        TOP_BAR_AD_MAX   = TOP_BAR_AD_MAX,
    })
end

-- ============================================================================
-- 2. 场景标题（资源栏下方）
-- ============================================================================
function GameUI.RenderSceneTitle()
    screenW_, screenH_ = UICommon.getVirtualSize()
    local cy = TOPBAR_H + 8
    nvgFontFace(vg_, "sans"); nvgFontSize(vg_, 10)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, clr(100,150,255,160))
    local hint = explorerColonizeMode_
        and "探索舰就绪 — 点击未探索星球执行探索  |  [ESC] 取消"
        or  "拖动探索  |  滚轮缩放"
    nvgText(vg_, screenW_/2, cy, hint)
end

-- ============================================================================
-- [P3-1b] 以下 16 个 render 函数已提取到子模块:
--   GalaxyHud.lua     : renderFleetOverview, renderResourceCrisisFlash,
--                       renderPirateWarning, renderDailyChallengeBanner, renderLeagueHud
--   GalaxyPanels.lua  : renderSignalPanel, renderQuestPanel, renderMarketPanel,
--                       renderBlackMarketPanel, renderDiploRelPanel, renderExchangePanel,
--                       renderShipyardPanel, renderIntelPanel, renderCareerStatsPanel
--   Overlays.lua      : renderCampaignDialogue, renderEventPopup
-- ============================================================================
--- 外部接口：显示事件弹窗
---@param ev     table   事件数据（来自 GalaxyScene 的随机事件节点）
---@param onChoice function(choiceIdx) 玩家选择后的回调
function GameUI.ShowEventPopup(ev, onChoice)
    Overlays.ShowEventPopup(ev, onChoice)
end

--- P1-1 V2.4: 外交事件弹窗（适配 ShowEventPopup 格式）
---@param ev table  来自 DiplomacySystem._generateDiploEvent 的事件数据
function GameUI.ShowDiploEvent(ev)
    Overlays.ShowDiploEvent(ev)
end

-- ============================================================================
-- 主渲染入口（每帧从 main.lua 调用）
-- ============================================================================
function GameUI.RenderHUD(dt)
    dt = dt or 0
    -- P3-2: 更新 PlanetPanel 微动画计时器
    PlanetPanel.Update(dt)
    screenW_, screenH_ = UICommon.getVirtualSize()
    -- 更新鼠标位置（用于按钮悬停判断）
    local mpos = input:GetMousePosition()
    local dpr  = graphics:GetDPR()
    cursorX_ = mpos.x / dpr / UICommon.uiScale
    cursorY_ = mpos.y / dpr / UICommon.uiScale
    -- 每帧同步至 UICommon（教程弹窗在 deployed_ 前也需要读取）
    UICommon.screenW = screenW_
    UICommon.screenH = screenH_
    UICommon.cursorX = cursorX_
    UICommon.cursorY = cursorY_

    if currentScene_ == "galaxy" then
        -- P3-1b: GalaxyHud 统一渲染（含 deployHint / pirateWarning / crisisFlash / fleetOverview / banner / league）
        dailyChallengeBanner_ = GalaxyHud.Render({
            deployed             = deployed_,
            deployCallback       = deployCallback_,
            fleetOverviewShow    = fleetOverviewShow_,
            fleetOverviewData    = fleetOverviewData_,
            resCrisisState       = resCrisisState_,
            resCrisisBlink       = resCrisisBlink_,
            pirateWarningTime    = pirateWarningTime_,
            pirateWarnBlink      = pirateWarnBlink_,
            dailyChallengeBanner = dailyChallengeBanner_,
            leagueHud            = leagueHud_,
            dt                   = dt,
        }) or dailyChallengeBanner_

        if deployed_ then
            GalaxyPanels.RenderIntel()
            NemesisRenderPanel.Render()  -- P1-2: 宿敌档案面板
            GalaxyPanels.RenderCareerStats()
            GalaxyPanels.RenderSignal()
            GalaxyPanels.RenderQuest()
            CareerPanel.Render(dt)       -- P3-2: 生涯战绩全屏页面
            LogPanel.Render(completedGoals_UI_, exploreLog_)  -- P1-3: 任务日志面板
            TechPanel.Render({
                selectedPlanet       = selectedPlanet_,
                onResearch           = onResearchCb_,
                techCompleteEffects  = techCompleteEffects_,  -- P1-2: 粒子特效状态
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
            -- P2-1: 查询当前活动编队的驻守信息
            local garrisonInfo_ = getGarrisonInfoCb_ and getGarrisonInfoCb_(FleetPanel.GetActiveId()) or {}
            FleetPanel.Render({
                explorerColonizeMode = explorerColonizeMode_,
                onFleetSelect        = onFleetSelectCb_,
                onFleetMoveShip      = onFleetMoveShipCb_,
                onExplorerColonize   = onExplorerColonizeCb_,
                onAssignReserve      = onAssignReserveCb_,
                baseBonus            = rm_ and rm_.baseBonus or nil,
                onExplorerTask       = onExplorerTaskCb_,
                explorerTasks        = explorerTasks_UI_,
                garrisonedPlanet     = garrisonInfo_.garrisonedPlanet,
                colonizedPlanets     = garrisonInfo_.colonizedPlanets or {},
                onGarrisonFleet      = onGarrisonFleetCb_,
                onRecallGarrison     = onRecallGarrisonCb_,
                -- P1-2: 远征系统
                expeditions          = expeditions_UI_,
                pirateBases          = pirateBases_UI_,
                onLaunchExpedition   = onLaunchExpeditionCb_,
                lastExpedition       = lastExpedition_UI_,  -- P3-3.1: 远征重复记忆
            })
            if hasPlanet_ and selectedPlanet_ then
                if selectedPlanet_.isBase then
                    local bph = BasePanel.Render(selectedPlanet_, {
                        onBuild          = onBaseBuildCb_,
                        onCoreUpgrade    = onCoreUpgradeCb_,
                        onSpeedUpBuild   = onSpeedUpBuildCb_,
                        onSpeedUpBuildAd = speedUpAdLoading_ and nil or (speedUpAdCb_ and function(target)
                            speedUpAdLoading_ = true
                            speedUpAdCb_(target, function(ok, msg)
                                speedUpAdLoading_ = false
                            end)
                        end),
                        slotFlashTimer   = slotFlashTimer_,
                        slotFlashDuration= SLOT_FLASH_DURATION,
                        progressBar      = progressBar,
                        shipyardMult     = rm_ and rm_.baseBonus and rm_.baseBonus.shipyardMult or 1.0,
                        -- P1-2 WARP_GATE_PRIME
                        hasWarpGate      = rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGatePrime or false,
                        warpCooldown     = rm_ and rm_.baseBonus and rm_.baseBonus.warpGatePrimeCooldown or 0,
                        onWarpFleet      = onWarpFleetCb_,
                    })
                    GalaxyPanels.RenderExchange(selectedPlanet_, bph)
                    GalaxyPanels.RenderShipyard(selectedPlanet_)
                else
                    PlanetPanel.Render(selectedPlanet_, {
                        onBuild           = onBuildCb_,
                        onBatchUpgrade    = onBatchUpgradeCb_,  -- P3-3.3
                        onSpeedUpBuild    = onSpeedUpBuildCb_,
                        onSpeedUpBuildAd  = speedUpAdLoading_ and nil or (speedUpAdCb_ and function(target)
                            speedUpAdLoading_ = true
                            speedUpAdCb_(target, function(ok, msg)
                                speedUpAdLoading_ = false
                            end)
                        end),
                        progressBar       = progressBar,
                        onTogglePriority  = onTogglePriorityCb_,
                        isPriority        = getIsPriorityCb_ and getIsPriorityCb_(selectedPlanet_),
                        onCancelQueued    = onCancelQueuedCb_,  -- P1-3
                        prodHistory       = getPlanetProdHistoryCb_ and getPlanetProdHistoryCb_(selectedPlanet_.name), -- P3-2
                        onSendGift           = onSendGiftCb_,      -- P1-1
                        diplomacyState       = getDiplomacyStateCb_ and getDiplomacyStateCb_(selectedPlanet_.id), -- P1-1
                        onActivateLongTrade  = onActivateLongTradeCb_, -- P2-2
                        onSetSpec            = onSetSpecCb_,       -- P2-3
                        onUpgradePlanetCb    = onUpgradePlanetCb_, -- P1-2
                    })
                    GalaxyPanels.RenderShipyard(selectedPlanet_)
                end
            end
            -- P2-2 V2.4: 巨构工程面板（模态覆盖）
            MegaPanel.Render({
                coreLevel   = (GalaxyScene.GetBase and GalaxyScene.GetBase() or {}).coreLevel or 1,
                resources   = rm_ and rm_.resources or {},
                buildMult   = rm_ and rm_.baseBonus and rm_.baseBonus.buildMult or 1.0,
                onStartPhase = onMegaStartPhaseCb_,
            })
            -- P2-3 V2.4: 舰队涂装面板（模态覆盖）
            LiveryPanel.Render()
            -- P3-1 V2.4: 银河百科面板（模态覆盖）
            GalactopediaPanel.Render()
            -- P1-3 V2.5: 文明遗产面板（模态覆盖）
            LegacyPanel.Render()
            -- P2-1 V2.5: 阵型编辑器面板（模态覆盖）
            FormationEditor.Update(dt)
            FormationEditor.Render()
            -- P2-2a V2.5: 舰队命名模态面板
            FleetPanel.RenderNamingModal()
            -- P1-3: 帝国运营总览面板（全屏覆盖，置于最顶层）
            EmpirePanel.Render(getColonizedPlanetsCb_, onPlanetJumpCb_, onBatchBuildCb_)
        end
    end

    -- 通知中心面板（覆盖其他面板，在超时层之前）
    NotifyPanel.RenderCenter()

    -- 新手教程弹窗（在通知之后渲染，确保最高层级）
    TutorialSystem.Render()

    -- P2-2: 战役剧情对话框（在教程之后、事件弹窗之前）
    Overlays.RenderCampaignDialogue()

    -- 星图随机事件弹窗（覆盖在教程之后）
    Overlays.RenderEventPopup()

    -- 超时覆盖层
    TimeoutPanel.Render()
    -- P2-1: 轮间选卡覆盖层（在超时层之后，结算层之前）
    Overlays.RenderCardDraft()
    -- 结算覆盖层（最顶层，覆盖超时层）
    EndGamePanel.Render()
    -- 排行榜浮层（覆盖在结算层之上）
    EndGamePanel.RenderLeaderboard()
    -- P3-2: 战斗回放播放器（全屏覆盖，高于结算层）
    ReplayPlayer.Render()
    -- 成就面板（高于结算层，低于设置层）
    AchievementPanel.Render()
    -- 设置面板（最顶层，任何时候均可打开）
    SettingsPanel.Render()
    -- 涟漪反馈（最顶层叠加，不受任何面板遮挡）
    if #ripples_ > 0 then
        for _, rp in ipairs(ripples_) do
            local t    = 1 - rp.timer / RIPPLE_DURATION  -- 0→1
            local r    = rp.maxR * t
            local alpha = math.floor(120 * (1 - t))
            nvgBeginPath(vg_)
            nvgCircle(vg_, rp.x, rp.y, r)
            nvgStrokeColor(vg_, nvgRGBA(160, 200, 255, alpha))
            nvgStrokeWidth(vg_, math.max(0.5, 2.5 * (1 - t)))
            nvgStroke(vg_)
        end
    end

    -- ── 中期资源补给广告按钮（底部居中浮动，最多3次/局）──
    if deployed_ and topBarAdCb_ and topBarAdCount_ < TOP_BAR_AD_MAX
       and currentScene_ == "galaxy" and not EndGamePanel.IsActive() then
        local abW, abH = 152, 22
        local abX = math.floor(screenW_ / 2 - abW / 2)
        local abY = screenH_ - 32
        if not topBarAdLoading_ then
            local remain = TOP_BAR_AD_MAX - topBarAdCount_
            -- 轻微脉动边框
            local pulse = math.abs(math.sin(os.clock() * 1.8))
            local brdA  = math.floor(140 + 80 * pulse)
            nvgBeginPath(vg_); nvgRoundedRect(vg_, abX, abY, abW, abH, 5)
            nvgFillColor(vg_, nvgRGBA(0, 55, 30, 210)); nvgFill(vg_)
            nvgBeginPath(vg_); nvgRoundedRect(vg_, abX+0.5, abY+0.5, abW-1, abH-1, 5)
            nvgStrokeColor(vg_, nvgRGBA(0, 210, 110, brdA))
            nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)
            nvgFontFace(vg_, "sans"); nvgFontSize(vg_, 9)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(80, 255, 160, 255))
            nvgText(vg_, abX + abW/2, abY + abH/2,
                "🎬 看广告得资源补给 ×" .. remain)
            addHit(abX, abY, abW, abH, function()
                if topBarAdCb_ and not topBarAdLoading_ and topBarAdCount_ < TOP_BAR_AD_MAX then
                    topBarAdLoading_ = true
                    topBarAdCb_(function(ok)
                        topBarAdLoading_ = false
                        if ok then topBarAdCount_ = topBarAdCount_ + 1 end
                    end)
                end
            end)
        end
    end

    -- 顶栏按钮命中区：在所有面板之后注册，确保最高优先级（不被任何面板遮挡）
    -- 设置面板/成就面板打开时全屏遮罩已覆盖，无需额外处理
    if not SettingsPanel.IsVisible() and not AchievementPanel.IsVisible() then
        -- 铃铛按钮
        addHit(screenW_ - 36, 6, 28, 28, function() NotifyPanel.Toggle() end)
        -- 设置按钮（扩大热区到 36×36，中心不变）
        addHit(screenW_ - 76, 2, 36, 36, function()
            SettingsPanel.Toggle()
        end)
        -- 成就按钮
        addHit(screenW_ - 104, 6, 28, 28, function()
            AchievementPanel.Toggle()
        end)
