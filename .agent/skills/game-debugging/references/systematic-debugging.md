# Systematic Debugging Methodology for UrhoX Lua Games

## Golden Rule

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Randomly changing code hoping to fix a bug wastes time and introduces new bugs.
Follow the structured process below every time.

---

## Phase 1: Root Cause Investigation

### Step 1.1: Read the Error Message Thoroughly

Every piece of information matters:

```
[Thu May 12 10:23:45 2026] ERROR: LuaScript: scripts/main.lua:147:
attempt to index a nil value (local 'enemy')
```

Extract:
- **File and line**: `scripts/main.lua:147`
- **Error type**: `attempt to index a nil value`
- **Variable**: `local 'enemy'`
- **Context**: Line 147 tries to access a property of `enemy`, but `enemy` is nil

### Step 1.2: Reproduce Reliably

Create a reliable reproduction sequence:

```lua
-- Document exact steps:
-- 1. Start game
-- 2. Wait for 3 enemies to spawn
-- 3. Kill the first enemy
-- 4. Crash occurs when second enemy tries to attack

-- Add reproduction helper:
function ReproduceBug()
    -- Force the exact game state that triggers the bug
    for i = 1, 3 do
        SpawnEnemy(Vector3(i * 2, 0, 5))
    end
    -- Kill first enemy
    enemies[1].health = 0
    HandleEnemyDeath(enemies[1])
    -- Trigger attack from second enemy
    enemies[2]:Attack(player)  -- Should crash here
end
```

**If bug is intermittent:**
- Add logging around suspected area
- Track execution count: `callCount = (callCount or 0) + 1`
- Log game state at each occurrence
- Look for timing-dependent patterns (frame rate, load order)

### Step 1.3: Examine Recent Changes

```
Questions to ask:
1. What was the last change before the bug appeared?
2. Did I add/remove any nodes or components?
3. Did I change any event subscriptions?
4. Did I modify any resource paths?
5. Did I change array iteration logic?
```

### Step 1.4: Trace Data Flow Backward

Start from the crash point and work backward:

```lua
-- Crash at line 147: enemy.node.position
-- Question: Where does 'enemy' come from?

-- Line 140: local enemy = enemies[targetIndex]
-- Question: What is targetIndex? Is it valid?

-- Line 135: targetIndex = FindNearestEnemy(player.position)
-- Question: Does FindNearestEnemy return a valid index?

-- Add logging at each step:
log:Write(LOG_DEBUG, "FindNearestEnemy returned: " .. tostring(targetIndex))
log:Write(LOG_DEBUG, "enemies table size: " .. #enemies)
log:Write(LOG_DEBUG, "enemy at index: " .. tostring(enemies[targetIndex]))
```

---

## Phase 2: Pattern Analysis

### Step 2.1: Classify the Bug

| Category | Characteristics | Common in UrhoX |
|----------|----------------|-----------------|
| **Data bug** | Wrong value, nil where expected | Uninitialized variables, wrong array index |
| **Logic bug** | Code runs but produces wrong result | Wrong condition, missing case |
| **Lifecycle bug** | Object used after destruction | Node removed but reference kept |
| **Timing bug** | Works sometimes, fails other times | Event ordering, frame-dependent |
| **Resource bug** | Asset not found or wrong | Path errors, missing files |
| **State bug** | Game enters invalid state | Missing state transition, stale data |

### Step 2.2: Check Known Bug Patterns

Cross-reference with `references/lua-bug-patterns.md` for common UrhoX Lua patterns.

### Step 2.3: Look for Similar Code

If a bug exists in one place, the same pattern may be wrong elsewhere:

```lua
-- If you find this bug:
for i = 0, #enemies do  -- BUG: starts at 0

-- Search for ALL similar loops:
-- grep "for.*= 0," scripts/*.lua
-- Fix ALL of them, not just the one that crashed
```

---

## Phase 3: Hypothesis Testing

### Strategy: Binary Search

When you cannot pinpoint the cause, divide and conquer:

```lua
-- Comment out half the Update code
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    UpdatePlayer(dt)
    UpdateCamera(dt)
    -- UpdateEnemies(dt)      -- commented out
    -- UpdateProjectiles(dt)  -- commented out
    -- UpdateUI(dt)           -- commented out
    -- CheckCollisions()      -- commented out
end

-- Bug gone? Problem is in the commented half.
-- Bug persists? Problem is in the active half.
-- Repeat until isolated to a single function.
```

### Strategy: Minimal Reproduction

Strip the game to minimum code that reproduces the bug:

```lua
-- Create a new minimal test file
function Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- Add ONLY what's needed to reproduce
    local node = scene_:CreateChild("TestNode")
    local body = node:CreateComponent("RigidBody2D")

    -- Does this alone cause the issue?
    -- If yes: engine-level issue
    -- If no: add more until bug appears
end
```

### Strategy: Rubber Duck Debugging

Explain the code line by line (to yourself or in comments):

```lua
-- "On each frame, I iterate through all enemies..."
for i = 1, #enemies do
    -- "I get the enemy at index i..."
    local enemy = enemies[i]
    -- "Wait - could enemies[i] be nil if an enemy was
    --  removed during this same loop iteration?"
    -- AHA\! That's the bug\!
end
```

### Strategy: State Snapshot

Log complete game state at the moment of failure:

```lua
function DumpGameState(label)
    log:Write(LOG_DEBUG, "=== STATE DUMP: " .. label .. " ===")
    log:Write(LOG_DEBUG, "Player pos: " .. player.position:ToString())
    log:Write(LOG_DEBUG, "Enemy count: " .. #enemies)
    for i, e in ipairs(enemies) do
        log:Write(LOG_DEBUG, string.format("  Enemy[%d]: hp=%d pos=%s",
            i, e.health, e.node.position:ToString()))
    end
    log:Write(LOG_DEBUG, "Game state: " .. tostring(gameState))
    log:Write(LOG_DEBUG, "=== END DUMP ===")
end
```

---

## Phase 4: Implementation & Verification

### Step 4.1: Fix the Root Cause

```lua
-- ❌ Symptom fix (hides the real problem):
if enemy ~= nil then
    enemy:Attack(player)
end

-- ✅ Root cause fix (prevents nil enemy from existing):
function RemoveEnemy(index)
    -- Remove from table properly
    enemies[index].node:Remove()
    table.remove(enemies, index)
    -- Update any indices that reference enemies after this index
    if targetIndex and targetIndex > index then
        targetIndex = targetIndex - 1
    end
end
```

### Step 4.2: Verify the Fix

```
Verification checklist:
□ Original bug no longer reproduces
□ Related functionality still works
□ Edge cases tested (empty list, single item, max items)
□ No new warnings in console
□ Game flow from start to end works
```

### Step 4.3: Clean Up

```lua
-- Remove ALL debug logging before final delivery:
-- Search for: log:Write(LOG_DEBUG, "DEBUG
-- Remove all temporary debugging code
-- Remove any commented-out code blocks used for binary search
```

### Step 4.4: Document the Pattern

If this bug could happen again, note the pattern:

```
Bug: Enemy nil reference after removal during iteration
Cause: table.remove shifts indices; loop continues with stale index
Fix: Iterate in reverse when removing, or collect removals and batch
Pattern: "Mutation during iteration"
```

---

## Debugging Checklist (Quick Reference)

Before starting any fix:

- [ ] I have the exact error message
- [ ] I can reproduce the bug reliably
- [ ] I have checked recent changes
- [ ] I have identified the category (data/logic/lifecycle/timing/resource/state)

Before implementing a fix:

- [ ] I have a specific hypothesis
- [ ] I have evidence supporting the hypothesis
- [ ] I am fixing the root cause, not a symptom

After implementing:

- [ ] Original bug is resolved
- [ ] No regressions introduced
- [ ] Debug logging removed
- [ ] Code is clean and well-structured
