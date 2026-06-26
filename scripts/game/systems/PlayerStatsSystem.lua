--[[
PlayerStatsSystem.lua - 玩家档案与战绩排行
V3.0 Phase 2 P1-2
追踪玩家整体游戏数据与本地排行榜，含战绩雷达图数据
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
    -- V3.0 新增统计字段
    ps.campaignChaptersCompleted = ps.campaignChaptersCompleted or {}
    ps.campaignStagesCompleted = ps.campaignStagesCompleted or {}
    ps.achievementsUnlocked = ps.achievementsUnlocked or {}
    ps.roguelikeWins = ps.roguelikeWins or 0
    ps.roguelikeLosses = ps.roguelikeLosses or 0
    ps.totalDamageDealt = ps.totalDamageDealt or 0
    ps.totalDamageTaken = ps.totalDamageTaken or 0
    ps.totalShipsLost = ps.totalShipsLost or 0
    ps.totalHealing = ps.totalHealing or 0
    ps.highestDamageInBattle = ps.highestDamageInBattle or 0
    ps.longestBattle = ps.longestBattle or 0
    ps.fastestBattle = ps.fastestBattle or 999999
    ps.favoriteShip = ps.favoriteShip or nil
    ps.favoriteCommander = ps.favoriteCommander or nil
    ps.seasonPoints = ps.seasonPoints or 0
    ps.seasonRank = ps.seasonRank or 0
    ps.totalCreditsEarned = ps.totalCreditsEarned or 0
    ps.totalTechResearched = ps.totalTechResearched or 0
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
        if stats.damageDealt then
            ps.totalDamageDealt = (ps.totalDamageDealt or 0) + stats.damageDealt
            if stats.damageDealt > (ps.highestDamageInBattle or 0) then
                ps.highestDamageInBattle = stats.damageDealt
            end
        end
        if stats.damageTaken then
            ps.totalDamageTaken = (ps.totalDamageTaken or 0) + stats.damageTaken
        end
        if stats.healing then
            ps.totalHealing = (ps.totalHealing or 0) + stats.healing
        end
        if stats.battleDuration then
            if stats.battleDuration > (ps.longestBattle or 0) then
                ps.longestBattle = stats.battleDuration
            end
            if stats.battleDuration < (ps.fastestBattle or 999999) and victory then
                ps.fastestBattle = stats.battleDuration
            end
        end
        if stats.isRoguelike then
            if victory then
                ps.roguelikeWins = (ps.roguelikeWins or 0) + 1
            else
                ps.roguelikeLosses = (ps.roguelikeLosses or 0) + 1
            end
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

function PlayerStatsSystem.recordCampaignChapterComplete(playerState, chapterId)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.campaignChaptersCompleted = ps.campaignChaptersCompleted or {}
    ps.campaignChaptersCompleted[chapterId] = true
end

function PlayerStatsSystem.recordCampaignStageComplete(playerState, stageId)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.campaignStagesCompleted = ps.campaignStagesCompleted or {}
    ps.campaignStagesCompleted[stageId] = true
end

function PlayerStatsSystem.recordAchievementUnlocked(playerState, achievementId)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.achievementsUnlocked = ps.achievementsUnlocked or {}
    ps.achievementsUnlocked[achievementId] = true
end

function PlayerStatsSystem.recordCreditsEarned(playerState, amount)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.totalCreditsEarned = (ps.totalCreditsEarned or 0) + (tonumber(amount) or 0)
end

function PlayerStatsSystem.recordTechResearched(playerState)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.totalTechResearched = (ps.totalTechResearched or 0) + 1
end

function PlayerStatsSystem.setFavoriteCommander(playerState, commanderId)
    local ps = ensurePlayerState(playerState)
    if not ps then return end
    ps.favoriteCommander = commanderId
end

-- V3.0 新增：战绩雷达图数据
-- 返回用于雷达图展示的标准化数据（0-100范围）
function PlayerStatsSystem.getRadarChartData(playerState)
    local ps = ensurePlayerState(playerState)
    if not ps then
        return {
            combat = 0, economy = 0, exploration = 0, survival = 0, efficiency = 0, versatility = 0
        }
    end

    -- 计算各维度得分
    local totalBattles = ps.totalBattles or 0
    local victories = ps.victories or 0
    local totalShipsBuilt = ps.totalShipsBuilt or 0
    local totalEnemiesKilled = ps.totalEnemiesKilled or 0
    local highestWave = ps.highestWave or 0
    local totalTechResearched = ps.totalTechResearched or 0

    -- 战斗维度：胜率 + 击杀效率
    local winRate = totalBattles > 0 and (victories / totalBattles) or 0
    local killPerBattle = totalBattles > 0 and (totalEnemiesKilled / totalBattles) or 0
    local combat = math.min(100, (winRate * 60 + math.min(killPerBattle / 50, 1) * 40))

    -- 经济维度：资源获取 + 舰船建造
    local resourceScore = math.min(ps.totalResourcesEarned / 100000, 1) * 50
    local buildScore = math.min(totalShipsBuilt / 500, 1) * 50
    local economy = math.min(100, resourceScore + buildScore)

    -- 探索维度：最高波次 + 科技研究
    local waveScore = math.min(highestWave / 200, 1) * 60
    local techScore = math.min(totalTechResearched / 30, 1) * 40
    local exploration = math.min(100, waveScore + techScore)

    -- 生存维度：存活率 + 战损比
    local survivalRate = totalBattles > 0 and (1 - (ps.totalShipsLost or 0) / math.max(totalShipsBuilt, 1)) or 1
    survivalRate = math.max(0, math.min(survivalRate, 1))
    local damageRatio = (ps.totalDamageTaken or 1) > 0 and ((ps.totalDamageDealt or 0) / (ps.totalDamageTaken or 1)) or 1
    local survival = math.min(100, (survivalRate * 50 + math.min(damageRatio / 3, 1) * 50))

    -- 效率维度：战斗时长效率
    local avgBattleTime = totalBattles > 0 and ((ps.totalPlayTime or 0) / totalBattles) or 300
    local efficiency = math.max(0, 100 - (avgBattleTime - 60) / 6)
    efficiency = math.min(100, math.max(0, efficiency))

    -- 通用性维度：舰船类型多样性 + 成就解锁
    local shipTypeCount = 0
    for _ in pairs(ps.shipTypesBuilt or {}) do shipTypeCount = shipTypeCount + 1 end
    local shipDiversity = math.min(shipTypeCount / 10, 1) * 50
    local achievementCount = 0
    for _ in pairs(ps.achievementsUnlocked or {}) do achievementCount = achievementCount + 1 end
    local achievementScore = math.min(achievementCount / 50, 1) * 50
    local versatility = math.min(100, shipDiversity + achievementScore)

    return {
        combat = math.floor(combat),
        economy = math.floor(economy),
        exploration = math.floor(exploration),
        survival = math.floor(survival),
        efficiency = math.floor(efficiency),
        versatility = math.floor(versatility),
    }
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
    KILLS = { key = "totalEnemiesKilled", name = "总击杀", desc = "按总击杀数排序" },
    DAMAGE = { key = "totalDamageDealt", name = "总伤害", desc = "按总伤害排序" },
    WINRATE = { key = "winRate", name = "胜率", desc = "按胜率排序" },
    TECH = { key = "totalTechResearched", name = "科技研究", desc = "按已研究科技数排序" },
    RESOURCES = { key = "totalResourcesEarned", name = "资源获取", desc = "按总资源获取排序" },
}

-- 获取排行榜数据（支持自定义排序键）
function PlayerStatsSystem.getLeaderboardByStat(playerState, statKey, limit)
    local ps = ensurePlayerState(playerState)
    if not ps then return {} end
    limit = tonumber(limit) or 10
    local sorted = {}
    for _, run in ipairs(ps.localRuns) do
        table.insert(sorted, run)
    end
    table.sort(sorted, function(a, b)
        local av = a[statKey] or 0
        local bv = b[statKey] or 0
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
        -- V3.0 新增字段
        campaignChaptersCompleted = ps.campaignChaptersCompleted,
        campaignStagesCompleted = ps.campaignStagesCompleted,
        achievementsUnlocked = ps.achievementsUnlocked,
        roguelikeWins = ps.roguelikeWins,
        roguelikeLosses = ps.roguelikeLosses,
        totalDamageDealt = ps.totalDamageDealt,
        totalDamageTaken = ps.totalDamageTaken,
        totalShipsLost = ps.totalShipsLost,
        totalHealing = ps.totalHealing,
        highestDamageInBattle = ps.highestDamageInBattle,
        longestBattle = ps.longestBattle,
        fastestBattle = ps.fastestBattle,
        favoriteShip = ps.favoriteShip,
        favoriteCommander = ps.favoriteCommander,
        seasonPoints = ps.seasonPoints,
        seasonRank = ps.seasonRank,
        totalCreditsEarned = ps.totalCreditsEarned,
        totalTechResearched = ps.totalTechResearched,
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
    -- V3.0 新增字段
    ps.campaignChaptersCompleted = data.campaignChaptersCompleted or {}
    ps.campaignStagesCompleted = data.campaignStagesCompleted or {}
    ps.achievementsUnlocked = data.achievementsUnlocked or {}
    ps.roguelikeWins = data.roguelikeWins or 0
    ps.roguelikeLosses = data.roguelikeLosses or 0
    ps.totalDamageDealt = data.totalDamageDealt or 0
    ps.totalDamageTaken = data.totalDamageTaken or 0
    ps.totalShipsLost = data.totalShipsLost or 0
    ps.totalHealing = data.totalHealing or 0
    ps.highestDamageInBattle = data.highestDamageInBattle or 0
    ps.longestBattle = data.longestBattle or 0
    ps.fastestBattle = data.fastestBattle or 999999
    ps.favoriteShip = data.favoriteShip
    ps.favoriteCommander = data.favoriteCommander
    ps.seasonPoints = data.seasonPoints or 0
    ps.seasonRank = data.seasonRank or 0
    ps.totalCreditsEarned = data.totalCreditsEarned or 0
    ps.totalTechResearched = data.totalTechResearched or 0
end

return PlayerStatsSystem
