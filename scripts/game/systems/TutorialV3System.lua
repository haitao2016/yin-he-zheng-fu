---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/systems/TutorialV3System.lua -- V3.0 新手引导重构
-- 8 阶段教学系统，分阶段引导玩家熟悉各系统
-- ============================================================================

local TutorialV3System = {}

-- ============================================================================
-- 教学阶段定义
-- ============================================================================

local TUTORIAL_STAGES = {
    -- ------------------------------------------------------------------------
    -- STAGE_1_BASICS: 开局 5 分钟
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_1_BASICS",
        name = "基础操作",
        desc = "学习移动、建造舰船与触发战斗的基础操作。",
        steps = {
            { action = "MOVE_FLEET",     hint = "拖动舰船图标，移动舰队至目标星系。", target = 1 },
            { action = "BUILD_SHIP",     hint = "在基地点击建造按钮，建造第一艘驱逐舰。", target = 1 },
            { action = "TRIGGER_BATTLE", hint = "点击敌舰进入战斗，完成第一次交火。",     target = 1 },
            { action = "VIEW_RESOURCES", hint = "查看顶部资源栏，了解金属与能源。",          target = 1 },
        },
        reward = { credits = 500, metal = 200, energy = 200 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_2_TECH: 首次接触科技树
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_2_TECH",
        name = "科技树入门",
        desc = "了解科技节点、研究路径与推荐升级方向。",
        steps = {
            { action = "OPEN_TECH_PANEL", hint = "打开科技树面板，查看可用科技。",               target = 1 },
            { action = "RESEARCH_TIER1",  hint = "选择并完成一项一级科技研究。",                 target = 1 },
            { action = "VIEW_PREREQ",     hint = "查看某科技的前置要求，理解解锁链。",           target = 1 },
            { action = "RESEARCH_COMPLETE", hint = "等待研究完成，领取科技加成。",               target = 1 },
        },
        reward = { credits = 1000, blueCrystal = 5 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_3_FLEET: 舰队管理
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_3_FLEET",
        name = "舰队管理",
        desc = "学习舰种选择、编队管理与阵型编辑。",
        steps = {
            { action = "OPEN_FLEET_PANEL",  hint = "打开舰队面板，查看已拥有的舰船。",        target = 1 },
            { action = "SELECT_SHIP_TYPE",  hint = "选择不同舰种，了解各舰种的属性差异。",      target = 3 },
            { action = "FORMATION_EDIT",    hint = "进入阵型编辑模式，调整舰船站位。",         target = 1 },
            { action = "SAVE_FORMATION",    hint = "保存自定义阵型方案。",                     target = 1 },
            { action = "DEPLOY_FLEET",      hint = "将编队部署至战场。",                        target = 1 },
        },
        reward = { credits = 1500, blueCrystal = 8 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_4_EVENTS: 随机事件
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_4_EVENTS",
        name = "随机事件",
        desc = "了解事件交互、选项影响与后果权衡。",
        steps = {
            { action = "TRIGGER_EVENT",  hint = "在星系图中触发一次随机事件。",                target = 1 },
            { action = "READ_EVENT",     hint = "仔细阅读事件描述，了解背景。",                  target = 1 },
            { action = "CHOOSE_OPTION",  hint = "在多个选项中做出抉择。",                        target = 1 },
            { action = "SEE_RESULT",     hint = "查看选择带来的结果与奖励。",                    target = 1 },
        },
        reward = { credits = 1000, purpleCrystal = 2 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_5_CAMPAIGN: 战役模式
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_5_CAMPAIGN",
        name = "战役模式",
        desc = "了解战役模式流程、关卡选择与奖励机制。",
        steps = {
            { action = "OPEN_CAMPAIGN",  hint = "打开战役面板，查看章节与关卡。",               target = 1 },
            { action = "SELECT_CHAPTER", hint = "选择一个战役章节，了解背景剧情。",               target = 1 },
            { action = "START_STAGE",    hint = "进入一个关卡，开始战役战斗。",                   target = 1 },
            { action = "COMPLETE_STAGE", hint = "完成一个关卡并领取通关奖励。",                   target = 1 },
        },
        reward = { credits = 2000, purpleCrystal = 5, civilizationPoints = 3 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_6_SEASON: 赛季系统
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_6_SEASON",
        name = "赛季系统",
        desc = "学习赛季任务、积分奖励与主题变体。",
        steps = {
            { action = "OPEN_SEASON",      hint = "打开赛季界面，查看当前赛季。",                target = 1 },
            { action = "VIEW_TASKS",       hint = "查看赛季任务列表。",                           target = 1 },
            { action = "COMPLETE_TASK",    hint = "完成一项赛季任务并领取积分。",                 target = 1 },
            { action = "CLAIM_MILESTONE",  hint = "领取一个积分里程碑奖励。",                     target = 1 },
        },
        reward = { credits = 2500, purpleCrystal = 8 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_7_GUILD: 公会系统
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_7_GUILD",
        name = "公会系统",
        desc = "了解公会创建/加入、公会任务与协作。",
        steps = {
            { action = "OPEN_GUILD",    hint = "打开公会界面，查看公会列表。",                   target = 1 },
            { action = "JOIN_OR_CREATE", hint = "加入一个公会，或创建自己的公会。",              target = 1 },
            { action = "GUILD_TASK",     hint = "完成一项公会任务，获得贡献值。",                 target = 1 },
            { action = "GUILD_DONATE",   hint = "向公会捐赠资源，提升公会等级。",                 target = 1 },
        },
        reward = { credits = 3000, purpleCrystal = 10 },
        isCompleted = false,
    },

    -- ------------------------------------------------------------------------
    -- STAGE_8_ADVANCED: 进阶内容
    -- ------------------------------------------------------------------------
    {
        id   = "STAGE_8_ADVANCED",
        name = "进阶内容",
        desc = "探索隐藏成就、指挥官技能与 Roguelike 选卡等高阶玩法。",
        steps = {
            { action = "VIEW_ACHIEVEMENTS",  hint = "查看成就列表，了解隐藏成就条件。",         target = 1 },
            { action = "COMMANDER_SKILL",    hint = "学习与分配一项指挥官技能。",               target = 1 },
            { action = "ROGUE_CARD_PICK",    hint = "在 Roguelike 模式中选择一张增益卡。",      target = 1 },
            { action = "HARD_MODE_TRY",      hint = "尝试高难度战斗或关卡。",                    target = 1 },
        },
        reward = { credits = 5000, purpleCrystal = 15, rainbowCrystal = 2 },
        isCompleted = false,
    },
}

-- ============================================================================
-- 索引表
-- ============================================================================

local STAGE_BY_ID = {}
for idx, stage in ipairs(TUTORIAL_STAGES) do
    STAGE_BY_ID[stage.id] = stage
    stage._index = idx
end

-- ============================================================================
-- 运行时玩家状态辅助
-- ============================================================================

local function ensureTutorialState(playerState)
    playerState = playerState or {}
    playerState.tutorialV3 = playerState.tutorialV3 or {
        currentStageIndex = 1,
        stepsCompleted = {},
        stagesCompleted = {},
    }
    for _, stage in ipairs(TUTORIAL_STAGES) do
        playerState.tutorialV3.stepsCompleted[stage.id] = playerState.tutorialV3.stepsCompleted[stage.id] or {}
        for _, step in ipairs(stage.steps) do
            playerState.tutorialV3.stepsCompleted[stage.id][step.action] =
                playerState.tutorialV3.stepsCompleted[stage.id][step.action] or 0
        end
    end
    return playerState
end

-- ============================================================================
-- 主要 API
-- ============================================================================

--- 获取当前玩家应进行的教学阶段
---@param playerState table
---@return table|nil @ 当前阶段表
function TutorialV3System.getCurrentStage(playerState)
    playerState = ensureTutorialState(playerState)
    local idx = playerState.tutorialV3.currentStageIndex
    if idx < 1 or idx > #TUTORIAL_STAGES then return nil end
    return TUTORIAL_STAGES[idx]
end

--- 标记某个动作步骤完成，自动推进当前阶段
---@param stepId string @ 对应 steps 中的 action 字段
---@param playerState table
---@return boolean, string @ (是否推进, 说明信息)
function TutorialV3System.completeStep(stepId, playerState)
    playerState = ensureTutorialState(playerState)
    local stage = TutorialV3System.getCurrentStage(playerState)
    if not stage then return false, "教学已全部完成" end

    local steps = playerState.tutorialV3.stepsCompleted[stage.id]
    local stepDef = nil
    for _, s in ipairs(stage.steps) do
        if s.action == stepId then stepDef = s; break end
    end
    if not stepDef then
        -- 不在当前阶段：如果是未来阶段的步骤，忽略；如果是已完成阶段，忽略
        return false, "步骤不在当前阶段: " .. tostring(stepId)
    end

    steps[stepId] = (steps[stepId] or 0) + 1

    -- 判断阶段是否完成
    local allDone = true
    for _, s in ipairs(stage.steps) do
        if (steps[s.action] or 0) < s.target then
            allDone = false
            break
        end
    end

    if allDone then
        playerState.tutorialV3.stagesCompleted[stage.id] = true
        local nextIdx = (stage._index or 1) + 1
        if nextIdx <= #TUTORIAL_STAGES then
            playerState.tutorialV3.currentStageIndex = nextIdx
            return true, "阶段完成: " .. stage.name .. " -> 进入: " .. TUTORIAL_STAGES[nextIdx].name
        else
            playerState.tutorialV3.currentStageIndex = #TUTORIAL_STAGES + 1
            return true, "所有教学阶段已完成"
        end
    end

    return true, "步骤进度: " .. stepId .. " (" .. tostring(steps[stepId]) .. "/" .. tostring(stepDef.target) .. ")"
end

--- 教学是否全部完成
---@param playerState table
---@return boolean
function TutorialV3System.isTutorialComplete(playerState)
    playerState = ensureTutorialState(playerState)
    return (playerState.tutorialV3.currentStageIndex or 1) > #TUTORIAL_STAGES
end

--- 返回某个动作对应的提示文字
---@param actionId string
---@param playerState table
---@return string
function TutorialV3System.getHintForAction(actionId, playerState)
    local stage = TutorialV3System.getCurrentStage(playerState)
    if not stage then return "" end
    for _, s in ipairs(stage.steps) do
        if s.action == actionId then return s.hint end
    end
    return ""
end

--- 当前阶段是否可跳过（仅部分阶段允许跳过）
---@param playerState table
---@return boolean
function TutorialV3System.canSkip(playerState)
    local stage = TutorialV3System.getCurrentStage(playerState)
    if not stage then return false end
    -- 第 1 阶段强制教学，不可跳过；从第 2 阶段起允许玩家选择跳过
    return (stage._index or 1) > 1
end

--- 跳过当前阶段
---@param playerState table
---@return boolean, string
function TutorialV3System.skipStage(playerState)
    if not TutorialV3System.canSkip(playerState) then
        return false, "当前阶段不可跳过"
    end
    playerState = ensureTutorialState(playerState)
    local stage = TutorialV3System.getCurrentStage(playerState)
    if not stage then return false, "无当前阶段" end
    playerState.tutorialV3.stagesCompleted[stage.id] = true
    local nextIdx = (stage._index or 1) + 1
    playerState.tutorialV3.currentStageIndex = math.min(nextIdx, #TUTORIAL_STAGES + 1)
    return true, "已跳过阶段: " .. stage.name
end

--- 获取指定阶段的奖励
---@param stageId string
---@return table|nil
function TutorialV3System.getStageReward(stageId)
    local stage = STAGE_BY_ID[stageId]
    if not stage then return nil end
    return stage.reward
end

--- 获取所有阶段定义（用于 UI 展示）
---@param playerState table|nil
---@return table
function TutorialV3System.getAllStages(playerState)
    if not playerState then return TUTORIAL_STAGES end
    playerState = ensureTutorialState(playerState)
    local result = {}
    for _, stage in ipairs(TUTORIAL_STAGES) do
        local copy = {}
        for k, v in pairs(stage) do copy[k] = v end
        copy.isCompleted = playerState.tutorialV3.stagesCompleted[stage.id] == true
        table.insert(result, copy)
    end
    return result
end

-- P3-P3-1: 跳过教程功能
--- 跳过当前阶段（用于玩家主动跳过或特殊情况）
---@param playerState table
---@param stageId string|nil 阶段ID，不填则跳过当前阶段
---@return boolean
function TutorialV3System.skipStage(playerState, stageId)
    playerState = ensureTutorialState(playerState)
    local targetStage = stageId and STAGE_BY_ID[stageId] or TutorialV3System.getCurrentStage(playerState)
    if not targetStage then return false end

    playerState.tutorialV3.stagesCompleted[targetStage.id] = true
    local nextIdx = (targetStage._index or 1) + 1
    playerState.tutorialV3.currentStageIndex = math.min(nextIdx, #TUTORIAL_STAGES + 1)
    print("[Tutorial] 跳过教程阶段: " .. targetStage.name)
    return true
end

--- 跳过所有剩余教程（用于老玩家或测试）
---@param playerState table
---@return boolean
function TutorialV3System.skipAllTutorial(playerState)
    playerState = ensureTutorialState(playerState)
    for _, stage in ipairs(TUTORIAL_STAGES) do
        playerState.tutorialV3.stagesCompleted[stage.id] = true
    end
    playerState.tutorialV3.currentStageIndex = #TUTORIAL_STAGES + 1
    print("[Tutorial] 跳过所有教程")
    return true
end

--- 检查教程是否全部完成
---@param playerState table
---@return boolean
function TutorialV3System.isAllCompleted(playerState)
    playerState = ensureTutorialState(playerState)
    return playerState.tutorialV3.currentStageIndex > #TUTORIAL_STAGES
end

--- 获取教程完成进度
---@param playerState table
---@return number completed, number total
function TutorialV3System.getProgress(playerState)
    playerState = ensureTutorialState(playerState)
    local completed = 0
    for _, stage in ipairs(TUTORIAL_STAGES) do
        if playerState.tutorialV3.stagesCompleted[stage.id] then
            completed = completed + 1
        end
    end
    return completed, #TUTORIAL_STAGES
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function TutorialV3System.serialize(playerState)
    playerState = ensureTutorialState(playerState)
    return playerState.tutorialV3
end

function TutorialV3System.deserialize(playerState, data)
    playerState = playerState or {}
    if data and type(data) == "table" then
        playerState.tutorialV3 = {
            currentStageIndex = data.currentStageIndex or 1,
            stepsCompleted = data.stepsCompleted or {},
            stagesCompleted = data.stagesCompleted or {},
        }
    else
        playerState.tutorialV3 = {
            currentStageIndex = 1,
            stepsCompleted = {},
            stagesCompleted = {},
        }
    end
    return playerState
end

return TutorialV3System
