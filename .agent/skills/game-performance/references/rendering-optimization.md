# Rendering Optimization Reference

Complete rendering pipeline tuning guide for UrhoX Lua games: draw call reduction, shadow configuration, instancing, culling, and LOD strategies.

## Table of Contents

1. [Frame Budget](#frame-budget)
2. [Draw Call Reduction](#draw-call-reduction)
3. [Dynamic Instancing](#dynamic-instancing)
4. [LOD Strategies](#lod-strategies)
5. [Shadow Optimization](#shadow-optimization)
6. [Occlusion Culling](#occlusion-culling)
7. [Texture and Material Optimization](#texture-and-material-optimization)
8. [Light Optimization](#light-optimization)
9. [Platform-Specific Budgets](#platform-specific-budgets)

---

## Frame Budget

At 60 FPS, each frame has **16.67ms** total. Typical budget split:

| Phase | Budget | UrhoX Measurement |
|-------|--------|--------------------|
| Game logic / Lua scripts | 4–6ms | `engine:DumpProfiler()` → Script block |
| Physics (3D or Box2D) | 1–3ms | Profiler → Physics block |
| Rendering (GPU) | 6–8ms | `renderer:GetNumBatches()`, primitives |
| Event dispatch | 0.5–1ms | Profiler → Events block |
| Headroom / OS | 2–3ms | Buffer for GC, OS scheduling |

**Warning signs**:
- Batches > 300 (desktop) or > 100 (mobile) → draw call bound
- Primitives > 1M (desktop) or > 100K (mobile) → geometry bound
- Lights > 8 → per-pixel lighting expensive

---

## Draw Call Reduction

### Why Draw Calls Matter

Each unique (Model + Material + Transform) combination = 1 draw call.
GPU state switches between draw calls are the primary cost.

### Reduction Strategies

| Strategy | Savings | Complexity |
|----------|---------|------------|
| Share materials | High | Low |
| Dynamic instancing | High | Low (1 line) |
| Merge static geometry | Medium | Medium |
| Reduce unique materials | High | Design-time |
| Atlas textures | Medium | Asset pipeline |

### Material Sharing Pattern

```lua
-- ❌ Bad: each object gets a unique material clone
for i = 1, 100 do
    local node = scene_:CreateChild("Tree")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Tree.mdl"))
    local mat = cache:GetResource("Material", "Materials/Tree.xml"):Clone()
    model:SetMaterial(mat)  -- 100 unique materials = 100 draw calls
end

-- ✅ Good: all objects share one material instance
local treeMat = cache:GetResource("Material", "Materials/Tree.xml")
for i = 1, 100 do
    local node = scene_:CreateChild("Tree")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Tree.mdl"))
    model:SetMaterial(treeMat)  -- shared = batched into fewer draw calls
end
```

### When to Clone Materials

Only clone when the object needs visually different properties:
- Different color (tint per team)
- Different texture (damage states)
- Different emission (selected highlight)

```lua
-- Clone only for objects that need unique appearance
local selectedMat = baseMat:Clone()
selectedMat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 0, 1)))
selectedNode:GetComponent("StaticModel"):SetMaterial(selectedMat)
```

---

## Dynamic Instancing

UrhoX can automatically batch objects with the same Model + Material into instanced draw calls.

```lua
-- Enable in Start()
renderer:SetDynamicInstancing(true)
renderer:SetMinInstances(2)           -- batch when ≥ 2 instances
renderer:SetMaxSortedInstances(1000)  -- cap for sorted (transparent) objects
```

### Instancing Requirements

| Condition | Instanced? |
|-----------|-----------|
| Same Model + same Material | ✅ Yes |
| Same Model + cloned Material (same params) | ❌ No |
| Same Model + different Material | ❌ No |
| Different Model + same Material | ❌ No |
| Animated model (skinned) | ❌ No |

### Measuring Instancing Effect

```lua
-- Before instancing
print("Batches:", renderer:GetNumBatches())  -- e.g., 150

-- After enabling instancing
renderer:SetDynamicInstancing(true)
-- Next frame:
print("Batches:", renderer:GetNumBatches())  -- e.g., 45
```

---

## LOD Strategies

### DrawDistance (Hard Cutoff)

Objects beyond DrawDistance are completely invisible:

```lua
-- Grass: only render within 30m
grassModel:SetDrawDistance(30.0)

-- Buildings: visible up to 200m
buildingModel:SetDrawDistance(200.0)

-- Shadows: expensive, limit range
treeModel:SetShadowDistance(40.0)  -- no shadows beyond 40m
```

### LodBias (Soft Transition)

Adjusts the distance at which LOD levels switch. Lower = lower quality sooner:

```lua
-- Per-object
detailModel:SetLodBias(0.5)   -- switch to lower LOD earlier (saves GPU)
heroModel:SetLodBias(2.0)     -- keep high detail longer (important object)

-- Per-camera (global multiplier)
camera:SetLodBias(0.8)        -- globally prefer lower LODs
```

### Distance-Based Update Frequency

For non-rendering logic (AI, animation):

```lua
function updateWithLOD(node, cameraPos, dt)
    local dist = (node.position - cameraPos):Length()
    if dist < 20 then
        -- Full update: AI + animation + particles
        updateFull(node, dt)
    elseif dist < 50 then
        -- Medium: AI only, skip particles
        updateAI(node, dt)
    else
        -- Minimal: idle animation only
    end
end
```

---

## Shadow Optimization

Shadows are one of the most expensive rendering features.

```lua
-- Global shadow config
renderer:SetDrawShadows(true)
renderer:SetShadowMapSize(1024)     -- 512 (mobile) / 1024-2048 (desktop)
renderer:SetShadowQuality(SHADOWQUALITY_SIMPLE)  -- SIMPLE / PCF16 / VSM / BLUR_VSM
renderer:SetMaxShadowMaps(2)        -- limit concurrent shadow maps

-- Per-light shadow control
mainLight:SetCastShadows(true)
mainLight:SetShadowBias(BiasParameters(0.00025, 0.5))
mainLight:SetShadowCascade(CascadeParameters(10.0, 30.0, 80.0, 0.0, 0.8))

-- Optimization: only hero and nearby objects cast shadows
for _, obj in ipairs(distantObjects) do
    obj:GetComponent("StaticModel"):SetCastShadows(false)
end
```

### Shadow Budget Guide

| Platform | Map Size | Max Maps | Quality |
|----------|----------|----------|---------|
| Mobile (low) | 512 | 1 | SIMPLE |
| Mobile (high) | 1024 | 2 | SIMPLE |
| Desktop | 1024–2048 | 4 | PCF16 |
| Desktop (high) | 2048–4096 | 4 | VSM |

---

## Occlusion Culling

Prevents rendering objects hidden behind walls/buildings.

```lua
-- Enable and configure
renderer:SetMaxOccluderTriangles(5000)
renderer:SetOcclusionBufferSize(256)     -- 128 (fast) / 256 (balanced) / 512 (precise)
renderer:SetOccluderSizeThreshold(0.025) -- skip tiny occluders
renderer:SetThreadedOcclusion(true)      -- use worker thread

-- Mark objects
-- Large, opaque objects → occluders (they hide things behind them)
wallModel:SetOccluder(true)
buildingModel:SetOccluder(true)

-- Small objects → occludees (they get hidden)
decorModel:SetOccludee(true)
propModel:SetOccludee(true)
```

### Occlusion Best Practices

| Do | Don't |
|----|-------|
| Mark large walls/buildings as occluders | Mark small props as occluders |
| Use in scenes with many objects | Use in open scenes with few obstacles |
| Use OcclusionBufferSize ≤ 256 on mobile | Use 512+ on mobile (CPU cost) |
| Enable ThreadedOcclusion | Skip this — it's free performance |

---

## Texture and Material Optimization

```lua
-- Prefer compressed textures (DXT/ETC on mobile)
-- Smaller textures for distant objects
-- Use texture atlases to batch draw calls

-- Reduce shader complexity
-- PBRNoTexture.xml     → simple solid colors
-- NoTextureUnlit.xml   → flat shading, cheapest
-- DiffUnlit.xml        → texture without lighting, cheap

-- Reduce per-material shader parameters
-- Fewer unique materials = more batching
```

---

## Light Optimization

```lua
-- Use minimal lights
-- 1 directional (sun) + 2–4 point lights = typical budget

-- Point/spot light optimization
light:SetRange(15.0)            -- limit light reach
light:SetFadeDistance(20.0)     -- fade out beyond 20m from camera

-- Disable per-pixel lighting for distant lights
light:SetPerVertex(true)        -- cheaper, for fill lights

-- Baked lighting (if supported)
-- Use Zone ambient instead of many point lights
local zone = scene_:CreateComponent("Zone")
zone:SetAmbientColor(Color(0.3, 0.3, 0.3))
zone:SetBoundingBox(BoundingBox(-500, 500))
```

---

## Platform-Specific Budgets

| Metric | Mobile (Low) | Mobile (High) | Desktop | Desktop (High) |
|--------|-------------|---------------|---------|----------------|
| FPS target | 30 | 60 | 60 | 60+ |
| Draw calls | < 50 | < 100 | < 300 | < 500 |
| Triangles | < 50K | < 100K | < 500K | < 1M+ |
| Lights | 2–3 | 4–6 | 6–8 | 10+ |
| Shadow maps | 0–1 | 1–2 | 2–4 | 4+ |
| Shadow size | 512 | 1024 | 1024–2048 | 2048–4096 |
| Texture mem | < 64MB | < 128MB | < 256MB | < 512MB |
| Instancing | Essential | Essential | Recommended | Recommended |
