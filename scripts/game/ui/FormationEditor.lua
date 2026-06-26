--- 自定义阵型编辑器模块
--- P2-1 V2.5：8×6网格 + 拖拽放置 + 3套保存槽

local UICommon = require("game.ui.UICommon")
local Systems  = require("game.Systems")
local cjson    = require("cjson")

local SAVE_FILE = "formation_slots.json"

local FormationEditor = {}

-- ─── 常量 ─────────────────────────────────────────────────────────────────────
local GRID_COLS  = 8
local GRID_ROWS  = 6
local CELL_SIZE  = 28   -- 每格像素大小
local GRID_PAD   = 8    -- 网格外边距
local SLOT_COUNT = 3    -- 保存槽数量

-- 战斗用舰船类型（可放入阵型的类型）
-- V2.6 A1: 新增舰种 COMBAT_TYPES 和 MELEE_TYPES
local COMBAT_TYPES = { "SCOUT", "FRIGATE", "DESTROYER", "BATTLECRUISER", "INTERCEPTOR", "CARRIER", "ENGINEER", "STEALTH", "SUPPORT", "DREADNOUGHT" }

-- 近战判定（不能放在后排 col 7-8）
local MELEE_TYPES = { SCOUT = true, INTERCEPTOR = true, DREADNOUGHT = true }

-- ─── 状态 ─────────────────────────────────────────────────────────────────────
local open_        = false     -- 编辑器面板是否打开
local slotIdx_     = 1         -- 当前编辑槽 (1-3)
local grid_        = {}        -- grid_[row][col] = shipType 或 nil
local dragging_    = nil       -- {shipType=, fromRow=, fromCol=} 拖拽中的舰船
local dragX_       = 0         -- 拖拽当前屏幕坐标
local dragY_       = 0
local shipPalette_ = {}        -- 可选舰船列表（从编队数据获取）
local errorMsg_    = nil       -- 验证错误提示
local errorTimer_  = 0

-- 持久化存储（3 个槽，每槽为 grid 数据或 nil）
local savedSlots_ = { nil, nil, nil }

-- 自定义阵型胜利计数（用于"战术家"成就）
local customWins_ = 0

-- ─── 持久化 ─────────────────────────────────────────────────────────────────────

local function saveToFile()
    local data = { slots = savedSlots_, customWins = customWins_ }
    local json = cjson.encode(data)
    local file = File(SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
    end
end

local function loadFromFile()
    if not fileSystem:FileExists(SAVE_FILE) then
        return
    end
    local file = File(SAVE_FILE, FILE_READ) ---@diagnostic disable-line: param-type-mismatch
    if not file:IsOpen() then
        return
    end
    local raw = file:ReadString()
    file:Close()
    local ok, decoded = pcall(cjson.decode, raw)
    if not ok or type(decoded) ~= "table" then
        return
    end
    -- 恢复槽位数据
    if decoded.slots then
        for i = 1, SLOT_COUNT do
            savedSlots_[i] = decoded.slots[i] or nil
        end
    end
    -- 恢复自定义胜利计数
    if decoded.customWins then
        customWins_ = decoded.customWins
    end
end

-- ─── 辅助 ─────────────────────────────────────────────────────────────────────

--- 清空网格
local function clearGrid()
    grid_ = {}
    for r = 1, GRID_ROWS do
        grid_[r] = {}
        for c = 1, GRID_COLS do
            grid_[r][c] = nil
        end
    end
end

--- 网格深拷贝
local function copyGrid(g)
    local ng = {}
    for r = 1, GRID_ROWS do
        ng[r] = {}
        for c = 1, GRID_COLS do
            ng[r][c] = g[r] and g[r][c] or nil
        end
    end
    return ng
end

--- 验证阵型规则
--- @return boolean, string|nil
local function validateGrid()
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            local st = grid_[r][c]
            if st then
                -- 前排(col 1-2)不能放 ENGINEER
                if c <= 2 and st == "ENGINEER" then
                    return false, "工程舰不能放在前排(列1-2)"
                end
                -- 后排(col 7-8)不能放近战舰
                if c >= 7 and MELEE_TYPES[st] then
                    return false, (SHIP_TYPES[st] and SHIP_TYPES[st].name or st) .. "不能放在后排(列7-8)"
                end
            end
        end
    end
    return true, nil
end

--- 统计当前网格已放舰船数量
local function countPlaced()
    local n = 0
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            if grid_[r][c] then n = n + 1 end
        end
    end
    return n
end

--- 将网格转为序列化格式 { {row,col,shipType}, ... }
local function gridToList(g)
    local list = {}
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            if g[r] and g[r][c] then
                list[#list+1] = { r = r, c = c, t = g[r][c] }
            end
        end
    end
    return list
end

--- 从序列化格式恢复网格
local function listToGrid(list)
    local g = {}
    for r = 1, GRID_ROWS do
        g[r] = {}
    end
    if list then
        for _, item in ipairs(list) do
            if item.r >= 1 and item.r <= GRID_ROWS and item.c >= 1 and item.c <= GRID_COLS then
                g[item.r][item.c] = item.t
            end
        end
    end
    return g
end

--- 将网格坐标转为战斗区域的 (x, y) 像素坐标（映射到 BattleScene 左半部分）
--- 战场区域宽约 300px（左半），高约 screenH-88（去顶栏）
--- col 1 = 最左, col 8 = 中部
--- row 1 = 最上, row 6 = 最下
function FormationEditor.GridToPixel(row, col, screenW, screenH)
    local areaW = 300     -- 战斗区域左半部分宽度
    local topOff = 88     -- 顶部偏移
    local areaH = screenH - topOff - 12  -- 底部留白
    local cellW = areaW / GRID_COLS
    local cellH = areaH / GRID_ROWS
    local x = (col - 0.5) * cellW
    local y = topOff + (row - 0.5) * cellH
    return x, y
end

-- ─── 公开接口 ─────────────────────────────────────────────────────────────────

--- 初始化：从磁盘文件恢复持久化数据
function FormationEditor.Init()
    savedSlots_ = { nil, nil, nil }
    customWins_ = 0
    loadFromFile()
    print("[FormationEditor] Init: loaded " .. (FormationEditor.HasSaved() and "有" or "无") .. "自定义阵型, customWins=" .. customWins_)
end

--- 保存到磁盘
function FormationEditor.Save()
    saveToFile()
end

--- 记录一次自定义阵型胜利（战斗胜利时调用）
function FormationEditor.AddCustomWin()
    customWins_ = customWins_ + 1
    saveToFile()
end

--- 获取自定义阵型胜利次数
function FormationEditor.GetCustomWins()
    return customWins_
end

function FormationEditor.IsOpen() return open_ end

function FormationEditor.Open(fleetShips)
    open_ = true
    errorMsg_ = nil
    errorTimer_ = 0
    dragging_ = nil
    -- 初始化调色板（从当前编队的舰船列表获取可选类型）
    shipPalette_ = {}
    if fleetShips then
        for _, entry in ipairs(fleetShips) do
            if entry.shipType and SHIP_TYPES[entry.shipType] and entry.shipType ~= "EXPLORER" then
                shipPalette_[#shipPalette_+1] = entry.shipType
            end
        end
    else
        -- 默认全部战斗类型
        for _, st in ipairs(COMBAT_TYPES) do
            shipPalette_[#shipPalette_+1] = st
        end
    end
    -- 加载当前槽数据（如果已有）
    if savedSlots_[slotIdx_] then
        grid_ = listToGrid(savedSlots_[slotIdx_])
    else
        clearGrid()
    end
end

function FormationEditor.Close()
    open_ = false
    dragging_ = nil
end

--- 加载持久化数据（从存档恢复）
---@param slots table|nil  { [1]=list, [2]=list, [3]=list }
function FormationEditor.LoadSlots(slots)
    savedSlots_ = { nil, nil, nil }
    if slots then
        for i = 1, SLOT_COUNT do
            if slots[i] then
                savedSlots_[i] = slots[i]
            end
        end
    end
end

--- 获取当前所有存储槽数据（用于存档）
function FormationEditor.GetSlots()
    return savedSlots_
end

--- 获取指定槽的阵型坐标列表（用于战斗加载）
---@param idx number 1-3
---@return table|nil  { {r,c,t}, ... }
function FormationEditor.GetSlotData(idx)
    return savedSlots_[idx]
end

--- 检查是否有任何已保存的自定义阵型
function FormationEditor.HasSaved()
    for i = 1, SLOT_COUNT do
        if savedSlots_[i] and #savedSlots_[i] > 0 then return true end
    end
    return false
end

--- 获取第一个非空槽的数据（供 BattleScene 自动选取）
function FormationEditor.GetFirstSavedSlot()
    for i = 1, SLOT_COUNT do
        if savedSlots_[i] and #savedSlots_[i] > 0 then
            return savedSlots_[i], i
        end
    end
    return nil, 0
end

-- ─── 渲染 ─────────────────────────────────────────────────────────────────────

function FormationEditor.Render()
    if not open_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit
    local panel   = UICommon.panel
    local text    = UICommon.text

    -- 面板尺寸与位置（居中浮层）
    local panW = GRID_COLS * CELL_SIZE + GRID_PAD*2 + 100  -- 网格+调色板
    local panH = GRID_ROWS * CELL_SIZE + GRID_PAD*2 + 90   -- 网格+按钮行
    local panX = math.floor((screenW - panW) / 2)
    local panY = math.floor((screenH - panH) / 2)

    -- 背景遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)
    addHit(0, 0, screenW, screenH, function() end) -- 拦截穿透

    -- 面板背景
    panel(panX, panY, panW, panH, 6, {20, 30, 50, 240}, {80, 140, 255, 120})

    -- 标题
    text(panX + panW/2, panY + 12, "自定义阵型编辑器", 12, 220, 240, 255, 255,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 槽位切换按钮
    local slotY = panY + 26
    local slotBtnW = 50
    for i = 1, SLOT_COUNT do
        local sx = panX + GRID_PAD + (i-1) * (slotBtnW + 4)
        local isAct = (i == slotIdx_)
        local hasSave = savedSlots_[i] and #savedSlots_[i] > 0
        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx, slotY, slotBtnW, 16, 3)
        nvgFillColor(vg, nvgRGBA(
            isAct and 60 or 30,
            isAct and 100 or 50,
            isAct and 180 or 80,
            isAct and 220 or 140))
        nvgFill(vg)
        if isAct then
            nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 200))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
        local label = "槽" .. i
        if hasSave then label = label .. " ✓" end
        text(sx + slotBtnW/2, slotY + 8, label, 9,
            isAct and 255 or 180, isAct and 255 or 200, 255, isAct and 255 or 180,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local capI = i
        addHit(sx, slotY, slotBtnW, 16, function()
            slotIdx_ = capI
            if savedSlots_[capI] then
                grid_ = listToGrid(savedSlots_[capI])
            else
                clearGrid()
            end
        end)
    end

    -- 关闭按钮
    local closeX = panX + panW - 30
    nvgBeginPath(vg); nvgRoundedRect(vg, closeX, panY + 6, 24, 16, 3)
    nvgFillColor(vg, nvgRGBA(180, 40, 40, 200)); nvgFill(vg)
    text(closeX + 12, panY + 14, "✕", 10, 255, 200, 200, 255,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    addHit(closeX, panY + 6, 24, 16, function() FormationEditor.Close() end)

    -- ─── 网格绘制 ──────────────────────────────────────────────────────────
    local gridX = panX + GRID_PAD
    local gridY = panY + 48
    local gridW = GRID_COLS * CELL_SIZE
    local gridH = GRID_ROWS * CELL_SIZE

    -- 列标签（1=前排, 8=后排）
    for c = 1, GRID_COLS do
        local cx = gridX + (c-1) * CELL_SIZE + CELL_SIZE/2
        local lbl = (c <= 2) and "前" or (c >= 7 and "后" or "")
        if lbl ~= "" then
            text(cx, gridY - 6, lbl, 7, 200, 200, 220, 120,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end
    end

    -- 网格背景
    nvgBeginPath(vg)
    nvgRect(vg, gridX, gridY, gridW, gridH)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 180))
    nvgFill(vg)

    -- 格线
    nvgStrokeColor(vg, nvgRGBA(60, 80, 120, 100))
    nvgStrokeWidth(vg, 0.5)
    for r = 0, GRID_ROWS do
        nvgBeginPath(vg)
        nvgMoveTo(vg, gridX, gridY + r * CELL_SIZE)
        nvgLineTo(vg, gridX + gridW, gridY + r * CELL_SIZE)
        nvgStroke(vg)
    end
    for c = 0, GRID_COLS do
        nvgBeginPath(vg)
        nvgMoveTo(vg, gridX + c * CELL_SIZE, gridY)
        nvgLineTo(vg, gridX + c * CELL_SIZE, gridY + gridH)
        nvgStroke(vg)
    end

    -- 禁止区域高亮（前排ENGINEER / 后排近战）
    for c = 1, 2 do
        for r = 1, GRID_ROWS do
            nvgBeginPath(vg)
            nvgRect(vg, gridX + (c-1)*CELL_SIZE + 1, gridY + (r-1)*CELL_SIZE + 1, CELL_SIZE-2, CELL_SIZE-2)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 15))
            nvgFill(vg)
        end
    end
    for c = 7, 8 do
        for r = 1, GRID_ROWS do
            nvgBeginPath(vg)
            nvgRect(vg, gridX + (c-1)*CELL_SIZE + 1, gridY + (r-1)*CELL_SIZE + 1, CELL_SIZE-2, CELL_SIZE-2)
            nvgFillColor(vg, nvgRGBA(255, 80, 80, 15))
            nvgFill(vg)
        end
    end

    -- 已放置舰船
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            local st = grid_[r][c]
            if st and SHIP_TYPES[st] then
                local cx = gridX + (c-1) * CELL_SIZE + CELL_SIZE/2
                local cy = gridY + (r-1) * CELL_SIZE + CELL_SIZE/2
                local clr = SHIP_TYPES[st].color
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, 9)
                nvgFillColor(vg, nvgRGBA(clr[1], clr[2], clr[3], 200))
                nvgFill(vg)
                -- 首字母
                text(cx, cy, string.sub(SHIP_TYPES[st].name, 1, 3), 7,
                    255, 255, 255, 230, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                -- 点击可拖拽（移除或重放）
                local capR, capC, capSt = r, c, st
                addHit(gridX + (c-1)*CELL_SIZE, gridY + (r-1)*CELL_SIZE, CELL_SIZE, CELL_SIZE, function()
                    -- 开始拖拽（从网格移出）
                    dragging_ = { shipType = capSt, fromRow = capR, fromCol = capC }
                    grid_[capR][capC] = nil
                end)
            else
                -- 空格子可作为放置目标
                local capR2, capC2 = r, c
                addHit(gridX + (c-1)*CELL_SIZE, gridY + (r-1)*CELL_SIZE, CELL_SIZE, CELL_SIZE, function()
                    if dragging_ then
                        -- 验证：前排禁 ENGINEER
                        if capC2 <= 2 and dragging_.shipType == "ENGINEER" then
                            errorMsg_ = "工程舰不能放前排"
                            errorTimer_ = 2.0
                            -- 归还原位
                            if dragging_.fromRow then
                                grid_[dragging_.fromRow][dragging_.fromCol] = dragging_.shipType
                            end
                        elseif capC2 >= 7 and MELEE_TYPES[dragging_.shipType] then
                            errorMsg_ = (SHIP_TYPES[dragging_.shipType].name) .. "不能放后排"
                            errorTimer_ = 2.0
                            if dragging_.fromRow then
                                grid_[dragging_.fromRow][dragging_.fromCol] = dragging_.shipType
                            end
                        else
                            grid_[capR2][capC2] = dragging_.shipType
                        end
                        dragging_ = nil
                    end
                end)
            end
        end
    end

    -- ─── 舰船调色板（右侧） ─────────────────────────────────────────────────
    local palX = gridX + gridW + 10
    local palY = gridY
    text(palX + 35, palY - 6, "舰船", 9, 200, 220, 255, 200,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for idx, st in ipairs(shipPalette_) do
        local sdata = SHIP_TYPES[st]
        if sdata then
            local py2 = palY + (idx-1) * 24
            local clr = sdata.color
            nvgBeginPath(vg)
            nvgRoundedRect(vg, palX, py2, 70, 20, 3)
            nvgFillColor(vg, nvgRGBA(clr[1], clr[2], clr[3], 60))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(clr[1], clr[2], clr[3], 140))
            nvgStrokeWidth(vg, 0.7); nvgStroke(vg)
            -- 舰船图标+名称
            nvgBeginPath(vg); nvgCircle(vg, palX + 10, py2 + 10, 5)
            nvgFillColor(vg, nvgRGBA(clr[1], clr[2], clr[3], 220)); nvgFill(vg)
            text(palX + 20, py2 + 10, sdata.name, 8, 220, 230, 255, 220,
                NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            -- 点击 = 选中准备放置
            local capSt = st
            addHit(palX, py2, 70, 20, function()
                dragging_ = { shipType = capSt, fromRow = nil, fromCol = nil }
            end)
        end
    end

    -- 取消拖拽按钮（当有拖拽时显示）
    if dragging_ then
        local cancelY = palY + #shipPalette_ * 24 + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, palX, cancelY, 70, 18, 3)
        nvgFillColor(vg, nvgRGBA(180, 60, 60, 180)); nvgFill(vg)
        text(palX + 35, cancelY + 9, "取消放置", 8, 255, 200, 200, 240,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        addHit(palX, cancelY, 70, 18, function()
            -- 归还原位
            if dragging_ and dragging_.fromRow then
                grid_[dragging_.fromRow][dragging_.fromCol] = dragging_.shipType
            end
            dragging_ = nil
        end)
    end

    -- ─── 底部按钮行 ──────────────────────────────────────────────────────
    local btnY = gridY + gridH + 10
    local btnH = 20
    local btnW2 = 60
    local placed = countPlaced()

    -- 统计
    text(panX + GRID_PAD, btnY + btnH/2, "已放置: " .. placed, 9,
        180, 200, 240, 200, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- 保存按钮
    local saveX = panX + panW/2 - btnW2 - 4
    nvgBeginPath(vg); nvgRoundedRect(vg, saveX, btnY, btnW2, btnH, 3)
    local canSave = placed > 0
    nvgFillColor(vg, nvgRGBA(40, canSave and 140 or 60, canSave and 80 or 40, canSave and 220 or 120))
    nvgFill(vg)
    text(saveX + btnW2/2, btnY + btnH/2, "保存", 10,
        canSave and 220 or 120, 255, canSave and 200 or 120, canSave and 255 or 140,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canSave then
        addHit(saveX, btnY, btnW2, btnH, function()
            local ok, err = validateGrid()
            if not ok then
                errorMsg_ = err
                errorTimer_ = 2.5
            else
                savedSlots_[slotIdx_] = gridToList(grid_)
                saveToFile()  -- 自动持久化到磁盘
                errorMsg_ = "阵型已保存到槽" .. slotIdx_
                errorTimer_ = 1.5
            end
        end)
    end

    -- 清空按钮
    local clearX = panX + panW/2 + 4
    nvgBeginPath(vg); nvgRoundedRect(vg, clearX, btnY, btnW2, btnH, 3)
    nvgFillColor(vg, nvgRGBA(120, 60, 30, 180)); nvgFill(vg)
    text(clearX + btnW2/2, btnY + btnH/2, "清空", 10,
        255, 180, 100, 230, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    addHit(clearX, btnY, btnW2, btnH, function()
        clearGrid()
        dragging_ = nil
    end)

    -- 错误/成功提示
    if errorMsg_ and errorTimer_ > 0 then
        text(panX + panW/2, btnY + btnH + 14, errorMsg_, 9,
            255, 220, 80, 240, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

--- 每帧更新（递减错误提示计时器）
function FormationEditor.Update(dt)
    if errorTimer_ > 0 then
        errorTimer_ = errorTimer_ - dt
        if errorTimer_ <= 0 then
            errorMsg_ = nil
        end
    end
end

return FormationEditor
