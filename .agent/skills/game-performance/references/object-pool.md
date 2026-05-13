# Object Pool Reference

Complete object pool implementation for UrhoX Lua games with auto-grow, metrics, and lifecycle callbacks.

## Table of Contents

1. [Design Principles](#design-principles)
2. [Generic Pool Module](#generic-pool-module)
3. [Typed Pool Variants](#typed-pool-variants)
4. [Usage Patterns](#usage-patterns)
5. [Pool Sizing Guide](#pool-sizing-guide)
6. [Common Pitfalls](#common-pitfalls)

---

## Design Principles

| Principle | Explanation |
|-----------|-------------|
| Hide, don't destroy | `SetEnabled(false)` + move off-screen instead of `Remove()` |
| Pre-warm at load | Create all objects during scene setup, never during gameplay |
| Fixed capacity first | Start with fixed pool; add auto-grow only if needed |
| Reset on release | Clear velocity, state, timers before returning to pool |
| Track metrics | Monitor high-water mark to right-size pools |

---

## Generic Pool Module

```lua
--- ObjectPool.lua — Generic pool for any node-based object
--- Usage: local pool = ObjectPool.new(scene, 50, createBullet, resetBullet)

local ObjectPool = {}
ObjectPool.__index = ObjectPool

--- Create a new object pool.
--- @param scene     Scene       Parent scene
--- @param capacity  number      Initial pool size
--- @param createFn  function    fn(scene) → node  Factory function
--- @param resetFn   function?   fn(node)           Called on release (optional)
--- @param autoGrow  boolean?    Allow pool to grow beyond capacity (default false)
function ObjectPool.new(scene, capacity, createFn, resetFn, autoGrow)
    local self = setmetatable({}, ObjectPool)
    self.scene    = scene
    self.createFn = createFn
    self.resetFn  = resetFn or function() end
    self.autoGrow = autoGrow or false
    self.nodes    = {}       -- all nodes (both active and inactive)
    self.active   = {}       -- set of active node indices
    self.capacity = capacity
    -- metrics
    self.acquireCount = 0
    self.releaseCount = 0
    self.highWater    = 0
    self.missCount    = 0    -- acquire attempts when pool empty

    -- Pre-warm
    for i = 1, capacity do
        local node = createFn(scene)
        node:SetEnabled(false)
        self.nodes[i] = node
    end
    return self
end

--- Acquire a node from the pool.
--- @return Node? node  nil if pool exhausted and autoGrow=false
function ObjectPool:acquire()
    for i = 1, #self.nodes do
        if not self.active[i] then
            self.active[i] = true
            self.acquireCount = self.acquireCount + 1
            local activeCount = self:getActiveCount()
            if activeCount > self.highWater then
                self.highWater = activeCount
            end
            local node = self.nodes[i]
            node:SetEnabled(true)
            return node
        end
    end

    -- Pool exhausted
    self.missCount = self.missCount + 1

    if self.autoGrow then
        local idx = #self.nodes + 1
        local node = self.createFn(self.scene)
        self.nodes[idx] = node
        self.active[idx] = true
        self.acquireCount = self.acquireCount + 1
        self.capacity = self.capacity + 1
        local activeCount = self:getActiveCount()
        if activeCount > self.highWater then
            self.highWater = activeCount
        end
        return node
    end

    return nil
end

--- Release a node back to the pool.
--- @param node Node  The node to release
function ObjectPool:release(node)
    for i = 1, #self.nodes do
        if self.nodes[i] == node then
            self.active[i] = nil
            self.releaseCount = self.releaseCount + 1
            self.resetFn(node)
            node:SetEnabled(false)
            return
        end
    end
end

--- Release all active nodes.
function ObjectPool:releaseAll()
    for i = 1, #self.nodes do
        if self.active[i] then
            self.active[i] = nil
            self.releaseCount = self.releaseCount + 1
            self.resetFn(self.nodes[i])
            self.nodes[i]:SetEnabled(false)
        end
    end
end

--- Get count of currently active nodes.
--- @return number
function ObjectPool:getActiveCount()
    local count = 0
    for _ in pairs(self.active) do
        count = count + 1
    end
    return count
end

--- Get pool metrics for diagnostics.
--- @return table {capacity, active, acquires, releases, highWater, misses}
function ObjectPool:getMetrics()
    return {
        capacity = self.capacity,
        active   = self:getActiveCount(),
        acquires = self.acquireCount,
        releases = self.releaseCount,
        highWater = self.highWater,
        misses   = self.missCount,
    }
end

--- Destroy the pool and remove all nodes from the scene.
function ObjectPool:destroy()
    for i = 1, #self.nodes do
        if self.nodes[i] then
            self.nodes[i]:Remove()
        end
    end
    self.nodes  = {}
    self.active = {}
end

return ObjectPool
```

---

## Typed Pool Variants

### Bullet Pool

```lua
local ObjectPool = require("ObjectPool")

local function createBullet(scene)
    local node = scene:CreateChild("Bullet")
    node:SetScale(0.1)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    model:SetMaterial(cache:GetResource("Material",
        "Materials/DefaultGrey.xml"))
    model:SetDrawDistance(80.0)  -- don't render distant bullets
    return node
end

local function resetBullet(node)
    node.position = Vector3(0, -999, 0)
    -- If using RigidBody:
    -- local body = node:GetComponent("RigidBody")
    -- if body then
    --     body:SetLinearVelocity(Vector3.ZERO)
    --     body:SetAngularVelocity(Vector3.ZERO)
    -- end
end

bulletPool = ObjectPool.new(scene_, 100, createBullet, resetBullet)
```

### Enemy Pool

```lua
local function createEnemy(scene)
    local node = scene:CreateChild("Enemy")
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetDrawDistance(120.0)
    -- Pre-create components
    node:CreateComponent("RigidBody")
    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
    return node
end

local function resetEnemy(node)
    node.position = Vector3(0, -999, 0)
    local body = node:GetComponent("RigidBody")
    body:SetLinearVelocity(Vector3.ZERO)
    body:SetAngularVelocity(Vector3.ZERO)
end

enemyPool = ObjectPool.new(scene_, 30, createEnemy, resetEnemy, true)  -- auto-grow
```

### 2D Sprite Pool (Box2D)

```lua
local function createProjectile(scene)
    local node = scene:CreateChild("Proj")
    local sprite = node:CreateComponent("StaticSprite2D")
    sprite:SetSprite(cache:GetResource("Sprite2D", "Textures/bullet.png"))
    local body = node:CreateComponent("RigidBody2D")
    body:SetBodyType(BT_DYNAMIC)
    body:SetBullet(true)
    local shape = node:CreateComponent("CollisionCircle2D")
    shape:SetRadius(0.1)
    return node
end

projectilePool = ObjectPool.new(scene_, 200, createProjectile)
```

---

## Usage Patterns

### Fire and Forget

```lua
function fireBullet(origin, direction, speed)
    local bullet = bulletPool:acquire()
    if not bullet then return end  -- pool exhausted
    bullet.position = origin
    bullet:SetDirection(direction)
    -- Store velocity in a Lua table keyed by node ID
    activeBullets[bullet:GetID()] = {
        node = bullet,
        velocity = direction * speed,
        lifetime = 3.0,
    }
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    for id, b in pairs(activeBullets) do
        b.lifetime = b.lifetime - dt
        if b.lifetime <= 0 then
            bulletPool:release(b.node)
            activeBullets[id] = nil
        else
            b.node:Translate(b.velocity * dt)
        end
    end
end
```

### Wave Spawner

```lua
function spawnWave(count)
    for i = 1, count do
        local enemy = enemyPool:acquire()
        if not enemy then break end  -- pool exhausted
        local angle = (i / count) * 2 * math.pi
        enemy.position = Vector3(math.cos(angle) * 20, 1, math.sin(angle) * 20)
    end
end

function onEnemyKilled(enemyNode)
    enemyPool:release(enemyNode)
end
```

### Pool Diagnostics

```lua
-- Print pool stats (bind to a debug key)
if input:GetKeyPress(KEY_F11) then
    local m = bulletPool:getMetrics()
    print(string.format(
        "Bullet Pool: %d/%d active, high-water=%d, misses=%d",
        m.active, m.capacity, m.highWater, m.misses
    ))
end
```

---

## Pool Sizing Guide

| Object Type | Typical Size | Notes |
|------------|-------------|-------|
| Bullets / projectiles | 50–200 | Short lifetime, high spawn rate |
| Enemies (wave spawner) | 20–50 | Medium lifetime, batch spawn |
| Particles / effects | 100–500 | Very short lifetime |
| Collectibles | 20–50 | Placed at level load |
| Audio sources | 8–16 | Shared, reuse after done |

**Rule of thumb**: Pool size = peak concurrent count × 1.2 (20% headroom).

Use `highWater` metric after a full gameplay session to right-size.

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Forgot `SetEnabled(false)` on release | Pool template includes it automatically |
| Node still visible after release | Move to `(0, -999, 0)` in resetFn |
| RigidBody retains velocity after release | Reset linear + angular velocity in resetFn |
| Pool grows unbounded | Use `autoGrow = false` (default) or cap growth |
| Acquiring from empty pool crashes | `acquire()` returns nil — always nil-check |
| Components queried each frame | Create all components at pool init, cache references |
| Collision events fire on disabled nodes | UrhoX skips disabled nodes — no issue |
