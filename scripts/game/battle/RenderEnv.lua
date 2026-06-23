---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- RenderEnv: 环境/背景层渲染 (从 BattleRender.lua 拆分)
-- ============================================================================
local BS = require("game.battle.BattleState")

local RenderEnv = {}

local function drawEnvParticles()
    if #BS.envParticles == 0 then return end
    local pt = BS.currentEnv and BS.currentEnv.particleType
    for _, p in ipairs(BS.envParticles) do
        local frac  = p.life / p.maxLife
        local alpha = math.floor(frac * (p.maxA or 200))
        if alpha <= 0 then goto continue end

        if pt == "nebula" then
            -- 大雾团：圆形渐变（中心稍亮，边缘淡出）
            local rad = p.size * (0.5 + frac * 0.5)  -- 先小后大
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, p.x, p.y, math.max(1, rad))
            nvgFillColor(BS.vg, nvgRGBA(p.r, p.g, p.b, alpha))
            nvgFill(BS.vg)
        elseif pt == "asteroid" then
            -- 小岩石：不规则多边形（用简单椭圆近似）
            nvgSave(BS.vg)
            nvgTranslate(BS.vg, p.x, p.y)
            nvgRotate(BS.vg, p.life * 1.5)  -- 自旋
            local s = p.size
            nvgBeginPath(BS.vg)
            nvgEllipse(BS.vg, 0, 0, s, s * 0.7)
            nvgFillColor(BS.vg, nvgRGBA(p.r, p.g, p.b, alpha))
            nvgFill(BS.vg)
            -- 高光描边
            nvgStrokeColor(BS.vg, nvgRGBA(
                math.min(255, p.r + 60),
                math.min(255, p.g + 50),
                math.min(255, p.b + 30), math.floor(alpha * 0.5)))
            nvgStrokeWidth(BS.vg, 0.5)
            nvgStroke(BS.vg)
            nvgRestore(BS.vg)
        elseif pt == "magstor" then
            -- 电弧线段：快速竖向线，有发光感
            nvgBeginPath(BS.vg)
            nvgMoveTo(BS.vg, p.x, p.y)
            nvgLineTo(BS.vg, p.x + p.vx * 0.05, p.y + p.vy * 0.05)
            nvgStrokeColor(BS.vg, nvgRGBA(p.r, p.g, p.b, alpha))
            nvgStrokeWidth(BS.vg, p.size or 1.5)
            nvgStroke(BS.vg)
            -- 外层更宽的低透线（模拟发光）
            nvgBeginPath(BS.vg)
            nvgMoveTo(BS.vg, p.x, p.y)
            nvgLineTo(BS.vg, p.x + p.vx * 0.05, p.y + p.vy * 0.05)
            nvgStrokeColor(BS.vg, nvgRGBA(p.r, p.g, p.b, math.floor(alpha * 0.25)))
            nvgStrokeWidth(BS.vg, (p.size or 1.5) * 3)
            nvgStroke(BS.vg)
        end
        ::continue::
    end
end

--- P1-2: 环境 HUD（左上角小徽标）
local function drawEnvHUD()
    if not BS.currentEnv then return end
    local ex = 8
    local ey = 32   -- 在顶部标题栏下方
    local ew = 90
    local eh = 20

    -- 背景
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, ex, ey, ew, eh, 5)
    -- 背景色随环境变化
    local bgA = 180
    if BS.currentEnv.key == "NEBULA" then
        nvgFillColor(BS.vg, nvgRGBA(20, 5, 50, bgA))
    elseif BS.currentEnv.key == "ASTEROID" then
        nvgFillColor(BS.vg, nvgRGBA(35, 20, 5, bgA))
    elseif BS.currentEnv.key == "MAGSTOR" then
        nvgFillColor(BS.vg, nvgRGBA(5, 30, 20, bgA))
    end
    nvgFill(BS.vg)
    -- 边框（环境颜色）
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, ex + 0.5, ey + 0.5, ew - 1, eh - 1, 5)
    nvgStrokeColor(BS.vg, nvgRGBA(BS.currentEnv.pR, BS.currentEnv.pG, BS.currentEnv.pB, 140))
    nvgStrokeWidth(BS.vg, 0.8)
    nvgStroke(BS.vg)

    -- 图标 + 文字
    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 10)
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(BS.currentEnv.pR, BS.currentEnv.pG, BS.currentEnv.pB, 220))
    nvgText(BS.vg, ex + 5, ey + eh / 2, BS.currentEnv.icon .. " " .. BS.currentEnv.label)
end

--- P1-2: 环境进入公告横幅（战斗开始时中央短暂显示）
local function drawEnvAnnounce()
    if BS.envAnnounceAlpha <= 0 then return end
    if not BS.currentEnv then return end
    local a = BS.envAnnounceAlpha
    local cx = BS.screenW / 2
    local cy = BS.screenH * 0.28

    -- 横幅背景
    local bw, bh = 280, 52
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2, cy - bh/2, bw, bh, 8)
    nvgFillColor(BS.vg, nvgRGBA(0, 0, 0, math.floor(a * 0.75)))
    nvgFill(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2 + 0.5, cy - bh/2 + 0.5, bw - 1, bh - 1, 8)
    nvgStrokeColor(BS.vg, nvgRGBA(BS.currentEnv.pR, BS.currentEnv.pG, BS.currentEnv.pB, a))
    nvgStrokeWidth(BS.vg, 1.5)
    nvgStroke(BS.vg)

    -- 标题行：环境名称
    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(BS.vg, 16)
    nvgFillColor(BS.vg, nvgRGBA(BS.currentEnv.pR, BS.currentEnv.pG, BS.currentEnv.pB, a))
    nvgText(BS.vg, cx, cy - 10, BS.currentEnv.icon .. "  进入" .. BS.currentEnv.label .. "区域")

    -- 描述行
    nvgFontSize(BS.vg, 9.5)
    nvgFillColor(BS.vg, nvgRGBA(200, 200, 200, math.floor(a * 0.85)))
    nvgText(BS.vg, cx, cy + 12, BS.currentEnv.desc)
end

--- P3-1: 动态背景星星（视差三层 + 闪烁 + 近景十字光晕）
local function drawBgStars()
    -- 视差系数：layer 越大移动越快（近景视差更明显）
    local layerParallax = { 0.15, 0.35, 0.65 }
    -- Boss 波次时整体偏红色调
    local isBossWave = (BS.waveNum % BS.BOSS_WAVE_INTERVAL == 0) and BS.state == "fighting"

    for _, s in ipairs(BS.bgStars) do
        local pf  = layerParallax[s.layer] or 0.3
        -- 视差后的屏幕坐标（循环滚动，星星飘出屏幕左/下侧后从右/上侧重现）
        local sx = (s.x - BS.bgScrollX * pf) % (BS.screenW + 40)
        local sy = (s.y - BS.bgScrollY * pf) % (BS.screenH + 40)
        -- 闪烁：alpha 在基础值 ±30% 之间正弦波动
        local twinkle = math.sin(s.twinklePhase)
        local a = math.max(20, math.min(255, math.floor(s.alpha + twinkle * s.alpha * 0.3)))

        -- 星星颜色：正常白蓝，Boss波带橙红调
        local sr, sg, sb
        if isBossWave then
            sr = math.min(255, 200 + math.floor(twinkle * 30))
            sg = math.max(80,  140 - math.floor(twinkle * 20))
            sb = math.max(60,  100 - math.floor(twinkle * 20))
        else
            sr = math.min(255, 200 + math.floor(twinkle * 40))
            sg = math.min(255, 210 + math.floor(twinkle * 30))
            sb = 255
        end

        -- 绘制星点
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, sx, sy, s.r)
        nvgFillColor(BS.vg, nvgRGBA(sr, sg, sb, a))
        nvgFill(BS.vg)

        -- layer 3 近景大星：十字光晕
        if s.layer == 3 then
            local glowLen = s.r * (3.5 + twinkle * 1.5)
            local ga      = math.floor(a * 0.5)
            nvgStrokeWidth(BS.vg, 0.8)
            nvgStrokeColor(BS.vg, nvgRGBA(sr, sg, sb, ga))
            -- 水平光芒
            nvgBeginPath(BS.vg)
            nvgMoveTo(BS.vg, sx - glowLen, sy)
            nvgLineTo(BS.vg, sx + glowLen, sy)
            nvgStroke(BS.vg)
            -- 垂直光芒
            nvgBeginPath(BS.vg)
            nvgMoveTo(BS.vg, sx, sy - glowLen)
            nvgLineTo(BS.vg, sx, sy + glowLen)
            nvgStroke(BS.vg)
        end
    end
end

local function drawGrid()
    local env = BS.currentEnv
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, 0, 0, BS.screenW, BS.screenH)
    -- P1-2: 背景色随环境微调
    nvgFillColor(BS.vg, nvgRGBA(
        env and env.bgR or 0,
        env and env.bgG or 0,
        env and env.bgB or 10, 255))
    nvgFill(BS.vg)
    nvgStrokeColor(BS.vg, nvgRGBA(50,100,200, 20))
    nvgStrokeWidth(BS.vg, 1)
    local step = 60
    for x = 0, BS.screenW, step do
        nvgBeginPath(BS.vg); nvgMoveTo(BS.vg,x,0); nvgLineTo(BS.vg,x,BS.screenH); nvgStroke(BS.vg)
    end
    for y = 0, BS.screenH, step do
        nvgBeginPath(BS.vg); nvgMoveTo(BS.vg,0,y); nvgLineTo(BS.vg,BS.screenW,y); nvgStroke(BS.vg)
    end
end

RenderEnv.drawEnvParticles = drawEnvParticles
RenderEnv.drawEnvHUD       = drawEnvHUD
RenderEnv.drawEnvAnnounce  = drawEnvAnnounce
RenderEnv.drawBgStars      = drawBgStars
RenderEnv.drawGrid         = drawGrid

return RenderEnv
