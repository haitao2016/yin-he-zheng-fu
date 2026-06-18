-- Auto-split from TutorialSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function TutorialSystem.TriggerPhase(phaseName)
    if not enabled_ then return end
    if phaseDone_[phaseName] then return end

    local steps = PHASES[phaseName]
    if not steps then return end

    -- 过滤已完成步骤
    local queue = {}
    for _, s in ipairs(steps) do
        if not completed_[s.id] then
            queue[#queue + 1] = s
        end
    end

    if #queue == 0 then
        phaseDone_[phaseName] = true
        return
    end

    -- 入队并开始显示
    stepQueue_ = queue
    stepIdx_   = 0
    TutorialSystem._ShowNext()
    print(string.format("[P3-3 Tutorial] 触发阶段: %s (%d步)", phaseName, #queue))
end

--- 兼容旧接口：TriggerStart → TriggerPhase("intro")
function TutorialSystem.TriggerStart()
    TutorialSystem.TriggerPhase("intro")
end

--- 兼容旧接口：TriggerDeployed → TriggerPhase("deployed")
function TutorialSystem.TriggerDeployed()
    TutorialSystem.TriggerPhase("deployed")
end

--- 强制跳过整个教程
function TutorialSystem.Skip()
    active_      = false
    currentStep_ = nil
    stepQueue_   = {}
    stepIdx_     = 0
    -- 标记所有阶段完成
    for _, phase in ipairs(PHASE_ORDER) do
        phaseDone_[phase] = true
    end
    completed_["tutorial_done"] = true
end

--- 是否当前有教程弹窗在显示
function TutorialSystem.IsActive()
    return active_
end

--- 每帧更新（动画计时）
function TutorialSystem.Update(dt)
    if not active_ then return end
    animT_ = math.min(1, animT_ + dt / ANIM_DUR)
    pulseT_ = pulseT_ + dt  -- 脉冲持续累加
end

-- ============================================================================
-- 内部：显示下一步
-- ============================================================================
function TutorialSystem._ShowNext()
    stepIdx_ = stepIdx_ + 1
    if stepIdx_ > #stepQueue_ then
        active_      = false
        currentStep_ = nil
        return
    end
    currentStep_ = stepQueue_[stepIdx_]
    active_      = true
    animT_       = 0
end

function TutorialSystem._OnConfirm()
    if not currentStep_ then return end
    completed_[currentStep_.id] = true
    if currentStep_.isLast then
        TutorialSystem.Skip()
        return
    end
    TutorialSystem._ShowNext()
end

-- ============================================================================
-- 渲染：脉冲高亮效果
-- ============================================================================
local function renderPulseHighlight(vg, hx, hy, hw, hh, ease)
    -- 呼吸脉冲参数（正弦曲线 0.5~1.0 变化）
    local pulse = 0.5 + 0.5 * math.sin(pulseT_ * 3.0)
    local borderAlpha = math.floor((120 + 100 * pulse) * ease)
    local glowAlpha   = math.floor((20 + 30 * pulse) * ease)

    -- 内部高亮填充（呼吸明灭）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, hx - 2, hy - 2, hw + 4, hh + 4, 6)
    nvgFillColor(vg, nvgRGBA(60, 160, 255, glowAlpha))
    nvgFill(vg)

    -- 外层脉冲描边
    nvgBeginPath(vg)
    nvgRoundedRect(vg, hx - 2, hy - 2, hw + 4, hh + 4, 6)
    nvgStrokeColor(vg, nvgRGBA(80, 200, 255, borderAlpha))
    nvgStrokeWidth(vg, 2.0 + pulse)
    nvgStroke(vg)

    -- 扩散光环（每个脉冲周期扩散一次）
    local ringPhase = (pulseT_ * 1.5) % 1.0
    local ringAlpha = math.floor(80 * (1 - ringPhase) * ease)
    local ringExpand = ringPhase * 6
    if ringAlpha > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, hx - 2 - ringExpand, hy - 2 - ringExpand,
            hw + 4 + ringExpand * 2, hh + 4 + ringExpand * 2, 8)
        nvgStrokeColor(vg, nvgRGBA(100, 180, 255, ringAlpha))
        nvgStrokeWidth(vg, 1.0)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 渲染：获取高亮区域实际像素坐标
-- ============================================================================
local function getHighlightRect(vg, screenW, screenH, highlight)
    if not highlight then return nil end

    local TOPBAR_H = UICommon.TOPBAR_H or 44

    if highlight == "topbar" then
        return 0, 0, screenW, TOPBAR_H + 2
    elseif highlight == "fleet" then
        -- 右下角编队面板区域（大致）
        local fw, fh = 180, 200
        return screenW - fw - 8, screenH - fh - 8, fw, fh
    elseif highlight == "tech" then
        -- 左侧科研面板区域（大致）
        local tw, th = 180, 200
        return 8, TOPBAR_H + 10, tw, th
    elseif type(highlight) == "table" then
        return highlight[1], highlight[2], highlight[3], highlight[4]
    end

    return nil
end

-- ============================================================================
-- 主渲染入口
-- ============================================================================
function TutorialSystem.Render()
    if not active_ or not currentStep_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    if not vg or not screenW then return end

    local step = currentStep_
    local ease = animT_ * animT_ * (3 - 2 * animT_)  -- smoothstep

    -- ——— 半透明遮罩（整屏）———
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 20, math.floor(170 * ease)))
    nvgFill(vg)

    -- ——— 脉冲高亮区域 ———
    local hlX, hlY, hlW, hlH = getHighlightRect(vg, screenW, screenH, step.highlight)
    if hlX then
        -- 在遮罩上挖出半透明亮区（略微可见底下内容）
        nvgBeginPath(vg)
        nvgRoundedRect(vg, hlX, hlY, hlW, hlH, 4)
        nvgFillColor(vg, nvgRGBA(0, 0, 20, math.floor(170 * ease)))  -- 同遮罩色取反效果
        nvgFill(vg)
        -- 用 globalCompositeOp 不方便，改为用一个"减淡"矩形模拟
        nvgBeginPath(vg)
        nvgRoundedRect(vg, hlX, hlY, hlW, hlH, 4)
        nvgFillColor(vg, nvgRGBA(20, 40, 80, math.floor(100 * ease)))
        nvgFill(vg)
        -- 脉冲描边
        renderPulseHighlight(vg, hlX, hlY, hlW, hlH, ease)
    end

    -- ——— 弹窗尺寸与位置 ———
    local PW, PH = 340, 220
    -- 根据行数自动调整高度
    local lineCount = select(2, step.body:gsub("\n", "\n")) + 1
    PH = 80 + lineCount * 18 + 50

    local px, py
    local anchor = step.anchor or "center"
    local TOPBAR_H = UICommon.TOPBAR_H or 44

    if anchor == "center" then
        px = (screenW - PW) / 2
        py = (screenH - PH) / 2
    elseif anchor == "top" then
        px = (screenW - PW) / 2
        py = TOPBAR_H + 10
    elseif anchor == "bottom" then
        px = (screenW - PW) / 2
        py = screenH - PH - 20
    elseif anchor == "left" then
        px = 16
        py = math.max(TOPBAR_H + 4, (screenH - PH) / 2)
    elseif anchor == "right" then
        px = screenW - PW - 16
        py = math.max(TOPBAR_H + 4, (screenH - PH) / 2)
    else
        px = (screenW - PW) / 2
        py = (screenH - PH) / 2
    end

    -- 动画：从屏幕外滑入
    local slideOff = (1 - ease) * 30
    py = py + slideOff

    -- ——— 面板背景 ———
    -- 外层光晕
    local shadow = nvgBoxGradient(vg, px - 4, py - 4, PW + 8, PH + 8, 10, 16,
        nvgRGBA(40, 100, 240, math.floor(80 * ease)),
        nvgRGBA(0, 0, 20, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px - 8, py - 8, PW + 16, PH + 16, 14)
    nvgFillPaint(vg, shadow)
    nvgFill(vg)

    -- 面板本体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 10)
    nvgFillColor(vg, nvgRGBA(12, 18, 36, math.floor(245 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 130, 255, math.floor(200 * ease)))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 顶部标题渐变条
    local titleGrad = nvgLinearGradient(vg, px, py, px + PW, py,
        nvgRGBA(20, 60, 180, math.floor(200 * ease)),
        nvgRGBA(40, 20, 120, math.floor(160 * ease)))
    nvgBeginPath(vg)
    nvgRoundedRectVarying(vg, px, py, PW, 34, 10, 10, 0, 0)
    nvgFillPaint(vg, titleGrad)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- ——— 阶段标签（左上角） ———
    local phaseLabel = ""
    if step.id then
        for pi, pn in ipairs(PHASE_ORDER) do
            local psteps = PHASES[pn]
            for _, ps in ipairs(psteps) do
                if ps.id == step.id then
                    phaseLabel = string.format("阶段 %d/%d", pi, #PHASE_ORDER)
                    break
                end
            end
            if phaseLabel ~= "" then break end
        end
    end
    if phaseLabel ~= "" then
        nvgFontSize(vg, 8)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 140, 220, math.floor(160 * ease)))
        nvgText(vg, px + 10, py + 17, phaseLabel)
    end

    -- ——— 标题文字 ———
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 230, 255, math.floor(255 * ease)))
    nvgText(vg, px + PW / 2, py + 17, step.title or "")

    -- ——— 步骤进度（右上角小字） ———
    local total = #stepQueue_
    if total > 1 then
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(100, 140, 200, math.floor(180 * ease)))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + PW - 10, py + 17,
            string.format("%d / %d", stepIdx_, total))
    end

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 34)
    nvgLineTo(vg, px + PW - 16, py + 34)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 220, math.floor(100 * ease)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- ——— 正文多行文字 ———
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))

    local textX = px + 18
    local textY = py + 42
    local lineH = 17

    local body = step.body or ""
    local lineNum = 0
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        if line:sub(1, 3) == "•" or line:sub(1, 1) == "•" then
            nvgFillColor(vg, nvgRGBA(100, 200, 255, math.floor(200 * ease)))
            nvgText(vg, textX, textY + lineNum * lineH, line)
            nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))
        elseif line:find("^①") or line:find("^②") or line:find("^③") then
            nvgFillColor(vg, nvgRGBA(120, 255, 160, math.floor(220 * ease)))
            nvgText(vg, textX, textY + lineNum * lineH, line)
            nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))
        elseif line:find("×") then
            nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(220 * ease)))
            nvgText(vg, textX, textY + lineNum * lineH, line)
            nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))
        else
            nvgText(vg, textX, textY + lineNum * lineH, line)
        end
        lineNum = lineNum + 1
    end

    -- ——— 确认按钮 ———
    local btnW, btnH = 120, 28
    local btnX = px + PW - btnW - 16
    local btnY = py + PH - btnH - 14

    -- 跳过按钮（左下角）
    local skipW, skipH = 80, 26
    local skipX = px + 14
    local skipY = py + PH - skipH - 14

    local isSkipHover = false
    if UICommon.cursorX and UICommon.cursorY then
        isSkipHover = UICommon.cursorX >= skipX and UICommon.cursorX <= skipX + skipW
                   and UICommon.cursorY >= skipY and UICommon.cursorY <= skipY + skipH
    end

    -- 跳过按钮背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, skipX, skipY, skipW, skipH, 5)
    nvgFillColor(vg, nvgRGBA(40, 50, 80, math.floor((isSkipHover and 180 or 110) * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 130, 200, math.floor((isSkipHover and 200 or 130) * ease)))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 180, 230, math.floor(220 * ease)))
    nvgText(vg, skipX + skipW / 2, skipY + skipH / 2, "跳过全部")

    -- 全屏遮罩拦截（必须最先注册：OnClick 为"后注册优先"，最先注册者最后命中，
    -- 这样既能阻止点击穿透到下方星图，又不会抢占下方按钮的点击）
    addHit(0, 0, screenW, screenH, function() end)

    -- 面板拦截
    addHit(px, py, PW, PH, function() end)

    -- 跳过按钮点击区
    addHit(skipX, skipY, skipW, skipH, function()
        TutorialSystem.Skip()
    end)

    -- 确认按钮
    local hover = false
    if UICommon.cursorX and UICommon.cursorY then
        hover = UICommon.cursorX >= btnX and UICommon.cursorX <= btnX + btnW
             and UICommon.cursorY >= btnY and UICommon.cursorY <= btnY + btnH
    end
    local fillA = hover and 230 or 200
    local grad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(30, 100, 240, fillA),
        nvgRGBA(15, 60, 160, fillA))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
    nvgFillPaint(vg, grad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, hover and 255 or 180))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, math.floor(255 * ease)))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, step.btnText or "下一步")

    addHit(btnX, btnY, btnW, btnH, function()
        TutorialSystem._OnConfirm()
    end)
end

-- ============================================================================
-- 存档支持（与游戏云存档集成）
-- ============================================================================

--- 序列化已完成步骤 + 阶段 + 开关状态（用于云存档）
function TutorialSystem.Serialize()
    local steps = {}
    for k, v in pairs(completed_) do
        if v then steps[#steps + 1] = k end
    end
    local phases = {}
    for k, v in pairs(phaseDone_) do
        if v then phases[#phases + 1] = k end
    end
    return {
        steps   = steps,
        phases  = phases,
        enabled = enabled_,
    }
end

--- 从云存档恢复（兼容旧格式）
function TutorialSystem.Deserialize(data)
    if not data then return end

    -- 兼容旧格式（纯数组 = 已完成步骤 ID 列表）
    if data[1] ~= nil or (type(data) == "table" and not data.steps) then
        local list = data.steps or data
        for _, k in ipairs(list) do
            completed_[k] = true
        end
        -- 旧格式没有阶段信息，根据已完成步骤推断
        if completed_["tutorial_done"] then
            for _, p in ipairs(PHASE_ORDER) do phaseDone_[p] = true end
        end
        return
    end

    -- 新格式
    if data.steps then
        for _, k in ipairs(data.steps) do completed_[k] = true end
    end
    if data.phases then
        for _, k in ipairs(data.phases) do phaseDone_[k] = true end
    end
    if data.enabled ~= nil then
        enabled_ = data.enabled ~= false
    end
end

--- 查询教程是否已全部完成
function TutorialSystem.IsDone()
    return completed_["tutorial_done"] == true
end

return TutorialSystem
