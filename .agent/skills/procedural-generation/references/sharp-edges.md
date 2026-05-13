# PCG Sharp Edges & Common Pitfalls

> Critical mistakes in procedural generation that cause bugs, crashes, or bad player experiences.
> Each entry includes: severity, symptoms, why it happens, and solution with UrhoX Lua code.

## Table of Contents

1. [CRITICAL: Same Seed Different Results](#1-same-seed-different-results)
2. [CRITICAL: Unplayable Generated Content](#2-unplayable-generated-content)
3. [CRITICAL: No Fallback Content](#3-no-fallback-content)
4. [HIGH: Floating Point Accumulation](#4-floating-point-accumulation)
5. [HIGH: Non-Deterministic Iteration Order](#5-non-deterministic-iteration-order)
6. [HIGH: Main Thread Blocking](#6-main-thread-blocking)
7. [MEDIUM: Uniform Distribution Bias](#7-uniform-distribution-bias)
8. [MEDIUM: Noise Tiling Seams](#8-noise-tiling-seams)
9. [MEDIUM: Memory Explosion in Large Worlds](#9-memory-explosion-in-large-worlds)
10. [LOW: Lua Array Index Off-by-One](#10-lua-array-index-off-by-one)

---

## 1. Same Seed Different Results

**Severity**: CRITICAL

**Symptoms**:
- Same seed produces different worlds across sessions
- Multiplayer world desync
- Saved worlds load differently
- Shared seeds don't reproduce the same map

**Why It Happens**:
1. `math.random()` state is global — any code calling it changes the sequence
2. Iterating over Lua tables with `pairs()` has undefined order
3. Adding new generation steps changes the RNG consumption sequence
4. OS time-dependent code mixed with seeded generation

**Solution**:

```lua
-- BAD: Global math.random state shared everywhere
function GenerateWorld(seed)
    math.randomseed(seed)
    local terrain = GenerateTerrain()  -- Consumes N random values
    SpawnEnemies()  -- Also uses math.random — if count changes, terrain changes\!
end

-- GOOD: Coordinate-based hashing (each position is independent)
function GenerateWorld(seed)
    for y = 1, height do
        for x = 1, width do
            -- Each tile uses its own deterministic hash
            local value = HashCoord(x, y, seed)
            map[y][x] = value > 0.5 and 1 or 0
        end
    end
    -- Enemy spawning uses different seed offset — won't affect terrain
    for y = 1, height do
        for x = 1, width do
            local enemyRoll = HashCoord(x, y, seed + 10000)
            if enemyRoll > 0.95 then SpawnEnemy(x, y) end
        end
    end
end

-- GOOD: Isolated RNG per subsystem
function GenerateWorld(seed)
    -- Each subsystem gets its own seed offset
    local terrainSeed = seed
    local enemySeed = seed + 10000
    local lootSeed = seed + 20000

    math.randomseed(terrainSeed)
    GenerateTerrain()

    math.randomseed(enemySeed)
    SpawnEnemies()

    math.randomseed(lootSeed)
    PlaceLoot()
end
```

---

## 2. Unplayable Generated Content

**Severity**: CRITICAL

**Symptoms**:
- Players stuck with no path forward
- "Impossible level" bug reports
- Key items spawn in unreachable areas
- Exit blocked by walls
- QA can't reproduce (different seed)

**Why It Happens**:
1. No validation of connectivity between areas
2. Required items spawn in unreachable locations
3. Difficulty spikes make levels practically impossible
4. Edge cases in generation algorithms

**Solution**:

```lua
-- ALWAYS validate generated content
function GenerateLevel(seed, params)
    local MAX_ATTEMPTS = 100

    for attempt = 1, MAX_ATTEMPTS do
        local currentSeed = seed + attempt - 1
        math.randomseed(currentSeed)
        for i = 1, 3 do math.random() end

        local level = RawGenerateLevel(params)

        -- Validation pipeline (cheapest checks first)
        local valid, reason = ValidateLevel(level, params)
        if valid then
            print(string.format("Level generated: seed=%d, attempt=%d", currentSeed, attempt))
            return level, currentSeed
        end

        print(string.format("Seed %d rejected: %s", currentSeed, reason))
    end

    -- CRITICAL: Never show broken content
    print("WARNING: All attempts failed, using fallback level")
    return GetHandcraftedFallback(params), "fallback"
end

function ValidateLevel(level, params)
    -- 1. Structure (O(1))
    if not level.spawn then return false, "no_spawn" end
    if not level.exit then return false, "no_exit" end

    -- 2. Size (O(1))
    local area = CountFloorTiles(level)
    if area < params.minArea then return false, "too_small" end
    if area > params.maxArea then return false, "too_large" end

    -- 3. Connectivity (O(n) flood fill)
    if not IsFullyConnected(level) then return false, "disconnected" end

    -- 4. Path exists (O(n))
    if not PathExists(level.spawn, level.exit, level) then
        return false, "no_path_to_exit"
    end

    -- 5. Required items reachable
    for _, item in ipairs(level.requiredItems) do
        if not PathExists(level.spawn, item.position, level) then
            return false, "unreachable_item:" .. item.name
        end
    end

    return true, "valid"
end
```

---

## 3. No Fallback Content

**Severity**: CRITICAL

**Symptoms**:
- Game crashes when generation fails
- Infinite loading screen
- Empty/broken level displayed
- Players see debug geometry

**Solution**:

```lua
-- ALWAYS have handcrafted fallback levels
local FALLBACK_LEVELS = {
    -- Simple but guaranteed-valid level
    small = {
        width = 10, height = 10,
        spawn = {x = 2, y = 2},
        exit = {x = 9, y = 9},
        -- Pre-validated handcrafted layout
        data = {
            {1,1,1,1,1,1,1,1,1,1},
            {1,0,0,0,0,0,0,0,0,1},
            {1,0,0,0,1,1,0,0,0,1},
            {1,0,0,0,0,0,0,0,0,1},
            {1,0,1,1,0,0,1,1,0,1},
            {1,0,0,0,0,0,0,0,0,1},
            {1,0,0,1,1,0,0,0,0,1},
            {1,0,0,0,0,0,0,1,0,1},
            {1,0,0,0,0,0,0,0,0,1},
            {1,1,1,1,1,1,1,1,1,1},
        }
    }
}

function GetHandcraftedFallback(params)
    return FALLBACK_LEVELS.small
end
```

---

## 4. Floating Point Accumulation

**Severity**: HIGH

**Symptoms**:
- Terrain looks slightly different each time despite same seed
- Chunk boundaries have visible seams
- Coordinates drift over large distances
- Heightmap values gradually diverge

**Solution**:

```lua
-- BAD: Accumulated float errors
local pos = 0
for i = 1, 1000000 do
    pos = pos + 0.001  -- Error compounds with each addition
end
-- pos ≈ 999.9999... (not exactly 1000)

-- GOOD: Calculate from integers
function GetPosition(step, stepSize)
    return step * stepSize  -- Single multiplication, minimal error
end

-- GOOD: Use integer coordinates, convert only for display
function GenerateChunkTerrain(chunkX, chunkY, seed)
    for ly = 1, CHUNK_SIZE do
        for lx = 1, CHUNK_SIZE do
            -- Integer world coordinates (exact)
            local wx = chunkX * CHUNK_SIZE + lx
            local wy = chunkY * CHUNK_SIZE + ly
            -- Hash from integers (deterministic)
            local height = HashCoord(wx, wy, seed)
        end
    end
end
```

---

## 5. Non-Deterministic Iteration Order

**Severity**: HIGH

**Symptoms**:
- Same seed, slightly different results each run
- Works in testing, fails in production
- Multiplayer desync despite same seed

**Why It Happens**: Lua `pairs()` iterates hash tables in undefined order.

**Solution**:

```lua
-- BAD: pairs() order is non-deterministic
local tileChoices = {water = 0.3, grass = 0.5, forest = 0.2}
for tile, weight in pairs(tileChoices) do
    -- Order may vary between runs\!
    -- This means math.random() is consumed in different order
end

-- GOOD: Use ipairs() with sorted array
local tileChoices = {
    {tile = "forest", weight = 0.2},
    {tile = "grass", weight = 0.5},
    {tile = "water", weight = 0.3},
}
-- Sort to guarantee order
table.sort(tileChoices, function(a, b) return a.tile < b.tile end)
for _, choice in ipairs(tileChoices) do
    -- Deterministic order every time
end
```

---

## 6. Main Thread Blocking

**Severity**: HIGH

**Symptoms**:
- Game freezes during level generation
- Loading screen doesn't animate
- Input becomes unresponsive
- Frame rate drops to 0 during generation

**Solution**:

```lua
-- GOOD: Chunked generation across frames using coroutine
local generationCoroutine = nil

function StartGeneration(seed, width, height)
    generationCoroutine = coroutine.create(function()
        local map = {}
        for y = 1, height do
            map[y] = {}
            for x = 1, width do
                map[y][x] = HashCoord(x, y, seed) > 0.5 and 1 or 0
            end
            -- Yield every row to let game loop run
            if y % 4 == 0 then
                coroutine.yield(y / height)  -- Report progress
            end
        end
        return map
    end)
end

function HandleUpdate(eventType, eventData)
    if generationCoroutine then
        local ok, result = coroutine.resume(generationCoroutine)
        if not ok then
            print("Generation error: " .. tostring(result))
            generationCoroutine = nil
        elseif coroutine.status(generationCoroutine) == "dead" then
            -- Generation complete, result is the map
            OnGenerationComplete(result)
            generationCoroutine = nil
        else
            -- result is progress (0-1)
            UpdateLoadingBar(result)
        end
    end
end
```

---

## 7. Uniform Distribution Bias

**Severity**: MEDIUM

**Symptoms**:
- Generated landscapes look "flat" and boring
- No clear landmarks or points of interest
- Everything looks the same
- Player has no sense of direction

**Solution**:

```lua
-- BAD: Uniform random placement
for i = 1, numTrees do
    local x = math.random(1, width)
    local y = math.random(1, height)
    PlaceTree(x, y)
end

-- GOOD: Poisson disk sampling for even spacing
function PoissonDiskSample(width, height, minDist, seed, maxAttempts)
    math.randomseed(seed)
    for i = 1, 3 do math.random() end

    maxAttempts = maxAttempts or 30
    local cellSize = minDist / math.sqrt(2)
    local gridW = math.ceil(width / cellSize)
    local gridH = math.ceil(height / cellSize)

    local grid = {}
    for y = 1, gridH do
        grid[y] = {}
        for x = 1, gridW do grid[y][x] = nil end
    end

    local points = {}
    local active = {}

    -- Start with random point
    local firstX = math.random() * width
    local firstY = math.random() * height
    table.insert(points, {x = firstX, y = firstY})
    table.insert(active, #points)
    local gx = math.floor(firstX / cellSize) + 1
    local gy = math.floor(firstY / cellSize) + 1
    if gx >= 1 and gx <= gridW and gy >= 1 and gy <= gridH then
        grid[gy][gx] = #points
    end

    while #active > 0 do
        local idx = math.random(1, #active)
        local point = points[active[idx]]
        local found = false

        for attempt = 1, maxAttempts do
            local angle = math.random() * math.pi * 2
            local dist = minDist + math.random() * minDist
            local nx = point.x + math.cos(angle) * dist
            local ny = point.y + math.sin(angle) * dist

            if nx >= 0 and nx < width and ny >= 0 and ny < height then
                local ngx = math.floor(nx / cellSize) + 1
                local ngy = math.floor(ny / cellSize) + 1
                local tooClose = false

                for dy = -2, 2 do
                    for dx = -2, 2 do
                        local cx, cy = ngx + dx, ngy + dy
                        if cx >= 1 and cx <= gridW and cy >= 1 and cy <= gridH then
                            local other = grid[cy][cx]
                            if other then
                                local ddx = points[other].x - nx
                                local ddy = points[other].y - ny
                                if ddx*ddx + ddy*ddy < minDist*minDist then
                                    tooClose = true
                                    break
                                end
                            end
                        end
                    end
                    if tooClose then break end
                end

                if not tooClose then
                    table.insert(points, {x = nx, y = ny})
                    table.insert(active, #points)
                    if ngx >= 1 and ngx <= gridW and ngy >= 1 and ngy <= gridH then
                        grid[ngy][ngx] = #points
                    end
                    found = true
                    break
                end
            end
        end

        if not found then
            table.remove(active, idx)
        end
    end

    return points
end
```

---

## 8. Noise Tiling Seams

**Severity**: MEDIUM

**Symptoms**:
- Visible lines at chunk boundaries
- Terrain height jumps at edges
- Texture patterns don't match across chunks

**Solution**:

```lua
-- Use coordinate-based noise (HashCoord), not chunk-local random
-- HashCoord naturally tiles because it hashes world coordinates

-- BAD: Chunk-local generation
function GenerateChunk(chunkX, chunkY, seed)
    math.randomseed(seed + chunkX * 1000 + chunkY)
    for y = 1, CHUNK_SIZE do
        for x = 1, CHUNK_SIZE do
            chunk[y][x] = math.random()  -- No continuity between chunks\!
        end
    end
end

-- GOOD: World-coordinate noise
function GenerateChunk(chunkX, chunkY, seed)
    for y = 1, CHUNK_SIZE do
        for x = 1, CHUNK_SIZE do
            local wx = chunkX * CHUNK_SIZE + x
            local wy = chunkY * CHUNK_SIZE + y
            chunk[y][x] = FBMNoise(wx, wy, {seed = seed, scale = 100})
        end
    end
end
```

---

## 9. Memory Explosion in Large Worlds

**Severity**: MEDIUM

**Symptoms**:
- Game slows down over time
- Memory usage grows without bound
- Eventually crashes on mobile devices

**Solution**:

```lua
-- Implement chunk loading/unloading (see ChunkWorld in pcg-algorithms.md)
-- Key: unload chunks outside player's load radius

-- Track memory usage
function MonitorChunkMemory(chunkWorld)
    local count = 0
    for _ in pairs(chunkWorld.loadedChunks) do count = count + 1 end
    print(string.format("Loaded chunks: %d", count))

    -- Warning threshold (adjust per platform)
    if count > 100 then
        print("WARNING: Too many chunks loaded, consider reducing load radius")
    end
end
```

---

## 10. Lua Array Index Off-by-One

**Severity**: LOW (but frequent)

**Symptoms**:
- `attempt to index a nil value` at grid edges
- Missing row/column in generated map
- Terrain has holes at boundaries

**Solution**:

```lua
-- BAD: 0-based indexing (C/JavaScript habit)
for y = 0, height - 1 do
    for x = 0, width - 1 do
        map[y][x] = generate(x, y)  -- map[0] is nil\!
    end
end

-- GOOD: 1-based indexing (Lua convention)
for y = 1, height do
    for x = 1, width do
        map[y][x] = generate(x, y)
    end
end

-- Neighbor checking with bounds
function GetNeighbors(map, x, y, width, height)
    local neighbors = {}
    local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
    for _, d in ipairs(dirs) do
        local nx, ny = x + d[1], y + d[2]
        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
            table.insert(neighbors, map[ny][nx])
        end
    end
    return neighbors
end
```
