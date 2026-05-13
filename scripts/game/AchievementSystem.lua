-- ============================================================================
-- game/AchievementSystem.lua  -- 银河征服 成就系统
-- 轻量级成就模块：定义成就 → 触发检查 → Toast 通知
-- ============================================================================
local AchievementSystem = {}

-- ─── 成就定义 ─────────────────────────────────────────────────────────────────
-- 每条成就：{ id, name, desc, check(state) → bool }
-- state 由 AchievementSystem.Check(eventName, state) 传入
local ACHIEVEMENTS = {
    -- 殖民类
    {
        id    = "first_colony",
        name  = "星际拓荒者",
        desc  = "首次殖民一颗星球",
        event = "colonize",
        check = function(s) return (s.totalColonized or 0) >= 1 end,
    },
    {
        id    = "colony_5",
        name  = "领土扩张",
        desc  = "累计殖民 5 颗星球",
        event = "colonize",
        check = function(s) return (s.totalColonized or 0) >= 5 end,
    },
    -- 战斗类
    {
        id    = "first_kill",
        name  = "初战告捷",
        desc  = "首次击败海盗袭击",
        event = "pirate_kill",
        check = function(s) return (s.piratesKilled or 0) >= 1 end,
    },
    {
        id    = "pirate_hunter",
        name  = "海盗克星",
        desc  = "累计击败 3 次海盗袭击",
        event = "pirate_kill",
        check = function(s) return (s.piratesKilled or 0) >= 3 end,
    },
    -- 科技类
    {
        id    = "first_research",
        name  = "科研先驱",
        desc  = "完成首项科技研发",
        event = "research_complete",
        check = function(s) return (s.totalResearch or 0) >= 1 end,
    },
    -- 胜利类
    {
        id    = "galactic_conquest",
        name  = "银河征服者",
        desc  = "消灭所有海盗基地，完成征服",
        event = "victory",
        check = function(s) return s.victory == true end,
    },
    -- 速通类
    {
        id    = "speed_runner",
        name  = "神速指挥官",
        desc  = "在 10 分钟内取得胜利",
        event = "victory",
        check = function(s) return s.victory == true and (s.playTime or 99999) <= 600 end,
    },
}

-- ─── 内部状态 ─────────────────────────────────────────────────────────────────
local unlocked_  = {}   -- Set: { [id] = true }
local notifyFn_  = nil  -- function(msg, type) 通知回调

-- ─── 初始化 ──────────────────────────────────────────────────────────────────
---@param opts { notifyFn:function, unlocked:table|nil }
function AchievementSystem.Init(opts)
    notifyFn_ = opts.notifyFn or function() end
    unlocked_ = {}
    if opts.unlocked then
        for _, id in ipairs(opts.unlocked) do
            unlocked_[id] = true
        end
    end
end

-- ─── 触发检查 ─────────────────────────────────────────────────────────────────
--- 外部调用：某个事件发生时，传入 eventName 和游戏状态快照 state
---@param eventName string  事件名（colonize / pirate_kill / research_complete / victory）
---@param state     table   游戏状态快照
function AchievementSystem.Check(eventName, state)
    for _, ach in ipairs(ACHIEVEMENTS) do
        if ach.event == eventName and not unlocked_[ach.id] then
            local ok, err = pcall(ach.check, state)
            if ok and err then   -- err 在 pcall 成功时就是返回值
                unlocked_[ach.id] = true
                notifyFn_("🏆 成就解锁: " .. ach.name .. "\n" .. ach.desc, "success")
                print(string.format("[Achievement] 解锁: %s (%s)", ach.name, ach.id))
            end
        end
    end
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

return AchievementSystem
