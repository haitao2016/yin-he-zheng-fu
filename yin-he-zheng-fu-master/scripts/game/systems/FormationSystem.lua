---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/systems/FormationSystem.lua -- 阵型系统
-- V2.8 P1-5
-- ============================================================================

local FormationSystem = {}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local FormationState = {
    selectedFormation = "VANGUARD",
    unlockedFormations = { "VANGUARD", "PHALANX" },
    formationEffects = {},
}

-- ============================================================================
-- 阵型查询
-- ============================================================================

-- 获取所有阵型
function FormationSystem.getAllFormations()
    local formations = {}
    for _, formation in ipairs(SHIP_FORMATIONS) do
        local isUnlocked = FormationState.unlockedFormations[formation.id] == true

        table.insert(formations, {
            id = formation.id,
            name = formation.name,
            desc = formation.desc,
            icon = formation.icon,
            unlocked = isUnlocked,
            effect = formation.effect,
        })
    end
    return formations
end

-- 获取阵型信息
function FormationSystem.getFormation(formationId)
    local formation = nil
    for _, f in ipairs(SHIP_FORMATIONS) do
        if f.id == formationId then formation = f; break end
    end
    if not formation then return nil end

    return {
        id = formation.id,
        name = formation.name,
        desc = formation.desc,
        icon = formation.icon,
        unlocked = FormationState.unlockedFormations[formation.id] == true,
        effect = formation.effect,
        shipOrder = formation.shipOrder,
    }
end

-- 获取当前阵型
function FormationSystem.getCurrentFormation()
    return FormationSystem.getFormation(FormationState.selectedFormation)
end

-- 检查是否已解锁
function FormationSystem.isUnlocked(formationId)
    return FormationState.unlockedFormations[formationId] == true
end

-- ============================================================================
-- 阵型选择
-- ============================================================================

-- 选择阵型
function FormationSystem.selectFormation(formationId)
    if not FormationSystem.isUnlocked(formationId) then
        return false, "阵型未解锁"
    end

    FormationState.selectedFormation = formationId

    -- 应用阵型效果
    FormationSystem.applyFormationEffects()

    return true, "已选择 " .. (FormationSystem.getFormation(formationId) or {}).name
end

-- ============================================================================
-- 阵型解锁
-- ============================================================================

-- 解锁阵型
function FormationSystem.unlockFormation(formationId)
    if FormationState.unlockedFormations[formationId] then
        return false, "阵型已解锁"
    end

    FormationState.unlockedFormations[formationId] = true

    if NotifyPanel then
        local formation = FormationSystem.getFormation(formationId)
        NotifyPanel.push({
            type = "UNLOCK",
            title = "阵型解锁",
            message = "解锁新阵型: " .. (formation and formation.name or formationId),
        })
    end

    FormationSystem.saveState()
    return true, "解锁成功"
end

-- 检查并自动解锁
function FormationSystem.checkUnlocks()
    -- 根据波次自动解锁
    local wave = playerState and playerState.currentWave or 0

    if wave >= 10 and not FormationState.unlockedFormations["FLANK"] then
        FormationSystem.unlockFormation("FLANK")
    end
    if wave >= 20 and not FormationState.unlockedFormations["CRESCENT"] then
        FormationSystem.unlockFormation("CRESCENT")
    end
    if wave >= 35 and not FormationState.unlockedFormations["PINZHER"] then
        FormationSystem.unlockFormation("PINZHER")
    end
    if wave >= 50 and not FormationState.unlockedFormations["SKIRMISH"] then
        FormationSystem.unlockFormation("SKIRMISH")
    end
end

-- ============================================================================
-- 阵型效果
-- ============================================================================

-- 应用阵型效果
function FormationSystem.applyFormationEffects()
    local formation = FormationSystem.getFormation(FormationState.selectedFormation)
    if not formation then return end

    FormationState.formationEffects = {}

    if formation.effect then
        for effectType, value in pairs(formation.effect) do
            FormationState.formationEffects[effectType] = value
        end
    end
end

-- 获取阵型效果加成
function FormationSystem.getEffect(effectType)
    return FormationState.formationEffects[effectType] or 0
end

-- 获取战斗修正
function FormationSystem.getBattleModifiers(ship)
    local modifiers = {
        dmgBonus = 1.0,
        defenseBonus = 1.0,
        speedBonus = 1.0,
        aoeReduction = 0,
        atkSpeedBonus = 0,
    }

    local effect = FormationState.formationEffects

    if effect.dmgBonus then
        modifiers.dmgBonus = modifiers.dmgBonus + effect.dmgBonus
    end
    if effect.defenseBonus then
        modifiers.defenseBonus = modifiers.defenseBonus + effect.defenseBonus
    end
    if effect.speedBonus then
        modifiers.speedBonus = modifiers.speedBonus + effect.speedBonus
    end
    if effect.aoeReduction then
        modifiers.aoeReduction = effect.aoeReduction
    end
    if effect.atkSpeedBonus then
        modifiers.atkSpeedBonus = effect.atkSpeedBonus
    end
    if effect.sideDmgBonus then
        -- 侧翼攻击加成
        modifiers.sideDmgBonus = effect.sideDmgBonus
    end
    if effect.focusFireBonus then
        -- 集火加成
        modifiers.focusFireBonus = effect.focusFireBonus
    end
    if effect.retreatSpeedBonus then
        -- 撤退速度加成
        modifiers.retreatSpeedBonus = effect.retreatSpeedBonus
    end
    if effect.hitAndRunDmg then
        -- 打了就跑伤害加成
        modifiers.hitAndRunDmg = effect.hitAndRunDmg
    end

    return modifiers
end

-- ============================================================================
-- 阵型视觉预览
-- ============================================================================

-- 获取阵型坐标分布
function FormationSystem.getFormationLayout()
    local formation = FormationSystem.getFormation(FormationState.selectedFormation)
    if not formation or not formation.shipOrder then
        -- 默认排列
        return {
            { x = 0, y = 0 },
            { x = 50, y = 30 },
            { x = -50, y = 30 },
            { x = 80, y = -20 },
            { x = -80, y = -20 },
        }
    end

    local layout = {}
    local count = #formation.shipOrder

    if formation.id == "VANGUARD" then
        -- 分散前卫
        for i, shipType in ipairs(formation.shipOrder) do
            local angle = (i - 1) * (math.pi * 2 / count) + math.pi / 2
            table.insert(layout, {
                x = math.cos(angle) * 100,
                y = math.sin(angle) * 60,
                shipType = shipType,
            })
        end

    elseif formation.id == "PHALANX" then
        -- 紧密方阵
        local rows = math.ceil(count / 2)
        for i, shipType in ipairs(formation.shipOrder) do
            local row = math.floor((i - 1) / 2)
            local col = (i - 1) % 2
            table.insert(layout, {
                x = (col - 0.5) * 60,
                y = row * 50,
                shipType = shipType,
            })
        end

    elseif formation.id == "FLANK" then
        -- 两翼包抄
        for i, shipType in ipairs(formation.shipOrder) do
            local side = i % 2 == 0 and 1 or -1
            local row = math.floor((i - 1) / 2)
            table.insert(layout, {
                x = side * 80,
                y = row * 40,
                shipType = shipType,
            })
        end

    elseif formation.id == "CRESCENT" then
        -- 新月弧形
        for i, shipType in ipairs(formation.shipOrder) do
            local angle = (i - 1) * (math.pi / (count - 1)) - math.pi / 2
            table.insert(layout, {
                x = math.cos(angle) * 90,
                y = math.sin(angle) * 50 + 30,
                shipType = shipType,
            })
        end

    elseif formation.id == "PINZHER" then
        -- 钳形
        for i, shipType in ipairs(formation.shipOrder) do
            local side = i % 2 == 0 and 1 or -1
            table.insert(layout, {
                x = side * 70,
                y = (i - 1) * 35,
                shipType = shipType,
            })
        end

    elseif formation.id == "SKIRMISH" then
        -- 游击 - 菱形
        for i, shipType in ipairs(formation.shipOrder) do
            local dist = math.abs(i - (count + 1) / 2)
            table.insert(layout, {
                x = (i - (count + 1) / 2) * 50,
                y = dist * 30,
                shipType = shipType,
            })
        end
    end

    return layout
end

-- ============================================================================
-- 存档
-- ============================================================================

function FormationSystem.saveState()
    if playerState then
        playerState.formationState = {
            selectedFormation = FormationState.selectedFormation,
            unlockedFormations = FormationState.unlockedFormations,
        }
    end
end

function FormationSystem.loadState(data)
    if data then
        FormationState.selectedFormation = data.selectedFormation or "VANGUARD"
        FormationState.unlockedFormations = data.unlockedFormations or { "VANGUARD", "PHALANX" }
        FormationSystem.applyFormationEffects()
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return FormationSystem
