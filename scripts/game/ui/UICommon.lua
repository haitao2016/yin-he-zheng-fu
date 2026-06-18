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

--- 缓动函数
function UICommon.easeOut(t) return 1 - (1 - t) * (1 - t) end  -- 减速
function UICommon.easeIn(t) return t * t * t end                   -- 加速
function UICommon.easeInOut(t) return t < 0.5 and 2*t*t or 1-(-2*t+2)^2/2 end  -- 先慢后快

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

return UICommon
