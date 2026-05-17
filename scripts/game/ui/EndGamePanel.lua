-- ============================================================================
-- game/ui/EndGamePanel.lua  -- 游戏结算面板 + 排行榜子面板
-- ============================================================================
local UICommon = require "game.ui.UICommon"

local EndGamePanel = {}

-- ── 结算面板私有状态 ──────────────────────────────────────────────────────────
local active_        = false
local gameType_      = nil     -- "win" | "lose"
local stats_         = {}      -- { playTime, colonized, piratesKilled, rank, level, stars, ... }
local onRetry_       = nil     -- 点击"再来一局"回调
local animT_         = 0       -- 进场动画计时器
local adCb_          = nil     -- 广告回调：fn(onResult)
local adWatched_     = false   -- 本局是否已看过广告
local adLoading_     = false   -- 广告播放中

-- ── 排行榜子面板私有状态 ──────────────────────────────────────────────────────
local lbVisible_     = false
local lbData_        = nil
local lbLoading_     = false
local lbMyRank_      = nil
local lbMyScore_     = nil
local lbOnRequest_   = nil     -- fn(callback) 由 Client.lua 注入
local lbAnimT_       = 0
local LB_ANIM_DUR    = 0.45
local LB_ROW_STAGGER = 0.06

-- 通知函数（由 GameUI 通过 SetNotifyFn 注入）
local notifyFn_ = nil

-- ── 排行榜渲染 ────────────────────────────────────────────────────────────────
local function renderLeaderboard()
    if not lbVisible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    local panelProg = math.min(1.0, lbAnimT_ / LB_ANIM_DUR)
    local panelEase = 1 - (1 - panelProg) ^ 3
    local panelAlpha = panelEase

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(180 * panelAlpha)))
    nvgFill(vg)

    local pw = math.min(420, screenW - 40)
    local ph = math.min(520, screenH - 40)
    local px = (screenW - pw) / 2
    local slideOffset = (1 - panelEase) * (ph * 0.35)
    local py = (screenH - ph) / 2 - slideOffset

    nvgSave(vg)
    nvgGlobalAlpha(vg, panelAlpha)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px - 2, py - 2, pw + 4, ph + 4, 14)
    nvgFillColor(vg, nvgRGBA(80, 50, 180, 60))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(8, 5, 22, 248))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 200, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 150, 255, 255))
    nvgText(vg, px + pw / 2, py + 22, "🏅  银河征服 · 排行榜")

    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, py + 36); nvgLineTo(vg, px + pw - 20, py + 36)
    nvgStrokeColor(vg, nvgRGBA(80, 60, 160, 120))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local listY = py + 44
    if lbMyRank_ or lbMyScore_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px + 10, listY, pw - 20, 20, 4)
        nvgFillColor(vg, nvgRGBA(60, 40, 120, 160)); nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 150, 255, 220))
        local rankStr = lbMyRank_ and string.format("我的排名: #%d", lbMyRank_) or "我的排名: 未上榜"
        nvgText(vg, px + 16, listY + 10, rankStr)
        if lbMyScore_ then
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 220))
            nvgText(vg, px + pw - 16, listY + 10, string.format("得分: %d", lbMyScore_))
        end
        listY = listY + 28
    end

    local rowH = 28
    local rankColors = { {255,215,0}, {192,192,192}, {205,127,50} }

    if lbLoading_ then
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 120, 200, 200))
        nvgText(vg, px + pw / 2, listY + 60, "加载中...")
    elseif not lbData_ or #lbData_ == 0 then
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 100, 160, 180))
        nvgText(vg, px + pw / 2, listY + 60, "暂无排行榜数据")
    else
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(100, 90, 150, 180))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + 16, listY + 6, "排名  指挥官")
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + pw - 16, listY + 6, "得分")
        listY = listY + 16

        local maxRows = math.floor((py + ph - 50 - listY) / rowH)
        for i, entry in ipairs(lbData_) do
            if i > maxRows then break end

            local rowDelay = LB_ANIM_DUR + (i - 1) * LB_ROW_STAGGER
            local rowProg  = math.max(0, math.min(1, (lbAnimT_ - rowDelay) / 0.18))
            local rowEase  = 1 - (1 - rowProg) ^ 2
            local rowSlide = (1 - rowEase) * 10
            local ry = listY + (i - 1) * rowH + rowSlide

            if rowEase <= 0 then goto continueRow end

            nvgSave(vg)
            nvgGlobalAlpha(vg, rowEase * panelAlpha)

            if entry.isMe then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px + 8, ry + 1, pw - 16, rowH - 2, 4)
                nvgFillColor(vg, nvgRGBA(60, 40, 130, 140)); nvgFill(vg)
            elseif i % 2 == 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px + 8, ry + 1, pw - 16, rowH - 2, 4)
                nvgFillColor(vg, nvgRGBA(20, 15, 45, 80)); nvgFill(vg)
            end

            local rc = rankColors[entry.rank] or {160, 150, 200}
            nvgFontSize(vg, entry.rank <= 3 and 13 or 11)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 255))
            local medal = entry.rank == 1 and "🥇"
                       or entry.rank == 2 and "🥈"
                       or entry.rank == 3 and "🥉"
                       or string.format("#%d", entry.rank)
            nvgText(vg, px + 16, ry + rowH / 2, medal)

            nvgFontSize(vg, 11)
            nvgFillColor(vg, entry.isMe
                and nvgRGBA(220, 200, 255, 255)
                or  nvgRGBA(180, 170, 210, 220))
            local nameX = entry.rank <= 9 and (px + 46) or (px + 52)
            local name = entry.nickname or ("玩家" .. tostring(entry.userId or "?"))
            nvgText(vg, nameX, ry + rowH / 2, name .. (entry.isMe and " ★" or ""))

            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 230))
            nvgText(vg, px + pw - 16, ry + rowH / 2, tostring(entry.score or 0))

            nvgRestore(vg)
            ::continueRow::
        end
    end

    local cbw, cbh = 120, 32
    local cbx = (screenW - cbw) / 2
    local cby = py + ph - cbh - 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbx, cby, cbw, cbh, 7)
    nvgFillColor(vg, nvgRGBA(40, 30, 80, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 180, 160))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 140, 220, 240))
    nvgText(vg, screenW / 2, cby + cbh / 2, "关闭")
    addHit(cbx, cby, cbw, cbh, function()
        lbVisible_ = false
    end)

    nvgRestore(vg)
end

-- ── P3-2: 6维度雷达图 ────────────────────────────────────────────────────────
--- 绘制6轴六边形雷达图
---@param vg      userdata  NanoVG context
---@param cx      number    中心 x
---@param cy      number    中心 y
---@param radius  number    最大半径（像素）
---@param dims    table     { {label, value (0-1)} … } 顺时针6个维度
---@param ease    number    动画进度 0-1
local function renderRadarChart(vg, cx, cy, radius, dims, ease)
    local N = #dims  -- 6
    -- 各顶点方向，从顶部(-π/2)顺时针
    local angles = {}
    for i = 1, N do
        angles[i] = -math.pi / 2 + (i - 1) * (2 * math.pi / N)
    end

    -- 1. 背景网格（三层：0.33 / 0.66 / 1.0）
    for layer = 1, 3 do
        local r = radius * (layer / 3)
        nvgBeginPath(vg)
        for i = 1, N do
            local px = cx + r * math.cos(angles[i])
            local py = cy + r * math.sin(angles[i])
            if i == 1 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
        end
        nvgClosePath(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 100, 160, math.floor(60 * ease)))
        nvgStrokeWidth(vg, 0.8)
        nvgStroke(vg)
    end

    -- 2. 辐射轴线
    for i = 1, N do
        local px = cx + radius * math.cos(angles[i])
        local py = cy + radius * math.sin(angles[i])
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy)
        nvgLineTo(vg, px, py)
        nvgStrokeColor(vg, nvgRGBA(80, 100, 160, math.floor(50 * ease)))
        nvgStrokeWidth(vg, 0.7)
        nvgStroke(vg)
    end

    -- 3. 数据多边形（填充 + 描边）
    nvgBeginPath(vg)
    for i = 1, N do
        local v  = math.max(0.05, (dims[i].value or 0) * ease)  -- ease 动画缩放
        local r  = radius * v
        local px = cx + r * math.cos(angles[i])
        local py = cy + r * math.sin(angles[i])
        if i == 1 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(80, 180, 255, math.floor(55 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 220, 255, math.floor(230 * ease)))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 4. 顶点圆点
    for i = 1, N do
        local v  = math.max(0.05, (dims[i].value or 0) * ease)
        local r  = radius * v
        local px = cx + r * math.cos(angles[i])
        local py = cy + r * math.sin(angles[i])
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, 3)
        nvgFillColor(vg, nvgRGBA(180, 240, 255, math.floor(220 * ease)))
        nvgFill(vg)
    end

    -- 5. 标签（轴末端外侧）
    local LABEL_GAP = 14
    nvgFontFace(vg, "sans")
    for i = 1, N do
        local lr = radius + LABEL_GAP
        local px = cx + lr * math.cos(angles[i])
        local py = cy + lr * math.sin(angles[i])
        -- 对齐：左右轴居中，顶/底轴居中
        local alignH
        local cosA = math.cos(angles[i])
        if cosA > 0.3 then
            alignH = NVG_ALIGN_LEFT
        elseif cosA < -0.3 then
            alignH = NVG_ALIGN_RIGHT
        else
            alignH = NVG_ALIGN_CENTER
        end
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, alignH + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 190, 240, math.floor(210 * ease)))
        nvgText(vg, px, py, dims[i].label)

        -- 百分比数值（轴内稍偏，仅在 ease > 0.6 时显示）
        if ease > 0.6 then
            local pct = math.floor((dims[i].value or 0) * 100)
            local vr  = radius * math.max(0.05, dims[i].value or 0) * ease
            local vx  = cx + vr * math.cos(angles[i])
            local vy  = cy + vr * math.sin(angles[i])
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 240, 255, math.floor(200 * (ease - 0.6) / 0.4)))
            nvgText(vg, vx, vy - 6, pct .. "%")
        end
    end
end

-- ── 结算面板渲染 ──────────────────────────────────────────────────────────────
local function renderEndGame()
    if not active_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    local isWin = (gameType_ == "win")
    local AT    = animT_          -- 原始计时器（0→3.0 @ 1.5/s）

    -- P1-3: 缓动辅助函数
    local function easeOutBack(x)
        local c1 = 1.70158; local c3 = c1 + 1
        return 1 + c3 * (x - 1)^3 + c1 * (x - 1)^2
    end
    local function easeOutElastic(x)
        if x <= 0 then return 0 end
        if x >= 1 then return 1 end
        local c4 = (2 * math.pi) / 3
        return 2^(-10*x) * math.sin((x*10 - 0.75) * c4) + 1
    end
    -- 通用滑段：将 AT 映射到 [start, start+dur] → 0→1
    local function seg(start, dur)
        return math.max(0, math.min(1, (AT - start) / dur))
    end

    -- 面板主 ease：0→0.65s 用 easeOutBack（过冲回弹），纯位置用
    local tPos  = seg(0, 0.65)
    local easePos = easeOutBack(tPos)
    -- Alpha ease：0→0.4s smoothstep（避免 easeOutBack 导致 alpha>1 闪屏）
    local tAlpha = seg(0, 0.4)
    local ease   = tAlpha * tAlpha * (3 - 2 * tAlpha)

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(180 * ease)))
    nvgFill(vg)

    local dw, dh = 480, 700  -- P3-2: 扩高以容纳雷达图（+136px）
    local dx = (screenW - dw) / 2
    -- P1-3: 用 easePos 做位置（过冲），用 ease 做 alpha（不过冲）
    local dy = (screenH - dh) / 2 + (1 - easePos) * screenH * 0.3

    local glowR, glowG, glowB = isWin and 80 or 220, isWin and 220 or 50, isWin and 60 or 50
    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx-3, dy-3, dw+6, dh+6, 16)
    nvgFillColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(70 * ease)))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx, dy, dw, dh, 14)
    nvgFillColor(vg, nvgRGBA(8, 10, 22, 252))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(220 * ease)))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 44)
    nvgFillColor(vg, nvgRGBA(glowR+40, glowG+40, glowB+40, math.floor(255 * ease)))
    nvgText(vg, screenW / 2, dy + 56, isWin and "🏆" or "💀")

    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(glowR+60, glowG+60, glowB+60, math.floor(255 * ease)))
    nvgText(vg, screenW / 2, dy + 102, isWin and "银河征服完成！" or "帝国覆灭")

    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(160, 180, 220, math.floor(200 * ease)))
    nvgText(vg, screenW / 2, dy + 124,
        isWin and "你已消灭所有海盗势力，统一银河！" or "星航基地已被摧毁，帝国就此终结。")

    -- P1-3: 星级评分 — 逐颗弹出动画
    local starCount = stats_.stars or 1
    local starCx    = screenW / 2
    local starY     = dy + 152
    nvgFontSize(vg, 8)
    nvgFillColor(vg, nvgRGBA(120, 140, 180, math.floor(160 * ease)))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, starCx, starY - 10, "本局评级")
    for i = 1, 3 do
        local sx_i  = starCx + (i - 2) * 48
        local filled = (i <= starCount)
        -- P1-3: 每颗星在 AT=0.2+(i-1)*0.18s 处弹出（easeOutElastic）
        local starT  = seg(0.2 + (i - 1) * 0.18, 0.45)
        local starSc = easeOutElastic(starT)
        nvgSave(vg)
        nvgTranslate(vg, sx_i, starY)
        nvgScale(vg, starSc, starSc)
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 26)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if filled then
            nvgFillColor(vg, nvgRGBA(255, 180, 0, math.floor(60 * ease)))
            nvgText(vg, 1, 1, "★")
            nvgFillColor(vg, nvgRGBA(255, 210, 30, math.floor(255 * ease)))
        else
            nvgFillColor(vg, nvgRGBA(60, 70, 100, math.floor(180 * ease)))
        end
        nvgText(vg, 0, 0, filled and "★" or "☆")
        nvgRestore(vg)
    end

    -- P1-3: 胜利时金色闪光粒子（AT=0.6s 后激活，持续至 AT=2.5s）
    if isWin and AT > 0.6 and AT < 2.5 then
        local pt    = AT - 0.6          -- 粒子时间 0→1.9s
        local NPART = 16
        for pi = 1, NPART do
            -- 每颗粒子有独立的相位偏移（伪随机）
            local phase  = (pi - 1) / NPART * 2.0
            local localT = (pt - phase) % 1.8   -- 0→1.8 循环
            if localT < 1.5 then
                local lt01   = localT / 1.5
                local angle  = (pi - 1) * (math.pi * 2 / NPART) + lt01 * 0.4
                local radius = 30 + (pi % 4) * 12
                local px2    = dx + dw / 2 + math.cos(angle) * radius
                local py2    = starY - 20 - lt01 * 40  -- 向上漂移
                local alpha  = math.floor((1 - lt01) * 200)
                local r2     = (pi % 2 == 0) and 2.0 or 1.4
                nvgBeginPath(vg)
                nvgCircle(vg, px2, py2, r2)
                nvgFillColor(vg, nvgRGBA(255, 210 + (pi % 3) * 15, 30, alpha))
                nvgFill(vg)
            end
        end
    end

    -- 分割线
    local lx1, lx2, ly = dx + 30, dx + dw - 30, dy + 180
    nvgBeginPath(vg)
    nvgMoveTo(vg, lx1, ly); nvgLineTo(vg, lx2, ly)
    nvgStrokeColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(80 * ease)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local function fmtTime(s)
        local m   = math.floor((s or 0) / 60)
        local sec = math.floor((s or 0) % 60)
        return string.format("%d分%02d秒", m, sec)
    end
    local baseRows = {
        { label="游戏时长", value=fmtTime(stats_.playTime) },
        { label="殖民星球", value=tostring(stats_.colonized or 0) .. " 颗" },
        { label="击败海盗", value=tostring(stats_.piratesKilled or 0) .. " 次" },
        { label="最终等级", value="Lv." .. tostring(stats_.level or 1) .. "  [" .. (stats_.rank or "见习指挥官") .. "]" },
    }
    local sy = dy + 194
    -- P1-3: 基础统计行逐行错开淡入+从左滑入（0.35s + 行号*0.1s 时启动）
    for ri, row in ipairs(baseRows) do
        local rowT   = seg(0.35 + (ri - 1) * 0.10, 0.25)
        local rowEase = rowT * rowT * (3 - 2 * rowT)
        local slideX  = (1 - rowEase) * 18   -- 从右偏移18px滑入
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 150, 200, math.floor(180 * rowEase)))
        nvgText(vg, dx + 60 - slideX, sy + 7, row.label)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, math.floor(230 * rowEase)))
        nvgText(vg, dx + dw - 60 + slideX, sy + 7, row.value)
        sy = sy + 22
    end

    -- 分割线2
    nvgBeginPath(vg)
    nvgMoveTo(vg, lx1, sy + 4); nvgLineTo(vg, lx2, sy + 4)
    nvgStrokeColor(vg, nvgRGBA(60, 80, 140, math.floor(80 * ease)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 14

    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 130, 200, math.floor(160 * ease)))
    nvgText(vg, screenW / 2, sy + 7, "— 战斗详情 —")
    sy = sy + 18

    local shipNames = {
        SCOUT="侦察舰", FRIGATE="护卫舰", DESTROYER="驱逐舰",
        BATTLECRUISER="战列舰", CARRIER="航母", INTERCEPTOR="拦截机",
        MINER="采矿舰", ENGINEER="工程舰", EXPLORER="探索舰",
    }
    local function fmtNum(n)
        if n >= 10000 then return string.format("%.1fw", n/10000) end
        return tostring(math.floor(n or 0))
    end
    local survivor = stats_.bestSurvivor and (shipNames[stats_.bestSurvivor] or stats_.bestSurvivor) or "—"
    local battleRows = {
        { label="伤害输出", value=fmtNum(stats_.dmgDealt or 0),      color={80,220,120} },
        { label="受到伤害", value=fmtNum(stats_.dmgTaken or 0),      color={220,100,80} },
        { label="击落敌舰", value=(stats_.enemiesKilled or 0).." 艘", color={200,180,80} },
        { label="通关波次", value=(stats_.wavesCleared  or 0).." 波", color={120,180,255} },
        { label="存活旗舰", value=survivor,                           color={180,140,255} },
    }
    -- P1-3: 战斗详情行从 0.75s 开始逐行错开（间隔0.08s）
    for bi, row in ipairs(battleRows) do
        local bRowT   = seg(0.75 + (bi - 1) * 0.08, 0.22)
        local bRowE   = bRowT * bRowT * (3 - 2 * bRowT)
        local bSlideX = (1 - bRowE) * 14
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 180, math.floor(160 * bRowE)))
        nvgText(vg, dx + 60 - bSlideX, sy + 7, row.label)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(row.color[1], row.color[2], row.color[3], math.floor(230 * bRowE)))
        nvgText(vg, dx + dw - 60 + bSlideX, sy + 7, row.value)
        sy = sy + 20
    end

    if stats_.mvpShip then
        local mvpName = shipNames[stats_.mvpShip] or stats_.mvpShip
        local mvpT    = seg(1.20, 0.25)
        local mvpE    = mvpT * mvpT * (3 - 2 * mvpT)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 180, math.floor(160 * mvpE)))
        nvgText(vg, dx + 60, sy + 7, "⭐ MVP舰种")
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, math.floor(230 * mvpE)))
        nvgText(vg, dx + dw - 60, sy + 7, mvpName)
        sy = sy + 20
    end

    -- 分割线3
    nvgBeginPath(vg)
    nvgMoveTo(vg, lx1, sy + 4); nvgLineTo(vg, lx2, sy + 4)
    nvgStrokeColor(vg, nvgRGBA(60, 80, 140, math.floor(60 * ease)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 14

    -- P3-2: 六维度雷达图 ───────────────────────────────────────────────────────
    do
        local dmgDealt  = stats_.dmgDealt  or 0
        local dmgTaken  = stats_.dmgTaken  or 0
        local colonized = stats_.colonized or 0
        local totalRes  = stats_.totalResearch or 0
        local pirates   = stats_.piratesKilled or 0
        local waves     = stats_.wavesCleared  or 0

        -- 防御能力：伤害比越低越好，0 = 全部扣血，1 = 零伤
        local defRaw = dmgDealt > 0 and (1 - math.min(1, dmgTaken / dmgDealt)) or (dmgTaken == 0 and 1 or 0)

        local dims = {
            { label = "战斗强度", value = math.min(1, dmgDealt  / 50000) },
            { label = "防御能力", value = math.max(0, defRaw)            },
            { label = "扩张速度", value = math.min(1, colonized / 8)     },
            { label = "科研进度", value = math.min(1, totalRes  / 12)    },
            { label = "战术效率", value = math.min(1, pirates   / 20)    },
            { label = "生存时间", value = math.min(1, waves     / 10)    },
        }

        -- 雷达图区域：宽 dw，高 136，居中
        local RADAR_H  = 136
        local rcx      = dx + dw / 2
        local rcy      = dy + sy + RADAR_H / 2  -- 面板内绝对坐标
        local radius   = 46

        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 200, math.floor(160 * ease)))
        nvgText(vg, screenW / 2, dy + sy + 8, "— 综合评估 —")

        renderRadarChart(vg, rcx, rcy + 12, radius, dims, ease)

        sy = sy + RADAR_H + 8
    end
    -- ─────────────────────────────────────────────────────────────────────────

    -- 再来一局按钮
    local bw, bh = 200, 44
    local bx = (screenW - bw) / 2
    local by = dy + dh - 60

    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 8)
    nvgFillColor(vg, nvgRGBA(
        isWin and 30 or 160,
        isWin and 120 or 40,
        isWin and 200 or 40,
        math.floor(220 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(
        isWin and 80 or 220,
        isWin and 180 or 80,
        isWin and 255 or 80,
        math.floor(200 * ease)))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 235, 255, math.floor(255 * ease)))
    nvgText(vg, screenW / 2, by + bh / 2, "🔄  再来一局")

    if ease > 0.8 then
        addHit(bx, by, bw, bh, function()
            if onRetry_ then onRetry_() end
        end)
    end

    -- 广告按钮
    local adw, adh = 240, 38
    local adx = (screenW - adw) / 2
    local ady = by - adh - 8

    if adWatched_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, adx, ady, adw, adh, 7)
        nvgFillColor(vg, nvgRGBA(20, 60, 20, math.floor(180 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 180, 60, math.floor(140 * ease)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 220, 100, math.floor(230 * ease)))
        nvgText(vg, screenW / 2, ady + adh / 2, "✅  下局资源加成已激活！")
    elseif adLoading_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, adx, ady, adw, adh, 7)
        nvgFillColor(vg, nvgRGBA(40, 40, 40, math.floor(160 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 80, 80, math.floor(120 * ease)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 140, 140, math.floor(200 * ease)))
        nvgText(vg, screenW / 2, ady + adh / 2, "广告加载中…")
    elseif adCb_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, adx, ady, adw, adh, 7)
        local grad = nvgLinearGradient(vg, adx, ady, adx, ady + adh,
            nvgRGBA(120, 80, 0, math.floor(230 * ease)),
            nvgRGBA(80, 50, 0, math.floor(210 * ease)))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(220 * ease)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(255 * ease)))
        nvgText(vg, screenW / 2, ady + adh / 2, "🎬  看广告 · 下局获得资源加成")
        if ease > 0.8 then
            addHit(adx, ady, adw, adh, function()
                if adLoading_ or adWatched_ then return end
                adLoading_ = true
                adCb_(function(success, msg)
                    adLoading_ = false
                    if success then
                        adWatched_ = true
                        if notifyFn_ then notifyFn_("🎬 广告观看完成！下局资源加成已激活", "info") end
                    else
                        if notifyFn_ then notifyFn_("广告未完整播放，请重试", "warn") end
                    end
                end)
            end)
        end
    end

    -- 排行榜按钮
    local lbw, lbh = 160, 34
    local lbx = (screenW - lbw) / 2
    local lby = ady - lbh - 8

    nvgBeginPath(vg)
    nvgRoundedRect(vg, lbx, lby, lbw, lbh, 7)
    nvgFillColor(vg, nvgRGBA(40, 30, 80, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 80, 220, math.floor(180 * ease)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 150, 255, math.floor(240 * ease)))
    nvgText(vg, screenW / 2, lby + lbh / 2, "🏅  银河排行榜")

    if ease > 0.8 then
        addHit(lbx, lby, lbw, lbh, function()
            lbVisible_  = true
            lbLoading_  = true
            lbData_     = nil
            lbMyRank_   = nil
            lbMyScore_  = nil
            lbAnimT_    = 0
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
-- 公开 API
-- ============================================================================

--- 每帧更新动画计时器（由 GameUI.UpdateNotifications 调用）
---@param dt number 帧间隔（秒）
function EndGamePanel.Update(dt)
    if active_ and animT_ < 3.0 then
        animT_ = animT_ + dt * 1.5   -- P1-3: 延长到3.0，支持逐行错开动画
    end
    if lbVisible_ and lbAnimT_ < LB_ANIM_DUR + LB_ROW_STAGGER * 15 then
        lbAnimT_ = lbAnimT_ + dt
    end
end

--- 渲染结算界面（每帧调用）
function EndGamePanel.Render()
    renderEndGame()
end

--- 渲染排行榜（每帧调用，在结算面板之后调用）
function EndGamePanel.RenderLeaderboard()
    renderLeaderboard()
end

--- 显示结算界面
---@param gameType string  "win" | "lose"
---@param stats    table   统计数据
---@param onRetry  function 再来一局回调
function EndGamePanel.Show(gameType, stats, onRetry)
    active_     = true
    gameType_   = gameType
    stats_      = stats or {}
    onRetry_    = onRetry
    animT_      = 0
end

--- 隐藏结算界面并重置状态
function EndGamePanel.Hide()
    active_     = false
    gameType_   = nil
    stats_      = {}
    animT_      = 0
    adWatched_  = false
    adLoading_  = false
    lbVisible_  = false
    lbData_     = nil
    lbAnimT_    = 0
end

--- 是否当前结算界面可见
function EndGamePanel.IsActive()
    return active_
end

--- 注入结算广告回调
---@param fn function  fn(onResult) — onResult(success, msg)
function EndGamePanel.SetAdCallback(fn)
    adCb_ = fn
end

--- 注入排行榜请求回调
---@param fn function  fn(callback) — callback(data, myRank, myScore)
function EndGamePanel.SetLeaderboardCallback(fn)
    lbOnRequest_ = fn
end

--- 注入通知函数（用于广告结果通知）
---@param fn function  fn(msg, ntype)
function EndGamePanel.SetNotifyFn(fn)
    notifyFn_ = fn
end

return EndGamePanel
