---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- RenderHUD: HUD层渲染 — 波次/连击/信息面板/阵型/技能 (从 BattleRender.lua 拆分)
-- ============================================================================
local BS = require("game.battle.BattleState")
local FormationEditor = require("game.ui.FormationEditor")
local Systems = require("game.Systems")

local FORMATION_ORDER = {"wedge", "circle", "scatter", "charge", "custom"}

local RenderHUD = {}

-- P0-3: Boss 阶段转换横幅（由 BattleState 的 bossPhaseBannerTimer 触发）
local function drawBossPhaseBanner()
    if not BS.bossPhaseBannerTimer or BS.bossPhaseBannerTimer <= 0 then return end
    local totalDuration = BS.bossPhaseBannerTotal or 2.5
    local t = BS.bossPhaseBannerTimer / totalDuration
    -- 淡入淡出
    local alpha = 1.0
    if t > 0.8 then
        alpha = (1.0 - t) / 0.2
    elseif t < 0.2 then
        alpha = t / 0.2
    end
    alpha = math.max(0, math.min(1, alpha))

    local bx, by = BS.screenW / 2, BS.screenH * 0.18
    local text = BS.bossPhaseBannerText or "阶段转换"

    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 28)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 文字阴影
    nvgFillColor(BS.vg, nvgRGBA(0, 0, 0, math.floor(200 * alpha)))
    nvgText(BS.vg, bx + 2, by + 2, text)

    -- 主文字（橙金色）
    nvgFillColor(BS.vg, nvgRGBA(255, 180, 50, math.floor(255 * alpha)))
    nvgText(BS.vg, bx, by, text)

    -- 上下装饰线
    local textW = nvgTextBounds(BS.vg, 0, 0, text) or 200
    local lineW = math.max(textW * 1.5, 200)
    nvgStrokeWidth(BS.vg, 2)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 140, 30, math.floor(200 * alpha)))
    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, bx - lineW / 2, by - 20)
    nvgLineTo(BS.vg, bx + lineW / 2, by - 20)
    nvgMoveTo(BS.vg, bx - lineW / 2, by + 20)
    nvgLineTo(BS.vg, bx + lineW / 2, by + 20)
    nvgStroke(BS.vg)
end

local function drawWaveHUD()
    -- P1-6: Boss 预警阶段也绘制，否则只在战斗中绘制
    if BS.state ~= "fighting" and BS.state ~= "bossWarning" then return end
    local cx = BS.screenW / 2

    -- P1-6: Boss 预警横幅（在预警阶段绘制在顶部）
    if BS.bossWarningActive and BS.bossWarningTimer and BS.bossWarningTimer > 0 then
        local remain = math.max(0, math.ceil(BS.bossWarningTimer))
        local totalDur = BS.bossWarningDuration or 10
        local bossType = BS.bossWarningType or "BATTLECRUISER"
        local bossName = "未知类型"
        local bossDesc = ""
        if bossType == "BATTLECRUISER" then
            bossName = "战列巡洋舰"
            bossDesc = "重甲 Boss · 高爆发伤害"
        elseif bossType == "CARRIER" then
            bossName = "母舰"
            bossDesc = "无人机群 + 自爆舰载机"
        elseif bossType == "VOID_LORD" then
            bossName = "虚空领主"
            bossDesc = "隐形突袭 + 幻影分身 + 虚空吞噬"
        end

        -- 闪烁边框效果（随倒计时变化，越接近0越急促）
        local pulsePhase = os.clock() * (2.5 + (totalDur - BS.bossWarningTimer) * 0.15)
        local pulse = 0.5 + 0.5 * math.sin(pulsePhase)

        -- 外层预警大横幅（深红背景 + 橙边闪烁）
        local bannerW = 460
        local bannerH = 86
        local bannerX = cx - bannerW / 2
        local bannerY = 6
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bannerX, bannerY, bannerW, bannerH, 10)
        nvgFillColor(BS.vg, nvgRGBA(90, 10, 10, math.floor(180 + 40 * pulse)))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bannerX, bannerY, bannerW, bannerH, 10)
        nvgStrokeColor(BS.vg, nvgRGBA(255, 140, 40, math.floor(180 + 75 * pulse)))
        nvgStrokeWidth(BS.vg, 2.5)
        nvgStroke(BS.vg)

        -- 顶部标题行
        nvgFontFace(BS.vg, "sans")
        nvgFontSize(BS.vg, 18)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(255, 220, 60, 255))
        nvgText(BS.vg, cx, bannerY + 18,
            "⚠ 第 " .. (BS.bossWarningWave or BS.waveNum) .. " 波：Boss 即将出现！")

        -- Boss 类型名称（大号）
        nvgFontSize(BS.vg, 16)
        nvgFillColor(BS.vg, nvgRGBA(255, 180, 120, 250))
        nvgText(BS.vg, cx, bannerY + 40, "◆ " .. bossName .. " ◆")

        -- Boss 描述
        nvgFontSize(BS.vg, 11)
        nvgFillColor(BS.vg, nvgRGBA(230, 200, 160, 230))
        nvgText(BS.vg, cx, bannerY + 58, bossDesc)

        -- 倒计时 + 建议
        nvgFontSize(BS.vg, 10)
        nvgFillColor(BS.vg, nvgRGBA(180, 160, 140, 220))
        nvgText(BS.vg, cx, bannerY + 74,
            string.format("倒计时 %ds · 建议：检查舰队配置，确保有护卫舰/防御塔 [SPACE跳过]",
                remain))

        -- 预警状态下不再绘制普通波次 HUD
        return
    end

    local hw, hh = 140, 48
    -- 背景胶囊
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - hw, 4, hw * 2, hh, 8)
    nvgFillColor(BS.vg, nvgRGBA(8, 12, 30, 210))
    nvgFill(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - hw, 4, hw * 2, hh, 8)
    nvgStrokeColor(BS.vg, nvgRGBA(60, 120, 255, 140))
    nvgStrokeWidth(BS.vg, 1)
    nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")

    -- 第一行：波次文字 + 兵力
    local row1Y = 4 + 13
    nvgFontSize(BS.vg, 11)
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local isBossNow = (BS.waveNum % BS.BOSS_WAVE_INTERVAL == 0)
    if isBossNow then
        nvgFillColor(BS.vg, nvgRGBA(255, 120, 40, 240))
    else
        nvgFillColor(BS.vg, nvgRGBA(100, 180, 255, 220))
    end
    nvgText(BS.vg, cx - hw + 10, row1Y,
        isBossNow and string.format("第 %d 波 ⚡ BOSS", BS.waveNum)
                   or string.format("第 %d 波", BS.waveNum))

    nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(80, 220, 120, 200))
    nvgText(BS.vg, cx + hw - 10, row1Y,
        string.format("我方 %d  敌方 %d", #BS.playerFleet, #BS.enemyFleet))

    -- 第二行：波次时间线进度条
    local barY   = 4 + 26
    local barH   = 7
    local barX0  = cx - hw + 10
    local barX1  = cx + hw - 10
    local barW   = barX1 - barX0

    local stageSize  = BS.BOSS_WAVE_INTERVAL
    local stageStart = math.floor((BS.waveNum - 1) / stageSize) * stageSize + 1
    local stageEnd   = stageStart + stageSize - 1

    -- 轨道背景
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, barX0, barY, barW, barH, 3)
    nvgFillColor(BS.vg, nvgRGBA(20, 35, 70, 200))
    nvgFill(BS.vg)

    -- 已完成段（包含当前波）
    local pct = (BS.waveNum - stageStart) / stageSize
    if pct > 0 then
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, barX0, barY, barW * pct, barH, 3)
        if isBossNow then
            nvgFillColor(BS.vg, nvgRGBA(255, 100, 20, 200))
        else
            nvgFillColor(BS.vg, nvgRGBA(60, 140, 255, 200))
        end
        nvgFill(BS.vg)
    end

    -- 节点圆点：stageSize 个节点（每波一个）
    local nodeR = 4.5
    for i = 1, stageSize do
        local wave_i  = stageStart + i - 1
        local nx      = barX0 + barW * (i - 0.5) / stageSize
        local ny      = barY + barH / 2
        local isBoss  = (wave_i % BS.BOSS_WAVE_INTERVAL == 0)
        local isPast  = (wave_i < BS.waveNum)
        local isCur   = (wave_i == BS.waveNum)

        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, nx, ny, isBoss and nodeR + 1 or nodeR)
        if isBoss then
            if isCur then
                nvgFillColor(BS.vg, nvgRGBA(255, 80, 20, 255))
            elseif isPast then
                nvgFillColor(BS.vg, nvgRGBA(180, 60, 20, 220))
            else
                nvgFillColor(BS.vg, nvgRGBA(80, 30, 10, 200))
            end
        else
            if isCur then
                nvgFillColor(BS.vg, nvgRGBA(80, 200, 255, 255))
            elseif isPast then
                nvgFillColor(BS.vg, nvgRGBA(40, 100, 180, 220))
            else
                nvgFillColor(BS.vg, nvgRGBA(25, 45, 90, 200))
            end
        end
        nvgFill(BS.vg)

        if isCur then
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, nx, ny, (isBoss and nodeR + 3 or nodeR + 2))
            nvgStrokeWidth(BS.vg, 1.5)
            if isBoss then
                nvgStrokeColor(BS.vg, nvgRGBA(255, 120, 40, 180))
            else
                nvgStrokeColor(BS.vg, nvgRGBA(100, 200, 255, 180))
            end
            nvgStroke(BS.vg)
        end

        if isBoss then
            nvgFontSize(BS.vg, 7)
            nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(BS.vg, nvgRGBA(255, 220, 100, 255))
            nvgText(BS.vg, nx, ny, "B")
        end
    end

    -- 阶段标签（左 W1 右 W5）
    nvgFontSize(BS.vg, 8)
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(80, 120, 200, 160))
    nvgText(BS.vg, barX0, barY + barH + 6, string.format("W%d", stageStart))
    nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(200, 100, 60, 160))
    nvgText(BS.vg, barX1, barY + barH + 6, string.format("BOSS W%d", stageEnd))
end

--- 连击计数 HUD（右上角）
local function drawComboHUD()
    if BS.state ~= "fighting" then return end
    if BS.comboCount < 2 then return end
    local alpha = 255
    if BS.comboDisplayTimer < 0.5 then
        alpha = math.floor(BS.comboDisplayTimer / 0.5 * 255)
    end
    if alpha <= 0 then return end

    local lv    = BS.getComboLevel()
    local color = lv and { 255, 220, 40 } or { 180, 220, 255 }
    local label = lv and lv.label or "COMBO"

    local bx = BS.screenW - 120
    local by = 6
    local bw = 112
    local bh = 40

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, bx, by, bw, bh, 6)
    nvgFillColor(BS.vg, nvgRGBA(10, 15, 35, math.floor(alpha * 0.8)))
    nvgFill(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, bx, by, bw, bh, 6)
    nvgStrokeColor(BS.vg, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.7)))
    nvgStrokeWidth(BS.vg, 1.2)
    nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 大连击数字
    nvgFontSize(BS.vg, 20)
    nvgFillColor(BS.vg, nvgRGBA(color[1], color[2], color[3], alpha))
    nvgText(BS.vg, bx + bw * 0.38, by + bh * 0.5, string.format("x%d", BS.comboCount))
    -- 标签文字
    nvgFontSize(BS.vg, 8)
    nvgFillColor(BS.vg, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.85)))
    nvgText(BS.vg, bx + bw * 0.75, by + bh * 0.38, label)
    -- 倍率提示
    if lv and BS.comboCount >= 3 then
        nvgFontSize(BS.vg, 9)
        nvgFillColor(BS.vg, nvgRGBA(120, 255, 160, math.floor(alpha * 0.9)))
        nvgText(BS.vg, bx + bw * 0.75, by + bh * 0.68,
            string.format("+%d星币", BS.comboCount * 20))
    end
    -- 衰减条（剩余连击时间）
    if BS.comboCount > 0 then
        local pct2 = 1.0 - math.min(1, BS.comboTimer / BS.COMBO_RESET_TIME)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, bx + 4, by + bh - 4, (bw - 8) * pct2, 2)
        nvgFillColor(BS.vg, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.7)))
        nvgFill(BS.vg)
    end
end

--- P2-2: 绘制单舰信息面板（选中舰船时显示在其旁边）
local function drawShipInfoPanel()
    local ship = BS.selectedShip
    if not ship then return end
    -- 检查舰船仍在舰队中（可能已阵亡）
    local alive = false
    for _, s in ipairs(BS.playerFleet) do if s == ship then alive = true; break end end
    if not alive then
        for _, s in ipairs(BS.enemyFleet) do if s == ship then alive = true; break end end
    end
    if not alive then BS.selectedShip = nil; return end

    local isPlayer = (ship.team == "player")
    local cfg = BS.SHIP_TYPES[ship.stype] or {}
    local typeName = cfg.name or ship.stype
    local panW, panH = 148, 120
    local px = ship.x + 18
    local py = ship.y - panH / 2
    if px + panW > BS.screenW - 8 then px = ship.x - panW - 18 end
    if py < 92 then py = 92 end
    if py + panH > BS.screenH - 6 then py = BS.screenH - panH - 6 end

    local bgR = isPlayer and 5  or 30
    local bgG = isPlayer and 20 or 5
    local bgB = isPlayer and 50 or 5
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, px, py, panW, panH, 6)
    nvgFillColor(BS.vg, nvgRGBA(bgR, bgG, bgB, 215))
    nvgFill(BS.vg)
    local borderR = isPlayer and 60  or 200
    local borderG = isPlayer and 160 or 60
    local borderB = isPlayer and 255 or 60
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, px + 0.5, py + 0.5, panW - 1, panH - 1, 6)
    nvgStrokeColor(BS.vg, nvgRGBA(borderR, borderG, borderB, 160))
    nvgStrokeWidth(BS.vg, 1); nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(BS.vg, 12)
    nvgFillColor(BS.vg, nvgRGBA(borderR, borderG, borderB, 230))
    local teamLabel = isPlayer and "我方" or "敌方"
    nvgText(BS.vg, px + 8, py + 11, teamLabel .. " · " .. typeName)
    if ship.isBoss then
        nvgFillColor(BS.vg, nvgRGBA(255, 80, 80, 220))
        nvgText(BS.vg, px + panW - 30, py + 11, "BOSS")
    end
    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, px + 6, py + 19); nvgLineTo(BS.vg, px + panW - 6, py + 19)
    nvgStrokeColor(BS.vg, nvgRGBA(borderR, borderG, borderB, 60))
    nvgStrokeWidth(BS.vg, 0.5); nvgStroke(BS.vg)

    -- HP 条
    local barX, barY = px + 8, py + 27
    local barW2, barH2 = panW - 16, 8
    local hpRatio = math.max(0, ship.health / ship.maxHealth)
    nvgBeginPath(BS.vg); nvgRoundedRect(BS.vg, barX, barY, barW2, barH2, 3)
    nvgFillColor(BS.vg, nvgRGBA(40, 40, 40, 160)); nvgFill(BS.vg)
    local hpR = math.floor(math.min(255, (1 - hpRatio) * 510))
    local hpG = math.floor(math.min(255, hpRatio * 510))
    nvgBeginPath(BS.vg); nvgRoundedRect(BS.vg, barX, barY, barW2 * hpRatio, barH2, 3)
    nvgFillColor(BS.vg, nvgRGBA(hpR, hpG, 30, 200)); nvgFill(BS.vg)
    nvgFontSize(BS.vg, 9)
    nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(220, 220, 220, 200))
    nvgText(BS.vg, px + panW - 8, barY + barH2/2,
        string.format("HP %d/%d", math.floor(ship.health), ship.maxHealth))

    -- 护盾条（若有）
    local rowY = barY + barH2 + 5
    if ship.maxShield and ship.maxShield > 0 then
        local shRatio = math.max(0, (ship.shield or 0) / ship.maxShield)
        nvgBeginPath(BS.vg); nvgRoundedRect(BS.vg, barX, rowY, barW2, barH2, 3)
        nvgFillColor(BS.vg, nvgRGBA(40, 40, 40, 160)); nvgFill(BS.vg)
        nvgBeginPath(BS.vg); nvgRoundedRect(BS.vg, barX, rowY, barW2 * shRatio, barH2, 3)
        nvgFillColor(BS.vg, nvgRGBA(80, 160, 255, 200)); nvgFill(BS.vg)
        nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFontSize(BS.vg, 9)
        nvgFillColor(BS.vg, nvgRGBA(160, 200, 255, 200))
        nvgText(BS.vg, px + panW - 8, rowY + barH2/2,
            string.format("护盾 %d/%d", math.floor(ship.shield or 0), ship.maxShield))
        rowY = rowY + barH2 + 5
    end

    -- 数值行（攻击 / 速度 / 射程）
    local statY = rowY + 4
    local function statLine(label, val, unit)
        nvgFontSize(BS.vg, 10)
        nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(160, 160, 160, 180))
        nvgText(BS.vg, px + 8, statY, label)
        nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(230, 230, 230, 220))
        nvgText(BS.vg, px + panW - 8, statY, string.format("%.0f %s", val, unit))
        statY = statY + 14
    end
    statLine("攻击", ship.dmg,   "dmg")
    statLine("速度", ship.speed, "px/s")
    statLine("射程", ship.range, "px")

    -- 选中高亮
    local hlR = (ship.isBoss and 12 or 10)
    nvgBeginPath(BS.vg)
    nvgCircle(BS.vg, ship.x, ship.y, hlR)
    nvgStrokeColor(BS.vg, nvgRGBA(borderR, borderG, borderB, 180))
    nvgStrokeWidth(BS.vg, 1.5); nvgStroke(BS.vg)
    -- 连接线
    local lineEndX = (ship.x + 18 >= BS.screenW - 8 - panW) and (px + panW) or px
    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, ship.x, ship.y)
    nvgLineTo(BS.vg, lineEndX, py + panH/2)
    nvgStrokeColor(BS.vg, nvgRGBA(borderR, borderG, borderB, 60))
    nvgStrokeWidth(BS.vg, 0.8); nvgStroke(BS.vg)
end

--- P2-2: 绘制集火目标橙色脉冲光环
local function drawFocusRing()
    if not BS.focusTarget or BS.focusTarget.health <= 0 then return end
    local t     = (os.clock() % 1.2) / 1.2
    local pulse = 0.75 + 0.5 * math.abs(math.sin(t * math.pi))
    local r     = 22 * pulse

    nvgBeginPath(BS.vg)
    nvgCircle(BS.vg, BS.focusTarget.x, BS.focusTarget.y, r)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 140, 0, 200))
    nvgStrokeWidth(BS.vg, 2.5)
    nvgStroke(BS.vg)

    nvgBeginPath(BS.vg)
    nvgCircle(BS.vg, BS.focusTarget.x, BS.focusTarget.y, 14)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 60, 130))
    nvgStrokeWidth(BS.vg, 1.2)
    nvgStroke(BS.vg)

    -- 十字准线（四段短横线）
    local cross = 9
    nvgStrokeColor(BS.vg, nvgRGBA(255, 160, 40, 180))
    nvgStrokeWidth(BS.vg, 1.5)
    for _, dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        nvgBeginPath(BS.vg)
        nvgMoveTo(BS.vg, BS.focusTarget.x + dir[1] * (r + 3), BS.focusTarget.y + dir[2] * (r + 3))
        nvgLineTo(BS.vg, BS.focusTarget.x + dir[1] * (r + 3 + cross), BS.focusTarget.y + dir[2] * (r + 3 + cross))
        nvgStroke(BS.vg)
    end

    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 9)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(255, 180, 60, 210))
    nvgText(BS.vg, BS.focusTarget.x, BS.focusTarget.y - r - 7, "◎ 集火")
end

--- P2-2: 绘制顶部集火状态条（含取消按钮）
local function drawFocusHUD()
    BS.focusHudBtn = nil
    if not BS.focusTarget or BS.focusTarget.health <= 0 then return end

    local cfg       = BS.SHIP_TYPES[BS.focusTarget.stype] or {}
    local typeName  = cfg.name or BS.focusTarget.stype
    local hpPct     = math.max(0, BS.focusTarget.health / (BS.focusTarget.maxHealth or BS.focusTarget.health))

    local barW, barH = 220, 26
    local bx = BS.screenW / 2 - barW / 2
    local by = 58

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, bx, by, barW, barH, 5)
    nvgFillColor(BS.vg, nvgRGBA(40, 18, 5, 210))
    nvgFill(BS.vg)

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, bx + 0.5, by + 0.5, barW - 1, barH - 1, 5)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 140, 0, 200))
    nvgStrokeWidth(BS.vg, 1.2); nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(BS.vg, 10)
    nvgFillColor(BS.vg, nvgRGBA(255, 160, 50, 230))
    nvgText(BS.vg, bx + 7, by + barH / 2, "◎ 集火: 敌方" .. typeName)

    -- HP 进度条（小型）
    local hpBarX = bx + 105
    local hpBarW = 68
    local hpBarH = 4
    local hpBarY = by + barH / 2 - hpBarH / 2
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, hpBarX, hpBarY, hpBarW, hpBarH)
    nvgFillColor(BS.vg, nvgRGBA(60, 20, 10, 180))
    nvgFill(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, hpBarX, hpBarY, hpBarW * hpPct, hpBarH)
    local hpR = math.floor(200 * (1 - hpPct) + 60  * hpPct)
    local hpG = math.floor(60  * (1 - hpPct) + 180 * hpPct)
    nvgFillColor(BS.vg, nvgRGBA(hpR, hpG, 40, 220))
    nvgFill(BS.vg)

    nvgFontSize(BS.vg, 8)
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(200, 200, 200, 180))
    nvgText(BS.vg, hpBarX + hpBarW + 3, by + barH / 2,
        string.format("%d/%d", math.max(0, math.floor(BS.focusTarget.health)),
                                math.floor(BS.focusTarget.maxHealth or BS.focusTarget.health)))

    -- [✕] 取消按钮
    local btnW, btnH = 22, 16
    local btnX = bx + barW - btnW - 4
    local btnY = by + barH / 2 - btnH / 2
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, btnX, btnY, btnW, btnH, 3)
    nvgFillColor(BS.vg, nvgRGBA(180, 50, 30, 200))
    nvgFill(BS.vg)
    nvgFontSize(BS.vg, 9)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(255, 220, 200, 230))
    nvgText(BS.vg, btnX + btnW / 2, btnY + btnH / 2, "✕")
    BS.focusHudBtn = { x = btnX, y = btnY, w = btnW, h = btnH }
end

--- P2-3: 绘制阵型选择栏（技能栏左侧，竖排 4 个小按钮）
local function drawFormationBar()
    if BS.state ~= "fighting" and BS.state ~= "win" then
        BS.formationBtn = {}
        return
    end

    local skillBtnW  = 74
    local skillGapX  = 6
    local skillCols  = 3
    local skillTotalW = skillBtnW * skillCols + skillGapX * (skillCols - 1)
    local skillStartX = BS.screenW / 2 - skillTotalW / 2

    local btnW, btnH = 60, 20
    local gap        = 2
    local numBtns    = #FORMATION_ORDER
    local totalH     = btnH * numBtns + gap * (numBtns - 1)
    local bx         = skillStartX - btnW - 10
    local row2Y      = BS.screenH - 74 - 6 - 5
    local topY       = row2Y + (74 - totalH) / 2

    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 9)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if BS.formationLocked then
        nvgFillColor(BS.vg, nvgRGBA(180, 80, 80, 160))
        nvgText(BS.vg, bx + btnW/2, topY - 8, "阵型🔒")
    else
        nvgFillColor(BS.vg, nvgRGBA(100, 220, 140, 180))
        nvgText(BS.vg, bx + btnW/2, topY - 8, "阵型(备战)")
    end

    BS.formationBtn = {}
    for i, key in ipairs(FORMATION_ORDER) do
        local fc   = BS.FORMATION_CONFIG[key]
        local by   = topY + (i - 1) * (btnH + gap)
        local active = (BS.currentFormation == key)
        local noCustomData = (key == "custom" and not FormationEditor.HasSaved())
        local locked = (BS.formationLocked and not active) or noCustomData

        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx, by, btnW, btnH, 5)
        if active then
            nvgFillColor(BS.vg, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 210))
        elseif locked then
            nvgFillColor(BS.vg, nvgRGBA(30, 30, 40, 140))
        else
            nvgFillColor(BS.vg, nvgRGBA(18, 24, 45, 170))
        end
        nvgFill(BS.vg)

        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx + 0.5, by + 0.5, btnW - 1, btnH - 1, 5)
        if active then
            nvgStrokeColor(BS.vg, nvgRGBA(255, 255, 255, 200))
        elseif locked then
            nvgStrokeColor(BS.vg, nvgRGBA(60, 60, 70, 100))
        else
            nvgStrokeColor(BS.vg, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 120))
        end
        nvgStrokeWidth(BS.vg, 1.2)
        nvgStroke(BS.vg)

        nvgFontSize(BS.vg, 10)
        if active then
            nvgFillColor(BS.vg, nvgRGBA(255, 255, 255, 255))
        elseif locked then
            nvgFillColor(BS.vg, nvgRGBA(80, 80, 90, 140))
        else
            nvgFillColor(BS.vg, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 200))
        end
        local btnLabel = fc.icon .. " " .. fc.label
        if noCustomData then btnLabel = "🔒 " .. fc.label end
        nvgText(BS.vg, bx + btnW/2, by + btnH/2, btnLabel)

        BS.formationBtn[i] = { x=bx, y=by, w=btnW, h=btnH, key=key, locked=locked }
    end
end

--- P1-2: 撤退 / 紧急增援按钮（右下角）
local function drawRetreatReinforce()
    if BS.state ~= "fighting" then
        BS.retreatBtn   = nil
        BS.reinforceBtn = nil
        return
    end

    local btnW, btnH = 72, 24
    local marginR = 10
    local marginB = 10

    local canReinforce = (#BS.enemyFleet == 0 and BS.waveGapTimer < BS.WAVE_GAP
                         and BS.reinforceCooldown <= 0)
    local metal   = BS.rm and (BS.rm.resources.metal   or 0) or 0
    local crystal = BS.rm and (BS.rm.resources.crystal or 0) or 0
    local hasResMeta = (metal >= BS.REINFORCE_COST_METAL and crystal >= BS.REINFORCE_COST_CRYSTAL)

    local retreatX = BS.screenW - btnW - marginR
    local retreatY = BS.screenH - btnH - marginB
    local reinforceY = retreatY - btnH - 6

    -- ── 撤退按钮 ──
    if not BS.retreatUsed then
        local energy = BS.rm and (BS.rm.resources.energy or 0) or 0
        local canRetreat = (energy >= BS.RETREAT_COST_ENERGY)
        local bgR, bgG, bgB = canRetreat and 160 or 60, 30, canRetreat and 30 or 30
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, retreatX, retreatY, btnW, btnH, 5)
        nvgFillColor(BS.vg, nvgRGBA(bgR, bgG, bgB, 200))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, retreatX, retreatY, btnW, btnH, 5)
        nvgStrokeColor(BS.vg, canRetreat and nvgRGBA(255, 80, 60, 200) or nvgRGBA(100, 60, 60, 160))
        nvgStrokeWidth(BS.vg, 1)
        nvgStroke(BS.vg)
        nvgFontFace(BS.vg, "sans")
        nvgFontSize(BS.vg, 10)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, canRetreat and nvgRGBA(255, 180, 160, 240) or nvgRGBA(150, 100, 100, 180))
        nvgText(BS.vg, retreatX + btnW/2, retreatY + btnH/2 - 5, "⚑ 战略撤退")
        nvgFontSize(BS.vg, 8)
        nvgFillColor(BS.vg, nvgRGBA(200, 160, 140, 180))
        nvgText(BS.vg, retreatX + btnW/2, retreatY + btnH/2 + 6,
            string.format("能源 -%d", BS.RETREAT_COST_ENERGY))
        BS.retreatBtn = { x=retreatX, y=retreatY, w=btnW, h=btnH }
    else
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, retreatX, retreatY, btnW, btnH, 5)
        nvgFillColor(BS.vg, nvgRGBA(40, 40, 40, 150))
        nvgFill(BS.vg)
        nvgFontFace(BS.vg, "sans")
        nvgFontSize(BS.vg, 9)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(120, 100, 100, 160))
        nvgText(BS.vg, retreatX + btnW/2, retreatY + btnH/2, "撤退（已用）")
        BS.retreatBtn = nil
    end

    -- ── 紧急增援按钮 ──
    if canReinforce then
        local bgG2 = hasResMeta and 120 or 40
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, retreatX, reinforceY, btnW, btnH, 5)
        nvgFillColor(BS.vg, nvgRGBA(20, bgG2, 40, 200))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, retreatX, reinforceY, btnW, btnH, 5)
        nvgStrokeColor(BS.vg, hasResMeta and nvgRGBA(60, 220, 100, 200) or nvgRGBA(60, 100, 60, 160))
        nvgStrokeWidth(BS.vg, 1)
        nvgStroke(BS.vg)
        nvgFontFace(BS.vg, "sans")
        nvgFontSize(BS.vg, 10)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, hasResMeta and nvgRGBA(120, 255, 160, 240) or nvgRGBA(100, 160, 100, 180))
        nvgText(BS.vg, retreatX + btnW/2, reinforceY + btnH/2 - 5, "⊕ 紧急增援")
        nvgFontSize(BS.vg, 8)
        nvgFillColor(BS.vg, nvgRGBA(160, 200, 160, 180))
        nvgText(BS.vg, retreatX + btnW/2, reinforceY + btnH/2 + 6,
            string.format("金属%d 晶体%d", BS.REINFORCE_COST_METAL, BS.REINFORCE_COST_CRYSTAL))
        BS.reinforceBtn = { x=retreatX, y=reinforceY, w=btnW, h=btnH, canDo=hasResMeta }
    else
        BS.reinforceBtn = nil
    end
end

-- ============================================================================
-- P2-2: 技能升级选择弹窗（波次间隙覆盖层）
-- ============================================================================
local function drawSkillUpgrade()
    if not BS.skillUpgradeCards or #BS.skillUpgradeCards == 0 then return end
    if BS.state ~= "win" then return end

    local vg = BS.vg
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, BS.screenW, BS.screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 10, 170))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 240))
    nvgText(vg, BS.screenW / 2, BS.screenH / 2 - 80, "⬆ 技能强化 — 选择一项升级")

    local cardW, cardH = 130, 90
    local cardGap = 20
    local n = #BS.skillUpgradeCards
    local totalW = n * cardW + (n - 1) * cardGap
    local startX = BS.screenW / 2 - totalW / 2
    local cardY  = BS.screenH / 2 - cardH / 2 - 10

    BS.skillUpgradeCardBtns = {}
    for i, skillIdx in ipairs(BS.skillUpgradeCards) do
        local cx = startX + (i - 1) * (cardW + cardGap)
        local lv = BS.BattleSkills.GetLevel(skillIdx)
        local nextLv = lv + 1
        local icon = BS.BattleSkills.GetIcon(skillIdx)
        local name = BS.BattleSkills.GetName(skillIdx)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cardY, cardW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(18, 28, 60, 220))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx + 0.5, cardY + 0.5, cardW - 1, cardH - 1, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 190, 40, 200))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(240, 240, 255, 255))
        nvgText(vg, cx + cardW / 2, cardY + 22, icon)
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(200, 225, 255, 230))
        nvgText(vg, cx + cardW / 2, cardY + 42, name)

        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(120, 180, 120, 200))
        nvgText(vg, cx + cardW / 2, cardY + 58, "Lv" .. lv .. " → Lv" .. nextLv)

        nvgFontSize(vg, 9)
        if nextLv == 2 then
            nvgFillColor(vg, nvgRGBA(160, 220, 160, 190))
            nvgText(vg, cx + cardW / 2, cardY + 72, "效果 +50%")
        else
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, cx + cardW / 2, cardY + 68, "效果 +100%")
            nvgFillColor(vg, nvgRGBA(160, 200, 255, 180))
            nvgText(vg, cx + cardW / 2, cardY + 80, "冷却 -20%")
        end

        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(255, 230, 100, 160))
        nvgText(vg, cx + cardW / 2, cardY + cardH - 6, "点击选择")

        BS.skillUpgradeCardBtns[#BS.skillUpgradeCardBtns + 1] = {
            x = cx, y = cardY, w = cardW, h = cardH, skillIdx = skillIdx
        }
    end
end

--- P3-2: Boss击破全屏闪光 + BOSS DESTROYED 横幅

--- P0-1: 超级 Boss 特殊血条渲染
local function drawSuperBossHealthBar()
    -- 遍历敌舰查找超级 Boss
    local superBoss = nil
    if BS.enemyFleet then
        for _, ship in ipairs(BS.enemyFleet) do
            if ship.isSuperBoss then superBoss = ship; break end
        end
    end
    if not superBoss then return end

    local def = BS.SUPER_BOSSES and BS.SUPER_BOSSES[superBoss.superBossType]
    local bx, by, bw = BS.screenW - 160, 50, 300

    -- 血条背景
    nvgFillColor(BS.vg, nvgRGBA(40, 10, 10, 220))
    nvgBeginPath(BS.vg); nvgRoundedRect(BS.vg, bx, by, bw, 18, 3); nvgFill(BS.vg)

    -- 当前阶段血条
    local phaseHpRatio = superBoss.health > 0 and superBoss.health / superBoss.maxHealth or 0
    nvgFillColor(BS.vg, nvgRGBA(220, 30, 30, 255))
    nvgBeginPath(BS.vg); nvgRoundedRect(BS.vg, bx, by, bw * math.max(0, phaseHpRatio), 18, 3); nvgFill(BS.vg)

    -- 阶段标记线
    if def and def.phases then
        for _, phase in ipairs(def.phases) do
            if phase.hpThreshold < 1.0 then
                local px = bx + bw * phase.hpThreshold
                nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 0, 200))
                nvgStrokeWidth(BS.vg, 2)
                nvgBeginPath(BS.vg)
                nvgMoveTo(BS.vg, px, by)
                nvgLineTo(BS.vg, px, by + 18)
                nvgStroke(BS.vg)
            end
        end
    end

    -- 超级 Boss 名字
    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 14)
    nvgTextAlign(BS.vg, NVG_ALIGN.CENTER)
    nvgFillColor(BS.vg, nvgRGBA(255, 100, 100, 255))
    nvgText(BS.vg, bx + bw/2, by - 10, "⚠ " .. (def and def.name or "??") .. " ⚠")

    -- 阶段名
    if superBoss.currentPhase and superBoss.currentPhase.name then
        nvgFontSize(BS.vg, 11)
        nvgFillColor(BS.vg, nvgRGBA(255, 180, 80, 220))
        nvgText(BS.vg, bx + bw/2, by + 32, superBoss.currentPhase.name)
    end

    -- 轰炸区域指示（如果正在轰炸）
    if BS.bombardZones and #BS.bombardZones > 0 then
        for _, zone in ipairs(BS.bombardZones) do
            local alpha = math.floor((zone.timer / zone.maxTimer) * 200)
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, zone.x, zone.y, zone.radius)
            nvgFillColor(BS.vg, nvgRGBA(255, 60, 60, alpha))
            nvgFill(BS.vg)
        end
    end
end

-- P0-7: 速度切换按钮和自动战斗开关
local function drawSpeedControl()
    if not BS then return end
    local screenW, screenH = BS.screenW or 800, BS.screenH or 600

    local btnSize = 32
    local startX = screenW - 170
    local y = screenH - 50

    -- 获取当前速度显示
    local speedLabel = "▶ 1x"
    local BATTLE_SPEEDS = Systems.BATTLE_SPEEDS
    for _, spd in ipairs(BATTLE_SPEEDS) do
        if spd.id == BS.battleSpeedId then
            speedLabel = spd.icon .. " " .. spd.name
        end
    end

    -- 速度按钮
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, startX, y, 60, btnSize, 6)
    nvgFillColor(BS.vg, nvgRGBA(60, 60, 100, 200)); nvgFill(BS.vg)
    nvgStrokeColor(BS.vg, nvgRGBA(150, 150, 200, 150)); nvgStrokeWidth(BS.vg, 1); nvgStroke(BS.vg)
    nvgFontFace(BS.vg, "sans"); nvgFontSize(BS.vg, 11)
    nvgTextAlign(BS.vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(255, 255, 255, 255))
    nvgText(BS.vg, startX + 30, y + btnSize/2, speedLabel)

    addHit(startX, y, 60, btnSize, function()
        -- 循环切换速度
        local currentIdx = 1
        for i, spd in ipairs(BATTLE_SPEEDS) do
            if spd.id == BS.battleSpeedId then currentIdx = i; break end
        end
        local nextIdx = (currentIdx % #BATTLE_SPEEDS) + 1
        local nextSpeed = BATTLE_SPEEDS[nextIdx]
        BS.battleSpeed = nextSpeed.mult
        BS.battleSpeedId = nextSpeed.id
        if BS.notifyFn then BS.notifyFn("战斗速度: " .. nextSpeed.name, "info") end
    end)

    -- 自动战斗开关
    local autoX = startX + 70
    local autoColor = BS.autoBattleEnabled and nvgRGBA(80, 160, 80, 200) or nvgRGBA(80, 60, 60, 200)
    local autoStrokeColor = BS.autoBattleEnabled and nvgRGBA(100, 255, 100, 200) or nvgRGBA(150, 100, 100, 150)

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, autoX, y, 60, btnSize, 6)
    nvgFillColor(BS.vg, autoColor); nvgFill(BS.vg)
    nvgStrokeColor(BS.vg, autoStrokeColor); nvgStrokeWidth(BS.vg, 1); nvgStroke(BS.vg)
    nvgFontSize(BS.vg, 11)
    nvgTextAlign(BS.vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(255, 255, 255, 255))
    nvgText(BS.vg, autoX + 30, y + btnSize/2, BS.autoBattleEnabled and "ON" or "OFF")

    addHit(autoX, y, 60, btnSize, function()
        BS.autoBattleEnabled = not BS.autoBattleEnabled
        if BS.notifyFn then
            BS.notifyFn(BS.autoBattleEnabled and "自动战斗: 开启" or "自动战斗: 关闭", "info")
        end
    end)

    -- 自动战斗状态指示
    if BS.autoBattleEnabled then
        nvgFontFace(BS.vg, "sans")
        nvgFontSize(BS.vg, 10)
        nvgTextAlign(BS.vg, NVG_ALIGN.CENTER)
        nvgFillColor(BS.vg, nvgRGBA(100, 255, 100, 200))
        nvgText(BS.vg, autoX + 30, y - 12, "AUTO")
    end

    -- 快捷键提示
    nvgFontSize(BS.vg, 8)
    nvgTextAlign(BS.vg, NVG_ALIGN.LEFT)
    nvgFillColor(BS.vg, nvgRGBA(150, 150, 150, 150))
    nvgText(BS.vg, startX, y + btnSize + 10, "1-4:速度 A:自动")
end

-- ============================================================================
-- P1-10: 暂停界面渲染
-- ============================================================================
local function drawPauseScreen()
    if not BS.paused then return end
    
    local screenW, screenH = BS.screenW or 800, BS.screenH or 600
    local vg = BS.vg
    
    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)
    
    -- 暂停文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 36)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, screenW/2, screenH/2 - 50, "⏸ 游戏暂停")
    
    -- 提示
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
    nvgText(vg, screenW/2, screenH/2, "按 P 或 ESC 继续")
    
    -- 继续按钮
    local btnW, btnH = 120, 40
    local btnX, btnY = screenW/2 - btnW/2, screenH/2 + 50
    
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)
    nvgFillColor(vg, nvgRGBA(80, 120, 80, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 100, 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
    
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, btnX + btnW/2, btnY + btnH/2, "▶ 继续")
    
    addHit(btnX, btnY, btnW, btnH, function()
        BS.paused = false
    end)
end

RenderHUD.drawBossPhaseBanner = drawBossPhaseBanner
RenderHUD.drawSuperBossHealthBar = drawSuperBossHealthBar
RenderHUD.drawWaveHUD          = drawWaveHUD
RenderHUD.drawComboHUD         = drawComboHUD
RenderHUD.drawShipInfoPanel    = drawShipInfoPanel
RenderHUD.drawFocusRing        = drawFocusRing
RenderHUD.drawFocusHUD         = drawFocusHUD
RenderHUD.drawFormationBar     = drawFormationBar
RenderHUD.drawRetreatReinforce = drawRetreatReinforce
RenderHUD.drawSkillUpgrade     = drawSkillUpgrade
RenderHUD.drawSpeedControl     = drawSpeedControl
RenderHUD.drawPauseScreen      = drawPauseScreen  -- P1-10: 暂停界面

return RenderHUD
