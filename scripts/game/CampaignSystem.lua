-- ============================================================================
-- game/CampaignSystem.lua  -- P2-2: 战役模式——银河征服序章
-- ============================================================================
-- 3 fixed campaign levels with story dialogue, fixed maps, and tutorial progression.
-- Each level awards 文明积分 × 3 on completion.

local CampaignSystem = {}

-- ============================================================================
-- 战役关卡定义
-- ============================================================================
local LEVELS = {
    -- Level 1: 拓荒（Colonize & Build）
    {
        id         = 1,
        name       = "第一章：拓荒",
        subtitle   = "在未知星域建立第一个殖民地",
        difficulty = "easy",
        maxWaves   = 4,
        pirateBaseCount = 1,
        reward     = 3,  -- 文明积分
        -- 固定星系数据（4 个星系，位置固定）
        fixedStars = {
            { x=-400,  y=-200, type="G", planets=3 },
            { x= 300,  y=-100, type="K", planets=2 },
            { x=-100,  y= 400, type="M", planets=4 },
            { x= 500,  y= 350, type="F", planets=2 },
        },
        -- 固定海盗基地位置
        fixedPirateBases = {
            { x=600, y=-400, level=2 },
        },
        -- 种子飞船固定出生位置
        seedPos = { x=-300, y=0 },
        -- 剧情对话（关卡开始、首次殖民、首次胜利）
        dialogues = {
            intro = {
                { speaker="舰长", text="指挥官，我们的种子飞船已抵达未知星域。在这里建立殖民地是我们的首要任务。" },
                { speaker="AI顾问", text="建议先展开基地，然后殖民附近的资源星球。注意防范海盗袭击。" },
                { speaker="舰长", text="了解。全体船员，准备展开！这是人类迈向星辰大海的第一步！" },
            },
            on_first_colonize = {
                { speaker="AI顾问", text="殖民成功！这颗行星将为我们提供宝贵的资源。建议立即修建采矿设施。" },
            },
            on_victory = {
                { speaker="舰长", text="太好了！海盗据点已被清除。这片星域现在安全了。" },
                { speaker="AI顾问", text="指挥官，您已证明自己有能力守护殖民地。新的征程在前方等待着我们。" },
            },
        },
        -- 胜利条件
        winCondition = { type="pirate_clear" },  -- 清除所有海盗基地
    },

    -- Level 2: 反击（Tech & Combat）
    {
        id         = 2,
        name       = "第二章：反击",
        subtitle   = "研发先进科技，击溃海盗要塞",
        difficulty = "normal",
        maxWaves   = 8,
        pirateBaseCount = 2,
        reward     = 3,
        fixedStars = {
            { x=-600,  y=-300, type="G", planets=3 },
            { x= 0,    y=-500, type="K", planets=2 },
            { x= 500,  y=-200, type="F", planets=3 },
            { x=-300,  y= 300, type="M", planets=4 },
            { x= 400,  y= 400, type="G", planets=2 },
            { x=-500,  y= 500, type="K", planets=3 },
        },
        fixedPirateBases = {
            { x=700,  y=-500, level=4 },
            { x=-700, y= 600, level=5 },
        },
        seedPos = { x=0, y=0 },
        dialogues = {
            intro = {
                { speaker="舰长", text="情报显示这片区域有两个海盗要塞。它们的火力远超我们之前遇到的。" },
                { speaker="AI顾问", text="建议优先发展科技树。先进的舰船武器是击破要塞的关键。" },
                { speaker="舰长", text="明白。科研部门全力运转，我们要用智慧碾压这些匪徒！" },
            },
            on_first_research = {
                { speaker="AI顾问", text="首项科技研发完成！舰队战力已得到提升。继续推进科技树吧。" },
            },
            on_victory = {
                { speaker="舰长", text="两座海盗要塞已被摧毁！我们的科技实力让敌人闻风丧胆。" },
                { speaker="AI顾问", text="但前方的挑战更加严峻……有情报显示，一个中立势力正在观望。" },
            },
        },
        winCondition = { type="pirate_clear" },
    },

    -- Level 3: 联盟（Diplomacy）
    {
        id         = 3,
        name       = "第三章：联盟",
        subtitle   = "通过外交手段建立星际同盟",
        difficulty = "normal",
        maxWaves   = 10,
        pirateBaseCount = 3,
        reward     = 3,
        fixedStars = {
            { x=-800,  y=-400, type="G", planets=3 },
            { x=-200,  y=-600, type="K", planets=2 },
            { x= 600,  y=-300, type="F", planets=4 },
            { x=-500,  y= 200, type="M", planets=3 },
            { x= 300,  y= 100, type="G", planets=2 },
            { x= 700,  y= 500, type="K", planets=3 },
            { x=-100,  y= 600, type="F", planets=2 },
            { x=-600,  y=-100, type="M", planets=3 },
        },
        fixedPirateBases = {
            { x= 900,  y=-600, level=5 },
            { x=-900,  y= 700, level=6 },
            { x= 100,  y=-800, level=7 },
        },
        seedPos = { x=-200, y=200 },
        dialogues = {
            intro = {
                { speaker="舰长", text="扫描发现一个中立文明'织星者'定居在这片星域。他们既非敌人，也非盟友。" },
                { speaker="AI顾问", text="三座海盗要塞环伺四周，仅凭我们的力量恐怕难以取胜。建议与织星者建立外交关系。" },
                { speaker="舰长", text="好的。在战斗之外，我们也需要学会合作。全员准备——战争与和平，一样都不能少！" },
            },
            on_alliance = {
                { speaker="织星者使节", text="你们证明了自己的诚意。织星者愿与你们并肩作战，共抗海盗。" },
                { speaker="舰长", text="感谢！有了盟友的支援，那些海盗要塞将不堪一击！" },
            },
            on_victory = {
                { speaker="舰长", text="最后的海盗要塞陷落了！银河征服序章——圆满完成！" },
                { speaker="AI顾问", text="恭喜指挥官。从拓荒到联盟，您已成长为真正的星际领袖。" },
                { speaker="舰长", text="这只是开始。未来还有更广阔的宇宙等着我们去征服！" },
            },
        },
        winCondition = { type="pirate_clear" },
    },
}

-- ============================================================================
-- 战役状态
-- ============================================================================
local state_ = {
    active      = false,   -- 是否在战役模式中
    levelIdx    = 0,       -- 当前关卡索引 (1-3)
    completed   = {},      -- 已完成关卡 id set: { [1]=true, [2]=true, ... }
    dialogueQueue = {},    -- 待显示对话队列
    dialogueIdx   = 0,     -- 当前对话行索引
    showingDialogue = false,
    triggers    = {},      -- 剧情触发器状态（防止重复触发）
}

-- ============================================================================
-- 对外接口
-- ============================================================================

--- 获取所有关卡定义
function CampaignSystem.GetLevels()
    return LEVELS
end

--- 获取当前状态
function CampaignSystem.GetState()
    return state_
end

--- 是否处于战役模式
function CampaignSystem.IsActive()
    return state_.active
end

--- 获取当前关卡定义（nil if not active）
function CampaignSystem.GetCurrentLevel()
    if not state_.active or state_.levelIdx < 1 then return nil end
    return LEVELS[state_.levelIdx]
end

--- 启动战役关卡
---@param levelIdx number 1-3
function CampaignSystem.StartLevel(levelIdx)
    local level = LEVELS[levelIdx]
    if not level then return false end
    state_.active    = true
    state_.levelIdx  = levelIdx
    state_.triggers  = {}
    state_.dialogueQueue = {}
    state_.dialogueIdx   = 0
    state_.showingDialogue = false
    print(string.format("[Campaign] 启动关卡 %d: %s", levelIdx, level.name))
    return true
end

--- 结束当前战役关卡（调用者在胜利时调用）
---@return number earnedPoints 获得的文明积分
function CampaignSystem.CompleteLevel()
    if not state_.active then return 0 end
    local level = LEVELS[state_.levelIdx]
    if not level then return 0 end
    state_.completed[state_.levelIdx] = true
    local points = level.reward or 3
    print(string.format("[Campaign] 关卡 %d 完成！奖励文明积分 +%d", state_.levelIdx, points))
    state_.active = false
    return points
end

--- 退出战役（玩家手动退出或战败）
function CampaignSystem.Abort()
    state_.active = false
    state_.levelIdx = 0
    state_.dialogueQueue = {}
    state_.showingDialogue = false
    print("[Campaign] 战役已退出")
end

--- 检查关卡是否已通关
function CampaignSystem.IsLevelCompleted(levelIdx)
    return state_.completed[levelIdx] == true
end

--- 获取已完成关卡数
function CampaignSystem.GetCompletedCount()
    local count = 0
    for _ in pairs(state_.completed) do count = count + 1 end
    return count
end

-- ============================================================================
-- 对话系统
-- ============================================================================

--- 触发一段对话（不重复触发同一 triggerKey）
---@param triggerKey string  如 "intro", "on_first_colonize"
function CampaignSystem.TriggerDialogue(triggerKey)
    if not state_.active then return end
    if state_.triggers[triggerKey] then return end  -- 已触发过
    local level = LEVELS[state_.levelIdx]
    if not level then return end
    local lines = level.dialogues[triggerKey]
    if not lines or #lines == 0 then return end
    state_.triggers[triggerKey] = true
    state_.dialogueQueue = lines
    state_.dialogueIdx   = 1
    state_.showingDialogue = true
    print(string.format("[Campaign] 触发对话: %s (%d 行)", triggerKey, #lines))
end

--- 推进对话到下一行（玩家点击继续）
---@return boolean finished 对话是否全部播完
function CampaignSystem.AdvanceDialogue()
    if not state_.showingDialogue then return true end
    state_.dialogueIdx = state_.dialogueIdx + 1
    if state_.dialogueIdx > #state_.dialogueQueue then
        state_.showingDialogue = false
        state_.dialogueQueue = {}
        state_.dialogueIdx = 0
        return true
    end
    return false
end

--- 获取当前对话行 { speaker, text } 或 nil
function CampaignSystem.GetCurrentDialogueLine()
    if not state_.showingDialogue then return nil end
    return state_.dialogueQueue[state_.dialogueIdx]
end

--- 对话是否正在显示
function CampaignSystem.IsShowingDialogue()
    return state_.showingDialogue
end

-- ============================================================================
-- 存档
-- ============================================================================

--- 导出存档数据（合并到 galaxy_career.json）
function CampaignSystem.GetSaveData()
    return {
        completed = state_.completed,
    }
end

--- 载入存档数据
function CampaignSystem.LoadSaveData(data)
    if not data then return end
    state_.completed = data.completed or {}
end

return CampaignSystem
