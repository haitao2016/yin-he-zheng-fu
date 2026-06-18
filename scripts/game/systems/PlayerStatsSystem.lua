--[[
PlayerStatsSystem.lua - 玩家档案与战绩排行
V2.7 P3-2
追踪玩家整体游戏数据与本地排行榜
]]

local PlayerStatsSystem = {}

local function ensurePlayerState(playerState)
    if not playerState then return nil end
    playerState.playerStats = playerState.playerStats or {}
    local ps = playerState.playerStats
    ps.playerName = ps.playerName or "玩家"
    ps.totalPlayTime = ps.totalPlayTime or 0
    ps.highestWave = ps.highestWave or 0
    ps.totalBattles = ps.totalBattles or 0
    ps.victories = ps.victories or 0
    ps.totalShipsBuilt = ps.totalShipsBuilt or 0
    ps.totalEnemiesKilled = ps.totalEnemiesKilled or 0
    ps.totalResourcesEarned = ps.totalResourcesEarned or 0
    ps.totalResourcesByType = ps.totalResourcesByType or {}
    ps.shipTypesBuilt = ps.shipTypesBuilt or {}
    ps.localRuns = ps.localRuns or {}
    return ps
end

function PlayerStatsSystem.setPlayerName(name)
    if not name or name == "" then return end
    local profile = _G and _G.PlayerProfile
    if profile and profile.setPlayerName then profile:setPlayerName(name) end
    return name
end

function PlayerStatsSystem.getPlayerStats(playerState)
    local ps = ensurePlayerState(playerState)
    if not ps then return nil end
    return {
        playerName = ps.playerName or "玩家",
        totalPlayTime = ps.totalPlayTime or 0,
        highestWave = ps.highestWave or 0,
        totalBattles = ps.totalBattles or 0,
        victories = ps.victories or 0,
        totalShipsBuilt = ps.totalShipsBuilt or 0,
        totalEnemiesKilled = ps.totalEnemiesKilled or 0,
        totalResourcesEarned = ps.totalResourcesEarned or 0,
        totalResourcesByType = ps.totalResourcesByType or {},
        shipTypesBuilt = ps.shipTypesBuilt or {},
    }
end

function PlayerStatsSystem.recordWaveComplete(playerState, waveNum)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    waveNum = tonumber(waveNum) or 0
    if waveNum > (ps.highestWave or 0) then
        ps.highestWave = waveNum
    end
end

function PlayerStatsSystem.recordBattleComplete(playerState, victory, stats)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.totalBattles = (ps.totalBattles or 0) + 1
    if victory then
        ps.victories = (ps.victories or 0) + 1
    end
    if stats then
        if stats.enemiesKilled then
            ps.totalEnemiesKilled = (ps.totalEnemiesKilled or 0) + stats.enemiesKilled
        end
        if stats.shipsLost then
            ps.totalShipsLost = (ps.totalShipsLost or 0) + stats.shipsLost
        end
    end
end

function PlayerStatsSystem.recordShipBuilt(playerState, shipType)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.totalShipsBuilt = (ps.totalShipsBuilt or 0) + 1
    if shipType then
        ps.shipTypesBuilt = ps.shipTypesBuilt or {}
        ps.shipTypesBuilt[shipType] = (ps.shipTypesBuilt[shipType] or 0) + 1
    end
end

function PlayerStatsSystem.recordResourceEarned(playerState, resType, amount)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    amount = tonumber(amount) or 0
    ps.totalResourcesEarned = (ps.totalResourcesEarned or 0) + amount
    if resType then
        ps.totalResourcesByType = ps.totalResourcesByType or {}
        ps.totalResourcesByType[resType] = (ps.totalResourcesByType[resType] or 0) + amount
    end
end

function PlayerStatsSystem.updatePlayTime(playerState, dt)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.totalPlayTime = (ps.totalPlayTime or 0) + (tonumber(dt) or 0)
end

function PlayerStatsSystem.submitRun(playerState, runData)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    local entry = {
        playerName = ps.playerName or "玩家",
        highestWave = runData.highestWave or ps.highestWave or 0,
        totalPlayTime = runData.totalPlayTime or ps.totalPlayTime or 0,
        fleetSize = runData.fleetSize or 0,
        timestamp = runData.timestamp or 0,
    }
    table.insert(ps.localRuns, entry)
    if #ps.localRuns > 100 then table.remove(ps.localRuns, 1) end
end

PlayerStatsSystem.CATEGORIES = {
    WAVE = { key = "highestWave", name = "最高波次", desc = "按最高波次排序" },
    TIME = { key = "totalPlayTime", name = "游戏时长", desc = "按游戏时长排序" },
    FLEET = { key = "fleetSize", name = "舰队规模", desc = "按舰队规模排序" },
}

function PlayerStatsSystem.getLocalLeaderboard(playerState, category, limit)
    local ps = ensurePlayerState(playerState)
    if not ps then return {} end
    limit = tonumber(limit) or 10
    category = category or "WAVE"
    local cat = PlayerStatsSystem.CATEGORIES[category]
    if not cat then return {} end
    local sorted = {}
    for _, run in ipairs(ps.localRuns) do
        table.insert(sorted, run)
    end
    table.sort(sorted, function(a, b)
        local av = a[cat.key] or 0
        local bv = b[cat.key] or 0
        return av > bv
    end)
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(result, sorted[i])
    end
    return result
end

function PlayerStatsSystem.serialize(playerState)
    local ps = ensurePlayerState(playerState)
    if not ps then return nil end
    return {
        playerName = ps.playerName,
        totalPlayTime = ps.totalPlayTime,
        highestWave = ps.highestWave,
        totalBattles = ps.totalBattles,
        victories = ps.victories,
        totalShipsBuilt = ps.totalShipsBuilt,
        totalEnemiesKilled = ps.totalEnemiesKilled,
        totalResourcesEarned = ps.totalResourcesEarned,
        totalResourcesByType = ps.totalResourcesByType,
        shipTypesBuilt = ps.shipTypesBuilt,
        localRuns = ps.localRuns,
    }
end

function PlayerStatsSystem.deserialize(playerState, data)
    if not playerState or not data then return end
    playerState.playerStats = playerState.playerStats or {}
    local ps = playerState.playerStats
    ps.playerName = data.playerName or ps.playerName
    ps.totalPlayTime = data.totalPlayTime or 0
    ps.highestWave = data.highestWave or 0
    ps.totalBattles = data.totalBattles or 0
    ps.victories = data.victories or 0
    ps.totalShipsBuilt = data.totalShipsBuilt or 0
    ps.totalEnemiesKilled = data.totalEnemiesKilled or 0
    ps.totalResourcesEarned = data.totalResourcesEarned or 0
    ps.totalResourcesByType = data.totalResourcesByType or {}
    ps.shipTypesBuilt = data.shipTypesBuilt or {}
    ps.localRuns = data.localRuns or {}
end

return PlayerStatsSystem
