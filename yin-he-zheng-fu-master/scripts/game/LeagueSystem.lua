---@diagnostic disable: param-type-mismatch
-- ============================================================================
-- game/LeagueSystem.lua  -- P1-3: 星际联赛模式
-- 每周固定种子星图 → 统一条件竞技 → 联赛计分 → 段位晋升 → 排行榜
-- ============================================================================
local LeagueSystem = {}

-- ─── 段位定义 ─────────────────────────────────────────────────────────────────
local RANKS = {
    { id = "bronze",   name = "青铜舰长",   icon = "🥉", minPts = 0,    color = {r=180,g=120,b=60}  },
    { id = "silver",   name = "白银指挥",   icon = "🥈", minPts = 200,  color = {r=180,g=190,b=210} },
    { id = "gold",     name = "黄金统帅",   icon = "🥇", minPts = 500,  color = {r=255,g=200,b=50}  },
    { id = "platinum", name = "白金元帅",   icon = "💎", minPts = 1000, color = {r=150,g=220,b=255} },
    { id = "diamond",  name = "钻石霸主",   icon = "👑", minPts = 2000, color = {r=200,g=130,b=255} },
}

-- ─── 周赛配置 ─────────────────────────────────────────────────────────────────
-- 每周固定难度修正（让联赛有辨识度）
local WEEK_MODIFIERS = {
    { label = "速攻赛季", desc = "海盗攻击频率×1.3", attackMult = 1.3, resMult = 1.0 },
    { label = "富饶赛季", desc = "资源产出×1.5",      attackMult = 1.0, resMult = 1.5 },
    { label = "标准赛季", desc = "均衡条件",           attackMult = 1.0, resMult = 1.0 },
    { label = "荒芜赛季", desc = "初始资源-30%",       attackMult = 1.0, resMult = 0.7 },
    { label = "狂潮赛季", desc = "威胁上限+2",         attackMult = 0.9, resMult = 1.0 },
}

-- ─── 状态 ─────────────────────────────────────────────────────────────────────
local state_ = {
    totalPoints   = 0,       -- 累计联赛积分（决定段位）
    weekKey       = "",      -- 当前周标识 "2026W22"
    weekSeed      = 0,       -- 本周种子
    weekModIdx    = 1,       -- 本周修正索引
    weekBestScore = 0,       -- 本周最高单局分
    weekGames     = 0,       -- 本周已打局数
    weekSubmitted = false,   -- 本周是否已提交排行榜
    history       = {},      -- 最近4周记录 [{weekKey, score, rank}]
}

-- ─── 工具函数 ─────────────────────────────────────────────────────────────────

--- 获取当前 ISO 周标识 "YYYYWww"
local function getCurrentWeekKey()
    local t = os.date("*t")
    -- ISO week: 简化计算（1月1日所在周为第1周）
    local jan1 = os.time({year=t.year, month=1, day=1, hour=12})
    local dayOfYear = math.floor((os.time(t) - jan1) / 86400) + 1
    local weekNum = math.ceil(dayOfYear / 7)
    return string.format("%04dW%02d", t.year, weekNum)
end

--- 从周标识生成确定性种子
local function weekKeyToSeed(wk)
    -- 简单哈希：将字符串转为数字
    local h = 5381
    for i = 1, #wk do
        h = ((h * 33) + string.byte(wk, i)) % 2147483647
    end
    return h
end

--- 根据累计积分获取当前段位
local function getRankByPoints(pts)
    local result = RANKS[1]
    for i = #RANKS, 1, -1 do
        if pts >= RANKS[i].minPts then
            result = RANKS[i]
            break
        end
    end
    return result
end

--- 获取下一段位信息（用于进度条）
local function getNextRank(pts)
    for i = 1, #RANKS do
        if pts < RANKS[i].minPts then
            return RANKS[i]
        end
    end
    return nil  -- 已最高段位
end

--- 计算本周修正索引（基于种子）
local function getWeekModIndex(seed)
    return (seed % #WEEK_MODIFIERS) + 1
end

-- ─── 公共 API ─────────────────────────────────────────────────────────────────

--- 初始化/重置（新赛季或首次进入）
function LeagueSystem.Init()
    local wk = getCurrentWeekKey()
    local seed = weekKeyToSeed(wk)
    state_.weekKey    = wk
    state_.weekSeed   = seed
    state_.weekModIdx = getWeekModIndex(seed)
    -- 不重置 totalPoints 和 history（持久化）
    state_.weekBestScore = 0
    state_.weekGames     = 0
    state_.weekSubmitted = false
    print(string.format("[League] 初始化: week=%s seed=%d mod=%s",
        wk, seed, WEEK_MODIFIERS[state_.weekModIdx].label))
end

--- 检查并刷新周赛（跨周时自动重置）
function LeagueSystem.CheckWeekRollover()
    local wk = getCurrentWeekKey()
    if wk ~= state_.weekKey then
        -- 归档上周记录
        if state_.weekBestScore > 0 then
            local rank = getRankByPoints(state_.totalPoints)
            table.insert(state_.history, 1, {
                weekKey = state_.weekKey,
                score   = state_.weekBestScore,
                rank    = rank.id,
            })
            -- 只保留最近4周
            while #state_.history > 4 do
                table.remove(state_.history)
            end
        end
        -- 刷新到新周
        local seed = weekKeyToSeed(wk)
        state_.weekKey       = wk
        state_.weekSeed      = seed
        state_.weekModIdx    = getWeekModIndex(seed)
        state_.weekBestScore = 0
        state_.weekGames     = 0
        state_.weekSubmitted = false
        print(string.format("[League] 周赛刷新: %s → mod=%s",
            wk, WEEK_MODIFIERS[state_.weekModIdx].label))
        return true  -- 通知调用方：发生了周切换
    end
    return false
end

--- 获取本周种子（GalaxyScene 用于 math.randomseed）
function LeagueSystem.GetWeekSeed()
    return state_.weekSeed
end

--- 获取本周修正配置
function LeagueSystem.GetWeekModifier()
    return WEEK_MODIFIERS[state_.weekModIdx]
end

--- 获取本周标识
function LeagueSystem.GetWeekKey()
    return state_.weekKey
end

--- 计算单局联赛得分
--- @param stats table {colonies, kills, techCount, surviveTime, wavesCleared, flagshipsAlive}
--- @return number score
function LeagueSystem.CalcScore(stats)
    local s = stats or {}
    local score = 0
    -- 殖民数 × 30
    score = score + (s.colonies or 0) * 30
    -- 击杀数 × 5
    score = score + (s.kills or 0) * 5
    -- 科技数 × 15
    score = score + (s.techCount or 0) * 15
    -- 存活时间（分钟）× 2
    score = score + math.floor((s.surviveTime or 0) / 60) * 2
    -- 波次清除 × 20
    score = score + (s.wavesCleared or 0) * 20
    -- 旗舰存活奖励 × 40
    score = score + (s.flagshipsAlive or 0) * 40
    -- 本周修正加分（速攻赛季击杀加倍等）
    local mod = WEEK_MODIFIERS[state_.weekModIdx]
    if mod.attackMult > 1.0 then
        -- 速攻赛季：击杀分 ×1.5
        score = score + math.floor((s.kills or 0) * 5 * 0.5)
    end
    return math.max(0, score)
end

--- 提交联赛成绩（每局结束时调用）
--- @param stats table 同 CalcScore
--- @return number score, boolean isNewBest
function LeagueSystem.SubmitGame(stats)
    local score = LeagueSystem.CalcScore(stats)
    state_.weekGames = state_.weekGames + 1
    local isNewBest = score > state_.weekBestScore
    if isNewBest then
        state_.weekBestScore = score
        -- 累计积分：每次刷新最高分时增加差值
        local diff = score - (state_.weekBestScore - score + score)  -- 简化
        state_.totalPoints = state_.totalPoints + math.floor(score * 0.1)
        state_.weekSubmitted = false  -- 需要重新提交排行榜
    end
    print(string.format("[League] 本局得分=%d best=%d total=%d games=%d",
        score, state_.weekBestScore, state_.totalPoints, state_.weekGames))
    return score, isNewBest
end

--- 获取当前段位信息
function LeagueSystem.GetRank()
    return getRankByPoints(state_.totalPoints)
end

--- 获取段位进度 {current, next, progress}
function LeagueSystem.GetRankProgress()
    local cur = getRankByPoints(state_.totalPoints)
    local nxt = getNextRank(state_.totalPoints)
    local progress = 1.0
    if nxt then
        local range = nxt.minPts - cur.minPts
        local delta = state_.totalPoints - cur.minPts
        progress = math.min(1.0, delta / math.max(1, range))
    end
    return {
        current  = cur,
        next     = nxt,
        progress = progress,
        points   = state_.totalPoints,
    }
end

--- 获取联赛状态摘要（用于 UI 展示）
function LeagueSystem.GetStatus()
    local rank = getRankByPoints(state_.totalPoints)
    local mod  = WEEK_MODIFIERS[state_.weekModIdx]
    return {
        weekKey       = state_.weekKey,
        weekLabel     = mod.label,
        weekDesc      = mod.desc,
        weekBestScore = state_.weekBestScore,
        weekGames     = state_.weekGames,
        totalPoints   = state_.totalPoints,
        rankId        = rank.id,
        rankName      = rank.name,
        rankIcon      = rank.icon,
        rankColor     = rank.color,
        history       = state_.history,
    }
end

--- 获取排行榜 cloudScore key（按周）
function LeagueSystem.GetLeaderboardKey()
    return "league_" .. state_.weekKey
end

--- 标记已提交排行榜
function LeagueSystem.MarkSubmitted()
    state_.weekSubmitted = true
end

function LeagueSystem.NeedsSubmit()
    return state_.weekBestScore > 0 and not state_.weekSubmitted
end

--- 获取本周最高分
function LeagueSystem.GetWeekBest()
    return state_.weekBestScore
end

-- ─── 序列化/反序列化 ──────────────────────────────────────────────────────────

function LeagueSystem.Serialize()
    return {
        totalPoints   = state_.totalPoints,
        weekKey       = state_.weekKey,
        weekBestScore = state_.weekBestScore,
        weekGames     = state_.weekGames,
        weekSubmitted = state_.weekSubmitted,
        history       = state_.history,
    }
end

function LeagueSystem.Deserialize(data)
    if not data then
        LeagueSystem.Init()
        return
    end
    state_.totalPoints   = data.totalPoints or 0
    state_.weekBestScore = data.weekBestScore or 0
    state_.weekGames     = data.weekGames or 0
    state_.weekSubmitted = data.weekSubmitted or false
    state_.history       = data.history or {}
    -- 恢复周标识并检查是否跨周
    state_.weekKey = data.weekKey or ""
    local wk = getCurrentWeekKey()
    local seed = weekKeyToSeed(wk)
    state_.weekSeed   = seed
    state_.weekModIdx = getWeekModIndex(seed)
    if wk ~= state_.weekKey then
        -- 跨周了，归档旧数据
        LeagueSystem.CheckWeekRollover()
    else
        state_.weekKey = wk
    end
    print(string.format("[League] 反序列化: pts=%d week=%s best=%d",
        state_.totalPoints, state_.weekKey, state_.weekBestScore))
end

return LeagueSystem
