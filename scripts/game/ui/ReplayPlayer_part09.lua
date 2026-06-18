-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


    -- 播放头（圆形滑块）
    local headX = barX + barW * progress
    nvgBeginPath(vg)
    nvgCircle(vg, headX, barY + barH / 2, 7 * ease)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, math.floor(255 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 140, 255, math.floor(200 * ease)))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 时间轴拖拽区域（整个条区域）
    addHit(barX - 4, barY - 10, barW + 8, barH + 20, function()
        -- 计算鼠标在时间轴上的位置
        local mx = UICommon.cursorX / UICommon.uiScale
        local rel = (mx - barX) / barW
        rel = math.max(0, math.min(1, rel))
        currentTime_ = rel * duration_
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
    end)

    -- 控制按钮区域 (在时间条下方)
    local ctrlY = barY + barH + 8

    -- 播放/暂停按钮
    local btnSize = 24
    local playX = tlX + tlW / 2 - btnSize / 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, playX, ctrlY, btnSize, btnSize, 6)
    nvgFillColor(vg, nvgRGBA(30, 60, 100, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, math.floor(180 * ease)))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 230, 255, math.floor(240 * ease)))
    nvgText(vg, playX + btnSize / 2, ctrlY + btnSize / 2, playing_ and "⏸" or "▶")

    addHit(playX, ctrlY, btnSize, btnSize, function()
        playing_ = not playing_
    end)

    -- 倍速按钮（播放按钮右侧）
    local spdX = playX + btnSize + 12
    local spdW = 36
    nvgBeginPath(vg)
    nvgRoundedRect(vg, spdX, ctrlY + 2, spdW, btnSize - 4, 5)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(180 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 200, math.floor(150 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 220, 255, math.floor(240 * ease)))
    nvgText(vg, spdX + spdW / 2, ctrlY + btnSize / 2, speed_ .. "×")

    addHit(spdX, ctrlY, spdW, btnSize, function()
        -- 循环切换倍速
        local idx = 1
        for i, s in ipairs(SPEEDS) do
            if s == speed_ then idx = i; break end
        end
        speed_ = SPEEDS[(idx % #SPEEDS) + 1]
    end)

    -- 后退5秒按钮（播放按钮左侧）
    local backX = playX - btnSize - 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, ctrlY + 2, btnSize, btnSize - 4, 5)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(180 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 180, math.floor(150 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 200, 220, math.floor(220 * ease)))
    nvgText(vg, backX + btnSize / 2, ctrlY + btnSize / 2, "⏪")

    addHit(backX, ctrlY, btnSize, btnSize, function()
        currentTime_ = math.max(0, currentTime_ - 5)
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
    end)

    -- 前进5秒按钮（倍速右侧）
    local fwdX = spdX + spdW + 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, fwdX, ctrlY + 2, btnSize, btnSize - 4, 5)
    nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(180 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 180, math.floor(150 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 200, 220, math.floor(220 * ease)))
    nvgText(vg, fwdX + btnSize / 2, ctrlY + btnSize / 2, "⏩")

    addHit(fwdX, ctrlY, btnSize, btnSize, function()
        currentTime_ = math.min(duration_, currentTime_ + 5)
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
    end)

    -- 时间显示（左侧当前时间 / 右侧总时长）
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 180, 220, math.floor(200 * ease)))
    nvgText(vg, barX, ctrlY + btnSize / 2, formatTime(currentTime_))

    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, barX + barW, ctrlY + btnSize / 2, formatTime(duration_))
end

-- ============================================================================
-- 渲染：事件弹幕
-- ============================================================================
