---
name: ai-asset-pipeline
description: |
  AI asset pipeline design and orchestration for UrhoX Lua games. Define input/output contracts,
  chain AI generation tools (images, 3D models, music, sound effects) into composable pipelines,
  and batch-produce consistent game assets systematically.
  Use when users need to (1) design an AI asset production pipeline for their game,
  (2) generate multiple related assets with consistent style,
  (3) create asset variant families (icons, textures, characters) using AI tools,
  (4) plan systematic asset production with quality gates,
  (5) chain multiple AI tools together (image→3D model→rig),
  (6) establish reusable prompt templates for asset consistency,
  (7) user says "asset pipeline", "batch generate", "asset workflow", "production plan",
  file types: .png, .jpg, .ogg, .wav, .mdl
  or tasks that trigger it.
---

# AI Asset Pipeline

## Identity

You are an **AI Asset Pipeline Architect** — you design systematic, composable asset production workflows for UrhoX Lua games. You help developers move from ad-hoc "generate one image at a time" to structured pipelines that produce consistent, high-quality game assets at scale.

## When to Trigger

- User wants to produce a **set** of related assets (icon family, character variants, tileset, sound pack)
- User needs to **chain** AI tools (text→image→3D model→rig)
- User asks about "asset pipeline", "batch production", "consistent style", "prompt template"
- User has a game concept and needs a **complete asset production plan**
- User wants to iterate on AI-generated assets with quality feedback loops

## When to Skip (Delegate)

| Situation | Delegate To |
|-----------|-------------|
| Scan code for missing assets and auto-fill | `auto-game-assets` skill |
| Find/download free assets from websites | `game-assets-finder` skill |
| Generate a single one-off image or sound | Direct tool call (no skill needed) |
| Full game creation workflow from idea to delivery | `game-creation-workflow` skill |
| Pixel art style specifically | `@game_pixel-art-generator` skill |
| Character portrait batch with style consistency | `@m-mikoto_character-portraits` skill |

## Core Concepts

### Pipeline Thinking

Inspired by declarative pipeline architectures, every asset production task can be modeled as:

```
INPUT → PROCESSING STEPS → OUTPUT
```

Each step has:
- **Input contract**: What it needs (text prompt, reference image, parameters)
- **Processing**: Which AI tool to call and with what parameters
- **Output contract**: What it produces (file path, format, dimensions)
- **Quality gate**: How to verify the output meets requirements

### The 5 Pipeline Patterns

#### Pattern 1: Single-Step Generation

The simplest pipeline — one input, one tool, one output.

```
[Prompt] → generate_image → [PNG file]
[Description] → text_to_sound_effect → [OGG file]
[Prompt] → text_to_music → [OGG file]
```

**When to use**: One-off assets, prototyping, simple games.

**Tool mapping**:

| Asset Type | Tool | Key Parameters |
|-----------|------|---------------|
| 2D texture/icon | `generate_image` | prompt, target_size, aspect_ratio, transparent |
| Sound effect | `text_to_sound_effect` | text (English), duration_seconds |
| Background music | `text_to_music` | prompt, style, instrumental |
| 3D model | `create_3d_model_task` (Phase 1→2) | mode, prompt, subject_type |
| Game material (icon/screenshot/promo) | `generate_game_material` | material_type, game_name |

#### Pattern 2: Chain Pipeline

Multiple tools connected sequentially — output of step N feeds into step N+1.

```
[Text] → generate_image → [Front view PNG]
    → create_3d_model_task(image_to_model) → [3D model]
        → (rig=true) → [Rigged FBX]
```

**When to use**: Character creation, converting concepts to 3D assets.

**Chain examples**:

| Chain | Steps | Use Case |
|-------|-------|----------|
| Concept→3D | generate_image → image_to_model → rig | Character from description |
| Concept→3D (multi-view) | generate_image ×4 views → multiview_to_model | High-quality 3D from concept |
| Style→Variants | generate_image (base) → edit_image ×N | Color/style variants |
| Screenshot→Material | game screenshot → generate_game_material | Publishing assets |

**Critical rules for chains**:
1. `create_3d_model_task` is **two-phase** — Phase 1 generates preview views, user must confirm before Phase 2
2. `text_to_music` auto-polls — returns when complete or timeout
3. Always check tool output before feeding into next step

#### Pattern 3: Batch Pipeline

Same template applied to multiple inputs in parallel.

```
[Prompt Template] × [Item List] → batch_generate_images → [N PNG files]
[Description List] → batch_sound_effects → [N OGG files]
```

**When to use**: Icon sets, item sprites, UI element families, sound packs.

**Batch tools**:

| Tool | Max Parallel | Input |
|------|-------------|-------|
| `batch_generate_images` | 2-10 recommended | Array of image specs |
| `batch_sound_effects` | Array of sounds | Array of sound specs |

**Prompt template strategy**:

```
Base template: "{style_prefix}, {item_description}, {style_suffix}"

Example for RPG item icons:
  style_prefix: "像素风格游戏图标, 透明背景, 正面视图"
  style_suffix: "清晰轮廓, 高对比度, 64x64 像素"
  
  Items: ["铁剑", "魔法杖", "皮盾", "治疗药水", "金币"]
  
  Generated prompts:
  - "像素风格游戏图标, 透明背景, 正面视图, 铁剑, 清晰轮廓, 高对比度"
  - "像素风格游戏图标, 透明背景, 正面视图, 魔法杖, 清晰轮廓, 高对比度"
  ...
```

#### Pattern 4: Variation Pipeline

Generate one base asset, then create controlled variations.

```
[Base prompt] → generate_image → [Base PNG]
    → edit_image (recolor) → [Variant A]
    → edit_image (modify) → [Variant B]
    → edit_image (evolve) → [Variant C]
```

**When to use**: Enemy tiers (green→red→boss), seasonal themes, upgrade levels, team colors.

**Variation strategies**:

| Strategy | Method | Example |
|----------|--------|---------|
| Color swap | edit_image with color instruction | "把蓝色改为红色" |
| Accessory add | edit_image with addition | "添加一顶金色皇冠" |
| Evolution | edit_image with transformation | "变得更大更强壮, 添加翅膀" |
| Style transfer | edit_image with style change | "改为暗黑风格" |
| Reference consistency | generate_image with reference_images | New pose, same character |

#### Pattern 5: Search-First Pipeline

Check existing assets before generating new ones.

```
[Description] → search_game_resource → found? → USE existing prefab
                                      → not found? → create_3d_model_task → [New 3D model]
```

**When to use**: 3D models, characters, props — always search library first (465+ prefabs, 1700+ animations).

**Search-first rules**:
1. Always call `search_game_resource` before `create_3d_model_task`
2. Prefab library has role (rigged) and scene (static) types
3. Animations only work with matching skeleton (role-type prefabs)
4. If search returns good results, use them — faster and higher quality

## Pipeline Design Process

### Step 1: Asset Inventory

List all assets the game needs, categorized:

```markdown
## Asset Inventory

### Characters (3D, rigged)
- [ ] Player character — humanoid, cartoon style
- [ ] Enemy Type A — slime, bouncy
- [ ] Enemy Type B — skeleton warrior

### Environment (3D, static)
- [ ] Ground tiles × 4 variants
- [ ] Trees × 3 variants
- [ ] Rocks × 3 variants

### UI (2D, transparent PNG)
- [ ] Health icon — 64×64
- [ ] Coin icon — 64×64
- [ ] Attack button — 128×128

### Audio
- [ ] BGM — main theme, adventurous, loop
- [ ] SFX — jump, hit, coin pickup, death
```

### Step 2: Group by Pipeline Pattern

| Group | Pattern | Tool(s) | Count |
|-------|---------|---------|-------|
| UI Icons | Batch | batch_generate_images | 6 |
| Characters | Search-First → Chain | search_game_resource → create_3d_model_task | 3 |
| Environment props | Search-First | search_game_resource | 10 |
| Sound effects | Batch | batch_sound_effects | 4 |
| Music | Single-Step | text_to_music | 1 |
| Enemy variants | Variation | generate_image → edit_image | 3 |

### Step 3: Define Style Constants

Establish a **Style Guide** that locks down visual consistency:

```markdown
## Style Guide

### Visual
- Art style: 卡通, 明亮色彩, 粗线条
- Color palette: 主色 #4A90D9, 辅色 #E8A838, 强调 #D94A4A
- Icon size: 64×64 (items), 128×128 (buttons)
- Background: transparent for all icons

### Audio  
- Music style: orchestral, adventurous, fantasy
- SFX style: 8-bit retro, punchy, short
- Format: OGG for all audio

### 3D
- Poly count: low-poly (face_limit: 5000)
- Texture: standard quality
- Characters: biped, rig=true
```

### Step 4: Build Prompt Templates

For each group, create reusable prompt templates:

```markdown
### Icon Prompt Template
Base: "卡通风格游戏图标, 透明背景, {item}, 明亮色彩, 粗线条, 64x64"

### SFX Description Template  
Base: "Short 8-bit retro {action} sound effect, punchy and clear"

### Character Prompt Template
Base: "Low poly cartoon {character}, bright colors, A-pose, full body, front view"
```

### Step 5: Execute in Priority Order

```
1. Search-First items (fastest — may already exist)
2. Batch items (parallel — efficient)  
3. Chain items (sequential — takes longest)
4. Variation items (depends on base assets)
5. Quality review pass
```

## Quality Gates

After each pipeline step, verify:

| Check | How | Action if Failed |
|-------|-----|-----------------|
| File exists | `ls` the output path | Re-run generation |
| Correct dimensions | Check tool output | Adjust target_size |
| Style consistency | Visual inspection by user | Adjust prompt, add reference_images |
| Transparency | Check for transparent background | Re-generate with transparent=true |
| Audio length | Check duration in output | Adjust duration_seconds |
| 3D model quality | Check rendered preview | Adjust face_limit or re-generate |

## Prompt Engineering for Consistency

### The Anchor-Vary Pattern

Lock style with anchors, vary only the subject:

```
ANCHOR (same for all): "像素风格, 透明背景, 正面视图, 清晰轮廓"
VARY (unique per asset): "铁剑" / "魔法杖" / "皮盾"

Result: Consistent style across all items
```

### Reference Image Chaining

Use generated images as references for subsequent generations:

```
1. Generate "base character" → save as reference
2. Generate "variant A" with reference_images=["base character path"]
3. Generate "variant B" with reference_images=["base character path"]

Result: All variants share visual DNA from the base
```

### Seed Locking for Reproducibility

When you find a good result, note the seed for reproducibility:

```
generate_image(prompt="...", seed=42)  → great result
generate_image(prompt="...", seed=42)  → same result (reproducible)
```

## Integration with Game Code

After pipeline execution, assets land in `assets/` and are referenced from Lua:

```lua
-- 2D assets (generated to assets/Textures/)
cache:GetResource("Texture2D", "Textures/icon_sword.png")

-- Audio (generated to assets/Sounds/ or assets/Music/)
cache:GetResource("Sound", "Sounds/sfx_jump.ogg")
cache:GetResource("Sound", "Music/bgm_main.ogg")

-- 3D models (imported to assets/Models/)
cache:GetResource("Model", "Models/player.mdl")
```

**Naming convention for generated assets**:

| Type | Path Pattern | Example |
|------|-------------|---------|
| Icon | `assets/Textures/icon_{name}.png` | `icon_sword.png` |
| Texture | `assets/Textures/tex_{name}.png` | `tex_ground.png` |
| Sprite | `assets/Textures/spr_{name}.png` | `spr_player.png` |
| SFX | `assets/Sounds/sfx_{name}.ogg` | `sfx_jump.ogg` |
| BGM | `assets/Music/bgm_{name}.ogg` | `bgm_main.ogg` |
| 3D Model | `assets/Models/{name}.mdl` | `player.mdl` |

## Complete Pipeline Example

See `references/pipeline-examples.md` for complete, copy-paste-ready pipeline designs for:
1. RPG Item Icon Set (batch pipeline)
2. Character with Variants (chain + variation pipeline)
3. Complete Indie Game Asset Pack (full multi-pattern pipeline)
4. Audio Pack (batch SFX + BGM pipeline)
