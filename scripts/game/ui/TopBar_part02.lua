-- Auto-split from TopBar.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


    -- 成就按钮
    do
        local bx, by, bw, bh = screenW - 104, 6, 28, 28
        local isOpen    = AchievementPanel.IsVisible()
        local unlockCnt = AchievementPanel.GetUnlockCount()
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(80,50,20,220) or nvgRGBA(20,40,80,160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(255,200,60,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255,210,80,230))
        nvgText(vg, bx + bw/2, by + bh/2, "🏆")
        if unlockCnt > 0 then
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg, nvgRGBA(60,200,100,240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255,255,255,255))
            nvgText(vg, bx + bw - 2, by + 2, tostring(unlockCnt))
        end
    end

    -- 日志按钮
    do
        local bx, by, bw, bh = screenW - 138, 6, 28, 28
        local isOpen = LogPanel.IsVisible()
        local pendingGoals = 0
        if STAGE_GOALS then
            for _, g in ipairs(STAGE_GOALS) do
                if not ctx.completedGoals[g.id] then pendingGoals = pendingGoals + 1 end
            end
        end
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20,60,120,220) or nvgRGBA(20,40,80,160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160,210,255,230))
        nvgText(vg, bx + bw/2, by + bh/2, "📋")
        if pendingGoals > 0 then
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg, nvgRGBA(255,150,30,240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255,255,255,255))
            nvgText(vg, bx + bw - 2, by + 2, tostring(math.min(pendingGoals, 9)))
        end
    end

    -- 战绩按钮
    do
        local bx, by, bw, bh = screenW - 172, 6, 28, 28
        local isOpen = ctx.statsVisible
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(10, 50, 100, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80, 180, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📊")
    end

    -- 快捷信号按钮
    do
        local bx, by, bw, bh = screenW - 206, 6, 28, 28
        local isOpen = ctx.signalOpen
        local onCD   = ctx.signalCooldown > 0
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(40, 80, 20, 220)
                       or (onCD and nvgRGBA(30, 30, 30, 140))
                       or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(100, 220, 80, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, onCD and nvgRGBA(120, 120, 120, 150) or nvgRGBA(140, 255, 120, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📡")
        if onCD then
            local pct = ctx.signalCooldown / ctx.SIGNAL_CD
            nvgBeginPath(vg)
            nvgArc(vg, bx + bw/2, by + bh/2, 11,
                   -math.pi/2, -math.pi/2 + (1 - pct) * math.pi * 2, 1)
            nvgStrokeColor(vg, nvgRGBA(100, 220, 80, 180))
            nvgStrokeWidth(vg, 2); nvgStroke(vg)
        end
    end

    -- 帝国总览按钮
    do
        local bx, by, bw, bh = screenW - 240, 6, 28, 28
        local isOpen = EmpirePanel.IsVisible()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(50, 30, 80, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(180, 120, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 160, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "🏛️")
    end

    -- 宿敌档案按钮
    do
        local bx, by, bw, bh = screenW - 272, 6, 28, 28
        local isOpen = NemesisRenderPanel.IsVisible()
        local hasActive = NemesisSystem.GetActiveCaptain() ~= nil
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(60, 15, 20, 220) or nvgRGBA(40, 15, 30, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(255, 80, 80, 220) or (hasActive and nvgRGBA(200, 60, 60, 180) or nvgRGBA(80, 40, 60, 120)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, hasActive and nvgRGBA(255, 100, 100, 240) or nvgRGBA(180, 100, 120, 200))
        nvgText(vg, bx + bw/2, by + bh/2, "⚔")
        if hasActive and not isOpen then
            local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 4, by + 4, 3)
            nvgFillColor(vg, nvgRGBA(255, 60, 60, math.floor(180 + 75 * pulse)))
            nvgFill(vg)
        end
    end

    -- 任务板按钮
    do
        local bx, by, bw, bh = screenW - 304, 6, 28, 28
        local isOpen = ctx.questVisible
        local activeN = #QuestBoard.GetQuests()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20, 60, 40, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80, 220, 140, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 230, 160, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📌")
        if activeN > 0 then
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg, nvgRGBA(60, 200, 120, 240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, bx + bw - 2, by + 2, tostring(activeN))
        end
    end

    -- 外交关系网按钮
    do
        local bx, by, bw, bh = screenW - 338, 6, 28, 28
        local isOpen = ctx.diploRelVisible
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(60, 30, 80, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(180, 100, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 140, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "🤝")
    end

    -- 巨构工程按钮（Lv7+ 解锁）
    do
        local bx, by, bw, bh = screenW - 372, 6, 28, 28
        local isOpen = MegaPanel.IsOpen()
        local megaBase = GalaxyScene.GetBase and GalaxyScene.GetBase()
        local coreLevel = megaBase and megaBase.coreLevel or 1
        local visible = coreLevel >= 7
        if visible then
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
            nvgFillColor(vg, isOpen and nvgRGBA(80, 50, 10, 220) or nvgRGBA(40, 30, 60, 160))
            nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
            nvgStrokeColor(vg, isOpen and nvgRGBA(255, 180, 60, 220) or nvgRGBA(100, 80, 140, 120))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 230))
            nvgText(vg, bx + bw/2, by + bh/2, "🏗️")
        end
    end

    -- 舰队涂装按钮
    do
        local bx, by, bw, bh = screenW - 406, 6, 28, 28
        local isOpen = LiveryPanel.IsVisible()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(40, 20, 80, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(180, 100, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 160, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "🎨")
    end

    -- 银河百科按钮
    do
        local bx, by, bw, bh = screenW - 440, 6, 28, 28
        local isOpen = GalactopediaPanel.IsVisible()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20, 60, 50, 220) or nvgRGBA(15, 40, 60, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80, 220, 180, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 230, 200, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📖")
    end

    -- 文明遗产按钮
    do
        local bx, by, bw, bh = screenW - 474, 6, 28, 28
        local isOpen = LegacyPanel.IsOpen()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(50, 40, 15, 220) or nvgRGBA(30, 30, 50, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(255, 200, 60, 220) or nvgRGBA(140, 120, 60, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 80, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "⭐")
    end

    -- ── 星币（遗产按钮左边）──
    local credits = math.floor(rm.resources.credits or 0)
    local credX = screenW - 528
    local credIconH = resIcons["credits"]
    if credIconH and credIconH >= 0 then
        local paint = nvgImagePattern(vg, credX, rowMid - 7, 14, 14, 0, credIconH, 1.0)
        nvgBeginPath(vg); nvgRect(vg, credX, rowMid - 7, 14, 14)
        nvgFillPaint(vg, paint); nvgFill(vg)
    end
    text(credX + 17, rowMid - 6, "星币", 9, 255,210,60,200)
    text(credX + 17, rowMid + 6, tostring(credits), 10, 255,230,80,255)

    -- ── 玩家信息 + 在线时限/无尽轮次 ──
    local infoRightX = credX - 8
    local rtStr, tr, tg, tb
    if ctx.endlessRound > 0 then
        rtStr = string.format("∞ 第 %d 轮", ctx.endlessRound)
        local pulse = math.abs(math.sin(os.clock() * 2.0))
        tr = 255
        tg = math.floor(140 + 60 * pulse)
        tb = math.floor(40  + 20 * pulse)
    else
        local rtSec     = math.max(0, math.floor(ctx.remainingTime))
        local rtMin     = math.floor(rtSec / 60)
        local rtSecPart = rtSec % 60
        if rtMin >= 60 then
            rtStr = string.format("⏱%d:%02d:00", math.floor(rtMin/60), rtMin%60)
        else
            rtStr = string.format("⏱%02d:%02d", rtMin, rtSecPart)
        end
        local isLowTime = rtMin < 30
        tr = isLowTime and 255 or 100
        tg = isLowTime and 80  or 200
        tb = isLowTime and 60  or 120
        if rtMin < 5 then
            local blink = math.floor(os.clock() * 2) % 2 == 0
            tr, tg, tb = blink and 255 or 200, blink and 60 or 80, blink and 60 or 60
        end
    end
    text(infoRightX, rowMid - 6, player.name .. " Lv." .. player.level, 9,
        160,210,255,210, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
    text(infoRightX, rowMid + 6, rtStr, 9, tr, tg, tb, 220, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)

    -- ══════════════════════════════════════════════════════════════════════════
    -- 全部征收按钮（顶栏居中，仅银河视图且已展开时显示）
    -- ══════════════════════════════════════════════════════════════════════════
    if ctx.deployed and ctx.onHarvestAll and ctx.currentScene == "galaxy" then
        local btnW, btnH = 72, 20
        local bx = math.floor(screenW / 2 - btnW / 2)
        local by = math.floor(rowMid - btnH / 2)
        local onCD  = ctx.harvestAllCD > 0
        local bgClr  = onCD and nvgRGBA(20,40,20,160) or nvgRGBA(20,80,40,200)
        local brdClr = onCD and nvgRGBA(60,90,60,120) or nvgRGBA(60,200,100,200)
        local lblClr = onCD and nvgRGBA(100,140,100,180) or nvgRGBA(140,255,160,255)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, btnW, btnH, 4)
        nvgFillColor(vg, bgClr); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx+0.5, by+0.5, btnW-1, btnH-1, 4)
        nvgStrokeColor(vg, brdClr); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- 冷却遮罩
        if onCD then
            local maskW = math.floor(btnW * ctx.harvestAllCD / ctx.HARVEST_ALL_CD)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx + btnW - maskW, by, maskW, btnH, 4)
            nvgFillColor(vg, nvgRGBA(0,0,0,100)); nvgFill(vg)
        end
        local label = onCD and string.format("征收 %ds", math.ceil(ctx.harvestAllCD)) or "全部征收"
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, lblClr)
        nvgText(vg, bx + btnW/2, by + btnH/2, label)
        if not onCD then
            addHit(bx, by, btnW, btnH, ctx.onHarvestAll)
        end
    end

    -- ── 分隔线 ──
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, TOPBAR_H); nvgLineTo(vg, screenW, TOPBAR_H)
    nvgStrokeColor(vg, clr(60,90,200,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ══════════════════════════════════════════════════════════════════════════
    -- 征服进度双轨条（TopBar 底部，3px 总高度）
    -- ══════════════════════════════════════════════════════════════════════════
    local getConquestProgress = ctx.getConquestProgress
    if getConquestProgress then
        local cp = getConquestProgress()
        if cp then
            local barY  = TOPBAR_H
            local barH  = 3
            local half  = screenW / 2

            -- 左轨：殖民进度（绿色）
            local colPct = cp.total > 0 and math.min(1, cp.colonized / cp.total) or 0
            nvgBeginPath(vg); nvgRect(vg, 0, barY, half, barH)
            nvgFillColor(vg, nvgRGBA(10, 25, 15, 180)); nvgFill(vg)
            if colPct > 0.005 then
                local grad = nvgLinearGradient(vg, 0, barY, half * colPct, barY,
                    nvgRGBA(30, 200, 90, 220), nvgRGBA(80, 255, 140, 180))
                nvgBeginPath(vg); nvgRect(vg, 0, barY, half * colPct, barH)
                nvgFillPaint(vg, grad); nvgFill(vg)
            end
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 7)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(60, 220, 110, 190))
            nvgText(vg, 4, barY + barH/2,
                string.format("殖民 %d/%d", cp.colonized, cp.total))

            -- 右轨：歼灭进度（橙红色）
            local pirPct = cp.piratesTotal > 0 and math.min(1, cp.piratesKilled / cp.piratesTotal) or 0
            nvgBeginPath(vg); nvgRect(vg, half, barY, half, barH)
            nvgFillColor(vg, nvgRGBA(25, 12, 10, 180)); nvgFill(vg)
            if pirPct > 0.005 then
                local fillW = half * pirPct
                local grad2 = nvgLinearGradient(vg, half, barY, half + fillW, barY,
                    nvgRGBA(220, 80, 30, 220), nvgRGBA(255, 160, 60, 180))
                nvgBeginPath(vg); nvgRect(vg, half, barY, fillW, barH)
                nvgFillPaint(vg, grad2); nvgFill(vg)
            end
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 160, 70, 190))
            local pirLabel = string.format("歼敌 %d/%d", cp.piratesKilled, cp.piratesTotal)
            if cp.pirateThreat and cp.pirateThreat > 0 then
                local threatColors = {
                    {100,255,100}, {255,220,60}, {255,140,30}, {255,60,60}, {220,60,255}
                }
                local tc = threatColors[cp.pirateThreat] or {255,255,255}
                local dots = string.rep("◆", cp.pirateThreat)
                local labelW = nvgTextBounds(vg, 0, 0, pirLabel)
                nvgFontSize(vg, 7)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220))
                nvgText(vg, screenW - 4 - labelW - 4, barY + barH/2,
                    string.format("威胁%s", dots))
            end
            nvgFontSize(vg, 7)
            nvgFillColor(vg, nvgRGBA(255, 160, 70, 190))
            nvgText(vg, screenW - 4, barY + barH/2, pirLabel)

            -- 中间分隔竖线
            nvgBeginPath(vg)
            nvgMoveTo(vg, half, barY); nvgLineTo(vg, half, barY + barH)
            nvgStrokeColor(vg, nvgRGBA(80, 100, 160, 100))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
    end
end

return TopBar
