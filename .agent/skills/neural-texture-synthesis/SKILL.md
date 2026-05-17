---
name: neural-texture-synthesis
description: |
  Neural Style Transfer 算法原理的 Lua 原生实现工具集，
  灵感源自 walid0925/AI_Artistry（Gatys et al. 神经风格迁移论文实现）。
  将 VGG 多层特征提取、Gram 矩阵纹理统计、三分量损失函数、迭代优化等核心算法
  映射为 UrhoX Lua 游戏开发中可直接调用的程序化工具模块。

  提供五大核心模块：
  1. ColorStatistics — 颜色统计分析与跨图像颜色迁移（对应 NST 的 Content/Style 分离）
  2. ProceduralTexture — 基于噪声函数与统计模型的程序化纹理生成（对应 Gram 矩阵的纹理统计建模）
  3. PainterlyRenderer — NanoVG 实时艺术化渲染效果（对应多层风格特征的视觉表达）
  4. ConsistencyScorer — 多维度视觉一致性评分（对应损失函数的误差度量机制）
  5. ParameterOptimizer — 无梯度迭代优化器（对应 NST 的迭代梯度下降优化流程）

  与 art-style-transfer 的区别：
  - art-style-transfer = MCP 图像工具的 prompt 工程工作流（黑箱调用 AI）
  - neural-texture-synthesis = NST 数学原理的 Lua 原生代码实现（白箱算法工具）
  两者互补：本 Skill 提供算法级的理解和程序化控制，art-style-transfer 提供 AI 驱动的端到端迁移。

  Use when: users need to (1) 用 Lua 代码实现程序化纹理生成（噪声函数、分形纹理、棋盘格等），
  (2) 在游戏运行时进行颜色风格迁移（如白天→黑夜色调变换），
  (3) 用 NanoVG 实现实时艺术化渲染效果（水彩、油画笔触、素描线条），
  (4) 对多个游戏素材进行视觉一致性评分和质量检测，
  (5) 用迭代优化方法自动调参（找最佳颜色配置、动画参数等），
  (6) 理解 Neural Style Transfer 的数学原理并将其应用于游戏系统，
  (7) 生成可平铺的程序化纹理用于 3D 模型表面，
  (8) 实现调色板提取、颜色和谐化、色彩空间转换等颜色工具。

  MUST trigger when:
    - 用户说"程序化纹理"或"procedural texture"
    - 用户需要 Lua 原生的颜色分析/迁移工具
    - 用户想用 NanoVG 做艺术化渲染效果
    - 用户说"迭代优化"或需要自动调参工具
    - 用户需要纹理生成算法（Perlin噪声、Worley等）

  trigger-keywords:
    - 程序化纹理
    - procedural texture
    - 噪声纹理
    - Perlin noise
    - 颜色迁移
    - color transfer
    - 调色板
    - palette
    - 艺术化渲染
    - painterly
    - 一致性评分
    - 迭代优化
    - 自动调参
    - Gram matrix
    - 纹理合成
    - texture synthesis

version: "1.0.0"
metadata:
  author: "UrhoX-Skill"
  inspirations: ["walid0925/AI_Artistry", "Gatys et al. 2015"]
  tags: ["procedural", "texture", "color", "nanovg", "optimization", "algorithm"]
---

# Neural Texture Synthesis — NST 算法原理的 Lua 原生实现

> 将 Neural Style Transfer 的数学内核（Gram 矩阵、损失函数、迭代优化、多层特征）
> 转化为 UrhoX Lua 游戏开发中的程序化工具。

---

## 1. 理论基础：从 AI_Artistry 到 Lua 原生工具

### 1.1 Neural Style Transfer 核心算法回顾

AI_Artistry（walid0925）实现了 Gatys et al. 2015 年论文 "A Neural Algorithm of Artistic Style" 的核心算法：

```
输入：内容图 C、风格图 S
输出：合成图 G（既保留 C 的内容结构，又具有 S 的风格纹理）

算法核心：
1. VGG19 特征提取 → 不同层捕获不同尺度的特征
   - 浅层（block1-2）: 边缘、颜色 → 局部纹理特征
   - 中层（block3-4）: 形状、图案 → 中尺度结构
   - 深层（block5）:   语义内容 → 高层内容表达

2. Gram 矩阵 → 风格的数学表达
   G_ij = Σ_k F_ik × F_jk
   Gram 矩阵捕获特征通道之间的相关性，即"纹理统计信息"

3. 三分量损失函数 → 优化目标
   L_total = α·L_content + β·L_style + γ·L_tv
   - L_content = ||F_content(C) - F_content(G)||²       # 内容保持
   - L_style   = Σ_l ||Gram_l(S) - Gram_l(G)||²         # 风格匹配
   - L_tv      = Σ_ij |G_{i+1,j} - G_{i,j}| + |G_{i,j+1} - G_{i,j}|  # 平滑度

4. 迭代优化 → 梯度下降直接更新像素
   for epoch = 1, N do
       loss = compute_total_loss(G, C, S)
       G = G - lr * gradient(loss, G)
   end
```

### 1.2 算法概念到 Lua 模块的映射

我们将 NST 的五个核心概念分别映射为独立的 Lua 工具模块：

| NST 概念 | 原始实现 | Lua 模块 | 游戏应用 |
|---------|---------|---------|---------|
| Content/Style 分离 | VGG 深/浅层输出 | **ColorStatistics** | 颜色分析、调色板提取、色调迁移 |
| Gram 矩阵 | 通道相关性矩阵 | **ProceduralTexture** | 纹理统计建模、噪声纹理生成 |
| 多层风格特征 | block1~block5 | **PainterlyRenderer** | NanoVG 实时艺术化效果 |
| 损失函数 | L_content + L_style + L_tv | **ConsistencyScorer** | 素材一致性评分、质量检测 |
| 迭代优化 | 梯度下降 | **ParameterOptimizer** | 无梯度自动调参、参数搜索 |

### 1.3 设计哲学

```
art-style-transfer（已有 Skill）
  → "用 AI 工具做风格迁移"（prompt 工程 + MCP 工具调用）
  → 黑箱：不关心 AI 内部如何实现

neural-texture-synthesis（本 Skill）
  → "把 NST 的数学原理变成 Lua 代码"（算法实现 + 程序化工具）
  → 白箱：每一步都是可控的 Lua 代码，可调试、可定制
```

两者互补，不冲突：
- 需要 AI 驱动的高质量风格迁移 → 使用 art-style-transfer
- 需要程序化、可控、实时的视觉工具 → 使用 neural-texture-synthesis

---

## 2. 模块 1: ColorStatistics — 颜色统计与迁移

> 对应 NST 的 Content/Style 分离：通过颜色统计信息实现风格（色调）与内容（结构）的分离和重组。

### 2.1 核心概念

颜色统计是 NST 中最直接可用的概念：
- **内容** = 图像的亮度/结构信息（L 通道）
- **风格** = 图像的色彩分布（a/b 通道或 HSV 中的 H/S）

通过统计匹配（均值/标准差对齐），可以将一张图的色调"迁移"到另一张图上。

### 2.2 颜色空间工具

```lua
-- ============================================================
-- ColorStatistics 模块
-- 文件：scripts/NeuralTexture/ColorStatistics.lua
-- ============================================================
local ColorStatistics = {}

--- RGB → HSV 转换
---@param r number 红色 [0,1]
---@param g number 绿色 [0,1]
---@param b number 蓝色 [0,1]
---@return number h 色相 [0,360)
---@return number s 饱和度 [0,1]
---@return number v 明度 [0,1]
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

    return h, s, v
end

--- HSV → RGB 转换
---@param h number 色相 [0,360)
---@param s number 饱和度 [0,1]
---@param v number 明度 [0,1]
---@return number r, number g, number b 各通道 [0,1]
function ColorStatistics.HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b

    if     h < 60  then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else                r, g, b = c, 0, x
    end

    return r + m, g + m, b + m
end

--- RGB → Lab (简化版，使用 D65 白点)
---@param r number [0,1]
---@param g number [0,1]
---@param b number [0,1]
---@return number L [0,100], number a [-128,127], number lab_b [-128,127]
function ColorStatistics.RGBtoLab(r, g, b)
    -- 线性化
    local function linearize(c)
        return (c > 0.04045) and ((c + 0.055) / 1.055) ^ 2.4 or (c / 12.92)
    end
    r, g, b = linearize(r), linearize(g), linearize(b)

    -- sRGB → XYZ (D65)
    local x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    local y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    local z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

    -- XYZ → Lab
    local function f(t)
        return (t > 0.008856) and t ^ (1/3) or (7.787 * t + 16/116)
    end
    x, y, z = f(x / 0.95047), f(y / 1.00000), f(z / 1.08883)

    return 116 * y - 16, 500 * (x - y), 200 * (y - z)
end

return ColorStatistics
```

### 2.3 调色板提取（K-Means 简化版）

```lua
--- 从颜色样本中提取 K 个主色调
---@param samples table 颜色数组 {{r,g,b}, ...}
---@param K number 聚类数（默认 5）
---@param iterations number 迭代次数（默认 20）
---@return table 主色调数组 {{r,g,b,weight}, ...}
function ColorStatistics.ExtractPalette(samples, K, iterations)
    K = K or 5
    iterations = iterations or 20
    if #samples == 0 then return {} end

    -- 初始化：均匀间隔选取种子
    local centroids = {}
    for i = 1, K do
        local idx = math.floor((i - 1) * #samples / K) + 1
        idx = math.min(idx, #samples)
        centroids[i] = { samples[idx][1], samples[idx][2], samples[idx][3] }
    end

    local assignments = {}

    for iter = 1, iterations do
        -- 分配阶段
        for i = 1, #samples do
            local minDist = math.huge
            local bestK = 1
            for k = 1, K do
                local dr = samples[i][1] - centroids[k][1]
                local dg = samples[i][2] - centroids[k][2]
                local db = samples[i][3] - centroids[k][3]
                local dist = dr*dr + dg*dg + db*db
                if dist < minDist then
                    minDist = dist
                    bestK = k
                end
            end
            assignments[i] = bestK
        end

        -- 更新阶段
        for k = 1, K do
            local sumR, sumG, sumB, count = 0, 0, 0, 0
            for i = 1, #samples do
                if assignments[i] == k then
                    sumR = sumR + samples[i][1]
                    sumG = sumG + samples[i][2]
                    sumB = sumB + samples[i][3]
                    count = count + 1
                end
            end
            if count > 0 then
                centroids[k] = { sumR/count, sumG/count, sumB/count }
            end
        end
    end

    -- 计算权重
    local result = {}
    for k = 1, K do
        local count = 0
        for i = 1, #samples do
            if assignments[i] == k then count = count + 1 end
        end
        result[k] = {
            r = centroids[k][1],
            g = centroids[k][2],
            b = centroids[k][3],
            weight = count / #samples,
        }
    end

    -- 按权重降序排列
    table.sort(result, function(a, b) return a.weight > b.weight end)
    return result
end
```

### 2.4 颜色迁移（Reinhard 方法）

这是 NST 中 Style Transfer 最直接的简化版本——在 Lab 颜色空间中做统计对齐：

```lua
--- Reinhard 颜色迁移：将 source 的色调统计迁移到 target 上
--- 原理：在 Lab 空间中，将 target 的每个通道均值/标准差对齐到 source
---@param targetColors table 目标颜色数组 {{r,g,b}, ...}
---@param sourceStats table 源统计信息 {meanL,meanA,meanB,stdL,stdA,stdB}
---@param targetStats table 目标统计信息 {meanL,meanA,meanB,stdL,stdA,stdB}
---@return table 迁移后的颜色数组
function ColorStatistics.TransferColors(targetColors, sourceStats, targetStats)
    local result = {}
    for i = 1, #targetColors do
        local L, a, lab_b = ColorStatistics.RGBtoLab(
            targetColors[i][1], targetColors[i][2], targetColors[i][3]
        )

        -- 统计对齐：target → 零均值 → 缩放 → source 均值
        if targetStats.stdL > 0.001 then
            L = (L - targetStats.meanL) * (sourceStats.stdL / targetStats.stdL) + sourceStats.meanL
        end
        if targetStats.stdA > 0.001 then
            a = (a - targetStats.meanA) * (sourceStats.stdA / targetStats.stdA) + sourceStats.meanA
        end
        if targetStats.stdB > 0.001 then
            lab_b = (lab_b - targetStats.meanB) * (sourceStats.stdB / targetStats.stdB) + sourceStats.meanB
        end

        -- 裁剪到有效范围
        L = math.max(0, math.min(100, L))
        a = math.max(-128, math.min(127, a))
        lab_b = math.max(-128, math.min(127, lab_b))

        -- Lab → RGB (简化逆变换)
        local fy = (L + 16) / 116
        local fx = a / 500 + fy
        local fz = fy - lab_b / 200

        local function invF(t)
            return (t > 0.206897) and t*t*t or ((t - 16/116) / 7.787)
        end
        local x = invF(fx) * 0.95047
        local y = invF(fy) * 1.00000
        local z = invF(fz) * 1.08883

        -- XYZ → sRGB
        local rr =  3.2404542*x - 1.5371385*y - 0.4985314*z
        local gg = -0.9692660*x + 1.8760108*y + 0.0415560*z
        local bb =  0.0556434*x - 0.2040259*y + 1.0572252*z

        local function gammaCorrect(c)
            c = math.max(0, math.min(1, c))
            return (c > 0.0031308) and (1.055 * c^(1/2.4) - 0.055) or (12.92 * c)
        end

        result[i] = { gammaCorrect(rr), gammaCorrect(gg), gammaCorrect(bb) }
    end
    return result
end

--- 计算颜色数组的 Lab 统计信息
---@param colors table 颜色数组 {{r,g,b}, ...}
---@return table stats {meanL, meanA, meanB, stdL, stdA, stdB}
function ColorStatistics.ComputeLabStats(colors)
    local sumL, sumA, sumB = 0, 0, 0
    local n = #colors
    local Ls, As, Bs = {}, {}, {}

    for i = 1, n do
        local L, a, b = ColorStatistics.RGBtoLab(colors[i][1], colors[i][2], colors[i][3])
        Ls[i], As[i], Bs[i] = L, a, b
        sumL = sumL + L
        sumA = sumA + a
        sumB = sumB + b
    end

    local meanL, meanA, meanB = sumL/n, sumA/n, sumB/n
    local varL, varA, varB = 0, 0, 0
    for i = 1, n do
        varL = varL + (Ls[i] - meanL)^2
        varA = varA + (As[i] - meanA)^2
        varB = varB + (Bs[i] - meanB)^2
    end

    return {
        meanL = meanL, meanA = meanA, meanB = meanB,
        stdL = math.sqrt(varL / n),
        stdA = math.sqrt(varA / n),
        stdB = math.sqrt(varB / n),
    }
end
```

### 2.5 颜色和谐化

```lua
--- 颜色和谐化：根据色彩理论调整调色板
---@param baseHue number 基础色相 [0,360)
---@param scheme string 和谐方案："complementary"|"triadic"|"analogous"|"split"
---@return table 和谐色相数组
function ColorStatistics.HarmonyScheme(baseHue, scheme)
    local hues = { baseHue }
    if scheme == "complementary" then
        hues[2] = (baseHue + 180) % 360
    elseif scheme == "triadic" then
        hues[2] = (baseHue + 120) % 360
        hues[3] = (baseHue + 240) % 360
    elseif scheme == "analogous" then
        hues[2] = (baseHue + 30) % 360
        hues[3] = (baseHue - 30) % 360
    elseif scheme == "split" then
        hues[2] = (baseHue + 150) % 360
        hues[3] = (baseHue + 210) % 360
    end
    return hues
end
```

### 2.6 游戏应用示例

```lua
-- ============================================================
-- 示例：白天→黄昏色调迁移
-- 文件：scripts/main.lua
-- ============================================================
local CS = require "NeuralTexture.ColorStatistics"

-- 定义白天和黄昏的颜色统计
local dayStats = {
    meanL = 70, meanA = -5, meanB = 10,
    stdL = 15, stdA = 8, stdB = 12,
}
local duskStats = {
    meanL = 45, meanA = 15, meanB = 30,
    stdL = 20, stdA = 12, stdB = 18,
}

-- 在 Update 中根据时间插值
local timeOfDay = 0.0  -- 0=白天, 1=黄昏

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    timeOfDay = math.min(1.0, timeOfDay + dt * 0.05)

    -- 插值统计参数
    local currentStats = {
        meanL = Lerp(dayStats.meanL, duskStats.meanL, timeOfDay),
        meanA = Lerp(dayStats.meanA, duskStats.meanA, timeOfDay),
        meanB = Lerp(dayStats.meanB, duskStats.meanB, timeOfDay),
        stdL  = Lerp(dayStats.stdL,  duskStats.stdL,  timeOfDay),
        stdA  = Lerp(dayStats.stdA,  duskStats.stdA,  timeOfDay),
        stdB  = Lerp(dayStats.stdB,  duskStats.stdB,  timeOfDay),
    }

    -- 应用到场景 Zone 的雾色/环境色
    local fogR, fogG, fogB = CS.HSVtoRGB(
        Lerp(200, 30, timeOfDay),   -- 蓝→橙
        Lerp(0.3, 0.6, timeOfDay),  -- 饱和度增加
        Lerp(0.8, 0.5, timeOfDay)   -- 明度降低
    )
    zone.fogColor = Color(fogR, fogG, fogB)
end
```

---

## 3. 模块 2: ProceduralTexture — 程序化纹理生成

> 对应 NST 的 Gram 矩阵：Gram 矩阵本质上捕获了"纹理统计信息"（通道间的相关性模式）。
> 程序化纹理生成器使用数学噪声函数生成具有特定统计特征的纹理。

### 3.1 核心概念

NST 中的 Gram 矩阵 `G_ij = Σ_k F_ik × F_jk` 编码了纹理的**统计特性**：
- 哪些特征倾向于同时出现（正相关）
- 特征出现的频率和强度分布

程序化纹理生成器通过**噪声函数**（Perlin、Worley、Value）的叠加和变换，
生成具有可控统计特性的纹理。这是 Gram 矩阵方法在游戏中的实用替代。

### 3.2 Perlin 噪声实现

```lua
-- ============================================================
-- ProceduralTexture 模块
-- 文件：scripts/NeuralTexture/ProceduralTexture.lua
-- ============================================================
local ProceduralTexture = {}

-- 排列表（用于哈希）
local perm = {}
do
    local p = {151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,
               140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,
               247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,
               57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,
               74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,
               60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,
               65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,
               200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,
               52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,
               207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,
               119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,
               129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,
               218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,
               81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,
               184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,
               222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180}
    for i = 0, 255 do perm[i] = p[i + 1] end
    for i = 256, 511 do perm[i] = perm[i - 256] end
end

local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end

local function grad(hash, x, y)
    local h = hash & 3
    local u = (h < 2) and x or y
    local v = (h < 2) and y or x
    return ((h & 1) == 0 and u or -u) + ((h & 2) == 0 and v or -v)
end

--- 2D Perlin 噪声
---@param x number
---@param y number
---@return number 噪声值 [-1, 1]
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

    local x1 = Lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u)
    local x2 = Lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u)

    return Lerp(x1, x2, v)
end

--- 分形布朗运动（fBm）— 多层噪声叠加
--- 对应 NST 的多层特征提取：每一层（octave）捕获不同尺度的细节
---@param x number
---@param y number
---@param octaves number 叠加层数（默认 6，类比 VGG 的层数）
---@param lacunarity number 频率缩放因子（默认 2.0）
---@param gain number 振幅衰减因子（默认 0.5）
---@return number 叠加噪声值
function ProceduralTexture.FBM(x, y, octaves, lacunarity, gain)
    octaves = octaves or 6
    lacunarity = lacunarity or 2.0
    gain = gain or 0.5

    local sum = 0
    local amplitude = 1.0
    local frequency = 1.0
    local maxValue = 0

    for i = 1, octaves do
        sum = sum + amplitude * ProceduralTexture.Perlin2D(x * frequency, y * frequency)
        maxValue = maxValue + amplitude
        amplitude = amplitude * gain
        frequency = frequency * lacunarity
    end

    return sum / maxValue
end
```

### 3.3 Worley（细胞）噪声

```lua
--- Worley 噪声（细胞噪声）— 生成蜂窝/石头/龟裂纹理
---@param x number
---@param y number
---@param density number 细胞密度（默认 4）
---@return number 最近距离 [0,1]
---@return number 次近距离 [0,1]
function ProceduralTexture.Worley2D(x, y, density)
    density = density or 4
    x = x * density
    y = y * density
    local cellX = math.floor(x)
    local cellY = math.floor(y)

    local minDist1 = math.huge
    local minDist2 = math.huge

    for dx = -1, 1 do
        for dy = -1, 1 do
            local cx = cellX + dx
            local cy = cellY + dy
            -- 伪随机偏移（哈希）
            local hash = perm[(perm[cx & 255] + (cy & 255)) & 255]
            local px = cx + (hash / 255.0)
            hash = perm[(hash + 1) & 255]
            local py = cy + (hash / 255.0)

            local distX = x - px
            local distY = y - py
            local dist = math.sqrt(distX * distX + distY * distY)

            if dist < minDist1 then
                minDist2 = minDist1
                minDist1 = dist
            elseif dist < minDist2 then
                minDist2 = dist
            end
        end
    end

    return minDist1 / density, minDist2 / density
end
```

### 3.4 纹理合成器

```lua
--- 纹理合成工厂 — 组合多种噪声生成特定类型的纹理
---@param texType string 纹理类型
---@param x number 采样坐标 x [0,1]
---@param y number 采样坐标 y [0,1]
---@param params table 可选参数
---@return number r, number g, number b 颜色值 [0,1]
function ProceduralTexture.Sample(texType, x, y, params)
    params = params or {}

    if texType == "marble" then
        -- 大理石纹理：Perlin 扭曲的正弦条纹
        local scale = params.scale or 5.0
        local turbulence = params.turbulence or 5.0
        local noise = ProceduralTexture.FBM(x * scale, y * scale, 6)
        local pattern = math.sin(x * scale + noise * turbulence)
        local v = (pattern + 1) * 0.5
        local base = params.baseColor or {0.9, 0.9, 0.88}
        local vein = params.veinColor or {0.3, 0.25, 0.2}
        return Lerp(base[1], vein[1], v),
               Lerp(base[2], vein[2], v),
               Lerp(base[3], vein[3], v)

    elseif texType == "wood" then
        -- 木纹纹理：同心环 + 噪声扰动
        local scale = params.scale or 10.0
        local cx, cy = 0.5, 0.5
        local dist = math.sqrt((x - cx)^2 + (y - cy)^2) * scale
        local noise = ProceduralTexture.Perlin2D(x * 8, y * 8) * 0.3
        local ring = math.sin(dist + noise * scale) * 0.5 + 0.5
        local light = params.lightColor or {0.76, 0.60, 0.38}
        local dark  = params.darkColor  or {0.45, 0.30, 0.15}
        return Lerp(light[1], dark[1], ring),
               Lerp(light[2], dark[2], ring),
               Lerp(light[3], dark[3], ring)

    elseif texType == "stone" then
        -- 石头纹理：Worley 噪声 + fBm 细节
        local d1, d2 = ProceduralTexture.Worley2D(x, y, params.density or 6)
        local detail = ProceduralTexture.FBM(x * 20, y * 20, 4) * 0.1
        local v = d2 - d1 + detail
        v = math.max(0, math.min(1, v * 2))
        local base = params.baseColor or {0.6, 0.58, 0.55}
        local crack = params.crackColor or {0.3, 0.28, 0.25}
        return Lerp(base[1], crack[1], v),
               Lerp(base[2], crack[2], v),
               Lerp(base[3], crack[3], v)

    elseif texType == "checkerboard" then
        -- 棋盘格
        local scale = params.scale or 8
        local cx = math.floor(x * scale) % 2
        local cy = math.floor(y * scale) % 2
        if (cx + cy) % 2 == 0 then
            local c = params.color1 or {0.9, 0.9, 0.9}
            return c[1], c[2], c[3]
        else
            local c = params.color2 or {0.2, 0.2, 0.2}
            return c[1], c[2], c[3]
        end

    else -- "noise" 默认
        local v = ProceduralTexture.FBM(x * (params.scale or 8), y * (params.scale or 8))
        v = (v + 1) * 0.5
        return v, v, v
    end
end
```

### 3.5 NanoVG 纹理预览

```lua
--- 在 NanoVG 中预览程序化纹理
---@param vg userdata NanoVG 上下文
---@param x number 绘制起始 x
---@param y number 绘制起始 y
---@param w number 宽度
---@param h number 高度
---@param texType string 纹理类型
---@param params table 纹理参数
---@param resolution number 采样分辨率（默认 64）
function ProceduralTexture.PreviewNVG(vg, x, y, w, h, texType, params, resolution)
    resolution = resolution or 64
    local cellW = w / resolution
    local cellH = h / resolution

    for iy = 0, resolution - 1 do
        for ix = 0, resolution - 1 do
            local u = ix / resolution
            local v = iy / resolution
            local r, g, b = ProceduralTexture.Sample(texType, u, v, params)

            nvgBeginPath(vg)
            nvgRect(vg, x + ix * cellW, y + iy * cellH, cellW + 0.5, cellH + 0.5)
            nvgFillColor(vg, nvgRGBf(r, g, b))
            nvgFill(vg)
        end
    end
end
```

### 3.6 生成纹理图片并保存

```lua
--- 生成程序化纹理并通过 MCP generate_image 工具保存为文件
--- 用途：生成纹理资源文件供 3D 模型使用
---@param texType string 纹理类型
---@param params table 参数
---@return string prompt 用于 generate_image 的描述
function ProceduralTexture.GeneratePrompt(texType, params)
    params = params or {}
    local prompts = {
        marble = "无缝可平铺的大理石纹理，白色底色带灰褐色纹路，自然石材质感，写实风格，游戏贴图",
        wood   = "无缝可平铺的木纹纹理，温暖棕色调，清晰年轮纹路，自然木材质感，游戏贴图",
        stone  = "无缝可平铺的石头纹理，灰色调，自然裂缝和凹凸，粗糙石材表面，游戏贴图",
        metal  = "无缝可平铺的金属纹理，银灰色调，轻微磨损和划痕，金属光泽，游戏贴图",
        fabric = "无缝可平铺的织物纹理，编织图案，柔软布料质感，自然褶皱，游戏贴图",
    }
    return prompts[texType] or ("无缝可平铺的 " .. texType .. " 纹理，游戏贴图")
end
```

---

## 4. 模块 3: PainterlyRenderer — NanoVG 艺术化渲染

> 对应 NST 的多层风格特征：VGG 不同层捕获从局部笔触（浅层）到全局构图（深层）的风格。
> PainterlyRenderer 通过 NanoVG 绘制不同层次的艺术化效果，模拟这种多尺度风格表达。

### 4.1 核心概念

NST 的风格来自多个网络层的 Gram 矩阵，可以拆解为：
- **Layer 1** (block1_conv1): 颜色分布和微观纹理 → 对应笔触粒子效果
- **Layer 2** (block2_conv1): 小尺度图案重复 → 对应笔触方向和密度
- **Layer 3** (block3_conv1): 中尺度结构 → 对应色块分布
- **Layer 4-5** (block4/5): 全局风格特征 → 对应整体色调和构图氛围

### 4.2 笔触粒子系统

```lua
-- ============================================================
-- PainterlyRenderer 模块
-- 文件：scripts/NeuralTexture/PainterlyRenderer.lua
-- ============================================================
local PainterlyRenderer = {}
local PT = require "NeuralTexture.ProceduralTexture"

--- 油画笔触效果
--- 在指定区域内用随机笔触填充，模拟油画质感
---@param vg userdata NanoVG 上下文
---@param x number 区域起始 x
---@param y number 区域起始 y
---@param w number 区域宽度
---@param h number 区域高度
---@param color table {r, g, b, a} 基础颜色
---@param params table 笔触参数
function PainterlyRenderer.OilPaintFill(vg, x, y, w, h, color, params)
    params = params or {}
    local brushCount = params.brushCount or 80
    local brushSize  = params.brushSize or math.min(w, h) * 0.08
    local variation  = params.colorVariation or 0.1
    local seed       = params.seed or 42

    math.randomseed(seed)

    for i = 1, brushCount do
        local bx = x + math.random() * w
        local by = y + math.random() * h
        local bw = brushSize * (0.5 + math.random() * 1.0)
        local bh = brushSize * (0.3 + math.random() * 0.4)
        local angle = math.random() * math.pi

        -- 颜色变化
        local dr = (math.random() - 0.5) * variation
        local dg = (math.random() - 0.5) * variation
        local db = (math.random() - 0.5) * variation

        nvgSave(vg)
        nvgTranslate(vg, bx, by)
        nvgRotate(vg, angle)

        nvgBeginPath(vg)
        nvgEllipse(vg, 0, 0, bw, bh)

        local cr = math.max(0, math.min(1, color[1] + dr))
        local cg = math.max(0, math.min(1, color[2] + dg))
        local cb = math.max(0, math.min(1, color[3] + db))
        local ca = color[4] or 0.85

        nvgFillColor(vg, nvgRGBAf(cr, cg, cb, ca))
        nvgFill(vg)
        nvgRestore(vg)
    end
end

--- 水彩晕染效果
--- 使用多层半透明渐变圆模拟水彩扩散
---@param vg userdata NanoVG 上下文
---@param cx number 中心 x
---@param cy number 中心 y
---@param radius number 扩散半径
---@param color table {r, g, b} 颜色
---@param params table 参数
function PainterlyRenderer.WatercolorBlob(vg, cx, cy, radius, color, params)
    params = params or {}
    local layers = params.layers or 5
    local wobble = params.wobble or 0.3
    local seed   = params.seed or 42

    math.randomseed(seed)

    for i = 1, layers do
        local t = i / layers
        local r = radius * (1 - t * 0.6)  -- 由大到小
        local alpha = 0.05 + 0.08 * t       -- 由浅到深

        -- 不规则偏移
        local ox = (math.random() - 0.5) * radius * wobble
        local oy = (math.random() - 0.5) * radius * wobble

        nvgBeginPath(vg)
        -- 用多点贝塞尔模拟不规则边缘
        local segments = 8
        for s = 0, segments do
            local angle = (s / segments) * math.pi * 2
            local rr = r * (1 + (math.random() - 0.5) * wobble)
            local px = cx + ox + math.cos(angle) * rr
            local py = cy + oy + math.sin(angle) * rr
            if s == 0 then
                nvgMoveTo(vg, px, py)
            else
                -- 贝塞尔控制点
                local cpAngle = ((s - 0.5) / segments) * math.pi * 2
                local cpR = r * (1 + (math.random() - 0.5) * wobble * 0.5)
                local cpx = cx + ox + math.cos(cpAngle) * cpR
                local cpy = cy + oy + math.sin(cpAngle) * cpR
                nvgQuadTo(vg, cpx, cpy, px, py)
            end
        end
        nvgClosePath(vg)

        -- 径向渐变：中心浓→边缘淡
        local paint = nvgRadialGradient(vg, cx + ox, cy + oy,
            r * 0.1, r,
            nvgRGBAf(color[1], color[2], color[3], alpha),
            nvgRGBAf(color[1], color[2], color[3], 0)
        )
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    end
end

--- 素描线条效果
--- 使用交叉阴影线模拟铅笔素描
---@param vg userdata NanoVG 上下文
---@param x number 区域 x
---@param y number 区域 y
---@param w number 区域宽度
---@param h number 区域高度
---@param darkness number 明暗度 [0,1]（0=空白, 1=密集阴影线）
---@param params table 参数
function PainterlyRenderer.SketchHatching(vg, x, y, w, h, darkness, params)
    params = params or {}
    local spacing  = params.spacing or 4
    local angle1   = params.angle1 or -math.pi / 4  -- 主线方向
    local angle2   = params.angle2 or math.pi / 4   -- 交叉线方向
    local wobble   = params.wobble or 1.5
    local lineColor = params.color or {0.15, 0.12, 0.1}

    local density = math.floor(darkness * 30) -- 线条数量与明暗度成正比
    if density < 1 then return end

    nvgSave(vg)
    nvgScissor(vg, x, y, w, h)
    nvgStrokeColor(vg, nvgRGBAf(lineColor[1], lineColor[2], lineColor[3], 0.4 + darkness * 0.4))
    nvgStrokeWidth(vg, 0.8)

    -- 第一层阴影线
    local function drawLines(angle, count)
        local cx, cy = x + w/2, y + h/2
        local diag = math.sqrt(w*w + h*h)
        for i = 1, count do
            local offset = (i / count - 0.5) * diag
            local cosA = math.cos(angle)
            local sinA = math.sin(angle)

            nvgBeginPath(vg)
            local sx = cx + cosA * (-diag/2) - sinA * offset
            local sy = cy + sinA * (-diag/2) + cosA * offset
            nvgMoveTo(vg, sx, sy)

            -- 手绘抖动
            local steps = 6
            for s = 1, steps do
                local t = s / steps
                local ex = cx + cosA * (diag * (t - 0.5)) - sinA * offset
                local ey = cy + sinA * (diag * (t - 0.5)) + cosA * offset
                ex = ex + (math.random() - 0.5) * wobble
                ey = ey + (math.random() - 0.5) * wobble
                nvgLineTo(vg, ex, ey)
            end
            nvgStroke(vg)
        end
    end

    drawLines(angle1, density)
    if darkness > 0.4 then
        drawLines(angle2, math.floor(density * 0.6))  -- 交叉线密度较低
    end

    nvgResetScissor(vg)
    nvgRestore(vg)
end

return PainterlyRenderer
```

### 4.3 多层渲染管线

将上述效果按 NST 的多层概念组合：

```lua
--- 多层艺术化渲染管线
--- 模拟 NST 多层风格特征的叠加效果
---@param vg userdata NanoVG 上下文
---@param x number 区域 x
---@param y number 区域 y
---@param w number 区域宽度
---@param h number 区域高度
---@param style string 风格名称
---@param params table 参数
function PainterlyRenderer.ApplyStyle(vg, x, y, w, h, style, params)
    params = params or {}

    if style == "oil_painting" then
        -- Layer 1: 底色大笔触
        PainterlyRenderer.OilPaintFill(vg, x, y, w, h,
            params.baseColor or {0.85, 0.8, 0.7},
            { brushCount = 40, brushSize = math.min(w,h) * 0.15, seed = 1 })
        -- Layer 2: 中景色块
        PainterlyRenderer.OilPaintFill(vg, x, y, w, h,
            params.midColor or {0.6, 0.5, 0.3},
            { brushCount = 60, brushSize = math.min(w,h) * 0.08, seed = 2 })
        -- Layer 3: 高光细节
        PainterlyRenderer.OilPaintFill(vg, x + w*0.2, y + h*0.2, w*0.6, h*0.6,
            params.highlightColor or {1.0, 0.95, 0.85},
            { brushCount = 20, brushSize = math.min(w,h) * 0.04, seed = 3 })

    elseif style == "watercolor" then
        -- Layer 1: 湿底层
        PainterlyRenderer.WatercolorBlob(vg, x + w*0.5, y + h*0.5,
            math.min(w,h) * 0.5, params.bgColor or {0.85, 0.9, 0.95}, {layers = 3})
        -- Layer 2: 主色
        PainterlyRenderer.WatercolorBlob(vg, x + w*0.4, y + h*0.4,
            math.min(w,h) * 0.35, params.mainColor or {0.3, 0.5, 0.7}, {layers = 5})
        -- Layer 3: 点缀
        PainterlyRenderer.WatercolorBlob(vg, x + w*0.6, y + h*0.55,
            math.min(w,h) * 0.15, params.accentColor or {0.8, 0.4, 0.3}, {layers = 3})

    elseif style == "sketch" then
        -- Layer 1: 纸张底色
        nvgBeginPath(vg)
        nvgRect(vg, x, y, w, h)
        nvgFillColor(vg, nvgRGBf(0.95, 0.93, 0.88))
        nvgFill(vg)
        -- Layer 2-3: 阴影线
        PainterlyRenderer.SketchHatching(vg, x, y, w, h,
            params.darkness or 0.5)
    end
end
```

---

## 5. 模块 4: ConsistencyScorer — 视觉一致性评分

> 对应 NST 的损失函数：L_content 度量内容差异，L_style 度量风格差异。
> ConsistencyScorer 用类似的"距离度量"思想，评估游戏素材之间的视觉一致性。

### 5.1 核心概念

NST 损失函数的本质是**定义一个数值指标来衡量两个东西有多"相似"或"不同"**。
ConsistencyScorer 将这个思想应用到游戏素材质量管理中：

```
L_total = w1·L_palette + w2·L_brightness + w3·L_saturation + w4·L_contrast

- L_palette:    调色板差异（两组主色调的距离）
- L_brightness: 亮度分布差异
- L_saturation: 饱和度分布差异
- L_contrast:   对比度差异
```

### 5.2 评分工具实现

```lua
-- ============================================================
-- ConsistencyScorer 模块
-- 文件：scripts/NeuralTexture/ConsistencyScorer.lua
-- ============================================================
local ConsistencyScorer = {}
local CS = require "NeuralTexture.ColorStatistics"

--- 计算两个调色板之间的距离
--- 对应 NST 的 L_style（Gram 矩阵距离）
---@param palette1 table 调色板 1 {{r,g,b,weight},...}
---@param palette2 table 调色板 2
---@return number 距离分数 [0, 1]（0=完全一致, 1=完全不同）
function ConsistencyScorer.PaletteDistance(palette1, palette2)
    if #palette1 == 0 or #palette2 == 0 then return 1.0 end

    local totalDist = 0
    local count = math.min(#palette1, #palette2)

    for i = 1, count do
        local L1, a1, b1 = CS.RGBtoLab(palette1[i].r, palette1[i].g, palette1[i].b)
        local L2, a2, b2 = CS.RGBtoLab(palette2[i].r, palette2[i].g, palette2[i].b)

        -- CIE76 色差公式（简化版 ΔE）
        local dE = math.sqrt((L1-L2)^2 + (a1-a2)^2 + (b1-b2)^2)
        totalDist = totalDist + dE
    end

    -- 归一化到 [0,1]，ΔE=100 视为完全不同
    return math.min(1.0, (totalDist / count) / 100.0)
end

--- 计算两组颜色统计的亮度一致性
--- 对应 NST 的 L_content（特征距离）
---@param stats1 table Lab 统计信息
---@param stats2 table Lab 统计信息
---@return number 一致性分数 [0, 1]
function ConsistencyScorer.BrightnessConsistency(stats1, stats2)
    local dMean = math.abs(stats1.meanL - stats2.meanL) / 100.0
    local dStd  = math.abs(stats1.stdL - stats2.stdL) / 50.0
    return math.min(1.0, (dMean + dStd) / 2)
end

--- 计算饱和度一致性
---@param colors1 table 颜色数组
---@param colors2 table 颜色数组
---@return number 一致性分数 [0, 1]
function ConsistencyScorer.SaturationConsistency(colors1, colors2)
    local function avgSat(colors)
        local sum = 0
        for i = 1, #colors do
            local _, s, _ = CS.RGBtoHSV(colors[i][1], colors[i][2], colors[i][3])
            sum = sum + s
        end
        return sum / #colors
    end

    return math.min(1.0, math.abs(avgSat(colors1) - avgSat(colors2)))
end

--- 综合一致性评分
--- 对应 NST 的 L_total（加权组合）
---@param asset1 table 素材 1 的颜色信息 {colors={}, palette={}, stats={}}
---@param asset2 table 素材 2 的颜色信息
---@param weights table 权重配置（可选）
---@return number score 综合分数 [0, 100]（100=完全一致）
---@return table details 分项分数
function ConsistencyScorer.Score(asset1, asset2, weights)
    weights = weights or { palette = 0.4, brightness = 0.3, saturation = 0.3 }

    local paletteDist = ConsistencyScorer.PaletteDistance(asset1.palette, asset2.palette)
    local brightnessDist = ConsistencyScorer.BrightnessConsistency(asset1.stats, asset2.stats)
    local satDist = ConsistencyScorer.SaturationConsistency(asset1.colors, asset2.colors)

    local totalDist = weights.palette * paletteDist
                    + weights.brightness * brightnessDist
                    + weights.saturation * satDist

    local score = math.floor((1 - totalDist) * 100 + 0.5)

    return score, {
        palette = math.floor((1 - paletteDist) * 100 + 0.5),
        brightness = math.floor((1 - brightnessDist) * 100 + 0.5),
        saturation = math.floor((1 - satDist) * 100 + 0.5),
    }
end

--- 批量评分：计算一组素材相互之间的一致性矩阵
---@param assets table 素材数组 [{colors, palette, stats}, ...]
---@return table matrix 一致性矩阵 matrix[i][j] = score
---@return number avgScore 平均分数
function ConsistencyScorer.BatchScore(assets)
    local n = #assets
    local matrix = {}
    local totalScore = 0
    local count = 0

    for i = 1, n do
        matrix[i] = {}
        for j = 1, n do
            if i == j then
                matrix[i][j] = 100
            elseif j > i then
                matrix[i][j] = ConsistencyScorer.Score(assets[i], assets[j])
                totalScore = totalScore + matrix[i][j]
                count = count + 1
            else
                matrix[i][j] = matrix[j][i]
            end
        end
    end

    return matrix, (count > 0) and (totalScore / count) or 100
end

return ConsistencyScorer
```

### 5.3 一致性评分的游戏应用

```lua
-- 示例：检查游戏图标的风格一致性
local Scorer = require "NeuralTexture.ConsistencyScorer"

-- 定义几个图标的颜色数据（实际应用中从图像采样）
local iconSword = {
    colors  = {{0.7,0.7,0.75}, {0.5,0.5,0.55}, {0.3,0.2,0.1}},
    palette = CS.ExtractPalette({{0.7,0.7,0.75},{0.5,0.5,0.55},{0.3,0.2,0.1}}, 3),
    stats   = CS.ComputeLabStats({{0.7,0.7,0.75},{0.5,0.5,0.55},{0.3,0.2,0.1}}),
}
local iconShield = {
    colors  = {{0.6,0.6,0.65}, {0.4,0.35,0.2}, {0.8,0.75,0.6}},
    palette = CS.ExtractPalette({{0.6,0.6,0.65},{0.4,0.35,0.2},{0.8,0.75,0.6}}, 3),
    stats   = CS.ComputeLabStats({{0.6,0.6,0.65},{0.4,0.35,0.2},{0.8,0.75,0.6}}),
}

local score, details = Scorer.Score(iconSword, iconShield)
print(string.format("一致性: %d%% (调色板:%d%% 亮度:%d%% 饱和度:%d%%)",
    score, details.palette, details.brightness, details.saturation))
-- 输出示例: 一致性: 78% (调色板:72% 亮度:85% 饱和度:80%)
```

---

## 6. 模块 5: ParameterOptimizer — 迭代参数优化

> 对应 NST 的迭代梯度下降：NST 在像素空间上做梯度下降来最小化损失函数。
> ParameterOptimizer 在参数空间上做无梯度优化来最小化用户定义的目标函数。

### 6.1 核心概念

NST 的优化流程：
```
初始化 G（随机噪声或内容图）
for epoch = 1, N do
    loss = L_content(G) + L_style(G) + L_tv(G)
    G = G - lr * ∂loss/∂G
end
```

在 Lua 中，我们无法做自动微分，但可以用**无梯度优化方法**实现类似效果：
- **Nelder-Mead 单纯形法**：适合低维（2-10 维）连续优化
- **模拟退火**：适合有局部最优的离散/连续优化
- **随机搜索 + 精炼**：适合高维参数空间的快速探索

### 6.2 实现

```lua
-- ============================================================
-- ParameterOptimizer 模块
-- 文件：scripts/NeuralTexture/ParameterOptimizer.lua
-- ============================================================
local ParameterOptimizer = {}

--- 随机搜索 + 局部精炼优化器
--- 灵感：NST 的迭代优化，从初始点逐步逼近最优解
---@param objective function 目标函数 f(params) → number（越小越好）
---@param bounds table 参数范围 {{min1,max1},{min2,max2},...}
---@param config table 配置
---@return table bestParams 最优参数
---@return number bestScore 最优分数
---@return table history 优化历史
function ParameterOptimizer.Optimize(objective, bounds, config)
    config = config or {}
    local maxIter    = config.maxIterations or 100
    local population = config.population or 20
    local refineFrac = config.refineFraction or 0.3
    local seed       = config.seed or os.time()

    math.randomseed(seed)

    local dim = #bounds
    local bestParams = {}
    local bestScore = math.huge
    local history = {}

    -- 辅助：在范围内随机采样
    local function randomInBounds()
        local p = {}
        for d = 1, dim do
            p[d] = bounds[d][1] + math.random() * (bounds[d][2] - bounds[d][1])
        end
        return p
    end

    -- 辅助：在当前最优附近采样
    local function perturbAround(center, radius)
        local p = {}
        for d = 1, dim do
            local range = bounds[d][2] - bounds[d][1]
            local delta = (math.random() - 0.5) * 2 * range * radius
            p[d] = math.max(bounds[d][1], math.min(bounds[d][2], center[d] + delta))
        end
        return p
    end

    -- Phase 1: 全局随机搜索（对应 NST 早期大步优化）
    local globalIter = math.floor(maxIter * (1 - refineFrac))
    for i = 1, globalIter do
        local params
        if i <= population then
            params = randomInBounds()  -- 初始群体
        else
            -- 交叉探索：在最优点和随机点之间
            local t = math.random()
            local rnd = randomInBounds()
            params = {}
            for d = 1, dim do
                params[d] = bestParams[d] * t + rnd[d] * (1 - t)
            end
        end

        local score = objective(params)
        history[#history + 1] = { iter = i, score = score, phase = "global" }

        if score < bestScore then
            bestScore = score
            bestParams = params
        end
    end

    -- Phase 2: 局部精炼（对应 NST 后期小步优化）
    local refineIter = maxIter - globalIter
    for i = 1, refineIter do
        local radius = 0.1 * (1 - i / refineIter)  -- 搜索半径逐渐缩小
        local params = perturbAround(bestParams, radius)
        local score = objective(params)

        history[#history + 1] = {
            iter = globalIter + i,
            score = score,
            phase = "refine",
        }

        if score < bestScore then
            bestScore = score
            bestParams = params
        end
    end

    return bestParams, bestScore, history
end

--- 模拟退火优化器
--- 适用于有局部最优的离散或连续参数空间
---@param objective function 目标函数
---@param initial table 初始参数
---@param bounds table 参数范围
---@param config table 配置 {temperature, cooling, iterations}
---@return table bestParams
---@return number bestScore
function ParameterOptimizer.SimulatedAnnealing(objective, initial, bounds, config)
    config = config or {}
    local T = config.temperature or 1.0
    local cooling = config.cooling or 0.995
    local maxIter = config.iterations or 500

    local dim = #bounds
    local current = {}
    for d = 1, dim do current[d] = initial[d] end
    local currentScore = objective(current)

    local best = {}
    for d = 1, dim do best[d] = current[d] end
    local bestScore = currentScore

    for i = 1, maxIter do
        -- 邻域扰动
        local candidate = {}
        for d = 1, dim do
            local range = bounds[d][2] - bounds[d][1]
            local delta = (math.random() - 0.5) * range * T * 0.5
            candidate[d] = math.max(bounds[d][1],
                math.min(bounds[d][2], current[d] + delta))
        end

        local candidateScore = objective(candidate)
        local deltaE = candidateScore - currentScore

        -- Metropolis 准则
        if deltaE < 0 or math.random() < math.exp(-deltaE / T) then
            current = candidate
            currentScore = candidateScore

            if currentScore < bestScore then
                for d = 1, dim do best[d] = current[d] end
                bestScore = currentScore
            end
        end

        T = T * cooling
    end

    return best, bestScore
end

return ParameterOptimizer
```

### 6.3 游戏应用示例

```lua
-- 示例：自动寻找最佳雾效颜色参数
-- 目标：让场景雾色与给定的参考色尽可能接近
local Opt = require "NeuralTexture.ParameterOptimizer"
local CS  = require "NeuralTexture.ColorStatistics"

-- 参考色（目标）
local targetL, targetA, targetB = CS.RGBtoLab(0.8, 0.5, 0.3)  -- 暖橙色

-- 目标函数：与参考色的 Lab 距离
local function fogObjective(params)
    local r, g, b = params[1], params[2], params[3]
    local L, a, lab_b = CS.RGBtoLab(r, g, b)
    return math.sqrt((L - targetL)^2 + (a - targetA)^2 + (lab_b - targetB)^2)
end

-- 优化
local bestParams, bestScore = Opt.Optimize(
    fogObjective,
    {{0, 1}, {0, 1}, {0, 1}},  -- RGB 各通道 [0,1]
    { maxIterations = 50, population = 10 }
)

print(string.format("最佳雾色: RGB(%.2f, %.2f, %.2f), 误差: %.2f",
    bestParams[1], bestParams[2], bestParams[3], bestScore))
```

---

## 7. 集成指南

### 7.1 项目结构

```
scripts/
├── main.lua                          # 入口文件
├── NeuralTexture/                    # 本 Skill 的模块目录
│   ├── ColorStatistics.lua           # 模块 1: 颜色统计与迁移
│   ├── ProceduralTexture.lua         # 模块 2: 程序化纹理生成
│   ├── PainterlyRenderer.lua         # 模块 3: NanoVG 艺术化渲染
│   ├── ConsistencyScorer.lua         # 模块 4: 视觉一致性评分
│   └── ParameterOptimizer.lua        # 模块 5: 迭代参数优化
└── Game/                             # 用户游戏逻辑
    └── ...
```

### 7.2 引用方式

```lua
-- 在 scripts/main.lua 中引用
local CS  = require "NeuralTexture.ColorStatistics"
local PT  = require "NeuralTexture.ProceduralTexture"
local PR  = require "NeuralTexture.PainterlyRenderer"
local Scr = require "NeuralTexture.ConsistencyScorer"
local Opt = require "NeuralTexture.ParameterOptimizer"
```

### 7.3 构建与测试

代码修改后必须调用 UrhoX MCP `build` 工具进行构建：

```
写代码 → 调用 build 工具 → 预览测试
```

### 7.4 与其他 Skill 的协同

| 场景 | 工具组合 |
|------|---------|
| 生成纹理 → AI 风格化 | ProceduralTexture → art-style-transfer |
| AI 生成素材 → 一致性检查 | auto-game-assets → ConsistencyScorer |
| 手动调色 → 自动优化 | ColorStatistics → ParameterOptimizer |
| 艺术化 HUD → NanoVG 渲染 | PainterlyRenderer → NanoVG 事件 |

### 7.5 性能注意事项

| 模块 | 适用场景 | 性能建议 |
|------|---------|---------|
| ColorStatistics | 初始化/场景切换 | 颜色转换开销小，可每帧调用 |
| ProceduralTexture | 初始化/资源生成 | 噪声计算较重，建议预计算并缓存 |
| PainterlyRenderer | NanoVG 渲染 | 笔触数量影响帧率，建议 ≤200 笔/帧 |
| ConsistencyScorer | 离线/工具时 | 批量评分可能较慢，不建议每帧调用 |
| ParameterOptimizer | 初始化/设置 | 优化循环阻塞主线程，建议帧间分片 |

---

## 8. 保存与持久化

### 8.1 颜色配置保存

```lua
local cjson = require "cjson"

--- 保存颜色配置到 JSON 文件
---@param config table 颜色配置
---@param filename string 文件名（相对路径）
function SaveColorConfig(config, filename)
    local json = cjson.encode(config)
    local file = File:new(filename, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
    end
end

--- 加载颜色配置
---@param filename string
---@return table|nil
function LoadColorConfig(filename)
    local file = File:new(filename, FILE_READ)
    if file:IsOpen() then
        local json = file:ReadString()
        file:Close()
        return cjson.decode(json)
    end
    return nil
end
```

### 8.2 纹理预设保存

```lua
-- 保存纹理预设
local preset = {
    texType = "marble",
    params = {
        scale = 5.0,
        turbulence = 5.0,
        baseColor = {0.9, 0.9, 0.88},
        veinColor = {0.3, 0.25, 0.2},
    },
}
SaveColorConfig(preset, "texture_preset.json")

-- 加载纹理预设
local loaded = LoadColorConfig("texture_preset.json")
if loaded then
    local r, g, b = PT.Sample(loaded.texType, 0.5, 0.5, loaded.params)
end
```

---

## 9. FAQ 与常见问题

### Q1: 这个 Skill 和 art-style-transfer 有什么区别？

**art-style-transfer** 是用 MCP 图像工具（AI 黑箱）做风格迁移的工作流指南。
**neural-texture-synthesis** 是 NST 算法原理的 Lua 白箱实现，提供程序化工具。

两者互补：
- 需要高质量 AI 风格迁移 → art-style-transfer
- 需要程序化控制、实时效果、算法理解 → neural-texture-synthesis

### Q2: ProceduralTexture 生成的纹理如何用到 3D 模型上？

两种方式：
1. **运行时 NanoVG 预览** — 用 `PreviewNVG` 做快速预览
2. **生成图片资源** — 用 `GeneratePrompt` 配合 MCP `generate_image` 工具生成实际纹理文件，
   然后在代码中用 `cache:GetResource("Texture2D", "Textures/xxx.png")` 引用

### Q3: ParameterOptimizer 会卡住主线程吗？

是的。建议：
- 将 `maxIterations` 控制在 100 以内
- 或使用分帧优化：每帧只执行 5-10 次迭代
- 重型优化放在 `Start()` 中执行（加载阶段）

### Q4: NanoVG 笔触效果怎么避免闪烁？

使用固定 `seed` 参数。每帧使用相同的 seed，笔触位置和颜色变化就会保持一致。
只有在用户触发更新时才改变 seed。

---

## 10. 引用资源

| 资源 | 用途 |
|------|------|
| `references/algorithm-foundations.md` | NST 数学公式详解、VGG 特征层分析、Gram 矩阵推导 |
| `references/lua-implementations.md` | 完整 Lua 代码实现（可直接复制使用） |
| `references/game-recipes.md` | 游戏开发实用食谱（日夜循环、程序化地形配色等） |
| `art-style-transfer/SKILL.md` | AI 驱动的风格迁移工作流（互补 Skill） |
| `engine-docs/api/nanovg.md` | NanoVG API 参考 |

---

## 11. 注意事项

### 11.1 必须遵守的规则

1. **代码放 scripts/ 目录**：所有 Lua 模块文件放在 `scripts/NeuralTexture/`
2. **构建后测试**：每次修改代码后调用 UrhoX MCP build 工具
3. **NanoVG 用 NanoVGRender 事件**：所有 NanoVG 渲染代码放在 NanoVGRender 回调中
4. **字体先创建**：使用 NanoVG 文本前必须 `nvgCreateFont`
5. **不修改 urhox-libs/**：该目录只读

### 11.2 不要做的事

1. 不要在 Update 中做重型优化循环（用分帧策略）
2. 不要在每帧重新计算调色板（缓存结果）
3. 不要假设屏幕尺寸（用 `graphics:GetWidth()` / `graphics:GetHeight()`）
4. 不要写入构建输出目录
5. 不要使用 `io` 库（沙箱已移除，用 `File` 替代）
