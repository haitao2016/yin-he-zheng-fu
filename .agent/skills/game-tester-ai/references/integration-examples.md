# Game Tester AI — 集成示例

> 本文档展示如何将测试框架集成到 UrhoX Lua 游戏中。
> 包括完整 main.lua 示例、各模块独立用法和 NanoVG 仪表盘叠加。

---

## 目录

1. [完整集成示例 — 3D 平台跳跃游戏](#1-完整集成示例)
2. [GameTypeDetector 独立用法](#2-gametypedetector-独立用法)
3. [GameMetricsCollector 独立用法](#3-gamemetricscollector-独立用法)
4. [HumanVsAIDetector 独立用法](#4-humanvsaidetector-独立用法)
5. [SessionManager 持久化用法](#5-sessionmanager-持久化用法)
6. [NanoVG 仪表盘叠加](#6-nanovg-仪表盘叠加)
7. [TestRunner 一键集成](#7-testrunner-一键集成)

---

## 1. 完整集成示例

> 将所有 5 个模块集成到一个 3D 平台跳跃游戏中。
> 按 F5 生成报告，按 F6 显示/隐藏 NanoVG 仪表盘。

```lua
-- scripts/main.lua
-- 3D 平台跳跃 + 游戏测试框架完整集成

require "LuaScripts/Utilities/Sample"

local GameTypeDetector     = require "scripts.testing.GameTypeDetector"
local GameMetricsCollector = require "scripts.testing.GameMetricsCollector"
local HumanVsAIDetector    = require "scripts.testing.HumanVsAIDetector"
local SessionManager       = require "scripts.testing.SessionManager"
local ReportBuilder        = require "scripts.testing.ReportBuilder"

-- 游戏状态
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Node
local characterNode_ = nil

-- 测试组件
local collector
local session
local reportBuilder
local gameTypeResult
local lastVerdict
local showDashboard = false
local vg

function Start()
    SampleStart()

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    -- 光照
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.brightness = 1.0

    -- 地面
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(0, -0.5, 0)
    floorNode.scale = Vector3(50, 1, 50)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local floorBody = floorNode:CreateComponent("RigidBody")
    floorBody.mass = 0
    local floorShape = floorNode:CreateComponent("CollisionShape")
    floorShape:SetBox(Vector3.ONE)

    -- 角色（简单球体）
    characterNode_ = scene_:CreateChild("Character")
    characterNode_.position = Vector3(0, 1, 0)
    local charModel = characterNode_:CreateComponent("StaticModel")
    charModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local charBody = characterNode_:CreateComponent("RigidBody")
    charBody.mass = 1.0
    charBody.friction = 0.7
    local charShape = characterNode_:CreateComponent("CollisionShape")
    charShape:SetSphere(1.0)

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 5, -10)
    cameraNode_:LookAt(Vector3.ZERO)
    local camera = cameraNode_:CreateComponent("Camera")
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- === 初始化测试框架 ===
    collector     = GameMetricsCollector.new()
    session       = SessionManager.new({ maxHistory = 50 })
    reportBuilder = ReportBuilder.new()

    -- 尝试加载历史记录
    session:loadFromFile("test_sessions.json")

    -- 识别游戏类型
    local detector = GameTypeDetector.new()
    gameTypeResult = detector:detect({
        title = "3D Platformer Demo",
        tags  = { "platformer", "jump", "3d", "run" }
    })
    log:Write(LOG_INFO, "[TestAI] Game type: " .. gameTypeResult.primary_type
              .. " (" .. gameTypeResult.confidence .. ")")

    session:setContext({
        gameName = "3D Platformer Demo",
        gameType = gameTypeResult.primary_type,
        startTime = os.time(),
    })

    -- NanoVG
    vg = nvgCreate(0)

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 每帧采集指标
    collector:update(dt)

    -- 角色移动
    local body = characterNode_:GetComponent("RigidBody")
    local moveSpeed = 8.0
    if input:GetKeyDown(KEY_W) then
        body:ApplyForce(Vector3(0, 0, moveSpeed))
        collector:recordAction("move_forward")
    end
    if input:GetKeyDown(KEY_S) then
        body:ApplyForce(Vector3(0, 0, -moveSpeed))
        collector:recordAction("move_back")
    end
    if input:GetKeyDown(KEY_A) then
        body:ApplyForce(Vector3(-moveSpeed, 0, 0))
        collector:recordAction("move_left")
    end
    if input:GetKeyDown(KEY_D) then
        body:ApplyForce(Vector3(moveSpeed, 0, 0))
        collector:recordAction("move_right")
    end

    -- 模拟得分（每 5 秒记录一次）
    local elapsed = collector.totalTime
    if elapsed > 0 and math.floor(elapsed) % 5 == 0 and math.floor(elapsed) ~= math.floor(elapsed - dt) then
        local score = math.floor(elapsed * 10 + math.random(-20, 20))
        collector:recordScore(score)
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- 跳跃
    if key == KEY_SPACE then
        local body = characterNode_:GetComponent("RigidBody")
        body:ApplyImpulse(Vector3(0, 7, 0))
        collector:recordAction("jump")
    end

    -- F5: 生成测试报告
    if key == KEY_F5 then
        local metrics = collector:getSnapshot()
        local hvDetector = HumanVsAIDetector.new()
        lastVerdict = hvDetector:analyze(metrics, gameTypeResult.primary_type)

        -- 打印文本报告
        local text = reportBuilder:buildText(metrics, lastVerdict, gameTypeResult)
        log:Write(LOG_INFO, "\n" .. text)

        -- 保存到会话
        session:saveTest({
            timestamp = os.time(),
            metrics   = metrics,
            verdict   = lastVerdict,
            gameType  = gameTypeResult,
        })
        session:saveToFile("test_sessions.json")

        log:Write(LOG_INFO, "[TestAI] Report saved. Total records: " .. session:getCount())
    end

    -- F6: 显示/隐藏 NanoVG 仪表盘
    if key == KEY_F6 then
        showDashboard = not showDashboard
    end

    -- ESC: 退出
    if key == KEY_ESCAPE then
        engine:Exit()
    end
end

function HandleNanoVGRender(eventType, eventData)
    if not showDashboard then return end

    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()

    nvgBeginFrame(vg, w, h, 1.0)

    local metrics = collector:getSnapshot()
    local panelW = 320
    local panelH = 340
    reportBuilder:drawDashboard(vg, w - panelW - 16, 16, panelW, panelH, metrics, lastVerdict)

    nvgEndFrame(vg)
end
```

---

## 2. GameTypeDetector 独立用法

> 仅使用类型识别器，不依赖其他模块。

```lua
local GameTypeDetector = require "scripts.testing.GameTypeDetector"

local detector = GameTypeDetector.new()

-- 添加自定义类型
detector:registerType("Idle/Clicker", {
    "idle", "clicker", "increment", "tap", "upgrade", "prestige"
})

-- 从游戏信息中检测
local result = detector:detect({
    title = "Cookie Clicker Remake",
    tags  = { "idle", "clicker", "casual" },
    description = "Tap cookies to earn points and buy upgrades"
})

log:Write(LOG_INFO, "Type: " .. result.primary_type)       -- "Idle/Clicker"
log:Write(LOG_INFO, "Confidence: " .. result.confidence)    -- "High"

-- 查看各类型得分
for typeName, score in pairs(result.scores) do
    if score > 0 then
        log:Write(LOG_INFO, "  " .. typeName .. ": " .. score)
    end
end
```

---

## 3. GameMetricsCollector 独立用法

> 仅使用指标采集器记录运行时数据。

```lua
local GameMetricsCollector = require "scripts.testing.GameMetricsCollector"

local collector = GameMetricsCollector.new()

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    collector:update(dt)
end

-- 在游戏逻辑中记录事件
function onPlayerJump()
    collector:recordAction("jump")
end

function onPlayerAttack()
    collector:recordAction("attack")
end

function onScoreChange(newScore)
    collector:recordScore(newScore)
end

function onGameError(desc)
    collector:recordError(desc)
end

-- 随时获取当前快照
function printMetrics()
    local m = collector:getSnapshot()
    log:Write(LOG_INFO, string.format(
        "FPS=%.1f | Actions=%d (%.2f/s) | Duration=%.1fs | Errors=%d | Rating=%s",
        m.fps_avg, m.action_count, m.actions_per_second,
        m.time_survived, m.error_count, m.performance_rating
    ))
end

-- 重置（开始新一局）
function onNewGame()
    collector:reset()
end
```

---

## 4. HumanVsAIDetector 独立用法

> 仅使用人机判别器分析一组指标。

```lua
local HumanVsAIDetector = require "scripts.testing.HumanVsAIDetector"

local detector = HumanVsAIDetector.new()

-- 用手动构造的指标测试
local testMetrics = {
    actions_per_second = 1.2,
    error_count        = 2,
    scores             = { 100, 250, 230, 480, 510, 490 },
    time_survived      = 45.0,
    performance_rating = "Medium",
}

local verdict = detector:analyze(testMetrics, "Action/Shooter")

log:Write(LOG_INFO, "Verdict: " .. verdict.result)         -- "Human"
log:Write(LOG_INFO, "Confidence: " .. verdict.confidence)   -- "High"
log:Write(LOG_INFO, string.format("Human ratio: %.0f%%", verdict.human_ratio * 100))

-- 逐个信号查看
for i = 1, #verdict.signals do
    local s = verdict.signals[i]
    log:Write(LOG_INFO, string.format("  Signal %d [%s]: %s - %s",
        i, s.name, s.label, s.detail))
end

-- 用 Bot 特征的指标测试
local botMetrics = {
    actions_per_second = 4.5,          -- 超高 APS
    error_count        = 0,            -- 零错误
    scores             = { 100, 200, 300, 400, 500 },  -- 完美线性增长
    time_survived      = 3.0,          -- 极短时间
    performance_rating = "High",       -- 高性能
}

local botVerdict = detector:analyze(botMetrics, "Endless Runner")
log:Write(LOG_INFO, "Bot verdict: " .. botVerdict.result)   -- "AI/Bot"
```

---

## 5. SessionManager 持久化用法

> 使用 UrhoX File API 进行会话的保存/加载/导出。

```lua
local SessionManager = require "scripts.testing.SessionManager"

-- 创建管理器，最多保留 30 条历史
local session = SessionManager.new({ maxHistory = 30 })

-- 加载之前保存的数据
local loaded = session:loadFromFile("test_history.json")
if loaded then
    log:Write(LOG_INFO, "Loaded " .. session:getCount() .. " previous records")
end

-- 保存测试结果
session:saveTest({
    timestamp = os.time(),
    metrics   = { fps_avg = 55, action_count = 30, time_survived = 40 },
    verdict   = { result = "Human", confidence = "High" },
    gameType  = "Puzzle",
})

-- 查看最新记录
local latest = session:getLatest()
if latest then
    log:Write(LOG_INFO, "Latest verdict: " .. latest.verdict.result)
end

-- 遍历历史
local history = session:getHistory()
for i = 1, #history do
    local record = history[i]
    log:Write(LOG_INFO, string.format("Record %d: %s at %d",
        i, record.verdict.result, record.timestamp))
end

-- 设置和获取游戏上下文
session:setContext({
    gameName = "My Puzzle Game",
    gameType = "Puzzle",
    difficulty = "Hard",
})
local ctx = session:getContext()

-- 保存到文件
session:saveToFile("test_history.json")

-- 导出 JSON 字符串（用于其他用途）
local jsonStr = session:exportJSON()

-- 清除全部历史
session:clear()
```

---

## 6. NanoVG 仪表盘叠加

> 将 ReportBuilder 的可视化仪表盘叠加到任意游戏画面上。
> 注意：NanoVG 绘制必须在 NanoVGRender 事件中，nvgCreateFont 只调用一次。

```lua
local GameMetricsCollector = require "scripts.testing.GameMetricsCollector"
local HumanVsAIDetector    = require "scripts.testing.HumanVsAIDetector"
local ReportBuilder        = require "scripts.testing.ReportBuilder"

local collector     = GameMetricsCollector.new()
local reportBuilder = ReportBuilder.new()
local vg
local lastVerdict
local dashboardVisible = false

function Start()
    -- ... 游戏初始化 ...

    vg = nvgCreate(0)

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    collector:update(dt)

    -- ... 游戏逻辑，调用 collector:recordAction/recordScore/recordError ...
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- Tab 键切换仪表盘
    if key == KEY_TAB then
        dashboardVisible = not dashboardVisible

        -- 切换显示时更新人机判别
        if dashboardVisible then
            local metrics = collector:getSnapshot()
            local detector = HumanVsAIDetector.new()
            lastVerdict = detector:analyze(metrics)
        end
    end
end

function HandleNanoVGRender(eventType, eventData)
    if not dashboardVisible then return end

    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()

    nvgBeginFrame(vg, w, h, 1.0)

    -- 右上角仪表盘
    local panelW = 300
    local panelH = 320
    local metrics = collector:getSnapshot()
    reportBuilder:drawDashboard(vg, w - panelW - 12, 12, panelW, panelH, metrics, lastVerdict)

    nvgEndFrame(vg)
end
```

---

## 7. TestRunner 一键集成

> 封装所有模块为一个 TestRunner 入口，最少代码量集成。

```lua
-- scripts/testing/TestRunner.lua
-- 一键测试入口：自动初始化所有模块

local GameTypeDetector     = require "scripts.testing.GameTypeDetector"
local GameMetricsCollector = require "scripts.testing.GameMetricsCollector"
local HumanVsAIDetector    = require "scripts.testing.HumanVsAIDetector"
local SessionManager       = require "scripts.testing.SessionManager"
local ReportBuilder        = require "scripts.testing.ReportBuilder"

local TestRunner = {}
TestRunner.__index = TestRunner

--- 创建一键测试入口
---@param opts table { gameTitle: string, gameTags: string[], savePath?: string }
---@return table runner
function TestRunner.new(opts)
    local self = setmetatable({}, TestRunner)

    self.collector     = GameMetricsCollector.new()
    self.session       = SessionManager.new({ maxHistory = 50 })
    self.reportBuilder = ReportBuilder.new()
    self.savePath      = opts.savePath or "test_sessions.json"

    -- 自动识别游戏类型
    local detector = GameTypeDetector.new()
    self.gameType = detector:detect({
        title = opts.gameTitle or "Unknown Game",
        tags  = opts.gameTags or {},
    })

    -- 尝试加载历史
    self.session:loadFromFile(self.savePath)

    -- 设置上下文
    self.session:setContext({
        gameName  = opts.gameTitle,
        gameType  = self.gameType.primary_type,
        startTime = os.time(),
    })

    self.lastVerdict    = nil
    self.dashboardVisible = false
    self.vg             = nil

    return self
end

--- 初始化 NanoVG（在 Start 中调用）
function TestRunner:initNVG()
    self.vg = nvgCreate(0)
end

--- 每帧更新（在 HandleUpdate 中调用）
---@param dt number
function TestRunner:update(dt)
    self.collector:update(dt)
end

--- 记录玩家操作
---@param actionType string
function TestRunner:recordAction(actionType)
    self.collector:recordAction(actionType)
end

--- 记录得分
---@param score number
function TestRunner:recordScore(score)
    self.collector:recordScore(score)
end

--- 记录错误
---@param errorType string
function TestRunner:recordError(errorType)
    self.collector:recordError(errorType)
end

--- 生成报告并保存
---@return string textReport, table verdict
function TestRunner:generateReport()
    local metrics = self.collector:getSnapshot()
    local detector = HumanVsAIDetector.new()
    self.lastVerdict = detector:analyze(metrics, self.gameType.primary_type)

    local text = self.reportBuilder:buildText(metrics, self.lastVerdict, self.gameType)

    self.session:saveTest({
        timestamp = os.time(),
        metrics   = metrics,
        verdict   = self.lastVerdict,
        gameType  = self.gameType,
    })
    self.session:saveToFile(self.savePath)

    return text, self.lastVerdict
end

--- 切换仪表盘显示
function TestRunner:toggleDashboard()
    self.dashboardVisible = not self.dashboardVisible
    if self.dashboardVisible then
        local metrics = self.collector:getSnapshot()
        local detector = HumanVsAIDetector.new()
        self.lastVerdict = detector:analyze(metrics, self.gameType.primary_type)
    end
end

--- NanoVG 渲染仪表盘（在 NanoVGRender 事件中调用）
---@param screenW number 逻辑屏幕宽度
---@param screenH number 逻辑屏幕高度
function TestRunner:renderDashboard(screenW, screenH)
    if not self.dashboardVisible or not self.vg then return end

    nvgBeginFrame(self.vg, screenW, screenH, 1.0)
    local panelW = 300
    local panelH = 320
    local metrics = self.collector:getSnapshot()
    self.reportBuilder:drawDashboard(
        self.vg, screenW - panelW - 12, 12,
        panelW, panelH, metrics, self.lastVerdict
    )
    nvgEndFrame(self.vg)
end

--- 重置（新一局）
function TestRunner:reset()
    self.collector:reset()
    self.lastVerdict = nil
end

return TestRunner
```

### TestRunner 使用示例

> 在游戏中只需 5 行代码集成全部测试功能。

```lua
-- scripts/main.lua
require "LuaScripts/Utilities/Sample"
local TestRunner = require "scripts.testing.TestRunner"

local runner

function Start()
    SampleStart()

    -- 一行初始化
    runner = TestRunner.new({
        gameTitle = "My Cool Game",
        gameTags  = { "platformer", "action", "3d" },
    })
    runner:initNVG()

    -- ... 游戏场景初始化 ...

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    runner:update(dt)

    -- 在游戏逻辑中记录操作
    if input:GetKeyDown(KEY_SPACE) then
        runner:recordAction("jump")
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_F5 then
        local text, verdict = runner:generateReport()
        log:Write(LOG_INFO, "\n" .. text)
    end

    if key == KEY_F6 then
        runner:toggleDashboard()
    end
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()
    runner:renderDashboard(w, h)
end
```

---

## 约束检查清单

所有示例均遵守以下引擎规则：

- [x] 代码放在 `scripts/` 目录
- [x] NanoVG 绘制在 `NanoVGRender` 事件中
- [x] `nvgCreateFont` 只调用一次（ReportBuilder:initFont 内部防重复）
- [x] 数组索引从 1 开始（`for i = 1, #arr`）
- [x] 使用枚举常量（`KEY_F5`, `KEY_SPACE`, `KEY_ESCAPE`）
- [x] 文件读写用 `File` API（非 `io` 库）
- [x] 不调用 `SetMode()`，使用 `GetWidth()/GetHeight()/GetDPR()`
- [x] `eventData` 使用 `["Key"]:GetInt()` 模式
