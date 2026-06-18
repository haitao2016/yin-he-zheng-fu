---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-----------------------------------------------------------
-- RoguelikeCardSystem 无尽模式 3 选 1 卡牌系统
-----------------------------------------------------------
require("game.GameConstants")

ROGUELIKE_CARDS = {
    ---- 增益类 ----
    {
        id = "ATTACK_OVERDRIVE",
        name = "攻击过载",
        desc = "所有舰船攻击力 +20%",
        icon = "icon_attack",
        rarity = "common",
        effect = { type = "buff", stat = "attackMult", value = 0.20 }
    },
    {
        id = "REINFORCED_ARMOR",
        name = "强化装甲",
        desc = "所有舰船防御 +25%",
        icon = "icon_defense",
        rarity = "common",
        effect = { type = "buff", stat = "defenseMult", value = 0.25 }
    },
    {
        id = "PHASE_SHIELD",
        name = "相位护盾",
        desc = "护盾最大值 +30%，回复 +15%",
        icon = "icon_shield",
        rarity = "uncommon",
        effect = { type = "buff", stat = "shieldMaxMult", value = 0.30, shieldRegen = 0.15 }
    },
    {
        id = "RESOURCE_BOON",
        name = "资源恩惠",
        desc = "基础资源产出 +40%",
        icon = "icon_resource",
        rarity = "common",
        effect = { type = "buff", stat = "resourceProdMult", value = 0.40 }
    },
    {
        id = "HYPERSPEED",
        name = "超光速驱动",
        desc = "舰队移动速度 +35%，开火速率 +15%",
        icon = "icon_speed",
        rarity = "uncommon",
        effect = { type = "buff", stat = "speedMult", value = 0.35, fireRate = 0.15 }
    },
    {
        id = "QUANTUM_FACTORY",
        name = "量子工厂",
        desc = "舰船建造速度 +50%，升级费用 -20%",
        icon = "icon_build",
        rarity = "uncommon",
        effect = { type = "buff", stat = "buildSpeedMult", value = 0.50, upgradeCostMult = -0.20 }
    },
    {
        id = "SKILL_CHARGE",
        name = "战术充能",
        desc = "战斗开始时技能充能 +2",
        icon = "icon_skill",
        rarity = "uncommon",
        effect = { type = "buff", stat = "skillChargeBonus", value = 2 }
    },

    ---- 减益高回报类 ----
    {
        id = "BLOODLUST",
        name = "嗜血狂热",
        desc = "攻击力 +50%，但受到伤害 +25%",
        icon = "icon_bloodlust",
        rarity = "rare",
        effect = { type = "tradeoff", stat = "attackMult", value = 0.50, takeDamageMult = 0.25 }
    },
    {
        id = "BASTION_PROTOCOL",
        name = "堡垒协议",
        desc = "防御 +60%，护盾 +40%，但移动速度 -30%",
        icon = "icon_bastion",
        rarity = "rare",
        effect = { type = "tradeoff", stat = "defenseMult", value = 0.60, shieldMaxMult = 0.40, speedMult = -0.30 }
    },
    {
        id = "POWER_DRAIN",
        name = "能量吞噬",
        desc = "资源产出 +100%，但每回合失去 5% 当前生命值",
        icon = "icon_powerdrain",
        rarity = "rare",
        effect = { type = "tradeoff", stat = "resourceProdMult", value = 1.0, hpLossPerWave = 0.05 }
    },
    {
        id = "OVERCLOCK",
        name = "超频核心",
        desc = "开火速率 +75%，但护盾回复 -50%",
        icon = "icon_overclock",
        rarity = "rare",
        effect = { type = "tradeoff", stat = "fireRate", value = 0.75, shieldRegen = -0.50 }
    },

    ---- 特殊效果类 ----
    {
        id = "BATTLE_LUST",
        name = "战意激荡",
        desc = "每次击败敌舰回复 2% 最大生命值",
        icon = "icon_battlelust",
        rarity = "epic",
        effect = { type = "special", stat = "lifestealPct", value = 0.02 }
    },
    {
        id = "CRITICAL_MASS",
        name = "临界质量",
        desc = "暴击率 +20%，暴击伤害 +50%",
        icon = "icon_crit",
        rarity = "epic",
        effect = { type = "special", stat = "critChance", value = 0.20, critDamage = 0.50 }
    },
    {
        id = "AFTERBURNER",
        name = "后燃推进",
        desc = "闪避率 +15%，首次受到致命伤害时免疫并回复 50% 生命值",
        icon = "icon_afterburner",
        rarity = "legendary",
        effect = { type = "special", stat = "evasionChance", value = 0.15, onceRevivePct = 0.50 }
    },
    {
        id = "GALACTIC_LUCK",
        name = "银河好运",
        desc = "每次选卡时额外获得 1 张卡选项",
        icon = "icon_luck",
        rarity = "legendary",
        effect = { type = "special", stat = "extraCardDraw", value = 1 }
    },
    {
        id = "VOID_STRIKE",
        name = "虚空打击",
        desc = "所有攻击附带 10% 当前生命值的无视防御伤害",
        icon = "icon_void",
        rarity = "legendary",
        effect = { type = "special", stat = "trueDamagePct", value = 0.10 }
    }
}

local ROGUELIKE_CARDS_BY_ID = {}
for _, c in ipairs(ROGUELIKE_CARDS) do ROGUELIKE_CARDS_BY_ID[c.id] = c end

local RarityWeight = {
    common    = 60,
    uncommon  = 35,
    rare      = 20,
    epic      = 10,
    legendary = 4
}

local RoguelikeCardSystem = {}
RoguelikeCardSystem.__index = RoguelikeCardSystem

function RoguelikeCardSystem.new()
    local self = setmetatable({}, RoguelikeCardSystem)
    self.selected = {}
    return self
end

--- 从卡池随机抽取 count 张卡（不重复，不与已选择的卡重复）
function RoguelikeCardSystem:drawCards(count)
    count = count or 3
    local pool = {}
    for _, c in ipairs(ROGUELIKE_CARDS) do
        if not self.selected[c.id] then
            local w = RarityWeight[c.rarity] or 10
            for _ = 1, w do pool[#pool + 1] = c end
        end
    end
    local result = {}
    local used = {}
    while #result < count and #pool > 0 do
        local idx = math.random(1, #pool)
        local pick = pool[idx]
        if not used[pick.id] then
            used[pick.id] = true
            result[#result + 1] = pick
        end
        table.remove(pool, idx)
        if #pool == 0 and #result < count then
            for _, c in ipairs(ROGUELIKE_CARDS) do
                if not used[c.id] then result[#result + 1] = c end
                if #result >= count then break end
            end
            break
        end
    end
    return result
end

--- 应用选定卡牌
function RoguelikeCardSystem:applyCard(cardId, gameState)
    local card = ROGUELIKE_CARDS_BY_ID[cardId]
    if not card then return false, "未知卡牌" end
    if self.selected[cardId] then return false, "已选择该卡牌" end
    self.selected[cardId] = true
    if gameState then
        gameState.roguelikeCards = gameState.roguelikeCards or {}
        gameState.roguelikeCards[cardId] = true
        gameState.baseBonus = gameState.baseBonus or {}
        local e = card.effect
        if e.stat then
            gameState.baseBonus[e.stat] = (gameState.baseBonus[e.stat] or 0) + (e.value or 0)
        end
        if e.shieldRegen then
            gameState.baseBonus.shieldRegen = (gameState.baseBonus.shieldRegen or 0) + e.shieldRegen
        end
        if e.fireRate then
            gameState.baseBonus.fireRateMult = (gameState.baseBonus.fireRateMult or 0) + e.fireRate
        end
        if e.shieldMaxMult then
            gameState.baseBonus.shieldMaxMult = (gameState.baseBonus.shieldMaxMult or 1.0) * (1 + e.shieldMaxMult)
        end
        if e.upgradeCostMult then
            gameState.baseBonus.upgradeCostMult = (gameState.baseBonus.upgradeCostMult or 1.0) * (1 + e.upgradeCostMult)
        end
        if e.takeDamageMult then
            gameState.baseBonus.takeDamageMult = (gameState.baseBonus.takeDamageMult or 1.0) * (1 + e.takeDamageMult)
        end
        if e.speedMult then
            gameState.baseBonus.speedMult = (gameState.baseBonus.speedMult or 1.0) * (1 + e.speedMult)
        end
        if e.critChance then
            gameState.baseBonus.critChance = (gameState.baseBonus.critChance or 0) + e.critChance
        end
        if e.critDamage then
            gameState.baseBonus.critDamageBonus = (gameState.baseBonus.critDamageBonus or 0) + e.critDamage
        end
        if e.hpLossPerWave then
            gameState.baseBonus.hpLossPerWave = (gameState.baseBonus.hpLossPerWave or 0) + e.hpLossPerWave
        end
        if e.lifestealPct then
            gameState.baseBonus.lifestealPct = (gameState.baseBonus.lifestealPct or 0) + e.lifestealPct
        end
        if e.evasionChance then
            gameState.baseBonus.evasionChance = (gameState.baseBonus.evasionChance or 0) + e.evasionChance
        end
        if e.onceRevivePct then
            gameState.baseBonus.reviveAvailable = (gameState.baseBonus.reviveAvailable or 0) + 1
            gameState.baseBonus.revivePct = (gameState.baseBonus.revivePct or 0) + e.onceRevivePct
        end
        if e.extraCardDraw then
            gameState.baseBonus.extraCardDraw = (gameState.baseBonus.extraCardDraw or 0) + e.extraCardDraw
        end
        if e.trueDamagePct then
            gameState.baseBonus.trueDamagePct = (gameState.baseBonus.trueDamagePct or 0) + e.trueDamagePct
        end
        print("[Roguelike] 获得卡牌: " .. card.name)
    end
    return true, ""
end

--- 获取已选卡牌列表
function RoguelikeCardSystem:getCardHistory()
    local list = {}
    for id, _ in pairs(self.selected) do
        local c = ROGUELIKE_CARDS_BY_ID[id]
        if c then list[#list + 1] = c end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function RoguelikeCardSystem:serialize()
    local list = {}
    for id, _ in pairs(self.selected) do list[#list + 1] = id end
    return { selected = list }
end

function RoguelikeCardSystem:deserialize(data)
    self.selected = {}
    if data and data.selected then
        for _, id in ipairs(data.selected) do self.selected[id] = true end
    end
end

return RoguelikeCardSystem
