---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
LeaderboardSystem.lua - 排行榜系统
V2.7 P2-1
本地排行榜 + 分数提交
]]

local LeaderboardSystem = {}

-- 排行榜类型
LeaderboardSystem.BOARD_TYPES = {
    ENDLESS = { name = "无尽模式", key = "endlessRecord", icon = "∞" },
    BOSS_RUSH = { name = "Boss Rush", key = "bossRushScore", icon = "💀" },
    SPEEDRUN = { name = "速通", key = "speedrunTime", icon = "⏱️" },
    TOTAL_SCORE = { name = "总分", key = "totalScore", icon = "🏆" },
}

-- 初始化排行榜
function LeaderboardSystem.init(playerState)
    playerState.leaderboards = playerState.leaderboards or {}
    for typeKey, _ in pairs(LeaderboardSystem.BOARD_TYPES) do
        playerState.leaderboards[typeKey] = playerState.leaderboards[typeKey] or {}
    end
end

-- 提交分数
function LeaderboardSystem.submitScore(boardType, score, playerState, playerName)
    playerName = playerName or "玩家"
    
    LeaderboardSystem.init(playerState)
    
    local board = playerState.leaderboards[boardType]
    if not board then return false end
    
    -- 检查是否已有记录
    local existing = nil
    for i, entry in ipairs(board) do
        if entry.name == playerName then
            existing = i
            break
        end
    end
    
    if existing then
        -- 更新记录（如果新分数更高）
        if boardType == "SPEEDRUN" then
            -- 速通是时间越短越好
            if score < board[existing].score then
                board[existing].score = score
                board[existing].timestamp = os.time()
            end
        else
            -- 其他是分数越高越好
            if score > board[existing].score then
                board[existing].score = score
                board[existing].timestamp = os.time()
            end
        end
    else
        -- 新记录
        table.insert(board, {
            name = playerName,
            score = score,
            timestamp = os.time(),
        })
    end
    
    -- 排序
    if boardType == "SPEEDRUN" then
        table.sort(board, function(a, b) return a.score < b.score end)
    else
        table.sort(board, function(a, b) return a.score > b.score end)
    end
    
    -- 限制数量
    while #board > 20 do
        table.remove(board)
    end
    
    return true
end

-- 获取排行榜
function LeaderboardSystem.getBoard(boardType, playerState)
    LeaderboardSystem.init(playerState)
    return playerState.leaderboards[boardType] or {}
end

-- 获取玩家排名
function LeaderboardSystem.getPlayerRank(boardType, playerName, playerState)
    local board = LeaderboardSystem.getBoard(boardType, playerState)
    for i, entry in ipairs(board) do
        if entry.name == playerName then
            return i
        end
    end
    return nil
end

-- 获取最高分数
function LeaderboardSystem.getHighScore(boardType, playerState)
    local board = LeaderboardSystem.getBoard(boardType, playerState)
    if #board > 0 then
        return board[1].score
    end
    return 0
end

return LeaderboardSystem