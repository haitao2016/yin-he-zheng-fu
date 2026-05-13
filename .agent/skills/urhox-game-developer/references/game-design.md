# Game Design Reference

## Table of Contents
1. [Core Loop Design](#1-core-loop-design)
2. [GDD Template](#2-gdd-template)
3. [Genre Templates](#3-genre-templates)
4. [Player Psychology](#4-player-psychology)
5. [Difficulty Curves](#5-difficulty-curves)
6. [Level Design Principles](#6-level-design-principles)
7. [Monetization Systems](#7-monetization-systems)

---

## 1  Core Loop Design

Every game needs a fun 30-second loop. If it is not fun in 30 seconds, no amount of content fixes it.

```
ACTION → Player does something
FEEDBACK → Game responds immediately (visual + audio)
REWARD → Player feels progress/satisfaction
REPEAT → Loop tightens, stakes increase
```

### Core Loops by Genre

| Genre | Core Loop | Key Feel |
|-------|-----------|----------|
| Platformer | Run → Jump → Land → Collect | Precision |
| Shooter | Aim → Shoot → Hit → Loot | Power |
| Puzzle | Observe → Think → Solve → Advance | Insight |
| RPG | Explore → Fight → Level → Equip | Growth |
| Tower Defense | Build → Defend → Earn → Upgrade | Strategy |
| Idle / Clicker | Click → Earn → Upgrade → Automate | Accumulation |
| Racing | Steer → Boost → Drift → Finish | Speed |

---

## 2  GDD Template

Minimal GDD that fits in a session context:

```markdown
## [Game Title]

**Concept** (1 sentence): [What does the player do and why is it fun?]

**Genre**: [Primary genre] + [Optional modifier]

**Target Platform**: TapTap mobile / PC

**Core Loop** (30 seconds):
1. [Action]
2. [Feedback]
3. [Reward]

**Player Verbs** (what the player can do):
- [Verb 1]
- [Verb 2]

**Win / Lose Condition**:
- Win: [Condition]
- Lose: [Condition]

**Progression**:
- Short term (seconds): [Micro reward]
- Medium term (minutes): [Session goal]
- Long term (hours): [Meta progression]

**Visual Style**: [2-3 adjectives]

**Audio Mood**: [2-3 adjectives]

**Scope (MVP)**:
- [ ] Core mechanic working
- [ ] One level / scene
- [ ] Win/lose state
- [ ] Basic audio
```

---

## 3  Genre Templates

### Platformer Feel Checklist
- **Coyote time**: Allow jump 0.1–0.15s after walking off ledge
- **Jump buffer**: Queue jump input 0.1s before landing
- **Variable jump height**: Short tap = low jump; hold = high jump
- **Fast fall**: Down input doubles gravity
- **Landing squash**: Scale Y 0.7 on land, restore over 0.1s

### Shooter Feel Checklist
- **Hit stop**: Freeze 2–4 frames on strong hit
- **Screen shake**: 0.1–0.3s on explosion/impact
- **Muzzle flash**: 1-frame white overlay on shoot
- **Camera lead**: Camera moves slightly toward aim direction
- **Recoil**: Snap up + recover in 0.15s

### Puzzle Design Rules
1. Introduce mechanic in safe context
2. Combine two known mechanics = new challenge
3. Every puzzle has exactly one "aha" moment
4. Hard puzzle after a hard puzzle = frustration. Alternate pacing.
5. Never require a solution the player could not have discovered

### RPG Progression Formula
```
XP to next level = base * level^1.5
Stat growth per level = flat + random(0, variance)
Enemy HP = player_max_hp * (0.5 + wave * 0.2)
Enemy DMG = player_max_hp * 0.1
```

---

## 4  Player Psychology

### Bartle Player Types
| Type | Motivation | What They Need |
|------|-----------|---------------|
| Achiever | Complete goals, earn rewards | Clear objectives, badges, XP |
| Explorer | Discover secrets, understand systems | Hidden content, lore, depth |
| Socializer | Interact with others | Leaderboards, co-op, chat |
| Killer | Compete and dominate | PvP, rankings, skill expression |

### Flow State (Csikszentmihalyi)
- Flow = challenge slightly above current skill
- Too easy = boredom; too hard = anxiety
- **DDA (Dynamic Difficulty Adjustment)**: Increase enemy speed/HP when win streak ≥ 3; decrease when lose streak ≥ 2

### Engagement Hooks
| Hook | Implementation |
|------|---------------|
| Variable reward | Random rare drops (slot machine psychology) |
| Loss aversion | "You are so close to the next level\!" |
| Completion drive | Progress bar always slightly below 100% |
| Social proof | "1,234 players online now" |
| Streak system | Bonus for consecutive daily play |

---

## 5  Difficulty Curves

### Standard Arc
```
Tutorial → Comfort zone → First challenge spike → Rest beat →
Second challenge → Skill test → Boss / climax → Denouement
```

### Numbers Guide
| Metric | Beginner | Normal | Hard |
|--------|----------|--------|------|
| Enemy HP multiplier | 0.7× | 1.0× | 1.5× |
| Enemy speed multiplier | 0.8× | 1.0× | 1.3× |
| Player respawn count | unlimited | 3 | 1 |
| Time limit multiplier | 1.5× | 1.0× | 0.8× |

### Pacing Rule of Thumb
- 2 minutes of tension → 30 seconds of relief
- Never 3 hard encounters in a row without a safe zone
- Boss should feel like all previous skills combined

---

## 6  Level Design Principles

### The 3 C's
- **Character**: What can they do? Constrain abilities to force creativity.
- **Controls**: Are inputs responsive? Latency > 100ms breaks immersion.
- **Camera**: Does it show the player what they need to see?

### Spatial Grammar
```
Safe zone → Introduce mechanic
Combat zone → Test mechanic
Reward zone → Celebrate mastery
Transition → Lead to next safe zone
```

### Signposting Checklist
- [ ] Player can see the goal from the start position
- [ ] Light / color directs attention to important objects
- [ ] First encounter with every mechanic is in a no-fail context
- [ ] Critical paths are visually distinct from optional paths

---

## 7  Monetization Systems

### TapTap-Compatible Models

| Model | When to Use | UrhoX Implementation |
|-------|------------|---------------------|
| Free + Ads | Casual, broad audience | `get_ad_config` MCP tool |
| Premium (paid) | Strong IP, low sessions | Standard TapTap publish |
| In-app purchase | Mid-core, long sessions | Cloud score + custom shop UI |
| Season pass | Regular content updates | Cloud variables for unlock flags |

### Ad Integration Checklist
1. Call `get_ad_config` MCP tool to sync ad config
2. Check `status == 1` before showing ads
3. Rewarded ad: player chooses to watch → reward immediately after
4. Interstitial: only between natural breaks (level end, respawn)
5. Never block core gameplay loop with mandatory ads

### Balance Formula
```
Session value = avg_session_minutes * ad_rpm / 60
Target: session_value > $0.01 to be sustainable on free model
Rewarded ads typically 3–5× RPM of banner ads
```
