# Visual Style Guide

Ready-to-use visual design resources for UrhoX Lua games. Choose a palette, apply PBR material parameters, set up lighting, and follow typography rules for polished output.

## Color Palettes

Every game needs an intentional 6-color palette:

| Role | Purpose |
|------|---------|
| **Primary** | Main interactive elements (player, buttons) |
| **Secondary** | Supporting elements (platforms, UI accents) |
| **Background** | Scene background (usually muted/dark) |
| **Accent** | Highlights, rewards (collectibles, score) |
| **Danger** | Hazards, warnings |
| **Neutral** | Text, borders, subtle elements |

### 1. Vibrant Arcade

Energetic, high-contrast. For action, arcade, casual games.

```lua
local COLORS = {
    primary    = Color(0.18, 0.80, 0.44, 1.0),  -- Emerald green
    secondary  = Color(0.20, 0.60, 0.86, 1.0),  -- Sky blue
    background = Color(0.10, 0.10, 0.15, 1.0),  -- Dark navy
    accent     = Color(0.95, 0.77, 0.06, 1.0),  -- Gold
    danger     = Color(0.91, 0.30, 0.24, 1.0),  -- Red
    neutral    = Color(0.93, 0.94, 0.95, 1.0),  -- Light grey
}
```

### 2. Warm Sunset

Cozy, inviting. For adventure, puzzle, story games.

```lua
local COLORS = {
    primary    = Color(0.90, 0.49, 0.13, 1.0),  -- Orange
    secondary  = Color(0.83, 0.33, 0.33, 1.0),  -- Coral
    background = Color(0.16, 0.12, 0.18, 1.0),  -- Deep purple
    accent     = Color(1.00, 0.84, 0.00, 1.0),  -- Bright yellow
    danger     = Color(0.75, 0.22, 0.17, 1.0),  -- Dark red
    neutral    = Color(0.98, 0.96, 0.93, 1.0),  -- Warm white
}
```

### 3. Cool Ocean

Calm, sleek. For puzzle, strategy, ambient games.

```lua
local COLORS = {
    primary    = Color(0.00, 0.63, 0.73, 1.0),  -- Teal
    secondary  = Color(0.00, 0.47, 0.75, 1.0),  -- Ocean blue
    background = Color(0.05, 0.08, 0.15, 1.0),  -- Deep sea
    accent     = Color(0.00, 0.90, 0.80, 1.0),  -- Aqua
    danger     = Color(0.85, 0.28, 0.36, 1.0),  -- Salmon
    neutral    = Color(0.88, 0.93, 0.96, 1.0),  -- Ice white
}
```

### 4. Forest / Nature

Organic, grounded. For exploration, farming, nature games.

```lua
local COLORS = {
    primary    = Color(0.30, 0.69, 0.31, 1.0),  -- Forest green
    secondary  = Color(0.55, 0.76, 0.29, 1.0),  -- Lime
    background = Color(0.13, 0.17, 0.10, 1.0),  -- Dark forest
    accent     = Color(1.00, 0.76, 0.03, 1.0),  -- Amber
    danger     = Color(0.83, 0.18, 0.18, 1.0),  -- Crimson
    neutral    = Color(0.96, 0.97, 0.93, 1.0),  -- Pale green
}
```

### 5. Neon Cyberpunk

Electric, futuristic. For sci-fi, shooter, racing games.

```lua
local COLORS = {
    primary    = Color(0.00, 0.90, 1.00, 1.0),  -- Cyan
    secondary  = Color(0.75, 0.00, 1.00, 1.0),  -- Purple
    background = Color(0.04, 0.04, 0.08, 1.0),  -- Near black
    accent     = Color(1.00, 0.20, 0.60, 1.0),  -- Hot pink
    danger     = Color(1.00, 0.25, 0.25, 1.0),  -- Bright red
    neutral    = Color(0.70, 0.75, 0.80, 1.0),  -- Steel grey
}
```

### 6. Pastel Dream

Soft, whimsical. For casual, kids, cozy games.

```lua
local COLORS = {
    primary    = Color(0.60, 0.80, 0.98, 1.0),  -- Baby blue
    secondary  = Color(0.98, 0.70, 0.80, 1.0),  -- Blush pink
    background = Color(0.98, 0.97, 0.94, 1.0),  -- Cream
    accent     = Color(0.98, 0.90, 0.55, 1.0),  -- Lemon
    danger     = Color(0.95, 0.55, 0.55, 1.0),  -- Soft red
    neutral    = Color(0.60, 0.55, 0.65, 1.0),  -- Lavender grey
}
```

## Applying Colors to PBR Materials

```lua
--- Create a colored PBR material
---@param color Color
---@param roughness number 0.0-1.0
---@param metallic number 0.0 or 1.0
---@return Material
local function CreateColorMaterial(color, roughness, metallic)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique",
        "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("MatRoughness", Variant(roughness or 0.5))
    mat:SetShaderParameter("MatMetallic", Variant(metallic or 0.0))
    return mat
end

-- For transparent objects:
local function CreateTransparentMaterial(color, roughness)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique",
        "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(color))
    mat:SetShaderParameter("MatRoughness", Variant(roughness or 0.3))
    mat:SetShaderParameter("MatMetallic", Variant(0.0))
    return mat
end
```

## PBR Roughness Reference

| Surface Type | Roughness | Metallic | Example |
|-------------|-----------|----------|---------|
| Mirror / Chrome | 0.0-0.1 | 1.0 | Polished metal props |
| Polished plastic | 0.2-0.3 | 0.0 | Toy-like objects |
| Painted wood | 0.4-0.5 | 0.0 | Furniture, platforms |
| Matte plastic | 0.5-0.6 | 0.0 | UI elements, buttons |
| Rough wood | 0.6-0.7 | 0.0 | Crates, fences |
| Rubber / Matte | 0.7-0.9 | 0.0 | Tires, soft objects |
| Concrete / Rock | 0.8-1.0 | 0.0 | Ground, walls |
| Gold | 0.3-0.4 | 1.0 | Coins, rewards |
| Brushed steel | 0.4-0.5 | 1.0 | Weapons, machinery |

**Rule**: Metallic is binary — 0.0 for non-metals, 1.0 for metals. No in-between.

## Lighting Setup

### Standard 3-Point for 3D Games

```lua
local function SetupLighting(scene)
    -- Key light (main directional, angled from above-right)
    local keyNode = scene:CreateChild("KeyLight")
    keyNode.rotation = Quaternion(45, 30, 0)
    local keyLight = keyNode:CreateComponent("Light")
    keyLight.lightType = LIGHT_DIRECTIONAL
    keyLight.color = Color(1.0, 0.95, 0.9, 1.0)  -- Slightly warm
    keyLight.brightness = 1.0
    keyLight.castShadows = true

    -- Ambient via Zone
    local zone = scene:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000),
                                    Vector3(1000, 1000, 1000))
    zone.ambientColor = Color(0.3, 0.3, 0.35, 1.0)  -- Cool ambient fill
    zone.fogColor = Color(0.1, 0.1, 0.15, 1.0)
end
```

### Warm Indoor Lighting

```lua
local function SetupWarmLighting(scene)
    local keyNode = scene:CreateChild("KeyLight")
    keyNode.rotation = Quaternion(60, 45, 0)
    local keyLight = keyNode:CreateComponent("Light")
    keyLight.lightType = LIGHT_DIRECTIONAL
    keyLight.color = Color(1.0, 0.88, 0.7, 1.0)  -- Warm golden
    keyLight.brightness = 0.8
    keyLight.castShadows = true

    local zone = scene:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000),
                                    Vector3(1000, 1000, 1000))
    zone.ambientColor = Color(0.35, 0.28, 0.22, 1.0)  -- Warm ambient
end
```

## Typography

### Font Selection

- **Game UI**: `Fonts/MiSans-Regular.ttf` (clean, modern, CJK support)
- **Sizes**: Title 32-48, Subtitle 20-28, Body/HUD 16-24, Caption 12-14

### Readability Rules

1. Minimum contrast ratio 4.5:1 for body text
2. Use text shadow or outline over complex backgrounds
3. Monospace/tabular figures for scores and timers
4. Never use font sizes below 12px logical

## Shape Language

| Game Mood | Shapes | Examples |
|-----------|--------|---------|
| Friendly / Casual | Rounded, soft corners | Circles, rounded rects |
| Aggressive / Intense | Angular, sharp | Triangles, jagged edges |
| Technical / Sci-fi | Geometric, clean | Hexagons, straight lines |
| Natural / Organic | Irregular, flowing | Curves, variable widths |
