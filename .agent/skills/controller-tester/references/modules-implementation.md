# Controller Tester — 模块完整实现

> 本文档包含三大模块的完整 Lua 实现代码，可直接复制到项目 `scripts/` 目录使用。

---

## §1 ControllerDetector — 控制器检测模块

```lua
-- scripts/ControllerDetector.lua
-- 控制器检测、热插拔监听、信息查询

local ControllerDetector = {
    controllers = {},     -- joystickID → controllerInfo
    activeID = nil,       -- 当前选中的控制器 ID
    onConnected = nil,    -- 连接回调 function(id, info)
    onDisconnected = nil, -- 断开回调 function(id)
}

--- 控制器信息结构
---@class ControllerInfo
---@field name string
---@field joystickID integer
---@field isGamepad boolean
---@field numButtons integer
---@field numAxes integer
---@field numHats integer

--- 初始化检测器，扫描已连接控制器并订阅热插拔事件
function ControllerDetector:Init()
    self.controllers = {}
    self:ScanAll()

    SubscribeToEvent("JoystickConnected", function(_, eventData)
        local id = eventData["JoystickID"]:GetInt()
        self:OnConnected(id)
    end)

    SubscribeToEvent("JoystickDisconnected", function(_, eventData)
        local id = eventData["JoystickID"]:GetInt()
        self:OnDisconnected(id)
    end)

    log:Write(LOG_INFO, string.format("[ControllerDetector] 初始化完成，检测到 %d 个控制器",
        self:GetCount()))
end

--- 扫描所有已连接控制器
function ControllerDetector:ScanAll()
    self.controllers = {}
    local count = input:GetNumJoysticks()
    for i = 0, count - 1 do
        local js = input:GetJoystickByIndex(i)
        if js then
            local info = {
                name = js.name,
                joystickID = js.joystickID,
                isGamepad = js:IsController(),
                numButtons = js.numButtons,
                numAxes = js.numAxes,
                numHats = js.numHats,
            }
            self.controllers[js.joystickID] = info
            if not self.activeID then
                self.activeID = js.joystickID
            end
        end
    end
end

--- 处理控制器连接
function ControllerDetector:OnConnected(joystickID)
    local js = input:GetJoystick(joystickID)
    if not js then return end

    local info = {
        name = js.name,
        joystickID = joystickID,
        isGamepad = js:IsController(),
        numButtons = js.numButtons,
        numAxes = js.numAxes,
        numHats = js.numHats,
    }
    self.controllers[joystickID] = info

    if not self.activeID then
        self.activeID = joystickID
    end

    log:Write(LOG_INFO, "[ControllerDetector] 控制器已连接: " .. js.name)
    if self.onConnected then
        self.onConnected(joystickID, info)
    end
end

--- 处理控制器断开
function ControllerDetector:OnDisconnected(joystickID)
    local info = self.controllers[joystickID]
    local name = info and info.name or "unknown"
    self.controllers[joystickID] = nil

    if self.activeID == joystickID then
        self.activeID = nil
        for id, _ in pairs(self.controllers) do
            self.activeID = id
            break
        end
    end

    log:Write(LOG_INFO, "[ControllerDetector] 控制器已断开: " .. name)
    if self.onDisconnected then
        self.onDisconnected(joystickID)
    end
end

--- 获取已连接控制器数量
function ControllerDetector:GetCount()
    local count = 0
    for _ in pairs(self.controllers) do count = count + 1 end
    return count
end

--- 获取当前活跃控制器的 JoystickState
---@return JoystickState|nil
function ControllerDetector:GetActiveJoystick()
    if not self.activeID then return nil end
    return input:GetJoystick(self.activeID)
end

--- 获取当前活跃控制器的信息
---@return ControllerInfo|nil
function ControllerDetector:GetActiveInfo()
    if not self.activeID then return nil end
    return self.controllers[self.activeID]
end

--- 切换到下一个控制器
function ControllerDetector:SelectNext()
    local ids = {}
    for id in pairs(self.controllers) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    if #ids == 0 then return end

    local currentIdx = 1
    for i, id in ipairs(ids) do
        if id == self.activeID then
            currentIdx = i
            break
        end
    end
    self.activeID = ids[(currentIdx % #ids) + 1]
end

--- 获取所有控制器信息列表
---@return ControllerInfo[]
function ControllerDetector:GetAllControllers()
    local list = {}
    for _, info in pairs(self.controllers) do
        list[#list + 1] = info
    end
    return list
end

return ControllerDetector
```

---

## §2 ControllerVisualizer — NanoVG 可视化面板

```lua
-- scripts/ControllerVisualizer.lua
-- 使用 NanoVG 绘制控制器实时输入可视化面板

local ControllerVisualizer = {
    vg = nil,           -- NanoVG 上下文
    font = -1,          -- 字体句柄
    deadzone = 0.1,     -- 默认死区
    showDeadzone = true, -- 是否显示死区圆
}

-- 颜色预设
local COLORS = {
    bg           = function(vg) return nvgRGBA(30, 30, 40, 230) end,
    panel        = function(vg) return nvgRGBA(45, 45, 60, 200) end,
    border       = function(vg) return nvgRGBA(80, 80, 100, 255) end,
    text         = function(vg) return nvgRGBA(220, 220, 230, 255) end,
    textDim      = function(vg) return nvgRGBA(140, 140, 160, 255) end,
    stickBg      = function(vg) return nvgRGBA(50, 50, 70, 200) end,
    stickDot     = function(vg) return nvgRGBA(100, 200, 255, 255) end,
    stickDotDead = function(vg) return nvgRGBA(255, 100, 100, 180) end,
    deadzone     = function(vg) return nvgRGBA(255, 255, 100, 40) end,
    btnOff       = function(vg) return nvgRGBA(60, 60, 80, 200) end,
    btnOn        = function(vg) return nvgRGBA(80, 220, 120, 255) end,
    triggerBg    = function(vg) return nvgRGBA(50, 50, 70, 200) end,
    triggerFill  = function(vg) return nvgRGBA(255, 160, 50, 255) end,
    title        = function(vg) return nvgRGBA(255, 255, 255, 255) end,
    connected    = function(vg) return nvgRGBA(100, 255, 100, 255) end,
    disconnected = function(vg) return nvgRGBA(255, 100, 100, 255) end,
    hatActive    = function(vg) return nvgRGBA(200, 150, 255, 255) end,
}

--- 初始化可视化器（在 Start() 中调用）
function ControllerVisualizer:Init()
    self.vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    self.font = nvgCreateFont(self.vg, "sans", "Fonts/MiSans-Regular.ttf")
    if self.font < 0 then
        log:Write(LOG_ERROR, "[ControllerVisualizer] 字体加载失败")
    end
end

--- 应用死区过滤
local function applyDeadzone(value, dz)
    if math.abs(value) < dz then return 0.0 end
    local sign = value > 0 and 1 or -1
    return sign * (math.abs(value) - dz) / (1.0 - dz)
end

--- 绘制摇杆圆盘
---@param cx number 圆心 X
---@param cy number 圆心 Y
---@param r number 半径
---@param rawX number X 轴原始值 (-1~1)
---@param rawY number Y 轴原始值 (-1~1)
---@param label string 标签文字
function ControllerVisualizer:DrawStick(cx, cy, r, rawX, rawY, label)
    local vg = self.vg

    -- 底盘
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, COLORS.stickBg(vg))
    nvgFill(vg)
    nvgStrokeColor(vg, COLORS.border(vg))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 十字线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - r, cy)
    nvgLineTo(vg, cx + r, cy)
    nvgMoveTo(vg, cx, cy - r)
    nvgLineTo(vg, cx, cy + r)
    nvgStrokeColor(vg, nvgRGBA(60, 60, 80, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 死区圆
    if self.showDeadzone and self.deadzone > 0 then
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, r * self.deadzone)
        nvgFillColor(vg, COLORS.deadzone(vg))
        nvgFill(vg)
    end

    -- 应用死区
    local dx = applyDeadzone(rawX, self.deadzone)
    local dy = applyDeadzone(rawY, self.deadzone)

    -- 指示点
    local dotX = cx + dx * r * 0.85
    local dotY = cy + dy * r * 0.85
    local dotR = r * 0.15
    local inDeadzone = (dx == 0 and dy == 0 and (rawX ~= 0 or rawY ~= 0))

    nvgBeginPath(vg)
    nvgCircle(vg, dotX, dotY, dotR)
    nvgFillColor(vg, inDeadzone and COLORS.stickDotDead(vg) or COLORS.stickDot(vg))
    nvgFill(vg)

    -- 标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgFillColor(vg, COLORS.text(vg))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, cx, cy + r + 8, label)

    -- 数值
    nvgFontSize(vg, 11)
    nvgFillColor(vg, COLORS.textDim(vg))
    nvgText(vg, cx, cy + r + 24, string.format("%.2f, %.2f", rawX, rawY))
end

--- 绘制扳机进度条
---@param x number 左上角 X
---@param y number 左上角 Y
---@param w number 宽度
---@param h number 高度
---@param value number 扳机值 (0~1 或 -1~1)
---@param label string 标签
function ControllerVisualizer:DrawTrigger(x, y, w, h, value, label)
    local vg = self.vg
    local normalized = (value + 1) * 0.5  -- 将 -1~1 映射到 0~1
    local fillH = h * normalized

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 4)
    nvgFillColor(vg, COLORS.triggerBg(vg))
    nvgFill(vg)

    -- 填充（从底部向上）
    if fillH > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, y + h - fillH, w, fillH, 4)
        nvgFillColor(vg, COLORS.triggerFill(vg))
        nvgFill(vg)
    end

    -- 边框
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 4)
    nvgStrokeColor(vg, COLORS.border(vg))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgFillColor(vg, COLORS.text(vg))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, x + w * 0.5, y + h + 6, label)

    -- 数值
    nvgFontSize(vg, 11)
    nvgFillColor(vg, COLORS.textDim(vg))
    nvgText(vg, x + w * 0.5, y + h + 20, string.format("%.0f%%", normalized * 100))
end

--- 绘制单个按钮
---@param x number 圆心 X
---@param y number 圆心 Y
---@param r number 半径
---@param pressed boolean 是否按下
---@param label string 按钮标签
function ControllerVisualizer:DrawButton(x, y, r, pressed, label)
    local vg = self.vg

    nvgBeginPath(vg)
    nvgCircle(vg, x, y, r)
    nvgFillColor(vg, pressed and COLORS.btnOn(vg) or COLORS.btnOff(vg))
    nvgFill(vg)
    nvgStrokeColor(vg, COLORS.border(vg))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.min(r * 0.9, 12))
    nvgFillColor(vg, COLORS.text(vg))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgText(vg, x, y, label)
end

--- 绘制十字键（D-Pad）
---@param cx number 中心 X
---@param cy number 中心 Y
---@param size number 整体大小
---@param hatPos integer 帽子开关位置（HAT_* 枚举）
function ControllerVisualizer:DrawDPad(cx, cy, size, hatPos)
    local vg = self.vg
    local s = size * 0.3  -- 每个方向块大小

    local dirs = {
        { dx = 0,  dy = -1, flag = HAT_UP,    label = "U" },
        { dx = 0,  dy = 1,  flag = HAT_DOWN,  label = "D" },
        { dx = -1, dy = 0,  flag = HAT_LEFT,  label = "L" },
        { dx = 1,  dy = 0,  flag = HAT_RIGHT, label = "R" },
    }

    -- 中心块
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.5, cy - s * 0.5, s, s)
    nvgFillColor(vg, COLORS.stickBg(vg))
    nvgFill(vg)

    for _, dir in ipairs(dirs) do
        local bx = cx + dir.dx * s
        local by = cy + dir.dy * s
        local active = (hatPos & dir.flag) ~= 0

        nvgBeginPath(vg)
        nvgRect(vg, bx - s * 0.5, by - s * 0.5, s, s)
        nvgFillColor(vg, active and COLORS.hatActive(vg) or COLORS.btnOff(vg))
        nvgFill(vg)
        nvgStrokeColor(vg, COLORS.border(vg))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgFillColor(vg, COLORS.text(vg))
        nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
        nvgText(vg, bx, by, dir.label)
    end
end

--- 绘制标准手柄按钮布局（ABXY + 肩键）
---@param x number 起始 X
---@param y number 起始 Y
---@param js JoystickState 控制器状态
function ControllerVisualizer:DrawGamepadButtons(x, y, js)
    local vg = self.vg
    local r = 14
    local gap = 36

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgFillColor(vg, COLORS.text(vg))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
    nvgText(vg, x, y, "按钮状态")

    y = y + 24

    if js:IsController() then
        -- ABXY 菱形布局
        local abxyX = x + 40
        local abxyY = y + 30
        self:DrawButton(abxyX, abxyY - gap * 0.7, r,
            js:GetButtonDown(CONTROLLER_BUTTON_Y), "Y")
        self:DrawButton(abxyX, abxyY + gap * 0.7, r,
            js:GetButtonDown(CONTROLLER_BUTTON_A), "A")
        self:DrawButton(abxyX - gap * 0.7, abxyY, r,
            js:GetButtonDown(CONTROLLER_BUTTON_X), "X")
        self:DrawButton(abxyX + gap * 0.7, abxyY, r,
            js:GetButtonDown(CONTROLLER_BUTTON_B), "B")

        -- 功能键
        local funcY = abxyY + gap * 1.5
        self:DrawButton(x + 10, funcY, 10,
            js:GetButtonDown(CONTROLLER_BUTTON_BACK), "BK")
        self:DrawButton(x + 40, funcY, 10,
            js:GetButtonDown(CONTROLLER_BUTTON_GUIDE), "G")
        self:DrawButton(x + 70, funcY, 10,
            js:GetButtonDown(CONTROLLER_BUTTON_START), "ST")

        -- 肩键
        local shY = funcY + 30
        self:DrawButton(x + 15, shY, 12,
            js:GetButtonDown(CONTROLLER_BUTTON_LEFTSHOULDER), "LB")
        self:DrawButton(x + 65, shY, 12,
            js:GetButtonDown(CONTROLLER_BUTTON_RIGHTSHOULDER), "RB")

        -- 摇杆按下
        self:DrawButton(x + 15, shY + 30, 10,
            js:GetButtonDown(CONTROLLER_BUTTON_LEFTSTICK), "LS")
        self:DrawButton(x + 65, shY + 30, 10,
            js:GetButtonDown(CONTROLLER_BUTTON_RIGHTSTICK), "RS")
    else
        -- 通用按钮网格（非标准手柄）
        local cols = 4
        for i = 0, js.numButtons - 1 do
            local col = i % cols
            local row = math.floor(i / cols)
            local bx = x + 18 + col * 36
            local by = y + 18 + row * 36
            self:DrawButton(bx, by, r,
                js:GetButtonDown(i), tostring(i))
        end
    end
end

--- 绘制完整的控制器面板
---@param js JoystickState 控制器状态
---@param info ControllerInfo 控制器信息
function ControllerVisualizer:DrawFullPanel(js, info)
    local vg = self.vg
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()

    nvgBeginFrame(vg, w, h, graphics:GetDPR())
    nvgFontFace(vg, "sans")

    -- 背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, COLORS.bg(vg))
    nvgFill(vg)

    -- 标题
    nvgFontSize(vg, 28)
    nvgFillColor(vg, COLORS.title(vg))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, w * 0.5, 16, "Controller Tester")

    -- 控制器名称和状态
    nvgFontSize(vg, 16)
    nvgFillColor(vg, COLORS.connected(vg))
    nvgText(vg, w * 0.5, 50, info.name)

    -- 控制器详细信息
    nvgFontSize(vg, 12)
    nvgFillColor(vg, COLORS.textDim(vg))
    nvgText(vg, w * 0.5, 72, string.format(
        "类型: %s | 按钮: %d | 轴: %d | 帽子开关: %d",
        info.isGamepad and "标准手柄" or "通用设备",
        info.numButtons, info.numAxes, info.numHats))

    -- 布局区域
    local contentY = 100
    local panelH = h - contentY - 20

    -- 左侧：摇杆
    local stickR = math.min(panelH * 0.2, 60)
    if js.numAxes >= 2 then
        self:DrawStick(w * 0.2, contentY + panelH * 0.3, stickR,
            js:GetAxisPosition(CONTROLLER_AXIS_LEFTX),
            js:GetAxisPosition(CONTROLLER_AXIS_LEFTY),
            "左摇杆")
    end
    if js.numAxes >= 4 then
        self:DrawStick(w * 0.2, contentY + panelH * 0.75, stickR,
            js:GetAxisPosition(CONTROLLER_AXIS_RIGHTX),
            js:GetAxisPosition(CONTROLLER_AXIS_RIGHTY),
            "右摇杆")
    end

    -- 中间：扳机
    local trigW = 24
    local trigH = math.min(panelH * 0.3, 80)
    if js.numAxes >= 5 then
        self:DrawTrigger(w * 0.42, contentY + 20, trigW, trigH,
            js:GetAxisPosition(CONTROLLER_AXIS_TRIGGERLEFT), "LT")
    end
    if js.numAxes >= 6 then
        self:DrawTrigger(w * 0.5, contentY + 20, trigW, trigH,
            js:GetAxisPosition(CONTROLLER_AXIS_TRIGGERRIGHT), "RT")
    end

    -- 右侧：按钮
    self:DrawGamepadButtons(w * 0.62, contentY + 10, js)

    -- 右下：D-Pad
    if js.numHats > 0 then
        local hatPos = js:GetHatPosition(0)
        self:DrawDPad(w * 0.42, contentY + panelH * 0.7, 80, hatPos)
    end

    -- 底部：死区设置显示
    nvgFontSize(vg, 12)
    nvgFillColor(vg, COLORS.textDim(vg))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_BOTTOM)
    nvgText(vg, w * 0.5, h - 8,
        string.format("死区: %.0f%% | 按 [/] 调节 | Tab 切换控制器", self.deadzone * 100))

    nvgEndFrame(vg)
end

--- 绘制"无控制器"状态
function ControllerVisualizer:DrawNoController()
    local vg = self.vg
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()

    nvgBeginFrame(vg, w, h, graphics:GetDPR())
    nvgFontFace(vg, "sans")

    -- 背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, COLORS.bg(vg))
    nvgFill(vg)

    -- 标题
    nvgFontSize(vg, 28)
    nvgFillColor(vg, COLORS.title(vg))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgText(vg, w * 0.5, h * 0.4, "Controller Tester")

    -- 提示
    nvgFontSize(vg, 18)
    nvgFillColor(vg, COLORS.disconnected(vg))
    nvgText(vg, w * 0.5, h * 0.5, "未检测到控制器")

    nvgFontSize(vg, 14)
    nvgFillColor(vg, COLORS.textDim(vg))
    nvgText(vg, w * 0.5, h * 0.58, "请连接游戏手柄或摇杆")

    nvgEndFrame(vg)
end

--- 调节死区
function ControllerVisualizer:AdjustDeadzone(delta)
    self.deadzone = math.max(0.0, math.min(0.5, self.deadzone + delta))
end

return ControllerVisualizer
```

---

## §3 ControllerLogger — 事件日志模块

```lua
-- scripts/ControllerLogger.lua
-- 控制器输入事件日志记录与显示

local ControllerLogger = {
    entries = {},       -- 日志条目列表
    maxEntries = 50,    -- 最大条目数
    startTime = 0,      -- 启动时间
}

---@class LogEntry
---@field time number 相对时间（秒）
---@field text string 日志文本
---@field color table {r, g, b, a}

-- 日志类型颜色
local LOG_COLORS = {
    button_down  = { r = 80,  g = 220, b = 120, a = 255 },
    button_up    = { r = 180, g = 180, b = 200, a = 200 },
    axis         = { r = 100, g = 180, b = 255, a = 230 },
    hat          = { r = 200, g = 150, b = 255, a = 230 },
    connect      = { r = 255, g = 220, b = 80,  a = 255 },
    disconnect   = { r = 255, g = 100, b = 100, a = 255 },
}

--- 标准手柄按钮名称映射
local BUTTON_NAMES = {
    [CONTROLLER_BUTTON_A]              = "A",
    [CONTROLLER_BUTTON_B]              = "B",
    [CONTROLLER_BUTTON_X]              = "X",
    [CONTROLLER_BUTTON_Y]              = "Y",
    [CONTROLLER_BUTTON_BACK]           = "Back",
    [CONTROLLER_BUTTON_GUIDE]          = "Guide",
    [CONTROLLER_BUTTON_START]          = "Start",
    [CONTROLLER_BUTTON_LEFTSTICK]      = "L Stick",
    [CONTROLLER_BUTTON_RIGHTSTICK]     = "R Stick",
    [CONTROLLER_BUTTON_LEFTSHOULDER]   = "LB",
    [CONTROLLER_BUTTON_RIGHTSHOULDER]  = "RB",
    [CONTROLLER_BUTTON_DPAD_UP]        = "D-Up",
    [CONTROLLER_BUTTON_DPAD_DOWN]      = "D-Down",
    [CONTROLLER_BUTTON_DPAD_LEFT]      = "D-Left",
    [CONTROLLER_BUTTON_DPAD_RIGHT]     = "D-Right",
}

--- 轴名称映射
local AXIS_NAMES = {
    [CONTROLLER_AXIS_LEFTX]        = "L-Stick X",
    [CONTROLLER_AXIS_LEFTY]        = "L-Stick Y",
    [CONTROLLER_AXIS_RIGHTX]       = "R-Stick X",
    [CONTROLLER_AXIS_RIGHTY]       = "R-Stick Y",
    [CONTROLLER_AXIS_TRIGGERLEFT]  = "L-Trigger",
    [CONTROLLER_AXIS_TRIGGERRIGHT] = "R-Trigger",
}

--- 初始化日志模块
---@param maxEntries? integer 最大日志条目数（默认 50）
---@param axisThreshold? number 轴变化日志阈值（默认 0.15）
function ControllerLogger:Init(maxEntries, axisThreshold)
    self.entries = {}
    self.maxEntries = maxEntries or 50
    self.startTime = os.clock()
    local threshold = axisThreshold or 0.15

    SubscribeToEvent("JoystickButtonDown", function(_, eventData)
        local btn = eventData["Button"]:GetInt()
        local name = BUTTON_NAMES[btn] or ("Btn " .. tostring(btn))
        self:Add(string.format("▼ %s 按下", name), LOG_COLORS.button_down)
    end)

    SubscribeToEvent("JoystickButtonUp", function(_, eventData)
        local btn = eventData["Button"]:GetInt()
        local name = BUTTON_NAMES[btn] or ("Btn " .. tostring(btn))
        self:Add(string.format("▲ %s 释放", name), LOG_COLORS.button_up)
    end)

    SubscribeToEvent("JoystickAxisMove", function(_, eventData)
        local axis = eventData["Button"]:GetInt()
        local pos  = eventData["Position"]:GetFloat()
        if math.abs(pos) > threshold then
            local name = AXIS_NAMES[axis] or ("Axis " .. tostring(axis))
            self:Add(string.format("◆ %s: %.2f", name, pos), LOG_COLORS.axis)
        end
    end)

    SubscribeToEvent("JoystickHatMove", function(_, eventData)
        local hat = eventData["Button"]:GetInt()
        local pos = eventData["Position"]:GetInt()
        local dirStr = "中"
        if pos ~= HAT_CENTER then
            local parts = {}
            if (pos & HAT_UP)    ~= 0 then parts[#parts + 1] = "上" end
            if (pos & HAT_DOWN)  ~= 0 then parts[#parts + 1] = "下" end
            if (pos & HAT_LEFT)  ~= 0 then parts[#parts + 1] = "左" end
            if (pos & HAT_RIGHT) ~= 0 then parts[#parts + 1] = "右" end
            dirStr = table.concat(parts, "+")
        end
        self:Add(string.format("✦ D-Pad: %s", dirStr), LOG_COLORS.hat)
    end)

    SubscribeToEvent("JoystickConnected", function(_, eventData)
        local id = eventData["JoystickID"]:GetInt()
        local js = input:GetJoystick(id)
        local name = js and js.name or ("ID:" .. tostring(id))
        self:Add("🔌 已连接: " .. name, LOG_COLORS.connect)
    end)

    SubscribeToEvent("JoystickDisconnected", function(_, eventData)
        self:Add("⚡ 控制器已断开", LOG_COLORS.disconnect)
    end)

    self:Add("日志系统已初始化", LOG_COLORS.connect)
end

--- 添加日志条目
---@param text string 日志文本
---@param color table 颜色 {r, g, b, a}
function ControllerLogger:Add(text, color)
    table.insert(self.entries, 1, {
        time = os.clock() - self.startTime,
        text = text,
        color = color or LOG_COLORS.axis,
    })
    if #self.entries > self.maxEntries then
        table.remove(self.entries)
    end
end

--- 使用 NanoVG 绘制日志面板
---@param vg userdata NanoVG 上下文
---@param x number 面板左上角 X
---@param y number 面板左上角 Y
---@param w number 面板宽度
---@param h number 面板高度
function ControllerLogger:Draw(vg, x, y, w, h)
    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(25, 25, 35, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 60, 80, 200))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
    nvgText(vg, x + 8, y + 6, "事件日志")

    -- 日志条目
    local lineH = 16
    local startY = y + 28
    local maxLines = math.floor((h - 36) / lineH)

    nvgFontSize(vg, 11)
    for i = 1, math.min(#self.entries, maxLines) do
        local entry = self.entries[i]
        local ly = startY + (i - 1) * lineH
        local c = entry.color

        -- 时间戳
        nvgFillColor(vg, nvgRGBA(100, 100, 120, 180))
        nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
        nvgText(vg, x + 8, ly, string.format("%.1fs", entry.time))

        -- 日志文本
        nvgFillColor(vg, nvgRGBA(c.r, c.g, c.b, c.a))
        nvgText(vg, x + 50, ly, entry.text)
    end
end

--- 清空日志
function ControllerLogger:Clear()
    self.entries = {}
    self:Add("日志已清空", LOG_COLORS.connect)
end

return ControllerLogger
```

---

## §4 工具函数

### 死区过滤

```lua
--- 线性死区过滤
---@param value number 原始轴值 (-1.0 ~ 1.0)
---@param deadzone number 死区阈值 (推荐 0.1 ~ 0.25)
---@return number 过滤后的值
local function applyDeadzone(value, deadzone)
    if math.abs(value) < deadzone then
        return 0.0
    end
    local sign = value > 0 and 1 or -1
    return sign * (math.abs(value) - deadzone) / (1.0 - deadzone)
end

--- 圆形死区过滤（同时考虑两轴）
---@param x number X轴原始值
---@param y number Y轴原始值
---@param deadzone number 死区半径 (推荐 0.15 ~ 0.25)
---@return number, number 过滤后的 X, Y
local function applyCircularDeadzone(x, y, deadzone)
    local magnitude = math.sqrt(x * x + y * y)
    if magnitude < deadzone then
        return 0.0, 0.0
    end
    local scale = (magnitude - deadzone) / (1.0 - deadzone)
    local norm = scale / magnitude
    return x * norm, y * norm
end
```

### 按钮/轴名称查询

```lua
--- 获取按钮的可读名称
---@param buttonIndex integer 按钮索引
---@param isGamepad boolean 是否为标准手柄
---@return string
local function getButtonName(buttonIndex, isGamepad)
    if isGamepad and BUTTON_NAMES[buttonIndex] then
        return BUTTON_NAMES[buttonIndex]
    end
    return "Button " .. tostring(buttonIndex)
end

--- 获取轴的可读名称
---@param axisIndex integer 轴索引
---@param isGamepad boolean 是否为标准手柄
---@return string
local function getAxisName(axisIndex, isGamepad)
    if isGamepad and AXIS_NAMES[axisIndex] then
        return AXIS_NAMES[axisIndex]
    end
    return "Axis " .. tostring(axisIndex)
end
```
