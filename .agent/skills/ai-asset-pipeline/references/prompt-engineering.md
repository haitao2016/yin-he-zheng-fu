# Prompt Engineering for Game Assets

Systematic prompt construction techniques for consistent, high-quality AI-generated game assets.

---

## The Prompt Anatomy

Every effective asset generation prompt has 4 layers:

```
[SUBJECT] + [STYLE] + [TECHNICAL] + [CONSTRAINTS]
```

| Layer | Purpose | Example |
|-------|---------|---------|
| Subject | What to generate | 铁剑, 绿色史莱姆, 森林背景 |
| Style | Art direction | 卡通风格, 像素风格, 写实风格 |
| Technical | Format specs | 透明背景, 正面视图, 清晰轮廓 |
| Constraints | What to avoid/ensure | 简单设计, 无文字, 高对比度 |

---

## Style Vocabulary Reference

### Art Style Keywords (Chinese prompts for generate_image)

| Style | Keywords | Best For |
|-------|----------|----------|
| Pixel art | 像素风格, 像素画, 8bit, 16bit, 复古像素 | Retro games, icons |
| Cartoon | 卡通风格, 可爱, 圆润, 明亮色彩 | Casual games, mobile |
| Anime | 动漫风格, 日式, 二次元 | RPGs, visual novels |
| Flat design | 扁平化设计, 简约, 几何形状 | UI elements, casual |
| Realistic | 写实风格, 照片级, 精细 | Simulation, strategy |
| Low poly | 低面数3D风格, 几何, 简洁 | 3D casual games |
| Watercolor | 水彩风格, 柔和, 手绘感 | Story games, peaceful |
| Gothic | 暗黑风格, 哥特, 阴暗, 神秘 | Horror, dark fantasy |
| Chibi | Q版, 大头, 萌系, 可爱比例 | Mobile RPGs |

### View/Composition Keywords

| View | Keywords | Use For |
|------|----------|---------|
| Front | 正面视图, 面向镜头 | Icons, character sheets |
| Side | 侧面视图, 侧身 | Platformer sprites |
| Top-down | 俯视图, 从上往下看 | Top-down game tiles |
| Isometric | 等距视角, 2.5D | Isometric game assets |
| Three-quarter | 3/4视角, 斜上方 | Strategy game units |

### Technical Quality Keywords

| Quality | Keywords |
|---------|----------|
| Clean edges | 清晰轮廓, 干净边缘, 无锯齿 |
| High contrast | 高对比度, 色彩鲜明 |
| Simple | 简单设计, 少细节, 易辨认 |
| Detailed | 精细, 丰富细节, 高品质 |
| Consistent lighting | 统一光源, 一致阴影 |

---

## Template Library

### Icons (64×64 to 256×256)

```
Template: "{item}, {art_style}游戏图标, 透明背景, 正面视图, 清晰轮廓, 高对比度"

Parameters:
  target_size: "64x64" / "128x128" / "256x256"
  aspect_ratio: "1:1"
  transparent: true
```

**Examples by genre**:

| Genre | art_style | Sample items |
|-------|-----------|-------------|
| Fantasy RPG | 像素风格 | 铁剑, 魔法杖, 药水, 盾牌, 卷轴 |
| Sci-fi | 扁平化科幻 | 激光枪, 能量电池, 芯片, 太空头盔 |
| Casual | 卡通风格 | 星星, 爱心, 金币, 钻石, 礼物盒 |
| Horror | 暗黑写实 | 十字架, 蜡烛, 骷髅钥匙, 药瓶 |

### Character Sprites (256×512 to 512×1024)

```
Template: "{character_desc}, {art_style}, 透明背景, 全身像, {view}, {pose}"

Parameters:
  target_size: "256x512" / "512x1024"
  aspect_ratio: "2:3" or "3:4"
  transparent: true
```

**Pose vocabulary**:
- 站立姿势 (standing) — default for icons/previews
- A-pose 双臂自然张开 — required for 3D model rigging
- 战斗姿势 (combat stance) — for battle UI
- 奔跑动作 (running) — for sprint animations

### Textures (512×512 to 1024×1024)

```
Template: "{surface_desc}, 无缝贴图, 俯视图, {style}, 均匀分布"

Parameters:
  target_size: "512x512" / "1024x1024"
  aspect_ratio: "1:1"
  transparent: false
```

**Surface types**:

| Surface | Prompt fragment |
|---------|----------------|
| Grass | 绿色草地, 自然纹理, 细密草丛 |
| Stone | 灰色石头地面, 不规则石块, 粗糙纹理 |
| Wood | 木地板, 棕色木纹, 横向纹理 |
| Sand | 金色沙地, 细腻颗粒, 自然纹理 |
| Water | 蓝色水面, 波纹效果, 半透明 |
| Lava | 熔岩地面, 红橙色发光, 裂纹 |

### Backgrounds / Scenes (16:9)

```
Template: "{scene_desc}, 游戏背景, {style}, {mood}, 宽屏"

Parameters:
  target_size: "1920x1080" / "1344x768"
  aspect_ratio: "16:9"
  transparent: false
```

---

## Sound Effect Prompts (English)

Sound descriptions must be in **English** for best results with `text_to_sound_effect`.

### SFX Prompt Formula

```
"[Adjective] [source/action] sound, [quality], [duration hint]"
```

### SFX Reference Table

| Category | Prompt | Duration |
|----------|--------|----------|
| **UI** | | |
| Button click | "Clean minimal UI button click, soft and satisfying" | 0.2s |
| Menu open | "Soft whoosh, menu sliding open, UI transition" | 0.3s |
| Error/wrong | "Gentle low buzz, soft wrong answer sound, not harsh" | 0.4s |
| Success/confirm | "Bright confirmation chime, positive feedback, short" | 0.3s |
| **Combat** | | |
| Sword swing | "Quick sword swing whoosh, sharp metal cutting air" | 0.3s |
| Sword hit | "Metal sword impact on armor, clang with slight ring" | 0.4s |
| Punch | "Meaty punch impact, cartoon style, powerful" | 0.3s |
| Explosion | "Medium explosion with deep bass, fiery blast, cinematic" | 1.5s |
| Shield block | "Heavy metal shield block, resonant clang, defensive" | 0.5s |
| **Movement** | | |
| Footstep stone | "Single footstep on stone floor, hard sole, indoor" | 0.2s |
| Jump | "Short bouncy cartoon jump, springy and playful" | 0.3s |
| Land | "Soft landing thud on ground, dampened impact" | 0.3s |
| Dash | "Quick air dash whoosh, fast movement, energetic" | 0.3s |
| **Pickup/Reward** | | |
| Coin | "Cheerful coin pickup ding, bright and rewarding" | 0.3s |
| Power-up | "Rising magical power-up sound, ascending chimes, empowering" | 0.8s |
| Health restore | "Gentle healing sound, soft warm chimes, restorative" | 0.6s |
| Level up | "Triumphant level up fanfare, ascending notes, celebration" | 1.5s |
| **Ambient (loop)** | | |
| Wind | "Gentle wind blowing through trees, outdoor ambiance" | 5.0s, loop |
| Rain | "Steady rainfall, medium intensity, calming" | 5.0s, loop |
| Fire | "Crackling campfire, warm and cozy, steady" | 5.0s, loop |
| Forest | "Forest ambiance, bird chirps, rustling leaves, peaceful" | 5.0s, loop |

---

## Music Prompts

Music uses `text_to_music` with Chinese or English prompts.

### Music Prompt Formula

```
Simple mode: "[mood] [genre] game music, [instruments], [tempo], [purpose]"

Custom mode:
  style: "[genre], [mood], [instruments]"
  title: "[Track Name]"
  instrumental: true (usually)
```

### Genre Templates

| Game Genre | Style Keywords | Mood |
|-----------|---------------|------|
| Fantasy RPG | orchestral, strings, brass, epic | heroic, adventurous |
| Casual puzzle | piano, xylophone, light percussion | cheerful, playful |
| Horror | ambient, drone, dissonant strings | tense, eerie, unsettling |
| Sci-fi | electronic, synth, pulsing bass | futuristic, atmospheric |
| Platformer | chiptune, 8-bit, energetic drums | upbeat, energetic |
| Racing | electronic, driving beat, intense | high-energy, adrenaline |
| Relaxing | acoustic guitar, piano, nature sounds | calm, peaceful, meditative |

### Track Type Templates

| Track Type | Additional Keywords |
|-----------|-------------------|
| Menu/Title | calm, inviting, loopable, medium tempo |
| Gameplay (action) | driving beat, energetic, loopable, uptempo |
| Gameplay (exploration) | ambient, atmospheric, loopable, moderate |
| Boss battle | intense, dramatic, aggressive, fast tempo |
| Victory | triumphant, celebration, fanfare, bright |
| Game over | melancholy, somber, reflective, slow |
| Cutscene | cinematic, emotional, dynamic, varied |

---

## Consistency Techniques

### Technique 1: Seed Locking

Find a seed that produces good results, then reuse it:

```
generate_image(prompt="...", seed=12345)  → good result
# Use same seed for related assets to get similar "random" choices
```

### Technique 2: Reference Image Chaining

Generate a "style anchor" image first, then use it as reference for all subsequent generations:

```
Step 1: Generate style anchor
  generate_image(prompt="卡通风格游戏角色, 明亮色彩, 可爱")
  → save path as STYLE_REF

Step 2: Generate all other assets WITH reference
  generate_image(
    prompt="卡通风格游戏道具, 铁剑",
    reference_images=[STYLE_REF]
  )
```

### Technique 3: Prompt Prefix/Suffix Locking

Keep identical prefix and suffix, only vary the subject:

```python
PREFIX = "像素风格, 透明背景, 64x64, 清晰轮廓"
SUFFIX = "高对比度, 无文字, 简单设计"

prompts = [
    f"{PREFIX}, 铁剑, {SUFFIX}",
    f"{PREFIX}, 魔法杖, {SUFFIX}",
    f"{PREFIX}, 皮盾, {SUFFIX}",
]
```

### Technique 4: Variation from Base

When you need asset families (enemy tiers, upgrade levels):

```
1. Generate base: "绿色史莱姆" → base.png
2. Edit for tier 2: edit_image(base.png, "改为蓝色, 加冰晶") → tier2.png
3. Edit for tier 3: edit_image(base.png, "改为红色, 加火焰, 更大") → tier3.png
```

This preserves proportions and style better than generating each from scratch.
