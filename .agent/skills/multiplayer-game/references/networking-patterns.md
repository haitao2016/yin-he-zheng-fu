# Networking Patterns Reference

Sync strategies, AOI, chunk partitioning, shared simulation, and storage patterns for UrhoX multiplayer games.

## Table of Contents

1. [Sync Strategy Comparison](#1-sync-strategy-comparison)
2. [Snapshot + Diff Pattern](#2-snapshot--diff-pattern)
3. [Client Prediction & Reconciliation](#3-client-prediction--reconciliation)
4. [Remote Player Interpolation](#4-remote-player-interpolation)
5. [Area of Interest (AOI)](#5-area-of-interest-aoi)
6. [Chunk-Based Partitioning](#6-chunk-based-partitioning)
7. [Shared Simulation Logic](#7-shared-simulation-logic)
8. [Network Priority & Bandwidth](#8-network-priority--bandwidth)
9. [Tick Rate Guidelines](#9-tick-rate-guidelines)
10. [Storage Patterns](#10-storage-patterns)

---

## 1. Sync Strategy Comparison

| Strategy | Bandwidth | Latency Tolerance | Cheat Resistance | UrhoX Support |
|---|---|---|---|---|
| State sync (basic) | Medium | Good | Good | Native (REPLICATED nodes) |
| State sync + prediction | Medium-High | Best | Good | Manual implementation |
| Frame sync (lockstep) | Low | Poor | Fair | Manual implementation |
| Event-driven | Very Low | N/A | Good | Native (RemoteEvent) |

**Recommendation**: Use state sync for most games. Frame sync only for RTS/MOBA where determinism is critical.

---

## 2. Snapshot + Diff Pattern

Send a full snapshot on join/resync, then incremental diffs per tick.

```lua
-- Server: full snapshot for new client
function SendFullSnapshot(conn)
    local msg = VectorBuffer()
    msg:WriteUInt(#entities)
    for _, e in ipairs(entities) do
        msg:WriteUInt(e.id)
        msg:WriteVector3(e.position)
        msg:WriteQuaternion(e.rotation)
        msg:WriteInt(e.health)
        msg:WriteUByte(e.state)
    end
    conn:SendMessage(MSG_FULL_SNAPSHOT, true, true, msg)
end

-- Server: per-tick diff (only changed entities)
function SendDiff()
    local msg = VectorBuffer()
    local changed = GetChangedEntities()
    msg:WriteUInt(#changed)
    for _, e in ipairs(changed) do
        msg:WriteUInt(e.id)
        local flags = 0
        if e.posChanged then flags = flags | 0x01 end
        if e.rotChanged then flags = flags | 0x02 end
        if e.hpChanged  then flags = flags | 0x04 end
        msg:WriteUByte(flags)
        if flags & 0x01 ~= 0 then msg:WriteVector3(e.position) end
        if flags & 0x02 ~= 0 then msg:WriteQuaternion(e.rotation) end
        if flags & 0x04 ~= 0 then msg:WriteInt(e.health) end
    end
    network:BroadcastMessage(MSG_DIFF, true, false, msg)  -- unreliable for frequent diffs
end
```

---

## 3. Client Prediction & Reconciliation

For hybrid netcode (client owns movement):

```lua
-- Client side
local inputHistory = {}  -- circular buffer of {seq, input, predictedPos}
local inputSeq = 0

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 1. Gather input
    local input = GatherInput()
    inputSeq = inputSeq + 1

    -- 2. Predict locally
    local predictedPos = ApplyMovement(localPlayer.position, input, dt)
    localPlayer.position = predictedPos

    -- 3. Store for reconciliation
    inputHistory[inputSeq % BUFFER_SIZE] = {
        seq = inputSeq, input = input, pos = predictedPos
    }

    -- 4. Send to server
    local msg = VectorBuffer()
    msg:WriteUInt(inputSeq)
    msg:WriteVector3(input.moveDir)
    msg:WriteBool(input.jump)
    network:GetServerConnection():SendMessage(MSG_INPUT, true, true, msg)
end

-- On server correction
function HandleServerCorrection(serverSeq, serverPos)
    -- Discard acknowledged inputs
    -- If position mismatch > threshold, snap and replay unacked inputs
    if (localPlayer.position - serverPos):Length() > 0.1 then
        localPlayer.position = serverPos
        -- Replay inputs from serverSeq+1 to current inputSeq
        for seq = serverSeq + 1, inputSeq do
            local entry = inputHistory[seq % BUFFER_SIZE]
            if entry then
                localPlayer.position = ApplyMovement(localPlayer.position, entry.input, FIXED_DT)
            end
        end
    end
end
```

---

## 4. Remote Player Interpolation

Never snap remote players to server positions — interpolate for smoothness:

```lua
-- Per remote player state
local remoteState = {
    prevPos = Vector3.ZERO,
    targetPos = Vector3.ZERO,
    prevRot = Quaternion.IDENTITY,
    targetRot = Quaternion.IDENTITY,
    interpTime = 0,
    interpDuration = 0.1,  -- match server tick interval
}

function UpdateRemotePlayer(node, state, dt)
    state.interpTime = state.interpTime + dt
    local t = math.min(1.0, state.interpTime / state.interpDuration)

    node.position = Lerp(state.prevPos, state.targetPos, t)
    node.rotation = state.prevRot:Slerp(state.targetRot, t)
end

function OnNewServerState(state, newPos, newRot)
    state.prevPos = state.targetPos
    state.prevRot = state.targetRot
    state.targetPos = newPos
    state.targetRot = newRot
    state.interpTime = 0
end
```

---

## 5. Area of Interest (AOI)

For games with many entities, only send relevant data to each client.

```lua
local AOI_RADIUS = 50.0  -- meters

function UpdateAOI(player)
    local nearbyEntities = GetEntitiesInRadius(player.position, AOI_RADIUS)

    -- Entities entering view
    for _, entity in ipairs(nearbyEntities) do
        if not player.visibleEntities[entity.id] then
            player.visibleEntities[entity.id] = true
            SendEntityEnter(player.connection, entity)  -- full state
        end
    end

    -- Entities leaving view
    for id, _ in pairs(player.visibleEntities) do
        local entity = entities[id]
        if not entity or (player.position - entity.position):Length() > AOI_RADIUS then
            player.visibleEntities[id] = nil
            SendEntityLeave(player.connection, id)
        end
    end
end
```

**When to use AOI**:
- Player count > 20
- Large game world (> 100m across)
- Entities have private state (fog of war)

**When to skip AOI**:
- Small arena (<20 players, full visibility)
- Turn-based games

---

## 6. Chunk-Based Partitioning

For large persistent worlds, partition into independently managed chunks.

```lua
local CHUNK_SIZE = 16  -- 16x16 meter chunks

function GetChunkKey(worldX, worldZ)
    local cx = math.floor(worldX / CHUNK_SIZE)
    local cz = math.floor(worldZ / CHUNK_SIZE)
    return cx .. "," .. cz
end

-- Client subscribes to nearby chunks (3x3 window)
function UpdateChunkSubscriptions(player)
    local cx = math.floor(player.position.x / CHUNK_SIZE)
    local cz = math.floor(player.position.z / CHUNK_SIZE)

    local newChunks = {}
    for dx = -1, 1 do
        for dz = -1, 1 do
            local key = (cx + dx) .. "," .. (cz + dz)
            newChunks[key] = true
        end
    end

    -- Subscribe to new chunks
    for key, _ in pairs(newChunks) do
        if not player.subscribedChunks[key] then
            SubscribePlayerToChunk(player, key)
        end
    end

    -- Unsubscribe from old chunks
    for key, _ in pairs(player.subscribedChunks) do
        if not newChunks[key] then
            UnsubscribePlayerFromChunk(player, key)
        end
    end

    player.subscribedChunks = newChunks
end
```

**Use sparingly**: Only when world is large and state-heavy. Don't over-engineer small matches.

---

## 7. Shared Simulation Logic

Code that runs identically on client (prediction) and server (authority). Keep it pure and deterministic.

**What belongs in shared/**:
- Movement integration (`ApplyMovement(pos, vel, dt)`)
- Input transforms (button → action mapping)
- Collision helpers (AABB, radius checks)
- Constants (speeds, gravity, bounds)

**What does NOT belong in shared/**:
- Network calls
- Scene manipulation
- UI code
- Random number generation (server-authoritative seed only)

```lua
-- shared/Movement.lua
local Movement = {}

function Movement.ApplyInput(pos, input, speed, dt)
    local vel = input.direction * speed
    return pos + vel * dt
end

function Movement.ClampToWorldBounds(pos, bounds)
    return Vector3(
        math.max(bounds.minX, math.min(bounds.maxX, pos.x)),
        pos.y,
        math.max(bounds.minZ, math.min(bounds.maxZ, pos.z))
    )
end

return Movement
```

---

## 8. Network Priority & Bandwidth

Use UrhoX's `NetworkPriority` component for automatic priority-based updates:

```lua
local priority = node:CreateComponent("NetworkPriority")
priority.basePriority = 100.0     -- higher = more frequent updates
priority.distanceFactor = 0.5     -- reduce priority with distance
priority.minPriority = 10.0       -- floor priority
priority.alwaysUpdateOwner = true  -- always send to controlling client
```

**Manual bandwidth optimization**:

| Data Type | Reliable | Ordered | Frequency |
|---|---|---|---|
| Position/rotation | No | No | Every tick |
| Health/score changes | Yes | Yes | On event |
| Chat messages | Yes | Yes | On event |
| Shoot/hit events | Yes | Yes | On event |
| Environment state | Yes | Yes | 1 Hz or on change |
| Full snapshot (resync) | Yes | Yes | On join/resync |

---

## 9. Tick Rate Guidelines

| Genre | Server Tick | Client Send | Notes |
|---|---|---|---|
| Competitive FPS | 60 Hz | 60 Hz | Highest fidelity |
| Arena/Action | 20 Hz | 20 Hz | Good balance |
| IO / Casual | 10 Hz | 10 Hz | Sufficient for simple movement |
| Open World (per chunk) | 10 Hz | 10 Hz | Scale = active chunks × tick |
| Turn-based | Event-driven | Event-driven | No tick loop |
| Idle | Scheduled (5-15 min) | On action | Coarse intervals + catch-up |

Set via:
```lua
network.updateFps = 20  -- server-side tick rate
```

---

## 10. Storage Patterns

| Storage | Best For | UrhoX Approach |
|---|---|---|
| In-memory (Lua tables) | Realtime game state (positions, inputs, phase) | Default — fast, lost on crash |
| Cloud variables (`clientCloud`) | Player scores, leaderboards, progression | Built-in API (see `recipes/client-cloud-score.md`) |
| Local file (`File` API) | Save games, settings, replays | Sandboxed file I/O (see `recipes/file-storage.md`) |
| Server cloud (`serverCloud`) | Authoritative player data, match history | Server-side API (see `recipes/server-cloud-score.md`) |

**Rule**: Use in-memory for per-tick game state. Use cloud/file storage for persistent data that survives match end.
