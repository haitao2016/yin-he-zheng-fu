-- ============================================================================
-- game/AchievementSystem.lua  -- 银河征服 成就系统
-- 轻量级成就模块：定义成就 → 触发检查 → Toast 通知
-- ============================================================================
local AchievementSystem = {}

-- ─── 成就定义 ─────────────────────────────────────────────────────────────────
-- 每条成就：{ id, name, desc, event, check(state) → bool }
-- state 由 AchievementSystem.Check(eventName, state) 传入
local ACHIEVEMENTS = {
    -- ── 殖民类 ───────────────────────────────────────────────────────────────
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
    {
        id    = "colony_10",
        name  = "星域霸主",
        desc  = "累计殖民 10 颗星球",
        event = "colonize",
        check = function(s) return (s.totalColonized or 0) >= 10 end,
    },
    -- ── 战斗类 ───────────────────────────────────────────────────────────────
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
    {
        id    = "pirate_destroyer",
        name  = "海盗终结者",
        desc  = "累计击败 10 次海盗袭击",
        event = "pirate_kill",
        check = function(s) return (s.piratesKilled or 0) >= 10 end,
    },
    -- ── 舰队类 ───────────────────────────────────────────────────────────────
    {
        id    = "first_ship",
        name  = "造船初体验",
        desc  = "建造第一艘舰船",
        event = "ship_built",
        check = function(s) return (s.totalShipsBuilt or 0) >= 1 end,
    },
    {
        id    = "fleet_builder",
        name  = "舰队缔造者",
        desc  = "累计建造 20 艘舰船",
        event = "ship_built",
        check = function(s) return (s.totalShipsBuilt or 0) >= 20 end,
    },
    {
        id    = "carrier_deploy",
        name  = "巨舰出击",
        desc  = "建造第一艘母舰（CARRIER）",
        event = "ship_built",
        check = function(s) return s.lastBuiltType == "CARRIER" end,
    },
    -- ── 科技类 ───────────────────────────────────────────────────────────────
    {
        id    = "first_research",
        name  = "科研先驱",
        desc  = "完成首项科技研发",
        event = "research_complete",
        check = function(s) return (s.totalResearch or 0) >= 1 end,
    },
    {
        id    = "tech_enthusiast",
        name  = "科技狂热者",
        desc  = "累计研究 5 项科技",
        event = "research_complete",
        check = function(s) return (s.totalResearch or 0) >= 5 end,
    },
    {
        id    = "tech_master",
        name  = "科技大师",
        desc  = "累计研究 10 项科技",
        event = "research_complete",
        check = function(s) return (s.totalResearch or 0) >= 10 end,
    },
    -- ── 资源类 ───────────────────────────────────────────────────────────────
    {
        id    = "resource_hoarder",
        name  = "资源囤积者",
        desc  = "同时持有金属 5000",
        event = "resource_milestone",
        check = function(s) return (s.metal or 0) >= 5000 end,
    },
    -- ── 胜利类 ───────────────────────────────────────────────────────────────
    {
        id    = "galactic_conquest",
        name  = "银河征服者",
        desc  = "消灭所有海盗基地，完成征服",
        event = "victory",
        check = function(s) return s.victory == true end,
    },
    -- ── 速通类 ───────────────────────────────────────────────────────────────
    {
        id    = "speed_runner",
        name  = "神速指挥官",
        desc  = "在 10 分钟内取得胜利",
        event = "victory",
        check = function(s) return s.victory == true and (s.playTime or 99999) <= 600 end,
    },

    -- ══ P2-3: 隐藏成就（12个）═══════════════════════════════════════════════
    -- 隐藏成就在解锁前 desc 不可见，以 "???" 代替展示
    {
        id     = "hidden_overkill",
        name   = "过度击杀",
        desc   = "在一场战斗中对单个目标造成超过其最大血量 3 倍的伤害",
        hint   = "对同一目标造成难以置信的过量伤害",
        event  = "battle_result",
        hidden = true,
        check  = function(s) return (s.overkillMax or 0) >= 3.0 end,
    },
    {
        id     = "hidden_no_damage",
        name   = "铁壁无损",
        desc   = "赢得一场战斗且全程未损失任何舰船",
        hint   = "以完美状态赢得战斗",
        event  = "battle_result",
        hidden = true,
        check  = function(s) return s.victory == true and (s.shipsLost or 0) == 0 end,
    },
    {
        id     = "hidden_wave10",
        name   = "万浪不沉",
        desc   = "在无尽模式中坚持到第 10 波",
        hint   = "在无尽的战火中证明自己",
        event  = "endless_wave",
        hidden = true,
        check  = function(s) return (s.endlessWave or 0) >= 10 end,
    },
    {
        id     = "hidden_card5",
        name   = "卡组大师",
        desc   = "在无尽模式中累计选取 5 张强化卡",
        hint   = "积少成多，逐渐壮大",
        event  = "endless_card",
        hidden = true,
        check  = function(s) return (s.totalCardsChosen or 0) >= 5 end,
    },
    {
        id     = "hidden_epic_card",
        name   = "传说加持",
        desc   = "在无尽模式中选取一张史诗（Epic）强化卡",
        hint   = "获得最稀有的力量",
        event  = "endless_card",
        hidden = true,
        check  = function(s) return s.lastCardRarity == "epic" end,
    },
    {
        id     = "hidden_focus_kill",
        name   = "精准猎杀",
        desc   = "使用集火指令击毁 5 艘敌方舰船",
        hint   = "指挥若定，一击必杀",
        event  = "focus_kill",
        hidden = true,
        check  = function(s) return (s.focusKills or 0) >= 5 end,
    },
    {
        id     = "hidden_boss_focus",
        name   = "王者之矛",
        desc   = "使用集火指令击毁一个 BOSS 级目标",
        hint   = "集中全部火力，对抗最强敌人",
        event  = "focus_kill",
        hidden = true,
        check  = function(s) return s.focusBossKill == true end,
    },
    {
        id     = "hidden_explore20",
        name   = "星际探险家",
        desc   = "累计完成 20 次探索任务",
        hint   = "不断探索未知宇宙",
        event  = "explore_done",
        hidden = true,
        check  = function(s) return (s.totalExplored or 0) >= 20 end,
    },
    {
        id     = "hidden_explore_all",
        name   = "星图测绘师",
        desc   = "在一局中触发全部 5 种探索事件类型",
        hint   = "见识宇宙的方方面面",
        event  = "explore_done",
        hidden = true,
        check  = function(s) return (s.exploreTypesFound or 0) >= 5 end,
    },
    {
        id     = "hidden_no_loss_campaign",
        name   = "完美征服",
        desc   = "从头到尾赢得战役，且从未在任何战斗中损失舰船",
        hint   = "极致的战术完美主义",
        event  = "victory",
        hidden = true,
        check  = function(s) return s.victory == true and (s.totalShipsLostCampaign or 0) == 0 end,
    },
    {
        id     = "hidden_dda_hard",
        name   = "难度挑战者",
        desc   = "在动态难度提升至最高档时赢得一场战斗",
        hint   = "面对最强的自适应敌人",
        event  = "battle_result",
        hidden = true,
        check  = function(s) return s.victory == true and (s.ddaLevel or 0) >= 3 end,
    },
    {
        id     = "hidden_full_tech",
        name   = "科技全树",
        desc   = "同时解锁科技树双路线的 Tier4 顶级科技",
        hint   = "掌握最前沿的星际科技",
        event  = "research_complete",
        hidden = true,
        check  = function(s)
            return (s.unlockedTechs and s.unlockedTechs["NOVA_CANNON"] and s.unlockedTechs["FORTRESS_PROTOCOL"]) == true
        end,
    },
}

-- ─── P2-3: 成就奖励定义 ────────────────────────────────────────────────────────
-- type: "resource" | "reserve_ship" | "skill_point" | "skill_level"
-- value: 各类型的具体奖励值
local ACHIEVEMENT_REWARDS = {
    -- 殖民类
    first_colony      = { desc = "开局 +100 金属",               type = "resource",    value = { metal = 100 } },
    colony_5          = { desc = "开局 +200 金属",               type = "resource",    value = { metal = 200 } },
    colony_10         = { desc = "开局 +300 金属 +150 能源",     type = "resource",    value = { metal = 300, esource = 150 } },
    -- 战斗类
    first_kill        = { desc = "首场战斗 +1 技能点",           type = "skill_point", value = 1 },
    pirate_hunter     = { desc = "首场战斗 +1 技能点",           type = "skill_point", value = 1 },
    pirate_destroyer  = { desc = "开局 +200 金属 +100 核燃料",   type = "resource",    value = { metal = 200, nuclear = 100 } },
    -- 舰队类
    first_ship        = { desc = "开局 +100 能源",               type = "resource",    value = { esource = 100 } },
    fleet_builder     = { desc = "储备增加 1 艘工程舰",          type = "reserve_ship",value = { shipType = "ENGINEER", count = 1 } },
    carrier_deploy    = { desc = "开局 +100 核燃料",             type = "resource",    value = { nuclear = 100 } },
    -- 科技类
    first_research    = { desc = "开局 +80 核燃料",              type = "resource",    value = { nuclear = 80 } },
    tech_enthusiast   = { desc = "开局 +150 核燃料",             type = "resource",    value = { nuclear = 150 } },
    tech_master       = { desc = "开局 +200 金属 +200 能源",     type = "resource",    value = { metal = 200, esource = 200 } },
    -- 资源类
    resource_hoarder  = { desc = "开局 +300 金属 +200 能源",     type = "resource",    value = { metal = 300, esource = 200 } },
    -- 胜利类
    galactic_conquest = { desc = "储备增加 1 艘探索舰",          type = "reserve_ship",value = { shipType = "EXPLORER", count = 1 } },
    speed_runner      = { desc = "首场战斗 +2 技能点",           type = "skill_point", value = 2 },
    -- 隐藏成就
    hidden_overkill       = { desc = "开局 +500 金属",           type = "resource",    value = { metal = 500 } },
    hidden_no_damage      = { desc = "技能「集火」初始 Lv2",     type = "skill_level", value = { skill = 1, level = 2 } },
    hidden_wave10         = { desc = "开局 +400 能源",           type = "resource",    value = { esource = 400 } },
    hidden_card5          = { desc = "首场战斗 +2 技能点",       type = "skill_point", value = 2 },
    hidden_epic_card      = { desc = "开局 +300 核燃料",         type = "resource",    value = { nuclear = 300 } },
    hidden_focus_kill     = { desc = "技能「EMP冲击」初始 Lv2",  type = "skill_level", value = { skill = 3, level = 2 } },
    hidden_boss_focus     = { desc = "技能「相位加速」初始 Lv2", type = "skill_level", value = { skill = 5, level = 2 } },
    hidden_explore20      = { desc = "开局 +100 金属/能源/核燃料", type = "resource",  value = { metal = 100, esource = 100, nuclear = 100 } },
    hidden_explore_all    = { desc = "开局 +400 金属",           type = "resource",    value = { metal = 400 } },
    hidden_no_loss_campaign = { desc = "储备增加 1 艘旗舰",      type = "reserve_ship",value = { shipType = "DESTROYER", count = 1 } },
    hidden_dda_hard       = { desc = "开局 +200 金属 +100 核燃料", type = "resource",  value = { metal = 200, nuclear = 100 } },
    hidden_full_tech      = { desc = "开局 +500 核燃料",         type = "resource",    value = { nuclear = 500 } },
}

-- ─── 内部状态 ─────────────────────────────────────────────────────────────────
local unlocked_      = {}   -- Set: { [id] = true }
local redeemed_      = {}   -- Set: { [id] = true }  P2-3: 已兑换成就奖励
local notifyFn_      = nil  -- function(msg, type) 通知回调
local onUnlockFn_    = nil  -- function(id, list) 解锁回调（用于云端同步）
local audioFn_       = nil  -- function() 成就解锁音效回调

-- 合并通知缓冲
local FLUSH_DELAY    = 0.6  -- 秒：等待此时间内的连续解锁后一次性推送
local pendingUnlocks_ = {}  -- { {name, desc}, ... } 待合并队列
local flushTimer_    = 0    -- 倒计时；>0 表示缓冲中

-- ─── 初始化 ──────────────────────────────────────────────────────────────────
---@param opts { notifyFn:function, onUnlock:function|nil, onAudio:function|nil, unlocked:table|nil, redeemed:table|nil }
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

-- ─── 触发检查 ─────────────────────────────────────────────────────────────────
--- 外部调用：某个事件发生时，传入 eventName 和游戏状态快照 state
---@param eventName string  事件名（colonize/pirate_kill/ship_built/research_complete/resource_milestone/victory）
---@param state     table   游戏状态快照
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

--- 每帧更新：倒计时结束时将缓冲的成就合并为一条通知推送
---@param dt number
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
