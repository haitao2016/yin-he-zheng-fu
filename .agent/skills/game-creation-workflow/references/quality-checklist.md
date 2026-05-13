# Game Quality Checklist

Comprehensive pre-delivery validation checklist for UrhoX Lua games. Work through each section before handing the game to the user.

## How to Use

- Run through each section in order
- Mark items as pass/fail
- Fix all CRITICAL items before delivery
- HIGH items should be fixed if time permits
- MEDIUM items are polish — nice to have

---

## 1. Core Game Loop [CRITICAL]

### Engagement
- [ ] Core mechanic understandable in < 5 seconds
- [ ] Player has a clear goal from the start
- [ ] Sense of progression exists (score, levels, unlocks)
- [ ] "One more try" quality — failure motivates retry
- [ ] Difficulty ramps gradually, not too steep or flat

### Controls
- [ ] Input feels responsive (no perceptible delay)
- [ ] Controls follow standard conventions (WASD/arrows, space=jump)
- [ ] Uses enum values (`KEY_SPACE`, `MOUSEB_LEFT`), not magic numbers
- [ ] No conflicting key bindings
- [ ] Mouse mode correct (`MM_RELATIVE` for FPS/TPS, `MM_ABSOLUTE` for menus)

### Feedback
- [ ] Every player action has visual feedback
- [ ] Score changes are animated (not just number swap)
- [ ] Negative events clearly communicated (damage flash, shake)
- [ ] Positive events feel rewarding (particles, sound, scale pop)

---

## 2. Visual Design [HIGH]

### Color & Style
- [ ] Intentional color palette (4-6 colors, not random)
- [ ] High contrast between interactive and background elements
- [ ] Color conveys meaning (red=danger, green=safe, gold=reward)
- [ ] Visual style is cohesive (not mixing flat and realistic)
- [ ] Background doesn't compete with foreground

### Materials & Lighting (3D)
- [ ] PBR materials use appropriate roughness (0.3-0.8 typical)
- [ ] Metallic values are binary (0.0 or 1.0, never between)
- [ ] Scene has directional light + ambient zone
- [ ] Shadows enabled for depth perception
- [ ] Using `PBRNoTexture.xml` for procedural materials

### Typography
- [ ] Font readable at all sizes used
- [ ] Sufficient contrast between text and background
- [ ] Text sizes follow hierarchy (title > subtitle > body > caption)
- [ ] Using `Fonts/MiSans-Regular.ttf` for CJK support

---

## 3. UI / UX [HIGH]

### HUD
- [ ] Score/progress always visible during gameplay
- [ ] HUD doesn't obstruct gameplay area
- [ ] HUD positioned in standard locations (score top, health top-left)
- [ ] HUD updates smoothly (animated transitions)
- [ ] Using `urhox-libs/UI` system (not native UI)

### Menus
- [ ] Game has a start/title screen
- [ ] Game over screen shows final score
- [ ] Restart option clearly available
- [ ] Clean state reset on restart (no leftover objects/timers)

### Responsiveness
- [ ] UI scales on different screen sizes
- [ ] Using `UI.Scale.DEFAULT` for automatic scaling
- [ ] No text overflow or clipping
- [ ] Layout uses Flexbox properties (justifyContent, alignItems)

---

## 4. Audio [MEDIUM]

### Sound Effects
- [ ] Key actions have sound effects (jump, collect, hit, score)
- [ ] Sound style matches visual style
- [ ] Volume levels balanced (SFX don't drown each other)

### Music (if applicable)
- [ ] Background music matches game mood
- [ ] Music loops seamlessly
- [ ] Music doesn't overwhelm sound effects

---

## 5. Technical Quality [CRITICAL]

### Stability
- [ ] No console errors during normal gameplay
- [ ] No nil access errors in any game state
- [ ] Game handles rapid input without breaking
- [ ] Screen edge cases handled (clamp/wrap/destroy)

### Performance
- [ ] Consistent frame rate during gameplay
- [ ] No memory leaks (nodes cleaned up on destroy/restart)
- [ ] Object pooling for frequently spawned entities
- [ ] No per-frame resource allocation (materials, models)

### Code Quality
- [ ] Variables properly typed (Rule #11 — annotate nil-init vars)
- [ ] Array indices start from 1 (Rule #4)
- [ ] Event data accessed correctly (`eventData["Key"]:GetType()`)
- [ ] Resource paths correct (no `assets/` prefix — Rule #1.5)
- [ ] Module structure if > 1000 lines (Rule #13)

### Build
- [ ] MCP build tool called after final changes
- [ ] Build completes without errors
- [ ] No LSP warnings in game code

---

## 6. Accessibility [MEDIUM]

- [ ] Core info not conveyed by color alone (add shape/text cues)
- [ ] Text meets minimum contrast ratio (4.5:1)
- [ ] Game playable without audio (visual cues for all audio events)
- [ ] Controls learnable by trial and error

---

## 7. Game Feel / Juice [HIGH]

### Low Effort, High Impact
- [ ] Screen shake on impactful events
- [ ] Scale "pop" on score changes
- [ ] Particle effects on key events (collect, destroy)
- [ ] Smooth camera transitions (no sudden jumps)

### Medium Effort
- [ ] Trail effects behind fast objects
- [ ] Animated state transitions (fade/slide between menus)
- [ ] Background parallax (side-scrollers)
- [ ] Object squash/stretch on movement

---

## 8. UrhoX-Specific Checks [CRITICAL]

- [ ] Code lives in `scripts/` directory
- [ ] Started from scaffold (not blank file)
- [ ] `graphics:SetMode()` NOT used (banned — Rule #0.8)
- [ ] Materials use `PBRNoTexture.xml` or `PBRNoTextureAlpha.xml`
- [ ] Input uses `KEY_*` / `MOUSEB_*` enums
- [ ] UI uses `urhox-libs/UI`, not native UI
- [ ] NanoVG renders in `NanoVGRender` event (if used)
- [ ] NanoVG font created with `nvgCreateFont` before text draw
- [ ] `nvgCreateFont` called only once (not per frame)
- [ ] Build tool called after all changes

---

## Quick Severity Guide

| Severity | Definition | Action |
|----------|-----------|--------|
| CRITICAL | Game broken, won't run, or violates engine rules | Must fix |
| HIGH | Noticeable quality issue, affects player experience | Should fix |
| MEDIUM | Polish item, nice to have | Fix if time permits |

## Scoring (Optional)

Rate each section 1-5:

| Section | Score | Notes |
|---------|-------|-------|
| Core Loop | /5 | |
| Visual Design | /5 | |
| UI/UX | /5 | |
| Audio | /5 | |
| Technical | /5 | |
| Accessibility | /5 | |
| Game Feel | /5 | |
| UrhoX Compliance | /5 | |
| **Total** | **/40** | |

**Thresholds**: 32+ = Ship-ready, 24-31 = Needs polish, <24 = Needs significant work
