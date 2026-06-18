-- Auto-split from RenderHUD.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function drawTooltipBox(cx, cy, lines, titleColor, borderColor)
    local vg      = GS.vg
    local screenW = GS.screenW
    local screenH = GS.screenH

    titleColor  = titleColor  or {255, 220, 80}
    borderColor = borderColor or {100, 160, 255}
    local tw = 170
    local th = 14 * #lines + 12
    local tx = cx + 14
    local ty = cy - th / 2
    if tx + tw > screenW - 10 then tx = cx - tw - 14 end
    if ty < 60 then ty = 60 end
    if ty + th > screenH - 10 then ty = screenH - th - 10 end

    nvgBeginPath(vg)
    nvgRoundedRect(vg, tx, ty, tw, th, 5)
    nvgFillColor(vg, nvgRGBA(5, 10, 22, 235))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], 160))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    for i, line in ipairs(lines) do
        local ly = ty + 6 + (i-1) * 14
        if i == 1 then
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(titleColor[1], titleColor[2], titleColor[3], 255))
        else
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(180, 210, 255, 200))
        end
        nvgText(vg, tx + 7, ly, line)
    end
end

-- ============================================================================
-- drawTooltip — 行星悬浮提示
-- ============================================================================
function M.drawTooltip(planet)
    if not planet then return end
    local px, py = planet._sx, planet._sy
    if not px then return end

    local lines = {}
    lines[1] = planet.name
    lines[2] = planet.ptype .. " 行星"
    if planet.colonized then
        local bCnt = #planet.buildings
        lines[#lines+1] = "已探索  ·  建筑: " .. bCnt .. " 座"
        for i = 1, math.min(3, bCnt) do
            local b = planet.buildings[i]
            local bInfo = BUILDINGS[b.key]
            local bName = bInfo and bInfo.name or b.key
            local lvlStr = (b.level and b.level > 1) and (" Lv"..b.level) or ""
            lines[#lines+1] = "  · " .. bName .. lvlStr
        end
        if bCnt > 3 then
            lines[#lines+1] = "  … 共 " .. bCnt .. " 座"
        end
        if planet.constructing then
            local job = planet.constructing
            local pct = math.floor((job.progress or 0) * 100)
            local jInfo = BUILDINGS[job.key]
            lines[#lines+1] = "建造中: " .. (jInfo and jInfo.name or job.key) .. " " .. pct .. "%"
        end
    else
        lines[#lines+1] = "未探索  ·  点击探索"
    end

    drawTooltipBox(px, py, lines, {255,220,80}, {100,160,255})
end

-- ============================================================================
-- drawAsteroidTooltip — 小行星悬浮提示
-- ============================================================================
function M.drawAsteroidTooltip(a)
    if not a then return end
    local sx, sy = GS.w2s(a.x, a.y)
    local cfg    = GS.ASTEROID_TYPES[a.atype]
    local szCfg  = a.sizeKey and GS.ASTEROID_SIZES[a.sizeKey]
    local hpPct  = math.floor((a.hp / a.maxHP) * 100)
    local c      = cfg.color

    local lines = {}
    lines[1] = (szCfg and szCfg.label or "") .. cfg.label .. "小行星"
    lines[2] = "资源: " .. cfg.label
    lines[3] = "产出: " .. math.floor(a.yield) .. " /次"
    lines[4] = string.format("耐久: %d / %d  (%d%%)", a.hp, a.maxHP, hpPct)
    local densityMax = 90
    local density = math.min(100, math.floor(a.yield / densityMax * hpPct))
    lines[5] = "矿石密度: " .. density .. "%"

    drawTooltipBox(sx, sy, lines, {c[1]+60, c[2]+60, c[3]+60}, {c[1], c[2], c[3]})
end

-- ============================================================================
-- drawPirateWarningHUD — 海盗进攻预警面板
-- ============================================================================
function M.drawPirateWarningHUD()
    local pirateAI = GS.pirateAI
    if not pirateAI or #pirateAI.fleets == 0 then return end

    local vg      = GS.vg
    local screenW = GS.screenW
    local PIRATE_FLEET_SPEED = GS.PIRATE_FLEET_SPEED

    local fleets = pirateAI.fleets
    local count  = #fleets
    local w      = 240
    local h      = 22 + count * 20 + 8
    local px     = screenW - w - 12
    local py     = 120

    -- 面板背景
    local bg = nvgLinearGradient(vg, px, py, px, py + h,
        nvgRGBA(120, 10, 10, 200), nvgRGBA(60, 0, 0, 180))
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, w, h, 6)
    nvgFillPaint(vg, bg); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 60, 60, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 80, 80, 255))
    nvgText(vg, px + w/2, py + 12, "⚠ 海盗来袭")

    -- 每条舰队信息
    for i, fl in ipairs(fleets) do
        local iy = py + 22 + (i-1) * 20
        local dx  = fl.targetX - fl.x
        local dy  = fl.targetY - fl.y
        local rem = math.sqrt(dx*dx + dy*dy)
        local eta = rem / PIRATE_FLEET_SPEED

        local progress = math.max(0.05, math.min(0.95, 1 - eta / 300))

        local barX = px + 10
        local barW = w - 20
        nvgBeginPath(vg); nvgRect(vg, barX, iy + 8, barW, 4)
        nvgFillColor(vg, nvgRGBA(60, 0, 0, 160)); nvgFill(vg)
        nvgBeginPath(vg); nvgRect(vg, barX, iy + 8, barW * progress, 4)
        local r = math.floor(200 + progress * 55)
        nvgFillColor(vg, nvgRGBA(r, 60, 40, 220)); nvgFill(vg)

        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 180, 140, 230))
        local etaStr = eta > 0 and string.format("~%ds", math.ceil(eta)) or "即将到达!"
        nvgText(vg, barX, iy + 3,
            string.format("Lv%d → %s  %s", fl.pirateLevel, fl.targetName, etaStr))
    end
end

-- ============================================================================
-- drawAnomalyIndicator — 星域异象指示器（右上角）
-- ============================================================================
function M.drawAnomalyIndicator()
    local active = AnomalySystem.GetActive()
    if not active then return end

    local vg      = GS.vg
    local screenW = GS.screenW
    local totalTime = GS.totalTime

    local clr = active.color or {r=180, g=100, b=255}
    local padR = 10
    local iw, ih = 150, 28
    local ix = screenW - iw - padR
    local iy = padR

    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix, iy, iw, ih, 6)
    nvgFillColor(vg, nvgRGBA(10, 5, 30, 190))
    nvgFill(vg)

    local pulse = 0.7 + 0.3 * math.sin(totalTime * 2.5)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix + 0.5, iy + 0.5, iw - 1, ih - 1, 6)
    nvgStrokeColor(vg, nvgRGBA(clr.r, clr.g, clr.b, math.floor(pulse * 160)))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(clr.r, clr.g, clr.b, 230))
    local remaining = active.remainWaves or 0
    nvgText(vg, ix + 6, iy + ih / 2,
        (active.icon or "⚠") .. " " .. (active.name or "异象") .. "  剩余" .. remaining .. "波")
end

-- ============================================================================
-- drawWeatherHUD — 天气指示器（异象指示器下方）
-- ============================================================================
function M.drawWeatherHUD()
    local weather = StarWeather.GetCurrent()
    if not weather then return end

    local vg      = GS.vg
    local screenW = GS.screenW

    local clr = weather.color or { r = 150, g = 150, b = 200 }
    local padR = 10
    local iw, ih = 150, 28
    local ix = screenW - iw - padR
    local anomActive = AnomalySystem.GetActive()
    local iy = anomActive and (padR + 32) or padR

    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix, iy, iw, ih, 6)
    nvgFillColor(vg, nvgRGBA(5, 10, 25, 185))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix + 2, iy + ih - 4, (iw - 4) * (1.0 - weather.progress), 2, 1)
    nvgFillColor(vg, nvgRGBA(clr.r, clr.g, clr.b, 100))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix + 0.5, iy + 0.5, iw - 1, ih - 1, 6)
    nvgStrokeColor(vg, nvgRGBA(clr.r, clr.g, clr.b, 120))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(clr.r, clr.g, clr.b, 220))
    local remSec = math.ceil(weather.remaining)
    nvgText(vg, ix + 6, iy + ih / 2 - 2,
        (weather.icon or "🌤") .. " " .. weather.name .. "  " .. remSec .. "s")
end

-- ============================================================================
-- drawSeedLabel — 种子码标签（小地图上方）
-- ============================================================================
function M.drawSeedLabel()
    local currentSeed = GS.currentSeed
    if not currentSeed then return end

    local vg      = GS.vg
    local screenW = GS.screenW
    local screenH = GS.screenH
    local MINIMAP_W   = GS.MINIMAP_W
    local MINIMAP_H   = GS.MINIMAP_H
    local MINIMAP_PAD = GS.MINIMAP_PAD

    local mx = screenW - MINIMAP_W - MINIMAP_PAD
    local my = screenH - MINIMAP_H - MINIMAP_PAD - 18

    local SHAPE_SHORT = { SPIRAL="旋臂", CLUSTER="星团", CORRIDOR="走廊", TWIN="双核", RING="环带" }
    local currentShape = GS.currentShape
    local shapeName = SHAPE_SHORT[currentShape] or (currentShape or "")
    local label = "SEED " .. currentSeed .. "  " .. shapeName

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(120, 160, 220, 140))
    nvgText(vg, mx + MINIMAP_W, my + 16, label)
end

-- ============================================================================
-- drawMinimap — 小地图（右下角）
-- ============================================================================
function M.drawMinimap()
    local vg      = GS.vg
    local screenW = GS.screenW
    local screenH = GS.screenH
    local zoom    = GS.zoom
    local camera  = GS.camera
    local MINIMAP_W           = GS.MINIMAP_W
    local MINIMAP_H           = GS.MINIMAP_H
    local MINIMAP_PAD         = GS.MINIMAP_PAD
    local MINIMAP_WORLD_RANGE = GS.MINIMAP_WORLD_RANGE
    local starSystems     = GS.starSystems
    local deepSpaceSystems = GS.deepSpaceSystems
    local seedShip        = GS.seedShip
    local pirateAI        = GS.pirateAI
    local mapVariant      = GS.mapVariant
    local rm              = GS.rm

    local mx = screenW - MINIMAP_W - MINIMAP_PAD
    local my = screenH - MINIMAP_H - MINIMAP_PAD

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mx, my, MINIMAP_W, MINIMAP_H, 4)
    nvgFillColor(vg, nvgRGBA(0, 6, 18, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(68, 100, 200, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(100, 160, 255, 160))
    nvgText(vg, mx + 4, my + 2, "星区总览")

    -- 缩放因子
    local scaleX = (MINIMAP_W - 8)  / (MINIMAP_WORLD_RANGE * 2)
    local scaleY = (MINIMAP_H - 14) / (MINIMAP_WORLD_RANGE * 2)
    local offX   = mx + 4 + (MINIMAP_W - 8)  / 2
    local offY   = my + 12 + (MINIMAP_H - 14) / 2

    -- 恒星系
    for _, sys in ipairs(starSystems) do
        local bx = offX + sys.x * scaleX
        local by = offY + sys.y * scaleY
        local hasColony = false
        for _, p in ipairs(sys.planets) do
            if p.colonized then hasColony = true; break end
        end
        nvgBeginPath(vg)
        nvgCircle(vg, bx, by, hasColony and 2.5 or 1.2)
        if hasColony then
            nvgFillColor(vg, nvgRGBA(50, 220, 100, 220))
        else
            nvgFillColor(vg, nvgRGBA(180, 180, 200, 100))
        end
        nvgFill(vg)
    end

    -- 基地/种子飞船标记
    if seedShip then
        local sbx = offX + seedShip.x * scaleX
        local sby = offY + seedShip.y * scaleY
        if seedShip.state == "deployed" or seedShip.colonized then
            local pulse = 0.6 + 0.4 * math.abs(math.sin(seedShip.pulse or 0))
            local baseGlow = nvgRadialGradient(vg, sbx, sby, 4, 10,
                nvgRGBA(0, 220, 120, math.floor(120 * pulse)),
                nvgRGBA(0, 220, 120, 0))
            nvgBeginPath(vg); nvgCircle(vg, sbx, sby, 10)
            nvgFillPaint(vg, baseGlow); nvgFill(vg)
            nvgBeginPath(vg); nvgCircle(vg, sbx, sby, 5 * pulse)
            nvgStrokeColor(vg, nvgRGBA(0, 255, 140, math.floor(220 * pulse)))
            nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            nvgBeginPath(vg); nvgCircle(vg, sbx, sby, 3)
            nvgFillColor(vg, nvgRGBA(0, 255, 140, 255)); nvgFill(vg)
            local cs = 5
            nvgBeginPath(vg)
            nvgMoveTo(vg, sbx - cs, sby); nvgLineTo(vg, sbx - 2, sby)
            nvgMoveTo(vg, sbx + 2, sby); nvgLineTo(vg, sbx + cs, sby)
            nvgMoveTo(vg, sbx, sby - cs); nvgLineTo(vg, sbx, sby - 2)
            nvgMoveTo(vg, sbx, sby + 2); nvgLineTo(vg, sbx, sby + cs)
            nvgStrokeColor(vg, nvgRGBA(0, 255, 140, 200))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(0, 255, 140, 200))
            nvgText(vg, sbx, sby + 6, "基地")
        else
            nvgSave(vg)
            nvgTranslate(vg, sbx, sby)
            nvgRotate(vg, seedShip.angle)
            nvgBeginPath(vg)
            nvgMoveTo(vg,  4, 0); nvgLineTo(vg, -2.5, -2); nvgLineTo(vg, -2.5, 2)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(80, 180, 255, 220)); nvgFill(vg)
            nvgRestore(vg)
        end
    end

    -- 视口矩形
    local cx = screenW / 2
    local cy = screenH / 2
    local wLeft  = (0  - cx) / zoom - camera.x + cx
    local wTop   = (60 - cy) / zoom - camera.y + cy
    local wRight = (screenW - cx) / zoom - camera.x + cx
    local wBot   = (screenH - cy) / zoom - camera.y + cy

    local vx1 = offX + wLeft  * scaleX
    local vy1 = offY + wTop   * scaleY
    local vx2 = offX + wRight * scaleX
    local vy2 = offY + wBot   * scaleY

    nvgBeginPath(vg)
    nvgRect(vg, vx1, vy1, vx2-vx1, vy2-vy1)
    nvgStrokeColor(vg, nvgRGBA(255, 220, 50, 160))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 深空星系
    local hasGateMap = rm and rm.baseBonus and rm.baseBonus.hasWarpGate
    for _, sys in ipairs(deepSpaceSystems) do
        local bx = offX + sys.x * scaleX
        local by = offY + sys.y * scaleY
        nvgBeginPath(vg)
        nvgCircle(vg, bx, by, 1.5)
        if hasGateMap then
            local hasColonyDS = false
            for _, p in ipairs(sys.planets) do
                if p.colonized then hasColonyDS = true; break end
            end
            nvgFillColor(vg, hasColonyDS and nvgRGBA(200, 100, 255, 220) or nvgRGBA(140, 80, 255, 180))
        else
            nvgFillColor(vg, nvgRGBA(60, 40, 100, 60))
        end
        nvgFill(vg)
    end

    -- 海盗基地和舰队
    if pirateAI then pirateAI:renderMinimap(vg, offX, offY, scaleX, scaleY) end

    -- 缩放比例标注
    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(130, 150, 200, 150))
    nvgText(vg, mx + MINIMAP_W - 3, my + MINIMAP_H - 2,
        string.format("x%.1f | 滚轮缩放", zoom))

    -- 星图变体标签
    local VARIANT_SHORT = {
        NORMAL  = { s="标准", r=160, g=180, b=255 },
        DENSE   = { s="密集", r=80,  g=220, b=120 },
        SPARSE  = { s="稀疏", r=255, g=200, b=80  },
        BIPOLAR = { s="双极", r=255, g=100, b=100 },
    }
    local vs = VARIANT_SHORT[mapVariant] or VARIANT_SHORT.NORMAL
    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(vs.r, vs.g, vs.b, 200))
    nvgText(vg, mx + 4, my + 3, "【" .. vs.s .. "】")
end

-- ============================================================================
-- drawPirateThreatHeatmap — 海盗威胁热力图叠层
-- ============================================================================
function M.drawPirateThreatHeatmap()
    local pirateAI = GS.pirateAI
    if not pirateAI then return end

    local vg      = GS.vg
    local zoom    = GS.zoom
    local screenW = GS.screenW
    local screenH = GS.screenH

    for _, base in ipairs(pirateAI.bases) do
        if not base.active then goto continue end
        local bsx, bsy = GS.w2s(base.x, base.y)
        local maxR = (200 + base.level * 60) * zoom
        if bsx < -maxR or bsx > screenW + maxR
        or bsy < -maxR or bsy > screenH + maxR then
            goto continue
        end

        local urgency = 0
        if base.attackTimer and base.attackTimer < 20 then
            urgency = (1 - base.attackTimer / 20) * 0.5
        end
        local baseAlpha  = math.min(90, 30 + base.level * 12) + math.floor(urgency * 60)
        local innerR     = (50 + base.level * 20) * zoom
        local outerR     = (160 + base.level * 55) * zoom

        local grad = nvgRadialGradient(vg, bsx, bsy, innerR, outerR,
            nvgRGBA(220, 60, 30, baseAlpha),
            nvgRGBA(220, 60, 30, 0))
        nvgBeginPath(vg)
        nvgCircle(vg, bsx, bsy, outerR)
        nvgFillPaint(vg, grad)
        nvgFill(vg)

        local coreAlpha = math.min(120, 50 + base.level * 15) + math.floor(urgency * 40)
        local coreGrad = nvgRadialGradient(vg, bsx, bsy, 0, innerR,
            nvgRGBA(255, 100, 20, coreAlpha),
            nvgRGBA(220, 60, 30, 0))
        nvgBeginPath(vg)
        nvgCircle(vg, bsx, bsy, innerR)
        nvgFillPaint(vg, coreGrad)
        nvgFill(vg)

        if zoom >= 0.7 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, math.max(9, 10 * zoom))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 130, 60, 180))
            nvgText(vg, bsx, bsy - innerR - 4 * zoom,
                "海盗 Lv." .. base.level)
        end
        ::continue::
    end
end

-- ============================================================================
-- drawColonyRipples — 殖民涟漪动画（3圈同心扩散波 + 中心闪光）
-- ============================================================================
function M.drawColonyRipples()
    local colonyRipples = GS.colonyRipples
    if #colonyRipples == 0 then return end

    local vg   = GS.vg
    local zoom = GS.zoom

    for _, rp in ipairs(colonyRipples) do
        local planet = rp.planet
        local cx = planet._sx
        local cy = planet._sy
        if not cx then goto nextRipple end
        local prog   = rp.t / rp.dur
        local baseR  = planet.size * zoom

        for wave = 0, 2 do
            local phase = prog + wave * 0.33
            if phase > 1 then phase = phase - 1 end
            if phase < 0.85 then
                local eased = 1 - (1 - phase / 0.85) ^ 2
                local alpha = math.floor((1 - phase / 0.85) * 180)
                local r1 = baseR + eased * baseR * 5.0
                local r2 = r1 + 3 * zoom
                local grad = nvgRadialGradient(vg, cx, cy, r1, r2,
                    nvgRGBA(60, 255, 120, alpha),
                    nvgRGBA(60, 255, 120, 0))
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, r2)
                nvgFillPaint(vg, grad)
                nvgFill(vg)
            end
        end

        local flashDur  = 0.35 / rp.dur
        if prog < flashDur then
            local fp    = prog / flashDur
            local fa    = math.floor((1 - fp) ^ 1.5 * 220)
            local fr    = baseR * (1 + fp * 1.8)
            local fGrad = nvgRadialGradient(vg, cx, cy, 0, fr,
                nvgRGBA(180, 255, 200, fa),
                nvgRGBA(60, 255, 120, 0))
            nvgBeginPath(vg)
            nvgCircle(vg, cx, cy, fr)
            nvgFillPaint(vg, fGrad)
            nvgFill(vg)
        end
        ::nextRipple::
    end
end

-- ============================================================================
-- drawSignalButton — 快捷信号按钮 + 弹出面板（右下角）
-- ============================================================================
function M.drawSignalButton()
    local seedShip = GS.seedShip
    if not seedShip or seedShip.state ~= "deployed" then return end

    local vg      = GS.vg
    local screenW = GS.screenW
    local screenH = GS.screenH
    local mouseX  = GS.mouseX
    local mouseY  = GS.mouseY
    local signalOpen      = GS.signalOpen
    local signalCooldowns = GS.signalCooldowns
    local QUICK_SIGNALS   = GS.QUICK_SIGNALS
    local SIGNAL_CD       = GS.SIGNAL_CD

    local BW     = 44
    local PAD    = 8
    local btnX   = screenW - BW - PAD
    local btnY   = screenH - BW - PAD - 50

    -- 主按钮背景
    local bgAlpha = signalOpen and 220 or 180
    local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX+BW, btnY+BW,
        nvgRGBA(40, 120, 200, bgAlpha), nvgRGBA(20, 70, 150, bgAlpha))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, BW, BW, 10)
    nvgFillPaint(vg, btnGrad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 180, 255, signalOpen and 255 or 160))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, BW, BW, 10)
    nvgStroke(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, btnX + BW*0.5, btnY + BW*0.5, "📡")

    -- 展开面板
    if not signalOpen then return end

    local ITEM_H  = 40
    local PANEL_W = 180
    local panelX  = screenW - PANEL_W - PAD
    local panelY  = btnY - #QUICK_SIGNALS * ITEM_H - 8

    local panelGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + #QUICK_SIGNALS*ITEM_H,
        nvgRGBA(15, 40, 80, 230), nvgRGBA(8, 25, 55, 235))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panelX, panelY, PANEL_W, #QUICK_SIGNALS * ITEM_H, 8)
    nvgFillPaint(vg, panelGrad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 140, 220, 180))
    nvgStrokeWidth(vg, 1)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panelX, panelY, PANEL_W, #QUICK_SIGNALS * ITEM_H, 8)
    nvgStroke(vg)

    for i, sig in ipairs(QUICK_SIGNALS) do
        local iy  = panelY + (i - 1) * ITEM_H
        local cd  = signalCooldowns[i]
        local onCD = cd and cd > 0

        if mouseX >= panelX and mouseX <= panelX + PANEL_W
           and mouseY >= iy and mouseY <= iy + ITEM_H then
            nvgBeginPath(vg)
            nvgRect(vg, panelX, iy, PANEL_W, ITEM_H)
            nvgFillColor(vg, nvgRGBA(80, 160, 255, onCD and 30 or 60))
            nvgFill(vg)
        end

        if i > 1 then
            nvgBeginPath(vg)
            nvgMoveTo(vg, panelX + 8, iy)
            nvgLineTo(vg, panelX + PANEL_W - 8, iy)
            nvgStrokeColor(vg, nvgRGBA(80, 140, 200, 60))
            nvgStrokeWidth(vg, 0.5)
            nvgStroke(vg)
        end

        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, onCD and 100 or 220))
        nvgText(vg, panelX + 10, iy + ITEM_H * 0.5, sig.icon)

        nvgFontSize(vg, 13)
        local tc = sig.color
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], onCD and 100 or 220))
        nvgText(vg, panelX + 36, iy + ITEM_H * 0.5, sig.text)

        if onCD then
            local cdProg = 1 - cd / SIGNAL_CD
            nvgBeginPath(vg)
            nvgRect(vg, panelX + PANEL_W - 52, iy + ITEM_H*0.5 - 3, 44, 6)
            nvgFillColor(vg, nvgRGBA(40, 60, 100, 180))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, panelX + PANEL_W - 52, iy + ITEM_H*0.5 - 3, 44 * cdProg, 6)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200))
            nvgFill(vg)
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 220, 255, 160))
            nvgText(vg, panelX + PANEL_W - 6, iy + ITEM_H*0.5 + 8,
                string.format("%.0fs", cd))
        end
    end
end

-- ============================================================================
-- drawSignalBanners — 信号横幅（屏幕顶部中央）
-- ============================================================================
function M.drawSignalBanners()
    local signalBanners = GS.signalBanners
    if #signalBanners == 0 then return end

    local vg      = GS.vg
    local screenW = GS.screenW

    local BANNER_H = 36
    local BANNER_W = math.min(400, screenW - 40)
    local bx       = (screenW - BANNER_W) * 0.5

    for i = #signalBanners, 1, -1 do
        local b   = signalBanners[i]
        local idx = #signalBanners - i
        local by  = 58 + idx * (BANNER_H + 6)

        local alpha = b.alpha
        local c = b.color

        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, BANNER_W, BANNER_H, 6)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(alpha * 0.25)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(alpha * 0.7)))
        nvgStrokeWidth(vg, 1.5)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, BANNER_W, BANNER_H, 6)
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, 4, BANNER_H, 6)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], alpha))
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 240, 255, alpha))
        nvgText(vg, bx + BANNER_W * 0.5, by + BANNER_H * 0.5, b.text)
    end
end

return M
