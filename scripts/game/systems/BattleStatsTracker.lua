--[[
BattleStatsTracker.lua - 战斗统计追踪（V3.2 P0-2 增强版）

功能：
1. 单局战斗数据收集
2. 舰种贡献度统计
3. 伤害来源分布（物理/能量/爆炸）
4. 时间轴统计（前30秒/中期/尾声）
5. 6 维雷达图计算
6. 战斗摘要生成
]]

local BattleStatsTracker = {}

-- ============================================================================
-- 状态
-- ============================================================================

local currentStats = {
    damageDealt = 0,
    damageTaken = 0,
    shipsLost = 0,
    enemiesKilled = 0,
    skillUses = 0,
    wavesSurvived = 0,
    perfectWaves = 0,
    victory = false,
    started = false,
}

-- V3.2 新增：舰种贡献字典
local shipTypeContribution = {}

-- V3.2 新增：伤害类型分布
local damageTypeDistribution = {
    physical = 0,
    energy = 0,
    explosive = 0,
}

-- V3.2 新增：时间轴统计（秒分段
local timelineStats = {
    ["first30s"] = { damageDealt = 0, damageTaken = 0, kills = 0 },
    ["mid30-90s"] = { damageDealt = 0, damageTaken = 0, kills = 0 },
    ["late90+s"] = { damageDealt = 0, damageTaken = 0, kills = 0 },
}

-- V3.2 新增：战场时间跟踪器
local battleStartTime = nil

local MAX_ATTACK_REF = 10000
local MAX_DEFENSE_REF = 5000
local MAX_ECONOMY_REF = 200
local MAX_EXPLORATION_REF = 30
local MAX_COMMAND_REF = 20
local MAX_TEAMWORK_REF = 15

-- ============================================================================
-- 核心方法
-- ============================================================================

function BattleStatsTracker.startBattle()
    currentStats = {
        damageDealt = 0,
        damageTaken = 0,
        shipsLost = 0,
        enemiesKilled = 0,
        skillUses = 0,
        wavesSurvived = 0,
        perfectWaves = 0,
        victory = false,
        started = true,
    }
    shipTypeContribution = {}
    damageTypeDistribution = {
        physical = 0,
        energy = 0,
        explosive = 0,
    }
    timelineStats = {
        ["first30s"] = { damageDealt = 0, damageTaken = 0, kills = 0 },
        ["mid30-90s"] = { damageDealt = 0, damageTaken = 0, kills = 0 },
        ["late90+s"] = { damageDealt = 0, damageTaken = 0, kills = 0 },
    }
    battleStartTime = os.clock()
    return currentStats
end

-- ============================================================================
-- 伤害相关
-- ============================================================================

function BattleStatsTracker.recordDamage(amount, shipType, dmgType)
    if not currentStats.started then return end
    currentStats.damageDealt = (currentStats.damageDealt or 0) + (tonumber(amount) or 0)

    -- V3.2: 舰种贡献度统计
    if shipType then
        if not shipTypeContribution[shipType] then
            shipTypeContribution[shipType] = {
                damageDealt = 0,
                kills = 0,
                hits = 0,
            }
        end
        shipTypeContribution[shipType].damageDealt = shipTypeContribution[shipType].damageDealt + (tonumber(amount) or 0)
        shipTypeContribution[shipType].hits = shipTypeContribution[shipType].hits + 1
    end

    -- V3.2: 伤害类型统计
    if dmgType and damageTypeDistribution[dmgType] then
        damageTypeDistribution[dmgType] = damageTypeDistribution[dmgType] + (tonumber(amount) or 0)
    end

    -- V3.2: 时间轴统计
    local elapsed = battleStartTime and (os.clock() - battleStartTime) or 0
    if elapsed < 30 then
        timelineStats["first30s"].damageDealt = timelineStats["first30s"].damageDealt + (tonumber(amount) or 0)
    elseif elapsed < 90 then
        timelineStats["mid30-90s"].damageDealt = timelineStats["mid30-90s"].damageDealt + (tonumber(amount) or 0)
    else
        timelineStats["late90+s"].damageDealt = timelineStats["late90+s"].damageDealt + (tonumber(amount) or 0)
    end
end

function BattleStatsTracker.recordDamageTaken(amount, shipType)
    if not currentStats.started then return end
    currentStats.damageTaken = (currentStats.damageTaken or 0) + (tonumber(amount) or 0)

    -- V3.2: 时间轴统计
    local elapsed = battleStartTime and (os.clock() - battleStartTime) or 0
    if elapsed < 30 then
        timelineStats["first30s"].damageTaken = timelineStats["first30s"].damageTaken + (tonumber(amount) or 0)
    elseif elapsed < 90 then
        timelineStats["mid30-90s"].damageTaken = timelineStats["mid30-90s"].damageTaken + (tonumber(amount) or 0)
    else
        timelineStats["late90+s"].damageTaken = timelineStats["late90+s"].damageTaken + (tonumber(amount) or 0)
    end
end

-- ============================================================================
-- 击杀/舰船相关
-- ============================================================================

function BattleStatsTracker.recordEnemyKilled(amount, shipType)
    if not currentStats.started then return end
    currentStats.enemiesKilled = (currentStats.enemiesKilled or 0) + (tonumber(amount) or 1)

    if shipType and shipTypeContribution[shipType] then
        shipTypeContribution[shipType].kills = shipTypeContribution[shipType].kills + (tonumber(amount) or 1)
    end

    -- V3.2: 时间轴统计
    local elapsed = battleStartTime and (os.clock() - battleStartTime) or 0
    if elapsed < 30 then
        timelineStats["first30s"].kills = timelineStats["first30s"].kills + 1
    elseif elapsed < 90 then
        timelineStats["mid30-90s"].kills = timelineStats["mid30-90s"].kills + 1
    else
        timelineStats["late90+s"].kills = timelineStats["late90+s"].kills + 1
    end
end

function BattleStatsTracker.recordShipLost(amount)
    if not currentStats.started then return end
    currentStats.shipsLost = (currentStats.shipsLost or 0) + (tonumber(amount) or 1)
end

function BattleStatsTracker.recordSkillUse()
    if not currentStats.started then return end
    currentStats.skillUses = (currentStats.skillUses or 0) + 1
end

function BattleStatsTracker.recordWave(perfect)
    if not currentStats.started then return end
    currentStats.wavesSurvived = (currentStats.wavesSurvived or 0) + 1
    if perfect then
        currentStats.perfectWaves = (currentStats.perfectWaves or 0) + 1
    end
end

-- ============================================================================
-- 战斗结束
-- ============================================================================

function BattleStatsTracker.endBattle(victory)
    local summary = {
        damageDealt = currentStats.damageDealt,
        damageTaken = currentStats.damageTaken,
        shipsLost = currentStats.shipsLost,
        enemiesKilled = currentStats.enemiesKilled,
        skillUses = currentStats.skillUses,
        wavesSurvived = currentStats.wavesSurvived,
        perfectWaves = currentStats.perfectWaves,
        victory = not not victory,
    }

    -- V3.2: 添加扩展统计
    summary.shipTypeContribution = {}
    for shipType, data in pairs(shipTypeContribution) do
        table.insert(summary.shipTypeContribution, {
            shipType = shipType,
            damageDealt = data.damageDealt,
            kills = data.kills,
            hits = data.hits,
        })
    end
    table.sort(summary.shipTypeContribution, function(a, b) return a.damageDealt > b.damageDealt end)

    summary.damageTypeDistribution = {
        physical = damageTypeDistribution.physical,
        energy = damageTypeDistribution.energy,
        explosive = damageTypeDistribution.explosive,
    }

    summary.timelineStats = {
        first30s = timelineStats["first30s"],
        mid30_90s = timelineStats["mid30-90s"],
        late90s = timelineStats["late90+s"],
    }

    -- V3.2: 战斗时长
    summary.battleDuration = battleStartTime and (os.clock() - battleStartTime) or 0

    currentStats.started = false
    return summary
end

function BattleStatsTracker.getCurrent()
    return {
        damageDealt = currentStats.damageDealt,
        damageTaken = currentStats.damageTaken,
        shipsLost = currentStats.shipsLost,
        enemiesKilled = currentStats.enemiesKilled,
        skillUses = currentStats.skillUses,
        wavesSurvived = currentStats.wavesSurvived,
        perfectWaves = currentStats.perfectWaves,
        started = currentStats.started,
    }
end

-- ============================================================================
-- V3.2 新增：舰种贡献度排行榜
-- ============================================================================

function BattleStatsTracker.getShipTypeRanking()
    local ranking = {}
    for shipType, data in pairs(shipTypeContribution) do
        table.insert(ranking, {
            shipType = shipType,
            damageDealt = data.damageDealt,
            kills = data.kills,
            hits = data.hits,
            avgDamage = data.hits > 0 and data.damageDealt / data.hits or 0,
        })
    end
    table.sort(ranking, function(a, b) return a.damageDealt > b.damageDealt end)
    return ranking
end

-- ============================================================================
-- V3.2 新增：MVP 舰种
-- ============================================================================

function BattleStatsTracker.getMvpShipType()
    local ranking = BattleStatsTracker.getShipTypeRanking()
    if #ranking > 0 then
        return ranking[1].shipType, ranking[1].damageDealt
    end
    return nil, 0
end

-- ============================================================================
-- V3.2 新增：伤害类型分布（百分比
-- ============================================================================

function BattleStatsTracker.getDamageTypeBreakdown()
    local total = damageTypeDistribution.physical + damageTypeDistribution.energy + damageTypeDistribution.explosive
    if total <= 0 then
        return { physical = 0, energy = 0, explosive = 0 }
    end
    return {
        physical = damageTypeDistribution.physical,
        energy = damageTypeDistribution.energy,
        explosive = damageTypeDistribution.explosive,
        physicalPercent = math.floor(damageTypeDistribution.physical / total * 100 + 0.5),
        energyPercent = math.floor(damageTypeDistribution.energy / total * 100 + 0.5),
        explosivePercent = 100 - math.floor(damageTypeDistribution.physical / total * 100 + 0.5) - math.floor(damageTypeDistribution.energy / total * 100 + 0.5),
    }
end

-- ============================================================================
-- V3.2 新增：时间轴统计分析
-- ============================================================================

function BattleStatsTracker.getTimelineAnalysis()
    return {
        first30s = timelineStats["first30s"],
        mid30_90s = timelineStats["mid30-90s"],
        late90s = timelineStats["late90+s"],
        battlePhase = battleStartTime and (os.clock() - battleStartTime) < 30 and "early" or
                      battleStartTime and (os.clock() - battleStartTime) < 90 and "mid" or "late",
    }
end

-- ============================================================================
-- 6 维雷达图计算
-- ============================================================================

local function clamp01(v, max)
    if not v or v <= 0 then return 0 end
    if v >= max then return 1 end
    return v / max
end

function BattleStatsTracker.getRadarData(battleStats)
    local stats = battleStats or BattleStatsTracker.getCurrent()

    local attack = clamp01(stats.damageDealt or 0, MAX_ATTACK_REF)
    local defenseRaw = 1 - clamp01(stats.damageTaken or 0, MAX_DEFENSE_REF)
    local defense = math.max(0, defenseRaw - clamp01(stats.shipsLost or 0, 10) * 0.5)
    local economyScore = (stats.enemiesKilled or 0) * 5 + (stats.damageDealt or 0) * 0.1 - (stats.shipsLost or 0) * 20
    local economy = clamp01(math.max(0, economyScore), MAX_ECONOMY_REF)
    local exploration = clamp01(stats.wavesSurvived or 0, MAX_EXPLORATION_REF)
    local command = clamp01(stats.skillUses or 0, MAX_COMMAND_REF)
    local teamwork = clamp01(stats.perfectWaves or 0, MAX_TEAMWORK_REF)

    return {
        attack = attack,
        defense = defense,
        economy = economy,
        exploration = exploration,
        command = command,
        teamwork = teamwork,
    }
end

-- ============================================================================
-- V3.2 新增：生成战斗综合报告
-- ============================================================================

function BattleStatsTracker.generateReport(battleSummary)
    local summary = battleSummary or BattleStatsTracker.getCurrent()
    local radar = BattleStatsTracker.getRadarData(summary)
    local ranking = BattleStatsTracker.getShipTypeRanking()
    local mvpShip, mvpDamage = BattleStatsTracker.getMvpShipType()
    local dmgBreakdown = BattleStatsTracker.getDamageTypeBreakdown()
    local timeline = BattleStatsTracker.getTimelineAnalysis()

    -- 生成简单的文字报告
    local reportLines = {}
    table.insert(reportLines, "=== 战斗报告 ===")
    table.insert(reportLines, "战斗结果: " .. (summary.victory and "胜利" or "失败"))
    table.insert(reportLines, "战斗时长: " .. string.format("%.1f 秒", summary.battleDuration or 0))
    table.insert(reportLines, "存活波次: " .. tostring(summary.wavesSurvived or 0))
    table.insert(reportLines, "击杀敌舰: " .. tostring(summary.enemiesKilled or 0))
    table.insert(reportLines, "输出伤害: " .. tostring(summary.damageDealt or 0))
    table.insert(reportLines, "承受伤害: " .. tostring(summary.damageTaken or 0))
    table.insert(reportLines, "损失舰船: " .. tostring(summary.shipsLost or 0))
    table.insert(reportLines, "技能使用: " .. tostring(summary.skillUses or 0))
    table.insert(reportLines, "完美波次: " .. tostring(summary.perfectWaves or 0))
    table.insert(reportLines, "MVP 舰种: " .. (mvpShip or "无") .. " (" .. tostring(mvpDamage) .. " 伤害)")
    table.insert(reportLines, "伤害分布 (物理/能量/爆炸): " .. tostring(dmgBreakdown.physical) .. "/" .. tostring(dmgBreakdown.energy) .. "/" .. tostring(dmgBreakdown.explosive))

    if #ranking > 0 then
        table.insert(reportLines, "舰种贡献度:")
        for i, ship in ipairs(ranking) do
            if i <= 5 then
                table.insert(reportLines, "  " .. tostring(ship.shipType) .. ": " .. tostring(ship.damageDealt) .. " 伤害, " .. tostring(ship.kills) .. " 击杀")
            end
        end
    end

    table.insert(reportLines, "6 维评估:")
    table.insert(reportLines, "  攻击: " .. string.format("%.0f%%", radar.attack * 100))
    table.insert(reportLines, "  防御: " .. string.format("%.0f%%", radar.defense * 100))
    table.insert(reportLines, "  经济: " .. string.format("%.0f%%", radar.economy * 100))
    table.insert(reportLines, "  探索: " .. string.format("%.0f%%", radar.exploration * 100))
    table.insert(reportLines, "  指挥: " .. string.format("%.0f%%", radar.command * 100))
    table.insert(reportLines, "  团队: " .. string.format("%.0f%%", radar.teamwork * 100))

    return {
        textReport = table.concat(reportLines, "\n"),
        radar = radar,
        shipRanking = ranking,
        mvpShip = mvpShip,
        mvpDamage = mvpDamage,
        damageBreakdown = dmgBreakdown,
        timeline = timeline,
        summary = summary,
    }
end

return BattleStatsTracker
