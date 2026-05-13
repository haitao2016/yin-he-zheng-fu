# Genre Templates

Pre-designed numeric configurations for common game genres. Copy the constants block into your game and adjust as needed. All values use UrhoX units (meters, m/s, seconds).

## 1. 2D Side-Scroller / Platformer

**Scaffold**: `templates/scaffold-2d-physics.lua`

### Camera

- Fixed orthographic, looking at XY plane
- Smooth follow with damping
- Optional parallax background layers

### Constants

```lua
-- === PLATFORMER CONSTANTS ===

-- Physics
local GRAVITY          = Vector2(0, -25)    -- Snappier than real gravity (-9.81)
local JUMP_FORCE       = 12.0               -- Initial jump impulse (m/s)
local MOVE_SPEED       = 5.0                -- Horizontal speed (m/s)
local MAX_FALL_SPEED   = -15.0              -- Terminal velocity (m/s)

-- Game feel
local COYOTE_TIME      = 0.1                -- Seconds after ledge where jump still works
local JUMP_BUFFER      = 0.1                -- Seconds before landing where input queued
local CORNER_CORRECT   = 0.3                -- Forgiveness for near-miss edges (meters)

-- Level
local TILE_SIZE        = 1.0                -- World units per tile
local CAMERA_SMOOTH    = 5.0                -- Camera follow speed (higher = snappier)
```

### Common Pitfalls

- Gravity too low → floaty jumps, reduce fun
- No coyote time → edge jumps feel unfair
- Ground detection via raycast, not collision flags
- All collision shapes on same node as RigidBody2D

---

## 2. 2D Casual / Arcade

**Scaffold**: `templates/scaffold-2d.lua`

### Camera

- Static or slowly scrolling
- Orthographic projection

### Constants

```lua
-- === CASUAL ARCADE CONSTANTS ===

-- Scrolling
local SCROLL_SPEED     = 3.0                -- Base scroll speed (m/s)
local SPEED_INCREMENT  = 0.1                -- Speed increase per milestone
local MAX_SPEED        = 8.0                -- Speed cap (m/s)

-- Spawning
local SPAWN_INTERVAL   = 2.0                -- Seconds between obstacles
local MIN_SPAWN_INT    = 0.8                -- Minimum at max difficulty
local GAP_SIZE         = 3.0                -- Gap between obstacles (meters)

-- Player
local PLAYER_SPEED     = 5.0                -- Movement speed (m/s)
local INVULNERABLE_T   = 1.5                -- Invulnerability after hit (seconds)

-- Scoring
local BASE_SCORE       = 10                 -- Points per obstacle passed
local COMBO_MULT       = 1.5                -- Multiplier per consecutive success
local COMBO_TIMEOUT    = 2.0                -- Seconds before combo resets
```

### Common Pitfalls

- Difficulty ramps too fast → frustrating
- No speed cap → impossible at high scores
- Spawn randomness without minimum gap → unfair clustering

---

## 3. 3D Third-Person Action

**Scaffold**: `templates/scaffold-3d-character.lua`

### Camera

- Use `ThirdPersonCamera` library (NEVER calculate manually)
- Typical offset: `Vector3(0, 1.7, 0)` (eye height)

### Constants

```lua
-- === TPS ACTION CONSTANTS ===

-- Character movement
local MOVE_SPEED       = 5.0                -- Walk speed (m/s)
local SPRINT_SPEED     = 8.0                -- Sprint speed (m/s)
local JUMP_VELOCITY    = 7.0                -- Jump impulse (m/s)
local TURN_SPEED       = 15.0               -- Rotation speed (deg/frame factor)

-- Camera (ThirdPersonCamera config)
local CAM_DISTANCE     = 5.0                -- Behind character (meters)
local CAM_HEIGHT       = 1.7                -- Above character pivot (meters)
local CAM_FOV          = 45.0               -- Field of view (degrees)
local MOUSE_SENS       = 0.1                -- Mouse look speed

-- Combat (if applicable)
local ATTACK_RANGE     = 2.0                -- Melee reach (meters)
local ATTACK_COOLDOWN  = 0.5                -- Seconds between attacks
local HITSTOP_FRAMES   = 3                  -- Frames to pause on hit
local KNOCKBACK_FORCE  = 5.0                -- Knockback impulse (m/s)
```

### Common Pitfalls

- Camera clipping through walls → ThirdPersonCamera handles this
- Mouse mode must be `MM_RELATIVE`
- Character sliding on slopes → set slope limit in physics

---

## 4. 3D First-Person

**Scaffold**: `templates/scaffold-3d-scene.lua` (modified for FPS)

### Camera

- Camera on character node at eye height
- `input.mouseMode = MM_RELATIVE`

### Constants

```lua
-- === FPS CONSTANTS ===

-- Movement
local MOVE_SPEED       = 5.0                -- Walk speed (m/s)
local SPRINT_SPEED     = 8.0                -- Sprint speed (m/s)
local JUMP_VELOCITY    = 7.0                -- Jump impulse (m/s)
local MOUSE_SENS       = 0.1                -- Look speed
local PITCH_LIMIT      = 89.0               -- Prevent camera flip (degrees)

-- View
local EYE_HEIGHT       = 1.7                -- Camera height (meters)
local FOV              = 60.0               -- Field of view (degrees)
local HEADBOB_AMP      = 0.03               -- Head bobbing amplitude (meters)
local HEADBOB_FREQ     = 8.0                -- Head bobbing frequency (Hz)
```

---

## 5. Puzzle Game

**Scaffold**: `templates/scaffold-2d.lua` or `templates/scaffold-3d-scene.lua`

### Camera

- Fixed position, looking at puzzle area
- May zoom for different board sizes

### Constants

```lua
-- === PUZZLE CONSTANTS ===

-- Grid
local GRID_W           = 8                  -- Columns
local GRID_H           = 8                  -- Rows
local CELL_SIZE        = 1.0                -- World units per cell

-- Animation
local SWAP_DURATION    = 0.2                -- Piece swap time (seconds)
local MATCH_FLASHES    = 3                  -- Flash count before removal
local FALL_SPEED       = 8.0                -- Falling speed (cells/second)
local CLEAR_DELAY      = 0.15               -- Delay between cascade stages

-- Scoring
local SCORE_PER_MATCH  = 100                -- Base score
local COMBO_MULT       = 1.5                -- Per cascade combo
local BONUS_THRESHOLD  = 4                  -- Pieces for bonus (4+ match)
local BONUS_POINTS     = 50                 -- Extra points per bonus piece
```

---

## 6. Endless Runner

**Scaffold**: `templates/scaffold-2d.lua` (2D) or `templates/scaffold-3d-character.lua` (3D)

### Key Design

- Auto-scrolling world
- Core mechanic: obstacle avoidance
- Progressive difficulty via speed + density

### Constants

```lua
-- === ENDLESS RUNNER CONSTANTS ===

-- Speed progression
local BASE_SPEED       = 5.0                -- Starting scroll speed (m/s)
local MAX_SPEED        = 15.0               -- Speed cap (m/s)
local SPEED_RAMP       = 0.1                -- Increase per second

-- Lanes (3D runner)
local NUM_LANES        = 3
local LANE_WIDTH       = 2.0                -- Lane spacing (meters)
local LANE_SWITCH_SPD  = 10.0               -- Lane change speed (m/s)

-- Obstacles
local MIN_OBS_DIST     = 5.0                -- Minimum gap (meters)
local OBS_TYPES        = {"low", "high", "left", "right"}
local SECTION_LENGTH   = 20.0               -- Procedural section length (meters)

-- Collectibles
local COIN_VALUE       = 1
local MAGNET_RANGE     = 3.0                -- Auto-collect radius (meters)
local MAGNET_DURATION  = 5.0                -- Power-up duration (seconds)
```

---

## 7. Tower Defense

**Scaffold**: `templates/scaffold-2d.lua` (top-down) or `templates/scaffold-3d-scene.lua`

### Camera

- Top-down or isometric view
- Pan/zoom controls

### Constants

```lua
-- === TOWER DEFENSE CONSTANTS ===

-- Grid
local MAP_W            = 16                 -- Grid columns
local MAP_H            = 12                 -- Grid rows
local CELL_SIZE        = 1.0                -- World units per cell

-- Enemies
local ENEMY_BASE_HP    = 100                -- Wave 1 health
local ENEMY_HP_SCALE   = 1.15               -- HP multiplier per wave
local ENEMY_SPEED      = 2.0                -- Base speed (m/s)
local WAVE_INTERVAL    = 15.0               -- Seconds between waves
local ENEMIES_PER_WAVE = 10                 -- Base count (scales with wave)
local SPAWN_DELAY      = 0.5                -- Seconds between spawns in wave

-- Towers
local TOWER_COSTS      = {100, 200, 350, 500}   -- Per tower type
local TOWER_RANGES     = {3.0, 4.0, 2.5, 5.0}   -- Attack range (meters)
local TOWER_DAMAGE     = {25, 15, 50, 10}        -- Damage per hit
local TOWER_FIRE_RATE  = {1.0, 0.5, 2.0, 0.3}   -- Seconds between shots

-- Economy
local START_GOLD       = 500
local KILL_REWARD      = 20                 -- Gold per enemy killed
local INTEREST_RATE    = 0.05               -- Gold interest per wave (5%)
local LIVES            = 20                 -- Lives before game over
```

## Usage Pattern

```lua
-- 1. Copy the constants block for your genre
-- 2. Paste at the top of main.lua
-- 3. Use the named constants throughout your code
-- 4. Adjust values after playtesting

-- Example: platformer jump
if jumpPressed and (isGrounded or coyoteTimer > 0) then
    body:ApplyLinearImpulse(Vector2(0, JUMP_FORCE), true)
    coyoteTimer = 0
end
```
