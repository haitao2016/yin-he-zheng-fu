---@diagnostic disable: undefined-global
-- ============================================================================
-- DragManager.lua — 面板拖拽管理器
-- 为所有 NanoVG 即时模式面板提供统一的拖拽定位功能
-- 使用方法:
--   1. 面板渲染时调用 DragManager.GetPos(id, defaultX, defaultY) 获取当前位置
--   2. 面板渲染拖拽把手区域（标题栏）
--   3. 调用 DragManager.RegisterHandle(id, hx, hy, hw, hh) 注册拖拽热区
--   4. GameUI 在 OnTouchBegin/Move/End 中调用 DragManager 对应方法
-- ============================================================================

local DragManager = {}

-- 面板位置存储: { [panelId] = { x=offset, y=offset } }
local positions_ = {}

-- 拖拽状态
local dragging_     = false
local dragId_       = nil    ---@type string|nil
local dragStartMX_  = 0
local dragStartMY_  = 0
local dragStartPX_  = 0
local dragStartPY_  = 0

-- 拖拽把手区域: { [panelId] = { x, y, w, h } }
local handles_ = {}

-- 屏幕边界（每帧由 GameUI 设置）
local screenW_ = 800
local screenH_ = 600
local TOPBAR_H = 48  -- 顶栏保护区高度

--- 每帧开始前重置把手注册（因为即时模式每帧重新注册）
function DragManager.BeginFrame(sw, sh)
    handles_  = {}
    screenW_  = sw or screenW_
    screenH_  = sh or screenH_
end

--- 设置顶栏高度（面板不能拖到顶栏之上）
function DragManager.SetTopBarH(h)
    TOPBAR_H = h or 48
end

--- 获取面板当前位置（含拖拽偏移）
---@param id string 面板唯一标识
---@param defaultX number 默认X坐标
---@param defaultY number 默认Y坐标
---@return number x, number y
function DragManager.GetPos(id, defaultX, defaultY)
    local pos = positions_[id]
    if pos then
        return pos.x, pos.y
    end
    return defaultX, defaultY
end

--- 注册拖拽把手区域（每帧在渲染标题栏后调用）
---@param id string 面板唯一标识
---@param x number 把手左上角X
---@param y number 把手左上角Y
---@param w number 把手宽度
---@param h number 把手高度
function DragManager.RegisterHandle(id, x, y, w, h)
    handles_[id] = { x = x, y = y, w = w, h = h }
end

--- 重置指定面板位置（恢复默认）
function DragManager.ResetPos(id)
    positions_[id] = nil
end

--- 重置所有面板位置
function DragManager.ResetAll()
    positions_ = {}
end

--- 触摸/鼠标按下：检测是否命中拖拽把手
---@param mx number 屏幕坐标X
---@param my number 屏幕坐标Y
---@return boolean consumed 是否开始拖拽
function DragManager.OnTouchBegin(mx, my)
    -- 逆序遍历（后注册的面板在上层）
    for id, h in pairs(handles_) do
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
            dragging_    = true
            dragId_      = id
            dragStartMX_ = mx
            dragStartMY_ = my
            local pos = positions_[id]
            dragStartPX_ = pos and pos.x or h.x
            dragStartPY_ = pos and pos.y or h.y
            return true
        end
    end
    return false
end

--- 触摸/鼠标移动：更新拖拽中面板的位置
---@param mx number 屏幕坐标X
---@param my number 屏幕坐标Y
---@return boolean consumed
function DragManager.OnTouchMove(mx, my)
    if not dragging_ or not dragId_ then return false end
    local dx = mx - dragStartMX_
    local dy = my - dragStartMY_
    local newX = dragStartPX_ + dx
    local newY = dragStartPY_ + dy

    -- 边界保护：不让面板完全离开屏幕
    local h = handles_[dragId_]
    local hw = h and h.w or 100
    local hh = h and h.h or 30
    newX = math.max(-hw + 40, math.min(screenW_ - 40, newX))
    newY = math.max(TOPBAR_H, math.min(screenH_ - hh, newY))

    positions_[dragId_] = { x = newX, y = newY }
    return true
end

--- 触摸/鼠标抬起：结束拖拽
---@return boolean consumed
function DragManager.OnTouchEnd()
    if not dragging_ then return false end
    dragging_ = false
    dragId_   = nil
    return true
end

--- 是否正在拖拽中（用于阻止其他输入）
function DragManager.IsDragging()
    return dragging_
end

--- 绘制拖拽把手指示器（可选 — 在标题栏中间画一小排点）
---@param vg userdata NanoVG context
---@param x number 把手区域X
---@param y number 把手区域Y
---@param w number 把手区域宽度
---@param h number 把手区域高度
function DragManager.DrawHandle(vg, x, y, w, h)
    local cx = x + w / 2
    local cy = y + h / 2
    local dotR = 1.5
    local dotGap = 6
    local dotCount = 5
    local startX = cx - (dotCount - 1) * dotGap / 2
    nvgBeginPath(vg)
    for i = 0, dotCount - 1 do
        nvgCircle(vg, startX + i * dotGap, cy, dotR)
    end
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 120))
    nvgFill(vg)
end

return DragManager
