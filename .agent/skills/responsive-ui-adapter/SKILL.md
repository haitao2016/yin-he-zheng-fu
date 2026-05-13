---
name: responsive-ui-adapter
description: |
  UrhoX 多设备 UI 自适应适配系统。根据目标设备（PC/手机/平板）自动生成响应式布局代码，
  覆盖三大标准分辨率断点（PC 1920×1080、手机 867×390、平板 1180×820），
  提供完整的断点检测、布局切换、安全区域适配和组件缩放方案。

  Use when users need to (1) UI 适配多设备/多分辨率,
  (2) 创建响应式布局（PC+手机+平板）,
  (3) 用户说"适配手机""适配平板""适配PC""多端适配",
  (4) 解决 UI 在不同屏幕尺寸下错乱/溢出/拥挤,
  (5) 设置断点自动切换横竖屏布局,
  (6) 用户提到"响应式""自适应""屏幕适配""分辨率适配",
  (7) UI 在小屏上挤成一团或在大屏上留白过多。

  MUST trigger when:
    - 用户提到需要同时适配 PC、手机、平板三种设备
    - 用户提到具体分辨率数字并要求 UI 适配
    - 用户说"UI 适配"或"响应式 UI"

  trigger-keywords:
    - 响应式
    - 自适应
    - 适配
    - 分辨率
    - 多设备
    - 断点
    - breakpoint
    - responsive
    - 手机适配
    - 平板适配
    - PC适配
    - 屏幕适配
    - 布局切换
    - 横竖屏

version: "1.0.0"
metadata:
  author: "UrhoX-Skill"
  tags: ["ui", "responsive", "layout", "adaptation", "game-dev"]
---

# 多设备 UI 自适应适配系统

> 一套方案覆盖 PC、手机、平板三大设备族，让 UI 在任何屏幕上都"刚刚好"。

---

## 1. 身份

本 Skill 是 **UrhoX UI 多设备自适应布局专家**，提供从断点检测、布局策略选择到完整代码生成的全流程方案。

---

## 2. 标准断点定义

### 2.1 三大目标设备

| 设备 | 物理分辨率 | 宽高比 | 短边(逻辑) | 分类标识 |
|------|-----------|--------|-----------|---------|
| **PC** | 1920 × 1080 | 16:9 | 1080 | `"desktop"` |
| **平板** | 1180 × 820 | ~3:2 | 820 | `"tablet"` |
| **手机** | 867 × 390 | ~20:9 | 390 | `"phone"` |

### 2.2 断点阈值（基于逻辑短边）

```
phone ──── 600 ──── tablet ──── 900 ──── desktop
  <600       600~900        ≥900
```

> **为什么用短边？** 横竖屏切换时，短边是稳定不变的维度，能可靠区分设备族。

---

## 3. 核心工作流

```
项目初始化
  │
  ├─ 1. 初始化 UI 系统（UI.Init + UI.Scale.DEFAULT）
  │
  ├─ 2. 检测设备类型（断点函数）
  │
  ├─ 3. 选择布局策略
  │     ├─ phone  → 单列纵向 + 折叠菜单
  │     ├─ tablet → 双列/侧栏 + 自适应网格
  │     └─ desktop → 多列 + 宽屏面板
  │
  ├─ 4. 构建 UI 树（Yoga Flexbox）
  │
  └─ 5. 监听窗口变化（可选：动态切换）
```

---

## 4. 断点检测模块

### 4.1 基础断点检测

```lua
--- 获取当前设备类型
---@return "phone"|"tablet"|"desktop"
local function getDeviceType()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    -- 逻辑短边 = 物理短边 / DPR
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

### 4.2 扩展设备信息

```lua
--- 获取完整的设备适配信息
---@return table 包含设备类型、朝向、逻辑分辨率、布局参数
local function getDeviceInfo()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    local logW = physW / dpr
    local logH = physH / dpr
    local shortSide = math.min(logW, logH)

    local deviceType
    if shortSide < 600 then
        deviceType = "phone"
    elseif shortSide < 900 then
        deviceType = "tablet"
    else
        deviceType = "desktop"
    end

    local isLandscape = logW > logH

    return {
        type = deviceType,
        isLandscape = isLandscape,
        logicalWidth = logW,
        logicalHeight = logH,
        shortSide = shortSide,
        dpr = dpr,
        physWidth = physW,
        physHeight = physH,
        -- 布局参数（按设备类型预设）
        layout = {
            columns    = ({ phone = 1, tablet = 2, desktop = 3 })[deviceType],
            sidebarW   = ({ phone = 0, tablet = 200, desktop = 260 })[deviceType],
            padding    = ({ phone = 8, tablet = 16, desktop = 24 })[deviceType],
            gap        = ({ phone = 8, tablet = 12, desktop = 16 })[deviceType],
            fontSize   = ({ phone = 13, tablet = 14, desktop = 16 })[deviceType],
            titleSize  = ({ phone = 20, tablet = 24, desktop = 28 })[deviceType],
            showSidebar = deviceType ~= "phone",
        },
    }
end
```

---

## 5. 布局策略

### 5.1 策略总览

| 设备 | 主布局 | 导航 | 网格列数 | 侧栏 | 字号 |
|------|--------|------|---------|------|------|
| phone | 单列纵向 | 底部标签栏/汉堡菜单 | 1-2 | 隐藏 | 13-14 |
| tablet | 双列/侧栏 | 侧边导航 | 2-3 | 窄(200) | 14-15 |
| desktop | 多列宽屏 | 顶部/侧边 | 3-4 | 宽(260) | 15-16 |

### 5.2 手机布局模板

```lua
local function createPhoneLayout(info)
    return UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = {
            -- 顶部栏
            UI.Panel {
                width = "100%", height = 48,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = info.layout.padding,
                backgroundColor = {30, 30, 45, 255},
                children = {
                    UI.Label { text = "标题", fontSize = info.layout.titleSize,
                               fontColor = {255,255,255,255}, flex = 1 },
                    UI.Button { text = "☰", variant = "text",
                                onClick = function() --[[打开菜单]] end },
                },
            },
            -- 内容区（可滚动）
            UI.ScrollView {
                flex = 1, flexBasis = 0,
                width = "100%",
                scrollY = true, bounces = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        padding = info.layout.padding,
                        gap = info.layout.gap,
                        children = {
                            -- ← 填充游戏内容
                        },
                    },
                },
            },
            -- 底部标签栏
            UI.Panel {
                width = "100%", height = 52,
                flexDirection = "row",
                justifyContent = "space-around",
                alignItems = "center",
                backgroundColor = {30, 30, 45, 255},
                children = {
                    UI.Button { text = "主页", variant = "text" },
                    UI.Button { text = "背包", variant = "text" },
                    UI.Button { text = "设置", variant = "text" },
                },
            },
        },
    }
end
```

### 5.3 平板布局模板

```lua
local function createTabletLayout(info)
    return UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "row",
        children = {
            -- 侧栏导航
            UI.Panel {
                width = info.layout.sidebarW,
                height = "100%",
                backgroundColor = {25, 25, 40, 255},
                padding = 12,
                gap = 8,
                children = {
                    UI.Label { text = "导航", fontSize = 16,
                               fontColor = {200,200,200,255}, marginBottom = 12 },
                    UI.Button { text = "主页", variant = "text", width = "100%" },
                    UI.Button { text = "背包", variant = "text", width = "100%" },
                    UI.Button { text = "设置", variant = "text", width = "100%" },
                },
            },
            -- 主内容区
            UI.ScrollView {
                flex = 1, flexBasis = 0,
                height = "100%",
                scrollY = true, bounces = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        padding = info.layout.padding,
                        gap = info.layout.gap,
                        children = {
                            -- ← 填充游戏内容
                        },
                    },
                },
            },
        },
    }
end
```

### 5.4 桌面布局模板

```lua
local function createDesktopLayout(info)
    return UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = {
            -- 顶部导航栏
            UI.Panel {
                width = "100%", height = 56,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = info.layout.padding,
                backgroundColor = {25, 25, 40, 255},
                children = {
                    UI.Label { text = "游戏标题", fontSize = info.layout.titleSize,
                               fontColor = {255,255,255,255} },
                    UI.Panel { flex = 1 },
                    UI.Button { text = "主页", variant = "text", marginRight = 12 },
                    UI.Button { text = "背包", variant = "text", marginRight = 12 },
                    UI.Button { text = "设置", variant = "text" },
                },
            },
            -- 主体（侧栏 + 内容）
            UI.Panel {
                flex = 1, flexBasis = 0,
                width = "100%",
                flexDirection = "row",
                children = {
                    UI.Panel {
                        width = info.layout.sidebarW,
                        height = "100%",
                        backgroundColor = {30, 30, 45, 255},
                        padding = 16, gap = 8,
                        children = {
                            UI.Label { text = "快捷功能", fontSize = 14,
                                       fontColor = {180,180,180,255} },
                        },
                    },
                    UI.ScrollView {
                        flex = 1, flexBasis = 0,
                        height = "100%",
                        scrollY = true, bounces = true,
                        children = {
                            UI.Panel {
                                width = "100%",
                                padding = info.layout.padding,
                                gap = info.layout.gap,
                                maxWidth = 1200,
                                alignSelf = "center",
                                children = {
                                    -- ← 填充游戏内容
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end
```

---

## 6. 响应式组件模式

### 6.1 自适应网格

```lua
--- 使用最小列宽自动计算列数
local function createAutoGrid(items)
    return UI.SimpleGrid {
        width = "100%",
        minColumnWidth = 240,
        gap = 12,
        children = items,
    }
end
```

### 6.2 条件显隐

```lua
--- 仅在特定设备类型下显示的组件
local function showOnDevice(deviceType, showOn, child)
    if type(showOn) == "string" then showOn = { showOn } end
    for _, t in ipairs(showOn) do
        if t == deviceType then return child end
    end
    return nil
end
```

### 6.3 自适应字号

```lua
local function adaptiveFontSize(info, role)
    local sizes = {
        phone  = { title = 20, subtitle = 16, body = 13, caption = 10 },
        tablet = { title = 24, subtitle = 18, body = 14, caption = 11 },
        desktop = { title = 28, subtitle = 20, body = 16, caption = 12 },
    }
    return sizes[info.type][role] or sizes[info.type].body
end
```

---

## 7. 完整集成示例

```lua
local UI = require("urhox-libs/UI")

-- （从 §4 复制 getDeviceInfo 函数到此处）

function Start()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    local info = getDeviceInfo()
    log:Write(LOG_INFO, string.format(
        "[Responsive] 设备=%s 逻辑=%dx%d DPR=%.1f",
        info.type, info.logicalWidth, info.logicalHeight, info.dpr
    ))

    local root
    if info.type == "phone" then
        root = createPhoneLayout(info)
    elseif info.type == "tablet" then
        root = createTabletLayout(info)
    else
        root = createDesktopLayout(info)
    end

    UI.SetRoot(root)
end
```

---

## 8. 常见问题诊断

| 症状 | 原因 | 解决 |
|------|------|------|
| 手机上 UI 挤成一团 | 未用 `UI.Scale.DEFAULT` | 初始化设置 `scale = UI.Scale.DEFAULT` |
| 平板只显示一列 | 断点阈值不匹配 | 检查 `getDeviceType()` 短边阈值 |
| 大屏内容拉伸过宽 | 未设 `maxWidth` | 内容区加 `maxWidth = 1200` |
| 内容溢出容器 | Yoga `flexShrink` 默认 0 | 弹性子元素加 `flexShrink = 1` |
| ScrollView 不滚动 | 缺少高度约束 | 设 `flexGrow = 1, flexBasis = 0` |
| 横竖屏切换后布局不变 | 未监听分辨率变化 | HandleUpdate 中定期检查或监听 ScreenMode 事件 |

---

## 9. 参考文档

- [references/layout-patterns.md](references/layout-patterns.md) — 12 种响应式布局模式详解与实战代码
- 引擎文档：`engine-docs/recipes/ui.md` § UI.Scale 策略
- 示例：`examples/09-ui-scaler-component.lua`
- 示例：`examples/14-ui-widgets-gallery.lua`

---

## 10. 检查清单

适配代码交付前自查：

- [ ] `UI.Init` 使用了 `scale = UI.Scale.DEFAULT`
- [ ] 断点函数基于 **逻辑短边**（物理短边 ÷ DPR）
- [ ] 三种设备布局都有对应实现（phone/tablet/desktop）
- [ ] 手机布局使用单列 + ScrollView
- [ ] 弹性子元素设置了 `flexShrink = 1`
- [ ] ScrollView 使用了 `flexGrow = 1, flexBasis = 0`
- [ ] 桌面布局内容区设置了 `maxWidth`
- [ ] 字号做了设备适配（手机≥13，桌面≥16）
- [ ] 按钮/触摸目标≥40px 高度
