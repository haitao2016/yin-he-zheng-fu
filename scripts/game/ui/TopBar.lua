---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/TopBar.lua  -- 顶部资源栏 + 工具按钮行 + 征服进度条
-- 从 GameUI.RenderTopBar (L614-L1211) 完整迁移
-- ============================================================================
local UICommon          = require("game.ui.UICommon")
local NotifyPanel       = require("game.ui.NotifyPanel")
local SettingsPanel     = require("game.ui.SettingsPanel")
local AchievementPanel  = require("game.ui.AchievementPanel")
local LogPanel          = require("game.ui.LogPanel")
local EmpirePanel       = require("game.ui.EmpirePanel")
local NemesisRenderPanel = require("game.ui.NemesisRenderPanel")
local NemesisSystem     = require("game.NemesisSystem")
local QuestBoard        = require("game.QuestBoard")
local MegaPanel         = require("game.ui.MegaPanel")
local LiveryPanel       = require("game.ui.LiveryPanel")
local GalactopediaPanel = require("game.ui.GalactopediaPanel")
local GalaxyScene       = require("game.GalaxyScene")
local LegacyPanel       = require("game.ui.LegacyPanel")

local TopBar = {}

-- ============================================================================
--- 渲染完整顶栏（每帧由 GameUI.RenderTopBar 调用）
--- @param ctx table  GameUI 传入的状态快照
---   .displayRes       table   资源滚动显示值
---   .flashRes         table   资源闪光 { timer, dir }
---   .FLASH_DURATION   number  闪光持续秒
---   .resCrisisState   table   资源危机状态 { [key]=true }
---   .resCrisisBlink   number  危机闪烁计时器
---   .resTrendDir      table   趋势箭头 { [key]=1/-1/0 }
---   .statsVisible     boolean 战绩面板是否打开
---   .signalOpen       boolean 信号面板是否打开
---   .signalCooldown   number  信号冷却秒数
---   .SIGNAL_CD        number  信号冷却总时长
---   .diploRelVisible  boolean 外交面板是否打开
---   .questVisible     boolean 任务面板是否打开
---   .deployed         boolean 种子飞船已展开
---   .currentScene     string  当前场景 "galaxy"/"battle"
---   .harvestAllCD     number  全部征收冷却
---   .HARVEST_ALL_CD   number  全部征收冷却总时长
---   .onHarvestAll     function 全部征收按钮回调
---   .getConquestProgress function 获取征服进度
---   .remainingTime    number  剩余在线时间(秒)
---   .endlessRound     number  无尽模式轮次(0=普通)
---   .completedGoals   table   已完成目标 { [id]=true }
-- ============================================================================
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

    -- 布局：[原矿3列] [精炼区] [星币+玩家+铃铛]
    -- 响应式：窄屏（<500）时缩小右侧区域，保证资源列不重叠
    local REFINED_W = screenW < 500 and 0 or 130    -- 窄屏隐藏精炼区
    local RIGHT_W   = screenW < 500 and 140 or 270  -- 窄屏压缩右侧
    local cols      = #RES_ORDER
    local colW      = math.max(50, (screenW - RIGHT_W - REFINED_W) / cols)
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
    -- 右区工具按钮行（从右往左排列，响应式：窄屏缩小按钮+间距）
    -- ══════════════════════════════════════════════════════════════════════════
    local BTN_SZ   = screenW < 400 and 22 or 28   -- 窄屏缩小按钮
    local BTN_GAP  = screenW < 400 and 2  or 6    -- 窄屏缩小间距
    local BTN_STEP = BTN_SZ + BTN_GAP
    local BTN_Y    = screenW < 400 and 8 or 6
    local BTN_FONT = screenW < 400 and 11 or 13
    -- 最大可放按钮数（保证不侵入资源列区域）
    local resAreaEnd = 8 + cols * colW + (REFINED_W > 0 and REFINED_W + 16 or 8)
    local maxBtns    = math.floor((screenW - resAreaEnd - 8) / BTN_STEP)

    local btnIdx = 0  -- 从右往左计数
    local function nextBtnX()
        btnIdx = btnIdx + 1
        return screenW - btnIdx * BTN_STEP - 4
    end
    local function canFitMore()
        return btnIdx < maxBtns
    end

    -- 通知铃铛（最右，必显示）
    do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
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
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
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

    -- 设置按钮（铃铛左边，必显示）
    do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = SettingsPanel.IsVisible()
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20,80,180,200) or nvgRGBA(20,40,80,160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80,160,255,220) or nvgRGBA(60,100,180,120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT + 1); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180,210,255,220))
        nvgText(vg, bx + bw/2, by + bh/2, "⚙")
    end

    -- 成就按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
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
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255,210,80,230))
        nvgText(vg, bx + bw/2, by + bh/2, "🏆")
        if unlockCnt > 0 then
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg, nvgRGBA(60,200,100,240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255,255,255,255))
            nvgText(vg, bx + bw - 2, by + 2, tostring(unlockCnt))
        end
    end end

    -- 日志按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
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
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160,210,255,230))
        nvgText(vg, bx + bw/2, by + bh/2, "📋")
        if pendingGoals > 0 then
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg, nvgRGBA(255,150,30,240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255,255,255,255))
            nvgText(vg, bx + bw - 2, by + 2, tostring(math.min(pendingGoals, 9)))
        end
    end end

    -- 战绩按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = ctx.statsVisible
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(10, 50, 100, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80, 180, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📊")
    end end

    -- 快捷信号按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
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
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, onCD and nvgRGBA(120, 120, 120, 150) or nvgRGBA(140, 255, 120, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📡")
        if onCD then
            local pct = ctx.signalCooldown / ctx.SIGNAL_CD
            nvgBeginPath(vg)
            nvgArc(vg, bx + bw/2, by + bh/2, BTN_SZ * 0.4,
                   -math.pi/2, -math.pi/2 + (1 - pct) * math.pi * 2, 1)
            nvgStrokeColor(vg, nvgRGBA(100, 220, 80, 180))
            nvgStrokeWidth(vg, 2); nvgStroke(vg)
        end
    end end

    -- 帝国总览按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = EmpirePanel.IsVisible()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(50, 30, 80, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(180, 120, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 160, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "🏛️")
    end end

    -- 宿敌档案按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = NemesisRenderPanel.IsVisible()
        local hasActive = NemesisSystem.GetActiveCaptain() ~= nil
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(60, 15, 20, 220) or nvgRGBA(40, 15, 30, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(255, 80, 80, 220) or (hasActive and nvgRGBA(200, 60, 60, 180) or nvgRGBA(80, 40, 60, 120)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, hasActive and nvgRGBA(255, 100, 100, 240) or nvgRGBA(180, 100, 120, 200))
        nvgText(vg, bx + bw/2, by + bh/2, "⚔")
        if hasActive and not isOpen then
            local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 4, by + 4, 3)
            nvgFillColor(vg, nvgRGBA(255, 60, 60, math.floor(180 + 75 * pulse)))
            nvgFill(vg)
        end
    end end

    -- 任务板按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = ctx.questVisible
        local activeN = #QuestBoard.GetQuests()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20, 60, 40, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80, 220, 140, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 230, 160, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📌")
        if activeN > 0 then
            nvgBeginPath(vg); nvgCircle(vg, bx + bw - 2, by + 2, 6)
            nvgFillColor(vg, nvgRGBA(60, 200, 120, 240)); nvgFill(vg)
            nvgFontSize(vg, 7); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, bx + bw - 2, by + 2, tostring(activeN))
        end
    end end

    -- 外交关系网按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = ctx.diploRelVisible
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(60, 30, 80, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(180, 100, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 140, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "🤝")
    end end

    -- 巨构工程按钮（Lv7+ 解锁）
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
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
            nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 230))
            nvgText(vg, bx + bw/2, by + bh/2, "🏗️")
        end
    end end

    -- 舰队涂装按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = LiveryPanel.IsVisible()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(40, 20, 80, 220) or nvgRGBA(20, 40, 80, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(180, 100, 255, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 160, 255, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "🎨")
    end end

    -- 银河百科按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = GalactopediaPanel.IsVisible()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(20, 60, 50, 220) or nvgRGBA(15, 40, 60, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(80, 220, 180, 220) or nvgRGBA(60, 100, 180, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 230, 200, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "📖")
    end end

    -- 文明遗产按钮
    if canFitMore() then do
        local bx, by, bw, bh = nextBtnX(), BTN_Y, BTN_SZ, BTN_SZ
        local isOpen = LegacyPanel.IsOpen()
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgFillColor(vg, isOpen and nvgRGBA(50, 40, 15, 220) or nvgRGBA(30, 30, 50, 160))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
        nvgStrokeColor(vg, isOpen and nvgRGBA(255, 200, 60, 220) or nvgRGBA(140, 120, 60, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, BTN_FONT); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 80, 230))
        nvgText(vg, bx + bw/2, by + bh/2, "⭐")
    end end

    -- ── 星币（按钮行左边动态定位）──
    local credits = math.floor(rm.resources.credits or 0)
    local credX = math.max(resAreaEnd + 4, screenW - (btnIdx + 1) * BTN_STEP - 60)
    local credIconH = resIcons["credits"]
    if credIconH and credIconH >= 0 then
        local paint = nvgImagePattern(vg, credX, rowMid - 7, 14, 14, 0, credIconH, 1.0)
        nvgBeginPath(vg); nvgRect(vg, credX, rowMid - 7, 14, 14)
        nvgFillPaint(vg, paint); nvgFill(vg)
    end
    text(credX + 17, rowMid - 6, "星币", 9, 255,210,60,200)
    text(credX + 17, rowMid + 6, tostring(credits), 10, 255,230,80,255)

    -- ── 玩家信息 + 在线时限/无尽轮次（窄屏隐藏）──
    local infoRightX = credX - 8
    if infoRightX < resAreaEnd + 10 then goto skipPlayerInfo end
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
    ::skipPlayerInfo::

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
