---
name: responsive-ui-auto-adapter
description: |
  UrhoX Lua 游戏 UI 全设备自动适配注入器。扫描现有游戏代码，自动识别 UI 技术栈
  （urhox-libs/UI 组件 或 raw NanoVG），分析适配缺失项，
  一键注入完整的响应式适配层：缩放初始化、安全区域、断点检测、响应式布局重构、
  字体缩放、屏幕旋转/尺寸变化处理。

  与 responsive-ui-adapter（参考指南）不同，本 Skill 是自动化代码转换工具——
  直接分析用户代码并注入适配代码，而非提供参考片段。

  Use when users need to (1) 自动给现有游戏添加多设备适配,
  (2) 一键让 UI 兼容手机/平板/PC,
  (3) 用户说"帮我适配""自动适配""一键适配",
  (4) 用户的游戏在某些设备上 UI 显示异常,
  (5) 用户希望不手动改代码就能适配所有设备,
  (6) 从零开始写项目时自动内置适配能力,
  (7) 用户说"全设备""全平台 UI""自动响应式"。

  MUST trigger when:
    - 用户明确要求自动/一键适配所有设备界面
    - 用户的游戏代码完全缺失适配逻辑且要求修复
    - 用户说"帮我做自适应适配"或"自动适配所有设备"

  trigger-keywords:
    - 自动适配
    - 一键适配
    - 全设备适配
    - 自动自适应
    - 自动响应式
    - auto adapt
    - auto responsive
    - 注入适配
    - 适配注入
    - UI自适应
    - 全平台UI
    - 设备适配
    - 屏幕自适应
    - 自动兼容

version: "1.0.0"
metadata:
  author: "UrhoX-Skill"
  tags: ["ui", "responsive", "auto-adapter", "code-injection", "device-adaptation"]
---

# UI 全设备自动适配注入器

> **自动扫描 → 智能检测 → 一键注入**：让任何 UrhoX Lua 游戏的 UI 自动适配全设备。

---

## 1. 身份与定位

本 Skill 是 **自动化 UI 适配代码注入器**，执行四步工作流：

```
SCAN（扫描代码） → CLASSIFY（评估适配状态） → INJECT（注入适配代码） → VERIFY（验证结果）
```

### 1.1 与相关 Skill 的关系

| Skill | 职责 | 层级 |
|-------|------|------|
| **responsive-ui-auto-adapter**（本 Skill） | 自动分析代码并注入适配层 | 代码生成/转换层 |
| `responsive-ui-adapter` | 提供适配方案参考片段 | 设计参考层 |
| `universal-playable-adapter` | 输入方式适配（触屏/键鼠/手柄） | 输入层 |
| `device-adaptation-bug-fixer` | 扫描已有代码中的适配 BUG | 诊断修复层 |

**本 Skill 不重复上述 Skill 的功能**，而是在它们之上提供自动化注入能力。

---

## 2. 四步工作流

### 步骤 1: SCAN — 扫描代码

扫描 `scripts/` 目录，识别项目的 UI 技术栈和当前适配状态。

#### 2.1.1 UI 技术栈检测

```
检测优先级（从高到低）：

1. urhox-libs/UI 组件系统
   检测标志: require("urhox-libs/UI") 或 require "urhox-libs/UI"
   关键函数: UI.Init, UI.Panel, UI.Label, UI.Button, UI.SetRoot

2. raw NanoVG 绘制
   检测标志: nvgCreate, nvgBeginFrame, nvgEndFrame
   关键事件: SubscribeToEvent("NanoVGRender", ...)

3. 混合模式（UI 组件 + NanoVG）
   同时存在上述两类标志

4. 旧版原生 UI（已废弃，建议迁移）
   检测标志: ui.root, UIElement, CreateButton, CreateText
   不注入适配，提示用户迁移到 urhox-libs/UI
```

#### 2.1.2 适配状态检测清单

对每个维度检测是否已存在适配代码：

| 维度 | 检测标志 | 状态 |
|------|---------|------|
| **缩放初始化** | `UI.Scale` 参数 / `nvgBeginFrame` 参数正确性 | ✅已有 / ❌缺失 |
| **安全区域** | `SafeAreaView` / `GetSafeAreaInsets` | ✅已有 / ❌缺失 |
| **断点检测** | `getDeviceType` / 短边分类逻辑 | ✅已有 / ❌缺失 |
| **响应式布局** | 条件布局切换 / `SimpleGrid` / `flexWrap` | ✅已有 / ❌缺失 |
| **字体缩放** | `fontSize` 随设备变化 / `fontScale` | ✅已有 / ❌缺失 |
| **屏幕变化处理** | 尺寸变化检测逻辑 | ✅已有 / ❌缺失 |
| **DPR 处理** | `graphics:GetDPR()` 调用 | ✅已有 / ❌缺失 |

### 步骤 2: CLASSIFY — 评估适配级别

根据扫描结果，将项目分为三个适配级别：

| 级别 | 条件 | 注入策略 |
|------|------|---------|
| **L0 - 无适配** | 所有维度均缺失 | 完整注入全部模块 |
| **L1 - 部分适配** | 1-4 个维度已有 | 补充注入缺失模块 |
| **L2 - 基本完备** | 5+ 个维度已有 | 仅提示优化建议，不自动注入 |

### 步骤 3: INJECT — 注入适配代码

根据技术栈和适配级别，选择对应注入模板。

### 步骤 4: VERIFY — 验证结果

注入后检查：
1. 代码无语法错误（调用 build 工具）
2. UI.Init 参数正确
3. 安全区域包裹层级正确
4. 断点检测逻辑完整

---

## 3. 注入模块详解（UI 组件系统）

当检测到项目使用 `urhox-libs/UI` 组件系统时，按以下模块注入。

### 3.1 模块 A: 缩放初始化

**检测**: `UI.Init` 调用中是否有 `scale` 参数

**缺失时注入**:

```lua
-- ============================================
-- [AUTO-ADAPT] 缩放初始化
-- ============================================
local UI = require("urhox-libs/UI")

UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
    -- DEFAULT = DPR_DENSITY_ADAPTIVE:
    -- dpr * clamp(sqrt(shortSide/720), 0.625, 1.0)
    -- 自动适配不同密度和尺寸的屏幕
    scale = UI.Scale.DEFAULT,
})
```

**已有但不正确时修复**:

| 现有写法 | 问题 | 修复为 |
|---------|------|--------|
| `scale = 1` 或 `scale = 2` | 硬编码缩放，不适配 | `scale = UI.Scale.DEFAULT` |
| 无 `scale` 字段 | 缺失缩放 | 添加 `scale = UI.Scale.DEFAULT` |
| `scale = UI.Scale.DPR` | 可用，但小屏过小 | 保留（可选优化为 DEFAULT） |

**规则**:
- 如果用户明确了设计分辨率 → 使用 `UI.Scale.DESIGN_RESOLUTION(w, h)`
- 如果用户未明确 → 使用 `UI.Scale.DEFAULT`（即 DPR_DENSITY_ADAPTIVE）
- 不要使用裸数字作为 scale 值

### 3.2 模块 B: 安全区域包裹

**检测**: 根节点是否被 `SafeAreaView` 包裹

**缺失时注入**:

将现有根节点包裹在 SafeAreaView 中：

```lua
-- ============================================
-- [AUTO-ADAPT] 安全区域适配
-- ============================================

-- 修改前:
-- UI.SetRoot(UI.Panel { ... })

-- 修改后:
UI.SetRoot(
    UI.SafeAreaView {
        edges = "all",        -- 四边安全区域
        mode = "padding",     -- padding 模式（内容内缩）
        backgroundColor = Color(0, 0, 0, 1),  -- 安全区外的背景色
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                -- ... 原有内容 ...
            }
        }
    }
)
```

**注入规则**:
- 横屏游戏: `edges = "horizontal"` （左右刘海/圆角）
- 竖屏游戏: `edges = "all"` （四边）
- 如果已有 SafeAreaView 但 edges 不全 → 提示用户检查

### 3.3 模块 C: 断点检测与设备分类

**检测**: 是否存在设备分类函数

**缺失时注入**:

```lua
-- ============================================
-- [AUTO-ADAPT] 设备分类与断点检测
-- ============================================

--- 获取设备类型（phone / tablet / desktop）
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

--- 获取详细设备信息
---@return table {type, physW, physH, dpr, logicalW, logicalH, shortSide, isPortrait, aspectRatio}
local function getDeviceInfo()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr
    local shortSide = math.min(logW, logH)
    return {
        type = (shortSide < 600) and "phone" or (shortSide < 900) and "tablet" or "desktop",
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

**断点阈值**:

| 设备类型 | 逻辑短边范围 | 典型设备 |
|---------|------------|---------|
| `phone` | < 600 | iPhone, Android 手机 |
| `tablet` | 600 ~ 899 | iPad, Android 平板 |
| `desktop` | ≥ 900 | PC, Mac |

### 3.4 模块 D: 响应式布局重构

**检测**: 是否有条件布局切换逻辑

**缺失时注入**（根据项目复杂度选择策略）:

#### 策略 D1: SimpleGrid 自动列数（简单场景）

适用于：网格/卡片/图标列表布局

```lua
-- ============================================
-- [AUTO-ADAPT] 响应式网格布局
-- ============================================

-- SimpleGrid 根据容器宽度自动计算列数
-- minColumnWidth=150 → 手机2列、平板3-4列、PC5-6列
local grid = UI.SimpleGrid {
    width = "100%",
    minColumnWidth = 150,   -- 最小列宽（逻辑像素）
    gap = 8,
    children = items,       -- 子元素列表
}
```

#### 策略 D2: 条件布局切换（复杂场景）

适用于：需要不同设备完全不同布局的场景

```lua
-- ============================================
-- [AUTO-ADAPT] 条件布局切换
-- ============================================

local function createAdaptiveLayout(children)
    local device = getDeviceType()

    if device == "phone" then
        -- 手机: 垂直堆叠，全宽
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "column",
            padding = 8,
            children = children,
        }
    elseif device == "tablet" then
        -- 平板: 侧边栏 + 内容
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "row",
            children = {
                UI.Panel {
                    width = 240, height = "100%",
                    children = { children[1] },  -- 侧边栏
                },
                UI.Panel {
                    width = "100%", height = "100%",
                    flexShrink = 1,
                    children = { children[2] },  -- 主内容
                },
            },
        }
    else
        -- PC: 宽布局，居中最大宽度
        return UI.Panel {
            width = "100%", height = "100%",
            alignItems = "center",
            children = {
                UI.Panel {
                    width = "100%", maxWidth = 1200, height = "100%",
                    flexDirection = "row",
                    padding = 16,
                    children = children,
                },
            },
        }
    end
end
```

#### 策略 D3: 弹性百分比布局（通用场景）

适用于：大多数普通 UI

```lua
-- ============================================
-- [AUTO-ADAPT] 弹性百分比布局
-- ============================================

-- 使用百分比 + flexShrink 自动适配
local root = UI.Panel {
    width = "100%", height = "100%",
    flexDirection = "column",
    children = {
        -- 顶部栏: 固定高度
        UI.Panel {
            width = "100%", height = 48,
            flexDirection = "row",
            justifyContent = "spaceBetween",
            alignItems = "center",
            paddingHorizontal = 12,
            children = { --[[ 标题、按钮 ]] },
        },
        -- 内容区: 自动填充
        UI.Panel {
            width = "100%",
            flexGrow = 1,       -- 填充剩余空间
            flexShrink = 1,     -- 允许缩小（Yoga 默认=0, 需显式设置！）
            children = { --[[ 游戏内容 ]] },
        },
        -- 底部栏: 固定高度
        UI.Panel {
            width = "100%", height = 56,
            children = { --[[ 操作按钮 ]] },
        },
    },
}
```

**⚠️ 关键: Yoga flexShrink 默认值**

```
Yoga (UrhoX) 默认: flexShrink = 0  （不允许缩小）
CSS 默认:          flex-shrink = 1  （允许缩小）

→ 需要子元素自适应缩小时，必须显式设置 flexShrink = 1
```

### 3.5 模块 E: 字体缩放适配

**检测**: fontSize 是否使用固定值且无设备条件

**注入策略**: 根据设备类型调整字体大小

```lua
-- ============================================
-- [AUTO-ADAPT] 自适应字体大小
-- ============================================

--- 获取适配后的字体大小
---@param baseSize number 基础字号（以 desktop 为基准）
---@return number 适配后的字号
local function adaptFontSize(baseSize)
    local device = getDeviceType()
    if device == "phone" then
        return math.max(12, baseSize * 0.85)   -- 手机略小，最小12
    elseif device == "tablet" then
        return baseSize * 0.95                  -- 平板略小
    else
        return baseSize                         -- PC 保持原值
    end
end

-- 使用示例:
UI.Label { text = "标题", fontSize = adaptFontSize(24) }
UI.Label { text = "正文", fontSize = adaptFontSize(16) }
```

**注意**: UI 库的 Theme.FontSize 计算公式为 `ptSize * sizeRatio * fontScale`，
**不会**再乘以 uiScale（NanoVG 自身缩放已处理 DPR）。
因此 `adaptFontSize` 只需关注逻辑字号的设备差异。

### 3.6 模块 F: 屏幕尺寸变化处理

**检测**: 是否有屏幕尺寸变化检测逻辑

**注入策略**:

```lua
-- ============================================
-- [AUTO-ADAPT] 屏幕尺寸变化监听
-- ============================================

local lastWidth = 0
local lastHeight = 0

--- 检查屏幕尺寸是否发生变化，如有变化则重建 UI
---@param rebuildFn function 重建 UI 的回调函数
local function checkScreenResize(rebuildFn)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    if w ~= lastWidth or h ~= lastHeight then
        lastWidth = w
        lastHeight = h
        rebuildFn()
    end
end

-- 在 HandleUpdate 中调用:
function HandleUpdate(eventType, eventData)
    checkScreenResize(function()
        rebuildUI()  -- 用户定义的 UI 重建函数
    end)
end
```

**注意**: 现代 UI 系统（urhox-libs/UI）内部已在 `UI.Update(dt)` 中轮询屏幕变化。
此模块用于用户代码中需要根据尺寸变化执行额外逻辑（如切换布局策略）的场景。

---

## 4. 注入模块详解（raw NanoVG）

当检测到项目使用 raw NanoVG 绘制时，按以下模块注入。

### 4.1 模块 NV-A: nvgBeginFrame 参数修正

**检测**: `nvgBeginFrame` 调用参数是否正确

**常见错误与修正**:

```lua
-- ❌ 错误: 使用物理分辨率，高 DPI 屏幕 UI 偏小
nvgBeginFrame(vg, physW, physH, 1.0)

-- ❌ 错误: DPR 参数位置错误
nvgBeginFrame(vg, physW, physH, dpr)

-- ✅ 正确（模式 B - 推荐）: 系统逻辑分辨率 + DPR
local dpr = graphics:GetDPR()
local logW = graphics:GetWidth() / dpr
local logH = graphics:GetHeight() / dpr
nvgBeginFrame(vg, logW, logH, dpr)
```

**修正规则**:

| 现有写法 | 检测模式 | 修正为 |
|---------|---------|--------|
| `nvgBeginFrame(vg, w, h, 1.0)` | 物理分辨率+1.0 | 模式 B |
| `nvgBeginFrame(vg, w, h, dpr)` | 物理分辨率+DPR | 模式 B |
| `nvgBeginFrame(vg, w/dpr, h/dpr, dpr)` | 已正确（模式B） | 不修改 |
| `nvgBeginFrame(vg, designW, designH, ...)` | 设计分辨率（模式A） | 不修改 |

### 4.2 模块 NV-B: 坐标系适配

**检测**: NanoVG 绘图坐标是否使用物理像素

**注入**:

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 坐标适配
-- ============================================

-- 在 NanoVGRender 事件处理函数中:
function HandleNanoVGRender(eventType, eventData)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    -- 使用逻辑坐标（模式 B）
    local w = physW / dpr
    local h = physH / dpr

    nvgBeginFrame(vg, w, h, dpr)

    -- 所有绘图使用逻辑坐标
    -- w, h 是逻辑尺寸，直接用于布局计算
    -- 例: 居中绘制一个 100x100 的矩形
    nvgRect(vg, w/2 - 50, h/2 - 50, 100, 100)

    nvgEndFrame(vg)
end
```

### 4.3 模块 NV-C: 安全区域内缩

**检测**: NanoVG 绘图是否考虑安全区域

**注入**:

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 安全区域内缩
-- ============================================

--- 获取安全区域边距（逻辑像素）
---@return number, number, number, number top, right, bottom, left
local function getSafeInsets()
    local top, right, bottom, left = GetSafeAreaInsets(false)
    local dpr = graphics:GetDPR()
    -- GetSafeAreaInsets 返回物理像素，需转换为逻辑像素
    return top / dpr, right / dpr, bottom / dpr, left / dpr
end

-- 在绘制时使用安全区域:
function HandleNanoVGRender(eventType, eventData)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local w, h = physW / dpr, physH / dpr

    local safeTop, safeRight, safeBottom, safeLeft = getSafeInsets()

    nvgBeginFrame(vg, w, h, dpr)

    -- 安全绘制区域
    local safeX = safeLeft
    local safeY = safeTop
    local safeW = w - safeLeft - safeRight
    local safeH = h - safeTop - safeBottom

    -- 将所有 UI 元素限制在安全区域内
    -- 例: HUD 文本
    nvgText(vg, safeX + 10, safeY + 30, "Score: 100")

    nvgEndFrame(vg)
end
```

### 4.4 模块 NV-D: 自适应字体大小

**注入**:

```lua
-- ============================================
-- [AUTO-ADAPT] NanoVG 自适应字体
-- ============================================

--- NanoVG 自适应字体大小
---@param baseSize number 基础字号（以 720p 逻辑高度为基准）
---@return number 适配后的字号
local function nvgAdaptFontSize(baseSize)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local shortSide = math.min(physW, physH) / dpr

    -- 以 720 为基准缩放
    local scaleFactor = math.max(0.6, math.min(1.2, shortSide / 720))
    return math.floor(baseSize * scaleFactor + 0.5)
end

-- 使用:
nvgFontSize(vg, nvgAdaptFontSize(24))
nvgText(vg, x, y, "Hello World")
```

---

## 5. 注入流程（操作指南）

当触发本 Skill 时，按以下步骤执行：

### 5.1 完整流程

```
步骤 1: 扫描
──────────
1a. 列出 scripts/ 目录所有 .lua 文件
1b. 在每个文件中检测 UI 技术栈标志:
    - grep "require.*urhox-libs/UI"     → UI 组件
    - grep "nvgCreate\|nvgBeginFrame"   → raw NanoVG
    - grep "ui\.root\|UIElement"        → 旧版原生 UI
1c. 检测每个适配维度的状态（见 §2.1.2 清单）

步骤 2: 评估
──────────
2a. 统计已有/缺失的适配维度数量
2b. 确定适配级别（L0 / L1 / L2）
2c. 向用户报告扫描结果，列出缺失项

步骤 3: 注入
──────────
3a. 根据技术栈选择模块（§3 UI组件 或 §4 NanoVG）
3b. 仅注入缺失的模块，不修改已有的适配代码
3c. 注入位置规则:
    - 工具函数（getDeviceType 等）: 文件顶部（require 之后）
    - UI.Init 修改: 在现有 UI.Init 位置
    - SafeAreaView 包裹: 在 UI.SetRoot 位置
    - 屏幕变化监听: 在 HandleUpdate 中
3d. 每个注入块用 [AUTO-ADAPT] 注释标记

步骤 4: 验证
──────────
4a. 调用 build 工具构建项目
4b. 检查是否有语法错误
4c. 向用户汇报注入结果
```

### 5.2 注入位置规则

```
文件结构（注入后）:
┌──────────────────────────────┐
│ require 语句                  │
├──────────────────────────────┤
│ [AUTO-ADAPT] 工具函数         │  ← getDeviceType, adaptFontSize 等
├──────────────────────────────┤
│ 游戏配置/常量                 │
├──────────────────────────────┤
│ function Start()              │
│   UI.Init(...)     ← 修改    │  ← 确保 scale = UI.Scale.DEFAULT
│   ...                        │
│   UI.SetRoot(...)  ← 包裹    │  ← SafeAreaView 包裹
│ end                          │
├──────────────────────────────┤
│ function HandleUpdate(...)    │
│   checkScreenResize(...)      │  ← 屏幕变化监听
│   ...                        │
│ end                          │
└──────────────────────────────┘
```

### 5.3 不注入的情况

以下情况**不执行自动注入**，仅提供建议：

1. **L2 级别**（5+ 维度已适配）: 适配基本完备，只提优化建议
2. **旧版原生 UI**: 提示用户先迁移到 urhox-libs/UI
3. **用户明确拒绝**: 尊重用户选择，仅提供参考代码
4. **代码结构过于复杂**: 多文件交叉引用，无法安全注入，改为生成独立适配模块

---

## 6. 独立适配模块方案

对于多文件项目或结构复杂的项目，不直接修改现有代码，
而是生成一个独立的适配模块 `scripts/DeviceAdapter.lua`，
由用户手动引用。

### 6.1 DeviceAdapter.lua 模板

```lua
-- ============================================================
-- DeviceAdapter.lua — 全设备 UI 自适应适配模块
-- 自动生成，请根据项目需要调整
-- ============================================================

local M = {}

--- 获取设备类型
---@return "phone"|"tablet"|"desktop"
function M.getDeviceType()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local shortSide = math.min(physW, physH) / dpr
    if shortSide < 600 then return "phone"
    elseif shortSide < 900 then return "tablet"
    else return "desktop" end
end

--- 获取详细设备信息
---@return table
function M.getDeviceInfo()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW, logH = physW / dpr, physH / dpr
    local shortSide = math.min(logW, logH)
    return {
        type = M.getDeviceType(),
        physW = physW, physH = physH,
        dpr = dpr,
        logicalW = logW, logicalH = logH,
        shortSide = shortSide,
        isPortrait = logH > logW,
        aspectRatio = math.max(logW, logH) / math.min(logW, logH),
    }
end

--- 自适应字体大小
---@param baseSize number 基础字号
---@return number
function M.adaptFontSize(baseSize)
    local dt = M.getDeviceType()
    if dt == "phone" then return math.max(12, baseSize * 0.85)
    elseif dt == "tablet" then return baseSize * 0.95
    else return baseSize end
end

--- NanoVG 自适应字体大小（以 720p 为基准）
---@param baseSize number
---@return number
function M.nvgAdaptFontSize(baseSize)
    local shortSide = math.min(graphics:GetWidth(), graphics:GetHeight()) / graphics:GetDPR()
    local factor = math.max(0.6, math.min(1.2, shortSide / 720))
    return math.floor(baseSize * factor + 0.5)
end

--- 获取安全区域边距（逻辑像素）
---@return number, number, number, number top, right, bottom, left
function M.getSafeInsets()
    local top, right, bottom, left = GetSafeAreaInsets(false)
    local dpr = graphics:GetDPR()
    return top / dpr, right / dpr, bottom / dpr, left / dpr
end

--- 获取安全绘制区域（逻辑像素）
---@return table {x, y, w, h}
function M.getSafeRect()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local w, h = physW / dpr, physH / dpr
    local st, sr, sb, sl = M.getSafeInsets()
    return {
        x = sl,
        y = st,
        w = w - sl - sr,
        h = h - st - sb,
    }
end

-- 屏幕尺寸变化检测
local _lastW, _lastH = 0, 0

--- 检查屏幕尺寸变化
---@param callback function 变化时的回调
---@return boolean 是否发生变化
function M.checkResize(callback)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    if w ~= _lastW or h ~= _lastH then
        _lastW, _lastH = w, h
        if callback then callback(M.getDeviceInfo()) end
        return true
    end
    return false
end

--- 根据设备类型选择值
---@param phoneVal any
---@param tabletVal any
---@param desktopVal any
---@return any
function M.pick(phoneVal, tabletVal, desktopVal)
    local dt = M.getDeviceType()
    if dt == "phone" then return phoneVal
    elseif dt == "tablet" then return tabletVal
    else return desktopVal end
end

return M
```

### 6.2 使用方式

```lua
local DA = require "DeviceAdapter"

-- 在 UI 代码中使用:
UI.Label {
    text = "标题",
    fontSize = DA.adaptFontSize(24),
}

-- 根据设备选择不同值:
local padding = DA.pick(8, 12, 16)
local columns = DA.pick(2, 3, 4)

-- 监听屏幕变化:
function HandleUpdate(eventType, eventData)
    DA.checkResize(function(info)
        print("屏幕变化:", info.logicalW, "x", info.logicalH)
        rebuildUI()
    end)
end
```

---

## 7. 特殊场景处理

### 7.1 混合 UI 技术栈（UI 组件 + NanoVG）

当项目同时使用 UI 组件和 raw NanoVG 时：
- UI 组件部分: 按 §3 模块注入
- NanoVG 部分: 按 §4 模块注入
- **共享**: 设备分类函数只注入一次（模块 C / NV 共用）

### 7.2 多文件项目

当 `scripts/` 目录有多个 .lua 文件时：
1. 找到主入口文件（含 `Start()` 函数的文件）
2. 工具函数注入到主入口或生成独立模块 `DeviceAdapter.lua`
3. 其他文件通过 `require` 引用适配模块

### 7.3 已有 UIScaler 的旧项目

如果检测到 `require "LuaScripts/Utilities/UIScaler"`：
- UIScaler 是旧版原生 UI 的缩放组件
- 提示用户迁移到 `urhox-libs/UI` + `UI.Scale`
- 不在 UIScaler 基础上注入

### 7.4 纯 3D 游戏（无 UI）

如果未检测到任何 UI 技术栈：
- 只注入基础模块（设备分类 + 屏幕变化检测）
- 为将来可能添加的 UI 预留适配基础

---

## 8. 输出格式

向用户报告时使用以下格式：

```
## 扫描结果

**UI 技术栈**: urhox-libs/UI 组件系统
**适配级别**: L0（无适配）

| 维度 | 状态 | 操作 |
|------|------|------|
| 缩放初始化 | ❌ 缺失 | 注入 UI.Scale.DEFAULT |
| 安全区域 | ❌ 缺失 | 注入 SafeAreaView |
| 断点检测 | ❌ 缺失 | 注入 getDeviceType |
| 响应式布局 | ❌ 缺失 | 注入弹性百分比布局 |
| 字体缩放 | ❌ 缺失 | 注入 adaptFontSize |
| 屏幕变化 | ❌ 缺失 | 注入 checkScreenResize |
| DPR 处理 | ❌ 缺失 | 通过 UI.Scale.DEFAULT 处理 |

## 注入计划

将注入以下模块到 `scripts/main.lua`:
- 模块 A: 缩放初始化
- 模块 B: 安全区域包裹
- 模块 C: 断点检测
- 模块 D: 弹性百分比布局（D3）
- 模块 E: 字体缩放
- 模块 F: 屏幕变化处理

确认后开始注入。
```

---

## 9. 引用资源

| 资源 | 用途 |
|------|------|
| `references/injection-templates.md` | 完整注入代码模板（可直接复制） |
| `references/scan-patterns.md` | 扫描检测的 grep 模式和判断逻辑 |
| `engine-docs/recipes/ui.md` | UI 库完整文档 |
| `responsive-ui-adapter/SKILL.md` | 响应式布局参考方案 |
| `examples/14-ui-widgets-gallery.lua` | UI 组件完整示例 |
| `examples/09-ui-scaler-component.lua` | UIScaler 旧方案参考 |

---

## 10. 注意事项

### 10.1 不要做的事

1. **不要覆盖用户的设计意图**: 如果用户有意使用固定布局，尊重选择
2. **不要注入到已完备的项目**: L2 级别只提建议
3. **不要修改 urhox-libs/ 目录**: 只读，不可修改
4. **不要硬编码物理分辨率**: 始终使用逻辑坐标
5. **不要用裸数字作 scale**: 使用 `UI.Scale.*` 预设

### 10.2 必须做的事

1. **注入前先报告扫描结果**: 让用户确认注入计划
2. **注入后调用 build**: 验证代码正确性
3. **标记注入代码**: 使用 `[AUTO-ADAPT]` 注释标记
4. **保留用户代码**: 只添加/包裹，不删除用户逻辑
5. **处理 flexShrink**: Yoga 默认 0，CSS 默认 1，需显式设置

### 10.3 Yoga vs CSS 差异速查

| 属性 | Yoga（UrhoX） | CSS |
|------|-------------|-----|
| `flexShrink` | 默认 **0** | 默认 1 |
| `flexDirection` | 默认 **column** | 默认 row |
| box model | **border-box** | content-box |
| 百分比 | 相对父容器 | 相对父容器 |

