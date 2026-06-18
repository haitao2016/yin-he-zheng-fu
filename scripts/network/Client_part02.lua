-- Auto-split from Client.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function getRemainingTime()
    return math.max(0, TL.BASE_LIMIT + TL.extraTime - TL.playTime)
end
