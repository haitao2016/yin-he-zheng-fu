--[[
Constants/CampaignConstants.lua
战役章节、关卡目标、剧情对话、分支选择常量
]]

local M = {}

-- ============================================================================
-- 关卡目标类型
-- ============================================================================

M.STAGE_OBJECTIVES = {
    ASSAULT   = { name = "突袭战",   desc = "消灭所有敌人" },
    DEFEND    = { name = "防守战",   desc = "抵御敌人进攻" },
    SURVIVE   = { name = "生存战",   desc = "存活指定时间" },
    ELIMINATE = { name = "斩首行动", desc = "击败Boss" },
    ESCORT    = { name = "护送战",   desc = "保护目标到达" },
}

-- ============================================================================
-- 战役章节
-- ============================================================================

M.CAMPAIGN_CHAPTERS = {
    {
        id = "PROLOGUE", name = "序章：星火燎原",
        description = "银河边缘的殖民地遭到袭击，你被征召加入抵抗军...",
        requiredWave = 0,
        stages = {
            { id = "STAGE_P1", name = "初战告捷", difficulty = "EASY", unlockWave = 0, enemyComp = { FIGHTER = 5, DESTROYER = 2 }, objective = "ASSAULT", objectiveTarget = 0, rewards = { blueCrystal = 30, credits = 100 } },
            { id = "STAGE_P2", name = "艰难抵抗", difficulty = "EASY", unlockWave = 5, enemyComp = { FIGHTER = 8, DESTROYER = 3, CORVETTE = 2 }, objective = "DEFEND", objectiveTarget = 5, rewards = { blueCrystal = 50, credits = 150 } },
            { id = "STAGE_P3", name = "战术撤退", difficulty = "MEDIUM", unlockWave = 10, enemyComp = { DESTROYER = 5, CORVETTE = 4, BATTLECRUISER = 1 }, objective = "SURVIVE", objectiveTarget = 3, rewards = { blueCrystal = 80, purpleCrystal = 10, credits = 200 } },
        },
        chapterRewards = { blueCrystal = 100, skin = "CAMPAIGN_PILOT" },
    },
    {
        id = "CHAPTER_1", name = "第一章：黑暗降临",
        description = "一支神秘舰队出现在银河核心区域...",
        requiredWave = 15,
        stages = {
            { id = "STAGE_1_1", name = "遭遇战", difficulty = "MEDIUM", unlockWave = 15, enemyComp = { DESTROYER = 8, CORVETTE = 6, BATTLECRUISER = 2 }, objective = "ASSAULT", objectiveTarget = 0, rewards = { blueCrystal = 100, credits = 300 } },
            { id = "STAGE_1_2", name = "防守", difficulty = "MEDIUM", unlockWave = 25, enemyComp = { CORVETTE = 10, BATTLECRUISER = 4 }, objective = "DEFEND", objectiveTarget = 8, rewards = { blueCrystal = 150, credits = 400 } },
            { id = "STAGE_1_3", name = "Boss战：虚空领主", difficulty = "HARD", unlockWave = 35, enemyComp = { VOID_LORD = 1, DESTROYER = 6, BATTLECRUISER = 3 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { purpleCrystal = 30, credits = 500 } },
        },
        chapterRewards = { purpleCrystal = 50, rainbowCrystal = 20, skin = "REBEL_COMMANDER" },
    },
    {
        id = "CHAPTER_2", name = "第二章：帝国反击",
        description = "帝国舰队开始全面反攻，抵抗军面临严峻考验...",
        requiredWave = 45,
        stages = {
            { id = "STAGE_2_1", name = "追击帝国残部", difficulty = "HARD", unlockWave = 45, enemyComp = { DESTROYER = 10, BATTLECRUISER = 6, CARRIER = 2 }, objective = "ASSAULT", objectiveTarget = 0, rewards = { blueCrystal = 200, purpleCrystal = 20, credits = 700 } },
            { id = "STAGE_2_2", name = "帝国反击", difficulty = "HARD", unlockWave = 55, enemyComp = { BATTLECRUISER = 8, CARRIER = 4, VOID_LORD = 1 }, objective = "DEFEND", objectiveTarget = 10, rewards = { blueCrystal = 250, purpleCrystal = 30, credits = 800 } },
            { id = "STAGE_2_3", name = "决战：帝国堡垒", difficulty = "EXTREME", unlockWave = 65, enemyComp = { VOID_LORD = 2, BATTLECRUISER = 10, CARRIER = 3 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { purpleCrystal = 50, rainbowCrystal = 10, credits = 1000 } },
        },
        chapterRewards = { purpleCrystal = 100, rainbowCrystal = 30, skin = "IMPERIAL_HUNTER" },
    },
    {
        id = "CHAPTER_3", name = "第三章：深渊之眼",
        description = "虚空领主的真正意图逐渐显露，银河陷入前所未有的危机...",
        requiredWave = 80,
        stages = {
            { id = "STAGE_3_1", name = "虚空信号", difficulty = "HARD", unlockWave = 80, enemyComp = { VOID_LORD = 2, STEALTH = 5, DESTROYER = 6 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { blueCrystal = 400, purpleCrystal = 80, credits = 800 } },
            { id = "STAGE_3_2", name = "深渊之门", difficulty = "EXTREME", unlockWave = 95, enemyComp = { VOID_LORD = 3, DEVASTATOR = 1, BATTLECRUISER = 8 }, objective = "DEFEND", objectiveTarget = 15, rewards = { purpleCrystal = 120, rainbowCrystal = 30, credits = 1200 } },
            { id = "STAGE_3_3", name = "最终决战", difficulty = "EXTREME", unlockWave = 110, enemyComp = { DEVASTATOR = 2, VOID_LORD = 4, CARRIER = 5 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 100, rareItem = "VOID_LORD_TOKEN" } },
        },
        chapterRewards = { rainbowCrystal = 80, title = "深渊征服者", skin = "VOID_HUNTER" },
    },
    {
        id = "CHAPTER_4", name = "第四章：星际黎明",
        description = "击败虚空领主后，银河迎来了久违的和平。但新的威胁正在暗处酝酿...",
        requiredWave = 130,
        stages = {
            { id = "STAGE_4_1", name = "和平的代价", difficulty = "MEDIUM", unlockWave = 130, enemyComp = { DESTROYER = 10, BATTLECRUISER = 5, CARRIER = 3 }, objective = "ASSAULT", objectiveTarget = 0, rewards = { blueCrystal = 500, credits = 1500 } },
            { id = "STAGE_4_2", name = "内部叛徒", difficulty = "HARD", unlockWave = 145, enemyComp = { BATTLECRUISER = 8, STEALTH = 6, RAILGUN = 2 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { purpleCrystal = 150, credits = 2000 } },
            { id = "STAGE_4_3", name = "黎明前的黑暗", difficulty = "EXTREME", unlockWave = 160, enemyComp = { RAILGUN = 4, DEVASTATOR = 2, VOID_LORD = 3 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 50, rareItem = "STRATEGIST_TOKEN" } },
        },
        chapterRewards = { purpleCrystal = 200, title = "银河守护者", skin = "GUARDIAN" },
    },
    {
        id = "CHAPTER_5", name = "第五章：终极挑战",
        description = "传说中最强大的敌人现身，只有真正的银河英雄才能战胜它...",
        requiredWave = 180,
        stages = {
            { id = "STAGE_5_1", name = "传说的开始", difficulty = "EXTREME", unlockWave = 180, enemyComp = { DEVASTATOR = 3, VOID_LORD = 5, RAILGUN = 4 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 80, credits = 3000 } },
            { id = "STAGE_5_2", name = "最终试炼", difficulty = "NIGHTMARE", unlockWave = 200, enemyComp = { DEVASTATOR = 5, VOID_LORD = 6, RAILGUN = 5 }, objective = "SURVIVE", objectiveTarget = 5, rewards = { rainbowCrystal = 150, rareItem = "TITAN_TOKEN" } },
            { id = "STAGE_5_3", name = "银河飞升", difficulty = "NIGHTMARE", unlockWave = 220, enemyComp = { DEVASTATOR = 8, VOID_LORD = 8, RAILGUN = 6, ENGINEER = 4 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 300, title = "银河英雄", avatar = "GALACTIC_HERO" } },
        },
        chapterRewards = { rainbowCrystal = 500, title = "银河传奇", avatar = "GALACTIC_LEGEND", skin = "LEGENDARY_COMMANDER" },
    },
    -- ============================================================================
    -- V3.0 P2-2: 新战役章节（第6-8章）
    -- ============================================================================
    {
        id = "CHAPTER_6", name = "第六章：星际贸易联盟",
        description = "银河贸易联盟的邀请带来了新的机遇与挑战...",
        requiredWave = 250,
        stages = {
            { id = "STAGE_6_1", name = "贸易港的麻烦", difficulty = "MEDIUM", unlockWave = 250, enemyComp = { PIRATE_BOSS = 1, FIGHTER = 15, DESTROYER = 8 }, objective = "ASSAULT", objectiveTarget = 0, rewards = { credits = 5000, blueCrystal = 300 } },
            { id = "STAGE_6_2", name = "商业间谍", difficulty = "HARD", unlockWave = 270, enemyComp = { STEALTH = 8, DESTROYER = 6, CORVETTE = 4 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { credits = 8000, purpleCrystal = 100 } },
            { id = "STAGE_6_3", name = "市场危机", difficulty = "EXTREME", unlockWave = 290, enemyComp = { BATTLECRUISER = 10, CARRIER = 5, PIRATE_BOSS = 1 }, objective = "DEFEND", objectiveTarget = 12, rewards = { credits = 10000, rainbowCrystal = 50 } },
        },
        chapterRewards = { credits = 20000, title = "商业大亨", skin = "TRADER_LORD" },
    },
    {
        id = "CHAPTER_7", name = "第七章：虚空边境",
        description = "虚空边境出现变异敌人，银河再次面临危机...",
        requiredWave = 320,
        stages = {
            { id = "STAGE_7_1", name = "变异感染者", difficulty = "HARD", unlockWave = 320, enemyComp = { MUTANT_VOID = 10, VOID_LORD = 3, DESTROYER = 8 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { purpleCrystal = 200, mutantChance = 0.3 } },
            { id = "STAGE_7_2", name = "虚空裂隙", difficulty = "EXTREME", unlockWave = 350, enemyComp = { MUTANT_VOID = 15, VOID_LORD = 5, DEVASTATOR = 2 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 80, mutantChance = 0.5 } },
            { id = "STAGE_7_3", name = "虚空领主复苏", difficulty = "NIGHTMARE", unlockWave = 380, enemyComp = { VOID_LORD_SUPREME = 1, MUTANT_VOID = 20, DEVASTATOR = 4 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 150, rareItem = "VOID_ESSENCE" } },
        },
        chapterRewards = { rainbowCrystal = 200, title = "虚空行者", skin = "VOID_WALKER" },
    },
    {
        id = "CHAPTER_8", name = "第八章：银河危机",
        description = "银河面临最严峻的考验，宿敌的真正实力终于显露...",
        requiredWave = 420,
        stages = {
            { id = "STAGE_8_1", name = "宿敌现身", difficulty = "EXTREME", unlockWave = 420, enemyComp = { NEMESIS_BOSS = 1, BATTLECRUISER = 12, CARRIER = 6 }, objective = "ASSAULT", objectiveTarget = 0, rewards = { rainbowCrystal = 150, title = "宿敌猎人" } },
            { id = "STAGE_8_2", name = "最终决战", difficulty = "NIGHTMARE", unlockWave = 450, enemyComp = { NEMESIS_BOSS_SUPREME = 1, DEVASTATOR = 6, VOID_LORD = 8 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 300, rareItem = "NEMESIS_TOKEN" } },
            { id = "STAGE_8_3", name = "银河重塑", difficulty = "NIGHTMARE", unlockWave = 500, enemyComp = { GALAXY_WILL = 1, DEVASTATOR = 10, VOID_LORD = 10, RAILGUN = 8 }, objective = "ELIMINATE", objectiveTarget = 0, rewards = { rainbowCrystal = 500, title = "银河救世主", avatar = "GALAXY_SAVIOR" } },
        },
        chapterRewards = { rainbowCrystal = 1000, title = "银河传奇", avatar = "ULTIMATE_LEGEND", skin = "GALACTIC_GOD" },
    },
}

-- 剧情对话
M.CAMPAIGN_DIALOGUE = {
    ["STAGE_P1_START"] = { speaker = "指挥官", speakerTitle = "抵抗军临时指挥官", text = "各单位注意，前方检测到敌方侦察舰队信号。", emotion = "DETERMINED", portrait = "commander_default" },
    ["STAGE_1_1_START"] = { speaker = "指挥官", speakerTitle = "抵抗军指挥官", text = "我们收到了来自前线的求救信号，立即出发！", emotion = "ALERT", portrait = "commander_default" },
    ["STAGE_1_2_START"] = { speaker = "副官", speakerTitle = "抵抗军副官", text = "敌人的主力正在集结，准备防御！", emotion = "ALERT", portrait = "officer_default" },
    ["STAGE_1_3_START"] = { speaker = "指挥官", speakerTitle = "抵抗军指挥官", text = "虚空领主出现了...全军戒备，不惜一切代价击杀它！", emotion = "ALERT", portrait = "commander_default" },
    ["STAGE_3_1_START"] = { speaker = "情报官", speakerTitle = "抵抗军情报官", text = "检测到深渊方向的大量虚空能量波动，那里似乎有什么东西正在苏醒...", emotion = "WORRIED", portrait = "officer_default" },
    ["STAGE_3_1_END"] = { speaker = "指挥官", speakerTitle = "抵抗军指挥官", text = "这些虚空生物比预想的更强大。但我们别无选择，继续前进！", emotion = "DETERMINED", portrait = "commander_default" },
    ["STAGE_3_2_START"] = { speaker = "科学家", speakerTitle = "抵抗军首席科学家", text = "这就是深渊之门的能量源...如果让它完全打开，整个银河都将被吞噬！", emotion = "ALERT", portrait = "scientist_default" },
    ["STAGE_3_3_START"] = { speaker = "虚空领主", speakerTitle = "深渊君主", text = "渺小的生命，你们竟敢挑战深渊？让我看看你们有什么资本...", emotion = "ANGRY", portrait = "void_lord" },
    ["STAGE_3_3_END"] = { speaker = "指挥官", speakerTitle = "抵抗军指挥官", text = "我们...做到了。深渊领主的威胁终于解除了。但这只是开始...", emotion = "HAPPY", portrait = "commander_default" },
    ["STAGE_4_1_START"] = { speaker = "副官", speakerTitle = "抵抗军副官", text = "指挥官，银河议会发来通讯，表彰我们的胜利。但内部似乎有些不稳...", emotion = "WORRIED", portrait = "officer_default" },
    ["STAGE_4_2_START"] = { speaker = "叛徒", speakerTitle = "内鬼", text = "你太天真了，指挥官。这个银河需要真正的统治者，而不是你们这些理想主义者。", emotion = "ANGRY", portrait = "traitor_default" },
    ["STAGE_4_3_START"] = { speaker = "指挥官", speakerTitle = "抵抗军指挥官", text = "黎明前最黑暗的时刻...但只要我们还站着，就绝不会放弃！", emotion = "DETERMINED", portrait = "commander_default" },
    ["STAGE_5_1_START"] = { speaker = "古老存在", speakerTitle = "银河守护者", text = "能够走到这里的凡人...你证明了自己的价值。但真正的试炼才刚刚开始。", emotion = "NEUTRAL", portrait = "ancient_one" },
    ["STAGE_5_2_START"] = { speaker = "指挥官", speakerTitle = "银河英雄", text = "这就是传说中的终极试炼吗？来吧，我不会再退缩！", emotion = "DETERMINED", portrait = "commander_default" },
    ["STAGE_5_3_START"] = { speaker = "最终Boss", speakerTitle = "银河意志", text = "你终于来了，银河的英雄。我是这片星系的意志，现在，是时候证明你是否配得上这个称号了！", emotion = "ALERT", portrait = "final_boss" },
    ["STAGE_5_3_END"] = { speaker = "指挥官", speakerTitle = "银河传奇", text = "我...做到了。银河从此迎来了真正的和平。这是我职责的终点，也是新篇章的起点。", emotion = "HAPPY", portrait = "commander_default" },
    -- V3.0 新章节对话
    ["STAGE_6_1_START"] = { speaker = "贸易商", speakerTitle = "银河贸易联盟代表", text = "欢迎，银河英雄。贸易联盟需要你的帮助来解决一些...麻烦。", emotion = "NEUTRAL", portrait = "trader_default" },
    ["STAGE_6_2_START"] = { speaker = "副官", speakerTitle = "情报官", text = "指挥官，有间谍潜入了我们的舰队。他们在窃取贸易机密！", emotion = "WORRIED", portrait = "officer_default" },
    ["STAGE_6_3_START"] = { speaker = "黑市商人", speakerTitle = "银河黑市首领", text = "哈！贸易联盟的防线不堪一击。这市场迟早是我们的！", emotion = "ANGRY", portrait = "pirate_default" },
    ["STAGE_7_1_START"] = { speaker = "科学家", speakerTitle = "虚空研究者", text = "这些是...被虚空感染的舰船！它们比普通敌人更加狂暴和危险。", emotion = "ALERT", portrait = "scientist_default" },
    ["STAGE_7_2_START"] = { speaker = "指挥官", speakerTitle = "银河英雄", text = "虚空裂隙...如果不阻止它，整个银河都会被虚空吞噬。", emotion = "DETERMINED", portrait = "commander_default" },
    ["STAGE_7_3_START"] = { speaker = "虚空领主", speakerTitle = "虚空君主", text = "愚蠢的凡人...你们以为能阻止虚空的扩张？太天真了！", emotion = "ANGRY", portrait = "void_lord" },
    ["STAGE_8_1_START"] = { speaker = "神秘声音", speakerTitle = "未知存在", text = "终于...你就是我等待的那个存在。银河的命运将因你而改变。", emotion = "NEUTRAL", portrait = "ancient_one" },
    ["STAGE_8_2_START"] = { speaker = "宿敌", speakerTitle = "银河的阴影", text = "好久不见，银河英雄。这一次，你不会再有胜算。", emotion = "ANGRY", portrait = "nemesis_default" },
    ["STAGE_8_3_START"] = { speaker = "银河意志", speakerTitle = "银河本体", text = "证明你自己，凡人。只有真正的救世主才配重塑银河的命运。", emotion = "NEUTRAL", portrait = "galaxy_will" },
}

-- 剧情分支
M.CAMPAIGN_BRANCHES = {
    { id = "BRANCH_CH1_END", chapterId = "CHAPTER_1", triggerAfter = "STAGE_1_3", choices = {
        { id = "PURSUIT", text = "追击帝国残部", effect = { followUp = "CHAPTER_2_STAGE_1", bonus = { blueCrystal = 50 } } },
        { id = "RETREAT", text = "战略撤退重整", effect = { followUp = "CHAPTER_2_STAGE_1", bonus = { healthRestore = 0.5 } } },
    } },
    { id = "BRANCH_CH3_END", chapterId = "CHAPTER_3", triggerAfter = "STAGE_3_3", choices = {
        { id = "EXPLORE_VOID", text = "探索深渊残余", effect = { followUp = "CHAPTER_4_STAGE_1", bonus = { rainbowCrystal = 30 } } },
        { id = "HEAL_TROOPS", text = "全军休整", effect = { followUp = "CHAPTER_4_STAGE_1", bonus = { healthRestore = 1.0 } } },
    } },
    { id = "BRANCH_CH4_END", chapterId = "CHAPTER_4", triggerAfter = "STAGE_4_3", choices = {
        { id = "CHASE_TRAITOR", text = "追击叛徒", effect = { followUp = "CHAPTER_5_STAGE_1", bonus = { purpleCrystal = 100 } } },
        { id = "PREPARE_ARMY", text = "积蓄力量", effect = { followUp = "CHAPTER_5_STAGE_1", bonus = { fleetCapacityBonus = 10 } } },
    } },
}

return M
