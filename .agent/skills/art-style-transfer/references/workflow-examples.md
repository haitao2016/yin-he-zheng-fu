# 风格迁移工作流实操案例

> art-style-transfer Skill 的端到端工作流示例。
> 展示从风格定义到批量迁移的完整流程。

---

## 案例 1：独立游戏 — 水墨武侠

### 项目背景

- **游戏类型**：横版动作 RPG
- **美术方向**：中国水墨风格
- **需要迁移的素材**：场景背景 ×3、角色立绘 ×2、UI 面板、图标 ×6

### Step 1: DEFINE（定义风格）

选择内置风格「中国水墨」并自定义微调：

```
风格名称：武侠水墨
基础风格：中国水墨

六维度定制：
- 色板：黑灰为主，朱砂红点缀，加入少量青绿（区别于纯传统水墨）
- 笔触：写意大笔触，墨渍飞溅效果
- 光影：自然散射，不使用明暗对比
- 线条：写意线条，粗细变化丰富
- 细节：低至中等，远景极简
- 氛围：空灵禅意中带有江湖气
```

### Step 2: ANCHOR（锚定参考）

准备 1-2 张风格参考图作为锚点：

```lua
-- 使用 generate_image 生成风格锚点图
mcp__sce-urhox__generate_image({
    prompt = "中国水墨风格的武侠山水场景，远山淡墨晕染，近景松树浓墨点缀，"
          .. "大面积留白，朱砂红点缀亭台楼阁，写意飞溅墨渍，空灵江湖气",
    name = "style_anchor_ink_wuxia",
    target_size = "1024x1024",
    aspect_ratio = "1:1"
})
```

用户确认参考图满意后，保存路径作为后续迁移的 `reference_images`。

### Step 3: TRANSFER（批量迁移）

#### 3.1 场景背景迁移

```lua
-- 批量迁移 3 张场景背景
mcp__sce-urhox__batch_generate_images({
    images = {
        {
            prompt = "中国水墨武侠风格的竹林小径场景，墨色竹子浓淡有致，"
                  .. "小径蜿蜒消失在薄雾中，大面积留白，写意笔法",
            name = "bg_bamboo_ink",
            target_size = "1920x1080",
            aspect_ratio = "16:9",
            reference_images = { "assets/style_anchor_ink_wuxia.png" }
        },
        {
            prompt = "中国水墨武侠风格的悬崖瀑布场景，瀑布用留白表现，"
                  .. "岩石浓墨皴擦，雾气弥漫，远山淡墨若隐若现",
            name = "bg_cliff_ink",
            target_size = "1920x1080",
            aspect_ratio = "16:9",
            reference_images = { "assets/style_anchor_ink_wuxia.png" }
        },
        {
            prompt = "中国水墨武侠风格的古镇夜景，屋檐轮廓用浓墨勾勒，"
                  .. "灯笼用朱砂红点缀，水面倒影墨色晕染",
            name = "bg_town_ink",
            target_size = "1920x1080",
            aspect_ratio = "16:9",
            reference_images = { "assets/style_anchor_ink_wuxia.png" }
        }
    }
})
```

#### 3.2 角色立绘迁移（对现有素材）

```lua
-- 将已有角色图迁移为水墨风格
mcp__sce-urhox__edit_image({
    image = "assets/Textures/hero_original.png",
    prompt = "将此角色转换为中国水墨风格。使用写意线条勾勒轮廓，"
          .. "墨色浓淡变化丰富。衣袂飘逸，留白大胆。"
          .. "保持角色整体轮廓识别度，面部特征可辨。",
    name = "hero_ink",
    target_size = "512x1024",
    aspect_ratio = "2:3",
    reference_images = { "assets/style_anchor_ink_wuxia.png" },
    transparent = true
})
```

#### 3.3 UI 面板和图标

```lua
-- 迁移 UI 面板
mcp__sce-urhox__edit_image({
    image = "assets/Textures/ui_panel.png",
    prompt = "将此 UI 面板转换为水墨风格。背景大面积留白，"
          .. "墨色边框带有自然墨渍效果。按钮使用朱砂红点缀。"
          .. "保持文字可读性。",
    name = "ui_panel_ink",
    target_size = "512x512",
    aspect_ratio = "1:1",
    reference_images = { "assets/style_anchor_ink_wuxia.png" }
})

-- 批量生成图标
mcp__sce-urhox__batch_generate_images({
    images = {
        {
            prompt = "水墨风格的剑图标，写意笔法勾勒剑身，墨色浓淡有致，透明背景",
            name = "icon_sword_ink",
            target_size = "128x128",
            transparent = true,
            reference_images = { "assets/style_anchor_ink_wuxia.png" }
        },
        {
            prompt = "水墨风格的药瓶图标，简洁写意，朱砂红点缀瓶身，透明背景",
            name = "icon_potion_ink",
            target_size = "128x128",
            transparent = true,
            reference_images = { "assets/style_anchor_ink_wuxia.png" }
        }
    }
})
```

### Step 4: VERIFY（一致性校验）

校验清单：
- [x] 所有素材使用同一风格锚点 `style_anchor_ink_wuxia.png`
- [x] 色板一致：黑灰为主，朱砂红点缀
- [x] 笔触统一：写意线条，墨渍效果
- [x] 各品类技术约束满足（纹理可平铺、图标可识别等）
- [x] 透明背景素材边缘干净

**不一致修复示例**：
```lua
-- 如果某张背景色调偏蓝，用 edit_image 修正
mcp__sce-urhox__edit_image({
    image = "assets/Textures/bg_cliff_ink.png",
    prompt = "调整此水墨画的色调，去除偏蓝色调，"
          .. "统一为纯黑灰墨色，朱砂红点缀风格。",
    name = "bg_cliff_ink_fixed",
    target_size = "1920x1080",
    aspect_ratio = "16:9",
    reference_images = { "assets/style_anchor_ink_wuxia.png" }
})
```

---

## 案例 2：休闲手游 — 卡通赛璐珞风格

### 项目背景

- **游戏类型**：消除类休闲手游
- **美术方向**：明亮卡通赛璐珞
- **需要迁移的素材**：消除方块纹理 ×6、UI 背景、图标 ×8

### Step 1: DEFINE

```
风格名称：糖果卡通
基础风格：卡通赛璐珞

六维度定制：
- 色板：糖果色系（粉、黄、青、紫），高饱和
- 笔触：平滑色块，2级色阶
- 光影：简单2级阶梯高光
- 线条：圆润粗描线，黑色
- 细节：中低，突出形状辨识
- 氛围：欢快甜美
```

### Step 2: ANCHOR

```lua
mcp__sce-urhox__generate_image({
    prompt = "糖果色系的卡通赛璐珞风格，粉黄青紫高饱和色彩，"
          .. "圆润粗黑描线，2级色阶平涂，欢快甜美，"
          .. "展示多个糖果色方块排列",
    name = "style_anchor_candy_cel",
    target_size = "1024x1024",
    aspect_ratio = "1:1"
})
```

### Step 3: TRANSFER

```lua
-- 批量生成 6 种颜色的消除方块
local colors = {
    { name = "red",    desc = "红色草莓" },
    { name = "yellow", desc = "黄色柠檬" },
    { name = "blue",   desc = "蓝色蓝莓" },
    { name = "green",  desc = "绿色苹果" },
    { name = "purple", desc = "紫色葡萄" },
    { name = "orange", desc = "橙色橘子" },
}

local images = {}
for _, c in ipairs(colors) do
    table.insert(images, {
        prompt = "卡通赛璐珞风格的" .. c.desc .. "方块图标，"
              .. "圆润造型，粗黑描线，2级色阶，糖果色系，"
              .. "表情可爱，透明背景",
        name = "block_" .. c.name,
        target_size = "256x256",
        transparent = true,
        reference_images = { "assets/style_anchor_candy_cel.png" }
    })
end

mcp__sce-urhox__batch_generate_images({ images = images })
```

### Step 4: VERIFY

校验清单：
- [x] 6 个方块描线粗细一致
- [x] 色阶级数统一（2 级）
- [x] 所有方块大小比例一致
- [x] 透明背景边缘干净
- [x] 在 64x64 缩小后仍可辨识

---

## 案例 3：风格混合 — 赛博朋克 × 浮世绘

### 项目背景

- **游戏类型**：动作冒险
- **美术方向**：赛博朋克与浮世绘的融合（类似《幽灵线：东京》风格）
- **需要迁移的素材**：场景背景、角色立绘、UI 界面

### Step 1: DEFINE

```
风格名称：霓虹浮世
基础风格：赛博朋克 × 浮世绘 混合

六维度定制（混合规则）：
- 色板：取赛博朋克的霓虹蓝/品红 + 浮世绘的靛蓝/金色
- 笔触：取浮世绘的平涂色块
- 光影：取赛博朋克的霓虹发光效果
- 线条：取浮世绘的精细黑色描线
- 细节：高（两种风格都支持高细节）
- 氛围：未来都市 + 东方美学
```

### Step 2: ANCHOR

```lua
mcp__sce-urhox__generate_image({
    prompt = "赛博朋克与浮世绘混合风格，霓虹蓝品红与靛蓝金色配色，"
          .. "平涂色块填充，霓虹发光边缘效果，精细黑色描线，"
          .. "未来都市中的东方建筑元素，高细节",
    name = "style_anchor_cyber_ukiyo",
    target_size = "1024x1024",
    aspect_ratio = "1:1"
})
```

### Step 3: TRANSFER

```lua
-- 场景背景：霓虹浮世风格的都市
mcp__sce-urhox__generate_image({
    prompt = "赛博朋克浮世绘混合风格的夜间城市街道，"
          .. "传统日式建筑配霓虹灯管，鸟居门框发出品红光芒，"
          .. "浮世绘平涂色块技法，精细描线，靛蓝天空，"
          .. "雨水反光中混合霓虹色彩",
    name = "bg_city_cyber_ukiyo",
    target_size = "1920x1080",
    aspect_ratio = "16:9",
    reference_images = { "assets/style_anchor_cyber_ukiyo.png" }
})

-- 角色：武士 × 赛博格
mcp__sce-urhox__generate_image({
    prompt = "赛博朋克浮世绘混合风格的武士角色，"
          .. "传统武士铠甲融入科技发光线条，面具为能面样式但有LED眼，"
          .. "浮世绘精细描线，平涂色块，霓虹蓝品红点缀，透明背景",
    name = "char_samurai_cyber",
    target_size = "512x1024",
    aspect_ratio = "2:3",
    transparent = true,
    reference_images = { "assets/style_anchor_cyber_ukiyo.png" }
})

-- UI 面板：混合风格
mcp__sce-urhox__edit_image({
    image = "assets/Textures/ui_base_panel.png",
    prompt = "将此 UI 面板转换为赛博朋克浮世绘混合风格。"
          .. "面板边框使用浮世绘的波浪纹描线，但发出霓虹蓝光。"
          .. "背景使用深靛蓝平涂。按钮使用品红霓虹高亮。"
          .. "保持文字可读性。",
    name = "ui_panel_cyber_ukiyo",
    target_size = "512x512",
    aspect_ratio = "1:1",
    reference_images = { "assets/style_anchor_cyber_ukiyo.png" }
})
```

### Step 4: VERIFY

混合风格的额外校验点：
- [x] 两种风格元素比例一致（不能某张图偏赛博、另一张偏浮世绘）
- [x] 描线风格统一（浮世绘精细线 + 霓虹发光边缘）
- [x] 色板在所有素材中保持统一（靛蓝 + 霓虹蓝品红 + 金色）
- [x] 平涂手法一致（不出现半写实渐变）

---

## 案例 4：风格指南生成

### 场景

团队需要一份视觉风格指南（Style Guide），确保后续所有素材风格统一。

### 工作流

```lua
-- 1. 生成风格样板（展示各品类的风格效果）
local style_samples = {
    {
        prompt = "印象派油画风格的地面纹理样板，厚重笔触，暖色调，可平铺",
        name = "styleguide_texture_sample",
        target_size = "512x512"
    },
    {
        prompt = "印象派油画风格的 UI 按钮样板，柔和笔触背景，画框边框",
        name = "styleguide_ui_sample",
        target_size = "512x256",
        aspect_ratio = "16:9"
    },
    {
        prompt = "印象派油画风格的角色半身像样板，粗犷笔触，暖色光影",
        name = "styleguide_character_sample",
        target_size = "512x512"
    },
    {
        prompt = "印象派油画风格的森林场景样板，大面积笔触铺色，柔和光影",
        name = "styleguide_scene_sample",
        target_size = "1024x512",
        aspect_ratio = "16:9"
    },
    {
        prompt = "印象派油画风格的药水图标样板，小笔触密集，色彩饱和，透明背景",
        name = "styleguide_icon_sample",
        target_size = "256x256",
        transparent = true
    }
}

mcp__sce-urhox__batch_generate_images({ images = style_samples })

-- 2. 将样板图整理为文档供团队参考
-- 文件组织：
-- assets/style_guide/
--   ├── anchor.png          (风格锚点图)
--   ├── texture_sample.png  (纹理样板)
--   ├── ui_sample.png       (UI 样板)
--   ├── character_sample.png(角色样板)
--   ├── scene_sample.png    (场景样板)
--   └── icon_sample.png     (图标样板)
```

### 风格指南文档模板

```markdown
# 游戏风格指南 — 印象派油画

## 色板
- 主色调：暖黄 #F5D76E、橙色 #F39C12、蓝色 #2E86C1
- 辅助色：白色 #FDFEFE、深棕 #6E2C00

## 笔触规范
- 厚重可见笔触，方向随物体形态
- 天空：横向长笔触
- 树叶：短小密集笔触
- 水面：水平波动笔触

## 各品类要求
- 纹理：保持可平铺性，笔触方向均匀分布
- UI：背景笔触柔和，文字区域保持清晰度
- 角色：面部笔触精细，衣着笔触粗犷
- 场景：远景模糊大笔触，近景清晰小笔触
- 图标：密集小笔触，轮廓清晰

## 参考锚点图
[见 assets/style_guide/anchor.png]
```

---

## 常见问题与解决方案

### Q1: 迁移后素材色调不一致

**原因**：未使用统一的风格锚点图作为 `reference_images`。

**解决**：
1. 选择一张最满意的已迁移素材作为新锚点
2. 用 `edit_image` 重新迁移不一致的素材，将新锚点加入 `reference_images`

### Q2: 纹理迁移后无法平铺

**原因**：风格迁移改变了边缘像素，导致接缝可见。

**解决**：
1. 在 prompt 中强调"保持纹理可平铺特性，确保边缘无缝衔接"
2. 如仍有接缝，使用 `edit_image` 专门修复边缘区域

### Q3: 角色迁移后面部辨识度降低

**原因**：风格化过度，`preserve_level` 设置过低。

**解决**：
1. 使用 high 保留度修饰语（见 style-prompts.md §6）
2. 在 prompt 中明确"面部特征必须清晰可辨"

### Q4: 风格混合比例不对

**原因**：prompt 中两种风格描述权重不均。

**解决**：
1. 明确指定"主基调采用 A 风格，融入 B 风格的 XX 元素"
2. 主风格描述词量 > 辅助风格

### Q5: 批量生成的素材风格差异大

**原因**：AI 生成的随机性导致每次结果不同。

**解决**：
1. 始终使用同一张锚点图作为 `reference_images`
2. 使用 `seed` 参数固定随机种子（同 prompt + 同 seed = 接近结果）
3. 对偏差较大的素材，用 `edit_image` 微调

---

*文档版本: 1.0.0 | 配合 art-style-transfer SKILL.md v1.0.0 使用*
