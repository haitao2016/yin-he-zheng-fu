# Performance Reference

## Table of Contents
1. [Profiling — Locate the Bottleneck](#1-profiling--locate-the-bottleneck)
2. [GPU Optimization](#2-gpu-optimization)
3. [Thermal & Battery Management](#3-thermal--battery-management)
4. [Memory Management](#4-memory-management)
5. [Lua CPU Optimization](#5-lua-cpu-optimization)
6. [Startup Optimization](#6-startup-optimization)
7. [Touch Input Latency](#7-touch-input-latency)
8. [App Lifecycle Patterns](#8-app-lifecycle-patterns)

---

## 1  Profiling — Locate the Bottleneck

**Rule**: Never optimize blindly. Measure first, fix the measured bottleneck, measure again.

### Frame Time Budget (60 fps = 16.7 ms total)
```
GPU render       ≤ 8 ms
Lua Update()     ≤ 4 ms
Physics step     ≤ 2 ms
Audio            ≤ 1 ms
Overhead         ≤ 1.7 ms
```

### Built-in UrhoX Profiler
```lua
-- Enable in Start():
engine:SetMaxFps(60)        -- cap to target FPS, prevents thermal runaway

-- Print renderer stats each second:
local statsTimer_ = 0
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    statsTimer_ = statsTimer_ + dt
    if statsTimer_ >= 1.0 then
        statsTimer_ = 0
        local stats = renderer:GetFrameInfo()
        print(string.format(
            "[Perf] FPS:%d  Batches:%d  Triangles:%d  Lights:%d",
            math.floor(1/dt),
            stats.numBatches,
            stats.numPrimitives,
            stats.numShadowMaps
        ))
    end
end
```

### Identify Bottleneck Type
| Symptom | Likely Cause | Section to Read |
|---------|-------------|-----------------|
| FPS drops when many objects on screen | Too many draw calls | §GPU |
| FPS drops only after 5-10 min play | Thermal throttling | §Thermal |
| FPS drops with many particles/lights | GPU fill-rate bound | §GPU |
| FPS drops in Lua-heavy code (AI, physics callbacks) | CPU / Lua bound | §Lua CPU |
| Memory warning then crash | Memory leak or spike | §Memory |
| Slow level load | Asset loading on main thread | §Startup |

---

## 2  GPU Optimization

### Draw Call Reduction

**Target: ≤ 100 draw calls per frame on mobile**

```lua
-- 1. Static batching: group non-moving objects under one parent node
local group = scene_:CreateChild("StaticGroup")
group:SetStaticModel(...)   -- engine auto-batches children

-- 2. Use instancing for repeated objects (grass, trees, enemies)
-- Set same material on all instances — engine batches them automatically

-- 3. Merge materials: fewer unique materials = fewer draw calls
-- Bad:  100 boxes each with unique material = 100 draw calls
-- Good: 100 boxes sharing one material = 1 draw call

-- 4. Check draw call count each frame:
print("Draw calls: " .. renderer:GetNumBatches())
```

### Texture Optimization
```lua
-- Power-of-2 dimensions ONLY: 256, 512, 1024, 2048
-- Never: 300x400, 600x800 (wastes GPU memory, breaks mipmapping)

-- Texture compression (set in material XML or at build time):
-- Android: ETC2 (all modern devices support it)
-- iOS:     PVRTC or ASTC
-- Format choice in material:
--   <texture unit="diffuse" name="Textures/hero.dds" />  -- compressed

-- Mipmap: always enable for 3D objects, disable for UI sprites
```

### Lighting Budget
```lua
-- Directional lights: max 1 (the sun/main light)
-- Point lights: max 4 per frame on mobile
-- No real-time shadows on mobile (bake them instead)
local light = node:CreateComponent("Light")
light.lightType   = LIGHT_DIRECTIONAL
light.castShadows = false   -- MUST be false on low-end mobile
```

### NanoVG GPU Cost
```lua
-- Each nvgBeginPath / nvgFill = 1 draw call
-- Group paths: draw all UI elements in ONE HandleNVGRender call
-- Avoid nvgSave/nvgRestore loops with heavy path counts

-- Cache paths that don't change frame-to-frame:
-- Draw background once to an offscreen texture, blit each frame
-- (Advanced: use nvgCreateImageFromHandle with RenderTexture)
```

---

## 3  Thermal & Battery Management

### Root Causes
| Cause | Fix |
|-------|-----|
| Uncapped frame rate | `engine:SetMaxFps(60)` — default is unlimited\! |
| Physics running at full rate when not needed | Pause physics when not visible |
| Audio sources not stopped | Call `src:Stop()` when SFX node is removed |
| Background network polling | Increase poll interval; pause when app is backgrounded |
| Particle systems running off-screen | Disable emitter when outside camera frustum |

### FPS Cap (Critical for Mobile)
```lua
function Start()
    -- Cap at 60 fps — prevents CPU/GPU from running full throttle
    engine:SetMaxFps(60)

    -- On low-end devices, target 30 fps for better thermal:
    -- engine:SetMaxFps(30)
end
```

### Adaptive Quality
```lua
-- Reduce quality automatically when device is thermal-throttling:
local lowQualityMode_ = false
local fpsDropTimer_   = 0

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    if dt > 0.033 and not lowQualityMode_ then  -- below 30 fps
        fpsDropTimer_ = fpsDropTimer_ + dt
        if fpsDropTimer_ > 2.0 then  -- sustained for 2 seconds
            enableLowQualityMode()
        end
    else
        fpsDropTimer_ = 0
    end
end

local function enableLowQualityMode()
    lowQualityMode_ = true
    renderer:SetShadowMapSize(512)         -- reduce shadow quality
    renderer:SetDrawShadows(false)         -- disable shadows entirely
    engine:SetMaxFps(30)                   -- drop target to 30 fps
    print("[Perf] Low quality mode activated")
end
```

### Battery-Friendly Background Behavior
```lua
function HandlePause(eventType, eventData)
    engine:SetMaxFps(5)    -- nearly stop rendering while backgrounded
    physics:SetFps(0)      -- pause physics
end

function HandleResume(eventType, eventData)
    engine:SetMaxFps(60)   -- restore normal rate
    physics:SetFps(60)
end
```

---

## 4  Memory Management

### Memory Budget (Mobile)
| Category | Low-end (1 GB RAM) | Mid-range (3 GB) |
|----------|-------------------|-----------------|
| Textures | ≤ 64 MB | ≤ 128 MB |
| Audio | ≤ 16 MB | ≤ 32 MB |
| Scripts/Logic | ≤ 8 MB | ≤ 16 MB |
| Total headroom | 150 MB | 300 MB |

### Common Memory Leaks in UrhoX Lua
```lua
-- LEAK 1: SFX nodes never removed
-- BAD:
local node = scene_:CreateChild("SFX")
local src = node:CreateComponent("SoundSource")
src:Play(snd)
-- node lives forever\!

-- GOOD: use REMOVE_NODE
src.autoRemoveMode = REMOVE_NODE   -- node auto-removes when sound ends

-- LEAK 2: NanoVG images created every frame
-- BAD (in HandleUpdate or HandleNVGRender):
local img = nvgCreateImage(vg_, "Textures/icon.png", 0)  -- leaks every frame\!

-- GOOD: create once in Start()
local iconImg_
function Start()
    iconImg_ = nvgCreateImage(vg_, "Textures/icon.png", 0)
end

-- LEAK 3: Subscriptions on removed nodes
-- After node:Remove(), unsubscribe all events first:
UnsubscribeFromAllEvents()  -- or UnsubscribeFromEvent(node, "...")
node:Remove()
```

### Object Pool Pattern
```lua
-- Reuse nodes instead of creating/destroying (bullets, particles, enemies)
local bulletPool_ = {}

local function acquireBullet()
    if #bulletPool_ > 0 then
        local b = table.remove(bulletPool_)
        b.node.enabled = true
        return b
    end
    return createBullet()   -- only allocates when pool is empty
end

local function releaseBullet(b)
    b.node.enabled = false
    bulletPool_[#bulletPool_ + 1] = b
end
```

### Cache Management
```lua
-- Release unused resources when changing levels:
cache:ReleaseAllResources(false)   -- false = keep referenced resources

-- Release a specific resource manually:
cache:ReleaseResource("Texture2D", "Textures/level1_bg.png", true)
```

---

## 5  Lua CPU Optimization

### Expensive Patterns to Avoid
```lua
-- BAD: string concatenation in Update loop (creates garbage each frame)
local debugText = "Score: " .. score .. "  Lives: " .. lives  -- every frame\!

-- GOOD: only update label when value changes
if score ~= lastScore_ then
    scoreLabel:SetText("Score: " .. score)
    lastScore_ = score
end

-- BAD: table.insert in hot path (allocation)
local hits = {}
for _, e in ipairs(enemies) do
    if touching(player, e) then
        table.insert(hits, e)   -- allocation every call
    end
end

-- GOOD: reuse a pre-allocated table
local hits_ = {}   -- module-level, reused
local function getHits()
    local n = 0
    for _, e in ipairs(enemies) do
        if touching(player, e) then
            n = n + 1; hits_[n] = e
        end
    end
    return hits_, n
end

-- BAD: math.sqrt in distance checks (expensive)
local dist = math.sqrt(dx*dx + dy*dy)
if dist < radius then ...end

-- GOOD: compare squared distances
local dist2 = dx*dx + dy*dy
if dist2 < radius*radius then ...end
```

### Update Frequency Throttling
```lua
-- Not everything needs to run every frame:
local aiTimer_     = 0
local AI_INTERVAL  = 0.1   -- run AI 10× per second, not 60×

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")

    -- Critical (every frame): player input, camera, animation
    updatePlayer(dt)
    updateCamera(dt)

    -- Non-critical (throttled): AI, leaderboard refresh, UI updates
    aiTimer_ = aiTimer_ + dt
    if aiTimer_ >= AI_INTERVAL then
        aiTimer_ = 0
        updateEnemyAI()
    end
end
```

---

## 6  Startup Optimization

### Load Order Strategy
```lua
function Start()
    -- Phase 1 (synchronous, must complete before first frame):
    --   - Create scene + camera + viewport
    --   - Load tiny placeholder assets (loading screen texture)
    --   - Show loading screen

    -- Phase 2 (async, while showing loading screen):
    cache:BackgroundLoadResource("Texture2D", "Textures/level1_bg.png", false, nil)
    cache:BackgroundLoadResource("Model",     "Models/player.mdl",      false, nil)

    -- Phase 3 (after phase 2 done):
    --   - Instantiate game objects
    --   - Start gameplay

    SubscribeToEvent("AsyncLoadFinished", "HandleLoadDone")
end

function HandleLoadDone(eventType, eventData)
    -- All background resources ready — build the scene
    buildLevel()
    hideLoadingScreen()
end
```

### 5-Second FTUE Rule
```
< 1 s: Show first pixel (loading screen or splash)
< 3 s: Show interactive element (tap to continue, or auto-proceed)
< 5 s: Player is in game and can act
> 5 s: Unacceptable — audit which assets block the main thread
```

### Asset Load Time Audit
```lua
-- Measure how long each heavy asset takes:
local t0 = time:GetElapsedTime()
local tex = cache:GetResource("Texture2D", "Textures/big_atlas.png")
print(string.format("[Load] big_atlas: %.1f ms",
    (time:GetElapsedTime() - t0) * 1000))
```

---

## 7  Touch Input Latency

### Lowest-Latency Input Pattern
```lua
-- Poll touches in Update() — lower latency than event callbacks
function HandleUpdate(eventType, eventData)
    local n = input:GetNumTouches()
    for i = 0, n - 1 do
        local t = input:GetTouch(i)
        if t.delta.x ~= 0 or t.delta.y ~= 0 then
            local dpr = graphics:GetDPR()
            local lx = t.position.x / dpr
            local ly = t.position.y / dpr
            handleTouchMove(t.touchID, lx, ly)
        end
    end
end
```

### Hit Area Sizing
```lua
-- Minimum 44×44 logical pixels per Apple HIG / Google Material
-- Finger hotspot is offset UP from visual center — account for this:
local TAP_OFFSET_Y = -8   -- shift hit box up 8px for natural thumb use

local function addHit(cx, cy, w, h, fn)
    -- Expand hit area beyond visual bounds
    local hitW = math.max(w, 44)
    local hitH = math.max(h, 44)
    local hitX = cx - hitW * 0.5
    local hitY = cy - hitH * 0.5 + TAP_OFFSET_Y
    hitAreas_[#hitAreas_ + 1] = { x=hitX, y=hitY, w=hitW, h=hitH, fn=fn }
end
```

### Gesture Recognition
```lua
-- Swipe: require minimum distance + maximum time
local SWIPE_MIN_PX  = 30   -- logical pixels
local SWIPE_MAX_SEC = 0.4  -- seconds

local touchStart_ = {}  -- { [id] = {x, y, time} }

SubscribeToEvent("TouchBegin", function(et, ed)
    local id = ed:GetInt("TouchID")
    local dpr = graphics:GetDPR()
    touchStart_[id] = {
        x = ed:GetInt("X") / dpr,
        y = ed:GetInt("Y") / dpr,
        t = time:GetElapsedTime()
    }
end)

SubscribeToEvent("TouchEnd", function(et, ed)
    local id = ed:GetInt("TouchID")
    local s  = touchStart_[id]
    if not s then return end
    local dpr = graphics:GetDPR()
    local ex = ed:GetInt("X") / dpr
    local ey = ed:GetInt("Y") / dpr
    local dt = time:GetElapsedTime() - s.t
    local dx = ex - s.x
    local dy = ey - s.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist >= SWIPE_MIN_PX and dt <= SWIPE_MAX_SEC then
        if math.abs(dx) > math.abs(dy) then
            onSwipe(dx > 0 and "right" or "left")
        else
            onSwipe(dy > 0 and "down" or "up")
        end
    end
    touchStart_[id] = nil
end)
```

---

## 8  App Lifecycle Patterns

### Required Subscriptions
```lua
function Start()
    SubscribeToEvent("ApplicationPaused",  "HandleAppPause")
    SubscribeToEvent("ApplicationResumed", "HandleAppResume")
end
```

### Save State on Pause
```lua
function HandleAppPause(eventType, eventData)
    -- Write game state synchronously — device may not call Resume
    local data = {
        score     = score_,
        level     = currentLevel_,
        playerPos = { x = playerNode_.position.x, y = playerNode_.position.y },
        timestamp = os.time(),
    }
    local file = File:new(fileSystem:GetUserDocumentsDir() .. "save.json", FILE_WRITE)
    if file:IsOpen() then
        local json = require("cjson")
        file:WriteString(json.encode(data))
        file:Close()
    end
    Audio.PauseAll()
end
```

### Restore State on Resume
```lua
function HandleAppResume(eventType, eventData)
    Audio.ResumeAll()
    -- Optional: show "Paused" overlay
    showPauseOverlay()
end
```

### Cold Start vs Warm Resume
```lua
-- On Start(), check if a saved state exists from last session:
local function hasSaveFile()
    return fileSystem:FileExists(fileSystem:GetUserDocumentsDir() .. "save.json")
end

function Start()
    if hasSaveFile() then
        loadSavedState()   -- resume where player left off
    else
        startNewGame()     -- fresh start
    end
end
```
