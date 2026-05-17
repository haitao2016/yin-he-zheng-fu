# 7 大模块完整 Lua 实现参考

> 每个模块的完整可用 Lua 代码，可直接放入 scripts/ 使用

---

## 1. LayerCompositor 完整实现

```lua
-- scripts/scene_craft/LayerCompositor.lua
local LayerCompositor = {}
LayerCompositor.__index = LayerCompositor

function LayerCompositor.New()
    local self = setmetatable({}, LayerCompositor)
    self.layers = {}
    self.cameraX = 0
    self.cameraY = 0
    self.imageCache = {}
    return self
end

function LayerCompositor:AddLayer(config)
    local layer = {
        name = config.name or ("Layer_" .. (#self.layers + 1)),
        depth = config.depth or 0,
        parallaxFactor = config.parallaxFactor or 1.0,
        opacity = config.opacity or 1.0,
        visible = config.visible ~= false,
        blendMode = config.blendMode or "normal",
        elements = config.elements or {},
        offset = config.offset or { x = 0, y = 0 },
    }
    self.layers[#self.layers + 1] = layer
    return layer
end

function LayerCompositor:GetLayer(name)
    for i = 1, #self.layers do
        if self.layers[i].name == name then
            return self.layers[i], i
        end
    end
    return nil
end

function LayerCompositor:RemoveLayer(name)
    for i = #self.layers, 1, -1 do
        if self.layers[i].name == name then
            table.remove(self.layers, i)
            return true
        end
    end
    return false
end

function LayerCompositor:SetLayerVisible(name, visible)
    local layer = self:GetLayer(name)
    if layer then layer.visible = visible end
end

function LayerCompositor:SetLayerOpacity(name, opacity)
    local layer = self:GetLayer(name)
    if layer then layer.opacity = math.max(0, math.min(1, opacity)) end
end

function LayerCompositor:SetCamera(x, y)
    self.cameraX = x or self.cameraX
    self.cameraY = y or self.cameraY
end

function LayerCompositor:GetCachedImage(vg, path)
    if self.imageCache[path] then
        return self.imageCache[path]
    end
    local img = nvgCreateImage(vg, path, 0)
    if img > 0 then
        self.imageCache[path] = img
    end
    return img
end

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

function LayerCompositor:RenderElement(vg, elem, ox, oy)
    local x = elem.x + ox
    local y = elem.y + oy

    if elem.type == "sprite" and elem.texture then
        local img = self:GetCachedImage(vg, elem.texture)
        if img and img > 0 then
            local paint = nvgImagePattern(vg, x, y, elem.width, elem.height, 0, img, 1.0)
            nvgBeginPath(vg)
            nvgRect(vg, x, y, elem.width, elem.height)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
        end
    elseif elem.type == "rect" and elem.color then
        nvgBeginPath(vg)
        nvgRect(vg, x, y, elem.width, elem.height)
        local c = elem.color
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], c[4] or 255))
        nvgFill(vg)
    elseif elem.type == "custom" and elem.render then
        elem.render(vg, x, y, elem.width, elem.height)
    end
end

function LayerCompositor:Render(vg, viewW, viewH)
    table.sort(self.layers, function(a, b) return a.depth > b.depth end)

    for i = 1, #self.layers do
        local layer = self.layers[i]
        if not layer.visible then goto continue end

        local ox = -self.cameraX * layer.parallaxFactor + (layer.offset.x or 0)
        local oy = -self.cameraY * layer.parallaxFactor + (layer.offset.y or 0)

        nvgSave(vg)
        nvgGlobalAlpha(vg, layer.opacity)
        self:ApplyBlendMode(vg, layer.blendMode)

        for j = 1, #layer.elements do
            local elem = layer.elements[j]
            -- 简单视口裁剪
            if viewW and viewH then
                local ex = elem.x + ox
                if ex + (elem.width or 0) < 0 or ex > viewW then
                    goto skip
                end
            end
            self:RenderElement(vg, elem, ox, oy)
            ::skip::
        end

        nvgRestore(vg)
        ::continue::
    end
end

function LayerCompositor:Cleanup(vg)
    for _, img in pairs(self.imageCache) do
        if img > 0 then nvgDeleteImage(vg, img) end
    end
    self.imageCache = {}
end

return LayerCompositor
```

---

## 2. DepthParallax 完整实现

```lua
-- scripts/scene_craft/DepthParallax.lua
local DepthParallax = {}

function DepthParallax.DepthToFactor(depth, focalDepth, strength)
    focalDepth = focalDepth or 0.5
    strength = strength or 1.0
    local factor = 1.0 - (depth - focalDepth) * strength
    return math.max(0, math.min(2.0, factor))
end

function DepthParallax.AtmosphericColor(baseColor, depth, config)
    config = config or {}
    local fogColor = config.fogColor or { 180, 200, 220 }
    local fogStart = config.fogStart or 0.3
    local fogEnd = config.fogEnd or 1.0

    if depth < fogStart then return baseColor end

    local t = math.min(1.0, (depth - fogStart) / (fogEnd - fogStart))
    return {
        math.floor(baseColor[1] + (fogColor[1] - baseColor[1]) * t),
        math.floor(baseColor[2] + (fogColor[2] - baseColor[2]) * t),
        math.floor(baseColor[3] + (fogColor[3] - baseColor[3]) * t),
        baseColor[4] or 255,
    }
end

function DepthParallax.DepthScale(baseScale, depth, near, far)
    near = near or 0.0
    far = far or 1.0
    local t = math.max(0, math.min(1, (depth - near) / (far - near)))
    return baseScale * (1.0 - t * 0.5)
end

function DepthParallax.AutoAssignFactors(layers, config)
    config = config or {}
    local minFactor = config.minFactor or 0.05
    local maxFactor = config.maxFactor or 1.0

    for i = 1, #layers do
        local depth = layers[i].depth or 0
        layers[i].parallaxFactor = minFactor + (1.0 - depth) * (maxFactor - minFactor)
    end
end

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
        { name = "shadows",    depth = 0.8,  factor = 1.0  },
        { name = "objects",    depth = 0.5,  factor = 1.0  },
        { name = "overlay",    depth = 0.0,  factor = 1.0  },
    },
    isometric = {
        { name = "ground",     depth = 1.0,  factor = 0.95 },
        { name = "walls",      depth = 0.5,  factor = 1.0  },
        { name = "roofs",      depth = 0.2,  factor = 1.05 },
        { name = "effects",    depth = 0.0,  factor = 1.1  },
    },
}

return DepthParallax
```

---

## 3. SpriteComposer 完整实现

```lua
-- scripts/scene_craft/SpriteComposer.lua
local SpriteComposer = {}

function SpriteComposer.SortByY(sprites)
    table.sort(sprites, function(a, b)
        local ay = a.y + (a.height or 0)
        local by = b.y + (b.height or 0)
        if ay == by then return a.x < b.x end
        return ay < by
    end)
end

function SpriteComposer.RenderSprites(vg, sprites, imageCache)
    SpriteComposer.SortByY(sprites)
    for i = 1, #sprites do
        local s = sprites[i]
        if s.visible == false then goto continue end

        nvgSave(vg)
        nvgGlobalAlpha(vg, s.opacity or 1.0)

        if s.texture and imageCache[s.texture] then
            local img = imageCache[s.texture]
            if img > 0 then
                local paint = nvgImagePattern(vg, s.x, s.y, s.width, s.height, 0, img, 1.0)
                nvgBeginPath(vg)
                nvgRect(vg, s.x, s.y, s.width, s.height)
                nvgFillPaint(vg, paint)
                nvgFill(vg)
            end
        elseif s.color then
            nvgBeginPath(vg)
            nvgRect(vg, s.x, s.y, s.width, s.height)
            nvgFillColor(vg, nvgRGBA(s.color[1], s.color[2], s.color[3], s.color[4] or 255))
            nvgFill(vg)
        end

        nvgRestore(vg)
        ::continue::
    end
end

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

function SpriteComposer.AddSprite(list, config)
    list[#list + 1] = {
        x = config.x or 0,
        y = config.y or 0,
        width = config.width or 64,
        height = config.height or 64,
        texture = config.texture,
        color = config.color,
        opacity = config.opacity or 1.0,
        visible = config.visible ~= false,
        tag = config.tag,
    }
    return #list
end

return SpriteComposer
```

---

## 4. IdentityToken 完整实现

```lua
-- scripts/scene_craft/IdentityToken.lua
local IdentityToken = {}

function IdentityToken.New(config)
    return {
        name = config.name or "Unknown",
        version = config.version or 1,
        visualTraits = config.visualTraits or {},
        promptAnchors = config.promptAnchors or {},
        colorPalette = config.colorPalette or {},
        referenceImages = config.referenceImages or {},
        metadata = config.metadata or {},
    }
end

function IdentityToken.ToPrompt(token, sceneContext)
    local parts = {}
    for i = 1, #token.promptAnchors do
        parts[#parts + 1] = token.promptAnchors[i]
    end
    if token.colorPalette and token.colorPalette.primary then
        parts[#parts + 1] = "color palette: " .. token.colorPalette.primary
        if token.colorPalette.secondary then
            parts[#parts + 1] = token.colorPalette.secondary
        end
    end
    if sceneContext then
        parts[#parts + 1] = sceneContext
    end
    return table.concat(parts, ", ")
end

function IdentityToken.Validate(token)
    local errors = {}
    if not token.name or token.name == "" then
        errors[#errors + 1] = "name is required"
    end
    if not token.promptAnchors or #token.promptAnchors == 0 then
        errors[#errors + 1] = "at least one prompt anchor is required"
    end
    return #errors == 0, errors
end

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

function IdentityToken.BuildImageRequest(token, pose, background)
    local prompt = IdentityToken.ToPrompt(token, background)
    if pose then prompt = prompt .. ", " .. pose end
    return {
        prompt = prompt,
        referenceImages = token.referenceImages,
    }
end

return IdentityToken
```

---

## 5. KitBash 完整实现

```lua
-- scripts/scene_craft/KitBash.lua
local KitBash = {}

function KitBash.NewKit(config)
    return {
        name = config.name or "Unnamed Kit",
        category = config.category or "general",
        assets = config.assets or {},
    }
end

function KitBash.FindAsset(kit, assetId)
    for i = 1, #kit.assets do
        if kit.assets[i].id == assetId then
            return kit.assets[i]
        end
    end
    return nil
end

function KitBash.CreateFromTemplate(template)
    local instances = {}
    for i = 1, #template.placements do
        local p = template.placements[i]
        instances[#instances + 1] = {
            assetId = p.assetId,
            x = p.x or 0,
            y = p.y or 0,
            scaleX = p.scaleX or 1.0,
            scaleY = p.scaleY or 1.0,
            rotation = p.rotation or 0,
            flipX = p.flipX or false,
            layer = p.layer or 0,
        }
    end
    return instances
end

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

function KitBash.RenderInstances(vg, instances, kit, imageCache)
    table.sort(instances, function(a, b)
        if a.layer ~= b.layer then return a.layer < b.layer end
        return a.y < b.y
    end)

    for i = 1, #instances do
        local inst = instances[i]
        local asset = KitBash.FindAsset(kit, inst.assetId)
        if not asset then goto continue end

        nvgSave(vg)
        nvgTranslate(vg, inst.x, inst.y)
        if inst.rotation ~= 0 then
            nvgRotate(vg, math.rad(inst.rotation))
        end
        if inst.flipX then nvgScale(vg, -1, 1) end
        nvgScale(vg, inst.scaleX or 1, inst.scaleY or 1)

        local w = asset.width
        local h = asset.height
        local ax = -(asset.anchor and asset.anchor.x or 0.5) * w
        local ay = -(asset.anchor and asset.anchor.y or 0.5) * h

        if asset.texture and imageCache[asset.texture] then
            local img = imageCache[asset.texture]
            if img > 0 then
                local paint = nvgImagePattern(vg, ax, ay, w, h, 0, img, 1.0)
                nvgBeginPath(vg)
                nvgRect(vg, ax, ay, w, h)
                nvgFillPaint(vg, paint)
                nvgFill(vg)
            end
        else
            nvgBeginPath(vg)
            nvgRect(vg, ax, ay, w, h)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 100, 100, 255))
            nvgStroke(vg)
        end

        nvgRestore(vg)
        ::continue::
    end
end

function KitBash.Instantiate3D(scene, instances, kit)
    local root = scene:CreateChild("KitBash_Root")
    for i = 1, #instances do
        local inst = instances[i]
        local asset = KitBash.FindAsset(kit, inst.assetId)
        if not asset then goto continue end

        local node = root:CreateChild(asset.name .. "_" .. i)
        node.position = Vector3(inst.x * 0.01, inst.layer * 0.1, inst.y * 0.01)
        node.scale = Vector3(inst.scaleX or 1, 1, inst.scaleY or 1)

        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlitAlpha.xml"))
        local tex = cache:GetResource("Texture2D", asset.texture)
        if tex then mat:SetTexture(0, tex) end
        model:SetMaterial(mat)

        ::continue::
    end
    return root
end

function KitBash.SaveLayout(instances, filename)
    local cjson = require("cjson")
    local json = cjson.encode({ placements = instances })
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
        return true
    end
    return false
end

function KitBash.LoadLayout(filename)
    local cjson = require("cjson")
    local file = File(filename, FILE_READ)
    if file then
        local json = file:ReadLine()
        file:Close()
        local data = cjson.decode(json)
        return data and data.placements or {}
    end
    return {}
end

return KitBash
```

---

## 6. CraftPipeline 完整实现

```lua
-- scripts/scene_craft/CraftPipeline.lua
local CraftPipeline = {}

function CraftPipeline.New()
    return { nodes = {}, connections = {} }
end

function CraftPipeline.AddNode(pipeline, nodeType, params)
    local node = {
        id = #pipeline.nodes + 1,
        type = nodeType,
        params = params or {},
    }
    pipeline.nodes[#pipeline.nodes + 1] = node
    return node.id
end

function CraftPipeline.Connect(pipeline, fromId, toId)
    pipeline.connections[#pipeline.connections + 1] = { from = fromId, to = toId }
end

function CraftPipeline.Chain(...)
    local pipeline = CraftPipeline.New()
    local steps = { ... }
    local prevId = nil
    for i = 1, #steps do
        local nodeId = CraftPipeline.AddNode(pipeline, steps[i].type, steps[i].params)
        if prevId then CraftPipeline.Connect(pipeline, prevId, nodeId) end
        prevId = nodeId
    end
    return pipeline
end

function CraftPipeline.Execute(vg, pipeline, x, y, w, h, imageCache)
    for i = 1, #pipeline.nodes do
        CraftPipeline.ExecuteNode(vg, pipeline.nodes[i], x, y, w, h, imageCache)
    end
end

function CraftPipeline.ExecuteNode(vg, node, x, y, w, h, imageCache)
    local t = node.type
    local p = node.params

    if t == "source" then
        local img = imageCache and imageCache[p.texture]
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

    elseif t == "gradient" then
        local paint = nvgLinearGradient(vg, x, y, x, y + h,
            nvgRGBA(p.top[1], p.top[2], p.top[3], p.top[4] or 255),
            nvgRGBA(p.bottom[1], p.bottom[2], p.bottom[3], p.bottom[4] or 255))
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillPaint(vg, paint)
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
            nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, p.alpha or 180))
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillPaint(vg, paint)
        nvgFill(vg)

    elseif t == "brightness" then
        local factor = p.factor or 1.0
        if factor > 1.0 then
            nvgBeginPath(vg)
            nvgRect(vg, x, y, w, h)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.min(255, math.floor(255 * (factor - 1.0)))))
            nvgFill(vg)
        elseif factor < 1.0 then
            nvgBeginPath(vg)
            nvgRect(vg, x, y, w, h)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, math.min(255, math.floor(255 * (1.0 - factor)))))
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

    elseif t == "grain" then
        -- 简化噪点：随机半透明点阵
        local density = p.density or 0.02
        local alpha = p.alpha or 30
        local step = math.max(2, math.floor(1.0 / density))
        for py = y, y + h, step do
            for px = x, x + w, step do
                if math.random() < density then
                    local gray = math.random(0, 255)
                    nvgBeginPath(vg)
                    nvgRect(vg, px, py, 1, 1)
                    nvgFillColor(vg, nvgRGBA(gray, gray, gray, alpha))
                    nvgFill(vg)
                end
            end
        end
    end
end

function CraftPipeline.SaveState(pipeline, filename)
    local cjson = require("cjson")
    local serializable = { nodes = {}, connections = pipeline.connections }
    for i = 1, #pipeline.nodes do
        serializable.nodes[i] = {
            id = pipeline.nodes[i].id,
            type = pipeline.nodes[i].type,
            params = pipeline.nodes[i].params,
        }
    end
    local json = cjson.encode(serializable)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
        return true
    end
    return false
end

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

return CraftPipeline
```

---

## 7. ControlMapGen 完整实现

```lua
-- scripts/scene_craft/ControlMapGen.lua
local ControlMapGen = {}

function ControlMapGen.RenderDepthMap(vg, compositor, w, h)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgFill(vg)

    local sorted = {}
    for i = 1, #compositor.layers do
        sorted[#sorted + 1] = compositor.layers[i]
    end
    table.sort(sorted, function(a, b) return a.depth > b.depth end)

    for i = 1, #sorted do
        local layer = sorted[i]
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

function ControlMapGen.RenderNormalMap(vg, compositor, w, h)
    -- 简化法线图：平面元素法线朝上 (0.5, 0.5, 1.0) = RGB(128,128,255)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(128, 128, 255, 255))
    nvgFill(vg)

    -- 边缘法线偏转（简化：用渐变模拟边缘法线变化）
    for i = 1, #compositor.layers do
        local layer = compositor.layers[i]
        if not layer.visible then goto continue end
        for j = 1, #layer.elements do
            local e = layer.elements[j]
            -- 左边缘
            local paintL = nvgLinearGradient(vg, e.x, e.y, e.x + 4, e.y,
                nvgRGBA(0, 128, 255, 200), nvgRGBA(128, 128, 255, 0))
            nvgBeginPath(vg)
            nvgRect(vg, e.x, e.y, 4, e.height or 100)
            nvgFillPaint(vg, paintL)
            nvgFill(vg)
            -- 右边缘
            local ex2 = e.x + (e.width or 100)
            local paintR = nvgLinearGradient(vg, ex2 - 4, e.y, ex2, e.y,
                nvgRGBA(128, 128, 255, 0), nvgRGBA(255, 128, 255, 200))
            nvgBeginPath(vg)
            nvgRect(vg, ex2 - 4, e.y, 4, e.height or 100)
            nvgFillPaint(vg, paintR)
            nvgFill(vg)
        end
        ::continue::
    end
end

function ControlMapGen.BuildEditRequest(controlMapPath, prompt)
    return {
        referenceImage = controlMapPath,
        prompt = prompt,
    }
end

return ControlMapGen
```
