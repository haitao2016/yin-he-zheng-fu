---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/i18n/zh-CN.lua -- 中文（简体）资源文件
-- ============================================================================

return {
    -- ========================================================================
    -- UI 通用文本
    -- ========================================================================

    ["ui.confirm"] = "确认",
    ["ui.cancel"] = "取消",
    ["ui.save"] = "保存",
    ["ui.settings"] = "设置",
    ["ui.exit"] = "退出",
    ["ui.research"] = "科技",
    ["ui.fleet"] = "舰队",
    ["ui.base"] = "基地",
    ["ui.campaign"] = "战役",
    ["ui.season"] = "赛季",
    ["ui.guild"] = "公会",
    ["ui.friends"] = "好友",

    ["ui.back"] = "返回",
    ["ui.close"] = "关闭",
    ["ui.ok"] = "确定",
    ["ui.yes"] = "是",
    ["ui.no"] = "否",
    ["ui.next"] = "下一页",
    ["ui.prev"] = "上一页",
    ["ui.search"] = "搜索",
    ["ui.filter"] = "筛选",
    ["ui.sort"] = "排序",

    ["ui.level"] = "等级",
    ["ui.exp"] = "经验",
    ["ui.power"] = "战力",
    ["ui.reward"] = "奖励",
    ["ui.claim"] = "领取",
    ["ui.locked"] = "未解锁",
    ["ui.unlocked"] = "已解锁",
    ["ui.completed"] = "已完成",
    ["ui.inProgress"] = "进行中",

    ["ui.loading"] = "加载中...",
    ["ui.connecting"] = "连接中...",
    ["ui.error"] = "错误",
    ["ui.success"] = "成功",
    ["ui.warning"] = "警告",
    ["ui.info"] = "提示",

    ["ui.language"] = "语言",
    ["ui.chinese"] = "简体中文",
    ["ui.english"] = "English",

    -- ========================================================================
    -- 成就描述
    -- ========================================================================

    ["achievement.first_blood.name"] = "初战告捷",
    ["achievement.first_blood.desc"] = "击败第一个 Boss",

    ["achievement.boss_slayer.name"] = "Boss 杀手",
    ["achievement.boss_slayer.desc"] = "击败 {count} 个 Boss",

    ["achievement.legendary_hunter.name"] = "传说猎人",
    ["achievement.legendary_hunter.desc"] = "击败超级 Boss",

    ["achievement.unbroken.name"] = "无懈可击",
    ["achievement.unbroken.desc"] = "无伤通关任意波次",

    ["achievement.endless_warrior.name"] = "无尽战士",
    ["achievement.endless_warrior.desc"] = "无尽模式达到波次 {wave}",

    ["achievement.boss_rush_champion.name"] = "Boss Rush 冠军",
    ["achievement.boss_rush_champion.desc"] = "完成 Boss Rush（5 Boss）",

    ["achievement.first_steps.name"] = "初窥门径",
    ["achievement.first_steps.desc"] = "研究第一个科技",

    ["achievement.research_master.name"] = "科研大师",
    ["achievement.research_master.desc"] = "研究所有科技",

    ["achievement.ship_builder.name"] = "造船大师",
    ["achievement.ship_builder.desc"] = "建造 {count} 艘舰船",

    ["achievement.fleet_admiral.name"] = "舰队提督",
    ["achievement.fleet_admiral.desc"] = "舰队总战力达到 {power}",

    ["achievement.trading_tycoon.name"] = "贸易大亨",
    ["achievement.trading_tycoon.desc"] = "完成 {count} 次星际贸易",

    ["achievement.guild_founder.name"] = "公会创始人",
    ["achievement.guild_founder.desc"] = "创建一个公会",

    ["achievement.campaign_hero.name"] = "战役英雄",
    ["achievement.campaign_hero.desc"] = "完成战役第一章",

    ["achievement.season_veteran.name"] = "赛季老兵",
    ["achievement.season_veteran.desc"] = "累计赛季积分达到 {points}",

    ["achievement.galactic_explorer.name"] = "银河探索者",
    ["achievement.galactic_explorer.desc"] = "探索 {count} 个星系",

    ["achievement.resource_baron.name"] = "资源大亨",
    ["achievement.resource_baron.desc"] = "累计收集 {amount} 资源",

    ["achievement.speed_runner.name"] = "速度之王",
    ["achievement.speed_runner.desc"] = "在 {time} 秒内完成任意战役",

    ["achievement.commander_elite.name"] = "精英指挥官",
    ["achievement.commander_elite.desc"] = "指挥官等级达到 {level}",

    ["achievement.perfectionist.name"] = "完美主义者",
    ["achievement.perfectionist.desc"] = "任意战役达成三星评价",

    ["achievement.survivor.name"] = "幸存者",
    ["achievement.survivor.desc"] = "在一艘舰船不沉的情况下通关波次 {wave}",

    -- ========================================================================
    -- 事件描述
    -- ========================================================================

    ["event.pirate_raid.name"] = "海盗突袭",
    ["event.pirate_raid.desc"] = "一支海盗舰队出现在你附近，做好战斗准备！",

    ["event.merchant_ship.name"] = "商船来访",
    ["event.merchant_ship.desc"] = "一艘友好的商船提供了稀有商品交易机会。",

    ["event.asteroid_field.name"] = "小行星带",
    ["event.asteroid_field.desc"] = "发现富含矿产的小行星带，可派出采矿队。",

    ["event.anomaly.name"] = "空间异常",
    ["event.anomaly.desc"] = "检测到未知空间异常，可能蕴含宝贵资源或危险。",

    ["event.distress_signal.name"] = "求救信号",
    ["event.distress_signal.desc"] = "接收到遇险船只的求救信号，是否前往救援？",

    ["event.nebulon.name"] = "星云奇观",
    ["event.nebulon.desc"] = "穿越一片美丽的星云，舰队获得短暂能量加成。",

    ["event.black_hole.name"] = "黑洞警告",
    ["event.black_hole.desc"] = "前方检测到黑洞引力场，务必谨慎通过！",

    ["event.ancient_ruins.name"] = "古代遗迹",
    ["event.ancient_ruins.desc"] = "发现失落文明的遗迹，或许藏有珍贵科技。",

    ["event.space_storm.name"] = "太空风暴",
    ["event.space_storm.desc"] = "强烈的离子风暴来袭，舰队机动性受到影响。",

    ["event.diplomatic_meeting.name"] = "外交会晤",
    ["event.diplomatic_meeting.desc"] = "友好势力发出外交邀请，可达成贸易协定。",

    ["event.supernova.name"] = "超新星爆发",
    ["event.supernova.desc"] = "附近恒星发生剧烈爆炸，辐射危害巨大！",

    ["event.derelict.name"] = "废弃舰船",
    ["event.derelict.desc"] = "发现一艘被遗弃的战舰，可能还有可用物资。",

    ["event.alien_contact.name"] = "外星接触",
    ["event.alien_contact.desc"] = "首次与未知外星文明接触，他们的意图尚不明朗。",

    ["event.bounty_hunter.name"] = "赏金猎人",
    ["event.bounty_hunter.desc"] = "你的悬赏已经被顶尖赏金猎人注意到了。",

    ["event.void_rift.name"] = "虚空裂隙",
    ["event.void_rift.desc"] = "空间出现神秘裂隙，从中涌出了异常能量生物。",

    ["event.comet_shower.name"] = "彗星雨",
    ["event.comet_shower.desc"] = "大量彗星划过星系，带来稀有冰核资源。",

    -- ========================================================================
    -- 指挥官技能文本
    -- ========================================================================

    ["commander.skill.tactical_genius.name"] = "战术天才",
    ["commander.skill.tactical_genius.desc"] = "全体舰船攻击力 +{value}%",

    ["commander.skill.defensive_mastery.name"] = "防御大师",
    ["commander.skill.defensive_mastery.desc"] = "全体舰船受到的伤害 -{value}%",

    ["commander.skill.logistics_expert.name"] = "后勤专家",
    ["commander.skill.logistics_expert.desc"] = "资源产出效率 +{value}%",

    ["commander.skill.engineering_wizard.name"] = "工程奇才",
    ["commander.skill.engineering_wizard.desc"] = "舰船建造时间 -{value}%",

    ["commander.skill.research_visionary.name"] = "科研远见",
    ["commander.skill.research_visionary.desc"] = "科技研究速度 +{value}%",

    ["commander.skill.diplomatic_charm.name"] = "外交魅力",
    ["commander.skill.diplomatic_charm.desc"] = "贸易收益 +{value}%",

    ["commander.skill.admiral_aura.name"] = "提督光环",
    ["commander.skill.admiral_aura.desc"] = "舰队总战力 +{value}%",

    ["commander.skill.lucky_star.name"] = "福星高照",
    ["commander.skill.lucky_star.desc"] = "稀有物品掉落率 +{value}%",

    ["commander.skill.rapid_deployment.name"] = "快速部署",
    ["commander.skill.rapid_deployment.desc"] = "舰队出征准备时间 -{value}%",

    ["commander.skill.resource_sense.name"] = "资源感知",
    ["commander.skill.resource_sense.desc"] = "探索发现资源概率 +{value}%",

    ["commander.skill.vanguard.name"] = "先锋指挥",
    ["commander.skill.vanguard.desc"] = "首波攻击额外 +{value}% 伤害",

    ["commander.skill.iron_will.name"] = "钢铁意志",
    ["commander.skill.iron_will.desc"] = "战损后仍保持 {value}% 战斗力",

    -- ========================================================================
    -- 科技名称与描述
    -- ========================================================================

    ["tech.deep_mining.name"] = "深层采矿",
    ["tech.deep_mining.desc"] = "提升矿井产量20%。利用深层钻探技术开采行星地核资源。",
    ["tech.solar_efficiency.name"] = "高效光伏",
    ["tech.solar_efficiency.desc"] = "电站产量+15%。改进光伏转化效率。",
    ["tech.crystal_process.name"] = "晶石精炼",
    ["tech.crystal_process.desc"] = "晶石加工效率提升20%。",
    ["tech.hull_alloy.name"] = "合金船壳",
    ["tech.hull_alloy.desc"] = "所有舰船耐久+25%。",
    ["tech.shield_reinforce.name"] = "护盾强化",
    ["tech.shield_reinforce.desc"] = "护盾值+100，防御+10%。",
    ["tech.rapid_refine.name"] = "快速精炼",
    ["tech.rapid_refine.desc"] = "舰船建造时间-15%。",
    ["tech.warp_drive.name"] = "曲速引擎",
    ["tech.warp_drive.desc"] = "舰队移动速度+50%。",
    ["tech.advanced_weapons.name"] = "高级武器系统",
    ["tech.advanced_weapons.desc"] = "所有战舰攻击力+30%。",
    ["tech.defense_matrix.name"] = "防御矩阵",
    ["tech.defense_matrix.desc"] = "舰队生命值+30%，护盾上限+20%。",
    ["tech.void_anchor.name"] = "虚空锚定",
    ["tech.void_anchor.desc"] = "敌方舰队移动速度-30%。",
    ["tech.nova_cannon.name"] = "新星炮",
    ["tech.nova_cannon.desc"] = "AOE半径+80%，全体伤害+50%。",
    ["tech.fortress_protocol.name"] = "要塞协议",
    ["tech.fortress_protocol.desc"] = "基地护盾最大值翻倍，每秒恢复1%基地护盾。",
    ["tech.quantum_core.name"] = "量子核心",
    ["tech.quantum_core.desc"] = "科研速度+50%，核心升级费用-20%。",
    ["tech.phase_drive.name"] = "相位驱动",
    ["tech.phase_drive.desc"] = "舰队速度再+50%，获得隐形能力。",
    ["tech.stellar_sync.name"] = "星际同步",
    ["tech.stellar_sync.desc"] = "全局产出+25%，科研+30%。",
    ["tech.stellar_engine.name"] = "恒星引擎",
    ["tech.stellar_engine.desc"] = "全局移动速度+60%，战斗开局获得初始加速。",
    ["tech.quantum_factory.name"] = "量子工厂",
    ["tech.quantum_factory.desc"] = "舰船建造速度翻倍，升级费用-25%。",
    ["tech.void_fleet.name"] = "虚空舰队",
    ["tech.void_fleet.desc"] = "敌方舰队生成-30%，敌舰伤害-20%。",
    ["tech.fortress_protocol_ii.name"] = "要塞协议II",
    ["tech.fortress_protocol_ii.desc"] = "基地护盾最大值3倍，每秒恢复2%，受攻击时触发反击护盾。",
    ["tech.chrono_research.name"] = "时序研究",
    ["tech.chrono_research.desc"] = "科研速度2.5倍，事件频率减半。",
    ["tech.galactic_ascend.name"] = "银河飞升",
    ["tech.galactic_ascend.desc"] = "全局伤害2倍，舰队上限+3，每波技能点+2，所有奖励翻倍。",

    -- ========================================================================
    -- 舰船类型名称与描述
    -- ========================================================================

    ["ship.fighter.name"] = "战斗机",
    ["ship.fighter.desc"] = "高速轻型舰船，擅长快速突击。",
    ["ship.corvette.name"] = "护卫舰",
    ["ship.corvette.desc"] = "平衡型舰船，适合侧翼支援。",
    ["ship.destroyer.name"] = "驱逐舰",
    ["ship.destroyer.desc"] = "主战舰船，正面突击的主力。",
    ["ship.battlecruiser.name"] = "战列巡洋舰",
    ["ship.battlecruiser.desc"] = "重型火力舰，后排输出核心。",
    ["ship.carrier.name"] = "航母",
    ["ship.carrier.desc"] = "舰载机平台，提供空中支援。",
    ["ship.void_lord.name"] = "虚空领主",
    ["ship.void_lord.desc"] = "终极战舰，碾压一切。",
    ["ship.devastator.name"] = "毁灭者",
    ["ship.devastator.desc"] = "末日武器，所到之处寸草不生。",
    ["ship.engineer.name"] = "工程维修舰",
    ["ship.engineer.desc"] = "支援舰，周期性为周围友舰修复生命。",
    ["ship.stealth.name"] = "隐形突击舰",
    ["ship.stealth.desc"] = "高爆发低生存，周期性进入隐形状态。",
    ["ship.railgun.name"] = "轨道炮舰",
    ["ship.railgun.desc"] = "超远程单体高伤，充能后发射轨道炮。",

    -- ========================================================================
    -- 战斗指令名称与描述
    -- ========================================================================

    ["battlecmd.focus_fire.name"] = "集火目标",
    ["battlecmd.focus_fire.desc"] = "全舰队集火指定目标：+50% 伤害，+100% 射速，持续 8 秒",
    ["battlecmd.defense_stance.name"] = "优先防御",
    ["battlecmd.defense_stance.desc"] = "舰队转入防御姿态：-30% 伤害，+50% 防御，持续 10 秒",
    ["battlecmd.tactical_retreat.name"] = "后撤重整",
    ["battlecmd.tactical_retreat.desc"] = "舰队后撤：+30% 移动速度，护盾 +40%，5 秒内无法攻击",
    ["battlecmd.full_salvo.name"] = "全弹发射",
    ["battlecmd.full_salvo.desc"] = "一次性发射所有武器：+200% 伤害，消耗所有技能充能",
    ["battlecmd.emergency_repair.name"] = "紧急修理",
    ["battlecmd.emergency_repair.desc"] = "紧急修复 30% 最大生命值，冷却 60 秒",

    -- ========================================================================
    -- Roguelike 卡牌名称与描述
    -- ========================================================================

    ["roguelike.attack_overdrive.name"] = "攻击过载",
    ["roguelike.attack_overdrive.desc"] = "所有舰船攻击力 +20%",
    ["roguelike.reinforced_armor.name"] = "强化装甲",
    ["roguelike.reinforced_armor.desc"] = "所有舰船防御 +25%",
    ["roguelike.phase_shield.name"] = "相位护盾",
    ["roguelike.phase_shield.desc"] = "护盾最大值 +30%，回复 +15%",
    ["roguelike.resource_boon.name"] = "资源恩惠",
    ["roguelike.resource_boon.desc"] = "基础资源产出 +40%",
    ["roguelike.hyperspeed.name"] = "超光速驱动",
    ["roguelike.hyperspeed.desc"] = "舰队移动速度 +35%，开火速率 +15%",
    ["roguelike.quantum_factory.name"] = "量子工厂",
    ["roguelike.quantum_factory.desc"] = "舰船建造速度 +50%，升级费用 -20%",
    ["roguelike.skill_charge.name"] = "战术充能",
    ["roguelike.skill_charge.desc"] = "战斗开始时技能充能 +2",
    ["roguelike.bloodlust.name"] = "嗜血狂热",
    ["roguelike.bloodlust.desc"] = "攻击力 +50%，但受到伤害 +25%",
    ["roguelike.bastion_protocol.name"] = "堡垒协议",
    ["roguelike.bastion_protocol.desc"] = "防御 +60%，护盾 +40%，但移动速度 -30%",
    ["roguelike.power_drain.name"] = "能量吞噬",
    ["roguelike.power_drain.desc"] = "资源产出 +100%，但每回合失去 5% 当前生命值",
    ["roguelike.overclock.name"] = "超频核心",
    ["roguelike.overclock.desc"] = "开火速率 +75%，但护盾回复 -50%",
    ["roguelike.battle_lust.name"] = "战意激荡",
    ["roguelike.battle_lust.desc"] = "每次击败敌舰回复 2% 最大生命值",
    ["roguelike.critical_mass.name"] = "临界质量",
    ["roguelike.critical_mass.desc"] = "暴击率 +20%，暴击伤害 +50%",
    ["roguelike.afterburner.name"] = "后燃推进",
    ["roguelike.afterburner.desc"] = "闪避率 +15%，首次受到致命伤害时免疫并回复 50% 生命值",
    ["roguelike.galactic_luck.name"] = "银河好运",
    ["roguelike.galactic_luck.desc"] = "每次选卡时额外获得 1 张卡选项",
    ["roguelike.void_strike.name"] = "虚空打击",
    ["roguelike.void_strike.desc"] = "所有攻击附带 10% 当前生命值的无视防御伤害",

    -- ========================================================================
    -- 游戏设置文本
    -- ========================================================================

    ["settings.audio"] = "音频",
    ["settings.graphics"] = "图像",
    ["settings.gameplay"] = "游戏性",
    ["settings.accessibility"] = "辅助功能",
    ["settings.language"] = "语言",
    ["settings.master_volume"] = "主音量",
    ["settings.music_volume"] = "音乐音量",
    ["settings.sfx_volume"] = "音效音量",
    ["settings.voice_volume"] = "语音音量",
    ["settings.graphics_quality"] = "画质",
    ["settings.resolution"] = "分辨率",
    ["settings.fullscreen"] = "全屏",
    ["settings.vsync"] = "垂直同步",
    ["settings.particle_effects"] = "粒子特效",
    ["settings.ambient_occlusion"] = "环境光遮蔽",
    ["settings.bloom"] = "泛光效果",
    ["settings.game_speed"] = "游戏速度",
    ["settings.autosave_interval"] = "自动保存间隔",
    ["settings.show_damage_numbers"] = "显示伤害数字",
    ["settings.show_tutorial_hints"] = "显示教程提示",
    ["settings.confirm_before_exit"] = "退出前确认",
    ["settings.colorblind_mode"] = "色盲模式",
    ["settings.colorblind_none"] = "无",
    ["settings.colorblind_red_green"] = "红绿色盲",
    ["settings.colorblind_blue_yellow"] = "蓝黄色盲",
    ["settings.font_size"] = "字体大小",
    ["settings.font_small"] = "小",
    ["settings.font_medium"] = "中",
    ["settings.font_large"] = "大",
    ["settings.high_contrast"] = "高对比度模式",
    ["settings.reduced_motion"] = "减少动画效果",
    ["settings.screen_shake"] = "屏幕震动",
    ["settings.damage_flash"] = "受伤闪烁",

    -- ========================================================================
    -- 难度名称与描述
    -- ========================================================================

    ["difficulty.easy.name"] = "简单",
    ["difficulty.easy.desc"] = "适合新手：敌人较弱，资源产出丰厚。",
    ["difficulty.normal.name"] = "普通",
    ["difficulty.normal.desc"] = "标准体验：平衡的挑战与收益。",
    ["difficulty.hard.name"] = "困难",
    ["difficulty.hard.desc"] = "高级挑战：敌人更强，资源更稀缺。",
    ["difficulty.nightmare.name"] = "噩梦",
    ["difficulty.nightmare.desc"] = "极限挑战：敌人极为强大，资源极度紧张。",

    -- ========================================================================
    -- 战役章节名称
    -- ========================================================================

    ["campaign.prologue.name"] = "序章：星火燎原",
    ["campaign.chapter1.name"] = "第一章：黑暗降临",
    ["campaign.chapter2.name"] = "第二章：帝国反击",
    ["campaign.stage.objective.assault"] = "突袭战",
    ["campaign.stage.objective.defend"] = "防守战",
    ["campaign.stage.objective.survive"] = "生存战",
    ["campaign.stage.objective.eliminate"] = "斩首行动",
    ["campaign.stage.objective.escort"] = "护送战",
    ["campaign.stage.difficulty.easy"] = "简单",
    ["campaign.stage.difficulty.medium"] = "普通",
    ["campaign.stage.difficulty.hard"] = "困难",
    ["campaign.stage.difficulty.extreme"] = "噩梦",

    -- ========================================================================
    -- 赛季文本
    -- ========================================================================

    ["season.current"] = "当前赛季",
    ["season.next"] = "下一赛季",
    ["season.ends_in"] = "剩余 {days} 天",
    ["season.points"] = "赛季积分",
    ["season.rank"] = "赛季排名",
    ["season.rewards"] = "赛季奖励",
    ["season.exclusive"] = "赛季限定",

    -- ========================================================================
    -- 银河事件文本（新增事件）
    -- ========================================================================

    ["event.stargate_open.name"] = "星门开启",
    ["event.stargate_open.desc"] = "星门开启，提供快速移动通道。",
    ["event.wormhole_appears.name"] = "虫洞出现",
    ["event.wormhole_appears.desc"] = "神秘虫洞连接两个遥远区域。",
    ["event.rare_mineral_discovery.name"] = "稀有矿物发现",
    ["event.rare_mineral_discovery.desc"] = "探测到稀有矿物资源，采矿效率大幅提升。",
    ["event.solar_storm.name"] = "太阳风暴",
    ["event.solar_storm.desc"] = "太阳风暴干扰电子设备。",
    ["event.trade_festival.name"] = "星际贸易节",
    ["event.trade_festival.desc"] = "贸易税全免，所有交易收益 +50%。",
    ["event.alien_contact.name"] = "外星接触",
    ["event.alien_contact.desc"] = "与神秘外星文明建立联系。",
    ["event.void_rift.name"] = "虚空裂隙",
    ["event.void_rift.desc"] = "空间出现神秘裂隙，涌出异常能量生物。",
    ["event.pirate_harbor.name"] = "海盗港",
    ["event.pirate_harbor.desc"] = "发现海盗藏身处，可缴获丰厚物资。",
    ["event.mercenary_offer.name"] = "佣兵招募",
    ["event.mercenary_offer.desc"] = "佣兵舰队提供协助，需要支付报酬。",
    ["event.ambush.name"] = "伏击预警",
    ["event.ambush.desc"] = "情报显示前方有伏击阵地，小心通过。",
    ["event.ancient_ruins.name"] = "远古遗迹",
    ["event.ancient_ruins.desc"] = "发现失落文明的遗迹，可能藏有珍贵科技。",
    ["event.abandoned_fleet.name"] = "废弃舰队",
    ["event.abandoned_fleet.desc"] = "发现被遗弃的战舰残骸，可打捞可用部件。",
    ["event.comet_shower.name"] = "彗星雨",
    ["event.comet_shower.desc"] = "大量彗星划过星系，带来稀有冰核资源。",
    ["event.nebula_passage.name"] = "星云穿越",
    ["event.nebula_passage.desc"] = "穿越神秘星云，舰队获得短暂能量加成。",
    ["event.wormhole_stable.name"] = "稳定虫洞",
    ["event.wormhole_stable.desc"] = "发现稳定的虫洞通道，大幅缩短航行时间。",
    ["event.distant_signal.name"] = "遥远信号",
    ["event.distant_signal.desc"] = "接收到来自深空的神秘信号，引导向未知区域。",
    ["event.diplomatic_gift.name"] = "外交礼物",
    ["event.diplomatic_gift.desc"] = "友好势力送来珍贵礼物。",
    ["event.trade_embargo.name"] = "贸易禁运",
    ["event.trade_embargo.desc"] = "银河经济动荡，贸易收益暂时降低。",
    ["event.guild_merger.name"] = "公会联盟",
    ["event.guild_merger.desc"] = "多个公会提议结盟，共同对抗威胁。",
    ["event.trade_storm.name"] = "贸易风暴",
    ["event.trade_storm.desc"] = "全星系市场价格剧烈波动。",
    ["event.mining_boom.name"] = "采矿繁荣期",
    ["event.mining_boom.desc"] = "矿区大丰收，矿物产量暴增。",
    ["event.crystal_swarm.name"] = "晶石潮汐",
    ["event.crystal_swarm.desc"] = "晶石矿脉异常活跃，产量大幅提升。",
    ["event.warp_anomaly.name"] = "曲速异常",
    ["event.warp_anomaly.desc"] = "曲速航行出现随机坐标偏移。",
    ["event.gateway_activation.name"] = "星门激活",
    ["event.gateway_activation.desc"] = "发现新的跃迁星门连接未知星系。",
    ["event.stellar_flare.name"] = "恒星耀斑",
    ["event.stellar_flare.desc"] = "近距离恒星爆发，释放巨大能量。",
    ["event.void_storm.name"] = "虚空风暴",
    ["event.void_storm.desc"] = "虚空能量风暴席卷整个星系，机遇与危险并存。",
    ["event.golden_age.name"] = "黄金时代",
    ["event.golden_age.desc"] = "银河进入繁荣期，所有产出大幅提升。",

    -- ========================================================================
    -- 资源类型文本
    -- ========================================================================

    ["resource.minerals"] = "矿石",
    ["resource.energy"] = "能源",
    ["resource.crystal"] = "晶石",
    ["resource.nuclear"] = "核能",
    ["resource.credits"] = "星币",
    ["resource.blue_crystal"] = "蓝晶",
    ["resource.purple_crystal"] = "紫晶",
    ["resource.rainbow_crystal"] = "彩虹晶",

    -- ========================================================================
    -- 战斗环境文本
    -- ========================================================================

    ["environment.asteroid_field.name"] = "小行星带",
    ["environment.asteroid_field.desc"] = "移动速度-30%，但提供20%掩体防护。",
    ["environment.nebula.name"] = "星云区",
    ["environment.nebula.desc"] = "隐形效果+50%，但探测范围-30%。",
    ["environment.solar_storm.name"] = "太阳风暴",
    ["environment.solar_storm.desc"] = "护盾效率-40%，能源恢复-20%。",
    ["environment.gravity_well.name"] = "重力井",
    ["environment.gravity_well.desc"] = "所有舰船和弹药速度减半。",
    ["environment.debris_field.name"] = "残骸区",
    ["environment.debris_field.desc"] = "提供40%掩体，20%几率从残骸获取资源。",
    ["environment.ion_storm.name"] = "离子风暴",
    ["environment.ion_storm.desc"] = "护盾恢复-50%，技能冷却+30%。",
    ["environment.warp_zone.name"] = "曲速区",
    ["environment.warp_zone.desc"] = "移动速度翻倍，技能冷却-30%。",
    ["environment.crystal_field.name"] = "晶体区",
    ["environment.crystal_field.desc"] = "护盾效率+30%，15%几率额外获得晶石。",

    -- ========================================================================
    -- 阵型文本
    -- ========================================================================

    ["formation.vanguard.name"] = "前卫阵型",
    ["formation.vanguard.desc"] = "舰船分散布置，减小AOE伤害。",
    ["formation.phalanx.name"] = "方阵",
    ["formation.phalanx.desc"] = "紧密排列，火力集中。",
    ["formation.flank.name"] = "两翼包抄",
    ["formation.flank.desc"] = "从侧翼进攻，机动性提升。",
    ["formation.crescent.name"] = "新月阵型",
    ["formation.crescent.desc"] = "弧形布置，兼顾攻防。",
    ["formation.pinzher.name"] = "钳形攻势",
    ["formation.pinzher.desc"] = "前后夹击，优先集火。",
    ["formation.skirmish.name"] = "游击阵型",
    ["formation.skirmish.desc"] = "保持距离，边打边退。",

    -- ========================================================================
    -- 快捷信号文本
    -- ========================================================================

    ["signal.rally"] = "集合",
    ["signal.retreat"] = "撤退",
    ["signal.help"] = "求救",
    ["signal.target"] = "标记目标",
    ["signal.attack"] = "进攻",
    ["signal.defend"] = "防守",
    ["signal.wait"] = "待命",
}
