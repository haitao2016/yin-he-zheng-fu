-- ============================================================================
-- game/GalactopediaSystem.lua  -- P3-1: 银河百科系统（数据+解锁逻辑）
-- 分类条目+解锁机制，记录玩家已解锁的知识
-- ============================================================================
local GalactopediaSystem = {}

-- ============================================================================
-- 百科分类与条目定义
-- ============================================================================
local CATEGORIES = {
    { id = "ships",     name = "舰船图鉴", icon = "🚀" },
    { id = "buildings", name = "建筑设施", icon = "🏗️" },
    { id = "tech",      name = "科技档案", icon = "🔬" },
    { id = "skills",    name = "战斗技能", icon = "🎯" },
    { id = "bosses",    name = "Boss指南",  icon = "👾" },
    { id = "factions",  name = "派系情报", icon = "🏛️" },
    { id = "anomalies", name = "星象奇观", icon = "✨" },
    { id = "captains",  name = "宿敌档案", icon = "💀" },
    { id = "resources", name = "资源矿物", icon = "💎" },
    { id = "lore",      name = "银河传说", icon = "📜" },
}

--- 舰船条目
local SHIP_ENTRIES = {
    { id = "SCOUT",         name = "侦察舰",  icon = "🔍", desc = "轻型侦察单位，速度极快但火力薄弱。常用于前线侦察和快速殖民行动。", unlockCondition = "build_ship_SCOUT" },
    { id = "FRIGATE",       name = "护卫舰",  icon = "⚔️", desc = "舰队主力，攻守平衡。是初期扩张的中坚力量，可群体作战形成数量优势。", unlockCondition = "build_ship_FRIGATE" },
    { id = "DESTROYER",     name = "驱逐舰",  icon = "🗡️", desc = "中型战舰，拥有厚实装甲和可观火力。舰队核心单位，适合正面对抗。", unlockCondition = "build_ship_DESTROYER" },
    { id = "BATTLECRUISER", name = "战列舰",  icon = "⚡", desc = "重型主力舰，超高血量与溅射武器系统。建造耗时漫长但战场统治力极强。", unlockCondition = "build_ship_BATTLECRUISER" },
    { id = "CARRIER",       name = "母舰",    icon = "🌟", desc = "巨型旗舰级战舰，血量惊人、范围溅射。一艘母舰足以扭转战局。", unlockCondition = "build_ship_CARRIER" },
    { id = "INTERCEPTOR",   name = "拦截舰",  icon = "💨", desc = "高速玻璃炮，极快射速但脆弱如纸。以数量取胜的消耗品。", unlockCondition = "build_ship_INTERCEPTOR" },
    { id = "ENGINEER",      name = "工程舰",  icon = "🔧", desc = "非战斗单位，专职采集星球矿物资源。经济发展的基石。", unlockCondition = "build_ship_ENGINEER" },
    { id = "EXPLORER",      name = "探索舰",  icon = "🌍", desc = "殖民专用舰，可在未开发星球建立前哨站。版图扩张的先驱者。", unlockCondition = "build_ship_EXPLORER" },
    -- V2.6 新增舰种
    { id = "STEALTH",       name = "隐形舰",  icon = "👻", desc = "高机动性舰种，需相位驱动科技解锁。攻击附带相位伤害，可短暂隐形躲避敌方火力，适合特种突袭与后排狙击。", unlockCondition = "build_ship_STEALTH" },
    { id = "SUPPORT",       name = "支援舰",  icon = "⚕️", desc = "纳米修复科技解锁的辅助单位。为友军提供治疗光环，并小幅提升附近战舰的攻击输出，是持久战的关键支柱。", unlockCondition = "build_ship_SUPPORT" },
    { id = "DREADNOUGHT",   name = "巨型战舰", icon = "🛸", desc = "新星炮+量子堡垒解锁的终极战舰，超高血量与范围攻击，每波战斗仅能部署一艘，是舰队的核心王牌。", unlockCondition = "build_ship_DREADNOUGHT" },
}

--- 科技条目
local TECH_ENTRIES = {
    { id = "DEEP_MINING",      name = "深层采矿",     icon = "⛏️",  desc = "提升矿井产量20%。利用深层钻探技术开采行星地核资源。", unlockCondition = "research_DEEP_MINING" },
    { id = "SOLAR_EFFICIENCY", name = "高效光伏",     icon = "☀️",  desc = "电站产量+15%。改进光伏转化效率，从恒星辐射中获取更多能源。", unlockCondition = "research_SOLAR_EFFICIENCY" },
    { id = "CRYSTAL_PROCESS",  name = "水晶提纯",     icon = "💠",  desc = "水晶精炼效率+30%。通过量子谐振技术纯化天然水晶矿脉。", unlockCondition = "research_CRYSTAL_PROCESS" },
    { id = "HULL_ALLOY",       name = "合金船壳",     icon = "🛡️",  desc = "所有舰船耐久+25%。使用星际合金强化舰体结构。", unlockCondition = "research_HULL_ALLOY" },
    { id = "SHIELD_REINFORCE", name = "护盾强化",     icon = "🔰",  desc = "基地护盾+300，防御+20%。多层能量场叠加形成坚固屏障。", unlockCondition = "research_SHIELD_REINFORCE" },
    { id = "RAPID_REFINE",     name = "快速精炼",     icon = "⚗️",  desc = "精炼速率×1.5。催化分子重组加速原矿到精炼品的转化。", unlockCondition = "research_RAPID_REFINE" },
    { id = "WARP_DRIVE",       name = "曲速引擎",     icon = "🌀",  desc = "舰队移动速度+50%。弯曲时空实现超光速跃迁。", unlockCondition = "research_WARP_DRIVE" },
    { id = "ADVANCED_WEAPONS", name = "高级武器系统", icon = "💥",  desc = "所有战舰攻击力+30%。粒子束武器替代传统动能弹头。", unlockCondition = "research_ADVANCED_WEAPONS" },
    { id = "QUANTUM_CORE",     name = "量子核心",     icon = "🧬",  desc = "科研速度+50%，核心升级费-20%。量子纠缠计算突破科技瓶颈。", unlockCondition = "research_QUANTUM_CORE" },
    { id = "NOVA_CANNON",      name = "新星炮",       icon = "☄️",  desc = "AOE半径+80%。聚焦恒星能量释放毁灭性打击。", unlockCondition = "research_NOVA_CANNON" },
    { id = "VOID_ANCHOR",      name = "虚空锚定",     icon = "⚓",  desc = "攻击+20%，敌方减速20%。操纵虚空能量束缚敌舰。", unlockCondition = "research_VOID_ANCHOR" },
    { id = "STELLAR_SYNC",     name = "星际同步",     icon = "🔗",  desc = "全局产出+25%，科研+30%。恒星网络同步提升文明效率。", unlockCondition = "research_STELLAR_SYNC" },
    -- Tier5 扩展（V2.6）
    { id = "STELLAR_ENGINE",   name = "恒星引擎",    icon = "☀️",  desc = "将恒星能量转化为舰队动能，全局移动速度+60%，战斗开场获得初始加速。", unlockCondition = "research_STELLAR_ENGINE" },
    { id = "QUANTUM_FACTORY",  name = "量子工厂",    icon = "🏭", desc = "基于量子纠缠的自动化生产，金属/能源精炼效率+80%，舰船建造时间-25%。", unlockCondition = "research_QUANTUM_FACTORY" },
    { id = "VOID_FLEET",       name = "虚空舰队",    icon = "🌌", desc = "解锁虚空舰体技术，所有舰船生命值+40%，并可在战斗开始触发一次虚空跃迁。", unlockCondition = "research_VOID_FLEET" },
    { id = "FORTRESS_PROTOCOL_II", name = "要塞协议II", icon = "🏯", desc = "基地护盾最大值翻倍，每秒恢复1%基地护盾，遭受攻击时触发反击护盾。", unlockCondition = "research_FORTRESS_PROTOCOL_II" },
    { id = "SPACE_TIME_STUDY", name = "时空研究",    icon = "⏳", desc = "高阶时空学研究，科研速度+60%，解锁 Tier5 全部进阶协议。", unlockCondition = "research_SPACE_TIME_STUDY" },
    { id = "CIVILIZATION_LEAP",name = "文明飞跃",    icon = "🚀", desc = "文明等级跃迁，全局资源产出+50%，舰队上限+2，是 V2.6 的终极科技。", unlockCondition = "research_CIVILIZATION_LEAP" },
}

--- 建筑条目（V2.6 扩展）
local BUILDING_ENTRIES = {
    { id = "BUILD_MINE",            name = "自动化矿井",   icon = "⛏️", desc = "行星基础建筑，持续产出矿石资源。是任何殖民点的起步设施。", unlockCondition = "auto" },
    { id = "BUILD_POWER",          name = "太阳能阵列",   icon = "☀️", desc = "产出能源资源，驱动一切高级建筑与舰船建造。", unlockCondition = "auto" },
    { id = "BUILD_SHIELD",         name = "护盾发生器", icon = "🛡️", desc = "为基地/行星提供额外护盾，防御敌方突袭。", unlockCondition = "auto" },
    { id = "BUILD_TRADE",          name = "星际交易所", icon = "💰", desc = "提供星币产出建筑，用于外交与贸易的基石。", unlockCondition = "auto" },
    { id = "BUILD_DEFENSE_TURRET", name = "轨道炮塔",   icon = "🔫", desc = "在星球战斗中部署的固定炮塔，自动攻击进入射程的敌人。配合舰队可形成坚固防线。", unlockCondition = "build_DEFENSE_TURRET" },
    { id = "BUILD_ADV_REFINERY",   name = "高级精炼厂", icon = "🏭", desc = "精炼速率大幅提升，并有5%概率产出稀有资源，是高等级资源链的核心建筑。", unlockCondition = "build_ADV_REFINERY" },
    { id = "BUILD_RESEARCH",       name = "科研站",     icon = "🔬", desc = "科研速度+20%，科研点倍率×1.15，加速整个科技树解锁。", unlockCondition = "build_RESEARCH_STATION" },
    { id = "BUILD_STARGATE",       name = "星门节点",   icon = "🌀", desc = "舰队可瞬移至该星球轨道，冷却60秒。高速机动与战略绕后必备。", unlockCondition = "build_STARGATE_NODE" },
}

--- 派系条目
local FACTION_ENTRIES = {
    { id = "trade_union",  name = "商业联盟",   icon = "💰", desc = "控制着星域间贸易航线的富商组织。提供金属和能源贸易机会，以利益为纽带。", unlockCondition = "meet_faction_trade_union" },
    { id = "star_guild",   name = "星际工会",   icon = "⚙️", desc = "技术工匠与工程师组成的互助组织。掌握先进生产工艺，擅长能源精炼。", unlockCondition = "meet_faction_star_guild" },
    { id = "relic_keeper", name = "遗迹守护者", icon = "🏛️", desc = "致力于保护远古文明遗迹的神秘组织。掌握珍贵矿物资源，对外来者态度谨慎。", unlockCondition = "meet_faction_relic_keeper" },
}

--- 战斗技能条目（V2.6 扩展）
local SKILL_ENTRIES = {
    { id = "SK_TACTICAL",  name = "战术协同", icon = "🎯", desc = "激活8秒内，友舰对同一目标的攻击叠加伤害，最高可额外叠加100%伤害。集火战首选。", unlockCondition = "auto" },
    { id = "SK_GRAVITY",   name = "引力陷阱", icon = "🌀", desc = "在战场选定位置生成减速与持续伤害陷阱，敌舰进入范围内会被拖慢并受到每秒伤害。", unlockCondition = "auto" },
    { id = "SK_DARK_STORM", name = "暗能风暴", icon = "🌪️", desc = "全场增益：友舰攻击力与速度同时提升，敌舰命中率下降，是大混战中最致命的技能。", unlockCondition = "auto" },
}

--- Boss 指南（V2.6 扩展）
local BOSS_ENTRIES = {
    { id = "BOSS_BC",      name = "战列巡洋舰Boss", icon = "⚔️", desc = "3阶段机制：血量低于70%进入狂怒，范围炮击威胁全队；低于30%时召唤小型舰增援。建议分阶段集火+护盾强化交替。", unlockCondition = "auto" },
    { id = "BOSS_CARRIER", name = "母舰Boss",        icon = "🛸", desc = "3阶段机制：释放无人机群持续骚扰，血量低于20%启动自爆倒计时。需在15秒内完成击杀或全队后撤避免范围伤害。", unlockCondition = "auto" },
    { id = "BOSS_VOID",    name = "虚空领主Boss",    icon = "👾", desc = "4阶段机制：隐形→分身→腐蚀持续伤害→吞噬大招。需高机动舰队保持机动，避免被吞噬锁定。", unlockCondition = "auto" },
}

--- 异象条目
local ANOMALY_ENTRIES = {
    { id = "ION_STORM",     name = "离子风暴",   icon = "⚡", desc = "高能离子粒子充斥星域，护盾效率提升但舰船减速。双刃剑般的天象。", unlockCondition = "encounter_anomaly_ION_STORM" },
    { id = "DARK_MATTER",   name = "暗物质涌流", icon = "🌀", desc = "暗物质从虚空涌入，武器威力增强但护盾削弱。进攻方的天赐良机。", unlockCondition = "encounter_anomaly_DARK_MATTER" },
    { id = "GRAVITY_WELL",  name = "引力异常",   icon = "🕳️", desc = "局部引力扭曲，影响战场机动性。善加利用可形成战术优势。", unlockCondition = "encounter_anomaly_GRAVITY_WELL" },
    { id = "SOLAR_FLARE",   name = "太阳耀斑",   icon = "☀️", desc = "恒星耀斑爆发，所有武器威力倍增但舰船结构受损。高风险高回报。", unlockCondition = "encounter_anomaly_SOLAR_FLARE" },
    { id = "NEBULA_SHROUD", name = "星云屏蔽",   icon = "🌫️", desc = "浓密星云笼罩战场，首轮攻击被大幅削弱。防守方的天然屏障。", unlockCondition = "encounter_anomaly_NEBULA_SHROUD" },
    { id = "RIFT",          name = "时空裂隙",   icon = "💠", desc = "时空裂隙释放不稳定能量，随机极大强化某项属性。混沌中的希望。", unlockCondition = "encounter_anomaly_RIFT" },
}

--- 宿敌条目
local CAPTAIN_ENTRIES = {
    { id = "ironjaw",  name = "铁爪·格拉克", icon = "🦾", desc = "机械改造的海盗头目，指挥重甲编队。每次遭遇都在进化，最终会释放全部战力。", unlockCondition = "encounter_nemesis_ironjaw" },
    { id = "phantom",  name = "幽影·赛拉",   icon = "👻", desc = "神出鬼没的速攻战术大师，偏好蜂群战术。被击败后总能逃脱。", unlockCondition = "encounter_nemesis_phantom" },
    { id = "tyrant",   name = "暴君·沃坦",   icon = "👑", desc = "信仰力量至上的舰队统帅，指挥母舰编队。其信念如同装甲般坚不可摧。", unlockCondition = "encounter_nemesis_tyrant" },
}

--- 资源条目
local RESOURCE_ENTRIES = {
    { id = "metal",    name = "金属矿",  icon = "🪨", desc = "银河中最基础的建筑材料。从行星地壳采集的铁、钛、钨等合金原矿，经精炼后用于舰船建造和建筑建设。", unlockCondition = "auto" },
    { id = "esource",  name = "能源矿",  icon = "⚡", desc = "高密度能量结晶体，是文明运转的动力源泉。从恒星辐射和星际尘埃中凝结而成，驱动一切高级设备。", unlockCondition = "auto" },
    { id = "nuclear",  name = "核能水晶", icon = "💎", desc = "极其稀有的量子级能量载体，蕴含恒星核心般的巨大能量。只有最先进的科技和最强大的战舰才需要它。", unlockCondition = "auto" },
    { id = "crystal",  name = "晶石",     icon = "🔮", desc = "跨维度共振晶体，用于专精系统激活和高级协议缔结。产量稀少但用途广泛。", unlockCondition = "auto" },
    -- V2.6 稀有资源扩展
    { id = "rare_titanium",    name = "钛合金",   icon = "🔩", desc = "高级舰船建造的核心材料。比普通金属轻且强度更高，是隐形舰与巨型战舰的舰体基础。", unlockCondition = "auto" },
    { id = "rare_darkmatter",  name = "暗物质",   icon = "🌀", desc = "虚空科技原料，来源于深空与虚空领主残骸。用于激活 Tier5 协议与虚空舰队升级。", unlockCondition = "auto" },
    { id = "rare_starcore",    name = "星核碎片", icon = "🌟", desc = "极高能量密度的恒星内核碎片，Tier5 科技和终极舰船建造的必需资源。", unlockCondition = "auto" },
    { id = "rare_blue_crystal", name = "蓝晶石",  icon = "💙", desc = "高级建筑升级材料，蓝晶小行星的产物。精炼后可用于强化护盾与引擎系统。", unlockCondition = "auto" },
    { id = "rare_purple_crystal", name = "紫晶石", icon = "💜", desc = "高级建筑升级材料，稀有混合小行星的产物。强化量子计算与科研设施。", unlockCondition = "auto" },
    { id = "rare_rainbow_crystal", name = "彩虹晶", icon = "🌈", desc = "传说级晶体，仅在特殊星象与虚空领主处获得，可解锁最高阶的文明突破。", unlockCondition = "auto" },
}

--- 传说条目（通过里程碑解锁）
local LORE_ENTRIES = {
    { id = "lore_origin",      name = "星际起源",     icon = "🌌", desc = "人类在银河系建立第一个殖民地的那一天起，便注定了各派系之间的永恒竞争。每位指挥官都从一颗边陲母星开始，书写属于自己的银河史诗。", unlockCondition = "auto" },
    { id = "lore_first_battle",name = "初次交锋",     icon = "⚔️", desc = "第一次与海盗舰队遭遇时，新手指挥官们才真正理解——银河绝非太平。战火是文明扩张中不可避免的代价。", unlockCondition = "win_battle_1" },
    { id = "lore_expansion",   name = "殖民时代",     icon = "🌍", desc = "当舰队跨越第一个星系边界，殖民一颗全新行星，帝国的版图便翻开了新篇章。每颗行星都有独特资源和挑战。", unlockCondition = "colonize_3" },
    { id = "lore_war",         name = "全面战争",     icon = "💀", desc = "当宿敌船长第一次在战场上现身，指挥官们意识到：有些敌人不会被轻易击溃，他们在学习，在进化。", unlockCondition = "encounter_nemesis_any" },
    { id = "lore_diplomacy",   name = "外交博弈",     icon = "🤝", desc = "三大派系之间的微妙平衡如同走钢丝。拉拢一方必然得罪另一方——三角博弈之下，没有永恒的盟友。", unlockCondition = "alliance_any" },
    { id = "lore_endgame",     name = "终局之战",     icon = "🌠", desc = "当所有宿敌被击败、科技树攀至顶峰，真正的挑战才刚刚开始——银河的命运，掌握在你手中。", unlockCondition = "defeat_all_nemesis" },
    { id = "lore_megastructure",name= "巨构时代",     icon = "🏗️", desc = "文明的巅峰不再是战舰数量，而是改造星系本身的能力。戴森球、环世界——每一座巨构都是对宇宙法则的挑战。", unlockCondition = "mega_complete_1" },
    { id = "lore_livery",      name = "荣耀徽记",     icon = "🎨", desc = "经验丰富的指挥官用独特的涂装和徽章标记自己的舰队。这不仅是美学追求，更是威慑——让敌人一眼便知来者不善。", unlockCondition = "customize_livery" },
}

-- ============================================================================
-- 按分类ID索引所有条目
-- ============================================================================
local ENTRIES_BY_CATEGORY = {
    ships     = SHIP_ENTRIES,
    buildings = BUILDING_ENTRIES,
    tech      = TECH_ENTRIES,
    skills    = SKILL_ENTRIES,
    bosses    = BOSS_ENTRIES,
    factions  = FACTION_ENTRIES,
    anomalies = ANOMALY_ENTRIES,
    captains  = CAPTAIN_ENTRIES,
    resources = RESOURCE_ENTRIES,
    lore      = LORE_ENTRIES,
}

-- ============================================================================
-- 运行时状态
-- ============================================================================
local state_ = {
    unlocked = {},  -- { [entryId] = true }
}

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化/重置
function GalactopediaSystem.Init()
    state_.unlocked = {}
    -- 自动解锁 "auto" 条件的条目
    for _, entries in pairs(ENTRIES_BY_CATEGORY) do
        for _, e in ipairs(entries) do
            if e.unlockCondition == "auto" then
                state_.unlocked[e.id] = true
            end
        end
    end
end

--- 尝试解锁一个条目（外部触发）
---@param conditionKey string  如 "build_ship_FRIGATE", "research_WARP_DRIVE"
---@return string|nil  解锁的条目名称（用于 toast），nil 表示未解锁新条目
function GalactopediaSystem.TryUnlock(conditionKey)
    if not conditionKey then return nil end
    for _, entries in pairs(ENTRIES_BY_CATEGORY) do
        for _, e in ipairs(entries) do
            if e.unlockCondition == conditionKey and not state_.unlocked[e.id] then
                state_.unlocked[e.id] = true
                print(string.format("[Galactopedia] 解锁: %s %s", e.icon, e.name))
                return e.name
            end
        end
    end
    return nil
end

--- 批量尝试解锁（方便一次传入多个 key）
---@param keys string[]
---@return string[]  新解锁的条目名称列表
function GalactopediaSystem.TryUnlockBatch(keys)
    local results = {}
    for _, k in ipairs(keys) do
        local name = GalactopediaSystem.TryUnlock(k)
        if name then results[#results + 1] = name end
    end
    return results
end

--- 查询某条目是否已解锁
---@param entryId string
---@return boolean
function GalactopediaSystem.IsUnlocked(entryId)
    return state_.unlocked[entryId] == true
end

--- 获取分类列表
function GalactopediaSystem.GetCategories()
    return CATEGORIES
end

--- 获取某分类下的所有条目（含解锁状态）
---@param categoryId string
---@return table[]  { id, name, icon, desc, unlocked }
function GalactopediaSystem.GetEntries(categoryId)
    local src = ENTRIES_BY_CATEGORY[categoryId]
    if not src then return {} end
    local result = {}
    for _, e in ipairs(src) do
        result[#result + 1] = {
            id       = e.id,
            name     = e.name,
            icon     = e.icon,
            desc     = e.desc,
            unlocked = state_.unlocked[e.id] == true,
        }
    end
    return result
end

--- 获取总解锁数 / 总条目数
function GalactopediaSystem.GetProgress()
    local total = 0
    local unlocked = 0
    for _, entries in pairs(ENTRIES_BY_CATEGORY) do
        for _, e in ipairs(entries) do
            total = total + 1
            if state_.unlocked[e.id] then unlocked = unlocked + 1 end
        end
    end
    return unlocked, total
end

--- 获取某分类的解锁进度
function GalactopediaSystem.GetCategoryProgress(categoryId)
    local src = ENTRIES_BY_CATEGORY[categoryId]
    if not src then return 0, 0 end
    local total = #src
    local unlocked = 0
    for _, e in ipairs(src) do
        if state_.unlocked[e.id] then unlocked = unlocked + 1 end
    end
    return unlocked, total
end

-- ============================================================================
-- 序列化/反序列化
-- ============================================================================
function GalactopediaSystem.Serialize()
    local ids = {}
    for id in pairs(state_.unlocked) do
        ids[#ids + 1] = id
    end
    return { unlocked = ids }
end

function GalactopediaSystem.Deserialize(data)
    GalactopediaSystem.Init()  -- 先重置（含auto解锁）
    if not data or not data.unlocked then return end
    for _, id in ipairs(data.unlocked) do
        state_.unlocked[id] = true
    end
end

function GalactopediaSystem.Reset()
    GalactopediaSystem.Init()
end

-- 初始化
GalactopediaSystem.Init()

return GalactopediaSystem
