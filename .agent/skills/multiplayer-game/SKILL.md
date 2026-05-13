---
name: multiplayer-game
description: "Patterns and architecture guide for building multiplayer games, covering game mode selection, networking models, state synchronization, matchmaking, security, and anti-cheat. Use when users need to (1) design multiplayer game architecture, (2) choose netcode model (hybrid, server-authoritative, event-driven), (3) implement matchmaking or lobby systems, (4) set up state synchronization and interest management, (5) add anti-cheat or movement validation, (6) decide tick rate, persistence strategy, or actor topology for any multiplayer genre, file types, or tasks that trigger it."
---

# Multiplayer Game Skill

Pragmatic patterns for building multiplayer games in UrhoX: game mode selection, netcode models, tick loops, state sync, interest management, matchmaking, security, and anti-cheat.

## Trigger Conditions

Activate when ANY of:
- User requests creating a multiplayer game or adding multiplayer to existing game
- `.project/settings.json` has `multiplayer.enabled = true`
- User mentions keywords: "联机", "多人", "对战", "合作", "matchmaking", "lobby", "同步"

## Pre-Check

```bash
cat .project/settings.json   # check @runtime.multiplayer.enabled
```

## File Structure

```
scripts/
├── main.lua                    # Entry (auto-routes to Client/Server/Standalone)
├── network/
│   ├── Client.lua              # Client: input, rendering, prediction
│   ├── Server.lua              # Server: authoritative logic, broadcast
│   ├── Standalone.lua          # Offline single-player (optional)
│   ├── Shared.lua              # Shared utilities, constants, materials
│   └── MessageTypes.lua        # Message IDs and serialization helpers
├── shared/
│   ├── GameConfig.lua          # Shared game config (speeds, timers, spawn points)
│   └── Utils.lua               # Pure deterministic helpers (clamp, lerp, collision)
└── components/
    ├── PlayerController.lua
    └── GameManager.lua
```

## Game Classification

Pick the closest match, then see `references/game-modes.md` for full implementation details (lifecycle diagrams, actor topology, tick patterns).

| Classification | Examples | Tick Rate | State Model | Matchmaking |
|---|---|---|---|---|
| **Battle Royale** | Fortnite, PUBG | 10 Hz | Hybrid | Lobby fill → start |
| **Arena** | CS2, Halo, Overwatch | 20 Hz | Hybrid | Queue by mode → full match |
| **IO Style** | Agar.io, Slither.io | 10 Hz | Server-auth + interpolation | Open lobby routing |
| **Open World** | Minecraft, Rust | 10 Hz/chunk | Hybrid or Server-auth | Chunk-based routing |
| **Party** | Fall Guys lobbies | Event-driven | Server-auth (basic) | Host-created codes |
| **Ranked** | Chess ladders, competitive duels | 20 Hz | Hybrid | ELO-based pairing |
| **Turn-Based** | Chess, card games | Event-driven | Server-auth (basic) | Invite or queue |
| **Idle** | Cookie Clicker | Scheduled | Server-auth (basic) | No matchmaker |
| **Casual PvP** | Quiz battles, party sports | 20-30 Hz | Server-auth | Simple state sync |
| **Co-op PvE** | Survival, dungeon crawl | 30 Hz | Server-auth | State sync + AI sync |

## State Model Selection

| Model | When | Client Role | Server Role |
|---|---|---|---|
| **Hybrid** (client movement, server combat) | Shooters, action, ranked | Owns movement + prediction; sends capped-rate position | Validates movement anti-cheat; owns combat, hits, damage |
| **Server-auth + interpolation** | IO style, persistent worlds | Sends input commands; interpolates between snapshots | Simulates on fixed ticks; publishes authoritative snapshots |
| **Server-auth (basic logic)** | Turn-based, event-driven, party | Displays confirmed state only | Validates and applies discrete actions (turns, votes) |

## Core Network API (UrhoX)

### Role Detection & Routing

```lua
-- main.lua
local isServer = network:IsServerRunning()
if isServer then
    require "network.Server"
else
    require "network.Client"
end
```

### Server Essentials

```lua
SubscribeToEvent("ClientConnected", "HandleClientConnected")
SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

function HandleClientConnected(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    conn.scene = scene_
    -- Create player node, assign to connection
end

-- Tick rate control
network.updateFps = 20  -- 20 Hz server tick

-- Broadcast to all clients
network:BroadcastMessage(MSG_ID, true, true, msgBuffer)
network:BroadcastRemoteEvent("GameEvent", true, eventData)

-- Send to specific client
conn:SendMessage(MSG_ID, true, true, msgBuffer)
conn:SendRemoteEvent("PrivateEvent", true, eventData)
```

### Client Essentials

```lua
SubscribeToEvent("ServerConnected", "HandleServerConnected")
SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")

-- Send input to server
local msg = VectorBuffer()
msg:WriteVector3(moveDir)
msg:WriteBool(jump)
network:GetServerConnection():SendMessage(MSG_INPUT, true, true, msg)
```

### Custom Messages & Receive

```lua
MSG_PLAYER_INPUT = 100
MSG_GAME_STATE   = 101
MSG_CHAT         = 102

SubscribeToEvent("NetworkMessage", "HandleNetworkMessage")
function HandleNetworkMessage(eventType, eventData)
    local msgID = eventData["MessageID"]:GetInt()
    local data  = eventData["Data"]:GetBuffer()
    if msgID == MSG_PLAYER_INPUT then
        local moveDir = data:ReadVector3()
        local jump = data:ReadBool()
    end
end
```

### Node Replication

```lua
-- Server: create replicated node (auto-syncs position/rotation to clients)
local node = scene_:CreateChild("Player", REPLICATED)
node.position = Vector3(0, 1, 0)  -- auto-replicated
```

## Network Update Patterns

- **Snapshots + diffs**: Full snapshot on join/resync; per-tick diffs for regular updates.
- **Dirty flags**: Only serialize changed fields to reduce bandwidth.
- **Broadcast vs per-connection**: `BroadcastMessage` for shared state; `conn:SendMessage` for private data (hand cards, fog-of-war).
- **Tick batching**: Batch high-frequency updates (positions) per server tick rather than per-event.

```lua
-- Dirty-flag bandwidth optimization
local dirtyFlags = 0
if posChanged then dirtyFlags = dirtyFlags | 0x01 end
if rotChanged then dirtyFlags = dirtyFlags | 0x02 end
if hpChanged  then dirtyFlags = dirtyFlags | 0x04 end
msg:WriteUByte(dirtyFlags)
if dirtyFlags & 0x01 ~= 0 then msg:WriteVector3(pos) end
if dirtyFlags & 0x02 ~= 0 then msg:WriteQuaternion(rot) end
if dirtyFlags & 0x04 ~= 0 then msg:WriteInt(hp) end
```

## Client Prediction & Reconciliation

```lua
-- Client: predict locally, send input, reconcile on server correction
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    local input = GatherInput()
    PredictMovement(localPlayer, input, dt)  -- immediate local feedback
    SendInputToServer(input)
end

function HandleServerState(state)
    if (localPlayer.position - state.position):Length() > THRESHOLD then
        localPlayer.position = state.position
        ReplayPendingInputs()  -- re-simulate unacknowledged inputs
    end
end
```

## Interest Management

- **Filter by relevance**: Send each client only nearby/visible/team-relevant state.
- **AOI radius**: Typical 50m for MMO, full-map for arena (<20 players).
- **Chunk partitioning**: For large worlds, partition by chunks; clients subscribe to nearby chunks only.
- **Server-side only**: Clients must never receive hidden data (fog of war, enemy positions behind walls).

→ Full AOI and chunk-based details in `references/networking-patterns.md`

## Security Baseline

| Area | Rule |
|---|---|
| **Authority** | Server recomputes all derived state (HP, score, win). Never trust client values. |
| **Identity** | Use connection object as authoritative identity, not client-sent IDs. |
| **Input validation** | Clamp sizes/lengths, validate enums, reject impossible values. |
| **Rate limiting** | Per-connection limits for spammy actions (chat, fire, movement). |
| **Movement anti-cheat** | Enforce max delta per tick (speed cap), reject teleports, enforce world bounds. |

→ Full security patterns and code examples in `references/security.md`

## Common Pitfalls

### 1. Client-authoritative combat
```lua
-- ❌ Client calculates damage directly
player.health = player.health - damage

-- ✅ Client sends intent, server validates and applies
SendToServer(MSG_HIT, { targetId = id })
```

### 2. No interpolation for remote players
```lua
-- ✅ Smooth remote player movement
local alpha = math.min(1.0, dt * INTERP_SPEED)
remoteNode.position = Lerp(remoteNode.position, targetPos, alpha)
remoteNode.rotation = remoteNode.rotation:Slerp(targetRot, alpha)
```

### 3. Missing disconnect cleanup
```lua
-- ✅ Always clean up on disconnect
function HandleClientDisconnected(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    RemovePlayerNode(conn)
    RemoveFromScoreboard(conn)
    BroadcastPlayerLeft(conn)
end
```

### 4. Ignoring shared simulation code
```lua
-- ✅ Keep deterministic helpers in shared/ for both client prediction and server validation
-- shared/Utils.lua
function ApplyMovement(pos, velocity, dt)
    return pos + velocity * dt
end
-- Used by BOTH Client.lua (prediction) and Server.lua (authority)
```

## Checklist

Before submitting multiplayer code:

- [ ] Read `.project/settings.json` to confirm `multiplayer.enabled`
- [ ] Server handles all authoritative logic (HP, score, hit detection)
- [ ] Client only collects input and renders
- [ ] Disconnect cleanup implemented (remove nodes, update scoreboard, broadcast)
- [ ] Remote players use position interpolation
- [ ] Messages use reasonable send frequency (match tick rate to genre)
- [ ] Input validated and rate-limited on server
- [ ] Shared simulation logic in `shared/` for prediction + validation
- [ ] Tested with 2+ simultaneous players

## References (load as needed)

| File | When to read |
|---|---|
| `references/game-modes.md` | Choosing genre-specific architecture, lifecycle, actors, tick patterns |
| `references/networking-patterns.md` | Sync strategies, AOI, chunk partitioning, shared simulation, storage |
| `references/security.md` | Anti-cheat, movement validation, rate limiting, input sanitization |

## Related Engine Docs

- `engine-docs/api/network.md` → Network API reference
- `engine-docs/lua-scripting-guide.md` → Networking sections
- `examples/22-third-person-shooter` → Complete multiplayer shooter example
- `CLAUDE.md` → Rule #14 (multiplayer mode detection)
