# AI Game Tester — 集成示例与使用指南

> 完整 main.lua 集成示例、自定义行动词库、JSON 会话回放、NanoVG 报告可视化。

## 目录

- [完整 main.lua 集成示例](#完整集成示例)
- [自定义行动词库](#自定义行动词库)
- [JSON 会话记录与回放](#json-会话记录与回放)
- [NanoVG 可视化报告](#nanovg-可视化报告)
- [单独使用 Trie 模糊搜索](#单独使用-trie-模糊搜索)
- [单独使用骰子模拟器](#单独使用骰子模拟器)

---

## 完整集成示例

```lua
-- scripts/main.lua
-- AI Game Tester 完整集成示例
-- 整合 6 大模块：TrieEngine、ActionSystem、DiceSimulator、
-- DecisionEngine、SessionRecorder、TestRunner

require "LuaScripts/Utilities/Sample"

-- 引入模块
local TrieEngine      = require "scripts.ai-test.TrieEngine"
local ActionSystem    = require "scripts.ai-test.ActionSystem"
local DiceSimulator   = require "scripts.ai-test.DiceSimulator"
local DecisionEngine  = require "scripts.ai-test.DecisionEngine"
local SessionRecorder = require "scripts.ai-test.SessionRecorder"
local TestRunner      = require "scripts.ai-test.TestRunner"

---@type Scene
local scene_ = nil
local screenW, screenH, dpr = 0, 0, 1.0

-- ============================================================
-- §1  词库与配置
-- ============================================================

-- 动词词库（RPG 法术动作）
local VERBS = {
    "cast", "throw", "summon", "invoke", "channel",
    "strike", "blast", "heal", "shield", "drain",
}

-- 名词词库（RPG 法术目标/元素）
local NOUNS = {
    "fire", "ice", "lightning", "shadow", "light",
    "earth", "wind", "water", "poison", "arcane",
    "bolt", "wave", "storm", "shield", "nova",
}

-- 骰子配置
local DICE_CONFIG = {
    count    = 6,   -- 6d6
    sides    = 6,
    success  = 4,   -- 4+ 算成功
    explode  = 6,   -- 6 爆炸骰（额外投一次）
}

-- ============================================================
-- §2  Start()
-- ============================================================

function Start()
    SampleStart()

    screenW = graphics:GetWidth()
    screenH = graphics:GetHeight()
    dpr     = graphics:GetDPR()

    -- 创建简单 3D 场景（仅作背景）
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    local zone = scene_:CreateComponent("Zone")
    zone.boundingBox  = BoundingBox(Vector3(-100, -100, -100), Vector3(100, 100, 100))
    zone.ambientColor = Color(0.15, 0.15, 0.2)
    zone.fogColor     = Color(0.1, 0.1, 0.15)

    local camNode = scene_:CreateChild("Camera")
    camNode.position = Vector3(0, 0, -5)
    local camera = camNode:CreateComponent("Camera")
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)

    -- ============================================================
    -- §3  运行测试
    -- ============================================================

    local runner = TestRunner.new({
        verbs      = VERBS,
        nouns      = NOUNS,
        diceConfig = DICE_CONFIG,
        -- 行动组合测试
        actionTest = {
            sampleSize  = 50,      -- 生成 50 个随机行动
            maxChanges  = 2,       -- Trie 模糊搜索允许 2 次编辑
        },
        -- 骰子概率分析
        diceAnalysis = {
            simulations = 10000,   -- 每个等级模拟 1 万次
            maxLevel    = 10,      -- 测试 1~10 级
        },
        -- 决策引擎测试
        decisionTest = {
            rounds      = 20,      -- 模拟 20 轮决策
            contextText = "A dark cave filled with ancient runes",
        },
    })

    -- 执行全部测试
    runner:runActionTest()
    runner:runDiceAnalysis()
    runner:runDecisionTest()

    -- 输出文本报告
    runner:printReport()

    -- 保存 JSON 报告
    local report = runner:getReport()
    local cjson = require "cjson"
    local jsonStr = cjson.encode(report)

    local file = File:new(context, "ai-test-report.json", FILE_WRITE)
    if file:IsOpen() then
        file:WriteLine(jsonStr)
        file:Close()
        log:Write(LOG_INFO, "[AITest] Report saved to ai-test-report.json")
    end

    SubscribeToEvent("Update", "HandleUpdate")
end

-- ============================================================
-- §4  Update（可选：实时可视化）
-- ============================================================

function HandleUpdate(eventType, eventData)
    -- 此示例主要是一次性测试，Update 可用于交互式 UI
end

function Stop()
    scene_ = nil
end
```

---

## 自定义行动词库

根据你的游戏类型自定义词库：

```lua
-- ========== 中世纪奇幻 RPG ==========
local fantasyVerbs = {
    "cast", "invoke", "summon", "enchant", "dispel",
    "smite", "resurrect", "transmute", "conjure", "banish",
}
local fantasyNouns = {
    "fireball", "icestorm", "thunderbolt", "shadow", "light",
    "golem", "phoenix", "dragon", "undead", "elemental",
}

-- ========== 科幻射击游戏 ==========
local scifiVerbs = {
    "fire", "deploy", "activate", "hack", "overload",
    "scan", "teleport", "cloak", "charge", "detonate",
}
local scifiNouns = {
    "laser", "plasma", "shield", "drone", "turret",
    "emp", "nanobots", "reactor", "warp", "gravity",
}

-- ========== 卡牌 Roguelike ==========
local cardVerbs = {
    "play", "discard", "draw", "exhaust", "retain",
    "upgrade", "duplicate", "transform", "channel", "evoke",
}
local cardNouns = {
    "strike", "defend", "poison", "strength", "weakness",
    "lightning", "frost", "void", "focus", "calm",
}

-- 创建行动系统时传入自定义词库
local actionSys = ActionSystem.new(fantasyVerbs, fantasyNouns)
local action = actionSys:createAction("cast", "fireball")
print("Action:", action.name, "Level:", action.level)
```

---

## JSON 会话记录与回放

### 记录测试会话

```lua
local SessionRecorder = require "scripts.ai-test.SessionRecorder"
local DiceSimulator   = require "scripts.ai-test.DiceSimulator"
local ActionSystem    = require "scripts.ai-test.ActionSystem"

local actionSys = ActionSystem.new(VERBS, NOUNS)
local dice = DiceSimulator.new(DICE_CONFIG)

-- 开始一次测试会话
local startAction = actionSys:randomAction()
local session = SessionRecorder.new(startAction)

-- 模拟 5 轮测试
for round = 1, 5 do
    local action = actionSys:randomAction()
    local result = dice:roll()
    local success = dice:check(result, action.level)

    -- 基于测试结果评分（-2 ~ +2）
    local rating = 0
    if success and action.level >= 3 then
        rating = 2   -- 高难度成功，好评
    elseif success then
        rating = 1   -- 普通成功
    elseif action.level <= 2 then
        rating = -2  -- 低难度失败，差评
    else
        rating = -1  -- 高难度失败，可接受
    end

    session:addScenario({
        text    = string.format("Round %d: Testing %s", round, action.name),
        action  = action,
        success = success,
        rating  = rating,
    })
end

session:setEnding("Test session completed normally")

-- 保存到文件
session:save("test-session-001.json")
```

### 回放与分析历史会话

```lua
local SessionRecorder = require "scripts.ai-test.SessionRecorder"
local DecisionEngine  = require "scripts.ai-test.DecisionEngine"

-- 加载历史会话
local loaded = SessionRecorder.load("test-session-001.json")
if loaded then
    print("Start action:", loaded.startAction.name)
    print("Scenarios:", #loaded.scenarios)
    print("Ending:", loaded.ending)

    -- 提取场景数据供决策引擎学习
    local scenarios = loaded:extractScenarios()

    local engine = DecisionEngine.new()
    engine:loadHistory(scenarios)
    print("Decision engine loaded", engine:historyCount(), "scenarios")

    -- 用历史数据评估新行动
    local score = engine:evaluate(
        { name = "cast fireball", level = 3 },  -- 原始行动
        { name = "cast icestorm", level = 4 },   -- 当前候选
        "A dragon guards the treasure"            -- 场景文本
    )
    print("Evaluation score:", score)
end
```

---

## NanoVG 可视化报告

将测试结果用 NanoVG 柱状图渲染（骰子概率分布、等级曲线）：

```lua
-- 在 main.lua 中添加 NanoVG 可视化

local vg = nil
local fontSans = -1
local reportData = nil  -- TestRunner:getReport() 的结果

function Start()
    -- ... 前面的初始化代码 ...

    -- NanoVG 初始化
    vg = nvgCreate(0)
    fontSans = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    -- 运行测试并获取报告数据
    runner:runDiceAnalysis()
    reportData = runner:getReport()

    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleNanoVGRender(eventType, eventData)
    local w = screenW / dpr
    local h = screenH / dpr
    nvgBeginFrame(vg, w, h, dpr)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(220, 220, 240, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(vg, w * 0.5, 20, "AI Game Tester — Dice Probability Report")

    -- 绘制骰子等级曲线柱状图
    if reportData and reportData.diceAnalysis then
        drawLevelCurveChart(w * 0.1, 80, w * 0.8, h * 0.35,
            reportData.diceAnalysis.levelCurve)
    end

    nvgEndFrame(vg)
end

--- 绘制等级成功率柱状图
---@param x number 左上角 X
---@param y number 左上角 Y
---@param chartW number 图表宽度
---@param chartH number 图表高度
---@param curveData table {level, successRate} 数组
function drawLevelCurveChart(x, y, chartW, chartH, curveData)
    if not curveData or #curveData == 0 then return end

    local barCount = #curveData
    local barGap = 4
    local barW = (chartW - barGap * (barCount + 1)) / barCount

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, chartW, chartH, 8)
    nvgFillColor(vg, nvgRGBA(30, 30, 50, 200))
    nvgFill(vg)

    -- 柱子
    for i, item in ipairs(curveData) do
        local rate = item.successRate or 0
        local barH = chartH * 0.8 * rate
        local bx = x + barGap + (i - 1) * (barW + barGap)
        local by = y + chartH * 0.85 - barH

        -- 柱体（颜色从绿到红）
        local r = math.floor(255 * (1 - rate))
        local g = math.floor(255 * rate)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, barW, barH, 3)
        nvgFillColor(vg, nvgRGBA(r, g, 80, 220))
        nvgFill(vg)

        -- 等级标签
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgText(vg, bx + barW * 0.5, y + chartH * 0.88,
            string.format("Lv%d", item.level))

        -- 成功率标签
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgText(vg, bx + barW * 0.5, by - 2,
            string.format("%.0f%%", rate * 100))
    end

    -- 图表标题
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(180, 200, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    nvgText(vg, x + 10, y - 4, "Success Rate by Spell Level (6d6, 4+ success, 6 explodes)")
end
```

---

## 单独使用 Trie 模糊搜索

Trie 模块可独立使用，测试文本命令解析：

```lua
local TrieEngine = require "scripts.ai-test.TrieEngine"

-- 构建字典
local trie = TrieEngine.new()
local commands = {
    "attack", "defend", "heal", "cast", "dodge",
    "inspect", "inventory", "interact", "investigate",
}
for _, cmd in ipairs(commands) do
    trie:insert(cmd)
end

-- 精确搜索
print(trie:search("attack"))   -- true
print(trie:search("attck"))    -- false（少了 a）

-- 模糊搜索（允许 1 次编辑）
local fuzzy1 = trie:fuzzySearch("attck", 1)
-- 结果: {"attack"}（编辑距离 1 以内的匹配）

-- 模糊搜索（允许 2 次编辑）
local fuzzy2 = trie:fuzzySearch("inspt", 2)
-- 结果: {"inspect"}

-- 字谜搜索（重排字母）
local anagrams = trie:anagramSearch("acst", true)
-- 结果: {"cast"}（complete=true 要求用完所有字母）

-- 部分字谜（不要求用完所有字母）
local partial = trie:anagramSearch("acastextra", false)
-- 结果: {"cast", "attack", ...}（字母够用即可）

-- 应用：测试玩家输入容错
local function processPlayerCommand(input)
    -- 先精确匹配
    if trie:search(input) then
        return input
    end
    -- 模糊匹配（最多 2 次编辑）
    local matches = trie:fuzzySearch(input, 2)
    if #matches == 1 then
        return matches[1]  -- 唯一匹配，自动修正
    elseif #matches > 1 then
        return nil, matches  -- 多个候选，让玩家选择
    end
    return nil, {}  -- 无匹配
end
```

---

## 单独使用骰子模拟器

骰子模块可独立分析游戏概率平衡：

```lua
local DiceSimulator = require "scripts.ai-test.DiceSimulator"

-- 标准 RPG 骰子：6d6, 4+成功, 6爆炸
local dice = DiceSimulator.new({
    count   = 6,
    sides   = 6,
    success = 4,
    explode = 6,
})

-- 单次投掷
local result = dice:roll()
print("Dice:", table.concat(result.dice, ","))
print("Successes:", result.successes)
print("Exploded:", result.exploded)

-- 检查是否通过指定等级
local passed = dice:check(result, 3)  -- 需要 3 个成功
print("Level 3 check:", passed)

-- 批量模拟：1 万次，测试等级 5 的通过率
local stats = dice:batchSimulate(10000, 5)
print(string.format(
    "Level 5: %.1f%% success (avg successes: %.2f)",
    stats.successRate * 100,
    stats.avgSuccesses
))

-- 等级曲线：测试 1~12 级的通过率分布
local curve = dice:levelCurve(10000, 12)
for _, point in ipairs(curve) do
    local bar = string.rep("█", math.floor(point.successRate * 40))
    print(string.format("Lv%2d: %5.1f%% %s",
        point.level, point.successRate * 100, bar))
end
-- 输出示例:
-- Lv 1: 98.7% ████████████████████████████████████████
-- Lv 2: 93.4% █████████████████████████████████████
-- Lv 3: 82.1% ████████████████████████████████
-- Lv 4: 63.5% █████████████████████████
-- Lv 5: 42.8% █████████████████
-- Lv 6: 25.3% ██████████
-- ...

-- 自定义骰子规则（如 4d10, 7+成功, 10爆炸）
local customDice = DiceSimulator.new({
    count   = 4,
    sides   = 10,
    success = 7,
    explode = 10,
})
local customCurve = customDice:levelCurve(5000, 8)
```

---

## 模块文件结构

将模块放入 `scripts/ai-test/` 目录：

```
scripts/
├── main.lua                    -- 入口文件
└── ai-test/
    ├── TrieEngine.lua          -- Trie 字典树
    ├── ActionSystem.lua        -- 行动系统（动词+名词）
    ├── DiceSimulator.lua       -- 骰子模拟器
    ├── DecisionEngine.lua      -- 决策引擎（历史学习）
    ├── SessionRecorder.lua     -- 会话记录器（JSON）
    └── TestRunner.lua          -- 测试运行器
```

> 各模块的完整实现代码 → [modules-implementation.md](modules-implementation.md)
