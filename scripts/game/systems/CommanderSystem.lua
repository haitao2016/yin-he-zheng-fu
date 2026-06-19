---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/CommanderSystem.lua -- 指挥官系统
-- V2.8 P0-5
-- ============================================================================

local CommanderSystem = {}

-- ============================================================================
-- 指挥官运行时状态
-- ============================================================================

local CommanderState = {
    unlockedCommanders = { "ADMIRAL_CHEN", "REBEL_LEADER" },
    selectedCommander = "ADMIRAL_CHEN",
    skillCooldowns = {},
    passiveBuffs = {},
    killStacks = {},
}

-- ============================================================================
-- 指挥官查询
-- ============================================================================

-- 获取所有指挥官
function CommanderSystem.getAllCommanders()
    local commanders = {}
    for id, cmd in pairs(COMMANDERS) do
        table.insert(commanders, {
            id = id,
            name = cmd.name,
            title = cmd.title,
            rarity = cmd.rarity,
            faction = cmd.faction,
            portrait = cmd.portrait,
            unlocked = CommanderState.unlockedCommanders[id] == true,
            recruitCost = cmd.recruitCost,
            lore = cmd.lore,
        })
    end
    return commanders
end

-- 获取指挥官信息
function CommanderSystem.getCommander(commanderId)
    local cmd = COMMANDERS[commanderId]
    if not cmd then return nil end

    return {
        id = cmd.id,
        name = cmd.name,
        title = cmd.title,
        rarity = cmd.rarity,
        faction = cmd.faction,
        portrait = cmd.portrait,
        unlocked = CommanderState.unlockedCommanders[commanderId] == true,
        recruitCost = cmd.recruitCost,
        skills = cmd.skills,
        passive = cmd.passive,
        lore = cmd.lore,
    }
end

-- 获取当前指挥官
function CommanderSystem.getCurrentCommander()
    return CommanderSystem.getCommander(CommanderState.selectedCommander)
end

-- 检查是否已解锁
function CommanderSystem.isUnlocked(commanderId)
    return CommanderState.unlockedCommanders[commanderId] == true
end

-- ============================================================================
-- V3.2 P1-2: 指挥官图鉴（Codex）
-- ============================================================================

-- 图鉴进度统计
function CommanderSystem.getCodex()
    local all = {}
    local unlockedCount = 0
    local totalCount = 0

    for id, cmd in pairs(COMMANDERS) do
        totalCount = totalCount + 1
        local unlocked = CommanderState.unlockedCommanders[id] == true
        if unlocked then unlockedCount = unlockedCount + 1 end

        table.insert(all, {
            id = id,
            name = cmd.name or id,
            title = cmd.title or "",
            rarity = cmd.rarity or "COMMON",
            faction = cmd.faction or "",
            portrait = cmd.portrait or "",
            lore = cmd.lore or "",
            unlocked = unlocked,
            recruitCost = cmd.recruitCost,
            skills = cmd.skills and #cmd.skills or 0,
            isSelected = CommanderState.selectedCommander == id,
            -- 技能树进度（如果当前选中）
            skillTreeProgress = cmd.skillTree and {
                totalNodes = #cmd.skillTree,
                unlockedNodes = CommanderSkillTreeState.unlockedNodes[id] and (function()
                    local cnt = 0
                    for _, _ in pairs(CommanderSkillTreeState.unlockedNodes[id]) do cnt = cnt + 1 end
                    return cnt
                end)() or 0,
                availablePoints = CommanderSkillTreeState.skillPoints[id] or 0,
            } or nil,
        })
    end

    table.sort(all, function(a, b)
        local rarityOrder = { LEGENDARY = 1, EPIC = 2, RARE = 3, COMMON = 4 }
        local ra = rarityOrder[a.rarity] or 5
        local rb = rarityOrder[b.rarity] or 5
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)

    return {
        commanders = all,
        total = totalCount,
        unlocked = unlockedCount,
        completionPercent = totalCount > 0 and math.floor(unlockedCount / totalCount * 100) or 0,
    }
end

-- 按稀有度分组
function CommanderSystem.getCodexByRarity()
    local codex = CommanderSystem.getCodex()
    local groups = {
        LEGENDARY = {},
        EPIC = {},
        RARE = {},
        COMMON = {},
    }
    for _, c in ipairs(codex.commanders) do
        if groups[c.rarity] then
            table.insert(groups[c.rarity], c)
        else
            table.insert(groups.COMMON, c)
        end
    end
    return groups
end

-- 图鉴快速切换选择（点击图鉴中某一指挥官直接切换）
function CommanderSystem.selectFromCodex(commanderId)
    if not COMMANDERS[commanderId] then
        return false, "指挥官不存在"
    end
    if CommanderState.unlockedCommanders[commanderId] ~= true then
        return false, "指挥官未解锁"
    end
    return CommanderSystem.selectCommander(commanderId)
end

-- ============================================================================
-- 指挥官选择
-- ============================================================================

-- 选择指挥官
function CommanderSystem.selectCommander(commanderId)
    if not COMMANDERS[commanderId] then
        return false, "指挥官不存在"
    end

    if not CommanderState.unlockedCommanders[commanderId] then
        return false, "指挥官未解锁"
    end

    CommanderState.selectedCommander = commanderId

    -- 应用被动技能效果
    CommanderSystem.applyPassiveEffects()

    return true, "已选择 " .. COMMANDERS[commanderId].name
end

-- ============================================================================
-- 指挥官招募
-- ============================================================================

-- 招募指挥官
function CommanderSystem.recruitCommander(commanderId)
    local cmd = COMMANDERS[commanderId]
    if not cmd then
        return false, "指挥官不存在"
    end

    if CommanderState.unlockedCommanders[commanderId] then
        return false, "已拥有该指挥官"
    end

    if cmd.recruitCost then
        -- 检查资源
        local RM = require("game.systems.ResourceManager")
        if RM then
            for resource, amount in pairs(cmd.recruitCost) do
                if resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal" then
                    if not RM.canAffordRare(resource, amount) then
                        return false, "资源不足"
                    end
                end
            end
            -- 消耗资源
            for resource, amount in pairs(cmd.recruitCost) do
                if resource == "blueCrystal" or resource == "purpleCrystal" or resource == "rainbowCrystal" then
                    RM:spendRare(resource, amount)
                end
            end
        end
    end

    -- 解锁指挥官
    CommanderState.unlockedCommanders[commanderId] = true

    -- 保存
    CommanderSystem.saveState()

    return true, "招募成功: " .. cmd.name
end

-- 高级招募
function CommanderSystem.premiumRecruit(recruitType)
    local recruit = COMMANDER_RECRUITMENT[recruitType]
    if not recruit then
        return false, "招募类型不存在"
    end

    -- 检查资源
    if recruit.cost then
        local RM = require("game.systems.ResourceManager")
        if RM then
            for resource, amount in pairs(recruit.cost) do
                if resource == "blueCrystal" then
                    if not RM.canAffordRare(resource, amount) then
                        return false, "资源不足"
                    end
                elseif resource == "rainbowCrystal" then
                    if not RM.canAffordRare(resource, amount) then
                        return false, "资源不足"
                    end
                end
            end
            -- 消耗资源
            for resource, amount in pairs(recruit.cost) do
                if resource == "blueCrystal" or resource == "rainbowCrystal" then
                    RM:spendRare(resource, amount)
                end
            end
        end
    end

    -- 随机抽取
    local candidates = {}
    for id, cmd in pairs(COMMANDERS) do
        if not CommanderState.unlockedCommanders[id] then
            local rarityMatch = true
            if recruit.guarantee == "RARE" and cmd.rarity == "COMMON" then
                rarityMatch = false
            elseif recruit.guarantee == "EPIC" and (cmd.rarity == "COMMON" or cmd.rarity == "RARE") then
                rarityMatch = false
            end
            if rarityMatch then
                table.insert(candidates, { id = id, rarity = cmd.rarity, weight = 1 })
            end
        end
    end

    if #candidates == 0 then
        return false, "没有可招募的指挥官"
    end

    -- 按稀有度权重随机
    local totalWeight = 0
    for _, c in ipairs(candidates) do
        if c.rarity == "LEGENDARY" then c.weight = 10
        elseif c.rarity == "EPIC" then c.weight = 5
        elseif c.rarity == "RARE" then c.weight = 2
        else c.weight = 1 end
        totalWeight = totalWeight + c.weight
    end

    local roll = math.random() * totalWeight
    local selected = candidates[1]
    local accumulated = 0

    for _, c in ipairs(candidates) do
        accumulated = accumulated + c.weight
        if roll <= accumulated then
            selected = c
            break
        end
    end

    -- 解锁指挥官
    CommanderState.unlockedCommanders[selected.id] = true
    CommanderSystem.saveState()

    local cmd = COMMANDERS[selected.id]
    return true, "招募成功: " .. cmd.name .. " (" .. cmd.rarity .. ")", selected.id
end

-- ============================================================================
-- 指挥官技能
-- ============================================================================

-- 获取当前指挥官技能
function CommanderSystem.getSkills()
    local cmd = COMMANDERS[CommanderState.selectedCommander]
    if not cmd then return {} end

    local skills = {}
    for _, skill in ipairs(cmd.skills) do
        local cooldown = CommanderState.skillCooldowns[skill.id] or 0
        table.insert(skills, {
            id = skill.id,
            name = skill.name,
            desc = skill.desc,
            cooldown = skill.cooldown,
            currentCooldown = cooldown,
            ready = cooldown <= 0,
            hotkey = skill.hotkey,
            icon = skill.icon,
            effect = skill.effect,
        })
    end
    return skills
end

-- 使用技能
function CommanderSystem.useSkill(skillId, ctx)
    local cmd = COMMANDERS[CommanderState.selectedCommander]
    if not cmd then return false, "指挥官不存在" end

    local skill = nil
    for _, s in ipairs(cmd.skills) do
        if s.id == skillId then skill = s; break end
    end
    if not skill then return false, "技能不存在" end

    -- 检查冷却
    local currentCooldown = CommanderState.skillCooldowns[skillId] or 0
    if currentCooldown > 0 then
        return false, "技能冷却中"
    end

    -- 应用技能效果
    CommanderSystem.applySkillEffect(skill, ctx)

    -- 设置冷却
    CommanderState.skillCooldowns[skillId] = skill.cooldown

    -- 保存
    CommanderSystem.saveState()

    return true, "技能已激活: " .. skill.name
end

-- 应用技能效果
function CommanderSystem.applySkillEffect(skill, ctx)
    local effect = skill.effect

    if not ctx then ctx = {} end

    if effect.type == "DMG_REDUCTION" then
        -- 降低伤害效果
        ctx.applyBuff = ctx.applyBuff or function(buff)
            if BS and BS.playerFleet then
                for _, ship in ipairs(BS.playerFleet) do
                    ship.dmgReductionBuff = ship.dmgReductionBuff or 0
                    ship.dmgReductionBuff = ship.dmgReductionBuff + (effect.value or 0.5)
                    ship.dmgReductionTimer = skill.duration or 5
                end
            end
        end
        ctx.applyBuff()

    elseif effect.type == "ATK_BOOST" then
        -- 提升攻击力
        ctx.applyBuff = ctx.applyBuff or function(buff)
            if BS and BS.playerFleet then
                for _, ship in ipairs(BS.playerFleet) do
                    ship.atkBoostBuff = ship.atkBoostBuff or 0
                    ship.atkBoostBuff = ship.atkBoostBuff + (effect.value or 0.25)
                    ship.atkBoostTimer = skill.duration or 8
                end
            end
        end
        ctx.applyBuff()

    elseif effect.type == "ATK_SPEED_BOOST" then
        -- 提升攻击速度
        ctx.applyBuff = ctx.applyBuff or function(buff)
            if BS and BS.playerFleet then
                for _, ship in ipairs(BS.playerFleet) do
                    ship.atkSpeedBoost = ship.atkSpeedBoost or 0
                    ship.atkSpeedBoost = ship.atkSpeedBoost + (effect.value or 0.5)
                    ship.atkSpeedBoostTimer = skill.duration or 6
                end
            end
        end
        ctx.applyBuff()

    elseif effect.type == "EXECUTE" then
        -- 毁灭打击 - 对高血量敌人造成高伤害
        if effect.targetEnemy and BS and BS.enemyFleet then
            local target = BS.enemyFleet[1]
            if target then
                local damage = target.health * (effect.value - 1)  -- 造成 (value-1) 倍当前生命值的额外伤害
                BattleSystem = BattleSystem or require("game.battle.BattleSystem")
                if BattleSystem and BattleSystem.dealDamage then
                    BattleSystem.dealDamage(target, damage)
                end
            end
        end

    elseif effect.type == "LIFESTEAL_KILL" then
        -- 击杀回复生命
        -- (在 onEnemyKilled 事件中处理)

    elseif effect.type == "TELEPORT" then
        -- 传送 - 暂时无敌
        if BS and BS.playerFleet then
            for _, ship in ipairs(BS.playerFleet) do
                ship.invulnerableTimer = effect.invulnDuration or 1.5
                ship.visible = false
            end
        end

    elseif effect.type == "NEXT_ATTACK_MULT" then
        -- 下次攻击加成
        if BS and BS.playerFleet then
            for _, ship in ipairs(BS.playerFleet) do
                ship.nextAttackMult = (ship.nextAttackMult or 1) * (effect.value or 5)
            end
        end
    end

    -- 显示技能激活提示
    if NotifyPanel then
        NotifyPanel.push({
            type = "SKILL",
            title = "技能激活",
            message = skill.name,
            icon = skill.icon,
        })
    end
end

-- 更新技能冷却
function CommanderSystem.updateCooldowns(dt)
    local changed = false
    for skillId, cooldown in pairs(CommanderState.skillCooldowns) do
        if cooldown > 0 then
            CommanderState.skillCooldowns[skillId] = math.max(0, cooldown - dt)
            changed = true
        end
    end

    -- 更新 buff 计时器
    if BS and BS.playerFleet then
        for _, ship in ipairs(BS.playerFleet) do
            if ship.dmgReductionTimer and ship.dmgReductionTimer > 0 then
                ship.dmgReductionTimer = ship.dmgReductionTimer - dt
                if ship.dmgReductionTimer <= 0 then
                    ship.dmgReductionBuff = 0
                end
            end
            if ship.atkBoostTimer and ship.atkBoostTimer > 0 then
                ship.atkBoostTimer = ship.atkBoostTimer - dt
                if ship.atkBoostTimer <= 0 then
                    ship.atkBoostBuff = 0
                end
            end
            if ship.atkSpeedBoostTimer and ship.atkSpeedBoostTimer > 0 then
                ship.atkSpeedBoostTimer = ship.atkSpeedBoostTimer - dt
                if ship.atkSpeedBoostTimer <= 0 then
                    ship.atkSpeedBoost = 0
                end
            end
            if ship.invulnerableTimer and ship.invulnerableTimer > 0 then
                ship.invulnerableTimer = ship.invulnerableTimer - dt
                if ship.invulnerableTimer <= 0 then
                    ship.visible = true
                end
            end
        end
    end

    if changed then
        CommanderSystem.saveState()
    end
end

-- ============================================================================
-- 被动技能效果
-- ============================================================================

-- 应用被动效果
function CommanderSystem.applyPassiveEffects()
    local cmd = COMMANDERS[CommanderState.selectedCommander]
    if not cmd or not cmd.passive then return end

    local passive = cmd.passive
    CommanderState.passiveBuffs = {}

    if passive.effects then
        if passive.effects.buildSpeedMult then
            CommanderState.passiveBuffs.buildSpeedMult = passive.effects.buildSpeedMult
        end
        if passive.effects.lowHpDmgBoost then
            CommanderState.passiveBuffs.lowHpDmgBoost = passive.effects.lowHpDmgBoost
        end
        if passive.effects.killStackAtk then
            CommanderState.passiveBuffs.killStackAtk = passive.effects.killStackAtk
        end
        if passive.effects.stealthDurationMult then
            CommanderState.passiveBuffs.stealthDurationMult = passive.effects.stealthDurationMult
        end
    end
end

-- 获取被动技能信息
function CommanderSystem.getPassive()
    local cmd = COMMANDERS[CommanderState.selectedCommander]
    if not cmd or not cmd.passive then return nil end

    return {
        id = cmd.passive.id,
        name = cmd.passive.name,
        desc = cmd.passive.desc,
        effects = cmd.passive.effects,
    }
end

-- 获取被动加成
function CommanderSystem.getPassiveBonus(bonusType)
    return CommanderState.passiveBuffs[bonusType] or 0
end

-- ============================================================================
-- 击杀叠加系统（佣兵战术）
-- ============================================================================

-- 击杀时调用
function CommanderSystem.onKill(target)
    local bonus = CommanderState.passiveBuffs.killStackAtk
    if not bonus then return end

    CommanderState.killStacks.current = (CommanderState.killStacks.current or 0) + 1
    CommanderState.killStacks.current = math.min(CommanderState.killStacks.current, bonus.maxStacks)
    CommanderState.killStacks.timer = bonus.duration

    -- 应用叠加效果
    if BS and BS.playerFleet then
        for _, ship in ipairs(BS.playerFleet) do
            ship.killStackBonus = (CommanderState.killStacks.current or 0) * bonus.bonus
        end
    end
end

-- 更新叠加状态
function CommanderSystem.updateKillStacks(dt)
    if CommanderState.killStacks.timer then
        CommanderState.killStacks.timer = CommanderState.killStacks.timer - dt
        if CommanderState.killStacks.timer <= 0 then
            CommanderState.killStacks.current = 0
            CommanderState.killStacks.timer = nil
            if BS and BS.playerFleet then
                for _, ship in ipairs(BS.playerFleet) do
                    ship.killStackBonus = 0
                end
            end
        end
    end
end

-- 获取当前叠加层数
function CommanderSystem.getKillStacks()
    return CommanderState.killStacks.current or 0
end

-- ============================================================================
-- 战斗中的指挥官效果
-- ============================================================================

-- 获取指挥官战斗加成
function CommanderSystem.getBattleModifiers(ship)
    local modifiers = {
        dmgMult = 1.0,
        dmgReduction = 0,
        atkSpeedMult = 1.0,
        buildSpeedMult = 1.0,
    }

    -- 被动加成
    if CommanderState.passiveBuffs.lowHpDmgBoost and ship and ship.health and ship.maxHealth then
        if ship.health / ship.maxHealth < 0.3 then
            modifiers.dmgMult = modifiers.dmgMult + CommanderState.passiveBuffs.lowHpDmgBoost
        end
    end

    -- 击杀叠加
    if ship and ship.killStackBonus then
        modifiers.dmgMult = modifiers.dmgMult + ship.killStackBonus
    end

    -- 临时 buff
    if ship then
        if ship.atkBoostBuff then
            modifiers.dmgMult = modifiers.dmgMult + ship.atkBoostBuff
        end
        if ship.atkSpeedBoost then
            modifiers.atkSpeedMult = modifiers.atkSpeedMult + ship.atkSpeedBoost
        end
        if ship.dmgReductionBuff then
            modifiers.dmgReduction = modifiers.dmgReduction + ship.dmgReductionBuff
        end
        if ship.nextAttackMult then
            modifiers.nextAttackMult = ship.nextAttackMult
        end
    end

    -- 被动：建造速度
    if CommanderState.passiveBuffs.buildSpeedMult then
        modifiers.buildSpeedMult = CommanderState.passiveBuffs.buildSpeedMult
    end

    -- 被动：隐形持续时间
    if CommanderState.passiveBuffs.stealthDurationMult and ship and ship.stealthTimer then
        modifiers.stealthDurationMult = CommanderState.passiveBuffs.stealthDurationMult
    end

    return modifiers
end

-- ============================================================================
-- V3.2 P0-3: 指挥官技能树系统
-- ============================================================================

-- 技能树分支定义
local SKILL_TREE_BRANCHES = {
    ATTACK = { id = "ATTACK", name = "攻击", icon = "⚔", desc = "专注于伤害输出和战场压制" },
    DEFENSE = { id = "DEFENSE", name = "防御", icon = "🛡", desc = "专注于舰队防御和生存能力" },
    SUPPORT = { id = "SUPPORT", name = "辅助", icon = "✦", desc = "专注于团队增益和后勤支援" },
}

-- 技能节点类型
local SKILL_NODE_TYPES = {
    PASSIVE = "PASSIVE",       -- 被动技能：永久属性加成
    ACTIVE = "ACTIVE",         -- 主动技能：战斗中可激活
    ULTIMATE = "ULTIMATE",     -- 终极技能：需要前置条件，效果强力
}

-- 通用技能树模板（每个指挥官可覆盖）
local DEFAULT_SKILL_TREE = {
    ATTACK = {
        { id = "ATTACK_1", name = "精准打击", type = "PASSIVE", tier = 1, cost = 1, effects = { dmgMult = 0.05 }, desc = "舰队伤害 +5%" },
        { id = "ATTACK_2", name = "致命一击", type = "PASSIVE", tier = 2, cost = 2, effects = { critChance = 0.15 }, desc = "暴击率 +15%", requires = { "ATTACK_1" } },
        { id = "ATTACK_3", name = "压制射击", type = "ACTIVE", tier = 3, cost = 3, effects = { stunChance = 0.2, stunDuration = 2 }, desc = "主动：攻击有 20% 概率使敌人瘫痪 2 秒", requires = { "ATTACK_2" } },
        { id = "ATTACK_4", name = "毁灭之怒", type = "ULTIMATE", tier = 4, cost = 5, effects = { dmgMult = 0.3, enemyDmgTakenMult = 0.2 }, desc = "终极：伤害 +30%，敌人承受伤害 +20%", requires = { "ATTACK_3" } },
    },
    DEFENSE = {
        { id = "DEFENSE_1", name = "重装护甲", type = "PASSIVE", tier = 1, cost = 1, effects = { dmgReduction = 0.05 }, desc = "舰队减伤 +5%" },
        { id = "DEFENSE_2", name = "能量护盾", type = "PASSIVE", tier = 2, cost = 2, effects = { shieldBonus = 0.1 }, desc = "护盾效果 +10%", requires = { "DEFENSE_1" } },
        { id = "DEFENSE_3", name = "紧急修复", type = "ACTIVE", tier = 3, cost = 3, effects = { healPercent = 0.15, healCooldown = 15 }, desc = "主动：立即恢复 15% 生命（冷却 15 秒）", requires = { "DEFENSE_2" } },
        { id = "DEFENSE_4", name = "铁壁防线", type = "ULTIMATE", tier = 4, cost = 5, effects = { dmgReduction = 0.2, maxHpBonus = 0.2 }, desc = "终极：减伤 +20%，最大生命 +20%", requires = { "DEFENSE_3" } },
    },
    SUPPORT = {
        { id = "SUPPORT_1", name = "指挥官光环", type = "PASSIVE", tier = 1, cost = 1, effects = { expBonus = 0.1 }, desc = "经验获取 +10%" },
        { id = "SUPPORT_2", name = "战术协同", type = "PASSIVE", tier = 2, cost = 2, effects = { teamAtkSpeed = 0.1 }, desc = "团队攻击速度 +10%", requires = { "SUPPORT_1" } },
        { id = "SUPPORT_3", name = "资源调度", type = "ACTIVE", tier = 3, cost = 3, effects = { resourceGain = 0.2 }, desc = "主动：战斗中获取资源 +20%（持续 10 秒）", requires = { "SUPPORT_2" } },
        { id = "SUPPORT_4", name = "战争艺术", type = "ULTIMATE", tier = 4, cost = 5, effects = { allStatsMult = 0.15, rewardBonus = 0.3 }, desc = "终极：全属性 +15%，战斗奖励 +30%", requires = { "SUPPORT_3" } },
    },
}

-- 每个指挥官的技能点管理
local CommanderSkillTreeState = {
    -- commanderId -> skill tree state
    unlockedNodes = {},      -- { commanderId = { nodeId = true } }
    skillPoints = {},         -- { commanderId = number }
    totalPointsAllocated = {}, -- { commanderId = number }
}

-- 初始化指挥官技能树状态
local function initSkillTreeFor(commanderId)
    if not CommanderSkillTreeState.unlockedNodes[commanderId] then
        CommanderSkillTreeState.unlockedNodes[commanderId] = {}
    end
    if CommanderSkillTreeState.skillPoints[commanderId] == nil then
        CommanderSkillTreeState.skillPoints[commanderId] = 3  -- 初始 3 技能点
    end
    if CommanderSkillTreeState.totalPointsAllocated[commanderId] == nil then
        CommanderSkillTreeState.totalPointsAllocated[commanderId] = 0
    end
end

-- 获取指挥官技能树（返回完整树结构 + 当前状态）
function CommanderSystem.getSkillTree(commanderId)
    local cmd = COMMANDERS[commanderId]
    if not cmd then return nil end

    initSkillTreeFor(commanderId)

    -- 优先使用指挥官自定义技能树，否则使用默认树
    local tree = cmd.skillTree or DEFAULT_SKILL_TREE
    local unlocked = CommanderSkillTreeState.unlockedNodes[commanderId]

    local result = {
        branches = {},
        availablePoints = CommanderSkillTreeState.skillPoints[commanderId] or 0,
        totalPoints = CommanderSkillTreeState.totalPointsAllocated[commanderId] or 0,
    }

    for branchId, nodes in pairs(tree) do
        local branchInfo = SKILL_TREE_BRANCHES[branchId] or { name = branchId }
        local branchNodes = {}
        for _, node in ipairs(nodes) do
            table.insert(branchNodes, {
                id = node.id,
                name = node.name,
                desc = node.desc,
                tier = node.tier,
                cost = node.cost,
                type = node.type,
                effects = node.effects,
                requires = node.requires,
                unlocked = unlocked[node.id] == true,
                canUnlock = CommanderSystem.canUnlockNode(commanderId, node),
            })
        end
        table.insert(result.branches, {
            id = branchId,
            name = branchInfo.name,
            icon = branchInfo.icon,
            desc = branchInfo.desc,
            nodes = branchNodes,
        })
    end

    return result
end

-- 检查是否可以解锁某个技能节点
function CommanderSystem.canUnlockNode(commanderId, node)
    initSkillTreeFor(commanderId)

    -- 1. 检查是否已解锁
    local unlocked = CommanderSkillTreeState.unlockedNodes[commanderId]
    if unlocked[node.id] then return false, "已解锁" end

    -- 2. 检查技能点是否足够
    local points = CommanderSkillTreeState.skillPoints[commanderId] or 0
    if points < node.cost then return false, "技能点不足（需要 " .. node.cost .. "）" end

    -- 3. 检查前置条件
    if node.requires then
        for _, reqId in ipairs(node.requires) do
            if not unlocked[reqId] then
                return false, "需要先解锁前置技能"
            end
        end
    end

    return true, "可解锁"
end

-- 解锁技能节点
function CommanderSystem.unlockSkillNode(commanderId, nodeId)
    initSkillTreeFor(commanderId)

    -- 在技能树中查找节点
    local cmd = COMMANDERS[commanderId]
    local tree = cmd and cmd.skillTree or DEFAULT_SKILL_TREE
    local targetNode = nil
    for _, nodes in pairs(tree) do
        for _, node in ipairs(nodes) do
            if node.id == nodeId then
                targetNode = node
                break
            end
        end
        if targetNode then break end
    end

    if not targetNode then return false, "技能不存在" end

    -- 检查是否可解锁
    local canUnlock, reason = CommanderSystem.canUnlockNode(commanderId, targetNode)
    if not canUnlock then return false, reason end

    -- 扣除技能点
    CommanderSkillTreeState.skillPoints[commanderId] = (CommanderSkillTreeState.skillPoints[commanderId] or 0) - targetNode.cost
    CommanderSkillTreeState.totalPointsAllocated[commanderId] = (CommanderSkillTreeState.totalPointsAllocated[commanderId] or 0) + targetNode.cost

    -- 标记为已解锁
    CommanderSkillTreeState.unlockedNodes[commanderId][nodeId] = true

    -- 应用效果到当前指挥官（如果是当前选中的）
    if CommanderState.selectedCommander == commanderId then
        CommanderSystem.applySkillTreeEffects()
    end

    -- 保存
    CommanderSystem.saveSkillTree()

    return true, "已解锁: " .. targetNode.name
end

-- 重置技能树（返还技能点）
function CommanderSystem.resetSkillTree(commanderId)
    initSkillTreeFor(commanderId)

    -- 返还所有技能点
    local totalRefund = CommanderSkillTreeState.totalPointsAllocated[commanderId] or 0
    CommanderSkillTreeState.skillPoints[commanderId] = (CommanderSkillTreeState.skillPoints[commanderId] or 0) + totalRefund
    CommanderSkillTreeState.totalPointsAllocated[commanderId] = 0

    -- 清除所有解锁状态
    CommanderSkillTreeState.unlockedNodes[commanderId] = {}

    -- 如果是当前指挥官，重新应用效果
    if CommanderState.selectedCommander == commanderId then
        CommanderSystem.applySkillTreeEffects()
    end

    CommanderSystem.saveSkillTree()
    return true, "已重置，返还 " .. totalRefund .. " 技能点"
end

-- 分配技能点（获得新技能点）
function CommanderSystem.awardSkillPoint(commanderId, amount)
    initSkillTreeFor(commanderId)
    amount = tonumber(amount) or 1
    CommanderSkillTreeState.skillPoints[commanderId] = (CommanderSkillTreeState.skillPoints[commanderId] or 0) + amount
    CommanderSystem.saveSkillTree()
    return true, "获得 " .. amount .. " 技能点"
end

-- 获取当前可用技能点
function CommanderSystem.getAvailablePoints(commanderId)
    initSkillTreeFor(commanderId or CommanderState.selectedCommander)
    local id = commanderId or CommanderState.selectedCommander
    return CommanderSkillTreeState.skillPoints[id] or 0
end

-- 应用技能树效果到当前指挥官
function CommanderSystem.applySkillTreeEffects()
    local commanderId = CommanderState.selectedCommander
    local cmd = COMMANDERS[commanderId]
    if not cmd then return end

    initSkillTreeFor(commanderId)
    local tree = cmd.skillTree or DEFAULT_SKILL_TREE
    local unlocked = CommanderSkillTreeState.unlockedNodes[commanderId]

    -- 重置 skill tree 加成
    CommanderState.skillTreeBuffs = CommanderState.skillTreeBuffs or {}

    for _, nodes in pairs(tree) do
        for _, node in ipairs(nodes) do
            if unlocked[node.id] and node.effects then
                for effectKey, effectValue in pairs(node.effects) do
                    CommanderState.skillTreeBuffs[effectKey] = (CommanderState.skillTreeBuffs[effectKey] or 0) + effectValue
                end
            end
        end
    end
end

-- 获取技能树加成总和（用于计算战斗效果）
function CommanderSystem.getSkillTreeBonus(bonusType)
    local commanderId = CommanderState.selectedCommander
    if not commanderId then return 0 end

    -- 确保初始化
    initSkillTreeFor(commanderId)

    local cmd = COMMANDERS[commanderId]
    local tree = cmd.skillTree or DEFAULT_SKILL_TREE
    local unlocked = CommanderSkillTreeState.unlockedNodes[commanderId]

    local total = 0
    for _, nodes in pairs(tree) do
        for _, node in ipairs(nodes) do
            if unlocked[node.id] and node.effects and node.effects[bonusType] then
                total = total + node.effects[bonusType]
            end
        end
    end

    return total
end

-- 检查当前指挥官是否有某个主动技能
function CommanderSystem.hasActiveSkill(skillNodeId)
    local commanderId = CommanderState.selectedCommander
    initSkillTreeFor(commanderId)
    return CommanderSkillTreeState.unlockedNodes[commanderId] and CommanderSkillTreeState.unlockedNodes[commanderId][skillNodeId]
end

-- 保存技能树状态
function CommanderSystem.saveSkillTree()
    if playerState then
        playerState.commanderSkillTree = {
            unlockedNodes = CommanderSkillTreeState.unlockedNodes,
            skillPoints = CommanderSkillTreeState.skillPoints,
            totalPointsAllocated = CommanderSkillTreeState.totalPointsAllocated,
        }
    end
end

-- 加载技能树状态
function CommanderSystem.loadSkillTree(data)
    if data then
        if data.unlockedNodes then
            for cmdId, nodes in pairs(data.unlockedNodes) do
                initSkillTreeFor(cmdId)
                for nodeId, isUnlocked in pairs(nodes) do
                    CommanderSkillTreeState.unlockedNodes[cmdId][nodeId] = isUnlocked
                end
            end
        end
        if data.skillPoints then
            for cmdId, points in pairs(data.skillPoints) do
                initSkillTreeFor(cmdId)
                CommanderSkillTreeState.skillPoints[cmdId] = points
            end
        end
        if data.totalPointsAllocated then
            for cmdId, total in pairs(data.totalPointsAllocated) do
                initSkillTreeFor(cmdId)
                CommanderSkillTreeState.totalPointsAllocated[cmdId] = total
            end
        end

        -- 应用技能树效果
        if CommanderState.selectedCommander then
            CommanderSystem.applySkillTreeEffects()
        end
    end
end

-- ============================================================================
-- V3.2 P0-3: 扩展获取战斗加成（合并技能树效果）
-- ============================================================================

local originalGetBattleModifiers = CommanderSystem.getBattleModifiers
function CommanderSystem.getBattleModifiers(ship)
    -- 调用原逻辑
    local modifiers = originalGetBattleModifiers(ship)

    -- 应用技能树加成
    if CommanderState.selectedCommander then
        local dmgMult = CommanderSystem.getSkillTreeBonus("dmgMult")
        local dmgReduction = CommanderSystem.getSkillTreeBonus("dmgReduction")
        local critChance = CommanderSystem.getSkillTreeBonus("critChance")
        local atkSpeed = CommanderSystem.getSkillTreeBonus("teamAtkSpeed")
        local enemyDmgTakenMult = CommanderSystem.getSkillTreeBonus("enemyDmgTakenMult")
        local shieldBonus = CommanderSystem.getSkillTreeBonus("shieldBonus")
        local maxHpBonus = CommanderSystem.getSkillTreeBonus("maxHpBonus")
        local allStatsMult = CommanderSystem.getSkillTreeBonus("allStatsMult")

        modifiers.dmgMult = (modifiers.dmgMult or 1.0) * (1 + dmgMult) * (1 + allStatsMult)
        modifiers.dmgReduction = math.min(0.8, (modifiers.dmgReduction or 0) + dmgReduction + allStatsMult)
        modifiers.critChance = (modifiers.critChance or 0) + critChance
        modifiers.atkSpeedMult = (modifiers.atkSpeedMult or 1.0) * (1 + atkSpeed) * (1 + allStatsMult)
        modifiers.enemyDmgTakenMult = 1 + enemyDmgTakenMult
        modifiers.shieldBonus = shieldBonus
        modifiers.maxHpBonus = maxHpBonus
        modifiers.rewardBonus = CommanderSystem.getSkillTreeBonus("rewardBonus")
        modifiers.healPercent = CommanderSystem.getSkillTreeBonus("healPercent")
    end

    return modifiers
end

-- ============================================================================
-- 存档
-- ============================================================================

function CommanderSystem.saveState()
    if playerState then
        playerState.commanderState = {
            unlockedCommanders = CommanderState.unlockedCommanders,
            selectedCommander = CommanderState.selectedCommander,
            skillCooldowns = CommanderState.skillCooldowns,
            passiveBuffs = CommanderState.passiveBuffs,
        }
        playerState.commanderSkillTree = {
            unlockedNodes = CommanderSkillTreeState.unlockedNodes,
            skillPoints = CommanderSkillTreeState.skillPoints,
            totalPointsAllocated = CommanderSkillTreeState.totalPointsAllocated,
        }
    end
end

function CommanderSystem.loadState(data)
    if data then
        CommanderState.unlockedCommanders = data.unlockedCommanders or { "ADMIRAL_CHEN", "REBEL_LEADER" }
        CommanderState.selectedCommander = data.selectedCommander or "ADMIRAL_CHEN"
        CommanderState.skillCooldowns = data.skillCooldowns or {}
        CommanderState.passiveBuffs = data.passiveBuffs or {}

        -- 应用被动效果
        CommanderSystem.applyPassiveEffects()
    end
end

-- 加载所有指挥官相关数据（主入口）
function CommanderSystem.loadAll(commanderData, skillTreeData)
    CommanderSystem.loadState(commanderData)
    CommanderSystem.loadSkillTree(skillTreeData)
end

-- ============================================================================
-- V3.2 P2-4: 指挥官与舰队协同加成
-- ============================================================================

local SYNERGY_COMBOS = {
    ADMIRAL_CHEN = {
        BATTLECRUISER = {
            name = "重装阵线",
            desc = "陈将军率领战列舰部队",
            bonuses = { dmgMult = 0.15, maxHealthMult = 0.10 },
        },
        DESTROYER = {
            name = "闪电突袭",
            desc = "陈将军率领驱逐舰部队",
            bonuses = { speedMult = 0.20, critChance = 0.10 },
        },
    },
    REBEL_LEADER = {
        CRUISER = {
            name = "游击战术",
            desc = "反叛军领袖率领巡洋舰部队",
            bonuses = { dmgMult = 0.12, energyRegen = 0.15 },
        },
        CARRIER = {
            name = "空中压制",
            desc = "反叛军领袖率领航空母舰部队",
            bonuses = { fighterDmgMult = 0.25 },
        },
    },
    SCIENTIST = {
        SCIENCE_SHIP = {
            name = "科研加速",
            desc = "科学家率领科研船部队",
            bonuses = { researchSpeedMult = 0.30 },
        },
        ESCORT = {
            name = "护盾工程",
            desc = "科学家率领护卫舰部队",
            bonuses = { shieldMult = 0.20 },
        },
    },
    GLOBAL = {
        FLAGSHIP = {
            name = "旗舰指挥",
            desc = "任意指挥官率领旗舰部队",
            bonuses = { globalStatsMult = 0.10 },
            applyToAll = true,
        },
    },
}

local SynergyState = {
    activeBonuses = {},
    tempBonuses = {},
}

---@param fleet table
---@return table
function CommanderSystem.detectFleetComposition(fleet)
    local composition = {}
    if not fleet then return composition end
    local ships = fleet.ships or fleet
    if type(ships) == "table" then
        for _, entry in ipairs(ships) do
            if entry and entry.shipType then
                composition[entry.shipType] = (composition[entry.shipType] or 0) + (entry.count or 1)
            elseif type(entry) == "string" then
                composition[entry] = (composition[entry] or 0) + 1
            end
        end
    end
    if BS and BS.playerFleet and type(BS.playerFleet) == "table" then
        for _, ship in ipairs(BS.playerFleet) do
            if ship and ship.stype then
                composition[ship.stype] = (composition[ship.stype] or 0) + 1
            end
        end
    end
    return composition
end

---@param commanderId string
---@param fleet table
---@return table
function CommanderSystem.getSynergyBonuses(commanderId, fleet)
    local totalBonuses = {}
    local composition = CommanderSystem.detectFleetComposition(fleet)
    local combos = SYNERGY_COMBOS[commanderId] or {}
    for shipType, combo in pairs(combos) do
        if composition[shipType] and composition[shipType] > 0 and combo.bonuses then
            for bonusKey, bonusValue in pairs(combo.bonuses) do
                totalBonuses[bonusKey] = (totalBonuses[bonusKey] or 0) + bonusValue
            end
        end
    end
    local globalCombos = SYNERGY_COMBOS.GLOBAL or {}
    for shipType, combo in pairs(globalCombos) do
        if composition[shipType] and composition[shipType] > 0 and combo.bonuses then
            for bonusKey, bonusValue in pairs(combo.bonuses) do
                totalBonuses[bonusKey] = (totalBonuses[bonusKey] or 0) + bonusValue
            end
        end
    end
    if SynergyState.tempBonuses[commanderId] then
        for bonusKey, bonusValue in pairs(SynergyState.tempBonuses[commanderId]) do
            totalBonuses[bonusKey] = (totalBonuses[bonusKey] or 0) + bonusValue
        end
    end
    return totalBonuses
end

---@param ship table
---@param bonuses table
---@return table
function CommanderSystem.applySynergyBonuses(ship, bonuses)
    if not ship or not bonuses then return ship end
    ship.synergyBonuses = ship.synergyBonuses or {}
    for bonusKey, bonusValue in pairs(bonuses) do
        ship.synergyBonuses[bonusKey] = bonusValue
        if bonusKey == "dmgMult" then
            ship.damage = (ship.damage or ship.baseDamage or 0) * (1 + bonusValue)
        elseif bonusKey == "maxHealthMult" then
            ship.maxHealth = (ship.maxHealth or ship.baseHealth or 0) * (1 + bonusValue)
        elseif bonusKey == "speedMult" then
            ship.speed = (ship.speed or ship.baseSpeed or 0) * (1 + bonusValue)
        elseif bonusKey == "critChance" then
            ship.critChance = (ship.critChance or 0) + bonusValue
        elseif bonusKey == "energyRegen" then
            ship.energyRegen = (ship.energyRegen or 0) * (1 + bonusValue)
        elseif bonusKey == "fighterDmgMult" then
            ship.fighterDamage = (ship.fighterDamage or 0) * (1 + bonusValue)
        elseif bonusKey == "researchSpeedMult" then
            ship.researchSpeed = (ship.researchSpeed or 0) * (1 + bonusValue)
        elseif bonusKey == "shieldMult" then
            ship.shield = (ship.shield or ship.baseShield or 0) * (1 + bonusValue)
        elseif bonusKey == "globalStatsMult" then
            ship.damage = (ship.damage or ship.baseDamage or 0) * (1 + bonusValue)
            ship.maxHealth = (ship.maxHealth or ship.baseHealth or 0) * (1 + bonusValue)
            ship.speed = (ship.speed or ship.baseSpeed or 0) * (1 + bonusValue)
        end
    end
    return ship
end

---@param ship table
---@return table
function CommanderSystem.removeSynergyBonuses(ship)
    if not ship then return ship end
    if ship.synergyBonuses then
        for bonusKey, _ in pairs(ship.synergyBonuses) do
            if bonusKey == "dmgMult" then
                ship.damage = ship.baseDamage or ship.damage
            elseif bonusKey == "maxHealthMult" then
                ship.maxHealth = ship.baseHealth or ship.maxHealth
            elseif bonusKey == "speedMult" then
                ship.speed = ship.baseSpeed or ship.speed
            elseif bonusKey == "critChance" then
                ship.critChance = 0
            elseif bonusKey == "energyRegen" then
                ship.energyRegen = ship.baseEnergyRegen or ship.energyRegen
            elseif bonusKey == "fighterDmgMult" then
                ship.fighterDamage = ship.baseFighterDamage or ship.fighterDamage
            elseif bonusKey == "researchSpeedMult" then
                ship.researchSpeed = ship.baseResearchSpeed or ship.researchSpeed
            elseif bonusKey == "shieldMult" then
                ship.shield = ship.baseShield or ship.shield
            elseif bonusKey == "globalStatsMult" then
                ship.damage = ship.baseDamage or ship.damage
                ship.maxHealth = ship.baseHealth or ship.maxHealth
                ship.speed = ship.baseSpeed or ship.speed
            end
        end
        ship.synergyBonuses = nil
    end
    return ship
end

---@param commanderId string
---@param fleet table
---@return table
function CommanderSystem.getFleetSynergySummary(commanderId, fleet)
    local summary = {
        commanderId = commanderId,
        composition = {},
        activeCombos = {},
        totalBonuses = {},
        comboCount = 0,
    }
    summary.composition = CommanderSystem.detectFleetComposition(fleet)
    local combos = SYNERGY_COMBOS[commanderId] or {}
    for shipType, combo in pairs(combos) do
        if summary.composition[shipType] and summary.composition[shipType] > 0 then
            summary.comboCount = summary.comboCount + 1
            table.insert(summary.activeCombos, {
                shipType = shipType,
                count = summary.composition[shipType],
                name = combo.name,
                desc = combo.desc,
                bonuses = combo.bonuses,
            })
        end
    end
    local globalCombos = SYNERGY_COMBOS.GLOBAL or {}
    for shipType, combo in pairs(globalCombos) do
        if summary.composition[shipType] and summary.composition[shipType] > 0 then
            summary.comboCount = summary.comboCount + 1
            table.insert(summary.activeCombos, {
                shipType = shipType,
                count = summary.composition[shipType],
                name = combo.name,
                desc = combo.desc,
                bonuses = combo.bonuses,
                isGlobal = true,
            })
        end
    end
    summary.totalBonuses = CommanderSystem.getSynergyBonuses(commanderId, fleet)
    return summary
end

---@param commanderId string
---@return table
function CommanderSystem.getRecommendedShipTypes(commanderId)
    local recommended = {}
    local combos = SYNERGY_COMBOS[commanderId] or {}
    for shipType, combo in pairs(combos) do
        table.insert(recommended, {
            shipType = shipType,
            name = combo.name,
            desc = combo.desc,
            bonuses = combo.bonuses,
        })
    end
    local globalCombos = SYNERGY_COMBOS.GLOBAL or {}
    for shipType, combo in pairs(globalCombos) do
        table.insert(recommended, {
            shipType = shipType,
            name = combo.name,
            desc = combo.desc,
            bonuses = combo.bonuses,
            isGlobal = true,
        })
    end
    return recommended
end

---@param commanderId string
---@param fleet table
---@param bonusType string
---@param value number
---@return table
function CommanderSystem.applyTemporarySynergy(commanderId, fleet, bonusType, value)
    if not SynergyState.tempBonuses[commanderId] then
        SynergyState.tempBonuses[commanderId] = {}
    end
    SynergyState.tempBonuses[commanderId][bonusType] = (SynergyState.tempBonuses[commanderId][bonusType] or 0) + (value or 0)
    local totalBonuses = CommanderSystem.getSynergyBonuses(commanderId, fleet)
    if BS and BS.playerFleet then
        for _, ship in ipairs(BS.playerFleet) do
            CommanderSystem.applySynergyBonuses(ship, totalBonuses)
        end
    end
    return totalBonuses
end

-- ============================================================================
-- 导出
-- ============================================================================

return CommanderSystem
