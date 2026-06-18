-- Auto-split from TutorialSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function TutorialSystem.SetEnabled(flag)
    enabled_ = flag ~= false
    if not enabled_ then
        -- 立刻关闭当前弹窗
        active_      = false
        currentStep_ = nil
        stepQueue_   = {}
        stepIdx_     = 0
    end
end
