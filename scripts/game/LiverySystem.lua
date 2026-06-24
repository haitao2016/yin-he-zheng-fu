-- ============================================================================
-- game/LiverySystem.lua  -- P2-3 V2.4: 舰队涂装与徽章系统
-- 纯视觉定制：色板(主色+辅色) + 军旗徽章(20种) + 解锁条件 + 存档
-- ============================================================================

local LiverySystem = {}

-- ============================================================================
-- 色板定义（12种主色 + 12种辅色）
-- ============================================================================
-- 主色: 舰身色调
LiverySystem.PRIMARY_COLORS = {
    { id = "imperial_blue",   name = "帝国蓝",   r = 40,  g = 80,  b = 180, unlock = "free" },
    { id = "crimson",         name = "深红",     r = 180, g = 30,  b = 30,  unlock = "free" },
    { id = "void_black",      name = "虚空黑",   r = 20,  g = 20,  b = 30,  unlock = "free" },
    { id = "emerald",         name = "翠绿",     r = 20,  g = 160, b = 80,  unlock = "achievement", condition = "colonize_5" },
    { id = "solar_gold",      name = "日耀金",   r = 220, g = 180, b = 40,  unlock = "achievement", condition = "win_hard" },
    { id = "nebula_purple",   name = "星云紫",   r = 120, g = 40,  b = 200, unlock = "achievement", condition = "research_all" },
    { id = "frost_white",     name = "霜白",     r = 200, g = 220, b = 240, unlock = "league", condition = "silver" },
    { id = "plasma_cyan",     name = "等离子青", r = 40,  g = 200, b = 220, unlock = "league", condition = "gold" },
    { id = "inferno_orange",  name = "地狱橙",   r = 240, g = 120, b = 20,  unlock = "crisis", condition = "survive_any" },
    { id = "phantom_grey",    name = "幽灵灰",   r = 80,  g = 90,  b = 100, unlock = "nemesis", condition = "defeat_1" },
    { id = "dark_matter",     name = "暗物质",   r = 30,  g = 10,  b = 50,  unlock = "crisis", condition = "survive_all" },
    { id = "champion_chrome", name = "冠军铬",   r = 200, g = 210, b = 220, unlock = "league", condition = "champion" },
}

-- 辅色: 引擎尾焰/装饰线
LiverySystem.ACCENT_COLORS = {
    { id = "flame_orange",    name = "烈焰橙",   r = 255, g = 140, b = 30,  unlock = "free" },
    { id = "electric_blue",   name = "电光蓝",   r = 60,  g = 140, b = 255, unlock = "free" },
    { id = "toxic_green",     name = "剧毒绿",   r = 80,  g = 255, b = 60,  unlock = "free" },
    { id = "plasma_pink",     name = "等离子粉", r = 255, g = 80,  b = 180, unlock = "achievement", condition = "kill_1000" },
    { id = "ghost_white",     name = "幽灵白",   r = 240, g = 240, b = 255, unlock = "achievement", condition = "wave_20" },
    { id = "void_purple",     name = "虚空紫",   r = 160, g = 60,  b = 255, unlock = "achievement", condition = "fleet_max" },
    { id = "sun_yellow",      name = "太阳黄",   r = 255, g = 230, b = 50,  unlock = "league", condition = "silver" },
    { id = "blood_red",       name = "血红",     r = 255, g = 20,  b = 40,  unlock = "league", condition = "gold" },
    { id = "ice_cyan",        name = "冰晶青",   r = 100, g = 240, b = 255, unlock = "crisis", condition = "survive_any" },
    { id = "warp_indigo",     name = "跃迁靛",   r = 80,  g = 40,  b = 200, unlock = "nemesis", condition = "defeat_3" },
    { id = "neutron_gold",    name = "中子金",   r = 255, g = 200, b = 80,  unlock = "crisis", condition = "survive_all" },
    { id = "dark_energy",     name = "暗能量",   r = 120, g = 0,   b = 180, unlock = "league", condition = "champion" },
}

-- ============================================================================
-- 军旗徽章定义（20种）
-- ============================================================================
LiverySystem.EMBLEMS = {
    -- 基础几何图形（初始解锁）
    { id = "star",       icon = "⭐", name = "星芒",     unlock = "free" },
    { id = "shield",     icon = "🛡️", name = "护盾",     unlock = "free" },
    { id = "sword",      icon = "⚔️", name = "交叉剑",   unlock = "free" },
    -- 成就专属
    { id = "wing",       icon = "🦅", name = "苍鹰之翼", unlock = "achievement", condition = "colonize_5" },
    { id = "crown",      icon = "👑", name = "征服者冠冕",unlock = "league", condition = "champion" },
    { id = "skull",      icon = "💀", name = "危机幸存者",unlock = "crisis", condition = "survive_any" },
    { id = "diamond",    icon = "💎", name = "钻石指挥官",unlock = "achievement", condition = "commander_lv10" },
    { id = "anchor",     icon = "⚓", name = "星港锚",   unlock = "achievement", condition = "build_stargate" },
    { id = "bolt",       icon = "⚡", name = "闪电突击", unlock = "achievement", condition = "win_fast" },
    { id = "atom",       icon = "⚛️", name = "原子核心", unlock = "achievement", condition = "research_all" },
    -- 联赛段位
    { id = "bronze_ring",icon = "🥉", name = "铜环",     unlock = "league", condition = "bronze" },
    { id = "silver_ring",icon = "🥈", name = "银环",     unlock = "league", condition = "silver" },
    { id = "gold_ring",  icon = "🥇", name = "金环",     unlock = "league", condition = "gold" },
    -- 宿敌战利品
    { id = "nemesis_x",  icon = "❌", name = "宿敌之印", unlock = "nemesis", condition = "defeat_1" },
    { id = "nemesis_xx", icon = "☠️", name = "终结者",   unlock = "nemesis", condition = "defeat_3" },
    { id = "nemesis_xxx",icon = "🔥", name = "灭族者",   unlock = "nemesis", condition = "defeat_5" },
    -- 巨构/特殊
    { id = "dyson",      icon = "☀️", name = "戴森之环", unlock = "mega", condition = "DYSON_SPHERE" },
    { id = "gate",       icon = "🌀", name = "星门印记", unlock = "mega", condition = "STARGATE" },
    { id = "fortress",   icon = "🏰", name = "量子堡垒", unlock = "mega", condition = "QUANTUM_FORTRESS" },
    { id = "galaxy",     icon = "🌌", name = "银河之主", unlock = "achievement", condition = "win_legendary" },
}

-- ============================================================================
-- 状态管理
-- ============================================================================
local state_ = {
    selectedPrimary = "imperial_blue",   -- 当前选择主色 id
    selectedAccent  = "flame_orange",    -- 当前选择辅色 id
    selectedEmblem  = "star",            -- 当前选择徽章 id
    unlockedPrimary = { imperial_blue = true, crimson = true, void_black = true },
    unlockedAccent  = { flame_orange = true, electric_blue = true, toxic_green = true },
    unlockedEmblems = { star = true, shield = true, sword = true },
}

-- ============================================================================
-- 解锁条件检查
-- ============================================================================
local function checkUnlockCondition(item, achievements, leagueRank, crisisSurvived, nemesisDefeated, megaCompleted)
    if item.unlock == "free" then return true end
    if item.unlock == "achievement" then
        return achievements and achievements[item.condition]
    end
    if item.unlock == "league" then
        local ranks = { bronze = 1, silver = 2, gold = 3, champion = 4 }
        local required = ranks[item.condition] or 99
        local current  = ranks[leagueRank] or 0
        return current >= required
    end
    if item.unlock == "crisis" then
        if item.condition == "survive_any" then
            return crisisSurvived and crisisSurvived > 0
        elseif item.condition == "survive_all" then
            return crisisSurvived and crisisSurvived >= 3
        end
    end
    if item.unlock == "nemesis" then
        local n = tonumber(item.condition:match("%d+")) or 1
        return nemesisDefeated and nemesisDefeated >= n
    end
    if item.unlock == "mega" then
        return megaCompleted and megaCompleted[item.condition]
    end
    return false
end

--- 刷新解锁状态（应在成就/联赛/危机变化时调用）
---@param ctx table {achievements, leagueRank, crisisSurvived, nemesisDefeated, megaCompleted}
function LiverySystem.RefreshUnlocks(ctx)
    local ach   = ctx.achievements or {}
    local league = ctx.leagueRank or "none"
    local crisis = ctx.crisisSurvived or 0
    local nemesis = ctx.nemesisDefeated or 0
    local mega   = ctx.megaCompleted or {}

    for _, c in ipairs(LiverySystem.PRIMARY_COLORS) do
        if checkUnlockCondition(c, ach, league, crisis, nemesis, mega) then
            state_.unlockedPrimary[c.id] = true
        end
    end
    for _, c in ipairs(LiverySystem.ACCENT_COLORS) do
        if checkUnlockCondition(c, ach, league, crisis, nemesis, mega) then
            state_.unlockedAccent[c.id] = true
        end
    end
    for _, e in ipairs(LiverySystem.EMBLEMS) do
        if checkUnlockCondition(e, ach, league, crisis, nemesis, mega) then
            state_.unlockedEmblems[e.id] = true
        end
    end
end

-- ============================================================================
-- 选择/获取
-- ============================================================================
function LiverySystem.SetPrimary(id)
    if state_.unlockedPrimary[id] then
        state_.selectedPrimary = id
        return true
    end
    return false
end

function LiverySystem.SetAccent(id)
    if state_.unlockedAccent[id] then
        state_.selectedAccent = id
        return true
    end
    return false
end

function LiverySystem.SetEmblem(id)
    if state_.unlockedEmblems[id] then
        state_.selectedEmblem = id
        return true
    end
    return false
end

function LiverySystem.GetAllPrimaries()
    return LiverySystem.PRIMARY_COLORS
end

function LiverySystem.GetAllAccents()
    return LiverySystem.ACCENT_COLORS
end

function LiverySystem.GetPrimary()
    for _, c in ipairs(LiverySystem.PRIMARY_COLORS) do
        if c.id == state_.selectedPrimary then return c end
    end
    return LiverySystem.PRIMARY_COLORS[1]
end

function LiverySystem.GetAccent()
    for _, c in ipairs(LiverySystem.ACCENT_COLORS) do
        if c.id == state_.selectedAccent then return c end
    end
    return LiverySystem.ACCENT_COLORS[1]
end

function LiverySystem.GetEmblem()
    for _, e in ipairs(LiverySystem.EMBLEMS) do
        if e.id == state_.selectedEmblem then return e end
    end
    return LiverySystem.EMBLEMS[1]
end

function LiverySystem.IsUnlocked(category, id)
    if category == "primary" then return state_.unlockedPrimary[id] or false end
    if category == "accent"  then return state_.unlockedAccent[id] or false end
    if category == "emblem"  then return state_.unlockedEmblems[id] or false end
    return false
end

--- 获取战斗用色彩（供 BattleScene 使用）
---@return table {primaryR, primaryG, primaryB, accentR, accentG, accentB, emblemIcon}
function LiverySystem.GetBattleColors()
    local p = LiverySystem.GetPrimary()
    local a = LiverySystem.GetAccent()
    local e = LiverySystem.GetEmblem()
    return {
        primaryR = p.r, primaryG = p.g, primaryB = p.b,
        accentR  = a.r, accentG  = a.g, accentB  = a.b,
        emblemIcon = e.icon,
    }
end

-- ============================================================================
-- 序列化/反序列化（写入 galaxy_career.json）
-- ============================================================================
function LiverySystem.Serialize()
    return {
        selectedPrimary = state_.selectedPrimary,
        selectedAccent  = state_.selectedAccent,
        selectedEmblem  = state_.selectedEmblem,
        unlockedPrimary = state_.unlockedPrimary,
        unlockedAccent  = state_.unlockedAccent,
        unlockedEmblems = state_.unlockedEmblems,
    }
end

function LiverySystem.Deserialize(data)
    if not data then return end
    state_.selectedPrimary = data.selectedPrimary or "imperial_blue"
    state_.selectedAccent  = data.selectedAccent or "flame_orange"
    state_.selectedEmblem  = data.selectedEmblem or "star"
    state_.unlockedPrimary = data.unlockedPrimary or { imperial_blue = true, crimson = true, void_black = true }
    state_.unlockedAccent  = data.unlockedAccent or { flame_orange = true, electric_blue = true, toxic_green = true }
    state_.unlockedEmblems = data.unlockedEmblems or { star = true, shield = true, sword = true }
end

function LiverySystem.Reset()
    state_.selectedPrimary = "imperial_blue"
    state_.selectedAccent  = "flame_orange"
    state_.selectedEmblem  = "star"
    state_.unlockedPrimary = { imperial_blue = true, crimson = true, void_black = true }
    state_.unlockedAccent  = { flame_orange = true, electric_blue = true, toxic_green = true }
    state_.unlockedEmblems = { star = true, shield = true, sword = true }
end

return LiverySystem
