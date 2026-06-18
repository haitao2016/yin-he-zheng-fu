-- Auto-split from TopBar.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function TopBar.Render(ctx)
    local vg       = UICommon.vg
    local screenW  = UICommon.screenW
    local rm       = UICommon.rm
    local player   = UICommon.player
    local resIcons = UICommon.resIcons
    local clr      = UICommon.clr
    local panel    = UICommon.panel
    local text     = UICommon.text
    local addHit   = UICommon.addHit
    local TOPBAR_H = UICommon.TOPBAR_H

    if not rm or not player then return end

    -- EXP 条（最顶部细线，2px）
    local expNeeded = player.level * EXP_PER_LEVEL
    local expPct    = math.min(1, player.exp / expNeeded)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, 2)
    nvgFillColor(vg, clr(15,15,35,200)); nvgFill(vg)
    if expPct > 0.01 then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW*expPct, 2)
        nvgFillColor(vg, clr(50,180,255,230)); nvgFill(vg)
    end

    -- 顶部背景条（44px 紧凑版）
    panel(0, 2, screenW, TOPBAR_H - 2, 0, {0,4,16,220}, {50,80,180,70})

    local RAW_KEYS = { metal="minerals", esource="energy", nuclear="crystal" }
    local mult = rm.refineryMult or 0
    local eBlockRate    = 3.0 * mult
    local esourceRate   = eBlockRate / 2.0

    -- 布局：[原矿3列] [精炼区130px] [星币+玩家+铃铛260px]
    local REFINED_W = 130
    local RIGHT_W   = 270
    local cols      = #RES_ORDER
    local colW      = (screenW - RIGHT_W - REFINED_W) / cols
    local rowMid    = 2 + (TOPBAR_H - 2) / 2   -- 垂直居中 y ≈ 23

    local displayRes      = ctx.displayRes
    local flashRes        = ctx.flashRes
    local FLASH_DURATION  = ctx.FLASH_DURATION
    local resCrisisState  = ctx.resCrisisState
    local resCrisisBlink  = ctx.resCrisisBlink
    local resTrendDir     = ctx.resTrendDir

    -- ── 原矿3列（两行：名称 + 数量/速率）──
    for i, res in ipairs(RES_ORDER) do
        local c      = RES_COLORS[res]
        local rawKey = RAW_KEYS[res]
        local rawVal  = math.floor(displayRes[rawKey] or rm.resources[rawKey] or 0)
        local rawRate = rm.rates[rawKey] or 0
        local bx  = 8 + (i-1) * colW

        local iconH = resIcons[res]
        if iconH and iconH >= 0 then
            local paint = nvgImagePattern(vg, bx, rowMid - 7, 14, 14, 0, iconH, 1.0)
            nvgBeginPath(vg); nvgRect(vg, bx, rowMid - 7, 14, 14)
            nvgFillPaint(vg, paint); nvgFill(vg)
        end

        local tx = bx + 17
        local rateStr = mult > 0 and string.format("+%.0f/s", rawRate) or "待炼"
        -- 闪光颜色：增加→绿，减少→橙
        local fl = flashRes[rawKey]
        local valR, valG, valB = 220, 220, 220
        if fl and fl.timer > 0 then
            local t = fl.timer / FLASH_DURATION
            if fl.dir > 0 then
                valR = math.floor(valR * (1-t) + 100 * t)
                valG = math.floor(valG * (1-t) + 255 * t)
                valB = math.floor(valB * (1-t) + 120 * t)
            else
                valR = math.floor(valR * (1-t) + 255 * t)
                valG = math.floor(valG * (1-t) + 160 * t)
                valB = math.floor(valB * (1-t) + 60  * t)
            end
        end
        text(tx, rowMid - 6, RES_TAGS[res], 9, c[1],c[2],c[3],200)
        text(tx, rowMid + 6, string.format("%d %s", rawVal, rateStr), 9, valR, valG, valB, 240)
    end

    -- ── 精炼资源区（水晶列与星币之间，3行竖排）──
    local rzX  = 8 + cols * colW + 8
    local rzYs = { rowMid - 10, rowMid + 1, rowMid + 12 }
    for j, res in ipairs(RES_ORDER) do
        local c      = RES_COLORS[res]
        local refVal = math.floor(displayRes[res] or rm.resources[res] or 0)
        local refinedLbl = (RES_REFINED_LABELS and RES_REFINED_LABELS[res]) or RES_LABELS[res]
        local label
        if res == "esource" and mult > 0 then
            label = string.format("%s %d +%.1f/s", refinedLbl, refVal, esourceRate)
        else
            label = string.format("%s %d", refinedLbl, refVal)
        end
        -- 闪光：增加→背景偏绿，减少→背景偏红
        local fl  = flashRes[res]
        local bgA = 28
        local bdA = 65
        local txA = 230
        local txR, txG, txB = c[1], c[2], c[3]
        if fl and fl.timer > 0 then
            local t = fl.timer / FLASH_DURATION
            bgA = math.floor(28 + 60 * t)
            bdA = math.floor(65 + 100 * t)
            txA = 255
            if fl.dir > 0 then
                txR = math.floor(txR * (1-t) + 100 * t)
                txG = math.floor(txG * (1-t) + 255 * t)
                txB = math.floor(txB * (1-t) + 120 * t)
            else
                txR = math.floor(txR * (1-t) + 255 * t)
                txG = math.floor(txG * (1-t) + 80  * t)
                txB = math.floor(txB * (1-t) + 60  * t)
            end
        end
        nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local tw = nvgTextBounds(vg, 0, 0, label, nil)
        nvgBeginPath(vg); nvgRoundedRect(vg, rzX - 2, rzYs[j] - 5, tw + 6, 11, 2)
        -- 危机状态：叠加红色半透明背景
        if resCrisisState[res] then
            local blinkA = math.floor(30 + 25 * math.abs(math.sin(resCrisisBlink * 3.5)))
            nvgFillColor(vg, nvgRGBA(255, 60, 60, bgA + blinkA)); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], bgA)); nvgFill(vg)
        end
        -- 危机状态：红色闪烁边框
        if resCrisisState[res] then
            local blinkB = math.floor(140 + 115 * math.abs(math.sin(resCrisisBlink * 3.5)))
            nvgStrokeColor(vg, nvgRGBA(255, 80, 80, blinkB)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        else
            nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], bdA)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        end
        -- 危机状态文字改为红色
        if resCrisisState[res] then
            nvgFillColor(vg, nvgRGBA(255, 100, 100, 255))
        else
            nvgFillColor(vg, nvgRGBA(txR, txG, txB, txA))
        end
        nvgText(vg, rzX + 1, rzYs[j], label)

        -- 趋势箭头（紧跟在胶囊右侧）
        local tdir = resTrendDir[res]
        if tdir and tdir ~= 0 then
            local arrowX = rzX + tw + 9
            local arrowY = rzYs[j]
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if tdir > 0 then
                nvgFillColor(vg, nvgRGBA(80, 230, 120, 200))
                nvgText(vg, arrowX, arrowY, "▲")
            else
                nvgFillColor(vg, nvgRGBA(255, 100, 80, 200))
                nvgText(vg, arrowX, arrowY, "▼")
            end
        end
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- 右区工具按钮行（从右往左排列，每个 28×28，间距 4-6px）
    -- ══════════════════════════════════════════════════════════════════════════

    -- 通知铃铛（最右）
    do
        local bx, by, bw, bh = screenW - 36, 6, 28, 28
        local isOpen    = NotifyPanel.IsOpen()
        local hasUnread = NotifyPanel.GetUnread() > 0
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20,80,180,200) or nvgRGBA(20,40,80,160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, hasUnread and nvgRGBA(255,220,60,255) or nvgRGBA(140,180,255,220))
        nvgText(vg, bx + bw/2, by + bh/2, "🔔")
        if hasUnread then
            local dot = math.min(NotifyPanel.GetUnread(), 99)
            local dotX = bx + bw - 2
            local dotY = by + 2
            nvgBeginPath(vg); nvgCircle(vg, dotX, dotY, 6)
            nvgFillColor(vg, nvgRGBA(220,50,50,240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255,255,255,255))
            nvgText(vg, dotX, dotY, tostring(dot))
        end
    end

    -- 设置按钮（铃铛左边）
    do
        local bx, by, bw, bh = screenW - 70, 6, 28, 28
        local isOpen = SettingsPanel.IsVisible()
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20,80,180,200) or nvgRGBA(20,40,80,160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180,210,255,220))
        nvgText(vg, bx + bw/2, by + bh/2, "⚙")
    end
