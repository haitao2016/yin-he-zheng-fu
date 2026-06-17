-- ============================================================================
-- game/ui/GalactopediaPanel.lua  -- P3-1: 银河百科 UI 面板
-- 分类选项卡+条目列表+详情展示+解锁进度
-- ============================================================================
local UICommon           = require "game.ui.UICommon"
local GalactopediaSystem = require "game.GalactopediaSystem"

local GalactopediaPanel = {}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local visible_       = false
local animT_         = 0
local ANIM_DUR       = 0.25
local selectedCat_   = "ships"     -- 当前选中分类
local selectedEntry_ = nil         -- 当前选中条目 id（展示详情）
local scrollY_       = 0           -- 条目列表滚动偏移
local MAX_SCROLL     = 0           -- 动态计算

-- ── 公开 API ─────────────────────────────────────────────────────────────────
function GalactopediaPanel.Show()
    visible_ = true
    animT_   = 0
    scrollY_ = 0
    selectedEntry_ = nil
end

function GalactopediaPanel.Hide()
    visible_ = false
end

function GalactopediaPanel.IsVisible()
    return visible_
end

function GalactopediaPanel.Toggle()
    if visible_ then GalactopediaPanel.Hide() else GalactopediaPanel.Show() end
end

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

    -- 面板尺寸
    local pw = math.min(520, screenW - 30)
    local ph = math.min(500, screenH - 30)
    local px = (screenW - pw) / 2
    local py = (screenH - ph) / 2 - (1 - ease) * 40

    nvgSave(vg)
    nvgGlobalAlpha(vg, ease)

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(6, 10, 28, 250))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 200, 180, 180))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    addHit(px, py, pw, ph, function() end) -- consume clicks

    -- 标题与进度
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(60, 220, 200, 255))
    local unlocked, total = GalactopediaSystem.GetProgress()
    nvgText(vg, px + pw / 2, py + 20, string.format("📖  银河百科  (%d/%d)", unlocked, total))

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 34)
    nvgLineTo(vg, px + pw - 16, py + 34)
    nvgStrokeColor(vg, nvgRGBA(60, 180, 160, 80))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 关闭按钮
    local closeX = px + pw - 28
    local closeY = py + 8
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
    nvgText(vg, closeX + 8, closeY + 10, "✕")
    addHit(closeX, closeY, 20, 20, function() visible_ = false end)

    -- ── 分类选项卡 ─────────────────────────────────────────────────
    local categories = GalactopediaSystem.GetCategories()
    local tabY = py + 40
    local tabH = 22
    local tabSpacing = 4
    local totalTabW = 0
    -- 先计算总宽
    nvgFontSize(vg, 10)
    local tabWidths = {}
    for i, cat in ipairs(categories) do
        local label = cat.icon .. " " .. cat.name
        local tw = 46  -- approximate fixed width for compact layout
        tabWidths[i] = tw
        totalTabW = totalTabW + tw + tabSpacing
    end
    totalTabW = totalTabW - tabSpacing

    local tabStartX = px + (pw - totalTabW) / 2
    local cx = tabStartX
    for i, cat in ipairs(categories) do
        local tw = tabWidths[i]
        local isActive = (selectedCat_ == cat.id)
        -- tab background
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, tabY, tw, tabH, 4)
        if isActive then
            nvgFillColor(vg, nvgRGBA(30, 140, 160, 220))
        else
            nvgFillColor(vg, nvgRGBA(20, 40, 60, 180))
        end
        nvgFill(vg)
        -- tab label
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(200, 255, 240, 255) or nvgRGBA(150, 180, 180, 200))
        nvgText(vg, cx + tw / 2, tabY + tabH / 2, cat.icon)
        -- hit
        local catId = cat.id
        addHit(cx, tabY, tw, tabH, function()
            selectedCat_   = catId
            selectedEntry_ = nil
            scrollY_       = 0
        end)
        cx = cx + tw + tabSpacing
    end

    -- ── 分类进度条 ─────────────────────────────────────────────────
    local barY = tabY + tabH + 6
    local catUnlocked, catTotal = GalactopediaSystem.GetCategoryProgress(selectedCat_)
    local barW = pw - 40
    local barH = 6
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px + 20, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, 200))
    nvgFill(vg)
    if catTotal > 0 then
        local fillW = barW * (catUnlocked / catTotal)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px + 20, barY, fillW, barH, 3)
        nvgFillColor(vg, nvgRGBA(60, 220, 180, 220))
        nvgFill(vg)
    end
    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(120, 200, 180, 200))
    nvgText(vg, px + pw - 20, barY + barH / 2, string.format("%d/%d", catUnlocked, catTotal))

    -- ── 条目列表 ─────────────────────────────────────────────────
    local listY = barY + barH + 10
    local listH = ph - (listY - py) - 12
    local entries = GalactopediaSystem.GetEntries(selectedCat_)
    local rowH = 32
    local contentH = #entries * rowH
    MAX_SCROLL = math.max(0, contentH - listH)
    scrollY_ = math.max(0, math.min(scrollY_, MAX_SCROLL))

    -- clip region (simulated via scissor)
    nvgScissor(vg, px + 10, listY, pw - 20, listH)

    for i, entry in ipairs(entries) do
        local ry = listY + (i - 1) * rowH - scrollY_
        -- Skip if outside visible area
        if ry + rowH > listY and ry < listY + listH then
            local isSelected = (selectedEntry_ == entry.id)
            -- row background
            nvgBeginPath(vg)
            nvgRoundedRect(vg, px + 14, ry + 2, pw - 28, rowH - 4, 5)
            if isSelected then
                nvgFillColor(vg, nvgRGBA(40, 120, 140, 180))
            elseif not entry.unlocked then
                nvgFillColor(vg, nvgRGBA(15, 20, 30, 150))
            else
                nvgFillColor(vg, nvgRGBA(20, 50, 70, 150))
            end
            nvgFill(vg)

            -- icon + name
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if entry.unlocked then
                nvgFillColor(vg, nvgRGBA(220, 255, 240, 255))
                nvgText(vg, px + 22, ry + rowH / 2, entry.icon .. "  " .. entry.name)
            else
                nvgFillColor(vg, nvgRGBA(80, 100, 110, 180))
                nvgText(vg, px + 22, ry + rowH / 2, "🔒  ???")
            end

            -- "已解锁" 标记
            if entry.unlocked then
                nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(60, 200, 160, 160))
                nvgText(vg, px + pw - 22, ry + rowH / 2, "✓")
            end

            -- hit area
            if entry.unlocked then
                local eid = entry.id
                addHit(px + 14, ry + 2, pw - 28, rowH - 4, function()
                    selectedEntry_ = (selectedEntry_ == eid) and nil or eid
                end)
            end
        end
    end

    nvgResetScissor(vg)

    -- ── 详情浮层 ─────────────────────────────────────────────────
    if selectedEntry_ then
        -- 找到选中条目
        local detail = nil
        for _, e in ipairs(entries) do
            if e.id == selectedEntry_ and e.unlocked then
                detail = e; break
            end
        end
        if detail then
            local detW = pw - 50
            local detH = 70
            local detX = px + 25
            local detY = py + ph - detH - 16

            nvgBeginPath(vg)
            nvgRoundedRect(vg, detX, detY, detW, detH, 8)
            nvgFillColor(vg, nvgRGBA(10, 30, 50, 240))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(60, 200, 180, 120))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 条目名
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(100, 240, 220, 255))
            nvgText(vg, detX + 10, detY + 8, detail.icon .. "  " .. detail.name)

            -- 描述文字（自动换行）
            nvgFontSize(vg, 9.5)
            nvgFillColor(vg, nvgRGBA(200, 220, 220, 220))
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgTextBox(vg, detX + 10, detY + 26, detW - 20, detail.desc)

            addHit(detX, detY, detW, detH, function() end)
        end
    end

    -- ── 滚动箭头提示 ─────────────────────────────────────────────
    if MAX_SCROLL > 0 then
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if scrollY_ > 0 then
            nvgFillColor(vg, nvgRGBA(150, 220, 200, 180))
            nvgText(vg, px + pw / 2, listY + 6, "▲")
        end
        if scrollY_ < MAX_SCROLL then
            nvgFillColor(vg, nvgRGBA(150, 220, 200, 180))
            nvgText(vg, px + pw / 2, listY + listH - 6, "▼")
        end
        -- scroll hit areas
        addHit(px + 10, listY, pw - 20, 18, function()
            scrollY_ = math.max(0, scrollY_ - 64)
        end)
        addHit(px + 10, listY + listH - 18, pw - 20, 18, function()
            scrollY_ = math.min(MAX_SCROLL, scrollY_ + 64)
        end)
    end

    nvgRestore(vg)
end

function GalactopediaPanel.Render()
    render()
end

return GalactopediaPanel
