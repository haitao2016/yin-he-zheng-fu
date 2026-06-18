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
