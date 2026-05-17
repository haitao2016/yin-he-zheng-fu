# 注入代码模板完整参考

> 本文档提供可直接复制的完整注入代码模板，按模块分类。
> 每个模板都标注了注入位置、前置条件和注意事项。

---

## 模块 A: 缩放初始化（UI 组件系统）

### A1: 全新 UI.Init（项目尚无 UI.Init）

```lua
-- ============================================
-- [AUTO-ADAPT] 缩放初始化
-- ============================================
local UI = require("urhox-libs/UI")

UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
    scale = UI.Scale.DEFAULT,
    -- DEFAULT = DPR_DENSITY_ADAPTIVE:
    -- dpr * clamp(sqrt(shortSide/720), 0.625, 1.0)
})
```

**注入位置**: `Start()` 函数最前面
**前置条件**: 无

### A2: 修复已有 UI.Init（缺少 scale 参数）

```lua
-- 修改前:
UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
})

-- 修改后:
UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
    scale = UI.Scale.DEFAULT,   -- [AUTO-ADAPT] 添加缩放
})
```

### A3: 修复硬编码 scale

```lua
-- 修改前:
UI.Init({
    fonts = { ... },
    scale = 2,           -- ❌ 硬编码
})

-- 修改后:
UI.Init({
    fonts = { ... },
    scale = UI.Scale.DEFAULT,   -- [AUTO-ADAPT] 自适应缩放
})
```

### A4: 用户指定了设计分辨率

```lua
-- 当用户明确说"按 1920x1080 设计"时:
UI.Init({
    fonts = { ... },
    scale = UI.Scale.DESIGN_RESOLUTION(1920, 1080),  -- 设计分辨率模式
})

-- 当用户明确说"按短边 720 设计"时:
UI.Init({
    fonts = { ... },
    scale = UI.Scale.DESIGN_SHORT_SIDE(720),
})
```

---

## 模块 B: 安全区域包裹（UI 组件系统）

### B1: 包裹整个根节点

```lua
-- ============================================
-- [AUTO-ADAPT] 安全区域适配
-- ============================================

-- 修改前:
UI.SetRoot(UI.Panel {
    width = "100%", height = "100%",
    children = { ... }
})

-- 修改后:
UI.SetRoot(
    UI.SafeAreaView {
        edges = "all",
        mode = "padding",
        backgroundColor = Color(0, 0, 0, 1),
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                children = { ... }   -- 原有内容不变
            }
        }
    }
)
```

### B2: 横屏游戏（仅左右安全区）

```lua
UI.SetRoot(
    UI.SafeAreaView {
        edges = "horizontal",   -- 仅左右（刘海/圆角）
        mode = "padding",
        backgroundColor = Color(0, 0, 0, 1),
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                children = { ... }
            }
        }
    }
)
```

### B3: 已有 SafeAreaView 但 edges 不完整

```lua
-- 修改前:
UI.SafeAreaView {
    edges = "horizontal",   -- 只有水平
    children = { ... }
}

-- 建议修改（如果竖屏也需要）:
UI.SafeAreaView {
    edges = "all",          -- [AUTO-ADAPT] 扩展为全边安全区
    mode = "padding",
    children = { ... }
}
```

---

## 模块 C: 断点检测与设备分类

### C1: 基础设备分类（内联版）

```lua
-- ============================================
-- [AUTO-ADAPT] 设备分类
-- ============================================

---@return "phone"|"tablet"|"desktop"
local function getDeviceType()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local shortSide = math.min(physW, physH) / dpr
    if shortSide < 600 then
        return "phone"
    elseif shortSide < 900 then
        return "tablet"
    else
        return "desktop"
    end
end
```

**注入位置**: 文件顶部（require 语句之后、Start() 之前）

### C2: 详细设备信息（内联版）

```lua
-- ============================================
-- [AUTO-ADAPT] 设备详情
-- ============================================

---@return table
local function getDeviceInfo()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr
    local shortSide = math.min(logW, logH)
    return {
        type = (shortSide < 600) and "phone"
            or (shortSide < 900) and "tablet"
            or "desktop",
        physW = physW,
        physH = physH,
        dpr = dpr,
        logicalW = logW,
        logicalH = logH,
        shortSide = shortSide,
        isPortrait = logH > logW,
        aspectRatio = math.max(logW, logH) / math.min(logW, logH),
    }
end
```

### C3: 条件值选择器

```lua
-- ============================================
-- [AUTO-ADAPT] 设备条件值选择
-- ============================================

--- 根据设备类型选择值
---@param phoneVal any
---@param tabletVal any
---@param desktopVal any
---@return any
local function pick(phoneVal, tabletVal, desktopVal)
    local dt = getDeviceType()
    if dt == "phone" then return phoneVal
    elseif dt == "tablet" then return tabletVal
    else return desktopVal end
end

-- 用法:
local padding = pick(8, 12, 16)
local fontSize = pick(14, 16, 18)
local columns = pick(2, 3, 5)
```

---

## 模块 D: 响应式布局

### D1: SimpleGrid 自动列数

```lua
-- ============================================
-- [AUTO-ADAPT] 响应式网格
-- ============================================
local grid = UI.SimpleGrid {
    width = "100%",
    minColumnWidth = 150,
    gap = 8,
    children = items,
}
```

### D2: 条件布局切换

```lua
-- ============================================
-- [AUTO-ADAPT] 条件布局切换
-- ============================================
local function createAdaptiveLayout(contentChildren)
    local device = getDeviceType()

    if device == "phone" then
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "column",
            padding = 8,
            children = contentChildren,
        }
    elseif device == "tablet" then
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "row",
            children = {
                UI.Panel {
                    width = 240, height = "100%",
                    children = { contentChildren[1] },
                },
                UI.Panel {
                    width = "100%", height = "100%",
                    flexShrink = 1,
                    children = { contentChildren[2] },
                },
            },
        }
    else
        return UI.Panel {
            width = "100%", height = "100%",
            alignItems = "center",
            children = {
                UI.Panel {
                    width = "100%", maxWidth = 1200, height = "100%",
                    flexDirection = "row",
                    padding = 16,
                    children = contentChildren,
                },
            },
        }
    end
end
```

### D3: 弹性百分比布局

```lua
-- ============================================
-- [AUTO-ADAPT] 弹性百分比布局
-- ============================================
local root = UI.Panel {
    width = "100%", height = "100%",
    flexDirection = "column",
    children = {
        -- 固定高度头部
        UI.Panel {
            width = "100%", height = 48,
            flexDirection = "row",
            justifyContent = "spaceBetween",
            alignItems = "center",
            paddingHorizontal = 12,
            children = headerChildren,
        },
        -- 弹性内容区
        UI.Panel {
            width = "100%",
            flexGrow = 1,
            flexShrink = 1,   -- ⚠️ Yoga 默认=0，必须显式设置！
            children = contentChildren,
        },
        -- 固定高度底部
        UI.Panel {
            width = "100%", height = 56,
            flexDirection = "row",
            justifyContent = "spaceEvenly",
            alignItems = "center",
            children = footerChildren,
        },
    },
}
```

### D4: 滚动容器适配

```lua
-- ============================================
-- [AUTO-ADAPT] 滚动容器（内容超出时自动滚动）
-- ============================================
local scrollArea = UI.ScrollView {
    width = "100%",
    flexGrow = 1,
    flexShrink = 1,
    children = {
        UI.Panel {
            width = "100%",
            -- 内容会自动撑开高度，超出部分可滚动
            children = longContentChildren,
        },
    },
}
```

---

## 模块 E: 字体缩放

### E1: UI 组件字体适配

```lua
-- ============================================
-- [AUTO-ADAPT] 自适应字体大小
-- ============================================

---@param baseSize number 基础字号（desktop 基准）
---@return number
local function adaptFontSize(baseSize)
    local device = getDeviceType()
    if device == "phone" then
        return math.max(12, baseSize * 0.85)
    elseif device == "tablet" then
        return baseSize * 0.95
    else
        return baseSize
    end
end
```

### E2: NanoVG 字体适配

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 自适应字体
-- ============================================

---@param baseSize number 基础字号（720p 逻辑高度基准）
---@return number
local function nvgAdaptFontSize(baseSize)
    local shortSide = math.min(graphics:GetWidth(), graphics:GetHeight()) / graphics:GetDPR()
    local factor = math.max(0.6, math.min(1.2, shortSide / 720))
    return math.floor(baseSize * factor + 0.5)
end
```

---

## 模块 F: 屏幕变化处理

### F1: 基础尺寸变化检测

```lua
-- ============================================
-- [AUTO-ADAPT] 屏幕尺寸变化监听
-- ============================================

local _lastScreenW, _lastScreenH = 0, 0

---@param rebuildFn function
local function checkScreenResize(rebuildFn)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    if w ~= _lastScreenW or h ~= _lastScreenH then
        _lastScreenW = w
        _lastScreenH = h
        if rebuildFn then rebuildFn() end
    end
end

-- 在 HandleUpdate 中使用:
-- checkScreenResize(rebuildUI)
```

### F2: 带设备类型变化检测

```lua
-- ============================================
-- [AUTO-ADAPT] 设备类型变化监听
-- ============================================

local _lastScreenW, _lastScreenH = 0, 0
local _lastDeviceType = ""

---@param onResize function|nil 尺寸变化回调
---@param onDeviceChange function|nil 设备类型变化回调(newType, oldType)
local function checkScreenChange(onResize, onDeviceChange)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    if w ~= _lastScreenW or h ~= _lastScreenH then
        _lastScreenW = w
        _lastScreenH = h
        local newType = getDeviceType()
        if newType ~= _lastDeviceType then
            local oldType = _lastDeviceType
            _lastDeviceType = newType
            if onDeviceChange then onDeviceChange(newType, oldType) end
        end
        if onResize then onResize() end
    end
end
```

---

## 模块 NV: NanoVG 专用模板

### NV-A: nvgBeginFrame 修正（模式 B）

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 分辨率修正（模式 B）
-- ============================================
function HandleNanoVGRender(eventType, eventData)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    -- 模式 B: 逻辑坐标 + DPR
    local w = physW / dpr
    local h = physH / dpr
    nvgBeginFrame(vg, w, h, dpr)

    -- 绘图代码（使用逻辑坐标 w, h）
    -- ...

    nvgEndFrame(vg)
end
```

### NV-B: NanoVG 安全区域

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 安全区域
-- ============================================

---@return number, number, number, number
local function getSafeInsets()
    local top, right, bottom, left = GetSafeAreaInsets(false)
    local dpr = graphics:GetDPR()
    return top / dpr, right / dpr, bottom / dpr, left / dpr
end

---@return table {x, y, w, h}
local function getSafeRect()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local w, h = physW / dpr, physH / dpr
    local st, sr, sb, sl = getSafeInsets()
    return { x = sl, y = st, w = w - sl - sr, h = h - st - sb }
end

-- 使用:
-- local safe = getSafeRect()
-- nvgText(vg, safe.x + 10, safe.y + 30, "Score: 100")
```

### NV-C: NanoVG 完整适配模板

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 完整适配渲染
-- ============================================

local vg = nil
local fontNormal = -1

function Start()
    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleNanoVGRender(eventType, eventData)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local w = physW / dpr
    local h = physH / dpr

    nvgBeginFrame(vg, w, h, dpr)

    -- 安全区域
    local st, sr, sb, sl = getSafeInsets()
    local safeX, safeY = sl, st
    local safeW = w - sl - sr
    local safeH = h - st - sb

    -- 自适应字体
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, nvgAdaptFontSize(24))

    -- 在安全区域内绘制
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
    nvgText(vg, safeX + 10, safeY + 10, "Score: 100")

    nvgEndFrame(vg)
end
```

---

## 独立模块: DeviceAdapter.lua 完整版

见 SKILL.md §6.1，可直接复制为 `scripts/DeviceAdapter.lua`。

包含以下函数:
- `M.getDeviceType()` → "phone"|"tablet"|"desktop"
- `M.getDeviceInfo()` → 详细设备信息 table
- `M.adaptFontSize(baseSize)` → UI 组件字体适配
- `M.nvgAdaptFontSize(baseSize)` → NanoVG 字体适配
- `M.getSafeInsets()` → 安全区域逻辑像素
- `M.getSafeRect()` → 安全绘制区域
- `M.checkResize(callback)` → 屏幕变化检测
- `M.pick(phoneVal, tabletVal, desktopVal)` → 设备条件值选择

---

## 组合注入示例

### 完整注入示例: UI 组件项目（L0 → 全注入）

```lua
-- ============================================
-- [AUTO-ADAPT] 设备分类工具函数
-- ============================================
---@return "phone"|"tablet"|"desktop"
local function getDeviceType()
    local shortSide = math.min(graphics:GetWidth(), graphics:GetHeight()) / graphics:GetDPR()
    if shortSide < 600 then return "phone"
    elseif shortSide < 900 then return "tablet"
    else return "desktop" end
end

---@param baseSize number
---@return number
local function adaptFontSize(baseSize)
    local dt = getDeviceType()
    if dt == "phone" then return math.max(12, baseSize * 0.85)
    elseif dt == "tablet" then return baseSize * 0.95
    else return baseSize end
end

---@param phoneVal any @param tabletVal any @param desktopVal any
local function pick(phoneVal, tabletVal, desktopVal)
    local dt = getDeviceType()
    if dt == "phone" then return phoneVal
    elseif dt == "tablet" then return tabletVal
    else return desktopVal end
end

local _lastW, _lastH = 0, 0
local function checkScreenResize(fn)
    local w, h = graphics:GetWidth(), graphics:GetHeight()
    if w ~= _lastW or h ~= _lastH then
        _lastW, _lastH = w, h
        if fn then fn() end
    end
end

-- ============================================
-- 游戏代码
-- ============================================
local UI = require("urhox-libs/UI")

function Start()
    -- [AUTO-ADAPT] 缩放初始化
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    buildUI()
end

function buildUI()
    -- [AUTO-ADAPT] 安全区域 + 响应式布局
    UI.SetRoot(
        UI.SafeAreaView {
            edges = "all",
            mode = "padding",
            backgroundColor = Color(0, 0, 0, 1),
            children = {
                UI.Panel {
                    width = "100%", height = "100%",
                    flexDirection = "column",
                    children = {
                        UI.Label {
                            text = "My Game",
                            fontSize = adaptFontSize(28),
                        },
                        UI.Panel {
                            width = "100%",
                            flexGrow = 1,
                            flexShrink = 1,
                            padding = pick(8, 12, 16),
                            children = {
                                -- 游戏内容
                            },
                        },
                    },
                },
            },
        }
    )
end

function HandleUpdate(eventType, eventData)
    -- [AUTO-ADAPT] 屏幕变化检测
    checkScreenResize(buildUI)
end
```

