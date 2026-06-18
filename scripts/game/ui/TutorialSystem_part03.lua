-- Auto-split from TutorialSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function TutorialSystem.Reset()
    completed_   = {}
    phaseDone_   = {}
    active_      = false
    currentStep_ = nil
    stepQueue_   = {}
    stepIdx_     = 0
    enabled_     = true
end
