---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/systems/SynergyAttackSystem.lua -- 协同攻击系统
-- V2.8 P2-5
-- ============================================================================

local SynergyAttackSystem = {}

-- ============================================================================
-- 协同攻击定义
-- ============================================================================

SYNERGY_ATTACKS = {
    {
        id = "DESTROYER_CARRIER_COMBO",
        name = "海空协同",
        desc = "驱逐舰+航母联合攻击",
        required = { DESTROYER = 2, CARRIER = 1 },
        effect = {
            type = "COMBO_DAMAGE",
            value = 1.5,
            radius = 100,
        },
        cooldown = 8,
        icon = "synergy_air_naval",
    },
    {
        id = "STEALTH_INFILTRATION",
        name = "隐形渗透",
        desc = "隐形舰突袭",
        required = { STEALTH = 3 },
        effect = {
            type = "BACKSTAB",
            value = 3.0,
        },
        cooldown = 10,
        icon = "synergy_stealth",
    },
    {
        id = "SUPPORT_WAVE",
        name = "支援波",
        desc = "支援舰群体治疗",
        required = { SUPPORT = 2, BATTLECRUISER = 2 },
        effect = {
            type = "AREA_HEAL",
            value = 0.3,
            radius = 150,
        },
        cooldown = 12,
        icon = "synergy_support",
    },
    {
        id = "DREADNOUGHT_BARRAGE",
        name = "无畏炮击",
        desc = "超级战列舰集火",
        required = { DREADNOUGHT = 1, DESTROYER = 3 },
        effect = {
            type = "FOCUS_FIRE",
            value = 4.0,
            targetOnly = true,
        },
        cooldown = 15,
        icon = "synergy_dreadnought",
    },
    {
        id = "STEALTH_ASSASSINATE",
        name = "隐形刺杀",
        desc = "隐形单位击杀回能",
        required = { STEALTH = 2 },
        effect = {
            type = "KILL_ENERGY",
            value = 0.5,
        },
        cooldown = 5,
        icon = "synergy_assassin",
    },
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local SynergyState = {
    activeSynergies = {},
    cooldownTimers = {},
    synergyProgress = {},  -- 每个协同攻击的进度
}

-- ============================================================================
-- 协同攻击检查
-- ============================================================================

-- 检查并触发协同攻击
function SynergyAttackSystem.checkSynergy(fleet)
    local synergies = {}

    for _, synergy in ipairs(SYNERGY_ATTACKS) do
        -- 检查是否满足条件
        if SynergyAttackSystem.checkRequirements(fleet, synergy.required) then
            -- 检查冷却
            local lastUsed = SynergyState.cooldownTimers[synergy.id] or 0
            if os.time() - lastUsed >= synergy.cooldown then
                table.insert(synergies, synergy)
            end
        end
    end

    return synergies
end

-- 检查是否满足协同攻击条件
function SynergyAttackSystem.checkRequirements(fleet, requirements)
    local shipCounts = {}

    -- 统计各类型舰船数量
    for _, ship in ipairs(fleet) do
        local stype = ship.stype or ship.type
        if stype then
            shipCounts[stype] = (shipCounts[stype] or 0) + 1
        end
    end

    -- 检查是否满足所有要求
    for shipType, requiredCount in pairs(requirements) do
        if (shipCounts[shipType] or 0) < requiredCount then
            return false
        end
    end

    return true
end

-- 触发协同攻击
function SynergyAttackSystem.triggerSynergy(synergyId, context)
    local synergy = nil
    for _, s in ipairs(SYNERGY_ATTACKS) do
        if s.id == synergyId then synergy = s; break end
    end

    if not synergy then
        return false, "协同攻击不存在"
    end

    -- 设置冷却
    SynergyState.cooldownTimers[synergyId] = os.time()

    -- 应用效果
    SynergyAttackSystem.applyEffect(synergy.effect, context)

    -- 记录活跃的协同攻击
    table.insert(SynergyState.activeSynergies, {
        id = synergyId,
        name = synergy.name,
        startTime = os.time(),
        duration = 2,
    })

    -- 显示通知
    if NotifyPanel then
        NotifyPanel.push({
            type = "SYNERGY",
            title = "⚡ " .. synergy.name,
            message = synergy.desc,
            icon = synergy.icon,
        })
    end

    return true, "协同攻击已触发"
end

-- 应用协同攻击效果
function SynergyAttackSystem.applyEffect(effect, context)
    if not context then context = {} end

    local playerFleet = context.playerFleet or (BS and BS.playerFleet)
    local enemyFleet = context.enemyFleet or (BS and BS.enemyFleet)

    if effect.type == "COMBO_DAMAGE" then
        -- 组合伤害
        if enemyFleet then
            local targets = SynergyAttackSystem.findTargetsInRadius(enemyFleet, context.targetX or 400, context.targetY or 300, effect.radius)
            for _, target in ipairs(targets) do
                target.health = target.health - (target.health * 0.1 * effect.value)
            end
        end

    elseif effect.type == "BACKSTAB" then
        -- 背刺伤害
        if enemyFleet and enemyFleet[1] then
            local target = enemyFleet[1]
            target.health = target.health - (target.health * (effect.value - 1))
        end

    elseif effect.type == "AREA_HEAL" then
        -- 范围治疗
        if playerFleet then
            for _, ship in ipairs(playerFleet) do
                local dx = (ship.x or 0) - (context.targetX or 400)
                local dy = (ship.y or 0) - (context.targetY or 300)
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= effect.radius then
                    ship.health = math.min(ship.maxHealth, ship.health + ship.maxHealth * effect.value)
                end
            end
        end

    elseif effect.type == "FOCUS_FIRE" then
        -- 集火
        if enemyFleet and enemyFleet[1] and effect.targetOnly then
            local target = enemyFleet[1]
            target.health = target.health - (target.health * (effect.value - 1))
        end

    elseif effect.type == "KILL_ENERGY" then
        -- 击杀回能
        if playerFleet then
            for _, ship in ipairs(playerFleet) do
                ship.energy = math.min(ship.maxEnergy or 100, (ship.energy or 50) + (ship.maxEnergy or 100) * effect.value)
            end
        end
    end
end

-- 查找范围内的目标
function SynergyAttackSystem.findTargetsInRadius(fleet, x, y, radius)
    local targets = {}
    for _, ship in ipairs(fleet) do
        local dx = (ship.x or 0) - x
        local dy = (ship.y or 0) - y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= radius then
            table.insert(targets, ship)
        end
    end
    return targets
end

-- ============================================================================
-- 查询接口
-- ============================================================================

-- 获取所有协同攻击
function SynergyAttackSystem.getAllSynergies()
    local synergies = {}
    for _, synergy in ipairs(SYNERGY_ATTACKS) do
        local cooldownEnd = SynergyState.cooldownTimers[synergy.id] or 0
        local cooldownRemaining = math.max(0, synergy.cooldown - (os.time() - cooldownEnd))

        table.insert(synergies, {
            id = synergy.id,
            name = synergy.name,
            desc = synergy.desc,
            icon = synergy.icon,
            cooldown = synergy.cooldown,
            cooldownRemaining = cooldownRemaining,
            ready = cooldownRemaining <= 0,
        })
    end
    return synergies
end

-- 获取可用的协同攻击
function SynergyAttackSystem.getAvailableSynergies()
    return SynergyAttackSystem.checkSynergy(BS and BS.playerFleet or {})
end

-- ============================================================================
-- 更新
-- ============================================================================

-- 更新协同攻击状态
function SynergyAttackSystem.update(dt)
    -- 更新活跃协同攻击
    local toRemove = {}
    for i, synergy in ipairs(SynergyState.activeSynergies) do
        synergy.startTime = synergy.startTime - dt
        if synergy.startTime <= 0 then
            table.insert(toRemove, i)
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(SynergyState.activeSynergies, toRemove[i])
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return SynergyAttackSystem
