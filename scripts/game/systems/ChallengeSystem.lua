--[[
ChallengeSystem.lua - 每日挑战系统
V2.7 P0-3
]]

local ChallengeSystem = {}

-- 获取今日挑战
---@return table
function ChallengeSystem.getDailyChallenge()
    local dateStr = os.date("%Y%m%d")
    local salt = 20260617
    local seedNum = tonumber(dateStr) + salt
    math.randomseed(seedNum)
    
    -- 随机选择 1-2 个挑战
    local challengeCount = math.random(1, 2)
    local selected = {}
    
    for i = 1, challengeCount do
        local idx = math.random(#DAILY_CHALLENGES)
        table.insert(selected, DAILY_CHALLENGES[idx])
    end
    
    return {
        seed = seedNum,
        date = os.date("%Y-%m-%d"),
        challenges = selected,
        completed = false,
        perfect = false,
        score = 0,
    }
end

-- 应用挑战效果到游戏状态
---@param challenge table
---@param gameState table
function ChallengeSystem.applyChallengeEffect(challenge, gameState)
    local ctype = challenge.type
    
    if ctype == "LOW_RESOURCE" then
        gameState.resourceMult = {
            minerals = challenge.metalMult,
            energy = challenge.esourceMult,
        }
    elseif ctype == "BOSS_FROM_WAVE1" then
        gameState.forceBossWave1 = true
    elseif ctype == "SPEED_BATTLE" then
        gameState.waveTimeLimit = challenge.timeLimitPerWave
    end
end

-- 领取挑战奖励
---@param challenge table
---@param playerState table
---@return table
function ChallengeSystem.claimChallengeReward(challenge, playerState)
    local points = challenge.reward or 50
    playerState.challengePoints = (playerState.challengePoints or 0) + points
    
    local bonus = {}
    if challenge.difficulty == "hard" then
        bonus.blueCrystal = math.random(20, 50)
    else
        bonus.blueCrystal = math.random(10, 30)
    end
    
    return { points = points, bonus = bonus }
end

-- 获取挑战积分
---@param playerState table
---@return number
function ChallengeSystem.getChallengePoints(playerState)
    return playerState.challengePoints or 0
end

-- P2-2: 挑战积分商店扩展
---@param itemId string
---@param playerState table
---@param rm table
---@param notifyFn function
---@return boolean, string
ChallengeSystem.purchaseShopItem = function(itemId, playerState, rm, notifyFn)
    local item = nil
    for _, i in ipairs(CHALLENGE_SHOP) do
        if i.id == itemId then item = i; break end
    end
    
    if not item then return false, "商品不存在" end
    
    local points = playerState.challengePoints or 0
    if points < item.cost then return false, "积分不足（需要 " .. item.cost .. "）" end
    
    playerState.challengePoints = points - item.cost
    
    -- 应用商品效果
    if item.id == "SKILL_RESET" then
        playerState.skillPoints = playerState.maxSkillPoints or 6
        for _, ship in ipairs(playerState.fleet or {}) do
            ship.skillLevel = 1
        end
        notifyFn("技能点已重置", "success")
    elseif item.id == "GOLD_CHEST" then
        local rewards = { blueCrystal = math.random(20, 50), purpleCrystal = math.random(5, 15) }
        for res, amount in pairs(rewards) do
            rm:addRare(res, amount)
        end
        notifyFn("获得: " .. rewards.blueCrystal .. " 蓝晶石, " .. rewards.purpleCrystal .. " 紫晶石", "success")
    elseif item.id == "SPEED_UP" then
        playerState.speedBoostActive = true
        playerState.speedBoostExpiry = os.time() + 3600
        notifyFn("全局加速已激活（1小时）", "success")
    elseif item.id == "REPAIR_KIT" then
        for _, ship in ipairs(playerState.fleet or {}) do
            ship.health = math.min(ship.health + ship.maxHealth * 0.5, ship.maxHealth)
        end
        notifyFn("舰队已修复 50%", "success")
    elseif item.id == "BOSS_KEY" then
        playerState.bossKeyAvailable = true
        notifyFn("Boss 钥匙已获得，可在下一波召唤 Boss", "success")
    end
    
    return true, "购买成功"
end

return ChallengeSystem