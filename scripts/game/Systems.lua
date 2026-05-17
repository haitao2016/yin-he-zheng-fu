-- ============================================================================
-- game/Systems.lua  -- 所有游戏系统与常量（无引擎 API 依赖）
-- ============================================================================

-- ============================================================================
-- 全局常量
-- ============================================================================
BUILDINGS = {
    MINE         = { name="自动化矿井",   cost={metal=100,esource=50},               prod={minerals=10},  buildTime=5,  upgradeK=1.5 },
    POWER_PLANT  = { name="太阳能阵列",   cost={metal=80},                           prod={energy=15},    buildTime=3,  upgradeK=1.4 },
    SHIELD_GEN   = { name="护盾发生器",   cost={metal=300,esource=400,nuclear=100},  prod={},             buildTime=12, upgradeK=1.8 },
    TRADE_HUB    = { name="星际交易所",   cost={metal=500,esource=300,nuclear=80},   prod={credits=5},    buildTime=15, upgradeK=1.6 },  -- H2: 解锁市场面板
}
BUILD_ORDER = {"MINE","POWER_PLANT","SHIELD_GEN","TRADE_HUB"}

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
    BASE_SHIELD     = { name="护盾发生器", cost={metal=300,  esource=400, nuclear=100}, desc="基地护盾值+200/级（累计）",          buildTime=12, upgradeK=1.8 },  -- L3: 原SHIELD_GEN，避免与BUILDINGS.SHIELD_GEN同名
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
-- 每个模块解锁所需的最低基地核心等级（coreLevel）
-- Lv1 初始已解锁；Lv2-Lv7 随核心升级解锁
BASE_MODULE_UNLOCK_LEVEL = {
    COMMAND_CENTER  = 2,   -- Lv2 解锁
    SOLAR_ARRAY     = 1,   -- 初始可建
    ENERGY_CORE     = 1,   -- 初始可建
    MINERAL_SILO    = 2,   -- Lv2 解锁
    MATERIAL_DEPOT  = 2,   -- Lv2 解锁
    RESEARCH_CENTER = 3,   -- Lv3 解锁
    DEFENSE_CANNON  = 3,   -- Lv3 解锁
    HANGAR          = 4,   -- Lv4 解锁
    BUILD_CENTER    = 4,   -- Lv4 解锁
    REFINERY        = 2,   -- Lv2 解锁
    EXCHANGE_CENTER = 5,   -- Lv5 解锁
    SHIPYARD        = 3,   -- Lv3 解锁
    BASE_SHIELD          = 6,   -- Lv6 解锁
    WARP_GATE            = 7,   -- Lv7 解锁
    -- P1-2: Lv8-10 专属模块
    PARTICLE_ACCELERATOR = 8,   -- Lv8 解锁
    WARP_GATE_PRIME      = 9,   -- Lv9 解锁
    STELLAR_FORTRESS     = 10,  -- Lv10 解锁
}

-- 基地核心最大等级
BASE_CORE_MAX_LEVEL = 10

--- 根据核心等级计算模块槽位上限（Lv1=8，每级+1，最高15）
function BaseModuleSlots(coreLevel)
    return math.min(15, 7 + (coreLevel or 1))
end

-- 各级升级费用（从当前等级升到下一级）
-- key = 当前等级，value = {metal, esource, nuclear, buildTime(秒)}
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

-- 每个核心等级解锁的模块列表（用于提示）
BASE_CORE_UNLOCK_PREVIEW = {
    [1]  = {"ENERGY_CORE","SOLAR_ARRAY"},
    [2]  = {"COMMAND_CENTER","MINERAL_SILO","MATERIAL_DEPOT","REFINERY"},
    [3]  = {"RESEARCH_CENTER","DEFENSE_CANNON","SHIPYARD"},
    [4]  = {"HANGAR","BUILD_CENTER"},
    [5]  = {"EXCHANGE_CENTER"},
    [6]  = {"BASE_SHIELD"},
    [7]  = {"WARP_GATE"},
    [8]  = {"PARTICLE_ACCELERATOR"},  -- P1-2: 粒子加速器
    [9]  = {"WARP_GATE_PRIME"},        -- P1-2: 主曲速门
    [10] = {"STELLAR_FORTRESS"},       -- P1-2: 恒星要塞
}

-- 互换比例表：EXCHANGE_RATES[from][to] = 消耗 from 数量获得 to 数量的比例
-- 每次互换固定消耗 100 单位 from，获得 amount 单位 to
EXCHANGE_RATES = {
    metal   = { esource=1.5,  nuclear=0.3  },  -- 100金属 → 150能源 / 30核能
    esource = { metal=0.6,    nuclear=0.2  },  -- 100能源 → 60金属  / 20核能
    nuclear = { metal=3.0,    esource=4.5  },  -- 100核能 → 300金属 / 450能源
}
EXCHANGE_AMOUNT = 100   -- 每次互换消耗的来源资源数量

TECHS = {
    -- Tier 1（无前置，初始可研究）
    DEEP_MINING      = { name="深层采矿",   desc="矿井产量+20%",              cost={nuclear=50,  esource=100},          time=20, prereqs={},                                      bonus={building="MINE", prodMult=1.2} },
    SOLAR_EFFICIENCY = { name="高效光伏",   desc="电站产量+15%",              cost={nuclear=80,  metal=200},             time=30, prereqs={},                                      bonus={building="POWER_PLANT", prodMult=1.15} },
    CRYSTAL_PROCESS  = { name="水晶提纯",   desc="水晶→核能精炼效率+30%",     cost={esource=80,  metal=150},             time=25, prereqs={},                                      bonus={refineMult="crystal", val=1.3} },
    HULL_ALLOY       = { name="合金船壳",   desc="所有舰船最大耐久+25%",      cost={metal=200,   nuclear=60},            time=30, prereqs={},                                      bonus={shipHealthMult=1.25} },

    -- Tier 2（需要 1 项 Tier1 前置）
    SHIELD_REINFORCE = { name="护盾强化",   desc="基地护盾+300，防御+20%",    cost={nuclear=150, metal=400},             time=45, prereqs={"SOLAR_EFFICIENCY"},                    bonus={shieldBonus=300, defenseBonus=0.2} },
    RAPID_REFINE     = { name="快速精炼",   desc="精炼速率×1.5（原矿→精炼）", cost={nuclear=120, esource=200},           time=40, prereqs={"DEEP_MINING"},                         bonus={globalRefineMult=1.5} },
    COLONY_BIOTECH   = { name="殖民生物技术", desc="殖民星球人口增长速率+40%", cost={esource=150, nuclear=80},            time=35, prereqs={"CRYSTAL_PROCESS"},                     bonus={colonyPopMult=1.4} },
    NANO_REPAIR      = { name="纳米修复",   desc="所有战舰最大耐久+20%",      cost={metal=200,   esource=100},           time=30, prereqs={"HULL_ALLOY"},                          bonus={shipHealthMult=1.20} },

    -- Tier 3（需要 2 项 Tier2 前置）── 四者互斥，只能选一（P1-3: 新增 VOID_ANCHOR）
    WARP_DRIVE       = { name="曲速引擎",   desc="舰队移动速度+50%",          cost={nuclear=300, esource=500},           time=60, prereqs={"SHIELD_REINFORCE","RAPID_REFINE"},     bonus={fleetSpeedMult=1.5},  exclusiveGroup="TIER3" },
    ADVANCED_WEAPONS = { name="高级武器系统", desc="所有战舰攻击力+30%",      cost={metal=500,   nuclear=200},           time=55, prereqs={"HULL_ALLOY","RAPID_REFINE"},           bonus={shipDmgMult=1.3},     exclusiveGroup="TIER3" },
    DEFENSE_MATRIX   = { name="防御矩阵",   desc="基地护盾+400，防御+30%",    cost={nuclear=200, metal=500},             time=50, prereqs={"SHIELD_REINFORCE","NANO_REPAIR"},      bonus={shieldBonus=400, defenseBonus=0.3}, exclusiveGroup="TIER3" },
    -- P1-3: 速攻专精替代路线（与 WARP_DRIVE 互斥）
    VOID_ANCHOR      = { name="虚空锚定",   desc="战舰攻击力+20%，敌方舰队减速20%",
                         cost={nuclear=280, esource=400, metal=200}, time=60,
                         prereqs={"SHIELD_REINFORCE","RAPID_REFINE"},
                         bonus={shipDmgMult=1.2, enemySpeedDebuff=0.8}, exclusiveGroup="TIER3" },

    -- Tier 4（顶层科技，需要 Tier3 前置）
    QUANTUM_CORE     = { name="量子核心",   desc="基地核心升级费用-20%，科研速度+50%", cost={nuclear=600, esource=800, metal=1000}, time=90, prereqs={"WARP_DRIVE","ADVANCED_WEAPONS"}, bonus={coreUpgradeCostMult=0.8, researchSpeedMult=1.5}, exclusiveGroup="TIER4_UTIL" },
    PHASE_DRIVE      = { name="相位驱动",   desc="精炼速率×1.4，舰队速度+40%",         cost={nuclear=500, esource=600, metal=800},  time=80, prereqs={"WARP_DRIVE","NANO_REPAIR"},          bonus={globalRefineMult=1.4, fleetSpeedMult=1.4} },
    -- P1-1: 攻击路线 Tier4 —— 前置 ADVANCED_WEAPONS
    NOVA_CANNON      = { name="新星炮",     desc="战舰AOE半径+80%，每波战斗开始获得1次星陨打击技能",
                         cost={nuclear=500, metal=800, esource=400}, time=85,
                         prereqs={"ADVANCED_WEAPONS"},
                         bonus={aoeRadiusMult=1.8, battleStartSkillCharge=1} },
    -- P1-1: 防御路线 Tier4 —— 前置 DEFENSE_MATRIX
    FORTRESS_PROTOCOL= { name="要塞协议",   desc="基地最大护盾×2.2，战斗中每10s护盾自动恢复5%",
                         cost={nuclear=400, metal=600, esource=600}, time=80,
                         prereqs={"DEFENSE_MATRIX"},
                         bonus={shieldMaxMult=2.2, shieldRegenPct=0.05} },
    -- P1-3: 虚空锚定专精路线 Tier4（与 QUANTUM_CORE 互斥）
    STELLAR_SYNC     = { name="星际同步",   desc="全局资源产出+25%，科研速度+30%",
                         cost={nuclear=500, esource=700, metal=800}, time=85,
                         prereqs={"VOID_ANCHOR","DEFENSE_MATRIX"},
                         bonus={globalProdMult=1.25, researchSpeedMult=1.3}, exclusiveGroup="TIER4_UTIL" },
}
TECH_ORDER = {
    "DEEP_MINING","SOLAR_EFFICIENCY","CRYSTAL_PROCESS","HULL_ALLOY",             -- Tier 1
    "SHIELD_REINFORCE","RAPID_REFINE","COLONY_BIOTECH","NANO_REPAIR",             -- Tier 2
    "WARP_DRIVE","ADVANCED_WEAPONS","DEFENSE_MATRIX","VOID_ANCHOR",              -- Tier 3 (P1-3: +VOID_ANCHOR)
    "QUANTUM_CORE","PHASE_DRIVE","NOVA_CANNON","FORTRESS_PROTOCOL","STELLAR_SYNC", -- Tier 4 (P1-3: +STELLAR_SYNC)
}

RANKS = {"见习指挥官","资深舰长","舰队少将","星系统治者","银河霸主"}
EXP_PER_LEVEL = 1000

RES_ORDER  = {"metal","esource","nuclear"}
-- L6: esource="能源"（精炼资源），energy="能量块"（原矿），通过标签明确区分层级
RES_LABELS = { metal="金属", esource="能源", nuclear="核能" }
RES_TAGS   = { metal="矿石", esource="能量块", nuclear="水晶" }   -- 原矿标签（顶栏左侧3列）
RES_REFINED_LABELS = { metal="金属(精)", esource="能源(精)", nuclear="核能(精)" }  -- 精炼区标签（顶栏右侧3行）
RES_COLORS = { metal={180,180,180}, esource={255,255,0}, nuclear={0,255,255} }

SHIP_TYPES = {
    -- buildTime 单位：秒（与 ShipProductionQueue 实际计时保持一致）
    SCOUT         = { name="侦察舰", speed=180, health=50,   maxHealth=50,   range=100,  dmg=6,  color={100,200,255}, buildTime=14 },
    FRIGATE       = { name="护卫舰", speed=100, health=150,  maxHealth=150,  range=200,  dmg=10, color={80,160,255},  buildTime=25 },
    DESTROYER     = { name="驱逐舰", speed=60,  health=400,  maxHealth=400,  range=300,  dmg=18, color={40,100,220},  buildTime=55 },
    BATTLECRUISER = { name="战列舰", speed=35,  health=1200, maxHealth=1200, range=380,  dmg=45, color={160,80,255},  buildTime=120,
                      aoeRadius=60, shotRate=0.5 },  -- 超重型主力舰：超高血量/伤害，低速，溅射攻击
    ENGINEER     = { name="工程舰", speed=40,  health=80,  maxHealth=80,  range=0,    dmg=0,  color={255,200,80},  buildTime=18,
                     mineRate={minerals=8, energy=4} },
    EXPLORER     = { name="探索舰", speed=120, health=100, maxHealth=100, range=0,    dmg=0,  color={120,255,160}, buildTime=22,
                     isExplorer=true },  -- 专用于殖民行星
    CARRIER      = { name="母舰",   speed=18,  health=3000, maxHealth=3000, range=320, dmg=60, color={200,150,255}, buildTime=180,
                     aoeRadius=80, shotRate=0.3 },  -- 巨型战舰：超强血量，范围溅射
    INTERCEPTOR  = { name="拦截舰", speed=240, health=80,   maxHealth=80,   range=180, dmg=14, color={255,220,80},  buildTime=20,
                     shotRate=1.5 },  -- 高速拦截：极快速度+高射速，玻璃炮
}
SHIP_QUEUE_ORDER = {"ENGINEER","EXPLORER","SCOUT","INTERCEPTOR","FRIGATE","DESTROYER","BATTLECRUISER","CARRIER"}
SHIP_COSTS = {
    SCOUT         = { metal=100,  esource=50  },
    FRIGATE       = { metal=250,  esource=100 },
    DESTROYER     = { metal=600,  esource=300 },
    BATTLECRUISER = { metal=1800, esource=800,  nuclear=200 },  -- 需要核能，体现高端定位
    ENGINEER      = { metal=180,  esource=80  },
    EXPLORER      = { metal=300,  esource=120 },
    CARRIER       = { metal=2500, esource=1000, nuclear=400 },  -- 顶级战舰，资源密集
    INTERCEPTOR   = { metal=120,  esource=60  },                -- 廉价快速消耗品
}

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
    -- ── 扩展目标（P2-3）: 8个中后期目标 ────────────────────────────────────
    -- 1. 完成5项科技
    { id="research_5",   title="科技先驱",     desc="解锁任意5项科技",
      check=function(gs)
          if not (gs.rs and gs.rs.unlocked) then return false end
          local n = 0; for _ in pairs(gs.rs.unlocked) do n = n + 1 end; return n >= 5
      end,
      reward={nuclear=400, credits=1000} },

    -- 2. 完成量子核心科技
    { id="quantum_core", title="量子突破",     desc="研究完成量子核心科技",
      check=function(gs)
          return gs.rs and gs.rs.unlocked and gs.rs.unlocked["QUANTUM_CORE"] == true
      end,
      reward={metal=2000, esource=1000, nuclear=600, credits=2000} },

    -- 3. 殖民8颗星球
    { id="colony_8",     title="星系帝国",     desc="殖民8颗星球",
      check=function(gs) return (gs.profile and gs.profile.colonized or 0) >= 8 end,
      reward={credits=3000, metal=2000, esource=1000} },

    -- 4. 歼灭50艘海盗舰船（累计战斗击杀）
    { id="pirates_50",   title="星域清道夫",   desc="累计击毁50艘海盗舰船",
      check=function(gs) return (gs.totalEnemiesKilled or 0) >= 50 end,
      reward={metal=1500, nuclear=300, credits=1000} },

    -- 5. 无尽模式进入第3轮
    { id="endless_3",    title="永恒征服者",   desc="无尽模式存活至第3轮",
      check=function(gs) return (gs.endlessRound or 0) >= 3 end,
      reward={metal=3000, esource=1500, nuclear=800, credits=3000} },

    -- 6. 建造星际交易所
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

    -- 7. 舰队规模达15艘
    { id="fleet_15",     title="钢铁舰队",     desc="累计建造15艘舰船",
      check=function(gs) return (gs.totalShipsBuilt or 0) >= 15 end,
      reward={metal=2500, esource=1200, nuclear=400} },

    -- 8. 核能储量达5000
    { id="nuclear_5000", title="核能霸主",     desc="核燃料储量达到5000",
      check=function(gs)
          return gs.rm and gs.rm.resources and (gs.rm.resources.nuclear or 0) >= 5000
      end,
      reward={credits=2500, metal=1000} },
}

-- ============================================================================
-- ResourceManager
-- ============================================================================
local ResourceManager = {}
ResourceManager.__index = ResourceManager

function ResourceManager.new()
    local self = setmetatable({}, ResourceManager)
    -- 原矿资源（行星/小行星产出，经精炼厂转化后才可用）
    self.resources   = { minerals=0,     energy=0,     crystal=0,
    -- 精炼资源（可直接消耗，初始储备用于建造精炼厂）
                         metal=800,      esource=500,  nuclear=300,  -- M1: 初始核能 150→300
                         population=10, credits=0 }
    self.rates       = { minerals=10,    energy=5,     crystal=2,
                         metal=0,        esource=0,    nuclear=0,
                         population=0.1, credits=0 }
    self.caps        = { minerals=9999,  energy=9999,  crystal=2000,
                         metal=99999,    esource=99999, nuclear=9999,
                         population=99999, credits=9999999 }
    self.convertRate  = 0   -- 范围 -20 ~ +20（原矿互换用）
    self.refineryMult = 0   -- 0=无精炼厂，>0=精炼厂倍率（由 applyBaseModuleEffects 设置）
    return self
end

-- 互换比例常量
local CONVERT_RATIO = 1.5  -- 1 矿石 → 1.5 能量（或 1.5 能量 → 1 矿石）

-- 精炼配置（模块级缓存，避免每帧 GC）
local REFINE_CFG = {
    minerals = { ref="metal",   ratio=3.0, processRate=7.0 },
    energy   = { ref="esource", ratio=2.0, processRate=3.0 },
    crystal  = { ref="nuclear", ratio=3.0, processRate=1.0 },  -- M1 修复：5:1→3:1，早期核能不再过窄
}

function ResourceManager:update(dt)
    -- Step 1：所有资源按速率正常积累（原矿也进入库存）
    for res, rate in pairs(self.rates) do
        if rate ~= 0 then
            local cap = self.caps[res] or 99999
            self.resources[res] = math.min(cap, (self.resources[res] or 0) + rate * dt)
        end
    end

    -- Step 2：原矿 ⇄ 原矿 自动互换（convertRate 只作用于原矿层）
    if self.convertRate ~= 0 then
        local rate = self.convertRate
        if rate > 0 then
            local drain = math.min(rate * dt, math.max(0, self.resources.minerals))
            self.resources.minerals = self.resources.minerals - drain
            self.resources.energy   = math.min(self.caps.energy,
                self.resources.energy + drain * CONVERT_RATIO)
        else
            local drain = math.min((-rate) * CONVERT_RATIO * dt, math.max(0, self.resources.energy))
            self.resources.energy   = self.resources.energy - drain
            self.resources.minerals = math.min(self.caps.minerals,
                self.resources.minerals + drain / CONVERT_RATIO)
        end
    end

    -- Step 3：精炼厂以固定速率从原矿库存消耗并转化为精炼资源
    -- refineryMult 来源对比：
    --   无（核心 Lv.1）          mult=0    → 不精炼
    --   星航基地核心 Lv.2+       mult=0.3  → 矿石 2.1/s（基础精炼能力）
    --   资源精炼厂 Lv.1          mult=1.0  → 矿石 7/s
    --   资源精炼厂 Lv.2          mult=1.5  → 矿石 10.5/s
    --   资源精炼厂 Lv.3          mult=2.0  → 矿石 14/s
    -- 精炼处理速率（processRate × mult）：
    --   矿石 7×mult /s → 金属 7×mult/3 /s
    --   能量块 3×mult /s → 能源 3×mult/2 /s
    --   水晶 1×mult /s → 核能 1×mult/5 /s
    if self.refineryMult and self.refineryMult > 0 then
        -- S1 RAPID_REFINE: 全局精炼速率加成（累乘到 refineryMult 上）
        local globalMult = (self.baseBonus and self.baseBonus.globalRefineMult) or 1.0
        for raw, cfg in pairs(REFINE_CFG) do
            local rawAmt = self.resources[raw] or 0
            if rawAmt > 0 then
                -- S1 CRYSTAL_PROCESS: 水晶精炼效率独立加成
                -- P1-2 Volcanic nuclearMult: 核能精炼速率加成
                local extraMult = globalMult
                if raw == "crystal" then
                    extraMult = extraMult * ((self.baseBonus and self.baseBonus.crystalRefineMult) or 1.0)
                    extraMult = extraMult * ((self.baseBonus and self.baseBonus.nuclearMult) or 1.0)
                end
                local toConsume = math.min(rawAmt, cfg.processRate * self.refineryMult * extraMult * dt)
                if toConsume > 0 then
                    self.resources[raw] = rawAmt - toConsume
                    local cap = self.caps[cfg.ref] or 99999
                    self.resources[cfg.ref] = math.min(cap,
                        (self.resources[cfg.ref] or 0) + toConsume / cfg.ratio)
                end
            end
        end
    end
end

--- 设置互换速率（正=矿→能量，负=能→矿，0=关闭）
function ResourceManager:setConvertRate(rate)
    self.convertRate = math.max(-20, math.min(20, rate))
end

--- 获取互换对显示速率（用于 UI 展示净变化）
--- 返回 { mineralsPerSec, energyPerSec }（已含互换影响）
function ResourceManager:getConvertDisplay()
    local r = self.convertRate
    if r > 0 then
        return -r, r * CONVERT_RATIO   -- 矿石减少，能量增加
    elseif r < 0 then
        return (-r) / CONVERT_RATIO, r * CONVERT_RATIO  -- 矿石增加，能量减少
    end
    return 0, 0
end

function ResourceManager:canAfford(cost)
    for res, amt in pairs(cost) do
        if (self.resources[res] or 0) < amt then return false end
    end
    return true
end

function ResourceManager:spend(cost)
    if not self:canAfford(cost) then return false end
    for res, amt in pairs(cost) do
        self.resources[res] = (self.resources[res] or 0) - amt
    end
    return true
end

function ResourceManager:add(resType, amount)
    if self.resources[resType] ~= nil then
        local cap = self.caps[resType] or 99999
        self.resources[resType] = math.min(cap, self.resources[resType] + amount)
    end
end

-- 资源互换：从 fromRes 消耗 EXCHANGE_AMOUNT，换取 toRes
-- 返回 ok, gain（实际获得数量）或 false, reason
function ResourceManager:exchange(fromRes, toRes)
    local rates = EXCHANGE_RATES[fromRes]
    if not rates or not rates[toRes] then
        return false, "不支持该互换方向"
    end
    local have = self.resources[fromRes] or 0
    if have < EXCHANGE_AMOUNT then
        return false, RES_LABELS[fromRes] .. "不足（需要 " .. EXCHANGE_AMOUNT .. "）"
    end
    local gain = math.floor(EXCHANGE_AMOUNT * rates[toRes])
    self.resources[fromRes] = have - EXCHANGE_AMOUNT
    local cap = self.caps[toRes] or 99999
    self.resources[toRes] = math.min(cap, (self.resources[toRes] or 0) + gain)
    return true, gain
end

function ResourceManager:fmtCost(cost)
    local parts = {}
    for _, res in ipairs(RES_ORDER) do
        local amt = cost[res]
        if amt and amt > 0 then
            parts[#parts+1] = RES_LABELS[res] .. "×" .. amt
        end
    end
    return table.concat(parts, " ")
end

-- ============================================================================
-- BuildingSystem
-- ============================================================================
local BuildingSystem = {}
BuildingSystem.__index = BuildingSystem

function BuildingSystem.new(rm)
    return setmetatable({ rm=rm }, BuildingSystem)
end

function BuildingSystem:getUpgradeCost(key, level)
    local bd   = BUILDINGS[key]
    local cost = {}
    local m    = bd.upgradeK ^ level   -- H1: math.pow 在 Lua 5.3+ 已移除，改用 ^ 运算符
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    for res, base in pairs(bd.cost) do
        cost[res] = math.max(1, math.floor(base * m * bcm))
    end
    return cost
end

--- P1-3: 获取建筑显示名称（供 UI 渲染队列条目时使用）
function BuildingSystem:getBuildingName(key)
    return BUILDINGS[key] and BUILDINGS[key].name or key
end

--- P2-3: 获取建筑类型可用专精列表
function BuildingSystem:getSpecsForBuilding(key)
    return BUILDING_SPECS[key] or {}
end

--- P2-3: 查找专精定义（按建筑类型 key + 专精 key）
function BuildingSystem:findSpec(bKey, specKey)
    for _, sp in ipairs(BUILDING_SPECS[bKey] or {}) do
        if sp.key == specKey then return sp end
    end
    return nil
end

--- P2-3: 重算单个建筑产量（科技倍率 + 专精效果）
--- 会先撤销旧贡献再写入新值到 rm.rates
function BuildingSystem:_recalcBuildingProd(b, planet)
    local bd = BUILDINGS[b.key]
    if not bd then return end
    -- 撤销旧产量贡献
    for res, old in pairs(b.currentProd or {}) do
        self.rm.rates[res] = math.max(0, (self.rm.rates[res] or 0) - old)
    end
    b.currentProd = {}
    -- 科技倍率
    local techMult = 1.0
    if planet.appliedTechs then
        for techId in pairs(planet.appliedTechs) do
            local bonus = TECHS[techId] and TECHS[techId].bonus
            if bonus and bonus.building == b.key then
                techMult = bonus.prodMult; break
            end
        end
    end
    -- 专精效果
    local specEffect = nil
    if b.spec then
        local sp = self:findSpec(b.key, b.spec)
        if sp then specEffect = sp.effect end
    end
    for res, rate in pairs(bd.prod) do
        local val = math.floor(rate * b.level * techMult)
        if specEffect then
            local mKey = res .. "Mult"
            local fKey = res .. "Flat"
            if specEffect[mKey] then val = math.floor(val * specEffect[mKey]) end
            if specEffect[fKey] then val = val + specEffect[fKey] end
        end
        b.currentProd[res] = math.max(0, val)
        self.rm.rates[res] = (self.rm.rates[res] or 0) + b.currentProd[res]
    end
end

--- P2-3: 为建筑设置专精（消耗晶石 SPEC_COST）
function BuildingSystem:setSpec(bldIdx, planet, specKey)
    local b = planet.buildings[bldIdx]
    if not b then return false, "无效建筑" end
    if b.level < 3 then return false, "需要 Lv.3+" end
    local sp = self:findSpec(b.key, specKey)
    if not sp then return false, "未知专精" end
    if b.spec == specKey then return false, "已选择此专精" end
    if not self.rm:canAfford({crystal = SPEC_COST}) then
        return false, string.format("晶石不足（需 %d）", SPEC_COST)
    end
    self.rm:spend({crystal = SPEC_COST})
    b.spec = specKey
    self:_recalcBuildingProd(b, planet)
    return true, sp.name .. " 已激活"
end

-- P1-3: 建造队列最大容量
local BUILD_QUEUE_MAX = 3

--- 检查是否可以新建（支持队列：constructing 满但 queue 未满也可以）
function BuildingSystem:canBuild(key, planet)
    if not planet.colonized  then return false, "尚未殖民" end
    -- P1-3: 允许队列排队，队列满时才拒绝
    local qLen = planet.buildQueue and #planet.buildQueue or 0
    if planet.constructing and qLen >= BUILD_QUEUE_MAX then return false, "队列已满" end
    if #planet.buildings + (planet.constructing and 1 or 0) + qLen >= 10 then return false, "槽位已满" end
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    local cost = {}
    for res, base in pairs(BUILDINGS[key].cost) do
        cost[res] = math.max(1, math.floor(base * bcm))
    end
    if not self.rm:canAfford(cost) then return false, "资源不足" end
    return true, ""
end

function BuildingSystem:build(key, planet)
    local ok, reason = self:canBuild(key, planet)
    if not ok then return false, reason end
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    local cost = {}
    for res, base in pairs(BUILDINGS[key].cost) do
        cost[res] = math.max(1, math.floor(base * bcm))
    end
    self.rm:spend(cost)
    local bd = BUILDINGS[key]
    local bm = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt = math.max(1, math.floor(bd.buildTime * bm))
    local job = {
        key=key, progress=0,
        totalTime=bt, remaining=bt,
        level=1, isUpgrade=false, targetIdx=nil
    }
    -- P1-3: 若当前没有建造任务，直接开始；否则入队
    if not planet.constructing then
        planet.constructing = job
    else
        planet.buildQueue = planet.buildQueue or {}
        planet.buildQueue[#planet.buildQueue + 1] = job
    end
    return true, ""
end

--- 检查升级（canUpgrade 保持单槽校验，允许排队时调整）
function BuildingSystem:canUpgrade(bldIdx, planet)
    local b    = planet.buildings[bldIdx]
    if not b then return false, "无效建筑" end
    -- P1-3: 同 canBuild，允许队列排队
    local qLen = planet.buildQueue and #planet.buildQueue or 0
    if planet.constructing and qLen >= BUILD_QUEUE_MAX then return false, "队列已满" end
    local cost = self:getUpgradeCost(b.key, b.level)
    if not self.rm:canAfford(cost) then return false, "资源不足" end
    return true, ""
end

function BuildingSystem:upgrade(bldIdx, planet)
    local ok, reason = self:canUpgrade(bldIdx, planet)
    if not ok then return false, reason end
    local b    = planet.buildings[bldIdx]
    local cost = self:getUpgradeCost(b.key, b.level)
    self.rm:spend(cost)
    local bd = BUILDINGS[b.key]
    local bm = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt = math.max(1, math.floor(bd.buildTime * b.level * bm))
    local job = {
        key=b.key, progress=0,
        totalTime=bt, remaining=bt,
        level=b.level+1, isUpgrade=true, targetIdx=bldIdx
    }
    -- P1-3: 若当前没有建造任务，直接开始；否则入队
    if not planet.constructing then
        planet.constructing = job
    else
        planet.buildQueue = planet.buildQueue or {}
        planet.buildQueue[#planet.buildQueue + 1] = job
    end
    return true, ""
end

function BuildingSystem:applyTechBonus(planet, techId)
    local bonus = TECHS[techId] and TECHS[techId].bonus
    if not bonus then return end
    -- 去重：每个行星每个科技只应用一次
    planet.appliedTechs = planet.appliedTechs or {}
    if planet.appliedTechs[techId] then return end
    planet.appliedTechs[techId] = true

    for _, b in ipairs(planet.buildings) do
        if b.key == bonus.building then
            local bd = BUILDINGS[b.key]
            for res, baseProd in pairs(bd.prod) do
                -- 正确公式：产量 = 基础 × 等级 × 科技倍率（平乘，非指数）
                self.rm.rates[res] = math.max(0, (self.rm.rates[res] or 0) - (b.currentProd[res] or 0))
                b.currentProd[res] = math.floor(baseProd * b.level * bonus.prodMult)
                self.rm.rates[res] = (self.rm.rates[res] or 0) + b.currentProd[res]
            end
        end
    end
end

function BuildingSystem:update(dt, planet)
    if not planet.constructing then return nil end
    local job = planet.constructing
    job.remaining = job.remaining - dt
    job.progress  = 1.0 - math.max(0, job.remaining) / job.totalTime
    if job.remaining <= 0 then
        local completed = job.key
        if not job.isUpgrade then
            -- 新建
            local bd  = BUILDINGS[job.key]
            local bld = { key=job.key, name=bd.name, level=1, currentProd={} }
            for res, rate in pairs(bd.prod) do
                bld.currentProd[res] = rate
                self.rm.rates[res] = (self.rm.rates[res] or 0) + rate
            end
            planet.buildings[#planet.buildings+1] = bld
        else
            -- 升级
            local b   = planet.buildings[job.targetIdx]
            if b then
                b.level = job.level
                self:_recalcBuildingProd(b, planet)  -- P2-3: 含科技+专精效果
            end
        end
        planet.constructing = nil
        -- P1-3: 自动出队下一个任务
        if planet.buildQueue and #planet.buildQueue > 0 then
            planet.constructing = table.remove(planet.buildQueue, 1)
        end
        return completed
    end
    return nil
end

-- P1-3: 取消队列中某个建造任务（退还资源，index 为 buildQueue 中的 1-based 位置）
function BuildingSystem:cancelQueued(qIdx, planet)
    if not planet.buildQueue then return false end
    local job = planet.buildQueue[qIdx]
    if not job then return false end
    -- 退还资源
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    local bd   = BUILDINGS[job.key]
    if bd then
        local refund = {}
        if not job.isUpgrade then
            for res, base in pairs(bd.cost) do
                refund[res] = math.max(1, math.floor(base * bcm))
            end
        else
            -- 升级退还：getUpgradeCost 需要当前等级，job.level-1 是原始等级
            local origLevel = job.level - 1
            for res, base in pairs(bd.cost) do
                refund[res] = math.max(1, math.floor(base * origLevel * bcm))
            end
        end
        for res, amt in pairs(refund) do self.rm:add(res, amt) end
    end
    table.remove(planet.buildQueue, qIdx)
    return true
end

-- ============================================================================
-- ResearchSystem
-- ============================================================================
local ResearchSystem = {}
ResearchSystem.__index = ResearchSystem

function ResearchSystem.new(rm, bs)
    local self = setmetatable({ rm=rm, bs=bs, planetGetter=nil }, ResearchSystem)
    self.unlocked = {}
    self.active   = nil
    return self
end

--- 设置动态行星列表获取函数（每次科技完成时调用，确保包含新殖民的行星）
function ResearchSystem:setPlanetGetter(fn)
    self.planetGetter = fn
end

function ResearchSystem:canResearch(id)
    local t = TECHS[id]
    if not t then return false, "未知科技" end
    if self.unlocked[id] then return false, "已完成" end
    if self.active        then return false, "研究中" end
    for _, pre in ipairs(t.prereqs) do
        if not self.unlocked[pre] then return false, "需先完成: " .. TECHS[pre].name end
    end
    -- P1-1: 互斥分组检查（同组内已解锁其他科技则封锁）
    if t.exclusiveGroup then
        for otherId, otherT in pairs(TECHS) do
            if otherId ~= id and otherT.exclusiveGroup == t.exclusiveGroup
               and self.unlocked[otherId] then
                return false, "与 " .. otherT.name .. " 互斥（只能选一）"
            end
        end
    end
    if not self.rm:canAfford(t.cost) then return false, "资源不足" end
    return true, ""
end

--- P1-1: 检查科技是否被互斥锁定（已有同组其他科技解锁）
---@param id string
---@return boolean  true = 被互斥封锁
function ResearchSystem:isExcluded(id)
    local t = TECHS[id]
    if not t or not t.exclusiveGroup then return false end
    if self.unlocked[id] then return false end
    for otherId, otherT in pairs(TECHS) do
        if otherId ~= id and otherT.exclusiveGroup == t.exclusiveGroup
           and self.unlocked[otherId] then
            return true
        end
    end
    return false
end

-- 前置科技是否全部完成（不检查资源）
function ResearchSystem:prereqsMet(id)
    local t = TECHS[id]
    if not t then return false end
    if self.unlocked[id] then return false end
    if self.active        then return false end
    for _, pre in ipairs(t.prereqs) do
        if not self.unlocked[pre] then return false end
    end
    return true
end

function ResearchSystem:start(id)
    local ok, reason = self:canResearch(id)
    if not ok then return false, reason end
    self.rm:spend(TECHS[id].cost)
    self.active = {
        id=id,
        remaining=TECHS[id].time,
        totalTime=TECHS[id].time,
        progress=0
    }
    return true, ""
end

function ResearchSystem:update(dt)
    if not self.active then return nil end
    -- S1 QUANTUM_CORE: researchSpeedMult 与科研中心的 researchMult 叠乘
    local speedMult = ((self.rm.baseBonus and self.rm.baseBonus.researchMult) or 1.0)
                    * ((self.rm.baseBonus and self.rm.baseBonus.researchSpeedMult) or 1.0)
    self.active.remaining = self.active.remaining - dt * speedMult
    self.active.progress  = 1.0 - math.max(0, self.active.remaining) / self.active.totalTime
    if self.active.remaining <= 0 then
        local id = self.active.id
        self.unlocked[id] = true
        self.active = nil
        -- 通过 getter 动态获取所有行星（包含最新殖民的）并应用科技加成
        if self.planetGetter then
            local planets = self.planetGetter()
            for _, p in ipairs(planets) do
                if p.colonized then
                    self.bs:applyTechBonus(p, id)
                end
            end
        end
        -- 应用特殊科技效果到 baseBonus
        local bonus = TECHS[id] and TECHS[id].bonus
        if bonus then
            if bonus.fleetSpeedMult then
                -- WARP_DRIVE：舰队速度加成（存入 baseBonus 供 FleetManager 读取）
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.fleetSpeedMult = (self.rm.baseBonus.fleetSpeedMult or 1.0) * bonus.fleetSpeedMult
                print("[Research] 曲速引擎激活：舰队速度×" .. tostring(self.rm.baseBonus.fleetSpeedMult))
            end
            if bonus.shieldBonus then
                -- SHIELD_REINFORCE：护盾加成（存入 baseBonus 供战斗系统读取）
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldBonus  = (self.rm.baseBonus.shieldBonus  or 0) + bonus.shieldBonus
                self.rm.baseBonus.defenseBonus = (self.rm.baseBonus.defenseBonus or 0) + bonus.defenseBonus
                print("[Research] 护盾强化激活：护盾+" .. tostring(bonus.shieldBonus))
            end
            -- P1-1: NOVA_CANNON —— AOE 半径倍增 + 战斗开场技能充能
            if bonus.aoeRadiusMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.aoeRadiusMult = (self.rm.baseBonus.aoeRadiusMult or 1.0) * bonus.aoeRadiusMult
                print("[Research] 新星炮激活：AOE半径×" .. tostring(self.rm.baseBonus.aoeRadiusMult))
            end
            if bonus.battleStartSkillCharge then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.battleStartSkillCharge = (self.rm.baseBonus.battleStartSkillCharge or 0) + bonus.battleStartSkillCharge
                print("[Research] 新星炮激活：每波战斗开始额外技能充能+" .. tostring(bonus.battleStartSkillCharge))
            end
            -- P1-1: FORTRESS_PROTOCOL —— 护盾上限倍增 + 护盾回复
            if bonus.shieldMaxMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldMaxMult = (self.rm.baseBonus.shieldMaxMult or 1.0) * bonus.shieldMaxMult
                print("[Research] 要塞协议激活：护盾上限×" .. tostring(self.rm.baseBonus.shieldMaxMult))
            end
            if bonus.shieldRegenPct then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldRegenPct = (self.rm.baseBonus.shieldRegenPct or 0) + bonus.shieldRegenPct
                print("[Research] 要塞协议激活：战斗中护盾每10s回复" .. tostring(bonus.shieldRegenPct * 100) .. "%")
            end
            -- P1-3: VOID_ANCHOR —— 战舰攻击倍率 + 敌方减速系数
            if bonus.enemySpeedDebuff then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.enemySpeedDebuff = (self.rm.baseBonus.enemySpeedDebuff or 1.0) * bonus.enemySpeedDebuff
                print("[Research] 虚空锚定激活：敌方舰队速度×" .. tostring(self.rm.baseBonus.enemySpeedDebuff))
            end
            -- P1-3: STELLAR_SYNC —— 全局产出倍率
            if bonus.globalProdMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.globalProdMult = (self.rm.baseBonus.globalProdMult or 1.0) * bonus.globalProdMult
                print("[Research] 星际同步激活：全局产出×" .. tostring(self.rm.baseBonus.globalProdMult))
            end
        end
        print("[Research] 完成: " .. TECHS[id].name)
        return id
    end
    return nil
end

-- ============================================================================
-- MarketSystem
-- ============================================================================
local BASE_RATES = {
    metal   = { buy=2.0,  sell=0.5 },
    esource = { buy=3.0,  sell=1.0 },
    nuclear = { buy=10.0, sell=4.0 },
}

local MarketSystem = {}
MarketSystem.__index = MarketSystem

function MarketSystem.new(rm)
    local self = setmetatable({ rm=rm, timer=0 }, MarketSystem)
    self.rates      = {}
    self.history    = {}  -- 记录近期买价快照（最多6条）
    self.priceFlash = {}  -- P2-3: 价格大幅波动提示计时器（秒）
    for res, r in pairs(BASE_RATES) do
        self.rates[res]      = { buy=r.buy, sell=r.sell }
        self.history[res]    = { r.buy }  -- 初始时放一条基准价
        self.priceFlash[res] = 0
    end
    return self
end

function MarketSystem:update(dt)
    -- P2-3: 衰减所有 priceFlash 计时器
    for res, _ in pairs(self.priceFlash) do
        if self.priceFlash[res] > 0 then
            self.priceFlash[res] = math.max(0, self.priceFlash[res] - dt)
        end
    end

    self.timer = self.timer + dt
    if self.timer >= 12 then   -- 每12秒波动一次，让玩家有感知
        self.timer = 0
        for res, r in pairs(self.rates) do
            local prevBuy = r.buy   -- P2-3: 记录变动前价格
            -- 记录历史（买价快照）
            local h = self.history[res]
            h[#h+1] = r.buy
            if #h > 6 then table.remove(h, 1) end
            -- 滑动波动：当前价 × 随机因子，带均值回归避免无限漂移
            local change   = 1.0 + (math.random() * 0.5 - 0.25)   -- ±25%
            local base     = BASE_RATES[res]
            local revert   = 0.25   -- 25% 拉力归向基准价
            r.buy  = math.max(base.buy  * 0.4, r.buy  * change * (1 - revert) + base.buy  * revert)
            r.sell = math.max(base.sell * 0.4, r.sell * change * (1 - revert) + base.sell * revert)
            -- 卖价始终 ≤ 买价的 60%（交易所差价）
            r.sell = math.min(r.sell, r.buy * 0.6)
            -- P2-3: 变动 > 15% 触发价格闪烁提示（8秒）
            local changePct = math.abs(r.buy - prevBuy) / prevBuy
            if changePct >= 0.15 then
                self.priceFlash[res] = 8.0
            end
        end
    end
end

--- 获取某资源的价格趋势符号（"↑" / "↓" / "→"）
function MarketSystem:getTrend(resType)
    local h = self.history[resType]
    if not h or #h < 2 then return "→" end
    local last = h[#h]
    local prev = h[#h - 1]
    if last > prev * 1.05 then return "↑"
    elseif last < prev * 0.95 then return "↓"
    else return "→" end
end

function MarketSystem:sell(resType, amount)
    local r = self.rates[resType]
    if not r then return false, "不可交易" end
    if (self.rm.resources[resType] or 0) < amount then return false, "资源不足" end
    self.rm.resources[resType] = self.rm.resources[resType] - amount
    self.rm:add("credits", amount * r.sell)
    return true, math.floor(amount * r.sell)
end

function MarketSystem:buy(resType, amount)
    local r = self.rates[resType]
    if not r then return false, "不可交易" end
    local cost = amount * r.buy
    if not self.rm:canAfford({credits=cost}) then return false, "星币不足" end
    self.rm:spend({credits=cost})
    self.rm:add(resType, amount)
    return true, math.floor(cost)
end

-- ============================================================================
-- PlayerProfile
-- ============================================================================
local PlayerProfile = {}
PlayerProfile.__index = PlayerProfile

function PlayerProfile.new()
    local self = setmetatable({}, PlayerProfile)
    local n = tostring(GetLoginName() or "")
    self.name      = (n ~= "" and n ~= "(?)") and n or "玩家"
    self.level     = 1
    self.exp       = 0
    self.rankIdx   = 1
    self.rank      = RANKS[1]
    self.alliance  = "无联盟"
    self.colonized = 0
    self.battles   = 0
    self.wins      = 0
    return self
end

-- 等级奖励表：每级给予的资源奖励
local LEVEL_REWARDS = {
    -- 每隔5级有大奖励，其余给小奖励
    default  = { metal=500,  esource=300,  nuclear=50  },
    milestone= { metal=2000, esource=1000, nuclear=200 },  -- 5/10/15/20级
}

function PlayerProfile:addExp(amount)
    self.exp = self.exp + amount
    local rewards = nil
    while self.exp >= self.level * EXP_PER_LEVEL do
        self.exp   = self.exp - self.level * EXP_PER_LEVEL
        self.level = self.level + 1
        -- 5的倍数为里程碑大奖励，否则普通奖励
        local r = (self.level % 5 == 0) and LEVEL_REWARDS.milestone or LEVEL_REWARDS.default
        -- 累计奖励（可能连续升多级）
        if not rewards then
            rewards = { metal=0, esource=0, nuclear=0 }
        end
        rewards.metal   = rewards.metal   + r.metal
        rewards.esource = rewards.esource + r.esource
        rewards.nuclear = rewards.nuclear + r.nuclear
    end
    if rewards then
        local idx    = math.min(math.floor(self.level / 5) + 1, #RANKS)  -- L1: (level-1)/5 偏差1级，改为 level/5，Lv5晋升第2阶
        self.rankIdx = idx
        self.rank    = RANKS[idx]
        print("[Profile] 晋升! Lv." .. self.level .. "  " .. self.rank)
        return true, self.level, self.rank, rewards
    end
    return false
end

-- ============================================================================
-- ShipProductionQueue (造船厂队列)
-- ============================================================================
local ShipProductionQueue = {}
ShipProductionQueue.__index = ShipProductionQueue

function ShipProductionQueue.new(rm)
    return setmetatable({ rm=rm, items={}, timer=0 }, ShipProductionQueue)
end

function ShipProductionQueue:canQueue(shipType, planet)
    if not planet.colonized then return false, "未殖民" end
    local hasShipyard = false
    -- 检查行星建筑
    if planet.buildings then
        for _, b in ipairs(planet.buildings) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    -- 检查基地模块（isBase 标记）
    if not hasShipyard and planet.isBase and planet.modules then
        for _, b in ipairs(planet.modules) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    if not hasShipyard then return false, "需建造造船厂" end
    if not self.rm:canAfford(SHIP_COSTS[shipType]) then return false, "资源不足" end
    return true, ""
end

function ShipProductionQueue:queue(shipType, planet)
    local ok, reason = self:canQueue(shipType, planet)
    if not ok then return false, reason end
    self.rm:spend(SHIP_COSTS[shipType])
    local buildTime = SHIP_TYPES[shipType].buildTime
    self.items[#self.items+1] = {
        shipType  = shipType,
        planet    = planet,
        remaining = buildTime,
        totalTime = buildTime,
        progress  = 0,
    }
    return true, ""
end

-- P2-3: 取消队列中第 index 项（退还已花费资源）
function ShipProductionQueue:cancel(index)
    if index < 1 or index > #self.items then return false end
    local job  = self.items[index]
    local cost = SHIP_COSTS[job.shipType]
    if cost and self.rm then
        for res, amt in pairs(cost) do
            self.rm:add(res, amt)
        end
    end
    table.remove(self.items, index)
    return true
end

-- P2-3: 将队列中第 index 项上移一位（index 必须 >= 2）
function ShipProductionQueue:promote(index)
    if index <= 1 or index > #self.items then return false end
    self.items[index-1], self.items[index] = self.items[index], self.items[index-1]
    return true
end

function ShipProductionQueue:update(dt)
    if #self.items == 0 then return nil end
    local job = self.items[1]
    local shipMult = (self.rm.baseBonus and self.rm.baseBonus.shipyardMult) or 1.0
    job.remaining = job.remaining - dt * shipMult
    job.progress  = 1.0 - math.max(0, job.remaining) / job.totalTime
    if job.remaining <= 0 then
        local completed = job
        table.remove(self.items, 1)
        print("[Shipyard] 完成生产: " .. completed.shipType)
        return completed
    end
    return nil
end

-- ============================================================================
-- FleetManager  -- 编队系统（最多 MAX_FLEETS 个编队，初始给 5 个）
-- ============================================================================
local MAX_FLEET_SLOTS  = 10   -- 理论上限
local INIT_FLEET_COUNT = 5    -- 玩家初始解锁编队数

local FleetManager = {}
FleetManager.__index = FleetManager

function FleetManager.new()
    local self = setmetatable({}, FleetManager)
    self.maxFleets = INIT_FLEET_COUNT   -- 已解锁编队数（可扩展）
    self.fleets    = {}                  -- 编队列表，索引 1~maxFleets
    self.reserve   = {}                  -- 储备池 { [shipType]=count }
    for i = 1, INIT_FLEET_COUNT do
        self.fleets[i] = {
            id       = i,
            name     = "第 " .. i .. " 编队",
            ships    = {},   -- { shipType, count } 列表（同类型合并显示）
            deployedCount = 0,  -- 已在战场的数量（战斗时更新）
        }
    end
    return self
end

--- 造船完成 → 进入储备池
function FleetManager:addToReserve(shipType)
    self.reserve[shipType] = (self.reserve[shipType] or 0) + 1
end

--- 从储备池取一艘 → 加入指定编队
function FleetManager:assignFromReserve(shipType, fleetId)
    local n = self.reserve[shipType] or 0
    if n <= 0 then return false, "储备中没有该舰船" end
    local ok, reason = self:addShip(fleetId, shipType)
    if not ok then return false, reason end
    self.reserve[shipType] = n - 1
    if self.reserve[shipType] <= 0 then self.reserve[shipType] = nil end
    return true
end

--- 储备池总数
function FleetManager:reserveTotal()
    local n = 0
    for _, c in pairs(self.reserve) do n = n + c end
    return n
end

--- 向编队添加一艘舰船（建造完成时调用）
--- 返回 true/false
local MAX_SHIPS_PER_FLEET = 10  -- 每编队最多舰船数

function FleetManager:addShip(fleetId, shipType)
    local fl = self.fleets[fleetId]
    if not fl then return false, "编队不存在" end
    -- 检查编队上限
    if self:totalShips(fleetId) >= MAX_SHIPS_PER_FLEET then
        return false, "编队已满（上限 " .. MAX_SHIPS_PER_FLEET .. " 艘）"
    end
    -- 查找同类型条目
    for _, entry in ipairs(fl.ships) do
        if entry.shipType == shipType then
            entry.count = entry.count + 1
            return true
        end
    end
    fl.ships[#fl.ships+1] = { shipType=shipType, count=1 }
    return true
end

--- 从编队移除一艘舰船（通常在舰船阵亡时调用）
function FleetManager:removeShip(fleetId, shipType)
    local fl = self.fleets[fleetId]
    if not fl then return end
    for i, entry in ipairs(fl.ships) do
        if entry.shipType == shipType then
            entry.count = entry.count - 1
            if entry.count <= 0 then table.remove(fl.ships, i) end
            return
        end
    end
end

--- 移动舰船：将 shipType 从 srcFleet 移到 dstFleet（1 艘）
function FleetManager:moveShip(srcId, dstId, shipType)
    if srcId == dstId then return false, "同一编队" end
    local src = self.fleets[srcId]
    local dst = self.fleets[dstId]
    if not src or not dst then return false, "编队不存在" end
    -- 检查来源是否有该舰
    local found = false
    for _, e in ipairs(src.ships) do
        if e.shipType == shipType and e.count > 0 then found = true; break end
    end
    if not found then return false, "编队中没有该舰船" end
    self:removeShip(srcId, shipType)
    self:addShip(dstId, shipType)
    return true
end

--- 获取编队的舰船总数
function FleetManager:totalShips(fleetId)
    local fl = self.fleets[fleetId]
    if not fl then return 0 end
    local n = 0
    for _, e in ipairs(fl.ships) do n = n + e.count end
    return n
end

--- 解锁更多编队槽位（逐步 +1，内部兼容接口）
function FleetManager:unlock()
    if self.maxFleets >= MAX_FLEET_SLOTS then return false, "已达上限" end
    self.maxFleets = self.maxFleets + 1
    local i = self.maxFleets
    self.fleets[i] = {
        id=i, name="第 " .. i .. " 编队", ships={}, deployedCount=0
    }
    return true
end

--- 根据基地模块效果重新设定编队上限（applyBaseModuleEffects 调用）
--- target：期望的 maxFleets 值，自动 clamp 到 [INIT_FLEET_COUNT, MAX_FLEET_SLOTS]
function FleetManager:setMaxFleets(target)
    local clamped = math.max(INIT_FLEET_COUNT, math.min(MAX_FLEET_SLOTS, target))
    if clamped == self.maxFleets then return end
    self.maxFleets = clamped
    -- 补全缺少的编队槽位（仅增加，不删除已有编队的舰船）
    for i = #self.fleets + 1, self.maxFleets do
        self.fleets[i] = {
            id=i, name="第 " .. i .. " 编队", ships={}, deployedCount=0
        }
    end
end

-- ============================================================================
-- BaseBuildingSystem  —— 星航基地独立建造系统
-- ============================================================================
local BaseBuildingSystem = {}
BaseBuildingSystem.__index = BaseBuildingSystem

function BaseBuildingSystem.new(rm)
    return setmetatable({ rm = rm }, BaseBuildingSystem)
end

function BaseBuildingSystem:getUpgradeCost(key, level)
    local mod = BASE_MODULES[key]
    if not mod then return {} end
    local k = mod.upgradeK or 1.5
    local cost = {}
    for res, base in pairs(mod.cost) do
        cost[res] = math.floor(base * (k ^ level))
    end
    return cost
end

function BaseBuildingSystem:canBuild(key, base)
    if base.constructing            then return false, "队列忙碌" end
    local maxSlots = BaseModuleSlots(base.coreLevel)
    if #base.buildings >= maxSlots  then return false, "槽位已满" end
    -- 同类模块只能建一个
    for _, b in ipairs(base.buildings) do
        if b.key == key then return false, "已安装" end
    end
    -- 核心等级校验
    local reqLv = BASE_MODULE_UNLOCK_LEVEL[key] or 1
    local curLv = base.coreLevel or 1
    if curLv < reqLv then
        return false, "需核心 Lv." .. reqLv
    end
    if not self.rm:canAfford(BASE_MODULES[key].cost) then return false, "资源不足" end
    return true, ""
end

--- 检查是否可升级核心等级
function BaseBuildingSystem:canUpgradeCore(base)
    local lv = base.coreLevel or 1
    if lv >= BASE_CORE_MAX_LEVEL then return false, "已达最高等级" end
    if base.constructing          then return false, "队列忙碌" end
    local cost = BASE_CORE_UPGRADE_COSTS[lv]
    if not cost                   then return false, "无升级配置" end
    -- S1 QUANTUM_CORE: 核心升级费用折扣
    local costMult = (self.rm.baseBonus and self.rm.baseBonus.coreUpgradeCostMult) or 1.0
    -- 提取资源部分（排除 buildTime），并应用折扣
    local resCost = {}
    for k, v in pairs(cost) do
        if k ~= "buildTime" then resCost[k] = math.max(1, math.floor(v * costMult)) end
    end
    if not self.rm:canAfford(resCost) then return false, "资源不足" end
    return true, "", resCost
end

--- 执行核心等级升级（进入建造队列）
function BaseBuildingSystem:upgradeCore(base)
    local ok, reason, resCost = self:canUpgradeCore(base)
    if not ok then return false, reason end
    local lv   = base.coreLevel or 1
    local cost = BASE_CORE_UPGRADE_COSTS[lv]
    self.rm:spend(resCost)
    base.constructing = {
        key       = "__CORE_UPGRADE__",
        progress  = 0,
        totalTime = cost.buildTime,
        remaining = cost.buildTime,
        level     = lv + 1,
        isUpgrade = false,
        isCoreUpgrade = true,
    }
    return true, ""
end

function BaseBuildingSystem:canUpgrade(bldIdx, base)
    local b = base.buildings[bldIdx]
    if not b then return false, "无效模块" end
    if base.constructing then return false, "队列忙碌" end
    local cost = self:getUpgradeCost(b.key, b.level)
    if not self.rm:canAfford(cost) then return false, "资源不足" end
    return true, ""
end

function BaseBuildingSystem:build(key, base)
    local ok, reason = self:canBuild(key, base)
    if not ok then return false, reason end
    self.rm:spend(BASE_MODULES[key].cost)
    local mod = BASE_MODULES[key]
    local bm  = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt  = math.max(1, math.floor(mod.buildTime * bm))
    base.constructing = {
        key = key, progress = 0,
        totalTime = bt, remaining = bt,
        level = 1, isUpgrade = false
    }
    return true, ""
end

function BaseBuildingSystem:upgrade(bldIdx, base)
    local ok, reason = self:canUpgrade(bldIdx, base)
    if not ok then return false, reason end
    local b    = base.buildings[bldIdx]
    local cost = self:getUpgradeCost(b.key, b.level)
    self.rm:spend(cost)
    local mod  = BASE_MODULES[b.key]
    local bm   = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt   = math.max(1, math.floor(mod.buildTime * (mod.upgradeK ^ b.level) * bm))
    base.constructing = {
        key = b.key, progress = 0,
        totalTime = bt, remaining = bt,
        level = b.level + 1, isUpgrade = true, targetIdx = bldIdx
    }
    return true, ""
end

--- 返回完成的模块 key（完成时），否则返回 nil
function BaseBuildingSystem:update(dt, base)
    if not base.constructing then return nil end
    local job = base.constructing
    job.remaining = job.remaining - dt
    job.progress  = 1 - math.max(0, job.remaining / job.totalTime)
    if job.remaining <= 0 then
        local doneKey = job.key
        if job.isCoreUpgrade then
            -- 核心等级升级完成
            base.coreLevel = job.level
        elseif job.isUpgrade then
            base.buildings[job.targetIdx].level = job.level
        else
            base.buildings[#base.buildings + 1] = {
                key = job.key, name = BASE_MODULES[job.key].name, level = 1
            }
        end
        base.constructing = nil
        return doneKey
    end
    return nil
end

-- ============================================================================
-- 序列化 / 反序列化（云存档支持）
-- ============================================================================

--- ResourceManager: 序列化当前资源与产出速率
function ResourceManager:serialize()
    return {
        resources = {
            minerals   = math.floor(self.resources.minerals   or 0),
            energy     = math.floor(self.resources.energy     or 0),
            crystal    = math.floor(self.resources.crystal    or 0),
            metal      = math.floor(self.resources.metal      or 0),
            esource    = math.floor(self.resources.esource    or 0),
            nuclear    = math.floor(self.resources.nuclear    or 0),
            population = math.floor(self.resources.population or 0),
            credits    = math.floor(self.resources.credits    or 0),
        }
    }
end

--- ResourceManager: 从存档恢复资源（产出速率由建筑重建后自动恢复）
function ResourceManager:deserialize(data)
    if not data or not data.resources then return end
    for k, v in pairs(data.resources) do
        if self.resources[k] ~= nil then
            self.resources[k] = v
        end
    end
end

--- ResearchSystem: 序列化已解锁科技和当前研究进度
function ResearchSystem:serialize()
    local unlockedList = {}
    for id, _ in pairs(self.unlocked) do
        unlockedList[#unlockedList + 1] = id
    end
    local active = nil
    if self.active then
        active = {
            id        = self.active.id,
            remaining = self.active.remaining,
            totalTime = self.active.totalTime,
        }
    end
    return { unlocked = unlockedList, active = active }
end

--- ResearchSystem: 从存档恢复
function ResearchSystem:deserialize(data)
    if not data then return end
    self.unlocked = {}
    if data.unlocked then
        for _, id in ipairs(data.unlocked) do
            self.unlocked[id] = true
        end
    end
    self.active = nil
    if data.active then
        self.active = {
            id        = data.active.id,
            remaining = data.active.remaining,
            totalTime = data.active.totalTime,
            progress  = 1.0 - (data.active.remaining / math.max(1, data.active.totalTime)),
        }
    end
end

--- PlayerProfile: 序列化
function PlayerProfile:serialize()
    return {
        level     = self.level,
        exp       = self.exp,
        rankIdx   = self.rankIdx,
        colonized = self.colonized,
        battles   = self.battles,
        wins      = self.wins,
    }
end

--- PlayerProfile: 从存档恢复
function PlayerProfile:deserialize(data)
    if not data then return end
    self.level     = data.level     or 1
    self.exp       = data.exp       or 0
    self.rankIdx   = data.rankIdx   or 1
    self.rank      = RANKS[math.min(self.rankIdx, #RANKS)]
    self.colonized = data.colonized or 0
    self.battles   = data.battles   or 0
    self.wins      = data.wins      or 0
end

--- ShipProductionQueue: 序列化（仅保存队列项，不含 planet 对象引用）
function ShipProductionQueue:serialize()
    local items = {}
    for _, job in ipairs(self.items) do
        items[#items + 1] = {
            shipType  = job.shipType,
            remaining = job.remaining,
            totalTime = job.totalTime,
            planetId  = job.planet and job.planet.id or nil,
        }
    end
    return { items = items }
end

--- ShipProductionQueue: 从存档恢复（planetResolver 是一个函数，接受 id 返回行星对象）
function ShipProductionQueue:deserialize(data, planetResolver)
    if not data or not data.items then return end
    self.items = {}
    for _, d in ipairs(data.items) do
        local planet = planetResolver and planetResolver(d.planetId) or nil
        self.items[#self.items + 1] = {
            shipType  = d.shipType,
            remaining = d.remaining,
            totalTime = d.totalTime,
            progress  = 1.0 - (d.remaining / math.max(1, d.totalTime)),
            planet    = planet,
        }
    end
end

--- FleetManager: 序列化
function FleetManager:serialize()
    local fleets = {}
    for i, fl in ipairs(self.fleets) do
        local ships = {}
        for _, e in ipairs(fl.ships) do
            ships[#ships + 1] = { shipType = e.shipType, count = e.count }
        end
        fleets[i] = { id = fl.id, name = fl.name, ships = ships }
    end
    -- 序列化储备池
    local reserve = {}
    for st, cnt in pairs(self.reserve) do
        reserve[#reserve + 1] = { shipType = st, count = cnt }
    end
    return { maxFleets = self.maxFleets, fleets = fleets, reserve = reserve }
end

--- FleetManager: 从存档恢复
function FleetManager:deserialize(data)
    if not data then return end
    self.maxFleets = data.maxFleets or INIT_FLEET_COUNT
    self.fleets    = {}
    for i, fd in ipairs(data.fleets or {}) do
        local ships = {}
        for _, e in ipairs(fd.ships or {}) do
            ships[#ships + 1] = { shipType = e.shipType, count = e.count }
        end
        self.fleets[i] = { id = fd.id or i, name = fd.name or ("第 " .. i .. " 编队"), ships = ships, deployedCount = 0 }
    end
    -- 补全不足的编队槽位
    for i = #self.fleets + 1, self.maxFleets do
        self.fleets[i] = { id = i, name = "第 " .. i .. " 编队", ships = {}, deployedCount = 0 }
    end
    -- 恢复储备池
    self.reserve = {}
    for _, e in ipairs(data.reserve or {}) do
        if e.shipType and e.count then
            self.reserve[e.shipType] = e.count
        end
    end
end

-- ============================================================================
-- P1-1: 中立势力外交系统
-- ============================================================================
--- 三种中立势力定义
local NEUTRAL_FACTIONS = {
    trade_union   = { name = "商业联盟", icon = "💰", giftCost = { metal = 80, esource = 50 },
                      tradeInterval = 60, tradeGain = { metal = 30, esource = 20 },
                      color = { 255, 200, 80 } },
    star_guild    = { name = "星际工会", icon = "⚙️",  giftCost = { metal = 60, esource = 80 },
                      tradeInterval = 60, tradeGain = { metal = 20, esource = 35 },
                      color = { 100, 200, 255 } },
    relic_keeper  = { name = "遗迹守护者", icon = "🏛️", giftCost = { metal = 100, esource = 30 },
                      tradeInterval = 60, tradeGain = { metal = 50, esource = 10 },
                      color = { 180, 120, 255 } },
}

local GIFT_FAVOR          = 20    -- 每次礼物 +20 好感
local WAR_THRESHOLD       = 0     -- 好感 < 0 → 宣战
local TRADE_THRESHOLD     = 60    -- 好感 ≥ 60 → 商贸协议
local MILITARY_THRESHOLD  = 90    -- 好感 ≥ 90 → 军事合作

local DiplomacySystem = {}
DiplomacySystem.__index = DiplomacySystem

--- 创建外交系统（每局游戏一个实例）
function DiplomacySystem.new()
    local self = setmetatable({}, DiplomacySystem)
    -- planetId → { factionKey, favor(0-100), tradeTimer, atWar, military }
    self.planets = {}
    return self
end

--- 随机为未殖民星球分配中立势力标签（开局时调用）
---@param allPlanets table  GalaxyScene.GetAllPlanets() 结果
---@param ratio      number  0-1，随机标记比例（默认 0.35）
function DiplomacySystem:initFactions(allPlanets, ratio)
    ratio = ratio or 0.35
    local keys = { "trade_union", "star_guild", "relic_keeper" }
    for _, p in ipairs(allPlanets) do
        if not p.isBase and not p.colonized then
            if math.random() < ratio then
                local fk = keys[math.random(1, #keys)]
                self.planets[p.id] = {
                    factionKey  = fk,
                    favor       = 40,    -- 初始好感度 40（中立）
                    tradeTimer  = 0,
                    atWar       = false,
                    military    = false,
                }
                p.neutralFaction = fk    -- 在行星对象上打标记，渲染用
            end
        end
    end
end

--- 获取某行星的外交状态，无则返回 nil
---@param planetId number
---@return table|nil
function DiplomacySystem:getState(planetId)
    return self.planets[planetId]
end

--- 获取势力定义
---@param factionKey string
---@return table
function DiplomacySystem.getFactionDef(factionKey)
    return NEUTRAL_FACTIONS[factionKey]
end

--- 玩家送出外交礼物：扣资源、增好感
---@param planetId number
---@param rm       table
---@return boolean success, string msg
function DiplomacySystem:sendGift(planetId, rm)
    local st = self.planets[planetId]
    if not st then return false, "该星球无中立势力" end
    if st.atWar  then return false, "宣战中，无法外交" end
    local fd = NEUTRAL_FACTIONS[st.factionKey]
    if not fd then return false, "未知势力" end
    -- 扣除资源
    local cost = fd.giftCost
    if rm:get("metal") < cost.metal or rm:get("esource") < cost.esource then
        return false, string.format("资源不足（需金属%d 能源%d）", cost.metal, cost.esource)
    end
    rm:add("metal",   -cost.metal)
    rm:add("esource", -cost.esource)
    -- 增加好感
    st.favor = math.min(100, st.favor + GIFT_FAVOR)
    -- 检查新解锁
    if st.favor >= MILITARY_THRESHOLD then
        st.military = true
    end
    local msg = string.format("%s好感 +%d → %d", fd.name, GIFT_FAVOR, st.favor)
    if st.favor >= MILITARY_THRESHOLD and not st.military then
        msg = msg .. "  🤝军事合作已解锁！"
    elseif st.favor >= TRADE_THRESHOLD then
        msg = msg .. "  📦商贸协议已激活"
    end
    return true, msg
end

--- 每秒 tick：处理商贸自动收益 + 宣战衰减
---@param dt     number  时间步长（秒）
---@param rm     table
---@param allPlanets table
---@return table events  { {type="trade"|"war", planetId, factionKey, gain} }
function DiplomacySystem:tick(dt, rm, allPlanets)
    local events = {}
    -- 行星 id → 对象 快查
    local pmap = {}
    for _, p in ipairs(allPlanets or {}) do pmap[p.id] = p end

    for pid, st in pairs(self.planets) do
        if st.atWar then
            -- 宣战中好感持续衰减（每5s -1）
            st.tradeTimer = (st.tradeTimer or 0) + dt
            if st.tradeTimer >= 5 then
                st.tradeTimer = 0
                st.favor = math.max(-20, st.favor - 1)
            end
        elseif st.favor >= TRADE_THRESHOLD then
            -- 商贸协议自动收益
            local fd = NEUTRAL_FACTIONS[st.factionKey]
            if fd then
                st.tradeTimer = (st.tradeTimer or 0) + dt
                if st.tradeTimer >= fd.tradeInterval then
                    st.tradeTimer = 0
                    rm:add("metal",   fd.tradeGain.metal)
                    rm:add("esource", fd.tradeGain.esource)
                    events[#events+1] = {
                        type = "trade", planetId = pid,
                        factionKey = st.factionKey,
                        gain = fd.tradeGain,
                    }
                end
            end
        end
        -- 已殖民的星球移除外交状态
        local p = pmap[pid]
        if p and p.colonized then
            if p.neutralFaction then p.neutralFaction = nil end
            self.planets[pid] = nil
        end
    end
    return events
end

--- 检查某星球是否处于军事合作（海盗攻击时协防）
---@param planetId number
---@return boolean
function DiplomacySystem:hasMilitary(planetId)
    local st = self.planets[planetId]
    return st and st.military and not st.atWar
end

--- 序列化（存档）
function DiplomacySystem:serialize()
    local out = {}
    for pid, st in pairs(self.planets) do
        out[tostring(pid)] = {
            factionKey = st.factionKey,
            favor      = st.favor,
            tradeTimer = st.tradeTimer,
            atWar      = st.atWar,
            military   = st.military,
        }
    end
    return out
end

--- 反序列化（读档）
---@param data table   serialize() 结果
---@param allPlanets table
function DiplomacySystem:deserialize(data, allPlanets)
    if type(data) ~= "table" then return end
    local pmap = {}
    for _, p in ipairs(allPlanets or {}) do pmap[p.id] = p end
    for pidStr, st in pairs(data) do
        local pid = tonumber(pidStr)
        if pid then
            self.planets[pid] = {
                factionKey = st.factionKey,
                favor      = st.favor      or 40,
                tradeTimer = st.tradeTimer or 0,
                atWar      = st.atWar      or false,
                military   = st.military   or false,
            }
            local p = pmap[pid]
            if p then p.neutralFaction = st.factionKey end
        end
    end
end

-- ============================================================================
-- 导出（返回类与工厂函数）
-- ============================================================================
return {
    ResourceManager      = ResourceManager,
    BuildingSystem       = BuildingSystem,
    BaseBuildingSystem   = BaseBuildingSystem,
    ResearchSystem       = ResearchSystem,
    MarketSystem         = MarketSystem,
    PlayerProfile        = PlayerProfile,
    ShipProductionQueue  = ShipProductionQueue,
    FleetManager         = FleetManager,
    DiplomacySystem      = DiplomacySystem,
    NEUTRAL_FACTIONS     = NEUTRAL_FACTIONS,
    TRADE_THRESHOLD      = TRADE_THRESHOLD,
    MILITARY_THRESHOLD   = MILITARY_THRESHOLD,
}
