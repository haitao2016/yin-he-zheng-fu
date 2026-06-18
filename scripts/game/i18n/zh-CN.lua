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
}
