-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function lerp(a, b, t)
    return a + (b - a) * math.max(0, math.min(1, t))
end
