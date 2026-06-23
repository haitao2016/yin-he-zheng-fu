---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/systems/AIBattleSystem.lua
-- V3.0 P3-2: AI 对战模式
-- ============================================================================

local AIBattleSystem = {}

-- ============================================================================
-- 常量定义
-- ============================================================================

-- AI 难度配置
AI_DIFFICULTIES = {
    {
        id = "NOVICE",
        name = "新手",
        desc = "适合新手玩家学习",
        aiLevel = 0.3,
        reactionDelay = 2.0,
        decisionVariance = 0.5,
        fleetSize = 5,
    },
    {
        id = "VETERAN",
        name = "老手",
        desc = "具有一定挑战性",
        aiLevel = 0.6,
        reactionDelay = 1.0,
        decisionVariance = 0.3,
        fleetSize = 8,
    },
    {
        id = "MASTER",
        name = "大师",
        desc = "高难度 AI 对战",
        aiLevel = 0.85,
        reactionDelay = 0.5,
        decisionVariance = 0.15,
        fleetSize = 12,
    },
}

-- AI 排行榜
AI_LEADERBOARD = {
    rankings = {},    -- { aiId -> { wins = 0, losses = 0, streak = 0 } }
    matches = {},     -- 历史对战记录
}

-- ============================================================================
-- 运行时状态
-- ============================================================================
local AIBattleState = {
    currentMatch = nil,          -- 当前 AI 对战
    battleHistory = {},         -- AI 对战历史
    selectedDifficulty = nil,    -- 选定的难度
    seed = nil,                 -- 战斗随机种子
    settings = {
        randomSeed = true,        -- 是否使用随机种子
        fixedSeed = 12345,       -- 固定种子
        showBattleLog = true,    -- 显示战斗日志
    },
}

-- ============================================================================
-- AI 对战初始化
-- ============================================================================

--- 创建 AI 对战
function AIBattleSystem.createBattle(difficultyId, options)
    -- 获取难度配置
    local difficulty = nil
    for _, diff in ipairs(AI_DIFFICULTIES) do
        if diff.id == difficultyId then
            difficulty = diff
            break
        end
    end
    
    if not difficulty then
        return false, "无效的难度等级"
    end
    
    -- 确定随机种子
    local seed
    if options and options.randomSeed == false and options.seed then
        seed = options.seed
    else
        seed = os.time() + math.random(10000)
    end
    
    -- 创建对战
    AIBattleState.currentMatch = {
        id = "AI_BATTLE_" .. seed,
        difficulty = difficulty,
        difficultyId = difficultyId,
        seed = seed,
        status = "PREPARING",
        startTime = os.time(),
        turnCount = 0,
        battleLog = {},
        results = nil,
        teams = {
            left = {
                name = "AI-LEFT",
                type = "AI",
                aiLevel = difficulty.aiLevel,
                ships = {},
                score = 0,
            },
            right = {
                name = "AI-RIGHT",
                type = "AI",
                aiLevel = difficulty.aiLevel + math.random(-0.1, 0.1),
                ships = {},
                score = 0,
            },
        },
    }
    
    -- 初始化舰队
    AIBattleSystem.initializeFleets(AIBattleState.currentMatch)
    
    -- 设置种子
    math.randomseed(seed)
    
    return true, "AI 对战已创建", AIBattleState.currentMatch.id
end

--- 初始化舰队
function AIBattleSystem.initializeFleets(match)
    local difficulty = match.difficulty
    local fleetSize = difficulty.fleetSize
    
    -- 初始化左方 AI 舰队
    for i = 1, fleetSize do
        local shipType = AIBattleSystem.getRandomShipType()
        table.insert(match.teams.left.ships, {
            id = "LEFT_" .. i,
            type = shipType,
            hp = 100,
            maxHp = 100,
            atk = AIBattleSystem.calculateATK(shipType),
            speed = AIBattleSystem.calculateSpeed(shipType),
            pos = { x = 100 + i * 50, y = 300 + math.random(-100, 100) },
            status = "ALIVE",
        })
    end
    
    -- 初始化右方 AI 舰队
    for i = 1, fleetSize do
        local shipType = AIBattleSystem.getRandomShipType()
        table.insert(match.teams.right.ships, {
            id = "RIGHT_" .. i,
            type = shipType,
            hp = 100,
            maxHp = 100,
            atk = AIBattleSystem.calculateATK(shipType),
            speed = AIBattleSystem.calculateSpeed(shipType),
            pos = { x = 700 - i * 50, y = 300 + math.random(-100, 100) },
            status = "ALIVE",
        })
    end
    
    match.status = "READY"
end

--- 获取随机舰船类型
function AIBattleSystem.getRandomShipType()
    local types = { "FRIGATE", "DESTROYER", "BATTLECRUISER", "CARRIER", "CORVETTE" }
    return types[math.random(#types)]
end

--- 计算攻击力
function AIBattleSystem.calculateATK(shipType)
    local baseATK = {
        FRIGATE = 10,
        DESTROYER = 20,
        BATTLECRUISER = 40,
        CARRIER = 15,
        CORVETTE = 8,
    }
    return baseATK[shipType] or 15
end

--- 计算速度
function AIBattleSystem.calculateSpeed(shipType)
    local baseSpeed = {
        FRIGATE = 8,
        DESTROYER = 5,
        BATTLECRUISER = 3,
        CARRIER = 2,
        CORVETTE = 10,
    }
    return baseSpeed[shipType] or 5
end

-- ============================================================================
-- AI 对战流程
-- ============================================================================

--- 开始 AI 对战
function AIBattleSystem.startBattle()
    if not AIBattleState.currentMatch then
        return false, "没有进行中的 AI 对战"
    end
    
    if AIBattleState.currentMatch.status ~= "READY" then
        return false, "对战状态不正确"
    end
    
    AIBattleState.currentMatch.status = "RUNNING"
    
    return true, "AI 对战已开始"
end

--- 执行一回合
function AIBattleSystem.executeTurn()
    local match = AIBattleState.currentMatch
    if not match or match.status ~= "RUNNING" then
        return nil
    end
    
    match.turnCount = match.turnCount + 1
    
    -- 记录回合开始
    table.insert(match.battleLog, {
        turn = match.turnCount,
        type = "TURN_START",
        message = "第 " .. match.turnCount .. " 回合开始",
    })
    
    -- AI 决策（左方）
    local leftActions = AIBattleSystem.executeAITurn(match, "left")
    
    -- AI 决策（右方）
    local rightActions = AIBattleSystem.executeAITurn(match, "right")
    
    -- 结算伤害
    AIBattleSystem.resolveActions(match, leftActions, rightActions)
    
    -- 检查胜负
    local winner = AIBattleSystem.checkWinner(match)
    
    -- 记录回合结束
    table.insert(match.battleLog, {
        turn = match.turnCount,
        type = "TURN_END",
        message = "第 " .. match.turnCount .. " 回合结束",
    })
    
    return {
        turn = match.turnCount,
        leftActions = leftActions,
        rightActions = rightActions,
        winner = winner,
        status = match.status,
    }
end

--- AI 决策
function AIBattleSystem.executeAITurn(match, teamId)
    local team = match.teams[teamId]
    local actions = {}
    local aiLevel = team.aiLevel
    
    for _, ship in ipairs(team.ships) do
        if ship.status ~= "ALIVE" then
            goto continue
        end
        
        -- 根据 AI 等级决定是否行动
        if math.random() > aiLevel then
            goto continue
        end
        
        -- 行动选择
        local actionType = math.random()
        
        if actionType < 0.4 then
            -- 攻击
            local target = AIBattleSystem.selectTarget(match, teamId, ship)
            if target then
                local damage = AIBattleSystem.calculateDamage(ship, target)
                table.insert(actions, {
                    type = "ATTACK",
                    shipId = ship.id,
                    targetId = target.id,
                    damage = damage,
                })
                
                target.hp = target.hp - damage
                
                if target.hp <= 0 then
                    target.hp = 0
                    target.status = "DESTROYED"
                end
            end
            
        elseif actionType < 0.7 then
            -- 移动
            local direction = teamId == "left" and 1 or -1
            local newX = ship.pos.x + direction * ship.speed * 10
            ship.pos.x = math.max(50, math.min(750, newX))
            
            table.insert(actions, {
                type = "MOVE",
                shipId = ship.id,
                newPos = { x = ship.pos.x, y = ship.pos.y },
            })
            
        elseif actionType < 0.9 then
            -- 集火
            local target = AIBattleSystem.selectPriorityTarget(match, teamId)
            if target then
                table.insert(actions, {
                    type = "FOCUS",
                    shipId = ship.id,
                    targetId = target.id,
                })
            end
            
        else
            -- 保持位置
            table.insert(actions, {
                type = "HOLD",
                shipId = ship.id,
            })
        end
        
        ::continue::
    end
    
    return actions
end

--- 选择目标
function AIBattleSystem.selectTarget(match, teamId, attacker)
    local enemyTeamId = teamId == "left" and "right" or "left"
    local enemyTeam = match.teams[enemyTeamId]
    
    local candidates = {}
    for _, ship in ipairs(enemyTeam.ships) do
        if ship.status == "ALIVE" then
            table.insert(candidates, ship)
        end
    end
    
    if #candidates == 0 then
        return nil
    end
    
    -- 随机选择（简单实现）
    return candidates[math.random(#candidates)]
end

--- 选择优先目标
function AIBattleSystem.selectPriorityTarget(match, teamId)
    local enemyTeamId = teamId == "left" and "right" or "left"
    local enemyTeam = match.teams[enemyTeamId]
    
    local lowestHpShip = nil
    local lowestHp = math.huge
    
    for _, ship in ipairs(enemyTeam.ships) do
        if ship.status == "ALIVE" and ship.hp < lowestHp then
            lowestHp = ship.hp
            lowestHpShip = ship
        end
    end
    
    return lowestHpShip
end

--- 计算伤害
function AIBattleSystem.calculateDamage(attacker, defender)
    local baseDamage = attacker.atk
    local variance = math.random(80, 120) / 100
    local damage = math.floor(baseDamage * variance)
    
    -- 暴击（10% 概率，2 倍伤害）
    if math.random() < 0.1 then
        damage = damage * 2
    end
    
    return damage
end

--- 结算行动
function AIBattleSystem.resolveActions(match, leftActions, rightActions)
    -- 合并并排序行动（简单实现：随机顺序）
    local allActions = {}
    
    for _, action in ipairs(leftActions) do
        action.team = "left"
        table.insert(allActions, action)
    end
    
    for _, action in ipairs(rightActions) do
        action.team = "right"
        table.insert(allActions, action)
    end
    
    -- 随机排序
    for i = #allActions, 2, -1 do
        local j = math.random(i)
        allActions[i], allActions[j] = allActions[j], allActions[i]
    end
    
    -- 执行行动并记录日志
    for _, action in ipairs(allActions) do
        local actionDesc = ""
        
        if action.type == "ATTACK" then
            actionDesc = action.shipId .. " 攻击 " .. action.targetId .. "，造成 " .. action.damage .. " 伤害"
        elseif action.type == "MOVE" then
            actionDesc = action.shipId .. " 移动到 (" .. math.floor(action.newPos.x) .. ", " .. math.floor(action.newPos.y) .. ")"
        elseif action.type == "FOCUS" then
            actionDesc = action.shipId .. " 集火 " .. action.targetId
        elseif action.type == "HOLD" then
            actionDesc = action.shipId .. " 保持位置"
        end
        
        table.insert(match.battleLog, {
            turn = match.turnCount,
            type = action.type,
            team = action.team,
            message = actionDesc,
        })
    end
end

--- 检查胜负
function AIBattleSystem.checkWinner(match)
    local leftAlive = 0
    local rightAlive = 0
    
    for _, ship in ipairs(match.teams.left.ships) do
        if ship.status == "ALIVE" then
            leftAlive = leftAlive + 1
        end
    end
    
    for _, ship in ipairs(match.teams.right.ships) do
        if ship.status == "ALIVE" then
            rightAlive = rightAlive + 1
        end
    end
    
    -- 检查超时
    if match.turnCount >= 100 then
        match.status = "TIMEOUT"
        if leftAlive > rightAlive then
            return "LEFT"
        elseif rightAlive > leftAlive then
            return "RIGHT"
        else
            return "DRAW"
        end
    end
    
    -- 检查一方全灭
    if leftAlive == 0 then
        match.status = "FINISHED"
        return "RIGHT"
    elseif rightAlive == 0 then
        match.status = "FINISHED"
        return "LEFT"
    end
    
    return nil
end

--- 结束 AI 对战
function AIBattleSystem.endBattle(winner)
    local match = AIBattleState.currentMatch
    if not match then
        return false, "没有进行中的 AI 对战"
    end
    
    match.status = "FINISHED"
    match.endTime = os.time()
    match.winner = winner
    
    -- 更新分数
    if winner == "LEFT" then
        match.teams.left.score = match.teams.left.score + 1
    elseif winner == "RIGHT" then
        match.teams.right.score = match.teams.right.score + 1
    end
    
    -- 记录历史
    table.insert(AIBattleState.battleHistory, {
        id = match.id,
        difficulty = match.difficultyId,
        seed = match.seed,
        turnCount = match.turnCount,
        winner = winner,
        timestamp = os.time(),
    })
    
    -- 限制历史数量
    while #AIBattleState.battleHistory > 50 do
        table.remove(AIBattleState.battleHistory, 1)
    end
    
    AIBattleState.currentMatch = nil
    
    return true, winner
end

-- ============================================================================
-- AI 对战配置
-- ============================================================================

--- 获取难度列表
function AIBattleSystem.getDifficulties()
    return AI_DIFFICULTIES
end

--- 获取当前对战状态
function AIBattleSystem.getMatchState()
    return AIBattleState.currentMatch
end

--- 获取战斗日志
function AIBattleSystem.getBattleLog()
    if not AIBattleState.currentMatch then
        return {}
    end
    return AIBattleState.currentMatch.battleLog
end

--- 获取对战历史
function AIBattleSystem.getHistory(limit)
    limit = limit or 20
    local history = AIBattleState.battleHistory
    
    local result = {}
    for i = #history, math.max(1, #history - limit + 1), -1 do
        table.insert(result, history[i])
    end
    
    return result
end

--- 获取对战统计
function AIBattleSystem.getStats()
    local stats = {
        totalBattles = #AIBattleState.battleHistory,
        leftWins = 0,
        rightWins = 0,
        draws = 0,
        avgTurns = 0,
    }
    
    local totalTurns = 0
    for _, battle in ipairs(AIBattleState.battleHistory) do
        if battle.winner == "LEFT" then
            stats.leftWins = stats.leftWins + 1
        elseif battle.winner == "RIGHT" then
            stats.rightWins = stats.rightWins + 1
        else
            stats.draws = stats.draws + 1
        end
        totalTurns = totalTurns + battle.turnCount
    end
    
    if stats.totalBattles > 0 then
        stats.avgTurns = math.floor(totalTurns / stats.totalBattles)
    end
    
    return stats
end

-- ============================================================================
-- AI 排行榜
-- ============================================================================

--- 更新 AI 排行榜
function AIBattleSystem.updateLeaderboard(aiId, result)
    if not AI_LEADERBOARD.rankings[aiId] then
        AI_LEADERBOARD.rankings[aiId] = {
            aiId = aiId,
            wins = 0,
            losses = 0,
            streak = 0,
            bestStreak = 0,
        }
    end
    
    local ranking = AI_LEADERBOARD.rankings[aiId]
    
    if result == "WIN" then
        ranking.wins = ranking.wins + 1
        ranking.streak = ranking.streak + 1
        ranking.bestStreak = math.max(ranking.bestStreak, ranking.streak)
    elseif result == "LOSS" then
        ranking.losses = ranking.losses + 1
        ranking.streak = 0
    end
end

--- 获取 AI 排行榜
function AIBattleSystem.getLeaderboard(limit)
    limit = limit or 20
    
    local rankings = {}
    for aiId, ranking in pairs(AI_LEADERBOARD.rankings) do
        table.insert(rankings, {
            aiId = aiId,
            wins = ranking.wins,
            losses = ranking.losses,
            streak = ranking.streak,
            bestStreak = ranking.bestStreak,
            winRate = ranking.wins + ranking.losses > 0 
                and math.floor(ranking.wins / (ranking.wins + ranking.losses) * 100) 
                or 0,
        })
    end
    
    -- 按胜率排序
    table.sort(rankings, function(a, b)
        if a.winRate ~= b.winRate then
            return a.winRate > b.winRate
        end
        return a.wins > b.wins
    end)
    
    -- 添加排名
    for i, entry in ipairs(rankings) do
        entry.rank = i
    end
    
    -- 限制数量
    local result = {}
    for i = 1, math.min(limit, #rankings) do
        table.insert(result, rankings[i])
    end
    
    return result
end

-- ============================================================================
-- 设置
-- ============================================================================

--- 更新设置
function AIBattleSystem.updateSettings(settings)
    for key, value in pairs(settings) do
        if AIBattleState.settings[key] ~= nil then
            AIBattleState.settings[key] = value
        end
    end
end

--- 获取设置
function AIBattleSystem.getSettings()
    return AIBattleState.settings
end

-- ============================================================================
-- 存档
-- ============================================================================

function AIBattleSystem.saveState()
    if playerState then
        playerState.aiBattleState = {
            battleHistory = AIBattleState.battleHistory,
            selectedDifficulty = AIBattleState.selectedDifficulty,
            settings = AIBattleState.settings,
            leaderboard = AI_LEADERBOARD,
        }
    end
end

function AIBattleSystem.loadState(data)
    if data then
        AIBattleState.battleHistory = data.battleHistory or {}
        AIBattleState.selectedDifficulty = data.selectedDifficulty
        AIBattleState.settings = data.settings or AIBattleState.settings
        AI_LEADERBOARD = data.leaderboard or AI_LEADERBOARD
    end
end

return AIBattleSystem
