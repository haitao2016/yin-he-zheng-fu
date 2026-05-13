# Spatial Design Patterns for UrhoX Levels

Deep-dive reference on room composition, connectivity graphs, spatial flow, and UrhoX implementation patterns.

---

## 1. Room Composition Principles

### The Rule of Three Views

Every room should offer the player three distinct views when they enter:

```
Player enters from south:

         [Point of Interest]     <-- "what's that?" (DISCOVERY)
              |
    [Decoration]  [Decoration]
              |
         [Main Path]             <-- "where do I go?" (CLARITY)
              |
     [Side Path]  [Resource]     <-- "what else is here?" (OPTIONAL)
              |
         [ENTRANCE]
```

### Room Roles

| Role | Purpose | Size | Intensity | Examples |
|------|---------|------|-----------|---------|
| **Connector** | Move between areas | Small (3x3m - 5x5m) | Low | Hallways, doors, tunnels |
| **Arena** | Combat encounter | Medium (10x10m - 20x20m) | High | Open room, courtyard |
| **Puzzle** | Mental challenge | Variable | Medium | Switch room, lock room |
| **Hub** | Navigation center | Large (15x15m+) | Low | Town square, central hall |
| **Reward** | Treasure/rest | Small (3x3m - 8x8m) | Very Low | Treasure room, shop, save point |
| **Vista** | Showcase/foreshadow | Any | Low | Balcony, cliff edge, window |

### Room Composition (Lua)

```lua
--- Room composition helper: creates a room with role-appropriate setup
---@param scene Scene
---@param config table {name, position, size, role, mood}
---@return Node
local function createRoom(scene, config)
    local room = scene:CreateChild(config.name)
    room.position = config.position

    -- Floor
    local floor = room:CreateChild("Floor")
    floor.scale = Vector3(config.size.x, 0.2, config.size.z)
    local fm = floor:CreateComponent("StaticModel")
    fm.model = cache:GetResource("Model", "Models/Box.mdl")
    fm.material = cache:GetResource("Material", "Materials/DefaultGrey.xml")

    -- Floor collision
    local fb = floor:CreateComponent("RigidBody")
    fb.mass = 0
    local fs = floor:CreateComponent("CollisionShape")
    fs:SetBox(Vector3(config.size.x, 0.2, config.size.z))

    -- Role-specific setup
    if config.role == "arena" then
        -- Add entry/exit trigger zones
        createZoneTrigger(scene, config.position + Vector3(0, 1, -config.size.z / 2),
            Vector3(2, 2, 1), config.name .. "_entry",
            function() log:Write(LOG_INFO, "Arena started: " .. config.name) end)
    elseif config.role == "hub" then
        -- Add central light
        local hubLight = room:CreateChild("HubLight")
        hubLight.position = Vector3(0, config.size.y or 4, 0)
        local light = hubLight:CreateComponent("Light")
        light.lightType = LIGHT_POINT
        light.range = math.max(config.size.x, config.size.z)
        light.color = Color(1.0, 0.95, 0.8, 1.0)
    elseif config.role == "reward" then
        -- Mark with warm lighting
        local rewardLight = room:CreateChild("RewardLight")
        rewardLight.position = Vector3(0, 3, 0)
        local light = rewardLight:CreateComponent("Light")
        light.lightType = LIGHT_POINT
        light.range = 8.0
        light.color = Color(1.0, 0.85, 0.4, 1.0)
        light.brightness = 1.5
    end

    return room
end
```

---

## 2. Connectivity Graphs

### Adjacency Matrix

Use a connectivity table to plan level topology before building:

```lua
--- Level connectivity graph
---@class LevelGraph
local LevelGraph = {}
LevelGraph.__index = LevelGraph

function LevelGraph:new()
    local o = setmetatable({}, self)
    o.rooms = {}       -- { name = { role, position, size } }
    o.edges = {}       -- { {from, to, type} }
    return o
end

--- Add a room to the level graph
function LevelGraph:addRoom(name, role, position, size)
    self.rooms[name] = {
        role = role,
        position = position,
        size = size,
    }
end

--- Connect two rooms
---@param from string
---@param to string
---@param edgeType string "door"|"corridor"|"portal"|"locked"
function LevelGraph:connect(from, to, edgeType)
    self.edges[#self.edges + 1] = {
        from = from,
        to = to,
        type = edgeType or "door",
    }
end

--- Get all rooms connected to a given room
function LevelGraph:getNeighbors(roomName)
    local neighbors = {}
    for _, edge in ipairs(self.edges) do
        if edge.from == roomName then
            neighbors[#neighbors + 1] = { room = edge.to, type = edge.type }
        elseif edge.to == roomName then
            neighbors[#neighbors + 1] = { room = edge.from, type = edge.type }
        end
    end
    return neighbors
end

--- Validate connectivity: all rooms reachable from start
function LevelGraph:isFullyConnected(startRoom)
    local visited = {}
    local queue = { startRoom }
    visited[startRoom] = true

    while #queue > 0 do
        local current = table.remove(queue, 1)
        local neighbors = self:getNeighbors(current)
        for _, n in ipairs(neighbors) do
            if not visited[n.room] then
                visited[n.room] = true
                queue[#queue + 1] = n.room
            end
        end
    end

    -- Check all rooms visited
    for name, _ in pairs(self.rooms) do
        if not visited[name] then
            log:Write(LOG_WARNING, "Unreachable room: " .. name)
            return false
        end
    end
    return true
end

-- Example usage:
-- local graph = LevelGraph:new()
-- graph:addRoom("entrance", "connector", Vector3(0,0,0),    Vector3(5,4,5))
-- graph:addRoom("hub",      "hub",       Vector3(0,0,20),   Vector3(15,6,15))
-- graph:addRoom("arena_1",  "arena",     Vector3(-20,0,20), Vector3(12,5,12))
-- graph:addRoom("arena_2",  "arena",     Vector3(20,0,20),  Vector3(12,5,12))
-- graph:addRoom("treasure",  "reward",   Vector3(0,0,40),   Vector3(6,4,6))
-- graph:connect("entrance", "hub", "corridor")
-- graph:connect("hub", "arena_1", "door")
-- graph:connect("hub", "arena_2", "door")
-- graph:connect("hub", "treasure", "locked")
-- assert(graph:isFullyConnected("entrance"))
```

### Topology Patterns

```
LINEAR:          A ── B ── C ── D ── E
                 (One path, strong narrative control)

BRANCHING:       A ── B ── C
                      └── D ── E
                 (Player choice, moderate complexity)

LOOP:            A ── B ── C
                 └────────┘
                 (Shortcuts, reduce backtracking)

DIAMOND:         A ── B ── D
                 └── C ──┘
                 (Multiple paths to same goal)

HUB:                B
                    |
               C ── A ── D
                    |
                    E
                 (Central meeting point, RPG towns)
```

### Critical Path vs Optional Path

```
CRITICAL PATH (must traverse):
  [Start] ═══ [Room A] ═══ [Room B] ═══ [Boss] ═══ [End]

OPTIONAL PATHS (exploration rewards):
  [Start] ═══ [Room A] ═══ [Room B] ═══ [Boss] ═══ [End]
                  │              │
              [Secret 1]    [Secret 2]
                  │
              [Treasure]

Design rules:
  - Critical path: always clear, well-lit, obvious
  - Optional paths: partially visible, quieter, smaller entrances
  - Secrets: hidden but not invisible (audio cue, crack in wall)
```

---

## 3. Spatial Flow Techniques

### Funneling

Guide the player toward objectives by narrowing the space:

```
WIDE ━━━━━━━━━━━━━━━━━ NARROW ━━━ [OBJECTIVE]
   ╲                    ╱
    ╲                  ╱
     ╲                ╱
      ╲              ╱
       ╲            ╱
        ╲          ╱
```

Implementation: Use walls, obstacles, or terrain that gradually narrow the walkable area.

### Reveal and Reward

Show the player something interesting before they can reach it:

```
Step 1: VISTA (see the castle from a cliff)
   [Player] ──── [Cliff Edge]
                       │ (see but can't reach)
                  [Castle below]

Step 2: JOURNEY (descend to the castle)
   [Cliff] → [Path down] → [Forest] → [Bridge]

Step 3: ARRIVAL (reach what was seen)
   [Bridge] → [Castle Gate] → [Interior]
```

### Gating Techniques

| Gate Type | Mechanism | Player Experience |
|-----------|-----------|-------------------|
| **Ability gate** | Need specific skill | "I'll come back when I can double-jump" |
| **Key gate** | Need item from elsewhere | "I need to find the red key" |
| **Combat gate** | Clear enemies to proceed | "I must defeat the arena to unlock the door" |
| **Puzzle gate** | Solve puzzle to open | "I need to figure out this switch sequence" |
| **Soft gate** | Enemies too strong | "Those enemies are too tough for me now" |

```lua
--- Ability-gated door: opens only when player has required ability
---@param scene Scene
---@param position Vector3
---@param requiredAbility string
---@param playerAbilities table reference to player's ability set
local function createAbilityGate(scene, position, requiredAbility, playerAbilities)
    local gate = scene:CreateChild("Gate_" .. requiredAbility)
    gate.position = position
    gate.scale = Vector3(3, 4, 0.5)

    local model = gate:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")

    -- Visual indicator: red = locked, green = unlockable
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource(
        "Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.2, 0.2, 1.0)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3, 0.0, 0.0, 1.0)))
    model.material = mat

    -- Physical blocker
    local body = gate:CreateComponent("RigidBody")
    body.mass = 0
    local shape = gate:CreateComponent("CollisionShape")
    shape:SetBox(Vector3(3, 4, 0.5))

    -- Interaction zone
    local triggerNode = gate:CreateChild("InteractZone")
    local triggerBody = triggerNode:CreateComponent("RigidBody")
    triggerBody.trigger = true
    triggerBody.mass = 0
    local triggerShape = triggerNode:CreateComponent("CollisionShape")
    triggerShape:SetBox(Vector3(5, 4, 3))

    SubscribeToEvent(triggerNode, "NodeCollisionStart", function(_, eventData)
        if playerAbilities[requiredAbility] then
            -- Unlock: remove physical blocker, change color
            gate:Remove()
            log:Write(LOG_INFO, "Gate unlocked with: " .. requiredAbility)
        else
            log:Write(LOG_INFO, "Locked: requires " .. requiredAbility)
        end
    end)

    return gate
end
```

---

## 4. Room Composition Templates

### Combat Arena Template

```
┌─────────────────────────────┐
│  [Cover]          [Cover]   │
│         ╲        ╱          │
│          [Center]           │
│         ╱        ╲          │
│  [Cover]          [Cover]   │
│            │                │
│         [ENTRY]             │
└─────────────────────────────┘

Design principles:
- Entry at one end, reward/exit at opposite end
- Cover objects at cardinal positions
- Center area is exposed (high risk)
- Sight lines broken by pillars/walls
- Size: 12x12m to 20x20m for standard encounters
```

### Puzzle Room Template

```
┌────────────────────────────┐
│  [Switch A]   [Switch B]   │
│       │            │       │
│       └─── [Gate] ─┘       │
│            │               │
│        [Pressure Plate]    │
│            │               │
│         [ENTRY]            │
└────────────────────────────┘

Design principles:
- All puzzle elements visible from entry
- No hidden information (clear what needs to happen)
- Multiple states visually distinct
- Reset mechanism if player makes mistake
- Size: 8x8m to 12x12m typically
```

### Corridor Connector Template

```
   [From Room]
       │
  ┌────┴────┐
  │ Corridor │  Width: 3m+, Length: 5-15m
  │  (items) │  Optional: pickups, lore objects
  └────┬────┘
       │
   [To Room]

Design principles:
- Transition space: change lighting/music gradually
- Brief enough to maintain flow (5-15m)
- Place breadcrumbs or story details
- Use slight turns to break sight line to next room
```

---

## 5. Spatial Metrics Checklist

Before finalizing a level layout, verify:

### Flow
- [ ] Critical path completion time is within genre target
- [ ] No dead ends on the critical path
- [ ] Player can always see or intuit the next objective
- [ ] Backtracking paths have shortcuts after first traversal

### Scale
- [ ] Doorways are at least 2.2m H x 1.2m W
- [ ] Corridors are at least 3m wide
- [ ] Combat arenas allow for dodge/roll space (10m+ diameter)
- [ ] Jump gaps match character jump distance (2-4m standard)
- [ ] Ceiling height matches room mood (3m normal, 6m+ grand)

### Connectivity
- [ ] All rooms are reachable from start (run `isFullyConnected()`)
- [ ] Locked paths have a clear unlock mechanism
- [ ] Optional paths are findable but not mandatory
- [ ] Loop shortcuts exist to reduce backtracking

### Pacing
- [ ] Rest zones exist after every peak intensity zone
- [ ] New mechanics introduced in safe environment first
- [ ] Boss encounters have a checkpoint nearby
- [ ] Level ends on a satisfying high note (reward/revelation)
