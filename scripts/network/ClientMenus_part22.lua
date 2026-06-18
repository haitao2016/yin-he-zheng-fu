-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function getHeritageClosePos(sw, sh)
    local PW = math.min(620, sw - 40)
    local px = (sw - PW) * 0.5
    local py = (sh - 460) * 0.5
    return px + PW - 20, py + 20
end
