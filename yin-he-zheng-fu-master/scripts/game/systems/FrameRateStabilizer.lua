-- ============================================================================
-- game/systems/FrameRateStabilizer.lua  -- 帧率稳定系统
-- ============================================================================

local M = {}

local config = {
    targetFPS = 60,
    minFPS = 15,
    maxFrameTime = 1 / 15,
    
    sampleWindow = 60,
    smoothFactor = 0.15,
    
    adaptiveEnabled = true,
    qualitySwitchDelay = 3.0,
    qualitySwitchHysteresis = 5.0,
    
    maxParticleCount = 500,
    particleReductionStep = 0.1,
    
    maxProjectileCount = 100,
    projectileReductionStep = 0.1,
    
    maxShipCount = 50,
    shipUpdateSkip = 2,
    
    debugMode = false,
}

local state = {
    frameCount = 0,
    frameTimeAccum = 0,
    frameTimeHistory = {},
    smoothedFrameTime = 0,
    
    currentQualityLevel = 1,
    lastQualitySwitch = 0,
    
    particleMultiplier = 1.0,
    projectileMultiplier = 1.0,
    shipUpdateInterval = 1,
    
    droppedFrames = 0,
    consecutiveDrops = 0,
    
    lastReportTime = 0,
}

local qualityLevels = {
    {
        name = "ULTRA",
        fpsTarget = 60,
        particleMult = 1.0,
        projectileMult = 1.0,
        shipUpdateMult = 1,
        drawDistance = 1.0,
        shadowQuality = "HIGH",
        bloomEnabled = true,
    },
    {
        name = "HIGH",
        fpsTarget = 45,
        particleMult = 0.8,
        projectileMult = 0.9,
        shipUpdateMult = 1,
        drawDistance = 0.9,
        shadowQuality = "MEDIUM",
        bloomEnabled = true,
    },
    {
        name = "MEDIUM",
        fpsTarget = 30,
        particleMult = 0.5,
        projectileMult = 0.7,
        shipUpdateMult = 1,
        drawDistance = 0.75,
        shadowQuality = "LOW",
        bloomEnabled = false,
    },
    {
        name = "LOW",
        fpsTarget = 20,
        particleMult = 0.3,
        projectileMult = 0.5,
        shipUpdateMult = 2,
        drawDistance = 0.6,
        shadowQuality = "OFF",
        bloomEnabled = false,
    },
}

function M.SetConfig(newConfig)
    for key, value in pairs(newConfig) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
end

function M.GetConfig()
    return config
end

function M.Update(frameTime)
    state.frameCount = state.frameCount + 1
    state.frameTimeAccum = state.frameTimeAccum + frameTime
    
    table.insert(state.frameTimeHistory, frameTime)
    while #state.frameTimeHistory > config.sampleWindow do
        table.remove(state.frameTimeHistory, 1)
    end
    
    if state.smoothedFrameTime == 0 then
        state.smoothedFrameTime = frameTime
    else
        state.smoothedFrameTime = state.smoothedFrameTime * (1 - config.smoothFactor) + frameTime * config.smoothFactor
    end
    
    local currentFPS = 1.0 / state.smoothedFrameTime
    local avgFPS = M.GetAverageFPS()
    
    if frameTime > config.maxFrameTime then
        state.droppedFrames = state.droppedFrames + 1
        state.consecutiveDrops = state.consecutiveDrops + 1
    else
        state.consecutiveDrops = 0
    end
    
    if config.adaptiveEnabled then
        M.AdjustQuality(currentFPS, avgFPS)
    end
    
    if config.debugMode then
        M.DebugReport(currentFPS, avgFPS)
    end
end

function M.AdjustQuality(currentFPS, avgFPS)
    local now = os.clock()
    local timeSinceSwitch = now - state.lastQualitySwitch
    
    if timeSinceSwitch < config.qualitySwitchDelay then
        return
    end
    
    local targetLevel = state.currentQualityLevel
    
    if avgFPS < qualityLevels[state.currentQualityLevel].fpsTarget - config.qualitySwitchHysteresis then
        if state.currentQualityLevel < #qualityLevels then
            targetLevel = state.currentQualityLevel + 1
        end
    elseif avgFPS > qualityLevels[state.currentQualityLevel].fpsTarget + config.qualitySwitchHysteresis then
        if state.currentQualityLevel > 1 then
            targetLevel = state.currentQualityLevel - 1
        end
    end
    
    if targetLevel ~= state.currentQualityLevel then
        M.SetQualityLevel(targetLevel)
        state.lastQualitySwitch = now
        print(string.format("[FrameRateStabilizer] Quality level changed: %s -> %s", 
            qualityLevels[state.currentQualityLevel].name,
            qualityLevels[targetLevel].name))
    end
end

function M.SetQualityLevel(level)
    if level < 1 or level > #qualityLevels then
        return false
    end
    
    state.currentQualityLevel = level
    local q = qualityLevels[level]
    
    state.particleMultiplier = q.particleMult
    state.projectileMultiplier = q.projectileMult
    state.shipUpdateInterval = q.shipUpdateMult
    
    return true
end

function M.GetQualityLevel()
    return state.currentQualityLevel, qualityLevels[state.currentQualityLevel]
end

function M.GetQualityLevels()
    return qualityLevels
end

function M.GetAverageFPS()
    if #state.frameTimeHistory == 0 then
        return config.targetFPS
    end
    
    local total = 0
    for _, ft in ipairs(state.frameTimeHistory) do
        total = total + ft
    end
    local avgFrameTime = total / #state.frameTimeHistory
    return 1.0 / avgFrameTime
end

function M.GetCurrentFPS()
    return 1.0 / state.smoothedFrameTime
end

function M.GetParticleMultiplier()
    return state.particleMultiplier
end

function M.GetProjectileMultiplier()
    return state.projectileMultiplier
end

function M.GetShipUpdateInterval()
    return state.shipUpdateInterval
end

function M.ShouldUpdateShip(shipIndex)
    return shipIndex % state.shipUpdateInterval == 0
end

function M.GetStats()
    local avgFPS = M.GetAverageFPS()
    local currentFPS = M.GetCurrentFPS()
    
    return {
        frameCount = state.frameCount,
        droppedFrames = state.droppedFrames,
        consecutiveDrops = state.consecutiveDrops,
        currentFPS = currentFPS,
        averageFPS = avgFPS,
        smoothedFrameTime = state.smoothedFrameTime,
        qualityLevel = state.currentQualityLevel,
        qualityName = qualityLevels[state.currentQualityLevel].name,
        particleMultiplier = state.particleMultiplier,
        projectileMultiplier = state.projectileMultiplier,
        shipUpdateInterval = state.shipUpdateInterval,
        historySize = #state.frameTimeHistory,
    }
end

function M.DebugReport(currentFPS, avgFPS)
    local now = os.clock()
    if now - state.lastReportTime >= 1.0 then
        print(string.format("[FrameRateStabilizer] FPS: %.1f (avg: %.1f), Quality: %s, Drops: %d",
            currentFPS, avgFPS,
            qualityLevels[state.currentQualityLevel].name,
            state.droppedFrames))
        state.lastReportTime = now
    end
end

function M.Reset()
    state.frameCount = 0
    state.frameTimeAccum = 0
    state.frameTimeHistory = {}
    state.smoothedFrameTime = 0
    state.currentQualityLevel = 1
    state.lastQualitySwitch = 0
    state.particleMultiplier = 1.0
    state.projectileMultiplier = 1.0
    state.shipUpdateInterval = 1
    state.droppedFrames = 0
    state.consecutiveDrops = 0
    state.lastReportTime = 0
end

function M.EnableDebug(enabled)
    config.debugMode = enabled
end

return M