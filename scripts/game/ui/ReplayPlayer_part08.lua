-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function renderTimeline(vg, tlX, tlY, tlW, tlH, ease)
    local addHit = UICommon.addHit

    -- 时间轴背景条
    local barH = 6
    local barY = tlY + 10
    local barX = tlX + TIMELINE_PAD
    local barW = tlW - TIMELINE_PAD * 2

    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(20, 30, 50, math.floor(220 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(40, 80, 140, math.floor(100 * ease)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 已播放进度
    local progress = (duration_ > 0) and (currentTime_ / duration_) or 0
    if progress > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * progress, barH, 3)
        local grad = nvgLinearGradient(vg, barX, barY, barX + barW * progress, barY,
            nvgRGBA(40, 120, 255, math.floor(200 * ease)),
            nvgRGBA(60, 180, 255, math.floor(240 * ease)))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
    end

    -- 精彩时刻标记（金色菱形）
    for _, hl in ipairs(highlights_) do
        local hlPos = (duration_ > 0) and (hl.peakTime / duration_) or 0
        local hlX = barX + barW * hlPos
        local hlSize = 5

        nvgBeginPath(vg)
        nvgMoveTo(vg, hlX, barY - hlSize)
        nvgLineTo(vg, hlX + hlSize, barY + barH / 2)
        nvgLineTo(vg, hlX, barY + barH + hlSize)
        nvgLineTo(vg, hlX - hlSize, barY + barH / 2)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 40, math.floor(220 * ease)))
        nvgFill(vg)

        -- 点击精彩标记跳转
        addHit(hlX - 8, barY - 8, 16, barH + 16, function()
            currentTime_ = hl.peakTime
            currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
        end)
    end
