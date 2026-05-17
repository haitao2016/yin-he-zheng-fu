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

--- 由 GameUI 在初始化后调用，将工具函数绑定到 UICommon
function UICommon.bindFns(fns)
    UICommon.clr       = fns.clr
    UICommon.clrC      = fns.clrC
    UICommon.panel     = fns.panel
    UICommon.text      = fns.text
    UICommon.addHit    = fns.addHit
    UICommon.addScroll = fns.addScroll
end

return UICommon
