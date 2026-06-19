---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/AIDifficultySystem.lua -- AI 难度分级系统
-- V3.1 P1-4 平衡性全局调优
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
        waveGrowthRate = 0.03,      -- V3.1-P1-4: 波次成长率降低，新手友好
        enemyAI = {
            attackFrequency = 0.7,
            targetPriority = "HIGHEST_HP",
            moveStrategy = "AGGRESSIVE",
            skillUsageRate = 0.5,
            retreatThreshold = 0.2,
            comboChance = 0.3,
            aiReactionTime = 1.5,    -- V3.1-P1-4: AI 反应时间加长，更易被击败
        },
        unlockCondition = nil,
        rewardBonus = 0.5,
        winRateTarget = 0.80,      -- V3.1-P1-4: 目标胜率 80%
        recommendedLevel = 1,       -- 推荐玩家等级
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
        waveGrowthRate = 0.05,
        enemyAI = {
            attackFrequency = 1.0,
            targetPriority = "NEAREST",
            moveStrategy = "COORDINATED",
            skillUsageRate = 1.0,
            retreatThreshold = 0.15,
            comboChance = 0.5,
            aiReactionTime = 1.0,
        },
        unlockCondition = nil,
        rewardBonus = 1.0,
        winRateTarget = 0.60,      -- 目标胜率 60%
        recommendedLevel = 5,
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
        waveGrowthRate = 0.06,      -- 困难难度波次成长略快
        enemyAI = {
            attackFrequency = 1.3,
            targetPriority = "LOWEST_HP",
            moveStrategy = "AGGRESSIVE",
            skillUsageRate = 1.5,
            retreatThreshold = 0.1,
            comboChance = 0.7,
            aiReactionTime = 0.8,
        },
        unlockCondition = { completedNormal = true, minLevel = 10 },
        rewardBonus = 1.5,
        winRateTarget = 0.40,      -- 目标胜率 40%
        recommendedLevel = 15,
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
        waveGrowthRate = 0.07,
        enemyAI = {
            attackFrequency = 1.6,
            targetPriority = "STRONGEST",
            moveStrategy = "DEFENSIVE",
            skillUsageRate = 2.0,
            retreatThreshold = 0.05,
            comboChance = 0.9,
            aiReactionTime = 0.5,
        },
        unlockCondition = { completedHard = true, minLevel = 30, campaignChapter3 = true },
        rewardBonus = 2.5,
        winRateTarget = 0.25,      -- 目标胜率 25%
        recommendedLevel = 30,
    },
    INSANE = {
        id = "INSANE",
        name = "炼狱",
        nameEn = "Insane",
        desc = "终极挑战：敌人拥有完美战术与碾压属性，资源极度稀缺。仅为真正的指挥官准备。",
        enemySpawnMult = 2.0,
        enemyDmgMult = 2.3,
        enemyHpMult = 2.2,
        resourceMult = 0.45,
        eventMult = 2.0,
        bossPowerMult = 2.3,
        waveGrowthRate = 0.08,      -- 炼狱难度波次成长最快
        enemyAI = {
            attackFrequency = 2.0,
            targetPriority = "OPTIMAL",
            moveStrategy = "PREDICTIVE",
            skillUsageRate = 2.5,
            retreatThreshold = 0.0,
            comboChance = 1.0,
            feintRate = 0.4,
            focusFireChance = 0.8,
            flankChance = 0.6,
            aiReactionTime = 0.3,   -- 几乎无延迟
        },
        unlockCondition = { completedNightmare = true, minLevel = 50, campaignAllChapters = true },
        rewardBonus = 4.0,
        winRateTarget = 0.12,      -- 目标胜率 12%（极难）
        recommendedLevel = 50,
    },
}

-- 难度顺序列表（用于 UI 遍历）
local DIFFICULTY_ORDER = { "EASY", "NORMAL", "HARD", "NIGHTMARE", "INSANE" }

-- V3.1-P1-4: 难度曲线参数
local DIFFICULTY_CURVE = {
    maxWaveBase = 50,        -- 基础最大波次
    difficultyScaling = {      -- 各难度曲线陡峭度
        EASY = 0.8,
        NORMAL = 1.0,
        HARD = 1.2,
        NIGHTMARE = 1.4,
        INSANE = 1.6,
    },
    bossWaveInterval = 10,     -- Boss 波次间隔
    eliteWaveInterval = 5,     -- 精英波次间隔
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local RuntimeDifficultyState = {
    currentDifficulty = "NORMAL",
    sessionStats = {           -- V3.1-P1-4: 本次会话统计
        wins = 0,
        losses = 0,
        currentStreak = 0,     -- 当前连胜/连败
        bestWave = 0,
        avgWave = 0,
    },
    playerSkillRating = 1000,  -- V3.1-P1-4: 玩家技术评分（类似 MMR）
}

-- ============================================================================
-- 解锁条件检查
-- ============================================================================

---@param tier table
---@param gameState table
---@return boolean
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
    -- P1-1: 炼狱难度的解锁条件检查
    if cond.completedNightmare and not gameState.nightmareCompleted then
        return false
    end
    if cond.campaignAllChapters and not gameState.campaignAllCleared then
        return false
    end
    return true
end

-- V3.1-P1-4: 动态难度调整（DDA）增强版
---@param playerHpRatio number
---@param waveProgress number
---@param consecutiveLosses number
---@return table
function AIDifficultySystem.dynamicAdjust(playerHpRatio, waveProgress, consecutiveLosses)
    local tier = DIFFICULTY_TIERS[RuntimeDifficultyState.currentDifficulty]
    if not tier then return { dmgMult = 1.0, hpMult = 1.0, spawnMult = 1.0 } end

    -- 基础调整
    local adjustments = {
        dmgMult = 1.0,
        hpMult = 1.0,
        spawnMult = 1.0,
    }

    -- 连胜惩罚：玩家表现太好时略微增强敌人
    if consecutiveLosses and consecutiveLosses <= -3 then
        adjustments.dmgMult = adjustments.dmgMult * 1.05
        adjustments.hpMult = adjustments.hpMult * 1.05
    end

    -- 血量保护：玩家血量极低时降低难度
    if playerHpRatio and playerHpRatio < 0.2 then
        adjustments.dmgMult = adjustments.dmgMult * 0.7
        adjustments.hpMult = adjustments.hpMult * 0.8
        adjustments.spawnMult = adjustments.spawnMult * 0.9
    elseif playerHpRatio and playerHpRatio < 0.4 then
        adjustments.dmgMult = adjustments.dmgMult * 0.85
    end

    -- 血量优势惩罚：玩家表现太好时略微增强敌人
    if playerHpRatio and playerHpRatio > 0.9 and waveProgress and waveProgress < 0.5 then
        adjustments.dmgMult = adjustments.dmgMult * 1.1
        adjustments.spawnMult = adjustments.spawnMult * 1.05
    end

    return adjustments
end

-- ============================================================================
-- 核心 API
-- ============================================================================

---@param level string
---@param gameState table
---@return boolean, string
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

---@return string
function AIDifficultySystem.getCurrentDifficulty()
    return RuntimeDifficultyState.currentDifficulty
end

---@param gameState table
---@return table
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

---@param gameState table
---@return table
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

---@param level string
---@return string
function AIDifficultySystem.getDifficultyLabel(level)
    local tier = DIFFICULTY_TIERS[level]
    if tier == nil then
        return "未知"
    end
    return tier.name
end

---@param level string
---@return table|nil
function AIDifficultySystem.getDifficultyInfo(level)
    local tier = DIFFICULTY_TIERS[level]
    if tier == nil then return nil end
    return {
        id = tier.id,
        name = tier.name,
        nameEn = tier.nameEn,
        desc = tier.desc,
        recommendedLevel = tier.recommendedLevel,
        winRateTarget = tier.winRateTarget,
        rewardBonus = tier.rewardBonus,
    }
end

-- V3.1-P1-4: 增强版波次成长曲线计算
---@param waveNum number
---@param playerLevel number
---@return table
function AIDifficultySystem.getEnemyScaleAtWave(waveNum, playerLevel)
    local tier = DIFFICULTY_TIERS[RuntimeDifficultyState.currentDifficulty] or DIFFICULTY_TIERS.NORMAL
    local levelScaling = 1.0

    -- 玩家等级与难度匹配度调整
    if playerLevel then
        local diff = playerLevel - (tier.recommendedLevel or 5)
        if diff < 0 then
            -- 玩家等级低于推荐，每低 5 级，敌人强度降低 5%
            levelScaling = 1.0 + (diff / 5) * 0.05
        else
            -- 玩家等级高于推荐，每高 5 级，敌人强度提升 3%
            levelScaling = 1.0 + (diff / 5) * 0.03
        end
    end

    -- 使用难度特定的波次成长率
    local waveGrowthRate = tier.waveGrowthRate or 0.05
    local baseGrow = 1 + (waveNum - 1) * waveGrowthRate

    -- Boss 波次额外加成
    local isBossWave = waveNum % DIFFICULTY_CURVE.bossWaveInterval == 0
    local bossMult = isBossWave and 1.5 or 1.0

    -- 精英波次额外加成
    local isEliteWave = waveNum % DIFFICULTY_CURVE.eliteWaveInterval == 0
    local eliteMult = isEliteWave and 1.2 or 1.0

    return {
        spawnMult = tier.enemySpawnMult * baseGrow * eliteMult,
        dmgMult = tier.enemyDmgMult * baseGrow * bossMult,
        hpMult = tier.enemyHpMult * baseGrow * bossMult * eliteMult,
        isBossWave = isBossWave,
        isEliteWave = isEliteWave,
        waveGrowthRate = waveGrowthRate,
        levelScaling = levelScaling,
    }
end

-- V3.1-P1-4: 获取难度对比信息（用于 UI 显示）
---@param difficultyId string
---@return table|nil
function AIDifficultySystem.getDifficultyComparison(difficultyId)
    local tier = DIFFICULTY_TIERS[difficultyId]
    if not tier then return nil end

    local compareTiers = {
        { id = "EASY", label = "简单" },
        { id = "NORMAL", label = "普通" },
        { id = "HARD", label = "困难" },
        { id = "NIGHTMARE", label = "噩梦" },
        { id = "INSANE", label = "炼狱" },
    }

    local comparisons = {}
    for _, compare in ipairs(compareTiers) do
        local compareTier = DIFFICULTY_TIERS[compare.id]
        if compareTier then
            table.insert(comparisons, {
                id = compare.id,
                label = compare.label,
                enemyPowerRatio = tier.enemySpawnMult / compareTier.enemySpawnMult,
                dmgRatio = tier.enemyDmgMult / compareTier.enemyDmgMult,
                resourceRatio = compareTier.resourceMult / tier.resourceMult,
            })
        end
    end

    return {
        current = tier,
        comparisons = comparisons,
        recommendedLevel = tier.recommendedLevel,
        winRateTarget = tier.winRateTarget,
        estimatedClearWaves = math.floor(DIFFICULTY_CURVE.maxWaveBase * (DIFFICULTY_CURVE.difficultyScaling[difficultyId] or 1.0)),
    }
end

-- V3.1-P1-4: 获取难度预览信息（用于难度选择界面）
---@param difficultyId string
---@return table|nil
function AIDifficultySystem.getDifficultyPreview(difficultyId)
    local tier = DIFFICULTY_TIERS[difficultyId]
    if not tier then return nil end

    return {
        id = tier.id,
        name = tier.name,
        nameEn = tier.nameEn,
        desc = tier.desc,
        enemyPower = math.floor(tier.enemySpawnMult * 100),
        resourceIncome = math.floor(tier.resourceMult * 100),
        rewardBonus = math.floor(tier.rewardBonus * 100),
        recommendedLevel = tier.recommendedLevel,
        winRateTarget = tier.winRateTarget,
        keyFeatures = {
            tier.enemySpawnMult > 1.3 and "敌人强化" or nil,
            tier.enemyDmgMult > 1.5 and "敌人伤害提升" or nil,
            tier.resourceMult < 0.8 and "资源稀缺" or nil,
            tier.enemyAI.skillUsageRate > 1.5 and "敌人技能频繁" or nil,
            tier.enemyAI.feintRate and tier.enemyAI.feintRate > 0.3 and "AI 会使用战术欺骗" or nil,
        },
    }
end

-- V3.1-P1-4: 获取难度推荐（基于玩家历史表现）
---@param playerLevel number
---@param historicalWins number
---@param historicalLosses number
---@return string
function AIDifficultySystem.getRecommendedDifficulty(playerLevel, historicalWins, historicalLosses)
    local totalGames = historicalWins + historicalLosses
    if totalGames < 3 then
        -- 游戏经验不足，默认推荐简单
        return "EASY"
    end

    local winRate = historicalWins / totalGames
    local bestWave = RuntimeDifficultyState.sessionStats.bestWave or 0
    local skillRating = RuntimeDifficultyState.playerSkillRating

    -- 基于胜率和波次历史推荐难度
    if winRate > 0.85 and bestWave > 30 then
        if playerLevel >= 50 then return "INSANE"
        elseif playerLevel >= 30 then return "NIGHTMARE"
        else return "HARD" end
    elseif winRate > 0.65 and bestWave > 20 then
        if playerLevel >= 15 then return "HARD"
        else return "NORMAL" end
    elseif winRate > 0.4 then
        return "NORMAL"
    else
        return "EASY"
    end
end

-- 获取敌方 AI 行为参数
---@return table
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
---@param key string
---@param value any
---@return boolean
function AIDifficultySystem.setFleetAIAssist(key, value)
    if FleetAIAssist[key] ~= nil then
        FleetAIAssist[key] = value
        return true
    end
    return false
end

-- 批量设置舰队 AI 辅助
---@param settings table
function AIDifficultySystem.setFleetAIAssistAll(settings)
    for k, v in pairs(settings) do
        if FleetAIAssist[k] ~= nil then
            FleetAIAssist[k] = v
        end
    end
end

-- 获取舰队 AI 辅助设置
---@return table
function AIDifficultySystem.getFleetAIAssist()
    local assist = {}
    for k, v in pairs(FleetAIAssist) do
        assist[k] = v
    end
    return assist
end

-- 根据当前难度返回推荐舰队 AI 设置
---@param difficultyLevel string
---@return table
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
    else -- NIGHTMARE / INSANE
        return { autoAttack = false, autoHeal = false, autoSkill = false, autoShield = false, autoCure = false, aggroThreshold = 0.6, healThreshold = 0.2 }
    end
end

-- ============================================================================
-- V3.1-P1-4: 会话统计更新
-- ============================================================================

---@param result string
---@param waveReached number
function AIDifficultySystem.updateSessionStats(result, waveReached)
    local stats = RuntimeDifficultyState.sessionStats

    if result == "win" then
        stats.wins = stats.wins + 1
        stats.currentStreak = math.min(stats.currentStreak + 1, 10)
        -- 胜利时更新技能评分
        RuntimeDifficultyState.playerSkillRating = RuntimeDifficultyState.playerSkillRating + 25
    elseif result == "loss" then
        stats.losses = stats.losses + 1
        stats.currentStreak = math.max(stats.currentStreak - 1, -10)
        -- 失败时降低技能评分
        RuntimeDifficultyState.playerSkillRating = math.max(RuntimeDifficultyState.playerSkillRating - 15, 500)
    end

    -- 更新最佳波次
    if waveReached and waveReached > stats.bestWave then
        stats.bestWave = waveReached
    end

    -- 更新平均波次
    local totalGames = stats.wins + stats.losses
    if totalGames > 0 then
        stats.avgWave = (stats.avgWave * (totalGames - 1) + (waveReached or 0)) / totalGames
    end
end

---@return table
function AIDifficultySystem.getSessionStats()
    local stats = RuntimeDifficultyState.sessionStats
    local totalGames = stats.wins + stats.losses
    return {
        wins = stats.wins,
        losses = stats.losses,
        totalGames = totalGames,
        winRate = totalGames > 0 and (stats.wins / totalGames) or 0,
        currentStreak = stats.currentStreak,
        bestWave = stats.bestWave,
        avgWave = math.floor(stats.avgWave or 0),
        skillRating = RuntimeDifficultyState.playerSkillRating,
    }
end

function AIDifficultySystem.resetSessionStats()
    RuntimeDifficultyState.sessionStats = {
        wins = 0,
        losses = 0,
        currentStreak = 0,
        bestWave = 0,
        avgWave = 0,
    }
    RuntimeDifficultyState.playerSkillRating = 1000
end

-- ============================================================================
-- 存档
-- ============================================================================

---@return table
function AIDifficultySystem.serialize()
    return {
        currentDifficulty = RuntimeDifficultyState.currentDifficulty,
        fleetAIAssist = FleetAIAssist,
        sessionStats = RuntimeDifficultyState.sessionStats,
        playerSkillRating = RuntimeDifficultyState.playerSkillRating,
    }
end

---@param data table
---@return boolean
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
    -- V3.1-P1-4: 加载会话统计
    if data.sessionStats then
        RuntimeDifficultyState.sessionStats = data.sessionStats
    end
    if data.playerSkillRating then
        RuntimeDifficultyState.playerSkillRating = data.playerSkillRating
    end
    return true
end

-- ============================================================================
-- 导出
-- ============================================================================

return AIDifficultySystem
