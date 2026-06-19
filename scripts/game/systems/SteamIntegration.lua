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
