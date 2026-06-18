-- Auto-split from Client.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function getAdCount()
    return math.floor((TL.MAX_EXTRA - TL.extraTime) / TL.EXTRA_PER_AD)
end
