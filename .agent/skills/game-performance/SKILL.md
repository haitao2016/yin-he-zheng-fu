---
name: game-performance
description: "Game performance optimization patterns for UrhoX Lua games, covering object pooling, rendering optimization, draw call batching, LOD management, memory profiling, and frame budget analysis. Use when users need to (1) optimize game frame rate or fix lag/stuttering, (2) implement object pooling for bullets/enemies/particles, (3) reduce draw calls or triangle count, (4) configure LOD/draw distance/occlusion culling, (5) profile memory usage or detect leaks, (6) optimize Update loop or reduce per-frame allocations, (7) improve rendering performance for large scenes, (8) batch similar objects for instancing, (9) analyze frame budget and identify bottlenecks, or any other game performance optimization tasks."
---

# Game Performance Optimization

Practical patterns for optimizing UrhoX Lua games: object pooling, rendering pipeline tuning, memory management, and frame budget analysis.

## Trigger Conditions

Activate when the user:
- Reports lag, stuttering, low FPS, or performance issues
- Needs object pooling (bullets, enemies, collectibles, particles)
- Wants to reduce draw calls, batches, or triangle count
- Asks about LOD, draw distance, or culling configuration
- Needs memory profiling or leak detection
- Wants to optimize Update loops or per-frame allocations
- Has large scenes with many objects

## Core Workflow

```
1. Measure  → Identify bottleneck (CPU or GPU)
2. Diagnose → Locate hot path (rendering / physics / scripts)
3. Apply    → Use targeted optimization pattern
4. Verify   → Re-measure to confirm improvement
```

**Never optimize without measuring first.** Premature optimization wastes effort on non-bottlenecks.

## Quick Diagnostics

```lua
-- Add to Update to monitor performance in real-time
local batches    = renderer:GetNumBatches()
local primitives = renderer:GetNumPrimitives()
local lights     = renderer:GetNumLights()

-- Budget guidelines (60 FPS target = 16.67ms per frame)
-- Mobile:  batches < 100,  primitives < 100K
-- Desktop: batches < 300,  primitives < 1M
```

### Bottleneck Decision Tree

```
FPS < target?
├── GPU-bound (GPU time > CPU time)
│   ├── Too many draw calls    → Batching / Instancing (§2)
│   ├── Too many triangles     → LOD / DrawDistance (§3)
│   ├── Overdraw / transparency → Occlusion culling (§3)
│   └── Shadow maps too large  → Shadow config (§3)
│
└── CPU-bound (CPU time > GPU time)
    ├── Too many objects        → Object pool (§1)
    ├── Expensive Update loop   → Staggered updates (§4)
    ├── Physics bottleneck      → Collision layers (§4)
    └── Lua table allocations   → Cache & reuse (§4)
```

## §1 Object Pooling

UrhoX has no built-in pool. Use `node:SetEnabled(false)` to hide, reuse on acquire.

```lua
-- Minimal pool (inline, no module needed)
local pool = {}

local function preWarm(scene, count)
    for i = 1, count do
        local n = scene:CreateChild("Bullet")
        local m = n:CreateComponent("StaticModel")
        m:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        n:SetEnabled(false)
        pool[#pool + 1] = n
    end
end

local function acquire()
    for i = #pool, 1, -1 do
        local n = pool[i]
        if not n:IsEnabled() then
            n:SetEnabled(true)
            return n
        end
    end
    return nil  -- pool exhausted
end

local function release(n)
    n:SetEnabled(false)
    n.position = Vector3(0, -999, 0)  -- move off-screen
end
```

**When to pool**: Objects created/destroyed > 5 per second.

For full implementation with size limits, auto-grow, and callbacks → see `references/object-pool.md`.

## §2 Draw Call Optimization

```lua
-- Enable dynamic instancing (same model + same material = 1 draw call)
renderer:SetDynamicInstancing(true)
renderer:SetMinInstances(2)

-- Maximize batching: use shared materials
local sharedMat = cache:GetResource("Material", "Materials/Stone.xml")
for _, node in ipairs(stoneNodes) do
    node:GetComponent("StaticModel"):SetMaterial(sharedMat)
end
```

**Key rules**:
- Same Model + same Material = auto-batched with instancing
- Unique materials break batches — use `Material:Clone()` only when necessary
- Prefer `SetMaterial(shared)` over per-object material clones

## §3 LOD, Distance, and Culling

```lua
-- DrawDistance: hard cutoff, objects beyond this are invisible
staticModel:SetDrawDistance(150.0)      -- 150m max
staticModel:SetShadowDistance(50.0)     -- shadows only within 50m

-- LodBias: lower = use lower LOD sooner (saves GPU)
staticModel:SetLodBias(1.0)            -- default
camera:SetLodBias(0.8)                 -- global: prefer lower LODs

-- Occlusion culling
renderer:SetMaxOccluderTriangles(5000)
renderer:SetOcclusionBufferSize(256)
-- Mark large objects as occluders
wallModel:SetOccluder(true)
-- Mark small objects as occludees
decorModel:SetOccludee(true)
```

For complete rendering pipeline configuration → see `references/rendering-optimization.md`.

## §4 CPU-Side Patterns

### Staggered Updates

```lua
-- Don't update all enemies every frame
local ENEMY_UPDATE_INTERVAL = 3  -- update 1/3 of enemies per frame
local frameCount = 0

function HandleUpdate(eventType, eventData)
    frameCount = frameCount + 1
    for i, enemy in ipairs(enemies) do
        if i % ENEMY_UPDATE_INTERVAL == frameCount % ENEMY_UPDATE_INTERVAL then
            updateEnemyAI(enemy)
        end
    end
end
```

### Cache References

```lua
-- ❌ Bad: query every frame
function HandleUpdate()
    local model = playerNode:GetComponent("StaticModel")  -- overhead per frame
    local body  = playerNode:GetComponent("RigidBody")
end

-- ✅ Good: cache at creation
local playerModel = playerNode:GetComponent("StaticModel")
local playerBody  = playerNode:GetComponent("RigidBody")
function HandleUpdate()
    -- use playerModel, playerBody directly
end
```

### Avoid Per-Frame Allocation

```lua
-- ❌ Bad: creates new Vector3 every frame
function HandleUpdate()
    local dir = Vector3(0, 0, 1) * speed  -- allocation
end

-- ✅ Good: reuse pre-allocated vector
local moveDir = Vector3(0, 0, 0)
function HandleUpdate()
    moveDir.x, moveDir.y, moveDir.z = 0, 0, speed
end
```

## §5 Performance Profiling

```lua
-- One-shot dump (press F12 to trigger)
if input:GetKeyPress(KEY_F12) then
    engine:DumpProfiler()    -- writes profiler block timings
    engine:DumpMemory()      -- writes memory allocation stats
    engine:DumpResources(true)  -- writes loaded resources list
end

-- Real-time HUD
engine:CreateDebugHud()      -- shows FPS, batches, triangles overlay
```

For complete profiling workflow and interpretation → see `references/profiling-guide.md`.

## Checklist Before Shipping

- [ ] FPS ≥ 60 on target platform (16.67ms frame budget)
- [ ] Batch count within budget (mobile < 100, desktop < 300)
- [ ] No objects created/destroyed in tight loops (use pool)
- [ ] DrawDistance set on all distant objects
- [ ] DynamicInstancing enabled for repeated geometry
- [ ] Component references cached (no GetComponent in Update)
- [ ] No per-frame Lua table/Vector3 allocations in hot paths
- [ ] Profiler dump reviewed, no unexpected spikes

## Reference Files

| Topic | File | Load When |
|-------|------|-----------|
| Object Pool (full impl) | `references/object-pool.md` | Need configurable pool with auto-grow, callbacks, metrics |
| Rendering Pipeline | `references/rendering-optimization.md` | Tuning shadows, instancing, culling, LOD strategies |
| Profiling Guide | `references/profiling-guide.md` | Interpreting profiler output, memory analysis, frame budget |

## Constraints

### MUST DO
- Measure before optimizing — use renderer:GetNumBatches() and GetNumPrimitives()
- Use object pooling for objects created/destroyed frequently
- Cache component references outside Update loops
- Enable DynamicInstancing for scenes with repeated geometry
- Set DrawDistance on objects not visible at far range
- Profile with engine:DumpProfiler() to find real bottlenecks

### MUST NOT DO
- Call node:CreateChild() or node:Remove() in tight Update loops
- Call GetComponent() inside Update — cache it at creation
- Create new Vector3/Quaternion objects every frame in hot paths
- Clone materials unless visual difference is required
- Optimize without measuring — guess-driven optimization is wasted effort
- Use graphics:SetMode() — it is disabled in UrhoX (use GetWidth/GetHeight/GetDPR)
