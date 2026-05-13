# 2D Game Patterns for UrhoX

> Reference for `game-design-patterns` skill.
> Covers sprite animation, tilemaps, parallax, platformer feel, 2D camera,
> and 2D physics best practices — all in UrhoX Lua.

---

## 1  Sprite Animation

### Frame-Based Animation with NanoVG

For pure 2D games rendered via NanoVG:

```lua
local SpriteAnim = {}
SpriteAnim.__index = SpriteAnim

function SpriteAnim.new(config)
    local self = setmetatable({}, SpriteAnim)
    self.frames     = config.frames      -- { "Textures/hero_idle_1.png", ... }
    self.fps        = config.fps or 12
    self.loop       = config.loop ~= false
    self.timer      = 0
    self.frameIndex = 1
    self.images     = {}
    self.finished   = false
    return self
end

function SpriteAnim:load(vg)
    for i, path in ipairs(self.frames) do
        self.images[i] = nvgCreateImage(vg, path, 0)
    end
end

function SpriteAnim:update(dt)
    if self.finished then return end
    self.timer = self.timer + dt
    local frameDuration = 1.0 / self.fps
    while self.timer >= frameDuration do
        self.timer = self.timer - frameDuration
        self.frameIndex = self.frameIndex + 1
        if self.frameIndex > #self.frames then
            if self.loop then
                self.frameIndex = 1
            else
                self.frameIndex = #self.frames
                self.finished = true
            end
        end
    end
end

function SpriteAnim:draw(vg, x, y, w, h)
    local img = self.images[self.frameIndex]
    if not img then return end
    local paint = nvgImagePattern(vg, x, y, w, h, 0, img, 1.0)
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w, h)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end

return SpriteAnim
```

### Animation Controller

Manage multiple named animations with transitions:

```lua
local AnimController = {}
AnimController.__index = AnimController

function AnimController.new()
    local self = setmetatable({}, AnimController)
    self.anims = {}
    self.current = nil
    self.currentName = ""
    return self
end

function AnimController:add(name, anim)
    self.anims[name] = anim
end

function AnimController:play(name)
    if self.currentName == name then return end
    local anim = self.anims[name]
    if not anim then return end
    self.currentName = name
    self.current = anim
    anim.frameIndex = 1
    anim.timer = 0
    anim.finished = false
end

function AnimController:update(dt)
    if self.current then
        self.current:update(dt)
    end
end

function AnimController:draw(vg, x, y, w, h)
    if self.current then
        self.current:draw(vg, x, y, w, h)
    end
end

return AnimController
```

### 12 Principles of Animation (Game-Relevant Subset)

| Principle | Game Application |
|-----------|-----------------|
| **Squash & Stretch** | Character landing, ball bouncing |
| **Anticipation** | Wind-up before jump/attack |
| **Follow-Through** | Hair/cape momentum after stop |
| **Ease In/Out** | Camera moves, UI transitions |
| **Arcs** | Projectile paths, jump curves |
| **Timing** | Frame count = weight and mood |
| **Exaggeration** | Larger reactions = better feel |

---

## 2  Tilemap System

### Grid-Based Tilemap

```lua
local Tilemap = {}
Tilemap.__index = Tilemap

-- Tile types
Tilemap.EMPTY  = 0
Tilemap.GROUND = 1
Tilemap.WALL   = 2
Tilemap.SPIKE  = 3
Tilemap.COIN   = 4

function Tilemap.new(cols, rows, tileSize)
    local self = setmetatable({}, Tilemap)
    self.cols     = cols
    self.rows     = rows
    self.tileSize = tileSize
    self.data     = {}
    -- Initialize empty
    for r = 1, rows do
        self.data[r] = {}
        for c = 1, cols do
            self.data[r][c] = Tilemap.EMPTY
        end
    end
    return self
end

function Tilemap:get(col, row)
    if col < 1 or col > self.cols or row < 1 or row > self.rows then
        return Tilemap.WALL  -- Out-of-bounds = solid
    end
    return self.data[row][col]
end

function Tilemap:set(col, row, tile)
    if col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
        self.data[row][col] = tile
    end
end

function Tilemap:isSolid(col, row)
    local t = self:get(col, row)
    return t == Tilemap.GROUND or t == Tilemap.WALL
end

-- World position → tile coordinate
function Tilemap:worldToTile(x, y)
    local col = math.floor(x / self.tileSize) + 1
    local row = math.floor(y / self.tileSize) + 1
    return col, row
end

-- Tile coordinate → world position (top-left corner)
function Tilemap:tileToWorld(col, row)
    local x = (col - 1) * self.tileSize
    local y = (row - 1) * self.tileSize
    return x, y
end

return Tilemap
```

### Tilemap Rendering (NanoVG)

```lua
function Tilemap:draw(vg, cameraX, cameraY, screenW, screenH, tileImages)
    -- Only draw visible tiles (culling)
    local startCol = math.max(1, math.floor(cameraX / self.tileSize) + 1)
    local endCol   = math.min(self.cols,
        math.floor((cameraX + screenW) / self.tileSize) + 2)
    local startRow = math.max(1, math.floor(cameraY / self.tileSize) + 1)
    local endRow   = math.min(self.rows,
        math.floor((cameraY + screenH) / self.tileSize) + 2)

    for r = startRow, endRow do
        for c = startCol, endCol do
            local tile = self.data[r][c]
            if tile ~= Tilemap.EMPTY then
                local wx, wy = self:tileToWorld(c, r)
                local sx = wx - cameraX
                local sy = wy - cameraY
                local img = tileImages[tile]
                if img then
                    local paint = nvgImagePattern(vg,
                        sx, sy, self.tileSize, self.tileSize, 0, img, 1.0)
                    nvgBeginPath(vg)
                    nvgRect(vg, sx, sy, self.tileSize, self.tileSize)
                    nvgFillPaint(vg, paint)
                    nvgFill(vg)
                else
                    -- Fallback: colored rectangle
                    local colors = {
                        [Tilemap.GROUND] = nvgRGBA(100, 80, 60, 255),
                        [Tilemap.WALL]   = nvgRGBA(60, 60, 60, 255),
                        [Tilemap.SPIKE]  = nvgRGBA(200, 50, 50, 255),
                        [Tilemap.COIN]   = nvgRGBA(255, 215, 0, 255),
                    }
                    nvgBeginPath(vg)
                    nvgRect(vg, sx, sy, self.tileSize, self.tileSize)
                    nvgFillColor(vg, colors[tile] or nvgRGBA(128, 128, 128, 255))
                    nvgFill(vg)
                end
            end
        end
    end
end
```

### Tilemap Collision Detection

```lua
-- Check if a rectangle (AABB) collides with solid tiles
function Tilemap:checkCollision(x, y, w, h)
    local results = { top = false, bottom = false, left = false, right = false }

    local c1, r1 = self:worldToTile(x, y)
    local c2, r2 = self:worldToTile(x + w - 1, y + h - 1)

    for r = r1, r2 do
        for c = c1, c2 do
            if self:isSolid(c, r) then
                local tx, ty = self:tileToWorld(c, r)
                -- Determine collision side
                local overlapLeft   = (x + w) - tx
                local overlapRight  = (tx + self.tileSize) - x
                local overlapTop    = (y + h) - ty
                local overlapBottom = (ty + self.tileSize) - y

                local minOverlap = math.min(overlapLeft, overlapRight,
                                             overlapTop, overlapBottom)
                if minOverlap == overlapTop    then results.bottom = true end
                if minOverlap == overlapBottom  then results.top    = true end
                if minOverlap == overlapLeft    then results.right  = true end
                if minOverlap == overlapRight   then results.left   = true end
            end
        end
    end

    return results
end
```

---

## 3  Parallax Scrolling

### Multi-Layer Parallax

```lua
local ParallaxLayer = {}
ParallaxLayer.__index = ParallaxLayer

function ParallaxLayer.new(config)
    local self = setmetatable({}, ParallaxLayer)
    self.image   = nil       -- NanoVG image handle
    self.path    = config.path
    self.speed   = config.speed   -- 0.0 = static, 1.0 = same as camera
    self.offsetY = config.offsetY or 0
    self.repeatX = config.repeatX ~= false
    return self
end

function ParallaxLayer:load(vg)
    self.image = nvgCreateImage(vg, self.path, NVG_IMAGE_REPEATX)
end

function ParallaxLayer:draw(vg, cameraX, cameraY, screenW, screenH)
    if not self.image then return end
    local parallaxX = cameraX * self.speed
    local y = self.offsetY - cameraY * self.speed

    if self.repeatX then
        -- Seamless horizontal repeat
        local startX = -(parallaxX % screenW)
        for x = startX, screenW, screenW do
            local paint = nvgImagePattern(vg, x, y,
                screenW, screenH, 0, self.image, 1.0)
            nvgBeginPath(vg)
            nvgRect(vg, x, y, screenW, screenH)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
        end
    else
        local paint = nvgImagePattern(vg, -parallaxX, y,
            screenW, screenH, 0, self.image, 1.0)
        nvgBeginPath(vg)
        nvgRect(vg, 0, y, screenW, screenH)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    end
end

-- Usage:
-- local layers = {
--     ParallaxLayer.new({ path = "Textures/bg_sky.png",    speed = 0.1 }),
--     ParallaxLayer.new({ path = "Textures/bg_clouds.png", speed = 0.3 }),
--     ParallaxLayer.new({ path = "Textures/bg_trees.png",  speed = 0.6 }),
-- }
-- Draw back-to-front: for i, layer in ipairs(layers) do layer:draw(...) end
```

---

## 4  Platformer Feel

### Coyote Time + Jump Buffering

The two most important "game feel" techniques for platformers.

```lua
local PlatformerPlayer = {}
PlatformerPlayer.__index = PlatformerPlayer

local COYOTE_TIME   = 0.12  -- seconds after leaving ground where jump still works
local JUMP_BUFFER   = 0.10  -- seconds before landing where jump input is remembered
local JUMP_VELOCITY = 7.0   -- meters/second (UrhoX unit = meter)
local GRAVITY       = -9.81
local MAX_FALL      = -20.0

function PlatformerPlayer.new()
    local self = setmetatable({}, PlatformerPlayer)
    self.velY           = 0
    self.onGround       = false
    self.coyoteTimer    = 0
    self.jumpBufferTimer = 0
    self.jumpHeld       = false
    return self
end

function PlatformerPlayer:update(dt, jumpPressed, jumpHeld, grounded)
    -- Track ground state
    if grounded then
        self.coyoteTimer = COYOTE_TIME
        self.onGround = true
    else
        self.coyoteTimer = math.max(0, self.coyoteTimer - dt)
        self.onGround = false
    end

    -- Jump buffer: remember recent jump presses
    if jumpPressed then
        self.jumpBufferTimer = JUMP_BUFFER
    else
        self.jumpBufferTimer = math.max(0, self.jumpBufferTimer - dt)
    end

    -- Execute jump if both conditions met
    local canJump = self.coyoteTimer > 0
    local wantsJump = self.jumpBufferTimer > 0

    if canJump and wantsJump then
        self.velY = JUMP_VELOCITY
        self.coyoteTimer = 0
        self.jumpBufferTimer = 0
        self.jumpHeld = true
    end

    -- Variable jump height: release early = lower jump
    if self.jumpHeld and not jumpHeld and self.velY > 0 then
        self.velY = self.velY * 0.5  -- cut velocity
        self.jumpHeld = false
    end

    -- Gravity
    if not grounded then
        self.velY = self.velY + GRAVITY * dt
        self.velY = math.max(MAX_FALL, self.velY)
    elseif self.velY < 0 then
        self.velY = 0
    end

    return self.velY * dt  -- vertical displacement
end

return PlatformerPlayer
```

### Movement Feel Parameters

| Parameter | Tight Feel | Floaty Feel | Recommendation |
|-----------|-----------|-------------|----------------|
| Acceleration | 50-80 | 10-20 | Start at 40 |
| Deceleration | 60-100 | 5-15 | Start at 50 |
| Max Speed | 5-8 m/s | 3-5 m/s | Start at 6 |
| Jump Velocity | 7-10 m/s | 4-6 m/s | Start at 7 |
| Gravity | -20 to -30 | -8 to -12 | Start at -15 |
| Coyote Time | 0.08-0.15s | 0.1-0.2s | 0.12s |
| Jump Buffer | 0.08-0.12s | 0.1-0.15s | 0.10s |

---

## 5  2D Camera

### Smooth Follow Camera

```lua
local Camera2D = {}
Camera2D.__index = Camera2D

function Camera2D.new(config)
    local self = setmetatable({}, Camera2D)
    self.x = 0
    self.y = 0
    self.targetX = 0
    self.targetY = 0
    self.smoothing  = config.smoothing or 5.0   -- higher = snappier
    self.lookahead  = config.lookahead or 50     -- pixels ahead of movement
    self.deadzone   = config.deadzone or { x = 20, y = 10 }
    self.bounds     = config.bounds  -- { minX, maxX, minY, maxY } or nil
    self.shakeTimer = 0
    self.shakeIntensity = 0
    return self
end

function Camera2D:follow(targetX, targetY, velX)
    -- Lookahead based on movement direction
    local lookX = 0
    if velX > 0.1 then lookX = self.lookahead
    elseif velX < -0.1 then lookX = -self.lookahead end

    self.targetX = targetX + lookX
    self.targetY = targetY
end

function Camera2D:update(dt)
    -- Smooth interpolation (deadzone)
    local dx = self.targetX - self.x
    local dy = self.targetY - self.y

    if math.abs(dx) > self.deadzone.x then
        self.x = self.x + dx * self.smoothing * dt
    end
    if math.abs(dy) > self.deadzone.y then
        self.y = self.y + dy * self.smoothing * dt
    end

    -- Clamp to bounds
    if self.bounds then
        self.x = math.max(self.bounds.minX,
                 math.min(self.bounds.maxX, self.x))
        self.y = math.max(self.bounds.minY,
                 math.min(self.bounds.maxY, self.y))
    end

    -- Screen shake
    local offsetX, offsetY = 0, 0
    if self.shakeTimer > 0 then
        self.shakeTimer = self.shakeTimer - dt
        local intensity = self.shakeIntensity * (self.shakeTimer / 0.3)
        offsetX = (math.random() * 2 - 1) * intensity
        offsetY = (math.random() * 2 - 1) * intensity
    end

    return self.x + offsetX, self.y + offsetY
end

function Camera2D:shake(intensity, duration)
    self.shakeIntensity = intensity or 8
    self.shakeTimer = duration or 0.3
end

return Camera2D
```

### Camera Types for 2D

| Type | Best For | Behavior |
|------|----------|----------|
| **Locked** | Single screen | Camera never moves |
| **Follow** | Platformer | Track player with smooth lag |
| **Look-ahead** | Fast-paced | Shift in movement direction |
| **Room-based** | Metroidvania | Snap to room boundaries |
| **Multi-target** | 2-player | Zoom to fit both players |
| **Cinematic** | Cutscenes | Scripted path/positions |

---

## 6  2D Physics Tips (Box2D)

### Common Mistakes & Fixes

| Mistake | Fix |
|---------|-----|
| Collision shapes on child nodes | All shapes on **same node** as RigidBody2D |
| Using pixel units | UrhoX uses **meters**; 1 unit = 1 meter |
| Mesh collider for simple shapes | Use Box/Circle/Capsule when possible |
| Missing collision layers | Set category + mask bits for filtering |
| Tunneling at high speed | Enable CCD: `body.bullet = true` |

### Ground Detection (Box2D Sensor)

```lua
-- Create a thin sensor at character feet
local footSensor = characterNode:CreateComponent("CollisionBox2D")
footSensor.size = Vector2(0.4, 0.1)  -- slightly narrower than body
footSensor.center = Vector2(0, -0.5) -- below character center
footSensor.trigger = true
footSensor.categoryBits = 0x0002
footSensor.maskBits = 0x0001  -- collide with ground layer

local groundContacts = 0

SubscribeToEvent(characterNode, "NodeBeginContact2D", function(_, ed)
    local otherNode = ed["OtherNode"]:GetPtr("Node")
    groundContacts = groundContacts + 1
end)

SubscribeToEvent(characterNode, "NodeEndContact2D", function(_, ed)
    groundContacts = groundContacts - 1
end)

local function isOnGround()
    return groundContacts > 0
end
```

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Sprite appears blurry | Use nearest-neighbor filtering for pixel art |
| Animation too fast/slow | Adjust FPS per animation, not globally |
| Parallax jitters | Use floating-point camera, round only at draw time |
| Tilemap seams (gaps between tiles) | Overlap tiles by 1 pixel or use atlas |
| Jump feels wrong | Tune coyote time + jump buffer FIRST |
| Camera jerks on landing | Use deadzone + smoothing together |
| Z-fighting in 2D | Use explicit layer ordering, not Z position |
