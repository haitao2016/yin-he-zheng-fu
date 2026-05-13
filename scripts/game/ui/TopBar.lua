-- ============================================================================
-- game/ui/TopBar.lua  -- 顶部资源栏 + 玩家信息 + 铃铛按钮
-- ============================================================================
local UICommon = require("game.ui.UICommon")
local TopBar   = {}

--- 渲染顶部栏
--- @param ctx table  私有状态
---   .remainingTime    number   剩余在线时长（秒）
---   .notifyOpen       boolean  通知中心是否打开
---   .notifyUnread     number   未读通知数
---   .onBellClick      function 铃铛点击回调 function(newOpen)
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

    if not rm or not player then return end

    -- EXP 条（最顶部细线）
    local expNeeded = player.level * EXP_PER_LEVEL
    local expPct    = math.min(1, player.exp / expNeeded)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, 3)
    nvgFillColor(vg, clr(15,15,35,200)); nvgFill(vg)
    if expPct > 0.01 then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW * expPct, 3)
        nvgFillColor(vg, clr(50,180,255,230)); nvgFill(vg)
    end

    -- 顶部背景条（高度与 UICommon.TOPBAR_H=44 对齐）
    panel(0, 3, screenW, 44, 0, {0,4,16,210}, {50,80,180,70})

    -- 原矿来源映射
    local RAW_KEYS = { metal="minerals", esource="energy", nuclear="crystal" }

    -- 资源图标 + 数量（原矿层）
    -- 布局：3 列原矿 + 右侧精炼区（150px）+ 星币区（200px）
    --   行1 (y=14): 原矿名 + 图标
    --   行2 (y=28): 原矿数量 (速率)
    local REFINED_W = 150
    local mult = rm.refineryMult or 0
    local eBlockConsumeRate = 3.0 * mult
    local esourceRefineRate = eBlockConsumeRate / 2.0

    local cols = #RES_ORDER
    local colW = (screenW - 200 - REFINED_W) / cols
    for i, res in ipairs(RES_ORDER) do
        local c       = RES_COLORS[res]
        local rawKey  = RAW_KEYS[res]
        local rawVal  = math.floor(rm.resources[rawKey] or 0)
        local rawRate = rm.rates[rawKey] or 0
        local bx      = 16 + (i - 1) * colW
        local iconH   = resIcons[res]
        if iconH and iconH >= 0 then
            local paint = nvgImagePattern(vg, bx, 5, 14, 14, 0, iconH, 1.0)
            nvgBeginPath(vg); nvgRect(vg, bx, 5, 14, 14)
            nvgFillPaint(vg, paint); nvgFill(vg)
        end
        local tx      = bx + 18
        local rateStr = (mult > 0) and string.format("+%.1f/s", rawRate) or "待精炼"
        text(tx, 15, RES_TAGS[res], 9, c[1],c[2],c[3],200)
        text(tx, 29, string.format("%d (%s)", rawVal, rateStr), 10, 220,220,220,255)
    end

    -- 精炼资源区（水晶列与星币之间）
    local rzX = 16 + cols * colW + 12
    local rzYs = {12, 24, 37}
    for j, res in ipairs(RES_ORDER) do
        local c      = RES_COLORS[res]
        local refVal = math.floor(rm.resources[res] or 0)
        local label
        if res == "esource" and mult > 0 then
            label = string.format("能源 %d  +%.1f/s", refVal, esourceRefineRate)
        else
            label = string.format("%s %d", RES_LABELS[res], refVal)
        end
        -- 小胶囊背景
        nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local tw = nvgTextBounds(vg, 0, 0, label, nil)
        nvgBeginPath(vg); nvgRoundedRect(vg, rzX - 2, rzYs[j] - 6, tw + 6, 12, 2)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 30)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], 70)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        text(rzX + 1, rzYs[j], label, 9, c[1],c[2],c[3],230)
    end

    -- 星币（右侧）
    local credits   = math.floor(rm.resources.credits or 0)
    local credIconH = resIcons["credits"]
    if credIconH and credIconH >= 0 then
        local paint = nvgImagePattern(vg, screenW - 220, 6, 16, 16, 0, credIconH, 1.0)
        nvgBeginPath(vg); nvgRect(vg, screenW - 220, 6, 16, 16)
        nvgFillPaint(vg, paint); nvgFill(vg)
    end
    text(screenW - 199, 14, "星币",           9, 255,210,60,200)
    text(screenW - 199, 26, tostring(credits), 11, 255,230,80,255)

    -- 玩家信息
    local expStr = "EXP " .. player.exp .. "/" .. expNeeded
    text(screenW-16, 14, player.name .. "  Lv." .. player.level .. "  " .. player.rank,
        9, 160,210,255,210, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
    text(screenW-16, 26, expStr, 9, 50,180,255,180, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)

    -- 在线时限
    local rtSec     = math.max(0, math.floor(ctx.remainingTime or 7200))
    local rtMin     = math.floor(rtSec / 60)
    local rtSecPart = rtSec % 60
    local rtStr
    if rtMin >= 60 then
        rtStr = string.format("在线时限  %d:%02d:00", math.floor(rtMin/60), rtMin%60)
    else
        rtStr = string.format("在线时限  %02d:%02d", rtMin, rtSecPart)
    end
    local isLowTime = rtMin < 30
    local tr = isLowTime and 255 or 100
    local tg = isLowTime and 80  or 200
    local tb = isLowTime and 60  or 120
    if rtMin < 5 then
        local blink = math.floor(os.clock() * 2) % 2 == 0
        tr, tg, tb = blink and 255 or 200, blink and 60 or 80, blink and 60 or 60
    end
    text(screenW-16, 37, rtStr, 8, tr, tg, tb, 220, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)

    -- 铃铛按钮（通知中心入口）
    local bx, by, bw, bh = screenW - 258, 5, 26, 26
    local notifyOpen  = ctx.notifyOpen
    local hasUnread   = (ctx.notifyUnread or 0) > 0
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 6)
    nvgFillColor(vg, notifyOpen
        and nvgRGBA(20, 80, 180, 200) or nvgRGBA(20, 40, 80, 160))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 6)
    nvgStrokeColor(vg, notifyOpen
        and nvgRGBA(80, 160, 255, 220) or nvgRGBA(60, 100, 180, 120))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, hasUnread
        and nvgRGBA(255, 220, 60, 255) or nvgRGBA(140, 180, 255, 220))
    nvgText(vg, bx + bw/2, by + bh/2, "🔔")
    if hasUnread then
        local dotStr = tostring(math.min(ctx.notifyUnread, 99))
        local dotX, dotY = bx + bw - 2, by + 2
        nvgBeginPath(vg); nvgCircle(vg, dotX, dotY, 7)
        nvgFillColor(vg, nvgRGBA(220, 50, 50, 240)); nvgFill(vg)
        nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, dotX, dotY, dotStr)
    end
    addHit(bx, by, bw, bh, function()
        if ctx.onBellClick then ctx.onBellClick() end
    end)

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, 73); nvgLineTo(vg, screenW, 73)
    nvgStrokeColor(vg, clr(60,90,200,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
end

return TopBar
