# 游戏开发实战配方

> 本文档提供 `neural-texture-synthesis` 模块在实际游戏中的应用配方。
> 每个配方都是一个独立的、可直接使用的解决方案。

---

## 配方 1: 昼夜循环色彩系统

**场景**: 开放世界游戏中，根据时间流逝自动调整场景色调。

### 设计思路

利用 `ColorStatistics.TransferColors` 将场景颜色从"白天调色板"
平滑过渡到"黄昏调色板"、"夜晚调色板"。

### 实现代码

```lua
-- scripts/DayNightColors.lua

local ColorStatistics = require "scripts.NeuralTexture.ColorStatistics"

local DayNight = {}

-- 定义时段调色板
local palettes = {
    dawn    = { {0.95,0.7,0.5}, {0.9,0.8,0.7}, {0.6,0.5,0.7} },
    day     = { {0.5,0.7,1.0}, {0.9,0.9,0.85}, {0.3,0.7,0.3} },
    dusk    = { {1.0,0.5,0.2}, {0.8,0.4,0.3}, {0.3,0.2,0.4} },
    night   = { {0.05,0.05,0.15}, {0.1,0.1,0.3}, {0.02,0.02,0.08} },
}

-- 预计算 Lab 统计
local stats = {}
for name, pal in pairs(palettes) do
    stats[name] = ColorStatistics.ComputeLabStats(pal)
end

--- 获取当前时段
---@param hour number 0~24
---@return string period1, string period2, number blend
local function getPeriod(hour)
    if hour < 6 then
        return "night", "dawn", hour / 6
    elseif hour < 12 then
        return "dawn", "day", (hour - 6) / 6
    elseif hour < 18 then
        return "day", "dusk", (hour - 12) / 6
    else
        return "dusk", "night", (hour - 18) / 6
    end
end

--- 线性插值 Lab 统计
local function lerpStats(s1, s2, t)
    return {
        meanL = s1.meanL + (s2.meanL - s1.meanL) * t,
        meanA = s1.meanA + (s2.meanA - s1.meanA) * t,
        meanB = s1.meanB + (s2.meanB - s1.meanB) * t,
        stdL  = s1.stdL  + (s2.stdL  - s1.stdL)  * t,
        stdA  = s1.stdA  + (s2.stdA  - s1.stdA)  * t,
        stdB  = s1.stdB  + (s2.stdB  - s1.stdB)  * t,
    }
end

--- 根据游戏内小时获取雾色
---@param hour number 0~24
---@return number r, number g, number b
function DayNight.GetFogColor(hour)
    local p1, p2, t = getPeriod(hour)
    local blended = lerpStats(stats[p1], stats[p2], t)

    -- 用中性灰做颜色迁移
    local neutral = { {0.5, 0.5, 0.5} }
    local result = ColorStatistics.TransferColors(neutral, blended)
    return result[1][1], result[1][2], result[1][3]
end

--- 根据游戏内小时获取环境光颜色
---@param hour number
---@return number r, number g, number b
function DayNight.GetAmbientColor(hour)
    local p1, p2, t = getPeriod(hour)
    local blended = lerpStats(stats[p1], stats[p2], t)

    local base = { {0.6, 0.6, 0.6} }
    local result = ColorStatistics.TransferColors(base, blended)
    return result[1][1], result[1][2], result[1][3]
end

--- 在 HandleUpdate 中调用
---@param zone userdata UrhoX Zone 组件
---@param light userdata UrhoX Light 组件
---@param gameHour number 当前游戏内小时
function DayNight.Apply(zone, light, gameHour)
    local fr, fg, fb = DayNight.GetFogColor(gameHour)
    zone.fogColor = Color(fr, fg, fb, 1)

    local ar, ag, ab = DayNight.GetAmbientColor(gameHour)
    zone.ambientColor = Color(ar, ag, ab, 1)
end

return DayNight
```

### 使用方式

```lua
-- 在 main.lua 的 HandleUpdate 中
local DayNight = require "scripts.DayNightColors"
local gameHour = 0  -- 0~24 循环

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    gameHour = (gameHour + dt * 0.5) % 24  -- 48秒=游戏内1天

    DayNight.Apply(zone, light, gameHour)
end
```

---

## 配方 2: 程序化地形着色

**场景**: 根据高度和坡度自动给地形分配颜色（草地、岩石、雪地）。

### 实现代码

```lua
-- scripts/TerrainColoring.lua

local ProceduralTexture = require "scripts.NeuralTexture.ProceduralTexture"
local ColorStatistics   = require "scripts.NeuralTexture.ColorStatistics"

local TerrainColor = {}

-- 地形层配置
local layers = {
    { maxHeight = 0.2,  color = {0.2, 0.4, 0.15}, name = "grass"  },  -- 草地
    { maxHeight = 0.5,  color = {0.5, 0.45, 0.3}, name = "dirt"   },  -- 泥土
    { maxHeight = 0.75, color = {0.5, 0.5, 0.5},  name = "rock"   },  -- 岩石
    { maxHeight = 1.0,  color = {0.95, 0.95, 0.98}, name = "snow"  },  -- 雪地
}

--- 获取高度处的地形颜色
---@param height number 归一化高度 0~1
---@param worldX number 世界坐标 X（用于噪声变化）
---@param worldZ number 世界坐标 Z
---@return number r, number g, number b
function TerrainColor.GetColor(height, worldX, worldZ)
    -- 找到对应层
    local lower = layers[1]
    local upper = layers[1]

    for i = 1, #layers do
        if height <= layers[i].maxHeight then
            upper = layers[i]
            lower = (i > 1) and layers[i - 1] or layers[i]
            break
        end
    end

    -- 层间混合
    local range = upper.maxHeight - (lower == upper and 0 or lower.maxHeight)
    local localH = height - (lower == upper and 0 or lower.maxHeight)
    local t = (range > 0) and (localH / range) or 0

    -- 基础颜色插值
    local r = lower.color[1] + (upper.color[1] - lower.color[1]) * t
    local g = lower.color[2] + (upper.color[2] - lower.color[2]) * t
    local b = lower.color[3] + (upper.color[3] - lower.color[3]) * t

    -- 加入噪声变化
    local noise = ProceduralTexture.FBM(worldX * 0.1, worldZ * 0.1, 4) * 0.08
    r = math.max(0, math.min(1, r + noise))
    g = math.max(0, math.min(1, g + noise * 0.8))
    b = math.max(0, math.min(1, b + noise * 0.5))

    return r, g, b
end

--- 生成地形颜色提示词（用于 MCP generate_image）
---@param biome string "forest"|"desert"|"arctic"|"volcanic"
---@return string
function TerrainColor.GeneratePrompt(biome)
    local prompts = {
        forest   = "翠绿森林地形俯视图，深绿浅绿交替，棕色土路，无缝拼接贴图",
        desert   = "黄色沙漠地形俯视图，沙丘纹理，浅棕色，无缝拼接贴图",
        arctic   = "雪地地形俯视图，白色积雪覆盖，露出灰色岩石，无缝拼接贴图",
        volcanic = "火山地形俯视图，黑色岩石，橙红色熔岩裂缝，无缝拼接贴图",
    }
    return prompts[biome] or prompts.forest
end

return TerrainColor
```

---

## 配方 3: NanoVG 绘画风格 UI 背景

**场景**: 用油画/水彩风格渲染 UI 面板背景，打造手绘感游戏界面。

### 实现代码

```lua
-- scripts/PainterlyUI.lua
-- 在 NanoVGRender 事件中绘制风格化 UI 背景

local PainterlyRenderer = require "scripts.NeuralTexture.PainterlyRenderer"
local ColorStatistics   = require "scripts.NeuralTexture.ColorStatistics"

local PainterlyUI = {}

--- 绘制油画风格的面板背景
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
---@param hue number 色相 0~360（控制主色调）
function PainterlyUI.DrawPanel(vg, x, y, w, h, hue)
    -- 生成和谐色
    local colors = ColorStatistics.HarmonyScheme(hue, 0.4, 0.7, "analogous")

    -- 裁剪区域（防止笔触溢出）
    nvgSave(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 8)
    nvgPathWinding(vg, NVG_SOLID)
    -- 先画底色
    nvgFillColor(vg, nvgRGBAf(colors[2][1], colors[2][2], colors[2][3], 0.9))
    nvgFill(vg)

    -- 油画笔触
    PainterlyRenderer.OilPaintFill(vg, x + 4, y + 4, w - 8, h - 8,
        colors[1][1], colors[1][2], colors[1][3], {
            brushSize = 8, density = 60, variation = 0.1,
        })

    -- 边框
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 8)
    nvgStrokeColor(vg, nvgRGBAf(0, 0, 0, 0.3))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    nvgRestore(vg)
end

--- 绘制水彩风格的标题栏
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
---@param title string
function PainterlyUI.DrawTitle(vg, x, y, w, h, title)
    local colors = { {0.3, 0.5, 0.8}, {0.2, 0.4, 0.7} }

    -- 水彩背景
    PainterlyRenderer.ApplyStyle(vg, "watercolor", x, y, w, h, colors, {
        blobs = 5, layers = 4, wobble = 0.2,
    })

    -- 标题文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBf(1, 1, 1))
    nvgText(vg, x + w * 0.5, y + h * 0.5, title)
end

return PainterlyUI
```

### 使用方式

```lua
-- 在 NanoVGRender 事件中
function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local lw, lh = w / dpr, h / dpr

    nvgBeginFrame(vg, lw, lh, dpr)

    -- 绘制绘画风格面板
    PainterlyUI.DrawPanel(vg, 50, 50, 300, 400, 210)
    PainterlyUI.DrawTitle(vg, 50, 50, 300, 40, "游戏菜单")

    nvgEndFrame(vg)
end
```

---

## 配方 4: 素材一致性审计工具

**场景**: 批量检查游戏中所有 UI 图标是否色彩风格一致。

### 实现代码

```lua
-- scripts/AssetAudit.lua

local ColorStatistics   = require "scripts.NeuralTexture.ColorStatistics"
local ConsistencyScorer = require "scripts.NeuralTexture.ConsistencyScorer"

local AssetAudit = {}

--- 审计一组资源的色彩一致性
---@param assetPalettes table { { name = "icon_coin", palette = {{r,g,b},...} }, ... }
---@return table 审计报告
function AssetAudit.Audit(assetPalettes)
    local report = {
        totalAssets = #assetPalettes,
        pairs = {},
        worstPairs = {},
        averageScore = 0,
    }

    if #assetPalettes < 2 then
        report.averageScore = 100
        return report
    end

    local palettes = {}
    local names = {}
    for i, a in ipairs(assetPalettes) do
        palettes[i] = a.palette
        names[i] = a.name
    end

    local matrix, avg = ConsistencyScorer.BatchScore(palettes)
    report.averageScore = avg

    -- 找出最差的配对
    for i = 1, #palettes do
        for j = i + 1, #palettes do
            local pair = {
                asset1 = names[i],
                asset2 = names[j],
                score = matrix[i][j],
            }
            report.pairs[#report.pairs + 1] = pair

            if matrix[i][j] < 60 then
                report.worstPairs[#report.worstPairs + 1] = pair
            end
        end
    end

    -- 按分数排序（最差在前）
    table.sort(report.worstPairs, function(a, b) return a.score < b.score end)

    return report
end

--- 输出审计报告到日志
---@param report table 来自 Audit 的结果
function AssetAudit.PrintReport(report)
    log:Write(LOG_INFO, string.format(
        "=== Asset Consistency Audit ===\nTotal assets: %d\nAverage score: %.1f/100",
        report.totalAssets, report.averageScore
    ))

    if #report.worstPairs > 0 then
        log:Write(LOG_WARNING, "Inconsistent pairs (score < 60):")
        for _, pair in ipairs(report.worstPairs) do
            log:Write(LOG_WARNING, string.format(
                "  %s <-> %s : %.1f/100",
                pair.asset1, pair.asset2, pair.score
            ))
        end
    else
        log:Write(LOG_INFO, "All asset pairs are consistent\!")
    end
end

--- 保存审计报告为 JSON
---@param report table
---@param filename string 如 "audit_report.json"
function AssetAudit.SaveReport(report, filename)
    local cjson = require "cjson"
    local json = cjson.encode(report)
    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteString(json)
        file:Close()
        log:Write(LOG_INFO, "Audit report saved to " .. filename)
    end
end

return AssetAudit
```

### 使用方式

```lua
local AssetAudit = require "scripts.AssetAudit"

-- 定义资源的代表色（可手动设定或从图片采样）
local assets = {
    { name = "coin_icon", palette = {{1.0,0.84,0.0}, {0.85,0.65,0.13}} },
    { name = "gem_icon",  palette = {{0.0,0.5,1.0}, {0.3,0.2,0.8}} },
    { name = "heart_icon", palette = {{1.0,0.2,0.2}, {0.8,0.1,0.1}} },
    { name = "star_icon",  palette = {{1.0,0.9,0.1}, {0.9,0.7,0.0}} },
}

local report = AssetAudit.Audit(assets)
AssetAudit.PrintReport(report)
AssetAudit.SaveReport(report, "audit_result.json")
```

---

## 配方 5: 自动参数调优（雾色优化）

**场景**: 自动找到最佳雾颜色参数，使场景的整体色彩和谐度最高。

### 实现代码

```lua
-- scripts/FogOptimizer.lua

local ColorStatistics    = require "scripts.NeuralTexture.ColorStatistics"
local ConsistencyScorer  = require "scripts.NeuralTexture.ConsistencyScorer"
local ParameterOptimizer = require "scripts.NeuralTexture.ParameterOptimizer"

local FogOptimizer = {}

--- 自动优化雾颜色
---@param skyPalette table 天空调色板 { {r,g,b}, ... }
---@param groundPalette table 地面调色板
---@return table { fogR, fogG, fogB, score }
function FogOptimizer.OptimizeFogColor(skyPalette, groundPalette)
    -- 定义搜索范围：HSV 空间
    local ranges = {
        { "h", 0, 360 },
        { "s", 0, 0.6 },
        { "v", 0.3, 0.9 },
    }

    -- 评分函数：雾颜色与天空、地面的一致性
    local function scoreFunc(params)
        local r, g, b = ColorStatistics.HSVtoRGB(params.h, params.s, params.v)
        local fogPalette = { {r, g, b} }

        local skyScore = ConsistencyScorer.Score(fogPalette, skyPalette)
        local groundScore = ConsistencyScorer.Score(fogPalette, groundPalette)

        -- 综合：与天空和地面都要和谐
        return skyScore * 0.6 + groundScore * 0.4
    end

    local bestParams, bestScore = ParameterOptimizer.Optimize(
        scoreFunc, ranges, {
            globalSamples = 80,
            localSteps = 40,
        }
    )

    local r, g, b = ColorStatistics.HSVtoRGB(bestParams.h, bestParams.s, bestParams.v)

    return {
        fogR = r, fogG = g, fogB = b,
        score = bestScore,
        hue = bestParams.h,
        saturation = bestParams.s,
        value = bestParams.v,
    }
end

return FogOptimizer
```

### 使用方式

```lua
local FogOptimizer = require "scripts.FogOptimizer"

-- 定义场景调色板
local sky    = { {0.4,0.6,1.0}, {0.6,0.8,1.0}, {0.3,0.4,0.8} }
local ground = { {0.3,0.5,0.2}, {0.4,0.35,0.2}, {0.5,0.5,0.4} }

local result = FogOptimizer.OptimizeFogColor(sky, ground)

log:Write(LOG_INFO, string.format(
    "Optimal fog: RGB(%.2f, %.2f, %.2f), score=%.1f",
    result.fogR, result.fogG, result.fogB, result.score
))

-- 应用到场景
zone.fogColor = Color(result.fogR, result.fogG, result.fogB, 1)
```

---

## 配方 6: 程序化纹理预览与 MCP 生成

**场景**: 先用程序化噪声预览纹理效果，满意后调用 MCP 生成高质量贴图。

### 工作流

```
步骤 1: 用 ProceduralTexture 在 NanoVG 中预览
         → 调整参数直到满意

步骤 2: 用 ProceduralTexture.GeneratePrompt() 生成描述词
         → 传给 MCP generate_image 生成高质量贴图

步骤 3: 用 ConsistencyScorer 验证生成贴图与现有素材的一致性
```

### 实现代码

```lua
-- scripts/TextureWorkflow.lua

local ProceduralTexture = require "scripts.NeuralTexture.ProceduralTexture"

local TextureWorkflow = {}

--- 纹理预设配置
TextureWorkflow.presets = {
    marble_floor = {
        type = "marble",
        params = { scale = 0.3, veins = 8, turbulence = 4, octaves = 6 },
        promptExtra = "光滑抛光，室内地面",
    },
    wood_plank = {
        type = "wood",
        params = { scale = 0.5, rings = 15, turbulence = 1.5, octaves = 4 },
        promptExtra = "木板条纹，温暖色调",
    },
    cobblestone = {
        type = "stone",
        params = { scale = 0.8 },
        promptExtra = "中世纪鹅卵石路面，灰色",
    },
    perlin_clouds = {
        type = "noise",
        params = { scale = 0.2, octaves = 8 },
        promptExtra = "天空云层，白色柔和",
    },
}

--- 保存预设到 JSON
---@param presetName string
---@param filename string
function TextureWorkflow.SavePreset(presetName, filename)
    local preset = TextureWorkflow.presets[presetName]
    if not preset then
        log:Write(LOG_ERROR, "Unknown preset: " .. presetName)
        return
    end

    local cjson = require "cjson"
    local json = cjson.encode({
        name = presetName,
        type = preset.type,
        params = preset.params,
        prompt = ProceduralTexture.GeneratePrompt(preset.type, preset.params)
            .. "，" .. preset.promptExtra,
    })

    local file = File(filename, FILE_WRITE)
    if file then
        file:WriteString(json)
        file:Close()
        log:Write(LOG_INFO, "Preset saved: " .. filename)
    end
end

--- 加载预设
---@param filename string
---@return table|nil
function TextureWorkflow.LoadPreset(filename)
    if not fileSystem:FileExists(filename) then return nil end
    local cjson = require "cjson"
    local file = File(filename, FILE_READ)
    if file then
        local json = file:ReadString()
        file:Close()
        return cjson.decode(json)
    end
    return nil
end

return TextureWorkflow
```

---

## 性能注意事项

| 操作 | 复杂度 | 建议 |
|------|--------|------|
| K-Means 调色板提取 | O(n×k×iter) | 颜色数 n < 100，k ≤ 8 |
| 噪声纹理预览 | O(w×h/step²) | step ≥ 4，预览尺寸 ≤ 256×256 |
| 油画笔触渲染 | O(density) | density ≤ 300 |
| 批量一致性矩阵 | O(n²×k) | 资源数 n ≤ 20 |
| 参数优化 | O(samples + steps) | 总计 ≤ 200 次评估 |

**通用原则**：
- 程序化纹理预览放在 `NanoVGRender` 事件中，每帧执行
- 复杂计算（优化、批量审计）只在需要时一次性执行，不放在每帧循环
- 调色板提取和颜色迁移可以预计算并缓存结果

---

*本文档提供可直接应用到 UrhoX Lua 游戏中的实战配方。*
*所有代码遵循引擎规范，存放于 scripts/ 目录，修改后需调用构建工具。*
