# 集成示例 — Auto Game Vision Tester

> 将视觉测试框架集成到不同类型游戏的完整示例。

---

## §1 3D 场景游戏集成

完整示例：在 3D 场景中启用视觉质量自动测试。

```lua
-- scripts/main.lua
-- 3D 游戏 + 视觉测试集成示例

require "LuaScripts/Utilities/Sample"

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local vg = nil

-- 视觉测试模块
local VisionTester = nil
local tester = nil

function Start()
    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    local physicsWorld = scene_:CreateComponent("PhysicsWorld")

    -- 灯光
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.brightness = 1.0

    -- 地面
    local floorNode = scene_:CreateChild("Floor")
    floorNode.position = Vector3(0, 0, 0)
    floorNode.scale = Vector3(50, 1, 50)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local floorBody = floorNode:CreateComponent("RigidBody")
    local floorShape = floorNode:CreateComponent("CollisionShape")
    floorShape:SetBox(Vector3.ONE)

    -- 测试物体
    for i = 1, 10 do
        local boxNode = scene_:CreateChild("Box_" .. i)
        boxNode.position = Vector3(
            math.random(-10, 10),
            math.random(1, 5),
            math.random(-10, 10)
        )
        local boxModel = boxNode:CreateComponent("StaticModel")
        boxModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    end

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 10, -15)
    cameraNode_:LookAt(Vector3(0, 0, 0))
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 300.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- NanoVG
    vg = nvgCreate(NVG_ANTIALIAS + NVG_STENCIL_STROKES)

    -- 初始化视觉测试
    VisionTester = require("scripts.VisionTester")
    tester = VisionTester.Create(scene_, vg, {
        mode = "balanced",
        captureInterval = 2.0,
        fpsThreshold = 25,
        showOverlay = true,
    })

    -- 事件注册
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    tester:Update(dt)
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()
    nvgBeginFrame(vg, w, h, graphics:GetDPR())
    tester:Draw(vg, w, h)
    nvgEndFrame(vg)
end
```

---

## §2 分析模式切换

运行时动态切换分析深度。

```lua
-- 快速冒烟测试
tester:SetMode("quick")
tester:RunAnalysis()

-- 日常平衡分析
tester:SetMode("balanced")
tester:RunAnalysis()

-- 发布前深度检查
tester:SetMode("deep")
tester:RunAnalysis()

-- 单次覆盖模式（不改变默认设置）
tester:RunAnalysis("deep")
```

---

## §3 历史趋势对比

访问和对比测试历史。

```lua
-- 获取最近 10 条历史
local recent = tester.history:GetRecent(10)

for i, record in ipairs(recent) do
    log:Write(LOG_INFO, string.format(
        "[%d] %s — Mode: %s | C:%d M:%d L:%d | FPS: %.1f",
        i, record.timestamp, record.mode,
        record.critical, record.medium, record.low,
        record.fpsAvg
    ))
end

-- 计算趋势：最近 5 次 Critical 问题数
local last5 = tester.history:GetRecent(5)
local criticalTrend = {}
for _, r in ipairs(last5) do
    table.insert(criticalTrend, r.critical)
end
-- criticalTrend = {3, 2, 1, 0, 0} → 问题在减少，质量在提升
```

---

## §4 自定义分析规则扩展

在 VisualAnalyzer 中添加自定义检测规则。

```lua
-- 在 VisualAnalyzer 模块中扩展自定义检查
-- 例如：检测相机近裁剪面是否过大

local function checkCameraNearClip(snapshot)
    local issues = {}
    -- 此检查需要在 snapshot 中记录相机参数
    -- 可在 FrameCaptureEngine:CaptureSnapshot() 中添加相机数据
    if snapshot.cameraNearClip and snapshot.cameraNearClip > 1.0 then
        table.insert(issues, {
            severity = "low",
            category = "Camera",
            desc = string.format("Near clip plane too far: %.2f", snapshot.cameraNearClip),
            detail = "Objects close to camera may be clipped unexpectedly",
        })
    end
    return issues
end

-- 然后在 VisualAnalyzer:Analyze() 的 Deep 模式分支中添加调用
```

---

## §5 与游戏暂停菜单集成

在暂停菜单中添加视觉测试控制按钮。

```lua
local UI = require("urhox-libs/UI")

-- 创建视觉测试控制 UI
local function createVisionTestUI(tester)
    local panel = UI.Panel {
        position = "absolute", right = 10, bottom = 10,
        width = 200, padding = 10,
        backgroundColor = "rgba(0,0,0,0.8)",
        children = {
            UI.Label {
                text = "Vision Tester",
                fontSize = 16, color = "#98FF98",
                marginBottom = 8,
            },
            UI.Button {
                text = "Quick Scan", variant = "primary",
                onClick = function()
                    tester:SetMode("quick")
                    tester:RunAnalysis()
                end,
            },
            UI.Button {
                text = "Balanced Scan", marginTop = 4,
                onClick = function()
                    tester:SetMode("balanced")
                    tester:RunAnalysis()
                end,
            },
            UI.Button {
                text = "Deep Scan", marginTop = 4,
                onClick = function()
                    tester:SetMode("deep")
                    tester:RunAnalysis()
                end,
            },
            UI.Button {
                text = "Clear History", marginTop = 8,
                onClick = function()
                    tester.history:Clear()
                end,
            },
        },
    }
    return panel
end
```

---

## §6 报告数据导出

将分析报告以 JSON 格式导出到文件。

```lua
local cjson = require("cjson")

-- 导出最近一次分析报告
local function exportReport(tester)
    local report = tester:GetLastReport()
    if not report then
        log:Write(LOG_WARNING, "No report to export")
        return
    end

    local exportData = {
        timestamp = report.timestamp,
        mode = report.mode,
        framesAnalyzed = report.framesAnalyzed,
        summary = report.summary,
        issues = {
            critical = {},
            medium = {},
            low = {},
        },
    }

    for _, issue in ipairs(report.critical) do
        table.insert(exportData.issues.critical, {
            category = issue.category,
            description = issue.desc,
            detail = issue.detail,
        })
    end
    for _, issue in ipairs(report.medium) do
        table.insert(exportData.issues.medium, {
            category = issue.category,
            description = issue.desc,
            detail = issue.detail,
        })
    end
    for _, issue in ipairs(report.low) do
        table.insert(exportData.issues.low, {
            category = issue.category,
            description = issue.desc,
            detail = issue.detail,
        })
    end

    fileSystem:CreateDir("vision_test")
    local filename = string.format("vision_test/report_%s.json",
        os.date("%Y%m%d_%H%M%S"))
    local file = File:new(filename, FILE_WRITE)
    file:WriteString(cjson.encode(exportData))
    file:Close()

    log:Write(LOG_INFO, "Report exported to: " .. filename)
end
```
