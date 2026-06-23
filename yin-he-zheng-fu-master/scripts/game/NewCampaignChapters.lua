---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/NewCampaignChapters.lua -- V3.0 新战役章节扩展
-- CHAPTER_3 虚空之门 / CHAPTER_4 文明回响 / CHAPTER_5 银河终局
-- ============================================================================

local NewCampaignChapters = {}

-- ============================================================================
-- 难度枚举
-- ============================================================================

DIFFICULTY = {
    EASY      = "EASY",
    NORMAL    = "NORMAL",
    HARD      = "HARD",
    EXTREME   = "EXTREME",
    LEGENDARY = "LEGENDARY",
}

-- ============================================================================
-- 新战役章节全局表
-- ============================================================================

NEW_CAMPAIGN_CHAPTERS = {
    -- ------------------------------------------------------------------------
    -- CHAPTER_3: 虚空之门
    -- ------------------------------------------------------------------------
    {
        id   = "CHAPTER_3",
        name = "第三章：虚空之门",
        nameEn = "Chapter III: The Void Gate",
        description = "玩家深入探索虚空裂隙，面对未知文明的防御力量。揭开这片被时间遗忘的星域中隐藏的秘密。",
        requiredWave = 30,
        chapterRewards = {
            credits = 5000,
            purpleCrystal = 15,
            rainbowCrystal = 3,
            civilizationPoints = 10,
        },
        stages = {
            {
                id = "CH3_STAGE_1",
                name = "裂隙侦察",
                difficulty = DIFFICULTY.EASY,
                enemyComp = { scout = 8, fighter = 4 },
                objective = "DESTROY_ALL",
                objectiveTarget = 12,
                rewards = { credits = 500, blueCrystal = 5 },
            },
            {
                id = "CH3_STAGE_2",
                name = "虚空巡逻队",
                difficulty = DIFFICULTY.NORMAL,
                enemyComp = { fighter = 10, cruiser = 3 },
                objective = "SURVIVE_WAVES",
                objectiveTarget = 5,
                rewards = { credits = 800, blueCrystal = 8 },
            },
            {
                id = "CH3_STAGE_3",
                name = "异次元哨所",
                difficulty = DIFFICULTY.NORMAL,
                enemyComp = { fighter = 6, cruiser = 5, support = 2 },
                objective = "DESTROY_COMMANDER",
                objectiveTarget = 1,
                rewards = { credits = 1200, purpleCrystal = 3 },
            },
            {
                id = "CH3_STAGE_4",
                name = "虚空守卫",
                difficulty = DIFFICULTY.HARD,
                enemyComp = { cruiser = 8, battleship = 2 },
                objective = "DESTROY_ALL",
                objectiveTarget = 10,
                rewards = { credits = 1800, purpleCrystal = 5 },
            },
            {
                id = "CH3_STAGE_5",
                name = "次元门守护者",
                difficulty = DIFFICULTY.EXTREME,
                enemyComp = { battleship = 4, eliteGuardian = 1 },
                objective = "DESTROY_BOSS",
                objectiveTarget = 1,
                rewards = { credits = 3000, purpleCrystal = 8, rainbowCrystal = 1 },
            },
            {
                id = "CH3_STAGE_6",
                name = "虚空之门",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { cruiser = 6, battleship = 4, voidGate = 1 },
                objective = "SEAL_RIFT",
                objectiveTarget = 1,
                rewards = { credits = 5000, purpleCrystal = 15, rainbowCrystal = 3 },
            },
        },
    },

    -- ------------------------------------------------------------------------
    -- CHAPTER_4: 文明回响
    -- ------------------------------------------------------------------------
    {
        id   = "CHAPTER_4",
        name = "第四章：文明回响",
        nameEn = "Chapter IV: Echoes of Civilization",
        description = "玩家发现一个古老文明的遗迹，需要解读谜题并保护遗迹免受各方势力争夺。",
        requiredWave = 60,
        chapterRewards = {
            credits = 8000,
            purpleCrystal = 25,
            rainbowCrystal = 6,
            civilizationPoints = 20,
            uniqueTechUnlock = "ANCIENT_ARCHIVES",
        },
        stages = {
            {
                id = "CH4_STAGE_1",
                name = "遗迹外围",
                difficulty = DIFFICULTY.NORMAL,
                enemyComp = { pirate = 10, scavenger = 3 },
                objective = "CLEAR_PIRATES",
                objectiveTarget = 13,
                rewards = { credits = 1000, blueCrystal = 8 },
            },
            {
                id = "CH4_STAGE_2",
                name = "符文谜题",
                difficulty = DIFFICULTY.HARD,
                enemyComp = { guardianDrone = 8, puzzleBoss = 1 },
                objective = "SOLVE_PUZZLE",
                objectiveTarget = 3,
                rewards = { credits = 1500, purpleCrystal = 5 },
            },
            {
                id = "CH4_STAGE_3",
                name = "守护圣堂",
                difficulty = DIFFICULTY.HARD,
                enemyComp = { pirateFleet = 12, scavenger = 6 },
                objective = "PROTECT_RELIC",
                objectiveTarget = 180,
                rewards = { credits = 2000, purpleCrystal = 8 },
            },
            {
                id = "CH4_STAGE_4",
                name = "镜像回廊",
                difficulty = DIFFICULTY.EXTREME,
                enemyComp = { mirrorGuardian = 6, shadowClone = 4 },
                objective = "DESTROY_ALL",
                objectiveTarget = 10,
                rewards = { credits = 3000, purpleCrystal = 12 },
            },
            {
                id = "CH4_STAGE_5",
                name = "远古王座",
                difficulty = DIFFICULTY.EXTREME,
                enemyComp = { royalGuard = 8, ancientKing = 1 },
                objective = "DESTROY_BOSS",
                objectiveTarget = 1,
                rewards = { credits = 4500, purpleCrystal = 15, rainbowCrystal = 2 },
            },
            {
                id = "CH4_STAGE_6",
                name = "文明回响",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { royalGuard = 10, ancientKing = 1, echoBeast = 1 },
                objective = "AWAKEN_RELIC",
                objectiveTarget = 1,
                rewards = { credits = 8000, purpleCrystal = 25, rainbowCrystal = 6 },
            },
            {
                id = "CH4_STAGE_7",
                name = "记忆碎片",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { memoryGuardian = 12, timeWraith = 4 },
                objective = "COLLECT_FRAGMENTS",
                objectiveTarget = 5,
                rewards = { credits = 10000, purpleCrystal = 30, rainbowCrystal = 8 },
            },
        },
    },

    -- ------------------------------------------------------------------------
    -- CHAPTER_5: 银河终局
    -- ------------------------------------------------------------------------
    {
        id   = "CHAPTER_5",
        name = "第五章：银河终局",
        nameEn = "Chapter V: Galactic Finale",
        description = "最终决战。对抗帝国主力舰队，决定银河命运的最后一战即将打响。",
        requiredWave = 100,
        chapterRewards = {
            credits = 20000,
            purpleCrystal = 50,
            rainbowCrystal = 15,
            civilizationPoints = 50,
            titleUnlock = "GALACTIC_CONQUEROR",
        },
        stages = {
            {
                id = "CH5_STAGE_1",
                name = "前哨突破",
                difficulty = DIFFICULTY.HARD,
                enemyComp = { imperialScout = 12, imperialFighter = 6 },
                objective = "DESTROY_ALL",
                objectiveTarget = 18,
                rewards = { credits = 2500, purpleCrystal = 8 },
            },
            {
                id = "CH5_STAGE_2",
                name = "帝国防线",
                difficulty = DIFFICULTY.EXTREME,
                enemyComp = { imperialCruiser = 10, imperialBattleship = 3 },
                objective = "SURVIVE_WAVES",
                objectiveTarget = 10,
                rewards = { credits = 4000, purpleCrystal = 15 },
            },
            {
                id = "CH5_STAGE_3",
                name = "舰队指挥官",
                difficulty = DIFFICULTY.EXTREME,
                enemyComp = { imperialCruiser = 6, imperialBattleship = 4, fleetAdmiral = 1 },
                objective = "DESTROY_COMMANDER",
                objectiveTarget = 1,
                rewards = { credits = 6000, purpleCrystal = 20, rainbowCrystal = 3 },
            },
            {
                id = "CH5_STAGE_4",
                name = "能量核心",
                difficulty = DIFFICULTY.EXTREME,
                enemyComp = { imperialDefender = 12, energyCore = 1 },
                objective = "DESTROY_CORE",
                objectiveTarget = 1,
                rewards = { credits = 8000, purpleCrystal = 25, rainbowCrystal = 5 },
            },
            {
                id = "CH5_STAGE_5",
                name = "禁卫军团",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { imperialGuard = 10, imperialElite = 5 },
                objective = "DESTROY_ALL",
                objectiveTarget = 15,
                rewards = { credits = 12000, purpleCrystal = 35, rainbowCrystal = 8 },
            },
            {
                id = "CH5_STAGE_6",
                name = "帝国旗舰",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { imperialGuard = 8, imperialFlagship = 1 },
                objective = "DESTROY_FLAGSHIP",
                objectiveTarget = 1,
                rewards = { credits = 18000, purpleCrystal = 45, rainbowCrystal = 12 },
            },
            {
                id = "CH5_STAGE_7",
                name = "皇帝现身",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { imperialElite = 10, imperialFlagship = 1, emperor = 1 },
                objective = "DESTROY_EMPEROR",
                objectiveTarget = 1,
                rewards = { credits = 25000, purpleCrystal = 60, rainbowCrystal = 18 },
            },
            {
                id = "CH5_STAGE_8",
                name = "银河终局",
                difficulty = DIFFICULTY.LEGENDARY,
                enemyComp = { imperialFleet = 15, emperor = 1, finalWeapon = 1 },
                objective = "FINAL_VICTORY",
                objectiveTarget = 1,
                rewards = { credits = 50000, purpleCrystal = 100, rainbowCrystal = 30 },
            },
        },
    },
}

-- ============================================================================
-- 索引表
-- ============================================================================

local CHAPTER_BY_ID = {}
for _, chapter in ipairs(NEW_CAMPAIGN_CHAPTERS) do
    CHAPTER_BY_ID[chapter.id] = chapter
end

-- ============================================================================
-- 导出函数
-- ============================================================================

--- 按 id 获取章节定义
---@param chapterId string @ "CHAPTER_3" | "CHAPTER_4" | "CHAPTER_5"
---@return table|nil
function NewCampaignChapters.get(chapterId)
    if not chapterId then return nil end
    return CHAPTER_BY_ID[chapterId]
end

--- 获取所有新战役章节
---@return table
function NewCampaignChapters.getAll()
    return NEW_CAMPAIGN_CHAPTERS
end

--- 获取指定章节的指定关卡
---@param chapterId string
---@param stageIndex number @ 1-based 关卡索引
---@return table|nil
function NewCampaignChapters.getStage(chapterId, stageIndex)
    local chapter = CHAPTER_BY_ID[chapterId]
    if not chapter then return nil end
    if not stageIndex or stageIndex < 1 or stageIndex > #chapter.stages then return nil end
    return chapter.stages[stageIndex]
end

--- 根据玩家当前波次判断可进入的章节
---@param currentWave number
---@return table @ 已解锁章节数组
function NewCampaignChapters.getUnlockedChapters(currentWave)
    currentWave = currentWave or 0
    local unlocked = {}
    for _, chapter in ipairs(NEW_CAMPAIGN_CHAPTERS) do
        if currentWave >= (chapter.requiredWave or 0) then
            table.insert(unlocked, chapter)
        end
    end
    return unlocked
end

return NewCampaignChapters
