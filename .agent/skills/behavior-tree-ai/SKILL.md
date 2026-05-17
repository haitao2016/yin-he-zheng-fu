---
name: "behavior-tree-ai"
version: "1.0.0"
trigger:
  keywords:
    - 行为树
    - AI
    - NPC
    - 敌人AI
    - 巡逻
    - 追击
    - 状态机
    - FSM
    - 决策树
    - behavior tree
    - BT
    - HTN
    - 怪物AI
    - BOSS AI
    - 寻路
    - 自主行为
    - AI系统
    - 游戏AI
    - 智能体
  auto_detect:
    - "用户需要为游戏角色/NPC/敌人/怪物实现AI行为"
    - "用户提到行为树、决策树、状态机等AI概念"
    - "用户需要实现巡逻、追击、逃跑、攻击等AI行为模式"
    - "用户需要BOSS战斗AI或复杂敌人行为"
    - "用户需要多个AI行为的组合与切换"
description: |
  基于腾讯 behaviac 框架核心概念的纯 Lua 行为树 AI 系统，
  专为 UrhoX 游戏引擎设计。提供行为树(BT)、游戏逻辑状态机(FSM)、
  分层任务网络(HTN)三种 AI 决策模型的完整实现指南，
  包含从简单巡逻到复杂 BOSS 战斗的渐进式示例。

  Use when:
  (1) 用户需要为 NPC/敌人/怪物实现 AI 行为（巡逻、追击、攻击、逃跑）,
  (2) 用户需要行为树(Behavior Tree)系统来组织复杂 AI 决策逻辑,
  (3) 用户需要游戏逻辑状态机(不同于动画状态机)来管理 AI 状态切换,
  (4) 用户需要 BOSS 战斗 AI 或多阶段敌人行为,
  (5) 用户需要 HTN(分层任务网络)实现目标驱动型 AI,
  (6) 用户提到 behaviac、行为树、决策树、AI 系统等关键词。
context:
  - engine-docs/recipes/state-machine.md
  - engine-docs/api/physics.md
  - engine-docs/lua-scripting-guide.md
---

# Behavior Tree AI — 纯 Lua 游戏 AI 决策系统

> 灵感源自腾讯 behaviac 框架，为 UrhoX Lua 游戏引擎深度适配。
> 提供行为树(BT)、游戏逻辑状态机(FSM)、分层任务网络(HTN)三种 AI 决策模型。

---

## 1. 核心概念：逻辑层 vs 表现层

**最关键的架构理解**：UrhoX 引擎有两套独立的状态系统，绝不能混淆。

| 维度 | 游戏逻辑 AI（本 Skill） | 动画状态机（引擎内置） |
|------|------------------------|----------------------|
| **职责** | 决定 AI **做什么** | 决定角色**播放什么动画** |
| **技术** | 纯 Lua 行为树/FSM | AnimationStateMachine + .fsm 文件 |
| **数据流** | 感知 → 决策 → 行为 | 参数 → 状态切换 → 动画混合 |
| **文件** | `scripts/ai/*.lua` | `assets/FSM/*.fsm` |
| **更新** | 在 Update 事件中 tick | 引擎自动驱动 |

**协作模式**：
```
游戏逻辑 BT (本 Skill)          动画状态机 (引擎)
┌─────────────────┐            ┌──────────────────┐
│ 感知环境         │            │                  │
│   ↓              │  参数传递   │ fsm:SetFloat()   │
│ 决策(BT/FSM)    │ ────────→  │ fsm:SetBool()    │
│   ↓              │            │ fsm:SetTrigger() │
│ 执行行为         │            │   ↓              │
│ (移动/攻击/...)  │            │ 播放对应动画      │
└─────────────────┘            └──────────────────┘
```

**示例**：AI 决定"追击玩家" → 设置移动速度 → 动画状态机自动切换到跑步动画。

---

## 2. 行为树(BT)核心节点

### 2.1 节点返回值

```lua
-- 三种状态，所有节点必须返回其中之一
local BT_SUCCESS = "success"   -- 成功完成
local BT_FAILURE = "failure"   -- 执行失败
local BT_RUNNING = "running"   -- 仍在执行中（下一帧继续）
```

### 2.2 节点类型总览

| 类别 | 节点 | 说明 |
|------|------|------|
| **组合节点** | Sequence | 依次执行子节点，遇到失败则停止 |
| | Selector | 依次尝试子节点，遇到成功则停止 |
| | Parallel | 同时执行所有子节点 |
| **装饰节点** | Inverter | 反转子节点结果 |
| | Repeater | 重复执行子节点 N 次 |
| | Succeeder | 总是返回成功 |
| | UntilFail | 重复执行直到失败 |
| | Cooldown | 冷却时间限制 |
| **叶节点** | Action | 执行具体行为 |
| | Condition | 检查条件是否满足 |
| | Wait | 等待指定时间 |

### 2.3 纯 Lua 实现

```lua
-- ============================================================
-- 文件: scripts/ai/BehaviorTree.lua
-- 行为树核心框架 — 纯 Lua 实现
-- ============================================================

local BT = {}
BT.SUCCESS = "success"
BT.FAILURE = "failure"
BT.RUNNING = "running"

-- ── 叶节点：条件检查 ──
function BT.Condition(checkFn)
    return {
        type = "Condition",
        tick = function(self, entity, dt)
            return checkFn(entity) and BT.SUCCESS or BT.FAILURE
        end
    }
end

-- ── 叶节点：行为执行 ──
function BT.Action(actionFn)
    return {
        type = "Action",
        tick = function(self, entity, dt)
            return actionFn(entity, dt)
        end
    }
end

-- ── 叶节点：等待 ──
function BT.Wait(duration)
    return {
        type = "Wait",
        elapsed = 0,
        tick = function(self, entity, dt)
            self.elapsed = self.elapsed + dt
            if self.elapsed >= duration then
                self.elapsed = 0
                return BT.SUCCESS
            end
            return BT.RUNNING
        end
    }
end

-- ── 组合节点：顺序执行 ──
function BT.Sequence(children)
    return {
        type = "Sequence",
        children = children,
        currentIndex = 1,
        tick = function(self, entity, dt)
            while self.currentIndex <= #self.children do
                local child = self.children[self.currentIndex]
                local status = child:tick(entity, dt)
                if status == BT.RUNNING then
                    return BT.RUNNING
                elseif status == BT.FAILURE then
                    self.currentIndex = 1
                    return BT.FAILURE
                end
                self.currentIndex = self.currentIndex + 1
            end
            self.currentIndex = 1
            return BT.SUCCESS
        end
    }
end

-- ── 组合节点：选择执行 ──
function BT.Selector(children)
    return {
        type = "Selector",
        children = children,
        currentIndex = 1,
        tick = function(self, entity, dt)
            while self.currentIndex <= #self.children do
                local child = self.children[self.currentIndex]
                local status = child:tick(entity, dt)
                if status == BT.RUNNING then
                    return BT.RUNNING
                elseif status == BT.SUCCESS then
                    self.currentIndex = 1
                    return BT.SUCCESS
                end
                self.currentIndex = self.currentIndex + 1
            end
            self.currentIndex = 1
            return BT.FAILURE
        end
    }
end

-- ── 组合节点：并行执行 ──
function BT.Parallel(children, opts)
    opts = opts or {}
    local successThreshold = opts.successThreshold or #children
    return {
        type = "Parallel",
        children = children,
        tick = function(self, entity, dt)
            local successCount = 0
            local anyRunning = false
            for i = 1, #self.children do
                local status = self.children[i]:tick(entity, dt)
                if status == BT.SUCCESS then
                    successCount = successCount + 1
                elseif status == BT.RUNNING then
                    anyRunning = true
                end
            end
            if successCount >= successThreshold then
                return BT.SUCCESS
            elseif anyRunning then
                return BT.RUNNING
            end
            return BT.FAILURE
        end
    }
end

-- ── 装饰节点：反转 ──
function BT.Inverter(child)
    return {
        type = "Inverter",
        tick = function(self, entity, dt)
            local status = child:tick(entity, dt)
            if status == BT.SUCCESS then return BT.FAILURE end
            if status == BT.FAILURE then return BT.SUCCESS end
            return BT.RUNNING
        end
    }
end

-- ── 装饰节点：重复 ──
function BT.Repeater(child, times)
    return {
        type = "Repeater",
        count = 0,
        tick = function(self, entity, dt)
            local status = child:tick(entity, dt)
            if status == BT.SUCCESS then
                self.count = self.count + 1
                if self.count >= times then
                    self.count = 0
                    return BT.SUCCESS
                end
                return BT.RUNNING
            elseif status == BT.FAILURE then
                self.count = 0
                return BT.FAILURE
            end
            return BT.RUNNING
        end
    }
end

-- ── 装饰节点：冷却 ──
function BT.Cooldown(child, cooldownTime)
    return {
        type = "Cooldown",
        lastRun = -999,
        globalTime = 0,
        tick = function(self, entity, dt)
            self.globalTime = self.globalTime + dt
            if self.globalTime - self.lastRun < cooldownTime then
                return BT.FAILURE
            end
            local status = child:tick(entity, dt)
            if status ~= BT.RUNNING then
                self.lastRun = self.globalTime
            end
            return status
        end
    }
end

-- ── 装饰节点：总是成功 ──
function BT.Succeeder(child)
    return {
        type = "Succeeder",
        tick = function(self, entity, dt)
            child:tick(entity, dt)
            return BT.SUCCESS
        end
    }
end

return BT
```

---

## 3. 黑板系统(Blackboard)

黑板是 AI 实体间的共享数据存储，用于感知、通信和记忆。

```lua
-- ============================================================
-- 文件: scripts/ai/Blackboard.lua
-- 黑板数据共享系统
-- ============================================================

local Blackboard = {}
Blackboard.__index = Blackboard

function Blackboard.new()
    return setmetatable({
        data = {},
        listeners = {},
    }, Blackboard)
end

function Blackboard:set(key, value)
    local old = self.data[key]
    self.data[key] = value
    -- 通知监听者
    if old ~= value and self.listeners[key] then
        for _, fn in ipairs(self.listeners[key]) do
            fn(key, value, old)
        end
    end
end

function Blackboard:get(key, default)
    local v = self.data[key]
    if v == nil then return default end
    return v
end

function Blackboard:has(key)
    return self.data[key] ~= nil
end

function Blackboard:remove(key)
    self.data[key] = nil
end

function Blackboard:onChange(key, fn)
    if not self.listeners[key] then
        self.listeners[key] = {}
    end
    table.insert(self.listeners[key], fn)
end

return Blackboard
```

---

## 4. 游戏逻辑 FSM（不同于动画状态机）

**注意**：这是**游戏逻辑**状态机，用于管理 AI 行为状态（巡逻/战斗/逃跑），
与引擎的 AnimationStateMachine（管理动画播放）完全不同。

```lua
-- ============================================================
-- 文件: scripts/ai/GameFSM.lua
-- 游戏逻辑状态机 — 管理 AI 行为状态
-- ============================================================

local GameFSM = {}
GameFSM.__index = GameFSM

function GameFSM.new()
    return setmetatable({
        states = {},
        transitions = {},
        currentState = nil,
        currentStateName = nil,
    }, GameFSM)
end

--- 添加状态
--- @param name string 状态名称
--- @param callbacks table { onEnter, onUpdate, onExit }
function GameFSM:addState(name, callbacks)
    self.states[name] = {
        onEnter  = callbacks.onEnter or function() end,
        onUpdate = callbacks.onUpdate or function() end,
        onExit   = callbacks.onExit or function() end,
    }
end

--- 添加转换条件
--- @param from string 起始状态
--- @param to string 目标状态
--- @param condition function 条件函数，返回 true 则触发转换
function GameFSM:addTransition(from, to, condition)
    if not self.transitions[from] then
        self.transitions[from] = {}
    end
    table.insert(self.transitions[from], {
        target = to,
        condition = condition,
    })
end

--- 设置初始状态
function GameFSM:start(stateName)
    self.currentStateName = stateName
    self.currentState = self.states[stateName]
    if self.currentState then
        self.currentState.onEnter()
    end
end

--- 每帧更新
function GameFSM:update(entity, dt)
    if not self.currentStateName then return end

    -- 检查转换条件
    local transitions = self.transitions[self.currentStateName]
    if transitions then
        for _, t in ipairs(transitions) do
            if t.condition(entity, dt) then
                -- 执行状态转换
                if self.currentState then
                    self.currentState.onExit()
                end
                self.currentStateName = t.target
                self.currentState = self.states[t.target]
                if self.currentState then
                    self.currentState.onEnter()
                end
                return
            end
        end
    end

    -- 更新当前状态
    if self.currentState then
        self.currentState.onUpdate(entity, dt)
    end
end

--- 获取当前状态名
function GameFSM:getCurrentState()
    return self.currentStateName
end

--- 强制切换状态
function GameFSM:forceState(stateName)
    if self.currentState then
        self.currentState.onExit()
    end
    self.currentStateName = stateName
    self.currentState = self.states[stateName]
    if self.currentState then
        self.currentState.onEnter()
    end
end

return GameFSM
```

---

## 5. AI 管理器

统一管理所有 AI 实体，每帧驱动行为树 tick。

```lua
-- ============================================================
-- 文件: scripts/ai/AIManager.lua
-- AI 实体统一管理器
-- ============================================================

local AIManager = {}
AIManager.__index = AIManager

function AIManager.new()
    return setmetatable({
        entities = {},      -- { [id] = { node, tree, blackboard, ... } }
        nextId = 1,
        tickInterval = 0.1, -- AI 更新间隔（秒），降低 CPU 开销
        tickTimer = 0,
    }, AIManager)
end

--- 注册一个 AI 实体
--- @param node userdata  场景节点
--- @param tree table     行为树根节点
--- @param blackboard table 黑板实例
--- @return number id
function AIManager:register(node, tree, blackboard)
    local id = self.nextId
    self.nextId = self.nextId + 1
    self.entities[id] = {
        id = id,
        node = node,
        tree = tree,
        blackboard = blackboard,
        active = true,
    }
    return id
end

--- 移除 AI 实体
function AIManager:remove(id)
    self.entities[id] = nil
end

--- 启用/禁用
function AIManager:setActive(id, active)
    if self.entities[id] then
        self.entities[id].active = active
    end
end

--- 每帧调用（在 HandleUpdate 中）
function AIManager:update(dt)
    self.tickTimer = self.tickTimer + dt
    if self.tickTimer < self.tickInterval then
        return
    end
    local tickDt = self.tickTimer
    self.tickTimer = 0

    for _, entity in pairs(self.entities) do
        if entity.active and entity.node and not entity.node:IsNull() then
            entity.tree:tick(entity, tickDt)
        else
            -- 节点已销毁，清理
            if entity.node and entity.node:IsNull() then
                self.entities[entity.id] = nil
            end
        end
    end
end

--- 设置全局 tick 间隔
function AIManager:setTickInterval(interval)
    self.tickInterval = math.max(0.016, interval) -- 至少 60fps
end

return AIManager
```

---

## 6. 完整示例：敌人巡逻-追击-攻击

### 6.1 项目结构

```
scripts/
├── main.lua                  # 入口文件
├── ai/
│   ├── BehaviorTree.lua      # BT 核心框架
│   ├── Blackboard.lua        # 黑板系统
│   ├── GameFSM.lua           # 游戏逻辑 FSM
│   └── AIManager.lua         # AI 管理器
└── config/
    └── bt_registry.lua       # AI 行为配置注册表
```

### 6.2 敌人行为树定义

```lua
-- ============================================================
-- 文件: scripts/config/bt_registry.lua
-- AI 行为配置注册表 — 数据驱动的行为树定义
-- ============================================================

local BT = require "ai.BehaviorTree"

local Registry = {}

--- 感知函数库
local Perception = {}

function Perception.canSeePlayer(entity)
    local bb = entity.blackboard
    local playerNode = bb:get("playerNode")
    if not playerNode or playerNode:IsNull() then return false end

    local myPos = entity.node:GetWorldPosition()
    local playerPos = playerNode:GetWorldPosition()
    local dist = (playerPos - myPos):Length()

    bb:set("distToPlayer", dist)
    bb:set("playerPos", playerPos)

    local detectRange = bb:get("detectRange", 10.0)
    return dist <= detectRange
end

function Perception.isPlayerInAttackRange(entity)
    local dist = entity.blackboard:get("distToPlayer", 999)
    local atkRange = entity.blackboard:get("attackRange", 2.0)
    return dist <= atkRange
end

function Perception.isHealthLow(entity)
    local hp = entity.blackboard:get("hp", 100)
    local maxHp = entity.blackboard:get("maxHp", 100)
    return hp / maxHp < 0.2
end

--- 行为函数库
local Actions = {}

function Actions.patrol(entity, dt)
    local bb = entity.blackboard
    local node = entity.node
    local waypoints = bb:get("waypoints", {})

    if #waypoints == 0 then return BT.FAILURE end

    local wpIndex = bb:get("waypointIndex", 1)
    local target = waypoints[wpIndex]
    local myPos = node:GetWorldPosition()
    local dir = target - myPos
    local dist = dir:Length()

    if dist < 0.5 then
        -- 到达巡逻点，切换到下一个
        wpIndex = wpIndex % #waypoints + 1
        bb:set("waypointIndex", wpIndex)
        return BT.SUCCESS
    end

    -- 移动
    local speed = bb:get("patrolSpeed", 2.0)
    dir:Normalize()
    node:SetWorldPosition(myPos + dir * speed * dt)

    -- 朝向移动方向
    local angle = math.deg(math.atan(dir.x, dir.z))
    node:SetWorldRotation(Quaternion(angle, Vector3.UP))

    -- 同步动画参数（如果有动画状态机）
    local fsm = node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetFloat("moveSpeed", speed)
        fsm:SetBool("isMoving", true)
    end

    return BT.RUNNING
end

function Actions.chasePlayer(entity, dt)
    local bb = entity.blackboard
    local node = entity.node
    local playerPos = bb:get("playerPos")

    if not playerPos then return BT.FAILURE end

    local myPos = node:GetWorldPosition()
    local dir = playerPos - myPos
    local dist = dir:Length()

    local speed = bb:get("chaseSpeed", 5.0)
    dir:Normalize()
    node:SetWorldPosition(myPos + dir * speed * dt)

    -- 朝向玩家
    local angle = math.deg(math.atan(dir.x, dir.z))
    node:SetWorldRotation(Quaternion(angle, Vector3.UP))

    -- 同步动画
    local fsm = node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetFloat("moveSpeed", speed)
        fsm:SetBool("isMoving", true)
    end

    return BT.RUNNING
end

function Actions.attack(entity, dt)
    local bb = entity.blackboard
    local atkCooldown = bb:get("attackCooldown", 1.0)
    local lastAtk = bb:get("lastAttackTime", -999)
    local now = bb:get("gameTime", 0)

    if now - lastAtk < atkCooldown then
        return BT.RUNNING
    end

    -- 执行攻击
    bb:set("lastAttackTime", now)
    local damage = bb:get("attackDamage", 10)
    log:Write(LOG_INFO, "Enemy attacks\! Damage: " .. damage)

    -- 触发攻击动画
    local fsm = entity.node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetTrigger("attack")
    end

    return BT.SUCCESS
end

function Actions.flee(entity, dt)
    local bb = entity.blackboard
    local node = entity.node
    local playerPos = bb:get("playerPos")

    if not playerPos then return BT.FAILURE end

    local myPos = node:GetWorldPosition()
    local dir = myPos - playerPos  -- 反方向
    dir:Normalize()

    local speed = bb:get("fleeSpeed", 6.0)
    node:SetWorldPosition(myPos + dir * speed * dt)

    local fsm = node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetFloat("moveSpeed", speed)
    end

    return BT.RUNNING
end

function Actions.idle(entity, dt)
    local fsm = entity.node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetFloat("moveSpeed", 0)
        fsm:SetBool("isMoving", false)
    end
    return BT.SUCCESS
end

--- 构建标准敌人行为树
--- 优先级：低血量逃跑 > 攻击范围内攻击 > 发现玩家追击 > 巡逻
function Registry.createEnemyBT()
    return BT.Selector({
        -- 1. 低血量逃跑
        BT.Sequence({
            BT.Condition(Perception.isHealthLow),
            BT.Action(Actions.flee),
        }),

        -- 2. 攻击范围内 → 攻击
        BT.Sequence({
            BT.Condition(Perception.canSeePlayer),
            BT.Condition(Perception.isPlayerInAttackRange),
            BT.Cooldown(BT.Action(Actions.attack), 1.0),
        }),

        -- 3. 发现玩家 → 追击
        BT.Sequence({
            BT.Condition(Perception.canSeePlayer),
            BT.Action(Actions.chasePlayer),
        }),

        -- 4. 默认巡逻
        BT.Action(Actions.patrol),
    })
end

--- 构建 BOSS 行为树（多阶段）
function Registry.createBossBT()
    return BT.Selector({
        -- 阶段 1: 血量 > 50% — 普通攻击 + 技能
        BT.Sequence({
            BT.Condition(function(e)
                local hp = e.blackboard:get("hp", 100)
                local maxHp = e.blackboard:get("maxHp", 100)
                return hp / maxHp > 0.5
            end),
            BT.Selector({
                BT.Sequence({
                    BT.Condition(Perception.isPlayerInAttackRange),
                    BT.Action(Actions.attack),
                }),
                BT.Sequence({
                    BT.Condition(Perception.canSeePlayer),
                    BT.Action(Actions.chasePlayer),
                }),
            }),
        }),

        -- 阶段 2: 血量 <= 50% — 狂暴模式
        BT.Sequence({
            BT.Condition(function(e)
                local hp = e.blackboard:get("hp", 100)
                local maxHp = e.blackboard:get("maxHp", 100)
                return hp / maxHp <= 0.5
            end),
            -- 进入狂暴模式：提高攻速和伤害
            BT.Action(function(e, dt)
                e.blackboard:set("attackCooldown", 0.5) -- 攻速翻倍
                e.blackboard:set("attackDamage", 20)    -- 伤害翻倍
                e.blackboard:set("chaseSpeed", 8.0)     -- 移速提升
                return BT.SUCCESS
            end),
            BT.Selector({
                BT.Sequence({
                    BT.Condition(Perception.isPlayerInAttackRange),
                    BT.Action(Actions.attack),
                }),
                BT.Action(Actions.chasePlayer),
            }),
        }),
    })
end

--- 导出感知和行为函数，方便自定义组合
Registry.Perception = Perception
Registry.Actions = Actions

return Registry
```

### 6.3 主入口集成

```lua
-- ============================================================
-- 文件: scripts/main.lua
-- 集成行为树 AI 的游戏主入口
-- ============================================================

require "LuaScripts/Utilities/Sample"

local BT = require "ai.BehaviorTree"
local Blackboard = require "ai.Blackboard"
local AIManager = require "ai.AIManager"
local Registry = require "config.bt_registry"

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Node
local playerNode_ = nil
local aiManager = AIManager.new()

function Start()
    SampleStart()
    CreateScene()
    CreatePlayer()
    SpawnEnemies(3)
    SetupCamera()
    SubscribeToEvents()
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    -- 灯光
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.brightness = 1.0

    -- 地面
    local floorNode = scene_:CreateChild("Floor")
    floorNode:SetScale(Vector3(50, 1, 50))
    floorNode.position = Vector3(0, -0.5, 0)
    local model = floorNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local body = floorNode:CreateComponent("RigidBody")
    local shape = floorNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

function CreatePlayer()
    playerNode_ = scene_:CreateChild("Player")
    playerNode_.position = Vector3(0, 0.5, 0)
    local model = playerNode_:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
end

function SpawnEnemies(count)
    for i = 1, count do
        local enemyNode = scene_:CreateChild("Enemy_" .. i)
        enemyNode.position = Vector3(
            math.random(-15, 15),
            0.5,
            math.random(-15, 15)
        )
        local model = enemyNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

        -- 创建黑板并设置初始数据
        local bb = Blackboard.new()
        bb:set("playerNode", playerNode_)
        bb:set("hp", 100)
        bb:set("maxHp", 100)
        bb:set("detectRange", 12.0)
        bb:set("attackRange", 2.0)
        bb:set("attackDamage", 10)
        bb:set("attackCooldown", 1.0)
        bb:set("patrolSpeed", 2.0)
        bb:set("chaseSpeed", 5.0)
        bb:set("fleeSpeed", 6.0)
        bb:set("gameTime", 0)

        -- 设置巡逻点
        bb:set("waypoints", {
            Vector3(math.random(-10, 10), 0.5, math.random(-10, 10)),
            Vector3(math.random(-10, 10), 0.5, math.random(-10, 10)),
            Vector3(math.random(-10, 10), 0.5, math.random(-10, 10)),
        })
        bb:set("waypointIndex", 1)

        -- 创建行为树并注册
        local tree = Registry.createEnemyBT()
        aiManager:register(enemyNode, tree, bb)
    end
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 20, -20)
    cameraNode_:LookAt(Vector3(0, 0, 0))
    local camera = cameraNode_:CreateComponent("Camera")
    renderer:SetViewport(0, Viewport:new(scene_, camera))
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 更新游戏时间（传递给黑板）
    for _, entity in pairs(aiManager.entities) do
        if entity.blackboard then
            local t = entity.blackboard:get("gameTime", 0)
            entity.blackboard:set("gameTime", t + dt)
        end
    end

    -- 简单玩家移动（键盘控制）
    local speed = 8.0
    local move = Vector3.ZERO
    if input:GetKeyDown(KEY_W) then move = move + Vector3.FORWARD end
    if input:GetKeyDown(KEY_S) then move = move + Vector3.BACK end
    if input:GetKeyDown(KEY_A) then move = move + Vector3.LEFT end
    if input:GetKeyDown(KEY_D) then move = move + Vector3.RIGHT end
    if move:Length() > 0 then
        move:Normalize()
        playerNode_:Translate(move * speed * dt, TS_WORLD)
    end

    -- 驱动所有 AI 行为树
    aiManager:update(dt)
end
```

---

## 7. HTN (分层任务网络) — 目标驱动型 AI

HTN 适合需要「规划多步骤行为」的复杂 AI，如 RTS 单位或策略 NPC。

```lua
-- ============================================================
-- 文件: scripts/ai/HTN.lua
-- 分层任务网络 — 目标驱动型 AI 决策
-- ============================================================

local HTN = {}

--- 创建一个 HTN 规划器
function HTN.Planner()
    return {
        methods = {},   -- 复合任务分解方法
        operators = {}, -- 原子操作

        --- 注册复合任务的分解方法
        addMethod = function(self, taskName, condition, subtasks)
            if not self.methods[taskName] then
                self.methods[taskName] = {}
            end
            table.insert(self.methods[taskName], {
                condition = condition,
                subtasks = subtasks,
            })
        end,

        --- 注册原子操作
        addOperator = function(self, name, precondition, execute, effects)
            self.operators[name] = {
                precondition = precondition or function() return true end,
                execute = execute,
                effects = effects or function() end,
            }
        end,

        --- 规划任务序列
        plan = function(self, rootTask, worldState)
            local taskQueue = { rootTask }
            local result = {}
            local state = {}
            -- 复制世界状态
            for k, v in pairs(worldState) do state[k] = v end

            while #taskQueue > 0 do
                local task = table.remove(taskQueue, 1)

                if self.operators[task] then
                    -- 原子任务
                    local op = self.operators[task]
                    if op.precondition(state) then
                        table.insert(result, task)
                        op.effects(state)
                    else
                        return nil -- 规划失败
                    end
                elseif self.methods[task] then
                    -- 复合任务 — 尝试分解
                    local decomposed = false
                    for _, method in ipairs(self.methods[task]) do
                        if method.condition(state) then
                            -- 将子任务插入队列头部
                            for i = #method.subtasks, 1, -1 do
                                table.insert(taskQueue, 1, method.subtasks[i])
                            end
                            decomposed = true
                            break
                        end
                    end
                    if not decomposed then
                        return nil -- 无可用分解方法
                    end
                else
                    return nil -- 未知任务
                end
            end

            return result
        end,

        --- 执行规划好的任务序列
        executePlan = function(self, planList, entity, dt)
            if not planList or #planList == 0 then
                return "empty"
            end

            local task = planList[1]
            local op = self.operators[task]
            if not op then return "error" end

            local status = op.execute(entity, dt)
            if status == "success" then
                table.remove(planList, 1)
                if #planList == 0 then
                    return "complete"
                end
                return "running"
            end
            return status
        end,
    }
end

return HTN
```

---

## 8. 与引擎 AnimationStateMachine 的集成

行为树决定 AI 做什么，AnimationStateMachine 负责播放动画。
二者通过**参数传递**实现解耦。

### 8.1 集成模式

```lua
-- 在行为树的 Action 节点中，设置动画参数
function Actions.chasePlayer(entity, dt)
    local node = entity.node
    local speed = entity.blackboard:get("chaseSpeed", 5.0)

    -- ... 移动逻辑 ...

    -- 通过参数传递，让 AnimationStateMachine 自动切换到跑步动画
    local fsm = node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetFloat("moveSpeed", speed)   -- 动画状态机根据 moveSpeed 选择走/跑
        fsm:SetBool("isMoving", true)       -- 标记正在移动
    end

    return BT.RUNNING
end

function Actions.attack(entity, dt)
    -- ... 攻击逻辑 ...

    -- 触发攻击动画（一次性触发）
    local fsm = entity.node:GetComponent("AnimationStateMachine")
    if fsm then
        fsm:SetTrigger("attack")  -- 触发器自动重置
    end

    return BT.SUCCESS
end
```

### 8.2 .fsm 文件与行为树参数映射

```
行为树 Action              → 设置的动画参数        → .fsm 文件中的 condition
─────────────────────────────────────────────────────────────────────
巡逻 (patrol)              → moveSpeed=2.0        → "moveSpeed > 0.5"  → Walk
追击 (chase)               → moveSpeed=5.0        → "moveSpeed > 3.0"  → Run
待机 (idle)                → moveSpeed=0           → "moveSpeed < 0.1"  → Idle
攻击 (attack)              → SetTrigger("attack") → "attack"           → Attack
受伤 (hurt)                → SetTrigger("hit")    → "hit"              → Hit
死亡 (die)                 → SetBool("isDead",t)  → "isDead"           → Death
```

---

## 9. 实用模式与技巧

### 9.1 感知缓存（避免每帧射线检测）

```lua
-- 不要每帧都做射线检测，用计时器缓存结果
local perceptionTimer = 0
local PERCEPTION_INTERVAL = 0.2 -- 每 0.2 秒更新一次感知

function updatePerception(entity, dt)
    perceptionTimer = perceptionTimer + dt
    if perceptionTimer < PERCEPTION_INTERVAL then return end
    perceptionTimer = 0

    -- 在这里执行射线检测、距离计算等
    local playerPos = playerNode_:GetWorldPosition()
    local myPos = entity.node:GetWorldPosition()
    entity.blackboard:set("distToPlayer", (playerPos - myPos):Length())
    entity.blackboard:set("playerPos", playerPos)
end
```

### 9.2 行为树可视化调试

```lua
-- 在开发阶段，输出行为树当前执行路径
function debugBT(node, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    local status = node.lastStatus or "?"
    log:Write(LOG_DEBUG, prefix .. node.type .. " [" .. status .. "]")
    if node.children then
        for _, child in ipairs(node.children) do
            debugBT(child, indent + 1)
        end
    end
end
```

### 9.3 行为树热重载（开发模式）

```lua
-- 重新加载行为树定义（按 F5 重载）
if input:GetKeyPress(KEY_F5) then
    -- 清除 require 缓存
    package.loaded["config.bt_registry"] = nil
    local NewRegistry = require "config.bt_registry"

    -- 重新为所有 AI 构建行为树
    for _, entity in pairs(aiManager.entities) do
        entity.tree = NewRegistry.createEnemyBT()
    end
    log:Write(LOG_INFO, "BT hot-reloaded\!")
end
```

---

## 10. 项目构建与文件组织

### 10.1 推荐目录结构

```
scripts/
├── main.lua                  # 入口（构建时用此文件）
├── ai/
│   ├── BehaviorTree.lua      # BT 核心
│   ├── Blackboard.lua        # 黑板
│   ├── GameFSM.lua           # 游戏逻辑 FSM
│   ├── HTN.lua               # 分层任务网络
│   └── AIManager.lua         # AI 管理器
└── config/
    └── bt_registry.lua       # 行为配置注册表（状态文件）
```

### 10.2 构建指引

使用 UrhoX MCP 构建工具进行构建：
- 入口文件设置为 `main.lua`
- 所有 AI 模块通过 `require` 引用，构建工具会自动打包

### 10.3 性能建议

| 建议 | 说明 |
|------|------|
| **降低 AI tick 频率** | `AIManager.tickInterval = 0.1`（10Hz 足够） |
| **感知缓存** | 不要每帧射线检测，用计时器间隔更新 |
| **分组更新** | 大量 AI 时分组轮流 tick |
| **距离裁剪** | 远离摄像机的 AI 降低更新频率或暂停 |
| **简化碰撞** | AI 感知用距离检测，不用物理射线 |

---

## 11. 三种 AI 模型选择指南

| 特征 | 行为树 (BT) | 游戏逻辑 FSM | HTN |
|------|------------|-------------|-----|
| **适用场景** | 通用 NPC/敌人 AI | 简单状态切换 | 策略/规划型 AI |
| **复杂度** | 中等 | 低 | 高 |
| **可扩展性** | 高（组合节点） | 中等 | 高（任务分解） |
| **调试难度** | 中等 | 低 | 高 |
| **典型用例** | 巡逻追击、BOSS 战 | 门的开关、NPC 日程 | RTS 单位、策略 NPC |
| **推荐** | 大多数游戏 AI | 简单场景 | 需要多步规划时 |

**选择建议**：
- 不确定用哪个 → **行为树 (BT)**，最通用
- 只有 2-3 个状态 → **游戏逻辑 FSM**，最简单
- 需要"先做 A 再做 B 最后做 C"的规划 → **HTN**

---

## 12. DON'T — 常见错误

| 错误 | 正确做法 |
|------|---------|
| 把游戏逻辑 AI 写在 .fsm 文件里 | .fsm 只管动画，游戏逻辑用纯 Lua |
| 在行为树 Action 中直接播放动画 | 通过 fsm 参数间接驱动动画 |
| 每帧都做射线检测/距离计算 | 用计时器缓存感知结果 |
| 硬编码 AI 参数 | 放到 Blackboard 或配置文件中 |
| 所有 AI 同时 tick | 用 AIManager 统一控制 tick 频率 |
| 使用已禁用的分辨率设置 API | 用 `graphics:GetWidth()` / `graphics:GetHeight()` |
| 使用已移除的文件操作库 | 用引擎提供的 File API |
| 写入发布产物目录 | 代码只放 `scripts/` 目录 |
| 使用旧引擎名称 | 统一使用 UrhoX |
