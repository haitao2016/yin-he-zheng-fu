-- ============================================================================
-- game/ui/LegacyPanel.lua  -- P1-3 V2.5: 文明遗产面板（模态浮层）
-- 展示 LP、3 分支×5 级升级树、升级/重置操作
-- ============================================================================
local UICommon      = require("game.ui.UICommon")
local LegacySystem  = require("game.LegacySystem")

local LegacyPanel = {}

-- 面板状态
local open_        = false
local scrollY_     = 0
local hoverBranch_ = nil   -- "military" | "economy" | "diplomacy" | nil
local hoverLevel_  = 0     -- 1..5

-- ============================================================================
-- 分支配置
-- ============================================================================

local BRANCHES = {
    {
        key   = "military",
        label = "军事",
        color = { 220, 80, 80 },
        levels = {
            "初始舰队+1",
            "改装槽+1",
            "技能CD-10%",
            "指挥官初始Lv2",
            "Boss伤害+20%",
        },
    },
    {
        key   = "economy",
        label = "经济",
        color = { 80, 200, 120 },
        levels = {
            "初始资源+15%",
            "建造速度+10%",
            "黑市折扣10%",
            "殖民速度+20%",
            "巨构工期-15s",
        },
    },
    {
        key   = "diplomacy",
        label = "外交",
        color = { 80, 160, 240 },
        levels = {
            "初始好感+5",
            "协议CD-20%",
            "正面事件+10%",
            "任务刷新-30s",
            "危机倒计时+30s",
        },
    },
}

local UPGRADE_COST = LegacySystem.UPGRADE_COST
local RESET_COST   = LegacySystem.RESET_COST
local MAX_LEVEL    = 5

-- ============================================================================
-- 公开 API
-- ============================================================================

function LegacyPanel.IsOpen() return open_ end
function LegacyPanel.Open()   open_ = true; scrollY_ = 0 end
function LegacyPanel.Close()  open_ = false end
function LegacyPanel.Toggle()
    open_ = not open_
    if open_ then scrollY_ = 0 end
end

-- ============================================================================
-- 渲染
-- ============================================================================

function LegacyPanel.Render()
    if not open_ then return end

    local vg       = UICommon.vg
    local screenW  = UICommon.screenW
    local screenH  = UICommon.screenH
    local addHit   = UICommon.addHit
    local addScroll = UICommon.addScroll
    local panel    = UICommon.panel
    local text     = UICommon.text
    local clr      = UICommon.clr
    local C        = UICommon.C

    -- 面板尺寸（居中）
    local pw = math.min(480, screenW - 40)
    local ph = math.min(420, screenH - 40)
    local px = math.floor((screenW - pw) / 2)
    local py = math.floor((screenH - ph) / 2)

    -- 遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, clr(0, 0, 0, 160))
    nvgFill(vg)
    addHit(0, 0, screenW, screenH, function() LegacyPanel.Close() end)

    -- 面板背景
    panel(px, py, pw, ph, 8, C.panelBgDark or { 20, 24, 36, 230 }, C.panelBorder)
    -- 阻止点击穿透到遮罩
    addHit(px, py, pw, ph, function() end)

    -- 标题 + LP 显示
    local lp = LegacySystem.GetLP()
    nvgFontSize(vg, 16)
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, clr(255, 255, 255, 255))
    nvgText(vg, px + 14, py + 18, "文明遗产")

    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, clr(255, 220, 80, 255))
    nvgText(vg, px + pw - 14, py + 18, string.format("⭐ LP: %d", lp))

    -- 关闭按钮
    local closeX = px + pw - 30
    local closeY = py + 4
    addHit(closeX, closeY, 24, 24, function() LegacyPanel.Close() end)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, clr(200, 200, 200, 200))
    nvgText(vg, closeX + 12, closeY + 12, "✕")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 10, py + 34)
    nvgLineTo(vg, px + pw - 10, py + 34)
    nvgStrokeColor(vg, clr(100, 100, 120, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 内容区滚动
    local contentTop = py + 38
    local contentH   = ph - 38 - 44  -- 底部留44给重置按钮区
    addScroll(px, contentTop, pw, contentH, function(dy)
        scrollY_ = math.max(scrollY_ - dy * 20, 0)
    end)

    -- 裁剪
    nvgSave(vg)
    nvgScissor(vg, px, contentTop, pw, contentH)

    -- 获取树状态
    local tree = LegacySystem.GetTree()

    -- 布局参数
    local branchW    = pw - 28          -- 每个分支行宽度
    local nodeW      = 70               -- 每个等级节点宽
    local nodeH      = 36               -- 节点高
    local branchH    = 72               -- 每个分支占用高度
    local branchGap  = 12               -- 分支间距
    local startX     = px + 14
    local startY     = contentTop + 8 - scrollY_

    hoverBranch_ = nil
    hoverLevel_  = 0

    for bi, branch in ipairs(BRANCHES) do
        local by = startY + (bi - 1) * (branchH + branchGap)

        -- 跳过完全不可见区域
        if by + branchH >= contentTop and by <= contentTop + contentH then
            local bColor = branch.color
            local curLevel = tree[branch.key] and tree[branch.key].level or 0

            -- 分支标签
            nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, clr(bColor[1], bColor[2], bColor[3], 255))
            nvgText(vg, startX, by + 10, string.format("%s (Lv.%d/%d)", branch.label, curLevel, MAX_LEVEL))

            -- 节点行
            local nodeY = by + 22
            local nodeGap = math.floor((branchW - MAX_LEVEL * nodeW) / (MAX_LEVEL - 1))
            if nodeGap < 4 then nodeGap = 4 end

            for lvl = 1, MAX_LEVEL do
                local nx = startX + (lvl - 1) * (nodeW + nodeGap)
                local ny = nodeY

                -- 连线（前一个节点到当前）
                if lvl > 1 then
                    local prevNx = startX + (lvl - 2) * (nodeW + nodeGap) + nodeW
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, prevNx, ny + nodeH / 2)
                    nvgLineTo(vg, nx, ny + nodeH / 2)
                    if lvl <= curLevel then
                        nvgStrokeColor(vg, clr(bColor[1], bColor[2], bColor[3], 200))
                    else
                        nvgStrokeColor(vg, clr(80, 80, 100, 120))
                    end
                    nvgStrokeWidth(vg, 2)
                    nvgStroke(vg)
                end

                -- 节点背景
                local unlocked = lvl <= curLevel
                local isNext   = lvl == curLevel + 1
                local canBuy   = isNext and LegacySystem.CanUpgrade(branch.key)

                nvgBeginPath(vg)
                nvgRoundedRect(vg, nx, ny, nodeW, nodeH, 4)
                if unlocked then
                    nvgFillColor(vg, clr(bColor[1], bColor[2], bColor[3], 60))
                    nvgStrokeColor(vg, clr(bColor[1], bColor[2], bColor[3], 200))
                elseif canBuy then
                    nvgFillColor(vg, clr(40, 44, 60, 200))
                    nvgStrokeColor(vg, clr(255, 220, 80, 200))
                else
                    nvgFillColor(vg, clr(30, 32, 44, 180))
                    nvgStrokeColor(vg, clr(60, 60, 80, 120))
                end
                nvgFill(vg)
                nvgStrokeWidth(vg, unlocked and 2 or 1)
                nvgStroke(vg)

                -- 节点文字（描述）
                nvgFontSize(vg, 9)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                if unlocked then
                    nvgFillColor(vg, clr(255, 255, 255, 240))
                else
                    nvgFillColor(vg, clr(180, 180, 200, 180))
                end
                nvgText(vg, nx + nodeW / 2, ny + 4, branch.levels[lvl])

                -- 费用标签
                if not unlocked then
                    nvgFontSize(vg, 9)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                    if canBuy then
                        nvgFillColor(vg, clr(255, 220, 80, 220))
                    else
                        nvgFillColor(vg, clr(140, 140, 160, 160))
                    end
                    nvgText(vg, nx + nodeW / 2, ny + nodeH - 2,
                        string.format("%dLP", UPGRADE_COST[lvl]))
                end

                -- 点击区域（仅可购买时）
                if canBuy then
                    addHit(nx, ny, nodeW, nodeH, function()
                        LegacySystem.Upgrade(branch.key)
                    end)
                end

                -- Hover 检测（简化：用 addHit 的 onHover 不可用，用 cursor 判断）
                local cx, cy = UICommon.cursorX, UICommon.cursorY
                if cx >= nx and cx <= nx + nodeW and cy >= ny and cy <= ny + nodeH then
                    hoverBranch_ = branch.key
                    hoverLevel_  = lvl
                end
            end
        end
    end

    nvgRestore(vg)  -- 恢复裁剪

    -- 底部区域：重置按钮
    local bottomY = py + ph - 40
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 10, bottomY - 4)
    nvgLineTo(vg, px + pw - 10, bottomY - 4)
    nvgStrokeColor(vg, clr(100, 100, 120, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 重置按钮
    local resetW = 100
    local resetH = 28
    local resetX = px + pw / 2 - resetW / 2
    local resetY = bottomY + 2
    local canReset = lp >= RESET_COST

    nvgBeginPath(vg)
    nvgRoundedRect(vg, resetX, resetY, resetW, resetH, 4)
    if canReset then
        nvgFillColor(vg, clr(180, 60, 60, 200))
    else
        nvgFillColor(vg, clr(60, 60, 70, 180))
    end
    nvgFill(vg)

    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canReset then
        nvgFillColor(vg, clr(255, 255, 255, 240))
    else
        nvgFillColor(vg, clr(120, 120, 140, 160))
    end
    nvgText(vg, resetX + resetW / 2, resetY + resetH / 2,
        string.format("重置全部 (%dLP)", RESET_COST))

    if canReset then
        addHit(resetX, resetY, resetW, resetH, function()
            LegacySystem.Reset()
        end)
    end

    -- 已投入 LP 统计
    local spent = LegacySystem.GetTotalSpent()
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, clr(140, 140, 160, 180))
    nvgText(vg, px + 14, resetY + resetH / 2, string.format("已投入: %dLP", spent))
end

return LegacyPanel
