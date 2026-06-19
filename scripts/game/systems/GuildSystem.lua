---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/GuildSystem.lua -- 公会系统
-- V2.8 P0-6
-- ============================================================================

local GuildSystem = {}

-- ============================================================================
-- 公会运行时状态
-- ============================================================================

local GuildState = {
    playerGuildId = nil,
    playerRole = nil,
    memberOnline = {},
}

-- 运行时公会数据
local RuntimeGuilds = {}

-- ============================================================================
-- 公会查询
-- ============================================================================

-- 获取公会列表
function GuildSystem.getGuildList()
    local list = {}
    for id, guild in pairs(RuntimeGuilds) do
        table.insert(list, {
            id = id,
            name = guild.name,
            tag = guild.tag,
            level = guild.level,
            memberCount = #guild.members,
            maxMembers = guild.maxMembers,
            leaderName = GuildSystem.getMemberName(guild, guild.leaderId),
        })
    end
    -- 按等级排序
    table.sort(list, function(a, b) return a.level > b.level end)
    return list
end

-- 获取公会信息
function GuildSystem.getGuild(guildId)
    local guild = RuntimeGuilds[guildId]
    if not guild then return nil end

    return {
        id = guild.id,
        name = guild.name,
        tag = guild.tag,
        leaderId = guild.leaderId,
        leaderName = GuildSystem.getMemberName(guild, guild.leaderId),
        level = guild.level,
        exp = guild.exp,
        members = GuildSystem.getMemberList(guild),
        maxMembers = guild.maxMembers,
        announcement = guild.announcement,
        joinType = guild.settings and guild.settings.joinType or "APPROVAL",
        createdAt = guild.createdAt,
    }
end

-- 获取当前玩家的公会
function GuildSystem.getPlayerGuild()
    return GuildSystem.getGuild(GuildState.playerGuildId)
end

-- 获取成员列表
function GuildSystem.getMemberList(guild)
    if not guild then return {} end

    local members = {}
    for _, m in ipairs(guild.members) do
        table.insert(members, {
            id = m.id,
            name = m.name,
            role = m.role,
            roleName = GUILD_ROLES[m.role] and GUILD_ROLES[m.role].name or "成员",
            contribution = m.contribution,
            joinTime = m.joinTime,
            isOnline = GuildState.memberOnline[m.id] == true,
        })
    end
    -- 按角色和贡献排序
    table.sort(members, function(a, b)
        if a.role ~= b.role then
            if a.role == "LEADER" then return true
            elseif b.role == "LEADER" then return false
            elseif a.role == "OFFICER" then return true
            elseif b.role == "OFFICER" then return false
            end
        end
        return a.contribution > b.contribution
    end)
    return members
end

-- 获取成员名称
function GuildSystem.getMemberName(guild, memberId)
    if not guild then return "未知" end
    for _, m in ipairs(guild.members) do
        if m.id == memberId then return m.name end
    end
    return "未知"
end

-- 检查玩家是否在公会中
function GuildSystem.isInGuild()
    return GuildState.playerGuildId ~= nil
end

-- ============================================================================
-- 公会创建
-- ============================================================================

-- 创建公会
function GuildSystem.createGuild(name, tag, playerId, playerName)
    if not playerId or not playerName then
        return false, "玩家信息无效"
    end

    if GuildState.playerGuildId then
        return false, "已在公会中"
    end

    -- 验证名称
    if not name or #name < 2 or #name > 16 then
        return false, "公会名称长度需在 2-16 字符之间"
    end

    -- 验证标签
    if not tag or #tag < 2 or #tag > 5 then
        return false, "公会标签长度需在 2-5 字符之间"
    end

    -- 检查标签唯一性
    for _, guild in pairs(RuntimeGuilds) do
        if guild.tag == tag then
            return false, "公会标签已被使用"
        end
    end

    -- 创建公会
    local guildId = "GUILD_" .. tostring(math.random(100000, 999999))
    RuntimeGuilds[guildId] = {
        id = guildId,
        name = name,
        tag = tag,
        leaderId = playerId,
        members = {
            {
                id = playerId,
                name = playerName,
                role = "LEADER",
                joinTime = os.time(),
                contribution = 0,
            }
        },
        level = 1,
        exp = 0,
        maxMembers = GUILD_LEVEL_REWARDS[1].memberSlot,
        announcement = "欢迎加入 " .. name,
        createdAt = os.time(),
        settings = {
            joinType = "APPROVAL",
        },
        applications = {},
        dailyTasks = {},
        weeklyProgress = {},
    }

    -- 更新玩家状态
    GuildState.playerGuildId = guildId
    GuildState.playerRole = "LEADER"

    -- 保存
    GuildSystem.saveState()

    return true, "公会创建成功: " .. name, guildId
end

-- ============================================================================
-- 公会加入/离开
-- ============================================================================

-- 加入公会
function GuildSystem.joinGuild(guildId, playerId, playerName)
    local guild = RuntimeGuilds[guildId]
    if not guild then
        return false, "公会不存在"
    end

    if GuildState.playerGuildId then
        return false, "已在公会中"
    end

    if #guild.members >= guild.maxMembers then
        return false, "公会已满"
    end

    if guild.settings.joinType == "APPROVAL" then
        -- 需要审批
        guild.applications = guild.applications or {}
        table.insert(guild.applications, {
            playerId = playerId,
            playerName = playerName,
            applyTime = os.time(),
            message = "申请加入公会",
        })
        return false, "申请已提交，等待审批"
    elseif guild.settings.joinType == "OPEN" then
        -- 直接加入
        table.insert(guild.members, {
            id = playerId,
            name = playerName,
            role = "MEMBER",
            joinTime = os.time(),
            contribution = 0,
        })
        GuildState.playerGuildId = guildId
        GuildState.playerRole = "MEMBER"
        GuildSystem.saveState()
        return true, "加入成功"
    elseif guild.settings.joinType == "INVITE" then
        return false, "该公会仅可通过邀请加入"
    end

    return false, "加入失败"
end

-- 离开公会
function GuildSystem.leaveGuild(playerId)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then
        return false, "不在公会中"
    end

    if GuildState.playerRole == "LEADER" then
        -- 会长转让或解散
        if #guild.members > 1 then
            return false, "会长必须先转让公会或解散公会"
        else
            -- 解散公会
            RuntimeGuilds[GuildState.playerGuildId] = nil
        end
    else
        -- 移除成员
        for i, m in ipairs(guild.members) do
            if m.id == playerId then
                table.remove(guild.members, i)
                break
            end
        end
    end

    GuildState.playerGuildId = nil
    GuildState.playerRole = nil
    GuildSystem.saveState()

    return true, "已离开公会"
end

-- ============================================================================
-- 审批系统
-- ============================================================================

-- 获取申请列表
function GuildSystem.getApplications()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end

    if not GUILD_ROLES[GuildState.playerRole] or not GUILD_ROLES[GuildState.playerRole].permissions.approve then
        return {}
    end

    return guild.applications or {}
end

-- 审批申请
function GuildSystem.approveApplication(guildId, applicantId, approve)
    local guild = RuntimeGuilds[guildId]
    if not guild then return false, "公会不存在" end

    if not GUILD_ROLES[GuildState.playerRole] or not GUILD_ROLES[GuildState.playerRole].permissions.kick then
        return false, "没有审批权限"
    end

    local appIndex = nil
    local applicant = nil
    for i, app in ipairs(guild.applications or {}) do
        if app.playerId == applicantId then
            appIndex = i
            applicant = app
            break
        end
    end

    if not applicant then
        return false, "申请不存在"
    end

    if approve then
        -- 批准加入
        if #guild.members < guild.maxMembers then
            table.insert(guild.members, {
                id = applicant.playerId,
                name = applicant.playerName,
                role = "MEMBER",
                joinTime = os.time(),
                contribution = 0,
            })
            table.remove(guild.applications, appIndex)
        else
            return false, "公会已满"
        end
    else
        -- 拒绝申请
        table.remove(guild.applications, appIndex)
    end

    return true, approve and "已批准加入" or "已拒绝申请"
end

-- ============================================================================
-- 公会管理
-- ============================================================================

-- 修改公告
function GuildSystem.setAnnouncement(announcement)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    if not GUILD_ROLES[GuildState.playerRole] or not GUILD_ROLES[GuildState.playerRole].permissions.settings then
        return false, "没有设置权限"
    end

    guild.announcement = announcement
    return true, "公告已更新"
end

-- 修改加入类型
function GuildSystem.setJoinType(joinType)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    if not GUILD_ROLES[GuildState.playerRole] or not GUILD_ROLES[GuildState.playerRole].permissions.settings then
        return false, "没有设置权限"
    end

    guild.settings = guild.settings or {}
    guild.settings.joinType = joinType
    return true, "加入类型已更新"
end

-- 踢出成员
function GuildSystem.kickMember(targetId)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    if not GUILD_ROLES[GuildState.playerRole] or not GUILD_ROLES[GuildState.playerRole].permissions.kick then
        return false, "没有踢人权限"
    end

    if targetId == GuildState.playerGuildId then
        return false, "不能踢出自己"
    end

    local targetRole = nil
    for _, m in ipairs(guild.members) do
        if m.id == targetId then
            targetRole = m.role
            break
        end
    end

    -- 检查权限
    if targetRole == "LEADER" then
        return false, "不能踢出会长"
    end
    if targetRole == "OFFICER" and GuildState.playerRole ~= "LEADER" then
        return false, "只有会长可以踢出官员"
    end

    for i, m in ipairs(guild.members) do
        if m.id == targetId then
            table.remove(guild.members, i)
            break
        end
    end

    return true, "已踢出成员"
end

-- 晋升成员
function GuildSystem.promoteMember(targetId)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    if not GUILD_ROLES[GuildState.playerRole] or not GUILD_ROLES[GuildState.playerRole].permissions.promote then
        return false, "没有晋升权限"
    end

    for _, m in ipairs(guild.members) do
        if m.id == targetId then
            if m.role == "MEMBER" then
                m.role = "OFFICER"
                return true, "已晋升为官员"
            else
                return false, "该成员已是最高职位"
            end
        end
    end

    return false, "成员不存在"
end

-- 转让会长
function GuildSystem.transferLeadership(targetId)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    if GuildState.playerRole ~= "LEADER" then
        return false, "只有会长可以转让"
    end

    for _, m in ipairs(guild.members) do
        if m.id == targetId then
            m.role = "LEADER"
            -- 原会长降为官员
            for _, member in ipairs(guild.members) do
                if member.id == playerState and playerState.id then
                    -- 找到并降级
                    -- (此处需要正确的玩家ID)
                end
            end
            guild.leaderId = targetId
            GuildState.playerRole = "OFFICER"
            return true, "会长已转让"
        end
    end

    return false, "成员不存在"
end

-- 解散公会
function GuildSystem.disbandGuild()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    if GuildState.playerRole ~= "LEADER" then
        return false, "只有会长可以解散公会"
    end

    RuntimeGuilds[GuildState.playerGuildId] = nil
    GuildState.playerGuildId = nil
    GuildState.playerRole = nil
    GuildSystem.saveState()

    return true, "公会已解散"
end

-- ============================================================================
-- 公会贡献
-- ============================================================================

-- 捐赠资源
function GuildSystem.contribute(resourceType, amount)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    -- 消耗资源
    if resourceType == "metal" and playerState then
        if (playerState.metal or 0) < amount then
            return false, "金属不足"
        end
        playerState.metal = playerState.metal - amount
    else
        return false, "不支持的资源类型"
    end

    -- 更新成员贡献
    for _, m in ipairs(guild.members) do
        if m.id == playerState and playerState.id then
            m.contribution = m.contribution + amount
            break
        end
    end

    -- 增加公会经验
    guild.exp = guild.exp + amount

    -- 检查升级
    GuildSystem.checkLevelUp()

    -- 更新每日任务进度
    GuildSystem.updateTaskProgress("DONATE", amount)

    -- 保存
    GuildSystem.saveState()

    return true, "贡献成功: " .. amount .. " 金属"
end

-- 检查公会升级
function GuildSystem.checkLevelUp()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return end

    for i = #GUILD_LEVEL_REWARDS, 1, -1 do
        local levelReward = GUILD_LEVEL_REWARDS[i]
        if guild.exp >= levelReward.exp and guild.level < levelReward.level then
            guild.level = levelReward.level
            guild.maxMembers = levelReward.memberSlot

            if NotifyPanel then
                NotifyPanel.push({
                    type = "GUILD_LEVEL_UP",
                    title = "公会升级",
                    message = "公会等级提升至 " .. guild.level .. " 级！",
                })
            end
            break
        end
    end
end

-- 获取公会等级加成
function GuildSystem.getGuildBonus()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end

    local levelReward = nil
    for _, lr in ipairs(GUILD_LEVEL_REWARDS) do
        if lr.level == guild.level then
            levelReward = lr
            break
        end
    end

    return levelReward and levelReward.reward or {}
end

-- ============================================================================
-- 公会任务
-- ============================================================================

-- 更新任务进度
function GuildSystem.updateTaskProgress(taskType, value)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return end

    guild.dailyTasks = guild.dailyTasks or {}

    for _, task in ipairs(GUILD_DAILY_TASKS) do
        if task.type == taskType then
            guild.dailyTasks[task.id] = (guild.dailyTasks[task.id] or 0) + value
        end
    end
end

-- 获取每日任务
function GuildSystem.getDailyTasks()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end

    local tasks = {}
    for _, task in ipairs(GUILD_DAILY_TASKS) do
        local progress = guild.dailyTasks and guild.dailyTasks[task.id] or 0
        local completed = progress >= task.target

        table.insert(tasks, {
            id = task.id,
            name = task.name,
            desc = task.desc,
            target = task.target,
            progress = math.min(progress, task.target),
            completed = completed,
            reward = task.reward,
        })
    end
    return tasks
end

-- 领取任务奖励
function GuildSystem.claimTaskReward(taskId)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end

    local task = nil
    for _, t in ipairs(GUILD_DAILY_TASKS) do
        if t.id == taskId then task = t; break end
    end
    if not task then return false, "任务不存在" end

    local progress = guild.dailyTasks and guild.dailyTasks[taskId] or 0
    if progress < task.target then
        return false, "任务未完成"
    end

    -- 发放奖励
    if task.reward.contribution then
        for _, m in ipairs(guild.members) do
            if m.id == playerState and playerState.id then
                m.contribution = m.contribution + task.reward.contribution
                break
            end
        end
    end
    if task.reward.guildExp then
        guild.exp = guild.exp + task.reward.guildExp
        GuildSystem.checkLevelUp()
    end

    -- 标记已领取
    guild.dailyTasks[taskId .. "_claimed"] = true

    return true, "奖励已领取"
end

-- ============================================================================
-- 成员在线状态
-- ============================================================================

function GuildSystem.setOnlineStatus(playerId, online)
    GuildState.memberOnline[playerId] = online
end

function GuildSystem.isOnline(playerId)
    return GuildState.memberOnline[playerId] == true
end

-- ============================================================================
-- 存档
-- ============================================================================

function GuildSystem.saveState()
    if playerState then
        playerState.guildState = {
            playerGuildId = GuildState.playerGuildId,
            playerRole = GuildState.playerRole,
        }
        playerState.runtimeGuilds = RuntimeGuilds
    end
end

function GuildSystem.loadState(data)
    if data then
        GuildState.playerGuildId = data.playerGuildId
        GuildState.playerRole = data.playerRole
        RuntimeGuilds = playerState and playerState.runtimeGuilds or {}
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return GuildSystem

-- ============================================================================
-- V3.0 P1-2: 公会系统扩展
-- 公会战/公会任务/公会商店/公会日志
-- ============================================================================

local GuildSystemV2 = {}

-- ============================================================================
-- 公会战常量
-- ============================================================================
GUILD_WAR_CONFIG = {
    duration = 3600,           -- 战斗持续1小时
    preparationTime = 1800,    -- 准备时间30分钟
    matchSize = 3,             -- 每队3人
    matchCount = 3,            -- 3场战斗
    winScore = 1,              -- 胜利得1分
    drawScore = 0,             -- 平局得0分
    participationReward = 50,   -- 参与奖励公会币
    winReward = 200,           -- 胜利奖励公会币
}

-- 公会商店商品
GUILD_SHOP_ITEMS = {
    { id = "SHOP_GUILD_SKIN", cost = { guildCoin = 1000 }, items = { "SKIN_GUILD_EXCLUSIVE" },
      desc = "公会专属涂装", available = true },
    { id = "SHOP_GUILD_MODULE", cost = { guildCoin = 500 }, items = { "MODULE_GUILD_BUFF" },
      desc = "公会增益模块×1", available = true },
    { id = "SHOP_GUILD_EXP", cost = { guildCoin = 200 }, items = { "COMMANDER_EXP", amount = 500 },
      desc = "指挥官经验×500", available = true },
    { id = "SHOP_GUILD_CREDITS", cost = { guildCoin = 300 }, items = { "credits", amount = 3000 },
      desc = "星币×3000", available = true },
    { id = "SHOP_GUILD_CLAIM", cost = { guildCoin = 800 }, items = { "LEGACY_FRAGMENT" },
      desc = "文明遗产碎片×1", available = true },
}

-- ============================================================================
-- V2 运行时状态
-- ============================================================================
local V2State = {
    guildWarState = {
        currentWar = nil,       -- { enemyGuildId, preparationEnd, battleStart, battleEnd, status }
        matchResults = {},      -- { matchId -> { winner, scores } }
        warHistory = {},        -- 历史战绩
    },
    guildShopHistory = {},     -- 商店购买记录
    guildLog = {},             -- 公会日志
    memberContribution = {},    -- { [memberId] = totalContribution }
}

-- ============================================================================
-- 公会战系统
-- ============================================================================

--- 获取当前公会战状态
function GuildSystemV2.getWarState()
    return V2State.guildWarState.currentWar
end

--- 检查是否可以发起公会战
function GuildSystemV2.canStartWar()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end
    
    if guild.level < 3 then
        return false, "公会需达到3级才能发起公会战"
    end
    
    if V2State.guildWarState.currentWar then
        return false, "已有进行中的公会战"
    end
    
    -- 检查冷却（每周只能发起1次）
    local lastWar = V2State.guildWarState.warHistory[#V2State.guildWarState.warHistory]
    if lastWar then
        local weekStart = SeasonSystem and SeasonSystem.getWeekStart and SeasonSystem.getWeekStart() or os.time()
        if lastWar.timestamp and lastWar.timestamp > weekStart then
            return false, "本周已发起过公会战"
        end
    end
    
    return true, "可以发起公会战"
end

--- 发起公会战
function GuildSystemV2.startWar(enemyGuildId)
    local canStart, msg = GuildSystemV2.canStartWar()
    if not canStart then
        return false, msg
    end
    
    local enemyGuild = RuntimeGuilds[enemyGuildId]
    if not enemyGuild then
        return false, "对方公会不存在"
    end
    
    local now = os.time()
    
    V2State.guildWarState.currentWar = {
        guildId = GuildState.playerGuildId,
        enemyGuildId = enemyGuildId,
        enemyGuildName = enemyGuild.name,
        preparationEnd = now + GUILD_WAR_CONFIG.preparationTime,
        battleStart = now + GUILD_WAR_CONFIG.preparationTime,
        battleEnd = now + GUILD_WAR_CONFIG.preparationTime + GUILD_WAR_CONFIG.duration,
        status = "PREPARATION",
        myScore = 0,
        enemyScore = 0,
        matches = {},           -- { matchIndex -> { status, winner, myShips, enemyShips } }
        timestamp = now,
    }
    
    -- 添加日志
    GuildSystemV2.addLog("GUILD", "公会战开始", "与 " .. enemyGuild.name .. " 的公会战已开始！")
    
    return true, "公会战已开始！"
end

--- 获取公会战对阵信息
function GuildSystemV2.getWarMatchInfo()
    local war = V2State.guildWarState.currentWar
    if not war then return nil end
    
    return {
        myGuild = RuntimeGuilds[war.guildId] and RuntimeGuilds[war.guildId].name,
        enemyGuild = war.enemyGuildName,
        status = war.status,
        myScore = war.myScore,
        enemyScore = war.enemyScore,
        timeRemaining = war.battleEnd - os.time(),
        matches = war.matches,
    }
end

--- 加入公会战匹配
function GuildSystemV2.joinWarMatch(matchIndex, shipIds)
    local war = V2State.guildWarState.currentWar
    if not war or war.status ~= "PREPARATION" then
        return false, "公会战未在准备阶段"
    end
    
    if os.time() < war.preparationEnd then
        return false, "准备时间还未结束"
    end
    
    -- 创建匹配
    war.matches[matchIndex] = {
        status = "READY",
        myPlayer = playerState and playerState.id,
        myShips = shipIds,
        enemyPlayer = nil,
        enemyShips = {},
        winner = nil,
        myScore = 0,
        enemyScore = 0,
    }
    
    war.status = "BATTLE"
    
    return true, "已加入第" .. matchIndex .. "场战斗"
end

--- 完成公会战战斗并结算
function GuildSystemV2.completeWarMatch(matchIndex, winner, myScore, enemyScore)
    local war = V2State.guildWarState.currentWar
    if not war then return false, "没有进行中的公会战" end
    
    local match = war.matches[matchIndex]
    if not match then return false, "匹配不存在" end
    
    match.status = "COMPLETED"
    match.winner = winner
    match.myScore = myScore or 0
    match.enemyScore = enemyScore or 0
    
    -- 更新总分
    if winner == "MY_GUILD" then
        war.myScore = war.myScore + GUILD_WAR_CONFIG.winScore
    elseif winner == "ENEMY" then
        war.enemyScore = war.enemyScore + GUILD_WAR_CONFIG.winScore
    end
    
    -- 检查公会战是否结束
    local completedMatches = 0
    for _, m in pairs(war.matches) do
        if m.status == "COMPLETED" then
            completedMatches = completedMatches + 1
        end
    end
    
    if completedMatches >= GUILD_WAR_CONFIG.matchCount then
        GuildSystemV2.endWar()
    end
    
    return true, "第" .. matchIndex .. "场战斗已完成"
end

--- 结束公会战
function GuildSystemV2.endWar()
    local war = V2State.guildWarState.currentWar
    if not war then return false end
    
    -- 判定胜负
    local result
    if war.myScore > war.enemyScore then
        result = "WIN"
    elseif war.myScore < war.enemyScore then
        result = "LOSE"
    else
        result = "DRAW"
    end
    
    -- 记录历史
    table.insert(V2State.guildWarState.warHistory, {
        timestamp = os.time(),
        enemyGuild = war.enemyGuildName,
        myScore = war.myScore,
        enemyScore = war.enemyScore,
        result = result,
    })
    
    -- 限制历史数量
    while #V2State.guildWarState.warHistory > 20 do
        table.remove(V2State.guildWarState.warHistory, 1)
    end
    
    -- 发放奖励
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if guild then
        guild.guildCoins = guild.guildCoins or 0
        
        if result == "WIN" then
            guild.guildCoins = guild.guildCoins + 500
            GuildSystemV2.addLog("GUILD", "公会战胜利", "击败 " .. war.enemyGuildName .. "，获得 500 公会币！")
        elseif result == "DRAW" then
            guild.guildCoins = guild.guildCoins + 200
            GuildSystemV2.addLog("GUILD", "公会战平局", "与 " .. war.enemyGuildName .. " 战平，获得 200 公会币")
        else
            guild.guildCoins = guild.guildCoins + 100
            GuildSystemV2.addLog("GUILD", "公会战失败", "负于 " .. war.enemyGuildName .. "，获得 100 公会币")
        end
    end
    
    V2State.guildWarState.currentWar = nil
    
    return true, "公会战结束: " .. result
end

--- 获取公会战历史
function GuildSystemV2.getWarHistory()
    return V2State.guildWarState.warHistory
end

-- ============================================================================
-- 公会商店系统
-- ============================================================================

--- 获取公会商店商品
function GuildSystemV2.getShopItems()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end
    
    local items = {}
    for _, item in ipairs(GUILD_SHOP_ITEMS) do
        if item.available then
            local cost = item.cost.guildCoin or 0
            table.insert(items, {
                id = item.id,
                desc = item.desc,
                cost = cost,
                canAfford = (guild.guildCoins or 0) >= cost,
                purchased = V2State.guildShopHistory[item.id] or false,
            })
        end
    end
    
    return items
end

--- 购买公会商店商品
function GuildSystemV2.purchaseShopItem(itemId)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return false, "不在公会中" end
    
    for _, item in ipairs(GUILD_SHOP_ITEMS) do
        if item.id == itemId then
            if V2State.guildShopHistory[itemId] then
                return false, "已购买"
            end
            
            local cost = item.cost.guildCoin or 0
            if (guild.guildCoins or 0) < cost then
                return false, "公会币不足"
            end
            
            guild.guildCoins = guild.guildCoins - cost
            V2State.guildShopHistory[itemId] = true
            
            -- 发放物品
            if item.items then
                for _, reward in ipairs(item.items) do
                    if type(reward) == "table" then
                        -- 处理奖励
                        if reward.type == "CURRENCY" then
                            -- 发放货币
                        end
                    end
                end
            end
            
            GuildSystemV2.addLog("SHOP", "商店购买", "购买了 " .. item.desc)
            
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

--- 获取公会币余额
function GuildSystemV2.getGuildCoins()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    return guild and guild.guildCoins or 0
end

-- ============================================================================
-- 公会日志系统
-- ============================================================================

local MAX_LOG_ENTRIES = 100

--- 添加公会日志
function GuildSystemV2.addLog(category, title, message)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return end
    
    guild.guildLog = guild.guildLog or {}
    
    table.insert(guild.guildLog, {
        id = #guild.guildLog + 1,
        timestamp = os.time(),
        category = category,
        title = title,
        message = message,
        actorName = playerState and playerState.name,
    })
    
    -- 限制日志数量
    while #guild.guildLog > MAX_LOG_ENTRIES do
        table.remove(guild.guildLog, 1)
    end
end

--- 获取公会日志
function GuildSystemV2.getLog(category, limit)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end
    
    local logs = guild.guildLog or {}
    
    if category then
        local filtered = {}
        for _, log in ipairs(logs) do
            if log.category == category then
                table.insert(filtered, log)
            end
        end
        logs = filtered
    end
    
    -- 限制返回数量
    if limit and #logs > limit then
        local result = {}
        for i = #logs - limit + 1, #logs do
            table.insert(result, logs[i])
        end
        return result
    end
    
    return logs
end

--- 获取日志类别统计
function GuildSystemV2.getLogStats()
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end
    
    local logs = guild.guildLog or {}
    local stats = {
        TOTAL = #logs,
        MEMBER = 0,
        GUILD = 0,
        SHOP = 0,
        WAR = 0,
        OTHER = 0,
    }
    
    for _, log in ipairs(logs) do
        local cat = log.category
        if cat == "MEMBER" or cat == "JOIN" or cat == "LEAVE" then
            stats.MEMBER = stats.MEMBER + 1
        elseif cat == "GUILD" then
            stats.GUILD = stats.GUILD + 1
        elseif cat == "SHOP" then
            stats.SHOP = stats.SHOP + 1
        elseif cat == "WAR" then
            stats.WAR = stats.WAR + 1
        else
            stats.OTHER = stats.OTHER + 1
        end
    end
    
    return stats
end

-- ============================================================================
-- 公会权限系统
-- ============================================================================

--- 检查是否有权限执行操作
function GuildSystemV2.hasPermission(action)
    local role = GuildState.playerRole
    if not role then return false end
    
    local permissions = {
        LEADER = { "ALL" },
        OFFICER = { "KICK", "APPROVE", "EDIT_ANNOUNCEMENT", "SET_WAR", "VIEW_LOG" },
        MEMBER = { "VIEW_INFO", "PARTICIPATE_WAR", "VIEW_LOG" },
    }
    
    local rolePerms = permissions[role]
    if not rolePerms then return false end
    
    -- 会长拥有所有权限
    if role == "LEADER" then return true end
    
    for _, perm in ipairs(rolePerms) do
        if perm == action or perm == "ALL" then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- 成员贡献排行
-- ============================================================================

--- 记录成员贡献
function GuildSystemV2.recordContribution(playerId, amount)
    V2State.memberContribution[playerId] = (V2State.memberContribution[playerId] or 0) + amount
    
    -- 同步到公会数据
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if guild then
        for _, m in ipairs(guild.members) do
            if m.id == playerId then
                m.contribution = (m.contribution or 0) + amount
                break
            end
        end
    end
end

--- 获取成员贡献排行
function GuildSystemV2.getContributionRanking(limit)
    local guild = RuntimeGuilds[GuildState.playerGuildId]
    if not guild then return {} end
    
    local ranking = {}
    for _, m in ipairs(guild.members) do
        table.insert(ranking, {
            id = m.id,
            name = m.name,
            contribution = m.contribution or 0,
            role = m.role,
        })
    end
    
    table.sort(ranking, function(a, b)
        if a.contribution ~= b.contribution then
            return a.contribution > b.contribution
        end
        return a.name < b.name
    end)
    
    -- 限制数量
    if limit then
        local result = {}
        for i = 1, math.min(limit, #ranking) do
            result[i] = ranking[i]
            result[i].rank = i
        end
        return result
    end
    
    return ranking
end

--- 获取个人排名
function GuildSystemV2.getPersonalRank()
    local myId = playerState and playerState.id
    if not myId then return nil end
    
    local ranking = GuildSystemV2.getContributionRanking()
    for i, entry in ipairs(ranking) do
        if entry.id == myId then
            return {
                rank = i,
                totalMembers = #ranking,
                contribution = entry.contribution,
            }
        end
    end
    
    return nil
end

-- ============================================================================
-- 存档
-- ============================================================================

function GuildSystemV2.saveState()
    if playerState then
        playerState.guildSystemV2 = {
            guildWarState = V2State.guildWarState,
            guildShopHistory = V2State.guildShopHistory,
            memberContribution = V2State.memberContribution,
        }
    end
end

function GuildSystemV2.loadState(data)
    if data then
        V2State.guildWarState = data.guildWarState or {
            currentWar = nil,
            warHistory = {},
        }
        V2State.guildShopHistory = data.guildShopHistory or {}
        V2State.memberContribution = data.memberContribution or {}
    end
end

return GuildSystemV2
