# Bug 修复与稳定性提升 - 设计文档

> 创建时间: 2026-06-17
> 状态: 待审核

---

## 1. 问题概述

本次修复聚焦于游戏核心战斗系统和银河场景中的潜在 Bug 和稳定性问题，确保游戏在高强度战斗和长时间运行中的稳定性。

### 1.1 修复范围

| 优先级 | 问题类型 | 影响文件 | 预估修改量 |
|--------|----------|----------|-----------|
| **高** | 除零风险 | BattleAI.lua, BattleCombatPlayer.lua, BattleCombatEnemy.lua | ~8 处 |
| **高** | hp/health 字段不一致 | GalaxyScene.lua, PirateAI.lua 等 | ~6 处 |
| **高** | 目标死亡后未清除引用 | BattleAI.lua 等 | ~4 处 |
| **中** | 循环遍历中修改数组 | BattleDeath.lua 等 | ~3 处 |
| **低** | 边界条件不完善 | 多个文件 | ~5 处 |

---

## 2. 问题详细分析

### 2.1 高优先级：除零风险

**问题描述**：
在多个战斗文件中，代码使用 `1.0 / ship.shotRate` 计算射击间隔，但未检查 `shotRate` 是否为零。虽然 `shotRate` 在舰船创建时通常有默认值，但在极端情况下仍可能为零或极小值。

**受影响位置**：

| 文件 | 行号 | 代码 |
|------|------|------|
| BattleAI.lua | 786 | `if ship.lastShot >= (1.0 / ship.shotRate)` |
| BattleAI.lua | 994 | `if ship.lastShot >= (1.0 / ship.shotRate)` |
| BattleAI.lua | 1361 | `ship.lastHitter.lastShot = 1.0 / ship.lastHitter.shotRate` |
| BattleCombatPlayer.lua | 136 | `if ship.lastShot >= 1.0 / ship.shotRate` |
| BattleCombatEnemy.lua | 61 | `if es.lastShot >= 1.0 / es.shotRate` |
| BattleDeath.lua | 266 | `ship.lastHitter.lastShot = 1.0 / ship.lastHitter.shotRate` |

**修复方案**：
在所有除法运算前添加 `(shotRate or 1.0)` 保底值，确保分母不为零：
```lua
-- 修复前
if ship.lastShot >= (1.0 / ship.shotRate) then

-- 修复后
if ship.lastShot >= (1.0 / (ship.shotRate or 1.0)) then
```

---

### 2.2 高优先级：hp/health 字段不一致

**问题描述**：
代码库中存在字段命名不一致：某些地方使用 `.hp`，某些地方使用 `.health`。这种不一致可能导致某些情况下读取到错误的值或 nil 错误。

**受影响位置**：

| 文件 | 行号 | 字段 | 说明 |
|------|------|------|------|
| GalaxyScene.lua | 663 | `a.hp` | 应该是 `a.health` |
| GalaxyScene.lua | 1247 | `a.hp` | 应该是 `a.health` |
| GalaxyScene.lua | 1291 | `a.hp` | 应该是 `a.health` |
| GalaxyScene.lua | 1528 | `a.hp` | 应该是 `a.health` |
| GalaxyEvents.lua | 1076-1086 | `target.x/y` | 可能引用错误对象 |
| PirateAI.lua | 380 | `target.hp` | 应该是 `target.health` |
| PirateAI.lua | 315, 324 | `base.hp` | 应该是 `base.health` |
| galaxy/RenderFleets.lua | 25, 481 | `a.hp` | 应该是 `a.health` |

**修复方案**：
将所有 `.hp` 引用统一为 `.health`，确保命名一致。

---

### 2.3 高优先级：目标死亡后未清除引用

**问题描述**：
当目标舰船死亡后，其他舰船的 `ship.target` 引用可能仍然指向该死亡对象，导致后续代码尝试访问已删除对象的属性时出错。

**受影响位置**：

| 文件 | 行号 | 问题 |
|------|------|------|
| BattleAI.lua | 745 | `local tx, ty = ship.target.x, ship.target.y` - 可能在目标死亡后执行 |
| BattleAI.lua | 780 | `dist(ship.x, ship.y, ship.target.x, ship.target.y)` - 可能使用已死亡目标 |
| BattleCombatPlayer.lua | 108-109 | `ship.target.x/y` - 移动逻辑可能使用已死亡目标 |

**修复方案**：
在射击和移动逻辑之前，检查目标是否存在且健康：
```lua
-- 修复前
if ship.target then
    local tx, ty = ship.target.x, ship.target.y
    ...

-- 修复后
if ship.target and ship.target.health > 0 then
    local tx, ty = ship.target.x, ship.target.y
    ...
else
    ship.target = nil  -- 清除无效引用
end
```

---

### 2.4 中优先级：循环遍历中修改数组

**问题描述**：
某些地方在 `ipairs` 遍历过程中使用 `table.remove` 删除元素，这可能导致跳元素或访问已删除位置的问题。

**受影响位置**：

| 文件 | 行号 | 问题 |
|------|------|------|
| BattleCombatPlayer.lua | 102 | `table.remove(ship.burnTargets, i)` 在 ipairs 遍历中 |

**修复方案**：
使用倒序遍历或先收集待删除索引再统一处理：
```lua
-- 修复方案：使用倒序遍历
for i = #ship.burnTargets, 1, -1 do
    local bt = ship.burnTargets[i]
    bt.remaining = bt.remaining - dt
    if bt.remaining <= 0 then
        table.remove(ship.burnTargets, i)
    end
end
```

---

### 2.5 低优先级：边界条件不完善

**问题描述**：
某些边界条件检查不完善，可能导致异常值进入计算流程。

**受影响位置**：
- 某些距离计算未检查是否为负数
- 某些生命值操作未确保不超出最大值/最小值

**修复方案**：
添加适当的边界检查和 `clamp` 操作。

---

## 3. 实施计划

### 阶段一：修复除零风险
1. 修复 BattleAI.lua 中的 3 处
2. 修复 BattleCombatPlayer.lua 中的 1 处
3. 修复 BattleCombatEnemy.lua 中的 1 处
4. 修复 BattleDeath.lua 中的 1 处

### 阶段二：统一字段命名
1. 修复 GalaxyScene.lua 中的 4 处 `.hp`
2. 修复 PirateAI.lua 中的 3 处 `.hp`
3. 修复 RenderFleets.lua 中的 2 处 `.hp`

### 阶段三：清理无效引用
1. 在 BattleAI.lua 的移动和射击逻辑中添加目标有效性检查
2. 在 BattleCombatPlayer.lua 中添加目标有效性检查

### 阶段四：修复循环遍历
1. 修复 BattleCombatPlayer.lua 中的 table.remove 逻辑

### 阶段五：边界条件
1. 添加必要的边界检查

---

## 4. 验收标准

- [ ] 所有 8 处除零风险已修复
- [ ] 所有 `.hp` 已统一为 `.health`
- [ ] 目标死亡后引用已正确清理
- [ ] 循环遍历中删除元素已修复
- [ ] Lua LSP 无新增错误
- [ ] 代码审查通过

---

## 5. 风险评估

| 修复项 | 风险 | 缓解措施 |
|--------|------|----------|
| 字段重命名 | 中 | 确保所有引用点都被更新，使用全局搜索验证 |
| 引用清理 | 低 | 添加 nil 检查，确保向后兼容 |

---

## 6. 修订记录

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| v1 | 2026-06-17 | 初始设计文档 |
