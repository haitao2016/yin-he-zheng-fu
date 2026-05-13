# Profiling Guide

Complete guide to performance profiling in UrhoX Lua games: built-in tools, output interpretation, memory analysis, and frame budget diagnosis.

## Table of Contents

1. [Profiling Tools Overview](#profiling-tools-overview)
2. [DebugHud — Real-Time Overlay](#debughud)
3. [Renderer Statistics API](#renderer-statistics-api)
4. [Engine Profiler Dump](#engine-profiler-dump)
5. [Memory Analysis](#memory-analysis)
6. [Resource Audit](#resource-audit)
7. [Custom Timers](#custom-timers)
8. [Performance Dashboard Pattern](#performance-dashboard-pattern)
9. [Diagnosis Flowcharts](#diagnosis-flowcharts)

---

## Profiling Tools Overview

| Tool | Type | When to Use |
|------|------|-------------|
| `engine:CreateDebugHud()` | Real-time overlay | Quick visual check during gameplay |
| `renderer:GetNumBatches()` etc. | Per-frame API | Automated monitoring, conditional logging |
| `engine:DumpProfiler()` | One-shot file dump | Deep analysis of per-subsystem timings |
| `engine:DumpMemory()` | One-shot file dump | Memory leak detection |
| `engine:DumpResources(true)` | One-shot file dump | Find oversized or unused resources |
| Custom Lua timers | Manual | Profile specific game logic sections |

---

## DebugHud

The simplest way to monitor FPS and stats in real-time.

```lua
function Start()
    -- Create debug HUD (shows FPS, memory, draw stats)
    local debugHud = engine:CreateDebugHud()
    -- Toggle visibility with F2
end
```

The HUD shows:
- **FPS** (frames per second)
- **Triangle count** and **batch count**
- **Memory usage**
- **Active lights** and shadow maps

---

## Renderer Statistics API

Query per-frame rendering statistics for automated monitoring.

```lua
-- Call these in HandleUpdate or HandlePostRenderUpdate
local stats = {
    batches    = renderer:GetNumBatches(),       -- draw calls this frame
    primitives = renderer:GetNumPrimitives(),    -- triangles rendered
    geometries = renderer:GetNumGeometries(),    -- geometry objects visible
    lights     = renderer:GetNumLights(),        -- active lights
    shadowMaps = renderer:GetNumShadowMaps(),    -- shadow maps rendered
    occluders  = renderer:GetNumOccluders(),     -- occluder objects processed
}
```

### Automated Warning System

```lua
local WARNING_BATCHES    = 200
local WARNING_PRIMITIVES = 500000
local WARNING_LIGHTS     = 8
local warnCooldown = 0

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    warnCooldown = warnCooldown - dt
    if warnCooldown > 0 then return end

    local batches = renderer:GetNumBatches()
    local prims   = renderer:GetNumPrimitives()
    local lights  = renderer:GetNumLights()

    if batches > WARNING_BATCHES then
        print("[PERF WARNING] Batches:", batches, "> budget", WARNING_BATCHES)
        warnCooldown = 5.0  -- don't spam
    end
    if prims > WARNING_PRIMITIVES then
        print("[PERF WARNING] Primitives:", prims)
        warnCooldown = 5.0
    end
    if lights > WARNING_LIGHTS then
        print("[PERF WARNING] Lights:", lights)
        warnCooldown = 5.0
    end
end
```

### FPS Counter

```lua
local fpsAccum = 0
local fpsFrames = 0
local fpsDisplay = 0

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    fpsAccum = fpsAccum + dt
    fpsFrames = fpsFrames + 1
    if fpsAccum >= 1.0 then
        fpsDisplay = fpsFrames
        fpsFrames = 0
        fpsAccum = fpsAccum - 1.0
    end
end
```

---

## Engine Profiler Dump

Detailed per-subsystem timing breakdown written to log.

```lua
-- Trigger on key press (don't call every frame)
if input:GetKeyPress(KEY_F12) then
    engine:DumpProfiler()
end
```

### Interpreting Profiler Output

The profiler output shows hierarchical timing blocks:

```
Block                          | Count |  Avg  |  Max  | Frame%
-------------------------------+-------+-------+-------+-------
RunFrame                       |     1 | 12.5ms| 18.2ms| 100.0%
  BeginFrame                   |     1 |  0.1ms|  0.2ms|   0.8%
  Update                       |     1 |  3.2ms|  5.1ms|  25.6%
    ScriptUpdate               |     1 |  2.8ms|  4.5ms|  22.4%
    PhysicsUpdate              |     1 |  0.3ms|  0.5ms|   2.4%
  RenderUpdate                 |     1 |  1.1ms|  1.5ms|   8.8%
  Render                       |     1 |  7.8ms| 12.0ms|  62.4%
    ProcessLights              |     1 |  0.3ms|  0.4ms|   2.4%
    GetBatches                 |     1 |  0.8ms|  1.2ms|   6.4%
    SortBatches                |     1 |  0.2ms|  0.3ms|   1.6%
    DrawBatches                |     1 |  6.2ms| 10.0ms|  49.6%
```

### What to Look For

| Block | Healthy | Problem |
|-------|---------|---------|
| ScriptUpdate | < 4ms | > 6ms → optimize Lua Update loops |
| PhysicsUpdate | < 2ms | > 4ms → reduce collision shapes, simplify |
| DrawBatches | < 8ms | > 10ms → reduce batches, enable instancing |
| GetBatches | < 1ms | > 2ms → too many visible objects, use culling |
| ProcessLights | < 0.5ms | > 1ms → too many lights |

---

## Memory Analysis

```lua
if input:GetKeyPress(KEY_F11) then
    engine:DumpMemory()
end
```

### Leak Detection Pattern

```lua
-- Track allocation count at key points
local function logMemory(label)
    engine:DumpMemory()
    print("[MEM]", label, "- check log for details")
end

-- Usage
logMemory("Before level load")
loadLevel()
logMemory("After level load")
-- Play for 5 minutes...
logMemory("After gameplay")
unloadLevel()
logMemory("After level unload")
-- Compare: if "After level unload" > "Before level load" → leak
```

### Common Leak Sources

| Source | Symptom | Fix |
|--------|---------|-----|
| Nodes not removed | Memory grows per level restart | `scene_:Clear()` or track & remove |
| Event subscriptions | Callbacks retain references | Unsubscribe in cleanup |
| Lua table growth | Tables grow without clearing | Set `table[key] = nil` explicitly |
| Cached resources | Textures/models accumulate | `cache:ReleaseResource()` for unused |
| Material clones | Each clone = new GPU resource | Share materials (see rendering ref) |

---

## Resource Audit

```lua
if input:GetKeyPress(KEY_F10) then
    engine:DumpResources(true)  -- true = include filenames
end
```

### Interpreting Resource Dump

```
Type          | Count | Memory
--------------+-------+--------
Texture2D     |    45 | 128.5 MB  ← check for oversized textures
Model         |    23 |  12.3 MB
Material      |    67 |   0.8 MB  ← too many? check clones
Shader        |    12 |   0.2 MB
Sound         |     8 |   4.2 MB
```

### Optimization Actions

| Issue | Action |
|-------|--------|
| Texture memory > 128MB | Reduce texture sizes, use compressed formats |
| Material count > 50 | Share materials, reduce clones |
| Unused resources loaded | Use `cache:ReleaseResource()` |
| Large sounds (>1MB each) | Compress to OGG, reduce sample rate |

---

## Custom Timers

Profile specific sections of your game logic.

```lua
-- Simple timer utility
local function timeBlock(name, fn)
    local t0 = time:GetElapsedTime()
    fn()
    local elapsed = time:GetElapsedTime() - t0
    if elapsed > 0.001 then  -- only log if > 1ms
        print(string.format("[TIMER] %s: %.2fms", name, elapsed * 1000))
    end
end

-- Usage
function HandleUpdate(eventType, eventData)
    timeBlock("EnemyAI", function()
        updateAllEnemyAI()
    end)
    timeBlock("Particles", function()
        updateParticles()
    end)
end
```

---

## Performance Dashboard Pattern

Combine all metrics into a single debug overlay.

```lua
-- Collect metrics once per second for display
local perfData = {}
local perfTimer = 0

function updatePerfDashboard(dt)
    perfTimer = perfTimer + dt
    if perfTimer < 1.0 then return end
    perfTimer = 0

    perfData = {
        fps        = math.floor(1.0 / dt),
        batches    = renderer:GetNumBatches(),
        primitives = renderer:GetNumPrimitives(),
        lights     = renderer:GetNumLights(),
        shadows    = renderer:GetNumShadowMaps(),
        geometries = renderer:GetNumGeometries(),
        occluders  = renderer:GetNumOccluders(),
    }
end

-- Display with NanoVG (if using raw NanoVG)
function drawPerfOverlay(vg, x, y)
    nvgFontSize(vg, 14)
    nvgFontFace(vg, "mono")
    nvgFillColor(vg, nvgRGBA(0, 255, 0, 200))
    local lines = {
        string.format("FPS: %d", perfData.fps or 0),
        string.format("Batches: %d", perfData.batches or 0),
        string.format("Tris: %dk", (perfData.primitives or 0) / 1000),
        string.format("Lights: %d", perfData.lights or 0),
        string.format("Shadows: %d", perfData.shadows or 0),
    }
    for i, line in ipairs(lines) do
        nvgText(vg, x, y + (i - 1) * 16, line)
    end
end

-- Or display with UI system
-- local UI = require("urhox-libs/UI")
-- Use UI.Label to show perfData values
```

---

## Diagnosis Flowcharts

### FPS Drop Diagnosis

```
FPS < 60?
│
├─ Check renderer:GetNumBatches()
│  ├─ > 300 → Enable instancing, share materials
│  └─ < 300 → Not draw-call bound
│
├─ Check renderer:GetNumPrimitives()
│  ├─ > 500K → Add DrawDistance, enable LOD
│  └─ < 500K → Not geometry bound
│
├─ Check DumpProfiler() → ScriptUpdate
│  ├─ > 4ms → Optimize Update loop, stagger updates
│  └─ < 4ms → Not script bound
│
├─ Check DumpProfiler() → PhysicsUpdate
│  ├─ > 3ms → Reduce collision shapes, simplify
│  └─ < 3ms → Not physics bound
│
└─ Check DumpProfiler() → DrawBatches
   ├─ > 8ms → GPU bound: reduce shadows, lower quality
   └─ < 8ms → Investigate other subsystems
```

### Memory Growth Diagnosis

```
Memory growing?
│
├─ DumpResources(true)
│  ├─ Texture count growing → cache:ReleaseResource() unused
│  ├─ Material count growing → Stop cloning, share materials
│  └─ Model count growing → Check dynamic model loading
│
├─ DumpMemory()
│  ├─ Node count growing → Objects not being removed / pooled
│  └─ Component count growing → Unused components not cleaned up
│
└─ Check Lua side
   ├─ Table size growing → Clear references: t[k] = nil
   └─ Event subscriptions → Unsubscribe on cleanup
```
