---
title: "Tool Catalog — 游戏工具注册食谱与内置工具大全"
parent: autonomous-agent-framework
---

# Tool Catalog — 游戏工具注册食谱

> 本文档为 `autonomous-agent-framework` 的参考手册，提供各类游戏场景下的工具（Tool）注册模板和最佳实践。

---

## §1 工具接口规范

每个工具必须实现标准接口：

```lua
---@class AgentTool
---@field name string          -- 工具唯一标识
---@field description string   -- 自然语言描述（供 AI / 规则引擎选择）
---@field tags string[]        -- 分类标签（用于 FindByTag 检索）
---@field validate fun(params: table): boolean, string?  -- 参数校验
---@field execute fun(params: table, context: table): boolean, any  -- 执行逻辑
---@field cost fun(params: table): number                -- 预估开销（0-100）
```

### 1.1 命名规范

| 规则 | 示例 |
|------|------|
| 全小写 + 下划线 | `move_to`, `scan_area`, `pickup_item` |
| 动词开头 | `attack_target`, `cast_spell`, `build_wall` |
| 避免缩写 | `move_to`（✅）而非 `mv`（❌） |

### 1.2 标签体系

推荐使用以下标准标签：

| 标签 | 含义 | 适用工具 |
|------|------|---------|
| `movement` | 移动相关 | move_to, patrol, follow, flee |
| `combat` | 战斗相关 | attack, cast_spell, defend, dodge |
| `perception` | 感知/侦察 | scan_area, detect_enemy, listen |
| `interaction` | 物品/环境交互 | pickup_item, open_door, use_lever |
| `communication` | NPC 间通信 | send_message, call_allies, warn |
| `resource` | 资源管理 | gather, craft, trade, consume |
| `navigation` | 路径/导航 | find_path, set_waypoint, avoid_obstacle |
| `utility` | 通用辅助 | wait, log, set_variable |

---

## §2 移动工具集

### 2.1 move_to — 移动到目标点

```lua
local move_to = {
    name = "move_to",
    description = "移动代理到指定世界坐标",
    tags = { "movement", "navigation" },

    validate = function(params)
        if not params.target then
            return false, "缺少 target 参数（Vector3）"
        end
        if not params.speed then
            params.speed = 3.0  -- 默认步行速度 3 m/s
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        if not node then
            return false, "代理节点不存在"
        end

        local target = params.target
        local current = node.position
        local direction = (target - current):Normalized()
        local distance = (target - current):Length()

        if distance < 0.3 then
            return true, { arrived = true, position = current }
        end

        -- 设置移动方向（由外部 HandleUpdate 驱动实际移动）
        context.moveDirection = direction
        context.moveSpeed = params.speed
        context.moveTarget = target

        return true, { arrived = false, remaining = distance }
    end,

    cost = function(params)
        return 10  -- 移动是低开销操作
    end,
}
```

### 2.2 patrol — 巡逻路径

```lua
local patrol = {
    name = "patrol",
    description = "沿预定义路径点巡逻",
    tags = { "movement", "navigation" },

    validate = function(params)
        if not params.waypoints or #params.waypoints < 2 then
            return false, "至少需要 2 个路径点"
        end
        return true
    end,

    execute = function(params, context)
        local waypoints = params.waypoints
        local currentIdx = context.patrolIndex or 1
        local target = waypoints[currentIdx]

        local node = context.agentNode
        local dist = (target - node.position):Length()

        if dist < 0.5 then
            -- 到达当前路径点，移动到下一个
            currentIdx = currentIdx % #waypoints + 1
            context.patrolIndex = currentIdx
            return true, {
                waypointReached = true,
                nextIndex = currentIdx,
            }
        end

        context.moveDirection = (target - node.position):Normalized()
        context.moveSpeed = params.speed or 2.0
        context.moveTarget = target

        return true, { waypointReached = false, currentIndex = currentIdx }
    end,

    cost = function(params)
        return 5
    end,
}
```

### 2.3 follow — 跟随目标

```lua
local follow = {
    name = "follow",
    description = "跟随指定目标节点，保持一定距离",
    tags = { "movement", "navigation" },

    validate = function(params)
        if not params.targetNode then
            return false, "缺少 targetNode 参数"
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local target = params.targetNode
        local keepDistance = params.distance or 2.0

        local diff = target.position - node.position
        local dist = diff:Length()

        if dist <= keepDistance then
            context.moveDirection = nil
            return true, { inRange = true, distance = dist }
        end

        context.moveDirection = diff:Normalized()
        context.moveSpeed = params.speed or 3.5
        return true, { inRange = false, distance = dist }
    end,

    cost = function(params)
        return 10
    end,
}
```

### 2.4 flee — 逃离威胁

```lua
local flee = {
    name = "flee",
    description = "远离指定威胁源",
    tags = { "movement", "navigation" },

    validate = function(params)
        if not params.threatPosition then
            return false, "缺少 threatPosition 参数"
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local away = (node.position - params.threatPosition):Normalized()
        local dist = (node.position - params.threatPosition):Length()

        if dist > (params.safeDistance or 15.0) then
            context.moveDirection = nil
            return true, { safe = true, distance = dist }
        end

        context.moveDirection = away
        context.moveSpeed = params.speed or 5.0  -- 跑步速度
        return true, { safe = false, distance = dist }
    end,

    cost = function(params)
        return 15
    end,
}
```

---

## §3 战斗工具集

### 3.1 attack — 攻击目标

```lua
local attack = {
    name = "attack",
    description = "对目标执行近战/远程攻击",
    tags = { "combat" },

    validate = function(params)
        if not params.targetNode then
            return false, "缺少攻击目标"
        end
        if not params.damage then
            params.damage = 10
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local target = params.targetNode
        local range = params.range or 2.0

        local dist = (target.position - node.position):Length()
        if dist > range then
            return false, "目标超出攻击范围（" .. string.format("%.1f", dist) .. " > " .. range .. "）"
        end

        -- 面向目标
        local dir = (target.position - node.position):Normalized()
        node:LookAt(target.position, Vector3.UP)

        -- 应用伤害（通过 context 传递给游戏系统）
        context.lastAttack = {
            target = target,
            damage = params.damage,
            timestamp = context.currentTime or 0,
        }

        return true, {
            hit = true,
            damage = params.damage,
            distance = dist,
        }
    end,

    cost = function(params)
        return 30
    end,
}
```

### 3.2 cast_spell — 释放技能

```lua
local cast_spell = {
    name = "cast_spell",
    description = "释放指定技能/法术",
    tags = { "combat", "resource" },

    validate = function(params)
        if not params.spellName then
            return false, "缺少技能名称"
        end
        if not params.manaCost then
            params.manaCost = 20
        end
        return true
    end,

    execute = function(params, context)
        local currentMana = context.mana or 0
        if currentMana < params.manaCost then
            return false, "法力不足（需要 " .. params.manaCost .. "，当前 " .. currentMana .. "）"
        end

        context.mana = currentMana - params.manaCost

        -- 技能效果通过 context 传递
        context.activeSpell = {
            name = params.spellName,
            target = params.targetPosition or params.targetNode,
            power = params.power or 1.0,
            duration = params.duration or 0,
        }

        return true, {
            cast = true,
            spellName = params.spellName,
            remainingMana = context.mana,
        }
    end,

    cost = function(params)
        return 40 + (params.manaCost or 20)
    end,
}
```

### 3.3 defend — 防御姿态

```lua
local defend = {
    name = "defend",
    description = "进入防御姿态，降低受到的伤害",
    tags = { "combat" },

    validate = function(params)
        return true
    end,

    execute = function(params, context)
        context.isDefending = true
        context.defenseMultiplier = params.multiplier or 0.5  -- 50% 伤害减免
        context.defendUntil = (context.currentTime or 0) + (params.duration or 2.0)

        return true, {
            defending = true,
            reduction = (1 - (params.multiplier or 0.5)) * 100 .. "%",
            duration = params.duration or 2.0,
        }
    end,

    cost = function(params)
        return 20
    end,
}
```

---

## §4 感知工具集

### 4.1 scan_area — 区域扫描

```lua
local scan_area = {
    name = "scan_area",
    description = "扫描周围区域，发现敌人、物品和兴趣点",
    tags = { "perception" },

    validate = function(params)
        if not params.radius then
            params.radius = 10.0
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local center = node.position
        local radius = params.radius
        local results = { enemies = {}, items = {}, points = {} }

        -- 遍历场景子节点（实际项目建议用空间索引优化）
        local scene = node:GetScene()
        if not scene then
            return false, "无法获取场景"
        end

        -- 检测标记为不同类别的节点
        local children = scene:GetChildren(true)
        for i = 1, #children do
            local child = children[i]
            local dist = (child.position - center):Length()
            if dist <= radius and child ~= node then
                local tag = child:GetVar("agentTag"):GetString()
                local entry = {
                    node = child,
                    name = child.name,
                    distance = dist,
                    position = child.position,
                }
                if tag == "enemy" then
                    table.insert(results.enemies, entry)
                elseif tag == "item" then
                    table.insert(results.items, entry)
                elseif tag == "poi" then
                    table.insert(results.points, entry)
                end
            end
        end

        -- 按距离排序
        local function sortByDist(a, b) return a.distance < b.distance end
        table.sort(results.enemies, sortByDist)
        table.sort(results.items, sortByDist)

        return true, results
    end,

    cost = function(params)
        return 25  -- 扫描有一定计算开销
    end,
}
```

### 4.2 detect_enemy — 敌人检测

```lua
local detect_enemy = {
    name = "detect_enemy",
    description = "检测最近的敌人，返回位置和威胁等级",
    tags = { "perception", "combat" },

    validate = function(params)
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local detectionRange = params.range or 15.0
        local nearest = nil
        local nearestDist = math.huge

        local scene = node:GetScene()
        local children = scene:GetChildren(true)
        for i = 1, #children do
            local child = children[i]
            local tag = child:GetVar("agentTag"):GetString()
            if tag == "enemy" then
                local dist = (child.position - node.position):Length()
                if dist < detectionRange and dist < nearestDist then
                    nearest = child
                    nearestDist = dist
                end
            end
        end

        if nearest then
            -- 威胁等级基于距离
            local threat = "low"
            if nearestDist < 3.0 then threat = "critical"
            elseif nearestDist < 7.0 then threat = "high"
            elseif nearestDist < 12.0 then threat = "medium"
            end

            return true, {
                detected = true,
                enemy = nearest,
                distance = nearestDist,
                threatLevel = threat,
            }
        end

        return true, { detected = false }
    end,

    cost = function(params)
        return 15
    end,
}
```

---

## §5 交互工具集

### 5.1 pickup_item — 拾取物品

```lua
local pickup_item = {
    name = "pickup_item",
    description = "拾取地面上的物品",
    tags = { "interaction", "resource" },

    validate = function(params)
        if not params.itemNode then
            return false, "缺少物品节点"
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local item = params.itemNode
        local dist = (item.position - node.position):Length()
        local pickupRange = params.range or 1.5

        if dist > pickupRange then
            return false, "物品超出拾取范围"
        end

        -- 获取物品信息
        local itemName = item:GetVar("itemName"):GetString()
        local itemType = item:GetVar("itemType"):GetString()
        local itemValue = item:GetVar("itemValue"):GetInt()

        -- 添加到背包
        if not context.inventory then
            context.inventory = {}
        end
        table.insert(context.inventory, {
            name = itemName,
            type = itemType,
            value = itemValue,
        })

        -- 移除场景中的物品节点
        item:Remove()

        return true, {
            picked = true,
            itemName = itemName,
            inventoryCount = #context.inventory,
        }
    end,

    cost = function(params)
        return 5
    end,
}
```

### 5.2 use_object — 使用环境物体

```lua
local use_object = {
    name = "use_object",
    description = "与环境中的可交互物体互动（开门、拉杆、按钮等）",
    tags = { "interaction" },

    validate = function(params)
        if not params.objectNode then
            return false, "缺少交互对象"
        end
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local obj = params.objectNode
        local dist = (obj.position - node.position):Length()

        if dist > (params.range or 2.0) then
            return false, "距离太远，无法交互"
        end

        local objType = obj:GetVar("interactType"):GetString()
        local result = { interacted = true, objectType = objType }

        if objType == "door" then
            local isOpen = obj:GetVar("isOpen"):GetBool()
            obj:SetVar("isOpen", Variant(not isOpen))
            result.action = isOpen and "关闭" or "打开"
        elseif objType == "lever" then
            obj:SetVar("activated", Variant(true))
            result.action = "拉动"
        elseif objType == "button" then
            obj:SetVar("pressed", Variant(true))
            result.action = "按下"
        else
            result.action = "使用"
        end

        return true, result
    end,

    cost = function(params)
        return 10
    end,
}
```

---

## §6 通信工具集

### 6.1 send_signal — 发送信号

```lua
local send_signal = {
    name = "send_signal",
    description = "向其他代理发送信号/消息",
    tags = { "communication" },

    validate = function(params)
        if not params.signal then
            return false, "缺少信号类型"
        end
        return true
    end,

    execute = function(params, context)
        -- 通过 EventBus 广播（如果可用）
        if context.eventBus then
            context.eventBus:Emit("agent_signal", {
                sender = context.agentNode,
                signal = params.signal,
                data = params.data,
                radius = params.radius or 20.0,
            })
        end

        return true, {
            sent = true,
            signal = params.signal,
        }
    end,

    cost = function(params)
        return 5
    end,
}
```

### 6.2 call_allies — 呼叫援军

```lua
local call_allies = {
    name = "call_allies",
    description = "呼叫附近的友方单位支援",
    tags = { "communication", "combat" },

    validate = function(params)
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local callRange = params.range or 25.0
        local alliesFound = 0

        local scene = node:GetScene()
        local children = scene:GetChildren(true)
        for i = 1, #children do
            local child = children[i]
            local tag = child:GetVar("agentTag"):GetString()
            if tag == "ally" then
                local dist = (child.position - node.position):Length()
                if dist <= callRange then
                    -- 在友方节点上设置支援目标
                    child:SetVar("assistTarget", Variant(node.position))
                    child:SetVar("assistRequested", Variant(true))
                    alliesFound = alliesFound + 1
                end
            end
        end

        return true, {
            called = true,
            alliesNotified = alliesFound,
        }
    end,

    cost = function(params)
        return 15
    end,
}
```

---

## §7 辅助工具集

### 7.1 wait — 等待

```lua
local wait = {
    name = "wait",
    description = "等待指定时长",
    tags = { "utility" },

    validate = function(params)
        if not params.duration or params.duration <= 0 then
            params.duration = 1.0
        end
        return true
    end,

    execute = function(params, context)
        if not context._waitStart then
            context._waitStart = context.currentTime or 0
        end

        local elapsed = (context.currentTime or 0) - context._waitStart
        if elapsed >= params.duration then
            context._waitStart = nil
            return true, { waited = true, duration = params.duration }
        end

        return true, { waited = false, remaining = params.duration - elapsed }
    end,

    cost = function(params)
        return 1
    end,
}
```

### 7.2 set_variable — 设置上下文变量

```lua
local set_variable = {
    name = "set_variable",
    description = "在代理上下文中设置变量值",
    tags = { "utility" },

    validate = function(params)
        if not params.key then
            return false, "缺少变量名"
        end
        return true
    end,

    execute = function(params, context)
        context[params.key] = params.value
        return true, { set = true, key = params.key, value = params.value }
    end,

    cost = function(params)
        return 1
    end,
}
```

### 7.3 log_state — 记录状态

```lua
local log_state = {
    name = "log_state",
    description = "记录当前代理状态到日志",
    tags = { "utility" },

    validate = function(params)
        return true
    end,

    execute = function(params, context)
        local node = context.agentNode
        local info = {
            position = node and tostring(node.position) or "unknown",
            health = context.health or "N/A",
            mana = context.mana or "N/A",
            inventory = context.inventory and #context.inventory or 0,
            state = context.sessionState or "unknown",
        }

        log:Write(LOG_INFO, "[AgentLog] " .. (params.label or "状态") .. ": " ..
            "位置=" .. info.position ..
            " 生命=" .. tostring(info.health) ..
            " 法力=" .. tostring(info.mana) ..
            " 背包=" .. info.inventory)

        return true, info
    end,

    cost = function(params)
        return 1
    end,
}
```

---

## §8 批量注册模板

### 8.1 RPG 游戏工具集

```lua
local function RegisterRPGTools(runner)
    -- 移动
    runner:RegisterTool(move_to)
    runner:RegisterTool(patrol)
    runner:RegisterTool(follow)
    runner:RegisterTool(flee)

    -- 战斗
    runner:RegisterTool(attack)
    runner:RegisterTool(cast_spell)
    runner:RegisterTool(defend)

    -- 感知
    runner:RegisterTool(scan_area)
    runner:RegisterTool(detect_enemy)

    -- 交互
    runner:RegisterTool(pickup_item)
    runner:RegisterTool(use_object)

    -- 通信
    runner:RegisterTool(send_signal)
    runner:RegisterTool(call_allies)

    -- 辅助
    runner:RegisterTool(wait)
    runner:RegisterTool(set_variable)
    runner:RegisterTool(log_state)

    log:Write(LOG_INFO, "[RPGTools] 已注册 16 个工具")
end
```

### 8.2 RTS 游戏工具集

```lua
local function RegisterRTSTools(runner)
    -- 单位移动
    runner:RegisterTool(move_to)
    runner:RegisterTool(patrol)
    runner:RegisterTool(follow)

    -- 战斗
    runner:RegisterTool(attack)

    -- 侦察
    runner:RegisterTool(scan_area)
    runner:RegisterTool(detect_enemy)

    -- RTS 专用：建造
    runner:RegisterTool({
        name = "build_structure",
        description = "在指定位置建造建筑",
        tags = { "interaction", "resource" },
        validate = function(params)
            return params.structureType ~= nil, "缺少建筑类型"
        end,
        execute = function(params, context)
            if (context.resources or 0) < (params.cost or 100) then
                return false, "资源不足"
            end
            context.resources = (context.resources or 0) - (params.cost or 100)
            context.buildQueue = context.buildQueue or {}
            table.insert(context.buildQueue, {
                type = params.structureType,
                position = params.position,
                startTime = context.currentTime or 0,
                buildTime = params.buildTime or 10.0,
            })
            return true, { building = true, type = params.structureType }
        end,
        cost = function(params) return 50 end,
    })

    -- RTS 专用：采集资源
    runner:RegisterTool({
        name = "gather_resource",
        description = "采集指定资源节点的资源",
        tags = { "resource" },
        validate = function(params)
            return params.resourceNode ~= nil, "缺少资源节点"
        end,
        execute = function(params, context)
            local node = context.agentNode
            local res = params.resourceNode
            local dist = (res.position - node.position):Length()
            if dist > 2.0 then
                return false, "距离资源太远"
            end
            local amount = params.amount or 10
            context.resources = (context.resources or 0) + amount
            return true, { gathered = true, amount = amount, total = context.resources }
        end,
        cost = function(params) return 15 end,
    })

    runner:RegisterTool(wait)
    runner:RegisterTool(log_state)

    log:Write(LOG_INFO, "[RTSTools] 已注册 RTS 工具集")
end
```

### 8.3 平台跳跃游戏工具集

```lua
local function RegisterPlatformerTools(runner)
    runner:RegisterTool({
        name = "jump",
        description = "执行跳跃动作",
        tags = { "movement" },
        validate = function(params) return true end,
        execute = function(params, context)
            if not context.isGrounded then
                return false, "不在地面上，无法跳跃"
            end
            context.jumpRequested = true
            context.jumpForce = params.force or 7.0
            return true, { jumped = true }
        end,
        cost = function(params) return 10 end,
    })

    runner:RegisterTool({
        name = "run_direction",
        description = "向指定方向奔跑",
        tags = { "movement" },
        validate = function(params)
            return params.direction ~= nil, "缺少方向"
        end,
        execute = function(params, context)
            context.moveDirection = params.direction
            context.moveSpeed = params.speed or 5.0
            return true, { running = true }
        end,
        cost = function(params) return 5 end,
    })

    runner:RegisterTool({
        name = "check_platform",
        description = "检测前方是否有平台",
        tags = { "perception", "navigation" },
        validate = function(params) return true end,
        execute = function(params, context)
            -- 使用射线检测前方地面
            local node = context.agentNode
            local forward = node.rotation * Vector3.FORWARD
            local checkPos = node.position + forward * (params.distance or 2.0)
            -- 向下投射射线检测地面
            local hasPlatform = context.hasPlatformAhead or false
            return true, { hasPlatform = hasPlatform, checkPosition = checkPos }
        end,
        cost = function(params) return 5 end,
    })

    runner:RegisterTool(wait)
    runner:RegisterTool(log_state)

    log:Write(LOG_INFO, "[PlatformerTools] 已注册平台跳跃工具集")
end
```

---

## §9 自定义工具创建指南

### 9.1 快速创建模板

```lua
--- 创建自定义工具的快捷函数
---@param name string
---@param desc string
---@param tags string[]
---@param executeFn fun(params: table, context: table): boolean, any
---@return AgentTool
local function QuickTool(name, desc, tags, executeFn)
    return {
        name = name,
        description = desc,
        tags = tags,
        validate = function(params) return true end,
        execute = executeFn,
        cost = function(params) return 10 end,
    }
end

-- 使用示例
local my_tool = QuickTool(
    "heal_self",
    "消耗药水恢复生命值",
    { "resource", "combat" },
    function(params, context)
        local potions = context.potions or 0
        if potions <= 0 then
            return false, "没有药水"
        end
        context.potions = potions - 1
        context.health = math.min(
            (context.health or 0) + (params.amount or 30),
            context.maxHealth or 100
        )
        return true, {
            healed = true,
            health = context.health,
            potionsLeft = context.potions,
        }
    end
)
```

### 9.2 工具性能预算

| 工具类别 | 建议 cost 范围 | 说明 |
|---------|---------------|------|
| 辅助/等待 | 1-5 | 几乎无计算开销 |
| 简单移动 | 5-15 | 向量计算 |
| 感知扫描 | 15-30 | 需要遍历场景节点 |
| 战斗动作 | 20-40 | 碰撞检测+状态更新 |
| 技能释放 | 30-60 | 复杂效果计算 |
| 场景查询 | 40-80 | 大量节点遍历 |

### 9.3 注意事项

1. **不要在工具中阻塞** — execute 必须在单帧内返回
2. **使用 context 传递状态** — 不要在工具内部存储状态
3. **validate 先行** — 在 execute 之前完成所有参数检查
4. **pcall 保护** — AgentRunner 已经用 pcall 包裹 execute，但工具内部也应做防御性编程
5. **cost 诚实** — 准确评估计算开销，影响 SelfHealer 的策略选择

---

## §10 构建与测试

将工具定义放在 `scripts/` 目录下的模块文件中：

```
scripts/
├── main.lua              -- 入口
├── Agent/
│   ├── Tools/
│   │   ├── MovementTools.lua    -- §2 移动工具
│   │   ├── CombatTools.lua      -- §3 战斗工具
│   │   ├── PerceptionTools.lua  -- §4 感知工具
│   │   ├── InteractionTools.lua -- §5 交互工具
│   │   └── UtilityTools.lua     -- §7 辅助工具
│   └── AgentRunner.lua          -- 框架主模块
```

编写完成后调用 UrhoX MCP `build` 工具构建项目。

