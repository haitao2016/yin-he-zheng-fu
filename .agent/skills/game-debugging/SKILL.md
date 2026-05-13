---
name: game-debugging
description: >-
  Systematic debugging methodology and game testing patterns for UrhoX Lua games,
  covering root cause analysis, bug pattern recognition, hypothesis-driven debugging,
  and game-specific QA methodology. Use when users need to
  (1) debug crashes, nil errors, or unexpected behavior in Lua game code,
  (2) systematically isolate and fix hard-to-reproduce bugs,
  (3) identify common Lua/UrhoX bug patterns like 1-based indexing errors or event lifecycle issues,
  (4) set up testing strategies for gameplay mechanics,
  (5) diagnose rendering, physics, or input handling problems,
  (6) fix performance regressions or memory-related issues,
  (7) trace data flow through event systems and node hierarchies,
  (8) validate game behavior across different screen sizes and input methods,
  or any other debugging and testing tasks in UrhoX Lua game development.
---

# Game Debugging — Systematic Debugging & Testing for UrhoX Lua

## Purpose

Provide a structured, repeatable debugging methodology for UrhoX Lua games.
Instead of random code changes, follow a systematic process:
**Reproduce → Isolate → Hypothesize → Fix → Verify**.

## When to Use This Skill

| Trigger | Action |
|---------|--------|
| User reports a bug, crash, or unexpected behavior | Apply full debugging workflow |
| `attempt to index a nil value` or similar Lua error | Check `references/lua-bug-patterns.md` first |
| "It worked before but now it doesn't" | Use delta debugging / recent changes analysis |
| Game behaves differently on different devices | Screen/input compatibility check |
| User wants to test their game systematically | Apply `references/game-testing.md` |
| Performance regression | Route to `game-performance` skill for profiling |

## Routing to Other Skills

| Need | Skill |
|------|-------|
| Runtime debug UI (log viewer, scene inspector) | `调试助手` |
| Performance profiling and optimization | `game-performance` |
| Architecture/design issues causing bugs | `game-architect-v2` |

## Core Debugging Workflow

### Phase 1: Reproduce

Before any fix attempt, establish reliable reproduction:

```
1. Get exact error message (full stack trace if available)
2. Identify reproduction steps (what triggers the bug?)
3. Determine frequency (always? sometimes? only on first run?)
4. Note environment (screen size, input method, multiplayer?)
```

**UrhoX-specific reproduction tools:**

```lua
-- Add temporary logging at suspected locations
log:Write(LOG_DEBUG, "DEBUG: variable = " .. tostring(variable))
log:Write(LOG_DEBUG, "DEBUG: node exists = " .. tostring(node ~= nil))
log:Write(LOG_DEBUG, "DEBUG: position = " .. node.position:ToString())
```

### Phase 2: Isolate

Narrow down the problem area:

```
1. Binary search: Comment out half the code, does bug persist?
2. Minimal reproduction: Strip to minimum code that triggers bug
3. Recent changes: What changed since it last worked?
4. Data flow trace: Follow the value from source to crash point
```

### Phase 3: Hypothesize & Test

Form specific, testable hypotheses:

```
❌ Bad: "Something is wrong with physics"
✅ Good: "The collision callback fires before the node is fully initialized"

Test ONE hypothesis at a time:
1. State your hypothesis clearly
2. Predict what you expect to see
3. Add targeted logging/checks
4. Run and compare prediction vs reality
5. If wrong, move to next hypothesis
```

### Phase 4: Fix & Verify

```
1. Fix the root cause (not symptoms)
2. Verify the fix resolves the original bug
3. Check for regressions (did the fix break anything else?)
4. Remove all debug logging
5. Document if the bug pattern is common
```

## UrhoX Lua Quick Error Reference

| Error Message | Likely Cause | Fix |
|---------------|-------------|-----|
| `attempt to index a nil value` | Variable not initialized or wrong scope | Check variable assignment, verify node/component exists |
| `attempt to call a nil value` | Function name typo or wrong API | Check spelling, verify API in `.emmylua/` |
| `Stack index X out of range` | Wrong number of arguments to C++ bound function | Check function signature in docs |
| `Null pointer access` | Using destroyed node/component | Check node lifecycle, verify not deleted |
| `Resource not found` | Wrong resource path | Remove `assets/` prefix, check file exists |
| `Physics body not responding` | Missing RigidBody or wrong body type | Verify RigidBody2D/3D exists, check BT_DYNAMIC |
| `Event not firing` | Wrong event name or subscription timing | Verify event name string, subscribe in Start() |
| `NanoVG draws nothing` | Not using NanoVGRender event | Use `SubscribeToEvent("NanoVGRender", ...)` |
| `NanoVG text invisible` | Font not created | Call `nvgCreateFont()` once in Start() |
| `UI not responding to input` | Element not focusable or wrong layer | Check element properties, verify UI hierarchy |

## UrhoX-Specific Debugging Constraints

1. **No interactive debugger** — Use `log:Write()` for all inspection
2. **Lua 1-based arrays** — Off-by-one bugs are the #1 source of nil errors
3. **Event lifecycle** — Components may not exist when events fire during cleanup
4. **Node ownership** — Removing a parent removes all children; dangling references crash
5. **Resource paths** — No `assets/` or `scripts/` prefix; files are in resource search paths
6. **Sandboxed I/O** — No `io` library; use `File` API with relative paths
7. **Single-threaded** — No race conditions, but event ordering matters
8. **Hot reload limitations** — Some state persists across reloads; restart if in doubt

## Reference Files

| File | Content |
|------|---------|
| `references/systematic-debugging.md` | Complete 4-phase debugging methodology with UrhoX examples |
| `references/lua-bug-patterns.md` | Common Lua/UrhoX bug patterns with code examples |
| `references/game-testing.md` | Game QA methodology adapted for UrhoX development |
