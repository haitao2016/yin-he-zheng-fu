# Programming Reference

## Table of Contents
1. [Lua Patterns](#1-lua-patterns)
2. [Scene Graph & Lifecycle](#2-scene-graph--lifecycle)
3. [Input Handling](#3-input-handling)
4. [Physics 2D & 3D](#4-physics-2d--3d)
5. [Graphics & Rendering](#5-graphics--rendering)
6. [Camera Systems](#6-camera-systems)
7. [Multiplayer & Networking](#7-multiplayer--networking)
8. [Architecture Patterns](#8-architecture-patterns)

---

## 1  Lua Patterns

### Type Annotations (Required for LSP accuracy)
```lua
---@type Scene
local scene_ = nil   -- annotate nil declarations

---@type Node
local playerNode_ = nil

-- Auto-inferred (no annotation needed):
local scene = Scene()
local node = scene:CreateChild("Player")
```

### EventData Access
```lua
-- Both forms are correct. The second is more efficient:
local dt = eventData["TimeStep"]:GetFloat()   -- form 1
local dt = eventData:GetFloat("TimeStep")     -- form 2 (preferred)
```

### Safe Array Iteration
```lua
-- Lua arrays start at 1
for i = 1, #arr do
    local item = arr[i]   -- NOT arr[i-1]
end

-- Remove while iterating (backwards)
for i = #arr, 1, -1 do
    if arr[i].dead then table.remove(arr, i) end
end
```

### Module Pattern
```lua
-- scripts/game/MySystem.lua
local MySystem = {}

local state_ = nil   -- private

function MySystem.Init(opts)
    state_ = opts.initialValue
end

function MySystem.Update(dt)
    -- ...
end

return MySystem
```

### Require Paths
```lua
-- urhox-libs (read-only, engine copy runs at runtime)
local InputManager = require("urhox-libs.Platform.InputManager")

-- Your own modules
local MySystem = require("game.MySystem")   -- scripts/game/MySystem.lua

-- Asset paths (no "assets/" prefix)
cache:GetResource("Texture2D", "Textures/player.png")  -- assets/Textures/player.png
```

---

## 2  Scene Graph & Lifecycle

### Minimal Start() Pattern
```lua
---@type Scene
local scene_
---@type Node
local cameraNode_

function Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- Camera
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- Subscribe events
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
end
```

### Node Hierarchy
```lua
local parent = scene_:CreateChild("Parent")
local child  = parent:CreateChild("Child")

-- Position is local to parent
child.position = Vector3(1, 0, 0)

-- World position
local worldPos = child.worldPosition
```

### Component Access
```lua
local model  = node:CreateComponent("StaticModel")
local body   = node:CreateComponent("RigidBody")

-- Get existing component
local rb = node:GetComponent("RigidBody")
if rb then rb:ApplyImpulse(Vector3.UP * 5) end
```

---

## 3  Input Handling

### Keyboard
```lua
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    if input:GetKeyDown(KEY_W) then moveForward(dt) end
    if input:GetKeyDown(KEY_SPACE) then jump() end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_ESCAPE then togglePause() end
end
```

### Mouse
```lua
-- FPS / TPS: lock cursor
input.mouseMode = MM_RELATIVE

function HandleMouseMove(eventType, eventData)
    local dx = eventData:GetInt("DX")
    local dy = eventData:GetInt("DY")
    yaw_   = yaw_   + dx * MOUSE_SENS
    pitch_ = Clamp(pitch_ + dy * MOUSE_SENS, -89.0, 89.0)
end

function HandleMouseButtonDown(eventType, eventData)
    local button = eventData:GetInt("Button")
    if button == MOUSEB_LEFT then fire() end
end
```

### Mobile Touch
```lua
local InputManager = require("urhox-libs.Platform.InputManager")

function Start()
    InputManager.Init({ enableTouch = true })
end

function HandleUpdate(eventType, eventData)
    local touch = InputManager.GetPrimaryTouch()
    if touch then
        -- touch.x, touch.y in logical pixels
    end
end
```

---

## 4  Physics 2D & 3D

### Box2D Quick Setup
```lua
-- ALL collision shapes MUST be on the same node as RigidBody2D
local node = scene_:CreateChild("Player")
node:SetPosition2D(Vector2(0, 2))

local body = node:CreateComponent("RigidBody2D")
body.bodyType = BT_DYNAMIC

-- Box collider (full node, centered)
local shape = node:CreateComponent("CollisionBox2D")
shape.size   = Vector2(0.8, 1.6)
shape.center = Vector2(0, 0)   -- MUST be explicit

-- Circle collider
local circle = node:CreateComponent("CollisionCircle2D")
circle.radius = 0.4
circle.center = Vector2(0, 0)
```

### Ground Detection (Box2D)
```lua
-- Use a small sensor below the character
local footSensor = node:CreateComponent("CollisionBox2D")
footSensor.size     = Vector2(0.6, 0.1)
footSensor.center   = Vector2(0, -0.85)   -- just below feet
footSensor.trigger  = true

-- Count active contacts to detect ground
local groundContacts_ = 0

SubscribeToEvent(node, "PhysicsBeginContact2D", function(et, ed)
    groundContacts_ = groundContacts_ + 1
end)
SubscribeToEvent(node, "PhysicsEndContact2D", function(et, ed)
    groundContacts_ = groundContacts_ - 1
end)

local function isGrounded() return groundContacts_ > 0 end
```

### 3D Physics Quick Setup
```lua
local node = scene_:CreateChild("Box")
node.position = Vector3(0, 5, 0)

local model = node:CreateComponent("StaticModel")
model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

local body = node:CreateComponent("RigidBody")
body.mass = 1.0

local shape = node:CreateComponent("CollisionShape")
shape:SetBox(Vector3.ONE)   -- matches Models/Box.mdl (1×1×1)
```

### 3D Collision Events (see examples/18-physics-collision-3d.lua)
```lua
SubscribeToEvent(node, "NodeCollisionStart", function(et, ed)
    local other = ed:GetPtr("OtherNode")
    if other.name == "Collectible" then collect(other) end
end)
```

---

## 5  Graphics & Rendering

### NanoVG (Custom Vector Graphics)
```lua
local vg_

function Start()
    vg_ = nvgCreate(1)  -- 1 = antialias
    fontId_ = nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")  -- once only\!
    SubscribeToEvent("NanoVGRender", "HandleNVG")
end

function HandleNVG(eventType, eventData)
    local dpr = graphics:GetDPR()
    local w   = graphics:GetWidth()  / dpr
    local h   = graphics:GetHeight() / dpr
    nvgBeginFrame(vg_, w, h, dpr)

    -- Draw here
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, 10, 10, 200, 100, 8)
    nvgFillColor(vg_, nvgRGBAf(0.2, 0.2, 0.8, 0.9))
    nvgFill(vg_)

    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 24)
    nvgFillColor(vg_, nvgRGBAf(1, 1, 1, 1))
    nvgText(vg_, 20, 65, "Hello World")

    nvgEndFrame(vg_)
end
```

### PBR Materials (Procedural)
```lua
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
mat:SetShaderParameter("MatDiffColor", Vector4(0.8, 0.2, 0.2, 1.0))
mat:SetShaderParameter("Roughness", 0.4)
mat:SetShaderParameter("Metallic", 0.0)
node:GetComponent("StaticModel"):SetMaterial(mat)
```

### UI System (urhox-libs/UI)
```lua
local UI = require("urhox-libs/UI")

UI.Init({
    fonts = {{ family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }},
    scale = UI.Scale.DEFAULT,
})

local root = UI.Panel {
    width = "100%", height = "100%",
    justifyContent = "center", alignItems = "center",
    children = {
        UI.Label { text = "Score: 0", fontSize = 32, id = "scoreLabel" },
        UI.Button { text = "Play", variant = "primary",
            onClick = function() startGame() end },
    }
}
UI.SetRoot(root)

-- Update label later:
UI.FindById("scoreLabel"):SetText("Score: " .. score)
```

### Particle Effects
```lua
local emitterNode = scene_:CreateChild("Particles")
emitterNode.position = pos
local emitter = emitterNode:CreateComponent("ParticleEmitter")
emitter:SetEffect(cache:GetResource("ParticleEffect", "Particle/Explosion.xml"))
emitter:SetEmitting(true)
-- Auto-remove after effect completes:
SubscribeToEvent(emitter, "ParticlesEnd", function()
    emitterNode:Remove()
end)
```

---

## 6  Camera Systems

### Free Camera (3D scene scaffold)
```lua
-- Built into scaffold-3d-scene.lua
-- WASD move, mouse look (MM_RELATIVE)
```

### Third-Person Camera (MUST use library)
```lua
require "urhox-libs.Camera.ThirdPersonCamera"

local tpCamera_

function Start()
    -- After scene and character setup:
    tpCamera_ = ThirdPersonCamera.Create(scene_, {
        modes = {
            normal = { distance = 5.0, offset = Vector3(0, 1.7, 0), fov = 45.0 },
        },
    })
    renderer:SetViewport(0, Viewport:new(scene_, tpCamera_:GetCamera()))
end

-- In HandlePostUpdate (NOT HandleUpdate):
function HandlePostUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    tpCamera_:Update(dt, characterNode_, yaw_, pitch_)
end
```

### Orthographic Camera (2D)
```lua
local cam = cameraNode:CreateComponent("Camera")
cam.orthographic = true
cam.orthoSize    = 10   -- full height in world units (half = 5)

-- Screen → world conversion:
-- viewX = ndcX * aspect * orthoSize * 0.5   (NOTE the 0.5 factor\!)
-- viewY = ndcY * orthoSize * 0.5
```

---

## 7  Multiplayer & Networking

### Check Current Mode First
```lua
-- Always read this before implementing any feature:
-- .project/settings.json → @runtime.multiplayer.enabled
-- true  → implement in network/Client.lua + network/Server.lua
-- false → implement in network/Standalone.lua
```

### Server-Authoritative Pattern
```lua
-- Server: authoritative state, broadcast to all
function Server.BroadcastState(state)
    local msg = Shared.Serialize(state)
    for _, conn in ipairs(GetClientConnections()) do
        conn:SendMessage(MSG_STATE, true, true, msg)
    end
end

-- Client: send input, apply predicted state
function Client.SendInput(input)
    serverConn_:SendMessage(MSG_INPUT, false, false, Shared.Serialize(input))
end
```

### Cloud Score (clientCloud)
```lua
-- Read: engine-docs/recipes/client-cloud-score.md
-- Example: examples/11-client-cloud-score-leaderboard-api.lua

clientCloud:SetScore("highScore", score, function(ok, err)
    if ok then print("Saved\!") end
end)

clientCloud:GetLeaderboard("highScore", 10, function(ok, data)
    if ok then
        for _, entry in ipairs(data) do
            print(entry.rank, entry.name, entry.value)
        end
    end
end)
```

---

## 8  Architecture Patterns

### State Machine
```lua
local state_ = "menu"   -- "menu" | "playing" | "paused" | "gameover"

local STATE_UPDATE = {
    menu     = function(dt) updateMenu(dt)    end,
    playing  = function(dt) updateGame(dt)    end,
    paused   = function(dt) updatePaused(dt)  end,
    gameover = function(dt) updateGameOver(dt) end,
}

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    local fn = STATE_UPDATE[state_]
    if fn then fn(dt) end
end

local function switchState(new)
    state_ = new
end
```

### Object Pool
```lua
local pool_ = {}

local function acquire(template)
    if #pool_ > 0 then
        local obj = table.remove(pool_)
        obj.active = true
        return obj
    end
    return createNew(template)
end

local function release(obj)
    obj.active = false
    pool_[#pool_+1] = obj
end
```

### Modular File Split (>1000 lines → split required)
```
scripts/
  main.lua              -- entry: Start(), HandleUpdate()
  game/
    Systems.lua         -- resource/build/research systems
    GalaxyScene.lua     -- galaxy render + interaction
    BattleScene.lua     -- combat render + logic
    AudioManager.lua    -- BGM + SFX
  network/
    Client.lua          -- game logic + network client
    Server.lua          -- server-side authority
    Shared.lua          -- shared constants + serialization
```
