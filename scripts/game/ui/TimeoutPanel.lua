-- ============================================================================
-- game/ui/TimeoutPanel.lua  -- 在线时间超时覆盖层
-- ============================================================================
local UICommon = require "game.ui.UICommon"

local TimeoutPanel = {}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local active_    = false   -- 是否显示
local adCount_   = 0       -- 剩余可看广告次数（最多2次）
local onWatch_   = nil     -- 点击"看广告"后的回调

-- ── 渲染 ─────────────────────────────────────────────────────────────────────
local function render()
    if not active_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    -- 全屏半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
    nvgFill(vg)

    -- 中心对话框
    local dw, dh = 460, 280
    local dx = (screenW - dw) / 2
    local dy = (screenH - dh) / 2

    -- 边框发光效果
    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx-2, dy-2, dw+4, dh+4, 14)
    nvgFillColor(vg, nvgRGBA(200, 60, 60, 80))
    nvgFill(vg)

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx, dy, dw, dh, 12)
    nvgFillColor(vg, nvgRGBA(12, 8, 20, 250))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 60, 60, 220))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 图标（警告符号）
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 36)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 80, 60, 255))
    nvgText(vg, screenW / 2, dy + 50, "⏰")

    -- 标题
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(255, 100, 80, 255))
    nvgText(vg, screenW / 2, dy + 90, "在线时间已到！")

    -- 说明文字
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 220))
    nvgText(vg, screenW / 2, dy + 116, "您今日的2小时免费游玩时间已用完。")
    nvgText(vg, screenW / 2, dy + 135, "观看一段广告可延长1小时游玩，最多可延长2次。")

    -- 剩余次数显示
    nvgFontSize(vg, 13)
    local countColor = adCount_ > 0 and nvgRGBA(80,220,150,255) or nvgRGBA(150,150,160,200)
    nvgFillColor(vg, countColor)
    nvgText(vg, screenW / 2, dy + 163,
        "剩余可用次数：" .. adCount_ .. " / 2")

    -- 看广告按钮
    if adCount_ > 0 then
        local bw2, bh2 = 220, 44
        local bx2 = (screenW - bw2) / 2
        local by2 = dy + dh - 90

        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx2, by2, bw2, bh2, 8)
        nvgFillColor(vg, nvgRGBA(40, 160, 80, 230))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 240, 120, 200))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(220, 255, 230, 255))
        nvgText(vg, screenW / 2, by2 + bh2 / 2, "▶  观看广告 延长1小时")

        addHit(bx2, by2, bw2, bh2, function()
            if onWatch_ then onWatch_() end
        end)
    else
        -- 无广告次数
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(160, 160, 160, 200))
        nvgText(vg, screenW / 2, dy + dh - 68, "今日广告延时次数已用完，请明天再来。")
    end

    -- 退出说明（小字）
    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(120, 120, 140, 160))
    nvgText(vg, screenW / 2, dy + dh - 20,
        "已自动断开服务器。感谢游玩《银河征服》！")
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 显示超时覆盖层
---@param adCount number  剩余可看广告次数
---@param onWatch  function 点击"看广告"按钮的回调
function TimeoutPanel.Show(adCount, onWatch)
    active_   = true
    adCount_  = adCount or 0
    onWatch_  = onWatch
end

--- 更新广告次数（看完广告后调用）
function TimeoutPanel.UpdateAdCount(n)
    adCount_ = n or 0
end

--- 隐藏超时覆盖层
function TimeoutPanel.Hide()
    active_ = false
end

--- 是否当前可见
function TimeoutPanel.IsActive()
    return active_
end

--- 渲染（每帧调用）
function TimeoutPanel.Render()
    render()
end

return TimeoutPanel
