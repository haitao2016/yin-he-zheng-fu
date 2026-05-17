---
title: "Checkpoint Strategies — 检查点策略与回滚模式"
parent: autonomous-agent-framework
---

# Checkpoint Strategies — 检查点策略与回滚模式

> 本文档为 `autonomous-agent-framework` 的参考手册，介绍 CheckpointManager 的使用策略、存储优化和常见回滚模式。

---

## §1 检查点基础概念

### 1.1 什么是检查点

检查点（Checkpoint）是代理运行时状态的快照，包含：

| 数据 | 说明 | 示例 |
|------|------|------|
| 位置 | 代理在世界中的坐标 | `Vector3(10, 0, 5)` |
| 会话上下文 | 所有 context 中的可序列化数据 | health, mana, inventory |
| 计划进度 | PlanExecutor 的步骤状态 | 第 3/5 步已完成 |
| 自定义状态 | 通过 captureState 回调捕获的额外数据 | 巡逻路径点索引、战斗目标 |

### 1.2 何时保存检查点

| 时机 | 原因 | 标签建议 |
|------|------|---------|
| 任务开始前 | 任务失败可完全回滚 | `"task_start"` |
| 关键步骤完成后 | 避免重复已完成的工作 | `"step_N_done"` |
| 状态切换时 | 巡逻→战斗前保存巡逻进度 | `"before_combat"` |
| 获得重要物品后 | 防止因错误丢失已获取的物品 | `"item_acquired"` |
| 定期自动保存 | 防止长时间运行中的意外丢失 | `"auto_T"` (T=时间) |

---

## §2 存储策略

### 2.1 内存存储（默认）

检查点默认存储在 Lua table 中，生命周期与游戏进程相同。

```lua
local checkpointMgr = CheckpointManager.Create({ maxCheckpoints = 10 })

-- 保存
checkpointMgr:Save(currentState, "before_boss")

-- 恢复
local state = checkpointMgr:RollbackToLabel("before_boss")
```

**优点**：速度快、实现简单
**缺点**：游戏退出后丢失、占用运行时内存

### 2.2 文件持久化

使用 `File:new()` API 将检查点写入文件系统，实现跨会话持久化。

```lua
local cjson = require("cjson")

-- 保存到文件
local function SaveCheckpointToFile(checkpointMgr, filename)
    local allCheckpoints = checkpointMgr:List()
    local serializable = {}

    for i, cp in ipairs(allCheckpoints) do
        -- 过滤不可序列化的字段（如 Node 引用）
        local clean = FilterSerializable(cp.state)
        table.insert(serializable, {
            label = cp.label,
            index = cp.index,
            state = clean,
        })
    end

    local f = File:new(filename, FILE_WRITE)
    if f then
        f:WriteLine(cjson.encode(serializable))
        f:Close()
        log:Write(LOG_INFO, "检查点已持久化: " .. filename)
        return true
    end
    return false
end

-- 从文件恢复
local function LoadCheckpointsFromFile(checkpointMgr, filename)
    local f = File:new(filename, FILE_READ)
    if not f then
        log:Write(LOG_WARNING, "检查点文件不存在: " .. filename)
        return false
    end

    local content = f:ReadLine()
    f:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then
        log:Write(LOG_ERROR, "检查点文件格式错误")
        return false
    end

    -- 重建检查点
    checkpointMgr:Clear()
    for _, cp in ipairs(data) do
        checkpointMgr:Save(cp.state, cp.label)
    end

    log:Write(LOG_INFO, "已恢复 " .. #data .. " 个检查点")
    return true
end
```

### 2.3 可序列化数据过滤

```lua
--- 过滤掉不可序列化的字段（userdata、function 等）
---@param state table
---@return table
local function FilterSerializable(state)
    local result = {}
    for k, v in pairs(state) do
        local t = type(v)
        if t == "number" or t == "string" or t == "boolean" then
            result[k] = v
        elseif t == "table" then
            result[k] = FilterSerializable(v)
        end
        -- 跳过 function, userdata, thread
    end
    return result
end

--- 将 Vector3 转为可序列化格式
---@param vec Vector3
---@return table
local function SerializeVector3(vec)
    return { x = vec.x, y = vec.y, z = vec.z }
end

--- 从序列化格式恢复 Vector3
---@param t table
---@return Vector3
local function DeserializeVector3(t)
    return Vector3(t.x, t.y, t.z)
end
```

### 2.4 captureState / restoreState 回调

AgentRunner 通过回调函数让用户自定义状态捕获和恢复逻辑：

```lua
local runner = AgentRunner.Create({
    captureState = function(context)
        -- 捕获需要保存的游戏状态
        return {
            position = SerializeVector3(context.agentNode.position),
            rotation = {
                w = context.agentNode.rotation.w,
                x = context.agentNode.rotation.x,
                y = context.agentNode.rotation.y,
                z = context.agentNode.rotation.z,
            },
            health = context.health,
            mana = context.mana,
            inventory = context.inventory,
            patrolIndex = context.patrolIndex,
            questProgress = context.questProgress,
        }
    end,

    restoreState = function(context, savedState)
        -- 恢复游戏状态
        if savedState.position then
            context.agentNode.position = DeserializeVector3(savedState.position)
        end
        if savedState.rotation then
            local r = savedState.rotation
            context.agentNode.rotation = Quaternion(r.w, r.x, r.y, r.z)
        end
        context.health = savedState.health
        context.mana = savedState.mana
        context.inventory = savedState.inventory
        context.patrolIndex = savedState.patrolIndex
        context.questProgress = savedState.questProgress
    end,
})
```

---

## §3 回滚策略

### 3.1 立即回滚 — 错误发生时恢复最近检查点

```lua
-- SelfHealer 的 ROLLBACK 策略使用此模式
local function RollbackOnError(checkpointMgr, context, restoreState)
    local latest = checkpointMgr:RollbackLatest()
    if latest then
        restoreState(context, latest)
        log:Write(LOG_INFO, "已回滚到最近的检查点")
        return true
    end
    log:Write(LOG_WARNING, "没有可用的检查点")
    return false
end
```

### 3.2 标签回滚 — 回到指定锚点

```lua
-- 回到任务开始前的状态
local function RollbackToTaskStart(checkpointMgr, context, restoreState)
    local state = checkpointMgr:RollbackToLabel("task_start")
    if state then
        restoreState(context, state)
        log:Write(LOG_INFO, "已回滚到任务起点")
        return true
    end
    return false
end
```

### 3.3 条件回滚 — 根据状态决定回滚深度

```lua
--- 智能回滚：根据错误严重程度选择回滚深度
---@param errorLevel string "minor"|"major"|"critical"
local function SmartRollback(checkpointMgr, context, restoreState, errorLevel)
    if errorLevel == "minor" then
        -- 轻微错误：回到最近检查点
        local state = checkpointMgr:RollbackLatest()
        if state then
            restoreState(context, state)
            return true
        end

    elseif errorLevel == "major" then
        -- 严重错误：回到上一个阶段起点
        local checkpoints = checkpointMgr:List()
        for i = #checkpoints, 1, -1 do
            if checkpoints[i].label and checkpoints[i].label:match("^phase_") then
                local state = checkpointMgr:RollbackToLabel(checkpoints[i].label)
                if state then
                    restoreState(context, state)
                    return true
                end
            end
        end

    elseif errorLevel == "critical" then
        -- 致命错误：回到任务最初状态
        local checkpoints = checkpointMgr:List()
        if #checkpoints > 0 then
            -- 回滚到第一个检查点
            local state = checkpointMgr:Load(1)
            if state then
                restoreState(context, state)
                return true
            end
        end
    end

    return false
end
```

### 3.4 部分回滚 — 只恢复特定数据

```lua
--- 只恢复位置和生命值，保留背包和任务进度
local function PartialRollback(checkpointMgr, context)
    local savedState = checkpointMgr:RollbackLatest()
    if not savedState then return false end

    -- 只恢复部分状态
    if savedState.position then
        context.agentNode.position = DeserializeVector3(savedState.position)
    end
    context.health = savedState.health or context.health

    -- 保留当前的背包和任务进度（不回滚）
    log:Write(LOG_INFO, "部分回滚完成：位置和生命已恢复")
    return true
end
```

---

## §4 自动检查点策略

### 4.1 定时自动保存

```lua
--- 基于时间间隔的自动检查点
---@param runner table AgentRunner 实例
---@param interval number 保存间隔（秒）
local function SetupAutoSave(runner, interval)
    local lastSave = 0

    -- 在 Tick 中调用
    runner._autoSaveCheck = function(dt, context)
        lastSave = lastSave + dt
        if lastSave >= interval then
            lastSave = 0
            local state = runner.config.captureState(context)
            runner.checkpointMgr:Save(state, "auto_" .. math.floor(context.currentTime or 0))
            log:Write(LOG_DEBUG, "自动检查点已保存")
        end
    end
end

-- 使用
SetupAutoSave(runner, 30.0)  -- 每 30 秒自动保存
```

### 4.2 步骤完成自动保存

```lua
--- 每完成一个计划步骤就自动保存
local function SetupStepAutoSave(runner)
    runner.eventBus:On("plan:step_completed", function(data)
        local state = runner.config.captureState(runner.session.context)
        runner.checkpointMgr:Save(state, "step_" .. data.stepIndex .. "_done")
    end)
end
```

### 4.3 阶段性保存

```lua
--- 在关键阶段转换时保存
local function SetupPhaseCheckpoints(runner)
    local phases = {
        "exploration",   -- 探索阶段
        "combat",        -- 战斗阶段
        "collection",    -- 收集阶段
        "return",        -- 返回阶段
    }

    for _, phase in ipairs(phases) do
        runner.eventBus:On("agent:phase_" .. phase, function(data)
            local state = runner.config.captureState(runner.session.context)
            runner.checkpointMgr:Save(state, "phase_" .. phase)
            log:Write(LOG_INFO, "阶段检查点: " .. phase)
        end)
    end
end
```

---

## §5 存储优化

### 5.1 限制检查点数量

```lua
-- 设置最大检查点数量（默认 20）
local checkpointMgr = CheckpointManager.Create({ maxCheckpoints = 10 })

-- 超出限制时自动移除最老的检查点
-- CheckpointManager 内部实现：
-- if #self.checkpoints > self.maxCheckpoints then
--     table.remove(self.checkpoints, 1)
-- end
```

### 5.2 差分存储

```lua
--- 只存储与上一个检查点的差异，减少内存占用
---@param currentState table
---@param previousState table
---@return table diff 差异数据
local function ComputeDiff(currentState, previousState)
    local diff = {}
    for k, v in pairs(currentState) do
        if type(v) == "table" then
            if type(previousState[k]) == "table" then
                local subDiff = ComputeDiff(v, previousState[k])
                if next(subDiff) then
                    diff[k] = subDiff
                end
            else
                diff[k] = v
            end
        elseif v ~= previousState[k] then
            diff[k] = v
        end
    end
    return diff
end

--- 从差分数据恢复完整状态
---@param baseState table
---@param diff table
---@return table
local function ApplyDiff(baseState, diff)
    local result = {}
    -- 先复制基础状态
    for k, v in pairs(baseState) do
        if type(v) == "table" then
            result[k] = ApplyDiff(v, {})
        else
            result[k] = v
        end
    end
    -- 应用差异
    for k, v in pairs(diff) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = ApplyDiff(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end
```

### 5.3 选择性捕获

```lua
--- 只捕获变化频率高的字段，静态字段只在首次保存
local function SelectiveCapture(context, isFirstSave)
    local state = {
        -- 高频变化：每次保存
        position = SerializeVector3(context.agentNode.position),
        health = context.health,
        mana = context.mana,
        currentTime = context.currentTime,
    }

    if isFirstSave then
        -- 静态数据：只首次保存
        state.maxHealth = context.maxHealth
        state.maxMana = context.maxMana
        state.agentName = context.agentNode.name
        state.initialPosition = SerializeVector3(context.spawnPosition)
    end

    -- 中频变化：有变化才保存
    if context._inventoryChanged then
        state.inventory = context.inventory
        context._inventoryChanged = false
    end

    return state
end
```

---

## §6 错误恢复与检查点的协作

### 6.1 SelfHealer 回滚流程

```
错误发生
    │
    ├── 策略 1: RETRY（重试 3 次）
    │   └── 不涉及检查点
    │
    ├── 策略 2: ROLLBACK
    │   ├── checkpointMgr:RollbackLatest()
    │   ├── restoreState(context, savedState)
    │   ├── planExecutor:RetryCurrent()
    │   └── 从检查点恢复后重新执行当前步骤
    │
    ├── 策略 3: ALTERNATE_TOOL
    │   └── 不涉及检查点（换工具重试）
    │
    └── 策略 4: SKIP
        ├── 保存当前状态为检查点（标记为 "before_skip"）
        └── 跳过失败步骤，继续下一步
```

### 6.2 多层回滚防护

```lua
--- 为关键任务设置多层检查点防护
local function SetupMultiLayerProtection(runner)
    -- 第一层：每步完成保存
    runner.eventBus:On("plan:step_completed", function(data)
        local state = runner.config.captureState(runner.session.context)
        runner.checkpointMgr:Save(state, "step_" .. data.stepIndex)
    end)

    -- 第二层：自修复前保存
    runner.eventBus:On("heal:attempt", function(data)
        if data.strategy == "ROLLBACK" then
            -- 回滚前先保存当前状态（万一回滚后更差）
            local state = runner.config.captureState(runner.session.context)
            runner.checkpointMgr:Save(state, "pre_rollback")
        end
    end)

    -- 第三层：自修复失败后的兜底
    runner.eventBus:On("heal:failed", function(data)
        if data.strategy == "SKIP" then
            log:Write(LOG_WARNING, "所有修复策略失败，暂停代理等待外部干预")
            runner:Pause()
        end
    end)
end
```

---

## §7 常见问题

### Q1: 检查点太多导致内存增长怎么办？

**A**: 设置 `maxCheckpoints` 限制上限，旧检查点自动淘汰。对于长时间运行的代理，建议 `maxCheckpoints = 5~10`。

### Q2: 回滚后场景中的视觉状态不一致怎么办？

**A**: 在 `restoreState` 回调中同步更新视觉元素：

```lua
restoreState = function(context, savedState)
    -- 恢复数据
    context.health = savedState.health
    -- 同步视觉
    UpdateHealthBar(context.health, context.maxHealth)
    -- 恢复位置
    context.agentNode.position = DeserializeVector3(savedState.position)
end
```

### Q3: 如何避免回滚到"坏"状态？

**A**: 保存检查点前进行状态校验：

```lua
local function SafeSave(checkpointMgr, state, label, captureState)
    -- 校验状态合法性
    if state.health and state.health <= 0 then
        log:Write(LOG_WARNING, "不保存死亡状态的检查点")
        return false
    end
    if state.position and state.position.y < -100 then
        log:Write(LOG_WARNING, "不保存掉出地图的检查点")
        return false
    end
    checkpointMgr:Save(state, label)
    return true
end
```

### Q4: 如何实现"时间回溯"功能？

**A**: 使用高频检查点 + 顺序回放：

```lua
-- 每 0.5 秒保存一次快照（用于回放）
local replayBuffer = {}
local MAX_REPLAY_FRAMES = 120  -- 最多保存 60 秒

local function CaptureReplayFrame(context)
    table.insert(replayBuffer, {
        time = context.currentTime,
        position = SerializeVector3(context.agentNode.position),
        health = context.health,
    })
    if #replayBuffer > MAX_REPLAY_FRAMES then
        table.remove(replayBuffer, 1)
    end
end

-- 回溯 N 帧
local function RewindFrames(context, frames, restoreState)
    local targetIdx = math.max(1, #replayBuffer - frames)
    local state = replayBuffer[targetIdx]
    if state then
        restoreState(context, state)
        -- 截断未来帧
        for i = #replayBuffer, targetIdx + 1, -1 do
            table.remove(replayBuffer, i)
        end
        return true
    end
    return false
end
```

---

## §8 构建与测试

将检查点相关代码放在 `scripts/` 目录下的模块文件中：

```
scripts/
├── main.lua
├── Agent/
│   ├── CheckpointManager.lua   -- 核心检查点管理器
│   ├── CheckpointUtils.lua     -- 序列化/反序列化工具
│   └── AgentRunner.lua         -- 集成检查点的主框架
└── saves/                      -- 持久化文件目录
    └── agent_checkpoint.json
```

编写完成后调用 UrhoX MCP `build` 工具构建项目。

