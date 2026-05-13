---
name: animation-principles
description: >-
  Disney's 12 Principles of Animation adapted for UrhoX Lua game development.
  Provides mathematical formulas, Lua implementation patterns, and practical
  code snippets for squash-and-stretch, anticipation, follow-through, arcs,
  timing/spacing, exaggeration, and more. Covers procedural animation via
  per-frame transforms, easing curve selection, secondary motion, and
  volume-preserving scale. Complements the soyoyo_tween library (which is
  the execution tool) by providing the design methodology and formulas behind
  polished game animation.
---

# Animation Principles — Disney's 12 Principles for UrhoX Lua Games

## Identity

You are an **Animation Design Advisor**. You help developers apply Disney's 12 animation principles to make their UrhoX Lua games feel alive, polished, and juicy.

## Trigger Condition

**WHEN** the user needs to:
- Add "game feel" or "juice" to animations (squash, stretch, anticipation, follow-through)
- Design procedural animation (not skeletal/FSM — those use `setup-fsm`)
- Choose easing curves for motion (beyond just picking a tween name)
- Implement physics-inspired visual effects (arcs, secondary motion, exaggeration)
- Understand *why* an animation looks stiff and how to fix it

**SKIP WHEN**:
- User needs the Tween API itself → delegate to `soyoyo_tween`
- User needs skeletal animation / state machine → delegate to `setup-fsm`
- User needs particle effects → use engine ParticleEmitter

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `soyoyo_tween` | **Complementary** — tween is the *tool*, principles are the *design method*. Use principles to decide *what* to animate and *how*, then implement with Tween API |
| `setup-fsm` | **Non-overlapping** — FSM handles skeletal animation states; principles handle procedural visual polish |
| `game-design-patterns` | **Non-overlapping** — patterns cover code architecture; principles cover animation design |
| `game-creation-workflow` | **Integrates at Phase 5 step 8** — "Polish" phase benefits from these principles |

## The 12 Principles — Quick Reference

| # | Principle | Game Use Case | Key Formula |
|---|-----------|--------------|-------------|
| 1 | **Squash & Stretch** | Landing impact, speed lines | `scaleY = 1 + speed * intensity; scaleX = 1/scaleY` |
| 2 | **Anticipation** | Jump crouch, attack windup | Offset opposite to action direction for 10-20% of duration |
| 3 | **Staging** | Boss entrance, tutorial focus | Contrast/depth based on importance and focal distance |
| 4 | **Straight Ahead / Pose to Pose** | Procedural vs keyframed motion | Noise for organic feel; keyframe interpolation for control |
| 5 | **Follow Through** | Hair, capes, trailing particles | Drag offset + damped oscillation after stop |
| 6 | **Slow In / Slow Out** | All motion | Easing curves (see `references/easing-and-timing.md`) |
| 7 | **Arcs** | Projectiles, jumping, swinging | `y = h * 4 * t * (1-t)` parabolic arc |
| 8 | **Secondary Action** | Arm swing while walking, blinking | Sinusoidal offset layered on primary motion |
| 9 | **Timing** | Weight, mood, comedy | Frame spacing controls perceived mass |
| 10 | **Exaggeration** | Cartoon style, impact emphasis | `result = center + (value - center) * factor` |
| 11 | **Solid Drawing** | Volume preservation during squash | `correctedScale = scale * (targetVol / currentVol)^(1/dims)` |
| 12 | **Appeal** | Proportions, visual harmony | Golden ratio φ=1.618 for proportions |

## Core Implementation Patterns

### Pattern 1: Squash & Stretch on Landing/Jumping

```lua
-- Apply squash on landing, stretch during fast movement
local function applySquashStretch(node, velocity, intensity)
    intensity = intensity or 0.3
    local speed = velocity:Length()
    local stretch = math.min(1 + speed * intensity, 1 + intensity * 3)
    local squash = 1.0 / stretch  -- Volume preservation

    -- Align with velocity direction (2D: rotation around Z)
    local angle = math.atan(velocity.y, velocity.x)

    node.scale = Vector3(squash, stretch, 1.0)
    -- For 3D: rotate node to align stretch axis with velocity
end

-- Usage in HandleUpdate:
-- While falling fast → stretch vertically
-- On ground contact → squash briefly, then spring back with Tween
```

### Pattern 2: Anticipation Before Action

```lua
local function startJumpWithAnticipation(node, jumpForce)
    local originalScale = node.scale

    -- Phase 1: Crouch (anticipation) — 15% of total time
    Tween.to(node, { scale = Vector3(1.2, 0.7, 1.2) }, {
        duration = 0.1,
        easing = "easeInQuad",
        onComplete = function()
            -- Phase 2: Launch (the actual action)
            node:GetComponent("RigidBody"):ApplyImpulse(Vector3(0, jumpForce, 0))
            Tween.to(node, { scale = Vector3(0.85, 1.3, 0.85) }, {
                duration = 0.08,
                easing = "easeOutQuad",
                onComplete = function()
                    -- Phase 3: Restore
                    Tween.to(node, { scale = originalScale }, {
                        duration = 0.15, easing = "easeOutElastic"
                    })
                end
            })
        end
    })
end
```

### Pattern 3: Follow-Through for Secondary Elements

```lua
-- Attach a trailing element that lags behind the main node
local dragFactor = 0.3
local dampening = 0.95
local trailVelocity = Vector3.ZERO

function UpdateFollowThrough(dt, mainNode, trailNode)
    local targetPos = mainNode.position
    local currentPos = trailNode.position
    local diff = targetPos - currentPos

    -- Lag behind the main node
    trailVelocity = trailVelocity + diff * (1 - dragFactor) * 10 * dt
    trailVelocity = trailVelocity * dampening

    trailNode.position = currentPos + trailVelocity * dt
end
```

### Pattern 4: Arc Motion for Projectiles

```lua
-- Parabolic arc from start to target
local function getArcPosition(t, startPos, endPos, arcHeight)
    local x = startPos.x + (endPos.x - startPos.x) * t
    local z = startPos.z + (endPos.z - startPos.z) * t
    local baseY = startPos.y + (endPos.y - startPos.y) * t
    local arcY = arcHeight * 4 * t * (1 - t)  -- Parabola peak at t=0.5
    return Vector3(x, baseY + arcY, z)
end

-- Usage: animate a thrown object
local elapsed = 0
local duration = 1.0
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    elapsed = elapsed + dt
    local t = math.min(elapsed / duration, 1.0)
    projectileNode.position = getArcPosition(t, start, target, 5.0)
end
```

### Pattern 5: Exaggeration for Impact

```lua
-- Exaggerate a value away from a neutral center
local function exaggerate(value, center, factor)
    return center + (value - center) * factor
end

-- Example: exaggerate damage knockback
local baseKnockback = 5.0
local actualKnockback = exaggerate(baseKnockback, 0, 1.8)  -- 9.0

-- Example: exaggerate scale pop on item pickup
Tween.to(node, { scale = Vector3(1.5, 1.5, 1.5) }, {  -- Overshoot
    duration = 0.15, easing = "easeOutQuad",
    onComplete = function()
        Tween.to(node, { scale = Vector3(1, 1, 1) }, {
            duration = 0.3, easing = "easeOutElastic"
        })
    end
})
```

## When to Apply Each Principle

| Game Event | Principles to Apply |
|-----------|-------------------|
| **Character jumps** | Anticipation (crouch) → Squash/Stretch (launch/land) → Arc (trajectory) |
| **Enemy takes hit** | Exaggeration (knockback) → Follow-Through (body parts lag) → Timing (hitstop) |
| **Item collected** | Exaggeration (scale pop) → Secondary Action (sparkle particles) → Appeal (golden spiral path) |
| **Menu opens** | Anticipation (slight shrink) → Slow In/Out (easing) → Follow-Through (overshoot settle) |
| **Projectile fired** | Arc (trajectory) → Squash/Stretch (elongate along velocity) → Secondary Action (trail) |
| **Character walks** | Secondary Action (arm swing, head bob) → Arcs (limb paths) → Timing (weight) |
| **Boss entrance** | Staging (camera focus, dim background) → Anticipation (dramatic pause) → Exaggeration (scale) |

## Reference Files

| File | Content |
|------|---------|
| `references/principle-implementations.md` | Detailed formulas and full Lua implementations for all 12 principles |
| `references/easing-and-timing.md` | Easing curve math, timing/spacing guide, weight perception table |
