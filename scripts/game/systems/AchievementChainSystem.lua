---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-----------------------------------------------------------
-- AchievementChainSystem 成就解锁链系统
-----------------------------------------------------------
require("game.GameConstants")

ACHIEVEMENT_CHAINS = {
    {
        id = "CHAIN_COMBAT",
        name = "战斗之路",
        desc = "从首次出击到传奇猎人",
        chain = {
            "FIRST_BLOOD",
            "BOSS_SLAYER",
            "LEGENDARY_HUNTER",
            "NO_DAMAGE_MASTER",
            "COMBO_KING"
        },
        chainRewards = {
            { achievementId = "COMBO_KING", rewardType = "title", reward = "战王" },
            { achievementId = "COMBO_KING", rewardType = "resource", reward = { crystal = 5000 } }
        }
    },
    {
        id = "CHAIN_EXPLORATION",
        name = "银河探索者",
        desc = "探索浩瀚银河，发现远古遗迹",
        chain = {
            "FIRST_SYSTEM",
            "FIVE_SYSTEMS",
            "TEN_SYSTEMS",
            "ANCIENT_RUINS",
            "HIDDEN_GALAXY"
        },
        chainRewards = {
            { achievementId = "HIDDEN_GALAXY", rewardType = "title", reward = "星辰导航者" },
            { achievementId = "HIDDEN_GALAXY", rewardType = "resource", reward = { energy = 8000 } }
        }
    },
    {
        id = "CHAIN_TECHNOLOGY",
        name = "科技先驱",
        desc = "从第一步到科技巅峰",
        chain = {
            "FIRST_STEPS",
            "RESEARCH_MASTER",
            "TECH_TREE_COMPLETE"
        },
        chainRewards = {
            { achievementId = "TECH_TREE_COMPLETE", rewardType = "title", reward = "大科学家" },
            { achievementId = "TECH_TREE_COMPLETE", rewardType = "skillPoint", reward = 10 }
        }
    },
    {
        id = "CHAIN_ECONOMY",
        name = "银河巨富",
        desc = "从首次建造到资源百万",
        chain = {
            "FIRST_BUILD",
            "FIFTY_SHIPS",
            "HUNDRED_FLEET",
            "MILLION_RESOURCES"
        },
        chainRewards = {
            { achievementId = "MILLION_RESOURCES", rewardType = "title", reward = "银河大亨" },
            { achievementId = "MILLION_RESOURCES", rewardType = "resource", reward = { credits = 100000 } }
        }
    },
    {
        id = "CHAIN_SOCIAL",
        name = "公会领袖",
        desc = "从加入公会到成为领袖",
        chain = {
            "FIRST_GUILD",
            "TEN_GUILD_QUESTS",
            "GUILD_LEADER"
        },
        chainRewards = {
            { achievementId = "GUILD_LEADER", rewardType = "title", reward = "荣耀盟主" },
            { achievementId = "GUILD_LEADER", rewardType = "resource", reward = { influence = 500 } }
        }
    }
}

local ACHIEVEMENT_CHAINS_BY_ID = {}
for _, c in ipairs(ACHIEVEMENT_CHAINS) do ACHIEVEMENT_CHAINS_BY_ID[c.id] = c end

local AchievementChainSystem = {}
AchievementChainSystem.__index = AchievementChainSystem

function AchievementChainSystem.new()
    local self = setmetatable({}, AchievementChainSystem)
    self.claimedRewards = {}
    return self
end

--- 返回每条链的已达成进度
function AchievementChainSystem:checkChainProgress(playerState)
    local unlocked = (playerState and playerState.achievements) or {}
    local result = {}
    for _, chain in ipairs(ACHIEVEMENT_CHAINS) do
        local done = 0
        local total = #chain.chain
        for _, achId in ipairs(chain.chain) do
            if unlocked[achId] then done = done + 1 end
        end
        result[chain.id] = {
            name = chain.name,
            completed = done,
            total = total,
            percent = total > 0 and (done / total) or 0,
            done = done == total
        }
    end
    return result
end

--- 返回链中下一个未完成的成就 id
function AchievementChainSystem:getNextInChain(chainId, playerState)
    local chain = ACHIEVEMENT_CHAINS_BY_ID[chainId]
    if not chain then return nil end
    local unlocked = (playerState and playerState.achievements) or {}
    for _, achId in ipairs(chain.chain) do
        if not unlocked[achId] then return achId end
    end
    return nil
end

--- 检查整条链是否完成
function AchievementChainSystem:isChainComplete(chainId, playerState)
    local chain = ACHIEVEMENT_CHAINS_BY_ID[chainId]
    if not chain then return false end
    local unlocked = (playerState and playerState.achievements) or {}
    for _, achId in ipairs(chain.chain) do
        if not unlocked[achId] then return false end
    end
    return true
end

--- 获取链完成时的奖励列表
function AchievementChainSystem:getChainRewards(chainId)
    local chain = ACHIEVEMENT_CHAINS_BY_ID[chainId]
    if not chain then return {} end
    return chain.chainRewards or {}
end

function AchievementChainSystem:serialize()
    local list = {}
    for id, _ in pairs(self.claimedRewards) do list[#list + 1] = id end
    return { claimedRewards = list }
end

function AchievementChainSystem:deserialize(data)
    self.claimedRewards = {}
    if data and data.claimedRewards then
        for _, id in ipairs(data.claimedRewards) do self.claimedRewards[id] = true end
    end
end

return AchievementChainSystem
