# Common Lua & UrhoX Bug Patterns

Quick-reference for the most frequent bugs in UrhoX Lua game development.
Each pattern includes: symptoms, root cause, and fix.

---

## Pattern 1: Off-by-One (1-Based Indexing)

**Symptoms**: `attempt to index a nil value`, array seems to "skip" first/last element

**Root cause**: Lua arrays start at index 1, not 0.

```lua
-- ❌ BUG: Index 0 does not exist in Lua
local items = {"sword", "shield", "potion"}
for i = 0, #items - 1 do
    print(items[i])  -- items[0] is nil\!
end

-- ✅ FIX: Start from 1
for i = 1, #items do
    print(items[i])
end

-- ✅ FIX (alternative): Use ipairs
for i, item in ipairs(items) do
    print(item)
end
```

**Variations**:
- Random index: `math.random(0, #items - 1)` → use `math.random(1, #items)`
- Modular index: `index % count` gives 0 → use `(index - 1) % count + 1`
- Boundary check: `if index >= 0` → use `if index >= 1`

---

## Pattern 2: Nil Reference After Node Removal

**Symptoms**: `Null pointer access`, crash when accessing a removed node

**Root cause**: Lua keeps a reference to a node/component after it is removed from the scene.

```lua
-- ❌ BUG: Node removed but reference still used
local enemyNode = scene_:CreateChild("Enemy")
-- ... later ...
enemyNode:Remove()
-- ... even later ...
local pos = enemyNode.position  -- CRASH: node is destroyed

-- ✅ FIX: Nil the reference after removal
enemyNode:Remove()
enemyNode = nil

-- ✅ FIX: Check before use
if enemyNode ~= nil and enemyNode:GetID() ~= 0 then
    local pos = enemyNode.position
end
```

**Common scenarios**:
- Enemy killed but AI system still references it
- Projectile hits target, both removed, collision callback still runs
- Parent node removed, child references become dangling

---

## Pattern 3: Mutation During Iteration

**Symptoms**: Elements skipped, index out of range, sporadic crashes

**Root cause**: Removing items from a table while iterating forward shifts indices.

```lua
-- ❌ BUG: Removing during forward iteration
for i = 1, #enemies do
    if enemies[i].health <= 0 then
        table.remove(enemies, i)  -- Shifts all subsequent indices\!
        -- Now enemies[i] is actually the NEXT enemy, which gets skipped
    end
end

-- ✅ FIX: Iterate in reverse
for i = #enemies, 1, -1 do
    if enemies[i].health <= 0 then
        enemies[i].node:Remove()
        table.remove(enemies, i)  -- Safe: only affects already-processed indices
    end
end

-- ✅ FIX (alternative): Collect and batch remove
local toRemove = {}
for i, enemy in ipairs(enemies) do
    if enemy.health <= 0 then
        toRemove[#toRemove + 1] = i
    end
end
for j = #toRemove, 1, -1 do
    enemies[toRemove[j]].node:Remove()
    table.remove(enemies, toRemove[j])
end
```

---

## Pattern 4: Event Data Access Type Mismatch

**Symptoms**: `attempt to call method 'GetInt'`, wrong values from events

**Root cause**: Using wrong getter for eventData field type.

```lua
-- ❌ BUG: Wrong getter type
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetInt()  -- TimeStep is float, not int\!
end

-- ✅ FIX: Use correct getter
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
end

-- ✅ FIX (alternative, more efficient):
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
end
```

**Common event field types**:

| Field | Type | Getter |
|-------|------|--------|
| TimeStep | Float | `GetFloat()` |
| X, Y, DX, DY | Int | `GetInt()` |
| Button | Int | `GetInt()` |
| Key | Int | `GetInt()` |
| Pressed | Bool | `GetBool()` |
| Element | Ptr | `GetPtr("UIElement")` |

Reference: `.emmylua/Events.d.lua` for complete event field definitions.

---

## Pattern 5: Resource Path Errors

**Symptoms**: `Resource not found`, blank/missing textures, no sound

**Root cause**: Including directory prefixes that are already in the resource search path.

```lua
-- ❌ BUG: Adding 'assets/' prefix
local tex = cache:GetResource("Texture2D", "assets/Textures/player.png")

-- ✅ FIX: Direct path (assets/ is a resource root)
local tex = cache:GetResource("Texture2D", "Textures/player.png")

-- ❌ BUG: Adding 'scripts/' prefix for require
require "scripts.Utils.Helper"

-- ✅ FIX: Direct module path
require "Utils.Helper"
```

**Resource path rules**:
- `assets/` and `scripts/` are resource roots — never include them in paths
- Use forward slashes `/`, not backslashes
- Case-sensitive on most platforms
- Check file actually exists in the correct subdirectory

---

## Pattern 6: Scope and Closure Bugs

**Symptoms**: All instances share the same value, variable "doesn't update"

**Root cause**: Lua closures capture variables by reference; loop variable reuse.

```lua
-- ❌ BUG: All buttons call the same action (last iteration's value)
for i = 1, 5 do
    local btn = CreateButton("Button " .. i)
    btn.onClick = function()
        print("Clicked button " .. i)  -- 'i' is captured by reference
    end
end
-- All buttons print "Clicked button 5"

-- ✅ FIX: Create a local copy inside the loop
for i = 1, 5 do
    local index = i  -- Local copy for this iteration
    local btn = CreateButton("Button " .. index)
    btn.onClick = function()
        print("Clicked button " .. index)
    end
end
```

---

## Pattern 7: Missing Component Dependencies

**Symptoms**: Physics not working, model invisible, collision not detected

**Root cause**: Components have implicit dependencies that must be satisfied.

```lua
-- ❌ BUG: CollisionShape2D without RigidBody2D
local node = scene_:CreateChild("Platform")
local shape = node:CreateComponent("CollisionShape2D")  -- No rigid body\!

-- ✅ FIX: Add RigidBody2D first
local node = scene_:CreateChild("Platform")
local body = node:CreateComponent("RigidBody2D")
body.bodyType = BT_STATIC
local shape = node:CreateComponent("CollisionShape2D")

-- ❌ BUG: CollisionShape2D on child node (must be same node as RigidBody2D)
local bodyNode = scene_:CreateChild("Enemy")
local body = bodyNode:CreateComponent("RigidBody2D")
local childNode = bodyNode:CreateChild("Collider")
local shape = childNode:CreateComponent("CollisionShape2D")  -- Wrong node\!

-- ✅ FIX: Same node as RigidBody2D, use center offset
local bodyNode = scene_:CreateChild("Enemy")
local body = bodyNode:CreateComponent("RigidBody2D")
local shape = bodyNode:CreateComponent("CollisionShape2D")
shape.center = Vector2(0, 0.5)  -- Offset instead of child node
```

**Common dependency chains**:
- `StaticModel` → needs `Octree` on scene
- `CollisionShape2D` → needs `RigidBody2D` on same node
- `CollisionShape` (3D) → needs `RigidBody` on same node
- `AnimatedModel` → needs `AnimationController` for playback
- NanoVG rendering → needs `NanoVGRender` event subscription

---

## Pattern 8: Stale State After Scene Changes

**Symptoms**: Old data persists, ghost objects, wrong counts

**Root cause**: Game state variables not reset when scene changes or restarts.

```lua
-- ❌ BUG: Module-level state not reset on restart
local score = 0
local enemies = {}
local gameOver = false

function RestartGame()
    scene_:Clear()
    CreateGameContent()  -- Recreates scene but score/enemies/gameOver are stale\!
end

-- ✅ FIX: Explicitly reset all state
function RestartGame()
    scene_:Clear()
    score = 0
    enemies = {}
    gameOver = false
    CreateGameContent()
end
```

---

## Pattern 9: NanoVG Rendering Issues

**Symptoms**: Nothing drawn, text invisible, shapes in wrong position

```lua
-- ❌ BUG: Drawing in Update instead of NanoVGRender
function HandleUpdate(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)
    nvgText(vg, 100, 100, "Hello")  -- Won't display\!
    nvgEndFrame(vg)
end

-- ✅ FIX: Use NanoVGRender event
SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)
    nvgFontFace(vg, "sans")  -- Must set font before text
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, 100, 100, "Hello")
    nvgEndFrame(vg)
end

-- ❌ BUG: Font not created (text invisible)
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)
    nvgText(vg, 100, 100, "Hello")  -- No font set\!
    nvgEndFrame(vg)
end

-- ✅ FIX: Create font once in Start()
function Start()
    vg = nvgCreate(0)
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end
```

---

## Pattern 10: Math and Coordinate Errors

**Symptoms**: Objects in wrong position, movement in wrong direction, rotation inverted

```lua
-- ❌ BUG: Assuming Z-up (common in Blender/OpenGL convention)
node.position = Vector3(x, z, y)  -- Wrong axis mapping\!

-- ✅ FIX: UrhoX uses Y-up left-handed (same as Unity)
node.position = Vector3(x, y, z)  -- Y is up

-- ❌ BUG: Forgetting unit is meters
node.position = Vector3(0, 100, 0)  -- 100 meters up\! Probably not intended

-- ✅ FIX: Think in meters
node.position = Vector3(0, 1.5, 0)  -- 1.5 meters (character height)

-- ❌ BUG: Wrong rotation axis
local rotation = Quaternion(angle, Vector3.UP)  -- Rotates horizontally
-- Intended: look up/down

-- ✅ FIX: Pitch is around X axis (RIGHT)
local rotation = Quaternion(angle, Vector3.RIGHT)  -- Look up/down
```

---

## Diagnostic Logging Template

Add this to any game for structured debugging:

```lua
-- Debug levels
local DEBUG_NONE = 0
local DEBUG_ERROR = 1
local DEBUG_WARN = 2
local DEBUG_INFO = 3
local DEBUG_VERBOSE = 4

local debugLevel = DEBUG_INFO  -- Set during development

function DebugLog(level, category, message)
    if level <= debugLevel then
        local prefix = ({"[ERROR]", "[WARN]", "[INFO]", "[VERBOSE]"})[level]
        log:Write(LOG_DEBUG, prefix .. " [" .. category .. "] " .. message)
    end
end

-- Usage:
DebugLog(DEBUG_INFO, "Combat", "Enemy " .. id .. " took " .. damage .. " damage")
DebugLog(DEBUG_ERROR, "Spawn", "Failed to spawn: enemies table is nil")
DebugLog(DEBUG_VERBOSE, "Physics", "Body count: " .. bodyCount)
```
