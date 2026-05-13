# Animation Principles — Detailed Implementations

All implementations are pure Lua functions for UrhoX. They use per-frame `HandleUpdate` logic or integrate with `soyoyo_tween`.

---

## Principle 1: Squash & Stretch

**Concept**: The most important principle. Gives objects a sense of weight and flexibility. When moving fast → stretch along velocity. On impact → squash perpendicular.

**Volume Preservation Rule**: `scaleX * scaleY = 1.0` (2D) or `scaleX * scaleY * scaleZ = 1.0` (3D).

```lua
--- Compute squash/stretch scale from velocity.
--- @param velocity Vector3 Current velocity
--- @param intensity number 0.0 (none) to 1.0 (extreme), default 0.3
--- @return Vector3 scale to apply
local function computeSquashStretch(velocity, intensity)
    intensity = intensity or 0.3
    local speed = velocity:Length()
    local stretch = math.min(1.0 + speed * intensity, 1.0 + intensity * 3.0)
    local squash = 1.0 / stretch

    -- For 2D side-view: stretch along Y (up), squash along X
    if math.abs(velocity.y) > math.abs(velocity.x) then
        return Vector3(squash, stretch, 1.0)
    else
        return Vector3(stretch, squash, 1.0)
    end
end

-- Landing impact: brief squash then restore
local function onLanding(node)
    Tween.to(node, { scale = Vector3(1.3, 0.7, 1.3) }, {
        duration = 0.06,
        easing = "easeOutQuad",
        onComplete = function()
            Tween.to(node, { scale = Vector3(1, 1, 1) }, {
                duration = 0.25, easing = "easeOutElastic"
            })
        end
    })
end
```

**When to use**: Landing, bouncing, fast-moving projectiles, rubber-like objects, cartoon characters.

---

## Principle 2: Anticipation

**Concept**: Preparatory motion *before* the main action. Signals intent and makes the action feel more powerful.

**Rule of thumb**: Anticipation = 10-20% of total action duration, in the *opposite* direction.

```lua
--- Anticipation offset: moves opposite to intended direction.
--- @param actionDirection Vector3 Intended movement direction
--- @param windupRatio number Fraction of duration for windup (0.1 to 0.3)
--- @param windupIntensity number How far to pull back (meters or scale factor)
local function computeAnticipation(t, actionDirection, windupRatio, windupIntensity)
    windupRatio = windupRatio or 0.15
    windupIntensity = windupIntensity or 0.3

    if t < windupRatio then
        -- Windup phase: move opposite
        local phase_t = t / windupRatio
        local blend = math.sin(phase_t * math.pi / 2)  -- Smooth curve
        return actionDirection * (-windupIntensity * blend)
    else
        return Vector3.ZERO
    end
end
```

**Common applications**:

| Action | Anticipation Motion |
|--------|-------------------|
| Jump | Crouch down (scale Y to 0.7) |
| Punch/Attack | Pull arm/weapon back |
| Throw | Wind up opposite to throw direction |
| Dash | Brief pause + slight backward lean |
| Menu button press | Slight shrink before expanding |

---

## Principle 3: Staging

**Concept**: Present an idea so it is unmistakably clear. Direct the player's attention.

```lua
--- Staging: dim/desaturate non-focal elements.
--- @param elementNode Node Element to stage
--- @param focalPoint Vector3 Where attention should be
--- @param importance number 0.0 (background) to 1.0 (main focus)
local function applyStagingContrast(elementNode, focalPoint, importance)
    local distance = (elementNode.position - focalPoint):Length()
    local contrast = math.max(0.1, importance / (1.0 + distance * 0.5))

    -- Apply via material opacity or color dimming
    local material = elementNode:GetComponent("StaticModel").material
    if material then
        local baseColor = material:GetShaderParameter("MatDiffColor")
        material:SetShaderParameter("MatDiffColor",
            Color(baseColor.r * contrast, baseColor.g * contrast, baseColor.b * contrast, baseColor.a))
    end
end
```

**Game staging techniques**:
- Boss intro: darken background, spotlight boss, slow-motion
- Tutorial: dim everything except the interactive element
- Cutscene: letterbox framing, camera focus

---

## Principle 4: Straight Ahead vs Pose to Pose

**Concept**: Two approaches to creating motion.

**Straight Ahead** = frame-by-frame, organic, slightly unpredictable:
```lua
-- Add organic variation to procedural motion
local function straightAheadOffset(t, noiseAmount)
    noiseAmount = noiseAmount or 0.05
    local nx = math.sin(t * 13.37) * noiseAmount
    local ny = math.sin(t * 7.13 + 2.1) * noiseAmount
    return Vector3(nx, ny, 0)
end
```

**Pose to Pose** = define key positions, interpolate between them:
```lua
-- Interpolate between key poses with easing
local function poseInterpolate(t, keyPoses, keyTimes)
    -- Find current segment
    local seg = 1
    for i = 1, #keyTimes - 1 do
        if t >= keyTimes[i] then seg = i end
    end
    local tStart = keyTimes[seg]
    local tEnd = keyTimes[math.min(seg + 1, #keyTimes)]
    local localT = (tEnd > tStart) and ((t - tStart) / (tEnd - tStart)) or 1.0
    localT = math.max(0, math.min(1, localT))

    -- Apply cubic ease
    local eased = localT < 0.5
        and 4 * localT * localT * localT
        or 1 - (-2 * localT + 2)^3 / 2

    local a = keyPoses[seg]
    local b = keyPoses[math.min(seg + 1, #keyPoses)]
    return a + (b - a) * eased
end
```

**When to use which**:
- Straight ahead: fire, smoke, water, organic creatures
- Pose to pose: UI transitions, character key poses, controlled cinematics

---

## Principle 5: Follow Through & Overlapping Action

**Concept**: When main body stops, appendages continue moving. Different parts move at different rates.

```lua
--- Follow-through with damped oscillation.
--- Call every frame for trailing elements (hair, tail, cape).
local FollowThrough = {}

function FollowThrough.new(drag, oscillation, damping)
    return {
        drag = drag or 0.3,
        oscillation = oscillation or 0.1,
        damping = damping or 0.95,
        velocity = Vector3.ZERO,
        offset = Vector3.ZERO,
    }
end

function FollowThrough.update(self, dt, parentVelocity, parentStopped)
    -- Drag: lag behind parent
    local dragForce = parentVelocity * (-self.drag)

    if parentStopped then
        -- Oscillation after parent stops
        self.velocity = self.velocity * self.damping
        self.offset = self.offset + self.velocity * dt
    else
        self.velocity = parentVelocity * (1 - self.drag)
        self.offset = dragForce * dt
    end

    return self.offset
end
```

**Practical tips**:
- Hair/cape: drag=0.4, damping=0.9 (heavy, slow settle)
- Antenna/feather: drag=0.2, damping=0.85 (light, springy)
- UI tooltip following cursor: drag=0.15, damping=0.98 (smooth lag)

---

## Principle 6: Slow In / Slow Out

→ See `references/easing-and-timing.md` for complete easing curve reference.

**Core idea**: Real objects accelerate and decelerate. Constant speed looks mechanical.

**Quick Lua easing functions** (if not using soyoyo_tween):

```lua
local function easeInCubic(t) return t * t * t end
local function easeOutCubic(t) return 1 - (1 - t)^3 end
local function easeInOutCubic(t)
    return t < 0.5 and 4*t*t*t or 1 - (-2*t + 2)^3 / 2
end
```

---

## Principle 7: Arcs

**Concept**: Natural motion follows curved paths, not straight lines.

```lua
--- Parabolic arc between two points.
--- @param t number Normalized time 0..1
--- @param startPos Vector3
--- @param endPos Vector3
--- @param arcHeight number Maximum height above the straight line
--- @return Vector3 position on the arc
local function arcPosition(t, startPos, endPos, arcHeight)
    local pos = startPos + (endPos - startPos) * t
    pos.y = pos.y + arcHeight * 4 * t * (1 - t)
    return pos
end

--- Tangent direction on the arc (for aligning sprites/models).
local function arcTangent(t, startPos, endPos, arcHeight)
    local dx = endPos.x - startPos.x
    local dy = (endPos.y - startPos.y) + arcHeight * 4 * (1 - 2*t)
    local dz = endPos.z - startPos.z
    return Vector3(dx, dy, dz):Normalized()
end
```

**Common arc applications**:
- Thrown items: `arcHeight = throwForce * 0.5`
- Jump trajectory: parabolic Y with constant X velocity
- Sword swing: circular arc around shoulder pivot
- Camera pan: arc slightly above straight line for cinematic feel

---

## Principle 8: Secondary Action

**Concept**: Additional motion that supports the primary action without stealing focus.

```lua
--- Sinusoidal secondary motion (arm swing, head bob, etc.)
--- @param t number Current time (seconds, not normalized)
--- @param frequency number Cycles per second
--- @param amplitude number Maximum displacement
--- @param phaseOffset number Phase shift in radians
local function secondaryMotion(t, frequency, amplitude, phaseOffset)
    phaseOffset = phaseOffset or 0
    return amplitude * math.sin(2 * math.pi * frequency * t + phaseOffset)
end

-- Example: head bob while walking
local walkTime = 0
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if isWalking then
        walkTime = walkTime + dt
        local bobY = secondaryMotion(walkTime, 2.0, 0.05, 0)        -- vertical bob
        local swayX = secondaryMotion(walkTime, 1.0, 0.03, math.pi/2) -- horizontal sway
        headNode.position = baseHeadPos + Vector3(swayX, bobY, 0)
    end
end
```

---

## Principle 9: Timing

**Concept**: The number of frames/time allocated to an action conveys weight and mood.

| Weight | Duration Multiplier | Example |
|--------|-------------------|---------|
| Feather | 0.5x | Quick, snappy movements |
| Normal | 1.0x | Standard game objects |
| Heavy | 2.0x | Slow, weighty movements |
| Massive | 3.0x+ | Giant boss, heavy machinery |

```lua
--- Timing-adjusted duration based on perceived weight.
local function weightedDuration(baseDuration, weight)
    local multipliers = {
        feather = 0.5,
        light = 0.7,
        normal = 1.0,
        heavy = 1.5,
        massive = 2.5,
    }
    return baseDuration * (multipliers[weight] or 1.0)
end

-- Example: different jump feel
local jumpDuration = weightedDuration(0.5, "heavy")  -- 0.75s for a heavy character
```

---

## Principle 10: Exaggeration

**Concept**: Push values beyond realistic to make animation read clearly. Too realistic can look dull.

```lua
--- Exaggerate a value away from a center point.
--- @param value number The value to exaggerate
--- @param center number The neutral point
--- @param factor number Exaggeration multiplier (1.0 = no change)
local function exaggerate(value, center, factor)
    return center + (value - center) * factor
end
```

**Exaggeration guidelines**:

| Effect | Factor | Example |
|--------|--------|---------|
| Subtle polish | 1.1-1.3 | Slight overshoot on UI slide |
| Cartoon feel | 1.5-2.0 | Bounce on landing, stretch on dash |
| Comedy/slapstick | 2.0-3.0 | Extreme squash, wild knockback |
| Dramatic impact | 1.5-2.5 | Screen shake amplitude, hitstop duration |

---

## Principle 11: Solid Drawing (Volume Preservation)

**Concept**: Maintain consistent volume when deforming objects.

```lua
--- Correct scale to preserve volume.
--- @param scale Vector3 Current (potentially wrong) scale
--- @param targetVolume number Desired volume (default 1.0)
--- @return Vector3 corrected scale
local function preserveVolume(scale, targetVolume)
    targetVolume = targetVolume or 1.0
    local currentVolume = math.abs(scale.x * scale.y * scale.z)
    if currentVolume <= 0 then return scale end
    local correction = (targetVolume / currentVolume) ^ (1/3)
    return scale * correction
end

-- Example: after squash/stretch, ensure volume stays constant
local squashedScale = Vector3(1.4, 0.6, 1.0)  -- Volume = 0.84 (wrong\!)
local corrected = preserveVolume(squashedScale)  -- Corrected to volume = 1.0
```

---

## Principle 12: Appeal

**Concept**: Make designs visually pleasing using mathematical harmony.

```lua
--- Golden ratio proportions for layout/design.
local PHI = (1 + math.sqrt(5)) / 2  -- 1.618033988749895

--- Divide a total size into golden ratio proportions.
--- @param total number Total size to divide
--- @param divisions number Number of segments
--- @return table Array of segment sizes summing to total
local function goldenProportions(total, divisions)
    local raw = {}
    for i = 1, divisions do
        raw[i] = PHI ^ (-(i-1))
    end
    local sum = 0
    for _, v in ipairs(raw) do sum = sum + v end
    local result = {}
    for i, v in ipairs(raw) do
        result[i] = v / sum * total
    end
    return result
end

-- Example: divide a 1920px width into 3 harmonious columns
local cols = goldenProportions(1920, 3)
-- cols ≈ {893, 552, 341}  (adds visual hierarchy)
```

**Appeal in games**:
- Character proportions: head-to-body ratio using φ
- UI spacing: margins and padding based on golden ratio
- Animation rhythm: beat patterns using φ-based intervals
