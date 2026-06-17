#!/usr/bin/env python3
# =============================================================================
# tests/test_battle_shield_stats.py
# 验证战斗中敌方有护盾时，玩家总伤害统计（dmgDealt）
# 等于敌方总生命值损失（即：盾吸收部分不计入 dmgDealt）。
#
# 复现路径： scripts/game/battle/BattleAI.lua 中
#   function BattleAI.UpdatePlayerFleet(dt)  → 玩家射击路径
#   当前存在 Bug： battleStats_.dmgDealt += dmg（raw）
#   而不是 battleStats_.dmgDealt += actualDmg（扣除盾吸收后）
#
# 触发场景： 玩家舰（dmg=20）射击 1 只敌方舰（shield=10，hp=100）。
#   - 正确： absorbed=10, actualDmg=10, dmgDealt=10, 敌方 hp=90
#   - Bug：  dmgDealt=20（虚高，盾吸收的 10 被重复计入伤害统计）
#
# 运行：   python3 scripts/tests/test_battle_shield_stats.py
# =============================================================================

import sys

def simulate_shot(raw_dmg, target_shield, target_health, use_fix=True):
    """最小化提取的单次射击结算。"""
    actual_dmg = raw_dmg
    if target_shield and target_shield > 0:
        absorbed = min(target_shield, raw_dmg)
        target_shield = target_shield - absorbed
        actual_dmg = raw_dmg - absorbed
    target_health = target_health - actual_dmg
    dmg_dealt = actual_dmg if use_fix else raw_dmg  # ← Bug 在这里
    return {
        "target_health": target_health,
        "target_shield": target_shield,
        "actual_dmg": actual_dmg,
        "dmg_dealt": dmg_dealt,
    }

PASSED = 0
FAILED = 0

def check(label, expected, got):
    global PASSED, FAILED
    ok = expected == got
    if ok:
        PASSED += 1
        print(f"  [PASS] {label}: expected={expected} got={got}")
    else:
        FAILED += 1
        print(f"  [FAIL] {label}: expected={expected} got={got}")

# ---- Case 1: 部分盾吸收，扣血
print("Case 1: raw=20, shield=10, hp=100")
r_old   = simulate_shot(20, 10, 100, use_fix=False)
r_fixed = simulate_shot(20, 10, 100, use_fix=True)
check("OLD: dmgDealt (bug repro) should be 10, but old code returns 20 → expect fail",
      10, r_old["dmg_dealt"])
check("FIXED: target_health == 90?", 90, r_fixed["target_health"])
check("FIXED: target_shield == 0?",  0, r_fixed["target_shield"])
check("FIXED: dmg_dealt == 10?",     10, r_fixed["dmg_dealt"])

# ---- Case 2: 无盾，全额扣血
print("Case 2: raw=20, shield=0, hp=100")
r_old   = simulate_shot(20, 0, 100, use_fix=False)
r_fixed = simulate_shot(20, 0, 100, use_fix=True)
check("OLD:   target_health == 80?", 80, r_old["target_health"])
check("OLD:   dmg_dealt == 20?",     20, r_old["dmg_dealt"])
check("FIXED: target_health == 80?", 80, r_fixed["target_health"])
check("FIXED: dmg_dealt == 20?",     20, r_fixed["dmg_dealt"])

# ---- Case 3: 盾完全吸收伤害，无扣血
print("Case 3: raw=10, shield=100, hp=50")
r_old   = simulate_shot(10, 100, 50, use_fix=False)
r_fixed = simulate_shot(10, 100, 50, use_fix=True)
check("OLD:   target_health == 50?", 50, r_old["target_health"])
check("OLD:   dmg_dealt should be 0 (but old returns 10 → repro)", 0, r_old["dmg_dealt"])
check("FIXED: target_health == 50?", 50, r_fixed["target_health"])
check("FIXED: target_shield == 90?", 90, r_fixed["target_shield"])
check("FIXED: dmg_dealt == 0?",       0, r_fixed["dmg_dealt"])

# ---- Case 4: 穿甲弹（isPierce），忽略护盾
# 这是现有 BattleAI.lua:840 分支： isPierce 为 true 时不会进入护盾分支，
# actualDmg == rawDmg。两种实现在此场景一致。
print("Case 4: raw=30, shield=100, hp=50 (isPierce: no shield branch)")
# 在 Lua 中走 "if target.shield and target.shield > 0 and not isPierce then"
# 当 isPierce=true → 不进入盾吸收分支 → actualDmg = rawDmg = 30
# 模拟： 我们传 shield=0（等价： isPierce=true 时 shield 被忽略）
r_fixed = simulate_shot(30, 0, 50, use_fix=True)
check("FIXED: target_health == 20?", 20, r_fixed["target_health"])
check("FIXED: dmg_dealt == 30?",     30, r_fixed["dmg_dealt"])

print()
print(f"Result: {PASSED} passed, {FAILED} failed")
print("(Case 1 & 3 中的 OLD 断言按设计失败，用于复现 bug。)")

sys.exit(0 if FAILED == 0 else 1)
