---
name: runtime-visual-stylizer
description: |
  运行时视觉风格化系统。基于 UrhoX 引擎的 ColorGrading、RenderPath、Image 像素操作和 NanoVG 叠加
  四大核心能力，为游戏提供实时画面风格化效果（电影色调、复古风、赛博朋克、水彩风等）。
  灵感源自 Neural Style Transfer 的"内容+风格=合成"理念，将其映射为引擎原生的运行时渲染管线操作。

  与 art-style-transfer Skill 的区别：
  - art-style-transfer：离线 AI 素材风格迁移（edit_image/generate_image MCP 工具）
  - runtime-visual-stylizer：运行时实时画面风格化（引擎原生渲染管线）

  trigger-keywords:
    - 运行时风格化
    - 实时风格
    - 画面风格
    - 色调
    - 色彩校正
    - color grading
    - 调色
    - 滤镜
    - 后处理
    - post-processing
    - 电影色调
    - 复古风
    - 赛博朋克
    - 水彩风
    - 黑白
    - 怀旧
    - LUT
    - 暗角
    - 扫描线
    - 画面效果
    - visual style
    - cinematic
    - retro
    - noir
    - sepia
    - 色温
    - 曝光
    - 饱和度
    - 对比度
    - 日夜循环视觉
    - 场景氛围
version: 1.0.0
license: MIT
compatibility: UrhoX Lua (全平台)
metadata:
  category: rendering
  priority: medium
  requires_mcp: false
  engine_components:
    - ColorGrading
    - RenderPath
    - Image
    - NanoVG (可选)
---

# Runtime Visual Stylizer — 运行时视觉风格化系统

## 设计理念

Neural Style Transfer 的核心思想是 **内容 + 风格 = 合成图像**。
本 Skill 将这一理念映射到 UrhoX 引擎的运行时渲染管线：

| Neural Style Transfer | UrhoX 运行时映射 |
|----------------------|-----------------|
| 内容图像 (Content) | 引擎实时渲染的 3D/2D 场景 |
| 风格图像 (Style) | ColorGrading 预设 / RenderPath 参数 / 叠加效果 |
| 风格迁移算法 | 引擎原生后处理管线 |
| 合成输出 | 玩家看到的最终画面 |

**与 `art-style-transfer` Skill 的分工**：

| 维度 | art-style-transfer | runtime-visual-stylizer |
|------|-------------------|------------------------|
| 时机 | 开发期（离线） | 运行时（实时） |
| 对象 | 静态素材文件 | 渲染画面 |
| 工具 | MCP generate_image/edit_image | ColorGrading / RenderPath / NanoVG |
| 输出 | 风格化后的 PNG/JPG 文件 | 实时画面效果 |
| 性能 | 无运行时开销 | 每帧处理，需关注性能 |

---

## 四大核心能力

### 能力 1: ColorGrading 组件（推荐，最强大）

**适用场景**：电影色调、色彩校正、LUT 调色、日夜循环、场景氛围切换

ColorGrading 是 UrhoX 引擎内置的专业调色组件，提供 40+ 可调参数，
支持 LUT 查找表、动画过渡、预设保存/加载。

**核心 API**：

```lua
-- 获取 ColorGrading 组件（挂载在相机节点或 Viewport 上）
local cameraNode = scene_:GetChild("Camera")
local colorGrading = cameraNode:GetOrCreateComponent("ColorGrading")

-- === 全局参数 ===
colorGrading.exposure = 1.0           -- 曝光 (默认 1.0)
colorGrading.temperature = 0.0        -- 色温 (-1.0 冷蓝 ~ +1.0 暖黄, 默认 0)
colorGrading.tint = 0.0               -- 色调偏移 (-1.0 绿 ~ +1.0 品红, 默认 0)
colorGrading.globalSaturation = 1.0   -- 全局饱和度 (0=灰度, 1=正常, >1=过饱和)
colorGrading.globalContrast = 1.0     -- 全局对比度
colorGrading.globalGamma = 1.0        -- 全局伽马
colorGrading.globalGain = 1.0         -- 全局增益（整体亮度乘数）
colorGrading.globalOffset = 0.0       -- 全局偏移（整体亮度加数）

-- === 分区调色（阴影/中间调/高光）===
-- 每个区域支持: saturation, contrast, gamma, gain, offset, tint, tintIntensity
colorGrading.shadowsSaturation = 1.0
colorGrading.shadowsContrast = 1.0
colorGrading.shadowsGamma = 1.0
colorGrading.shadowsGain = 1.0
colorGrading.shadowsOffset = 0.0
colorGrading.shadowsTint = Color(0.5, 0.5, 1.0)  -- 阴影偏蓝色调
colorGrading.shadowsTintIntensity = 0.0           -- 色调强度 (0=关闭)

colorGrading.midtonesSaturation = 1.0
colorGrading.midtonesContrast = 1.0
-- ... (同上)

colorGrading.highlightsSaturation = 1.0
colorGrading.highlightsContrast = 1.0
-- ... (同上)

-- 区域边界
colorGrading.shadowsMax = 0.09        -- 阴影区上限
colorGrading.highlightsMin = 0.5      -- 高光区下限

-- === LUT 查找表 ===
colorGrading:SetLUT(lut)              -- 设置主 LUT
colorGrading.lutIntensity = 1.0       -- LUT 强度 (0=不生效, 1=完全)
colorGrading:SetSecondaryLUT(lut2)    -- 设置第二 LUT（用于混合）
colorGrading.lutBlendFactor = 0.0     -- 两个 LUT 的混合因子

-- === 动画过渡 ===
colorGrading:BlendToLUT(targetLUT, duration)  -- 平滑过渡到目标 LUT

-- === 预设管理 ===
colorGrading:SavePreset("Presets/MyStyle.json")   -- 保存当前参数为预设
colorGrading:LoadPreset("Presets/MyStyle.json")   -- 加载预设
colorGrading:ResetToDefaults()                     -- 重置为默认值

-- === 开关 ===
colorGrading.colorGradingEnabled = true  -- 启用/禁用
```

### 能力 2: RenderPath 后处理管线

**适用场景**：启用/禁用后处理效果、调整后处理参数

```lua
-- 获取当前 RenderPath
local viewport = renderer:GetViewport(0)
local renderPath = viewport:GetRenderPath()

-- 启用/禁用后处理效果（通过 tag）
renderPath:SetEnabled("Bloom", true)
renderPath:SetEnabled("FXAA", true)
renderPath:SetEnabled("AutoExposure", false)

-- 查询状态
local isBloom = renderPath:IsEnabled("Bloom")

-- 设置着色器参数
renderPath:SetShaderParameter("BloomThreshold", Variant(0.8))

-- 切换后处理效果
renderPath:ToggleEnabled("Bloom")

-- HDR 渲染
renderer:SetHDRRendering(true)

-- 克隆 RenderPath（不影响原始设置）
local customPath = renderPath:Clone()
customPath:SetEnabled("Bloom", true)
viewport:SetRenderPath(customPath)
```

### 能力 3: Image 像素操作（CPU 端，非实时）

**适用场景**：一次性图像处理、截图滤镜、贴图预处理

```lua
-- 截取当前画面
local screenshot = Image()
graphics:TakeScreenShot(screenshot)

-- 像素级操作
local w, h = screenshot.width, screenshot.height
for y = 0, h - 1 do
    for x = 0, w - 1 do
        local pixel = screenshot:GetPixel(x, y)
        -- 处理像素...
        screenshot:SetPixel(x, y, newColor)
    end
end

-- 保存结果
screenshot:SavePNG("Screenshots/stylized.png")

-- 缩放
screenshot:Resize(512, 512)

-- 翻转
screenshot:FlipHorizontal()
screenshot:FlipVertical()
```

> **性能警告**：Image 像素操作在 CPU 端执行，逐像素遍历大图（如 1920×1080）
> 会消耗大量时间。仅适合一次性处理（如截图保存），不适合每帧执行。

### 能力 4: NanoVG 叠加效果（仅限 NanoVG 项目）

**适用场景**：暗角、扫描线、颜色叠加等屏幕空间效果

> **重要**：NanoVG 叠加仅适用于已使用 NanoVG 渲染管线的项目。
> 对于纯 3D 或 UI 组件项目，请使用 ColorGrading + RenderPath。

```lua
-- 暗角效果
function DrawVignette(vg, w, h, intensity)
    intensity = intensity or 0.6
    local cx, cy = w * 0.5, h * 0.5
    local radius = math.max(w, h) * 0.7
    local innerRadius = radius * 0.5

    local paint = nvgRadialGradient(vg,
        cx, cy, innerRadius, radius,
        nvgRGBA(0, 0, 0, 0),
        nvgRGBA(0, 0, 0, math.floor(255 * intensity))
    )
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end

-- 扫描线效果
function DrawScanlines(vg, w, h, spacing, alpha)
    spacing = spacing or 4
    alpha = alpha or 30
    nvgBeginPath(vg)
    for y = 0, h, spacing do
        nvgRect(vg, 0, y, w, 1)
    end
    nvgFillColor(vg, nvgRGBA(0, 0, 0, alpha))
    nvgFill(vg)
end

-- 颜色叠加
function DrawColorOverlay(vg, w, h, r, g, b, a)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(r, g, b, a))
    nvgFill(vg)
end
```

---

## 内置风格预设

以下 15 个预设覆盖常见的视觉风格需求，全部基于 ColorGrading 参数：

```lua
local STYLE_PRESETS = {
    -- ====== 电影色调 ======
    cinematic_warm = {
        name = "暖色电影",
        exposure = 1.05,
        temperature = 0.15,
        tint = 0.02,
        globalSaturation = 0.9,
        globalContrast = 1.15,
        globalGamma = 0.95,
        shadowsTint = Color(0.4, 0.35, 0.5),
        shadowsTintIntensity = 0.15,
        highlightsTint = Color(1.0, 0.9, 0.7),
        highlightsTintIntensity = 0.1,
    },

    cinematic_cool = {
        name = "冷色电影",
        exposure = 0.95,
        temperature = -0.12,
        tint = -0.03,
        globalSaturation = 0.85,
        globalContrast = 1.2,
        globalGamma = 0.98,
        shadowsTint = Color(0.3, 0.4, 0.6),
        shadowsTintIntensity = 0.2,
        highlightsTint = Color(0.8, 0.85, 1.0),
        highlightsTintIntensity = 0.08,
    },

    -- ====== 复古 / 怀旧 ======
    retro_70s = {
        name = "70年代复古",
        exposure = 1.1,
        temperature = 0.2,
        tint = 0.05,
        globalSaturation = 0.75,
        globalContrast = 0.9,
        globalGamma = 1.1,
        globalOffset = 0.02,
        shadowsTint = Color(0.6, 0.4, 0.3),
        shadowsTintIntensity = 0.25,
        highlightsTint = Color(1.0, 0.95, 0.8),
        highlightsTintIntensity = 0.15,
    },

    sepia = {
        name = "怀旧棕褐",
        exposure = 1.0,
        temperature = 0.25,
        tint = 0.05,
        globalSaturation = 0.3,
        globalContrast = 1.05,
        globalGamma = 1.05,
        shadowsTint = Color(0.55, 0.4, 0.25),
        shadowsTintIntensity = 0.3,
        midtonesTint = Color(0.6, 0.5, 0.35),
        midtonesTintIntensity = 0.15,
    },

    faded_memory = {
        name = "褪色记忆",
        exposure = 1.15,
        temperature = 0.1,
        tint = 0.0,
        globalSaturation = 0.5,
        globalContrast = 0.85,
        globalGamma = 1.15,
        globalOffset = 0.05,
        shadowsGain = 1.2,
        highlightsGain = 0.9,
    },

    -- ====== 黑白 / 单色 ======
    noir = {
        name = "黑色电影",
        exposure = 0.9,
        temperature = 0.0,
        tint = 0.0,
        globalSaturation = 0.0,
        globalContrast = 1.4,
        globalGamma = 0.85,
        shadowsGain = 0.8,
        highlightsGain = 1.2,
    },

    monochrome_blue = {
        name = "蓝色单色",
        exposure = 0.95,
        temperature = -0.3,
        tint = -0.05,
        globalSaturation = 0.15,
        globalContrast = 1.1,
        shadowsTint = Color(0.2, 0.3, 0.6),
        shadowsTintIntensity = 0.4,
        highlightsTint = Color(0.6, 0.7, 1.0),
        highlightsTintIntensity = 0.2,
    },

    -- ====== 风格化 ======
    cyberpunk_neon = {
        name = "赛博朋克霓虹",
        exposure = 0.85,
        temperature = -0.1,
        tint = 0.08,
        globalSaturation = 1.4,
        globalContrast = 1.35,
        globalGamma = 0.9,
        shadowsTint = Color(0.1, 0.05, 0.3),
        shadowsTintIntensity = 0.35,
        highlightsTint = Color(0.9, 0.4, 1.0),
        highlightsTintIntensity = 0.15,
        midtonesTint = Color(0.2, 0.8, 0.9),
        midtonesTintIntensity = 0.1,
    },

    fantasy_pastel = {
        name = "梦幻粉彩",
        exposure = 1.15,
        temperature = 0.05,
        tint = 0.08,
        globalSaturation = 0.7,
        globalContrast = 0.85,
        globalGamma = 1.1,
        globalOffset = 0.03,
        shadowsTint = Color(0.5, 0.4, 0.6),
        shadowsTintIntensity = 0.15,
        highlightsTint = Color(1.0, 0.9, 0.95),
        highlightsTintIntensity = 0.1,
    },

    watercolor = {
        name = "水彩风",
        exposure = 1.2,
        temperature = 0.05,
        tint = 0.0,
        globalSaturation = 0.6,
        globalContrast = 0.8,
        globalGamma = 1.15,
        globalOffset = 0.04,
        shadowsGain = 1.3,
        highlightsGain = 0.85,
    },

    -- ====== 氛围 / 环境 ======
    horror_green = {
        name = "恐怖绿",
        exposure = 0.75,
        temperature = -0.05,
        tint = -0.15,
        globalSaturation = 0.6,
        globalContrast = 1.3,
        globalGamma = 0.8,
        shadowsTint = Color(0.1, 0.2, 0.1),
        shadowsTintIntensity = 0.3,
        midtonesTint = Color(0.3, 0.5, 0.3),
        midtonesTintIntensity = 0.15,
    },

    golden_hour = {
        name = "黄金时刻",
        exposure = 1.1,
        temperature = 0.35,
        tint = 0.05,
        globalSaturation = 1.1,
        globalContrast = 1.05,
        globalGamma = 1.0,
        shadowsTint = Color(0.6, 0.3, 0.2),
        shadowsTintIntensity = 0.2,
        highlightsTint = Color(1.0, 0.85, 0.5),
        highlightsTintIntensity = 0.2,
    },

    moonlit_night = {
        name = "月光之夜",
        exposure = 0.6,
        temperature = -0.2,
        tint = -0.05,
        globalSaturation = 0.5,
        globalContrast = 1.15,
        globalGamma = 0.9,
        shadowsTint = Color(0.15, 0.2, 0.35),
        shadowsTintIntensity = 0.35,
        highlightsTint = Color(0.7, 0.75, 1.0),
        highlightsTintIntensity = 0.15,
    },

    -- ====== 特殊效果 ======
    bleach_bypass = {
        name = "漂白旁通",
        exposure = 1.0,
        temperature = 0.0,
        tint = 0.0,
        globalSaturation = 0.5,
        globalContrast = 1.5,
        globalGamma = 0.9,
        shadowsGain = 0.7,
        highlightsGain = 1.3,
    },

    oversaturated_pop = {
        name = "过饱和波普",
        exposure = 1.05,
        temperature = 0.0,
        tint = 0.0,
        globalSaturation = 1.8,
        globalContrast = 1.2,
        globalGamma = 0.95,
    },
}
```

---

## VisualStyleManager 模块模板

将以下代码保存为 `scripts/VisualStyleManager.lua`：

```lua
-------------------------------------------------------
-- VisualStyleManager.lua
-- 运行时视觉风格管理器
-------------------------------------------------------
local VisualStyleManager = {}

local colorGrading_ = nil
local currentStyle_ = "default"
local currentParams_ = {}
local transitioning_ = false
local transitionFrom_ = {}
local transitionTo_ = {}
local transitionTime_ = 0
local transitionDuration_ = 0
local presets_ = {}  -- 将在 Init 中填充

-- 默认参数（引擎默认值）
local DEFAULT_PARAMS = {
    exposure = 1.0,
    temperature = 0.0,
    tint = 0.0,
    globalSaturation = 1.0,
    globalContrast = 1.0,
    globalGamma = 1.0,
    globalGain = 1.0,
    globalOffset = 0.0,
    shadowsSaturation = 1.0,
    shadowsContrast = 1.0,
    shadowsGamma = 1.0,
    shadowsGain = 1.0,
    shadowsOffset = 0.0,
    shadowsTint = Color(0.5, 0.5, 0.5),
    shadowsTintIntensity = 0.0,
    midtonesSaturation = 1.0,
    midtonesContrast = 1.0,
    midtonesGamma = 1.0,
    midtonesGain = 1.0,
    midtonesOffset = 0.0,
    midtonesTint = Color(0.5, 0.5, 0.5),
    midtonesTintIntensity = 0.0,
    highlightsSaturation = 1.0,
    highlightsContrast = 1.0,
    highlightsGamma = 1.0,
    highlightsGain = 1.0,
    highlightsOffset = 0.0,
    highlightsTint = Color(0.5, 0.5, 0.5),
    highlightsTintIntensity = 0.0,
    shadowsMax = 0.09,
    highlightsMin = 0.5,
}

--- 初始化风格管理器
---@param cameraNode Node 相机节点
---@param customPresets table|nil 自定义预设（可选，会合并到内置预设）
function VisualStyleManager.Init(cameraNode, customPresets)
    colorGrading_ = cameraNode:GetOrCreateComponent("ColorGrading")
    colorGrading_.colorGradingEnabled = true

    -- 复制内置预设
    for k, v in pairs(STYLE_PRESETS) do
        presets_[k] = v
    end

    -- 合并自定义预设
    if customPresets then
        for k, v in pairs(customPresets) do
            presets_[k] = v
        end
    end

    -- 记录当前参数
    currentParams_ = VisualStyleManager._CaptureCurrentParams()
    currentStyle_ = "default"
end

--- 立即应用风格预设
---@param styleName string 预设名称
function VisualStyleManager.Apply(styleName)
    local preset = presets_[styleName]
    if not preset then
        log:Write(LOG_WARNING, "VisualStyleManager: unknown style '" .. styleName .. "'")
        return false
    end

    transitioning_ = false
    VisualStyleManager._ApplyParams(preset)
    currentStyle_ = styleName
    currentParams_ = VisualStyleManager._CaptureCurrentParams()
    return true
end

--- 平滑过渡到目标风格
---@param styleName string 目标预设名称
---@param duration number 过渡时长（秒）
function VisualStyleManager.TransitionTo(styleName, duration)
    local preset = presets_[styleName]
    if not preset then
        log:Write(LOG_WARNING, "VisualStyleManager: unknown style '" .. styleName .. "'")
        return false
    end

    duration = duration or 1.0
    transitionFrom_ = VisualStyleManager._CaptureCurrentParams()
    transitionTo_ = {}

    -- 用默认值填充缺失字段
    for k, v in pairs(DEFAULT_PARAMS) do
        transitionTo_[k] = preset[k] or v
    end

    transitionTime_ = 0
    transitionDuration_ = duration
    transitioning_ = true
    currentStyle_ = styleName
    return true
end

--- 每帧更新（在 HandleUpdate 中调用）
---@param dt number 时间步长
function VisualStyleManager.Update(dt)
    if not transitioning_ then return end

    transitionTime_ = transitionTime_ + dt
    local t = math.min(transitionTime_ / transitionDuration_, 1.0)

    -- smoothstep 插值
    t = t * t * (3.0 - 2.0 * t)

    local lerped = VisualStyleManager._LerpParams(transitionFrom_, transitionTo_, t)
    VisualStyleManager._ApplyParams(lerped)

    if t >= 1.0 then
        transitioning_ = false
        currentParams_ = VisualStyleManager._CaptureCurrentParams()
    end
end

--- 重置为引擎默认
function VisualStyleManager.Reset()
    if colorGrading_ then
        colorGrading_:ResetToDefaults()
    end
    transitioning_ = false
    currentStyle_ = "default"
    currentParams_ = VisualStyleManager._CaptureCurrentParams()
end

--- 获取当前风格名称
function VisualStyleManager.GetCurrentStyle()
    return currentStyle_
end

--- 获取所有可用风格名称
function VisualStyleManager.GetAvailableStyles()
    local names = {}
    for k, v in pairs(presets_) do
        names[#names + 1] = { key = k, name = v.name or k }
    end
    table.sort(names, function(a, b) return a.key < b.key end)
    return names
end

--- 动态添加预设
function VisualStyleManager.AddPreset(key, params)
    presets_[key] = params
end

--- 直接设置单个参数（不通过预设）
function VisualStyleManager.SetParam(paramName, value)
    if colorGrading_ and DEFAULT_PARAMS[paramName] ~= nil then
        colorGrading_[paramName] = value
        currentParams_[paramName] = value
    end
end

--- 是否正在过渡中
function VisualStyleManager.IsTransitioning()
    return transitioning_
end

-- ========== 内部方法 ==========

function VisualStyleManager._ApplyParams(params)
    if not colorGrading_ then return end
    for k, v in pairs(params) do
        if k ~= "name" and DEFAULT_PARAMS[k] ~= nil then
            colorGrading_[k] = v
        end
    end
end

function VisualStyleManager._CaptureCurrentParams()
    if not colorGrading_ then return {} end
    local params = {}
    for k, _ in pairs(DEFAULT_PARAMS) do
        params[k] = colorGrading_[k]
    end
    return params
end

function VisualStyleManager._LerpParams(from, to, t)
    local result = {}
    for k, defaultVal in pairs(DEFAULT_PARAMS) do
        local a = from[k] or defaultVal
        local b = to[k] or defaultVal
        if type(a) == "number" then
            result[k] = a + (b - a) * t
        elseif type(a) == "userdata" and a.r then
            -- Color 插值
            result[k] = Color(
                a.r + (b.r - a.r) * t,
                a.g + (b.g - a.g) * t,
                a.b + (b.b - a.b) * t,
                a.a + (b.a - a.a) * t
            )
        else
            result[k] = (t < 0.5) and a or b
        end
    end
    return result
end

return VisualStyleManager
```

---

## 集成模板

### 基本用法（main.lua）

```lua
require "LuaScripts/Utilities/Sample"

-- 引入风格管理器和预设
local VisualStyleManager = require "VisualStyleManager"

function Start()
    SampleStart()

    -- 创建场景（略）
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    -- ... 创建场景内容 ...

    -- 创建相机
    local cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(0, 5, -10)
    cameraNode:CreateComponent("Camera")

    -- 初始化风格管理器
    VisualStyleManager.Init(cameraNode)

    -- 应用一个风格
    VisualStyleManager.Apply("cinematic_warm")

    -- 设置视口
    renderer:SetViewport(0, Viewport:new(scene_, cameraNode:GetComponent("Camera")))

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    VisualStyleManager.Update(dt)
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- 按 1-5 切换风格（带过渡动画）
    if key == KEY_1 then
        VisualStyleManager.TransitionTo("cinematic_warm", 1.5)
    elseif key == KEY_2 then
        VisualStyleManager.TransitionTo("noir", 1.5)
    elseif key == KEY_3 then
        VisualStyleManager.TransitionTo("cyberpunk_neon", 1.5)
    elseif key == KEY_4 then
        VisualStyleManager.TransitionTo("moonlit_night", 2.0)
    elseif key == KEY_5 then
        VisualStyleManager.Reset()
    end
end
```

### 游戏事件驱动风格切换

```lua
-- 根据游戏状态自动切换视觉风格
local GAME_STATE_STYLES = {
    menu       = { style = "fantasy_pastel",   transition = 1.0 },
    gameplay   = { style = "cinematic_warm",   transition = 0.8 },
    boss_fight = { style = "cyberpunk_neon",   transition = 0.5 },
    death      = { style = "noir",             transition = 0.3 },
    victory    = { style = "golden_hour",      transition = 1.5 },
    flashback  = { style = "faded_memory",     transition = 2.0 },
    horror     = { style = "horror_green",     transition = 1.0 },
}

function OnGameStateChanged(newState)
    local config = GAME_STATE_STYLES[newState]
    if config then
        VisualStyleManager.TransitionTo(config.style, config.transition)
    end
end
```

### 日夜循环视觉效果

```lua
-- 简单日夜循环：基于时间混合两种风格
local dayStyle = STYLE_PRESETS.cinematic_warm
local nightStyle = STYLE_PRESETS.moonlit_night
local gameTime = 0  -- 0-24 小时

function UpdateDayNightVisuals(dt)
    gameTime = (gameTime + dt * 0.01) % 24  -- 慢速循环

    -- 计算夜间因子 (0=白天, 1=夜晚)
    local nightFactor = 0
    if gameTime > 18 then
        nightFactor = math.min((gameTime - 18) / 2, 1.0)  -- 18-20 过渡
    elseif gameTime < 6 then
        nightFactor = 1.0
    elseif gameTime < 8 then
        nightFactor = 1.0 - (gameTime - 6) / 2  -- 6-8 过渡
    end

    -- smoothstep
    nightFactor = nightFactor * nightFactor * (3.0 - 2.0 * nightFactor)

    -- 混合参数并应用
    local blended = VisualStyleManager._LerpParams(dayStyle, nightStyle, nightFactor)
    VisualStyleManager._ApplyParams(blended)
end
```

---

## VisualFilters 模块（Image 像素操作）

用于一次性图像处理（如截图滤镜）。保存为 `scripts/VisualFilters.lua`：

```lua
-------------------------------------------------------
-- VisualFilters.lua
-- CPU 像素级图像滤镜（一次性处理，非实时）
-------------------------------------------------------
local VisualFilters = {}

--- 灰度化
function VisualFilters.Grayscale(image)
    local w, h = image.width, image.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = image:GetPixel(x, y)
            local gray = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
            image:SetPixel(x, y, Color(gray, gray, gray, c.a))
        end
    end
end

--- 棕褐色（怀旧）
function VisualFilters.Sepia(image, intensity)
    intensity = intensity or 1.0
    local w, h = image.width, image.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = image:GetPixel(x, y)
            local gray = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
            local sr = math.min(1.0, gray * 1.2)
            local sg = math.min(1.0, gray * 1.0)
            local sb = math.min(1.0, gray * 0.8)
            local t = intensity
            image:SetPixel(x, y, Color(
                c.r * (1 - t) + sr * t,
                c.g * (1 - t) + sg * t,
                c.b * (1 - t) + sb * t,
                c.a
            ))
        end
    end
end

--- 色调偏移（色相旋转，基于 YIQ 色彩空间）
function VisualFilters.HueShift(image, degrees)
    local rad = math.rad(degrees)
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)
    local w, h = image.width, image.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = image:GetPixel(x, y)
            -- RGB -> YIQ
            local yy = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
            local i  = 0.596 * c.r - 0.275 * c.g - 0.321 * c.b
            local q  = 0.212 * c.r - 0.523 * c.g + 0.311 * c.b
            -- 旋转 IQ 平面
            local ni = i * cosA - q * sinA
            local nq = i * sinA + q * cosA
            -- YIQ -> RGB
            local nr = math.max(0, math.min(1, yy + 0.956 * ni + 0.621 * nq))
            local ng = math.max(0, math.min(1, yy - 0.272 * ni - 0.647 * nq))
            local nb = math.max(0, math.min(1, yy - 1.107 * ni + 1.704 * nq))
            image:SetPixel(x, y, Color(nr, ng, nb, c.a))
        end
    end
end

--- 色阶化（减少色阶数量，卡通效果）
function VisualFilters.Posterize(image, levels)
    levels = levels or 4
    local step = 1.0 / levels
    local w, h = image.width, image.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = image:GetPixel(x, y)
            local r = math.floor(c.r / step + 0.5) * step
            local g = math.floor(c.g / step + 0.5) * step
            local b = math.floor(c.b / step + 0.5) * step
            image:SetPixel(x, y, Color(
                math.min(1, r), math.min(1, g), math.min(1, b), c.a
            ))
        end
    end
end

--- 反色
function VisualFilters.Invert(image)
    local w, h = image.width, image.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = image:GetPixel(x, y)
            image:SetPixel(x, y, Color(1 - c.r, 1 - c.g, 1 - c.b, c.a))
        end
    end
end

--- 亮度/对比度调整
function VisualFilters.BrightnessContrast(image, brightness, contrast)
    brightness = brightness or 0.0  -- -1.0 ~ +1.0
    contrast = contrast or 1.0      -- 0.0 ~ 3.0
    local w, h = image.width, image.height
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = image:GetPixel(x, y)
            local r = math.max(0, math.min(1, ((c.r - 0.5) * contrast + 0.5) + brightness))
            local g = math.max(0, math.min(1, ((c.g - 0.5) * contrast + 0.5) + brightness))
            local b = math.max(0, math.min(1, ((c.b - 0.5) * contrast + 0.5) + brightness))
            image:SetPixel(x, y, Color(r, g, b, c.a))
        end
    end
end

return VisualFilters
```

---

## 方案选择决策树

```
需要运行时视觉风格化
  │
  ├─ 需要实时画面效果？
  │   ├─ 是 → ColorGrading 组件（推荐）
  │   │   ├─ 简单调色（曝光/色温/饱和度） → 直接设置参数
  │   │   ├─ 预设风格切换 → VisualStyleManager.Apply()
  │   │   ├─ 带过渡动画 → VisualStyleManager.TransitionTo()
  │   │   └─ LUT 精确调色 → colorGrading:SetLUT() + BlendToLUT()
  │   │
  │   ├─ 需要后处理特效？ → RenderPath
  │   │   ├─ Bloom / FXAA → SetEnabled(tag, active)
  │   │   └─ 自定义着色器参数 → SetShaderParameter()
  │   │
  │   └─ NanoVG 项目需要屏幕效果？ → NanoVG 叠加
  │       ├─ 暗角 → DrawVignette()
  │       ├─ 扫描线 → DrawScanlines()
  │       └─ 颜色叠加 → DrawColorOverlay()
  │
  └─ 一次性图像处理（截图/贴图）？
      └─ Image 像素操作
          ├─ 灰度/棕褐/反色 → VisualFilters 模块
          └─ 自定义像素处理 → GetPixel/SetPixel 循环
```

---

## 重要注意事项

1. **ColorGrading 是首选方案**：性能最优、功能最全、支持动画过渡
2. **NanoVG 叠加效果仅限 NanoVG 项目**：不要在纯 3D/UI 项目中使用
3. **Image 像素操作不适合每帧执行**：仅用于一次性处理
4. **预设参数可自由组合**：不必使用完整预设，可以只设置部分参数
5. **过渡动画使用 smoothstep**：比线性插值更平滑自然
6. **ColorGrading 组件挂载在相机节点上**：不是场景根节点

---

## 跨 Skill 协作

| 场景 | 搭配 Skill | 说明 |
|------|-----------|------|
| 素材统一风格 + 运行时氛围 | art-style-transfer + 本 Skill | 离线统一素材画风，运行时叠加氛围效果 |
| UI 动画过渡 | soyoyo_tween | 用 tween 驱动 SetParam 实现参数动画 |
| 场景氛围音乐 | audio-manager | 风格切换时同步切换背景音乐 |
| 日夜循环 | materials | 配合灯光预设实现完整日夜效果 |

---

## 常见问题排查

| 症状 | 原因 | 解决方案 |
|------|------|---------|
| ColorGrading 不生效 | colorGradingEnabled 为 false | 设置 `colorGrading.colorGradingEnabled = true` |
| 过渡动画卡顿 | Update 中未调用 VisualStyleManager.Update | 确保每帧调用 |
| 风格切换无效果 | 预设名称拼写错误 | 检查预设 key 拼写 |
| 画面过暗/过亮 | exposure 或 gain 值异常 | 调整到合理范围（0.5-2.0） |
| NanoVG 叠加遮挡 UI | NanoVG 绘制顺序错误 | 确保叠加效果在 UI 之前绘制 |
| Image 处理太慢 | 大图逐像素遍历 | 先 Resize 到小尺寸再处理 |
| LUT 加载失败 | 文件路径错误 | 使用 assets/ 下相对路径 |
