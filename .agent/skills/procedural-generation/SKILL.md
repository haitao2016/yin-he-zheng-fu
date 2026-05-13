---
name: procedural-generation
description: "Procedural content generation (PCG) patterns and algorithms for UrhoX Lua games, covering noise functions (FBM, Perlin, domain warping), Wave Function Collapse, L-systems, cellular automata cave generation, Markov chain name/text generation, seed-based reproducibility, and generate-validate-fallback workflows. Use when users need to (1) implement noise-based terrain or heightmap generation, (2) generate dungeons, caves, or levels procedurally, (3) create Wave Function Collapse tile-based generation, (4) build L-system trees, plants, or fractal structures, (5) generate random names, items, or descriptions with Markov chains, (6) ensure seed reproducibility for shareable worlds, (7) validate generated content for playability (connectivity, completability), (8) implement chunk-based infinite world generation, (9) create procedural textures, colors, or visual variety, or any other procedural generation tasks in game development."
---

# Procedural Content Generation (PCG) for UrhoX Lua

> Algorithmic content creation patterns adapted for UrhoX Lua game development. Based on proven PCG techniques from GDC talks, academic research, and shipped games.

## Identity

**Role**: Procedural Content Generation Architect

**Core Philosophy**:
1. **Seed reproducibility first** — Same seed = same output, always
2. **Validate before showing** — Never show broken content to players
3. **Hybrid approach** — Hand-authored constraints + procedural variety
4. **Test with 10,000 seeds** — If it fails on 1, it will fail for players
5. **Fallback is mandatory** — When generation fails, have a backup plan

## When to Use Each Algorithm

| Algorithm | Best For | Complexity |
|-----------|----------|------------|
| **FBM Noise** | Terrain, heightmaps, clouds, organic textures | Low |
| **Domain Warping** | Alien landscapes, distorted terrain | Low |
| **Cellular Automata** | Caves, organic shapes | Low |
| **L-Systems** | Trees, plants, fractal patterns | Medium |
| **Markov Chains** | Names, text, item descriptions | Medium |
| **Wave Function Collapse** | Tile-based maps, constrained layouts | High |
| **BSP / Room Placement** | Dungeon rooms with corridors | Medium |
| **Poisson Disk Sampling** | Evenly-spaced object placement | Low |

## Quick Start: Seeded RNG in Lua

```lua
-- UrhoX Lua uses math.random with math.randomseed
-- ALWAYS set seed before generation
function CreateSeededRNG(seed)
    math.randomseed(seed)
    -- Warm up: discard first few values (Lua PRNG quirk)
    for i = 1, 3 do math.random() end
end

-- Coordinate-based hash for chunk generation (Squirrel3, GDC 2017)
function HashCoord(x, y, seed)
    local n = x + y * 198491317 + seed
    n = n ~ (n >> 8)
    n = n * 0x5bd1e995
    n = n ~ (n >> 15)
    n = (n * 0x27d4eb2d) & 0x7FFFFFFF
    return n / 0x7FFFFFFF  -- Returns 0.0-1.0
end
```

## Key Patterns (see references/ for full implementations)

### 1. FBM Noise (Fractal Brownian Motion)

Multiple octaves of noise layered for natural-looking terrain:

```lua
function FBMNoise(x, y, octaves, persistence, lacunarity, seed)
    local total = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxValue = 0

    for i = 1, octaves do
        total = total + HashCoord(
            math.floor(x * frequency),
            math.floor(y * frequency),
            seed + i
        ) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence   -- Each octave quieter
        frequency = frequency * lacunarity     -- Each octave finer
    end

    return total / maxValue  -- Normalize to 0-1
end
```

### 2. Generate-Validate-Fallback Loop

**Critical pattern** — every generator must use this:

```lua
function GenerateValidated(seed, params, maxAttempts)
    maxAttempts = maxAttempts or 100
    for attempt = 1, maxAttempts do
        local result = RawGenerate(seed + attempt - 1, params)
        local valid, reason = Validate(result, params)
        if valid then
            return result, seed + attempt - 1
        end
        -- Log failure for generator improvement
        print(string.format("Seed %d failed: %s", seed + attempt - 1, reason))
    end
    -- NEVER show broken content — use handcrafted fallback
    print("WARNING: All attempts failed, using fallback")
    return GetFallbackContent(params), "fallback"
end
```

### 3. Validation Checklist (ordered by cost)

1. **Structure check** (O(1)) — Spawn point exists? Exit exists?
2. **Size bounds** (O(1)) — Area within min/max range?
3. **Connectivity** (O(n) flood fill) — All areas reachable from spawn?
4. **Path exists** (O(n log n) A*) — Spawn→Exit path possible?
5. **Items reachable** (O(n) per item) — Required items accessible?
6. **Difficulty check** (O(n)) — Within target difficulty range?

## Reference Files

For full algorithm implementations and detailed guidance:

| File | Content | When to Read |
|------|---------|--------------|
| [pcg-algorithms.md](references/pcg-algorithms.md) | Full Lua implementations of all 7 PCG algorithms | Implementing any PCG system |
| [sharp-edges.md](references/sharp-edges.md) | Common PCG pitfalls with detection and solutions | Debugging PCG issues, code review |
| [validations.md](references/validations.md) | Validation rules and quality checks for generated content | Ensuring generated content is playable |

## UrhoX Integration Notes

- **RNG**: Use `math.randomseed(seed)` + warm-up. Lua 5.4 has improved PRNG
- **Coordinate hashing**: Use `HashCoord()` for position-based generation (chunks)
- **Save seeds**: Store generation seed with save data via `cjson.encode()`
- **Chunk loading**: Generate chunks in coroutines to avoid frame spikes
- **Display progress**: Show loading UI during heavy generation (see `urhox-libs/UI`)
- **Arrays**: Lua arrays start at 1, not 0 — all grid loops use `for y = 1, height do`
