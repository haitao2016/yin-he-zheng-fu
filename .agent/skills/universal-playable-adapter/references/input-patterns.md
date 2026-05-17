# 输入模式详细代码参考

> `universal-playable-adapter` Skill 的补充参考文档
> 按游戏类型提供完整的输入适配代码模式

---

## 1. 通用：统一移动输入读取器

所有游戏类型共用的底层输入函数，同时支持键盘 + 手柄 + 虚拟摇杆。

```lua
--- 读取归一化移动输入 (dx, dy ∈ [-1, 1])
--- 自动合并键盘 WASD/方向键 + 手柄左摇杆 + 屏幕虚拟摇杆
---@return number dx, number dy
local function getMovementInput()
    local dx, dy = 0, 0

    -- 键盘
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then dy = dy - 1 end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then dy = dy + 1 end
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then dx = dx - 1 end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then dx = dx + 1 end

    -- 手柄（物理手柄 + 虚拟摇杆共享同一接口）
    if input:GetNumJoysticks() > 0 then
        local js = input:GetJoystickByIndex(0)
        if js then
            local jx = js:GetAxisPosition(0)
            local jy = js:GetAxisPosition(1)
            local deadzone = 0.15
            if math.abs(jx) > deadzone then dx = dx + jx end
            if math.abs(jy) > deadzone then dy = dy + jy end
        end
    end

    -- 归一化（防止斜向速度 > 1）
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1.0 then dx, dy = dx / len, dy / len end
    return dx, dy
end
```

---

## 2. 3D 角色游戏（TPS/动作/RPG）

### 方案 A：使用 GameHUD（推荐）

适用于 3D 角色移动 + 视角控制的游戏。GameHUD 自动在移动端显示虚拟摇杆和按钮。

```lua
local UI = require("urhox-libs/UI")
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")

-- ① UI 初始化
UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
    scale = UI.Scale.DEFAULT,
})

-- ② 创建 GameHUD
local hud = UI.GameHUD({
    -- 移动摇杆（移动端自动显示，桌面端隐藏）
    joystick = { side = "left" },
    -- 动作按钮
    buttons = {
        { label = "Jump",   side = "right", row = 1, col = 1,
          keyBinding = "SPACE", onClick = function() doJump() end },
        { label = "Attack", side = "right", row = 1, col = 2,
          keyBinding = "F",     mouseBinding = "LMB",
          onClick = function() doAttack() end },
    },
})
UI.SetRoot(hud)

-- ③ 更新（PostUpdate 中）
function HandlePostUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- GameHUD 的摇杆输入通过 joystick 接口读取
    -- 桌面端自动 fallback 到键盘 WASD
    local dx, dy = getMovementInput()
    moveCharacter(dx, dy, dt)
end
```

### 方案 B：使用 VirtualControls（自定义外观）

适用于需要高度自定义摇杆外观的场景。

```lua
require "urhox-libs.UI.VirtualControls"

function Start()
    -- 创建虚拟摇杆
    local joystick = VirtualControls.CreateJoystick({
        position = Vector2(200, -200),
        alignment = { HA_LEFT, VA_BOTTOM },
        radius = 80,
    })

    -- 创建虚拟按钮（右侧）
    VirtualControls.CreateButton({
        label = "Jump",
        position = Vector2(-200, -300),
        alignment = { HA_RIGHT, VA_BOTTOM },
        keyBinding = KEY_SPACE,
        on_press = function() doJump() end,
    })

    VirtualControls.CreateButton({
        label = "Attack",
        position = Vector2(-100, -200),
        alignment = { HA_RIGHT, VA_BOTTOM },
        keyBinding = "F",
        mouseBinding = "LMB",
        on_press = function() doAttack() end,
    })

    -- 将摇杆绑定到角色控制
    VirtualControls.SetControls(characterControls)

    -- 初始化（自动订阅 Update 和 NanoVGRender 事件）
    VirtualControls.Initialize()
end
```

### 视角控制（鼠标/触摸右半屏/手柄右摇杆）

```lua
local yaw, pitch = 0, 0
local MOUSE_SENSITIVITY = 0.1
local TOUCH_SENSITIVITY = 0.15
local GAMEPAD_SENSITIVITY = 2.0

function HandlePostUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 鼠标（桌面 MM_RELATIVE 模式下）
    if input.mouseMode == MM_RELATIVE then
        local mouseMove = input:GetMouseMove()
        yaw = yaw + mouseMove.x * MOUSE_SENSITIVITY
        pitch = math.max(-89, math.min(89, pitch + mouseMove.y * MOUSE_SENSITIVITY))
    end

    -- 手柄右摇杆
    if input:GetNumJoysticks() > 0 then
        local js = input:GetJoystickByIndex(0)
        if js and js:GetNumAxes() >= 4 then
            local rx = js:GetAxisPosition(2)  -- 右摇杆 X
            local ry = js:GetAxisPosition(3)  -- 右摇杆 Y
            if math.abs(rx) > 0.15 then
                yaw = yaw + rx * GAMEPAD_SENSITIVITY
            end
            if math.abs(ry) > 0.15 then
                pitch = math.max(-89, math.min(89, pitch + ry * GAMEPAD_SENSITIVITY))
            end
        end
    end

    -- 触摸（右半屏拖拽）→ 通常由 GameHUD 或 VirtualControls 的 TouchLookArea 处理
end
```

---

## 3. 2D 平台跳跃游戏

### 键盘 + 触摸 双模式

```lua
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")

local isMobile = PlatformUtils.IsMobilePlatform()
    or PlatformUtils.IsWebPlatform()  -- Web 可能是手机浏览器

-- 桌面端：纯键盘
-- 移动端：左半屏虚拟方向键 + 右侧跳跃按钮

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    local moveX = 0
    local jump = false

    -- 键盘输入（桌面端 + Web 键盘）
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then moveX = -1 end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then moveX = 1 end
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_UP) then
        jump = true
    end

    -- 手柄输入
    if input:GetNumJoysticks() > 0 then
        local js = input:GetJoystickByIndex(0)
        if js then
            local jx = js:GetAxisPosition(0)
            if math.abs(jx) > 0.15 then moveX = moveX + jx end
            -- 手柄 A 键跳跃（button 0）
            if js:GetButtonPress(0) then jump = true end
        end
    end

    applyMovement(moveX, jump, dt)
end
```

### 触摸按钮（移动端 UI 叠加）

```lua
local UI = require("urhox-libs/UI")

-- 仅移动端显示触控按钮
if isMobile then
    local touchUI = UI.SafeAreaView({
        edges = "all",
        width = "100%", height = "100%",
        position = "absolute",
        children = {
            -- 左侧方向键
            UI.Panel({
                position = "absolute", left = 20, bottom = 20,
                flexDirection = "row", gap = 10,
                children = {
                    UI.Button({
                        text = "←", width = 64, height = 64,
                        onPointerDown = function() touchMoveX = -1 end,
                        onPointerUp   = function() touchMoveX = 0 end,
                    }),
                    UI.Button({
                        text = "→", width = 64, height = 64,
                        onPointerDown = function() touchMoveX = 1 end,
                        onPointerUp   = function() touchMoveX = 0 end,
                    }),
                },
            }),
            -- 右侧跳跃
            UI.Button({
                text = "JUMP", width = 80, height = 80,
                position = "absolute", right = 20, bottom = 20,
                onPointerDown = function() touchJump = true end,
            }),
        },
    })
    UI.SetRoot(touchUI)
end
```

---

## 4. 休闲/益智/点击类游戏

### 统一 Pointer 事件（鼠标 = 触摸）

休闲游戏最简单的方案：只处理 PointerEvent，鼠标和触摸自动统一。

```lua
local UI = require("urhox-libs/UI")

-- UI 组件自带 Pointer 事件，自动统一鼠标/触摸
local card = UI.Panel({
    width = 120, height = 160,
    backgroundColor = "#3498db",
    borderRadius = 8,

    -- 这些事件鼠标/触摸通用
    onPointerDown = function(self, e)
        -- e.x, e.y       = 屏幕坐标
        -- e.pointerId     = 0(鼠标) 或 1+(触摸)
        -- e.pointerType   = "mouse" / "touch" / "pen"
        -- e.button        = 0(左键)/1(中键)/2(右键)，触摸始终=0
        self:set("backgroundColor", "#2980b9")
    end,

    onPointerUp = function(self, e)
        self:set("backgroundColor", "#3498db")
        handleCardClick(self)
    end,

    -- 拖拽
    onPointerMove = function(self, e)
        if e.buttons > 0 then  -- 按下拖拽
            self:set("left", e.x - 60)
            self:set("top", e.y - 80)
        end
    end,
})
```

### 手势识别（UI 控件上的 swipe/pinch）

```lua
-- UI 控件内置手势支持
local gameBoard = UI.Panel({
    width = "100%", height = "100%",

    -- 滑动手势
    onSwipe = function(self, direction, velocity)
        -- direction: "left" | "right" | "up" | "down"
        -- velocity: 滑动速度
        if direction == "left" then moveLeft()
        elseif direction == "right" then moveRight()
        elseif direction == "up" then moveUp()
        elseif direction == "down" then moveDown()
        end
    end,

    -- 长按
    onLongPress = function(self, e)
        showContextMenu(e.x, e.y)
    end,
})
```

---

## 5. 俯视角/双摇杆射击游戏

### 左摇杆移动 + 右摇杆瞄准

```lua
require "urhox-libs.UI.VirtualControls"

function Start()
    -- 左摇杆：移动
    VirtualControls.CreateJoystick({
        id = "move",
        position = Vector2(200, -200),
        alignment = { HA_LEFT, VA_BOTTOM },
    })

    -- 右摇杆：瞄准/射击（释放时自动射击）
    VirtualControls.CreateJoystick({
        id = "aim",
        position = Vector2(-200, -200),
        alignment = { HA_RIGHT, VA_BOTTOM },
        on_move = function(x, y, percent)
            aimDirection = Vector2(x, y):Normalized()
        end,
        on_end = function()
            if aimDirection then shoot(aimDirection) end
        end,
    })

    -- 桌面端：WASD 移动，鼠标瞄准射击
    -- 手柄：左摇杆移动，右摇杆瞄准，RT 射击

    VirtualControls.Initialize()
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 移动（通用读取器）
    local dx, dy = getMovementInput()
    movePlayer(dx, dy, dt)

    -- 瞄准（桌面端：鼠标位置）
    if not PlatformUtils.IsMobilePlatform() then
        local mousePos = input:GetMousePosition()
        local playerScreen = WorldToScreen(playerNode.position)
        aimDirection = Vector2(mousePos.x - playerScreen.x, mousePos.y - playerScreen.y):Normalized()

        -- 鼠标左键射击
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            shoot(aimDirection)
        end
    end
end
```

---

## 6. RTS / 策略 / 编辑器类

### 鼠标/触摸 平移 + 缩放

```lua
-- 相机平移和缩放
local cameraYaw = 0
local cameraZoom = 10  -- 正交 orthoSize 或 distance

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 鼠标滚轮缩放
    local wheel = input.mouseMoveWheel
    if wheel ~= 0 then
        cameraZoom = math.max(3, math.min(30, cameraZoom - wheel * 2))
    end

    -- 鼠标中键/右键拖拽平移
    if input:GetMouseButtonDown(MOUSEB_MIDDLE)
       or input:GetMouseButtonDown(MOUSEB_RIGHT) then
        local move = input:GetMouseMove()
        local panSpeed = cameraZoom * 0.005
        panCamera(-move.x * panSpeed, move.y * panSpeed)
    end

    -- 键盘 WASD 平移
    local panX, panY = 0, 0
    if input:GetKeyDown(KEY_W) then panY = panY + 1 end
    if input:GetKeyDown(KEY_S) then panY = panY - 1 end
    if input:GetKeyDown(KEY_A) then panX = panX - 1 end
    if input:GetKeyDown(KEY_D) then panX = panX + 1 end
    if panX ~= 0 or panY ~= 0 then
        panCamera(panX * dt * cameraZoom, panY * dt * cameraZoom)
    end
end

-- 触摸：双指缩放
SubscribeToEvent("MultiGesture", "HandleMultiGesture")
function HandleMultiGesture(eventType, eventData)
    local dDist = eventData["DDist"]:GetFloat()
    if math.abs(dDist) > 0.001 then
        cameraZoom = math.max(3, math.min(30, cameraZoom - dDist * 50))
    end
end
```

---

## 7. Web 平台 Pointer Lock 处理

### ESC 退出后点击恢复

```lua
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")
local UI = require("urhox-libs/UI")

local pointerLockLost = false
---@type any
local relockUI = nil

function Start()
    if PlatformUtils.IsWebPlatform() then
        -- 监听鼠标模式变化
        SubscribeToEvent("MouseModeChanged", "HandleMouseModeChanged")
    end
end

function HandleMouseModeChanged(eventType, eventData)
    local mode = eventData["Mode"]:GetInt()
    local mouseLocked = eventData["MouseLocked"]:GetBool()

    if not mouseLocked and input.mouseMode == MM_RELATIVE then
        -- 用户按了 ESC，浏览器强制退出 Pointer Lock
        pointerLockLost = true
        showRelockUI()
    end
end

function showRelockUI()
    if relockUI then return end
    relockUI = UI.Panel({
        width = "100%", height = "100%",
        position = "absolute",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "rgba(0,0,0,0.6)",
        children = {
            UI.Panel({
                padding = 30, backgroundColor = "#2c3e50",
                borderRadius = 12, alignItems = "center", gap = 16,
                children = {
                    UI.Label({ text = "Game paused", fontSize = 24, color = "#fff" }),
                    UI.Label({ text = "Click to resume", fontSize = 16, color = "#bdc3c7" }),
                    UI.Button({
                        text = "Resume", variant = "primary",
                        onClick = function()
                            input.mouseMode = MM_RELATIVE
                            pointerLockLost = false
                            hideRelockUI()
                        end,
                    }),
                },
            }),
        },
    })
    UI.SetRoot(relockUI)
end

function hideRelockUI()
    if relockUI then
        relockUI:Destroy()
        relockUI = nil
    end
end
```

---

## 8. 动作按钮适配模式

### 按设备类型显示不同提示

```lua
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")

--- 获取动作按钮的显示文本
---@param action string 动作名
---@return string 显示文本
local function getActionHint(action)
    local isMobile = PlatformUtils.IsMobilePlatform()
    local hints = {
        jump    = isMobile and "Tap ⬆"   or "SPACE",
        attack  = isMobile and "Tap ⚔"   or "F / LMB",
        dodge   = isMobile and "Swipe ↔" or "SHIFT",
        interact= isMobile and "Tap 🔵"  or "E",
        pause   = isMobile and "Tap ⏸"   or "ESC",
    }
    return hints[action] or action
end

-- 在 UI 中使用
UI.Label({ text = "Jump: " .. getActionHint("jump"), fontSize = 14, color = "#aaa" })
```

---

## 9. 触摸最小尺寸规范

根据平台自动调整可交互元素的最小尺寸。

```lua
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")

-- Apple HIG: 44pt, Material Design: 48dp
-- 转换为引擎的基准像素（UI.Scale.DEFAULT 下）
local TOUCH_MIN_SIZE = PlatformUtils.IsMobilePlatform() and 44 or 32

--- 确保按钮满足最小触摸尺寸
---@param requestedSize number 请求的尺寸
---@return number 实际尺寸（不小于最小值）
local function ensureTouchSize(requestedSize)
    return math.max(requestedSize, TOUCH_MIN_SIZE)
end

-- 使用
UI.Button({
    text = "OK",
    width = ensureTouchSize(60),
    height = ensureTouchSize(40),
})
```

---

## 10. 输入方案选择决策表

| 游戏类型 | 推荐方案 | 移动端控件 | 桌面端控件 |
|---------|---------|-----------|-----------|
| 3D 动作/TPS/RPG | GameHUD 或 VirtualControls | 左摇杆+右摇杆+按钮 | WASD+鼠标视角+按键 |
| 2D 平台跳跃 | 手动 UI 按钮 | 左右箭头+跳跃按钮 | A/D+空格 |
| 休闲/益智/卡牌 | UI Pointer 事件 | 触摸点击/拖拽 | 鼠标点击/拖拽 |
| 俯视角射击 | VirtualControls 双摇杆 | 左摇杆移动+右摇杆射击 | WASD+鼠标瞄准 |
| RTS/策略 | 原生 Input API | 触摸平移+双指缩放 | WASD+鼠标滚轮 |
| 音乐/节奏 | UI Pointer + 键盘 | 触摸轨道 | 按键轨道 |

