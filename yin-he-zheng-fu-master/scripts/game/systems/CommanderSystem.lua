-- ============================================================================
-- systems/CommanderSystem.lua  -- 指挥官养成系统
-- 扩展功能：指挥官属性、技能树、装备系统、羁绊系统
-- ============================================================================

local Systems = require("game.Systems")

local M = {}

local COMMANDER_MAX_LEVEL = 10
local COMMANDER_MAX_SLOTS = 6

local EXP_TABLE = {
    0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700,
}

local ATTR_TYPES = {
    ATTACK = "attack",
    DEFENSE = "defense",
    SPEED = "speed",
    CRIT = "crit",
    LEADERSHIP = "leadership",
}

local ATTR_NAMES = {
    [ATTR_TYPES.ATTACK] = "攻击",
    [ATTR_TYPES.DEFENSE] = "防御",
    [ATTR_TYPES.SPEED] = "速度",
    [ATTR_TYPES.CRIT] = "暴击",
    [ATTR_TYPES.LEADERSHIP] = "领导力",
}

local SPECS = {
    tactical = {
        name = "战术专家",
        icon = "⚔️",
        description = "精通战斗战术，提升舰队攻击力和暴击率",
        perLevel = { dmgMult = 0.03, critChance = 0.01 },
        skills = {
            { id = "tactical_1", name = "精准打击", level = 1, effect = "暴击率+5%", passive = true },
            { id = "tactical_2", name = "战术洞察", level = 3, effect = "攻击+10%", passive = true },
            { id = "tactical_3", name = "致命一击", level = 5, effect = "暴击伤害+50%", passive = true },
            { id = "tactical_4", name = "闪电突袭", level = 7, effect = "攻击速度+20%", passive = true },
            { id = "tactical_ult", name = "战术核弹", level = 10, effect = "对敌方全体造成大量伤害", passive = false, cooldown = 45 },
        },
    },
    defense = {
        name = "防御大师",
        icon = "🛡️",
        description = "擅长防御阵型，提升舰队生存能力",
        perLevel = { healthMult = 0.04, shieldEff = 0.02 },
        skills = {
            { id = "defense_1", name = "加固装甲", level = 1, effect = "护甲+10%", passive = true },
            { id = "defense_2", name = "护盾充能", level = 3, effect = "护盾回复+20%", passive = true },
            { id = "defense_3", name = "铁壁阵型", level = 5, effect = "伤害减免+15%", passive = true },
            { id = "defense_4", name = "紧急维修", level = 7, effect = "每秒回复1%生命", passive = true },
            { id = "defense_ult", name = "能量屏障", level = 10, effect = "为全体友军添加护盾", passive = false, cooldown = 60 },
        },
    },
    logistics = {
        name = "后勤专家",
        icon = "📦",
        description = "优化资源管理，提升资源获取和舰队效率",
        perLevel = { resourceMult = 0.05, repairEff = 0.03 },
        skills = {
            { id = "logistics_1", name = "资源回收", level = 1, effect = "战斗后资源+10%", passive = true },
            { id = "logistics_2", name = "快速修复", level = 3, effect = "维修速度+25%", passive = true },
            { id = "logistics_3", name = "高效补给", level = 5, effect = "燃料消耗-15%", passive = true },
            { id = "logistics_4", name = "战略储备", level = 7, effect = "资源上限+20%", passive = true },
            { id = "logistics_ult", name = "紧急空投", level = 10, effect = "立即获得大量资源", passive = false, cooldown = 90 },
        },
    },
}

local COMMANDER_NAMES = {
    "赵云", "关羽", "张飞", "马超", "黄忠", "魏延",
    "张辽", "徐晃", "张郃", "庞德", "于禁", "乐进",
    "周瑜", "陆逊", "吕蒙", "鲁肃", "甘宁", "太史慈",
    "诸葛亮", "司马懿", "郭嘉", "庞统", "荀彧", "贾诩",
}

local commanders_ = {}
local nextId_ = 1

local function randomName()
    return COMMANDER_NAMES[math.random(1, #COMMANDER_NAMES)]
end

local function expToNext(level)
    return EXP_TABLE[level] or math.huge
end

local function calculateAttributes(cmd)
    local baseAttrs = {
        attack = 10 + cmd.level * 2,
        defense = 8 + cmd.level * 1.5,
        speed = 5 + cmd.level * 0.5,
        crit = 5 + cmd.level * 0.5,
        leadership = 1 + cmd.level * 0.1,
    }
    
    if cmd.spec and SPECS[cmd.spec] then
        local spec = SPECS[cmd.spec]
        if spec.perLevel then
            if spec.perLevel.dmgMult then
                baseAttrs.attack = baseAttrs.attack * (1 + spec.perLevel.dmgMult * cmd.level)
            end
            if spec.perLevel.healthMult then
                baseAttrs.defense = baseAttrs.defense * (1 + spec.perLevel.healthMult * cmd.level)
            end
        end
    end
    
    return baseAttrs
end

function M.GetAll()
    return commanders_
end

function M.GetById(id)
    for _, cmd in ipairs(commanders_) do
        if cmd.id == id then return cmd end
    end
    return nil
end

function M.GetByFleet(fleetId)
    for _, cmd in ipairs(commanders_) do
        if cmd.fleetId == fleetId then return cmd end
    end
    return nil
end

function M.Count()
    return #commanders_
end

function M.CanRecruit()
    return #commanders_ < COMMANDER_MAX_SLOTS
end

function M.Recruit(source, customName)
    if #commanders_ >= COMMANDER_MAX_SLOTS then
        return nil, string.format("指挥官已满（上限%d人）", COMMANDER_MAX_SLOTS)
    end
    local cmd = {
        id = nextId_,
        name = customName or randomName(),
        level = 1,
        exp = 0,
        spec = nil,
        source = source,
        fleetId = nil,
        skillCooldown = 0,
        skills = {},
        equipment = { weapon = nil, armor = nil, accessory = nil },
        bonds = {},
        attrs = calculateAttributes({ level = 1, spec = nil }),
    }
    nextId_ = nextId_ + 1
    commanders_[#commanders_ + 1] = cmd
    print(string.format("[Commander] 招募: %s (来源=%s)", cmd.name, source))
    return cmd, string.format("🎖 新指挥官 %s 加入！", cmd.name)
end

function M.AddExp(cmdId, amount)
    local cmd = M.GetById(cmdId)
    if not cmd or cmd.level >= COMMANDER_MAX_LEVEL then return false end
    cmd.exp = cmd.exp + amount
    local leveledUp = false
    while cmd.level < COMMANDER_MAX_LEVEL and cmd.exp >= expToNext(cmd.level) do
        cmd.exp = cmd.exp - expToNext(cmd.level)
        cmd.level = cmd.level + 1
        cmd.attrs = calculateAttributes(cmd)
        M.UnlockSkills(cmd)
        leveledUp = true
        print(string.format("[Commander] %s 升级! Lv%d", cmd.name, cmd.level))
    end
    if cmd.level >= COMMANDER_MAX_LEVEL then
        cmd.exp = 0
    end
    return leveledUp
end

function M.ChooseSpec(cmdId, specKey)
    local cmd = M.GetById(cmdId)
    if not cmd then return false, "指挥官不存在" end
    if cmd.level < 3 then return false, "需要达到3级才能选择专精" end
    if cmd.spec then return false, "已选择专精，无法更改" end
    if not SPECS[specKey] then return false, "无效的专精类型" end
    cmd.spec = specKey
    cmd.attrs = calculateAttributes(cmd)
    M.UnlockSkills(cmd)
    local specDef = SPECS[specKey]
    print(string.format("[Commander] %s 选择专精: %s %s", cmd.name, specDef.icon, specDef.name))
    return true, string.format("%s 选择了 %s %s！", cmd.name, specDef.icon, specDef.name)
end

function M.AssignToFleet(cmdId, fleetId)
    local cmd = M.GetById(cmdId)
    if not cmd then return false, "指挥官不存在" end
    if fleetId then
        for _, other in ipairs(commanders_) do
            if other.id ~= cmdId and other.fleetId == fleetId then
                other.fleetId = nil
            end
        end
    end
    cmd.fleetId = fleetId
    return true, fleetId and string.format("%s 已分配到编队%d", cmd.name, fleetId) or
                            string.format("%s 已解除编队分配", cmd.name)
end

function M.Retire(cmdId)
    local cmd = M.GetById(cmdId)
    if not cmd then return 0, "指挥官不存在" end
    local points = 50 + cmd.level * 10
    for i, c in ipairs(commanders_) do
        if c.id == cmdId then
            table.remove(commanders_, i)
            break
        end
    end
    print(string.format("[Commander] %s 退役，获得%d文明积分", cmd.name, points))
    return points, string.format("🏅 %s 光荣退役！获得 %d 文明积分", cmd.name, points)
end

function M.UnlockSkills(cmd)
    if not cmd.spec or not SPECS[cmd.spec] then return end
    local specSkills = SPECS[cmd.spec].skills
    for _, skill in ipairs(specSkills) do
        if cmd.level >= skill.level then
            local alreadyUnlocked = false
            for _, unlocked in ipairs(cmd.skills) do
                if unlocked.id == skill.id then
                    alreadyUnlocked = true
                    break
                end
            end
            if not alreadyUnlocked then
                cmd.skills[#cmd.skills + 1] = {
                    id = skill.id,
                    name = skill.name,
                    level = skill.level,
                    effect = skill.effect,
                    passive = skill.passive,
                    cooldown = skill.cooldown or 0,
                    currentCooldown = 0,
                }
                print(string.format("[Commander] %s 解锁技能: %s", cmd.name, skill.name))
            end
        end
    end
end

function M.ActivateSkill(cmdId, skillId)
    local cmd = M.GetById(cmdId)
    if not cmd then return false, "指挥官不存在" end
    
    local skill = nil
    for _, s in ipairs(cmd.skills) do
        if s.id == skillId then
            skill = s
            break
        end
    end
    
    if not skill then return false, "技能未解锁" end
    if skill.passive then return false, "被动技能无需激活" end
    if skill.currentCooldown > 0 then return false, "技能冷却中" end
    
    skill.currentCooldown = skill.cooldown
    print(string.format("[Commander] %s 激活技能: %s", cmd.name, skill.name))
    return true, skill
end

function M.EquipItem(cmdId, slot, item)
    local cmd = M.GetById(cmdId)
    if not cmd then return false, "指挥官不存在" end
    if not slot or not cmd.equipment[slot] then return false, "无效装备槽位" end
    
    cmd.equipment[slot] = item
    cmd.attrs = calculateAttributes(cmd)
    
    if item and item.attrs then
        for attr, value in pairs(item.attrs) do
            if cmd.attrs[attr] then
                cmd.attrs[attr] = cmd.attrs[attr] + value
            end
        end
    end
    
    return true, string.format("%s 装备了 %s", cmd.name, item and item.name or "空")
end

function M.AddBond(cmdId, targetCmdId)
    local cmd = M.GetById(cmdId)
    local target = M.GetById(targetCmdId)
    if not cmd or not target then return false, "指挥官不存在" end
    
    for _, bond in ipairs(cmd.bonds) do
        if bond == targetCmdId then return false, "羁绊已存在" end
    end
    
    cmd.bonds[#cmd.bonds + 1] = targetCmdId
    target.bonds[#target.bonds + 1] = cmdId
    
    print(string.format("[Commander] %s 与 %s 建立羁绊", cmd.name, target.name))
    return true, string.format("%s 与 %s 建立了羁绊！", cmd.name, target.name)
end

function M.GetBondBonus(cmdId)
    local cmd = M.GetById(cmdId)
    if not cmd then return 0 end
    
    local bonus = 0
    for _, bondId in ipairs(cmd.bonds) do
        local target = M.GetById(bondId)
        if target and target.fleetId == cmd.fleetId then
            bonus = bonus + 0.05
        end
    end
    
    return bonus
end

function M.GetPassiveBonus(cmdId)
    local bonus = { dmgMult = 1.0, healthMult = 1.0, resourceMult = 1.0, critChance = 0.05 }
    local cmd = M.GetById(cmdId)
    if not cmd then return bonus end
    
    bonus.dmgMult = bonus.dmgMult + (cmd.attrs.attack or 10) * 0.01
    bonus.healthMult = bonus.healthMult + (cmd.attrs.defense or 8) * 0.01
    bonus.critChance = bonus.critChance + (cmd.attrs.crit or 5) * 0.01
    
    if cmd.spec and SPECS[cmd.spec] then
        local spec = SPECS[cmd.spec]
        if spec.perLevel then
            if spec.perLevel.dmgMult then
                bonus.dmgMult = bonus.dmgMult + spec.perLevel.dmgMult * cmd.level
            end
            if spec.perLevel.healthMult then
                bonus.healthMult = bonus.healthMult + spec.perLevel.healthMult * cmd.level
            end
            if spec.perLevel.resourceMult then
                bonus.resourceMult = bonus.resourceMult + spec.perLevel.resourceMult * cmd.level
            end
            if spec.perLevel.critChance then
                bonus.critChance = bonus.critChance + spec.perLevel.critChance * cmd.level
            end
        end
    end
    
    local bondBonus = M.GetBondBonus(cmdId)
    bonus.dmgMult = bonus.dmgMult + bondBonus
    bonus.healthMult = bonus.healthMult + bondBonus
    
    return bonus
end

function M.GetFleetBonus(fleetId)
    local cmd = M.GetByFleet(fleetId)
    if not cmd then
        return { dmgMult = 1.0, healthMult = 1.0, resourceMult = 1.0, critChance = 0.05 }
    end
    return M.GetPassiveBonus(cmd.id)
end

function M.Update(dt)
    for _, cmd in ipairs(commanders_) do
        if cmd.skillCooldown > 0 then
            cmd.skillCooldown = math.max(0, cmd.skillCooldown - dt)
        end
        for _, skill in ipairs(cmd.skills) do
            if skill.currentCooldown > 0 then
                skill.currentCooldown = math.max(0, skill.currentCooldown - dt)
            end
        end
    end
end

function M.OnBattleEnd(fleetId, kills, waves, victory)
    local cmd = M.GetByFleet(fleetId)
    if not cmd then return false end
    
    local expGain = kills * 3 + waves * 8
    if victory then expGain = expGain * 2 end
    if expGain < 1 then expGain = 1 end
    
    print(string.format("[Commander] %s 战斗经验 +%d (击杀%d×3 + 波次%d×8 %s)",
        cmd.name, expGain, kills, waves, victory and "×2胜利加成" or ""))
    return M.AddExp(cmd.id, expGain)
end

function M.Serialize()
    local data = { nextId = nextId_, commanders = {} }
    for _, cmd in ipairs(commanders_) do
        data.commanders[#data.commanders + 1] = {
            id = cmd.id,
            name = cmd.name,
            level = cmd.level,
            exp = cmd.exp,
            spec = cmd.spec,
            source = cmd.source,
            fleetId = cmd.fleetId,
            skills = cmd.skills,
            equipment = cmd.equipment,
            bonds = cmd.bonds,
        }
    end
    return data
end

function M.Deserialize(data)
    if not data then return end
    nextId_ = data.nextId or 1
    commanders_ = {}
    for _, cmdData in ipairs(data.commanders or {}) do
        local cmd = {
            id = cmdData.id,
            name = cmdData.name,
            level = cmdData.level or 1,
            exp = cmdData.exp or 0,
            spec = cmdData.spec,
            source = cmdData.source,
            fleetId = cmdData.fleetId,
            skills = cmdData.skills or {},
            equipment = cmdData.equipment or { weapon = nil, armor = nil, accessory = nil },
            bonds = cmdData.bonds or {},
            skillCooldown = 0,
        }
        cmd.attrs = calculateAttributes(cmd)
        commanders_[#commanders_ + 1] = cmd
    end
end

function M.GetSpecs()
    return SPECS
end

function M.GetExpTable()
    return EXP_TABLE
end

function M.GetAttrTypes()
    return ATTR_TYPES
end

function M.GetAttrNames()
    return ATTR_NAMES
end

function M.GetMaxLevel()
    return COMMANDER_MAX_LEVEL
end

function M.GetMaxSlots()
    return COMMANDER_MAX_SLOTS
end

return M