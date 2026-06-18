-- Auto-split from AchievementSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function AchievementSystem.Update(dt)
    if flushTimer_ <= 0 then return end
    flushTimer_ = flushTimer_ - dt
    if flushTimer_ > 0 then return end
    flushTimer_ = 0

    local n = #pendingUnlocks_
    if n == 0 then return end

    -- 播放一次音效（无论多少条）
    if audioFn_ then audioFn_() end

    if n == 1 then
        -- 单条：保持原有样式
        local ach = pendingUnlocks_[1]
        notifyFn_("🏆 成就解锁: " .. ach.name .. "  " .. ach.desc, "success")
    else
        -- 多条合并：列出全部名称
        local names = {}
        for i = 1, n do names[i] = pendingUnlocks_[i].name end
        notifyFn_("🏆 解锁了 " .. n .. " 个成就: " .. table.concat(names, "、"), "success")
    end

    pendingUnlocks_ = {}
end

-- ─── 持久化辅助 ──────────────────────────────────────────────────────────────
--- 返回已解锁 id 列表（用于存档）
function AchievementSystem.GetUnlocked()
    local list = {}
    for id in pairs(unlocked_) do list[#list + 1] = id end
    return list
end

--- 直接覆盖已解锁列表（用于读档）
function AchievementSystem.SetUnlocked(list)
    unlocked_ = {}
    for _, id in ipairs(list or {}) do
        unlocked_[id] = true
    end
end

--- 返回成就总数（用于展示进度）
function AchievementSystem.GetTotal()
    return #ACHIEVEMENTS
end

-- ─── P2-3: 奖励兑换 API ──────────────────────────────────────────────────────

--- 兑换成就奖励（已解锁且未兑换且有奖励时才能兑换）
--- 返回 true, rewardTable 或 false, errMsg
function AchievementSystem.Redeem(id)
    if not unlocked_[id]       then return false, "未解锁" end
    if redeemed_[id]           then return false, "已兑换" end
    local reward = ACHIEVEMENT_REWARDS[id]
    if not reward              then return false, "无奖励" end
    redeemed_[id] = true
    print(string.format("[Achievement] 兑换奖励: %s → %s", id, reward.desc))
    return true, reward
end

--- 返回已兑换 id 列表（用于存档）
function AchievementSystem.GetRedeemed()
    local list = {}
    for id in pairs(redeemed_) do list[#list + 1] = id end
    return list
end

--- 直接覆盖已兑换列表（用于读档）
function AchievementSystem.SetRedeemed(list)
    redeemed_ = {}
    for _, id in ipairs(list or {}) do
        redeemed_[id] = true
    end
end

--- 返回可兑换数量（已解锁 + 有奖励 + 未兑换）
function AchievementSystem.GetRedeemableCount()
    local cnt = 0
    for id in pairs(unlocked_) do
        if not redeemed_[id] and ACHIEVEMENT_REWARDS[id] then
            cnt = cnt + 1
        end
    end
    return cnt
end

--- 返回所有已兑换奖励（供游戏开始时应用）
function AchievementSystem.GetActiveRewards()
    local result = {}
    for id in pairs(redeemed_) do
        local reward = ACHIEVEMENT_REWARDS[id]
        if reward then
            result[#result + 1] = { id = id, reward = reward }
        end
    end
    return result
end

--- 返回指定成就的奖励定义（供 UI 展示）
function AchievementSystem.GetReward(id)
    return ACHIEVEMENT_REWARDS[id]
end

--- 是否已兑换
function AchievementSystem.IsRedeemed(id)
    return redeemed_[id] == true
end

--- 返回全部成就列表（含解锁状态），供 UI 面板展示
--- 返回 { {id, name, desc, category, unlocked}, ... }
function AchievementSystem.GetAll()
    -- event → UI分类键 映射
    local EVENT_TO_CAT = {
        colonize           = "colonize",
        pirate_kill        = "combat",
        ship_built         = "fleet",
        research_complete  = "research",
        resource_milestone = "resource",
        victory            = "victory",
        -- P2-3: 隐藏成就事件
        battle_result      = "combat",
        endless_wave       = "endless",
        endless_card       = "endless",
        focus_kill         = "combat",
        explore_done       = "explore",
    }
    local list = {}
    for _, ach in ipairs(ACHIEVEMENTS) do
        local isUnlocked = unlocked_[ach.id] == true
        -- P2-3: 隐藏成就未解锁时遮蔽名称和描述
        local displayName = ach.name
        local displayDesc = ach.desc
        if ach.hidden and not isUnlocked then
            displayName = "???"
            displayDesc = ach.hint or "达成特殊条件后解锁"
        end
        list[#list + 1] = {
            id       = ach.id,
            name     = displayName,
            desc     = displayDesc,
            category = EVENT_TO_CAT[ach.event] or ach.event,
            unlocked = isUnlocked,
            hidden   = ach.hidden == true,
            reward   = ACHIEVEMENT_REWARDS[ach.id],          -- P2-3
            redeemed = redeemed_[ach.id] == true,            -- P2-3
        }
    end
    return list
end

--- 返回隐藏成就总数（已解锁/总计，供进度展示）
function AchievementSystem.GetHiddenProgress()
    local total, done = 0, 0
    for _, ach in ipairs(ACHIEVEMENTS) do
        if ach.hidden then
            total = total + 1
            if unlocked_[ach.id] then done = done + 1 end
        end
    end
    return done, total
end

return AchievementSystem
