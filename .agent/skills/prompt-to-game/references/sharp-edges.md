# Sharp Edges — Common Failure Modes in UrhoX Prompt-to-Game

## Severity: Critical

### SE-1: Skipping BUILD Step

**What happens**: Code looks correct but never runs. Errors accumulate silently across
multiple changes. When BUILD finally runs, dozens of errors are intertwined and hard to
isolate.

**Symptoms**:
- "It should work but nothing shows up"
- Multiple unrelated errors on first build
- Changes don't take effect

**Fix**: BUILD after EVERY code change. No exceptions. Even for "trivial" one-line fixes.

---

### SE-2: Array Index Starting at 0

**What happens**: Lua arrays are 1-based. Using index 0 returns `nil`, causing
`attempt to index a nil value` cascades.

**Pattern**:
```lua
-- ❌ Wrong (JavaScript/Python habit)
for i = 0, #items - 1 do
    items[i]:DoSomething()  -- items[0] is nil\!
end

-- ✅ Correct
for i = 1, #items do
    items[i]:DoSomething()
end
```

**Symptoms**:
- `attempt to index a nil value`
- First element always skipped
- Off-by-one in game logic

---

### SE-3: Using Native UI Instead of urhox-libs/UI

**What happens**: Native Urho3D UI system is deprecated. Code using `Text:new()`,
`Button:new()`, or `UIElement` directly will look wrong, lack features, and conflict
with the modern UI system.

**Pattern**:
```lua
-- ❌ Wrong (deprecated native UI)
local text = Text:new()
text:SetFont(cache:GetResource("Font", "Fonts/Anonymous Pro.ttf"), 15)
ui.root:AddChild(text)

-- ✅ Correct (urhox-libs/UI)
local UI = require("urhox-libs/UI")
UI.Init({ fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } } })
local root = UI.Panel { children = { UI.Label { text = "Hello", fontSize = 15 } } }
UI.SetRoot(root)
```

---

### SE-4: Using Magic Numbers for Input

**What happens**: Using `0` for left mouse button or `32` for spacebar instead of engine
enum constants. Values may not match engine internal representation.

**Pattern**:
```lua
-- ❌ Wrong
if button == 0 then ... end           -- MOUSEB_LEFT ≠ 0
if input:GetKeyDown(32) then ... end  -- KEY_SPACE ≠ 32

-- ✅ Correct
if button == MOUSEB_LEFT then ... end
if input:GetKeyDown(KEY_SPACE) then ... end
```

---

### SE-5: NanoVG Drawing Outside NanoVGRender Event

**What happens**: NanoVG draw calls in `HandleUpdate` or `HandlePostUpdate` produce
nothing. The rendering context is only valid inside the `NanoVGRender` event callback.

**Pattern**:
```lua
-- ❌ Wrong
function HandleUpdate(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)  -- Wrong event\!
    nvgCircle(vg, 100, 100, 50)
    nvgEndFrame(vg)
end

-- ✅ Correct
SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)
    nvgCircle(vg, 100, 100, 50)
    nvgEndFrame(vg)
end
```

---

### SE-6: NanoVG Font Not Created

**What happens**: Text rendering with NanoVG produces nothing (no error, just invisible).
`nvgCreateFont()` must be called once during initialization before any `nvgText()` calls.

**Pattern**:
```lua
-- ❌ Wrong: forgot to create font
function HandleNanoVGRender(eventType, eventData)
    nvgFontSize(vg, 24)
    nvgText(vg, 100, 100, "Hello")  -- Nothing appears\!
end

-- ✅ Correct: create font once in Start()
function Start()
    vg = nvgCreate(0)
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
end
```

**Also**: Never call `nvgCreateFont()` every frame — it leaks video memory.

---

## Severity: High

### SE-7: Code Outside scripts/ Directory

**What happens**: Code placed in wrong directory is not found by the build system.
All user game code must live in `scripts/`.

**Fix**: Always write to `/workspace/scripts/main.lua` (or subdirectories of `scripts/`).

---

### SE-8: Starting From Blank File

**What happens**: Missing critical boilerplate (scene creation, camera setup, event
subscription, input initialization). Game shows blank screen or crashes.

**Fix**: Always start from a scaffold template. The scaffold provides:
- Scene and camera setup
- Input handling initialization
- Event subscription boilerplate
- Proper `Start()` function structure

---

### SE-9: Using io Library

**What happens**: The `io` library has been removed from the Lua sandbox. Calls to
`io.open()`, `io.read()`, `io.write()` will crash.

**Pattern**:
```lua
-- ❌ Wrong
local f = io.open("save.json", "r")

-- ✅ Correct (use File API)
local file = File:new(fileSystem, "save.json", FILE_READ)
```

See `engine-docs/recipes/file-storage.md` for complete file I/O guide.

---

### SE-10: Wrong Material Technique Path

**What happens**: Using guessed technique paths like `Techniques/Diff.xml` or
`Techniques/PBR/PBR.xml` that don't exist. Materials fail to load.

**Fix**: For procedural (no-texture) materials, only use:
```lua
"Techniques/PBR/PBRNoTexture.xml"       -- Opaque PBR
"Techniques/PBR/PBRNoTextureAlpha.xml"  -- Transparent PBR
"Techniques/NoTextureUnlit.xml"         -- Unlit
```

---

### SE-11: Sunk-Cost Prompting Loop

**What happens**: Same error persists after 3+ fix attempts. Each fix introduces new
problems. Context becomes polluted with failed approaches.

**Symptoms**:
- Same error keeps returning
- Fixes undo previous fixes
- Increasing desperation in approach

**Fix**:
1. Stop after 3 failed attempts on the same issue
2. Re-read the relevant engine-docs section
3. Check examples for a working implementation of the same feature
4. If still stuck, strip to minimal reproduction and rebuild

---

### SE-12: Mega-Prompt Everything

**What happens**: Requesting entire complex game in a single iteration. Produces
inconsistent, intertwined code. Features conflict. Hard to debug.

**Pattern**:
```
❌ Bad: "做一个完整的RPG游戏，包含角色创建、回合制战斗、
背包系统、技能树、任务系统、对话树、存档、多人联机"

✅ Good: "先做一个角色在地图上移动的基础场景"
→ 测试通过后: "加上回合制战斗系统"
→ 测试通过后: "加上背包和装备"
```

**Fix**: Use component-by-component pattern. One feature per iteration.

---

## Severity: Medium

### SE-13: table.unpack Position Trap

**What happens**: `table.unpack()` only fully expands when it's the last item in a
table constructor. In other positions, it returns only the first value.

```lua
local items = {1, 2, 3}
-- ❌ {table.unpack(items), "extra"}  → {1, "extra"} (lost 2, 3\!)
-- ✅ {"extra", table.unpack(items)}  → {"extra", 1, 2, 3}
```

---

### SE-14: Not Checking Model Sizes

**What happens**: Assuming model dimensions (e.g., Box = 1x1x1) without verifying.
Positioning calculations are wrong.

**Fix**: Use `model.boundingBox.size` or check `engine-docs/built-in-models.md`.

---

### SE-15: Accepting Code Without Understanding

**What happens**: Generated code works initially but cannot be debugged, extended, or
explained when issues arise later.

**Fix**: Read every significant function. If a pattern is unclear, look it up in
engine-docs before accepting it.
