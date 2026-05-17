---
name: game-module-registry
description: >-
  UrhoX Lua 游戏模块注册中心与插件化架构。将 LobsterBio 的 ComponentRegistry/AQUADIF
  元数据契约/插件验证管线适配为 Lua 游戏开发的模块化治理方案。
  提供统一的模块注册表（ModuleRegistry）管理游戏子系统的发现、加载和依赖解析；
  每个模块必须声明 MODMETA 元数据契约（名称/版本/依赖/接口/作者），
  通过 8 项验证门禁才能注册；主管调度器（Supervisor）按依赖拓扑排序自动编排
  模块初始化顺序，支持热插拔和运行时卸载。
  Use when users need to
  (1) 将游戏拆分为可插拔的独立模块并统一注册管理,
  (2) 为游戏模块定义标准化元数据契约（版本/依赖/接口声明）,
  (3) 验证模块合规性（接口完整性、依赖可达、命名规范等 8 项检查）,
  (4) 按依赖拓扑排序自动编排模块初始化顺序,
  (5) 需要模块热插拔或运行时动态加载/卸载子系统,
  (6) 用户说"模块注册""插件化""组件注册""module registry""plugin system",
  (7) 用户说"模块验证""接口契约""元数据声明""dependency resolve",
  (8) 用户说"模块化架构""子系统编排""supervisor""模块管理器",
  (9) 项目包含 5+ 个独立子系统需要统一治理时主动建议,
  (10) 用户说"lobster""registry""AQUADIF"。
  MUST trigger when: 用户明确要求模块注册中心、插件化架构或模块验证管线。
  Should proactively suggest when: 项目已有 5+ 个 Lua 模块文件且缺乏统一管理。
metadata:
  version: "1.0.0"
  source: "https://clawhub.ai/cewinharhar/lobsterbio-dev"
  tags: [module-registry, plugin, metadata-contract, validation, supervisor, dependency]
---

# Game Module Registry — 游戏模块注册中心与插件化架构

> 将 LobsterBio 的 ComponentRegistry + AQUADIF 元数据契约 + 插件验证管线
> 适配为 UrhoX Lua 游戏开发的模块化治理方案。
>
> - 模块元数据契约规范 → `references/modmeta-spec.md`
> - 验证管线 8 项检查 → `references/validation-pipeline.md`

---

## §1 核心概念

### 1.1 概念映射（源 → UrhoX 适配）

| LobsterBio 原始概念 | UrhoX 适配概念 | 说明 |
|---------------------|---------------|------|
| ComponentRegistry | ModuleRegistry | 模块注册中心，统一管理游戏子系统 |
| AQUADIF 元数据 | MODMETA 契约 | 模块必须声明的标准化元数据 |
| validate_plugin (8项) | ValidateModule (8项) | 模块注册前的合规验证 |
| PEP 420 命名空间包 | Lua require 命名空间 | `scripts/modules/{name}/init.lua` 约定 |
| Supervisor 主管编排 | Supervisor 调度器 | 按依赖拓扑排序编排初始化 |
| IR (Instance Record) | ModuleRecord | 模块运行时实例记录 |
| @tool 装饰器 | 接口声明表 | `MODMETA.provides` 接口列表 |
| entry points 自动发现 | require 扫描 + 注册 | 启动时扫描 modules/ 目录 |

### 1.2 架构总览

```
scripts/
├── main.lua                    # 入口，启动 Supervisor
├── GameConfig.lua              # 游戏配置
├── ModuleRegistry.lua          # 模块注册中心（核心）
├── Supervisor.lua              # 主管调度器（核心）
└── modules/                    # 模块目录
    ├── combat/                 # 战斗模块
    │   ├── init.lua            # 模块入口 + MODMETA
    │   ├── CombatSystem.lua    # 实现
    │   └── ...
    ├── inventory/              # 背包模块
    │   ├── init.lua
    │   └── ...
    ├── dialogue/               # 对话模块
    │   ├── init.lua
    │   └── ...
    └── ...
```

### 1.3 模块生命周期

```
发现 → 验证 → 注册 → 依赖解析 → 初始化 → 运行 → 卸载（可选）
```

| 阶段 | 执行者 | 说明 |
|------|--------|------|
| 发现 | Supervisor | 扫描 `scripts/modules/*/init.lua` |
| 验证 | ValidateModule | 8 项合规检查（见 §3） |
| 注册 | ModuleRegistry | 写入注册表，分配 ModuleRecord |
| 依赖解析 | Supervisor | 拓扑排序，检测循环依赖 |
| 初始化 | Supervisor | 按排序顺序调用 `module:Init()` |
| 运行 | 各模块自身 | 处理事件、更新逻辑 |
| 卸载 | Supervisor | 调用 `module:Shutdown()`，移除注册 |

---

## §2 MODMETA 元数据契约

### 2.1 契约结构

每个模块的 `init.lua` 必须返回包含 `MODMETA` 字段的表：

```lua
-- scripts/modules/combat/init.lua

local CombatModule = {}

--- 模块元数据契约（必须声明）
CombatModule.MODMETA = {
    -- 必填字段
    name        = "combat",                -- 模块唯一标识符（全小写，无空格）
    version     = "1.0.0",                 -- 语义化版本号
    description = "回合制战斗系统",          -- 模块描述

    -- 依赖声明
    depends     = { "inventory", "character" }, -- 硬依赖（缺失则报错）
    optDepends  = { "audio" },                  -- 软依赖（缺失则降级）

    -- 接口声明
    provides    = {                         -- 本模块对外提供的接口
        "StartBattle",                      -- function(enemyList) → battleId
        "EndBattle",                        -- function(battleId) → result
        "GetBattleState",                   -- function(battleId) → state
    },

    -- 元信息
    author      = "developer",             -- 作者
    tags        = { "combat", "rpg" },     -- 标签，用于分类检索
    priority    = 50,                      -- 初始化优先级（0-100，越小越先）
}

--- 模块初始化（Supervisor 调用）
function CombatModule:Init(registry)
    -- registry 可用于查询其他模块的接口
    self.inventory = registry:GetModule("inventory")
    -- ... 初始化逻辑
end

--- 模块每帧更新（可选，Supervisor 在 HandleUpdate 中调用）
function CombatModule:Update(dt)
    -- ... 更新逻辑
end

--- 模块关闭（Supervisor 调用）
function CombatModule:Shutdown()
    -- ... 清理资源
end

return CombatModule
```

### 2.2 字段规范

| 字段 | 类型 | 必填 | 规则 |
|------|------|------|------|
| `name` | string | ✅ | 全小写，仅 `[a-z0-9-]`，与目录名一致 |
| `version` | string | ✅ | 语义化版本 `MAJOR.MINOR.PATCH` |
| `description` | string | ✅ | 不超过 100 字 |
| `depends` | string[] | ❌ | 硬依赖模块名列表 |
| `optDepends` | string[] | ❌ | 软依赖模块名列表 |
| `provides` | string[] | ✅ | 对外接口函数名列表 |
| `author` | string | ❌ | 作者标识 |
| `tags` | string[] | ❌ | 分类标签 |
| `priority` | number | ❌ | 0-100，默认 50 |

### 2.3 接口契约规则

`provides` 中声明的每个接口名，模块表中**必须存在同名函数**：

```lua
-- MODMETA.provides = { "StartBattle", "EndBattle" }
-- 则模块必须实现：
function CombatModule:StartBattle(enemyList) ... end
function CombatModule:EndBattle(battleId) ... end

-- ❌ 缺少声明的接口 → 验证失败
-- ❌ 接口存在但不是函数 → 验证失败
```

---

## §3 验证管线（ValidateModule）

### 3.1 八项检查

模块注册前必须通过以下 8 项验证：

| # | 检查项 | 规则 | 失败处理 |
|---|--------|------|---------|
| V1 | MODMETA 存在 | init.lua 返回的表必须包含 `MODMETA` 字段 | 🔴 阻断注册 |
| V2 | 必填字段完整 | `name`, `version`, `description`, `provides` 不为空 | 🔴 阻断注册 |
| V3 | 名称合规 | `name` 全小写 `[a-z0-9-]`，与目录名一致 | 🔴 阻断注册 |
| V4 | 版本格式 | `version` 符合 `X.Y.Z` 语义化版本 | 🔴 阻断注册 |
| V5 | 接口完整性 | `provides` 中每个名称对应模块表中的函数 | 🔴 阻断注册 |
| V6 | 生命周期方法 | 必须实现 `Init(registry)` 方法 | 🔴 阻断注册 |
| V7 | 依赖可声明 | `depends` 中的模块名格式合法 | 🟡 警告 |
| V8 | 无全局污染 | 模块 init.lua 不创建全局变量 | 🟡 警告 |

### 3.2 验证输出格式

```markdown
### 模块验证报告: {module_name}

| # | 检查项 | 状态 | 说明 |
|---|--------|------|------|
| V1 | MODMETA 存在 | ✅ | MODMETA 已声明 |
| V2 | 必填字段完整 | ✅ | name/version/description/provides 齐全 |
| V3 | 名称合规 | ✅ | "combat" 符合 [a-z0-9-] |
| V4 | 版本格式 | ✅ | "1.0.0" 符合 X.Y.Z |
| V5 | 接口完整性 | ❌ | 缺少 GetBattleState 的实现 |
| V6 | 生命周期方法 | ✅ | Init() 已实现 |
| V7 | 依赖可声明 | ✅ | depends 格式合法 |
| V8 | 无全局污染 | ⚠️ | 发现全局变量 BATTLE_DATA |

**结果**: ❌ 未通过（V5 失败）
**修复建议**: 在 CombatModule 中添加 GetBattleState 函数实现
```

### 3.3 Hard Gate 规则

**V1-V6 是硬性门禁**：任何一项失败，模块不可注册。
**V7-V8 是软性警告**：记录日志，允许注册但标记为 "warned"。

---

## §4 ModuleRegistry 注册中心

### 4.1 注册表结构

```lua
-- ModuleRegistry.lua 核心结构
local ModuleRegistry = {
    _modules = {},      -- { name → ModuleRecord }
    _loadOrder = {},    -- 按拓扑排序的初始化顺序
    _initialized = false,
}
```

### 4.2 ModuleRecord 实例记录

```lua
-- 每个已注册模块的运行时记录
ModuleRecord = {
    name        = "combat",
    version     = "1.0.0",
    status      = "active",    -- "registered" | "active" | "shutdown" | "error"
    instance    = CombatModule, -- 模块实例引用
    modmeta     = { ... },     -- 完整 MODMETA 副本
    registeredAt = os.time(),
    validationResult = { ... }, -- 8 项验证结果
}
```

### 4.3 核心 API

```lua
-- 注册模块（内部使用，Supervisor 调用）
ModuleRegistry:Register(moduleName, moduleTable) → boolean, errorMsg

-- 获取已注册模块
ModuleRegistry:GetModule(name) → moduleInstance | nil

-- 查询模块是否已注册
ModuleRegistry:HasModule(name) → boolean

-- 获取模块提供的接口
ModuleRegistry:GetInterface(moduleName, interfaceName) → function | nil

-- 列出所有已注册模块
ModuleRegistry:ListModules() → { ModuleRecord... }

-- 按标签搜索模块
ModuleRegistry:FindByTag(tag) → { ModuleRecord... }

-- 卸载模块（调用 Shutdown 并移除注册）
ModuleRegistry:Unregister(name) → boolean
```

---

## §5 Supervisor 主管调度器

### 5.1 职责

| 职责 | 说明 |
|------|------|
| 模块发现 | 扫描 `scripts/modules/*/init.lua` |
| 验证 | 调用 ValidateModule 8 项检查 |
| 注册 | 将通过验证的模块写入 ModuleRegistry |
| 依赖解析 | 拓扑排序，检测循环依赖 |
| 初始化编排 | 按排序顺序调用 `module:Init(registry)` |
| 运行时调度 | 在 HandleUpdate 中调用所有活跃模块的 `Update(dt)` |
| 卸载 | 逆序调用 `module:Shutdown()` |

### 5.2 启动流程

```lua
-- main.lua 中的启动方式
local Supervisor = require("Supervisor")
local ModuleRegistry = require("ModuleRegistry")

function Start()
    -- ... 场景初始化 ...

    -- 启动模块系统
    Supervisor:Boot(ModuleRegistry, {
        modulesPath = "modules",    -- 相对于 scripts/ 的模块目录
        autoDiscover = true,        -- 自动扫描发现
        strictMode = true,          -- V1-V6 任何失败阻止启动
    })
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    Supervisor:UpdateAll(dt)     -- 调度所有模块的 Update
end
```

### 5.3 依赖拓扑排序

```
输入: 所有模块的 depends 声明
  ↓
构建有向无环图 (DAG)
  ↓
├─ 检测到环 → 报告循环依赖错误，中止启动
└─ 无环 → 拓扑排序
  ↓
按排序结果确定初始化顺序
  ↓
priority 字段作为同层排序的二级排序键
```

**循环依赖处理**:

```markdown
### ❌ 循环依赖检测

发现模块间的循环依赖，无法确定初始化顺序：

```
combat → inventory → character → combat
```

**建议**:
1. 将共享逻辑提取为独立的 "core" 模块
2. 使用 `optDepends` 替代 `depends` 打破环
3. 通过事件系统解耦（模块间用事件通信而非直接引用）
```

### 5.4 软依赖降级

```lua
-- 模块初始化时检查软依赖
function MyModule:Init(registry)
    if registry:HasModule("audio") then
        self.audio = registry:GetModule("audio")
        self.soundEnabled = true
    else
        self.soundEnabled = false
        print("[MyModule] audio 模块未加载，音效已禁用")
    end
end
```

---

## §6 模块脚手架生成

### 6.1 脚手架命令

当用户说"创建模块 {name}"或"添加子系统 {name}"时，生成标准模块目录：

```
scripts/modules/{name}/
├── init.lua           # 模块入口 + MODMETA 声明
└── {Name}System.lua   # 核心逻辑（可选，按需创建更多文件）
```

### 6.2 init.lua 模板

```lua
-- scripts/modules/{name}/init.lua
-- 模块: {name}
-- 描述: {用户提供的描述}
-- 版本: 1.0.0

local {Name}Module = {}

{Name}Module.MODMETA = {
    name        = "{name}",
    version     = "1.0.0",
    description = "{用户提供的描述}",
    depends     = {},
    optDepends  = {},
    provides    = {},
    author      = "developer",
    tags        = {},
    priority    = 50,
}

function {Name}Module:Init(registry)
    print("[{name}] 模块初始化")
    -- TODO: 初始化逻辑
end

function {Name}Module:Update(dt)
    -- TODO: 每帧更新逻辑（可选）
end

function {Name}Module:Shutdown()
    print("[{name}] 模块关闭")
    -- TODO: 清理资源
end

return {Name}Module
```

---

## §7 UrhoX 引擎规则集成

### 7.1 模块代码规则检查

每个模块在验证阶段额外检查 UrhoX 引擎合规性：

| 引擎规则 | 在模块中的检查方式 |
|---------|------------------|
| #1 代码在 scripts/ | 模块位于 `scripts/modules/` 下 |
| #1.5 资源路径 | 模块内资源引用不加 `assets/` 前缀 |
| #4 数组索引从 1 | 代码审查时检查 |
| #9.6 材质 Technique | 涉及材质的模块使用 PBRNoTexture 系列 |
| #10 UI 系统 | UI 相关模块使用 urhox-libs/UI |
| #12 枚举值 | 输入处理模块使用枚举而非数字 |

### 7.2 模块间通信方式

| 方式 | 适用场景 | UrhoX 兼容 |
|------|---------|-----------|
| 直接调用 | 强耦合、同步操作 | `registry:GetModule("x"):DoSomething()` |
| 事件系统 | 松耦合、异步通知 | `SendEvent("CombatEnd", { result = "win" })` |
| 共享数据 | 全局状态（谨慎使用） | 通过 GameConfig 模块中转 |

**推荐**: 优先使用 UrhoX 事件系统（`SubscribeToEvent` / `SendEvent`）实现模块间通信。

---

### 7.3 构建验证集成

模块注册完成后，**必须调用 UrhoX MCP build 工具**验证整体项目可编译：

```
模块发现 → 8项验证 → 注册 → 依赖排序 → 初始化
                                          ↓
                                  调用 UrhoX MCP build 工具
                                          ↓
                                  构建通过 → 交付
                                  构建失败 → 修复后重新 build
```

**关键规则**：
- 每次新增或修改模块后，Supervisor 流程最后一步必须触发 UrhoX MCP build 工具
- build 失败时，检查模块的 require 路径、MODMETA.depends 声明是否与实际一致
- 模块脚手架生成后也必须立即 build 验证，确保模板代码无语法错误

```lua
-- Supervisor 完成模块编排后的标准流程：
-- 1. 所有模块 Init() 成功
-- 2. 输出 docs/registry-state.json
-- 3. 提示 AI 调用 UrhoX MCP build 工具验证
print("[Supervisor] 模块编排完成，请调用 build 工具验证项目")
```

---

## §8 状态文件

### 8.1 docs/registry-state.json

```json
{
    "version": "1.0.0",
    "timestamp": "2026-05-13T10:00:00Z",
    "modules": {
        "combat": {
            "version": "1.0.0",
            "status": "active",
            "depends": ["inventory", "character"],
            "provides": ["StartBattle", "EndBattle", "GetBattleState"],
            "validation": "passed",
            "initOrder": 3
        },
        "inventory": {
            "version": "1.2.0",
            "status": "active",
            "depends": [],
            "provides": ["AddItem", "RemoveItem", "GetItems"],
            "validation": "passed",
            "initOrder": 1
        }
    },
    "loadOrder": ["inventory", "character", "combat", "dialogue", "audio"],
    "errors": [],
    "warnings": ["audio: 全局变量 AUDIO_VOLUME 检测到 (V8)"]
}
```

### 8.2 docs/registry-status.md

```markdown
# 模块注册表状态

| 模块 | 版本 | 状态 | 依赖 | 接口数 | 验证 |
|------|------|------|------|--------|------|
| inventory | 1.2.0 | ✅ active | 无 | 3 | passed |
| character | 1.0.0 | ✅ active | 无 | 5 | passed |
| combat | 1.0.0 | ✅ active | inventory, character | 3 | passed |
| dialogue | 1.0.0 | ✅ active | character | 4 | passed |
| audio | 0.9.0 | ⚠️ warned | 无 | 2 | warned (V8) |

**初始化顺序**: inventory → character → combat → dialogue → audio

**警告**: 1 条（见下方）
- audio: 检测到全局变量 AUDIO_VOLUME，建议改为模块内局部变量
```

---

## §9 与其他 Skill 的协作

### 9.1 协作矩阵

| Skill | 协作方式 |
|-------|---------|
| `@zy_game-architect-v2` | 架构师设计子系统 → 本 skill 将子系统转化为注册模块 |
| `dev-tools-pack` | 模块脚手架生成器可调用 dev-tools-pack 的模板 |
| `game-dev-factory` | 工厂模式 R3(架构师) 输出模块结构 → 本 skill 生成注册代码 |
| `game-bug-checker` | 模块代码质量检查可调用 bug-checker |
| `game-mission-orchestrator` | 长期项目中每个里程碑可添加新模块 |
| `auto-workflow` | 检测到重复模块模式时建议模块化 + 注册 |

### 9.2 与 auto-workflow 的边界

| 维度 | game-module-registry | auto-workflow |
|------|---------------------|---------------|
| 核心关注 | 模块治理（注册/验证/依赖/编排） | 代码自动化（样板消除/配置提取） |
| 产出 | ModuleRegistry + Supervisor 架构 | 自动化脚本和模板 |
| 触发 | 模块化架构需求 | 重复代码模式检测 |
| 粒度 | 模块级（整个子系统） | 文件/函数级（代码片段） |

---

## §10 首次触发响应

```markdown
## 模块注册中心 已启动

欢迎使用插件化模块架构。

**核心组件**:

| 组件 | 职责 |
|------|------|
| **MODMETA 契约** | 每个模块声明名称/版本/依赖/接口 |
| **ValidateModule** | 8 项合规验证门禁 |
| **ModuleRegistry** | 模块注册表（发现/查询/卸载） |
| **Supervisor** | 依赖排序 + 初始化编排 + 运行时调度 |

**工作流程**:
1. 在 `scripts/modules/{name}/init.lua` 中声明 MODMETA
2. Supervisor 自动发现并验证模块
3. 通过 8 项检查后注册到 ModuleRegistry
4. 按依赖拓扑排序初始化
5. 运行时通过 registry 查询接口或事件通信

请描述你想创建的模块，或告诉我现有的模块列表，我来帮你搭建注册中心。
```

---

## §11 决策树

```
用户描述了模块化/插件化需求
  ↓
是否要求"模块注册""插件化""组件注册""模块验证"?
├─ 是 → 使用 game-module-registry
└─ 否 ↓
     是否要求"架构设计""子系统设计"?
     ├─ 是 → 建议 @zy_game-architect-v2（设计）+ game-module-registry（实现）
     └─ 否 ↓
          是否要求"模块脚手架""生成模块代码"?
          ├─ 是 → 简单模块用 dev-tools-pack，需要注册管理用 game-module-registry
          └─ 否 ↓
               是否项目有 5+ 个子系统需要统一管理?
               ├─ 是 → 主动建议 game-module-registry
               └─ 否 → 直接开发（无需模块注册中心）
```

---

## 参考文档

- `references/modmeta-spec.md` — MODMETA 元数据契约完整规范
- `references/validation-pipeline.md` — 验证管线 8 项检查详细规则
