-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end
