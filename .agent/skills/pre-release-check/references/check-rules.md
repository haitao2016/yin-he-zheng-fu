# 发布前检查 — 完整检测规则库

## 完整扫描脚本

AI 执行检查时，先运行此脚本批量扫描，再逐条分析结果。

```bash
#\!/bin/bash
DIR="scripts"
echo "══════════════════════════════════════"
echo "  发布前全面质量检查 — 扫描阶段"
echo "══════════════════════════════════════"

FILE_COUNT=$(find "$DIR" -name "*.lua" -type f 2>/dev/null | wc -l)
LINE_COUNT=$(find "$DIR" -name "*.lua" -type f -exec cat {} + 2>/dev/null | wc -l)
echo "扫描范围: $DIR/ ($FILE_COUNT 个文件, $LINE_COUNT 行代码)"
echo ""

# ═══ 维度 1: 屏幕显示适配 ═══
echo "▶ 维度1: 屏幕显示适配"

echo "--- D1-01: nvgBeginFrame 无 DPR ---"
grep -rln 'nvgBeginFrame' "$DIR/" 2>/dev/null | xargs grep -L 'GetDPR' 2>/dev/null

echo "--- D1-02: nvgBeginFrame 硬编码分辨率 ---"
grep -rnP 'nvgBeginFrame\s*\(.*\b[1-9][0-9]{2,}\b' "$DIR/" 2>/dev/null

echo "--- D1-03: SetMode 已禁用 ---"
grep -rn 'graphics:SetMode\|graphics\.SetMode' "$DIR/" 2>/dev/null

echo "--- D1-04: 触摸坐标无 DPR ---"
grep -rln 'GetTouch\|touch\.position' "$DIR/" 2>/dev/null | xargs grep -L 'GetDPR\|dpr\|DPR' 2>/dev/null

echo "--- D1-05: 屏幕尺寸缓存 ---"
grep -rn 'local.*screenW\|local.*screenH\|local.*SCREEN_W\|local.*SCREEN_H' "$DIR/" 2>/dev/null

echo "--- D1-06: 字号过小 ---"
grep -rnP 'fontSize\s*=\s*([1-9]|1[01])\b' "$DIR/" 2>/dev/null

echo "--- D1-07: NanoVG 硬编码坐标 ---"
grep -rnP 'nvg(Rect|Circle|Text|MoveTo|LineTo)\s*\(.*\b[3-9][0-9]{2}\b' "$DIR/" 2>/dev/null | head -10

echo "--- D1-08: ScreenMode 事件 ---"
grep -rln 'nvgBeginFrame\|GetWidth\|GetHeight' "$DIR/" 2>/dev/null | xargs grep -L 'ScreenMode' 2>/dev/null

# ═══ 维度 2: 硬件交互适配 ═══
echo ""
echo "▶ 维度2: 硬件交互适配"

echo "--- D2-01: 鼠标按钮数字常量 ---"
grep -rn 'button == [0-9]\|button ~= [0-9]\|button > [0-9]\|button < [0-9]' "$DIR/" 2>/dev/null

echo "--- D2-02: 键盘按键数字常量 ---"
grep -rn 'GetKeyDown([0-9]\|GetKeyPress([0-9]\|key == [0-9]' "$DIR/" 2>/dev/null

echo "--- D2-03: 键盘游戏缺移动端控件 ---"
grep -rln 'GetKeyDown\|GetKeyPress' "$DIR/" 2>/dev/null \
  | xargs grep -L 'GameHUD\|VirtualControls\|InputManager\|GetTouch\|GetNumTouches\|IsTouchSupported\|IsMobilePlatform\|onPointerDown\|onSwipe' 2>/dev/null

echo "--- D2-04: 鼠标视角无触摸替代 ---"
grep -rln 'GetMouseMove\|mouseMoveX\|mouseMoveY' "$DIR/" 2>/dev/null \
  | xargs grep -L 'GetTouch\|GameHUD\|VirtualControls\|TouchLookArea' 2>/dev/null

echo "--- D2-05: MM_RELATIVE 无 Web 处理 ---"
grep -rln 'mouseMode.*MM_RELATIVE\|MM_RELATIVE' "$DIR/" 2>/dev/null \
  | xargs grep -L 'SampleInitMouseMode\|IsWebPlatform\|MouseModeChanged' 2>/dev/null

echo "--- D2-06: Hover 无触摸回退 ---"
grep -rn 'hover\|isHover\|onHover' "$DIR/" 2>/dev/null | grep -v '\-\-.*hover'

echo "--- D2-07: 鼠标代码无平台检测 ---"
grep -rln 'GetMouseButton\|mouseMode\|MM_RELATIVE\|GetMouseMove' "$DIR/" 2>/dev/null \
  | xargs grep -L 'IsMobilePlatform\|IsTouchSupported\|PlatformUtils\|GetPlatform\|isMobile\|isDesktop' 2>/dev/null

# ═══ 维度 3: 界面布局 ═══
echo ""
echo "▶ 维度3: 界面布局"

echo "--- D3-01: UI.Init 无 scale ---"
grep -rn 'UI\.Init' "$DIR/" 2>/dev/null | grep -v 'scale'

echo "--- D3-02: SetRoot 无 SafeAreaView ---"
grep -rln 'UI\.SetRoot\|UI.SetRoot' "$DIR/" 2>/dev/null | xargs grep -L 'SafeAreaView' 2>/dev/null

echo "--- D3-03: 触摸元素尺寸过小 ---"
grep -rnP '(Button|Touchable).*width\s*=\s*[12][0-9]\b' "$DIR/" 2>/dev/null
grep -rnP '(Button|Touchable).*height\s*=\s*[12][0-9]\b' "$DIR/" 2>/dev/null

echo "--- D3-04: flexShrink 溢出 ---"
grep -rn 'ScrollView' "$DIR/" -A 10 2>/dev/null | grep 'flex = 1' | grep -v 'flexBasis'

echo "--- D3-05: SetRoot 内容检查 ---"
grep -rn 'UI\.SetRoot\|UI.SetRoot' "$DIR/" 2>/dev/null

# ═══ 维度 4: 功能性 ═══
echo ""
echo "▶ 维度4: 功能性"

echo "--- D4-01: eventData 点语法 ---"
grep -rn 'eventData\.' "$DIR/" 2>/dev/null | grep -v 'eventData\["' | grep -v 'eventData:Get' | grep -v '\-\-'

echo "--- D4-02: Box2D 脚底传感器 ---"
grep -rn "trigger = true" "$DIR/" 2>/dev/null | grep -v "center"

echo "--- D4-03: 3D SetLinearVelocity ---"
grep -rn "SetLinearVelocity" "$DIR/" 2>/dev/null

echo "--- D4-04: SetEnabled vs SetDeepEnabled ---"
grep -rn 'SetEnabled(false)' "$DIR/" 2>/dev/null | grep -v 'DeepEnabled'

echo "--- D4-05: 数组索引从 0 ---"
grep -rn 'for i = 0,' "$DIR/" 2>/dev/null
grep -rn '\[0\]' "$DIR/" 2>/dev/null

echo "--- D4-06: Unicode 转义 ---"
grep -rnP '\\u[0-9A-Fa-f]{4}[^}]' "$DIR/" 2>/dev/null

echo "--- D4-07: NanoVG 缺字体 ---"
for f in $(grep -rln 'nvgText' "$DIR/" 2>/dev/null); do
  grep -L 'nvgCreateFont' "$f" 2>/dev/null
done

echo "--- D4-08: nvgBeginFrame 不在 NanoVGRender ---"
grep -rln 'nvgBeginFrame' "$DIR/" 2>/dev/null | xargs grep -L 'NanoVGRender' 2>/dev/null

echo "--- D4-09: NanoVG + UI 混用 ---"
grep -rln 'nvgCreate' "$DIR/" 2>/dev/null | xargs grep -l 'UI\.Init\|UI\.SetRoot' 2>/dev/null

echo "--- D4-10: orthoSize 缺 0.5 ---"
grep -rn 'orthoSize' "$DIR/" 2>/dev/null | grep -v '0\.5'

echo "--- D4-11: table.unpack 位置 ---"
grep -rn 'table.unpack' "$DIR/" 2>/dev/null

echo "--- D4-12: 多人/单机配置 ---"
cat .project/settings.json 2>/dev/null | grep -A5 'multiplayer'

# ═══ 维度 5: 性能与稳定性 ═══
echo ""
echo "▶ 维度5: 性能与稳定性"

echo "--- D5-01: nvgCreateFont 泄漏 ---"
grep -rn 'nvgCreateFont' "$DIR/" 2>/dev/null | grep -vi 'start\|init\|setup'

echo "--- D5-02: Update 中创建对象 ---"
for f in $(find "$DIR" -name "*.lua" 2>/dev/null); do
  awk '/function.*[Uu]pdate|function.*[Rr]ender/,/^end/' "$f" 2>/dev/null \
    | grep -n 'Vector3(\|Vector2(\|Quaternion(\|Color(' && echo "  in $f"
done 2>/dev/null | head -15

echo "--- D5-03: Update 中字符串拼接 ---"
for f in $(find "$DIR" -name "*.lua" 2>/dev/null); do
  awk '/function.*[Uu]pdate/,/^end/' "$f" 2>/dev/null \
    | grep -n '\.\..*\.\.' && echo "  in $f"
done 2>/dev/null | head -10

echo "--- D5-04: 渲染无性能分级 ---"
grep -rln 'shadowMapSize\|drawShadows\|bloom\|HDR' "$DIR/" 2>/dev/null \
  | xargs grep -L 'performance\|tier\|quality' 2>/dev/null

echo "--- D5-05: Update 中 GetResource ---"
for f in $(find "$DIR" -name "*.lua" 2>/dev/null); do
  awk '/function.*[Uu]pdate/,/^end/' "$f" 2>/dev/null \
    | grep -n 'GetResource' && echo "  in $f"
done 2>/dev/null | head -10

# ═══ 维度 6: 界面与用户体验 ═══
echo ""
echo "▶ 维度6: 界面与用户体验"

echo "--- D6-04: 无暂停/退出机制 ---"
PAUSE=$(grep -rln 'KEY_ESCAPE\|[Pp]ause\|engine\.Exit\|engine:Exit' "$DIR/" 2>/dev/null | wc -l)
if [ "$PAUSE" -eq 0 ]; then
  echo "WARNING: 未检测到暂停/退出机制"
fi

# ═══ 维度 7: 兼容性与跨平台 ═══
echo ""
echo "▶ 维度7: 兼容性与跨平台"

echo "--- D7-01: Start 中音频自动播放 ---"
for f in $(find "$DIR" -name "*.lua" 2>/dev/null); do
  awk '/function Start/,/^end/' "$f" 2>/dev/null \
    | grep -n 'PlaySound\|:Play(' && echo "  in $f"
done

echo "--- D7-02: io 库使用 ---"
grep -rn '\bio\.\|io\.open\|io\.read\|io\.write' "$DIR/" 2>/dev/null | grep -v '\-\-'

echo "--- D7-03: 绝对路径 ---"
grep -rnP '"/[a-zA-Z]|"C:\\\\|"/home|"/tmp|"/workspace' "$DIR/" 2>/dev/null

echo "--- D7-04: require 路径检查 ---"
grep -rn 'require' "$DIR/" 2>/dev/null

echo "--- D7-05: 发布配置完整性 ---"
if [ -f .project/project.json ]; then
  echo "icon: $(grep -c 'icon' .project/project.json)"
  echo "screenshots: $(grep -c 'screenshot' .project/project.json)"
  echo "promotional: $(grep -c 'promotional' .project/project.json)"
  echo "title: $(grep -c 'title' .project/project.json)"
  echo "category: $(grep -c 'category' .project/project.json)"
else
  echo "WARNING: .project/project.json 不存在"
fi

echo ""
echo "══════════════════════════════════════"
echo "  扫描完成，进入分析阶段"
echo "══════════════════════════════════════"
```

---

## 维度 1: 屏幕显示适配 — 修复代码模板

### D1-01 nvgBeginFrame 缺少 DPR 处理 🔧

```lua
-- ❌ 修复前
nvgBeginFrame(vg, w, h, 1.0)

-- ✅ 修复后（模式 B：系统逻辑分辨率）
local dpr = graphics:GetDPR()
local logW, logH = w / dpr, h / dpr
nvgBeginFrame(vg, logW, logH, dpr)
```

### D1-02 nvgBeginFrame 硬编码分辨率 🔧

```lua
-- ❌ 修复前
nvgBeginFrame(vg, 1920, 1080, 1.0)

-- ✅ 修复后
local physW = graphics:GetWidth()
local physH = graphics:GetHeight()
local dpr = graphics:GetDPR()
nvgBeginFrame(vg, physW / dpr, physH / dpr, dpr)
```

### D1-03 graphics:SetMode() 🔧

```lua
-- ❌ 删除
graphics:SetMode(1920, 1080, ...)

-- ✅ 替换为
local w = graphics:GetWidth()
local h = graphics:GetHeight()
local dpr = graphics:GetDPR()
```

### D1-04 触摸坐标未除 DPR 🔍

```lua
-- 触摸坐标是物理像素，NanoVG/UI 使用逻辑坐标时需转换
local dpr = graphics:GetDPR()
local tx = touch.position.x / dpr
local ty = touch.position.y / dpr
```

### D1-05 屏幕尺寸缓存 🔍

```lua
-- ❌ 只在 Start 中缓存一次
function Start()
    screenW = graphics:GetWidth()  -- 旋转后不更新
end

-- ✅ 每帧读取或监听事件
function HandleUpdate(_, eventData)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
end
```

---

## 维度 2: 硬件交互适配 — 修复代码模板

### D2-01 鼠标按钮数字常量 🔧

映射: `0 → MOUSEB_LEFT`, `1 → MOUSEB_MIDDLE`, `2 → MOUSEB_RIGHT`

### D2-02 键盘按键数字常量 🔧

映射: `32 → KEY_SPACE`, `27 → KEY_ESCAPE`, `13 → KEY_RETURN`, `87 → KEY_W`, `65 → KEY_A`, `83 → KEY_S`, `68 → KEY_D`

### D2-03 键盘游戏缺移动端控件 🔍

```lua
-- 方案 A: GameHUD（推荐）
local UI = require("urhox-libs/UI")
local hud = UI.GameHUD({
    joystick = { side = "left" },
    buttons = {
        { label = "Jump", side = "right", keyBinding = "SPACE",
          onClick = function() doJump() end },
    },
})

-- 方案 B: VirtualControls
require "urhox-libs.UI.VirtualControls"
VirtualControls.CreateJoystick({ position = Vector2(200, -200) })
VirtualControls.Initialize()

-- 方案 C: UI 触摸按钮
UI.Button({
    text = "←", width = 64, height = 64,
    onPointerDown = function() moveLeft = true end,
    onPointerUp   = function() moveLeft = false end,
})
```

### D2-05 MM_RELATIVE Web 处理 🔍

```lua
-- 推荐：使用 Sample 工具函数
require "LuaScripts/Utilities/Sample"
SampleInitMouseMode(MM_RELATIVE)
```

---

## 维度 3: 界面布局 — 修复代码模板

### D3-01 UI.Init 缺 scale 🔧

```lua
-- ❌ 修复前
UI.Init({ fonts = { ... } })

-- ✅ 修复后
UI.Init({ fonts = { ... }, scale = UI.Scale.DEFAULT })
```

### D3-02 SafeAreaView 🔍

```lua
UI.SetRoot(
    UI.SafeAreaView({
        edges = "all",
        width = "100%", height = "100%",
        children = { --[[ 原有根内容 ]] }
    })
)
```

### D3-03 触摸元素尺寸 🔍

最小 44 逻辑像素，推荐 48。

### D3-04 flexShrink 溢出 🔍

```lua
-- ScrollView 子内容必须同时设置
UI.ScrollView({ flex = 1, flexBasis = 0, children = { ... } })
```

---

## 维度 4: 功能性 — 修复代码模板

### D4-01 eventData 点语法 🔧

```lua
-- ❌
local dt = eventData.TimeStep
-- ✅
local dt = eventData["TimeStep"]:GetFloat()
-- ✅ 高效写法
local dt = eventData:GetFloat("TimeStep")
```

### D4-02 Box2D 脚底传感器 🔍

```lua
-- ❌ trigger 缺 center
local sensor = node:CreateComponent("CollisionBox2D")
sensor.trigger = true
sensor.size = Vector2(0.5, 0.1)

-- ✅ 必须设置 center 偏移到脚底
sensor.center = Vector2(0, -halfHeight)
```

### D4-05 数组索引从 0 🔧

```lua
-- ❌
for i = 0, #arr - 1 do
-- ✅
for i = 1, #arr do
```

### D4-06 Unicode 转义 🔧

```lua
-- ❌
local s = "\u2764"
-- ✅
local s = "\u{2764}"
```

### D4-12 多人/单机判断 🔍

```lua
-- 读取 .project/settings.json
-- multiplayer.enabled == true → 多人模式代码
-- multiplayer.enabled == false → 单机模式代码
```

---

## 维度 5: 性能与稳定性 — 修复代码模板

### D5-01 nvgCreateFont 泄漏 🔧

```lua
-- ❌ 在渲染回调中调用
function HandleNanoVGRender(...)
    local font = nvgCreateFont(vg, "sans", "Fonts/xxx.ttf")  -- 每帧泄漏\!
end

-- ✅ 移到 Start() 中
local fontSans
function Start()
    fontSans = nvgCreateFont(vg, "sans", "Fonts/xxx.ttf")
end
```

### D5-02 每帧创建对象 🔍

```lua
-- ❌ Update 中每帧创建 Vector3
function HandleUpdate(_, ed)
    node.position = node.position + Vector3(0, 0, speed * dt)
end

-- ✅ 复用或直接设置分量
function HandleUpdate(_, ed)
    local pos = node.position
    pos.z = pos.z + speed * dt
    node.position = pos
end
```

### D5-05 Update 中 GetResource 🔍

```lua
-- ❌ 每帧加载资源
function HandleUpdate(...)
    local mat = cache:GetResource("Material", "Materials/X.xml")
end

-- ✅ 预加载到变量
local mat
function Start()
    mat = cache:GetResource("Material", "Materials/X.xml")
end
```

---

## 维度 7: 兼容性与跨平台 — 修复代码模板

### D7-02 io 库 🔧

```lua
-- ❌ io 已被沙箱移除
local f = io.open("save.dat", "r")

-- ✅ 使用 File 替代
local file = File(fileSystem:GetProgramDir() .. "save.dat", FILE_READ)
-- 或使用 engine-docs/recipes/file-storage.md 推荐方式
```

### D7-03 绝对路径 🔍

```lua
-- ❌ 绝对路径
cache:GetResource("Texture2D", "/workspace/assets/tex.png")

-- ✅ 相对路径（assets/ 是资源根）
cache:GetResource("Texture2D", "tex.png")
```

### D7-05 发布配置检查 📋

需确保 `.project/project.json` 中包含：
- `taptap_publish.title` — 游戏标题
- `taptap_publish.category` — 游戏分类
- `taptap_publish.screen_orientation` — 屏幕方向
- `assets.icon` — 游戏图标
- `assets.screenshots` — 至少 3 张截图
- `assets.promotional_image` — 宣传图

---

## 误报过滤规则

以下情况标记为 SKIP，不作为问题报告：

1. **注释中的代码** — `--` 开头的行
2. **字符串常量** — 引号内的内容
3. **D4-04**: 叶子节点 `SetEnabled` 是正确的
4. **D4-03**: `SetLinearVelocity` 在 2D 场景中可能是正确用法
5. **D5-02**: `Vector3()` 在非热路径中创建是可接受的
6. **D1-07**: NanoVG 游戏使用绝对坐标 + 整体缩放是有效模式
7. **D2-03**: 纯 PC 游戏（无移动端发布计划）可跳过
8. **D4-12**: 仅在项目同时包含单机和多人代码时才检查
