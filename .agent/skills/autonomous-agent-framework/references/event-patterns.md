---
title: "Event Patterns — 事件总线使用模式与常见事件流"
parent: autonomous-agent-framework
---

# Event Patterns — 事件总线使用模式

> 本文档为 `autonomous-agent-framework` 的参考手册，介绍 EventBus 的设计模式、常见事件流和游戏中的典型应用。

---

## §1 事件命名规范

### 1.1 命名格式

```
<domain>:<action>       -- 标准格式
<domain>:<entity>:<action>  -- 精细格式
```

| 域名 | 含义 | 示例 |
|------|------|------|
| `session` | 会话生命周期 | `session:started`, `session:paused` |
| `plan` | 计划执行 | `plan:step_completed`, `plan:failed` |
| `tool` | 工具调用 | `tool:executed`, `tool:failed` |
| `checkpoint` | 检查点 | `checkpoint:saved`, `checkpoint:restored` |
| `heal` | 自修复 | `heal:attempt`, `heal:success` |
| `agent` | 代理通用 | `agent:goal_set`, `agent:idle` |
| `game` | 游戏逻辑 | `game:enemy_spotted`, `game:item_picked` |

### 1.2 内置事件清单

```lua
-- 会话事件
local SessionEvents = {
    STARTED   = "session:started",    -- { sessionId }
    PAUSED    = "session:paused",     -- { sessionId, reason }
    RESUMED   = "session:resumed",    -- { sessionId }
    COMPLETED = "session:completed",  -- { sessionId, result }
    FAILED    = "session:failed",     -- { sessionId, error }
}

-- 计划事件
local PlanEvents = {
    STEP_STARTED   = "plan:step_started",    -- { stepIndex, description }
    STEP_COMPLETED = "plan:step_completed",  -- { stepIndex, result }
    STEP_FAILED    = "plan:step_failed",     -- { stepIndex, error }
    ALL_COMPLETED  = "plan:all_completed",   -- { totalSteps, results }
    DECOMPOSED     = "plan:decomposed",      -- { goal, stepCount }
}

-- 工具事件
local ToolEvents = {
    REGISTERED = "tool:registered",  -- { toolName }
    EXECUTED   = "tool:executed",    -- { toolName, params, result }
    FAILED     = "tool:failed",      -- { toolName, params, error }
}

-- 检查点事件
local CheckpointEvents = {
    SAVED    = "checkpoint:saved",    -- { label, index }
    RESTORED = "checkpoint:restored", -- { label, index }
    CLEARED  = "checkpoint:cleared",  -- {}
}

-- 自修复事件
local HealEvents = {
    ATTEMPT  = "heal:attempt",   -- { strategy, error }
    SUCCESS  = "heal:success",   -- { strategy, result }
    FAILED   = "heal:failed",    -- { strategy, error }
    ESCALATE = "heal:escalate",  -- { fromStrategy, toStrategy }
}
```

---

## §2 基础模式

### 2.1 观察者模式 — 解耦事件源与监听器

```lua
-- 场景：多个系统响应同一事件

local eventBus = EventBus.Create()

-- UI 系统监听
eventBus:On("agent:health_changed", function(data)
    UpdateHealthBar(data.current, data.max)
end)

-- 音效系统监听
eventBus:On("agent:health_changed", function(data)
    if data.current < data.max * 0.2 then
        PlaySound("Sounds/low_health_warning.ogg")
    end
end)

-- 粒子系统监听
eventBus:On("agent:health_changed", function(data)
    if data.delta < 0 then
        SpawnDamageParticles(data.position, math.abs(data.delta))
    end
end)

-- 触发事件 — 所有监听器自动响应
eventBus:Emit("agent:health_changed", {
    current = 25,
    max = 100,
    delta = -15,
    position = agentNode.position,
})
```

### 2.2 一次性事件 — Once 模式

```lua
-- 场景：只需要响应一次的事件

-- 等待首次发现敌人
eventBus:Once("agent:enemy_spotted", function(data)
    log:Write(LOG_INFO, "首次发现敌人！切换到战斗模式")
    agent:StartGoal("消灭敌人 " .. data.enemyName)
end)

-- 等待任务完成的一次性回调
eventBus:Once("plan:all_completed", function(data)
    log:Write(LOG_INFO, "所有步骤完成，总计: " .. data.totalSteps)
    RewardPlayer(100)
end)
```

### 2.3 优先级排序 — 控制执行顺序

```lua
-- 场景：多个处理器需要按特定顺序执行

-- 优先级越高越先执行（默认 0）
eventBus:On("agent:damaged", function(data)
    -- 最先执行：检查护盾
    if data.context.shieldActive then
        data.damage = data.damage * 0.5
        data.shieldAbsorbed = true
    end
end, 100)  -- 优先级 100

eventBus:On("agent:damaged", function(data)
    -- 其次：应用防御减免
    if data.context.isDefending then
        data.damage = data.damage * data.context.defenseMultiplier
    end
end, 50)  -- 优先级 50

eventBus:On("agent:damaged", function(data)
    -- 最后：实际扣血
    data.context.health = (data.context.health or 100) - data.damage
end, 0)  -- 优先级 0（默认）
```

### 2.4 事件过滤 — 全局拦截器

```lua
-- 场景：统一过滤某类事件

eventBus:AddFilter(function(eventName, data)
    -- 当代理处于无敌状态时，忽略所有伤害事件
    if eventName == "agent:damaged" and data.context.isInvincible then
        log:Write(LOG_DEBUG, "无敌状态，伤害事件被过滤")
        return false  -- 阻止事件传播
    end
    return true  -- 允许事件继续
end)
```

---

## §3 高级模式

### 3.1 事件链 — 级联触发

```lua
-- 场景：一个事件触发另一个事件，形成处理链

eventBus:On("agent:attack_landed", function(data)
    -- 攻击命中 → 触发伤害事件
    eventBus:Emit("agent:damaged", {
        target = data.target,
        damage = data.damage,
        source = data.attacker,
        context = data.targetContext,
    })
end)

eventBus:On("agent:damaged", function(data)
    -- 伤害事件 → 检查是否死亡
    if data.context.health <= 0 then
        eventBus:Emit("agent:died", {
            agent = data.target,
            killer = data.source,
            position = data.target.position,
        })
    end
end)

eventBus:On("agent:died", function(data)
    -- 死亡事件 → 掉落物品 + 计分
    SpawnLoot(data.position)
    AddScore(data.killer, 50)
    eventBus:Emit("game:score_changed", { player = data.killer, delta = 50 })
end)
```

> **注意**：避免无限循环事件链。确保链条有终止条件。

### 3.2 状态机驱动 — 结合 AgentSession

```lua
-- 场景：根据会话状态切换行为

eventBus:On("session:started", function(data)
    log:Write(LOG_INFO, "代理开始执行任务")
    -- 启动心跳计时器
    data.context.heartbeatTimer = 0
end)

eventBus:On("session:paused", function(data)
    log:Write(LOG_INFO, "代理暂停: " .. (data.reason or "unknown"))
    -- 暂停所有动画
    StopAgentAnimations(data.context.agentNode)
end)

eventBus:On("session:resumed", function(data)
    log:Write(LOG_INFO, "代理恢复执行")
    ResumeAgentAnimations(data.context.agentNode)
end)
```

### 3.3 事件聚合 — 收集多源数据

```lua
-- 场景：等待多个条件都满足后触发

local conditions = {
    allEnemiesCleared = false,
    allItemsCollected = false,
    timeUnder60s = false,
}

local function CheckAllConditions()
    for _, v in pairs(conditions) do
        if not v then return end
    end
    eventBus:Emit("game:perfect_clear", { conditions = conditions })
end

eventBus:On("game:enemies_cleared", function()
    conditions.allEnemiesCleared = true
    CheckAllConditions()
end)

eventBus:On("game:items_collected", function()
    conditions.allItemsCollected = true
    CheckAllConditions()
end)

eventBus:On("game:time_check", function(data)
    conditions.timeUnder60s = data.elapsed < 60.0
    CheckAllConditions()
end)
```

### 3.4 节流与防抖 — 控制事件频率

```lua
-- 场景：高频事件（如每帧位置更新）需要降频处理

local lastEmitTime = {}
local THROTTLE_INTERVAL = 0.5  -- 最多每 0.5 秒触发一次

--- 节流发送事件
---@param bus table EventBus 实例
---@param eventName string
---@param data table
---@param interval number? 节流间隔（秒），默认 0.5
local function ThrottledEmit(bus, eventName, data, interval)
    local now = data.currentTime or 0
    local last = lastEmitTime[eventName] or 0
    interval = interval or THROTTLE_INTERVAL

    if now - last >= interval then
        bus:Emit(eventName, data)
        lastEmitTime[eventName] = now
    end
end

-- 使用
-- 在 HandleUpdate 中：
-- ThrottledEmit(eventBus, "agent:position_updated", {
--     position = node.position,
--     currentTime = timeStep,
-- }, 0.3)
```

---

## §4 游戏场景事件流

### 4.1 NPC 巡逻-战斗流程

```
[开始巡逻]
    │
    ├── agent:patrol_started ──────── UI 显示巡逻图标
    │
    ├── (每帧 Tick)
    │   ├── agent:waypoint_reached ─── 更新路径点指示
    │   └── scan_area 工具执行
    │       ├── (无敌人) → 继续巡逻
    │       └── (发现敌人) → agent:enemy_spotted
    │
    ├── agent:enemy_spotted ──────── 切换到战斗
    │   ├── checkpoint:saved ──────── 保存巡逻进度
    │   ├── session:paused ────────── 暂停巡逻会话
    │   └── 创建战斗子目标
    │
    ├── [战斗循环]
    │   ├── tool:executed (attack)
    │   ├── agent:damaged
    │   ├── heal:attempt (如果出错)
    │   └── agent:died 或 agent:enemy_defeated
    │
    ├── agent:enemy_defeated ─────── 恢复巡逻
    │   ├── checkpoint:restored ────── 恢复巡逻进度
    │   └── session:resumed
    │
    └── plan:all_completed ────────── 巡逻完成
```

### 4.2 任务系统流程

```
[接受任务]
    │
    ├── plan:decomposed ──────────── 任务分解为子步骤
    │   └── UI 显示任务步骤列表
    │
    ├── [执行步骤 1..N]
    │   ├── plan:step_started ────── 高亮当前步骤
    │   ├── tool:executed ─────────── 显示执行动画
    │   │
    │   ├── (成功) → plan:step_completed
    │   │   └── UI 打钩 ✓
    │   │
    │   └── (失败) → plan:step_failed
    │       ├── heal:attempt ──────── 尝试自修复
    │       ├── (修复成功) → 重试
    │       └── (修复失败) → heal:escalate
    │           ├── checkpoint:restored ── 回滚到上一个存档
    │           └── 从存档点重新执行
    │
    └── plan:all_completed ────────── 任务完成
        ├── 计算奖励
        └── game:quest_completed
```

### 4.3 自修复流程

```
[错误发生]
    │
    ├── heal:attempt {strategy: "RETRY"}
    │   ├── (成功) → heal:success → 继续执行
    │   └── (失败) → heal:escalate
    │
    ├── heal:attempt {strategy: "ROLLBACK"}
    │   ├── checkpoint:restored
    │   ├── (成功) → heal:success → 从检查点重试
    │   └── (失败) → heal:escalate
    │
    ├── heal:attempt {strategy: "ALTERNATE_TOOL"}
    │   ├── 查找同标签替代工具
    │   ├── (成功) → heal:success → 用替代工具继续
    │   └── (失败) → heal:escalate
    │
    └── heal:attempt {strategy: "SKIP"}
        ├── 跳过当前步骤
        └── heal:success → 执行下一步骤
```

---

## §5 事件与引擎集成

### 5.1 桥接 UrhoX 引擎事件

```lua
-- 将引擎事件桥接到 EventBus

local function BridgeEngineEvents(eventBus, scene)
    -- 物理碰撞 → EventBus
    SubscribeToEvent("PhysicsCollisionStart", function(eventType, eventData)
        local nodeA = eventData["NodeA"]:GetPtr("Node")
        local nodeB = eventData["NodeB"]:GetPtr("Node")

        eventBus:Emit("physics:collision_start", {
            nodeA = nodeA,
            nodeB = nodeB,
        })
    end)

    -- 节点移除 → EventBus
    SubscribeToEvent("NodeRemoved", function(eventType, eventData)
        local node = eventData["Node"]:GetPtr("Node")
        eventBus:Emit("scene:node_removed", {
            node = node,
            name = node.name,
        })
    end)
end
```

### 5.2 事件日志与调试

```lua
-- 开启详细事件日志（调试用）
eventBus.logEvents = true

-- 自定义日志过滤
eventBus.logFilter = function(eventName)
    -- 只记录非高频事件
    return not eventName:match("^agent:position")
        and not eventName:match("^agent:heartbeat")
end

-- 导出事件历史用于分析
local function ExportEventLog(eventBus, filename)
    local cjson = require("cjson")
    local logData = {}
    for i, entry in ipairs(eventBus.eventLog) do
        table.insert(logData, {
            index = i,
            event = entry.event,
            time = entry.time,
            -- 注意：不序列化 userdata（如 Node）
        })
    end

    local f = File:new(filename, FILE_WRITE)
    if f then
        f:WriteLine(cjson.encode(logData))
        f:Close()
        log:Write(LOG_INFO, "事件日志已保存: " .. filename)
    end
end
```

---

## §6 性能建议

| 建议 | 说明 |
|------|------|
| 避免高频 Emit | 不要每帧对每个代理都 Emit 位置更新，使用节流（§3.4） |
| 限制监听器数量 | 单个事件建议不超过 10 个监听器 |
| 及时 Off | 代理销毁时移除所有监听器，防止回调空指针 |
| 使用 Once | 一次性逻辑用 Once 而非 On+手动 Off |
| 过滤器轻量 | 全局过滤器在每次 Emit 时都执行，保持简单 |
| 避免循环链 | A→B→C→A 会导致无限递归 |

---

## §7 构建

将事件模式代码放在 `scripts/` 目录下，编写完成后调用 UrhoX MCP `build` 工具构建项目。

