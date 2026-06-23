-- ============================================================================
-- game/SeasonSystem.lua  -- 赛季系统
-- ============================================================================

local M = {}

local currentSeason = nil
local playerProgress = {}
local seasonRewards = {}

local SeasonConfig = {
    durationDays = 28,
    rewardTiers = {
        { minScore = 0, rewards = { credits = 100, xp = 500 } },
        { minScore = 1000, rewards = { credits = 500, xp = 2000, blueprint = "starter" } },
        { minScore = 5000, rewards = { credits = 2000, xp = 5000, shipSkin = "golden" } },
        { minScore = 10000, rewards = { credits = 5000, xp = 10000, commander = "legendary" } },
        { minScore = 25000, rewards = { credits = 10000, xp = 25000, title = "champion" } },
    },
    leaderboardSize = 100,
}

local SeasonPhases = {
    PRE_SEASON = "pre_season",
    ACTIVE = "active",
    POST_SEASON = "post_season",
    OFF_SEASON = "off_season",
}

local SeasonTypes = {
    RANKED = {
        label = "排位赛季",
        description = "竞争激烈的排位赛季",
        scoreMultiplier = 1.5,
        rewardMultiplier = 2.0,
    },
    CASUAL = {
        label = "休闲赛季",
        description = "轻松愉快的休闲赛季",
        scoreMultiplier = 1.0,
        rewardMultiplier = 1.0,
    },
    EVENT = {
        label = "活动赛季",
        description = "限时活动赛季",
        scoreMultiplier = 2.0,
        rewardMultiplier = 1.5,
        durationDays = 14,
    },
}

function M.Init()
    currentSeason = M.CreateNewSeason()
    playerProgress = {}
    seasonRewards = {}
end

function M.CreateNewSeason(seasonType)
    local typeConfig = SeasonTypes[seasonType] or SeasonTypes.CASUAL
    local duration = typeConfig.durationDays or SeasonConfig.durationDays
    
    return {
        id = string.format("season_%d", os.time()),
        type = seasonType or "CASUAL",
        typeConfig = typeConfig,
        startTime = os.time(),
        endTime = os.time() + duration * 24 * 60 * 60,
        phase = SeasonPhases.ACTIVE,
        leaderboard = {},
        seasonPass = {
            tiers = M.GenerateSeasonPassTiers(),
            rewards = {},
        },
    }
end

function M.GenerateSeasonPassTiers()
    local tiers = {}
    for i = 1, 50 do
        local rewards = {}
        if i % 10 == 0 then
            table.insert(rewards, { type = "rare", item = "ship_skin", value = string.format("season_%d", i) })
        elseif i % 5 == 0 then
            table.insert(rewards, { type = "epic", item = "credits", value = i * 200 })
        else
            table.insert(rewards, { type = "common", item = "xp", value = i * 100 })
        end
        table.insert(tiers, {
            level = i,
            requiredXP = i * 1000,
            rewards = rewards,
            unlocked = false,
        })
    end
    return tiers
end

function M.GetCurrentSeason()
    return currentSeason
end

function M.UpdateSeasonPhase()
    if not currentSeason then return end
    
    local now = os.time()
    if now < currentSeason.startTime then
        currentSeason.phase = SeasonPhases.PRE_SEASON
    elseif now > currentSeason.endTime then
        currentSeason.phase = SeasonPhases.POST_SEASON
    else
        currentSeason.phase = SeasonPhases.ACTIVE
    end
end

function M.GetSeasonPhase()
    if not currentSeason then return SeasonPhases.OFF_SEASON end
    return currentSeason.phase
end

function M.AddPlayerScore(playerId, score, reason)
    if not currentSeason or currentSeason.phase ~= SeasonPhases.ACTIVE then
        return false, "Season not active"
    end
    
    if not playerProgress[playerId] then
        playerProgress[playerId] = {
            score = 0,
            seasonPassXP = 0,
            seasonPassLevel = 1,
            unlockedTiers = {},
            claimedRewards = {},
            matchesPlayed = 0,
            wins = 0,
            achievements = {},
        }
    end
    
    local multiplier = currentSeason.typeConfig.scoreMultiplier or 1.0
    local finalScore = math.floor(score * multiplier)
    
    playerProgress[playerId].score = playerProgress[playerId].score + finalScore
    playerProgress[playerId].seasonPassXP = playerProgress[playerId].seasonPassXP + score
    
    M.UpdateSeasonPass(playerId)
    M.UpdateLeaderboard(playerId)
    
    return true, finalScore
end

function M.UpdateSeasonPass(playerId)
    local progress = playerProgress[playerId]
    if not progress then return end
    
    local pass = currentSeason.seasonPass
    local currentXP = progress.seasonPassXP
    local currentLevel = progress.seasonPassLevel
    
    for _, tier in ipairs(pass.tiers) do
        if tier.level > currentLevel and currentXP >= tier.requiredXP then
            progress.seasonPassLevel = tier.level
            table.insert(progress.unlockedTiers, tier.level)
        end
    end
end

function M.UpdateLeaderboard(playerId)
    local progress = playerProgress[playerId]
    if not progress then return end
    
    local leaderboard = currentSeason.leaderboard
    local found = false
    
    for i, entry in ipairs(leaderboard) do
        if entry.playerId == playerId then
            entry.score = progress.score
            found = true
            break
        end
    end
    
    if not found then
        table.insert(leaderboard, {
            playerId = playerId,
            score = progress.score,
            rank = 0,
        })
    end
    
    table.sort(leaderboard, function(a, b) return a.score > b.score end)
    
    for i, entry in ipairs(leaderboard) do
        entry.rank = i
        if i > SeasonConfig.leaderboardSize then
            table.remove(leaderboard, i)
            break
        end
    end
end

function M.GetPlayerProgress(playerId)
    return playerProgress[playerId] or {
        score = 0,
        seasonPassXP = 0,
        seasonPassLevel = 1,
        unlockedTiers = {},
        claimedRewards = {},
        matchesPlayed = 0,
        wins = 0,
        achievements = {},
    }
end

function M.ClaimReward(playerId, tierLevel)
    local progress = playerProgress[playerId]
    if not progress then return false, "No progress found" end
    
    if not table.contains(progress.unlockedTiers, tierLevel) then
        return false, "Tier not unlocked"
    end
    
    if table.contains(progress.claimedRewards, tierLevel) then
        return false, "Reward already claimed"
    end
    
    local pass = currentSeason.seasonPass
    for _, tier in ipairs(pass.tiers) do
        if tier.level == tierLevel then
            table.insert(progress.claimedRewards, tierLevel)
            return true, tier.rewards
        end
    end
    
    return false, "Tier not found"
end

function M.GetLeaderboard(count)
    if not currentSeason then return {} end
    local result = {}
    for i = 1, math.min(count or 10, #currentSeason.leaderboard) do
        table.insert(result, currentSeason.leaderboard[i])
    end
    return result
end

function M.GetPlayerRank(playerId)
    if not currentSeason then return 0 end
    
    for i, entry in ipairs(currentSeason.leaderboard) do
        if entry.playerId == playerId then
            return i
        end
    end
    
    return #currentSeason.leaderboard + 1
end

function M.CalculateTierRewards(playerId)
    local progress = playerProgress[playerId]
    if not progress then return {} end
    
    local rewards = {}
    local score = progress.score
    
    for _, tier in ipairs(SeasonConfig.rewardTiers) do
        if score >= tier.minScore then
            for k, v in pairs(tier.rewards) do
                if not rewards[k] or rewards[k] < v then
                    rewards[k] = v
                end
            end
        end
    end
    
    return rewards
end

function M.EndSeason()
    if not currentSeason then return end
    
    currentSeason.phase = SeasonPhases.POST_SEASON
    
    for playerId, progress in pairs(playerProgress) do
        local rewards = M.CalculateTierRewards(playerId)
        seasonRewards[playerId] = rewards
    end
    
    return seasonRewards
end

function M.GetSeasonRewards(playerId)
    return seasonRewards[playerId] or {}
end

function M.GetSeasonTypes()
    return SeasonTypes
end

function M.GetSeasonPhases()
    return SeasonPhases
end

function M.GetSeasonConfig()
    return SeasonConfig
end

return M