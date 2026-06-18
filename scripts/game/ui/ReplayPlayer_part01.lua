-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function easeOutCubic(t)
    t = t - 1
    return t * t * t + 1
end
