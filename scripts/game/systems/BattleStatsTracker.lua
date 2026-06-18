---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
BattleStatsTracker.lua - 战斗统计追踪
V2.7 P3-2
单局战斗数据收集 + 雷达图六维计算
]]

local BattleStatsTracker = {}

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
    return currentStats
end

function BattleStatsTracker.recordDamage(amount)
    if not currentStats.started then return end
    currentStats.damageDealt = (currentStats.damageDealt or 0) + (tonumber(amount) or 0)
end

function BattleStatsTracker.recordDamageTaken(amount)
    if not currentStats.started then return end
    currentStats.damageTaken = (currentStats.damageTaken or 0) + (tonumber(amount) or 0)
end

function BattleStatsTracker.recordEnemyKilled(amount)
    if not currentStats.started then return end
    currentStats.enemiesKilled = (currentStats.enemiesKilled or 0) + (tonumber(amount) or 1)
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

local MAX_ATTACK_REF = 10000
local MAX_DEFENSE_REF = 5000
local MAX_ECONOMY_REF = 200
local MAX_EXPLORATION_REF = 30
local MAX_COMMAND_REF = 20
local MAX_TEAMWORK_REF = 15

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

    local economyScore = (stats.enemiesKilled or 0) * 5
        + (stats.damageDealt or 0) * 0.1
        - (stats.shipsLost or 0) * 20
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

return BattleStatsTracker
