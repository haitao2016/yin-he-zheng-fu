-- ============================================================================
-- game/ui/FleetPanelNaming.lua  -- 舰队命名子模块
-- ============================================================================

local UICommon = require("game.ui.UICommon")

local M = {}

local namingActive_   = false
local namingFleetId_  = nil
local namingText_     = ""
local LONG_PRESS_T    = 0.5
local NAME_MAX_LEN    = 8

local FLEET_NAME_POOL = {
    "利刃中队", "暴风编队", "幽灵小队", "铁壁舰群",
    "雷霆战队", "黑鹰突击", "星火纵队", "猎鹰中队",
    "银翼编队", "暗影小队", "赤焰舰群", "极光战队",
    "苍狼突击", "寒冰纵队", "烈焰中队", "龙吟编队",
    "凤凰小队", "天罡舰群", "破晓战队", "暮光突击",
    "星陨纵队", "霜刃中队", "怒涛编队", "鬼面小队",
    "血翼舰群", "流星战队", "黑洞突击", "裂空纵队",
    "冥王中队", "深渊编队",
}

function M.randomFleetName()
    return FLEET_NAME_POOL[math.random(1, #FLEET_NAME_POOL)]
end

function M.open(fleetId)
    local fm = UICommon.fm
    if not fm or not fm.fleets[fleetId] then return end
    namingActive_  = true
    namingFleetId_ = fleetId
    namingText_    = fm.fleets[fleetId].name or ""
end

function M.close()
    namingActive_  = false
    namingFleetId_ = nil
    namingText_    = ""
end

function M.confirm()
    local fm = UICommon.fm
    if fm and namingFleetId_ and fm.fleets[namingFleetId_] then
        local name = namingText_
        if #name == 0 then name = "第 " .. namingFleetId_ .. " 编队" end
        fm.fleets[namingFleetId_].name = name
    end
    M.close()
end

function M.OnTextInput(text)
    if not namingActive_ then return end
    local charCount = utf8.len(namingText_) or 0
    local newCharCount = utf8.len(text) or 0
    if charCount + newCharCount <= NAME_MAX_LEN then
        namingText_ = namingText_ .. text
    end
end

function M.OnBackspace()
    if not namingActive_ then return end
    if #namingText_ > 0 then
        local bytes = {utf8.codepoint(namingText_, 1, #namingText_)}
        if #bytes > 0 then
            table.remove(bytes, #bytes)
            local parts = {}
            for _, cp in ipairs(bytes) do
                parts[#parts+1] = utf8.char(cp)
            end
            namingText_ = table.concat(parts)
        end
    end
end

function M.OnEnter()
    if not namingActive_ then return end
    M.confirm()
end

function M.IsActive() 
    return namingActive_ 
end

function M.GetFleetId()
    return namingFleetId_
end

function M.GetText()
    return namingText_
end

return M