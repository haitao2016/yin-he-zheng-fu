---
name: game-balancing
description: >-
  Game balance design toolkit for UrhoX Lua games. Provides economy modeling
  (sink/faucet analysis, dual currencies, inflation prevention), progression
  formulas (XP curves, power scaling, prestige loops), difficulty curve design
  (linear, logarithmic, sawtooth patterns), loot table implementation with
  pity systems, and playtesting methodology with statistical metrics. Includes
  ready-to-use Lua code for all mathematical models. Use when designing or
  tuning game economies, level progression, drop rates, difficulty curves,
  enemy scaling, or analyzing playtest data for balance improvements.
---

# Game Balancing — UrhoX Lua 游戏数值平衡设计

> 为 UrhoX Lua 游戏提供完整的数值平衡设计工具箱：经济建模、进度公式、难度曲线、掉落表、测试方法论。

---

## 触发条件

**MUST trigger when:**
1. 用户需要设计游戏经济系统（货币、商店、交易）
2. 用户需要设计等级/经验/成长曲线
3. 用户需要设计掉落概率/战利品表
4. 用户需要调整游戏难度曲线
5. 用户需要敌人/怪物数值缩放策略
6. 用户需要分析游戏平衡数据或设计测试方案
7. 用户提到"数值策划"、"平衡"、"经济系统"、"掉落率"、"经验曲线"

**SKIP when:**
- 用户只需要 UI 布局/渲染/物理碰撞等非数值问题
- 用户需要的是游戏架构设计（→ `game-design-patterns`）
- 用户需要的是完整游戏创建流程（→ `game-creation-workflow`）
- 用户需要的是卡牌游戏专用数值框架（→ `@tianyi_card-game-numerical-framework`）

---

## 五大核心原则

| # | 原则 | 说明 |
|---|------|------|
| 1 | **水龙头-水槽平衡** | 资源产出（水龙头）与消耗（水槽）必须长期均衡 |
| 2 | **中位数玩家优先** | 先为中等水平玩家调好体验，再调节两端 |
| 3 | **进度感来自体验而非数值** | 玩家感受到的成长 > 实际数值增长 |
| 4 | **数据驱动迭代** | 每次调整基于测试数据，不靠直觉 |
| 5 | **小步修改** | 单次调整不超过 ±15%，避免过度矫正 |

---

## 1. 经济系统设计

### 1.1 水龙头-水槽模型

任何游戏经济都可以抽象为三层：

```
水龙头（Faucets）     库存（Stocks）      水槽（Sinks）
━━━━━━━━━━━━━━    ━━━━━━━━━━━━    ━━━━━━━━━━━━
 关卡奖励 ───────→  玩家金币  ───────→  商店购买
 日常任务 ───────→  玩家金币  ───────→  装备强化
 击杀怪物 ───────→  玩家金币  ───────→  消耗品
```

### 1.2 经济审计表

设计经济系统时，填写以下审计表：

| 资源名 | 水龙头（来源） | 每小时产出 | 水槽（去处） | 每小时消耗 | 净流量 |
|--------|---------------|-----------|-------------|-----------|-------|
| 金币   | 关卡/任务/掉落 | 300       | 商店/强化/修理 | 250      | +50   |
| 宝石   | 成就/日常      | 5         | 抽卡/加速    | 4         | +1    |

**健康净流量**：轻微正值（+5%~+15%），让玩家感到积累但不爆仓。

### 1.3 三类玩家每小时资源产出

```lua
-- scripts/balance/economy.lua
local EconomyConfig = {
    -- 三类玩家的每小时金币产出
    hourly_earn = {
        casual   = 150,   -- 休闲玩家（效率最低）
        median   = 300,   -- 中位数玩家（平衡基准）
        hardcore = 500,   -- 硬核玩家（效率最高）
    },
    -- 核心消费项定价（以中位数玩家为基准）
    prices = {
        basic_weapon    = 300 * 2,    -- 2小时可得
        mid_weapon      = 300 * 8,    -- 8小时可得
        endgame_weapon  = 300 * 40,   -- 40小时可得
    },
}
return EconomyConfig
```

### 1.4 通胀预防策略

| 策略 | Lua 实现思路 |
|------|-------------|
| 上限货币 | `gold = math.min(gold + earned, MAX_GOLD)` |
| 衰减/税收 | 每日登录时 `gold = math.floor(gold * 0.99)` |
| 递减收益 | 同一关卡重复刷金递减 `reward * (0.8 ^ repeat_count)` |
| 伪装水槽 | 修理费、传送费等"隐性消耗" |

### 1.5 经济健康指标

| 指标 | 公式 | 健康范围 | 异常时操作 |
|------|------|---------|-----------|
| 经济流速 | 消耗 / 产出 | 0.6 – 0.85 | < 0.6 加水槽；> 0.85 加水龙头 |
| 基尼系数 | 玩家资源分布不均匀度 | < 0.4 | > 0.4 加保底/追赶机制 |
| 存量中位数 | 中位玩家拥有的资源量 | 可买 2–5 个核心物品 | 偏低加产出，偏高加消耗 |

> 详见 → `references/economy-design.md`

---

## 2. 进度与成长公式

### 2.1 经验曲线

**核心公式**：
```lua
-- scripts/balance/progression.lua

--- 计算指定等级所需经验值
---@param level integer 目标等级
---@param base_xp number 基础经验值（1级→2级所需）
---@param exponent number 指数（推荐 1.5~2.5）
---@return number xp_required 该等级所需经验
local function xp_required(level, base_xp, exponent)
    return math.floor(base_xp * level ^ exponent)
end

--- 计算达到指定等级的累计总经验
---@param level integer 目标等级
---@param base_xp number 基础经验值
---@param exponent number 指数
---@return number total_xp
local function total_xp(level, base_xp, exponent)
    local sum = 0
    for lv = 1, level - 1 do
        sum = sum + xp_required(lv, base_xp, exponent)
    end
    return sum
end
```

**50级 RPG 示例**（base=100, exponent=1.8, 每小时获取200xp）：

| 等级 | 该级所需 XP | 累计 XP | 预计游戏时间(小时) |
|------|-----------|---------|------------------|
| 1→2  | 100       | 100     | 0.5              |
| 10   | 3,981     | ~16K    | ~80              |
| 25   | 19,036    | ~190K   | ~950             |
| 50   | 63,096    | ~1.1M   | ~5,500           |

### 2.2 替代曲线模型

```lua
--- 阶梯式（每10级一个台阶）
local function stepped_xp(level, base_xp, step_size, step_mult)
    step_size = step_size or 10
    step_mult = step_mult or 2.0
    local tier = math.floor((level - 1) / step_size)
    return math.floor(base_xp * (step_mult ^ tier))
end

--- 对数式（前期快升，后期平缓）
local function logarithmic_xp(level, base_xp, scale)
    scale = scale or 2.0
    return math.floor(base_xp * math.log(level + 1) * scale)
end

--- 斐波那契式（自然增长感）
local function fibonacci_xp(level, base_xp)
    if level <= 2 then return base_xp end
    local a, b = base_xp, base_xp
    for i = 3, level do
        a, b = b, a + b
    end
    return b
end
```

### 2.3 能力值缩放

```lua
--- 线性缩放：稳定、可预测
local function linear_power(level, base, growth)
    return base + growth * level
end

--- 复合增长：指数感、RPG 常用
local function compound_power(level, base, rate)
    return math.floor(base * (1 + rate) ^ level)
end

--- 递减收益：前期爽、后期稳定
local function diminishing_power(level, max_val, rate)
    return math.floor(max_val * (1 - math.exp(-rate * level)))
end
```

> 详见 → `references/progression-formulas.md`（含敌人缩放、转生循环、技能树平衡）

---

## 3. 难度曲线设计

### 3.1 四种难度曲线模型

```lua
-- scripts/balance/difficulty.lua

local DifficultyModels = {}

--- 线性：均匀增长，新手友好
function DifficultyModels.linear(level, base, increment)
    return base + increment * (level - 1)
end

--- 对数：前期快速提升，后期平缓
function DifficultyModels.logarithmic(level, base, scale)
    return base + scale * math.log(level)
end

--- 指数：后期急剧提升（硬核向）
function DifficultyModels.exponential(level, base, rate)
    return math.floor(base * (1 + rate) ^ (level - 1))
end

--- 锯齿波：每个"章节"内先易后难，章节切换时重置
function DifficultyModels.sawtooth(level, base, increment, chapter_size)
    chapter_size = chapter_size or 5
    local chapter = math.floor((level - 1) / chapter_size)
    local pos_in_chapter = (level - 1) % chapter_size
    local chapter_base = base + chapter * increment * chapter_size * 0.5
    return chapter_base + increment * pos_in_chapter
end

return DifficultyModels
```

### 3.2 锯齿波难度设计检查清单

锯齿波模式最常用于带"章节/世界"概念的游戏：

- [ ] 每个章节内难度递增是否平滑？
- [ ] 章节过渡时难度是否适当回落（新章节第一关比上一章节最后一关简单）？
- [ ] 每个章节是否引入了至少一个新机制？
- [ ] Boss 关卡是否处于章节末尾？
- [ ] 新章节开头是否作为新机制的教学关？

### 3.3 敌人数值缩放

```lua
--- 区间缩放：敌人有推荐等级范围，玩家等级偏离时有软限制
---@param base_stat number 敌人基础属性
---@param player_level integer 玩家等级
---@param center_level integer 敌人推荐等级
---@param min_scale number 最低缩放比（默认0.7）
---@param max_scale number 最高缩放比（默认1.3）
local function bracket_scale(base_stat, player_level, center_level, min_scale, max_scale)
    min_scale = min_scale or 0.7
    max_scale = max_scale or 1.3
    local ratio = player_level / center_level
    local scale = math.max(min_scale, math.min(max_scale, ratio))
    return math.floor(base_stat * scale)
end
```

---

## 4. 掉落表与保底系统

### 4.1 加权随机掉落

```lua
-- scripts/balance/loot.lua

local LootTable = {}
LootTable.__index = LootTable

--- 创建掉落表
---@param entries table[] { name, weight, ... } 数组
---@return table loot_table
function LootTable.new(entries)
    local self = setmetatable({}, LootTable)
    self.entries = entries
    self.total_weight = 0
    for _, entry in ipairs(entries) do
        self.total_weight = self.total_weight + entry.weight
    end
    return self
end

--- 随机抽取一个物品
---@return table entry 被选中的条目
function LootTable:roll()
    local roll = math.random() * self.total_weight
    local cumulative = 0
    for _, entry in ipairs(self.entries) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry
        end
    end
    return self.entries[#self.entries]  -- 兜底
end

-- 使用示例
local chest_loot = LootTable.new({
    { name = "金币袋",     rarity = "common",    weight = 60 },
    { name = "蓝色药水",   rarity = "uncommon",  weight = 25 },
    { name = "精钢剑",     rarity = "rare",      weight = 10 },
    { name = "龙鳞甲",     rarity = "epic",      weight = 4  },
    { name = "神器·天命",  rarity = "legendary", weight = 1  },
})

local item = chest_loot:roll()
```

### 4.2 保底系统（Pity Counter）

```lua
--- 带保底的掉落表
---@param loot_table table LootTable 实例
---@param pity_threshold integer 保底计数阈值
---@param guaranteed_rarity string 保底时给予的最低稀有度
local PityLoot = {}
PityLoot.__index = PityLoot

function PityLoot.new(loot_table, pity_threshold, guaranteed_rarity)
    local self = setmetatable({}, PityLoot)
    self.loot_table = loot_table
    self.pity_threshold = pity_threshold
    self.guaranteed_rarity = guaranteed_rarity
    self.pity_counter = 0
    return self
end

function PityLoot:roll()
    self.pity_counter = self.pity_counter + 1

    -- 达到保底阈值：强制给高稀有度物品
    if self.pity_counter >= self.pity_threshold then
        self.pity_counter = 0
        for _, entry in ipairs(self.loot_table.entries) do
            if entry.rarity == self.guaranteed_rarity then
                return entry
            end
        end
    end

    -- 正常抽取
    local item = self.loot_table:roll()

    -- 如果自然抽到高稀有度，重置计数器
    local rarity_rank = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
    if rarity_rank[item.rarity] and
       rarity_rank[item.rarity] >= (rarity_rank[self.guaranteed_rarity] or 3) then
        self.pity_counter = 0
    end

    return item
end

-- 使用：每50次必出 rare 或以上
local pity_chest = PityLoot.new(chest_loot, 50, "rare")
```

---

## 5. 测试与数据分析

### 5.1 核心平衡指标

在游戏中埋点并收集以下数据：

```lua
-- scripts/balance/metrics.lua

local Metrics = {
    -- 每关卡指标
    per_level = {
        completion_rate = 0,    -- 通关率（0~1）
        avg_attempts = 0,       -- 平均尝试次数
        avg_time = 0,           -- 平均通关时间（秒）
        avg_deaths = 0,         -- 平均死亡次数
    },
    -- 每会话指标
    per_session = {
        avg_session_length = 0, -- 平均会话时长（分钟）
        content_progressed = 0, -- 平均推进内容量
        resources_earned = 0,   -- 平均获取资源
        resources_spent = 0,    -- 平均消耗资源
    },
}

--- 难度指数（越高越难）
function Metrics.difficulty_index(completion_rate)
    return 1 - completion_rate
end

--- 经济流速（健康范围 0.6~0.85）
function Metrics.economy_velocity(spent, earned)
    if earned == 0 then return 0 end
    return spent / earned
end

--- 参与度斜率（>1 增长，<1 衰减）
function Metrics.engagement_slope(this_period, last_period)
    if last_period == 0 then return 1 end
    return this_period / last_period
end

return Metrics
```

### 5.2 平衡信号解读

| 信号 | 含义 | 调整方向 |
|------|------|---------|
| 通关率 < 30% | 关卡过难 | 降低敌人数值 10%，或增加检查点 |
| 通关率 > 95% | 关卡过简单 | 增加挑战元素，但保留作为教学关 |
| 经济流速 < 0.5 | 没东西可买 | 增加有价值的消耗项 |
| 经济流速 > 0.9 | 玩家总缺钱 | 增加产出或降低核心物品价格 |
| 参与度斜率 < 0.8 | 玩家流失加速 | 检查是否有难度墙或无聊区间 |
| 首次通关时间方差 > 均值×2 | 玩家水平差异大 | 增加动态难度或多路径 |

### 5.3 小样本统计参考

| 测试人数 | 可信度 | 适用场景 |
|---------|--------|---------|
| 3–5 人  | 可发现严重问题 | 早期原型验证 |
| 8–12 人 | 可发现趋势 | Alpha 测试 |
| 30+ 人  | 统计显著 | Beta 测试、正式调优 |

**快速判断规则**：
- 3 人中有 2+ 人反映同一问题 → 很可能是真问题
- 5 人中有 4+ 人在同一位置卡关 → 确认该位置过难

---

## 6. 常见反模式

| 反模式 | 问题 | 修正 |
|--------|------|------|
| 线性数值膨胀 | 后期数字巨大、失去意义 | 使用递减收益或压缩曲线 |
| 付费玩家无上限优势 | 毁坏竞技公平性 | 设置付费天花板或纯外观付费 |
| 单一最优策略 | 其他策略没人用 | 石头剪刀布式克制链 |
| 前期过度奖励 | 中后期"奖励荒漠" | 随进度增长奖励密度 |
| 靠数值堆难度 | 敌人只是血厚，不是更聪明 | 增加机制复杂度而非纯数值 |
| 忽略休闲玩家 | 大部分玩家体验差 | 以中位数玩家为基准设计 |
| 一次性大幅调整 | 社区震荡、负反馈 | 每次最多 ±15%，分批调整 |

---

## 7. 注意事项

1. **先设计经济再实现**：先用表格/电子表格模拟经济循环，确认合理后再写代码
2. **所有公式都需要可配置**：使用 Lua 配置表而非硬编码数字，方便后续调优
3. **中位数 ≠ 平均数**：少量硬核玩家会拉高平均值，用中位数更准确反映"大多数人"的体验
4. **保底系统是必须的**：纯随机会导致极端坏运气，保底可显著降低玩家挫败感
5. **难度曲线不是单调递增**：锯齿波（章节内递增+章节间回落）比纯递增更好

---

## 参考文件

- `references/economy-design.md` — 经济系统深度设计（双货币、通胀防御、多人市场）
- `references/progression-formulas.md` — 完整公式集（转生循环、技能树平衡、敌人缩放策略）
- `references/playtesting-guide.md` — 测试方法论（4种测试类型、观察方法、指标分析框架）
