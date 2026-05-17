---
name: scene-craft-compositor
description: >-
  UrhoX Lua 游戏场景合成与视觉分层引擎。
  灵感源自 storytold/artcraft 的 IDE 式场景合成架构，
  将其 SceneGraph / 3D-Compositing / Kit-Bashing / Identity-Transfer / Node-Pipeline
  五大核心能力映射为可在 UrhoX Lua 游戏内直接运行的纯 Lua 模块。
  提供 7 大模块：LayerCompositor（多层场景合成引擎）、
  DepthParallax（深度感知视差系统）、SpriteComposer（精灵图层合成器）、
  IdentityToken（角色视觉一致性锚定）、KitBash（场景预构建与资产组装）、
  CraftPipeline（节点式视觉处理管线）、ControlMapGen（控制图生成器）。
  适用于：多层视差背景、2D/3D 混合场景合成、场景预构建与快速原型、
  角色视觉一致性管理、深度排序与遮挡、节点式视觉特效管线。
  Use when: users need to
  (1) 创建多层视差滚动背景（横版/纵版/等距视角）,
  (2) 实现深度感知的 2D 场景合成（前景遮挡、大气透视）,
  (3) 使用 Kit Bashing 快速组装场景原型,
  (4) 管理角色视觉一致性（跨场景/跨生成保持角色外观）,
  (5) 构建节点式视觉处理管线（类 ComfyUI 风格的链式图像处理）,
  (6) 生成深度图/法线图/边缘图用于 AI 图像生成的 ControlNet 引导,
  (7) 实现 2D/3D 混合渲染场景,
  (8) 需要精灵图层的深度排序与 Y 轴遮挡,
  (9) 创建电影级场景分镜与镜头序列,
  (10) 批量组装关卡场景的视觉资产,
  (11) 用户说"场景合成""视差背景""图层合成""kit bash""场景拼装",
  (12) 用户说"scene compositing""parallax""depth layer""visual pipeline"。
  与 art-style-transfer 的区别：art-style-transfer 处理单张图像的风格迁移；
  本 skill 处理多图层场景的空间合成与深度管理。
  与 level-design 的区别：level-design 关注玩法流程与关卡结构；
  本 skill 关注视觉图层的合成渲染与深度排序。
  与 ai-asset-pipeline 的区别：ai-asset-pipeline 管理资产生产流水线；
  本 skill 处理资产在场景中的空间组合与视觉合成。
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  source: "https://github.com/storytold/artcraft"
  tags: [scene-compositing, parallax, depth-layering, kit-bashing, identity-transfer, visual-pipeline, 2d-3d-hybrid]
---

# Scene Craft Compositor — UrhoX Lua 场景合成引擎

> 灵感源自 [storytold/artcraft](https://github.com/storytold/artcraft)
> 将 AI 驱动的场景合成工作流映射为 UrhoX Lua 游戏可用的纯 Lua 模块

---

## §1 Use When — 触发条件

### 1.1 必须触发

当用户需求涉及以下场景时，**必须**加载本 skill：

| 场景 | 关键词 |
|------|--------|
| 多层视差滚动背景 | 视差、parallax、多层背景、滚动背景 |
| 深度感知场景合成 | 深度排序、前景遮挡、大气透视、depth compositing |
| Kit Bashing 场景组装 | kit bash、场景拼装、模块化场景、资产组装 |
| 角色视觉一致性 | 角色一致性、identity transfer、角色锚定 |
| 节点式视觉管线 | 视觉管线、节点处理、visual pipeline、processing chain |
| 控制图生成 | 深度图、法线图、边缘图、control map、ControlNet |
| 图层合成 | 图层、layer、合成、compositing |

### 1.2 不触发

| 场景 | 应使用的 Skill |
|------|---------------|
| 单张图像风格迁移 | art-style-transfer |
| 关卡玩法流程设计 | level-design |
| 资产批量生产管线 | ai-asset-pipeline |
| 3D 模型程序化生成 | procedural-generation |
| 运行时后处理滤镜 | runtime-visual-stylizer |

### 1.3 触发关键词

```
scene compositing, 场景合成, parallax, 视差, depth layer, 深度图层,
kit bash, 场景拼装, identity transfer, 角色一致性, visual pipeline,
视觉管线, control map, 控制图, layer compositor, 图层合成器,
sprite composer, 精灵合成, depth sorting, 深度排序, scene blocking,
场景分镜, multi-layer, 多层, compositing engine, 合成引擎
```

---

## §2 概念映射：ArtCraft → UrhoX Lua

| ArtCraft 概念 | UrhoX 模块 | 实现策略 |
|---------------|-----------|---------|
| SceneGraph（场景图） | **LayerCompositor** | 纯 Lua table 维护图层栈，NanoVG 或 Sprite 渲染 |
| to_depth_aware_backdrop() | **DepthParallax** | 数学公式计算视差因子，无需 MiDaS 深度估计 |
| ImageAsset + remove_background | **SpriteComposer** | Sprite2D + Y 轴排序，透明 PNG 由 MCP 生成 |
| identity_token + .latent | **IdentityToken** | JSON 描述符替代潜空间编码，MCP prompt 锚定 |
| AssetKit + SceneBlocker | **KitBash** | 预制件模板 + 网格对齐 + 批量实例化 |
| CraftingPipeline (node graph) | **CraftPipeline** | 链式函数调用 + NanoVG 渲染节点 |
| generate_control_maps() | **ControlMapGen** | 场景深度/法线信息导出为 MCP edit_image 引导 |

### 关键设计决策

**为什么不直接移植 ArtCraft 的神经网络方案？**

ArtCraft 依赖 GPU 计算（MiDaS 深度估计、ControlNet 条件生成、潜空间编码）。
UrhoX Lua 运行时无 GPU 通用计算能力，因此采用以下替代策略：

| ArtCraft 方案 | UrhoX 替代方案 | 原因 |
|--------------|---------------|------|
| MiDaS 深度估计 | 手动深度标注 + 数学公式 | 游戏场景深度由开发者定义，无需 AI 估计 |
| ControlNet 推理 | MCP generate_image / edit_image | 利用云端 AI 生成，非本地推理 |
| .latent 二进制编码 | JSON 文本描述符 | 可读、可编辑、可版本控制 |
| CUDA 并行合成 | NanoVG 顺序渲染 | 2D 图层合成性能足够 |

---

## §3 LayerCompositor — 多层场景合成引擎

> 对应 ArtCraft 的 SceneGraph 核心模块

### 3.1 数据结构

```lua
---@class CompositorLayer
---@field name string 图层名称
---@field depth number 深度值（0.0=最近，1.0=最远）
---@field parallaxFactor number 视差因子（0=不动，1=与相机同速）
---@field opacity number 不透明度 0.0~1.0
---@field visible boolean 是否可见
---@field blendMode string 混合模式: "normal"|"multiply"|"screen"|"overlay"|"additive"
---@field elements table[] 图层内元素列表
---@field offset Vector2 图层额外偏移

---@class CompositorElement
---@field type string "sprite"|"rect"|"text"|"custom"
---@field x number 局部 X 坐标
---@field y number 局部 Y 坐标
---@field width number 宽度
---@field height number 高度
---@field texture string|nil 纹理路径（sprite 类型）
---@field color table|nil {r,g,b,a} 颜色（rect 类型）
---@field render function|nil 自定义渲染函数（custom 类型）
```

### 3.2 核心 API

```lua
-- 创建合成器
local compositor = LayerCompositor.New()

-- 添加图层（按深度自动排序，depth 越大越远）
compositor:AddLayer({
    name = "sky",
    depth = 1.0,
    parallaxFactor = 0.1,
    opacity = 1.0,
    visible = true,
    blendMode = "normal",
    elements = {},
})

compositor:AddLayer({
    name = "mountains",
    depth = 0.8,
    parallaxFactor = 0.3,
    elements = {
        { type = "sprite", x = 0, y = 100, width = 1920, height = 400,
          texture = "Textures/mountains.png" },
    },
})

compositor:AddLayer({
    name = "foreground",
    depth = 0.0,
    parallaxFactor = 1.0,
    elements = {
        { type = "sprite", x = 100, y = 300, width = 64, height = 64,
          texture = "Textures/bush.png" },
    },
})

-- 更新相机位置（驱动视差）
compositor:SetCamera(cameraX, cameraY)

-- 渲染所有图层（在 NanoVGRender 事件中调用）
compositor:Render(vg)

-- 图层操作
compositor:SetLayerVisible("mountains", false)
compositor:SetLayerOpacity("foreground", 0.5)
compositor:RemoveLayer("sky")
compositor:GetLayer("mountains")  --> returns layer table or nil
```

### 3.3 渲染循环

```lua
function LayerCompositor:Render(vg)
    -- 按深度从远到近排序（depth 大的先画）
    table.sort(self.layers, function(a, b) return a.depth > b.depth end)

    for i = 1, #self.layers do
        local layer = self.layers[i]
        if not layer.visible then goto continue end

        -- 计算视差偏移
        local offsetX = -self.cameraX * layer.parallaxFactor + (layer.offset and layer.offset.x or 0)
        local offsetY = -self.cameraY * layer.parallaxFactor + (layer.offset and layer.offset.y or 0)

        nvgSave(vg)
        nvgGlobalAlpha(vg, layer.opacity)

        -- 应用混合模式
        self:ApplyBlendMode(vg, layer.blendMode)

        -- 渲染图层内所有元素
        for j = 1, #layer.elements do
            self:RenderElement(vg, layer.elements[j], offsetX, offsetY)
        end

        nvgRestore(vg)
        ::continue::
    end
end

function LayerCompositor:RenderElement(vg, elem, ox, oy)
    local x = elem.x + ox
    local y = elem.y + oy

    if elem.type == "sprite" and elem.texture then
        local img = self:GetCachedImage(vg, elem.texture)
        if img > 0 then
            local paint = nvgImagePattern(vg, x, y, elem.width, elem.height, 0, img, 1.0)
            nvgBeginPath(vg)
            nvgRect(vg, x, y, elem.width, elem.height)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
        end
    elseif elem.type == "rect" and elem.color then
        nvgBeginPath(vg)
        nvgRect(vg, x, y, elem.width, elem.height)
        nvgFillColor(vg, nvgRGBA(elem.color[1], elem.color[2], elem.color[3], elem.color[4] or 255))
        nvgFill(vg)
    elseif elem.type == "custom" and elem.render then
        elem.render(vg, x, y, elem.width, elem.height)
    end
end
```

### 3.4 混合模式

```lua
function LayerCompositor:ApplyBlendMode(vg, mode)
    if mode == "normal" then
        nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
    elseif mode == "additive" then
        nvgGlobalCompositeBlendFunc(vg, NVG_SRC_ALPHA, NVG_ONE)
    elseif mode == "multiply" then
        nvgGlobalCompositeBlendFunc(vg, NVG_DST_COLOR, NVG_ONE_MINUS_SRC_ALPHA)
    elseif mode == "screen" then
        nvgGlobalCompositeBlendFunc(vg, NVG_ONE, NVG_ONE_MINUS_SRC_COLOR)
    end
end
```

---

## §4 DepthParallax — 深度感知视差系统

> 对应 ArtCraft 的 to_depth_aware_backdrop() 深度合成

### 4.1 视差因子计算

```lua
local DepthParallax = {}

--- 将深度值 [0,1] 转换为视差因子
--- depth: 0.0 = 最近（前景），1.0 = 最远（天空）
--- focalDepth: 焦点深度（默认 0.5，中景）
--- strength: 视差强度乘数（默认 1.0）
function DepthParallax.DepthToFactor(depth, focalDepth, strength)
    focalDepth = focalDepth or 0.5
    strength = strength or 1.0
    -- 焦点处 factor=1.0（与相机同步），远处趋近 0，近处 > 1
    local factor = 1.0 - (depth - focalDepth) * strength
    return math.max(0, math.min(2.0, factor))
end

--- 预设视差配置（横版游戏常用）
DepthParallax.Presets = {
    sidescroller = {
        { name = "sky",        depth = 1.0,  factor = 0.05 },
        { name = "clouds",     depth = 0.9,  factor = 0.1  },
        { name = "mountains",  depth = 0.7,  factor = 0.3  },
        { name = "trees_far",  depth = 0.5,  factor = 0.5  },
        { name = "trees_near", depth = 0.3,  factor = 0.7  },
        { name = "ground",     depth = 0.0,  factor = 1.0  },
    },
    topdown = {
        { name = "floor",      depth = 1.0,  factor = 1.0  },
        { name = "objects",    depth = 0.5,  factor = 1.0  },
        { name = "overlay",    depth = 0.0,  factor = 1.0  },
    },
}
```

### 4.2 大气透视（Atmospheric Perspective）

```lua
--- 根据深度应用大气透视效果
--- 远处物体变浅、变模糊、偏蓝
function DepthParallax.AtmosphericColor(baseColor, depth, config)
    config = config or {}
    local fogColor = config.fogColor or { 180, 200, 220 }
    local fogStart = config.fogStart or 0.3
    local fogEnd = config.fogEnd or 1.0

    if depth < fogStart then
        return baseColor
    end

    local t = math.min(1.0, (depth - fogStart) / (fogEnd - fogStart))
    return {
        math.floor(baseColor[1] + (fogColor[1] - baseColor[1]) * t),
        math.floor(baseColor[2] + (fogColor[2] - baseColor[2]) * t),
        math.floor(baseColor[3] + (fogColor[3] - baseColor[3]) * t),
        baseColor[4] or 255,
    }
end

--- 根据深度缩放元素大小（透视缩放）
function DepthParallax.DepthScale(baseScale, depth, near, far)
    near = near or 0.0
    far = far or 1.0
    local t = (depth - near) / (far - near)
    return baseScale * (1.0 - t * 0.5)  -- 远处缩小到 50%
end
```

---

## §5 SpriteComposer — 精灵图层合成器

> 对应 ArtCraft 的 ImageAsset + 背景移除 + 2D 合成

### 5.1 Y 轴排序（画家算法）

```lua
local SpriteComposer = {}

--- 对精灵列表按 Y 轴排序（底部越大越后画 = 越靠前）
function SpriteComposer.SortByY(sprites)
    table.sort(sprites, function(a, b)
        local ay = a.y + (a.height or 0)
        local by = b.y + (b.height or 0)
        if ay == by then
            return a.x < b.x  -- Y 相同时按 X 排序
        end
        return ay < by
    end)
end

--- 渲染排序后的精灵列表（NanoVG）
function SpriteComposer.RenderSprites(vg, sprites, imageCache)
    SpriteComposer.SortByY(sprites)
    for i = 1, #sprites do
        local s = sprites[i]
        if not s.visible then goto continue end

        local img = imageCache[s.texture]
        if img and img > 0 then
            nvgSave(vg)
            nvgGlobalAlpha(vg, s.opacity or 1.0)
            local paint = nvgImagePattern(vg, s.x, s.y, s.width, s.height, 0, img, 1.0)
            nvgBeginPath(vg)
            nvgRect(vg, s.x, s.y, s.width, s.height)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
            nvgRestore(vg)
        end

        ::continue::
    end
end
```

### 5.2 与 3D 场景混合（Sprite2D 方案）

```lua
--- 在 3D 场景中创建深度排序的精灵
function SpriteComposer.CreateSprite3D(scene, config)
    local node = scene:CreateChild(config.name or "Sprite")
    node.position = Vector3(config.x or 0, config.y or 0, config.z or 0)

    local sprite = node:CreateComponent("StaticSprite2D")
    local spriteRes = cache:GetResource("Sprite2D", config.texture)
    if spriteRes then
        sprite:SetSprite(spriteRes)
        sprite:SetLayer(config.layer or 0)
        sprite:SetOrderInLayer(config.order or 0)
    end

    return node
end
```

---

## §6 IdentityToken — 角色视觉一致性锚定

> 对应 ArtCraft 的 identity_token + 潜空间编码

### 6.1 概念说明

ArtCraft 使用神经网络的潜空间向量（.latent 文件）锚定角色外观。
UrhoX 替代方案：使用 **JSON 文本描述符**，在 MCP 图像生成时作为 prompt 锚定。

### 6.2 Token 数据结构

```lua
---@class IdentityToken
---@field name string 角色名称
---@field version number Token 版本号
---@field visualTraits table 视觉特征
---@field promptAnchors string[] prompt 锚定词列表
---@field colorPalette table 色彩方案
---@field referenceImages string[] 参考图路径

-- 示例 Token
local heroToken = {
    name = "Knight_Hero",
    version = 1,
    visualTraits = {
        bodyType = "muscular male",
        height = "tall",
        hair = "short silver",
        eyes = "blue glowing",
        skin = "fair",
        distinguishing = "scar across left eye",
    },
    promptAnchors = {
        "silver-haired knight",
        "blue glowing eyes",
        "medieval plate armor with gold trim",
        "scar across left eye",
    },
    colorPalette = {
        primary   = "#C0C0C0",  -- 银色盔甲
        secondary = "#FFD700",  -- 金色装饰
        accent    = "#4169E1",  -- 蓝色发光
        skin      = "#FAEBD7",  -- 肤色
    },
    referenceImages = {
        "assets/Textures/Characters/knight_front.png",
        "assets/Textures/Characters/knight_side.png",
    },
}
```

### 6.3 Prompt 生成

```lua
local IdentityToken = {}

--- 从 Token 生成 MCP 图像生成用的 prompt
function IdentityToken.ToPrompt(token, sceneContext)
    local parts = {}

    -- 1. 核心锚定词
    for _, anchor in ipairs(token.promptAnchors) do
        parts[#parts + 1] = anchor
    end

    -- 2. 色彩信息
    if token.colorPalette then
        parts[#parts + 1] = "color palette: " .. token.colorPalette.primary
            .. " and " .. token.colorPalette.secondary
    end

    -- 3. 场景上下文
    if sceneContext then
        parts[#parts + 1] = sceneContext
    end

    return table.concat(parts, ", ")
end

--- 保存 Token 到文件
function IdentityToken.Save(token, filename)
    local cjson = require("cjson")
    local json = cjson.encode(token)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
        return true
    end
    return false
end

--- 从文件加载 Token
function IdentityToken.Load(filename)
    local cjson = require("cjson")
    local file = File(filename, FILE_READ)
    if file then
        local json = file:ReadLine()
        file:Close()
        return cjson.decode(json)
    end
    return nil
end
```

### 6.4 与 MCP 集成

```lua
--- 使用 IdentityToken 生成角色图像（通过 MCP generate_image）
--- 注意：此函数展示如何构建 prompt，实际 MCP 调用由 AI 助手执行
function IdentityToken.BuildImageRequest(token, pose, background)
    local prompt = IdentityToken.ToPrompt(token, background)
    prompt = prompt .. ", " .. (pose or "standing pose")

    return {
        prompt = prompt,
        referenceImages = token.referenceImages,
        -- AI 助手使用此信息调用 MCP generate_image
    }
end
```

---

## §7 KitBash — 场景预构建与资产组装

> 对应 ArtCraft 的 AssetKit + SceneBlocker

### 7.1 概念

Kit Bashing：使用预制模块化资产快速组装场景，如同乐高积木。
游戏开发中常用于关卡原型搭建、场景快速迭代。

### 7.2 资产套件定义

```lua
---@class KitAsset
---@field id string 资产唯一标识
---@field name string 显示名称
---@field texture string 纹理路径
---@field width number 默认宽度
---@field height number 默认高度
---@field anchor table {x, y} 锚点（0-1）
---@field snapPoints table[] 吸附点列表
---@field tags string[] 标签

---@class Kit
---@field name string 套件名称
---@field category string 类别
---@field assets KitAsset[] 资产列表

-- 示例：中世纪城堡套件
local CastleKit = {
    name = "Medieval Castle",
    category = "architecture",
    assets = {
        {
            id = "wall_straight",
            name = "直墙段",
            texture = "Textures/Kit/castle_wall.png",
            width = 128, height = 96,
            anchor = { x = 0.5, y = 1.0 },
            snapPoints = {
                { x = 0, y = 0.5, dir = "left" },
                { x = 1, y = 0.5, dir = "right" },
            },
            tags = { "wall", "structure" },
        },
        {
            id = "tower_round",
            name = "圆塔",
            texture = "Textures/Kit/castle_tower.png",
            width = 64, height = 160,
            anchor = { x = 0.5, y = 1.0 },
            snapPoints = {
                { x = 0.5, y = 0.9, dir = "bottom" },
            },
            tags = { "tower", "structure" },
        },
    },
}
```

### 7.3 场景模板与实例化

```lua
local KitBash = {}

--- 从模板创建场景布局
function KitBash.CreateFromTemplate(template)
    local instances = {}
    for i = 1, #template.placements do
        local p = template.placements[i]
        instances[#instances + 1] = {
            assetId = p.assetId,
            x = p.x,
            y = p.y,
            scaleX = p.scaleX or 1.0,
            scaleY = p.scaleY or 1.0,
            rotation = p.rotation or 0,
            flipX = p.flipX or false,
            layer = p.layer or 0,
        }
    end
    return instances
end

--- 吸附对齐：将新资产对齐到最近的吸附点
function KitBash.SnapTo(instances, newAsset, kit, snapDistance)
    snapDistance = snapDistance or 16
    local bestDist = snapDistance
    local bestPos = { x = newAsset.x, y = newAsset.y }

    for i = 1, #instances do
        local inst = instances[i]
        local kitAsset = KitBash.FindAsset(kit, inst.assetId)
        if not kitAsset then goto continue end

        for _, sp in ipairs(kitAsset.snapPoints or {}) do
            local spX = inst.x + sp.x * kitAsset.width * (inst.scaleX or 1.0)
            local spY = inst.y + sp.y * kitAsset.height * (inst.scaleY or 1.0)
            local dx = newAsset.x - spX
            local dy = newAsset.y - spY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < bestDist then
                bestDist = dist
                bestPos = { x = spX, y = spY }
            end
        end
        ::continue::
    end

    return bestPos
end

--- 在套件中查找资产
function KitBash.FindAsset(kit, assetId)
    for i = 1, #kit.assets do
        if kit.assets[i].id == assetId then
            return kit.assets[i]
        end
    end
    return nil
end
```

### 7.4 3D 场景实例化

```lua
--- 将 KitBash 布局转换为 3D 场景节点
function KitBash.Instantiate3D(scene, instances, kit)
    local root = scene:CreateChild("KitBash_Root")
    for i = 1, #instances do
        local inst = instances[i]
        local asset = KitBash.FindAsset(kit, inst.assetId)
        if not asset then goto continue end

        local node = root:CreateChild(asset.name .. "_" .. i)
        -- 将 2D 布局坐标映射到 3D（X 不变，Y→Z，层级→Y）
        node.position = Vector3(
            inst.x * 0.01,           -- 像素转米
            inst.layer * 0.1,         -- 层级高度
            inst.y * 0.01
        )
        node.scale = Vector3(inst.scaleX or 1, 1, inst.scaleY or 1)

        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
        local tex = cache:GetResource("Texture2D", asset.texture)
        if tex then
            mat:SetTexture(0, tex)  -- TU_DIFFUSE = 0
        end
        model:SetMaterial(mat)

        ::continue::
    end
    return root
end
```

---

## §8 CraftPipeline — 节点式视觉处理管线

> 对应 ArtCraft 的 CraftingPipeline 节点图系统

### 8.1 概念

ArtCraft 使用类 ComfyUI 的节点图进行图像处理。
UrhoX 映射为链式函数调用 + NanoVG 渲染节点。

### 8.2 节点类型

```lua
local CraftPipeline = {}

--- 可用节点类型
CraftPipeline.NodeTypes = {
    -- 源节点
    source      = "加载图像纹理",
    color       = "纯色填充",
    gradient    = "渐变填充",

    -- 变换节点
    tint        = "色彩叠加",
    brightness  = "亮度调整",
    saturate    = "饱和度调整",
    blur        = "模糊（NanoVG feather）",

    -- 合成节点
    overlay     = "叠加混合",
    mask        = "遮罩裁剪",

    -- 特效节点
    vignette    = "暗角效果",
    grain       = "噪点效果",
    glow        = "发光效果",

    -- 输出节点
    output      = "最终输出",
}
```

### 8.3 链式 API

```lua
--- 创建处理管线
function CraftPipeline.New()
    return {
        nodes = {},
        connections = {},
    }
end

--- 添加节点
function CraftPipeline.AddNode(pipeline, nodeType, params)
    local node = {
        id = #pipeline.nodes + 1,
        type = nodeType,
        params = params or {},
    }
    pipeline.nodes[#pipeline.nodes + 1] = node
    return node.id
end

--- 连接节点
function CraftPipeline.Connect(pipeline, fromId, toId)
    pipeline.connections[#pipeline.connections + 1] = {
        from = fromId,
        to = toId,
    }
end

--- 构建链式管线的便捷方法
function CraftPipeline.Chain(...)
    local pipeline = CraftPipeline.New()
    local steps = { ... }
    local prevId = nil

    for i = 1, #steps do
        local step = steps[i]
        local nodeId = CraftPipeline.AddNode(pipeline, step.type, step.params)
        if prevId then
            CraftPipeline.Connect(pipeline, prevId, nodeId)
        end
        prevId = nodeId
    end

    return pipeline
end

-- 使用示例
local pipeline = CraftPipeline.Chain(
    { type = "source",     params = { texture = "Textures/scene_bg.png" } },
    { type = "tint",       params = { color = { 255, 200, 150 }, strength = 0.3 } },
    { type = "vignette",   params = { radius = 0.8, softness = 0.4 } },
    { type = "brightness", params = { factor = 1.1 } },
    { type = "output",     params = {} }
)
```

### 8.4 执行引擎

```lua
--- 执行管线（在 NanoVGRender 事件中调用）
function CraftPipeline.Execute(vg, pipeline, x, y, w, h, imageCache)
    -- 构建执行顺序（拓扑排序简化版：按 id 顺序）
    for i = 1, #pipeline.nodes do
        local node = pipeline.nodes[i]
        CraftPipeline.ExecuteNode(vg, node, x, y, w, h, imageCache)
    end
end

function CraftPipeline.ExecuteNode(vg, node, x, y, w, h, imageCache)
    local t = node.type
    local p = node.params

    if t == "source" then
        local img = imageCache[p.texture]
        if img and img > 0 then
            local paint = nvgImagePattern(vg, x, y, w, h, 0, img, 1.0)
            nvgBeginPath(vg)
            nvgRect(vg, x, y, w, h)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
        end

    elseif t == "color" then
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillColor(vg, nvgRGBA(p.r or 0, p.g or 0, p.b or 0, p.a or 255))
        nvgFill(vg)

    elseif t == "tint" then
        local c = p.color or { 255, 255, 255 }
        local s = p.strength or 0.5
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(255 * s)))
        nvgFill(vg)

    elseif t == "vignette" then
        local cx = x + w * 0.5
        local cy = y + h * 0.5
        local r = math.max(w, h) * (p.radius or 0.8)
        local inner = r * (1.0 - (p.softness or 0.4))
        local paint = nvgRadialGradient(vg, cx, cy, inner, r,
            nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 180))
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillPaint(vg, paint)
        nvgFill(vg)

    elseif t == "brightness" then
        local factor = p.factor or 1.0
        if factor > 1.0 then
            local alpha = math.floor(255 * (factor - 1.0))
            nvgBeginPath(vg)
            nvgRect(vg, x, y, w, h)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.min(255, alpha)))
            nvgFill(vg)
        elseif factor < 1.0 then
            local alpha = math.floor(255 * (1.0 - factor))
            nvgBeginPath(vg)
            nvgRect(vg, x, y, w, h)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, math.min(255, alpha)))
            nvgFill(vg)
        end

    elseif t == "glow" then
        local cx = x + w * 0.5
        local cy = y + h * 0.5
        local gc = p.color or { 255, 200, 100 }
        local gr = p.radius or (math.min(w, h) * 0.3)
        local paint = nvgRadialGradient(vg, cx, cy, 0, gr,
            nvgRGBA(gc[1], gc[2], gc[3], p.intensity or 120),
            nvgRGBA(gc[1], gc[2], gc[3], 0))
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    end
end
```

### 8.5 管线序列化

```lua
--- 保存管线到 JSON
function CraftPipeline.SaveState(pipeline, filename)
    local cjson = require("cjson")
    local json = cjson.encode(pipeline)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
        return true
    end
    return false
end

--- 从 JSON 加载管线
function CraftPipeline.LoadState(filename)
    local cjson = require("cjson")
    local file = File(filename, FILE_READ)
    if file then
        local json = file:ReadLine()
        file:Close()
        return cjson.decode(json)
    end
    return nil
end
```

---

## §9 ControlMapGen — 控制图生成器

> 对应 ArtCraft 的 generate_control_maps() 深度/法线/边缘图生成

### 9.1 概念

ArtCraft 使用 MiDaS 等模型生成深度图用于 ControlNet。
UrhoX 方案：从场景图层信息导出简化的深度/法线/边缘数据，
供 MCP generate_image / edit_image 的 reference 参数使用。

### 9.2 深度图生成（从图层信息）

```lua
local ControlMapGen = {}

--- 从 LayerCompositor 生成简化深度图（灰度 NanoVG 渲染）
--- 白色=近（depth 0），黑色=远（depth 1）
function ControlMapGen.RenderDepthMap(vg, compositor, w, h)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))  -- 远处黑色
    nvgFill(vg)

    -- 按深度从远到近绘制（远处深色，近处浅色）
    local sortedLayers = {}
    for i = 1, #compositor.layers do
        sortedLayers[#sortedLayers + 1] = compositor.layers[i]
    end
    table.sort(sortedLayers, function(a, b) return a.depth > b.depth end)

    for i = 1, #sortedLayers do
        local layer = sortedLayers[i]
        if not layer.visible then goto continue end

        local gray = math.floor((1.0 - layer.depth) * 255)
        for j = 1, #layer.elements do
            local e = layer.elements[j]
            nvgBeginPath(vg)
            nvgRect(vg, e.x, e.y, e.width or 100, e.height or 100)
            nvgFillColor(vg, nvgRGBA(gray, gray, gray, 255))
            nvgFill(vg)
        end
        ::continue::
    end
end

--- 生成边缘图（简化版：在元素边界绘制白色边框）
function ControlMapGen.RenderEdgeMap(vg, compositor, w, h)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)

    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(vg, 2.0)

    for i = 1, #compositor.layers do
        local layer = compositor.layers[i]
        if not layer.visible then goto continue end
        for j = 1, #layer.elements do
            local e = layer.elements[j]
            nvgBeginPath(vg)
            nvgRect(vg, e.x, e.y, e.width or 100, e.height or 100)
            nvgStroke(vg)
        end
        ::continue::
    end
end
```

### 9.3 MCP 工作流集成

```lua
--- 构建 MCP edit_image 请求参数（由 AI 助手调用 MCP 工具）
--- 深度图或边缘图作为 reference_image，引导 AI 生成一致的场景
function ControlMapGen.BuildEditRequest(depthMapPath, prompt)
    return {
        referenceImage = depthMapPath,
        prompt = prompt,
        -- AI 助手使用此信息调用 MCP edit_image
    }
end
```

---

## §10 完整集成示例

```lua
-- scripts/main.lua
-- 横版视差滚动场景 + 精灵深度排序

-- ===== 全局变量 =====
---@type Scene
local scene_ = nil
---@type NanoVGContext
local vg = nil
local screenW, screenH = 0, 0

-- 模块实例
local compositor = nil
local cameraX = 0
local moveSpeed = 200  -- 像素/秒

-- 图像缓存
local imageCache = {}

function Start()
    -- 获取屏幕尺寸
    screenW = graphics:GetWidth()
    screenH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    screenW = screenW / dpr
    screenH = screenH / dpr

    -- 初始化 NanoVG
    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)

    -- 创建字体
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    -- 初始化合成器
    compositor = {
        layers = {},
        cameraX = 0,
        cameraY = 0,
    }

    -- 添加图层（从远到近）
    compositor.layers[1] = {
        name = "sky", depth = 1.0, parallaxFactor = 0.0,
        opacity = 1.0, visible = true, blendMode = "normal",
        elements = {
            { type = "rect", x = 0, y = 0, width = screenW * 3, height = screenH,
              color = { 135, 206, 235, 255 } },
        },
    }

    compositor.layers[2] = {
        name = "mountains", depth = 0.8, parallaxFactor = 0.2,
        opacity = 0.9, visible = true, blendMode = "normal",
        elements = {
            { type = "custom", x = 0, y = screenH * 0.3, width = screenW * 3, height = screenH * 0.7,
              render = function(v, x, y, w, h)
                  -- 绘制简笔山脉
                  nvgBeginPath(v)
                  nvgMoveTo(v, x, y + h)
                  for px = 0, w, 60 do
                      local peakH = math.sin(px * 0.01) * 100 + math.cos(px * 0.007) * 60
                      nvgLineTo(v, x + px, y + 100 - peakH)
                  end
                  nvgLineTo(v, x + w, y + h)
                  nvgClosePath(v)
                  nvgFillColor(v, nvgRGBA(100, 120, 150, 255))
                  nvgFill(v)
              end },
        },
    }

    compositor.layers[3] = {
        name = "trees", depth = 0.4, parallaxFactor = 0.6,
        opacity = 1.0, visible = true, blendMode = "normal",
        elements = {},
    }
    -- 添加树木
    for i = 1, 20 do
        local treeX = (i - 1) * 150 + math.random(-30, 30)
        compositor.layers[3].elements[i] = {
            type = "custom", x = treeX, y = screenH * 0.5,
            width = 40, height = 80,
            render = function(v, x, y, w, h)
                -- 树干
                nvgBeginPath(v)
                nvgRect(v, x + w * 0.35, y + h * 0.5, w * 0.3, h * 0.5)
                nvgFillColor(v, nvgRGBA(101, 67, 33, 255))
                nvgFill(v)
                -- 树冠
                nvgBeginPath(v)
                nvgCircle(v, x + w * 0.5, y + h * 0.35, w * 0.5)
                nvgFillColor(v, nvgRGBA(34, 120, 50, 255))
                nvgFill(v)
            end,
        }
    end

    compositor.layers[4] = {
        name = "ground", depth = 0.0, parallaxFactor = 1.0,
        opacity = 1.0, visible = true, blendMode = "normal",
        elements = {
            { type = "rect", x = 0, y = screenH * 0.85, width = screenW * 3, height = screenH * 0.15,
              color = { 76, 153, 0, 255 } },
        },
    }

    -- 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")

    log:Write(LOG_INFO, "[SceneCraft] Parallax compositor initialized")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 键盘控制相机移动
    if input:GetKeyDown(KEY_RIGHT) or input:GetKeyDown(KEY_D) then
        cameraX = cameraX + moveSpeed * dt
    end
    if input:GetKeyDown(KEY_LEFT) or input:GetKeyDown(KEY_A) then
        cameraX = cameraX - moveSpeed * dt
    end

    compositor.cameraX = cameraX
end

function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, screenW, screenH, graphics:GetDPR())

    -- 按深度从远到近排序
    table.sort(compositor.layers, function(a, b) return a.depth > b.depth end)

    for i = 1, #compositor.layers do
        local layer = compositor.layers[i]
        if not layer.visible then goto continue end

        local offsetX = -compositor.cameraX * layer.parallaxFactor
        local offsetY = 0

        nvgSave(vg)
        nvgGlobalAlpha(vg, layer.opacity)

        for j = 1, #layer.elements do
            local elem = layer.elements[j]
            local ex = elem.x + offsetX
            local ey = elem.y + offsetY

            if elem.type == "rect" and elem.color then
                nvgBeginPath(vg)
                nvgRect(vg, ex, ey, elem.width, elem.height)
                nvgFillColor(vg, nvgRGBA(elem.color[1], elem.color[2], elem.color[3], elem.color[4] or 255))
                nvgFill(vg)
            elseif elem.type == "custom" and elem.render then
                elem.render(vg, ex, ey, elem.width, elem.height)
            end
        end

        nvgRestore(vg)
        ::continue::
    end

    -- HUD 信息
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, 10, 25, string.format("Camera X: %.0f | A/D or Arrow Keys to move", cameraX))

    nvgEndFrame(vg)
end

function Stop()
    if vg then
        -- 释放缓存的图像
        for _, img in pairs(imageCache) do
            if img > 0 then nvgDeleteImage(vg, img) end
        end
        nvgDelete(vg)
    end
    log:Write(LOG_INFO, "[SceneCraft] Compositor stopped")
end
```

---

## §11 持久化 — 场景状态存档

```lua
--- 保存场景合成状态到 JSON 文件
--- 使用 cjson + File API（不使用 io 库，遵循引擎沙箱规则）
function SaveCompositorState(compositor, filename)
    local cjson = require("cjson")

    -- 准备可序列化数据（过滤 function 类型）
    local state = {
        cameraX = compositor.cameraX,
        cameraY = compositor.cameraY,
        layers = {},
    }

    for i = 1, #compositor.layers do
        local layer = compositor.layers[i]
        local layerData = {
            name = layer.name,
            depth = layer.depth,
            parallaxFactor = layer.parallaxFactor,
            opacity = layer.opacity,
            visible = layer.visible,
            blendMode = layer.blendMode,
            elementCount = #layer.elements,
        }
        state.layers[#state.layers + 1] = layerData
    end

    local json = cjson.encode(state)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
        log:Write(LOG_INFO, "[SceneCraft] State saved to " .. filename)
        return true
    end
    log:Write(LOG_WARNING, "[SceneCraft] Failed to save state")
    return false
end

--- 从 JSON 文件加载场景合成状态
function LoadCompositorState(filename)
    local cjson = require("cjson")
    local file = File(filename, FILE_READ)
    if file then
        local json = file:ReadLine()
        file:Close()
        local state = cjson.decode(json)
        log:Write(LOG_INFO, "[SceneCraft] State loaded from " .. filename)
        return state
    end
    log:Write(LOG_WARNING, "[SceneCraft] Failed to load state from " .. filename)
    return nil
end
```

---

## §12 常见问题 FAQ

### Q1: 与引擎原生的 Scene / Node 系统有什么区别？

LayerCompositor 是**纯 Lua 数据驱动**的 2D 图层系统，用 NanoVG 渲染。
引擎的 Scene/Node 是引擎原生的 3D 场景图。两者可以共存：
- 用 LayerCompositor 处理 2D 背景和 UI 图层
- 用引擎 Scene 处理 3D 游戏对象

### Q2: 视差背景性能如何？

NanoVG 渲染 10-20 个图层 + 每层数十个元素，在 60fps 内完全没有问题。
关键优化：只渲染视口内可见的元素（视口裁剪）。

### Q3: 如何使用图片纹理而不是程序化绘制？

将图片放入 `assets/Textures/` 目录，在元素中使用 `type = "sprite"` 并指定纹理路径。
需要在初始化时用 `nvgCreateImage()` 缓存图像句柄。

### Q4: KitBash 可以运行时使用吗？

可以。KitBash 适合：
- 开发时快速搭建场景原型
- 运行时程序化生成关卡布局
- 关卡编辑器的底层数据结构

### Q5: IdentityToken 如何保证跨生成一致性？

通过 prompt 锚定词 + 参考图片 + 色彩约束三重锚定。
配合 MCP 的 reference_images 参数，可以获得较高的视觉一致性。

### Q6: CraftPipeline 的节点图可以导出给 ComfyUI 使用吗？

不能直接导出。CraftPipeline 是简化的 NanoVG 渲染管线，
不是完整的图像处理图。但其序列化 JSON 可以作为参考手动构建 ComfyUI 工作流。

---

## §13 规则与约束

### 13.1 引擎规则遵从

| 规则 | 本 skill 的遵从方式 |
|------|-------------------|
| 代码放 scripts/ 目录 | 所有用户代码输出到 `scripts/` |
| 使用 NanoVGRender 事件 | 所有 NanoVG 渲染在 HandleNanoVGRender 中 |
| nvgCreateFont 只调用一次 | 在 Start() 中创建，不在渲染循环中 |
| 不使用 io 库 | 用 File API 替代 |
| 不写入构建输出目录 | 仅操作 scripts/ 和 assets/ |
| 数组索引从 1 开始 | 所有循环 for i = 1, n |
| 使用枚举而非数字 | 输入事件使用 KEY_* 和 MOUSEB_* |
| 构建后预览 | 每次修改代码后调用构建工具 |

### 13.2 性能预算

| 资源 | 推荐上限 | 说明 |
|------|---------|------|
| 图层数量 | 20 | 每层都要遍历渲染 |
| 每层元素数 | 100 | 视口裁剪可降低实际渲染数 |
| NanoVG 图像缓存 | 50 张 | nvgCreateImage 有内存开销 |
| JSON 存档大小 | 1 MB | cjson 解析有内存峰值 |

### 13.3 视口裁剪优化

```lua
--- 检测元素是否在视口内（简单 AABB 检测）
function IsInViewport(elemX, elemY, elemW, elemH, viewX, viewY, viewW, viewH)
    return elemX + elemW > viewX
       and elemX < viewX + viewW
       and elemY + elemH > viewY
       and elemY < viewY + viewH
end
```

---

## §14 参考文档

- `references/compositing-algorithms.md` — 图层合成算法与混合模式数学公式
- `references/lua-implementations.md` — 7 大模块完整 Lua 实现代码
- `references/game-recipes.md` — 实用游戏场景配方（横版视差、俯视地牢、等距场景等）
