# Project Conventions & Collaboration Practices

Standards for project organization, Git workflow, and team collaboration adapted for UrhoX Lua game projects.

---

## Project Setup Checklist

When starting a new UrhoX Lua game project:

### 1. Directory Structure
- [ ] Create `scripts/` for game code
- [ ] Create `assets/` for textures, sounds, models
- [ ] Choose appropriate scaffold from `templates/`
- [ ] Create `scripts/Config.lua` for game constants

### 2. Entry Point
- [ ] `scripts/main.lua` contains `Start()` function
- [ ] Entry point is clean — delegates to module functions
- [ ] Required scaffolding code (scene setup, camera, lighting) is in place

### 3. Configuration
- [ ] Game constants extracted to `Config.lua`
- [ ] No magic numbers in game logic files
- [ ] Difficulty/tuning values are easy to find and change

### 4. Multiplayer Check
- [ ] Read `.project/settings.json` for `multiplayer.enabled`
- [ ] Code organized accordingly (Standalone vs Client/Server)

---

## File Organization Rules

### Naming Conventions

| Item | Convention | Examples |
|------|-----------|---------|
| Lua source files | PascalCase | `GameManager.lua`, `EnemyAI.lua` |
| Directories | PascalCase | `Game/`, `UI/`, `Utils/` |
| Asset folders | PascalCase | `Textures/`, `Sounds/`, `Models/` |
| Config/data files | PascalCase or kebab-case | `Config.lua`, `level-data.json` |

### One Module = One Responsibility

Each `.lua` file should own exactly one concept:

| File | Responsibility |
|------|---------------|
| `Player.lua` | Player state, input, movement |
| `Enemy.lua` | Enemy behavior, AI |
| `Spawner.lua` | Entity spawning logic |
| `HUD.lua` | Score, health, timer display |
| `Config.lua` | All tunable constants |

**Anti-pattern**: `GameLogic.lua` that contains player + enemy + spawning + UI + scoring all in one file.

---

## Dependency Management

### Import Order Convention

```lua
-- 1. Engine/platform utilities
require "LuaScripts/Utilities/Sample"
local PlatformUtils = require "urhox-libs.Platform.PlatformUtils"

-- 2. Third-party/shared libraries
local Tween = require "urhox-libs.Tween.tween"

-- 3. Local project modules
local Config = require "Config"
local Player = require "Game.Player"
local Enemy  = require "Game.Enemy"
```

### Circular Dependency Prevention

```lua
-- BAD: Player requires Enemy, Enemy requires Player → circular\!

-- FIX 1: Inject dependency at runtime
function Enemy:SetTarget(playerNode)
    self.target = playerNode
end

-- FIX 2: Use event system to decouple
-- Enemy publishes "EnemyAttacked", Player subscribes
SubscribeToEvent("EnemyAttacked", function(_, eventData) ... end)
```

---

## Git Workflow for Game Projects

### Branch Naming

| Type | Format | Example |
|------|--------|---------|
| Feature | `feature/description` | `feature/add-inventory-system` |
| Bugfix | `fix/description` | `fix/player-stuck-on-wall` |
| Polish | `polish/description` | `polish/menu-animations` |
| Experiment | `experiment/description` | `experiment/new-enemy-ai` |

### Commit Message Convention

```
<type>: <short description>

<optional body explaining WHY>
```

**Types for game dev:**

| Type | When |
|------|------|
| `feat` | New game feature or mechanic |
| `fix` | Bug fix |
| `balance` | Gameplay tuning (damage, speed, timing) |
| `art` | Asset additions or changes |
| `audio` | Sound/music additions or changes |
| `ui` | UI/HUD changes |
| `perf` | Performance optimization |
| `refactor` | Code restructure without behavior change |
| `clean` | Remove dead code, organize files |

**Examples:**
```
feat: add double-jump mechanic with coyote time

balance: reduce goblin damage from 25 to 15, increase spawn delay

fix: player falls through floor when landing on slope edge

refactor: extract enemy AI into separate module
```

### What NOT to Commit

```gitignore
# UrhoX project .gitignore additions
.project/        # Engine-generated project config
.build/          # Build artifacts
.tmp/            # Temporary files
dist/            # Distribution output
logs/            # Log files
*.log
```

---

## Error Handling Patterns

### Defensive Resource Loading

```lua
-- BEFORE: Crash if resource missing
local model = cache:GetResource("Model", "Models/Player.mdl")
node:GetComponent("StaticModel"):SetModel(model)
-- If model is nil → crash\!

-- AFTER: Defensive check
local model = cache:GetResource("Model", "Models/Player.mdl")
if not model then
    print("[WARN] Model not found: Models/Player.mdl, using fallback")
    model = cache:GetResource("Model", "Models/Box.mdl")
end
node:GetComponent("StaticModel"):SetModel(model)
```

### Safe Node Access

```lua
-- Helper function
local function safeGetComponent(node, componentType)
    if not node then return nil end
    return node:GetComponent(componentType)
end

-- Usage
local body = safeGetComponent(enemyNode, "RigidBody")
if body then
    body:ApplyImpulse(knockback)
end
```

### Event Data Access Pattern

```lua
-- Robust event data extraction
function HandleCollision(eventType, eventData)
    local otherNode = eventData["OtherNode"]:GetPtr("Node")
    if not otherNode then return end  -- guard

    local otherBody = eventData["OtherBody"]:GetPtr("RigidBody")
    if not otherBody then return end  -- guard

    -- Safe to proceed
    processCollision(otherNode, otherBody)
end
```

---

## Performance-Aware Coding Conventions

### Avoid Per-Frame Allocations

```lua
-- BAD: Creates new table every frame
function HandleUpdate(eventType, eventData)
    local enemies = findEnemiesInRange(player.pos, 10)  -- returns new table
    local status = { hp = player.hp, score = score }      -- new table
end

-- GOOD: Reuse tables
local enemyBuffer = {}    -- reused each frame
local statusBuffer = {}   -- reused each frame

function HandleUpdate(eventType, eventData)
    findEnemiesInRange(player.pos, 10, enemyBuffer)  -- fills existing table
    statusBuffer.hp = player.hp
    statusBuffer.score = score
end
```

### String Concatenation in Hot Paths

```lua
-- BAD: String concatenation every frame
function HandleUpdate(eventType, eventData)
    debugText.text = "FPS: " .. tostring(fps) .. " Entities: " .. tostring(count)
end

-- GOOD: Use string.format (single allocation) and throttle
local debugUpdateTimer = 0
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    debugUpdateTimer = debugUpdateTimer + dt
    if debugUpdateTimer >= 0.25 then  -- update 4x per second
        debugUpdateTimer = 0
        debugText.text = string.format("FPS: %d Entities: %d", fps, count)
    end
end
```

### Cache Component References

```lua
-- BAD: GetComponent every frame
function HandleUpdate(eventType, eventData)
    local body = playerNode:GetComponent("RigidBody")  -- lookup each frame
    body.linearVelocity = moveDir * speed
end

-- GOOD: Cache in Start()
local playerBody  -- cached reference

function Start()
    playerBody = playerNode:GetComponent("RigidBody")
end

function HandleUpdate(eventType, eventData)
    playerBody.linearVelocity = moveDir * speed  -- use cached reference
end
```

---

## Team Collaboration Tips

### Conflict-Free Module Boundaries

When multiple developers work on the same game:

| Developer | Owns | Files |
|-----------|------|-------|
| Dev A | Player mechanics | `Game/Player.lua`, `Game/Abilities.lua` |
| Dev B | Enemy/AI | `Game/Enemy.lua`, `Game/AIBehavior.lua` |
| Dev C | UI/UX | `UI/HUD.lua`, `UI/Menu.lua`, `UI/Inventory.lua` |
| Shared | Config, entry point | `Config.lua`, `main.lua` (minimal changes) |

### Reducing Merge Conflicts

1. **Keep `main.lua` thin** — just calls module functions
2. **Config in one file** — `Config.lua` is the only shared data
3. **Communicate module interfaces** — agree on function signatures before coding
4. **Use events for cross-module communication** — avoid direct module-to-module calls

### Code Handoff Checklist

Before handing code to another developer:

- [ ] No `print()` debug statements left (or clearly marked `-- DEBUG`)
- [ ] All public functions have `---@param` annotations
- [ ] Module header comment explains purpose and dependencies
- [ ] Constants are in `Config.lua`, not inline
- [ ] Code builds successfully via build tool
