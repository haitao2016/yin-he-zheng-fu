# Procedural Content Generation via Evolution

> Reference for `evolutionary-game-systems` skill.
> Covers level generation, enemy waves, item/loot tables, and terrain —
> all driven by genetic algorithms in UrhoX Lua.

---

## 1  Level Generation

### Gene Encoding — Grid-Based

Encode a 2D level as a flat array of tile IDs.

```lua
-- Gene: flat array  [1 .. width*height]
-- 0 = empty, 1 = wall, 2 = platform, 3 = hazard, 4 = collectible
local function randomLevel(w, h)
    local genes = {}
    for i = 1, w * h do
        genes[i] = math.random(0, 4)
    end
    return genes
end
```

### Fitness — Reachability (BFS)

A level is only useful if the player can reach the exit.

```lua
local function bfsReachable(genes, w, h, startX, startY, goalX, goalY)
    local idx = function(x, y) return (y - 1) * w + x end
    local visited = {}
    local queue = { { startX, startY } }
    visited[idx(startX, startY)] = true

    while #queue > 0 do
        local cur = table.remove(queue, 1)
        local cx, cy = cur[1], cur[2]
        if cx == goalX and cy == goalY then return true end

        local dirs = { {1,0},{-1,0},{0,1},{0,-1} }
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if nx >= 1 and nx <= w and ny >= 1 and ny <= h then
                local ni = idx(nx, ny)
                if not visited[ni] and genes[ni] ~= 1 then  -- not wall
                    visited[ni] = true
                    queue[#queue + 1] = { nx, ny }
                end
            end
        end
    end
    return false
end
```

### Fitness — Composite Score

```lua
local function levelFitness(genes, w, h)
    local score = 0.0

    -- 1. Reachability (mandatory)
    if not bfsReachable(genes, w, h, 1, 1, w, h) then
        return 0.0  -- instant fail
    end
    score = score + 50.0

    -- 2. Platform density (prefer 20-40%)
    local platforms = 0
    for i = 1, #genes do
        if genes[i] == 2 then platforms = platforms + 1 end
    end
    local density = platforms / #genes
    if density >= 0.2 and density <= 0.4 then
        score = score + 30.0
    else
        score = score + 30.0 * (1.0 - math.abs(density - 0.3) / 0.3)
    end

    -- 3. Collectible count (prefer 5-10)
    local collectibles = 0
    for i = 1, #genes do
        if genes[i] == 4 then collectibles = collectibles + 1 end
    end
    if collectibles >= 5 and collectibles <= 10 then
        score = score + 20.0
    else
        score = score + math.max(0, 20.0 - math.abs(collectibles - 7) * 3)
    end

    return score
end
```

### Rendering in UrhoX

```lua
local function renderLevel(scene, genes, w, h, tileSize)
    tileSize = tileSize or 1.0
    local parent = scene:CreateChild("Level")

    for y = 1, h do
        for x = 1, w do
            local tile = genes[(y - 1) * w + x]
            if tile > 0 then
                local node = parent:CreateChild("Tile")
                node.position = Vector3(
                    (x - 1) * tileSize,
                    (h - y) * tileSize,  -- flip Y for screen coords
                    0
                )
                node.scale = Vector3(tileSize, tileSize, tileSize)

                local model = node:CreateComponent("StaticModel")
                model.model = cache:GetResource("Model", "Models/Box.mdl")

                -- Color by tile type
                local mat = Material:new()
                mat:SetTechnique(0,
                    cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
                if tile == 1 then      -- wall
                    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.3, 0.3)))
                elseif tile == 2 then  -- platform
                    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.7, 0.3)))
                elseif tile == 3 then  -- hazard
                    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.2, 0.1)))
                elseif tile == 4 then  -- collectible
                    mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.85, 0.0)))
                end
                model.material = mat
            end
        end
    end
    return parent
end
```

---

## 2  Enemy Wave Generation

### Gene Encoding

Each wave is an array of enemy-type indices with per-enemy parameter genes.

```lua
--[[
    Wave gene structure:
    {
        count = 8,           -- number of enemies
        types = {1,3,2,1,2,3,1,2},  -- enemy type per slot
        speeds = {1.0, 0.8, 1.2, ...},
        healths = {100, 150, 80, ...},
    }
]]

local ENEMY_TYPES = {
    { name = "Grunt",   baseCost = 1,  baseHP = 50,  baseDmg = 5  },
    { name = "Tank",    baseCost = 3,  baseHP = 200, baseDmg = 8  },
    { name = "Speeder", baseCost = 2,  baseHP = 30,  baseDmg = 12 },
    { name = "Boss",    baseCost = 8,  baseHP = 500, baseDmg = 20 },
}

local function randomWave(size, budget)
    local wave = { types = {}, speeds = {}, healths = {} }
    local spent = 0
    for i = 1, size do
        local t = math.random(1, #ENEMY_TYPES)
        -- respect budget
        if spent + ENEMY_TYPES[t].baseCost > budget then
            t = 1  -- fallback to cheapest
        end
        spent = spent + ENEMY_TYPES[t].baseCost
        wave.types[i] = t
        wave.speeds[i] = 0.8 + math.random() * 0.8  -- 0.8 to 1.6
        wave.healths[i] = ENEMY_TYPES[t].baseHP * (0.8 + math.random() * 0.4)
    end
    return wave
end
```

### Fitness — Challenge Balance

```lua
local function waveFitness(wave, playerDPS, targetDuration)
    -- Total effective HP
    local totalEHP = 0
    for i = 1, #wave.types do
        totalEHP = totalEHP + wave.healths[i]
    end

    -- Estimated clear time
    local clearTime = totalEHP / playerDPS

    -- Closer to target duration = better
    local timeDiff = math.abs(clearTime - targetDuration)
    local timeScore = math.max(0, 100 - timeDiff * 10)

    -- Variety bonus (more distinct types = better)
    local seen = {}
    for _, t in ipairs(wave.types) do seen[t] = true end
    local variety = 0
    for _ in pairs(seen) do variety = variety + 1 end
    local varietyScore = variety / #ENEMY_TYPES * 30

    return timeScore + varietyScore
end
```

---

## 3  Item / Loot Generation

### Gene Encoding — Stat Budgets

```lua
local STAT_NAMES = { "damage", "defense", "speed", "critRate", "healBonus" }

local function randomItem(powerBudget)
    local item = { stats = {}, rarity = 1 }
    local remaining = powerBudget

    for i = 1, #STAT_NAMES do
        if i == #STAT_NAMES then
            item.stats[i] = remaining  -- last stat gets the rest
        else
            local alloc = math.random(0, math.floor(remaining * 0.6))
            item.stats[i] = alloc
            remaining = remaining - alloc
        end
    end

    -- Determine rarity from total power
    if powerBudget > 80 then item.rarity = 4      -- legendary
    elseif powerBudget > 50 then item.rarity = 3   -- epic
    elseif powerBudget > 25 then item.rarity = 2   -- rare
    else item.rarity = 1 end                        -- common

    return item
end
```

### Fitness — Build Synergy

```lua
local function itemFitness(item, playerBuild)
    local score = 0

    -- Reward stats that match player build preferences
    for i, name in ipairs(STAT_NAMES) do
        local weight = playerBuild[name] or 0.5
        score = score + item.stats[i] * weight
    end

    -- Penalize extreme stat distributions (all in one stat)
    local maxStat = 0
    local total = 0
    for _, v in ipairs(item.stats) do
        total = total + v
        if v > maxStat then maxStat = v end
    end
    if total > 0 then
        local concentration = maxStat / total
        if concentration > 0.8 then
            score = score * 0.6  -- too concentrated
        end
    end

    return score
end
```

---

## 4  Terrain Generation

### Gene Encoding — Heightmap

```lua
local function randomHeightmap(w, h, minH, maxH)
    local hmap = {}
    for i = 1, w * h do
        hmap[i] = minH + math.random() * (maxH - minH)
    end
    return hmap
end
```

### Smoothing via Crossover

Using blend crossover naturally produces smoother terrain when
crossing two parents:

```lua
local function blendHeightmaps(parent1, parent2, alpha)
    alpha = alpha or 0.5
    local child = {}
    for i = 1, #parent1 do
        child[i] = parent1[i] * alpha + parent2[i] * (1.0 - alpha)
    end
    return child
end
```

### Rendering with CustomGeometry

```lua
local function renderTerrain(scene, hmap, w, h, scale)
    scale = scale or 1.0
    local node = scene:CreateChild("Terrain")
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local function height(x, y)
        return hmap[(y - 1) * w + x] or 0
    end

    for y = 1, h - 1 do
        for x = 1, w - 1 do
            local x0, x1 = (x - 1) * scale, x * scale
            local y0, y1 = (y - 1) * scale, y * scale
            local h00 = height(x, y)
            local h10 = height(x + 1, y)
            local h01 = height(x, y + 1)
            local h11 = height(x + 1, y + 1)

            -- Triangle 1
            geom:DefineVertex(Vector3(x0, h00, y0))
            geom:DefineNormal(Vector3.UP)
            geom:DefineTexCoord(Vector2(0, 0))

            geom:DefineVertex(Vector3(x1, h10, y0))
            geom:DefineNormal(Vector3.UP)
            geom:DefineTexCoord(Vector2(1, 0))

            geom:DefineVertex(Vector3(x0, h01, y1))
            geom:DefineNormal(Vector3.UP)
            geom:DefineTexCoord(Vector2(0, 1))

            -- Triangle 2
            geom:DefineVertex(Vector3(x1, h10, y0))
            geom:DefineNormal(Vector3.UP)
            geom:DefineTexCoord(Vector2(1, 0))

            geom:DefineVertex(Vector3(x1, h11, y1))
            geom:DefineNormal(Vector3.UP)
            geom:DefineTexCoord(Vector2(1, 1))

            geom:DefineVertex(Vector3(x0, h01, y1))
            geom:DefineNormal(Vector3.UP)
            geom:DefineTexCoord(Vector2(0, 1))
        end
    end

    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0,
        cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.65, 0.3)))
    geom:SetMaterial(mat)

    return node
end
```

---

## 5  Fitness Function Design Guide

| Goal | Fitness Components | Weight Advice |
|------|-------------------|---------------|
| Playable level | BFS reachability (binary) | Gate: 0 if fail |
| Appropriate difficulty | Clear-time vs target | 30-40% |
| Visual variety | Tile-type entropy | 10-20% |
| Player engagement | Collectible placement quality | 15-25% |
| Challenge curve | Difficulty ramp across waves | 20-30% |
| Build diversity | Stat distribution evenness | 10-15% |

### Multi-Objective Fitness

When optimizing multiple goals simultaneously:

```lua
local function multiObjectiveFitness(individual, weights)
    local scores = {}
    scores.playability = evaluatePlayability(individual)
    scores.difficulty  = evaluateDifficulty(individual)
    scores.variety     = evaluateVariety(individual)

    -- Weighted sum (simplest approach)
    local total = 0
    for key, score in pairs(scores) do
        total = total + score * (weights[key] or 1.0)
    end
    return total, scores  -- return breakdown for debugging
end
```

---

## 6  PCG Evolver — Frame-Budgeted Generation

Generate content across multiple frames to avoid stuttering.

```lua
local PCGEvolver = {}
PCGEvolver.__index = PCGEvolver

function PCGEvolver.new(config)
    local self = setmetatable({}, PCGEvolver)
    self.popSize    = config.popSize or 30
    self.geneFactory = config.geneFactory   -- function() -> genes
    self.fitnessFn  = config.fitnessFn      -- function(genes) -> number
    self.crossoverFn = config.crossoverFn or PCGEvolver.defaultCrossover
    self.mutateFn   = config.mutateFn or PCGEvolver.defaultMutate
    self.maxBudgetMs = config.maxBudgetMs or 2.0
    self.population = {}
    self.generation = 0
    self.bestGenes  = nil
    self.bestFitness = -math.huge
    self.state      = "idle"  -- idle | evolving | done
    self._evalIdx   = 1
    return self
end

function PCGEvolver:start()
    self.population = {}
    for i = 1, self.popSize do
        self.population[i] = {
            genes = self.geneFactory(),
            fitness = nil,
        }
    end
    self._evalIdx = 1
    self.generation = 0
    self.state = "evolving"
end

function PCGEvolver:tick()
    if self.state ~= "evolving" then return end

    local startTime = os.clock()

    -- Evaluate as many as we can within budget
    while self._evalIdx <= self.popSize do
        local ind = self.population[self._evalIdx]
        if not ind.fitness then
            ind.fitness = self.fitnessFn(ind.genes)
            if ind.fitness > self.bestFitness then
                self.bestFitness = ind.fitness
                self.bestGenes = ind.genes
            end
        end
        self._evalIdx = self._evalIdx + 1

        if (os.clock() - startTime) * 1000 > self.maxBudgetMs then
            return  -- budget exhausted, continue next frame
        end
    end

    -- All evaluated — breed next generation
    self:_breedNextGeneration()
    self.generation = self.generation + 1
    self._evalIdx = 1
end

function PCGEvolver:_breedNextGeneration()
    local sorted = {}
    for i, ind in ipairs(self.population) do
        sorted[i] = ind
    end
    table.sort(sorted, function(a, b) return a.fitness > b.fitness end)

    local newPop = {}
    -- Elitism: keep top 2
    newPop[1] = { genes = sorted[1].genes, fitness = nil }
    newPop[2] = { genes = sorted[2].genes, fitness = nil }

    for i = 3, self.popSize do
        local p1 = sorted[math.random(1, math.ceil(self.popSize * 0.4))]
        local p2 = sorted[math.random(1, math.ceil(self.popSize * 0.4))]
        local childGenes = self.crossoverFn(p1.genes, p2.genes)
        self.mutateFn(childGenes)
        newPop[i] = { genes = childGenes, fitness = nil }
    end

    self.population = newPop
end

function PCGEvolver.defaultCrossover(g1, g2)
    local child = {}
    local point = math.random(1, #g1)
    for i = 1, #g1 do
        child[i] = (i <= point) and g1[i] or g2[i]
    end
    return child
end

function PCGEvolver.defaultMutate(genes)
    for i = 1, #genes do
        if math.random() < 0.05 then
            if type(genes[i]) == "number" then
                genes[i] = genes[i] + (math.random() - 0.5) * 2
            end
        end
    end
end

return PCGEvolver
```

---

## 7  Complete Example — Platformer Level Generator

```lua
-- Evolve a platformer level over multiple frames
local GA = require("scripts.GA")  -- from ga-core.md

local W, H = 20, 12
local POP_SIZE = 40
local ELITE = 4
local MUTATION_RATE = 0.08

local population = {}
local generation = 0

function Start()
    -- Initialize population
    for i = 1, POP_SIZE do
        population[i] = {
            genes = randomLevel(W, H),
            fitness = 0,
        }
    end
    evaluateAll()
    renderBest()

    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function evaluateAll()
    for _, ind in ipairs(population) do
        ind.fitness = levelFitness(ind.genes, W, H)
    end
    table.sort(population, function(a, b)
        return a.fitness > b.fitness
    end)
end

function evolveOneGeneration()
    local newPop = {}

    -- Elitism
    for i = 1, ELITE do
        newPop[i] = { genes = {}, fitness = 0 }
        for j = 1, #population[i].genes do
            newPop[i].genes[j] = population[i].genes[j]
        end
    end

    -- Breed
    for i = ELITE + 1, POP_SIZE do
        local p1 = population[math.random(1, math.ceil(POP_SIZE * 0.3))]
        local p2 = population[math.random(1, math.ceil(POP_SIZE * 0.3))]

        -- Single-point crossover
        local child = {}
        local point = math.random(1, W * H)
        for j = 1, W * H do
            child[j] = (j <= point) and p1.genes[j] or p2.genes[j]
        end

        -- Mutation
        for j = 1, #child do
            if math.random() < MUTATION_RATE then
                child[j] = math.random(0, 4)
            end
        end

        newPop[i] = { genes = child, fitness = 0 }
    end

    population = newPop
    evaluateAll()
    generation = generation + 1
end

function renderBest()
    -- Remove old level
    local old = scene_:GetChild("Level")
    if old then old:Remove() end

    -- Render best individual
    renderLevel(scene_, population[1].genes, W, H, 1.0)
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key == KEY_SPACE then
        evolveOneGeneration()
        renderBest()
        log:Write(LOG_INFO, string.format(
            "Gen %d | Best fitness: %.1f", generation, population[1].fitness))
    end
end
```

---

## 8  Caching Generated Content

Use `cjson` + UrhoX `File` API to save/load evolved content:

```lua
local cjson = require("cjson")

local function saveContent(filename, data)
    local json = cjson.encode(data)
    local file = File(context, filename, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
        return true
    end
    return false
end

local function loadContent(filename)
    if not fileSystem:FileExists(filename) then return nil end
    local file = File(context, filename, FILE_READ)
    if file:IsOpen() then
        local json = file:ReadString()
        file:Close()
        return cjson.decode(json)
    end
    return nil
end

-- Usage:
-- saveContent("levels/best_gen42.json", { genes = bestGenes, fitness = bestFit })
-- local saved = loadContent("levels/best_gen42.json")
```

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Level always unreachable | Add reachability as a gate (0 fitness if fail) |
| Content converges to one pattern | Inject diversity every N generations |
| Fitness evaluation too slow | Use frame-budgeted PCGEvolver |
| Wave too easy or too hard | Calibrate target duration against player DPS |
| Heightmap too spiky | Apply blend crossover + low mutation rate |
| Item stats all zeros | Ensure power budget > 0 before generation |
| Gene array index off-by-one | Lua arrays start at 1 (not 0) |
