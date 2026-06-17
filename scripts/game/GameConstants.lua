---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/GameConstants.lua  -- 全局游戏常量（从 Systems.lua 拆分）
-- ============================================================================

-- ============================================================================
-- 全局常量
-- ============================================================================
BUILDINGS = {
    MINE             = { name="自动化矿井",    cost={metal=100,esource=50},                      prod={minerals=10}, buildTime=5,  upgradeK=1.5 },
    POWER_PLANT      = { name="太阳能阵列",    cost={metal=80},                                   prod={energy=15},   buildTime=3,  upgradeK=1.4 },
    SHIELD_GEN       = { name="护盾发生器",    cost={metal=300,esource=400,nuclear=100},         prod={},             buildTime=12, upgradeK=1.8,
                         specDefense=true, shieldBonus=200 },
    TRADE_HUB        = { name="星际交易所",    cost={metal=500,esource=300,nuclear=80},          prod={credits=5},   buildTime=15, upgradeK=1.6 },
    DEFENSE_TURRET   = { name="轨道炮塔",      cost={metal=400, esource=200},                    prod={},            buildTime=10, upgradeK=1.5,
                         combatEffect=true, turretDmg=25, turretRange=300, turretRate=1.5 },
    ADVANCED_REFINERY = { name="高级精炼厂",   cost={metal=600, esource=400, nuclear=150},       prod={minerals=5, energy=3, crystal=1},
                         refineBonus=2.0, rareChance=0.05, buildTime=12, upgradeK=1.6 },
    RESEARCH_STATION = { name="科研站",        cost={metal=500, esource=300, nuclear=200},       prod={},            buildTime=14, upgradeK=1.6,
                         researchBonus=0.20, researchMult=1.15 },
    STARGATE_NODE    = { name="星门节点",      cost={metal=800, esource=500, nuclear=200, crystal=50}, prod={},    buildTime=20, upgradeK=1.8,
                         teleportEnabled=true, teleportCooldown=60 },
}
BUILD_ORDER = {"MINE","POWER_PLANT","SHIELD_GEN","TRADE_HUB","DEFENSE_TURRET","ADVANCED_REFINERY","RESEARCH_STATION","STARGATE_NODE"}

-- P2-3: 建筑专精定义（每类行星建筑 3 种专精，Lv.3+ 解锁）
BUILDING_SPECS = {
    MINE = {
        { key="DEEP_DRILL",   name="深层钻探", desc="+15%矿石产量",  effect={mineralsMult=1.15} },
        { key="AUTO_SORT",    name="自动分拣", desc="+8矿石/s",      effect={mineralsFlat=8} },
        { key="VEIN_SCAN",    name="矿脉扫描", desc="+25%晶石",      effect={crystalMult=1.25} },
    },
    POWER_PLANT = {
        { key="THERMO_CYCLE", name="热核循环", desc="+20%能源",       effect={energyMult=1.20} },
        { key="SOLAR_BOOST",  name="太阳增幅", desc="+12能源/s",      effect={energyFlat=12} },
        { key="DARK_MATTER",  name="暗物质炉", desc="+10%能源晶石",   effect={energyMult=1.10, crystalMult=1.05} },
    },
    SHIELD_GEN = {
        { key="SUPERCONDUCT", name="超导护盾", desc="+300基地护盾",   effect={shieldBonus=300} },
        { key="REGEN_FIELD",  name="再生力场", desc="护盾恢复×1.5",  effect={shieldRegenMult=1.5} },
        { key="PHASE_WALL",   name="相位屏障", desc="防御力+15%",    effect={defenseBonus=0.15} },
    },
    TRADE_HUB = {
        { key="WARP_CHANNEL", name="星际通道", desc="+30%星币",       effect={creditsMult=1.30} },
        { key="BLACK_MARKET", name="黑市网络", desc="+20星币/s",      effect={creditsFlat=20} },
        { key="TECH_BROKER",  name="技术中介", desc="科研速度+20%",  effect={researchSpeedBonus=0.20} },
    },
}
SPEC_COST = 50   -- P2-3: 激活专精消耗晶石数量

-- ============================================================================
-- 星航基地模块（与行星建筑完全独立）
-- ============================================================================
BASE_MODULES = {
    COMMAND_CENTER  = { name="指挥中枢",   cost={metal=200,  esource=100},              desc="提升舰队上限+1",       buildTime=8,  upgradeK=1.8 },
    ENERGY_CORE     = { name="能量核心",   cost={metal=150,  esource=50},               desc="精炼所有原矿（矿石/能量块/水晶），精炼倍率+0.5×/级", buildTime=5,  upgradeK=1.5 },
    MINERAL_SILO    = { name="资源仓储",   cost={metal=100},                            desc="原矿存储上限×2/级（矿石/能量块/水晶）", buildTime=4,  upgradeK=1.4 },
    MATERIAL_DEPOT  = { name="材料仓库",   cost={metal=120, esource=60},               desc="精炼资源上限×2/级（金属/能源/核能）", buildTime=5,  upgradeK=1.4 },
    DEFENSE_CANNON  = { name="防御炮台",   cost={metal=300,  esource=200},              desc="基地防御力+50/级（累计）",           buildTime=10, upgradeK=1.6 },
    HANGAR          = { name="飞船机库",   cost={metal=400,  esource=150, nuclear=50},  desc="解锁更大舰船建造",                   buildTime=12, upgradeK=2.0 },
    WARP_GATE       = { name="曲速闸门",   cost={metal=800,  esource=500, nuclear=200}, desc="开启星系间跳跃",                     buildTime=20, upgradeK=2.5 },
    SOLAR_ARRAY     = { name="太阳能阵列",   cost={metal=80},                             desc="直接产出能源+3/s/级（无需精炼）",  buildTime=5,  upgradeK=1.4 },
    RESEARCH_CENTER = { name="科研中心",   cost={metal=150,  nuclear=50},               desc="科研速度×1.2/级（累乘）",            buildTime=8,  upgradeK=1.6 },
    SHIPYARD        = { name="星际造船厂", cost={metal=500,  esource=200},              desc="舰船建造速度×1.5/级（累乘）",        buildTime=15, upgradeK=2.0 },
    BASE_SHIELD     = { name="护盾发生器", cost={metal=300,  esource=400, nuclear=100}, desc="基地护盾值+200/级（累计）",          buildTime=12, upgradeK=1.8 },
    BUILD_CENTER    = { name="行星探索中心", cost={metal=250,  esource=150, nuclear=80},  desc="所有建造时间×0.75/级（最低25%）",  buildTime=10, upgradeK=1.7 },
    EXCHANGE_CENTER      = { name="资源互换中心",  cost={metal=300, esource=200, nuclear=100},                       desc="按比例互换金属/能源/核能",                                        buildTime=10, upgradeK=1.5 },
    REFINERY             = { name="资源精炼厂",    cost={metal=250, esource=150},                                    desc="原矿精炼为可用资源，每升一级转化速率×1.5（Lv1=1× Lv2=1.5× Lv3=2×…）", buildTime=8,  upgradeK=1.6 },
    -- P1-2: Lv8-10 专属模块
    PARTICLE_ACCELERATOR = { name="粒子加速器",    cost={metal=3000, nuclear=1200, esource=2000},                    desc="全局科研速度×2.5，精炼速率+50%",                                  buildTime=40, upgradeK=2.0 },
    WARP_GATE_PRIME      = { name="主曲速门",      cost={metal=5000, nuclear=2500, esource=3000},                    desc="舰队可瞬移至任意星球（冷却120s）",                                buildTime=55, upgradeK=2.5 },
    STELLAR_FORTRESS     = { name="恒星要塞",      cost={metal=8000, nuclear=4000, esource=5000},                    desc="基地防御力×2（翻倍），敌方来袭损失额外20%舰队",                   buildTime=70, upgradeK=3.0 },
}
BASE_MODULE_ORDER = {"ENERGY_CORE","COMMAND_CENTER","MINERAL_SILO","MATERIAL_DEPOT","REFINERY","DEFENSE_CANNON","HANGAR","WARP_GATE",
                     "SOLAR_ARRAY","RESEARCH_CENTER","SHIPYARD","BASE_SHIELD","BUILD_CENTER","EXCHANGE_CENTER",
                     "PARTICLE_ACCELERATOR","WARP_GATE_PRIME","STELLAR_FORTRESS"}

-- ============================================================================
-- 基地核心等级系统
-- ============================================================================
BASE_MODULE_UNLOCK_LEVEL = {
    COMMAND_CENTER  = 2,
    SOLAR_ARRAY     = 1,
    ENERGY_CORE     = 1,
    MINERAL_SILO    = 2,
    MATERIAL_DEPOT  = 2,
    RESEARCH_CENTER = 3,
    DEFENSE_CANNON  = 3,
    HANGAR          = 4,
    BUILD_CENTER    = 4,
    REFINERY        = 2,
    EXCHANGE_CENTER = 5,
    SHIPYARD        = 3,
    BASE_SHIELD          = 6,
    WARP_GATE            = 7,
    PARTICLE_ACCELERATOR = 8,
    WARP_GATE_PRIME      = 9,
    STELLAR_FORTRESS     = 10,
}

BASE_CORE_MAX_LEVEL = 10

--- 根据核心等级计算模块槽位上限（Lv1=8，每级+1，最高15）
function BaseModuleSlots(coreLevel)
    return math.min(15, 7 + (coreLevel or 1))
end

BASE_CORE_UPGRADE_COSTS = {
    [1] = { metal=300,   esource=150,               buildTime=10  },
    [2] = { metal=600,   esource=300,  nuclear=50,   buildTime=18  },
    [3] = { metal=1000,  esource=500,  nuclear=150,  buildTime=28  },
    [4] = { metal=1500,  esource=800,  nuclear=300,  buildTime=40  },
    [5] = { metal=2500,  esource=1200, nuclear=500,  buildTime=55  },
    [6] = { metal=4000,  esource=2000, nuclear=1000, buildTime=75  },
    [7] = { metal=6500,  esource=3500, nuclear=1800, buildTime=100 },
    [8] = { metal=10000, esource=5500, nuclear=3000, buildTime=130 },
    [9] = { metal=15000, esource=8000, nuclear=5000, buildTime=165 },
}

BASE_CORE_UNLOCK_PREVIEW = {
    [1]  = {"ENERGY_CORE","SOLAR_ARRAY"},
    [2]  = {"COMMAND_CENTER","MINERAL_SILO","MATERIAL_DEPOT","REFINERY"},
    [3]  = {"RESEARCH_CENTER","DEFENSE_CANNON","SHIPYARD"},
    [4]  = {"HANGAR","BUILD_CENTER"},
    [5]  = {"EXCHANGE_CENTER"},
    [6]  = {"BASE_SHIELD"},
    [7]  = {"WARP_GATE"},
    [8]  = {"PARTICLE_ACCELERATOR"},
    [9]  = {"WARP_GATE_PRIME"},
    [10] = {"STELLAR_FORTRESS"},
}

EXCHANGE_RATES = {
    metal   = { esource=1.5,  nuclear=0.3  },
    esource = { metal=0.6,    nuclear=0.2  },
    nuclear = { metal=3.0,    esource=4.5  },
}
EXCHANGE_AMOUNT = 100

TECHS = {
    -- Tier 1
    DEEP_MINING      = { name="深层采矿",   desc="矿井产量+20%",              cost={nuclear=50,  esource=100},          time=20, prereqs={},                                      bonus={building="MINE", prodMult=1.2} },
    SOLAR_EFFICIENCY = { name="高效光伏",   desc="电站产量+15%",              cost={nuclear=80,  metal=200},             time=30, prereqs={},                                      bonus={building="POWER_PLANT", prodMult=1.15} },
    CRYSTAL_PROCESS  = { name="水晶提纯",   desc="水晶→核能精炼效率+30%",     cost={esource=80,  metal=150},             time=25, prereqs={},                                      bonus={refineMult="crystal", val=1.3} },
    HULL_ALLOY       = { name="合金船壳",   desc="所有舰船最大耐久+25%",      cost={metal=200,   nuclear=60},            time=30, prereqs={},                                      bonus={shipHealthMult=1.25} },
    -- Tier 2
    SHIELD_REINFORCE = { name="护盾强化",   desc="基地护盾+300，防御+20%",    cost={nuclear=150, metal=400},             time=45, prereqs={"SOLAR_EFFICIENCY"},                    bonus={shieldBonus=300, defenseBonus=0.2} },
    RAPID_REFINE     = { name="快速精炼",   desc="精炼速率×1.5（原矿→精炼）", cost={nuclear=120, esource=200},           time=40, prereqs={"DEEP_MINING"},                         bonus={globalRefineMult=1.5} },
    COLONY_BIOTECH   = { name="殖民生物技术", desc="殖民星球人口增长速率+40%", cost={esource=150, nuclear=80},            time=35, prereqs={"CRYSTAL_PROCESS"},                     bonus={colonyPopMult=1.4} },
    NANO_REPAIR      = { name="纳米修复",   desc="所有战舰最大耐久+20%",      cost={metal=200,   esource=100},           time=30, prereqs={"HULL_ALLOY"},                          bonus={shipHealthMult=1.20} },
    -- Tier 3
    WARP_DRIVE       = { name="曲速引擎",   desc="舰队移动速度+50%",          cost={nuclear=300, esource=500},           time=60, prereqs={"SHIELD_REINFORCE","RAPID_REFINE"},     bonus={fleetSpeedMult=1.5},  exclusiveGroup="TIER3" },
    ADVANCED_WEAPONS = { name="高级武器系统", desc="所有战舰攻击力+30%",      cost={metal=500,   nuclear=200},           time=55, prereqs={"HULL_ALLOY","RAPID_REFINE"},           bonus={shipDmgMult=1.3},     exclusiveGroup="TIER3" },
    DEFENSE_MATRIX   = { name="防御矩阵",   desc="基地护盾+400，防御+30%",    cost={nuclear=200, metal=500},             time=50, prereqs={"SHIELD_REINFORCE","NANO_REPAIR"},      bonus={shieldBonus=400, defenseBonus=0.3}, exclusiveGroup="TIER3" },
    VOID_ANCHOR      = { name="虚空锚定",   desc="战舰攻击力+20%，敌方舰队减速20%",
                         cost={nuclear=280, esource=400, metal=200}, time=60,
                         prereqs={"SHIELD_REINFORCE","RAPID_REFINE"},
                         bonus={shipDmgMult=1.2, enemySpeedDebuff=0.8}, exclusiveGroup="TIER3" },
    -- Tier 4
    QUANTUM_CORE     = { name="量子核心",   desc="基地核心升级费用-20%，科研速度+50%", cost={nuclear=600, esource=800, metal=1000}, time=90, prereqs={"WARP_DRIVE","ADVANCED_WEAPONS"}, bonus={coreUpgradeCostMult=0.8, researchSpeedMult=1.5}, exclusiveGroup="TIER4_UTIL" },
    PHASE_DRIVE      = { name="相位驱动",   desc="精炼速率×1.4，舰队速度+40%",         cost={nuclear=500, esource=600, metal=800},  time=80, prereqs={"WARP_DRIVE","NANO_REPAIR"},          bonus={globalRefineMult=1.4, fleetSpeedMult=1.4} },
    NOVA_CANNON      = { name="新星炮",     desc="战舰AOE半径+80%，每波战斗开始获得1次星陨打击技能",
                         cost={nuclear=500, metal=800, esource=400}, time=85,
                         prereqs={"ADVANCED_WEAPONS"},
                         bonus={aoeRadiusMult=1.8, battleStartSkillCharge=1} },
    FORTRESS_PROTOCOL= { name="要塞协议",   desc="基地最大护盾×2.2，战斗中每10s护盾自动恢复5%",
                         cost={nuclear=400, metal=600, esource=600}, time=80,
                         prereqs={"DEFENSE_MATRIX"},
                         bonus={shieldMaxMult=2.2, shieldRegenPct=0.05} },
    STELLAR_SYNC     = { name="星际同步",   desc="全局资源产出+25%，科研速度+30%",
                         cost={nuclear=500, esource=700, metal=800}, time=85,
                         prereqs={"VOID_ANCHOR","DEFENSE_MATRIX"},
                         bonus={globalProdMult=1.25, researchSpeedMult=1.3}, exclusiveGroup="TIER4_UTIL" },
    -- Tier 5（P2-6: V2.6 高阶科技，需基地核心 Lv8 解锁）
    STELLAR_ENGINE   = { name="恒星引擎",     desc="舰队移动速度+60%",
                         cost={metal=3000, esource=2000, nuclear=500}, time=120, prereqs={"WARP_DRIVE"},
                         bonus={fleetSpeedMult=1.6}, coreLevelReq=8 },
    QUANTUM_FACTORY  = { name="量子工厂",     desc="舰船建造速度+50%，升级费用-25%",
                         cost={metal=3500, esource=1500, nuclear=800}, time=130, prereqs={"QUANTUM_CORE"},
                         bonus={shipyardSpeedMult=1.5, upgradeCostMult=0.75}, coreLevelReq=8 },
    VOID_FLEET       = { name="虚空舰队",     desc="所有舰船攻击力+25%，生命值+20%",
                         cost={metal=4000, esource=2500, nuclear=1000}, time=150, prereqs={"ADVANCED_WEAPONS","NOVA_CANNON"},
                         bonus={shipDmgMult=1.25, shipHealthMult=1.20}, coreLevelReq=8 },
    FORTRESS_PROTOCOL_II = { name="要塞协议II", desc="基地护盾+500，防御力+40%，战斗中护盾每秒回复8%",
                         cost={metal=3000, esource=2000, nuclear=1200}, time=140, prereqs={"FORTRESS_PROTOCOL"},
                         bonus={shieldBonus=500, defenseBonus=0.40, shieldRegenPct=0.08}, coreLevelReq=8 },
    CHRONO_RESEARCH  = { name="时空研究",     desc="科研速度×2.0，全局资源产出+15%",
                         cost={metal=2500, esource=1500, nuclear=800}, time=120, prereqs={"STELLAR_SYNC"},
                         bonus={researchSpeedMult=2.0, globalProdMult=1.15}, coreLevelReq=8 },
    GALACTIC_ASCEND  = { name="文明飞跃",     desc="全局伤害+30%，舰队上限+3，每波技能点+1",
                         cost={metal=5000, esource=3000, nuclear=1500, crystal=500}, time=180,
                         prereqs={"STELLAR_ENGINE","QUANTUM_FACTORY","VOID_FLEET","FORTRESS_PROTOCOL_II","CHRONO_RESEARCH"},
                         bonus={globalDmgMult=1.3, fleetCapBonus=3, skillPointBonus=1}, coreLevelReq=10, isFinal=true },
}
TECH_ORDER = {
    "DEEP_MINING","SOLAR_EFFICIENCY","CRYSTAL_PROCESS","HULL_ALLOY",
    "SHIELD_REINFORCE","RAPID_REFINE","COLONY_BIOTECH","NANO_REPAIR",
    "WARP_DRIVE","ADVANCED_WEAPONS","DEFENSE_MATRIX","VOID_ANCHOR",
    "QUANTUM_CORE","PHASE_DRIVE","NOVA_CANNON","FORTRESS_PROTOCOL","STELLAR_SYNC",
    "STELLAR_ENGINE","QUANTUM_FACTORY","VOID_FLEET","FORTRESS_PROTOCOL_II","CHRONO_RESEARCH","GALACTIC_ASCEND",
}

-- P2-5: 星球建筑槽位扩展（基础 4 槽，随基地核心等级扩展）
PLANET_BUILDING_SLOTS = {
    base          = 4,   -- 每个星球默认建筑槽位
    coreLv3Bonus  = 1,   -- 基地核心 Lv3 解锁 +1 槽
    coreLv5Bonus  = 1,   -- 基地核心 Lv5 解锁 +1 槽
}
--- 根据核心等级计算星球可拥有的最大建筑槽位
function PlanetBuildingSlots(coreLevel)
    local lv = coreLevel or 1
    local total = PLANET_BUILDING_SLOTS.base
    if lv >= 3 then total = total + PLANET_BUILDING_SLOTS.coreLv3Bonus end
    if lv >= 5 then total = total + PLANET_BUILDING_SLOTS.coreLv5Bonus end
    return total
end

RANKS = {"见习指挥官","资深舰长","舰队少将","星系统治者","银河霸主"}
EXP_PER_LEVEL = 1000

-- V2.6 C3: 稀有资源（独立于 RES_ORDER，由专门的 TopBar 面板展示）
RARE_RES_ORDER  = {"titanium", "darkMatter", "starCore", "blueCrystal", "purpleCrystal", "rainbowCrystal"}
RARE_RES_LABELS = { titanium="钛合金", darkMatter="暗物质", starCore="星核碎片",
                     blueCrystal="蓝晶石", purpleCrystal="紫晶石", rainbowCrystal="彩虹晶" }
RARE_RES_TAGS   = { titanium="钛",   darkMatter="暗",   starCore="核",
                     blueCrystal="蓝", purpleCrystal="紫", rainbowCrystal="虹" }
RARE_RES_COLORS = { titanium={180,180,200}, darkMatter={100,0,150}, starCore={255,200,50},
                     blueCrystal={60,140,255}, purpleCrystal={180,60,255}, rainbowCrystal={200,150,255} }
RARE_RES_CAPS   = { titanium=500, darkMatter=500, starCore=500,
                     blueCrystal=500, purpleCrystal=500, rainbowCrystal=500 }

-- V2.6 C3: 稀有资源自动转化比例（超出上限时，每1单位→50单位普通资源）
RES_OVERFLOW_CONVERSION = {
    titanium       = { to="metal",   ratio=50 },
    darkMatter     = { to="nuclear", ratio=50 },
    starCore       = { to="nuclear", ratio=50 },
    blueCrystal    = { to="crystal", ratio=50 },
    purpleCrystal  = { to="crystal", ratio=50 },
    rainbowCrystal = { to="crystal", ratio=50 },
}

-- 基础资源保持原状（TopBar.lua 依赖此顺序和内容）
RES_ORDER  = {"metal", "esource", "nuclear"}
RES_LABELS = { metal="金属", esource="能源", nuclear="核能" }
RES_TAGS   = { metal="矿石", esource="能量块", nuclear="水晶" }
RES_REFINED_LABELS = { metal="金属(精)", esource="能源(精)", nuclear="核能(精)" }
RES_COLORS = { metal={180,180,180}, esource={255,255,0}, nuclear={0,255,255} }

SHIP_TYPES = {
    SCOUT         = { name="侦察舰", speed=180, health=50,   maxHealth=50,   range=100,  dmg=6,  color={100,200,255}, buildTime=14 },
    FRIGATE       = { name="护卫舰", speed=100, health=150,  maxHealth=150,  range=200,  dmg=10, color={80,160,255},  buildTime=25 },
    DESTROYER     = { name="驱逐舰", speed=60,  health=400,  maxHealth=400,  range=300,  dmg=18, color={40,100,220},  buildTime=55 },
    BATTLECRUISER = { name="战列舰", speed=35,  health=1200, maxHealth=1200, range=380,  dmg=45, color={160,80,255},  buildTime=120,
                      aoeRadius=60, shotRate=0.5 },
    ENGINEER     = { name="工程舰", speed=40,  health=80,  maxHealth=80,  range=0,    dmg=0,  color={255,200,80},  buildTime=18,
                     mineRate={minerals=8, energy=4} },
    EXPLORER     = { name="探索舰", speed=120, health=100, maxHealth=100, range=0,    dmg=0,  color={120,255,160}, buildTime=22,
                     isExplorer=true },
    CARRIER      = { name="母舰",   speed=18,  health=3000, maxHealth=3000, range=320, dmg=60, color={200,150,255}, buildTime=180,
                     aoeRadius=80, shotRate=0.3 },
    INTERCEPTOR  = { name="拦截舰", speed=240, health=80,   maxHealth=80,   range=180, dmg=14, color={255,220,80},  buildTime=20,
                     shotRate=1.5 },
    -- V2.6 A1: 新增舰种
    STEALTH      = { name="隐形舰", speed=140, health=80,   maxHealth=80,   range=150,  dmg=15, color={80,200,160}, buildTime=25,
                     isStealth=true, stealthDuration=5, stealthSpeedMult=2.0, firstStrikeDmgMult=1.5 },
    SUPPORT      = { name="支援舰", speed=50,  health=200,  maxHealth=200,  range=0,    dmg=0,  color={180,100,220}, buildTime=30,
                     isSupport=true, healRadius=120, healInterval=8, healAmount=15, allyDmgBonus=0.10, allyDmgBonusRadius=80 },
    DREADNOUGHT  = { name="巨型战舰", speed=25, health=4000, maxHealth=4000, range=450, dmg=70, color={180,60,60}, buildTime=240,
                     aoeRadius=90, shotRate=0.4, isDreadnought=true, counterAttackChance=0.10, counterAttackDmg=50 },
    TURRET         = { name="轨道炮塔", speed=0, health=100, maxHealth=100, range=300, dmg=25, color={255,200,120}, buildTime=0,
                     isTurret=true, shotRate=1.5 },
}
SHIP_QUEUE_ORDER = {"ENGINEER","EXPLORER","SCOUT","INTERCEPTOR","FRIGATE","DESTROYER","STEALTH","SUPPORT","BATTLECRUISER","CARRIER","DREADNOUGHT"}
SHIP_COSTS = {
    SCOUT         = { metal=100,  esource=50  },
    FRIGATE       = { metal=250,  esource=100 },
    DESTROYER     = { metal=600,  esource=300 },
    BATTLECRUISER = { metal=1800, esource=800,  nuclear=200 },
    ENGINEER      = { metal=180,  esource=80  },
    EXPLORER      = { metal=300,  esource=120 },
    CARRIER       = { metal=2500, esource=1000, nuclear=400 },
    INTERCEPTOR   = { metal=120,  esource=60  },
    -- V2.6 A1: 新增舰种建造费用
    STEALTH       = { metal=200,  esource=100, crystal=50  },
    SUPPORT       = { metal=300,  esource=150 },
    DREADNOUGHT  = { metal=5000, esource=2000, nuclear=800, crystal=200 },
}

-- V2.6 A1: 新舰种解锁条件
SHIP_UNLOCK_REQUIREMENTS = {
    STEALTH      = { coreLevel=4, tech="PHASE_DRIVE",       desc="核心Lv.4 + 相位驱动" },
    SUPPORT      = { coreLevel=3, tech="NANO_REPAIR",       desc="核心Lv.3 + 纳米修复" },
    DREADNOUGHT = { coreLevel=8, tech="NOVA_CANNON",        desc="核心Lv.8 + 新星炮 + 量子堡垒" },
}

-- V2.6 A1: 巨型战舰建造上限（每波次）
DREADNOUGHT_PER_WAVE_LIMIT = 1

-- V2.6 A3: 多阶段Boss系统定义
-- 阶段阈值说明：hpThreshold 表示该阶段激活的最高血量比例（即血量低于该值时激活该阶段）
-- 例如：phase1.hpThreshold=1.00, phase2.hpThreshold=0.70, phase3.hpThreshold=0.30 表示
--   100%-70% 血量 → 阶段1；70%-30% 血量 → 阶段2；30%-0% 血量 → 阶段3
BOSS_PHASES = {
    -- 战列Boss：3阶段
    BATTLECRUISER = {
        { hpThreshold = 1.00, name = "常规形态",    dmgMult = 1.0, aoeRadiusMult = 1.0, special = nil },
        { hpThreshold = 0.70, name = "狂怒形态",    dmgMult = 1.5, aoeRadiusMult = 2.0, special = "BARRAGE" },
        { hpThreshold = 0.30, name = "死战形态",    dmgMult = 2.0, aoeRadiusMult = 2.0, special = "SUMMON_MINIONS", summonCount = 2, summonInterval = 5.0 },
    },
    -- 母舰Boss：3阶段
    CARRIER = {
        { hpThreshold = 1.00, name = "舰载机形态",  dmgMult = 1.0, shieldMult = 1.0, droneInterval = 8.0, special = nil },
        { hpThreshold = 0.60, name = "护盾强化",   dmgMult = 1.0, shieldMult = 3.0, droneInterval = 4.0, special = nil },
        { hpThreshold = 0.20, name = "自爆倒计时",  dmgMult = 1.0, shieldMult = 3.0, droneInterval = 2.0, special = "SELF_DESTRUCT", countdown = 15.0 },
    },
    -- 虚空Boss：4阶段（新增）
    VOID_LORD = {
        { hpThreshold = 1.00, name = "隐形形态",    dmgMult = 0.8, speedMult = 1.5, special = "STEALTH", stealthPhase = true },
        { hpThreshold = 0.70, name = "分裂形态",    dmgMult = 1.2, special = "PHANTOM_SPLIT", phantomCount = 2 },
        { hpThreshold = 0.40, name = "暗能腐蚀",    dmgMult = 1.5, special = "DARK_ENERGY", dotDamage = 20, dotInterval = 1.0 },
        { hpThreshold = 0.20, name = "虚空吞噬",    dmgMult = 2.0, special = "VOID_CONSUME", channelDamage = 20, channelInterruptable = true, channelInterruptThreshold = 500 },
    },
}

-- P1-4/5: Boss 专属技能参数
BOSS_SKILL_INTERVAL = {
    BARRAGE = 6.0,         -- 战列Boss狂怒形态：每6秒一次炮击
    DRONE_SWARM = 8.0,     -- 母舰Boss：每8秒释放无人机群
    VOID_CONSUME = 10.0,   -- 虚空Boss：每10秒尝试吞噬
    PHANTOM_SPLIT = 12.0, -- 虚空Boss分裂形态：每12秒产生分身
    SELF_DESTRUCT = 15.0,   -- 母舰自爆倒计时：15秒
}
BOSS_BARRAGE_DMG = 30     -- 炮击基础伤害
BOSS_DRONE_COUNT = 6        -- 无人机群数量
BOSS_DRONE_DMG = 8         -- 无人机攻击
BOSS_VOID_DMG = 30        -- 虚空吞噬基础伤害（由40下调，避免被秒杀）
BOSS_PHANTOM_COUNT = 2     -- 幻影分身数量

BOSS_SPAWN_WAVE = { BATTLECRUISER = 10, CARRIER = 10, VOID_LORD = 15 }  -- 各类型Boss首次出现波次

-- ============================================================================
-- P1-1: 舰船改装模块系统
-- ============================================================================
MODULE_CAT = { ATTACK = "attack", DEFENSE = "defense", UTILITY = "utility" }

SHIP_MODULES = {
    -- 攻击模块 (5)
    PIERCE_WARHEAD  = { name="穿透弹头",   cat=MODULE_CAT.ATTACK,  cost=5, replaceCost=3, icon="🔥",
        desc="攻击无视15%护盾", effect={type="pierceShield", value=0.15} },
    RAPID_FIRE      = { name="速射装置",   cat=MODULE_CAT.ATTACK,  cost=5, replaceCost=3, icon="⚡",
        desc="射速+25%", effect={type="shotRateMult", value=1.25} },
    PLASMA_BURN     = { name="等离子灼烧", cat=MODULE_CAT.ATTACK,  cost=5, replaceCost=3, icon="☄️",
        desc="攻击附带3s灼烧(每秒2%最大生命)", effect={type="burn", dps=0.02, duration=3.0} },
    PRECISION       = { name="精准打击",   cat=MODULE_CAT.ATTACK,  cost=5, replaceCost=3, icon="🎯",
        desc="伤害+20%，射速-10%", effect={type="dmgUp", dmgMult=1.20, rateMult=0.90} },
    PULSE_OVERLOAD  = { name="脉冲过载",   cat=MODULE_CAT.ATTACK,  cost=5, replaceCost=3, icon="💥",
        desc="每5次攻击触发一次双倍伤害", effect={type="pulseOverload", interval=5, mult=2.0} },
    -- 防御模块 (5)
    NANO_ARMOR      = { name="纳米装甲",   cat=MODULE_CAT.DEFENSE, cost=5, replaceCost=3, icon="🛡️",
        desc="最大生命+25%", effect={type="hpMult", value=1.25} },
    ENERGY_SHIELD   = { name="能量护盾",   cat=MODULE_CAT.DEFENSE, cost=5, replaceCost=3, icon="🔮",
        desc="获得20%最大生命的护盾", effect={type="shield", value=0.20} },
    EMERGENCY_REPAIR= { name="应急维修",   cat=MODULE_CAT.DEFENSE, cost=5, replaceCost=3, icon="🔧",
        desc="生命<30%时每秒回复2%最大生命", effect={type="emergencyHeal", threshold=0.30, healRate=0.02} },
    REFLECT_COAT    = { name="反射镀层",   cat=MODULE_CAT.DEFENSE, cost=5, replaceCost=3, icon="✨",
        desc="受击时15%概率反弹50%伤害", effect={type="reflect", chance=0.15, ratio=0.50} },
    STEALTH_PAINT   = { name="隐匿涂装",   cat=MODULE_CAT.DEFENSE, cost=5, replaceCost=3, icon="👻",
        desc="战斗开始3s内不被攻击", effect={type="stealth", duration=3.0} },
    -- 辅助模块 (5)
    TACTICAL_LINK   = { name="战术链路",   cat=MODULE_CAT.UTILITY, cost=5, replaceCost=3, icon="📡",
        desc="同编队友军+8%伤害", effect={type="allyDmgAura", value=0.08} },
    RECON_PROBE     = { name="侦察探针",   cat=MODULE_CAT.UTILITY, cost=5, replaceCost=3, icon="🛰️",
        desc="标记敌人使其受伤+12%持续4s", effect={type="markEnemy", value=0.12, duration=4.0} },
    TRACTOR_BEAM    = { name="牵引光束",   cat=MODULE_CAT.UTILITY, cost=5, replaceCost=3, icon="🌀",
        desc="减速命中目标20%持续2s", effect={type="slow", value=0.20, duration=2.0} },
    OVERCLOCK_ENGINE= { name="超频引擎",   cat=MODULE_CAT.UTILITY, cost=5, replaceCost=3, icon="🚀",
        desc="移动速度+30%", effect={type="speedMult", value=1.30} },
    QUANTUM_ANCHOR  = { name="量子锚定",   cat=MODULE_CAT.UTILITY, cost=5, replaceCost=3, icon="⚓",
        desc="击杀时回复5%最大生命", effect={type="killHeal", value=0.05} },
}

SHIP_MODULES_BY_CAT = { attack={}, defense={}, utility={} }
for k, v in pairs(SHIP_MODULES) do
    SHIP_MODULES_BY_CAT[v.cat][#SHIP_MODULES_BY_CAT[v.cat]+1] = k
end
for _, list in pairs(SHIP_MODULES_BY_CAT) do table.sort(list) end

-- ============================================================================
-- 星球类型加成表
-- ============================================================================
PLANET_TYPE_BONUS = {
    Terran        = { mineralMult=1.3,   label="矿石产量+30%"   },
    Oceanic       = { crystalMult=1.5,   label="水晶产量+50%"   },
    Volcanic      = { nuclearMult=1.4,   label="核能精炼+40%"   },
    Desert        = { mineralMult=1.3,   label="矿石产量+30%"   },
    Barren        = { buildCostMult=0.85, label="建造费用-15%"  },
    ["Gas Giant"] = { esourceMult=1.6,   label="能源精炼+60%"   },
}

-- ============================================================================
-- 阶段性目标定义
-- ============================================================================
STAGE_GOALS = {
    { id="first_colony",   title="建立第一个殖民地",  desc="探索并殖民一颗星球",         check=function(gs) return (gs.profile and gs.profile.colonized or 0) >= 1 end,  reward={metal=500,  esource=300} },
    { id="first_refinery", title="建造精炼厂",         desc="在基地建造资源精炼厂",        check=function(gs) return gs.base and gs.base.buildings and (function() for _,b in ipairs(gs.base.buildings) do if b.key=="REFINERY" then return true end end return false end)() end, reward={nuclear=100, esource=200} },
    { id="first_ship",     title="建造第一艘舰船",     desc="完成一艘舰船的建造",          check=function(gs) return (gs.totalShipsBuilt or 0) >= 1 end,                    reward={metal=300,  esource=150} },
    { id="fleet_5",        title="舰队扩编",           desc="拥有至少5艘舰船（含储备）",  check=function(gs) return (gs.totalShipsBuilt or 0) >= 5 end,                    reward={metal=600,  esource=300,  nuclear=50} },
    { id="research_first", title="完成第一项科技",     desc="解锁任意一项科技",            check=function(gs) return gs.rs and next(gs.rs.unlocked) ~= nil end,              reward={nuclear=200, credits=500} },
    { id="core_lv3",       title="基地核心Lv.3",       desc="将基地核心升级至3级",         check=function(gs) return gs.base and (gs.base.coreLevel or 1) >= 3 end,          reward={metal=1000, esource=500,  nuclear=200} },
    { id="colony_3",       title="三星联盟",           desc="殖民3颗星球",                 check=function(gs) return (gs.profile and gs.profile.colonized or 0) >= 3 end,  reward={credits=1000, metal=800} },
    { id="research_5",   title="科技先驱",     desc="解锁任意5项科技",
      check=function(gs)
          if not (gs.rs and gs.rs.unlocked) then return false end
          local n = 0; for _ in pairs(gs.rs.unlocked) do n = n + 1 end; return n >= 5
      end,
      reward={nuclear=400, credits=1000} },
    { id="quantum_core", title="量子突破",     desc="研究完成量子核心科技",
      check=function(gs)
          return gs.rs and gs.rs.unlocked and gs.rs.unlocked["QUANTUM_CORE"] == true
      end,
      reward={metal=2000, esource=1000, nuclear=600, credits=2000} },
    { id="colony_8",     title="星系帝国",     desc="殖民8颗星球",
      check=function(gs) return (gs.profile and gs.profile.colonized or 0) >= 8 end,
      reward={credits=3000, metal=2000, esource=1000} },
    { id="pirates_50",   title="星域清道夫",   desc="累计击毁50艘海盗舰船",
      check=function(gs) return (gs.totalEnemiesKilled or 0) >= 50 end,
      reward={metal=1500, nuclear=300, credits=1000} },
    { id="endless_3",    title="永恒征服者",   desc="无尽模式存活至第3轮",
      check=function(gs) return (gs.endlessRound or 0) >= 3 end,
      reward={metal=3000, esource=1500, nuclear=800, credits=3000} },
    { id="trade_hub",    title="星际商人",     desc="在任意星球建造星际交易所",
      check=function(gs)
          if not gs.colonizedPlanets then return false end
          for _, planet in ipairs(gs.colonizedPlanets) do
              if planet.buildings then
                  for _, b in ipairs(planet.buildings) do
                      if b.key == "TRADE_HUB" then return true end
                  end
              end
          end
          return false
      end,
      reward={credits=2000, esource=500} },
    { id="fleet_15",     title="钢铁舰队",     desc="累计建造15艘舰船",
      check=function(gs) return (gs.totalShipsBuilt or 0) >= 15 end,
      reward={metal=2500, esource=1200, nuclear=400} },
    { id="nuclear_5000", title="核能霸主",     desc="核燃料储量达到5000",
      check=function(gs)
          return gs.rm and gs.rm.resources and (gs.rm.resources.nuclear or 0) >= 5000
      end,
      reward={credits=2500, metal=1000} },
}

-- ============================================================================
-- P1-3: 指挥官系统常量
-- ============================================================================
COMMANDER_MAX_LEVEL = 10
COMMANDER_MAX_SLOTS = 4
COMMANDER_RETIRE_REWARD = 3

COMMANDER_EXP_TABLE = {
    [1] = 50,   [2] = 120,  [3] = 220,  [4] = 360,  [5] = 540,
    [6] = 780,  [7] = 1080, [8] = 1450, [9] = 1900, [10] = math.huge,
}

COMMANDER_SPECS = {
    tactical = {
        key = "tactical", name = "战术专精", icon = "⚔",
        desc = "强化编队攻击与技能伤害",
        perLevel = { dmgMult = 0.03 },
        passive = "编队攻击力 +3%/级",
        skill = {
            name = "精准打击", icon = "🎯", cooldown = 90,
            desc = "全编队攻击力×1.5，持续8秒",
            duration = 8, effectMult = 1.5, effectKey = "dmg",
        },
    },
    defense = {
        key = "defense", name = "防御专精", icon = "🛡",
        desc = "强化编队生存与护盾",
        perLevel = { healthMult = 0.04 },
        passive = "编队生命值 +4%/级",
        skill = {
            name = "紧急护盾", icon = "🔰", cooldown = 120,
            desc = "全编队无敌6秒",
            duration = 6, effectMult = 0.0, effectKey = "invuln",
        },
    },
    logistics = {
        key = "logistics", name = "后勤专精", icon = "📦",
        desc = "强化资源获取与维修",
        perLevel = { resourceMult = 0.05 },
        passive = "战斗资源掉落 +5%/级",
        skill = {
            name = "战场回收", icon = "♻", cooldown = 0,
            desc = "击杀敌舰时额外获得30%资源（被动）",
            duration = 0, effectMult = 1.3, effectKey = "salvage",
        },
    },
}

COMMANDER_NAMES = {
    "阿尔法·雷恩", "贝塔·索拉", "伽马·韦恩", "德尔塔·凯恩",
    "泽塔·摩根", "西塔·布雷克", "伊塔·诺瓦", "卡帕·奥瑞",
    "拉姆达·克洛", "西格玛·芬恩", "陶·海姆", "欧米伽·塞斯",
    "星火·将军", "暗鸦·少校", "曙光·上尉", "铁壁·中校",
}

COMMANDER_SOURCE = {
    CAMPAIGN  = "campaign",
    NEMESIS   = "nemesis",
    STREAK    = "streak",
    MARKET    = "market",
    INITIAL   = "initial",
}

COMMANDER_MARKET_COST = 2000

-- ============================================================================
-- P0-2: 无尽模式定义
-- ============================================================================
ENDLESS_MODES = {
    CLASSIC = { name = "经典无尽", startWave = 1, difficultyCurve = "linear", 
                desc = "难度线性递增，适合长期挑战" },
    SURVIVAL = { name = "生存模式", startWave = 20, difficultyCurve = "exponential",
                desc = "难度指数递增，更具挑战性" },
    SPEEDRUN = { name = "速通模式", startWave = 1, difficultyCurve = "linear",
                desc = "10分钟内到达波次50", timeLimit = 600, goalWave = 50 },
}

-- 难度递增曲线计算
function getEndlessDifficulty(waveNum, mode)
    local baseMultiplier = 1.0
    local endlessMode = ENDLESS_MODES[mode] or ENDLESS_MODES.CLASSIC
    
    if endlessMode.difficultyCurve == "linear" then
        baseMultiplier = 1.0 + (waveNum - 1) * 0.08  -- 每波 +8%
    elseif endlessMode.difficultyCurve == "exponential" then
        baseMultiplier = math.pow(1.1, math.min(waveNum - 1, 30))  -- 每波 ×1.1
    end
    
    return math.min(10.0, baseMultiplier)  -- 硬上限 10x
end

-- 无尽模式奖励表
ENDLESS_REWARDS = {
    every10Wave = { blueCrystal = {30, 50} },  -- 每10波奖励范围
    every25Wave = { purpleCrystal = 10 },       -- 每25波稀有材料
    milestone = {
        [50] = { blueCrystal = 100, purpleCrystal = 30 },
        [100] = { blueCrystal = 200, purpleCrystal = 80, rainbowCrystal = 10 },
        [200] = { blueCrystal = 500, purpleCrystal = 200, rainbowCrystal = 50 },
    },
}

-- ============================================================================
-- P0-3: 每日挑战定义
-- ============================================================================
DAILY_CHALLENGES = {
    { type = "ONLY_DESTROYER", desc = "只能建造驱逐舰", icon = "🚀", reward = 50 },
    { type = "ONLY_STEALTH", desc = "只能建造隐形舰", icon = "👻", reward = 60, prereq = "PHASE_DRIVE" },
    { type = "NO_SUPPORT", desc = "禁止建造支援舰", icon = "🚫", reward = 40 },
    { type = "LOW_RESOURCE", metalMult = 0.5, esourceMult = 0.5, desc = "资源产量减半", icon = "📉", reward = 45 },
    { type = "NO_SKILLS", desc = "禁止使用主动技能", icon = "❌", reward = 70 },
    { type = "BOSS_FROM_WAVE1", desc = "第1波就是Boss", icon = "💀", reward = 100, difficulty = "hard" },
    { type = "SPEED_BATTLE", timeLimitPerWave = 30, desc = "每波限时30秒", icon = "⏱️", reward = 80 },
    { type = "NO_HEALING", desc = "禁止治疗", icon = "🩹", reward = 65 },
}

-- 挑战积分商店
CHALLENGE_SHOP = {
    { id = "SKILL_RESET", name = "技能点重置券", cost = 100, desc = "重置所有技能点", icon = "🔄" },
    { id = "GOLD_CHEST", name = "黄金宝箱", cost = 200, desc = "随机稀有道具", icon = "📦" },
    { id = "SPEED_UP", name = "全局加速", cost = 150, desc = "所有建筑速度+50%", icon = "⚡" },
    { id = "REPAIR_KIT", name = "维修套件", cost = 80, desc = "恢复舰队50%血量", icon = "🔧" },
    { id = "BOSS_KEY", name = "Boss钥匙", cost = 500, desc = "直接召唤一个Boss", icon = "🗝️" },
}

-- P0-1: 超级 Boss 定义（里程碑波次触发）
SUPER_BOSSES = {
    -- 毁灭者：波次 50 首次出现
    DEVASTATOR = {
        name = "毁灭者",
        health = 50000,
        phases = {
            { hpThreshold = 0.8, name = "常规形态", special = nil },
            { hpThreshold = 0.5, name = "毁灭轰炸", special = "BOMBARDMENT",
              skillInterval = 4, skillDmg = 80, aoeRadius = 120 },
            { hpThreshold = 0.2, name = "最终形态", special = "FRENZY",
              speedMult = 2, dmgMult = 1.5, skillInterval = 2 },
        },
        rewards = { blueCrystal = 200, purpleCrystal = 50, rareItem = "DEVASTATOR_CORE" },
        mechanics = "范围轰炸 · 全屏AOE · 移动加速",
    },
    -- 虚空泰坦：波次 100 首次出现
    VOID_TITAN = {
        name = "虚空泰坦",
        health = 100000,
        phases = {
            { hpThreshold = 0.7, name = "虚空领域", special = "VOID_FIELD",
              fieldDmgPerSec = 5, shrinkRate = 0.1 },
            { hpThreshold = 0.4, name = "时间扭曲", special = "TIME_WARP",
              slowAllies = 0.5, duration = 10 },
            { hpThreshold = 0.1, name = "湮灭", special = "ANNIHILATION",
              summonMinions = true, minionCount = 8 },
        },
        rewards = { blueCrystal = 300, purpleCrystal = 100, rainbowCrystal = 20, rareItem = "VOID_TITAN_HEART" },
        mechanics = "虚空领域 · 时间扭曲 · 召唤从属",
    },
    -- 母巢意识：波次 200 首次出现
    HIVE_MIND = {
        name = "母巢意识",
        health = 200000,
        phases = {
            { hpThreshold = 0.6, name = "感染蔓延", special = "INFECTION",
              enemySpawnRate = 0.5, alliesTakeDmg = 2 },
            { hpThreshold = 0.3, name = "意识控制", special = "MIND_CONTROL",
              chanceToControl = 0.1, controlDuration = 5 },
            { hpThreshold = 0, name = "最终爆发", special = "FINAL_BURST",
              allAlliesTakeDmg = true, dmg = 50 },
        },
        rewards = { blueCrystal = 500, purpleCrystal = 200, rainbowCrystal = 50, rareItem = "HIVE_QUEEN_FRAGMENT" },
        mechanics = "持续召唤 · 意识控制 · 全队伤害",
    },
}

-- 超级 Boss 触发波次
SUPER_BOSS_WAVES = { 50, 100, 200 }

-- 超级 Boss 掉落物品定义
SUPER_BOSS_ITEMS = {
    DEVASTATOR_CORE = { name = "毁灭者核心", desc = "用于旗舰强化", rarity = "epic" },
    VOID_TITAN_HEART = { name = "虚空泰坦之心", desc = "用于传说装备", rarity = "legendary" },
    HIVE_QUEEN_FRAGMENT = { name = "母巢意识碎片", desc = "终极材料", rarity = "mythic" },
}

-- P0-4: 舰船强化材料
ENHANCEMENT_MATERIALS = {
    BASIC_REPAIR_KIT    = { name = "初级修复剂",    cost = { metal = 100 },      effect = { health = 10 } },
    ADVANCED_REPAIR_KIT = { name = "高级修复剂",    cost = { metal = 300 },      effect = { health = 35 } },
    WEAPON_MODULE       = { name = "武器模组",       cost = { metal = 200 },      effect = { dmg = 8 } },
    SHIELD_CAPACITOR    = { name = "护盾电容",      cost = { metal = 250 },      effect = { shield = 15 } },
    ENGINE_BOOSTER      = { name = "引擎增强器",    cost = { metal = 200 },      effect = { speed = 5 } },
    TITANIUM_ALLOY      = { name = "钛合金",        cost = { blueCrystal = 5 },  effect = { all = 5 } },
    DARK_MATTER         = { name = "暗物质",        cost = { purpleCrystal = 5 }, effect = { dmg = 15, health = 10 } },
}

-- 每艘舰船强化等级上限
SHIP_ENHANCE_MAX = {
    DESTROYER = 20, BATTLECRUISER = 15, CARRIER = 10,
    STEALTH = 25, SUPPORT = 15, DREADNOUGHT = 8,
}

-- 强化效果倍率（每级）
ENHANCE_EFFECT_SCALE = {
    health = 1.0,   -- 每级 +10% 基础值
    dmg = 0.08,    -- 每级 +8% 基础值
    shield = 0.06, -- 每级 +6% 基础值
    speed = 0.05,  -- 每级 +5% 基础值
    all = 0.10,    -- 每级 +10% 全部属性
}

-- P0-5: 星际贸易路线定义
TRADE_ROUTES = {
    { from = "INDUSTRIAL_PLANET", to = "HOME_BASE", resource = "metal", amount = 50, cooldown = 60, profit = 1.2 },
    { from = "RESOURCE_RICH", to = "HOME_BASE", resource = "esource", amount = 30, cooldown = 90, profit = 1.3 },
    { from = "HOME_BASE", to = "FRONTIER", resource = "metal", amount = 40, cooldown = 120, profit = 1.5 },
}

-- 贸易路线建立条件
TRADE_ROUTE_REQUIREMENTS = {
    minDistance = 200,
    hasTradeHub = true,
    fleetAvailable = true,
    maxRoutes = 3,  -- 最多同时建立 3 条贸易路线
}

-- 贸易路线奖励产出间隔（秒）
TRADE_REWARD_INTERVAL = 300  -- 5 分钟

-- P0-6/7: 自动战斗与加速配置
AUTO_BATTLE = {
    enabled = false,
    retreatThreshold = 0.2,      -- 20% HP 时后撤
    healerPriority = true,        -- 治疗舰优先治疗低血量友舰
    stealthWhenIdle = true,       -- 隐形舰空闲时自动隐身
    useSkillsAutomatically = true, -- 自动使用技能
}

BATTLE_SPEEDS = {
    { id = "NORMAL",   name = "1x",   mult = 1.0, icon = "▶" },
    { id = "FAST",     name = "1.5x", mult = 1.5, icon = "▶▶" },
    { id = "FASTER",   name = "2x",   mult = 2.0, icon = "▶▶▶" },
    { id = "FASTEST",  name = "3x",   mult = 3.0, icon = "⏩" },
}
CURRENT_BATTLE_SPEED = "NORMAL"

-- P1-1: Boss Rush 模式定义
BOSS_RUSH = {
    -- 可选的 Boss 列表
    bosses = {
        { id = "BATTLECRUISER", name = "战列巡洋舰", healthMult = 1.0, phaseCount = 3 },
        { id = "CARRIER", name = "母舰", healthMult = 1.2, phaseCount = 3 },
        { id = "VOID_LORD", name = "虚空领主", healthMult = 1.5, phaseCount = 4 },
        { id = "DEVASTATOR", name = "毁灭者", healthMult = 2.0, phaseCount = 3, isSuper = true },
        { id = "VOID_TITAN", name = "虚空泰坦", healthMult = 3.0, phaseCount = 3, isSuper = true },
    },
    
    -- Boss 数量选项
    bossCounts = { 3, 5, 7 },
    
    -- 波次间隔（秒）
    restInterval = 8,
    
    -- 奖励
    rewards = {
        perBoss = { blueCrystal = 30 },
        completion = { purpleCrystal = 50 },
        perfect = { purpleCrystal = 100, rainbowCrystal = 10 },
    },
    
    -- 分数计算
    scorePerBoss = 1000,
    timeBonus = 100,  -- 每节省 10 秒 +100 分
    healthBonus = 50, -- 每 10% 剩余生命 +50 分
}

-- P1-8: 隐藏关卡定义
HIDDEN_LEVELS = {
    {
        id = "VOID_REALM",
        name = "虚空领域",
        desc = "虚空领主的巢穴",
        triggerCondition = { voidBossDefeated = 3 },
        enemies = { VOID_LORD = 1 },
        rewards = { rainbowCrystal = 30, rareItem = "VOID_KEY" },
        difficulty = "extreme",
    },
    {
        id = "ANCIENT_TEMPLE",
        name = "远古遗迹",
        desc = "古老文明的遗迹",
        triggerCondition = { planetsExplored = 25, techsResearched = 15 },
        enemies = { GUARDIAN = 5, ANCIENT_BOSS = 1 },
        rewards = { purpleCrystal = 100, rareItem = "ANCIENT_ARTIFACT" },
        difficulty = "hard",
    },
    {
        id = "INFINITE_TOWER",
        name = "无尽塔",
        desc = "无限挑战",
        triggerCondition = { endlessWave = 100 },
        enemies = { randomBosses = true, count = 10 },
        rewards = { rainbowCrystal = 50 },
        difficulty = "extreme",
    },
}
