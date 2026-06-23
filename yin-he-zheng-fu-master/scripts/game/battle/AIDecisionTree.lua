-- ============================================================================
-- battle/AIDecisionTree.lua  -- AI决策树系统
-- ============================================================================

local M = {}

local BATTLE_TACTICS = {
    DEFENSIVE = "defensive",
    OFFENSIVE = "offensive",
    HARASS = "harass",
    AMBUSH = "ambush",
    RETREAT = "retreat",
}

local TACTIC_CONFIG = {
    [BATTLE_TACTICS.DEFENSIVE] = {
        name = "防御战术",
        description = "优先保护己方舰船，减少伤亡",
        weight = 0.3,
        moveAggression = 0.2,
        targetPriority = "weakest",
        shootPriority = "closest",
    },
    [BATTLE_TACTICS.OFFENSIVE] = {
        name = "进攻战术",
        description = "全力攻击敌方舰船",
        weight = 0.3,
        moveAggression = 0.8,
        targetPriority = "highestThreat",
        shootPriority = "highestThreat",
    },
    [BATTLE_TACTICS.HARASS] = {
        name = "骚扰战术",
        description = "游击式攻击，打带跑",
        weight = 0.2,
        moveAggression = 0.6,
        targetPriority = "isolated",
        shootPriority = "weakest",
    },
    [BATTLE_TACTICS.AMBUSH] = {
        name = "伏击战术",
        description = "等待敌方靠近后突然攻击",
        weight = 0.1,
        moveAggression = 0.1,
        targetPriority = "leader",
        shootPriority = "leader",
    },
    [BATTLE_TACTICS.RETREAT] = {
        name = "撤退战术",
        description = "战略性撤退，保存实力",
        weight = 0.1,
        moveAggression = -0.5,
        targetPriority = "none",
        shootPriority = "closest",
    },
}

local STATE_NODE_TYPES = {
    CONDITION = "condition",
    ACTION = "action",
    SELECTOR = "selector",
    SEQUENCE = "sequence",
    PARALLEL = "parallel",
}

local function createNode(nodeType, data)
    return {
        type = nodeType,
        data = data,
        children = {},
    }
end

local function evaluateCondition(node, context)
    local condition = node.data
    if condition.type == "healthPercent" then
        local hpPercent = context.self.health / context.self.maxHealth
        if condition.comparison == "lessThan" then
            return hpPercent < condition.value
        elseif condition.comparison == "greaterThan" then
            return hpPercent > condition.value
        elseif condition.comparison == "equals" then
            return hpPercent == condition.value
        end
    elseif condition.type == "distanceToTarget" then
        local dist = context.distanceToTarget or math.huge
        if condition.comparison == "lessThan" then
            return dist < condition.value
        elseif condition.comparison == "greaterThan" then
            return dist > condition.value
        end
    elseif condition.type == "hasAllyNearby" then
        local count = context.allyCountNearby or 0
        return count >= condition.minCount
    elseif condition.type == "enemyCount" then
        local count = context.enemyCount or 0
        if condition.comparison == "greaterThan" then
            return count > condition.value
        elseif condition.comparison == "lessThan" then
            return count < condition.value
        end
    elseif condition.type == "tacticAvailable" then
        return context.currentTactic == condition.tactic
    elseif condition.type == "isBoss" then
        return context.self.isBoss or false
    elseif condition.type == "waveNumber" then
        local wave = context.waveNumber or 1
        if condition.comparison == "greaterThan" then
            return wave > condition.value
        elseif condition.comparison == "lessThan" then
            return wave < condition.value
        end
    elseif condition.type == "timeSinceSpawn" then
        local age = context.self.age or 0
        if condition.comparison == "greaterThan" then
            return age > condition.value
        end
    end
    return false
end

local function executeAction(node, context)
    local action = node.data
    if action.type == "selectTactic" then
        context.currentTactic = action.tactic
        return true
    elseif action.type == "setTargetPriority" then
        context.targetPriority = action.priority
        return true
    elseif action.type == "setMoveAggression" then
        context.moveAggression = action.value
        return true
    elseif action.type == "focusFire" then
        context.focusTarget = action.targetType
        return true
    elseif action.type == "retreat" then
        context.shouldRetreat = true
        return true
    elseif action.type == "holdPosition" then
        context.shouldHoldPosition = true
        return true
    elseif action.type == "advance" then
        context.shouldAdvance = true
        return true
    end
    return false
end

local function evaluateNode(node, context)
    if not node then return false end
    
    if node.type == STATE_NODE_TYPES.CONDITION then
        return evaluateCondition(node, context)
    elseif node.type == STATE_NODE_TYPES.ACTION then
        return executeAction(node, context)
    elseif node.type == STATE_NODE_TYPES.SELECTOR then
        for _, child in ipairs(node.children) do
            if evaluateNode(child, context) then
                return true
            end
        end
        return false
    elseif node.type == STATE_NODE_TYPES.SEQUENCE then
        for _, child in ipairs(node.children) do
            if not evaluateNode(child, context) then
                return false
            end
        end
        return true
    elseif node.type == STATE_NODE_TYPES.PARALLEL then
        local successCount = 0
        local required = node.data.required or #node.children
        for _, child in ipairs(node.children) do
            if evaluateNode(child, context) then
                successCount = successCount + 1
            end
        end
        return successCount >= required
    end
    return false
end

function M.CreateDecisionTree()
    local root = createNode(STATE_NODE_TYPES.SELECTOR, { name = "Root" })
    
    local retreatBranch = createNode(STATE_NODE_TYPES.SEQUENCE, { name = "RetreatBranch" })
    retreatBranch.children[#retreatBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "healthPercent",
        comparison = "lessThan",
        value = 0.2
    })
    retreatBranch.children[#retreatBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "enemyCount",
        comparison = "greaterThan",
        value = 3
    })
    retreatBranch.children[#retreatBranch.children + 1] = createNode(STATE_NODE_TYPES.ACTION, {
        type = "selectTactic",
        tactic = BATTLE_TACTICS.RETREAT
    })
    root.children[#root.children + 1] = retreatBranch
    
    local ambushBranch = createNode(STATE_NODE_TYPES.SEQUENCE, { name = "AmbushBranch" })
    ambushBranch.children[#ambushBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "distanceToTarget",
        comparison = "greaterThan",
        value = 200
    })
    ambushBranch.children[#ambushBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "hasAllyNearby",
        minCount = 2
    })
    ambushBranch.children[#ambushBranch.children + 1] = createNode(STATE_NODE_TYPES.ACTION, {
        type = "selectTactic",
        tactic = BATTLE_TACTICS.AMBUSH
    })
    root.children[#root.children + 1] = ambushBranch
    
    local defensiveBranch = createNode(STATE_NODE_TYPES.SEQUENCE, { name = "DefensiveBranch" })
    defensiveBranch.children[#defensiveBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "healthPercent",
        comparison = "lessThan",
        value = 0.4
    })
    defensiveBranch.children[#defensiveBranch.children + 1] = createNode(STATE_NODE_TYPES.ACTION, {
        type = "selectTactic",
        tactic = BATTLE_TACTICS.DEFENSIVE
    })
    root.children[#root.children + 1] = defensiveBranch
    
    local harassBranch = createNode(STATE_NODE_TYPES.SEQUENCE, { name = "HarassBranch" })
    harassBranch.children[#harassBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "distanceToTarget",
        comparison = "greaterThan",
        value = 150
    })
    harassBranch.children[#harassBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "isBoss",
    })
    harassBranch.children[#harassBranch.children + 1] = createNode(STATE_NODE_TYPES.ACTION, {
        type = "selectTactic",
        tactic = BATTLE_TACTICS.HARASS
    })
    root.children[#root.children + 1] = harassBranch
    
    local offensiveBranch = createNode(STATE_NODE_TYPES.SELECTOR, { name = "OffensiveBranch" })
    local waveCondition = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "waveNumber",
        comparison = "greaterThan",
        value = 3
    })
    offensiveBranch.children[#offensiveBranch.children + 1] = waveCondition
    offensiveBranch.children[#offensiveBranch.children + 1] = createNode(STATE_NODE_TYPES.CONDITION, {
        type = "healthPercent",
        comparison = "greaterThan",
        value = 0.6
    })
    root.children[#root.children + 1] = offensiveBranch
    
    local defaultAction = createNode(STATE_NODE_TYPES.ACTION, {
        type = "selectTactic",
        tactic = BATTLE_TACTICS.OFFENSIVE
    })
    root.children[#root.children + 1] = defaultAction
    
    return root
end

function M.Evaluate(tree, context)
    return evaluateNode(tree, context)
end

function M.GetTacticConfig(tactic)
    return TACTIC_CONFIG[tactic] or TACTIC_CONFIG[BATTLE_TACTICS.OFFENSIVE]
end

function M.GetTactics()
    return BATTLE_TACTICS
end

function M.CalculateTargetPriority(ships, selfShip, tactic, context)
    local config = M.GetTacticConfig(tactic)
    local priority = config.targetPriority
    
    if priority == "weakest" then
        local weakest = nil
        local minHpPercent = math.huge
        for _, ship in ipairs(ships) do
            local hpPercent = ship.health / ship.maxHealth
            if hpPercent < minHpPercent then
                minHpPercent = hpPercent
                weakest = ship
            end
        end
        return weakest
    elseif priority == "highestThreat" then
        local highest = nil
        local maxThreat = -math.huge
        for _, ship in ipairs(ships) do
            local threat = (ship.dmg or 0) * (ship.shotRate or 1)
            if threat > maxThreat then
                maxThreat = threat
                highest = ship
            end
        end
        return highest
    elseif priority == "closest" then
        local closest = nil
        local minDist = math.huge
        for _, ship in ipairs(ships) do
            local dx = ship.x - selfShip.x
            local dy = ship.y - selfShip.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < minDist then
                minDist = dist
                closest = ship
            end
        end
        return closest
    elseif priority == "isolated" then
        local mostIsolated = nil
        local maxDistToAlly = -math.huge
        for _, ship in ipairs(ships) do
            local minDistToAlly = math.huge
            for _, ally in ipairs(ships) do
                if ally ~= ship then
                    local dx = ship.x - ally.x
                    local dy = ship.y - ally.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < minDistToAlly then
                        minDistToAlly = dist
                    end
                end
            end
            if minDistToAlly > maxDistToAlly then
                maxDistToAlly = minDistToAlly
                mostIsolated = ship
            end
        end
        return mostIsolated
    elseif priority == "leader" then
        if #ships > 0 then
            return ships[1]
        end
        return nil
    end
    
    return M.CalculateTargetPriority(ships, selfShip, BATTLE_TACTICS.OFFENSIVE, context)
end

function M.UpdateTactic(context)
    local tree = context.decisionTree or M.CreateDecisionTree()
    context.decisionTree = tree
    
    M.Evaluate(tree, context)
    
    local tactic = context.currentTactic or BATTLE_TACTICS.OFFENSIVE
    local config = M.GetTacticConfig(tactic)
    
    context.moveAggression = config.moveAggression
    context.targetPriority = config.targetPriority
    
    return tactic
end

return M