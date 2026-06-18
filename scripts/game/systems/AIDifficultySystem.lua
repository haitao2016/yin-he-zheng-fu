---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/systems/AIDifficultySystem.lua -- AI 难度分级系统
-- V2.8 Diff-1
-- ============================================================================

local AIDifficultySystem = {}

-- ============================================================================
-- 难度等级定义（全局）
-- ============================================================================

DIFFICULTY_TIERS = {
    EASY = {
        id = "EASY",
        name = "简单",
        nameEn = "Easy",
        desc = "适合新手：敌人较弱，资源产出丰厚。",
        enemySpawnMult = 0.7,
        enemyDmgMult = 0.7,
        enemyHpMult = 0.8,
        resourceMult = 1.5,
        eventMult = 0.6,
        bossPowerMult = 0.8,
        enemyAI = {
            attackFrequency = 0.7,
            targetPriority = "HIGHEST_HP",
            moveStrategy = "AGGRESSIVE",
            skillUsageRate = 0.5,
            retreatThreshold = 0.2,
            comboChance = 0.3,
        },
        unlockCondition = nil,
        rewardBonus = 0.5,
    },
    NORMAL = {
        id = "NORMAL",
        name = "普通",
        nameEn = "Normal",
        desc = "标准体验：平衡的挑战与收益。",
        enemySpawnMult = 1.0,
        enemyDmgMult = 1.0,
        enemyHpMult = 1.0,
        resourceMult = 1.0,
        eventMult = 1.0,
        bossPowerMult = 1.0,
        enemyAI = {
            attackFrequency = 1.0,
            targetPriority = "NEAREST",
            moveStrategy = "COORDINATED",
            skillUsageRate = 1.0,
            retreatThreshold = 0.15,
            comboChance = 0.5,
        },
        unlockCondition = nil,
    },
    HARD = {
        id = "HARD",
        name = "困难",
        nameEn = "Hard",
        desc = "高级挑战：敌人更强，资源更稀缺。通关普通后解锁。",
        enemySpawnMult = 1.3,
        enemyDmgMult = 1.4,
        enemyHpMult = 1.3,
        resourceMult = 0.85,
        eventMult = 1.3,
        bossPowerMult = 1.4,
        enemyAI = {
            attackFrequency = 1.3,
            targetPriority = "LOWEST_HP",
            moveStrategy = "AGGRESSIVE",
            skillUsageRate = 1.5,
            retreatThreshold = 0.1,
            comboChance = 0.7,
        },
        unlockCondition = { completedNormal = true, minLevel = 10 },
        rewardBonus = 1.5,
    },
    NIGHTMARE = {
        id = "NIGHTMARE",
        name = "噩梦",
        nameEn = "Nightmare",
        desc = "极限挑战：敌人极为强大，资源极度紧张。通关困难后解锁。",
        enemySpawnMult = 1.6,
        enemyDmgMult = 1.8,
        enemyHpMult = 1.7,
        resourceMult = 0.65,
        eventMult = 1.6,
        bossPowerMult = 1.8,
        enemyAI = {
            attackFrequency = 1.6,
            targetPriority = "STRONGEST",
            moveStrategy = "DEFENSIVE",
            skillUsageRate = 2.0,
            retreatThreshold = 0.05,
            comboChance = 0.9,
        },
        unlockCondition = { completedHard = true, minLevel = 30, campaignChapter3 = true },
        rewardBonus = 2.5,
    },
}

-- 难度顺序列表（用于 UI 遍历）
local DIFFICULTY_ORDER = { "EASY", "NORMAL", "HARD", "NIGHTMARE" }

-- ============================================================================
-- 运行时状态
-- ============================================================================

local RuntimeDifficultyState = {
    currentDifficulty = "NORMAL",
}

-- ============================================================================
-- 解锁条件检查
-- ============================================================================

local function checkUnlockCondition(tier, gameState)
    if tier == nil or tier.unlockCondition == nil then
        return true
    end
    if gameState == nil then
        return tier.unlockCondition == nil
    end
    local cond = tier.unlockCondition
    if cond.minLevel and (gameState.playerLevel or 1) < cond.minLevel then
        return false
    end
    if cond.completedNormal and not gameState.normalCompleted then
        return false
    end
    if cond.completedHard and not gameState.hardCompleted then
        return false
    end
    if cond.campaignChapter3 and not gameState.campaignChapter3Cleared then
        return false
    end
    return true
end

-- ============================================================================
-- 核心 API
-- ============================================================================

function AIDifficultySystem.setDifficulty(level, gameState)
    if level == nil then return false, "难度标识不能为空" end
    local tier = DIFFICULTY_TIERS[level]
    if tier == nil then
        return false, "未知难度: " .. tostring(level)
    end
    if not checkUnlockCondition(tier, gameState) then
        return false, "难度 " .. tier.name .. " 尚未解锁"
    end
    RuntimeDifficultyState.currentDifficulty = level
    return true, "难度已切换为: " .. tier.name
end

function AIDifficultySystem.getCurrentDifficulty()
    return RuntimeDifficultyState.currentDifficulty
end

function AIDifficultySystem.getDifficultyMods(gameState)
    local level = RuntimeDifficultyState.currentDifficulty
    local tier = DIFFICULTY_TIERS[level]
    if tier == nil then
        tier = DIFFICULTY_TIERS.NORMAL
    end
    return {
        level = tier.id,
        name = tier.name,
        enemySpawnMult = tier.enemySpawnMult,
        enemyDmgMult = tier.enemyDmgMult,
        enemyHpMult = tier.enemyHpMult,
        resourceMult = tier.resourceMult,
        eventMult = tier.eventMult,
        bossPowerMult = tier.bossPowerMult,
        rewardBonus = tier.rewardBonus,
    }
end

function AIDifficultySystem.getAvailableDifficulties(gameState)
    local list = {}
    for _, key in ipairs(DIFFICULTY_ORDER) do
        local tier = DIFFICULTY_TIERS[key]
        local unlocked = checkUnlockCondition(tier, gameState)
        table.insert(list, {
            id = tier.id,
            name = tier.name,
            nameEn = tier.nameEn,
            desc = tier.desc,
            unlocked = unlocked,
            isCurrent = (RuntimeDifficultyState.currentDifficulty == tier.id),
        })
    end
    return list
end

function AIDifficultySystem.getDifficultyLabel(level)
    local tier = DIFFICULTY_TIERS[level]
    if tier == nil then
        return "未知"
    end
    return tier.name
end

function AIDifficultySystem.getDifficultyInfo(level)
    local tier = DIFFICULTY_TIERS[level]
    if tier == nil then return nil end
    return {
        id = tier.id,
        name = tier.name,
        nameEn = tier.nameEn,
        desc = tier.desc,
    }
end

-- 便捷：根据 wave 动态修正敌人强度（波次成长曲线）
function AIDifficultySystem.getEnemyScaleAtWave(waveNum)
    local tier = DIFFICULTY_TIERS[RuntimeDifficultyState.currentDifficulty] or DIFFICULTY_TIERS.NORMAL
    local baseGrow = 1 + (waveNum - 1) * 0.05
    return {
        spawnMult = tier.enemySpawnMult * baseGrow,
        dmgMult = tier.enemyDmgMult * baseGrow,
        hpMult = tier.enemyHpMult * baseGrow,
    }
end

-- 获取敌方 AI 行为参数
function AIDifficultySystem.getEnemyAIParams()
    local tier = DIFFICULTY_TIERS[RuntimeDifficultyState.currentDifficulty] or DIFFICULTY_TIERS.NORMAL
    return tier.enemyAI or {
        attackFrequency = 1.0,
        targetPriority = "NEAREST",
        moveStrategy = "COORDINATED",
        skillUsageRate = 1.0,
        retreatThreshold = 0.15,
        comboChance = 0.5,
    }
end

-- ============================================================================
-- 舰队 AI 辅助设置（玩家可选的自动战斗辅助）
-- ============================================================================

local FleetAIAssist = {
    autoAttack = false,       -- 自动攻击最近的敌人
    autoHeal = false,         -- 自动使用维修技能
    autoSkill = false,        -- 自动释放技能
    autoShield = false,        -- 自动使用护盾技能
    autoCure = false,         -- 自动驱散负面状态
    aggroThreshold = 0.8,     -- 自动攻击触发血量阈值（1.0=始终）
    healThreshold = 0.5,       -- 自动治疗触发血量阈值
}

-- 设置舰队 AI 辅助选项
function AIDifficultySystem.setFleetAIAssist(key, value)
    if FleetAIAssist[key] ~= nil then
        FleetAIAssist[key] = value
        return true
    end
    return false
end

-- 批量设置舰队 AI 辅助
function AIDifficultySystem.setFleetAIAssistAll(settings)
    for k, v in pairs(settings) do
        if FleetAIAssist[k] ~= nil then
            FleetAIAssist[k] = v
        end
    end
end

-- 获取舰队 AI 辅助设置
function AIDifficultySystem.getFleetAIAssist()
    local assist = {}
    for k, v in pairs(FleetAIAssist) do
        assist[k] = v
    end
    return assist
end

-- 根据当前难度返回推荐舰队 AI 设置
function AIDifficultySystem.getRecommendedFleetAI(difficultyLevel)
    local tier = DIFFICULTY_TIERS[difficultyLevel or RuntimeDifficultyState.currentDifficulty]
    if not tier then return FleetAIAssist end
    -- 根据难度自动推荐不同的辅助等级
    if tier.id == "EASY" then
        return { autoAttack = true, autoHeal = true, autoSkill = true, autoShield = true, autoCure = true, aggroThreshold = 1.0, healThreshold = 0.7 }
    elseif tier.id == "NORMAL" then
        return { autoAttack = true, autoHeal = true, autoSkill = false, autoShield = true, autoCure = true, aggroThreshold = 0.9, healThreshold = 0.5 }
    elseif tier.id == "HARD" then
        return { autoAttack = false, autoHeal = false, autoSkill = false, autoShield = false, autoCure = false, aggroThreshold = 0.8, healThreshold = 0.3 }
    else -- NIGHTMARE
        return { autoAttack = false, autoHeal = false, autoSkill = false, autoShield = false, autoCure = false, aggroThreshold = 0.6, healThreshold = 0.2 }
    end
end

-- ============================================================================
-- 存档
-- ============================================================================

function AIDifficultySystem.serialize()
    return {
        currentDifficulty = RuntimeDifficultyState.currentDifficulty,
        fleetAIAssist = FleetAIAssist,
    }
end

function AIDifficultySystem.deserialize(data)
    if data == nil then return false end
    if data.currentDifficulty and DIFFICULTY_TIERS[data.currentDifficulty] then
        RuntimeDifficultyState.currentDifficulty = data.currentDifficulty
    end
    if data.fleetAIAssist then
        for k, v in pairs(data.fleetAIAssist) do
            if FleetAIAssist[k] ~= nil then
                FleetAIAssist[k] = v
            end
        end
    end
    return true
end

-- ============================================================================
-- 导出
-- ============================================================================

return AIDifficultySystem
