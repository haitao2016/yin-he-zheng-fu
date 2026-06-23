---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/systems/SpectatorSystem.lua
-- V3.0 P3-1: 观战系统
-- ============================================================================

local SpectatorSystem = {}

-- ============================================================================
-- 常量定义
-- ============================================================================
local MAX_SPECTATORS = 10                    -- 最大观战人数
local SPECTATE_COOLDOWN = 60                -- 观战冷却（秒）

-- 预设弹幕
local PRESET_DANMAKU = {
    "加油！",
    "稳住！",
    "太秀了！",
    "666",
    "厉害",
    "期待",
    "必胜！",
    "注意战术",
}

-- ============================================================================
-- 运行时状态
-- ============================================================================
local SpectatorState = {
    currentSpectating = nil,     -- 当前观战中的战斗 { battleId, hostId }
    spectatingHistory = {},      -- 观战历史
    danmakuHistory = {},         -- 弹幕历史
    pendingRequests = {},        -- 待接受的观战请求
    watchCount = 0,              -- 累计观战次数
    cooldownUntil = 0,          -- 冷却结束时间
}

-- ============================================================================
-- 观战请求
-- ============================================================================

--- 发起观战请求
function SpectatorSystem.requestSpectate(hostId, battleId)
    if SpectatorState.currentSpectating then
        return false, "已在观战中"
    end
    
    local now = os.time()
    if now < SpectatorState.cooldownUntil then
        local remaining = SpectatorState.cooldownUntil - now
        return false, string.format("观战冷却中，还需 %d 秒", remaining)
    end
    
    -- 创建请求
    local request = {
        id = "SPECTATE_" .. os.time(),
        hostId = hostId,
        battleId = battleId,
        requesterId = playerState and playerState.id,
        requesterName = playerState and playerState.name,
        timestamp = now,
        status = "PENDING",
    }
    
    SpectatorState.pendingRequests[request.id] = request
    
    -- 这里应该发送到 hostId 请求同意
    -- 模拟直接接受
    return true, "观战请求已发送", request.id
end

--- 接受观战请求
function SpectatorSystem.acceptSpectate(requestId)
    local request = SpectatorState.pendingRequests[requestId]
    if not request then
        return false, "请求不存在"
    end
    
    if request.status ~= "PENDING" then
        return false, "请求已处理"
    end
    
    request.status = "ACCEPTED"
    
    -- 加入观战
    SpectatorState.currentSpectating = {
        battleId = request.battleId,
        hostId = request.hostId,
        startTime = os.time(),
        viewMode = "FOLLOW",  -- FOLLOW 或 FREE
        followedShip = nil,
    }
    
    SpectatorState.watchCount = SpectatorState.watchCount + 1
    
    return true, "已加入观战"
end

--- 拒绝观战请求
function SpectatorSystem.rejectSpectate(requestId)
    local request = SpectatorState.pendingRequests[requestId]
    if not request then
        return false, "请求不存在"
    end
    
    request.status = "REJECTED"
    SpectatorState.pendingRequests[requestId] = nil
    
    return true, "已拒绝观战请求"
end

--- 获取待处理的观战请求
function SpectatorSystem.getPendingRequests()
    local requests = {}
    for _, request in pairs(SpectatorState.pendingRequests) do
        if request.status == "PENDING" then
            table.insert(requests, {
                id = request.id,
                hostId = request.hostId,
                hostName = request.hostName,
                timestamp = request.timestamp,
            })
        end
    end
    return requests
end

-- ============================================================================
-- 观战状态
-- ============================================================================

--- 获取当前观战状态
function SpectatorSystem.getSpectatingState()
    return SpectatorState.currentSpectating
end

--- 是否正在观战
function SpectatorSystem.isSpectating()
    return SpectatorState.currentSpectating ~= nil
end

--- 离开观战
function SpectatorSystem.leaveSpectate()
    if not SpectatorState.currentSpectating then
        return false, "未在观战中"
    end
    
    -- 记录历史
    local spectating = SpectatorState.currentSpectating
    table.insert(SpectatorState.spectatingHistory, {
        battleId = spectating.battleId,
        hostId = spectating.hostId,
        startTime = spectating.startTime,
        endTime = os.time(),
        duration = os.time() - spectating.startTime,
    })
    
    -- 设置冷却
    SpectatorState.cooldownUntil = os.time() + SPECTATE_COOLDOWN
    
    SpectatorState.currentSpectating = nil
    
    return true, "已离开观战"
end

--- 获取观战历史
function SpectatorSystem.getSpectatingHistory(limit)
    limit = limit or 20
    local history = SpectatorState.spectatingHistory
    
    local result = {}
    for i = #history, math.max(1, #history - limit + 1), -1 do
        table.insert(result, history[i])
    end
    
    return result
end

-- ============================================================================
-- 观战视角
-- ============================================================================

--- 切换观战视角
function SpectatorSystem.setViewMode(mode)
    if not SpectatorState.currentSpectating then
        return false, "未在观战中"
    end
    
    if mode ~= "FOLLOW" and mode ~= "FREE" then
        return false, "无效的视角模式"
    end
    
    SpectatorState.currentSpectating.viewMode = mode
    
    return true, "视角已切换为: " .. mode
end

--- 跟随指定舰船
function SpectatorSystem.followShip(shipId)
    if not SpectatorState.currentSpectating then
        return false, "未在观战中"
    end
    
    SpectatorState.currentSpectating.followedShip = shipId
    SpectatorState.currentSpectating.viewMode = "FOLLOW"
    
    return true, "已跟随舰船"
end

--- 跟随己方舰队
function SpectatorSystem.followOwnFleet()
    if not SpectatorState.currentSpectating then
        return false, "未在观战中"
    end
    
    SpectatorState.currentSpectating.followedShip = "OWN_FLEET"
    SpectatorState.currentSpectating.viewMode = "FOLLOW"
    
    return true, "已跟随己方舰队"
end

--- 切换到自由视角
function SpectatorSystem.setFreeView()
    if not SpectatorState.currentSpectating then
        return false, "未在观战中"
    end
    
    SpectatorState.currentSpectating.viewMode = "FREE"
    SpectatorState.currentSpectating.followedShip = nil
    
    return true, "已切换到自由视角"
end

-- ============================================================================
-- 弹幕系统
-- ============================================================================

--- 发送弹幕
function SpectatorSystem.sendDanmaku(message)
    if not SpectatorState.currentSpectating then
        return false, "未在观战中"
    end
    
    -- 验证消息
    if not message or #message == 0 then
        return false, "消息不能为空"
    end
    
    -- 限制消息长度
    if #message > 20 then
        message = message:sub(1, 20)
    end
    
    -- 记录弹幕
    local danmaku = {
        id = #SpectatorState.danmakuHistory + 1,
        senderId = playerState and playerState.id,
        senderName = playerState and playerState.name or "匿名",
        message = message,
        timestamp = os.time(),
        battleId = SpectatorState.currentSpectating.battleId,
    }
    
    table.insert(SpectatorState.danmakuHistory, danmaku)
    
    -- 限制历史数量
    while #SpectatorState.danmakuHistory > 100 do
        table.remove(SpectatorState.danmakuHistory, 1)
    end
    
    return true, "弹幕已发送"
end

--- 获取预设弹幕列表
function SpectatorSystem.getPresetDanmaku()
    return PRESET_DANMAKU
end

--- 获取当前战斗的弹幕
function SpectatorSystem.getCurrentDanmaku()
    if not SpectatorState.currentSpectating then
        return {}
    end
    
    local battleId = SpectatorState.currentSpectating.battleId
    local danmaku = {}
    
    for _, d in ipairs(SpectatorState.danmakuHistory) do
        if d.battleId == battleId then
            table.insert(danmaku, d)
        end
    end
    
    return danmaku
end

--- 发送预设弹幕
function SpectatorSystem.sendPresetDanmaku(index)
    local presets = PRESET_DANMAKU
    if index < 1 or index > #presets then
        return false, "预设弹幕不存在"
    end
    
    return SpectatorSystem.sendDanmaku(presets[index])
end

-- ============================================================================
-- 精彩时刻订阅
-- ============================================================================

local SpectatorHighlights = {
    subscriptions = {},  -- { [friendId] = true }
    highlights = {},    -- { [battleId] = { highlightId, timestamp, clipUrl } }
}

--- 订阅好友精彩时刻
function SpectatorSystem.subscribeHighlights(friendId)
    SpectatorHighlights.subscriptions[friendId] = true
    return true, "已订阅"
end

--- 取消订阅
function SpectatorSystem.unsubscribeHighlights(friendId)
    SpectatorHighlights.subscriptions[friendId] = nil
    return true, "已取消订阅"
end

--- 获取精彩时刻通知
function SpectatorSystem.getHighlightNotifications()
    local notifications = {}
    
    for friendId, _ in pairs(SpectatorHighlights.subscriptions) do
        for battleId, highlight in pairs(SpectatorHighlights.highlights) do
            if highlight.friendId == friendId then
                table.insert(notifications, {
                    friendId = friendId,
                    battleId = battleId,
                    timestamp = highlight.timestamp,
                    clipUrl = highlight.clipUrl,
                })
            end
        end
    end
    
    return notifications
end

-- ============================================================================
-- 统计
-- ============================================================================

--- 获取观战统计
function SpectatorSystem.getStats()
    return {
        totalWatchCount = SpectatorState.watchCount,
        spectatingHistoryCount = #SpectatorState.spectatingHistory,
        danmakuSentCount = #SpectatorState.danmakuHistory,
        cooldownRemaining = math.max(0, SpectatorState.cooldownUntil - os.time()),
    }
end

-- ============================================================================
-- 存档
-- ============================================================================

function SpectatorSystem.saveState()
    if playerState then
        playerState.spectatorState = {
            spectatingHistory = SpectatorState.spectatingHistory,
            watchCount = SpectatorState.watchCount,
            cooldownUntil = SpectatorState.cooldownUntil,
            subscriptions = SpectatorHighlights.subscriptions,
        }
    end
end

function SpectatorSystem.loadState(data)
    if data then
        SpectatorState.spectatingHistory = data.spectatingHistory or {}
        SpectatorState.watchCount = data.watchCount or 0
        SpectatorState.cooldownUntil = data.cooldownUntil or 0
        SpectatorHighlights.subscriptions = data.subscriptions or {}
    end
end

return SpectatorSystem
