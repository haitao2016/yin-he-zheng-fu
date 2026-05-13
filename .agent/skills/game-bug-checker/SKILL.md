---
name: game-bug-checker
description: |
  UrhoX Lua 游戏 BUG 自动检查与修复工具。
  通过静态代码扫描和模式匹配，检测 17 类已验证的引擎陷阱和常见编程错误，
  输出分级诊断报告并提供一键修复建议。

  Use when users need to:
    (1) 检查游戏代码中的 BUG 或潜在问题
    (2) 代码写完后想做一次质量检查
    (3) 游戏运行异常但不知道原因
    (4) 排查特定错误信息
    (5) 发布前做最终代码审查
    (6) 用户说"检查BUG""查错""为什么不工作""帮我排查"

  MUST trigger when:
    - 用户报告运行时错误并贴出错误信息
    - 用户说"检查代码""审查代码""review"且目标是 scripts/ 目录

  trigger-keywords:
    - BUG
    - 检查
    - 查错
    - 排查
    - debug
    - 修复
    - fix
    - review
    - 审查
    - 为什么不工作
    - 报错
    - 崩溃
    - 不显示
    - 无效
version: "1.0.0"
metadata:
  author: "game-bug-checker"
  tags: ["debugging", "quality", "static-analysis", "bug-fix", "UrhoX"]
---

# Game Bug Checker - UrhoX Lua 游戏 BUG 检查与修复

## 身份

你是一位 UrhoX Lua 游戏代码质量检查专家。你的工作是通过**静态扫描 + 模式匹配**快速定位代码中的 BUG、陷阱和潜在问题，输出分级诊断报告，并为每个问题提供具体的修复方案。

---

## 核心工作流程

### 阶段 1: 扫描 (Scan)

对 `scripts/` 目录执行全量静态扫描，按优先级检测 **4 个严重级别、17 类 BUG 模式**：

```
scripts/ 全部 .lua 文件
  |
[致命级] -> 立即修复，否则游戏无法正常运行
[高危级] -> 大概率导致运行时错误
[中危级] -> 可能导致显示异常或行为不符预期
[低危级] -> 代码质量问题，建议改进
  |
输出诊断报告
```

### 阶段 2: 诊断 (Diagnose)

对每个发现的问题输出：

| 字段 | 说明 |
|------|------|
| 文件:行号 | 精确定位 |
| 严重级别 | 致命 / 高 / 中 / 低 |
| BUG 类型 | 17 类中的哪一类 |
| 问题描述 | 一句话说明 |
| 当前代码 | 标记错误的代码片段 |
| 修复方案 | 正确的代码片段 |

### 阶段 3: 修复 (Fix)

用户确认后，逐个应用修复：
1. 标记该问题为已修复
2. 如果涉及多处相同模式，批量修复
3. 修复完成后重新扫描确认

---

## 17 类 BUG 检测清单

详见 [references/bug-patterns.md](references/bug-patterns.md) 获取完整的错误代码/正确代码对照和检测命令。

以下是快速索引：

### 致命级 (Critical) - 4 类

| ID | 名称 | 检测关键词 |
|----|------|-----------|
| C1 | Box2D 脚底传感器碰撞失效 | `trigger = true` 缺 `center` |
| C2 | 3D 角色控制器挂墙 | `SetLinearVelocity` 直接控制移动 |
| C3 | eventData 访问格式错误 | `eventData.X` 或缺类型转换 |
| C4 | SetEnabled 无法隐藏子节点 | `SetEnabled(false)` 非 `SetDeepEnabled` |

### 高危级 (High) - 3 类

| ID | 名称 | 检测关键词 |
|----|------|-----------|
| H1 | 数组索引从 0 开始 | `for i = 0,` 或 `[0]` |
| H2 | Unicode 转义语法错误 | `\uXXXX` 缺花括号 |
| H3 | 数字常量代替枚举值 | `button == 0` / `key == 32` |

### 中危级 (Medium) - 7 类

| ID | 名称 | 检测关键词 |
|----|------|-----------|
| M1 | NanoVG 文本不显示 | 有 `nvgText` 无 `nvgCreateFont` |
| M2 | NanoVG 图形不显示 | `nvgBeginFrame` 不在 `NanoVGRender` 事件 |
| M3 | UI 层级冲突 | 同文件 `nvgCreate` + `UI.Init` |
| M4 | SetMode 已禁用 | `SetMode` 调用 |
| M5 | nvgCreateFont 每帧调用 | `nvgCreateFont` 在渲染回调中 |
| M6 | orthoSize 缺少 0.5 因子 | 手动计算中 `orthoSize` 没乘 0.5 |
| M7 | 小物体 Collision Margin 过大 | 小碰撞体缺 `SetMargin` |

### 低危级 (Low) - 3 类

| ID | 名称 | 检测关键词 |
|----|------|-----------|
| L1 | table.unpack 位置陷阱 | `table.unpack` 不在表构造器末尾 |
| L2 | GetRankList player 类型误用 | `.player:` 字符串操作 |
| L3 | 不必要的 MarkDirty 调用 | `MarkDirty` 用于相机 |

---

## 扫描命令集

诊断时按以下顺序执行检测：

```bash
# === 致命级 ===
# C1: Box2D 脚底传感器
grep -rn "trigger = true" scripts/ | grep -v "center"

# C2: 3D 角色控制器挂墙
grep -rn "SetLinearVelocity" scripts/

# C3: eventData 访问错误
grep -rn 'eventData\.' scripts/ | grep -v 'eventData\["' | grep -v 'eventData:Get'

# C4: SetEnabled vs SetDeepEnabled
grep -rn 'SetEnabled(false)' scripts/ | grep -v 'DeepEnabled'

# === 高危级 ===
# H1: 数组索引
grep -rn 'for i = 0,' scripts/
grep -rn '\[0\]' scripts/

# H2: Unicode 转义
grep -rnP '\\u[0-9A-Fa-f]{4}[^{]' scripts/ 2>/dev/null

# H3: 数字常量
grep -rn 'button == [0-9]' scripts/
grep -rn 'key == [0-9]' scripts/

# === 中危级 ===
# M1: NanoVG 缺少字体
for f in $(grep -rln 'nvgText' scripts/ 2>/dev/null); do grep -L 'nvgCreateFont' "$f" 2>/dev/null; done

# M2: NanoVG 渲染事件
grep -rln 'nvgBeginFrame' scripts/ 2>/dev/null | xargs grep -L 'NanoVGRender' 2>/dev/null

# M3: UI 混用
grep -rln 'nvgCreate' scripts/ 2>/dev/null | xargs grep -l 'UI.Init\|UI.SetRoot' 2>/dev/null

# M4: SetMode
grep -rn 'SetMode' scripts/ | grep -i 'graphic'

# M5: nvgCreateFont 泄漏
grep -rn 'nvgCreateFont' scripts/ | grep -vi 'start\|init\|setup\|create'

# M6: orthoSize 因子
grep -rn 'orthoSize' scripts/ | grep -v '0\.5'

# M7: Collision Margin
grep -rln 'SetCylinder\|SetSphere' scripts/ 2>/dev/null | xargs grep -L 'SetMargin' 2>/dev/null

# === 低危级 ===
# L1: table.unpack
grep -rn 'table.unpack' scripts/

# L2: player 字段类型
grep -rn '\.player:' scripts/

# L3: MarkDirty
grep -rn 'MarkDirty' scripts/
```

---

## 诊断报告输出格式

```
========================================
  UrhoX 游戏 BUG 诊断报告
========================================
扫描范围: scripts/ (XX 个文件, XXXX 行代码)
发现问题: X 个致命 / X 个高危 / X 个中危 / X 个低危

----------------------------------------
[致命] C3: eventData 访问格式错误
  文件: scripts/main.lua:47
  问题: 使用点语法访问 eventData
  当前: local dt = eventData.TimeStep
  修复: local dt = eventData["TimeStep"]:GetFloat()
----------------------------------------
[高危] H1: 数组索引从 0 开始
  文件: scripts/game.lua:123
  问题: 循环从 0 开始，Lua 数组索引从 1 开始
  当前: for i = 0, #enemies - 1 do
  修复: for i = 1, #enemies do
----------------------------------------

========================================
  修复建议
========================================
致命级问题必须立即修复。
是否自动应用修复？(逐个确认 / 全部应用 / 跳过)
```

---

## 错误信息速查表

当用户贴出错误信息时，快速匹配：

| 错误信息 | 最可能的 BUG 类型 |
|---------|------------------|
| `attempt to call method 'GetInt'` | C3: eventData 访问格式 |
| `attempt to index a nil value` | H1: 数组索引 / C4: SetEnabled |
| `missing '{' near '"\u...'` | H2: Unicode 转义 |
| `Null pointer access` | C4: SetEnabled / 节点未创建 |
| 按空格无法跳跃 | C1: Box2D 脚底传感器 |
| 角色撞墙卡住 | C2: 3D 角色控制器 |
| NanoVG 文本不显示 | M1: 缺少字体初始化 |
| NanoVG 什么都不显示 | M2: 错误的渲染事件 |
| SetMode 无效果 | M4: SetMode 已禁用 |
| 鼠标左键无响应 | H3: 数字常量代替枚举 |

---

## 误报过滤规则

扫描结果需要人工判断的场景：

1. **C4**: 叶子节点（无子节点）使用 `SetEnabled` 是正确的
2. **C3**: `eventData:GetInt("X")` 是合法的新 API
3. **H1**: C 库返回的 0-based 索引可能是正确的
4. **M5**: 非循环的初始化函数中调用 `nvgCreateFont` 不是泄漏
5. **M7**: 只有小于 0.1m 的物体才需要调小 margin

---

## 与引擎核心规则的关系

本 Skill 的所有检测规则均来源于引擎核心规则，不引入额外约束：

| Skill BUG 类型 | 对应引擎规则 |
|---------------|-------------|
| C1 (Box2D) | CLAUDE.md 诊断: 按空格无法跳跃 |
| C2 (角色控制器) | CLAUDE.md 规则 #13.5 |
| C3 (eventData) | CLAUDE.md 规则 #3 |
| C4 (SetDeepEnabled) | engine-docs gotchas |
| H1 (数组索引) | CLAUDE.md 规则 #4 |
| H2 (Unicode) | lua-scripting-guide 关键规则 |
| H3 (枚举值) | CLAUDE.md 规则 #12 |
| M1-M3 (NanoVG) | CLAUDE.md 规则 #6, #7, #8, #10 |
| M4 (SetMode) | CLAUDE.md 规则 #0.8 |

本 Skill 不会修改引擎代码、不引入新编码规范、不执行危险操作。
