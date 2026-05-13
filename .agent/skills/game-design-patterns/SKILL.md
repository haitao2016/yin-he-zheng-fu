---
name: game-design-patterns
description: "Game design patterns and best practices for UrhoX Lua games, covering core loop design, GDD structure, player psychology, 2D/3D game architecture, genre-specific templates, audio integration, difficulty balancing, and progression systems. Use when users need to (1) design core loop or GDD, (2) choose patterns for specific genres (platformer, shooter, puzzle, RPG, tower defense), (3) implement 2D patterns: sprite animation, tilemaps, parallax, platformer feel (coyote time, jump buffering), (4) implement 3D patterns: camera systems, lighting, collider selection, LOD, (5) integrate audio with spatial sound, adaptive music, sound layering, (6) design difficulty curves, progression, or reward schedules, (7) understand player psychology (Bartle types, flow state, engagement hooks), (8) add game juice/polish (screen shake, hit stop, particles, squash-stretch), (9) structure game projects with state management and scene transitions, or any other game design and architecture tasks."
---

# Game Design Patterns for UrhoX

> Adapted from [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) game-development suite.
> Provides game design fundamentals, genre patterns, and UrhoX Lua implementation guidance.

---

## When to Use This Skill

| User Intent | This Skill Provides |
|-------------|-------------------|
| "I want to make a platformer/shooter/puzzle/RPG" | Genre-specific core loop + patterns |
| "How should I structure my game?" | State management + scene flow |
| "My game doesn't feel good" | Juice & polish patterns |
| "How do I balance difficulty?" | Progression + difficulty curves |
| "I need sound effects / music" | Audio integration patterns |
| "What camera should I use?" | Camera selection guide |
| "How do 2D tilemaps work?" | 2D architecture patterns |

**Routing to other skills** (do NOT duplicate):

| Need | Use Instead |
|------|------------|
| Performance optimization, object pooling, draw call batching | `game-performance` |
| Multiplayer networking, matchmaking, sync | `multiplayer-game` |
| Evolutionary AI, DDA via genetic algorithms | `evolutionary-game-systems` |
| System architecture (DDD, ECS, Data-Driven) | `@zy_game-architect-v2` |
| JRPG-specific system design documents | `@jrpg_jrpg-design` |
| UI components and layout | `@loomy_reactive-ui` or engine `urhox-libs/UI` |

---

## 1  Core Loop — The 30-Second Rule

Every game needs a fun 30-second loop. If the loop isn't fun, no amount of content saves it.

```
ACTION  →  Player does something
FEEDBACK →  Game responds immediately
REWARD  →  Player feels satisfaction
REPEAT  →  Loop tightens over time
```

### Genre Core Loops

| Genre | Core Loop | Key Metric |
|-------|-----------|------------|
| Platformer | Run → Jump → Land → Collect | Precision |
| Shooter | Aim → Shoot → Hit → Loot | Accuracy |
| Puzzle | Observe → Think → Solve → Advance | Insight |
| RPG | Explore → Fight → Level → Gear | Growth |
| Tower Defense | Build → Defend → Earn → Upgrade | Strategy |
| Idle/Clicker | Click → Earn → Upgrade → Automate | Accumulation |
| Racing | Steer → Boost → Drift → Finish | Speed |

### UrhoX Core Loop Skeleton

```lua
-- Every UrhoX game maps to this structure:

function Start()
    -- SETUP: Create world, load assets, init state
    SetupScene()
    SetupUI()
    gameState = "menu"
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- INPUT: Read player actions (abstracted)
    local actions = ReadInput()

    -- UPDATE: Process game logic by state
    if gameState == "playing" then
        UpdateGameplay(dt, actions)
    elseif gameState == "paused" then
        UpdatePauseMenu(actions)
    elseif gameState == "gameover" then
        UpdateGameOver(actions)
    end

    -- RENDER: Engine handles this automatically
    -- But update UI/HUD here
    UpdateHUD()
end
```

---

## 2  Game State Management

### State Machine Pattern

```lua
local GameStates = {
    MENU     = "menu",
    PLAYING  = "playing",
    PAUSED   = "paused",
    GAMEOVER = "gameover",
    VICTORY  = "victory",
}

local currentState = GameStates.MENU

local stateHandlers = {
    [GameStates.MENU] = {
        enter = function() ShowMainMenu() end,
        update = function(dt) UpdateMenu(dt) end,
        exit = function() HideMainMenu() end,
    },
    [GameStates.PLAYING] = {
        enter = function() StartGameplay() end,
        update = function(dt) UpdateGameplay(dt) end,
        exit = function() PauseGameplay() end,
    },
    -- ... more states
}

function ChangeState(newState)
    if currentState == newState then return end
    local old = stateHandlers[currentState]
    if old and old.exit then old.exit() end
    currentState = newState
    local new = stateHandlers[newState]
    if new and new.enter then new.enter() end
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    local handler = stateHandlers[currentState]
    if handler and handler.update then
        handler.update(dt)
    end
end
```

---

## 3  Input Abstraction

Abstract input into **actions**, not raw keys. Enables multi-platform and rebindable controls.

```lua
local InputActions = {}

function InputActions.read()
    local actions = {
        moveX = 0, moveY = 0,
        jump = false, attack = false,
        pause = false,
    }

    -- Keyboard
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then
        actions.moveX = actions.moveX - 1
    end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then
        actions.moveX = actions.moveX + 1
    end
    if input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) then
        actions.moveY = actions.moveY + 1
    end
    if input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) then
        actions.moveY = actions.moveY - 1
    end

    actions.jump   = input:GetKeyPress(KEY_SPACE)
    actions.attack = input:GetMouseButtonPress(MOUSEB_LEFT)
    actions.pause  = input:GetKeyPress(KEY_ESCAPE)

    return actions
end

return InputActions
```

---

## 4  Player Psychology

### Bartle Player Types

| Type | Driven By | Design For |
|------|-----------|------------|
| Achiever | Goals, completion, 100% | Collectibles, achievements, milestones |
| Explorer | Discovery, secrets, lore | Hidden areas, Easter eggs, world-building |
| Socializer | Interaction, community | Co-op, chat, leaderboards, sharing |
| Killer | Competition, dominance | PvP, rankings, high scores |

### Flow State — The Sweet Spot

```
Difficulty
    ^
    |   FRUSTRATION (too hard)
    |  ╱
    | ╱  ★ FLOW ZONE ★
    |╱
    +---BOREDOM (too easy)---→ Time/Skill
```

**Rules for flow:**
1. Challenge grows with player skill
2. Clear goals at every moment
3. Immediate feedback on every action
4. Player feels in control

### Reward Schedules

| Schedule | Pattern | Effect | Example |
|----------|---------|--------|---------|
| Fixed | Every N actions | Predictable, steady | +10 coins per enemy |
| Variable | Random chance | Addictive, exciting | Loot drops (5-20% chance) |
| Ratio | Scales with effort | Grinding incentive | XP = damage * combo |
| Interval | Time-based | Return engagement | Daily login rewards |

---

## 5  Difficulty & Progression

### Difficulty Curve Types

| Curve | Shape | Best For |
|-------|-------|----------|
| Linear | Steady ramp | Tutorial → Endgame |
| Staircase | Flat plateaus + jumps | Level-based games |
| Sawtooth | Spike → rest → spike | Boss-based games |
| Adaptive | Responds to player | Casual-friendly |

### Progression Systems

| Type | What Grows | Example |
|------|-----------|---------|
| Skill | Player ability | Muscle memory, pattern recognition |
| Power | Character stats | Level-ups, gear upgrades |
| Content | World access | New zones, story chapters |
| Social | Community standing | Leaderboards, titles |

### Difficulty Parameters (tunable)

```lua
local DifficultyConfig = {
    easy = {
        enemyHP     = 0.7,   -- multiplier
        enemyDamage = 0.5,
        enemySpeed  = 0.8,
        playerHP    = 1.5,
        dropRate    = 1.5,
        aimAssist   = true,
    },
    normal = {
        enemyHP = 1.0, enemyDamage = 1.0, enemySpeed = 1.0,
        playerHP = 1.0, dropRate = 1.0, aimAssist = false,
    },
    hard = {
        enemyHP = 1.5, enemyDamage = 1.5, enemySpeed = 1.2,
        playerHP = 0.8, dropRate = 0.7, aimAssist = false,
    },
}
```

---

## 6  Design Patterns Quick Reference

| Pattern | Use When | UrhoX Example |
|---------|----------|---------------|
| State Machine | 3-5 discrete states | Player: Idle→Walk→Jump→Attack |
| Observer/Events | Cross-system communication | `SubscribeToEvent("NodeCollision", ...)` |
| Command | Undo, replay, networking | Input recording, action queue |
| Object Pool | Frequent spawn/destroy | Bullets, particles, coins |
| Spatial Hash | Many collision checks | 2D grid-based lookup |
| Singleton | Global managers | GameManager, AudioManager |
| Strategy | Swappable algorithms | Enemy AI behaviors |
| Composite | Tree structures | UI hierarchies, scene graphs |

> **Decision rule:** Start with State Machine + Events. Add complexity only when needed.

---

## 7  Genre Quick-Start Templates

### Platformer Checklist

- [ ] Gravity + ground detection (Box2D or manual)
- [ ] Coyote time (jump grace period after leaving edge)
- [ ] Jump buffering (accept jump input slightly before landing)
- [ ] Variable jump height (hold = higher)
- [ ] Screen shake on landing/impact
- [ ] Parallax background layers
- [ ] Tilemap collision

### Shooter Checklist

- [ ] Weapon system (fire rate, ammo, reload)
- [ ] Projectile or hitscan
- [ ] Hit feedback (screen flash, enemy flash, knockback)
- [ ] Camera: FPS (`MM_RELATIVE`) or TPS (`ThirdPersonCamera`)
- [ ] Enemy spawning + wave system
- [ ] Health/shield system

### Puzzle Checklist

- [ ] Grid or freeform interaction
- [ ] Undo system (Command pattern)
- [ ] Win condition detection
- [ ] Hint system (progressive)
- [ ] Level progression (unlock next)
- [ ] Timer (optional pressure)

### Tower Defense Checklist

- [ ] Grid or path-based placement
- [ ] Enemy pathfinding (waypoints or A*)
- [ ] Tower targeting (nearest, strongest, first)
- [ ] Wave system (escalating difficulty)
- [ ] Economy (earn → spend → upgrade)
- [ ] Life system (enemies reaching goal)

---

## 8  Reference Files

| File | Content |
|------|---------|
| `references/2d-game-patterns.md` | Sprite animation, tilemaps, parallax, platformer feel, 2D camera, 2D physics tips |
| `references/3d-game-patterns.md` | Camera systems, lighting, shadows, collider selection, LOD, culling, shader guidance |
| `references/audio-and-polish.md` | Sound effect layering, spatial audio, adaptive music, game juice (shake/hitstop/particles/squash-stretch), screen transitions |

---

## Constraints (UrhoX-Specific)

1. **Unit = meter** — gravity is -9.81, character ~1.8m tall
2. **Y-up left-handed** — Y=up, Z=forward, X=right (same as Unity)
3. **Lua 1-based arrays** — `for i = 1, #items do`
4. **`math.random()`** for RNG — no external libraries
5. **`File` API** for persistence — `io` is sandboxed away
6. **`cjson`** for JSON — `require("cjson")`
7. **NanoVG** for custom 2D rendering — must use `NanoVGRender` event
8. **UI components** for HUD/menus — `require("urhox-libs/UI")`, not raw NanoVG
9. **`graphics:SetMode()` is disabled** — use `GetWidth()/GetHeight()/GetDPR()`
10. **Enums not numbers** — `MOUSEB_LEFT` not `0`, `KEY_SPACE` not `32`
11. **Build after every change** — always call the UrhoX MCP build tool
