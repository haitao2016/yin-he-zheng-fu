-- ============================================================================
-- game/FriendSystem.lua  -- 好友系统
-- ============================================================================

local M = {}

local friends = {}
local pendingRequests = {}
local blockedUsers = {}

local FriendStatus = {
    OFFLINE = "offline",
    ONLINE = "online",
    BUSY = "busy",
    AWAY = "away",
}

function M.GetFriends(playerId)
    if not friends[playerId] then
        return {}
    end
    
    local result = {}
    for friendId, status in pairs(friends[playerId]) do
        table.insert(result, {
            playerId = friendId,
            status = status.status,
            lastOnline = status.lastOnline,
            relationship = status.relationship,
        })
    end
    return result
end

function M.SendFriendRequest(senderId, targetId)
    if senderId == targetId then
        return false, "Cannot add yourself"
    end
    
    if M.AreFriends(senderId, targetId) then
        return false, "Already friends"
    end
    
    if M.IsBlocked(senderId, targetId) then
        return false, "User is blocked"
    end
    
    if not pendingRequests[targetId] then
        pendingRequests[targetId] = {}
    end
    
    if table.contains(pendingRequests[targetId], senderId) then
        return false, "Request already sent"
    end
    
    table.insert(pendingRequests[targetId], senderId)
    
    return true, "Request sent"
end

function M.GetPendingRequests(playerId)
    return pendingRequests[playerId] or {}
end

function M.AcceptFriendRequest(playerId, requesterId)
    if not pendingRequests[playerId] then
        return false, "No pending requests"
    end
    
    local idx = nil
    for i, id in ipairs(pendingRequests[playerId]) do
        if id == requesterId then
            idx = i
            break
        end
    end
    
    if not idx then
        return false, "Request not found"
    end
    
    table.remove(pendingRequests[playerId], idx)
    
    if not friends[playerId] then
        friends[playerId] = {}
    end
    if not friends[requesterId] then
        friends[requesterId] = {}
    end
    
    friends[playerId][requesterId] = {
        status = "offline",
        lastOnline = os.time(),
        relationship = "friend",
    }
    friends[requesterId][playerId] = {
        status = "offline",
        lastOnline = os.time(),
        relationship = "friend",
    }
    
    return true, "Friend request accepted"
end

function M.RejectFriendRequest(playerId, requesterId)
    if not pendingRequests[playerId] then
        return false, "No pending requests"
    end
    
    local idx = nil
    for i, id in ipairs(pendingRequests[playerId]) do
        if id == requesterId then
            idx = i
            break
        end
    end
    
    if not idx then
        return false, "Request not found"
    end
    
    table.remove(pendingRequests[playerId], idx)
    
    return true, "Friend request rejected"
end

function M.RemoveFriend(playerId, friendId)
    if not friends[playerId] or not friends[playerId][friendId] then
        return false, "Not friends"
    end
    
    friends[playerId][friendId] = nil
    if friends[friendId] then
        friends[friendId][playerId] = nil
    end
    
    return true, "Friend removed"
end

function M.AreFriends(playerId1, playerId2)
    return friends[playerId1] and friends[playerId1][playerId2] ~= nil
end

function M.BlockUser(playerId, targetId)
    if playerId == targetId then
        return false, "Cannot block yourself"
    end
    
    if M.IsBlocked(playerId, targetId) then
        return false, "Already blocked"
    end
    
    if not blockedUsers[playerId] then
        blockedUsers[playerId] = {}
    end
    
    table.insert(blockedUsers[playerId], targetId)
    
    M.RemoveFriend(playerId, targetId)
    
    return true, "User blocked"
end

function M.UnblockUser(playerId, targetId)
    if not blockedUsers[playerId] then
        return false, "No blocked users"
    end
    
    local idx = nil
    for i, id in ipairs(blockedUsers[playerId]) do
        if id == targetId then
            idx = i
            break
        end
    end
    
    if not idx then
        return false, "User not blocked"
    end
    
    table.remove(blockedUsers[playerId], idx)
    
    return true, "User unblocked"
end

function M.IsBlocked(playerId, targetId)
    return blockedUsers[playerId] and table.contains(blockedUsers[playerId], targetId)
end

function M.GetBlockedUsers(playerId)
    return blockedUsers[playerId] or {}
end

function M.UpdateFriendStatus(playerId, status)
    if not friends[playerId] then return end
    
    for friendId, friendData in pairs(friends[playerId]) do
        if friends[friendId] and friends[friendId][playerId] then
            friends[friendId][playerId].status = status
            if status == "offline" then
                friends[friendId][playerId].lastOnline = os.time()
            end
        end
    end
end

function M.SendGift(playerId, friendId, giftType, amount)
    if not M.AreFriends(playerId, friendId) then
        return false, "Not friends"
    end
    
    return true, "Gift sent"
end

function M.GetFriendStatus(friendId)
    if not friends[friendId] then
        return FriendStatus.OFFLINE
    end
    
    return FriendStatus.ONLINE
end

function M.GetFriendStatuses()
    return FriendStatus
end

return M