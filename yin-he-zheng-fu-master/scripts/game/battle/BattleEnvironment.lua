-- ============================================================================
-- game/battle/BattleEnvironment.lua  -- 战斗环境系统
-- ============================================================================

local M = {}

local BATTLE_ENVIRONMENTS = {
    NONE = {
        key   = "NONE",
        label = "无",
        icon  = "",
        desc  = "",
        bgR = 0, bgG = 5, bgB = 16,
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 1.0,
        asteroidDamage   = 0,
        particleType = "none",
    },
    NEBULA = {
        key   = "NEBULA",
        label = "星云",
        icon  = "☁",
        desc  = "浓密星云降低能见度，敌方射程 -25%",
        bgR = 8,  bgG = 0,  bgB = 22,
        enemyRangeMult   = 0.75,
        shieldAbsorb     = 1.0,
        asteroidDamage   = 0,
        particleType = "nebula",
        pR = 80, pG = 40, pB = 200,
    },
    ASTEROID = {
        key   = "ASTEROID",
        label = "小行星带",
        icon  = "☄",
        desc  = "飞石频繁撞击，每2秒随机舰船受到碎片伤害",
        bgR = 12, bgG = 8,  bgB = 5,
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 1.0,
        asteroidDamage   = 12,
        asteroidInterval = 2.0,
        particleType = "asteroid",
        pR = 140, pG = 110, pB = 60,
    },
    MAGSTOR = {
        key   = "MAGSTOR",
        label = "磁暴",
        icon  = "⚡",
        desc  = "强烈磁暴干扰护盾系统，护盾吸收率 -40%",
        bgR = 0,  bgG = 12, bgB = 8,
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 0.60,
        asteroidDamage   = 0,
        particleType = "magstor",
        pR = 40, pG = 220, pB = 120,
    },
}

local ENV_POOL = { "NEBULA", "ASTEROID", "MAGSTOR" }

local currentEnv_ = BATTLE_ENVIRONMENTS.NONE
local envParticles_ = {}
local envTimer_ = 0
local envAsteroidTimer_ = 0
local envAnnounceAlpha_ = 0
local envAnnounceTimer_ = 0
local ENV_ANNOUNCE_DUR = 2.0

function M.GetEnvironments()
    return BATTLE_ENVIRONMENTS
end

function M.GetEnvPool()
    return ENV_POOL
end

function M.GetCurrentEnv()
    return currentEnv_
end

function M.SetCurrentEnv(envKey)
    currentEnv_ = BATTLE_ENVIRONMENTS[envKey] or BATTLE_ENVIRONMENTS.NONE
end

function M.Randomize()
    if math.random() < 0.3 then
        currentEnv_ = BATTLE_ENVIRONMENTS.NONE
    else
        local idx = math.random(#ENV_POOL)
        currentEnv_ = BATTLE_ENVIRONMENTS[ENV_POOL[idx]]
    end
    envParticles_ = {}
    envTimer_ = 0
    envAsteroidTimer_ = 0
    envAnnounceAlpha_ = 1.0
    envAnnounceTimer_ = ENV_ANNOUNCE_DUR
end

function M.Reset()
    currentEnv_ = BATTLE_ENVIRONMENTS.NONE
    envParticles_ = {}
    envTimer_ = 0
    envAsteroidTimer_ = 0
    envAnnounceAlpha_ = 0
    envAnnounceTimer_ = 0
end

function M.Update(dt)
    envTimer_ = envTimer_ + dt
    
    if envAnnounceTimer_ > 0 then
        envAnnounceTimer_ = envAnnounceTimer_ - dt
        if envAnnounceTimer_ <= 0 then
            envAnnounceAlpha_ = 0
        else
            envAnnounceAlpha_ = envAnnounceTimer_ / ENV_ANNOUNCE_DUR
        end
    end
    
    if currentEnv_.particleType == "asteroid" then
        envAsteroidTimer_ = envAsteroidTimer_ + dt
    end
end

function M.GetState()
    return {
        currentEnv = currentEnv_,
        envParticles = envParticles_,
        envTimer = envTimer_,
        envAsteroidTimer = envAsteroidTimer_,
        envAnnounceAlpha = envAnnounceAlpha_,
        envAnnounceTimer = envAnnounceTimer_,
    }
end

function M.SetState(state)
    currentEnv_ = state.currentEnv or BATTLE_ENVIRONMENTS.NONE
    envParticles_ = state.envParticles or {}
    envTimer_ = state.envTimer or 0
    envAsteroidTimer_ = state.envAsteroidTimer or 0
    envAnnounceAlpha_ = state.envAnnounceAlpha or 0
    envAnnounceTimer_ = state.envAnnounceTimer or 0
end

return M