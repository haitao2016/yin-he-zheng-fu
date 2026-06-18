-- Auto-split from GameUI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function GameUI.ShowDailyChallengeHint(challenge)
    if not challenge then return end
    local dur = 5.5
    dailyChallengeBanner_ = { challenge = challenge, timer = dur, duration = dur }
end

-- P1-3: 设置联赛 HUD 数据（进入联赛模式时调用）
function GameUI.SetLeagueHud(data)
    leagueHud_ = data   -- { rankIcon, rankName, weekKey, modLabel, bestScore } 或 nil 关闭
end

-- P2-1: 展示无尽模式选卡面板（委托 Overlays）
function GameUI.ShowCardDraft(cards, onSelect)
    Overlays.ShowCardDraft(cards, onSelect)
end

-- P2-1: 隐藏选卡面板（委托 Overlays）
function GameUI.HideCardDraft()
    Overlays.HideCardDraft()
end

-- 刷新探索任务列表（由 Client.lua 在任务启动/完成时调用）
function GameUI.RefreshExplorerTasks(tasks)
    explorerTasks_UI_ = tasks or {}
end

-- P1-3: 推送一条探索完成日志（由 Client.lua 在 updateExplorerTasks 任务完成时调用）
-- entry: { icon=string, label=string, rewardStr=string, timeStr=string }
function GameUI.PushExploreLog(entry)
    table.insert(exploreLog_, 1, entry)  -- 最新的排最前
    if #exploreLog_ > 20 then
        table.remove(exploreLog_)        -- 只保留最近 20 条
    end
end

-- P1-3: 同步已完成目标集合（由 Client.lua 在 checkStageGoals 后调用）
-- completed: { [goalId] = true, ... }
function GameUI.SetCompletedGoals(completed)
    completedGoals_UI_ = completed or {}
end

-- P2-1: 同步生涯战绩数据到 UI（由 Client.lua 在游戏结束/场景初始化时调用）
function GameUI.SetCareerStats(stats)
    if type(stats) ~= "table" then return end
    GalaxyPanels.SetCareerStats(stats)   -- HUD 面板内部存储
    EndGamePanel.SetCareerStats(stats)   -- P3-1: 同步生涯数据到个人主页弹窗
    CareerPanel.SetStats(stats)          -- P3-2: 同步生涯数据到全屏战绩页面
end

-- ============================================================================
-- 场景切换
-- ============================================================================
function GameUI.ShowScene(scene, hasPlanet)
    currentScene_ = scene
    hasPlanet_    = hasPlanet == true
    NemesisRenderPanel.Hide()
end

-- ============================================================================
-- 点击处理（供 main.lua 转发鼠标事件）
-- ============================================================================
function GameUI.OnClick(mx, my)
    for i = #hitAreas_, 1, -1 do   -- 后绘制的优先（最顶层）
        local h = hitAreas_[i]
        if mx >= h.x and mx <= h.x+h.w and my >= h.y and my <= h.y+h.h then
            if h.fn then h.fn() end
            return true  -- 消费事件
        end
    end
    return false
end

-- ============================================================================
-- 初始化 / 销毁
-- ============================================================================
function GameUI.Init(opts)
    vg_            = opts.vg
    rm_            = opts.rm
    bs_            = opts.bs
    bbs_           = opts.bbs
    rs_            = opts.rs
    ms_            = opts.ms
    player_        = opts.player
    spq_           = opts.spq
    onBuildCb_          = opts.onBuildCb
    onBatchUpgradeCb_   = opts.onBatchUpgradeCb  -- P3-3.3
    onBaseBuildCb_      = opts.onBaseBuildCb
    onCoreUpgradeCb_    = opts.onCoreUpgradeCb
    onResearchCb_       = opts.onResearchCb
    onMarketCb_         = opts.onMarketCb
    bm_                 = opts.bm               -- P2-2: 黑市走私网络
    onBlackMarketCb_    = opts.onBlackMarketCb   -- P2-2: 黑市回调
    onExchangeCb_       = opts.onExchangeCb
    onShipQueueCb_          = opts.onShipQueueCb
    onShipCancelCb_         = opts.onShipCancelCb
    onShipPromoteCb_        = opts.onShipPromoteCb
    onExplorerColonizeCb_   = opts.onExplorerColonizeCb
    onExplorerTaskCb_       = opts.onExplorerTaskCb
    explorerTasks_UI_       = opts.explorerTasks or {}
    fm_                 = opts.fm
    pirateAI_           = opts.pirateAI    -- P1-3: 情报面板
    onFleetSelectCb_    = opts.onFleetSelectCb
    onFleetMoveShipCb_  = opts.onFleetMoveShipCb
    onAssignReserveCb_  = opts.onAssignReserveCb
    onSpeedUpBuildCb_      = opts.onSpeedUpBuildCb
    onBuyNuclearCb_        = opts.onBuyNuclearCb
    onHarvestAllCb_        = opts.onHarvestAllCb
    onTogglePriorityCb_    = opts.onTogglePriorityCb   -- P2-1
    getIsPriorityCb_       = opts.getIsPriorityCb       -- P2-1: 查询函数 function(planet)->bool
    onCancelQueuedCb_      = opts.onCancelQueuedCb      -- P1-3: 取消建造队列
    onWarpFleetCb_         = opts.onWarpFleetCb         -- P1-2: 主曲速门瞬移
    onSendSignalCb_        = opts.onSendSignalCb        -- P3-1: 快捷信号
    onGarrisonFleetCb_     = opts.onGarrisonFleetCb     -- P2-1: 驻守编队
    onRecallGarrisonCb_    = opts.onRecallGarrisonCb    -- P2-1: 召回驻守
    getGarrisonInfoCb_     = opts.getGarrisonInfoCb     -- P2-1: 查询驻守信息
    getPlanetProdHistoryCb_ = opts.getPlanetProdHistoryCb -- P3-2: 查询星球产量历史
    onSendGiftCb_           = opts.onSendGift            -- P1-1: 外交送礼
    getDiplomacyStateCb_    = opts.getDiplomacyState     -- P1-1: 查询外交状态
    getDiploRelationsCb_    = opts.getDiploRelations     -- P1-1 V2.4
    onActivateIntelCb_      = opts.onActivateIntel       -- P1-1 V2.4
    onActivateAllianceCb_   = opts.onActivateAlliance    -- P1-1 V2.4
    onActivateBlockadeCb_   = opts.onActivateBlockade    -- P1-1 V2.4
    onActivateMediationCb_  = opts.onActivateMediation   -- P1-1 V2.4
    onDiploEventChoiceCb_   = opts.onDiploEventChoice    -- P1-1 V2.4
    onSetSpecCb_            = opts.onSetSpec             -- P2-3: 设置建筑专精
    onUpgradePlanetCb_      = opts.onUpgradePlanetCb    -- P1-2: 升级星球等级
    onActivateLongTradeCb_  = opts.onActivateLongTrade  -- P2-2: 激活长期贸易协议
    onLaunchExpeditionCb_   = opts.onLaunchExpedition   -- P1-2: 远征
    onMegaStartPhaseCb_    = opts.onMegaStartPhase    -- P2-2 V2.4: 巨构工程
    getConquestProgress_   = opts.getConquestProgress
    onCampaignDialogueDone_ = opts.onCampaignDialogueDone  -- P2-2: 战役对话完毕
    getColonizedPlanetsCb_ = opts.getColonizedPlanets   -- P1-3: 帝国面板
    onBatchBuildCb_        = opts.onBatchBuild           -- P1-3: 批量建造
    onPlanetJumpCb_        = opts.onPlanetJump           -- P1-3: 跳转星球
    lbOnRequest_           = opts.onShowLeaderboard
    if opts.fm then
        FleetPanel.SetActiveId(1)
    end

    -- 初始化面板模块
    SettingsPanel.SetAudio(Audio)
    SettingsPanel.Load()
    EndGamePanel.SetNotifyFn(GameUI.Notify)
    EndGamePanel.SetLeaderboardCallback(opts.onShowLeaderboard)

    -- 创建字体（GameUI 使用 main 传入的 vg_，只需注册字体）
    nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 加载资源图标（同时为精炼资源键建立别名）
    local f = NVG_IMAGE_PREMULTIPLIED
    resIcons_["minerals"]   = nvgCreateImage(vg_, "image/icon_minerals_20260511191023.png",  f)
    resIcons_["energy"]     = nvgCreateImage(vg_, "image/icon_energy_20260511190704.png",    f)
    resIcons_["crystal"]    = nvgCreateImage(vg_, "image/icon_crystal_20260511190706.png",   f)
    resIcons_["population"] = nvgCreateImage(vg_, "image/icon_population_20260511190825.png",f)
    resIcons_["credits"]    = nvgCreateImage(vg_, "image/icon_credits_20260511190705.png",   f)
    -- 精炼资源复用原矿图标
    resIcons_["metal"]   = resIcons_["minerals"]
    resIcons_["esource"] = resIcons_["energy"]
    resIcons_["nuclear"] = resIcons_["crystal"]

    -- P2-1: 每局开始重置危机通知标记，确保新游戏能再次提示
    resCrisisNotified_ = {}
    resCrisisState_    = {}
    -- P1-2: 重置趋势采样（新局资源重置，旧趋势无效）
    resTrendDir_    = {}
    resTrendSample_ = {}
    resTrendTimer_  = 0
    -- P1-3: 重置日志面板状态（新局开始时清空）
    LogPanel.Reset()
    exploreLog_         = {}
    completedGoals_UI_  = {}
    -- P2-1: 重置战绩面板开合状态（数据保留，面板默认关闭）
    statsVisible_       = false
    -- P3-1: 重置信号面板状态
    signalOpen_         = false
    signalCooldown_     = 0
    -- P1-3: 重置帝国面板状态
    EmpirePanel.Reset()

    -- 同步共享上下文供 UI 子模块使用
    UICommon.vg            = vg_
    UICommon.screenW       = screenW_
    UICommon.screenH       = screenH_
    UICommon.rm            = rm_
    UICommon.bs            = bs_
    UICommon.bbs           = bbs_
    UICommon.rs            = rs_
    UICommon.ms            = ms_
    UICommon.player        = player_
    UICommon.fm            = fm_
    UICommon.spq           = spq_
    UICommon.pirateAI      = pirateAI_   -- P1-3
    UICommon.resIcons      = resIcons_
    UICommon.bindFns({
        clr         = clr,
        clrC        = clrC,
        panel       = panel,
        text        = text,
        addHit      = addHit,
        addScroll   = addScroll,
        drawButton  = drawButton,
        progressBar = progressBar,
    })

    -- P3-1b: 初始化子模块
    GalaxyPanels.Init({
        onMarketCb            = onMarketCb_,
        onBlackMarketCb       = onBlackMarketCb_,
        onExchangeCb          = onExchangeCb_,
        onShipQueueCb         = onShipQueueCb_,
        onShipCancelCb        = onShipCancelCb_,
        onShipPromoteCb       = onShipPromoteCb_,
        getDiploRelationsCb   = getDiploRelationsCb_,
        onActivateIntelCb     = onActivateIntelCb_,
        onActivateAllianceCb  = onActivateAllianceCb_,
        onActivateBlockadeCb  = onActivateBlockadeCb_,
        onActivateMediationCb = onActivateMediationCb_,
        onSendSignalCb        = onSendSignalCb_,
        notifyFn              = GameUI.Notify,
    })
    Overlays.Init({
        onCampaignDialogueDone = onCampaignDialogueDone_,
        onDiploEventChoice     = onDiploEventChoiceCb_,
    })

    print("[GameUI] 初始化完成（纯NanoVG模式）")
end

function GameUI.Shutdown()
    -- 清空动画状态，防止旧数据干扰下一局
    displayRes_ = {}
    flashRes_   = {}
    ripples_    = {}
    Overlays.ClearEventPopup()
    print("[GameUI] 已关闭")
end

-- 星际造船厂建造完成后调用，解锁编队管理面板
function GameUI.SetShipyardBuilt(built)
    shipyardBuilt_ = built == true
end

-- 更新编队面板数据（由 main.lua 在舰船建造完成/编队切换时调用）
function GameUI.RefreshFleetPanel(fm, activeId)
    fm_ = fm
    UICommon.fm = fm
    if activeId then
        FleetPanel.SetActiveId(activeId)
    end
end

--- P1-2: 更新远征数据（由 Client.lua 每帧调用）
function GameUI.SetExpeditions(exps, bases, lastExp)
    expeditions_UI_ = exps or {}
    pirateBases_UI_ = bases or {}
    lastExpedition_UI_ = lastExp or {}
end

--- 同步地图选中编队（由 Client.lua 在 GalaxyScene.onFleetSelect 回调中调用）
function GameUI.SetMapSelectedFleet(fleetId)
    FleetPanel.SetMapSelected(fleetId)
end

-- 储备池有变化时刷新（fm 已是引用，直接重绘即可）
function GameUI.RefreshReservePanel(fm)
    if fm then fm_ = fm end
end

-- 种子飞船展开完毕后调用，解锁全部 UI 面板
function GameUI.SetDeployed(flag)
    deployed_ = flag == true
    if deployed_ then
        -- 展开基地后触发后续教程步骤
        TutorialSystem.TriggerDeployed()
    end
end

--- P2-2a: 舰队命名输入转发（供 Client.lua 事件路由调用）
function GameUI.IsFleetNaming() return FleetPanel.IsNaming() end
function GameUI.OnFleetNamingText(text) FleetPanel.OnTextInput(text) end
function GameUI.OnFleetNamingBackspace() FleetPanel.OnBackspace() end
function GameUI.OnFleetNamingEnter() FleetPanel.OnEnter() end

--- P3-3.5: 设置舰队速览浮窗显示/隐藏
function GameUI.SetFleetOverview(show, fleetMgr)
    fleetOverviewShow_ = show
    fleetOverviewData_ = fleetMgr
end

--- 显示游戏结算界面
---@param gameType string  "win" | "lose"
---@param stats    table   { playTime, colonized, piratesKilled, rank, level }
---@param onRetry  function 点击"再来一局"回调
function GameUI.ShowEndGame(gameType, stats, onRetry)
    EndGamePanel.Show(gameType, stats, onRetry)
end

--- 隐藏结算界面（重置状态）
function GameUI.HideEndGame()
    EndGamePanel.Hide()
    -- 新局开始时重置中期资源广告计数
    topBarAdCount_      = 0
    topBarAdLoading_    = false
    speedUpAdLoading_   = false
    techSpeedAdLoading_ = false
end

--- 注入广告回调（由 Client.lua 调用）
--- @param fn function  fn(onResult) — onResult(success, msg) 在广告结束后被调用
function GameUI.SetAdCallback(fn)
    EndGamePanel.SetAdCallback(fn)
end

--- 注入建造加速广告回调（星币不足时免费完成建造）
--- @param fn function  fn(target, onResult) — target 为建造目标（星球/基地）
function GameUI.SetSpeedUpAdCallback(fn)
    speedUpAdCb_ = fn
end

--- 注入科技研究加速广告回调（看广告加速5分钟）
--- @param fn function  fn(onResult)
function GameUI.SetTechSpeedAdCallback(fn)
    techSpeedAdCb_ = fn
end

--- 注入中期资源补给广告回调（每局最多3次）
--- @param fn function  fn(onResult)
function GameUI.SetTopBarAdCallback(fn)
    topBarAdCb_ = fn
end

-- ============================================================================
-- 教程系统接口
-- ============================================================================
--- 恢复教程存档数据（登录/云存档时调用）
function GameUI.TutorialDeserialize(list)
    TutorialSystem.Deserialize(list)
end

--- 获取教程存档数据（保存时调用）
function GameUI.TutorialSerialize()
    return TutorialSystem.Serialize()
end

--- 触发游戏开始阶段的教程步骤
function GameUI.TutorialTriggerStart()
    TutorialSystem.TriggerStart()
end

-- 注册"在此展开基地"按钮的点击回调（由 Client.lua 调用）
function GameUI.SetDeployCallback(fn)
    deployCallback_ = fn
end

-- 更新剩余游戏时间（秒），由 Client.lua 每帧调用
function GameUI.SetRemainingTime(seconds)
    remainingTime_ = math.max(0, seconds)
end

-- 显示/隐藏超时覆盖层
-- adCount: 剩余可看广告次数
-- onWatch: 点击"看广告"按钮的回调
function GameUI.ShowTimeoutScreen(adCount, onWatch)
    TimeoutPanel.Show(adCount, onWatch)
end

-- 更新超时面板中的广告次数（看完广告后调用）
function GameUI.UpdateTimeoutAdCount(adCount)
    TimeoutPanel.UpdateAdCount(adCount)
end

-- 隐藏超时覆盖层（如广告续时成功后调用）
function GameUI.HideTimeoutScreen()
    TimeoutPanel.Hide()
end

-- TechPanel 每帧重绘，无需显式刷新；保留接口避免调用方报错
function GameUI.RefreshTechPanel() end

function GameUI.SetVg(vg, w, h)
    vg_ = vg; screenW_ = w; screenH_ = h
end

-- P3-2: 打开/关闭生涯战绩全屏页面
function GameUI.ShowCareerPage()
    CareerPanel.Show()
    statsVisible_   = false   -- 关闭小浮动面板，避免遮挡
end

function GameUI.HideCareerPage()
    CareerPanel.Hide()
end

-- P1-3: 切换帝国运营总览面板
function GameUI.ToggleEmpirePanel()
    EmpirePanel.Toggle()
end

-- P1-3 V2.5: 切换文明遗产面板
function GameUI.ToggleLegacyPanel()
    LegacyPanel.Toggle()
end

-- P1-2 V2.4: 终局危机面板（复用 eventPopup_ 渲染通道）
---@param crisis table  来自 GalaxyEvents.GetEndgameCrisis() 的数据
---@param onChoice function|nil  玩家做出选择后的回调(choiceIdx)
function GameUI.ShowEndgameCrisisPanel(crisis, onChoice)
    if not crisis then return end
    local r, g, b = crisis.color[1], crisis.color[2], crisis.color[3]
    local phaseLabel = string.format("阶段 %d/%d — %s", crisis.phase, crisis.totalPhases, crisis.phaseName)
    local timerStr   = string.format("⏱ 剩余 %ds", math.floor(crisis.phaseTimer or 0))
    local desc = crisis.phaseDesc .. "\n\n" .. timerStr

    -- 将 crisis.choices 适配为 eventPopup 格式
    local popupChoices = {}
    for _, ch in ipairs(crisis.choices or {}) do
        local costStr = ""
        if ch.cost then
            local parts = {}
            for k, v in pairs(ch.cost) do
                if v > 0 then parts[#parts + 1] = k .. "×" .. v end
            end
            if #parts > 0 then costStr = " [" .. table.concat(parts, ", ") .. "]" end
        end
        popupChoices[#popupChoices + 1] = { text = ch.text .. costStr }
    end

    local adapted = {
        color   = {r, g, b},
        icon    = crisis.icon,
        label   = crisis.name .. " — " .. phaseLabel,
        desc    = desc,
        choices = popupChoices,
    }
    GameUI.ShowEventPopup(adapted, onChoice)
end

function GameUI.RenderProgressBars(selectedPlanet)
end

return GameUI
