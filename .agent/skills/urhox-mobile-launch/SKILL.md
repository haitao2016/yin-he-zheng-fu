---
name: urhox-mobile-launch
description: "UrhoX mobile game launch expert: diagnose and fix performance on low-end Android/iOS devices, optimize touch input responsiveness (60-120Hz), reduce battery drain and thermal throttling, tune fast launch (FTUE under 5 seconds), handle app lifecycle (suspend/resume/save state), profile memory and GPU draw calls, and prepare TapTap release builds. Use when users need to (1) game runs slow or drops frames on mobile, (2) battery drains too fast or device heats up, (3) touch controls feel laggy or unresponsive, (4) game takes too long to load, (5) game crashes after suspend/resume, (6) prepare for TapTap store submission, (7) pass TapTap review requirements, (8) user says '卡顿', '发热', '耗电', '加载慢', '闪退', '触摸延迟', '发布', '上架', 'performance', 'launch', 'mobile'."
license: MIT
metadata:
  version: "1.0.0"
  author: "UrhoX Dev Team"
  tags: ["mobile", "performance", "launch", "taptap", "android", "ios", "optimization", "urhox"]
---

# UrhoX Mobile Launch Expert

Diagnose and fix the six most common mobile launch blockers — before submission, not after rejection.

## Six Launch Blockers

| Blocker | Symptom | Reference |
|---------|---------|-----------|
| Frame rate drop | FPS < 30, visible stutter | `references/performance.md` §GPU |
| Battery / thermal | Device heats up, throttles after 5 min | `references/performance.md` §Thermal |
| Touch latency | Controls feel "floaty" or delayed | `references/performance.md` §Touch |
| Slow startup | Splash > 5 s, FTUE drop-off | `references/performance.md` §Startup |
| Lifecycle crash | Crash on phone call / lock screen | `references/performance.md` §Lifecycle |
| Store rejection | Missing assets, wrong orientation | `references/publishing-checklist.md` |

Read the matching reference section(s) before answering.

---

## Quick Diagnosis Workflow

```
User reports problem
       ↓
1. Ask: "What device? Android or iOS?"
2. Ask: "When does it happen? Always / after N minutes / on specific action?"
3. Add frame-time log (see performance.md §Profiling)
4. Identify bottleneck from log
5. Apply targeted fix
6. Verify with build + QR test
```

---

## UrhoX Performance Budget (Mobile Targets)

| Metric | Target | Hard Limit |
|--------|--------|-----------|
| Frame time | ≤ 16.7 ms (60 fps) | 33 ms (30 fps) |
| Draw calls per frame | ≤ 100 | 200 |
| Active nodes in scene | ≤ 2000 | 5000 |
| Textures in memory | ≤ 128 MB | 256 MB |
| Startup time (cold) | ≤ 3 s | 5 s |
| Lua Update() time | ≤ 4 ms | 8 ms |

---

## Frame Time Logger (Add in Development)

```lua
local fpsDisplay_ = { samples = {}, sum = 0, max = 24 }

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    -- Rolling average over 24 frames
    if #fpsDisplay_.samples >= fpsDisplay_.max then
        fpsDisplay_.sum = fpsDisplay_.sum - table.remove(fpsDisplay_.samples, 1)
    end
    fpsDisplay_.samples[#fpsDisplay_.samples + 1] = dt
    fpsDisplay_.sum = fpsDisplay_.sum + dt

    local avgMs = (fpsDisplay_.sum / #fpsDisplay_.samples) * 1000
    local fps   = 1000 / avgMs
    -- Print only when fps drops below threshold:
    if fps < 45 then
        print(string.format("[PERF] FPS %.1f  frame %.2f ms", fps, avgMs))
    end
end
```

---

## App Lifecycle Events

```lua
-- Subscribe in Start() — handle all lifecycle transitions
SubscribeToEvent("ApplicationPaused",  "HandlePause")
SubscribeToEvent("ApplicationResumed", "HandleResume")

function HandlePause(eventType, eventData)
    -- Called when: phone call, lock screen, home button, notification
    saveGame()               -- write state to file immediately
    Audio.PauseAll()         -- stop all audio
    if bgmSource_ then bgmSource_:Stop() end
    print("[Lifecycle] Paused — state saved")
end

function HandleResume(eventType, eventData)
    -- Called when player returns to game
    Audio.ResumeAll()
    print("[Lifecycle] Resumed")
end
```

> **Critical**: UrhoX may not call Resume after a long suspend on low-memory devices. Always save on Pause, never rely on Resume.

---

## Touch Input Rules

```lua
-- Use logical pixels (divide by DPR) for all hit detection
local function screenToLogical(sx, sy)
    local dpr = graphics:GetDPR()
    return sx / dpr, sy / dpr
end

-- Minimum tap target: 44×44 logical pixels (Apple HIG / Material Design)
local MIN_TAP_SIZE = 44

-- Swipe detection: require minimum distance to avoid mis-fires
local SWIPE_MIN_DIST = 20   -- logical pixels

-- Input polling: read in Update, not in touch events, for lowest latency
function HandleUpdate(eventType, eventData)
    local numTouches = input:GetNumTouches()
    for i = 0, numTouches - 1 do
        local touch = input:GetTouch(i)
        local lx, ly = screenToLogical(touch.position.x, touch.position.y)
        processTouch(lx, ly)
    end
end
```

---

## Startup Optimization Checklist

- [ ] Defer non-critical resource loads to after first frame rendered
- [ ] Use `cache:BackgroundLoadResource()` for large assets
- [ ] Compress textures (JPG for opaque, PNG only when alpha needed)
- [ ] Preload only assets for the first scene/level at startup
- [ ] Show a progress screen while loading — never a black screen > 1 s

---

## Specialist Skill Routing

| Need | Use Skill |
|------|-----------|
| Deep performance profiling, object pooling, draw call batching | `game-performance` |
| Publishing assets (icon, screenshots, promo) | `urhox-game-developer` §Publishing |
| Audio system setup (BGM/SFX) | `audio-manager` |
| Game review and polish | `game-review-improve` |

---

## Reference Files

- GPU optimization, thermal, memory, profiling → `references/performance.md`
- TapTap submission checklist, rejection reasons, QR test → `references/publishing-checklist.md`
