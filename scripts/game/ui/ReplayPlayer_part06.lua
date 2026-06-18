-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
