---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
Constants/GalaxyEventConstants.lua
银河事件系统常量
]]

local M = {}

-- ============================================================================
-- 银河事件定义
-- ============================================================================

M.GALAXY_EVENTS = {
    -- 经济类事件
    { id = "STARGATE_OPEN", name = "星门开启", desc = "星门开启，提供快速移动通道",
      duration = 120, probability = 0.03, icon = "event_stargate",
      effects = { { type = "TRAVEL_SPEED", value = 2.0 }, { type = "TRADE_BONUS", value = 0.3 } } },
    { id = "WORMHOLE_APPEARS", name = "虫洞出现", desc = "神秘虫洞连接两个遥远区域",
      duration = 180, probability = 0.02, icon = "event_wormhole",
      effects = { { type = "NEW_PATH", planets = { "RANDOM_A", "RANDOM_B" } } } },
    { id = "PIRATE_RAID", name = "海盗袭击", desc = "海盗舰队袭击附近星球，完成可获得悬赏金",
      duration = 0, probability = 0.06, icon = "event_pirate",
      effects = { { type = "PLANET_RAID", planetId = "RANDOM" }, { type = "REWARD_PIRATE_DEFEATED", bounty = 100 } } },
    { id = "RARE_MINERAL_DISCOVERY", name = "稀有矿物发现", desc = "探测到稀有矿物资源，采矿效率大幅提升",
      duration = 300, probability = 0.015, icon = "event_mineral",
      effects = { { type = "RARE_NODE", planetId = "RANDOM" }, { type = "MINE_OUTPUT", value = 2.0 } } },
    { id = "SOLAR_STORM", name = "太阳风暴", desc = "太阳风暴干扰电子设备",
      duration = 60, probability = 0.04, icon = "event_storm",
      effects = { { type = "SHIELD_PENALTY", value = 0.5 }, { type = "STEALTH_BONUS", value = 2.0 } } },
    { id = "TRADE_FESTIVAL", name = "星际贸易节", desc = "贸易税全免，所有交易收益 +50%",
      duration = 240, probability = 0.025, icon = "event_festival",
      effects = { { type = "TRADE_BONUS", value = 0.5 }, { type = "NO_TAX", value = true } } },
    { id = "ALIEN_CONTACT", name = "外星接触", desc = "与神秘外星文明建立联系",
      duration = 360, probability = 0.01, icon = "event_alien",
      effects = { { type = "RESEARCH_SPEED", value = 2.0 }, { type = "RANDOM_TECH", value = 1 } } },

    -- 战斗类事件
    { id = "VOID_RIFT", name = "虚空裂隙", desc = "空间出现神秘裂隙，涌出异常能量生物",
      duration = 0, probability = 0.025, icon = "event_void",
      effects = { { type = "ENEMY_WAVE_BOOST", mult = 1.3 }, { type = "RARE_DROP_CHANCE", value = 0.15 } } },
    { id = "PIRATE_HARBOR", name = "海盗港", desc = "发现海盗藏身处，可缴获丰厚物资",
      duration = 180, probability = 0.02, icon = "event_pirate_harbor",
      effects = { { type = "BOUNTY_HUNTER_BONUS", value = 200 }, { type = "REPUTATION_GAIN", value = 50 } } },
    { id = "MERCENARY_OFFER", name = "佣兵招募", desc = "佣兵舰队提供协助，需要支付报酬",
      duration = 300, probability = 0.03, icon = "event_mercenary",
      effects = { { type = "TEMPORARY_ALLY", shipType = "DESTROYER", count = 3 } } },
    { id = "AMBUSH", name = "伏击预警", desc = "情报显示前方有伏击阵地，小心通过",
      duration = 120, probability = 0.04, icon = "event_ambush",
      effects = { { type = "ENEMY_AMBUSH_CHANCE", value = 0.3 }, { type = "FLEET_DEFENSE_BONUS", value = 0.2 } } },

    -- 探索类事件
    { id = "ANCIENT_RUINS", name = "远古遗迹", desc = "发现失落文明的遗迹，可能藏有珍贵科技",
      duration = 0, probability = 0.018, icon = "event_ruins",
      effects = { { type = "EXPLORATION_REWARD", bonus = { crystal = 100, credits = 500 } }, { type = "RESEARCH_SPEED", value = 1.5 } } },
    { id = "ABANDONED_FLEET", name = "废弃舰队", desc = "发现被遗弃的战舰残骸，可打捞可用部件",
      duration = 240, probability = 0.022, icon = "event_wreck",
      effects = { { type = "SCAVENGE_REWARD", bonus = { metal = 300, shipPart = 1 } } } },
    { id = "COMET_SHOWER", name = "彗星雨", desc = "大量彗星划过星系，带来稀有冰核资源",
      duration = 180, probability = 0.025, icon = "event_comet",
      effects = { { type = "RESOURCE_BONUS", resource = "NUCLEAR", value = 1.8 }, { type = "CREDITS_BONUS", value = 300 } } },
    { id = "NEBULA_PASSAGE", name = "星云穿越", desc = "穿越神秘星云，舰队获得短暂能量加成",
      duration = 200, probability = 0.035, icon = "event_nebula",
      effects = { { type = "ENERGY_BOOST", value = 1.5 }, { type = "STEALTH_BONUS", value = 1.3 } } },
    { id = "WORMHOLE_STABLE", name = "稳定虫洞", desc = "发现稳定的虫洞通道，大幅缩短航行时间",
      duration = 300, probability = 0.015, icon = "event_wormhole_stable",
      effects = { { type = "TRAVEL_SPEED", value = 3.0 }, { type = "EXPLORATION_RANGE", value = 1.5 } } },
    { id = "DISTANT_SIGNAL", name = "遥远信号", desc = "接收到来自深空的神秘信号，引导向未知区域",
      duration = 0, probability = 0.012, icon = "event_signal",
      effects = { { type = "REVEAL_HIDDEN_SYSTEM", value = true }, { type = "RESEARCH_SPEED", value = 1.3 } } },

    -- 社交/外交类事件
    { id = "DIPLOMATIC_GIFT", name = "外交礼物", desc = "友好势力送来珍贵礼物",
      duration = 0, probability = 0.028, icon = "event_gift",
      effects = { { type = "FREE_RESOURCES", bonus = { blueCrystal = 50, credits = 1000 } } } },
    { id = "TRADE_EMBARGO", name = "贸易禁运", desc = "银河经济动荡，贸易收益暂时降低",
      duration = 360, probability = 0.03, icon = "event_embargo",
      effects = { { type = "TRADE_PENALTY", value = -0.4 }, { type = "RESOURCE_BONUS", resource = "MINERALS", value = 1.2 } } },
    { id = "GUILD_MERGER", name = "公会联盟", desc = "多个公会提议结盟，共同对抗威胁",
      duration = 0, probability = 0.015, icon = "event_guild",
      effects = { { type = "GUILD_BONUS", value = 0.25 }, { type = "REPUTATION_GAIN", value = 100 } } },

    -- 经济/资源类事件
    { id = "TRADE_STORM", name = "贸易风暴", desc = "全星系市场价格剧烈波动",
      duration = 60, probability = 0.04, icon = "event_trade_storm",
      effects = { { type = "TRADE_RANDOM_FLUCTUATION", range = 0.5 } } },
    { id = "MINING_BOOM", name = "采矿繁荣期", desc = "矿区大丰收，矿物产量暴增",
      duration = 300, probability = 0.035, icon = "event_mining_boom",
      effects = { { type = "RESOURCE_BONUS", resource = "MINERALS", value = 2.0 }, { type = "ENERGY_DRAIN", value = 0.8 } } },
    { id = "CRYSTAL_SWARM", name = "晶石潮汐", desc = "晶石矿脉异常活跃，产量大幅提升",
      duration = 240, probability = 0.028, icon = "event_crystal",
      effects = { { type = "RESOURCE_BONUS", resource = "CRYSTAL", value = 2.5 }, { type = "CREDITS_BONUS", value = 800 } } },
    { id = "WARP_ANOMALY", name = "曲速异常", desc = "曲速航行出现随机坐标偏移",
      duration = 180, probability = 0.03, icon = "event_warp_anomaly",
      effects = { { type = "WARP_INSTABILITY", value = 0.15 }, { type = "DISCOVERY_CHANCE", value = 0.25 } } },
    { id = "GATEWAY_ACTIVATION", name = "星门激活", desc = "发现新的跃迁星门连接未知星系",
      duration = 0, probability = 0.012, icon = "event_gateway",
      effects = { { type = "NEW_STARGATE", value = true }, { type = "EXPLORATION_REWARD", bonus = { credits = 2000 } } } },
    { id = "STELLAR_FLARE", name = "恒星耀斑", desc = "近距离恒星爆发，释放巨大能量",
      duration = 120, probability = 0.025, icon = "event_flare",
      effects = { { type = "ENERGY_BOOST", value = 2.0 }, { type = "SHIELD_PENALTY", value = 0.6 } } },

    -- 稀有/传说级事件
    { id = "VOID_STORM", name = "虚空风暴", desc = "虚空能量风暴席卷整个星系，机遇与危险并存",
      duration = 300, probability = 0.008, icon = "event_voidstorm", rarity = "legendary",
      effects = { { type = "VOID_ENERGY", value = 3.0 }, { type = "ALL_RESOURCES", value = 1.5 }, { type = "ENEMY_WAVE_BOOST", mult = 1.5 } } },
    { id = "GOLDEN_AGE", name = "黄金时代", desc = "银河进入繁荣期，所有产出大幅提升",
      duration = 600, probability = 0.005, icon = "event_golden", rarity = "legendary",
      effects = { { type = "ALL_RESOURCES", value = 2.0 }, { type = "TRADE_BONUS", value = 1.0 }, { type = "RESEARCH_SPEED", value = 2.0 } } },
}

M.ACTIVE_GALAXY_EVENTS = {}

return M
