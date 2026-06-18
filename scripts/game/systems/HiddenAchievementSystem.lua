--[[
HiddenAchievementSystem.lua - 隐藏成就与解锁链
V2.7 P3-2
隐藏成就未解锁前显示 ???，通过解锁链循序渐进暴露
]]

local HiddenAchievementSystem = {}

HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS = {
    {
        id = "NO_DAMAGE_MASTER",
        name = "无伤大师",
        desc = "连续5波无伤过关",
        icon = "🛡️",
        category = "combat",
        condition = function(ps)
            return (ps and ps.noDamageStreak or 0) >= 5
        end,
        reward = { purpleCrystal = 50, rainbowCrystal = 5 },
    },
    {
        id = "COMBO_KING",
        name = "连击之王",
        desc = "单场战斗达成30连击",
        icon = "🔥",
        category = "combat",
        condition = function(ps)
            return (ps and ps.maxCombo or 0) >= 30
        end,
        reward = { blueCrystal = 100 },
        chainNext = "PERFECT_CLEAR",
    },
    {
        id = "SPEED_RUNNER",
        name = "速通达人",
        desc = "1小时内完成第一章",
        icon = "⚡",
        category = "combat",
        condition = function(ps)
            local t = ps and ps.chapter1Time or math.huge
            return t > 0 and t <= 3600
        end,
        reward = { purpleCrystal = 30, rainbowCrystal = 3 },
        chainPrev = "COMBO_KING",
    },
    {
        id = "ECONOMY_MOGUL",
        name = "经济大亨",
        desc = "单局累计获得百万资源",
        icon = "💰",
        category = "economy",
        condition = function(ps)
            return (ps and ps.singleRunResources or 0) >= 1000000
        end,
        reward = { purpleCrystal = 100, rainbowCrystal = 10 },
    },
    {
        id = "PEACE_MAKER",
        name = "和平使者",
        desc = "不建造任何战斗舰完成一个章节",
        icon = "🕊️",
        category = "strategy",
        condition = function(ps)
            return ps and ps.noCombatShipChapterComplete or false
        end,
        reward = { rainbowCrystal = 20 },
    },
    {
        id = "LUCKY_DEVIATOR",
        name = "幸运偏差",
        desc = "连续3次随机事件获得最优选项",
        icon = "🍀",
        category = "exploration",
        condition = function(ps)
            return (ps and ps.luckyStreak or 0) >= 3
        end,
        reward = { rainbowCrystal = 15 },
    },
    {
        id = "COLONIZATION_EXPERT",
        name = "殖民专家",
        desc = "累计殖民10颗行星",
        icon = "🌍",
        category = "exploration",
        condition = function(ps)
            return (ps and ps.planetsColonized or 0) >= 10
        end,
        reward = { purpleCrystal = 80 },
    },
    {
        id = "SHIP_COLLECTOR",
        name = "舰船收藏家",
        desc = "拥有所有类型舰船",
        icon = "🛥️",
        category = "fleet",
        condition = function(ps)
            return ps and ps.allShipTypesCollected or false
        end,
        reward = { purpleCrystal = 50, rainbowCrystal = 5 },
    },
    {
        id = "PERFECT_CLEAR",
        name = "完美通关",
        desc = "波次30无伤无舰损",
        icon = "✨",
        category = "combat",
        condition = function(ps)
            return ps and ps.perfectWave30 or false
        end,
        reward = { rainbowCrystal = 10 },
        chainPrev = "COMBO_KING",
    },
    {
        id = "UNDERDOG",
        name = "逆袭",
        desc = "舰队规模低于5艘击败Boss",
        icon = "💪",
        category = "combat",
        condition = function(ps)
            return ps and ps.bossDefeatedWithSmallFleet or false
        end,
        reward = { purpleCrystal = 50 },
    },
    {
        id = "DEEP_SPACE",
        name = "深空探索者",
        desc = "发现3个隐藏星系",
        icon = "🔭",
        category = "exploration",
        condition = function(ps)
            return (ps and ps.hiddenGalaxiesFound or 0) >= 3
        end,
        reward = { rainbowCrystal = 15 },
        chainPrev = "COLONIZATION_EXPERT",
    },
    {
        id = "MASTER_ENGINEER",
        name = "工程大师",
        desc = "将一艘舰船强化到满级",
        icon = "⚙️",
        category = "fleet",
        condition = function(ps)
            return ps and ps.maxEnhancementReached or false
        end,
        reward = { blueCrystal = 100 },
    },
    {
        id = "DIPLOMAT",
        name = "外交家",
        desc = "与10个派系达成友好关系",
        icon = "🤝",
        category = "social",
        condition = function(ps)
            return (ps and ps.friendlyFactions or 0) >= 10
        end,
        reward = { purpleCrystal = 60 },
    },
    {
        id = "MERCHANT_LORD",
        name = "贸易之王",
        desc = "建立20条贸易路线",
        icon = "📦",
        category = "economy",
        condition = function(ps)
            return (ps and ps.tradeRoutesEstablished or 0) >= 20
        end,
        reward = { purpleCrystal = 80 },
    },
    {
        id = "GALACTIC_HERO",
        name = "银河英雄",
        desc = "同时持有5个传奇成就",
        icon = "🏆",
        category = "legendary",
        condition = function(ps)
            return (ps and ps.legendaryCount or 0) >= 5
        end,
        reward = { rainbowCrystal = 50 },
        chainPrev = "PERFECT_CLEAR",
    },
}

HiddenAchievementSystem.CATEGORIES = {
    combat = { name = "战斗", icon = "⚔️" },
    economy = { name = "经济", icon = "💰" },
    exploration = { name = "探索", icon = "🌌" },
    fleet = { name = "舰队", icon = "🚀" },
    strategy = { name = "战略", icon = "🎯" },
    social = { name = "社交", icon = "🤝" },
    legendary = { name = "传奇", icon = "🏆" },
}

local function getUnlockedSet(playerState)
    if not playerState then return {} end
    playerState.hiddenAchievements = playerState.hiddenAchievements or {}
    playerState.hiddenAchievements.unlocked = playerState.hiddenAchievements.unlocked or {}
    return playerState.hiddenAchievements.unlocked
end

function HiddenAchievementSystem.getHiddenAchievements()
    local list = {}
    for _, ach in ipairs(HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS) do
        table.insert(list, {
            id = ach.id,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
            category = ach.category,
            hidden = true,
            chainPrev = ach.chainPrev,
            chainNext = ach.chainNext,
        })
    end
    return list
end

function HiddenAchievementSystem.isUnlocked(achievementId, playerState)
    local unlocked = getUnlockedSet(playerState)
    return not not unlocked[achievementId]
end

function HiddenAchievementSystem.canShowPreview(achievementId, playerState)
    local unlocked = getUnlockedSet(playerState)
    if unlocked[achievementId] then return true end
    for _, ach in ipairs(HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS) do
        if ach.id == achievementId and ach.chainPrev then
            if unlocked[ach.chainPrev] then return true end
        end
    end
    return false
end

function HiddenAchievementSystem.checkUnlockConditions(playerState, notifyFn)
    local unlocked = getUnlockedSet(playerState)
    local newly = {}
    for _, ach in ipairs(HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS) do
        if not unlocked[ach.id] and ach.condition and ach.condition(playerState) then
            unlocked[ach.id] = true
            table.insert(newly, ach)
        end
    end
    if notifyFn then
        for _, ach in ipairs(newly) do
            notifyFn("🌟 隐藏成就解锁: " .. ach.name .. "！", "hidden_achievement")
        end
    end
    return newly
end

function HiddenAchievementSystem.getAchievementDisplay(achievementId, playerState)
    local unlocked = getUnlockedSet(playerState)
    local target = nil
    for _, ach in ipairs(HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS) do
        if ach.id == achievementId then target = ach break end
    end
    if not target then return nil end
    if unlocked[achievementId] then
        return {
            id = target.id,
            name = target.name,
            desc = target.desc,
            icon = target.icon,
            category = target.category,
            hidden = false,
            unlocked = true,
        }
    end
    if HiddenAchievementSystem.canShowPreview(achievementId, playerState) then
        return {
            id = target.id,
            name = "???",
            desc = "已满足前置条件，继续探索解锁此成就",
            icon = target.icon,
            category = target.category,
            hidden = true,
            unlocked = false,
            hint = true,
        }
    end
    return {
        id = target.id,
        name = "???",
        desc = "未知成就：继续游戏以解锁",
        icon = "❓",
        category = target.category,
        hidden = true,
        unlocked = false,
        hint = false,
    }
end

function HiddenAchievementSystem.getChainProgress(chainId, playerState)
    chainId = chainId or "combat"
    local unlocked = getUnlockedSet(playerState)
    local chain = {}
    for _, ach in ipairs(HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS) do
        if ach.category == chainId or ach.chainPrev or ach.chainNext then
            table.insert(chain, ach)
        end
    end
    local total = #chain
    local done = 0
    local nextAch = nil
    for _, ach in ipairs(chain) do
        if unlocked[ach.id] then
            done = done + 1
        elseif not nextAch then
            local prevOk = true
            if ach.chainPrev then
                prevOk = not not unlocked[ach.chainPrev]
            end
            if prevOk then nextAch = ach.id end
        end
    end
    return {
        chainId = chainId,
        total = total,
        completed = done,
        percent = total > 0 and (done / total) or 0,
        nextId = nextAch,
    }
end

function HiddenAchievementSystem.getProgress(playerState)
    local unlocked = getUnlockedSet(playerState)
    local result = {}
    for _, ach in ipairs(HiddenAchievementSystem.HIDDEN_ACHIEVEMENTS) do
        result[ach.id] = {
            id = ach.id,
            name = ach.name,
            desc = ach.desc,
            icon = ach.icon,
            category = ach.category,
            unlocked = not not unlocked[ach.id],
        }
    end
    return result
end

function HiddenAchievementSystem.serialize(playerState)
    if not playerState then return nil end
    local unlocked = getUnlockedSet(playerState)
    local list = {}
    for id, _ in pairs(unlocked) do
        if unlocked[id] then table.insert(list, id) end
    end
    return { unlocked = list }
end

function HiddenAchievementSystem.deserialize(playerState, data)
    if not playerState or not data then return end
    playerState.hiddenAchievements = playerState.hiddenAchievements or {}
    playerState.hiddenAchievements.unlocked = {}
    if data.unlocked then
        for _, id in ipairs(data.unlocked) do
            playerState.hiddenAchievements.unlocked[id] = true
        end
    end
end

return HiddenAchievementSystem
