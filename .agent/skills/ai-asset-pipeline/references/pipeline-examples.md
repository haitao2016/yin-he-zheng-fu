# Pipeline Examples

Complete, actionable pipeline designs for common game asset production scenarios.

---

## Example 1: RPG Item Icon Set

**Scenario**: Generate 10 RPG item icons with consistent pixel art style.

### Style Constants

```
Art style: 像素风格游戏图标
Background: 透明
Size: 128×128
View: 正面视图
Line: 清晰轮廓, 高对比度
```

### Prompt Template

```
"{item_description}, 像素风格游戏图标, 透明背景, 正面视图, 清晰轮廓, 高对比度"
```

### Asset List

| # | Item | Prompt (item_description part) |
|---|------|------|
| 1 | Iron Sword | 铁剑, 灰色金属剑身, 棕色剑柄 |
| 2 | Magic Staff | 紫色魔法杖, 顶部有发光水晶 |
| 3 | Wooden Shield | 圆形木盾, 铁边装饰 |
| 4 | Health Potion | 红色治疗药水瓶, 心形标签 |
| 5 | Mana Potion | 蓝色魔法药水瓶, 星形标签 |
| 6 | Gold Coin | 金色硬币, 正面有皇冠图案 |
| 7 | Iron Helmet | 铁制头盔, 带护鼻 |
| 8 | Leather Armor | 棕色皮甲, 带金属扣 |
| 9 | Magic Ring | 金色戒指, 镶嵌红色宝石 |
| 10 | Treasure Chest | 木质宝箱, 金色锁扣, 微开 |

### Execution Plan

**Step 1: Batch generate (2 batches of 5)**

```
batch_generate_images:
  Batch 1 (items 1-5):
    images:
      - prompt: "铁剑, 灰色金属剑身, 棕色剑柄, 像素风格游戏图标, 透明背景, 正面视图, 清晰轮廓"
        name: "icon_iron_sword"
        target_size: "128x128"
        transparent: true
      - prompt: "紫色魔法杖, 顶部有发光水晶, 像素风格游戏图标, 透明背景, 正面视图, 清晰轮廓"
        name: "icon_magic_staff"
        target_size: "128x128"
        transparent: true
      ... (3 more)

  Batch 2 (items 6-10): same pattern
```

**Step 2: Quality review**

- Check all 10 PNGs exist in output
- Verify transparent background
- Visual consistency check — if any outlier, re-generate with reference_images from a good one

**Step 3: Organize**

Move generated files to `assets/Textures/` with consistent naming.

---

## Example 2: Character with Tier Variants

**Scenario**: Create a slime enemy with 3 tiers (green→blue→red) using variation pipeline.

### Pipeline

```
Step 1: Generate base slime
  generate_image:
    prompt: "卡通风格绿色史莱姆怪物, 可爱圆润, 透明背景, 正面视图, 大眼睛, 简单设计"
    name: "slime_base"
    target_size: "512x512"
    transparent: true
    → Output: slime_base_TIMESTAMP.png

Step 2: Create blue variant (Tier 2)
  edit_image:
    image: [slime_base output path]
    prompt: "把绿色改为深蓝色, 添加冰晶效果在头顶, 保持其他不变"
    name: "slime_blue"
    target_size: "512x512"
    transparent: true
    → Output: slime_blue_TIMESTAMP.png

Step 3: Create red variant (Tier 3 — Boss)
  edit_image:
    image: [slime_base output path]
    prompt: "把绿色改为暗红色, 变大1.5倍, 添加愤怒的表情和火焰光环, 添加小皇冠"
    name: "slime_boss"
    target_size: "512x512"
    transparent: true
    → Output: slime_boss_TIMESTAMP.png
```

### Quality Gates

| Check | Criteria |
|-------|---------|
| Base quality | Clear silhouette, cute design, clean edges |
| Color difference | Each tier clearly distinguishable at game resolution |
| Style consistency | All 3 share same art style and proportions |
| Transparency | All backgrounds fully transparent |

---

## Example 3: Complete Indie Game Asset Pack

**Scenario**: Produce all assets for a simple 3D platformer.

### Phase 1: Asset Inventory

```
Characters:
  [C1] Player — cartoon humanoid, bright colors
  [C2] Enemy Slime — bouncy green blob
  [C3] NPC Shopkeeper — friendly old man

Environment:
  [E1] Ground block — grassy top, dirt sides
  [E2] Stone block — grey stone texture
  [E3] Tree — cartoon pine tree
  [E4] Mushroom — red spotted mushroom

UI:
  [U1] Heart icon — 64×64, red
  [U2] Coin icon — 64×64, gold
  [U3] Star icon — 64×64, yellow
  [U4] Play button — 128×128
  [U5] Settings gear — 64×64

Audio:
  [A1] BGM Main — adventurous orchestral loop
  [A2] SFX Jump — short bouncy
  [A3] SFX Coin — cheerful pickup ding
  [A4] SFX Hit — impact thud
  [A5] SFX Death — sad descending tone
  [A6] SFX Button — UI click
```

### Phase 2: Pipeline Assignment

| Group | Pattern | Priority |
|-------|---------|----------|
| Characters [C1-C3] | Search-First → Chain | 3 (slowest) |
| Environment [E1-E4] | Search-First | 1 (fastest) |
| UI Icons [U1-U5] | Batch | 2 |
| BGM [A1] | Single-Step | 2 |
| SFX [A2-A6] | Batch | 2 |

### Phase 3: Execute

**Round 1 — Search existing assets (parallel)**

```
search_game_resource("cartoon humanoid character")  → C1
search_game_resource("slime enemy")                 → C2
search_game_resource("old man NPC shopkeeper")      → C3
search_game_resource("grassy ground block")         → E1
search_game_resource("stone block")                 → E2
search_game_resource("cartoon pine tree")           → E3
search_game_resource("mushroom prop")               → E4
```

Review results: use found prefabs, mark unfound for generation.

**Round 2 — Batch generation (parallel)**

```
batch_generate_images:
  images:
    - prompt: "红色爱心图标, 卡通风格, 透明背景, 清晰轮廓"
      name: "icon_heart", target_size: "64x64", transparent: true
    - prompt: "金色硬币图标, 卡通风格, 透明背景, 闪亮效果"
      name: "icon_coin", target_size: "64x64", transparent: true
    - prompt: "黄色五角星图标, 卡通风格, 透明背景, 发光效果"
      name: "icon_star", target_size: "64x64", transparent: true
    - prompt: "绿色圆形播放按钮, 卡通风格, 透明背景, 白色三角形"
      name: "btn_play", target_size: "128x128", transparent: true
    - prompt: "灰色齿轮设置图标, 卡通风格, 透明背景"
      name: "icon_settings", target_size: "64x64", transparent: true

batch_sound_effects:
  sounds:
    - name: "sfx_jump", text: "Short bouncy cartoon jump sound, springy and playful"
      duration: 0.5
    - name: "sfx_coin", text: "Cheerful coin pickup ding, bright and rewarding, retro style"
      duration: 0.3
    - name: "sfx_hit", text: "Soft impact thud, cartoon style, not aggressive"
      duration: 0.4
    - name: "sfx_death", text: "Sad descending tone, game over feeling, short"
      duration: 1.0
    - name: "sfx_button", text: "Clean UI button click, soft and satisfying"
      duration: 0.2

text_to_music:
  prompt: "Adventurous orchestral game soundtrack, upbeat and heroic, fantasy platformer, loopable"
  style: "orchestral, adventure, fantasy, upbeat"
  title: "Main Theme"
  instrumental: true
  customMode: true
```

**Round 3 — Chain generation (sequential, for unfound characters)**

For each character not found in search:

```
Step 1: generate_image (front view, A-pose for humanoid)
Step 2: create_3d_model_task (image_to_model, Phase 1)
Step 3: User confirms preview views
Step 4: create_3d_model_task (Phase 2, rig=true for humanoid)
Step 5: Poll query_3d_model_task until complete
```

### Phase 4: Quality Review

Run through all generated assets:
- All files exist at expected paths
- Images have correct dimensions and transparency
- Audio files play correctly and have appropriate length
- 3D models render properly in preview
- Style is consistent across all assets

---

## Example 4: Audio Pack

**Scenario**: Create complete audio for a casual puzzle game.

### Asset List

```
BGM:
  [B1] Menu music — calm, peaceful, piano-based
  [B2] Gameplay music — light, cheerful, medium tempo
  [B3] Victory jingle — triumphant, short celebration

SFX:
  [S1] Tile place — soft click
  [S2] Tile match — satisfying chime cascade
  [S3] Combo — ascending sparkle tones
  [S4] Wrong move — gentle buzz
  [S5] Level complete — fanfare burst
  [S6] Button tap — clean UI click
  [S7] Star earned — magical shimmer
  [S8] Timer warning — soft tick-tock
```

### Execution

**Batch 1: Sound effects (parallel)**

```
batch_sound_effects:
  sounds:
    - name: "sfx_tile_place"
      text: "Soft satisfying click, ceramic tile being placed, gentle"
      duration: 0.3
    - name: "sfx_tile_match"
      text: "Satisfying chime cascade, three ascending notes, magical matching sound"
      duration: 0.8
    - name: "sfx_combo"
      text: "Quick ascending sparkle tones, combo multiplier, exciting and rewarding"
      duration: 1.0
    - name: "sfx_wrong"
      text: "Gentle low buzz, soft wrong answer sound, not harsh"
      duration: 0.5
    - name: "sfx_level_complete"
      text: "Short triumphant fanfare burst, celebration, bright brass"
      duration: 1.5
    - name: "sfx_button"
      text: "Clean minimal UI button click"
      duration: 0.2
    - name: "sfx_star"
      text: "Magical shimmer sound, star earned reward, bright and sparkly"
      duration: 0.8
    - name: "sfx_timer"
      text: "Soft mechanical tick-tock, clock ticking, gentle urgency"
      duration: 1.0
      loop: true
```

**Batch 2: Music (sequential — each takes time)**

```
text_to_music (B1):
  prompt: "Calm peaceful puzzle game menu music, piano and soft strings, relaxing"
  style: "piano, ambient, calm, peaceful"
  title: "Puzzle Menu", instrumental: true, customMode: true

text_to_music (B2):
  prompt: "Light cheerful puzzle gameplay music, playful xylophone and light percussion"
  style: "casual, cheerful, playful, light"
  title: "Puzzle Play", instrumental: true, customMode: true

text_to_music (B3):
  prompt: "Short triumphant victory celebration, fanfare, achievement unlocked feeling"
  style: "triumphant, celebration, fanfare, bright"
  title: "Victory", instrumental: true, customMode: true
```

### File Organization

```
assets/
├── Sounds/
│   ├── sfx_tile_place.ogg
│   ├── sfx_tile_match.ogg
│   ├── sfx_combo.ogg
│   ├── sfx_wrong.ogg
│   ├── sfx_level_complete.ogg
│   ├── sfx_button.ogg
│   ├── sfx_star.ogg
│   └── sfx_timer.ogg
└── Music/
    ├── bgm_menu.ogg
    ├── bgm_gameplay.ogg
    └── bgm_victory.ogg
```
