# Game Tester AI — UrhoX Lua 游戏自动化测试框架

> 灵感源自 [Priyal9497/game-tester-ai](https://github.com/Priyal9497/game-tester-ai)（TestProbe AI v3.0），
> 将 Python Web 游戏测试平台的核心理念迁移到 UrhoX Lua 引擎内部，
> 为开发者提供无需人工操作的游戏类型识别、运行时指标采集、人机行为判别与测试报告生成能力。

---
name: game-tester-ai
description: |
  UrhoX Lua 游戏自动化测试框架。
  灵感源自 Priyal9497/game-tester-ai（TestProbe AI v3.0），
  将 Python Web 游戏测试平台的核心理念迁移到 UrhoX Lua 引擎内部，
  提供游戏类型识别、运行时指标采集、人机行为判别（6 信号模型）、
  会话管理与测试报告生成的完整自动化测试能力。

Use when users need to
  (1) 自动化测试游戏玩法平衡性和行为模式
  (2) 检测游戏中的人类玩家与 AI/Bot 行为差异
  (3) 采集游戏运行时指标（FPS、操作频率、得分曲线、错误率）
  (4) 自动识别游戏类型并应用对应测试策略
  (5) 生成结构化测试报告（JSON + 可视化）
  (6) 记录并回放测试会话用于回归分析
  (7) 用户说"游戏测试""自动测试""行为检测""人机判别"

MUST trigger when:
  - 用户要求对游戏进行自动化测试或行为分析
  - 用户需要检测玩家行为是人类还是 AI/Bot
  - 用户说"性能测试""指标采集""测试报告"

trigger-keywords:
  - 游戏测试
  - 自动测试
  - 行为检测
  - 人机判别
  - 性能指标
  - 测试报告
  - 操作频率
  - 得分分析
  - Bot 检测
  - 玩家行为
  - game test
  - automated test
  - bot detection
  - player behavior
  - metrics collection
---

## 核心架构

```
┌─────────────────────────────────────────────────────┐
│                   TestRunner（入口）                  │
│          统一调度 · 注入回调 · 汇总结果               │
├──────────┬──────────┬──────────┬──────────┬──────────┤
│ GameType │ Metrics  │ HumanVs  │ Session  │ Report   │
│ Detector │Collector │AIDetector│ Manager  │ Builder  │
│ 7类关键词 │ FPS/APS  │ 6信号模型 │ JSON序列化│ 文本+NVG │
│ 置信度   │ 得分曲线 │ 人/AI/Bot│ 历史管理 │ 可视化   │
└──────────┴──────────┴──────────┴──────────┴──────────┘
```

### 五大模块

| 模块 | 源自 | 核心能力 | 行数 |
|------|------|---------|------|
| **GameTypeDetector** | tester.py `detect_game_type()` | 7 类游戏关键词识别 + 置信度评估 | ~80 |
| **GameMetricsCollector** | tester.py `run_test()` | 运行时 FPS/APS/得分/错误指标采集 | ~120 |
| **HumanVsAIDetector** | ai_helper.py `get_human_ai_verdict()` | 6 信号人机行为判别模型 | ~150 |
| **SessionManager** | chatbot.py session management | 测试会话 JSON 序列化与历史管理 | ~100 |
| **ReportBuilder** | chatbot.py `build_reply()` | 结构化文本 + NanoVG 可视化报告 | ~120 |

---

## API 速查

### GameTypeDetector — 游戏类型识别

```lua
local detector = GameTypeDetector.new()

-- 注册自定义类型
detector:registerType("Tower Defense", {
    "tower", "defense", "wave", "turret", "td"
})

-- 检测游戏类型
local result = detector:detect({
    title = "Epic Tower Defense",
    tags  = {"strategy", "tower", "defense"},
    description = "Build towers to defend your base"
})
-- result = { primary_type = "Tower Defense", confidence = "High", scores = {...} }
```

**内置 7 类游戏**:

| 类型 | 关键词示例 |
|------|----------|
| Endless Runner | runner, run, jump, obstacle, dino |
| Puzzle | puzzle, match, block, tetris, 2048, sudoku |
| Card/Board | chess, card, board, solitaire, checkers |
| Action/Shooter | shoot, shooter, bullet, enemy, kill |
| Strategy | strategy, tower, defense, build, upgrade |
| Sports | football, soccer, basketball, tennis, golf |
| Racing | race, racing, car, drive, speed |

### GameMetricsCollector — 运行时指标采集

```lua
local collector = GameMetricsCollector.new()

-- 在 HandleUpdate 中每帧调用
collector:update(dt)

-- 记录玩家操作
collector:recordAction("jump")
collector:recordAction("attack")

-- 记录得分
collector:recordScore(1500)

-- 记录错误/异常
collector:recordError("collision_glitch")

-- 获取快照
local metrics = collector:getSnapshot()
-- metrics = {
--   fps_avg = 58.3,
--   fps_min = 45,
--   time_survived = 32.5,
--   action_count = 47,
--   actions_per_second = 1.45,
--   scores = {100, 500, 1200, 1500},
--   error_count = 2,
--   performance_rating = "High"  -- High/Medium/Low
-- }
```

### HumanVsAIDetector — 人机行为判别

```lua
local detector = HumanVsAIDetector.new()

local verdict = detector:analyze(metrics)
-- verdict = {
--   result = "Human",          -- "Human" | "AI/Bot" | "Uncertain"
--   confidence = "High",       -- "High" | "Medium"
--   human_score = 5,
--   bot_score = 1,
--   human_ratio = 0.83,
--   signals = {
--     { name = "Action Rate", value = 1.45, label = "Human", detail = "..." },
--     { name = "Error Pattern", value = 2, label = "Human", detail = "..." },
--     -- ... 共 6 个信号
--   }
-- }
```

**6 信号模型**:

| # | 信号 | 人类特征 | Bot 特征 |
|---|------|---------|---------|
| 1 | Action Rate (APS) | 0.3-2.0 操作/秒 | >3.0 操作/秒 |
| 2 | Error Pattern | 1-3 个错误 | 0 或 >5 个错误 |
| 3 | Score Progression | 分数变化有波动 | 分数增长一致 |
| 4 | Timing Pattern | 15-60 秒合理时长 | <5 秒过快 |
| 5 | Performance Level | Medium/Low | High（可能 AI 辅助） |
| 6 | Game Type Behavior | 类型匹配操作节奏 | 节奏与类型不符 |

### SessionManager — 会话管理

```lua
local session = SessionManager.new({ maxHistory = 50 })

-- 保存测试结果
session:saveTest(testResult)

-- 获取历史
local history = session:getHistory()
local latest  = session:getLatest()

-- 导出/导入 JSON
local json = session:exportJSON()
session:importJSON(json)

-- 清除历史
session:clear()
```

### ReportBuilder — 报告生成

```lua
local report = ReportBuilder.new()

-- 生成文本报告
local text = report:buildText(metrics, verdict, gameType)

-- 在 NanoVGRender 事件中绘制可视化报告
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)
    report:drawDashboard(vg, x, y, w, h, metrics, verdict)
    nvgEndFrame(vg)
end
```

---

## 快速开始

```lua
-- scripts/main.lua
-- 完整游戏测试集成示例

require "LuaScripts/Utilities/Sample"

-- 引入测试模块
local GameTypeDetector     = require "scripts.testing.GameTypeDetector"
local GameMetricsCollector = require "scripts.testing.GameMetricsCollector"
local HumanVsAIDetector    = require "scripts.testing.HumanVsAIDetector"
local SessionManager       = require "scripts.testing.SessionManager"
local ReportBuilder        = require "scripts.testing.ReportBuilder"

local collector
local session
local reportBuilder

function Start()
    -- 初始化测试组件
    collector     = GameMetricsCollector.new()
    session       = SessionManager.new({ maxHistory = 50 })
    reportBuilder = ReportBuilder.new()

    -- 游戏类型识别
    local detector = GameTypeDetector.new()
    local gameType = detector:detect({
        title = "My Awesome Platformer",
        tags  = { "platformer", "jump", "run" }
    })
    log:Write(LOG_INFO, "Game Type: " .. gameType.primary_type
              .. " (" .. gameType.confidence .. ")")

    -- ... 初始化游戏场景 ...

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    collector:update(dt)

    -- ... 游戏逻辑 ...
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- 记录玩家操作
    collector:recordAction("keypress")

    -- F5 生成测试报告
    if key == KEY_F5 then
        local metrics = collector:getSnapshot()
        local hvDetector = HumanVsAIDetector.new()
        local verdict = hvDetector:analyze(metrics)
        local text = reportBuilder:buildText(metrics, verdict)
        log:Write(LOG_INFO, text)
        session:saveTest({
            timestamp = os.time(),
            metrics   = metrics,
            verdict   = verdict,
        })
    end
end
```

---

## 约束与兼容

### 引擎规则遵守

| 规则 | 遵守情况 |
|------|---------|
| 代码放 scripts/ | 所有测试模块放 scripts/testing/ |
| NanoVG 在 NanoVGRender 事件 | ReportBuilder 仅在该事件中渲染 |
| nvgCreateFont 只调用一次 | ReportBuilder 在 init() 中创建 |
| 数组索引从 1 开始 | 所有数组循环 for i = 1, #arr |
| 使用枚举不用数字 | KEY_F5 等枚举常量 |
| File API 非 io 库 | SessionManager 用 File 读写 |
| 不调用 SetMode() | 使用 GetWidth()/GetHeight()/GetDPR() |

### 性能考量

- MetricsCollector 每帧更新仅做累加运算（O(1)）
- 分析/报告按需触发，不影响游戏帧率
- SessionManager 历史上限 50 条，自动淘汰旧记录
- ReportBuilder 的 NanoVG 渲染仅在需要时绘制

---

## 参考文档

- **[模块完整实现](references/modules-implementation.md)** — 5 个模块的完整 Lua 代码
- **[集成示例](references/integration-examples.md)** — 完整 main.lua、各模块独立用法、NanoVG 仪表盘
