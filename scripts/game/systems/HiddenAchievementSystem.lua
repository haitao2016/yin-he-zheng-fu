---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-----------------------------------------------------------
-- HiddenAchievementSystem 隐藏成就链式解锁系统
-- V3.0 Phase 1 P2-2
-- 12+ 隐藏成就，以 ??? 遮罩未解锁项，支持成就链式解锁
-----------------------------------------------------------
require("game.GameConstants")

--- 隐藏成就定义
--- hidden: true 表示未解锁时显示为 ???
--- chain: 链ID，同链成就必须按顺序解锁
--- prerequisite: 前置成就ID（同一链中必须先解锁）
local HIDDEN_ACHIEVEMENTS = {
    -- ============ 探索链 ============
    {
        id = "EXPLORER_I",
        hidden = true,
        chain = "exploration",
        name = "???",  -- 未解锁时显示 ???
        realName = "星际探险家 I",
        desc = "???",
        realDesc = "探索 5 个星系",
        icon = "🔭",
        category = "exploration",
        prerequisite = nil,
        condition = function(ps) return (ps.galaxiesExplored or 0) >= 5 end,
        reward = { blueCrystal = 30 },
    },
    {
        id = "EXPLORER_II",
        hidden = true,
        chain = "exploration",
        name = "???",
        realName = "星际探险家 II",
        desc = "???",
        realDesc = "探索 20 个星系",
        icon = "🔭",
        category = "exploration",
        prerequisite = "EXPLORER_I",
        condition = function(ps) return (ps.galaxiesExplored or 0) >= 20 end,
        reward = { blueCrystal = 50 },
    },
    {
        id = "ARCHAEOLOGIST",
        hidden = true,
        chain = "exploration",
        name = "???",
        realName = "考古学家",
        desc = "???",
        realDesc = "发现所有远古遗迹",
        icon = "🏛️",
        category = "exploration",
        prerequisite = "EXPLORER_II",
        condition = function(ps) return ps.allRelicsDiscovered or false end,
        reward = { purpleCrystal = 30 },
    },
    {
        id = "HIDDEN_STAR",
        hidden = true,
        chain = "exploration",
        name = "???",
        realName = "隐秘星辰",
        desc = "???",
        realDesc = "发现隐藏星系",
        icon = "⭐",
        category = "exploration",
        prerequisite = "ARCHAEOLOGIST",
        condition = function(ps) return ps.hiddenGalaxyFound or false end,
        reward = { purpleCrystal = 50, rainbowCrystal = 5 },
    },
    -- ============ 战斗链 ============
    {
        id = "FLAWLESS_I",
        hidden = true,
        chain = "combat",
        name = "???",
        realName = "完美主义者 I",
        desc = "???",
        realDesc = "无伤完成一波",
        icon = "💫",
        category = "combat",
        prerequisite = nil,
        condition = function(ps) return (ps.flawlessWaves or 0) >= 1 end,
        reward = { blueCrystal = 40 },
    },
    {
        id = "FLAWLESS_II",
        hidden = true,
        chain = "combat",
        name = "???",
        realName = "完美主义者 II",
        desc = "???",
        realDesc = "无伤完成 5 波",
        icon = "💫",
        category = "combat",
        prerequisite = "FLAWLESS_I",
        condition = function(ps) return (ps.flawlessWaves or 0) >= 5 end,
        reward = { blueCrystal = 60 },
    },
    {
        id = "FLAWLESS_MASTER",
        hidden = true,
        chain = "combat",
        name = "???",
        realName = "完美大师",
        desc = "???",
        realDesc = "无伤完成一整章战役",
        icon = "🏅",
        category = "combat",
        prerequisite = "FLAWLESS_II",
        condition = function(ps) return ps.flawlessChapter or false end,
        reward = { purpleCrystal = 80, rainbowCrystal = 10 },
    },
    -- ============ 经济链 ============
    {
        id = "SHIPBUILDER_I",
        hidden = true,
        chain = "economy",
        name = "???",
        realName = "舰船建造师 I",
        desc = "???",
        realDesc = "建造 10 艘舰船",
        icon = "⚓",
        category = "economy",
        prerequisite = nil,
        condition = function(ps) return (ps.shipsBuilt or 0) >= 10 end,
        reward = { blueCrystal = 30 },
    },
    {
        id = "SHIPBUILDER_II",
        hidden = true,
        chain = "economy",
        name = "???",
        realName = "舰船建造师 II",
        desc = "???",
        realDesc = "建造 50 艘舰船",
        icon = "⚓",
        category = "economy",
        prerequisite = "SHIPBUILDER_I",
        condition = function(ps) return (ps.shipsBuilt or 0) >= 50 end,
        reward = { blueCrystal = 60 },
    },
    {
        id = "ADMIRAL",
        hidden = true,
        chain = "economy",
        name = "???",
        realName = "海军上将",
        desc = "???",
        realDesc = "组建百舰舰队",
        icon = "🎖️",
        category = "economy",
        prerequisite = "SHIPBUILDER_II",
        condition = function(ps) return (ps.maxFleetSize or 0) >= 100 end,
        reward = { purpleCrystal = 100, rainbowCrystal = 15 },
    },
    -- ============ 社交链 ============
    {
        id = "GUILD_MEMBER",
        hidden = true,
        chain = "social",
        name = "???",
        realName = "公会新人",
        desc = "???",
        realDesc = "完成首个公会任务",
        icon = "🤝",
        category = "social",
        prerequisite = nil,
        condition = function(ps) return (ps.guildTasksCompleted or 0) >= 1 end,
        reward = { blueCrystal = 30 },
    },
    {
        id = "GUILD_VETERAN",
        hidden = true,
        chain = "social",
        name = "???",
        realName = "公会老兵",
        desc = "???",
        realDesc = "完成 10 个公会任务",
        icon = "🤝",
        category = "social",
        prerequisite = "GUILD_MEMBER",
        condition = function(ps) return (ps.guildTasksCompleted or 0) >= 10 end,
        reward = { blueCrystal = 80 },
    },
    {
        id = "GUILD_LEADER",
        hidden = true,
        chain = "social",
        name = "???",
        realName = "公会领袖",
        desc = "???",
        realDesc = "成为公会会长",
        icon = "👑",
        category = "social",
        prerequisite = "GUILD_VETERAN",
        condition = function(ps) return ps.isGuildLeader or false end,
        reward = { purpleCrystal = 150, rainbowCrystal = 20 },
    },
    -- ============ 额外隐藏成就（无链） ============
    {
        id = "SECRET_TECH",
        hidden = true,
        chain = nil,
        name = "???",
        realName = "禁忌科技",
        desc = "???",
        realDesc = "发现隐藏科技路线",
        icon = "🔮",
        category = "research",
        prerequisite = nil,
        condition = function(ps) return ps.secretTechDiscovered or false end,
        reward = { rainbowCrystal = 30 },
    },
    {
        id = "TREASURE_HUNTER",
        hidden = true,
        chain = nil,
        name = "???",
        realName = "宝藏猎人",
        desc = "???",
        realDesc = "在单次探索中发现 3 个稀有资源点",
        icon = "💎",
        category = "exploration",
        prerequisite = nil,
        condition = function(ps) return (ps.rareNodesFoundInOneRun or 0) >= 3 end,
        reward = { purpleCrystal = 50 },
    },
    {
        id = "PERFECT_DEFENSE",
        hidden = true,
        chain = nil,
        name = "???",
        realName = "铜墙铁壁",
        desc = "???",
        realDesc = "在防御塔协助下完成 10 波战斗，未失去任何舰船",
        icon = "🏰",
        category = "combat",
        prerequisite = nil,
        condition = function(ps) return (ps.towerDefensePerfectWaves or 0) >= 10 end,
        reward = { blueCrystal = 100 },
    },
}

--- 按ID索引
local ACH_BY_ID = {}
for _, a in ipairs(HIDDEN_ACHIEVEMENTS) do ACH_BY_ID[a.id] = a end

--- 按链分组
local ACH_BY_CHAIN = {}
for _, a in ipairs(HIDDEN_ACHIEVEMENTS) do
    if a.chain then
        ACH_BY_CHAIN[a.chain] = ACH_BY_CHAIN[a.chain] or {}
        ACH_BY_CHAIN[a.chain][#ACH_BY_CHAIN[a.chain] + 1] = a
    end
end

local HiddenAchievementSystem = {}
HiddenAchievementSystem.__index = HiddenAchievementSystem

function HiddenAchievementSystem.new()
    local self = setmetatable({}, HiddenAchievementSystem)
    self.unlocked = {}      -- { [id] = true }
    self.chainProgress = {} -- { [chainId] = { current = 0, unlocked = {} } }
    return self
end

--- 检查成就是否可解锁（前置条件满足）
function HiddenAchievementSystem:isUnlocked(achievementId)
    return self.unlocked[achievementId] == true
end

--- 检查成就是否满足解锁条件（包含前置检查）
function HiddenAchievementSystem:canUnlock(achievementId, playerStats)
    local ach = ACH_BY_ID[achievementId]
    if not ach then return false end
    if self.unlocked[achievementId] then return false end  -- 已解锁
    -- 前置成就检查
    if ach.prerequisite then
        if not self.unlocked[ach.prerequisite] then return false end
    end
    -- 条件检查
    if ach.condition then
        return ach:condition(playerStats)
    end
    return false
end

--- 解锁成就
function HiddenAchievementSystem:unlock(achievementId, playerStats)
    if self.unlocked[achievementId] then return false end
    local ach = ACH_BY_ID[achievementId]
    if not ach then return false end

    -- 前置检查
    if ach.prerequisite and not self.unlocked[ach.prerequisite] then
        return false, "前置成就未完成"
    end

    -- 条件检查
    if ach.condition and not ach:condition(playerStats) then
        return false, "条件未满足"
    end

    self.unlocked[achievementId] = true

    -- 更新链进度
    if ach.chain then
        self.chainProgress[ach.chain] = self.chainProgress[ach.chain] or { current = 0, unlocked = {} }
        self.chainProgress[ach.chain].current = (self.chainProgress[ach.chain].current or 0) + 1
        self.chainProgress[ach.chain].unlocked[achievementId] = true
    end

    print("[HiddenAchievement] 解锁隐藏成就: " .. ach.realName .. " (" .. achievementId .. ")")
    return true, ach
end

--- 每帧检查可解锁的成就
function HiddenAchievementSystem:checkAll(playerStats)
    local newlyUnlocked = {}
    for _, ach in ipairs(HIDDEN_ACHIEVEMENTS) do
        if not self.unlocked[ach.id] then
            local ok, result = self:unlock(ach.id, playerStats)
            if ok and result then
                newlyUnlocked[#newlyUnlocked + 1] = result
            end
        end
    end
    return newlyUnlocked
end

--- 获取成就显示信息（隐藏时返回 ???）
function HiddenAchievementSystem:getDisplayInfo(achievementId)
    local ach = ACH_BY_ID[achievementId]
    if not ach then return nil end
    if not self.unlocked[achievementId] and ach.hidden then
        return {
            id = ach.id,
            name = "???",
            desc = "???",
            icon = "🔒",
            hidden = true,
        }
    end
    return {
        id = ach.id,
        name = ach.realName or ach.name,
        desc = ach.realDesc or ach.desc,
        icon = ach.icon,
        hidden = false,
    }
end

--- 获取某个链的当前进度
function HiddenAchievementSystem:getChainProgress(chainId)
    return self.chainProgress[chainId] or { current = 0, unlocked = {} }
end

--- 获取某个链下一个可解锁的成就
function HiddenAchievementSystem:getNextInChain(chainId)
    local chain = ACH_BY_CHAIN[chainId]
    if not chain then return nil end
    for _, ach in ipairs(chain) do
        if not self.unlocked[ach.id] then
            return ach
        end
    end
    return nil  -- 全部解锁
end

--- 获取所有隐藏成就（用于 UI 显示）
function HiddenAchievementSystem:getAllDisplay(playerStats)
    local result = {}
    for _, ach in ipairs(HIDDEN_ACHIEVEMENTS) do
        result[#result + 1] = self:getDisplayInfo(ach.id)
    end
    return result
end

--- 获取已解锁的隐藏成就数量
function HiddenAchievementSystem:getUnlockedCount()
    local count = 0
    for _, v in pairs(self.unlocked) do
        if v then count = count + 1 end
    end
    return count
end

--- 获取隐藏成就总数
function HiddenAchievementSystem:getTotalCount()
    return #HIDDEN_ACHIEVEMENTS
end

--- 序列化
function HiddenAchievementSystem:serialize()
    return {
        unlocked = self.unlocked,
        chainProgress = self.chainProgress,
    }
end

--- 反序列化
function HiddenAchievementSystem:deserialize(data)
    self.unlocked = {}
    self.chainProgress = {}
    if data then
        if data.unlocked then
            for id, v in pairs(data.unlocked) do
                self.unlocked[id] = v
            end
        end
        if data.chainProgress then
            self.chainProgress = data.chainProgress
        end
    end
end

return HiddenAchievementSystem