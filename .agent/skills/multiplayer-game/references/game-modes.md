# Game Modes — Architecture Reference

Detailed architecture, lifecycle, actor topology, and tick patterns for each multiplayer game classification. Read the section matching your game genre.

## Table of Contents

1. [Battle Royale](#1-battle-royale)
2. [Arena](#2-arena)
3. [IO Style](#3-io-style)
4. [Open World](#4-open-world)
5. [Party](#5-party)
6. [Ranked](#6-ranked)
7. [Turn-Based](#7-turn-based)
8. [Idle](#8-idle)
9. [Casual PvP](#9-casual-pvp)
10. [Co-op PvE](#10-co-op-pve)

---

## 1. Battle Royale

**Examples**: Fortnite, Apex Legends, PUBG, Warzone

| Topic | Detail |
|---|---|
| Tick Rate | 10 Hz (100ms) |
| Netcode | Hybrid — client owns movement/camera/prediction; server owns zone, projectiles, hits, eliminations, loot, placement |
| Matchmaking | Route to fullest non-started lobby (oldest tie-break); start when capacity reached |

**Architecture**:

```
Server (10 Hz fixed loop):
├── Zone progression (shrinking circle)
├── Player state management
├── Hit detection & damage (authoritative)
├── Loot spawning & pickup validation
├── Elimination tracking & placement
└── Broadcast snapshots + events

Client:
├── Input → local movement prediction
├── Interpolate remote players
├── Zone visualization
├── Loot/inventory UI
└── Receive & reconcile server state
```

**Lifecycle**:

```
Client → Matchmaker: findMatch()
  if no open lobby → Matchmaker creates Match
Matchmaker → Client: {matchId, playerId}
Client → Match: connect(playerId)
Match → Matchmaker: playerConnected
  [lobby countdown → live phase]
Match → Client: snapshots + events
  [last player standing → game over]
Match → Matchmaker: closeMatch
```

**Key Sync Priorities**:

| Data | Priority | Frequency | Reliable |
|---|---|---|---|
| Player position | High | Every tick | No |
| Shoot/hit events | Highest | On event | Yes |
| Health changes | High | On event | Yes |
| Loot pickup | Medium | On event | Yes |
| Zone state | Low | 1 Hz | Yes |

---

## 2. Arena

**Examples**: CS2, Halo TDM/FFA, Overwatch Quick Play, Rocket League

| Topic | Detail |
|---|---|
| Tick Rate | 20 Hz (50ms) |
| Netcode | Hybrid — client movement + prediction; server owns team assignment, projectiles, hits, scoring, phase transitions |
| Matchmaking | Mode-based queues (duo, squad, FFA); build only full matches; pre-assign teams |

**Architecture**:

```
Server (20 Hz fixed loop):
├── Team/FFA assignment
├── Spawn management
├── Combat resolution (authoritative)
├── Score tracking & win conditions
├── Round/phase transitions
└── Tighter snapshot cadence (50ms)

Client:
├── Input + movement prediction + smoothing
├── Shoot effects (visual only)
├── Scoreboard UI
└── Phase transition handling
```

**Lifecycle**:

```
Client → Matchmaker: queueForMatch(mode)
  [enqueue; fill when capacity reached]
Matchmaker → Match: create(matchId, team assignments)
Matchmaker → Client: assignmentReady
Client → Match: connect(playerId)
  [waiting → live when all connected]
  [rounds/phases play out]
Match → Matchmaker: matchCompleted
```

---

## 3. IO Style

**Examples**: Agar.io, Slither.io, surviv.io

| Topic | Detail |
|---|---|
| Tick Rate | 10 Hz (100ms) |
| Netcode | Server-authoritative + interpolation — client sends input intents; server simulates and publishes snapshots |
| Matchmaking | Open-lobby routing to fullest room below capacity; auto-create new lobbies |

**Architecture**:

```
Server (10 Hz fixed loop):
├── Input processing (move direction, actions)
├── Kinematic movement simulation
├── Collision & growth/split logic
├── Lightweight periodic snapshots
└── Player join/leave management

Client:
├── Send input intents (direction, split, boost)
├── Interpolate between server snapshots
├── Render all visible entities
└── Leaderboard UI
```

**Key**: No client prediction needed — server is sole authority. Client interpolates between received snapshots for smooth rendering.

---

## 4. Open World

**Examples**: Minecraft survival servers, Rust, MMO zone worlds

| Topic | Detail |
|---|---|
| Tick Rate | 10 Hz per chunk |
| Netcode | Hybrid (sandbox: client movement + server validation) or Server-auth (MMO-like) |
| Matchmaking | Client-driven chunk routing from world coordinates |

**Architecture**:

```
Chunk-based sharding:
├── Each chunk = independent simulation scope
├── Client subscribes to nearby chunks (e.g., 3x3 window)
├── Chunk owns: local players, blocks/terrain, local physics
├── Cross-chunk: handoff when player crosses boundary
└── Persistence: chunk state saved to storage

Client:
├── Resolve chunk keys from world position
├── Connect to visible chunks
├── Stream chunk data on enter
├── Unsubscribe on leave
└── Local building preview + server confirmation
```

**When to use chunks**: Only when world is large and state-heavy (sandbox builders, MMOs). Small-map games (<20 players) don't need partitioning.

**Block Change Example (UrhoX)**:

```lua
local CHUNK_SIZE = 16

function HandleBlockChange(conn, x, y, z, blockType)
    if not CanModify(conn, x, y, z) then return end
    SetBlock(x, y, z, blockType)
    local chunkX = math.floor(x / CHUNK_SIZE)
    local chunkZ = math.floor(z / CHUNK_SIZE)
    local nearby = GetPlayersInChunk(chunkX, chunkZ)
    for _, player in ipairs(nearby) do
        SendBlockUpdate(player.connection, x, y, z, blockType)
    end
end
```

---

## 5. Party

**Examples**: Fall Guys private lobbies, custom game rooms, social party sessions

| Topic | Detail |
|---|---|
| Tick Rate | Event-driven (no continuous tick) |
| Netcode | Server-auth (basic logic) — server owns membership, host permissions, phase transitions |
| Matchmaking | Host-created private party flow using party codes |

**Lifecycle**:

```
Host → Matchmaker: createParty()
Matchmaker → Host: {matchId, partyCode, playerId}
Host → Match: connect(playerId)

Joiner → Matchmaker: joinParty(partyCode)
Matchmaker → Joiner: {matchId, playerId}
Joiner → Match: connect(playerId)

Host → Match: startGame()
  [party game plays out]
Host → Match: finishGame()
Match → Matchmaker: closeParty
```

**Key**: No physics loop needed for lobby. Add realtime tick only if party includes mini-games.

---

## 6. Ranked

**Examples**: Chess ladders, competitive card games, duel arena ranked queues

| Topic | Detail |
|---|---|
| Tick Rate | 20 Hz (50ms) for realtime; event-driven for turn-based ranked |
| Netcode | Hybrid — client movement + prediction; server owns hits, match results, rating updates |
| Matchmaking | ELO/MMR-based queue pairing with widening search window as wait time increases |

**Architecture**:

```
Matchmaker:
├── Rating-based queueing
├── Pairing with rating window (widens over time)
├── Assignment persistence
└── Result fanout (update ratings)

Match:
├── Ranked phase management
├── Score & winner reporting
└── Anti-cheat validation (stricter than casual)

Player (persistent):
├── Canonical MMR / ELO rating
├── Win/loss record
└── Match history

Leaderboard:
├── Global ordered rankings
└── Top-N queries
```

**Lifecycle**:

```
Client → Matchmaker: queueForMatch(username)
Matchmaker → Player: getRating()
  [store queue row; retry pairing with widening window]
  [pair found]
Matchmaker → Match: create(matchId, assigned players)
Matchmaker → Client: assignmentReady
Client → Match: connect(username)
  [match plays out]
Match → Matchmaker: matchCompleted(results)
Matchmaker → Player: applyMatchResult(win/loss, ratingDelta)
Matchmaker → Leaderboard: updatePlayer(score)
```

---

## 7. Turn-Based

**Examples**: Chess, Words With Friends, async board games

| Topic | Detail |
|---|---|
| Tick Rate | Event-driven (no continuous tick) |
| Netcode | Server-auth (basic) — server owns turn ownership, committed moves, turn order, completion |
| Matchmaking | Private invite (codes) and public queue pairing |

**Architecture**:

```
Server (event-driven):
├── Game state machine (WAITING → PLAYING → GAME_OVER)
├── Turn ownership enforcement
├── Move validation against game rules
├── Random number generation (server-authoritative seed)
├── Win/draw condition checking
└── Move history for replay

Client:
├── Board/hand rendering
├── Draft moves locally before submit
├── Animate confirmed moves
└── History/replay viewer
```

**State Machine Example (UrhoX)**:

```lua
local GameState = {
    WAITING = "waiting",
    PLAYING = "playing",
    TURN_ACTION = "turn_action",
    GAME_OVER = "game_over",
}

function HandlePlayerAction(conn, action)
    if conn ~= currentTurnPlayer then return end
    if not ValidateAction(action) then
        SendError(conn, "Invalid action")
        return
    end
    local result = ExecuteAction(action)
    BroadcastAction(action, result)
    if CheckGameOver() then
        TransitionTo(GameState.GAME_OVER)
    else
        NextTurn()
    end
end
```

**Dual Matchmaking Lifecycle**:

```
-- Public queue:
A → Matchmaker: queueForMatch()
B → Matchmaker: queueForMatch()
  [pair first two queued]
Matchmaker → Match: create + seed players

-- Private invite:
A → Matchmaker: createGame()
Matchmaker → A: {matchId, inviteCode}
B → Matchmaker: joinByCode(inviteCode)
Matchmaker → Match: create + seed players
```

---

## 8. Idle

**Examples**: Cookie Clicker, Idle Miner Tycoon, Adventure Capitalist

| Topic | Detail |
|---|---|
| Tick Rate | No continuous tick; use scheduled intervals (5-15 min) + offline catch-up |
| Netcode | Server-auth (basic) — server owns resources, production rates, building validation |
| Matchmaking | No matchmaker; direct per-player world + shared leaderboard |

**Architecture**:

```
Per-player world:
├── Building/upgrade validation
├── Resource production scheduling
├── Offline catch-up (elapsed wall time)
└── State persistence

Leaderboard (shared):
├── Global score tracking
└── Periodic update from worlds
```

**Lifecycle**:

```
Client → World: getOrCreate(playerId) + initialize()
  [seed state; schedule first production collection]
World → Client: stateUpdate

loop:
  Client → World: build() / collectProduction()
  World → Leaderboard: updateScore()
  World → Client: stateUpdate
```

**Offline Catch-Up Pattern**:

```lua
function CalculateOfflineProgress(lastTime, nowTime, productionRate)
    local elapsed = nowTime - lastTime
    local resources = math.floor(elapsed * productionRate)
    return resources
end
```

---

## 9. Casual PvP

**Examples**: Party quiz, simple sports, Fall Guys-style minigames

| Topic | Detail |
|---|---|
| Tick Rate | 20-30 Hz |
| Netcode | Server-auth — simple state sync |
| Matchmaking | Simple lobby fill or party-code based |

**Architecture**:

```
Server (20-30 Hz):
├── Game rule management
├── Round/phase control
├── Score calculation
├── State broadcast
└── Simple matchmaking

Client:
├── Input → server
├── Receive state → render
├── UI interaction
└── Optional simple prediction
```

**Round-End Sync Example (UrhoX)**:

```lua
-- Server
function HandleRoundEnd()
    local results = CalculateResults()
    local msg = VectorBuffer()
    msg:WriteInt(#results)
    for _, r in ipairs(results) do
        msg:WriteInt(r.playerId)
        msg:WriteInt(r.score)
        msg:WriteInt(r.rank)
    end
    BroadcastMessage(MSG_ROUND_RESULT, msg)
end

-- Client
function HandleRoundResult(data)
    local count = data:ReadInt()
    for i = 1, count do
        local pid = data:ReadInt()
        local score = data:ReadInt()
        local rank = data:ReadInt()
        UpdateScoreboard(pid, score, rank)
    end
end
```

---

## 10. Co-op PvE

**Examples**: Survival games, dungeon crawlers, wave defense

| Topic | Detail |
|---|---|
| Tick Rate | 30 Hz |
| Netcode | Server-auth — state sync with AI synchronization |
| Matchmaking | Party or lobby fill |

**Architecture**:

```
Server (30 Hz):
├── AI/NPC behavior (server-authoritative)
├── Wave/spawn management
├── Damage calculation (PvE)
├── Loot distribution
├── Event triggers (boss phases, traps)
└── Player state sync

Client:
├── Input + movement
├── AI entity interpolation
├── VFX / animation playback
└── Co-op UI (shared objectives, loot rolls)
```

**Key Challenge**: All AI must run on server. Client only interpolates AI positions and plays animations based on server-sent state changes. Never run AI logic on client.

---

## Decision Tree

```
Does the game need realtime control?
├── No (turn-based)
│   └── Event-driven architecture
│       → Turn-Based, Card games
│
├── Yes, but no precise hit detection
│   └── Simple state sync (20-30 Hz)
│       → Casual PvP, Party, Co-op PvE
│
└── Yes, with precise hit/collision detection
    ├── Players < 20
    │   └── State sync + client prediction + lag compensation
    │       → FPS/TPS (Arena), Racing, Ranked
    │
    └── Players > 20
        └── State sync + AOI / chunk partitioning
            → MMO, Open World, Battle Royale (large lobby)
```

## Complexity Comparison

| Architecture | Complexity | Best For |
|---|---|---|
| Event-driven | ★ | Turn-based, card games |
| Simple state sync | ★★ | Casual PvP, party |
| State sync + prediction | ★★★★ | Competitive shooters, racing |
| State sync + AOI | ★★★★★ | MMO, large worlds |
| Chunk-based sharding | ★★★★★ | Sandbox, persistent worlds |
