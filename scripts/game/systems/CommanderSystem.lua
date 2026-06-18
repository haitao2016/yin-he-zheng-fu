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

-- ============================================================================
-- 导出
-- ============================================================================

return CommanderSystem
