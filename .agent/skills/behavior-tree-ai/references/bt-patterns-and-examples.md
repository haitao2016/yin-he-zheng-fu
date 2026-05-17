# 行为树模式库与 UrhoX 集成示例

> 常见 AI 行为模式的行为树实现，可直接复用或组合。

---

## 1. 常见行为模式速查

### 1.1 巡逻-追击-返回模式

最常见的敌人 AI 模式，适用于大部分动作游戏。

```
Selector
├── Sequence [追击]
│   ├── Condition: 发现玩家
│   ├── Condition: 未超出追击范围
│   └── Action: 追向玩家
├── Sequence [返回]
│   ├── Condition: 距离巡逻路线太远
│   └── Action: 返回巡逻路线
└── Action: 巡逻 [默认]
```

**特点**：超出追击范围自动放弃，防止玩家无限风筝。

### 1.2 远程攻击模式

```
Selector
├── Sequence [太近→后退]
│   ├── Condition: 玩家距离 < 安全距离
│   └── Action: 后退拉开距离
├── Sequence [射程内→攻击]
│   ├── Condition: 玩家在射程内
│   ├── Condition: 攻击冷却完毕
│   └── Action: 远程攻击
├── Sequence [追击到射程]
│   ├── Condition: 发现玩家
│   └── Action: 移动到射程内
└── Action: 巡逻
```

### 1.3 BOSS 多阶段模式

```
Selector
├── Sequence [阶段3: 血量 < 20%]
│   ├── Condition: HP < 20%
│   ├── Action: 全屏技能（绝望一击）
│   └── Cooldown(10s): Action: 召唤小怪
├── Sequence [阶段2: 血量 < 50%]
│   ├── Condition: HP < 50%
│   ├── Action: 狂暴化（提升属性）
│   └── Selector: 攻击/技能循环
├── Sequence [阶段1: 正常]
│   └── Selector: 普通攻击/移动
└── Action: 待机
```

### 1.4 守卫模式

```
Selector
├── Sequence [警戒→攻击]
│   ├── Condition: 有入侵者在警戒范围
│   ├── Action: 面向入侵者
│   └── Selector
│       ├── Sequence [近战]
│       │   ├── Condition: 距离 < 攻击范围
│       │   └── Action: 攻击
│       └── Action: 靠近
├── Sequence [可疑→调查]
│   ├── Condition: 听到声音/看到痕迹
│   └── Action: 移动到可疑位置
└── Action: 在岗位待机
```

### 1.5 群体协作模式

```
Parallel(all)
├── Action: 共享玩家位置到群组黑板
├── Selector [角色分工]
│   ├── Sequence [坦克：正面冲锋]
│   │   ├── Condition: 我是坦克角色
│   │   └── Action: 冲向玩家
│   ├── Sequence [射手：保持距离]
│   │   ├── Condition: 我是射手角色
│   │   └── Action: 保持射程距离射击
│   └── Sequence [治疗：支援队友]
│       ├── Condition: 我是治疗角色
│       └── Action: 治疗血量最低的队友
```

---

## 2. 感知系统模式

### 2.1 视锥检测

```lua
--- 检查目标是否在 AI 的视锥内
--- @param myNode userdata AI 节点
--- @param targetPos Vector3 目标位置
--- @param viewAngle number 视角半角（度）
--- @param viewDist number 视距
--- @return boolean
function isInViewCone(myNode, targetPos, viewAngle, viewDist)
    local myPos = myNode:GetWorldPosition()
    local toTarget = targetPos - myPos
    local dist = toTarget:Length()

    if dist > viewDist then return false end
    if dist < 0.01 then return true end

    toTarget:Normalize()
    local forward = myNode:GetWorldDirection()
    local dot = forward:DotProduct(toTarget)
    local angle = math.deg(math.acos(math.max(-1, math.min(1, dot))))

    return angle <= viewAngle
end
```

### 2.2 听觉感知

```lua
--- 声音事件系统
local SoundEvents = {
    events = {},  -- { pos, radius, type, time }

    emit = function(self, pos, radius, soundType)
        table.insert(self.events, {
            pos = pos,
            radius = radius,
            type = soundType,
            time = 0,
        })
    end,

    canHear = function(self, listenerPos, hearingRange)
        for _, event in ipairs(self.events) do
            local dist = (event.pos - listenerPos):Length()
            if dist <= math.min(event.radius, hearingRange) then
                return true, event
            end
        end
        return false, nil
    end,

    update = function(self, dt)
        -- 清理过期的声音事件
        local i = 1
        while i <= #self.events do
            self.events[i].time = self.events[i].time + dt
            if self.events[i].time > 1.0 then  -- 1 秒后过期
                table.remove(self.events, i)
            else
                i = i + 1
            end
        end
    end,
}
```

---

## 3. 游戏逻辑 FSM 模式

### 3.1 NPC 日程系统

```lua
local GameFSM = require "ai.GameFSM"

local function createNPCSchedule(npcNode, bb)
    local fsm = GameFSM.new()

    fsm:addState("sleep", {
        onEnter = function()
            log:Write(LOG_INFO, "NPC goes to sleep")
        end,
        onUpdate = function(entity, dt)
            -- 播放睡觉动画
        end,
    })

    fsm:addState("work", {
        onEnter = function()
            log:Write(LOG_INFO, "NPC goes to work")
        end,
        onUpdate = function(entity, dt)
            -- 移动到工作地点，执行工作
        end,
    })

    fsm:addState("eat", {
        onEnter = function()
            log:Write(LOG_INFO, "NPC goes to eat")
        end,
    })

    fsm:addState("wander", {
        onUpdate = function(entity, dt)
            -- 随机漫步
        end,
    })

    -- 时间驱动的状态转换
    fsm:addTransition("sleep", "work", function(e)
        return bb:get("hour", 0) >= 8
    end)
    fsm:addTransition("work", "eat", function(e)
        return bb:get("hour", 0) >= 12
    end)
    fsm:addTransition("eat", "work", function(e)
        return bb:get("hour", 0) >= 13
    end)
    fsm:addTransition("work", "wander", function(e)
        return bb:get("hour", 0) >= 18
    end)
    fsm:addTransition("wander", "sleep", function(e)
        return bb:get("hour", 0) >= 22
    end)

    fsm:start("sleep")
    return fsm
end
```

### 3.2 门/机关状态机

```lua
local function createDoorFSM(doorNode)
    local fsm = GameFSM.new()

    fsm:addState("closed", {
        onEnter = function()
            -- 关门动画/音效
        end,
    })
    fsm:addState("opening", {
        onEnter = function()
            -- 播放开门动画
        end,
        onUpdate = function(entity, dt)
            -- 插值开门
        end,
    })
    fsm:addState("open", {})
    fsm:addState("closing", {
        onUpdate = function(entity, dt)
            -- 插值关门
        end,
    })

    fsm:addTransition("closed", "opening", function(e)
        return e.blackboard:get("playerNearby", false)
    end)
    fsm:addTransition("opening", "open", function(e)
        return e.blackboard:get("animFinished", false)
    end)
    fsm:addTransition("open", "closing", function(e)
        return not e.blackboard:get("playerNearby", false)
    end)
    fsm:addTransition("closing", "closed", function(e)
        return e.blackboard:get("animFinished", false)
    end)

    fsm:start("closed")
    return fsm
end
```

---

## 4. HTN 使用示例

### 4.1 RTS 采集资源

```lua
local HTN = require "ai.HTN"

local planner = HTN.Planner()

-- 定义复合任务：采集资源
planner:addMethod("gatherResource", function(state)
    return state.hasResource == false and state.resourceNearby == true
end, { "moveToResource", "harvest", "returnToBase", "deposit" })

-- 定义原子操作
planner:addOperator("moveToResource", function(state)
    return state.resourceNearby == true
end, function(entity, dt)
    -- 移动到资源点
    return "success"
end, function(state)
    state.atResource = true
end)

planner:addOperator("harvest", function(state)
    return state.atResource == true
end, function(entity, dt)
    -- 采集
    return "success"
end, function(state)
    state.hasResource = true
    state.atResource = false
end)

-- 规划
local worldState = { hasResource = false, resourceNearby = true }
local taskPlan = planner:plan("gatherResource", worldState)
-- 结果: { "moveToResource", "harvest", "returnToBase", "deposit" }
```

---

## 5. AnimationStateMachine 参数速查

行为树 Action 中常用的动画参数传递：

| 游戏行为 | 设置的参数 | .fsm 中的 condition |
|---------|-----------|-------------------|
| 站立不动 | `SetFloat("moveSpeed", 0)` | `moveSpeed < 0.1` → Idle |
| 走路 | `SetFloat("moveSpeed", 2)` | `moveSpeed > 0.5 and moveSpeed < 3` → Walk |
| 跑步 | `SetFloat("moveSpeed", 5)` | `moveSpeed > 3` → Run |
| 攻击 | `SetTrigger("attack")` | `attack` → Attack |
| 受伤 | `SetTrigger("hit")` | `hit` → Hit |
| 死亡 | `SetBool("isDead", true)` | `isDead` → Death |
| 跳跃 | `SetTrigger("jump")` | `jump` → Jump |
| 着地 | `SetBool("isGrounded", true)` | `isGrounded` → Land |

---

## 6. 调试工具

### 6.1 行为树状态打印

```lua
--- 打印行为树当前执行状态（开发时使用）
function printBTStatus(aiManager)
    for id, entity in pairs(aiManager.entities) do
        local state = "unknown"
        if entity.tree and entity.tree.type then
            state = entity.tree.type
        end
        local hp = entity.blackboard:get("hp", 0)
        local dist = entity.blackboard:get("distToPlayer", 999)
        log:Write(LOG_DEBUG, string.format(
            "[AI #%d] State: %s | HP: %d | DistToPlayer: %.1f",
            id, state, hp, dist
        ))
    end
end
```

### 6.2 NanoVG 可视化调试

```lua
--- 在 NanoVGRender 事件中绘制 AI 调试信息
function drawAIDebug(vg, camera, aiManager)
    for _, entity in pairs(aiManager.entities) do
        local worldPos = entity.node:GetWorldPosition()
        -- 世界坐标 → 屏幕坐标（需要相机投影）
        local screenPos = camera:WorldToScreenPoint(worldPos)
        if screenPos.z > 0 then -- 在相机前方
            local x = screenPos.x * screenWidth
            local y = screenPos.y * screenHeight

            -- 显示 HP 条
            local hp = entity.blackboard:get("hp", 100)
            local maxHp = entity.blackboard:get("maxHp", 100)
            local ratio = hp / maxHp

            nvgBeginPath(vg)
            nvgRect(vg, x - 20, y - 30, 40, 4)
            nvgFillColor(vg, nvgRGBA(60, 60, 60, 180))
            nvgFill(vg)

            nvgBeginPath(vg)
            nvgRect(vg, x - 20, y - 30, 40 * ratio, 4)
            nvgFillColor(vg, nvgRGBA(
                math.floor(255 * (1 - ratio)),
                math.floor(255 * ratio),
                0, 220))
            nvgFill(vg)
        end
    end
end
```

---

## 7. 性能优化清单

| 优化项 | 方法 | 效果 |
|--------|------|------|
| AI tick 频率 | `AIManager.tickInterval = 0.1`~`0.2` | CPU 降低 5-10x |
| 感知缓存 | 每 0.2s 更新感知，中间帧用缓存 | 避免每帧物理查询 |
| 距离裁剪 | 距摄像机 > 50m 的 AI 暂停 | 减少无效计算 |
| 分组更新 | N 个 AI 分 M 组轮流 tick | 平滑 CPU 开销 |
| LOD AI | 远处 AI 简化行为树 | 降低决策复杂度 |
| 对象池 | 复用行为树节点实例 | 减少 GC 压力 |
