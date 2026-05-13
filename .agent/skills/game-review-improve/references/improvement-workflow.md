# Structured Improvement Workflow for UrhoX Lua Games

How to systematically add features and improvements without breaking existing functionality.

---

## Improvement Implementation Rules

### Rule 1: Don't Break What Works

Improvements are **additive**. Never modify:
- Physics values (gravity, velocity, collision)
- Scoring logic (point values, conditions)
- Input handling (control mappings)
- Win/lose conditions
- Core game flow

```lua
-- ❌ WRONG: Changing existing physics to add screen shake
body.mass = body.mass * shakeMultiplier  -- Don't touch physics\!

-- ✅ RIGHT: Screen shake is purely visual (camera offset)
cameraNode.position = baseCameraPos + shakeOffset  -- Camera only
```

### Rule 2: Configuration Over Hardcoding

Every tuning value goes in a config table:

```lua
-- ✅ Good: all values configurable
local CONFIG = {
    SHAKE_INTENSITY = 0.5,
    SHAKE_DECAY = 2.0,
    PARTICLE_COUNT = 12,
    PARTICLE_SPEED = 120,
    FLASH_DURATION = 0.1,
    FLOATING_TEXT_SPEED = 60,
    FLOATING_TEXT_DURATION = 0.8,
    FADE_SPEED = 3.0,
    ENTRANCE_DURATION = 0.4,
    ENTRANCE_OVERSHOOT = 1.7,
}

-- ❌ Bad: magic numbers scattered in code
local speed = 120  -- what is this? where do I tune it?
```

### Rule 3: Clean Up What You Add

Every effect, timer, and subscription must have cleanup:

```lua
-- Pattern: track everything for cleanup
local activeEffects = {}

function AddEffect(effect)
    activeEffects[#activeEffects + 1] = effect
end

function CleanupEffects()
    for _, effect in ipairs(activeEffects) do
        if effect.node then
            effect.node:Remove()
        end
    end
    activeEffects = {}
end

-- Call CleanupEffects() on restart
```

### Rule 4: Build After Each Change

After implementing each improvement:

```
1. Save the file
2. Call MCP build tool
3. If build fails, fix immediately before moving on
4. If build succeeds, verify the change works
5. Then move to next improvement
```

---

## Feature Addition Workflow

When adding a new gameplay feature (not just polish):

### Step 1: Understand What Exists

```
Read ALL game files:
□ main.lua — entry point, scene setup
□ All game modules — how gameplay works
□ State management — where game state lives
□ Event handling — how systems communicate
```

### Step 2: Plan the Feature

Before writing code:

```
1. What does it do? (player perspective)
2. What new state is needed?
3. What new events are needed?
4. Which existing files need changes?
5. Any new files to create?
```

### Step 3: Implement in Order

```
1. State first — add new state variables with proper defaults
2. Logic next — implement the core mechanic
3. Feedback last — add visual/audio feedback for the feature
4. Wire everything — connect to existing systems
```

### Step 4: Verify Integration

```
□ New feature works as described
□ Existing gameplay unchanged
□ Restart still works cleanly (3x test)
□ No Lua errors in console
□ Performance acceptable
```

---

## Iterative Improvement Strategy

### First Pass: Foundation

Fix the most impactful, easiest improvements:

```
Priority:
1. Fix any crashes or broken flows
2. Ensure restart works cleanly
3. Add missing game over / restart flow
4. Basic visual polish (background, colors)
```

### Second Pass: Feel

Add juice and feedback:

```
Priority:
1. Screen shake on key events
2. Floating score text
3. Particle effects on destruction
4. Scale pop on collection
5. Sound effects for actions
```

### Third Pass: Polish

Refine and finalize:

```
Priority:
1. Smooth transitions between states
2. Entity entrance/exit animations
3. Difficulty progression
4. Score tracking (best score)
5. Code cleanup and optimization
```

---

## Common Improvement Patterns

### Adding Difficulty Progression

```lua
-- Difficulty scales with score or time
local difficultyConfig = {
    BASE_SPEED = 3.0,
    SPEED_INCREMENT = 0.2,     -- per difficulty level
    DIFFICULTY_INTERVAL = 10,  -- points per difficulty increase
    MAX_DIFFICULTY = 10,
}

function GetDifficulty()
    return math.min(difficultyConfig.MAX_DIFFICULTY,
        math.floor(score / difficultyConfig.DIFFICULTY_INTERVAL))
end

function GetCurrentSpeed()
    return difficultyConfig.BASE_SPEED +
        GetDifficulty() * difficultyConfig.SPEED_INCREMENT
end
```

### Adding Best Score Tracking

```lua
-- Using File API for persistent storage
local bestScore = 0

function LoadBestScore()
    local file = File:new(
        "best_score.json", FILE_READ
    )
    if file:IsOpen() then
        local data = file:ReadString()
        file:Close()
        local decoded = cjson.decode(data)
        if decoded and decoded.bestScore then
            bestScore = decoded.bestScore
        end
    end
end

function SaveBestScore()
    if score > bestScore then
        bestScore = score
        local file = File:new(
            "best_score.json", FILE_WRITE
        )
        if file:IsOpen() then
            file:WriteString(cjson.encode({ bestScore = bestScore }))
            file:Close()
        end
    end
end

-- Call LoadBestScore() in Start()
-- Call SaveBestScore() on game over
```

### Adding Combo System

```lua
local comboConfig = {
    COMBO_WINDOW = 2.0,     -- seconds to maintain combo
    COMBO_MULTIPLIER = 0.5, -- bonus per combo level
    MAX_COMBO = 10,
}

local combo = 0
local comboTimer = 0

function AddComboHit()
    combo = math.min(comboConfig.MAX_COMBO, combo + 1)
    comboTimer = comboConfig.COMBO_WINDOW
    return 1 + combo * comboConfig.COMBO_MULTIPLIER  -- score multiplier
end

function UpdateCombo(dt)
    if comboTimer > 0 then
        comboTimer = comboTimer - dt
        if comboTimer <= 0 then
            combo = 0
        end
    end
end

-- Reset in restart:
function ResetCombo()
    combo = 0
    comboTimer = 0
end
```

### Adding Simple Power-Up System

```lua
local powerUpConfig = {
    SPAWN_INTERVAL = 15.0,  -- seconds between spawns
    DURATION = 5.0,         -- how long power-up lasts
    TYPES = {
        speed = { multiplier = 2.0, color = Color(0, 1, 0) },
        shield = { multiplier = 1.0, color = Color(0, 0.5, 1) },
        magnet = { multiplier = 1.0, color = Color(1, 1, 0) },
    }
}

local activePowerUp = nil
local powerUpTimer = 0

function ActivatePowerUp(type)
    activePowerUp = {
        type = type,
        config = powerUpConfig.TYPES[type],
        remaining = powerUpConfig.DURATION,
    }
    -- Visual feedback
    AddScreenShake(0.2)
    AddFloatingText(playerX, playerY, string.upper(type) .. "\!", nil)
end

function UpdatePowerUp(dt)
    if activePowerUp then
        activePowerUp.remaining = activePowerUp.remaining - dt
        if activePowerUp.remaining <= 0 then
            activePowerUp = nil
        end
    end
end

function HasPowerUp(type)
    return activePowerUp and activePowerUp.type == type
end
```

---

## Measuring Improvement

### Before/After Score Comparison

Always track the audit score before and after improvements:

```
Before: 28/50
After:  41/50 (+13 points)

Areas improved:
- Visual Polish: 2 → 4 (+2)
- Game Feel: 1 → 4 (+3)
- Game Flow: 3 → 5 (+2)
- UI Quality: 2 → 4 (+2)
- Audio: 1 → 3 (+2)
- Restart Safety: 3 → 5 (+2)
```

### Quality Tiers

| Score | Tier | Status |
|-------|------|--------|
| 0-15 | Prototype | Needs fundamental work |
| 16-25 | Alpha | Core works, needs polish |
| 26-35 | Beta | Playable, needs refinement |
| 36-45 | Release Candidate | Good quality, minor tweaks |
| 46-50 | Polished | Ship-ready |

---

## When to Stop Improving

Not every game needs to reach 50/50. Stop when:

1. **Core loop is fun** — the fundamental gameplay is satisfying
2. **No crashes** — stable through full play sessions
3. **Clean restarts** — 3x restart test passes
4. **Basic polish** — screen shake, feedback, transitions exist
5. **User is satisfied** — the game meets the user's goals

Perfectionism is the enemy of shipping. A fun 35/50 game is better than an unshipped 50/50 game.
