# 经济系统深度设计

> 游戏经济系统的完整设计框架，涵盖双货币系统、通胀防御、多人市场动态。

---

## 1. 水龙头-水槽建模三步法

### 步骤一：绘制流动图

列出游戏中所有资源，标记每个资源的来源（水龙头）和去处（水槽）：

```
                    ┌─── 关卡通关奖励
                    ├─── 每日任务
    [金币 水龙头] ──┤
                    ├─── 击杀怪物
                    └─── 成就奖励

                    ┌─── 武器购买
                    ├─── 装备强化
    [金币 水槽] ────┤
                    ├─── 消耗品购买
                    └─── 修理/传送费
```

### 步骤二：量化每小时流量

为三类玩家建模：

```lua
-- 三类玩家的每小时资源流量
local player_profiles = {
    casual = {
        play_hours_per_day = 0.5,
        efficiency = 0.5,     -- 只获得理论最大值的50%
        spend_ratio = 0.3,    -- 只花掉收入的30%
    },
    median = {
        play_hours_per_day = 1.5,
        efficiency = 0.75,
        spend_ratio = 0.65,
    },
    hardcore = {
        play_hours_per_day = 4.0,
        efficiency = 0.95,
        spend_ratio = 0.80,
    },
}

--- 计算指定玩家类型N天后的资源存量
---@param profile table 玩家画像
---@param base_earn number 理论每小时产出
---@param days integer 天数
---@return number stock 资源存量
local function simulate_stock(profile, base_earn, days)
    local daily_earn = base_earn * profile.efficiency * profile.play_hours_per_day
    local daily_spend = daily_earn * profile.spend_ratio
    local net_daily = daily_earn - daily_spend
    return net_daily * days
end

-- 模拟30天后的金币存量
-- 休闲: simulate_stock(casual, 300, 30)    = 1575
-- 中位: simulate_stock(median, 300, 30)    = 4134
-- 硬核: simulate_stock(hardcore, 300, 30)  = 6840
```

### 步骤三：模拟关键时间节点

检查以下时间节点的玩家状态：

| 时间节点 | 检查项 | 健康标准 |
|---------|--------|---------|
| 第1小时 | 玩家能买到第一件有用物品吗？ | 是 |
| 第1天 | 玩家是否感到进步？ | 明显的装备/能力提升 |
| 第1周 | 休闲玩家是否被甩开太远？ | 与中位差距 < 2倍 |
| 第1月 | 经济是否出现通胀？ | 物价稳定或缓慢上涨 |

---

## 2. 双货币系统

### 软货币 vs 硬货币

```lua
local CurrencySystem = {
    soft = {
        name = "金币",
        sources = { "gameplay", "quests", "drops" },   -- 游戏内获取
        sinks = { "basic_gear", "consumables", "repair" },
        earn_rate = 300,  -- 每小时
    },
    hard = {
        name = "钻石",
        sources = { "purchase", "achievement", "daily_reward" },  -- 主要付费
        sinks = { "premium_gear", "cosmetics", "speed_up" },
        earn_rate_free = 5,   -- 免费每小时
        earn_rate_paid = 100, -- 付费换算
    },
}
```

### 汇率管理

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| 固定汇率 | 1钻石 = 100金币（不变） | 简单游戏 |
| 浮动汇率 | 根据供需动态调整 | MMO/有交易系统的游戏 |
| 混合模式 | 设置汇率上下限的浮动 | 推荐大多数游戏 |

```lua
--- 混合汇率：有上下限的浮动汇率
---@param base_rate number 基准汇率
---@param supply number 当前流通量
---@param demand number 当前需求量
---@param floor_rate number 最低汇率
---@param ceil_rate number 最高汇率
---@return number exchange_rate
local function hybrid_exchange_rate(base_rate, supply, demand, floor_rate, ceil_rate)
    local market_rate = base_rate * (demand / math.max(supply, 1))
    return math.max(floor_rate, math.min(ceil_rate, market_rate))
end
```

---

## 3. 通胀防御机制

### 3.1 有界货币

```lua
local MAX_GOLD = 999999

local function add_gold(current, amount)
    return math.min(current + amount, MAX_GOLD)
end
```

### 3.2 递减重复收益

```lua
--- 同一来源重复获取时递减奖励
---@param base_reward number 基础奖励
---@param repeat_count integer 已重复次数
---@param decay_rate number 衰减率（默认0.8）
---@param min_ratio number 最低比例（默认0.1）
---@return number actual_reward
local function diminishing_reward(base_reward, repeat_count, decay_rate, min_ratio)
    decay_rate = decay_rate or 0.8
    min_ratio = min_ratio or 0.1
    local ratio = math.max(min_ratio, decay_rate ^ repeat_count)
    return math.floor(base_reward * ratio)
end

-- 示例：反复刷同一关
-- 第1次: 100, 第2次: 80, 第3次: 64, 第4次: 51, ...最低: 10
```

### 3.3 渐进税收（高额交易）

```lua
--- 交易税（累进制）
local tax_brackets = {
    { threshold = 0,     rate = 0.05 },  -- 0~999:   5%
    { threshold = 1000,  rate = 0.10 },  -- 1000~:  10%
    { threshold = 10000, rate = 0.15 },  -- 10000~: 15%
}

local function calculate_tax(amount)
    local tax = 0
    local remaining = amount
    for i = #tax_brackets, 1, -1 do
        local bracket = tax_brackets[i]
        if remaining > bracket.threshold then
            local taxable = remaining - bracket.threshold
            tax = tax + taxable * bracket.rate
            remaining = bracket.threshold
        end
    end
    return math.floor(tax)
end
```

---

## 4. 多人经济特殊考量

### 问题与对策

| 问题 | 影响 | 对策 |
|------|------|------|
| 刷金脚本/外挂 | 通货膨胀 | 行为检测 + 每日获取上限 |
| 市场操纵 | 价格失控 | 设置价格区间限制 |
| 新老玩家差距 | 新手流失 | 追赶机制 + 绑定装备 |
| RMT（真钱交易） | 经济体系崩溃 | 绑定系统 + 交易冷却 |

### 追赶机制设计

```lua
--- 追赶经验加成：等级越低于服务器中位数，经验加成越高
---@param player_level integer 玩家等级
---@param server_median_level integer 服务器中位等级
---@param max_bonus number 最大加成倍率（默认3.0）
---@return number xp_multiplier
local function catchup_multiplier(player_level, server_median_level, max_bonus)
    max_bonus = max_bonus or 3.0
    if player_level >= server_median_level then
        return 1.0
    end
    local gap_ratio = (server_median_level - player_level) / server_median_level
    return 1.0 + (max_bonus - 1.0) * gap_ratio
end

-- 服务器中位50级，玩家10级 → 经验 ×2.6
-- 服务器中位50级，玩家45级 → 经验 ×1.2
```

---

## 5. 经济健康监控仪表板

设计一个运行时监控模块：

```lua
-- scripts/balance/economy_monitor.lua

local EconomyMonitor = {
    -- 按时间窗口记录
    window_earned = 0,
    window_spent = 0,
    window_start = 0,
    window_size = 300,  -- 5分钟窗口
}

function EconomyMonitor:record_earn(amount)
    self.window_earned = self.window_earned + amount
end

function EconomyMonitor:record_spend(amount)
    self.window_spent = self.window_spent + amount
end

function EconomyMonitor:get_velocity()
    if self.window_earned == 0 then return 0 end
    return self.window_spent / self.window_earned
end

function EconomyMonitor:check_health()
    local v = self:get_velocity()
    if v < 0.5 then return "WARNING", "玩家囤积资源，需增加消耗项" end
    if v > 0.9 then return "WARNING", "玩家资源紧张，需增加产出或降价" end
    return "HEALTHY", string.format("经济流速 %.2f（健康范围 0.6-0.85）", v)
end

function EconomyMonitor:reset_window()
    self.window_earned = 0
    self.window_spent = 0
end

return EconomyMonitor
```
