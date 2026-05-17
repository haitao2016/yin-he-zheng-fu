---
skill_name: "genetic-code-evolution"
version: "1.0.0"
description: "Genetic Code Evolution — 遗传编程与程序合成引擎，为 UrhoX Lua 游戏提供基于遗传算法自动进化可执行指令序列的能力。可用于自动生成 NPC 行为程序、进化关卡解法、策略优化、自适应 AI 等场景"
author: "UrhoX Skill Builder"
tags:
  - genetic-algorithm
  - program-synthesis
  - evolutionary-computation
  - virtual-machine
  - ai-programming
  - game-ai
  - auto-generation
triggers:
  - 遗传编程
  - 程序合成
  - 进化代码
  - 自动编程
  - genetic programming
  - program synthesis
  - evolve program
  - evolve code
  - 指令进化
  - 行为进化
  - AI编程
  - 自动生成AI
  - 遗传算法生成程序
  - virtual machine
  - 虚拟机
  - 指令集
---

# Genetic Code Evolution

> 遗传编程与程序合成引擎 — 用遗传算法自动进化可执行指令序列

灵感来源：[primaryobjects/AI-Programmer](https://github.com/primaryobjects/AI-Programmer) — 一个使用遗传算法自动生成可运行程序的研究项目。

本 Skill 将 AI-Programmer 的核心思想（遗传算法 + 虚拟机 + 适应度评估 → 程序合成）适配为 UrhoX Lua 游戏引擎的可用模块，用于在游戏运行时自动进化可执行的指令序列，驱动 NPC 行为、关卡策略、自适应 AI 等。

---

## §1 Use When 触发条件

**Use when** users need to:

1. 用遗传算法**自动生成可执行程序/指令序列**来控制游戏实体
2. 让 NPC/敌人的**行为通过进化自动涌现**而非手动编写
3. 实现**自适应 AI**——根据玩家行为进化出对应策略
4. 用进化搜索自动寻找**关卡最优解法或策略组合**
5. 构建"**虚拟生物**"系统——生物的行为由可进化的指令序列驱动
6. 需要一个**轻量虚拟机**来安全执行进化产生的指令序列
7. 实现**遗传编程（GP）**风格的游戏玩法或教学演示
8. 需要**程序合成**能力——给定输入输出目标，自动进化出满足条件的程序

**与 `evolutionary-game-systems` 的区别**：
- `evolutionary-game-systems`：进化的是**参数/数值**（血量、攻击力、权重等浮点数向量）
- `genetic-code-evolution`（本 Skill）：进化的是**可执行指令序列**（程序），通过虚拟机解释执行

**不适用场景**：
- 仅需进化游戏参数 → 使用 `evolutionary-game-systems`
- 手动编写行为树 → 使用 `behavior-tree-ai`
- 过程化地形/关卡生成 → 使用 `procedural-generation`

---

## §2 系统架构概述

```
┌─────────────────────────────────────────────────────────┐
│                 Genetic Code Evolution                   │
│                                                         │
│  ┌─────────┐  ┌────────────┐  ┌───────────────────┐    │
│  │ Genome  │→│ Interpreter │→│ FitnessEvaluator  │    │
│  │ Encoder │  │ (VM)       │  │                   │    │
│  └─────────┘  └────────────┘  └───────────────────┘    │
│       ↑                              │                  │
│       │          ┌───────────┐       │                  │
│       └──────────│ Evolution │←──────┘                  │
│                  │ Engine    │                           │
│                  └───────────┘                           │
│                       ↑                                  │
│               ┌───────────────┐                          │
│               │ Sandbox       │                          │
│               │ Environment   │                          │
│               └───────────────┘                          │
└─────────────────────────────────────────────────────────┘
```

### 六大核心模块

| 模块 | 职责 |
|------|------|
| **GenomeEncoder** | 基因组编解码：浮点数组 ↔ 指令序列 |
| **InstructionSet** | 定义可用指令集（内置 + 自定义扩展） |
| **Interpreter** | 轻量虚拟机，安全执行指令序列 |
| **FitnessEvaluator** | 适应度评估框架，衡量程序表现 |
| **EvolutionEngine** | 遗传算法引擎：选择、交叉、变异、世代管理 |
| **SandboxEnv** | 沙箱执行环境，为程序提供输入/输出/传感器 |

---

## §3 指令集系统（InstructionSet）

### §3.1 概念

AI-Programmer 原版使用 Brainfuck 8 指令集。本 Skill 将其适配为**面向游戏的指令集**，分为三个层级：

| 层级 | 名称 | 指令数 | 适用场景 |
|------|------|--------|---------|
| **Tier-1** | Core | 8 | 教学演示、字符串生成（对标原版 BF） |
| **Tier-2** | GameAction | 16 | NPC 行为控制、简单策略 |
| **Tier-3** | Extended | 24+ | 复杂 AI、多实体协作 |

### §3.2 Tier-1: Core 指令集（8 指令）

直接映射 AI-Programmer 原版指令，在虚拟机内存带上操作：

```lua
local InstructionSet = {}

--- Tier-1 Core 指令集定义
InstructionSet.CORE = {
    { id = 0, symbol = ">", name = "ptr_inc",   desc = "指针右移" },
    { id = 1, symbol = "<", name = "ptr_dec",   desc = "指针左移" },
    { id = 2, symbol = "+", name = "val_inc",   desc = "当前值+1" },
    { id = 3, symbol = "-", name = "val_dec",   desc = "当前值-1" },
    { id = 4, symbol = ".", name = "output",    desc = "输出当前值" },
    { id = 5, symbol = ",", name = "input",     desc = "读取输入" },
    { id = 6, symbol = "[", name = "loop_start", desc = "循环开始（值为0则跳到匹配]）" },
    { id = 7, symbol = "]", name = "loop_end",   desc = "循环结束（值非0则回跳到匹配[）" },
}

--- 指令总数
function InstructionSet.GetSize(instructionSet)
    return #instructionSet
end

return InstructionSet
```

### §3.3 Tier-2: GameAction 指令集（16 指令）

在 Core 基础上增加面向游戏实体控制的指令：

```lua
InstructionSet.GAME_ACTION = {
    -- Core 指令 (0-7) 同上
    -- ... (继承 CORE 的 8 条)

    -- 移动指令
    { id = 8,  symbol = "F", name = "move_forward",  desc = "向前移动一步" },
    { id = 9,  symbol = "B", name = "move_backward", desc = "向后移动一步" },
    { id = 10, symbol = "L", name = "turn_left",     desc = "左转 90 度" },
    { id = 11, symbol = "R", name = "turn_right",    desc = "右转 90 度" },

    -- 感知指令
    { id = 12, symbol = "S", name = "sense_ahead",   desc = "探测前方，结果存入当前格" },
    { id = 13, symbol = "D", name = "sense_distance", desc = "探测目标距离，存入当前格" },

    -- 动作指令
    { id = 14, symbol = "A", name = "attack",        desc = "执行攻击动作" },
    { id = 15, symbol = "G", name = "grab",          desc = "拾取/交互" },
}
```

### §3.4 Tier-3: Extended 指令集（24 指令）

额外增加高级控制指令：

```lua
InstructionSet.EXTENDED = {
    -- GameAction 指令 (0-15) 同上

    -- 高级移动
    { id = 16, symbol = "U", name = "move_up",       desc = "向上移动（跳跃/飞行）" },
    { id = 17, symbol = "W", name = "wait",          desc = "等待一回合" },

    -- 高级感知
    { id = 18, symbol = "E", name = "sense_entity",  desc = "探测最近实体类型" },
    { id = 19, symbol = "H", name = "sense_health",  desc = "读取自身生命值" },

    -- 通讯
    { id = 20, symbol = "C", name = "signal",        desc = "发送信号（写入共享通道）" },
    { id = 21, symbol = "P", name = "receive",       desc = "接收信号（读取共享通道）" },

    -- 子程序（对标 BrainPlus）
    { id = 22, symbol = "{", name = "func_define",   desc = "定义子程序开始" },
    { id = 23, symbol = "}", name = "func_call",     desc = "调用已定义的子程序" },
}
```

### §3.5 自定义指令集

用户可根据游戏需求自定义指令集：

```lua
--- 创建自定义指令集
---@param baseSet table 基础指令集（CORE/GAME_ACTION/EXTENDED）
---@param extraInstructions table 额外指令数组
---@return table 新指令集
function InstructionSet.Extend(baseSet, extraInstructions)
    local newSet = {}
    for i = 1, #baseSet do
        newSet[i] = baseSet[i]
    end
    local nextId = #baseSet
    for i = 1, #extraInstructions do
        local instr = extraInstructions[i]
        instr.id = nextId + i - 1
        newSet[#newSet + 1] = instr
    end
    return newSet
end

-- 示例：为塔防游戏添加建造指令
local towerDefenseSet = InstructionSet.Extend(InstructionSet.GAME_ACTION, {
    { symbol = "T", name = "place_tower",  desc = "在当前位置放置塔" },
    { symbol = "X", name = "remove_tower", desc = "移除当前位置的塔" },
    { symbol = "Q", name = "upgrade",      desc = "升级当前位置的塔" },
})
```

---

## §4 基因组编解码（GenomeEncoder）

### §4.1 核心概念

每个基因组是一个浮点数数组，通过取模映射到指令索引：

```lua
local GenomeEncoder = {}

--- 将浮点基因组解码为指令序列
---@param genome number[] 浮点数数组（基因组）
---@param instructionSet table 指令集定义
---@return table[] 指令对象数组
function GenomeEncoder.Decode(genome, instructionSet)
    local program = {}
    local setSize = #instructionSet
    for i = 1, #genome do
        local gene = genome[i]
        -- 将浮点数映射到指令索引：取绝对值 * 大数 后取模
        local index = (math.floor(math.abs(gene) * 1000000) % setSize) + 1
        program[i] = instructionSet[index]
    end
    return program
end

--- 将指令序列编码回浮点基因组
---@param program table[] 指令对象数组
---@param instructionSet table 指令集定义
---@return number[] 浮点数数组
function GenomeEncoder.Encode(program, instructionSet)
    local genome = {}
    local setSize = #instructionSet
    for i = 1, #program do
        -- 指令 id 归一化到 [0, 1) 区间
        genome[i] = (program[i].id + 0.5) / setSize
    end
    return genome
end

--- 生成随机基因组
---@param size number 基因组长度
---@return number[] 随机浮点数数组
function GenomeEncoder.RandomGenome(size)
    local genome = {}
    for i = 1, size do
        genome[i] = math.random()
    end
    return genome
end

--- 将指令序列转为可读字符串
---@param program table[] 指令对象数组
---@return string 指令符号串
function GenomeEncoder.ProgramToString(program)
    local symbols = {}
    for i = 1, #program do
        symbols[i] = program[i].symbol
    end
    return table.concat(symbols)
end

return GenomeEncoder
```

### §4.2 基因组长度建议

| 目标复杂度 | 建议长度 | 示例用途 |
|-----------|---------|---------|
| 简单输出 | 20-50 | 输出固定字符串 |
| 简单行为 | 50-100 | 直线寻路、简单巡逻 |
| 中等行为 | 100-200 | 追击+躲避策略 |
| 复杂策略 | 200-500 | 多目标决策、协作行为 |

---

## §5 虚拟机解释器（Interpreter）

### §5.1 核心虚拟机

安全的沙箱化指令执行器，带执行步数限制防止死循环：

```lua
local Interpreter = {}

--- 虚拟机状态
---@class VMState
---@field memory number[] 内存带（数据数组）
---@field memorySize number 内存带长度
---@field pointer number 内存指针位置
---@field pc number 程序计数器
---@field output number[] 输出缓冲区
---@field inputBuffer number[] 输入缓冲区
---@field inputIndex number 输入读取位置
---@field steps number 已执行步数
---@field maxSteps number 最大允许步数
---@field halted boolean 是否已停机
---@field env table 沙箱环境引用

--- 创建新的虚拟机状态
---@param config table? 配置 { memorySize, maxSteps, input, env }
---@return VMState
function Interpreter.CreateVM(config)
    config = config or {}
    local memSize = config.memorySize or 256
    local memory = {}
    for i = 1, memSize do
        memory[i] = 0
    end

    local inputBuf = {}
    if config.input then
        for i = 1, #config.input do
            inputBuf[i] = config.input[i]
        end
    end

    return {
        memory = memory,
        memorySize = memSize,
        pointer = 1,
        pc = 1,
        output = {},
        inputBuffer = inputBuf,
        inputIndex = 1,
        steps = 0,
        maxSteps = config.maxSteps or 10000,
        halted = false,
        env = config.env or {},
    }
end

--- 执行指令序列
---@param program table[] 指令对象数组
---@param vm VMState 虚拟机状态
---@return VMState 执行后的虚拟机状态
function Interpreter.Execute(program, vm)
    local progLen = #program
    if progLen == 0 then
        vm.halted = true
        return vm
    end

    while vm.pc >= 1 and vm.pc <= progLen and not vm.halted do
        if vm.steps >= vm.maxSteps then
            vm.halted = true
            break
        end

        local instr = program[vm.pc]
        vm.steps = vm.steps + 1

        Interpreter._ExecuteInstruction(instr, program, vm)

        vm.pc = vm.pc + 1
    end

    vm.halted = true
    return vm
end

--- 执行单条指令（内部方法）
function Interpreter._ExecuteInstruction(instr, program, vm)
    local name = instr.name

    -- ===== Tier-1: Core 指令 =====
    if name == "ptr_inc" then
        vm.pointer = vm.pointer + 1
        if vm.pointer > vm.memorySize then vm.pointer = 1 end

    elseif name == "ptr_dec" then
        vm.pointer = vm.pointer - 1
        if vm.pointer < 1 then vm.pointer = vm.memorySize end

    elseif name == "val_inc" then
        vm.memory[vm.pointer] = (vm.memory[vm.pointer] + 1) % 256

    elseif name == "val_dec" then
        vm.memory[vm.pointer] = (vm.memory[vm.pointer] - 1) % 256

    elseif name == "output" then
        vm.output[#vm.output + 1] = vm.memory[vm.pointer]

    elseif name == "input" then
        if vm.inputIndex <= #vm.inputBuffer then
            vm.memory[vm.pointer] = vm.inputBuffer[vm.inputIndex]
            vm.inputIndex = vm.inputIndex + 1
        else
            vm.memory[vm.pointer] = 0
        end

    elseif name == "loop_start" then
        if vm.memory[vm.pointer] == 0 then
            -- 跳到匹配的 loop_end
            local depth = 1
            while depth > 0 and vm.pc < #program do
                vm.pc = vm.pc + 1
                if program[vm.pc].name == "loop_start" then
                    depth = depth + 1
                elseif program[vm.pc].name == "loop_end" then
                    depth = depth - 1
                end
            end
        end

    elseif name == "loop_end" then
        if vm.memory[vm.pointer] ~= 0 then
            -- 回跳到匹配的 loop_start
            local depth = 1
            while depth > 0 and vm.pc > 1 do
                vm.pc = vm.pc - 1
                if program[vm.pc].name == "loop_end" then
                    depth = depth + 1
                elseif program[vm.pc].name == "loop_start" then
                    depth = depth - 1
                end
            end
            vm.pc = vm.pc - 1  -- 因为外层循环会 +1
        end

    -- ===== Tier-2: GameAction 指令 =====
    elseif name == "move_forward" then
        if vm.env.moveForward then vm.env.moveForward(vm) end

    elseif name == "move_backward" then
        if vm.env.moveBackward then vm.env.moveBackward(vm) end

    elseif name == "turn_left" then
        if vm.env.turnLeft then vm.env.turnLeft(vm) end

    elseif name == "turn_right" then
        if vm.env.turnRight then vm.env.turnRight(vm) end

    elseif name == "sense_ahead" then
        if vm.env.senseAhead then
            vm.memory[vm.pointer] = vm.env.senseAhead(vm) or 0
        end

    elseif name == "sense_distance" then
        if vm.env.senseDistance then
            vm.memory[vm.pointer] = vm.env.senseDistance(vm) or 0
        end

    elseif name == "attack" then
        if vm.env.attack then vm.env.attack(vm) end

    elseif name == "grab" then
        if vm.env.grab then vm.env.grab(vm) end

    -- ===== Tier-3: Extended 指令 =====
    elseif name == "move_up" then
        if vm.env.moveUp then vm.env.moveUp(vm) end

    elseif name == "wait" then
        -- 空操作
    elseif name == "sense_entity" then
        if vm.env.senseEntity then
            vm.memory[vm.pointer] = vm.env.senseEntity(vm) or 0
        end

    elseif name == "sense_health" then
        if vm.env.senseHealth then
            vm.memory[vm.pointer] = vm.env.senseHealth(vm) or 0
        end

    elseif name == "signal" then
        if vm.env.signal then vm.env.signal(vm, vm.memory[vm.pointer]) end

    elseif name == "receive" then
        if vm.env.receive then
            vm.memory[vm.pointer] = vm.env.receive(vm) or 0
        end
    end
    -- 未识别指令 → 静默忽略（空操作）
end

--- 获取输出的字符串形式
---@param vm VMState
---@return string
function Interpreter.GetOutputString(vm)
    local chars = {}
    for i = 1, #vm.output do
        local code = vm.output[i]
        if code >= 32 and code <= 126 then
            chars[#chars + 1] = string.char(code)
        end
    end
    return table.concat(chars)
end

--- 重置虚拟机状态（保留环境）
function Interpreter.Reset(vm)
    for i = 1, vm.memorySize do
        vm.memory[i] = 0
    end
    vm.pointer = 1
    vm.pc = 1
    vm.output = {}
    vm.inputIndex = 1
    vm.steps = 0
    vm.halted = false
end

return Interpreter
```

### §5.2 执行安全保障

| 保护机制 | 说明 |
|---------|------|
| **步数上限** | `maxSteps` 参数，默认 10000，防止死循环 |
| **内存边界回绕** | 指针超出范围时自动绕回，不越界 |
| **值域限制** | 内存值限制在 0-255 (% 256) |
| **输入耗尽保护** | 输入缓冲读完后返回 0 |
| **未知指令忽略** | 未识别的指令名视为空操作 |

---

## §6 适应度评估（FitnessEvaluator）

### §6.1 概念

适应度函数是遗传编程的核心——定义了"什么是好程序"。

### §6.2 内置适应度函数

```lua
local FitnessEvaluator = {}

--- 字符串匹配适应度（对标 AI-Programmer 原版）
--- 目标：进化出能输出指定字符串的程序
---@param vm VMState 执行完毕的虚拟机
---@param targetString string 目标字符串
---@return number 适应度分数（越高越好）
function FitnessEvaluator.StringMatch(vm, targetString)
    local output = vm.output
    local targetBytes = { string.byte(targetString, 1, #targetString) }
    local fitness = 0
    local maxLen = math.max(#output, #targetBytes)

    for i = 1, #targetBytes do
        if i <= #output then
            -- 字符越接近目标，分数越高
            fitness = fitness + (256 - math.abs(output[i] - targetBytes[i]))
        end
    end

    -- 长度惩罚：输出长度与目标不同时扣分
    local lenPenalty = math.abs(#output - #targetBytes) * 50
    fitness = fitness - lenPenalty

    -- 归一化到 [0, 1]
    local maxPossible = #targetBytes * 256
    if maxPossible == 0 then return 0 end
    return math.max(0, fitness) / maxPossible
end

--- 目标位置寻路适应度
--- 目标：进化出能到达指定位置的行为程序
---@param vm VMState 执行完毕的虚拟机
---@param startPos table {x, y} 起始位置
---@param targetPos table {x, y} 目标位置
---@param finalPos table {x, y} 执行后实际位置
---@return number 适应度分数（越高越好）
function FitnessEvaluator.Pathfinding(vm, startPos, targetPos, finalPos)
    local startDist = math.sqrt(
        (targetPos.x - startPos.x) ^ 2 +
        (targetPos.y - startPos.y) ^ 2
    )
    local finalDist = math.sqrt(
        (targetPos.x - finalPos.x) ^ 2 +
        (targetPos.y - finalPos.y) ^ 2
    )

    if startDist == 0 then return 1.0 end

    -- 越接近目标分数越高
    local fitness = 1.0 - (finalDist / startDist)

    -- 到达目标的奖励
    if finalDist < 0.5 then
        fitness = fitness + 0.5
    end

    -- 步数效率奖励（用更少步数到达更好）
    local efficiency = 1.0 - (vm.steps / vm.maxSteps)
    fitness = fitness + efficiency * 0.1

    return math.min(1.0, math.max(0, fitness))
end

--- 收集物品适应度
--- 目标：进化出能收集尽可能多物品的行为程序
---@param vm VMState 执行完毕的虚拟机
---@param collected number 收集到的物品数量
---@param totalItems number 场景中物品总数
---@param damageTaken number 受到的伤害
---@return number 适应度分数（越高越好）
function FitnessEvaluator.ItemCollection(vm, collected, totalItems, damageTaken)
    if totalItems == 0 then return 0 end

    local collectRatio = collected / totalItems
    local damagePenalty = damageTaken * 0.01
    local stepEfficiency = 1.0 - (vm.steps / vm.maxSteps)

    local fitness = collectRatio * 0.7
                  + stepEfficiency * 0.2
                  - damagePenalty

    return math.min(1.0, math.max(0, fitness))
end

--- 生存适应度
--- 目标：进化出能存活尽可能久的行为程序
---@param vm VMState 执行完毕的虚拟机
---@param survivalTicks number 存活回合数
---@param maxTicks number 最大回合数
---@param healthRemaining number 剩余生命值
---@param maxHealth number 最大生命值
---@return number 适应度分数（越高越好）
function FitnessEvaluator.Survival(vm, survivalTicks, maxTicks, healthRemaining, maxHealth)
    local survivalRatio = survivalTicks / maxTicks
    local healthRatio = healthRemaining / maxHealth

    return survivalRatio * 0.6 + healthRatio * 0.4
end

--- 组合适应度（加权多目标）
---@param scores table 键值对 { [name] = score }
---@param weights table 键值对 { [name] = weight }
---@return number 加权总分
function FitnessEvaluator.Combined(scores, weights)
    local totalWeight = 0
    local weightedSum = 0
    for name, weight in pairs(weights) do
        local score = scores[name] or 0
        weightedSum = weightedSum + score * weight
        totalWeight = totalWeight + weight
    end
    if totalWeight == 0 then return 0 end
    return weightedSum / totalWeight
end

return FitnessEvaluator
```

### §6.3 自定义适应度函数

用户可以定义任意适应度函数，只要签名返回 `number`：

```lua
--- 自定义适应度函数示例：进化出能画正方形的程序
local function SquareDrawingFitness(vm)
    local trail = vm.env.trail or {}  -- 移动轨迹
    if #trail < 4 then return 0 end

    -- 检查轨迹是否形成正方形
    -- ... 自定义评估逻辑
    return score
end
```

---

## §7 遗传算法引擎（EvolutionEngine）

### §7.1 核心引擎

```lua
local EvolutionEngine = {}

--- 种群配置
---@class PopulationConfig
---@field populationSize number 种群大小（默认 100）
---@field genomeSize number 基因组长度（默认 50）
---@field mutationRate number 变异率（默认 0.05）
---@field crossoverRate number 交叉率（默认 0.7）
---@field eliteCount number 精英保留数量（默认 2）
---@field tournamentSize number 锦标赛选择的参赛个体数（默认 3）

--- 创建初始种群
---@param config PopulationConfig
---@return table 种群对象
function EvolutionEngine.CreatePopulation(config)
    config = config or {}
    local pop = {
        config = {
            populationSize = config.populationSize or 100,
            genomeSize = config.genomeSize or 50,
            mutationRate = config.mutationRate or 0.05,
            crossoverRate = config.crossoverRate or 0.7,
            eliteCount = config.eliteCount or 2,
            tournamentSize = config.tournamentSize or 3,
        },
        individuals = {},
        generation = 0,
        bestFitness = 0,
        bestGenome = nil,
        history = {},
    }

    -- 初始化随机个体
    for i = 1, pop.config.populationSize do
        pop.individuals[i] = {
            genome = GenomeEncoder.RandomGenome(pop.config.genomeSize),
            fitness = 0,
        }
    end

    return pop
end

--- 评估整个种群的适应度
---@param pop table 种群对象
---@param instructionSet table 指令集
---@param evaluateFunc function(genome, instructionSet) -> number
function EvolutionEngine.Evaluate(pop, instructionSet, evaluateFunc)
    for i = 1, #pop.individuals do
        local ind = pop.individuals[i]
        ind.fitness = evaluateFunc(ind.genome, instructionSet)
    end

    -- 按适应度排序（降序）
    table.sort(pop.individuals, function(a, b)
        return a.fitness > b.fitness
    end)

    -- 更新最佳记录
    local best = pop.individuals[1]
    if best.fitness > pop.bestFitness then
        pop.bestFitness = best.fitness
        -- 深复制最佳基因组
        pop.bestGenome = {}
        for i = 1, #best.genome do
            pop.bestGenome[i] = best.genome[i]
        end
    end

    -- 记录历史
    pop.history[#pop.history + 1] = {
        generation = pop.generation,
        bestFitness = best.fitness,
        avgFitness = EvolutionEngine._AverageFitness(pop),
    }
end

--- 进化到下一代
---@param pop table 种群对象
function EvolutionEngine.NextGeneration(pop)
    local cfg = pop.config
    local newIndividuals = {}

    -- 精英保留
    for i = 1, cfg.eliteCount do
        if i <= #pop.individuals then
            newIndividuals[i] = {
                genome = EvolutionEngine._CopyGenome(pop.individuals[i].genome),
                fitness = pop.individuals[i].fitness,
            }
        end
    end

    -- 生成剩余个体
    while #newIndividuals < cfg.populationSize do
        local parent1 = EvolutionEngine._TournamentSelect(pop)
        local parent2 = EvolutionEngine._TournamentSelect(pop)

        local childGenome
        if math.random() < cfg.crossoverRate then
            childGenome = EvolutionEngine._Crossover(parent1.genome, parent2.genome)
        else
            childGenome = EvolutionEngine._CopyGenome(parent1.genome)
        end

        EvolutionEngine._Mutate(childGenome, cfg.mutationRate)

        newIndividuals[#newIndividuals + 1] = {
            genome = childGenome,
            fitness = 0,
        }
    end

    pop.individuals = newIndividuals
    pop.generation = pop.generation + 1
end

--- 锦标赛选择
function EvolutionEngine._TournamentSelect(pop)
    local best = nil
    for i = 1, pop.config.tournamentSize do
        local idx = math.random(1, #pop.individuals)
        local candidate = pop.individuals[idx]
        if best == nil or candidate.fitness > best.fitness then
            best = candidate
        end
    end
    return best
end

--- 单点交叉
function EvolutionEngine._Crossover(genome1, genome2)
    local len = math.min(#genome1, #genome2)
    local point = math.random(1, len)
    local child = {}
    for i = 1, point do
        child[i] = genome1[i]
    end
    for i = point + 1, len do
        child[i] = genome2[i]
    end
    return child
end

--- 变异
function EvolutionEngine._Mutate(genome, rate)
    for i = 1, #genome do
        if math.random() < rate then
            genome[i] = math.random()  -- 完全随机替换
        end
    end
end

--- 深复制基因组
function EvolutionEngine._CopyGenome(genome)
    local copy = {}
    for i = 1, #genome do
        copy[i] = genome[i]
    end
    return copy
end

--- 计算种群平均适应度
function EvolutionEngine._AverageFitness(pop)
    local sum = 0
    for i = 1, #pop.individuals do
        sum = sum + pop.individuals[i].fitness
    end
    return sum / #pop.individuals
end

--- 获取当代最佳程序
---@param pop table 种群对象
---@param instructionSet table 指令集
---@return table[] 最佳程序的指令序列
function EvolutionEngine.GetBestProgram(pop, instructionSet)
    if pop.bestGenome then
        return GenomeEncoder.Decode(pop.bestGenome, instructionSet)
    end
    return {}
end

--- 获取进化统计信息
---@param pop table 种群对象
---@return table 统计信息
function EvolutionEngine.GetStats(pop)
    return {
        generation = pop.generation,
        bestFitness = pop.bestFitness,
        currentBestFitness = pop.individuals[1] and pop.individuals[1].fitness or 0,
        averageFitness = EvolutionEngine._AverageFitness(pop),
        populationSize = #pop.individuals,
        historyLength = #pop.history,
    }
end

return EvolutionEngine
```

### §7.2 选择策略对比

| 策略 | 优势 | 劣势 | 推荐场景 |
|------|------|------|---------|
| **锦标赛选择**（默认） | 选择压力可调（改变 tournamentSize） | — | 通用，推荐默认使用 |
| 轮盘赌选择 | 概率公平 | 超级个体可能垄断 | 适应度差异小时 |
| 排名选择 | 避免超级个体垄断 | 收敛较慢 | 需要多样性时 |
| 精英策略 | 保证不退化 | 可能陷入局部最优 | 始终配合使用 |

---

## §8 沙箱环境（SandboxEnv）

### §8.1 网格世界环境

最常用的沙箱环境——2D 网格世界：

```lua
local SandboxEnv = {}

--- 创建 2D 网格世界
---@param config table { width, height, walls, items, entities }
---@return table 沙箱环境对象
function SandboxEnv.CreateGrid(config)
    config = config or {}
    local width = config.width or 10
    local height = config.height or 10

    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = 0  -- 0=空地, 1=墙, 2=物品, 3=敌人, 4=目标
        end
    end

    -- 放置墙壁
    if config.walls then
        for i = 1, #config.walls do
            local w = config.walls[i]
            if w.y >= 1 and w.y <= height and w.x >= 1 and w.x <= width then
                grid[w.y][w.x] = 1
            end
        end
    end

    -- 放置物品
    if config.items then
        for i = 1, #config.items do
            local it = config.items[i]
            if it.y >= 1 and it.y <= height and it.x >= 1 and it.x <= width then
                grid[it.y][it.x] = 2
            end
        end
    end

    local env = {
        grid = grid,
        width = width,
        height = height,
        agentX = config.startX or 1,
        agentY = config.startY or 1,
        agentDir = config.startDir or 0,  -- 0=上, 1=右, 2=下, 3=左
        collected = 0,
        damage = 0,
        trail = {},
        totalItems = config.items and #config.items or 0,
        targetX = config.targetX or width,
        targetY = config.targetY or height,
    }

    -- 记录起始位置
    env.trail[1] = { x = env.agentX, y = env.agentY }

    -- 方向增量表
    local dirDelta = {
        [0] = { dx = 0, dy = -1 },  -- 上
        [1] = { dx = 1, dy = 0 },   -- 右
        [2] = { dx = 0, dy = 1 },   -- 下
        [3] = { dx = -1, dy = 0 },  -- 左
    }

    -- 绑定环境回调到虚拟机
    env.moveForward = function(vm)
        local d = dirDelta[env.agentDir]
        local nx = env.agentX + d.dx
        local ny = env.agentY + d.dy
        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
            if grid[ny][nx] ~= 1 then  -- 不是墙
                env.agentX = nx
                env.agentY = ny
                env.trail[#env.trail + 1] = { x = nx, y = ny }
            end
        end
    end

    env.moveBackward = function(vm)
        local d = dirDelta[env.agentDir]
        local nx = env.agentX - d.dx
        local ny = env.agentY - d.dy
        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
            if grid[ny][nx] ~= 1 then
                env.agentX = nx
                env.agentY = ny
                env.trail[#env.trail + 1] = { x = nx, y = ny }
            end
        end
    end

    env.turnLeft = function(vm)
        env.agentDir = (env.agentDir + 3) % 4
    end

    env.turnRight = function(vm)
        env.agentDir = (env.agentDir + 1) % 4
    end

    env.senseAhead = function(vm)
        local d = dirDelta[env.agentDir]
        local nx = env.agentX + d.dx
        local ny = env.agentY + d.dy
        if nx < 1 or nx > width or ny < 1 or ny > height then
            return 1  -- 边界视为墙
        end
        return grid[ny][nx]
    end

    env.senseDistance = function(vm)
        local dx = env.targetX - env.agentX
        local dy = env.targetY - env.agentY
        return math.floor(math.sqrt(dx * dx + dy * dy))
    end

    env.grab = function(vm)
        if grid[env.agentY][env.agentX] == 2 then
            grid[env.agentY][env.agentX] = 0
            env.collected = env.collected + 1
        end
    end

    env.attack = function(vm)
        local d = dirDelta[env.agentDir]
        local nx = env.agentX + d.dx
        local ny = env.agentY + d.dy
        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
            if grid[ny][nx] == 3 then  -- 敌人
                grid[ny][nx] = 0
            end
        end
    end

    return env
end

--- 重置沙箱环境
function SandboxEnv.ResetGrid(env, config)
    env.agentX = config.startX or 1
    env.agentY = config.startY or 1
    env.agentDir = config.startDir or 0
    env.collected = 0
    env.damage = 0
    env.trail = { { x = env.agentX, y = env.agentY } }

    -- 重置网格内容（需从配置重建）
    for y = 1, env.height do
        for x = 1, env.width do
            env.grid[y][x] = 0
        end
    end
    if config.walls then
        for i = 1, #config.walls do
            local w = config.walls[i]
            env.grid[w.y][w.x] = 1
        end
    end
    if config.items then
        for i = 1, #config.items do
            local it = config.items[i]
            env.grid[it.y][it.x] = 2
        end
    end
end

return SandboxEnv
```

---

## §9 分帧进化（FrameDistributor）

### §9.1 为什么需要分帧

遗传算法的评估过程计算量大，如果在单帧中评估整个种群会导致帧率暴跌。
分帧进化器将评估工作分散到多帧中执行：

```lua
local FrameDistributor = {}

--- 创建分帧进化管理器
---@param config table { evaluationsPerFrame, onGenerationComplete }
---@return table 管理器对象
function FrameDistributor.Create(config)
    config = config or {}
    return {
        evaluationsPerFrame = config.evaluationsPerFrame or 5,
        currentIndex = 1,
        isEvaluating = true,
        onGenerationComplete = config.onGenerationComplete or function(pop) end,
        population = nil,
        instructionSet = nil,
        evaluateFunc = nil,
    }
end

--- 绑定种群和评估函数
function FrameDistributor.Bind(mgr, pop, instructionSet, evaluateFunc)
    mgr.population = pop
    mgr.instructionSet = instructionSet
    mgr.evaluateFunc = evaluateFunc
    mgr.currentIndex = 1
    mgr.isEvaluating = true
end

--- 每帧调用——在 HandleUpdate 中调用
---@param mgr table 管理器对象
function FrameDistributor.Tick(mgr)
    if not mgr.isEvaluating or not mgr.population then return end

    local pop = mgr.population
    local endIndex = math.min(
        mgr.currentIndex + mgr.evaluationsPerFrame - 1,
        #pop.individuals
    )

    for i = mgr.currentIndex, endIndex do
        local ind = pop.individuals[i]
        ind.fitness = mgr.evaluateFunc(ind.genome, mgr.instructionSet)
    end

    mgr.currentIndex = endIndex + 1

    -- 整代评估完成
    if mgr.currentIndex > #pop.individuals then
        -- 排序
        table.sort(pop.individuals, function(a, b)
            return a.fitness > b.fitness
        end)

        -- 更新最佳记录
        local best = pop.individuals[1]
        if best.fitness > pop.bestFitness then
            pop.bestFitness = best.fitness
            pop.bestGenome = EvolutionEngine._CopyGenome(best.genome)
        end

        pop.history[#pop.history + 1] = {
            generation = pop.generation,
            bestFitness = best.fitness,
            avgFitness = EvolutionEngine._AverageFitness(pop),
        }

        -- 通知回调
        mgr.onGenerationComplete(pop)

        -- 进化下一代并重新开始评估
        EvolutionEngine.NextGeneration(pop)
        mgr.currentIndex = 1
    end
end

--- 暂停进化
function FrameDistributor.Pause(mgr)
    mgr.isEvaluating = false
end

--- 恢复进化
function FrameDistributor.Resume(mgr)
    mgr.isEvaluating = true
end

return FrameDistributor
```

### §9.2 在游戏主循环中集成

```lua
-- scripts/main.lua
require "LuaScripts/Utilities/Sample"

-- 加载模块（均在 scripts/ 目录下）
local InstructionSet = require("scripts.InstructionSet")
local GenomeEncoder = require("scripts.GenomeEncoder")
local Interpreter = require("scripts.Interpreter")
local FitnessEvaluator = require("scripts.FitnessEvaluator")
local EvolutionEngine = require("scripts.EvolutionEngine")
local SandboxEnv = require("scripts.SandboxEnv")
local FrameDistributor = require("scripts.FrameDistributor")

local population
local evolver
local iSet = InstructionSet.GAME_ACTION

function Start()
    -- 创建种群
    population = EvolutionEngine.CreatePopulation({
        populationSize = 50,
        genomeSize = 80,
        mutationRate = 0.05,
        eliteCount = 2,
    })

    -- 评估函数
    local function evaluate(genome, instrSet)
        local program = GenomeEncoder.Decode(genome, instrSet)
        local gridConfig = {
            width = 8, height = 8,
            startX = 1, startY = 1,
            targetX = 8, targetY = 8,
            walls = { {x=3,y=2}, {x=3,y=3}, {x=3,y=4} },
        }
        local env = SandboxEnv.CreateGrid(gridConfig)
        local vm = Interpreter.CreateVM({
            maxSteps = 500,
            env = env,
        })
        Interpreter.Execute(program, vm)
        return FitnessEvaluator.Pathfinding(
            vm,
            { x = gridConfig.startX, y = gridConfig.startY },
            { x = gridConfig.targetX, y = gridConfig.targetY },
            { x = env.agentX, y = env.agentY }
        )
    end

    -- 创建分帧管理器
    evolver = FrameDistributor.Create({
        evaluationsPerFrame = 10,
        onGenerationComplete = function(pop)
            local stats = EvolutionEngine.GetStats(pop)
            log:Write(LOG_INFO, string.format(
                "Gen %d | Best: %.4f | Avg: %.4f",
                stats.generation, stats.bestFitness, stats.averageFitness
            ))
        end,
    })
    FrameDistributor.Bind(evolver, population, iSet, evaluate)

    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    FrameDistributor.Tick(evolver)
end
```

---

## §10 持久化（GenomePersistence）

### §10.1 保存与加载进化状态

```lua
local GenomePersistence = {}

--- 保存种群到 JSON 文件
---@param pop table 种群对象
---@param filename string 文件名（相对路径，存放在 scripts/ 下）
function GenomePersistence.Save(pop, filename)
    local cjson = require("cjson")

    local data = {
        generation = pop.generation,
        bestFitness = pop.bestFitness,
        bestGenome = pop.bestGenome,
        config = pop.config,
        history = pop.history,
        individuals = {},
    }

    for i = 1, #pop.individuals do
        data.individuals[i] = {
            genome = pop.individuals[i].genome,
            fitness = pop.individuals[i].fitness,
        }
    end

    local jsonStr = cjson.encode(data)
    local file = File:new(filename, FILE_WRITE)
    if file then
        file:WriteString(jsonStr)
        file:Close()
        log:Write(LOG_INFO, "GenomePersistence: saved to " .. filename)
    end
end

--- 从 JSON 文件加载种群
---@param filename string 文件名
---@return table? 种群对象（失败返回 nil）
function GenomePersistence.Load(filename)
    local cjson = require("cjson")

    if not fileSystem:FileExists(filename) then
        log:Write(LOG_WARNING, "GenomePersistence: file not found: " .. filename)
        return nil
    end

    local file = File:new(filename, FILE_READ)
    if not file then return nil end

    local jsonStr = file:ReadString()
    file:Close()

    local data = cjson.decode(jsonStr)
    if not data then return nil end

    local pop = {
        config = data.config,
        individuals = {},
        generation = data.generation or 0,
        bestFitness = data.bestFitness or 0,
        bestGenome = data.bestGenome,
        history = data.history or {},
    }

    for i = 1, #data.individuals do
        pop.individuals[i] = {
            genome = data.individuals[i].genome,
            fitness = data.individuals[i].fitness or 0,
        }
    end

    log:Write(LOG_INFO, string.format(
        "GenomePersistence: loaded gen %d, best fitness %.4f",
        pop.generation, pop.bestFitness
    ))
    return pop
end

--- 导出最佳程序为可读文本
---@param pop table 种群对象
---@param instructionSet table 指令集
---@return string 可读程序文本
function GenomePersistence.ExportBestProgram(pop, instructionSet)
    if not pop.bestGenome then return "(no best genome)" end
    local program = GenomeEncoder.Decode(pop.bestGenome, instructionSet)
    local lines = {}
    lines[1] = "-- Best program (generation " .. pop.generation .. ", fitness " ..
               string.format("%.4f", pop.bestFitness) .. ")"
    lines[2] = "-- Instruction count: " .. #program
    lines[3] = "-- Symbol string: " .. GenomeEncoder.ProgramToString(program)
    lines[4] = ""
    for i = 1, #program do
        lines[#lines + 1] = string.format(
            "%3d: %-15s  %s", i, program[i].name, program[i].desc
        )
    end
    return table.concat(lines, "\n")
end

return GenomePersistence
```

---

## §11 完整游戏集成示例：NPC 寻路进化

以下示例展示如何在 UrhoX Lua 游戏中使用遗传编程自动进化 NPC 行为：

```lua
-- scripts/main.lua
-- NPC 寻路行为进化演示
-- 使用遗传算法进化出能导航网格迷宫的 NPC 行为程序

require "LuaScripts/Utilities/Sample"

------------------------------------------------------------
-- 模块引用（所有模块均在 scripts/ 目录下）
------------------------------------------------------------

-- 内联简化版模块（完整版参见 §3-§10 各模块文件）

------------------------------------------------------------
-- 指令集
------------------------------------------------------------
local INSTR_SET = {
    { id = 0, symbol = "F", name = "move_forward",  desc = "向前移动" },
    { id = 1, symbol = "B", name = "move_backward", desc = "向后移动" },
    { id = 2, symbol = "L", name = "turn_left",     desc = "左转" },
    { id = 3, symbol = "R", name = "turn_right",    desc = "右转" },
    { id = 4, symbol = "S", name = "sense_ahead",   desc = "探测前方" },
    { id = 5, symbol = "[", name = "loop_start",    desc = "循环开始" },
    { id = 6, symbol = "]", name = "loop_end",      desc = "循环结束" },
    { id = 7, symbol = "W", name = "wait",          desc = "等待" },
}

------------------------------------------------------------
-- 迷宫配置
------------------------------------------------------------
local MAZE = {
    width = 10, height = 10,
    startX = 1, startY = 1,
    targetX = 10, targetY = 10,
    walls = {
        {x=3,y=1},{x=3,y=2},{x=3,y=3},{x=3,y=4},
        {x=5,y=6},{x=5,y=7},{x=5,y=8},{x=5,y=9},
        {x=7,y=2},{x=7,y=3},{x=7,y=4},{x=7,y=5},
        {x=8,y=8},{x=9,y=8},{x=10,y=8},
    },
}

------------------------------------------------------------
-- 全局状态
------------------------------------------------------------
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local population = nil
local generationCount = 0
local bestFitness = 0
local bestTrail = {}
local isEvolving = true

------------------------------------------------------------
-- 场景搭建
------------------------------------------------------------
function Start()
    SampleStart()

    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(5.5, 15, 5.5)
    cameraNode_.rotation = Quaternion(90, Vector3.RIGHT)
    local camera = cameraNode_:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = 14

    -- 光源
    local lightNode = scene_:CreateChild("Light")
    lightNode.rotation = Quaternion(60, 30, 0)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL

    -- 渲染设置
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)

    -- 搭建迷宫可视化（使用 Box 模型）
    CreateMazeVisualization()

    -- 初始化种群
    InitEvolution()

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function CreateMazeVisualization()
    -- 地面
    for y = 1, MAZE.height do
        for x = 1, MAZE.width do
            local tileNode = scene_:CreateChild("Tile")
            tileNode.position = Vector3(x, -0.25, y)
            tileNode.scale = Vector3(0.95, 0.5, 0.95)
            local model = tileNode:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

            local mat = Material:new()
            mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
            mat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.6, 0.2, 1.0)))
            model:SetMaterial(mat)
        end
    end

    -- 墙壁
    for i = 1, #MAZE.walls do
        local w = MAZE.walls[i]
        local wallNode = scene_:CreateChild("Wall")
        wallNode.position = Vector3(w.x, 0.5, w.y)
        wallNode.scale = Vector3(0.95, 1.0, 0.95)
        local model = wallNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.3, 0.2, 1.0)))
        model:SetMaterial(mat)
    end

    -- 目标标记
    local targetNode = scene_:CreateChild("Target")
    targetNode.position = Vector3(MAZE.targetX, 0.5, MAZE.targetY)
    targetNode.scale = Vector3(0.5, 0.5, 0.5)
    local model = targetNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.8, 0.0, 1.0)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.5, 0.4, 0.0, 1.0)))
    model:SetMaterial(mat)
end

------------------------------------------------------------
-- 进化逻辑
------------------------------------------------------------

function InitEvolution()
    math.randomseed(time:GetSystemTime())
    population = {}
    local POP_SIZE = 60
    local GENOME_SIZE = 60

    for i = 1, POP_SIZE do
        local genome = {}
        for j = 1, GENOME_SIZE do
            genome[j] = math.random()
        end
        population[i] = { genome = genome, fitness = 0 }
    end
end

--- 解码基因组为指令序列
local function DecodeGenome(genome)
    local program = {}
    local setSize = #INSTR_SET
    for i = 1, #genome do
        local index = (math.floor(math.abs(genome[i]) * 1000000) % setSize) + 1
        program[i] = INSTR_SET[index]
    end
    return program
end

--- 在网格中模拟执行程序
local function SimulateProgram(program)
    -- 创建网格
    local grid = {}
    for y = 1, MAZE.height do
        grid[y] = {}
        for x = 1, MAZE.width do
            grid[y][x] = 0
        end
    end
    for i = 1, #MAZE.walls do
        grid[MAZE.walls[i].y][MAZE.walls[i].x] = 1
    end

    local ax, ay, adir = MAZE.startX, MAZE.startY, 0
    local trail = { { x = ax, y = ay } }
    local dirDx = { [0] = 0, [1] = 1, [2] = 0, [3] = -1 }
    local dirDy = { [0] = -1, [1] = 0, [2] = 1, [3] = 0 }

    -- 简化 VM
    local mem = {}
    for i = 1, 32 do mem[i] = 0 end
    local ptr = 1
    local pc = 1
    local steps = 0
    local maxSteps = 500

    while pc >= 1 and pc <= #program and steps < maxSteps do
        steps = steps + 1
        local instr = program[pc]
        local name = instr.name

        if name == "move_forward" then
            local nx = ax + dirDx[adir]
            local ny = ay + dirDy[adir]
            if nx >= 1 and nx <= MAZE.width and ny >= 1 and ny <= MAZE.height then
                if grid[ny][nx] ~= 1 then
                    ax, ay = nx, ny
                    trail[#trail + 1] = { x = ax, y = ay }
                end
            end
        elseif name == "move_backward" then
            local nx = ax - dirDx[adir]
            local ny = ay - dirDy[adir]
            if nx >= 1 and nx <= MAZE.width and ny >= 1 and ny <= MAZE.height then
                if grid[ny][nx] ~= 1 then
                    ax, ay = nx, ny
                    trail[#trail + 1] = { x = ax, y = ay }
                end
            end
        elseif name == "turn_left" then
            adir = (adir + 3) % 4
        elseif name == "turn_right" then
            adir = (adir + 1) % 4
        elseif name == "sense_ahead" then
            local nx = ax + dirDx[adir]
            local ny = ay + dirDy[adir]
            if nx < 1 or nx > MAZE.width or ny < 1 or ny > MAZE.height then
                mem[ptr] = 1
            else
                mem[ptr] = grid[ny][nx]
            end
        elseif name == "loop_start" then
            if mem[ptr] == 0 then
                local depth = 1
                while depth > 0 and pc < #program do
                    pc = pc + 1
                    if program[pc].name == "loop_start" then depth = depth + 1
                    elseif program[pc].name == "loop_end" then depth = depth - 1
                    end
                end
            end
        elseif name == "loop_end" then
            if mem[ptr] ~= 0 then
                local depth = 1
                while depth > 0 and pc > 1 do
                    pc = pc - 1
                    if program[pc].name == "loop_end" then depth = depth + 1
                    elseif program[pc].name == "loop_start" then depth = depth - 1
                    end
                end
                pc = pc - 1
            end
        -- wait = 空操作
        end

        pc = pc + 1
    end

    return ax, ay, trail, steps
end

--- 适应度评估
local function EvaluateFitness(genome)
    local program = DecodeGenome(genome)
    local ax, ay, trail, steps = SimulateProgram(program)

    local startDist = math.sqrt(
        (MAZE.targetX - MAZE.startX) ^ 2 + (MAZE.targetY - MAZE.startY) ^ 2
    )
    local finalDist = math.sqrt(
        (MAZE.targetX - ax) ^ 2 + (MAZE.targetY - ay) ^ 2
    )

    local fitness = 0
    if startDist > 0 then
        fitness = (1.0 - finalDist / startDist) * 0.8
    end
    if finalDist < 0.5 then
        fitness = fitness + 0.5
    end
    local eff = 1.0 - (steps / 500)
    fitness = fitness + eff * 0.1

    return math.max(0, fitness), trail
end

--- 进化一代（分帧变量）
local evalIndex = 1
local evalPhase = "evaluate"  -- "evaluate" 或 "breed"
local tempTrails = {}

local EVALS_PER_FRAME = 10

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if not isEvolving then return end

    if evalPhase == "evaluate" then
        local endIdx = math.min(evalIndex + EVALS_PER_FRAME - 1, #population)
        for i = evalIndex, endIdx do
            local fit, trail = EvaluateFitness(population[i].genome)
            population[i].fitness = fit
            tempTrails[i] = trail
        end
        evalIndex = endIdx + 1

        if evalIndex > #population then
            -- 排序
            -- 先标记 trail
            for i = 1, #population do
                population[i]._trail = tempTrails[i]
            end
            table.sort(population, function(a, b) return a.fitness > b.fitness end)

            if population[1].fitness > bestFitness then
                bestFitness = population[1].fitness
                bestTrail = population[1]._trail or {}
            end

            generationCount = generationCount + 1
            evalPhase = "breed"
        end

    elseif evalPhase == "breed" then
        -- 选择 + 交叉 + 变异
        local newPop = {}

        -- 精英保留
        for i = 1, 2 do
            local g = {}
            for j = 1, #population[i].genome do g[j] = population[i].genome[j] end
            newPop[i] = { genome = g, fitness = 0 }
        end

        while #newPop < #population do
            -- 锦标赛选择
            local function tournamentSelect()
                local best = population[math.random(1, #population)]
                for t = 1, 2 do
                    local cand = population[math.random(1, #population)]
                    if cand.fitness > best.fitness then best = cand end
                end
                return best
            end

            local p1 = tournamentSelect()
            local p2 = tournamentSelect()

            -- 交叉
            local child = {}
            local gLen = #p1.genome
            if math.random() < 0.7 then
                local pt = math.random(1, gLen)
                for j = 1, pt do child[j] = p1.genome[j] end
                for j = pt + 1, gLen do child[j] = p2.genome[j] end
            else
                for j = 1, gLen do child[j] = p1.genome[j] end
            end

            -- 变异
            for j = 1, #child do
                if math.random() < 0.05 then
                    child[j] = math.random()
                end
            end

            newPop[#newPop + 1] = { genome = child, fitness = 0 }
        end

        population = newPop
        tempTrails = {}
        evalIndex = 1
        evalPhase = "evaluate"
    end
end

------------------------------------------------------------
-- NanoVG HUD 渲染
------------------------------------------------------------
function HandleNanoVGRender(eventType, eventData)
    local vg = GetNanoVGContext()
    if not vg then return end

    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local lw = w / dpr
    local lh = h / dpr

    nvgBeginFrame(vg, lw, lh, dpr)

    -- 信息面板背景
    nvgBeginPath(vg)
    nvgRect(vg, 10, 10, 280, 100)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
    nvgFill(vg)

    -- 文本
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, 20, 35, string.format("Generation: %d", generationCount))
    nvgText(vg, 20, 55, string.format("Best Fitness: %.4f", bestFitness))
    nvgText(vg, 20, 75, string.format("Population: %d", #population))
    nvgText(vg, 20, 95, string.format("Trail Length: %d", #bestTrail))

    nvgEndFrame(vg)
end
```

---

## §12 应用场景汇总

| 游戏场景 | 指令集层级 | 适应度函数 | 说明 |
|---------|-----------|-----------|------|
| **字符串输出演示** | Tier-1 Core | StringMatch | 经典 AI-Programmer 复刻 |
| **NPC 迷宫寻路** | Tier-2 GameAction | Pathfinding | NPC 自动学会导航 |
| **物品收集 AI** | Tier-2 GameAction | ItemCollection | 进化出收集策略 |
| **生存 AI** | Tier-2 GameAction | Survival | 进化出躲避/战斗策略 |
| **编队协作** | Tier-3 Extended | Combined | 多实体通讯协作 |
| **关卡解法搜索** | Tier-2 GameAction | 自定义 | 自动找出通关策略 |
| **虚拟生态** | Tier-3 Extended | Combined | 生物行为涌现 |
| **玩法教学演示** | Tier-1 Core | StringMatch | 遗传算法科普展示 |

---

## §13 与其他 Skill 的协作

| 协作 Skill | 协作方式 |
|-----------|---------|
| `evolutionary-game-systems` | 本 Skill 进化程序，该 Skill 进化参数；可组合使用 |
| `behavior-tree-ai` | 行为树提供框架，进化出的程序填充叶节点行为 |
| `procedural-generation` | 进化出的程序可驱动 PCG 参数选择 |
| `game-balancing` | 用进化搜索自动寻找平衡参数组合 |
| `gaia-npc-ai` | 进化出基础行为，Gaia 做高层决策 |

---

## §14 构建与调试

### §14.1 项目文件结构

```
scripts/
  main.lua                 -- 游戏入口
  evolution/
    InstructionSet.lua     -- 指令集定义
    GenomeEncoder.lua      -- 基因组编解码
    Interpreter.lua        -- 虚拟机解释器
    FitnessEvaluator.lua   -- 适应度评估
    EvolutionEngine.lua    -- 遗传算法引擎
    SandboxEnv.lua         -- 沙箱环境
    FrameDistributor.lua   -- 分帧进化管理
    GenomePersistence.lua  -- 持久化管理
```

### §14.2 构建步骤

1. 将所有模块文件放在 `scripts/` 目录下
2. 在 `main.lua` 中引用各模块
3. 调用 UrhoX 构建工具进行构建
4. 预览测试进化效果

### §14.3 调试建议

| 问题 | 排查方向 |
|------|---------|
| 适应度长期不提高 | 检查变异率是否太低；增大种群；简化指令集 |
| 帧率下降 | 减小 `evaluationsPerFrame`；减小 `maxSteps` |
| 程序全是空操作 | 检查适应度函数是否给出有意义的梯度 |
| 收敛到局部最优 | 增大变异率；使用更大锦标赛尺寸 |
| 存档加载后行为不同 | 确认随机种子一致；检查环境配置是否完全相同 |

### §14.4 性能调优参数

| 参数 | 低配设备 | 中配设备 | 高配设备 |
|------|---------|---------|---------|
| `populationSize` | 20-30 | 50-100 | 100-500 |
| `genomeSize` | 30-50 | 50-100 | 100-300 |
| `evaluationsPerFrame` | 2-5 | 5-15 | 15-50 |
| `maxSteps` | 200 | 500 | 2000 |

---

## §15 设计原则：AI-Programmer 到游戏的映射

| AI-Programmer 原版 | 游戏化适配 |
|-------------------|-----------|
| Brainfuck 指令集 | 分层游戏指令集（Core/GameAction/Extended） |
| 控制台输出匹配 | 多种游戏适应度函数（寻路/收集/生存/组合） |
| 整代同步评估 | 分帧异步评估（不阻塞游戏主循环） |
| C# 实现 | 纯 Lua 实现，运行在 UrhoX 引擎中 |
| 单一进化目标 | 多目标加权适应度组合 |
| 无可视化 | 3D/2D 场景可视化 + NanoVG HUD |
| 进化结果仅打印 | JSON 持久化存档 + 可导出程序文本 |
| 无运行时环境 | 可扩展沙箱环境（网格世界 + 自定义） |

---

## §16 API 速查表

### GenomeEncoder

| 方法 | 签名 | 说明 |
|------|------|------|
| `Decode` | `(genome, instructionSet) → program` | 浮点基因组 → 指令序列 |
| `Encode` | `(program, instructionSet) → genome` | 指令序列 → 浮点基因组 |
| `RandomGenome` | `(size) → genome` | 生成随机基因组 |
| `ProgramToString` | `(program) → string` | 指令序列 → 符号串 |

### Interpreter

| 方法 | 签名 | 说明 |
|------|------|------|
| `CreateVM` | `(config?) → VMState` | 创建虚拟机 |
| `Execute` | `(program, vm) → VMState` | 执行程序 |
| `GetOutputString` | `(vm) → string` | 获取输出字符串 |
| `Reset` | `(vm) → void` | 重置虚拟机状态 |

### FitnessEvaluator

| 方法 | 签名 | 说明 |
|------|------|------|
| `StringMatch` | `(vm, targetString) → number` | 字符串匹配适应度 |
| `Pathfinding` | `(vm, startPos, targetPos, finalPos) → number` | 寻路适应度 |
| `ItemCollection` | `(vm, collected, total, damage) → number` | 物品收集适应度 |
| `Survival` | `(vm, ticks, maxTicks, hp, maxHp) → number` | 生存适应度 |
| `Combined` | `(scores, weights) → number` | 多目标加权组合 |

### EvolutionEngine

| 方法 | 签名 | 说明 |
|------|------|------|
| `CreatePopulation` | `(config) → pop` | 创建种群 |
| `Evaluate` | `(pop, instrSet, evalFunc) → void` | 评估整代适应度 |
| `NextGeneration` | `(pop) → void` | 生成下一代 |
| `GetBestProgram` | `(pop, instrSet) → program` | 获取最佳程序 |
| `GetStats` | `(pop) → stats` | 获取进化统计 |

### SandboxEnv

| 方法 | 签名 | 说明 |
|------|------|------|
| `CreateGrid` | `(config) → env` | 创建网格世界 |
| `ResetGrid` | `(env, config) → void` | 重置网格 |

### FrameDistributor

| 方法 | 签名 | 说明 |
|------|------|------|
| `Create` | `(config) → mgr` | 创建分帧管理器 |
| `Bind` | `(mgr, pop, instrSet, evalFunc) → void` | 绑定评估任务 |
| `Tick` | `(mgr) → void` | 每帧执行（在 Update 中调用） |
| `Pause` / `Resume` | `(mgr) → void` | 暂停/恢复进化 |

### GenomePersistence

| 方法 | 签名 | 说明 |
|------|------|------|
| `Save` | `(pop, filename) → void` | 保存种群到 JSON |
| `Load` | `(filename) → pop?` | 从 JSON 加载种群 |
| `ExportBestProgram` | `(pop, instrSet) → string` | 导出最佳程序文本 |

### InstructionSet

| 常量 / 方法 | 说明 |
|-------------|------|
| `CORE` | Tier-1 Core 指令集（8 条） |
| `GAME_ACTION` | Tier-2 GameAction 指令集（16 条） |
| `EXTENDED` | Tier-3 Extended 指令集（24 条） |
| `Extend(base, extra)` | 自定义扩展指令集 |
| `GetSize(set)` | 获取指令集大小 |
