---
name: "santorinai"
description: |
  Santorini 棋盘游戏 AI 测试框架。灵感来源于 Tomansion/SantorinAI，
  将 Python Santorini AI 对战测试框架迁移到 UrhoX Lua 引擎内，
  为开发者提供完整的棋盘逻辑、AI 玩家接口、对局运行器和 NanoVG 等距可视化。
  支持自定义 AI 策略开发、批量对局统计和胜负分析。
trigger-keywords:
  - 棋盘游戏
  - Santorini
  - 圣托里尼
  - 桌游AI
  - 回合制棋盘
  - AI对战
  - 棋盘对弈
  - board game
  - 策略棋盘
  - 塔防棋
  - 棋类游戏
  - 棋盘测试
  - AI棋手
  - 回合策略
---

# SantorinAI — Santorini 棋盘游戏 AI 测试框架

> **灵感来源**: [Tomansion/SantorinAI](https://github.com/Tomansion/SantorinAI)
>
> 将 Python Santorini AI 对战测试框架的核心理念迁移到 UrhoX Lua 引擎，
> 提供完整的棋盘逻辑、可扩展 AI 玩家接口、对局运行器和 NanoVG 等距可视化。

---

## 一、Santorini 游戏规则概述

**Santorini**（圣托里尼）是一款 2 人策略棋盘游戏：

| 要素 | 说明 |
|------|------|
| 棋盘 | 5×5 方格 |
| 棋子 | 每位玩家 2 枚棋子（pawn） |
| 塔层 | 0=空地, 1=一层, 2=二层, 3=三层, 4=封顶（dome） |
| 回合 | 选棋子 → 移动（相邻8格,最多升1层） → 建造（相邻8格加1层） |
| 胜利 | 棋子移动到三层塔顶 **或** 对手无法移动 |

### 核心约束
- 移动只能上升最多 1 层（不能跳两层）
- 不能移动到封顶（level 4）或有棋子的格子
- 建造不能在封顶或有棋子的格子上
- 移动和建造必须在相邻 8 格内

---

## 二、模块架构

```
scripts/
├── santorinai/
│   ├── Board.lua          -- 棋盘状态与规则引擎
│   ├── Pawn.lua           -- 棋子数据结构
│   ├── Player.lua         -- AI 玩家抽象接口
│   ├── Tester.lua         -- 对局运行器与统计
│   ├── Display.lua        -- NanoVG 等距可视化
│   └── players/
│       ├── RandomPlayer.lua     -- 随机策略
│       ├── FirstChoicePlayer.lua -- 首选策略
│       └── BasicPlayer.lua      -- 启发式策略
└── main.lua               -- 入口文件
```

### 2.1 模块职责

| 模块 | 职责 | 原始对应 |
|------|------|---------|
| **Board** | 5×5 棋盘状态管理、移动/建造合法性验证、胜负判定、状态复制 | `board.py` |
| **Pawn** | 棋子数据（编号、归属玩家、坐标） | `pawn.py` |
| **Player** | AI 玩家抽象接口（`name`/`placePawn`/`playMove`） | `player.py` |
| **Tester** | 批量 1v1 对局运行、胜负统计、胜负类型追踪 | `tester.py` |
| **Display** | NanoVG 等距视角棋盘渲染、塔层/棋子/高亮绘制 | `board_displayer.py` |
| **Players** | 3 种内置 AI 策略示范 | `player_examples/` |

---

## 三、核心 API 速查

### 3.1 Board（棋盘）

```lua
local Board = require("santorinai.Board")

local board = Board.new(2)              -- 创建 2 人棋盘
board:placePawn({3, 3})                 -- 放置当前玩家的棋子
board:playMove(1, {3, 4}, {3, 3})       -- 棋子1移动到(3,4)，在(3,3)建造

-- 查询
board:getPossibleMovementPositions(pawn)        -- 可移动位置列表
board:getPossibleBuildingPositions(pawn)         -- 可建造位置列表
board:getPossibleMovementAndBuildingPositions(pawn) -- 移动+建造组合列表
board:getPlayerPawns(playerNumber)               -- 获取玩家的棋子
board:getPlayingPawn(pawnNumber)                 -- 获取当前玩家的第N枚棋子
board:isGameOver()                               -- 是否结束
board:copy()                                     -- 深拷贝（用于AI模拟）

-- 状态
board.grid[x][y]              -- 塔层值 (0-4), 索引 1-5
board.turnNumber              -- 当前回合数
board.playerTurn              -- 当前行动玩家 (1 或 2)
board.winnerPlayerNumber      -- 获胜玩家编号 (nil=未结束)
```

### 3.2 Player（AI 玩家接口）

```lua
local Player = require("santorinai.Player")

-- 实现自定义 AI 玩家
local MyAI = Player.extend("MySmartAI")

function MyAI:placePawn(board, pawn)
    -- 返回 {x, y} 放置位置
    local positions = board:getPossibleMovementPositions(pawn)
    return positions[1]
end

function MyAI:playMove(board)
    -- 返回 pawnNumber, {moveX, moveY}, {buildX, buildY}
    local pawns = board:getPlayerPawns(self.playerNumber)
    local moves = board:getPossibleMovementAndBuildingPositions(pawns[1])
    local chosen = moves[1]
    return pawns[1].order, chosen[1], chosen[2]
end
```

### 3.3 Tester（对局运行器）

```lua
local Tester = require("santorinai.Tester")

local tester = Tester.new()
tester.verboseLevel = 1       -- 0=静默, 1=每局结果, 2=每步详情

-- 运行 100 局 1v1
local results = tester:play1v1(player1, player2, 100)
-- results = { wins = {["AI-1"]=62, ["AI-2"]=38}, winTypes = {...} }
```

### 3.4 Display（NanoVG 可视化）

```lua
local Display = require("santorinai.Display")

-- 在 NanoVGRender 事件中调用
function HandleNanoVGRender(eventType, eventData)
    Display.drawBoard(vg, board, ox, oy, tileSize)
end
```

---

## 四、AI 策略实现指南

### 4.1 决策流程

```
placePawn 阶段:
  收到 board + pawn → 返回 {x, y} 放置位置

playMove 阶段:
  收到 board → 枚举所有合法走法 → 评估 → 返回 pawnNumber, movePos, buildPos
```

### 4.2 内置策略对比

| 策略 | 放置 | 移动 | 建造 | 强度 |
|------|------|------|------|------|
| **RandomPlayer** | 随机 | 随机 | 随机 | ★☆☆ |
| **FirstChoicePlayer** | 首个 | 首个 | 首个 | ★☆☆ |
| **BasicPlayer** | 靠近友军 | 优先登顶/阻止对手/爬高 | 随机 | ★★☆ |

### 4.3 高级策略思路

```lua
-- 评分函数示例
function evaluateMove(board, pawn, movePos, buildPos)
    local score = 0
    local moveLevel = board.grid[movePos[1]][movePos[2]]

    -- 登顶即胜 (+1000)
    if moveLevel == 3 then score = score + 1000 end

    -- 爬高加分 (+10 per level)
    score = score + moveLevel * 10

    -- 封锁对手加分
    local opponentPawns = getOpponentPawns(board, pawn)
    for _, op in ipairs(opponentPawns) do
        if isAdjacent(buildPos, op.pos) and board.grid[buildPos[1]][buildPos[2]] == 3 then
            score = score + 50  -- 封顶阻止对手
        end
    end

    return score
end
```

---

## 五、快速开始

```lua
-- main.lua: 最小可运行示例
require "LuaScripts/Utilities/Sample"

local Board = require("santorinai.Board")
local Tester = require("santorinai.Tester")
local RandomPlayer = require("santorinai.players.RandomPlayer")
local BasicPlayer = require("santorinai.players.BasicPlayer")
local Display = require("santorinai.Display")

local vg
local currentBoard
local tester
local results

function Start()
    SampleInitMouseMode(MM_ABSOLUTE)
    vg = nvgCreate(0)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    -- 创建玩家
    local p1 = BasicPlayer.new(1)
    local p2 = RandomPlayer.new(2)

    -- 运行对局
    tester = Tester.new()
    tester.verboseLevel = 0
    results = tester:play1v1(p1, p2, 50)

    -- 保留最后一局用于可视化
    currentBoard = tester.lastBoard

    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()
    nvgBeginFrame(vg, w, h, 1.0)

    -- 绘制棋盘
    Display.drawBoard(vg, currentBoard, w/2 - 150, 50, 60)

    -- 绘制统计
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    local y = h - 80
    for name, wins in pairs(results.wins) do
        nvgText(vg, 20, y, name .. ": " .. wins .. " wins")
        y = y + 25
    end

    nvgEndFrame(vg)
end
```

---

## 六、UrhoX 引擎适配要点

| Python 原版 | Lua 适配 | 说明 |
|------------|---------|------|
| 0-based 索引 | **1-based 索引** | grid[1][1] ~ grid[5][5] |
| `(x, y)` 元组 | `{x, y}` 表 | Lua 无元组，用数组表 |
| `isinstance()` 检查 | `type()` + 元表检查 | Lua OOP 通过元表实现 |
| `random.choice()` | `math.random()` | Lua 标准库 |
| PySimpleGUI 渲染 | **NanoVG** 渲染 | 在 NanoVGRender 事件中绘制 |
| `copy()` 深拷贝 | 手动表复制 | 遍历 grid + pawns 复制 |
| 类继承 | **元表继承** | `setmetatable(obj, {__index = base})` |
| `print()` 日志 | `log:Write(LOG_INFO, ...)` | UrhoX 日志系统 |

### 关键规则遵守

- **NanoVG 渲染**: 只在 `NanoVGRender` 事件回调中绘制
- **字体创建**: `nvgCreateFont` 只在 `Start()` 中调用一次
- **数组索引**: 所有棋盘坐标从 1 开始（1-5）
- **文件存储**: 对局记录用 `File` API + cjson 序列化
- **枚举值**: 输入事件用 `MOUSEB_LEFT` 等枚举，不用数字

---

## 七、详细实现参考

- **完整模块实现** → `references/modules-implementation.md`
  - Board、Pawn、Player、Tester、Display 完整 Lua 代码
  - 3 种内置 AI 策略完整实现
- **集成示例** → `references/integration-examples.md`
  - 人机对战（鼠标点击交互）
  - AI 锦标赛（批量对局 + 统计报表）
  - 回放系统（对局记录 + 回放）
