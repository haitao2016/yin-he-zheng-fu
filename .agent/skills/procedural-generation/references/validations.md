# PCG Validation Rules

> Quality checks for procedurally generated content in UrhoX Lua games.
> Use these to verify generated content is playable and meets design constraints.

## Table of Contents

1. [Seed Reproducibility](#1-seed-reproducibility)
2. [Content Connectivity](#2-content-connectivity)
3. [Content Completability](#3-content-completability)
4. [Size & Density Bounds](#4-size--density-bounds)
5. [Difficulty Validation](#5-difficulty-validation)
6. [Performance Validation](#6-performance-validation)
7. [Save/Load Seed Persistence](#7-saveload-seed-persistence)
8. [Batch Testing Framework](#8-batch-testing-framework)

---

## 1. Seed Reproducibility

**Rule**: Same seed MUST produce identical output every time.

**Check**: Generate same content twice with same seed, compare results.

```lua
--- Verify seed reproducibility
function ValidateSeedReproducibility(generateFn, seed, params)
    local result1 = generateFn(seed, params)
    local result2 = generateFn(seed, params)

    -- Deep compare
    local hash1 = HashContent(result1)
    local hash2 = HashContent(result2)

    if hash1 ~= hash2 then
        return false, "CRITICAL: Same seed produced different results"
    end
    return true, "reproducible"
end

--- Hash generated content for comparison
function HashContent(content)
    local hash = 0
    if type(content) == "table" then
        for y = 1, #content do
            for x = 1, #content[y] do
                local v = content[y][x]
                if type(v) == "number" then
                    hash = ((hash << 5) - hash + math.floor(v * 1000)) & 0x7FFFFFFF
                elseif type(v) == "string" then
                    for i = 1, #v do
                        hash = ((hash << 5) - hash + string.byte(v, i)) & 0x7FFFFFFF
                    end
                end
            end
        end
    end
    return hash
end
```

**Common Violations**:
- Using `pairs()` over hash tables (undefined order)
- Calling `math.random()` from other systems between generation steps
- Using `os.time()` or `os.clock()` in generation code
- Table iteration order changing between Lua versions

---

## 2. Content Connectivity

**Rule**: All gameplay-relevant areas MUST be reachable from the spawn point.

```lua
--- Validate all floor tiles are connected
---@param map table 2D grid [y][x], 0=floor 1=wall
---@param spawnX integer spawn X position
---@param spawnY integer spawn Y position
---@return boolean valid
---@return string reason
function ValidateConnectivity(map, spawnX, spawnY)
    local width = #map[1]
    local height = #map

    -- Verify spawn is on floor
    if map[spawnY][spawnX] ~= 0 then
        return false, "spawn_on_wall"
    end

    -- BFS flood fill from spawn
    local visited = {}
    for y = 1, height do
        visited[y] = {}
        for x = 1, width do visited[y][x] = false end
    end

    local queue = {{x = spawnX, y = spawnY}}
    visited[spawnY][spawnX] = true
    local reachableCount = 0

    while #queue > 0 do
        local pos = table.remove(queue, 1)
        reachableCount = reachableCount + 1

        local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
        for _, d in ipairs(dirs) do
            local nx, ny = pos.x + d[1], pos.y + d[2]
            if nx >= 1 and nx <= width and ny >= 1 and ny <= height
               and not visited[ny][nx] and map[ny][nx] == 0 then
                visited[ny][nx] = true
                table.insert(queue, {x = nx, y = ny})
            end
        end
    end

    -- Count total floor tiles
    local totalFloor = 0
    for y = 1, height do
        for x = 1, width do
            if map[y][x] == 0 then totalFloor = totalFloor + 1 end
        end
    end

    if reachableCount < totalFloor then
        local unreachable = totalFloor - reachableCount
        return false, string.format(
            "disconnected: %d/%d reachable (%d isolated)",
            reachableCount, totalFloor, unreachable
        )
    end

    return true, string.format("connected: %d floor tiles", totalFloor)
end
```

---

## 3. Content Completability

**Rule**: Player MUST be able to reach the exit from spawn, with all required items obtainable.

```lua
--- A* pathfinding for path validation
---@param startX integer
---@param startY integer
---@param endX integer
---@param endY integer
---@param map table 2D grid, 0=walkable
---@return boolean pathExists
function PathExists(startX, startY, endX, endY, map)
    local width = #map[1]
    local height = #map

    if map[startY][startX] ~= 0 or map[endY][endX] ~= 0 then
        return false
    end

    -- A* with octile distance heuristic
    local function heuristic(x1, y1, x2, y2)
        return math.abs(x1 - x2) + math.abs(y1 - y2)
    end

    local function key(x, y) return y * 10000 + x end

    local openSet = {}
    local startKey = key(startX, startY)
    openSet[startKey] = {x = startX, y = startY, g = 0, f = heuristic(startX, startY, endX, endY)}
    local closedSet = {}

    while next(openSet) do
        -- Find lowest f
        local bestKey, bestNode = nil, nil
        for k, node in pairs(openSet) do
            if not bestNode or node.f < bestNode.f then
                bestKey, bestNode = k, node
            end
        end

        if bestNode.x == endX and bestNode.y == endY then
            return true
        end

        openSet[bestKey] = nil
        closedSet[bestKey] = true

        local dirs = {{0,-1}, {0,1}, {-1,0}, {1,0}}
        for _, d in ipairs(dirs) do
            local nx, ny = bestNode.x + d[1], bestNode.y + d[2]
            local nk = key(nx, ny)

            if nx >= 1 and nx <= width and ny >= 1 and ny <= height
               and map[ny][nx] == 0 and not closedSet[nk] then
                local g = bestNode.g + 1
                local existing = openSet[nk]
                if not existing or g < existing.g then
                    openSet[nk] = {
                        x = nx, y = ny,
                        g = g,
                        f = g + heuristic(nx, ny, endX, endY)
                    }
                end
            end
        end
    end

    return false
end

--- Full completability validation
function ValidateCompletability(level)
    local errors = {}

    -- 1. Path from spawn to exit
    if not PathExists(level.spawn.x, level.spawn.y,
                      level.exit.x, level.exit.y, level.map) then
        table.insert(errors, "no_path_spawn_to_exit")
    end

    -- 2. All keys/required items reachable from spawn
    if level.requiredItems then
        for _, item in ipairs(level.requiredItems) do
            if not PathExists(level.spawn.x, level.spawn.y,
                              item.x, item.y, level.map) then
                table.insert(errors, "unreachable_item:" .. (item.name or "unknown"))
            end
        end
    end

    -- 3. Key-locked door validation (keys before doors)
    if level.doors and level.keys then
        for _, door in ipairs(level.doors) do
            local keyForDoor = nil
            for _, k in ipairs(level.keys) do
                if k.id == door.keyId then keyForDoor = k; break end
            end
            if not keyForDoor then
                table.insert(errors, "door_without_key:" .. door.keyId)
            elseif not PathExists(level.spawn.x, level.spawn.y,
                                  keyForDoor.x, keyForDoor.y, level.map) then
                table.insert(errors, "key_behind_own_door:" .. door.keyId)
            end
        end
    end

    if #errors > 0 then
        return false, table.concat(errors, ", ")
    end
    return true, "completable"
end
```

---

## 4. Size & Density Bounds

**Rule**: Generated content must fall within acceptable size and density ranges.

```lua
--- Validate map dimensions and content density
function ValidateSizeAndDensity(map, config)
    local width = #map[1]
    local height = #map
    local errors = {}

    -- Floor area
    local floorCount = 0
    for y = 1, height do
        for x = 1, width do
            if map[y][x] == 0 then floorCount = floorCount + 1 end
        end
    end

    local totalCells = width * height
    local floorRatio = floorCount / totalCells

    -- Minimum playable area
    local minArea = config.minArea or 100
    if floorCount < minArea then
        table.insert(errors, string.format("too_small: %d < %d", floorCount, minArea))
    end

    -- Maximum area (performance)
    local maxArea = config.maxArea or 10000
    if floorCount > maxArea then
        table.insert(errors, string.format("too_large: %d > %d", floorCount, maxArea))
    end

    -- Floor ratio (too open = boring, too closed = cramped)
    local minRatio = config.minFloorRatio or 0.3
    local maxRatio = config.maxFloorRatio or 0.7
    if floorRatio < minRatio then
        table.insert(errors, string.format("too_cramped: %.2f < %.2f", floorRatio, minRatio))
    elseif floorRatio > maxRatio then
        table.insert(errors, string.format("too_open: %.2f > %.2f", floorRatio, maxRatio))
    end

    if #errors > 0 then
        return false, table.concat(errors, ", ")
    end
    return true, string.format("area=%d, ratio=%.2f", floorCount, floorRatio)
end
```

---

## 5. Difficulty Validation

**Rule**: Generated content difficulty must match target difficulty range.

```lua
--- Estimate level difficulty based on structural features
function ValidateDifficulty(level, targetDifficulty)
    local difficulty = 0

    -- Path length (longer = harder)
    -- Use simple BFS distance from spawn to exit
    local pathLen = BFSDistance(level.spawn, level.exit, level.map)
    if pathLen then
        difficulty = difficulty + math.min(pathLen / 100, 1.0) * 0.3
    end

    -- Enemy density
    if level.enemies then
        local enemyDensity = #level.enemies / CountFloorTiles(level.map)
        difficulty = difficulty + math.min(enemyDensity * 100, 1.0) * 0.3
    end

    -- Tight corridors (narrow passages)
    local narrowCount = CountNarrowPassages(level.map)
    difficulty = difficulty + math.min(narrowCount / 20, 1.0) * 0.2

    -- Dead ends
    local deadEnds = CountDeadEnds(level.map)
    difficulty = difficulty + math.min(deadEnds / 10, 1.0) * 0.2

    -- Check against target range
    local tolerance = 0.2
    if math.abs(difficulty - targetDifficulty) > tolerance then
        return false, string.format(
            "difficulty_mismatch: got=%.2f, target=%.2f±%.2f",
            difficulty, targetDifficulty, tolerance
        )
    end

    return true, string.format("difficulty=%.2f (target=%.2f)", difficulty, targetDifficulty)
end
```

---

## 6. Performance Validation

**Rule**: Generated content must not exceed performance budgets.

```lua
--- Validate content won't cause performance issues
function ValidatePerformance(content, platform)
    local errors = {}

    -- Tile/cell count (rendering budget)
    local maxCells = platform == "mobile" and 50000 or 200000
    local totalCells = content.width * content.height
    if totalCells > maxCells then
        table.insert(errors, string.format(
            "too_many_cells: %d > %d (target: %s)",
            totalCells, maxCells, platform
        ))
    end

    -- Entity count
    local maxEntities = platform == "mobile" and 200 or 1000
    local entityCount = (content.enemies and #content.enemies or 0)
                      + (content.items and #content.items or 0)
    if entityCount > maxEntities then
        table.insert(errors, string.format(
            "too_many_entities: %d > %d",
            entityCount, maxEntities
        ))
    end

    if #errors > 0 then
        return false, table.concat(errors, ", ")
    end
    return true, string.format("cells=%d, entities=%d", totalCells, entityCount)
end
```

---

## 7. Save/Load Seed Persistence

**Rule**: Generation seeds MUST be stored with save data for reproducibility.

```lua
--- Save generation metadata with game save
function SaveGenerationData(filename, genData)
    local cjson = require("cjson")
    local saveData = {
        worldSeed = genData.worldSeed,
        levelSeeds = genData.levelSeeds,  -- Per-level seeds
        version = genData.generatorVersion,  -- Track generator version\!
        timestamp = os.time(),
    }

    local file = File:new(filename, FILE_WRITE)
    if file then
        file:WriteString(cjson.encode(saveData))
        file:Close()
    end
end

--- Load and validate generation data
function LoadGenerationData(filename)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_READ)
    if not file then return nil, "file_not_found" end

    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then return nil, "invalid_json" end

    -- Version check: generator changes may break seed compatibility
    if data.version ~= CURRENT_GENERATOR_VERSION then
        print(string.format(
            "WARNING: Save uses generator v%s, current is v%s",
            tostring(data.version), tostring(CURRENT_GENERATOR_VERSION)
        ))
    end

    return data, "ok"
end
```

---

## 8. Batch Testing Framework

**Rule**: Test generation with 10,000+ seeds before shipping.

```lua
--- Batch test generator with many seeds
--- Run during development to find edge cases
function BatchTestGenerator(generateFn, validateFn, config)
    local numSeeds = config.numSeeds or 10000
    local baseSeed = config.baseSeed or 1

    local results = {
        passed = 0,
        failed = 0,
        failures = {},  -- {seed, reason}
        avgAttempts = 0,
    }

    local totalAttempts = 0
    for i = 1, numSeeds do
        local seed = baseSeed + i - 1
        local content, usedSeed = generateFn(seed, config.params)

        if content then
            local valid, reason = validateFn(content, config.params)
            if valid then
                results.passed = results.passed + 1
            else
                results.failed = results.failed + 1
                table.insert(results.failures, {seed = seed, reason = reason})
            end
        else
            results.failed = results.failed + 1
            table.insert(results.failures, {seed = seed, reason = "generation_failed"})
        end

        -- Progress reporting
        if i % 1000 == 0 then
            print(string.format(
                "Tested %d/%d seeds (%.1f%% pass rate)",
                i, numSeeds,
                results.passed / i * 100
            ))
        end
    end

    -- Summary
    local passRate = results.passed / numSeeds * 100
    print(string.format("\n=== Batch Test Results ==="))
    print(string.format("Seeds tested: %d", numSeeds))
    print(string.format("Passed: %d (%.1f%%)", results.passed, passRate))
    print(string.format("Failed: %d (%.1f%%)", results.failed, 100 - passRate))

    if #results.failures > 0 then
        print("\nFirst 10 failures:")
        for i = 1, math.min(10, #results.failures) do
            local f = results.failures[i]
            print(string.format("  Seed %d: %s", f.seed, f.reason))
        end
    end

    -- Target: >99.9% pass rate
    if passRate < 99.9 then
        print(string.format("\nWARNING: Pass rate %.1f%% below 99.9%% target\!", passRate))
    end

    return results
end
```
