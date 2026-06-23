-- ============================================================================
-- game/ui/GalaxyHud.lua  -- 银河场景 HUD 覆盖层
-- 包含：部署提示 / 舰队速览 / 资源危机闪烁 / 海盗预警 / 每日挑战 / 联赛徽章
-- ============================================================================

local UICommon = require("game.ui.UICommon")

local GalaxyHud = {}

-- ============================================================================
-- 常量
-- ============================================================================
local PIRATE_WARN_THRESH = 30

-- ============================================================================
-- 1. 展开前操作提示 HUD（种子飞船阶段，手机紧凑版）
-- ============================================================================
---@param ctx {deployCallback: function}
local function renderDeployHint(ctx)
    local vg = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local cursorX = UICommon.cursorX
    local cursorY = UICommon.cursorY
    local clrC    = UICommon.clrC
    local addHit  = UICommon.addHit
    local C       = UICommon.C

    -- 底部居中提示框（手机横屏压缩版）
    local bw  = math.min(480, screenW - 40)
    local bh  = 64
    local bx  = (screenW - bw) / 2
    local by  = screenH - bh - 14

    -- 背景板
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 7)
    nvgFillColor(vg,   clrC(C.panelBg))
    nvgFill(vg)
    nvgStrokeColor(vg, clrC(C.panelBorder))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题行
    nvgFontSize(vg, 11)
    nvgFillColor(vg, clrC(C.textTitle))
    nvgText(vg, screenW / 2, by + 13, "星航种子飞船 — 寻找落脚点")

    -- 移动说明行
    nvgFontSize(vg, 9)
    nvgFillColor(vg, clrC(C.textSubtitle))
    nvgText(vg, screenW / 2, by + 27, "WASD / 方向键  或  点击地图 移动")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, bx + 16, by + 36)
    nvgLineTo(vg, bx + bw - 16, by + 36)
    nvgStrokeColor(vg, nvgRGBA(60, 120, 220, 80))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 「在此展开基地」按钮
    local btnW, btnH = math.min(220, bw - 80), 20
    local btnX = screenW / 2 - btnW / 2
    local btnY = by + 40

    local hover = cursorX >= btnX and cursorX <= btnX + btnW
               and cursorY >= btnY and cursorY <= btnY + btnH
    local fillA = hover and 230 or 180
    local borderA = hover and 255 or 180

    local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(20, 160, 80, fillA), nvgRGBA(10, 110, 55, fillA))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
    nvgFillPaint(vg, btnGrad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 220, 120, borderA))
    nvgStrokeWidth(vg, hover and 1.5 or 1.0)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(200, 255, 220, 255))
    nvgText(vg, screenW / 2, btnY + btnH / 2, "▶  在此展开基地")

    -- SPACE 提示（右侧小字）
    nvgFontSize(vg, 8)
    nvgFillColor(vg, nvgRGBA(120, 160, 200, 140))
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, bx + bw - 8, btnY + btnH / 2, "SPACE")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    addHit(btnX, btnY, btnW, btnH, function()
        if ctx.deployCallback then ctx.deployCallback() end
    end)
end

-- ============================================================================
-- 2. 舰队总览 (TAB)
-- ============================================================================
---@param ctx {fleetOverviewShow: boolean, fleetOverviewData: table|nil}
local function renderFleetOverview(ctx)
    if not ctx.fleetOverviewShow or not ctx.fleetOverviewData then return end
    local fm = ctx.fleetOverviewData
    local vg = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH

    local PW = 280
    local PAD = 10
    local lineH  = 18
    local fleetCount = fm.maxFleets or #fm.fleets
    local PH = 34 + fleetCount * lineH + 8 + lineH + PAD
    local px = math.floor((screenW - PW) / 2)
    local py = math.floor((screenH - PH) / 2) - 40

    -- 半透明背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 8)
    nvgFillColor(vg, nvgRGBA(6, 12, 30, 230)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 8)
    nvgStrokeColor(vg, nvgRGBA(60, 160, 255, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 标题
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 220, 255, 255))
    nvgText(vg, px + PW/2, py + 16, "⚓ 舰队总览 (TAB)")

    -- 分隔线
    nvgBeginPath(vg); nvgMoveTo(vg, px + PAD, py + 30); nvgLineTo(vg, px + PW - PAD, py + 30)
    nvgStrokeColor(vg, nvgRGBA(60, 120, 200, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local sy = py + 36
    for i = 1, fleetCount do
        local fl = fm.fleets[i]
        if fl then
            nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(140, 180, 255, 220))
            nvgText(vg, px + PAD, sy + lineH/2, fl.name or ("编队"..i))
            -- 舰船统计
            local parts = {}
            local total = 0
            for _, entry in ipairs(fl.ships or {}) do
                local st = SHIP_TYPES[entry.shipType]
                local nm = st and st.name or entry.shipType
                parts[#parts+1] = nm.."×"..entry.count
                total = total + entry.count
            end
            local info = total > 0 and table.concat(parts, " ") or "—空—"
            nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, total > 0 and 200 or 100))
            nvgText(vg, px + PW - PAD, sy + lineH/2, info)
            sy = sy + lineH
        end
    end

    -- 分隔线
    nvgBeginPath(vg); nvgMoveTo(vg, px + PAD, sy + 2); nvgLineTo(vg, px + PW - PAD, sy + 2)
    nvgStrokeColor(vg, nvgRGBA(60, 120, 200, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 8

    -- 储备池
    local resParts = {}
    local resTotal = 0
    for stype, cnt in pairs(fm.reserve or {}) do
        if cnt > 0 then
            local st = SHIP_TYPES[stype]
            resParts[#resParts+1] = (st and st.name or stype).."×"..cnt
            resTotal = resTotal + cnt
        end
    end
    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 100, 220))
    nvgText(vg, px + PAD, sy + lineH/2, "储备池 ("..resTotal..")")
    nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 200, 150, 180))
    local resInfo = resTotal > 0 and table.concat(resParts, " ") or "无"
    nvgText(vg, px + PW - PAD, sy + lineH/2, resInfo)
end

-- ============================================================================
-- 3. 资源危机屏幕边缘红色闪烁
-- ============================================================================
---@param ctx {resCrisisState: table, resCrisisBlink: number}
local function renderResourceCrisisFlash(ctx)
    local anyCrisis = false
    for _, v in pairs(ctx.resCrisisState) do
        if v then anyCrisis = true; break end
    end
    if not anyCrisis then return end

    local vg = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH

    local pulse = math.abs(math.sin(ctx.resCrisisBlink * 2.5))
    local alpha = math.floor(20 + 35 * pulse)
    local edgeW = 6

    -- 上边
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, edgeW)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, 0, edgeW,
        nvgRGBA(255, 40, 40, alpha), nvgRGBA(255, 40, 40, 0)))
    nvgFill(vg)
    -- 下边
    nvgBeginPath(vg)
    nvgRect(vg, 0, screenH - edgeW, screenW, edgeW)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, screenH - edgeW, 0, screenH,
        nvgRGBA(255, 40, 40, 0), nvgRGBA(255, 40, 40, alpha)))
    nvgFill(vg)
    -- 左边
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, edgeW, screenH)
    nvgFillPaint(vg, nvgLinearGradient(vg, 0, 0, edgeW, 0,
        nvgRGBA(255, 40, 40, alpha), nvgRGBA(255, 40, 40, 0)))
    nvgFill(vg)
    -- 右边
    nvgBeginPath(vg)
    nvgRect(vg, screenW - edgeW, 0, edgeW, screenH)
    nvgFillPaint(vg, nvgLinearGradient(vg, screenW - edgeW, 0, screenW, 0,
        nvgRGBA(255, 40, 40, 0), nvgRGBA(255, 40, 40, alpha)))
    nvgFill(vg)
end

-- ============================================================================
-- 4. 海盗进攻预警倒计时 HUD（顶部居中）
-- ============================================================================
---@param ctx {pirateWarningTime: number, pirateWarnBlink: number}
local function renderPirateWarning(ctx)
    if ctx.pirateWarningTime > PIRATE_WARN_THRESH then return end
    local vg = UICommon.vg
    local screenW = UICommon.screenW

    local t    = math.ceil(ctx.pirateWarningTime)
    local urgency = math.max(0, 1.0 - t / PIRATE_WARN_THRESH)
    local r = math.floor(200 + 55 * urgency)
    local g = math.floor(100 * (1 - urgency))
    local freq  = 1.0 + urgency * 2.0
    local blink = math.abs(math.sin(ctx.pirateWarnBlink * math.pi * freq))
    local bgAlpha = math.floor(160 + 80 * blink)

    local bw = 220
    local bh = 28
    local bx = (screenW - bw) / 2
    local by = 52

    -- 背景条
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 6)
    nvgFillColor(vg, nvgRGBA(r, g, 20, bgAlpha))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(r, g + 40, 40, 230))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 文字
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(255, 240, 80, 255))
    nvgText(vg, screenW / 2, by + bh / 2,
        string.format("⚠ 海盗进攻倒计时: %ds", t))
end

-- ============================================================================
-- 5. 每日挑战开局横幅（游戏开始后显示数秒）
-- ============================================================================
---@param ctx {dailyChallengeBanner: table|nil, dt: number}
---@return table|nil updatedBanner
local function renderDailyChallengeBanner(ctx)
    if not ctx.dailyChallengeBanner then return nil end
    local banner = ctx.dailyChallengeBanner
    banner.timer = banner.timer - ctx.dt
    if banner.timer <= 0 then
        return nil  -- 告知调用方清除
    end

    local vg = UICommon.vg
    local screenW = UICommon.screenW
    local ch  = banner.challenge
    local dur = banner.duration
    local t   = banner.timer

    -- 渐隐：最后 1 秒淡出
    local alpha = math.min(1.0, t / 1.0)
    -- 入场：前 0.4 秒从上滑入
    local elapsed = dur - t
    local slideT  = math.min(1.0, elapsed / 0.4)
    local slideY  = (1.0 - slideT) * (-60)

    local BW, BH = math.min(460, screenW - 20), 72
    local bx     = (screenW - BW) / 2
    local by     = 52 + slideY

    local a = math.floor(alpha * 220)
    local ta = math.floor(alpha * 255)

    -- 背景面板
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, BW, BH, 8)
    nvgFillColor(vg, nvgRGBA(10, 25, 60, a))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, math.floor(alpha * 180)))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题行
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(120, 200, 255, ta))
    nvgText(vg, screenW / 2, by + 13, "📅  今日星际挑战")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, bx + 12, by + 23)
    nvgLineTo(vg, bx + BW - 12, by + 23)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, math.floor(alpha * 120)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 限制行
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(255, 120, 80, ta))
    nvgText(vg, screenW / 2, by + 38, "🚫  " .. (ch.restrictDesc or ch.restriction or "无限制"))

    -- 强化行
    nvgFillColor(vg, nvgRGBA(100, 230, 130, ta))
    nvgText(vg, screenW / 2, by + 56, "⚡  " .. (ch.boostDesc or ch.boost or "无强化"))

    return banner  -- 返回更新后的 banner（timer 已递减）
end

-- ============================================================================
-- 6. 联赛模式 HUD 徽章（左上角，TopBar 下方）
-- ============================================================================
---@param ctx {leagueHud: table|nil}
local function renderLeagueHud(ctx)
    if not ctx.leagueHud then return end
    local h = ctx.leagueHud
    local vg = UICommon.vg
    local BW, BH = 180, 36
    local bx, by = 8, 50

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, BW, BH, 6)
    nvgFillColor(vg, nvgRGBA(8, 15, 40, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 50, 140))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 段位图标 + 名称
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 210, 60, 230))
    nvgText(vg, bx + 8, by + BH / 2, string.format("%s %s", h.rankIcon or "🏆", h.rankName or ""))

    -- 最佳得分
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 200))
    nvgText(vg, bx + BW - 8, by + BH / 2, string.format("Best:%d", h.bestScore or 0))
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 渲染银河场景 HUD 覆盖层
---@param ctx table 帧上下文
---   deployed: boolean            是否已展开基地
---   deployCallback: function     展开基地回调
---   fleetOverviewShow: boolean   TAB 舰队总览开关
---   fleetOverviewData: table     舰队数据
---   resCrisisState: table        资源危机状态 {resKey=bool}
---   resCrisisBlink: number       危机闪烁计时器
---   pirateWarningTime: number    海盗进攻倒计时
---   pirateWarnBlink: number      海盗预警闪烁计时器
---   dailyChallengeBanner: table  每日挑战横幅数据
---   leagueHud: table             联赛 HUD 数据
---   dt: number                   帧间隔
---@return table|nil updatedBanner 更新后的每日挑战数据（nil = 已结束）
function GalaxyHud.Render(ctx)
    if not ctx.deployed then
        renderDeployHint(ctx)
        return ctx.dailyChallengeBanner
    end

    renderPirateWarning(ctx)
    renderResourceCrisisFlash(ctx)
    renderFleetOverview(ctx)
    local updatedBanner = renderDailyChallengeBanner(ctx)
    renderLeagueHud(ctx)

    return updatedBanner
end

return GalaxyHud
