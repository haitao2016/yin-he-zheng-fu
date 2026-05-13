# Game Quality Audit Checklist — Scoring Criteria

Detailed criteria for each audit area. Score 1-5 for each.

---

## 1. Core Loop (Input → Action → Consequence → Feedback)

| Score | Criteria |
|-------|----------|
| 1 | No functional gameplay loop; game doesn't respond to input |
| 2 | Basic input works but missing consequence or feedback |
| 3 | Complete loop: input → action → consequence, but feedback is minimal |
| 4 | Good loop with clear feedback; actions feel meaningful |
| 5 | Tight loop with satisfying feedback on every action; risk/reward balance |

**What to check**:
```lua
-- Does input produce immediate visible response?
-- Does each action have a consequence (scoring, damage, progression)?
-- Is there visual+audio feedback for every player action?
-- Is there a fail state that creates tension?
```

**Common UrhoX issues**:
- Movement without delta time (frame-rate dependent speed)
- Input checked in wrong event (Update vs FixedUpdate for physics)
- Missing feedback: score changes silently, hits have no visual effect

---

## 2. Game Flow (Start → Gameplay → Game Over → Restart)

| Score | Criteria |
|-------|----------|
| 1 | Game starts but no game over or restart mechanism |
| 2 | Game over exists but restart is broken or missing |
| 3 | Full flow works but transitions are abrupt (hard cuts) |
| 4 | Smooth transitions, clear game over screen with score display |
| 5 | Polished flow with animations, score summary, best score tracking |

**What to check**:
```lua
-- Does the game have a clear start state?
-- Is there a win/lose condition?
-- Does game over show the player's result?
-- Can the player restart without reloading?
-- Are transitions smooth (fade, slide) or hard cuts?
```

**UrhoX-specific checks**:
- Scene recreation vs state reset approach
- Event resubscription after restart
- Camera reset to correct position

---

## 3. Restart Safety (Clean Reset)

| Score | Criteria |
|-------|----------|
| 1 | Restart crashes or produces errors |
| 2 | Restart works but state leaks (scores carry over, entities duplicate) |
| 3 | State resets correctly but minor issues (audio continues, effects linger) |
| 4 | Clean restart; 2nd run identical to 1st |
| 5 | 3+ consecutive restarts are perfectly identical; all resources cleaned up |

**What to check**:
```lua
-- Are ALL module-level variables reset?
-- Are event subscriptions cleaned up and resubscribed?
-- Are all child nodes removed before recreating?
-- Do timers/scheduled callbacks get cancelled?
-- Test: restart 3 times rapidly — 3rd run identical to 1st?

-- Common pattern for clean restart:
function RestartGame()
    -- Reset all state
    score = 0
    gameOver = false
    enemies = {}

    -- Clean up scene
    scene_:GetChild("GameContent"):Remove()

    -- Recreate
    CreateGameContent()
end
```

**UrhoX-specific pitfalls**:
- `SubscribeToEvent` called again without unsubscribing → double-firing
- Module-level tables (enemies, bullets) not cleared
- NanoVG font created again → memory leak (use cached handle)

---

## 4. Visual Polish (Backgrounds, Colors, Animations)

| Score | Criteria |
|-------|----------|
| 1 | No visual styling; default/placeholder graphics |
| 2 | Basic colors applied but flat; no depth or atmosphere |
| 3 | Cohesive color palette; some visual variety |
| 4 | Atmospheric backgrounds, smooth animations, visual hierarchy |
| 5 | Rich visuals: parallax, dynamic lighting, polished transitions |

**What to check**:
- Background: flat color vs gradient vs layered/parallax?
- Color palette: random colors or cohesive theme?
- Animations: things pop in/out or smooth tween?
- Idle animations: do entities have life when not interacted with?
- Visual hierarchy: is the player character clearly the focus?

**UrhoX-specific patterns (see `visual-polish-patterns.md`)**:
- NanoVG gradients for 2D backgrounds
- Material color variations for 3D scene atmosphere
- Node scale animation for entity entrance/exit
- Camera techniques for visual impact

---

## 5. Game Feel / Juice

| Score | Criteria |
|-------|----------|
| 1 | No juice effects at all; game feels flat |
| 2 | One or two effects exist but inconsistently applied |
| 3 | Key moments have feedback (hit, score, death) |
| 4 | Consistent juice: shake, flash, particles on important events |
| 5 | Every interaction feels satisfying; layered effects (visual+audio+camera) |

**Juice elements to check**:
```
□ Screen shake on impact/explosion
□ Flash effect on damage
□ Particle burst on destruction
□ Scale pop on collection/scoring
□ Camera zoom on key moments
□ Hit stop/freeze frame on big hits
□ Squash and stretch on landing/bouncing
□ Floating score text near action
□ Trail effects on fast-moving objects
```

**UrhoX implementation**:
```lua
-- Screen shake via camera
cameraNode.position = cameraNode.position +
    Vector3(math.random() - 0.5, math.random() - 0.5, 0) * shakeIntensity

-- Scale pop
node.scale = Vector3(1.3, 1.3, 1.3)  -- pop up
-- then tween back to 1.0 over 0.2 seconds

-- Flash: temporarily swap material to white emissive
```

---

## 6. UI Quality

| Score | Criteria |
|-------|----------|
| 1 | No UI or completely broken UI |
| 2 | Basic text display but poor readability or layout |
| 3 | Functional UI: score, game over text, restart button |
| 4 | Well-designed UI with consistent style and good readability |
| 5 | Polished UI with animations, proper layout, responsive to screen size |

**What to check**:
- Is score/status clearly visible during gameplay?
- Is game over screen informative (show score, best score)?
- Are interactive elements clearly tappable/clickable?
- Does UI adapt to different screen sizes?
- Is font consistent throughout?
- Does UI use the recommended `urhox-libs/UI` system (not raw NanoVG)?

---

## 7. Audio

| Score | Criteria |
|-------|----------|
| 1 | No audio at all |
| 2 | Either BGM or SFX, but not both |
| 3 | BGM + SFX exist but coverage is incomplete |
| 4 | Full coverage: BGM for each state, SFX for each action |
| 5 | Adaptive audio: volume variations, spatial sound, smooth transitions |

**Coverage checklist**:
```
BGM:
□ Main gameplay has background music
□ Game over/menu has different music or silence
□ Music loops seamlessly

SFX:
□ Player action (jump, shoot, attack)
□ Score/collect
□ Damage/hit
□ Game over
□ UI click/select
□ Enemy/obstacle interaction
```

---

## 8. Code Architecture

| Score | Criteria |
|-------|----------|
| 1 | Single massive file with no organization |
| 2 | Some structure but tightly coupled; globals everywhere |
| 3 | Logical separation into modules; some state management |
| 4 | Clean architecture: modules, centralized state, event-based communication |
| 5 | Exemplary: fully modular, configurable constants, clean lifecycle management |

**Architecture checks**:
```
□ Code split into logical modules (not everything in main.lua)
□ State centralized (not scattered across globals)
□ Constants configurable (not hardcoded magic numbers)
□ Systems communicate via events or clear interfaces
□ No circular dependencies between modules
□ Clean lifecycle: setup → update → cleanup
□ Files under 1500 lines (split if larger)
```

---

## 9. Performance

| Score | Criteria |
|-------|----------|
| 1 | Visible lag or frame drops during normal gameplay |
| 2 | Acceptable frame rate but obvious inefficiencies |
| 3 | Smooth gameplay; basic optimization applied |
| 4 | Well-optimized: pooling, efficient updates, proper cleanup |
| 5 | Highly optimized: batching, LOD, profiled and tuned |

**What to check**:
```lua
-- Delta time used for all movement?
local dt = eventData["TimeStep"]:GetFloat()
node.position = node.position + velocity * dt  -- ✅
node.position = node.position + velocity        -- ❌

-- Object pooling for frequently created/destroyed objects?
-- Are removed nodes actually cleaned up (node:Remove())?
-- Are tables cleared when objects are removed?
-- Heavy computation cached rather than recalculated per frame?
```

---

## 10. Player Experience

| Score | Criteria |
|-------|----------|
| 1 | Player doesn't understand what to do |
| 2 | Gameplay is clear but no progression or variety |
| 3 | Basic progression; some difficulty ramping |
| 4 | Good pacing with difficulty curve; some replayability |
| 5 | Compelling loop: clear goals, varied challenges, reason to replay |

**What to check**:
- Can a new player understand the controls without instructions?
- Does difficulty increase over time?
- Is there variety (different enemies, obstacles, patterns)?
- Is there a reason to play again (high score, unlockables, randomness)?
- Does the player feel like they're improving?

---

## Scoring Summary Template

```
Game Quality Audit: [Game Name]
Date: [Date]

| # | Area               | Score | Notes |
|---|-------------------|-------|-------|
| 1 | Core Loop          | /5   |       |
| 2 | Game Flow          | /5   |       |
| 3 | Restart Safety     | /5   |       |
| 4 | Visual Polish      | /5   |       |
| 5 | Game Feel / Juice  | /5   |       |
| 6 | UI Quality         | /5   |       |
| 7 | Audio              | /5   |       |
| 8 | Code Architecture  | /5   |       |
| 9 | Performance        | /5   |       |
| 10| Player Experience  | /5   |       |
|   | **TOTAL**          | **/50** |    |

Areas below 3 (mandatory improvement):
- [list]

Top improvements by impact:
1. [item]
2. [item]
3. [item]
```
