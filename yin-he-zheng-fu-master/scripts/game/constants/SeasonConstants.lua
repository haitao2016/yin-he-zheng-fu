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
        -- P2-2: 第二路线 - 探索任务
        routes = {
            { id = "MAIN_COMBAT", name = "战斗路线", desc = "舰队战斗，击败敌人", weight = 1.0 },
            { id = "MAIN_EXPLORE", name = "探索路线", desc = "探索星系，发现遗迹", weight = 0.8 },
        },
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
        -- P2-2: 第二路线 - 虚空任务
        routes = {
            { id = "MAIN_COMBAT", name = "战斗路线", desc = "舰队战斗，击败敌人", weight = 1.0 },
            { id = "MAIN_VOID", name = "虚空路线", desc = "探索虚空，击退虚空生物", weight = 0.9 },
        },
        exclusiveRewards = {
            { id = "SKIN_SEASON_VOID", name = "虚空战甲涂装", type = "SHIP_SKIN", rarity = "EPIC" },
            { id = "TITLE_VOID_HUNTER", name = "虚空猎手", type = "TITLE", rarity = "LEGENDARY" },
            { id = "FRAME_SEASON_VOID", name = "虚空赛季框", type = "PROFILE_FRAME", rarity = "RARE" },
        },
    },
    -- P2-2: 新增赛季 3
    {
        id = "SEASON_3", name = "第三赛季：银河争霸", shortName = "银河争霸",
        startDate = "2027-01-01", endDate = "2027-03-31", duration = 90,
        theme = "EMPIRE", themeColor = { 0.8, 0.2, 0.2, 1.0 },
        routes = {
            { id = "MAIN_COMBAT", name = "征服路线", desc = "征服星系，建立帝国", weight = 1.0 },
            { id = "MAIN_DIPLOMACY", name = "外交路线", desc = "建立联盟，拓展影响力", weight = 0.85 },
        },
        exclusiveRewards = {
            { id = "SKIN_SEASON_IMPERIAL", name = "帝国皇家涂装", type = "SHIP_SKIN", rarity = "LEGENDARY" },
            { id = "TITLE_EMPEROR", name = "银河大帝", type = "TITLE", rarity = "LEGENDARY" },
            { id = "FRAME_SEASON_IMPERIAL", name = "帝国黄金框", type = "PROFILE_FRAME", rarity = "EPIC" },
            { id = "AVATAR_EMPEROR", name = "帝王头像", type = "AVATAR", rarity = "LEGENDARY" },
        },
    },
}

-- ============================================================================
-- P2-2: 赛季任务系统（第二路线任务）
-- ============================================================================

M.SEASON_TASKS = {
    -- 第一赛季任务
    SEASON_1 = {
        -- 战斗路线任务
        { id = "TASK_COMBAT_1", route = "MAIN_COMBAT", name = "初战告捷", desc = "完成 10 场战斗", target = 10, points = 100, type = "BATTLES_WON" },
        { id = "TASK_COMBAT_2", route = "MAIN_COMBAT", name = "舰队扩充", desc = "建造 20 艘战舰", target = 20, points = 150, type = "SHIPS_BUILT" },
        { id = "TASK_COMBAT_3", route = "MAIN_COMBAT", name = "巨兽猎人", desc = "击败 5 个 BOSS", target = 5, points = 300, type = "BOSS_KILLED" },
        { id = "TASK_COMBAT_4", route = "MAIN_COMBAT", name = "百战百胜", desc = "赢得 100 场战斗", target = 100, points = 500, type = "BATTLES_WON" },
        -- 探索路线任务（第二路线）
        { id = "TASK_EXPLORE_1", route = "MAIN_EXPLORE", name = "初涉银河", desc = "探索 5 个星系", target = 5, points = 100, type = "SYSTEMS_EXPLORED" },
        { id = "TASK_EXPLORE_2", route = "MAIN_EXPLORE", name = "星图绘制", desc = "探索 20 个星系", target = 20, points = 200, type = "SYSTEMS_EXPLORED" },
        { id = "TASK_EXPLORE_3", route = "MAIN_EXPLORE", name = "考古学家", desc = "发现 3 处远古遗迹", target = 3, points = 250, type = "RUINS_DISCOVERED" },
        { id = "TASK_EXPLORE_4", route = "MAIN_EXPLORE", name = "星海征服者", desc = "探索 50 个星系", target = 50, points = 500, type = "SYSTEMS_EXPLORED" },
    },
    -- 第二赛季任务
    SEASON_2 = {
        { id = "TASK_COMBAT_1", route = "MAIN_COMBAT", name = "虚空守卫", desc = "击败 20 个敌人", target = 20, points = 100, type = "ENEMIES_KILLED" },
        { id = "TASK_COMBAT_2", route = "MAIN_COMBAT", name = "精锐舰队", desc = "建造 30 艘高级战舰", target = 30, points = 200, type = "SHIPS_BUILT" },
        { id = "TASK_COMBAT_3", route = "MAIN_COMBAT", name = "虚空暴君", desc = "击败 10 个 BOSS", target = 10, points = 400, type = "BOSS_KILLED" },
        -- 虚空路线任务（第二路线）
        { id = "TASK_VOID_1", route = "MAIN_VOID", name = "虚空行者", desc = "进入 10 个虚空区域", target = 10, points = 150, type = "VOID_ZONES_ENTERED" },
        { id = "TASK_VOID_2", route = "MAIN_VOID", name = "虚空清扫", desc = "击败 50 个虚空生物", target = 50, points = 250, type = "VOID_CREATURES_KILLED" },
        { id = "TASK_VOID_3", route = "MAIN_VOID", name = "虚空研究", desc = "收集 100 个虚空晶体", target = 100, points = 350, type = "VOID_CRYSTALS_COLLECTED" },
        { id = "TASK_VOID_4", route = "MAIN_VOID", name = "虚空主宰", desc = "完成 5 次虚空探险", target = 5, points = 600, type = "VOID_EXPEDITIONS_COMPLETE" },
    },
    -- 第三赛季任务
    SEASON_3 = {
        { id = "TASK_COMBAT_1", route = "MAIN_COMBAT", name = "帝国先锋", desc = "征服 5 个星系", target = 5, points = 150, type = "SYSTEMS_CONQUERED" },
        { id = "TASK_COMBAT_2", route = "MAIN_COMBAT", name = "帝国舰队", desc = "建造 50 艘战舰", target = 50, points = 250, type = "SHIPS_BUILT" },
        { id = "TASK_COMBAT_3", route = "MAIN_COMBAT", name = "银河霸主", desc = "征服 20 个星系", target = 20, points = 500, type = "SYSTEMS_CONQUERED" },
        -- 外交路线任务（第二路线）
        { id = "TASK_DIPLO_1", route = "MAIN_DIPLOMACY", name = "外交使者", desc = "与 3 个势力建交", target = 3, points = 150, type = "ALLIANCES_FORGED" },
        { id = "TASK_DIPLO_2", route = "MAIN_DIPLOMACY", name = "贸易中心", desc = "完成 20 次贸易", target = 20, points = 200, type = "TRADES_COMPLETED" },
        { id = "TASK_DIPLO_3", route = "MAIN_DIPLOMACY", name = "联盟领袖", desc = "建立 1 个联盟", target = 1, points = 400, type = "ALLIANCES_LED" },
        { id = "TASK_DIPLO_4", route = "MAIN_DIPLOMACY", name = "银河统一", desc = "影响力达到 10000", target = 10000, points = 800, type = "INFLUENCE_GAINED" },
    },
}

-- P2-2: 赛季任务类型枚举
M.TASK_TYPES = {
    BATTLES_WON = { name = "战斗胜利", icon = "icon_battles" },
    SHIPS_BUILT = { name = "舰船建造", icon = "icon_ships" },
    BOSS_KILLED = { name = "BOSS 击杀", icon = "icon_boss" },
    ENEMIES_KILLED = { name = "敌人击杀", icon = "icon_enemies" },
    SYSTEMS_EXPLORED = { name = "星系探索", icon = "icon_system" },
    RUINS_DISCOVERED = { name = "遗迹发现", icon = "icon_ruins" },
    VOID_ZONES_ENTERED = { name = "虚空区域", icon = "icon_void" },
    VOID_CREATURES_KILLED = { name = "虚空生物击杀", icon = "icon_void_creature" },
    VOID_CRYSTALS_COLLECTED = { name = "虚空晶体收集", icon = "icon_crystal" },
    VOID_EXPEDITIONS_COMPLETE = { name = "虚空探险", icon = "icon_expedition" },
    SYSTEMS_CONQUERED = { name = "星系征服", icon = "icon_conquest" },
    ALLIANCES_FORGED = { name = "建立联盟", icon = "icon_alliance" },
    TRADES_COMPLETED = { name = "贸易完成", icon = "icon_trade" },
    ALLIANCES_LED = { name = "领导联盟", icon = "icon_leader" },
    INFLUENCE_GAINED = { name = "影响力", icon = "icon_influence" },
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
