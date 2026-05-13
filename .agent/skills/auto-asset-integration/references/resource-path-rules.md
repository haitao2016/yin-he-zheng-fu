# 引擎资源路径规则与格式对照表

> 本文档详细说明 UrhoX 引擎的资源路径映射、支持格式和构建配置规则。

---

## 1. 资源路径映射规则

### 核心规则

`scripts/` 和 `assets/` 都是资源根目录。代码中引用资源时**不需要加目录前缀**。

```
代码引用路径                    → 文件存放位置
────────────────────────────────────────────────
"Textures/hero.png"            → assets/Textures/hero.png
"Sounds/jump.ogg"              → assets/Sounds/jump.ogg
"Music/theme.ogg"              → assets/Music/theme.ogg
"Models/enemy.mdl"             → assets/Models/enemy.mdl
"UI/button.png"                → assets/UI/button.png
"Sprites/player.png"           → assets/Sprites/player.png
"Fonts/MiSans-Regular.ttf"     → 内置（无需存放）
"Materials/DefaultGrey.xml"    → 内置（无需存放）
```

### 错误示例

```lua
-- ❌ 错误：不要加 assets/ 前缀
cache:GetResource("Texture2D", "assets/Textures/hero.png")

-- ✅ 正确：直接从子目录开始
cache:GetResource("Texture2D", "Textures/hero.png")

-- ❌ 错误：不要用绝对路径
cache:GetResource("Texture2D", "/workspace/assets/Textures/hero.png")

-- ✅ 正确
cache:GetResource("Texture2D", "Textures/hero.png")
```

---

## 2. 资源类型与文件格式

### cache:GetResource 类型对照表

| 资源类型 | 支持格式 | 典型目录 | DWP 类型 |
|---------|---------|---------|---------|
| `Texture2D` | .png, .jpg, .tga, .dds, .ktx | Textures/, UI/ | 媒体（自动占位） |
| `Image` | .png, .jpg, .tga | Textures/ | 媒体 |
| `Sound` | .ogg, .mp3, .wav | Sounds/, Music/ | 媒体 |
| `Model` | .mdl | Models/ | 媒体 |
| `Animation` | .ani | Animations/ | 媒体 |
| `Font` | .ttf, .otf | Fonts/ | 媒体 |
| `Material` | .xml | Materials/ | 渲染阻塞 |
| `Sprite2D` | .png, .jpg | Sprites/ | 媒体 |
| `SpriteSheet2D` | .xml + 图片 | Sprites/ | 渲染阻塞 |
| `ParticleEffect` | .xml | Particles/ | 渲染阻塞 |
| `XMLFile` | .xml | 各目录 | 渲染阻塞 |
| `JSONFile` | .json | 各目录 | 渲染阻塞 |

### DWP 资源分类

| 分类 | 特征 | 文件类型 |
|------|------|---------|
| **渲染阻塞**（启动时加载） | 必须在使用前就绑定 | .lua .json .xml .material .prefab .effect .fsm .blendspace |
| **DWP 媒体**（按需加载） | 引擎自动占位→热替换 | .png .jpg .tga .dds .ktx .ogg .mp3 .wav .mdl .ani .ttf .otf |

---

## 3. 推荐目录结构

```
assets/
├── Textures/           # 贴图纹理
│   ├── UI/             # UI 相关贴图
│   ├── Env/            # 环境贴图
│   ├── Char/           # 角色贴图
│   └── Effects/        # 特效贴图
├── Sprites/            # 2D 精灵
├── UI/                 # UI 图标和元素
├── Sounds/             # 音效
│   ├── SFX/            # 短音效
│   ├── UI/             # UI 交互音效
│   └── Ambient/        # 环境音
├── Music/              # 背景音乐
│   └── BGM/            # 场景BGM
├── Models/             # 3D 模型
├── Animations/         # 动画文件
├── Materials/          # 材质定义
├── Particles/          # 粒子效果
└── Fonts/              # 自定义字体（内置字体无需放这里）
```

---

## 4. 构建引用配置（resources.json）

### 位置

`.project/resources.json`

### 模式对照

#### 全量引用（默认，简单）

```json
{
  "groups": {
    "default": ["**"]
  }
}
```

- 所有 assets/ 下的文件都被打包
- 无裁剪，确保不会遗漏
- 构建产物可能较大

#### 增强引用（智能裁剪）

```json
{
  "groups": {
    "default": ["scripts/**"]
  }
}
```

- 只打包被代码引用的资源
- 递归追踪依赖关系
- **注意**: 没有被 `cache:GetResource()` 引用的素材会被裁剪

#### 预加载配置

```json
{
  "preload_groups": ["default"],
  "groups": {
    "default": ["**"]
  }
}
```

- `preload_groups` 中的组在启动时下载
- 空数组 `[]` 表示使用 DWP（边玩边下）

### 构建策略选择

| 策略 | preload_groups | groups | 适用场景 |
|------|---------------|--------|---------|
| 全量 + 预加载 | ["default"] | {"default":["**"]} | 小项目、快速原型 |
| 增强 + 预加载 | ["default"] | {"default":["scripts/**"]} | 中型项目 |
| 全量 + DWP | [] | {"default":["**"]} | 大型项目（默认） |
| 增强 + DWP | [] | {"default":["scripts/**"]} | 大型项目（最优） |

---

## 5. NanoVG 资源引用

### 图片

```lua
-- 在初始化时加载（不要在每帧调用）
local img = nvgCreateImage(vg, "UI/background.png", 0)

-- 带 flags 的加载
local tileImg = nvgCreateImage(vg, "Textures/tile.png", NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY)
```

路径规则同 `cache:GetResource()`，直接从子目录开始。

### 字体

```lua
-- 使用内置字体（推荐）
local fontId = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

-- 使用自定义字体
local fontId = nvgCreateFont(vg, "custom", "Fonts/MyFont.ttf")
```

---

## 6. 内置资源列表（不需要生成）

### 内置字体

| 路径 | 说明 |
|------|------|
| `Fonts/MiSans-Regular.ttf` | 默认字体 |
| `Fonts/MiSans-Bold.ttf` | 粗体 |

### 内置 3D 模型

| 路径 | 形状 | 尺寸 |
|------|------|------|
| `Models/Box.mdl` | 立方体 | 1.0 × 1.0 × 1.0 |
| `Models/Sphere.mdl` | 球体 | 直径 1.0 |
| `Models/Cylinder.mdl` | 圆柱 | 直径 1.0, 高 1.0 |
| `Models/Cone.mdl` | 圆锥 | 直径 1.0, 高 1.0 |
| `Models/Plane.mdl` | 平面 | 1.0 × 1.0 |
| `Models/Torus.mdl` | 圆环 | 外径 0.5 |

### 内置 Technique（渲染技术）

```
Techniques/PBR/PBRNoTexture.xml       — 不透明 PBR
Techniques/PBR/PBRNoTextureAlpha.xml  — 透明 PBR
Techniques/NoTextureUnlit.xml         — 无光照
Techniques/Diff.xml                   — 漫反射
Techniques/DiffAlpha.xml              — 漫反射透明
... 等
```

### 内置材质

```
Materials/DefaultGrey.xml    — 默认灰色
... 等
```

### 内置 RenderPath

```
RenderPaths/Forward.xml
RenderPaths/Deferred.xml
... 等
```

---

## 7. 素材生成后的文件移动规则

AI 工具生成的文件通常带有时间戳后缀，需要重命名：

```bash
# generate_image 输出: assets/{name}_{timestamp}.png
# 目标路径: assets/{代码引用路径}

# 示例
# 代码中: cache:GetResource("Texture2D", "Textures/hero.png")
# 生成输出: assets/hero_20250101120000.png
# 需要移动:
mkdir -p assets/Textures
mv assets/hero_*.png assets/Textures/hero.png

# text_to_sound_effect 输出: assets/{output_name}.ogg
# 目标路径: assets/{代码引用路径}

# 示例
# 代码中: cache:GetResource("Sound", "Sounds/SFX/jump.ogg")
# 生成输出: assets/jump.ogg
# 需要移动:
mkdir -p assets/Sounds/SFX
mv assets/jump.ogg assets/Sounds/SFX/jump.ogg
```

### 文件名匹配策略

```bash
# 模式: 用 name 参数匹配生成文件，用 glob 找到带时间戳的文件
# 然后移动到代码引用的目标路径

# 通用脚本模式
target_path="assets/Textures/hero.png"
generated=$(ls -t assets/hero_*.png 2>/dev/null | head -1)
if [ -n "$generated" ]; then
    mkdir -p "$(dirname "$target_path")"
    mv "$generated" "$target_path"
fi
```

---

## 8. 资源引用代码模板

### Texture2D

```lua
local tex = cache:GetResource("Texture2D", "Textures/hero.png")
-- 用于 StaticModel 材质
material:SetTexture(TU_DIFFUSE, tex)
-- 用于 UI Sprite
sprite.texture = tex
```

### Sound（音效）

```lua
local sound = cache:GetResource("Sound", "Sounds/SFX/jump.ogg")
sound.looped = false

local source = node:CreateComponent("SoundSource")
source:Play(sound)
```

### Sound（背景音乐）

```lua
local bgm = cache:GetResource("Sound", "Music/BGM/theme.ogg")
bgm.looped = true

local musicNode = scene_:CreateChild("BGM")
local source = musicNode:CreateComponent("SoundSource")
source.soundType = SOUND_MUSIC
source:Play(bgm)
```

### Model

```lua
local staticModel = node:CreateComponent("StaticModel")
staticModel:SetModel(cache:GetResource("Model", "Models/enemy.mdl"))
staticModel:SetMaterial(cache:GetResource("Material", "Materials/DefaultGrey.xml"))
```

### Sprite2D

```lua
local sprite = node:CreateComponent("StaticSprite2D")
sprite:SetSprite(cache:GetResource("Sprite2D", "Sprites/player.png"))
```

### Font

```lua
local font = cache:GetResource("Font", "Fonts/MiSans-Regular.ttf")
-- 用于 UI Text
text.defaultStyle = font
```

### Animation

```lua
local animCtrl = node:CreateComponent("AnimationController")
animCtrl:PlayNewExclusive(AnimationParameters(
    cache:GetResource("Animation", "Animations/idle.ani")
):Looped())
```
