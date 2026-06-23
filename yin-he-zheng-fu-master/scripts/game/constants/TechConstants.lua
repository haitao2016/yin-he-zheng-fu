--[[
Constants/TechConstants.lua
科技树、关卡难度、指挥官相关常量
]]

local M = {}

-- ============================================================================
-- 关卡难度
-- ============================================================================

M.STAGE_DIFFICULTY = {
    EASY      = { name = "简单", healthMult = 0.8, dmgMult = 0.8, rewardsMult = 0.8 },
    MEDIUM    = { name = "普通", healthMult = 1.0, dmgMult = 1.0, rewardsMult = 1.0 },
    HARD      = { name = "困难", healthMult = 1.3, dmgMult = 1.3, rewardsMult = 1.3 },
    EXTREME   = { name = "噩梦", healthMult = 1.8, dmgMult = 1.8, rewardsMult = 2.0 },
    NIGHTMARE = { name = "炼狱", healthMult = 2.5, dmgMult = 2.2, rewardsMult = 3.0 },
}

-- ============================================================================
-- 指挥官系统
-- ============================================================================

M.COMMANDER_MAX_LEVEL = 10
M.COMMANDER_MAX_SLOTS = 4
M.COMMANDER_RETIRE_REWARD = 3
M.COMMANDER_EXP_TABLE = { 100, 220, 360, 520, 700, 900, 1120, 1360, 1620, 2000 }
M.COMMANDER_SPECS = {
    TACTICS     = { name = "战术",   desc = "提升战斗效率",     bonus = { attackMult = 1.1, critRate = 0.05 } },
    LOGISTICS   = { name = "后勤",   desc = "提升资源采集",     bonus = { resourceMult = 1.15, buildSpeedMult = 1.1 } },
    ENGINEERING = { name = "工程",   desc = "提升研发与建造",   bonus = { researchSpeedMult = 1.2, shipHealthMult = 1.1 } },
}
M.COMMANDER_NAMES = { "陈上将", "约翰·克拉克", "娜塔莎·罗曼诺夫", "张翼德", "李·阿达玛", "卡特·史巴克" }
M.COMMANDER_SOURCE = { RECRUIT = "RECRUIT", MARKET = "MARKET", MISSION = "MISSION" }
M.COMMANDER_MARKET_COST = 2000

-- ============================================================================
-- 科技树 (Tier1-5)
-- ============================================================================

M.TECHS = {
    -- ── Tier 1 基础科技 ─────────────────────────────────────
    DEEP_MINING = { id = "DEEP_MINING", name = "深层采矿", tier = 1, cost = { minerals = 200 }, time = 60, prereqs = {}, bonus = { mineralOutputMult = 1.2 }, desc = "矿井产量+20%。利用深层钻探技术开采行星地核资源。" },
    SOLAR_EFFICIENCY = { id = "SOLAR_EFFICIENCY", name = "高效光伏", tier = 1, cost = { minerals = 150, energy = 100 }, time = 45, prereqs = {}, bonus = { energyOutputMult = 1.15 }, desc = "电站产量+15%。改进光伏转化效率，从恒星辐射中获取更多能源。" },
    CRYSTAL_PROCESS = { id = "CRYSTAL_PROCESS", name = "晶石精炼", tier = 1, cost = { minerals = 300, crystal = 30 }, time = 70, prereqs = {}, bonus = { crystalOutputMult = 1.2 }, desc = "晶石加工效率+20%。精密提纯工艺获得更高品质晶体。" },
    HULL_ALLOY = { id = "HULL_ALLOY", name = "合金船壳", tier = 1, cost = { minerals = 400 }, time = 80, prereqs = {}, bonus = { shipHealthMult = 1.25 }, desc = "所有舰船耐久+25%。" },

    -- ── Tier 2 中级科技 ─────────────────────────────────────
    SHIELD_REINFORCE = { id = "SHIELD_REINFORCE", name = "护盾强化", tier = 2, cost = { minerals = 350, crystal = 20, energy = 150 }, time = 100, prereqs = { "HULL_ALLOY" }, bonus = { shieldFlat = 150, defenseMult = 1.15 }, desc = "护盾值+150，防御+15%。" },
    RAPID_REFINE = { id = "RAPID_REFINE", name = "快速精炼", tier = 2, cost = { minerals = 600, energy = 200 }, time = 120, prereqs = { "DEEP_MINING" }, bonus = { buildSpeedMult = 1.15 }, desc = "舰船建造速度+15%。" },
    COLONY_BIOTECH = { id = "COLONY_BIOTECH", name = "殖民生物技术", tier = 2, cost = { minerals = 500, crystal = 50 }, time = 110, prereqs = { "CRYSTAL_PROCESS" }, bonus = { colonySpeedMult = 1.3, resourceCapMult = 1.2 }, desc = "殖民速度+30%，资源上限+20%。" },
    NANO_REPAIR = { id = "NANO_REPAIR", name = "纳米维修", tier = 2, cost = { minerals = 550, crystal = 40, energy = 180 }, time = 115, prereqs = { "SHIELD_REINFORCE" }, bonus = { battleRegenPct = 0.02 }, desc = "战斗中每秒恢复2%舰队生命值。" },

    -- ── Tier 3 高级科技 ─────────────────────────────────────
    WARP_DRIVE = { id = "WARP_DRIVE", name = "曲速引擎", tier = 3, cost = { minerals = 700, crystal = 80, energy = 300 }, time = 150, prereqs = { "RAPID_REFINE", "HULL_ALLOY" }, bonus = { fleetSpeedMult = 1.5 }, desc = "舰队移动速度+50%。" },
    ADVANCED_WEAPONS = { id = "ADVANCED_WEAPONS", name = "高级武器系统", tier = 3, cost = { minerals = 800, crystal = 100, energy = 200 }, time = 160, prereqs = { "HULL_ALLOY", "CRYSTAL_PROCESS" }, bonus = { attackMult = 1.3 }, desc = "所有战舰攻击力+30%。" },
    DEFENSE_MATRIX = { id = "DEFENSE_MATRIX", name = "防御矩阵", tier = 3, cost = { minerals = 900, crystal = 90, energy = 280 }, time = 155, prereqs = { "SHIELD_REINFORCE", "NANO_REPAIR" }, bonus = { shipHealthMult = 1.25, shieldMult = 1.3 }, desc = "舰队生命+25%，护盾上限+30%。" },
    VOID_ANCHOR = { id = "VOID_ANCHOR", name = "虚空锚定", tier = 3, cost = { minerals = 1500, crystal = 200, energy = 500 }, time = 240, prereqs = { "WARP_DRIVE", "DEFENSE_MATRIX" }, bonus = { enemySpeedDebuff = 0.7 }, desc = "敌方舰队移动速度-30%。" },

    -- ── Tier 4 顶级科技 · 双路线 ─────────────────────────────
    -- ⚔ 攻击路线: NOVA_CANNON(强火力) → VOID_FLEET(压制)
    -- 🛡 防御路线: FORTRESS_PROTOCOL(强化护盾) → FORTRESS_PROTOCOL_II(反击)
    -- ⚙ 通用路线: QUANTUM_CORE → STELLAR_SYNC / PHASE_DRIVE
    QUANTUM_CORE = { id = "QUANTUM_CORE", name = "量子核心", tier = 4, cost = { minerals = 2200, crystal = 350, energy = 700 }, time = 320, prereqs = { "ADVANCED_WEAPONS", "DEFENSE_MATRIX" }, bonus = { researchSpeedMult = 1.5, upgradeCostMult = 0.8 }, desc = "科研速度+50%，核心升级费用-20%。" },
    NOVA_CANNON = { id = "NOVA_CANNON", name = "新星炮", tier = 4, cost = { minerals = 2800, crystal = 400, energy = 900, nuclear = 80 }, time = 360, prereqs = { "ADVANCED_WEAPONS", "VOID_ANCHOR" }, bonus = { aoeRadiusMult = 1.8, attackMult = 1.5, battleStartSkillCharge = 1 }, desc = "AOE半径+80%，全体伤害+50%，每波战斗开始额外技能充能+1。" },
    FORTRESS_PROTOCOL = { id = "FORTRESS_PROTOCOL", name = "要塞协议", tier = 4, cost = { minerals = 2600, crystal = 320, energy = 1000 }, time = 340, prereqs = { "DEFENSE_MATRIX", "NANO_REPAIR" }, bonus = { shieldMaxMult = 2.0, shieldRegenPct = 0.015 }, desc = "基地护盾最大值翻倍，每秒恢复1.5%基地护盾。" },
    STELLAR_SYNC = { id = "STELLAR_SYNC", name = "星际同步", tier = 4, cost = { minerals = 3000, crystal = 500, energy = 1000 }, time = 400, prereqs = { "QUANTUM_CORE", "SOLAR_EFFICIENCY" }, bonus = { globalProdMult = 1.25, researchSpeedMult = 1.3 }, desc = "全局产出+25%，科研+30%。" },
    PHASE_DRIVE = { id = "PHASE_DRIVE", name = "相位驱动", tier = 4, cost = { minerals = 3200, crystal = 520, energy = 1100, nuclear = 180 }, time = 410, prereqs = { "QUANTUM_CORE", "WARP_DRIVE" }, bonus = { fleetSpeedMult = 2.0, stealthEnabled = true }, desc = "舰队速度再+50%，获得隐形能力。" },

    -- ── Tier 5 终极科技 ─────────────────────────────────────
    STELLAR_ENGINE = { id = "STELLAR_ENGINE", name = "恒星引擎", tier = 5, cost = { minerals = 4500, crystal = 700, energy = 1800, nuclear = 320 }, time = 520, prereqs = { "PHASE_DRIVE", "NOVA_CANNON" }, bonus = { fleetSpeedMult = 1.6, battleStartSpeedBoost = 1.0 }, desc = "全局移动速度+60%，战斗开局获得初始加速。" },
    QUANTUM_FACTORY = { id = "QUANTUM_FACTORY", name = "量子工厂", tier = 5, cost = { minerals = 4800, crystal = 750, energy = 1600 }, time = 540, prereqs = { "QUANTUM_CORE", "STELLAR_SYNC" }, bonus = { shipyardSpeedMult = 2.0, upgradeCostMult = 0.75 }, desc = "舰船建造速度翻倍，升级费用-25%。" },
    VOID_FLEET = { id = "VOID_FLEET", name = "虚空舰队", tier = 5, cost = { minerals = 5000, crystal = 800, energy = 2000, nuclear = 400 }, time = 560, prereqs = { "NOVA_CANNON", "STELLAR_ENGINE" }, bonus = { enemySpawnMult = 0.7, enemyDamageMult = 0.8 }, desc = "敌方舰队生成-30%，敌舰伤害-20%。" },
    FORTRESS_PROTOCOL_II = { id = "FORTRESS_PROTOCOL_II", name = "要塞协议II", tier = 5, cost = { minerals = 5200, crystal = 820, energy = 2100, nuclear = 380 }, time = 580, prereqs = { "FORTRESS_PROTOCOL", "STELLAR_SYNC" }, bonus = { shieldMaxMult = 3.0, shieldRegenPct = 0.025, counterShield = true }, desc = "基地护盾最大值3倍，每秒恢复2.5%，受攻击时触发反击护盾。" },
    CHRONO_RESEARCH = { id = "CHRONO_RESEARCH", name = "时序研究", tier = 5, cost = { minerals = 6000, crystal = 1000, energy = 2500, nuclear = 500 }, time = 600, prereqs = { "STELLAR_SYNC", "QUANTUM_FACTORY" }, bonus = { researchSpeedMult = 2.5, eventFrequencyMult = 0.5 }, desc = "科研速度2.5倍，事件频率减半。" },
    GALACTIC_ASCEND = { id = "GALACTIC_ASCEND", name = "银河飞升", tier = 5, cost = { minerals = 8000, crystal = 1500, energy = 3000, nuclear = 800 }, time = 720, prereqs = { "STELLAR_ENGINE", "VOID_FLEET", "FORTRESS_PROTOCOL_II", "CHRONO_RESEARCH" }, bonus = { attackMult = 2.0, fleetCapBonus = 3, skillPointsBonus = 2, rewardMult = 2.0 }, desc = "全局伤害2倍，舰队上限+3，每波技能点+2，所有奖励翻倍。" },
}

return M
