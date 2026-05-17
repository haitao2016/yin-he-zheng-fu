---
name: "auto-game-vision-tester"
description: |
  UrhoX Lua 游戏自动化视觉质量测试框架。
  灵感源自 AutoGameVisionTester（https://github.com/Sqeakzz/AutoGameVisionTester），
  将 Python + Grok Vision API 的自动化游戏截图视觉分析理念迁移到 UrhoX Lua 引擎内，
  为开发者提供无需外部 API 的引擎内帧级视觉质量检测、严重性分级报告、
  智能去重捕获、分析历史管理和 NanoVG 可视化报告面板。

  核心能力：
  - 帧捕获引擎：可配置间隔的自动帧采样，感知哈希去重跳过静态帧
  - 视觉分析器：基于规则的多维度画面质量检测（Z-fighting、纹理异常、UI 重叠、
    色彩带状、LOD 跳变、光照异常、性能指标）
  - 严重性分级：Critical / Medium / Low 三级问题分类
  - 分析模式：Quick（仅 Critical）/ Balanced（均衡）/ Deep（全面深度）
  - NanoVG 报告面板：实时可视化检测结果与统计摘要
  - 历史系统：JSON 持久化测试会话，支持回顾与趋势对比

  Use when: users need to
    (1) 自动检测游戏画面中的视觉缺陷（Z-fighting、纹理撕裂、UI 重叠等）
    (2) 在开发阶段持续监控渲染质量和帧率性能
    (3) 生成带严重性分级的视觉 QA 报告
    (4) 对比不同版本的视觉质量变化趋势
    (5) 用户说"视觉测试""画面质量""渲染检测""QA 自动化"
    (6) 用户说"visual test""rendering QA""screenshot analysis"
    (7) 需要自动化截图分析而非人工逐帧检查

  MUST trigger when:
    - 用户要求自动检测游戏画面的视觉质量问题
    - 用户需要自动化游戏 QA / 渲染质量测试
    - 用户说"视觉测试"或"visual QA"或"画面检测"

trigger-keywords:
  - 视觉测试
  - 画面质量
  - 渲染检测
  - QA自动化
  - 截图分析
  - Z-fighting
  - 纹理异常
  - UI重叠
  - 视觉缺陷
  - 帧分析
  - visual test
  - visual QA
  - rendering QA
  - screenshot analysis
  - frame analysis
  - game QA
  - 视觉质量
  - 画面检测
  - 渲染质量
---

# Auto Game Vision Tester — UrhoX Lua 自动化视觉质量测试框架

> **灵感来源**: [Sqeakzz/AutoGameVisionTester](https://github.com/Sqeakzz/AutoGameVisionTester)
>
> 将 Python + Grok Vision API 的自动化游戏截图视觉分析理念迁移到 UrhoX Lua 引擎，
> 提供帧捕获、基于规则的视觉分析、严重性分级、NanoVG 报告面板和历史管理等完整工具集。

---

## 一、概述

### 1.1 原始项目

原始 Python 项目通过 OS 级窗口截图 + Grok-4 Vision API 对游戏画面进行 AI 分析，
检测视觉缺陷（Z-fighting、纹理异常、UI 问题、光照问题、LOD 问题），
生成带 Critical/Medium/Low 三级严重性分类的 HTML 报告，支持感知哈希去重、
三种分析模式（Quick/Balanced/Deep）和历史记录系统。

### 1.2 UrhoX 迁移方案

在 UrhoX 中重新实现为**引擎内帧级视觉质量测试框架**：
- 使用引擎渲染管线内的帧数据替代 OS 级窗口截图
- 使用**基于规则的多维度分析算法**替代外部 Grok Vision API
- 使用 NanoVG 绘制实时报告面板替代 HTML 报告
- 保留感知哈希去重、三级严重性、三种模式、历史记录等核心概念

### 1.3 原始→迁移映射

| Python 原始模块 | Lua 模块 | 映射说明 |
|----------------|----------|---------|
| `capture.py` | `FrameCaptureEngine` | OS 窗口截图 → 引擎内帧采样 + 哈希去重 |
| `grok_vision.py` | `VisualAnalyzer` | Grok Vision API → 基于规则的多维度分析 |
| `report.py` | `ReportRenderer` | HTML 报告 → NanoVG 实时报告面板 |
| `main.py` (history) | `HistoryManager` | JSON 历史记录 → File API 持久化 |
| `main.py` (config) | `VisionConfig` | config.json → Lua table 配置 |
| `main.py` (menu/dashboard) | `TestRunner` | CLI/Web → 引擎内测试编排 |

### 1.4 模块架构

```
auto-game-vision-tester/
├── SKILL.md                              # 本文件（< 500 行）
└── references/
    ├── modules-implementation.md          # 六大模块完整实现
    └── integration-examples.md            # 集成示例与使用场景
```

**六大模块**：

| 模块 | 职责 | 文件位置 |
|------|------|---------|
| VisionConfig | 测试配置管理（间隔、模式、阈值） | modules-implementation.md §1 |
| FrameCaptureEngine | 帧采样、感知哈希去重 | modules-implementation.md §2 |
| VisualAnalyzer | 基于规则的多维度视觉分析 | modules-implementation.md §3 |
| ReportRenderer | NanoVG 实时报告面板 | modules-implementation.md §4 |
| HistoryManager | 测试会话 JSON 持久化 | modules-implementation.md §5 |
| TestRunner | 测试编排入口 | modules-implementation.md §6 |

---

## 二、核心 API 速查

### 2.1 帧性能数据（替代截图分析）

```lua
-- 获取当前 FPS
local fps = engine:GetFps()

-- 获取屏幕分辨率
local width = graphics:GetWidth()
local height = graphics:GetHeight()
local dpr = graphics:GetDPR()

-- 获取渲染统计
local stats = renderer:GetNumViews()
```

### 2.2 场景遍历（检测潜在视觉问题）

```lua
-- 遍历场景节点
local function traverseNodes(node, callback)
    callback(node)
    for i = 0, node:GetNumChildren(false) - 1 do
        traverseNodes(node:GetChild(i), callback)
    end
end

-- 检查模型组件
local model = node:GetComponent("StaticModel")
if model then
    local bb = model.boundingBox
    local materials = model:GetNumGeometries()
end
```

### 2.3 NanoVG 报告绘制

```lua
-- 在 NanoVGRender 事件中绘制报告面板
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, logicalW, logicalH, dpr)
    -- 报告面板绘制...
    nvgEndFrame(vg)
end
```

### 2.4 File API（历史持久化）

```lua
-- 写入测试报告 JSON
local file = File:new("vision_test/history.json", FILE_WRITE)
file:WriteString(cjson.encode(historyData))
file:Close()

-- 读取历史记录
local file = File:new("vision_test/history.json", FILE_READ)
local content = file:ReadString()
file:Close()
local historyData = cjson.decode(content)
```

---

## 三、视觉分析维度

### 3.1 检测项目（基于规则）

| 检测维度 | 检测方法 | 严重性 |
|---------|---------|--------|
| 帧率骤降 | FPS 低于阈值或帧间波动过大 | Critical |
| 节点重叠 | 两个不透明节点在同一位置（Z-fighting 风险） | Critical |
| UI 元素越界 | UI 元素超出屏幕范围 | Medium |
| 材质缺失 | StaticModel 无材质或使用默认材质 | Medium |
| 过多 Draw Call | 单帧渲染批次过多 | Medium |
| 相机裁剪异常 | 近裁剪面过大导致物体消失 | Low |
| 纹理尺寸不规范 | 非 2 的幂次纹理 | Low |
| 空节点冗余 | 场景中存在大量无组件空节点 | Low |

### 3.2 三种分析模式

| 模式 | 检测项 | 适用场景 |
|------|--------|---------|
| **Quick** | 仅 Critical 级别（帧率、节点重叠） | 快速冒烟测试 |
| **Balanced** | Critical + Medium | 日常开发迭代 |
| **Deep** | 全部维度 + 详细统计 | 发布前全面检查 |

### 3.3 严重性定义

| 级别 | 颜色 | 含义 |
|------|------|------|
| **Critical** | 红色 `#ff6b6b` | 影响可玩性或造成视觉崩溃 |
| **Medium** | 黄色 `#ffd93d` | 影响视觉质量但不影响可玩性 |
| **Low** | 绿色 `#6bcb77` | 优化建议或轻微瑕疵 |

---

## 四、配置说明

```lua
local config = {
    -- 捕获设置
    captureInterval = 2.0,      -- 帧采样间隔（秒）
    hashThreshold = 18,         -- 感知哈希相似度阈值（0-64）

    -- 分析设置
    mode = "balanced",          -- "quick" / "balanced" / "deep"
    fpsThreshold = 25,          -- 帧率警告阈值
    overlapDistance = 0.01,     -- 节点重叠检测距离（米）

    -- 报告设置
    maxHistory = 50,            -- 最大历史记录数
    showOverlay = true,         -- 是否显示实时检测浮层
    overlayPosition = "top-right", -- 浮层位置

    -- 分辨率参考
    resolution = "balanced",    -- "budget"(960x540) / "balanced"(1280x720) / "full"(1920x1080)
}
```

---

## 五、核心流程

```
Start()
  │
  ├─ 初始化 VisionConfig（加载配置）
  ├─ 初始化 FrameCaptureEngine（注册定时采样）
  ├─ 初始化 VisualAnalyzer（注册分析规则）
  ├─ 初始化 ReportRenderer（创建 NanoVG 字体）
  ├─ 初始化 HistoryManager（加载历史记录）
  └─ 初始化 TestRunner（注册热键 F9 触发分析）

HandleUpdate(dt)
  │
  ├─ FrameCaptureEngine:Update(dt)
  │   ├─ 累计定时器
  │   ├─ 到达间隔 → 采集当前帧数据（FPS、节点快照）
  │   ├─ 计算感知哈希
  │   └─ 哈希差异 > 阈值 → 加入分析队列
  │
  └─ TestRunner:Update(dt)
      └─ 检测热键 F9 → 触发 runAnalysis()

runAnalysis()
  │
  ├─ VisualAnalyzer:analyze(capturedFrames, mode)
  │   ├─ Quick: 仅检查帧率 + 节点重叠
  │   ├─ Balanced: + 材质缺失 + UI 越界 + Draw Call
  │   └─ Deep: + 纹理尺寸 + 空节点 + 相机裁剪 + 统计
  │
  ├─ ReportRenderer:render(results)
  │   └─ NanoVG 面板：严重性列表 + 摘要统计
  │
  └─ HistoryManager:save(results)
      └─ JSON 持久化到 vision_test/history.json

HandleNanoVGRender()
  │
  └─ ReportRenderer:draw(vg, w, h)
      ├─ 实时浮层（捕获计数、运行时间）
      └─ 报告面板（检测到热键触发后展示）
```

---

## 六、与其他 Skill 的关系

| Skill | 职责 | 本 Skill 的互补点 |
|-------|------|-------------------|
| `game-bug-checker` | 静态代码扫描 | 本 Skill 做**运行时视觉质量检测** |
| `game-performance` | 性能优化建议 | 本 Skill 提供**帧率监控数据**支撑性能分析 |
| `ai-game-tester` | RPG 行动/概率测试 | 本 Skill 聚焦**视觉/渲染**维度 |
| `game-review-improve` | 游戏整体审查 | 本 Skill 提供**自动化视觉 QA 数据** |

---

## 七、关键注意事项

### 7.1 UrhoX 引擎规则遵循

- 使用 `graphics:GetWidth()` / `graphics:GetHeight()` / `graphics:GetDPR()` 获取分辨率
- NanoVG 绘制**只在** `NanoVGRender` 事件中执行
- `nvgCreateFont()` **只在** `Start()` 中调用一次
- 使用 `File` API 进行文件读写，不使用 `io` 库
- 使用枚举常量（`KEY_F9`、`MOUSEB_LEFT`），不使用数字
- 事件数据访问使用 `eventData["Key"]:GetFloat()` 模式

### 7.2 性能考量

- 帧采样使用间隔定时器，不逐帧分析
- 感知哈希去重避免重复分析静态画面
- 场景遍历在分析触发时才执行，不在每帧 Update 中运行
- NanoVG 报告面板按需显示，不持续渲染

### 7.3 感知哈希实现

引擎内无 imagehash 库，使用简化的帧特征哈希：
- 基于 FPS 值 + 场景节点数 + 可见模型数构建帧指纹
- 帧指纹差异低于阈值则视为"静态帧"跳过

---

## 八、使用方式

### 8.1 基础集成

```lua
-- 在游戏 Start() 中初始化视觉测试
local VisionTester = require("scripts.VisionTester")
local tester = VisionTester.Create(scene_, {
    mode = "balanced",
    captureInterval = 2.0,
    showOverlay = true,
})

-- 在 Update 中驱动
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    tester:Update(dt)
end

-- 在 NanoVGRender 中绘制报告
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, logicalW, logicalH, dpr)
    tester:Draw(vg, logicalW, logicalH)
    nvgEndFrame(vg)
end
```

### 8.2 手动触发分析

```lua
-- 按 F9 手动触发（已内置）
-- 或代码触发：
tester:RunAnalysis()

-- 查看历史
local history = tester:GetHistory()
for i = 1, #history do
    print(history[i].timestamp, history[i].totalIssues)
end
```

### 8.3 导出报告数据

```lua
-- 获取最近一次分析结果
local report = tester:GetLastReport()
-- report.critical = { {desc="...", detail="..."}, ... }
-- report.medium = { ... }
-- report.low = { ... }
-- report.summary = { critical=2, medium=3, low=5, fps_avg=58.2 }
```

---

## 九、完整实现

详见 `references/` 目录：
- **modules-implementation.md** — 六大模块的完整 Lua 实现代码
- **integration-examples.md** — 集成到不同类型游戏的完整示例
