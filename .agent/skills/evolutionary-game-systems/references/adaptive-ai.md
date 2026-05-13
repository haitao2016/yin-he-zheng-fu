# Adaptive AI & Dynamic Difficulty via Evolution

> Reference for `evolutionary-game-systems` skill.
> Covers NPC behavior evolution, dynamic difficulty adjustment (DDA),
> squad composition, and player modeling — all in UrhoX Lua.

---

## 1  NPC Behavior Evolution

### NPCBrain — Gene-Driven Decision Making

Each NPC has a set of behavioral genes that determine how it acts.

```lua
local NPCBrain = {}
NPCBrain.__index = NPCBrain

-- 6 behavioral genes, each in [0, 1]
NPCBrain.GENE_NAMES = {
    "aggression",     -- 0=passive, 1=attack-on-sight
    "caution",        -- 0=reckless, 1=always-retreat-when-low-hp
    "exploration",    -- 0=stay-put, 1=roam-widely
    "sociability",    -- 0=lone-wolf, 1=always-group-up
    "resourceFocus",  -- 0=ignore-pickups, 1=prioritize-resources
    "adaptability",   -- 0=rigid-pattern, 1=react-to-player-actions
}

function NPCBrain.new(genes)
    local self = setmetatable({}, NPCBrain)
    self.genes = genes or NPCBrain.randomGenes()
    return self
end

function NPCBrain.randomGenes()
    local g = {}
    for i = 1, #NPCBrain.GENE_NAMES do
        g[i] = math.random()
    end
    return g
end

function NPCBrain:decide(context)
    --[[
        context = {
            distToPlayer    = number,
            hpPercent       = number (0-1),
            nearbyAllies    = number,
            nearbyResources = number,
            playerThreat    = number (0-1),
        }
    ]]

    local dominated  -- action with highest weight wins
    local bestWeight = -1

    local actions = {
        {
            name = "attack",
            weight = self.genes[1] * (1.0 - context.distToPlayer / 20.0)
                   + (1.0 - self.genes[2]) * 0.3,
        },
        {
            name = "retreat",
            weight = self.genes[2] * (1.0 - context.hpPercent)
                   + (1.0 - self.genes[1]) * context.playerThreat,
        },
        {
            name = "explore",
            weight = self.genes[3] * 0.5
                   + (1.0 - self.genes[1]) * 0.2,
        },
        {
            name = "group",
            weight = self.genes[4] * (context.nearbyAllies > 0 and 0.8 or 0.2),
        },
        {
            name = "gather",
            weight = self.genes[5] * (context.nearbyResources > 0 and 1.0 or 0.0),
        },
    }

    -- Adaptability modulates reaction to player threat
    if self.genes[6] > 0.5 and context.playerThreat > 0.7 then
        -- High adaptability: shift toward caution when threatened
        actions[2].weight = actions[2].weight + self.genes[6] * 0.4
    end

    for _, action in ipairs(actions) do
        if action.weight > bestWeight then
            bestWeight = action.weight
            dominated = action.name
        end
    end

    return dominated
end

return NPCBrain
```

### Evolving Better NPCs

After each game round, evaluate NPC performance and evolve:

```lua
local function npcFitness(brain, matchStats)
    local score = 0

    -- Survival bonus
    score = score + matchStats.survivalTime * 2.0

    -- Damage dealt
    score = score + matchStats.damageDealt * 0.5

    -- Resources gathered
    score = score + matchStats.resourcesGathered * 1.5

    -- Penalize instant deaths
    if matchStats.survivalTime < 5 then
        score = score * 0.3
    end

    return score
end
```

---

## 2  Dynamic Difficulty Adjustment (DDA)

### Player Model

Track rolling averages of player performance metrics.

```lua
local PlayerModel = {}
PlayerModel.__index = PlayerModel

function PlayerModel.new(windowSize)
    local self = setmetatable({}, PlayerModel)
    self.windowSize = windowSize or 10
    self.metrics = {
        clearTime     = {},  -- seconds to clear each wave/level
        deathCount    = {},  -- deaths per attempt
        accuracy      = {},  -- hit rate (0-1)
        resourceUsage = {},  -- items used per wave
        damageDealt   = {},  -- DPS-equivalent
    }
    return self
end

function PlayerModel:record(metricName, value)
    local list = self.metrics[metricName]
    if not list then
        self.metrics[metricName] = {}
        list = self.metrics[metricName]
    end
    list[#list + 1] = value
    -- Keep window
    while #list > self.windowSize do
        table.remove(list, 1)
    end
end

function PlayerModel:average(metricName)
    local list = self.metrics[metricName]
    if not list or #list == 0 then return 0 end
    local sum = 0
    for _, v in ipairs(list) do sum = sum + v end
    return sum / #list
end

function PlayerModel:trend(metricName)
    local list = self.metrics[metricName]
    if not list or #list < 3 then return 0 end
    -- Compare recent half vs older half
    local mid = math.floor(#list / 2)
    local oldAvg, newAvg = 0, 0
    for i = 1, mid do oldAvg = oldAvg + list[i] end
    for i = mid + 1, #list do newAvg = newAvg + list[i] end
    oldAvg = oldAvg / mid
    newAvg = newAvg / (#list - mid)
    return newAvg - oldAvg  -- positive = improving
end

function PlayerModel:skillLevel()
    -- Composite skill estimate (0-1)
    local acc = self:average("accuracy")
    local deathRate = math.min(self:average("deathCount") / 5, 1.0)
    local dps = math.min(self:average("damageDealt") / 100, 1.0)
    return (acc * 0.4 + (1.0 - deathRate) * 0.3 + dps * 0.3)
end

return PlayerModel
```

### DDA Evolver

Evolve difficulty parameters to match player skill.

```lua
local DDAEvolver = {}
DDAEvolver.__index = DDAEvolver

-- Difficulty genes
DDAEvolver.PARAMS = {
    "enemyCount",      -- wave size multiplier
    "enemyHP",         -- HP multiplier
    "enemyDamage",     -- damage multiplier
    "spawnRate",       -- spawn frequency multiplier
    "resourceDrops",   -- resource availability multiplier
}

function DDAEvolver.new(playerModel, config)
    local self = setmetatable({}, DDAEvolver)
    self.playerModel = playerModel
    self.popSize     = config.popSize or 20
    self.population  = {}
    self.targetSkill = config.targetSkill or 0.5  -- target engagement level

    -- Guardrails: min/max for each param
    self.minValues = config.minValues or { 0.5, 0.5, 0.5, 0.5, 0.5 }
    self.maxValues = config.maxValues or { 2.0, 2.0, 2.0, 2.0, 2.0 }

    self:_initPopulation()
    return self
end

function DDAEvolver:_initPopulation()
    for i = 1, self.popSize do
        local genes = {}
        for j = 1, #DDAEvolver.PARAMS do
            genes[j] = self.minValues[j]
                     + math.random() * (self.maxValues[j] - self.minValues[j])
        end
        self.population[i] = { genes = genes, fitness = 0 }
    end
end

function DDAEvolver:evaluate()
    local skill = self.playerModel:skillLevel()
    local trend = self.playerModel:trend("accuracy")

    for _, ind in ipairs(self.population) do
        local diff = self:_estimateDifficulty(ind.genes)

        -- Fitness = how close difficulty matches player skill
        local skillGap = math.abs(diff - skill)
        ind.fitness = 100 - skillGap * 200

        -- Bonus for slight upward pressure (keep it challenging)
        if diff > skill and diff < skill + 0.15 then
            ind.fitness = ind.fitness + 20
        end

        -- If player is improving, allow harder content
        if trend > 0.05 then
            ind.fitness = ind.fitness + (diff - skill) * 30
        end

        -- Penalize extremes (never make game trivial or impossible)
        if diff < 0.1 or diff > 0.95 then
            ind.fitness = ind.fitness - 50
        end
    end
end

function DDAEvolver:_estimateDifficulty(genes)
    -- Composite difficulty estimate from genes
    local sum = 0
    for i = 1, #genes do
        -- Normalize to [0, 1]
        local norm = (genes[i] - self.minValues[i])
                   / (self.maxValues[i] - self.minValues[i])
        sum = sum + norm
    end
    -- resourceDrops inversely affects difficulty
    local resNorm = (genes[5] - self.minValues[5])
                  / (self.maxValues[5] - self.minValues[5])
    sum = sum - resNorm * 2  -- more resources = easier
    return math.max(0, math.min(1, sum / #genes))
end

function DDAEvolver:getBestParams()
    table.sort(self.population, function(a, b)
        return a.fitness > b.fitness
    end)
    local best = self.population[1].genes
    local params = {}
    for i, name in ipairs(DDAEvolver.PARAMS) do
        params[name] = best[i]
    end
    return params
end

return DDAEvolver
```

### Usage in Game Loop

```lua
local playerModel = PlayerModel.new(10)
local dda = DDAEvolver.new(playerModel, {
    popSize = 20,
    targetSkill = 0.5,
    minValues = { 0.5, 0.5, 0.5, 0.5, 0.5 },
    maxValues = { 2.0, 2.0, 2.0, 2.0, 2.0 },
})

-- After each wave/round:
function onWaveComplete(stats)
    playerModel:record("clearTime", stats.clearTime)
    playerModel:record("deathCount", stats.deaths)
    playerModel:record("accuracy", stats.accuracy)
    playerModel:record("damageDealt", stats.damageDealt)

    -- Evolve difficulty
    dda:evaluate()

    -- Apply to next wave
    local params = dda:getBestParams()
    nextWave.enemyCount = math.floor(BASE_ENEMY_COUNT * params.enemyCount)
    nextWave.enemyHP    = BASE_HP * params.enemyHP
    nextWave.enemyDmg   = BASE_DMG * params.enemyDamage
    nextWave.spawnRate   = BASE_RATE * params.spawnRate
    nextWave.dropRate    = BASE_DROPS * params.resourceDrops
end
```

---

## 3  Squad Composition Evolution

### Counter-Strategy Matrix

Evolve enemy squads that specifically counter the player tactics.

```lua
-- Player archetype detection
local ARCHETYPES = {
    "rusher",     -- aggressive, high DPS, low defense
    "turtle",     -- defensive, slow, high HP
    "sniper",     -- ranged, accurate, fragile
    "balanced",   -- no extreme
}

local function classifyPlayer(model)
    local acc = model:average("accuracy")
    local deaths = model:average("deathCount")
    local dps = model:average("damageDealt")

    if dps > 70 and deaths > 2 then return "rusher" end
    if deaths < 0.5 and dps < 40 then return "turtle" end
    if acc > 0.8 and dps > 50 then return "sniper" end
    return "balanced"
end

-- Counter matrix: what enemy types work against each archetype
local COUNTER_MATRIX = {
    rusher   = { "Tank", "Tank", "Speeder" },     -- absorb damage, flank
    turtle   = { "Speeder", "Speeder", "Boss" },  -- overwhelm defenses
    sniper   = { "Speeder", "Grunt", "Grunt" },   -- rush before they aim
    balanced = { "Grunt", "Tank", "Speeder" },     -- balanced response
}
```

### Squad Evolution

```lua
local function squadFitness(squad, playerArchetype)
    local score = 0
    local counters = COUNTER_MATRIX[playerArchetype]

    -- Reward squads that include counter-types
    for _, enemy in ipairs(squad) do
        for _, counter in ipairs(counters) do
            if enemy == counter then
                score = score + 20
            end
        end
    end

    -- Variety bonus
    local seen = {}
    for _, e in ipairs(squad) do seen[e] = true end
    local types = 0
    for _ in pairs(seen) do types = types + 1 end
    score = score + types * 5

    return score
end
```

---

## 4  Player Modeling & Classification

### Feature Extraction

```lua
local function extractFeatures(model)
    return {
        skill        = model:skillLevel(),
        aggression   = model:average("damageDealt") / 100,
        survival     = 1.0 - math.min(model:average("deathCount") / 5, 1.0),
        accuracy     = model:average("accuracy"),
        resourceUse  = model:average("resourceUsage"),
        improving    = model:trend("accuracy") > 0,
    }
end
```

### Style Classification

```lua
local function classifyPlayStyle(features)
    if features.aggression > 0.7 and features.survival < 0.4 then
        return "berserker"  -- high risk, high reward player
    elseif features.accuracy > 0.8 and features.aggression < 0.4 then
        return "marksman"   -- precise but cautious
    elseif features.survival > 0.8 and features.resourceUse > 0.6 then
        return "survivor"   -- resource-focused survivalist
    elseif features.improving then
        return "learner"    -- actively improving, needs graduated challenge
    else
        return "casual"     -- default relaxed style
    end
end
```

---

## 5  Online vs Offline Evolution

| Aspect | Online (In-Game) | Offline (Between Sessions) |
|--------|-----------------|---------------------------|
| **When** | Every frame / every wave | Between game sessions |
| **Budget** | 1-2ms per frame | Unlimited |
| **Pop Size** | 10-30 | 50-200 |
| **Generations** | 1-5 per trigger | 50-500 |
| **Use Case** | DDA, NPC reactions | Level generation, balance tuning |
| **Persistence** | In-memory | File (cjson + File API) |

### Hybrid Approach

```lua
-- Online: quick micro-adjustments each wave
local function onlineEvolve(dda, playerModel)
    dda:evaluate()
    -- Just 1 generation, top-3 selection
    return dda:getBestParams()
end

-- Offline: thorough optimization between sessions
local function offlineEvolve(config)
    local evolver = PCGEvolver.new(config)
    evolver:start()
    for gen = 1, 200 do
        -- No frame budget constraint
        for i = 1, evolver.popSize do
            local ind = evolver.population[i]
            if not ind.fitness then
                ind.fitness = evolver.fitnessFn(ind.genes)
            end
        end
        evolver:_breedNextGeneration()
    end
    return evolver.bestGenes
end
```

---

## 6  Evolution Monitor — Stagnation & Diversity

### Convergence Detection

```lua
local EvolutionMonitor = {}
EvolutionMonitor.__index = EvolutionMonitor

function EvolutionMonitor.new(config)
    local self = setmetatable({}, EvolutionMonitor)
    self.stagnationThreshold = config.stagnationThreshold or 10
    self.diversityThreshold  = config.diversityThreshold or 0.05
    self.fitnessHistory      = {}
    self.lastBestFitness     = -math.huge
    self.stagnationCount     = 0
    return self
end

function EvolutionMonitor:update(bestFitness, population)
    self.fitnessHistory[#self.fitnessHistory + 1] = bestFitness

    -- Stagnation check
    if math.abs(bestFitness - self.lastBestFitness) < 0.01 then
        self.stagnationCount = self.stagnationCount + 1
    else
        self.stagnationCount = 0
    end
    self.lastBestFitness = bestFitness

    -- Diversity check
    local diversity = self:_measureDiversity(population)

    return {
        stagnant = self.stagnationCount >= self.stagnationThreshold,
        diversity = diversity,
        lowDiversity = diversity < self.diversityThreshold,
        generation = #self.fitnessHistory,
    }
end

function EvolutionMonitor:_measureDiversity(population)
    if #population < 2 then return 0 end

    -- Average pairwise distance (first gene only for speed)
    local totalDist = 0
    local pairs = 0
    local sampleSize = math.min(#population, 10)

    for i = 1, sampleSize do
        for j = i + 1, sampleSize do
            local dist = 0
            local g1 = population[i].genes
            local g2 = population[j].genes
            for k = 1, #g1 do
                dist = dist + math.abs(g1[k] - g2[k])
            end
            totalDist = totalDist + dist / #g1
            pairs = pairs + 1
        end
    end

    return pairs > 0 and totalDist / pairs or 0
end

return EvolutionMonitor
```

### Diversity Injection

When stagnation or low diversity is detected:

```lua
local function injectDiversity(population, ratio)
    ratio = ratio or 0.3
    local replaceCount = math.floor(#population * ratio)

    -- Sort by fitness, replace worst individuals
    table.sort(population, function(a, b)
        return a.fitness > b.fitness
    end)

    for i = #population - replaceCount + 1, #population do
        -- Replace with random individual
        population[i] = {
            genes = randomGenes(),  -- your gene factory
            fitness = nil,
        }
    end
end
```

---

## 7  Tower Defense AI Example

A complete example of evolving enemy wave strategies for a tower defense game.

```lua
-- Tower Defense DDA
local playerModel = PlayerModel.new(8)
local monitor = EvolutionMonitor.new({ stagnationThreshold = 5 })

local waves = {}       -- evolved wave configs
local currentWave = 1

function evolveNextWave()
    local archetype = classifyPlayer(playerModel)

    -- Create population of candidate waves
    local pop = {}
    for i = 1, 30 do
        pop[i] = {
            genes = randomWave(8, 20),  -- 8 enemies, budget 20
            fitness = 0,
        }
    end

    -- Evaluate
    local playerDPS = playerModel:average("damageDealt")
    local targetTime = 30  -- 30 seconds per wave

    for _, ind in ipairs(pop) do
        ind.fitness = waveFitness(ind.genes, playerDPS, targetTime)
                    + squadFitness(
                        ind.genes.types,
                        archetype
                      ) * 0.5
    end

    -- Quick evolution (5 generations, no frame budget needed between waves)
    for gen = 1, 5 do
        table.sort(pop, function(a, b) return a.fitness > b.fitness end)

        local newPop = {}
        -- Elite
        newPop[1] = pop[1]
        newPop[2] = pop[2]

        for i = 3, #pop do
            local p1 = pop[math.random(1, 8)]
            local p2 = pop[math.random(1, 8)]
            newPop[i] = {
                genes = crossoverWave(p1.genes, p2.genes),
                fitness = 0,
            }
            mutateWave(newPop[i].genes)
            newPop[i].fitness = waveFitness(
                newPop[i].genes, playerDPS, targetTime)
        end
        pop = newPop
    end

    table.sort(pop, function(a, b) return a.fitness > b.fitness end)
    return pop[1].genes
end

function onWaveEnd(stats)
    playerModel:record("clearTime", stats.clearTime)
    playerModel:record("deathCount", stats.deaths)
    playerModel:record("accuracy", stats.accuracy)
    playerModel:record("damageDealt", stats.damageDealt)

    currentWave = currentWave + 1
    local nextWaveConfig = evolveNextWave()
    spawnWave(nextWaveConfig)
end
```

---

## 8  UrhoX Integration Patterns

### Event-Driven Evolution Triggers

```lua
-- Evolve after specific game events
SubscribeToEvent("WaveComplete", function(eventType, eventData)
    local waveNum = eventData["WaveNum"]:GetInt()
    local clearTime = eventData["ClearTime"]:GetFloat()
    playerModel:record("clearTime", clearTime)
    evolveNextWave()
end)
```

### NPC Animation from Genes

```lua
-- Map behavioral genes to animation states
local function applyBrainToNPC(node, brain, action)
    local animCtrl = node:GetComponent("AnimationController")
    if not animCtrl then return end

    if action == "attack" then
        animCtrl:PlayExclusive("Models/NPC/Attack.ani", 0, false, 0.2)
    elseif action == "retreat" then
        animCtrl:PlayExclusive("Models/NPC/Run.ani", 0, true, 0.2)
        -- Move away from player
        local dir = (node.position - playerNode.position):Normalized()
        node.position = node.position + dir * brain.genes[2] * 5.0 * timeStep
    elseif action == "explore" then
        animCtrl:PlayExclusive("Models/NPC/Walk.ani", 0, true, 0.2)
    elseif action == "group" then
        animCtrl:PlayExclusive("Models/NPC/Walk.ani", 0, true, 0.2)
    elseif action == "gather" then
        animCtrl:PlayExclusive("Models/NPC/Interact.ani", 0, false, 0.2)
    end
end
```

### Persistence Between Sessions

```lua
local cjson = require("cjson")

local function saveBrains(brains, filename)
    local data = {}
    for i, brain in ipairs(brains) do
        data[i] = brain.genes
    end
    local json = cjson.encode(data)
    local file = File(context, filename, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
    end
end

local function loadBrains(filename)
    if not fileSystem:FileExists(filename) then return nil end
    local file = File(context, filename, FILE_READ)
    if not file:IsOpen() then return nil end
    local json = file:ReadString()
    file:Close()
    local data = cjson.decode(json)
    local brains = {}
    for i, genes in ipairs(data) do
        brains[i] = NPCBrain.new(genes)
    end
    return brains
end
```

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| NPC behavior too erratic | Lower mutation rate for behavioral genes |
| DDA makes game too easy | Add slight upward pressure in fitness |
| Player model stale after break | Reset rolling window on session start |
| Squad always same composition | Use diversity injection in monitor |
| Genes drift out of valid range | Clamp after mutation: `math.max(min, math.min(max, v))` |
| NPC freezes (no action selected) | Ensure at least one action always has weight > 0 |
| Memory leak from brain objects | Reuse brain tables, don't create new ones each frame |
