# GA Core Module Reference

> Complete genetic algorithm implementation patterns for UrhoX Lua games.

---

## 1. Minimal GA Skeleton

```lua
-- GA.lua — drop into scripts/
local GA = {}

function GA.createIndividual(geneCount, minVal, maxVal)
    local genes = {}
    for i = 1, geneCount do
        genes[i] = minVal + math.random() * (maxVal - minVal)
    end
    return { genes = genes, fitness = 0 }
end

function GA.createPopulation(size, geneCount, minVal, maxVal)
    local pop = {}
    for i = 1, size do
        pop[i] = GA.createIndividual(geneCount, minVal, maxVal)
    end
    return pop
end

function GA.evaluateAll(pop, fitnessFn)
    for i = 1, #pop do
        pop[i].fitness = fitnessFn(pop[i].genes)
    end
    table.sort(pop, function(a, b) return a.fitness > b.fitness end)
end

function GA.evolve(pop, opts)
    opts = opts or {}
    local selectFn   = opts.select   or GA.tournamentSelect
    local crossoverFn = opts.crossover or GA.singlePointCrossover
    local mutateFn    = opts.mutate   or GA.gaussianMutate
    local eliteCount  = opts.eliteCount or 2
    local mutRate     = opts.mutationRate or 0.1
    local mutStrength = opts.mutationStrength or 0.2

    local newPop = {}
    for i = 1, math.min(eliteCount, #pop) do
        newPop[i] = { genes = {table.unpack(pop[i].genes)}, fitness = pop[i].fitness }
    end
    while #newPop < #pop do
        local p1 = selectFn(pop)
        local p2 = selectFn(pop)
        local child = crossoverFn(p1, p2)
        mutateFn(child, mutRate, mutStrength)
        newPop[#newPop + 1] = child
    end
    return newPop
end

return GA
```

---

## 2. Selection Operators

### 2.1 Tournament Selection (Default)

```lua
function GA.tournamentSelect(pop, k)
    k = k or 3
    local best = pop[math.random(1, #pop)]
    for i = 2, k do
        local candidate = pop[math.random(1, #pop)]
        if candidate.fitness > best.fitness then best = candidate end
    end
    return best
end
```

### 2.2 Roulette Wheel Selection

```lua
function GA.rouletteSelect(pop)
    local minFit = pop[#pop].fitness
    local totalFit = 0
    for i = 1, #pop do totalFit = totalFit + (pop[i].fitness - minFit + 1e-6) end
    local r = math.random() * totalFit
    local cumulative = 0
    for i = 1, #pop do
        cumulative = cumulative + (pop[i].fitness - minFit + 1e-6)
        if cumulative >= r then return pop[i] end
    end
    return pop[#pop]
end
```

### 2.3 Rank Selection

```lua
function GA.rankSelect(pop)
    local n = #pop
    local totalRank = n * (n + 1) / 2
    local r = math.random() * totalRank
    local cumulative = 0
    for i = 1, n do
        cumulative = cumulative + (n - i + 1)
        if cumulative >= r then return pop[i] end
    end
    return pop[1]
end
```

### 2.4 Elitist Selection

```lua
function GA.elitistSelect(pop, topPercent)
    topPercent = topPercent or 0.3
    local poolSize = math.max(1, math.floor(#pop * topPercent))
    return pop[math.random(1, poolSize)]
end
```

### Selection Comparison

| Method | Pressure | Diversity | Best For |
|--------|----------|-----------|----------|
| Tournament (k=3) | Medium | Good | General purpose, default choice |
| Roulette | Low | High | Early exploration |
| Rank | Medium | Medium | Uneven fitness landscapes |
| Elitist | High | Low | Fast convergence, fine-tuning |

---

## 3. Crossover Operators

### 3.1 Single-Point Crossover (Default)

```lua
function GA.singlePointCrossover(p1, p2)
    local n = #p1.genes
    local point = math.random(1, n - 1)
    local childGenes = {}
    for i = 1, point do childGenes[i] = p1.genes[i] end
    for i = point + 1, n do childGenes[i] = p2.genes[i] end
    return { genes = childGenes, fitness = 0 }
end
```

### 3.2 Two-Point Crossover

```lua
function GA.twoPointCrossover(p1, p2)
    local n = #p1.genes
    local a = math.random(1, n - 1)
    local b = math.random(a + 1, n)
    local childGenes = {}
    for i = 1, n do
        if i >= a and i <= b then childGenes[i] = p2.genes[i]
        else childGenes[i] = p1.genes[i] end
    end
    return { genes = childGenes, fitness = 0 }
end
```

### 3.3 Uniform Crossover

```lua
function GA.uniformCrossover(p1, p2, mixRate)
    mixRate = mixRate or 0.5
    local childGenes = {}
    for i = 1, #p1.genes do
        childGenes[i] = math.random() < mixRate and p2.genes[i] or p1.genes[i]
    end
    return { genes = childGenes, fitness = 0 }
end
```

### 3.4 BLX-alpha Blend Crossover

```lua
function GA.blendCrossover(p1, p2, alpha)
    alpha = alpha or 0.5
    local childGenes = {}
    for i = 1, #p1.genes do
        local lo = math.min(p1.genes[i], p2.genes[i])
        local hi = math.max(p1.genes[i], p2.genes[i])
        local range = hi - lo
        childGenes[i] = (lo - range * alpha) + math.random() * (range * (1 + 2 * alpha))
    end
    return { genes = childGenes, fitness = 0 }
end
```

### Crossover Comparison

| Method | Gene Mixing | Best For |
|--------|-------------|----------|
| Single-Point | Block swap | Ordered gene sequences |
| Two-Point | Segment swap | Medium gene count |
| Uniform | Per-gene random | Independent genes |
| BLX-alpha Blend | Interpolation | Continuous numeric params |

---

## 4. Mutation Operators

### 4.1 Gaussian Mutation (Default)

```lua
function GA.gaussianMutate(individual, rate, strength)
    rate = rate or 0.1; strength = strength or 0.2
    for i = 1, #individual.genes do
        if math.random() < rate then
            local u1 = math.random(); local u2 = math.random()
            local z = math.sqrt(-2 * math.log(math.max(u1, 1e-10))) * math.cos(2 * math.pi * u2)
            individual.genes[i] = individual.genes[i] + z * strength
        end
    end
end
```

### 4.2 Uniform Mutation

```lua
function GA.uniformMutate(individual, rate, minVal, maxVal)
    rate = rate or 0.1; minVal = minVal or 0; maxVal = maxVal or 1
    for i = 1, #individual.genes do
        if math.random() < rate then
            individual.genes[i] = minVal + math.random() * (maxVal - minVal)
        end
    end
end
```

### 4.3 Swap Mutation (for Permutations)

```lua
function GA.swapMutate(individual, rate)
    rate = rate or 0.1
    local n = #individual.genes
    if math.random() < rate and n >= 2 then
        local a = math.random(1, n); local b = math.random(1, n)
        individual.genes[a], individual.genes[b] = individual.genes[b], individual.genes[a]
    end
end
```

### 4.4 Adaptive Mutation

```lua
function GA.adaptiveMutate(individual, rate, strength, generation, maxGens)
    local decay = 1 - (generation / maxGens) * 0.8
    GA.gaussianMutate(individual, rate * (0.5 + 0.5 * decay), strength * decay)
end
```

### Mutation Comparison

| Method | Distribution | Best For |
|--------|-------------|----------|
| Gaussian | Normal (bell curve) | Fine-tuning continuous params |
| Uniform | Flat random | Broad exploration |
| Swap | Position exchange | Permutation problems (order) |
| Adaptive | Decaying gaussian | Long evolutionary runs |

---

## 5. Gene Encoding Schemes

### 5.1 Numeric (Continuous)

```lua
local individual = GA.createIndividual(10, 0.0, 1.0)
-- Use for: damage multipliers, speed, health, probabilities
```

### 5.2 Binary

```lua
function GA.createBinaryIndividual(geneCount)
    local genes = {}
    for i = 1, geneCount do genes[i] = math.random() < 0.5 and 0 or 1 end
    return { genes = genes, fitness = 0 }
end
-- Use for: feature flags, ability toggles, grid presence
```

### 5.3 Permutation

```lua
function GA.createPermutationIndividual(n)
    local genes = {}
    for i = 1, n do genes[i] = i end
    for i = n, 2, -1 do -- Fisher-Yates shuffle
        local j = math.random(1, i)
        genes[i], genes[j] = genes[j], genes[i]
    end
    return { genes = genes, fitness = 0 }
end
-- Use for: patrol orders, level sequences, item arrangements
```

### 5.4 Composite (Multi-segment)

```lua
function GA.createCompositeIndividual(segments)
    local genes = {}; local idx = 1
    for _, seg in ipairs(segments) do
        for i = 1, seg.count do
            if seg.type == "float" then genes[idx] = seg.min + math.random() * (seg.max - seg.min)
            elseif seg.type == "int" then genes[idx] = math.random(seg.min, seg.max)
            elseif seg.type == "binary" then genes[idx] = math.random() < 0.5 and 0 or 1 end
            idx = idx + 1
        end
    end
    return { genes = genes, fitness = 0 }
end

-- Example: enemy with stats + abilities
local enemy = GA.createCompositeIndividual({
    { type = "float", count = 3, min = 0.5, max = 2.0 },  -- hp, speed, damage
    { type = "binary", count = 4 },                         -- ability flags
    { type = "int", count = 2, min = 1, max = 5 },         -- weapon type, armor type
})
```

---

## 6. Serialization (UrhoX File API)

```lua
local cjson = require("cjson")

function GA.savePopulation(pop, filename)
    local f = File:new(filename, FILE_WRITE)
    if f:IsOpen() then
        local data = { generation = pop.generation or 0, individuals = {} }
        for i = 1, #pop do
            data.individuals[i] = { genes = pop[i].genes, fitness = pop[i].fitness }
        end
        f:WriteLine(cjson.encode(data)); f:Close(); return true
    end
    return false
end

function GA.loadPopulation(filename)
    local f = File:new(filename, FILE_READ)
    if f:IsOpen() then
        local json = f:ReadLine(); f:Close()
        local data = cjson.decode(json)
        local pop = {}
        for i = 1, #data.individuals do pop[i] = data.individuals[i] end
        pop.generation = data.generation
        return pop
    end
    return nil
end
```

---

## 7. Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Array index 0 | Lua arrays start at 1 |
| math.random() same sequence | Seed once: math.randomseed(os.time()) |
| Fitness NaN from log(0) | Guard: math.log(math.max(val, 1e-10)) |
| Converges too fast | Increase mutation rate or use rank selection |
| Crossover breaks range | Clamp: math.max(min, math.min(max, gene)) |
| Evolving every frame kills FPS | Use frame budget (max 2ms) |
| io.open for save files | Use UrhoX File API (sandboxed) |
| table.unpack mid-constructor | Only fully expands at last position |
| Huge population | Keep <= 200 for real-time games |
| Mutation too high late | Use adaptive mutation with decay |
| No elitism | Always keep top 1-2 unchanged |

---

## 8. Frame-Budget Evolution Pattern

```lua
local evoState = { phase = "idle", evalIndex = 1, newPop = {} }

function updateEvolution(pop, fitnessFn, budgetMs)
    local startTime = os.clock() * 1000
    if evoState.phase == "evaluating" then
        while evoState.evalIndex <= #pop do
            pop[evoState.evalIndex].fitness = fitnessFn(pop[evoState.evalIndex].genes)
            evoState.evalIndex = evoState.evalIndex + 1
            if (os.clock() * 1000 - startTime) > budgetMs then return pop, false end
        end
        table.sort(pop, function(a, b) return a.fitness > b.fitness end)
        evoState.phase = "breeding"; evoState.newPop = {}
    end
    if evoState.phase == "breeding" then
        if #evoState.newPop == 0 then
            evoState.newPop[1] = { genes = {table.unpack(pop[1].genes)}, fitness = pop[1].fitness }
            evoState.newPop[2] = { genes = {table.unpack(pop[2].genes)}, fitness = pop[2].fitness }
        end
        while #evoState.newPop < #pop do
            local p1 = GA.tournamentSelect(pop)
            local p2 = GA.tournamentSelect(pop)
            local child = GA.singlePointCrossover(p1, p2)
            GA.gaussianMutate(child, 0.1, 0.2)
            evoState.newPop[#evoState.newPop + 1] = child
            if (os.clock() * 1000 - startTime) > budgetMs then return pop, false end
        end
        evoState.phase = "idle"; evoState.evalIndex = 1
        return evoState.newPop, true
    end
    return pop, true
end

function startEvolution()
    evoState.phase = "evaluating"; evoState.evalIndex = 1
end
```
