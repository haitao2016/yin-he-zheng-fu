# Lua 实现参考 — 完整代码

> 本文档提供 `neural-texture-synthesis` skill 中五个核心模块的
> 完整可复制 Lua 代码。所有代码遵循 UrhoX Lua 开发规范。

---

## 模块 1: ColorStatistics

> 色彩分析与迁移工具，对应 NST 中的内容/风格分离概念。

```lua
-- scripts/NeuralTexture/ColorStatistics.lua
-- 色彩统计与迁移模块

local ColorStatistics = {}

----------------------------------------------------------------
-- 1. 色彩空间转换
----------------------------------------------------------------

--- RGB → HSV
---@param r number 0~1
---@param g number 0~1
---@param b number 0~1
---@return number h 0~360
---@return number s 0~1
---@return number v 0~1
function ColorStatistics.RGBtoHSV(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local d = max - min
    local h, s, v

    v = max
    s = (max == 0) and 0 or (d / max)

    if d == 0 then
        h = 0
    elseif max == r then
        h = 60 * (((g - b) / d) % 6)
    elseif max == g then
        h = 60 * (((b - r) / d) + 2)
    else
        h = 60 * (((r - g) / d) + 4)
    end

    if h < 0 then h = h + 360 end
    return h, s, v
end

--- HSV → RGB
---@param h number 0~360
---@param s number 0~1
---@param v number 0~1
---@return number r, number g, number b (all 0~1)
function ColorStatistics.HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b

    if h < 60 then      r, g, b = c, x, 0
    elseif h < 120 then  r, g, b = x, c, 0
    elseif h < 180 then  r, g, b = 0, c, x
    elseif h < 240 then  r, g, b = 0, x, c
    elseif h < 300 then  r, g, b = x, 0, c
    else                  r, g, b = c, 0, x
    end

    return r + m, g + m, b + m
end

--- sRGB 线性化（单通道）
local function srgbToLinear(c)
    if c > 0.04045 then
        return ((c + 0.055) / 1.055) ^ 2.4
    else
        return c / 12.92
    end
end

--- 线性 → sRGB（单通道）
local function linearToSrgb(c)
    if c > 0.0031308 then
        return 1.055 * c ^ (1.0 / 2.4) - 0.055
    else
        return 12.92 * c
    end
end

--- RGB → CIE Lab（经由 XYZ）
---@param r number 0~1 (sRGB)
---@param g number 0~1
---@param b number 0~1
---@return number L, number a, number bL
function ColorStatistics.RGBtoLab(r, g, b)
    -- sRGB → 线性 RGB
    local rl = srgbToLinear(r)
    local gl = srgbToLinear(g)
    local bl = srgbToLinear(b)

    -- 线性 RGB → XYZ (D65)
    local x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl
    local y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
    local z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl

    -- D65 白点
    local xn, yn, zn = 0.95047, 1.00000, 1.08883

    local function f(t)
        local delta = 6.0 / 29.0
        if t > delta * delta * delta then
            return t ^ (1.0 / 3.0)
        else
            return t / (3.0 * delta * delta) + 4.0 / 29.0
        end
    end

    local fx = f(x / xn)
    local fy = f(y / yn)
    local fz = f(z / zn)

    local L = 116.0 * fy - 16.0
    local a = 500.0 * (fx - fy)
    local bVal = 200.0 * (fy - fz)

    return L, a, bVal
end

--- CIE Lab → RGB
---@param L number
---@param a number
---@param bVal number
---@return number r, number g, number b (0~1 sRGB, clamped)
function ColorStatistics.LabToRGB(L, a, bVal)
    local xn, yn, zn = 0.95047, 1.00000, 1.08883
    local delta = 6.0 / 29.0

    local fy = (L + 16.0) / 116.0
    local fx = a / 500.0 + fy
    local fz = fy - bVal / 200.0

    local function fInv(t)
        if t > delta then
            return t * t * t
        else
            return 3.0 * delta * delta * (t - 4.0 / 29.0)
        end
    end

    local x = xn * fInv(fx)
    local y = yn * fInv(fy)
    local z = zn * fInv(fz)

    -- XYZ → 线性 RGB
    local rl =  3.2404542 * x - 1.5371385 * y - 0.4985314 * z
    local gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
    local bl =  0.0556434 * x - 0.2040259 * y + 1.0572252 * z

    -- 线性 → sRGB 并 clamp
    local function clamp01(v) return math.max(0, math.min(1, v)) end
    return clamp01(linearToSrgb(rl)),
           clamp01(linearToSrgb(gl)),
           clamp01(linearToSrgb(bl))
end

----------------------------------------------------------------
-- 2. 色彩统计
----------------------------------------------------------------

--- 计算 Lab 统计量（均值、标准差）
---@param colors table { {r,g,b}, ... } 0~1
---@return table { meanL, meanA, meanB, stdL, stdA, stdB }
function ColorStatistics.ComputeLabStats(colors)
    local n = #colors
    if n == 0 then
        return { meanL = 0, meanA = 0, meanB = 0, stdL = 0, stdA = 0, stdB = 0 }
    end

    local sumL, sumA, sumB = 0, 0, 0
    local labs = {}

    for i = 1, n do
        local c = colors[i]
        local L, a, b = ColorStatistics.RGBtoLab(c[1], c[2], c[3])
        labs[i] = { L, a, b }
        sumL = sumL + L
        sumA = sumA + a
        sumB = sumB + b
    end

    local mL, mA, mB = sumL / n, sumA / n, sumB / n

    local varL, varA, varB = 0, 0, 0
    for i = 1, n do
        varL = varL + (labs[i][1] - mL) ^ 2
        varA = varA + (labs[i][2] - mA) ^ 2
        varB = varB + (labs[i][3] - mB) ^ 2
    end

    return {
        meanL = mL, meanA = mA, meanB = mB,
        stdL = math.sqrt(varL / n),
        stdA = math.sqrt(varA / n),
        stdB = math.sqrt(varB / n),
    }
end

----------------------------------------------------------------
-- 3. Reinhard 颜色迁移
----------------------------------------------------------------

--- 将 srcColors 的色彩分布迁移到 tgtColors 的分布
---@param srcColors table { {r,g,b}, ... }
---@param tgtStats table 来自 ComputeLabStats
---@return table 迁移后的颜色 { {r,g,b}, ... }
function ColorStatistics.TransferColors(srcColors, tgtStats)
    local srcStats = ColorStatistics.ComputeLabStats(srcColors)
    local result = {}

    for i = 1, #srcColors do
        local c = srcColors[i]
        local L, a, b = ColorStatistics.RGBtoLab(c[1], c[2], c[3])

        -- Reinhard 公式
        local safeDiv = function(num, den)
            return (den > 1e-6) and (num / den) or 0
        end

        local newL = (L - srcStats.meanL) * safeDiv(tgtStats.stdL, srcStats.stdL) + tgtStats.meanL
        local newA = (a - srcStats.meanA) * safeDiv(tgtStats.stdA, srcStats.stdA) + tgtStats.meanA
        local newB = (b - srcStats.meanB) * safeDiv(tgtStats.stdB, srcStats.stdB) + tgtStats.meanB

        local r, g, bVal = ColorStatistics.LabToRGB(newL, newA, newB)
        result[i] = { r, g, bVal }
    end

    return result
end

----------------------------------------------------------------
-- 4. 调色板提取（简化 K-Means）
----------------------------------------------------------------

--- 从颜色列表中提取 K 个代表色
---@param colors table { {r,g,b}, ... }
---@param k number 聚类数（默认 5）
---@param maxIter number 最大迭代次数（默认 20）
---@return table 调色板 { {r,g,b}, ... }
function ColorStatistics.ExtractPalette(colors, k, maxIter)
    k = k or 5
    maxIter = maxIter or 20
    local n = #colors
    if n <= k then return colors end

    -- 随机初始化中心
    local centers = {}
    local used = {}
    for i = 1, k do
        local idx
        repeat
            idx = math.random(1, n)
        until not used[idx]
        used[idx] = true
        centers[i] = { colors[idx][1], colors[idx][2], colors[idx][3] }
    end

    local assign = {}

    for iter = 1, maxIter do
        -- 分配
        for i = 1, n do
            local bestDist = math.huge
            local bestK = 1
            for j = 1, k do
                local dr = colors[i][1] - centers[j][1]
                local dg = colors[i][2] - centers[j][2]
                local db = colors[i][3] - centers[j][3]
                local dist = dr * dr + dg * dg + db * db
                if dist < bestDist then
                    bestDist = dist
                    bestK = j
                end
            end
            assign[i] = bestK
        end

        -- 更新中心
        local sums = {}
        local counts = {}
        for j = 1, k do
            sums[j] = { 0, 0, 0 }
            counts[j] = 0
        end

        for i = 1, n do
            local j = assign[i]
            sums[j][1] = sums[j][1] + colors[i][1]
            sums[j][2] = sums[j][2] + colors[i][2]
            sums[j][3] = sums[j][3] + colors[i][3]
            counts[j] = counts[j] + 1
        end

        for j = 1, k do
            if counts[j] > 0 then
                centers[j][1] = sums[j][1] / counts[j]
                centers[j][2] = sums[j][2] / counts[j]
                centers[j][3] = sums[j][3] / counts[j]
            end
        end
    end

    return centers
end

----------------------------------------------------------------
-- 5. 色彩和谐方案
----------------------------------------------------------------

--- 生成和谐配色方案
---@param h number 基准色相 0~360
---@param s number 饱和度 0~1
---@param v number 明度 0~1
---@param scheme string "complementary"|"triadic"|"analogous"|"split"
---@return table { {r,g,b}, ... }
function ColorStatistics.HarmonyScheme(h, s, v, scheme)
    local hues = {}
    if scheme == "complementary" then
        hues = { h, (h + 180) % 360 }
    elseif scheme == "triadic" then
        hues = { h, (h + 120) % 360, (h + 240) % 360 }
    elseif scheme == "analogous" then
        hues = { (h - 30) % 360, h, (h + 30) % 360 }
    elseif scheme == "split" then
        hues = { h, (h + 150) % 360, (h + 210) % 360 }
    else
        hues = { h }
    end

    local result = {}
    for i = 1, #hues do
        local r, g, b = ColorStatistics.HSVtoRGB(hues[i], s, v)
        result[i] = { r, g, b }
    end
    return result
end

----------------------------------------------------------------
-- 6. 持久化
----------------------------------------------------------------

--- 保存颜色配置到 JSON
---@param config table 配置数据
---@param filename string 文件名（如 "color_preset.json"）
function ColorStatistics.SaveConfig(config, filename)
    local cjson = require "cjson"
    local jsonStr = cjson.encode(config)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteString(jsonStr)
        file:Close()
        log:Write(LOG_INFO, "ColorStatistics: saved to " .. filename)
    end
end

--- 加载颜色配置
---@param filename string
---@return table|nil
function ColorStatistics.LoadConfig(filename)
    if not fileSystem:FileExists(filename) then return nil end
    local cjson = require "cjson"
    local file = File(filename, FILE_READ)
    if file then
        local jsonStr = file:ReadString()
        file:Close()
        return cjson.decode(jsonStr)
    end
    return nil
end

return ColorStatistics
```

---

## 模块 2: ProceduralTexture

> 程序化纹理生成，对应 NST 中的 Gram 矩阵纹理统计概念。

```lua
-- scripts/NeuralTexture/ProceduralTexture.lua
-- 程序化纹理生成模块

local ProceduralTexture = {}

----------------------------------------------------------------
-- 1. Perlin 噪声
----------------------------------------------------------------

local perm = {}
local function initPerm(seed)
    math.randomseed(seed or 0)
    local p = {}
    for i = 0, 255 do p[i] = i end
    for i = 255, 1, -1 do
        local j = math.random(0, i)
        p[i], p[j] = p[j], p[i]
    end
    for i = 0, 511 do
        perm[i] = p[i % 256]
    end
end
initPerm(42)

local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end

local function grad(hash, x, y)
    local h = hash & 3
    if h == 0 then return  x + y
    elseif h == 1 then return -x + y
    elseif h == 2 then return  x - y
    else return -x - y
    end
end

local function lerp(a, b, t) return a + t * (b - a) end

--- 2D Perlin 噪声
---@param x number
---@param y number
---@return number 约 -1 ~ 1
function ProceduralTexture.Perlin2D(x, y)
    local xi = math.floor(x) & 255
    local yi = math.floor(y) & 255
    local xf = x - math.floor(x)
    local yf = y - math.floor(y)

    local u = fade(xf)
    local v = fade(yf)

    local aa = perm[perm[xi] + yi]
    local ab = perm[perm[xi] + yi + 1]
    local ba = perm[perm[xi + 1] + yi]
    local bb = perm[perm[xi + 1] + yi + 1]

    return lerp(
        lerp(grad(aa, xf, yf),     grad(ba, xf - 1, yf),     u),
        lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u),
        v
    )
end

--- 分形布朗运动
---@param x number
---@param y number
---@param octaves number 叠加层数（默认 6）
---@param lacunarity number 频率倍增（默认 2.0）
---@param gain number 振幅衰减（默认 0.5）
---@return number 约 -1 ~ 1
function ProceduralTexture.FBM(x, y, octaves, lacunarity, gain)
    octaves = octaves or 6
    lacunarity = lacunarity or 2.0
    gain = gain or 0.5

    local sum = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxAmp = 0

    for _ = 1, octaves do
        sum = sum + amplitude * ProceduralTexture.Perlin2D(x * frequency, y * frequency)
        maxAmp = maxAmp + amplitude
        amplitude = amplitude * gain
        frequency = frequency * lacunarity
    end

    return sum / maxAmp
end

----------------------------------------------------------------
-- 2. Worley 噪声（细胞噪声）
----------------------------------------------------------------

--- 2D Worley 噪声
---@param x number
---@param y number
---@param density number 每单元种子点数（默认 1）
---@return number F1 最近距离
---@return number F2 第二近距离
function ProceduralTexture.Worley2D(x, y, density)
    density = density or 1
    local cellX = math.floor(x)
    local cellY = math.floor(y)

    local f1 = math.huge
    local f2 = math.huge

    for dx = -1, 1 do
        for dy = -1, 1 do
            local cx = cellX + dx
            local cy = cellY + dy
            -- 伪随机偏移（简易哈希）
            local hash = (cx * 374761393 + cy * 668265263) & 0x7FFFFFFF
            for _ = 1, density do
                local px = cx + (hash % 1000) / 1000.0
                hash = (hash * 1103515245 + 12345) & 0x7FFFFFFF
                local py = cy + (hash % 1000) / 1000.0
                hash = (hash * 1103515245 + 12345) & 0x7FFFFFFF

                local distSq = (x - px) ^ 2 + (y - py) ^ 2
                if distSq < f1 then
                    f2 = f1
                    f1 = distSq
                elseif distSq < f2 then
                    f2 = distSq
                end
            end
        end
    end

    return math.sqrt(f1), math.sqrt(f2)
end

----------------------------------------------------------------
-- 3. 纹理类型工厂
----------------------------------------------------------------

--- 采样纹理值
---@param texType string "marble"|"wood"|"stone"|"checkerboard"|"noise"
---@param x number
---@param y number
---@param params table|nil 可选参数
---@return number 0~1
function ProceduralTexture.Sample(texType, x, y, params)
    params = params or {}
    local scale = params.scale or 1.0
    local sx, sy = x * scale, y * scale

    if texType == "marble" then
        local turb = ProceduralTexture.FBM(sx, sy, params.octaves or 6)
        local v = math.sin(sx * (params.veins or 5.0) + turb * (params.turbulence or 5.0))
        return (v + 1) * 0.5

    elseif texType == "wood" then
        local dist = math.sqrt(sx * sx + sy * sy) * (params.rings or 10.0)
        local turb = ProceduralTexture.FBM(sx, sy, params.octaves or 4) * (params.turbulence or 2.0)
        local v = math.sin(dist + turb)
        return (v + 1) * 0.5

    elseif texType == "stone" then
        local f1, f2 = ProceduralTexture.Worley2D(sx, sy)
        local edge = f2 - f1
        local noise = ProceduralTexture.FBM(sx * 3, sy * 3, 4) * 0.15
        return math.min(1, math.max(0, edge + noise))

    elseif texType == "checkerboard" then
        local cx = math.floor(sx) % 2
        local cy = math.floor(sy) % 2
        return ((cx + cy) % 2 == 0) and 1.0 or 0.0

    else -- "noise"
        return (ProceduralTexture.FBM(sx, sy, params.octaves or 6) + 1) * 0.5
    end
end

----------------------------------------------------------------
-- 4. 重新初始化排列表
----------------------------------------------------------------

--- 用新种子重置噪声
---@param seed number
function ProceduralTexture.SetSeed(seed)
    initPerm(seed)
end

----------------------------------------------------------------
-- 5. NanoVG 预览
----------------------------------------------------------------

--- 在 NanoVG 中预览纹理
---@param vg userdata NanoVG 上下文
---@param x number 绘制起始 X
---@param y number 绘制起始 Y
---@param w number 宽度
---@param h number 高度
---@param texType string 纹理类型
---@param params table|nil 纹理参数
---@param colorFunc function|nil 值到颜色的映射 (v) -> r,g,b
function ProceduralTexture.PreviewNVG(vg, x, y, w, h, texType, params, colorFunc)
    local step = params and params.previewStep or 4
    colorFunc = colorFunc or function(v)
        return v, v, v
    end

    for py = 0, h - 1, step do
        for px = 0, w - 1, step do
            local u = px / w * 10
            local v_coord = py / h * 10
            local val = ProceduralTexture.Sample(texType, u, v_coord, params)
            local r, g, b = colorFunc(val)

            nvgBeginPath(vg)
            nvgRect(vg, x + px, y + py, step, step)
            nvgFillColor(vg, nvgRGBf(r, g, b))
            nvgFill(vg)
        end
    end
end

----------------------------------------------------------------
-- 6. MCP 集成辅助
----------------------------------------------------------------

--- 生成 MCP generate_image 的描述词
---@param texType string
---@param params table|nil
---@return string 中文描述
function ProceduralTexture.GeneratePrompt(texType, params)
    params = params or {}
    local prompts = {
        marble = "大理石纹理，白色底色带灰色纹路，光滑表面",
        wood   = "木纹纹理，温暖的棕色木材，年轮清晰",
        stone  = "石墙纹理，灰色不规则碎石，接缝明显",
        noise  = "抽象噪声纹理，灰色渐变，有机感",
    }

    local base = prompts[texType] or "抽象纹理"
    if params.style then
        base = base .. "，" .. params.style .. "风格"
    end
    if params.color then
        base = base .. "，" .. params.color .. "色调"
    end
    return base .. "，无缝拼接，游戏贴图"
end

return ProceduralTexture
```

---

## 模块 3: PainterlyRenderer

> 绘画风格渲染，对应 NST 中的多层特征概念。

```lua
-- scripts/NeuralTexture/PainterlyRenderer.lua
-- 绘画风格 NanoVG 渲染器

local PainterlyRenderer = {}

----------------------------------------------------------------
-- 1. 油画笔触填充
----------------------------------------------------------------

--- 用油画笔触填充区域
---@param vg userdata NanoVG 上下文
---@param x number 区域左上角 X
---@param y number 区域左上角 Y
---@param w number 区域宽度
---@param h number 区域高度
---@param baseR number 基础红色 0~1
---@param baseG number 基础绿色 0~1
---@param baseB number 基础蓝色 0~1
---@param params table|nil { brushSize, density, variation }
function PainterlyRenderer.OilPaintFill(vg, x, y, w, h, baseR, baseG, baseB, params)
    params = params or {}
    local brushSize = params.brushSize or 12
    local density = params.density or 200
    local variation = params.variation or 0.15

    for _ = 1, density do
        local bx = x + math.random() * w
        local by = y + math.random() * h
        local bw = brushSize * (0.5 + math.random() * 1.5)
        local bh = bw * (0.3 + math.random() * 0.4)
        local angle = math.random() * math.pi

        -- 颜色变化
        local dr = (math.random() - 0.5) * 2 * variation
        local dg = (math.random() - 0.5) * 2 * variation
        local db = (math.random() - 0.5) * 2 * variation

        local r = math.max(0, math.min(1, baseR + dr))
        local g = math.max(0, math.min(1, baseG + dg))
        local b = math.max(0, math.min(1, baseB + db))

        nvgSave(vg)
        nvgTranslate(vg, bx, by)
        nvgRotate(vg, angle)
        nvgBeginPath(vg)
        nvgEllipse(vg, 0, 0, bw * 0.5, bh * 0.5)
        nvgFillColor(vg, nvgRGBAf(r, g, b, 0.7 + math.random() * 0.3))
        nvgFill(vg)
        nvgRestore(vg)
    end
end

----------------------------------------------------------------
-- 2. 水彩渲染
----------------------------------------------------------------

--- 水彩色斑绘制
---@param vg userdata
---@param cx number 中心 X
---@param cy number 中心 Y
---@param radius number 半径
---@param r number 红色 0~1
---@param g number 绿色 0~1
---@param b number 蓝色 0~1
---@param params table|nil { layers, wobble }
function PainterlyRenderer.WatercolorBlob(vg, cx, cy, radius, r, g, b, params)
    params = params or {}
    local layers = params.layers or 5
    local wobble = params.wobble or 0.3

    for i = layers, 1, -1 do
        local layerRadius = radius * (i / layers)
        local alpha = 0.08 + 0.04 * (layers - i)

        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + layerRadius, cy)

        local segments = 16
        for s = 1, segments do
            local angle = (s / segments) * math.pi * 2
            local wobbleR = layerRadius * (1 + (math.random() - 0.5) * wobble)
            local px = cx + math.cos(angle) * wobbleR
            local py = cy + math.sin(angle) * wobbleR

            local nextAngle = ((s + 0.5) / segments) * math.pi * 2
            local ctrlR = layerRadius * (1 + (math.random() - 0.5) * wobble * 0.5)
            local cpx = cx + math.cos(nextAngle) * ctrlR
            local cpy = cy + math.sin(nextAngle) * ctrlR

            nvgQuadTo(vg, cpx, cpy, px, py)
        end

        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBAf(r, g, b, alpha))
        nvgFill(vg)
    end
end

----------------------------------------------------------------
-- 3. 素描线条
----------------------------------------------------------------

--- 交叉排线（Cross-Hatching）
---@param vg userdata
---@param x number 区域 X
---@param y number 区域 Y
---@param w number 区域宽度
---@param h number 区域高度
---@param darkness number 暗度 0~1（控制线条密度）
---@param params table|nil { lineWidth, wobble, angle }
function PainterlyRenderer.SketchHatching(vg, x, y, w, h, darkness, params)
    params = params or {}
    local lineWidth = params.lineWidth or 1.0
    local wobbleAmt = params.wobble or 2.0
    local baseAngle = params.angle or (math.pi / 4)

    local spacing = math.max(3, 20 * (1 - darkness))
    local diagonal = math.sqrt(w * w + h * h)

    nvgSave(vg)
    nvgTranslate(vg, x + w * 0.5, y + h * 0.5)
    nvgRotate(vg, baseAngle)

    -- 裁剪区域（近似）
    nvgStrokeColor(vg, nvgRGBAf(0.1, 0.1, 0.1, 0.3 + darkness * 0.5))
    nvgStrokeWidth(vg, lineWidth)

    local half = diagonal * 0.5
    local pos = -half
    while pos < half do
        nvgBeginPath(vg)
        local startX = -half
        local startY = pos + (math.random() - 0.5) * wobbleAmt
        nvgMoveTo(vg, startX, startY)

        local step = 10
        local cx = startX + step
        while cx < half do
            local cy = pos + (math.random() - 0.5) * wobbleAmt
            nvgLineTo(vg, cx, cy)
            cx = cx + step
        end

        nvgStroke(vg)
        pos = pos + spacing
    end

    nvgRestore(vg)
end

----------------------------------------------------------------
-- 4. 多层风格渲染管线
----------------------------------------------------------------

--- 应用绘画风格到矩形区域
---@param vg userdata
---@param style string "oil_painting"|"watercolor"|"sketch"
---@param x number
---@param y number
---@param w number
---@param h number
---@param baseColors table { {r,g,b}, ... } 基础颜色列表
---@param params table|nil 风格参数
function PainterlyRenderer.ApplyStyle(vg, style, x, y, w, h, baseColors, params)
    params = params or {}

    if style == "oil_painting" then
        -- 第一层：大笔触背景
        local bg = baseColors[1] or { 0.8, 0.7, 0.6 }
        PainterlyRenderer.OilPaintFill(vg, x, y, w, h, bg[1], bg[2], bg[3], {
            brushSize = (params.brushSize or 12) * 2,
            density = math.floor((params.density or 200) * 0.5),
            variation = (params.variation or 0.15) * 1.5,
        })

        -- 第二层：中等笔触细节
        for i = 2, math.min(#baseColors, 5) do
            local c = baseColors[i]
            local regionX = x + math.random() * w * 0.6
            local regionY = y + math.random() * h * 0.6
            PainterlyRenderer.OilPaintFill(vg, regionX, regionY, w * 0.4, h * 0.4,
                c[1], c[2], c[3], {
                    brushSize = params.brushSize or 12,
                    density = math.floor((params.density or 200) * 0.3),
                    variation = params.variation or 0.15,
                })
        end

        -- 第三层：小笔触高光
        PainterlyRenderer.OilPaintFill(vg, x, y, w, h, 1, 1, 0.9, {
            brushSize = (params.brushSize or 12) * 0.5,
            density = math.floor((params.density or 200) * 0.15),
            variation = 0.05,
        })

    elseif style == "watercolor" then
        -- 多个水彩色斑
        local blobCount = params.blobs or 8
        for i = 1, blobCount do
            local c = baseColors[((i - 1) % #baseColors) + 1]
            local cx = x + math.random() * w
            local cy = y + math.random() * h
            local r = math.min(w, h) * (0.2 + math.random() * 0.4)
            PainterlyRenderer.WatercolorBlob(vg, cx, cy, r, c[1], c[2], c[3], {
                layers = params.layers or 5,
                wobble = params.wobble or 0.3,
            })
        end

    elseif style == "sketch" then
        -- 背景
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillColor(vg, nvgRGBf(0.95, 0.93, 0.88))
        nvgFill(vg)

        -- 排线层
        PainterlyRenderer.SketchHatching(vg, x, y, w, h, params.darkness or 0.5, {
            angle = math.pi / 4,
            wobble = params.wobble or 2.0,
        })
        -- 交叉排线
        if (params.darkness or 0.5) > 0.3 then
            PainterlyRenderer.SketchHatching(vg, x, y, w, h, (params.darkness or 0.5) * 0.7, {
                angle = -math.pi / 4,
                wobble = params.wobble or 2.0,
            })
        end
    end
end

return PainterlyRenderer
```

---

## 模块 4: ConsistencyScorer

> 视觉一致性评分，对应 NST 中的损失函数概念。

```lua
-- scripts/NeuralTexture/ConsistencyScorer.lua
-- 视觉一致性评分模块

local ColorStatistics = require "scripts.NeuralTexture.ColorStatistics"
local ConsistencyScorer = {}

----------------------------------------------------------------
-- 1. 调色板距离（CIE76 ΔE）
----------------------------------------------------------------

--- 计算两个调色板之间的平均色差
---@param palette1 table { {r,g,b}, ... }
---@param palette2 table { {r,g,b}, ... }
---@return number 平均 ΔE（越小越一致）
function ConsistencyScorer.PaletteDistance(palette1, palette2)
    local totalDE = 0
    local count = 0

    for i = 1, #palette1 do
        local L1, a1, b1 = ColorStatistics.RGBtoLab(
            palette1[i][1], palette1[i][2], palette1[i][3])

        local bestDE = math.huge
        for j = 1, #palette2 do
            local L2, a2, b2 = ColorStatistics.RGBtoLab(
                palette2[j][1], palette2[j][2], palette2[j][3])

            local de = math.sqrt((L1 - L2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
            if de < bestDE then bestDE = de end
        end

        totalDE = totalDE + bestDE
        count = count + 1
    end

    return (count > 0) and (totalDE / count) or 0
end

----------------------------------------------------------------
-- 2. 亮度一致性
----------------------------------------------------------------

--- 评估一组颜色的亮度一致性
---@param colors table { {r,g,b}, ... }
---@return number 0~1（1=完全一致）
function ConsistencyScorer.BrightnessConsistency(colors)
    if #colors < 2 then return 1.0 end

    local luminances = {}
    for i = 1, #colors do
        local c = colors[i]
        luminances[i] = 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]
    end

    local sum = 0
    for i = 1, #luminances do sum = sum + luminances[i] end
    local mean = sum / #luminances

    local variance = 0
    for i = 1, #luminances do
        variance = variance + (luminances[i] - mean) ^ 2
    end
    variance = variance / #luminances

    -- 标准差归一化到 0~1 的一致性分数
    local stddev = math.sqrt(variance)
    return math.max(0, 1 - stddev * 4)
end

----------------------------------------------------------------
-- 3. 饱和度一致性
----------------------------------------------------------------

--- 评估饱和度一致性
---@param colors table { {r,g,b}, ... }
---@return number 0~1
function ConsistencyScorer.SaturationConsistency(colors)
    if #colors < 2 then return 1.0 end

    local sats = {}
    for i = 1, #colors do
        local _, s, _ = ColorStatistics.RGBtoHSV(
            colors[i][1], colors[i][2], colors[i][3])
        sats[i] = s
    end

    local sum = 0
    for i = 1, #sats do sum = sum + sats[i] end
    local mean = sum / #sats

    local variance = 0
    for i = 1, #sats do
        variance = variance + (sats[i] - mean) ^ 2
    end
    variance = variance / #sats

    local stddev = math.sqrt(variance)
    return math.max(0, 1 - stddev * 4)
end

----------------------------------------------------------------
-- 4. 综合评分
----------------------------------------------------------------

--- 计算综合一致性分数
---@param palette1 table
---@param palette2 table
---@param weights table|nil { palette, brightness, saturation }
---@return number 0~100 综合分
---@return table 详细分数
function ConsistencyScorer.Score(palette1, palette2, weights)
    weights = weights or { palette = 0.5, brightness = 0.3, saturation = 0.2 }

    local paletteDE = ConsistencyScorer.PaletteDistance(palette1, palette2)
    -- ΔE → 0~1 分数（ΔE=0 → 1.0, ΔE>=30 → 0.0）
    local paletteScore = math.max(0, 1 - paletteDE / 30)

    local allColors = {}
    for _, c in ipairs(palette1) do allColors[#allColors + 1] = c end
    for _, c in ipairs(palette2) do allColors[#allColors + 1] = c end

    local brightScore = ConsistencyScorer.BrightnessConsistency(allColors)
    local satScore = ConsistencyScorer.SaturationConsistency(allColors)

    local composite = (
        weights.palette * paletteScore +
        weights.brightness * brightScore +
        weights.saturation * satScore
    ) * 100

    return composite, {
        palette = paletteScore * 100,
        brightness = brightScore * 100,
        saturation = satScore * 100,
        deltaE = paletteDE,
    }
end

----------------------------------------------------------------
-- 5. 批量一致性矩阵
----------------------------------------------------------------

--- 对多组调色板计算两两一致性
---@param palettes table { palette1, palette2, ... }
---@return table 矩阵 scores[i][j], number 平均分
function ConsistencyScorer.BatchScore(palettes)
    local n = #palettes
    local scores = {}
    local total = 0
    local count = 0

    for i = 1, n do
        scores[i] = {}
        for j = 1, n do
            if i == j then
                scores[i][j] = 100
            elseif j > i then
                local s = ConsistencyScorer.Score(palettes[i], palettes[j])
                scores[i][j] = s
                total = total + s
                count = count + 1
            end
        end
    end

    -- 填充对称部分
    for i = 1, n do
        for j = 1, i - 1 do
            scores[i][j] = scores[j][i]
        end
    end

    local avg = (count > 0) and (total / count) or 100
    return scores, avg
end

return ConsistencyScorer
```

---

## 模块 5: ParameterOptimizer

> 无梯度参数优化，对应 NST 中的迭代优化概念。

```lua
-- scripts/NeuralTexture/ParameterOptimizer.lua
-- 参数优化模块（无梯度方法）

local ParameterOptimizer = {}

----------------------------------------------------------------
-- 1. 随机搜索 + 局部精炼
----------------------------------------------------------------

--- 优化参数以最大化评分函数
---@param scoreFunc function(params) -> number (越高越好)
---@param ranges table { { name, min, max }, ... }
---@param opts table|nil { globalSamples, localSteps, localRadius, seed }
---@return table 最优参数 { name = value, ... }
---@return number 最优分数
function ParameterOptimizer.Optimize(scoreFunc, ranges, opts)
    opts = opts or {}
    local globalSamples = opts.globalSamples or 50
    local localSteps = opts.localSteps or 30
    local localRadius = opts.localRadius or 0.1
    local seed = opts.seed or os.time()

    math.randomseed(seed)

    local bestParams = {}
    local bestScore = -math.huge

    -- 第一阶段：全局随机搜索
    for _ = 1, globalSamples do
        local candidate = {}
        for _, r in ipairs(ranges) do
            candidate[r[1]] = r[2] + math.random() * (r[3] - r[2])
        end

        local score = scoreFunc(candidate)
        if score > bestScore then
            bestScore = score
            bestParams = candidate
        end
    end

    -- 第二阶段：局部精炼
    for step = 1, localSteps do
        local radius = localRadius * (1 - step / localSteps) -- 逐步缩小
        local candidate = {}

        for _, r in ipairs(ranges) do
            local range = r[3] - r[2]
            local delta = (math.random() - 0.5) * 2 * radius * range
            local val = bestParams[r[1]] + delta
            candidate[r[1]] = math.max(r[2], math.min(r[3], val))
        end

        local score = scoreFunc(candidate)
        if score > bestScore then
            bestScore = score
            bestParams = candidate
        end
    end

    return bestParams, bestScore
end

----------------------------------------------------------------
-- 2. 模拟退火
----------------------------------------------------------------

--- 模拟退火优化
---@param scoreFunc function(params) -> number
---@param ranges table { { name, min, max }, ... }
---@param opts table|nil { steps, tempStart, tempEnd, seed }
---@return table 最优参数
---@return number 最优分数
function ParameterOptimizer.SimulatedAnnealing(scoreFunc, ranges, opts)
    opts = opts or {}
    local steps = opts.steps or 100
    local tempStart = opts.tempStart or 1.0
    local tempEnd = opts.tempEnd or 0.01
    local seed = opts.seed or os.time()

    math.randomseed(seed)

    -- 初始化
    local current = {}
    for _, r in ipairs(ranges) do
        current[r[1]] = r[2] + math.random() * (r[3] - r[2])
    end

    local currentScore = scoreFunc(current)
    local bestParams = {}
    for k, v in pairs(current) do bestParams[k] = v end
    local bestScore = currentScore

    -- 退火循环
    for step = 1, steps do
        local t = step / steps
        local temp = tempStart * (1 - t) + tempEnd * t

        -- 生成邻域解
        local neighbor = {}
        for _, r in ipairs(ranges) do
            local range = r[3] - r[2]
            local delta = (math.random() - 0.5) * 2 * temp * range
            local val = current[r[1]] + delta
            neighbor[r[1]] = math.max(r[2], math.min(r[3], val))
        end

        local neighborScore = scoreFunc(neighbor)
        local diff = neighborScore - currentScore

        -- Metropolis 准则
        if diff > 0 or math.random() < math.exp(diff / (temp + 1e-10)) then
            current = neighbor
            currentScore = neighborScore

            if currentScore > bestScore then
                bestScore = currentScore
                for k, v in pairs(current) do bestParams[k] = v end
            end
        end
    end

    return bestParams, bestScore
end

return ParameterOptimizer
```

---

## 项目集成示例

将所有模块整合到一个游戏项目中：

```lua
-- scripts/main.lua
-- 入口文件：演示 neural-texture-synthesis 各模块

require "LuaScripts/Utilities/Sample"

local ColorStatistics   = require "scripts.NeuralTexture.ColorStatistics"
local ProceduralTexture = require "scripts.NeuralTexture.ProceduralTexture"
local PainterlyRenderer = require "scripts.NeuralTexture.PainterlyRenderer"
local ConsistencyScorer = require "scripts.NeuralTexture.ConsistencyScorer"
local ParameterOptimizer = require "scripts.NeuralTexture.ParameterOptimizer"

local vg = nil

function Start()
    SampleStart()

    -- 创建 NanoVG 上下文
    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")

    log:Write(LOG_INFO, "NeuralTexture demo started")
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local lw, lh = w / dpr, h / dpr

    nvgBeginFrame(vg, lw, lh, dpr)

    -- 绘制程序化纹理预览
    ProceduralTexture.PreviewNVG(vg, 10, 10, 200, 200, "marble", { scale = 0.5 })
    ProceduralTexture.PreviewNVG(vg, 220, 10, 200, 200, "wood", { scale = 0.3 })

    -- 绘制油画风格区域
    local palette = ColorStatistics.HarmonyScheme(210, 0.6, 0.8, "triadic")
    PainterlyRenderer.ApplyStyle(vg, "oil_painting", 10, 220, 200, 200, palette)

    -- 绘制水彩区域
    PainterlyRenderer.ApplyStyle(vg, "watercolor", 220, 220, 200, 200, palette, {
        blobs = 12, layers = 6
    })

    -- 显示一致性分数
    local score = ConsistencyScorer.Score(palette, { {0.9,0.3,0.1}, {0.2,0.5,0.8} })
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBf(1, 1, 1))
    nvgText(vg, 10, 440, string.format("Consistency: %.1f/100", score))

    nvgEndFrame(vg)
end

function Stop()
    if vg then nvgDelete(vg) end
end
```

**构建步骤**：编写完代码后，必须调用 UrhoX MCP `build` 工具进行构建。

---

*本文档提供可直接复制使用的完整 Lua 代码实现。*
*所有代码遵循 UrhoX 引擎规范，存放于 scripts/ 目录。*
