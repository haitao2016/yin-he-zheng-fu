---@diagnostic disable: missing-parameter
-- ============================================================================
-- game/GameUI.lua  -- 完整 HUD：纯 NanoVG 绘制，无 UI 库依赖
-- ============================================================================

local GameUI        = {}
local Audio         = require("game.AudioManager")
local UICommon      = require("game.ui.UICommon")
local NotifyPanel   = require("game.ui.NotifyPanel")
local FleetPanel    = require("game.ui.FleetPanel")
local TechPanel     = require("game.ui.TechPanel")
local PlanetPanel   = require("game.ui.PlanetPanel")
local BasePanel     = require("game.ui.BasePanel")
local TutorialSystem    = require("game.ui.TutorialSystem")
local SettingsPanel     = require("game.ui.SettingsPanel")
local TimeoutPanel      = require("game.ui.TimeoutPanel")
local AchievementPanel  = require("game.ui.AchievementPanel")
local EndGamePanel      = require("game.ui.EndGamePanel")
local Campaign          = require("game.CampaignSystem")
local NemesisSystem     = require("game.NemesisSystem")
local Commander         = require("game.CommanderSystem")  -- P1-3 V2.4
local QuestBoard        = require("game.QuestBoard")       -- P2-1 V2.4
local MegaPanel         = require("game.ui.MegaPanel")     -- P2-2 V2.4: 巨构工程面板
local LiveryPanel       = require("game.ui.LiveryPanel")   -- P2-3 V2.4: 舰队涂装面板
local GalactopediaPanel = require("game.ui.GalactopediaPanel") -- P3-1 V2.4: 银河百科面板
local GalaxyScene       = require("game.GalaxyScene")      -- P2-2 V2.4: base access
local EmpirePanel       = require("game.ui.EmpirePanel")       -- P1-3: 帝国运营总览
local LogPanel          = require("game.ui.LogPanel")          -- P1-3: 任务日志
local CareerPanel       = require("game.ui.CareerPanel")       -- P3-2: 生涯战绩全屏页
local NemesisRenderPanel = require("game.ui.NemesisRenderPanel") -- P1-2: 宿敌档案渲染
local ReplayPlayer       = require("game.ui.ReplayPlayer")       -- P3-2: 战斗回放播放器
local LegacyPanel        = require("game.ui.LegacyPanel")        -- P1-3 V2.5: 文明遗产面板
local FormationEditor    = require("game.ui.FormationEditor")    -- P2-1 V2.5: 阵型编辑器
local GalaxyHud          = require("game.ui.GalaxyHud")          -- P3-1b: 银河HUD（海盗预警/资源危机/舰队速览/日挑/联赛）
local GalaxyPanels       = require("game.ui.GalaxyPanels")       -- P3-1b: 银河面板集合（情报/信号/任务/市场/外交等）
local Overlays           = require("game.ui.Overlays")           -- P3-1b: 覆层（战役对话/事件弹窗/选卡）
local TopBar             = require("game.ui.TopBar")             -- P3-1b: 顶部资源栏渲染（拆分自 RenderTopBar）

-- ============================================================================
-- 通用常量
-- ============================================================================
local SIGNAL_CD = 5   -- 信号按钮冷却（秒），需与 GalaxyPanels.SIGNAL_CD 一致

-- ============================================================================
-- 颜色主题常量（避免散落的魔法数字）
-- ============================================================================
local C = {
    -- 面板背景
    panelBg       = {8,  12, 28,  220},
    panelBgDark   = {5,  15, 30,  248},
    panelBorder   = {60, 140, 255, 180},
    panelBorderDim= {60, 120, 220, 80},

    -- 文字
    textPrimary   = {200, 220, 255, 255},
    textSecondary = {120, 160, 200, 140},
    textTitle     = {100, 200, 255, 255},
    textSubtitle  = {160, 200, 255, 200},
    textMuted     = {100, 150, 255, 140},

    -- 状态色
    green         = {30,  180, 80,  220},
    greenDim      = {60,  140, 60,  180},
    greenText     = {160, 255, 160, 255},
    red           = {220, 50,  50,  240},
    redDim        = {200, 60,  60,  180},
    yellow        = {255, 220, 60,  255},
    yellowDim     = {255, 220, 80,  200},
    orange        = {255, 180, 60,  240},
    orangeDim     = {255, 180, 60,  220},

    -- 蓝色系（按钮/选中）
    blueBtnBg     = {20,  80,  180, 200},
    blueBtnBgDim  = {20,  40,  80,  160},
    blueBtnBorder = {80,  160, 255, 220},
    blueBtnBorderDim={60, 100, 180, 120},
    blueHighlight = {68,  136, 255, 140},
    blueDeep      = {30,  60,  100, 180},
    blueBright    = {80,  180, 255, 200},
    blueAccent    = {100, 170, 255, 230},
    blueNav       = {40,  120, 220, 200},
}

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_            = nil
local screenW_       = 800
local screenH_       = 600
local cursorX_       = 0    -- 当前鼠标位置（逻辑像素）
local cursorY_       = 0

-- 资源图标纹理句柄
local resIcons_      = {}   -- { minerals=h, energy=h, crystal=h, population=h, credits=h }

-- 数据依赖（由 Init 注入）
local rm_            = nil
local bs_            = nil   -- 行星建造系统
local bbs_           = nil   -- 基地建造系统（独立）
local rs_            = nil
local ms_            = nil
local player_        = nil
local spq_           = nil
local pirateAI_      = nil   -- P1-3: 海盗 AI（情报面板数据源）

-- 编队系统
local fm_                 = nil   -- FleetManager 引用
local shipyardCollapsed_  = true  -- 造船厂面板是否折叠（默认折叠）
local exchangeCollapsed_  = true  -- 互换中心面板是否折叠（默认折叠）
local shipyardBuilt_      = false -- 星际造船厂是否已建造

-- 回调
local onBuildCb_          = nil   -- 行星建造回调
local onBatchUpgradeCb_   = nil   -- P3-3.3: 批量升级回调
local onBaseBuildCb_      = nil   -- 基地建造回调（独立）
local onCoreUpgradeCb_    = nil   -- 核心等级升级回调
local onResearchCb_       = nil

local onExplorerColonizeCb_ = nil
local explorerColonizeMode_  = false   -- 高亮提示玩家点击未殖民星球
local onFleetSelectCb_    = nil
local onFleetMoveShipCb_  = nil
local onAssignReserveCb_  = nil
local onSpeedUpBuildCb_   = nil   -- 星币加速建造
local onBuyNuclearCb_     = nil   -- 星币购买核能
local onHarvestAllCb_       = nil   -- 全部征收回调
local onTogglePriorityCb_   = nil   -- P2-1: 殖民优先标记切换回调
local getIsPriorityCb_      = nil   -- P2-1: 查询是否标记 function(planet)->bool
local onCancelQueuedCb_     = nil   -- P1-3: 取消建造队列回调 function(qIdx, planet)
local onWarpFleetCb_        = nil   -- P1-2: 主曲速门瞬移回调 function(planet)

local onGarrisonFleetCb_    = nil   -- P2-1: 驻守编队 function(fleetId, planet)
local onRecallGarrisonCb_   = nil   -- P2-1: 召回驻守 function(fleetId)
local getGarrisonInfoCb_    = nil   -- P2-1: 查询驻守信息 function(fleetId)->{garrisonedPlanet, colonizedPlanets}
local getPlanetProdHistoryCb_ = nil -- P3-2: 查询星球产量历史 function(planetName)->{minerals,energy,crystal}
local onSendGiftCb_          = nil  -- P1-1: 外交送礼 function(planetId)
local getDiplomacyStateCb_   = nil  -- P1-1: 查询外交状态 function(planetId)->{factionKey,factionDef,favor,atWar,military}

local onSetSpecCb_           = nil  -- P2-3: 设置建筑专精 function(planetId, bldIdx, specKey)
local onUpgradePlanetCb_     = nil  -- P1-2: 升级星球等级 function(planet)
local onActivateLongTradeCb_ = nil  -- P2-2: 激活长期贸易协议 function(planetId)
local onLaunchExpeditionCb_  = nil  -- P1-2: 远征 function(fleetId, baseId)
local onMegaStartPhaseCb_    = nil  -- P2-2 V2.4: 巨构工程开始建造 function(megaId)
local expeditions_UI_        = {}   -- P1-2: 当前远征列表（从 Client 传入）
local pirateBases_UI_        = {}   -- P1-2: 已探明海盗基地列表
local lastExpedition_UI_     = {}   -- P3-3.1: 远征重复记忆 { [fleetId]=baseId }
local harvestAllCD_         = 0     -- 全部征收剩余冷却（秒）
local HARVEST_ALL_CD      = 60    -- 全部征收冷却时间（秒）
local getConquestProgress_ = nil  -- 返回 {colonized, total, piratesKilled, piratesTotal}

-- 海盗预警状态
local pirateWarningTime_  = math.huge  -- 最近一次进攻倒计时（秒），math.huge 表示无威胁
local PIRATE_WARN_THRESH  = 30         -- 倒计时 ≤ 30 秒时显示预警
local pirateWarnBlink_    = 0          -- 闪烁计时器

-- 资源危机预警状态
local RES_CRISIS_THRESHOLDS = {
    metal   = 200,   -- 金属 < 200 触发
    esource = 100,   -- 能源块 < 100 触发（P2-1 修正）
    nuclear = 80,    -- 核燃料 < 80 触发
}
-- P2-1: 每局只推送一次建议通知（进入危机首次），重开/新局时清空
local RES_CRISIS_ADVICE = {
    metal   = "建议升级矿场或征收更多殖民星球",
    esource = "建议研究高效炼化或建造能源站",
    nuclear = "建议研究深层采矿或升级精炼厂",
}
local resCrisisState_    = {}   -- key → true/false（当前是否危机）
local resCrisisNotified_ = {}   -- key → true（本局已通知，不重复推送）
local resCrisisBlink_    = 0    -- 全局闪烁计时器

-- P3-3.5: 舰队速览浮窗状态
local fleetOverviewShow_ = false
local fleetOverviewData_ = nil   -- FleetManager 引用

-- 场景状态
local currentScene_  = "galaxy"
local hasPlanet_     = false
local selectedPlanet_= nil
local endlessRound_  = 0      -- 无尽模式轮次（0=普通模式）

-- 游戏时间（通知时间戳用，同步给 NotifyPanel）
local gameTime_       = 0

-- 可点击区域列表（每帧重建）
local hitAreas_ = {}

-- 滚动区域列表（每帧重建）
local scrollAreas_ = {}

-- 触摸拖拽滚动状态
local touchDragActive_ = false
local touchDragId_     = 0
local touchDragLastY_  = 0
local touchDragScrollFn_ = nil



-- 核心升级槽位闪烁计时器（升级后亮0.6s）
local slotFlashTimer_ = 0
local SLOT_FLASH_DURATION = 0.6
-- 种子飞船是否已展开（展开前屏蔽大部分 UI 面板）
local deployed_ = false

-- 展开按钮回调（由 Client.lua 注入）
local deployCallback_ = nil





-- P1-3: 帝国运营总览面板



-- P1-2: 宿敌档案面板状态
local getColonizedPlanetsCb_ = nil    -- function() -> planets[]
local onBatchBuildCb_      = nil      -- function(buildingKey, checkedPlanets)
local onPlanetJumpCb_      = nil      -- function(planetName) 跳转到指定星球

-- ============================================================================
-- 资源数字滚动动画（P3-3）
-- displayRes_[res] = 当前显示值（向真实值平滑靠近）
-- flashRes_[res]   = {timer, dir} dir: 1=增加(绿), -1=减少(红)
-- ============================================================================
local displayRes_ = {}   -- 显示值（浮点，渲染时 floor）
local flashRes_   = {}   -- { timer=0.6, dir=1/-1 }
local SCROLL_SPEED_FACTOR = 8.0   -- 每秒追赶 (real-display)*factor
local FLASH_DURATION      = 0.55  -- 闪光持续秒数

-- P1-2: 资源趋势箭头
-- resTrendDir_[res]  = 1(涨) / -1(跌) / 0(平稳)
-- resTrendSample_[res] = 上次采样值
local resTrendDir_    = {}   -- 当前箭头方向
local resTrendSample_ = {}   -- 上次采样时的值
local resTrendTimer_  = 0    -- 距下次采样的倒计时
local RES_TREND_INTERVAL = 8.0   -- 采样间隔（秒）
local RES_TREND_THRESHOLD = 5    -- 变化量超过多少才显示箭头（避免噪音）

-- 按钮点击涟漪效果
-- ripples_[i] = { x, y, r, maxR, timer, maxTimer }
local ripples_         = {}
local RIPPLE_DURATION  = 0.35   -- 涟漪扩散时长（秒）
local RIPPLE_MAX_R     = 28     -- 最大涟漪半径（像素）

-- P1-2: 科技完成粒子特效
-- techCompleteEffects_[id] = { timer, maxTimer }
-- timer 递增到 maxTimer 时粒子消失
local techCompleteEffects_   = {}
local TECH_EFFECT_DURATION   = 2.2   -- 粒子动画持续时长（秒）

-- ============================================================================
-- 游戏时间限制（状态已移至 TimeoutPanel）
-- ============================================================================
-- 剩余在线时间（由 Client.lua 更新，秒）
local remainingTime_    = 7200    -- 默认2小时

-- P2-1: 每日挑战开局横幅
local dailyChallengeBanner_ = nil   -- nil 或 { challenge, timer, duration }
-- challenge = { restriction, boost, restrictDesc, boostDesc }

-- P1-3: 联赛模式 HUD 状态
local leagueHud_ = nil  -- nil 或 { rankIcon, rankName, weekKey, modLabel, bestScore }

-- EXPLORER 舰探索任务列表（由 Client.lua 通过 RefreshExplorerTasks 更新）
local explorerTasks_UI_ = {}
local onExplorerTaskCb_ = nil

-- P1-3: 任务日志面板状态


-- P3-2: 生涯战绩全屏页面
-- 探索日志（由 Client.lua 通过 GameUI.PushExploreLog 推送，保留最近 10 条）
local exploreLog_       = {}
-- 目标完成状态（由 Client.lua 通过 GameUI.SetCompletedGoals 同步）
local completedGoals_UI_ = {}

-- ============================================================================
-- 结算/排行榜/成就/设置（状态已移至各面板模块）
-- ============================================================================
-- 广告相关（建造加速）
local speedUpAdCb_      = nil   -- fn(target, onResult)，星币不足时免费完成
local speedUpAdLoading_ = false -- 广告播放中
-- 广告相关（科技研究加速）
local techSpeedAdCb_      = nil   -- fn(onResult)，看广告加速5分钟
local techSpeedAdLoading_ = false -- 广告播放中
-- 广告相关（中期资源补给）
local topBarAdCb_      = nil   -- fn(onResult)，看广告得资源包
local topBarAdCount_   = 0     -- 本局已观看次数
local topBarAdLoading_ = false -- 广告播放中
local TOP_BAR_AD_MAX   = 3     -- 每局最多看3次
-- 排行榜回调（由 Client.lua 注入，传递给 EndGamePanel）
local lbOnRequest_     = nil

-- ============================================================================
-- 通知系统
-- ============================================================================
function GameUI.Notify(msg, ntype)
    Audio.PlayNotify(ntype)
    NotifyPanel.Push(msg, ntype)
end

function GameUI.SetPirateWarning(minTime)
    pirateWarningTime_ = minTime or math.huge
end

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
            -- P0-2: 无尽挑战和每日挑战按钮
            GalaxyPanels.RenderChallengeButtons()
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
        -- 📋 日志按钮
        addHit(screenW_ - 138, 6, 28, 28, function()
            LogPanel.Toggle()
        end)
        -- 📊 战绩按钮
        addHit(screenW_ - 172, 6, 28, 28, function()
            statsVisible_ = not statsVisible_
        end)
        -- 📡 P3-1: 信号按钮
        addHit(screenW_ - 206, 6, 28, 28, function()
            if signalCooldown_ <= 0 then
                signalOpen_ = not signalOpen_
            end
        end)
        -- 🏛️ P1-3: 帝国总览按钮
        addHit(screenW_ - 240, 6, 28, 28, function()
            EmpirePanel.Toggle()
        end)
        -- ⚔ P1-2: 宿敌档案按钮
        addHit(screenW_ - 272, 6, 28, 28, function()
            NemesisRenderPanel.Toggle()
        end)
        -- 📌 P2-1: 任务板按钮
        addHit(screenW_ - 304, 6, 28, 28, function()
            questVisible_ = not questVisible_
        end)
        -- 🤝 P1-1: 外交关系网按钮
        addHit(screenW_ - 338, 6, 28, 28, function()
            diploRelVisible_ = not diploRelVisible_
        end)
        -- 🏗️ P2-2 V2.4: 巨构工程按钮（Lv7+可见）
        local megaBase2 = GalaxyScene.GetBase and GalaxyScene.GetBase()
        if megaBase2 and megaBase2.coreLevel >= 7 then
            addHit(screenW_ - 372, 6, 28, 28, function()
                MegaPanel.Toggle()
            end)
        end
        -- 🎨 P2-3 V2.4: 舰队涂装按钮
        addHit(screenW_ - 406, 6, 28, 28, function()
            -- 打开时刷新解锁上下文
            if not LiveryPanel.IsVisible() then
                LiveryPanel.SetContext({
                    achievements  = AchievementPanel.GetUnlockCount() or 0,
                    leagueRank    = 0,
                    crisisBeaten  = 0,
                    nemesisBeaten = NemesisSystem and NemesisSystem.GetDefeatedCount and NemesisSystem.GetDefeatedCount() or 0,
                    megaCompleted = 0,
                })
            end
            LiveryPanel.Toggle()
        end)
        -- 📖 P3-1 V2.4: 银河百科按钮
        addHit(screenW_ - 440, 6, 28, 28, function()
            GalactopediaPanel.Toggle()
        end)
        -- ⭐ P1-3 V2.5: 文明遗产按钮
        addHit(screenW_ - 474, 6, 28, 28, function()
            LegacyPanel.Toggle()
        end)
    end

    -- P3-3: FPS 计数器更新 & 渲染（最顶层叠加）
    SettingsPanel.UpdateFPS(dt)
    SettingsPanel.RenderFPS()
end

-- ============================================================================
-- Refresh 接口（供 main.lua 调用，更新缓存数据）
-- ============================================================================
function GameUI.RefreshResourceBar()
    -- 资源在 RenderTopBar 里实时读取，无需缓存
end

function GameUI.RefreshBlackMarketPanel()
    -- P2-2: 面板每帧读取 bm_ 状态，无需手动缓存刷新
end

function GameUI.RefreshPlanetPanel(planet)
    -- M1: 切换星球时重置面板状态，清除 planetBuildPending_ 残留
    -- L3: 同时重置 TechPanel 滚动位置，避免跨星球残留
    if planet ~= selectedPlanet_ then
        PlanetPanel.ResetScroll()
        TechPanel.ResetScroll()
    end
    selectedPlanet_ = planet
end

-- 强制刷新当前面板（广告奖励等场景下数据已改变但 selectedPlanet_ 引用未变）
function GameUI.ForceRefreshPanel(planet)
    -- 先置 nil 再赋值，确保渲染函数检测到"切换"并重新读取数据
    selectedPlanet_ = nil
    selectedPlanet_ = planet
end


function GameUI.RefreshShipyardPanel()
    -- 实时读取，无需缓存
end

-- 设置探索舰殖民模式（影响提示文字和储备面板高亮）
function GameUI.SetExplorerColonizeMode(active)
    explorerColonizeMode_ = active == true
end

-- 注入成就数据（由 Client.lua 在初始化/解锁时调用）
-- data: { {id, name, desc, category, unlocked}, ... }
-- total: 成就总数（含未解锁）
function GameUI.SetAchievements(data, total)
    AchievementPanel.SetData(data, total)
end

-- P2-3: 注入成就奖励兑换回调
function GameUI.SetRedeemCallback(fn)
    AchievementPanel.SetRedeemCallback(fn)
end

-- P2-3: 返回可兑换奖励数量（供外部读取）
function GameUI.GetRedeemableCount()
    return AchievementPanel.GetRedeemableCount()
end

-- 设置无尽征服模式当前轮次（0 = 普通模式，>0 = 无尽模式第N轮）
-- 由 Client.lua 在进入无尽模式、每轮开始时调用
function GameUI.SetEndlessRound(round)
    endlessRound_ = round or 0
end

--- P2-1: 显示每日挑战开局横幅（游戏开始时调用）
--- challenge = { restriction, boost, restrictDesc, boostDesc }
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
    -- P0-1: 同步已解锁科技表与 spq 判断（保持 UI/逻辑两边一致）
    if spq_ and rs_ then spq_.techUnlocked = rs_.unlocked or {} end
    UICommon.pirateAI      = pirateAI_   -- P1-3
    UICommon.resIcons      = resIcons_
    -- P0-5: 共享 GalaxyScene 引用供 GalaxyPanels 访问贸易状态
    UICommon.galaxyScene   = GalaxyScene
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
        -- P0-2: 无尽/每日挑战回调
        onEndlessChallengeCb  = GameUI.OpenEndlessModePanel,
        onDailyChallengeCb     = GameUI.OpenDailyChallengePanel,
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

-- P0-2: 打开无尽模式选择面板
function GameUI.OpenEndlessModePanel()
    local EndlessPanel = require("game.ui.EndlessPanel")
    EndlessPanel.Show()
end

-- P0-3: 打开每日挑战面板
function GameUI.OpenDailyChallengePanel()
    local ChallengePanel = require("game.ui.ChallengePanel")
    local panel = ChallengePanel.open()
    registerOverlay("dailyChallenge", function(vg) panel.draw(vg) end)
end

return GameUI
