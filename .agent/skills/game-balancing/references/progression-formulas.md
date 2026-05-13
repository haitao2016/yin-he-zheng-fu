# 进度公式完整集

> 所有数学公式均提供 Lua 实现，可直接用于 UrhoX 游戏项目。

---

## 1. 经验曲线对比

### 1.1 指数曲线（最常用）

```lua
--- 标准指数经验曲线
--- 特点：前期快升，后期稳定减速
---@param level integer 目标等级（1-based）
---@param base_xp number 基础经验（1→2级所需）
---@param exponent number 指数（推荐 1.5~2.5）
---@return number xp 该级所需经验
local function exponential_xp(level, base_xp, exponent)
    return math.floor(base_xp * level ^ exponent)
end

-- 不同指数的手感：
-- 1.5: 温和增长（休闲游戏）
-- 1.8: 中等增长（动作RPG）
-- 2.0: 快速增长（MMO）
-- 2.5: 极快增长（肝向游戏）
```

**典型数值表（base=100, exponent=1.8）**：

| 等级 | 升级所需 XP | 累计 XP | 若每小时200XP，需 |
|------|-----------|---------|------------------|
| 5    | 1,803     | 4,357   | ~22小时          |
| 10   | 6,310     | 25,119  | ~126小时         |
| 20   | 21,877    | 160,489 | ~802小时         |
| 30   | 44,306    | 473,789 | ~2369小时        |
| 50   | 104,713   | 1,878K  | ~9390小时        |

### 1.2 斐波那契曲线

```lua
--- 斐波那契经验曲线
--- 特点：自然增长感，前5级加速很快
---@param max_level integer 最大等级
---@param base_xp number 基础经验
---@return table xp_table 每级所需经验数组
local function fibonacci_xp_table(max_level, base_xp)
    local result = { base_xp, base_xp }
    for i = 3, max_level do
        result[i] = result[i-1] + result[i-2]
    end
    return result
end
```

### 1.3 阶梯曲线

```lua
--- 阶梯式经验曲线
--- 特点：同一阶段内升级速度相同，跨阶段时突然变慢
---@param level integer 目标等级
---@param base_xp number 基础经验
---@param step_size integer 每阶段包含的等级数（默认10）
---@param step_multiplier number 跨阶段倍率（默认2.0）
---@return number xp 该级所需经验
local function stepped_xp(level, base_xp, step_size, step_multiplier)
    step_size = step_size or 10
    step_multiplier = step_multiplier or 2.0
    local tier = math.floor((level - 1) / step_size)
    return math.floor(base_xp * (step_multiplier ^ tier))
end
```

### 1.4 对数曲线

```lua
--- 对数经验曲线
--- 特点：前期陡峭提升，后期非常平缓（适合休闲游戏）
---@param level integer 目标等级
---@param base_xp number 基础经验
---@param scale number 缩放系数（默认2.0）
---@return number xp 该级所需经验
local function logarithmic_xp(level, base_xp, scale)
    scale = scale or 2.0
    return math.floor(base_xp * math.log(level + 1) * scale)
end
```

### 选型指南

| 曲线类型 | 适合游戏类型 | 前期速度 | 后期速度 |
|---------|------------|---------|---------|
| 指数 1.5 | 休闲RPG、手游 | 快 | 较慢 |
| 指数 2.0 | MMO、硬核RPG | 快 | 很慢 |
| 斐波那契 | 独立游戏、Roguelike | 中 | 极快增长 |
| 阶梯 | 赛季制/章节制游戏 | 阶段内均匀 | 跨阶段跳跃 |
| 对数 | 超休闲、解谜 | 快 | 几乎持平 |

---

## 2. 能力值缩放完整集

### 2.1 线性缩放

```lua
--- 线性增长：每级固定增长值
--- 适用：基础属性（HP、MP）
---@param level integer
---@param base number 1级基础值
---@param growth number 每级增长量
---@return number stat
local function linear_stat(level, base, growth)
    return base + growth * (level - 1)
end

-- HP: linear_stat(50, 100, 20) = 100 + 20*49 = 1080
```

### 2.2 复合增长

```lua
--- 复合增长（百分比递增）
--- 适用：攻击力、技能伤害
---@param level integer
---@param base number 1级基础值
---@param rate number 每级增长率（如 0.05 = 5%）
---@return number stat
local function compound_stat(level, base, rate)
    return math.floor(base * (1 + rate) ^ (level - 1))
end

-- ATK: compound_stat(50, 10, 0.05) = 10 * 1.05^49 ≈ 109
```

### 2.3 递减收益

```lua
--- 递减收益（趋近上限）
--- 适用：暴击率、闪避率、抗性
---@param level integer
---@param max_value number 理论上限
---@param rate number 增长速度（如 0.05）
---@return number stat
local function diminishing_stat(level, max_value, rate)
    return math.floor(max_value * (1 - math.exp(-rate * level)))
end

-- 暴击率: diminishing_stat(50, 75, 0.04) = 75 * (1 - e^(-2)) ≈ 65%
-- 暴击率: diminishing_stat(100, 75, 0.04) = 75 * (1 - e^(-4)) ≈ 74%
```

### 2.4 S曲线（Sigmoid）

```lua
--- S曲线：前慢-中快-后慢
--- 适用：技能熟练度、解锁进度
---@param level integer
---@param max_value number 最大值
---@param midpoint number 拐点等级
---@param steepness number 陡峭度（默认0.1）
---@return number stat
local function sigmoid_stat(level, max_value, midpoint, steepness)
    steepness = steepness or 0.1
    return math.floor(max_value / (1 + math.exp(-steepness * (level - midpoint))))
end
```

---

## 3. 敌人缩放策略

### 3.1 固定等级（最简单）

每个区域的敌人有固定等级，不随玩家变化。

```lua
local zone_enemies = {
    forest    = { min_level = 1,  max_level = 10 },
    desert    = { min_level = 8,  max_level = 20 },
    volcano   = { min_level = 18, max_level = 30 },
    endgame   = { min_level = 28, max_level = 50 },
}
```

### 3.2 等级匹配

敌人等级跟随玩家，保持恒定挑战度。

```lua
--- 等级匹配缩放
---@param base_stat number 敌人基础属性
---@param player_level integer 玩家等级
---@param enemy_base_level integer 敌人设计等级
---@return number scaled_stat
local function level_matched(base_stat, player_level, enemy_base_level)
    local ratio = player_level / enemy_base_level
    return math.floor(base_stat * ratio)
end
```

### 3.3 区间缩放（推荐）

敌人有推荐等级范围，超出范围时有软限制。

```lua
--- 区间缩放
---@param base_stat number 敌人基础属性
---@param player_level integer 玩家等级
---@param center_level integer 敌人推荐等级
---@param min_scale number 最低缩放（默认0.7）
---@param max_scale number 最高缩放（默认1.3）
---@return number scaled_stat
local function bracket_scale(base_stat, player_level, center_level, min_scale, max_scale)
    min_scale = min_scale or 0.7
    max_scale = max_scale or 1.3
    local ratio = player_level / center_level
    local clamped = math.max(min_scale, math.min(max_scale, ratio))
    return math.floor(base_stat * clamped)
end

-- 敌人推荐等级20，基础HP=500
-- 玩家10级: bracket_scale(500, 10, 20) = 500 * max(0.7, 0.5) = 350
-- 玩家20级: bracket_scale(500, 20, 20) = 500 * 1.0 = 500
-- 玩家30级: bracket_scale(500, 30, 20) = 500 * min(1.3, 1.5) = 650
```

### 策略选型

| 策略 | 优点 | 缺点 | 适合 |
|------|------|------|------|
| 固定 | 简单、世界感强 | 回头碾压/前面碰壁 | 线性RPG |
| 等级匹配 | 始终有挑战 | 失去成长感 | 开放世界 |
| 区间缩放 | 平衡：有挑战又有成长感 | 实现稍复杂 | 大多数游戏（推荐） |

---

## 4. 转生/赛季循环（Prestige Loop）

```lua
--- 转生系统配置
local PrestigeConfig = {
    -- 每次转生获得的永久加成
    bonuses = {
        { prestige = 1,  xp_mult = 1.10, gold_mult = 1.05, unlock = "新皮肤" },
        { prestige = 2,  xp_mult = 1.25, gold_mult = 1.10, unlock = "新技能槽" },
        { prestige = 3,  xp_mult = 1.50, gold_mult = 1.20, unlock = "新难度模式" },
        { prestige = 5,  xp_mult = 2.00, gold_mult = 1.50, unlock = "特殊称号" },
        { prestige = 10, xp_mult = 3.00, gold_mult = 2.00, unlock = "隐藏结局" },
    },
}

--- 获取当前转生的加成
---@param prestige_count integer 已转生次数
---@return number xp_mult, number gold_mult
local function get_prestige_bonus(prestige_count)
    local xp_mult, gold_mult = 1.0, 1.0
    for _, bonus in ipairs(PrestigeConfig.bonuses) do
        if prestige_count >= bonus.prestige then
            xp_mult = bonus.xp_mult
            gold_mult = bonus.gold_mult
        end
    end
    return xp_mult, gold_mult
end

--- 转生重置逻辑
---@param player table 玩家数据
local function do_prestige(player)
    player.prestige = player.prestige + 1
    player.level = 1
    player.xp = 0
    player.gold = 0
    -- 保留：成就、收藏、转生货币
    -- 重置：等级、经验、普通货币、装备
end
```

### 转生循环设计检查清单

- [ ] 每次转生是否能在 2-4 小时内回到上次进度（加速感）？
- [ ] 转生奖励是否足够诱人？
- [ ] 是否有仅转生后可获取的独占内容？
- [ ] 转生次数是否有合理上限或递减收益？

---

## 5. 技能树平衡

### 节点定价公式

```lua
--- 技能树节点消耗计算
---@param base_cost number 基础消耗
---@param power_tier integer 技能强度等级（1=弱, 2=中, 3=强, 4=终极）
---@param depth integer 技能在树中的深度（从根到该节点的距离）
---@param depth_mult number 深度倍率（默认1.5）
---@return number cost
local function skill_node_cost(base_cost, power_tier, depth, depth_mult)
    depth_mult = depth_mult or 1.5
    return math.floor(base_cost * power_tier * (depth_mult ^ (depth - 1)))
end

-- 弱技能(tier=1), 深度1: 100 * 1 * 1.0 = 100
-- 中技能(tier=2), 深度2: 100 * 2 * 1.5 = 300
-- 强技能(tier=3), 深度3: 100 * 3 * 2.25 = 675
-- 终极(tier=4),   深度4: 100 * 4 * 3.375 = 1350
```

### 路径平衡验证

```lua
--- 验证多条技能路径的平衡性
--- 总消耗差异不应超过15%
---@param paths table { {cost1, cost2, ...}, {cost1, cost2, ...} }
---@return boolean balanced, number max_variance_pct
local function validate_paths(paths)
    local totals = {}
    for i, path in ipairs(paths) do
        local sum = 0
        for _, cost in ipairs(path) do
            sum = sum + cost
        end
        totals[i] = sum
    end

    local min_total = math.huge
    local max_total = 0
    for _, t in ipairs(totals) do
        min_total = math.min(min_total, t)
        max_total = math.max(max_total, t)
    end

    local variance = (max_total - min_total) / min_total * 100
    return variance <= 15, variance
end
```

### 洗点经济

```lua
--- 洗点消耗（随次数递增，防止频繁切换）
---@param respec_count integer 已洗点次数
---@param base_cost number 首次洗点费用
---@param max_cost number 费用上限
---@return number cost
local function respec_cost(respec_count, base_cost, max_cost)
    local cost = math.floor(base_cost * (1.5 ^ respec_count))
    return math.min(cost, max_cost)
end

-- 第1次: 100, 第2次: 150, 第3次: 225, 第4次: 337, ..., 上限: 5000
```
