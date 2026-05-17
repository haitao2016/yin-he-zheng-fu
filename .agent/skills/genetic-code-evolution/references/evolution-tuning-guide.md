---
title: "进化参数调优指南"
description: "遗传算法参数调优、性能基准和故障排除完整参考"
skill: genetic-code-evolution
---

# 进化参数调优指南

## 1. 核心参数总览

### 1.1 参数表

| 参数 | 默认值 | 范围 | 影响 |
|------|--------|------|------|
| `populationSize` | 100 | 20 - 1000 | 种群多样性 vs 计算成本 |
| `genomeLength` | 100 | 20 - 500 | 程序最大复杂度 |
| `maxGenerations` | 500 | 50 - 10000 | 进化总时长 |
| `crossoverRate` | 0.7 | 0.5 - 0.95 | 基因重组频率 |
| `mutationRate` | 0.01 | 0.001 - 0.1 | 随机变异频率 |
| `eliteCount` | 2 | 1 - 10 | 精英保留数量 |
| `tournamentSize` | 3 | 2 - 10 | 选择压力 |
| `maxSteps` | 1000 | 100 - 10000 | VM 单次执行上限 |

### 1.2 参数间的关系

```
种群大小 ↑  → 多样性 ↑ → 探索能力 ↑ → 计算成本 ↑
基因长度 ↑  → 程序复杂度 ↑ → 搜索空间 ↑ → 收敛速度 ↓
突变率 ↑    → 探索能力 ↑ → 稳定性 ↓
交叉率 ↑    → 基因混合 ↑ → 可能破坏好基因
选择压力 ↑  → 收敛速度 ↑ → 多样性 ↓ → 局部最优风险 ↑
```

## 2. 任务难度预设

### 2.1 简单任务（字符串生成、简单寻路）

```lua
local simpleConfig = {
    populationSize = 50,
    genomeLength = 50,
    maxGenerations = 200,
    crossoverRate = 0.7,
    mutationRate = 0.02,
    eliteCount = 2,
    tournamentSize = 3,
    maxSteps = 500,
}
-- 预期收敛：50-100 代
-- 每代耗时：< 1ms（50 个体 × 500 步）
```

### 2.2 中等任务（迷宫导航、物品收集）

```lua
local mediumConfig = {
    populationSize = 150,
    genomeLength = 100,
    maxGenerations = 500,
    crossoverRate = 0.7,
    mutationRate = 0.01,
    eliteCount = 3,
    tournamentSize = 4,
    maxSteps = 2000,
}
-- 预期收敛：200-400 代
-- 每代耗时：~5ms（150 × 2000 步，需要帧分配器）
```

### 2.3 困难任务（战斗策略、多目标优化）

```lua
local hardConfig = {
    populationSize = 300,
    genomeLength = 200,
    maxGenerations = 2000,
    crossoverRate = 0.65,
    mutationRate = 0.005,
    eliteCount = 5,
    tournamentSize = 5,
    maxSteps = 5000,
}
-- 预期收敛：800-1500 代
-- 每代耗时：~50ms（300 × 5000 步，必须用帧分配器）
```

### 2.4 极端任务（程序合成、协同进化）

```lua
local extremeConfig = {
    populationSize = 500,
    genomeLength = 300,
    maxGenerations = 5000,
    crossoverRate = 0.6,
    mutationRate = 0.003,
    eliteCount = 10,
    tournamentSize = 6,
    maxSteps = 10000,
}
-- 预期收敛：2000-4000 代
-- 每代耗时：~200ms+（必须帧分配器 + 后台进化）
```

## 3. 帧分配器配置

### 3.1 帧率目标

```lua
local FrameDistributor = require("scripts.GeneticEvolution.FrameDistributor")

-- 60fps 目标：每帧可用 ~16ms
-- 留 10ms 给渲染 → 进化可用 6ms
local distributor = FrameDistributor.Create({
    evaluationsPerFrame = 10,    -- 每帧评估 10 个个体
    targetFrameTime = 6,         -- 最大 6ms
})
```

### 3.2 评估预算分配

| 种群大小 | 每帧评估数 | 完成一代所需帧数 | 60fps 下每代耗时 |
|---------|-----------|----------------|----------------|
| 50      | 10        | 5 帧           | 0.08 秒        |
| 100     | 10        | 10 帧          | 0.17 秒        |
| 200     | 20        | 10 帧          | 0.17 秒        |
| 500     | 25        | 20 帧          | 0.33 秒        |

### 3.3 动态调节

```lua
-- 根据实际帧率动态调整
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 如果帧率低于 30fps，减少评估量
    if dt > 0.033 then
        distributor.evaluationsPerFrame = math.max(1, distributor.evaluationsPerFrame - 2)
    -- 如果帧率高于 55fps，增加评估量
    elseif dt < 0.018 then
        distributor.evaluationsPerFrame = math.min(50, distributor.evaluationsPerFrame + 2)
    end

    FrameDistributor.Tick(distributor, engine, env, fitnessFunc, fitnessOpts)
end
```

## 4. 收敛问题诊断

### 4.1 症状-原因-解决方案表

| 症状 | 可能原因 | 解决方案 |
|------|---------|---------|
| 所有个体分数几乎相同 | 选择压力太低 | 增大 `tournamentSize` |
| 最优分数停滞不前 | 陷入局部最优 | 增大 `mutationRate` 或加入随机移民 |
| 分数忽高忽低 | 突变率太高 | 降低 `mutationRate` |
| 分数增长极慢 | 搜索空间太大 | 减少 `genomeLength` 或指令数 |
| 好方案被后代淘汰 | 精英数太少 | 增加 `eliteCount` |
| 永远达不到满分 | 适应度函数设计问题 | 检查是否有部分奖励 |
| 进化初期就卡住 | 起点太差 | 用启发式初始化替代纯随机 |
| 收敛后又退化 | 交叉破坏精英基因 | 增加 `eliteCount` |

### 4.2 监测指标

```lua
local function MonitorEvolution(engine)
    local stats = engine:GetStats()

    -- 1. 适应度分布
    print(string.format("Gen %d: best=%d avg=%d worst=%d",
        stats.generation, stats.maxFitness, stats.avgFitness, stats.minFitness))

    -- 2. 多样性指标
    local diversity = stats.maxFitness - stats.minFitness
    local relDiversity = diversity / math.max(1, stats.maxFitness) * 100
    print(string.format("  Diversity: %d (%.1f%%)", diversity, relDiversity))

    -- 3. 改进速率
    if stats.generation > 10 then
        local improvement = stats.maxFitness - (stats.fitnessHistory[stats.generation - 10] or 0)
        print(string.format("  Improvement (last 10 gen): %d", improvement))
    end

    -- 4. 程序有效性
    local validPrograms = 0
    for _, indiv in ipairs(engine.population) do
        if indiv.programLength > 0 then
            validPrograms = validPrograms + 1
        end
    end
    print(string.format("  Valid programs: %d/%d", validPrograms, #engine.population))
end
```

## 5. 高级调优策略

### 5.1 自适应突变率

```lua
local function AdaptiveMutation(engine, baseRate)
    local stats = engine:GetStats()

    -- 种群多样性低时增大突变率
    local diversity = stats.maxFitness - stats.avgFitness
    local maxDiversity = stats.maxFitness * 0.3

    if diversity < maxDiversity * 0.1 then
        -- 极低多样性：大幅增大突变
        return baseRate * 5
    elseif diversity < maxDiversity * 0.3 then
        -- 低多样性：适度增大
        return baseRate * 2
    else
        return baseRate
    end
end
```

### 5.2 随机移民

定期注入随机个体，防止过早收敛：

```lua
local function InjectImmigrants(engine, count, genomeLength, instructionSet)
    for i = 1, count do
        local immigrant = GenomeEncoder.RandomGenome(genomeLength, instructionSet.size)
        -- 替换种群中最差的个体
        engine.population[#engine.population - i + 1] = {
            genome = immigrant,
            fitness = 0,
        }
    end
end

-- 每 50 代注入 5 个随机个体
if stats.generation % 50 == 0 then
    InjectImmigrants(engine, 5, config.genomeLength, instructionSet)
end
```

### 5.3 启发式初始化

用已知好的模式初始化部分种群：

```lua
local function HeuristicInit(engine, instructionSet, templates)
    -- templates: 手工设计的基础行为序列
    local templatePatterns = {
        -- "直线前进" 模式
        { 8, 8, 8, 8, 8 },  -- move_forward × 5
        -- "螺旋搜索" 模式
        { 8, 8, 11, 8, 8, 11 },  -- forward, forward, turn_right, ...
        -- "之字形" 模式
        { 8, 10, 8, 11, 8, 10, 8, 11 },
    }

    for i, pattern in ipairs(templatePatterns) do
        if i <= #engine.population then
            local genome = GenomeEncoder.RandomGenome(config.genomeLength, instructionSet.size)
            -- 将模板写入基因前段
            for j, instr in ipairs(pattern) do
                genome[j] = instr / instructionSet.size + math.random() * 0.0001
            end
            engine.population[i].genome = genome
        end
    end
end
```

### 5.4 岛屿模型

将种群分成多个子群，定期交换精英：

```lua
local function IslandModel(islands, migrationInterval, migrantCount)
    -- islands: EvolutionEngine 数组
    -- 每 migrationInterval 代交换 migrantCount 个精英

    for i, island in ipairs(islands) do
        local stats = island:GetStats()
        if stats.generation % migrationInterval == 0 then
            -- 从当前岛屿取精英
            local best = island:GetBestProgram()
            -- 发送到下一个岛屿（环形拓扑）
            local nextIsland = islands[(i % #islands) + 1]
            -- 替换目标岛屿中最差个体
            local worstIdx = #nextIsland.population
            nextIsland.population[worstIdx].genome = best.genome
        end
    end
end
```

## 6. 性能优化

### 6.1 VM 优化

```lua
-- 减少 VM 开销的技巧：

-- 1. 预编译循环匹配表（只计算一次）
local function PrecompileLoops(program)
    local loopMap = {}
    local stack = {}
    for i, instr in ipairs(program) do
        if instr == 6 then  -- loop_start
            table.insert(stack, i)
        elseif instr == 7 then  -- loop_end
            local start = table.remove(stack)
            if start then
                loopMap[start] = i
                loopMap[i] = start
            end
        end
    end
    return loopMap
end

-- 2. 批量评估时重用 VM 对象
local sharedVM = Interpreter.CreateVM(instructionSet)
for _, indiv in ipairs(population) do
    Interpreter.Reset(sharedVM)
    Interpreter.Execute(sharedVM, indiv.genome, env)
    indiv.fitness = fitnessFunc(sharedVM, env, opts)
end
```

### 6.2 内存优化

```lua
-- 基因组内存估算
-- 每个基因 = 1 个 Lua number = 8 bytes
-- 种群内存 ≈ populationSize × genomeLength × 8

-- 示例：500 × 300 × 8 = 1.2 MB（完全可接受）
-- 极端：1000 × 500 × 8 = 4 MB（仍然安全）
```

### 6.3 评估跳过

```lua
-- 跳过未变化的个体（精英无需重新评估）
for _, indiv in ipairs(population) do
    if not indiv.evaluated then
        -- 只评估新生成/变异的个体
        local vm = Interpreter.CreateVM(instructionSet)
        Interpreter.Execute(vm, indiv.genome, env)
        indiv.fitness = fitnessFunc(vm, env, opts)
        indiv.evaluated = true
    end
end
```

## 7. 构建与调试清单

### 7.1 项目文件结构

```
scripts/
├── main.lua                        -- 入口，场景搭建 + 进化启动
└── GeneticEvolution/
    ├── GenomeEncoder.lua            -- 基因编解码
    ├── InstructionSet.lua           -- 指令集定义
    ├── Interpreter.lua              -- VM 执行器
    ├── FitnessEvaluator.lua         -- 适应度评估
    ├── EvolutionEngine.lua          -- 进化引擎
    ├── SandboxEnv.lua               -- 沙盒环境
    ├── FrameDistributor.lua         -- 帧分配器
    └── GenomePersistence.lua        -- 基因存档
```

### 7.2 调试日志模板

```lua
-- 在 main.lua 中添加调试输出
local function DebugLog(engine, generation)
    local stats = engine:GetStats()
    local best = engine:GetBestProgram()

    print(string.format("[Gen %04d] Best: %d | Avg: %d | Worst: %d",
        generation, stats.maxFitness, stats.avgFitness, stats.minFitness))

    if best then
        local program = GenomeEncoder.ProgramToString(best.genome, instructionSet)
        print("  Best program: " .. program:sub(1, 60) .. "...")
    end
end
```

### 7.3 常见错误排查

| 错误现象 | 检查项 |
|---------|-------|
| 所有个体得分为 0 | VM maxSteps 太小，程序没执行完 |
| 适应度全是 NaN | 除零错误，检查 fitness 公式 |
| 进化极慢 | 检查帧分配器的 evaluationsPerFrame |
| 内存增长 | 检查是否每帧创建新表而未释放 |
| 实体不移动 | 检查 onGameAction 回调是否正确注册 |
| 循环死锁 | VM 的 loop 嵌套检测是否启用 |

## 8. 参数调优速查卡

```
┌──────────────────────────────────────────────┐
│           参数调优速查卡                      │
├──────────────────────────────────────────────┤
│                                              │
│  收敛太慢？                                   │
│  → 增大 populationSize                       │
│  → 减小 genomeLength                         │
│  → 检查 fitness 是否有梯度                    │
│                                              │
│  过早收敛（局部最优）？                        │
│  → 增大 mutationRate                         │
│  → 减小 tournamentSize                       │
│  → 加入随机移民                               │
│                                              │
│  分数不稳定？                                 │
│  → 减小 mutationRate                         │
│  → 增大 eliteCount                           │
│  → 多次评估取中位数                           │
│                                              │
│  帧率下降？                                   │
│  → 减小 evaluationsPerFrame                  │
│  → 减小 maxSteps                             │
│  → 启用评估跳过                               │
│                                              │
│  内存占用高？                                 │
│  → 减小 populationSize                       │
│  → 重用 VM 对象                              │
│                                              │
└──────────────────────────────────────────────┘
```
