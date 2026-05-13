# Site Reference

URL patterns, parsing strategies, and edge cases for each supported site.

## 1. game-icons.net

- **Base URL**: `https://game-icons.net`
- **Tag browse**: `https://game-icons.net/tags/{tag}.html`
- **Tags index**: `https://game-icons.net/tags.html` (all available tags)
- **Icon page**: `https://game-icons.net/1x1/{author}/{icon-name}.html`
- **SVG download**: `/icons/ffffff/000000/1x1/{author}/{name}.svg` (direct file, not inline)
- **Attribution**: `Icon by {author} from game-icons.net, CC BY 3.0`
- **Fuzzy search**: If exact tag fails, search tags index. Built-in synonyms:
  - sword → blade, weapon; potion → flask, bottle, alchemy
  - bow → weapon, archery; armor → shield, helmet; magic → spell, wizard
- **Notes**:
  - All icons are monochrome SVG; change color via `fill` attribute
  - ~4000+ icons across 200+ tags

## 2. OpenGameArt.org

- **Base URL**: `https://opengameart.org`
- **Search**: `https://opengameart.org/art-search-advanced?keys={query}`
- **Asset page**: `https://opengameart.org/content/{slug}`
- **Parsing**: Find download links in "Files" section (`.png`, `.zip`, `.svg`, `.ogg`, `.wav`).
- **License field**: Read "License(s)" on asset page. Values: CC0, CC-BY 3.0, CC-BY-SA 3.0, GPL.
- **Notes**:
  - Downloads may be ZIP archives with varied internal structure
  - License varies per asset — always read from the page

## 3. itch.io

- **Base URL**: `https://itch.io`
- **Tag search**: `https://itch.io/game-assets/free/tag-{tag}`
- **Keyword search**: `https://itch.io/search?q={query}&type=game-assets`
- **Method**: Browser interaction required.
- **License**: Check sidebar on asset page. If absent, assume "All rights reserved".
- **Notes**: "Free" does not mean libre — always check license

## 4. Peritune

- **Base URL**: `https://peritune.com`
- **Full track list**: `https://peritune.com/freematerial_list/` (HTML table, 460+ tracks)
- **Tag browse**: `https://peritune.com/blog/tag/{english-tag}/` (e.g. fight, fantasy, horror)
- **MP3 URL pattern**: `https://peritune.com/music/Peritune_{Name}.mp3`
- **ZIP URL pattern**: `https://peritune.com/music/Peritune_{Name}.zip`
- **Attribution**: `Music by Peritune (https://peritune.com), CC BY 4.0`
- **Parsing strategy**: Fetch `/freematerial_list/`, parse `<tr>` rows. Each row has:
  - Title: `<a href="...">Title</a>`
  - Description: Japanese text in `<td>`
  - Audio: `<source src="...mp3">` inside `<audio>` tag
  - Download: `<a href="...zip">ZIP</a>`
- **Search method**: Filter all tracks by keyword match on title + description (case-insensitive)
- **Available tags**: fight, cool, celtic, chillin, horror, fun, piano, healing, folk-music, doleful, fantasy, magnificent, suspicious, cute, beautiful, ambient, cinematic, powerful, folk, wonder, japanese_style
- **Notes**:
  - Search/tag pages do NOT contain MP3 links (rendered via JS)
  - Must use `/freematerial_list/` for direct download URLs
  - Some tracks have Retro/Drumless variants

## 5. Pixabay Sound Effects

- **Base URL**: `https://pixabay.com/sound-effects/`
- **Search**: `https://pixabay.com/sound-effects/search/{query}/`
- **License**: Pixabay Content License — free commercial, no attribution required.
- **Method**: Browser interaction (download requires CAPTCHA/login).

## 6. Spriters Resource

- **Base URL**: `https://www.spriters-resource.com`
- **Search**: `https://www.spriters-resource.com/search/?q={query}`
- **Method**: Browser interaction.
- **License**: Fan-made. **NOT for commercial use.**
