# 验证管线 8 项检查详细规则

> 本文档定义 ValidateModule 函数的 8 项检查的详细规则、判定逻辑和修复指南。

---

## 1. 验证流程总览

```
加载 init.lua
  ↓
V1: MODMETA 存在?
  ↓ pass
V2: 必填字段完整?
  ↓ pass
V3: 名称合规?
  ↓ pass
V4: 版本格式?
  ↓ pass
V5: 接口完整性?
  ↓ pass
V6: 生命周期方法?
  ↓ pass
V7: 依赖可声明?（警告级）
  ↓
V8: 无全局污染?（警告级）
  ↓
结果汇总 → 通过/失败/警告
```

**快速失败**: V1-V6 任何一项失败立即标记为 failed，但仍继续执行后续检查以收集完整报告。

---

## 2. 各项检查详解

### V1: MODMETA 存在

**检查方式**:
```lua
local moduleTable = require("modules." .. name .. ".init")
if type(moduleTable) ~= "table" then
    -- FAIL: init.lua 没有返回 table
end
if type(moduleTable.MODMETA) ~= "table" then
    -- FAIL: 缺少 MODMETA 字段
end
```

**常见失败原因**:
- init.lua 没有 `return` 语句
- 返回了非表类型（string、nil等）
- MODMETA 拼写错误

**修复**: 确保 init.lua 返回包含 `MODMETA` 字段的表。

---

### V2: 必填字段完整

**必填字段**: `name`, `version`, `description`, `provides`

**检查方式**:
```lua
local required = { "name", "version", "description", "provides" }
for _, field in ipairs(required) do
    if meta[field] == nil or meta[field] == "" then
        -- FAIL: 缺少必填字段
    end
end
-- provides 额外检查
if type(meta.provides) ~= "table" or #meta.provides == 0 then
    -- FAIL: provides 必须是非空数组
end
```

**修复**: 补全所有缺失字段，确保 provides 至少包含一个接口名。

---

### V3: 名称合规

**规则**:
1. 全小写: `[a-z0-9-]` 只允许字母、数字和连字符
2. 长度: 2-30 字符
3. 一致性: MODMETA.name 必须与目录名完全一致

**检查方式**:
```lua
if not meta.name:match("^[a-z0-9%-]+$") then
    -- FAIL: 包含非法字符
end
if #meta.name < 2 or #meta.name > 30 then
    -- FAIL: 长度不合规
end
if meta.name ~= dirName then
    -- FAIL: 与目录名不一致
end
```

**常见失败**:
- `name = "Combat"` → 应改为 `"combat"`
- `name = "combat_system"` → 应改为 `"combat-system"`（用连字符）
- 目录名 `combat/` 但 `name = "battle"` → 不一致

---

### V4: 版本格式

**规则**: 语义化版本 `MAJOR.MINOR.PATCH`，每部分是非负整数。

**检查方式**:
```lua
if not meta.version:match("^%d+%.%d+%.%d+$") then
    -- FAIL: 不符合 X.Y.Z 格式
end
```

**常见失败**:
- `version = "1.0"` → 缺少 PATCH，应为 `"1.0.0"`
- `version = "v1.0.0"` → 不要加 "v" 前缀
- `version = "1.0.0-beta"` → 暂不支持预发布标签

---

### V5: 接口完整性

**规则**: `provides` 数组中的每个名称，模块表中必须存在同名函数。

**检查方式**:
```lua
for _, ifaceName in ipairs(meta.provides) do
    if type(moduleTable[ifaceName]) ~= "function" then
        -- FAIL: 声明了接口但未实现
    end
end
```

**常见失败**:
- provides 声明了 `"GetState"` 但函数名写成了 `"getState"`（大小写不一致）
- 接口声明了但忘记实现
- 实现了但作为局部函数（不在模块表上）

---

### V6: 生命周期方法

**规则**: 必须实现 `Init(self, registry)` 方法。

**检查方式**:
```lua
if type(moduleTable.Init) ~= "function" then
    -- FAIL: 缺少 Init 方法
end
```

**可选生命周期方法**（不检查但建议）:
- `Update(self, dt)` — 如果模块需要每帧更新
- `Shutdown(self)` — 如果模块持有需要清理的资源

---

### V7: 依赖可声明（警告级）

**规则**: depends 和 optDepends 中的每个名称格式合法。

**检查方式**:
```lua
local allDeps = {}
for _, d in ipairs(meta.depends or {}) do table.insert(allDeps, d) end
for _, d in ipairs(meta.optDepends or {}) do table.insert(allDeps, d) end
for _, dep in ipairs(allDeps) do
    if not dep:match("^[a-z0-9%-]+$") then
        -- WARN: 依赖名称格式不合法
    end
end
```

**注意**: V7 是警告级，不阻断注册。实际依赖是否存在在注册阶段由 Supervisor 检查。

---

### V8: 无全局污染（警告级）

**规则**: 模块 init.lua 加载后不应引入新的全局变量。

**检查方式（概念）**:
```lua
-- 记录加载前的全局变量列表
local globalsBefore = {}
for k, _ in pairs(_G) do globalsBefore[k] = true end

-- 加载模块
require("modules." .. name .. ".init")

-- 比较加载后的全局变量
for k, _ in pairs(_G) do
    if not globalsBefore[k] then
        -- WARN: 模块引入了全局变量
    end
end
```

**注意**: 这是一个概念性检查。实际实现中通过代码审查识别全局变量。

**常见全局污染**:
- `COMBAT_DATA = {}` → 应改为 `local combatData = {}`
- 忘记 `local` 声明 → 变量自动成为全局

---

## 3. 验证结果汇总

### 3.1 结果级别

| 级别 | 含义 | 处理 |
|------|------|------|
| **passed** | 8 项全部通过 | 允许注册 |
| **warned** | V1-V6 通过，V7/V8 有警告 | 允许注册，记录警告 |
| **failed** | V1-V6 任一失败 | 阻断注册 |

### 3.2 报告模板

```markdown
### 模块验证报告: {name} v{version}

| # | 检查 | 状态 | 详情 |
|---|------|------|------|
| V1 | MODMETA 存在 | {✅/❌} | {说明} |
| V2 | 必填字段 | {✅/❌} | {说明} |
| V3 | 名称合规 | {✅/❌} | {说明} |
| V4 | 版本格式 | {✅/❌} | {说明} |
| V5 | 接口完整 | {✅/❌} | {说明} |
| V6 | 生命周期 | {✅/❌} | {说明} |
| V7 | 依赖声明 | {✅/⚠️} | {说明} |
| V8 | 全局污染 | {✅/⚠️} | {说明} |

**结果**: {passed / warned / failed}
{失败时: **阻断原因**: V{N} — {具体原因}}
{警告时: **警告**: {具体内容}}
```

---

## 4. 批量验证

Supervisor 启动时对所有发现的模块执行批量验证：

```markdown
### 批量验证结果

| 模块 | 结果 | 问题 |
|------|------|------|
| inventory | ✅ passed | - |
| combat | ✅ passed | - |
| dialogue | ⚠️ warned | V8: 全局变量 DIALOGUE_ACTIVE |
| quest | ❌ failed | V5: 缺少 AcceptQuest 实现 |

**统计**: 4 个模块，2 通过，1 警告，1 失败
**可注册**: inventory, combat, dialogue
**已阻断**: quest（需修复后重新验证）
```
