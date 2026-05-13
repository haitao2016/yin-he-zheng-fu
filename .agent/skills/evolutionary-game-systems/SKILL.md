---
name: evolutionary-game-systems
description: "Evolutionary algorithm and genetic programming patterns for UrhoX Lua games, covering genetic algorithm framework, procedural content generation via evolution, NPC AI behavior evolution, dynamic difficulty adjustment, and game parameter auto-tuning. Use when users need to (1) implement genetic algorithms for game content generation, (2) evolve NPC or enemy AI behaviors adaptively, (3) create dynamic difficulty adjustment that adapts to player skill, (4) auto-tune game balance parameters like damage/health/speed, (5) generate procedural levels/items/enemies using evolutionary selection, (6) implement mutation and crossover operators for game entities, (7) build self-adapting game systems that improve over play sessions, (8) create creature/character evolution mechanics as gameplay features, (9) optimize game configurations using evolutionary search, or any other evolutionary/genetic algorithm tasks in game development."
---

# Evolutionary Game Systems

Genetic algorithm (GA) and evolutionary computation patterns adapted for UrhoX Lua game development. Derived from GEP (Genome Evolution Protocol) concepts: structured evolution with genes, mutations, fitness evaluation, and strategy presets.

## Core Concepts Mapping

| Evolution Concept | Game Development Adaptation |
|---|---|
| Gene | Encodable game parameter (stat, behavior weight, layout cell) |
| Chromosome | Complete entity configuration (enemy build, level layout, AI profile) |
| Population | Pool of candidate solutions being evaluated |
| Fitness Function | Game-specific quality metric (playability, fun, balance, survival) |
| Selection | Choose parents based on fitness (tournament, roulette, elitist) |
| Crossover | Combine two parent chromosomes to produce offspring |
| Mutation | Random perturbation of gene values |
| Generation | One full cycle of evaluate, select, breed, mutate |
| Strategy Preset | Evolution behavior mode (explore/exploit/diversify/repair) |

## When to Apply

| User Request | Pattern to Use | Reference |
|---|---|---|
| Generate random but balanced levels | PCG with GA | references/procedural-generation.md |
| Make enemies adapt to player | NPC AI Evolution | references/adaptive-ai.md |
| Auto-balance game difficulty | DDA System | references/adaptive-ai.md DDA section |
| Evolve creature stats/builds | GA as Gameplay | references/ga-core.md |
| Find optimal game parameters | Parameter Tuning | references/ga-core.md Tuning section |
| Procedural item/weapon generation | PCG with GA | references/procedural-generation.md |

## Quick Start: Minimal GA

```lua
local GA = {}

function GA.createPopulation(size, geneCount, ranges)
    local pop = {}
    for i = 1, size do
        local genes = {}
        for g = 1, geneCount do
            local r = ranges[g] or {0, 1}
            genes[g] = r[1] + math.random() * (r[2] - r[1])
        end
        pop[i] = { genes = genes, fitness = 0 }
    end
    return pop
end

function GA.evaluate(pop, fitnessFn)
    for i = 1, #pop do
        pop[i].fitness = fitnessFn(pop[i].genes)
    end
    table.sort(pop, function(a, b) return a.fitness > b.fitness end)
end

function GA.select(pop, tournamentSize)
    tournamentSize = tournamentSize or 3
    local best = pop[math.random(1, #pop)]
    for _ = 2, tournamentSize do
        local c = pop[math.random(1, #pop)]
        if c.fitness > best.fitness then best = c end
    end
    return best
end

function GA.crossover(p1, p2)
    local genes = {}
    local point = math.random(1, #p1.genes)
    for i = 1, #p1.genes do
        genes[i] = (i <= point) and p1.genes[i] or p2.genes[i]
    end
    return { genes = genes, fitness = 0 }
end

function GA.mutate(ind, rate, ranges)
    for i = 1, #ind.genes do
        if math.random() < rate then
            local r = ranges[i] or {0, 1}
            local delta = (r[2] - r[1]) * 0.1 * (math.random() * 2 - 1)
            ind.genes[i] = math.max(r[1], math.min(r[2], ind.genes[i] + delta))
        end
    end
end

function GA.evolve(pop, fitnessFn, ranges, opts)
    opts = opts or {}
    local eliteCount = opts.eliteCount or 2
    local mutationRate = opts.mutationRate or 0.1
    local tournamentSize = opts.tournamentSize or 3
    GA.evaluate(pop, fitnessFn)
    local newPop = {}
    for i = 1, math.min(eliteCount, #pop) do
        newPop[i] = { genes = {table.unpack(pop[i].genes)}, fitness = pop[i].fitness }
    end
    while #newPop < #pop do
        local p1 = GA.select(pop, tournamentSize)
        local p2 = GA.select(pop, tournamentSize)
        local child = GA.crossover(p1, p2)
        GA.mutate(child, mutationRate, ranges)
        newPop[#newPop + 1] = child
    end
    return newPop
end
```

Usage in game Update loop (non-blocking, one generation per frame):

```lua
local pop, ranges, gen = nil, nil, 0
local MAX_GEN = 50

function StartEvolution()
    ranges = { {1, 100}, {0.5, 5.0}, {10, 50} }  -- hp, speed, damage
    pop = GA.createPopulation(30, 3, ranges)
    gen = 0
end

function HandleUpdate(eventType, eventData)
    if pop and gen < MAX_GEN then
        pop = GA.evolve(pop, function(genes)
            local hp, speed, damage = genes[1], genes[2], genes[3]
            return math.min(hp, 80) + speed * 10 - math.abs(damage - 25)
        end, ranges, { mutationRate = 0.15 })
        gen = gen + 1
        if gen == MAX_GEN then
            local best = pop[1]
            print(string.format("Best after %d gen: HP=%.0f SPD=%.1f DMG=%.0f fit=%.1f",
                gen, best.genes[1], best.genes[2], best.genes[3], best.fitness))
        end
    end
end
```

## Strategy Presets

Control evolution behavior with presets (adapted from GEP strategy system):

| Preset | mutationRate | eliteCount | tournamentSize | Use Case |
|---|---|---|---|---|
| explore | 0.25 | 1 | 2 | Early search, maximize diversity |
| exploit | 0.05 | 4 | 5 | Converge on known good solutions |
| balanced | 0.10 | 2 | 3 | Default, general-purpose |
| diversify | 0.30 | 0 | 2 | Escape local optima, restart search |

```lua
local PRESETS = {
    explore   = { mutationRate = 0.25, eliteCount = 1, tournamentSize = 2 },
    exploit   = { mutationRate = 0.05, eliteCount = 4, tournamentSize = 5 },
    balanced  = { mutationRate = 0.10, eliteCount = 2, tournamentSize = 3 },
    diversify = { mutationRate = 0.30, eliteCount = 0, tournamentSize = 2 },
}

local stagnantGens = 0
local lastBestFitness = -math.huge

function getAdaptivePreset(bestFitness)
    if math.abs(bestFitness - lastBestFitness) < 0.01 then
        stagnantGens = stagnantGens + 1
    else
        stagnantGens = 0
    end
    lastBestFitness = bestFitness
    if stagnantGens > 10 then
        stagnantGens = 0
        return PRESETS.diversify
    elseif stagnantGens > 5 then
        return PRESETS.explore
    else
        return PRESETS.balanced
    end
end
```

## Convergence and Signal De-duplication

Prevent wasted cycles when evolution is stuck (adapted from evolver signal de-duplication):

```lua
function checkConvergence(pop, threshold)
    threshold = threshold or 0.01
    if #pop < 2 then return true end
    local geneCount = #pop[1].genes
    for g = 1, geneCount do
        local minVal, maxVal = math.huge, -math.huge
        for i = 1, #pop do
            minVal = math.min(minVal, pop[i].genes[g])
            maxVal = math.max(maxVal, pop[i].genes[g])
        end
        if (maxVal - minVal) > threshold then return false end
    end
    return true
end

function injectDiversity(pop, count, ranges)
    local fresh = GA.createPopulation(count, #ranges, ranges)
    for i = 1, count do
        pop[#pop - i + 1] = fresh[i]
    end
end
```

## Performance Rules (UrhoX Specific)

### MUST DO
- Run evolution in budgeted frames: limit to 1 generation per frame for populations under 100
- For populations over 100, spread evaluation across multiple frames
- Use math.random() for all random operations
- Store evolution state in module-level variables, not globals
- Keep gene arrays as flat Lua tables of numbers for speed
- Clamp all gene values to valid ranges after mutation

### MUST NOT DO
- Do NOT run multi-generation loops in a single HandleUpdate: blocks rendering
- Do NOT allocate new tables every frame: reuse population tables
- Do NOT use graphics:SetMode(): it is disabled in UrhoX
- Do NOT use string-keyed gene tables: use numeric arrays for performance
- Do NOT evolve during gameplay-critical frames
- Do NOT assume array index 0 exists: Lua arrays start at 1

### Frame Budget Pattern

```lua
local evolutionBudgetMs = 2.0
local evolutionTimer = 0

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    evolutionTimer = evolutionTimer + dt
    if evolutionTimer >= 0.05 then  -- evolve at 20Hz max
        evolutionTimer = 0
        local startTime = os.clock()
        pop = GA.evolve(pop, fitnessFunc, ranges, currentPreset)
        local elapsed = (os.clock() - startTime) * 1000
        if elapsed > evolutionBudgetMs then
            print(string.format("WARNING: Evolution took %.1fms (budget: %.1fms)",
                elapsed, evolutionBudgetMs))
        end
    end
end
```

## Reference Files

| File | Content | When to Read |
|---|---|---|
| references/ga-core.md | Complete GA module with selection/crossover/mutation variants, parameter tuning workflow | Implementing any GA system |
| references/procedural-generation.md | Level/item/enemy PCG with evolution, fitness functions, encoding schemes | Generating game content via evolution |
| references/adaptive-ai.md | NPC behavior evolution, DDA system, player modeling, online adaptation | AI that adapts to players |

## Constraints

### MUST DO
- Validate gene ranges before evolution starts
- Provide a clear fitness function comment explaining what good means
- Use strategy presets for reproducible evolution behavior
- Log evolution progress (generation count, best fitness) during development
- Test fitness function independently before running full evolution

### MUST NOT DO
- Do NOT run evolution synchronously for more than 2ms per frame
- Do NOT use evolution for problems with known analytical solutions
- Do NOT store population state in _G global table
- Do NOT create closures inside evolution loops: pre-define fitness functions
