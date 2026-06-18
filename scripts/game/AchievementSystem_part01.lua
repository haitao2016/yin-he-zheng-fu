-- Auto-split from AchievementSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function AchievementSystem.Init(opts)
    notifyFn_   = opts.notifyFn  or function() end
    onUnlockFn_ = opts.onUnlock  or function() end
    audioFn_    = opts.onAudio   or nil
    unlocked_      = {}
    redeemed_      = {}
    pendingUnlocks_ = {}
    flushTimer_    = 0
    if opts.unlocked then
        for _, id in ipairs(opts.unlocked) do
            unlocked_[id] = true
        end
    end
    if opts.redeemed then
        for _, id in ipairs(opts.redeemed) do
            redeemed_[id] = true
        end
    end
end
