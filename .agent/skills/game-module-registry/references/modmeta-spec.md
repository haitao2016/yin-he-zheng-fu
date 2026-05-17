# MODMETA 元数据契约完整规范

> 本文档定义游戏模块必须遵守的 MODMETA 元数据契约格式、字段规则和扩展指南。

---

## 1. 契约总则

### 1.1 基本原则

- **自描述**: 每个模块通过 MODMETA 完整描述自身的能力和需求
- **可验证**: 所有字段可通过自动化工具验证
- **向后兼容**: 新增字段不破坏旧模块

### 1.2 声明位置

MODMETA 必须在模块入口文件 `init.lua` 中声明，作为返回表的直接字段：

```lua
local MyModule = {}
MyModule.MODMETA = { ... }  -- ← 在这里
return MyModule
```

---

## 2. 字段详细规范

### 2.1 name（必填）

```lua
name = "combat"
```

| 规则 | 说明 |
|------|------|
| 格式 | 全小写，仅 `[a-z0-9-]` |
| 长度 | 2-30 字符 |
| 唯一性 | 同一注册表内不可重复 |
| 一致性 | 必须与目录名完全一致（`modules/combat/` → `name = "combat"`） |

### 2.2 version（必填）

```lua
version = "1.2.3"
```

| 规则 | 说明 |
|------|------|
| 格式 | `MAJOR.MINOR.PATCH`（语义化版本） |
| MAJOR | 不兼容的接口变更 |
| MINOR | 向后兼容的功能新增 |
| PATCH | 向后兼容的问题修复 |

### 2.3 description（必填）

```lua
description = "回合制战斗系统，支持多人团队战斗"
```

| 规则 | 说明 |
|------|------|
| 长度 | 5-100 字符 |
| 语言 | 中文或英文均可 |
| 内容 | 一句话描述模块核心功能 |

### 2.4 depends（可选）

```lua
depends = { "inventory", "character" }
```

| 规则 | 说明 |
|------|------|
| 类型 | string 数组 |
| 含义 | 硬依赖，缺失任何一个则模块无法初始化 |
| 验证 | 注册时检查所有依赖模块是否已注册 |
| 循环 | 不允许循环依赖（A→B→A） |

### 2.5 optDepends（可选）

```lua
optDepends = { "audio", "analytics" }
```

| 规则 | 说明 |
|------|------|
| 类型 | string 数组 |
| 含义 | 软依赖，缺失时模块降级运行 |
| 验证 | 不阻断注册，仅记录警告 |
| 使用 | Init 中检查 `registry:HasModule()` 后条件启用 |

### 2.6 provides（必填）

```lua
provides = { "StartBattle", "EndBattle", "GetBattleState" }
```

| 规则 | 说明 |
|------|------|
| 类型 | string 数组 |
| 含义 | 模块对外公开的接口函数名 |
| 验证 | 每个名称在模块表中必须有同名函数 |
| 最少 | 至少 1 个接口（空模块无意义） |

### 2.7 author（可选）

```lua
author = "developer"
```

仅用于标识，不参与验证。

### 2.8 tags（可选）

```lua
tags = { "combat", "rpg", "turn-based" }
```

| 规则 | 说明 |
|------|------|
| 类型 | string 数组 |
| 用途 | 分类检索，`registry:FindByTag()` 使用 |
| 格式 | 全小写，`[a-z0-9-]` |

### 2.9 priority（可选）

```lua
priority = 30
```

| 规则 | 说明 |
|------|------|
| 类型 | number，0-100 |
| 默认 | 50 |
| 含义 | 同依赖层级内的初始化顺序（越小越先） |
| 注意 | 依赖关系优先于 priority（依赖的模块必然先初始化） |

---

## 3. 生命周期方法

### 3.1 必须实现

```lua
function Module:Init(registry)
```

- 参数: `registry` 是 ModuleRegistry 实例，可查询其他模块
- 职责: 初始化模块内部状态，获取依赖引用
- 时机: Supervisor 按拓扑排序调用

### 3.2 可选实现

```lua
function Module:Update(dt)
```

- 参数: `dt` 为帧间隔时间（秒）
- 职责: 每帧更新逻辑
- 时机: Supervisor 在 HandleUpdate 中调用

```lua
function Module:Shutdown()
```

- 职责: 清理资源、取消事件订阅
- 时机: Supervisor 卸载模块或游戏退出时调用

---

## 4. 扩展字段

用户可自定义额外字段，放在 MODMETA 内但不参与标准验证：

```lua
MODMETA = {
    name = "combat",
    version = "1.0.0",
    -- ...标准字段...

    -- 自定义扩展（前缀 x_ 表示扩展字段）
    x_config = {
        maxEnemies = 10,
        turnTimeout = 30,
    },
    x_debugMode = false,
}
```

**约定**: 扩展字段以 `x_` 前缀命名，避免与未来标准字段冲突。

---

## 5. 常见错误

| 错误 | 原因 | 修正 |
|------|------|------|
| V2: provides 为空 | 忘记声明接口 | 添加模块的公开函数名到 provides |
| V3: 名称不一致 | 目录名和 MODMETA.name 不同 | 确保两者完全一致 |
| V5: 接口缺失 | provides 中声明了但没实现 | 添加对应函数或从 provides 移除 |
| V6: Init 缺失 | 忘记实现 Init 方法 | 添加 `function Module:Init(registry) end` |
