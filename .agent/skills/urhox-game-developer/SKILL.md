---
name: urhox-game-developer
description: "Full-stack UrhoX Lua game development assistant covering 7 specialist domains: (1) Game Design — core loop, GDD, genre templates, player psychology, difficulty curves; (2) Lua Programming — UrhoX API patterns, event system, scene graph, physics, input; (3) Graphics & Rendering — NanoVG, PBR materials, camera systems, particle effects; (4) Audio — BGM crossfade, SFX one-shot, spatial 3D audio, AudioManager; (5) Multiplayer — server-authoritative sync, client prediction, cloud scores/leaderboard; (6) Tools & Pipeline — asset optimization, build refs, DWP, i18n, modular architecture; (7) Publishing — TapTap platform, game materials, QR test, GameJam. Use when users ask about any aspect of UrhoX game development: 'make a game', 'add feature', 'fix bug', 'optimize', 'publish', 'game design', 'audio', 'UI', 'physics', 'camera', 'multiplayer', '做游戏', '添加功能', '发布游戏', '游戏开发'."
license: MIT
metadata:
  version: "1.0.0"
  author: "UrhoX Dev Team"
  tags: ["urhox", "lua", "game-dev", "design", "programming", "audio", "publishing", "taptap"]
---

# UrhoX Game Developer

7 specialist domains covering the full game development lifecycle.

## Domain Routing

Read the matching reference file before answering:

| User Intent | Domain | Reference |
|-------------|--------|-----------|
| Game idea, core loop, level design, GDD, player psychology | Game Design | `references/game-design.md` |
| Lua code, API usage, architecture, bug fixes | Programming | `references/programming.md` |
| NanoVG graphics, PBR materials, shaders, camera | Graphics | `references/programming.md` section Graphics |
| BGM, SFX, AudioManager, 3D spatial audio | Audio | `references/audio-publishing.md` section Audio |
| Multiplayer, server sync, cloud scores | Networking | `references/programming.md` section Multiplayer |
| Asset pipeline, build config, i18n, modular splits | Pipeline | `references/audio-publishing.md` section Pipeline |
| TapTap publish, game materials, GameJam | Publishing | `references/audio-publishing.md` section Publishing |

For cross-domain requests, read all relevant reference files.

---

## Universal Workflow

### New game from scratch
1. Read `engine-docs/principles.md` + `lua-scripting-guide.md` (mandatory)
2. Pick scaffold by game type (see table below)
3. Find closest example via `examples/api-index.md`
4. Copy scaffold, fill in game logic, run build tool

**Scaffold quick-pick:**

| Game Type | Scaffold |
|-----------|----------|
| 2D casual (Flappy Bird, Snake) | `templates/scaffold-2d.lua` |
| 2D platformer (Mario style) | `templates/scaffold-2d-physics.lua` |
| 3D scene / visualization | `templates/scaffold-3d-scene.lua` |
| 3D character game (Roblox style) | `templates/scaffold-3d-character.lua` |

### Add feature to existing game
1. Read relevant API doc (`engine-docs/api/`)
2. Find example in `examples/api-index.md`
3. Minimal change principle — only touch what is needed
4. Run build tool

### Bug fix flow
1. Check `lua-scripting-guide.md` → "Key Notes" first
2. Verify against common pitfalls table below
3. Add logs to isolate → fix → remove debug logs
4. Run build tool

---

## Absolute Rules (Breaking These Breaks the Game)

| Rule | Correct Approach |
|------|-----------------|
| Length unit | Meters only. Character height 1.8m, jump speed 7m/s |
| Coordinate system | Y-up left-hand (same as Unity): Y=up, Z=forward, X=right |
| UI system | Must use `urhox-libs/UI`. Native UIElement is deprecated |
| NanoVG rendering | Only inside `NanoVGRender` event handler, never in Update |
| NanoVG font | Call `nvgCreateFont` once in `Start()`, reuse the handle |
| Array index | Lua arrays start at **1**, not 0 |
| Mouse button | Use `MOUSEB_LEFT`, never numeric `0` |
| Material technique | Use `PBRNoTexture.xml` for procedural — do not guess paths |
| Resolution | `SetMode()` is disabled. Use `GetWidth()/GetHeight()/GetDPR()` |
| Code location | Write only to `scripts/`. Never write to `dist/` |
| Build | **Call the build tool after every code change** |

---

## Common Error Quick-Reference

| Symptom | Cause and Fix |
|---------|--------------|
| NanoVG shows nothing | Missing `NanoVGRender` event subscription |
| Text does not render | `nvgCreateFont()` not called in Start() |
| Click has no response | Using numeric `0` instead of `MOUSEB_LEFT` |
| UI layout wrong on device | Not using `UIScaler` or physical-resolution layout |
| `attempt to index nil` (arrays) | Array indexed from 0 — must start from 1 |
| Box2D collision not detected | Collision shape not on same node as RigidBody2D |
| Third-person camera jitter | Not using `ThirdPersonCamera` library |
| Multiplayer logic in wrong file | Did not read `multiplayer.enabled` from `.project/settings.json` |

---

## Specialist Skill Routing

When a narrower skill exists, prefer it over this one:

| Need | Use Skill |
|------|-----------|
| Character animation FSM | `setup-fsm` |
| Pixel art assets | `@game_pixel-art-generator` |
| 3D model import | `import-fbx` / `import-glb` |
| Materials and PBR | `materials` |
| Audio manager code | `audio-manager` |
| Game review and polish | `game-review-improve` |
| Performance optimization | `game-performance` |
| Multiplayer architecture | `multiplayer-game` |
| Evolutionary / adaptive AI | `evolutionary-game-systems` |
| JRPG system design | `@jrpg_jrpg-design` |

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/explore` | Analyze current project and recommend next features |
| `/learn [topic]` | Learning path + code examples for the topic |
| `/projects` | List game project ideas suited to current skill level |
| `/profile` | Assess code quality and produce improvement checklist |

---

## Reference Files

- Game design theory, level design, monetization → `references/game-design.md`
- Lua patterns, graphics, physics, multiplayer → `references/programming.md`
- Audio integration, build pipeline, TapTap publishing → `references/audio-publishing.md`
