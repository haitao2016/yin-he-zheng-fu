# 检测边界与误报/漏报规避

> 每条 AD 规则的已知误报（false positive）和漏报（false negative）场景，
> 以及检测时应采取的规避策略。

---

## AD-01: 鼠标按钮数字常量

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| `table[0]` | 数字 0 不在鼠标上下文 | 检查上下文是否在 Mouse 事件回调内 |
| `if state == 0 then` | 状态机用 0 表示初始 | 仅匹配 `button == 0` 模式 |
| `for i = 0, 2 do` | 循环计数器 | 排除 for 循环模式 |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| `local btn = 0; if btn == mouseBtn` | 常量赋值后再比较 | 追踪一层变量赋值 |
| 数字常量在配置表中 | `{ button = 0 }` | 检查表字段名含 button |

### 推荐检测模式

```
grep -nP "(button|btn|mouse\w*)\s*[=~<>]+\s*[012]\b" file.lua
```
排除 `for` 行和注释行。

---

## AD-02: 键盘按键数字常量

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| `GetKeyDown(1)` | KEY_A = 'a' = 97 ≠ 1，但用户可能传的是 KEY 枚举值 | 检查值是否在合理 keycode 范围 |
| `array[32]` | 数字 32 在数组索引上下文 | 仅匹配 `GetKey*` 函数参数 |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| `local JUMP_KEY = 32` | 常量赋值再传入 | 检测 `= 数字` 且变量名含 key |
| `keys = {32, 27, 13}` | 批量配置 | 检测数组中的常见 keycode 值 |

### 推荐检测模式

```
grep -nP "GetKey(Down|Press|Up)\s*\(\s*\d+" file.lua
grep -nP '(Key|key|KEY)\s*[=:]\s*\d+' file.lua
```

---

## AD-03: NanoVG BeginFrame DPR

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| `nvgBeginFrame(vg, w, h, customRatio)` | 用户已有自定义缩放比 | 检查第 4 参数是否为变量（非数字 1） |
| 模式 A 项目故意传 1.0 | 设计分辨率模式不需 DPR | 检查是否有 UIScaler/DESIGN_WIDTH |
| 测试代码 `-- nvgBeginFrame(...)` | 注释行 | 排除 `--` 开头的行 |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| `local ratio = 1.0; nvgBeginFrame(vg,w,h,ratio)` | 第 4 参数是变量 | 追踪变量赋值，值为 1.0 则标记 |
| `nvgBeginFrame (vg, w, h, 1)` | 1 而非 1.0 | 匹配整数 1 和浮点 1.0 |

### 推荐检测模式

```
grep -nP "nvgBeginFrame\s*\([^)]*,\s*(1\.0|1)\s*\)" file.lua
```
排除注释行。再排除已有 `dpr` 的行。

---

## AD-04: MM_RELATIVE 无 Web 处理

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 已有 `IsWebPlatform()` 但在不同文件 | 单文件扫描漏判 | 全项目搜索 Web 平台处理 |
| 使用了 `GameHUD` 库（内部已处理） | 库内封装 | 检查是否 require 了 GameHUD |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| `input.mouseMode = 2` | 用数字代替 MM_RELATIVE | 匹配 `mouseMode\s*=\s*2` |
| 在 config 表中设置 | `{ mouseMode = MM_RELATIVE }` | 全文搜索 MM_RELATIVE |

---

## AD-05: 触摸坐标未除 DPR

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| UI 组件内部处理（已自动转换） | UI 框架内部已处理 DPR | 检查是否在 UI 回调内 |
| 传递给引擎 API（引擎内部处理） | 引擎已处理 | 检查坐标是否传给引擎函数 |
| 模式 C 项目（物理像素坐标系） | 故意使用物理坐标 | 极罕见，降级 MANUAL |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| `input:GetTouchState(0).position` | 非事件方式获取触摸 | 搜索 GetTouchState |
| 触摸坐标存入变量后使用 | 间接使用 | 追踪 eventData["X"] 赋值链 |

---

## AD-07: graphics:SetMode() 调用

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 注释中的 `SetMode` | 注释行 | 排除 `--` 开头的行 |
| 字符串中的 `SetMode` | 日志/调试信息 | 排除引号内的匹配 |
| 其他对象的 SetMode | 非 graphics 对象 | 匹配 `graphics:SetMode` 或 `graphics.SetMode` |

### 推荐检测模式

```
grep -nP "^[^-]*graphics\s*[:.]\s*SetMode" file.lua
```

---

## AD-08: nvgBeginFrame 硬编码分辨率

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| `nvgBeginFrame(vg, DESIGN_W, DESIGN_H, ...)` | 常量名看似硬编码 | 检查是否为全大写常量（可能是设计分辨率） |
| `nvgBeginFrame(vg, 100, 100, ...)` | 小数字可能是有意的 | 仅匹配 >= 320 的分辨率值 |

### 常见硬编码分辨率值

| 宽度值 | 高度值 | 分辨率 |
|--------|--------|--------|
| 1920 | 1080 | Full HD |
| 1280 | 720 | HD |
| 960 | 540 | qHD |
| 800 | 600 | SVGA |
| 2560 | 1440 | QHD |

---

## AD-09: UI.Init 缺少 scale

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 已在外部包装函数中设置 | 间接调用 | 检查是否有 wrapper |
| `UI.Init()` 无参调用在测试代码中 | 测试/demo | 文件名含 test → 降低优先级 |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| `local config = {}; UI.Init(config)` | scale 在变量内 | 检查 config 变量是否含 scale |
| 动态构造参数 | `opts.scale = nil` | 静态分析难以覆盖 → 接受漏报 |

---

## AD-10: UI 根节点缺 SafeAreaView

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 全屏背景（不需要安全区）| 背景图有意覆盖全屏 | 检查是否只有背景层 |
| 弹窗 UI（不在根节点）| 非全屏 UI | 检查 SetRoot 上下文 |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| 多处 SetRoot 调用（切换页面）| 只检查了第一处 | 搜索所有 SetRoot |
| NanoVG 绘制的 UI（非 UI 库）| NanoVG 不经过 UI.SetRoot | 此时应检测 NanoVG 坐标偏移 |

---

## AD-11: 交互元素尺寸过小

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 元素有 padding 扩大了触摸区 | 实际触摸区 > 视觉区 | 检查 padding |
| 仅桌面端使用的 UI | 桌面端无最小尺寸要求 | 检查平台条件分支 |
| UI.Scale 会放大 | 基础尺寸小但缩放后足够 | 考虑 scale 因子 |

### 检测阈值

- 硬性警告: width < 24 或 height < 24
- 建议优化: width < 44 或 height < 44
- 桌面端可放宽到 24x24

---

## AD-12: Yoga flexShrink 溢出

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 父容器有 overflow = "scroll" | 允许滚动 | 检查父容器属性 |
| 子元素总宽度 < 父容器 | 不会溢出 | 静态分析难以判断 → 保留提示 |

### 检测条件

仅当以下条件同时满足时报告：
1. 父容器有 `flexDirection = "row"`
2. 多个子元素有固定 `width`
3. 没有任何子元素设置 `flexShrink`
4. 父容器无 `overflow = "scroll"`

---

## AD-14: 键盘游戏缺少移动端控件

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 桌面端专属游戏（RTS等） | 不需要移动端支持 | 检查项目配置的目标平台 |
| 已使用 InputManager（自动处理）| 库内封装 | 检查 require InputManager |
| 已使用 GameHUD | 库内封装 | 检查 require GameHUD |
| 使用 VirtualControls | 手动创建但已有 | 检查 require VirtualControls |

### 检测触发条件

仅当以下条件同时满足时触发：
1. 代码中有 `GetKeyDown`/`GetKeyPress` 调用
2. 未 require `InputManager`、`GameHUD`、`VirtualControls` 中任何一个
3. 未检测到 `IsMobilePlatform()` 或 `IsTouchSupported()` 条件分支

---

## AD-16: Web 音频自动播放

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 音频在用户点击后才播放 | 已符合自动播放策略 | 检查 PlaySound 是否在事件回调内 |
| 已调用 `audio:Resume()` | 已有恢复逻辑 | 全文搜索 `audio:Resume` |

### 漏报场景

| 场景 | 漏报原因 | 规避 |
|------|---------|------|
| BGM 在 Start 中 PlayMusic | 语法正常但 Web 上静默 | 检查 Start/初始化阶段的音频调用 |
| 间接调用 `soundSource:Play()` | 非全局 audio 调用 | 搜索所有 `:Play()` 调用 |

---

## AD-17: 屏幕旋转/窗口缩放布局未更新

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 使用 UI 库（自动响应） | UI 组件库内部处理 | 检查是否纯 UI 库项目 |
| 使用 UIScaler（自动处理） | 组件内部处理 | 检查 require UIScaler |
| 固定竖屏/横屏游戏 | 不旋转 | 检查项目配置的屏幕方向 |

### 检测触发条件

仅当以下条件同时满足时触发：
1. 代码中有布局相关的硬编码坐标（如 `GetWidth()` 赋值给变量）
2. 未订阅 `ScreenMode` 事件
3. 未使用 UIScaler 或 UI 库的自动响应功能

---

## AD-19: nvgCreateFont 渲染循环泄漏

### 误报场景

| 场景 | 误报原因 | 规避 |
|------|---------|------|
| 首次渲染时延迟创建（有 if 保护）| `if not font then font = nvgCreateFont(...)` | 检查是否有 nil 守卫 |
| 在 `pcall` 内创建 | 错误处理场景 | 检查外层是否有 pcall |

### 安全的 nvgCreateFont 位置

| 位置 | 安全性 |
|------|--------|
| 文件顶层 | ✅ 安全（只执行一次） |
| `Start()` 函数 | ✅ 安全 |
| `init()` / `setup()` 函数 | ✅ 安全（约定初始化函数） |
| `HandleUpdate` / `HandleNanoVGRender` 内 | ❌ 危险（每帧执行） |
| 带 nil 守卫的条件内 | ✅ 安全 |

### 推荐检测模式

```
# 在渲染/更新函数内搜索 nvgCreateFont
grep -nP "nvgCreateFont" file.lua
```

然后检查该行是否在 `HandleUpdate`/`HandleNanoVGRender`/Update 函数体内，
且无 `if.*nil` 守卫。

---

## 通用边界规避策略

### 注释行排除

所有规则都必须排除注释行：
```
grep -P "^[^-]*PATTERN" file.lua
```
或先 strip 注释再匹配。

### 字符串内排除

避免匹配字符串字面量中的内容：
```lua
print("nvgBeginFrame example")  -- 不应触发 AD-03
log("button == 0 check")        -- 不应触发 AD-01
```

方法：检查匹配行中 `PATTERN` 前是否有未闭合的引号。

### 多文件项目

- 所有规则应跨文件搜索（一个文件中的平台检测可能保护另一个文件的逻辑）
- AD-04/AD-14/AD-18 需要**全项目**搜索 `PlatformUtils` / `IsMobilePlatform`
- 如果主入口文件有平台分支，子模块可能不需要重复检测

### 降级策略

当检测结果不确定时，宁可降级：
- AUTO-FIX → MANUAL-FLAG（不确定是否安全修复）
- 高优先级 → 中优先级（不确定影响范围）
- 报告中标注"可能误报，建议人工确认"

