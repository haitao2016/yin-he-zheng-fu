# Validations — Quality Checklist for UrhoX Prompt-to-Game

Run this checklist before delivering any game code to the user.

## V1: Build Verification (Blocking)

```
[ ] MCP build tool was called after the latest code change
[ ] Build completed without errors
[ ] No unresolved LSP diagnostics at error level
```

**If any V1 check fails: DO NOT deliver. Fix first.**

---

## V2: Scaffold Compliance (Blocking)

```
[ ] Code is based on an official scaffold template
[ ] Start() function exists and initializes scene, camera, viewport
[ ] Code is located in scripts/ directory
[ ] No code written to dist/ or other forbidden directories
```

---

## V3: UrhoX API Correctness (Blocking)

```
[ ] No magic numbers for input (uses KEY_*, MOUSEB_* enums)
[ ] No native UI usage (no Text:new(), Button:new(), UIElement)
[ ] UI uses urhox-libs/UI library
[ ] eventData accessed via eventData["Key"]:GetType() pattern
[ ] Lua arrays indexed from 1 (not 0)
[ ] No io library calls (io.open, io.read, io.write)
[ ] Material techniques use PBRNoTexture.xml family (not guessed paths)
[ ] NanoVG rendering inside NanoVGRender event (not Update)
[ ] NanoVG fonts created once in Start() (not every frame)
[ ] Units are meters (gravity ≈ -9.81, character height ≈ 1.5-2.0)
```

---

## V4: Code Quality (Warning)

```
[ ] Single file does not exceed 1000 lines
      (800+ → suggest splitting; 1500+ → must split)
[ ] No deeply nested conditionals (> 3 levels)
[ ] No duplicate code blocks (> 2 identical blocks)
[ ] Functions have clear single responsibility
[ ] Game state management is explicit (menu / playing / gameover)
```

---

## V5: Game Completeness (Warning)

```
[ ] Core mechanic works (player can DO the main thing)
[ ] Win/lose condition is implemented (or explicitly omitted for sandbox games)
[ ] Game can be restarted after game over
[ ] Score or progress is displayed (if applicable)
[ ] Basic input feedback exists (visual or audio response to player actions)
```

---

## V6: Logging & Debug (First Delivery Only)

```
[ ] Key game events have log output (score change, state transition, collision)
[ ] Log statements use log:Write(LOG_DEBUG, ...) format
[ ] Debug logs are marked for removal after user confirms game works
```

---

## V7: Security (Blocking)

```
[ ] No eval() or loadstring() with user input
[ ] No hardcoded API keys or secrets
[ ] No file operations outside sandbox (only relative paths like "save.json")
[ ] No code written to /workspace/dist/
```

---

## V8: Iteration Readiness

```
[ ] Code is structured for easy extension (clear separation of concerns)
[ ] Key game parameters are defined as config variables at top of file
      (speeds, sizes, spawn rates, colors)
[ ] User can tweak gameplay by changing config values without understanding internals
```

---

## Severity Levels

| Level | Meaning |
|-------|---------|
| **Blocking** | Must fix before delivering code |
| **Warning** | Flag to user, suggest improvement |
| **Info** | Note for future iteration |

## Quick Self-Check (Before Every Delivery)

Ask yourself these 5 questions:

1. Did I BUILD after the last change?
2. Did I start from a scaffold?
3. Are all arrays 1-indexed?
4. Am I using urhox-libs/UI (not native UI)?
5. Am I using enum constants (not magic numbers)?

If any answer is "no" → fix before delivering.
