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
local TutorialSystem = require("game.ui.TutorialSystem")

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
local onExplorerColonizeCb_ = nil
local explorerColonizeMode_  = false   -- 高亮提示玩家点击未殖民星球
local onFleetSelectCb_    = nil
local onFleetMoveShipCb_  = nil
local onAssignReserveCb_  = nil
local onSpeedUpBuildCb_   = nil   -- 星币加速建造
local onBuyNuclearCb_     = nil   -- 星币购买核能
local getConquestProgress_ = nil  -- 返回 {colonized, total, piratesKilled, piratesTotal}

-- 海盗预警状态
local pirateWarningTime_  = math.huge  -- 最近一次进攻倒计时（秒），math.huge 表示无威胁
local PIRATE_WARN_THRESH  = 30         -- 倒计时 ≤ 30 秒时显示预警
local pirateWarnBlink_    = 0          -- 闪烁计时器

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

-- ============================================================================
-- 资源数字滚动动画（P3-3）
-- displayRes_[res] = 当前显示值（向真实值平滑靠近）
-- flashRes_[res]   = {timer, dir} dir: 1=增加(绿), -1=减少(红)
-- ============================================================================
local displayRes_ = {}   -- 显示值（浮点，渲染时 floor）
local flashRes_   = {}   -- { timer=0.6, dir=1/-1 }
local SCROLL_SPEED_FACTOR = 8.0   -- 每秒追赶 (real-display)*factor
local FLASH_DURATION      = 0.55  -- 闪光持续秒数

-- 按钮点击涟漪效果
-- ripples_[i] = { x, y, r, maxR, timer, maxTimer }
local ripples_         = {}
local RIPPLE_DURATION  = 0.35   -- 涟漪扩散时长（秒）
local RIPPLE_MAX_R     = 28     -- 最大涟漪半径（像素）

-- ============================================================================
-- 游戏时间限制
-- ============================================================================
local timeoutActive_    = false   -- 是否显示超时覆盖层
local timeoutAdCount_   = 0       -- 剩余可看广告次数（最多2次）
local timeoutOnWatch_   = nil     -- 点击"看广告"后的回调
-- 剩余在线时间（由 Client.lua 更新，秒）
local remainingTime_    = 7200    -- 默认2小时

-- ============================================================================
-- 结算界面
-- ============================================================================
local endGameActive_   = false
local endGameType_     = nil    -- "win" | "lose"
local endGameStats_    = {}     -- { playTime, colonized, piratesKilled, rank, level }
local endGameOnRetry_  = nil    -- 点击"再来一局"回调
local endGameAnimT_    = 0      -- 进场动画计时器

-- ============================================================================
-- 排行榜面板
-- ============================================================================
local lbVisible_       = false  -- 排行榜面板是否显示
local lbData_          = nil    -- 排行榜数据 [{rank,nickname,score,isMe}]
local lbLoading_       = false  -- 是否正在加载
local lbMyRank_        = nil    -- 我的排名（number 或 nil）
local lbMyScore_       = nil    -- 我的分数
local lbOnRequest_     = nil    -- 拉取排行榜的回调（由 Client.lua 注入）

-- ============================================================================
-- 设置面板
-- ============================================================================
local settingsVisible_  = false   -- 设置面板是否打开
local settingsBgmVol_   = 0.7     -- BGM 音量 0-1
local settingsSfxVol_   = 1.0     -- SFX 音量 0-1
local settingsMute_     = false   -- 全局静音
-- 滑块拖拽状态
local settingsDragSlider_ = nil   -- "bgm" | "sfx" | nil
local SETTINGS_FILE = "galaxy_settings.json"

local function saveSettings()
    local cjson = require "cjson"
    local data = cjson.encode({
        bgmVolume = settingsBgmVol_,
        sfxVolume = settingsSfxVol_,
        mute      = settingsMute_,
    })
    local f = File(SETTINGS_FILE, FILE_WRITE)
    if f:IsOpen() then f:WriteString(data); f:Close() end
end

local function loadSettings()
    if not fileSystem:FileExists(SETTINGS_FILE) then return end
    local f = File(SETTINGS_FILE, FILE_READ)
    if not f:IsOpen() then return end
    local raw = f:ReadString(); f:Close()
    local ok, data = pcall(require("cjson").decode, raw)
    if not ok or type(data) ~= "table" then return end
    settingsBgmVol_ = tonumber(data.bgmVolume) or settingsBgmVol_
    settingsSfxVol_ = tonumber(data.sfxVolume) or settingsSfxVol_
    settingsMute_   = data.mute == true
    Audio.SetBGMVolume(settingsBgmVol_)
    Audio.SetSFXVolume(settingsSfxVol_)
    Audio.SetMute(settingsMute_)
end

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
    -- 海盗预警闪烁
    if pirateWarningTime_ <= PIRATE_WARN_THRESH then
        pirateWarnBlink_ = pirateWarnBlink_ + dt
    end
    if slotFlashTimer_ > 0 then
        slotFlashTimer_ = slotFlashTimer_ - dt
    end
    -- 结算界面进场动画
    if endGameActive_ and endGameAnimT_ < 1 then
        endGameAnimT_ = math.min(1, endGameAnimT_ + dt * 1.5)
    end
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
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth()  / dpr
    screenH_ = graphics:GetHeight() / dpr

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
        nvgFillColor(vg_, nvgRGBA(c[1], c[2], c[3], bgA)); nvgFill(vg_)
        nvgStrokeColor(vg_, nvgRGBA(c[1], c[2], c[3], bdA)); nvgStrokeWidth(vg_, 0.5); nvgStroke(vg_)
        nvgFillColor(vg_, nvgRGBA(txR, txG, txB, txA))
        nvgText(vg_, rzX + 1, rzYs[j], label)
    end

    -- ── 右区布局（从右往左，间距 8px，不重叠）──
    -- 🔔 铃铛：screenW-8 ~ screenW-36（宽28）
    -- ⚙  设置：screenW-42 ~ screenW-70（宽28）
    -- 星币区：screenW-76 ~ screenW-156（宽80，图标14+标签+数值）
    -- 玩家信息：screenW-162 ~ screenW-280（右对齐于 screenW-162）

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
        local isOpen = settingsVisible_
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

    -- 星币（设置按钮左边，间距 6px）
    local credits = math.floor(rm_.resources.credits or 0)
    local credX = screenW_ - 156
    local credIconH = resIcons_["credits"]
    if credIconH and credIconH >= 0 then
        local paint = nvgImagePattern(vg_, credX, rowMid - 7, 14, 14, 0, credIconH, 1.0)
        nvgBeginPath(vg_); nvgRect(vg_, credX, rowMid - 7, 14, 14)
        nvgFillPaint(vg_, paint); nvgFill(vg_)
    end
    text(credX + 17, rowMid - 6, "星币", 9, 255,210,60,200)
    text(credX + 17, rowMid + 6, tostring(credits), 10, 255,230,80,255)

    -- 玩家信息 + 在线时限（星币左边，右对齐于 credX-6）
    local infoRightX = credX - 6
    -- 在线时限
    local rtSec     = math.max(0, math.floor(remainingTime_))
    local rtMin     = math.floor(rtSec / 60)
    local rtSecPart = rtSec % 60
    local rtStr
    if rtMin >= 60 then
        rtStr = string.format("⏱%d:%02d:00", math.floor(rtMin/60), rtMin%60)
    else
        rtStr = string.format("⏱%02d:%02d", rtMin, rtSecPart)
    end
    local isLowTime = rtMin < 30
    local tr = isLowTime and 255 or 100
    local tg = isLowTime and 80  or 200
    local tb = isLowTime and 60  or 120
    if rtMin < 5 then
        local blink = math.floor(os.clock() * 2) % 2 == 0
        tr, tg, tb = blink and 255 or 200, blink and 60 or 80, blink and 60 or 60
    end
    text(infoRightX, rowMid - 6, player_.name .. " Lv." .. player_.level, 9,
        160,210,255,210, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
    text(infoRightX, rowMid + 6, rtStr, 9, tr, tg, tb, 220, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)

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
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth() / dpr
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

    for _, res in ipairs({"metal","esource","nuclear"}) do
        local r     = ms_.rates[res]
        local c     = RES_COLORS[res]
        local trend = ms_:getTrend(res)
        -- 趋势颜色：↑绿 ↓红 →灰
        local tr,tg,tb = 150,150,150
        if trend == "↑" then tr,tg,tb = 50,230,100
        elseif trend == "↓" then tr,tg,tb = 255,80,80 end
        -- 资源名 + 趋势箭头
        text(px+10, sy+9, RES_LABELS[res], 10, c[1]+40,c[2]+40,c[3]+40,230)
        text(px+60, sy+9, trend, 12, tr,tg,tb,255)
        -- 卖/买价格
        text(px+78, sy+9,
            "卖:" .. string.format("%.1f", r.sell) .. "★  买:" .. string.format("%.1f", r.buy) .. "★",
            10, c[1]+20,c[2]+20,c[3]+20,210)
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

    -- 队列状态
    if spq_ and #spq_.items > 0 then
        -- 第一条：正在生产，带进度条
        local job = spq_.items[1]
        local pct = job.progress or 0
        local lbl = "生产: "..SHIP_TYPES[job.shipType].name.." "..math.floor(pct*100).."%"
        progressBar(px+8, sy, pw-16, 12, pct, lbl, 100,160,255)
        sy = sy + 16
        -- 后续等待条目
        if #spq_.items > 1 then
            nvgBeginPath(vg_); nvgMoveTo(vg_, px+6, sy+2); nvgLineTo(vg_, px+pw-6, sy+2)
            nvgStrokeColor(vg_, clr(60,120,200,40)); nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
            sy = sy + 8
            for i = 2, #spq_.items do
                local q  = spq_.items[i]
                local st = SHIP_TYPES[q.shipType]
                -- 序号圆点
                nvgBeginPath(vg_)
                nvgCircle(vg_, px+14, sy+6, 4)
                nvgFillColor(vg_, nvgRGBA(st.color[1], st.color[2], st.color[3], 200))
                nvgFill(vg_)
                text(px+24, sy+6, (i-1)..". "..st.name, 10, 160,180,220,200)
                sy = sy + 16
            end
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
-- 结算覆盖层
-- ============================================================================
local function renderEndGameOverlay()
    if not endGameActive_ then return end

    local isWin = (endGameType_ == "win")
    -- smoothstep 进场
    local t = endGameAnimT_
    local ease = t * t * (3 - 2 * t)

    -- 全屏遮罩（随动画淡入）
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, math.floor(180 * ease)))
    nvgFill(vg_)

    -- 面板尺寸
    local dw, dh = 480, 340
    local dx = (screenW_ - dw) / 2
    -- 从屏幕下方滑入
    local dy = (screenH_ - dh) / 2 + (1 - ease) * screenH_ * 0.3

    -- 发光边框
    local glowR, glowG, glowB = isWin and 80 or 220, isWin and 220 or 50, isWin and 60 or 50
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, dx-3, dy-3, dw+6, dh+6, 16)
    nvgFillColor(vg_, nvgRGBA(glowR, glowG, glowB, math.floor(70 * ease)))
    nvgFill(vg_)

    -- 面板背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, dx, dy, dw, dh, 14)
    nvgFillColor(vg_, nvgRGBA(8, 10, 22, 252))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(glowR, glowG, glowB, math.floor(220 * ease)))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)

    -- 大图标
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 44)
    nvgFillColor(vg_, nvgRGBA(glowR+40, glowG+40, glowB+40, math.floor(255 * ease)))
    nvgText(vg_, screenW_ / 2, dy + 56, isWin and "🏆" or "💀")

    -- 主标题
    nvgFontSize(vg_, 22)
    nvgFillColor(vg_, nvgRGBA(glowR+60, glowG+60, glowB+60, math.floor(255 * ease)))
    nvgText(vg_, screenW_ / 2, dy + 102, isWin and "银河征服完成！" or "帝国覆灭")

    -- 副标题
    nvgFontSize(vg_, 12)
    nvgFillColor(vg_, nvgRGBA(160, 180, 220, math.floor(200 * ease)))
    nvgText(vg_, screenW_ / 2, dy + 124,
        isWin and "你已消灭所有海盗势力，统一银河！" or "星航基地已被摧毁，帝国就此终结。")

    -- 分割线
    local lx1, lx2, ly = dx + 30, dx + dw - 30, dy + 138
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, lx1, ly); nvgLineTo(vg_, lx2, ly)
    nvgStrokeColor(vg_, nvgRGBA(glowR, glowG, glowB, math.floor(80 * ease)))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- 统计数据（两列）
    local stats = endGameStats_ or {}
    local function fmtTime(s)
        local m = math.floor((s or 0) / 60)
        local sec = math.floor((s or 0) % 60)
        return string.format("%d分%02d秒", m, sec)
    end
    local rows = {
        { label="游戏时长",   value=fmtTime(stats.playTime) },
        { label="殖民星球",   value=tostring(stats.colonized or 0) .. " 颗" },
        { label="击败海盗",   value=tostring(stats.piratesKilled or 0) .. " 次" },
        { label="最终等级",   value="Lv." .. tostring(stats.level or 1) .. "  [" .. (stats.rank or "见习指挥官") .. "]" },
    }
    local sy = dy + 152
    for _, row in ipairs(rows) do
        nvgFontSize(vg_, 11)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(120, 150, 200, math.floor(180 * ease)))
        nvgText(vg_, dx + 60, sy + 7, row.label)
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(200, 220, 255, math.floor(230 * ease)))
        nvgText(vg_, dx + dw - 60, sy + 7, row.value)
        sy = sy + 22
    end

    -- 分割线2
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, lx1, sy + 4); nvgLineTo(vg_, lx2, sy + 4)
    nvgStrokeColor(vg_, nvgRGBA(60, 80, 140, math.floor(80 * ease)))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    sy = sy + 14

    -- 再来一局按钮
    local bw, bh = 200, 44
    local bx = (screenW_ - bw) / 2
    local by = dy + dh - 60

    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx, by, bw, bh, 8)
    nvgFillColor(vg_, nvgRGBA(
        isWin and 30 or 160,
        isWin and 120 or 40,
        isWin and 200 or 40,
        math.floor(220 * ease)))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(
        isWin and 80 or 220,
        isWin and 180 or 80,
        isWin and 255 or 80,
        math.floor(200 * ease)))
    nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)

    nvgFontSize(vg_, 14)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(220, 235, 255, math.floor(255 * ease)))
    nvgText(vg_, screenW_ / 2, by + bh / 2, "🔄  再来一局")

    if ease > 0.8 then
        addHit(bx, by, bw, bh, function()
            if endGameOnRetry_ then endGameOnRetry_() end
        end)
    end

    -- 排行榜按钮（位于再来一局按钮上方）
    local lbw, lbh = 160, 34
    local lbx = (screenW_ - lbw) / 2
    local lby = by - lbh - 10

    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, lbx, lby, lbw, lbh, 7)
    nvgFillColor(vg_, nvgRGBA(40, 30, 80, math.floor(200 * ease)))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(120, 80, 220, math.floor(180 * ease)))
    nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)
    nvgFontSize(vg_, 12)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(180, 150, 255, math.floor(240 * ease)))
    nvgText(vg_, screenW_ / 2, lby + lbh / 2, "🏅  银河排行榜")

    if ease > 0.8 then
        addHit(lbx, lby, lbw, lbh, function()
            lbVisible_ = true
            lbLoading_ = true
            lbData_    = nil
            lbMyRank_  = nil
            lbMyScore_ = nil
            if lbOnRequest_ then
                lbOnRequest_(function(data, myRank, myScore)
                    lbData_    = data
                    lbMyRank_  = myRank
                    lbMyScore_ = myScore
                    lbLoading_ = false
                end)
            else
                lbLoading_ = false
            end
        end)
    end
end

-- ============================================================================
-- 排行榜面板渲染
-- ============================================================================
local function renderLeaderboard()
    if not lbVisible_ then return end

    -- 全屏半透明遮罩
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, 180))
    nvgFill(vg_)

    local pw = math.min(420, screenW_ - 40)
    local ph = math.min(520, screenH_ - 40)
    local px = (screenW_ - pw) / 2
    local py = (screenH_ - ph) / 2

    -- 面板背景光晕
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px - 2, py - 2, pw + 4, ph + 4, 14)
    nvgFillColor(vg_, nvgRGBA(80, 50, 180, 60))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, pw, ph, 12)
    nvgFillColor(vg_, nvgRGBA(8, 5, 22, 248))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(100, 70, 200, 200))
    nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 16)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(180, 150, 255, 255))
    nvgText(vg_, px + pw / 2, py + 22, "🏅  银河征服 · 排行榜")

    -- 分割线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 20, py + 36); nvgLineTo(vg_, px + pw - 20, py + 36)
    nvgStrokeColor(vg_, nvgRGBA(80, 60, 160, 120))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- 我的排名固定栏
    local listY = py + 44
    if lbMyRank_ or lbMyScore_ then
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, px + 10, listY, pw - 20, 20, 4)
        nvgFillColor(vg_, nvgRGBA(60, 40, 120, 160)); nvgFill(vg_)
        nvgFontSize(vg_, 10)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(180, 150, 255, 220))
        local rankStr = lbMyRank_ and string.format("我的排名: #%d", lbMyRank_) or "我的排名: 未上榜"
        nvgText(vg_, px + 16, listY + 10, rankStr)
        if lbMyScore_ then
            nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255, 220, 100, 220))
            nvgText(vg_, px + pw - 16, listY + 10, string.format("得分: %d", lbMyScore_))
        end
        listY = listY + 28
    end

    local rowH = 28
    local rankColors = { {255,215,0}, {192,192,192}, {205,127,50} }

    if lbLoading_ then
        nvgFontSize(vg_, 13)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(140, 120, 200, 200))
        nvgText(vg_, px + pw / 2, listY + 60, "加载中...")
    elseif not lbData_ or #lbData_ == 0 then
        nvgFontSize(vg_, 13)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(120, 100, 160, 180))
        nvgText(vg_, px + pw / 2, listY + 60, "暂无排行榜数据")
    else
        -- 表头
        nvgFontSize(vg_, 9)
        nvgFillColor(vg_, nvgRGBA(100, 90, 150, 180))
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg_, px + 16, listY + 6, "排名  指挥官")
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg_, px + pw - 16, listY + 6, "得分")
        listY = listY + 16

        local maxRows = math.floor((py + ph - 50 - listY) / rowH)
        for i, entry in ipairs(lbData_) do
            if i > maxRows then break end
            local ry = listY + (i - 1) * rowH

            if entry.isMe then
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px + 8, ry + 1, pw - 16, rowH - 2, 4)
                nvgFillColor(vg_, nvgRGBA(60, 40, 130, 140)); nvgFill(vg_)
            elseif i % 2 == 0 then
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, px + 8, ry + 1, pw - 16, rowH - 2, 4)
                nvgFillColor(vg_, nvgRGBA(20, 15, 45, 80)); nvgFill(vg_)
            end

            local rc = rankColors[entry.rank] or {160, 150, 200}
            nvgFontSize(vg_, entry.rank <= 3 and 13 or 11)
            nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(rc[1], rc[2], rc[3], 255))
            local medal = entry.rank == 1 and "🥇"
                       or entry.rank == 2 and "🥈"
                       or entry.rank == 3 and "🥉"
                       or string.format("#%d", entry.rank)
            nvgText(vg_, px + 16, ry + rowH / 2, medal)

            nvgFontSize(vg_, 11)
            nvgFillColor(vg_, entry.isMe
                and nvgRGBA(220, 200, 255, 255)
                or  nvgRGBA(180, 170, 210, 220))
            local nameX = entry.rank <= 9 and (px + 46) or (px + 52)
            local name = entry.nickname or ("玩家" .. tostring(entry.userId or "?"))
            nvgText(vg_, nameX, ry + rowH / 2, name .. (entry.isMe and " ★" or ""))

            nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255, 220, 100, 230))
            nvgText(vg_, px + pw - 16, ry + rowH / 2, tostring(entry.score or 0))
        end
    end

    -- 关闭按钮
    local cbw, cbh = 120, 32
    local cbx = (screenW_ - cbw) / 2
    local cby = py + ph - cbh - 12
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cbx, cby, cbw, cbh, 7)
    nvgFillColor(vg_, nvgRGBA(40, 30, 80, 200)); nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(100, 70, 180, 160))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    nvgFontSize(vg_, 12)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(160, 140, 220, 240))
    nvgText(vg_, screenW_ / 2, cby + cbh / 2, "关闭")
    addHit(cbx, cby, cbw, cbh, function()
        lbVisible_ = false
    end)
end

-- ============================================================================
-- 设置面板
-- ============================================================================
-- 滑块拖拽上下文（trackX/trackW 用于每帧计算值）
local settingsDragCtx_ = { trackX = 0, trackW = 1 }

local function renderSettingsPanel()
    if not settingsVisible_ then return end

    -- 处理滑块拖拽（每帧检测鼠标按键状态）
    if settingsDragSlider_ then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local newVal = math.max(0, math.min(1,
                (cursorX_ - settingsDragCtx_.trackX) / settingsDragCtx_.trackW))
            if settingsDragSlider_ == "bgm" then
                settingsBgmVol_ = newVal
                Audio.SetBGMVolume(newVal)
            elseif settingsDragSlider_ == "sfx" then
                settingsSfxVol_ = newVal
                Audio.SetSFXVolume(newVal)
            end
        else
            -- 鼠标松开，保存并结束拖拽
            saveSettings()
            settingsDragSlider_ = nil
        end
    end

    -- 全屏半透明遮罩（点击遮罩关闭面板）
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg_)
    addHit(0, 0, screenW_, screenH_, function()
        settingsVisible_ = false
    end)

    -- 面板尺寸和位置（居中）
    local pw, ph = 340, 280
    local px = (screenW_ - pw) / 2
    local py = (screenH_ - ph) / 2

    -- 面板背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, pw, ph, 12)
    nvgFillColor(vg_, nvgRGBA(8, 12, 30, 245)); nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(80, 140, 255, 200))
    nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
    -- 面板内部点击不传到遮罩
    addHit(px, py, pw, ph, function() end)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 16)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(100, 200, 255, 255))
    nvgText(vg_, px + pw / 2, py + 24, "⚙  游戏设置")

    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 16, py + 40)
    nvgLineTo(vg_, px + pw - 16, py + 40)
    nvgStrokeColor(vg_, nvgRGBA(60, 100, 180, 80))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- 辅助函数：绘制带标签的水平滑块
    -- 返回：用户点击/拖拽后的新值（nil 表示没有交互）
    local function drawSlider(label, val, sx, sy, sw, sh, key)
        -- 标签
        nvgFontSize(vg_, 11)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(160, 200, 255, 220))
        nvgText(vg_, sx, sy + sh / 2, label)

        -- 百分比文字（右端）
        local pctStr = string.format("%d%%", math.floor(val * 100))
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(120, 180, 255, 200))
        nvgText(vg_, sx + sw, sy + sh / 2, pctStr)

        -- 滑槽
        local trackX = sx + 70
        local trackW = sw - 70 - 36
        local trackY = sy + sh / 2
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, trackX, trackY - 3, trackW, 6, 3)
        nvgFillColor(vg_, nvgRGBA(30, 50, 90, 200)); nvgFill(vg_)

        -- 已填充段
        local fillW = trackW * val
        if fillW > 1 then
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, trackX, trackY - 3, fillW, 6, 3)
            nvgFillColor(vg_, nvgRGBA(60, 160, 255, 220)); nvgFill(vg_)
        end

        -- 滑块圆点（拖拽中高亮）
        local thumbX  = trackX + fillW
        local isDragging = (settingsDragSlider_ == key)
        nvgBeginPath(vg_); nvgCircle(vg_, thumbX, trackY, isDragging and 9 or 7)
        nvgFillColor(vg_, isDragging and nvgRGBA(180, 230, 255, 255) or nvgRGBA(120, 200, 255, 255))
        nvgFill(vg_)
        nvgStrokeColor(vg_, nvgRGBA(200, 230, 255, 220))
        nvgStrokeWidth(vg_, isDragging and 2 or 1.5); nvgStroke(vg_)

        -- 点击/拖拽起始区域（整个滑槽 + 圆点区域）
        addHit(trackX - 8, trackY - 12, trackW + 16, 24, function()
            -- 鼠标按下：立即更新值并开启拖拽
            local newVal = math.max(0, math.min(1, (cursorX_ - trackX) / trackW))
            if key == "bgm" then
                settingsBgmVol_ = newVal
                Audio.SetBGMVolume(newVal)
            elseif key == "sfx" then
                settingsSfxVol_ = newVal
                Audio.SetSFXVolume(newVal)
            end
            -- 记录拖拽状态（松开时 renderSettingsPanel 保存设置）
            settingsDragSlider_ = key
            settingsDragCtx_.trackX = trackX
            settingsDragCtx_.trackW = trackW
        end)
    end

    -- BGM 音量滑块
    local rowH   = 40
    local slotX  = px + 16
    local slotW  = pw - 32
    local row1Y  = py + 52

    drawSlider("BGM 音乐", settingsBgmVol_, slotX, row1Y, slotW, rowH, "bgm")

    -- SFX 音量滑块
    local row2Y = row1Y + rowH + 8
    drawSlider("SFX 音效", settingsSfxVol_, slotX, row2Y, slotW, rowH, "sfx")

    -- 静音开关
    local row3Y  = row2Y + rowH + 12
    local togW, togH = 52, 26
    local togX   = px + pw - 16 - togW
    local togY   = row3Y + 4

    nvgFontSize(vg_, 11)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(160, 200, 255, 220))
    nvgText(vg_, slotX, togY + togH / 2, "全局静音")

    -- 开关背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, togX, togY, togW, togH, togH / 2)
    nvgFillColor(vg_, settingsMute_ and nvgRGBA(60,160,255,200) or nvgRGBA(30,50,90,200))
    nvgFill(vg_)
    nvgStrokeColor(vg_, settingsMute_ and nvgRGBA(100,200,255,180) or nvgRGBA(60,100,180,100))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    -- 开关圆点
    local dotX = settingsMute_ and (togX + togW - togH/2 - 2) or (togX + togH/2 + 2)
    nvgBeginPath(vg_); nvgCircle(vg_, dotX, togY + togH/2, togH/2 - 3)
    nvgFillColor(vg_, nvgRGBA(220, 240, 255, 255)); nvgFill(vg_)
    -- 开关文字
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, settingsMute_ and nvgRGBA(255,255,255,200) or nvgRGBA(100,140,200,180))
    nvgText(vg_, togX + togW/2, togY + togH/2, settingsMute_ and "ON" or "OFF")
    addHit(togX, togY, togW, togH, function()
        settingsMute_ = not settingsMute_
        Audio.SetMute(settingsMute_)
        saveSettings()
    end)

    -- 分隔线（按钮上方）
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 16, py + ph - 48)
    nvgLineTo(vg_, px + pw - 16, py + ph - 48)
    nvgStrokeColor(vg_, nvgRGBA(60, 100, 180, 60))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- 关闭按钮
    local cbw, cbh = 120, 32
    local cbx = px + (pw - cbw) / 2
    local cby = py + ph - cbh - 10
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cbx, cby, cbw, cbh, 7)
    nvgFillColor(vg_, nvgRGBA(20, 60, 140, 200)); nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(80, 140, 255, 160))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
    nvgFontSize(vg_, 12)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(180, 220, 255, 240))
    nvgText(vg_, cbx + cbw / 2, cby + cbh / 2, "关闭")
    addHit(cbx, cby, cbw, cbh, function()
        settingsVisible_ = false
    end)
end

-- ============================================================================
-- 游戏超时覆盖层
-- ============================================================================
local function renderTimeoutOverlay()
    if not timeoutActive_ then return end

    -- 全屏半透明遮罩
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, 200))
    nvgFill(vg_)

    -- 中心对话框
    local dw, dh = 460, 280
    local dx = (screenW_ - dw) / 2
    local dy = (screenH_ - dh) / 2

    -- 边框发光效果
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, dx-2, dy-2, dw+4, dh+4, 14)
    nvgFillColor(vg_, nvgRGBA(200, 60, 60, 80))
    nvgFill(vg_)

    -- 面板背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, dx, dy, dw, dh, 12)
    nvgFillColor(vg_, nvgRGBA(12, 8, 20, 250))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(200, 60, 60, 220))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)

    -- 图标（警告符号）
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 36)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(255, 80, 60, 255))
    nvgText(vg_, screenW_ / 2, dy + 50, "⏰")

    -- 标题
    nvgFontSize(vg_, 20)
    nvgFillColor(vg_, nvgRGBA(255, 100, 80, 255))
    nvgText(vg_, screenW_ / 2, dy + 90, "在线时间已到！")

    -- 说明文字
    nvgFontSize(vg_, 12)
    nvgFillColor(vg_, nvgRGBA(200, 200, 220, 220))
    nvgText(vg_, screenW_ / 2, dy + 116, "您今日的2小时免费游玩时间已用完。")
    nvgText(vg_, screenW_ / 2, dy + 135, "观看一段广告可延长1小时游玩，最多可延长2次。")

    -- 剩余次数显示
    nvgFontSize(vg_, 13)
    local countColor = timeoutAdCount_ > 0 and nvgRGBA(80,220,150,255) or nvgRGBA(150,150,160,200)
    nvgFillColor(vg_, countColor)
    nvgText(vg_, screenW_ / 2, dy + 163,
        "剩余可用次数：" .. timeoutAdCount_ .. " / 2")

    -- 看广告按钮
    if timeoutAdCount_ > 0 then
        local bw2, bh2 = 220, 44
        local bx2 = (screenW_ - bw2) / 2
        local by2 = dy + dh - 90

        -- 按钮背景渐变感
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx2, by2, bw2, bh2, 8)
        nvgFillColor(vg_, nvgRGBA(40, 160, 80, 230))
        nvgFill(vg_)
        nvgStrokeColor(vg_, nvgRGBA(80, 240, 120, 200))
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)

        nvgFontSize(vg_, 14)
        nvgFillColor(vg_, nvgRGBA(220, 255, 230, 255))
        nvgText(vg_, screenW_ / 2, by2 + bh2 / 2, "▶  观看广告 延长1小时")

        addHit(bx2, by2, bw2, bh2, function()
            if timeoutOnWatch_ then timeoutOnWatch_() end
        end)
    else
        -- 无广告次数
        nvgFontSize(vg_, 12)
        nvgFillColor(vg_, nvgRGBA(160, 160, 160, 200))
        nvgText(vg_, screenW_ / 2, dy + dh - 68, "今日广告延时次数已用完，请明天再来。")
    end

    -- 退出说明（小字）
    nvgFontSize(vg_, 10)
    nvgFillColor(vg_, nvgRGBA(120, 120, 140, 160))
    nvgText(vg_, screenW_ / 2, dy + dh - 20,
        "已自动断开服务器。感谢游玩《银河征服》！")
end

-- ============================================================================
-- 主渲染入口（每帧从 main.lua 调用）
-- ============================================================================
function GameUI.RenderHUD()
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth()  / dpr
    screenH_ = graphics:GetHeight() / dpr
    -- 更新鼠标位置（用于按钮悬停判断）
    local mpos = input:GetMousePosition()
    cursorX_ = mpos.x / dpr
    cursorY_ = mpos.y / dpr
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
            TechPanel.Render({
                selectedPlanet = selectedPlanet_,
                onResearch     = onResearchCb_,
            })
            renderMarketPanel()
            FleetPanel.Render({
                explorerColonizeMode = explorerColonizeMode_,
                onFleetSelect        = onFleetSelectCb_,
                onFleetMoveShip      = onFleetMoveShipCb_,
                onExplorerColonize   = onExplorerColonizeCb_,
                onAssignReserve      = onAssignReserveCb_,
                baseBonus            = rm_ and rm_.baseBonus or nil,
            })
            if hasPlanet_ and selectedPlanet_ then
                if selectedPlanet_.isBase then
                    local bph = BasePanel.Render(selectedPlanet_, {
                        onBuild          = onBaseBuildCb_,
                        onCoreUpgrade    = onCoreUpgradeCb_,
                        onSpeedUpBuild   = onSpeedUpBuildCb_,
                        slotFlashTimer   = slotFlashTimer_,
                        slotFlashDuration= SLOT_FLASH_DURATION,
                        progressBar      = progressBar,
                        shipyardMult     = rm_ and rm_.baseBonus and rm_.baseBonus.shipyardMult or 1.0,
                    })
                    renderExchangePanel(selectedPlanet_, bph)
                    renderShipyardPanel(selectedPlanet_)
                else
                    PlanetPanel.Render(selectedPlanet_, {
                        onBuild        = onBuildCb_,
                        onSpeedUpBuild = onSpeedUpBuildCb_,
                        progressBar    = progressBar,
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

    -- 超时覆盖层
    renderTimeoutOverlay()
    -- 结算覆盖层（最顶层，覆盖超时层）
    renderEndGameOverlay()
    -- 排行榜浮层（覆盖在结算层之上）
    renderLeaderboard()
    -- 设置面板（最顶层，任何时候均可打开）
    renderSettingsPanel()
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

    -- 顶栏按钮命中区：在所有面板之后注册，确保最高优先级（不被任何面板遮挡）
    -- 设置面板打开时全屏遮罩已覆盖，无需额外处理
    if not settingsVisible_ then
        -- 铃铛按钮
        addHit(screenW_ - 36, 6, 28, 28, function() NotifyPanel.Toggle() end)
        -- 设置按钮（扩大热区到 36×36，中心不变）
        addHit(screenW_ - 76, 2, 36, 36, function()
            settingsVisible_ = not settingsVisible_
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


function GameUI.RefreshShipyardPanel()
    -- 实时读取，无需缓存
end

-- 设置探索舰殖民模式（影响提示文字和储备面板高亮）
function GameUI.SetExplorerColonizeMode(active)
    explorerColonizeMode_ = active == true
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
    onExplorerColonizeCb_   = opts.onExplorerColonizeCb
    fm_                 = opts.fm
    onFleetSelectCb_    = opts.onFleetSelectCb
    onFleetMoveShipCb_  = opts.onFleetMoveShipCb
    onAssignReserveCb_  = opts.onAssignReserveCb
    onSpeedUpBuildCb_      = opts.onSpeedUpBuildCb
    onBuyNuclearCb_        = opts.onBuyNuclearCb
    getConquestProgress_   = opts.getConquestProgress
    lbOnRequest_           = opts.onShowLeaderboard
    if opts.fm then
        FleetPanel.SetActiveId(1)
    end

    -- 加载用户设置（音量等）
    loadSettings()

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
    endGameActive_  = true
    endGameType_    = gameType
    endGameStats_   = stats or {}
    endGameOnRetry_ = onRetry
    endGameAnimT_   = 0
end

--- 隐藏结算界面（重置状态）
function GameUI.HideEndGame()
    endGameActive_ = false
    endGameType_   = nil
    endGameStats_  = {}
    endGameAnimT_  = 0
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
    timeoutActive_  = true
    timeoutAdCount_ = adCount or 0
    timeoutOnWatch_ = onWatch
end

-- 更新超时面板中的广告次数（看完广告后调用）
function GameUI.UpdateTimeoutAdCount(adCount)
    timeoutAdCount_ = adCount or 0
end

-- 隐藏超时覆盖层（如广告续时成功后调用）
function GameUI.HideTimeoutScreen()
    timeoutActive_ = false
end

-- TechPanel 每帧重绘，无需显式刷新；保留接口避免调用方报错
function GameUI.RefreshTechPanel() end

function GameUI.SetVg(vg, w, h)
    vg_ = vg; screenW_ = w; screenH_ = h
end

return GameUI
