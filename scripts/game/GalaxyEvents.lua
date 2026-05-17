-- ============================================================================
-- game/GalaxyEvents.lua  -- 银河星图随机事件系统
-- 负责: 事件类型数据、事件节点生命周期管理（生成/更新/渲染）
-- 不负责: 玩家点击事件节点后的奖励逻辑（由 GalaxyScene.handleClick 处理）
-- ============================================================================

local GalaxyEvents = {}

-- ============================================================================
-- 事件系统配置常量
-- ============================================================================
local EVENT_SPAWN_INTERVAL = 90  -- 每 90 秒生成新事件
local EVENT_LIFESPAN       = 120 -- 事件节点存活时间（秒）
local EVENT_MAX_COUNT      = 5   -- 地图上最多同时存在事件数

-- P1-3: 链式事件配置
local CHAIN_DELAY_MIN  = 50   -- 子事件触发最短延迟（秒）
local CHAIN_DELAY_MAX  = 80   -- 子事件触发最长延迟（秒）
local CHAIN_DIST_MAX   = 500  -- 子事件生成的最大偏移距离（世界坐标）

-- ============================================================================
-- 事件类型数据
-- ============================================================================
local EVENT_TYPES = {
    -- ── 原有3种（P1-3: 已添加链式触发字段）──────────────────────────────────
    MINE = {
        id      = "MINE",
        label   = "废弃矿场",
        icon    = "⛏",
        color   = {180, 140, 80},
        desc    = "探测到废弃星际矿场，内含大量原矿残留。",
        choices = {
            -- choiceIdx=1 触发链式子事件 MINE_COLLAPSE
            { text = "派遣探测器采集 ⛓", res = "minerals", amount = 0,
              chainEvent = "MINE_COLLAPSE" },
            { text = "放弃，继续探索" },
        },
    },
    MERCHANT = {
        id      = "MERCHANT",
        label   = "流浪商人",
        icon    = "🛸",
        color   = {80, 200, 255},
        desc    = "遭遇流浪商船，对方愿意以矿石换取能量块。",
        choices = {
            -- choiceIdx=1 触发链式子事件 MERCHANT_RETURN
            { text = "以矿石×80 换取能量×60 ⛓",
              cost = {minerals=80}, gain = {energy=60},
              chainEvent = "MERCHANT_RETURN" },
            { text = "以晶石×30 换取矿石×100",
              cost = {crystal=30},  gain = {minerals=100} },
            { text = "拒绝交易" },
        },
    },
    RIFT = {
        id      = "RIFT",
        label   = "时空裂缝",
        icon    = "✦",
        color   = {180, 80, 255},
        desc    = "发现异常时空裂缝，辐射极高但蕴含未知能量。",
        choices = {
            -- choiceIdx=1 触发链式子事件 RIFT_SURGE（危机事件）
            { text = "进入裂缝采集能量 ⛓", gain = {energy=120, crystal=40}, hpLoss = true,
              chainEvent = "RIFT_SURGE" },
            { text = "绕道远航（耗时）",  gain = {crystal=20} },
            { text = "封锁区域，上报基地" },
        },
    },
    -- ── P1-3: 链式子事件（3种，由父事件触发）────────────────────────────────
    MINE_COLLAPSE = {
        id      = "MINE_COLLAPSE",
        label   = "矿场坍塌警报",
        icon    = "💥",
        color   = {255, 120, 60},
        desc    = "采集中矿场结构不稳，深层矿洞坍塌！探测器被困，需要紧急决策。",
        isChain = true,
        choices = {
            { text = "紧急出动工程舰救援（消耗能源×40，获得大量矿石）",
              cost = {esource=40}, gain = {minerals=300, crystal=30}, expGain=80 },
            { text = "放弃探测器，只保留已采矿石",
              gain = {minerals=80} },
            { text = "全面撤离，矿场全损" },
        },
    },
    MERCHANT_RETURN = {
        id      = "MERCHANT_RETURN",
        label   = "商人再度来访",
        icon    = "🛸",
        color   = {120, 230, 255},
        desc    = "上次交易的流浪商人再度出现！他带来了更稀有的货物，声称专门回来报恩。",
        isChain = true,
        choices = {
            { text = "购入高级货物（消耗核能×60，获得大量晶石+能源）",
              cost = {nuclear=60}, gain = {crystal=100, esource=120}, expGain=100 },
            { text = "少量采购（矿石×50→能源×80）",
              cost = {minerals=50}, gain = {esource=80} },
            { text = "感谢后婉拒，各自继续旅程" },
        },
    },
    RIFT_SURGE = {
        id      = "RIFT_SURGE",
        label   = "裂缝能量爆发",
        icon    = "⚡",
        color   = {220, 60, 255},
        desc    = "时空裂缝发生能量激增！周边空间扭曲，如不立刻处理，将对基地护盾造成严重损耗。",
        isChain = true,
        isCrisis = true,  -- 危机事件：不处理将受到惩罚
        choices = {
            { text = "释放反相位脉冲封印裂缝（消耗核能×80）",
              cost = {nuclear=80}, gain = {crystal=60, esource=80}, expGain=150 },
            { text = "引导能量流向己方采集器（有风险）",
              gain = {esource=200}, hpLoss = true, expGain=80 },
            { text = "无力应对，撤离区域（护盾受损）",
              shieldLoss = true },
        },
    },
    -- ── 新增5种 ────────────────────────────────────────────────────────────
    DERELICT = {
        id      = "DERELICT",
        label   = "废弃战舰",
        icon    = "🚀",
        color   = {100, 160, 220},
        desc    = "扫描到一艘古老的废弃战舰残骸，舰体完整度尚可，或许能拆解出有用零件。",
        choices = {
            { text = "全面拆解（获取金属+能源）",
              gain = {minerals=200, esource=80}, expGain=50 },
            { text = "只取核心数据（获取经验）",
              gain = {}, expGain=120 },
            { text = "保持距离，不予理睬" },
        },
    },
    NEBULA = {
        id      = "NEBULA",
        label   = "能量星云",
        icon    = "🌌",
        color   = {60, 220, 180},
        desc    = "舰队驶入稀薄星云区域，磁场异常活跃，能量充沛——但导航系统受到干扰。",
        choices = {
            { text = "开启采集阵列吸取能量",
              gain = {esource=180, nuclear=40} },
            { text = "加速穿越星云（获少量晶石）",
              gain = {crystal=60} },
            { text = "原路折返，绕行" },
        },
    },
    PIRATE_LOOT = {
        id      = "PIRATE_LOOT",
        label   = "海盗遗宝",
        icon    = "💰",
        color   = {240, 190, 50},
        desc    = "发现被击毁的海盗据点残骸，散落的货仓内可能藏有掠夺物资，但拾取需要消耗燃料。",
        choices = {
            { text = "投入能源×60 全力打捞（高收益）",
              cost = {esource=60}, gain = {minerals=350, credits=80}, expGain=60 },
            { text = "简单扫描取走明显物资",
              gain = {minerals=120, credits=30} },
            { text = "放弃，离开危险区域" },
        },
    },
    ANOMALY = {
        id      = "ANOMALY",
        label   = "引力异常",
        icon    = "🌀",
        color   = {200, 100, 80},
        desc    = "探测到强烈引力异常区——可能是微型黑洞，也可能是深埋的超稠密矿脉。",
        choices = {
            { text = "冒险深入探测（高风险高回报）",
              gain = {crystal=120, nuclear=80}, hpLoss = true, expGain=100 },
            { text = "释放探测器采样（安全，低回报）",
              gain = {crystal=40, nuclear=20} },
            { text = "记录坐标后立刻撤离" },
        },
    },
    COLONY_SOS = {
        id      = "COLONY_SOS",
        label   = "殖民地求援",
        icon    = "📡",
        color   = {120, 220, 120},
        desc    = "接收到边远殖民地发来的求援信号，物资匮乏，但他们可以提供科研数据作为回报。",
        choices = {
            { text = "紧急援助（矿石×150 + 能源×60）",
              cost = {minerals=150, esource=60},
              gain = {credits=200}, expGain=150 },
            { text = "只送少量物资（矿石×60）",
              cost = {minerals=60},
              gain = {credits=60}, expGain=50 },
            { text = "无力援助，遗憾拒绝" },
        },
    },
    -- ── P2-3 扩展事件 (6 种) ──────────────────────────────────────────────
    TECH_RELIC = {
        id      = "TECH_RELIC",
        label   = "科技遗迹",
        icon    = "🔬",
        color   = {100, 200, 255},
        desc    = "发现一座沉寂已久的古文明科研站，内部仍有微弱能量脉冲，数据核心可能保存完好。",
        choices = {
            { text = "破解数据核心（获取科研经验）",
              gain = {}, expGain = 200 },
            { text = "拆解设备取走零件",
              gain = {crystal = 80, nuclear = 50} },
            { text = "上传坐标，返航报告" },
        },
    },
    FUEL_DEPOT = {
        id      = "FUEL_DEPOT",
        label   = "燃料补给站",
        icon    = "⛽",
        color   = {255, 200, 60},
        desc    = "意外发现一处废弃的星际燃料补给站，储罐仍残留部分核燃料，但管道老化有泄漏风险。",
        choices = {
            { text = "谨慎提取全部燃料（风险操作）",
              gain = {nuclear = 160, esource = 60}, hpLoss = true },
            { text = "只取安全储量（低风险）",
              gain = {nuclear = 70} },
            { text = "转发位置给商业采矿公司" },
        },
    },
    ALIEN_SIGNAL = {
        id      = "ALIEN_SIGNAL",
        label   = "异星信号",
        icon    = "👾",
        color   = {160, 255, 160},
        desc    = "截获一段来历不明的重复性编码信号，可能是智慧生命的通信，也可能是自动化浮标的干扰波。",
        choices = {
            { text = "尝试破译并回应信号",
              gain = {credits = 150}, expGain = 180 },
            { text = "全频段录制后带回基地分析",
              gain = {}, expGain = 120 },
            { text = "屏蔽频率，不予理会" },
        },
    },
    METEOR_SWARM = {
        id      = "METEOR_SWARM",
        label   = "矿石陨群",
        icon    = "☄",
        color   = {220, 150, 80},
        desc    = "舰队前方出现密集陨石群，初步光谱分析显示陨石富含稀有矿物，但穿越充满危险。",
        choices = {
            { text = "全速穿越陨石群采矿（高风险高回报）",
              gain = {minerals = 280, crystal = 60}, hpLoss = true, expGain = 80 },
            { text = "在外围捕获较小陨石",
              gain = {minerals = 120, crystal = 20} },
            { text = "绕行规避，保全舰队" },
        },
    },
    STRANDED_CREW = {
        id      = "STRANDED_CREW",
        label   = "遇难船员",
        icon    = "🆘",
        color   = {255, 120, 120},
        desc    = "收到微弱求救信号，是一艘被海盗袭击后遗弃的民用飞船，幸存船员仍在等待救援。",
        choices = {
            { text = "全力营救幸存者（获得大量经验与信誉）",
              gain = {credits = 120}, expGain = 220 },
            { text = "传送部分物资后撤离",
              cost = {esource = 40},
              gain = {credits = 60}, expGain = 80 },
            { text = "此地危险，加速离开" },
        },
    },
    DARK_MATTER = {
        id      = "DARK_MATTER",
        label   = "暗物质云",
        icon    = "🌑",
        color   = {140, 80, 200},
        desc    = "舰队探测器检测到周围空间存在高浓度暗物质云团，理论上可用于增强引擎效率，但稳定性未知。",
        choices = {
            { text = "尝试收集暗物质样本（获取晶石+核燃料）",
              gain = {crystal = 100, nuclear = 80}, hpLoss = true, expGain = 160 },
            { text = "被动记录数据不主动接触",
              gain = {}, expGain = 100 },
            { text = "立即远离异常区域" },
        },
    },
    -- ── P2-1 新增 12 种 ────────────────────────────────────────────────────
    DERELICT_SHIP = {
        id      = "DERELICT_SHIP",
        label   = "漂流战舰",
        icon    = "🚢",
        color   = {100, 160, 220},
        desc    = "发现一艘漂流在星际空间的废弃战舰残骸，舰体保存尚可，可以尝试拆解或紧急修复利用。",
        choices = {
            { text = "全面拆解残骸（获得矿石+能源）",
              gain = {minerals = 240, esource = 100}, expGain = 60 },
            { text = "尝试修复引擎（获得临时护盾加成）",
              gain = {}, expGain = 140,
              buffKey = "SHIELD_BOOST", buffDur = 90 },
            { text = "记录坐标后离开" },
        },
    },
    PLASMA_STORM = {
        id       = "PLASMA_STORM",
        label    = "等离子风暴",
        icon     = "⚡",
        color    = {255, 180, 40},
        desc     = "等离子风暴席卷周边区域！强烈电磁场干扰导致所有编队引擎节流，移动速度将大幅下降。",
        isForced = true,   -- 强制事件：点击即自动触发，无选项
        forcedEffect = {
            buffKey    = "FLEET_SLOW",
            buffDur    = 60,
            magnitude  = 0.30,   -- 速度 -30%
            notifyMsg  = "等离子风暴爆发！编队速度-30%，持续60秒",
            notifyType = "danger",
        },
    },
    ANCIENT_RUIN = {
        id      = "ANCIENT_RUIN",
        label   = "古代遗迹",
        icon    = "🏛️",
        color   = {200, 160, 80},
        desc    = "探测到远古文明遗迹，内部仍有能量波动。解码其数据核心将加速当前科技研究进程。",
        choices = {
            { text = "全力解码数据核心（科研进度+20%）",
              gain = {}, expGain = 180,
              specialAction = "TECH_BOOST" },   -- 一次性效果
            { text = "提取遗迹能源结晶",
              gain = {crystal = 120, nuclear = 60} },
            { text = "仔细考古，获取历史档案",
              gain = {credits = 180}, expGain = 150 },
        },
    },
    DISTRESS_BEACON = {
        id      = "DISTRESS_BEACON",
        label   = "求救信标",
        icon    = "📡",
        color   = {120, 220, 160},
        desc    = "接收到强烈求救信标信号！疑为被遗弃的运输船员或补给仓库，及时抵达可获救援奖励。",
        choices = {
            { text = "全速赶往救援（获晶石+学分）",
              gain = {crystal = 80, credits = 150}, expGain = 160 },
            { text = "谨慎接近取走补给物资",
              gain = {minerals = 180, esource = 80} },
            { text = "疑似陷阱，远离信标区域" },
        },
    },
    NEBULA_CLOUD = {
        id       = "NEBULA_CLOUD",
        label    = "星云迷雾",
        icon     = "🌌",
        color    = {80, 180, 220},
        desc     = "星云迷雾笼罩此区域！电磁散射可遮蔽基地位置，令敌方侦察延迟感知——自动激活3分钟侦察屏蔽。",
        isPassive = true,  -- 被动事件：进入后自动激活增益
        passiveEffect = {
            buffKey    = "STEALTH_FIELD",
            buffDur    = 180,
            notifyMsg  = "星云迷雾已激活！基地位置对海盗隐蔽 3 分钟",
            notifyType = "success",
        },
    },
    BOUNTY_HUNTER = {
        id      = "BOUNTY_HUNTER",
        label   = "赏金猎人",
        icon    = "🎯",
        color   = {240, 120, 60},
        desc    = "一位声名狼藉的赏金猎人现身！他愿意以学分为酬，清除指定海盗基地，但要价不菲。",
        choices = {
            { text = "雇佣猎人消灭海盗基地（消耗学分×300）",
              cost = {credits = 300},
              gain = {}, expGain = 200,
              specialAction = "BOUNTY_KILL" },
            { text = "分享情报（提供海盗位置，获少量学分）",
              gain = {credits = 80}, expGain = 60 },
            { text = "拒绝合作，各走各路" },
        },
    },
    QUANTUM_BEACON = {
        id       = "QUANTUM_BEACON",
        label    = "量子信标",
        icon     = "💠",
        color    = {60, 220, 255},
        desc     = "古老量子信标自动激活！涌出的量子能量流将显著提升附近所有编队的引擎效率，持续5分钟。",
        isPassive = true,
        passiveEffect = {
            buffKey    = "FLEET_HASTE",
            buffDur    = 300,
            magnitude  = 0.50,   -- 速度 +50%
            notifyMsg  = "量子信标已激活！所有编队移速+50%，持续5分钟",
            notifyType = "success",
        },
    },
    ROGUE_AI = {
        id       = "ROGUE_AI",
        label    = "叛乱 AI",
        icon     = "🤖",
        color    = {180, 60, 60},
        desc     = "警报！一个叛乱 AI 已占领附近殖民地，正在建造防御炮台，主动攻击过往舰队！",
        isForced = true,
        forcedEffect = {
            buffKey    = "ROGUE_AI_THREAT",
            buffDur    = 0,      -- 永久持续直到清除
            notifyMsg  = "叛乱AI已占领附近殖民地！派遣舰队消灭以解除威胁",
            notifyType = "danger",
            specialAction = "ROGUE_AI_SPAWN",
        },
    },
    CRYSTAL_SURGE = {
        id      = "CRYSTAL_SURGE",
        label   = "晶石涌现",
        icon    = "💎",
        color   = {100, 255, 200},
        desc    = "深空晶矿层突然涌出大量晶石矿漂！可立即采集，但矿漂正在快速飘散，窗口期有限。",
        choices = {
            { text = "全力开采（获得大量晶石）",
              gainRandom = {crystal = {150, 350}}, expGain = 80 },
            { text = "高效择优采集（中等数量，无风险）",
              gain = {crystal = 120} },
            { text = "来不及，只记录坐标" },
        },
    },
    STELLAR_FLARE = {
        id       = "STELLAR_FLARE",
        label    = "恒星耀斑",
        icon     = "☀️",
        color    = {255, 200, 50},
        desc     = "附近恒星爆发强烈耀斑！电磁脉冲将使范围内600单位所有舰队引擎暂时失效，停止移动20秒。",
        isForced = true,
        forcedEffect = {
            buffKey    = "FLEET_EMP",
            buffDur    = 20,
            notifyMsg  = "恒星耀斑爆发！所有编队停止移动 20 秒",
            notifyType = "danger",
        },
    },
    ALIEN_ARTIFACT = {
        id      = "ALIEN_ARTIFACT",
        label   = "异星文物",
        icon    = "🔮",
        color   = {160, 80, 255},
        desc    = "发现不明星际文明留下的神秘文物，能量波动规律无法解读。研究它可能带来意想不到的惊喜。",
        choices = {
            { text = "深入研究文物（随机大奖励）",
              gain = {}, expGain = 200,
              specialAction = "ARTIFACT_RESEARCH" },
            { text = "封装带回基地（获经验+学分）",
              gain = {credits = 200}, expGain = 160 },
            { text = "测试激活文物（有风险）",
              gain = {nuclear = 150, crystal = 80}, hpLoss = true, expGain = 100 },
        },
    },
    PIRATE_DEFECTOR = {
        id      = "PIRATE_DEFECTOR",
        label   = "海盗叛逃者",
        icon    = "🏴",
        color   = {200, 100, 160},
        desc    = "一名叛逃的海盗飞行员前来投靠！他可以带来2艘临时战舰助阵，但只效忠30秒后便会自行解散。",
        choices = {
            { text = "收编叛逃者（获得2艘临时舰船30秒）",
              gain = {}, expGain = 120,
              buffKey = "TEMP_FLEET", buffDur = 30, buffAmt = 2 },
            { text = "索取情报（获取海盗据点信息+学分）",
              gain = {credits = 120}, expGain = 100 },
            { text = "不信任，拒绝接触" },
        },
    },
}

local EVENT_TYPE_KEYS = {
    "MINE", "MERCHANT", "RIFT",
    "DERELICT", "NEBULA", "PIRATE_LOOT", "ANOMALY", "COLONY_SOS",
    "TECH_RELIC", "FUEL_DEPOT", "ALIEN_SIGNAL",
    "METEOR_SWARM", "STRANDED_CREW", "DARK_MATTER",
    -- P2-1 新增12种
    "DERELICT_SHIP", "PLASMA_STORM", "ANCIENT_RUIN", "DISTRESS_BEACON",
    "NEBULA_CLOUD", "BOUNTY_HUNTER", "QUANTUM_BEACON", "ROGUE_AI",
    "CRYSTAL_SURGE", "STELLAR_FLARE", "ALIEN_ARTIFACT", "PIRATE_DEFECTOR",
}

-- ============================================================================
-- 模块状态
-- ============================================================================
local events_           = {}   -- 当前地图上存活的事件节点
local spawnTimer_       = 0    -- 下次生成事件的倒计时
-- P1-3: 链式事件队列  { typeKey, wx, wy, delay }
local chainQueue_       = {}   -- 待触发的链式子事件列表
-- P2-1: 激活的 Buff/Debuff 列表  { buffKey, timeLeft, magnitude, label }
local activeBuffs_      = {}   -- 当前生效的星系级 buff/debuff

-- 渲染上下文（由 GalaxyScene 通过 Draw 参数传入，每帧刷新）
-- ctx = { vg, screenW, screenH, w2s }  其中 w2s(wx,wy) → sx,sy

-- ============================================================================
-- 内部：在指定坐标附近生成链式子事件
-- ============================================================================
local function spawnChain(typeKey, wx, wy)
    if #events_ >= EVENT_MAX_COUNT then return end
    local tpl = EVENT_TYPES[typeKey]
    if not tpl then return end
    -- 在父事件附近随机偏移
    local angle  = math.random() * math.pi * 2
    local dist   = 120 + math.random() * (CHAIN_DIST_MAX - 120)
    local cx     = wx + math.cos(angle) * dist
    local cy     = wy + math.sin(angle) * dist
    -- 克隆 choices
    local choices = {}
    for _, ch in ipairs(tpl.choices) do
        local c = {}
        for k, v in pairs(ch) do c[k] = v end
        choices[#choices + 1] = c
    end
    events_[#events_ + 1] = {
        id      = #events_ + 1 + math.random(1000),
        typeKey = typeKey,
        label   = tpl.label,
        icon    = tpl.icon,
        color   = tpl.color,
        desc    = tpl.desc,
        choices = choices,
        x       = cx,
        y       = cy,
        life    = EVENT_LIFESPAN,
        pulse   = 0,
        claimed = false,
        isChain = true,
        isCrisis = tpl.isCrisis or false,
    }
    print(string.format("[GalaxyEvent] ⛓ 链式子事件 %s @ (%.0f, %.0f)", typeKey, cx, cy))
end

-- ============================================================================
-- 内部：生成一个新事件
-- ============================================================================
local function spawn(baseX, baseY)
    if #events_ >= EVENT_MAX_COUNT then return end
    local tries = 0
    local wx, wy
    repeat
        wx = (math.random() - 0.5) * 3600
        wy = (math.random() - 0.5) * 3600
        tries = tries + 1
        local d = math.sqrt((wx - baseX)^2 + (wy - baseY)^2)
        if d > 400 then break end
    until tries > 20

    local typeKey = EVENT_TYPE_KEYS[math.random(1, #EVENT_TYPE_KEYS)]
    local tpl     = EVENT_TYPES[typeKey]

    -- 对 MINE 类型随机化采集量
    local choices = {}
    for i, ch in ipairs(tpl.choices) do
        local c = {}
        for k, v in pairs(ch) do c[k] = v end
        if i == 1 and typeKey == "MINE" then
            c.amount = 60 + math.random(0, 80)
        end
        choices[#choices + 1] = c
    end

    events_[#events_ + 1] = {
        id      = #events_ + 1 + math.random(1000),
        typeKey = typeKey,
        label   = tpl.label,
        icon    = tpl.icon,
        color   = tpl.color,
        desc    = tpl.desc,
        choices = choices,
        x       = wx,
        y       = wy,
        life    = EVENT_LIFESPAN,
        pulse   = 0,
        claimed = false,
    }
    print(string.format("[GalaxyEvent] 新事件 %s @ (%.0f, %.0f)", typeKey, wx, wy))
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- P1-3: 调度一个链式子事件（由 Client.lua 在玩家做出选择后调用）
---@param typeKey string  子事件类型键
---@param wx      number  父事件世界 X（子事件将在附近生成）
---@param wy      number  父事件世界 Y
function GalaxyEvents.ScheduleChain(typeKey, wx, wy)
    local delay = CHAIN_DELAY_MIN + math.random() * (CHAIN_DELAY_MAX - CHAIN_DELAY_MIN)
    chainQueue_[#chainQueue_ + 1] = {
        typeKey = typeKey,
        wx      = wx,
        wy      = wy,
        delay   = delay,
    }
    print(string.format("[GalaxyEvent] ⛓ 链式事件 %s 已调度，%.1f 秒后触发", typeKey, delay))
end

--- 重置事件系统（新局开始时调用）
function GalaxyEvents.Reset()
    events_       = {}
    spawnTimer_   = 0
    chainQueue_   = {}
    activeBuffs_  = {}
end

--- 每帧更新（由 GalaxyScene.Update 调用）
---@param dt     number  时间步长
---@param colonized boolean 基地是否已建立
---@param baseX  number  基地世界 X（用于生成位置回避）
---@param baseY  number  基地世界 Y
function GalaxyEvents.Update(dt, colonized, baseX, baseY)
    if not colonized then return end
    -- 倒计时 → 尝试生成
    spawnTimer_ = spawnTimer_ - dt
    if spawnTimer_ <= 0 then
        spawnTimer_ = EVENT_SPAWN_INTERVAL + math.random(0, 30)
        spawn(baseX or 0, baseY or 0)
    end
    -- P1-3: 链式队列倒计时 → 到期生成子事件
    local ci = 1
    while ci <= #chainQueue_ do
        local cq = chainQueue_[ci]
        cq.delay = cq.delay - dt
        if cq.delay <= 0 then
            spawnChain(cq.typeKey, cq.wx, cq.wy)
            table.remove(chainQueue_, ci)
        else
            ci = ci + 1
        end
    end
    -- 更新脉冲动画 + 到期删除
    local i = 1
    while i <= #events_ do
        local ev = events_[i]
        ev.pulse = ev.pulse + dt * 2.5
        if not ev.claimed then
            ev.life = ev.life - dt
            if ev.life <= 0 then
                -- P1-3: 危机事件超时未处理 → 触发惩罚回调
                if ev.isCrisis then
                    GalaxyEvents.onCrisisExpired(ev)
                end
                table.remove(events_, i)
            else
                i = i + 1
            end
        else
            ev.fadeTimer = (ev.fadeTimer or 0.8) - dt
            if ev.fadeTimer <= 0 then
                table.remove(events_, i)
            else
                i = i + 1
            end
        end
    end
    -- P2-1: 更新激活 buff 倒计时
    local bi = 1
    while bi <= #activeBuffs_ do
        local bf = activeBuffs_[bi]
        if bf.timeLeft > 0 then
            bf.timeLeft = bf.timeLeft - dt
            if bf.timeLeft <= 0 then
                print(string.format("[GalaxyEvent] buff %s 已过期", bf.buffKey))
                table.remove(activeBuffs_, bi)
            else
                bi = bi + 1
            end
        else
            -- timeLeft <= 0 初始时为永久 buff（由外部手动移除）
            bi = bi + 1
        end
    end
end

--- P1-3: 危机事件超时回调（由 Client.lua 覆写以执行惩罚）
function GalaxyEvents.onCrisisExpired(ev)
    -- 默认空实现，Client.lua 将覆盖此函数
    print(string.format("[GalaxyEvent] ⚡ 危机事件 %s 超时未处理！", ev.typeKey))
end

-- ============================================================================
-- P2-1: Buff/Debuff 公共 API
-- ============================================================================

--- 激活一个星系级 buff/debuff
---@param buffKey   string  buff 唯一键（如 "FLEET_SLOW"）
---@param timeLeft  number  持续秒数（0 = 永久，需手动调 RemoveBuff 移除）
---@param magnitude number  强度（可选，事件相关数值）
---@param label     string  显示名称（可选）
function GalaxyEvents.AddBuff(buffKey, timeLeft, magnitude, label)
    -- 相同 key 覆盖（刷新计时）
    for _, bf in ipairs(activeBuffs_) do
        if bf.buffKey == buffKey then
            bf.timeLeft  = timeLeft or bf.timeLeft
            bf.magnitude = magnitude or bf.magnitude
            print(string.format("[GalaxyEvent] buff %s 已刷新，剩余 %.1fs", buffKey, bf.timeLeft))
            return
        end
    end
    activeBuffs_[#activeBuffs_ + 1] = {
        buffKey   = buffKey,
        timeLeft  = timeLeft or 0,
        origDur   = timeLeft or 0,
        magnitude = magnitude or 1.0,
        label     = label or buffKey,
    }
    print(string.format("[GalaxyEvent] buff %s 已激活，持续 %.1fs", buffKey, timeLeft or 0))
end

--- 手动移除指定 buff（用于永久 buff 被清除时）
---@param buffKey string
function GalaxyEvents.RemoveBuff(buffKey)
    for i = #activeBuffs_, 1, -1 do
        if activeBuffs_[i].buffKey == buffKey then
            table.remove(activeBuffs_, i)
            print(string.format("[GalaxyEvent] buff %s 已移除", buffKey))
            return
        end
    end
end

--- 查询指定 buff 是否激活
---@param buffKey string
---@return boolean, number  (isActive, timeLeft)
function GalaxyEvents.HasBuff(buffKey)
    for _, bf in ipairs(activeBuffs_) do
        if bf.buffKey == buffKey then
            return true, bf.timeLeft
        end
    end
    return false, 0
end

--- 返回全部激活 buff（供 UI 显示）
---@return table
function GalaxyEvents.GetActiveBuffs()
    return activeBuffs_
end

--- 渲染所有事件节点（由 GalaxyScene.Render 调用）
---@param ctx table  { vg, screenW, screenH, w2s }
function GalaxyEvents.Draw(ctx)
    local vg      = ctx.vg
    local screenW = ctx.screenW
    local screenH = ctx.screenH
    local w2s     = ctx.w2s
    for _, ev in ipairs(events_) do
        if not ev.claimed then
            local sx, sy = w2s(ev.x, ev.y)
            if sx < -40 or sx > screenW + 40 or sy < -40 or sy > screenH + 40 then
                goto continue_ev
            end
            local r, g, b = ev.color[1], ev.color[2], ev.color[3]
            local t = ev.pulse
            -- 脉冲光晕
            local haloR = 18 + math.sin(t) * 5
            local haloA = math.floor(60 + math.sin(t) * 30)
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, haloR)
            nvgFillColor(vg, nvgRGBA(r, g, b, haloA)); nvgFill(vg)
            -- 核心圆
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, 9)
            nvgFillColor(vg, nvgRGBA(r, g, b, 200)); nvgFill(vg)
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, 9)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 160))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            -- P1-3: 危机事件 — 红色闪烁外框
            if ev.isCrisis then
                local blinkA = math.floor(80 + math.sin(ev.pulse * 3) * 70)
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, 14)
                nvgStrokeColor(vg, nvgRGBA(255, 60, 60, blinkA))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
            end
            -- P1-3: 链式事件 — 右下角锁链标记
            if ev.isChain and not ev.isCrisis then
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 220, 80, 220))
                nvgText(vg, sx + 7, sy + 4, "⛓")
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
            -- P2-1: 强制事件 — 红色旋转外框 + "!" 标记
            if ev.isForced then
                local ang = ev.pulse * 1.8
                nvgSave(vg)
                nvgTranslate(vg, sx, sy)
                nvgRotate(vg, ang)
                nvgBeginPath(vg)
                for qi = 0, 3 do
                    local a0 = qi * math.pi * 0.5
                    local a1 = a0 + math.pi * 0.35
                    nvgMoveTo(vg, math.cos(a0)*16, math.sin(a0)*16)
                    nvgArcTo(vg, math.cos((a0+a1)*0.5)*18, math.sin((a0+a1)*0.5)*18,
                                 math.cos(a1)*16, math.sin(a1)*16, 2)
                end
                nvgStrokeColor(vg, nvgRGBA(255, 80, 40, 200))
                nvgStrokeWidth(vg, 2); nvgStroke(vg)
                nvgRestore(vg)
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 80, 40, 230))
                nvgText(vg, sx + 9, sy - 12, "!")
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
            -- P2-1: 被动事件 — 绿色呼吸光晕
            if ev.isPassive then
                local breathA = math.floor(40 + math.sin(ev.pulse * 1.2) * 35)
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, 20 + math.sin(ev.pulse)*3)
                nvgFillColor(vg, nvgRGBA(80, 255, 160, breathA)); nvgFill(vg)
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(80, 255, 160, 220))
                nvgText(vg, sx + 9, sy - 12, "✦")
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
            -- 图标文字
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
            nvgText(vg, sx, sy, ev.icon)
            -- 标签（下方）
            nvgFontSize(vg, 9)
            local labelColor = ev.isCrisis and nvgRGBA(255, 100, 100, 220) or nvgRGBA(r, g, b, 200)
            nvgFillColor(vg, labelColor)
            nvgText(vg, sx, sy + 16, ev.label)
            -- 生命值警示（< 30s 时变红闪烁）
            if ev.life < 30 then
                local blink = math.floor(ev.pulse * 2) % 2 == 0
                if blink then
                    nvgFontSize(vg, 8)
                    nvgFillColor(vg, nvgRGBA(255, 80, 80, 200))
                    nvgText(vg, sx, sy + 26, string.format("%ds", math.ceil(ev.life)))
                end
            end
            ::continue_ev::
        end
    end
    -- P2-1: 渲染激活 buff 状态条（左下角，位于小地图上方）
    if #activeBuffs_ > 0 then
        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local bx  = 10
        local by0 = screenH - 160   -- 从底部往上，避开小地图
        for bi2, bf in ipairs(activeBuffs_) do
            local by = by0 - (bi2 - 1) * 22
            local isDebuff = bf.buffKey == "FLEET_SLOW" or bf.buffKey == "FLEET_EMP"
                          or bf.buffKey == "ROGUE_AI_THREAT"
            local cr, cg, cb = 80, 220, 120
            if isDebuff then cr, cg, cb = 255, 80, 60 end
            -- 背景胶囊
            local barW = 120
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, by - 8, barW, 16, 4)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 140)); nvgFill(vg)
            -- 进度条（仅有限时长时显示）
            if bf.timeLeft > 0 then
                local tpl2 = EVENT_TYPES[bf.buffKey] -- 不一定有，仅取 buffDur
                -- 通过 label 存储的原始时长反算比例（简化：timeLeft/原时长）
                local ratio = math.min(1, bf.timeLeft / math.max(1, bf.origDur or bf.timeLeft))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, bx + 1, by - 7, (barW - 2) * ratio, 14, 3)
                nvgFillColor(vg, nvgRGBA(cr, cg, cb, 60)); nvgFill(vg)
            end
            -- 文字
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220))
            local timeStr = bf.timeLeft > 0 and string.format(" %.0fs", bf.timeLeft) or " ∞"
            nvgText(vg, bx + 4, by, (isDebuff and "▼" or "▲") .. " " .. bf.label .. timeStr)
        end
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

--- 返回当前事件列表（供 GalaxyScene 的点击处理读取）
---@return table
function GalaxyEvents.GetList()
    return events_
end

--- 获取事件类型模板数据（供 handleClick 中读取）
---@param typeKey string
---@return table|nil
function GalaxyEvents.GetType(typeKey)
    return EVENT_TYPES[typeKey]
end

--- 序列化当前事件列表（用于存档）
---@return table
function GalaxyEvents.Serialize()
    local out = {}
    for _, ev in ipairs(events_) do
        out[#out + 1] = {
            id       = ev.id,
            typeKey  = ev.typeKey,
            label    = ev.label,
            icon     = ev.icon,
            color    = ev.color,
            desc     = ev.desc,
            choices  = ev.choices,
            x        = ev.x,
            y        = ev.y,
            life     = ev.life,
            pulse    = ev.pulse,
            claimed  = ev.claimed,
            isChain  = ev.isChain,
            isCrisis = ev.isCrisis,
        }
    end
    -- P1-3: 同时序列化链式队列
    local chains = {}
    for _, cq in ipairs(chainQueue_) do
        chains[#chains + 1] = {
            typeKey = cq.typeKey,
            wx      = cq.wx,
            wy      = cq.wy,
            delay   = cq.delay,
        }
    end
    return { events = out, chainQueue = chains }
end

--- 反序列化恢复事件列表（用于读档）
---@param data table
function GalaxyEvents.Deserialize(data)
    if type(data) == "table" and data.events then
        -- P1-3 新格式
        events_     = data.events or {}
        chainQueue_ = data.chainQueue or {}
    else
        -- 兼容旧存档（data 直接是事件列表）
        events_     = data or {}
        chainQueue_ = {}
    end
    spawnTimer_ = EVENT_SPAWN_INTERVAL
end

return GalaxyEvents
