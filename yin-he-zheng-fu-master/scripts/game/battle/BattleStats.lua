-- ============================================================================
-- game/battle/BattleStats.lua  -- 战斗统计模块
-- ============================================================================

local M = {}

local BATTLE_LOG_MAX = 30

local battleStats_ = {
    dmgDealt     = 0,
    dmgTaken     = 0,
    enemiesKilled= 0,
    wavesCleared = 0,
    bestSurvivor = nil,
    shipsLost    = 0,
    overkillMax  = 0,
    focusBossKill = false,
    focusKillCount= 0,
    chainCount   = 0,
    reinforceWin = false,
    maxCombo     = 0,
}

local battleLog_ = {}
local fleetName_ = "舰队"

function M.SetFleetName(name)
    fleetName_ = name or "舰队"
end

function M.AddBattleEvent(text)
    table.insert(battleLog_, { wave = 0, text = text })
    if #battleLog_ > BATTLE_LOG_MAX then
        table.remove(battleLog_, 1)
    end
end

function M.SetWaveNum(waveNum)
    for _, entry in ipairs(battleLog_) do
        if entry.wave == 0 then
            entry.wave = waveNum
        end
    end
end

function M.GetBattleLog()
    return battleLog_
end

function M.Reset()
    battleStats_ = {
        dmgDealt     = 0,
        dmgTaken     = 0,
        enemiesKilled= 0,
        wavesCleared = 0,
        bestSurvivor = nil,
        shipsLost    = 0,
        overkillMax  = 0,
        focusBossKill = false,
        focusKillCount= 0,
        chainCount   = 0,
        reinforceWin = false,
        maxCombo     = 0,
    }
    battleLog_ = {}
end

function M.AddDmgDealt(amount)
    battleStats_.dmgDealt = battleStats_.dmgDealt + amount
end

function M.AddDmgTaken(amount)
    battleStats_.dmgTaken = battleStats_.dmgTaken + amount
end

function M.AddEnemyKill()
    battleStats_.enemiesKilled = battleStats_.enemiesKilled + 1
end

function M.AddWaveCleared()
    battleStats_.wavesCleared = battleStats_.wavesCleared + 1
end

function M.SetBestSurvivor(stype)
    battleStats_.bestSurvivor = stype
end

function M.AddShipLost()
    battleStats_.shipsLost = battleStats_.shipsLost + 1
end

function M.UpdateOverkillMax(overkill)
    if overkill > battleStats_.overkillMax then
        battleStats_.overkillMax = overkill
    end
end

function M.SetFocusBossKill(value)
    battleStats_.focusBossKill = value
end

function M.AddFocusKill()
    battleStats_.focusKillCount = battleStats_.focusKillCount + 1
end

function M.AddChainCount()
    battleStats_.chainCount = battleStats_.chainCount + 1
end

function M.SetReinforceWin(value)
    battleStats_.reinforceWin = value
end

function M.SetMaxCombo(combo)
    if combo > battleStats_.maxCombo then
        battleStats_.maxCombo = combo
    end
end

function M.GetStats()
    return battleStats_
end

return M