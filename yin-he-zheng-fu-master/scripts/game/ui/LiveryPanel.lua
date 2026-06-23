-- ============================================================================
-- game/ui/LiveryPanel.lua  -- 舰队涂装与徽章选择面板
-- P2-3 V2.4: 涂装色板 + 徽章 + 解锁条件显示
-- ============================================================================
local UICommon      = require "game.ui.UICommon"
local LiverySystem  = require "game.LiverySystem"

local LiveryPanel = {}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local visible_    = false
local tab_        = "color"   -- "color" | "emblem"
local animT_      = 0
local scrollY_    = 0         -- emblem tab scroll offset
local ANIM_DUR    = 0.25

-- ── 渲染 ─────────────────────────────────────────────────────────────────────
local function render()
    if not visible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    animT_ = math.min(animT_ + 0.016, ANIM_DUR)
    local prog = math.min(1.0, animT_ / ANIM_DUR)
    local ease = 1 - (1 - prog) ^ 3

    -- 全屏遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(170 * ease)))
    nvgFill(vg)
    addHit(0, 0, screenW, screenH, function() visible_ = false end)

    -- 面板
    local pw = math.min(400, screenW - 30)
    local ph = math.min(460, screenH - 30)
    local px = (screenW - pw) / 2
    local py = (screenH - ph) / 2 - (1 - ease) * 40

    nvgSave(vg)
    nvgGlobalAlpha(vg, ease)

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(6, 10, 28, 250))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 180, 255, 180))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    addHit(px, py, pw, ph, function() end) -- consume clicks

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 200, 255, 255))
    nvgText(vg, px + pw / 2, py + 20, "🎨  舰队涂装与徽章")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 34)
    nvgLineTo(vg, px + pw - 16, py + 34)
    nvgStrokeColor(vg, nvgRGBA(60, 120, 200, 80))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- Tab 切换按钮
    local tabY = py + 40
    local tabW = 90
    local tabH = 24
    local tabs = { {id="color", label="涂装色板"}, {id="emblem", label="徽章图标"} }
    for i, t in ipairs(tabs) do
        local tx = px + (pw / 2) + (i - 1.5) * (tabW + 8) - tabW / 2
        local isActive = (tab_ == t.id)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW, tabH, 5)
        nvgFillColor(vg, isActive and nvgRGBA(40, 120, 220, 220) or nvgRGBA(20, 40, 80, 180))
        nvgFill(vg)
        nvgStrokeColor(vg, isActive and nvgRGBA(80, 180, 255, 200) or nvgRGBA(50, 90, 160, 100))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(220, 245, 255, 255) or nvgRGBA(120, 160, 200, 200))
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, t.label)
        addHit(tx, tabY, tabW, tabH, function() tab_ = t.id; scrollY_ = 0 end)
    end

    -- 内容区
    local contentY = tabY + tabH + 12
    local contentH = ph - (contentY - py) - 50

    if tab_ == "color" then
        renderColorTab(vg, px, contentY, pw, contentH, addHit)
    else
        renderEmblemTab(vg, px, contentY, pw, contentH, addHit)
    end

    -- 关闭按钮
    local cbw, cbh = 100, 28
    local cbx = px + (pw - cbw) / 2
    local cby = py + ph - cbh - 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbx, cby, cbw, cbh, 6)
    nvgFillColor(vg, nvgRGBA(20, 60, 140, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 140, 255, 160))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 240))
    nvgText(vg, cbx + cbw / 2, cby + cbh / 2, "关闭")
    addHit(cbx, cby, cbw, cbh, function() visible_ = false end)

    nvgRestore(vg)
end

-- ── 色板 Tab ─────────────────────────────────────────────────────────────────
function renderColorTab(vg, px, startY, pw, contentH, addHit)
    local margin = 16
    local areaW = pw - margin * 2

    -- 预览条：当前主色 + 辅色
    local previewH = 32
    local primary = LiverySystem.GetPrimary()
    local accent  = LiverySystem.GetAccent()
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 180, 220, 200))
    nvgText(vg, px + margin, startY + previewH / 2, "当前:")

    -- 主色方块
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px + margin + 36, startY + 4, 40, previewH - 8, 4)
    nvgFillColor(vg, nvgRGBA(primary.r, primary.g, primary.b, 255)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, px + margin + 56, startY + previewH / 2, "主色")

    -- 辅色方块
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px + margin + 84, startY + 4, 40, previewH - 8, 4)
    nvgFillColor(vg, nvgRGBA(accent.r, accent.g, accent.b, 255)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgFontSize(vg, 8)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, px + margin + 104, startY + previewH / 2, "辅色")

    -- 主色色板
    local secY = startY + previewH + 8
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 220))
    nvgText(vg, px + margin, secY + 6, "▎主色（船体涂装）")
    secY = secY + 18

    local primaries = LiverySystem.GetAllPrimaries()
    local cols = 6
    local cellS = math.floor((areaW - (cols - 1) * 4) / cols)
    local selPrimId = LiverySystem.GetPrimary().id

    for idx, c in ipairs(primaries) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local cx = px + margin + col * (cellS + 4)
        local cy = secY + row * (cellS + 4)
        local isUnlocked = LiverySystem.IsUnlocked("primary", c.id)
        local isSelected = (c.id == selPrimId)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, cellS, cellS, 4)
        if isUnlocked then
            nvgFillColor(vg, nvgRGBA(c.r, c.g, c.b, 255))
        else
            nvgFillColor(vg, nvgRGBA(math.floor(c.r*0.3), math.floor(c.g*0.3), math.floor(c.b*0.3), 180))
        end
        nvgFill(vg)

        if isSelected then
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        elseif isUnlocked then
            nvgStrokeColor(vg, nvgRGBA(200, 200, 200, 80))
            nvgStrokeWidth(vg, 0.5)
            nvgStroke(vg)
        end

        -- 锁定图标
        if not isUnlocked then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
            nvgText(vg, cx + cellS / 2, cy + cellS / 2, "🔒")
        end

        addHit(cx, cy, cellS, cellS, function()
            if isUnlocked then
                LiverySystem.SetPrimary(c.id)
            end
        end)
    end

    -- 辅色色板
    local primRows = math.ceil(#primaries / cols)
    local accY = secY + primRows * (cellS + 4) + 10
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 220))
    nvgText(vg, px + margin, accY + 6, "▎辅色（引擎尾焰）")
    accY = accY + 18

    local accents = LiverySystem.GetAllAccents()
    local selAccId = LiverySystem.GetAccent().id

    for idx, c in ipairs(accents) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local cx = px + margin + col * (cellS + 4)
        local cy = accY + row * (cellS + 4)
        local isUnlocked = LiverySystem.IsUnlocked("accent", c.id)
        local isSelected = (c.id == selAccId)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, cellS, cellS, 4)
        if isUnlocked then
            nvgFillColor(vg, nvgRGBA(c.r, c.g, c.b, 255))
        else
            nvgFillColor(vg, nvgRGBA(math.floor(c.r*0.3), math.floor(c.g*0.3), math.floor(c.b*0.3), 180))
        end
        nvgFill(vg)

        if isSelected then
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        elseif isUnlocked then
            nvgStrokeColor(vg, nvgRGBA(200, 200, 200, 80))
            nvgStrokeWidth(vg, 0.5)
            nvgStroke(vg)
        end

        if not isUnlocked then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
            nvgText(vg, cx + cellS / 2, cy + cellS / 2, "🔒")
        end

        addHit(cx, cy, cellS, cellS, function()
            if isUnlocked then
                LiverySystem.SetAccent(c.id)
            end
        end)
    end
end

-- ── 徽章 Tab ─────────────────────────────────────────────────────────────────
function renderEmblemTab(vg, px, startY, pw, contentH, addHit)
    local margin = 16
    local areaW = pw - margin * 2

    local emblems = LiverySystem.GetAllEmblems()
    local selEmbId = LiverySystem.GetEmblem().id
    local cols = 5
    local cellS = math.floor((areaW - (cols - 1) * 6) / cols)
    local rowH = cellS + 20  -- cell + label space

    -- 当前徽章预览
    local curEmb = LiverySystem.GetEmblem()
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 180, 220, 200))
    nvgText(vg, px + margin, startY + 10, "当前徽章:")
    nvgFontSize(vg, 18)
    nvgText(vg, px + margin + 62, startY + 10, curEmb.icon)
    nvgFontSize(vg, 9)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 180))
    nvgText(vg, px + margin + 84, startY + 10, curEmb.name)

    local gridY = startY + 28

    for idx, emb in ipairs(emblems) do
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local cx = px + margin + col * (cellS + 6)
        local cy = gridY + row * rowH
        local isUnlocked = LiverySystem.IsUnlocked("emblem", emb.id)
        local isSelected = (emb.id == selEmbId)

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, cellS, cellS, 6)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(40, 100, 180, 200))
        elseif isUnlocked then
            nvgFillColor(vg, nvgRGBA(20, 40, 80, 180))
        else
            nvgFillColor(vg, nvgRGBA(15, 20, 40, 200))
        end
        nvgFill(vg)

        if isSelected then
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        else
            nvgStrokeColor(vg, nvgRGBA(60, 100, 160, isUnlocked and 120 or 60))
            nvgStrokeWidth(vg, 0.8)
            nvgStroke(vg)
        end

        -- 图标
        nvgFontSize(vg, isUnlocked and 20 or 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isUnlocked then
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
            nvgText(vg, cx + cellS / 2, cy + cellS / 2, emb.icon)
        else
            nvgFillColor(vg, nvgRGBA(100, 100, 100, 160))
            nvgText(vg, cx + cellS / 2, cy + cellS / 2, "🔒")
        end

        -- 名称标签
        nvgFontSize(vg, 7)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(140, 160, 200, isUnlocked and 200 or 120))
        local label = #emb.name > 4 and string.sub(emb.name, 1, 4) .. ".." or emb.name
        nvgText(vg, cx + cellS / 2, cy + cellS + 2, label)

        addHit(cx, cy, cellS, cellS + 14, function()
            if isUnlocked then
                LiverySystem.SetEmblem(emb.id)
            end
        end)
    end
end

-- ============================================================================
-- 公开 API
-- ============================================================================

function LiveryPanel.Show()
    visible_ = true
    animT_   = 0
    scrollY_ = 0
    -- 刷新解锁状态
    LiverySystem.RefreshUnlocks(LiveryPanel._ctx or {})
end

function LiveryPanel.Hide()
    visible_ = false
end

function LiveryPanel.IsVisible()
    return visible_
end

function LiveryPanel.Toggle()
    if visible_ then
        visible_ = false
    else
        LiveryPanel.Show()
    end
end

function LiveryPanel.Render()
    render()
end

--- 注入解锁上下文（由 Client.lua 设置，包含 achievements/league/crisis/nemesis/mega）
function LiveryPanel.SetContext(ctx)
    LiveryPanel._ctx = ctx
end

return LiveryPanel
