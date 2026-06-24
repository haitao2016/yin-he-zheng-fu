--- 任务日志面板模块
--- 右侧浮动面板，双 Tab：目标 / 探索记录

local UICommon    = require("game.ui.UICommon")
local DragManager = require("game.ui.DragManager")

local LogPanel = {}

-- ============================================================================
-- 面板私有状态
-- ============================================================================
local visible_  = false    -- 面板是否打开
local tab_      = "goals"  -- "goals" | "explore"
local scroll_   = 0        -- 当前 tab 的滚动偏移

-- ============================================================================
-- 公开 API
-- ============================================================================

function LogPanel.IsVisible()  return visible_  end

function LogPanel.Toggle()
    visible_ = not visible_
    scroll_  = 0
end

function LogPanel.Show()
    visible_ = true
    scroll_  = 0
end

function LogPanel.Hide()
    visible_ = false
    scroll_  = 0
end

--- 重置所有状态（新局开始时由 GameUI.Reset 调用）
function LogPanel.Reset()
    visible_  = false
    tab_      = "goals"
    scroll_   = 0
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 渲染任务日志面板
---@param completedGoals table   { [goalId]=true } 已完成目标 map
---@param exploreLog     table   探索日志条目数组
function LogPanel.Render(completedGoals, exploreLog)
    if not visible_ then return end

    local vg = UICommon.vg
    local W  = UICommon.screenW

    local PW      = 260
    local PAD     = 10
    local TAB_H   = 24
    local HEADER  = 28
    local ITEM_H  = 46    -- 目标条目高度
    local LOG_H   = 38    -- 探索日志条目高度
    local MAX_VIS = 6     -- 最多显示条目数（超出滚动）

    -- 面板高度：固定高（避免随内容抖动）
    local ph = HEADER + TAB_H + 4 + MAX_VIS * ITEM_H + PAD
    local px, py = DragManager.GetPos("log", W - PW - 8, 50)

    -- 关闭按钮区域（后注册 hit）
    local closeBx = px + PW - 22
    local closeBy = py + 4

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, ph, 8)
    nvgFillColor(vg, nvgRGBA(6, 12, 28, 230))
    nvgFill(vg)
    DragManager.RegisterHandle("log", px, py, PW, 24)
    DragManager.DrawHandle(vg, px, py, PW, 6)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, ph, 8)
    nvgStrokeColor(vg, nvgRGBA(60, 140, 255, 180))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 标题行
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
    nvgText(vg, px + PAD, py + HEADER / 2, "📋 任务日志")
    -- 关闭按钮
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 180, 220, 180))
    nvgText(vg, closeBx + 9, py + HEADER / 2, "✕")

    -- 分隔线
    local sepY = py + HEADER
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 6, sepY); nvgLineTo(vg, px + PW - 6, sepY)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 60))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- Tab 按钮
    local tabY     = sepY + 3
    local tabW     = (PW - PAD * 2) / 2
    local tabs     = { {key="goals", label="目标"}, {key="explore", label="探索记录"} }
    for i, tabDef in ipairs(tabs) do
        local tx     = px + PAD + (i - 1) * tabW
        local active = tab_ == tabDef.key
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW - 3, TAB_H, 4)
        nvgFillColor(vg, active and nvgRGBA(20, 80, 180, 200) or nvgRGBA(14, 30, 60, 160))
        nvgFill(vg)
        nvgStrokeColor(vg, active and nvgRGBA(80, 160, 255, 220) or nvgRGBA(40, 70, 120, 100))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, active and nvgRGBA(180, 220, 255, 255) or nvgRGBA(120, 160, 200, 180))
        nvgText(vg, tx + tabW / 2 - 1, tabY + TAB_H / 2, tabDef.label)
        local capturedKey = tabDef.key
        UICommon.addHit(tx, tabY, tabW - 3, TAB_H, function()
            tab_    = capturedKey
            scroll_ = 0
        end)
    end

    -- 内容区起始 Y
    local contentY = tabY + TAB_H + 6
    local contentH = ph - (contentY - py) - PAD
    -- 裁剪区（用矩形遮罩模拟）
    local clipX = px + 4
    local clipW = PW - 8

    -- ── Tab: 目标 ──
    if tab_ == "goals" then
        local goals     = STAGE_GOALS or {}
        local itemCount = #goals
        local totalH    = itemCount * ITEM_H
        local maxScroll = math.max(0, totalH - contentH)
        scroll_ = math.min(math.max(0, scroll_), maxScroll)

        -- 滚动区域注册
        UICommon.addScroll(clipX, contentY, clipW, contentH, function(delta)
            scroll_ = math.min(math.max(0, scroll_ - delta * 30), maxScroll)
        end)

        local iy = contentY - scroll_
        for _, goal in ipairs(goals) do
            if iy + ITEM_H > contentY - 4 and iy < contentY + contentH then
                local done = completedGoals and completedGoals[goal.id] == true
                -- 条目背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, clipX, iy, clipW, ITEM_H - 3, 5)
                nvgFillColor(vg, done and nvgRGBA(10,40,20,200) or nvgRGBA(12,20,44,200))
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, clipX, iy, clipW, ITEM_H - 3, 5)
                nvgStrokeColor(vg, done and nvgRGBA(40,180,80,100) or nvgRGBA(40,80,160,80))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

                -- 完成指示条（左侧竖线）
                nvgBeginPath(vg)
                nvgRect(vg, clipX, iy + 2, 3, ITEM_H - 7)
                nvgFillColor(vg, done and nvgRGBA(40,200,80,230) or nvgRGBA(60,120,255,150))
                nvgFill(vg)

                -- 目标标题
                nvgFontFace(vg, "sans")
                nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, done and nvgRGBA(100,220,120,240) or nvgRGBA(180,210,255,230))
                nvgText(vg, clipX + 10, iy + 4,
                    (done and "✓ " or "○ ") .. goal.title)

                -- 目标描述
                nvgFontSize(vg, 9)
                nvgFillColor(vg, done and nvgRGBA(80,160,100,180) or nvgRGBA(120,150,200,160))
                nvgText(vg, clipX + 10, iy + 17, goal.desc)

                -- 奖励预览（右侧）
                if not done and goal.reward then
                    local parts = {}
                    for res, amt in pairs(goal.reward) do
                        local lbl = RES_LABELS and RES_LABELS[res] or res
                        parts[#parts+1] = "+" .. amt .. lbl
                    end
                    local rStr = table.concat(parts, " ")
                    nvgFontSize(vg, 8)
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255,210,60,180))
                    nvgText(vg, clipX + clipW - 4, iy + 4, rStr)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                end
            end
            iy = iy + ITEM_H
        end

        -- 无目标时提示
        if #goals == 0 then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 150, 200, 160))
            nvgText(vg, px + PW / 2, contentY + contentH / 2, "暂无阶段目标")
        end

        -- 滚动条（有溢出时显示）
        if maxScroll > 0 then
            local barH   = contentH * contentH / totalH
            local barY   = contentY + scroll_ / maxScroll * (contentH - barH)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, px + PW - 6, barY, 3, barH, 2)
            nvgFillColor(vg, nvgRGBA(60, 140, 255, 160))
            nvgFill(vg)
        end

    -- ── Tab: 探索记录 ──
    else
        local logs      = exploreLog or {}
        local itemCount = #logs
        if itemCount == 0 then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 150, 200, 160))
            nvgText(vg, px + PW / 2, contentY + contentH / 2, "暂无探索记录")
        else
            local totalH    = itemCount * LOG_H
            local maxScroll = math.max(0, totalH - contentH)
            scroll_ = math.min(math.max(0, scroll_), maxScroll)

            -- 滚动区域
            UICommon.addScroll(clipX, contentY, clipW, contentH, function(delta)
                scroll_ = math.min(math.max(0, scroll_ - delta * 30), maxScroll)
            end)

            -- 最新在最前（倒序显示）
            local iy = contentY - scroll_
            for idx = itemCount, 1, -1 do
                local entry = logs[idx]
                if iy + LOG_H > contentY - 4 and iy < contentY + contentH then
                    -- 条目背景
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, clipX, iy, clipW, LOG_H - 3, 4)
                    nvgFillColor(vg, nvgRGBA(10, 24, 48, 200))
                    nvgFill(vg)
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, clipX, iy, clipW, LOG_H - 3, 4)
                    nvgStrokeColor(vg, nvgRGBA(40, 100, 200, 80))
                    nvgStrokeWidth(vg, 0.7); nvgStroke(vg)

                    -- 左竖线（蓝绿色）
                    nvgBeginPath(vg)
                    nvgRect(vg, clipX, iy + 2, 3, LOG_H - 7)
                    nvgFillColor(vg, nvgRGBA(40, 200, 180, 200))
                    nvgFill(vg)

                    -- 图标 + 任务名
                    nvgFontFace(vg, "sans")
                    nvgFontSize(vg, 11)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(160, 220, 255, 230))
                    nvgText(vg, clipX + 9, iy + 3,
                        (entry.icon or "🔭") .. " " .. (entry.label or "未知任务"))

                    -- 奖励摘要
                    nvgFontSize(vg, 9)
                    nvgFillColor(vg, nvgRGBA(100, 200, 140, 200))
                    nvgText(vg, clipX + 9, iy + 16, entry.rewardStr or "")

                    -- 时间戳（右对齐）
                    nvgFontSize(vg, 8)
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(100, 130, 180, 160))
                    nvgText(vg, clipX + clipW - 4, iy + 3, entry.timeStr or "")
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                end
                iy = iy + LOG_H
            end

            -- 滚动条
            if maxScroll > 0 then
                local barH = contentH * contentH / totalH
                local barY = contentY + scroll_ / maxScroll * (contentH - barH)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px + PW - 6, barY, 3, barH, 2)
                nvgFillColor(vg, nvgRGBA(40, 200, 180, 160))
                nvgFill(vg)
            end
        end
    end

    -- 关闭按钮 hit
    UICommon.addHit(closeBx, closeBy, 20, 20, function()
        visible_ = false
        scroll_  = 0
    end)
    -- 面板遮罩（点击面板内部不穿透）
    UICommon.addHit(px, py, PW, ph, function() end)
end

return LogPanel
