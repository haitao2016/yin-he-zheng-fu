---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/SeasonSystem.lua -- 赛季框架系统
-- V2.8 P0-2
-- ============================================================================

local SeasonSystem = {}

-- ============================================================================
-- 赛季任务定义
-- ============================================================================

SEASON_TASKS = {
    -- 累计类任务
    { id = "PLAY_WAVES", type = "CUMULATIVE", category = "BATTLE",
      desc = "完成 100 波战斗", target = 100,
      reward = { points = 100 } },
    { id = "WIN_50_BATTLES", type = "CUMULATIVE", category = "BATTLE",
      desc = "赢得 50 场战斗", target = 50,
      reward = { points = 150 } },
    { id = "KILL_ENEMIES", type = "CUMULATIVE", category = "BATTLE",
      desc = "击败 1000 艘敌舰", target = 1000,
      reward = { points = 200 } },
    { id = "DESTROY_BOSS", type = "CUMULATIVE", category = "BATTLE",
      desc = "击败 20 个 Boss", target = 20,
      reward = { points = 300 } },

    -- 波次类任务
    { id = "REACH_WAVE_50", type = "MILESTONE", category = "PROGRESS",
      desc = "达到波次 50", target = 50,
      reward = { points = 500 } },
    { id = "REACH_WAVE_100", type = "MILESTONE", category = "PROGRESS",
      desc = "达到波次 100", target = 100,
      reward = { points = 1000 } },

    -- 周期性任务（每周重置）
    { id = "WEEKLY_WIN_10", type = "WEEKLY", category = "BATTLE",
      desc = "本周赢得 10 场战斗", target = 10,
      reward = { points = 300 } },
    { id = "WEEKLY_REACH_WAVE_30", type = "WEEKLY", category = "PROGRESS",
      desc = "本周达到波次 30", target = 30,
      reward = { points = 500 } },
    { id = "WEEKLY_KILL_200", type = "WEEKLY", category = "BATTLE",
      desc = "本周击败 200 艘敌舰", target = 200,
      reward = { points = 200 } },
    { id = "WEEKLY_CAMPAIGN", type = "WEEKLY", category = "CAMPAIGN",
      desc = "本周完成 3 个战役关卡", target = 3,
      reward = { points = 400 } },

    -- 挑战类任务
    { id = "DEFEAT_SUPER_BOSS", type = "CHALLENGE", category = "BATTLE",
      desc = "击败超级 Boss", target = 1,
      reward = { points = 1000 } },
    { id = "COMPLETE_ENDLESS_50", type = "CHALLENGE", category = "ENDLESS",
      desc = "无尽模式达到波次 50", target = 50,
      reward = { points = 800 } },
    { id = "COMPLETE_CAMPAIGN_CH1", type = "CHALLENGE", category = "CAMPAIGN",
      desc = "完成第一章战役", target = 1,
      reward = { points = 2000 } },

    -- 社交类任务
    { id = "JOIN_GUILD", type = "ONE_TIME", category = "SOCIAL",
      desc = "加入一个公会", target = 1,
      reward = { points = 100 } },
    { id = "HELP_FRIEND", type = "WEEKLY", category = "SOCIAL",
      desc = "本周支援好友 3 次", target = 3,
      reward = { points = 200 } },
    { id = "ADD_FRIEND", type = "ONE_TIME", category = "SOCIAL",
      desc = "添加 5 个好友", target = 5,
      reward = { points = 150 } },

    -- 经济类任务
    { id = "EARN_CREDITS", type = "CUMULATIVE", category = "ECONOMY",
      desc = "赚取 10000 星币", target = 10000,
      reward = { points = 100 } },
    { id = "TRADE_ITEMS", type = "CUMULATIVE", category = "ECONOMY",
      desc = "完成 50 次交易", target = 50,
      reward = { points = 150 } },

    -- 养成类任务
    { id = "ENHANCE_SHIP", type = "CUMULATIVE", category = "FLEET",
      desc = "强化舰船 10 次", target = 10,
      reward = { points = 200 } },
    { id = "RESEARCH_TECH", type = "CUMULATIVE", category = "TECH",
      desc = "完成 20 项科技研究", target = 20,
      reward = { points = 300 } },
    { id = "MAX_LEVEL_BUILDING", type = "ONE_TIME", category = "ECONOMY",
      desc = "将任意建筑升到满级", target = 1,
      reward = { points = 500 } },
}

-- 任务分类
SEASON_TASK_CATEGORIES = {
    { id = "ALL", name = "全部" },
    { id = "BATTLE", name = "战斗" },
    { id = "PROGRESS", name = "进度" },
    { id = "CHALLENGE", name = "挑战" },
    { id = "SOCIAL", name = "社交" },
    { id = "ECONOMY", name = "经济" },
    { id = "FLEET", name = "舰队" },
    { id = "CAMPAIGN", name = "战役" },
}

-- ============================================================================
-- 运行时赛季数据
-- ============================================================================

local RuntimeSeasonState = {
    currentSeasonId = "SEASON_1",
    startTime = 0,
    endTime = 0,
    daysRemaining = 0,
    playerPoints = 0,
    tasksProgress = {},
    rewardsClaimed = {},
    weeklyTasksReset = 0,
    lastWeeklyReset = 0,
}

-- ============================================================================
-- 赛季初始化
-- ============================================================================

function SeasonSystem.initialize()
    -- 尝试从存档加载
    if playerState and playerState.seasonState then
        RuntimeSeasonState = playerState.seasonState
    else
        -- 初始化当前赛季
        SeasonSystem.startSeason("SEASON_1")
    end

    -- 检查赛季是否过期
    SeasonSystem.checkSeasonEnd()
end

-- 开始赛季
function SeasonSystem.startSeason(seasonId)
    local season = SEASONS[1]  -- 默认第一个赛季
    for _, s in ipairs(SEASONS) do
        if s.id == seasonId then season = s; break end
    end

    RuntimeSeasonState.currentSeasonId = season.id
    RuntimeSeasonState.startTime = os.time()
    RuntimeSeasonState.endTime = SeasonSystem.parseDate(season.endDate)
    RuntimeSeasonState.daysRemaining = math.ceil((RuntimeSeasonState.endTime - RuntimeSeasonState.startTime) / 86400)

    -- 重置周任务
    RuntimeSeasonState.lastWeeklyReset = os.time()
    RuntimeSeasonState.weeklyTasksReset = RuntimeSeasonState.weeklyTasksReset + 1

    -- 初始化任务进度
    for _, task in ipairs(SEASON_TASKS) do
        if task.type == "WEEKLY" then
            RuntimeSeasonState.tasksProgress[task.id] = 0
        elseif task.type == "ONE_TIME" or task.type == "CUMULATIVE" or task.type == "MILESTONE" then
            if not RuntimeSeasonState.tasksProgress[task.id] then
                RuntimeSeasonState.tasksProgress[task.id] = 0
            end
        end
    end

    -- 保存到存档
    SeasonSystem.saveState()

    return true, "赛季开始: " .. season.name
end

-- 解析日期字符串
function SeasonSystem.parseDate(dateStr)
    local year, month, day = dateStr:match("(%d+)-(%d+)-(%d+)")
    return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 0 })
end

-- ============================================================================
-- 赛季检查
-- ============================================================================

function SeasonSystem.checkSeasonEnd()
    local now = os.time()

    if now >= RuntimeSeasonState.endTime then
        -- 赛季结束
        SeasonSystem.endCurrentSeason()
    end

    -- 检查周重置
    SeasonSystem.checkWeeklyReset()
end

-- 赛季结束
function SeasonSystem.endCurrentSeason()
    local currentSeason = nil
    for _, s in ipairs(SEASONS) do
        if s.id == RuntimeSeasonState.currentSeasonId then currentSeason = s; break end
    end

    -- 发放赛季结束奖励
    SeasonSystem.grantSeasonEndRewards()

    -- 查找下一个赛季
    local nextSeasonId = nil
    local foundCurrent = false
    for _, s in ipairs(SEASONS) do
        if foundCurrent then
            nextSeasonId = s.id
            break
        end
        if s.id == RuntimeSeasonState.currentSeasonId then
            foundCurrent = true
        end
    end

    -- 如果没有下一个赛季，循环到第一个
    if not nextSeasonId and #SEASONS > 0 then
        nextSeasonId = SEASONS[1].id
    end

    if nextSeasonId then
        SeasonSystem.startSeason(nextSeasonId)
    end
end

-- 发放赛季结束奖励
function SeasonSystem.grantSeasonEndRewards()
    -- 根据积分发放额外奖励
    local points = RuntimeSeasonState.playerPoints
    local rewards = {}

    if points >= 5000 then
        rewards.rainbowCrystal = 50
    elseif points >= 2500 then
        rewards.purpleCrystal = 100
    elseif points >= 1000 then
        rewards.blueCrystal = 200
    end

    -- 赛季专属奖励标记
    rewards.seasonExclusiveUnlocked = RuntimeSeasonState.currentSeasonId

    -- 发放奖励
    if NotifyPanel then
        NotifyPanel.push({
            type = "SEASON_END",
            title = "赛季结束",
            message = "恭喜获得赛季结束奖励！",
            rewards = rewards,
        })
    end

    return rewards
end

-- 检查周重置
function SeasonSystem.checkWeeklyReset()
    local now = os.time()
    local weekStart = SeasonSystem.getWeekStart(now)

    if weekStart > RuntimeSeasonState.lastWeeklyReset then
        -- 重置周任务
        RuntimeSeasonState.weeklyTasksReset = RuntimeSeasonState.weeklyTasksReset + 1
        RuntimeSeasonState.lastWeeklyReset = weekStart

        for _, task in ipairs(SEASON_TASKS) do
            if task.type == "WEEKLY" then
                RuntimeSeasonState.tasksProgress[task.id] = 0
            end
        end

        SeasonSystem.saveState()

        if NotifyPanel then
            NotifyPanel.push({
                type = "INFO",
                title = "周任务已重置",
                message = "新的一周开始了，快去完成周任务吧！",
            })
        end
    end
end

-- 获取本周开始时间
function SeasonSystem.getWeekStart(timestamp)
    local now = timestamp or os.time()
    local wday = os.date("*t", now).wday - 1  -- 0 = 周日
    if wday == 0 then wday = 7 end
    local weekStart = now - (wday * 86400) - os.date("*t", now).hour * 3600 - os.date("*t", now).min * 60 - os.date("*t", now).sec
    return weekStart
end

-- ============================================================================
-- 任务进度更新
-- ============================================================================

-- 更新任务进度
function SeasonSystem.updateTaskProgress(taskId, increment)
    if not increment then increment = 1 end

    local task = nil
    for _, t in ipairs(SEASON_TASKS) do
        if t.id == taskId then task = t; break end
    end
    if not task then return false, "任务不存在" end

    -- 检查任务类型
    if task.type == "ONE_TIME" and RuntimeSeasonState.tasksProgress[taskId] and RuntimeSeasonState.tasksProgress[taskId] >= 1 then
        return false, "任务已完成"
    end

    -- 更新进度
    RuntimeSeasonState.tasksProgress[taskId] = (RuntimeSeasonState.tasksProgress[taskId] or 0) + increment

    -- 限制进度上限
    if task.target then
        RuntimeSeasonState.tasksProgress[taskId] = math.min(RuntimeSeasonState.tasksProgress[taskId], task.target)
    end

    -- 检查完成
    if task.target and RuntimeSeasonState.tasksProgress[taskId] >= task.target then
        -- 任务完成，发放奖励
        SeasonSystem.claimTaskReward(taskId)
    end

    SeasonSystem.saveState()
    return true, "进度已更新"
end

-- 发放任务奖励
function SeasonSystem.claimTaskReward(taskId)
    local task = nil
    for _, t in ipairs(SEASON_TASKS) do
        if t.id == taskId then task = t; break end
    end
    if not task then return false end

    -- 标记为已领取
    RuntimeSeasonState.rewardsClaimed[taskId] = true

    -- 增加积分
    if task.reward and task.reward.points then
        RuntimeSeasonState.playerPoints = RuntimeSeasonState.playerPoints + task.reward.points
    end

    -- 显示通知
    if NotifyPanel then
        NotifyPanel.push({
            type = "TASK_COMPLETE",
            title = "任务完成",
            message = task.desc .. " (+" .. (task.reward and task.reward.points or 0) .. " 赛季积分)",
        })
    end

    return true
end

-- ============================================================================
-- 便捷任务更新接口
-- ============================================================================

function SeasonSystem.onWaveCompleted(waveNum, victory)
    -- 波次任务
    SeasonSystem.updateTaskProgress("PLAY_WAVES", 1)
    if victory then
        SeasonSystem.updateTaskProgress("WIN_50_BATTLES", 1)
    end

    -- 波次里程碑
    if waveNum >= 50 then
        SeasonSystem.updateTaskProgress("REACH_WAVE_50", 1)
    end
    if waveNum >= 100 then
        SeasonSystem.updateTaskProgress("REACH_WAVE_100", 1)
    end

    -- 周任务
    SeasonSystem.updateTaskProgress("WEEKLY_WIN_10", victory and 1 or 0)
    if waveNum >= 30 then
        SeasonSystem.updateTaskProgress("WEEKLY_REACH_WAVE_30", 1)
    end
end

function SeasonSystem.onEnemyKilled(enemyType, isBoss)
    SeasonSystem.updateTaskProgress("KILL_ENEMIES", 1)
    if isBoss then
        SeasonSystem.updateTaskProgress("DESTROY_BOSS", 1)
    end
    SeasonSystem.updateTaskProgress("WEEKLY_KILL_200", 1)
end

function SeasonSystem.onSuperBossDefeated()
    SeasonSystem.updateTaskProgress("DEFEAT_SUPER_BOSS", 1)
end

function SeasonSystem.onCampaignStageComplete(stageId)
    SeasonSystem.updateTaskProgress("WEEKLY_CAMPAIGN", 1)
    -- 检查章节完成
    local CS = require("game.systems.CampaignSystem")
    local progress = CS.getProgress()
    if progress and progress.completedChapters["CHAPTER_1"] then
        SeasonSystem.updateTaskProgress("COMPLETE_CAMPAIGN_CH1", 1)
    end
end

function SeasonSystem.onGuildJoined()
    SeasonSystem.updateTaskProgress("JOIN_GUILD", 1)
end

function SeasonSystem.onFriendAdded()
    SeasonSystem.updateTaskProgress("ADD_FRIEND", 1)
end

function SeasonSystem.onFriendHelped()
    SeasonSystem.updateTaskProgress("HELP_FRIEND", 1)
end

function SeasonSystem.onCreditsEarned(amount)
    SeasonSystem.updateTaskProgress("EARN_CREDITS", amount)
end

function SeasonSystem.onTradeCompleted()
    SeasonSystem.updateTaskProgress("TRADE_ITEMS", 1)
end

function SeasonSystem.onShipEnhanced()
    SeasonSystem.updateTaskProgress("ENHANCE_SHIP", 1)
end

function SeasonSystem.onTechResearched()
    SeasonSystem.updateTaskProgress("RESEARCH_TECH", 1)
end

function SeasonSystem.onEndlessWaveReached(wave)
    if wave >= 50 then
        SeasonSystem.updateTaskProgress("COMPLETE_ENDLESS_50", 1)
    end
end

-- ============================================================================
-- 查询接口
-- ============================================================================

-- 获取当前赛季信息
function SeasonSystem.getCurrentSeason()
    local season = nil
    for _, s in ipairs(SEASONS) do
        if s.id == RuntimeSeasonState.currentSeasonId then season = s; break end
    end
    return season
end

-- 获取赛季状态
function SeasonSystem.getSeasonState()
    local now = os.time()
    RuntimeSeasonState.daysRemaining = math.ceil((RuntimeSeasonState.endTime - now) / 86400)

    return {
        seasonId = RuntimeSeasonState.currentSeasonId,
        seasonName = SeasonSystem.getCurrentSeason() and SeasonSystem.getCurrentSeason().name or "",
        daysRemaining = RuntimeSeasonState.daysRemaining,
        playerPoints = RuntimeSeasonState.playerPoints,
        weekNumber = RuntimeSeasonState.weeklyTasksReset,
    }
end

-- 获取任务列表
function SeasonSystem.getTasks(category)
    local tasks = {}
    for _, task in ipairs(SEASON_TASKS) do
        if category == "ALL" or task.category == category then
            local progress = RuntimeSeasonState.tasksProgress[task.id] or 0
            local claimed = RuntimeSeasonState.rewardsClaimed[task.id] or false
            local completed = task.target and progress >= task.target

            table.insert(tasks, {
                id = task.id,
                type = task.type,
                category = task.category,
                desc = task.desc,
                target = task.target,
                progress = progress,
                reward = task.reward,
                completed = completed,
                claimed = claimed,
            })
        end
    end
    return tasks
end

-- 获取已领取的赛季奖励里程碑
function SeasonSystem.getClaimedMilestones()
    local claimed = {}
    for _, milestone in ipairs(SEASON_POINT_REWARDS) do
        if RuntimeSeasonState.playerPoints >= milestone.points then
            claimed[milestone.points] = true
        end
    end
    return claimed
end

-- ============================================================================
-- 存档
-- ============================================================================

function SeasonSystem.saveState()
    if playerState then
        playerState.seasonState = RuntimeSeasonState
    end
end

function SeasonSystem.loadState(data)
    if data then
        RuntimeSeasonState = data
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return SeasonSystem

-- ============================================================================
-- V3.0 P1-3: 赛季系统深化
-- 赛季主题/通行证/任务/商店/排行榜
-- ============================================================================

local SeasonSystemV2 = {}

-- ============================================================================
-- 赛季主题定义
-- ============================================================================
SEASON_THEMES = {
    { id = "STAR_TURMOIL", name = "星际风暴", icon = "storm",
      bgmTrack = "season_storm", accentColor = {0.4, 0.6, 1.0},
      specialEvent = "STORM_SURGE", desc = "风暴肆虐，战力激增" },
    { id = "VOID_INVASION", name = "虚空入侵", icon = "void",
      bgmTrack = "season_void", accentColor = {0.6, 0.2, 0.8},
      specialEvent = "VOID_RIFT", desc = "虚空裂缝频现，变异敌人增多" },
    { id = "ALLIANCE_WAR", name = "星际联盟战", icon = "war",
      bgmTrack = "season_war", accentColor = {1.0, 0.4, 0.2},
      specialEvent = "FACTION_CONFLICT", desc = "阵营冲突加剧，战斗经验+50%" },
    { id = "TRADE_FEDERATION", name = "贸易联邦", icon = "trade",
      bgmTrack = "season_trade", accentColor = {0.8, 0.8, 0.3},
      specialEvent = "TRADE_BONUS", desc = "市场繁荣，交易收益翻倍" },
    { id = "FRONTIER_EXPLORE", name = "边境探索", icon = "explore",
      bgmTrack = "season_explore", accentColor = {0.2, 0.8, 0.5},
      specialEvent = "EXPEDITION_BOOST", desc = "探索收获增加，稀有发现概率+30%" },
}

-- ============================================================================
-- 通行证奖励定义
-- ============================================================================
SEASON_PASS_TIERS = {
    FREE = {
        { id = "PASS_FREE_1", level = 1, reward = { type = "CURRENCY", id = "credits", amount = 500 },
          desc = "500 星币", icon = "star" },
        { id = "PASS_FREE_2", level = 5, reward = { type = "CURRENCY", id = "crystal", amount = 50 },
          desc = "50 水晶", icon = "crystal" },
        { id = "PASS_FREE_3", level = 10, reward = { type = "SHIP", id = "FRIGATE", amount = 3 },
          desc = "3 艘侦察舰", icon = "ship" },
        { id = "PASS_FREE_4", level = 15, reward = { type = "CURRENCY", id = "credits", amount = 1000 },
          desc = "1000 星币", icon = "star" },
        { id = "PASS_FREE_5", level = 20, reward = { type = "MODULE", id = "SCOUT_PROBE", amount = 1 },
          desc = "侦察模块×1", icon = "module" },
    },
    PREMIUM = {
        { id = "PASS_PRE_1", level = 1, reward = { type = "SKIN", id = "SKIN_SEASON_NAVY", amount = 1 },
          desc = "赛季限定涂装", icon = "skin" },
        { id = "PASS_PRE_2", level = 5, reward = { type = "CURRENCY", id = "crystal", amount = 100 },
          desc = "100 水晶", icon = "crystal" },
        { id = "PASS_PRE_3", level = 10, reward = { type = "COMMANDER_EXP", id = "xp_boost", amount = 500 },
          desc = "指挥官经验×500", icon = "commander" },
        { id = "PASS_PRE_4", level = 15, reward = { type = "CURRENCY", id = "season_points", amount = 200 },
          desc = "200 赛季积分", icon = "season" },
        { id = "PASS_PRE_5", level = 20, reward = { type = "TITLE", id = "SEASON_CHAMPION", amount = 1 },
          desc = "赛季冠军称号", icon = "title" },
        { id = "PASS_PRE_6", level = 25, reward = { type = "SHIP", id = "CARRIER", amount = 1 },
          desc = "1 艘航母", icon = "ship" },
        { id = "PASS_PRE_7", level = 30, reward = { type = "MODULE", id = "LEGEND_REACTOR", amount = 1 },
          desc = "传奇反应堆×1", icon = "module" },
        { id = "PASS_PRE_8", level = 40, reward = { type = "SKIN", id = "SKIN_SEASON_GOLD", amount = 1 },
          desc = "赛季冠军涂装", icon = "skin" },
    },
}

-- ============================================================================
-- 赛季专属任务（V3.0 新增）
-- ============================================================================
SEASON_EXCLUSIVE_TASKS = {
    -- 使用特定系统完成任务
    { id = "USE_MUTANT_SHIP", desc = "使用变异舰船赢得 5 场战斗", target = 5, reward = { points = 300 },
      icon = "mutant" },
    { id = "HELP_FRIENDS_10", desc = "支援好友 10 次", target = 10, reward = { points = 200 },
      icon = "friend" },
    { id = "WIN_ENDLESS_20", desc = "无尽模式达到波次 20", target = 20, reward = { points = 400 },
      icon = "endless" },
    { id = "UNLOCK_LEGACY", desc = "解锁一项文明遗产", target = 1, reward = { points = 250 },
      icon = "legacy" },
    { id = "USE_FORMATION", desc = "使用自定义阵型赢得 3 场战斗", target = 3, reward = { points = 150 },
      icon = "formation" },
    { id = "MAX_FRIENDSHIP", desc = "与好友达到满友谊值", target = 1, reward = { points = 300 },
      icon = "friendship" },
    { id = "WIN_LEAGUE", desc = "赢得一次星际联赛", target = 1, reward = { points = 500 },
      icon = "league" },
    { id = "BUILD_MEGASTRUCTURE", desc = "开始建造一个巨构", target = 1, reward = { points = 350 },
      icon = "megastructure" },
    { id = "DEFEAT_NEMESIS", desc = "击败一位宿敌", target = 1, reward = { points = 400 },
      icon = "nemesis" },
    { id = "COLLECT_BLUEPRINT", desc = "收藏 3 套战术蓝图", target = 3, reward = { points = 200 },
      icon = "blueprint" },
}

-- ============================================================================
-- 赛季商店商品
-- ============================================================================
SEASON_SHOP_ITEMS = {
    -- 往期赛季奖励（补齐机制）
    { id = "SHOP_LEGACY_SKIN", cost = { seasonPoints = 3000 }, items = { "SKIN_SEASON_NAVY" },
      desc = "往期赛季限定涂装", available = true },
    { id = "SHOP_LEGACY_TITLE", cost = { seasonPoints = 2000 }, items = { "TITLE_SEASON_CHAMPION" },
      desc = "往期赛季冠军称号", available = true },
    -- 当前赛季专属
    { id = "SHOP_SEASON_COMMANDER", cost = { seasonPoints = 5000 }, items = { "COMMANDER_TEMP" },
      desc = "赛季限定指挥官体验卡×7天", available = true },
    { id = "SHOP_SEASON_MODULE", cost = { seasonPoints = 2500 }, items = { "MODULE_SEASON_EXCLUSIVE" },
      desc = "赛季限定模块", available = true },
    { id = "SHOP_SEASON_RESKIN", cost = { seasonPoints = 1500 }, items = { "SKIN_CURRENT_THEME" },
      desc = "当前赛季主题涂装", available = true },
    -- 实用道具
    { id = "SHOP_XP_BOOST", cost = { seasonPoints = 500 }, items = { "COMMANDER_EXP", amount = 1000 },
      desc = "指挥官经验×1000", available = true },
    { id = "SHOP_CURRENCY_PACK", cost = { seasonPoints = 1000 }, items = { "credits", amount = 5000 },
      desc = "星币×5000", available = true },
}

-- ============================================================================
-- V2 运行时状态
-- ============================================================================
local V2State = {
    currentTheme = nil,           -- 当前赛季主题
    passLevel = 0,                -- 通行证等级
    passPurchased = false,        -- 是否已购买高级通行证
    exclusiveTasksProgress = {},   -- 赛季专属任务进度
    exclusiveTasksClaimed = {},   -- 赛季专属任务奖励领取状态
    shopHistory = {},             -- 商店购买历史
    themeEffects = {},            -- 主题效果加成
}

-- ============================================================================
-- 赛季主题系统
-- ============================================================================

--- 获取当前赛季主题
function SeasonSystemV2.getCurrentTheme()
    return V2State.currentTheme
end

--- 应用赛季主题效果
function SeasonSystemV2.applyThemeEffects()
    local theme = V2State.currentTheme
    if not theme then return {} end
    
    local effects = {}
    
    -- 根据主题 ID 应用不同效果
    if theme.id == "STAR_TURMOIL" then
        effects.battleXpBonus = 0.2      -- 战斗经验+20%
        effects.enemySpawnRate = 1.1      -- 敌人刷新+10%
    elseif theme.id == "VOID_INVASION" then
        effects.mutantDropRate = 0.3      -- 变异舰船掉落+30%
        effects.voidEventFrequency = 2.0  -- 虚空事件频率×2
    elseif theme.id == "ALLIANCE_WAR" then
        effects.battleXpBonus = 0.5       -- 战斗经验+50%
        effects.lootBonus = 0.2           -- 战利品+20%
    elseif theme.id == "TRADE_FEDERATION" then
        effects.tradeEfficiency = 2.0      -- 交易效率×2
        effects.marketDiscount = 0.2       -- 市场折扣20%
    elseif theme.id == "FRONTIER_EXPLORE" then
        effects.expeditionYield = 0.3      -- 远征产出+30%
        effects.rareDiscoveries = 0.3      -- 稀有发现+30%
    end
    
    V2State.themeEffects = effects
    return effects
end

--- 获取主题加成（用于战斗/经济计算）
function SeasonSystemV2.getThemeBonus(bonusType)
    local effects = V2State.themeEffects
    if not effects then
        effects = SeasonSystemV2.applyThemeEffects()
    end
    return effects[bonusType] or 0
end

-- ============================================================================
-- 通行证系统
-- ============================================================================

--- 购买高级通行证
function SeasonSystemV2.purchasePremiumPass()
    if V2State.passPurchased then
        return false, "已购买高级通行证"
    end
    
    V2State.passPurchased = true
    V2State.passLevel = 1  -- 购买即升1级
    
    -- 发放首级奖励
    SeasonSystemV2.claimPassReward(1, "PREMIUM")
    
    return true, "高级通行证购买成功！"
end

--- 获取通行证等级
function SeasonSystemV2.getPassLevel()
    return V2State.passLevel
end

--- 获取通行证状态
function SeasonSystemV2.getPassState()
    return {
        level = V2State.passLevel,
        purchased = V2State.passPurchased,
        maxLevel = 40,
    }
end

--- 领取通行证奖励
function SeasonSystemV2.claimPassReward(level, tier)
    tier = tier or (V2State.passPurchased and "PREMIUM" or "FREE")
    local rewards = SEASON_PASS_TIERS[tier]
    
    for _, reward in ipairs(rewards) do
        if reward.level == level then
            local claimedKey = tier .. "_" .. level
            if not V2State["passClaimed_" .. claimedKey] then
                V2State["passClaimed_" .. claimedKey] = true
                
                -- 发放奖励
                SeasonSystemV2.grantPassReward(reward.reward)
                
                return true, "已领取: " .. reward.desc
            else
                return false, "该奖励已领取"
            end
        end
    end
    
    return false, "奖励不存在"
end

--- 发放通行证奖励
function SeasonSystemV2.grantPassReward(reward)
    if not reward then return end
    
    local RewardSystem = _G.RewardSystem or {}
    
    if reward.type == "CURRENCY" then
        -- 发放货币
        local rm = require("game.systems.ResourceManager")
        if rm then rm.addResource(reward.id, reward.amount) end
    elseif reward.type == "SHIP" then
        -- 发放舰船
        local FleetManager = require("game.systems.FleetManager")
        if FleetManager then
            for i = 1, (reward.amount or 1) do
                FleetManager.addToReserve(reward.id)
            end
        end
    elseif reward.type == "SKIN" or reward.type == "MODULE" or reward.type == "TITLE" then
        -- 解锁皮肤/模块/称号
        if LiverySystem then
            LiverySystem.unlockSkin(reward.id)
        end
    elseif reward.type == "COMMANDER_EXP" then
        -- 指挥官经验
        if Commander and Commander.addExperience then
            Commander.addExperience(reward.amount)
        end
    end
    
    -- 通知
    if NotifyPanel then
        NotifyPanel.push({
            type = "SEASON_REWARD",
            title = "通行证奖励",
            message = reward.desc or "奖励已发放",
        })
    end
end

--- 获取通行证奖励列表
function SeasonSystemV2.getPassRewards()
    local freeRewards = {}
    local premiumRewards = {}
    
    for _, reward in ipairs(SEASON_PASS_TIERS.FREE) do
        table.insert(freeRewards, {
            level = reward.level,
            desc = reward.desc,
            icon = reward.icon,
            claimed = V2State["passClaimed_FREE_" .. reward.level] or false,
            tier = "FREE",
        })
    end
    
    for _, reward in ipairs(SEASON_PASS_TIERS.PREMIUM) do
        table.insert(premiumRewards, {
            level = reward.level,
            desc = reward.desc,
            icon = reward.icon,
            claimed = V2State["passClaimed_PREMIUM_" .. reward.level] or false,
            tier = "PREMIUM",
            locked = not V2State.passPurchased,
        })
    end
    
    return { free = freeRewards, premium = premiumRewards }
end

-- ============================================================================
-- 赛季专属任务
-- ============================================================================

--- 更新专属任务进度
function SeasonSystemV2.updateExclusiveTaskProgress(taskId, increment)
    increment = increment or 1
    
    for _, task in ipairs(SEASON_EXCLUSIVE_TASKS) do
        if task.id == taskId then
            if not V2State.exclusiveTasksProgress[taskId] then
                V2State.exclusiveTasksProgress[taskId] = 0
            end
            
            V2State.exclusiveTasksProgress[taskId] = V2State.exclusiveTasksProgress[taskId] + increment
            
            -- 限制上限
            if task.target then
                V2State.exclusiveTasksProgress[taskId] = math.min(
                    V2State.exclusiveTasksProgress[taskId], task.target)
            end
            
            -- 检查完成
            if V2State.exclusiveTasksProgress[taskId] >= task.target then
                SeasonSystemV2.claimExclusiveTaskReward(taskId)
            end
            
            return true, "进度已更新"
        end
    end
    
    return false, "任务不存在"
end

--- 领取专属任务奖励
function SeasonSystemV2.claimExclusiveTaskReward(taskId)
    if V2State.exclusiveTasksClaimed[taskId] then
        return false, "已领取"
    end
    
    for _, task in ipairs(SEASON_EXCLUSIVE_TASKS) do
        if task.id == taskId then
            if (V2State.exclusiveTasksProgress[taskId] or 0) < task.target then
                return false, "任务未完成"
            end
            
            V2State.exclusiveTasksClaimed[taskId] = true
            
            -- 增加赛季积分
            if task.reward and task.reward.points then
                RuntimeSeasonState.playerPoints = RuntimeSeasonState.playerPoints + task.reward.points
            end
            
            if NotifyPanel then
                NotifyPanel.push({
                    type = "TASK_COMPLETE",
                    title = "赛季专属任务完成",
                    message = task.desc .. " (+" .. (task.reward.points or 0) .. " 赛季积分)",
                })
            end
            
            return true, "奖励已发放"
        end
    end
    
    return false, "任务不存在"
end

--- 获取专属任务列表
function SeasonSystemV2.getExclusiveTasks()
    local tasks = {}
    for _, task in ipairs(SEASON_EXCLUSIVE_TASKS) do
        local progress = V2State.exclusiveTasksProgress[task.id] or 0
        local completed = progress >= task.target
        local claimed = V2State.exclusiveTasksClaimed[task.id] or false
        
        table.insert(tasks, {
            id = task.id,
            desc = task.desc,
            target = task.target,
            progress = progress,
            completed = completed,
            claimed = claimed,
            reward = task.reward,
            icon = task.icon,
        })
    end
    return tasks
end

-- ============================================================================
-- 赛季商店
-- ============================================================================

--- 获取商店商品列表
function SeasonSystemV2.getShopItems()
    local items = {}
    for _, item in ipairs(SEASON_SHOP_ITEMS) do
        if item.available then
            local cost = item.cost.seasonPoints or 0
            table.insert(items, {
                id = item.id,
                desc = item.desc,
                cost = cost,
                canAfford = RuntimeSeasonState.playerPoints >= cost,
                purchased = V2State.shopHistory[item.id] or false,
            })
        end
    end
    return items
end

--- 购买商店商品
function SeasonSystemV2.purchaseShopItem(itemId)
    for _, item in ipairs(SEASON_SHOP_ITEMS) do
        if item.id == itemId then
            if V2State.shopHistory[itemId] then
                return false, "已购买"
            end
            
            local cost = item.cost.seasonPoints or 0
            if RuntimeSeasonState.playerPoints < cost then
                return false, "赛季积分不足"
            end
            
            RuntimeSeasonState.playerPoints = RuntimeSeasonState.playerPoints - cost
            V2State.shopHistory[itemId] = true
            
            -- 发放物品
            if item.items then
                for _, reward in ipairs(item.items) do
                    if type(reward) == "table" then
                        SeasonSystemV2.grantPassReward(reward)
                    else
                        -- 简单字符串视为皮肤ID
                        if LiverySystem then
                            LiverySystem.unlockSkin(reward)
                        end
                    end
                end
            end
            
            if NotifyPanel then
                NotifyPanel.push({
                    type = "PURCHASE_SUCCESS",
                    title = "购买成功",
                    message = item.desc,
                })
            end
            
            return true, "购买成功"
        end
    end
    
    return false, "商品不存在"
end

-- ============================================================================
-- 赛季排行榜
-- ============================================================================

--- 获取赛季排行榜（模拟）
function SeasonSystemV2.getSeasonLeaderboard(limit)
    limit = limit or 100
    
    -- 模拟排行榜数据
    local rankings = {
        { rank = 1, name = "银河征服者", points = 15000, title = "赛季冠军" },
        { rank = 2, name = "星际指挥官", points = 12500, title = "大师" },
        { rank = 3, name = "战术大师", points = 11000, title = "宗师" },
    }
    
    -- 添加当前玩家（如果存在）
    if playerState and playerState.name then
        local playerRank = {
            rank = -1,  -- 待计算
            name = playerState.name,
            points = RuntimeSeasonState.playerPoints or 0,
            title = SeasonSystemV2.getPlayerTitle(),
            isPlayer = true,
        }
        
        -- 简单插入排序
        for i, entry in ipairs(rankings) do
            if playerRank.points >= entry.points then
                table.insert(rankings, i, playerRank)
                break
            end
        end
        
        -- 重新编号
        for i, entry in ipairs(rankings) do
            entry.rank = i
            if entry.isPlayer then
                playerRank.rank = i
            end
        end
        
        return rankings, playerRank.rank
    end
    
    return rankings, -1
end

--- 获取玩家称号
function SeasonSystemV2.getPlayerTitle()
    local points = RuntimeSeasonState.playerPoints or 0
    if points >= 10000 then
        return "传奇指挥官"
    elseif points >= 5000 then
        return "大师"
    elseif points >= 2000 then
        return "精英"
    elseif points >= 500 then
        return "新星"
    else
        return "初出茅庐"
    end
end

-- ============================================================================
-- 存档
-- ============================================================================

function SeasonSystemV2.saveState()
    if playerState then
        playerState.seasonSystemV2 = {
            currentTheme = V2State.currentTheme,
            passLevel = V2State.passLevel,
            passPurchased = V2State.passPurchased,
            exclusiveTasksProgress = V2State.exclusiveTasksProgress,
            exclusiveTasksClaimed = V2State.exclusiveTasksClaimed,
            shopHistory = V2State.shopHistory,
            themeEffects = V2State.themeEffects,
        }
    end
end

function SeasonSystemV2.loadState(data)
    if data then
        V2State.currentTheme = data.currentTheme
        V2State.passLevel = data.passLevel or 0
        V2State.passPurchased = data.passPurchased or false
        V2State.exclusiveTasksProgress = data.exclusiveTasksProgress or {}
        V2State.exclusiveTasksClaimed = data.exclusiveTasksClaimed or {}
        V2State.shopHistory = data.shopHistory or {}
        V2State.themeEffects = data.themeEffects or {}
        
        -- 初始化主题效果
        SeasonSystemV2.applyThemeEffects()
    end
end

return SeasonSystemV2
