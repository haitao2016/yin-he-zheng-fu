---
title: "适应度函数食谱"
description: "为不同游戏目标设计有效适应度函数的完整参考"
skill: genetic-code-evolution
---

# 适应度函数食谱

## 1. 适应度函数设计原则

### 1.1 什么是好的适应度函数

适应度函数是进化的**唯一驱动力**——它定义了"什么是好程序"。设计不当会导致：

- **过早收敛**：所有个体陷入局部最优
- **无法收敛**：适应度景观太平坦，随机漫步
- **欺骗性**：高分个体实际行为不符合预期

### 1.2 核心原则

| 原则 | 说明 | 示例 |
|------|------|------|
| **梯度连续** | 接近目标时分数应逐渐升高 | 距出口 3 格 > 距出口 5 格 |
| **部分奖励** | 完成一半也应有分数 | 收集 3/5 物品 > 收集 0/5 |
| **行为塑形** | 鼓励探索性行为 | 访问新格子 +1，重复访问 +0 |
| **惩罚节制** | 惩罚不要太重 | -1 per 无效步 vs -100（太重会抑制探索） |
| **可分解** | 多目标可加权组合 | 总分 = 击杀 × 100 + 生存 × 1 |

### 1.3 评分范围建议

```
推荐：0 ~ 10000 的整数区间
原因：
  - 整数比较快于浮点
  - 范围足够表达细粒度差异
  - 便于调试和打印
```

## 2. 内置适应度函数详解

### 2.1 StringMatch（字符串匹配）

源自 AI-Programmer 的经典适应度函数。

```lua
local FitnessEvaluator = require("scripts.GeneticEvolution.FitnessEvaluator")

local fitness = FitnessEvaluator.StringMatch(vm, {
    target = "hello",       -- 目标字符串
})
-- 公式：sum( 256 - |output[i] - target[i]| ) / (256 * #target) * 10000
-- 完美匹配 = 10000
-- 完全不匹配 ≈ 5000（随机输出的期望值）
```

**适用场景**：
- 教学演示（遗传算法入门）
- 密码/序列猜测游戏
- 程序合成基础验证

**调优技巧**：
- 短字符串（≤5 字符）收敛快，适合演示
- 长字符串需要更大种群（200+）和更多代数（1000+）

### 2.2 Pathfinding（寻路）

评估实体从起点到终点的寻路能力。

```lua
local fitness = FitnessEvaluator.Pathfinding(vm, env, {
    targetX = 10,           -- 目标 X
    targetY = 10,           -- 目标 Y
    maxDist = 20,           -- 最大可能距离（用于归一化）
})
-- 公式：
--   baseDist = maxDist - manhattan(entity, target)  -- 距离越近分越高
--   reachBonus = (到达目标) ? 5000 : 0
--   exploreBonus = uniqueTilesVisited * 10
--   penalty = wallCollisions * -5
--   total = baseDist / maxDist * 3000 + reachBonus + exploreBonus + penalty
```

**适用场景**：
- 迷宫求解
- NPC 导航行为进化
- 路径优化（最短路径搜索）

**设计要点**：
- `exploreBonus` 防止实体原地不动就得高分
- `wallCollisions` 惩罚不能太重，否则实体会学会"不动"
- `reachBonus` 必须远大于其他项，确保"到达"是首要目标

### 2.3 ItemCollection（物品收集）

评估实体收集场景中物品的效率。

```lua
local fitness = FitnessEvaluator.ItemCollection(vm, env, {
    totalItems = 5,         -- 场景中总物品数
})
-- 公式：
--   collectScore = collectedItems / totalItems * 6000
--   speedBonus = (totalItems 全收集) ? (maxSteps - usedSteps) * 2 : 0
--   exploreBonus = uniqueTilesVisited * 5
--   total = collectScore + speedBonus + exploreBonus
```

### 2.4 Survival（生存）

评估实体在危险环境中存活的能力。

```lua
local fitness = FitnessEvaluator.Survival(vm, env, {
    maxTurns = 200,         -- 最大回合数
})
-- 公式：
--   survivalScore = turnsAlive / maxTurns * 5000
--   healthBonus = remainingHealth / maxHealth * 2000
--   killBonus = enemiesKilled * 500
--   dodgeBonus = attacksDodged * 100
--   total = survivalScore + healthBonus + killBonus + dodgeBonus
```

### 2.5 Combined（组合评估）

将多个适应度函数加权组合。

```lua
local fitness = FitnessEvaluator.Combined(vm, env, {
    evaluators = {
        { func = FitnessEvaluator.Pathfinding, weight = 0.4, opts = { targetX=10, targetY=10, maxDist=20 } },
        { func = FitnessEvaluator.ItemCollection, weight = 0.3, opts = { totalItems=5 } },
        { func = FitnessEvaluator.Survival, weight = 0.3, opts = { maxTurns=200 } },
    },
})
-- 公式：sum( evaluator_i(vm, env, opts) * weight_i )
```

## 3. 自定义适应度函数配方

### 3.1 区域占领

NPC 需要占领尽可能多的地图区域。

```lua
local function TerritoryControl(vm, env, opts)
    local score = 0
    local controlledTiles = 0
    local totalTiles = env.gridWidth * env.gridHeight

    for y = 1, env.gridHeight do
        for x = 1, env.gridWidth do
            if env.ownership[y][x] == env.entityId then
                controlledTiles = controlledTiles + 1
            end
        end
    end

    -- 占领比例（主要得分）
    score = score + (controlledTiles / totalTiles) * 7000

    -- 连续区域奖励（鼓励占领连片区域而非零散格子）
    local largestRegion = env:GetLargestConnectedRegion(env.entityId)
    score = score + (largestRegion / controlledTiles) * 2000

    -- 效率奖励（步数越少占领越多越好）
    score = score + math.max(0, 1000 - vm.stepCount)

    return math.floor(score)
end
```

### 3.2 编队保持

多个 NPC 需要保持队形移动。

```lua
local function FormationKeeping(vm, env, opts)
    local score = 0
    local idealPositions = opts.formation  -- 预定义队形坐标

    -- 队形偏差（越小越好）
    local totalDeviation = 0
    for i, npc in ipairs(env.npcs) do
        local ideal = idealPositions[i]
        local dx = npc.x - (env.leaderX + ideal.offsetX)
        local dy = npc.y - (env.leaderY + ideal.offsetY)
        totalDeviation = totalDeviation + math.sqrt(dx*dx + dy*dy)
    end
    local maxDeviation = #env.npcs * env.gridWidth
    score = score + (1 - totalDeviation / maxDeviation) * 5000

    -- 移动进度（队伍需要向目标前进）
    local distToGoal = math.abs(env.leaderX - opts.goalX) + math.abs(env.leaderY - opts.goalY)
    score = score + (1 - distToGoal / opts.maxDist) * 3000

    -- 存活率
    local aliveCount = 0
    for _, npc in ipairs(env.npcs) do
        if npc.alive then aliveCount = aliveCount + 1 end
    end
    score = score + (aliveCount / #env.npcs) * 2000

    return math.floor(score)
end
```

### 3.3 资源效率

NPC 需要用最少资源完成目标。

```lua
local function ResourceEfficiency(vm, env, opts)
    local score = 0

    -- 任务完成度（首要目标）
    local completion = env.tasksCompleted / opts.totalTasks
    score = score + completion * 6000

    -- 资源节约（次要目标）
    local resourceUsed = opts.initialResource - env.currentResource
    local maxResource = opts.initialResource
    if completion > 0 then
        -- 每单位完成度消耗的资源越少越好
        local efficiency = completion / (resourceUsed / maxResource + 0.01)
        score = score + math.min(efficiency * 500, 3000)
    end

    -- 时间效率
    if env.tasksCompleted > 0 then
        score = score + math.max(0, 1000 - vm.stepCount / env.tasksCompleted)
    end

    return math.floor(score)
end
```

### 3.4 对抗评估（协同进化）

两个程序互相对抗，胜者得高分。

```lua
local function CompetitiveFitness(vmA, vmB, env, opts)
    -- 执行双方程序交替行动
    local turnsA = 0
    local turnsB = 0

    for turn = 1, opts.maxTurns do
        -- A 行动
        Interpreter.ExecuteStep(vmA, env)
        -- B 行动
        Interpreter.ExecuteStep(vmB, env)

        if env:IsDefeated("B") then
            -- A 获胜
            return {
                fitnessA = 8000 + (opts.maxTurns - turn) * 10,
                fitnessB = turn * 5,
            }
        elseif env:IsDefeated("A") then
            -- B 获胜
            return {
                fitnessA = turn * 5,
                fitnessB = 8000 + (opts.maxTurns - turn) * 10,
            }
        end
    end

    -- 平局：按剩余生命值评分
    return {
        fitnessA = 4000 + env.healthA * 20,
        fitnessB = 4000 + env.healthB * 20,
    }
end
```

## 4. 适应度景观分析

### 4.1 什么是适应度景观

```
适应度 ↑
       ▓▓░░                  ▓▓▓▓
      ▓▓▓▓░░                ▓▓▓▓▓▓
     ▓▓▓▓▓▓░░              ▓▓▓▓▓▓▓▓   ← 全局最优
    ░░▓▓▓▓▓▓░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓
   ░░░░▓▓▓▓░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓
  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
       ↑ 局部最优          基因空间 →
```

### 4.2 检测景观问题

在进化过程中监测以下指标：

```lua
local function AnalyzeLandscape(stats)
    -- 1. 多样性检查
    local diversity = stats.maxFitness - stats.avgFitness
    if diversity < 10 then
        print("[警告] 种群多样性过低，可能过早收敛")
        -- 建议：增大突变率或引入随机移民
    end

    -- 2. 停滞检查
    if stats.generation > 100 and stats.bestFitnessHistory then
        local recent = stats.bestFitnessHistory
        local improvement = recent[#recent] - recent[math.max(1, #recent - 50)]
        if improvement < 100 then
            print("[警告] 最近 50 代几乎无改进，可能陷入局部最优")
            -- 建议：重新设计适应度函数的梯度
        end
    end

    -- 3. 天花板检查
    if stats.maxFitness > 9500 and stats.avgFitness < 5000 then
        print("[信息] 精英个体远超平均，考虑增大选择压力")
    end
end
```

## 5. 适应度函数调优技巧

### 5.1 分阶段适应度

随着进化进行，逐步提高要求：

```lua
local function StagedFitness(vm, env, opts)
    local gen = opts.currentGeneration

    if gen < 50 then
        -- 阶段 1：只奖励移动（学会走路）
        return env.uniqueTilesVisited * 100
    elseif gen < 150 then
        -- 阶段 2：移动 + 收集（学会拾取）
        return env.uniqueTilesVisited * 50 + env.itemsCollected * 500
    else
        -- 阶段 3：完整评估
        return FitnessEvaluator.Combined(vm, env, opts.fullConfig)
    end
end
```

### 5.2 多目标帕累托排序

当多个目标存在冲突时（如速度 vs 安全）：

```lua
local function ParetoRank(population, objectives)
    -- objectives = { "speed", "safety", "efficiency" }
    for _, indiv in ipairs(population) do
        indiv.dominatedCount = 0
        indiv.dominates = {}
    end

    for i = 1, #population do
        for j = i + 1, #population do
            local a, b = population[i], population[j]
            if DominatesAll(a, b, objectives) then
                b.dominatedCount = b.dominatedCount + 1
                table.insert(a.dominates, j)
            elseif DominatesAll(b, a, objectives) then
                a.dominatedCount = a.dominatedCount + 1
                table.insert(b.dominates, i)
            end
        end
    end

    -- Pareto 前沿中的个体 dominatedCount == 0
    for _, indiv in ipairs(population) do
        indiv.fitness = 10000 - indiv.dominatedCount * 100
    end
end
```

### 5.3 噪声抵抗

对于随机性环境，单次评估可能不准确：

```lua
local function RobustEvaluation(genome, env, fitnessFunc, opts)
    local trials = opts.trials or 3
    local scores = {}

    for t = 1, trials do
        env:Reset(math.random(1, 99999))  -- 不同随机种子
        local vm = Interpreter.CreateVM(opts.instructionSet)
        Interpreter.Execute(vm, genome, env)
        scores[t] = fitnessFunc(vm, env, opts)
    end

    -- 取中位数而非平均值（抵抗极端值）
    table.sort(scores)
    return scores[math.ceil(#scores / 2)]
end
```

## 6. 适应度函数反模式

### 反模式 1：全有或全无

```
❌ fitness = (到达目标) ? 10000 : 0
   → 大多数个体得 0 分，无法引导进化方向

✅ fitness = (maxDist - distToTarget) / maxDist * 8000
             + (到达目标) ? 2000 : 0
   → 越接近目标分越高，到达后有额外奖励
```

### 反模式 2：惩罚过重

```
❌ fitness = collectScore - wallHits * 1000
   → 撞一次墙就归零，实体学会"不动"

✅ fitness = collectScore - wallHits * 5
   → 轻微惩罚，实体仍有动力探索
```

### 反模式 3：目标冲突未加权

```
❌ fitness = speed + safety  （数量级可能差异巨大）
   → speed 可能是 0-1000，safety 可能是 0-10，speed 完全主导

✅ fitness = normalize(speed) * 0.5 + normalize(safety) * 0.5
   → 归一化后加权，两个目标均衡
```

### 反模式 4：评估不稳定

```
❌ 每次评估使用不同随机种子且只评估 1 次
   → 同一个体得分波动极大，好基因可能被淘汰

✅ 评估 3 次取中位数，或固定种子保证可复现
```
