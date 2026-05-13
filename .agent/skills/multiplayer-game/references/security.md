# Security & Anti-Cheat Reference

Security patterns, input validation, rate limiting, and movement anti-cheat for UrhoX multiplayer games.

## Table of Contents

1. [Security Baseline](#1-security-baseline)
2. [Identity & Authorization](#2-identity--authorization)
3. [Input Validation](#3-input-validation)
4. [Rate Limiting](#4-rate-limiting)
5. [Movement Anti-Cheat](#5-movement-anti-cheat)
6. [State Integrity](#6-state-integrity)
7. [Common Attack Vectors](#7-common-attack-vectors)

---

## 1. Security Baseline

Apply ALL of these to every multiplayer game, regardless of genre:

| Principle | Implementation |
|---|---|
| **Server is authority** | Server recomputes all derived state. Client is untrusted display terminal. |
| **Validate all input** | Every client message is validated before processing. |
| **Rate limit everything** | Per-connection rate limits on all client-initiated actions. |
| **Minimal data exposure** | Send each client only the data it needs (AOI, team, phase). |
| **Log suspicious activity** | Log rate limit violations, impossible inputs, position anomalies. |

---

## 2. Identity & Authorization

```lua
-- ✅ Use connection object as authoritative identity
function HandleClientConnected(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    -- Server assigns player ID — never accept client-claimed IDs
    local playerId = GeneratePlayerId()
    connectionToPlayer[conn] = playerId
    playerToConnection[playerId] = conn
end

-- ✅ Validate caller is allowed to act on target
function HandlePlayerAction(conn, targetId, action)
    local callerId = connectionToPlayer[conn]
    if not callerId then return end  -- unknown connection

    -- Can only act on own entities (unless game rules allow otherwise)
    if targetId ~= callerId and not IsAllowedAction(callerId, targetId, action) then
        LogSuspicious(conn, "unauthorized action on " .. targetId)
        return
    end

    ProcessAction(callerId, targetId, action)
end
```

---

## 3. Input Validation

Validate every field in every message from clients:

```lua
function ValidatePlayerInput(data)
    local moveDir = data:ReadVector3()
    local jump = data:ReadBool()

    -- Clamp movement direction to unit length
    local len = moveDir:Length()
    if len > 1.001 then
        moveDir = moveDir / len  -- normalize, don't reject (may be floating point)
    end

    -- Validate enum values
    -- (example: weapon slot must be 1-3)
    local weaponSlot = data:ReadInt()
    if weaponSlot < 1 or weaponSlot > 3 then
        weaponSlot = 1  -- fallback to default
    end

    return { moveDir = moveDir, jump = jump, weaponSlot = weaponSlot }
end

-- String validation (chat, usernames)
function ValidateString(str, maxLen)
    if not str or #str == 0 then return nil end
    if #str > maxLen then
        str = str:sub(1, maxLen)  -- truncate
    end
    -- Strip control characters
    str = str:gsub("[%c]", "")
    return str
end
```

---

## 4. Rate Limiting

Per-connection rate limits prevent spam and abuse:

```lua
local RateLimiter = {}

function RateLimiter.Create(maxPerSecond)
    return {
        maxPerSecond = maxPerSecond,
        tokens = maxPerSecond,
        lastRefill = os.clock(),
    }
end

function RateLimiter.Allow(limiter)
    local now = os.clock()
    local elapsed = now - limiter.lastRefill

    -- Refill tokens
    limiter.tokens = math.min(
        limiter.maxPerSecond,
        limiter.tokens + elapsed * limiter.maxPerSecond
    )
    limiter.lastRefill = now

    if limiter.tokens >= 1.0 then
        limiter.tokens = limiter.tokens - 1.0
        return true
    end
    return false
end

-- Usage per connection
local chatLimiters = {}   -- conn → RateLimiter
local moveLimiters = {}   -- conn → RateLimiter

function HandleChatMessage(conn, message)
    if not chatLimiters[conn] then
        chatLimiters[conn] = RateLimiter.Create(3)  -- 3 messages/sec max
    end
    if not RateLimiter.Allow(chatLimiters[conn]) then
        LogSuspicious(conn, "chat rate limit exceeded")
        return  -- silently drop
    end
    -- Process chat message...
end

function HandleMovementUpdate(conn, data)
    if not moveLimiters[conn] then
        moveLimiters[conn] = RateLimiter.Create(20)  -- 20 updates/sec max
    end
    if not RateLimiter.Allow(moveLimiters[conn]) then
        return  -- drop excess movement updates
    end
    -- Process movement...
end
```

**Recommended limits**:

| Action | Max Rate |
|---|---|
| Movement updates | 20/sec (match tick rate) |
| Chat messages | 3/sec |
| Fire/attack | 10/sec |
| Join/leave | 1/sec |
| Item pickup | 5/sec |

---

## 5. Movement Anti-Cheat

For hybrid netcode (client sends positions), validate on server:

```lua
local MAX_SPEED = 10.0       -- meters/sec (game's max move speed)
local SPEED_TOLERANCE = 1.3  -- 30% tolerance for network jitter
local WORLD_BOUNDS = { minX = -100, maxX = 100, minZ = -100, maxZ = 100, minY = -5, maxY = 50 }

function ValidateMovement(player, newPos, dt)
    local oldPos = player.lastValidatedPos
    local delta = (newPos - oldPos):Length()
    local maxDelta = MAX_SPEED * SPEED_TOLERANCE * dt

    -- 1. Speed check: reject teleports
    if delta > maxDelta then
        LogSuspicious(player.conn, string.format(
            "speed hack? delta=%.2f max=%.2f", delta, maxDelta
        ))
        -- Option A: Snap back to last valid position
        return oldPos
        -- Option B: Clamp movement to max allowed
        -- local dir = (newPos - oldPos):Normalized()
        -- return oldPos + dir * maxDelta
    end

    -- 2. World bounds check
    if newPos.x < WORLD_BOUNDS.minX or newPos.x > WORLD_BOUNDS.maxX
    or newPos.z < WORLD_BOUNDS.minZ or newPos.z > WORLD_BOUNDS.maxZ
    or newPos.y < WORLD_BOUNDS.minY or newPos.y > WORLD_BOUNDS.maxY then
        LogSuspicious(player.conn, "out of bounds")
        return ClampToWorldBounds(newPos)
    end

    -- 3. Basic collision check (optional, for walls/terrain)
    if CollidesWithWorld(newPos) then
        return oldPos
    end

    -- Valid
    player.lastValidatedPos = newPos
    return newPos
end
```

**Escalation levels**:

| Severity | Action |
|---|---|
| Minor (1-2 violations) | Snap back to last valid position |
| Moderate (repeated violations) | Warn + temporary movement restriction |
| Severe (persistent abuse) | Disconnect client |

---

## 6. State Integrity

Server must be sole authority for all game-critical state:

```lua
-- ❌ WRONG: Trust client-sent HP
function HandleDamageReport(conn, data)
    local targetId = data:ReadInt()
    local newHp = data:ReadInt()  -- NEVER trust this\!
    players[targetId].health = newHp
end

-- ✅ CORRECT: Server calculates damage
function HandleAttackIntent(conn, data)
    local attackerId = connectionToPlayer[conn]
    local targetId = data:ReadInt()

    -- Server validates: is attacker alive? in range? cooldown elapsed?
    if not CanAttack(attackerId, targetId) then return end

    -- Server calculates damage (weapon stats, defense, buffs)
    local damage = CalculateDamage(attackerId, targetId)

    -- Server applies
    players[targetId].health = players[targetId].health - damage

    -- Server broadcasts result
    BroadcastDamageEvent(attackerId, targetId, damage)

    -- Server checks death
    if players[targetId].health <= 0 then
        HandlePlayerDeath(targetId, attackerId)
    end
end
```

**Never trust client for**:
- Health / HP changes
- Score / currency / experience
- Inventory / loot acquisition
- Win conditions / placements
- Cooldown timers
- Random number outcomes

**Client CAN own** (with server validation):
- Movement position (hybrid mode, with anti-cheat)
- Camera orientation
- UI state
- Visual effects (cosmetic only)

---

## 7. Common Attack Vectors

| Attack | Prevention |
|---|---|
| **Speed hack** | Server validates max delta per tick (Section 5) |
| **Teleport** | Reject large position jumps, snap to last valid |
| **Damage hack** | Server-authoritative combat calculations (Section 6) |
| **Item duplication** | Server validates inventory operations, use transactions |
| **Chat spam** | Rate limiting (Section 4) |
| **Identity spoofing** | Use connection object, never client-claimed IDs (Section 2) |
| **Data sniffing** | AOI / interest management — don't send hidden data |
| **Replay attack** | Sequence numbers on inputs, reject stale/duplicate |
| **Resource exhaustion** | Message size limits, connection limits, rate limits |

**Defense-in-depth principle**: Layer multiple protections. No single check is sufficient.
