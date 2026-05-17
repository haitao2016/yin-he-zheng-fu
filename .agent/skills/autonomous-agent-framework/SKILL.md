---
name: autonomous-agent-framework
description: >-
  UrhoX Lua 游戏内自治代理框架。
  灵感源自 entropy-research/Devon 的 Session-Tool-Event-Checkpoint 架构，
  将 AI 编程代理的核心模式映射为游戏内可运行的自治 NPC/系统代理。
  提供 6 大核心模块：AgentSession（会话生命周期与状态持久化）、
  ToolRegistry（工具注册与动态调度）、EventBus（事件总线与回调分发）、
  PlanExecutor（目标分解与多步执行）、CheckpointManager（状态快照与回滚恢复）、
  SelfHealer（错误检测与自我修正循环）。
  适用于：自治 NPC 行为系统、任务链自动执行、可回滚的游戏状态管理、
  事件驱动的系统编排、自修复游戏逻辑。
  Use when users need to
  (1) 为 NPC 实现自治代理行为（接收目标→规划→执行→自我修正）,
  (2) 构建可注册/动态调度的工具系统（NPC 根据情境选择不同工具/技能）,
  (3) 实现事件驱动的游戏系统编排（事件总线、回调链、事件过滤）,
  (4) 需要状态快照与回滚机制（存档点、时间回溯、撤销操作）,
  (5) 构建自修复/容错游戏逻辑（错误检测→自动恢复→重试）,
  (6) 实现多步任务链自动执行（任务分解→顺序执行→状态检查→迭代）,
  (7) 用户说"自治代理""autonomous agent""NPC agent""智能代理",
  (8) 用户说"工具注册""tool registry""动态工具""能力发现",
  (9) 用户说"事件总线""event bus""事件驱动""回调系统",
  (10) 用户说"检查点""checkpoint""回滚""rollback""快照""snapshot",
  (11) 用户说"自修复""self-heal""自动恢复""容错""error recovery",
  (12) 用户说"任务链""task chain""多步执行""plan-execute"。
  与 behavior-tree-ai 的区别：行为树处理"每帧决策"（tick 驱动、条件分支），
  本框架处理"多步任务生命周期"（会话管理、工具调度、检查点、自修复）。
  与 structured-dev-session 的区别：结构化开发管理"开发流程阶段"（分析→实施→审查），
  本框架管理"游戏内代理的运行时会话"（目标→规划→工具调用→回滚→完成）。
  两者可组合使用。
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  source: "https://github.com/entropy-research/Devon"
  tags: [autonomous-agent, session-management, tool-registry, event-bus, checkpoint, self-healing, game-ai]
---

# Autonomous Agent Framework — 游戏内自治代理框架

> 灵感源自 [Devon](https://github.com/entropy-research/Devon) 的 AI 编程代理架构，
> 将 Session-Tool-Event-Checkpoint 模式映射为 UrhoX Lua 游戏内的自治代理系统。
>
> 核心理念：**游戏内实体可以像 AI Agent 一样接收目标、规划步骤、调用工具、保存检查点、自我修正。**
>
> - 工具注册配方 → `references/tool-catalog.md`
> - 事件总线模式 → `references/event-patterns.md`
> - 检查点策略 → `references/checkpoint-strategies.md`

---

## §1 Use When（触发条件）

### 1.1 触发场景

| # | 场景 | 典型用户描述 |
|---|------|-------------|
| 1 | NPC 自治行为 | "让 NPC 自己决定做什么""NPC 接到任务后自动执行" |
| 2 | 工具/技能调度 | "NPC 根据情况选择不同技能""动态注册新能力" |
| 3 | 事件驱动编排 | "事件总线""回调链""发布-订阅" |
| 4 | 状态快照回滚 | "存档点""时间回溯""撤销上一步" |
| 5 | 自修复逻辑 | "NPC 卡住自动恢复""容错机制" |
| 6 | 多步任务链 | "自动执行一系列步骤""任务分解" |
| 7 | 代理系统原型 | "做一个 Agent 系统""智能代理框架" |

### 1.2 与相关 Skill 的区别

| Skill | 关注点 | 本框架的独特性 |
|-------|--------|---------------|
| `behavior-tree-ai` | 每帧 tick 决策（条件→动作分支） | 多步任务生命周期（会话→规划→工具→检查点→完成） |
| `structured-dev-session` | 开发流程阶段管理 | 游戏内运行时代理会话 |
| `game-dev-factory` | 虚拟角色对话链 | 运行时工具注册 + 事件总线 + 状态回滚 |
| `subagent-task-orchestrator` | 子代理 dispatch | 单代理内的完整生命周期（非 dispatch 多代理） |
| `game-mission-orchestrator` | 任务/关卡编排 | 代理自治决策 + 自修复 + 检查点恢复 |

**可组合使用**：行为树管理每帧微决策，本框架管理跨帧宏任务生命周期。

---

## §2 架构总览

### 2.1 六大核心模块

```
┌─────────────────────────────────────────────────────────────┐
│                    AgentSession                              │
│         （会话生命周期：创建 → 运行 → 暂停 → 恢复 → 完成）    │
├─────────────┬──────────────┬────────────────────────────────┤
│ ToolRegistry│  EventBus    │     CheckpointManager          │
│ 工具注册     │  事件总线     │     检查点管理                  │
│ 动态调度     │  回调分发     │     快照/回滚                   │
├─────────────┴──────────────┴────────────────────────────────┤
│                    PlanExecutor                               │
│         （目标分解 → 步骤队列 → 顺序执行 → 状态检查）          │
├─────────────────────────────────────────────────────────────┤
│                    SelfHealer                                 │
│         （错误检测 → 回滚到检查点 → 替代策略 → 重试）          │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 模块职责

| 模块 | Devon 对应 | 职责 |
|------|-----------|------|
| `AgentSession` | `session.py` | 会话创建/暂停/恢复/终止、状态持久化、上下文管理 |
| `ToolRegistry` | `tools/` + 动态注册 | 工具注册/注销、能力查询、参数校验、执行调度 |
| `EventBus` | `event_loop.py` | 事件发布/订阅、回调链、事件过滤、优先级排序 |
| `PlanExecutor` | Agent Loop | 目标分解为步骤、顺序执行、进度追踪、完成判定 |
| `CheckpointManager` | Checkpoint/Rollback | 状态快照、存储/加载、回滚到指定点、快照清理 |
| `SelfHealer` | Self-healing | 错误检测、恢复策略选择、回滚+重试、最大重试限制 |

### 2.3 数据流

```
目标输入
  ↓
AgentSession.Start(goal)
  ↓
PlanExecutor.Decompose(goal) → [Step1, Step2, Step3, ...]
  ↓
┌─── 循环每个 Step ───────────────────────────────┐
│  CheckpointManager.Save()                        │
│  ToolRegistry.FindTool(step.toolName)             │
│  tool.Execute(step.args)                          │
│  EventBus.Emit("step_completed", {step, result})  │
│  ↓                                                │
│  成功？ → 下一步                                   │
│  失败？ → SelfHealer.Handle(error)                 │
│           ├─ 回滚到检查点                          │
│           ├─ 选择替代工具/策略                      │
│           └─ 重试（最多 N 次）                      │
└─────────────────────────────────────────────────┘
  ↓
AgentSession.Complete(result)
EventBus.Emit("session_completed", {session, result})
```

---

## §3 AgentSession — 会话生命周期

### 3.1 会话状态机

```
         Create()
            ↓
    ┌── CREATED ──┐
    │             │
    │  Start()    │
    ↓             │
  RUNNING ◄───────┘
    │   │
    │   │ Pause()
    │   ↓
    │  PAUSED
    │   │
    │   │ Resume()
    │   ↓
    │  RUNNING (恢复)
    │
    │ Complete() / Fail()
    ↓
  FINISHED
```

### 3.2 实现代码

```lua
-- scripts/AgentFramework/AgentSession.lua

local AgentSession = {}
AgentSession.__index = AgentSession

--- 会话状态枚举
AgentSession.State = {
    CREATED  = "created",
    RUNNING  = "running",
    PAUSED   = "paused",
    FINISHED = "finished",
}

--- 创建新会话
---@param config table { id: string, goal: string, context: table? }
---@return table session
function AgentSession.Create(config)
    local session = setmetatable({}, AgentSession)
    session.id = config.id or ("session_" .. os.clock())
    session.goal = config.goal or ""
    session.state = AgentSession.State.CREATED
    session.context = config.context or {}
    session.history = {}          -- 执行历史
    session.startTime = nil
    session.endTime = nil
    session.result = nil
    session.error = nil
    session.metadata = {}         -- 用户自定义元数据
    return session
end

--- 启动会话
function AgentSession:Start()
    if self.state ~= AgentSession.State.CREATED then
        return false, "Session must be in CREATED state to start"
    end
    self.state = AgentSession.State.RUNNING
    self.startTime = os.clock()
    self:_AddHistory("session_started", { goal = self.goal })
    return true
end

--- 暂停会话
function AgentSession:Pause(reason)
    if self.state ~= AgentSession.State.RUNNING then
        return false, "Session must be RUNNING to pause"
    end
    self.state = AgentSession.State.PAUSED
    self:_AddHistory("session_paused", { reason = reason })
    return true
end

--- 恢复会话
function AgentSession:Resume()
    if self.state ~= AgentSession.State.PAUSED then
        return false, "Session must be PAUSED to resume"
    end
    self.state = AgentSession.State.RUNNING
    self:_AddHistory("session_resumed", {})
    return true
end

--- 完成会话
function AgentSession:Complete(result)
    self.state = AgentSession.State.FINISHED
    self.endTime = os.clock()
    self.result = result
    self:_AddHistory("session_completed", { result = result })
    return true
end

--- 会话失败
function AgentSession:Fail(error)
    self.state = AgentSession.State.FINISHED
    self.endTime = os.clock()
    self.error = error
    self:_AddHistory("session_failed", { error = error })
    return true
end

--- 检查会话是否活跃
function AgentSession:IsActive()
    return self.state == AgentSession.State.RUNNING
end

--- 获取会话运行时长
function AgentSession:GetElapsed()
    if not self.startTime then return 0 end
    local endT = self.endTime or os.clock()
    return endT - self.startTime
end

--- 设置上下文数据
function AgentSession:SetContext(key, value)
    self.context[key] = value
end

--- 获取上下文数据
function AgentSession:GetContext(key)
    return self.context[key]
end

--- 添加历史记录（内部方法）
function AgentSession:_AddHistory(event, data)
    table.insert(self.history, {
        event = event,
        data = data,
        timestamp = os.clock(),
    })
end

--- 序列化为可保存的表
function AgentSession:Serialize()
    return {
        id = self.id,
        goal = self.goal,
        state = self.state,
        context = self.context,
        history = self.history,
        startTime = self.startTime,
        endTime = self.endTime,
        result = self.result,
        error = self.error,
        metadata = self.metadata,
    }
end

--- 从序列化数据恢复
function AgentSession.Deserialize(data)
    local session = setmetatable({}, AgentSession)
    session.id = data.id
    session.goal = data.goal
    session.state = data.state
    session.context = data.context or {}
    session.history = data.history or {}
    session.startTime = data.startTime
    session.endTime = data.endTime
    session.result = data.result
    session.error = data.error
    session.metadata = data.metadata or {}
    return session
end

return AgentSession
```

---

## §4 ToolRegistry — 工具注册与动态调度

### 4.1 核心概念

Devon 的工具系统允许运行时注册/注销工具，代理根据当前任务自动选择合适的工具。
映射到游戏中：NPC 拥有一组"能力"（工具），根据目标和情境动态调度。

### 4.2 工具接口规范

每个工具必须实现标准接口：

```lua
---@class ToolDefinition
---@field name string        工具唯一名称
---@field description string 工具描述（用于能力发现）
---@field tags string[]      标签（用于分类查找）
---@field validate function? 参数校验函数（可选）
---@field execute function   执行函数 (args) → result, error
---@field cost number?       执行成本（可选，用于策略选择）
```

### 4.3 实现代码

```lua
-- scripts/AgentFramework/ToolRegistry.lua

local ToolRegistry = {}
ToolRegistry.__index = ToolRegistry

--- 创建工具注册表
---@return table registry
function ToolRegistry.Create()
    local registry = setmetatable({}, ToolRegistry)
    registry.tools = {}        -- name → ToolDefinition
    registry.tagIndex = {}     -- tag → { name1, name2, ... }
    return registry
end

--- 注册工具
---@param tool ToolDefinition
---@return boolean success
---@return string? error
function ToolRegistry:Register(tool)
    if not tool.name then
        return false, "Tool must have a name"
    end
    if not tool.execute then
        return false, "Tool must have an execute function"
    end
    if self.tools[tool.name] then
        return false, "Tool '" .. tool.name .. "' already registered"
    end

    self.tools[tool.name] = {
        name = tool.name,
        description = tool.description or "",
        tags = tool.tags or {},
        validate = tool.validate,
        execute = tool.execute,
        cost = tool.cost or 1,
        callCount = 0,
        totalTime = 0,
    }

    -- 更新标签索引
    for _, tag in ipairs(tool.tags or {}) do
        if not self.tagIndex[tag] then
            self.tagIndex[tag] = {}
        end
        table.insert(self.tagIndex[tag], tool.name)
    end

    return true
end

--- 注销工具
---@param name string
---@return boolean
function ToolRegistry:Unregister(name)
    local tool = self.tools[name]
    if not tool then return false end

    -- 清理标签索引
    for _, tag in ipairs(tool.tags) do
        local tagList = self.tagIndex[tag]
        if tagList then
            for i, n in ipairs(tagList) do
                if n == name then
                    table.remove(tagList, i)
                    break
                end
            end
        end
    end

    self.tools[name] = nil
    return true
end

--- 查找工具（按名称）
---@param name string
---@return table? tool
function ToolRegistry:FindTool(name)
    return self.tools[name]
end

--- 按标签查找工具
---@param tag string
---@return table[] tools
function ToolRegistry:FindByTag(tag)
    local names = self.tagIndex[tag] or {}
    local result = {}
    for _, name in ipairs(names) do
        local tool = self.tools[name]
        if tool then
            table.insert(result, tool)
        end
    end
    return result
end

--- 列出所有已注册工具（能力发现）
---@return table[] toolInfos { name, description, tags, cost }
function ToolRegistry:ListTools()
    local list = {}
    for _, tool in pairs(self.tools) do
        table.insert(list, {
            name = tool.name,
            description = tool.description,
            tags = tool.tags,
            cost = tool.cost,
        })
    end
    -- 按名称排序
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- 执行工具
---@param name string  工具名称
---@param args table   参数
---@return any result
---@return string? error
function ToolRegistry:Execute(name, args)
    local tool = self.tools[name]
    if not tool then
        return nil, "Tool '" .. name .. "' not found"
    end

    -- 参数校验
    if tool.validate then
        local valid, err = tool.validate(args)
        if not valid then
            return nil, "Validation failed: " .. (err or "unknown")
        end
    end

    -- 执行并计时
    local startT = os.clock()
    local ok, result, err = pcall(tool.execute, args)
    local elapsed = os.clock() - startT

    tool.callCount = tool.callCount + 1
    tool.totalTime = tool.totalTime + elapsed

    if not ok then
        return nil, "Tool execution error: " .. tostring(result)
    end

    return result, err
end

--- 获取工具使用统计
---@param name string
---@return table? stats { callCount, totalTime, avgTime }
function ToolRegistry:GetStats(name)
    local tool = self.tools[name]
    if not tool then return nil end
    return {
        callCount = tool.callCount,
        totalTime = tool.totalTime,
        avgTime = tool.callCount > 0 and (tool.totalTime / tool.callCount) or 0,
    }
end

return ToolRegistry
```

### 4.4 内置游戏工具示例

```lua
-- 注册移动工具
registry:Register({
    name = "move_to",
    description = "移动到目标位置",
    tags = { "navigation", "movement" },
    cost = 2,
    validate = function(args)
        if not args.target then return false, "Missing target position" end
        return true
    end,
    execute = function(args)
        local node = args.node
        local target = args.target
        -- 计算路径并开始移动
        node.position = target  -- 简化版，实际应用 lerp/导航
        return { arrived = true, position = target }
    end,
})

-- 注册攻击工具
registry:Register({
    name = "attack",
    description = "攻击目标实体",
    tags = { "combat", "action" },
    cost = 5,
    validate = function(args)
        if not args.target then return false, "Missing target" end
        if not args.damage then return false, "Missing damage value" end
        return true
    end,
    execute = function(args)
        local target = args.target
        local damage = args.damage
        target.hp = math.max(0, (target.hp or 100) - damage)
        return { hit = true, remainingHp = target.hp }
    end,
})

-- 注册感知工具
registry:Register({
    name = "scan_area",
    description = "扫描周围区域寻找目标",
    tags = { "perception", "sensor" },
    cost = 1,
    execute = function(args)
        local center = args.center
        local radius = args.radius or 10
        -- 简化版：返回区域内的实体列表
        local found = {}
        -- ... 实际实现中遍历场景节点 ...
        return { entities = found, count = #found }
    end,
})

-- 注册拾取工具
registry:Register({
    name = "pickup_item",
    description = "拾取附近的物品",
    tags = { "interaction", "inventory" },
    cost = 1,
    validate = function(args)
        if not args.item then return false, "Missing item" end
        return true
    end,
    execute = function(args)
        local item = args.item
        local inventory = args.inventory or {}
        table.insert(inventory, item)
        return { picked = true, inventory = inventory }
    end,
})

-- 注册等待工具
registry:Register({
    name = "wait",
    description = "等待指定时间",
    tags = { "utility" },
    cost = 0,
    execute = function(args)
        local duration = args.duration or 1.0
        return { waited = true, duration = duration }
    end,
})
```

---

## §5 EventBus — 事件总线与回调分发

### 5.1 核心概念

Devon 使用事件循环处理工具调用和状态变化。映射到游戏中：
全局事件总线负责代理间通信、状态广播、松耦合系统协调。

### 5.2 实现代码

```lua
-- scripts/AgentFramework/EventBus.lua

local EventBus = {}
EventBus.__index = EventBus

--- 创建事件总线
---@return table bus
function EventBus.Create()
    local bus = setmetatable({}, EventBus)
    bus.listeners = {}        -- eventName → { {callback, priority, id}, ... }
    bus.nextListenerId = 1
    bus.eventLog = {}         -- 事件日志（可选启用）
    bus.logEnabled = false
    bus.filters = {}          -- 全局过滤器
    return bus
end

--- 订阅事件
---@param eventName string
---@param callback function(data: table)
---@param priority number? 优先级（数字越小越先执行，默认 100）
---@return number listenerId 用于取消订阅
function EventBus:On(eventName, callback, priority)
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
    end

    local id = self.nextListenerId
    self.nextListenerId = self.nextListenerId + 1

    table.insert(self.listeners[eventName], {
        callback = callback,
        priority = priority or 100,
        id = id,
    })

    -- 按优先级排序
    table.sort(self.listeners[eventName], function(a, b)
        return a.priority < b.priority
    end)

    return id
end

--- 订阅一次性事件（触发后自动取消）
---@param eventName string
---@param callback function
---@return number listenerId
function EventBus:Once(eventName, callback)
    local id
    id = self:On(eventName, function(data)
        self:Off(id)
        callback(data)
    end)
    return id
end

--- 取消订阅
---@param listenerId number
function EventBus:Off(listenerId)
    for eventName, listeners in pairs(self.listeners) do
        for i, listener in ipairs(listeners) do
            if listener.id == listenerId then
                table.remove(listeners, i)
                return
            end
        end
    end
end

--- 取消某事件的所有订阅
---@param eventName string
function EventBus:OffAll(eventName)
    self.listeners[eventName] = nil
end

--- 发布事件
---@param eventName string
---@param data table?
function EventBus:Emit(eventName, data)
    data = data or {}
    data._eventName = eventName
    data._timestamp = os.clock()

    -- 全局过滤器
    for _, filter in ipairs(self.filters) do
        if not filter(eventName, data) then
            return  -- 被过滤器拦截
        end
    end

    -- 事件日志
    if self.logEnabled then
        table.insert(self.eventLog, {
            event = eventName,
            data = data,
            timestamp = data._timestamp,
        })
    end

    -- 分发给监听器
    local listeners = self.listeners[eventName]
    if not listeners then return end

    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener.callback, data)
        if not ok then
            print("[EventBus] Error in listener for '" .. eventName .. "': " .. tostring(err))
        end
    end
end

--- 添加全局过滤器
---@param filter function(eventName: string, data: table): boolean
function EventBus:AddFilter(filter)
    table.insert(self.filters, filter)
end

--- 启用/禁用事件日志
function EventBus:EnableLog(enabled)
    self.logEnabled = enabled
end

--- 获取事件日志
function EventBus:GetLog()
    return self.eventLog
end

--- 清空事件日志
function EventBus:ClearLog()
    self.eventLog = {}
end

return EventBus
```

### 5.3 预定义事件类型

```lua
-- 会话事件
local SessionEvents = {
    STARTED      = "session_started",
    PAUSED       = "session_paused",
    RESUMED      = "session_resumed",
    COMPLETED    = "session_completed",
    FAILED       = "session_failed",
}

-- 计划事件
local PlanEvents = {
    DECOMPOSED   = "plan_decomposed",
    STEP_STARTED = "step_started",
    STEP_DONE    = "step_completed",
    STEP_FAILED  = "step_failed",
    ALL_DONE     = "plan_all_completed",
}

-- 工具事件
local ToolEvents = {
    REGISTERED   = "tool_registered",
    UNREGISTERED = "tool_unregistered",
    CALLED       = "tool_called",
    SUCCEEDED    = "tool_succeeded",
    FAILED       = "tool_failed",
}

-- 检查点事件
local CheckpointEvents = {
    SAVED        = "checkpoint_saved",
    LOADED       = "checkpoint_loaded",
    ROLLED_BACK  = "checkpoint_rolled_back",
    CLEARED      = "checkpoint_cleared",
}

-- 自修复事件
local HealEvents = {
    ERROR_DETECTED = "error_detected",
    RETRY_STARTED  = "retry_started",
    RECOVERED      = "error_recovered",
    GAVE_UP        = "error_gave_up",
}
```

---

## §6 PlanExecutor — 目标分解与多步执行

### 6.1 核心概念

Devon 的 Agent Loop 将目标分解为步骤序列，逐步执行并检查状态。
映射到游戏中：NPC 接收高级目标（"清理房间"），分解为多个子步骤（移动→拾取→存放→重复）。

### 6.2 实现代码

```lua
-- scripts/AgentFramework/PlanExecutor.lua

local PlanExecutor = {}
PlanExecutor.__index = PlanExecutor

--- 步骤状态
PlanExecutor.StepState = {
    PENDING    = "pending",
    RUNNING    = "running",
    COMPLETED  = "completed",
    FAILED     = "failed",
    SKIPPED    = "skipped",
}

--- 创建计划执行器
---@param config table { maxRetries: number?, stepTimeout: number? }
---@return table executor
function PlanExecutor.Create(config)
    config = config or {}
    local executor = setmetatable({}, PlanExecutor)
    executor.steps = {}
    executor.currentIndex = 0
    executor.maxRetries = config.maxRetries or 3
    executor.stepTimeout = config.stepTimeout or 10.0
    executor.isRunning = false
    executor.onStepComplete = nil    -- 回调
    executor.onStepFailed = nil      -- 回调
    executor.onAllComplete = nil     -- 回调
    return executor
end

--- 添加步骤
---@param step table { name: string, toolName: string, args: table, condition: function? }
function PlanExecutor:AddStep(step)
    table.insert(self.steps, {
        name = step.name or ("step_" .. #self.steps + 1),
        toolName = step.toolName,
        args = step.args or {},
        condition = step.condition,    -- 前置条件（可选）
        state = PlanExecutor.StepState.PENDING,
        result = nil,
        error = nil,
        retries = 0,
    })
end

--- 从目标自动分解步骤（使用规则表）
---@param goal string 目标描述
---@param rules table 分解规则 { pattern → steps[] }
function PlanExecutor:Decompose(goal, rules)
    for pattern, stepDefs in pairs(rules) do
        if goal:find(pattern) then
            for _, stepDef in ipairs(stepDefs) do
                self:AddStep(stepDef)
            end
            return true
        end
    end
    return false, "No matching rule for goal: " .. goal
end

--- 获取当前步骤
---@return table? step
function PlanExecutor:GetCurrentStep()
    if self.currentIndex < 1 or self.currentIndex > #self.steps then
        return nil
    end
    return self.steps[self.currentIndex]
end

--- 执行下一步
---@param registry table ToolRegistry
---@return boolean hasMore 是否还有更多步骤
---@return any result 当前步骤结果
---@return string? error 错误信息
function PlanExecutor:ExecuteNext(registry)
    self.currentIndex = self.currentIndex + 1

    if self.currentIndex > #self.steps then
        self.isRunning = false
        if self.onAllComplete then
            self.onAllComplete(self:GetResults())
        end
        return false, nil, nil
    end

    local step = self.steps[self.currentIndex]
    step.state = PlanExecutor.StepState.RUNNING

    -- 检查前置条件
    if step.condition and not step.condition() then
        step.state = PlanExecutor.StepState.SKIPPED
        return true, nil, "Condition not met, skipped"
    end

    -- 调用工具
    local result, err = registry:Execute(step.toolName, step.args)

    if err then
        step.state = PlanExecutor.StepState.FAILED
        step.error = err
        step.retries = step.retries + 1

        if self.onStepFailed then
            self.onStepFailed(step, err)
        end

        return true, nil, err
    end

    step.state = PlanExecutor.StepState.COMPLETED
    step.result = result

    if self.onStepComplete then
        self.onStepComplete(step, result)
    end

    return true, result, nil
end

--- 重试当前步骤
---@param registry table ToolRegistry
---@return boolean canRetry
---@return any result
---@return string? error
function PlanExecutor:RetryCurrent(registry)
    local step = self:GetCurrentStep()
    if not step then return false, nil, "No current step" end
    if step.retries >= self.maxRetries then
        return false, nil, "Max retries exceeded"
    end

    -- 回退索引以重新执行
    self.currentIndex = self.currentIndex - 1
    return self:ExecuteNext(registry)
end

--- 获取所有步骤的结果摘要
---@return table results
function PlanExecutor:GetResults()
    local results = {}
    for _, step in ipairs(self.steps) do
        table.insert(results, {
            name = step.name,
            state = step.state,
            result = step.result,
            error = step.error,
            retries = step.retries,
        })
    end
    return results
end

--- 获取进度
---@return number completed, number total
function PlanExecutor:GetProgress()
    local completed = 0
    for _, step in ipairs(self.steps) do
        if step.state == PlanExecutor.StepState.COMPLETED
        or step.state == PlanExecutor.StepState.SKIPPED then
            completed = completed + 1
        end
    end
    return completed, #self.steps
end

--- 重置执行器
function PlanExecutor:Reset()
    self.currentIndex = 0
    self.isRunning = false
    for _, step in ipairs(self.steps) do
        step.state = PlanExecutor.StepState.PENDING
        step.result = nil
        step.error = nil
        step.retries = 0
    end
end

return PlanExecutor
```

### 6.3 目标分解规则示例

```lua
-- 常用目标分解规则
local decomposeRules = {
    -- "巡逻" → 移动到多个路径点
    ["patrol"] = {
        { name = "go_to_wp1", toolName = "move_to", args = { target = Vector3(0, 0, 10) } },
        { name = "scan_at_wp1", toolName = "scan_area", args = { radius = 15 } },
        { name = "go_to_wp2", toolName = "move_to", args = { target = Vector3(10, 0, 0) } },
        { name = "scan_at_wp2", toolName = "scan_area", args = { radius = 15 } },
    },

    -- "收集资源" → 扫描→移动→拾取
    ["collect"] = {
        { name = "find_items", toolName = "scan_area", args = { radius = 20 } },
        { name = "go_to_item", toolName = "move_to", args = {} },  -- args 动态填充
        { name = "pick_up", toolName = "pickup_item", args = {} },
    },

    -- "战斗" → 扫描→接近→攻击
    ["combat"] = {
        { name = "find_enemy", toolName = "scan_area", args = { radius = 25 } },
        { name = "approach", toolName = "move_to", args = {} },
        { name = "strike", toolName = "attack", args = { damage = 10 } },
    },
}
```

---

## §7 CheckpointManager — 状态快照与回滚

### 7.1 核心概念

Devon 支持检查点保存和回滚恢复。映射到游戏中：
在执行关键步骤前保存状态快照，失败时回滚到最近的安全点。

### 7.2 实现代码

```lua
-- scripts/AgentFramework/CheckpointManager.lua

local cjson = require("cjson")

local CheckpointManager = {}
CheckpointManager.__index = CheckpointManager

--- 创建检查点管理器
---@param config table { maxCheckpoints: number?, storagePrefix: string? }
---@return table manager
function CheckpointManager.Create(config)
    config = config or {}
    local mgr = setmetatable({}, CheckpointManager)
    mgr.checkpoints = {}     -- id → snapshot
    mgr.order = {}           -- 有序的 checkpoint id 列表
    mgr.maxCheckpoints = config.maxCheckpoints or 20
    mgr.storagePrefix = config.storagePrefix or "checkpoints"
    mgr.nextId = 1
    return mgr
end

--- 保存检查点
---@param label string 检查点标签
---@param state table  要保存的状态数据（会深拷贝）
---@return string checkpointId
function CheckpointManager:Save(label, state)
    local id = self.storagePrefix .. "_" .. self.nextId
    self.nextId = self.nextId + 1

    local snapshot = {
        id = id,
        label = label,
        timestamp = os.clock(),
        state = CheckpointManager._DeepCopy(state),
    }

    self.checkpoints[id] = snapshot
    table.insert(self.order, id)

    -- 清理超出限制的旧检查点
    while #self.order > self.maxCheckpoints do
        local oldId = table.remove(self.order, 1)
        self.checkpoints[oldId] = nil
    end

    return id
end

--- 加载检查点
---@param id string 检查点 ID
---@return table? state 恢复的状态
---@return string? error
function CheckpointManager:Load(id)
    local snapshot = self.checkpoints[id]
    if not snapshot then
        return nil, "Checkpoint '" .. id .. "' not found"
    end
    return CheckpointManager._DeepCopy(snapshot.state), nil
end

--- 回滚到最近的检查点
---@return table? state
---@return string? checkpointId
function CheckpointManager:RollbackLatest()
    if #self.order == 0 then
        return nil, nil
    end
    local latestId = self.order[#self.order]
    local state = self:Load(latestId)
    return state, latestId
end

--- 回滚到指定标签的最近检查点
---@param label string
---@return table? state
---@return string? checkpointId
function CheckpointManager:RollbackToLabel(label)
    -- 从最新往最旧搜索
    for i = #self.order, 1, -1 do
        local id = self.order[i]
        local snapshot = self.checkpoints[id]
        if snapshot and snapshot.label == label then
            return CheckpointManager._DeepCopy(snapshot.state), id
        end
    end
    return nil, nil
end

--- 列出所有检查点
---@return table[] infos { id, label, timestamp }
function CheckpointManager:List()
    local list = {}
    for _, id in ipairs(self.order) do
        local snapshot = self.checkpoints[id]
        if snapshot then
            table.insert(list, {
                id = snapshot.id,
                label = snapshot.label,
                timestamp = snapshot.timestamp,
            })
        end
    end
    return list
end

--- 清除所有检查点
function CheckpointManager:Clear()
    self.checkpoints = {}
    self.order = {}
end

--- 持久化到文件
---@param filename string 文件路径（如 "agent_checkpoints.json"）
function CheckpointManager:SaveToFile(filename)
    local data = {
        checkpoints = {},
        order = self.order,
        nextId = self.nextId,
    }
    for id, snapshot in pairs(self.checkpoints) do
        data.checkpoints[id] = snapshot
    end

    local jsonStr = cjson.encode(data)
    local file = File:new(filename, FILE_WRITE)
    if file then
        file:WriteString(jsonStr)
        file:Close()
    end
end

--- 从文件恢复
---@param filename string
---@return boolean success
function CheckpointManager:LoadFromFile(filename)
    local file = File:new(filename, FILE_READ)
    if not file then return false end

    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then return false end

    self.checkpoints = data.checkpoints or {}
    self.order = data.order or {}
    self.nextId = data.nextId or 1
    return true
end

--- 深拷贝工具
function CheckpointManager._DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[CheckpointManager._DeepCopy(k)] = CheckpointManager._DeepCopy(v)
    end
    return setmetatable(copy, getmetatable(orig))
end

return CheckpointManager
```

---

## §8 SelfHealer — 错误检测与自我修正

### 8.1 核心概念

Devon 的 self-healing 允许代理在遇到错误时自动恢复。映射到游戏中：
当 NPC 执行任务失败时，自动回滚状态、选择替代策略、重试执行。

### 8.2 恢复策略

```
错误发生
  ↓
SelfHealer.Handle(error, context)
  ↓
┌─ 策略 1: 简单重试 ─────────────────────┐
│  同一工具、同一参数，再试一次            │
│  适用于：瞬时错误（碰撞干扰等）          │
└─────────────────────────────────────────┘
  ↓ 失败
┌─ 策略 2: 回滚重试 ─────────────────────┐
│  回滚到上一个检查点，再试一次            │
│  适用于：状态污染（位置错误等）           │
└─────────────────────────────────────────┘
  ↓ 失败
┌─ 策略 3: 替代工具 ─────────────────────┐
│  找相同标签的其他工具替代执行             │
│  适用于：工具本身不可用                   │
└─────────────────────────────────────────┘
  ↓ 失败
┌─ 策略 4: 跳过步骤 ─────────────────────┐
│  标记当前步骤为 SKIPPED，继续下一步      │
│  适用于：非关键步骤                      │
└─────────────────────────────────────────┘
  ↓ 失败
放弃（触发 error_gave_up 事件）
```

### 8.3 实现代码

```lua
-- scripts/AgentFramework/SelfHealer.lua

local SelfHealer = {}
SelfHealer.__index = SelfHealer

--- 恢复策略枚举
SelfHealer.Strategy = {
    RETRY         = "retry",           -- 简单重试
    ROLLBACK      = "rollback",        -- 回滚到检查点再重试
    ALTERNATE     = "alternate_tool",  -- 使用替代工具
    SKIP          = "skip",            -- 跳过当前步骤
}

--- 创建自修复器
---@param config table { maxRetries: number?, strategies: string[]? }
---@return table healer
function SelfHealer.Create(config)
    config = config or {}
    local healer = setmetatable({}, SelfHealer)
    healer.maxRetries = config.maxRetries or 3
    healer.strategies = config.strategies or {
        SelfHealer.Strategy.RETRY,
        SelfHealer.Strategy.ROLLBACK,
        SelfHealer.Strategy.ALTERNATE,
        SelfHealer.Strategy.SKIP,
    }
    healer.retryCount = 0
    healer.strategyIndex = 1
    healer.healLog = {}
    return healer
end

--- 处理错误
---@param error string          错误描述
---@param context table         上下文 { step, registry, checkpointMgr, executor, eventBus }
---@return boolean recovered    是否成功恢复
---@return string strategy      使用的恢复策略
function SelfHealer:Handle(error, context)
    self.retryCount = self.retryCount + 1

    -- 记录错误
    table.insert(self.healLog, {
        error = error,
        retryCount = self.retryCount,
        timestamp = os.clock(),
    })

    -- 通知事件总线
    if context.eventBus then
        context.eventBus:Emit("error_detected", {
            error = error,
            retryCount = self.retryCount,
            step = context.step,
        })
    end

    -- 超出最大重试次数
    if self.retryCount > self.maxRetries then
        if context.eventBus then
            context.eventBus:Emit("error_gave_up", {
                error = error,
                totalRetries = self.retryCount,
            })
        end
        return false, "exceeded_max_retries"
    end

    -- 尝试各策略
    for i = self.strategyIndex, #self.strategies do
        local strategy = self.strategies[i]

        if context.eventBus then
            context.eventBus:Emit("retry_started", {
                strategy = strategy,
                retryCount = self.retryCount,
            })
        end

        local recovered = self:_ApplyStrategy(strategy, context)

        if recovered then
            self.strategyIndex = 1   -- 重置策略索引
            self.retryCount = 0

            if context.eventBus then
                context.eventBus:Emit("error_recovered", {
                    strategy = strategy,
                })
            end

            return true, strategy
        end

        self.strategyIndex = i + 1
    end

    -- 所有策略都失败
    self.strategyIndex = 1
    return false, "all_strategies_exhausted"
end

--- 应用恢复策略（内部方法）
function SelfHealer:_ApplyStrategy(strategy, context)
    if strategy == SelfHealer.Strategy.RETRY then
        return self:_StrategyRetry(context)
    elseif strategy == SelfHealer.Strategy.ROLLBACK then
        return self:_StrategyRollback(context)
    elseif strategy == SelfHealer.Strategy.ALTERNATE then
        return self:_StrategyAlternate(context)
    elseif strategy == SelfHealer.Strategy.SKIP then
        return self:_StrategySkip(context)
    end
    return false
end

--- 策略1: 简单重试
function SelfHealer:_StrategyRetry(context)
    if not context.executor or not context.registry then return false end
    local _, result, err = context.executor:RetryCurrent(context.registry)
    return err == nil
end

--- 策略2: 回滚到检查点再重试
function SelfHealer:_StrategyRollback(context)
    if not context.checkpointMgr then return false end
    local state, cpId = context.checkpointMgr:RollbackLatest()
    if not state then return false end

    -- 恢复状态
    if context.restoreState then
        context.restoreState(state)
    end

    -- 重试
    if context.executor and context.registry then
        local _, result, err = context.executor:RetryCurrent(context.registry)
        return err == nil
    end

    return true  -- 至少回滚成功了
end

--- 策略3: 使用替代工具
function SelfHealer:_StrategyAlternate(context)
    if not context.registry or not context.step then return false end
    local currentTool = context.registry:FindTool(context.step.toolName)
    if not currentTool then return false end

    -- 按标签找替代工具
    for _, tag in ipairs(currentTool.tags) do
        local alternatives = context.registry:FindByTag(tag)
        for _, alt in ipairs(alternatives) do
            if alt.name ~= currentTool.name then
                local result, err = context.registry:Execute(alt.name, context.step.args)
                if not err then
                    context.step.result = result
                    context.step.state = "completed"
                    return true
                end
            end
        end
    end
    return false
end

--- 策略4: 跳过步骤
function SelfHealer:_StrategySkip(context)
    if not context.step then return false end
    context.step.state = "skipped"
    return true  -- 跳过总是"成功"的
end

--- 重置修复器
function SelfHealer:Reset()
    self.retryCount = 0
    self.strategyIndex = 1
end

--- 获取修复日志
function SelfHealer:GetLog()
    return self.healLog
end

return SelfHealer
```

---

## §9 AgentRunner — 完整运行时编排器

### 9.1 核心概念

将上述 6 个模块组合为统一的运行时编排器。类似 Devon 的主循环，
在游戏的 `HandleUpdate` 中每帧驱动代理执行。

### 9.2 实现代码

```lua
-- scripts/AgentFramework/AgentRunner.lua

local AgentSession      = require("scripts.AgentFramework.AgentSession")
local ToolRegistry      = require("scripts.AgentFramework.ToolRegistry")
local EventBus          = require("scripts.AgentFramework.EventBus")
local PlanExecutor      = require("scripts.AgentFramework.PlanExecutor")
local CheckpointManager = require("scripts.AgentFramework.CheckpointManager")
local SelfHealer        = require("scripts.AgentFramework.SelfHealer")

local AgentRunner = {}
AgentRunner.__index = AgentRunner

--- 创建代理运行器
---@param config table
---@return table runner
function AgentRunner.Create(config)
    config = config or {}
    local runner = setmetatable({}, AgentRunner)

    runner.session = nil
    runner.registry = ToolRegistry.Create()
    runner.eventBus = EventBus.Create()
    runner.executor = PlanExecutor.Create({
        maxRetries = config.maxRetries or 3,
    })
    runner.checkpoints = CheckpointManager.Create({
        maxCheckpoints = config.maxCheckpoints or 20,
        storagePrefix = config.storagePrefix or "agent",
    })
    runner.healer = SelfHealer.Create({
        maxRetries = config.maxRetries or 3,
    })

    runner.stepsPerFrame = config.stepsPerFrame or 1  -- 每帧执行几步
    runner.decomposeRules = config.decomposeRules or {}

    -- 状态快照回调
    runner.captureState = config.captureState or function() return {} end
    runner.restoreState = config.restoreState or function(state) end

    return runner
end

--- 注册工具（快捷方式）
function AgentRunner:RegisterTool(tool)
    return self.registry:Register(tool)
end

--- 开始新任务
---@param goal string 目标描述
---@param context table? 初始上下文
function AgentRunner:StartGoal(goal, context)
    -- 创建新会话
    self.session = AgentSession.Create({
        goal = goal,
        context = context,
    })
    self.session:Start()

    -- 分解目标为步骤
    self.executor:Reset()
    local ok, err = self.executor:Decompose(goal, self.decomposeRules)
    if not ok then
        print("[AgentRunner] Failed to decompose goal: " .. (err or "unknown"))
        self.session:Fail("decompose_failed: " .. (err or ""))
        return false
    end

    -- 保存初始检查点
    self.checkpoints:Save("initial", self.captureState())

    self.eventBus:Emit("session_started", {
        goal = goal,
        stepCount = #self.executor.steps,
    })

    self.healer:Reset()
    return true
end

--- 每帧调用（在 HandleUpdate 中）
---@param dt number 时间步长
function AgentRunner:Tick(dt)
    if not self.session or not self.session:IsActive() then
        return
    end

    for i = 1, self.stepsPerFrame do
        local step = self.executor:GetCurrentStep()

        -- 执行前保存检查点
        if step then
            self.checkpoints:Save("before_" .. (step.name or "step"), self.captureState())
        end

        local hasMore, result, err = self.executor:ExecuteNext(self.registry)

        if err then
            -- 调用自修复
            local recovered, strategy = self.healer:Handle(err, {
                step = self.executor:GetCurrentStep(),
                registry = self.registry,
                checkpointMgr = self.checkpoints,
                executor = self.executor,
                eventBus = self.eventBus,
                restoreState = self.restoreState,
            })

            if not recovered then
                self.session:Fail(err)
                self.eventBus:Emit("session_failed", { error = err })
                return
            end
        end

        if not hasMore then
            -- 所有步骤完成
            local results = self.executor:GetResults()
            self.session:Complete(results)
            self.eventBus:Emit("session_completed", { results = results })
            return
        end
    end
end

--- 暂停代理
function AgentRunner:Pause(reason)
    if self.session then
        self.session:Pause(reason)
    end
end

--- 恢复代理
function AgentRunner:Resume()
    if self.session then
        self.session:Resume()
    end
end

--- 获取进度
function AgentRunner:GetProgress()
    return self.executor:GetProgress()
end

--- 获取会话状态
function AgentRunner:GetState()
    if not self.session then return "idle" end
    return self.session.state
end

--- 持久化当前会话
---@param filename string
function AgentRunner:SaveSession(filename)
    if not self.session then return false end
    local data = {
        session = self.session:Serialize(),
        executor = self.executor:GetResults(),
        gameState = self.captureState(),
    }
    local cjson = require("cjson")
    local jsonStr = cjson.encode(data)
    local file = File:new(filename, FILE_WRITE)
    if file then
        file:WriteString(jsonStr)
        file:Close()
        return true
    end
    return false
end

--- 从文件恢复会话
---@param filename string
function AgentRunner:LoadSession(filename)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_READ)
    if not file then return false end
    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then return false end

    self.session = AgentSession.Deserialize(data.session)

    if data.gameState then
        self.restoreState(data.gameState)
    end

    return true
end

return AgentRunner
```

---

## §10 完整集成示例 — NPC 自治代理

### 10.1 场景描述

一个 3D 场景中的 NPC 守卫，自治执行"巡逻→发现敌人→战斗→返回"的完整任务循环。
展示全部 6 个模块的协同工作。

### 10.2 项目结构

```
scripts/
├── main.lua                         -- 入口：场景搭建 + 代理启动
└── AgentFramework/
    ├── AgentSession.lua             -- 会话生命周期
    ├── ToolRegistry.lua             -- 工具注册
    ├── EventBus.lua                 -- 事件总线
    ├── PlanExecutor.lua             -- 计划执行
    ├── CheckpointManager.lua        -- 检查点管理
    ├── SelfHealer.lua               -- 自修复
    └── AgentRunner.lua              -- 运行时编排
```

### 10.3 完整代码

```lua
-- scripts/main.lua
-- NPC 自治代理演示：守卫巡逻 + 战斗 + 自修复

require "LuaScripts/Utilities/Sample"

local AgentRunner = require("scripts.AgentFramework.AgentRunner")

-- 全局变量
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Node
local guardNode_ = nil
---@type Node
local enemyNode_ = nil

-- NPC 状态
local guardState = {
    hp = 100,
    position = Vector3(0, 1, 0),
    inventory = {},
    enemyDetected = false,
    patrolIndex = 1,
}

-- 代理运行器
local runner = nil

-- 巡逻路径点
local patrolPoints = {
    Vector3(0, 1, 0),
    Vector3(10, 1, 0),
    Vector3(10, 1, 10),
    Vector3(0, 1, 10),
}

function Start()
    SampleInitMouseMode(MM_RELATIVE)

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    -- 灯光
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(1, 1, 1)
    light.brightness = 1.0

    -- 地面
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(5, 0, 5)
    floorNode.scale = Vector3(30, 0.1, 30)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.6, 0.3, 1.0)))
    floorMat:SetShaderParameter("Roughness", Variant(0.8))
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorModel:SetMaterial(floorMat)

    -- 守卫 NPC
    guardNode_ = scene_:CreateChild("Guard")
    guardNode_.position = Vector3(0, 1, 0)
    local guardModel = guardNode_:CreateComponent("StaticModel")
    guardModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local guardMat = Material:new()
    guardMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    guardMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.5, 1.0, 1.0)))
    guardMat:SetShaderParameter("Roughness", Variant(0.3))
    guardMat:SetShaderParameter("Metallic", Variant(0.7))
    guardModel:SetMaterial(guardMat)

    -- 敌人
    enemyNode_ = scene_:CreateChild("Enemy")
    enemyNode_.position = Vector3(8, 1, 8)
    local enemyModel = enemyNode_:CreateComponent("StaticModel")
    enemyModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local enemyMat = Material:new()
    enemyMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    enemyMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.2, 0.2, 1.0)))
    enemyMat:SetShaderParameter("Roughness", Variant(0.3))
    enemyMat:SetShaderParameter("Metallic", Variant(0.5))
    enemyModel:SetMaterial(enemyMat)

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(5, 15, -5)
    cameraNode_:LookAt(Vector3(5, 0, 5))
    local camera = cameraNode_:CreateComponent("Camera")
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- ===== 初始化代理框架 =====
    runner = AgentRunner.Create({
        maxRetries = 3,
        maxCheckpoints = 10,
        stepsPerFrame = 1,

        -- 状态快照回调
        captureState = function()
            return {
                hp = guardState.hp,
                position = { guardState.position.x, guardState.position.y, guardState.position.z },
                patrolIndex = guardState.patrolIndex,
                enemyDetected = guardState.enemyDetected,
            }
        end,

        restoreState = function(state)
            guardState.hp = state.hp
            guardState.position = Vector3(state.position[1], state.position[2], state.position[3])
            guardState.patrolIndex = state.patrolIndex
            guardState.enemyDetected = state.enemyDetected
            guardNode_.position = guardState.position
        end,

        -- 目标分解规则
        decomposeRules = {
            ["patrol_and_guard"] = {
                { name = "go_wp1", toolName = "move_to",
                  args = { target = patrolPoints[1] } },
                { name = "scan_1", toolName = "scan_area",
                  args = { center = patrolPoints[1], radius = 8 } },
                { name = "go_wp2", toolName = "move_to",
                  args = { target = patrolPoints[2] } },
                { name = "scan_2", toolName = "scan_area",
                  args = { center = patrolPoints[2], radius = 8 } },
                { name = "go_wp3", toolName = "move_to",
                  args = { target = patrolPoints[3] } },
                { name = "scan_3", toolName = "scan_area",
                  args = { center = patrolPoints[3], radius = 8 } },
                { name = "go_wp4", toolName = "move_to",
                  args = { target = patrolPoints[4] } },
                { name = "scan_4", toolName = "scan_area",
                  args = { center = patrolPoints[4], radius = 8 } },
            },
        },
    })

    -- 注册工具
    runner:RegisterTool({
        name = "move_to",
        description = "移动守卫到目标位置",
        tags = { "navigation", "movement" },
        cost = 2,
        execute = function(args)
            local target = args.target
            guardState.position = target
            guardNode_.position = target
            print("[Guard] Moved to: " .. tostring(target))
            return { arrived = true }
        end,
    })

    runner:RegisterTool({
        name = "scan_area",
        description = "扫描区域寻找敌人",
        tags = { "perception" },
        cost = 1,
        execute = function(args)
            local center = args.center or guardState.position
            local radius = args.radius or 10
            local enemyPos = enemyNode_.position
            local dist = (enemyPos - center):Length()
            local detected = dist <= radius

            if detected then
                guardState.enemyDetected = true
                print("[Guard] Enemy detected at distance: " .. string.format("%.1f", dist))
            else
                print("[Guard] Area clear (nearest: " .. string.format("%.1f", dist) .. ")")
            end

            return { detected = detected, distance = dist }
        end,
    })

    runner:RegisterTool({
        name = "attack",
        description = "攻击敌人",
        tags = { "combat", "action" },
        cost = 5,
        execute = function(args)
            local damage = args.damage or 10
            print("[Guard] Attacking enemy for " .. damage .. " damage\!")
            return { hit = true, damage = damage }
        end,
    })

    -- 监听事件
    runner.eventBus:On("session_started", function(data)
        print("[Event] Session started: " .. (data.goal or ""))
    end)
    runner.eventBus:On("session_completed", function(data)
        print("[Event] Session completed\!")
    end)
    runner.eventBus:On("error_detected", function(data)
        print("[Event] Error detected: " .. (data.error or ""))
    end)
    runner.eventBus:On("error_recovered", function(data)
        print("[Event] Recovered via strategy: " .. (data.strategy or ""))
    end)

    -- 启动巡逻任务
    runner:StartGoal("patrol_and_guard")

    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 每帧驱动代理
    if runner then
        runner:Tick(dt)

        -- 任务完成后重新开始
        if runner:GetState() == "finished" then
            print("[Main] Patrol cycle done, restarting...")
            runner:StartGoal("patrol_and_guard")
        end
    end
end
```

---

## §11 应用场景

| # | 场景 | 模块组合 | 示例 |
|---|------|---------|------|
| 1 | NPC 自治巡逻 | Session + Plan + Tool | 守卫自动巡逻路线 |
| 2 | 任务自动执行 | Plan + Tool + Checkpoint | RPG 任务链自动推进 |
| 3 | 可回滚游戏操作 | Checkpoint + Healer | 策略游戏撤销操作 |
| 4 | 事件驱动 UI 编排 | EventBus + Session | 复杂 UI 状态流转 |
| 5 | 容错 NPC 行为 | Healer + Tool + Checkpoint | NPC 卡住自动恢复 |
| 6 | 动态能力系统 | ToolRegistry | RPG 技能装备/卸载 |
| 7 | 游戏录像/回放 | Checkpoint + EventBus | 记录每步并回放 |
| 8 | 教程自动执行 | Plan + EventBus | 新手引导自动推进 |

---

## §12 Skill 协作

| 协作 Skill | 关系 | 协作方式 |
|-----------|------|---------|
| `behavior-tree-ai` | 互补 | 行为树管每帧微决策，Agent 管跨帧宏任务 |
| `game-save-system` | 互补 | 存档系统提供持久化层，Checkpoint 用于运行时快照 |
| `game-mission-orchestrator` | 互补 | 任务编排定义任务图，Agent 执行单个任务节点 |
| `evolutionary-game-systems` | 可选 | 用 GA 进化工具选择策略或任务分解规则 |
| `audio-manager` | 可选 | 代理事件触发音效（检测敌人→警报音效） |

---

## §13 构建与调试

### 13.1 项目文件结构

```
scripts/
├── main.lua                         -- 入口文件
└── AgentFramework/
    ├── AgentSession.lua             -- §3 会话生命周期
    ├── ToolRegistry.lua             -- §4 工具注册
    ├── EventBus.lua                 -- §5 事件总线
    ├── PlanExecutor.lua             -- §6 计划执行
    ├── CheckpointManager.lua        -- §7 检查点管理
    ├── SelfHealer.lua               -- §8 自修复
    └── AgentRunner.lua              -- §9 运行时编排
```

### 13.2 构建步骤

1. 将上述模块文件放入 `scripts/AgentFramework/` 目录
2. 在 `scripts/main.lua` 中引用 `AgentRunner`
3. 调用 UrhoX MCP 构建工具进行构建
4. 预览验证代理行为

### 13.3 调试技巧

```lua
-- 启用事件日志
runner.eventBus:EnableLog(true)

-- 每 5 秒打印一次进度
local logTimer = 0
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    logTimer = logTimer + dt
    if logTimer > 5 then
        logTimer = 0
        local done, total = runner:GetProgress()
        print(string.format("[Debug] Progress: %d/%d | State: %s",
            done, total, runner:GetState()))
    end
end
```

### 13.4 性能注意事项

| 配置 | 建议值 | 说明 |
|------|--------|------|
| `stepsPerFrame` | 1-3 | 每帧执行步骤数，过多会卡顿 |
| `maxCheckpoints` | 10-20 | 过多会占用内存 |
| `maxRetries` | 2-5 | 过多会导致卡死循环 |
| 工具 `execute` 耗时 | < 1ms | 避免在工具中执行复杂计算 |

---

## §14 Devon → 游戏映射设计原则

### 14.1 概念映射表

| Devon 概念 | 游戏映射 | 说明 |
|-----------|---------|------|
| Session | NPC 任务会话 | 一个完整任务的生命周期 |
| Tool | NPC 能力/技能 | 可注册/注销的行为原子 |
| Event Loop | HandleUpdate + EventBus | 帧驱动 + 事件分发 |
| Checkpoint | 状态快照 | 运行时状态保存/回滚 |
| Self-healing | 自修复循环 | 错误→回滚→替代→重试 |
| Agent Loop | PlanExecutor | 目标→分解→顺序执行→完成 |
| File Tools | 移动/拾取工具 | 游戏世界交互原子 |
| Code Search | 感知/扫描工具 | 环境信息采集 |
| Conversation | 事件广播 | 代理间松耦合通信 |
| Directory Scope | 活动范围 | NPC 的行动半径限制 |

### 14.2 设计决策

| 决策 | Devon 原版 | 游戏适配 | 原因 |
|------|-----------|---------|------|
| 执行模式 | 异步 Python | 同步每帧 tick | 游戏循环是同步的 |
| 状态存储 | 文件系统 | cjson + File API | UrhoX 沙箱内文件读写 |
| 工具发现 | LLM 推理选择 | 标签匹配 + 规则 | 无需外部 LLM，纯 Lua 规则 |
| 错误恢复 | 用户介入 | 自动策略链 | 游戏运行时无法等用户 |
| 上下文管理 | Token 窗口 | Lua 表引用 | 无 token 限制 |

---

## §15 API 速查

### AgentSession

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create(config)` | `{ id, goal, context }` | session | 创建会话 |
| `Start()` | — | bool, err | 启动会话 |
| `Pause(reason)` | string | bool, err | 暂停 |
| `Resume()` | — | bool, err | 恢复 |
| `Complete(result)` | any | bool | 完成 |
| `Fail(error)` | string | bool | 失败 |
| `IsActive()` | — | bool | 是否活跃 |
| `GetElapsed()` | — | number | 运行时长 |
| `SetContext(k, v)` | string, any | — | 设置上下文 |
| `GetContext(k)` | string | any | 获取上下文 |
| `Serialize()` | — | table | 序列化 |
| `Deserialize(data)` | table | session | 反序列化 |

### ToolRegistry

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create()` | — | registry | 创建注册表 |
| `Register(tool)` | ToolDef | bool, err | 注册工具 |
| `Unregister(name)` | string | bool | 注销工具 |
| `FindTool(name)` | string | tool? | 按名称查找 |
| `FindByTag(tag)` | string | tools[] | 按标签查找 |
| `ListTools()` | — | infos[] | 列出所有工具 |
| `Execute(name, args)` | string, table | result, err | 执行工具 |
| `GetStats(name)` | string | stats? | 使用统计 |

### EventBus

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create()` | — | bus | 创建事件总线 |
| `On(event, cb, priority?)` | string, func, num? | listenerId | 订阅 |
| `Once(event, cb)` | string, func | listenerId | 一次性订阅 |
| `Off(listenerId)` | number | — | 取消订阅 |
| `OffAll(event)` | string | — | 取消全部 |
| `Emit(event, data?)` | string, table? | — | 发布事件 |
| `AddFilter(filter)` | func | — | 全局过滤器 |
| `EnableLog(enabled)` | bool | — | 启用日志 |

### PlanExecutor

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create(config)` | table | executor | 创建执行器 |
| `AddStep(step)` | StepDef | — | 添加步骤 |
| `Decompose(goal, rules)` | string, table | bool, err | 目标分解 |
| `ExecuteNext(registry)` | ToolRegistry | hasMore, result, err | 执行下一步 |
| `RetryCurrent(registry)` | ToolRegistry | canRetry, result, err | 重试 |
| `GetProgress()` | — | done, total | 进度 |
| `GetResults()` | — | results[] | 结果摘要 |
| `Reset()` | — | — | 重置 |

### CheckpointManager

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create(config)` | table | manager | 创建管理器 |
| `Save(label, state)` | string, table | checkpointId | 保存快照 |
| `Load(id)` | string | state?, err | 加载快照 |
| `RollbackLatest()` | — | state?, cpId | 回滚到最新 |
| `RollbackToLabel(label)` | string | state?, cpId | 回滚到标签 |
| `List()` | — | infos[] | 列出所有 |
| `Clear()` | — | — | 清除全部 |
| `SaveToFile(filename)` | string | — | 持久化到文件 |
| `LoadFromFile(filename)` | string | bool | 从文件恢复 |

### SelfHealer

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create(config)` | table | healer | 创建修复器 |
| `Handle(error, context)` | string, table | recovered, strategy | 处理错误 |
| `Reset()` | — | — | 重置 |
| `GetLog()` | — | entries[] | 修复日志 |

### AgentRunner

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `Create(config)` | table | runner | 创建编排器 |
| `RegisterTool(tool)` | ToolDef | bool, err | 注册工具 |
| `StartGoal(goal, ctx?)` | string, table? | bool | 启动目标 |
| `Tick(dt)` | number | — | 每帧驱动 |
| `Pause(reason)` | string | — | 暂停 |
| `Resume()` | — | — | 恢复 |
| `GetProgress()` | — | done, total | 进度 |
| `GetState()` | — | string | 会话状态 |
| `SaveSession(filename)` | string | bool | 持久化会话 |
| `LoadSession(filename)` | string | bool | 恢复会话 |
