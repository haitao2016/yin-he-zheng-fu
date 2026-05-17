# 实用游戏场景配方

> 基于 Scene Craft Compositor 的常见游戏场景实现方案

---

## 配方 1：横版视差滚动背景

**适用场景**：横版平台跳跃、横版射击、跑酷游戏

```lua
-- scripts/main.lua
local vg = nil
local screenW, screenH = 0, 0
local cameraX = 0
local scrollSpeed = 200

-- 图层配置
local layers = {
    { name = "sky",       depth = 1.0, factor = 0.0,  color = {135,206,235,255} },
    { name = "clouds",    depth = 0.9, factor = 0.05, color = {200,220,240,200} },
    { name = "mountains", depth = 0.7, factor = 0.2,  color = {100,120,150,255} },
    { name = "hills",     depth = 0.5, factor = 0.4,  color = {80,140,80,255}   },
    { name = "trees",     depth = 0.3, factor = 0.7,  color = {40,100,40,255}   },
    { name = "ground",    depth = 0.0, factor = 1.0,  color = {76,153,0,255}    },
}

function Start()
    screenW = graphics:GetWidth() / graphics:GetDPR()
    screenH = graphics:GetHeight() / graphics:GetDPR()
    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if input:GetKeyDown(KEY_RIGHT) or input:GetKeyDown(KEY_D) then
        cameraX = cameraX + scrollSpeed * dt
    end
    if input:GetKeyDown(KEY_LEFT) or input:GetKeyDown(KEY_A) then
        cameraX = cameraX - scrollSpeed * dt
    end
end

function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, screenW, screenH, graphics:GetDPR())

    for i = 1, #layers do
        local l = layers[i]
        local ox = -cameraX * l.factor
        local yStart = screenH * (0.2 + l.depth * 0.3)

        nvgBeginPath(vg)
        nvgRect(vg, ox - screenW, yStart, screenW * 5, screenH - yStart)
        nvgFillColor(vg, nvgRGBA(l.color[1], l.color[2], l.color[3], l.color[4]))
        nvgFill(vg)
    end

    -- HUD
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, 10, 20, string.format("Camera: %.0f", cameraX))

    nvgEndFrame(vg)
end

function Stop()
    if vg then nvgDelete(vg) end
end
```

构建后即可预览横版视差效果。

---

## 配方 2：俯视角地牢场景

**适用场景**：Roguelike、俯视角 RPG、地牢探险

```lua
-- 俯视角不需要视差，但需要 Y 轴排序
local sprites = {}
local cameraX, cameraY = 0, 0
local moveSpeed = 150

function Start()
    -- ... 初始化 NanoVG ...

    -- 添加地牢元素（Y 轴排序决定遮挡关系）
    sprites = {
        { x = 100, y = 100, width = 64, height = 96,
          color = {139,69,19,255}, tag = "pillar" },
        { x = 200, y = 150, width = 48, height = 48,
          color = {255,215,0,255}, tag = "chest" },
        { x = 160, y = 120, width = 32, height = 48,
          color = {70,130,180,255}, tag = "player" },
        { x = 300, y = 200, width = 64, height = 96,
          color = {139,69,19,255}, tag = "pillar" },
    }

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, screenW, screenH, graphics:GetDPR())

    -- 地板
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(60, 60, 60, 255))
    nvgFill(vg)

    -- Y 轴排序
    table.sort(sprites, function(a, b)
        local ay = a.y + (a.height or 0)
        local by = b.y + (b.height or 0)
        return ay < by
    end)

    -- 渲染排序后的精灵
    for i = 1, #sprites do
        local s = sprites[i]
        nvgBeginPath(vg)
        nvgRect(vg, s.x - cameraX, s.y - cameraY, s.width, s.height)
        nvgFillColor(vg, nvgRGBA(s.color[1], s.color[2], s.color[3], s.color[4]))
        nvgFill(vg)
    end

    nvgEndFrame(vg)
end
```

---

## 配方 3：等距场景（Isometric）

**适用场景**：城市建造、策略游戏、农场模拟

```lua
-- 等距坐标转换
local function IsoToScreen(ix, iy, tileW, tileH)
    local sx = (ix - iy) * (tileW * 0.5)
    local sy = (ix + iy) * (tileH * 0.5)
    return sx, sy
end

local function ScreenToIso(sx, sy, tileW, tileH)
    local ix = (sx / (tileW * 0.5) + sy / (tileH * 0.5)) * 0.5
    local iy = (sy / (tileH * 0.5) - sx / (tileW * 0.5)) * 0.5
    return math.floor(ix), math.floor(iy)
end

-- 等距地图数据
local mapW, mapH = 10, 10
local tileW, tileH = 64, 32
local map = {}  -- map[y][x] = tileType

function InitMap()
    for y = 1, mapH do
        map[y] = {}
        for x = 1, mapW do
            map[y][x] = (math.random() < 0.2) and 1 or 0  -- 1=建筑, 0=地面
        end
    end
end

function RenderIsoMap(vg, offsetX, offsetY)
    -- 按行列顺序绘制（自然实现后物体遮挡前物体）
    for y = 1, mapH do
        for x = 1, mapW do
            local sx, sy = IsoToScreen(x, y, tileW, tileH)
            sx = sx + offsetX
            sy = sy + offsetY

            -- 地面菱形
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy - tileH * 0.5)
            nvgLineTo(vg, sx + tileW * 0.5, sy)
            nvgLineTo(vg, sx, sy + tileH * 0.5)
            nvgLineTo(vg, sx - tileW * 0.5, sy)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(100, 180, 100, 255))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 140, 80, 255))
            nvgStroke(vg)

            -- 建筑
            if map[y][x] == 1 then
                local bh = 40  -- 建筑高度
                nvgBeginPath(vg)
                nvgRect(vg, sx - 15, sy - bh - tileH * 0.25, 30, bh)
                nvgFillColor(vg, nvgRGBA(180, 120, 80, 255))
                nvgFill(vg)
            end
        end
    end
end
```

---

## 配方 4：KitBash 场景编辑器原型

**适用场景**：关卡编辑器、场景搭建工具

```lua
local selectedAssetId = nil
local placedInstances = {}
local gridSize = 32

-- 简单套件
local editorKit = {
    name = "Platformer Kit",
    assets = {
        { id = "ground",  name = "地面", width = 64, height = 32,
          anchor = { x = 0.5, y = 1.0 }, color = {76,153,0,255} },
        { id = "brick",   name = "砖块", width = 32, height = 32,
          anchor = { x = 0.5, y = 0.5 }, color = {180,100,60,255} },
        { id = "spike",   name = "尖刺", width = 32, height = 16,
          anchor = { x = 0.5, y = 1.0 }, color = {200,50,50,255} },
        { id = "coin",    name = "金币", width = 16, height = 16,
          anchor = { x = 0.5, y = 0.5 }, color = {255,215,0,255} },
    },
}

function HandleMouseClick(x, y)
    if selectedAssetId then
        -- 网格对齐
        local snappedX = math.floor(x / gridSize) * gridSize
        local snappedY = math.floor(y / gridSize) * gridSize

        placedInstances[#placedInstances + 1] = {
            assetId = selectedAssetId,
            x = snappedX,
            y = snappedY,
            scaleX = 1.0,
            scaleY = 1.0,
            layer = 0,
        }
    end
end

function RenderEditor(vg)
    -- 绘制网格
    nvgStrokeColor(vg, nvgRGBA(100, 100, 100, 50))
    nvgStrokeWidth(vg, 0.5)
    for gx = 0, screenW, gridSize do
        nvgBeginPath(vg)
        nvgMoveTo(vg, gx, 0)
        nvgLineTo(vg, gx, screenH)
        nvgStroke(vg)
    end
    for gy = 0, screenH, gridSize do
        nvgBeginPath(vg)
        nvgMoveTo(vg, 0, gy)
        nvgLineTo(vg, screenW, gy)
        nvgStroke(vg)
    end

    -- 绘制已放置的实例
    for i = 1, #placedInstances do
        local inst = placedInstances[i]
        local asset = FindAsset(editorKit, inst.assetId)
        if asset and asset.color then
            nvgBeginPath(vg)
            nvgRect(vg, inst.x, inst.y, asset.width, asset.height)
            nvgFillColor(vg, nvgRGBA(asset.color[1], asset.color[2], asset.color[3], asset.color[4] or 255))
            nvgFill(vg)
        end
    end
end

function FindAsset(kit, id)
    for i = 1, #kit.assets do
        if kit.assets[i].id == id then return kit.assets[i] end
    end
    return nil
end

--- 保存关卡布局
function SaveLevel(filename)
    local cjson = require("cjson")
    local data = { placements = placedInstances }
    local json = cjson.encode(data)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
        log:Write(LOG_INFO, "Level saved: " .. filename)
    end
end

--- 加载关卡布局
function LoadLevel(filename)
    local cjson = require("cjson")
    local file = File(filename, FILE_READ)
    if file then
        local json = file:ReadLine()
        file:Close()
        local data = cjson.decode(json)
        placedInstances = data and data.placements or {}
        log:Write(LOG_INFO, "Level loaded: " .. filename)
    end
end
```

---

## 配方 5：视觉处理管线（后处理链）

**适用场景**：场景氛围切换、日夜交替、滤镜效果

```lua
-- 不同氛围的管线预设
local Atmospheres = {
    dawn = {
        { type = "tint",       params = { color = {255,180,120}, strength = 0.2 } },
        { type = "vignette",   params = { radius = 0.9, softness = 0.5 } },
        { type = "brightness", params = { factor = 0.9 } },
    },
    night = {
        { type = "tint",       params = { color = {30,40,80}, strength = 0.4 } },
        { type = "vignette",   params = { radius = 0.6, softness = 0.6 } },
        { type = "brightness", params = { factor = 0.6 } },
    },
    underwater = {
        { type = "tint",       params = { color = {60,120,180}, strength = 0.35 } },
        { type = "vignette",   params = { radius = 0.7, softness = 0.5 } },
        { type = "brightness", params = { factor = 0.8 } },
    },
}

function ApplyAtmosphere(vg, name, x, y, w, h)
    local preset = Atmospheres[name]
    if not preset then return end

    local pipeline = CraftPipeline.Chain(table.unpack(preset))
    CraftPipeline.Execute(vg, pipeline, x, y, w, h, nil)
end

-- 在渲染循环中使用
-- 先渲染场景，再叠加氛围管线
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, screenW, screenH, graphics:GetDPR())

    -- 1. 渲染场景图层
    RenderScene(vg)

    -- 2. 叠加氛围效果
    ApplyAtmosphere(vg, currentAtmosphere, 0, 0, screenW, screenH)

    nvgEndFrame(vg)
end
```

---

## 配方 6：角色一致性工作流（MCP 集成）

**适用场景**：需要 AI 生成角色图像并保持一致的游戏

```lua
-- 1. 定义角色 Token
local mainCharToken = {
    name = "Forest_Ranger",
    version = 1,
    visualTraits = {
        bodyType = "athletic female",
        hair = "long auburn braid",
        eyes = "green",
        outfit = "leather vest, brown boots, green cloak",
    },
    promptAnchors = {
        "auburn braided hair female ranger",
        "green eyes, leather vest",
        "brown boots, green forest cloak",
        "athletic build, confident stance",
    },
    colorPalette = {
        primary   = "#8B4513",  -- 皮革棕
        secondary = "#228B22",  -- 森林绿
        accent    = "#DAA520",  -- 金属扣
        skin      = "#DEB887",  -- 肤色
    },
    referenceImages = {
        "assets/Textures/Characters/ranger_ref.png",
    },
}

-- 2. 保存 Token 到存档
IdentityToken.Save(mainCharToken, "char_ranger.json")

-- 3. 生成不同场景的角色图像请求
local forestReq = IdentityToken.BuildImageRequest(
    mainCharToken,
    "standing with bow drawn, aiming",
    "dense forest background, dappled sunlight"
)
-- AI 助手使用 forestReq.prompt 和 forestReq.referenceImages 调用 MCP

local campReq = IdentityToken.BuildImageRequest(
    mainCharToken,
    "sitting by campfire, relaxed",
    "night camp, warm firelight"
)
```

---

## 通用提示

### 性能优化清单

| 优化项 | 方法 | 影响 |
|--------|------|------|
| 视口裁剪 | 只渲染可见元素 | 减少 draw call |
| 图像缓存 | nvgCreateImage 只调用一次 | 避免显存泄漏 |
| 排序频率 | 只在元素变化时重新排序 | 减少 CPU 开销 |
| 图层合并 | 静态图层合并为单一纹理 | 减少图层遍历 |

### 调试技巧

```lua
-- 显示图层边界（调试用）
function DebugDrawLayerBounds(vg, compositor)
    nvgStrokeWidth(vg, 1)
    for i = 1, #compositor.layers do
        local layer = compositor.layers[i]
        -- 随机颜色标识图层
        local hue = (i * 60) % 360
        nvgStrokeColor(vg, nvgHSLA(hue, 200, 128, 180))
        for j = 1, #layer.elements do
            local e = layer.elements[j]
            nvgBeginPath(vg)
            nvgRect(vg, e.x, e.y, e.width or 10, e.height or 10)
            nvgStroke(vg)
        end
    end
end
```

### 存档和读取场景状态

使用 `File` API 和 `cjson`（不使用 `io` 库）：

```lua
function QuickSave(data, name)
    local cjson = require("cjson")
    local json = cjson.encode(data)
    local file = File(name .. ".json", FILE_WRITE)
    if file then
        file:WriteLine(json)
        file:Close()
    end
end

function QuickLoad(name)
    local cjson = require("cjson")
    local file = File(name .. ".json", FILE_READ)
    if file then
        local json = file:ReadLine()
        file:Close()
        return cjson.decode(json)
    end
    return nil
end
```

每次修改代码后，请使用构建工具验证。
