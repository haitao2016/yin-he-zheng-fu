# 3D Game Patterns for UrhoX

> Reference for `game-design-patterns` skill.
> Covers camera systems, lighting, shadows, collider selection, LOD,
> culling strategies, and rendering tips — all in UrhoX Lua.

---

## 1  Camera Systems

### Camera Type Selection

| Type | Best For | UrhoX Setup |
|------|----------|-------------|
| **First-Person** | FPS, horror, exploration | `MM_RELATIVE` + yaw/pitch on camera node |
| **Third-Person** | Action, adventure, RPG | `ThirdPersonCamera` library (REQUIRED) |
| **Isometric** | Strategy, ARPG | Orthographic camera, 45 degree rotation |
| **Orbital** | Viewers, editors | Rotate around target point |
| **Top-Down** | RTS, twin-stick | Fixed pitch, follow player XZ |
| **Side-Scroll** | 2.5D platformer | Fixed X axis, track player YZ |

### First-Person Camera

```lua
require "LuaScripts/Utilities/Sample"

local yaw   = 0
local pitch = 0

function Start()
    -- Lock and hide cursor for FPS control
    input.mouseMode = MM_RELATIVE

    scene_ = Scene()
    -- ... scene setup ...

    cameraNode = scene_:CreateChild("Camera")
    cameraNode.position = Vector3(0, 1.7, 0)  -- eye height
    local camera = cameraNode:CreateComponent("Camera")
    camera.fov = 60

    renderer:SetViewport(0, Viewport:new(scene_, camera))
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    local mouseMove = input.mouseMove

    yaw   = yaw   + mouseMove.x * 0.1
    pitch = pitch + mouseMove.y * 0.1
    pitch = math.max(-89, math.min(89, pitch))

    cameraNode.rotation = Quaternion(pitch, yaw, 0)

    -- Movement
    local speed = 5.0 * dt
    if input:GetKeyDown(KEY_W) then
        cameraNode:Translate(Vector3.FORWARD * speed)
    end
    if input:GetKeyDown(KEY_S) then
        cameraNode:Translate(Vector3.BACK * speed)
    end
    if input:GetKeyDown(KEY_A) then
        cameraNode:Translate(Vector3.LEFT * speed)
    end
    if input:GetKeyDown(KEY_D) then
        cameraNode:Translate(Vector3.RIGHT * speed)
    end
end
```

### Third-Person Camera (Use Library)

```lua
-- ALWAYS use ThirdPersonCamera library for third-person
require "urhox-libs.Camera.ThirdPersonCamera"

local tpCamera = ThirdPersonCamera.Create(scene_, {
    modes = {
        normal = {
            distance = 5.0,
            offset   = Vector3(0, 1.7, 0),  -- shoulder height
            fov      = 45.0,
        },
        aim = {
            distance = 2.5,
            offset   = Vector3(0.5, 1.5, 0),  -- over-the-shoulder
            fov      = 35.0,
        },
    },
})

-- In PostUpdate:
function HandlePostUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    tpCamera:Update(dt, characterNode, yaw, pitch)
end
```

### Isometric Camera

```lua
local cameraNode = scene_:CreateChild("Camera")
cameraNode.position = Vector3(0, 20, -20)
cameraNode.rotation = Quaternion(45, 0, 0)  -- look down at 45 degrees

local camera = cameraNode:CreateComponent("Camera")
camera.orthographic = true
camera.orthoSize = 15.0  -- visible world height in meters
camera.nearClip = 0.1
camera.farClip = 100.0
```

---

## 2  Lighting Setup

### Lighting Types

| Type | UrhoX Component | Use Case | Cost |
|------|----------------|----------|------|
| **Directional** | `Light` (LIGHT_DIRECTIONAL) | Sun, moon | Low |
| **Point** | `Light` (LIGHT_POINT) | Torches, lamps | Medium |
| **Spot** | `Light` (LIGHT_SPOT) | Flashlights, stage | Medium |
| **Ambient** | Zone component | Base illumination | Free |

### Standard Outdoor Lighting

```lua
-- Ambient (Zone)
local zoneNode = scene_:CreateChild("Zone")
local zone = zoneNode:CreateComponent("Zone")
zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000),
                                Vector3(1000, 1000, 1000))
zone.ambientColor = Color(0.3, 0.3, 0.4)  -- slightly blue ambient
zone.fogColor = Color(0.7, 0.8, 0.9)
zone.fogStart = 100.0
zone.fogEnd = 300.0

-- Directional Light (Sun)
local lightNode = scene_:CreateChild("DirectionalLight")
lightNode.direction = Vector3(0.6, -1.0, 0.8):Normalized()
local light = lightNode:CreateComponent("Light")
light.lightType = LIGHT_DIRECTIONAL
light.color = Color(1.0, 0.95, 0.8)  -- warm sunlight
light.brightness = 1.0
light.castShadows = true
light.shadowBias = BiasParameters(0.00025, 0.5)
light.shadowCascade = CascadeParameters(10, 30, 80, 200, 0.8)
```

### Standard Indoor Lighting

```lua
-- Dimmer ambient
zone.ambientColor = Color(0.1, 0.1, 0.15)

-- Point lights for lamps/fixtures
local function createPointLight(pos, color, range)
    local node = scene_:CreateChild("PointLight")
    node.position = pos
    local light = node:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = color
    light.range = range
    light.brightness = 1.5
    light.castShadows = false  -- expensive for point lights
    return node
end

createPointLight(Vector3(0, 3, 0), Color(1.0, 0.9, 0.7), 8.0)
createPointLight(Vector3(5, 3, 3), Color(0.8, 0.8, 1.0), 6.0)
```

### Lighting Performance Tips

| Tip | Impact |
|-----|--------|
| Limit shadow-casting lights to 1-2 | Major FPS gain |
| Use per-vertex lighting for distant objects | Medium FPS gain |
| Bake static lighting when possible | Major FPS gain |
| Use light radius to limit affected area | Medium FPS gain |
| Disable shadows on point/spot lights | Major FPS gain |

---

## 3  Shadow Configuration

### Shadow Cascade (Directional Light)

```lua
-- CascadeParameters(split1, split2, split3, split4, fadeStart)
-- Splits define distance thresholds for shadow quality levels
light.shadowCascade = CascadeParameters(
    10,    -- high quality: 0-10 meters
    30,    -- medium quality: 10-30 meters
    80,    -- low quality: 30-80 meters
    200,   -- minimal quality: 80-200 meters
    0.8    -- fade starts at 80% of last cascade
)

-- Shadow bias to prevent acne
light.shadowBias = BiasParameters(0.00025, 0.5)
```

### Shadow Quality vs Performance

| Setting | Quality | Performance |
|---------|---------|-------------|
| No shadows | None | Best |
| 1 cascade, 512px | Low | Good |
| 2 cascades, 1024px | Medium | Moderate |
| 4 cascades, 2048px | High | Heavy |

---

## 4  Collider Selection

### Shape Selection Guide

| Collider | Use For | Cost |
|----------|---------|------|
| **Box** | Crates, buildings, walls | Cheapest |
| **Sphere** | Balls, quick proximity checks | Cheapest |
| **Capsule** | Characters, NPCs | Cheap |
| **Cylinder** | Pillars, barrels | Cheap |
| **ConvexHull** | Irregular convex shapes | Medium |
| **TriangleMesh** | Static terrain, complex static | Expensive |

### Best Practices

```lua
-- Rule: Simple colliders, complex visuals

-- Character: Capsule
local body = characterNode:CreateComponent("RigidBody")
body.mass = 70.0
body.angularFactor = Vector3(0, 0, 0)  -- prevent tumbling
local shape = characterNode:CreateComponent("CollisionShape")
shape:SetCapsule(0.6, 1.8, Vector3(0, 0.9, 0))  -- diameter, height, offset

-- Building: Box (even if model is detailed)
local shape = buildingNode:CreateComponent("CollisionShape")
shape:SetBox(Vector3(10, 5, 8))  -- approximate bounding box

-- Terrain: HeightfieldShape (if using Terrain component)
local shape = terrainNode:CreateComponent("CollisionShape")
shape:SetTerrain()

-- Complex static: TriangleMesh (ONLY for static objects)
local shape = staticNode:CreateComponent("CollisionShape")
shape:SetTriangleMesh(model)
```

### Collision Layer Strategy

```lua
-- Define layers (bit flags)
local LAYER = {
    GROUND  = 1,   -- 0x0001
    PLAYER  = 2,   -- 0x0002
    ENEMY   = 4,   -- 0x0004
    BULLET  = 8,   -- 0x0008
    TRIGGER = 16,  -- 0x0010
    PICKUP  = 32,  -- 0x0020
}

-- Player: collides with ground, enemy, pickup
body.collisionLayer = LAYER.PLAYER
body.collisionMask  = LAYER.GROUND + LAYER.ENEMY + LAYER.PICKUP

-- Enemy bullet: collides with player only
bulletBody.collisionLayer = LAYER.BULLET
bulletBody.collisionMask  = LAYER.PLAYER
```

---

## 5  LOD (Level of Detail)

### Distance-Based LOD Strategy

| Distance | Detail Level | Approach |
|----------|-------------|----------|
| 0-10m | Full | Original model |
| 10-30m | Medium | 50% triangle count |
| 30-100m | Low | 25% or billboard |
| 100m+ | Minimal | Billboard or hidden |

### UrhoX LOD Setup

```lua
local model = node:CreateComponent("StaticModel")
model:SetModel(cache:GetResource("Model", "Models/Tree.mdl"))

-- Set draw distance (beyond this, object is invisible)
model.drawDistance = 150.0

-- Set shadow distance (beyond this, no shadow)
model.shadowDistance = 50.0

-- LOD bias: higher = use lower detail sooner
model.lodBias = 1.0
```

### LOD for Crowds/Vegetation

```lua
-- For many similar objects: adjust LOD bias based on object count
local function setAdaptiveLOD(objects, camera)
    local count = #objects
    local lodBias = 1.0
    if count > 100 then lodBias = 2.0 end
    if count > 500 then lodBias = 4.0 end

    for _, obj in ipairs(objects) do
        local model = obj:GetComponent("StaticModel")
        if model then
            model.lodBias = lodBias
        end
    end
end
```

---

## 6  Culling Strategies

### Frustum Culling

Automatic in UrhoX — objects outside camera view are not rendered.
No setup needed, but be aware:
- Large objects may pop in/out at edges
- Set appropriate `drawDistance` to help

### Occlusion Culling

```lua
-- UrhoX supports software occlusion culling
local camera = cameraNode:GetComponent("Camera")

-- Large solid objects can be occluders
local model = wallNode:CreateComponent("StaticModel")
model.occluder = true  -- this object can hide things behind it

-- Small objects can be occludees
local smallModel = propNode:CreateComponent("StaticModel")
smallModel.occludee = true  -- this object can be hidden
```

### Draw Distance by Category

| Category | Draw Distance | Shadow Distance |
|----------|--------------|-----------------|
| Terrain | 500m+ | 100m |
| Buildings | 200m | 80m |
| Characters | 100m | 40m |
| Props | 50m | 20m |
| Particles | 30m | None |
| Small details | 15m | None |

---

## 7  Material & Shader Guidelines

### PBR Material Quick Reference

```lua
-- Programmatic (no texture) — use PBRNoTexture
local mat = Material:new()
mat:SetTechnique(0,
    cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
mat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.2, 0.1, 1.0)))
mat:SetShaderParameter("Roughness", Variant(0.5))
mat:SetShaderParameter("Metallic", Variant(0.0))

-- Transparent material — use PBRNoTextureAlpha
local glassMat = Material:new()
glassMat:SetTechnique(0,
    cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
glassMat:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.8, 1.0, 0.3)))
```

> For the complete materials guide with 35+ presets, use the `materials` skill.

### When to Use Custom Shaders

| Need | Solution |
|------|----------|
| Different color/roughness | Just change material parameters |
| Toon/cel shading | Custom technique |
| Water surface | Custom shader with time uniform |
| Dissolve/burn effect | Custom shader with noise texture |
| Outline/rim lighting | Custom shader |

---

## 8  Scene Organization

### Node Hierarchy Best Practice

```
Scene
├── Environment
│   ├── Terrain
│   ├── Skybox
│   ├── DirectionalLight
│   └── Zone
├── Static (buildings, props)
│   ├── Building_01
│   └── Prop_01
├── Dynamic (moving objects)
│   ├── Player
│   ├── Enemies
│   │   ├── Enemy_01
│   │   └── Enemy_02
│   └── Projectiles
├── Triggers (invisible volumes)
│   ├── SpawnZone_01
│   └── Checkpoint_01
└── Camera
```

### Spatial Partitioning

UrhoX uses an Octree internally for spatial queries:

```lua
-- Raycast example (shooting, line-of-sight)
local ray = camera:GetScreenRay(0.5, 0.5)  -- center of screen
local results = octree:Raycast(ray, RAY_TRIANGLE, 100.0, DRAWABLE_GEOMETRY)
if #results > 0 then
    local hit = results[1]  -- closest hit
    local hitNode = hit.drawable:GetNode()
    local hitPos = hit.position
    local hitNormal = hit.normal
end

-- Sphere query (area detection)
local query = SphereOctreeQuery(Sphere(playerPos, 10.0), DRAWABLE_GEOMETRY)
octree:GetDrawables(query)
for _, drawable in ipairs(query.result) do
    -- Process nearby objects
end
```

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| TriangleMesh on dynamic body | Use ConvexHull or simple shapes for moving objects |
| Too many shadow-casting lights | Limit to 1-2 directional, disable for point/spot |
| No draw distance set | Always set drawDistance for non-essential objects |
| Forgetting LOD | Set lodBias and use simpler models at distance |
| Light bleeding through walls | Use shadow bias tuning, ensure walls are thick enough |
| Camera clips through walls | Use ThirdPersonCamera library (handles collision) |
| Manual 3rd-person camera math | ALWAYS use ThirdPersonCamera library |
