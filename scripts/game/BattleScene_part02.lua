-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function syncAIVarsBack()
    local v = BattleAI.GetVarsOut()
    scoutAuraApplied_   = v.scoutAuraApplied
    explorerMarkTarget_ = v.explorerMarkTarget
    engineerHealTimer_  = v.engineerHealTimer
end
