# Game Testing Methodology for UrhoX Lua Games

Practical testing strategies for UrhoX Lua games.
No external test frameworks needed — all testing uses in-game verification.

---

## Testing Categories

### 1. Smoke Testing (First Run Verification)

Run immediately after any code change to catch obvious breakage.

**Checklist**:

```
□ Game starts without Lua errors in console
□ Main game scene loads and is visible
□ Player character (if any) spawns at correct position
□ Basic input responds (move, jump, click)
□ UI elements are visible and readable
□ No warnings about missing resources
□ Frame rate is acceptable (no obvious freezes)
```

**Automated smoke test pattern**:

```lua
-- Add to Start() during development
function SmokeTest()
    local passed = true
    local results = {}

    -- Test 1: Scene exists
    if scene_ == nil then
        results[#results + 1] = "FAIL: scene_ is nil"
        passed = false
    else
        results[#results + 1] = "PASS: scene exists"
    end

    -- Test 2: Camera exists
    local cam = scene_:GetChild("Camera", true)
    if cam == nil then
        results[#results + 1] = "FAIL: Camera node not found"
        passed = false
    else
        results[#results + 1] = "PASS: Camera exists"
    end

    -- Test 3: Player exists
    local player = scene_:GetChild("Player", true)
    if player == nil then
        results[#results + 1] = "FAIL: Player node not found"
        passed = false
    else
        results[#results + 1] = "PASS: Player exists at " .. player.position:ToString()
    end

    -- Report
    for _, r in ipairs(results) do
        log:Write(LOG_INFO, "[SMOKE] " .. r)
    end
    log:Write(LOG_INFO, "[SMOKE] Result: " .. (passed and "ALL PASSED" or "FAILURES DETECTED"))

    return passed
end
```

### 2. Gameplay Testing

Test actual game mechanics work correctly.

**Core mechanics checklist**:

```
Movement:
□ Character moves in all directions
□ Movement speed feels correct
□ Character stops when no input
□ Diagonal movement is not faster than cardinal
□ Movement works with both keyboard and touch

Combat/Interaction:
□ Actions trigger on correct input
□ Damage/score values are correct
□ Cooldowns/timers work properly
□ Feedback (visual/audio) plays on actions

Game Flow:
□ Start → gameplay transition works
□ Win condition triggers correctly
□ Lose condition triggers correctly
□ Restart resets all state properly
□ Pause/resume preserves state
```

**State reset verification**:

```lua
-- Critical test: verify RestartGame resets ALL state
function TestRestart()
    -- Set up known state
    score = 42
    gameOver = true
    enemies = {1, 2, 3}

    -- Restart
    RestartGame()

    -- Verify reset
    assert(score == 0, "Score not reset: " .. score)
    assert(gameOver == false, "gameOver not reset")
    assert(#enemies == 0, "Enemies not cleared: " .. #enemies)
    log:Write(LOG_INFO, "[TEST] RestartGame: PASSED")
end
```

### 3. Edge Case Testing

Test boundary conditions that players will inevitably trigger.

**Common edge cases**:

| Category | Edge Cases to Test |
|----------|--------------------|
| **Numeric** | Zero health, max score, negative values, very large numbers |
| **Arrays** | Empty list, single item, boundary indices (first/last) |
| **Timing** | Very fast input (spam clicking), very slow play, alt-tab during action |
| **Spatial** | Off-screen, at world boundaries, overlapping positions |
| **State** | Double-tap restart, pause during transition, input during loading |
| **Resources** | Missing textures (should fallback gracefully), missing sounds |

**Edge case test pattern**:

```lua
function TestEdgeCases()
    -- Test: empty enemy list doesn't crash
    enemies = {}
    local nearest = FindNearestEnemy(Vector3.ZERO)
    assert(nearest == nil, "Should return nil for empty list")

    -- Test: score doesn't go negative
    score = 0
    AddScore(-10)
    assert(score >= 0, "Score went negative: " .. score)

    -- Test: player at world boundary
    player.position = Vector3(9999, 0, 9999)
    HandleUpdate(nil, fakeEventData(0.016))
    -- Should not crash or produce NaN
    local pos = player.position
    assert(pos.x == pos.x, "Player position is NaN")  -- NaN ~= NaN

    log:Write(LOG_INFO, "[TEST] Edge cases: PASSED")
end
```

### 4. Visual/UI Testing

Verify visual elements display correctly.

**Checklist**:

```
Layout:
□ UI fits screen without clipping
□ Text is readable (not too small, not overlapping)
□ Buttons are large enough to tap (mobile: minimum 44x44 logical px)
□ No overlapping UI elements
□ UI adapts to different aspect ratios (test 16:9, 4:3, 9:16)

Visual Feedback:
□ Hit/damage effects are visible
□ Score changes are noticeable
□ State changes have clear visual indication
□ Animations play smoothly (no pops or jumps)

Performance Visual:
□ No visible Z-fighting (flickering surfaces)
□ No texture stretching or tiling artifacts
□ Particles don't accumulate infinitely
```

**Aspect ratio test helper**:

```lua
-- Log current screen info for verification
function LogScreenInfo()
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    log:Write(LOG_INFO, string.format(
        "[DISPLAY] Physical: %dx%d | DPR: %.1f | Logical: %dx%d | Ratio: %.2f",
        w, h, dpr, w/dpr, h/dpr, w/h
    ))
end
```

### 5. Performance Validation

Verify game runs within acceptable frame budgets.

```lua
-- Simple frame time monitor
local frameTimes = {}
local maxSamples = 60

function MonitorPerformance(dt)
    frameTimes[#frameTimes + 1] = dt
    if #frameTimes > maxSamples then
        table.remove(frameTimes, 1)
    end

    -- Calculate stats every second
    if #frameTimes == maxSamples then
        local sum = 0
        local maxDt = 0
        for _, t in ipairs(frameTimes) do
            sum = sum + t
            if t > maxDt then maxDt = t end
        end
        local avgDt = sum / #frameTimes
        local avgFps = 1.0 / avgDt
        local minFps = 1.0 / maxDt

        if avgFps < 30 then
            log:Write(LOG_WARNING, string.format(
                "[PERF] Low FPS\! avg=%.1f min=%.1f", avgFps, minFps))
        end
    end
end
```

**Performance red flags**:

| Symptom | Likely Cause | Investigation |
|---------|-------------|---------------|
| Steady low FPS | Too many draw calls or complex geometry | Check node count, use batching |
| Gradual FPS drop | Memory leak (objects not cleaned up) | Log node count over time |
| Periodic stutters | GC pauses or periodic heavy computation | Profile per-frame allocation |
| Sudden FPS drop | New entities spawned without pooling | Implement object pooling |

---

## Testing Workflow

### During Development

```
1. Write/modify code
2. Build (MCP build tool)
3. Run smoke test (does it start?)
4. Test the specific feature you changed
5. Quick edge case check
6. Move to next feature
```

### Before Delivery

```
1. Full smoke test
2. Complete gameplay walkthrough (start to finish)
3. Edge case sweep
4. Visual check on current screen size
5. Performance validation (stable 30+ FPS)
6. Clean up: remove debug logging, test helpers
```

### Bug Report Template

When documenting bugs found during testing:

```
## Bug: [Short Description]

**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected**: [What should happen]
**Actual**: [What actually happens]
**Frequency**: [Always / Sometimes / Once]
**Error Message**: [Full error text if any]

**Environment**:
- Screen: [resolution]
- Input: [keyboard/mouse/touch]

**Notes**: [Any additional observations]
```

---

## Assert Helper for UrhoX Lua

Since Lua's built-in `assert` gives minimal info, use an enhanced version:

```lua
function GameAssert(condition, message)
    if not condition then
        local info = debug.getinfo(2, "Sl")
        local location = info.source .. ":" .. info.currentline
        log:Write(LOG_ERROR, "[ASSERT FAILED] " .. location .. ": " .. (message or "assertion failed"))
        -- Optionally dump state
        DumpGameState("ASSERT_FAILURE")
        error(message or "assertion failed")
    end
end

-- Usage:
GameAssert(#enemies > 0, "No enemies to target")
GameAssert(score >= 0, "Score went negative: " .. score)
GameAssert(node ~= nil, "Player node is nil after scene load")
```
