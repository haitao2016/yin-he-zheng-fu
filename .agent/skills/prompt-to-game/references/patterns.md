# Prompt-to-Game Patterns for UrhoX Lua

## Pattern 1: Component-by-Component Building

Build games piece by piece, testing after each component.

**When to use**: Any game larger than a single-screen demo.

**Process**:
```
1. Generate minimal viable game (one mechanic) from scaffold
2. BUILD and test immediately
3. Add one feature via new code changes
4. BUILD and test again
5. Refactor when single file exceeds ~800 lines
6. Repeat until complete
```

**Example — Platformer sequence**:
```lua
-- Step 1: Player movement (from scaffold-2d-physics.lua)
-- Test: verify character moves with WASD/arrows
-- Step 2: Add jumping with spacebar
-- Test: verify physics and ground detection
-- Step 3: Add platforms and collectibles
-- Test: verify collision
-- Step 4: Add score counter via UI library
-- Test: verify HUD
```

**Why it works**: Catch issues immediately; maintain context coherence; easier debugging.

---

## Pattern 2: Reference Existing Games

Use well-known games as shorthand for mechanics when describing what to build.

**When to use**: When describing complex mechanics.

**Effective references**:
```
"做一个类似 Flappy Bird 但主角是火箭的游戏"
"做一个像水果忍者那样的3D切割游戏"
"加一个类似马里奥的双段跳，带土狼时间"
"做一个类似 Vampire Survivors 的弹幕生存游戏"
```

**Bad references** (too vague):
```
"做个像马里奥的游戏"  // 哪代马里奥？什么机制？
"做个好玩的射击游戏"   // 什么视角？什么风格？
```

**Why it works**: Communicates complex mechanics concisely; sets clear expectations.

---

## Pattern 3: Scaffold-First Development

Always start from the matching scaffold, never from blank file.

**Decision tree**:
```
Is it 2D?
  ├─ Has physics/collision? → scaffold-2d-physics.lua
  └─ Pure rendering (NanoVG)? → scaffold-2d.lua
Is it 3D?
  ├─ Has a controllable character? → scaffold-3d-character.lua
  └─ Scene exploration / visualization? → scaffold-3d-scene.lua
```

**After copying scaffold**:
1. Read all `-- TODO:` comments
2. Fill in `CreateGameContent()` with game-specific objects
3. Fill in `HandleUpdate()` with game logic
4. Add UI via `urhox-libs/UI` (not raw NanoVG unless custom graphics needed)

---

## Pattern 4: Reference Example Code

Before implementing a feature, check if a relevant example exists.

**Quick lookup**:
```
Flappy Bird mechanics     → examples/03-flappy-bird-game.lua
2D platformer physics     → examples/04-box2d-platformer.lua
Mario-style game          → examples/05-super-mario-game.lua
3D fruit cutting          → examples/12-fruit-ninja-3d-game.lua
UI widgets gallery        → examples/14-ui-widgets-gallery.lua
Inventory drag-drop       → examples/15-inventory-drag-drop.lua
3D physics collision      → examples/18-physics-collision-3d.lua
Modular architecture      → examples/07-minecraft-voxel-world/
TPS game                  → examples/22-third-person-shooter/
Cloud save / leaderboard  → examples/11-client-cloud-score-leaderboard-api.lua
```

**Rules**:
- Copy example → rename → customize (never deliver example as-is)
- At least one round of optimization: UI polish, config tuning, cleanup

---

## Pattern 5: Three-Prompt Workflow

Compress full game development into 3 focused iterations.

**When to use**: Game jams, quick prototypes, proof of concepts.

**Structure**:
```
Iteration 1 — Core gameplay loop:
  Scene setup + player + one core mechanic + basic objects
  → BUILD → Test → Fix critical issues only

Iteration 2 — Major feature addition:
  Scoring system OR level progression OR enemy AI OR power-ups
  → BUILD → Test → Fix critical issues only

Iteration 3 — Polish pass:
  UI (game over, restart, score display) + visual effects + sound
  → BUILD → Test → Final delivery
```

**Time allocation** (for a 2-hour jam):
- Iteration 1: 50% of time
- Iteration 2: 30% of time
- Iteration 3: 20% of time

---

## Pattern 6: Refactor at Threshold

Know when to stop adding features and restructure.

**Thresholds**:
```
Single file > 800 lines  → Extract modules
Nested conditionals > 3   → Extract functions
Duplicate code blocks > 2  → Create shared utility
```

**Refactoring prompt structure**:
```
Refactor into modules:
- main.lua: Entry point, scene setup, game loop
- player.lua: Player class, movement, input handling
- enemies.lua: Enemy spawning, AI, collision
- ui.lua: HUD, menus, game over screen
Use Lua require() for imports. Maintain all functionality.
```

---

## Pattern 7: Negative Constraints

Explicitly state what NOT to do when the AI keeps making unwanted choices.

**UrhoX-specific negative constraints**:
```
DO NOT:
- Use native UI (UIElement, Text, Button from Urho3D)
- Use magic numbers for input (0, 1, 2 instead of MOUSEB_LEFT, KEY_SPACE)
- Put code outside scripts/ directory
- Use io.open() or io.read() (sandbox removed io library)
- Call nvgCreateFont() every frame
- Skip the BUILD step
- Use array index 0

DO:
- Use urhox-libs/UI for all UI elements
- Use KEY_* and MOUSEB_* enums
- Use eventData["Key"]:GetType() for event data access
- Call MCP build tool after every change
- Use Lua 1-based indexing
```

---

## Pattern 8: Seed Lock and Document

Save working state after each successful iteration.

**Process**:
```
1. After BUILD succeeds and game plays correctly
2. Note what was added/changed in this iteration
3. If using git: commit with descriptive message
4. Before next change: ensure current state is recoverable
```

**Why it matters for UrhoX**:
- BUILD failures can be hard to diagnose
- Rolling back to last working state saves debugging time
- Each iteration should be independently functional
