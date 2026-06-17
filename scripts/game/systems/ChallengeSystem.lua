--[[
ChallengeSystem.lua - 每日挑战系统
V2.7 P0-3
]]

local ChallengeSystem = {}

-- 获取今日挑战
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
function ChallengeSystem.getChallengePoints(playerState)
    return playerState.challengePoints or 0
end

return ChallengeSystem