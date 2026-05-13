---
name: game-assets-finder
description: |
  Search and download free game assets (SVG icons, sprites, tilesets, music, sound effects) from 6 popular websites.
  Use when users need to: (1) find game icons/sprites/tilesets, (2) download free BGM or sound effects,
  (3) batch-download assets from game-icons.net, OpenGameArt, itch.io, Peritune, Pixabay, Spriters Resource,
  (4) track asset licenses, (5) build an asset library from free online sources.
  Trigger keywords: game assets, sprites, game icons, game music, sound effects, download assets,
  素材, 图标, 精灵图, 游戏音乐, 音效, 下载素材, BGM, tileset, pixel art.
---

# Game Assets Finder

Search and download free game assets from 6 websites. Handles direct HTTP downloads, page parsing, and browser-interactive sites. Tracks licenses automatically.

## Supported Sites

| Site | Type | License | Method |
|------|------|---------|--------|
| game-icons.net | SVG icons | CC BY 3.0 | Direct / data-URI parse |
| OpenGameArt.org | Open-source art | CC0 / CC-BY | Page parse + links |
| itch.io | Mixed game assets | Mixed | Browser interaction |
| Peritune | Game music (BGM) | CC BY 4.0 | Direct download |
| Pixabay SFX | Sound effects | Free commercial | Direct download |
| Spriters Resource | Fan-game sprites | Fan copyright | Browser interaction |

## Workflow

```
User query → detect asset type → select site(s) → search → download → log license
```

### 1. Auto-Detect Asset Type & Select Site

| Query keywords | Type | Primary site |
|---------------|------|-------------|
| icon, UI, button, weapon icon | Icon | game-icons.net |
| sprite, tileset, pixel art, 2D | Sprite | OpenGameArt / itch.io |
| music, BGM, background music | Music | Peritune |
| sound effect, SFX, UI sound | SFX | Pixabay SFX |
| retro, fan-game, NES/SNES style | Fan sprite | Spriters Resource |

### 2. Download

Run `scripts/download_asset.py`:

```bash
# Direct-download sites
python3 scripts/download_asset.py --site game-icons --query "sword" --output ./assets/icons/
python3 scripts/download_asset.py --site opengameart --query "platformer tileset" --output ./assets/sprites/
python3 scripts/download_asset.py --site peritune --query "battle" --output ./assets/music/

# Browser-interactive sites (prints instructions for user)
python3 scripts/download_asset.py --site itch --query "pixel art" --output ./assets/sprites/
python3 scripts/download_asset.py --site spriters --query "megaman" --output ./assets/sprites/

# Batch mode (comma-separated)
python3 scripts/download_asset.py --site game-icons --query "sword,shield,potion" --output ./assets/icons/ --batch
```

For itch.io and Spriters Resource, the script outputs URLs and step-by-step manual download instructions since these sites require JavaScript interaction.

### 3. License Tracking

Every download is logged to `LICENSE_TRACKER.md`:

```
| File | Source | License | Attribution | Date |
| sword.svg | game-icons.net | CC BY 3.0 | Lorc | 2025-01-15 |
```

License rules:
- **CC0**: Free, no attribution needed
- **CC BY 3.0/4.0**: Free, attribution required
- **Free commercial** (Pixabay): Free, no attribution needed
- **Fan copyright** (Spriters Resource): **NOT for commercial use** — always warn user

## Peritune Music Tags

Peritune uses Japanese tags. Common mappings:

| Keyword (CN/EN) | Peritune tag |
|-----------------|-------------|
| battle, combat, 战斗 | 戦闘 |
| Japanese, traditional, 和风 | 和風 |
| cool, epic, 史诗 | かっこいい |
| relaxing, chill, 放松 | ほのぼの |
| Celtic, Irish | ケルト |
| fantasy, 奇幻 | ファンタジー |
| horror, scary, 恐怖 | ホラー |
| electronic, EDM, 电子 | エレクトロニック |

Full tag mapping and site-specific parsing details: see [references/sites.md](references/sites.md).
