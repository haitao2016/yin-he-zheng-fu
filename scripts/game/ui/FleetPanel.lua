--- 编队管理面板模块
--- 负责渲染编队 tab、舰船列表、储备池、移动模式

local UICommon = require("game.ui.UICommon")

local FleetPanel = {}

-- 舰船类型颜色映射（用于折叠态圆点摘要）
local FLEET_SHIP_COLORS = {
    SCOUT         = {100,200,255},
    FRIGATE       = {80,160,255},
    DESTROYER     = {40,100,220},
    BATTLECRUISER = {160,80,255},
}

-- 面板私有状态
local collapsed_      = false
local activeId_       = 1       -- 当前选中编队 id
local mapSelectedId_  = nil     -- 地图选中编队 id
local moveFrom_       = nil     -- 移动源编队 id
local moveType_       = nil     -- 待移动舰船类型
local bonusCollapsed_ = true    -- 科技加成区折叠状态

function FleetPanel.SetActiveId(id)   activeId_ = id end
function FleetPanel.GetActiveId()     return activeId_ end
function FleetPanel.SetMapSelected(id)
    mapSelectedId_ = id
    if id == nil then
        moveFrom_ = nil
        moveType_ = nil
    end
end
function FleetPanel.GetMapSelected()  return mapSelectedId_ end
function FleetPanel.ClearMove()
    moveFrom_ = nil
    moveType_ = nil
end

--- 渲染编队面板
---@param ctx table  {fm, explorerColonizeMode,
---                   onFleetSelect, onFleetMoveShip,
---                   onExplorerColonize, onAssignReserve,
---                   techPanelH, baseBonus}
function FleetPanel.Render(ctx)
    local fm = UICommon.fm
    if not fm then return end

    local vg        = UICommon.vg
    local screenW   = UICommon.screenW
    local addHit    = UICommon.addHit
    local panel     = UICommon.panel
    local text      = UICommon.text
    local clr       = UICommon.clr
    local clrC      = UICommon.clrC
    local C         = UICommon.C

    local explorerColonizeMode = ctx.explorerColonizeMode or false
    local onFleetSelect        = ctx.onFleetSelect
    local onFleetMoveShip      = ctx.onFleetMoveShip
    local onExplorerColonize   = ctx.onExplorerColonize
    local onAssignReserve      = ctx.onAssignReserve
    local baseBonus            = ctx.baseBonus  -- rm_.baseBonus，可能为 nil

    local pw_full = UICommon.FLEET_PANEL_W or 248
    local py      = UICommon.PANEL_TOP or 48
    -- FleetPanel 位于 PlanetPanel 左侧，避免两面板重叠
    -- right_offset = PLANET_PANEL_RIGHT + PLANET_PANEL_W + FLEET_PANEL_GAP = 12+275+6 = 293
    local fleetRight = (UICommon.PLANET_PANEL_RIGHT or 12)
                     + (UICommon.PLANET_PANEL_W     or 275)
                     + (UICommon.FLEET_PANEL_GAP    or 6)
    local fl      = fm.fleets
    local maxF    = fm.maxFleets
    local TAB_H   = 22
    local ROW_H   = 18
    local RES_ROW_H = 22
    local curFleet  = fl[activeId_]
    local shipRows  = curFleet and #curFleet.ships or 0

    -- 储备池列表
    local reserveList = {}
    for _, stt in ipairs(SHIP_QUEUE_ORDER) do
        if SHIP_TYPES[stt] then
            local cnt = fm.reserve and (fm.reserve[stt] or 0) or 0
            if cnt > 0 then
                reserveList[#reserveList + 1] = { shipType = stt, count = cnt }
            end
        end
    end

    -- ---- 折叠态：贴右边缘的竖向标签条 ----
    if collapsed_ then
        local activeDots = {}
        for fid = 1, maxF do
            local f = fl[fid]
            if f and #f.ships > 0 then
                activeDots[#activeDots+1] = FLEET_SHIP_COLORS[f.ships[1].shipType] or {100,180,255}
            end
        end

        local dotCount = #activeDots
        local TAB_W  = 18
        local TAB_PH = math.max(90, 60 + dotCount * 10)
        -- 折叠 tab 贴在 PlanetPanel 左边缘，不与 PlanetPanel 重叠
        local px_tab = screenW - fleetRight - TAB_W

        nvgBeginPath(vg)
        nvgRoundedRectVarying(vg, px_tab, py, TAB_W, TAB_PH, 4, 0, 0, 4)
        nvgFillColor(vg, clrC(C.panelBg))
        nvgFill(vg)
        nvgStrokeColor(vg, clrC(C.panelBorderDim))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgFillColor(vg, clrC(C.blueAccent))
        local label = "编队管理"
        for ci = 1, #label / 3 do
            local ch = label:sub((ci-1)*3+1, ci*3)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, px_tab + TAB_W/2, py + 12 + (ci-1)*16, ch)
        end

        local dotStartY = py + 12 + 4 * 16 + 6
        for di, dc in ipairs(activeDots) do
            nvgBeginPath(vg)
            nvgCircle(vg, px_tab + TAB_W/2, dotStartY + (di-1)*10, 3)
            nvgFillColor(vg, nvgRGBA(dc[1], dc[2], dc[3], 220))
            nvgFill(vg)
        end

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(120,180,255,200))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, px_tab + TAB_W/2, py + TAB_PH - 10, "▶")

        addHit(px_tab, py, TAB_W, TAB_PH, function()
            collapsed_ = false
        end)
        return
    end

    -- ---- 展开态：正常面板 ----
    local pw = pw_full
    -- 展开面板位于 PlanetPanel 左侧（间距 FLEET_PANEL_GAP）
    local px = screenW - pw - fleetRight

    -- 构建科技加成行（仅展示倍率 > 1 或有数值的项）
    local bonusRows = {}
    if baseBonus then
        local bb = baseBonus
        local function addRow(icon, label, val, clrR, clrG, clrB)
            bonusRows[#bonusRows + 1] = {
                icon = icon, label = label, val = val,
                cr = clrR, cg = clrG, cb = clrB
            }
        end
        -- 舰船战斗属性
        if bb.shipDmgMult    and bb.shipDmgMult    > 1.001 then
            addRow("⚔", "攻击力", string.format("+%.0f%%", (bb.shipDmgMult-1)*100), 255,120,80)
        end
        if bb.shipHealthMult and bb.shipHealthMult > 1.001 then
            addRow("❤", "舰船生命", string.format("+%.0f%%", (bb.shipHealthMult-1)*100), 255,80,100)
        end
        if bb.shieldBonus    and bb.shieldBonus    > 0.5 then
            addRow("🛡", "护盾值", string.format("+%.0f", bb.shieldBonus), 80,180,255)
        end
        if bb.defenseBonus   and bb.defenseBonus   > 0.001 then
            addRow("🔰", "防御率", string.format("+%.0f%%", bb.defenseBonus*100), 80,220,255)
        end
        -- 机动/移速
        if bb.fleetSpeedMult and bb.fleetSpeedMult > 1.001 then
            addRow("🚀", "舰队速度", string.format("+%.0f%%", (bb.fleetSpeedMult-1)*100), 100,255,200)
        end
        -- 建造速度
        if bb.shipyardMult   and bb.shipyardMult   > 1.001 then
            addRow("🔧", "建造速度", string.format("+%.0f%%", (bb.shipyardMult-1)*100), 255,200,80)
        end
        -- 曲速闸门
        if bb.hasWarpGate then
            addRow("🌀", "曲速闸门", "已启用", 180,100,255)
        end
    end
    local BONUS_ROW_H = 16
    -- 加成区高度：标题行14 + 各行 + 4底边，折叠时仅显示标题行14
    local bonusH = (baseBonus ~= nil)
        and (14 + (bonusCollapsed_ and 0 or (#bonusRows > 0 and #bonusRows * BONUS_ROW_H + 4 or 14)) + 6)
        or 0

    local ph = 16 + 18
             + TAB_H + 6
             + 18
             + (shipRows > 0 and (shipRows * ROW_H) or 20)
             + (moveFrom_ and 38 or 0)
             + 12
             + 16
             + math.max(1, #reserveList) * RES_ROW_H
             + 12
             + bonusH

    panel(px, py, pw, ph, 7, {8,16,30,240}, {50,100,200,200})

    local sy = py + 14

    -- 收起按钮
    local btnX = px + pw - 18
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(120,180,255,200))
    nvgText(vg, btnX, py + 14, "◀")
    addHit(btnX - 10, py, 22, 28, function()
        collapsed_ = true
    end)
    text(px+pw/2, sy, "[ 编队管理 ]", 13, 100,170,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = sy + 18

    -- ---- 编队 tab ----
    local tabW = math.floor((pw - 8) / maxF)
    local tabX = px + 4
    for i = 1, maxF do
        local active  = (i == activeId_)
        local mapSel  = (i == mapSelectedId_)
        local totalSh = fm:totalShips(i)
        local br, bg, bb = active and 60 or 20, active and 120 or 50, active and 220 or 120
        if mapSel and not active then
            br, bg, bb = 80, 60, 20
        elseif mapSel and active then
            br, bg, bb = 80, 100, 200
        end
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tabX, sy, tabW - 2, TAB_H, 3)
        nvgFillColor(vg, nvgRGBA(br, bg, bb, (active or mapSel) and 220 or 120))
        nvgFill(vg)
        if active then
            nvgStrokeColor(vg, nvgRGBA(100,180,255,200))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        elseif mapSel then
            nvgStrokeColor(vg, nvgRGBA(255,180,60,220))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200,220,255,255))
        nvgText(vg, tabX + (tabW-2)/2, sy + TAB_H/2, i)
        nvgFontSize(vg, 8)
        local isFull = totalSh >= 10
        nvgFillColor(vg, isFull and nvgRGBA(255,80,80,240) or nvgRGBA(255,220,80,200))
        nvgText(vg, tabX + (tabW-2)/2, sy + TAB_H - 5, totalSh.."/10")
        if mapSel then
            nvgFontSize(vg, 7)
            nvgFillColor(vg, nvgRGBA(255,180,60,240))
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgText(vg, tabX + tabW - 3, sy + 2, "▶")
        end
        local capturedI = i
        local tx, ty = tabX, sy
        addHit(tx, ty, tabW-2, TAB_H, function()
            if mapSelectedId_ == capturedI then
                mapSelectedId_ = nil
                moveFrom_      = nil
                moveType_      = nil
                if onFleetSelect then onFleetSelect(nil) end
            else
                activeId_      = capturedI
                mapSelectedId_ = capturedI
                moveFrom_      = nil
                moveType_      = nil
                if onFleetSelect then onFleetSelect(capturedI) end
            end
        end)
        tabX = tabX + tabW
    end
    sy = sy + TAB_H + 6

    -- ---- 舰船列表 ----
    if not curFleet then
        text(px+8, sy+8, "编队数据加载中...", 10, 160,160,180,160)
        return
    end

    local curTotal = fm:totalShips(activeId_)
    local capColor = curTotal >= 10 and {255,80,80} or {100,180,255}
    text(px+8,    sy+8, curFleet.name, 10, 160,200,255,200)
    text(px+pw-8, sy+8, curTotal.."/10", 10, capColor[1],capColor[2],capColor[3],230,
        NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
    sy = sy + 18

    if #curFleet.ships == 0 then
        text(px+pw/2, sy+10, "（空编队）", 10, 130,150,180,160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        sy = sy + 20
    else
        for _, entry in ipairs(curFleet.ships) do
            local st = SHIP_TYPES[entry.shipType]
            if st then
                local c = FLEET_SHIP_COLORS[entry.shipType] or st.color
                nvgBeginPath(vg)
                nvgCircle(vg, px+14, sy+ROW_H/2, 4)
                nvgFillColor(vg, nvgRGBA(c[1],c[2],c[3],200))
                nvgFill(vg)
                text(px+24, sy+ROW_H/2, st.name .. " ×" .. entry.count,
                    10, 180,210,255,220, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)

                if moveFrom_ == activeId_ and moveType_ == entry.shipType then
                    local bx = px + pw - 40
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, sy+2, 32, ROW_H-4, 2)
                    nvgFillColor(vg, nvgRGBA(200,60,60,180)); nvgFill(vg)
                    text(bx+16, sy+ROW_H/2, "取消", 9, 255,200,200,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx, sy+2, 32, ROW_H-4, function()
                        moveFrom_ = nil
                        moveType_ = nil
                    end)
                else
                    local bx = px + pw - 40
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, sy+2, 32, ROW_H-4, 2)
                    nvgFillColor(vg, nvgRGBA(40,80,180,160)); nvgFill(vg)
                    text(bx+16, sy+ROW_H/2, "移动", 9, 160,200,255,220, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capturedType = entry.shipType
                    local capturedSrc  = activeId_
                    addHit(bx, sy+2, 32, ROW_H-4, function()
                        moveFrom_ = capturedSrc
                        moveType_ = capturedType
                    end)
                end
                sy = sy + ROW_H
            end
        end
    end

    -- ---- 移动模式：选择目标编队 ----
    if moveFrom_ then
        sy = sy + 4
        text(px+8, sy+8, "→ 选择目标编队:", 10, 255,220,80,220)
        sy = sy + 16
        local btW = math.floor((pw - 8) / maxF)
        local btX = px + 4
        for i = 1, maxF do
            if i ~= moveFrom_ then
                local capturedDst = i
                nvgBeginPath(vg); nvgRoundedRect(vg, btX, sy, btW-2, 16, 2)
                nvgFillColor(vg, nvgRGBA(60,140,60,180)); nvgFill(vg)
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(160,255,160,255))
                nvgText(vg, btX+(btW-2)/2, sy+8, i)
                addHit(btX, sy, btW-2, 16, function()
                    if onFleetMoveShip then
                        onFleetMoveShip(moveFrom_, capturedDst, moveType_)
                    end
                    moveFrom_ = nil
                    moveType_ = nil
                end)
            end
            btX = btX + btW
        end
        sy = sy + 18
    end

    -- ---- 储备池 ----
    sy = sy + 4
    nvgBeginPath(vg)
    nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, nvgRGBA(60,120,200,80))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 8

    local resClr = explorerColonizeMode and {120,255,160} or {80,180,255}
    text(px+pw/2, sy+8, "── 可加入舰船 ──", 10,
        resClr[1], resClr[2], resClr[3], 200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = sy + 16

    if #reserveList == 0 then
        text(px+pw/2, sy+RES_ROW_H/2, "暂无储备舰船", 10,
            130,150,180,160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    else
        for _, entry in ipairs(reserveList) do
            local st = SHIP_TYPES[entry.shipType]
            if st then
                local isExplorer = (entry.shipType == "EXPLORER")
                local c = FLEET_SHIP_COLORS[entry.shipType] or st.color or {180,200,255}
                nvgBeginPath(vg)
                nvgCircle(vg, px+14, sy+RES_ROW_H/2, 4)
                nvgFillColor(vg, nvgRGBA(c[1],c[2],c[3],200))
                nvgFill(vg)
                text(px+24, sy+RES_ROW_H/2, st.name .. " ×" .. entry.count,
                    10, 200,220,255,230, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)

                local btnH = 16
                if isExplorer then
                    local btn2W   = 36
                    local gap     = 3
                    local btnColX = px + pw - (btn2W * 2 + gap) - 6
                    local btnColY = sy + (RES_ROW_H - btnH) / 2
                    nvgBeginPath(vg); nvgRoundedRect(vg, btnColX, btnColY, btn2W, btnH, 3)
                    nvgFillColor(vg, nvgRGBA(30,180,80, explorerColonizeMode and 240 or 180))
                    nvgFill(vg)
                    text(btnColX+btn2W/2, sy+RES_ROW_H/2, "探索", 9,
                        180,255,200,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(btnColX, btnColY, btn2W, btnH, function()
                        if onExplorerColonize then onExplorerColonize() end
                    end)
                    local btnFltX = btnColX + btn2W + gap
                    nvgBeginPath(vg); nvgRoundedRect(vg, btnFltX, btnColY, btn2W, btnH, 3)
                    nvgFillColor(vg, nvgRGBA(40,120,220,200)); nvgFill(vg)
                    text(btnFltX+btn2W/2, sy+RES_ROW_H/2, "+队", 9,
                        200,230,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capturedTypeEx = entry.shipType
                    addHit(btnFltX, btnColY, btn2W, btnH, function()
                        if onAssignReserve then onAssignReserve(capturedTypeEx) end
                    end)
                else
                    local bw2  = 42
                    local bx   = px + pw - bw2 - 6
                    local by   = sy + (RES_ROW_H - btnH) / 2
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw2, btnH, 3)
                    nvgFillColor(vg, nvgRGBA(40,120,220,200)); nvgFill(vg)
                    text(bx+bw2/2, sy+RES_ROW_H/2, "+编队", 9,
                        200,230,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capturedType = entry.shipType
                    addHit(bx, by, bw2, btnH, function()
                        if onAssignReserve then onAssignReserve(capturedType) end
                    end)
                end
                sy = sy + RES_ROW_H
            end
        end
    end

    -- ---- 科技加成区（可折叠）----
    if baseBonus ~= nil then
        sy = sy + 4
        -- 分隔线
        nvgBeginPath(vg)
        nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, nvgRGBA(100,80,200,80))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        sy = sy + 8

        -- 标题行（可点击展开/折叠）
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160,120,255,220))
        nvgText(vg, px+10, sy+6, bonusCollapsed_ and "▶ 科技加成" or "▼ 科技加成")
        -- 右侧提示：有加成时显示数量
        if #bonusRows > 0 then
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180,140,255,180))
            nvgText(vg, px+pw-8, sy+6, #bonusRows .. " 项活跃")
        end
        addHit(px, sy, pw, 14, function()
            bonusCollapsed_ = not bonusCollapsed_
        end)
        sy = sy + 14

        -- 展开态：渲染每一行加成
        if not bonusCollapsed_ then
            if #bonusRows == 0 then
                nvgFontFace(vg, "sans")
                nvgFontSize(vg, 9)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120,100,180,140))
                nvgText(vg, px+pw/2, sy+7, "暂无科技加成（研究科技后显示）")
                sy = sy + 14
            else
                for _, row in ipairs(bonusRows) do
                    -- 左侧彩色竖条
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, px+8, sy+2, 3, BONUS_ROW_H-4, 1)
                    nvgFillColor(vg, nvgRGBA(row.cr, row.cg, row.cb, 200))
                    nvgFill(vg)
                    -- 标签
                    nvgFontFace(vg, "sans")
                    nvgFontSize(vg, 9)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(row.cr, row.cg, row.cb, 200))
                    nvgText(vg, px+16, sy+BONUS_ROW_H/2, row.label)
                    -- 数值（右对齐，亮色）
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(row.cr, row.cg, row.cb, 240))
                    nvgText(vg, px+pw-8, sy+BONUS_ROW_H/2, row.val)
                    sy = sy + BONUS_ROW_H
                end
            end
        end
    end
end

return FleetPanel
