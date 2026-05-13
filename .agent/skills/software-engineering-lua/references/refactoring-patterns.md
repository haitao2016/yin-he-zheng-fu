# Lua Refactoring Patterns — Complete Catalog

A comprehensive collection of refactoring techniques adapted for UrhoX Lua game code, with concrete before/after examples.

---

## 1. Extract Function

**When**: A block of code can be grouped by a single purpose.

```lua
-- BEFORE
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- Move player
    local moveDir = Vector3.ZERO
    if input:GetKeyDown(KEY_W) then moveDir = moveDir + Vector3.FORWARD end
    if input:GetKeyDown(KEY_S) then moveDir = moveDir + Vector3.BACK end
    if input:GetKeyDown(KEY_A) then moveDir = moveDir + Vector3.LEFT end
    if input:GetKeyDown(KEY_D) then moveDir = moveDir + Vector3.RIGHT end
    if moveDir:Length() > 0 then
        moveDir = moveDir:Normalized()
        playerNode.position = playerNode.position + moveDir * MOVE_SPEED * dt
    end

    -- Update enemies
    for i = 1, #enemies do
        local e = enemies[i]
        local toPlayer = playerNode.position - e.node.position
        if toPlayer:Length() < AGGRO_RANGE then
            local dir = toPlayer:Normalized()
            e.node.position = e.node.position + dir * e.speed * dt
        end
    end

    -- Update UI
    hpText.text = "HP: " .. playerHp
    scoreText.text = "Score: " .. score
end

-- AFTER
local function getInputDirection()
    local dir = Vector3.ZERO
    if input:GetKeyDown(KEY_W) then dir = dir + Vector3.FORWARD end
    if input:GetKeyDown(KEY_S) then dir = dir + Vector3.BACK end
    if input:GetKeyDown(KEY_A) then dir = dir + Vector3.LEFT end
    if input:GetKeyDown(KEY_D) then dir = dir + Vector3.RIGHT end
    if dir:Length() > 0 then dir = dir:Normalized() end
    return dir
end

local function updatePlayerMovement(dt)
    local dir = getInputDirection()
    if dir:Length() > 0 then
        playerNode.position = playerNode.position + dir * MOVE_SPEED * dt
    end
end

local function updateEnemies(dt)
    for i = 1, #enemies do
        local e = enemies[i]
        local toPlayer = playerNode.position - e.node.position
        if toPlayer:Length() < AGGRO_RANGE then
            e.node.position = e.node.position + toPlayer:Normalized() * e.speed * dt
        end
    end
end

local function updateHUD()
    hpText.text = "HP: " .. playerHp
    scoreText.text = "Score: " .. score
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    updatePlayerMovement(dt)
    updateEnemies(dt)
    updateHUD()
end
```

---

## 2. Replace Global State with Module Table

**When**: Multiple related globals clutter the namespace and risk name collision.

```lua
-- BEFORE: Global soup
playerHp = 100
playerScore = 0
playerName = "Hero"
playerNode = nil
playerSpeed = 5.0

-- AFTER: Module table
local Player = {
    hp = 100,
    score = 0,
    name = "Hero",
    node = nil,
    speed = 5.0,
}

-- Access: Player.hp, Player.score, etc.
return Player
```

---

## 3. Replace Magic Strings with Constant Table

**When**: String comparisons appear in multiple places for state management.

```lua
-- BEFORE: Stringly typed
if gameState == "menu" then ... end
if gameState == "playing" then ... end
if gameState == "gameover" then ... end
-- Typo risk: "plaing" would silently fail

-- AFTER: Constant table
local STATE = {
    MENU     = "menu",
    PLAYING  = "playing",
    PAUSED   = "paused",
    GAMEOVER = "gameover",
}

if gameState == STATE.PLAYING then ... end
-- Typo: STATE.PLAING → error "attempt to index nil" → caught immediately
```

---

## 4. Replace Nested Conditionals with Lookup Table

**When**: Long if/elseif chains map input to actions.

```lua
-- BEFORE: Long conditional chain
function HandleKeyPress(key)
    if key == KEY_1 then
        selectWeapon(1)
    elseif key == KEY_2 then
        selectWeapon(2)
    elseif key == KEY_3 then
        selectWeapon(3)
    elseif key == KEY_SPACE then
        jump()
    elseif key == KEY_E then
        interact()
    elseif key == KEY_R then
        reload()
    elseif key == KEY_ESCAPE then
        togglePause()
    end
end

-- AFTER: Lookup table
local KEY_ACTIONS = {
    [KEY_1]      = function() selectWeapon(1) end,
    [KEY_2]      = function() selectWeapon(2) end,
    [KEY_3]      = function() selectWeapon(3) end,
    [KEY_SPACE]  = jump,
    [KEY_E]      = interact,
    [KEY_R]      = reload,
    [KEY_ESCAPE] = togglePause,
}

function HandleKeyPress(key)
    local action = KEY_ACTIONS[key]
    if action then action() end
end
```

---

## 5. Replace Constructor Parameters with Config Table

**When**: Functions or constructors take 4+ positional arguments.

```lua
-- BEFORE
function SpawnEnemy(name, model, hp, speed, damage, patrolRadius, aggroRange, loot)
    -- hard to read at call site, easy to mix up order
end
SpawnEnemy("Orc", "Models/Orc.mdl", 200, 3.5, 25, 10, 15, {"gold", "sword"})

-- AFTER
function SpawnEnemy(config)
    local name         = config.name         or "Enemy"
    local model        = config.model        or "Models/Box.mdl"
    local hp           = config.hp           or 100
    local speed        = config.speed        or 3.0
    local damage       = config.damage       or 10
    local patrolRadius = config.patrolRadius or 5.0
    local aggroRange   = config.aggroRange   or 10.0
    local loot         = config.loot         or {}
    -- ...
end
SpawnEnemy {
    name = "Orc",
    model = "Models/Orc.mdl",
    hp = 200,
    speed = 3.5,
    damage = 25,
    patrolRadius = 10,
    aggroRange = 15,
    loot = { "gold", "sword" },
}
```

---

## 6. Extract Class (OOP Module)

**When**: A set of functions all operate on the same data, indicating a hidden class.

```lua
-- BEFORE: Procedural functions operating on a shared table
local bulletData = {}

function createBullet(pos, dir, speed)
    table.insert(bulletData, { pos = pos, dir = dir, speed = speed, alive = true })
end

function updateBullets(dt)
    for i = #bulletData, 1, -1 do
        local b = bulletData[i]
        b.pos = b.pos + b.dir * b.speed * dt
        if b.pos:Length() > 100 then
            table.remove(bulletData, i)
        end
    end
end

-- AFTER: OOP module
local Bullet = {}
Bullet.__index = Bullet

function Bullet.new(pos, dir, speed)
    return setmetatable({
        pos = pos, dir = dir, speed = speed or 20.0, alive = true,
    }, Bullet)
end

function Bullet:Update(dt)
    self.pos = self.pos + self.dir * self.speed * dt
    if self.pos:Length() > 100 then
        self.alive = false
    end
end

return Bullet
```

---

## 7. Replace Repeated Event Setup with Registration Helper

**When**: Multiple nodes subscribe to the same event pattern with similar boilerplate.

```lua
-- BEFORE: Repetitive event subscriptions
SubscribeToEvent(coin1, "NodeCollisionStart", function(_, eventData)
    local other = eventData["OtherNode"]:GetPtr("Node")
    if other == playerNode then collectCoin(coin1) end
end)
SubscribeToEvent(coin2, "NodeCollisionStart", function(_, eventData)
    local other = eventData["OtherNode"]:GetPtr("Node")
    if other == playerNode then collectCoin(coin2) end
end)
-- repeated for each coin...

-- AFTER: Registration helper
local function registerCollectible(node, collectFn)
    SubscribeToEvent(node, "NodeCollisionStart", function(_, eventData)
        local other = eventData["OtherNode"]:GetPtr("Node")
        if other == playerNode then collectFn(node) end
    end)
end

for _, coin in ipairs(coins) do
    registerCollectible(coin, collectCoin)
end
```

---

## 8. Introduce State Machine for Complex Game States

**When**: Multiple booleans or string comparisons manage game state transitions.

```lua
-- BEFORE: Boolean soup
local isMenu = true
local isPlaying = false
local isPaused = false
local isGameOver = false

function changeToPlaying()
    isMenu = false; isPlaying = true; isPaused = false; isGameOver = false
end
-- Easy to forget one, causing invalid combined state

-- AFTER: State machine
local GameState = {
    current = "menu",

    transitions = {
        menu     = { play = "playing" },
        playing  = { pause = "paused", die = "gameover" },
        paused   = { resume = "playing", quit = "menu" },
        gameover = { restart = "playing", quit = "menu" },
    },

    transition = function(self, action)
        local newState = self.transitions[self.current]
            and self.transitions[self.current][action]
        if newState then
            self.current = newState
            return true
        end
        print("[GameState] Invalid: " .. self.current .. " -> " .. action)
        return false
    end,

    is = function(self, state)
        return self.current == state
    end,
}

-- Usage:
GameState:transition("play")      -- menu → playing
if GameState:is("playing") then ... end
```

---

## 9. Pull Up Repeated Cleanup into Destructor Pattern

**When**: Multiple places need to clean up the same resources (nodes, events, timers).

```lua
-- BEFORE: Cleanup scattered and easy to forget
function removeEnemy(enemy)
    if enemy.node then enemy.node:Remove() end
    if enemy.hpBar then enemy.hpBar:Remove() end
    -- forgot to unsubscribe event — memory leak\!
end

-- AFTER: Destructor pattern
function Enemy:Destroy()
    -- Unsubscribe events
    if self._eventSub then
        UnsubscribeFromEvent(self._eventSub)
        self._eventSub = nil
    end
    -- Remove nodes
    if self.hpBarNode then
        self.hpBarNode:Remove()
        self.hpBarNode = nil
    end
    if self.node then
        self.node:Remove()
        self.node = nil
    end
    -- Clear references
    self.alive = false
end
```

---

## 10. Flatten Callback Hell with Sequential Functions

**When**: Deeply nested callbacks make flow hard to follow.

```lua
-- BEFORE: Callback nesting
Tween.to(node, 0.3, { scaleX = 1.2, scaleY = 0.8 }, {
    onComplete = function()
        Tween.to(node, 0.2, { scaleX = 0.9, scaleY = 1.1 }, {
            onComplete = function()
                Tween.to(node, 0.15, { scaleX = 1.0, scaleY = 1.0 }, {
                    onComplete = function()
                        onBounceComplete()
                    end,
                })
            end,
        })
    end,
})

-- AFTER: Sequence (uses soyoyo_tween Tween.sequence)
Tween.sequence {
    Tween.to(node, 0.3,  { scaleX = 1.2, scaleY = 0.8  }),
    Tween.to(node, 0.2,  { scaleX = 0.9, scaleY = 1.1  }),
    Tween.to(node, 0.15, { scaleX = 1.0, scaleY = 1.0  }),
    Tween.callback(onBounceComplete),
}
```

---

## 11. Separate Data from Logic

**When**: Game configuration (stats, levels, items) is mixed with logic.

```lua
-- BEFORE: Data embedded in logic
function createLevel1()
    spawnEnemy("Goblin", Vector3(10, 0, 5), 50, 3.0)
    spawnEnemy("Orc", Vector3(20, 0, 10), 200, 2.0)
    spawnEnemy("Goblin", Vector3(15, 0, 8), 50, 3.0)
end

function createLevel2()
    spawnEnemy("Dragon", Vector3(30, 0, 0), 500, 1.5)
    spawnEnemy("Orc", Vector3(25, 0, 5), 200, 2.0)
end

-- AFTER: Data-driven
local LEVELS = {
    [1] = {
        { type = "Goblin", pos = Vector3(10, 0, 5) },
        { type = "Orc",    pos = Vector3(20, 0, 10) },
        { type = "Goblin", pos = Vector3(15, 0, 8) },
    },
    [2] = {
        { type = "Dragon", pos = Vector3(30, 0, 0) },
        { type = "Orc",    pos = Vector3(25, 0, 5) },
    },
}

local ENEMY_STATS = {
    Goblin = { hp = 50,  speed = 3.0 },
    Orc    = { hp = 200, speed = 2.0 },
    Dragon = { hp = 500, speed = 1.5 },
}

function createLevel(levelNum)
    for _, spawn in ipairs(LEVELS[levelNum]) do
        local stats = ENEMY_STATS[spawn.type]
        spawnEnemy(spawn.type, spawn.pos, stats.hp, stats.speed)
    end
end
```

---

## 12. Introduce Object Pool for Frequent Spawn/Destroy

**When**: Objects are created and destroyed frequently (bullets, particles, coins).

```lua
local Pool = {}
Pool.__index = Pool

function Pool.new(createFn, resetFn, initialSize)
    local self = setmetatable({
        _createFn = createFn,
        _resetFn  = resetFn,
        _inactive = {},
    }, Pool)
    for _ = 1, (initialSize or 10) do
        local obj = createFn()
        obj.node.enabled = false
        table.insert(self._inactive, obj)
    end
    return self
end

function Pool:Get()
    local obj
    if #self._inactive > 0 then
        obj = table.remove(self._inactive)
    else
        obj = self._createFn()
    end
    obj.node.enabled = true
    return obj
end

function Pool:Return(obj)
    obj.node.enabled = false
    if self._resetFn then self._resetFn(obj) end
    table.insert(self._inactive, obj)
end
```

---

## Refactoring Safety Checklist

Before refactoring, verify:

- [ ] Code works correctly before you start (test baseline)
- [ ] Make **one change at a time** — no batch refactoring
- [ ] Build and test after each change
- [ ] Behavior is unchanged (same inputs → same outputs)
- [ ] No new globals introduced
- [ ] All references to renamed functions/variables updated
- [ ] Dead code removed (not just commented out)
