---@diagnostic disable: assign-type-mismatch, return-type-mismatch
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

-- ============================================================================
-- V3.0 P1-1: 好友系统 2.0
-- 好友助战/友谊赛/礼物系统/好友战报
-- ============================================================================

local FriendSystemV2 = {}

-- ============================================================================
-- 常量定义
-- ============================================================================
local MAX_FRIENDS = 50                    -- 最大好友数
local DAILY_GIFT_COOLDOWN = 86400         -- 每日礼物冷却（24小时）
local FRIENDSHIP_GIFT_BONUS = 5           -- 每次礼物增加的友谊值
local MAX_FRIENDSHIP = 100                -- 最大友谊值
local FRIENDSHIP_TITLE_THRESHOLD = 50      -- 解锁称号的友谊值
local HELP_COOLDOWN = 86400               -- 助战冷却（24小时）
local FRIENDSHIP_REWARD_THRESHOLD = {      -- 友谊值奖励阈值
    { threshold = 20, bonus = 0.05 },     -- 友谊值20: 5%战斗加成
    { threshold = 50, bonus = 0.10 },     -- 友谊值50: 10%战斗加成
    { threshold = 80, bonus = 0.15 },     -- 友谊值80: 15%战斗加成
    { threshold = 100, bonus = 0.20 },    -- 友谊值100: 20%战斗加成
}

-- ============================================================================
-- V2 状态
-- ============================================================================
local V2State = {
    friendship = {},          -- { [friendId] = { value = 0~100, lastGiftTime = 0, lastHelpTime = 0, legendShips = {} } }
    battleHistory = {},       -- { [friendId] = { recentBattles = {}, lastSeen = 0 } }
    friendTitles = {},        -- { [friendId] = "称号" }
    giftsReceived = {},       -- { [friendId] = timestamp } 收到的礼物记录
    giftsSent = {},           -- { [friendId] = timestamp } 送出的礼物记录
}

-- ============================================================================
-- 友谊值系统
-- ============================================================================

--- 获取友谊值
function FriendSystemV2.getFriendship(friendId)
    local data = V2State.friendship[friendId]
    return data and data.value or 0
end

--- 增加友谊值
function FriendSystemV2.addFriendship(friendId, amount)
    if not V2State.friendship[friendId] then
        V2State.friendship[friendId] = { value = 0, lastGiftTime = 0, lastHelpTime = 0, legendShips = {} }
    end
    local data = V2State.friendship[friendId]
    data.value = math.min(MAX_FRIENDSHIP, (data.value or 0) + amount)
    
    -- 检查称号解锁
    if data.value >= FRIENDSHIP_TITLE_THRESHOLD and not V2State.friendTitles[friendId] then
        V2State.friendTitles[friendId] = FriendSystemV2.generateTitle(data.value)
    end
    
    return data.value
end

--- 获取友谊加成
function FriendSystemV2.getFriendshipBonus()
    local totalBonus = 0
    for friendId, data in pairs(V2State.friendship) do
        local value = data.value or 0
        for _, reward in ipairs(FRIENDSHIP_REWARD_THRESHOLD) do
            if value >= reward.threshold then
                totalBonus = totalBonus + reward.bonus
            end
        end
    end
    return math.min(totalBonus, 0.5)  -- 最多50%加成
end

--- 生成称号
function FriendSystemV2.generateTitle(friendshipValue)
    if friendshipValue >= 100 then
        return "生死之交"
    elseif friendshipValue >= 80 then
        return "挚友"
    elseif friendshipValue >= 50 then
        return "好友"
    elseif friendshipValue >= 20 then
        return "熟识"
    else
        return "新识"
    end
end

--- 获取好友称号
function FriendSystemV2.getFriendTitle(friendId)
    return V2State.friendTitles[friendId] or "新识"
end

-- ============================================================================
-- 礼物系统
-- ============================================================================

--- 检查是否可以送礼
function FriendSystemV2.canSendGift(friendId)
    local data = V2State.friendship[friendId]
    if not data then return true, "可以送礼" end
    
    local now = os.time()
    local cooldownEnd = (data.lastGiftTime or 0) + DAILY_GIFT_COOLDOWN
    
    if now < cooldownEnd then
        local remaining = cooldownEnd - now
        return false, string.format("送礼冷却中，还需 %d 秒", remaining)
    end
    return true, "可以送礼"
end

--- 发送礼物（无消耗）
function FriendSystemV2.sendGift(friendId)
    local canSend, msg = FriendSystemV2.canSendGift(friendId)
    if not canSend then
        return false, msg
    end
    
    -- 初始化
    if not V2State.friendship[friendId] then
        V2State.friendship[friendId] = { value = 0, lastGiftTime = 0, lastHelpTime = 0, legendShips = {} }
    end
    
    -- 记录送礼
    local data = V2State.friendship[friendId]
    data.lastGiftTime = os.time()
    V2State.giftsSent[friendId] = os.time()
    
    -- 增加友谊值
    local newValue = FriendSystemV2.addFriendship(friendId, FRIENDSHIP_GIFT_BONUS)
    
    return true, string.format("礼物已送达！友谊值 +%d，当前: %d", FRIENDSHIP_GIFT_BONUS, newValue)
end

--- 检查是否收到礼物
function FriendSystemV2.hasReceivedGift(friendId)
    return V2State.giftsReceived[friendId] ~= nil
end

--- 标记收到礼物
function FriendSystemV2.markGiftReceived(friendId)
    V2State.giftsReceived[friendId] = os.time()
end

-- ============================================================================
-- 好友助战系统
-- ============================================================================

--- 检查是否可以请求助战
function FriendSystemV2.canRequestHelp(friendId)
    local data = V2State.friendship[friendId]
    if not data then return true, "可以请求" end
    
    local now = os.time()
    local cooldownEnd = (data.lastHelpTime or 0) + HELP_COOLDOWN
    
    if now < cooldownEnd then
        local remaining = cooldownEnd - now
        return false, string.format("助战冷却中，还需 %d 秒", remaining)
    end
    return true, "可以请求"
end

--- 请求好友助战（获得传奇舰船）
function FriendSystemV2.requestHelp(friendId)
    local canRequest, msg = FriendSystemV2.canRequestHelp(friendId)
    if not canRequest then
        return false, msg
    end
    
    -- 初始化
    if not V2State.friendship[friendId] then
        V2State.friendship[friendId] = { value = 0, lastGiftTime = 0, lastHelpTime = 0, legendShips = {} }
    end
    
    local data = V2State.friendship[friendId]
    data.lastHelpTime = os.time()
    
    -- 生成传奇舰船（基于好友历史最强舰船）
    local legendShip = {
        id = "LEGEND_" .. friendId .. "_" .. os.time(),
        shipType = FriendSystemV2.getRandomLegendShipType(),
        name = FriendSystemV2.getLegendShipName(data.value),
        level = math.random(10, 20),
        atkBonus = 0.1 + (data.value / 100) * 0.2,  -- 友谊值越高加成越高
        hpBonus = 0.1 + (data.value / 100) * 0.2,
        canJoinBattle = true,
        expirationTime = os.time() + 3600,  -- 1小时后过期
    }
    
    table.insert(data.legendShips, legendShip)
    
    -- 限制最多3艘传奇舰船
    while #data.legendShips > 3 do
        table.remove(data.legendShips, 1)
    end
    
    return true, string.format("获得传奇舰船「%s」！", legendShip.name)
end

--- 获取好友传奇舰船
function FriendSystemV2.getLegendShips(friendId)
    local data = V2State.friendship[friendId]
    if not data then return {} end
    
    -- 过滤过期舰船
    local now = os.time()
    local validShips = {}
    for _, ship in ipairs(data.legendShips) do
        if ship.expirationTime > now then
            table.insert(validShips, ship)
        end
    end
    
    return validShips
end

--- 使用传奇舰船参战
function FriendSystemV2.useLegendShip(friendId, shipId)
    local ships = FriendSystemV2.getLegendShips(friendId)
    for i, ship in ipairs(ships) do
        if ship.id == shipId then
            -- 标记为已使用（消耗）
            table.remove(ships, i)
            return true, ship
        end
    end
    return false, nil
end

--- 获取随机传奇舰船类型
function FriendSystemV2.getRandomLegendShipType()
    local types = { "FRIGATE", "DESTROYER", "BATTLECRUISER", "CARRIER" }
    return types[math.random(#types)]
end

--- 根据友谊值生成舰船名称
function FriendSystemV2.getLegendShipName(friendshipValue)
    local prefixes = { "传奇", "英雄", "无畏", "荣耀", "永恒" }
    local suffixes = { "先锋", "守护", "利刃", "风暴", "之光" }
    local prefix = prefixes[math.random(#prefixes)]
    local suffix = suffixes[math.random(#suffixes)]
    
    if friendshipValue >= 80 then
        return prefix .. "旗舰"
    elseif friendshipValue >= 50 then
        return prefix .. suffix
    else
        return suffix .. "战舰"
    end
end

-- ============================================================================
-- 友谊赛系统
-- ============================================================================

local FriendshipMatchState = {
    currentMatch = nil,      -- 当前进行的友谊赛
    matchHistory = {},       -- 历史记录
    pendingChallenges = {},   -- 待接受的挑战
}

--- 发起友谊赛挑战
function FriendSystemV2.challengeFriend(friendId)
    if FriendshipMatchState.currentMatch then
        return false, "已有进行中的友谊赛"
    end
    
    if not FriendSystem.isFriend(friendId) then
        return false, "该玩家不是好友"
    end
    
    -- 创建挑战
    local challenge = {
        id = "CHALLENGE_" .. os.time(),
        challengerId = playerState and playerState.id,
        challengerName = playerState and playerState.name,
        challengedId = friendId,
        challengedName = FriendSystem.friends[friendId] and FriendSystem.friends[friendId].name,
        shipLimit = 5,  -- 限定5艘舰船
        timestamp = os.time(),
        status = "PENDING",
    }
    
    FriendshipMatchState.pendingChallenges[friendId] = challenge
    
    return true, challenge
end

--- 接受友谊赛挑战
function FriendSystemV2.acceptChallenge(challengeId)
    for friendId, challenge in pairs(FriendshipMatchState.pendingChallenges) do
        if challenge.id == challengeId then
            challenge.status = "ACCEPTED"
            FriendshipMatchState.currentMatch = challenge
            return true, challenge
        end
    end
    return false, "挑战不存在"
end

--- 拒绝友谊赛挑战
function FriendSystemV2.rejectChallenge(challengeId)
    for friendId, challenge in pairs(FriendshipMatchState.pendingChallenges) do
        if challenge.id == challengeId then
            FriendshipMatchState.pendingChallenges[friendId] = nil
            return true, "已拒绝挑战"
        end
    end
    return false, "挑战不存在"
end

--- 开始友谊赛
function FriendSystemV2.startMatch()
    if not FriendshipMatchState.currentMatch then
        return false, "没有进行中的友谊赛"
    end
    
    FriendshipMatchState.currentMatch.status = "IN_PROGRESS"
    return true, FriendshipMatchState.currentMatch
end

--- 结束友谊赛
function FriendSystemV2.endMatch(result, challengerScore, challengedScore)
    if not FriendshipMatchState.currentMatch then
        return false, "没有进行中的友谊赛"
    end
    
    local match = FriendshipMatchState.currentMatch
    match.status = "COMPLETED"
    match.result = result  -- "CHALLENGER_WIN", "CHALLENGED_WIN", "DRAW"
    match.challengerScore = challengerScore
    match.challengedScore = challengedScore
    match.endTime = os.time()
    
    -- 记录历史（不计入排名）
    table.insert(FriendshipMatchState.matchHistory, match)
    
    -- 限制历史记录数量
    while #FriendshipMatchState.matchHistory > 20 do
        table.remove(FriendshipMatchState.matchHistory, 1)
    end
    
    FriendshipMatchState.currentMatch = nil
    
    -- 根据结果增加友谊值
    if result == "CHALLENGER_WIN" then
        FriendSystemV2.addFriendship(match.challengedId, 3)  -- 输方友谊值+3（激励再战）
    elseif result == "CHALLENGED_WIN" then
        FriendSystemV2.addFriendship(match.challengerId, 3)
    end
    
    return true, match
end

--- 获取友谊赛历史
function FriendSystemV2.getMatchHistory()
    return FriendshipMatchState.matchHistory
end

--- 获取待接受挑战
function FriendSystemV2.getPendingChallenges()
    return FriendshipMatchState.pendingChallenges
end

-- ============================================================================
-- 好友战报系统
-- ============================================================================

--- 记录好友战报
function FriendSystemV2.recordBattleReport(friendId, report)
    if not V2State.battleHistory[friendId] then
        V2State.battleHistory[friendId] = {
            recentBattles = {},
            lastSeen = os.time(),
        }
    end
    
    local data = V2State.battleHistory[friendId]
    table.insert(data.recentBattles, {
        id = "REPORT_" .. os.time(),
        waveReached = report.waveReached,
        enemiesDefeated = report.enemiesDefeated,
        timestamp = os.time(),
        isVictory = report.isVictory,
        difficulty = report.difficulty,
    })
    
    -- 限制记录数量
    while #data.recentBattles > 5 do
        table.remove(data.recentBattles, 1)
    end
    
    data.lastSeen = os.time()
end

--- 获取好友最近战报
function FriendSystemV2.getFriendBattleReports(friendId)
    local data = V2State.battleHistory[friendId]
    if not data then return {} end
    return data.recentBattles
end

--- 获取好友战报摘要
function FriendSystemV2.getFriendBattleSummary(friendId)
    local reports = FriendSystemV2.getFriendBattleReports(friendId)
    if #reports == 0 then
        return { totalBattles = 0, victories = 0, avgWaves = 0 }
    end
    
    local victories = 0
    local totalWaves = 0
    for _, report in ipairs(reports) do
        if report.isVictory then victories = victories + 1 end
        totalWaves = totalWaves + report.waveReached
    end
    
    return {
        totalBattles = #reports,
        victories = victories,
        avgWaves = math.floor(totalWaves / #reports),
    }
end

-- ============================================================================
-- 完整好友信息获取
-- ============================================================================

--- 获取完整好友信息（包含 V2 数据）
function FriendSystemV2.getFullFriendInfo(friendId)
    local friend = FriendSystem.friends[friendId]
    if not friend then return nil end
    
    local friendship = FriendSystemV2.getFriendship(friendId)
    local title = FriendSystemV2.getFriendTitle(friendId)
    local legendShips = FriendSystemV2.getLegendShips(friendId)
    local canGift, giftMsg = FriendSystemV2.canSendGift(friendId)
    local canHelp, helpMsg = FriendSystemV2.canRequestHelp(friendId)
    local battleSummary = FriendSystemV2.getFriendBattleSummary(friendId)
    
    return {
        id = friendId,
        name = friend.name,
        level = friend.level,
        online = friend.online,
        lastOnline = friend.lastOnline,
        friendship = friendship,
        title = title,
        legendShips = legendShips,
        canGift = canGift,
        canHelp = canHelp,
        battleSummary = battleSummary,
    }
end

--- 获取所有好友完整信息
function FriendSystemV2.getAllFriendsInfo()
    local friends = {}
    for friendId, _ in pairs(FriendSystem.friends or {}) do
        table.insert(friends, FriendSystemV2.getFullFriendInfo(friendId))
    end
    
    -- 按友谊值排序
    table.sort(friends, function(a, b)
        return (a.friendship or 0) > (b.friendship or 0)
    end)
    
    return friends
end

-- ============================================================================
-- 存档
-- ============================================================================

function FriendSystemV2.saveState()
    if playerState then
        playerState.friendSystemV2 = {
            friendship = V2State.friendship,
            battleHistory = V2State.battleHistory,
            friendTitles = V2State.friendTitles,
            giftsReceived = V2State.giftsReceived,
            giftsSent = V2State.giftsSent,
            matchHistory = FriendshipMatchState.matchHistory,
        }
    end
end

function FriendSystemV2.loadState(data)
    if data then
        V2State.friendship = data.friendship or {}
        V2State.battleHistory = data.battleHistory or {}
        V2State.friendTitles = data.friendTitles or {}
        V2State.giftsReceived = data.giftsReceived or {}
        V2State.giftsSent = data.giftsSent or {}
        FriendshipMatchState.matchHistory = data.matchHistory or {}
    end
end

return FriendSystemV2
