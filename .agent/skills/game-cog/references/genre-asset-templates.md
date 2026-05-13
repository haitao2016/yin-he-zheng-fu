# Genre Asset Templates

Pre-built asset checklists by game genre. Copy the relevant template and customize for the specific game concept.

## Table of Contents

1. [Platformer (2D Side-Scroller)](#1-platformer)
2. [Shoot'em Up (STG/Shooter)](#2-shootem-up)
3. [RPG / JRPG](#3-rpg--jrpg)
4. [Tower Defense](#4-tower-defense)
5. [Puzzle / Casual](#5-puzzle--casual)
6. [Endless Runner](#6-endless-runner)
7. [Fighting / Beat'em Up](#7-fighting--beatem-up)
8. [Racing](#8-racing)
9. [Asset Naming Convention](#9-asset-naming-convention)

---

## 1. Platformer

**Typical style**: Pixel, Cartoon, Hand-drawn
**Dimension**: 2D

### Characters

| # | Asset | Description | Size | Transparent | Notes |
|---|-------|------------|------|-------------|-------|
| 1 | Player idle | 玩家角色站立正面 | 128x128 | Yes | Hero image candidate |
| 2 | Player run | 玩家角色奔跑姿态 | 128x128 | Yes | Reference hero |
| 3 | Player jump | 玩家角色跳跃姿态 | 128x128 | Yes | Reference hero |
| 4 | Enemy A | 基础敌人(如史莱姆) | 64x64 | Yes | |
| 5 | Enemy B | 飞行敌人 | 64x64 | Yes | |
| 6 | Boss | 关底Boss | 256x256 | Yes | |

### Items & Pickups

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Coin | 金币/收集物 | 32x32 | Yes |
| 2 | Heart | 生命值/血量 | 32x32 | Yes |
| 3 | Power-up A | 无敌星/加速 | 32x32 | Yes |
| 4 | Key | 钥匙/开门道具 | 32x32 | Yes |

### Environment

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Ground tile | 地面瓦片 | 64x64 | No |
| 2 | Platform | 悬浮平台 | 128x32 | Yes |
| 3 | Background | 远景背景(天空/山脉) | 1024x512 | No |
| 4 | Obstacle | 障碍物(尖刺/岩石) | 64x64 | Yes |
| 5 | Decoration | 装饰物(花草/灯) | 32x32 | Yes |

### UI

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Health icon | 生命图标 | 32x32 | Yes |
| 2 | Coin icon | 金币HUD图标 | 32x32 | Yes |
| 3 | Pause button | 暂停按钮 | 64x64 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_jump | Character jump, bouncy spring | 0.3s |
| 2 | sfx_land | Soft landing on ground | 0.2s |
| 3 | sfx_coin | Coin collect, bright chime | 0.3s |
| 4 | sfx_hit | Taking damage, impact | 0.5s |
| 5 | sfx_death | Game over death jingle | 1.0s |
| 6 | sfx_powerup | Power-up collect, ascending sparkle | 0.5s |
| 7 | bgm_main | Upbeat adventure theme, energetic | - |
| 8 | bgm_boss | Intense boss battle theme | - |

---

## 2. Shoot'em Up

**Typical style**: Pixel, Sci-fi, Neon
**Dimension**: 2D (vertical/horizontal scroll)

### Characters

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Player ship | 玩家战机 | 128x128 | Yes |
| 2 | Enemy A | 基础小型敌机 | 64x64 | Yes |
| 3 | Enemy B | 中型敌机 | 64x64 | Yes |
| 4 | Enemy C | 特殊敌机(有护盾) | 96x96 | Yes |
| 5 | Boss | 巨型Boss | 256x256 | Yes |

### Projectiles & Effects

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Bullet player | 玩家子弹 | 16x32 | Yes |
| 2 | Bullet enemy | 敌方子弹 | 16x16 | Yes |
| 3 | Missile | 追踪导弹 | 16x32 | Yes |
| 4 | Explosion | 爆炸效果 | 64x64 | Yes |

### Items

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Shield | 护盾道具 | 32x32 | Yes |
| 2 | Weapon upgrade | 武器升级 | 32x32 | Yes |
| 3 | Health | 回血道具 | 32x32 | Yes |
| 4 | Score bonus | 分数加成 | 32x32 | Yes |

### Environment

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Background layer 1 | 远景星空 | 1024x1024 | No |
| 2 | Background layer 2 | 中景星云/行星 | 1024x1024 | Yes |
| 3 | Asteroid | 小行星障碍 | 64x64 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_shoot | Laser shot, bright sci-fi | 0.2s |
| 2 | sfx_explosion | Explosion, deep rumble | 1.0s |
| 3 | sfx_pickup | Power-up pickup, electronic ding | 0.3s |
| 4 | sfx_shield | Shield activate, energy hum | 0.5s |
| 5 | sfx_boss_appear | Boss warning alarm, dramatic | 2.0s |
| 6 | bgm_stage | Electronic space combat, intense | - |
| 7 | bgm_boss | Epic boss battle, heavy synth | - |

---

## 3. RPG / JRPG

**Typical style**: Anime, Pixel, Cartoon
**Dimension**: 2D or 3D

### Characters

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Hero | 主角立绘(正面) | 256x256 | Yes |
| 2 | Hero portrait | 主角头像(对话框用) | 128x128 | Yes |
| 3 | Party member A | 队友A | 256x256 | Yes |
| 4 | Party member B | 队友B | 256x256 | Yes |
| 5 | NPC merchant | 商人NPC | 256x256 | Yes |
| 6 | Enemy slime | 史莱姆怪物 | 128x128 | Yes |
| 7 | Enemy skeleton | 骷髅战士 | 128x128 | Yes |
| 8 | Boss dragon | 龙Boss | 512x512 | Yes |

### Items & Equipment

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Sword | 铁剑 | 64x64 | Yes |
| 2 | Shield | 木盾 | 64x64 | Yes |
| 3 | Potion HP | 红色治疗药水 | 64x64 | Yes |
| 4 | Potion MP | 蓝色魔力药水 | 64x64 | Yes |
| 5 | Gold coin | 金币货币 | 32x32 | Yes |
| 6 | Gem | 宝石(稀有货币) | 32x32 | Yes |
| 7 | Armor | 铠甲 | 64x64 | Yes |
| 8 | Ring | 魔法戒指 | 64x64 | Yes |
| 9 | Scroll | 魔法卷轴 | 64x64 | Yes |
| 10 | Key item | 关键道具 | 64x64 | Yes |

### Environment

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Village bg | 村庄背景 | 1024x576 | No |
| 2 | Dungeon bg | 地牢背景 | 1024x576 | No |
| 3 | Forest bg | 森林背景 | 1024x576 | No |
| 4 | Battle bg | 战斗场景背景 | 1024x576 | No |

### UI

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | HP icon | 血量图标(红心) | 32x32 | Yes |
| 2 | MP icon | 魔力图标(蓝星) | 32x32 | Yes |
| 3 | EXP icon | 经验值图标 | 32x32 | Yes |
| 4 | Menu bg | 菜单面板背景 | 512x512 | Yes |
| 5 | Dialog frame | 对话框边框 | 512x128 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_attack | Sword slash, metallic swing | 0.5s |
| 2 | sfx_magic | Magic spell cast, mystical sparkle | 1.0s |
| 3 | sfx_heal | Healing chime, warm ascending bells | 1.0s |
| 4 | sfx_levelup | Level up fanfare, triumphant jingle | 2.0s |
| 5 | sfx_menu_select | Menu selection click | 0.1s |
| 6 | sfx_chest_open | Treasure chest opening, wooden creak | 1.0s |
| 7 | bgm_town | Peaceful medieval town, acoustic guitar | - |
| 8 | bgm_battle | Intense turn-based battle, orchestral | - |
| 9 | bgm_dungeon | Dark dungeon exploration, eerie ambient | - |
| 10 | bgm_boss | Epic boss battle, full orchestra | - |

---

## 4. Tower Defense

**Typical style**: Cartoon, Low-poly
**Dimension**: 2D or 2.5D

### Towers

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Arrow tower | 箭塔(基础) | 128x128 | Yes |
| 2 | Magic tower | 法术塔 | 128x128 | Yes |
| 3 | Cannon tower | 炮塔 | 128x128 | Yes |
| 4 | Slow tower | 减速塔(冰) | 128x128 | Yes |
| 5 | Gold mine | 产金建筑 | 128x128 | Yes |

### Enemies

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Grunt | 基础步兵小兵 | 64x64 | Yes |
| 2 | Fast | 快速轻装敌人 | 64x64 | Yes |
| 3 | Tank | 重装甲敌人 | 64x64 | Yes |
| 4 | Flying | 飞行敌人 | 64x64 | Yes |
| 5 | Boss | 关底Boss | 128x128 | Yes |

### Environment & UI

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Path tile | 路径瓦片 | 64x64 | No |
| 2 | Grass tile | 草地(可建造区域) | 64x64 | No |
| 3 | Wave icon | 波次图标 | 32x32 | Yes |
| 4 | Gold icon | 金币图标 | 32x32 | Yes |
| 5 | HP icon | 生命图标 | 32x32 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_build | Tower placement, construction thud | 0.5s |
| 2 | sfx_arrow | Arrow firing, twang whoosh | 0.3s |
| 3 | sfx_magic | Magic blast, arcane burst | 0.5s |
| 4 | sfx_cannon | Cannon fire, deep boom | 0.5s |
| 5 | sfx_enemy_die | Enemy death, poof | 0.3s |
| 6 | sfx_wave_start | New wave horn, dramatic | 1.5s |
| 7 | bgm_battle | Strategic defense, building tension | - |

---

## 5. Puzzle / Casual

**Typical style**: Cartoon, Minimalist, Flat
**Dimension**: 2D

### Game Pieces

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1-6 | Piece variants | 6种不同颜色/形状的游戏块 | 64x64 | Yes |
| 7 | Special piece | 特殊道具块(炸弹/彩虹) | 64x64 | Yes |
| 8 | Blocker | 障碍物/不可移动块 | 64x64 | Yes |

### UI

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Star empty | 空星(评价) | 64x64 | Yes |
| 2 | Star filled | 满星(评价) | 64x64 | Yes |
| 3 | Score icon | 分数图标 | 32x32 | Yes |
| 4 | Timer icon | 计时器图标 | 32x32 | Yes |
| 5 | Hint button | 提示按钮 | 64x64 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_match | Matching pieces, cheerful pop | 0.3s |
| 2 | sfx_combo | Combo chain, escalating chime | 0.5s |
| 3 | sfx_fail | Wrong move, soft buzzer | 0.3s |
| 4 | sfx_clear | Level complete, celebration sparkle | 1.5s |
| 5 | sfx_star | Star earned, bright ding | 0.3s |
| 6 | bgm_puzzle | Light cheerful puzzle theme, calming | - |

---

## 6. Endless Runner

**Typical style**: Cartoon, Pixel, Low-poly
**Dimension**: 2D or 3D

### Characters

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Player run | 玩家奔跑 | 128x128 | Yes |
| 2 | Player jump | 玩家跳跃 | 128x128 | Yes |
| 3 | Player slide | 玩家滑铲 | 128x128 | Yes |

### Obstacles & Pickups

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Low obstacle | 低矮障碍(需跳) | 64x64 | Yes |
| 2 | High obstacle | 高处障碍(需滑) | 64x128 | Yes |
| 3 | Coin | 金币 | 32x32 | Yes |
| 4 | Magnet | 磁铁道具 | 32x32 | Yes |
| 5 | Multiplier | 分数翻倍 | 32x32 | Yes |

### Environment

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Ground | 地面纹理 | 256x64 | No |
| 2 | Background 1 | 远景(天空) | 1024x512 | No |
| 3 | Background 2 | 中景(建筑/树) | 1024x512 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_jump | Quick jump, light whoosh | 0.3s |
| 2 | sfx_slide | Slide, ground scrape | 0.5s |
| 3 | sfx_coin | Coin pickup, bright bling | 0.2s |
| 4 | sfx_crash | Crash into obstacle, impact | 0.5s |
| 5 | bgm_run | Energetic running theme, driving beat | - |

---

## 7. Fighting / Beat'em Up

**Typical style**: Anime, Pixel, Realistic
**Dimension**: 2D

### Characters

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Fighter A idle | 格斗家A站姿 | 256x256 | Yes |
| 2 | Fighter A attack | 格斗家A攻击 | 256x256 | Yes |
| 3 | Fighter B idle | 格斗家B站姿 | 256x256 | Yes |
| 4 | Fighter B attack | 格斗家B攻击 | 256x256 | Yes |

### Effects

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Hit spark | 命中火花 | 64x64 | Yes |
| 2 | Dust cloud | 落地灰尘 | 64x64 | Yes |
| 3 | Energy wave | 气功波/能量弹 | 128x64 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_punch | Heavy punch, meaty impact | 0.3s |
| 2 | sfx_kick | Roundhouse kick, whoosh thud | 0.4s |
| 3 | sfx_block | Shield block, metallic clang | 0.3s |
| 4 | sfx_special | Special move charge, energy buildup | 1.0s |
| 5 | sfx_ko | Knockout, dramatic slam | 1.0s |
| 6 | bgm_fight | Intense fighting music, adrenaline pumping | - |

---

## 8. Racing

**Typical style**: Cartoon, Low-poly, Realistic
**Dimension**: 2D or 3D

### Vehicles

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Car player | 玩家赛车(俯视) | 128x128 | Yes |
| 2 | Car rival A | 对手A | 128x128 | Yes |
| 3 | Car rival B | 对手B | 128x128 | Yes |

### Track & Items

| # | Asset | Description | Size | Transparent |
|---|-------|------------|------|-------------|
| 1 | Road tile | 赛道直线 | 128x128 | No |
| 2 | Road curve | 赛道弯道 | 128x128 | No |
| 3 | Boost pad | 加速板 | 64x64 | Yes |
| 4 | Oil slick | 减速油渍 | 64x64 | Yes |
| 5 | Finish line | 终点线 | 256x64 | Yes |

### Audio

| # | Asset | English Description | Duration |
|---|-------|-------------------|----------|
| 1 | sfx_engine | Car engine rev, continuous | 2.0s |
| 2 | sfx_boost | Speed boost, turbo whoosh | 1.0s |
| 3 | sfx_drift | Tire drift, screeching | 1.0s |
| 4 | sfx_crash | Car collision, crunching metal | 1.0s |
| 5 | sfx_countdown | 3-2-1 countdown beeps | 3.0s |
| 6 | bgm_race | High energy racing music, driving electronic | - |

---

## 9. Asset Naming Convention

Standard naming pattern for generated files:

```
assets/
├── Textures/
│   ├── Characters/
│   │   ├── chr_{name}.png          # Character sprites
│   │   └── chr_{name}_portrait.png # Character portraits
│   ├── Items/
│   │   └── itm_{name}.png         # Item icons
│   ├── UI/
│   │   └── ui_{name}.png          # UI elements
│   ├── Environment/
│   │   ├── env_{name}.png         # Environment pieces
│   │   └── tile_{name}.png        # Tileable textures
│   └── Effects/
│       └── fx_{name}.png          # VFX sprites
├── Sounds/
│   └── sfx_{name}.ogg             # Sound effects
├── Music/
│   └── bgm_{name}.ogg             # Background music
└── Models/
    └── mdl_{name}.mdl             # 3D models
```

### Prefix convention

| Prefix | Category | Example |
|--------|----------|---------|
| `chr_` | Character | `chr_hero.png` |
| `itm_` | Item/pickup | `itm_sword.png` |
| `ui_` | UI element | `ui_hp_icon.png` |
| `env_` | Environment | `env_forest_bg.png` |
| `tile_` | Tileable texture | `tile_grass.png` |
| `fx_` | Effect/particle | `fx_explosion.png` |
| `sfx_` | Sound effect | `sfx_jump.ogg` |
| `bgm_` | Background music | `bgm_battle.ogg` |
| `mdl_` | 3D model | `mdl_tree.mdl` |
