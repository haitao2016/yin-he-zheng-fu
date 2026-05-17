# 模块实现 — Auto Game Vision Tester

> 六大模块的完整 Lua 实现代码。

---

## §1 VisionConfig — 测试配置管理

```lua
------------------------------------------------------------
-- VisionConfig: 视觉测试配置管理
-- 对应原始 config.json
------------------------------------------------------------
local VisionConfig = {}
VisionConfig.__index = VisionConfig

--- 默认配置
local DEFAULTS = {
    -- 帧捕获
    captureInterval = 2.0,
    hashThreshold = 18,

    -- 分析
    mode = "balanced",         -- "quick" / "balanced" / "deep"
    fpsThreshold = 25,
    overlapDistance = 0.01,
    maxDrawCalls = 200,

    -- 报告
    maxHistory = 50,
    showOverlay = true,
    overlayPosition = "top-right",

    -- 热键
    triggerKey = KEY_F9,
}

function VisionConfig.Create(overrides)
    local self = setmetatable({}, VisionConfig)
    self.values = {}
    -- 合并默认值与自定义覆盖
    for k, v in pairs(DEFAULTS) do
        self.values[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            self.values[k] = v
        end
    end
    return self
end

function VisionConfig:Get(key)
    return self.values[key]
end

function VisionConfig:Set(key, value)
    self.values[key] = value
end

function VisionConfig:GetMode()
    return self.values.mode
end

function VisionConfig:SetMode(newMode)
    if newMode == "quick" or newMode == "balanced" or newMode == "deep" then
        self.values.mode = newMode
    end
end

return VisionConfig
```

---

## §2 FrameCaptureEngine — 帧采样与去重

```lua
------------------------------------------------------------
-- FrameCaptureEngine: 帧采样 + 感知哈希去重
-- 对应原始 capture.py + main.py 的 capture_loop
------------------------------------------------------------
local FrameCaptureEngine = {}
FrameCaptureEngine.__index = FrameCaptureEngine

function FrameCaptureEngine.Create(scene, config)
    local self = setmetatable({}, FrameCaptureEngine)
    self.scene = scene
    self.config = config
    self.timer = 0
    self.capturedFrames = {}
    self.lastHash = 0
    self.captureCount = 0
    self.skipCount = 0
    self.startTime = time:GetElapsedTime()
    return self
end

--- 帧特征哈希（替代 imagehash）
-- 使用 FPS + 节点数 + 可见模型数构建指纹
function FrameCaptureEngine:ComputeFrameHash()
    local fps = engine:GetFps()
    local nodeCount = 0
    local modelCount = 0

    -- 遍历场景统计
    local function countNodes(node)
        nodeCount = nodeCount + 1
        local sm = node:GetComponent("StaticModel")
        if sm then
            modelCount = modelCount + 1
        end
        local am = node:GetComponent("AnimatedModel")
        if am then
            modelCount = modelCount + 1
        end
        for i = 0, node:GetNumChildren(false) - 1 do
            countNodes(node:GetChild(i))
        end
    end

    if self.scene then
        countNodes(self.scene)
    end

    -- 组合哈希：FPS 区间 + 节点数 + 模型数
    local fpsSlot = math.floor(fps / 5)
    local hash = fpsSlot * 10000 + nodeCount * 100 + modelCount
    return hash
end

--- 计算两个哈希之间的差异
function FrameCaptureEngine:HashDifference(hash1, hash2)
    return math.abs(hash1 - hash2)
end

--- 采集当前帧数据快照
function FrameCaptureEngine:CaptureSnapshot()
    local snapshot = {
        timestamp = time:GetElapsedTime(),
        fps = engine:GetFps(),
        nodeCount = 0,
        modelCount = 0,
        nodes = {},  -- 节点位置快照（用于重叠检测）
    }

    local function gatherData(node)
        snapshot.nodeCount = snapshot.nodeCount + 1
        local sm = node:GetComponent("StaticModel")
        local am = node:GetComponent("AnimatedModel")
        if sm or am then
            snapshot.modelCount = snapshot.modelCount + 1
            local pos = node:GetWorldPosition()
            table.insert(snapshot.nodes, {
                name = node.name,
                position = { x = pos.x, y = pos.y, z = pos.z },
                hasModel = true,
                hasMaterial = sm and (sm:GetNumGeometries() > 0) or true,
            })
        else
            -- 记录空节点
            local numComponents = node:GetNumComponents()
            if numComponents == 0 and node:GetNumChildren(false) == 0 then
                table.insert(snapshot.nodes, {
                    name = node.name,
                    position = nil,
                    hasModel = false,
                    isEmpty = true,
                })
            end
        end
        for i = 0, node:GetNumChildren(false) - 1 do
            gatherData(node:GetChild(i))
        end
    end

    if self.scene then
        gatherData(self.scene)
    end

    return snapshot
end

--- 每帧更新
function FrameCaptureEngine:Update(dt)
    self.timer = self.timer + dt
    local interval = self.config:Get("captureInterval")
    if self.timer < interval then
        return
    end
    self.timer = self.timer - interval

    -- 计算当前帧哈希
    local currentHash = self:ComputeFrameHash()
    local diff = self:HashDifference(currentHash, self.lastHash)
    local threshold = self.config:Get("hashThreshold")

    if diff < threshold and self.captureCount > 0 then
        -- 静态帧，跳过
        self.skipCount = self.skipCount + 1
        return
    end

    -- 差异足够大，捕获帧数据
    self.lastHash = currentHash
    self.captureCount = self.captureCount + 1
    local snapshot = self:CaptureSnapshot()
    table.insert(self.capturedFrames, snapshot)
end

--- 获取已捕获帧列表
function FrameCaptureEngine:GetCapturedFrames()
    return self.capturedFrames
end

--- 清空已捕获帧
function FrameCaptureEngine:ClearFrames()
    self.capturedFrames = {}
end

--- 获取统计信息
function FrameCaptureEngine:GetStats()
    return {
        captured = self.captureCount,
        skipped = self.skipCount,
        queued = #self.capturedFrames,
        runtime = time:GetElapsedTime() - self.startTime,
    }
end

return FrameCaptureEngine
```

---

## §3 VisualAnalyzer — 基于规则的视觉分析

```lua
------------------------------------------------------------
-- VisualAnalyzer: 多维度视觉质量分析
-- 对应原始 grok_vision.py 的分析 prompt 逻辑
------------------------------------------------------------
local VisualAnalyzer = {}
VisualAnalyzer.__index = VisualAnalyzer

function VisualAnalyzer.Create(config)
    local self = setmetatable({}, VisualAnalyzer)
    self.config = config
    return self
end

--- 检测帧率骤降 (Critical)
local function checkFpsDrop(snapshot, config)
    local issues = {}
    local threshold = config:Get("fpsThreshold")
    if snapshot.fps < threshold then
        table.insert(issues, {
            severity = "critical",
            category = "Performance",
            desc = string.format(
                "FPS dropped to %.0f (threshold: %d)",
                snapshot.fps, threshold
            ),
            detail = string.format(
                "Nodes: %d, Models: %d — scene may be too complex",
                snapshot.nodeCount, snapshot.modelCount
            ),
        })
    end
    return issues
end

--- 检测节点位置重叠 / Z-fighting 风险 (Critical)
local function checkNodeOverlap(snapshot, config)
    local issues = {}
    local dist = config:Get("overlapDistance")
    local modelNodes = {}
    for _, n in ipairs(snapshot.nodes) do
        if n.hasModel and n.position then
            table.insert(modelNodes, n)
        end
    end
    for i = 1, #modelNodes do
        for j = i + 1, #modelNodes do
            local a = modelNodes[i].position
            local b = modelNodes[j].position
            local dx = a.x - b.x
            local dy = a.y - b.y
            local dz = a.z - b.z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d < dist then
                table.insert(issues, {
                    severity = "critical",
                    category = "Z-Fighting Risk",
                    desc = string.format(
                        "Nodes '%s' and '%s' overlap (distance: %.4f m)",
                        modelNodes[i].name, modelNodes[j].name, d
                    ),
                    detail = "Two opaque models at nearly identical positions cause Z-fighting",
                })
            end
        end
    end
    return issues
end

--- 检测材质缺失 (Medium)
local function checkMissingMaterials(snapshot)
    local issues = {}
    for _, n in ipairs(snapshot.nodes) do
        if n.hasModel and not n.hasMaterial then
            table.insert(issues, {
                severity = "medium",
                category = "Material",
                desc = string.format("Node '%s' has no material assigned", n.name),
                detail = "Model renders with default magenta, visually broken",
            })
        end
    end
    return issues
end

--- 检测过多模型节点 (Medium)
local function checkDrawCallOverload(snapshot, config)
    local issues = {}
    local maxDC = config:Get("maxDrawCalls")
    if snapshot.modelCount > maxDC then
        table.insert(issues, {
            severity = "medium",
            category = "Performance",
            desc = string.format(
                "High model count: %d (threshold: %d)",
                snapshot.modelCount, maxDC
            ),
            detail = "Too many draw calls may cause performance degradation",
        })
    end
    return issues
end

--- 检测空节点冗余 (Low)
local function checkEmptyNodes(snapshot)
    local issues = {}
    local emptyCount = 0
    for _, n in ipairs(snapshot.nodes) do
        if n.isEmpty then
            emptyCount = emptyCount + 1
        end
    end
    if emptyCount > 20 then
        table.insert(issues, {
            severity = "low",
            category = "Optimization",
            desc = string.format("%d empty nodes in scene", emptyCount),
            detail = "Consider cleaning up unused nodes to reduce scene complexity",
        })
    end
    return issues
end

--- 执行分析
function VisualAnalyzer:Analyze(frames, modeOverride)
    local mode = modeOverride or self.config:GetMode()
    local results = {
        mode = mode,
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        critical = {},
        medium = {},
        low = {},
        framesAnalyzed = #frames,
        summary = { critical = 0, medium = 0, low = 0, fpsAvg = 0 },
    }

    local fpsSum = 0

    for _, snapshot in ipairs(frames) do
        fpsSum = fpsSum + snapshot.fps

        -- Quick: 仅 Critical
        local fpsIssues = checkFpsDrop(snapshot, self.config)
        for _, issue in ipairs(fpsIssues) do
            table.insert(results.critical, issue)
        end

        local overlapIssues = checkNodeOverlap(snapshot, self.config)
        for _, issue in ipairs(overlapIssues) do
            table.insert(results.critical, issue)
        end

        -- Balanced: + Medium
        if mode == "balanced" or mode == "deep" then
            local matIssues = checkMissingMaterials(snapshot)
            for _, issue in ipairs(matIssues) do
                table.insert(results.medium, issue)
            end

            local dcIssues = checkDrawCallOverload(snapshot, self.config)
            for _, issue in ipairs(dcIssues) do
                table.insert(results.medium, issue)
            end
        end

        -- Deep: + Low
        if mode == "deep" then
            local emptyIssues = checkEmptyNodes(snapshot)
            for _, issue in ipairs(emptyIssues) do
                table.insert(results.low, issue)
            end
        end
    end

    results.summary.critical = #results.critical
    results.summary.medium = #results.medium
    results.summary.low = #results.low
    if #frames > 0 then
        results.summary.fpsAvg = fpsSum / #frames
    end

    return results
end

return VisualAnalyzer
```

---

## §4 ReportRenderer — NanoVG 报告面板

```lua
------------------------------------------------------------
-- ReportRenderer: NanoVG 实时报告面板
-- 对应原始 report.py 的 HTML 报告生成
-- 注意：所有 NanoVG 绘制必须在 NanoVGRender 事件中执行
------------------------------------------------------------
local ReportRenderer = {}
ReportRenderer.__index = ReportRenderer

-- 颜色定义（对应原始 HTML 报告样式）
local COLORS = {
    bg       = { 15, 15, 26, 230 },      -- #0f0f1a
    header   = { 26, 26, 46, 255 },      -- #1a1a2e
    critical = { 255, 107, 107, 255 },   -- #ff6b6b
    medium   = { 255, 217, 61, 255 },    -- #ffd93d
    low      = { 107, 203, 119, 255 },   -- #6bcb77
    text     = { 224, 224, 224, 255 },   -- #e0e0e0
    accent   = { 152, 255, 152, 255 },   -- #98FF98
    summary  = { 22, 33, 62, 255 },      -- #16213e
}

function ReportRenderer.Create(vg)
    local self = setmetatable({}, ReportRenderer)
    self.vg = vg
    self.report = nil
    self.showReport = false
    self.showOverlay = true
    self.overlayStats = nil
    self.scrollY = 0

    -- 字体必须在初始化时创建一次（规则 #7）
    self.fontNormal = nvgCreateFont(vg, "report-sans", "Fonts/MiSans-Regular.ttf")

    return self
end

--- 绘制实时浮层（捕获状态）
function ReportRenderer:DrawOverlay(vg, w, h, stats)
    if not self.showOverlay or not stats then return end

    local ox = w - 220
    local oy = 10
    local ow = 210
    local oh = 80

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox, oy, ow, oh, 8)
    nvgFillColor(vg, nvgRGBA(COLORS.header[1], COLORS.header[2], COLORS.header[3], COLORS.header[4]))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "report-sans")
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], COLORS.accent[4]))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(vg, ox + 10, oy + 8, "Vision Tester")

    -- 统计
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4]))
    nvgText(vg, ox + 10, oy + 28,
        string.format("Captured: %d  Skipped: %d", stats.captured, stats.skipped))
    nvgText(vg, ox + 10, oy + 44,
        string.format("Queued: %d", stats.queued))
    nvgText(vg, ox + 10, oy + 60,
        string.format("Runtime: %.0fs  [F9] Analyze", stats.runtime))
end

--- 绘制严重性图标
local function drawSeverityBadge(vg, x, y, severity)
    local color
    local label
    if severity == "critical" then
        color = COLORS.critical
        label = "CRIT"
    elseif severity == "medium" then
        color = COLORS.medium
        label = "MED"
    else
        color = COLORS.low
        label = "LOW"
    end

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, 40, 18, 4)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 200))
    nvgFill(vg)

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, x + 20, y + 9, label)
end

--- 绘制完整报告面板
function ReportRenderer:DrawReport(vg, w, h)
    if not self.showReport or not self.report then return end

    local pw = math.min(600, w - 40)
    local px = (w - pw) / 2
    local py = 20 - self.scrollY
    local lineH = 20

    -- 背景遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, h - 40, 12)
    nvgFillColor(vg, nvgRGBA(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4]))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "report-sans")
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(vg, px + pw / 2, py + 16, "Vision QA Report")

    -- 模式与时间
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 200))
    nvgText(vg, px + pw / 2, py + 44,
        string.format("Mode: %s | %s | Frames: %d",
            string.upper(self.report.mode),
            self.report.timestamp,
            self.report.framesAnalyzed))

    local curY = py + 75

    -- 摘要条
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px + 16, curY, pw - 32, 50, 8)
    nvgFillColor(vg, nvgRGBA(COLORS.summary[1], COLORS.summary[2], COLORS.summary[3], 255))
    nvgFill(vg)

    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local s = self.report.summary
    -- Critical 数量
    nvgFillColor(vg, nvgRGBA(COLORS.critical[1], COLORS.critical[2], COLORS.critical[3], 255))
    nvgText(vg, px + 30, curY + 8, string.format("Critical: %d", s.critical))
    -- Medium 数量
    nvgFillColor(vg, nvgRGBA(COLORS.medium[1], COLORS.medium[2], COLORS.medium[3], 255))
    nvgText(vg, px + 160, curY + 8, string.format("Medium: %d", s.medium))
    -- Low 数量
    nvgFillColor(vg, nvgRGBA(COLORS.low[1], COLORS.low[2], COLORS.low[3], 255))
    nvgText(vg, px + 280, curY + 8, string.format("Low: %d", s.low))
    -- FPS
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 255))
    nvgText(vg, px + 30, curY + 28, string.format("Avg FPS: %.1f", s.fpsAvg))

    curY = curY + 65

    -- 渲染各级别问题列表
    local function drawIssueList(title, issues, color)
        if #issues == 0 then return end
        nvgFontSize(vg, 16)
        nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 255))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(vg, px + 20, curY, title)
        curY = curY + 24

        nvgFontSize(vg, 13)
        for _, issue in ipairs(issues) do
            drawSeverityBadge(vg, px + 24, curY, issue.severity)
            nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 255))
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgText(vg, px + 70, curY + 2, issue.desc)
            curY = curY + lineH
            if issue.detail then
                nvgFontSize(vg, 11)
                nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 140))
                nvgText(vg, px + 70, curY, issue.detail)
                curY = curY + lineH - 4
                nvgFontSize(vg, 13)
            end
        end
        curY = curY + 10
    end

    drawIssueList("Critical Issues", self.report.critical, COLORS.critical)
    drawIssueList("Medium Issues", self.report.medium, COLORS.medium)
    drawIssueList("Low Issues", self.report.low, COLORS.low)

    -- 关闭提示
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 120))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(vg, px + pw / 2, curY + 10, "Press [F9] to close report")
end

--- 设置报告数据
function ReportRenderer:SetReport(report)
    self.report = report
    self.showReport = true
    self.scrollY = 0
end

--- 切换报告显示
function ReportRenderer:ToggleReport()
    self.showReport = not self.showReport
end

--- 设置浮层统计
function ReportRenderer:SetOverlayStats(stats)
    self.overlayStats = stats
end

--- 主绘制入口（在 NanoVGRender 事件中调用）
function ReportRenderer:Draw(vg, w, h)
    self:DrawOverlay(vg, w, h, self.overlayStats)
    self:DrawReport(vg, w, h)
end

return ReportRenderer
```

---

## §5 HistoryManager — 测试历史持久化

```lua
------------------------------------------------------------
-- HistoryManager: JSON 测试历史持久化
-- 对应原始 main.py 的 save_to_history / view_history
-- 使用 File API（不使用 io 库）
------------------------------------------------------------
local cjson = require("cjson")

local HistoryManager = {}
HistoryManager.__index = HistoryManager

local HISTORY_PATH = "vision_test/history.json"

function HistoryManager.Create(maxRecords)
    local self = setmetatable({}, HistoryManager)
    self.maxRecords = maxRecords or 50
    self.records = {}
    self:Load()
    return self
end

--- 从文件加载历史
function HistoryManager:Load()
    if not fileSystem:FileExists(HISTORY_PATH) then
        self.records = {}
        return
    end
    local file = File:new(HISTORY_PATH, FILE_READ)
    local content = file:ReadString()
    file:Close()
    local ok, data = pcall(cjson.decode, content)
    if ok and type(data) == "table" then
        self.records = data
    else
        self.records = {}
    end
end

--- 保存历史到文件
function HistoryManager:Save()
    -- 确保目录存在
    fileSystem:CreateDir("vision_test")
    local file = File:new(HISTORY_PATH, FILE_WRITE)
    file:WriteString(cjson.encode(self.records))
    file:Close()
end

--- 添加新记录
function HistoryManager:AddRecord(report)
    local record = {
        timestamp = report.timestamp,
        mode = report.mode,
        framesAnalyzed = report.framesAnalyzed,
        critical = report.summary.critical,
        medium = report.summary.medium,
        low = report.summary.low,
        fpsAvg = report.summary.fpsAvg,
        totalIssues = report.summary.critical + report.summary.medium + report.summary.low,
    }
    table.insert(self.records, record)
    -- 保持最大记录数
    while #self.records > self.maxRecords do
        table.remove(self.records, 1)
    end
    self:Save()
end

--- 获取所有历史记录
function HistoryManager:GetRecords()
    return self.records
end

--- 获取最近 N 条记录
function HistoryManager:GetRecent(n)
    local count = math.min(n, #self.records)
    local recent = {}
    for i = #self.records - count + 1, #self.records do
        table.insert(recent, self.records[i])
    end
    return recent
end

--- 清空历史
function HistoryManager:Clear()
    self.records = {}
    self:Save()
end

return HistoryManager
```

---

## §6 TestRunner — 测试编排入口

```lua
------------------------------------------------------------
-- TestRunner (VisionTester): 测试编排入口
-- 对应原始 main.py 的 main_menu / run_preview_mode
-- 整合所有模块，提供统一的 API
------------------------------------------------------------
local VisionConfig = require("scripts.VisionConfig")
local FrameCaptureEngine = require("scripts.FrameCaptureEngine")
local VisualAnalyzer = require("scripts.VisualAnalyzer")
local ReportRenderer = require("scripts.ReportRenderer")
local HistoryManager = require("scripts.HistoryManager")

local VisionTester = {}
VisionTester.__index = VisionTester

function VisionTester.Create(scene, vg, overrides)
    local self = setmetatable({}, VisionTester)

    -- 初始化配置
    self.config = VisionConfig.Create(overrides)

    -- 初始化各模块
    self.capture = FrameCaptureEngine.Create(scene, self.config)
    self.analyzer = VisualAnalyzer.Create(self.config)
    self.renderer = ReportRenderer.Create(vg)
    self.history = HistoryManager.Create(self.config:Get("maxHistory"))

    self.lastReport = nil
    self.isRunning = true

    log:Write(LOG_INFO, "VisionTester initialized — mode: " .. self.config:GetMode())
    return self
end

--- 每帧更新（在 HandleUpdate 中调用）
function VisionTester:Update(dt)
    if not self.isRunning then return end

    -- 驱动帧捕获
    self.capture:Update(dt)

    -- 更新浮层统计
    self.renderer:SetOverlayStats(self.capture:GetStats())

    -- 检测热键触发
    local triggerKey = self.config:Get("triggerKey")
    if input:GetKeyPress(triggerKey) then
        if self.renderer.showReport then
            -- 报告已显示，关闭它
            self.renderer:ToggleReport()
        else
            -- 运行分析
            self:RunAnalysis()
        end
    end
end

--- 执行分析
function VisionTester:RunAnalysis(modeOverride)
    local frames = self.capture:GetCapturedFrames()
    if #frames == 0 then
        log:Write(LOG_WARNING, "VisionTester: No frames captured yet")
        return nil
    end

    log:Write(LOG_INFO, string.format(
        "VisionTester: Analyzing %d frames (mode: %s)",
        #frames, modeOverride or self.config:GetMode()))

    -- 执行分析
    local report = self.analyzer:Analyze(frames, modeOverride)

    -- 保存结果
    self.lastReport = report
    self.history:AddRecord(report)

    -- 显示报告
    self.renderer:SetReport(report)

    -- 清空已分析帧
    self.capture:ClearFrames()

    log:Write(LOG_INFO, string.format(
        "VisionTester: Analysis complete — C:%d M:%d L:%d",
        report.summary.critical, report.summary.medium, report.summary.low))

    return report
end

--- NanoVG 绘制（在 NanoVGRender 事件中调用）
function VisionTester:Draw(vg, w, h)
    self.renderer:Draw(vg, w, h)
end

--- 获取最近一次报告
function VisionTester:GetLastReport()
    return self.lastReport
end

--- 获取历史记录
function VisionTester:GetHistory()
    return self.history:GetRecords()
end

--- 切换分析模式
function VisionTester:SetMode(mode)
    self.config:SetMode(mode)
end

--- 暂停/恢复测试
function VisionTester:SetRunning(running)
    self.isRunning = running
end

return VisionTester
```
