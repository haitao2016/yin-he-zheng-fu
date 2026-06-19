---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/SteamIntegration.lua -- Steam 集成系统
-- V2.8 P1-6
-- ============================================================================

local SteamIntegration = {}

-- ============================================================================
-- Steam 状态
-- ============================================================================

local SteamState = {
    initialized = false,
    isSteamDeck = false,
    userId = nil,
    userName = "Player",
    achievements = {},
    stats = {},
    leaderboards = {},
}

-- Steam 成就定义
STEAM_ACHIEVEMENTS = {
    {
        id = "FIRST_STEP",
        name = "第一步",
        desc = "完成第一场战斗",
        icon = "ach_first_step",
    },
    {
        id = "DESTROYER_OF_WORLDS",
        name = "世界毁灭者",
        desc = "击败第一个 Boss",
        icon = "ach_boss_01",
    },
    {
        id = "FLEET_COMMANDER",
        name = "舰队指挥官",
        desc = "建造 10 艘舰船",
        icon = "ach_fleet_01",
    },
    {
        id = "ECONOMIC_MASTER",
        name = "经济大师",
        desc = "积累 10000 星币",
        icon = "ach_economy_01",
    },
    {
        id = "TECH_WHIZ",
        name = "科技达人",
        desc = "完成 10 项科技研究",
        icon = "ach_tech_01",
    },
    {
        id = "ENDURANCE",
        name = "耐久",
        desc = "达到波次 50",
        icon = "ach_wave_50",
    },
    {
        id = "LEGENDARY",
        name = "传奇",
        desc = "达到波次 100",
        icon = "ach_wave_100",
    },
    {
        id = "SUPER_BOSS_SLAYER",
        name = "超级Boss猎手",
        desc = "击败超级 Boss",
        icon = "ach_super_boss",
    },
    {
        id = "CAMPAIGN_COMPLETE",
        name = "战役完成",
        desc = "完成第一章战役",
        icon = "ach_campaign",
    },
    {
        id = "COLLECTOR",
        name = "收藏家",
        desc = "收集 5 种不同舰船",
        icon = "ach_collector",
    },
    {
        id = "GUILD_MASTER",
        name = "公会大师",
        desc = "创建公会并升至 3 级",
        icon = "ach_guild_01",
    },
    {
        id = "SOCIAL_BUTTERFLY",
        name = "社交达人",
        desc = "添加 5 个好友",
        icon = "ach_social",
    },
    {
        id = "PERFECTIONIST",
        name = "完美主义者",
        desc = "无伤通关任意关卡",
        icon = "ach_perfect",
    },
    {
        id = "SPEEDRUNNER",
        name = "速通者",
        desc = "在 5 分钟内达到波次 20",
        icon = "ach_speedrun",
    },
    {
        id = "RICHEST",
        name = "首富",
        desc = "积累 100000 星币",
        icon = "ach_rich",
    },
}

-- ============================================================================
-- 初始化
-- ============================================================================

function SteamIntegration.initialize()
    -- 检查是否是 Steam 版本
    SteamState.initialized = true

    -- 检测是否在 Steam Deck 上运行
    SteamState.isSteamDeck = SteamIntegration.checkSteamDeck()

    -- 加载存档的成就和统计
    if playerState and playerState.steamAchievements then
        SteamState.achievements = playerState.steamAchievements
    end
    if playerState and playerState.steamStats then
        SteamState.stats = playerState.steamStats
    end

    return SteamState.initialized
end

-- 检测 Steam Deck
function SteamIntegration.checkSteamDeck()
    -- 简单检测，可以通过环境变量或平台特定API增强
    return false  -- 默认返回非 Steam Deck
end

-- ============================================================================
-- 成就系统
-- ============================================================================

-- 解锁成就
function SteamIntegration.unlockAchievement(achievementId)
    if not SteamState.initialized then return false end

    -- 检查是否已解锁
    if SteamState.achievements[achievementId] then
        return false, "成就已解锁"
    end

    -- 解锁成就
    SteamState.achievements[achievementId] = {
        unlocked = true,
        unlockTime = os.time(),
    }

    -- 保存到存档
    if playerState then
        playerState.steamAchievements = SteamState.achievements
    end

    -- 显示通知
    local achievement = nil
    for _, ach in ipairs(STEAM_ACHIEVEMENTS) do
        if ach.id == achievementId then achievement = ach; break end
    end

    if achievement and NotifyPanel then
        NotifyPanel.push({
            type = "ACHIEVEMENT",
            title = "🏆 成就解锁: " .. achievement.name,
            message = achievement.desc,
            icon = achievement.icon,
        })
    end

    return true, "成就已解锁"
end

-- 检查成就是否已解锁
function SteamIntegration.isAchievementUnlocked(achievementId)
    return SteamState.achievements[achievementId] ~= nil
end

-- 获取所有成就
function SteamIntegration.getAchievements()
    local achievements = {}
    local unlockedCount = 0

    for _, ach in ipairs(STEAM_ACHIEVEMENTS) do
        local isUnlocked = SteamState.achievements[ach.id] ~= nil
        if isUnlocked then unlockedCount = unlockedCount + 1 end

        table.insert(achievements, {
            id = ach.id,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
            unlocked = isUnlocked,
            unlockTime = isUnlocked and SteamState.achievements[ach.id].unlockTime or nil,
        })
    end

    return {
        achievements = achievements,
        totalCount = #STEAM_ACHIEVEMENTS,
        unlockedCount = unlockedCount,
    }
end

-- 批量检查成就条件
function SteamIntegration.checkAchievements()
    local stats = SteamIntegration.getStats()

    -- 第一步
    if (stats.battlesWon or 0) >= 1 then
        SteamIntegration.unlockAchievement("FIRST_STEP")
    end

    -- 毁灭者
    if (stats.bossesDefeated or 0) >= 1 then
        SteamIntegration.unlockAchievement("DESTROYER_OF_WORLDS")
    end

    -- 超级Boss猎手
    if (stats.superBossesDefeated or 0) >= 1 then
        SteamIntegration.unlockAchievement("SUPER_BOSS_SLAYER")
    end

    -- 耐久
    if (stats.highestWave or 0) >= 50 then
        SteamIntegration.unlockAchievement("ENDURANCE")
    end

    -- 传奇
    if (stats.highestWave or 0) >= 100 then
        SteamIntegration.unlockAchievement("LEGENDARY")
    end

    -- 经济大师
    if (stats.totalCreditsEarned or 0) >= 10000 then
        SteamIntegration.unlockAchievement("ECONOMIC_MASTER")
    end

    -- 首富
    if (stats.totalCreditsEarned or 0) >= 100000 then
        SteamIntegration.unlockAchievement("RICHEST")
    end

    -- 科技达人
    if (stats.techsResearched or 0) >= 10 then
        SteamIntegration.unlockAchievement("TECH_WHIZ")
    end

    -- 收藏家
    if (stats.shipTypesOwned or 0) >= 5 then
        SteamIntegration.unlockAchievement("COLLECTOR")
    end
end

-- ============================================================================
-- 统计系统
-- ============================================================================

-- 更新统计
function SteamIntegration.setStat(statName, value)
    SteamState.stats[statName] = value
    if playerState then
        playerState.steamStats = SteamState.stats
    end
end

-- 增加统计值
function SteamIntegration.addStat(statName, increment)
    local current = SteamState.stats[statName] or 0
    SteamIntegration.setStat(statName, current + increment)
end

-- 获取统计
function SteamIntegration.getStat(statName)
    return SteamState.stats[statName] or 0
end

-- 获取所有统计
function SteamIntegration.getStats()
    return SteamState.stats
end

-- 更新战斗相关统计
function SteamIntegration.onBattleEnd(victory, wave, enemiesKilled, noDamage)
    if victory then
        SteamIntegration.addStat("battlesWon", 1)
    end
    SteamIntegration.addStat("battlesPlayed", 1)

    if wave > (SteamState.stats.highestWave or 0) then
        SteamIntegration.setStat("highestWave", wave)
    end

    SteamIntegration.addStat("enemiesKilled", enemiesKilled or 0)

    if noDamage then
        SteamIntegration.unlockAchievement("PERFECTIONIST")
    end

    -- 检查成就
    SteamIntegration.checkAchievements()
end

-- 更新 Boss 击杀统计
function SteamIntegration.onBossDefeated(isSuper)
    if isSuper then
        SteamIntegration.addStat("superBossesDefeated", 1)
    else
        SteamIntegration.addStat("bossesDefeated", 1)
    end
    SteamIntegration.addStat("bossesDefeated", 1)
    SteamIntegration.checkAchievements()
end

-- 更新经济统计
function SteamIntegration.onCreditsEarned(amount)
    SteamIntegration.addStat("totalCreditsEarned", amount)
    SteamIntegration.checkAchievements()
end

-- 更新舰船统计
function SteamIntegration.onShipBuilt(shipType)
    SteamIntegration.addStat("shipsBuilt", 1)

    -- 记录舰船类型
    local typesOwned = SteamState.stats.shipTypesOwned or {}
    if not typesOwned[shipType] then
        typesOwned[shipType] = true
        SteamIntegration.setStat("shipTypesOwned", typesOwned)
        SteamIntegration.checkAchievements()
    end
end

-- 更新科技统计
function SteamIntegration.onTechResearched()
    SteamIntegration.addStat("techsResearched", 1)
    SteamIntegration.checkAchievements()
end

-- ============================================================================
-- 云存档
-- ============================================================================

-- 保存云存档
function SteamIntegration.saveCloud()
    -- 模拟云存档保存
    local saveData = {
        playerState = playerState,
        timestamp = os.time(),
    }

    -- 在实际 Steam 实现中，这里会调用 SteamFile 云存档API
    return true, saveData
end

-- 加载云存档
function SteamIntegration.loadCloud()
    -- 模拟云存档加载
    -- 在实际 Steam 实现中，这里会调用 SteamFile 云存档API
    return nil  -- 返回 nil 表示使用本地存档
end

-- ============================================================================
-- 排行榜
-- ============================================================================

-- 上报分数
function SteamIntegration.submitScore(leaderboardId, score)
    SteamState.leaderboards[leaderboardId] = score
    -- 在实际 Steam 实现中，这里会调用 SteamUserStats API
    return true
end

-- 获取排行榜
function SteamIntegration.getLeaderboard(leaderboardId)
    -- 模拟排行榜数据
    local entries = {}
    for i = 1, 10 do
        table.insert(entries, {
            rank = i,
            score = (11 - i) * 1000,
            name = "Player_" .. i,
        })
    end
    return entries
end

-- ============================================================================
-- 导出
-- ============================================================================

return SteamIntegration

-- ============================================================================
-- V3.0 P2-3: Steam 成就与云存档
-- Steam 排行榜/云存档/统计数据/创意工坊
-- ============================================================================

local SteamIntegrationV2 = {}

-- ============================================================================
-- Steam 成就扩展定义（V3.0 新成就）
-- ============================================================================
STEAM_ACHIEVEMENTS_V2 = {
    -- V3.0 新增成就
    { id = "GALAXY_LEGEND", name = "银河传奇", desc = "完成第8章战役", icon = "ach_galaxy_legend" },
    { id = "MUTANT_COLLECTOR", name = "变异收藏家", desc = "收集5种不同词缀的变异舰船", icon = "ach_mutant" },
    { id = "LEGACY_MASTER", name = "遗产大师", desc = "解锁全部文明遗产路线", icon = "ach_legacy" },
    { id = "FORMATION_EXPERT", name = "阵型专家", desc = "使用自定义阵型赢得10场战斗", icon = "ach_formation" },
    { id = "BLUEPRINT_MASTER", name = "蓝图大师", desc = "收藏5套战术蓝图", icon = "ach_blueprint" },
    { id = "REPLAY_WARRIOR", name = "回放战士", desc = "观看10次战斗回放", icon = "ach_replay" },
    { id = "GUILD_WARRIOR", name = "公会战士", desc = "赢得5场公会战", icon = "ach_guild_war" },
    { id = "SEASON_CHAMPION", name = "赛季冠军", desc = "赛季积分达到10000", icon = "ach_season" },
    { id = "FRIENDSHIP_GURU", name = "友谊大师", desc = "与好友达到满友谊值", icon = "ach_friendship" },
    { id = "BOND_MASTER", name = "羁绊大师", desc = "与任意角色羁绊达到满级", icon = "ach_bond" },
    { id = "AI_BATTLE_MASTER", name = "AI对战大师", desc = "在AI竞技场中获得10连胜", icon = "ach_ai" },
    { id = "SPECTATOR", name = "观战者", desc = "观战好友战斗10次", icon = "ach_spectator" },
    { id = "PERFORMANCE_OPT", name = "性能优化者", desc = "游戏运行超过1小时无卡顿", icon = "ach_performance" },
    { id = "SPEED_DEMON", name = "速度恶魔", desc = "3分钟内达到波次50", icon = "ach_speed" },
    { id = "NO_LOSS_STREAK", name = "零败传说", desc = "连胜100场战斗", icon = "ach_noloss" },
}

-- Steam 排行榜定义
STEAM_LEADERBOARDS = {
    { id = "HIGHEST_WAVE", name = "最高波次", sortMethod = "DESC", displayType = "NUMERIC" },
    { id = "TOTAL_BATTLES", name = "总战斗数", sortMethod = "DESC", displayType = "NUMERIC" },
    { id = "VICTORIES", name = "胜利次数", sortMethod = "DESC", displayType = "NUMERIC" },
    { id = "SEASON_POINTS", name = "赛季积分", sortMethod = "DESC", displayType = "NUMERIC" },
    { id = "CLEAR_TIME", name = "最快通关", sortMethod = "ASC", displayType = "SECONDS" },
}

-- ============================================================================
-- V2 运行时状态
-- ============================================================================
local V2State = {
    cloudSaveEnabled = false,
    lastCloudSync = 0,
    cloudSyncInterval = 300,  -- 5分钟同步一次
    leaderboardCache = {},    -- 排行榜缓存
    leaderboardCacheTime = 0,
    statistics = {
        totalPlayTime = 0,
        totalKills = 0,
        totalDeaths = 0,
        totalCreditsEarned = 0,
        totalDistanceTraveled = 0,
    },
    workshopItems = {},       -- 创意工坊物品
}

-- ============================================================================
-- Steam 成就 V2 系统
-- ============================================================================

--- 解锁成就（V2 扩展）
function SteamIntegrationV2.unlockAchievementV2(achievementId)
    -- 检查是否是 V2 成就
    for _, ach in ipairs(STEAM_ACHIEVEMENTS_V2) do
        if ach.id == achievementId then
            if SteamState.achievements[achievementId] then
                return false, "成就已解锁"
            end
            
            SteamState.achievements[achievementId] = {
                unlocked = true,
                unlockTime = os.time(),
            }
            
            -- 同步到 Steam API（如果可用）
            SteamIntegrationV2.syncToSteamAPI("achievement", achievementId)
            
            if NotifyPanel then
                NotifyPanel.push({
                    type = "ACHIEVEMENT",
                    title = "Steam 成就解锁",
                    message = ach.name .. " - " .. ach.desc,
                })
            end
            
            return true, "成就解锁成功"
        end
    end
    
    return false, "成就不存在"
end

--- 检查成就条件
function SteamIntegrationV2.checkAchievementConditions()
    -- 波次相关成就
    if playerState and playerState.waveNumber then
        if playerState.waveNumber >= 50 then
            SteamIntegrationV2.unlockAchievementV2("ENDURANCE")
        end
        if playerState.waveNumber >= 100 then
            SteamIntegrationV2.unlockAchievementV2("LEGENDARY")
        end
        if playerState.waveNumber >= 50 and playerState.totalPlayTime and playerState.totalPlayTime < 180 then
            SteamIntegrationV2.unlockAchievementV2("SPEED_DEMON")
        end
    end
    
    -- 连胜相关成就
    if playerState and playerState.winStreak and playerState.winStreak >= 100 then
        SteamIntegrationV2.unlockAchievementV2("NO_LOSS_STREAK")
    end
end

--- 获取所有已解锁成就
function SteamIntegrationV2.getUnlockedAchievements()
    local achievements = {}
    
    -- V1 成就
    for _, ach in ipairs(STEAM_ACHIEVEMENTS) do
        local state = SteamState.achievements[ach.id]
        table.insert(achievements, {
            id = ach.id,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
            unlocked = state and state.unlocked or false,
            unlockTime = state and state.unlockTime or nil,
            version = 1,
        })
    end
    
    -- V2 成就
    for _, ach in ipairs(STEAM_ACHIEVEMENTS_V2) do
        local state = SteamState.achievements[ach.id]
        table.insert(achievements, {
            id = ach.id,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
            unlocked = state and state.unlocked or false,
            unlockTime = state and state.unlockTime or nil,
            version = 2,
        })
    end
    
    return achievements
end

-- ============================================================================
-- Steam 排行榜系统
-- ============================================================================

--- 提交排行榜分数
function SteamIntegrationV2.submitLeaderboardScore(leaderboardId, score)
    -- 检查是否是有效的排行榜
    local validLeaderboard = false
    for _, lb in ipairs(STEAM_LEADERBOARDS) do
        if lb.id == leaderboardId then
            validLeaderboard = true
            break
        end
    end
    
    if not validLeaderboard then
        return false, "排行榜不存在"
    end
    
    -- 缓存分数
    if not V2State.leaderboardCache[leaderboardId] then
        V2State.leaderboardCache[leaderboardId] = {}
    end
    
    local myEntry = {
        score = score,
        timestamp = os.time(),
        rank = -1,  -- 待服务器分配
    }
    
    -- 如果有更好的成绩则更新
    local existing = V2State.leaderboardCache[leaderboardId].myEntry
    if not existing or (leaderboardId == "CLEAR_TIME" and score < existing.score) 
        or (leaderboardId ~= "CLEAR_TIME" and score > existing.score) then
        V2State.leaderboardCache[leaderboardId].myEntry = myEntry
    end
    
    -- 模拟提交到 Steam
    SteamIntegrationV2.syncToSteamAPI("leaderboard", leaderboardId, score)
    
    return true, "分数已提交"
end

--- 获取排行榜
function SteamIntegrationV2.getLeaderboard(leaderboardId, limit)
    limit = limit or 100
    
    -- 检查缓存
    local cacheTime = V2State.leaderboardCacheTime or 0
    if os.time() - cacheTime < 60 and V2State.leaderboardCache[leaderboardId] then
        return V2State.leaderboardCache[leaderboardId].entries
    end
    
    -- 模拟排行榜数据
    local entries = {}
    
    -- 生成模拟数据
    for i = 1, math.min(limit, 20) do
        table.insert(entries, {
            rank = i,
            score = (20 - i) * 1000 + math.random(100),
            name = "Player_" .. string.format("%05d", math.random(10000)),
            isMe = false,
        })
    end
    
    -- 添加我的成绩
    local myEntry = V2State.leaderboardCache[leaderboardId] and V2State.leaderboardCache[leaderboardId].myEntry
    if myEntry then
        -- 计算排名
        local myRank = 1
        for i, entry in ipairs(entries) do
            if leaderboardId == "CLEAR_TIME" then
                if myEntry.score > entry.score then
                    myRank = i
                    break
                end
            else
                if myEntry.score < entry.score then
                    myRank = i
                    break
                end
            end
            myRank = i + 1
        end
        
        -- 插入我的成绩
        table.insert(entries, myRank, {
            rank = myRank,
            score = myEntry.score,
            name = "Me",
            isMe = true,
        })
        
        -- 重新编号
        for i = 1, #entries do
            entries[i].rank = i
        end
    end
    
    -- 缓存结果
    if not V2State.leaderboardCache[leaderboardId] then
        V2State.leaderboardCache[leaderboardId] = {}
    end
    V2State.leaderboardCache[leaderboardId].entries = entries
    V2State.leaderboardCacheTime = os.time()
    
    return entries
end

-- ============================================================================
-- 云存档系统
-- ============================================================================

--- 启用云存档
function SteamIntegrationV2.enableCloudSave()
    V2State.cloudSaveEnabled = true
    return true
end

--- 禁用云存档
function SteamIntegrationV2.disableCloudSave()
    V2State.cloudSaveEnabled = false
    return true
end

--- 检查云存档状态
function SteamIntegrationV2.isCloudSaveEnabled()
    return V2State.cloudSaveEnabled
end

--- 上传存档到云端
function SteamIntegrationV2.uploadSaveToCloud(saveData)
    if not V2State.cloudSaveEnabled then
        return false, "云存档未启用"
    end
    
    -- 序列化存档数据
    local serialized = SteamIntegrationV2.serializeSaveData(saveData)
    
    -- 模拟上传到 Steam Cloud
    local success = true  -- 实际实现需要 Steam API
    
    if success then
        V2State.lastCloudSync = os.time()
        
        -- 记录上传时间
        if playerState then
            playerState.lastCloudSync = os.time()
        end
        
        print("[SteamIntegrationV2] 存档已上传到云端")
        return true, "上传成功"
    end
    
    return false, "上传失败"
end

--- 从云端下载存档
function SteamIntegrationV2.downloadSaveFromCloud()
    if not V2State.cloudSaveEnabled then
        return nil, "云存档未启用"
    end
    
    -- 模拟从 Steam Cloud 下载
    local cloudData = playerState and playerState.cloudSaveData
    
    if cloudData then
        local deserialized = SteamIntegrationV2.deserializeSaveData(cloudData)
        V2State.lastCloudSync = os.time()
        print("[SteamIntegrationV2] 存档已从云端下载")
        return deserialized, "下载成功"
    end
    
    return nil, "云端无存档"
end

--- 序列化存档数据
function SteamIntegrationV2.serializeSaveData(data)
    -- 简化实现，实际需要 JSON 编码
    -- 移除大体积数据以节省云存储空间
    local serialized = {}
    for key, value in pairs(data) do
        -- 跳过战斗回放等大体积数据
        if key ~= "battleReplays" and key ~= "screenshotCache" then
            serialized[key] = value
        end
    end
    return serialized
end

--- 反序列化存档数据
function SteamIntegrationV2.deserializeSaveData(data)
    -- 简化实现
    return data
end

--- 检查是否需要云同步
function SteamIntegrationV2.checkCloudSync()
    if not V2State.cloudSaveEnabled then
        return false
    end
    
    local now = os.time()
    if now - V2State.lastCloudSync >= V2State.cloudSyncInterval then
        return true, "需要进行云同步"
    end
    
    return false
end

-- ============================================================================
-- Steam 统计数据
-- ============================================================================

--- 更新统计数据
function SteamIntegrationV2.updateStat(statName, value)
    V2State.statistics[statName] = (V2State.statistics[statName] or 0) + value
    
    -- 同步到 Steam Stats API
    SteamIntegrationV2.syncToSteamAPI("stat", statName, value)
end

--- 获取统计数据
function SteamIntegrationV2.getStats()
    return V2State.statistics
end

--- 重置统计数据
function SteamIntegrationV2.resetStats()
    V2State.statistics = {
        totalPlayTime = 0,
        totalKills = 0,
        totalDeaths = 0,
        totalCreditsEarned = 0,
        totalDistanceTraveled = 0,
    }
    
    -- 同步到 Steam
    SteamIntegrationV2.syncToSteamAPI("stats", nil, V2State.statistics)
end

-- ============================================================================
-- 创意工坊集成
-- ============================================================================

--- 订阅创意工坊物品
function SteamIntegrationV2.subscribeItem(publishedFileId)
    if not V2State.workshopItems[publishedFileId] then
        V2State.workshopItems[publishedFileId] = {
            subscribed = true,
            subscribedTime = os.time(),
        }
        print("[SteamIntegrationV2] 已订阅创意工坊物品: " .. publishedFileId)
        return true
    end
    return false, "已订阅"
end

--- 取消订阅创意工坊物品
function SteamIntegrationV2.unsubscribeItem(publishedFileId)
    if V2State.workshopItems[publishedFileId] then
        V2State.workshopItems[publishedFileId] = nil
        print("[SteamIntegrationV2] 已取消订阅创意工坊物品: " .. publishedFileId)
        return true
    end
    return false, "未订阅"
end

--- 获取已订阅的创意工坊物品
function SteamIntegrationV2.getSubscribedItems()
    local items = {}
    for id, item in pairs(V2State.workshopItems) do
        table.insert(items, {
            id = id,
            subscribed = item.subscribed,
            subscribedTime = item.subscribedTime,
        })
    end
    return items
end

-- ============================================================================
-- Steam API 同步（模拟）
-- ============================================================================

--- 同步数据到 Steam API
function SteamIntegrationV2.syncToSteamAPI(dataType, id, value)
    -- 这是一个模拟实现
    -- 实际实现需要 Steam API 调用
    if dataType == "achievement" then
        print(string.format("[Steam] 解锁成就: %s", id))
    elseif dataType == "leaderboard" then
        print(string.format("[Steam] 提交排行榜 %s: %d", id, value))
    elseif dataType == "stat" then
        print(string.format("[Steam] 更新统计 %s: %d", id, value))
    elseif dataType == "stats" then
        print("[Steam] 统计数据已同步")
    end
    
    return true
end

-- ============================================================================
-- 存档
-- ============================================================================

function SteamIntegrationV2.saveState()
    if playerState then
        playerState.steamIntegrationV2 = {
            cloudSaveEnabled = V2State.cloudSaveEnabled,
            lastCloudSync = V2State.lastCloudSync,
            statistics = V2State.statistics,
            workshopItems = V2State.workshopItems,
        }
    end
end

function SteamIntegrationV2.loadState(data)
    if data then
        V2State.cloudSaveEnabled = data.cloudSaveEnabled or false
        V2State.lastCloudSync = data.lastCloudSync or 0
        V2State.statistics = data.statistics or {}
        V2State.workshopItems = data.workshopItems or {}
    end
end

return SteamIntegrationV2
