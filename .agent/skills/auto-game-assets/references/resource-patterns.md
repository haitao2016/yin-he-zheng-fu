# UrhoX Resource Reference Detection Patterns

## Grep Patterns by Resource Type

### 1. 2D Textures / Images

```
cache:GetResource("Texture2D", "PATH")
cache:GetResource("Sprite2D", "PATH")
nvgCreateImage(vg, "PATH")
UI image = "PATH.png"
```

Common prefixes: `Textures/`, `UI/`, `Sprites/`
Common suffixes: `.png`, `.jpg`

### 2. Sound Effects

```
cache:GetResource("Sound", "PATH")
```

Common prefixes: `Sounds/`, `SFX/`
Common suffixes: `.ogg`, `.wav`
Distinguish from music by: variable names, path containing `SFX/` or `Sounds/`

### 3. Music / BGM

Same resource type as Sound, distinguished by:
- Variable name contains `music`/`bgm`/`soundtrack`
- Path contains `Music/` or `BGM/`

### 4. 3D Models

```
cache:GetResource("Model", "PATH")
```

Common prefixes: `Models/`
Common suffixes: `.mdl`

### 5. Fonts

```
cache:GetResource("Font", "PATH")
nvgCreateFont(vg, "name", "PATH")
```

Common prefixes: `Fonts/`
Common suffixes: `.ttf`, `.otf`

## Built-in Resources (skip these)

### Built-in Models
Box.mdl, Sphere.mdl, Cylinder.mdl, Cone.mdl, Plane.mdl, Torus.mdl

### Built-in Fonts
Fonts/MiSans-Regular.ttf, Fonts/Anonymous Pro.ttf

### Built-in Techniques/Materials
Techniques/PBR/*, Techniques/NoTexture*, Techniques/Diff*

## Resource Type -> Generation Tool Mapping

| Type | Tool | Notes |
|------|------|-------|
| 2D texture/icon/UI | generate_image / batch_generate_images | Set target_size, transparent |
| Sound effect | text_to_sound_effect / batch_sound_effects | English prompts work best |
| BGM music | text_to_music | Supports style, lyrics |
| 3D model | search_game_resource -> create_3d_model_task | Search library first |
| Font | NOT generatable | Use built-in fonts |
| Material XML | NOT generatable | Create programmatically |
| Particle XML | NOT generatable | Create programmatically |
| Animation | search_game_resource | Search library only |
