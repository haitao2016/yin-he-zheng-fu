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
