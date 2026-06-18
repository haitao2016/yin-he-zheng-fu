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

return M
