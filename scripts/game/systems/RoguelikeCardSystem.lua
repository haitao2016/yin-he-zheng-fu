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
    },
    ---- V3.0 新增卡牌 ----
    {
        id = "VOID_RESONANCE",
        name = "虚空共振",
        desc = "虚空伤害 +30%，但每次攻击消耗 2% 最大生命值",
        icon = "icon_void_res",
        rarity = "epic",
        effect = { type = "tradeoff", stat = "voidDamageMult", value = 0.30, hpLossPerAttack = 0.02 }
    },
    {
        id = "FORTRESS_MASTERY",
        name = "要塞精通",
        desc = "护盾回复 +50%，防御塔伤害 +40%",
        icon = "icon_fortress",
        rarity = "uncommon",
        effect = { type = "buff", stat = "shieldRegen", value = 0.50, towerDamageMult = 0.40 }
    },
    {
        id = "RAPID_FIRE",
        name = "速射精通",
        desc = "攻击间隔 -25%，但每次攻击消耗额外 5% 能量",
        icon = "icon_rapid",
        rarity = "uncommon",
        effect = { type = "tradeoff", stat = "attackInterval", value = -0.25, energyCostMult = 0.05 }
    },
    {
        id = "SHIELD_WALL",
        name = "护盾壁垒",
        desc = "所有舰船获得 20% 临时护盾，每波重置",
        icon = "icon_shield_wall",
        rarity = "epic",
        effect = { type = "special", stat = "shieldWallPct", value = 0.20 }
    },
    {
        id = "ARSONIST",
        name = "纵火者",
        desc = "攻击附带灼烧，8秒内造成 50% 攻击力的持续伤害",
        icon = "icon_arson",
        rarity = "rare",
        effect = { type = "special", stat = "burnDamagePct", value = 0.50, burnDuration = 8 }
    },
    {
        id = "CHAIN_LIGHTNING",
        name = "链式闪电",
        desc = "攻击弹射 3 次，每次伤害 -30%",
        icon = "icon_lightning",
        rarity = "epic",
        effect = { type = "special", stat = "chainCount", value = 3, chainDamageFalloff = 0.30 }
    },
    {
        id = "TITAN_POWER",
        name = "泰坦之力",
        desc = "旗舰伤害 +80%，但移动速度 -50%",
        icon = "icon_titan",
        rarity = "rare",
        effect = { type = "tradeoff", stat = "flagshipDamageMult", value = 0.80, flagshipSpeedMult = -0.50 }
    },
    {
        id = "AEGISProtocol",
        name = "宙斯盾协议",
        desc = "全体护盾 +100%，护盾不被穿透",
        icon = "icon_aegis",
        rarity = "legendary",
        effect = { type = "special", stat = "shieldPierceImmune", value = true }
    },
    {
        id = "LOOT_HUNTER",
        name = "战利品猎人",
        desc = "击败敌舰额外掉落 +50% 几率获得资源",
        icon = "icon_loot",
        rarity = "uncommon",
        effect = { type = "special", stat = "lootDropChance", value = 0.50 }
    },
    {
        id = "SECOND_WIND",
        name = "绝处逢生",
        desc = "当舰队血量低于 20% 时，回复 50% 最大生命值（每局一次）",
        icon = "icon_secondwind",
        rarity = "legendary",
        effect = { type = "special", stat = "secondWindThreshold", value = 0.20, secondWindHealPct = 0.50 }
    },
    {
        id = "SHIELD_BURST",
        name = "护盾爆发",
        desc = "护盾耗尽时释放能量冲击波，伤害附近敌人",
        icon = "icon_shield_burst",
        rarity = "rare",
        effect = { type = "special", stat = "shieldBurstDmg", value = 0.30 }
    },
    {
        id = "ENERGY_SURGE",
        name = "能量涌动",
        desc = "能量上限 +60%，能量回复 +40%",
        icon = "icon_energy",
        rarity = "uncommon",
        effect = { type = "buff", stat = "energyMaxMult", value = 0.60, energyRegenMult = 0.40 }
    },
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

---@return RoguelikeCardSystem
function RoguelikeCardSystem.new()
    local self = setmetatable({}, RoguelikeCardSystem)
    self.selected = {}
    self.currentDraw = {}  -- 本次可选择的卡牌
    return self
end

--- 从卡池随机抽取 count 张卡（不重复，不与已选择的卡重复）
--- 会根据当前已选卡中的 extraCardDraw 效果增加抽卡数量
---@param count number
---@param gameState table
---@return table
function RoguelikeCardSystem:drawCards(count, gameState)
    count = count or 3
    -- 计算额外抽卡加成
    local extraDraws = 0
    if gameState and gameState.baseBonus then
        extraDraws = gameState.baseBonus.extraCardDraw or 0
    end
    local totalCount = count + extraDraws

    local pool = {}
    for _, c in ipairs(ROGUELIKE_CARDS) do
        if not self.selected[c.id] then
            local w = RarityWeight[c.rarity] or 10
            for _ = 1, w do pool[#pool + 1] = c end
        end
    end
    local result = {}
    local used = {}
    while #result < totalCount and #pool > 0 do
        local idx = math.random(1, #pool)
        local pick = pool[idx]
        if not used[pick.id] then
            used[pick.id] = true
            result[#result + 1] = pick
        end
        table.remove(pool, idx)
        if #pool == 0 and #result < totalCount then
            for _, c in ipairs(ROGUELIKE_CARDS) do
                if not used[c.id] then result[#result + 1] = c end
                if #result >= totalCount then break end
            end
            break
        end
    end
    self.currentDraw = result
    return result
end

--- 获取本次可选择的卡牌
---@return table
function RoguelikeCardSystem:getCurrentDraw()
    return self.currentDraw
end

--- 波次结束后触发选牌界面（集成用）
-- P0-3: 每 3 波触发一次选牌，第 1 波后必触发（玩家开局就能选卡）
---@param waveNum number
---@param gameState table
---@return table
function RoguelikeCardSystem:onWaveEnd(waveNum, gameState)
    if waveNum <= 0 then return {} end
    -- 第一波后必触发（给玩家首次选卡机会），之后每 3 波触发
    if waveNum == 1 or waveNum % 3 == 0 then
        local cards = self:drawCards(3, gameState)
        print("[Roguelike] 第 " .. waveNum .. " 波结束，刷新 " .. #cards .. " 张卡牌选项")
        return cards
    end
    return {}
end

--- 跳过当前卡牌选择（保留已选记录）
function RoguelikeCardSystem:skipCurrentDraw()
    self.currentDraw = {}
end

--- 应用选定卡牌
---@param cardId string
---@param gameState table
---@return boolean, string
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
        -- V3.0 新增字段处理
        if e.voidDamageMult then
            gameState.baseBonus.voidDamageMult = (gameState.baseBonus.voidDamageMult or 1.0) * (1 + e.voidDamageMult)
        end
        if e.hpLossPerAttack then
            gameState.baseBonus.hpLossPerAttack = (gameState.baseBonus.hpLossPerAttack or 0) + e.hpLossPerAttack
        end
        if e.towerDamageMult then
            gameState.baseBonus.towerDamageMult = (gameState.baseBonus.towerDamageMult or 1.0) * (1 + e.towerDamageMult)
        end
        if e.attackInterval then
            gameState.baseBonus.attackIntervalMult = (gameState.baseBonus.attackIntervalMult or 1.0) * (1 + e.attackInterval)
        end
        if e.energyCostMult then
            gameState.baseBonus.energyCostMult = (gameState.baseBonus.energyCostMult or 1.0) * (1 + e.energyCostMult)
        end
        if e.shieldWallPct then
            gameState.baseBonus.shieldWallPct = (gameState.baseBonus.shieldWallPct or 0) + e.shieldWallPct
        end
        if e.burnDamagePct then
            gameState.baseBonus.burnDamagePct = (gameState.baseBonus.burnDamagePct or 0) + e.burnDamagePct
        end
        if e.burnDuration then
            gameState.baseBonus.burnDuration = math.max(gameState.baseBonus.burnDuration or 0, e.burnDuration)
        end
        if e.chainCount then
            gameState.baseBonus.chainCount = math.max(gameState.baseBonus.chainCount or 0, e.chainCount)
        end
        if e.chainDamageFalloff then
            gameState.baseBonus.chainDamageFalloff = (gameState.baseBonus.chainDamageFalloff or 1.0) * (1 - e.chainDamageFalloff)
        end
        if e.flagshipDamageMult then
            gameState.baseBonus.flagshipDamageMult = (gameState.baseBonus.flagshipDamageMult or 1.0) * (1 + e.flagshipDamageMult)
        end
        if e.flagshipSpeedMult then
            gameState.baseBonus.flagshipSpeedMult = (gameState.baseBonus.flagshipSpeedMult or 1.0) * (1 + e.flagshipSpeedMult)
        end
        if e.shieldPierceImmune then
            gameState.baseBonus.shieldPierceImmune = true
        end
        if e.lootDropChance then
            gameState.baseBonus.lootDropChance = (gameState.baseBonus.lootDropChance or 0) + e.lootDropChance
        end
        if e.secondWindThreshold then
            gameState.baseBonus.secondWindThreshold = math.min(gameState.baseBonus.secondWindThreshold or 1.0, e.secondWindThreshold)
        end
        if e.secondWindHealPct then
            gameState.baseBonus.secondWindHealPct = (gameState.baseBonus.secondWindHealPct or 0) + e.secondWindHealPct
        end
        if e.shieldBurstDmg then
            gameState.baseBonus.shieldBurstDmg = (gameState.baseBonus.shieldBurstDmg or 0) + e.shieldBurstDmg
        end
        if e.energyMaxMult then
            gameState.baseBonus.energyMaxMult = (gameState.baseBonus.energyMaxMult or 1.0) * (1 + e.energyMaxMult)
        end
        if e.energyRegenMult then
            gameState.baseBonus.energyRegenMult = (gameState.baseBonus.energyRegenMult or 1.0) * (1 + e.energyRegenMult)
        end
        print("[Roguelike] 获得卡牌: " .. card.name)
    end
    return true, ""
end

--- 获取已选卡牌列表
---@return table
function RoguelikeCardSystem:getCardHistory()
    local list = {}
    for id, _ in pairs(self.selected) do
        local c = ROGUELIKE_CARDS_BY_ID[id]
        if c then list[#list + 1] = c end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---@return table
function RoguelikeCardSystem:serialize()
    local list = {}
    for id, _ in pairs(self.selected) do list[#list + 1] = id end
    return { selected = list }
end

---@param data table
function RoguelikeCardSystem:deserialize(data)
    self.selected = {}
    if data and data.selected then
        for _, id in ipairs(data.selected) do self.selected[id] = true end
    end
end

return RoguelikeCardSystem
