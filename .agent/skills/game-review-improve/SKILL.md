---
name: game-review-improve
description: >-
  Systematic game quality audit and iterative improvement methodology for UrhoX Lua games.
  Provides structured review scoring across gameplay, visuals, architecture, performance,
  and player experience, then plans and implements highest-impact improvements.
  Use when users need to
  (1) audit and review their game code for quality and completeness,
  (2) get a structured quality score with actionable improvement recommendations,
  (3) systematically improve game feel, polish, and player experience,
  (4) verify architecture patterns like state management, event cleanup, and restart safety,
  (5) check visual polish level and identify missing juice effects,
  (6) validate game flow from start to game-over to restart,
  (7) run a pre-ship quality checklist before publishing,
  (8) iteratively improve a game across multiple sessions with measurable progress,
  or any other game review, audit, or iterative improvement tasks in UrhoX Lua development.
---

# Game Review & Improve — Systematic Quality Audit for UrhoX Lua

## Purpose

Provide a repeatable, scored methodology for auditing and improving UrhoX Lua games.
Each pass identifies the highest-impact improvements, implements them, and measures progress.
Run multiple times — each pass builds on the last.

## When to Use This Skill

| User Says | Action |
|-----------|--------|
| "review my game" / "check my code" | Full audit with scoring |
| "improve my game" / "make it better" | Audit → plan → implement improvements |
| "polish my game" / "add juice" | Focus on visual polish audit |
| "is my game ready to publish?" | Pre-ship validation checklist |
| "what's wrong with my game?" | Diagnostic audit |
| "improve [specific area]" | Focused audit on that area |

## Routing to Other Skills

| Need | Route To |
|------|----------|
| Fix a specific bug or crash | `game-debugging` |
| Optimize frame rate / performance | `game-performance` |
| Design game systems from scratch | `game-architect-v2` |
| Add tween/easing animations | `@soyoyo_tween` |
| Design UI layouts | `game-ui-design` or `@loomy_reactive-ui` |
| Add materials/textures | `materials` |

## Core Workflow

```
Step 1: READ — Read entire game codebase thoroughly
Step 2: AUDIT — Score each quality area (1-5 scale)
Step 3: DIAGNOSE — Identify top improvements by impact
Step 4: PLAN — Present improvement plan, wait for user choice
Step 5: IMPLEMENT — Apply selected improvements
Step 6: VERIFY — Build, test, confirm no regressions
Step 7: REPORT — Show before/after scores and changes
```

**Key rule**: Always present the plan and wait for user confirmation before implementing.

## Step 1: Read the Codebase

Read every file completely — do not skim:

```
scripts/
├── main.lua              — Entry point, Start(), scene setup
├── [game modules]        — Gameplay logic, entities, systems
└── [utility modules]     — Helpers, constants, state management
```

Build a mental model:
- What is the core gameplay loop?
- How is state managed? (global variables? module tables? centralized state?)
- How do systems communicate? (direct calls? events? shared state?)
- What happens on game over? On restart?
- What visual feedback exists for player actions?

## Step 2: Audit and Score

Rate each area on a 1-5 scale. See `references/audit-checklist.md` for detailed criteria.

| Area | Score | What to Check |
|------|-------|---------------|
| **Core Loop** | /5 | Input → action → consequence → feedback → repeat |
| **Game Flow** | /5 | Start → gameplay → game over → restart cycle |
| **Restart Safety** | /5 | Clean state reset, no stale references or listeners |
| **Visual Polish** | /5 | Backgrounds, particles, animations, screen effects |
| **Game Feel / Juice** | /5 | Screen shake, flash, hit stop, squash-stretch |
| **UI Quality** | /5 | Readability, layout, responsiveness, feedback |
| **Audio** | /5 | BGM, SFX coverage, volume balance |
| **Code Architecture** | /5 | Modularity, state management, separation of concerns |
| **Performance** | /5 | Frame rate, object pooling, cleanup, delta time |
| **Player Experience** | /5 | Onboarding, difficulty curve, replayability |

**Overall score: X / 50**

**Mandatory threshold**: Any area scoring below 3 should be flagged for improvement.

## Step 3: Diagnose

From the audit, identify the **top 5-8 improvements** ranked by player impact:

```
For each improvement:
1. Title — short name (e.g., "Add screen shake on hit")
2. Area — which audit category it improves
3. Impact — why this matters to the player
4. Effort — low / medium / high
5. What to do — plain description of the change
```

Put highest-impact, lowest-effort items first.

## Step 4: Plan and Confirm

Present the improvement plan as a numbered list.
**Wait for the user to choose before implementing.**

Options:
- "All" — implement everything
- Specific numbers — implement selected items
- "Top 3" — just the most impactful

## Step 5: Implement

Follow these rules strictly:

1. **Don't break gameplay** — visual/polish changes are additive
2. **Constants over magic numbers** — configurable values in module-level tables
3. **Clean up what you add** — event subscriptions, timers, temporary nodes
4. **Match existing code style** — same patterns and naming as the project
5. **Build after each change** — call MCP build tool to verify

## Step 6: Verify

After all improvements:

```
□ MCP build succeeds with no errors
□ Game starts and core loop works
□ Game over triggers correctly
□ Restart works cleanly (test 3x in a row)
□ No new console warnings
□ Frame rate is acceptable
```

## Step 7: Report

```
Improvement Report
Score: X/50 → Y/50 (+Z points)

Implemented:
1. [Title] — [one-sentence summary]
2. [Title] — [one-sentence summary]

Files modified: [list]
Files created: [list]

How to test: [specific things to verify]

Next: Run this skill again to find the next batch of improvements.
```

## Quick Error Reference (UrhoX-Specific)

| Symptom | Common Cause |
|---------|-------------|
| State persists after restart | Module-level variables not reset |
| Events fire twice | Duplicate SubscribeToEvent calls |
| Nodes not cleaned up | Missing node:Remove() in cleanup |
| Visual effects accumulate | Particles/effects not destroyed after use |
| Input feels unresponsive | Missing delta time multiplication |
| UI overlaps game | Wrong render layer or draw order |

## Focus Area Keywords

When the user specifies a focus:

- **"gameplay"** — core loop, controls, difficulty, variety, risk/reward
- **"visuals"** — backgrounds, palette, animations, particles, transitions
- **"polish"** — screen shake, hit pause, squash-stretch, easing, timing
- **"audio"** — BGM coverage, SFX for actions, volume, mute toggle
- **"architecture"** — modularity, state management, event cleanup, constants
- **"ux"** — onboarding, feedback, difficulty curve, replayability
- **"pre-ship"** — full validation checklist before publishing

## Pre-Ship Validation Checklist

Before publishing, verify ALL items:

```
Core:
□ Player can start, play, and reach game over
□ Score/progress tracks correctly
□ Restart works cleanly 3x in a row
□ No Lua errors in console during full playthrough

Input:
□ Touch input works (if mobile target)
□ Keyboard + mouse works (if PC target)
□ Controls feel responsive (delta-time based movement)

Visual:
□ No visual glitches or Z-fighting
□ UI readable at target resolution
□ Game over screen is polished (not placeholder)

Audio:
□ BGM plays during gameplay
□ Key actions have SFX feedback
□ Audio doesn't stack/overlap uncontrollably

Architecture:
□ No global state leaks between restarts
□ All event subscriptions cleaned up properly
□ No hardcoded magic numbers in game logic
□ Code organized in logical modules
```

## Reference Files

| File | Content |
|------|---------|
| `references/audit-checklist.md` | Detailed scoring criteria for each audit area (1-5 scale) |
| `references/visual-polish-patterns.md` | UrhoX Lua patterns for juice, particles, transitions, effects |
| `references/improvement-workflow.md` | Structured feature addition and iterative improvement workflow |
