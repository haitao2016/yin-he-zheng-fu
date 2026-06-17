-- ============================================================================
-- game/ui/ReplayPlayer.lua  -- P3-2: 战斗回放播放器面板
-- 全屏回放：时间轴拖拽 / 播放暂停 / 倍速 / 精彩标记 / 迷你战场
-- ============================================================================
local UICommon = require "game.ui.UICommon"
local BattleReplaySystem = require "game.BattleReplaySystem"

local ReplayPlayer = {}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local active_       = false
local animT_        = 0       -- 进场动画计时器 (0→1)

-- 回放播放状态
local playing_      = false   -- 是否正在播放
local speed_        = 1       -- 倍速 (1/2/4)
local currentTime_  = 0       -- 当前播放时间（秒）
local duration_     = 0       -- 总时长
local dragging_     = false   -- 是否正在拖拽时间轴

-- 缓存数据
local frames_       = {}      -- BattleReplaySystem.GetFrames()
local events_       = {}      -- BattleReplaySystem.GetEvents()
local highlights_   = {}      -- BattleReplaySystem.GetHighlights()
local mvp_          = nil     -- BattleReplaySystem.GetMVP()
local currentFrame_ = nil     -- 当前帧数据

-- 事件弹幕
local eventPopups_  = {}      -- { {text, x, y, alpha, timer} }

-- 回调
local onClose_      = nil     -- 关闭回调

-- 常量
local SPEEDS          = {1, 2, 4}
local TIMELINE_H      = 36    -- 时间轴条高度
local TIMELINE_PAD    = 50    -- 时间轴左右内边距
local MAP_MARGIN      = 60    -- 迷你地图边距
local EVENT_POPUP_DUR = 2.0   -- 事件弹幕显示时长
local MAX_POPUPS      = 4     -- 同时最多显示弹幕数

-- ============================================================================
-- 工具函数
-- ============================================================================

local function easeOutCubic(t)
    t = t - 1
    return t * t * t + 1
end

local function easeOutBack(t)
    local c = 1.7
    t = t - 1
    return t * t * ((c + 1) * t + c) + 1
end

local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

-- ============================================================================
-- 渲染：迷你战场地图
-- ============================================================================
local function renderBattleMap(vg, mapX, mapY, mapW, mapH, ease)
    -- 战场背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mapX, mapY, mapW, mapH, 8)
    nvgFillColor(vg, nvgRGBA(4, 8, 20, math.floor(240 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(40, 80, 140, math.floor(120 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 网格线（微弱）
    nvgStrokeColor(vg, nvgRGBA(20, 40, 80, math.floor(40 * ease)))
    nvgStrokeWidth(vg, 0.5)
    local gridStep = mapW / 8
    for i = 1, 7 do
        nvgBeginPath(vg)
        nvgMoveTo(vg, mapX + i * gridStep, mapY)
        nvgLineTo(vg, mapX + i * gridStep, mapY + mapH)
        nvgStroke(vg)
    end
    gridStep = mapH / 6
    for i = 1, 5 do
        nvgBeginPath(vg)
        nvgMoveTo(vg, mapX, mapY + i * gridStep)
        nvgLineTo(vg, mapX + mapW, mapY + i * gridStep)
        nvgStroke(vg)
    end

    if not currentFrame_ then
        -- 无帧数据时显示提示
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 120, 180, math.floor(160 * ease)))
        nvgText(vg, mapX + mapW / 2, mapY + mapH / 2, "按 ▶ 开始回放")
        return
    end

    -- 坐标转换：帧坐标 → 地图像素
    -- 帧中 x,y 是游戏世界坐标（大约 0~screenW, 0~screenH）
    -- 我们映射到地图区域内
    local function worldToMap(wx, wy)
        -- 假设游戏世界坐标范围约 0-867, 0-390（标准手机横屏）
        local nx = wx / 867
        local ny = wy / 390
        return mapX + nx * mapW, mapY + ny * mapH
    end

    -- 绘制敌方舰船（红色/橙色圆点）
    if currentFrame_.e then
        for _, ship in ipairs(currentFrame_.e) do
            local sx, sy = worldToMap(ship.x, ship.y)
            local radius = ship.boss and 5 or 3
            local hpRatio = (ship.maxHp > 0) and (ship.hp / ship.maxHp) or 0

            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, radius * ease)
            if ship.boss then
                nvgFillColor(vg, nvgRGBA(255, 100, 40, math.floor(220 * ease)))
            else
                local r = math.floor(lerp(100, 220, hpRatio))
                nvgFillColor(vg, nvgRGBA(r, 40, 40, math.floor(200 * ease)))
            end
            nvgFill(vg)

            -- Boss 额外光圈
            if ship.boss then
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, (radius + 2) * ease)
                nvgStrokeColor(vg, nvgRGBA(255, 140, 40, math.floor(120 * ease)))
                nvgStrokeWidth(vg, 1)
                nvgStroke(vg)
            end
        end
    end

    -- 绘制玩家舰船（蓝色/青色圆点）
    if currentFrame_.p then
        for _, ship in ipairs(currentFrame_.p) do
            local sx, sy = worldToMap(ship.x, ship.y)
            local radius = 3.5
            local hpRatio = (ship.maxHp > 0) and (ship.hp / ship.maxHp) or 0

            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, radius * ease)
            local g = math.floor(lerp(120, 220, hpRatio))
            nvgFillColor(vg, nvgRGBA(60, g, 255, math.floor(220 * ease)))
            nvgFill(vg)

            -- 护盾指示（外圈半透明蓝环）
            if ship.sh and ship.sh > 0 then
                nvgBeginPath(vg)
                nvgCircle(vg, sx, sy, (radius + 2) * ease)
                nvgStrokeColor(vg, nvgRGBA(80, 180, 255, math.floor(100 * ease)))
                nvgStrokeWidth(vg, 1)
                nvgStroke(vg)
            end
        end
    end

    -- 帧信息角标
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(80, 140, 200, math.floor(140 * ease)))
    local pCount = currentFrame_.p and #currentFrame_.p or 0
    local eCount = currentFrame_.e and #currentFrame_.e or 0
    nvgText(vg, mapX + 6, mapY + 4,
        string.format("🔵%d  🔴%d", pCount, eCount))
end

-- ============================================================================
-- 渲染：时间轴 + 控制条
-- ============================================================================
local function renderTimeline(vg, tlX, tlY, tlW, tlH, ease)
    local addHit = UICommon.addHit

    -- 时间轴背景条
    local barH = 6
    local barY = tlY + 10
    local barX = tlX + TIMELINE_PAD
    local barW = tlW - TIMELINE_PAD * 2

    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(20, 30, 50, math.floor(220 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(40, 80, 140, math.floor(100 * ease)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 已播放进度
    local progress = (duration_ > 0) and (currentTime_ / duration_) or 0
    if progress > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * progress, barH, 3)
        local grad = nvgLinearGradient(vg, barX, barY, barX + barW * progress, barY,
            nvgRGBA(40, 120, 255, math.floor(200 * ease)),
            nvgRGBA(60, 180, 255, math.floor(240 * ease)))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
    end

    -- 精彩时刻标记（金色菱形）
    for _, hl in ipairs(highlights_) do
        local hlPos = (duration_ > 0) and (hl.peakTime / duration_) or 0
        local hlX = barX + barW * hlPos
        local hlSize = 5

        nvgBeginPath(vg)
        nvgMoveTo(vg, hlX, barY - hlSize)
        nvgLineTo(vg, hlX + hlSize, barY + barH / 2)
        nvgLineTo(vg, hlX, barY + barH + hlSize)
        nvgLineTo(vg, hlX - hlSize, barY + barH / 2)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 40, math.floor(220 * ease)))
        nvgFill(vg)

        -- 点击精彩标记跳转
        addHit(hlX - 8, barY - 8, 16, barH + 16, function()
            currentTime_ = hl.peakTime
            currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
        end)
    end

    -- 播放头（圆形滑块）
    local headX = barX + barW * progress
    nvgBeginPath(vg)
    nvgCircle(vg, headX, barY + barH / 2, 7 * ease)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, math.floor(255 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 140, 255, math.floor(200 * ease)))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 时间轴拖拽区域（整个条区域）
    addHit(barX - 4, barY - 10, barW + 8, barH + 20, function()
        -- 计算鼠标在时间轴上的位置
        local mx = UICommon.cursorX / UICommon.uiScale
        local rel = (mx - barX) / barW
        rel = math.max(0, math.min(1, rel))
        currentTime_ = rel * duration_
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
    end)

    -- 控制按钮区域 (在时间条下方)
    local ctrlY = barY + barH + 8

    -- 播放/暂停按钮
    local btnSize = 24
    local playX = tlX + tlW / 2 - btnSize / 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, playX, ctrlY, btnSize, btnSize, 6)
    nvgFillColor(vg, nvgRGBA(30, 60, 100, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, math.floor(180 * ease)))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 230, 255, math.floor(240 * ease)))
    nvgText(vg, playX + btnSize / 2, ctrlY + btnSize / 2, playing_ and "⏸" or "▶")

    addHit(playX, ctrlY, btnSize, btnSize, function()
        playing_ = not playing_
    end)

    -- 倍速按钮（播放按钮右侧）
    local spdX = playX + btnSize + 12
    local spdW = 36
    nvgBeginPath(vg)
    nvgRoundedRect(vg, spdX, ctrlY + 2, spdW, btnSize - 4, 5)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(180 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 200, math.floor(150 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 220, 255, math.floor(240 * ease)))
    nvgText(vg, spdX + spdW / 2, ctrlY + btnSize / 2, speed_ .. "×")

    addHit(spdX, ctrlY, spdW, btnSize, function()
        -- 循环切换倍速
        local idx = 1
        for i, s in ipairs(SPEEDS) do
            if s == speed_ then idx = i; break end
        end
        speed_ = SPEEDS[(idx % #SPEEDS) + 1]
    end)

    -- 后退5秒按钮（播放按钮左侧）
    local backX = playX - btnSize - 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, ctrlY + 2, btnSize, btnSize - 4, 5)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(180 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 180, math.floor(150 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 200, 220, math.floor(220 * ease)))
    nvgText(vg, backX + btnSize / 2, ctrlY + btnSize / 2, "⏪")

    addHit(backX, ctrlY, btnSize, btnSize, function()
        currentTime_ = math.max(0, currentTime_ - 5)
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
    end)

    -- 前进5秒按钮（倍速右侧）
    local fwdX = spdX + spdW + 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, fwdX, ctrlY + 2, btnSize, btnSize - 4, 5)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(180 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 180, math.floor(150 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 200, 220, math.floor(220 * ease)))
    nvgText(vg, fwdX + btnSize / 2, ctrlY + btnSize / 2, "⏩")

    addHit(fwdX, ctrlY, btnSize, btnSize, function()
        currentTime_ = math.min(duration_, currentTime_ + 5)
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
    end)

    -- 时间显示（左侧当前时间 / 右侧总时长）
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 180, 220, math.floor(200 * ease)))
    nvgText(vg, barX, ctrlY + btnSize / 2, formatTime(currentTime_))

    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, barX + barW, ctrlY + btnSize / 2, formatTime(duration_))
end

-- ============================================================================
-- 渲染：事件弹幕
-- ============================================================================
local function renderEventPopups(vg, mapX, mapY, mapW, mapH, ease)
    nvgFontFace(vg, "sans")
    for i = #eventPopups_, 1, -1 do
        local popup = eventPopups_[i]
        local alpha = popup.alpha * ease
        if alpha <= 0 then
            table.remove(eventPopups_, i)
        else
            local py = mapY + mapH - 30 - (i - 1) * 20
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 背景
            local tw = nvgTextBounds(vg, 0, 0, popup.text) + 16
            nvgBeginPath(vg)
            nvgRoundedRect(vg, mapX + mapW / 2 - tw / 2, py - 9, tw, 18, 4)
            nvgFillColor(vg, nvgRGBA(10, 20, 40, math.floor(180 * alpha)))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(160 * alpha)))
            nvgStrokeWidth(vg, 0.8)
            nvgStroke(vg)
            -- 文字
            nvgFillColor(vg, nvgRGBA(255, 230, 120, math.floor(240 * alpha)))
            nvgText(vg, mapX + mapW / 2, py, popup.text)
        end
    end
end

-- ============================================================================
-- 渲染：MVP 信息栏
-- ============================================================================
local function renderMVPBanner(vg, x, y, w, ease)
    if not mvp_ then return end
    local h = 28

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(30, 20, 0, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 180, 40, math.floor(140 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(240 * ease)))
    local mvpText = string.format("⭐ MVP: %s — %s (伤害:%d 击杀:%d)",
        mvp_.stype or "?", mvp_.reason or "", mvp_.dmg or 0, mvp_.kills or 0)
    nvgText(vg, x + w / 2, y + h / 2, mvpText)
end

-- ============================================================================
-- 渲染：精彩时刻列表（侧栏）
-- ============================================================================
local function renderHighlightList(vg, lx, ly, lw, lh, ease)
    local addHit = UICommon.addHit

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, lx, ly, lw, lh, 6)
    nvgFillColor(vg, nvgRGBA(8, 14, 30, math.floor(220 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 160, math.floor(100 * ease)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(220 * ease)))
    nvgText(vg, lx + 8, ly + 6, "⭐ 精彩时刻")

    -- 列表
    local iy = ly + 24
    local itemH = 32
    for i, hl in ipairs(highlights_) do
        if iy + itemH > ly + lh then break end

        local isNear = math.abs(currentTime_ - hl.peakTime) < 1.0
        -- 条目背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, lx + 4, iy, lw - 8, itemH - 3, 4)
        if isNear then
            nvgFillColor(vg, nvgRGBA(40, 60, 20, math.floor(200 * ease)))
        else
            nvgFillColor(vg, nvgRGBA(12, 20, 40, math.floor(180 * ease)))
        end
        nvgFill(vg)

        -- 时间标签
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(100, 180, 255, math.floor(200 * ease)))
        nvgText(vg, lx + 10, iy + 3, formatTime(hl.peakTime))

        -- 描述
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(180, 210, 240, math.floor(200 * ease)))
        local desc = hl.desc or ""
        if #desc > 14 then desc = desc:sub(1, 14) .. "…" end
        nvgText(vg, lx + 10, iy + 15, desc)

        -- 评分星星
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(255, 200, 40, math.floor(200 * ease)))
        local stars = math.min(5, math.floor(hl.score / 10))
        nvgText(vg, lx + lw - 8, iy + 3, string.rep("★", stars))

        -- 点击跳转
        addHit(lx + 4, iy, lw - 8, itemH - 3, function()
            currentTime_ = hl.peakTime
            currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
        end)

        iy = iy + itemH
    end

    if #highlights_ == 0 then
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 160, math.floor(150 * ease)))
        nvgText(vg, lx + lw / 2, ly + lh / 2, "无精彩时刻")
    end
end

-- ============================================================================
-- 主渲染
-- ============================================================================
local function renderReplayPlayer()
    if not active_ then return end

    local vg       = UICommon.vg
    local addHit   = UICommon.addHit
    local screenW, screenH = UICommon.getVirtualSize()

    local ease = easeOutCubic(math.min(1, animT_ / 0.5))
    if ease <= 0 then return end

    -- 全屏半透明背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(2, 6, 14, math.floor(240 * ease)))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, math.floor(240 * ease)))
    nvgText(vg, screenW / 2, 8, "🎬 战斗回放")

    -- 关闭按钮（右上角）
    local closeX = screenW - 40
    local closeY = 6
    local closeW, closeH = 32, 22
    nvgBeginPath(vg)
    nvgRoundedRect(vg, closeX, closeY, closeW, closeH, 5)
    nvgFillColor(vg, nvgRGBA(60, 20, 20, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 80, 80, math.floor(180 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(240, 140, 140, math.floor(240 * ease)))
    nvgText(vg, closeX + closeW / 2, closeY + closeH / 2, "✕")
    addHit(closeX, closeY, closeW, closeH, function()
        ReplayPlayer.Hide()
    end)

    -- 布局计算
    local hlListW = 140    -- 精彩列表宽度
    local mapX    = MAP_MARGIN
    local mapY    = 30
    local mapW    = screenW - MAP_MARGIN * 2 - hlListW - 10
    local mapH    = screenH - TIMELINE_H - 70 - 30  -- 减去标题/MVP/时间轴

    -- MVP 横幅（地图上方）
    renderMVPBanner(vg, mapX, mapY, mapW, ease)
    mapY = mapY + 32

    -- 迷你战场地图
    mapH = screenH - mapY - TIMELINE_H - 50
    renderBattleMap(vg, mapX, mapY, mapW, mapH, ease)

    -- 事件弹幕（叠在地图上）
    renderEventPopups(vg, mapX, mapY, mapW, mapH, ease)

    -- 精彩时刻侧栏（地图右侧）
    local hlX = mapX + mapW + 10
    local hlY = mapY
    local hlH = mapH + 32  -- 包含 MVP 区域高度
    renderHighlightList(vg, hlX, hlY, hlListW, hlH, ease)

    -- 时间轴 + 控制条（底部）
    local tlY = screenH - TIMELINE_H - 12
    renderTimeline(vg, 0, tlY, screenW, TIMELINE_H, ease)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 每帧更新
---@param dt number
function ReplayPlayer.Update(dt)
    if not active_ then return end

    -- 进场动画
    if animT_ < 0.5 then
        animT_ = animT_ + dt
    end

    -- 播放推进
    if playing_ and duration_ > 0 then
        local prevTime = currentTime_
        currentTime_ = currentTime_ + dt * speed_

        if currentTime_ >= duration_ then
            currentTime_ = duration_
            playing_ = false
        end

        -- 更新当前帧
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)

        -- 检查新事件（生成弹幕）
        local newEvents = BattleReplaySystem.GetEventsInRange(prevTime, currentTime_)
        for _, ev in ipairs(newEvents) do
            if #eventPopups_ >= MAX_POPUPS then
                table.remove(eventPopups_, 1)
            end
            local desc = BattleReplaySystem._describeEvent(ev)
            if desc and desc ~= "" then
                eventPopups_[#eventPopups_ + 1] = {
                    text  = desc,
                    alpha = 1.0,
                    timer = EVENT_POPUP_DUR,
                }
            end
        end
    end

    -- 弹幕淡出
    for i = #eventPopups_, 1, -1 do
        local popup = eventPopups_[i]
        popup.timer = popup.timer - dt
        if popup.timer <= 0 then
            table.remove(eventPopups_, i)
        else
            popup.alpha = math.min(1, popup.timer / 0.5)
        end
    end
end

--- 渲染
function ReplayPlayer.Render()
    renderReplayPlayer()
end

--- 显示回放播放器
function ReplayPlayer.Show()
    -- 加载回放数据
    frames_     = BattleReplaySystem.GetFrames()
    events_     = BattleReplaySystem.GetEvents()
    highlights_ = BattleReplaySystem.GetHighlights()
    mvp_        = BattleReplaySystem.GetMVP()
    duration_   = BattleReplaySystem.GetDuration()

    if #frames_ == 0 then
        print("[P3-2 ReplayPlayer] 无帧数据，无法播放")
        return false
    end

    active_       = true
    animT_        = 0
    playing_      = false
    speed_        = 1
    currentTime_  = 0
    currentFrame_ = frames_[1]
    eventPopups_  = {}
    dragging_     = false

    print(string.format("[P3-2 ReplayPlayer] 打开回放: %d帧, %.1f秒, %d精彩",
        #frames_, duration_, #highlights_))
    return true
end

--- 隐藏回放播放器
function ReplayPlayer.Hide()
    active_       = false
    playing_      = false
    currentFrame_ = nil
    eventPopups_  = {}
    animT_        = 0
    if onClose_ then onClose_() end
end

--- 是否活跃
function ReplayPlayer.IsActive()
    return active_
end

--- 设置关闭回调
---@param fn function
function ReplayPlayer.SetOnClose(fn)
    onClose_ = fn
end

return ReplayPlayer
