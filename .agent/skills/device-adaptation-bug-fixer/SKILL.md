---
name: device-adaptation-bug-fixer
description: |
  全设备适配 BUG 自动检测与修复系统。扫描 scripts/ 目录中的 Lua 游戏代码，
  自动识别 20 类跨设备适配缺陷（输入/分辨率/UI 布局/安全区/性能/平台兼容），
  将可自动修复的 BUG 直接修补，需人工确认的 BUG 生成诊断报告并附修复建议。
  覆盖从"手机无法操控"到"高 DPI 屏幕 UI 错乱"的完整适配问题闭环。
  Use when users need to (1) 检查游戏是否在所有设备上可玩,
  (2) 修复手机上无法操控的问题,
  (3) 修复高 DPI 屏幕上 UI 错乱/过小的问题,
  (4) 修复 NanoVG 在 Retina 屏上显示异常,
  (5) 修复 Web 平台鼠标锁定/音频自动播放问题,
  (6) 检查触摸按钮尺寸是否符合规范,
  (7) 检查是否缺少虚拟摇杆或触控按钮,
  (8) 检查安全区域(刘海屏)是否被遮挡,
  (9) 用户说"适配检查""设备兼容""跨端BUG""手机上玩不了",
  (10) 游戏在 PC 正常但手机上出问题。
  MUST trigger when: 用户要求检查或修复游戏的设备适配/跨端兼容性问题。
  trigger-keywords:
    - 适配检查
    - 适配BUG
    - 设备兼容
    - 跨端BUG
    - 手机适配
    - 全平台检查
    - 触控适配
    - DPI适配
    - 安全区检查
    - 刘海屏
    - 分辨率适配
    - 输入适配
    - 设备BUG
    - 兼容性检查
    - 移动端BUG
    - PC适配
    - Web适配
    - 自动修复适配
version: "1.0.0"
metadata:
  category: "quality-assurance"
  complexity: "advanced"
  estimated_tokens: 4000
---

# 全设备适配 BUG 自动检测与修复

## 概述

本 Skill 对 `scripts/` 目录中的 UrhoX Lua 游戏代码执行全面的设备适配扫描，
覆盖 **6 大类 20 种**跨设备适配缺陷，分为**可自动修复**和**需人工确认**两级。

与 `game-bug-checker` Skill 的区别：
- `game-bug-checker`：聚焦引擎 API 误用（eventData、数组索引、碰撞体等）
- `device-adaptation-bug-fixer`：聚焦**跨设备可玩性**（输入、分辨率、UI、安全区等）

两者互补，不重叠。

---

## 执行流程

```
SCAN → CLASSIFY → FIX/FLAG → REPORT
  │        │          │          │
  │        │          │          └─ 输出诊断报告 + 修复统计
  │        │          └─ 自动修复 / 生成修复建议
  │        └─ 按严重度分类 (CRITICAL / HIGH / MEDIUM / LOW)
  └─ grep/静态分析扫描 scripts/*.lua
```

### 步骤 1: SCAN — 扫描代码

对 `scripts/` 下所有 `.lua` 文件执行以下 grep/静态分析：

```bash
# 准备：收集所有待扫描文件
SCRIPTS=$(find scripts/ -name "*.lua" -type f)
```

### 步骤 2: CLASSIFY — 按 6 大类分类

按下方「BUG 检测规则库」的 20 条规则逐一检测。

### 步骤 3: FIX/FLAG — 自动修复或标记

- **AUTO-FIX（🔧）**: 直接编辑代码修复，修复前备份原行到注释
- **MANUAL-FLAG（🔍）**: 输出警告 + 推荐修复代码，等待用户确认

### 步骤 4: REPORT — 输出诊断报告

```
══════════════════════════════════════
  设备适配扫描报告
══════════════════════════════════════
扫描文件: N 个
发现问题: M 个 (X 个已自动修复, Y 个需人工确认)

🔧 已自动修复:
  [AD-03] main.lua:42 — nvgBeginFrame 缺少 DPR 处理 → 已修复
  [AD-01] game.lua:15 — 鼠标按钮使用数字常量 → 已替换为枚举

🔍 需人工确认:
  [AD-07] main.lua — 未检测到虚拟摇杆/触控按钮（移动端可能无法操控）
    → 建议: 添加 GameHUD 或 VirtualControls（见修复代码）
  [AD-10] ui.lua — UI.SetRoot 未包裹 SafeAreaView（刘海屏可能遮挡）
    → 建议: 用 SafeAreaView 包裹根 UI

✅ 通过项:
  [AD-02] 键盘枚举使用正确
  [AD-05] UI.Init 已设置 scale
  ...
══════════════════════════════════════
```

---

## BUG 检测规则库（6 大类 20 条）

### 第一类：输入适配（AD-01 ~ AD-06）

#### AD-01 鼠标按钮使用数字常量 🔧 AUTO-FIX

**严重度**: HIGH
**检测**:
```bash
grep -rn 'button == [0-9]\|button ~= [0-9]\|button > [0-9]\|button < [0-9]' scripts/
```

**症状**: 鼠标点击检测失败，`MOUSEB_LEFT` 不保证等于 0。

**自动修复**:
```lua
-- ❌ 修复前
if button == 0 then  -- 左键
if button == 1 then  -- 中键
if button == 2 then  -- 右键

-- ✅ 修复后
if button == MOUSEB_LEFT then
if button == MOUSEB_MIDDLE then
if button == MOUSEB_RIGHT then
```

**映射表**: `0 → MOUSEB_LEFT`, `1 → MOUSEB_MIDDLE`, `2 → MOUSEB_RIGHT`

---

#### AD-02 键盘按键使用数字常量 🔧 AUTO-FIX

**严重度**: HIGH
**检测**:
```bash
grep -rn 'GetKeyDown([0-9]\|GetKeyPress([0-9]\|key == [0-9]' scripts/
```

**自动修复**: 使用常见 keycode 映射表替换：
- `32 → KEY_SPACE`, `27 → KEY_ESCAPE`, `13 → KEY_RETURN`
- `87 → KEY_W`, `65 → KEY_A`, `83 → KEY_S`, `68 → KEY_D`

---

#### AD-03 NanoVG BeginFrame 缺少 DPR 处理 🔧 AUTO-FIX

**严重度**: HIGH
**检测**:
```bash
# 查找 nvgBeginFrame 调用中最后一个参数为 1.0 的情况
grep -rn 'nvgBeginFrame.*,\s*1\.0\s*)' scripts/

# 或者 nvgBeginFrame 但文件中没有 GetDPR
grep -rln 'nvgBeginFrame' scripts/ | xargs grep -L 'GetDPR' 2>/dev/null
```

**症状**: 高 DPI 屏幕上 NanoVG 内容缩小到左下角 1/4，文字模糊。

**自动修复**:
```lua
-- ❌ 修复前
nvgBeginFrame(vg, w, h, 1.0)

-- ✅ 修复后（模式 B：系统逻辑分辨率，推荐默认）
local dpr = graphics:GetDPR()
local logW, logH = w / dpr, h / dpr
nvgBeginFrame(vg, logW, logH, dpr)
```

**修复步骤**:
1. 在文件顶部或初始化处添加 `local dpr = graphics:GetDPR()`
2. 若 `w`/`h` 来自 `graphics:GetWidth()`/`GetHeight()`，在 `nvgBeginFrame` 前除以 `dpr`
3. 将第三参数从 `1.0` 改为 `dpr`
4. **同时检查**该文件中所有 NanoVG 坐标/尺寸是否也需要除以 DPR

---

#### AD-04 MM_RELATIVE 缺少 Web 平台处理 🔍 MANUAL

**严重度**: MEDIUM
**检测**:
```bash
# 使用 MM_RELATIVE 但没有用 SampleInitMouseMode 也没有平台检查
grep -rln 'mouseMode\s*=\s*MM_RELATIVE' scripts/ \
  | xargs grep -L 'SampleInitMouseMode\|IsWebPlatform\|MouseModeChanged' 2>/dev/null
```

**症状**: Web 平台上 ESC 退出 Pointer Lock 后无法恢复，游戏卡死。

**修复建议**:
```lua
-- 方案 A（推荐）：使用 Sample 工具函数自动处理
require "LuaScripts/Utilities/Sample"
SampleInitMouseMode(MM_RELATIVE)

-- 方案 B：手动处理
input.mouseMode = MM_RELATIVE
if PlatformUtils.IsWebPlatform() then
    SubscribeToEvent("MouseModeChanged", function(_, ed)
        local locked = ed["MouseLocked"]:GetBool()
        if not locked then showRelockPrompt() end
    end)
end
```

---

#### AD-05 触摸坐标未除以 DPR 🔍 MANUAL

**严重度**: HIGH
**检测**:
```bash
# 使用 GetTouch 但同文件没有 DPR 处理
grep -rln 'GetTouch\|touch\.position\|touchState' scripts/ \
  | xargs grep -L 'GetDPR\|dpr\|DPR' 2>/dev/null
```

**症状**: 高 DPI 设备上触摸位置偏移 2-3 倍，点击不准。

**修复建议**:
```lua
-- 触摸坐标是物理像素，需转为逻辑坐标
local dpr = graphics:GetDPR()
local tx = touch.position.x / dpr
local ty = touch.position.y / dpr
```

**判断条件**: 仅在代码使用逻辑坐标系（NanoVG 模式 B、UI 组件）时需要修复。
如果整个渲染管线使用物理像素（模式 C），则不需要。

---

#### AD-06 Hover 交互无触摸回退 🔍 MANUAL

**严重度**: MEDIUM
**检测**:
```bash
# 自定义 hover 逻辑（非 UI 组件的）
grep -rn 'hover\|isHover\|onHover\|mouseOver' scripts/ \
  | grep -v 'urhox-libs\|--.*hover'
```

**症状**: 移动设备上没有 hover 状态，依赖 hover 的交互完全失效。

**修复建议**: 将 hover 效果改为 press/active 状态，或添加触摸替代方案。

---

### 第二类：分辨率/DPR 适配（AD-07 ~ AD-09）

#### AD-07 调用 graphics:SetMode()（已禁用 API）🔧 AUTO-FIX

**严重度**: MEDIUM
**检测**:
```bash
grep -rn 'graphics:SetMode\|graphics\.SetMode' scripts/
```

**自动修复**: 删除 `SetMode` 调用，替换为分辨率查询：
```lua
-- ❌ 删除
graphics:SetMode(1920, 1080, false, false, false, false, false, 1)

-- ✅ 替换为
local w = graphics:GetWidth()
local h = graphics:GetHeight()
local dpr = graphics:GetDPR()
```

---

#### AD-08 nvgBeginFrame 使用硬编码分辨率 🔧 AUTO-FIX

**严重度**: HIGH
**检测**:
```bash
# nvgBeginFrame 参数中出现大于 100 的数字常量（疑似硬编码分辨率）
grep -rnP 'nvgBeginFrame\s*\(.*\b[1-9][0-9]{2,}\b' scripts/
```

**症状**: NanoVG 只在特定分辨率下正确显示，其他设备上内容裁剪或缩放。

**自动修复**:
```lua
-- ❌ 修复前
nvgBeginFrame(vg, 1920, 1080, 1.0)

-- ✅ 修复后
local physW = graphics:GetWidth()
local physH = graphics:GetHeight()
local dpr = graphics:GetDPR()
nvgBeginFrame(vg, physW / dpr, physH / dpr, dpr)
```

---

#### AD-09 UI.Init 缺少 scale 参数 🔧 AUTO-FIX

**严重度**: MEDIUM
**检测**:
```bash
# UI.Init 调用中没有 scale 字段
grep -rn 'UI\.Init\s*(' scripts/ | grep -v 'scale'
```

**症状**: 不同 DPR 设备上 UI 元素大小不一致。

**自动修复**: 在 `UI.Init` 参数表中添加 `scale = UI.Scale.DEFAULT`：
```lua
-- ❌ 修复前
UI.Init({
    fonts = { ... },
})

-- ✅ 修复后
UI.Init({
    fonts = { ... },
    scale = UI.Scale.DEFAULT,
})
```

---

### 第三类：UI 布局适配（AD-10 ~ AD-13）

#### AD-10 UI 根节点缺少 SafeAreaView 🔍 MANUAL

**严重度**: MEDIUM
**检测**:
```bash
# 使用 UI.SetRoot 但整个文件没有 SafeAreaView
grep -rln 'UI\.SetRoot\|UI.SetRoot' scripts/ \
  | xargs grep -L 'SafeAreaView' 2>/dev/null
```

**症状**: 刘海屏/圆角屏设备上关键 UI 被遮挡。

**修复建议**:
```lua
-- 用 SafeAreaView 包裹根 UI
UI.SetRoot(
    UI.SafeAreaView({
        edges = "all",
        width = "100%", height = "100%",
        children = { --[[ 原有根内容 ]] }
    })
)
```

---

#### AD-11 交互元素尺寸过小（触摸不友好）🔍 MANUAL

**严重度**: MEDIUM
**检测**:
```bash
# 按钮/可交互元素宽高 < 36（低于 Apple HIG 44pt 推荐）
grep -rnP '(Button|Touchable).*width\s*=\s*[12][0-9]\b' scripts/
grep -rnP '(Button|Touchable).*height\s*=\s*[12][0-9]\b' scripts/
```

**症状**: 手机上按钮太小，用户难以准确点击。

**修复建议**: 交互元素最小尺寸不低于 44（逻辑像素），推荐 48。

---

#### AD-12 Yoga flexShrink 导致子元素溢出 🔍 MANUAL

**严重度**: MEDIUM
**检测**:
```bash
# ScrollView 或受限容器的子元素使用 flex=1 但没有 flexBasis=0
grep -rn 'ScrollView' scripts/ -A 10 | grep 'flex = 1' | grep -v 'flexBasis'

# 或有固定宽高子元素在 flex 容器中
grep -rn 'flex = 1' scripts/ | grep -v 'flexShrink\|flexBasis'
```

**症状**: 子元素超出容器边界，内容被裁剪或溢出可见区域。

**修复建议**:
```lua
-- ScrollView 子内容必须同时设置 flex 和 flexBasis
UI.ScrollView({
    flex = 1, flexBasis = 0,  -- 两者缺一不可
    children = { ... }
})
```

---

#### AD-13 字号过小（移动端不可读）🔍 MANUAL

**严重度**: LOW
**检测**:
```bash
# fontSize 小于 12 的元素
grep -rnP 'fontSize\s*=\s*([1-9]|1[01])\b' scripts/
```

**症状**: 手机上文字过小，用户无法阅读。

**修复建议**: 移动端最小字号 ≥ 12 逻辑像素，推荐正文 14-16。

---

### 第四类：输入可玩性（AD-14 ~ AD-15）

#### AD-14 键盘游戏缺少移动端控件 🔍 MANUAL

**严重度**: CRITICAL
**检测**:
```bash
# 使用键盘输入但没有任何触摸/摇杆/手柄方案
grep -rln 'GetKeyDown\|GetKeyPress' scripts/ \
  | xargs grep -L 'GameHUD\|VirtualControls\|InputManager\|GetTouch\|GetNumTouches\|IsTouchSupported\|IsMobilePlatform\|onPointerDown\|onSwipe' 2>/dev/null
```

**症状**: 移动设备上完全无法操控，游戏不可玩。

**修复建议**:
```lua
-- 方案 A：使用 GameHUD（3D 角色游戏推荐）
local UI = require("urhox-libs/UI")
local hud = UI.GameHUD({
    joystick = { side = "left" },
    buttons = {
        { label = "Jump", side = "right", keyBinding = "SPACE",
          onClick = function() doJump() end },
    },
})

-- 方案 B：使用 VirtualControls（自定义外观）
require "urhox-libs.UI.VirtualControls"
VirtualControls.CreateJoystick({ position = Vector2(200, -200), alignment = {HA_LEFT, VA_BOTTOM} })
VirtualControls.Initialize()

-- 方案 C：使用 UI 组件触摸按钮（2D/休闲游戏）
UI.Button({
    text = "←", width = 64, height = 64,
    onPointerDown = function() moveLeft = true end,
    onPointerUp   = function() moveLeft = false end,
})
```

---

#### AD-15 鼠标模式游戏无移动端视角控制 🔍 MANUAL

**严重度**: HIGH
**检测**:
```bash
# 使用 GetMouseMove 做视角控制但没有触摸替代
grep -rln 'GetMouseMove\|mouseMoveX\|mouseMoveY' scripts/ \
  | xargs grep -L 'GetTouch\|GameHUD\|VirtualControls\|TouchLookArea' 2>/dev/null
```

**症状**: 移动端无法转动视角，只能看固定方向。

**修复建议**: 使用 `GameHUD`（内置触摸视角区域）或 `VirtualControls` 的 `TouchLookArea`。

---

### 第五类：平台特定问题（AD-16 ~ AD-18）

#### AD-16 Web 平台音频自动播放被阻止 🔍 MANUAL

**严重度**: LOW
**检测**:
```bash
# Start() 函数中直接播放音频
awk '/function Start/,/^end/' scripts/*.lua 2>/dev/null \
  | grep -n 'PlaySound\|Play()\|PlayMusic\|:Play'
```

**症状**: Web 浏览器阻止自动播放，背景音乐在首次用户交互前静音。

**修复建议**: 延迟到用户首次点击/触摸后再播放音频，或使用引擎内置的音频恢复机制。

---

#### AD-17 屏幕旋转/窗口缩放后布局未更新 🔍 MANUAL

**严重度**: LOW
**检测**:
```bash
# 缓存了屏幕尺寸但没有更新逻辑
grep -rn 'local.*screenW\|local.*screenH\|local.*SCREEN_W\|local.*SCREEN_H' scripts/ \
  | grep -v 'function\|Update\|每帧'
```

**症状**: 旋转设备或调整窗口大小后，UI 停留在旧布局。

**修复建议**:
```lua
-- 方案 A：每帧重新读取（简单）
function HandleUpdate(eventType, eventData)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    -- 使用 w, h 计算布局
end

-- 方案 B：监听 ScreenMode 事件
SubscribeToEvent("ScreenMode", function(_, ed)
    local w = ed["Width"]:GetInt()
    local h = ed["Height"]:GetInt()
    rebuildLayout(w, h)
end)
```

---

#### AD-18 无平台条件分支的输入代码 🔍 MANUAL

**严重度**: MEDIUM
**检测**:
```bash
# 使用鼠标特定功能但没有平台检测
grep -rln 'GetMouseButton\|mouseMode\|MM_RELATIVE\|GetMouseMove' scripts/ \
  | xargs grep -L 'IsMobilePlatform\|IsTouchSupported\|PlatformUtils\|GetPlatform\|isMobile\|isDesktop' 2>/dev/null
```

**症状**: 代码假定鼠标始终可用，移动端运行异常或报错。

**修复建议**:
```lua
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"
if PlatformUtils.IsMobilePlatform() then
    -- 触摸输入方案
else
    -- 鼠标/键盘输入方案
end
```

---

### 第六类：性能适配（AD-19 ~ AD-20）

#### AD-19 nvgCreateFont 在渲染循环中调用（显存泄漏）🔧 AUTO-FIX

**严重度**: HIGH
**检测**:
```bash
# nvgCreateFont 出现在 NanoVGRender 事件处理函数或 Update 函数中
awk '/function Handle.*Render\|function Handle.*Update/,/^end/' scripts/*.lua 2>/dev/null \
  | grep -n 'nvgCreateFont'

# 简化检测：nvgCreateFont 不在 Start/Init 函数中
grep -rn 'nvgCreateFont' scripts/ | grep -vi 'start\|init\|setup\|create.*font.*once'
```

**症状**: VRAM 持续增长，游戏逐渐变卡直到崩溃。

**自动修复**: 将 `nvgCreateFont` 移到 `Start()` 函数或文件顶层，存入模块变量。

---

#### AD-20 缺少性能分级（低端设备卡顿）🔍 MANUAL

**严重度**: LOW
**检测**:
```bash
# 使用高级渲染特性但没有分级逻辑
grep -rln 'shadowMapSize\|drawShadows\|SetNumViewports\|bloom\|HDR' scripts/ \
  | xargs grep -L 'performance\|tier\|quality\|low.*end\|high.*end' 2>/dev/null
```

**症状**: 低端设备帧率低于 30fps，游戏体验差。

**修复建议**:
```lua
local function getPerformanceTier()
    local pixels = graphics:GetWidth() * graphics:GetHeight()
    if pixels <= 921600 then return "low"       -- ≤ 720p
    elseif pixels <= 2073600 then return "medium" -- ≤ 1080p
    else return "high" end
end

local tier = getPerformanceTier()
renderer.drawShadows = (tier ~= "low")
renderer.shadowMapSize = ({ low = 512, medium = 1024, high = 2048 })[tier]
```

---

## 执行优先级

按以下顺序扫描，确保最关键的问题先被发现：

```
CRITICAL（游戏不可玩）:
  AD-14 键盘游戏缺少移动端控件
  AD-15 鼠标视角游戏无触摸替代

HIGH（功能严重受损）:
  AD-01 鼠标按钮数字常量        🔧
  AD-02 键盘按键数字常量        🔧
  AD-03 NanoVG BeginFrame 无 DPR 🔧
  AD-05 触摸坐标未除 DPR
  AD-08 nvgBeginFrame 硬编码分辨率 🔧
  AD-19 nvgCreateFont 每帧调用   🔧

MEDIUM（体验受损）:
  AD-04 MM_RELATIVE 无 Web 处理
  AD-06 Hover 无触摸回退
  AD-07 SetMode 已禁用 API      🔧
  AD-09 UI.Init 无 scale         🔧
  AD-10 缺少 SafeAreaView
  AD-11 触摸元素尺寸过小
  AD-12 flexShrink 溢出
  AD-18 无平台条件分支

LOW（可改善）:
  AD-13 字号过小
  AD-16 Web 音频自动播放
  AD-17 屏幕旋转布局未更新
  AD-20 缺少性能分级
```

---

## 自动修复安全策略

### 修复前确认

1. **仅修改 `scripts/` 目录**下的用户代码
2. **不修改** `urhox-libs/`、`engine-docs/`、`examples/` 等引擎目录
3. 每次修复前向用户展示**修复前后对比**
4. 批量修复时先列出所有修改点，用户确认后再执行

### 修复标记

在修复的行上方添加注释标记，方便用户追踪：
```lua
-- [AD-FIX:AD-03] NanoVG DPR 适配修复
local dpr = graphics:GetDPR()
nvgBeginFrame(vg, physW / dpr, physH / dpr, dpr)
```

### 不可修复的判定

以下情况标记为 SKIP，不尝试修复：
- 代码在注释中（`--` 开头的行）
- 代码在字符串常量中
- 无法确定变量含义（如 `button` 不确定是否来自鼠标事件）
- 修复会改变非适配相关的行为

---

## 与 game-bug-checker 的分工

| 检测项 | game-bug-checker | device-adaptation-bug-fixer |
|-------|-----------------|---------------------------|
| eventData 语法 | ✅ C3 | — |
| 数组索引从 0 开始 | ✅ H1 | — |
| Unicode 转义 | ✅ H2 | — |
| 鼠标/键盘枚举 | ✅ H3 | ✅ AD-01/02（重复覆盖，无冲突） |
| SetMode 已禁用 | ✅ M4 | ✅ AD-07（重复覆盖，无冲突） |
| nvgCreateFont 泄漏 | ✅ M5 | ✅ AD-19（重复覆盖，无冲突） |
| NanoVG DPR 处理 | — | ✅ AD-03/08 |
| 触摸坐标 DPR | — | ✅ AD-05 |
| Web Pointer Lock | — | ✅ AD-04 |
| 缺少虚拟摇杆 | — | ✅ AD-14 |
| SafeAreaView | — | ✅ AD-10 |
| UI Scale 设置 | — | ✅ AD-09 |
| 触摸尺寸规范 | — | ✅ AD-11 |
| 性能分级 | — | ✅ AD-20 |

两个 Skill **可同时运行**。重复覆盖的 3 项（AD-01/02, AD-07, AD-19）检测规则一致，
修复策略一致，不会产生冲突。

---

## 完整扫描脚本模板

AI 在执行本 Skill 时，按以下模板扫描：

```bash
#\!/bin/bash
# === 设备适配 BUG 全量扫描 ===
DIR="scripts"

echo "=== AD-01: 鼠标按钮数字常量 ==="
grep -rn 'button == [0-9]\|button ~= [0-9]\|button > [0-9]\|button < [0-9]' "$DIR/" 2>/dev/null

echo "=== AD-02: 键盘按键数字常量 ==="
grep -rn 'GetKeyDown([0-9]\|GetKeyPress([0-9]\|key == [0-9]' "$DIR/" 2>/dev/null

echo "=== AD-03: nvgBeginFrame 无 DPR ==="
grep -rln 'nvgBeginFrame' "$DIR/" 2>/dev/null | xargs grep -L 'GetDPR' 2>/dev/null

echo "=== AD-04: MM_RELATIVE 无 Web 处理 ==="
grep -rln 'mouseMode.*MM_RELATIVE\|MM_RELATIVE' "$DIR/" 2>/dev/null \
  | xargs grep -L 'SampleInitMouseMode\|IsWebPlatform\|MouseModeChanged' 2>/dev/null

echo "=== AD-05: 触摸坐标无 DPR ==="
grep -rln 'GetTouch\|touch\.position' "$DIR/" 2>/dev/null \
  | xargs grep -L 'GetDPR\|dpr\|DPR' 2>/dev/null

echo "=== AD-06: Hover 无触摸回退 ==="
grep -rn 'hover\|isHover\|onHover' "$DIR/" 2>/dev/null | grep -v '\-\-.*hover'

echo "=== AD-07: SetMode 已禁用 ==="
grep -rn 'graphics:SetMode\|graphics\.SetMode' "$DIR/" 2>/dev/null

echo "=== AD-08: nvgBeginFrame 硬编码分辨率 ==="
grep -rnP 'nvgBeginFrame\s*\(.*\b[1-9][0-9]{2,}\b' "$DIR/" 2>/dev/null

echo "=== AD-09: UI.Init 无 scale ==="
grep -rn 'UI\.Init' "$DIR/" 2>/dev/null | grep -v 'scale'

echo "=== AD-10: SetRoot 无 SafeAreaView ==="
grep -rln 'UI\.SetRoot\|UI.SetRoot' "$DIR/" 2>/dev/null \
  | xargs grep -L 'SafeAreaView' 2>/dev/null

echo "=== AD-11: 触摸元素尺寸过小 ==="
grep -rnP '(Button|Touchable).*width\s*=\s*[12][0-9]\b' "$DIR/" 2>/dev/null
grep -rnP '(Button|Touchable).*height\s*=\s*[12][0-9]\b' "$DIR/" 2>/dev/null

echo "=== AD-12: flexShrink 溢出风险 ==="
grep -rn 'ScrollView' "$DIR/" -A 10 2>/dev/null | grep 'flex = 1' | grep -v 'flexBasis'

echo "=== AD-13: 字号过小 ==="
grep -rnP 'fontSize\s*=\s*([1-9]|1[01])\b' "$DIR/" 2>/dev/null

echo "=== AD-14: 键盘游戏缺移动端控件 ==="
grep -rln 'GetKeyDown\|GetKeyPress' "$DIR/" 2>/dev/null \
  | xargs grep -L 'GameHUD\|VirtualControls\|InputManager\|GetTouch\|IsTouchSupported\|IsMobilePlatform\|onPointerDown\|onSwipe' 2>/dev/null

echo "=== AD-15: 鼠标视角无触摸替代 ==="
grep -rln 'GetMouseMove\|mouseMoveX\|mouseMoveY' "$DIR/" 2>/dev/null \
  | xargs grep -L 'GetTouch\|GameHUD\|VirtualControls\|TouchLookArea' 2>/dev/null

echo "=== AD-16: Start 中音频自动播放 ==="
for f in "$DIR/"*.lua; do
  awk '/function Start/,/^end/' "$f" 2>/dev/null | grep -n 'PlaySound\|:Play(' && echo "  in $f"
done

echo "=== AD-17: 屏幕尺寸缓存未更新 ==="
grep -rn 'local.*screenW\|local.*screenH\|local.*SCREEN_W\|local.*SCREEN_H' "$DIR/" 2>/dev/null

echo "=== AD-18: 鼠标代码无平台检测 ==="
grep -rln 'GetMouseButton\|mouseMode\|MM_RELATIVE\|GetMouseMove' "$DIR/" 2>/dev/null \
  | xargs grep -L 'IsMobilePlatform\|IsTouchSupported\|PlatformUtils\|GetPlatform\|isMobile\|isDesktop' 2>/dev/null

echo "=== AD-19: nvgCreateFont 非初始化调用 ==="
grep -rn 'nvgCreateFont' "$DIR/" 2>/dev/null | grep -vi 'start\|init\|setup'

echo "=== AD-20: 高级渲染无性能分级 ==="
grep -rln 'shadowMapSize\|drawShadows\|bloom\|HDR' "$DIR/" 2>/dev/null \
  | xargs grep -L 'performance\|tier\|quality' 2>/dev/null

echo "=== 扫描完成 ==="
```

---

## 参考文档

- `references/fix-patterns.md` — 每条规则的完整修复代码模板和边界条件
- `references/detection-edge-cases.md` — 检测误报/漏报的已知边界和规避策略

