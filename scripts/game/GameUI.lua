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
local onBaseBuildCb_      = nil   -- 基地建造回调（独立）
local onCoreUpgradeCb_    = nil   -- 核心等级升级回调
local onResearchCb_       = nil
local onMarketCb_         = nil
local onExchangeCb_       = nil   -- 资源互换回调 function(fromRes, toRes)
local onShipQueueCb_      = nil
local onShipCancelCb_     = nil
local onShipPromoteCb_    = nil
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
local onSendSignalCb_       = nil   -- P3-1: 发送快捷信号回调 function(signal)
local onGarrisonFleetCb_    = nil   -- P2-1: 驻守编队 function(fleetId, planet)
local onRecallGarrisonCb_   = nil   -- P2-1: 召回驻守 function(fleetId)
local getGarrisonInfoCb_    = nil   -- P2-1: 查询驻守信息 function(fleetId)->{garrisonedPlanet, colonizedPlanets}
local getPlanetProdHistoryCb_ = nil -- P3-2: 查询星球产量历史 function(planetName)->{minerals,energy,crystal}
local onSendGiftCb_          = nil  -- P1-1: 外交送礼 function(planetId)
local getDiplomacyStateCb_   = nil  -- P1-1: 查询外交状态 function(planetId)->{factionKey,factionDef,favor,atWar,military}
local onSetSpecCb_           = nil  -- P2-3: 设置建筑专精 function(planetId, bldIdx, specKey)
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

-- 场景状态
local currentScene_  = "galaxy"
local hasPlanet_     = false
local selectedPlanet_= nil

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

-- 面板折叠状态
local marketCollapsed_ = false

-- 核心升级槽位闪烁计时器（升级后亮0.6s）
local slotFlashTimer_ = 0
local SLOT_FLASH_DURATION = 0.6
-- 种子飞船是否已展开（展开前屏蔽大部分 UI 面板）
local deployed_ = false

-- 展开按钮回调（由 Client.lua 注入）
local deployCallback_ = nil

-- 星图随机事件弹窗
-- eventPopup_ = { ev={...}, onChoice=fn } | nil
local eventPopup_ = nil

-- P3-1: 快捷信号系统
local signalOpen_  = false   -- 面板是否展开
local signalCooldown_ = 0    -- 发送冷却（秒），防止频繁刷屏
local SIGNAL_CD    = 5       -- 冷却时间 5s
local QUICK_SIGNALS = {
    { icon = "🚨", label = "需要支援！",   color = {220, 60,  60},  type = "error"   },
    { icon = "⚔️", label = "发起进攻！",   color = {255, 140, 30},  type = "warn"    },
    { icon = "🛡️", label = "全力防守！",   color = {60,  140, 255}, type = "info"    },
    { icon = "💰", label = "资源短缺",     color = {255, 210, 50},  type = "warn"    },
    { icon = "🔬", label = "科技突破！",   color = {180, 100, 255}, type = "success" },
    { icon = "🚀", label = "舰队集结！",   color = {80,  220, 200}, type = "info"    },
    { icon = "👀", label = "海盗来袭！",   color = {255, 80,  80},  type = "error"   },
    { icon = "✅", label = "一切就绪！",   color = {60,  210, 100}, type = "success" },
}

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

-- 无尽征服模式当前轮次（0=普通模式，>0=无尽模式第N轮）
local endlessRound_     = 0

-- P2-1: 轮间选卡面板状态
local cardDraft_ = {
    visible   = false,
    cards     = {},       -- [{key, icon, label, desc, rarity}]
    onSelect  = nil,      -- function(cardKey)
    hoverIdx  = 0,        -- 鼠标悬停的卡牌索引
    animT     = 0,        -- 入场动画计时器
}

-- EXPLORER 舰探索任务列表（由 Client.lua 通过 RefreshExplorerTasks 更新）
local explorerTasks_UI_ = {}
local onExplorerTaskCb_ = nil

-- P1-3: 任务日志面板状态
local logVisible_       = false   -- 面板是否打开
local logTab_           = "goals" -- "goals" | "explore"
local logScroll_        = 0       -- 探索记录 tab 的滚动偏移

-- P2-1: 生涯战绩面板状态
local statsVisible_     = false
local careerStats_UI_   = {
    totalGames=0, totalWins=0, bestWave=0,
    totalKills=0, totalColonies=0, bestMvpShip="", playtime=0,
}
-- P3-2: 生涯战绩全屏页面
local careerPageOpen_   = false
local careerPageAnim_   = 0.0   -- 0→1 入场动画进度
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
    -- P2-1: 选卡面板入场动画
    if cardDraft_.visible then
        cardDraft_.animT = math.min(1.0, cardDraft_.animT + dt * 3.0)
        cardDraft_.runT  = (cardDraft_.runT or 0) + dt  -- P2-1 V2.0: 粒子动画累计时间
    end
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
    -- P3-1: 信号发送冷却倒计时
    if signalCooldown_ > 0 then
        signalCooldown_ = math.max(0, signalCooldown_ - dt)
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

    -- EXP 条（最顶部细线，2px）
    local expNeeded = player_.level * EXP_PER_LEVEL
    local expPct    = math.min(1, player_.exp / expNeeded)
    nvgBeginPath(vg_); nvgRect(vg_, 0, 0, screenW_, 2)
    nvgFillColor(vg_, clr(15,15,35,200)); nvgFill(vg_)
    if expPct > 0.01 then
        nvgBeginPath(vg_); nvgRect(vg_, 0, 0, screenW_*expPct, 2)
        nvgFillColor(vg_, clr(50,180,255,230)); nvgFill(vg_)
    end

    -- 顶部背景条（44px 紧凑版）
    panel(0, 2, screenW_, TOPBAR_H - 2, 0, {0,4,16,220}, {50,80,180,70})

    local RAW_KEYS = { metal="minerals", esource="energy", nuclear="crystal" }
    local mult = rm_.refineryMult or 0
    local eBlockRate    = 3.0 * mult
    local esourceRate   = eBlockRate / 2.0

    -- 布局：[原矿3列] [精炼区130px] [星币+玩家+铃铛260px]
    local REFINED_W = 130
    local RIGHT_W   = 270
    local cols      = #RES_ORDER
    local colW      = (screenW_ - RIGHT_W - REFINED_W) / cols
    local rowMid    = 2 + (TOPBAR_H - 2) / 2   -- 垂直居中 y ≈ 23

    -- 原矿3列（两行：名称 + 数量/速率）
    for i, res in ipairs(RES_ORDER) do
        local c      = RES_COLORS[res]
        local rawKey = RAW_KEYS[res]
        -- 使用滚动显示值（rawKey 对应 minerals/energy/crystal）
        local rawVal  = math.floor(displayRes_[rawKey] or rm_.resources[rawKey] or 0)
        local rawRate = rm_.rates[rawKey] or 0
        local bx  = 8 + (i-1) * colW

        local iconH = resIcons_[res]
        if iconH and iconH >= 0 then
            local paint = nvgImagePattern(vg_, bx, rowMid - 7, 14, 14, 0, iconH, 1.0)
            nvgBeginPath(vg_); nvgRect(vg_, bx, rowMid - 7, 14, 14)
            nvgFillPaint(vg_, paint); nvgFill(vg_)
        end

        local tx = bx + 17
        local rateStr = mult > 0 and string.format("+%.0f/s", rawRate) or "待炼"
        -- 闪光颜色：增加→绿，减少→橙
        local fl = flashRes_[rawKey]
        local valR, valG, valB = 220, 220, 220
        if fl and fl.timer > 0 then
            local t = fl.timer / FLASH_DURATION
            if fl.dir > 0 then
                valR = math.floor(valR * (1-t) + 100 * t)
                valG = math.floor(valG * (1-t) + 255 * t)
                valB = math.floor(valB * (1-t) + 120 * t)
            else
                valR = math.floor(valR * (1-t) + 255 * t)
                valG = math.floor(valG * (1-t) + 160 * t)
                valB = math.floor(valB * (1-t) + 60  * t)
            end
        end
        text(tx, rowMid - 6, RES_TAGS[res], 9, c[1],c[2],c[3],200)
        text(tx, rowMid + 6, string.format("%d %s", rawVal, rateStr), 9, valR, valG, valB, 240)
    end

    -- 精炼资源区（水晶列与星币之间，3行竖排）
    local rzX  = 8 + cols * colW + 8
    local rzYs = { rowMid - 10, rowMid + 1, rowMid + 12 }
    for j, res in ipairs(RES_ORDER) do
        local c      = RES_COLORS[res]
        -- 使用滚动显示值
        local refVal = math.floor(displayRes_[res] or rm_.resources[res] or 0)
        -- L6: 精炼区使用"精炼"后缀标签，与原矿区明确区分
        local refinedLbl = (RES_REFINED_LABELS and RES_REFINED_LABELS[res]) or RES_LABELS[res]
        local label
        if res == "esource" and mult > 0 then
            label = string.format("%s %d +%.1f/s", refinedLbl, refVal, esourceRate)
        else
            label = string.format("%s %d", refinedLbl, refVal)
        end
        -- 闪光：增加→背景偏绿，减少→背景偏红
        local fl  = flashRes_[res]
        local bgA = 28
        local bdA = 65
        local txA = 230
        local txR, txG, txB = c[1], c[2], c[3]
        if fl and fl.timer > 0 then
            local t = fl.timer / FLASH_DURATION
            bgA = math.floor(28 + 60 * t)
            bdA = math.floor(65 + 100 * t)
            txA = 255
            if fl.dir > 0 then
                txR = math.floor(txR * (1-t) + 100 * t)
                txG = math.floor(txG * (1-t) + 255 * t)
                txB = math.floor(txB * (1-t) + 120 * t)
            else
                txR = math.floor(txR * (1-t) + 255 * t)
                txG = math.floor(txG * (1-t) + 80  * t)
                txB = math.floor(txB * (1-t) + 60  * t)
            end
        end
        nvgFontSize(vg_, 8); nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local tw = nvgTextBounds(vg_, 0, 0, label, nil)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, rzX - 2, rzYs[j] - 5, tw + 6, 11, 2)
        -- 危机状态：叠加红色半透明背景
        if resCrisisState_[res] then
            local blinkA = math.floor(30 + 25 * math.abs(math.sin(resCrisisBlink_ * 3.5)))
            nvgFillColor(vg_, nvgRGBA(255, 60, 60, bgA + blinkA)); nvgFill(vg_)
        else
            nvgFillColor(vg_, nvgRGBA(c[1], c[2], c[3], bgA)); nvgFill(vg_)
        end
        -- 危机状态：红色闪烁边框
        if resCrisisState_[res] then
            local blinkB = math.floor(140 + 115 * math.abs(math.sin(resCrisisBlink_ * 3.5)))
            nvgStrokeColor(vg_, nvgRGBA(255, 80, 80, blinkB)); nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)
        else
            nvgStrokeColor(vg_, nvgRGBA(c[1], c[2], c[3], bdA)); nvgStrokeWidth(vg_, 0.5); nvgStroke(vg_)
        end
        -- 危机状态文字改为红色
        if resCrisisState_[res] then
            nvgFillColor(vg_, nvgRGBA(255, 100, 100, 255))
        else
            nvgFillColor(vg_, nvgRGBA(txR, txG, txB, txA))
        end
        nvgText(vg_, rzX + 1, rzYs[j], label)

        -- P1-2: 趋势箭头（紧跟在胶囊右侧）
        local tdir = resTrendDir_[res]
        if tdir and tdir ~= 0 then
            local arrowX = rzX + tw + 9   -- 胶囊右边缘外 3px
            local arrowY = rzYs[j]
            nvgFontSize(vg_, 8)
            nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if tdir > 0 then
                nvgFillColor(vg_, nvgRGBA(80, 230, 120, 200))
                nvgText(vg_, arrowX, arrowY, "▲")
            else
                nvgFillColor(vg_, nvgRGBA(255, 100, 80, 200))
                nvgText(vg_, arrowX, arrowY, "▼")
            end
        end
    end

    -- ── 右区布局（从右往左，间距 6px，不重叠）──
    -- 🔔 铃铛：screenW-8 ~ screenW-36（宽28）
    -- ⚙  设置：screenW-42 ~ screenW-70（宽28）
    -- 🏆 成就：screenW-76 ~ screenW-104（宽28）
    -- 📋 日志：screenW-110 ~ screenW-138（宽28）
    -- 星币区：screenW-144 ~ screenW-224（宽80，图标14+标签+数值）
    -- 玩家信息：右对齐于 screenW-230

    -- 通知铃铛（最右）
    do
        local bx, by, bw, bh = screenW_ - 36, 6, 28, 28
        local isOpen    = NotifyPanel.IsOpen()
        local hasUnread = NotifyPanel.GetUnread() > 0
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgFillColor(vg_, isOpen and nvgRGBA(20,80,180,200) or nvgRGBA(20,40,80,160))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgStrokeColor(vg_, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 13); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, hasUnread and nvgRGBA(255,220,60,255) or nvgRGBA(140,180,255,220))
        nvgText(vg_, bx + bw/2, by + bh/2, "🔔")
        if hasUnread then
            local dot = math.min(NotifyPanel.GetUnread(), 99)
            local dotX = bx + bw - 2
            local dotY = by + 2
            nvgBeginPath(vg_); nvgCircle(vg_, dotX, dotY, 6)
            nvgFillColor(vg_, nvgRGBA(220,50,50,240)); nvgFill(vg_)
            nvgFontSize(vg_, 7); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255,255,255,255))
            nvgText(vg_, dotX, dotY, tostring(dot))
        end
        -- addHit 移到 RenderHUD 末尾注册，确保最高优先级
    end

    -- 设置按钮（铃铛左边，间距 6px）
    do
        local bx, by, bw, bh = screenW_ - 70, 6, 28, 28
        local isOpen = SettingsPanel.IsVisible()
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgFillColor(vg_, isOpen and nvgRGBA(20,80,180,200) or nvgRGBA(20,40,80,160))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgStrokeColor(vg_, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 14); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(180,210,255,220))
        nvgText(vg_, bx + bw/2, by + bh/2, "⚙")
        -- addHit 移到 RenderHUD 末尾注册，确保最高优先级
    end

    -- 成就按钮（设置按钮左边，间距 6px）
    do
        local bx, by, bw, bh = screenW_ - 104, 6, 28, 28
        local isOpen    = AchievementPanel.IsVisible()
        local unlockCnt = AchievementPanel.GetUnlockCount()
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgFillColor(vg_, isOpen and nvgRGBA(80,50,20,220) or nvgRGBA(20,40,80,160))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgStrokeColor(vg_, isOpen and nvgRGBA(255,200,60,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 13); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(255,210,80,230))
        nvgText(vg_, bx + bw/2, by + bh/2, "🏆")
        -- 成就数徽章
        if unlockCnt > 0 then
            nvgBeginPath(vg_); nvgCircle(vg_, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg_, nvgRGBA(60,200,100,240)); nvgFill(vg_)
            nvgFontSize(vg_, 7); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255,255,255,255))
            nvgText(vg_, bx + bw - 2, by + 2, tostring(unlockCnt))
        end
    end

    -- 📋 日志按钮（成就按钮左边，间距 6px）
    do
        local bx, by, bw, bh = screenW_ - 138, 6, 28, 28
        local isOpen = logVisible_
        -- 计算未完成目标数（有徽章提示）
        local pendingGoals = 0
        if STAGE_GOALS then
            for _, g in ipairs(STAGE_GOALS) do
                if not completedGoals_UI_[g.id] then pendingGoals = pendingGoals + 1 end
            end
        end
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgFillColor(vg_, isOpen and nvgRGBA(20,60,120,220) or nvgRGBA(20,40,80,160))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgStrokeColor(vg_, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 13); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(160,210,255,230))
        nvgText(vg_, bx + bw/2, by + bh/2, "📋")
        -- 徽章：未完成目标数（橙色）
        if pendingGoals > 0 then
            nvgBeginPath(vg_); nvgCircle(vg_, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg_, nvgRGBA(255,150,30,240)); nvgFill(vg_)
            nvgFontSize(vg_, 7); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255,255,255,255))
            nvgText(vg_, bx + bw - 2, by + 2, tostring(math.min(pendingGoals, 9)))
        end
        -- addHit 在 RenderHUD 末尾注册
    end

    -- P2-1: 战绩按钮（日志按钮左边，间距 6px）
    do
        local bx, by, bw, bh = screenW_ - 172, 6, 28, 28
        local isOpen = statsVisible_
        nvgBeginPath(vg_); nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgFillColor(vg_, isOpen and nvgRGBA(10, 50, 100, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg_)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgStrokeColor(vg_, isOpen and nvgRGBA(80, 180, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 13); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(100, 200, 255, 230))
        nvgText(vg_, bx + bw/2, by + bh/2, "📊")
    end

    -- P3-1: 快捷信号按钮（战绩按钮左边，间距 6px）
    do
        local bx, by, bw, bh = screenW_ - 206, 6, 28, 28
        local isOpen = signalOpen_
        local onCD   = signalCooldown_ > 0
        nvgBeginPath(vg_); nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgFillColor(vg_, isOpen and nvgRGBA(40, 80, 20, 220)
                       or (onCD and nvgRGBA(30, 30, 30, 140))
                       or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg_)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, bx, by, bw, bh, 5)
        nvgStrokeColor(vg_, isOpen and nvgRGBA(100, 220, 80, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 13); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, onCD and nvgRGBA(120, 120, 120, 150) or nvgRGBA(140, 255, 120, 230))
        nvgText(vg_, bx + bw/2, by + bh/2, "📡")
        -- 冷却圆弧进度
        if onCD then
            local pct = signalCooldown_ / SIGNAL_CD
            nvgBeginPath(vg_)
            nvgArc(vg_, bx + bw/2, by + bh/2, 11,
                   -math.pi/2, -math.pi/2 + (1 - pct) * math.pi * 2, 1)
            nvgStrokeColor(vg_, nvgRGBA(100, 220, 80, 180))
            nvgStrokeWidth(vg_, 2); nvgStroke(vg_)
        end
    end

    -- 星币（战绩按钮左边，间距 6px）
    local credits = math.floor(rm_.resources.credits or 0)
    local credX = screenW_ - 258
    local credIconH = resIcons_["credits"]
    if credIconH and credIconH >= 0 then
        local paint = nvgImagePattern(vg_, credX, rowMid - 7, 14, 14, 0, credIconH, 1.0)
        nvgBeginPath(vg_); nvgRect(vg_, credX, rowMid - 7, 14, 14)
        nvgFillPaint(vg_, paint); nvgFill(vg_)
    end
    text(credX + 17, rowMid - 6, "星币", 9, 255,210,60,200)
    text(credX + 17, rowMid + 6, tostring(credits), 10, 255,230,80,255)

    -- 玩家信息 + 在线时限/无尽轮次（星币左边，右对齐于 credX-6）
    local infoRightX = credX - 8
    local rtStr, tr, tg, tb
    if endlessRound_ > 0 then
        -- 无尽征服模式：显示当前轮次
        rtStr = string.format("∞ 第 %d 轮", endlessRound_)
        -- 橙色脉动
        local pulse = math.abs(math.sin(os.clock() * 2.0))
        tr = math.floor(255)
        tg = math.floor(140 + 60 * pulse)
        tb = math.floor(40  + 20 * pulse)
    else
        -- 普通模式：在线时限倒计时
        local rtSec     = math.max(0, math.floor(remainingTime_))
        local rtMin     = math.floor(rtSec / 60)
        local rtSecPart = rtSec % 60
        if rtMin >= 60 then
            rtStr = string.format("⏱%d:%02d:00", math.floor(rtMin/60), rtMin%60)
        else
            rtStr = string.format("⏱%02d:%02d", rtMin, rtSecPart)
        end
        local isLowTime = rtMin < 30
        tr = isLowTime and 255 or 100
        tg = isLowTime and 80  or 200
        tb = isLowTime and 60  or 120
        if rtMin < 5 then
            local blink = math.floor(os.clock() * 2) % 2 == 0
            tr, tg, tb = blink and 255 or 200, blink and 60 or 80, blink and 60 or 60
        end
    end
    text(infoRightX, rowMid - 6, player_.name .. " Lv." .. player_.level, 9,
        160,210,255,210, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
    text(infoRightX, rowMid + 6, rtStr, 9, tr, tg, tb, 220, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)

    -- ── 全部征收按钮（顶栏居中，仅银河视图且已展开时显示）──
    if deployed_ and onHarvestAllCb_ and currentScene_ == "galaxy" then
        local btnW, btnH = 72, 20
        local bx = math.floor(screenW_ / 2 - btnW / 2)
        local by = math.floor(rowMid - btnH / 2)
        local onCD  = harvestAllCD_ > 0
        local bgClr  = onCD and nvgRGBA(20,40,20,160) or nvgRGBA(20,80,40,200)
        local brdClr = onCD and nvgRGBA(60,90,60,120) or nvgRGBA(60,200,100,200)
        local lblClr = onCD and nvgRGBA(100,140,100,180) or nvgRGBA(140,255,160,255)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, bx, by, btnW, btnH, 4)
        nvgFillColor(vg_, bgClr); nvgFill(vg_)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, bx+0.5, by+0.5, btnW-1, btnH-1, 4)
        nvgStrokeColor(vg_, brdClr); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        -- 冷却遮罩（从右往左消退）
        if onCD then
            local maskW = math.floor(btnW * harvestAllCD_ / HARVEST_ALL_CD)
            nvgBeginPath(vg_); nvgRoundedRect(vg_, bx + btnW - maskW, by, maskW, btnH, 4)
            nvgFillColor(vg_, nvgRGBA(0,0,0,100)); nvgFill(vg_)
        end
        local label = onCD and string.format("征收 %ds", math.ceil(harvestAllCD_)) or "全部征收"
        nvgFontFace(vg_, "sans"); nvgFontSize(vg_, 9)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, lblClr)
        nvgText(vg_, bx + btnW/2, by + btnH/2, label)
        if not onCD then
            addHit(bx, by, btnW, btnH, function()
                harvestAllCD_ = HARVEST_ALL_CD
                if onHarvestAllCb_ then onHarvestAllCb_() end
            end)
        end
    end

    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, 0, TOPBAR_H); nvgLineTo(vg_, screenW_, TOPBAR_H)
    nvgStrokeColor(vg_, clr(60,90,200,60)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- ── 征服进度双轨条（TopBar 底部，3px 总高度，紧贴分隔线下方）──
    if getConquestProgress_ then
        local cp = getConquestProgress_()
        if cp then
            local barY  = TOPBAR_H      -- 紧贴 TopBar 底边
            local barH  = 3
            local half  = screenW_ / 2  -- 两轨各占一半宽度

            -- 左轨：殖民进度（绿色）
            local colPct = cp.total > 0 and math.min(1, cp.colonized / cp.total) or 0
            nvgBeginPath(vg_); nvgRect(vg_, 0, barY, half, barH)
            nvgFillColor(vg_, nvgRGBA(10, 25, 15, 180)); nvgFill(vg_)
            if colPct > 0.005 then
                local grad = nvgLinearGradient(vg_, 0, barY, half * colPct, barY,
                    nvgRGBA(30, 200, 90, 220), nvgRGBA(80, 255, 140, 180))
                nvgBeginPath(vg_); nvgRect(vg_, 0, barY, half * colPct, barH)
                nvgFillPaint(vg_, grad); nvgFill(vg_)
            end
            -- 左轨标签（叠加在进度条上，颜色半透明）
            nvgFontFace(vg_, "sans"); nvgFontSize(vg_, 7)
            nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(60, 220, 110, 190))
            nvgText(vg_, 4, barY + barH/2,
                string.format("殖民 %d/%d", cp.colonized, cp.total))

            -- 右轨：歼灭进度（橙红色）
            local pirPct = cp.piratesTotal > 0 and math.min(1, cp.piratesKilled / cp.piratesTotal) or 0
            nvgBeginPath(vg_); nvgRect(vg_, half, barY, half, barH)
            nvgFillColor(vg_, nvgRGBA(25, 12, 10, 180)); nvgFill(vg_)
            if pirPct > 0.005 then
                local fillW = half * pirPct
                local grad2 = nvgLinearGradient(vg_, half, barY, half + fillW, barY,
                    nvgRGBA(220, 80, 30, 220), nvgRGBA(255, 160, 60, 180))
                nvgBeginPath(vg_); nvgRect(vg_, half, barY, fillW, barH)
                nvgFillPaint(vg_, grad2); nvgFill(vg_)
            end
            -- 右轨标签（含威胁等级徽章）
            nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255, 160, 70, 190))
            local pirLabel = string.format("歼敌 %d/%d", cp.piratesKilled, cp.piratesTotal)
            if cp.pirateThreat and cp.pirateThreat > 0 then
                local threatColors = {
                    {100,255,100}, {255,220,60}, {255,140,30}, {255,60,60}, {220,60,255}
                }
                local tc = threatColors[cp.pirateThreat] or {255,255,255}
                local dots = string.rep("◆", cp.pirateThreat)
                -- 威胁等级文字（彩色，在右轨标签左侧）
                local labelW = nvgTextBounds(vg_, 0, 0, pirLabel)
                nvgFontSize(vg_, 7)
                nvgFillColor(vg_, nvgRGBA(tc[1], tc[2], tc[3], 220))
                nvgText(vg_, screenW_ - 4 - labelW - 4, barY + barH/2,
                    string.format("威胁%s", dots))
            end
            nvgFontSize(vg_, 7)
            nvgFillColor(vg_, nvgRGBA(255, 160, 70, 190))
            nvgText(vg_, screenW_ - 4, barY + barH/2, pirLabel)

            -- 中间分隔竖线
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, half, barY); nvgLineTo(vg_, half, barY + barH)
            nvgStrokeColor(vg_, nvgRGBA(80, 100, 160, 100))
            nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        end
    end
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
-- 3.5 海盗进攻预警倒计时 HUD（顶部居中）
-- ============================================================================
local function renderPirateWarning()
    if pirateWarningTime_ > PIRATE_WARN_THRESH then return end
    local t    = math.ceil(pirateWarningTime_)
    -- 根据剩余时间插值颜色：>15s橙→≤15s红
    local urgency = math.max(0, 1.0 - t / PIRATE_WARN_THRESH)
    local r = math.floor(200 + 55 * urgency)
    local g = math.floor(100 * (1 - urgency))
    -- 闪烁 alpha（0.5Hz~1Hz 加速闪烁）
    local freq  = 1.0 + urgency * 2.0
    local blink = math.abs(math.sin(pirateWarnBlink_ * math.pi * freq))
    local bgAlpha = math.floor(160 + 80 * blink)

    local bw = 220
    local bh = 28
    local bx = (screenW_ - bw) / 2
    local by = 52   -- TopBar 下方

    -- 背景条
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx, by, bw, bh, 6)
    nvgFillColor(vg_, nvgRGBA(r, g, 20, bgAlpha))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(r, g + 40, 40, 230))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    -- 文字
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 13)
    nvgFillColor(vg_, nvgRGBA(255, 240, 80, 255))
    nvgText(vg_, screenW_ / 2, by + bh / 2,
        string.format("⚠ 海盗进攻倒计时: %ds", t))
end

-- ============================================================================
-- 3.6 海盗情报面板 P1-3（右侧，科技树下方）
-- ============================================================================
local function renderIntelPanel()
    if not UICommon.pirateAI then return end
    local intel = UICommon.pirateAI:GetActiveIntel()
    if #intel == 0 then return end

    -- 面板参数
    local PW      = 190
    local LINE_H  = 18
    local PAD     = 8
    local ENTRY_H = LINE_H * 4 + PAD  -- 每条情报：4行
    local HEADER  = 22
    local ph      = HEADER + #intel * (ENTRY_H + 4) + PAD
    local px      = screenW_ - PW - 8
    local py      = 50   -- 顶部留给 TopBar

    local function ic(r, g, b, a) return nvgRGBA(r, g, b, a or 255) end

    -- 面板背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, PW, ph, 6)
    nvgFillColor(vg_, ic(10, 30, 40, 210))
    nvgFill(vg_)
    nvgStrokeColor(vg_, ic(60, 220, 200, 200))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 11)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, ic(60, 240, 220, 255))
    nvgText(vg_, px + PW / 2, py + HEADER / 2, "[ 海盗情报 ]")

    -- 分割线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 6, py + HEADER)
    nvgLineTo(vg_, px + PW - 6, py + HEADER)
    nvgStrokeColor(vg_, ic(60, 200, 180, 120))
    nvgStrokeWidth(vg_, 0.8)
    nvgStroke(vg_)

    local ey = py + HEADER + 2

    -- 计算玩家基地位置（用于方位判断）
    local baseX, baseY = 0, 0
    if UICommon.bs then
        baseX = UICommon.bs.x or 0
        baseY = UICommon.bs.y or 0
    end

    for i, entry in ipairs(intel) do
        local ex = px + PAD
        local ew = PW - PAD * 2

        -- 条目背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, ex - 2, ey, ew + 4, ENTRY_H, 4)
        nvgFillColor(vg_, ic(20, 50, 60, 180))
        nvgFill(vg_)
        nvgStrokeColor(vg_, ic(60, 180, 160, 80))
        nvgStrokeWidth(vg_, 0.7)
        nvgStroke(vg_)

        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 行1: 基地等级 + 方位
        local dx = entry.x - baseX
        local dy = entry.y - baseY
        local angle = math.deg(math.atan(dy, dx))
        local dirs = { "东", "东北", "北", "西北", "西", "西南", "南", "东南" }
        local dirIdx = math.floor((angle + 202.5) / 45) % 8 + 1
        local dirStr = dirs[dirIdx]

        nvgFontSize(vg_, 10)
        nvgFillColor(vg_, ic(60, 240, 220, 240))
        nvgText(vg_, ex, ey + 2, string.format("Lv%d 海盗基地  [%s]", entry.level, dirStr))

        -- 行2: 预计进攻时间（±20% 误差）
        local urgency = entry.estimatedAttack <= 30
        local tr = urgency and 255 or 220
        local tg = urgency and 100 or 190
        nvgFontSize(vg_, 10)
        nvgFillColor(vg_, ic(tr, tg, 60, 240))
        nvgText(vg_, ex, ey + LINE_H + 2,
            string.format("进攻: 约 %ds", entry.estimatedAttack))

        -- 行3: 舰队编成
        nvgFontSize(vg_, 9)
        nvgFillColor(vg_, ic(180, 210, 230, 220))
        nvgText(vg_, ex, ey + LINE_H * 2 + 2,
            "兵力: " .. entry.composition)

        -- 行4: 情报有效时间
        local itLeft = math.ceil(entry.intelTimer)
        local itR = itLeft <= 20 and 255 or 140
        local itG = itLeft <= 20 and 160 or 200
        nvgFontSize(vg_, 9)
        nvgFillColor(vg_, ic(itR, itG, 140, 200))
        nvgText(vg_, ex, ey + LINE_H * 3 + 2,
            string.format("情报剩余: %ds", itLeft))

        ey = ey + ENTRY_H + 4
    end
end

-- ============================================================================
-- P2-1. 生涯战绩面板（右侧浮动，6格数据卡片 3×2）
-- ============================================================================
local function renderCareerStatsPanel()
    if not statsVisible_ then return end

    local cs   = careerStats_UI_
    local PW   = 260
    local PAD  = 10
    local PH   = 258   -- P3-2: 底部加了"查看完整战绩"按钮，高度+28
    local px   = screenW_ - PW - 6
    local py   = 40

    -- 背景板
    nvgBeginPath(vg_); nvgRoundedRect(vg_, px, py, PW, PH, 8)
    nvgFillColor(vg_, nvgRGBA(6, 10, 26, 235)); nvgFill(vg_)
    nvgBeginPath(vg_); nvgRoundedRect(vg_, px, py, PW, PH, 8)
    nvgStrokeColor(vg_, nvgRGBA(80, 140, 255, 180)); nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)

    -- 标题栏
    nvgFontSize(vg_, 13); nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(100, 200, 255, 255))
    nvgText(vg_, px + PAD, py + 14, "📊 生涯战绩")
    -- 关闭按钮
    nvgFontSize(vg_, 12); nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(150, 180, 220, 200))
    nvgText(vg_, px + PW - PAD, py + 14, "✕")
    addHit(px + PW - 26, py, 26, 28, function() statsVisible_ = false end)

    -- 分隔线
    nvgBeginPath(vg_); nvgMoveTo(vg_, px + PAD, py + 28); nvgLineTo(vg_, px + PW - PAD, py + 28)
    nvgStrokeColor(vg_, nvgRGBA(60, 100, 180, 120)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- 6 格卡片数据（3列×2行）
    local cards = {
        { icon="🎮", label="总局数",   value=tostring(cs.totalGames) },
        { icon="🏆", label="胜利",     value=string.format("%d局 (%.0f%%)",
            cs.totalWins,
            cs.totalGames > 0 and (cs.totalWins / cs.totalGames * 100) or 0) },
        { icon="⚡", label="最高波次", value=tostring(cs.bestWave) .. "波" },
        { icon="💥", label="总击杀",   value=tostring(cs.totalKills) },
        { icon="🌍", label="总殖民",   value=tostring(cs.totalColonies) .. "颗" },
        { icon="⏱",  label="游戏时长", value=(function()
            local t = cs.playtime
            if t < 60 then return t .. "秒"
            elseif t < 3600 then return string.format("%d分%d秒", math.floor(t/60), t%60)
            else return string.format("%dh%dm", math.floor(t/3600), math.floor((t%3600)/60)) end
        end)() },
    }
    local COLS      = 3
    local CARD_W    = math.floor((PW - PAD*2 - (COLS-1)*6) / COLS)
    local CARD_H    = 58
    local ROWS      = 2
    local gridTop   = py + 34
    for i, card in ipairs(cards) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local cx  = px + PAD + col * (CARD_W + 6)
        local cy  = gridTop + row * (CARD_H + 6)
        -- 卡片背景
        nvgBeginPath(vg_); nvgRoundedRect(vg_, cx, cy, CARD_W, CARD_H, 5)
        nvgFillColor(vg_, nvgRGBA(15, 25, 55, 200)); nvgFill(vg_)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, cx, cy, CARD_W, CARD_H, 5)
        nvgStrokeColor(vg_, nvgRGBA(50, 90, 160, 120)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        -- 图标
        nvgFontSize(vg_, 16); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(255, 255, 255, 220))
        nvgText(vg_, cx + CARD_W/2, cy + 5, card.icon)
        -- 数值
        nvgFontSize(vg_, 12); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(180, 220, 255, 255))
        nvgText(vg_, cx + CARD_W/2, cy + 24, card.value)
        -- 标签
        nvgFontSize(vg_, 9); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(100, 140, 200, 160))
        nvgText(vg_, cx + CARD_W/2, cy + CARD_H - 13, card.label)
    end

    -- MVP 舰种（底部）
    local mvpY = gridTop + ROWS * (CARD_H + 6) + 2
    nvgBeginPath(vg_); nvgRoundedRect(vg_, px + PAD, mvpY, PW - PAD*2, 22, 4)
    nvgFillColor(vg_, nvgRGBA(40, 30, 10, 180)); nvgFill(vg_)
    nvgBeginPath(vg_); nvgRoundedRect(vg_, px + PAD, mvpY, PW - PAD*2, 22, 4)
    nvgStrokeColor(vg_, nvgRGBA(200, 160, 40, 120)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    nvgFontSize(vg_, 10); nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(200, 160, 60, 220))
    local mvpLabel = (cs.bestMvpShip and cs.bestMvpShip ~= "") and ("🥇 历史MVP：" .. cs.bestMvpShip) or "🥇 历史MVP：尚无记录"
    nvgText(vg_, px + PAD + 6, mvpY + 11, mvpLabel)

    -- P3-2: "查看完整战绩"按钮
    local btnY  = mvpY + 28
    local btnX  = px + PAD
    local btnW  = PW - PAD * 2
    local btnH  = 22
    local bhov  = cursorX_ >= btnX and cursorX_ <= btnX+btnW
               and cursorY_ >= btnY and cursorY_ <= btnY+btnH
    nvgBeginPath(vg_); nvgRoundedRect(vg_, btnX, btnY, btnW, btnH, 4)
    nvgFillColor(vg_, bhov and nvgRGBA(40, 80, 160, 230) or nvgRGBA(20, 40, 90, 180))
    nvgFill(vg_)
    nvgBeginPath(vg_); nvgRoundedRect(vg_, btnX, btnY, btnW, btnH, 4)
    nvgStrokeColor(vg_, bhov and nvgRGBA(100, 180, 255, 220) or nvgRGBA(60, 100, 200, 120))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    nvgFontSize(vg_, 10); nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(140, 200, 255, 230))
    nvgText(vg_, btnX + btnW/2, btnY + btnH/2, "🏛 查看完整战绩 →")
    addHit(btnX, btnY, btnW, btnH, function()
        careerPageOpen_ = true
        statsVisible_   = false
    end)
end

-- ============================================================================
-- P3-2. 生涯战绩全屏页面
-- ============================================================================
local function renderCareerPage(dt)
    if not careerPageOpen_ and careerPageAnim_ <= 0 then return end

    -- 入场/退场动画
    local TARGET = careerPageOpen_ and 1.0 or 0.0
    local SPEED  = 6.0
    if dt and dt > 0 then
        careerPageAnim_ = careerPageAnim_ + (TARGET - careerPageAnim_) * math.min(1, SPEED * dt)
        if math.abs(careerPageAnim_ - TARGET) < 0.005 then careerPageAnim_ = TARGET end
    end
    if careerPageAnim_ <= 0.01 then return end

    local vg  = vg_
    local sw  = screenW_
    local sh  = screenH_
    local a   = careerPageAnim_  -- 透明度/缩放驱动

    -- 全屏遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(0, 5, 20, math.floor(210 * a)))
    nvgFill(vg)

    -- 主面板（居中，80% 宽，最大 820px）
    local PW  = math.min(820, sw * 0.86)
    local PH  = math.min(560, sh * 0.84)
    local px  = (sw - PW) * 0.5
    local py  = (sh - PH) * 0.5 + (1 - a) * 30   -- 向下偏移实现滑入

    -- 背景板
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 14)
    nvgFillColor(vg, nvgRGBA(8, 14, 36, math.floor(245 * a))); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 14)
    nvgStrokeColor(vg, nvgRGBA(60, 120, 255, math.floor(200 * a)))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 顶部装饰线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 14, py); nvgLineTo(vg, px + PW - 14, py)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, math.floor(180 * a)))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(120, 200, 255, math.floor(255 * a)))
    nvgText(vg, px + 20, py + 22, "🏛  生涯战绩")

    -- 关闭按钮
    local cx = px + PW - 20; local cy = py + 22
    local mpos = input:GetMousePosition()
    local dpr  = graphics:GetDPR()
    local mx = mpos.x / dpr / UICommon.uiScale
    local my = mpos.y / dpr / UICommon.uiScale
    local closeDist = math.sqrt((mx - cx)^2 + (my - cy)^2)
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, closeDist < 14
        and nvgRGBA(255, 90, 90, math.floor(255 * a))
        or  nvgRGBA(160, 180, 220, math.floor(180 * a)))
    nvgText(vg, cx, cy, "✕")
    addHit(cx - 14, cy - 14, 28, 28, function() careerPageOpen_ = false end)

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 38); nvgLineTo(vg, px + PW - 16, py + 38)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 200, math.floor(120 * a)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ─── 数据读取 ─────────────────────────────────────────
    local cs  = careerStats_UI_
    local win = cs.totalGames > 0 and (cs.totalWins / cs.totalGames) or 0
    local function fmtTime(s)
        if s < 60    then return string.format("%d秒", s)
        elseif s < 3600 then return string.format("%d分%d秒", math.floor(s/60), s%60)
        else return string.format("%dh %dm", math.floor(s/3600), math.floor((s%3600)/60)) end
    end

    -- ─── 左侧：统计数据网格 (4×2) ──────────────────────────
    local GRID_COLS = 4
    local GRID_ROWS = 2
    local GRID_W    = PW * 0.56
    local GRID_H    = PH - 76
    local CARD_W    = (GRID_W - 16 - (GRID_COLS-1)*8) / GRID_COLS
    local CARD_H    = (GRID_H - (GRID_ROWS-1)*8) / GRID_ROWS
    local gx        = px + 16
    local gy        = py + 46

    local cards = {
        { icon="🎮", label="总局数",   val=tostring(cs.totalGames),  color={100,180,255} },
        { icon="🏆", label="胜率",     val=string.format("%.0f%%", win*100), color={80,220,120} },
        { icon="⚡", label="最高波次", val=tostring(cs.bestWave).."波",      color={255,200,60}  },
        { icon="💥", label="总击杀",   val=tostring(cs.totalKills),          color={255,120,80}  },
        { icon="🌍", label="总殖民",   val=tostring(cs.totalColonies).."颗", color={60,200,200}  },
        { icon="🕹️", label="胜利局数", val=tostring(cs.totalWins).."局",    color={180,120,255} },
        { icon="⏱",  label="总时长",   val=fmtTime(cs.playtime),            color={160,200,255} },
        { icon="🥇", label="历史MVP",  val=(cs.bestMvpShip ~= "" and cs.bestMvpShip or "无"),
                                                                              color={255,190,50}  },
    }

    for i, card in ipairs(cards) do
        local col = (i - 1) % GRID_COLS
        local row = math.floor((i - 1) / GRID_COLS)
        local bx  = gx + col * (CARD_W + 8)
        local by  = gy + row * (CARD_H + 8)

        -- 卡片背景
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, CARD_W, CARD_H, 7)
        nvgFillColor(vg, nvgRGBA(16, 28, 60, math.floor(210 * a))); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, CARD_W, CARD_H, 7)
        nvgStrokeColor(vg, nvgRGBA(card.color[1], card.color[2], card.color[3], math.floor(90 * a)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 顶部彩色条
        nvgBeginPath(vg); nvgRoundedRect(vg, bx+2, by+2, CARD_W-4, 3, 1.5)
        nvgFillColor(vg, nvgRGBA(card.color[1], card.color[2], card.color[3], math.floor(160 * a)))
        nvgFill(vg)

        -- 图标
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(220 * a)))
        nvgText(vg, bx + CARD_W/2, by + 8, card.icon)

        -- 数值
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(card.color[1], card.color[2], card.color[3], math.floor(240 * a)))
        nvgText(vg, bx + CARD_W/2, by + 30, card.val)

        -- 标签
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(120, 150, 200, math.floor(160 * a)))
        nvgText(vg, bx + CARD_W/2, by + CARD_H - 4, card.label)
    end

    -- ─── 右侧：雷达图 ──────────────────────────────────────
    local RW   = PW - GRID_W - 32
    local rx   = gx + GRID_W + 16
    local ry   = gy
    local rcx  = rx + RW / 2
    local rcy  = gy + GRID_H / 2
    local R    = math.min(RW, GRID_H) * 0.38

    -- 雷达图标题
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(140, 180, 255, math.floor(180 * a)))
    nvgText(vg, rcx, ry, "综合评分")

    -- 六维数据（归一化到 0~1）
    local DIMS = {
        { label="胜率",   val=win },
        { label="波次",   val=math.min(1, cs.bestWave / 20) },
        { label="击杀",   val=math.min(1, cs.totalKills / 200) },
        { label="殖民",   val=math.min(1, cs.totalColonies / 50) },
        { label="游戏数", val=math.min(1, cs.totalGames / 30) },
        { label="时长",   val=math.min(1, cs.playtime / 7200) },
    }
    local N    = #DIMS
    local TWO_PI = math.pi * 2

    -- 背景网格（3层）
    for layer = 1, 3 do
        local r = R * (layer / 3)
        nvgBeginPath(vg)
        for i = 1, N do
            local ang = (i - 1) * TWO_PI / N - math.pi / 2
            local lx  = rcx + r * math.cos(ang)
            local ly  = rcy + r * math.sin(ang)
            if i == 1 then nvgMoveTo(vg, lx, ly) else nvgLineTo(vg, lx, ly) end
        end
        nvgClosePath(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 100, 180, math.floor(80 * a)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end

    -- 轴线
    for i = 1, N do
        local ang = (i - 1) * TWO_PI / N - math.pi / 2
        nvgBeginPath(vg)
        nvgMoveTo(vg, rcx, rcy)
        nvgLineTo(vg, rcx + R * math.cos(ang), rcy + R * math.sin(ang))
        nvgStrokeColor(vg, nvgRGBA(60, 100, 180, math.floor(60 * a)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end

    -- 数据多边形（填充）
    nvgBeginPath(vg)
    for i = 1, N do
        local ang = (i - 1) * TWO_PI / N - math.pi / 2
        local r   = R * math.max(0.04, DIMS[i].val) * a
        local lx  = rcx + r * math.cos(ang)
        local ly  = rcy + r * math.sin(ang)
        if i == 1 then nvgMoveTo(vg, lx, ly) else nvgLineTo(vg, lx, ly) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(60, 140, 255, math.floor(70 * a))); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, math.floor(200 * a)))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 数据点
    for i = 1, N do
        local ang = (i - 1) * TWO_PI / N - math.pi / 2
        local r   = R * math.max(0.04, DIMS[i].val) * a
        local lx  = rcx + r * math.cos(ang)
        local ly  = rcy + r * math.sin(ang)
        nvgBeginPath(vg); nvgCircle(vg, lx, ly, 3)
        nvgFillColor(vg, nvgRGBA(150, 210, 255, math.floor(240 * a))); nvgFill(vg)
    end

    -- 维度标签
    for i = 1, N do
        local ang  = (i - 1) * TWO_PI / N - math.pi / 2
        local LR   = R + 18
        local lx   = rcx + LR * math.cos(ang)
        local ly   = rcy + LR * math.sin(ang)
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 200, 255, math.floor(200 * a)))
        nvgText(vg, lx, ly, DIMS[i].label)
    end

    -- ─── 底部提示 ──────────────────────────────────────────
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(100, 130, 180, math.floor(120 * a)))
    nvgText(vg, px + PW/2, py + PH - 6, "点击遮罩或右上角 ✕ 关闭")

    -- 点击遮罩关闭（最后注册，优先级最低）
    addHit(0, 0, px, sh, function() careerPageOpen_ = false end)
    addHit(px + PW, 0, sw - px - PW, sh, function() careerPageOpen_ = false end)
    addHit(px, 0, PW, py, function() careerPageOpen_ = false end)
    addHit(px, py + PH, PW, sh - py - PH, function() careerPageOpen_ = false end)
end

-- ============================================================================
-- P3-1. 快捷信号面板（TopBar 下方居中弹出，4×2 格布局）
-- ============================================================================
local function renderSignalPanel()
    if not signalOpen_ then return end
    local vg   = vg_
    local sw   = screenW_
    -- 面板尺寸
    local COLS, ROWS = 4, 2
    local BTN_W, BTN_H = 120, 44
    local GAP  = 6
    local PAD  = 10
    local pw   = COLS * BTN_W + (COLS - 1) * GAP + PAD * 2
    local ph   = ROWS * BTN_H + (ROWS - 1) * GAP + PAD * 2
    local px   = sw / 2 - pw / 2
    local py   = 48    -- TopBar 正下方

    -- 面板背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgFillColor(vg, nvgRGBA(8, 16, 36, 230)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 80, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 200, 140, 180))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local cdStr = signalCooldown_ > 0
        and string.format("  [冷却 %.0fs]", signalCooldown_) or ""
    nvgText(vg, px + PAD, py + 2, "📡 快捷信号" .. cdStr)

    -- 8 个信号按钮
    local onCD = signalCooldown_ > 0
    for i, sig in ipairs(QUICK_SIGNALS) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local bx  = px + PAD + col * (BTN_W + GAP)
        local by  = py + PAD + 10 + row * (BTN_H + GAP)
        local cr, cg, cb = sig.color[1], sig.color[2], sig.color[3]
        local mx, my = cursorX_, cursorY_
        local hover = mx >= bx and mx <= bx + BTN_W and my >= by and my <= by + BTN_H

        -- 按钮背景
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, BTN_W, BTN_H, 6)
        if onCD then
            nvgFillColor(vg, nvgRGBA(20, 20, 30, 140))
        elseif hover then
            nvgFillColor(vg, nvgRGBA(cr, cg, cb, 50))
        else
            nvgFillColor(vg, nvgRGBA(12, 20, 40, 200))
        end
        nvgFill(vg)
        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, BTN_W, BTN_H, 6)
        nvgStrokeColor(vg, onCD and nvgRGBA(60, 60, 60, 100)
            or nvgRGBA(cr, cg, cb, hover and 220 or 100))
        nvgStrokeWidth(vg, hover and 1.5 or 1); nvgStroke(vg)
        -- 图标
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, onCD and nvgRGBA(80, 80, 80, 150) or nvgRGBA(255, 255, 255, 230))
        nvgText(vg, bx + 8, by + BTN_H / 2, sig.icon)
        -- 文字
        nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, onCD and nvgRGBA(80, 80, 80, 150)
            or nvgRGBA(cr, cg, cb, hover and 255 or 200))
        nvgText(vg, bx + 30, by + BTN_H / 2, sig.label)
    end

    -- 注册点击热区
    for i, sig in ipairs(QUICK_SIGNALS) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local bx  = px + PAD + col * (BTN_W + GAP)
        local by2 = py + PAD + 10 + row * (BTN_H + GAP)
        if not onCD then
            addHit(bx, by2, BTN_W, BTN_H, function()
                -- 发送信号：本地通知 + 回调
                signalOpen_    = false
                signalCooldown_ = SIGNAL_CD
                local msg = sig.icon .. " " .. sig.label
                GameUI.Notify("📡 [信号] " .. msg, sig.type)
                if onSendSignalCb_ then onSendSignalCb_(sig) end
            end)
        end
    end
    -- 点击面板外区域关闭
    addHit(0, 0, px, screenH_, function() signalOpen_ = false end)
    addHit(px + pw, 0, screenW_ - px - pw, screenH_, function() signalOpen_ = false end)
    addHit(px, py + ph, pw, screenH_ - py - ph, function() signalOpen_ = false end)
end

-- ============================================================================
-- P1-3. 任务日志面板（右侧浮动，双 Tab：目标 / 探索记录）
-- ============================================================================
local function renderLogPanel()
    if not logVisible_ then return end

    local PW      = 260
    local PAD     = 10
    local TAB_H   = 24
    local HEADER  = 28
    local ITEM_H  = 46    -- 目标条目高度
    local LOG_H   = 38    -- 探索日志条目高度
    local MAX_VIS = 6     -- 最多显示条目数（超出滚动）

    -- 面板高度：固定高（避免随内容抖动）
    local ph = HEADER + TAB_H + 4 + MAX_VIS * ITEM_H + PAD
    local px = screenW_ - PW - 8
    local py = 50    -- 低于 TopBar（44px）

    -- 关闭按钮区域（后注册 hit）
    local closeBx = px + PW - 22
    local closeBy = py + 4

    -- 面板背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, PW, ph, 8)
    nvgFillColor(vg_, nvgRGBA(6, 12, 28, 230))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, PW, ph, 8)
    nvgStrokeColor(vg_, nvgRGBA(60, 140, 255, 180))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    -- 标题行
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 12)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(100, 200, 255, 255))
    nvgText(vg_, px + PAD, py + HEADER / 2, "📋 任务日志")
    -- 关闭按钮
    nvgFontSize(vg_, 11)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(160, 180, 220, 180))
    nvgText(vg_, closeBx + 9, py + HEADER / 2, "✕")

    -- 分隔线
    local sepY = py + HEADER
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 6, sepY); nvgLineTo(vg_, px + PW - 6, sepY)
    nvgStrokeColor(vg_, nvgRGBA(60, 100, 200, 60))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- Tab 按钮
    local tabY     = sepY + 3
    local tabW     = (PW - PAD * 2) / 2
    local tabs     = { {key="goals", label="目标"}, {key="explore", label="探索记录"} }
    for i, tab in ipairs(tabs) do
        local tx = px + PAD + (i - 1) * tabW
        local active = logTab_ == tab.key
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, tx, tabY, tabW - 3, TAB_H, 4)
        nvgFillColor(vg_, active and nvgRGBA(20, 80, 180, 200) or nvgRGBA(14, 30, 60, 160))
        nvgFill(vg_)
        nvgStrokeColor(vg_, active and nvgRGBA(80, 160, 255, 220) or nvgRGBA(40, 70, 120, 100))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        nvgFontSize(vg_, 10)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, active and nvgRGBA(180, 220, 255, 255) or nvgRGBA(120, 160, 200, 180))
        nvgText(vg_, tx + tabW / 2 - 1, tabY + TAB_H / 2, tab.label)
        local capturedKey = tab.key
        addHit(tx, tabY, tabW - 3, TAB_H, function()
            logTab_ = capturedKey
            logScroll_ = 0
        end)
    end

    -- 内容区起始 Y
    local contentY = tabY + TAB_H + 6
    local contentH = ph - (contentY - py) - PAD
    -- 裁剪区（用矩形遮罩模拟）
    local clipX = px + 4
    local clipW = PW - 8

    -- ── Tab: 目标 ──
    if logTab_ == "goals" then
        local goals = STAGE_GOALS or {}
        local itemCount = #goals
        local totalH    = itemCount * ITEM_H
        local maxScroll = math.max(0, totalH - contentH)
        logScroll_ = math.min(math.max(0, logScroll_), maxScroll)

        -- 滚动区域注册
        addScroll(clipX, contentY, clipW, contentH, function(delta)
            logScroll_ = math.min(math.max(0, logScroll_ - delta * 30), maxScroll)
        end)

        local iy = contentY - logScroll_
        for _, goal in ipairs(goals) do
            if iy + ITEM_H > contentY - 4 and iy < contentY + contentH then
                local done = completedGoals_UI_[goal.id] == true
                -- 条目背景
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, clipX, iy, clipW, ITEM_H - 3, 5)
                nvgFillColor(vg_, done and nvgRGBA(10,40,20,200) or nvgRGBA(12,20,44,200))
                nvgFill(vg_)
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, clipX, iy, clipW, ITEM_H - 3, 5)
                nvgStrokeColor(vg_, done and nvgRGBA(40,180,80,100) or nvgRGBA(40,80,160,80))
                nvgStrokeWidth(vg_, 0.8); nvgStroke(vg_)

                -- 完成指示条（左侧竖线）
                nvgBeginPath(vg_)
                nvgRect(vg_, clipX, iy + 2, 3, ITEM_H - 7)
                nvgFillColor(vg_, done and nvgRGBA(40,200,80,230) or nvgRGBA(60,120,255,150))
                nvgFill(vg_)

                -- 目标标题
                nvgFontFace(vg_, "sans")
                nvgFontSize(vg_, 10)
                nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg_, done and nvgRGBA(100,220,120,240) or nvgRGBA(180,210,255,230))
                nvgText(vg_, clipX + 10, iy + 4,
                    (done and "✓ " or "○ ") .. goal.title)

                -- 目标描述
                nvgFontSize(vg_, 9)
                nvgFillColor(vg_, done and nvgRGBA(80,160,100,180) or nvgRGBA(120,150,200,160))
                nvgText(vg_, clipX + 10, iy + 17, goal.desc)

                -- 奖励预览（右侧）
                if not done and goal.reward then
                    local parts = {}
                    for res, amt in pairs(goal.reward) do
                        local lbl = RES_LABELS and RES_LABELS[res] or res
                        parts[#parts+1] = "+" .. amt .. lbl
                    end
                    local rStr = table.concat(parts, " ")
                    nvgFontSize(vg_, 8)
                    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg_, nvgRGBA(255,210,60,180))
                    nvgText(vg_, clipX + clipW - 4, iy + 4, rStr)
                    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                end
            end
            iy = iy + ITEM_H
        end

        -- 无目标时提示
        if #goals == 0 then
            nvgFontSize(vg_, 10)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(120, 150, 200, 160))
            nvgText(vg_, px + PW / 2, contentY + contentH / 2, "暂无阶段目标")
        end

        -- 滚动条（有溢出时显示）
        if maxScroll > 0 then
            local barH   = contentH * contentH / totalH
            local barY   = contentY + logScroll_ / maxScroll * (contentH - barH)
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, px + PW - 6, barY, 3, barH, 2)
            nvgFillColor(vg_, nvgRGBA(60, 140, 255, 160))
            nvgFill(vg_)
        end

    -- ── Tab: 探索记录 ──
    else
        local logs = exploreLog_
        local itemCount = #logs
        if itemCount == 0 then
            nvgFontSize(vg_, 10)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(120, 150, 200, 160))
            nvgText(vg_, px + PW / 2, contentY + contentH / 2, "暂无探索记录")
        else
            local totalH    = itemCount * LOG_H
            local maxScroll = math.max(0, totalH - contentH)
            logScroll_ = math.min(math.max(0, logScroll_), maxScroll)

            -- 滚动区域
            addScroll(clipX, contentY, clipW, contentH, function(delta)
                logScroll_ = math.min(math.max(0, logScroll_ - delta * 30), maxScroll)
            end)

            -- 最新在最前（倒序显示）
            local iy = contentY - logScroll_
            for idx = itemCount, 1, -1 do
                local entry = logs[idx]
                if iy + LOG_H > contentY - 4 and iy < contentY + contentH then
                    -- 条目背景
                    nvgBeginPath(vg_)
                    nvgRoundedRect(vg_, clipX, iy, clipW, LOG_H - 3, 4)
                    nvgFillColor(vg_, nvgRGBA(10, 24, 48, 200))
                    nvgFill(vg_)
                    nvgBeginPath(vg_)
                    nvgRoundedRect(vg_, clipX, iy, clipW, LOG_H - 3, 4)
                    nvgStrokeColor(vg_, nvgRGBA(40, 100, 200, 80))
                    nvgStrokeWidth(vg_, 0.7); nvgStroke(vg_)

                    -- 左竖线（蓝绿色）
                    nvgBeginPath(vg_)
                    nvgRect(vg_, clipX, iy + 2, 3, LOG_H - 7)
                    nvgFillColor(vg_, nvgRGBA(40, 200, 180, 200))
                    nvgFill(vg_)

                    -- 图标 + 任务名
                    nvgFontFace(vg_, "sans")
                    nvgFontSize(vg_, 11)
                    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg_, nvgRGBA(160, 220, 255, 230))
                    nvgText(vg_, clipX + 9, iy + 3,
                        (entry.icon or "🔭") .. " " .. (entry.label or "未知任务"))

                    -- 奖励摘要
                    nvgFontSize(vg_, 9)
                    nvgFillColor(vg_, nvgRGBA(100, 200, 140, 200))
                    nvgText(vg_, clipX + 9, iy + 16, entry.rewardStr or "")

                    -- 时间戳（右对齐）
                    nvgFontSize(vg_, 8)
                    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg_, nvgRGBA(100, 130, 180, 160))
                    local ts = entry.timeStr or ""
                    nvgText(vg_, clipX + clipW - 4, iy + 3, ts)
                    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                end
                iy = iy + LOG_H
            end

            -- 滚动条
            if maxScroll > 0 then
                local barH = contentH * contentH / totalH
                local barY = contentY + logScroll_ / maxScroll * (contentH - barH)
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px + PW - 6, barY, 3, barH, 2)
                nvgFillColor(vg_, nvgRGBA(40, 200, 180, 160))
                nvgFill(vg_)
            end
        end
    end

    -- 关闭按钮 hit
    addHit(closeBx, closeBy, 20, 20, function()
        logVisible_ = false
        logScroll_  = 0
    end)
    -- 面板遮罩（点击面板内部不穿透）
    addHit(px, py, PW, ph, function() end)
end

-- ============================================================================
-- 4. 市场面板（左下）
-- ============================================================================
local function renderMarketPanel()
    if not ms_ then return end
    -- 仅当选中星球已建造星际交易所时显示
    if not selectedPlanet_ or not selectedPlanet_.colonized then return end
    local hasHub = false
    for _, b in ipairs(selectedPlanet_.buildings) do
        if b.key == "TRADE_HUB" then hasHub = true; break end
    end
    if not hasHub then return end
    local pw = 230
    local lineH = 20
    local rows = 2 + 3 * 2  -- title+sep + 每资源2行（矿石/能量块/水晶）
    if marketCollapsed_ then rows = 2 end
    local ph = rows * lineH + 12

    local px = 12
    -- 底部锚点：优先贴屏幕底部，但不与 TechPanel 重叠
    local techBottom = PANEL_TOP + (UICommon.techPanelH or 0) + (UICommon.techPanelH > 0 and 8 or 0)
    local py = math.max(techBottom, screenH_ - ph - 8)
    -- 若面板超出屏幕底部则不显示（屏幕太小）
    if py + ph > screenH_ - 4 then return end

    panel(px, py, pw, ph, 7,
        {8,22,12,235},
        {40,180,80,200})

    local titleY = py + 14
    text(px+10, titleY, "[ 银河交易所 ]", 13, 60,200,100,255)
    local btnX = px+pw-22
    text(btnX, titleY, marketCollapsed_ and "▼" or "▲", 11, 80,200,120,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    addHit(px, py, pw, 22, function() marketCollapsed_ = not marketCollapsed_ end)

    if marketCollapsed_ then return end

    local sy = titleY + 22
    nvgBeginPath(vg_); nvgMoveTo(vg_, px+8, sy); nvgLineTo(vg_, px+pw-8, sy)
    nvgStrokeColor(vg_, clr(40,180,80,60)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    sy = sy + 8

    -- P2-3: 迷你折线图绘制函数（sparkline）
    local function drawSparkline(cx, cy, w, h, history, upR,upG,upB, downR,downG,downB)
        if not history or #history < 2 then return end
        -- 找最大最小值（归一化）
        local minV, maxV = history[1], history[1]
        for _, v in ipairs(history) do
            if v < minV then minV = v end
            if v > maxV then maxV = v end
        end
        local range = maxV - minV
        if range < 0.01 then range = 0.01 end
        -- 图表背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, cx, cy, w, h, 2)
        nvgFillColor(vg_, clr(15,15,15,120))
        nvgFill(vg_)
        -- 折线
        local n = #history
        local lastDir = history[n] >= history[n-1]
        local lr = lastDir and upR  or downR
        local lg = lastDir and upG  or downG
        local lb = lastDir and upB  or downB
        nvgBeginPath(vg_)
        for i, v in ipairs(history) do
            local t = (i - 1) / (n - 1)
            local nx2 = cx + t * w
            local ny2 = cy + h - ((v - minV) / range) * h
            ny2 = math.max(cy + 1, math.min(cy + h - 1, ny2))
            if i == 1 then nvgMoveTo(vg_, nx2, ny2)
            else            nvgLineTo(vg_, nx2, ny2) end
        end
        nvgStrokeColor(vg_, clr(lr, lg, lb, 200))
        nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)
        -- 最新值端点
        local lx = cx + w
        local ly = cy + h - ((history[n] - minV) / range) * h
        ly = math.max(cy + 1, math.min(cy + h - 1, ly))
        nvgBeginPath(vg_)
        nvgCircle(vg_, lx, ly, 2)
        nvgFillColor(vg_, clr(lr, lg, lb, 255))
        nvgFill(vg_)
    end

    for _, res in ipairs({"metal","esource","nuclear"}) do
        local r     = ms_.rates[res]
        local c     = RES_COLORS[res]
        local trend = ms_:getTrend(res)
        -- 趋势颜色：↑绿 ↓红 →灰
        local tr,tg,tb = 150,150,150
        if trend == "↑" then tr,tg,tb = 50,230,100
        elseif trend == "↓" then tr,tg,tb = 255,80,80 end

        -- P2-3: 价格突变提示（!标记 + 边框闪烁）
        local flash = ms_.priceFlash and (ms_.priceFlash[res] or 0) or 0
        local flashAlpha = flash > 0 and math.floor(math.abs(math.sin(flash * 4)) * 180 + 60) or 0

        -- 资源名 + 趋势箭头
        text(px+10, sy+9, RES_LABELS[res], 10, c[1]+40,c[2]+40,c[3]+40,230)
        text(px+60, sy+9, trend, 12, tr,tg,tb,255)
        -- P2-3: 突变感叹号
        if flashAlpha > 0 then
            text(px+74, sy+9, "!", 11, 255,220,60,flashAlpha)
        end
        -- 卖/买价格（缩短文字以腾出 sparkline 空间）
        text(px+82, sy+9,
            "卖" .. string.format("%.1f", r.sell) .. " 买" .. string.format("%.1f", r.buy),
            10, c[1]+20,c[2]+20,c[3]+20,210)
        -- P2-3: 迷你折线图（右侧，46×13px）
        local sparkX = px + pw - 52
        local sparkY = sy + 1
        drawSparkline(sparkX, sparkY, 44, 13, ms_.history[res],
            50,230,100,   -- 上升色（绿）
            255,100,80    -- 下降色（红）
        )
        sy = sy + 18

        local capturedRes = res
        local y1 = sy
        drawButton(px+10,   y1, 100, 16, "卖出×100", 200,120,50, function()
            if onMarketCb_ then onMarketCb_("sell", capturedRes, 100) end
        end)
        drawButton(px+120,  y1, 100, 16, "买入×100", 50,150,200, function()
            if onMarketCb_ then onMarketCb_("buy", capturedRes, 100) end
        end)
        sy = y1 + 20
    end
end

-- ============================================================================
-- 5. 展开前操作提示 HUD（种子飞船阶段，手机紧凑版）
-- ============================================================================
local function renderDeployHint()
    -- 底部居中提示框（手机横屏压缩版）
    local bw  = math.min(480, screenW_ - 40)
    local bh  = 64
    local bx  = (screenW_ - bw) / 2
    local by  = screenH_ - bh - 14

    -- 背景板
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx, by, bw, bh, 7)
    nvgFillColor(vg_,   clrC(C.panelBg))
    nvgFill(vg_)
    nvgStrokeColor(vg_, clrC(C.panelBorder))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题行（更小字号）
    nvgFontSize(vg_, 11)
    nvgFillColor(vg_, clrC(C.textTitle))
    nvgText(vg_, screenW_ / 2, by + 13, "星航种子飞船 — 寻找落脚点")

    -- 移动说明行
    nvgFontSize(vg_, 9)
    nvgFillColor(vg_, clrC(C.textSubtitle))
    nvgText(vg_, screenW_ / 2, by + 27, "WASD / 方向键  或  点击地图 移动")

    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, bx + 16, by + 36)
    nvgLineTo(vg_, bx + bw - 16, by + 36)
    nvgStrokeColor(vg_, nvgRGBA(60, 120, 220, 80))
    nvgStrokeWidth(vg_, 0.8)
    nvgStroke(vg_)

    -- 「在此展开基地」按钮
    local btnW, btnH = math.min(220, bw - 80), 20
    local btnX = screenW_ / 2 - btnW / 2
    local btnY = by + 40

    local hover = cursorX_ >= btnX and cursorX_ <= btnX + btnW
               and cursorY_ >= btnY and cursorY_ <= btnY + btnH
    local fillA = hover and 230 or 180
    local borderA = hover and 255 or 180

    local btnGrad = nvgLinearGradient(vg_, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(20, 160, 80, fillA), nvgRGBA(10, 110, 55, fillA))
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, btnX, btnY, btnW, btnH, 4)
    nvgFillPaint(vg_, btnGrad)
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(60, 220, 120, borderA))
    nvgStrokeWidth(vg_, hover and 1.5 or 1.0)
    nvgStroke(vg_)

    nvgFontSize(vg_, 10)
    nvgFillColor(vg_, nvgRGBA(200, 255, 220, 255))
    nvgText(vg_, screenW_ / 2, btnY + btnH / 2, "▶  在此展开基地")

    -- SPACE 提示（右侧小字）
    nvgFontSize(vg_, 8)
    nvgFillColor(vg_, nvgRGBA(120, 160, 200, 140))
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg_, bx + bw - 8, btnY + btnH / 2, "SPACE")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    addHit(btnX, btnY, btnW, btnH, function()
        if deployCallback_ then deployCallback_() end
    end)
end





-- ============================================================================
-- 6c. 资源互换中心面板（基地已安装 EXCHANGE_CENTER 时显示）
-- ============================================================================
local function renderExchangePanel(base, basePanelH)
    if not base or not base.isBase then return end
    -- 检查是否已安装互换中心
    local hasExchange = false
    for _, b in ipairs(base.buildings) do
        if b.key == "EXCHANGE_CENTER" then hasExchange = true; break end
    end
    if not hasExchange then return end

    local pw = 275
    local px = screenW_ - pw - 12
    -- 放在基地面板下方（使用 BasePanel.Render 返回的精确高度）
    local py = PANEL_TOP + (basePanelH or 300) + 8

    local titleH = 26

    -- ---- 折叠态：只显示标题条 ----
    if exchangeCollapsed_ then
        if py + titleH > screenH_ - 4 then return end
        panel(px, py, pw, titleH, 5, {10,22,20,220}, {60,200,120,160})
        text(px + 14, py + titleH/2, "▶", 10, 60,200,120,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
        text(px + pw/2, py + titleH/2, "资源互换中心", 12, 60,220,140,220,
            NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        addHit(px, py, pw, titleH, function() exchangeCollapsed_ = false end)
        return
    end

    -- ---- 展开态 ----
    local EXCHANGE_RES = {"metal","esource","nuclear"}
    local btnH   = 20
    local stockH = 14  -- 库存栏高度
    -- 计算总高度：标题 + 分隔 + 库存行 + 分隔 + 每组(分组标题12 + 2个按钮*24) * 3组
    local groupCount = #EXCHANGE_RES  -- 3 组
    local btnsPerGroup = #EXCHANGE_RES - 1  -- 每组 2 个按钮
    local ph = titleH + 4 + stockH + 4 + groupCount * (12 + btnsPerGroup * (btnH + 3) + 6) + 4
    if py + ph > screenH_ - 4 then return end  -- 超出屏幕则不显示

    panel(px, py, pw, ph, 7, {10,22,20,240}, {60,200,120,200})

    local sy = py + titleH/2
    -- 折叠按钮（左侧）
    text(px + 10, sy, "◀", 9, 60,200,120,180, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
    addHit(px, py, 28, titleH, function() exchangeCollapsed_ = true end)
    -- 标题
    text(px+pw/2, sy, "[ 资源互换中心 ]", 13, 60,220,140,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = py + titleH + 2

    -- 分隔线
    nvgBeginPath(vg_); nvgMoveTo(vg_, px+8, sy); nvgLineTo(vg_, px+pw-8, sy)
    nvgStrokeColor(vg_, clr(60,200,120,60)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    sy = sy + 3

    -- 当前库存行（3 种资源余量）
    if rm_ then
        local resOrder = {"metal","esource","nuclear"}
        local colW = (pw - 16) / 3
        for i, res in ipairs(resOrder) do
            local amt   = math.floor(rm_.resources[res] or 0)
            local rclr  = RES_COLORS[res]
            local cx    = px + 8 + (i - 1) * colW + colW / 2
            local enough = amt >= EXCHANGE_AMOUNT
            text(cx, sy + stockH/2,
                RES_LABELS[res] .. ": " .. amt,
                9,
                enough and (rclr[1]+30) or 180,
                enough and (rclr[2]+30) or 100,
                enough and (rclr[3]+30) or 80,
                enough and 220 or 150,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end
    end
    sy = sy + stockH + 3

    -- 第二条分隔线
    nvgBeginPath(vg_); nvgMoveTo(vg_, px+8, sy); nvgLineTo(vg_, px+pw-8, sy)
    nvgStrokeColor(vg_, clr(60,200,120,40)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    sy = sy + 4

    -- 按来源资源分组渲染互换按钮
    for _, fromRes in ipairs(EXCHANGE_RES) do
        local fromLabel = RES_LABELS[fromRes]
        local fromClr   = RES_COLORS[fromRes]
        local have      = rm_ and (rm_.resources[fromRes] or 0) or 0
        local canFrom   = have >= EXCHANGE_AMOUNT

        -- 分组标题（来源资源名 + 余量）
        text(px + 12, sy + 6,
            "消耗 " .. fromLabel .. "（" .. math.floor(have) .. "）",
            9,
            fromClr[1]+20, fromClr[2]+20, fromClr[3]+20,
            canFrom and 200 or 120,
            NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        sy = sy + 12

        -- 本组各目标按钮
        for _, toRes in ipairs(EXCHANGE_RES) do
            if toRes ~= fromRes then
                local ratio   = EXCHANGE_RATES[fromRes] and EXCHANGE_RATES[fromRes][toRes]
                if ratio then
                    local toLabel = RES_LABELS[toRes]
                    local gain    = math.floor(EXCHANGE_AMOUNT * ratio)
                    local toClr   = RES_COLORS[toRes]

                    -- 按钮背景
                    local bx = px + 8
                    nvgBeginPath(vg_)
                    nvgRoundedRect(vg_, bx, sy, pw-16, btnH, 3)
                    nvgFillColor(vg_, nvgRGBA(
                        canFrom and 20 or 14,
                        canFrom and 80 or 45,
                        canFrom and 50 or 32,
                        canFrom and 210 or 110))
                    nvgFill(vg_)
                    nvgStrokeColor(vg_, nvgRGBA(
                        fromClr[1], fromClr[2], fromClr[3],
                        canFrom and 160 or 60))
                    nvgStrokeWidth(vg_, 0.8)
                    nvgStroke(vg_)

                    -- 左侧：消耗
                    local midX = px + pw / 2
                    text(midX - 6, sy + btnH/2,
                        "-" .. EXCHANGE_AMOUNT .. " " .. fromLabel,
                        10,
                        fromClr[1]+50, fromClr[2]+50, fromClr[3]+50,
                        canFrom and 230 or 110,
                        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    -- 箭头
                    text(midX, sy + btnH/2, "⇒", 10,
                        160, 220, 160, canFrom and 200 or 90,
                        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    -- 右侧：获得
                    text(midX + 6, sy + btnH/2,
                        "+" .. gain .. " " .. toLabel,
                        10,
                        toClr[1]+50, toClr[2]+50, toClr[3]+50,
                        canFrom and 230 or 110,
                        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

                    if canFrom then
                        local capturedFrom = fromRes
                        local capturedTo   = toRes
                        addHit(bx, sy, pw-16, btnH, function()
                            if onExchangeCb_ then onExchangeCb_(capturedFrom, capturedTo) end
                        end)
                    end
                    sy = sy + btnH + 3
                end
            end
        end
        sy = sy + 6  -- 组间距
    end
end

-- ============================================================================
-- 7. 造船厂面板
-- ============================================================================
local function renderShipyardPanel(planet)
    if not planet or not planet.colonized then return end
    local hasShipyard = false
    -- 检查行星建筑
    if planet.buildings then
        for _, b in ipairs(planet.buildings) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    -- 检查基地模块
    if not hasShipyard and planet.isBase and planet.modules then
        for _, b in ipairs(planet.modules) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    if not hasShipyard then return end

    local pw = 210
    -- 造船厂移到左侧区域（x=12），位于 TechPanel 下方，避免与右侧面板重叠
    -- UICommon.techPanelH 由 TechPanel.Render 每帧更新（不显示时为 0）
    local px = 12
    local techH = UICommon.techPanelH or 0
    local py = PANEL_TOP + (techH > 0 and (techH + 8) or 0)
    local titleH = 26

    -- ---- 折叠态：只显示标题条，若有生产任务显示进度小提示 ----
    if shipyardCollapsed_ then
        local queueSize = spq_ and #spq_.items or 0
        local colH = titleH + (queueSize > 0 and 16 or 0)
        panel(px, py, pw, colH, 5, {6,12,24,220}, {60,120,200,160})
        text(px + 14, py + titleH/2, "▶", 10, 100,160,255,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
        text(px + pw/2, py + titleH/2, "造船厂", 12, 100,170,255,220,
            NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        -- 生产中提示
        if queueSize > 0 then
            local job = spq_.items[1]
            local pct = job.progress or 0
            progressBar(px+8, py+titleH, pw-16, 10, pct,
                SHIP_TYPES[job.shipType].name.." "..math.floor(pct*100).."%",
                80, 130, 220)
        end
        addHit(px, py, pw, colH, function() shipyardCollapsed_ = false end)
        return
    end

    -- ---- 展开态 ----
    local numShips  = #SHIP_QUEUE_ORDER
    local queueSize = spq_ and #spq_.items or 0
    local ph = titleH + 4 + (queueSize > 0 and 16 or 18)
             + (queueSize > 1 and (10 + (queueSize - 1) * 16) or 0)
             + 8 + numShips * 22

    panel(px, py, pw, ph, 7,
        {6,12,24,240},
        {60,120,200,200})

    local sy = py + titleH/2
    -- 折叠按钮（左侧）
    text(px + 10, sy, "◀", 9, 100,160,255,180, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
    addHit(px, py, 28, titleH, function() shipyardCollapsed_ = true end)
    -- 标题
    text(px+pw/2, sy, "[ 造船厂 ]", 13, 100,170,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = py + titleH + 4

    -- P2-3: 队列状态（最多显示3条，含取消×和上移↑按钮）
    if spq_ and #spq_.items > 0 then
        local displayMax = math.min(3, #spq_.items)
        for i = 1, displayMax do
            local capturedIdx = i
            local q   = spq_.items[i]
            local st  = SHIP_TYPES[q.shipType]
            local rowH = 18
            local rowY = sy

            if i == 1 then
                -- 第一条：正在生产，带进度条（闪烁蓝光效果用透明度脉动）
                local pct   = q.progress or 0
                local pulse = math.abs(math.sin(gameTime_ * 3)) * 80 + 120  -- 120~200
                local barW  = pw - 52  -- 留出×按钮空间
                -- 进度条背景
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px+8, rowY, barW, 14, 3)
                nvgFillColor(vg_, nvgRGBA(20,50,100,180))
                nvgFill(vg_)
                -- 进度条填充（闪烁）
                if pct > 0 then
                    nvgBeginPath(vg_)
                    nvgRoundedRect(vg_, px+8, rowY, barW * pct, 14, 3)
                    nvgFillColor(vg_, nvgRGBA(60, 140, 255, math.floor(pulse)))
                    nvgFill(vg_)
                end
                -- 进度文字
                local lbl = st.name .. " " .. math.floor(pct*100) .. "%"
                text(px+8+barW/2, rowY+7, lbl, 9, 180,210,255,220, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                -- × 取消按钮
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px+pw-40, rowY+1, 14, 12, 2)
                nvgFillColor(vg_, nvgRGBA(180,60,60,160))
                nvgFill(vg_)
                text(px+pw-33, rowY+7, "×", 10, 255,180,180,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+pw-40, rowY, 14, 14, function()
                    if onShipCancelCb_ then onShipCancelCb_(capturedIdx) end
                end)
                sy = sy + 18
            else
                -- 等待中的条目：序号圆点 + 名称 + ↑上移 + ×取消
                local rowMid = rowY + rowH/2
                -- 序号圆点
                nvgBeginPath(vg_)
                nvgCircle(vg_, px+14, rowMid, 4)
                nvgFillColor(vg_, nvgRGBA(st.color[1], st.color[2], st.color[3], 200))
                nvgFill(vg_)
                -- 名称
                text(px+24, rowMid, (i-1)..". "..st.name, 10, 160,185,225,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
                -- ↑ 上移按钮
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px+pw-56, rowY+3, 14, 12, 2)
                nvgFillColor(vg_, nvgRGBA(60,120,200,140))
                nvgFill(vg_)
                text(px+pw-49, rowMid, "↑", 9, 160,210,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+pw-56, rowY+2, 14, 14, function()
                    if onShipPromoteCb_ then onShipPromoteCb_(capturedIdx) end
                end)
                -- × 取消按钮
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px+pw-40, rowY+3, 14, 12, 2)
                nvgFillColor(vg_, nvgRGBA(180,60,60,140))
                nvgFill(vg_)
                text(px+pw-33, rowMid, "×", 10, 255,180,180,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+pw-40, rowY+2, 14, 14, function()
                    if onShipCancelCb_ then onShipCancelCb_(capturedIdx) end
                end)
                sy = sy + rowH
            end
        end
        -- 超出显示范围的条目提示
        if #spq_.items > 3 then
            text(px+pw/2, sy+6, "...还有 " .. (#spq_.items-3) .. " 艘", 9, 120,140,170,160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            sy = sy + 14
        end
    else
        text(px+10, sy+7, "队列: 空闲", 10, 130,150,180,180)
        sy = sy + 18
    end

    nvgBeginPath(vg_); nvgMoveTo(vg_, px+6, sy); nvgLineTo(vg_, px+pw-6, sy)
    nvgStrokeColor(vg_, clr(60,120,200,60)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    sy = sy + 8

    for _, stype in ipairs(SHIP_QUEUE_ORDER) do
        local capturedType = stype
        local cost = SHIP_COSTS[stype]
        local costStr = rm_:fmtCost(cost)
        local st = SHIP_TYPES[stype]
        -- M4: 显示建造时间（受造船厂加速影响后实际时间由队列决定，此处显示基础值）
        local timeStr = st.buildTime and (" ⏱"..st.buildTime.."s") or ""
        sy = drawButton(px+8, sy, pw-16, 18,
            st.name.." ["..costStr.."]"..timeStr,
            60, 100, 220,
            function()
                if onShipQueueCb_ then onShipQueueCb_(capturedType) end
            end)
    end
end


-- ============================================================================
-- 9. 进度条浮层（星图场景）
-- ============================================================================
function GameUI.RenderProgressBars(selectedPlanet)
end


-- ============================================================================
-- 11. 通知渲染
-- ============================================================================
function GameUI.RenderNotifications()
    -- 更新 UICommon 屏幕宽度确保子模块可读到最新值
    UICommon.screenW = screenW_
    NotifyPanel.RenderToasts()
end

-- ============================================================================
-- 星图随机事件弹窗
-- ============================================================================
local function renderEventPopup()
    if not eventPopup_ then return end
    local ev       = eventPopup_.ev
    local onChoice = eventPopup_.onChoice
    local r, g, b  = ev.color[1], ev.color[2], ev.color[3]

    -- 半透明全屏遮罩
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg_)

    -- 弹窗主体
    local panW  = math.min(screenW_ - 40, 340)
    local btnH  = 34
    local padV  = 14
    local titleH = 32
    local descH  = 36
    local choiceH = #ev.choices * (btnH + 8)
    local panH  = titleH + padV + descH + padV + choiceH + padV
    local panX  = screenW_ / 2 - panW / 2
    local panY  = screenH_ / 2 - panH / 2

    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, panX, panY, panW, panH, 10)
    nvgFillColor(vg_, nvgRGBA(6, 12, 28, 248))
    nvgFill(vg_)
    -- 边框（事件主色）
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, panX + 0.5, panY + 0.5, panW - 1, panH - 1, 10)
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, 200))
    nvgStrokeWidth(vg_, 1.5)
    nvgStroke(vg_)
    -- 顶部彩色条
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, panX, panY, panW, 4, 10)
    nvgFillColor(vg_, nvgRGBA(r, g, b, 200))
    nvgFill(vg_)

    -- 标题行（图标 + 名称）
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 15)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(r, g, b, 255))
    nvgText(vg_, screenW_ / 2, panY + 4 + titleH / 2 + 2,
        ev.icon .. "  " .. ev.label)

    -- 描述文字（可换行裁剪）
    local descY = panY + titleH + padV
    nvgFontSize(vg_, 11)
    nvgFillColor(vg_, nvgRGBA(180, 200, 230, 200))
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgTextBox(vg_, panX + 16, descY, panW - 32, ev.desc)

    -- 选项按钮
    local btnY = descY + descH + padV
    for idx, ch in ipairs(ev.choices) do
        local isCancel = (ch.cost == nil and ch.gain == nil and ch.res == nil)
        local bgR = isCancel and nvgRGBA(40, 40, 60, 180) or nvgRGBA(r//4, g//4, b//4, 200)
        local bdR = isCancel and nvgRGBA(80, 80, 120, 120) or nvgRGBA(r, g, b, 160)
        local txR = isCancel and nvgRGBA(140, 150, 180, 200) or nvgRGBA(r, g, b, 240)

        local bx = panX + 12
        local bw = panW - 24
        -- 按钮背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, btnY, bw, btnH, 6)
        nvgFillColor(vg_, bgR)
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx + 0.5, btnY + 0.5, bw - 1, btnH - 1, 6)
        nvgStrokeColor(vg_, bdR)
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
        -- 悬停高亮
        if cursorX_ >= bx and cursorX_ <= bx + bw
            and cursorY_ >= btnY and cursorY_ <= btnY + btnH then
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, bx, btnY, bw, btnH, 6)
            nvgFillColor(vg_, nvgRGBA(255, 255, 255, 18))
            nvgFill(vg_)
        end
        -- 按钮文字
        nvgFontSize(vg_, 11)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, txR)
        nvgText(vg_, bx + bw / 2, btnY + btnH / 2, ch.text)

        -- 注册点击区域
        local captureIdx = idx
        addHit(bx, btnY, bw, btnH, function()
            eventPopup_ = nil
            if onChoice then onChoice(captureIdx) end
        end)
        btnY = btnY + btnH + 8
    end
end

--- 外部接口：显示事件弹窗
---@param ev     table   事件数据（来自 GalaxyScene 的随机事件节点）
---@param onChoice function(choiceIdx) 玩家选择后的回调
function GameUI.ShowEventPopup(ev, onChoice)
    eventPopup_ = { ev = ev, onChoice = onChoice }
end

-- ============================================================================
-- 主渲染入口（每帧从 main.lua 调用）
-- ============================================================================
function GameUI.RenderHUD(dt)
    dt = dt or 0
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
        if not deployed_ then
            renderDeployHint()
        else
            -- 屏幕尺寸和光标已在帧顶部同步到 UICommon

            renderPirateWarning()
            renderIntelPanel()          -- 海盗情报面板
            renderCareerStatsPanel()    -- P2-1: 生涯战绩面板
            renderSignalPanel()         -- P3-1: 快捷信号面板
            renderCareerPage(dt)        -- P3-2: 生涯战绩全屏页面
            renderLogPanel()            -- P1-3: 任务日志面板
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
            renderMarketPanel()
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
                    renderExchangePanel(selectedPlanet_, bph)
                    renderShipyardPanel(selectedPlanet_)
                else
                    PlanetPanel.Render(selectedPlanet_, {
                        onBuild           = onBuildCb_,
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
                        onSendGift        = onSendGiftCb_,      -- P1-1
                        diplomacyState    = getDiplomacyStateCb_ and getDiplomacyStateCb_(selectedPlanet_.id), -- P1-1
                        onSetSpec         = onSetSpecCb_,       -- P2-3
                    })
                    renderShipyardPanel(selectedPlanet_)
                end
            end
        end
    end

    -- 通知中心面板（覆盖其他面板，在超时层之前）
    NotifyPanel.RenderCenter()

    -- 新手教程弹窗（在通知之后渲染，确保最高层级）
    TutorialSystem.Render()

    -- 星图随机事件弹窗（覆盖在教程之后）
    renderEventPopup()

    -- 超时覆盖层
    TimeoutPanel.Render()
    -- P2-1: 轮间选卡覆盖层（在超时层之后，结算层之前）
    if cardDraft_.visible and #cardDraft_.cards > 0 then
        local vg      = vg_
        local sw, sh  = screenW_, screenH_
        local t       = cardDraft_.animT  -- 0→1 入场插值
        -- 暗化背景
        nvgBeginPath(vg); nvgRect(vg, 0, 0, sw, sh)
        nvgFillColor(vg, nvgRGBA(0, 0, 10, math.floor(200 * t)))
        nvgFill(vg)
        -- 标题
        local titleY = sh * 0.12 + (1 - t) * 40
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(255 * t)))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, sw/2, titleY, string.format("⚡ 第 %d 轮奖励 — 选择强化卡牌", endlessRound_))
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, math.floor(200 * t)))
        nvgText(vg, sw/2, titleY + 26, "选择一张卡牌增强你的舰队")
        -- 卡牌布局
        local CARD_W, CARD_H = 170, 240
        local GAP    = 24
        local n      = #cardDraft_.cards
        local totalW = n * CARD_W + (n - 1) * GAP
        local startX = sw/2 - totalW/2
        local cardY  = sh * 0.5 - CARD_H/2 + (1 - t) * 60
        -- 稀有度颜色
        local rarityColors = {
            common   = {120, 200, 255},
            rare     = {160, 120, 255},
            epic     = {255, 180, 60},
        }
        -- 先用原始 cardY 做本帧 hover 命中检测，再进入渲染
        local newHoverIdx = 0
        for i = 1, n do
            local cx2 = startX + (i-1) * (CARD_W + GAP)
            if cursorX_ >= cx2 and cursorX_ <= cx2 + CARD_W
               and cursorY_ >= cardY - 10 and cursorY_ <= cardY + CARD_H then
                newHoverIdx = i
            end
        end
        cardDraft_.hoverIdx = newHoverIdx
        for i, card in ipairs(cardDraft_.cards) do
            local cx = startX + (i-1) * (CARD_W + GAP)
            local isHover = (cardDraft_.hoverIdx == i)
            local ry = isHover and (cardY - 10) or cardY
            local rc = rarityColors[card.rarity or "common"]
            -- 卡牌背景
            nvgBeginPath(vg); nvgRoundedRect(vg, cx, ry, CARD_W, CARD_H, 12)
            nvgFillColor(vg, nvgRGBA(12, 20, 40, 240))
            nvgFill(vg)
            -- 边框（稀有度色）
            nvgStrokeWidth(vg, isHover and 3 or 2)
            nvgStrokeColor(vg, nvgRGBA(rc[1], rc[2], rc[3], isHover and 255 or 180))
            nvgStroke(vg)
            -- P2-1 V2.0: 史诗卡金色粒子特效（沿边框环绕的闪光粒子）
            if card.rarity == "epic" then
                local gt = cardDraft_.runT or 0  -- 粒子运动累计时间
                local SPARKS = 12
                for si = 1, SPARKS do
                    local phase = (si / SPARKS) * math.pi * 2 + gt * 1.8
                    -- 沿矩形边框参数化运动
                    local perim = 2 * (CARD_W + CARD_H)
                    local pos   = ((phase % (math.pi * 2)) / (math.pi * 2)) * perim
                    local px, py
                    if pos < CARD_W then
                        px, py = cx + pos, ry
                    elseif pos < CARD_W + CARD_H then
                        px, py = cx + CARD_W, ry + (pos - CARD_W)
                    elseif pos < 2 * CARD_W + CARD_H then
                        px, py = cx + CARD_W - (pos - CARD_W - CARD_H), ry + CARD_H
                    else
                        px, py = cx, ry + CARD_H - (pos - 2 * CARD_W - CARD_H)
                    end
                    local sparkAlpha = math.floor(180 * t * (0.5 + 0.5 * math.sin(phase * 3 + si)))
                    local sparkR     = 2.0 + 1.5 * math.abs(math.sin(phase * 2 + si * 0.7))
                    nvgBeginPath(vg)
                    nvgCircle(vg, px, py, sparkR)
                    nvgFillColor(vg, nvgRGBA(255, 210, 60, sparkAlpha))
                    nvgFill(vg)
                end
                -- 史诗卡顶部金色光晕
                local glowPaint = nvgRadialGradient(vg,
                    cx + CARD_W/2, ry - 4, 0, 60,
                    nvgRGBA(255, 200, 50, math.floor(80 * t)),
                    nvgRGBA(255, 180, 0, 0))
                nvgBeginPath(vg); nvgRect(vg, cx - 10, ry - 30, CARD_W + 20, 60)
                nvgFillPaint(vg, glowPaint); nvgFill(vg)
            end
            -- 图标
            nvgFontSize(vg, 44); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(255 * t)))
            nvgText(vg, cx + CARD_W/2, ry + 62, card.icon or "★")
            -- 稀有度标签
            local rl = card.rarity == "epic" and "史诗" or card.rarity == "rare" and "稀有" or "普通"
            nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 220))
            nvgText(vg, cx + CARD_W/2, ry + 112, rl)
            -- 卡名
            nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(220, 230, 255, 240))
            nvgText(vg, cx + CARD_W/2, ry + 132, card.label or "")
            -- 描述（最多2行，手动换行）
            nvgFontSize(vg, 11); nvgFillColor(vg, nvgRGBA(160, 170, 200, 200))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local desc = card.desc or ""
            -- 简单按字数折行（每行最多14字）
            local line1, line2 = desc:sub(1, 14), desc:sub(15)
            nvgText(vg, cx + CARD_W/2, ry + 154, line1)
            if line2 ~= "" then nvgText(vg, cx + CARD_W/2, ry + 168, line2) end
            -- 选择按钮
            local btnX, btnY, btnW2, btnH2 = cx + 16, ry + CARD_H - 38, CARD_W - 32, 26
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW2, btnH2, 6)
            nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], isHover and 200 or 120))
            nvgFill(vg)
            nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
            nvgText(vg, cx + CARD_W/2, btnY + btnH2/2, "选择")
            -- 注册点击热区（t 足够大才响应）
            if t > 0.5 then
                addHit(cx, ry, CARD_W, CARD_H, function()
                    if cardDraft_.onSelect then cardDraft_.onSelect(card.key) end
                    cardDraft_.visible = false
                end)
            end
        end
    end
    -- 结算覆盖层（最顶层，覆盖超时层）
    EndGamePanel.Render()
    -- 排行榜浮层（覆盖在结算层之上）
    EndGamePanel.RenderLeaderboard()
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
            logVisible_ = not logVisible_
            logScroll_  = 0
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
    end
end

-- ============================================================================
-- Refresh 接口（供 main.lua 调用，更新缓存数据）
-- ============================================================================
function GameUI.RefreshResourceBar()
    -- 资源在 RenderTopBar 里实时读取，无需缓存
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

-- P2-1: 展示无尽模式选卡面板
-- cards: [{key, icon, label, desc, rarity}], onSelect: function(cardKey)
function GameUI.ShowCardDraft(cards, onSelect)
    cardDraft_.visible  = true
    cardDraft_.cards    = cards or {}
    cardDraft_.onSelect = onSelect
    cardDraft_.hoverIdx = 0
    cardDraft_.animT    = 0
    cardDraft_.runT     = 0  -- P2-1 V2.0: 重置粒子动画时间
end

-- P2-1: 隐藏选卡面板
function GameUI.HideCardDraft()
    cardDraft_.visible  = false
    cardDraft_.cards    = {}
    cardDraft_.onSelect = nil
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
    careerStats_UI_.totalGames    = stats.totalGames    or 0
    careerStats_UI_.totalWins     = stats.totalWins     or 0
    careerStats_UI_.bestWave      = stats.bestWave      or 0
    careerStats_UI_.totalKills    = stats.totalKills    or 0
    careerStats_UI_.totalColonies = stats.totalColonies or 0
    careerStats_UI_.bestMvpShip   = stats.bestMvpShip   or ""
    careerStats_UI_.playtime      = stats.playtime      or 0
    EndGamePanel.SetCareerStats(stats)   -- P3-1: 同步生涯数据到个人主页弹窗
end

-- ============================================================================
-- 场景切换
-- ============================================================================
function GameUI.ShowScene(scene, hasPlanet)
    currentScene_ = scene
    hasPlanet_    = hasPlanet == true
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
    onBaseBuildCb_      = opts.onBaseBuildCb
    onCoreUpgradeCb_    = opts.onCoreUpgradeCb
    onResearchCb_       = opts.onResearchCb
    onMarketCb_         = opts.onMarketCb
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
    onSetSpecCb_            = opts.onSetSpec             -- P2-3: 设置建筑专精
    getConquestProgress_   = opts.getConquestProgress
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
    logVisible_         = false
    logTab_             = "goals"
    logScroll_          = 0
    exploreLog_         = {}
    completedGoals_UI_  = {}
    -- P2-1: 重置战绩面板开合状态（数据保留，面板默认关闭）
    statsVisible_       = false
    -- P3-1: 重置信号面板状态
    signalOpen_         = false
    signalCooldown_     = 0

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
        clr       = clr,
        clrC      = clrC,
        panel     = panel,
        text      = text,
        addHit    = addHit,
        addScroll = addScroll,
    })

    print("[GameUI] 初始化完成（纯NanoVG模式）")
end

function GameUI.Shutdown()
    -- 清空动画状态，防止旧数据干扰下一局
    displayRes_ = {}
    flashRes_   = {}
    ripples_    = {}
    eventPopup_ = nil
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
    careerPageOpen_ = true
    statsVisible_   = false   -- 关闭小浮动面板，避免遮挡
end

function GameUI.HideCareerPage()
    careerPageOpen_ = false
end

return GameUI
