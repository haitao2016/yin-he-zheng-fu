# 修复代码模板库

> 每条 AD 规则的完整修复代码模板、边界条件和安全检查。
> AI 执行自动修复时，从本文档复制对应模板，替换占位符后写入用户代码。

---

## 🔧 AUTO-FIX 规则修复模板

### AD-01: 鼠标按钮数字常量 → 枚举替换

**替换映射表**:

| 数字模式 | 替换为 |
|---------|--------|
| `== 0` (鼠标按钮上下文) | `== MOUSEB_LEFT` |
| `== 1` (鼠标按钮上下文) | `== MOUSEB_MIDDLE` |
| `== 2` (鼠标按钮上下文) | `== MOUSEB_RIGHT` |
| `~= 0` (鼠标按钮上下文) | `~= MOUSEB_LEFT` |

**上下文识别**（仅在以下场景替换）:
```lua
-- 场景 1: MouseButtonDown/MouseButtonUp 事件处理函数内
-- 场景 2: 变量名含 button/btn/mouseButton
-- 场景 3: eventData["Button"]:GetInt() 的比较

-- ❌ 原代码
local button = eventData["Button"]:GetInt()
if button == 0 then  -- 左键

-- ✅ 修复后
local button = eventData["Button"]:GetInt()
if button == MOUSEB_LEFT then  -- [AD-FIX:AD-01]
```

**边界条件**:
- 不替换非鼠标上下文中的数字 0/1/2（如数组索引、数学计算）
- 判断方法：向上搜索最近的函数名，确认包含 `Mouse` 或 `Click` 关键字
- 如果上下文不明确 → 降级为 MANUAL-FLAG，不自动替换

**安全检查**: 替换前验证变量名或事件名包含鼠标相关关键字

---

### AD-02: 键盘按键数字常量 → 枚举替换

**替换映射表**（常用键）:

| 数字 | 枚举值 | 说明 |
|------|--------|------|
| 32 | `KEY_SPACE` | 空格 |
| 27 | `KEY_ESCAPE` | ESC |
| 13 | `KEY_RETURN` | 回车 |
| 9 | `KEY_TAB` | Tab |
| 8 | `KEY_BACKSPACE` | 退格 |
| 119 | `KEY_W` | W键 |
| 97 | `KEY_A` | A键 |
| 115 | `KEY_S` | S键 |
| 100 | `KEY_D` | D键 |

**上下文识别**:
```lua
-- 场景: GetKeyDown/GetKeyPress/KeyDown/KeyUp 事件

-- ❌ 原代码
if input:GetKeyDown(32) then  -- 空格

-- ✅ 修复后
if input:GetKeyDown(KEY_SPACE) then  -- [AD-FIX:AD-02]
```

**边界条件**:
- 仅在 `GetKeyDown`/`GetKeyPress`/`GetKeyUp` 参数位置替换
- 仅在 `eventData["Key"]:GetInt()` 比较位置替换
- 不替换 `GetScancodeDown` 参数（scancode 编码不同）
- 不确定的数字值 → 降级为 MANUAL-FLAG

---

### AD-03: nvgBeginFrame 缺少 DPR 处理

**修复模板（模式 B — 推荐）**:

```lua
-- ❌ 原代码
nvgBeginFrame(vg, width, height, 1.0)

-- ✅ 修复后（模式 B：逻辑坐标 + DPR 缩放）
local dpr = graphics:GetDPR()  -- [AD-FIX:AD-03]
nvgBeginFrame(vg, width / dpr, height / dpr, dpr)  -- [AD-FIX:AD-03]
```

**修复策略**:

1. 检查函数/文件顶部是否已有 `local dpr = graphics:GetDPR()`
2. 如果已有 → 只修改 `nvgBeginFrame` 调用
3. 如果没有 → 在 `nvgBeginFrame` 前一行插入 `dpr` 获取代码
4. 同时修复同一函数内所有 `nvgBeginFrame` 调用

**变体检测**:

| 原始代码 | 修复方式 |
|---------|---------|
| `nvgBeginFrame(vg, w, h, 1.0)` | → `nvgBeginFrame(vg, w/dpr, h/dpr, dpr)` |
| `nvgBeginFrame(vg, w, h, 1)` | → `nvgBeginFrame(vg, w/dpr, h/dpr, dpr)` |
| `nvgBeginFrame(vg, 1920, 1080, 1.0)` | → 同时触发 AD-08，改用动态宽高 |
| `nvgBeginFrame(vg, w, h, ratio)` | ratio 不是 1.0 → 可能已处理，标记 MANUAL |

**边界条件**:
- 第 4 参数已是 `dpr` 或 `graphics:GetDPR()` → 跳过
- 第 4 参数是非 1.0 的变量 → 降级 MANUAL（可能已有自定义处理）
- 同一作用域已声明 `dpr` → 不重复声明

---

### AD-07: graphics:SetMode() 调用（已禁用 API）

**修复模板**:

```lua
-- ❌ 原代码
graphics:SetMode(1920, 1080, ...)

-- ✅ 修复后
-- [AD-FIX:AD-07] graphics:SetMode() 在 UrhoX 中已禁用，使用以下 API 获取屏幕信息：
local physW, physH = graphics:GetWidth(), graphics:GetHeight()
local dpr = graphics:GetDPR()
local logicalW, logicalH = physW / dpr, physH / dpr
```

**修复策略**:

1. 注释掉 `SetMode` 调用行（不删除，保留注释说明）
2. 在注释后插入替代代码
3. 搜索文件中使用 SetMode 参数值的地方，替换为动态获取

**边界条件**:
- 如果 SetMode 返回值被使用 → 降级 MANUAL（极罕见）
- 如果 SetMode 在条件分支中 → 整个分支可能需要重构 → MANUAL

---

### AD-08: nvgBeginFrame 使用硬编码分辨率

**修复模板**:

```lua
-- ❌ 原代码
nvgBeginFrame(vg, 1920, 1080, 1.0)
-- 或
nvgBeginFrame(vg, 1280, 720, 1.0)

-- ✅ 修复后
local physW, physH = graphics:GetWidth(), graphics:GetHeight()  -- [AD-FIX:AD-08]
local dpr = graphics:GetDPR()  -- [AD-FIX:AD-08]
nvgBeginFrame(vg, physW / dpr, physH / dpr, dpr)  -- [AD-FIX:AD-08]
```

**常见硬编码分辨率**:
- 1920, 1080 (1080P)
- 1280, 720 (720P)
- 800, 600 (SVGA)
- 960, 540 (qHD)

**修复策略**:
1. 匹配 `nvgBeginFrame(vg, NUMBER, NUMBER, ...)` 模式
2. 替换前两个数字参数为动态获取
3. 同时修复第 4 参数的 DPR 问题（合并 AD-03）
4. 检查同一作用域是否已有 `GetWidth()`/`GetHeight()` 变量

**边界条件**:
- 硬编码数字是设计分辨率（模式 A 项目）→ 保留但提示用户确认
- 识别方法：如果周围代码有 `UIScaler` 或 `DESIGN_WIDTH` 常量 → 可能是模式 A → MANUAL

---

### AD-09: UI.Init 缺少 scale 参数

**修复模板**:

```lua
-- ❌ 原代码
UI.Init({
    fonts = { ... }
})

-- ✅ 修复后
UI.Init({
    fonts = { ... },
    scale = UI.Scale.DEFAULT,  -- [AD-FIX:AD-09] DPR 自适应缩放
})
```

**修复策略**:
1. 定位 `UI.Init({` 调用
2. 检查参数表内是否已有 `scale` 字段
3. 如果没有 → 在最后一个字段后添加 `scale = UI.Scale.DEFAULT,`
4. 如果已有但值不是 `UI.Scale.DEFAULT` → 标记 MANUAL（用户有自定义设置）

**边界条件**:
- `UI.Init()` 无参数调用 → 改为 `UI.Init({ scale = UI.Scale.DEFAULT })`
- 已有 `scale = UI.Scale.FIXED(...)` → 跳过（用户已明确设计分辨率）
- 已有 `scale = some_variable` → 跳过

---

### AD-19: nvgCreateFont 在渲染循环中调用（显存泄漏）

**修复模板**:

```lua
-- ❌ 原代码（在 HandleNanoVGRender 或 HandleUpdate 中）
function HandleNanoVGRender(eventType, eventData)
    local font = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    nvgFontFace(vg, "sans")
    nvgText(vg, 100, 100, "Hello")
end

-- ✅ 修复后（提取到文件顶层/Start函数）
local fontNormal  -- [AD-FIX:AD-19] 字体句柄提升到全局/模块层

function Start()
    -- ... 其他初始化 ...
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")  -- [AD-FIX:AD-19]
end

function HandleNanoVGRender(eventType, eventData)
    nvgFontFace(vg, "sans")
    nvgText(vg, 100, 100, "Hello")
end
```

**修复策略**:
1. 在渲染/更新函数内搜索 `nvgCreateFont`
2. 提取调用到 `Start()` 函数（如无 Start → 创建）
3. 将返回值赋给模块级变量
4. 从循环函数内删除 `nvgCreateFont` 行

**边界条件**:
- `nvgCreateFont` 在 `Start()` / 文件顶层 / `init` 函数中 → 安全，跳过
- `nvgCreateFont` 在 `if` 条件内（条件只执行一次）→ 可能安全 → MANUAL
- 多个渲染函数各自创建字体 → 全部提取到 Start

---

## 🔍 MANUAL-FLAG 规则修复建议

以下规则不自动修复，AI 输出修复建议供用户确认。

### AD-04: MM_RELATIVE 缺少 Web 平台处理

**建议代码**:
```lua
-- 建议：为 Web 平台添加 Pointer Lock 恢复 UI
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

if PlatformUtils.IsWebPlatform() then
    -- Web 上 ESC 会强制退出 Pointer Lock
    -- 需要点击画布重新锁定
    SubscribeToEvent("MouseButtonDown", function(eventType, eventData)
        if not input.mouseGrabbed then
            input.mouseMode = MM_RELATIVE  -- 重新锁定
        end
    end)
end
```

**诊断提示**: "检测到使用 MM_RELATIVE，但未处理 Web 平台 Pointer Lock 退出。Web 上按 ESC 会强制解锁鼠标，需要添加重新锁定逻辑。"

---

### AD-05: 触摸坐标未除以 DPR

**建议代码**:
```lua
-- 建议：触摸坐标需要除以 DPR 转换为逻辑坐标
local dpr = graphics:GetDPR()
local touchX = eventData["X"]:GetInt() / dpr
local touchY = eventData["Y"]:GetInt() / dpr
```

**诊断提示**: "检测到直接使用触摸坐标而未除以 DPR。在高 DPI 屏幕上，触摸坐标是物理像素，需要转换为逻辑坐标。"

---

### AD-06: Hover 交互无触摸回退

**建议代码**:
```lua
-- 建议：移动端无 hover，用 press+hold 替代
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

if PlatformUtils.IsMobilePlatform() then
    -- 移动端：长按显示 tooltip
    SubscribeToEvent("TouchBegin", HandleTouchTooltip)
else
    -- 桌面端：保持 hover
    SubscribeToEvent("MouseMove", HandleHoverTooltip)
end
```

**诊断提示**: "检测到 hover 交互（鼠标悬停事件），但移动端不支持 hover。建议为移动端提供替代交互方式（长按、点击展开等）。"

---

### AD-10: UI 根节点缺少 SafeAreaView

**建议代码**:
```lua
-- 建议：用 SafeAreaView 包裹 UI 根节点
local UI = require("urhox-libs/UI")

local root = UI.SafeAreaView {
    edges = "all",  -- 或 {"top", "bottom"} 按需选择
    children = {
        -- 原有的根节点内容移到这里
        UI.Panel { ... }
    }
}
UI.SetRoot(root)
```

**诊断提示**: "UI 根节点未使用 SafeAreaView 包裹。在刘海屏/圆角屏设备上，UI 内容可能被遮挡。建议用 SafeAreaView 包裹最外层 UI。"

---

### AD-11: 交互元素尺寸过小

**诊断提示**: "发现交互元素尺寸可能小于 44x44 逻辑点（Apple HIG 标准）。在移动设备上，过小的按钮/触控区域会导致难以点击。建议最小尺寸 44x44。"

**检测位置**: UI.Button/可点击元素的 width/height 属性，NanoVG 绘制的触控区域

---

### AD-12: Yoga flexShrink 导致子元素溢出

**建议代码**:
```lua
-- Yoga 默认 flexShrink = 0（与 CSS 不同）
-- 当子元素总尺寸超过容器时不会自动收缩

-- 建议：对需要自适应的子元素设置 flexShrink
UI.Panel {
    flexDirection = "row",
    children = {
        UI.Label { text = "长文本...", flexShrink = 1 },  -- 允许收缩
        UI.Button { text = "OK", width = 80 },             -- 固定宽度
    }
}
```

---

### AD-13: 字号过小

**诊断提示**: "检测到字号 < 12px。在移动设备上，小于 12px 的文字几乎不可读。建议正文最小 14px，标题最小 18px。"

---

### AD-14: 键盘游戏缺少移动端控件

**建议代码**（方案 A — GameHUD）:
```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
local GameHUD = require "urhox-libs.UI.GameHUD"

if PlatformUtils.IsMobilePlatform() then
    local hud = GameHUD.Create({
        joystick = true,
        buttons = {
            { label = "Jump", action = "jump" },
            { label = "Attack", action = "attack" },
        }
    })
end
```

**建议代码**（方案 B — VirtualControls）:
```lua
local VirtualControls = require "urhox-libs.UI.VirtualControls"

local vc = VirtualControls.Create({
    joystick = { position = "bottom-left" },
    buttons = {
        { label = "A", key = KEY_SPACE, position = "bottom-right" },
    }
})
```

---

### AD-15: 鼠标模式游戏无移动端视角控制

**建议代码**:
```lua
-- 建议：移动端用触摸区域替代鼠标视角控制
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

if PlatformUtils.IsMobilePlatform() then
    -- 右半屏幕拖拽 → 视角旋转
    SubscribeToEvent("TouchMove", function(eventType, eventData)
        local dx = eventData["DX"]:GetInt()
        local dy = eventData["DY"]:GetInt()
        yaw = yaw + dx * 0.15
        pitch = pitch + dy * 0.15
    end)
end
```

---

### AD-16: Web 平台音频自动播放被阻止

**建议代码**:
```lua
-- 建议：Web 平台需要用户交互后才能播放音频
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

if PlatformUtils.IsWebPlatform() then
    -- 第一次点击时才初始化音频
    local audioResumed = false
    SubscribeToEvent("MouseButtonDown", function()
        if not audioResumed then
            audio:Resume()  -- 恢复 AudioContext
            audioResumed = true
        end
    end)
end
```

---

### AD-17: 屏幕旋转/窗口缩放后布局未更新

**建议代码**:
```lua
-- 建议：监听 ScreenMode 事件，更新布局参数
SubscribeToEvent("ScreenMode", function(eventType, eventData)
    local newW = eventData["Width"]:GetInt()
    local newH = eventData["Height"]:GetInt()
    -- 重新计算布局相关变量
    screenWidth = newW
    screenHeight = newH
    -- 刷新 UI
    if uiRoot then
        uiRoot:SetSize(newW, newH)
    end
end)
```

---

### AD-18: 无平台条件分支的输入代码

**诊断提示**: "检测到使用键盘/鼠标输入但无平台检测分支。建议添加 PlatformUtils.IsMobilePlatform() 判断，为移动端提供触摸控制替代方案。"

---

### AD-20: 缺少性能分级

**建议代码**:
```lua
-- 建议：根据设备能力调整渲染质量
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

local quality = "high"
if PlatformUtils.IsMobilePlatform() then
    local w = graphics:GetWidth()
    if w < 1080 then
        quality = "low"
    elseif w < 1920 then
        quality = "medium"
    end
end

-- 根据 quality 调整渲染参数
if quality == "low" then
    renderer.shadowMapSize = 512
    renderer.shadowQuality = SHADOWQUALITY_SIMPLE_16BIT
elseif quality == "medium" then
    renderer.shadowMapSize = 1024
    renderer.shadowQuality = SHADOWQUALITY_PCF_16BIT
else
    renderer.shadowMapSize = 2048
    renderer.shadowQuality = SHADOWQUALITY_PCF_24BIT
end
```

---

## 通用修复注意事项

### 自动修复安全守则

1. **只修改单行或相邻几行** — 不重构函数结构
2. **保留原始缩进** — 匹配周围代码风格
3. **添加标记注释** — 所有修复行尾添加 `-- [AD-FIX:AD-XX]`
4. **不删除用户代码** — 只注释或替换
5. **不确定就降级** — 任何存疑的修复 → 改为 MANUAL-FLAG

### 修复顺序

1. 先修复 AD-07（SetMode 禁用）→ 影响后续分辨率相关修复
2. 再修复 AD-03/AD-08（NanoVG DPR）→ 可能合并为一次修改
3. 最后修复 AD-01/AD-02（枚举替换）→ 最安全，独立于其他修复
4. AD-09/AD-19 顺序无关 → 随时修复

### 冲突处理

| 规则冲突 | 处理方式 |
|---------|---------|
| AD-03 + AD-08 同时触发 | 合并修复：替换硬编码 + 加 DPR |
| AD-07 + AD-08 同时触发 | 先注释 SetMode (AD-07)，再修 BeginFrame (AD-08) |
| AD-01 + game-bug-checker H3 同时修复 | 结果相同，不冲突 |

