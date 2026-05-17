---
name: universal-playable-adapter
description: |
  全设备可游玩适配系统。不仅适配 UI 布局，更确保游戏在手机/平板/PC/Web
  上完整可游玩：输入方案自动切换（触控↔键鼠↔手柄）、安全区域自动避让、
  触控按钮与虚拟摇杆自动生成、性能分级渲染、Web 平台特殊处理。
  涵盖从"设备检测"到"操控可用"的完整闭环。
  Use when users need to (1) 让游戏在所有设备上可玩,
  (2) 自动适配触控/键鼠/手柄输入,
  (3) 添加虚拟摇杆和触控按钮,
  (4) 处理刘海屏安全区域,
  (5) 游戏在手机上无法操控/按钮太小/摇杆缺失,
  (6) 游戏在 PC 上没有键盘支持,
  (7) 游戏在 Web 上鼠标锁定异常,
  (8) 用户说"全平台适配""跨端游玩""移动端操控",
  (9) 为 3D 游戏添加手机触控相机控制,
  (10) 让 2D 游戏支持触屏和键盘双模式。
  MUST trigger when: 用户希望游戏能在不同设备上正常操控和游玩。
  trigger-keywords:
    - 全平台
    - 跨端
    - 可游玩
    - 触控适配
    - 手柄适配
    - 虚拟摇杆
    - 安全区域
    - 刘海屏
    - 移动端操控
    - 键鼠适配
    - 输入适配
    - playable
    - cross-platform
    - touch controls
    - gamepad
    - universal
    - 操控
    - 手机上玩
    - PC上玩
  file types: .lua
version: "1.0.0"
metadata:
  author: "UrhoX-Skill-Creator"
  tags: ["adaptation", "input", "cross-platform", "touch", "gamepad", "safe-area", "responsive", "playable"]
---

# 全设备可游玩适配系统

## 角色定义

你是一位 **UrhoX 全平台游戏适配专家**。你的职责不仅是让 UI 在各设备上"看起来好"，
更是让游戏在手机、平板、PC、Web 上"玩起来顺"——操控流畅、按钮够大、摇杆到位、安全区正确、性能达标。

---

## 本 Skill 与 responsive-ui-adapter 的关系

| 维度 | responsive-ui-adapter | 本 Skill（universal-playable-adapter） |
|------|----------------------|---------------------------------------|
| 聚焦 | UI 布局自适应 | 游戏**可游玩性**自适应 |
| 覆盖 | 断点检测 + 布局切换 | 输入 + 操控 + 安全区 + 性能 + UI |
| 适用 | UI 密集型应用 | 任何需要跨端可玩的**游戏** |
| 关系 | 可作为本 Skill 的子模块 | 包含并扩展 responsive-ui-adapter |

---

## 核心架构：五层适配模型

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 5: 游戏逻辑适配                                        │
│  难度/速度/相机距离 根据设备微调                                 │
├──────────────────────────────────────────────────────────────┤
│  Layer 4: UI 布局适配                                         │
│  响应式断点 + Flexbox 自适应 + 组件缩放                         │
├──────────────────────────────────────────────────────────────┤
│  Layer 3: 安全区域适配                                         │
│  刘海/挖孔/圆角/Home 指示条 自动避让                            │
├──────────────────────────────────────────────────────────────┤
│  Layer 2: 输入操控适配                                         │
│  触控/键鼠/手柄 自动检测 + 虚拟摇杆 + 触控相机                  │
├──────────────────────────────────────────────────────────────┤
│  Layer 1: 设备检测 + 分辨率适配                                │
│  平台识别 + DPR + 物理/逻辑分辨率 + 方向                        │
└──────────────────────────────────────────────────────────────┘
```

---

## Layer 1: 设备检测 + 分辨率适配

### 1.1 完整设备信息检测

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

--- 获取完整的设备适配信息
---@return table deviceInfo
local function getDeviceInfo()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    local logW = physW / dpr
    local logH = physH / dpr
    local isLandscape = physW > physH
    local shortSide = math.min(logW, logH)
    local longSide = math.max(logW, logH)
    local aspect = longSide / shortSide

    -- 设备分类（基于逻辑短边）
    local deviceType
    if shortSide < 500 then
        deviceType = "phone"
    elseif shortSide < 900 then
        deviceType = "tablet"
    else
        deviceType = "desktop"
    end

    -- 平台检测
    local platform = PlatformUtils.GetPlatform()
    local isMobile = PlatformUtils.IsMobilePlatform()
    local isWeb = PlatformUtils.IsWebPlatform()
    local isDesktop = PlatformUtils.IsDesktopPlatform()
    local isTouchDevice = PlatformUtils.IsTouchSupported()

    return {
        -- 分辨率
        physWidth = physW,
        physHeight = physH,
        logWidth = logW,
        logHeight = logH,
        dpr = dpr,
        isLandscape = isLandscape,
        aspect = aspect,

        -- 设备
        deviceType = deviceType,   -- "phone" | "tablet" | "desktop"
        platform = platform,       -- "Windows"|"Linux"|"Mac"|"Android"|"iOS"|"Web"
        isMobile = isMobile,
        isDesktop = isDesktop,
        isWeb = isWeb,
        isTouchDevice = isTouchDevice,

        -- 输入能力
        hasTouch = isTouchDevice,
        hasKeyboard = isDesktop or isWeb,
        hasMouse = isDesktop or isWeb,
        hasGamepad = input:GetNumJoysticks() > 0,

        -- 适配参数预设
        touchMinSize = isMobile and 44 or 32,        -- 最小触控目标 (dp)
        fontSize = ({ phone = 14, tablet = 15, desktop = 16 })[deviceType],
        padding = ({ phone = 8, tablet = 12, desktop = 16 })[deviceType],
    }
end
```

### 1.2 分辨率初始化

```lua
local UI = require("urhox-libs/UI")

-- 推荐：使用默认缩放（DPR 密度自适应）
UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
    scale = UI.Scale.DEFAULT,
})
```

**何时用 DESIGN_RESOLUTION**：
- 像素风游戏（固定 320×180 等低分辨率）
- 明确要求 1920×1080 设计稿的项目
- NanoVG 纯 2D 游戏已有固定坐标体系

**何时用 DEFAULT（推荐）**：
- 大多数游戏
- 需要在各设备上自然缩放

### 1.3 屏幕方向变化监听

```lua
local lastW, lastH = graphics:GetWidth(), graphics:GetHeight()

function HandleUpdate(eventType, eventData)
    local w, h = graphics:GetWidth(), graphics:GetHeight()
    if w ~= lastW or h ~= lastH then
        lastW, lastH = w, h
        -- 屏幕尺寸变化（旋转/窗口缩放）
        onScreenChanged(w, h)
    end
end

function onScreenChanged(w, h)
    local info = getDeviceInfo()  -- 重新检测
    -- 更新布局、输入、安全区...
end
```

---

## Layer 2: 输入操控适配（核心）

### 2.1 输入方案自动选择策略

```
┌──────────────────────────────────────────────────────┐
│              输入方案决策树                             │
│                                                       │
│  检测平台                                              │
│  ├─ 手机/平板 ──→ 触控模式                             │
│  │   ├─ 2D 游戏 → 虚拟方向键 + 动作按钮               │
│  │   ├─ 3D 游戏 → 虚拟摇杆 + 触控相机 + 动作按钮      │
│  │   └─ 休闲游戏 → 直接触控（点击/滑动）              │
│  │                                                    │
│  ├─ PC (桌面) ──→ 键鼠模式                             │
│  │   ├─ 移动: WASD                                    │
│  │   ├─ 视角: 鼠标 (MM_RELATIVE)                      │
│  │   ├─ 动作: 空格/Shift/鼠标键                       │
│  │   └─ 触屏 PC → 动态启用触控                        │
│  │                                                    │
│  └─ Web ──→ 键鼠模式 + Pointer Lock 特殊处理          │
│      ├─ 默认同 PC 键鼠                                │
│      ├─ Pointer Lock ESC 退出提示                     │
│      └─ 移动端浏览器 → 触控模式                        │
└──────────────────────────────────────────────────────┘
```

### 2.2 方案 A：使用 GameHUD（推荐，3D 角色游戏）

**GameHUD 是最高层的跨平台操控抽象**，自动处理触控/键鼠差异：

```lua
local GameHUD = require "urhox-libs.UI.GameHUD"

local function setupGameControls(deviceInfo)
    GameHUD.Create({
        -- 移动摇杆（手机=虚拟摇杆，PC=显示WASD提示）
        enableJoystick = true,

        -- 动作按钮（手机=屏幕按钮，PC=键盘映射）
        enableJump = true,          -- 空格 / 触控按钮
        enableRun = true,           -- Shift / 触控按钮
        enableCrouch = false,       -- 按需启用

        -- 射击类游戏
        enableShooter = false,      -- 按需启用（Arm/Shoot/Reload）

        -- 触控相机（仅手机生效）
        enableTouchLook = deviceInfo.isMobile,

        -- PC 按键提示
        showKeyHints = deviceInfo.hasKeyboard,

        -- 统一回调（无需关心输入来源）
        onJoystickInput = function(dx, dy)
            -- dx, dy 范围 [-1, 1]，直接用于角色移动
            moveCharacter(dx, dy)
        end,
        onJump = function()
            characterJump()
        end,
        onRun = function(isRunning)
            setRunning(isRunning)
        end,
    })

    -- 手机端：启用触控相机控制
    if deviceInfo.isMobile then
        GameHUD.EnableTouchLook(camera, 0.3)  -- sensitivity
    end

    -- PC/Web：设置鼠标模式
    if deviceInfo.hasMouse and not deviceInfo.isMobile then
        input.mouseMode = MM_RELATIVE
    end
end
```

### 2.3 方案 B：手动构建跨平台输入（2D 游戏 / 自定义需求）

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local InputManager = require "urhox-libs.Platform.InputManager"

local function setupInputForPlatform(deviceInfo)
    if deviceInfo.isMobile then
        -- 手机/平板：启用虚拟摇杆
        InputManager.Initialize({
            touchSensitivity = 1.0,
        })
    end
    -- PC 上如果检测到触屏也会自动启用（InputManager 内置逻辑）
end

--- 统一的移动输入读取（每帧调用）
---@return number dx 水平输入 [-1, 1]
---@return number dy 垂直输入 [-1, 1]
local function getMovementInput()
    local dx, dy = 0, 0

    -- 键盘输入（PC/Web）
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then dy = dy - 1 end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then dy = dy + 1 end
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then dx = dx - 1 end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then dx = dx + 1 end

    -- 虚拟摇杆输入（手机/触屏PC）
    if input:GetNumJoysticks() > 0 then
        local js = input:GetJoystick(0)
        if js then
            local jx = js:GetAxisPosition(0)  -- 左右
            local jy = js:GetAxisPosition(1)  -- 上下
            -- 应用死区
            if math.abs(jx) > 0.15 then dx = dx + jx end
            if math.abs(jy) > 0.15 then dy = dy + jy end
        end
    end

    -- 归一化
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1 then
        dx, dy = dx / len, dy / len
    end

    return dx, dy
end

--- 统一的动作输入读取
---@return boolean jump 是否按下跳跃
---@return boolean action 是否按下动作键
local function getActionInput()
    local jump = input:GetKeyPress(KEY_SPACE)
    local action = input:GetKeyPress(KEY_E)
        or input:GetMouseButtonPress(MOUSEB_LEFT)

    -- 虚拟按钮也映射到 joystick 按钮
    if input:GetNumJoysticks() > 0 then
        local js = input:GetJoystick(0)
        if js then
            if js:GetButtonPress(0) then jump = true end
            if js:GetButtonPress(1) then action = true end
        end
    end

    return jump, action
end
```

### 2.4 方案 C：纯触控游戏（休闲/点击类）

```lua
--- 休闲游戏触控适配
--- 同时支持鼠标和触控，无需虚拟摇杆
local function setupCasualInput()
    -- 点击/触控 → 统一回调
    SubscribeToEvent("MouseButtonDown", function(eventType, eventData)
        local x = eventData["X"]:GetInt()
        local y = eventData["Y"]:GetInt()
        local button = eventData["Button"]:GetInt()
        if button == MOUSEB_LEFT then
            onTap(x, y)
        end
    end)

    SubscribeToEvent("TouchBegin", function(eventType, eventData)
        local x = eventData["X"]:GetInt()
        local y = eventData["Y"]:GetInt()
        onTap(x, y)
    end)
end

--- 或使用 UI 组件的统一手势（推荐）
local gameArea = UI.Panel {
    width = "100%", height = "100%",
    onTap = function(self, e)
        onTap(e.x, e.y)
    end,
    onSwipeLeft = function(self, e) onSwipe("left") end,
    onSwipeRight = function(self, e) onSwipe("right") end,
    onSwipeUp = function(self, e) onSwipe("up") end,
    onSwipeDown = function(self, e) onSwipe("down") end,
    onPinchMove = function(self, e)
        onZoom(e.scale, e.centerX, e.centerY)
    end,
}
```

### 2.5 Web 平台 Pointer Lock 特殊处理

```lua
local function setupWebMouseMode(deviceInfo)
    if not deviceInfo.isWeb then return end

    -- Web 平台 MM_RELATIVE 使用浏览器 Pointer Lock API
    -- ESC 会强制退出锁定（浏览器行为，无法覆盖）
    -- 退出后需要用户再次点击才能重新锁定

    input.mouseMode = MM_RELATIVE

    -- 提示 UI：当鼠标解锁时显示
    -- （通过检测 mouseMode 或检测 ESC 事件来判断）
    SubscribeToEvent("KeyDown", function(eventType, eventData)
        local key = eventData["Key"]:GetInt()
        if key == KEY_ESCAPE then
            -- Web 上 ESC 会退出 Pointer Lock
            -- 显示"点击屏幕继续游戏"提示
            showPointerLockPrompt()
        end
    end)
end

local function showPointerLockPrompt()
    -- 显示一个提示面板
    local prompt = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "rgba(0,0,0,0.6)",
        children = {
            UI.Label {
                text = "点击屏幕继续游戏",
                fontSize = 24, color = "#ffffff",
            },
        },
        onTap = function(self, e)
            input.mouseMode = MM_RELATIVE  -- 重新锁定
            self:Remove()                   -- 移除提示
        end,
    }
    UI.GetRoot():AddChild(prompt)
end
```

### 2.6 手柄（Gamepad）支持

```lua
local function setupGamepadInput()
    -- 检测手柄连接
    SubscribeToEvent("JoystickConnected", function(eventType, eventData)
        local id = eventData["JoystickID"]:GetInt()
        log:Write(LOG_INFO, "Gamepad connected: " .. id)
        -- 可选：切换到手柄 UI 提示
    end)

    SubscribeToEvent("JoystickDisconnected", function(eventType, eventData)
        -- 切换回键鼠/触控 UI 提示
    end)
end

--- 统一手柄输入读取（在 getMovementInput 中集成）
local function readGamepad()
    local numJoysticks = input:GetNumJoysticks()
    for i = 0, numJoysticks - 1 do
        local js = input:GetJoystick(i)
        if js and js.controller then
            -- 标准手柄布局
            local lx = js:GetAxisPosition(0)   -- 左摇杆 X
            local ly = js:GetAxisPosition(1)   -- 左摇杆 Y
            local rx = js:GetAxisPosition(2)   -- 右摇杆 X
            local ry = js:GetAxisPosition(3)   -- 右摇杆 Y
            local a = js:GetButtonPress(0)     -- A 按钮
            local b = js:GetButtonPress(1)     -- B 按钮
            return lx, ly, rx, ry, a, b
        end
    end
    return 0, 0, 0, 0, false, false
end
```

---

## Layer 3: 安全区域适配

### 3.1 使用 SafeAreaView（推荐）

```lua
local UI = require("urhox-libs/UI")

-- 整个游戏 UI 包裹在 SafeAreaView 中
local root = UI.SafeAreaView {
    edges = "all",          -- 所有边都避让
    mode = "padding",       -- 内边距模式
    width = "100%",
    height = "100%",
    children = {
        -- 游戏 HUD、菜单等
        createGameUI(),
    },
}
UI.SetRoot(root)
```

### 3.2 选择性安全区避让

```lua
-- 只避让顶部和底部（适合横屏游戏）
UI.SafeAreaView {
    edges = { "top", "bottom" },
    -- ...
}

-- 只避让左右（适合竖屏，刘海在侧面）
UI.SafeAreaView {
    edges = "horizontal",
    -- ...
}
```

### 3.3 手动获取安全区距离

```lua
--- 获取安全区内边距（单位：逻辑像素）
local function getSafeInsets()
    local rect = GetSafeAreaInsets(false)
    local dpr = graphics:GetDPR()
    return {
        top = rect.min.y / dpr,
        bottom = rect.max.y / dpr,
        left = rect.min.x / dpr,
        right = rect.max.x / dpr,
    }
end
```

### 3.4 安全区对 NanoVG 游戏的影响

如果使用 NanoVG 渲染 UI（非 UI 组件），需要手动处理：

```lua
function HandleNanoVGRender(eventType, eventData)
    local insets = getSafeInsets()

    nvgBeginFrame(vg, width, height, 1.0)

    -- 在安全区内绘制 HUD
    local safeX = insets.left
    local safeY = insets.top
    local safeW = width / dpr - insets.left - insets.right
    local safeH = height / dpr - insets.top - insets.bottom

    -- 分数显示在安全区内的左上角
    nvgFontSize(vg, 24)
    nvgText(vg, safeX + 10, safeY + 30, "Score: " .. score)

    nvgEndFrame(vg)
end
```

---

## Layer 4: UI 布局适配

### 4.1 响应式断点

```lua
--- 获取当前断点对应的布局参数
local function getLayoutConfig()
    local info = getDeviceInfo()
    local cfg = {}

    if info.deviceType == "phone" then
        cfg.columns = 1
        cfg.sidebarWidth = 0
        cfg.showSidebar = false
        cfg.padding = 8
        cfg.gap = 8
        cfg.fontSize = 13
        cfg.titleSize = 20
        cfg.buttonHeight = 44       -- 触控友好
        cfg.iconSize = 24
    elseif info.deviceType == "tablet" then
        cfg.columns = 2
        cfg.sidebarWidth = 200
        cfg.showSidebar = true
        cfg.padding = 12
        cfg.gap = 12
        cfg.fontSize = 15
        cfg.titleSize = 24
        cfg.buttonHeight = 40
        cfg.iconSize = 28
    else -- desktop
        cfg.columns = 3
        cfg.sidebarWidth = 260
        cfg.showSidebar = true
        cfg.padding = 16
        cfg.gap = 16
        cfg.fontSize = 16
        cfg.titleSize = 28
        cfg.buttonHeight = 36
        cfg.iconSize = 32
    end

    return cfg
end
```

### 4.2 触控友好的按钮尺寸

| 设备 | 最小触控目标 | 推荐按钮高度 | 按钮间距 |
|------|------------|------------|---------|
| 手机 | 44×44 dp | 48 dp | 8 dp |
| 平板 | 40×40 dp | 44 dp | 10 dp |
| PC | 32×32 dp | 36 dp | 8 dp |

```lua
-- 创建自适应按钮
local function createAdaptiveButton(text, onClick)
    local info = getDeviceInfo()
    local minH = info.isMobile and 48 or 36
    return UI.Button {
        text = text,
        minHeight = minH,
        paddingHorizontal = info.isMobile and 20 or 12,
        fontSize = info.fontSize,
        variant = "primary",
        onClick = onClick,
    }
end
```

### 4.3 自适应网格布局

```lua
-- SimpleGrid 自动计算列数
UI.SimpleGrid {
    minColumnWidth = 150,   -- 最小列宽，自动算列数
    gap = info.padding,
    children = items,
}
```

---

## Layer 5: 游戏逻辑适配

### 5.1 难度/速度微调

```lua
local function getGameplayConfig(deviceInfo)
    local cfg = {}

    if deviceInfo.deviceType == "phone" then
        -- 手机：稍微降低难度/速度，补偿触控精度
        cfg.moveSpeed = 4.5         -- 略慢
        cfg.aimAssist = true        -- 瞄准辅助
        cfg.hitboxScale = 1.2       -- 判定范围放大 20%
        cfg.spawnRate = 0.8         -- 敌人生成速度降低
    elseif deviceInfo.deviceType == "tablet" then
        cfg.moveSpeed = 5.0
        cfg.aimAssist = true
        cfg.hitboxScale = 1.1
        cfg.spawnRate = 0.9
    else
        cfg.moveSpeed = 5.0
        cfg.aimAssist = false
        cfg.hitboxScale = 1.0
        cfg.spawnRate = 1.0
    end

    return cfg
end
```

### 5.2 相机距离适配

```lua
local function getCameraConfig(deviceInfo)
    if deviceInfo.deviceType == "phone" then
        return {
            distance = 7.0,       -- 手机拉远相机，看到更多
            fov = 50,
            sensitivity = 0.25,   -- 触控灵敏度降低
        }
    elseif deviceInfo.deviceType == "tablet" then
        return {
            distance = 6.0,
            fov = 48,
            sensitivity = 0.3,
        }
    else
        return {
            distance = 5.0,
            fov = 45,
            sensitivity = 0.5,    -- 鼠标灵敏度
        }
    end
end
```

### 5.3 2D 游戏正交视野适配

```lua
local function setupOrthoCamera(deviceInfo)
    local camera = cameraNode:GetComponent("Camera")
    camera.orthographic = true

    -- 固定高度，宽度自适应
    local baseOrthoSize = 10.0  -- 设计基准
    if deviceInfo.deviceType == "phone" then
        -- 手机横屏很窄，稍微缩小 orthoSize 让画面更紧凑
        camera.orthoSize = baseOrthoSize * 0.85
    else
        camera.orthoSize = baseOrthoSize
    end
end
```

---

## 完整适配模板

### 模板 A：3D 角色游戏全平台适配

```lua
require "LuaScripts/Utilities/Sample"
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local UI = require("urhox-libs/UI")
local GameHUD = require "urhox-libs.UI.GameHUD"
require "urhox-libs.Camera.ThirdPersonCamera"

-- 设备检测
local deviceInfo  -- 初始化时填充

function Start()
    -- 1. 设备检测
    deviceInfo = getDeviceInfo()
    log:Write(LOG_INFO, string.format(
        "Device: %s (%s) %dx%d @%.1fx",
        deviceInfo.deviceType, deviceInfo.platform,
        deviceInfo.physWidth, deviceInfo.physHeight, deviceInfo.dpr
    ))

    -- 2. 分辨率初始化
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 3. 场景创建
    createScene()
    createCharacter()

    -- 4. 相机适配
    local camCfg = getCameraConfig(deviceInfo)
    local tpCamera = ThirdPersonCamera.Create(scene_, {
        modes = {
            normal = {
                distance = camCfg.distance,
                offset = Vector3(0, 1.7, 0),
                fov = camCfg.fov,
            },
        },
    })
    renderer:SetViewport(0, Viewport:new(scene_, tpCamera:GetCamera()))

    -- 5. 输入适配（GameHUD 自动处理跨平台）
    GameHUD.Create({
        enableJoystick = true,
        enableJump = true,
        enableTouchLook = deviceInfo.isMobile,
        showKeyHints = deviceInfo.hasKeyboard,
        onJoystickInput = function(dx, dy)
            moveCharacter(dx, dy)
        end,
        onJump = function()
            characterJump()
        end,
    })

    if deviceInfo.isMobile then
        GameHUD.EnableTouchLook(tpCamera:GetCamera(), camCfg.sensitivity)
    else
        input.mouseMode = MM_RELATIVE
    end

    -- 6. Web 特殊处理
    if deviceInfo.isWeb then
        setupWebMouseMode(deviceInfo)
    end

    -- 7. 安全区 UI
    local root = UI.SafeAreaView {
        edges = "all",
        width = "100%", height = "100%",
        children = {
            createHUD(deviceInfo),
        },
    }
    UI.SetRoot(root)

    -- 8. 游戏逻辑适配
    local gameCfg = getGameplayConfig(deviceInfo)
    applyGameplayConfig(gameCfg)
end
```

### 模板 B：2D 休闲游戏全平台适配

```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local InputManager = require "urhox-libs.Platform.InputManager"
local UI = require("urhox-libs/UI")

local deviceInfo

function Start()
    -- 1. 设备检测
    deviceInfo = getDeviceInfo()

    -- 2. UI 初始化
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 3. 输入初始化
    if deviceInfo.isMobile then
        InputManager.Initialize()
    end

    -- 4. 场景创建
    createScene()

    -- 5. 统一输入处理
    SubscribeToEvent("Update", "HandleUpdate")

    -- 6. 安全区 UI
    local root = UI.SafeAreaView {
        edges = "all",
        width = "100%", height = "100%",
        children = {
            createGameUI(deviceInfo),
        },
    }
    UI.SetRoot(root)
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 统一输入读取
    local dx, dy = getMovementInput()
    local jump, action = getActionInput()

    updateGame(dt, dx, dy, jump, action)
end
```

---

## 适配检查清单

### 阶段 1：基础适配（必做）
- [ ] 使用 `getDeviceInfo()` 检测设备
- [ ] 使用 `UI.Scale.DEFAULT` 初始化 UI
- [ ] 使用 `SafeAreaView` 包裹所有 UI
- [ ] 键盘 + 触控/摇杆 双路输入
- [ ] 触控按钮 ≥ 44dp（手机）
- [ ] 调用 build 验证

### 阶段 2：输入优化（推荐）
- [ ] 3D 游戏使用 `GameHUD` 统一操控
- [ ] 2D 游戏使用 `InputManager` + `getMovementInput()`
- [ ] 休闲游戏使用 UI 手势（`onTap`/`onSwipe`）
- [ ] Web 平台处理 Pointer Lock ESC
- [ ] 手柄支持（如需要）

### 阶段 3：体验打磨（可选）
- [ ] 手机端降低难度/放大判定
- [ ] 手机端拉远相机
- [ ] 根据设备调整字体/间距/列数
- [ ] 屏幕旋转响应布局更新
- [ ] 弱网/低性能设备降级

---

## 问题诊断速查

| 症状 | 原因 | 解决方案 |
|------|------|---------|
| 手机上没有摇杆 | 未初始化 InputManager | `InputManager.Initialize()` |
| 手机上按钮太小 | 未设置最小触控尺寸 | `minHeight = 44` |
| PC 上鼠标不隐藏 | 未设置鼠标模式 | `input.mouseMode = MM_RELATIVE` |
| Web 上 ESC 后无法操作 | Pointer Lock 退出 | 显示"点击继续"提示 |
| 刘海遮挡 UI | 未使用 SafeAreaView | 包裹 `UI.SafeAreaView { edges = "all" }` |
| 平板上布局太空 | 未做响应式断点 | 用 `getLayoutConfig()` 适配 |
| 触屏 PC 没有触控 | 未启用动态检测 | `InputManager.Initialize()` 自带 |
| 游戏在手机太难 | 触控精度低 | `getGameplayConfig()` 降低难度 |
| 键盘和摇杆冲突 | 输入叠加 | `getMovementInput()` 已处理归一化 |
| UI 和游戏点击穿透 | 未检查 UI 遮挡 | `UI.IsPointerOverUI()` 判断 |

---

## 参考文档

- `references/input-patterns.md` — 各游戏类型输入方案详细代码
- `references/device-matrix.md` — 设备分辨率矩阵与测试要点
- `engine-docs/api/input.md` — 引擎输入 API 完整参考
- `engine-docs/recipes/ui.md` — UI 系统使用指南
- `.claude/skills/responsive-ui-adapter/SKILL.md` — UI 布局响应式适配（子集）
