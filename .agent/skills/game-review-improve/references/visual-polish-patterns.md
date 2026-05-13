# Visual Polish Patterns for UrhoX Lua Games

Concrete, copy-paste-ready patterns for adding juice and polish to UrhoX Lua games.
Organized by effect type. Each pattern includes both NanoVG (2D) and 3D node approaches.

---

## Screen Shake

The most impactful single juice effect. Use on: hits, explosions, game over.

```lua
-- Camera shake system
local shakeTrauma = 0  -- 0.0 to 1.0
local shakeDecay = 2.0  -- how fast shake fades
local shakeMaxOffset = 0.5  -- maximum displacement in meters (3D) or pixels (2D)

function ApplyScreenShake(dt)
    if shakeTrauma <= 0 then return end

    -- Quadratic intensity feels more natural
    local intensity = shakeTrauma * shakeTrauma
    local offsetX = (math.random() * 2 - 1) * shakeMaxOffset * intensity
    local offsetY = (math.random() * 2 - 1) * shakeMaxOffset * intensity

    -- 3D: offset camera node
    cameraNode.position = baseCameraPos + Vector3(offsetX, offsetY, 0)

    -- Decay
    shakeTrauma = math.max(0, shakeTrauma - shakeDecay * dt)
end

-- Trigger: add trauma (capped at 1.0)
function AddScreenShake(amount)
    shakeTrauma = math.min(1.0, shakeTrauma + amount)
end

-- Usage:
-- AddScreenShake(0.3)  -- light hit
-- AddScreenShake(0.6)  -- heavy hit
-- AddScreenShake(1.0)  -- explosion / game over
```

**NanoVG (2D) variant**:
```lua
function HandleNanoVGRender(eventType, eventData)
    local intensity = shakeTrauma * shakeTrauma
    local offsetX = (math.random() * 2 - 1) * 8 * intensity  -- 8 pixels max
    local offsetY = (math.random() * 2 - 1) * 8 * intensity

    nvgBeginFrame(vg, w, h, 1.0)
    nvgTranslate(vg, offsetX, offsetY)  -- shake the entire canvas
    -- ... draw everything ...
    nvgEndFrame(vg)
end
```

---

## Hit Stop / Freeze Frame

Brief pause (40-80ms) on impactful moments. Makes hits feel powerful.

```lua
local hitStopTimer = 0
local hitStopDuration = 0

function TriggerHitStop(durationSeconds)
    hitStopTimer = durationSeconds
    hitStopDuration = durationSeconds
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if hitStopTimer > 0 then
        hitStopTimer = hitStopTimer - dt
        return  -- Skip ALL game logic during freeze
    end

    -- Normal game update continues here
    UpdateGameplay(dt)
end

-- Usage:
-- TriggerHitStop(0.05)  -- 50ms freeze on enemy kill
-- TriggerHitStop(0.08)  -- 80ms freeze on big hit
```

---

## Flash Effect (Damage Feedback)

Briefly turn an entity white/red on damage.

```lua
-- 3D: Material swap approach
function FlashEntity(node, duration)
    local model = node:GetComponent("StaticModel")
    if not model then return end

    local originalMat = model:GetMaterial(0)

    -- Create or reuse white flash material
    local flashMat = Material:new()
    flashMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    flashMat:SetShaderParameter("MatDiffColor", Variant(Color(3.0, 3.0, 3.0, 1.0)))  -- bright white

    model:SetMaterial(0, flashMat)

    -- Schedule restore (using frame counting since no coroutines)
    flashTimer = duration
    flashNode = node
    flashOriginalMat = originalMat
end

-- In Update:
if flashTimer and flashTimer > 0 then
    flashTimer = flashTimer - dt
    if flashTimer <= 0 then
        local model = flashNode:GetComponent("StaticModel")
        if model then model:SetMaterial(0, flashOriginalMat) end
        flashTimer = nil
    end
end
```

**NanoVG (2D) variant**:
```lua
-- Simply draw a white overlay on the entity for a few frames
local flashEntities = {}  -- { entity = framesRemaining }

function FlashEntity2D(entityId)
    flashEntities[entityId] = 4  -- flash for 4 frames
end

-- In render:
if flashEntities[id] and flashEntities[id] > 0 then
    -- Draw entity in white
    nvgGlobalCompositeOperation(vg, NVG_LIGHTER)
    -- draw entity shape
    nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
    flashEntities[id] = flashEntities[id] - 1
end
```

---

## Scale Pop (Collection/Score)

Quick scale-up then return to normal. Great for pickups, scoring, button press.

```lua
-- Scale pop system for 3D nodes
local scaleAnims = {}

function ScalePop(node, popScale, duration)
    scaleAnims[#scaleAnims + 1] = {
        node = node,
        startScale = node.scale,
        popScale = Vector3(popScale, popScale, popScale),
        timer = 0,
        duration = duration or 0.2,
        phase = "pop"  -- "pop" then "return"
    }
end

function UpdateScaleAnims(dt)
    for i = #scaleAnims, 1, -1 do
        local anim = scaleAnims[i]
        anim.timer = anim.timer + dt

        if anim.phase == "pop" then
            local t = math.min(1, anim.timer / (anim.duration * 0.3))
            -- Ease out
            t = 1 - (1 - t) * (1 - t)
            anim.node.scale = anim.startScale + (anim.popScale - anim.startScale) * t
            if anim.timer >= anim.duration * 0.3 then
                anim.phase = "return"
                anim.timer = 0
            end
        else
            local t = math.min(1, anim.timer / (anim.duration * 0.7))
            -- Ease in-out
            t = t * t * (3 - 2 * t)
            anim.node.scale = anim.popScale + (anim.startScale - anim.popScale) * t
            if t >= 1 then
                anim.node.scale = anim.startScale
                table.remove(scaleAnims, i)
            end
        end
    end
end

-- Usage:
-- ScalePop(coinNode, 1.5, 0.25)  -- pop to 1.5x then back
-- ScalePop(scoreNode, 1.3, 0.2)  -- subtle pop
```

---

## Floating Score Text

"+1" text that floats up and fades. Shows points near the action.

```lua
-- NanoVG floating text system
local floatingTexts = {}

function AddFloatingText(x, y, text, color)
    floatingTexts[#floatingTexts + 1] = {
        x = x, y = y,
        text = text,
        color = color or nvgRGBA(255, 255, 0, 255),
        timer = 0,
        duration = 0.8,
        speed = 60,  -- pixels per second upward
    }
end

function UpdateFloatingTexts(dt)
    for i = #floatingTexts, 1, -1 do
        local ft = floatingTexts[i]
        ft.timer = ft.timer + dt
        ft.y = ft.y - ft.speed * dt

        if ft.timer >= ft.duration then
            table.remove(floatingTexts, i)
        end
    end
end

function DrawFloatingTexts()
    nvgFontFace(vg, "sans")
    for _, ft in ipairs(floatingTexts) do
        local alpha = math.max(0, 1 - ft.timer / ft.duration)
        local scale = 1.0 + ft.timer * 0.3  -- slight grow

        nvgFontSize(vg, 24 * scale)
        nvgFillColor(vg, nvgRGBA(255, 255, 0, math.floor(alpha * 255)))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, ft.x, ft.y, ft.text)
    end
end

-- Usage:
-- AddFloatingText(enemyScreenX, enemyScreenY, "+100")
-- AddFloatingText(coinScreenX, coinScreenY, "+1", nvgRGBA(255, 215, 0, 255))
```

---

## Particle Burst (2D NanoVG)

Burst of particles on destruction, collection, or explosion.

```lua
local particles = {}

function EmitBurst(x, y, count, color, speed)
    count = count or 12
    speed = speed or 120
    for i = 1, count do
        local angle = (math.pi * 2 * i / count) + (math.random() - 0.5) * 0.5
        local spd = speed * (0.5 + math.random() * 0.5)
        particles[#particles + 1] = {
            x = x, y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            radius = 2 + math.random() * 3,
            color = color or nvgRGBA(255, 200, 50, 255),
            life = 0.4 + math.random() * 0.3,
            timer = 0,
        }
    end
end

function UpdateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.timer = p.timer + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 200 * dt  -- gravity
        if p.timer >= p.life then
            table.remove(particles, i)
        end
    end
end

function DrawParticles()
    for _, p in ipairs(particles) do
        local alpha = math.max(0, 1 - p.timer / p.life)
        local r = p.radius * (1 - p.timer / p.life * 0.5)
        nvgBeginPath(vg)
        nvgCircle(vg, p.x, p.y, r)
        nvgFillColor(vg, nvgRGBA(255, 200, 50, math.floor(alpha * 255)))
        nvgFill(vg)
    end
end

-- Usage:
-- EmitBurst(enemyX, enemyY, 15)          -- enemy death
-- EmitBurst(coinX, coinY, 8, goldColor)  -- coin collect
```

---

## Particle Burst (3D)

```lua
function EmitBurst3D(scene, position, count, color, radius)
    count = count or 10
    radius = radius or 0.1

    for i = 1, count do
        local node = scene:CreateChild("Particle")
        node.position = position
        node.scale = Vector3(radius, radius, radius)

        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(color or Color(1, 0.8, 0.2, 1)))
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(1, 0.5, 0, 1)))
        model:SetMaterial(0, mat)

        -- Random velocity
        local angle = math.pi * 2 * i / count
        local speed = 3 + math.random() * 3
        local vel = Vector3(
            math.cos(angle) * speed,
            2 + math.random() * 4,  -- upward
            math.sin(angle) * speed
        )

        -- Store velocity for update (use node's name as storage)
        node.name = string.format("%.2f,%.2f,%.2f,%.2f", vel.x, vel.y, vel.z, 0.5 + math.random() * 0.3)
    end
end

-- In Update: iterate particles and apply velocity + gravity + fade + remove
```

---

## Scene Transition (Fade)

```lua
-- Fade overlay for scene transitions
local fadeAlpha = 0
local fadeTarget = 0
local fadeSpeed = 3.0
local fadeCallback = nil

function FadeOut(callback)
    fadeTarget = 1.0
    fadeCallback = callback
end

function FadeIn()
    fadeAlpha = 1.0
    fadeTarget = 0
end

function UpdateFade(dt)
    if fadeAlpha ~= fadeTarget then
        if fadeAlpha < fadeTarget then
            fadeAlpha = math.min(fadeTarget, fadeAlpha + fadeSpeed * dt)
        else
            fadeAlpha = math.max(fadeTarget, fadeAlpha - fadeSpeed * dt)
        end

        if fadeAlpha == fadeTarget and fadeCallback then
            fadeCallback()
            fadeCallback = nil
            FadeIn()  -- auto fade back in
        end
    end
end

-- Draw last (on top of everything):
function DrawFade()
    if fadeAlpha > 0.01 then
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(fadeAlpha * 255)))
        nvgFill(vg)
    end
end

-- Usage:
-- FadeOut(function()
--     RestartGame()
-- end)
```

---

## Background Gradient (NanoVG 2D)

```lua
-- Vertical gradient background
function DrawBackground()
    local topColor = nvgRGBA(30, 40, 80, 255)     -- dark blue
    local bottomColor = nvgRGBA(80, 120, 180, 255) -- lighter blue

    local paint = nvgLinearGradient(vg, 0, 0, 0, screenH, topColor, bottomColor)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end
```

---

## Entity Entrance Animation

```lua
-- Pop-in: entity scales from 0 to 1 with overshoot
local entranceAnims = {}

function AnimateEntrance(node, delay)
    node.scale = Vector3(0, 0, 0)
    entranceAnims[#entranceAnims + 1] = {
        node = node,
        timer = -(delay or 0),  -- negative = wait
        duration = 0.4,
    }
end

function UpdateEntranceAnims(dt)
    for i = #entranceAnims, 1, -1 do
        local anim = entranceAnims[i]
        anim.timer = anim.timer + dt

        if anim.timer < 0 then
            -- Still waiting
        elseif anim.timer < anim.duration then
            -- Back-ease-out: overshoots then settles
            local t = anim.timer / anim.duration
            local overshoot = 1.7
            t = t - 1
            local scale = t * t * ((overshoot + 1) * t + overshoot) + 1
            anim.node.scale = Vector3(scale, scale, scale)
        else
            anim.node.scale = Vector3(1, 1, 1)
            table.remove(entranceAnims, i)
        end
    end
end

-- Usage: stagger enemy spawns
-- for i, enemy in ipairs(enemies) do
--     AnimateEntrance(enemy.node, (i - 1) * 0.1)
-- end
```

---

## Polish Checklist by Priority

### Essential (do first — biggest impact for least effort)

1. **Screen shake** on hits/death — immediate game feel improvement
2. **Floating score text** — makes scoring satisfying
3. **Background gradient** — replaces flat color, adds atmosphere
4. **Fade transitions** — professional scene changes
5. **Scale pop on collection** — satisfying pickups

### Advanced (do after essentials)

6. **Hit stop** on kills — makes combat feel powerful
7. **Particle bursts** on destruction — visual excitement
8. **Entity entrance animations** — world feels alive
9. **Flash on damage** — clear damage feedback
10. **Trail effects** on fast objects — sense of speed
