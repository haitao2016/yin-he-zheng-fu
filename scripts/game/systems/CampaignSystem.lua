---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/CampaignSystem.lua -- 战役模式系统
-- V2.8 P0-1
-- ============================================================================

local CampaignSystem = {}

-- ============================================================================
-- 战役状态
-- ============================================================================

local CampaignState = {
    currentChapter = nil,
    currentStage = nil,
    stageProgress = {},
    completedChapters = {},
    completedStages = {},
    dialogueHistory = {},
    playerChoices = {},
    inCampaignMode = false,
}

-- 临时运行时数据
local RuntimeStageData = {
    objectiveProgress = 0,
    objectiveTarget = 0,
    surviveTimer = 0,
    enemiesRemaining = 0,
    waveCount = 0,
}

-- ============================================================================
-- 章节与关卡查询
-- ============================================================================

-- 获取所有章节
function CampaignSystem.getChapters()
    return CAMPAIGN_CHAPTERS
end

-- 获取章节信息
function CampaignSystem.getChapter(chapterId)
    for _, chapter in ipairs(CAMPAIGN_CHAPTERS) do
        if chapter.id == chapterId then
            return chapter
        end
    end
    return nil
end

-- 获取关卡信息
function CampaignSystem.getStage(stageId)
    for _, chapter in ipairs(CAMPAIGN_CHAPTERS) do
        for _, stage in ipairs(chapter.stages) do
            if stage.id == stageId then
                return stage, chapter
            end
        end
    end
    return nil, nil
end

-- 获取章节的可玩关卡
function CampaignSystem.getPlayableStages(chapterId, playerWave)
    local chapter = CampaignSystem.getChapter(chapterId)
    if not chapter then return {} end

    local playable = {}
    for _, stage in ipairs(chapter.stages) do
        if playerWave >= stage.unlockWave and not CampaignState.completedStages[stage.id] then
            table.insert(playable, stage)
        end
    end
    return playable
end

-- 检查章节是否已解锁
function CampaignSystem.isChapterUnlocked(chapterId, playerWave)
    local chapter = CampaignSystem.getChapter(chapterId)
    if not chapter then return false end
    return playerWave >= chapter.requiredWave
end

-- ============================================================================
-- 关卡流程控制
-- ============================================================================

-- 开始关卡
function CampaignSystem.startStage(stageId, playerState)
    local stage, chapter = CampaignSystem.getStage(stageId)
    if not stage then
        return false, "关卡不存在"
    end

    -- 检查是否已通关
    if CampaignState.completedStages[stageId] then
        return false, "关卡已完成，可重复挑战"
    end

    -- 进入战役模式
    CampaignState.inCampaignMode = true
    CampaignState.currentChapter = chapter.id
    CampaignState.currentStage = stageId

    -- 初始化关卡数据
    RuntimeStageData.objectiveProgress = 0
    RuntimeStageData.objectiveTarget = stage.objectiveTarget or 0
    RuntimeStageData.surviveTimer = 0
    RuntimeStageData.enemiesRemaining = 0
    RuntimeStageData.waveCount = 0

    -- 计算敌舰总数
    local totalEnemies = 0
    for _, count in pairs(stage.enemyComp) do
        totalEnemies = totalEnemies + count
    end
    RuntimeStageData.enemiesRemaining = totalEnemies

    -- 显示开场对话
    local dialogueKey = stageId .. "_START"
    CampaignSystem.showDialogue(dialogueKey)

    -- 通知战斗系统开始战役关卡
    if BS then
        BS.campaignMode = true
        BS.campaignStage = stageId
        BS.campaignChapter = chapter.id
        BS.difficulty = STAGE_DIFFICULTY[stage.difficulty] or STAGE_DIFFICULTY.MEDIUM
    end

    return true, "关卡开始"
end

-- 更新关卡进度
function CampaignSystem.updateStageProgress(event, value)
    if not CampaignState.inCampaignMode then return end

    local stage = CampaignSystem.getStage(CampaignState.currentStage)
    if not stage then return end

    if stage.objective == "ASSAULT" or stage.objective == "ELIMINATE" then
        -- 击杀类目标
        if event == "ENEMY_KILLED" then
            RuntimeStageData.objectiveProgress = RuntimeStageData.objectiveProgress + 1
            RuntimeStageData.enemiesRemaining = math.max(0, RuntimeStageData.enemiesRemaining - 1)
        end
    elseif stage.objective == "DEFEND" then
        -- 防守类目标
        if event == "WAVE_SURVIVED" then
            RuntimeStageData.objectiveProgress = RuntimeStageData.objectiveProgress + 1
        end
    elseif stage.objective == "SURVIVE" then
        -- 生存类目标
        if event == "TIME_PASSED" then
            RuntimeStageData.surviveTimer = RuntimeStageData.surviveTimer + value
            RuntimeStageData.objectiveProgress = math.floor(RuntimeStageData.surviveTimer)
        end
    end

    -- 检查目标是否达成
    CampaignSystem.checkStageObjective()
end

-- 检查关卡目标达成
function CampaignSystem.checkStageObjective()
    local stage = CampaignSystem.getStage(CampaignState.currentStage)
    if not stage then return end

    local objectiveDef = STAGE_OBJECTIVES[stage.objective]
    if not objectiveDef then return end

    local completed = false

    if stage.objective == "ASSAULT" or stage.objective == "ELIMINATE" then
        completed = RuntimeStageData.enemiesRemaining <= 0
    elseif stage.objective == "DEFEND" then
        completed = RuntimeStageData.objectiveProgress >= stage.objectiveTarget
    elseif stage.objective == "SURVIVE" then
        completed = RuntimeStageData.objectiveProgress >= stage.objectiveTarget
    end

    if completed then
        CampaignSystem.completeStage(true)
    end
end

-- 关卡失败
function CampaignSystem.failStage()
    if not CampaignState.inCampaignMode then return end

    CampaignState.inCampaignMode = false

    -- 显示失败提示
    if NotifyPanel then
        NotifyPanel.push({
            type = "FAIL",
            title = "任务失败",
            message = "战役失败，可以重新挑战",
            icon = "fail",
        })
    end

    -- 重置状态
    if BS then
        BS.campaignMode = false
        BS.campaignStage = nil
    end
end

-- 完成任务
function CampaignSystem.completeStage(success)
    if not CampaignState.inCampaignMode then return end

    local stage, chapter = CampaignSystem.getStage(CampaignState.currentStage)
    if not stage then return end

    CampaignState.inCampaignMode = false

    if success then
        -- 标记关卡完成
        CampaignState.completedStages[CampaignState.currentStage] = true

        -- 计算奖励
        local rewards = CampaignSystem.calculateRewards(stage)

        -- 发放奖励
        CampaignSystem.grantRewards(rewards)

        -- 显示结束对话
        local dialogueKey = CampaignState.currentStage .. "_END"
        CampaignSystem.showDialogue(dialogueKey)

        -- 检查章节完成
        CampaignSystem.checkChapterCompletion(chapter)

        -- 显示奖励提示
        if NotifyPanel then
            NotifyPanel.push({
                type = "SUCCESS",
                title = "战役胜利",
                message = "获得: " .. CampaignSystem.formatRewards(rewards),
                icon = "victory",
            })
        end

        -- 触发剧情分支检查
        CampaignSystem.checkBranch()
    end

    -- 重置战斗系统
    if BS then
        BS.campaignMode = false
        BS.campaignStage = nil
        BS.campaignChapter = nil
    end

    CampaignState.currentChapter = nil
    CampaignState.currentStage = nil
end

-- 计算关卡奖励
function CampaignSystem.calculateRewards(stage)
    local diff = STAGE_DIFFICULTY[stage.difficulty] or STAGE_DIFFICULTY.MEDIUM
    local rewards = {}

    for resource, amount in pairs(stage.rewards) do
        if resource == "credits" or resource == "blueCrystal" or
           resource == "purpleCrystal" or resource == "rainbowCrystal" then
            rewards[resource] = math.floor(amount * diff.rewardsMult)
        else
            rewards[resource] = amount
        end
    end

    return rewards
end

-- 发放奖励
function CampaignSystem.grantRewards(rewards)
    local RM = require("game.systems.ResourceManager")

    for resource, amount in pairs(rewards) do
        if resource == "credits" then
            if playerState then
                playerState.credits = (playerState.credits or 0) + amount
            end
        elseif resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal" then
            if RM and RM.addRare then
                RM:addRare(resource, amount)
            end
        elseif resource == "skin" or resource == "rareItem" then
            -- 特殊物品处理
            if playerState then
                playerState.campaignItems = playerState.campaignItems or {}
                table.insert(playerState.campaignItems, resource)
            end
        end
    end
end

-- 格式化奖励显示
function CampaignSystem.formatRewards(rewards)
    local parts = {}
    if rewards.blueCrystal then table.insert(parts, "蓝晶×" .. rewards.blueCrystal) end
    if rewards.purpleCrystal then table.insert(parts, "紫晶×" .. rewards.purpleCrystal) end
    if rewards.rainbowCrystal then table.insert(parts, "虹晶×" .. rewards.rainbowCrystal) end
    if rewards.credits then table.insert(parts, "星币×" .. rewards.credits) end
    if rewards.skin then table.insert(parts, rewards.skin) end
    if rewards.rareItem then table.insert(parts, rewards.rareItem) end
    return table.concat(parts, ", ")
end

-- 检查章节是否完成
function CampaignSystem.checkChapterCompletion(chapter)
    if not chapter then return end

    local allCompleted = true
    for _, stage in ipairs(chapter.stages) do
        if not CampaignState.completedStages[stage.id] then
            allCompleted = false
            break
        end
    end

    if allCompleted and not CampaignState.completedChapters[chapter.id] then
        CampaignState.completedChapters[chapter.id] = true

        -- 发放章节奖励
        if chapter.chapterRewards then
            CampaignSystem.grantRewards(chapter.chapterRewards)
        end

        -- 提示章节完成
        if NotifyPanel then
            NotifyPanel.push({
                type = "SUCCESS",
                title = "章节完成",
                message = "恭喜完成 " .. chapter.name .. "！获得章节奖励",
                icon = "chapter_complete",
            })
        end
    end
end

-- ============================================================================
-- 剧情对话系统
-- ============================================================================

-- 显示对话
function CampaignSystem.showDialogue(dialogueKey)
    local dialogue = CAMPAIGN_DIALOGUE[dialogueKey]
    if not dialogue then return end

    -- 记录对话历史
    CampaignState.dialogueHistory[dialogueKey] = true

    -- 显示对话 UI
    if DialogueOverlay then
        DialogueOverlay.show(dialogue)
    end
end

-- 检查对话是否已看过
function CampaignSystem.hasSeenDialogue(dialogueKey)
    return CampaignState.dialogueHistory[dialogueKey] == true
end

-- ============================================================================
-- 剧情分支系统
-- ============================================================================

-- 检查剧情分支
function CampaignSystem.checkBranch()
    for _, branch in ipairs(CAMPAIGN_BRANCHES) do
        if CampaignState.completedStages[branch.triggerAfter] then
            CampaignSystem.triggerBranch(branch)
            break
        end
    end
end

-- 触发分支选择
function CampaignSystem.triggerBranch(branch)
    -- 显示分支选择 UI
    if BranchChoicePanel then
        BranchChoicePanel.show(branch)
    end
end

-- 玩家做出选择
function CampaignSystem.makeChoice(branchId, choiceId)
    local branch = nil
    for _, b in ipairs(CAMPAIGN_BRANCHES) do
        if b.id == branchId then branch = b; break end
    end
    if not branch then return false end

    local choice = nil
    for _, c in ipairs(branch.choices) do
        if c.id == choiceId then choice = c; break end
    end
    if not choice then return false end

    -- 记录选择
    CampaignState.playerChoices[branchId] = choiceId

    -- 应用选择效果
    if choice.effect then
        if choice.effect.bonus then
            CampaignSystem.grantRewards(choice.effect.bonus)
        end
        if choice.effect.followUp then
            -- 设置下一个关卡提示
            -- (在 UI 层显示)
        end
    end

    return true
end

-- ============================================================================
-- 存档与读取
-- ============================================================================

-- 序列化战役状态
function CampaignSystem.serialize()
    return {
        completedChapters = CampaignState.completedChapters,
        completedStages = CampaignState.completedStages,
        dialogueHistory = CampaignState.dialogueHistory,
        playerChoices = CampaignState.playerChoices,
    }
end

-- 反序列化战役状态
function CampaignSystem.deserialize(data)
    if not data then return end
    CampaignState.completedChapters = data.completedChapters or {}
    CampaignState.completedStages = data.completedStages or {}
    CampaignState.dialogueHistory = data.dialogueHistory or {}
    CampaignState.playerChoices = data.playerChoices or {}
end

-- 获取战役进度
function CampaignSystem.getProgress()
    return {
        completedChapters = CampaignState.completedChapters,
        completedStages = CampaignState.completedStages,
        totalChapters = #CAMPAIGN_CHAPTERS,
        totalStages = CampaignSystem.countTotalStages(),
    }
end

-- 统计总关卡数
function CampaignSystem.countTotalStages()
    local count = 0
    for _, chapter in ipairs(CAMPAIGN_CHAPTERS) do
        count = count + #chapter.stages
    end
    return count
end

-- ============================================================================
-- 获取当前关卡状态（用于 UI）
-- ============================================================================

function CampaignSystem.getCurrentStageState()
    if not CampaignState.inCampaignMode then return nil end

    local stage = CampaignSystem.getStage(CampaignState.currentStage)
    if not stage then return nil end

    local objectiveDef = STAGE_OBJECTIVES[stage.objective]

    return {
        stageId = CampaignState.currentStage,
        chapterId = CampaignState.currentChapter,
        stageName = stage.name,
        objective = stage.objective,
        objectiveName = objectiveDef and objectiveDef.name or "未知",
        objectiveDesc = objectiveDef and objectiveDef.desc or "",
        objectiveProgress = RuntimeStageData.objectiveProgress,
        objectiveTarget = stage.objectiveTarget or 0,
        enemiesRemaining = RuntimeStageData.enemiesRemaining,
        difficulty = stage.difficulty,
        difficultyName = STAGE_DIFFICULTY[stage.difficulty] and STAGE_DIFFICULTY[stage.difficulty].name or "普通",
    }
end

-- ============================================================================
-- 重置战役进度（仅用于测试）
-- ============================================================================

function CampaignSystem.resetProgress()
    CampaignState.completedChapters = {}
    CampaignState.completedStages = {}
    CampaignState.dialogueHistory = {}
    CampaignState.playerChoices = {}
end

-- ============================================================================
-- 导出模块
-- ============================================================================

return CampaignSystem
