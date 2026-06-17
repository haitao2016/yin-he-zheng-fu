--- 生涯战绩全屏页面模块
--- P3-2：带入场/退场动画的全屏雷达图 + 数据网格

local UICommon = require("game.ui.UICommon")

local CareerPanel = {}

-- ============================================================================
-- 面板私有状态
-- ============================================================================
local pageOpen_  = false   -- 页面是否应当打开
local pageAnim_  = 0.0     -- 0→1 入场/退场动画进度
local stats_     = {       -- 生涯统计数据（由 GameUI.SetCareerStats 写入）
    totalGames   = 0,
    totalWins    = 0,
    bestWave     = 0,
    totalKills   = 0,
    totalColonies= 0,
    bestMvpShip  = "",
    playtime     = 0,
}

-- ============================================================================
-- 公开 API
-- ============================================================================

function CareerPanel.IsOpen()   return pageOpen_  end
function CareerPanel.GetAnim()  return pageAnim_  end

function CareerPanel.Show()
    pageOpen_ = true
end

function CareerPanel.Hide()
    pageOpen_ = false
end

--- 更新生涯统计数据（由 GameUI.SetCareerStats 调用）
---@param s table  含 totalGames/totalWins/bestWave/totalKills/totalColonies/bestMvpShip/playtime
function CareerPanel.SetStats(s)
    if not s then return end
    stats_.totalGames    = s.totalGames    or 0
    stats_.totalWins     = s.totalWins     or 0
    stats_.bestWave      = s.bestWave      or 0
    stats_.totalKills    = s.totalKills    or 0
    stats_.totalColonies = s.totalColonies or 0
    stats_.bestMvpShip   = s.bestMvpShip   or ""
    stats_.playtime      = s.playtime      or 0
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 渲染生涯战绩全屏页面（含动画）
---@param dt number  帧时间（秒）
function CareerPanel.Render(dt)
    if not pageOpen_ and pageAnim_ <= 0 then return end

    -- 入场/退场动画
    local TARGET = pageOpen_ and 1.0 or 0.0
    local SPEED  = 6.0
    if dt and dt > 0 then
        pageAnim_ = pageAnim_ + (TARGET - pageAnim_) * math.min(1, SPEED * dt)
        if math.abs(pageAnim_ - TARGET) < 0.005 then pageAnim_ = TARGET end
    end
    if pageAnim_ <= 0.01 then return end

    local vg  = UICommon.vg
    local sw  = UICommon.screenW
    local sh  = UICommon.screenH
    local a   = pageAnim_  -- 透明度/缩放驱动

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
    UICommon.addHit(cx - 14, cy - 14, 28, 28, function() pageOpen_ = false end)

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 38); nvgLineTo(vg, px + PW - 16, py + 38)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 200, math.floor(120 * a)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ─── 数据读取 ─────────────────────────────────────────
    local cs  = stats_
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
    local N      = #DIMS
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
    UICommon.addHit(0, 0, px, sh, function() pageOpen_ = false end)
    UICommon.addHit(px + PW, 0, sw - px - PW, sh, function() pageOpen_ = false end)
    UICommon.addHit(px, 0, PW, py, function() pageOpen_ = false end)
    UICommon.addHit(px, py + PH, PW, sh - py - PH, function() pageOpen_ = false end)
end

return CareerPanel
