-- ============================================================================
-- game/ui/FleetPanelPresets.lua  -- 编队预设子模块
-- ============================================================================

local UICommon = require("game.ui.UICommon")

local M = {}

local presets_        = {nil, nil, nil}
local PRESET_SLOT_N   = 3

function M.GetPresets()
    return presets_
end

function M.SaveToPreset(slotIdx, fm, fleetId)
    if slotIdx < 1 or slotIdx > PRESET_SLOT_N then return end
    local fleet = fm and fm.fleets and fm.fleets[fleetId]
    if not fleet then return end
    local snap = {}
    for _, e in ipairs(fleet.ships) do
        snap[#snap+1] = { shipType = e.shipType, count = e.count }
    end
    local label = "编队" .. fleetId .. " 预设" .. slotIdx
    presets_[slotIdx] = { label = label, ships = snap }
end

function M.ApplyPreset(slotIdx, fm, fleetId)
    if slotIdx < 1 or slotIdx > PRESET_SLOT_N then return end
    local preset = presets_[slotIdx]
    if not preset or not fm then return end
    local fleet = fm.fleets[fleetId]
    if not fleet then return end
    
    local haveMap = {}
    for _, e in ipairs(fleet.ships) do 
        haveMap[e.shipType] = e.count 
    end
    
    for _, entry in ipairs(preset.ships) do
        local have = haveMap[entry.shipType] or 0
        local need = entry.count - have
        if need > 0 then
            for _ = 1, need do
                fm:assignFromReserve(entry.shipType, fleetId)
            end
        end
    end
end

function M.ClearPreset(slotIdx)
    if slotIdx < 1 or slotIdx > PRESET_SLOT_N then return end
    presets_[slotIdx] = nil
end

function M.ClearAll()
    presets_ = {nil, nil, nil}
end

function M.GetSlotCount()
    return PRESET_SLOT_N
end

return M