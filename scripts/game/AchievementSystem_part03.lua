-- Auto-split from AchievementSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function AchievementSystem.Check(eventName, state)
    for _, ach in ipairs(ACHIEVEMENTS) do
        if ach.event == eventName and not unlocked_[ach.id] then
            local ok, result = pcall(ach.check, state)
            if ok and result then
                unlocked_[ach.id] = true
                print(string.format("[Achievement] 解锁: %s (%s)", ach.name, ach.id))
                -- 加入合并缓冲，重置倒计时
                pendingUnlocks_[#pendingUnlocks_ + 1] = { name = ach.name, desc = ach.desc }
                flushTimer_ = FLUSH_DELAY
                -- 触发云端同步回调
                local list = AchievementSystem.GetUnlocked()
                onUnlockFn_(ach.id, list)
            end
        end
    end
end
