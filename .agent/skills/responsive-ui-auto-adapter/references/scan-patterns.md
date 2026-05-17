# 扫描检测模式与判断逻辑

> 本文档定义了 SCAN 步骤中每个检测维度的具体 grep 模式、判断规则和边界条件。

---

## 1. UI 技术栈检测

### 1.1 urhox-libs/UI 组件系统

**检测模式**（任一匹配即确认）:

```bash
# 模式 1: require 调用
grep -E 'require\s*[\("]\s*urhox-libs/UI\s*[\)"]' scripts/*.lua scripts/**/*.lua

# 模式 2: UI.Init 调用
grep -E 'UI\.Init\s*\(' scripts/*.lua scripts/**/*.lua

# 模式 3: UI.SetRoot 调用
grep -E 'UI\.SetRoot\s*\(' scripts/*.lua scripts/**/*.lua

# 模式 4: UI 组件构造
grep -E 'UI\.(Panel|Label|Button|Slider|Image|ScrollView|SafeAreaView)\s*\{' scripts/*.lua scripts/**/*.lua
```

**确认条件**: 模式 1 匹配，或模式 2+3 同时匹配

### 1.2 raw NanoVG

**检测模式**:

```bash
# 模式 1: NanoVG 上下文创建
grep -E 'nvgCreate\s*\(' scripts/*.lua scripts/**/*.lua

# 模式 2: NanoVG 帧开始
grep -E 'nvgBeginFrame\s*\(' scripts/*.lua scripts/**/*.lua

# 模式 3: NanoVGRender 事件订阅
grep -E 'NanoVGRender' scripts/*.lua scripts/**/*.lua
```

**确认条件**: 模式 1 或模式 2 匹配

### 1.3 旧版原生 UI

**检测模式**:

```bash
# 模式 1: ui.root 访问
grep -E 'ui\.root' scripts/*.lua scripts/**/*.lua

# 模式 2: UIElement 类型
grep -E 'UIElement|CreateButton|CreateText|CreateWindow' scripts/*.lua scripts/**/*.lua

# 模式 3: 旧版 UI 样式设置
grep -E 'SetStyleAuto|SetDefaultStyle' scripts/*.lua scripts/**/*.lua
```

**确认条件**: 模式 1 匹配，或模式 2+3 任一匹配
**处理**: 不注入适配，提示用户迁移到 urhox-libs/UI

### 1.4 混合模式

**确认条件**: 同时检测到 §1.1 和 §1.2 的标志
**处理**: 分别对 UI 组件部分和 NanoVG 部分执行对应注入

---

## 2. 适配维度检测

### 2.1 缩放初始化

#### UI 组件系统

**已适配的判断**:

```bash
# 检测 UI.Scale 预设
grep -E 'scale\s*=\s*UI\.Scale\.' scripts/*.lua scripts/**/*.lua
```

匹配结果分析:
| 匹配内容 | 状态 | 操作 |
|---------|------|------|
| `UI.Scale.DEFAULT` | ✅ 最佳 | 不修改 |
| `UI.Scale.DPR` | ✅ 可用 | 提示可优化为 DEFAULT |
| `UI.Scale.DPR_DENSITY_ADAPTIVE` | ✅ 最佳 | 不修改 |
| `UI.Scale.DESIGN_RESOLUTION(...)` | ✅ 有效 | 不修改（用户有设计分辨率） |
| `UI.Scale.DESIGN_SHORT_SIDE(...)` | ✅ 有效 | 不修改 |
| 无匹配 | ❌ 缺失 | 注入模块 A |

**额外检查 — 硬编码 scale**:

```bash
# 检测硬编码数字 scale
grep -E 'scale\s*=\s*[0-9]+' scripts/*.lua scripts/**/*.lua
```

如匹配到 `scale = 1` / `scale = 2` 等 → 标记为需修复

#### NanoVG

**已适配的判断**:

```bash
# 检测 nvgBeginFrame 参数模式
grep -E 'nvgBeginFrame\s*\(' scripts/*.lua scripts/**/*.lua
```

匹配结果分析:
| 参数模式 | 状态 | 操作 |
|---------|------|------|
| `(vg, w/dpr, h/dpr, dpr)` | ✅ 模式 B | 不修改 |
| `(vg, logW, logH, dpr)` 且前面有 dpr 计算 | ✅ 模式 B | 不修改 |
| `(vg, designW, designH, scale)` | ✅ 模式 A | 不修改 |
| `(vg, w, h, 1.0)` 或 `(vg, w, h, 1)` | ❌ 错误 | 修正为模式 B |
| `(vg, physW, physH, dpr)` | ❌ 错误 | 修正为模式 B |

**关键**: 需要追溯变量来源判断 w/h 是物理还是逻辑分辨率

### 2.2 安全区域

**已适配的判断**:

```bash
# UI 组件: SafeAreaView
grep -E 'SafeAreaView' scripts/*.lua scripts/**/*.lua

# NanoVG: GetSafeAreaInsets
grep -E 'GetSafeAreaInsets' scripts/*.lua scripts/**/*.lua
```

| 匹配 | 状态 | 操作 |
|------|------|------|
| 有 SafeAreaView | ✅ 已有 | 检查 edges 是否完整 |
| 有 GetSafeAreaInsets | ✅ 已有 | 检查是否除以 DPR |
| 无匹配 | ❌ 缺失 | 注入模块 B / NV-B |

### 2.3 断点检测

**已适配的判断**:

```bash
# 自定义设备分类函数
grep -E 'getDeviceType|deviceType|device_type' scripts/*.lua scripts/**/*.lua

# 短边分类逻辑
grep -E 'shortSide|short_side|shortEdge' scripts/*.lua scripts/**/*.lua

# DeviceAdapter 模块
grep -E 'require.*DeviceAdapter' scripts/*.lua scripts/**/*.lua
```

| 匹配 | 状态 | 操作 |
|------|------|------|
| 有设备分类函数 | ✅ 已有 | 检查阈值是否合理 |
| 有短边计算 | ✅ 部分 | 检查是否除以 DPR |
| 有 DeviceAdapter | ✅ 已有 | 不注入 |
| 无匹配 | ❌ 缺失 | 注入模块 C |

### 2.4 响应式布局

**已适配的判断**:

```bash
# SimpleGrid 自适应列数
grep -E 'SimpleGrid.*minColumnWidth' scripts/*.lua scripts/**/*.lua

# 条件布局切换
grep -E 'getDeviceType.*phone.*tablet.*desktop' scripts/*.lua scripts/**/*.lua

# flexWrap 使用
grep -E 'flexWrap\s*=' scripts/*.lua scripts/**/*.lua

# 百分比尺寸
grep -E "width\s*=\s*['\"][\d]+%['\"]" scripts/*.lua scripts/**/*.lua
```

| 匹配 | 状态 | 操作 |
|------|------|------|
| 有 SimpleGrid + minColumnWidth | ✅ 已有 | 不修改 |
| 有条件布局切换 | ✅ 已有 | 不修改 |
| 仅百分比尺寸 | ⚠️ 部分 | 检查是否有 flexShrink |
| 无任何匹配 | ❌ 缺失 | 注入模块 D |

### 2.5 字体缩放

**已适配的判断**:

```bash
# 自适应字体函数
grep -E 'adaptFontSize|nvgAdaptFontSize|fontScale' scripts/*.lua scripts/**/*.lua

# 设备条件字体
grep -E 'fontSize.*getDeviceType\|fontSize.*device' scripts/*.lua scripts/**/*.lua
```

| 匹配 | 状态 | 操作 |
|------|------|------|
| 有自适应字体函数 | ✅ 已有 | 不修改 |
| 有条件字体逻辑 | ✅ 已有 | 不修改 |
| 无匹配 | ❌ 缺失 | 注入模块 E |

### 2.6 屏幕变化处理

**已适配的判断**:

```bash
# 尺寸变化检测
grep -E 'lastWidth|lastHeight|_lastW|_lastH|lastScreenW|lastScreenH' scripts/*.lua scripts/**/*.lua

# ScreenMode 事件（旧版）
grep -E 'ScreenMode' scripts/*.lua scripts/**/*.lua

# checkResize 函数
grep -E 'checkResize|checkScreenResize|checkScreenChange' scripts/*.lua scripts/**/*.lua
```

| 匹配 | 状态 | 操作 |
|------|------|------|
| 有尺寸变化检测变量 | ✅ 已有 | 不修改 |
| 有 ScreenMode 事件 | ⚠️ 旧版 | 提示可更新 |
| 有 checkResize 函数 | ✅ 已有 | 不修改 |
| 无匹配 | ❌ 缺失 | 注入模块 F |

### 2.7 DPR 处理

**已适配的判断**:

```bash
# GetDPR 调用
grep -E 'GetDPR\s*\(\s*\)|getDPR|:GetDPR' scripts/*.lua scripts/**/*.lua

# DPR 相关变量
grep -E 'local\s+dpr\s*=' scripts/*.lua scripts/**/*.lua
```

| 匹配 | 状态 | 操作 |
|------|------|------|
| 有 GetDPR 调用 | ✅ 已有 | 检查使用是否正确 |
| 无匹配且使用了 NanoVG | ❌ 缺失 | 通过模块 NV-A 修正 |
| 无匹配且仅用 UI 组件 | ⚠️ 可接受 | UI.Scale.DEFAULT 内部处理 |

---

## 3. 适配级别评估

### 3.1 计分规则

| 维度 | 已适配得分 |
|------|----------|
| 缩放初始化 | +1 |
| 安全区域 | +1 |
| 断点检测 | +1 |
| 响应式布局 | +1 |
| 字体缩放 | +1 |
| 屏幕变化处理 | +1 |
| DPR 处理 | +1 |

### 3.2 级别判定

| 总分 | 级别 | 含义 | 操作 |
|------|------|------|------|
| 0 | L0 | 无适配 | 完整注入全部模块 |
| 1-4 | L1 | 部分适配 | 补充注入缺失模块 |
| 5-7 | L2 | 基本完备 | 仅提优化建议 |

---

## 4. 主入口文件识别

### 4.1 查找 Start() 函数

```bash
# 查找包含 Start() 函数定义的文件
grep -l 'function\s\+Start\s*(' scripts/*.lua scripts/**/*.lua
```

### 4.2 查找 HandleUpdate 函数

```bash
# 查找包含 HandleUpdate 的文件
grep -l 'function\s\+HandleUpdate\s*(' scripts/*.lua scripts/**/*.lua
```

### 4.3 主入口优先级

1. 包含 `Start()` 函数的文件
2. 如果多个文件有 `Start()`，选择同时有 `HandleUpdate` 的
3. 如果仍有多个，选择 `main.lua` / `game.lua` / `app.lua`
4. 如果仍无法确定，询问用户

---

## 5. 边界条件与误判处理

### 5.1 误判风险表

| 场景 | 风险 | 处理 |
|------|------|------|
| 注释中出现检测关键词 | 误判为已适配 | 排除 `--` 开头的行 |
| 字符串中出现关键词 | 误判 | 排除引号内内容 |
| 条件编译/平台分支中的代码 | 可能漏判 | 两个分支都检查 |
| require 路径拼写变体 | 漏判 | 同时检测 `"` 和 `'` |
| 变量别名 | 漏判 | 追踪 local 赋值 |

### 5.2 安全检测模式

在 grep 前过滤注释和字符串：

```bash
# 排除纯注释行
grep -v '^\s*--' file.lua | grep -E 'PATTERN'

# 注意: 行内注释后的代码仍会被检测，这是期望行为
# 例: local x = 1 -- comment  → 会匹配 "local x"
```

### 5.3 多文件项目处理

```
1. 先扫描所有 .lua 文件的 UI 技术栈
2. 汇总到一个统一报告
3. 适配维度检测在所有文件中查找
4. 注入仅在主入口文件执行
5. 工具函数可能生成为独立模块
```

---

## 6. 扫描报告模板

```
## 适配扫描报告

**项目结构**:
- scripts/ 文件数: N
- 主入口: scripts/main.lua
- 总代码行数: XXXX

**UI 技术栈**: urhox-libs/UI 组件系统

**适配维度扫描**:

| # | 维度 | 状态 | 检测依据 | 建议操作 |
|---|------|------|---------|---------|
| 1 | 缩放初始化 | ❌ | 未找到 UI.Scale | 注入 A1 |
| 2 | 安全区域 | ❌ | 未找到 SafeAreaView | 注入 B1 |
| 3 | 断点检测 | ❌ | 未找到设备分类 | 注入 C1 |
| 4 | 响应式布局 | ⚠️ | 有百分比但无 flexShrink | 补充 flexShrink |
| 5 | 字体缩放 | ❌ | 全部硬编码 fontSize | 注入 E1 |
| 6 | 屏幕变化 | ❌ | 无检测逻辑 | 注入 F1 |
| 7 | DPR 处理 | ❌ | 未调用 GetDPR | 通过 Scale 处理 |

**适配级别**: L0（无适配）— 得分 0/7

**推荐注入模块**: A1, B1, C1, D3, E1, F1
```

