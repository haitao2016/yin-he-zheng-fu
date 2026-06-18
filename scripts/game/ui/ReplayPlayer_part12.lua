-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function renderMVPBanner(vg, x, y, w, ease)
    if not mvp_ then return end
    local h = 28

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(30, 20, 0, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 180, 40, math.floor(140 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(240 * ease)))
    local mvpText = string.format("⭐ MVP: %s — %s (伤害:%d 击杀:%d)",
        mvp_.stype or "?", mvp_.reason or "", mvp_.dmg or 0, mvp_.kills or 0)
    nvgText(vg, x + w / 2, y + h / 2, mvpText)
end

-- ============================================================================
-- 渲染：精彩时刻列表（侧栏）
-- ============================================================================
local function renderHighlightList(vg, lx, ly, lw, lh, ease)
    local addHit = UICommon.addHit

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, lx, ly, lw, lh, 6)
    nvgFillColor(vg, nvgRGBA(8, 14, 30, math.floor(220 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 160, math.floor(100 * ease)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(220 * ease)))
    nvgText(vg, lx + 8, ly + 6, "⭐ 精彩时刻")

    -- 列表
    local iy = ly + 24
    local itemH = 32
    for i, hl in ipairs(highlights_) do
        if iy + itemH > ly + lh then break end

        local isNear = math.abs(currentTime_ - hl.peakTime) < 1.0
        -- 条目背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, lx + 4, iy, lw - 8, itemH - 3, 4)
        if isNear then
            nvgFillColor(vg, nvgRGBA(40, 60, 20, math.floor(200 * ease)))
        else
            nvgFillColor(vg, nvgRGBA(12, 20, 40, math.floor(180 * ease)))
        end
        nvgFill(vg)

        -- 时间标签
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(100, 180, 255, math.floor(200 * ease)))
        nvgText(vg, lx + 10, iy + 3, formatTime(hl.peakTime))

        -- 描述
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(180, 210, 240, math.floor(200 * ease)))
        local desc = hl.desc or ""
        if #desc > 14 then desc = desc:sub(1, 14) .. "…" end
        nvgText(vg, lx + 10, iy + 15, desc)

        -- 评分星星
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(255, 200, 40, math.floor(200 * ease)))
        local stars = math.min(5, math.floor(hl.score / 10))
        nvgText(vg, lx + lw - 8, iy + 3, string.rep("★", stars))

        -- 点击跳转
        addHit(lx + 4, iy, lw - 8, itemH - 3, function()
            currentTime_ = hl.peakTime
            currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)
        end)

        iy = iy + itemH
    end

    if #highlights_ == 0 then
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 160, math.floor(150 * ease)))
        nvgText(vg, lx + lw / 2, ly + lh / 2, "无精彩时刻")
    end
end

-- ============================================================================
-- 主渲染
-- ============================================================================
local function renderReplayPlayer()
    if not active_ then return end

    local vg       = UICommon.vg
    local addHit   = UICommon.addHit
    local screenW, screenH = UICommon.getVirtualSize()

    local ease = easeOutCubic(math.min(1, animT_ / 0.5))
    if ease <= 0 then return end

    -- 全屏半透明背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(2, 6, 14, math.floor(240 * ease)))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, math.floor(240 * ease)))
    nvgText(vg, screenW / 2, 8, "🎬 战斗回放")

    -- 关闭按钮（右上角）
    local closeX = screenW - 40
    local closeY = 6
    local closeW, closeH = 32, 22
    nvgBeginPath(vg)
    nvgRoundedRect(vg, closeX, closeY, closeW, closeH, 5)
    nvgFillColor(vg, nvgRGBA(60, 20, 20, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 80, 80, math.floor(180 * ease)))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(240, 140, 140, math.floor(240 * ease)))
    nvgText(vg, closeX + closeW / 2, closeY + closeH / 2, "✕")
    addHit(closeX, closeY, closeW, closeH, function()
        ReplayPlayer.Hide()
    end)

    -- 布局计算
    local hlListW = 140    -- 精彩列表宽度
    local mapX    = MAP_MARGIN
    local mapY    = 30
    local mapW    = screenW - MAP_MARGIN * 2 - hlListW - 10
    local mapH    = screenH - TIMELINE_H - 70 - 30  -- 减去标题/MVP/时间轴

    -- MVP 横幅（地图上方）
    renderMVPBanner(vg, mapX, mapY, mapW, ease)
    mapY = mapY + 32

    -- 迷你战场地图
    mapH = screenH - mapY - TIMELINE_H - 50
    renderBattleMap(vg, mapX, mapY, mapW, mapH, ease)

    -- 事件弹幕（叠在地图上）
    renderEventPopups(vg, mapX, mapY, mapW, mapH, ease)

    -- 精彩时刻侧栏（地图右侧）
    local hlX = mapX + mapW + 10
    local hlY = mapY
    local hlH = mapH + 32  -- 包含 MVP 区域高度
    renderHighlightList(vg, hlX, hlY, hlListW, hlH, ease)

    -- 时间轴 + 控制条（底部）
    local tlY = screenH - TIMELINE_H - 12
    renderTimeline(vg, 0, tlY, screenW, TIMELINE_H, ease)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 每帧更新
---@param dt number
function ReplayPlayer.Update(dt)
    if not active_ then return end

    -- 进场动画
    if animT_ < 0.5 then
        animT_ = animT_ + dt
    end

    -- 播放推进
    if playing_ and duration_ > 0 then
        local prevTime = currentTime_
        currentTime_ = currentTime_ + dt * speed_

        if currentTime_ >= duration_ then
            currentTime_ = duration_
            playing_ = false
        end

        -- 更新当前帧
        currentFrame_ = BattleReplaySystem.GetFrameAt(currentTime_)

        -- 检查新事件（生成弹幕）
        local newEvents = BattleReplaySystem.GetEventsInRange(prevTime, currentTime_)
        for _, ev in ipairs(newEvents) do
            if #eventPopups_ >= MAX_POPUPS then
                table.remove(eventPopups_, 1)
            end
            local desc = BattleReplaySystem._describeEvent(ev)
            if desc and desc ~= "" then
                eventPopups_[#eventPopups_ + 1] = {
                    text  = desc,
                    alpha = 1.0,
                    timer = EVENT_POPUP_DUR,
                }
            end
        end
    end

    -- 弹幕淡出
    for i = #eventPopups_, 1, -1 do
        local popup = eventPopups_[i]
        popup.timer = popup.timer - dt
        if popup.timer <= 0 then
            table.remove(eventPopups_, i)
        else
            popup.alpha = math.min(1, popup.timer / 0.5)
        end
    end
end

--- 渲染
function ReplayPlayer.Render()
    renderReplayPlayer()
end

--- 显示回放播放器
function ReplayPlayer.Show()
    -- 加载回放数据
    frames_     = BattleReplaySystem.GetFrames()
    events_     = BattleReplaySystem.GetEvents()
    highlights_ = BattleReplaySystem.GetHighlights()
    mvp_        = BattleReplaySystem.GetMVP()
    duration_   = BattleReplaySystem.GetDuration()

    if #frames_ == 0 then
        print("[P3-2 ReplayPlayer] 无帧数据，无法播放")
        return false
    end

    active_       = true
    animT_        = 0
    playing_      = false
    speed_        = 1
    currentTime_  = 0
    currentFrame_ = frames_[1]
    eventPopups_  = {}
    dragging_     = false

    print(string.format("[P3-2 ReplayPlayer] 打开回放: %d帧, %.1f秒, %d精彩",
        #frames_, duration_, #highlights_))
    return true
end

--- 隐藏回放播放器
function ReplayPlayer.Hide()
    active_       = false
    playing_      = false
    currentFrame_ = nil
    eventPopups_  = {}
    animT_        = 0
    if onClose_ then onClose_() end
end

--- 是否活跃
function ReplayPlayer.IsActive()
    return active_
end

--- 设置关闭回调
---@param fn function
function ReplayPlayer.SetOnClose(fn)
    onClose_ = fn
end

return ReplayPlayer
