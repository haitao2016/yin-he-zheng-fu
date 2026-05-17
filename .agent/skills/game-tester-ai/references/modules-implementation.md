# Game Tester AI — 模块完整实现

> 本文档包含 5 个测试模块的完整 Lua 实现代码。
> 所有代码遵循 UrhoX 引擎规则，可直接放入 `scripts/testing/` 使用。

---

## 目录

1. [GameTypeDetector — 游戏类型识别](#1-gametypedetector)
2. [GameMetricsCollector — 运行时指标采集](#2-gamemetricscollector)
3. [HumanVsAIDetector — 人机行为判别](#3-humanvsaidetector)
4. [SessionManager — 会话管理](#4-sessionmanager)
5. [ReportBuilder — 报告生成](#5-reportbuilder)

---

## 1. GameTypeDetector

> 源自 `tester.py` 的 `detect_game_type()` 函数。
> 通过关键词匹配 + 权重评分识别游戏类型。

```lua
-- scripts/testing/GameTypeDetector.lua
-- 游戏类型识别器：基于关键词评分的 7 类游戏分类

local GameTypeDetector = {}
GameTypeDetector.__index = GameTypeDetector

--- 内置游戏类型关键词表（源自 tester.py GAME_TYPE_KEYWORDS）
local DEFAULT_KEYWORDS = {
    ["Endless Runner"]   = { "runner", "run", "jump", "obstacle", "dino", "endless", "dash" },
    ["Puzzle"]           = { "puzzle", "match", "block", "tetris", "2048", "sudoku", "jigsaw" },
    ["Card/Board"]       = { "chess", "card", "board", "solitaire", "checkers", "poker", "mahjong" },
    ["Action/Shooter"]   = { "shoot", "shooter", "bullet", "enemy", "kill", "combat", "attack" },
    ["Strategy"]         = { "strategy", "tower", "defense", "build", "upgrade", "command" },
    ["Sports"]           = { "football", "soccer", "basketball", "tennis", "golf", "cricket" },
    ["Racing"]           = { "race", "racing", "car", "drive", "speed", "drift", "track" },
}

--- 创建新的类型检测器
---@return table detector
function GameTypeDetector.new()
    local self = setmetatable({}, GameTypeDetector)
    -- 深拷贝默认关键词
    self.keywords = {}
    for typeName, words in pairs(DEFAULT_KEYWORDS) do
        self.keywords[typeName] = {}
        for i = 1, #words do
            self.keywords[typeName][i] = words[i]
        end
    end
    return self
end

--- 注册自定义游戏类型
---@param typeName string 类型名称
---@param words string[] 关键词列表
function GameTypeDetector:registerType(typeName, words)
    self.keywords[typeName] = words
end

--- 检测游戏类型
--- 源自 tester.py detect_game_type(): 合并标题+标签+描述，关键词计分
---@param info table { title?: string, tags?: string[], description?: string }
---@return table { primary_type: string, confidence: string, scores: table }
function GameTypeDetector:detect(info)
    -- 合并所有文本为小写
    local parts = {}
    if info.title then
        parts[#parts + 1] = string.lower(info.title)
    end
    if info.tags then
        for i = 1, #info.tags do
            parts[#parts + 1] = string.lower(info.tags[i])
        end
    end
    if info.description then
        parts[#parts + 1] = string.lower(info.description)
    end
    local combined = table.concat(parts, " ")

    -- 各类型评分
    local scores = {}
    local bestType = "Unknown"
    local bestScore = 0

    for typeName, words in pairs(self.keywords) do
        local score = 0
        for i = 1, #words do
            -- 统计关键词出现次数
            local word = words[i]
            local searchStart = 1
            while true do
                local found = string.find(combined, word, searchStart, true)
                if not found then break end
                score = score + 1
                searchStart = found + 1
            end
        end
        scores[typeName] = score
        if score > bestScore then
            bestScore = score
            bestType = typeName
        end
    end

    -- 计算置信度（源自 tester.py 的阈值逻辑）
    local confidence
    if bestScore >= 3 then
        confidence = "High"
    elseif bestScore >= 1 then
        confidence = "Medium"
    else
        confidence = "Low"
        bestType = "Unknown"
    end

    return {
        primary_type = bestType,
        confidence   = confidence,
        scores       = scores,
    }
end

return GameTypeDetector
```

---

## 2. GameMetricsCollector

> 源自 `tester.py` 的 `run_test()` 函数。
> 原版通过 HTTP 分析网页元素；本版在引擎内实时采集运行时指标。

```lua
-- scripts/testing/GameMetricsCollector.lua
-- 运行时指标采集器：FPS、操作频率、得分曲线、错误记录

local GameMetricsCollector = {}
GameMetricsCollector.__index = GameMetricsCollector

--- 创建新的指标采集器
---@return table collector
function GameMetricsCollector.new()
    local self = setmetatable({}, GameMetricsCollector)
    self:reset()
    return self
end

--- 重置所有指标
function GameMetricsCollector:reset()
    self.startTime     = 0
    self.totalTime      = 0
    self.frameCount     = 0
    self.fpsSum         = 0
    self.fpsMin         = 999
    self.fpsMax         = 0
    self.actionCount    = 0
    self.actions        = {}      -- { {type=string, time=number}, ... }
    self.scores         = {}      -- { number, ... }
    self.errors         = {}      -- { {type=string, time=number}, ... }
    self.errorCount     = 0
    self.started        = false
    -- 用于 FPS 计算的滑动窗口
    self.fpsWindow      = {}
    self.fpsWindowSize  = 60      -- 最近 60 帧的平均
    self.fpsWindowIdx   = 0
end

--- 开始采集（手动调用或首次 update 自动调用）
function GameMetricsCollector:start()
    self:reset()
    self.startTime = os.clock()
    self.started   = true
end

--- 每帧更新，采集 FPS 数据
--- 在 HandleUpdate 中调用，传入 deltaTime
---@param dt number 帧间隔时间（秒）
function GameMetricsCollector:update(dt)
    if not self.started then
        self:start()
    end

    self.totalTime  = self.totalTime + dt
    self.frameCount = self.frameCount + 1

    -- 计算当前帧 FPS
    local fps = (dt > 0) and (1.0 / dt) or 0

    -- 滑动窗口
    self.fpsWindowIdx = self.fpsWindowIdx + 1
    if self.fpsWindowIdx > self.fpsWindowSize then
        self.fpsWindowIdx = 1
    end
    self.fpsWindow[self.fpsWindowIdx] = fps

    -- 更新极值
    if fps < self.fpsMin then self.fpsMin = fps end
    if fps > self.fpsMax then self.fpsMax = fps end
    self.fpsSum = self.fpsSum + fps
end

--- 记录玩家操作
---@param actionType string 操作类型标签（如 "jump", "attack", "click"）
function GameMetricsCollector:recordAction(actionType)
    self.actionCount = self.actionCount + 1
    self.actions[#self.actions + 1] = {
        type = actionType or "action",
        time = self.totalTime,
    }
end

--- 记录得分
---@param score number 当前分数
function GameMetricsCollector:recordScore(score)
    self.scores[#self.scores + 1] = score
end

--- 记录错误/异常事件
---@param errorType string 错误类型描述
function GameMetricsCollector:recordError(errorType)
    self.errorCount = self.errorCount + 1
    self.errors[#self.errors + 1] = {
        type = errorType or "error",
        time = self.totalTime,
    }
end

--- 计算性能等级（源自 tester.py 的评级逻辑）
---@return string "High" | "Medium" | "Low"
function GameMetricsCollector:calcPerformanceRating()
    local fpsAvg = self:getAvgFPS()
    local hasScores = #self.scores > 0
    local hasActions = self.actionCount > 5

    if fpsAvg >= 50 and hasScores and hasActions then
        return "High"
    elseif fpsAvg >= 30 or hasActions then
        return "Medium"
    else
        return "Low"
    end
end

--- 获取平均 FPS（基于滑动窗口）
---@return number
function GameMetricsCollector:getAvgFPS()
    local count = math.min(self.frameCount, self.fpsWindowSize)
    if count == 0 then return 0 end
    local sum = 0
    for i = 1, count do
        sum = sum + (self.fpsWindow[i] or 0)
    end
    return sum / count
end

--- 获取指标快照（对外主接口）
--- 返回与 tester.py run_test() 相同结构的指标字典
---@return table metrics
function GameMetricsCollector:getSnapshot()
    local fpsAvg = self:getAvgFPS()
    local aps = 0
    if self.totalTime > 0 then
        aps = self.actionCount / self.totalTime
    end

    return {
        fps_avg            = math.floor(fpsAvg * 10 + 0.5) / 10,
        fps_min            = math.floor(self.fpsMin),
        fps_max            = math.floor(self.fpsMax),
        time_survived      = math.floor(self.totalTime * 10 + 0.5) / 10,
        action_count       = self.actionCount,
        actions_per_second = math.floor(aps * 100 + 0.5) / 100,
        scores             = self.scores,
        error_count        = self.errorCount,
        errors             = self.errors,
        performance_rating = self:calcPerformanceRating(),
        frame_count        = self.frameCount,
    }
end

return GameMetricsCollector
```

---

## 3. HumanVsAIDetector

> 源自 `ai_helper.py` 的 `get_human_ai_verdict()` 函数。
> 实现完整的 6 信号人机行为判别模型。

```lua
-- scripts/testing/HumanVsAIDetector.lua
-- 人机行为判别器：6 信号模型，判断行为是人类/AI/Bot

local HumanVsAIDetector = {}
HumanVsAIDetector.__index = HumanVsAIDetector

--- 创建新的人机判别器
---@return table detector
function HumanVsAIDetector.new()
    local self = setmetatable({}, HumanVsAIDetector)
    return self
end

--- 信号 1: Action Rate (APS) 分析
--- 源自 ai_helper.py Signal 1
---@param aps number 每秒操作数
---@return string label, string detail
local function analyzeActionRate(aps)
    if aps >= 0.3 and aps <= 2.0 then
        return "Human",
            string.format("APS=%.2f in natural human range (0.3-2.0)", aps)
    elseif aps > 3.0 then
        return "Bot",
            string.format("APS=%.2f exceeds human capability (>3.0)", aps)
    elseif aps > 2.0 then
        return "Uncertain",
            string.format("APS=%.2f slightly elevated (2.0-3.0)", aps)
    else
        return "Human",
            string.format("APS=%.2f very low, likely casual human", aps)
    end
end

--- 信号 2: Error Pattern 分析
--- 源自 ai_helper.py Signal 2
---@param errorCount number 错误数量
---@return string label, string detail
local function analyzeErrorPattern(errorCount)
    if errorCount >= 1 and errorCount <= 3 then
        return "Human",
            string.format("%d errors - natural human error pattern", errorCount)
    elseif errorCount == 0 then
        return "Suspicious",
            "0 errors - suspiciously perfect (could be bot)"
    elseif errorCount > 5 then
        return "Bot",
            string.format("%d errors - excessive, possible automated probing", errorCount)
    else
        return "Uncertain",
            string.format("%d errors - moderate count", errorCount)
    end
end

--- 信号 3: Score Progression 分析
--- 源自 ai_helper.py Signal 3（方差公式完整迁移）
---@param scores number[] 得分历史
---@return string label, string detail
local function analyzeScoreProgression(scores)
    if #scores < 2 then
        return "Uncertain", "Insufficient score data for analysis"
    end

    -- 计算相邻分数差
    local diffs = {}
    for i = 2, #scores do
        diffs[#diffs + 1] = math.abs(scores[i] - scores[i - 1])
    end

    -- 计算平均差
    local sumDiff = 0
    for i = 1, #diffs do
        sumDiff = sumDiff + diffs[i]
    end
    local avgDiff = sumDiff / #diffs

    -- 计算方差
    local variance = 0
    for i = 1, #diffs do
        local dev = diffs[i] - avgDiff
        variance = variance + dev * dev
    end
    variance = variance / #diffs

    -- 阈值判定（源自 ai_helper.py）
    local threshold = avgDiff > 0 and (avgDiff * 0.5) or 1

    if variance > threshold then
        return "Human",
            string.format("Score variance=%.1f > threshold=%.1f (variable, human-like)", variance, threshold)
    else
        return "Bot",
            string.format("Score variance=%.1f <= threshold=%.1f (consistent, bot-like)", variance, threshold)
    end
end

--- 信号 4: Timing Pattern 分析
--- 源自 ai_helper.py Signal 4
---@param timeSurvived number 存活时间（秒）
---@return string label, string detail
local function analyzeTimingPattern(timeSurvived)
    if timeSurvived >= 15 and timeSurvived <= 60 then
        return "Human",
            string.format("%.1fs - natural human session duration (15-60s)", timeSurvived)
    elseif timeSurvived < 5 then
        return "Bot",
            string.format("%.1fs - suspiciously short (<5s), possible bot timeout", timeSurvived)
    elseif timeSurvived > 90 then
        return "Human",
            string.format("%.1fs - extended session, likely engaged human", timeSurvived)
    else
        return "Uncertain",
            string.format("%.1fs - between typical ranges", timeSurvived)
    end
end

--- 信号 5: Performance Level 分析
--- 源自 ai_helper.py Signal 5
---@param perfRating string "High" | "Medium" | "Low"
---@return string label, string detail
local function analyzePerformanceLevel(perfRating)
    if perfRating == "High" then
        return "Suspicious",
            "High performance - possibly AI-assisted"
    elseif perfRating == "Medium" then
        return "Human",
            "Medium performance - typical human level"
    else
        return "Human",
            "Low performance - very likely human"
    end
end

--- 信号 6: Game Type Behavior 分析
--- 源自 ai_helper.py Signal 6
---@param gameType string 游戏类型
---@param aps number 每秒操作数
---@return string label, string detail
local function analyzeGameTypeBehavior(gameType, aps)
    -- 慢节奏游戏（卡牌/棋盘/解谜）期望低 APS
    local slowTypes = {
        ["Card/Board"] = true,
        ["Puzzle"]     = true,
        ["Strategy"]   = true,
    }
    -- 快节奏游戏（动作/跑酷/竞速）期望较高 APS
    local fastTypes = {
        ["Action/Shooter"] = true,
        ["Endless Runner"] = true,
        ["Racing"]         = true,
    }

    if slowTypes[gameType] then
        if aps <= 1.0 then
            return "Human",
                string.format("%s + APS=%.2f: slow pace expected for this genre", gameType, aps)
        else
            return "Uncertain",
                string.format("%s + APS=%.2f: faster than expected for this genre", gameType, aps)
        end
    elseif fastTypes[gameType] then
        if aps >= 0.5 and aps <= 3.0 then
            return "Human",
                string.format("%s + APS=%.2f: normal pace for action genre", gameType, aps)
        elseif aps > 3.0 then
            return "Bot",
                string.format("%s + APS=%.2f: exceeds human action speed", gameType, aps)
        else
            return "Uncertain",
                string.format("%s + APS=%.2f: unusually slow for this genre", gameType, aps)
        end
    else
        return "Uncertain",
            string.format("%s + APS=%.2f: no specific behavior baseline", gameType, aps)
    end
end

--- 综合分析（主接口）
--- 完整迁移 ai_helper.py get_human_ai_verdict() 逻辑
---@param metrics table GameMetricsCollector:getSnapshot() 的返回值
---@param gameType? string 游戏类型（可选，默认 "Unknown"）
---@return table verdict
function HumanVsAIDetector:analyze(metrics, gameType)
    gameType = gameType or "Unknown"

    local aps           = metrics.actions_per_second or 0
    local errorCount    = metrics.error_count or 0
    local scores        = metrics.scores or {}
    local timeSurvived  = metrics.time_survived or 0
    local perfRating    = metrics.performance_rating or "Low"

    -- 运行 6 个信号分析
    local signals = {}
    local humanScore = 0
    local botScore   = 0

    local analyses = {
        { name = "Action Rate",        fn = function() return analyzeActionRate(aps) end,                        value = aps },
        { name = "Error Pattern",      fn = function() return analyzeErrorPattern(errorCount) end,               value = errorCount },
        { name = "Score Progression",  fn = function() return analyzeScoreProgression(scores) end,               value = #scores },
        { name = "Timing Pattern",     fn = function() return analyzeTimingPattern(timeSurvived) end,            value = timeSurvived },
        { name = "Performance Level",  fn = function() return analyzePerformanceLevel(perfRating) end,           value = perfRating },
        { name = "Game Type Behavior", fn = function() return analyzeGameTypeBehavior(gameType, aps) end,        value = gameType },
    }

    for i = 1, #analyses do
        local a = analyses[i]
        local label, detail = a.fn()

        signals[i] = {
            name   = a.name,
            value  = a.value,
            label  = label,
            detail = detail,
        }

        -- 计分（源自 ai_helper.py 的计分逻辑）
        if label == "Human" then
            humanScore = humanScore + 1
        elseif label == "Bot" then
            botScore = botScore + 1
        elseif label == "Suspicious" then
            botScore = botScore + 0.5
        end
        -- "Uncertain" 不加分
    end

    -- 计算人类占比和最终判定（源自 ai_helper.py）
    local total = humanScore + botScore
    local humanRatio = total > 0 and (humanScore / total) or 0.5

    local result, confidence
    if humanRatio >= 0.65 then
        result = "Human"
    elseif humanRatio <= 0.35 then
        result = "AI/Bot"
    else
        result = "Uncertain"
    end

    if humanRatio >= 0.80 or humanRatio <= 0.20 then
        confidence = "High"
    else
        confidence = "Medium"
    end

    return {
        result      = result,
        confidence  = confidence,
        human_score = humanScore,
        bot_score   = botScore,
        human_ratio = math.floor(humanRatio * 100 + 0.5) / 100,
        signals     = signals,
    }
end

return HumanVsAIDetector
```

---

## 4. SessionManager

> 源自 `chatbot.py` 的会话管理逻辑。
> 使用 UrhoX File API（非 io 库）进行 JSON 持久化。

```lua
-- scripts/testing/SessionManager.lua
-- 测试会话管理器：历史记录、JSON 序列化、持久化存储

local cjson = require "cjson"

local SessionManager = {}
SessionManager.__index = SessionManager

--- 创建新的会话管理器
---@param opts? table { maxHistory?: number }
---@return table manager
function SessionManager.new(opts)
    opts = opts or {}
    local self = setmetatable({}, SessionManager)
    self.maxHistory = opts.maxHistory or 50
    self.history    = {}   -- 测试历史（最新在前）
    self.context    = {}   -- 当前游戏上下文
    return self
end

--- 保存一条测试结果
---@param testResult table { timestamp, metrics, verdict, gameType?, ... }
function SessionManager:saveTest(testResult)
    -- 插入到头部（最新在前）
    table.insert(self.history, 1, testResult)

    -- 淘汰超出上限的旧记录（源自 chatbot.py deque maxlen=50）
    while #self.history > self.maxHistory do
        table.remove(self.history)
    end
end

--- 获取完整历史
---@return table[] history
function SessionManager:getHistory()
    return self.history
end

--- 获取最新一条记录
---@return table|nil latest
function SessionManager:getLatest()
    return self.history[1]
end

--- 获取历史记录数量
---@return number
function SessionManager:getCount()
    return #self.history
end

--- 设置当前游戏上下文（源自 chatbot.py current_game_context）
---@param ctx table { gameName?, gameType?, startTime?, ... }
function SessionManager:setContext(ctx)
    self.context = ctx or {}
end

--- 获取当前游戏上下文
---@return table
function SessionManager:getContext()
    return self.context
end

--- 导出为 JSON 字符串
---@return string json
function SessionManager:exportJSON()
    return cjson.encode({
        history = self.history,
        context = self.context,
        exportTime = os.time(),
    })
end

--- 从 JSON 字符串导入
---@param jsonStr string
---@return boolean success
function SessionManager:importJSON(jsonStr)
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or type(data) ~= "table" then
        return false
    end
    if data.history and type(data.history) == "table" then
        self.history = data.history
    end
    if data.context and type(data.context) == "table" then
        self.context = data.context
    end
    return true
end

--- 保存到文件（使用 UrhoX File API，非 io 库）
---@param filePath string 相对路径如 "test_sessions.json"
---@return boolean success
function SessionManager:saveToFile(filePath)
    local jsonStr = self:exportJSON()
    local file = File:new(filePath, FILE_WRITE)
    if file == nil then
        log:Write(LOG_ERROR, "[SessionManager] Cannot open file for writing: " .. filePath)
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    log:Write(LOG_INFO, "[SessionManager] Saved " .. #self.history .. " records to " .. filePath)
    return true
end

--- 从文件加载（使用 UrhoX File API）
---@param filePath string 相对路径
---@return boolean success
function SessionManager:loadFromFile(filePath)
    if not fileSystem:FileExists(filePath) then
        log:Write(LOG_WARNING, "[SessionManager] File not found: " .. filePath)
        return false
    end
    local file = File:new(filePath, FILE_READ)
    if file == nil then
        log:Write(LOG_ERROR, "[SessionManager] Cannot open file for reading: " .. filePath)
        return false
    end
    local jsonStr = file:ReadString()
    file:Close()
    return self:importJSON(jsonStr)
end

--- 清除所有历史
function SessionManager:clear()
    self.history = {}
    self.context = {}
end

return SessionManager
```

---

## 5. ReportBuilder

> 源自 `chatbot.py` 的 `build_reply()` 函数和 `PERF_CONFIG` 配置。
> 提供文本报告和 NanoVG 可视化仪表盘两种输出。

```lua
-- scripts/testing/ReportBuilder.lua
-- 测试报告生成器：文本报告 + NanoVG 可视化仪表盘

local ReportBuilder = {}
ReportBuilder.__index = ReportBuilder

--- 性能等级配置（源自 chatbot.py PERF_CONFIG）
local PERF_CONFIG = {
    High   = { icon = "[OK]",   comment = "Excellent\! Game runs smoothly.",       tip = "No major issues detected." },
    Medium = { icon = "[--]",   comment = "Good performance, room to improve.",   tip = "Consider optimizing hot paths." },
    Low    = { icon = "[\!\!]",   comment = "Poor performance, issues detected.",   tip = "Game may have rendering or logic bottlenecks." },
}

--- 创建新的报告生成器
---@return table builder
function ReportBuilder.new()
    local self = setmetatable({}, ReportBuilder)
    self.fontCreated = false
    return self
end

--- 初始化 NanoVG 字体（只调用一次）
---@param vg userdata NanoVG context
function ReportBuilder:initFont(vg)
    if not self.fontCreated then
        nvgCreateFont(vg, "report-sans", "Fonts/MiSans-Regular.ttf")
        self.fontCreated = true
    end
end

--- 生成文本报告（源自 chatbot.py build_reply）
---@param metrics table 指标快照
---@param verdict? table 人机判别结果
---@param gameType? table 游戏类型结果
---@return string report
function ReportBuilder:buildText(metrics, verdict, gameType)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add("========================================")
    add("       GAME TEST REPORT")
    add("========================================")
    add("")

    -- 游戏类型区
    if gameType then
        add("--- Game Type ---")
        add("  Type:       " .. (gameType.primary_type or "Unknown"))
        add("  Confidence: " .. (gameType.confidence or "N/A"))
        add("")
    end

    -- 性能指标区
    local perf = PERF_CONFIG[metrics.performance_rating] or PERF_CONFIG.Low
    add("--- Performance ---")
    add("  Rating:  " .. perf.icon .. " " .. (metrics.performance_rating or "N/A"))
    add("  Comment: " .. perf.comment)
    add("  Tip:     " .. perf.tip)
    add("")

    -- 运行时指标区
    add("--- Runtime Metrics ---")
    add(string.format("  FPS:        avg=%.1f  min=%d  max=%d",
        metrics.fps_avg or 0, metrics.fps_min or 0, metrics.fps_max or 0))
    add(string.format("  Duration:   %.1f seconds", metrics.time_survived or 0))
    add(string.format("  Actions:    %d (%.2f/sec)",
        metrics.action_count or 0, metrics.actions_per_second or 0))
    add(string.format("  Scores:     %d recorded", #(metrics.scores or {})))
    add(string.format("  Errors:     %d", metrics.error_count or 0))
    add("")

    -- 人机判别区
    if verdict then
        add("--- Human vs AI Verdict ---")
        add("  Result:     " .. verdict.result)
        add("  Confidence: " .. verdict.confidence)
        add(string.format("  Ratio:      %.0f%% human / %.0f%% bot",
            (verdict.human_ratio or 0) * 100,
            (1 - (verdict.human_ratio or 0)) * 100))
        add("")
        add("  Signals:")
        for i = 1, #verdict.signals do
            local s = verdict.signals[i]
            add(string.format("    [%d] %-20s => %-10s | %s",
                i, s.name, s.label, s.detail))
        end
        add("")
    end

    add("========================================")
    add("  Generated by Game Tester AI")
    add("========================================")

    return table.concat(lines, "\n")
end

--- NanoVG 可视化仪表盘绘制
--- 必须在 NanoVGRender 事件回调中调用
---@param vg userdata NanoVG context
---@param x number 左上角 X
---@param y number 左上角 Y
---@param w number 面板宽度
---@param h number 面板高度
---@param metrics table 指标快照
---@param verdict? table 人机判别结果
function ReportBuilder:drawDashboard(vg, x, y, w, h, metrics, verdict)
    self:initFont(vg)

    -- 背景面板
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 8)
    nvgFillColor(vg, nvgRGBA(20, 20, 30, 220))
    nvgFill(vg)

    -- 边框
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 180))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    nvgFontFace(vg, "report-sans")
    local pad = 12
    local cx  = x + pad
    local cy  = y + pad

    -- 标题
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(200, 220, 255, 255))
    nvgText(vg, cx, cy + 14, "Game Test Report")
    cy = cy + 30

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy)
    nvgLineTo(vg, x + w - pad, cy)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    cy = cy + 10

    nvgFontSize(vg, 13)

    -- FPS 指标
    nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
    nvgText(vg, cx, cy + 13, string.format("FPS: %.1f (min %d / max %d)",
        metrics.fps_avg or 0, metrics.fps_min or 0, metrics.fps_max or 0))
    cy = cy + 20

    -- 操作频率
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, cx, cy + 13, string.format("Actions: %d (%.2f/sec)",
        metrics.action_count or 0, metrics.actions_per_second or 0))
    cy = cy + 20

    -- 存活时间
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
    nvgText(vg, cx, cy + 13, string.format("Duration: %.1fs  Errors: %d",
        metrics.time_survived or 0, metrics.error_count or 0))
    cy = cy + 20

    -- 性能等级
    local perfColor
    local pr = metrics.performance_rating or "Low"
    if pr == "High" then
        perfColor = nvgRGBA(50, 255, 50, 255)
    elseif pr == "Medium" then
        perfColor = nvgRGBA(255, 200, 50, 255)
    else
        perfColor = nvgRGBA(255, 80, 80, 255)
    end
    nvgFillColor(vg, perfColor)
    nvgText(vg, cx, cy + 13, "Performance: " .. pr)
    cy = cy + 25

    -- 人机判别结果
    if verdict then
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy)
        nvgLineTo(vg, x + w - pad, cy)
        nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 120))
        nvgStroke(vg)
        cy = cy + 10

        local vColor
        if verdict.result == "Human" then
            vColor = nvgRGBA(50, 255, 120, 255)
        elseif verdict.result == "AI/Bot" then
            vColor = nvgRGBA(255, 80, 80, 255)
        else
            vColor = nvgRGBA(255, 200, 50, 255)
        end

        nvgFontSize(vg, 15)
        nvgFillColor(vg, vColor)
        nvgText(vg, cx, cy + 13, string.format("Verdict: %s (%s, %.0f%%)",
            verdict.result, verdict.confidence, (verdict.human_ratio or 0) * 100))
        cy = cy + 22

        -- 信号列表
        nvgFontSize(vg, 11)
        for i = 1, #verdict.signals do
            local s = verdict.signals[i]
            local sColor
            if s.label == "Human" then
                sColor = nvgRGBA(120, 255, 150, 200)
            elseif s.label == "Bot" then
                sColor = nvgRGBA(255, 120, 120, 200)
            else
                sColor = nvgRGBA(200, 200, 120, 200)
            end
            nvgFillColor(vg, sColor)
            nvgText(vg, cx + 8, cy + 11, string.format("%s: %s", s.name, s.label))
            cy = cy + 16
        end
    end
end

return ReportBuilder
```

---

## 模块依赖关系

```
TestRunner (入口)
├── GameTypeDetector    (独立，无依赖)
├── GameMetricsCollector (独立，无依赖)
├── HumanVsAIDetector   (依赖 metrics 快照数据)
├── SessionManager      (依赖 cjson, UrhoX File API)
└── ReportBuilder       (依赖 NanoVG, metrics + verdict 数据)
```

所有模块独立加载，可单独使用或组合使用。
