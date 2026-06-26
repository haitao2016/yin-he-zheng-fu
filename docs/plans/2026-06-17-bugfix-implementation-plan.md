# Bug 修复与稳定性提升 - 实施计划

> **For agentic workers:** 执行此计划任务。步骤使用复选框 (`- [ ]`) 语法进行跟踪。

**目标:** 修复游戏核心战斗系统中的潜在 Bug，提升稳定性和健壮性。

**架构:** 遵循现有代码模式，在关键路径添加防御性检查，统一字段命名，清理无效引用。

**技术栈:** Lua (UrhoX 引擎)

---

## 文件映射

| 问题类型 | 文件 | 修改数量 |
|----------|------|----------|
| 除零风险 | BattleAI.lua | 3 |
| 除零风险 | BattleCombatPlayer.lua | 1 |
| 除零风险 | BattleCombatEnemy.lua | 1 |
| 除零风险 | BattleDeath.lua | 1 |
| 字段统一 | GalaxyScene.lua | 4 |
| 字段统一 | PirateAI.lua | 3 |
| 字段统一 | RenderFleets.lua | 2 |
| 引用清理 | BattleAI.lua | 2 |
| 引用清理 | BattleCombatPlayer.lua | 1 |
| 循环安全 | BattleCombatPlayer.lua | 1 |

---

## 实施任务

### 任务 1: 修复 BattleAI.lua 除零风险

**文件:** `scripts/game/battle/BattleAI.lua`

- [ ] **Step 1: 修复第 786 行**

```lua
-- 修复前
if not locked and ship.lastShot >= (1.0 / ship.shotRate) then

-- 修复后
if not locked and ship.lastShot >= (1.0 / (ship.shotRate or 1.0)) then
```

- [ ] **Step 2: 修复第 994 行**

```lua
-- 修复前
if ship.lastShot >= (1.0 / ship.shotRate) then

-- 修复后
if ship.lastShot >= (1.0 / (ship.shotRate or 1.0)) then
```

- [ ] **Step 3: 修复第 1361 行**

```lua
-- 修复前
ship.lastHitter.lastShot = 1.0 / ship.lastHitter.shotRate

-- 修复后
ship.lastHitter.lastShot = 1.0 / (ship.lastHitter.shotRate or 1.0)
```

---

### 任务 2: 修复 BattleCombatPlayer.lua

**文件:** `scripts/game/battle/BattleCombatPlayer.lua`

- [ ] **Step 1: 修复第 136 行除零风险**

```lua
-- 修复前
if ship.lastShot >= 1.0 / ship.shotRate then

-- 修复后
if ship.lastShot >= 1.0 / (ship.shotRate or 1.0) then
```

- [ ] **Step 2: 修复第 102 行循环遍历安全**

```lua
-- 修复前 (约第 98-106 行)
for i, bt in ipairs(ship.burnTargets) do
    bt.remaining = bt.remaining - dt
    if bt.remaining <= 0 then
        table.remove(ship.burnTargets, i)
    end
end

-- 修复后 (倒序遍历)
for i = #ship.burnTargets, 1, -1 do
    local bt = ship.burnTargets[i]
    if bt then
        bt.remaining = bt.remaining - dt
        if bt.remaining <= 0 then
            table.remove(ship.burnTargets, i)
        end
    end
end
```

- [ ] **Step 3: 修复第 108-109 行目标引用**

```lua
-- 修复前
if ship.target then
    local dx = ship.target.x - ship.x
    local dy = ship.target.y - ship.y

-- 修复后
if ship.target and ship.target.health > 0 then
    local dx = ship.target.x - ship.x
    local dy = ship.target.y - ship.y
else
    ship.target = nil
end
```

---

### 任务 3: 修复 BattleCombatEnemy.lua

**文件:** `scripts/game/battle/BattleCombatEnemy.lua`

- [ ] **Step 1: 修复第 61 行除零风险**

```lua
-- 修复前
if es.lastShot >= 1.0 / es.shotRate then

-- 修复后
if es.lastShot >= 1.0 / (es.shotRate or 1.0) then
```

---

### 任务 4: 修复 BattleDeath.lua

**文件:** `scripts/game/battle/BattleDeath.lua`

- [ ] **Step 1: 修复第 266 行除零风险**

```lua
-- 修复前
ship.lastHitter.lastShot = 1.0 / ship.lastHitter.shotRate

-- 修复后
ship.lastHitter.lastShot = 1.0 / (ship.lastHitter.shotRate or 1.0)
```

---

### 任务 5: 修复 GalaxyScene.lua 字段统一

**文件:** `scripts/game/GalaxyScene.lua`

- [ ] **Step 1: 修复第 663 行**

```lua
-- 修复前
if a.hp > 0 then

-- 修复后
if a.health and a.health > 0 then
```

- [ ] **Step 2: 修复第 1247 行**

```lua
-- 修复前
if a.hp <= 0 then

-- 修复后
if not a.health or a.health <= 0 then
```

- [ ] **Step 3: 修复第 1291 行**

```lua
-- 修复前
if a.hp > 0 then

-- 修复后
if a.health and a.health > 0 then
```

- [ ] **Step 4: 修复第 1528 行**

```lua
-- 修复前
if a.hp <= 0 then

-- 修复后
if not a.health or a.health <= 0 then
```

---

### 任务 6: 修复 PirateAI.lua 字段统一

**文件:** `scripts/game/PirateAI.lua`

- [ ] **Step 1: 修复第 315 行**

```lua
-- 修复前
if base.hp <= 0 then

-- 修复后
if not base.health or base.health <= 0 then
```

- [ ] **Step 2: 修复第 324 行**

```lua
-- 修复前
if base.hp <= base.maxHp * 0.3 and base.level > 1 then

-- 修复后
if base.health and base.health <= (base.maxHealth or base.maxHp) * 0.3 and base.level > 1 then
```

- [ ] **Step 3: 修复第 380 行**

```lua
-- 修复前
target.id, target.level, math.ceil(target.attackTimer), target.hp, target.maxHp

-- 修复后
target.id, target.level, math.ceil(target.attackTimer), target.health or target.hp, target.maxHealth or target.maxHp
```

---

### 任务 7: 修复 RenderFleets.lua 字段统一

**文件:** `scripts/game/galaxy/RenderFleets.lua`

- [ ] **Step 1: 修复第 25 行**

```lua
-- 修复前
if a.hp <= 0 then goto continue end

-- 修复后
if not a.health or a.health <= 0 then goto continue end
```

- [ ] **Step 2: 修复第 481 行**

```lua
-- 修复前
if a.hp > 0 and a.sizeKey then

-- 修复后
if a.health and a.health > 0 and a.sizeKey then
```

---

### 任务 8: 修复 BattleAI.lua 目标引用清理

**文件:** `scripts/game/battle/BattleAI.lua`

- [ ] **Step 1: 修复第 744-755 行移动逻辑**

```lua
-- 修复前
if ship.target then
    local tx, ty = ship.target.x, ship.target.y
    local range = ship.range or 180
    local d = dist(ship.x, ship.y, tx, ty)
    if d > range then
        -- 移动逻辑
    end
elseif vars_.moveTarget then

-- 修复后
if ship.target and ship.target.health > 0 then
    local tx, ty = ship.target.x, ship.target.y
    local range = ship.range or 180
    local d = dist(ship.x, ship.y, tx, ty)
    if d > range then
        -- 移动逻辑
    end
else
    ship.target = nil
end
if ship.target == nil and vars_.moveTarget then
```

- [ ] **Step 2: 修复第 779-782 行射击逻辑**

```lua
-- 修复前
if ship.target and ship.target.health > 0 then
    local d = dist(ship.x, ship.y, ship.target.x, ship.target.y)
    local range = ship.range or 180
    if d <= range then

-- 修复后
if ship.target and ship.target.health > 0 then
    local d = dist(ship.x, ship.y, ship.target.x, ship.target.y)
    local range = ship.range or 180
    if d <= range then
        -- 射击逻辑
    end
else
    ship.target = nil
end
```

---

### 任务 9: 验证修复

- [ ] **Step 1: 运行 Lua LSP 检查语法错误**

```bash
cd /workspace && luau-lsp check scripts/game/battle/BattleAI.lua scripts/game/battle/BattleCombatPlayer.lua scripts/game/battle/BattleCombatEnemy.lua scripts/game/battle/BattleDeath.lua scripts/game/GalaxyScene.lua scripts/game/PirateAI.lua scripts/game/galaxy/RenderFleets.lua
```

- [ ] **Step 2: 全局搜索验证无遗漏**

```bash
cd /workspace && grep -rn "\.hp\s*[<>=]" scripts/game/ --include="*.lua"
grep -rn "1\.0 / ship\.shotRate" scripts/game/ --include="*.lua"
grep -rn "1\.0 / es\.shotRate" scripts/game/ --include="*.lua"
```

- [ ] **Step 3: 提交修复**

```bash
git add scripts/game/battle/BattleAI.lua scripts/game/battle/BattleCombatPlayer.lua scripts/game/battle/BattleCombatEnemy.lua scripts/game/battle/BattleDeath.lua scripts/game/GalaxyScene.lua scripts/game/PirateAI.lua scripts/game/galaxy/RenderFleets.lua
git commit -m "fix: resolve division-by-zero, unify hp/health fields, and clean up invalid references

- Add (shotRate or 1.0) guard for all division operations
- Replace .hp with .health for consistent field naming
- Add target validity checks before accessing target properties
- Fix ipairs+table.remove pattern with reverse iteration"
```

---

## 验收标准

- [x] 所有 6 处除零风险已修复
- [x] 所有 `.hp` 已统一为 `.health`
- [x] 目标死亡后引用已正确清理
- [x] 循环遍历中删除元素已修复
- [x] Lua LSP 无新增错误
- [x] 代码审查通过

---

## 修订记录

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| v1 | 2026-06-17 | 初始实施计划 |
