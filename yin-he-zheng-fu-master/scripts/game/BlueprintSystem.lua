-- ============================================================================
-- game/BlueprintSystem.lua  -- 战术蓝图系统
-- ============================================================================

local M = {}

local blueprints = {}
local nextId = 1

local BlueprintSchema = {
    id = "string",
    name = "string",
    description = "string",
    version = "string",
    created = "number",
    lastModified = "number",
    actions = "table",
    conditions = "table",
    triggers = "table",
    metadata = "table",
}

local ActionTypes = {
    MOVE_TO_TARGET = {
        label = "移动到目标",
        params = { targetType = "planet|fleet|position", targetId = "string", priority = "number" }
    },
    ATTACK_TARGET = {
        label = "攻击目标",
        params = { targetType = "fleet|base", targetId = "string", formation = "string" }
    },
    COLONIZE_PLANET = {
        label = "殖民行星",
        params = { planetId = "string" }
    },
    BUILD_SHIP = {
        label = "建造舰船",
        params = { shipType = "string", count = "number" }
    },
    RESEARCH_TECH = {
        label = "研究科技",
        params = { techId = "string" }
    },
    USE_SKILL = {
        label = "使用技能",
        params = { skillId = "string", targetId = "string" }
    },
    WAIT = {
        label = "等待",
        params = { duration = "number" }
    },
    CONDITIONAL_BRANCH = {
        label = "条件分支",
        params = { conditionId = "string", trueAction = "string", falseAction = "string" }
    },
}

local ConditionTypes = {
    HAS_RESOURCE = {
        label = "拥有资源",
        params = { resourceType = "string", amount = "number", operator = ">=|>|<=|<|==" }
    },
    HAS_TECH = {
        label = "拥有科技",
        params = { techId = "string" }
    },
    FLEET_STRENGTH = {
        label = "舰队实力",
        params = { minShips = "number", maxShips = "number" }
    },
    PLANET_COLONIZED = {
        label = "行星已殖民",
        params = { planetId = "string" }
    },
    ENEMY_NEARBY = {
        label = "敌人在附近",
        params = { range = "number", minCount = "number" }
    },
    TIME_PASSED = {
        label = "时间已过",
        params = { duration = "number" }
    },
}

local TriggerTypes = {
    GAME_START = { label = "游戏开始" },
    WAVE_COMPLETE = { label = "波次完成" },
    RESOURCE_CHANGE = { label = "资源变化" },
    PLANET_CAPTURED = { label = "行星占领" },
    FLEET_CREATED = { label = "舰队创建" },
    TECH_RESEARCHED = { label = "科技研究完成" },
    PLAYER_ACTION = { label = "玩家操作" },
}

function M.CreateBlueprint(name, description)
    local blueprint = {
        id = string.format("blueprint_%d", nextId),
        name = name or "未命名蓝图",
        description = description or "",
        version = "1.0",
        created = os.time(),
        lastModified = os.time(),
        actions = {},
        conditions = {},
        triggers = {},
        metadata = { author = "unknown", tags = {} }
    }
    nextId = nextId + 1
    blueprints[blueprint.id] = blueprint
    return blueprint
end

function M.LoadBlueprint(blueprintData)
    if not blueprintData.id then
        error("Blueprint must have an id")
    end
    blueprintData.lastModified = os.time()
    blueprints[blueprintData.id] = blueprintData
    return blueprintData
end

function M.GetBlueprint(blueprintId)
    return blueprints[blueprintId]
end

function M.DeleteBlueprint(blueprintId)
    blueprints[blueprintId] = nil
end

function M.GetAllBlueprints()
    local result = {}
    for id, blueprint in pairs(blueprints) do
        table.insert(result, blueprint)
    end
    table.sort(result, function(a, b) return a.created > b.created end)
    return result
end

function M.AddAction(blueprintId, actionType, params)
    local blueprint = blueprints[blueprintId]
    if not blueprint then error("Blueprint not found: " .. blueprintId) end
    
    local actionDef = ActionTypes[actionType]
    if not actionDef then error("Unknown action type: " .. actionType) end
    
    local action = {
        id = string.format("action_%d", #blueprint.actions + 1),
        type = actionType,
        label = actionDef.label,
        params = params or {},
        enabled = true,
    }
    table.insert(blueprint.actions, action)
    blueprint.lastModified = os.time()
    return action
end

function M.RemoveAction(blueprintId, actionId)
    local blueprint = blueprints[blueprintId]
    if not blueprint then error("Blueprint not found: " .. blueprintId) end
    
    for i, action in ipairs(blueprint.actions) do
        if action.id == actionId then
            table.remove(blueprint.actions, i)
            blueprint.lastModified = os.time()
            return true
        end
    end
    return false
end

function M.AddCondition(blueprintId, conditionType, params)
    local blueprint = blueprints[blueprintId]
    if not blueprint then error("Blueprint not found: " .. blueprintId) end
    
    local condDef = ConditionTypes[conditionType]
    if not condDef then error("Unknown condition type: " .. conditionType) end
    
    local condition = {
        id = string.format("cond_%d", #blueprint.conditions + 1),
        type = conditionType,
        label = condDef.label,
        params = params or {},
    }
    table.insert(blueprint.conditions, condition)
    blueprint.lastModified = os.time()
    return condition
end

function M.AddTrigger(blueprintId, triggerType, params)
    local blueprint = blueprints[blueprintId]
    if not blueprint then error("Blueprint not found: " .. blueprintId) end
    
    local triggerDef = TriggerTypes[triggerType]
    if not triggerDef then error("Unknown trigger type: " .. triggerType) end
    
    local trigger = {
        id = string.format("trigger_%d", #blueprint.triggers + 1),
        type = triggerType,
        label = triggerDef.label,
        params = params or {},
        enabled = true,
    }
    table.insert(blueprint.triggers, trigger)
    blueprint.lastModified = os.time()
    return trigger
end

function M.ValidateBlueprint(blueprintId)
    local blueprint = blueprints[blueprintId]
    if not blueprint then return false, "Blueprint not found" end
    
    local errors = {}
    
    if not blueprint.name or blueprint.name == "" then
        table.insert(errors, "蓝图名称不能为空")
    end
    
    if #blueprint.actions == 0 then
        table.insert(errors, "蓝图至少需要一个动作")
    end
    
    if #blueprint.triggers == 0 then
        table.insert(errors, "蓝图至少需要一个触发器")
    end
    
    for _, action in ipairs(blueprint.actions) do
        if not ActionTypes[action.type] then
            table.insert(errors, "未知动作类型: " .. action.type)
        end
    end
    
    return #errors == 0, errors
end

function M.ExportBlueprint(blueprintId)
    local blueprint = blueprints[blueprintId]
    if not blueprint then return nil end
    
    return {
        id = blueprint.id,
        name = blueprint.name,
        description = blueprint.description,
        version = blueprint.version,
        actions = blueprint.actions,
        conditions = blueprint.conditions,
        triggers = blueprint.triggers,
        metadata = blueprint.metadata,
    }
end

function M.GetActionTypes()
    return ActionTypes
end

function M.GetConditionTypes()
    return ConditionTypes
end

function M.GetTriggerTypes()
    return TriggerTypes
end

function M.ExecuteBlueprint(blueprintId, context)
    local blueprint = blueprints[blueprintId]
    if not blueprint then error("Blueprint not found: " .. blueprintId) end
    
    local success, errors = M.ValidateBlueprint(blueprintId)
    if not success then
        error("Blueprint validation failed: " .. table.concat(errors, ", "))
    end
    
    local results = {}
    for _, action in ipairs(blueprint.actions) do
        if action.enabled then
            local result = M.ExecuteAction(action, context)
            table.insert(results, { actionId = action.id, result = result })
        end
    end
    
    return results
end

function M.ExecuteAction(action, context)
    local actionType = action.type
    local params = action.params
    
    if actionType == "MOVE_TO_TARGET" then
        return M._executeMoveToTarget(params, context)
    elseif actionType == "ATTACK_TARGET" then
        return M._executeAttackTarget(params, context)
    elseif actionType == "COLONIZE_PLANET" then
        return M._executeColonizePlanet(params, context)
    elseif actionType == "BUILD_SHIP" then
        return M._executeBuildShip(params, context)
    elseif actionType == "RESEARCH_TECH" then
        return M._executeResearchTech(params, context)
    elseif actionType == "USE_SKILL" then
        return M._executeUseSkill(params, context)
    elseif actionType == "WAIT" then
        return M._executeWait(params, context)
    elseif actionType == "CONDITIONAL_BRANCH" then
        return M._executeConditionalBranch(params, context)
    end
    
    return { success = false, error = "Unknown action type: " .. actionType }
end

function M._executeMoveToTarget(params, context)
    return { success = true, message = "移动命令已执行", target = params.targetId }
end

function M._executeAttackTarget(params, context)
    return { success = true, message = "攻击命令已执行", target = params.targetId }
end

function M._executeColonizePlanet(params, context)
    return { success = true, message = "殖民命令已执行", planet = params.planetId }
end

function M._executeBuildShip(params, context)
    return { success = true, message = "建造命令已执行", shipType = params.shipType, count = params.count }
end

function M._executeResearchTech(params, context)
    return { success = true, message = "研究命令已执行", tech = params.techId }
end

function M._executeUseSkill(params, context)
    return { success = true, message = "技能使用命令已执行", skill = params.skillId }
end

function M._executeWait(params, context)
    return { success = true, message = "等待命令已执行", duration = params.duration }
end

function M._executeConditionalBranch(params, context)
    return { success = true, message = "条件分支已执行", condition = params.conditionId }
end

return M