---@diagnostic disable: assign-type-mismatch, return-type-mismatch
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
        -- P2-1: 里程碑奖励（完成部分成就时）
        milestones = {
            { count = 1, rewardType = "resource", reward = { credits = 500 } },
            { count = 3, rewardType = "resource", reward = { credits = 2000, crystal = 500 } },
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
        milestones = {
            { count = 2, rewardType = "resource", reward = { energy = 1000 } },
            { count = 4, rewardType = "resource", reward = { energy = 5000, crystal = 500 } },
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
        milestones = {
            { count = 2, rewardType = "resource", reward = { research = 2000 } },
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
        milestones = {
            { count = 2, rewardType = "resource", reward = { credits = 10000 } },
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
        milestones = {
            { count = 2, rewardType = "resource", reward = { influence = 100 } },
        },
        chainRewards = {
            { achievementId = "GUILD_LEADER", rewardType = "title", reward = "荣耀盟主" },
            { achievementId = "GUILD_LEADER", rewardType = "resource", reward = { influence = 500 } }
        }
    },
    -- P2-1: 新增成就链
    {
        id = "CHAIN_COLONIZATION",
        name = "殖民扩张",
        desc = "开拓外星殖民地",
        chain = {
            "FIRST_COLONY",
            "TEN_COLONIES",
            "COLONY_EXPERT",
            "GALACTIC_EMPIRE"
        },
        milestones = {
            { count = 2, rewardType = "resource", reward = { minerals = 5000, energy = 3000 } },
        },
        chainRewards = {
            { achievementId = "GALACTIC_EMPIRE", rewardType = "title", reward = "银河帝国" },
            { achievementId = "GALACTIC_EMPIRE", rewardType = "resource", reward = { minerals = 50000 } }
        }
    },
    {
        id = "CHAIN_ELITE",
        name = "精英之路",
        desc = "挑战高难度内容",
        chain = {
            "HARD_CLEARED",
            "NIGHTMARE_CLEARED",
            "INSANE_CLEARED",
            "NO_DEATH_RUN"
        },
        milestones = {
            { count = 2, rewardType = "resource", reward = { crystal = 2000 } },
            { count = 3, rewardType = "skillPoint", reward = 15 },
        },
        chainRewards = {
            { achievementId = "NO_DEATH_RUN", rewardType = "title", reward = "不死传说" },
            { achievementId = "NO_DEATH_RUN", rewardType = "resource", reward = { crystal = 10000, research = 10000 } }
        }
    }
}

local ACHIEVEMENT_CHAINS_BY_ID = {}
for _, c in ipairs(ACHIEVEMENT_CHAINS) do ACHIEVEMENT_CHAINS_BY_ID[c.id] = c end

local AchievementChainSystem = {}
AchievementChainSystem.__index = AchievementChainSystem

---@return AchievementChainSystem
function AchievementChainSystem.new()
    local self = setmetatable({}, AchievementChainSystem)
    self.claimedRewards = {}
    return self
end

--- 返回每条链的已达成进度
---@param playerState table
---@return table
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
---@param chainId string
---@param playerState table
---@return string|nil
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
---@param chainId string
---@param playerState table
---@return boolean
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
---@param chainId string
---@return table
function AchievementChainSystem:getChainRewards(chainId)
    local chain = ACHIEVEMENT_CHAINS_BY_ID[chainId]
    if not chain then return {} end
    return chain.chainRewards or {}
end

---@return table
function AchievementChainSystem:serialize()
    local list = {}
    for id, _ in pairs(self.claimedRewards) do list[#list + 1] = id end
    return { claimedRewards = list }
end

---@param data table
function AchievementChainSystem:deserialize(data)
    self.claimedRewards = {}
    if data and data.claimedRewards then
        for _, id in ipairs(data.claimedRewards) do self.claimedRewards[id] = true end
    end
end

-- ============================================================================
-- P2-1: 增强功能 - 里程碑奖励 + 奖励领取
-- ============================================================================

--- 获取指定链的可用里程碑奖励
---@param chainId string
---@param playerState table
---@return table
function AchievementChainSystem:getAvailableMilestones(chainId, playerState)
    local chain = ACHIEVEMENT_CHAINS_BY_ID[chainId]
    if not chain then return {} end
    local progress = self:checkChainProgress(playerState)
    local p = progress[chainId]
    if not p or not chain.milestones then return {} end
    local available = {}
    for _, m in ipairs(chain.milestones) do
        if p.completed >= m.count then
            local key = chainId .. "_milestone_" .. m.count
            if not self.claimedRewards[key] then
                available[#available + 1] = {
                    chainId = chainId,
                    count = m.count,
                    rewardType = m.rewardType,
                    reward = m.reward,
                    key = key,
                }
            end
        end
    end
    return available
end

--- 获取指定链的最终奖励（如果可用且未领取）
---@param chainId string
---@param playerState table
---@return table|nil
function AchievementChainSystem:getAvailableFinalReward(chainId, playerState)
    local chain = ACHIEVEMENT_CHAINS_BY_ID[chainId]
    if not chain then return nil end
    if not self:isChainComplete(chainId, playerState) then return nil end
    local rewards = {}
    for _, r in ipairs(chain.chainRewards or {}) do
        local key = chainId .. "_final_" .. r.achievementId
        if not self.claimedRewards[key] then
            rewards[#rewards + 1] = {
                chainId = chainId,
                achievementId = r.achievementId,
                rewardType = r.rewardType,
                reward = r.reward,
                key = key,
            }
        end
    end
    return rewards
end

--- 领取奖励（通用）
---@param rewardKey string
---@param reward any
---@return boolean, any
function AchievementChainSystem:claimReward(rewardKey, reward)
    if self.claimedRewards[rewardKey] then return false, "已领取" end
    self.claimedRewards[rewardKey] = true
    print("[AchievementChain] 领取奖励:", rewardKey)
    return true, reward
end

--- 获取总进度（所有链的综合）
---@param playerState table
---@return table
function AchievementChainSystem:getTotalProgress(playerState)
    local progress = self:checkChainProgress(playerState)
    local totalDone = 0
    local totalAll = 0
    for _, p in pairs(progress) do
        totalDone = totalDone + p.completed
        totalAll = totalAll + p.total
    end
    return {
        completed = totalDone,
        total = totalAll,
        percent = totalAll > 0 and (totalDone / totalAll) or 0,
        chains = #ACHIEVEMENT_CHAINS,
    }
end

--- 获取所有可用奖励（里程碑 + 最终奖励）
---@param playerState table
---@return table
function AchievementChainSystem:getAllAvailableRewards(playerState)
    local all = {}
    for _, chain in ipairs(ACHIEVEMENT_CHAINS) do
        local milestones = self:getAvailableMilestones(chain.id, playerState)
        for _, m in ipairs(milestones) do all[#all + 1] = m end
        local final = self:getAvailableFinalReward(chain.id, playerState)
        for _, r in ipairs(final or {}) do all[#all + 1] = r end
    end
    return all
end

return AchievementChainSystem
