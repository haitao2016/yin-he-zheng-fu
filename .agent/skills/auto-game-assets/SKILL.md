---
name: auto-game-assets
description: |
  Automatically scan game project code, identify missing assets (textures, icons, sound effects, BGM, 3D models),
  and batch-generate them using AI tools. Use when users need to:
  (1) generate all missing game assets automatically,
  (2) batch-create textures/icons/sounds for their game,
  (3) fill in placeholder or missing resources referenced in code,
  (4) user says "generate assets", "create game resources", "fill missing assets",
  (5) user says "生成素材", "补全资源", "自动生成资源", "批量生成素材", "缺少素材".
  Covers: 2D images (textures, icons, UI), sound effects, background music, and 3D models.
  file types: .png, .jpg, .ogg, .wav, .mdl
  or tasks that trigger it.
---

# Auto Game Assets

Scan game code for referenced-but-missing assets, present an analysis report for user confirmation, then batch-generate assets using AI tools.

## Workflow

```
Phase 1: SCAN   → Grep scripts/ for resource references
Phase 2: CHECK  → Verify which assets exist in assets/
Phase 3: REPORT → Present missing assets list to user
Phase 4: GENERATE → After user confirms, batch-generate
Phase 5: VERIFY → Confirm generated files, rebuild project
```

## Phase 1: Scan

Use Grep to find all resource references in `scripts/` directory.

**Search patterns** (run all in parallel):

```
# Textures
grep: cache:GetResource\("Texture2D",\s*"([^"]+)"     in scripts/
grep: nvgCreateImage\(vg,\s*"([^"]+)"                  in scripts/

# Sounds
grep: cache:GetResource\("Sound",\s*"([^"]+)"          in scripts/

# Models
grep: cache:GetResource\("Model",\s*"([^"]+)"          in scripts/

# Fonts
grep: cache:GetResource\("Font",\s*"([^"]+)"           in scripts/
grep: nvgCreateFont\(vg,\s*"[^"]*",\s*"([^"]+)"        in scripts/
```

Extract all unique resource paths from matches.

## Phase 2: Check Existence

For each found resource path:

1. Determine the real file location: resource paths are relative to `assets/` or `scripts/` (both are resource roots)
2. Check if file exists: `ls assets/{path}` or `ls scripts/{path}`
3. **Skip built-in resources** that do not need generation (see `references/resource-patterns.md` § Built-in Resources)

Classify each missing resource:

| Classification | Criteria | Generatable? |
|---------------|----------|-------------|
| **image** | `.png`/`.jpg` in `Textures/`/`UI/`/`Sprites/` | Yes → `generate_image` |
| **icon** | `.png` with small implied size (≤256px), or path has `Icon`/`icon` | Yes → `generate_image` (transparent) |
| **sfx** | `.ogg`/`.wav` in `Sounds/`/`SFX/`, or variable name has `sound`/`sfx` | Yes → `text_to_sound_effect` |
| **bgm** | `.ogg` in `Music/`/`BGM/`, or variable name has `music`/`bgm` | Yes → `text_to_music` |
| **model** | `.mdl` in `Models/` (non-built-in) | Yes → `search_game_resource` then `create_3d_model_task` |
| **font** | `.ttf`/`.otf` | No → suggest built-in alternative |
| **other** | `.xml` materials, particles, animations | No → note in report |

## Phase 3: Report

Present a formatted report to the user. Example:

```
## 素材分析报告

扫描了 scripts/ 下的 N 个文件，发现 M 个资源引用，其中 X 个缺失。

### 可自动生成 (Y 个)

| # | 类型 | 资源路径 | 建议描述 | 尺寸/时长 |
|---|------|---------|---------|----------|
| 1 | 🖼 图片 | Textures/player.png | 太空战舰，俯视角 | 256x256 |
| 2 | 🖼 图标 | UI/coin_icon.png | 金色硬币图标，透明背景 | 64x64 |
| 3 | 🔊 音效 | Sounds/explosion.ogg | 太空爆炸音效 | 1.5s |
| 4 | 🎵 BGM | Music/battle.ogg | 紧张的太空战斗BGM | - |
| 5 | 🧊 模型 | Models/spaceship.mdl | 科幻战舰3D模型 | - |

### 不可自动生成 (Z 个)

| 资源路径 | 原因 | 建议 |
|---------|------|------|
| Materials/custom.xml | 材质XML需代码创建 | 在代码中程序化生成 |

### 已存在 (W 个) ✅
（省略列表）

请确认是否按以上描述生成？可修改描述后再确认。
```

**Description inference rules**:
- Derive descriptions from: file name, path context, surrounding code comments, variable names, game context
- Read 5-10 lines around each resource reference to understand usage context
- Use Chinese descriptions for `generate_image` prompts
- Use English descriptions for `text_to_sound_effect` prompts
- Suggest appropriate `target_size` based on usage (icon→64x64/128x128, texture→256x256/512x512, background→1024x512)
- Set `transparent: true` for icons and UI elements

## Phase 4: Generate

After user confirms (they may modify descriptions/sizes), batch-generate all assets.

### Generation order (respect dependencies):
1. **Images** → use `batch_generate_images` (up to 10 per batch)
2. **Sound effects** → use `batch_sound_effects`
3. **BGM** → use `text_to_music` (one at a time)
4. **3D models** → first `search_game_resource`, if not found then `create_3d_model_task`

### Image generation defaults:

```
Icons:        target_size="128x128", aspect_ratio="1:1", transparent=true
UI elements:  target_size="256x256", aspect_ratio="1:1", transparent=true
Textures:     target_size="512x512", aspect_ratio="1:1"
Backgrounds:  target_size="1024x512", aspect_ratio="16:9"
```

### Sound effect defaults:

```
Short SFX (click/hit):   duration=0.5-1.0s
Medium SFX (explosion):  duration=1.5-3.0s
Ambient/loop:            duration=5-10s, loop=true
```

### File output location:

All generated files go to `assets/` under the path referenced in code:
- Code says `cache:GetResource("Texture2D", "Textures/player.png")`
- Generate to: `assets/Textures/player.png`

Create subdirectories as needed with `mkdir -p`.

## Phase 5: Verify

After generation:
1. List all generated files with sizes
2. Run the `build` tool to rebuild the project
3. Report completion summary

## References

- Detection patterns and built-in resource list: see [references/resource-patterns.md](references/resource-patterns.md)
