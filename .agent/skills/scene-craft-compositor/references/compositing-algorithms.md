# 图层合成算法与混合模式参考

> Scene Craft Compositor 的数学基础与算法参考

---

## 1. 混合模式数学公式

### 1.1 Porter-Duff 合成模型

所有混合模式基于 Porter-Duff alpha 合成模型：

```
Result = Source × Fs + Dest × Fd
```

其中 Fs、Fd 是混合因子，由 NanoVG 的 `nvgGlobalCompositeBlendFunc` 控制。

### 1.2 标准混合模式

| 模式 | 公式 | NanoVG 实现 | 用途 |
|------|------|------------|------|
| Normal | `S * Sa + D * (1-Sa)` | `NVG_SOURCE_OVER` | 默认叠加 |
| Additive | `S * Sa + D * 1` | `NVG_SRC_ALPHA, NVG_ONE` | 发光、火焰 |
| Multiply | `D * S + D * (1-Sa)` | `NVG_DST_COLOR, NVG_ONE_MINUS_SRC_ALPHA` | 阴影、染色 |
| Screen | `S * 1 + D * (1-S)` | `NVG_ONE, NVG_ONE_MINUS_SRC_COLOR` | 高光、雾气 |

### 1.3 Lua 实现

```lua
local BlendModes = {
    normal = function(vg)
        nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
    end,
    additive = function(vg)
        nvgGlobalCompositeBlendFunc(vg, NVG_SRC_ALPHA, NVG_ONE)
    end,
    multiply = function(vg)
        nvgGlobalCompositeBlendFunc(vg, NVG_DST_COLOR, NVG_ONE_MINUS_SRC_ALPHA)
    end,
    screen = function(vg)
        nvgGlobalCompositeBlendFunc(vg, NVG_ONE, NVG_ONE_MINUS_SRC_COLOR)
    end,
}

function ApplyBlend(vg, mode)
    local fn = BlendModes[mode or "normal"]
    if fn then fn(vg) end
end
```

---

## 2. 深度排序算法

### 2.1 画家算法（Painter's Algorithm）

从远到近依次绘制，后绘制的覆盖先绘制的：

```lua
function PainterSort(layers)
    table.sort(layers, function(a, b)
        return a.depth > b.depth  -- depth 大 = 更远 = 先画
    end)
end
```

**时间复杂度**: O(n log n) 排序 + O(n) 遍历

### 2.2 Y 轴排序（2D 等距/俯视视角）

精灵底部 Y 坐标越大越靠近观察者：

```lua
function YAxisSort(sprites)
    table.sort(sprites, function(a, b)
        local ay = a.y + (a.height or 0)  -- 底部 Y
        local by = b.y + (b.height or 0)
        if ay == by then
            return a.x < b.x
        end
        return ay < by  -- Y 小的先画（更远）
    end)
end
```

### 2.3 多键排序（图层 + Y 轴混合）

```lua
function HybridSort(elements)
    table.sort(elements, function(a, b)
        -- 先按图层排序
        if a.layer ~= b.layer then
            return a.layer < b.layer
        end
        -- 同层按 Y 轴排序
        local ay = a.y + (a.height or 0)
        local by = b.y + (b.height or 0)
        if ay ~= by then
            return ay < by
        end
        -- Y 相同按 X
        return a.x < b.x
    end)
end
```

---

## 3. 视差滚动公式

### 3.1 基础视差

```
elementScreenX = elementWorldX - cameraX * parallaxFactor
```

- `parallaxFactor = 0`: 不移动（固定背景，如天空）
- `parallaxFactor = 1`: 与相机同步移动（前景/地面）
- `parallaxFactor > 1`: 移动比相机快（近距离前景物体）

### 3.2 无限滚动（Tiling）

```lua
function TiledScroll(elementX, tileWidth, cameraX, factor)
    local offset = -cameraX * factor
    local wrapped = offset % tileWidth
    return elementX + wrapped
end
```

### 3.3 垂直视差（纵版游戏）

```lua
function VerticalParallax(elementY, cameraY, factor)
    return elementY - cameraY * factor
end
```

---

## 4. 大气透视算法

### 4.1 线性雾

```lua
function LinearFog(baseColor, depth, fogColor, fogStart, fogEnd)
    if depth <= fogStart then return baseColor end
    local t = math.min(1.0, (depth - fogStart) / (fogEnd - fogStart))
    return LerpColor(baseColor, fogColor, t)
end

function LerpColor(a, b, t)
    return {
        math.floor(a[1] + (b[1] - a[1]) * t),
        math.floor(a[2] + (b[2] - a[2]) * t),
        math.floor(a[3] + (b[3] - a[3]) * t),
        a[4] or 255,
    }
end
```

### 4.2 指数雾

```lua
function ExponentialFog(baseColor, depth, fogColor, density)
    local t = 1.0 - math.exp(-density * depth)
    return LerpColor(baseColor, fogColor, t)
end
```

---

## 5. 视口裁剪

### 5.1 AABB 裁剪

```lua
function AABBIntersects(ax, ay, aw, ah, bx, by, bw, bh)
    return ax + aw > bx
       and ax < bx + bw
       and ay + ah > by
       and ay < by + bh
end

function CullElements(elements, viewX, viewY, viewW, viewH)
    local visible = {}
    for i = 1, #elements do
        local e = elements[i]
        if AABBIntersects(e.x, e.y, e.width or 0, e.height or 0,
                          viewX, viewY, viewW, viewH) then
            visible[#visible + 1] = e
        end
    end
    return visible
end
```

### 5.2 裁剪考虑视差偏移

```lua
function CullWithParallax(elements, cameraX, parallaxFactor, viewW, viewH)
    local viewX = cameraX * parallaxFactor
    return CullElements(elements, viewX, 0, viewW, viewH)
end
```

---

## 6. 图像缓存管理

### 6.1 惰性加载 + 引用计数

```lua
local ImageCacheManager = {}

function ImageCacheManager.New(vg)
    return {
        vg = vg,
        cache = {},     -- path → { handle, refCount }
    }
end

function ImageCacheManager.Get(mgr, path)
    if mgr.cache[path] then
        mgr.cache[path].refCount = mgr.cache[path].refCount + 1
        return mgr.cache[path].handle
    end
    local handle = nvgCreateImage(mgr.vg, path, 0)
    if handle > 0 then
        mgr.cache[path] = { handle = handle, refCount = 1 }
    end
    return handle
end

function ImageCacheManager.Release(mgr, path)
    local entry = mgr.cache[path]
    if entry then
        entry.refCount = entry.refCount - 1
        if entry.refCount <= 0 then
            nvgDeleteImage(mgr.vg, entry.handle)
            mgr.cache[path] = nil
        end
    end
end

function ImageCacheManager.Clear(mgr)
    for path, entry in pairs(mgr.cache) do
        nvgDeleteImage(mgr.vg, entry.handle)
    end
    mgr.cache = {}
end
```
