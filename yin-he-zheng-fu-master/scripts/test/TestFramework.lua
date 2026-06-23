-- ============================================================================
-- test/TestFramework.lua  -- 单元测试框架
-- ============================================================================

local M = {}

local testResults = {}
local currentSuite = nil
local currentTest = nil

function M.StartSuite(name)
    currentSuite = {
        name = name,
        tests = {},
        passed = 0,
        failed = 0,
        skipped = 0,
    }
    testResults[name] = currentSuite
    print(string.format("[TEST] Starting suite: %s", name))
end

function M.EndSuite()
    if currentSuite then
        local total = currentSuite.passed + currentSuite.failed
        local percent = total > 0 and (currentSuite.passed / total) * 100 or 0
        print(string.format("[TEST] Suite '%s' completed: %d passed, %d failed, %d skipped (%.1f%%)",
            currentSuite.name,
            currentSuite.passed,
            currentSuite.failed,
            currentSuite.skipped,
            percent))
        currentSuite = nil
    end
end

function M.Test(name, func)
    if not currentSuite then
        print("[TEST] Error: No suite started")
        return
    end
    
    currentTest = name
    print(string.format("[TEST] Running: %s", name))
    
    local success, err = pcall(func)
    
    if success then
        currentSuite.passed = currentSuite.passed + 1
        print(string.format("[TEST] PASS: %s", name))
    else
        currentSuite.failed = currentSuite.failed + 1
        print(string.format("[TEST] FAIL: %s - %s", name, tostring(err)))
    end
    
    currentTest = nil
end

function M.Skip(name, reason)
    if not currentSuite then
        print("[TEST] Error: No suite started")
        return
    end
    
    currentSuite.skipped = currentSuite.skipped + 1
    print(string.format("[TEST] SKIP: %s - %s", name, reason))
end

function M.AssertTrue(value, message)
    if not value then
        error(message or "Expected true, got false")
    end
end

function M.AssertFalse(value, message)
    if value then
        error(message or "Expected false, got true")
    end
end

function M.AssertEqual(expected, actual, message)
    if expected ~= actual then
        error(message or string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
    end
end

function M.AssertNotEqual(expected, actual, message)
    if expected == actual then
        error(message or string.format("Expected not %s", tostring(expected)))
    end
end

function M.AssertNil(value, message)
    if value ~= nil then
        error(message or string.format("Expected nil, got %s", tostring(value)))
    end
end

function M.AssertNotNil(value, message)
    if value == nil then
        error(message or "Expected not nil")
    end
end

function M.AssertAlmostEqual(expected, actual, tolerance, message)
    tolerance = tolerance or 0.001
    local diff = math.abs(expected - actual)
    if diff > tolerance then
        error(message or string.format("Expected %.4f, got %.4f (diff: %.4f)", expected, actual, diff))
    end
end

function M.AssertThrows(func, message)
    local success, err = pcall(func)
    if success then
        error(message or "Expected function to throw")
    end
end

function M.GetResults()
    return testResults
end

function M.PrintSummary()
    local totalPassed = 0
    local totalFailed = 0
    local totalSkipped = 0
    
    print("\n=== TEST SUMMARY ===")
    for name, suite in pairs(testResults) do
        local total = suite.passed + suite.failed
        local percent = total > 0 and (suite.passed / total) * 100 or 0
        print(string.format("Suite: %s", name))
        print(string.format("  Passed: %d | Failed: %d | Skipped: %d | Coverage: %.1f%%",
            suite.passed, suite.failed, suite.skipped, percent))
        totalPassed = totalPassed + suite.passed
        totalFailed = totalFailed + suite.failed
        totalSkipped = totalSkipped + suite.skipped
    end
    
    local total = totalPassed + totalFailed
    local overallPercent = total > 0 and (totalPassed / total) * 100 or 0
    print(string.format("\nOverall: %d passed, %d failed, %d skipped (%.1f%%)",
        totalPassed, totalFailed, totalSkipped, overallPercent))
    print("===================")
    
    return overallPercent
end

function M.RunAllTests(testFiles)
    for _, file in ipairs(testFiles) do
        local ok, err = pcall(require, file)
        if not ok then
            print(string.format("[TEST] Failed to load test file %s: %s", file, err))
        end
    end
    return M.PrintSummary()
end

return M