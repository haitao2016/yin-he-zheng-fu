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
