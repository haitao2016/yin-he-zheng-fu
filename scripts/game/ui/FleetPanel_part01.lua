-- Auto-split from FleetPanel.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function randomFleetName()
    return FLEET_NAME_POOL[math.random(1, #FLEET_NAME_POOL)]
end
