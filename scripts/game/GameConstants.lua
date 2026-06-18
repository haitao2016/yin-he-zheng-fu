---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/GameConstants.lua  -- 战役/赛季/指挥官/公会/银河事件 常量扩展
-- V2.8 P0 系列新增
-- ============================================================================

-- ============================================================================
-- M1: 战役模式系统常量
-- ============================================================================

CAMPAIGN_CHAPTERS = {
    {
        id = "PROLOGUE",
        name = "序章：星火燎原",
        description = "银河边缘的殖民地遭到袭击，你被征召加入抵抗军...",
        requiredWave = 0,
        stages = {
            { id = "STAGE_P1", name = "初战告捷", difficulty = "EASY", unlockWave = 0,
              enemyComp = { FIGHTER = 5, DESTROYER = 2 },
              objective = "ASSAULT", objectiveTarget = 0,
              rewards = { blueCrystal = 30, credits = 100 } },
            { id = "STAGE_P2", name = "艰难抵抗", difficulty = "EASY", unlockWave = 5,
              enemyComp = { FIGHTER = 8, DESTROYER = 3, CORVETTE = 2 },
              objective = "DEFEND", objectiveTarget = 5,
              rewards = { blueCrystal = 50, credits = 150 } },
            { id = "STAGE_P3", name = "战术撤退", difficulty = "MEDIUM", unlockWave = 10,
              enemyComp = { DESTROYER = 5, CORVETTE = 4, BATTLECRUISER = 1 },
              objective = "SURVIVE", objectiveTarget = 3,
              rewards = { blueCrystal = 80, purpleCrystal = 10, credits = 200 } },
        },
        chapterRewards = { blueCrystal = 100, skin = "CAMPAIGN_PILOT" },
    },
    {
        id = "CHAPTER_1",
        name = "第一章：黑暗降临",
        description = "一支神秘舰队出现在银河核心区域...",
        requiredWave = 15,
        stages = {
            { id = "STAGE_1_1", name = "遭遇战", difficulty = "MEDIUM", unlockWave = 15,
              enemyComp = { DESTROYER = 6, CORVETTE = 4, BATTLECRUISER = 2 },
              objective = "ELIMINATE", objectiveTarget = 0,
              rewards = { blueCrystal = 100, credits = 300 } },
            { id = "STAGE_1_2", name = "围城", difficulty = "HARD", unlockWave = 25,
              enemyComp = { BATTLECRUISER = 4, DESTROYER = 5, CARRIER = 1 },
              objective = "DEFEND", objectiveTarget = 10,
              rewards = { blueCrystal = 150, purpleCrystal = 20, credits = 400 } },
            { id = "STAGE_1_3", name = "决战", difficulty = "HARD", unlockWave = 35,
              enemyComp = { BATTLECRUISER = 3, CARRIER = 2, VOID_LORD = 1 },
              objective = "ELIMINATE", objectiveTarget = 0,
              rewards = { blueCrystal = 200, purpleCrystal = 30, rareItem = "LEGENDARY_TOKEN" } },
        },
        chapterRewards = { blueCrystal = 200, rareItem = "LEGENDARY_SHIP_TOKEN" },
    },
    {
        id = "CHAPTER_2",
        name = "第二章：帝国反击",
        description = "帝国舰队开始大规模围剿叛军...",
        requiredWave = 50,
        stages = {
            { id = "STAGE_2_1", name = "帝国先遣队", difficulty = "HARD", unlockWave = 50,
              enemyComp = { DESTROYER = 8, BATTLECRUISER = 4, STEALTH = 3 },
              objective = "ELIMINATE", objectiveTarget = 0,
              rewards = { blueCrystal = 250, purpleCrystal = 40, credits = 500 } },
            { id = "STAGE_2_2", name = "行星攻坚", difficulty = "EXTREME", unlockWave = 60,
              enemyComp = { BATTLECRUISER = 6, CARRIER = 3, DEVASTATOR = 1 },
              objective = "ELIMINATE", objectiveTarget = 0,
              rewards = { blueCrystal = 300, purpleCrystal = 60, rainbowCrystal = 10 } },
        },
        chapterRewards = { purpleCrystal = 50, rainbowCrystal = 20, skin = "REBEL_COMMANDER" },
    },
}

-- 关卡类型
STAGE_OBJECTIVES = {
    ASSAULT  = { name = "突袭战", desc = "消灭所有敌人" },
    DEFEND   = { name = "防守战", desc = "抵御敌人进攻" },
    SURVIVE  = { name = "生存战", desc = "存活指定时间" },
    ELIMINATE = { name = "斩首行动", desc = "击败Boss" },
    ESCORT   = { name = "护送战", desc = "保护目标到达" },
}

-- 关卡难度
STAGE_DIFFICULTY = {
    EASY     = { name = "简单", healthMult = 0.8, dmgMult = 0.8, rewardsMult = 0.8 },
    MEDIUM   = { name = "普通", healthMult = 1.0, dmgMult = 1.0, rewardsMult = 1.0 },
    HARD     = { name = "困难", healthMult = 1.3, dmgMult = 1.3, rewardsMult = 1.3 },
    EXTREME  = { name = "噩梦", healthMult = 1.8, dmgMult = 1.8, rewardsMult = 2.0 },
}

-- 剧情对话
CAMPAIGN_DIALOGUE = {
    ["STAGE_P1_START"] = {
        speaker = "指挥官", speakerTitle = "抵抗军临时指挥官",
        text = "各单位注意，前方检测到敌方侦察舰队信号。",
        emotion = "DETERMINED", portrait = "commander_default",
    },
    ["STAGE_P1_END"] = {
        speaker = "指挥官", speakerTitle = "抵抗军临时指挥官",
        text = "漂亮的首战！继续保持警惕，敌人不会给我们喘息的机会。",
        emotion = "HAPPY", portrait = "commander_default",
    },
    ["STAGE_P2_START"] = {
        speaker = "副官", speakerTitle = "抵抗军情报官",
        text = "指挥官，帝国舰队正在集结，我们的防线撑不了多久！",
        emotion = "WORRIED", portrait = "officer_default",
    },
    ["STAGE_P2_END"] = {
        speaker = "指挥官", speakerTitle = "抵抗军临时指挥官",
        text = "有序撤退！我们需要重整旗鼓。",
        emotion = "DETERMINED", portrait = "commander_default",
    },
    ["STAGE_1_1_START"] = {
        speaker = "未知信号", speakerTitle = "",
        text = "这里是帝国舰队，你们已经被包围了。立即投降！",
        emotion = "ANGRY", portrait = "empire_officer",
    },
    ["STAGE_1_3_START"] = {
        speaker = "指挥官", speakerTitle = "抵抗军指挥官",
        text = "虚空领主出现了...全军戒备，不惜一切代价击杀它！",
        emotion = "ALERT", portrait = "commander_default",
    },
}

-- 剧情分支选择
CAMPAIGN_BRANCHES = {
    {
        id = "BRANCH_CH1_END",
        chapterId = "CHAPTER_1",
        triggerAfter = "STAGE_1_3",
        choices = {
            { id = "PURSUIT", text = "追击帝国残部", effect = { followUp = "CHAPTER_2_STAGE_1", bonus = { blueCrystal = 50 } } },
            { id = "RETREAT", text = "战略撤退重整", effect = { followUp = "CHAPTER_2_STAGE_1", bonus = { healthRestore = 0.5 } } },
        },
    },
}

-- ============================================================================
-- M2: 赛季系统常量
-- ============================================================================

SEASONS = {
    {
        id = "SEASON_1",
        name = "第一赛季：星际远征",
        shortName = "星际远征",
        startDate = "2026-07-01",
        endDate = "2026-09-30",
        duration = 91,
        theme = "MILITARY",
        themeColor = { 0.2, 0.5, 0.8, 1.0 },
        exclusiveRewards = {
            { id = "SKIN_SEASON_NAVY", name = "赛季海军涂装", type = "SHIP_SKIN", rarity = "EPIC" },
            { id = "TITLE_SEASON_MASTER", name = "赛季大师", type = "TITLE", rarity = "LEGENDARY" },
            { id = "FRAME_SEASON_GOLD", name = "金色赛季框", type = "PROFILE_FRAME", rarity = "RARE" },
            { id = "AVATAR_SEASON_HERO", name = "赛季英雄头像", type = "AVATAR", rarity = "EPIC" },
        },
    },
    {
        id = "SEASON_2",
        name = "第二赛季：虚空裂隙",
        shortName = "虚空裂隙",
        startDate = "2026-10-01",
        endDate = "2026-12-31",
        duration = 92,
        theme = "VOID",
        themeColor = { 0.4, 0.1, 0.6, 1.0 },
        exclusiveRewards = {
            { id = "SKIN_SEASON_VOID", name = "虚空战甲涂装", type = "SHIP_SKIN", rarity = "EPIC" },
            { id = "TITLE_VOID_HUNTER", name = "虚空猎手", type = "TITLE", rarity = "LEGENDARY" },
            { id = "FRAME_SEASON_VOID", name = "虚空赛季框", type = "PROFILE_FRAME", rarity = "RARE" },
        },
    },
}

-- 赛季积分奖励里程碑
SEASON_POINT_REWARDS = {
    { points = 500,  reward = { blueCrystal = 30 }, icon = "reward_crystal_blue" },
    { points = 1000, reward = { blueCrystal = 50, credits = 500 }, icon = "reward_bundle_1" },
    { points = 2000, reward = { purpleCrystal = 20 }, icon = "reward_crystal_purple" },
    { points = 3500, reward = { skin = "SKIN_SEASON_NAVY" }, icon = "reward_skin" },
    { points = 5000, reward = { rainbowCrystal = 10 }, icon = "reward_crystal_rainbow" },
    { points = 7500, reward = { frame = "FRAME_SEASON_GOLD" }, icon = "reward_frame" },
    { points = 10000, reward = { title = "TITLE_SEASON_MASTER" }, icon = "reward_title" },
}

-- 赛季状态（运行时）
SEASON_STATE = {
    currentSeasonId = "SEASON_1",
    startTime = 0,
    endTime = 0,
    daysRemaining = 0,
    playerPoints = 0,
    tasksCompleted = {},
    rewardsClaimed = {},
    weeklyTasksReset = 0,
}

-- ============================================================================
-- M4: 指挥官系统常量
-- ============================================================================

COMMANDERS = {
    ["ADMIRAL_CHEN"] = {
        id = "ADMIRAL_CHEN",
        name = "陈将军",
        title = "帝国舰队指挥官",
        rarity = "LEGENDARY",
        faction = "EMPIRE",
        portrait = "commander_admiral_chen",
        unlocked = true,
        recruitCost = nil,
        skills = {
            {
                id = "TACTICAL_RETREAT",
                name = "战术撤退",
                desc = "紧急后撤，降低受到的伤害 50%，持续 5 秒",
                cooldown = 30,
                duration = 5,
                effect = { type = "DMG_REDUCTION", value = 0.5 },
                icon = "skill_retreat",
                hotkey = "Q",
            },
            {
                id = "EMPire_COMMAND",
                name = "帝国号令",
                desc = "提升所有友舰攻击力 25%，持续 8 秒",
                cooldown = 45,
                duration = 8,
                effect = { type = "ATK_BOOST", value = 0.25 },
                icon = "skill_command",
                hotkey = "W",
            },
        },
        passive = {
            id = "EMPIRE_LOGISTICS",
            name = "帝国后勤",
            desc = "所有舰船生产时间降低 15%",
            effects = { buildSpeedMult = 0.85 },
        },
        lore = "陈将军是帝国最资深的指挥官，擅长以少胜多。在多次战役中展现出卓越的战术天赋。",
    },
    ["REBEL_LEADER"] = {
        id = "REBEL_LEADER",
        name = "艾琳·诺克斯",
        title = "自由联盟领袖",
        rarity = "LEGENDARY",
        faction = "REBEL",
        portrait = "commander_rebel_leader",
        unlocked = true,
        recruitCost = nil,
        skills = {
            {
                id = "INSPIRING_RALLY",
                name = "鼓舞士气",
                desc = "提升所有友舰攻击力 30%，持续 10 秒",
                cooldown = 40,
                duration = 10,
                effect = { type = "ATK_BOOST", value = 0.3 },
                icon = "skill_rally",
                hotkey = "Q",
            },
            {
                id = "REBEL_FRENZY",
                name = "叛军狂热",
                desc = "所有友舰攻击速度提升 50%，持续 6 秒",
                cooldown = 50,
                duration = 6,
                effect = { type = "ATK_SPEED_BOOST", value = 0.5 },
                icon = "skill_frenzy",
                hotkey = "W",
            },
        },
        passive = {
            id = "REBEL_SPIRIT",
            name = "叛军精神",
            desc = "低血量时（<30%），伤害提升 25%",
            effects = { lowHpDmgBoost = 0.25 },
        },
        lore = "艾琳曾是帝国科学院的天才科学家，因反对帝国的暴政而起义，如今成为自由联盟的领袖。",
    },
    ["MERCENARY_BOSS"] = {
        id = "MERCENARY_BOSS",
        name = "雷克斯·沃克",
        title = "佣兵之王",
        rarity = "EPIC",
        faction = "NEUTRAL",
        portrait = "commander_mercenary",
        unlocked = false,
        recruitCost = { blueCrystal = 200 },
        skills = {
            {
                id = "CONTRACT_BREAKER",
                name = "毁约打击",
                desc = "对目标造成 300% 伤害的毁灭性打击",
                cooldown = 60,
                effect = { type = "EXECUTE", value = 3.0, targetEnemy = true },
                icon = "skill_breaker",
                hotkey = "Q",
            },
            {
                id = "GOLDEN_CONTRACT",
                name = "黄金契约",
                desc = "击杀敌人后恢复 15% 最大生命值",
                cooldown = 0,
                effect = { type = "LIFESTEAL_KILL", value = 0.15 },
                icon = "skill_contract",
                hotkey = nil,
            },
        },
        passive = {
            id = "MERCENARY_TACTICS",
            name = "佣兵战术",
            desc = "击杀敌人后获得 10% 攻击加成，可叠加 5 层",
            effects = { killStackAtk = { bonus = 0.1, maxStacks = 5, duration = 10 } },
        },
        lore = "雷克斯是最致命的佣兵，只为出价最高的人服务。他的战术冷酷而高效。",
    },
    ["SHADOW_ASSASSIN"] = {
        id = "SHADOW_ASSASSIN",
        name = "夜影",
        title = "幽灵舰队指挥官",
        rarity = "EPIC",
        faction = "REBEL",
        portrait = "commander_shadow",
        unlocked = false,
        recruitCost = { purpleCrystal = 30 },
        skills = {
            {
                id = "PHASE_SHIFT",
                name = "相位位移",
                desc = "瞬间传送到目标位置，短暂无敌",
                cooldown = 25,
                effect = { type = "TELEPORT", invulnDuration = 1.5 },
                icon = "skill_phase",
                hotkey = "Q",
            },
            {
                id = "SHADOW_STRIKE",
                name = "暗影打击",
                desc = "下一次攻击造成 500% 伤害",
                cooldown = 35,
                effect = { type = "NEXT_ATTACK_MULT", value = 5.0 },
                icon = "skill_shadow",
                hotkey = "W",
            },
        },
        passive = {
            id = "GHOST_PROTOCOL",
            name = "幽灵协议",
            desc = "隐形舰持续时间延长 30%",
            effects = { stealthDurationMult = 1.3 },
        },
        lore = "夜影是一支神秘舰队的指挥官，擅长渗透和暗杀战术。",
    },
}

-- 指挥官招募选项
COMMANDER_RECRUITMENT = {
    FREE = { desc = "免费指挥官", guarantee = "COMMON", commanders = { "ADMIRAL_CHEN", "REBEL_LEADER" } },
    PREMIUM = { desc = "高级招募", cost = { blueCrystal = 500 },
                guarantee = "RARE", chance = { EPIC = 0.15, LEGENDARY = 0.05 } },
    PREMIUM_PLUS = { desc = "高级+招募", cost = { rainbowCrystal = 10 },
                     guarantee = "EPIC", chance = { LEGENDARY = 0.20 } },
}

-- 当前选中的指挥官
CURRENT_COMMANDER = "ADMIRAL_CHEN"

-- 指挥官技能冷却状态
COMMANDER_SKILL_COOLDOWNS = {}

-- ============================================================================
-- M3: 公会系统常量
-- ============================================================================

-- 公会等级奖励
GUILD_LEVEL_REWARDS = {
    { level = 1, exp = 0,       reward = { bonusGold = 0.05 },                  memberSlot = 10 },
    { level = 2, exp = 1000,    reward = { bonusGold = 0.10 },                  memberSlot = 15 },
    { level = 3, exp = 3000,    reward = { bonusGold = 0.15 },                  memberSlot = 20 },
    { level = 4, exp = 7000,    reward = { bonusGold = 0.20 },                  memberSlot = 30 },
    { level = 5, exp = 15000,   reward = { bonusGold = 0.25 },                  memberSlot = 50 },
    { level = 6, exp = 30000,   reward = { bonusGold = 0.30, bonusExp = 0.10 }, memberSlot = 75 },
    { level = 7, exp = 50000,   reward = { bonusGold = 0.35, bonusExp = 0.15 }, memberSlot = 100 },
    { level = 8, exp = 80000,   reward = { bonusGold = 0.40, bonusExp = 0.20 }, memberSlot = 150 },
}

-- 公会设置选项
GUILD_JOIN_TYPES = {
    OPEN     = { id = "OPEN",     name = "开放加入",     desc = "任何人都可以立即加入" },
    APPROVAL = { id = "APPROVAL", name = "需要审批",     desc = "需要会长/官员审批" },
    INVITE   = { id = "INVITE",   name = "仅邀请",       desc = "只能通过邀请加入" },
}

-- 公会成员角色
GUILD_ROLES = {
    LEADER  = { name = "会长",    permissions = { kick = true, promote = true, settings = true, disband = true } },
    OFFICER = { name = "官员",    permissions = { kick = true, promote = false, settings = false, disband = false } },
    MEMBER  = { name = "成员",    permissions = { kick = false, promote = false, settings = false, disband = false } },
}

-- 公会每日任务
GUILD_DAILY_TASKS = {
    { id = "TASK_DONATE", name = "公会捐赠", desc = "向公会捐赠 100 金属",
      target = 100, type = "DONATE", reward = { contribution = 50, guildExp = 10 } },
    { id = "TASK_BATTLE", name = "公会战斗", desc = "参与公会活动战斗 3 次",
      target = 3, type = "BATTLE", reward = { contribution = 30, guildExp = 5 } },
    { id = "TASK_RALLY", name = "公会集结", desc = "响应集结请求",
      target = 1, type = "RALLY", reward = { contribution = 100, guildExp = 20 } },
}

-- 公会每周挑战
GUILD_WEEKLY_TASKS = {
    { id = "WEEKLY_WAVE", name = "周波次挑战", desc = "本周累计达到波次 100",
      target = 100, type = "TOTAL_WAVE", reward = { contribution = 500, guildExp = 100, item = "GUILD_CHEST" } },
    { id = "WEEKLY_KILL", name = "周击杀挑战", desc = "本周累计击杀 500 艘敌舰",
      target = 500, type = "TOTAL_KILL", reward = { contribution = 300, guildExp = 60 } },
    { id = "WEEKLY_BOSS", name = "Boss击杀", desc = "本周击败 Boss 5 次",
      target = 5, type = "BOSS_KILL", reward = { contribution = 400, guildExp = 80, item = "LEGENDARY_BOX" } },
}

-- 运行时公会数据（本地模拟）
RUNTIME_GUILDS = {}
RUNTIME_PLAYER_GUILD = {}

-- ============================================================================
-- M1: 银河事件系统常量
-- ============================================================================

GALAXY_EVENTS = {
    {
        id = "STARGATE_OPEN",
        name = "星门开启",
        desc = "星门开启，提供快速移动通道",
        duration = 120,
        probability = 0.03,
        icon = "event_stargate",
        effects = {
            { type = "TRAVEL_SPEED", value = 2.0 },
            { type = "TRADE_BONUS", value = 0.3 },
        },
    },
    {
        id = "WORMHOLE_APPEARS",
        name = "虫洞出现",
        desc = "神秘虫洞连接两个遥远区域",
        duration = 180,
        probability = 0.02,
        icon = "event_wormhole",
        effects = {
            { type = "NEW_PATH", planets = { "RANDOM_A", "RANDOM_B" } },
        },
    },
    {
        id = "PIRATE_RAID",
        name = "海盗袭击",
        desc = "海盗舰队袭击附近星球，完成可获得悬赏金",
        duration = 0,
        probability = 0.06,
        icon = "event_pirate",
        effects = {
            { type = "PLANET_RAID", planetId = "RANDOM" },
            { type = "REWARD_PIRATE_DEFEATED", bounty = 100 },
        },
    },
    {
        id = "RARE_MINERAL_DISCOVERY",
        name = "稀有矿物发现",
        desc = "探测到稀有矿物资源，采矿效率大幅提升",
        duration = 300,
        probability = 0.015,
        icon = "event_mineral",
        effects = {
            { type = "RARE_NODE", planetId = "RANDOM" },
            { type = "MINE_OUTPUT", value = 2.0 },
        },
    },
    {
        id = "SOLAR_STORM",
        name = "太阳风暴",
        desc = "太阳风暴干扰电子设备",
        duration = 60,
        probability = 0.04,
        icon = "event_storm",
        effects = {
            { type = "SHIELD_PENALTY", value = 0.5 },
            { type = "STEALTH_BONUS", value = 2.0 },
        },
    },
    {
        id = "TRADE_FESTIVAL",
        name = "星际贸易节",
        desc = "贸易税全免，所有交易收益 +50%",
        duration = 240,
        probability = 0.025,
        icon = "event_festival",
        effects = {
            { type = "TRADE_BONUS", value = 0.5 },
            { type = "NO_TAX", value = true },
        },
    },
    {
        id = "ALIEN_CONTACT",
        name = "外星接触",
        desc = "与神秘外星文明建立联系",
        duration = 360,
        probability = 0.01,
        icon = "event_alien",
        effects = {
            { type = "RESEARCH_SPEED", value = 2.0 },
            { type = "RANDOM_TECH", value = 1 },
        },
    },
}

-- 活跃事件列表
ACTIVE_GALAXY_EVENTS = {}

-- 银河事件效果应用状态
GALAXY_EVENT_EFFECTS = {
    travelSpeedMult = 1.0,
    tradeBonus = 0.0,
    mineOutputMult = 1.0,
    shieldPenalty = 1.0,
    stealthBonus = 1.0,
    noTax = false,
    researchSpeedMult = 1.0,
}

-- ============================================================================
-- P1-5: 阵型系统常量
-- ============================================================================

SHIP_FORMATIONS = {
    {
        id = "VANGUARD",
        name = "前卫阵型",
        desc = "舰船分散布置，减小AOE伤害",
        icon = "formation_vanguard",
        effect = { aoeReduction = 0.2, spreadBonus = 0.1 },
        shipOrder = { "DESTROYER", "BATTLECRUISER" },
    },
    {
        id = "PHALANX",
        name = "方阵",
        desc = "紧密排列，火力集中",
        icon = "formation_phalanx",
        effect = { dmgBonus = 0.15, aoeExposure = 0.3 },
        shipOrder = { "BATTLECRUISER", "DESTROYER", "CARRIER" },
    },
    {
        id = "FLANK",
        name = "两翼包抄",
        desc = "从侧翼进攻，机动性提升",
        icon = "formation_flank",
        effect = { speedBonus = 0.2, sideDmgBonus = 0.25 },
        shipOrder = { "STEALTH", "DESTROYER", "CORVETTE" },
    },
    {
        id = "CRESCENT",
        name = "新月阵型",
        desc = "弧形布置，兼顾攻防",
        icon = "formation_crescent",
        effect = { defenseBonus = 0.15, dmgBonus = 0.1 },
        shipOrder = { "BATTLECRUISER", "SUPPORT", "DESTROYER" },
    },
    {
        id = "PINZHER",
        name = "钳形攻势",
        desc = "前后夹击，优先集火",
        icon = "formation_pinzher",
        effect = { focusFireBonus = 0.3, frontBackDmg = 0.2 },
        shipOrder = { "DESTROYER", "CARRIER", "DESTROYER" },
    },
    {
        id = "SKIRMISH",
        name = "游击阵型",
        desc = "保持距离，边打边退",
        icon = "formation_skirmish",
        effect = { retreatSpeedBonus = 0.3, hitAndRunDmg = 0.4 },
        shipOrder = { "STEALTH", "CORVETTE", "STEALTH" },
    },
}

-- 当前选中的阵型
CURRENT_FORMATION = "VANGUARD"

-- ============================================================================
-- V3.0 扩展: 科技树完整定义 (Tier1-5)
-- ============================================================================

TECHS = {
    -- Tier 1
    DEEP_MINING = {
        id = "DEEP_MINING", name = "深层采矿", tier = 1,
        cost = { minerals = 200 }, time = 60, prereqs = {},
        bonus = { mineralOutputMult = 1.2 },
        desc = "提升矿井产量20%。利用深层钻探技术开采行星地核资源。",
    },
    SOLAR_EFFICIENCY = {
        id = "SOLAR_EFFICIENCY", name = "高效光伏", tier = 1,
        cost = { minerals = 150, energy = 100 }, time = 45, prereqs = {},
        bonus = { energyOutputMult = 1.15 },
        desc = "电站产量+15%。改进光伏转化效率，从恒星辐射中获取更多能源。",
    },
    CRYSTAL_PROCESS = {
        id = "CRYSTAL_PROCESS", name = "晶石精炼", tier = 1,
        cost = { minerals = 300, crystal = 30 }, time = 70, prereqs = {},
        bonus = { crystalOutputMult = 1.2 },
        desc = "晶石加工效率提升20%。精密提纯工艺获得更高品质晶体。",
    },
    HULL_ALLOY = {
        id = "HULL_ALLOY", name = "合金船壳", tier = 1,
        cost = { minerals = 400 }, time = 80, prereqs = {},
        bonus = { shipHealthMult = 1.25 },
        desc = "所有舰船耐久+25%。使用星际合金强化舰体结构。",
    },

    -- Tier 2
    SHIELD_REINFORCE = {
        id = "SHIELD_REINFORCE", name = "护盾强化", tier = 2,
        cost = { minerals = 500, crystal = 50 }, time = 100,
        prereqs = { "HULL_ALLOY" },
        bonus = { shieldBonus = 100, defenseBonus = 0.1 },
        desc = "护盾值+100，防御+10%。多层能量屏障提升舰体生存能力。",
    },
    RAPID_REFINE = {
        id = "RAPID_REFINE", name = "快速精炼", tier = 2,
        cost = { minerals = 600, energy = 200 }, time = 90,
        prereqs = { "DEEP_MINING" },
        bonus = { buildSpeedMult = 0.85 },
        desc = "舰船建造时间-15%。自动化生产线加快造船速度。",
    },
    COLONY_BIOTECH = {
        id = "COLONY_BIOTECH", name = "殖民地生物科技", tier = 2,
        cost = { minerals = 400, crystal = 80 }, time = 110,
        prereqs = { "SOLAR_EFFICIENCY" },
        bonus = { colonyEfficiencyMult = 1.2 },
        desc = "殖民地效率+20%。生物工程优化殖民地运作效率。",
    },
    NANO_REPAIR = {
        id = "NANO_REPAIR", name = "纳米维修", tier = 2,
        cost = { crystals = 100, energy = 300 }, time = 120,
        prereqs = { "HULL_ALLOY" },
        bonus = { passiveRepairRate = 0.5 },
        desc = "战斗中被动回复0.5%/秒生命值。纳米机器自动修复舰体损伤。",
    },

    -- Tier 3
    WARP_DRIVE = {
        id = "WARP_DRIVE", name = "曲速引擎", tier = 3,
        cost = { minerals = 800, energy = 500, crystal = 100 }, time = 150,
        prereqs = { "SHIELD_REINFORCE" },
        bonus = { fleetSpeedMult = 1.5 },
        desc = "舰队移动速度+50%。突破性曲速场理论实现超光速航行。",
    },
    ADVANCED_WEAPONS = {
        id = "ADVANCED_WEAPONS", name = "高级武器系统", tier = 3,
        cost = { minerals = 1000, crystal = 150 }, time = 180,
        prereqs = { "HULL_ALLOY" },
        bonus = { shipDmgMult = 1.3 },
        desc = "所有战舰攻击力+30%。粒子束武器替代传统动能弹头。",
        exclusiveGroup = "TIER3_OFFENSE",
    },
    DEFENSE_MATRIX = {
        id = "DEFENSE_MATRIX", name = "防御矩阵", tier = 3,
        cost = { minerals = 800, crystal = 200, energy = 400 }, time = 180,
        prereqs = { "SHIELD_REINFORCE" },
        bonus = { shipHealthMult = 1.3, shieldMaxMult = 1.2 },
        desc = "舰队生命值+30%，护盾上限+20%。自适应防御矩阵提供全面保护。",
        exclusiveGroup = "TIER3_OFFENSE",
    },
    VOID_ANCHOR = {
        id = "VOID_ANCHOR", name = "虚空锚定", tier = 3,
        cost = { crystal = 300, energy = 600 }, time = 200,
        prereqs = { "WARP_DRIVE" },
        bonus = { enemySpeedDebuff = 0.7 },
        desc = "敌方舰队移动速度-30%。量子扰动场限制敌舰机动能力。",
    },

    -- Tier 4
    QUANTUM_CORE = {
        id = "QUANTUM_CORE", name = "量子核心", tier = 4,
        cost = { minerals = 1500, crystal = 400, energy = 800 }, time = 240,
        prereqs = { "ADVANCED_WEAPONS", "DEFENSE_MATRIX" },
        bonus = { researchSpeedMult = 1.5, coreUpgradeCostMult = 0.8 },
        desc = "科研速度+50%，核心升级费用-20%。量子纠缠计算突破科技瓶颈。",
    },
    PHASE_DRIVE = {
        id = "PHASE_DRIVE", name = "相位驱动", tier = 4,
        cost = { minerals = 1200, crystal = 300, energy = 1000 }, time = 260,
        prereqs = { "WARP_DRIVE" },
        bonus = { fleetSpeedMult = 2.0, stealthBonus = 0.3 },
        desc = "舰队速度再+50%，获得隐形能力。相位偏移技术实现短暂隐形。",
    },
    NOVA_CANNON = {
        id = "NOVA_CANNON", name = "新星炮", tier = 4,
        cost = { minerals = 2000, crystal = 500, nuclear = 200 }, time = 300,
        prereqs = { "ADVANCED_WEAPONS" }, coreLevelReq = 5,
        bonus = { dmgMult = 1.5, aoeRadiusMult = 1.8, battleStartSkillCharge = 1 },
        desc = "AOE半径+80%，全体伤害+50%。聚焦恒星能量释放毁灭性打击。",
    },
    FORTRESS_PROTOCOL = {
        id = "FORTRESS_PROTOCOL", name = "要塞协议", tier = 4,
        cost = { minerals = 1800, crystal = 600, energy = 1200 }, time = 300,
        prereqs = { "DEFENSE_MATRIX" }, coreLevelReq = 5,
        bonus = { shieldMaxMult = 2.0, shieldRegenPct = 0.01, baseShieldMult = 1.5 },
        desc = "基地护盾最大值翻倍，每秒恢复1%基地护盾。协同防御协议提供最大保护。",
    },
    STELLAR_SYNC = {
        id = "STELLAR_SYNC", name = "星际同步", tier = 4,
        cost = { crystal = 800, energy = 1500 }, time = 280,
        prereqs = { "VOID_ANCHOR" },
        bonus = { globalProdMult = 1.25, researchSpeedMult = 1.3 },
        desc = "全局产出+25%，科研+30%。恒星网络同步提升文明效率。",
    },

    -- Tier 5
    STELLAR_ENGINE = {
        id = "STELLAR_ENGINE", name = "恒星引擎", tier = 5,
        cost = { minerals = 3000, crystal = 1000, nuclear = 500 }, time = 400,
        prereqs = { "QUANTUM_CORE", "PHASE_DRIVE" }, coreLevelReq = 7,
        bonus = { globalSpeedMult = 1.6, battleStartAcceleration = 1 },
        desc = "全局移动速度+60%，战斗开局获得初始加速。将恒星能量转化为舰队动能。",
    },
    QUANTUM_FACTORY = {
        id = "QUANTUM_FACTORY", name = "量子工厂", tier = 5,
        cost = { minerals = 3500, crystal = 1200, energy = 2000 }, time = 450,
        prereqs = { "NOVA_CANNON", "QUANTUM_CORE" }, coreLevelReq = 7,
        bonus = { shipyardMult = 2.0, upgradeCostMult = 0.75 },
        desc = "舰船建造速度翻倍，升级费用-25%。量子复制技术大幅提升生产能力。",
    },
    VOID_FLEET = {
        id = "VOID_FLEET", name = "虚空舰队", tier = 5,
        cost = { crystal = 1500, nuclear = 800, energy = 2500 }, time = 500,
        prereqs = { "PHASE_DRIVE", "NOVA_CANNON" }, coreLevelReq = 8,
        bonus = { enemySpawnMult = 0.7, enemyDmgMult = 0.8 },
        desc = "敌方舰队生成-30%，敌舰伤害-20%。虚空投影创造假目标分散敌火力。",
    },
    FORTRESS_PROTOCOL_II = {
        id = "FORTRESS_PROTOCOL_II", name = "要塞协议II", tier = 5,
        cost = { minerals = 2500, crystal = 2000, energy = 3000 }, time = 500,
        prereqs = { "FORTRESS_PROTOCOL", "STELLAR_SYNC" }, coreLevelReq = 8,
        bonus = { baseShieldMult = 3.0, baseShieldRegenMult = 2.0, counterAttackDmg = 0.3 },
        desc = "基地护盾最大值3倍，每秒恢复2%，受攻击时触发反击护盾(30%伤害反弹)。",
    },
    CHRONO_RESEARCH = {
        id = "CHRONO_RESEARCH", name = "时序研究", tier = 5,
        cost = { crystal = 2500, energy = 4000, nuclear = 1000 }, time = 550,
        prereqs = { "STELLAR_SYNC", "QUANTUM_CORE" }, coreLevelReq = 9,
        bonus = { researchSpeedMult = 2.5, eventCooldownMult = 0.5 },
        desc = "科研速度2.5倍，事件频率减半。时间操控技术加速一切进程。",
    },
    GALACTIC_ASCEND = {
        id = "GALACTIC_ASCEND", name = "银河飞升", tier = 5,
        cost = { minerals = 5000, crystal = 3000, energy = 5000, nuclear = 1500 }, time = 600,
        prereqs = { "STELLAR_ENGINE", "QUANTUM_FACTORY", "VOID_FLEET" }, coreLevelReq = 10,
        bonus = { globalDmgMult = 2.0, fleetCapBonus = 3, skillPointBonus = 2, rewardMult = 2.0 },
        desc = "全局伤害2倍，舰队上限+3，每波技能点+2，所有奖励翻倍。银河级文明的最终形态。",
    },
}

-- 科技研究顺序（用于UI）
TECH_ORDER = {
    "DEEP_MINING", "SOLAR_EFFICIENCY", "CRYSTAL_PROCESS", "HULL_ALLOY",
    "SHIELD_REINFORCE", "RAPID_REFINE", "COLONY_BIOTECH", "NANO_REPAIR",
    "WARP_DRIVE", "ADVANCED_WEAPONS", "DEFENSE_MATRIX", "VOID_ANCHOR",
    "QUANTUM_CORE", "PHASE_DRIVE", "NOVA_CANNON", "FORTRESS_PROTOCOL", "STELLAR_SYNC",
    "STELLAR_ENGINE", "QUANTUM_FACTORY", "VOID_FLEET", "FORTRESS_PROTOCOL_II", "CHRONO_RESEARCH", "GALACTIC_ASCEND",
}

-- ============================================================================
-- V3.0 扩展: 舰船类型 (战斗舰 + 新舰种)
-- ============================================================================

SHIP_TYPES = {
    FIGHTER = {
        id = "FIGHTER", name = "战斗机", nameEn = "Fighter",
        role = "FRONT", tier = 1,
        stats = { health = 80, damage = 15, speed = 3.0, shield = 20, range = 1 },
        cost = { minerals = 50, energy = 20 }, buildTime = 15,
        unlock = { default = true },
    },
    CORVETTE = {
        id = "CORVETTE", name = "护卫舰", nameEn = "Corvette",
        role = "FLANK", tier = 1,
        stats = { health = 120, damage = 20, speed = 2.5, shield = 30, range = 1.5 },
        cost = { minerals = 80, energy = 30 }, buildTime = 20,
        unlock = { default = true },
    },
    DESTROYER = {
        id = "DESTROYER", name = "驱逐舰", nameEn = "Destroyer",
        role = "FRONT", tier = 2,
        stats = { health = 200, damage = 35, speed = 2.0, shield = 50, range = 2 },
        cost = { minerals = 150, energy = 60, crystal = 10 }, buildTime = 35,
        unlock = { tech = "HULL_ALLOY" },
    },
    BATTLECRUISER = {
        id = "BATTLECRUISER", name = "战列巡洋舰", nameEn = "Battlecruiser",
        role = "BACK", tier = 3,
        stats = { health = 350, damage = 60, speed = 1.8, shield = 80, range = 3 },
        cost = { minerals = 300, energy = 120, crystal = 30 }, buildTime = 60,
        unlock = { tech = "ADVANCED_WEAPONS" },
    },
    CARRIER = {
        id = "CARRIER", name = "航母", nameEn = "Carrier",
        role = "BACK", tier = 3,
        stats = { health = 400, damage = 40, speed = 1.5, shield = 100, range = 4 },
        cost = { minerals = 400, energy = 200, crystal = 50 }, buildTime = 90,
        unlock = { tech = "DEFENSE_MATRIX" },
    },
    VOID_LORD = {
        id = "VOID_LORD", name = "虚空领主", nameEn = "Void Lord",
        role = "BACK", tier = 4,
        stats = { health = 800, damage = 120, speed = 1.3, shield = 200, range = 5 },
        cost = { minerals = 800, energy = 400, crystal = 100, nuclear = 50 }, buildTime = 150,
        unlock = { tech = "NOVA_CANNON" },
    },
    DEVASTATOR = {
        id = "DEVASTATOR", name = "毁灭者", nameEn = "Devastator",
        role = "BACK", tier = 5,
        stats = { health = 1500, damage = 250, speed = 1.0, shield = 400, range = 6 },
        cost = { minerals = 2000, energy = 1000, crystal = 300, nuclear = 200 }, buildTime = 300,
        unlock = { tech = "GALACTIC_ASCEND" },
    },
    ENGINEER = {
        id = "ENGINEER", name = "工程维修舰", nameEn = "Engineer",
        role = "BACK", tier = 3,
        stats = { health = 250, damage = 10, speed = 2.2, shield = 80, range = 3 },
        cost = { minerals = 200, energy = 150, crystal = 40 }, buildTime = 50,
        unlock = { tech = "NANO_REPAIR" },
        specialSkill = { id = "REPAIR_DRONE", name = "维修无人机",
            effect = { aoeHealPct = 0.05, range = 2 }, cooldown = 15 },
    },
    STEALTH = {
        id = "STEALTH", name = "隐形突击舰", nameEn = "Stealth",
        role = "FLANK", tier = 3,
        stats = { health = 150, damage = 80, speed = 3.5, shield = 50, range = 2 },
        cost = { minerals = 250, energy = 200, crystal = 80 }, buildTime = 55,
        unlock = { tech = "PHASE_DRIVE" },
        specialSkill = { id = "PHASE_SHIFT", name = "相位位移",
            effect = { stealthDuration = 5, ambushDmgMult = 2.0 }, cooldown = 20 },
    },
    RAILGUN = {
        id = "RAILGUN", name = "轨道炮舰", nameEn = "Railgun",
        role = "BACK", tier = 4,
        stats = { health = 300, damage = 200, speed = 1.2, shield = 100, range = 8 },
        cost = { minerals = 500, energy = 300, crystal = 120, nuclear = 80 }, buildTime = 120,
        unlock = { tech = "NOVA_CANNON" },
        specialSkill = { id = "ORBITAL_STRIKE", name = "轨道打击",
            effect = { chargeTime = 3, dmgMult = 3.0, singleTarget = true }, cooldown = 10 },
    },
}

SHIP_TYPE_ORDER = { "FIGHTER", "CORVETTE", "DESTROYER", "BATTLECRUISER", "CARRIER", "VOID_LORD", "DEVASTATOR", "ENGINEER", "STEALTH", "RAILGUN" }

-- ============================================================================
-- V3.0 扩展: 基地核心模块 (Lv1-10)
-- ============================================================================

BASE_MODULES = {
    CORE = {
        key = "CORE", name = "核心",
        levels = {
            { level = 1, bonus = { buildSpeedMult = 1.0, researchMult = 1.0 } },
            { level = 2, bonus = { buildSpeedMult = 1.1, researchMult = 1.1 } },
            { level = 3, bonus = { buildSpeedMult = 1.2, researchMult = 1.2 } },
            { level = 4, bonus = { buildSpeedMult = 1.35, researchMult = 1.3 } },
            { level = 5, bonus = { buildSpeedMult = 1.5, researchMult = 1.4 } },
            { level = 6, bonus = { buildSpeedMult = 1.65, researchMult = 1.5 } },
            { level = 7, bonus = { buildSpeedMult = 1.8, researchMult = 1.6 } },
            { level = 8, bonus = { buildSpeedMult = 2.0, researchMult = 1.8 } },  -- 粒子加速器
            { level = 9, bonus = { buildSpeedMult = 2.3, researchMult = 2.0 } },  -- 主曲速门
            { level = 10, bonus = { buildSpeedMult = 2.6, researchMult = 2.3 } }, -- 恒星要塞
        },
    },
    POWER_PLANT = {
        key = "POWER_PLANT", name = "能源站",
        cost = { minerals = 200, energy = 0 }, buildTime = 30,
        bonus = { energyOutputMult = 1.3 },
    },
    MINING_RIG = {
        key = "MINING_RIG", name = "采矿站",
        cost = { minerals = 300 }, buildTime = 40,
        bonus = { mineralOutputMult = 1.25 },
    },
    RESEARCH_LAB = {
        key = "RESEARCH_LAB", name = "科研中心",
        cost = { minerals = 250, crystal = 50 }, buildTime = 45,
        bonus = { researchSpeedMult = 1.2 },
    },
    SHIPYARD = {
        key = "SHIPYARD", name = "造船厂",
        cost = { minerals = 400, crystal = 80 }, buildTime = 60,
        bonus = { shipBuildSpeedMult = 1.2 },
    },
    DEFENSE_TOWER = {
        key = "DEFENSE_TOWER", name = "防御塔",
        cost = { minerals = 350, crystal = 40 }, buildTime = 50,
        bonus = { baseDefense = 50 },
    },
    WAREHOUSE = {
        key = "WAREHOUSE", name = "仓库",
        cost = { minerals = 150 }, buildTime = 25,
        bonus = { storageCapMult = 1.5 },
    },
}

BASE_MODULE_ORDER = { "POWER_PLANT", "MINING_RIG", "RESEARCH_LAB", "SHIPYARD", "DEFENSE_TOWER", "WAREHOUSE" }

BASE_MODULE_UNLOCK_LEVEL = {
    POWER_PLANT = 1,
    MINING_RIG = 1,
    RESEARCH_LAB = 2,
    SHIPYARD = 2,
    DEFENSE_TOWER = 3,
    WAREHOUSE = 2,
}

BASE_CORE_MAX_LEVEL = 10

-- 基地核心升级费用 (从当前 level 升级到 level+1)
BASE_CORE_UPGRADE_COSTS = {
    [1] = { minerals = 300, energy = 100, buildTime = 30 },
    [2] = { minerals = 500, energy = 200, crystal = 50, buildTime = 45 },
    [3] = { minerals = 800, energy = 350, crystal = 100, buildTime = 60 },
    [4] = { minerals = 1200, energy = 500, crystal = 150, buildTime = 80 },
    [5] = { minerals = 1800, energy = 800, crystal = 250, nuclear = 50, buildTime = 100 },
    [6] = { minerals = 2500, energy = 1200, crystal = 400, nuclear = 100, buildTime = 120 },
    [7] = { minerals = 3500, energy = 1800, crystal = 600, nuclear = 200, buildTime = 150 },
    [8] = { minerals = 5000, energy = 2500, crystal = 900, nuclear = 400, buildTime = 200 },
    [9] = { minerals = 7000, energy = 3500, crystal = 1300, nuclear = 700, buildTime = 250 },
}

-- 每个核心等级的基地模块槽位上限
function BaseModuleSlots(coreLevel)
    local lv = coreLevel or 1
    return math.min(3 + lv, 12)
end

-- ============================================================================
-- V3.0 扩展: 每日挑战 (供 ChallengeSystem 使用)
-- ============================================================================

DAILY_CHALLENGES = {
    {
        id = "CHALLENGE_LOW_RES",
        name = "资源匮乏", difficulty = "normal",
        description = "资源产出-50%，但胜利奖励+100%。考验你的资源管理能力。",
        mods = { resourceMult = 0.5, rewardMult = 2.0 },
        reward = { seasonPoints = 500, crystal = 100 },
    },
    {
        id = "CHALLENGE_BOSS_RUSH",
        name = "Boss突袭", difficulty = "hard",
        description = "每3波出现Boss，敌人强度+20%。击杀Boss获得丰厚奖励。",
        mods = { bossFrequency = 3, enemyDmgMult = 1.2 },
        reward = { seasonPoints = 800, nuclear = 50 },
    },
    {
        id = "CHALLENGE_SPEED_BATTLE",
        name = "闪电战", difficulty = "normal",
        description = "所有战斗必须在30秒内结束，否则失败。舰船速度+30%。",
        mods = { battleTimeLimit = 30, speedMult = 1.3 },
        reward = { seasonPoints = 600, credits = 500 },
    },
    {
        id = "CHALLENGE_NO_DEFENSE",
        name = "无盾作战", difficulty = "extreme",
        description = "所有护盾无效，只能依靠舰体结构硬抗。舰体生命+50%。",
        mods = { shieldDisabled = true, healthMult = 1.5 },
        reward = { seasonPoints = 1200, rainbowCrystal = 20 },
    },
    {
        id = "CHALLENGE_ECONOMY",
        name = "经济封锁", difficulty = "hard",
        description = "资源产出-30%，但所有交易价值+50%。",
        mods = { resourceMult = 0.7, tradeBonus = 1.5 },
        reward = { seasonPoints = 700, credits = 800 },
    },
    {
        id = "CHALLENGE_FORTRESS",
        name = "要塞防御", difficulty = "hard",
        description = "敌人波次数量翻倍，但你的防御+30%。",
        mods = { enemyWaveMult = 2.0, defenseBonus = 0.3 },
        reward = { seasonPoints = 900, crystal = 200 },
    },
}

-- ============================================================================
-- V3.0 扩展: 成就系统扩展 (隐藏成就 + 战斗专项)
-- ============================================================================

ACHIEVEMENT_DEFINITIONS = {
    -- 战斗专项成就
    {
        id = "NO_DAMAGE_MASTER",
        name = "无伤大师", category = "combat", hidden = false,
        desc = "连续 5 波战斗不损失任何舰船",
        condition = function(ps) return (ps.noDamageStreak or 0) >= 5 end,
        reward = { blueCrystal = 500, title = "无伤大师" },
    },
    {
        id = "COMBO_KING",
        name = "连击之王", category = "combat", hidden = false,
        desc = "单场战斗达成 30 次连续命中",
        condition = function(ps) return (ps.maxCombo or 0) >= 30 end,
        reward = { blueCrystal = 400, title = "连击之王" },
    },
    {
        id = "WAVE_MVP_5",
        name = "五连MVP", category = "combat", hidden = false,
        desc = "连续 5 波成为全队最高伤害输出",
        condition = function(ps) return (ps.mvpStreak or 0) >= 5 end,
        reward = { purpleCrystal = 100, title = "五连MVP" },
    },
    {
        id = "HUNDRED_ENEMY_KILL",
        name = "百人斩", category = "combat", hidden = false,
        desc = "单局游戏击杀 100 艘敌舰",
        condition = function(ps) return (ps.singleRunEnemies or 0) >= 100 end,
        reward = { purpleCrystal = 80 },
    },
    {
        id = "BOSS_HUNTER",
        name = "Boss猎手", category = "combat", hidden = false,
        desc = "累计击败 20 个 Boss",
        condition = function(ps) return (ps.totalBosses or 0) >= 20 end,
        reward = { purpleCrystal = 150, rainbowCrystal = 10 },
    },
    {
        id = "PERFECT_CLEAR",
        name = "完美通关", category = "combat", hidden = true,
        desc = "无伤完成一整章战役",
        condition = function(ps) return ps.perfectChapter == true end,
        reward = { rainbowCrystal = 30, title = "完美指挥官" },
    },
    {
        id = "UNDERDOG",
        name = "以弱胜强", category = "combat", hidden = true,
        desc = "舰队规模小于50%的情况下击败 Boss",
        condition = function(ps) return ps.underdogVictory == true end,
        reward = { purpleCrystal = 200 },
    },

    -- 探索类成就
    {
        id = "DEEP_SPACE_EXPLORER",
        name = "深空探索者", category = "exploration", hidden = true,
        desc = "探索距离基地超过 5000 单位的星域",
        condition = function(ps) return (ps.maxDistanceExplored or 0) >= 5000 end,
        reward = { crystal = 300, title = "深空探索者" },
    },
    {
        id = "COLONIZATION_EXPERT",
        name = "殖民专家", category = "exploration", hidden = true,
        desc = "成功殖民 10 颗行星",
        condition = function(ps) return (ps.planetsColonized or 0) >= 10 end,
        reward = { purpleCrystal = 120 },
    },

    -- 经济类成就
    {
        id = "ECONOMY_MOGUL",
        name = "经济大亨", category = "economy", hidden = true,
        desc = "单局累计获得超过 1,000,000 资源",
        condition = function(ps) return (ps.totalResourcesEarned or 0) >= 1000000 end,
        reward = { purpleCrystal = 200, credits = 2000, title = "经济大亨" },
    },
    {
        id = "MERCHANT_LORD",
        name = "贸易霸主", category = "economy", hidden = true,
        desc = "完成 50 次星际贸易",
        condition = function(ps) return (ps.totalTrades or 0) >= 50 end,
        reward = { credits = 5000 },
    },
    {
        id = "SHIP_COLLECTOR",
        name = "舰船收藏家", category = "fleet", hidden = true,
        desc = "同时拥有所有类型的舰船",
        condition = function(ps)
            if not ps.ownedShipTypes then return false end
            local count = 0
            for _, _ in pairs(ps.ownedShipTypes) do count = count + 1 end
            return count >= 10
        end,
        reward = { rainbowCrystal = 50, title = "舰船收藏家" },
    },

    -- 策略类成就
    {
        id = "PEACE_MAKER",
        name = "和平使者", category = "strategy", hidden = true,
        desc = "不建造任何战斗舰完成一个战役章节",
        condition = function(ps) return ps.peaceChapter == true end,
        reward = { title = "和平使者", credits = 3000 },
    },
    {
        id = "MASTER_ENGINEER",
        name = "工程大师", category = "strategy", hidden = true,
        desc = "同时建造超过 20 艘工程维修舰",
        condition = function(ps) return (ps.engineerCount or 0) >= 20 end,
        reward = { purpleCrystal = 150 },
    },
    {
        id = "SPEED_RUNNER",
        name = "速通达人", category = "strategy", hidden = true,
        desc = "1小时内完成第一章战役",
        condition = function(ps) return (ps.chapter1Time or math.huge) <= 3600 end,
        reward = { rainbowCrystal = 40, title = "速通达人" },
    },

    -- 社交类
    {
        id = "DIPLOMAT",
        name = "外交家", category = "social", hidden = true,
        desc = "加入公会并完成 10 个公会任务",
        condition = function(ps) return (ps.guildTasksCompleted or 0) >= 10 end,
        reward = { credits = 2000 },
    },
    {
        id = "LUCKY_DEVIATOR",
        name = "幸运儿", category = "social", hidden = true,
        desc = "连续 3 次事件都获得最优选择",
        condition = function(ps) return (ps.luckyStreak or 0) >= 3 end,
        reward = { rainbowCrystal = 15 },
    },

    -- 传说级成就
    {
        id = "GALACTIC_HERO",
        name = "银河英雄", category = "legendary", hidden = true,
        desc = "完成所有战役章节 + 解锁所有 Tier5 科技 + 击败终极 Boss",
        condition = function(ps)
            return ps.allChaptersComplete and ps.allTier5Researched and ps.finalBossDefeated
        end,
        reward = { rainbowCrystal = 200, title = "银河英雄", avatar = "GALACTIC_HERO" },
    },
}

-- ============================================================================
-- V3.0 扩展: 成就解锁链定义
-- ============================================================================

ACHIEVEMENT_CHAINS = {
    COMBAT_MASTER = {
        chainId = "COMBAT_MASTER", name = "战斗大师之路",
        achievements = { "FIRST_BLOOD", "BOSS_SLAYER", "LEGENDARY_HUNTER", "NO_DAMAGE_MASTER", "COMBO_KING" },
        chainReward = { rainbowCrystal = 100, title = "战斗大师" },
    },
    EXPLORATION_MASTER = {
        chainId = "EXPLORATION_MASTER", name = "探索大师之路",
        achievements = { "FIRST_SYSTEM", "FIVE_SYSTEMS", "TEN_SYSTEMS", "COLONIZATION_EXPERT", "DEEP_SPACE_EXPLORER" },
        chainReward = { rainbowCrystal = 100, title = "探索大师" },
    },
    TECHNOLOGY_MASTER = {
        chainId = "TECHNOLOGY_MASTER", name = "科技大师之路",
        achievements = { "FIRST_STEPS", "RESEARCH_MASTER", "NOVA_CANNON", "FORTRESS_PROTOCOL", "GALACTIC_ASCEND" },
        chainReward = { rainbowCrystal = 150, title = "科技大师" },
    },
    ECONOMY_MASTER = {
        chainId = "ECONOMY_MASTER", name = "经济大师之路",
        achievements = { "FIRST_BUILD", "FIFTY_SHIPS", "HUNDRED_FLEET", "MERCHANT_LORD", "ECONOMY_MOGUL" },
        chainReward = { rainbowCrystal = 120, title = "经济大师" },
    },
}

-- ============================================================================
-- V3.0 扩展: 资源类型定义 (统一资源常量)
-- ============================================================================

RESOURCE_TYPES = {
    MINERALS = { id = "MINERALS", name = "矿石", nameEn = "Minerals", icon = "⛏️", color = { 200, 150, 100 } },
    ENERGY = { id = "ENERGY", name = "能源", nameEn = "Energy", icon = "⚡", color = { 255, 220, 100 } },
    CRYSTAL = { id = "CRYSTAL", name = "晶石", nameEn = "Crystal", icon = "💎", color = { 100, 200, 255 } },
    NUCLEAR = { id = "NUCLEAR", name = "核能", nameEn = "Nuclear", icon = "☢️", color = { 100, 255, 150 } },
    CREDITS = { id = "CREDITS", name = "星币", nameEn = "Credits", icon = "💰", color = { 255, 200, 50 } },
    BLUE_CRYSTAL = { id = "BLUE_CRYSTAL", name = "蓝晶", nameEn = "Blue Crystal", icon = "🔷", color = { 80, 150, 255 } },
    PURPLE_CRYSTAL = { id = "PURPLE_CRYSTAL", name = "紫晶", nameEn = "Purple Crystal", icon = "🔶", color = { 180, 80, 255 } },
    RAINBOW_CRYSTAL = { id = "RAINBOW_CRYSTAL", name = "彩虹晶", nameEn = "Rainbow Crystal", icon = "🌈", color = { 255, 150, 255 } },
}

-- ============================================================================
-- V3.0 扩展: 游戏数值平衡常量
-- ============================================================================

GAME_BALANCE = {
    -- 战斗平衡
    baseEnemyHealth = 100,
    baseEnemyDamage = 10,
    enemyHealthGrowthPerWave = 1.08,   -- 每波敌人生命增长8%
    enemyDamageGrowthPerWave = 1.06,   -- 每波敌人伤害增长6%
    bossHealthMult = 5.0,              -- Boss 生命倍数
    bossDamageMult = 2.5,              -- Boss 伤害倍数

    -- 经济平衡
    startingResources = { minerals = 500, energy = 200, crystal = 50 },
    baseResourceGenPerSec = { minerals = 5, energy = 3, crystal = 0.5 },
    maxStorageBase = 5000,
    storagePerWarehouse = 3000,

    -- 奖励平衡
    waveRewardBase = { credits = 50 },
    waveRewardGrowth = 1.1,            -- 每波奖励增长10%
    bossRewardMult = 5.0,

    -- 难度调整系数 (会被 AIDifficultySystem 的值覆盖)
    difficultyMods = {
        EASY = { enemyHealth = 0.6, enemyDamage = 0.6, enemySpawn = 0.7, resourceMult = 1.3, rewardMult = 0.8 },
        NORMAL = { enemyHealth = 1.0, enemyDamage = 1.0, enemySpawn = 1.0, resourceMult = 1.0, rewardMult = 1.0 },
        HARD = { enemyHealth = 1.5, enemyDamage = 1.3, enemySpawn = 1.3, resourceMult = 0.9, rewardMult = 1.5 },
        NIGHTMARE = { enemyHealth = 2.0, enemyDamage = 1.8, enemySpawn = 1.6, resourceMult = 0.8, rewardMult = 2.0 },
    },
}

-- ============================================================================
-- V3.0 扩展: 战斗环境效果 (星图变体)
-- ============================================================================

BATTLE_ENVIRONMENTS = {
    ASTEROID_FIELD = {
        id = "ASTEROID_FIELD", name = "小行星带",
        effect = { speedMult = 0.7, coverBonus = 0.2, collisionDamage = 5 },
        desc = "移动速度-30%，但提供20%掩体防护，有碰撞伤害。",
    },
    NEBULA = {
        id = "NEBULA", name = "星云区",
        effect = { stealthBonus = 0.5, sensorPenalty = 0.3 },
        desc = "隐形效果+50%，但探测范围-30%。",
    },
    SOLAR_STORM = {
        id = "SOLAR_STORM", name = "太阳风暴",
        effect = { shieldPenalty = 0.4, energyRegenMult = 0.8 },
        desc = "护盾效率-40%，能源恢复-20%。",
    },
    GRAVITY_WELL = {
        id = "GRAVITY_WELL", name = "重力井",
        effect = { speedMult = 0.5, projectileSpeedMult = 0.7 },
        desc = "所有舰船和弹药速度减半。",
    },
    DEBRIS_FIELD = {
        id = "DEBRIS_FIELD", name = "残骸区",
        effect = { coverBonus = 0.4, scavengeChance = 0.2 },
        desc = "提供40%掩体，20%几率从残骸获取资源。",
    },
    ION_STORM = {
        id = "ION_STORM", name = "离子风暴",
        effect = { shieldRegenMult = 0.5, skillCooldownMult = 1.3 },
        desc = "护盾恢复-50%，技能冷却+30%。",
    },
    WARP_ZONE = {
        id = "WARP_ZONE", name = "曲速区",
        effect = { speedMult = 2.0, skillCooldownMult = 0.7 },
        desc = "移动速度翻倍，技能冷却-30%。",
    },
    CRYSTAL_FIELD = {
        id = "CRYSTAL_FIELD", name = "晶体区",
        effect = { shieldBonus = 0.3, crystalDropChance = 0.15 },
        desc = "护盾效率+30%，15%几率额外获得晶石。",
    },
}

-- 星图变体的环境权重
MAP_VARIANT_ENV_WEIGHTS = {
    STANDARD = { ASTEROID_FIELD = 1, NEBULA = 1, SOLAR_STORM = 1, GRAVITY_WELL = 1, DEBRIS_FIELD = 1, ION_STORM = 1, WARP_ZONE = 1, CRYSTAL_FIELD = 1 },
    RESOURCE_RICH = { ASTEROID_FIELD = 2, CRYSTAL_FIELD = 3, DEBRIS_FIELD = 2, WARP_ZONE = 1, NEBULA = 1 },
    BARREN = { SOLAR_STORM = 2, GRAVITY_WELL = 2, ION_STORM = 2, ASTEROID_FIELD = 1 },
    HIGH_THREAT = { GRAVITY_WELL = 2, ION_STORM = 2, SOLAR_STORM = 2, ASTEROID_FIELD = 1, NEBULA = 1 },
}
