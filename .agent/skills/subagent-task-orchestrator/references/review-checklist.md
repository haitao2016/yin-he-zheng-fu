# Two-Phase Review Checklist — 两阶段审查清单

> 本文档提供子代理产出代码的标准化审查清单。
> 严格遵循：**先合规（Phase A），再质量（Phase B）。合规不通过不得进入质量审查。**

---

## Phase A：引擎规则合规审查

### P0 — 致命问题（必须修复，不修复不继续）

| # | 检查项 | 违规示例 | 正确做法 |
|---|-------|---------|---------|
| A1 | 代码是否写入 scripts/ 目录 | 写入 src/ 或根目录 | 所有用户代码在 scripts/ 下 |
| A2 | require 路径是否正确 | `require "scripts.main"` | `require "main"` |
| A3 | NanoVG 是否在 NanoVGRender 事件中 | 在 Update 中调用 nvgBeginFrame | 订阅 NanoVGRender 事件 |
| A4 | UI 是否使用 urhox-libs/UI | 使用 UIElement 原生 UI | `local UI = require("urhox-libs/UI")` |
| A5 | nil 变量是否有类型标注 | `local scene = nil` | `---@type Scene` 换行 `local scene = nil` |
| A6 | 数组索引是否从 1 开始 | `for i = 0, #arr - 1 do` | `for i = 1, #arr do` |
| A7 | 枚举是否用常量名 | `if button == 0 then` | `if button == MOUSEB_LEFT then` |
| A8 | 事件数据访问方式是否正确 | `eventData.TimeStep` | `eventData["TimeStep"]:GetFloat()` |

### P1 — 重要问题（应该修复）

| # | 检查项 | 违规示例 | 正确做法 |
|---|-------|---------|---------|
| B1 | 资源路径是否正确 | `"assets/Textures/a.png"` | `"Textures/a.png"` |
| B2 | 模块是否标准模式 | 全局函数散落 | `local M = {} / return M` |
| B3 | 是否有 Cleanup 函数 | 无资源释放 | 提供 `M.Cleanup()` |
| B4 | 坐标系是否正确 | Z-up 或右手系 | Y-up 左手系 |
| B5 | 材质 Technique 是否正确 | 猜测路径 `"Techniques/Diff.xml"` | `"Techniques/PBR/PBRNoTexture.xml"` |
| B6 | 长度单位是否为米 | 角色高度 100 | 角色高度 1.7 |

### P2 — 建议优化（不阻塞）

| # | 检查项 | 说明 |
|---|-------|------|
| C1 | CONFIG 表集中配置 | 魔法数字应提取到 CONFIG |
| C2 | 日志输出 | 首次交付应有 print 调试输出 |
| C3 | 注释 | 关键逻辑应有说明 |

### 合规审查判定

```
P0 全部通过 且 P1 全部通过
  --> 合规通过，进入质量审查

P0 有不通过项
  --> 合规失败，必须修复后重新审查

P0 全部通过但 P1 有不通过项
  --> 合规失败，应修复后重新审查
     （P1 累计不通过项 <= 2 且为低风险时，可由主代理手动修复后继续）
```

---

## Phase B：代码质量审查

### 可读性

| # | 检查项 | 违规示例 | 正确做法 |
|---|-------|---------|---------|
| D1 | 变量命名有意义 | `local a, b, c` | `local health, maxHealth, damage` |
| D2 | 函数命名清晰 | `local function do_it()` | `local function calculateDamage()` |
| D3 | 复杂逻辑有注释 | 50 行无注释的数学计算 | 关键步骤加注释 |
| D4 | 函数长度合理 | 单函数 200+ 行 | 拆分为多个 < 50 行的函数 |
| D5 | 一致的代码风格 | 混用 camelCase 和 snake_case | 统一命名风格 |

### 可维护性

| # | 检查项 | 违规示例 | 正确做法 |
|---|-------|---------|---------|
| E1 | 无重复代码 | 相同逻辑出现 3+ 次 | 抽取公共函数 |
| E2 | 模块职责单一 | 一个模块处理 UI + 数据 + 网络 | 拆分为独立模块 |
| E3 | 依赖关系清晰 | 循环 require | 单向依赖链 |
| E4 | 配置可调 | 硬编码数值散落各处 | 集中到 CONFIG 表 |

### 健壮性

| # | 检查项 | 违规示例 | 正确做法 |
|---|-------|---------|---------|
| F1 | nil 检查 | 直接访问可能为 nil 的表字段 | `if obj then obj.method() end` |
| F2 | 除零保护 | `local ratio = a / b` | `local ratio = b ~= 0 and a / b or 0` |
| F3 | 数组边界检查 | `arr[index]` 无边界验证 | `if index >= 1 and index <= #arr then` |
| F4 | 类型安全 | 数字和字符串混用 | 统一类型或显式转换 |

### 性能

| # | 检查项 | 违规示例 | 正确做法 |
|---|-------|---------|---------|
| G1 | Update 中无对象创建 | 每帧 `Vector3(x,y,z)` | 缓存为模块级变量 |
| G2 | 缓存重复计算 | 每帧重新查找节点 | Init 时缓存节点引用 |
| G3 | 字符串拼接优化 | 循环中 `s = s .. item` | `table.concat` |
| G4 | 避免不必要的全局访问 | 频繁使用全局变量 | `local` 化热路径变量 |

### 质量审查判定

```
所有类别无严重问题（D-G 类均无超过 3 项违规）
  --> 质量通过

某类别有 3+ 项违规
  --> 质量不通过
     严重问题（D4 函数过长、E1 大量重复、F1 无 nil 检查）
       --> 重新 dispatch 修复
     轻微问题（D5 风格不一致、G4 非热路径全局变量）
       --> 记录但不阻塞

单个严重问题
  --> 可由主代理评估：手动修复或重新 dispatch
```

---

## 审查执行流程

```
读取子代理产出的文件
  |
  v
Phase A: 合规审查
  |
  +-- P0 不通过 --> 列出问题 --> dispatch 修复 --> 重新 Phase A
  +-- P1 不通过 --> 评估风险 --> 修复或手动补 --> 重新 Phase A
  +-- 全通过 ---+
                |
                v
Phase B: 质量审查
  |
  +-- 严重问题 --> dispatch 修复 --> 重新 Phase B
  +-- 轻微问题 --> 记录 --> 通过（附注）
  +-- 全通过 ---+
                |
                v
标记任务完成，继续下一个
```

---

## 审查报告模板

每个任务审查完成后，生成简要审查报告：

```
## Task #N 审查报告: {任务名}

### Phase A: 合规审查
- 状态: 通过 / 不通过（第 X 轮通过）
- P0 检查: 8/8 通过
- P1 检查: 6/6 通过
- P2 建议: 2 条（已记录）

### Phase B: 质量审查
- 状态: 通过 / 通过（附注）
- 可读性: OK
- 可维护性: OK
- 健壮性: 1 条轻微问题（F4 类型安全）
- 性能: OK

### 修改文件
- scripts/Systems/XXX.lua (新增)
- scripts/main.lua (修改: 添加 require 和初始化)

### 遗留
- F4: 建议后续统一类型处理
```
