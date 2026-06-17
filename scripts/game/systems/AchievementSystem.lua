--[[
AchievementSystem.lua - 成就系统
V2.7 P1-2
追踪玩家各种里程碑，达成解锁奖励
]]

local AchievementSystem = {}

-- 成就定义
AchievementSystem.ACHIEVEMENTS = {
    -- 战斗类成就
    {
        id = "FIRST_BLOOD",
        name = "初战告捷",
        desc = "击败第一个 Boss",
        icon = "⚔️",
        category = "combat",
        condition = function(ps) return (ps.bossesDefeated or 0) >= 1 end,
        reward = { blueCrystal = 20 },
    },
    {
        id = "BOSS_SLAYER",
        name = "Boss 杀手",
        desc = "击败 10 个 Boss",
        icon = "💀",
        category = "combat",
        condition = function(ps) return (ps.bossesDefeated or 0) >= 10 end,
        reward = { blueCrystal = 100, purpleCrystal = 10 },
    },
    {
        id = "LEGENDARY_HUNTER",
        name = "传说猎人",
        desc = "击败超级 Boss",
        icon = "🏆",
        category = "combat",
        condition = function(ps) return (ps.superBossesDefeated or 0) >= 1 end,
        reward = { purpleCrystal = 50, rainbowCrystal = 5 },
    },
    {
        id = "UNBROKEN",
        name = "无懈可击",
        desc = "无伤通关任意波次",
        icon = "🛡️",
        category = "combat",
        condition = function(ps) return ps.noDamageWave or false end,
        reward = { blueCrystal = 50 },
    },
    {
        id = "ENDLESS_WARRIOR",
        name = "无尽战士",
        desc = "无尽模式达到波次 50",
        icon = "∞",
        category = "combat",
        condition = function(ps) return (ps.endlessRecord or 0) >= 50 end,
        reward = { purpleCrystal = 100 },
    },
    {
        id = "BOSS_RUSH_CHAMPION",
        name = "Boss Rush 冠军",
        desc = "完成 Boss Rush（5 Boss）",
        icon = "💎",
        category = "combat",
        condition = function(ps) return (ps.bossRushCompleted or 0) >= 5 end,
        reward = { purpleCrystal = 80, rainbowCrystal = 10 },
    },
    
    -- 科技类成就
    {
        id = "FIRST_STEPS",
        name = "初窥门径",
        desc = "研究第一个科技",
        icon = "🔬",
        category = "research",
        condition = function(ps) return (ps.techsResearched or 0) >= 1 end,
        reward = { blueCrystal = 10 },
    },
    {
        id = "RESEARCH_MASTER",
        name = "科研大师",
        desc = "研究所有科技",
        icon = "📚",
        category = "research",
        condition = function(ps) return ps.allTechsResearched or false end,
        reward = { purpleCrystal = 100 },
    },
    {
        id = "TIER5_EXPLORER",
        name = "T5 探索者",
        desc = "研究第一个 Tier5 科技",
        icon = "🌟",
        category = "research",
        condition = function(ps) return ps.tier5Unlocked or false end,
        reward = { rainbowCrystal = 20 },
    },
    
    -- 舰船类成就
    {
        id = "FLEET_COMMANDER",
        name = "舰队指挥官",
        desc = "建造 50 艘舰船",
        icon = "🚀",
        category = "fleet",
        condition = function(ps) return (ps.shipsBuilt or 0) >= 50 end,
        reward = { blueCrystal = 30 },
    },
    {
        id = "SHIP_COLLECTOR",
        name = "舰船收藏家",
        desc = "建造所有类型舰船",
        icon = "🛥️",
        category = "fleet",
        condition = function(ps) return ps.allShipTypesBuilt or false end,
        reward = { purpleCrystal = 50 },
    },
    {
        id = "ENHANCED_WARRIOR",
        name = "强化战士",
        desc = "将一艘舰船强化到满级",
        icon = "⚡",
        category = "fleet",
        condition = function(ps) return ps.maxEnhancementReached or false end,
        reward = { blueCrystal = 100 },
    },
    
    -- 经济类成就
    {
        id = "WEALTHY",
        name = "小有资产",
        desc = "累计获得 1000 蓝晶石",
        icon = "💰",
        category = "economy",
        condition = function(ps) return (ps.totalBlueCrystalEarned or 0) >= 1000 end,
        reward = { blueCrystal = 50 },
    },
    {
        id = "RICH_ADVENTURER",
        name = "富甲一方",
        desc = "累计获得 5000 蓝晶石",
        icon = "💎",
        category = "economy",
        condition = function(ps) return (ps.totalBlueCrystalEarned or 0) >= 5000 end,
        reward = { purpleCrystal = 100 },
    },
    {
        id = "TRADE_MASTER",
        name = "贸易大师",
        desc = "建立 3 条贸易路线",
        icon = "📦",
        category = "economy",
        condition = function(ps) return (ps.tradeRoutesEstablished or 0) >= 3 end,
        reward = { blueCrystal = 80 },
    },
    
    -- 探索类成就
    {
        id = "GALAXY_EXPLORER",
        name = "星系探索者",
        desc = "探索 20 个星球",
        icon = "🌌",
        category = "exploration",
        condition = function(ps) return (ps.planetsExplored or 0) >= 20 end,
        reward = { blueCrystal = 40 },
    },
    {
        id = "COLONIZER",
        name = "殖民者",
        desc = "殖民 5 个星球",
        icon = "🏠",
        category = "exploration",
        condition = function(ps) return (ps.planetsColonized or 0) >= 5 end,
        reward = { purpleCrystal = 30 },
    },
}

-- 成就分类
AchievementSystem.CATEGORIES = {
    { id = "combat", name = "战斗", icon = "⚔️" },
    { id = "research", name = "科技", icon = "🔬" },
    { id = "fleet", name = "舰船", icon = "🚀" },
    { id = "economy", name = "经济", icon = "💰" },
    { id = "exploration", name = "探索", icon = "🌌" },
}

-- 获取玩家成就进度
function AchievementSystem.getProgress(playerState)
    playerState.achievements = playerState.achievements or {}
    playerState.achievements.unlocked = playerState.achievements.unlocked or {}
    
    local progress = {}
    for _, ach in ipairs(AchievementSystem.ACHIEVEMENTS) do
        local unlocked = playerState.achievements.unlocked[ach.id] or false
        local meetsCondition = ach.condition(playerState)
        
        progress[ach.id] = {
            id = ach.id,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
            category = ach.category,
            unlocked = unlocked,
            meetsCondition = meetsCondition,
            reward = ach.reward,
        }
    end
    
    return progress
end

-- 检查并解锁新成就
function AchievementSystem.checkAndUnlock(playerState, notifyFn)
    local progress = AchievementSystem.getProgress(playerState)
    local newlyUnlocked = {}
    
    for id, data in pairs(progress) do
        if data.meetsCondition and not data.unlocked then
            playerState.achievements.unlocked[id] = true
            table.insert(newlyUnlocked, data)
        end
    end
    
    -- 发放奖励并通知
    for _, ach in ipairs(newlyUnlocked) do
        local rm = UICommon and UICommon.rm
        if rm and rm.addRare and ach.reward then
            for res, amount in pairs(ach.reward) do
                rm:addRare(res, amount)
            end
        end
        
        if notifyFn then
            notifyFn("🏆 成就解锁: " .. ach.name .. "！", "achievement")
        end
    end
    
    return newlyUnlocked
end

-- 获取成就统计
function AchievementSystem.getStats(playerState)
    local progress = AchievementSystem.getProgress(playerState)
    local total = 0
    local unlocked = 0
    
    for _, data in pairs(progress) do
        total = total + 1
        if data.unlocked then unlocked = unlocked + 1 end
    end
    
    return {
        total = total,
        unlocked = unlocked,
        percentage = total > 0 and math.floor(unlocked / total * 100) or 0,
    }
end

-- 更新玩家状态（供外部调用）
function AchievementSystem.updateStat(playerState, stat, value)
    playerState.achievementStats = playerState.achievementStats or {}
    playerState.achievementStats[stat] = value
end

function AchievementSystem.incrementStat(playerState, stat, delta)
    playerState.achievementStats = playerState.achievementStats or {}
    playerState.achievementStats[stat] = (playerState.achievementStats[stat] or 0) + (delta or 1)
end

return AchievementSystem
