--- 编队管理面板模块
--- 负责渲染编队 tab、舰船列表、储备池、移动模式

local UICommon   = require("game.ui.UICommon")
local Systems    = require("game.Systems")
local Commander  = require("game.CommanderSystem")  -- P1-3 V2.4
local SHIP_MODULES       = Systems.SHIP_MODULES
local SHIP_MODULES_BY_CAT = Systems.SHIP_MODULES_BY_CAT
local MODULE_CAT         = Systems.MODULE_CAT

local FleetPanel = {}

-- 舰船类型颜色映射（用于折叠态圆点摘要）
local FLEET_SHIP_COLORS = {
    SCOUT         = {100,200,255},
    FRIGATE       = {80,160,255},
    DESTROYER     = {40,100,220},
    BATTLECRUISER = {160,80,255},
    CARRIER       = {200,150,255},
    INTERCEPTOR   = {255,220,80},
    ENGINEER      = {255,200,80},
    EXPLORER      = {120,255,160},
}

-- 面板私有状态
local collapsed_      = false
local activeId_       = 1       -- 当前选中编队 id
local mapSelectedId_  = nil     -- 地图选中编队 id
local moveFrom_       = nil     -- 移动源编队 id
local moveType_       = nil     -- 待移动舰船类型
local bonusCollapsed_ = true    -- 科技加成区折叠状态
-- P2-1: 驻守星球选择器展开状态（按编队 id 记录）
local garrisonOpen_   = {}      -- {[fleetId]=true/false}
-- P1-1: 改装系统状态
local modifyShipType_ = nil     -- 当前正在改装的舰船类型 (nil=未打开)
local modifyCat_      = "attack" -- 当前选中的模块分类标签
-- P3-2: 编组预设（3 个槽，每槽 nil 或 {label, ships=[{shipType,count}]}）
local presets_        = {nil, nil, nil}
local PRESET_SLOT_N   = 3

-- P2-2a: 舰队命名系统
local namingActive_   = false    -- 命名面板是否打开
local namingFleetId_  = nil      -- 正在命名的编队 id
local namingText_     = ""       -- 当前输入文本
local namePressStart_ = 0        -- 长按计时起始
local namePressInside_= false    -- 鼠标是否在名称区域内按住
local LONG_PRESS_T    = 0.5      -- 长按阈值（秒）
local NAME_MAX_LEN    = 8        -- 最大字符数

-- P2-3: 蓝图面板状态
local bpListOpen_     = false    -- 蓝图列表是否展开
local bpConfirmDel_   = nil      -- 待确认删除的蓝图索引 (nil=不显示)
local bpToastMsg_     = nil      -- 操作反馈消息
local bpToastEnd_     = 0        -- toast 消失的 os.clock 时间点

-- P2-2a: 30 个预设随机舰队名
local FLEET_NAME_POOL = {
    "利刃中队", "暴风编队", "幽灵小队", "铁壁舰群",
    "雷霆战队", "黑鹰突击", "星火纵队", "猎鹰中队",
    "银翼编队", "暗影小队", "赤焰舰群", "极光战队",
    "苍狼突击", "寒冰纵队", "烈焰中队", "龙吟编队",
    "凤凰小队", "天罡舰群", "破晓战队", "暮光突击",
    "星陨纵队", "霜刃中队", "怒涛编队", "鬼面小队",
    "血翼舰群", "流星战队", "黑洞突击", "裂空纵队",
    "冥王中队", "深渊编队",
}

-- P2-2a: 从名称池随机选取一个名字
local function randomFleetName()
    return FLEET_NAME_POOL[math.random(1, #FLEET_NAME_POOL)]
end

-- P2-2a: 打开命名面板
local function openNaming(fleetId)
    local fm = UICommon.fm
    if not fm or not fm.fleets[fleetId] then return end
    namingActive_  = true
    namingFleetId_ = fleetId
    namingText_    = fm.fleets[fleetId].name or ""
end

-- P2-2a: 关闭命名面板
local function closeNaming()
    namingActive_  = false
    namingFleetId_ = nil
    namingText_    = ""
end

-- P2-2a: 确认命名
local function confirmNaming()
    local fm = UICommon.fm
    if fm and namingFleetId_ and fm.fleets[namingFleetId_] then
        local name = namingText_
        if #name == 0 then name = "第 " .. namingFleetId_ .. " 编队" end
        fm.fleets[namingFleetId_].name = name
    end
    closeNaming()
end

-- P2-2a: TextInput 事件处理（接收字符输入）
function FleetPanel.OnTextInput(text)
    if not namingActive_ then return end
    -- UTF-8 字符计数
    local charCount = utf8.len(namingText_) or 0
    local newCharCount = utf8.len(text) or 0
    if charCount + newCharCount <= NAME_MAX_LEN then
        namingText_ = namingText_ .. text
    end
end

-- P2-2a: 退格键处理
function FleetPanel.OnBackspace()
    if not namingActive_ then return end
    if #namingText_ > 0 then
        -- 移除最后一个 UTF-8 字符
        local bytes = {utf8.codepoint(namingText_, 1, #namingText_)}
        if #bytes > 0 then
            table.remove(bytes, #bytes)
            local parts = {}
            for _, cp in ipairs(bytes) do
                parts[#parts+1] = utf8.char(cp)
            end
            namingText_ = table.concat(parts)
        end
    end
end

-- P2-2a: 回车确认
function FleetPanel.OnEnter()
    if not namingActive_ then return end
    confirmNaming()
end

-- P2-2a: 命名面板是否激活（供外部判断是否拦截输入）
function FleetPanel.IsNaming() return namingActive_ end

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

-- P3-2: 保存当前编队到预设槽
local function saveToPreset(slotIdx, fm, fleetId)
    local fleet = fm and fm.fleets and fm.fleets[fleetId]
    if not fleet then return end
    local snap = {}
    for _, e in ipairs(fleet.ships) do
        snap[#snap+1] = { shipType = e.shipType, count = e.count }
    end
    local label = "编队" .. fleetId .. " 预设" .. slotIdx
    presets_[slotIdx] = { label = label, ships = snap }
end

-- P3-2: 从预设槽补充舰船到当前编队（非破坏性：仅从储备池添加缺少的舰船）
local function applyPreset(slotIdx, fm, fleetId)
    local preset = presets_[slotIdx]
    if not preset or not fm then return end
    local fleet = fm.fleets[fleetId]
    if not fleet then return end
    -- 建立当前编队的舰船类型映射
    local haveMap = {}
    for _, e in ipairs(fleet.ships) do haveMap[e.shipType] = e.count end
    -- 按预设补充缺少的舰船（从储备池拉取）
    for _, entry in ipairs(preset.ships) do
        local have = haveMap[entry.shipType] or 0
        local need = entry.count - have
        if need > 0 then
            for _ = 1, need do
                fm:assignFromReserve(entry.shipType, fleetId)
            end
        end
    end
end

--- 渲染编队面板
---@param ctx table  {fm, explorerColonizeMode,
---                   onFleetSelect, onFleetMoveShip,
---                   onExplorerColonize, onAssignReserve,
---                   techPanelH, baseBonus,
---                   onExplorerTask, explorerTasks,
---                   garrisonedPlanet, colonizedPlanets,
---                   onGarrisonFleet, onRecallGarrison}
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
    local onExplorerTask       = ctx.onExplorerTask
    local explorerTasks        = ctx.explorerTasks or {}
    -- P2-1: 驻守系统
    local garrisonedPlanet     = ctx.garrisonedPlanet   -- 当前编队驻守的星球，nil=未驻守
    local colonizedPlanets     = ctx.colonizedPlanets or {}
    local onGarrisonFleet      = ctx.onGarrisonFleet
    local onRecallGarrison     = ctx.onRecallGarrison
    -- P1-2: 远征
    local expeditions          = ctx.expeditions or {}
    local pirateBases          = ctx.pirateBases or {}
    local onLaunchExpedition   = ctx.onLaunchExpedition
    local lastExpedition       = ctx.lastExpedition or {}  -- P3-3.1

    local pw_full = math.min(UICommon.FLEET_PANEL_W or 248, math.floor(screenW * 0.45))
    local py      = UICommon.PANEL_TOP or 48
    -- P3-x: FleetPanel 移至左上角，固定左边距 8px
    local FLEET_LEFT_MARGIN = 8
    local fleetRight = 0  -- 仅保留用于兼容，左上角模式不使用
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
        -- P3-x: 折叠 tab 贴在左上角
        local px_tab = FLEET_LEFT_MARGIN

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
    -- P3-x: 展开面板锚定左上角
    local px = FLEET_LEFT_MARGIN

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

    -- 探索任务区高度
    local TASK_ROW_H = 24
    local taskH = #explorerTasks > 0 and (14 + #explorerTasks * TASK_ROW_H + 6) or 0

    -- P3-2: 编组预设区高度（标题14 + 3行×18 + 底边距8）
    local PRESET_ROW_H = 18
    local presetH = 8 + 14 + PRESET_SLOT_N * PRESET_ROW_H + 4

    -- P2-1: 驻守区高度（分隔线8 + 标题行20 + 可选展开列表）
    local GARRISON_ROW_H = 20
    local isGarrisonOpen = garrisonOpen_[activeId_] or false
    local garrisonListH  = isGarrisonOpen and (math.max(1, #colonizedPlanets) * 18 + 4) or 0
    local garrisonH      = 8 + GARRISON_ROW_H + garrisonListH

    -- P1-3 V2.4: 指挥官区高度（分隔线8 + 头像直径20 + 底边距8 = 36，无指挥官则0）
    local cmdOfficerH = Commander.GetByFleet(activeId_) and 36 or 0

    local ph = 16 + 18
             + TAB_H + 6
             + 18
             + (shipRows > 0 and (shipRows * ROW_H) or 20)
             + (moveFrom_ and 38 or 0)
             + 12
             + 16
             + math.max(1, #reserveList) * RES_ROW_H
             + 12
             + garrisonH
             + bonusH
             + taskH
             + presetH
             + cmdOfficerH

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
    -- P2-2a: 编辑按钮（✏️ 图标，点击打开命名）
    local editBtnX = px + 8
    -- 计算名称文本宽度来定位编辑按钮
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
    local nameW = nvgTextBounds(vg, 0, 0, curFleet.name)
    editBtnX = px + 8 + nameW + 6
    nvgFillColor(vg, nvgRGBA(100,160,255,160))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(vg, editBtnX, sy+8, "✎")
    addHit(editBtnX - 4, sy, 18, 18, function()
        openNaming(activeId_)
    end)
    -- P2-2a: 长按名称区域也可触发命名
    local nameHitX, nameHitY, nameHitW, nameHitH = px+4, sy, nameW+12, 18
    if input:GetMouseButtonDown(MOUSEB_LEFT) then
        local dpr = graphics:GetDPR()
        local mx = input.mousePosition.x / dpr
        local my = input.mousePosition.y / dpr
        if mx >= nameHitX and mx <= nameHitX + nameHitW
           and my >= nameHitY and my <= nameHitY + nameHitH then
            if not namePressInside_ then
                namePressInside_ = true
                namePressStart_  = os.clock()
            elseif os.clock() - namePressStart_ >= LONG_PRESS_T then
                namePressInside_ = false
                openNaming(activeId_)
            end
        else
            namePressInside_ = false
        end
    else
        namePressInside_ = false
    end
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
                -- 已装备模块图标（显示在舰船名称后）
                local equippedKey = curFleet.modules and curFleet.modules[entry.shipType]
                local nameStr = st.name .. " ×" .. entry.count
                if equippedKey and SHIP_MODULES[equippedKey] then
                    nameStr = nameStr .. " " .. SHIP_MODULES[equippedKey].icon
                end
                -- P1-2 V2.5: 变异舰船标记（⚡前缀 + 词缀图标）
                local mutantData = curFleet.mutants and curFleet.mutants[entry.shipType]
                local isMutant = mutantData and mutantData.affixes and #mutantData.affixes > 0
                if isMutant then
                    local affixIcons = ""
                    local MutSys = require("game.MutantShipSystem")
                    for _, aKey in ipairs(mutantData.affixes) do
                        local adef = MutSys.GetAffix(aKey)
                        if adef then affixIcons = affixIcons .. adef.icon end
                    end
                    nameStr = "⚡" .. nameStr .. " " .. affixIcons
                end
                local nameR, nameG, nameB = 180, 210, 255
                if isMutant then nameR, nameG, nameB = 255, 200, 80 end
                text(px+24, sy+ROW_H/2, nameStr,
                    10, nameR,nameG,nameB,220, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)

                -- "改装" 按钮
                local mx = px + pw - 74
                local isModifying = (modifyShipType_ == entry.shipType)
                nvgBeginPath(vg); nvgRoundedRect(vg, mx, sy+2, 30, ROW_H-4, 2)
                nvgFillColor(vg, nvgRGBA(
                    isModifying and 180 or 120,
                    isModifying and 120 or 80,
                    isModifying and 40  or 180,
                    isModifying and 200 or 140))
                nvgFill(vg)
                text(mx+15, sy+ROW_H/2, isModifying and "关闭" or "改装",
                    8, 255,220,160,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                local capType = entry.shipType
                addHit(mx, sy+2, 30, ROW_H-4, function()
                    if modifyShipType_ == capType then
                        modifyShipType_ = nil
                    else
                        modifyShipType_ = capType
                    end
                end)

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

    -- ---- P1-1: 改装面板（选中某舰船类型时展开） ----
    if modifyShipType_ and curFleet then
        sy = sy + 4
        nvgBeginPath(vg)
        nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, nvgRGBA(180,120,40,120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        sy = sy + 6

        -- 标题行：残骸零件余额
        local salvage = fm.salvageParts or 0
        text(px+8, sy+7, "改装: " .. (SHIP_TYPES[modifyShipType_] and SHIP_TYPES[modifyShipType_].name or modifyShipType_),
            9, 255,200,100,230)
        text(px+pw-8, sy+7, "零件:" .. salvage,
            9, 200,180,120,200, NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
        sy = sy + 16

        -- 当前已装备模块
        local eqKey = curFleet.modules and curFleet.modules[modifyShipType_]
        if eqKey and SHIP_MODULES[eqKey] then
            local m = SHIP_MODULES[eqKey]
            nvgBeginPath(vg); nvgRoundedRect(vg, px+6, sy, pw-12, 20, 3)
            nvgFillColor(vg, nvgRGBA(60,80,40,140)); nvgFill(vg)
            text(px+12, sy+10, m.icon .. " " .. m.name .. " (已装备)",
                9, 180,255,120,230, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
            -- 卸下按钮
            local ubx = px + pw - 42
            nvgBeginPath(vg); nvgRoundedRect(vg, ubx, sy+3, 34, 14, 2)
            nvgFillColor(vg, nvgRGBA(180,60,60,180)); nvgFill(vg)
            text(ubx+17, sy+10, "卸下", 8, 255,200,200,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            addHit(ubx, sy+3, 34, 14, function()
                fm:unequipModule(activeId_, modifyShipType_)
            end)
            sy = sy + 22
        else
            text(px+12, sy+7, "未装备模块", 9, 130,150,180,160)
            sy = sy + 16
        end

        -- 分类标签 (攻击/防御/辅助)
        local cats = {
            { key = "attack",  label = "攻击", clr = {255,100,80}  },
            { key = "defense", label = "防御", clr = {80,200,255}  },
            { key = "utility", label = "辅助", clr = {180,255,80}  },
        }
        local catW = math.floor((pw - 16) / 3)
        local catX = px + 8
        for _, cat in ipairs(cats) do
            local isActive = (modifyCat_ == cat.key)
            nvgBeginPath(vg); nvgRoundedRect(vg, catX, sy, catW-2, 14, 2)
            nvgFillColor(vg, nvgRGBA(
                cat.clr[1], cat.clr[2], cat.clr[3],
                isActive and 180 or 60))
            nvgFill(vg)
            text(catX + (catW-2)/2, sy+7, cat.label,
                8, 255,255,255, isActive and 255 or 140,
                NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            local capCat = cat.key
            addHit(catX, sy, catW-2, 14, function()
                modifyCat_ = capCat
            end)
            catX = catX + catW
        end
        sy = sy + 18

        -- 模块列表（当前分类）
        local modKeys = SHIP_MODULES_BY_CAT[modifyCat_] or {}
        for _, mKey in ipairs(modKeys) do
            local m = SHIP_MODULES[mKey]
            if m then
                local owned = fm.moduleInventory and fm.moduleInventory[mKey] or 0
                local isEquipped = (eqKey == mKey)
                local canEquip = (owned > 0 or isEquipped) and (not isEquipped)
                local cost = isEquipped and 0 or (eqKey and m.replaceCost or m.cost)

                -- 模块行背景
                nvgBeginPath(vg); nvgRoundedRect(vg, px+6, sy, pw-12, 28, 3)
                nvgFillColor(vg, nvgRGBA(30,40,60, isEquipped and 180 or 100))
                nvgFill(vg)

                -- 图标 + 名称
                text(px+12, sy+9, m.icon .. " " .. m.name,
                    9, 220,230,255, isEquipped and 255 or 200,
                    NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
                -- 效果描述 + 拥有数量
                local effDesc = ""
                local eff = m.effect
                if eff.type == "pierceShield" then effDesc = "穿盾" .. math.floor(eff.value*100) .. "%"
                elseif eff.type == "shotRateMult" then effDesc = "射速×" .. eff.value
                elseif eff.type == "burn" then effDesc = "灼烧" .. math.floor(eff.dps*100) .. "%/s"
                elseif eff.type == "dmgUp" then effDesc = "伤害×" .. eff.dmgMult
                elseif eff.type == "pulseOverload" then effDesc = "每" .. eff.interval .. "s×" .. eff.mult
                elseif eff.type == "hpMult" then effDesc = "血量×" .. eff.value
                elseif eff.type == "shield" then effDesc = "护盾" .. math.floor(eff.value*100) .. "%"
                elseif eff.type == "emergencyHeal" then effDesc = "低血回复"
                elseif eff.type == "reflect" then effDesc = "反伤" .. math.floor(eff.chance*100) .. "%"
                elseif eff.type == "stealth" then effDesc = "隐匿" .. eff.duration .. "s"
                elseif eff.type == "allyDmgAura" then effDesc = "友方+" .. math.floor(eff.value*100) .. "%"
                elseif eff.type == "markEnemy" then effDesc = "标记+" .. math.floor(eff.value*100) .. "%"
                elseif eff.type == "slow" then effDesc = "减速" .. math.floor(eff.value*100) .. "%"
                elseif eff.type == "speedMult" then effDesc = "速度×" .. eff.value
                elseif eff.type == "killHeal" then effDesc = "击杀回血" .. math.floor(eff.value*100) .. "%"
                end
                text(px+12, sy+20, effDesc .. "  拥有:" .. owned,
                    8, 160,180,200,160, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)

                -- 装备按钮
                if canEquip and salvage >= cost then
                    local ebx = px + pw - 50
                    nvgBeginPath(vg); nvgRoundedRect(vg, ebx, sy+6, 42, 16, 2)
                    nvgFillColor(vg, nvgRGBA(40,160,80,200)); nvgFill(vg)
                    local btnLabel = eqKey and ("换" .. cost .. "件") or (cost .. "件装")
                    text(ebx+21, sy+14, btnLabel,
                        8, 200,255,200,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capMKey = mKey
                    addHit(ebx, sy+6, 42, 16, function()
                        fm:equipModule(activeId_, modifyShipType_, capMKey)
                    end)
                elseif isEquipped then
                    text(px+pw-14, sy+14, "✓",
                        10, 120,255,120,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                end

                sy = sy + 30
            end
        end
        sy = sy + 4
    end

    -- ---- P1-3 V2.4: 指挥官信息 ----
    local cmdOfficer = Commander.GetByFleet(activeId_)
    if cmdOfficer then
        sy = sy + 2
        nvgBeginPath(vg)
        nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, nvgRGBA(180,120,255,80))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        sy = sy + 6

        -- 指挥官头像占位（紫色圆形）
        local avatarR = 10
        nvgBeginPath(vg)
        nvgCircle(vg, px + 18, sy + avatarR, avatarR)
        nvgFillColor(vg, nvgRGBA(120, 60, 200, 180))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 120, 255, 200))
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        -- 等级数字
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 255, 255))
        nvgText(vg, px + 18, sy + avatarR, tostring(cmdOfficer.level))

        -- 名称 + 专精
        local specLabel = ""
        if cmdOfficer.spec then
            local specDef = Systems.COMMANDER_SPECS[cmdOfficer.spec]
            specLabel = specDef and (" [" .. specDef.name .. "]") or ""
        end
        text(px + 32, sy + 6, cmdOfficer.name .. specLabel,
            9, 200, 180, 255, 230, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        -- 经验条
        local expTable = Systems.COMMANDER_EXP_TABLE
        local maxLv = Systems.COMMANDER_MAX_LEVEL
        local expForNext = (cmdOfficer.level < maxLv) and expTable[cmdOfficer.level + 1] or 0
        local expPct = (expForNext > 0) and math.min(1, cmdOfficer.exp / expForNext) or 1.0
        local barX, barY, barW, barH = px + 32, sy + 12, pw - 48, 4
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 2)
        nvgFillColor(vg, nvgRGBA(30, 20, 50, 180)); nvgFill(vg)
        if expPct > 0 then
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * expPct, barH, 2)
            nvgFillColor(vg, nvgRGBA(180, 100, 255, 220)); nvgFill(vg)
        end

        -- 技能冷却提示
        local skillCd = Commander.GetSkillCooldown(activeId_)
        if skillCd and skillCd > 0 then
            text(px + 32, sy + 20, string.format("Q技能 冷却%.0fs", skillCd),
                8, 180, 140, 200, 160, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        else
            text(px + 32, sy + 20, "Q技能 就绪",
                8, 120, 255, 160, 200, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        end

        sy = sy + avatarR * 2 + 8
    end

    -- ---- P2-1 V2.5: 阵型编辑器入口 ----
    do
        sy = sy + 4
        nvgBeginPath(vg)
        nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, nvgRGBA(80,200,180,80))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        sy = sy + 6

        local LeagueSys = require("game.LeagueSystem")
        local rank = LeagueSys.GetRank()
        -- 解锁条件：白银段位以上
        local unlocked = rank and (rank.id == "silver" or rank.id == "gold" or rank.id == "platinum" or rank.id == "diamond")
        local FEditor = require("game.ui.FormationEditor")
        local hasSaved = FEditor.HasSaved()

        local btnW3 = pw - 16
        local btnH3 = 20
        nvgBeginPath(vg); nvgRoundedRect(vg, px+8, sy, btnW3, btnH3, 3)
        if unlocked then
            nvgFillColor(vg, nvgRGBA(30, 100, 120, 200))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 200, 180, 160))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            local btnLabel = "⚔ 阵型编辑器" .. (hasSaved and " ✓" or "")
            text(px+8+btnW3/2, sy+btnH3/2, btnLabel, 10,
                180, 255, 220, 240, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            addHit(px+8, sy, btnW3, btnH3, function()
                local ships = curFleet and curFleet.ships or nil
                FEditor.Open(ships)
            end)
        else
            nvgFillColor(vg, nvgRGBA(40, 50, 60, 140))
            nvgFill(vg)
            text(px+8+btnW3/2, sy+btnH3/2, "🔒 阵型编辑器 (白银解锁)", 9,
                120, 140, 160, 160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        end
        sy = sy + btnH3 + 4

        -- ---- P2-3 V2.5: 战术蓝图 保存/加载 ----
        if unlocked then
            local BPSys = require("game.BlueprintSystem")
            local bpCount = BPSys.Count()
            local canSave = BPSys.CanSave()

            -- Toast 消息渲染（基于 os.clock 判断存活）
            local bpRemain = bpToastEnd_ - os.clock()
            if bpToastMsg_ and bpRemain > 0 then
                local tAlpha = math.min(1, bpRemain * 4) * 220
                text(px + pw/2, sy + 6, bpToastMsg_, 9,
                    180, 255, 200, tAlpha, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                sy = sy + 14
            end

            -- 两个半宽按钮：保存 / 列表
            local halfW = math.floor((pw - 20) / 2)
            local btnH4 = 18

            -- [保存蓝图] 按钮
            nvgBeginPath(vg); nvgRoundedRect(vg, px+8, sy, halfW, btnH4, 3)
            if canSave then
                nvgFillColor(vg, nvgRGBA(30, 80, 130, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 160, 255, 140))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                text(px+8+halfW/2, sy+btnH4/2, "📋 保存蓝图", 9,
                    160, 220, 255, 240, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+8, sy, halfW, btnH4, function()
                    local fm = UICommon.fm
                    if not fm then return end
                    local formSlot = nil
                    local fSlots = FEditor.GetSlots()
                    local firstSaved = FEditor.GetFirstSavedSlot()
                    if firstSaved then formSlot = fSlots[firstSaved] end
                    -- 指挥官
                    local cmd = Commander.GetByFleet(activeId_)
                    local cmdId = cmd and cmd.id or nil
                    -- 自动命名
                    local bpName = "蓝图 " .. (bpCount + 1)
                    local ok, msg = BPSys.SaveCurrent(bpName, fm, formSlot, cmdId)
                    bpToastMsg_   = msg
                    bpToastEnd_   = os.clock() + 2.0
                end)
            else
                nvgFillColor(vg, nvgRGBA(40, 50, 60, 140)); nvgFill(vg)
                text(px+8+halfW/2, sy+btnH4/2, "📋 已满(" .. bpCount .. "/" .. BPSys.GetMaxSlots() .. ")", 8,
                    120, 140, 160, 160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            end

            -- [蓝图列表] 按钮
            local lx = px + 12 + halfW
            nvgBeginPath(vg); nvgRoundedRect(vg, lx, sy, halfW, btnH4, 3)
            if bpCount > 0 then
                local listBg = bpListOpen_ and nvgRGBA(60, 120, 80, 200) or nvgRGBA(30, 100, 80, 200)
                nvgFillColor(vg, listBg); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 200, 160, 140))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                local listLabel = bpListOpen_ and "▼ 收起列表" or ("📂 蓝图(" .. bpCount .. ")")
                text(lx+halfW/2, sy+btnH4/2, listLabel, 9,
                    160, 255, 200, 240, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(lx, sy, halfW, btnH4, function()
                    bpListOpen_ = not bpListOpen_
                    bpConfirmDel_ = nil
                end)
            else
                nvgFillColor(vg, nvgRGBA(40, 50, 60, 140)); nvgFill(vg)
                text(lx+halfW/2, sy+btnH4/2, "📂 无蓝图", 8,
                    120, 140, 160, 160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            end
            sy = sy + btnH4 + 4

            -- ---- 蓝图列表展开 ----
            if bpListOpen_ and bpCount > 0 then
                local allBP = BPSys.GetAll()
                for bi = 1, #allBP do
                    local bp = allBP[bi]
                    local rowH = 22
                    -- 蓝图行背景
                    nvgBeginPath(vg); nvgRoundedRect(vg, px+10, sy, pw-20, rowH, 2)
                    nvgFillColor(vg, nvgRGBA(25, 45, 65, 180)); nvgFill(vg)

                    -- 蓝图名称 + 编队数
                    local fleetN = bp.fleets and #bp.fleets or 0
                    local info = bp.name .. "  (" .. fleetN .. "队)"
                    text(px+14, sy+rowH/2, info, 8,
                        180, 220, 255, 220, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)

                    -- [应用] 按钮
                    local applyW = 28
                    local applyX = px + pw - 10 - applyW - 2 - 20  -- 留出删除按钮空间
                    nvgBeginPath(vg); nvgRoundedRect(vg, applyX, sy+3, applyW, rowH-6, 2)
                    nvgFillColor(vg, nvgRGBA(40, 120, 80, 200)); nvgFill(vg)
                    text(applyX+applyW/2, sy+rowH/2, "应用", 8,
                        180, 255, 200, 240, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capturedBi = bi
                    addHit(applyX, sy+3, applyW, rowH-6, function()
                        local fm = UICommon.fm
                        if not fm then return end
                        local ok, msg = BPSys.Apply(capturedBi, fm)
                        bpToastMsg_   = msg
                        bpToastEnd_   = os.clock() + 2.5
                        bpListOpen_   = false
                    end)

                    -- [删除] 按钮
                    local delX = px + pw - 10 - 18
                    nvgBeginPath(vg); nvgRoundedRect(vg, delX, sy+3, 16, rowH-6, 2)
                    if bpConfirmDel_ == bi then
                        nvgFillColor(vg, nvgRGBA(180, 40, 40, 220)); nvgFill(vg)
                        text(delX+8, sy+rowH/2, "✓", 8,
                            255, 200, 200, 255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                        addHit(delX, sy+3, 16, rowH-6, function()
                            BPSys.Delete(capturedBi)
                            bpConfirmDel_ = nil
                            bpToastMsg_   = "🗑 蓝图已删除"
                            bpToastEnd_   = os.clock() + 1.5
                            if BPSys.Count() == 0 then bpListOpen_ = false end
                        end)
                    else
                        nvgFillColor(vg, nvgRGBA(100, 40, 40, 180)); nvgFill(vg)
                        text(delX+8, sy+rowH/2, "×", 9,
                            255, 140, 140, 200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                        addHit(delX, sy+3, 16, rowH-6, function()
                            bpConfirmDel_ = capturedBi
                        end)
                    end

                    sy = sy + rowH + 2
                end
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
                    -- 三按钮：[殖民] [任务] [+队]
                    local btn3W   = 30
                    local gap     = 2
                    local totalBtnW = btn3W * 3 + gap * 2
                    local btn1X   = px + pw - totalBtnW - 6
                    local btn2X   = btn1X + btn3W + gap
                    local btn3X   = btn2X + btn3W + gap
                    local btnY    = sy + (RES_ROW_H - btnH) / 2

                    -- 殖民按钮（绿色）
                    nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btn3W, btnH, 3)
                    nvgFillColor(vg, nvgRGBA(30,180,80, explorerColonizeMode and 240 or 160))
                    nvgFill(vg)
                    text(btn1X+btn3W/2, sy+RES_ROW_H/2, "殖民", 8,
                        180,255,200,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(btn1X, btnY, btn3W, btnH, function()
                        if onExplorerColonize then onExplorerColonize() end
                    end)

                    -- 任务按钮（橙色）
                    nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btn3W, btnH, 3)
                    nvgFillColor(vg, nvgRGBA(200,120,30, onExplorerTask and 200 or 80))
                    nvgFill(vg)
                    text(btn2X+btn3W/2, sy+RES_ROW_H/2, "任务", 8,
                        255,210,120,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(btn2X, btnY, btn3W, btnH, function()
                        if onExplorerTask then onExplorerTask() end
                    end)

                    -- +队按钮（蓝色）
                    nvgBeginPath(vg); nvgRoundedRect(vg, btn3X, btnY, btn3W, btnH, 3)
                    nvgFillColor(vg, nvgRGBA(40,120,220,200)); nvgFill(vg)
                    text(btn3X+btn3W/2, sy+RES_ROW_H/2, "+队", 8,
                        200,230,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capturedTypeEx = entry.shipType
                    addHit(btn3X, btnY, btn3W, btnH, function()
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

    -- ---- P2-1: 舰队驻守区 ----
    sy = sy + 4
    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, nvgRGBA(60, 200, 140, 80))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 8

    -- 驻守状态行（左：状态文字，右：[驻守]/[召回] 按钮）
    local garrisonBtnW = 38
    local garrisonBtnH = 16
    local garrisonBtnY = sy + (GARRISON_ROW_H - garrisonBtnH) / 2

    -- 状态文字
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    if garrisonedPlanet then
        nvgFillColor(vg, nvgRGBA(80, 220, 150, 240))
        nvgText(vg, px+10, sy+GARRISON_ROW_H/2,
            "🏴 驻守: " .. (garrisonedPlanet.name or "?"))
    else
        nvgFillColor(vg, nvgRGBA(130, 160, 200, 180))
        nvgText(vg, px+10, sy+GARRISON_ROW_H/2, "⚑ 驻守星球: 未驻守")
    end

    -- 召回按钮（仅驻守时显示）
    if garrisonedPlanet then
        local recBtnX = px + pw - garrisonBtnW - 6
        nvgBeginPath(vg); nvgRoundedRect(vg, recBtnX, garrisonBtnY, garrisonBtnW, garrisonBtnH, 3)
        nvgFillColor(vg, nvgRGBA(180, 60, 60, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 100, 100, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
        nvgText(vg, recBtnX + garrisonBtnW/2, sy+GARRISON_ROW_H/2, "召回")
        local capturedFleetId = activeId_
        addHit(recBtnX, garrisonBtnY, garrisonBtnW, garrisonBtnH, function()
            if onRecallGarrison then onRecallGarrison(capturedFleetId) end
            garrisonOpen_[capturedFleetId] = false
        end)
    end

    -- 驻守/选择按钮
    local garrBtnX = garrisonedPlanet
        and (px + pw - garrisonBtnW * 2 - 10)
        or  (px + pw - garrisonBtnW - 6)
    nvgBeginPath(vg); nvgRoundedRect(vg, garrBtnX, garrisonBtnY, garrisonBtnW, garrisonBtnH, 3)
    local gOpen = garrisonOpen_[activeId_] or false
    nvgFillColor(vg, gOpen
        and nvgRGBA(40, 160, 100, 220)
        or  nvgRGBA(30, 100, 180, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, gOpen
        and nvgRGBA(80, 220, 140, 200)
        or  nvgRGBA(60, 160, 255, 160))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 240, 220, 255))
    nvgText(vg, garrBtnX + garrisonBtnW/2, sy+GARRISON_ROW_H/2, gOpen and "收起" or "驻守")
    local capturedGFleetId = activeId_
    addHit(garrBtnX, garrisonBtnY, garrisonBtnW, garrisonBtnH, function()
        garrisonOpen_[capturedGFleetId] = not (garrisonOpen_[capturedGFleetId] or false)
    end)
    sy = sy + GARRISON_ROW_H

    -- 驻守星球选择列表（展开时显示）
    if isGarrisonOpen then
        if #colonizedPlanets == 0 then
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(130, 150, 180, 160))
            nvgText(vg, px+pw/2, sy+9, "暂无已殖民星球")
            sy = sy + 18
        else
            for _, planet in ipairs(colonizedPlanets) do
                local isSelected = (garrisonedPlanet == planet)
                -- 行背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+8, sy+1, pw-16, 16, 2)
                nvgFillColor(vg, isSelected
                    and nvgRGBA(30, 120, 70, 200)
                    or  nvgRGBA(20, 40, 70, 140))
                nvgFill(vg)
                if isSelected then
                    nvgStrokeColor(vg, nvgRGBA(60, 220, 120, 180))
                    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                end
                -- 星球名
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, isSelected
                    and nvgRGBA(120, 255, 160, 255)
                    or  nvgRGBA(180, 220, 255, 220))
                nvgText(vg, px+14, sy+9, planet.name or "未知")
                -- 已驻守标记
                if isSelected then
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(80, 255, 140, 240))
                    nvgText(vg, px+pw-10, sy+9, "✓ 驻守中")
                end
                -- 点击选择
                local capturedPlanet  = planet
                local capturedFleet   = activeId_
                addHit(px+8, sy+1, pw-16, 16, function()
                    if isSelected then
                        -- 再次点击 = 召回
                        if onRecallGarrison then onRecallGarrison(capturedFleet) end
                    else
                        if onGarrisonFleet then onGarrisonFleet(capturedFleet, capturedPlanet) end
                    end
                    garrisonOpen_[capturedFleet] = false
                end)
                sy = sy + 18
            end
            sy = sy + 4
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

    -- ---- 探索任务列表区 ----
    if #explorerTasks > 0 then
        sy = sy + 8
        -- 分隔线
        nvgBeginPath(vg)
        nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, nvgRGBA(255,180,60,80))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        sy = sy + 8

        -- 标题
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255,200,80,220))
        nvgText(vg, px+10, sy+6, "🛸 探索任务")
        sy = sy + 14

        for _, task in ipairs(explorerTasks) do
            local pct = math.min(1.0, task.elapsed / math.max(1, task.duration))
            local remaining = math.max(0, math.floor(task.duration - task.elapsed))
            local isDone = task.done

            -- 任务行背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, px+6, sy+2, pw-12, TASK_ROW_H-4, 3)
            nvgFillColor(vg, isDone
                and nvgRGBA(30,120,60,180)
                or  nvgRGBA(20,40,80,160))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, px+6, sy+2, pw-12, TASK_ROW_H-4, 3)
            nvgStrokeColor(vg, isDone
                and nvgRGBA(60,220,100,180)
                or  nvgRGBA(255,180,60,100))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

            -- 进度条（任务进行中显示）
            if not isDone and pct > 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+6, sy+2, math.floor((pw-12)*pct), TASK_ROW_H-4, 3)
                local grad = nvgLinearGradient(vg, px+6, sy, px+6+(pw-12)*pct, sy,
                    nvgRGBA(80,140,255,60), nvgRGBA(120,200,255,90))
                nvgFillPaint(vg, grad); nvgFill(vg)
            end

            -- 图标 + 任务名
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            local label = (task.icon or "🔍") .. " " .. (task.label or "探索中")
            nvgFillColor(vg, isDone
                and nvgRGBA(120,255,160,255)
                or  nvgRGBA(220,230,255,230))
            nvgText(vg, px+12, sy+TASK_ROW_H/2, label)

            -- 右侧：完成标记 或 剩余时间
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            if isDone then
                nvgFillColor(vg, nvgRGBA(100,255,140,255))
                nvgText(vg, px+pw-10, sy+TASK_ROW_H/2, "✓ 完成")
            else
                nvgFillColor(vg, nvgRGBA(200,200,255,180))
                nvgText(vg, px+pw-10, sy+TASK_ROW_H/2,
                    string.format("%ds", remaining))
            end

            sy = sy + TASK_ROW_H
        end
    end

    -- ---- P3-2: 编组预设区 ----
    sy = sy + 8
    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, nvgRGBA(120,80,200,80))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 8

    -- 标题行
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160,120,255,220))
    nvgText(vg, px+10, sy+6, "📋 编组预设")
    sy = sy + 14

    for slotIdx = 1, PRESET_SLOT_N do
        local preset   = presets_[slotIdx]
        local rowY     = sy
        local hasData  = preset ~= nil and #preset.ships > 0

        -- 行背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px+6, rowY+1, pw-12, PRESET_ROW_H-2, 3)
        nvgFillColor(vg, hasData
            and nvgRGBA(30, 20, 60, 160)
            or  nvgRGBA(20, 20, 40, 100))
        nvgFill(vg)
        nvgStrokeColor(vg, hasData
            and nvgRGBA(120, 80, 220, 120)
            or  nvgRGBA(60, 60, 100, 80))
        nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

        -- 槽标签 / 内容摘要
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        if hasData then
            -- 显示编队舰船组成摘要（最多3种类型）
            local parts = {}
            for i, e in ipairs(preset.ships) do
                if i > 3 then parts[#parts+1] = "..."; break end
                local abbr = e.shipType:sub(1, 3)
                parts[#parts+1] = abbr .. "×" .. e.count
            end
            nvgFillColor(vg, nvgRGBA(200, 180, 255, 230))
            nvgText(vg, px+12, rowY+PRESET_ROW_H/2,
                "预设" .. slotIdx .. ": " .. table.concat(parts, " "))
        else
            nvgFillColor(vg, nvgRGBA(100, 90, 140, 150))
            nvgText(vg, px+12, rowY+PRESET_ROW_H/2, "预设" .. slotIdx .. ": （空）")
        end

        -- [存] 按钮（右侧，始终显示）
        local saveBtnW = 22
        local loadBtnW = 30
        local btnH     = PRESET_ROW_H - 6
        local btnY     = rowY + 3
        local saveBX   = px + pw - saveBtnW - 6
        local loadBX   = saveBX - loadBtnW - 3

        -- [存] 按钮
        nvgBeginPath(vg)
        nvgRoundedRect(vg, saveBX, btnY, saveBtnW, btnH, 2)
        nvgFillColor(vg, nvgRGBA(60, 40, 140, 200))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(120, 80, 220, 180))
        nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 140, 255, 240))
        nvgText(vg, saveBX + saveBtnW/2, rowY + PRESET_ROW_H/2, "存")
        local capturedSlotSave = slotIdx
        addHit(saveBX, btnY, saveBtnW, btnH, function()
            saveToPreset(capturedSlotSave, fm, activeId_)
        end)

        -- [载入] 按钮（仅有预设数据时显示）
        if hasData then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, loadBX, btnY, loadBtnW, btnH, 2)
            nvgFillColor(vg, nvgRGBA(30, 80, 40, 200))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(60, 180, 80, 180))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 255, 140, 240))
            nvgText(vg, loadBX + loadBtnW/2, rowY + PRESET_ROW_H/2, "载入")
            local capturedSlotLoad = slotIdx
            addHit(loadBX, btnY, loadBtnW, btnH, function()
                applyPreset(capturedSlotLoad, fm, activeId_)
            end)
        end

        sy = sy + PRESET_ROW_H
    end

    -- =========================================================================
    -- P1-2: 远征区块
    -- =========================================================================
    local EXP_H = 0
    do
        local expStartY = sy + 6
        local ey = expStartY

        -- 分隔线
        nvgBeginPath(vg)
        nvgMoveTo(vg, px + 8, ey)
        nvgLineTo(vg, px + pw - 8, ey)
        nvgStrokeColor(vg, nvgRGBA(255, 160, 40, 60))
        nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
        ey = ey + 4

        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 180, 60, 220))
        nvgText(vg, px + 8, ey, "⚔ 远征")
        ey = ey + 13

        -- 显示当前编队是否正在远征
        local myExp = nil
        for _, exp in ipairs(expeditions) do
            if exp.fleetId == activeId_ then myExp = exp; break end
        end

        if myExp then
            -- 远征进度条
            local prog = math.min(1.0, myExp.elapsed / myExp.duration)
            local barW = pw - 24
            local barH = 8
            local barX = px + 12
            -- 背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, ey, barW, barH, 3)
            nvgFillColor(vg, nvgRGBA(40, 30, 20, 180))
            nvgFill(vg)
            -- 填充
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, ey, barW * prog, barH, 3)
            nvgFillColor(vg, nvgRGBA(255, 140, 30, 220))
            nvgFill(vg)
            ey = ey + barH + 3
            -- 文字
            local remain = math.max(0, myExp.duration - myExp.elapsed)
            nvgFontSize(vg, 8); nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
            nvgText(vg, px + 12, ey, string.format("远征Lv%d 剩余%.0fs", myExp.baseLevel, remain))
            ey = ey + 11
        else
            -- P3-3.1: 重复远征按钮（记忆上次目标）
            local lastBaseId = lastExpedition[activeId_]
            if lastBaseId and onLaunchExpedition then
                -- 验证目标基地仍然存活
                local lastBase = nil
                for _, b in ipairs(pirateBases) do
                    if b.id == lastBaseId then lastBase = b; break end
                end
                if lastBase then
                    local rbX = px + 10
                    local rbW = pw - 20
                    local rbH = 14
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, rbX, ey, rbW, rbH, 3)
                    nvgFillColor(vg, nvgRGBA(30, 80, 60, 200))
                    nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(80, 255, 140, 180))
                    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    nvgFontSize(vg, 8)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(140, 255, 180, 255))
                    nvgText(vg, rbX + rbW/2, ey + rbH/2,
                        string.format("🔁 重复远征 Lv%d", lastBase.level))
                    local capId = lastBaseId
                    addHit(rbX, ey, rbW, rbH, function()
                        onLaunchExpedition(activeId_, capId)
                    end)
                    ey = ey + rbH + 3
                end
            end
            -- 未在远征 → 显示"发起远征"按钮（需要有可攻击的海盗基地）
            if #pirateBases > 0 and onLaunchExpedition then
                -- 按钮列表（最多显示3个最近基地）
                local showCount = math.min(3, #pirateBases)
                for bi = 1, showCount do
                    local base = pirateBases[bi]
                    local expBtnX = px + 10
                    local btnW = pw - 20
                    local btnH2 = 14
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, expBtnX, ey, btnW, btnH2, 3)
                    nvgFillColor(vg, nvgRGBA(80, 40, 10, 180))
                    nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(255, 140, 30, 160))
                    nvgStrokeWidth(vg, 0.7); nvgStroke(vg)
                    nvgFontSize(vg, 8)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 200, 100, 240))
                    nvgText(vg, expBtnX + btnW/2, ey + btnH2/2,
                        string.format("远征 海盗基地Lv%d", base.level))
                    local capturedBase = base
                    addHit(expBtnX, ey, btnW, btnH2, function()
                        onLaunchExpedition(activeId_, capturedBase.id)
                    end)
                    ey = ey + btnH2 + 3
                end
            else
                nvgFontSize(vg, 8); nvgFillColor(vg, nvgRGBA(120, 120, 120, 160))
                nvgText(vg, px + 12, ey, "无可远征目标")
                ey = ey + 11
            end
        end

        EXP_H = ey - expStartY
    end
    sy = sy + EXP_H + 6
end

-- ══════════════════════════════════════════════════════════════════════════════
-- P2-2a: 命名模态框渲染
-- ══════════════════════════════════════════════════════════════════════════════
function FleetPanel.RenderNamingModal()
    if not namingActive_ then return end
    local vg    = UICommon.vg
    local addHit = UICommon.addHit
    local panel  = UICommon.panel
    local text   = UICommon.text

    local dpr = graphics:GetDPR()
    local sw  = graphics:GetWidth() / dpr
    local sh  = graphics:GetHeight() / dpr

    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
    nvgFill(vg)
    addHit(0, 0, sw, sh, function() closeNaming() end)

    -- 面板尺寸
    local mw, mh = 220, 160
    local mx = sw/2 - mw/2
    local my = sh/2 - mh/2

    -- 面板背景
    panel(mx, my, mw, mh, 8, {12,20,38,245}, {80,160,255,200})
    -- 阻止点击穿透到遮罩
    addHit(mx, my, mw, mh, function() end)

    local cy = my + 12

    -- 标题
    text(mx + mw/2, cy, "舰队命名", 12, 180,220,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    cy = cy + 20

    -- 输入框背景
    local inputX, inputY, inputW, inputH = mx + 12, cy, mw - 24, 22
    nvgBeginPath(vg)
    nvgRoundedRect(vg, inputX, inputY, inputW, inputH, 4)
    nvgFillColor(vg, nvgRGBA(5, 10, 20, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, 180))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)

    -- 输入文本 + 光标
    local displayText = namingText_
    local charCount = utf8.len(namingText_) or 0
    if charCount == 0 then
        -- placeholder
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 160, 120))
        nvgText(vg, inputX + 6, inputY + inputH/2, "点击随机或输入名称...")
    else
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 240, 255, 240))
        nvgText(vg, inputX + 6, inputY + inputH/2, displayText)
    end
    -- 闪烁光标
    local blink = math.floor(os.clock() * 2) % 2 == 0
    if blink then
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
        local tw = nvgTextBounds(vg, 0, 0, displayText)
        nvgBeginPath(vg)
        nvgRect(vg, inputX + 6 + tw + 1, inputY + 4, 1.5, inputH - 8)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 200))
        nvgFill(vg)
    end

    -- 字符计数
    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(120, 160, 200, 160))
    nvgText(vg, inputX + inputW - 4, inputY + inputH/2, charCount .. "/" .. NAME_MAX_LEN)

    cy = cy + inputH + 10

    -- 随机名称按钮行（显示 3 个随机名 + 🎲刷新按钮）
    text(mx + 12, cy, "快速选择:", 9, 140,180,220,180)
    cy = cy + 14

    -- 3个随机名称按钮
    local btnW = math.floor((mw - 36) / 3)
    for i = 1, 3 do
        local bx = mx + 10 + (i-1) * (btnW + 4)
        local by = cy
        local bh = 20
        local seed = namingFleetId_ * 100 + i  -- 稳定种子
        -- 使用稳定偏移，但每次打开面板时自然变化
        local idx = ((seed + math.floor(namePressStart_ * 10)) % #FLEET_NAME_POOL) + 1
        local name = FLEET_NAME_POOL[idx]
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, btnW, bh, 3)
        nvgFillColor(vg, nvgRGBA(25, 50, 80, 200))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 120, 180, 160))
        nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 220))
        nvgText(vg, bx + btnW/2, by + bh/2, name)
        local capName = name
        addHit(bx, by, btnW, bh, function()
            namingText_ = capName
        end)
    end
    cy = cy + 24

    -- 🎲 随机按钮
    local diceX = mx + mw/2 - 30
    local diceW, diceH = 60, 18
    nvgBeginPath(vg)
    nvgRoundedRect(vg, diceX, cy, diceW, diceH, 3)
    nvgFillColor(vg, nvgRGBA(40, 30, 60, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 120, 255, 180))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 255, 240))
    nvgText(vg, diceX + diceW/2, cy + diceH/2, "🎲 随机")
    addHit(diceX, cy, diceW, diceH, function()
        namingText_ = randomFleetName()
    end)
    cy = cy + diceH + 12

    -- 确认 / 取消按钮
    local btnCW = 70
    local btnCH = 22
    local gap   = 16
    local okX   = mx + mw/2 - btnCW - gap/2
    local noX   = mx + mw/2 + gap/2

    -- 确认
    nvgBeginPath(vg)
    nvgRoundedRect(vg, okX, cy, btnCW, btnCH, 4)
    nvgFillColor(vg, nvgRGBA(20, 80, 50, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 220, 140, 200))
    nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(120, 255, 180, 240))
    nvgText(vg, okX + btnCW/2, cy + btnCH/2, "确认")
    addHit(okX, cy, btnCW, btnCH, function() confirmNaming() end)

    -- 取消
    nvgBeginPath(vg)
    nvgRoundedRect(vg, noX, cy, btnCW, btnCH, 4)
    nvgFillColor(vg, nvgRGBA(60, 30, 30, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 100, 100, 180))
    nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(255, 140, 140, 240))
    nvgText(vg, noX + btnCW/2, cy + btnCH/2, "取消")
    addHit(noX, cy, btnCW, btnCH, function() closeNaming() end)
end

return FleetPanel
