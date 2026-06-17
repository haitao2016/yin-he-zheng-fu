-- ============================================================================
-- game/QuestBoard.lua  -- P2-1 V2.4: 程序化任务板
-- 每 120s 生成 1 个新任务，最多同时 3 个活跃任务
-- 类型: 歼灭(40%) / 经济(30%) / 外交(20%) / 探索(10%)
-- ============================================================================
local QuestBoard = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 常量
-- ═══════════════════════════════════════════════════════════════════════════════
local MAX_ACTIVE    = 3       -- 同时活跃任务上限
local REFRESH_CD    = 120     -- 新任务生成间隔（秒）
local TASK_TIMEOUT  = 300     -- 单任务限时（秒）
local ELITE_CHANCE  = 0.20    -- 精英任务概率

-- 类型权重
local TYPE_WEIGHTS = {
    { type = "combat",      weight = 40 },
    { type = "economy",     weight = 30 },
    { type = "diplomacy",   weight = 20 },
    { type = "exploration", weight = 10 },
}
local TOTAL_WEIGHT = 100

-- ═══════════════════════════════════════════════════════════════════════════════
-- 任务模板库
-- ═══════════════════════════════════════════════════════════════════════════════
local TEMPLATES = {
    combat = {
        { desc = "在下次战斗中击败所有敌舰",        cond = "win_battle",         target = 1 },
        { desc = "累计击杀 %d 艘敌舰",              cond = "total_kills",        target = {8, 12, 16} },
        { desc = "本波战斗中不损失舰船",            cond = "flawless_battle",    target = 1 },
        { desc = "使用指挥官技能并获胜",            cond = "skill_win",          target = 1 },
        { desc = "在一场战斗中击杀 %d 艘敌舰",      cond = "single_battle_kills", target = {5, 8, 10} },
    },
    economy = {
        { desc = "积累 %d 金属",                    cond = "have_metal",         target = {500, 800, 1200} },
        { desc = "积累 %d 能源",                    cond = "have_energy",        target = {400, 600, 1000} },
        { desc = "在黑市完成一次交易",              cond = "market_trade",       target = 1 },
        { desc = "收集 %d 残骸零件",                cond = "have_salvage",       target = {10, 15, 20} },
        { desc = "赚取 %d 星币",                    cond = "earn_credits",       target = {300, 500, 800} },
    },
    diplomacy = {
        { desc = "与任一势力好感度达到 %d",          cond = "faction_favor",      target = {30, 50, 70} },
        { desc = "签订一次贸易协定",                cond = "sign_trade",         target = 1 },
        { desc = "签订一次军事同盟",                cond = "sign_military",      target = 1 },
        { desc = "完成一次调停斡旋",                cond = "mediate",            target = 1 },
    },
    exploration = {
        { desc = "殖民一颗新星球",                  cond = "colonize",           target = 1 },
        { desc = "殖民 %d 颗星球",                  cond = "total_colonies",     target = {3, 5, 7} },
        { desc = "在异象星球作战并获胜",            cond = "anomaly_battle_win", target = 1 },
        { desc = "探索一颗未知星球",                cond = "explore_planet",     target = 1 },
    },
}

-- 奖励基础值
local BASE_REWARDS = {
    combat      = { metal = 200, energy = 150, salvage = 2 },
    economy     = { metal = 150, energy = 200, salvage = 1 },
    diplomacy   = { metal = 250, energy = 100, salvage = 2 },
    exploration = { metal = 180, energy = 180, salvage = 3 },
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════════════════════════════════════════════
local quests_   = {}       -- 活跃任务列表 [{id,type,desc,cond,target,progress,elite,timer,reward}]
local nextId_   = 1        -- 任务ID计数器
local spawnTimer_ = 60     -- 首个任务60s后出现
local stats_    = {        -- 累积事件计数器（用于条件检测）
    totalKills     = 0,
    battleKills    = 0,    -- 当前/上一场战斗击杀数
    battlesWon     = 0,
    flawless       = false,
    skillWin       = false,
    marketTrades   = 0,
    creditsEarned  = 0,
    tradeSigned    = 0,
    militarySigned = 0,
    mediations     = 0,
    colonizations  = 0,
    anomalyWins    = 0,
    explored       = 0,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 工具函数
-- ═══════════════════════════════════════════════════════════════════════════════
local function pickWeighted()
    local r = math.random(1, TOTAL_WEIGHT)
    local acc = 0
    for _, entry in ipairs(TYPE_WEIGHTS) do
        acc = acc + entry.weight
        if r <= acc then return entry.type end
    end
    return "combat"
end

local function pickTarget(tpl)
    if type(tpl.target) == "table" then
        return tpl.target[math.random(1, #tpl.target)]
    end
    return tpl.target
end

local function formatDesc(tpl, target)
    if tpl.desc:find("%%d") then
        return string.format(tpl.desc, target)
    end
    return tpl.desc
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 任务生成
-- ═══════════════════════════════════════════════════════════════════════════════
local function generateQuest()
    if #quests_ >= MAX_ACTIVE then return nil end

    local qtype = pickWeighted()
    local templates = TEMPLATES[qtype]
    local tpl = templates[math.random(1, #templates)]
    local target = pickTarget(tpl)
    local elite = math.random() < ELITE_CHANCE

    local reward = {}
    local base = BASE_REWARDS[qtype]
    local mult = elite and 3 or 1
    reward.metal   = math.floor((base.metal   + math.random(-50, 50)) * mult)
    reward.energy  = math.floor((base.energy  + math.random(-50, 50)) * mult)
    reward.salvage = base.salvage * mult

    local quest = {
        id       = nextId_,
        type     = qtype,
        desc     = formatDesc(tpl, target),
        cond     = tpl.cond,
        target   = target,
        progress = 0,
        elite    = elite,
        timer    = TASK_TIMEOUT,
        reward   = reward,
    }
    nextId_ = nextId_ + 1
    quests_[#quests_ + 1] = quest
    return quest
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 条件检测
-- ═══════════════════════════════════════════════════════════════════════════════
---@param quest table
---@param rm table  ResourceManager
---@param diplo table  DiplomacySystem (optional)
---@param fm table|nil  FleetManager（残骸零件查询）
---@return boolean
local function checkCondition(quest, rm, diplo, fm)
    local c = quest.cond
    local t = quest.target

    if c == "win_battle" then
        return quest.progress >= t
    elseif c == "total_kills" then
        return quest.progress >= t
    elseif c == "flawless_battle" then
        return quest.progress >= t
    elseif c == "skill_win" then
        return quest.progress >= t
    elseif c == "single_battle_kills" then
        return quest.progress >= t
    elseif c == "have_metal" then
        return rm and (rm.resources.metal or 0) >= t
    elseif c == "have_energy" then
        return rm and (rm.resources.esource or 0) >= t
    elseif c == "market_trade" then
        return quest.progress >= t
    elseif c == "have_salvage" then
        return fm ~= nil and (fm.salvageParts or 0) >= t
    elseif c == "earn_credits" then
        return quest.progress >= t
    elseif c == "faction_favor" then
        if not diplo then return false end
        -- 检查所有势力最高好感
        local maxFavor = diplo:getMaxFavor()
        return maxFavor >= t
    elseif c == "sign_trade" then
        return quest.progress >= t
    elseif c == "sign_military" then
        return quest.progress >= t
    elseif c == "mediate" then
        return quest.progress >= t
    elseif c == "colonize" then
        return quest.progress >= t
    elseif c == "total_colonies" then
        local GalaxyScene = require("game.GalaxyScene")
        local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
        return #planets >= t
    elseif c == "anomaly_battle_win" then
        return quest.progress >= t
    elseif c == "explore_planet" then
        return quest.progress >= t
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 公开 API
-- ═══════════════════════════════════════════════════════════════════════════════

--- 每帧更新（传入 dt 和资源管理器引用）
---@param dt number
---@param rm table ResourceManager
---@param diplo table|nil DiplomacySystem
---@param fm table|nil FleetManager（残骸零件查询）
---@return table|nil completedQuest  本帧完成的任务（仅第一个）
function QuestBoard.Update(dt, rm, diplo, fm)
    -- 生成计时
    spawnTimer_ = spawnTimer_ - dt
    if spawnTimer_ <= 0 then
        spawnTimer_ = REFRESH_CD
        generateQuest()
    end

    -- 检测完成 & 超时
    local completed = nil
    local i = 1
    while i <= #quests_ do
        local q = quests_[i]
        q.timer = q.timer - dt
        if q.timer <= 0 then
            -- 超时移除
            table.remove(quests_, i)
        elseif checkCondition(q, rm, diplo, fm) then
            -- 完成
            completed = q
            table.remove(quests_, i)
        else
            i = i + 1
        end
    end
    return completed
end

--- 事件通知：战斗胜利
---@param kills number 本场击杀数
---@param flawless boolean 是否无损
---@param usedSkill boolean 是否使用了指挥官技能
function QuestBoard.OnBattleWin(kills, flawless, usedSkill)
    stats_.battlesWon = stats_.battlesWon + 1
    stats_.totalKills = stats_.totalKills + kills
    stats_.battleKills = kills
    stats_.flawless = flawless
    stats_.skillWin = usedSkill

    for _, q in ipairs(quests_) do
        if q.cond == "win_battle" then
            q.progress = q.progress + 1
        elseif q.cond == "total_kills" then
            q.progress = q.progress + kills
        elseif q.cond == "single_battle_kills" then
            q.progress = math.max(q.progress, kills)
        elseif q.cond == "flawless_battle" and flawless then
            q.progress = q.progress + 1
        elseif q.cond == "skill_win" and usedSkill then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：黑市交易完成
function QuestBoard.OnMarketTrade()
    stats_.marketTrades = stats_.marketTrades + 1
    for _, q in ipairs(quests_) do
        if q.cond == "market_trade" then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：赚取星币
---@param amount number
function QuestBoard.OnCreditsEarned(amount)
    stats_.creditsEarned = stats_.creditsEarned + amount
    for _, q in ipairs(quests_) do
        if q.cond == "earn_credits" then
            q.progress = q.progress + amount
        end
    end
end

--- 事件通知：外交 — 贸易协定
function QuestBoard.OnTradeAgreement()
    stats_.tradeSigned = stats_.tradeSigned + 1
    for _, q in ipairs(quests_) do
        if q.cond == "sign_trade" then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：外交 — 军事同盟
function QuestBoard.OnMilitaryAlliance()
    stats_.militarySigned = stats_.militarySigned + 1
    for _, q in ipairs(quests_) do
        if q.cond == "sign_military" then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：外交 — 调停
function QuestBoard.OnMediation()
    stats_.mediations = stats_.mediations + 1
    for _, q in ipairs(quests_) do
        if q.cond == "mediate" then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：殖民
function QuestBoard.OnColonize()
    stats_.colonizations = stats_.colonizations + 1
    for _, q in ipairs(quests_) do
        if q.cond == "colonize" then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：异象星球战斗胜利
function QuestBoard.OnAnomalyBattleWin()
    stats_.anomalyWins = stats_.anomalyWins + 1
    for _, q in ipairs(quests_) do
        if q.cond == "anomaly_battle_win" then
            q.progress = q.progress + 1
        end
    end
end

--- 事件通知：探索星球
function QuestBoard.OnExplorePlanet()
    stats_.explored = stats_.explored + 1
    for _, q in ipairs(quests_) do
        if q.cond == "explore_planet" then
            q.progress = q.progress + 1
        end
    end
end

--- 获取当前活跃任务列表
---@return table[]
function QuestBoard.GetQuests()
    return quests_
end

--- 获取生成倒计时
---@return number
function QuestBoard.GetSpawnTimer()
    return spawnTimer_
end

--- 序列化
function QuestBoard.Serialize()
    return {
        quests     = quests_,
        nextId     = nextId_,
        spawnTimer = spawnTimer_,
        stats      = stats_,
    }
end

--- 反序列化
function QuestBoard.Deserialize(data)
    if not data then return end
    quests_     = data.quests or {}
    nextId_     = data.nextId or 1
    spawnTimer_ = data.spawnTimer or REFRESH_CD
    stats_      = data.stats or stats_
end

--- 获取已完成任务总数（用于成就统计）
---@return number
function QuestBoard.GetCompletedCount()
    return nextId_ - 1 - #quests_   -- 已生成减去仍活跃 = 已完成+已超时
end

--- 完全重置（新游戏）
function QuestBoard.Reset()
    quests_ = {}
    nextId_ = 1
    spawnTimer_ = 60
    stats_ = {
        totalKills = 0, battleKills = 0, battlesWon = 0,
        flawless = false, skillWin = false,
        marketTrades = 0, creditsEarned = 0,
        tradeSigned = 0, militarySigned = 0, mediations = 0,
        colonizations = 0, anomalyWins = 0, explored = 0,
    }
end

return QuestBoard
