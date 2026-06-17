-- =============================================================================
-- tests/test_battle_shield_stats.lua
-- 目的：验证战斗中敌方有护盾时，玩家总伤害统计（dmgDealt）
--       等于敌方总生命值损失（即：盾吸收部分不计入 dmgDealt）。
--
-- 触发场景：玩家舰（无盾，100 HP，20 DMG）射击 1 只敌方舰（盾=10，HP=100）。
--   - 首次射击：absorbed = min(10, 20) = 10，实际伤害 = 10，总 dmgDealt 应为 10
--   - 若 Bug 使用 raw dmg（20）计入 dmgDealt，则 dmgDealt=20（虚高）
--
-- 运行方式：lua5.3 scripts/tests/test_battle_shield_stats.lua
-- =============================================================================

package.path = "./scripts/?.lua;" .. package.path

-- 依赖 BattleAI 使用的本地状态变量。为了最小化依赖并精确复现
-- "盾吸收 vs dmgDealt 统计" 的场景，我们直接隔离 BattleAI 的
-- 核心玩家射击路径中的盾吸收 & 统计累加片段。
--
-- 我们并不 require("game.battle.BattleAI")（它依赖 Urho3D/Audio 等
-- 游戏内模块），而是把关键逻辑提取为一个可测试函数。

local function simulatePlayerShot_OLD(rawDmg, targetShield, targetHealth)
    -- Bug 版本：dmgDealt 使用 raw dmg（与 BattleAI.lua:847 当前实现一致）
    local actualDmg = rawDmg
    if targetShield and targetShield > 0 then
        local absorbed = math.min(targetShield, rawDmg)
        targetShield = targetShield - absorbed
        actualDmg = rawDmg - absorbed
    end
    targetHealth = targetHealth - actualDmg
    local dmgDealt = rawDmg   -- ← BUG：统计使用了 raw dmg，而不是 actualDmg
    return {
        targetHealth = targetHealth,
        targetShield = targetShield,
        actualDmg    = actualDmg,
        dmgDealt     = dmgDealt,
    }
end

local function simulatePlayerShot_FIXED(rawDmg, targetShield, targetHealth)
    -- 修复版本：dmgDealt 使用 actualDmg（盾吸收不计入总伤害统计）
    local actualDmg = rawDmg
    if targetShield and targetShield > 0 then
        local absorbed = math.min(targetShield, rawDmg)
        targetShield = targetShield - absorbed
        actualDmg = rawDmg - absorbed
    end
    targetHealth = targetHealth - actualDmg
    local dmgDealt = actualDmg   -- ← FIX
    return {
        targetHealth = targetHealth,
        targetShield = targetShield,
        actualDmg    = actualDmg,
        dmgDealt     = dmgDealt,
    }
end

local passed = 0
local failed = 0
local function assertEq(label, expected, got)
    if expected == got then
        passed = passed + 1
        print(string.format("  [PASS] %s: expected=%s got=%s", label, tostring(expected), tostring(got)))
    else
        failed = failed + 1
        print(string.format("  [FAIL] %s: expected=%s got=%s", label, tostring(expected), tostring(got)))
    end
end

print("== Case 1: 首次射击带盾目标（raw=20, shield=10, hp=100）")
local r1_old   = simulatePlayerShot_OLD(20, 10, 100)
local r1_fixed = simulatePlayerShot_FIXED(20, 10, 100)
assertEq("OLD: targetHealth=90?",   90, r1_old.targetHealth)
assertEq("OLD: targetShield=0?",     0, r1_old.targetShield)
assertEq("OLD: dmgDealt SHOULD BE 10 (but OLD uses raw 20 → fails as bug repro)", 10, r1_old.dmgDealt)
assertEq("FIXED: targetHealth=90?",  90, r1_fixed.targetHealth)
assertEq("FIXED: targetShield=0?",   0, r1_fixed.targetShield)
assertEq("FIXED: dmgDealt=10?",      10, r1_fixed.dmgDealt)

print("== Case 2: 无盾目标（raw=20, shield=0, hp=100）")
local r2_old   = simulatePlayerShot_OLD(20, 0, 100)
local r2_fixed = simulatePlayerShot_FIXED(20, 0, 100)
assertEq("OLD:   targetHealth=80?",  80, r2_old.targetHealth)
assertEq("OLD:   dmgDealt=20?",       20, r2_old.dmgDealt)
assertEq("FIXED: targetHealth=80?",  80, r2_fixed.targetHealth)
assertEq("FIXED: dmgDealt=20?",       20, r2_fixed.dmgDealt)

print("== Case 3: 盾大于伤害（raw=10, shield=100, hp=50）")
local r3_old   = simulatePlayerShot_OLD(10, 100, 50)
local r3_fixed = simulatePlayerShot_FIXED(10, 100, 50)
assertEq("OLD:   targetHealth should be 50 (no HP dmg)",   50, r3_old.targetHealth)
assertEq("OLD:   dmgDealt should be 0 (old uses raw 10 → fails as bug repro)", 0, r3_old.dmgDealt)
assertEq("FIXED: targetHealth=50?",  50, r3_fixed.targetHealth)
assertEq("FIXED: dmgDealt=0?",        0, r3_fixed.dmgDealt)

print("")
print(string.format("Result: %d passed, %d failed", passed, failed))
print("(Case 1 & 3 的 OLD 版本预期失败，用于复现 bug；FIXED 版本应全部通过。)")
if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
