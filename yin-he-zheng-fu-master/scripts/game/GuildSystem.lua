-- ============================================================================
-- game/GuildSystem.lua  -- 公会系统
-- ============================================================================

local M = {}

local guilds = {}
local playerGuilds = {}
local nextGuildId = 1

local GuildRanks = {
    FOUNDER = {
        label = "创始人",
        permissions = { "invite", "kick", "promote", "demote", "change_name", "disband", "manage_roles", "claim_rewards" },
        maxMembers = 0,
    },
    ADMIN = {
        label = "管理员",
        permissions = { "invite", "kick", "promote", "demote", "manage_roles" },
        maxMembers = 0,
    },
    OFFICER = {
        label = "官员",
        permissions = { "invite", "manage_roles" },
        maxMembers = 0,
    },
    MEMBER = {
        label = "成员",
        permissions = { "claim_rewards" },
        maxMembers = 0,
    },
}

local GuildLevels = {
    [1] = { requiredXP = 0, maxMembers = 10, bonus = { resource = 0.1 } },
    [2] = { requiredXP = 1000, maxMembers = 15, bonus = { resource = 0.15 } },
    [3] = { requiredXP = 3000, maxMembers = 20, bonus = { resource = 0.2 } },
    [4] = { requiredXP = 6000, maxMembers = 30, bonus = { resource = 0.25 } },
    [5] = { requiredXP = 10000, maxMembers = 50, bonus = { resource = 0.3 } },
}

local GuildAchievements = {
    FIRST_VICTORY = { label = "初战告捷", description = "获得第一场公会战斗胜利", rewardXP = 100 },
    RECRUITMENT = { label = "招兵买马", description = "招募10名成员", rewardXP = 200 },
    LEVEL_3 = { label = "茁壮成长", description = "公会升级到3级", rewardXP = 500 },
    WAR_CHAMPION = { label = "战争冠军", description = "获得公会战争冠军", rewardXP = 1000 },
}

function M.CreateGuild(playerId, name, description)
    local guild = {
        id = string.format("guild_%d", nextGuildId),
        name = name or "未命名公会",
        description = description or "",
        founderId = playerId,
        createdAt = os.time(),
        level = 1,
        xp = 0,
        members = {
            [playerId] = {
                rank = "FOUNDER",
                joinedAt = os.time(),
                contributions = 0,
                lastActive = os.time(),
            }
        },
        achievements = {},
        rewards = {},
        settings = {
            public = true,
            requireApproval = false,
            autoAccept = false,
        },
        treasury = { credits = 0, resources = {} },
        warStats = { wins = 0, losses = 0, draws = 0 },
    }
    
    nextGuildId = nextGuildId + 1
    guilds[guild.id] = guild
    playerGuilds[playerId] = guild.id
    
    return guild
end

function M.GetGuild(guildId)
    return guilds[guildId]
end

function M.GetPlayerGuild(playerId)
    local guildId = playerGuilds[playerId]
    if not guildId then return nil end
    return guilds[guildId]
end

function M.InvitePlayer(guildId, inviterId, targetPlayerId)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    local inviter = guild.members[inviterId]
    if not inviter then return false, "Inviter not in guild" end
    
    if not M.HasPermission(inviterId, guildId, "invite") then
        return false, "No permission to invite"
    end
    
    if playerGuilds[targetPlayerId] then
        return false, "Player already in a guild"
    end
    
    local memberCount = M.GetMemberCount(guildId)
    local maxMembers = GuildLevels[guild.level].maxMembers
    if memberCount >= maxMembers then
        return false, "Guild is full"
    end
    
    guild.members[targetPlayerId] = {
        rank = "MEMBER",
        joinedAt = os.time(),
        contributions = 0,
        lastActive = os.time(),
    }
    playerGuilds[targetPlayerId] = guildId
    
    return true, "Invitation accepted"
end

function M.KickPlayer(guildId, kickerId, targetPlayerId)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    local kicker = guild.members[kickerId]
    if not kicker then return false, "Kicker not in guild" end
    
    if kickerId == targetPlayerId then
        return false, "Cannot kick yourself"
    end
    
    if guild.members[targetPlayerId].rank == "FOUNDER" then
        return false, "Cannot kick founder"
    end
    
    if not M.HasPermission(kickerId, guildId, "kick") then
        return false, "No permission to kick"
    end
    
    guild.members[targetPlayerId] = nil
    playerGuilds[targetPlayerId] = nil
    
    return true, "Player kicked"
end

function M.PromotePlayer(guildId, promoterId, targetPlayerId, newRank)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    local promoter = guild.members[promoterId]
    if not promoter then return false, "Promoter not in guild" end
    
    if not M.HasPermission(promoterId, guildId, "promote") then
        return false, "No permission to promote"
    end
    
    if not GuildRanks[newRank] then
        return false, "Invalid rank"
    end
    
    guild.members[targetPlayerId].rank = newRank
    
    return true, "Player promoted"
end

function M.DemotePlayer(guildId, demoterId, targetPlayerId, newRank)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    local demoter = guild.members[demoterId]
    if not demoter then return false, "Demoter not in guild" end
    
    if not M.HasPermission(demoterId, guildId, "demote") then
        return false, "No permission to demote"
    end
    
    if guild.members[targetPlayerId].rank == "FOUNDER" then
        return false, "Cannot demote founder"
    end
    
    if not GuildRanks[newRank] then
        return false, "Invalid rank"
    end
    
    guild.members[targetPlayerId].rank = newRank
    
    return true, "Player demoted"
end

function M.HasPermission(playerId, guildId, permission)
    local guild = guilds[guildId]
    if not guild then return false end
    
    local member = guild.members[playerId]
    if not member then return false end
    
    local rank = GuildRanks[member.rank]
    if not rank then return false end
    
    return table.contains(rank.permissions, permission)
end

function M.GetMemberCount(guildId)
    local guild = guilds[guildId]
    if not guild then return 0 end
    
    local count = 0
    for _ in pairs(guild.members) do
        count = count + 1
    end
    return count
end

function M.AddContribution(playerId, guildId, amount)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    local member = guild.members[playerId]
    if not member then return false, "Member not found" end
    
    member.contributions = member.contributions + amount
    guild.xp = guild.xp + amount
    
    M.CheckLevelUp(guildId)
    M.CheckAchievements(guildId)
    
    return true, amount
end

function M.CheckLevelUp(guildId)
    local guild = guilds[guildId]
    if not guild then return end
    
    local currentLevel = guild.level
    local nextLevel = currentLevel + 1
    
    if GuildLevels[nextLevel] and guild.xp >= GuildLevels[nextLevel].requiredXP then
        guild.level = nextLevel
        M.AddGuildAchievement(guildId, "LEVEL_" .. nextLevel)
    end
end

function M.CheckAchievements(guildId)
    local guild = guilds[guildId]
    if not guild then return end
    
    for achievementId, achievement in pairs(GuildAchievements) do
        if not guild.achievements[achievementId] then
            local unlocked = M._checkAchievementCondition(guild, achievementId)
            if unlocked then
                M.AddGuildAchievement(guildId, achievementId)
            end
        end
    end
end

function M._checkAchievementCondition(guild, achievementId)
    if achievementId == "FIRST_VICTORY" then
        return guild.warStats.wins >= 1
    elseif achievementId == "RECRUITMENT" then
        return M.GetMemberCount(guild.id) >= 10
    elseif achievementId == "LEVEL_3" then
        return guild.level >= 3
    elseif achievementId == "WAR_CHAMPION" then
        return guild.warStats.wins >= 10
    end
    return false
end

function M.AddGuildAchievement(guildId, achievementId)
    local guild = guilds[guildId]
    if not guild then return end
    
    local achievement = GuildAchievements[achievementId]
    if not achievement then return end
    
    guild.achievements[achievementId] = {
        unlockedAt = os.time(),
        claimed = false,
    }
    
    guild.xp = guild.xp + (achievement.rewardXP or 0)
end

function M.ClaimAchievementReward(playerId, guildId, achievementId)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    if not guild.achievements[achievementId] then
        return false, "Achievement not unlocked"
    end
    
    if guild.achievements[achievementId].claimed then
        return false, "Reward already claimed"
    end
    
    if not M.HasPermission(playerId, guildId, "claim_rewards") then
        return false, "No permission to claim rewards"
    end
    
    guild.achievements[achievementId].claimed = true
    
    return true, GuildAchievements[achievementId]
end

function M.GetGuildBonus(guildId)
    local guild = guilds[guildId]
    if not guild then return {} end
    
    return GuildLevels[guild.level].bonus or {}
end

function M.ChangeGuildName(guildId, changerId, newName)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    if not M.HasPermission(changerId, guildId, "change_name") then
        return false, "No permission to change name"
    end
    
    guild.name = newName
    return true, "Name changed"
end

function M.DisbandGuild(guildId, playerId)
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    if guild.members[playerId].rank ~= "FOUNDER" then
        return false, "Only founder can disband"
    end
    
    for memberId, _ in pairs(guild.members) do
        playerGuilds[memberId] = nil
    end
    
    guilds[guildId] = nil
    
    return true, "Guild disbanded"
end

function M.LeaveGuild(playerId)
    local guildId = playerGuilds[playerId]
    if not guildId then return false, "Not in a guild" end
    
    local guild = guilds[guildId]
    if not guild then return false, "Guild not found" end
    
    if guild.members[playerId].rank == "FOUNDER" then
        return false, "Founder cannot leave, must disband"
    end
    
    guild.members[playerId] = nil
    playerGuilds[playerId] = nil
    
    return true, "Left guild"
end

function M.GetAllGuilds()
    local result = {}
    for id, guild in pairs(guilds) do
        table.insert(result, guild)
    end
    table.sort(result, function(a, b) return a.level > b.level end)
    return result
end

function M.SearchGuilds(searchTerm)
    local result = {}
    for id, guild in pairs(guilds) do
        if guild.settings.public then
            if not searchTerm or string.find(string.lower(guild.name), string.lower(searchTerm)) then
                table.insert(result, guild)
            end
        end
    end
    table.sort(result, function(a, b) return a.level > b.level end)
    return result
end

function M.UpdateMemberActivity(playerId)
    local guildId = playerGuilds[playerId]
    if not guildId then return end
    
    local guild = guilds[guildId]
    if not guild then return end
    
    if guild.members[playerId] then
        guild.members[playerId].lastActive = os.time()
    end
end

function M.GetGuildRanks()
    return GuildRanks
end

function M.GetGuildLevels()
    return GuildLevels
end

function M.GetGuildAchievements()
    return GuildAchievements
end

return M