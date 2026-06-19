-- ============================================================================
-- game/ui/UICommon.lua  -- UI 子模块共享上下文与工具函数
-- 所有面板子模块通过 require("game.ui.UICommon") 获取共享状态
-- ============================================================================

local UICommon = {}

-- ============================================================================
-- 颜色主题常量
-- ============================================================================
UICommon.C = {
    -- 面板背景
    panelBg          = {8,  12,  28,  220},
    panelBgDark      = {5,  15,  30,  248},
    panelBorder      = {60, 140, 255, 180},
    panelBorderDim   = {60, 120, 220, 80},

    -- 文字
    textPrimary      = {200, 220, 255, 255},
    textSecondary    = {120, 160, 200, 140},
    textTitle        = {100, 200, 255, 255},
    textSubtitle     = {160, 200, 255, 200},
    textMuted        = {100, 150, 255, 140},

    -- 状态色
    green            = {30,  180, 80,  220},
    greenDim         = {60,  140, 60,  180},
    greenText        = {160, 255, 160, 255},
    red              = {220, 50,  50,  240},
    redDim           = {200, 60,  60,  180},
    yellow           = {255, 220, 60,  255},
    yellowDim        = {255, 220, 80,  200},
    orange           = {255, 180, 60,  240},
    orangeDim        = {255, 180, 60,  220},

    -- 蓝色系（按钮/选中）
    blueBtnBg        = {20,  80,  180, 200},
    blueBtnBgDim     = {20,  40,  80,  160},
    blueBtnBorder    = {80,  160, 255, 220},
    blueBtnBorderDim = {60,  100, 180, 120},
    blueHighlight    = {68,  136, 255, 140},
    blueDeep         = {30,  60,  100, 180},
    blueBright       = {80,  180, 255, 200},
    blueAccent       = {100, 170, 255, 230},
    blueNav          = {40,  120, 220, 200},
}

-- ============================================================================
-- 布局常量（与 GameUI.lua 保持同步，手机横屏 867×390 20:9 优化）
-- ============================================================================
UICommon.TOPBAR_H  = 44    -- 顶部资源栏高度（px）
UICommon.PANEL_TOP = 48    -- 所有面板的顶部起始 y（TopBar 下方 4px 间隔）

-- 右侧面板宽度（供 FleetPanel 等计算精确偏移，避免重叠）
UICommon.PLANET_PANEL_W     = 275   -- PlanetPanel / BasePanel 展开宽度
UICommon.PLANET_PANEL_RIGHT = 12    -- 右侧面板距屏幕右边缘距离
UICommon.FLEET_PANEL_W      = 248   -- FleetPanel 展开宽度
UICommon.FLEET_PANEL_GAP    = 6     -- FleetPanel 与 PlanetPanel 之间间隙
-- FleetPanel 右边缘偏移 = 275 + 12 + 6 = 293

-- TechPanel 当前帧渲染高度（由 TechPanel.Render 每帧更新，供 Shipyard 定位）
UICommon.techPanelH = 0

-- ============================================================================
-- 共享运行时上下文（由 GameUI.Init 注入，供各面板读取）
-- ============================================================================
---@type userdata        NanoVG context
UICommon.vg            = nil
UICommon.screenW       = 800
UICommon.screenH       = 600

-- UI 全局缩放比（由 getVirtualSize 每帧更新）
-- 设计基准高度 390px（20:9 手机横屏逻辑分辨率）
-- 范围 0.65（小屏手机）→ 1.5（PC / 平板，上限防止面板过大）
UICommon.uiScale       = 1.0
UICommon.REF_H         = 390

--- 计算虚拟屏幕尺寸（代替各模块直接调用 graphics:GetWidth/Height/DPR）
--- 同时更新 UICommon.uiScale，供 nvgScale 使用
---@return number virtualW, number virtualH
function UICommon.getVirtualSize()
    local dpr   = graphics:GetDPR()
    local logW  = graphics:GetWidth()  / dpr
    local logH  = graphics:GetHeight() / dpr
    local scale = math.max(0.65, math.min(1.5, logH / UICommon.REF_H))
    UICommon.uiScale = scale
    return math.floor(logW / scale), math.floor(logH / scale)
end
UICommon.cursorX       = 0
UICommon.cursorY       = 0

-- 数据依赖（由 Init 注入）
---@type table   ResourceManager 实例
UICommon.rm            = nil
---@type table   BuildingSystem
UICommon.bs            = nil
---@type table   BaseBuildingSystem
UICommon.bbs           = nil
---@type table   ResearchSystem
UICommon.rs            = nil
---@type table   MarketSystem
UICommon.ms            = nil
---@type table   PlayerProfile
UICommon.player        = nil
---@type table   FleetManager
UICommon.fm            = nil
UICommon.spq           = nil
UICommon.pirateAI      = nil   -- P1-3: 海盗 AI 引用（供情报面板查询）
UICommon.resIcons      = {}

-- ============================================================================
-- 工具函数（由 GameUI 注入，子模块读取后调用）
-- ============================================================================
-- 这些函数依赖 vg，在 GameUI 初始化后通过 UICommon.bindFns() 注入

---@type fun(r:number,g:number,b:number,a?:number):userdata
UICommon.clr   = nil   -- nvgRGBA 包装

---@type fun(c:table):userdata
UICommon.clrC  = nil   -- 从颜色常量表生成 nvgColor

---@type fun(x:number,y:number,w:number,h:number,r:number,bg:table,border?:table)
UICommon.panel = nil   -- 绘制圆角矩形面板

---@type fun(x:number,y:number,str:string,size:number,r:number,g:number,b:number,a?:number,align?:number)
UICommon.text  = nil   -- 绘制文本

---@type fun(x:number,y:number,w:number,h:number,fn:function)
UICommon.addHit    = nil   -- 注册点击区域

---@type fun(x:number,y:number,w:number,h:number,fn:function)
UICommon.addScroll = nil   -- 注册滚动区域

---@type fun(x:number,y:number,w:number,h:number,label:string,r:number,g:number,b:number,onClick?:function):number
UICommon.drawButton = nil  -- 绘制小按钮，返回底部 y

---@type fun(x:number,y:number,w:number,h:number,pct:number,label?:string,barR:number,barG:number,barB:number)
UICommon.progressBar = nil -- 进度条

--- 由 GameUI 在初始化后调用，将工具函数绑定到 UICommon
function UICommon.bindFns(fns)
    UICommon.clr         = fns.clr
    UICommon.clrC        = fns.clrC
    UICommon.panel       = fns.panel
    UICommon.text        = fns.text
    UICommon.addHit      = fns.addHit
    UICommon.addScroll   = fns.addScroll
    UICommon.drawButton  = fns.drawButton
    UICommon.progressBar = fns.progressBar
end

-- ============================================================================
-- P2-P1-3: UI/UX 精修 - 动画工具
-- ============================================================================
UICommon.animTimers = {}  -- { [animId] = { timer = 0, duration = 0, onUpdate = fn, onComplete = fn } }

--- 注册一个动画
---@param animId string 动画唯一ID
---@param duration number 动画持续时间（秒）
---@param onUpdate function|nil 更新回调 (progress: 0-1)
---@param onComplete function|nil 完成回调
function UICommon.animStart(animId, duration, onUpdate, onComplete)
    UICommon.animTimers[animId] = {
        timer = 0,
        duration = duration,
        onUpdate = onUpdate,
        onComplete = onComplete,
    }
end

--- 取消动画
function UICommon.animCancel(animId)
    UICommon.animTimers[animId] = nil
end

--- 获取动画进度 (0-1)
function UICommon.animProgress(animId)
    local a = UICommon.animTimers[animId]
    if not a then return 0 end
    return math.min(1.0, a.timer / math.max(0.001, a.duration))
end

--- 更新所有动画（每帧调用）
function UICommon.animUpdate(dt)
    local toRemove = {}
    for animId, a in pairs(UICommon.animTimers) do
        a.timer = a.timer + dt
        if a.onUpdate then
            local progress = math.min(1.0, a.timer / math.max(0.001, a.duration))
            a.onUpdate(progress)
        end
        if a.timer >= a.duration then
            if a.onComplete then a.onComplete() end
            toRemove[#toRemove + 1] = animId
        end
    end
    for _, animId in ipairs(toRemove) do
        UICommon.animTimers[animId] = nil
    end
end

--- 缓动函数（P1-3: 扩展）
function UICommon.easeOut(t) return 1 - (1 - t) * (1 - t) end  -- 减速
function UICommon.easeIn(t) return t * t * t end                   -- 加速
function UICommon.easeInOut(t) return t < 0.5 and 2*t*t or 1-(-2*t+2)^2/2 end  -- 先慢后快
function UICommon.easeOutBounce(t)  -- 弹跳
    local n1 = 7.5625
    local d1 = 2.75
    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end
function UICommon.easeOutElastic(t)  -- 弹性
    local c4 = 2 * math.pi / 3
    if t == 0 then return 0
    elseif t == 1 then return 1
    else return (2 ^ (-10 * t)) * math.sin((t * 10 - 0.75) * c4) + 1
    end
end
function UICommon.linear(t) return t end
function UICommon.pulse(t) return 0.5 + 0.5 * math.sin(t * math.pi * 2) end  -- 脉冲0-1-0

--- 按钮点击缩放动画回调（scale 1 → 0.95 → 1，0.05s）
local BUTTON_ANIM_DURATION = 0.05
function UICommon.buttonClickAnim(animId, scaleFn)
    if UICommon.animTimers[animId] then return end  -- 动画进行中
    UICommon.animStart(animId, BUTTON_ANIM_DURATION, function(progress)
        local scale = 1.0
        if progress < 0.5 then
            scale = 1.0 - 0.05 * (progress * 2)
        else
            scale = 0.95 + 0.05 * ((progress - 0.5) * 2)
        end
        if scaleFn then scaleFn(scale) end
    end, function()
        if scaleFn then scaleFn(1.0) end  -- 确保恢复到1.0
    end)
end

--- 面板滑入动画（从右侧滑入，duration=0.25s）
function UICommon.panelSlideIn(animId, panelX, panelW, panelY, panelH, duration, renderFn)
    local startX = panelX + panelW  -- 从屏幕外开始
    UICommon.animStart(animId, duration or 0.25, function(progress)
        local p = UICommon.easeOut(progress)
        local x = startX - panelW * p
        renderFn(x, panelY, panelW, panelH)
    end)
end

--- 面板淡入动画（duration=0.25s）
function UICommon.fadeIn(animId, alpha, duration, renderFn)
    UICommon.animStart(animId, duration or 0.25, function(progress)
        local p = UICommon.easeOut(progress)
        renderFn(alpha * p)
    end)
end

-- ============================================================================
-- P1-3: 增强动画工具
-- ============================================================================

--- 面板滑出动画（从当前位置滑出到右侧）
function UICommon.panelSlideOut(animId, panelX, panelW, panelY, panelH, duration, renderFn, onComplete)
    UICommon.animStart(animId, duration or 0.20, function(progress)
        local p = UICommon.easeIn(progress)
        local x = panelX + panelW * p
        renderFn(x, panelY, panelW, panelH)
    end, onComplete)
end

--- 面板滑入动画（从左侧）
function UICommon.panelSlideInLeft(animId, panelX, panelW, panelY, panelH, duration, renderFn)
    local startX = panelX - panelW
    UICommon.animStart(animId, duration or 0.25, function(progress)
        local p = UICommon.easeOut(progress)
        local x = startX + panelW * p
        renderFn(x, panelY, panelW, panelH)
    end)
end

--- 面板从底部滑入
function UICommon.panelSlideUp(animId, panelX, panelW, panelY, panelH, duration, renderFn)
    local startY = panelY + panelH
    UICommon.animStart(animId, duration or 0.30, function(progress)
        local p = UICommon.easeOut(progress)
        local y = startY - panelH * p
        renderFn(panelX, y, panelW, panelH)
    end)
end

--- 面板淡出动画
function UICommon.fadeOut(animId, alpha, duration, renderFn, onComplete)
    UICommon.animStart(animId, duration or 0.20, function(progress)
        local p = UICommon.easeIn(progress)
        renderFn(alpha * (1 - p))
    end, onComplete)
end

--- 按钮点击缩放+弹性动画
function UICommon.buttonBounceAnim(animId, scaleFn, duration)
    if UICommon.animTimers[animId] then return end
    duration = duration or 0.25
    UICommon.animStart(animId, duration, function(progress)
        local scale = 1.0
        if progress < 0.3 then
            scale = 1.0 - 0.15 * (progress / 0.3)
        else
            scale = 0.85 + 0.15 * UICommon.easeOutBounce((progress - 0.3) / 0.7)
        end
        if scaleFn then scaleFn(scale) end
    end, function()
        if scaleFn then scaleFn(1.0) end
    end)
end

--- 按钮悬浮脉冲动画（循环）
function UICommon.buttonHoverPulse(baseScale, hoverTime)
    hoverTime = hoverTime or 0
    return baseScale + 0.03 * math.sin(hoverTime * 4)
end

--- 按钮悬浮滑出+缩放
function UICommon.buttonHoverScale(scaleFn, baseScale, hoverScale, hoverTime)
    hoverTime = hoverTime or 0
    local targetScale = baseScale or 1.0
    if hoverTime > 0 then
        local t = math.min(1.0, hoverTime / 0.15)
        targetScale = baseScale + (hoverScale - baseScale) * UICommon.easeOut(t)
    end
    if scaleFn then scaleFn(targetScale) end
    return targetScale
end

--- 文字闪烁动画
function UICommon.textGlow(animId, baseAlpha, duration, renderFn)
    UICommon.animStart(animId, duration or 1.0, function(progress)
        local p = UICommon.pulse(progress * 2)
        renderFn(baseAlpha * (0.5 + 0.5 * p))
    end)
end

--- 元素缩放入场
function UICommon.scaleIn(animId, baseScale, duration, renderFn)
    UICommon.animStart(animId, duration or 0.30, function(progress)
        local p = UICommon.easeOutElastic(progress)
        renderFn((baseScale or 1.0) * (0.5 + 0.5 * p))
    end)
end

--- 元素缩放出场
function UICommon.scaleOut(animId, baseScale, duration, renderFn, onComplete)
    UICommon.animStart(animId, duration or 0.20, function(progress)
        local p = UICommon.easeIn(progress)
        renderFn((baseScale or 1.0) * (1.0 - p))
    end, onComplete)
end

--- 旋转动画
function UICommon.rotateAnim(animId, duration, renderFn)
    UICommon.animStart(animId, duration, function(progress)
        local angle = progress * 360
        renderFn(angle)
    end)
end

--- 摇晃动画
function UICommon.shakeAnim(animId, intensity, duration, renderFn)
    intensity = intensity or 5
    UICommon.animStart(animId, duration or 0.30, function(progress)
        local shakeX = (math.random() - 0.5) * intensity * (1 - progress)
        local shakeY = (math.random() - 0.5) * intensity * (1 - progress)
        renderFn(shakeX, shakeY)
    end, function()
        renderFn(0, 0)
    end)
end

--- 进度条动画填充
function UICommon.progressFill(animId, targetProgress, duration, renderFn)
    UICommon.animStart(animId, duration or 0.50, function(progress)
        local p = UICommon.easeInOut(progress)
        renderFn(targetProgress * p)
    end)
end

--- 获取所有正在运行的动画数量
function UICommon.getActiveAnimCount()
    local count = 0
    for _ in pairs(UICommon.animTimers) do count = count + 1 end
    return count
end

--- 检查指定动画是否在运行
function UICommon.isAnimActive(animId)
    return UICommon.animTimers[animId] ~= nil
end

--- 停止所有动画
function UICommon.cancelAllAnims()
    UICommon.animTimers = {}
end

-- ============================================================================
-- V3.1-P1-5: UI/UX 增强工具
-- ============================================================================

--- Toast 提示系统（临时通知）
UICommon.toasts = {}
UICommon.toastMax = 5

function UICommon.showToast(message, duration, type, color)
    duration = duration or 3.0
    type = type or "info"  -- "info" | "success" | "warning" | "error"
    color = color or UICommon.C.textPrimary

    local toast = {
        message = message,
        duration = duration,
        type = type,
        color = color,
        timer = 0,
        alpha = 0,
        y = 0,
    }
    table.insert(UICommon.toasts, toast)

    -- 限制最大显示数量
    while #UICommon.toasts > UICommon.toastMax do
        table.remove(UICommon.toasts, 1)
    end

    return #UICommon.toasts
end

function UICommon.updateToasts(dt)
    for i = #UICommon.toasts, 1, -1 do
        local toast = UICommon.toasts[i]
        toast.timer = toast.timer + dt

        -- 淡入淡出
        if toast.timer < 0.3 then
            toast.alpha = toast.timer / 0.3
        elseif toast.timer > toast.duration - 0.5 then
            toast.alpha = (toast.duration - toast.timer) / 0.5
        else
            toast.alpha = 1.0
        end

        -- 移除过期提示
        if toast.timer >= toast.duration then
            table.remove(UICommon.toasts, i)
        end
    end
end

function UICommon.renderToasts(vg, x, y, w)
    local toastH = 30
    local gap = 5
    local currentY = y

    for i, toast in ipairs(UICommon.toasts) do
        if toast.alpha > 0.01 then
            local toastY = currentY + (i - 1) * (toastH + gap)
            local bgColor = {20, 30, 60, math.floor(220 * toast.alpha)}
            local borderColor = {toast.color[1], toast.color[2], toast.color[3], math.floor(180 * toast.alpha)}

            UICommon.panel(x, toastY, w, toastH, 6, bgColor, borderColor)
            UICommon.text(x + 10, toastY + toastH / 2, toast.message, 12, toast.color[1], toast.color[2], toast.color[3], math.floor(toast.color[4] * toast.alpha), 5)
            currentY = math.max(currentY, toastY + toastH + gap)
        end
    end
end

--- 加载指示器
UICommon.loadingSpinner = {
    angle = 0,
}

function UICommon.renderLoadingSpinner(vg, x, y, radius, color, thickness)
    radius = radius or 15
    color = color or UICommon.C.blueBright
    thickness = thickness or 3

    UICommon.loadingSpinner.angle = (UICommon.loadingSpinner.angle + 120 * 0.016) % 360

    local segments = 8
    local gap = 0.15
    for i = 1, segments do
        local startAngle = math.rad(UICommon.loadingSpinner.angle + (i - 1) * (360 / segments))
        local endAngle = startAngle + math.rad((360 / segments) * (1 - gap))
        local alpha = i / segments

        vg:ClearPath()
        vg:Arc(x, y, radius, startAngle, endAngle, 1)
        vg:StrokeWidth(thickness)
        vg:StrokeColor(color[1], color[2], color[3], math.floor(color[4] * alpha))
        vg:Stroke()
    end
end

--- 数字变化动画
UICommon.numberAnims = {}

function UICommon.animateNumber(key, fromValue, toValue, duration, onUpdate)
    UICommon.numberAnims[key] = {
        from = fromValue,
        to = toValue,
        duration = duration or 0.5,
        timer = 0,
        onUpdate = onUpdate,
    }
end

function UICommon.updateNumberAnims(dt)
    for key, anim in pairs(UICommon.numberAnims) do
        anim.timer = anim.timer + dt
        local progress = math.min(1.0, anim.timer / anim.duration)
        local eased = UICommon.easeOut(progress)
        local currentValue = anim.from + (anim.to - anim.from) * eased

        if anim.onUpdate then
            anim.onUpdate(currentValue, progress)
        end

        if progress >= 1.0 then
            UICommon.numberAnims[key] = nil
        end
    end
end

--- 图标按钮状态
UICommon.iconButtonStates = {}

function UICommon.drawIconButton(vg, x, y, size, iconColor, bgColor, hoverBgColor, pressedBgColor, isHovered, isPressed)
    bgColor = bgColor or UICommon.C.panelBg
    hoverBgColor = hoverBgColor or {30, 50, 80, 200}
    pressedBgColor = pressedBgColor or {40, 80, 140, 220}

    local currentBg = bgColor
    if isPressed then
        currentBg = pressedBgColor
    elseif isHovered then
        currentBg = hoverBgColor
    end

    vg:ClearPath()
    vg:RoundedRect(x, y, size, size, 4)
    vg:FillColor(currentBg[1], currentBg[2], currentBg[3], currentBg[4])
    vg:Fill()

    vg:ClearPath()
    vg:RoundedRect(x, y, size, size, 4)
    vg:StrokeWidth(1)
    vg:StrokeColor(UICommon.C.panelBorder[1], UICommon.C.panelBorder[2], UICommon.C.panelBorder[3], UICommon.C.panelBorder[4])
    vg:Stroke()

    return x + size / 2, y + size / 2
end

--- 状态徽章
function UICommon.drawBadge(vg, x, y, text, bgColor, textColor)
    bgColor = bgColor or UICommon.C.blueBtnBg
    textColor = textColor or UICommon.C.textPrimary

    local padding = 4
    local textW = #text * 8
    local badgeW = textW + padding * 2
    local badgeH = 16

    vg:ClearPath()
    vg:RoundedRect(x, y, badgeW, badgeH, 3)
    vg:FillColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    vg:Fill()

    UICommon.text(x + badgeW / 2, y + badgeH / 2, text, 10, textColor[1], textColor[2], textColor[3], textColor[4], 5)
end

--- 分割线
function UICommon.drawDivider(vg, x, y, w, thickness, color)
    thickness = thickness or 1
    color = color or {60, 80, 120, 100}

    vg:ClearPath()
    vg:MoveTo(x, y)
    vg:LineTo(x + w, y)
    vg:StrokeWidth(thickness)
    vg:StrokeColor(color[1], color[2], color[3], color[4])
    vg:Stroke()
end

--- 折叠面板
UICommon.collapseStates = {}

function UICommon.initCollapse(key, defaultCollapsed)
    if UICommon.collapseStates[key] == nil then
        UICommon.collapseStates[key] = not not defaultCollapsed
    end
end

function UICommon.toggleCollapse(key)
    UICommon.collapseStates[key] = not UICommon.collapseStates[key]
    return UICommon.collapseStates[key]
end

function UICommon.isCollapsed(key)
    return UICommon.collapseStates[key] or false
end

function UICommon.drawCollapseToggle(vg, x, y, size, key, label, textColor)
    local collapsed = UICommon.isCollapsed(key)
    local arrowChar = collapsed and ">" or "v"

    UICommon.text(x, y + size / 2, arrowChar, 12, textColor[1], textColor[2], textColor[3], textColor[4], 5)
    UICommon.text(x + size + 4, y + size / 2, label, 12, textColor[1], textColor[2], textColor[3], textColor[4], 5)
end

--- 工具提示（Tooltip）
UICommon.tooltip = {
    visible = false,
    text = "",
    x = 0,
    y = 0,
    timer = 0,
}

function UICommon.showTooltip(text, x, y, delay)
    delay = delay or 0.3
    UICommon.tooltip.visible = true
    UICommon.tooltip.text = text
    UICommon.tooltip.x = x
    UICommon.tooltip.y = y
    UICommon.tooltip.timer = 0
    UICommon.tooltip.delay = delay
end

function UICommon.hideTooltip()
    UICommon.tooltip.visible = false
end

function UICommon.updateTooltip(dt)
    if UICommon.tooltip.visible then
        UICommon.tooltip.timer = UICommon.tooltip.timer + dt
    end
end

function UICommon.renderTooltip(vg)
    if not UICommon.tooltip.visible or UICommon.tooltip.timer < (UICommon.tooltip.delay or 0.3) then
        return
    end

    local padding = 6
    local textW = #UICommon.tooltip.text * 7
    local ttW = textW + padding * 2
    local ttH = 20

    local ttX = UICommon.tooltip.x + 10
    local ttY = UICommon.tooltip.y + 10

    -- 背景
    local bgColor = {10, 15, 30, 240}
    vg:ClearPath()
    vg:RoundedRect(ttX, ttY, ttW, ttH, 4)
    vg:FillColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    vg:Fill()

    -- 边框
    vg:ClearPath()
    vg:RoundedRect(ttX, ttY, ttW, ttH, 4)
    vg:StrokeWidth(1)
    vg:StrokeColor(UICommon.C.panelBorder[1], UICommon.C.panelBorder[2], UICommon.C.panelBorder[3], 150)
    vg:Stroke()

    -- 文字
    UICommon.text(ttX + padding, ttY + ttH / 2, UICommon.tooltip.text, 11,
        UICommon.C.textPrimary[1], UICommon.C.textPrimary[2], UICommon.C.textPrimary[3], UICommon.C.textPrimary[4], 5)
end

--- 键盘快捷键提示
function UICommon.drawHotkeyHint(vg, x, y, key, hintText)
    local keyW = #key * 8 + 8
    local keyH = 16
    local gap = 4

    -- 按键背景
    vg:ClearPath()
    vg:RoundedRect(x, y, keyW, keyH, 3)
    vg:FillColor(30, 40, 60, 200)
    vg:Fill()
    vg:ClearPath()
    vg:RoundedRect(x, y, keyW, keyH, 3)
    vg:StrokeWidth(1)
    vg:StrokeColor(UICommon.C.panelBorder[1], UICommon.C.panelBorder[2], UICommon.C.panelBorder[3], 100)
    vg:Stroke()

    -- 按键文字
    UICommon.text(x + keyW / 2, y + keyH / 2, key, 10, 180, 200, 255, 255, 5)

    -- 提示文字
    if hintText then
        UICommon.text(x + keyW + gap, y + keyH / 2, hintText, 10, UICommon.C.textSecondary[1], UICommon.C.textSecondary[2], UICommon.C.textSecondary[3], UICommon.C.textSecondary[4], 5)
    end
end

return UICommon
