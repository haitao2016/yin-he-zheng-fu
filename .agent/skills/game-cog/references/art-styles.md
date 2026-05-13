# Art Style Presets & Prompt Templates

8 built-in style presets. Each preset provides a ready-to-use **Style Anchor** (prefix + suffix) for consistent asset generation.

## Table of Contents

1. [Pixel / Retro 8-bit](#1-pixel--retro-8-bit)
2. [Cartoon / Flat Design](#2-cartoon--flat-design)
3. [Hand-drawn / Watercolor](#3-hand-drawn--watercolor)
4. [Low-Poly 3D](#4-low-poly-3d)
5. [Anime / Cel-shaded](#5-anime--cel-shaded)
6. [Realistic / PBR](#6-realistic--pbr)
7. [Gothic / Dark Fantasy](#7-gothic--dark-fantasy)
8. [Minimalist / Geometric](#8-minimalist--geometric)
9. [Custom Style Guide](#9-custom-style-guide)

---

## 1. Pixel / Retro 8-bit

**Keywords**: 像素风, 复古, 8-bit, 16-bit, retro, chiptune

**Style Anchor**:
```
prefix: "像素风格游戏素材, 复古8位风格, 清晰像素点阵, 有限调色板"
suffix: "无抗锯齿, 锐利像素边缘, 纯色填充, 无渐变"
palette: 受限调色板(8-16色), 高饱和, 黑色描边
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "像素风格游戏素材, 复古8位风格, {角色描述}, 正面站立, 透明背景, 无抗锯齿, 锐利像素边缘" |
| Item icon | "像素风格游戏图标, 复古8位风格, {物品描述}, 透明背景, 无抗锯齿, 清晰轮廓" |
| Tile | "像素风格游戏瓦片, 复古8位风格, {地形描述}, 可无缝拼接, 无抗锯齿" |
| Background | "像素风格游戏背景, 复古8位风格, {场景描述}, 横向卷轴, 分层视差" |

**SFX style**: "8-bit retro chiptune {action} sound, short and punchy"
**BGM style**: "chiptune, 8-bit, retro game"

**Recommended sizes**: Characters 32x32/64x64, Icons 16x16/32x32, Tiles 32x32/64x64

---

## 2. Cartoon / Flat Design

**Keywords**: 卡通, 扁平化, 可爱, Q版, cute, flat

**Style Anchor**:
```
prefix: "卡通风格游戏素材, 扁平化设计, 粗线条描边, 明亮饱和色彩"
suffix: "简洁造型, 圆润边角, 清晰轮廓, 无复杂纹理"
palette: 高饱和明亮色, 2-3px 黑色描边, 白色高光
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "卡通风格游戏角色, 扁平化设计, {角色描述}, Q版比例, 大眼睛, 透明背景, 粗线条描边" |
| Item icon | "卡通风格游戏图标, 扁平化设计, {物品描述}, 透明背景, 圆润造型, 明亮色彩" |
| UI button | "卡通风格游戏按钮, 扁平化设计, {按钮描述}, 圆角矩形, 渐变高光, 透明背景" |
| Background | "卡通风格游戏背景, 扁平化设计, {场景描述}, 简洁构图, 明亮色调" |

**SFX style**: "Cartoon {action} sound effect, bouncy and playful, family-friendly"
**BGM style**: "cheerful, playful, cartoon, bouncy"

**Recommended sizes**: Characters 128x128/256x256, Icons 64x64/128x128, Tiles 128x128

---

## 3. Hand-drawn / Watercolor

**Keywords**: 手绘, 水彩, 素描, 涂鸦, sketch, watercolor

**Style Anchor**:
```
prefix: "手绘水彩风格游戏素材, 柔和笔触, 自然颜料质感, 纸张纹理"
suffix: "不规则边缘, 淡彩晕染, 铅笔线稿痕迹, 温暖色调"
palette: 柔和水彩色, 不透明度变化, 自然过渡
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "手绘水彩风格游戏角色, {角色描述}, 柔和笔触, 淡彩上色, 透明背景, 铅笔线稿" |
| Item icon | "手绘水彩风格游戏图标, {物品描述}, 透明背景, 自然颜料质感, 柔和边缘" |
| Background | "手绘水彩风格游戏背景, {场景描述}, 淡彩晕染, 纸张纹理, 梦幻氛围" |

**SFX style**: "Soft acoustic {action} sound, gentle, natural, organic feel"
**BGM style**: "acoustic, gentle, folk, soft piano"

**Recommended sizes**: Characters 256x256/512x512, Backgrounds 1024x512

---

## 4. Low-Poly 3D

**Keywords**: 低多边形, low-poly, 几何, 棱角, faceted

**Style Anchor**:
```
prefix: "低多边形3D风格游戏素材, 几何棱角分明, 扁平化着色, 简约造型"
suffix: "三角面可见, 无平滑着色, 鲜明色块, 干净背景"
palette: 每面纯色, 明暗对比通过面法线, 柔和渐变色系
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "低多边形3D风格游戏角色, {角色描述}, 几何棱角, 三角面可见, 透明背景, 正面视角" |
| Prop | "低多边形3D风格游戏道具, {道具描述}, 简约几何造型, 透明背景, 扁平化着色" |
| Environment | "低多边形3D风格游戏场景, {场景描述}, 几何化地形, 简约树木, 色块分明" |

**SFX style**: "Clean digital {action} sound, crisp, modern, minimalist"
**BGM style**: "electronic, ambient, modern, synthwave"

**Recommended sizes**: Characters 256x256, Props 128x128, Scenes 1024x512

**3D model note**: Use `create_3d_model_task` with `face_limit=2000-5000` for actual low-poly models.

---

## 5. Anime / Cel-shaded

**Keywords**: 动漫, 日式, 赛璐璐, anime, cel-shaded, manga

**Style Anchor**:
```
prefix: "日式动漫风格游戏素材, 赛璐璐着色, 精致线条, 大眼睛角色设计"
suffix: "清晰描边, 明暗分界锐利, 高光反射, 动漫比例"
palette: 肤色+高饱和服装色, 锐利阴影边界, 白色高光点
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "日式动漫风格游戏角色, 赛璐璐着色, {角色描述}, 全身立绘, 透明背景, 精致线条" |
| Portrait | "日式动漫风格角色头像, {角色描述}, 半身像, 表情丰富, 透明背景" |
| Item icon | "日式动漫风格游戏图标, {物品描述}, 透明背景, 赛璐璐着色, 清晰描边" |
| Background | "日式动漫风格游戏背景, {场景描述}, 精致线条, 氛围感光影" |

**SFX style**: "Anime-style {action} sound effect, dramatic, exaggerated, Japanese game"
**BGM style**: "JRPG, orchestral, dramatic, Japanese anime"

**Recommended sizes**: Characters 512x512, Portraits 256x256, Backgrounds 1024x576

---

## 6. Realistic / PBR

**Keywords**: 写实, 真实, 逼真, realistic, photorealistic, PBR

**Style Anchor**:
```
prefix: "写实风格游戏素材, 物理渲染, 真实光影, 细腻纹理"
suffix: "高细节, 自然光照, 真实比例, 专业品质"
palette: 自然色调, 物理准确光影, HDR 光照
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "写实风格游戏角色, 物理渲染, {角色描述}, 真实比例, 详细纹理, 透明背景" |
| Prop | "写实风格游戏道具, {道具描述}, 高细节, 金属/木材质感, 透明背景" |
| Environment | "写实风格游戏场景, {场景描述}, 自然光照, 大气透视, 高细节" |
| Texture | "写实无缝纹理, {材质描述}, 可平铺, PBR 材质, 高分辨率" |

**SFX style**: "Realistic {action} sound effect, natural, detailed, cinematic quality"
**BGM style**: "cinematic, orchestral, epic, film score"

**Recommended sizes**: Characters 512x512, Textures 512x512/1024x1024, Scenes 1024x576

---

## 7. Gothic / Dark Fantasy

**Keywords**: 哥特, 暗黑, 黑暗奇幻, gothic, dark fantasy, grim

**Style Anchor**:
```
prefix: "暗黑哥特风格游戏素材, 阴郁色调, 精致暗纹, 神秘氛围"
suffix: "深色背景, 冷色调光源, 锐利细节, 不祥之美"
palette: 深紫/暗红/墨绿为主, 金色/银色点缀, 低明度高对比
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "暗黑哥特风格游戏角色, {角色描述}, 阴郁色调, 精致暗纹, 透明背景, 神秘氛围" |
| Item icon | "暗黑哥特风格游戏图标, {物品描述}, 透明背景, 深色调, 金色细节" |
| Background | "暗黑哥特风格游戏背景, {场景描述}, 阴郁氛围, 月光照射, 荒凉之美" |

**SFX style**: "Dark fantasy {action} sound, ominous, deep, eerie atmosphere"
**BGM style**: "dark ambient, gothic, orchestral, ominous choir"

**Recommended sizes**: Characters 256x256/512x512, Backgrounds 1024x576

---

## 8. Minimalist / Geometric

**Keywords**: 极简, 几何, 抽象, minimalist, geometric, abstract

**Style Anchor**:
```
prefix: "极简主义风格游戏素材, 纯几何形状, 大面积留白, 少量色彩"
suffix: "无纹理, 纯色填充, 数学精确, 极简构图"
palette: 1-3种主色 + 大量白/灰/黑, 高对比, 无渐变
```

**Prompt examples by asset type**:

| Asset | Prompt Template |
|-------|----------------|
| Character | "极简主义风格游戏角色, 纯几何形状, {角色描述}, 简单圆形/方形, 透明背景" |
| Item icon | "极简主义风格游戏图标, {物品描述}, 透明背景, 单色, 几何形状" |
| Background | "极简主义风格游戏背景, {场景描述}, 大面积留白, 少量几何元素" |

**SFX style**: "Minimal {action} sound, clean, single tone, simple, zen-like"
**BGM style**: "minimal, ambient, zen, electronic, sparse"

**Recommended sizes**: Characters 64x64/128x128, Icons 32x32/64x64

---

## 9. Custom Style Guide

When none of the presets fit, build a custom Style Anchor:

### Step 1: Ask the user for visual references

- "有没有参考的游戏或画风？"
- "喜欢什么色调？明亮/暗沉/柔和/鲜艳？"
- "线条风格：粗/细/无描边？"

### Step 2: Construct the Style Anchor

```
prefix: "{用户描述的画风}, {线条特征}, {色彩特征}"
suffix: "{技术约束}, {质量描述}"
palette: "{主色} + {辅色} + {强调色}"
```

### Step 3: Generate and validate a hero image

Generate one test image, show to user, iterate until style is locked.

### Step 4: Apply to all assets

Use the validated hero image as `reference_images` for all subsequent generations.

---

## Style Mixing Tips

- **Pixel + Cartoon**: "像素风格, Q版比例, 大眼睛, 复古色彩" — cute retro
- **Anime + Gothic**: "日式动漫风格, 暗色调, 哥特装饰, 赛璐璐着色" — dark anime
- **Low-poly + Minimalist**: "低多边形, 极简配色, 大面积纯色, 几何棱角" — clean low-poly
- **Hand-drawn + Cartoon**: "手绘线条, 卡通比例, 蜡笔上色, 儿童绘本风" — storybook

When mixing, use one style's structure (prefix) and another's coloring (suffix).
