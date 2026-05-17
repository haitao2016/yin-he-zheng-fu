---
name: "controller-tester"
description: |
  游戏控制器/手柄实时测试与可视化工具。灵感来源于 Dtownsend117/Controller_Tester，
  将 Python 控制器测试工具的核心理念迁移到 UrhoX Lua 引擎内，
  为开发者提供控制器检测、按钮/摇杆/扳机实时可视化、事件日志、
  死区校准等完整的手柄调试能力。使用 NanoVG 绘制交互式手柄面板。
trigger-keywords:
  - 控制器
  - 手柄
  - 游戏手柄
  - controller
  - gamepad
  - joystick
  - 摇杆
  - 手柄测试
  - 控制器测试
  - 手柄调试
  - 输入测试
  - 按键测试
  - 手柄校准
  - 死区
  - deadzone
  - controller tester
  - gamepad tester
---

# Controller Tester — 游戏控制器实时测试与可视化工具

> **灵感来源**: [Dtownsend117/Controller_Tester](https://github.com/Dtownsend117/Controller_Tester)
>
> 将 Python 控制器测试工具的核心理念迁移到 UrhoX Lua 引擎，
> 提供控制器检测、实时输入可视化、事件日志和死区校准等完整调试工具集。

---

## 一、概述

### 1.1 原始项目

原始 Python 项目通过语音识别 + 键盘自动化（pyautogui）打开 Windows 游戏控制器面板（joy.cpl），
列出并选择控制器查看属性。核心功能是**控制器检测与状态查看**。

### 1.2 UrhoX 迁移方案

在 UrhoX 中重新实现为**引擎内控制器测试工具**：
- 使用 `Input` API（`JoystickState`）直接读取硬件输入
- 使用 NanoVG 绘制实时可视化面板（摇杆、按钮、扳机）
- 支持控制器热插拔检测
- 提供事件日志和死区配置

### 1.3 模块架构

```
controller-tester/
├── SKILL.md                              # 本文件（< 500 行）
└── references/
    ├── modules-implementation.md          # 三大模块完整实现
    └── integration-examples.md            # 集成示例与使用场景
```

**三大模块**：

| 模块 | 职责 | 文件位置 |
|------|------|---------|
| ControllerDetector | 控制器检测、热插拔、信息查询 | modules-implementation.md §1 |
| ControllerVisualizer | NanoVG 实时输入可视化面板 | modules-implementation.md §2 |
| ControllerLogger | 输入事件日志记录与回放 | modules-implementation.md §3 |

---

## 二、核心 API 速查

### 2.1 JoystickState（控制器状态读取）

```lua
-- 获取连接的控制器数量
local count = input:GetNumJoysticks()

-- 按索引获取控制器状态（0-based 索引）
---@type JoystickState
local js = input:GetJoystickByIndex(0)

-- 控制器信息
js.name           -- 控制器名称（string）
js.joystickID     -- 控制器 ID（int）
js:IsController()  -- 是否为标准游戏手柄（bool）
js.numButtons     -- 按钮数量
js.numAxes        -- 轴数量
js.numHats        -- 帽子开关数量

-- 实时输入读取
js:GetButtonDown(buttonIndex)   -- 按钮是否按下（bool）
js:GetAxisPosition(axisIndex)   -- 轴位置（float, -1.0 ~ 1.0）
js:GetHatPosition(hatIndex)     -- 帽子开关位置（int, HAT_* 枚举）
```

### 2.2 控制器枚举

```lua
-- 标准手柄按钮（用于 IsController() == true 的手柄）
CONTROLLER_BUTTON_A              -- A / ×
CONTROLLER_BUTTON_B              -- B / ○
CONTROLLER_BUTTON_X              -- X / □
CONTROLLER_BUTTON_Y              -- Y / △
CONTROLLER_BUTTON_BACK           -- Back / Select
CONTROLLER_BUTTON_START          -- Start / Options
CONTROLLER_BUTTON_LEFTSTICK      -- 左摇杆按下
CONTROLLER_BUTTON_RIGHTSTICK     -- 右摇杆按下
CONTROLLER_BUTTON_LEFTSHOULDER   -- LB / L1
CONTROLLER_BUTTON_RIGHTSHOULDER  -- RB / R1
CONTROLLER_BUTTON_DPAD_UP        -- 十字键上
CONTROLLER_BUTTON_DPAD_DOWN      -- 十字键下
CONTROLLER_BUTTON_DPAD_LEFT      -- 十字键左
CONTROLLER_BUTTON_DPAD_RIGHT     -- 十字键右

-- 标准手柄轴
CONTROLLER_AXIS_LEFTX            -- 左摇杆 X（-1=左, 1=右）
CONTROLLER_AXIS_LEFTY            -- 左摇杆 Y（-1=上, 1=下）
CONTROLLER_AXIS_RIGHTX           -- 右摇杆 X
CONTROLLER_AXIS_RIGHTY           -- 右摇杆 Y
CONTROLLER_AXIS_TRIGGERLEFT      -- 左扳机（0~1）
CONTROLLER_AXIS_TRIGGERRIGHT     -- 右扳机（0~1）

-- 帽子开关位置
HAT_CENTER  HAT_UP  HAT_RIGHT  HAT_DOWN  HAT_LEFT
```

### 2.3 控制器事件

```lua
-- 控制器连接/断开
SubscribeToEvent("JoystickConnected", function(eventType, eventData)
    local joystickID = eventData["JoystickID"]:GetInt()
end)

SubscribeToEvent("JoystickDisconnected", function(eventType, eventData)
    local joystickID = eventData["JoystickID"]:GetInt()
end)

-- 按钮按下/释放
SubscribeToEvent("JoystickButtonDown", function(eventType, eventData)
    local joystickID = eventData["JoystickID"]:GetInt()
    local button     = eventData["Button"]:GetInt()
end)

SubscribeToEvent("JoystickButtonUp", function(eventType, eventData)
    local joystickID = eventData["JoystickID"]:GetInt()
    local button     = eventData["Button"]:GetInt()
end)

-- 摇杆/轴移动
SubscribeToEvent("JoystickAxisMove", function(eventType, eventData)
    local joystickID = eventData["JoystickID"]:GetInt()
    local axis       = eventData["Button"]:GetInt()   -- 注意：字段名是 "Button" 但值是轴索引
    local position   = eventData["Position"]:GetFloat()
end)

-- 帽子开关变化
SubscribeToEvent("JoystickHatMove", function(eventType, eventData)
    local joystickID = eventData["JoystickID"]:GetInt()
    local hat        = eventData["Button"]:GetInt()
    local position   = eventData["Position"]:GetInt()
end)
```

> ⚠️ **关键陷阱**：`JoystickAxisMove` 事件中，轴索引存储在 `"Button"` 字段中，不是 `"Axis"`。

---

## 三、快速集成（一键嵌入）

### 3.1 最简用法（独立测试场景）

```lua
-- scripts/main.lua
require "LuaScripts/Utilities/Sample"

local vg = nil
local font = -1

-- 控制器状态缓存
local controllerInfo = {
    connected = false,
    name = "未检测到控制器",
    buttons = {},
    axes = {},
    hats = {},
}

function Start()
    SampleStart()

    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    font = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("JoystickConnected", "HandleJoystickConnected")
    SubscribeToEvent("JoystickDisconnected", "HandleJoystickDisconnected")
end

function HandleJoystickConnected(eventType, eventData)
    local id = eventData["JoystickID"]:GetInt()
    local js = input:GetJoystick(id)
    if js then
        controllerInfo.connected = true
        controllerInfo.name = js.name
        log:Write(LOG_INFO, "控制器已连接: " .. js.name)
    end
end

function HandleJoystickDisconnected(eventType, eventData)
    controllerInfo.connected = false
    controllerInfo.name = "控制器已断开"
    log:Write(LOG_INFO, "控制器已断开")
end

function HandleUpdate(eventType, eventData)
    if input:GetNumJoysticks() < 1 then
        controllerInfo.connected = false
        return
    end
    local js = input:GetJoystickByIndex(0)
    if not js then return end

    controllerInfo.connected = true
    controllerInfo.name = js.name

    -- 读取按钮状态
    controllerInfo.buttons = {}
    for i = 0, js.numButtons - 1 do
        controllerInfo.buttons[i] = js:GetButtonDown(i)
    end

    -- 读取轴状态
    controllerInfo.axes = {}
    for i = 0, js.numAxes - 1 do
        controllerInfo.axes[i] = js:GetAxisPosition(i)
    end

    -- 读取帽子开关
    controllerInfo.hats = {}
    for i = 0, js.numHats - 1 do
        controllerInfo.hats[i] = js:GetHatPosition(i)
    end
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()
    nvgBeginFrame(vg, w, h, graphics:GetDPR())

    nvgFontFace(vg, "sans")

    -- 标题
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, w * 0.5, 20, "🎮 Controller Tester")

    -- 控制器名称
    nvgFontSize(vg, 18)
    local nameColor = controllerInfo.connected
        and nvgRGBA(100, 255, 100, 255)
        or nvgRGBA(255, 100, 100, 255)
    nvgFillColor(vg, nameColor)
    nvgText(vg, w * 0.5, 55, controllerInfo.name)

    if controllerInfo.connected then
        DrawAxesPanel(w, h)
        DrawButtonsPanel(w, h)
    end

    nvgEndFrame(vg)
end

-- 详细绘制实现见 references/modules-implementation.md §2
function DrawAxesPanel(w, h) ... end
function DrawButtonsPanel(w, h) ... end
```

> 完整实现见 `references/modules-implementation.md`

---

## 四、模块详解

### 4.1 ControllerDetector — 控制器检测

**职责**：扫描已连接控制器，监听热插拔事件，提供控制器信息查询。

```lua
local ControllerDetector = {}

function ControllerDetector:Init()
    self.controllers = {}  -- joystickID → info
    self:ScanControllers()
    -- 订阅热插拔事件
    SubscribeToEvent("JoystickConnected", function(_, ed)
        self:OnConnected(ed["JoystickID"]:GetInt())
    end)
    SubscribeToEvent("JoystickDisconnected", function(_, ed)
        self:OnDisconnected(ed["JoystickID"]:GetInt())
    end)
end

function ControllerDetector:ScanControllers()
    self.controllers = {}
    local count = input:GetNumJoysticks()
    for i = 0, count - 1 do
        local js = input:GetJoystickByIndex(i)
        if js then
            self.controllers[js.joystickID] = {
                name = js.name,
                isGamepad = js:IsController(),
                numButtons = js.numButtons,
                numAxes = js.numAxes,
                numHats = js.numHats,
            }
        end
    end
end

function ControllerDetector:GetActiveController()
    for id, info in pairs(self.controllers) do
        return id, info  -- 返回第一个
    end
    return nil, nil
end
```

### 4.2 ControllerVisualizer — NanoVG 可视化面板

**职责**：用 NanoVG 绘制摇杆圆盘、按钮矩阵、扳机进度条、帽子开关方向。

核心绘制函数：

| 函数 | 绘制内容 |
|------|---------|
| `DrawStick(cx, cy, r, axisX, axisY)` | 摇杆圆盘（圆底+指示点） |
| `DrawTrigger(x, y, w, h, value, label)` | 扳机进度条 |
| `DrawButton(x, y, r, pressed, label)` | 单个按钮（亮/暗） |
| `DrawDPad(cx, cy, size, hatPos)` | 十字键四方向 |
| `DrawButtonGrid(x, y, js)` | 全部按钮网格 |

> 完整实现代码见 `references/modules-implementation.md §2`

### 4.3 ControllerLogger — 事件日志

**职责**：记录控制器输入事件（按钮按下/释放、轴变化），支持滚动查看历史。

```lua
local ControllerLogger = {}

function ControllerLogger:Init(maxEntries)
    self.entries = {}
    self.maxEntries = maxEntries or 50
    -- 订阅输入事件
    SubscribeToEvent("JoystickButtonDown", function(_, ed)
        self:Log("BUTTON DOWN", ed["Button"]:GetInt(), ed["JoystickID"]:GetInt())
    end)
    SubscribeToEvent("JoystickButtonUp", function(_, ed)
        self:Log("BUTTON UP", ed["Button"]:GetInt(), ed["JoystickID"]:GetInt())
    end)
    SubscribeToEvent("JoystickAxisMove", function(_, ed)
        local pos = ed["Position"]:GetFloat()
        if math.abs(pos) > 0.15 then  -- 过滤死区噪声
            self:Log(string.format("AXIS %d: %.2f",
                ed["Button"]:GetInt(), pos), nil, ed["JoystickID"]:GetInt())
        end
    end)
end

function ControllerLogger:Log(action, button, joystickID)
    table.insert(self.entries, 1, {
        time = os.clock(),
        action = action,
        button = button,
        joystickID = joystickID,
    })
    if #self.entries > self.maxEntries then
        table.remove(self.entries)
    end
end
```

---

## 五、死区与校准

### 5.1 死区过滤

```lua
--- 应用死区过滤到轴值
---@param value number 原始轴值 (-1.0 ~ 1.0)
---@param deadzone number 死区阈值 (0.0 ~ 1.0，推荐 0.1~0.25)
---@return number 过滤后的值
local function applyDeadzone(value, deadzone)
    if math.abs(value) < deadzone then
        return 0.0
    end
    -- 重新映射到 0~1 范围
    local sign = value > 0 and 1 or -1
    return sign * (math.abs(value) - deadzone) / (1.0 - deadzone)
end
```

### 5.2 摇杆圆形死区

```lua
--- 圆形死区（同时考虑两轴）
---@param x number X轴原始值
---@param y number Y轴原始值
---@param deadzone number 死区半径
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

---

## 六、引擎兼容性规则

| 规则 | 说明 |
|------|------|
| NanoVG 渲染事件 | 所有 NanoVG 绘制必须在 `NanoVGRender` 事件中 |
| 字体创建 | `nvgCreateFont` 只在 `Start()` 调用一次 |
| 分辨率 | 使用 `graphics:GetWidth()/GetDPR()` 获取逻辑分辨率 |
| 轴索引 | `JoystickAxisMove` 事件中轴索引在 `"Button"` 字段 |
| 控制器索引 | `GetJoystickByIndex()` 使用 0-based 索引 |
| Lua 数组 | 自定义数组从 1 开始，引擎 API 的索引从 0 开始 |
| 枚举值 | 使用 `CONTROLLER_BUTTON_A` 而非数字常量 |
| 不要用 SetMode | 使用 `GetWidth()/GetHeight()/GetDPR()` |

---

## 七、使用场景

| 场景 | 做法 |
|------|------|
| 独立手柄测试工具 | 直接使用快速集成示例（§3.1） |
| 嵌入游戏调试菜单 | 作为调试面板，按特定键切换显示 |
| 手柄按键映射配置 | 结合 Logger 捕获用户按键，建立映射表 |
| 多手柄支持测试 | 遍历所有 JoystickByIndex，分栏显示 |
| 死区校准界面 | 用 Slider 调节死区值，实时预览效果 |

> 详细集成示例见 `references/integration-examples.md`
