---@diagnostic disable: assign-type-mismatch, return-type-mismatch
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
        unlockCondition = nil,
        rewardBonus = 1.0,
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

-- ============================================================================
-- 存档
-- ============================================================================

function AIDifficultySystem.serialize()
    return {
        currentDifficulty = RuntimeDifficultyState.currentDifficulty,
    }
end

function AIDifficultySystem.deserialize(data)
    if data == nil then return false end
    if data.currentDifficulty and DIFFICULTY_TIERS[data.currentDifficulty] then
        RuntimeDifficultyState.currentDifficulty = data.currentDifficulty
    end
    return true
end

-- ============================================================================
-- 导出
-- ============================================================================

return AIDifficultySystem
