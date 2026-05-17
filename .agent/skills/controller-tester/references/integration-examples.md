# Controller Tester — 集成示例

> 本文档提供多种场景下的 Controller Tester 集成示例。

---

## §1 独立测试工具（完整可运行示例）

最简单的用法 — 创建一个独立的控制器测试场景。

```lua
-- scripts/main.lua
-- 独立控制器测试工具
require "LuaScripts/Utilities/Sample"

-- 模块引用（将 modules-implementation.md 的模块文件放到 scripts/ 目录下）
local Detector   = require "ControllerDetector"
local Visualizer = require "ControllerVisualizer"
local Logger     = require "ControllerLogger"

function Start()
    SampleStart()

    -- 初始化三大模块
    Detector:Init()
    Visualizer:Init()
    Logger:Init(60, 0.15)

    -- 订阅渲染和更新事件
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")

    log:Write(LOG_INFO, "Controller Tester 已启动")
end

function HandleUpdate(eventType, eventData)
    -- Tab 键切换控制器
    if input:GetKeyPress(KEY_TAB) then
        Detector:SelectNext()
    end

    -- [ ] 键调节死区
    if input:GetKeyPress(KEY_LEFTBRACKET) then
        Visualizer:AdjustDeadzone(-0.05)
    end
    if input:GetKeyPress(KEY_RIGHTBRACKET) then
        Visualizer:AdjustDeadzone(0.05)
    end

    -- C 键清空日志
    if input:GetKeyPress(KEY_C) then
        Logger:Clear()
    end
end

function HandleNanoVGRender(eventType, eventData)
    local js = Detector:GetActiveJoystick()
    local info = Detector:GetActiveInfo()

    if js and info then
        -- 绘制完整面板
        Visualizer:DrawFullPanel(js, info)

        -- 在面板右侧绘制事件日志
        local w = graphics:GetWidth() / graphics:GetDPR()
        local h = graphics:GetHeight() / graphics:GetDPR()

        -- 需要在 DrawFullPanel 的 nvgEndFrame 前插入日志绘制
        -- 或者使用独立的 beginFrame/endFrame
        -- 这里展示独立绘制方式：
        local vg = Visualizer.vg
        nvgBeginFrame(vg, w, h, graphics:GetDPR())
        Logger:Draw(vg, w * 0.72, 100, w * 0.26, h - 120)
        nvgEndFrame(vg)
    else
        Visualizer:DrawNoController()
    end
end
```

---

## §2 嵌入游戏调试菜单

将控制器测试面板嵌入到游戏的调试模式中，按 F3 切换显示。

```lua
-- scripts/main.lua（片段）
-- 在游戏主文件中添加控制器调试功能

local Detector   = require "ControllerDetector"
local Visualizer = require "ControllerVisualizer"
local showControllerDebug = false

function Start()
    -- ... 游戏初始化代码 ...

    Detector:Init()
    Visualizer:Init()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleUpdate(eventType, eventData)
    -- F3 键切换控制器调试面板
    if input:GetKeyPress(KEY_F3) then
        showControllerDebug = not showControllerDebug
    end

    -- ... 游戏逻辑 ...

    -- 使用控制器输入驱动游戏
    if Detector:GetCount() > 0 then
        local js = Detector:GetActiveJoystick()
        if js then
            -- 摇杆控制移动
            local moveX = js:GetAxisPosition(CONTROLLER_AXIS_LEFTX)
            local moveY = js:GetAxisPosition(CONTROLLER_AXIS_LEFTY)
            -- 应用死区
            if math.abs(moveX) < 0.15 then moveX = 0 end
            if math.abs(moveY) < 0.15 then moveY = 0 end
            -- ... 使用 moveX, moveY 驱动角色移动 ...

            -- A 键跳跃
            if js:GetButtonDown(CONTROLLER_BUTTON_A) then
                -- ... 跳跃逻辑 ...
            end
        end
    end
end

function HandleNanoVGRender(eventType, eventData)
    -- ... 游戏 NanoVG 绘制 ...

    -- 调试面板叠加
    if showControllerDebug then
        local js = Detector:GetActiveJoystick()
        local info = Detector:GetActiveInfo()
        if js and info then
            Visualizer:DrawFullPanel(js, info)
        else
            Visualizer:DrawNoController()
        end
    end
end
```

---

## §3 手柄按键映射配置器

让玩家自定义手柄按键映射（例如：攻击、跳跃、翻滚绑定到哪个按钮）。

```lua
-- scripts/KeyMapper.lua
-- 手柄按键映射配置器

local KeyMapper = {
    actions = {},        -- actionName → buttonIndex
    listening = false,   -- 是否正在监听按键
    listenAction = nil,  -- 正在映射的动作名
    onMapped = nil,      -- 映射完成回调
}

--- 定义可映射的动作
function KeyMapper:SetActions(actionNames)
    for _, name in ipairs(actionNames) do
        self.actions[name] = -1  -- 未映射
    end
end

--- 开始监听一个动作的按键映射
---@param actionName string 要映射的动作名
---@param callback? function 映射完成回调 function(actionName, buttonIndex)
function KeyMapper:StartListening(actionName, callback)
    self.listening = true
    self.listenAction = actionName
    self.onMapped = callback

    SubscribeToEvent("JoystickButtonDown", "HandleMapButton")
    log:Write(LOG_INFO, string.format("请按下要绑定到 [%s] 的按钮...", actionName))
end

--- 处理映射按钮
function HandleMapButton(eventType, eventData)
    if not KeyMapper.listening then return end

    local button = eventData["Button"]:GetInt()
    KeyMapper.actions[KeyMapper.listenAction] = button

    log:Write(LOG_INFO, string.format("[%s] 已绑定到按钮 %d",
        KeyMapper.listenAction, button))

    KeyMapper.listening = false
    if KeyMapper.onMapped then
        KeyMapper.onMapped(KeyMapper.listenAction, button)
    end
end

--- 检查动作是否按下
---@param actionName string 动作名称
---@param js JoystickState 控制器状态
---@return boolean
function KeyMapper:IsActionDown(actionName, js)
    local btn = self.actions[actionName]
    if btn and btn >= 0 then
        return js:GetButtonDown(btn)
    end
    return false
end

--- 检查动作是否刚按下（本帧）
---@param actionName string 动作名称
---@param js JoystickState 控制器状态
---@return boolean
function KeyMapper:IsActionPressed(actionName, js)
    local btn = self.actions[actionName]
    if btn and btn >= 0 then
        return js:GetButtonPress(btn)
    end
    return false
end

--- 导出映射配置（用于持久化存储）
---@return table actionName → buttonIndex
function KeyMapper:Export()
    local config = {}
    for name, btn in pairs(self.actions) do
        config[name] = btn
    end
    return config
end

--- 导入映射配置
---@param config table actionName → buttonIndex
function KeyMapper:Import(config)
    for name, btn in pairs(config) do
        if self.actions[name] ~= nil then
            self.actions[name] = btn
        end
    end
end

return KeyMapper
```

**使用示例**：

```lua
local KeyMapper = require "KeyMapper"

function Start()
    -- 定义游戏动作
    KeyMapper:SetActions({"jump", "attack", "dodge", "interact"})

    -- 从存档加载映射（如有）
    -- KeyMapper:Import(savedConfig)

    -- 或让玩家配置
    KeyMapper:StartListening("jump", function(action, btn)
        log:Write(LOG_INFO, action .. " → Button " .. btn)
        -- 继续配置下一个
        KeyMapper:StartListening("attack")
    end)
end

function HandleUpdate(eventType, eventData)
    local js = input:GetJoystickByIndex(0)
    if not js then return end

    if KeyMapper:IsActionPressed("jump", js) then
        -- 执行跳跃
    end
    if KeyMapper:IsActionDown("attack", js) then
        -- 执行攻击
    end
end
```

---

## §4 多手柄支持（多人本地对战）

检测和显示多个控制器状态，支持本地多人对战。

```lua
-- scripts/MultiPlayer.lua（片段）
-- 多手柄本地对战示例

local Detector = require "ControllerDetector"

local players = {}  -- playerIndex → { joystickID, ... }

function Start()
    Detector:Init()

    -- 监听新控制器连接，自动分配玩家
    Detector.onConnected = function(id, info)
        local playerIdx = #players + 1
        players[playerIdx] = {
            joystickID = id,
            name = "Player " .. playerIdx,
            controllerName = info.name,
        }
        log:Write(LOG_INFO, string.format(
            "玩家 %d 已加入 (控制器: %s)", playerIdx, info.name))
    end

    Detector.onDisconnected = function(id)
        for i, p in ipairs(players) do
            if p.joystickID == id then
                log:Write(LOG_INFO, string.format("玩家 %d 已断开", i))
                table.remove(players, i)
                break
            end
        end
    end
end

function HandleUpdate(eventType, eventData)
    for i, player in ipairs(players) do
        local js = input:GetJoystick(player.joystickID)
        if js then
            -- 每个玩家独立处理输入
            local moveX = js:GetAxisPosition(CONTROLLER_AXIS_LEFTX)
            local moveY = js:GetAxisPosition(CONTROLLER_AXIS_LEFTY)

            -- ... 用 moveX, moveY 驱动 player[i] 的角色 ...

            if js:GetButtonPress(CONTROLLER_BUTTON_A) then
                -- 玩家 i 跳跃
            end
        end
    end
end
```

---

## §5 使用 UI 组件构建设置面板

结合 `urhox-libs/UI` 组件构建死区配置界面（替代纯 NanoVG）。

```lua
-- scripts/ControllerSettings.lua（片段）
-- 使用 UI 组件构建控制器设置面板

local UI = require("urhox-libs/UI")

local deadzone = 0.15
local selectedController = 0

function CreateSettingsPanel()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    local root = UI.Panel {
        width = 400, height = 300,
        padding = 16,
        backgroundColor = "#1E1E2EE0",
        borderRadius = 8,
        children = {
            UI.Label {
                text = "控制器设置",
                fontSize = 20,
                color = "#FFFFFF",
                marginBottom = 16,
            },

            -- 控制器选择
            UI.Label { text = "当前控制器:", fontSize = 14, color = "#AAAACC" },
            UI.Label {
                id = "controllerName",
                text = "未检测到",
                fontSize = 16,
                color = "#66FF66",
                marginBottom = 12,
            },

            -- 死区滑块
            UI.Label {
                text = string.format("摇杆死区: %.0f%%", deadzone * 100),
                id = "deadzoneLabel",
                fontSize = 14,
                color = "#AAAACC",
            },
            UI.Slider {
                value = deadzone * 100,
                min = 0,
                max = 50,
                step = 5,
                onChange = function(self, v)
                    deadzone = v / 100
                    -- 更新标签
                    local label = UI.FindById("deadzoneLabel")
                    if label then
                        label:SetText(string.format("摇杆死区: %.0f%%", v))
                    end
                end,
            },

            -- 测试按钮
            UI.Button {
                text = "开始测试",
                variant = "primary",
                marginTop = 16,
                onClick = function(self)
                    -- 切换到测试面板
                end,
            },
        },
    }

    UI.SetRoot(root)
end
```

---

## §6 UrhoX 引擎兼容性检查清单

集成控制器测试功能时，确认以下事项：

| 检查项 | 正确做法 |
|--------|---------|
| NanoVG 绘制位置 | 所有 NanoVG 调用在 `NanoVGRender` 事件中 |
| 字体创建 | `nvgCreateFont` 只在 `Start()` 中调用一次 |
| 分辨率获取 | `graphics:GetWidth()/GetDPR()` 获取逻辑分辨率 |
| 轴事件字段 | `JoystickAxisMove` 的轴索引在 `"Button"` 字段 |
| 控制器索引 | `GetJoystickByIndex()` 使用 0-based 索引 |
| 按钮判断 | 使用 `CONTROLLER_BUTTON_A` 枚举，不用数字 |
| Lua 数组 | 自建数组从 1 开始，引擎 API 索引从 0 开始 |
| 不用 SetMode | 禁止调用 `graphics:SetMode()` |
| 文件存储 | 用 `File` API，不用 `io` 库 |
| 事件数据访问 | `eventData["Key"]:GetInt()` 模式 |
