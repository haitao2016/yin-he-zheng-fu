---
name: level-design
description: >-
  Level design methodology and spatial design patterns for UrhoX Lua games,
  covering level structure patterns (linear, hub-and-spoke, metroidvania),
  pacing and intensity curves, environmental storytelling, whitebox prototyping,
  player guidance via lighting and landmarks, difficulty progression, and level
  metrics per genre. Includes Lua code for zone triggers, checkpoints, and
  pacing controllers.
  Use when users need to (1) design level layouts or map structures,
  (2) implement pacing and intensity curves for gameplay flow,
  (3) create environmental storytelling with lighting and atmosphere,
  (4) build whitebox prototypes with UrhoX primitives,
  (5) implement player guidance systems (lighting, landmarks, breadcrumbs),
  (6) design difficulty progression that teaches through play,
  (7) set up checkpoint and zone trigger systems,
  (8) analyze level metrics (completion time, death count, secrets),
  (9) troubleshoot lost players, boring levels, or difficulty spikes,
  or any other level design tasks in game development.
---

# Level Design for UrhoX Lua Games

Complete level design methodology adapted for the UrhoX engine, covering spatial design theory, practical implementation patterns, and ready-to-use Lua code for building well-paced, engaging game levels.

---

## 1. Level Design Pillars

Five foundational principles that every level must address:

```
┌─────────────────────────────────────────────────────────────┐
│                    LEVEL DESIGN PILLARS                     │
├─────────────────────────────────────────────────────────────┤
│  1. FLOW      Guide the player naturally through space     │
│  2. PACING    Control intensity and rest moments           │
│  3. DISCOVERY Reward exploration and curiosity             │
│  4. CLARITY   Player always knows where to go              │
│  5. CHALLENGE Skill tests that teach and satisfy           │
└─────────────────────────────────────────────────────────────┘
```

### Pillar Checklist

| Pillar | Key Question | Red Flag |
|--------|-------------|----------|
| Flow | Can the player move through without stopping? | Dead ends without purpose |
| Pacing | Are intense and calm moments alternating? | Constant high intensity |
| Discovery | Are there rewards off the main path? | Everything is on rails |
| Clarity | Does the player know where to go next? | Frequent confusion |
| Challenge | Does difficulty match the player's skill growth? | Sudden spikes or plateaus |

---

## 2. Level Structure Patterns

### 2.1 Linear

```
[Start] → [Tutorial] → [Challenge A] → [Challenge B] → [Boss] → [End]
```

- **Pros**: Easy to pace, clear narrative direction, lower development cost
- **Cons**: Limited replay value, less exploration freedom
- **Best for**: Story-driven games, action games, tutorial sequences
- **UrhoX tip**: Use trigger zones along a single corridor/path

### 2.2 Hub & Spoke

```
           [Level A]
               ↑
[Level B] ← [HUB] → [Level C]
               ↓
           [Level D]
```

- **Pros**: Player choice, non-linear progression, hub as safe zone
- **Cons**: Can feel disconnected, harder to balance difficulty order
- **Best for**: RPGs, adventure games, open-world games
- **UrhoX tip**: Use scene transitions or loading zones between hub and spokes

### 2.3 Metroidvania

```
┌───┐   ┌───┐   ┌───┐
│ A │───│ B │───│ C │ (locked: need ability X)
└─┬─┘   └───┘   └───┘
  │       │
┌─┴─┐   ┌─┴─┐
│ D │───│ E │ (grants ability X)
└───┘   └───┘
```

- **Pros**: Rewarding exploration, ability-gated progression, high replay value
- **Cons**: Players can get lost, backtracking tedium
- **Best for**: Exploration games, 2D platformers, action-adventure
- **UrhoX tip**: Track unlocked abilities in a Lua table, gate zones with trigger checks

### 2.4 Open World (Zone-Based)

```
┌─────┬─────┬─────┐
│ Z1  │ Z2  │ Z3  │   Each zone: own difficulty tier
├─────┼─────┼─────┤   Soft boundaries (enemy level) or
│ Z4  │ Z5  │ Z6  │   hard boundaries (terrain/doors)
└─────┴─────┴─────┘
```

- **Pros**: Maximum freedom, emergent gameplay
- **Cons**: Hardest to pace, content sprawl risk
- **Best for**: Sandbox games, survival games, MMOs
- **UrhoX tip**: Use chunk-based loading or LOD zones for performance

---

## 3. Pacing & Intensity Curves

### The Build-Peak-Rest Pattern

```
Intensity
  High │      ╱╲           ╱╲    ╱╲
       │     ╱  ╲    ╱╲   ╱  ╲  ╱  ╲    ╱╲
       │    ╱    ╲  ╱  ╲ ╱    ╲╱    ╲  ╱  ╲
  Low  │───╱──────╲╱────╲──────────────╲╱────→ Time

  PATTERN: Build → Peak → Rest → Build → Peak → Rest
```

### Pacing Elements

| Phase | Purpose | Examples |
|-------|---------|---------|
| **Build-up** | Introduce mechanic safely, increase tension | New enemy type preview, environmental foreshadowing |
| **Peak** | Test player skills at highest intensity | Boss fight, timed puzzle, combat arena |
| **Rest** | Recovery, story, resource replenishment | Safe zone, shop, cutscene, save point |

### Pacing Controller (Lua)

```lua
--- Pacing zone manager: tracks player position through intensity phases
---@class PacingZone
---@field name string
---@field intensity number  -- 0.0 (rest) to 1.0 (peak)
---@field duration number   -- expected seconds in zone
---@field type string       -- "buildup" | "peak" | "rest"

local PacingManager = {}
PacingManager.__index = PacingManager

function PacingManager:new()
    local o = setmetatable({}, self)
    o.zones = {}
    o.currentZone = nil
    o.zoneStartTime = 0
    o.totalTime = 0
    return o
end

--- Add a pacing zone to the level sequence
---@param name string
---@param intensity number 0.0-1.0
---@param duration number seconds
---@param zoneType string "buildup"|"peak"|"rest"
function PacingManager:addZone(name, intensity, duration, zoneType)
    self.zones[#self.zones + 1] = {
        name = name,
        intensity = intensity,
        duration = duration,
        type = zoneType,
    }
end

--- Call when player enters a new zone
---@param zoneName string
function PacingManager:enterZone(zoneName)
    for i = 1, #self.zones do
        if self.zones[i].name == zoneName then
            self.currentZone = self.zones[i]
            self.zoneStartTime = self.totalTime
            log:Write(LOG_INFO, "Pacing: entering " .. zoneName
                .. " (intensity=" .. self.zones[i].intensity .. ")")
            return
        end
    end
end

--- Get current intensity (useful for dynamic music/lighting)
---@return number intensity 0.0-1.0
function PacingManager:getIntensity()
    if not self.currentZone then return 0 end
    return self.currentZone.intensity
end

--- Update elapsed time
---@param dt number delta time
function PacingManager:update(dt)
    self.totalTime = self.totalTime + dt
end

-- Usage example:
-- local pacing = PacingManager:new()
-- pacing:addZone("entrance",   0.1, 30, "rest")
-- pacing:addZone("corridor",   0.4, 45, "buildup")
-- pacing:addZone("arena",      0.9, 60, "peak")
-- pacing:addZone("safe_room",  0.1, 20, "rest")
```

---

## 4. Environmental Storytelling

### Storytelling Techniques

| Layer | Method | Example |
|-------|--------|---------|
| **Visual Narratives** | Object placement tells stories | Abandoned campfire, broken weapons, scattered notes |
| **Atmosphere** | Lighting, sound, weather set mood | Warm light = safe; cold blue = danger; rain = melancholy |
| **Discovery Layers** | Depth of lore rewards exploration | Surface (obvious), Hidden (secret rooms), Deep (lore fragments) |

### Lighting as Narrative Tool (UrhoX)

```lua
--- Set up mood lighting for a level zone
---@param scene Scene
---@param mood string "safe"|"danger"|"mystery"|"boss"
local function setupMoodLighting(scene, mood)
    local zoneLight = scene:CreateChild("ZoneLight")
    local light = zoneLight:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.range = 15.0
    light.castShadows = true

    local zone = scene:GetComponent("Zone") or scene:CreateComponent("Zone")

    if mood == "safe" then
        light.color = Color(1.0, 0.9, 0.7, 1.0)       -- warm yellow
        light.brightness = 1.2
        zone.fogColor = Color(0.3, 0.3, 0.25, 1.0)
    elseif mood == "danger" then
        light.color = Color(0.7, 0.2, 0.2, 1.0)        -- red tint
        light.brightness = 0.8
        zone.fogColor = Color(0.15, 0.05, 0.05, 1.0)
    elseif mood == "mystery" then
        light.color = Color(0.3, 0.4, 0.9, 1.0)        -- cool blue
        light.brightness = 0.6
        zone.fogColor = Color(0.1, 0.1, 0.2, 1.0)
    elseif mood == "boss" then
        light.color = Color(1.0, 0.5, 0.0, 1.0)        -- fiery orange
        light.brightness = 1.5
        zone.fogColor = Color(0.2, 0.1, 0.0, 1.0)
    end

    return zoneLight
end
```

### Environmental Detail Placement Checklist

- [ ] Abandoned objects tell a story (who was here? what happened?)
- [ ] Damage/decay on environment shows history and age
- [ ] Color palette shifts between safe and dangerous areas
- [ ] Sound changes reinforce mood transitions (ambient → tense → silence before boss)
- [ ] Hidden areas reward curious players with lore or resources

---

## 5. Whitebox Prototyping Workflow

### The 5-Step Process

```
1. CONCEPT (Paper/Sketch)
   - Sketch rough layout on paper or whiteboard
   - Define key beats (encounters, puzzles, story moments)
   - Identify critical path vs optional paths
              ↓
2. WHITEBOX (Engine - UrhoX Primitives)
   - Block out with Box/Cylinder/Sphere primitives
   - Test scale (1 unit = 1 meter), timing, sightlines
   - Place placeholder triggers and enemies
              ↓
3. PLAYTEST
   - Test flow: can player find the path?
   - Test pacing: are intensity curves correct?
   - Test scale: do spaces feel right for the character?
   - Iterate layout based on feedback
              ↓
4. ART PASS
   - Replace primitives with final models/prefabs
   - Add lighting, materials, environment props
   - Polish visual details and atmosphere
              ↓
5. FINAL POLISH
   - Audio integration (ambient, SFX, music transitions)
   - VFX placement (particles, post-processing)
   - Performance optimization (LOD, culling, draw calls)
```

### Whitebox with UrhoX Primitives

```lua
--- Create a whitebox room using engine primitives
---@param scene Scene
---@param pos Vector3 room center position
---@param size Vector3 room dimensions (width, height, depth)
---@param roomName string
---@return Node roomNode
local function createWhiteboxRoom(scene, pos, size, roomName)
    local room = scene:CreateChild(roomName)
    room.position = pos

    -- Floor
    local floor = room:CreateChild("Floor")
    floor.position = Vector3(0, 0, 0)
    floor.scale = Vector3(size.x, 0.2, size.z)
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Box.mdl")
    floorModel.material = cache:GetResource("Material", "Materials/DefaultGrey.xml")

    -- Walls (4 sides)
    local wallHeight = size.y
    local wallThickness = 0.3
    local wallConfigs = {
        { name = "WallNorth", pos = Vector3(0, wallHeight/2, size.z/2),
          scale = Vector3(size.x, wallHeight, wallThickness) },
        { name = "WallSouth", pos = Vector3(0, wallHeight/2, -size.z/2),
          scale = Vector3(size.x, wallHeight, wallThickness) },
        { name = "WallEast",  pos = Vector3(size.x/2, wallHeight/2, 0),
          scale = Vector3(wallThickness, wallHeight, size.z) },
        { name = "WallWest",  pos = Vector3(-size.x/2, wallHeight/2, 0),
          scale = Vector3(wallThickness, wallHeight, size.z) },
    }

    for _, cfg in ipairs(wallConfigs) do
        local wall = room:CreateChild(cfg.name)
        wall.position = cfg.pos
        wall.scale = cfg.scale
        local wallModel = wall:CreateComponent("StaticModel")
        wallModel.model = cache:GetResource("Model", "Models/Box.mdl")
        wallModel.material = cache:GetResource("Material", "Materials/DefaultGrey.xml")
    end

    return room
end
```

### Scale Reference (UrhoX = meters)

| Element | Size | Notes |
|---------|------|-------|
| Player character | 1.7-1.8m tall | Standard human height |
| Doorway | 2.2m H x 1.2m W | Must fit character + headroom |
| Corridor | 3m wide minimum | Comfortable movement |
| Small room | 5x5m | Intimate, close-quarters |
| Medium room | 10x10m | Standard combat arena |
| Large arena | 20x20m+ | Boss fights, open areas |
| Jump gap | 2-4m | Comfortable single jump |
| Ceiling height | 3-4m standard | Higher = grand, lower = oppressive |

---

## 6. Player Guidance Systems

### Visual Guidance Techniques

| Technique | Implementation | UrhoX Approach |
|-----------|---------------|----------------|
| **Lighting** | Bright path, dark surroundings | Point/spot lights on critical path |
| **Landmarks** | Tall unique structures visible from afar | Distinctive node with emissive material |
| **Breadcrumbs** | Collectibles along the path | Pickup nodes with trigger zones |
| **Color coding** | Unique colors mark important things | Material color differentiation |
| **Architecture** | Lines lead to objectives | Wall/floor geometry funneling |
| **Negative space** | Open area around key items | Clear geometry around objectives |

### Breadcrumb / Pickup System (Lua)

```lua
--- Create a line of collectible breadcrumbs along a path
---@param scene Scene
---@param points Vector3[] waypoints along the path
---@param spacing number meters between pickups
local function createBreadcrumbs(scene, points, spacing)
    local pickupGroup = scene:CreateChild("Breadcrumbs")
    local pickupIndex = 0

    for i = 1, #points - 1 do
        local startPt = points[i]
        local endPt = points[i + 1]
        local dir = endPt - startPt
        local dist = dir:Length()
        if dist > 0 then
            dir = dir / dist  -- normalize
        end

        local d = 0
        while d < dist do
            pickupIndex = pickupIndex + 1
            local pos = startPt + dir * d
            pos.y = pos.y + 0.5  -- float above ground

            local pickup = pickupGroup:CreateChild("Pickup_" .. pickupIndex)
            pickup.position = pos
            pickup.scale = Vector3(0.3, 0.3, 0.3)

            local model = pickup:CreateComponent("StaticModel")
            model.model = cache:GetResource("Model", "Models/Sphere.mdl")

            -- Emissive material for visibility
            local mat = Material:new()
            mat:SetTechnique(0, cache:GetResource(
                "Technique", "Techniques/PBR/PBRNoTexture.xml"))
            mat:SetShaderParameter("MatEmissiveColor",
                Variant(Color(0.8, 0.8, 0.2, 1.0)))
            mat:SetShaderParameter("MatDiffColor",
                Variant(Color(1.0, 1.0, 0.3, 1.0)))
            model.material = mat

            -- Trigger body for collection
            local body = pickup:CreateComponent("RigidBody")
            body.trigger = true
            body.mass = 0
            local shape = pickup:CreateComponent("CollisionShape")
            shape:SetSphere(0.6)

            d = d + spacing
        end
    end

    return pickupGroup
end
```

### Landmark Beacon (Lua)

```lua
--- Create a visible landmark beacon at a destination
---@param scene Scene
---@param position Vector3
---@param beaconColor Color
---@return Node
local function createLandmarkBeacon(scene, position, beaconColor)
    local beacon = scene:CreateChild("Landmark")
    beacon.position = position

    -- Tall pillar
    local pillar = beacon:CreateChild("Pillar")
    pillar.position = Vector3(0, 5, 0)
    pillar.scale = Vector3(0.5, 10, 0.5)
    local pillarModel = pillar:CreateComponent("StaticModel")
    pillarModel.model = cache:GetResource("Model", "Models/Cylinder.mdl")

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource(
        "Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatEmissiveColor", Variant(beaconColor))
    mat:SetShaderParameter("MatDiffColor", Variant(beaconColor))
    pillarModel.material = mat

    -- Point light at top for visibility
    local lightNode = beacon:CreateChild("BeaconLight")
    lightNode.position = Vector3(0, 10, 0)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_POINT
    light.color = beaconColor
    light.range = 30.0
    light.brightness = 2.0

    return beacon
end
```

---

## 7. Zone Trigger System

### Trigger Zone for Level Events (Lua)

```lua
--- Zone trigger: fires callback when player enters a region
---@param scene Scene
---@param position Vector3 zone center
---@param size Vector3 zone half-extents
---@param zoneName string
---@param onEnter function(otherNode: Node)
---@param onExit function(otherNode: Node)|nil
---@return Node
local function createZoneTrigger(scene, position, size, zoneName, onEnter, onExit)
    local zone = scene:CreateChild(zoneName)
    zone.position = position

    local body = zone:CreateComponent("RigidBody")
    body.trigger = true
    body.mass = 0
    body.collisionLayer = 2   -- trigger layer
    body.collisionMask = 1    -- detect player layer

    local shape = zone:CreateComponent("CollisionShape")
    shape:SetBox(size * 2)  -- SetBox takes full size, not half-extents

    SubscribeToEvent(zone, "NodeCollisionStart", function(eventType, eventData)
        local otherNode = eventData["OtherNode"]:GetPtr("Node")
        if otherNode and onEnter then
            onEnter(otherNode)
        end
    end)

    if onExit then
        SubscribeToEvent(zone, "NodeCollisionEnd", function(eventType, eventData)
            local otherNode = eventData["OtherNode"]:GetPtr("Node")
            if otherNode then
                onExit(otherNode)
            end
        end)
    end

    return zone
end

-- Usage:
-- createZoneTrigger(scene_, Vector3(0, 2, 30), Vector3(5, 3, 5), "ArenaEntry",
--     function(playerNode)
--         log:Write(LOG_INFO, "Player entered arena\!")
--         -- Lock doors, spawn enemies, change music
--     end,
--     function(playerNode)
--         log:Write(LOG_INFO, "Player left arena")
--     end
-- )
```

---

## 8. Checkpoint System

```lua
--- Simple checkpoint system: tracks last safe position
local CheckpointSystem = {}
CheckpointSystem.__index = CheckpointSystem

function CheckpointSystem:new()
    local o = setmetatable({}, self)
    o.checkpoints = {}         -- { name, position, rotation }
    o.lastCheckpoint = nil     -- most recent checkpoint reached
    o.onCheckpointReached = nil -- callback(checkpoint)
    return o
end

--- Register a checkpoint in the level
---@param name string
---@param position Vector3
---@param rotation Quaternion|nil
function CheckpointSystem:addCheckpoint(name, position, rotation)
    self.checkpoints[#self.checkpoints + 1] = {
        name = name,
        position = position,
        rotation = rotation or Quaternion.IDENTITY,
        reached = false,
    }
end

--- Mark checkpoint as reached (call from zone trigger)
---@param name string
function CheckpointSystem:reach(name)
    for i = 1, #self.checkpoints do
        if self.checkpoints[i].name == name
            and not self.checkpoints[i].reached then
            self.checkpoints[i].reached = true
            self.lastCheckpoint = self.checkpoints[i]
            log:Write(LOG_INFO, "Checkpoint reached: " .. name)
            if self.onCheckpointReached then
                self.onCheckpointReached(self.checkpoints[i])
            end
            return
        end
    end
end

--- Respawn player at last checkpoint
---@param playerNode Node
function CheckpointSystem:respawn(playerNode)
    if self.lastCheckpoint then
        playerNode.position = self.lastCheckpoint.position
        playerNode.rotation = self.lastCheckpoint.rotation
        local body = playerNode:GetComponent("RigidBody")
        if body then
            body:SetLinearVelocity(Vector3.ZERO)
            body:SetAngularVelocity(Vector3.ZERO)
        end
        log:Write(LOG_INFO, "Respawned at: " .. self.lastCheckpoint.name)
    end
end

-- Usage:
-- local checkpoints = CheckpointSystem:new()
-- checkpoints:addCheckpoint("start",  Vector3(0, 1, 0))
-- checkpoints:addCheckpoint("bridge", Vector3(0, 1, 50))
-- checkpoints:addCheckpoint("arena",  Vector3(0, 1, 100))
-- checkpoints.onCheckpointReached = function(cp)
--     -- Save progress, show UI notification
-- end
```

---

## 9. Difficulty Progression: Teaching Through Design

### The 4-Step Teaching Pattern

```
STEP 1: Safe Introduction
  [Player] --> [Gap] --> [Platform]
  No enemies, cannot die. Learn the mechanic.

STEP 2: Add Stakes
  [Player] --> [Gap + Spikes] --> [Platform]
  Same mechanic, now with consequence for failure.

STEP 3: Add Complexity
  [Player] --> [Moving Platform] --> [Goal]
  Timing + previously learned jump skill.

STEP 4: Combine Mechanics
  [Player] --> [Enemy] + [Gap] --> [Reward]
  Combat + platforming tested together.
```

### Difficulty Curve Types

| Curve | Shape | Use Case |
|-------|-------|----------|
| **Linear** | Steady climb | Puzzle games, tutorials |
| **Stepped** | Flat, jump, flat | Action games with chapters |
| **Sawtooth** | Rise, drop, rise higher | RPGs with hub returns |
| **Exponential** | Slow start, steep end | Roguelikes, score-chasers |

### Difficulty Scaling (Lua)

```lua
--- Calculate scaled difficulty based on progression
---@param baseValue number base stat (e.g., enemy HP)
---@param level number current level (1-based)
---@param curveType string "linear"|"stepped"|"sawtooth"|"exponential"
---@return number scaledValue
local function scaleDifficulty(baseValue, level, curveType)
    if curveType == "linear" then
        return baseValue * (1 + (level - 1) * 0.15)
    elseif curveType == "stepped" then
        local step = math.floor((level - 1) / 3)  -- jump every 3 levels
        return baseValue * (1 + step * 0.4)
    elseif curveType == "sawtooth" then
        local cycle = ((level - 1) % 5) / 5       -- reset every 5 levels
        local tier = math.floor((level - 1) / 5)
        return baseValue * (1 + tier * 0.5 + cycle * 0.3)
    elseif curveType == "exponential" then
        return baseValue * (1.12 ^ (level - 1))    -- 12% per level
    end
    return baseValue
end
```

---

## 10. Level Metrics Reference

### Target Metrics by Genre

| Metric | Action | Puzzle | RPG | Platformer |
|--------|--------|--------|-----|------------|
| Avg. completion time | 5-10 min | 10-20 min | 30-60 min | 3-8 min |
| Deaths per level | 2-5 | 0-2 | 1-3 | 5-15 |
| Secrets per level | 2-3 | 1-2 | 5-10 | 3-5 |
| Checkpoint frequency | Every 2 min | At puzzle start | Safe rooms | Every 30 sec |
| New mechanics introduced | 1 per level | 1-2 per level | 1 per chapter | 1 per 3 levels |

### Level Size Guidelines (UrhoX meters)

| Level Type | Playable Area | Vertical Range | Typical Node Count |
|-----------|---------------|----------------|--------------------|
| Tutorial | 50x50m | 0-5m | 50-100 |
| Standard level | 100x100m | 0-20m | 100-500 |
| Large arena | 200x200m | 0-30m | 300-1000 |
| Open zone | 500x500m+ | 0-50m | 500-2000+ (use LOD) |

---

## 11. Troubleshooting

### Players Get Lost

| Cause | Solution |
|-------|----------|
| Weak visual guidance | Add point/spot lights along critical path |
| Too many equal paths | Make main path visually distinct (wider, brighter) |
| No landmarks | Add tall unique structures visible from multiple angles |
| Missing signposts | Place collectible breadcrumbs or NPC hints at forks |

### Level Feels Too Long or Boring

| Cause | Solution |
|-------|----------|
| No pacing variety | Add rest zones between combat encounters |
| Redundant sections | Cut or merge areas that repeat the same challenge |
| Backtracking tedium | Add shortcuts that unlock after first traversal |
| No rewards | Place discoveries, pickups, or story beats more frequently |

### Difficulty Spikes Frustrate Players

| Cause | Solution |
|-------|----------|
| Untaught mechanic | Add safe training area before the hard section |
| Checkpoint too far | Place checkpoint closer to the challenge |
| Resource starvation | Provide optional resources/health before boss |
| Single solution | Offer multiple valid approaches to the challenge |

### Players Skip Optional Content

| Cause | Solution |
|-------|----------|
| Secrets too hidden | Partially reveal secrets (visible but not accessible yet) |
| Rewards off-path feel not worth it | Place valuable rewards near (but not on) critical path |
| No audio cues | Add subtle sounds for hidden areas (wind, chimes) |
| Low-value rewards | Ensure optional content has meaningful, unique rewards |

---

## Quick Reference

### Level Design Decision Flow

```
What type of game?
+-- Linear narrative --> Linear structure + strong pacing curve
+-- Exploration-focused --> Hub/Metroidvania + discovery layers
+-- Action-focused --> Arena-based + stepped difficulty
+-- Open world --> Zone-based + player-driven pacing

What phase of development?
+-- Concept --> Paper sketches, beat charts
+-- Prototype --> Whitebox with UrhoX primitives
+-- Production --> Art pass, lighting, atmosphere
+-- Polish --> Audio, VFX, performance, playtesting
```

### Files to Read for More Detail

- `references/spatial-patterns.md` -- Deep dive on spatial design, room composition, and connectivity
- `references/pacing-and-flow.md` -- Advanced pacing techniques, dynamic difficulty, and metric tracking
