---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
Constants/AchievementConstants.lua
成就系统、成就链、资源类型常量
]]

local M = {}

-- ============================================================================
-- 成就定义
-- ============================================================================

M.ACHIEVEMENT_DEFINITIONS = {
    -- 战斗专项成就
    { id = "NO_DAMAGE_MASTER", name = "无伤大师", category = "combat", hidden = false,
      desc = "连续 5 波战斗不损失任何舰船",
      condition = function(ps) return (ps.noDamageStreak or 0) >= 5 end,
      reward = { blueCrystal = 500, title = "无伤大师" } },
    { id = "COMBO_KING", name = "连击之王", category = "combat", hidden = false,
      desc = "单场战斗达成 30 次连续命中",
      condition = function(ps) return (ps.maxCombo or 0) >= 30 end,
      reward = { blueCrystal = 400, title = "连击之王" } },
    { id = "WAVE_MVP_5", name = "五连MVP", category = "combat", hidden = false,
      desc = "连续 5 波成为全队最高伤害输出",
      condition = function(ps) return (ps.mvpStreak or 0) >= 5 end,
      reward = { purpleCrystal = 100, title = "五连MVP" } },
    { id = "HUNDRED_ENEMY_KILL", name = "百人斩", category = "combat", hidden = false,
      desc = "单局游戏击杀 100 艘敌舰",
      condition = function(ps) return (ps.singleRunEnemies or 0) >= 100 end,
      reward = { purpleCrystal = 80 } },
    { id = "BOSS_HUNTER", name = "Boss猎手", category = "combat", hidden = false,
      desc = "累计击败 20 个 Boss",
      condition = function(ps) return (ps.totalBosses or 0) >= 20 end,
      reward = { purpleCrystal = 150, rainbowCrystal = 10 } },
    { id = "PERFECT_CLEAR", name = "完美通关", category = "combat", hidden = true,
      desc = "无伤完成一整章战役",
      condition = function(ps) return ps.perfectChapter == true end,
      reward = { rainbowCrystal = 30, title = "完美指挥官" } },
    { id = "UNDERDOG", name = "以弱胜强", category = "combat", hidden = true,
      desc = "舰队规模小于50%的情况下击败 Boss",
      condition = function(ps) return ps.underdogVictory == true end,
      reward = { purpleCrystal = 200 } },

    -- 探索类成就
    { id = "DEEP_SPACE_EXPLORER", name = "深空探索者", category = "exploration", hidden = true,
      desc = "探索距离基地超过 5000 单位的星域",
      condition = function(ps) return (ps.maxDistanceExplored or 0) >= 5000 end,
      reward = { crystal = 300, title = "深空探索者" } },
    { id = "COLONIZATION_EXPERT", name = "殖民专家", category = "exploration", hidden = true,
      desc = "成功殖民 10 颗行星",
      condition = function(ps) return (ps.planetsColonized or 0) >= 10 end,
      reward = { purpleCrystal = 120 } },

    -- 经济类成就
    { id = "ECONOMY_MOGUL", name = "经济大亨", category = "economy", hidden = true,
      desc = "单局累计获得超过 1,000,000 资源",
      condition = function(ps) return (ps.totalResourcesEarned or 0) >= 1000000 end,
      reward = { purpleCrystal = 200, credits = 2000, title = "经济大亨" } },
    { id = "MERCHANT_LORD", name = "贸易霸主", category = "economy", hidden = true,
      desc = "完成 50 次星际贸易",
      condition = function(ps) return (ps.totalTrades or 0) >= 50 end,
      reward = { credits = 5000 } },
    { id = "SHIP_COLLECTOR", name = "舰船收藏家", category = "fleet", hidden = true,
      desc = "同时拥有所有类型的舰船",
      condition = function(ps)
          if not ps.ownedShipTypes then return false end
          local count = 0
          for _, _ in pairs(ps.ownedShipTypes) do count = count + 1 end
          return count >= 10
      end,
      reward = { rainbowCrystal = 50, title = "舰船收藏家" } },

    -- 策略类成就
    { id = "PEACE_MAKER", name = "和平使者", category = "strategy", hidden = true,
      desc = "不建造任何战斗舰完成一个战役章节",
      condition = function(ps) return ps.peaceChapter == true end,
      reward = { title = "和平使者", credits = 3000 } },
    { id = "MASTER_ENGINEER", name = "工程大师", category = "strategy", hidden = true,
      desc = "同时建造超过 20 艘工程维修舰",
      condition = function(ps) return (ps.engineerCount or 0) >= 20 end,
      reward = { purpleCrystal = 150 } },
    { id = "SPEED_RUNNER", name = "速通达人", category = "strategy", hidden = true,
      desc = "1小时内完成第一章战役",
      condition = function(ps) return (ps.chapter1Time or math.huge) <= 3600 end,
      reward = { rainbowCrystal = 40, title = "速通达人" } },

    -- 社交类
    { id = "DIPLOMAT", name = "外交家", category = "social", hidden = true,
      desc = "加入公会并完成 10 个公会任务",
      condition = function(ps) return (ps.guildTasksCompleted or 0) >= 10 end,
      reward = { credits = 2000 } },
    { id = "LUCKY_DEVIATOR", name = "幸运儿", category = "social", hidden = true,
      desc = "连续 3 次事件都获得最优选择",
      condition = function(ps) return (ps.luckyStreak or 0) >= 3 end,
      reward = { rainbowCrystal = 15 } },

    -- 传说级成就
    { id = "GALACTIC_HERO", name = "银河英雄", category = "legendary", hidden = true,
      desc = "完成所有战役章节 + 解锁所有 Tier5 科技 + 击败终极 Boss",
      condition = function(ps)
          return ps.allChaptersComplete and ps.allTier5Researched and ps.finalBossDefeated
      end,
      reward = { rainbowCrystal = 200, title = "银河英雄", avatar = "GALACTIC_HERO" } },
}

-- ============================================================================
-- 成就解锁链
-- ============================================================================

M.ACHIEVEMENT_CHAINS = {
    COMBAT_MASTER = {
        chainId = "COMBAT_MASTER", name = "战斗大师之路",
        achievements = { "FIRST_BLOOD", "BOSS_SLAYER", "LEGENDARY_HUNTER", "NO_DAMAGE_MASTER", "COMBO_KING" },
        chainReward = { rainbowCrystal = 100, title = "战斗大师" },
    },
    EXPLORATION_MASTER = {
        chainId = "EXPLORATION_MASTER", name = "探索大师之路",
        achievements = { "FIRST_SYSTEM", "FIVE_SYSTEMS", "TEN_SYSTEMS", "COLONIZATION_EXPERT", "DEEP_SPACE_EXPLORER" },
        chainReward = { rainbowCrystal = 100, title = "探索大师" },
    },
    TECHNOLOGY_MASTER = {
        chainId = "TECHNOLOGY_MASTER", name = "科技大师之路",
        achievements = { "FIRST_STEPS", "RESEARCH_MASTER", "NOVA_CANNON", "FORTRESS_PROTOCOL", "GALACTIC_ASCEND" },
        chainReward = { rainbowCrystal = 150, title = "科技大师" },
    },
    ECONOMY_MASTER = {
        chainId = "ECONOMY_MASTER", name = "经济大师之路",
        achievements = { "FIRST_BUILD", "FIFTY_SHIPS", "HUNDRED_FLEET", "MERCHANT_LORD", "ECONOMY_MOGUL" },
        chainReward = { rainbowCrystal = 120, title = "经济大师" },
    },
}

-- ============================================================================
-- 资源类型定义
-- ============================================================================

M.RESOURCE_TYPES = {
    MINERALS       = { id = "MINERALS",       name = "矿石",     nameEn = "Minerals",       icon = "⛏️", color = { 200, 150, 100 } },
    ENERGY         = { id = "ENERGY",         name = "能源",     nameEn = "Energy",         icon = "⚡", color = { 255, 220, 100 } },
    CRYSTAL        = { id = "CRYSTAL",        name = "晶石",     nameEn = "Crystal",        icon = "💎", color = { 100, 200, 255 } },
    NUCLEAR        = { id = "NUCLEAR",        name = "核能",     nameEn = "Nuclear",        icon = "☢️", color = { 100, 255, 150 } },
    CREDITS        = { id = "CREDITS",        name = "星币",     nameEn = "Credits",        icon = "💰", color = { 255, 200, 50 } },
    BLUE_CRYSTAL   = { id = "BLUE_CRYSTAL",   name = "蓝晶",     nameEn = "Blue Crystal",   icon = "🔷", color = { 80, 150, 255 } },
    PURPLE_CRYSTAL = { id = "PURPLE_CRYSTAL", name = "紫晶",     nameEn = "Purple Crystal", icon = "🔶", color = { 180, 80, 255 } },
    RAINBOW_CRYSTAL = { id = "RAINBOW_CRYSTAL", name = "彩虹晶", nameEn = "Rainbow Crystal", icon = "🌈", color = { 255, 150, 255 } },
}

-- ============================================================================
-- 游戏数值平衡
-- ============================================================================

M.GAME_BALANCE = {
    baseEnemyHealth = 100,
    baseEnemyDamage = 10,
    enemyHealthGrowthPerWave = 1.08,
    enemyDamageGrowthPerWave = 1.06,
    bossHealthMult = 5.0,
    bossDamageMult = 2.5,

    startingResources = { minerals = 500, energy = 200, crystal = 50 },
    baseResourceGenPerSec = { minerals = 5, energy = 3, crystal = 0.5 },
    maxStorageBase = 5000,
    storagePerWarehouse = 3000,

    waveRewardBase = { credits = 50 },
    waveRewardGrowth = 1.1,
    bossRewardMult = 5.0,

    difficultyMods = {
        EASY      = { enemyHealth = 0.6, enemyDamage = 0.6, enemySpawn = 0.7, resourceMult = 1.3, rewardMult = 0.8 },
        NORMAL    = { enemyHealth = 1.0, enemyDamage = 1.0, enemySpawn = 1.0, resourceMult = 1.0, rewardMult = 1.0 },
        HARD      = { enemyHealth = 1.5, enemyDamage = 1.3, enemySpawn = 1.3, resourceMult = 0.9, rewardMult = 1.5 },
        NIGHTMARE = { enemyHealth = 2.0, enemyDamage = 1.8, enemySpawn = 1.6, resourceMult = 0.8, rewardMult = 2.0 },
    },
}

-- ============================================================================
-- 战斗环境效果
-- ============================================================================

M.BATTLE_ENVIRONMENTS = {
    ASTEROID_FIELD = { id = "ASTEROID_FIELD", name = "小行星带", effect = { speedMult = 0.7, coverBonus = 0.2, collisionDamage = 5 }, desc = "移动速度-30%，但提供20%掩体防护，有碰撞伤害。" },
    NEBULA        = { id = "NEBULA",        name = "星云区",   effect = { stealthBonus = 0.5, sensorPenalty = 0.3 }, desc = "隐形效果+50%，但探测范围-30%。" },
    SOLAR_STORM   = { id = "SOLAR_STORM",   name = "太阳风暴", effect = { shieldPenalty = 0.4, energyRegenMult = 0.8 }, desc = "护盾效率-40%，能源恢复-20%。" },
    GRAVITY_WELL  = { id = "GRAVITY_WELL",  name = "重力井",   effect = { speedMult = 0.5, projectileSpeedMult = 0.7 }, desc = "所有舰船和弹药速度减半。" },
    DEBRIS_FIELD  = { id = "DEBRIS_FIELD",  name = "残骸区",   effect = { coverBonus = 0.4, scavengeChance = 0.2 }, desc = "提供40%掩体，20%几率从残骸获取资源。" },
    ION_STORM     = { id = "ION_STORM",     name = "离子风暴", effect = { shieldRegenMult = 0.5, skillCooldownMult = 1.3 }, desc = "护盾恢复-50%，技能冷却+30%。" },
    WARP_ZONE     = { id = "WARP_ZONE",     name = "曲速区",   effect = { speedMult = 2.0, skillCooldownMult = 0.7 }, desc = "移动速度翻倍，技能冷却-30%。" },
    CRYSTAL_FIELD = { id = "CRYSTAL_FIELD", name = "晶体区",   effect = { shieldBonus = 0.3, crystalDropChance = 0.15 }, desc = "护盾效率+30%，15%几率额外获得晶石。" },
}

-- 星图变体的环境权重
M.MAP_VARIANT_ENV_WEIGHTS = {
    STANDARD     = { ASTEROID_FIELD = 1, NEBULA = 1, SOLAR_STORM = 1, GRAVITY_WELL = 1, DEBRIS_FIELD = 1, ION_STORM = 1, WARP_ZONE = 1, CRYSTAL_FIELD = 1 },
    RESOURCE_RICH = { ASTEROID_FIELD = 2, CRYSTAL_FIELD = 3, DEBRIS_FIELD = 2, WARP_ZONE = 1, NEBULA = 1 },
    BARREN       = { SOLAR_STORM = 2, GRAVITY_WELL = 2, ION_STORM = 2, ASTEROID_FIELD = 1 },
    HIGH_THREAT  = { GRAVITY_WELL = 2, ION_STORM = 2, SOLAR_STORM = 2, ASTEROID_FIELD = 1, NEBULA = 1 },
}

return M
