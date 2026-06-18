-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function easeOutBack(t)
    local c = 1.7
    t = t - 1
    return t * t * ((c + 1) * t + c) + 1
end
