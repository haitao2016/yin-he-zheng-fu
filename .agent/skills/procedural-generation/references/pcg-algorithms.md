# PCG Algorithm Implementations for UrhoX Lua

> Complete, copy-paste-ready implementations of 7 core PCG algorithms.
> All code uses Lua 5.4 with 1-based arrays, `math.random`/`math.randomseed`, and UrhoX conventions.

## Table of Contents

1. [Seeded RNG & Coordinate Hashing](#1-seeded-rng--coordinate-hashing)
2. [FBM Noise (Fractal Brownian Motion)](#2-fbm-noise)
3. [Domain Warping](#3-domain-warping)
4. [Cellular Automata Cave Generation](#4-cellular-automata-cave-generation)
5. [L-Systems](#5-l-systems)
6. [Markov Chain Name/Text Generation](#6-markov-chain-generation)
7. [Wave Function Collapse (WFC)](#7-wave-function-collapse)
8. [Chunk-Based Infinite World](#8-chunk-based-infinite-world)

---

## 1. Seeded RNG & Coordinate Hashing

### SplitMix-style Seeded RNG

```lua
--- Seedable PRNG wrapper for reproducible generation
---@class SeededRNG
local SeededRNG = {}
SeededRNG.__index = SeededRNG

function SeededRNG.new(seed)
    local self = setmetatable({}, SeededRNG)
    self.seed = seed or os.time()
    math.randomseed(self.seed)
    -- Warm up: Lua PRNG first values have low entropy
    for i = 1, 5 do math.random() end
    return self
end

--- Returns float in [0, 1)
function SeededRNG:next()
    return math.random()
end

--- Returns integer in [min, max]
function SeededRNG:nextInt(min, max)
    return math.random(min, max)
end

--- Returns true with given probability (0-1)
function SeededRNG:chance(probability)
    return math.random() < probability
end

--- Shuffles array in-place (Fisher-Yates)
function SeededRNG:shuffle(arr)
    for i = #arr, 2, -1 do
        local j = math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return arr
end

--- Pick random element from array
function SeededRNG:pick(arr)
    return arr[math.random(1, #arr)]
end

--- Pick with weighted probabilities
--- weights = {0.5, 0.3, 0.2} for 3 items
function SeededRNG:weightedPick(items, weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    local r = math.random() * total
    local cumulative = 0
    for i, w in ipairs(weights) do
        cumulative = cumulative + w
        if r <= cumulative then return items[i] end
    end
    return items[#items]
end
```

### Squirrel3 Coordinate Hash (GDC 2017)

```lua
--- Position-based deterministic hash (Squirrel Eiserloh, GDC 2017)
--- Use for chunk-based generation where each position needs its own seed
---@param x integer
---@param y integer
---@param seed integer
---@return number value in [0, 1]
function HashCoord(x, y, seed)
    local BIT_NOISE1 = 0x68E31DA4
    local BIT_NOISE2 = 0xB5297A4D
    local BIT_NOISE3 = 0x1B56C4E9

    local n = x + (y * 198491317) + (seed * 6543989)
    -- Use Lua 5.4 bitwise operators
    n = (n ~ BIT_NOISE1) * BIT_NOISE2
    n = n & 0x7FFFFFFF  -- Keep positive
    n = (n ~ (n >> 8)) * BIT_NOISE3
    n = n & 0x7FFFFFFF
    n = n ~ (n >> 8)
    n = n & 0x7FFFFFFF

    return n / 0x7FFFFFFF
end

--- 3D variant for volumetric generation
function HashCoord3D(x, y, z, seed)
    return HashCoord(x + z * 198491317, y, seed)
end
```

---

## 2. FBM Noise

### Basic FBM

```lua
--- Fractal Brownian Motion noise
--- Layers multiple octaves of noise for natural-looking results
---@param x number world X
---@param y number world Y
---@param config table {octaves, persistence, lacunarity, scale, seed}
---@return number value in [0, 1]
function FBMNoise(x, y, config)
    local octaves = config.octaves or 6
    local persistence = config.persistence or 0.5
    local lacunarity = config.lacunarity or 2.0
    local scale = config.scale or 100.0
    local seed = config.seed or 42

    local total = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxValue = 0

    for i = 1, octaves do
        -- Sample noise at scaled frequency
        local sx = x / scale * frequency
        local sy = y / scale * frequency
        local noise = HashCoord(
            math.floor(sx * 1000),
            math.floor(sy * 1000),
            seed + i * 31
        )
        total = total + noise * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end

    return total / maxValue
end
```

### Ridged FBM (for mountains/ridges)

```lua
--- Ridged FBM - creates sharp ridges like mountain ranges
function RidgedFBM(x, y, config)
    local octaves = config.octaves or 6
    local persistence = config.persistence or 0.5
    local lacunarity = config.lacunarity or 2.0
    local scale = config.scale or 100.0
    local seed = config.seed or 42

    local total = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxValue = 0

    for i = 1, octaves do
        local sx = x / scale * frequency
        local sy = y / scale * frequency
        local noise = HashCoord(
            math.floor(sx * 1000),
            math.floor(sy * 1000),
            seed + i * 31
        )
        -- Ridged: fold at 0.5, creating sharp creases
        noise = 1.0 - math.abs(noise * 2 - 1)
        noise = noise * noise  -- Sharpen ridges
        total = total + noise * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end

    return total / maxValue
end
```

### Terrain Generation with Biomes

```lua
--- Generate heightmap with biome-aware terrain
---@param width integer
---@param height integer
---@param seed integer
---@return table heightmap 2D array [y][x] with values 0-1
function GenerateTerrainHeightmap(width, height, seed)
    local heightmap = {}
    for y = 1, height do
        heightmap[y] = {}
        for x = 1, width do
            -- Base terrain
            local base = FBMNoise(x, y, {
                octaves = 6, persistence = 0.5,
                lacunarity = 2.0, scale = 200, seed = seed
            })
            -- Mountain overlay
            local mountain = RidgedFBM(x, y, {
                octaves = 4, persistence = 0.6,
                lacunarity = 2.2, scale = 150, seed = seed + 1000
            })
            -- Blend: mountains only where base terrain is high
            local mountainMask = math.max(0, base - 0.5) * 2
            heightmap[y][x] = base * 0.7 + mountain * mountainMask * 0.3
        end
    end
    return heightmap
end

--- Classify terrain into biomes based on height + moisture
function GetBiome(height, moisture)
    if height < 0.2 then return "water" end
    if height < 0.25 then return "beach" end
    if height > 0.8 then return "snow" end
    if height > 0.6 then
        return moisture > 0.5 and "forest_mountain" or "rock"
    end
    if moisture > 0.7 then return "swamp" end
    if moisture > 0.4 then return "forest" end
    if moisture > 0.2 then return "grassland" end
    return "desert"
end
```

---

## 3. Domain Warping

```lua
--- Domain warping (Inigo Quilez technique)
--- Distorts noise coordinates for alien/organic landscapes
---@param x number
---@param y number
---@param config table {warpStrength, scale, seed}
---@return number warped noise value 0-1
function DomainWarpedNoise(x, y, config)
    local warpStrength = config.warpStrength or 50.0
    local scale = config.scale or 100.0
    local seed = config.seed or 42

    -- First pass: get warp offsets
    local warpX = FBMNoise(x, y, {
        octaves = 4, scale = scale, seed = seed
    }) * warpStrength

    local warpY = FBMNoise(x, y, {
        octaves = 4, scale = scale, seed = seed + 500
    }) * warpStrength

    -- Second pass: sample noise at warped coordinates
    return FBMNoise(x + warpX, y + warpY, {
        octaves = 6, scale = scale, seed = seed + 1000
    })
end
```

---

## 4. Cellular Automata Cave Generation

```lua
--- Cellular automata cave generator (4-5 rule)
--- Creates organic cave-like structures
local CaveGenerator = {}

--- Generate a cave map
---@param width integer
---@param height integer
---@param seed integer
---@param config table {fillPercent, iterations, wallThreshold, minCaveSize}
---@return table map 2D array [y][x], 0=floor 1=wall
function CaveGenerator.generate(width, height, seed, config)
    config = config or {}
    local fillPercent = config.fillPercent or 0.45
    local iterations = config.iterations or 5
    local wallThreshold = config.wallThreshold or 4
    local minCaveSize = config.minCaveSize or 50

    -- Step 1: Random fill
    math.randomseed(seed)
    for i = 1, 3 do math.random() end  -- Warm up

    local map = {}
    for y = 1, height do
        map[y] = {}
        for x = 1, width do
            -- Borders are always walls
            if x == 1 or x == width or y == 1 or y == height then
                map[y][x] = 1
            else
                map[y][x] = math.random() < fillPercent and 1 or 0
            end
        end
    end

    -- Step 2: Cellular automata smoothing (4-5 rule)
    for iter = 1, iterations do
        local newMap = {}
        for y = 1, height do
            newMap[y] = {}
            for x = 1, width do
                local walls = CaveGenerator.countNeighborWalls(map, x, y, width, height)
                if walls > wallThreshold then
                    newMap[y][x] = 1  -- Become wall
                elseif walls < wallThreshold then
                    newMap[y][x] = 0  -- Become floor
                else
                    newMap[y][x] = map[y][x]  -- Stay same
                end
            end
        end
        map = newMap
    end

    -- Step 3: Remove small isolated caves
    CaveGenerator.removeSmallRegions(map, width, height, minCaveSize, 0)
    -- Step 4: Remove small isolated walls
    CaveGenerator.removeSmallRegions(map, width, height, minCaveSize, 1)

    return map
end

--- Count wall neighbors in 3x3 area
function CaveGenerator.countNeighborWalls(map, cx, cy, width, height)
    local count = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = cx + dx, cy + dy
            if nx < 1 or nx > width or ny < 1 or ny > height then
                count = count + 1  -- Out of bounds = wall
            elseif not (dx == 0 and dy == 0) then
                count = count + map[ny][nx]
            end
        end
    end
    return count
end

--- Flood fill to find connected regions, remove small ones
function CaveGenerator.removeSmallRegions(map, width, height, minSize, targetTile)
    local visited = {}
    for y = 1, height do
        visited[y] = {}
        for x = 1, width do visited[y][x] = false end
    end

    for y = 1, height do
        for x = 1, width do
            if not visited[y][x] and map[y][x] == targetTile then
                local region = CaveGenerator.floodFill(map, visited, x, y, width, height, targetTile)
                if #region < minSize then
                    -- Fill small region with opposite tile
                    local fillTile = targetTile == 0 and 1 or 0
                    for _, pos in ipairs(region) do
                        map[pos.y][pos.x] = fillTile
                    end
                end
            end
        end
    end
end

--- BFS flood fill, returns list of {x, y} positions
function CaveGenerator.floodFill(map, visited, startX, startY, width, height, targetTile)
    local region = {}
    local queue = {{x = startX, y = startY}}
    visited[startY][startX] = true

    while #queue > 0 do
        local pos = table.remove(queue, 1)
        table.insert(region, pos)

        local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
        for _, d in ipairs(dirs) do
            local nx, ny = pos.x + d[1], pos.y + d[2]
            if nx >= 1 and nx <= width and ny >= 1 and ny <= height
               and not visited[ny][nx] and map[ny][nx] == targetTile then
                visited[ny][nx] = true
                table.insert(queue, {x = nx, y = ny})
            end
        end
    end
    return region
end

--- Validate cave connectivity (all floor tiles reachable from spawn)
function CaveGenerator.validate(map, width, height)
    -- Find first floor tile as spawn
    local spawnX, spawnY
    for y = 1, height do
        for x = 1, width do
            if map[y][x] == 0 then
                spawnX, spawnY = x, y
                goto found
            end
        end
    end
    ::found::

    if not spawnX then return false, "no_floor_tiles" end

    -- Flood fill from spawn
    local visited = {}
    for y = 1, height do
        visited[y] = {}
        for x = 1, width do visited[y][x] = false end
    end

    local reachable = CaveGenerator.floodFill(map, visited, spawnX, spawnY, width, height, 0)

    -- Count total floor tiles
    local totalFloor = 0
    for y = 1, height do
        for x = 1, width do
            if map[y][x] == 0 then totalFloor = totalFloor + 1 end
        end
    end

    if #reachable < totalFloor then
        return false, string.format("disconnected: %d/%d reachable", #reachable, totalFloor)
    end

    return true, "connected"
end
```

---

## 5. L-Systems

```lua
--- L-System string rewriting + turtle graphics interpretation
local LSystem = {}
LSystem.__index = LSystem

function LSystem.new(axiom, rules, angle, length)
    local self = setmetatable({}, LSystem)
    self.axiom = axiom
    self.rules = rules          -- {F = "F[+F]F[-F]F"}
    self.angle = angle or 25    -- Degrees
    self.length = length or 10  -- Pixels/units
    return self
end

--- Apply production rules n times
function LSystem:generate(iterations)
    local current = self.axiom
    for i = 1, iterations do
        local next = ""
        for j = 1, #current do
            local ch = current:sub(j, j)
            next = next .. (self.rules[ch] or ch)
        end
        current = next
    end
    return current
end

--- Interpret L-system string as turtle graphics
--- Returns list of line segments {{x1,y1,x2,y2}, ...}
function LSystem:interpret(str, startX, startY, startAngle)
    local x, y = startX or 0, startY or 0
    local angle = startAngle or -90  -- Start pointing up
    local stack = {}
    local lines = {}

    for i = 1, #str do
        local ch = str:sub(i, i)
        if ch == "F" then
            -- Move forward, draw line
            local rad = math.rad(angle)
            local nx = x + math.cos(rad) * self.length
            local ny = y + math.sin(rad) * self.length
            table.insert(lines, {x1 = x, y1 = y, x2 = nx, y2 = ny})
            x, y = nx, ny
        elseif ch == "f" then
            -- Move forward without drawing
            local rad = math.rad(angle)
            x = x + math.cos(rad) * self.length
            y = y + math.sin(rad) * self.length
        elseif ch == "+" then
            angle = angle + self.angle
        elseif ch == "-" then
            angle = angle - self.angle
        elseif ch == "[" then
            table.insert(stack, {x = x, y = y, angle = angle})
        elseif ch == "]" then
            local state = table.remove(stack)
            x, y, angle = state.x, state.y, state.angle
        end
    end

    return lines
end

--- Classic presets
LSystem.PRESETS = {
    -- Realistic tree
    tree = {
        axiom = "X",
        rules = {X = "F+[[X]-X]-F[-FX]+X", F = "FF"},
        angle = 25, length = 5
    },
    -- Bush
    bush = {
        axiom = "F",
        rules = {F = "FF+[+F-F-F]-[-F+F+F]"},
        angle = 22.5, length = 8
    },
    -- Koch snowflake
    koch = {
        axiom = "F++F++F",
        rules = {F = "F-F++F-F"},
        angle = 60, length = 4
    },
    -- Dragon curve
    dragon = {
        axiom = "FX",
        rules = {X = "X+YF+", Y = "-FX-Y"},
        angle = 90, length = 5
    },
}

--- Stochastic L-System (weighted rule selection)
local StochasticLSystem = {}
StochasticLSystem.__index = StochasticLSystem

function StochasticLSystem.new(axiom, weightedRules, angle, length)
    local self = setmetatable({}, StochasticLSystem)
    self.axiom = axiom
    -- weightedRules = {F = {{rule="FF", weight=0.7}, {rule="F", weight=0.3}}}
    self.weightedRules = weightedRules
    self.angle = angle or 25
    self.length = length or 10
    return self
end

function StochasticLSystem:generate(iterations, seed)
    math.randomseed(seed or os.time())
    for i = 1, 3 do math.random() end

    local current = self.axiom
    for i = 1, iterations do
        local next = ""
        for j = 1, #current do
            local ch = current:sub(j, j)
            local rules = self.weightedRules[ch]
            if rules then
                -- Weighted random selection
                local totalWeight = 0
                for _, r in ipairs(rules) do totalWeight = totalWeight + r.weight end
                local roll = math.random() * totalWeight
                local cumulative = 0
                for _, r in ipairs(rules) do
                    cumulative = cumulative + r.weight
                    if roll <= cumulative then
                        next = next .. r.rule
                        break
                    end
                end
            else
                next = next .. ch
            end
        end
        current = next
    end
    return current
end

-- Reuse interpret() from LSystem
StochasticLSystem.interpret = LSystem.interpret
```

---

## 6. Markov Chain Generation

```lua
--- Markov chain for name/text generation
local MarkovGenerator = {}
MarkovGenerator.__index = MarkovGenerator

--- Create from training data
---@param trainingData string[] list of example strings
---@param order integer context window size (2 recommended for names)
function MarkovGenerator.new(trainingData, order)
    local self = setmetatable({}, MarkovGenerator)
    self.order = order or 2
    self.chains = {}  -- {prefix = {char = count}}
    self.starters = {} -- Valid starting prefixes

    for _, word in ipairs(trainingData) do
        local padded = string.rep("^", self.order) .. word .. "$"
        for i = 1, #padded - self.order do
            local prefix = padded:sub(i, i + self.order - 1)
            local nextChar = padded:sub(i + self.order, i + self.order)

            if not self.chains[prefix] then
                self.chains[prefix] = {}
            end
            self.chains[prefix][nextChar] = (self.chains[prefix][nextChar] or 0) + 1

            -- Track valid starters
            if prefix == string.rep("^", self.order) then
                -- Already handled by padding
            end
        end
    end

    return self
end

--- Generate a new string
---@param seed integer random seed
---@param minLen integer minimum length (default 3)
---@param maxLen integer maximum length (default 12)
---@return string generated name/word
function MarkovGenerator:generate(seed, minLen, maxLen)
    minLen = minLen or 3
    maxLen = maxLen or 12

    math.randomseed(seed)
    for i = 1, 3 do math.random() end

    local result = ""
    local prefix = string.rep("^", self.order)

    for i = 1, maxLen + self.order do
        local choices = self.chains[prefix]
        if not choices then break end

        -- Weighted random selection from choices
        local total = 0
        for _, count in pairs(choices) do total = total + count end
        local roll = math.random() * total
        local cumulative = 0
        local nextChar = "$"
        for ch, count in pairs(choices) do
            cumulative = cumulative + count
            if roll <= cumulative then
                nextChar = ch
                break
            end
        end

        if nextChar == "$" then
            if #result >= minLen then break end
            -- Too short, restart
            result = ""
            prefix = string.rep("^", self.order)
        else
            result = result .. nextChar
            prefix = prefix:sub(2) .. nextChar
        end
    end

    -- Capitalize first letter
    if #result > 0 then
        result = result:sub(1, 1):upper() .. result:sub(2)
    end

    return result
end

--- Batch generate unique names
function MarkovGenerator:generateBatch(count, baseSeed)
    local names = {}
    local seen = {}
    local seed = baseSeed or 42
    local attempts = 0

    while #names < count and attempts < count * 10 do
        local name = self:generate(seed + attempts)
        attempts = attempts + 1
        if #name >= 3 and not seen[name:lower()] then
            seen[name:lower()] = true
            table.insert(names, name)
        end
    end

    return names
end

-- Example training data for fantasy names
MarkovGenerator.FANTASY_NAMES = {
    "Aldric", "Brenna", "Caelum", "Darius", "Elena", "Faelan",
    "Gideon", "Helena", "Isolde", "Jorah", "Kira", "Lyric",
    "Morwen", "Nadia", "Orion", "Petra", "Quinn", "Rowan",
    "Sylvia", "Theron", "Ursula", "Valen", "Wren", "Xander",
    "Yara", "Zephyr", "Alaric", "Bronwyn", "Cedric", "Dagmar",
}
```

---

## 7. Wave Function Collapse

```lua
--- Simplified Wave Function Collapse for tile-based maps
--- Based on Maxim Gumin's algorithm
local WFC = {}
WFC.__index = WFC

--- Initialize WFC solver
---@param width integer grid width
---@param height integer grid height
---@param tiles table list of tile definitions
---@param adjacency table adjacency rules {tileA = {dir = {tileB, tileC}}}
function WFC.new(width, height, tiles, adjacency)
    local self = setmetatable({}, WFC)
    self.width = width
    self.height = height
    self.tiles = tiles
    self.adjacency = adjacency
    self.numTiles = #tiles

    -- Initialize grid: each cell has all tiles as possibilities
    self.grid = {}
    for y = 1, height do
        self.grid[y] = {}
        for x = 1, width do
            self.grid[y][x] = {}
            for i = 1, self.numTiles do
                self.grid[y][x][i] = true  -- All tiles possible
            end
        end
    end

    self.collapsed = {}
    for y = 1, height do
        self.collapsed[y] = {}
        for x = 1, width do
            self.collapsed[y][x] = nil
        end
    end

    return self
end

--- Count possible tiles for a cell
function WFC:entropy(x, y)
    local count = 0
    for i = 1, self.numTiles do
        if self.grid[y][x][i] then count = count + 1 end
    end
    return count
end

--- Find cell with lowest entropy (most constrained)
function WFC:findLowestEntropy()
    local minEntropy = self.numTiles + 1
    local candidates = {}

    for y = 1, self.height do
        for x = 1, self.width do
            if not self.collapsed[y][x] then
                local e = self:entropy(x, y)
                if e == 0 then return nil end  -- Contradiction\!
                if e < minEntropy then
                    minEntropy = e
                    candidates = {{x = x, y = y}}
                elseif e == minEntropy then
                    table.insert(candidates, {x = x, y = y})
                end
            end
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

--- Collapse a cell to a single tile
function WFC:collapse(x, y)
    local possible = {}
    for i = 1, self.numTiles do
        if self.grid[y][x][i] then
            table.insert(possible, i)
        end
    end

    if #possible == 0 then return false end

    local chosen = possible[math.random(1, #possible)]
    self.collapsed[y][x] = chosen

    -- Set only chosen tile as possible
    for i = 1, self.numTiles do
        self.grid[y][x][i] = (i == chosen)
    end

    return true
end

--- Propagate constraints from collapsed cell
function WFC:propagate(startX, startY)
    local stack = {{x = startX, y = startY}}
    local dirs = {
        {dx = 0, dy = -1, name = "up"},
        {dx = 0, dy = 1, name = "down"},
        {dx = -1, dy = 0, name = "left"},
        {dx = 1, dy = 0, name = "right"},
    }

    while #stack > 0 do
        local pos = table.remove(stack)

        for _, dir in ipairs(dirs) do
            local nx, ny = pos.x + dir.dx, pos.y + dir.dy
            if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                local changed = false
                for i = 1, self.numTiles do
                    if self.grid[ny][nx][i] then
                        -- Check if tile i is compatible with any tile at pos
                        local compatible = false
                        for j = 1, self.numTiles do
                            if self.grid[pos.y][pos.x][j] then
                                local tileName = self.tiles[j]
                                local allowed = self.adjacency[tileName]
                                    and self.adjacency[tileName][dir.name]
                                if allowed then
                                    for _, a in ipairs(allowed) do
                                        if a == self.tiles[i] then
                                            compatible = true
                                            break
                                        end
                                    end
                                end
                                if compatible then break end
                            end
                        end
                        if not compatible then
                            self.grid[ny][nx][i] = false
                            changed = true
                        end
                    end
                end
                if changed then
                    table.insert(stack, {x = nx, y = ny})
                end
            end
        end
    end
end

--- Run WFC to completion
---@param seed integer
---@return table|nil result grid [y][x] = tile name, or nil on failure
function WFC:solve(seed)
    math.randomseed(seed)
    for i = 1, 3 do math.random() end

    local maxSteps = self.width * self.height

    for step = 1, maxSteps do
        local cell = self:findLowestEntropy()
        if not cell then
            -- Check if fully solved
            local complete = true
            for y = 1, self.height do
                for x = 1, self.width do
                    if not self.collapsed[y][x] then
                        complete = false
                        break
                    end
                end
                if not complete then break end
            end
            if complete then break end
            return nil  -- Contradiction
        end

        if not self:collapse(cell.x, cell.y) then
            return nil  -- Contradiction
        end

        self:propagate(cell.x, cell.y)
    end

    -- Build result grid
    local result = {}
    for y = 1, self.height do
        result[y] = {}
        for x = 1, self.width do
            result[y][x] = self.tiles[self.collapsed[y][x]] or "unknown"
        end
    end

    return result
end

--- Example: Simple terrain WFC
WFC.TERRAIN_EXAMPLE = {
    tiles = {"water", "sand", "grass", "forest", "mountain"},
    adjacency = {
        water    = {up={"water","sand"}, down={"water","sand"}, left={"water","sand"}, right={"water","sand"}},
        sand     = {up={"water","sand","grass"}, down={"water","sand","grass"}, left={"water","sand","grass"}, right={"water","sand","grass"}},
        grass    = {up={"sand","grass","forest"}, down={"sand","grass","forest"}, left={"sand","grass","forest"}, right={"sand","grass","forest"}},
        forest   = {up={"grass","forest","mountain"}, down={"grass","forest","mountain"}, left={"grass","forest","mountain"}, right={"grass","forest","mountain"}},
        mountain = {up={"forest","mountain"}, down={"forest","mountain"}, left={"forest","mountain"}, right={"forest","mountain"}},
    }
}
```

---

## 8. Chunk-Based Infinite World

```lua
--- Chunk-based world generation for infinite/large worlds
--- Each chunk is generated independently using coordinate hash
local ChunkWorld = {}
ChunkWorld.__index = ChunkWorld

function ChunkWorld.new(chunkSize, seed, generateFn)
    local self = setmetatable({}, ChunkWorld)
    self.chunkSize = chunkSize or 16
    self.seed = seed or 42
    self.generateFn = generateFn  -- function(chunkX, chunkY, seed) -> chunkData
    self.loadedChunks = {}        -- ["x,y"] = chunkData
    self.loadRadius = 3           -- Load chunks within this radius
    return self
end

--- Get chunk key for storage
function ChunkWorld:key(cx, cy)
    return string.format("%d,%d", cx, cy)
end

--- Get or generate chunk at chunk coordinates
function ChunkWorld:getChunk(cx, cy)
    local k = self:key(cx, cy)
    if not self.loadedChunks[k] then
        -- Generate using coordinate hash for deterministic per-chunk seed
        local chunkSeed = math.floor(HashCoord(cx, cy, self.seed) * 0x7FFFFFFF)
        self.loadedChunks[k] = self.generateFn(cx, cy, chunkSeed)
    end
    return self.loadedChunks[k]
end

--- Convert world position to chunk coordinates
function ChunkWorld:worldToChunk(wx, wy)
    return math.floor(wx / self.chunkSize), math.floor(wy / self.chunkSize)
end

--- Update loaded chunks based on player position
--- Returns lists of newly loaded and unloaded chunk keys
function ChunkWorld:updateAroundPosition(worldX, worldY)
    local pcx, pcy = self:worldToChunk(worldX, worldY)
    local loaded = {}
    local unloaded = {}

    -- Mark chunks that should be loaded
    local shouldExist = {}
    for dy = -self.loadRadius, self.loadRadius do
        for dx = -self.loadRadius, self.loadRadius do
            local cx, cy = pcx + dx, pcy + dy
            local k = self:key(cx, cy)
            shouldExist[k] = true
            if not self.loadedChunks[k] then
                self:getChunk(cx, cy)
                table.insert(loaded, k)
            end
        end
    end

    -- Unload distant chunks
    for k, _ in pairs(self.loadedChunks) do
        if not shouldExist[k] then
            self.loadedChunks[k] = nil
            table.insert(unloaded, k)
        end
    end

    return loaded, unloaded
end
```
