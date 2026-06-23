---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/GamepadSupport.lua -- 手柄支持系统
-- V2.8 P1-7
-- ============================================================================

local GamepadSupport = {}

-- ============================================================================
-- 手柄状态
-- ============================================================================

local GamepadState = {
    enabled = true,
    connected = false,
    lastInputTime = 0,
    currentScheme = "XBOX",  -- XBOX, PS4, SWITCH
    vibration = true,
}

-- 按键映射
local BUTTON_MAPPING = {
    -- XBOX/PS4 通用
    A = "button_a",
    B = "button_b",
    X = "button_x",
    Y = "button_y",
    LB = "button_lb",
    RB = "button_rb",
    LT = "button_lt",
    RT = "button_rt",
    SELECT = "button_select",
    START = "button_start",
    L3 = "button_l3",
    R3 = "button_r3",
    UP = "dpad_up",
    DOWN = "dpad_down",
    LEFT = "dpad_left",
    RIGHT = "dpad_right",
}

-- 功能映射
local FUNCTION_MAPPING = {
    -- 主菜单
    MENU_CONFIRM = { "A" },
    MENU_CANCEL = { "B" },
    MENU_BACK = { "B", "SELECT" },
    MENU_PAUSE = { "START" },

    -- 战斗
    BATTLE_SKILL_1 = { "X" },
    BATTLE_SKILL_2 = { "Y" },
    BATTLE_SKILL_3 = { "LB" },
    BATTLE_SKILL_4 = { "RB" },
    BATTLE_NEXT_TARGET = { "RT" },
    BATTLE_TAB = { "LT" },

    -- 移动
    MOVE_UP = { "UP" },
    MOVE_DOWN = { "DOWN" },
    MOVE_LEFT = { "LEFT" },
    MOVE_RIGHT = { "RIGHT" },

    -- 舰队管理
    FLEET_SELECT_ALL = { "Y" },
    FLEET_DESELECT = { "B" },
}

-- ============================================================================
-- 初始化
-- ============================================================================

function GamepadSupport.initialize()
    -- 检测手柄连接
    GamepadState.connected = GamepadSupport.checkConnection()

    -- 自动检测手柄类型
    if GamepadState.connected then
        GamepadState.currentScheme = GamepadSupport.detectControllerType()
    end

    return GamepadState.connected
end

-- 检测手柄连接
function GamepadSupport.checkConnection()
    -- 模拟检测，实际应该调用平台API
    return false  -- 默认无手柄
end

-- 检测手柄类型
function GamepadSupport.detectControllerType()
    -- 根据输入设备名称判断
    return "XBOX"  -- 默认 XBOX 布局
end

-- ============================================================================
-- 输入处理
-- ============================================================================

-- 获取当前按键状态
function GamepadSupport.getButtonState(button)
    -- 模拟返回按键状态
    return false
end

-- 获取摇杆状态
function GamepadSupport.getStickState(stick)
    -- 模拟返回摇杆状态 (-1 到 1)
    if stick == "left" then
        return { x = 0, y = 0 }
    elseif stick == "right" then
        return { x = 0, y = 0 }
    end
    return { x = 0, y = 0 }
end

-- 获取扳机状态
function GamepadSupport.getTriggerState(trigger)
    -- 返回 0 到 1 的值
    return 0
end

-- 检查功能是否被触发
function GamepadSupport.isFunctionPressed(functionId)
    local buttons = FUNCTION_MAPPING[functionId]
    if not buttons then return false end

    for _, button in ipairs(buttons) do
        if GamepadSupport.getButtonState(button) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- 震动反馈
-- ============================================================================

function GamepadSupport.vibrate(leftMotor, rightMotor, duration)
    if not GamepadState.vibration or not GamepadState.connected then
        return
    end

    -- 模拟震动
    -- 实际应该调用平台震动API
end

function GamepadSupport.vibrateLight()
    GamepadSupport.vibrate(0.3, 0.1, 100)
end

function GamepadSupport.vibrateMedium()
    GamepadSupport.vibrate(0.6, 0.4, 200)
end

function GamepadSupport.vibrateHeavy()
    GamepadSupport.vibrate(1.0, 0.8, 300)
end

-- ============================================================================
-- UI 导航
-- ============================================================================

-- 导航状态
local NavigationState = {
    currentPanel = nil,
    selectedIndex = 0,
    items = {},
}

function GamepadSupport.setNavigationPanel(panelName, items)
    NavigationState.currentPanel = panelName
    NavigationState.items = items or {}
    NavigationState.selectedIndex = 0
end

function GamepadSupport.updateNavigation()
    -- 处理方向键导航
    local stick = GamepadSupport.getStickState("left")

    if stick.y < -0.5 then
        -- 上
        NavigationState.selectedIndex = math.max(0, NavigationState.selectedIndex - 1)
    elseif stick.y > 0.5 then
        -- 下
        NavigationState.selectedIndex = math.min(#NavigationState.items - 1, NavigationState.selectedIndex + 1)
    end

    if stick.x < -0.5 then
        -- 左
        NavigationState.selectedIndex = math.max(0, NavigationState.selectedIndex - 1)
    elseif stick.x > 0.5 then
        -- 右
        NavigationState.selectedIndex = math.min(#NavigationState.items - 1, NavigationState.selectedIndex + 1)
    end
end

function GamepadSupport.getSelectedIndex()
    return NavigationState.selectedIndex
end

function GamepadSupport.getSelectedItem()
    return NavigationState.items[NavigationState.selectedIndex + 1]
end

-- ============================================================================
-- 按键提示渲染
-- ============================================================================

-- 获取按键图标
function GamepadSupport.getButtonIcon(button)
    local scheme = GamepadState.currentScheme

    if button == "A" then
        return scheme == "PS4" and "○" or "A"
    elseif button == "B" then
        return scheme == "PS4" and "×" or "B"
    elseif button == "X" then
        return scheme == "PS4" and "□" or "X"
    elseif button == "Y" then
        return scheme == "PS4" and "△" or "Y"
    end

    return button
end

-- 渲染按键提示
function GamepadSupport.drawButtonHint(vg, x, y, button, text)
    local icon = GamepadSupport.getButtonIcon(button)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)

    -- 按钮背景
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, 10)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)

    -- 按钮图标
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x, y, icon)

    -- 文字
    if text then
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
        nvgText(vg, x + 15, y, text)
    end
end

-- ============================================================================
-- 设置
-- ============================================================================

function GamepadSupport.setEnabled(enabled)
    GamepadState.enabled = enabled
end

function GamepadSupport.isEnabled()
    return GamepadState.enabled
end

function GamepadSupport.setVibration(enabled)
    GamepadState.vibration = enabled
end

function GamepadSupport.isVibrationEnabled()
    return GamepadState.vibration
end

function GamepadSupport.setScheme(scheme)
    if scheme == "XBOX" or scheme == "PS4" or scheme == "SWITCH" then
        GamepadState.currentScheme = scheme
    end
end

function GamepadSupport.getScheme()
    return GamepadState.currentScheme
end

function GamepadSupport.isConnected()
    return GamepadState.connected
end

-- ============================================================================
-- 导出
-- ============================================================================

return GamepadSupport
