---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/systems/FriendSystem.lua -- 好友系统
-- V2.8 P1-4
-- ============================================================================

local FriendSystem = {}

-- ============================================================================
-- 好友状态
-- ============================================================================

local FriendState = {
    friends = {},
    pendingRequests = {},
    blocked = {},
}

-- ============================================================================
-- 好友查询
-- ============================================================================

-- 获取好友列表
function FriendSystem.getFriends()
    local friends = {}
    for id, friend in pairs(FriendState.friends) do
        table.insert(friends, {
            id = id,
            name = friend.name,
            level = friend.level,
            online = friend.online,
            lastOnline = friend.lastOnline,
            isHelping = friend.isHelping,
            helpingBonus = friend.helpingBonus,
        })
    end
    -- 按在线状态和等级排序
    table.sort(friends, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.level > b.level
    end)
    return friends
end

-- 获取待处理请求
function FriendSystem.getPendingRequests()
    return FriendState.pendingRequests
end

-- 获取好友数量
function FriendSystem.getFriendCount()
    local count = 0
    for _ in pairs(FriendState.friends) do
        count = count + 1
    end
    return count
end

-- 检查是否为好友
function FriendSystem.isFriend(playerId)
    return FriendState.friends[playerId] ~= nil
end

-- 检查是否被屏蔽
function FriendSystem.isBlocked(playerId)
    return FriendState.blocked[playerId] == true
end

-- ============================================================================
-- 好友操作
-- ============================================================================

-- 添加好友
function FriendSystem.addFriend(playerId, playerName, playerLevel)
    if playerId == (playerState and playerState.id) then
        return false, "不能添加自己为好友"
    end

    if FriendState.friends[playerId] then
        return false, "已经是好友"
    end

    if FriendState.blocked[playerId] then
        return false, "已屏蔽该玩家"
    end

    -- 发送好友请求（模拟）
    FriendState.pendingRequests[playerId] = {
        fromId = playerId,
        fromName = playerName,
        fromLevel = playerLevel,
        time = os.time(),
    }

    return true, "好友请求已发送"
end

-- 接受好友请求
function FriendSystem.acceptRequest(playerId)
    local request = FriendState.pendingRequests[playerId]
    if not request then
        return false, "请求不存在"
    end

    -- 添加好友
    FriendState.friends[playerId] = {
        name = request.fromName,
        level = request.fromLevel,
        online = false,
        lastOnline = os.time(),
        isHelping = false,
        helpingBonus = 0,
        addedTime = os.time(),
    }

    -- 移除请求
    FriendState.pendingRequests[playerId] = nil

    if NotifyPanel then
        NotifyPanel.push({
            type = "SUCCESS",
            title = "好友添加成功",
            message = request.fromName .. " 已成为你的好友",
        })
    end

    return true, "已添加好友"
end

-- 拒绝好友请求
function FriendSystem.rejectRequest(playerId)
    FriendState.pendingRequests[playerId] = nil
    return true, "已拒绝请求"
end

-- 删除好友
function FriendSystem.removeFriend(playerId)
    FriendState.friends[playerId] = nil
    return true, "已删除好友"
end

-- 屏蔽玩家
function FriendSystem.blockPlayer(playerId)
    FriendState.blocked[playerId] = true
    -- 同时删除好友关系
    FriendState.friends[playerId] = nil
    FriendState.pendingRequests[playerId] = nil
    return true, "已屏蔽玩家"
end

-- 取消屏蔽
function FriendSystem.unblockPlayer(playerId)
    FriendState.blocked[playerId] = nil
    return true, "已取消屏蔽"
end

-- ============================================================================
-- 在线状态
-- ============================================================================

-- 设置在线状态
function FriendSystem.setOnline(online)
    local playerId = playerState and playerState.id
    if not playerId then return end

    -- 更新好友列表中自己的状态
    for _, friend in pairs(FriendState.friends) do
        if friend.name == (playerState and playerState.name) then
            friend.online = online
        end
    end
end

-- 更新好友在线状态（模拟）
function FriendSystem.updateFriendStatus()
    -- 模拟随机在线状态变化
    for id, friend in pairs(FriendState.friends) do
        -- 5% 概率切换状态
        if math.random() < 0.05 then
            friend.online = not friend.online
            if not friend.online then
                friend.lastOnline = os.time()
            end
        end
    end
end

-- ============================================================================
-- 舰队支援
-- ============================================================================

-- 请求支援
function FriendSystem.requestSupport(friendId)
    local friend = FriendState.friends[friendId]
    if not friend then
        return false, "该玩家不是好友"
    end

    -- 计算支援奖励
    local baseBonus = 0.1
    local friendLevel = friend.level or 1
    local bonus = baseBonus * (friendLevel / 10)

    -- 给予支援加成
    friend.isHelping = true
    friend.helpingBonus = bonus

    if NotifyPanel then
        NotifyPanel.push({
            type = "SUCCESS",
            title = "请求已发送",
            message = friend.name .. " 的舰队将前来支援",
        })
    end

    return true, "请求已发送"
end

-- 取消支援
function FriendSystem.cancelSupport(friendId)
    local friend = FriendState.friends[friendId]
    if friend then
        friend.isHelping = false
        friend.helpingBonus = 0
    end
    return true, "支援已取消"
end

-- 获取支援加成
function FriendSystem.getSupportBonus()
    local totalBonus = 0
    for _, friend in pairs(FriendState.friends) do
        if friend.isHelping then
            totalBonus = totalBonus + (friend.helpingBonus or 0)
        end
    end
    return totalBonus
end

-- ============================================================================
-- 战斗邀请
-- ============================================================================

-- 邀请好友战斗
function FriendSystem.inviteToBattle(friendId)
    if not FriendState.friends[friendId] then
        return false, "该玩家不是好友"
    end

    if not FriendState.friends[friendId].online then
        return false, "该好友不在线"
    end

    -- 发送战斗邀请（模拟）
    if NotifyPanel then
        NotifyPanel.push({
            type = "INFO",
            title = "战斗邀请",
            message = "已向 " .. FriendState.friends[friendId].name .. " 发送战斗邀请",
        })
    end

    return true, "邀请已发送"
end

-- ============================================================================
-- 搜索玩家
-- ============================================================================

-- 搜索玩家（模拟）
function FriendSystem.searchPlayers(searchQuery)
    -- 模拟搜索结果
    local results = {}

    -- 添加一些模拟玩家
    local mockPlayers = {
        { id = "PLAYER_101", name = "星际指挥官", level = 25 },
        { id = "PLAYER_102", name = "银河征服者", level = 30 },
        { id = "PLAYER_103", name = "宇宙漫游者", level = 15 },
    }

    for _, player in ipairs(mockPlayers) do
        if searchQuery == "" or string.find(player.name:lower(), searchQuery:lower()) then
            table.insert(results, {
                id = player.id,
                name = player.name,
                level = player.level,
                isFriend = FriendState.friends[player.id] ~= nil,
                isBlocked = FriendState.blocked[player.id] == true,
            })
        end
    end

    return results
end

-- ============================================================================
-- 存档
-- ============================================================================

function FriendSystem.saveState()
    if playerState then
        playerState.friendState = {
            friends = FriendState.friends,
            pendingRequests = FriendState.pendingRequests,
            blocked = FriendState.blocked,
        }
    end
end

function FriendSystem.loadState(data)
    if data then
        FriendState.friends = data.friends or {}
        FriendState.pendingRequests = data.pendingRequests or {}
        FriendState.blocked = data.blocked or {}
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return FriendSystem

-- ============================================================================
-- 快捷信号系统（V3.0 Phase 1 P3-1）
-- 战斗中快速发送战术信号
-- ============================================================================

local SignalSystem = {}

-- 信号定义
SignalSystem.SIGNALS = {
    RALLY = { id = "RALLY", name = "集合", icon = "signal_rally", key = "1" },
    RETREAT = { id = "RETREAT", name = "撤退", icon = "signal_retreat", key = "2" },
    HELP = { id = "HELP", name = "求救", icon = "signal_help", key = "3" },
    TARGET = { id = "TARGET", name = "标记目标", icon = "signal_target", key = "4" },
    ATTACK = { id = "ATTACK", name = "进攻", icon = "signal_attack", key = "5" },
    DEFEND = { id = "DEFEND", name = "防守", icon = "signal_defend", key = "6" },
    WAIT = { id = "WAIT", name = "待命", icon = "signal_wait", key = "7" },
}

-- 信号状态
local SignalState = {
    sentSignals = {},       -- 已发送的信号历史
    receivedSignals = {},   -- 接收到的信号历史
    signalCooldowns = {},   -- 各信号冷却状态
    lastSignalTime = 0,     -- 上次发送信号的时间
}

local SIGNAL_COOLDOWN = 2.0  -- 信号冷却时间（秒）

-- 发送信号
function SignalSystem.sendSignal(signalId, targetPosition)
    local signal = SignalSystem.SIGNALS[signalId]
    if not signal then return false, "无效信号" end

    local now = os.time()
    if now - SignalState.lastSignalTime < SIGNAL_COOLDOWN then
        return false, "信号冷却中"
    end

    local signalData = {
        id = signal.id,
        name = signal.name,
        position = targetPosition,
        timestamp = now,
        fromPlayer = playerState and playerState.name or "指挥官",
    }

    table.insert(SignalState.sentSignals, signalData)
    if #SignalState.sentSignals > 20 then
        table.remove(SignalState.sentSignals, 1)
    end

    SignalState.lastSignalTime = now
    SignalState.signalCooldowns[signalId] = now + SIGNAL_COOLDOWN

    -- 通知 UI 显示信号
    if _G and _G.GameUI then
        _G.GameUI.showSignalNotification(signalData)
    end

    return true, "信号已发送"
end

-- 接收信号
function SignalSystem.receiveSignal(signalData)
    table.insert(SignalState.receivedSignals, signalData)
    if #SignalState.receivedSignals > 20 then
        table.remove(SignalState.receivedSignals, 1)
    end

    -- 通知 UI 显示信号
    if _G and _G.GameUI then
        _G.GameUI.showSignalReceived(signalData)
    end
end

-- 获取信号历史
function SignalSystem.getSignalHistory()
    return {
        sent = SignalState.sentSignals,
        received = SignalState.receivedSignals,
    }
end

-- 检查信号是否在冷却中
function SignalSystem.isOnCooldown(signalId)
    local cooldownEnd = SignalState.signalCooldowns[signalId] or 0
    return os.time() < cooldownEnd
end

-- 获取冷却剩余时间
function SignalSystem.getCooldownRemaining(signalId)
    local cooldownEnd = SignalState.signalCooldowns[signalId] or 0
    local remaining = cooldownEnd - os.time()
    return math.max(0, remaining)
end

-- 获取所有可用信号
function SignalSystem.getAllSignals()
    local signals = {}
    for id, signal in pairs(SignalSystem.SIGNALS) do
        signals[id] = {
            id = signal.id,
            name = signal.name,
            icon = signal.icon,
            key = signal.key,
            onCooldown = SignalSystem.isOnCooldown(signalId),
            cooldownRemaining = SignalSystem.getCooldownRemaining(signalId),
        }
    end
    return signals
end

-- 清除历史
function SignalSystem.clearHistory()
    SignalState.sentSignals = {}
    SignalState.receivedSignals = {}
end

-- 存档
function SignalSystem.saveState()
    if playerState then
        playerState.signalState = {
            sentSignals = SignalState.sentSignals,
            receivedSignals = SignalState.receivedSignals,
        }
    end
end

function SignalSystem.loadState(data)
    if data then
        SignalState.sentSignals = data.sentSignals or {}
        SignalState.receivedSignals = data.receivedSignals or {}
    end
end

return SignalSystem
