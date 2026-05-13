# Audio Integration & Game Polish Patterns for UrhoX

> Sound design, adaptive music, game juice, and polish techniques for UrhoX Lua games.

---

## 1. Sound Effect Architecture

### 1.1 Sound Layer System

Games need multiple simultaneous sounds. Organize them into layers:

| Layer | Priority | Examples | UrhoX Component |
|-------|----------|---------|-----------------|
| UI | Highest | Button clicks, menu transitions | `SoundSource` (2D) |
| Player | High | Footsteps, attacks, damage | `SoundSource3D` |
| Enemy | Medium | Enemy attacks, death cries | `SoundSource3D` |
| Environment | Low | Wind, water, birds | `SoundSource3D` (looping) |
| Music | Lowest | BGM, adaptive tracks | `SoundSource` (2D) |

### 1.2 Sound Manager Pattern

```lua
-- Sound management with volume control and pooling
local SoundManager = {
    masterVolume = 1.0,
    volumes = { sfx = 0.8, music = 0.6, ui = 1.0 },
    musicNode = nil,
    musicSource = nil,
}

function SoundManager:Init(scene)
    -- Music uses a dedicated 2D source (non-positional)
    self.musicNode = scene:CreateChild("Music")
    self.musicSource = self.musicNode:CreateComponent("SoundSource")
    self.musicSource.soundType = SOUND_MUSIC
end

function SoundManager:PlaySFX(node, soundPath, gain)
    gain = gain or 1.0
    local source = node:GetComponent("SoundSource3D")
    if not source then
        source = node:CreateComponent("SoundSource3D")
        source.soundType = SOUND_EFFECT
        source.nearDistance = 2.0
        source.farDistance = 30.0
    end
    local sound = cache:GetResource("Sound", soundPath)
    if sound then
        source.gain = gain * self.volumes.sfx * self.masterVolume
        source:Play(sound)
    end
end

function SoundManager:PlayUI(soundPath, gain)
    gain = gain or 1.0
    -- UI sounds: create temporary 2D source on scene root
    local sound = cache:GetResource("Sound", soundPath)
    if sound then
        local source = scene_:CreateComponent("SoundSource")
        source.soundType = SOUND_EFFECT
        source.gain = gain * self.volumes.ui * self.masterVolume
        source.autoRemoveMode = REMOVE_COMPONENT
        source:Play(sound)
    end
end

function SoundManager:PlayMusic(soundPath, fade)
    local sound = cache:GetResource("Sound", soundPath)
    if sound then
        sound.looped = true
        self.musicSource.gain = self.volumes.music * self.masterVolume
        self.musicSource:Play(sound)
    end
end

function SoundManager:SetVolume(category, vol)
    self.volumes[category] = math.max(0, math.min(1, vol))
    if category == "music" and self.musicSource then
        self.musicSource.gain = vol * self.masterVolume
    end
end
```

### 1.3 Spatial Audio (3D Sound)

```lua
-- UrhoX 3D positional audio
local function SetupSpatialSound(node, soundPath, options)
    options = options or {}
    local source = node:CreateComponent("SoundSource3D")
    source.soundType = options.type or SOUND_EFFECT
    source.nearDistance = options.near or 1.0   -- Full volume within this range (meters)
    source.farDistance = options.far or 50.0    -- Inaudible beyond this (meters)
    source.gain = options.gain or 1.0

    local sound = cache:GetResource("Sound", soundPath)
    if sound then
        sound.looped = options.loop or false
        source:Play(sound)
    end
    return source
end

-- Example: ambient campfire
SetupSpatialSound(campfireNode, "Sounds/fire_crackle.ogg", {
    near = 2.0,
    far = 15.0,
    loop = true,
    gain = 0.7,
})

-- Example: explosion (one-shot, auto-remove)
local src = SetupSpatialSound(explosionNode, "Sounds/explosion.ogg", {
    near = 5.0,
    far = 80.0,
})
src.autoRemoveMode = REMOVE_COMPONENT
```

**Key distance guidelines (in meters)**:

| Sound Type | nearDistance | farDistance |
|-----------|-------------|------------|
| Footsteps | 1.0 | 15.0 |
| Gunshot | 5.0 | 100.0 |
| Dialogue | 2.0 | 10.0 |
| Ambient loop | 3.0 | 20.0 |
| Explosion | 5.0 | 80.0 |
| UI click | N/A (2D) | N/A (2D) |

### 1.4 Sound Variation (Anti-Repetition)

```lua
-- Prevent repetitive sounds by using variations
local FootstepSounds = {
    "Sounds/footstep_01.ogg",
    "Sounds/footstep_02.ogg",
    "Sounds/footstep_03.ogg",
    "Sounds/footstep_04.ogg",
}
local lastFootstep = 0

local function PlayFootstep(node, gain)
    -- Avoid playing the same sound twice in a row
    local idx = math.random(1, #FootstepSounds)
    while idx == lastFootstep and #FootstepSounds > 1 do
        idx = math.random(1, #FootstepSounds)
    end
    lastFootstep = idx

    -- Slight pitch variation for natural feel
    local source = node:GetComponent("SoundSource3D")
    if source then
        source.frequency = 44100 * (0.95 + math.random() * 0.10)  -- +/- 5%
    end
    SoundManager:PlaySFX(node, FootstepSounds[idx], gain)
end
```

---

## 2. Adaptive Music System

### 2.1 Intensity-Based Music

```lua
-- Simple adaptive music: crossfade between calm/combat tracks
local AdaptiveMusic = {
    calmSource = nil,
    combatSource = nil,
    intensity = 0.0,       -- 0.0 = calm, 1.0 = full combat
    targetIntensity = 0.0,
    fadeSpeed = 0.5,       -- Transition speed (per second)
    baseVolume = 0.6,
}

function AdaptiveMusic:Init(scene)
    local node = scene:CreateChild("AdaptiveMusic")

    self.calmSource = node:CreateComponent("SoundSource")
    self.calmSource.soundType = SOUND_MUSIC

    self.combatSource = node:CreateComponent("SoundSource")
    self.combatSource.soundType = SOUND_MUSIC

    local calm = cache:GetResource("Sound", "Music/calm_loop.ogg")
    local combat = cache:GetResource("Sound", "Music/combat_loop.ogg")

    if calm then calm.looped = true; self.calmSource:Play(calm) end
    if combat then combat.looped = true; self.combatSource:Play(combat) end
end

function AdaptiveMusic:SetIntensity(target)
    self.targetIntensity = math.max(0, math.min(1, target))
end

function AdaptiveMusic:Update(dt)
    -- Smooth transition toward target
    if self.intensity < self.targetIntensity then
        self.intensity = math.min(self.intensity + self.fadeSpeed * dt, self.targetIntensity)
    elseif self.intensity > self.targetIntensity then
        self.intensity = math.max(self.intensity - self.fadeSpeed * dt, self.targetIntensity)
    end

    -- Crossfade volumes
    self.calmSource.gain = (1.0 - self.intensity) * self.baseVolume
    self.combatSource.gain = self.intensity * self.baseVolume
end

-- Usage in game loop:
-- AdaptiveMusic:SetIntensity(1.0)  -- enemies nearby
-- AdaptiveMusic:SetIntensity(0.0)  -- area clear
-- AdaptiveMusic:Update(dt)         -- call every frame
```

### 2.2 Music State Machine

```lua
-- For complex games: state-driven music selection
local MusicStates = {
    menu      = { track = "Music/menu_theme.ogg",    volume = 0.7 },
    explore   = { track = "Music/explore_loop.ogg",  volume = 0.5 },
    combat    = { track = "Music/combat_loop.ogg",   volume = 0.8 },
    boss      = { track = "Music/boss_theme.ogg",    volume = 0.9 },
    victory   = { track = "Music/victory_fanfare.ogg", volume = 0.7 },
    gameover  = { track = "Music/gameover.ogg",      volume = 0.6 },
}

local currentMusicState = nil

local function TransitionMusic(newState)
    if newState == currentMusicState then return end
    local config = MusicStates[newState]
    if not config then return end

    currentMusicState = newState
    SoundManager:PlayMusic(config.track)
    SoundManager:SetVolume("music", config.volume)
end
```

---

## 3. Game Juice & Feel

### 3.1 Screen Shake

```lua
-- Camera shake for impacts, explosions, damage
local ScreenShake = {
    trauma = 0.0,       -- Current trauma level (0-1)
    decay = 2.0,        -- Trauma decay per second
    maxOffset = 0.5,    -- Max offset in world units (meters)
    maxAngle = 3.0,     -- Max rotation in degrees
    frequency = 15.0,   -- Noise frequency
    time = 0.0,
}

function ScreenShake:AddTrauma(amount)
    self.trauma = math.min(1.0, self.trauma + amount)
end

function ScreenShake:Update(dt, cameraNode, basePos)
    self.time = self.time + dt

    if self.trauma <= 0 then return end

    -- Shake intensity = trauma^2 (quadratic for better feel)
    local shake = self.trauma * self.trauma

    -- Pseudo-random offsets using sin (deterministic, smooth)
    local t = self.time * self.frequency
    local offsetX = shake * self.maxOffset * math.sin(t * 1.1 + 0.3)
    local offsetY = shake * self.maxOffset * math.sin(t * 1.7 + 1.2)
    local angle   = shake * self.maxAngle  * math.sin(t * 0.9 + 2.1)

    cameraNode.position = Vector3(
        basePos.x + offsetX,
        basePos.y + offsetY,
        basePos.z
    )
    -- Apply roll for 2D games (optional)
    -- cameraNode.rotation = Quaternion(angle, Vector3.FORWARD)

    -- Decay trauma
    self.trauma = math.max(0, self.trauma - self.decay * dt)
end

-- Usage:
-- ScreenShake:AddTrauma(0.3)  -- light hit
-- ScreenShake:AddTrauma(0.7)  -- heavy explosion
-- ScreenShake:AddTrauma(1.0)  -- massive boss attack
```

**Trauma guidelines**:

| Event | Trauma Amount |
|-------|--------------|
| Light hit / coin pickup | 0.1 - 0.2 |
| Medium hit / enemy death | 0.3 - 0.4 |
| Heavy hit / player damage | 0.5 - 0.6 |
| Explosion | 0.7 - 0.8 |
| Boss attack / critical event | 0.9 - 1.0 |

### 3.2 Hit Stop (Frame Freeze)

```lua
-- Brief pause on impact for weight and impact feel
local HitStop = {
    timer = 0.0,
    active = false,
}

function HitStop:Trigger(duration)
    duration = duration or 0.05  -- 50ms default
    self.timer = duration
    self.active = true
end

function HitStop:GetTimeScale(dt)
    if not self.active then return 1.0 end

    self.timer = self.timer - dt
    if self.timer <= 0 then
        self.active = false
        return 1.0
    end
    return 0.0  -- Freeze game time
end

-- Usage in game loop:
-- local gameSpeed = HitStop:GetTimeScale(dt)
-- local gameDt = dt * gameSpeed
-- -- Use gameDt for all game logic (movement, physics, animation)
```

**Hit stop duration guidelines**:

| Event | Duration (seconds) |
|-------|-------------------|
| Light attack connects | 0.02 - 0.04 |
| Heavy attack connects | 0.05 - 0.08 |
| Critical hit | 0.08 - 0.12 |
| Killing blow | 0.10 - 0.15 |
| Parry / perfect block | 0.06 - 0.10 |

### 3.3 Squash and Stretch

```lua
-- Apply squash/stretch to a node for lively animation
local function SquashStretch(node, factor, dt, speed)
    speed = speed or 8.0
    -- factor > 1 = stretch (jumping up), factor < 1 = squash (landing)
    -- Preserve volume: scaleX * scaleY = 1
    local scaleY = 1.0 + (factor - 1.0)
    local scaleX = 1.0 / scaleY

    -- Lerp toward target for smooth transition
    local current = node.scale
    local targetScale = Vector3(scaleX, scaleY, scaleX)  -- For 3D
    node.scale = Vector3(
        current.x + (targetScale.x - current.x) * math.min(1, speed * dt),
        current.y + (targetScale.y - current.y) * math.min(1, speed * dt),
        current.z + (targetScale.z - current.z) * math.min(1, speed * dt)
    )
end

-- Usage:
-- SquashStretch(playerNode, 1.3, dt)  -- stretch while jumping
-- SquashStretch(playerNode, 0.7, dt)  -- squash on landing
-- SquashStretch(playerNode, 1.0, dt)  -- return to normal
```

### 3.4 Flash Effect (Damage Feedback)

```lua
-- Flash a model white when taking damage
local FlashEffect = {
    nodes = {},  -- { node = ..., timer = ..., original = ... }
}

function FlashEffect:Flash(node, duration)
    duration = duration or 0.1
    local model = node:GetComponent("StaticModel") or node:GetComponent("AnimatedModel")
    if not model then return end

    -- Create white flash material
    local flashMat = Material:new()
    flashMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    flashMat:SetShaderParameter("MatDiffColor", Variant(Color(1, 1, 1, 1)))

    -- Store original and apply flash
    local origMat = model:GetMaterial(0)
    model:SetMaterial(flashMat)

    table.insert(self.nodes, {
        model = model,
        timer = duration,
        original = origMat,
    })
end

function FlashEffect:Update(dt)
    for i = #self.nodes, 1, -1 do
        local entry = self.nodes[i]
        entry.timer = entry.timer - dt
        if entry.timer <= 0 then
            entry.model:SetMaterial(entry.original)
            table.remove(self.nodes, i)
        end
    end
end
```

### 3.5 Particle Burst (NanoVG 2D)

```lua
-- Simple 2D particle system for NanoVG games
local Particles = { list = {} }

function Particles:Burst(x, y, count, config)
    config = config or {}
    local color = config.color or { r = 1, g = 1, b = 0 }  -- yellow default
    local speed = config.speed or 200
    local life = config.life or 0.5
    local size = config.size or 4

    for i = 1, (count or 10) do
        local angle = math.random() * math.pi * 2
        local spd = speed * (0.5 + math.random() * 0.5)
        table.insert(self.list, {
            x = x, y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = life * (0.7 + math.random() * 0.3),
            maxLife = life,
            size = size * (0.5 + math.random() * 0.5),
            r = color.r, g = color.g, b = color.b,
        })
    end
end

function Particles:Update(dt)
    for i = #self.list, 1, -1 do
        local p = self.list[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 400 * dt  -- gravity
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.list, i)
        end
    end
end

function Particles:Draw(vg)
    for _, p in ipairs(self.list) do
        local alpha = p.life / p.maxLife
        nvgBeginPath(vg)
        nvgCircle(vg, p.x, p.y, p.size * alpha)
        nvgFillColor(vg, nvgRGBAf(p.r, p.g, p.b, alpha))
        nvgFill(vg)
    end
end

-- Usage:
-- Particles:Burst(enemyX, enemyY, 15, { color = {r=1,g=0,b=0}, speed = 300 })
-- Particles:Update(dt)  -- in HandleUpdate
-- Particles:Draw(vg)    -- in HandleNanoVGRender
```

### 3.6 Particle Burst (3D)

```lua
-- 3D particle effect using UrhoX ParticleEmitter
local function CreateExplosionEffect(scene, position)
    local effectNode = scene:CreateChild("Explosion")
    effectNode.position = position

    local emitter = effectNode:CreateComponent("ParticleEmitter")
    local effect = cache:GetResource("ParticleEffect", "Particle/Particle.xml")
    if effect then
        emitter:SetEffect(effect)
        emitter:SetEmitting(true)
    end

    -- Auto-remove after effect completes
    effectNode:AddTag("AutoRemove")
    return effectNode
end

-- For custom programmatic particles, configure ParticleEffect:
-- effect.minDirection / maxDirection: emission cone
-- effect.constantForce: gravity/wind (Vector3)
-- effect.minEmissionRate / maxEmissionRate: particles per second
-- effect.minTimeToLive / maxTimeToLive: particle lifetime
-- effect.minSize / maxSize: particle size range
```

---

## 4. Screen Transitions

### 4.1 Fade Transition (NanoVG)

```lua
-- Full-screen fade for scene transitions
local FadeTransition = {
    alpha = 0.0,
    target = 0.0,
    speed = 2.0,
    callback = nil,
    callbackFired = false,
}

function FadeTransition:FadeOut(onComplete)
    self.target = 1.0
    self.callback = onComplete
    self.callbackFired = false
end

function FadeTransition:FadeIn()
    self.target = 0.0
    self.callback = nil
end

function FadeTransition:Update(dt)
    if self.alpha < self.target then
        self.alpha = math.min(self.alpha + self.speed * dt, self.target)
    elseif self.alpha > self.target then
        self.alpha = math.max(self.alpha - self.speed * dt, self.target)
    end

    -- Fire callback at peak darkness
    if not self.callbackFired and self.alpha >= 1.0 and self.callback then
        self.callbackFired = true
        self.callback()
        -- Auto fade back in after callback
        self:FadeIn()
    end
end

function FadeTransition:Draw(vg, w, h)
    if self.alpha <= 0.001 then return end
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBAf(0, 0, 0, self.alpha))
    nvgFill(vg)
end

-- Usage:
-- FadeTransition:FadeOut(function()
--     LoadNewLevel()
-- end)
```

---

## 5. Polish Checklist

### 5.1 Essential Polish (Every Game)

| Category | Item | Implementation |
|----------|------|---------------|
| **Audio** | Button click sound |  |
| **Audio** | Background music |  |
| **Visual** | Screen shake on hit |  |
| **Visual** | Damage flash |  |
| **Visual** | Death particles |  |
| **Feel** | Hit stop on impact |  |
| **Feel** | Score popup animation | Tween or manual lerp |
| **UX** | Scene transitions |  |

### 5.2 Advanced Polish (If Time Allows)

| Category | Item | Notes |
|----------|------|-------|
| **Audio** | Footstep variation | 3-4 sounds + pitch randomization |
| **Audio** | Adaptive music | Crossfade calm/combat tracks |
| **Visual** | Squash/stretch | On jump, land, bounce |
| **Visual** | Trail effects | For fast-moving objects |
| **Visual** | Parallax background | Multi-layer depth |
| **Feel** | Coyote time | Allow jump after leaving edge |
| **Feel** | Input buffering | Queue inputs during animations |
| **UX** | Slow motion on kill |  briefly |

### 5.3 Sound Design Quick Reference

**Sound file guidelines for UrhoX**:

| Property | Recommendation |
|----------|---------------|
| Format |  (Vorbis) preferred,  for short SFX |
| Sample rate | 44100 Hz |
| Channels | Mono for 3D spatial, Stereo for music/UI |
| Duration | SFX: 0.1-2.0s, Music: loop seamlessly |

**UrhoX sound types** (for mixing):

| Type | Constant | Use |
|------|----------|-----|
| Effect |  | SFX, footsteps, impacts |
| Music |  | Background music |
| Voice |  | Dialogue, narration |
| Ambient |  | Environment loops |

---

## 6. Common Mistakes

| Mistake | Fix |
|---------|-----|
| Playing sound every frame | Use cooldown timer or trigger on state change |
| No pitch variation on repeated SFX | Add +/- 5% random pitch variation |
| Music not looped | Set  before playing |
| 3D sound inaudible | Check nearDistance/farDistance values |
| Too many simultaneous sounds | Limit max concurrent sounds per category |
| Screen shake in Update | Apply shake to camera in PostUpdate |
| Hit stop freezes UI | Only freeze game logic dt, not UI |
| Particles never cleaned up | Check life <= 0 and remove from list |
| Flash effect leaks materials | Always restore original material |
