---
name: software-engineering-lua
description: >-
  Software engineering best practices adapted for UrhoX Lua game projects.
  Covers code smell detection and refactoring patterns in Lua, structured
  debugging methodology, code review checklists for game scripts, project
  organization and module architecture, documentation standards, and
  Git workflow conventions. Bridges the gap between general software
  engineering principles and practical Lua game development, helping
  developers write cleaner, more maintainable game code.
---

# Software Engineering Best Practices for UrhoX Lua Games

## Identity

You are a **Software Engineering Coach** for Lua game developers. You help apply professional engineering practices — refactoring, code review, debugging methodology, documentation, and project organization — to UrhoX Lua game projects, raising code quality without over-engineering.

## Trigger Conditions

Activate this skill when the user:
- Asks to **refactor** or **clean up** game code
- Asks for a **code review** of their Lua scripts
- Wants to **organize** or **restructure** their project files
- Encounters **code smells** (long functions, duplicated logic, deep nesting)
- Asks about **naming conventions**, **documentation standards**, or **coding style** for Lua
- Needs a **debugging methodology** for Lua-specific bugs
- Asks about **project setup** best practices or module structure
- Mentions "technical debt", "maintainability", or "code quality"

## Skip Conditions

Do NOT activate when:
- User needs **general fullstack/web/backend** knowledge → delegate to `fullstack-dev-skills`
- User needs **game architecture patterns** (state machines, object pooling, ECS) → delegate to `game-design-patterns`
- User needs **performance profiling** → delegate to `game-performance`
- User needs **game quality audit with scoring** → delegate to `game-review-improve`
- User needs **systematic game bug investigation** → delegate to `game-debugging`
- User needs **Git save/commit** → delegate to `@org_git-save`

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `fullstack-dev-skills` | General SE knowledge base; this skill **specializes** it for Lua game dev |
| `game-design-patterns` | Game architecture patterns; this skill covers **code-level** quality |
| `game-debugging` | Game-specific debugging; this skill covers **SE debugging methodology** |
| `game-review-improve` | Game quality scoring; this skill covers **code review checklists** |
| `game-creation-workflow` | End-to-end workflow; this skill provides **engineering discipline within** each phase |

---

## Lua Code Smells — Detection & Fix

Quick reference for common code smells in Lua game scripts. Full catalog: `references/refactoring-patterns.md`

| # | Code Smell | Symptom | Fix |
|---|-----------|---------|-----|
| 1 | **Long Function** | Function > 50 lines | Extract helper functions |
| 2 | **God File** | Single file > 1500 lines | Split into modules |
| 3 | **Magic Numbers** | Hardcoded `0.5`, `100`, `3.14` | Extract to named constants |
| 4 | **Deep Nesting** | 4+ indent levels | Early returns / guard clauses |
| 5 | **Copy-Paste Logic** | Same 5+ lines in multiple places | Extract to shared function |
| 6 | **Long Parameter List** | Function with 5+ params | Use config table |
| 7 | **Global State Soup** | Many loose globals | Use module tables |
| 8 | **Dead Code** | Commented-out blocks, unused vars | Delete it |
| 9 | **Stringly Typed** | Comparing raw strings for state | Use constants or enums |
| 10 | **Callback Hell** | Nested anonymous functions 3+ deep | Named functions or coroutines |

### Pattern: Extract Config Table

```lua
-- BEFORE: Long parameter list (smell #6)
function CreateEnemy(name, hp, speed, damage, color, scale, model)
    -- ...
end
CreateEnemy("Goblin", 100, 5.0, 10, Color(0,1,0), 0.8, "Models/Goblin.mdl")

-- AFTER: Config table
function CreateEnemy(config)
    local name   = config.name   or "Enemy"
    local hp     = config.hp     or 100
    local speed  = config.speed  or 3.0
    local damage = config.damage or 10
    -- ...
end
CreateEnemy {
    name = "Goblin", hp = 100, speed = 5.0,
    damage = 10, color = Color(0,1,0),
}
```

### Pattern: Guard Clause (Early Return)

```lua
-- BEFORE: Deep nesting (smell #4)
function HandleCollision(eventType, eventData)
    local other = eventData["OtherNode"]:GetPtr("Node")
    if other then
        if other.name == "Coin" then
            if not collected[other:GetID()] then
                collected[other:GetID()] = true
                score = score + 10
                other:Remove()
            end
        end
    end
end

-- AFTER: Guard clauses
function HandleCollision(eventType, eventData)
    local other = eventData["OtherNode"]:GetPtr("Node")
    if not other then return end
    if other.name ~= "Coin" then return end
    if collected[other:GetID()] then return end

    collected[other:GetID()] = true
    score = score + 10
    other:Remove()
end
```

### Pattern: Named Constants

```lua
-- BEFORE: Magic numbers (smell #3)
if player.hp <= 0 then ... end
node.position = Vector3(0, 0.5, 0)
if timer > 3.0 then ... end

-- AFTER: Named constants
local PLAYER_DEAD_HP = 0
local GROUND_HALF_HEIGHT = 0.5
local RESPAWN_DELAY = 3.0

if player.hp <= PLAYER_DEAD_HP then ... end
node.position = Vector3(0, GROUND_HALF_HEIGHT, 0)
if timer > RESPAWN_DELAY then ... end
```

---

## Module Architecture

### Recommended Project Structure

```
scripts/
├── main.lua              -- Entry point (Start/Stop/HandleUpdate)
├── Config.lua            -- Game constants and settings
├── Game/
│   ├── GameManager.lua   -- Core game loop and state
│   ├── Player.lua        -- Player logic
│   ├── Enemy.lua         -- Enemy logic
│   └── Level.lua         -- Level/scene management
├── UI/
│   ├── HUD.lua           -- In-game HUD
│   ├── Menu.lua          -- Main menu
│   └── PauseMenu.lua     -- Pause overlay
└── Utils/
    ├── MathUtils.lua      -- Math helpers
    ├── TableUtils.lua     -- Table manipulation
    └── Debug.lua          -- Debug/logging utilities
```

### Module Template

```lua
-- scripts/Game/Enemy.lua
local Enemy = {}
Enemy.__index = Enemy

-- Constants
local DEFAULT_HP = 100
local DEFAULT_SPEED = 3.0

function Enemy.new(scene, config)
    local self = setmetatable({}, Enemy)
    self.hp = config.hp or DEFAULT_HP
    self.speed = config.speed or DEFAULT_SPEED
    self.node = scene:CreateChild(config.name or "Enemy")
    -- setup components ...
    return self
end

function Enemy:Update(dt)
    -- per-frame logic
end

function Enemy:TakeDamage(amount)
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self:Die()
    end
end

function Enemy:Die()
    self.node:Remove()
end

return Enemy
```

```lua
-- Usage in main.lua
local Enemy = require "Game.Enemy"
local goblin = Enemy.new(scene_, { name = "Goblin", hp = 50 })
```

### When to Split Files

| Indicator | Action |
|-----------|--------|
| File > 500 lines | Consider splitting |
| File > 1000 lines | Strongly consider splitting |
| File > 1500 lines | **Must** split (CLAUDE.md Rule #13) |
| 2+ systems in one file | Split into separate modules |
| Shared utility functions | Extract to `Utils/` module |

---

## Code Review Checklist for Lua Game Scripts

Before merging or delivering Lua code, verify:

### Correctness
- [ ] All `eventData` access uses correct getter (`:GetInt()`, `:GetFloat()`, `:GetPtr()`)
- [ ] Array loops start at index 1 (not 0)
- [ ] `nil` checks before accessing node/component members
- [ ] Event subscriptions have matching unsubscriptions on cleanup
- [ ] Resources are properly released (`node:Remove()`, unsubscribe events)

### Engine Compliance
- [ ] Code is in `scripts/` directory
- [ ] Uses `require "urhox-libs..."` not modifying `urhox-libs/`
- [ ] No `graphics:SetMode()` calls (use `GetWidth()/GetHeight()/GetDPR()`)
- [ ] Mouse buttons use `MOUSEB_LEFT`/`MOUSEB_RIGHT` (not numbers)
- [ ] PBR materials use `PBRNoTexture.xml` family (not guessed paths)
- [ ] NanoVG rendering is in `NanoVGRender` event handler
- [ ] Fonts created with `nvgCreateFont()` before text drawing

### Code Quality
- [ ] No magic numbers — constants are named
- [ ] No functions longer than ~50 lines
- [ ] No copy-pasted logic blocks
- [ ] No more than 3 levels of nesting
- [ ] Variables have clear, descriptive names
- [ ] No unused variables or dead code

### Performance
- [ ] No per-frame allocations (`{}` tables, string concatenation in Update)
- [ ] `nvgCreateFont()` called once in `Start()`, not every frame
- [ ] Heavy computations cached or throttled
- [ ] Object pooling used for frequently spawned/destroyed entities

---

## Debugging Methodology for Lua

### The 4-Step Process

```
1. REPRODUCE  →  Get exact steps, note expected vs actual
2. ISOLATE    →  Binary search: comment out halves of code
3. ROOT CAUSE →  Trace data flow, check assumptions
4. FIX+VERIFY →  Minimal fix, add guard, test regression
```

### Lua-Specific Debug Techniques

```lua
-- 1. Strategic logging with context
print(string.format("[Player] hp=%d pos=(%.1f,%.1f,%.1f) state=%s",
    self.hp, pos.x, pos.y, pos.z, self.state))

-- 2. Type checking at boundaries
assert(type(damage) == "number", "damage must be number, got: " .. type(damage))
assert(node ~= nil, "node is nil — was it removed?")

-- 3. Table inspection
local function dumpTable(t, indent)
    indent = indent or ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indent .. tostring(k) .. " = {")
            dumpTable(v, indent .. "  ")
            print(indent .. "}")
        else
            print(indent .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

-- 4. Frame counter for intermittent bugs
local frameCount = 0
function HandleUpdate(eventType, eventData)
    frameCount = frameCount + 1
    if bug_condition then
        print("[BUG] Occurred at frame " .. frameCount)
    end
end
```

### Common Lua Bug Patterns

| Bug Pattern | Symptom | Root Cause | Fix |
|-------------|---------|-----------|-----|
| `nil` index | `attempt to index a nil value` | Forgot `nil` check, node removed | Add guard: `if not node then return end` |
| Off-by-one | Wrong item selected, skip first/last | Index starts at 0 (should be 1) | Use `for i = 1, #arr` |
| Stale reference | Random crashes, wrong behavior | Node removed but reference kept | Set ref to `nil` after `:Remove()` |
| Scope leak | Variable mysteriously changes | Forgot `local` keyword | Always declare `local` |
| Event leak | Logic runs after scene change | Forgot to unsubscribe events | Unsubscribe in `Stop()` or cleanup |
| Closure capture | All callbacks use same value | Loop variable captured by reference | Capture via local copy |

### Closure Capture Fix

```lua
-- BUG: All buttons do the same thing (i is always 6 after loop)
for i = 1, 5 do
    buttons[i].onClick = function()
        print("Button " .. i)  -- always prints 6\!
    end
end

-- FIX: Capture via local
for i = 1, 5 do
    local idx = i  -- local copy captured by closure
    buttons[idx].onClick = function()
        print("Button " .. idx)  -- prints 1,2,3,4,5 correctly
    end
end
```

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Local variables | camelCase | `playerHp`, `moveSpeed` |
| Constants | UPPER_SNAKE | `MAX_ENEMIES`, `TILE_SIZE` |
| Functions | camelCase or PascalCase | `createEnemy()`, `HandleUpdate()` |
| Modules/Classes | PascalCase | `Enemy`, `GameManager` |
| Event handlers | `Handle` + EventName | `HandleUpdate`, `HandleCollision` |
| Private fields | `_` prefix | `self._internalState` |
| File names | PascalCase | `GameManager.lua`, `MathUtils.lua` |
| Engine callbacks | PascalCase (engine convention) | `Start()`, `Stop()`, `CreateScene()` |

---

## Documentation Standards

### Function Documentation

```lua
--- Create a new projectile and launch it toward the target.
---@param scene Scene The active scene
---@param origin Vector3 Spawn position
---@param target Vector3 Target position
---@param speed number Travel speed in m/s
---@return Node The projectile node
function LaunchProjectile(scene, origin, target, speed)
    -- implementation
end
```

### Module Header

```lua
--[[
    Enemy.lua — Enemy AI and behavior system

    Handles enemy spawning, patrol routes, aggro detection,
    and combat behavior. Uses finite state machine for AI states.

    Dependencies:
        - Config.lua (enemy stat tables)
        - Utils/MathUtils.lua (distance helpers)

    Usage:
        local Enemy = require "Game.Enemy"
        local e = Enemy.new(scene, { name = "Orc", hp = 200 })
]]
```

### When to Comment

| Situation | Action |
|-----------|--------|
| **Why** something is done | Comment |
| **What** the code does (obvious) | No comment needed |
| Complex formula or algorithm | Comment with reference |
| Workaround for engine quirk | Comment explaining why |
| Business rule or game design decision | Comment |
| Trivial getter/setter | No comment |

---

## Reference Files

| File | Content |
|------|---------|
| `references/refactoring-patterns.md` | Complete catalog of Lua refactoring patterns with before/after examples |
| `references/project-conventions.md` | Project setup conventions, Git workflow, and team collaboration practices |
