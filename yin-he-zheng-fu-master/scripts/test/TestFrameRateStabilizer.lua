-- ============================================================================
-- test/TestFrameRateStabilizer.lua  -- FrameRateStabilizer 单元测试
-- ============================================================================

local TestFramework = require("test.TestFramework")
local FrameRateStabilizer = require("game.systems.FrameRateStabilizer")

TestFramework.StartSuite("FrameRateStabilizer Tests")

TestFramework.Test("Initial state should be correct", function()
    FrameRateStabilizer.Reset()
    
    local stats = FrameRateStabilizer.GetStats()
    TestFramework.AssertEqual(0, stats.frameCount)
    TestFramework.AssertEqual(0, stats.droppedFrames)
    TestFramework.AssertEqual(1, stats.qualityLevel)
    TestFramework.AssertEqual("ULTRA", stats.qualityName)
    TestFramework.AssertEqual(1.0, stats.particleMultiplier)
    TestFramework.AssertEqual(1.0, stats.projectileMultiplier)
    TestFramework.AssertEqual(1, stats.shipUpdateInterval)
end)

TestFramework.Test("Update should accumulate frame time", function()
    FrameRateStabilizer.Reset()
    
    FrameRateStabilizer.Update(0.0167)
    FrameRateStabilizer.Update(0.0167)
    FrameRateStabilizer.Update(0.0167)
    
    local stats = FrameRateStabilizer.GetStats()
    TestFramework.AssertEqual(3, stats.frameCount)
    TestFramework.AssertEqual(3, stats.historySize)
end)

TestFramework.Test("GetAverageFPS should calculate correctly", function()
    FrameRateStabilizer.Reset()
    
    for i = 1, 10 do
        FrameRateStabilizer.Update(0.0167)
    end
    
    local avgFPS = FrameRateStabilizer.GetAverageFPS()
    TestFramework.AssertAlmostEqual(60, avgFPS, 5)
end)

TestFramework.Test("SetQualityLevel should change quality settings", function()
    FrameRateStabilizer.Reset()
    
    FrameRateStabilizer.SetQualityLevel(3)
    
    local stats = FrameRateStabilizer.GetStats()
    TestFramework.AssertEqual(3, stats.qualityLevel)
    TestFramework.AssertEqual("MEDIUM", stats.qualityName)
    TestFramework.AssertEqual(0.5, stats.particleMultiplier)
    TestFramework.AssertEqual(0.7, stats.projectileMultiplier)
end)

TestFramework.Test("ShouldUpdateShip should skip based on interval", function()
    FrameRateStabilizer.Reset()
    
    FrameRateStabilizer.SetQualityLevel(4)
    
    TestFramework.AssertTrue(FrameRateStabilizer.ShouldUpdateShip(1))
    TestFramework.AssertFalse(FrameRateStabilizer.ShouldUpdateShip(2))
    TestFramework.AssertTrue(FrameRateStabilizer.ShouldUpdateShip(3))
    TestFramework.AssertFalse(FrameRateStabilizer.ShouldUpdateShip(4))
end)

TestFramework.Test("SetConfig should update configuration", function()
    FrameRateStabilizer.SetConfig({ targetFPS = 30, debugMode = true })
    
    local config = FrameRateStabilizer.GetConfig()
    TestFramework.AssertEqual(30, config.targetFPS)
    TestFramework.AssertTrue(config.debugMode)
end)

TestFramework.Test("GetQualityLevels should return all levels", function()
    local levels = FrameRateStabilizer.GetQualityLevels()
    
    TestFramework.AssertEqual(4, #levels)
    TestFramework.AssertEqual("ULTRA", levels[1].name)
    TestFramework.AssertEqual("LOW", levels[4].name)
end)

TestFramework.Test("Dropped frames should be detected", function()
    FrameRateStabilizer.Reset()
    
    FrameRateStabilizer.Update(0.1)
    
    local stats = FrameRateStabilizer.GetStats()
    TestFramework.AssertEqual(1, stats.droppedFrames)
    TestFramework.AssertEqual(1, stats.consecutiveDrops)
end)

TestFramework.Test("Reset should clear all state", function()
    FrameRateStabilizer.Reset()
    
    FrameRateStabilizer.Update(0.0167)
    FrameRateStabilizer.SetQualityLevel(2)
    
    FrameRateStabilizer.Reset()
    
    local stats = FrameRateStabilizer.GetStats()
    TestFramework.AssertEqual(0, stats.frameCount)
    TestFramework.AssertEqual(1, stats.qualityLevel)
    TestFramework.AssertEqual(1.0, stats.particleMultiplier)
end)

TestFramework.EndSuite()