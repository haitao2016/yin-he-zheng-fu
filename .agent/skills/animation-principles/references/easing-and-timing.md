# Easing Curves & Timing Reference

Comprehensive guide to easing functions and timing/spacing for UrhoX Lua games.

---

## Easing Function Math

All easing functions map `t ∈ [0,1]` to an output value. `t=0` is start, `t=1` is end.

### Standard Easing Curves (Lua implementations)

Use these when you need raw math without the Tween library:

```lua
local Easing = {}

-- Linear (no easing)
function Easing.linear(t) return t end

-- Quadratic
function Easing.inQuad(t) return t * t end
function Easing.outQuad(t) return 1 - (1 - t) * (1 - t) end
function Easing.inOutQuad(t)
    return t < 0.5 and 2*t*t or 1 - (-2*t + 2)^2 / 2
end

-- Cubic
function Easing.inCubic(t) return t * t * t end
function Easing.outCubic(t) return 1 - (1 - t)^3 end
function Easing.inOutCubic(t)
    return t < 0.5 and 4*t*t*t or 1 - (-2*t + 2)^3 / 2
end

-- Quartic
function Easing.inQuart(t) return t^4 end
function Easing.outQuart(t) return 1 - (1 - t)^4 end
function Easing.inOutQuart(t)
    return t < 0.5 and 8*t^4 or 1 - (-2*t + 2)^4 / 2
end

-- Quintic
function Easing.inQuint(t) return t^5 end
function Easing.outQuint(t) return 1 - (1 - t)^5 end
function Easing.inOutQuint(t)
    return t < 0.5 and 16*t^5 or 1 - (-2*t + 2)^5 / 2
end

-- Sinusoidal
function Easing.inSine(t) return 1 - math.cos(t * math.pi / 2) end
function Easing.outSine(t) return math.sin(t * math.pi / 2) end
function Easing.inOutSine(t) return -(math.cos(math.pi * t) - 1) / 2 end

-- Exponential
function Easing.inExpo(t) return t == 0 and 0 or 2^(10*t - 10) end
function Easing.outExpo(t) return t == 1 and 1 or 1 - 2^(-10*t) end
function Easing.inOutExpo(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    return t < 0.5 and 2^(20*t - 10)/2 or (2 - 2^(-20*t + 10))/2
end

-- Bounce
function Easing.outBounce(t)
    if t < 1/2.75 then return 7.5625*t*t
    elseif t < 2/2.75 then t = t - 1.5/2.75; return 7.5625*t*t + 0.75
    elseif t < 2.5/2.75 then t = t - 2.25/2.75; return 7.5625*t*t + 0.9375
    else t = t - 2.625/2.75; return 7.5625*t*t + 0.984375 end
end
function Easing.inBounce(t) return 1 - Easing.outBounce(1 - t) end

-- Elastic
function Easing.outElastic(t, amplitude, period)
    amplitude = amplitude or 1.0
    period = period or 0.3
    if t == 0 or t == 1 then return t end
    local s = period / (2*math.pi) * math.asin(1 / math.max(amplitude, 1))
    return amplitude * 2^(-10*t) * math.sin((t - s) * 2*math.pi / period) + 1
end

-- Back (overshoot)
function Easing.outBack(t, overshoot)
    overshoot = overshoot or 1.70158
    t = t - 1
    return t*t*((overshoot + 1)*t + overshoot) + 1
end
function Easing.inBack(t, overshoot)
    overshoot = overshoot or 1.70158
    return t*t*((overshoot + 1)*t - overshoot)
end
```

### Generic helper (apply any easing to a value range)

```lua
--- Interpolate between two values using an easing function.
--- @param from number Start value
--- @param to number End value
--- @param t number Normalized time 0..1
--- @param easingFn function Easing function(t) -> t
local function lerp(from, to, t, easingFn)
    local eased = easingFn and easingFn(t) or t
    return from + (to - from) * eased
end

-- Example:
local opacity = lerp(0, 1, t, Easing.outCubic)
```

---

## Easing Selection Guide

### By Use Case

| Scenario | Recommended Easing | Why |
|----------|-------------------|-----|
| UI panel slides in | `easeOutCubic` | Fast arrival, smooth stop — feels responsive |
| UI panel slides out | `easeInCubic` | Slow start, fast exit — natural departure |
| Menu open/close | `easeInOutCubic` | Smooth both ends — polished feel |
| Popup appear | `easeOutBack` | Overshoot then settle — playful energy |
| Popup disappear | `easeInBack` | Pull back before departing |
| Bounce on landing | `easeOutBounce` | Physical bounce simulation |
| Spring/elastic UI | `easeOutElastic` | Springy overshoot — energetic, playful |
| Score counter | `easeOutCubic` | Fast start then slow to readable |
| Camera zoom | `easeInOutQuad` | Gentle start and stop — comfortable |
| Damage flash | `easeOutExpo` | Very fast then hold — reads as impact |
| Loading bar | `linear` | Honest representation of progress |
| Character acceleration | `easeInQuad` | Start slow, build speed — realistic weight |
| Character deceleration | `easeOutQuad` | Slowing to stop — friction feel |

### By Personality

| Game Tone | Preferred Curves | Overshoot |
|-----------|-----------------|-----------|
| Realistic/sim | Quad, Sine | None |
| Casual/friendly | Cubic, Back | Moderate (1.2-1.5) |
| Cartoon/playful | Elastic, Bounce | High (1.5-2.0) |
| Dramatic/epic | Quart, Expo | Minimal |
| Snappy/arcade | Quint, Expo | Brief/sharp |

---

## Timing & Spacing

### Concept

**Timing** = how many frames / how long an action takes.
**Spacing** = how the distance is distributed across frames.

Together they convey **weight, mood, and energy**.

### Weight Perception Table

| Object Weight | Movement Duration (1 meter) | Easing Style | Example |
|--------------|---------------------------|--------------|---------|
| Paper/feather | 0.1-0.2s | `outQuad` (floaty) | Paper flutter, leaf fall |
| Tennis ball | 0.2-0.4s | `outCubic` | Bouncing collectible |
| Human/character | 0.3-0.6s | `inOutCubic` | Walk step, jump land |
| Heavy crate | 0.5-1.0s | `inOutQuart` | Push/pull physics |
| Boulder/vehicle | 0.8-2.0s | `inOutQuint` | Slow acceleration |
| Building/mountain | 2.0-5.0s | `inOutSine` (gentle) | Earthquake, tectonic |

### Frame Spacing for Different Weights

```
Light object (fast, even spacing):
  ●  ●  ●  ●  ●  ●  ●  ●

Normal object (ease in/out):
  ●●  ●  ●    ●    ●  ●  ●●

Heavy object (slow start, slow stop):
  ●●●● ●● ●  ●  ●  ● ●● ●●●●
```

### Timing Patterns in Games

```lua
-- Hitstop: freeze frames on impact to sell weight
local HITSTOP_LIGHT  = 0.03  -- 2 frames at 60fps — fast jab
local HITSTOP_MEDIUM = 0.07  -- 4 frames — standard hit
local HITSTOP_HEAVY  = 0.12  -- 7 frames — heavy slam

-- Screen shake durations
local SHAKE_BUMP     = 0.1   -- Minor bump
local SHAKE_HIT      = 0.2   -- Combat hit
local SHAKE_EXPLOSION = 0.4  -- Major explosion
local SHAKE_EARTHQUAKE = 1.0 -- Environmental event

-- Animation phase timing (as fraction of total duration)
local ANTICIPATION_RATIO = 0.15  -- 15% windup
local ACTION_RATIO       = 0.50  -- 50% main action
local FOLLOW_THROUGH_RATIO = 0.35  -- 35% settle/recovery
```

---

## Combining Easing with Animation Principles

### Recipe: Satisfying Button Press

```lua
function OnButtonPress(btn)
    -- 1. Anticipation: slight shrink (easeInQuad — accelerating into the press)
    -- 2. Squash: compress on "impact"
    -- 3. Stretch: bounce back past resting state (easeOutBack — overshoot)
    -- 4. Settle: return to rest (easeOutElastic — springy settle)
    Tween.sequence({
        { target = btn, to = { scaleX = 0.92, scaleY = 0.92 },
          options = { duration = 0.06, easing = "easeInQuad" } },
        { target = btn, to = { scaleX = 1.08, scaleY = 1.08 },
          options = { duration = 0.08, easing = "easeOutBack" } },
        { target = btn, to = { scaleX = 1.0, scaleY = 1.0 },
          options = { duration = 0.2, easing = "easeOutElastic" } },
    })
end
```

### Recipe: Character Jump Arc

```lua
-- Combine timing, arcs, squash/stretch, and anticipation
function PerformJump(charNode, jumpHeight, jumpDuration)
    local startPos = charNode.position
    local peakPos = startPos + Vector3(0, jumpHeight, 0)

    -- Phase 1: Anticipation (crouch — 15% of duration)
    Tween.to(charNode, { scale = Vector3(1.2, 0.75, 1.2) }, {
        duration = jumpDuration * 0.15,
        easing = "easeInQuad",
        onComplete = function()
            -- Phase 2: Launch (stretch upward — fast start)
            charNode.scale = Vector3(0.85, 1.3, 0.85)  -- Stretch

            -- Phase 3: Arc trajectory (50% of duration)
            local elapsed = 0
            local arcDur = jumpDuration * 0.5
            -- Use HandleUpdate for arc...

            -- Phase 4: Landing squash (35% for fall + settle)
            -- Apply onLanding() from Principle 1 when hitting ground
        end
    })
end
```

### Recipe: Item Collect Feedback

```lua
function OnItemCollected(itemNode, playerNode)
    -- 1. Scale pop (exaggeration)
    Tween.to(itemNode, { scale = Vector3(1.5, 1.5, 1.5) }, {
        duration = 0.1, easing = "easeOutQuad",
        onComplete = function()
            -- 2. Arc toward UI score counter
            local uiTarget = Vector3(screenW - 100, 50, 0)
            -- ... arc motion to UI
            -- 3. Fade out
            -- 4. Score counter bump (secondary action)
        end
    })
end
```

---

## Mapping soyoyo_tween Easing Names

When using the `soyoyo_tween` library, use these string names:

| Math Function | soyoyo_tween Name | When to Use |
|--------------|-------------------|-------------|
| `Easing.inQuad` | `"easeInQuad"` | Acceleration |
| `Easing.outQuad` | `"easeOutQuad"` | Deceleration |
| `Easing.inOutQuad` | `"easeInOutQuad"` | Symmetric motion |
| `Easing.outCubic` | `"easeOutCubic"` | **Most common UI ease** |
| `Easing.outElastic` | `"easeOutElastic"` | Springy/playful |
| `Easing.outBounce` | `"easeOutBounce"` | Physical bounce |
| `Easing.outBack` | `"easeOutBack"` | Overshoot settle |
| `Easing.inBack` | `"easeInBack"` | Pull-back departure |
| `Easing.outExpo` | `"easeOutExpo"` | Sharp deceleration |
| `Easing.linear` | `"linear"` | Constant speed |

The math implementations in this file are useful when you need easing *outside* of Tween (e.g., in HandleUpdate for procedural animation, custom interpolation, or particle systems).
