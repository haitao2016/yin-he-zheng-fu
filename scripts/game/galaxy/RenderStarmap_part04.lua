-- Auto-split from RenderStarmap.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function drawPlanetDetails(px, py, ps, ptype, seed)
    if ps < 4 then return end
    local vg = GS.vg

    nvgSave(vg)
    nvgIntersectScissor(vg, px - ps, py - ps, ps * 2, ps * 2)

    if ptype == "Gas Giant" then
        local bands = {
            { y = -0.3, w = 0.5, a = 55 },
            { y =  0.1, w = 0.35, a = 45 },
            { y =  0.45, w = 0.2, a = 35 },
        }
        for _, b in ipairs(bands) do
            local bx = px
            local by = py + ps * b.y
            local bw = ps * 1.8
            local bh = ps * b.w
            nvgBeginPath(vg)
            nvgEllipse(vg, bx, by, bw * 0.5, bh * 0.5)
            nvgFillColor(vg, nvgRGBA(255, 200, 255, b.a))
            nvgFill(vg)
        end

    elseif ptype == "Terran" then
        local s = seed % 31 + 1
        local cnt = 2 + (GS.seededRand(s, 2) - 1)
        for i = 1, cnt do
            local ang = GS.seededRandF(s * i * 7) * math.pi * 2
            local r   = ps * (0.3 + GS.seededRandF(s * i * 13) * 0.25)
            local ex  = px + math.cos(ang) * ps * 0.3
            local ey  = py + math.sin(ang) * ps * 0.3
            nvgBeginPath(vg)
            nvgEllipse(vg, ex, ey, r * 0.9, r * 0.65)
            nvgFillColor(vg, nvgRGBA(60, 200, 80, 80 + i * 12))
            nvgFill(vg)
        end

    elseif ptype == "Desert" then
        for i = 1, 3 do
            local yOff = ps * (-0.4 + (i-1) * 0.4)
            nvgBeginPath(vg)
            nvgMoveTo(vg, px - ps * 0.8, py + yOff)
            nvgBezierTo(vg,
                px - ps * 0.2, py + yOff - ps * 0.1,
                px + ps * 0.2, py + yOff + ps * 0.08,
                px + ps * 0.8, py + yOff)
            nvgStrokeColor(vg, nvgRGBA(255, 235, 160, 70 + i * 15))
            nvgStrokeWidth(vg, math.max(0.8, ps * 0.06))
            nvgStroke(vg)
        end

    elseif ptype == "Oceanic" then
        nvgBeginPath(vg)
        nvgArc(vg, px - ps*0.2, py - ps*0.3, ps*0.5,
            math.pi * 1.1, math.pi * 1.7, NVG_CCW)
        nvgStrokeColor(vg, nvgRGBA(180, 230, 255, 80))
        nvgStrokeWidth(vg, math.max(1, ps * 0.12))
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, px + ps*0.2, py + ps*0.25, ps*0.12)
        nvgFillColor(vg, nvgRGBA(200, 240, 255, 60))
        nvgFill(vg)

    elseif ptype == "Volcanic" then
        local s = seed % 17 + 1
        for i = 1, 3 do
            local startAng = GS.seededRandF(s * i) * math.pi * 2
            local len = ps * (0.4 + GS.seededRandF(s * i * 3) * 0.4)
            nvgBeginPath(vg)
            nvgMoveTo(vg, px + math.cos(startAng) * ps * 0.1,
                          py + math.sin(startAng) * ps * 0.1)
            nvgLineTo(vg, px + math.cos(startAng) * len,
                          py + math.sin(startAng) * len)
            nvgStrokeColor(vg, nvgRGBA(255, 120, 30, 100 + i * 20))
            nvgStrokeWidth(vg, math.max(0.8, ps * 0.05))
            nvgStroke(vg)
        end

    elseif ptype == "Barren" then
        local s = seed % 23 + 1
        for i = 1, 3 do
            local ang  = GS.seededRandF(s * i * 5) * math.pi * 2
            local dist = ps * (0.15 + GS.seededRandF(s * i * 11) * 0.45)
            local cr   = ps * (0.06 + GS.seededRandF(s * i * 7) * 0.08)
            local cx   = px + math.cos(ang) * dist
            local cy   = py + math.sin(ang) * dist
            nvgBeginPath(vg)
            nvgCircle(vg, cx, cy, cr)
            nvgFillColor(vg, nvgRGBA(40, 40, 40, 90))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgCircle(vg, cx, cy, cr)
            nvgStrokeColor(vg, nvgRGBA(90, 80, 70, 70))
            nvgStrokeWidth(vg, math.max(0.5, cr * 0.3))
            nvgStroke(vg)
        end
    end

    nvgRestore(vg)

    -- Gas Giant 行星环
    if ptype == "Gas Giant" then
        local ringColor1 = nvgRGBA(200, 170, 255, 50)
        local ringColor2 = nvgRGBA(180, 150, 230, 35)
        nvgSave(vg)
        nvgBeginPath(vg)
        nvgEllipse(vg, px, py, ps * 1.85, ps * 0.35)
        nvgStrokeColor(vg, ringColor1)
        nvgStrokeWidth(vg, math.max(1.5, ps * 0.22))
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgEllipse(vg, px, py, ps * 2.2, ps * 0.42)
        nvgStrokeColor(vg, ringColor2)
        nvgStrokeWidth(vg, math.max(1, ps * 0.14))
        nvgStroke(vg)
        nvgRestore(vg)
    end
end

-- ============================================================================
-- 行星
-- ============================================================================

local function drawPlanet(sys, planet, sx, sy)
    local vg   = GS.vg
    local zoom = GS.zoom
    local px = sx + math.cos(planet.angle) * planet.orbitRadius * zoom
    local py = sy + math.sin(planet.angle) * planet.orbitRadius * zoom

    planet._sx = px
    planet._sy = py
    local ps = planet.size * zoom

    -- 殖民光晕
    if planet.colonized then
        local glow = nvgRadialGradient(vg, px, py, ps, ps*2.5,
            nvgRGBA(0,200,100,80), nvgRGBA(0,200,100,0))
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, ps*2.5)
        nvgFillPaint(vg, glow)
        nvgFill(vg)
    end

    -- Hover 高亮
    if planet == GS.hoveredPlanet and planet ~= GS.selectedPlanet then
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, ps + 4 * zoom)
        nvgStrokeColor(vg, nvgRGBA(200, 200, 255, 120))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
    end

    -- 行星本体
    local hl   = planet.colorHL
    local sh   = planet.colorSH
    local grad = nvgRadialGradient(vg,
        px - ps*0.35, py - ps*0.35, ps*0.15, ps*1.2,
        nvgRGBA(hl[1], hl[2], hl[3], 255),
        nvgRGBA(sh[1], sh[2], sh[3], 255))
    nvgBeginPath(vg)
    nvgCircle(vg, px, py, ps)
    nvgFillPaint(vg, grad)
    nvgFill(vg)

    -- 类型特化表面细节
    drawPlanetDetails(px, py, ps, planet.ptype, planet.id * 31 + (sys.id or 0) * 7)

    -- 殖民旗帜
    if planet.colonized then
        nvgBeginPath(vg)
        nvgCircle(vg, px, py - ps - 5 * zoom, 3 * zoom)
        nvgFillColor(vg, nvgRGBA(50, 255, 100, 220))
        nvgFill(vg)
    end

    -- 驻守编队旗帜
    local routeAnimT = GS.routeAnimT
    for fid, gp in pairs(GS.garrisonedFleets) do
        if gp == planet then
            local fx  = px + ps + 4 * zoom
            local fy  = py - ps * 0.5
            local fh  = 8 * zoom
            local fw  = 5 * zoom
            local pulse = 0.7 + 0.3 * math.sin(routeAnimT * 3.0 + fid)
            -- 旗杆
            nvgBeginPath(vg)
            nvgMoveTo(vg, fx, fy)
            nvgLineTo(vg, fx, fy + fh * 1.5)
            nvgStrokeColor(vg, nvgRGBA(200, 220, 255, 200))
            nvgStrokeWidth(vg, 1.0 * zoom)
            nvgStroke(vg)
            -- 旗面
            local r, g, b = 60, 140, 255
            if GS.fm and GS.fm.fleets and GS.fm.fleets[fid] then
                local fc = GS.fleetColorCache[fid]
                if fc then r, g, b = fc[1], fc[2], fc[3] end
            end
            nvgBeginPath(vg)
            nvgMoveTo(vg, fx, fy)
            nvgLineTo(vg, fx + fw, fy + fh * 0.4)
            nvgLineTo(vg, fx, fy + fh * 0.8)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(r, g, b, math.floor(pulse * 220)))
            nvgFill(vg)
            -- 编队编号
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, math.max(7, 7 * zoom))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
            nvgText(vg, fx + fw * 0.5, fy + fh * 0.4, tostring(fid))
            break
        end
    end

    -- 殖民动画
    if planet.colonized and planet.colonizeTime then
        local elapsed = routeAnimT - planet.colonizeTime
        local SWEEP_DUR = 3.5

        if elapsed < SWEEP_DUR then
            local progress  = elapsed / SWEEP_DUR
            local sweepAng  = progress * math.pi * 2
            local alpha     = math.floor(180 * math.min(1, progress * 3))

            nvgSave(vg)
            nvgScissor(vg, px - ps, py - ps, ps * 2, ps * 2)
            nvgBeginPath(vg)
            nvgCircle(vg, px, py, ps)
            nvgFillColor(vg, nvgRGBA(30, 200, 80, math.floor(alpha * 0.35)))
            nvgFill(vg)
            nvgRestore(vg)

            local frontAng = -math.pi / 2 + sweepAng
            nvgBeginPath(vg)
            nvgArc(vg, px, py, ps + 1, frontAng - 0.4, frontAng + 0.15, NVG_CW)
            nvgStrokeColor(vg, nvgRGBA(80, 255, 140, math.floor(alpha * 0.9)))
            nvgStrokeWidth(vg, 2.0 * zoom)
            nvgStroke(vg)

            nvgBeginPath(vg)
            nvgArc(vg, px, py, ps + 0.5, frontAng - 1.2, frontAng - 0.4, NVG_CW)
            nvgStrokeColor(vg, nvgRGBA(40, 200, 100, math.floor(alpha * 0.4)))
            nvgStrokeWidth(vg, 1.2 * zoom)
            nvgStroke(vg)
        else
            local shimmer = 0.4 + 0.6 * math.abs(math.sin(routeAnimT * 0.8 + planet.id * 1.3))
            local sAlpha  = math.floor(shimmer * 28)
            local tGrad = nvgRadialGradient(vg, px - ps * 0.2, py - ps * 0.2, 0, ps,
                nvgRGBA(40, 220, 100, sAlpha),
                nvgRGBA(20, 140, 60, math.floor(sAlpha * 0.3)))
            nvgBeginPath(vg)
            nvgCircle(vg, px, py, ps)
            nvgFillPaint(vg, tGrad)
            nvgFill(vg)
        end
    end

    -- 殖民优先标记
    if GS.priorityPlanetIds[planet.id] and not planet.colonized then
        local pulse = 0.55 + 0.45 * math.sin(routeAnimT * 3.0)
        local glowA = math.floor(pulse * 80)
        local glow2 = nvgRadialGradient(vg, px, py, ps, ps * 3.2,
            nvgRGBA(255, 160, 30, glowA), nvgRGBA(255, 160, 30, 0))
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, ps * 3.2)
        nvgFillPaint(vg, glow2)
        nvgFill(vg)
        -- 右上角菱形
        local mx2 = px + ps * 0.75
        local my2 = py - ps * 0.75
        local ir  = 3.5 * zoom
        nvgBeginPath(vg)
        nvgMoveTo(vg, mx2,      my2 - ir)
        nvgLineTo(vg, mx2 + ir, my2)
        nvgLineTo(vg, mx2,      my2 + ir)
        nvgLineTo(vg, mx2 - ir, my2)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 170, 40, math.floor(pulse * 230 + 25)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 200))
        nvgStrokeWidth(vg, 1.0)
        nvgStroke(vg)
    end

    -- 行星名
    if zoom >= 1.4 then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, math.max(8, 9 * zoom))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, 160))
        nvgText(vg, px, py + ps + 2, planet.name)
    end

    -- 卫星
    if planet.satellites and #planet.satellites > 0 then
        local maxMoonOrbit = (16 + planet.size) * zoom
        if px > -maxMoonOrbit - 100 and px < GS.screenW + maxMoonOrbit + 100
        and py > -maxMoonOrbit - 100 and py < GS.screenH + maxMoonOrbit + 100 then
            for _, moon in ipairs(planet.satellites) do
                local moonOrbit = moon.orbitR * zoom
                local moonAngle = moon.angle0 + (routeAnimT / moon.period) * (math.pi * 2)
                local mx = px + math.cos(moonAngle) * moonOrbit
                local my = py + math.sin(moonAngle) * moonOrbit
                local mr = math.max(1, moon.radius * zoom)
                local mc = moon.color

                if planet.colonized then
                    nvgBeginPath(vg)
                    nvgCircle(vg, px, py, moonOrbit)
                    nvgStrokeColor(vg, nvgRGBA(mc[1], mc[2], mc[3], 35))
                    nvgStrokeWidth(vg, math.max(0.5, 0.6 * zoom))
                    nvgStroke(vg)
                end

                local mhl = {math.min(255,mc[1]+60)//1, math.min(255,mc[2]+60)//1, math.min(255,mc[3]+60)//1}
                local msh = {math.max(0,mc[1]-30)//1,   math.max(0,mc[2]-30)//1,   math.max(0,mc[3]-30)//1}
                local mgrad = nvgRadialGradient(vg,
                    mx - mr * 0.3, my - mr * 0.3, mr * 0.1, mr * 1.2,
                    nvgRGBA(mhl[1], mhl[2], mhl[3], 230),
                    nvgRGBA(msh[1], msh[2], msh[3], 210))
                nvgBeginPath(vg)
                nvgCircle(vg, mx, my, mr)
                nvgFillPaint(vg, mgrad)
                nvgFill(vg)
            end
        end
    end

    -- 选中高亮
    if planet == GS.selectedPlanet then
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, ps + 5 * zoom)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 50, 200))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, ps + 9 * zoom)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 50, 80))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 恒星系统
-- ============================================================================

function M.drawStarSystem(sys)
    local vg   = GS.vg
    local zoom = GS.zoom
    local sx, sy = GS.w2s(sys.x, sys.y)

    -- 缓存屏幕坐标供 tooltip 使用
    sys._sx = sx
    sys._sy = sy

    -- 视锥剔除
    local maxRadius = (45 + 5 * 32 + 20) * zoom
    if sx < -maxRadius or sx > GS.screenW + maxRadius
    or sy < -maxRadius or sy > GS.screenH + maxRadius then
        for _, p in ipairs(sys.planets) do p._sx=nil; p._sy=nil end
        return
    end

    -- 轨道
    for _, p in ipairs(sys.planets) do
        drawOrbitRing(sx, sy, p.orbitRadius)
    end

    -- 恒星光晕
    local c  = sys.color
    local sr = sys.radius * zoom
    local glow = nvgRadialGradient(vg, sx, sy, 0, sr * 2.5,
        nvgRGBA(c[1],c[2],c[3], 160), nvgRGBA(c[1],c[2],c[3], 0))
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, sr * 2.5)
    nvgFillPaint(vg, glow)
    nvgFill(vg)

    -- 恒星本体
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, sr)
    nvgFillColor(vg, GS.nvgColor(c, 255))
    nvgFill(vg)

    -- 行星
    for _, p in ipairs(sys.planets) do
        drawPlanet(sys, p, sx, sy)
    end

    -- 恒星名称
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.max(8, 10 * zoom))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 140))
    nvgText(vg, sx, sy + sr + 4, sys.name)
end

-- ============================================================================
-- 派系外交关系线
-- ============================================================================

function M.drawDiploRelLines()
    if not GS.diploRelData or not GS.diploRelData.rels then return end
    if GS.zoom < 0.5 then return end
    local vg   = GS.vg
    local zoom = GS.zoom

    -- 收集派系重心
    local factionCenters = {}
    for _, sys in ipairs(GS.starSystems) do
        local fk = sys.neutralFaction
        if fk and sys._sx and sys._sy then
            local c = factionCenters[fk]
            if not c then
                c = { sx = 0, sy = 0, count = 0 }
                factionCenters[fk] = c
            end
            c.sx = c.sx + sys._sx
            c.sy = c.sy + sys._sy
            c.count = c.count + 1
        end
    end
    for _, c in pairs(factionCenters) do
        if c.count > 0 then
            c.sx = c.sx / c.count
            c.sy = c.sy / c.count
        end
    end

    local alpha = math.min(1.0, (zoom - 0.5) * 4)
    for _, r in ipairs(GS.diploRelData.rels) do
        local c1 = factionCenters[r.fk1]
        local c2 = factionCenters[r.fk2]
        if c1 and c2 and c1.count > 0 and c2.count > 0 then
            local col = DIPLO_REL_COLORS[r.rel] or DIPLO_REL_COLORS.neutral
            local lineAlpha = col[4] * alpha

            local mx = (c1.sx + c2.sx) * 0.5
            local my = (c1.sy + c2.sy) * 0.5
            local dx = c2.sx - c1.sx
            local dy = c2.sy - c1.sy
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 20 then goto continue_rel end
            local perpX = -dy / len * 20
            local perpY =  dx / len * 20
            local cpx = mx + perpX
            local cpy = my + perpY

            nvgBeginPath(vg)
            nvgMoveTo(vg, c1.sx, c1.sy)
            nvgQuadTo(vg, cpx, cpy, c2.sx, c2.sy)
            nvgStrokeColor(vg, nvgRGBA(col[1], col[2], col[3], math.floor(lineAlpha)))
            nvgStrokeWidth(vg, 1.5 * zoom)
            nvgStroke(vg)

            -- 关系标签
            local labelX = mx + perpX * 0.5
            local labelY = my + perpY * 0.5
            local labels = { compete = "⚔", neutral = "·", cooperate = "🤝" }
            nvgFontSize(vg, 10 * zoom)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(col[1], col[2], col[3], math.floor(200 * alpha)))
            nvgText(vg, labelX, labelY, labels[r.rel] or "·")

            -- 端点光圈
            for _, pt in ipairs({ {c1, r.fk1}, {c2, r.fk2} }) do
                local center, fk = pt[1], pt[2]
                local fc = DIPLO_FACTION_COLORS[fk]
                if fc then
                    nvgBeginPath(vg)
                    nvgCircle(vg, center.sx, center.sy, 6 * zoom)
                    nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], math.floor(80 * alpha)))
                    nvgFill(vg)
                end
            end

            ::continue_rel::
        end
    end
end

-- ============================================================================
-- 贸易航线
-- ============================================================================

function M.drawTradeRoutes()
    if not GS.seedShip or GS.seedShip.state ~= "deployed" then return end
    if #GS.colonizedPlanets == 0 then return end
    local vg   = GS.vg
    local zoom = GS.zoom
    local routeAnimT = GS.routeAnimT

    -- 有效节点
    local bsx, bsy = GS.w2s(GS.seedShip.x, GS.seedShip.y)
    local nodes = {}
    nodes[1] = { sx = bsx, sy = bsy, isBase = true }
    for _, p in ipairs(GS.colonizedPlanets) do
        if p._sx and p._sy then
            nodes[#nodes + 1] = { sx = p._sx, sy = p._sy, planet = p }
        end
    end
    if #nodes < 2 then return end

    -- 虚线参数
    local DASH_LEN = 10 * zoom
    local GAP_LEN  = 6 * zoom
    local UNIT_LEN = DASH_LEN + GAP_LEN
    local FLOW_SPEED = 18
    local offset = (routeAnimT * FLOW_SPEED) % UNIT_LEN

    -- 基地→殖民星球主干航线
    for i = 2, #nodes do
        local n = nodes[i]
        local dx = n.sx - bsx
        local dy = n.sy - bsy
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 2 then goto continue_route end

        local ux = dx / len
        local uy = dy / len

        local p = n.planet
        local cr, cg, cb = 60, 200, 255
        if p and p.colorHL then
            cr = math.floor(p.colorHL[1] * 0.6 + 60 * 0.4)
            cg = math.floor(p.colorHL[2] * 0.6 + 200 * 0.4)
            cb = math.floor(p.colorHL[3] * 0.6 + 255 * 0.4)
        end

        -- 底层线
        nvgBeginPath(vg)
        nvgMoveTo(vg, bsx, bsy)
        nvgLineTo(vg, n.sx, n.sy)
        nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 18))
        nvgStrokeWidth(vg, math.max(0.5, 1.5 * zoom))
        nvgStroke(vg)

        -- 流动虚线
        local pos = -offset
        local lineW = math.max(0.8, 1.8 * zoom)
        while pos < len do
            local dashStart = math.max(0, pos)
            local dashEnd   = math.min(len, pos + DASH_LEN)
            if dashEnd > dashStart then
                local alpha2 = 120 + math.floor(60 * math.abs(math.sin(
                    routeAnimT * 1.5 + (pos / len) * math.pi)))
                nvgBeginPath(vg)
                nvgMoveTo(vg, bsx + ux * dashStart, bsy + uy * dashStart)
                nvgLineTo(vg, bsx + ux * dashEnd,   bsy + uy * dashEnd)
                nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, alpha2))
                nvgStrokeWidth(vg, lineW)
                nvgStroke(vg)
            end
            pos = pos + UNIT_LEN
        end

        -- 端点菱形
        local planetSize = (p and p.size or 5) * zoom
        local markDist = planetSize + 6 * zoom
        if markDist < len then
            local mx = n.sx - ux * markDist
            local my = n.sy - uy * markDist
            local ms = math.max(2, 3 * zoom)
            local pulse = 0.7 + 0.3 * math.abs(math.sin(routeAnimT * 2.2 + i * 0.8))
            nvgBeginPath(vg)
            nvgMoveTo(vg, mx,      my - ms * pulse)
            nvgLineTo(vg, mx + ms * pulse, my)
            nvgLineTo(vg, mx,      my + ms * pulse)
            nvgLineTo(vg, mx - ms * pulse, my)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(cr, cg, cb, math.floor(180 * pulse)))
            nvgFill(vg)
        end

        ::continue_route::
    end

    -- 次级横向航线
    if #nodes >= 3 then
        for i = 2, #nodes - 1 do
            local a = nodes[i]
            local b = nodes[i + 1]
            local dx = b.sx - a.sx
            local dy = b.sy - a.sy
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 5 then
                local ux2 = dx / len
                local uy2 = dy / len
                local pos = -offset * 0.7
                while pos < len do
                    local dashStart = math.max(0, pos)
                    local dashEnd   = math.min(len, pos + DASH_LEN * 0.8)
                    if dashEnd > dashStart then
                        nvgBeginPath(vg)
                        nvgMoveTo(vg, a.sx + ux2 * dashStart, a.sy + uy2 * dashStart)
                        nvgLineTo(vg, a.sx + ux2 * dashEnd,   a.sy + uy2 * dashEnd)
                        nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 55))
                        nvgStrokeWidth(vg, math.max(0.5, 1.0 * zoom))
                        nvgStroke(vg)
                    end
                    pos = pos + UNIT_LEN
                end
            end
        end
    end
end

-- ============================================================================
-- 远征路径
-- ============================================================================

function M.drawExpeditionPaths()
    if #GS.expeditionPaths == 0 then return end
    local vg   = GS.vg
    local zoom = GS.zoom
    local routeAnimT = GS.routeAnimT

    local DASH_LEN = 8 * zoom
    local GAP_LEN  = 5 * zoom
    local UNIT_LEN = DASH_LEN + GAP_LEN
    local FLOW_SPD = 22
    local offset   = (routeAnimT * FLOW_SPD) % UNIT_LEN

    for _, exp in ipairs(GS.expeditionPaths) do
        local sx1, sy1 = GS.w2s(exp.startX, exp.startY)
        local sx2, sy2 = GS.w2s(exp.baseX, exp.baseY)
        local dx = sx2 - sx1
        local dy = sy2 - sy1
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 4 then goto continue_exp end

        local ux = dx / len
        local uy = dy / len

        -- 底层线
        nvgBeginPath(vg)
        nvgMoveTo(vg, sx1, sy1)
        nvgLineTo(vg, sx2, sy2)
        nvgStrokeColor(vg, nvgRGBA(255, 140, 40, 20))
        nvgStrokeWidth(vg, math.max(0.5, 1.2 * zoom))
        nvgStroke(vg)

        -- 橙色流动虚线
        local pos = -offset
        local lineW = math.max(0.8, 1.8 * zoom)
        while pos < len do
            local dStart = math.max(0, pos)
            local dEnd   = math.min(len, pos + DASH_LEN)
            if dEnd > dStart then
                local alpha = 140 + math.floor(50 * math.abs(math.sin(routeAnimT * 2 + pos / len * math.pi)))
                nvgBeginPath(vg)
                nvgMoveTo(vg, sx1 + ux * dStart, sy1 + uy * dStart)
                nvgLineTo(vg, sx1 + ux * dEnd,   sy1 + uy * dEnd)
                nvgStrokeColor(vg, nvgRGBA(255, 160, 50, alpha))
                nvgStrokeWidth(vg, lineW)
                nvgStroke(vg)
            end
            pos = pos + UNIT_LEN
        end

        -- 编队图标
        local progress = math.min(1.0, (exp.elapsed or 0) / math.max(1, exp.duration))
        local ix = sx1 + dx * progress
        local iy = sy1 + dy * progress
        local iconR = math.max(4, 6 * zoom)

        nvgBeginPath(vg)
        nvgCircle(vg, ix, iy, iconR * 1.6)
        nvgFillColor(vg, nvgRGBA(255, 140, 40, 35))
        nvgFill(vg)

        local angle = math.atan(dy, dx)
        nvgSave(vg)
        nvgTranslate(vg, ix, iy)
        nvgRotate(vg, angle)
        nvgBeginPath(vg)
        nvgMoveTo(vg, iconR, 0)
        nvgLineTo(vg, -iconR * 0.6, -iconR * 0.7)
        nvgLineTo(vg, -iconR * 0.6,  iconR * 0.7)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 180, 60, 220))
        nvgFill(vg)
        nvgRestore(vg)

        ::continue_exp::
    end
end

-- ============================================================================
-- 深空星系
-- ============================================================================

function M.drawDeepSpaceSystem(sys, animT)
    local vg   = GS.vg
    local zoom = GS.zoom
    local sx, sy = GS.w2s(sys.x, sys.y)
    local maxRadius = (50 + 6 * 36 + 20) * zoom
    if sx < -maxRadius or sx > GS.screenW + maxRadius
    or sy < -maxRadius or sy > GS.screenH + maxRadius then
        for _, p in ipairs(sys.planets) do p._sx=nil; p._sy=nil end
        return
    end

    local hasGate = GS.rm and GS.rm.baseBonus and GS.rm.baseBonus.hasWarpGate
    local pulse   = 0.5 + 0.5 * math.sin(animT * 2.5 + sys.id * 0.7)

    if not hasGate then
        local sr = sys.radius * zoom
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, sr * 1.8)
        nvgStrokeColor(vg, nvgRGBA(80, 80, 120, 80))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, sr)
        nvgFillColor(vg, nvgRGBA(40, 40, 60, 180))
        nvgFill(vg)
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, math.max(9, 11 * zoom))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 80, 140, 160))
        nvgText(vg, sx, sy, "?")
        if zoom >= 0.9 then
            nvgFontSize(vg, math.max(7, 8 * zoom))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(80, 80, 140, 100))
            nvgText(vg, sx, sy + sr + 3, "需要曲速闸门")
        end
        return
    end

    -- 解锁状态
    local sr = sys.radius * zoom
    local gAlpha = math.floor(80 + 60 * pulse)
    local glowPaint = nvgRadialGradient(vg, sx, sy, 0, sr * 3.5,
        nvgRGBA(120, 60, 255, gAlpha), nvgRGBA(120, 60, 255, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, sr * 3.5)
    nvgFillPaint(vg, glowPaint)
    nvgFill(vg)

    for _, p in ipairs(sys.planets) do
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, p.orbitRadius * zoom)
        nvgStrokeColor(vg, nvgRGBA(100, 60, 200, 20))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end

    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, sr)
    nvgFillColor(vg, nvgRGBA(120, 60, 255, 220))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, sr + 4 * zoom * pulse)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 255, math.floor(180 * pulse)))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.max(10, 12 * zoom))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 160, 255, 220))
    nvgText(vg, sx, sy, "⚡")

    for _, p in ipairs(sys.planets) do
        drawPlanet(sys, p, sx, sy)
    end

    if zoom >= 0.7 then
        nvgFontSize(vg, math.max(8, 9 * zoom))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 140, 255, 180))
        nvgText(vg, sx, sy + sr + 4, "⚡" .. sys.name)
    end
end

-- ============================================================================
-- 海盗威胁热力图
-- ============================================================================

function M.drawPirateThreatHeatmap()
    if not GS.pirateAI then return end
    local vg   = GS.vg
    local zoom = GS.zoom
    local routeAnimT = GS.routeAnimT

    for _, base in ipairs(GS.pirateAI.bases) do
        if not base.active then goto continue end
        local bsx, bsy = GS.w2s(base.x, base.y)
        local maxR = (200 + base.level * 60) * zoom
        if bsx < -maxR or bsx > GS.screenW + maxR
        or bsy < -maxR or bsy > GS.screenH + maxR then
            goto continue
        end

        local urgency = 0
        if base.attackTimer and base.attackTimer < 20 then
            urgency = (1 - base.attackTimer / 20) * 0.5
        end
        local baseAlpha = math.min(90, 30 + base.level * 12) + math.floor(urgency * 60)
        local innerR    = (50 + base.level * 20) * zoom
        local outerR    = (160 + base.level * 55) * zoom

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
-- 殖民涟漪动画
-- ============================================================================

function M.drawColonyRipples()
    if #GS.colonyRipples == 0 then return end
    local vg   = GS.vg
    local zoom = GS.zoom

    for _, r in ipairs(GS.colonyRipples) do
        local planet = r.planet
        local cx = planet._sx
        local cy = planet._sy
        if not cx then goto nextRipple end
        local prog  = r.t / r.dur
        local baseR = planet.size * zoom

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

        local flashDur = 0.35 / r.dur
        if prog < flashDur then
            local fp = prog / flashDur
            local fa = math.floor((1 - fp) ^ 1.5 * 220)
            local fr = baseR * (1 + fp * 1.8)
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

return M
