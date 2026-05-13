---
name: game-cog
description: |
  Concept-driven, style-consistent cross-modal game asset generation for UrhoX Lua games.
  From a single game concept, generate a complete, visually unified asset set covering 2D art, 3D models, SFX, and BGM.
  Core value: style consistency via shared style anchors and reference chaining.
  Use when users need to (1) generate a complete asset set from a game concept,
  (2) create style-consistent characters/items/environments/UI as a family,
  (3) produce cross-modal assets (2D+3D+audio) for one cohesive game,
  (4) apply an art style uniformly to all assets,
  (5) batch-produce assets from a genre template (RPG, platformer, shooter, puzzle),
  (6) user says "game-cog", "generate all assets", "concept to assets",
  (7) user says "从概念生成素材", "一键生成游戏资源", "统一风格素材",
  (8) user describes a game idea and wants all art/audio assets created together.
  file types: .png, .jpg, .ogg, .wav, .mdl
---

# Game Cog — Concept-to-Assets Generator

From a single game concept, generate a complete, style-consistent cross-modal asset set for UrhoX Lua games.

## When to Trigger

- User describes a game idea and wants **all assets** generated together
- User wants **style-consistent** asset families (not one-off images)
- User says "game-cog", "从概念生成素材", "统一风格", "一键生成"
- User picks a genre and wants a ready-to-use asset pack

## When to Delegate

| Situation | Delegate To |
|-----------|-------------|
| Scan code for missing assets, fill gaps | `auto-game-assets` |
| Design pipeline architecture, define contracts | `ai-asset-pipeline` |
| Find/download free assets from websites | `game-assets-finder` |
| Pixel art specifically | `@game_pixel-art-generator` |
| Character portraits batch | `@m-mikoto_character-portraits` |
| Single one-off image or sound | Direct tool call |
| Full game creation (code + assets) | `game-creation-workflow` |

## Core Workflow

```
Phase 1: CONCEPT   → Extract game concept, genre, core entities
Phase 2: STYLE     → Define art style anchor (palette, art direction, prompt template)
Phase 3: INVENTORY → Build categorized asset list from genre template
Phase 4: CONFIRM   → Present asset plan to user for review
Phase 5: GENERATE  → Batch-produce all assets with style consistency
Phase 6: DELIVER   → Verify, organize into assets/, report summary
```

### Phase 1: Concept Extraction

Ask the user (or infer from context) these key parameters:

| Parameter | Example | Required? |
|-----------|---------|-----------|
| **Game genre** | 平台跳跃 / RPG / 射击 / 塔防 / 解谜 | Yes |
| **Art style** | 像素 / 卡通 / 手绘 / 低多边形 / 写实 / 动漫 | Yes |
| **Theme/setting** | 中世纪奇幻 / 太空科幻 / 现代都市 / 水下世界 | Yes |
| **Color mood** | 明亮欢快 / 暗黑神秘 / 柔和治愈 / 复古怀旧 | Recommended |
| **Core entities** | 玩家角色, 3种敌人, 5种道具, 2种场景 | Yes |
| **Target dimension** | 2D / 3D / 2.5D | Yes |

If the user provides a single sentence like "做一个太空射击游戏", infer reasonable defaults and present them for confirmation.

### Phase 2: Style Definition

Define a **Style Anchor** — a reusable style DNA applied to every asset.

#### Style Anchor Structure

```
Style Anchor = {
  style_prefix:  "风格描述, 放在每个 prompt 开头"
  style_suffix:  "质量/技术约束, 放在每个 prompt 结尾"
  palette:       "主色 + 辅色 + 强调色"
  reference_seed: 42 (optional, for reproducibility)
}
```

#### Building the Style Anchor

1. **Select art style preset** — see `references/art-styles.md` for 8 built-in presets
2. **Generate a style reference image** — create one "hero image" that defines the visual DNA
3. **Lock the reference** — use this hero image as `reference_images` for all subsequent assets

#### Style Consistency Rules

1. **Same prefix/suffix** for all prompts in the same asset family
2. **Reference chaining**: hero image → character variants → item icons → environment
3. **Same seed** when generating variants of the same base
4. **Same target_size** within each asset category

### Phase 3: Asset Inventory

Build a complete asset list based on game genre. Use genre templates from `references/genre-asset-templates.md`.

| Category | Typical Assets | Tool |
|----------|---------------|------|
| **Characters** | Player, enemies, NPCs | `generate_image` or `create_3d_model_task` |
| **Items** | Weapons, power-ups, collectibles | `batch_generate_images` (transparent) |
| **Environment** | Ground tiles, backgrounds, obstacles | `batch_generate_images` or `search_game_resource` |
| **UI Elements** | Health bar, buttons, panels, icons | `batch_generate_images` (transparent) |
| **SFX** | Jump, hit, collect, death, menu click | `batch_sound_effects` |
| **BGM** | Main theme, battle, menu, game over | `text_to_music` |
| **3D Models** | Characters, props, environment pieces | `search_game_resource` then `create_3d_model_task` |

### Phase 4: Confirmation

Present the complete asset plan as a structured table report. Include:
- Game concept summary (genre, style, theme)
- Style anchor (prefix, suffix, palette)
- Full asset list by category with columns: #, name, description, size, transparent

Example format:

```
## Game Cog 资产生成计划

### 游戏概念
- 类型: 太空射击 | 风格: 像素 | 主题: 宇宙探险

### 风格锚点
- Prefix: "像素风格, 16位复古, 深蓝太空, 荧光色调"
- Suffix: "清晰像素边缘, 高对比度"

### 资产清单 (共 N 个)
[categorized tables...]

确认生成？可修改任何描述后再确认。
```

**Wait for user confirmation before proceeding.**

### Phase 5: Generation

Execute in strict order (dependencies matter):

**Step 1 — Hero Image** (style reference for everything else):
```
generate_image(prompt="{prefix}, {主角描述}, {suffix}", target_size="512x512", name="style_hero")
```

**Step 2 — Characters** (sequential, each references hero image):
```
generate_image(prompt="...", reference_images=[hero_path], transparent=true, ...)
```

**Step 3 — Items & UI** (batch, all reference hero image):
```
batch_generate_images(images=[...all reference hero_path...])
```

**Step 4 — Environment** (search library first for 3D, generate for 2D):
```
search_game_resource(wanted_resource="...") → found? use it : generate
```

**Step 5 — Sound Effects** (batch):
```
batch_sound_effects(sounds=[...English descriptions...])
```

**Step 6 — BGM** (one at a time, auto-polls):
```
text_to_music(prompt="...", customMode=true, instrumental=true, ...)
```

**Step 7 — 3D Models** (search-first, two-phase if generating):
```
search_game_resource → not found → create_3d_model_task(Phase1→confirm→Phase2)
```

### Phase 6: Delivery

1. **Organize** files into `assets/{Textures,Sounds,Music,Models}/` subdirectories
2. **Verify** all files exist with `ls`
3. **Generate manifest** — `assets/asset_manifest.lua` mapping logical names to paths
4. **Report** summary with counts and sizes per category
5. **Run build** tool to verify project compiles

## Style Consistency Techniques

### Reference Image Chaining

```
Hero Image → Character A (ref: hero) → Character B (ref: hero)
    ↓
Item Icons (batch, all ref: hero)
    ↓
Environment (ref: hero for color harmony)
```

### Prompt Template Pattern

Lock style, vary only subject:
```
TEMPLATE = "{prefix}, {SUBJECT}, {suffix}"
prefix = "卡通风格, 粗线条, 明亮色彩"   ← LOCKED
suffix = "清晰轮廓, 高饱和度"           ← LOCKED
SUBJECT = per-asset variable             ← VARIES
```

### Variation via edit_image

Create controlled variants from a base:
```
Base enemy → edit_image("改为红色")     → Elite variant
           → edit_image("添加盔甲")     → Armored variant
           → edit_image("增大, 加翅膀") → Boss variant
```

## Default Generation Parameters

| Asset Type | target_size | aspect_ratio | transparent | Tool |
|-----------|-------------|--------------|-------------|------|
| Character sprite | 256x256 | 1:1 | true | generate_image |
| Item icon | 64x64 or 128x128 | 1:1 | true | batch_generate_images |
| UI button | 256x128 | 2:1 | true | generate_image |
| Background | 1024x512 | 16:9 | false | generate_image |
| Tile | 256x256 | 1:1 | false | batch_generate_images |
| Short SFX | - | - | - | batch_sound_effects (0.3-1s) |
| Medium SFX | - | - | - | batch_sound_effects (1-3s) |
| Ambient loop | - | - | - | text_to_sound_effect (5-10s, loop) |
| BGM | - | - | - | text_to_music (instrumental) |

## References

- **Art style presets & prompt templates**: see [references/art-styles.md](references/art-styles.md)
- **Genre-specific asset checklists**: see [references/genre-asset-templates.md](references/genre-asset-templates.md)
