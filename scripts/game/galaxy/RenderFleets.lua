-- ============================================================================
-- game/galaxy/RenderFleets.lua  — 编队 / 种子飞船 / 小行星 渲染
-- 从 GalaxyScene.lua 提取的纯渲染函数
-- ============================================================================

local GS = require("game.galaxy.GalaxyState")

local M = {}

-- ============================================================================
-- drawAsteroids — 渲染所有小行星（图片/回退六边形）
-- ============================================================================
function M.drawAsteroids()
    local vg   = GS.vg
    local zoom = GS.zoom
    local screenW = GS.screenW
    local screenH = GS.screenH
    local ASTEROID_TYPES = GS.ASTEROID_TYPES
    local ASTEROID_SIZES = GS.ASTEROID_SIZES
    local asteroidImgs   = GS.asteroidImgs
    local selectedFleetId = GS.selectedFleetId
    local fleetObjs       = GS.fleetObjs

    for _, a in ipairs(GS.asteroids) do
        if not a.health or a.health <= 0 then goto continue end
        local sx, sy = GS.w2s(a.x, a.y)
        -- 视锥裁剪
        if sx < -20 or sx > screenW+20 or sy < -20 or sy > screenH+20 then
            goto continue
        end
        local r  = a.size * zoom
        local cfg = ASTEROID_TYPES[a.atype]
        local c  = cfg.color
        -- 耐久度影响透明度
        local hpPct = (a.health or a.hp or 0) / (a.maxHealth or a.maxHP or 1)
        local alpha = math.floor(120 + 100 * hpPct)
        -- 旋转渲染小行星图片
        nvgSave(vg)
        nvgTranslate(vg, sx, sy)
        nvgRotate(vg, a.angle)
        local imgH = asteroidImgs[a.atype]
        if imgH and imgH >= 0 then
            local half = r * 1.4
            nvgGlobalAlpha(vg, alpha / 255)
            local paint = nvgImagePattern(vg, -half, -half, half*2, half*2, 0, imgH, 1.0)
            nvgBeginPath(vg); nvgRect(vg, -half, -half, half*2, half*2)
            nvgFillPaint(vg, paint); nvgFill(vg)
            nvgGlobalAlpha(vg, 1.0)
        else
            -- 回退：六边形
            nvgBeginPath(vg)
            for k = 0, 5 do
                local theta = k * math.pi / 3
                local jitter = 1 + (k % 2) * 0.3
                local px2 = math.cos(theta) * r * jitter
                local py2 = math.sin(theta) * r * jitter
                if k == 0 then nvgMoveTo(vg, px2, py2) else nvgLineTo(vg, px2, py2) end
            end
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], alpha))
            nvgFill(vg)
        end
        nvgRestore(vg)
        -- 选中编队的采矿目标高亮（脉冲圆环）
        local selMining = selectedFleetId and fleetObjs[selectedFleetId]
            and fleetObjs[selectedFleetId].miningTarget
        if a == selMining then
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, r * 1.6)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 80, 180))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
        -- 大型小行星额外光晕（强调珍贵）
        if a.sizeKey == "large" then
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, r * 1.5)
            nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], 50))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        end
        -- 缩放足够大时显示资源标签（含尺寸前缀）
        if zoom > 0.9 then
            local szCfg   = ASTEROID_SIZES[a.sizeKey or "medium"]
            local sizeLabel = szCfg and szCfg.label or ""
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 9 * zoom)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 200))
            nvgText(vg, sx, sy + r + 2, sizeLabel .. cfg.label)
        end
        ::continue::
    end
end

-- ============================================================================
-- drawFleets — 渲染所有编队地图对象
-- ============================================================================
function M.drawFleets()
    local vg   = GS.vg
    local zoom = GS.zoom
    local screenW = GS.screenW
    local screenH = GS.screenH
    local fm   = GS.fm
    if not fm then return end

    local fleetObjs       = GS.fleetObjs
    local selectedFleetId = GS.selectedFleetId
    local FLEET_MINE_INTERVAL = GS.FLEET_MINE_INTERVAL

    for i = 1, fm.maxFleets do
        local fl = fm.fleets[i]
        if not fl or #fl.ships == 0 then goto nextFleet end
        local obj = fleetObjs[i]
        if not obj then goto nextFleet end

        local sx, sy = GS.w2s(obj.x, obj.y)
        -- 视锥裁剪
        if sx < -30 or sx > screenW+30 or sy < -30 or sy > screenH+30 then
            goto nextFleet
        end

        local isSelected = (selectedFleetId == i)
        local pulse      = math.abs(math.sin(obj.pulse * 2)) * 0.4 + 0.6
        local c          = GS.getFleetColor(i)
        local r          = (isSelected and 11 or 9) * zoom

        -- 移动目标虚线
        if obj.targetX then
            local tx, ty = GS.w2s(obj.targetX, obj.targetY)
            local tlen = math.sqrt((tx-sx)^2+(ty-sy)^2)
            if tlen > 1 then
                local nx, ny = (tx-sx)/tlen, (ty-sy)/tlen
                local pos, drawing = 0, true
                nvgBeginPath(vg)
                while pos < tlen do
                    local ex = math.min(pos + (drawing and 8 or 5), tlen)
                    if drawing then
                        nvgMoveTo(vg, sx+nx*pos, sy+ny*pos)
                        nvgLineTo(vg, sx+nx*ex,  sy+ny*ex)
                    end
                    pos = ex; drawing = not drawing
                end
                nvgStrokeColor(vg, nvgRGBA(c[1],c[2],c[3], 90))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)

                -- 目标十字
                local cr = 6 * zoom * pulse
                nvgBeginPath(vg); nvgCircle(vg, tx, ty, cr)
                nvgStrokeColor(vg, nvgRGBA(c[1],c[2],c[3], math.floor(160*pulse)))
                nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            end
        end

        -- 选中光圈
        if isSelected then
            local selR = r * 2.2 * pulse
            local glow = nvgRadialGradient(vg, sx, sy, r, selR,
                nvgRGBA(c[1],c[2],c[3], 80), nvgRGBA(c[1],c[2],c[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, selR)
            nvgFillPaint(vg, glow); nvgFill(vg)

            nvgBeginPath(vg); nvgCircle(vg, sx, sy, r * 1.5)
            nvgStrokeColor(vg, nvgRGBA(c[1],c[2],c[3], math.floor(180*pulse)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end

        -- 引擎尾焰（移动中）
        if obj.targetX then
            local tailX = sx - math.cos(obj.angle) * r * 1.4
            local tailY = sy - math.sin(obj.angle) * r * 1.4
            local flameG = nvgLinearGradient(vg, sx, sy, tailX, tailY,
                nvgRGBA(c[1],c[2],c[3], 200), nvgRGBA(c[1],c[2],c[3], 0))
            nvgBeginPath(vg)
            nvgMoveTo(vg, tailX + math.cos(obj.angle+math.pi/2)*3*zoom,
                           tailY + math.sin(obj.angle+math.pi/2)*3*zoom)
            nvgLineTo(vg, sx, sy)
            nvgLineTo(vg, tailX - math.cos(obj.angle+math.pi/2)*3*zoom,
                           tailY - math.sin(obj.angle+math.pi/2)*3*zoom)
            nvgClosePath(vg)
            nvgFillPaint(vg, flameG); nvgFill(vg)
        end

        -- 船体（箭头形）
        nvgSave(vg)
        nvgTranslate(vg, sx, sy)
        nvgRotate(vg, obj.angle)
        nvgBeginPath(vg)
        nvgMoveTo(vg,  r*1.2, 0)
        nvgLineTo(vg, -r*0.8,  r*0.6)
        nvgLineTo(vg, -r*0.4, 0)
        nvgLineTo(vg, -r*0.8, -r*0.6)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(c[1],c[2],c[3], math.floor(200 + pulse*50)))
        nvgFill(vg)
        -- 描边
        nvgStrokeColor(vg, nvgRGBA(255,255,255, isSelected and 180 or 100))
        nvgStrokeWidth(vg, isSelected and 1.5 or 1.0); nvgStroke(vg)
        nvgRestore(vg)

        -- 采矿光束（编队静止且有采矿目标时）
        if not obj.targetX and obj.miningTarget and obj.miningTarget.hp > 0 then
            local a  = obj.miningTarget
            local tx, ty = GS.w2s(a.x, a.y)
            local mineBeamPulse = math.abs(math.sin((obj.mineTimer or 0) * math.pi / FLEET_MINE_INTERVAL))
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, tx, ty)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(200 * mineBeamPulse)))
            nvgStrokeWidth(vg, 2.0 * zoom)
            nvgStroke(vg)
        end

        -- 编队标签 + 舰船数
        local totalShips = 0
        for _, e in ipairs(fl.ships) do totalShips = totalShips + e.count end
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, math.max(8, 10 * zoom))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(c[1],c[2],c[3], 220))
        nvgText(vg, sx, sy + r + 3, "编队" .. i .. " ×" .. totalShips)

        ::nextFleet::
    end
end

-- ============================================================================
-- drawSeedShip — 渲染种子飞船 / 星航基地
-- ============================================================================
function M.drawSeedShip()
    local vg   = GS.vg
    local zoom = GS.zoom
    local ss   = GS.seedShip
    if not ss then return end

    local sx, sy = GS.w2s(ss.x, ss.y)
    local SEED_DEPLOY_DUR = GS.SEED_DEPLOY_DUR
    local seedClickTarget = GS.seedClickTarget
    local keyDown         = GS.keyDown
    local imgSeedShip     = GS.imgSeedShip
    local imgBaseStation  = GS.imgBaseStation

    -- 点击移动目标：虚线路径 + 目标光标
    if seedClickTarget and ss.state == "moving" then
        local tx, ty = GS.w2s(seedClickTarget.x, seedClickTarget.y)
        -- 虚线连线
        local tlen = math.sqrt((tx-sx)*(tx-sx) + (ty-sy)*(ty-sy))
        if tlen > 1 then
            local nx, ny = (tx-sx)/tlen, (ty-sy)/tlen
            local pos = 0
            local drawing = true
            nvgBeginPath(vg)
            while pos < tlen do
                local ex = math.min(pos + (drawing and 10 or 6), tlen)
                if drawing then
                    nvgMoveTo(vg, sx + nx*pos, sy + ny*pos)
                    nvgLineTo(vg, sx + nx*ex,  sy + ny*ex)
                end
                pos = ex
                drawing = not drawing
            end
            nvgStrokeColor(vg, nvgRGBA(80, 200, 255, 110))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)
        end

        -- 目标光标（脉冲十字圆）
        local pulse = math.abs(math.sin(ss.pulse * 3)) * 0.4 + 0.6
        local cr = 8 * zoom * pulse
        nvgBeginPath(vg)
        nvgCircle(vg, tx, ty, cr)
        nvgStrokeColor(vg, nvgRGBA(80, 220, 255, math.floor(180 * pulse)))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
        -- 十字线
        nvgBeginPath(vg)
        nvgMoveTo(vg, tx - cr * 1.4, ty); nvgLineTo(vg, tx - cr * 0.5, ty)
        nvgMoveTo(vg, tx + cr * 0.5, ty); nvgLineTo(vg, tx + cr * 1.4, ty)
        nvgMoveTo(vg, tx, ty - cr * 1.4); nvgLineTo(vg, tx, ty - cr * 0.5)
        nvgMoveTo(vg, tx, ty + cr * 0.5); nvgLineTo(vg, tx, ty + cr * 1.4)
        nvgStrokeColor(vg, nvgRGBA(80, 220, 255, math.floor(200 * pulse)))
        nvgStrokeWidth(vg, 1.2)
        nvgStroke(vg)
    end

    local t   = ss.timer
    local pct = (ss.state == "deploying") and math.min(1, t / SEED_DEPLOY_DUR) or
                (ss.state == "deployed")  and 1 or 0
    local pulse = math.abs(math.sin(ss.pulse * 2)) * 0.5 + 0.5  -- 0.5~1.0

    -- 展开状态：基地光圈（deployed 后显示，颜色/大小随核心等级变化）
    if ss.state == "deployed" then
        local lv = ss.coreLevel or 1
        -- 等级越高，光圈越大
        local baseR = (math.min(110, 55 + lv * 5) + pulse * (4 + lv * 0.5)) * zoom
        -- 颜色渐变
        local cr, cg, cb
        if lv <= 2 then
            cr, cg, cb = 0, 200, 120
        elseif lv <= 5 then
            local tf = (lv - 2) / 3
            cr = math.floor(0 + tf * 80)
            cg = math.floor(200 - tf * 60)
            cb = math.floor(120 + tf * 135)
        elseif lv <= 8 then
            local tf = (lv - 5) / 3
            cr = math.floor(80  + tf * 175)
            cg = math.floor(140 - tf * 90)
            cb = math.floor(255 - tf * 55)
        else
            cr, cg, cb = 255, 200, 60
        end
        -- 外发光
        local glow = nvgRadialGradient(vg, sx, sy, baseR * 0.3, baseR,
            nvgRGBA(cr, cg, cb, 70), nvgRGBA(cr, cg, cb, 0))
        nvgBeginPath(vg); nvgCircle(vg, sx, sy, baseR)
        nvgFillPaint(vg, glow); nvgFill(vg)
        -- 外圈线
        nvgBeginPath(vg); nvgCircle(vg, sx, sy, baseR)
        nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, math.floor(80 + pulse * 70)))
        nvgStrokeWidth(vg, math.min(3.0, 1.2 + lv * 0.2)); nvgStroke(vg)
        -- 高等级（Lv5+）额外内圈
        if lv >= 5 then
            local innerR = baseR * 0.55
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, innerR)
            nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, math.floor(50 + pulse * 50)))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        end
        -- Lv8+ 旋转轨道环
        if lv >= 8 then
            local orbitR = baseR * 0.75
            local orbitAngle = ss.pulse * 0.8
            for oi = 0, 2 do
                local oa = orbitAngle + oi * math.pi * 2 / 3
                local dotX = sx + math.cos(oa) * orbitR
                local dotY = sy + math.sin(oa) * orbitR
                nvgBeginPath(vg); nvgCircle(vg, dotX, dotY, 2.5 * zoom)
                nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220)); nvgFill(vg)
            end
        end
    end

    -- 展开动画：扩散光环
    if ss.state == "deploying" then
        for i = 1, 3 do
            local ringPct = math.max(0, pct - (i-1) * 0.15)
            local ringR   = ringPct * 80 * zoom
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, ringR)
            nvgStrokeColor(vg, nvgRGBA(100, 220, 255,
                math.floor((1 - ringPct) * 180)))
            nvgStrokeWidth(vg, 2 - ringPct); nvgStroke(vg)
        end
    end

    -- 移动时：引擎尾焰
    if ss.state == "moving" then
        local moving = keyDown.up or keyDown.down or keyDown.left or keyDown.right
        if moving then
            local tailX = sx - math.cos(ss.angle) * 14 * zoom
            local tailY = sy - math.sin(ss.angle) * 14 * zoom
            local flameGrad = nvgLinearGradient(vg, sx, sy, tailX, tailY,
                nvgRGBA(100, 180, 255, 220), nvgRGBA(60, 120, 255, 0))
            nvgBeginPath(vg)
            nvgMoveTo(vg, tailX + math.cos(ss.angle + math.pi/2) * 4 * zoom,
                           tailY + math.sin(ss.angle + math.pi/2) * 4 * zoom)
            nvgLineTo(vg, sx, sy)
            nvgLineTo(vg, tailX - math.cos(ss.angle + math.pi/2) * 4 * zoom,
                           tailY - math.sin(ss.angle + math.pi/2) * 4 * zoom)
            nvgClosePath(vg)
            nvgFillPaint(vg, flameGrad); nvgFill(vg)
        end
    end

    -- 飞船本体（展开进度影响尺寸）
    local bodyScale = (ss.state == "deploying") and (1 + pct * 0.4) or 1
    local r = 10 * zoom * bodyScale
    local ang = ss.angle

    -- 外发光
    local glowR = r * 1.8 * pulse
    local shipGlow = nvgRadialGradient(vg, sx, sy, r * 0.5, glowR,
        nvgRGBA(80, 180, 255, 80), nvgRGBA(80, 180, 255, 0))
    nvgBeginPath(vg); nvgCircle(vg, sx, sy, glowR)
    nvgFillPaint(vg, shipGlow); nvgFill(vg)

    -- 飞船/基地纹理渲染
    nvgSave(vg)
    nvgTranslate(vg, sx, sy)
    nvgRotate(vg, ang)
    local half = r * 1.4
    local shipAlpha = (ss.state == "deploying") and (200 + pct * 55) or 255
    nvgGlobalAlpha(vg, shipAlpha / 255)
    if ss.state == "deployed" and imgBaseStation and imgBaseStation >= 0 then
        -- 展开后显示基地站图片（不旋转）
        nvgRotate(vg, -ang)
        local bHalf = (60 + pulse * 4) * zoom * 0.7
        local paint = nvgImagePattern(vg, -bHalf, -bHalf, bHalf*2, bHalf*2, 0, imgBaseStation, 1.0)
        nvgBeginPath(vg); nvgRect(vg, -bHalf, -bHalf, bHalf*2, bHalf*2)
        nvgFillPaint(vg, paint); nvgFill(vg)
    elseif imgSeedShip and imgSeedShip >= 0 then
        -- 移动/展开中：种子飞船图片
        local paint = nvgImagePattern(vg, -half, -half, half*2, half*2, 0, imgSeedShip, 1.0)
        nvgBeginPath(vg); nvgRect(vg, -half, -half, half*2, half*2)
        nvgFillPaint(vg, paint); nvgFill(vg)
    else
        -- 回退：六角形体
        nvgBeginPath(vg)
        for i = 0, 5 do
            local theta = i * math.pi / 3
            if i == 0 then nvgMoveTo(vg, math.cos(theta)*r, math.sin(theta)*r)
            else nvgLineTo(vg, math.cos(theta)*r, math.sin(theta)*r) end
        end
        nvgClosePath(vg)
        if ss.state == "deployed" then
            local lv2 = ss.coreLevel or 1
            if     lv2 <= 2 then nvgFillColor(vg, nvgRGBA(0,200,120,240))
            elseif lv2 <= 5 then nvgFillColor(vg, nvgRGBA(60,150,255,240))
            elseif lv2 <= 8 then nvgFillColor(vg, nvgRGBA(180,80,255,240))
            else                 nvgFillColor(vg, nvgRGBA(255,200,60,240))
            end
        else nvgFillColor(vg, nvgRGBA(80,160,255, math.floor(shipAlpha))) end
        nvgFill(vg)
    end
    nvgGlobalAlpha(vg, 1.0)
    nvgRestore(vg)

    -- 中心点（仅飞船移动时显示）
    if ss.state ~= "deployed" then
        nvgBeginPath(vg); nvgCircle(vg, sx, sy, 2.5 * zoom)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
    end

    -- 标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.max(9, 11 * zoom))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if ss.state == "deployed" then
        local lv3 = ss.coreLevel or 1
        local lr, lg, lb
        if     lv3 <= 2 then lr, lg, lb = 0,   220, 130
        elseif lv3 <= 5 then lr, lg, lb = 80,  180, 255
        elseif lv3 <= 8 then lr, lg, lb = 200, 120, 255
        else                 lr, lg, lb = 255, 210, 80
        end
        nvgFillColor(vg, nvgRGBA(lr, lg, lb, 220))
        nvgText(vg, sx, sy + r + 4,
            string.format("[ 星航基地 Lv.%d ]", lv3))
    elseif ss.state == "deploying" then
        nvgFillColor(vg, nvgRGBA(100, 220, 255, 200))
        nvgText(vg, sx, sy + r * bodyScale + 4,
            string.format("展开中 %d%%", math.floor(pct * 100)))
    else
        nvgFillColor(vg, nvgRGBA(140, 190, 255, 180))
        nvgText(vg, sx, sy + r + 4, "种子飞船")
    end
end

-- ============================================================================
-- drawAsteroidSummary — 小行星资源总量面板（小地图上方）
-- ============================================================================
function M.drawAsteroidSummary()
    local vg = GS.vg
    local screenW = GS.screenW
    local screenH = GS.screenH
    local ASTEROID_TYPES      = GS.ASTEROID_TYPES
    local ASTEROID_SIZES      = GS.ASTEROID_SIZES
    local ASTEROID_TYPE_ORDER = GS.ASTEROID_TYPE_ORDER
    local ASTEROID_SIZE_ORDER = GS.ASTEROID_SIZE_ORDER
    local MINIMAP_W   = GS.MINIMAP_W
    local MINIMAP_H   = GS.MINIMAP_H
    local MINIMAP_PAD = GS.MINIMAP_PAD

    -- 统计：各资源类型 × 各尺寸 的数量和储量
    local sizeCnt = {}
    local sizeTot = {}
    for _, atype in ipairs(ASTEROID_TYPE_ORDER) do
        sizeCnt[atype] = { small=0, medium=0, large=0 }
        sizeTot[atype] = { small=0, medium=0, large=0 }
    end
    for _, a in ipairs(GS.asteroids) do
        if a.health and a.health > 0 and a.sizeKey then
            sizeCnt[a.atype][a.sizeKey] = sizeCnt[a.atype][a.sizeKey] + 1
            sizeTot[a.atype][a.sizeKey] = sizeTot[a.atype][a.sizeKey]
                + a.yield * ((a.health or a.hp or 0) / (a.maxHealth or a.maxHP or 1))
        end
    end

    -- 面板尺寸
    local panW  = MINIMAP_W
    local rowH  = 38
    local panH  = 14 + 3 * rowH
    local px    = screenW - panW - MINIMAP_PAD
    local py    = screenH - MINIMAP_H - MINIMAP_PAD - panH - 6

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, panW, panH, 4)
    nvgFillColor(vg, nvgRGBA(0, 6, 18, 210))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(68, 100, 200, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(100, 160, 255, 160))
    nvgText(vg, px + 4, py + 3, "小行星资源")

    -- 每种资源类型行
    local typeRows = {
        { atype="minerals", label="矿石",  color=ASTEROID_TYPES.minerals.color },
        { atype="energy",   label="能量块", color=ASTEROID_TYPES.energy.color   },
        { atype="crystal",  label="水晶",  color=ASTEROID_TYPES.crystal.color  },
    }
    local sizeColors = {
        small  = { 160, 160, 160 },
        medium = { 220, 220, 100 },
        large  = { 100, 255, 160 },
    }

    for j, row in ipairs(typeRows) do
        local c  = row.color
        local ry = py + 14 + (j - 1) * rowH

        -- 资源类型标签
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(vg, px + 5, ry + 1, row.label)

        -- 三档尺寸小格
        local cellW = (panW - 8) / 3
        for k, sizeKey in ipairs(ASTEROID_SIZE_ORDER) do
            local szCfg = ASTEROID_SIZES[sizeKey]
            local sc    = sizeColors[sizeKey]
            local cx    = px + 4 + (k - 1) * cellW
            local cy    = ry + 12

            -- 格子背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx, cy, cellW - 2, rowH - 14, 2)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 20))
            nvgFill(vg)

            -- 尺寸名
            nvgFontSize(vg, 8)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 180))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgText(vg, cx + cellW/2 - 1, cy + 1, szCfg.label)

            -- 颗数
            local cnt = sizeCnt[row.atype][sizeKey]
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 220))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgText(vg, cx + cellW/2 - 1, cy + 10, cnt .. "颗")
        end
    end
end

return M
