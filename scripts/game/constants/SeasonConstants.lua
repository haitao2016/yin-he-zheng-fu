---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
Constants/SeasonConstants.lua
赛季系统、积分奖励、里程碑常量
]]

local M = {}

-- ============================================================================
-- 赛季定义
-- ============================================================================

M.SEASONS = {
    {
        id = "SEASON_1", name = "第一赛季：星际远征", shortName = "星际远征",
        startDate = "2026-07-01", endDate = "2026-09-30", duration = 91,
        theme = "MILITARY", themeColor = { 0.2, 0.5, 0.8, 1.0 },
        exclusiveRewards = {
            { id = "SKIN_SEASON_NAVY", name = "赛季海军涂装", type = "SHIP_SKIN", rarity = "EPIC" },
            { id = "TITLE_SEASON_MASTER", name = "赛季大师", type = "TITLE", rarity = "LEGENDARY" },
            { id = "FRAME_SEASON_GOLD", name = "金色赛季框", type = "PROFILE_FRAME", rarity = "RARE" },
            { id = "AVATAR_SEASON_HERO", name = "赛季英雄头像", type = "AVATAR", rarity = "EPIC" },
        },
    },
    {
        id = "SEASON_2", name = "第二赛季：虚空裂隙", shortName = "虚空裂隙",
        startDate = "2026-10-01", endDate = "2026-12-31", duration = 92,
        theme = "VOID", themeColor = { 0.4, 0.1, 0.6, 1.0 },
        exclusiveRewards = {
            { id = "SKIN_SEASON_VOID", name = "虚空战甲涂装", type = "SHIP_SKIN", rarity = "EPIC" },
            { id = "TITLE_VOID_HUNTER", name = "虚空猎手", type = "TITLE", rarity = "LEGENDARY" },
            { id = "FRAME_SEASON_VOID", name = "虚空赛季框", type = "PROFILE_FRAME", rarity = "RARE" },
        },
    },
}

-- 赛季积分奖励里程碑
M.SEASON_POINT_REWARDS = {
    { points = 500,  reward = { blueCrystal = 30 }, icon = "reward_crystal_blue" },
    { points = 1000, reward = { blueCrystal = 50, credits = 500 }, icon = "reward_bundle_1" },
    { points = 2000, reward = { purpleCrystal = 20 }, icon = "reward_crystal_purple" },
    { points = 3500, reward = { skin = "SKIN_SEASON_NAVY" }, icon = "reward_skin" },
    { points = 5000, reward = { rainbowCrystal = 10 }, icon = "reward_crystal_rainbow" },
    { points = 7500, reward = { frame = "FRAME_SEASON_GOLD" }, icon = "reward_frame" },
    { points = 10000, reward = { title = "TITLE_SEASON_MASTER" }, icon = "reward_title" },
}

-- 赛季状态（运行时）
M.SEASON_STATE = {
    currentSeasonId = "SEASON_1",
    startTime = 0,
    endTime = 0,
    daysRemaining = 0,
    playerPoints = 0,
    tasksCompleted = {},
    rewardsClaimed = {},
    weeklyTasksReset = 0,
}

-- P3-P2-2: 赛季商店（限定兑换道具）
M.SEASON_SHOP = {
    -- 第一赛季商店
    SEASON_1 = {
        {
            id = "SHOP_SEASON1_SKIN",
            name = "星际远征皮肤礼包",
            desc = "包含赛季海军涂装 + 专属聊天气泡",
            cost = { seasonPoints = 3000 },
            items = { "SKIN_SEASON_NAVY", "BUBBLE_SEASON_NAVY" },
            available = true,
        },
        {
            id = "SHOP_SEASON1_FRAME",
            name = "金色赛季框",
            desc = "头像框，彰显赛季荣耀",
            cost = { seasonPoints = 1500 },
            items = { "FRAME_SEASON_GOLD" },
            available = true,
        },
        {
            id = "SHOP_SEASON1_TITLE",
            name = "赛季大师称号",
            desc = "聊天时显示的专属称号",
            cost = { seasonPoints = 2000 },
            items = { "TITLE_SEASON_MASTER" },
            available = true,
        },
        {
            id = "SHOP_SEASON1_AVATAR",
            name = "赛季英雄头像",
            desc = "赛季限定头像",
            cost = { seasonPoints = 1000 },
            items = { "AVATAR_SEASON_HERO" },
            available = true,
        },
        {
            id = "SHOP_SEASON1_CRYSTAL_BUNDLE",
            name = "赛季晶石礼包",
            desc = "蓝色晶石 x200",
            cost = { seasonPoints = 500 },
            items = { "blueCrystal" },
            available = true,
        },
    },
    -- 第二赛季商店（虚空裂隙）
    SEASON_2 = {
        {
            id = "SHOP_SEASON2_SKIN",
            name = "虚空战甲礼包",
            desc = "包含虚空战甲涂装 + 专属特效",
            cost = { seasonPoints = 3000 },
            items = { "SKIN_SEASON_VOID", "EFFECT_SEASON_VOID" },
            available = true,
        },
        {
            id = "SHOP_SEASON2_FRAME",
            name = "虚空赛季框",
            desc = "头像框，神秘紫色",
            cost = { seasonPoints = 1500 },
            items = { "FRAME_SEASON_VOID" },
            available = true,
        },
        {
            id = "SHOP_SEASON2_TITLE",
            name = "虚空猎手称号",
            desc = "聊天时显示的专属称号",
            cost = { seasonPoints = 2000 },
            items = { "TITLE_VOID_HUNTER" },
            available = true,
        },
    },
}

-- P3-P2-2: 跨赛季积分（用于排行榜）
M.CROSS_SEASON_POINTS = {
    -- 跨赛季排名积分公式
    rankScoreFormula = function(seasonPoints, rank)
        -- 积分 = 赛季积分 × (1 + 排名加成系数)
        local rankBonus = rank <= 10 and (1 + (10 - rank) * 0.05) or 1.0
        return math.floor(seasonPoints * rankBonus)
    end,
    -- 赛季积分重置但跨赛季积分累积
    resetPerSeason = false,
    -- 排行榜分组
    leaderboardGroups = {
        { id = "GLOBAL", name = "全服排行榜", minRank = 1, maxRank = 100 },
        { id = "REGIONAL", name = "区域排行榜", minRank = 101, maxRank = 1000 },
        { id = "FRIENDS", name = "好友排行榜", minRank = nil, maxRank = nil },
    },
}

return M
