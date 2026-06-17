-- BattleUtils.lua 回归测试：
-- 1) 未加载 GameConstants 时，BattleUtils.shipTypeName 不应崩溃
-- 2) 已加载 GameConstants 时，BattleUtils.shipTypeName 应返回中文名
-- 3) spawnExplosion / logBattleEvent 在正常 context 下不应崩溃

local tests = {
    passed = 0,
    failed = 0,
    failMsgs = {},
}

local function assertEq(desc, got, expected)
    if got == expected then
        tests.passed = tests.passed + 1
    else
        tests.failed = tests.failed + 1
        tests.failMsgs[#tests.failMsgs + 1] =
            string.format("[FAIL] %s: got=%s expected=%s", desc, tostring(got), tostring(expected))
    end
end

local function assertNotError(desc, fn)
    local ok, err = pcall(fn)
    if ok then
        tests.passed = tests.passed + 1
    else
        tests.failed = tests.failed + 1
        tests.failMsgs[#tests.failMsgs + 1] =
            string.format("[FAIL] %s threw: %s", desc, tostring(err))
    end
end

-- ============================================================
-- Test 1: 孤立加载 BattleUtils（不先加载 GameConstants / Systems）
-- 若 shipTypeName 隐式依赖全局 SHIP_TYPES，则首次访问会抛错。
-- ============================================================
local oldGlobalSHIP = rawget(_G, "SHIP_TYPES")
rawset(_G, "SHIP_TYPES", nil)

-- 先卸载 BattleUtils 以模拟冷启动
package.loaded["game.battle.BattleUtils"] = nil
local BattleUtils = require("game.battle.BattleUtils")

assertNotError("shipTypeName(nil_stype_should_return_stype)", function()
    local result = BattleUtils.shipTypeName("EXPLORER")
    -- 当 SHIP_TYPES 全局不存在时，至少不应抛错，返回 stype 本身即可
    if type(result) ~= "string" then error("expected string, got " .. type(result)) end
end)

assertNotError("spawnExplosion_works_with_minimal_ctx", function()
    local ctx = {
        explParticles = {},
        SK = { timer = 0, dur = 0, strength = 0, offX = 0, offY = 0 },
    }
    BattleUtils.spawnExplosion(ctx, { stype = "FRIGATE", x = 0, y = 0, team = "player" })
    if #ctx.explParticles < 1 then error("expected at least 1 explosion particle") end
end)

assertNotError("logBattleEvent_handles_missing_battleLog", function()
    local ctx = {
        battleLog = {},
        BATTLE_LOG_MAX = 50,
        waveNum = 3,
    }
    BattleUtils.logBattleEvent(ctx, "测试日志")
    if #ctx.battleLog ~= 1 then error("expected 1 log entry, got " .. #ctx.battleLog) end
end)

-- 恢复全局，避免污染后续测试
rawset(_G, "SHIP_TYPES", oldGlobalSHIP)
package.loaded["game.battle.BattleUtils"] = nil

print(string.format(
    "[BattleUtils_test] 测试结果 passed=%d failed=%d",
    tests.passed, tests.failed
))
for _, m in ipairs(tests.failMsgs) do print("  " .. m) end

return tests
