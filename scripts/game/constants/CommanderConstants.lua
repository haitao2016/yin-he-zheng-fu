---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
Constants/CommanderConstants.lua
指挥官系统常量
]]

local M = {}

-- ============================================================================
-- 指挥官角色定义
-- ============================================================================

M.COMMANDERS = {
    ["ADMIRAL_CHEN"] = {
        id = "ADMIRAL_CHEN", name = "陈将军", title = "帝国舰队指挥官",
        rarity = "LEGENDARY", faction = "EMPIRE", portrait = "commander_admiral_chen",
        unlocked = true, recruitCost = nil,
        skills = {
            { id = "TACTICAL_RETREAT", name = "战术撤退", desc = "紧急后撤，降低受到的伤害 50%，持续 5 秒",
              cooldown = 30, duration = 5, effect = { type = "DMG_REDUCTION", value = 0.5 },
              icon = "skill_retreat", hotkey = "Q" },
            { id = "EMPIRE_COMMAND", name = "帝国号令", desc = "提升所有友舰攻击力 25%，持续 8 秒",
              cooldown = 45, duration = 8, effect = { type = "ATK_BOOST", value = 0.25 },
              icon = "skill_command", hotkey = "W" },
        },
        passive = { id = "EMPIRE_LOGISTICS", name = "帝国后勤", desc = "所有舰船生产时间降低 15%",
                    effects = { buildSpeedMult = 0.85 } },
        lore = "陈将军是帝国最资深的指挥官，擅长以少胜多。在多次战役中展现出卓越的战术天赋。",
    },
    ["REBEL_LEADER"] = {
        id = "REBEL_LEADER", name = "艾琳·诺克斯", title = "自由联盟领袖",
        rarity = "LEGENDARY", faction = "REBEL", portrait = "commander_rebel_leader",
        unlocked = true, recruitCost = nil,
        skills = {
            { id = "INSPIRING_RALLY", name = "鼓舞士气", desc = "提升所有友舰攻击力 30%，持续 10 秒",
              cooldown = 40, duration = 10, effect = { type = "ATK_BOOST", value = 0.3 },
              icon = "skill_rally", hotkey = "Q" },
            { id = "REBEL_FRENZY", name = "叛军狂热", desc = "所有友舰攻击速度提升 50%，持续 6 秒",
              cooldown = 50, duration = 6, effect = { type = "ATK_SPEED_BOOST", value = 0.5 },
              icon = "skill_frenzy", hotkey = "W" },
        },
        passive = { id = "REBEL_SPIRIT", name = "叛军精神", desc = "低血量时（<30%），伤害提升 25%",
                    effects = { lowHpDmgBoost = 0.25 } },
        lore = "艾琳曾是帝国科学院的天才科学家，因反对帝国的暴政而起义，如今成为自由联盟的领袖。",
    },
    ["MERCENARY_BOSS"] = {
        id = "MERCENARY_BOSS", name = "雷克斯·沃克", title = "佣兵之王",
        rarity = "EPIC", faction = "NEUTRAL", portrait = "commander_mercenary",
        unlocked = false, recruitCost = { blueCrystal = 200 },
        skills = {
            { id = "CONTRACT_BREAKER", name = "毁约打击", desc = "对目标造成 300% 伤害的毁灭性打击",
              cooldown = 60, effect = { type = "EXECUTE", value = 3.0, targetEnemy = true },
              icon = "skill_breaker", hotkey = "Q" },
            { id = "GOLDEN_CONTRACT", name = "黄金契约", desc = "击杀敌人后恢复 15% 最大生命值",
              cooldown = 0, effect = { type = "LIFESTEAL_KILL", value = 0.15 },
              icon = "skill_contract", hotkey = nil },
        },
        passive = { id = "MERCENARY_TACTICS", name = "佣兵战术", desc = "击杀敌人后获得 10% 攻击加成，可叠加 5 层",
                    effects = { killStackAtk = { bonus = 0.1, maxStacks = 5, duration = 10 } } },
        lore = "雷克斯是最致命的佣兵，只为出价最高的人服务。他的战术冷酷而高效。",
    },
    ["SHADOW_ASSASSIN"] = {
        id = "SHADOW_ASSASSIN", name = "夜影", title = "幽灵舰队指挥官",
        rarity = "EPIC", faction = "REBEL", portrait = "commander_shadow",
        unlocked = false, recruitCost = { purpleCrystal = 30 },
        skills = {
            { id = "PHASE_SHIFT", name = "相位位移", desc = "瞬间传送到目标位置，短暂无敌",
              cooldown = 25, effect = { type = "TELEPORT", invulnDuration = 1.5 },
              icon = "skill_phase", hotkey = "Q" },
            { id = "SHADOW_STRIKE", name = "暗影打击", desc = "下一次攻击造成 500% 伤害",
              cooldown = 35, effect = { type = "NEXT_ATTACK_MULT", value = 5.0 },
              icon = "skill_shadow", hotkey = "W" },
        },
        passive = { id = "GHOST_PROTOCOL", name = "幽灵协议", desc = "隐形舰持续时间延长 30%",
                    effects = { stealthDurationMult = 1.3 } },
        lore = "夜影是一支神秘舰队的指挥官，擅长渗透和暗杀战术。",
    },
}

M.COMMANDER_RECRUITMENT = {
    FREE = { desc = "免费指挥官", guarantee = "COMMON", commanders = { "ADMIRAL_CHEN", "REBEL_LEADER" } },
    PREMIUM = { desc = "高级招募", cost = { blueCrystal = 500 }, guarantee = "RARE",
                chance = { EPIC = 0.15, LEGENDARY = 0.05 } },
    PREMIUM_PLUS = { desc = "高级+招募", cost = { rainbowCrystal = 10 }, guarantee = "EPIC",
                     chance = { LEGENDARY = 0.20 } },
}

M.CURRENT_COMMANDER = "ADMIRAL_CHEN"
M.COMMANDER_SKILL_COOLDOWNS = {}

return M
