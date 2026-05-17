# SantorinAI 集成示例

> 本文档提供三类完整集成场景：**人机对战**、**AI 锦标赛**、**回放系统**。
> 所有代码遵循 UrhoX 引擎核心规则（1-based 索引、NanoVGRender 事件、枚举常量等）。

---

## 一、人机对战（Human vs AI）

### 1.1 概述

玩家通过鼠标点击棋盘格子操作棋子，AI 自动回应。分为两个阶段：
- **放置阶段**：玩家和 AI 交替放置 2 枚棋子
- **对局阶段**：玩家选棋子 → 移动 → 建造，然后 AI 行动

### 1.2 完整实现

```lua
-- scripts/main.lua
-- 人机对战：玩家(P1) vs AI(P2)

require "LuaScripts/Utilities/Sample"

-- 引入模块（参见 modules-implementation.md）
local Board = require("scripts.santorinai.Board")
local Player = require("scripts.santorinai.Player")
local Display = require("scripts.santorinai.Display")
local BasicPlayer = require("scripts.santorinai.players.BasicPlayer")

-- ============================================================
-- HumanPlayer：通过鼠标点击操作
-- ============================================================
local HumanPlayer = Player.extend("You (Human)")

function HumanPlayer:new(playerNumber)
    local instance = Player.new(self, playerNumber)
    instance.pendingAction = nil   -- 等待的操作回调
    instance.selectedPawn = nil    -- 当前选中的棋子
    instance.movedPosition = nil   -- 已移动到的位置
    instance.phase = "idle"        -- idle | place | selectPawn | move | build
    return instance
end

-- 放置棋子：由外部点击事件设置 pendingAction
function HumanPlayer:placePawn(board, pawn)
    self.phase = "place"
    self.pendingAction = nil
    -- 返回 nil 表示等待输入（游戏循环检查 pendingAction）
    return nil
end

-- 对局行动：分三步（选棋子 → 移动 → 建造）
function HumanPlayer:playMove(board)
    self.phase = "selectPawn"
    self.selectedPawn = nil
    self.movedPosition = nil
    self.pendingAction = nil
    return nil
end

-- 检查是否有待处理的操作结果
function HumanPlayer:hasPendingResult()
    return self.pendingAction ~= nil
end

-- 获取操作结果并重置
function HumanPlayer:getPendingResult()
    local result = self.pendingAction
    self.pendingAction = nil
    return result
end

-- ============================================================
-- 游戏状态管理器
-- ============================================================
local GameState = {}

function GameState.new()
    local gs = {
        board = Board.new(2),
        humanPlayer = nil,
        aiPlayer = nil,
        currentPlayer = 1,       -- 1=人类, 2=AI
        phase = "placement",     -- placement | playing | gameOver
        placementStep = 0,       -- 0..3 (共放4枚棋子)
        turnPhase = "selectPawn",-- selectPawn | move | build
        selectedPawn = nil,
        movedPos = nil,
        validPositions = {},     -- 当前阶段的合法位置
        message = "放置你的第 1 枚棋子",
        winner = 0,
        highlightCell = nil,     -- 鼠标悬停高亮
    }
    gs.humanPlayer = HumanPlayer:new(1)
    gs.aiPlayer = BasicPlayer:new(2)
    gs.validPositions = gs:getEmptyPositions()
    setmetatable(gs, { __index = GameState })
    return gs
end

function GameState:getEmptyPositions()
    local positions = {}
    for x = 1, 5 do
        for y = 1, 5 do
            if not self.board:isPawnOnPosition({x, y}) then
                positions[#positions + 1] = {x, y}
            end
        end
    end
    return positions
end

function GameState:isValidPosition(pos)
    for _, vp in ipairs(self.validPositions) do
        if vp[1] == pos[1] and vp[2] == pos[2] then
            return true
        end
    end
    return false
end

-- 处理 AI 放置一枚棋子
function GameState:aiPlacePawn()
    local pawn = self.board:getFirstUnplacedPawn(2)
    if not pawn then return end

    local pos = self.aiPlayer:placePawn(self.board, pawn)
    if pos then
        self.board:placePawn(pawn.number, pos)
    end
end

-- 处理 AI 行动
function GameState:aiPlayMove()
    local result = self.aiPlayer:playMove(self.board)
    if result then
        local pawnNum, movePos, buildPos = result[1], result[2], result[3]
        self.board:playMove(pawnNum, movePos, buildPos)
        -- 检查胜负
        if self.board:isGameOver() then
            self.phase = "gameOver"
            self.winner = self.board.winnerPlayer
            if self.winner == 1 then
                self.message = "你赢了！"
            else
                self.message = "AI 获胜！"
            end
        end
    end
end

-- 处理玩家点击
function GameState:handleClick(gridPos)
    if self.phase == "gameOver" then return end

    -- === 放置阶段 ===
    if self.phase == "placement" then
        if not self:isValidPosition(gridPos) then return end

        -- 人类放置
        local humanPawn = self.board:getFirstUnplacedPawn(1)
        if humanPawn then
            self.board:placePawn(humanPawn.number, gridPos)
            self.placementStep = self.placementStep + 1
        end

        -- AI 放置
        self:aiPlacePawn()
        self.placementStep = self.placementStep + 1

        -- 检查放置是否完成
        if self.placementStep >= 4 then
            self.phase = "playing"
            self.turnPhase = "selectPawn"
            self.message = "选择你要移动的棋子"
            self:updateValidPawns()
        else
            self.message = string.format("放置你的第 %d 枚棋子",
                self.placementStep / 2 + 1)
            self.validPositions = self:getEmptyPositions()
        end
        return
    end

    -- === 对局阶段 ===
    if self.phase == "playing" then
        -- 选棋子
        if self.turnPhase == "selectPawn" then
            local pawn = self.board:getPawnAtPosition(gridPos)
            if pawn and pawn.playerNumber == 1 then
                -- 检查该棋子是否能移动
                local movable = self.board:getPossibleMovementPositions(pawn.number)
                if #movable > 0 then
                    self.selectedPawn = pawn.number
                    self.turnPhase = "move"
                    self.validPositions = movable
                    self.message = "选择移动目标"
                end
            end
            return
        end

        -- 移动
        if self.turnPhase == "move" then
            if not self:isValidPosition(gridPos) then return end
            self.movedPos = gridPos
            -- 临时执行移动以计算可建造位置
            local boardCopy = self.board:copy()
            local pawn = boardCopy:getPlayingPawn(self.selectedPawn)
            pawn:move(gridPos)
            local buildable = boardCopy:getPossibleBuildingPositions(self.selectedPawn)

            self.turnPhase = "build"
            self.validPositions = buildable
            self.message = "选择建造位置"
            return
        end

        -- 建造
        if self.turnPhase == "build" then
            if not self:isValidPosition(gridPos) then return end

            -- 执行完整操作
            self.board:playMove(self.selectedPawn, self.movedPos, gridPos)

            -- 检查人类是否获胜
            if self.board:isGameOver() then
                self.phase = "gameOver"
                self.winner = self.board.winnerPlayer
                self.message = "你赢了！"
                return
            end

            -- AI 回合
            self.message = "AI 思考中..."
            self:aiPlayMove()

            if self.phase ~= "gameOver" then
                self.turnPhase = "selectPawn"
                self.message = "选择你要移动的棋子"
                self:updateValidPawns()
            end
            return
        end
    end
end

function GameState:updateValidPawns()
    -- 有效位置 = 人类棋子所在位置（能移动的）
    self.validPositions = {}
    local pawns = self.board:getPlayerPawns(1)
    for _, pawn in ipairs(pawns) do
        if pawn:isPlaced() then
            local moves = self.board:getPossibleMovementPositions(pawn.number)
            if #moves > 0 then
                self.validPositions[#self.validPositions + 1] = pawn.pos
            end
        end
    end
end

function GameState:getPawnAtPosition(pos)
    for _, pawn in ipairs(self.board.pawns) do
        if pawn:isPlaced() and pawn.pos[1] == pos[1] and pawn.pos[2] == pos[2] then
            return pawn
        end
    end
    return nil
end

-- ============================================================
-- 主程序入口
-- ============================================================

---@type NanoVGContext
local vg = nil
local gameState = nil

-- 等距投影参数
local TILE_SIZE = 60
local BOARD_OFFSET_X = 400
local BOARD_OFFSET_Y = 100

-- 等距坐标转换：网格坐标 → 屏幕坐标
local function gridToScreen(gx, gy)
    local sx = BOARD_OFFSET_X + (gx - gy) * TILE_SIZE * 0.5
    local sy = BOARD_OFFSET_Y + (gx + gy) * TILE_SIZE * 0.25
    return sx, sy
end

-- 屏幕坐标 → 网格坐标（反向投影）
local function screenToGrid(sx, sy)
    local dx = sx - BOARD_OFFSET_X
    local dy = sy - BOARD_OFFSET_Y
    local gx = (dx / (TILE_SIZE * 0.5) + dy / (TILE_SIZE * 0.25)) * 0.5
    local gy = (dy / (TILE_SIZE * 0.25) - dx / (TILE_SIZE * 0.5)) * 0.5
    local rx = math.floor(gx + 0.5)
    local ry = math.floor(gy + 0.5)
    if rx >= 1 and rx <= 5 and ry >= 1 and ry <= 5 then
        return rx, ry
    end
    return nil, nil
end

function Start()
    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    gameState = GameState.new()

    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    local mx = eventData["X"]:GetInt()
    local my = eventData["Y"]:GetInt()
    local gx, gy = screenToGrid(mx, my)
    if gx and gy then
        gameState:handleClick({gx, gy})
    end
end

function HandleMouseMove(eventType, eventData)
    local mx = eventData["X"]:GetInt()
    local my = eventData["Y"]:GetInt()
    local gx, gy = screenToGrid(mx, my)
    if gx and gy then
        gameState.highlightCell = {gx, gy}
    else
        gameState.highlightCell = nil
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key == KEY_R then
        -- 重新开始
        gameState = GameState.new()
    elseif key == KEY_ESCAPE then
        engine:Exit()
    end
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()
    nvgBeginFrame(vg, w, h, graphics:GetDPR())

    -- 背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(30, 30, 50, 255))
    nvgFill(vg)

    -- 绘制棋盘
    Display.drawBoard(vg, gameState.board, BOARD_OFFSET_X, BOARD_OFFSET_Y, TILE_SIZE)

    -- 高亮合法位置
    for _, pos in ipairs(gameState.validPositions) do
        local sx, sy = gridToScreen(pos[1], pos[2])
        nvgBeginPath(vg)
        nvgEllipse(vg, sx, sy - 5, TILE_SIZE * 0.3, TILE_SIZE * 0.15)
        nvgFillColor(vg, nvgRGBA(0, 255, 100, 80))
        nvgFill(vg)
    end

    -- 鼠标悬停高亮
    if gameState.highlightCell then
        local hx, hy = gridToScreen(gameState.highlightCell[1], gameState.highlightCell[2])
        nvgBeginPath(vg)
        nvgEllipse(vg, hx, hy - 5, TILE_SIZE * 0.35, TILE_SIZE * 0.18)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 0, 150))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end

    -- 状态消息
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, w * 0.5, 20, gameState.message)

    -- 操作提示
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_BOTTOM)
    nvgText(vg, 10, h - 10, "[R] 重新开始  [ESC] 退出")

    -- 游戏结束画面
    if gameState.phase == "gameOver" then
        nvgBeginPath(vg)
        nvgRect(vg, w * 0.25, h * 0.35, w * 0.5, h * 0.3)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
        nvgFill(vg)

        nvgFontSize(vg, 48)
        nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
        if gameState.winner == 1 then
            nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
        else
            nvgFillColor(vg, nvgRGBA(255, 100, 100, 255))
        end
        nvgText(vg, w * 0.5, h * 0.45, gameState.message)

        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
        nvgText(vg, w * 0.5, h * 0.55, "按 R 重新开始")
    end

    nvgEndFrame(vg)
end
```

### 1.3 关键设计说明

| 要点 | 说明 |
|------|------|
| 异步交互 | HumanPlayer 返回 `nil` 表示等待鼠标输入，游戏循环轮询 `hasPendingResult()` |
| 坐标转换 | `gridToScreen` / `screenToGrid` 实现等距投影与反向拾取 |
| 操作流程 | 选棋子 → 移动 → 建造，每步高亮合法位置 |
| NanoVG 规则 | 所有绘制在 `NanoVGRender` 事件中，`nvgCreateFont` 只在 `Start()` 调用一次 |
| 输入枚举 | 使用 `MOUSEB_LEFT`、`KEY_R`、`KEY_ESCAPE` 等枚举常量 |

---

## 二、AI 锦标赛（Tournament）

### 2.1 概述

批量运行多组 AI 对局，统计胜率、胜利类型、ELO 评分，输出可视化报表。

### 2.2 完整实现

```lua
-- scripts/tournament.lua
-- AI 锦标赛：多 AI 循环对战 + 统计报表

require "LuaScripts/Utilities/Sample"

local Board = require("scripts.santorinai.Board")
local Tester = require("scripts.santorinai.Tester")
local Display = require("scripts.santorinai.Display")
local RandomPlayer = require("scripts.santorinai.players.RandomPlayer")
local FirstChoicePlayer = require("scripts.santorinai.players.FirstChoicePlayer")
local BasicPlayer = require("scripts.santorinai.players.BasicPlayer")

-- ============================================================
-- 锦标赛运行器
-- ============================================================
local Tournament = {}

function Tournament.new(players, gamesPerMatch)
    local t = {
        players = players,
        gamesPerMatch = gamesPerMatch or 50,
        results = {},       -- [i][j] = { wins=number, total=number }
        eloRatings = {},    -- [i] = rating
        tester = Tester.new(),
        isFinished = false,
        currentI = 1,
        currentJ = 2,
        progress = 0,
        totalMatches = 0,
        completedMatches = 0,
        matchLog = {},      -- 对局日志
    }

    -- 初始化结果矩阵和 ELO
    local n = #players
    t.totalMatches = n * (n - 1) / 2
    for i = 1, n do
        t.results[i] = {}
        t.eloRatings[i] = 1200  -- 初始 ELO
        for j = 1, n do
            t.results[i][j] = { wins = 0, total = 0 }
        end
    end

    setmetatable(t, { __index = Tournament })
    return t
end

-- ELO 评分更新
function Tournament:updateElo(winnerIdx, loserIdx)
    local K = 32
    local rw = self.eloRatings[winnerIdx]
    local rl = self.eloRatings[loserIdx]
    local ew = 1.0 / (1.0 + math.exp((rl - rw) / 400.0))
    self.eloRatings[winnerIdx] = rw + K * (1.0 - ew)
    self.eloRatings[loserIdx] = rl + K * (0.0 - (1.0 - ew))
end

-- 运行下一组对局（每帧调用一次，避免阻塞）
function Tournament:runNextMatch()
    if self.isFinished then return end

    local i = self.currentI
    local j = self.currentJ
    local n = #self.players

    if i > n then
        self.isFinished = true
        self:sortByElo()
        return
    end

    -- 运行一组对局
    local p1 = self.players[i]:new(1)
    local p2 = self.players[j]:new(2)
    local matchResult = self.tester:play1v1(p1, p2, self.gamesPerMatch)

    -- 记录结果
    local p1wins = matchResult.wins[1] or 0
    local p2wins = matchResult.wins[2] or 0
    self.results[i][j] = { wins = p1wins, total = self.gamesPerMatch }
    self.results[j][i] = { wins = p2wins, total = self.gamesPerMatch }

    -- 更新 ELO（按净胜场）
    if p1wins > p2wins then
        self:updateElo(i, j)
    elseif p2wins > p1wins then
        self:updateElo(j, i)
    end

    -- 记录日志
    self.matchLog[#self.matchLog + 1] = {
        p1Name = p1:name(),
        p2Name = p2:name(),
        p1Wins = p1wins,
        p2Wins = p2wins,
        draws = self.gamesPerMatch - p1wins - p2wins,
    }

    self.completedMatches = self.completedMatches + 1
    self.progress = self.completedMatches / self.totalMatches

    -- 移到下一组
    self.currentJ = j + 1
    if self.currentJ > n then
        self.currentI = self.currentI + 1
        self.currentJ = self.currentI + 1
    end
end

-- 按 ELO 排序
function Tournament:sortByElo()
    -- 创建索引数组
    self.rankings = {}
    for i = 1, #self.players do
        self.rankings[i] = i
    end
    table.sort(self.rankings, function(a, b)
        return self.eloRatings[a] > self.eloRatings[b]
    end)
end

-- ============================================================
-- 主程序
-- ============================================================

---@type NanoVGContext
local vg = nil
local tournament = nil

function Start()
    vg = nvgCreate(NVG_ANTIALIAS | NVG_STENCIL_STROKES)
    nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    -- 注册参赛 AI（使用类引用，非实例）
    local playerClasses = {
        RandomPlayer,
        FirstChoicePlayer,
        BasicPlayer,
    }

    tournament = Tournament.new(playerClasses, 100)

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

function HandleUpdate(eventType, eventData)
    -- 每帧运行一组对局
    if tournament and not tournament.isFinished then
        tournament:runNextMatch()
    end
end

function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key == KEY_ESCAPE then
        engine:Exit()
    elseif key == KEY_R then
        -- 重新开始锦标赛
        local playerClasses = { RandomPlayer, FirstChoicePlayer, BasicPlayer }
        tournament = Tournament.new(playerClasses, 100)
    end
end

function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()
    nvgBeginFrame(vg, w, h, graphics:GetDPR())

    -- 背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(20, 20, 35, 255))
    nvgFill(vg)

    nvgFontFace(vg, "sans")

    -- 标题
    nvgFontSize(vg, 32)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, w * 0.5, 20, "SantorinAI 锦标赛")

    -- 进度条
    local barX, barY, barW, barH = 50, 70, w - 100, 20
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 5)
    nvgFillColor(vg, nvgRGBA(50, 50, 70, 255))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW * tournament.progress, barH, 5)
    nvgFillColor(vg, nvgRGBA(100, 200, 100, 255))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgText(vg, w * 0.5, barY + barH * 0.5,
        string.format("%d / %d 组对局 (%.0f%%)",
            tournament.completedMatches, tournament.totalMatches,
            tournament.progress * 100))

    -- 排行榜
    local tableY = 120
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
    nvgText(vg, 50, tableY, "排名")
    nvgText(vg, 120, tableY, "AI 名称")
    nvgTextAlign(vg, NVG_ALIGN_RIGHT | NVG_ALIGN_TOP)
    nvgText(vg, w - 50, tableY, "ELO")

    tableY = tableY + 35
    local rankings = tournament.rankings or {}
    for rank, idx in ipairs(rankings) do
        local player = tournament.players[idx]
        local elo = tournament.eloRatings[idx]
        local instance = player:new(1)

        -- 排名颜色
        local r, g, b = 180, 180, 180
        if rank == 1 then r, g, b = 255, 215, 0
        elseif rank == 2 then r, g, b = 192, 192, 192
        elseif rank == 3 then r, g, b = 205, 127, 50
        end

        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(r, g, b, 255))
        nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
        nvgText(vg, 50, tableY, string.format("#%d", rank))
        nvgText(vg, 120, tableY, instance:name())
        nvgTextAlign(vg, NVG_ALIGN_RIGHT | NVG_ALIGN_TOP)
        nvgText(vg, w - 50, tableY, string.format("%.0f", elo))
        tableY = tableY + 30
    end

    -- 对局详情日志
    tableY = tableY + 20
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
    nvgText(vg, 50, tableY, "对局记录：")
    tableY = tableY + 25

    local startIdx = math.max(1, #tournament.matchLog - 8)
    for i = startIdx, #tournament.matchLog do
        local log = tournament.matchLog[i]
        nvgFontSize(vg, 15)
        nvgFillColor(vg, nvgRGBA(160, 160, 180, 220))
        nvgText(vg, 60, tableY,
            string.format("%s vs %s → %d:%d",
                log.p1Name, log.p2Name, log.p1Wins, log.p2Wins))
        tableY = tableY + 22
    end

    -- 底部提示
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(120, 120, 140, 200))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_BOTTOM)
    nvgText(vg, 10, h - 10, "[R] 重新开始  [ESC] 退出")

    nvgEndFrame(vg)
end
```

### 2.3 扩展：添加自定义 AI

```lua
-- scripts/santorinai/players/MySmartAI.lua
local Player = require("scripts.santorinai.Player")
local MySmartAI = Player.extend("Smart AI v1")

function MySmartAI:placePawn(board, pawn)
    -- 优先占据中心区域
    local preferred = {{3,3}, {3,2}, {2,3}, {4,3}, {3,4}}
    for _, pos in ipairs(preferred) do
        if not board:isPawnOnPosition(pos) then
            return pos
        end
    end
    -- 回退到随机
    local empty = {}
    for x = 1, 5 do
        for y = 1, 5 do
            if not board:isPawnOnPosition({x, y}) then
                empty[#empty + 1] = {x, y}
            end
        end
    end
    return empty[math.random(#empty)]
end

function MySmartAI:playMove(board)
    local bestScore = -math.huge
    local bestMove = nil

    local pawns = board:getPlayerPawns(self.playerNumber)
    for _, pawn in ipairs(pawns) do
        if not pawn:isPlaced() then goto continuePawn end
        local combos = board:getPossibleMovementAndBuildingPositions(pawn.number)
        for _, combo in ipairs(combos) do
            local movePos, buildPos = combo[1], combo[2]
            local score = self:evaluateMove(board, pawn, movePos, buildPos)
            if score > bestScore then
                bestScore = score
                bestMove = { pawn.number, movePos, buildPos }
            end
        end
        ::continuePawn::
    end

    return bestMove
end

function MySmartAI:evaluateMove(board, pawn, movePos, buildPos)
    local score = 0
    local targetLevel = board.grid[movePos[1]][movePos[2]]
    local currentLevel = board.grid[pawn.pos[1]][pawn.pos[2]]

    -- 登上 3 层 = 必赢（最高优先级）
    if targetLevel == 3 then return 10000 end

    -- 攀爬加分
    score = score + (targetLevel - currentLevel) * 50

    -- 高处加分
    score = score + targetLevel * 20

    -- 封堵对手（如果建造位置附近有对手棋子在高层）
    local opponentNum = (self.playerNumber == 1) and 2 or 1
    local opponentPawns = board:getPlayerPawns(opponentNum)
    for _, op in ipairs(opponentPawns) do
        if op:isPlaced() then
            local opLevel = board.grid[op.pos[1]][op.pos[2]]
            if opLevel == 2 and board:isAdjacent(buildPos, op.pos) then
                -- 在对手 2 层旁边建造封顶
                score = score + 80
            end
        end
    end

    -- 靠近中心加分
    local cx = math.abs(movePos[1] - 3)
    local cy = math.abs(movePos[2] - 3)
    score = score - (cx + cy) * 5

    return score
end

return MySmartAI
```

然后在锦标赛中注册：

```lua
local MySmartAI = require("scripts.santorinai.players.MySmartAI")
local playerClasses = { RandomPlayer, FirstChoicePlayer, BasicPlayer, MySmartAI }
tournament = Tournament.new(playerClasses, 100)
```

---

## 三、回放系统（Replay）

### 3.1 概述

记录每步操作（放置/移动/建造），支持 JSON 序列化存储和逐帧回放。

### 3.2 记录器

```lua
-- scripts/santorinai/Recorder.lua
-- 对局记录器：记录每步操作供回放

local cjson = require("cjson")

local Recorder = {}

function Recorder.new()
    local r = {
        metadata = {
            timestamp = os.time(),
            players = {},
        },
        steps = {},           -- { type, player, pawn, from, to, build, boardState }
        currentStep = 0,
    }
    setmetatable(r, { __index = Recorder })
    return r
end

-- 设置玩家信息
function Recorder:setPlayers(p1Name, p2Name)
    self.metadata.players = { p1Name, p2Name }
end

-- 记录放置操作
function Recorder:recordPlace(playerNum, pawnNum, position, boardSnapshot)
    self.steps[#self.steps + 1] = {
        type = "place",
        player = playerNum,
        pawn = pawnNum,
        position = { position[1], position[2] },
        board = boardSnapshot,
    }
end

-- 记录移动+建造操作
function Recorder:recordMove(playerNum, pawnNum, fromPos, toPos, buildPos, boardSnapshot)
    self.steps[#self.steps + 1] = {
        type = "move",
        player = playerNum,
        pawn = pawnNum,
        from = { fromPos[1], fromPos[2] },
        to = { toPos[1], toPos[2] },
        build = { buildPos[1], buildPos[2] },
        board = boardSnapshot,
    }
end

-- 记录胜利
function Recorder:recordWin(winner, reason)
    self.steps[#self.steps + 1] = {
        type = "win",
        player = winner,
        reason = reason,  -- "reached_level_3" | "opponent_stuck"
    }
end

-- 导出棋盘快照（深拷贝 grid）
function Recorder.snapshotBoard(board)
    local snap = {}
    for x = 1, 5 do
        snap[x] = {}
        for y = 1, 5 do
            snap[x][y] = board.grid[x][y]
        end
    end
    return snap
end

-- 序列化为 JSON 字符串
function Recorder:toJSON()
    return cjson.encode({
        metadata = self.metadata,
        steps = self.steps,
    })
end

-- 从 JSON 字符串反序列化
function Recorder.fromJSON(jsonStr)
    local data = cjson.decode(jsonStr)
    local r = Recorder.new()
    r.metadata = data.metadata
    r.steps = data.steps
    return r
end

-- 保存到文件（使用引擎 File API）
function Recorder:saveToFile(filename)
    local file = File:new(filename, FILE_WRITE)
    if file then
        local json = self:toJSON()
        file:Write(json, #json)
        file:Close()
        log:Write(LOG_INFO, "Replay saved to: " .. filename)
        return true
    end
    log:Write(LOG_ERROR, "Failed to save replay: " .. filename)
    return false
end

-- 从文件加载
function Recorder.loadFromFile(filename)
    local file = File:new(filename, FILE_READ)
    if file then
        local size = file:GetSize()
        local content = file:Read(size)
        file:Close()
        return Recorder.fromJSON(content)
    end
    log:Write(LOG_ERROR, "Failed to load replay: " .. filename)
    return nil
end

return Recorder
```

### 3.3 回放播放器

```lua
-- scripts/santorinai/ReplayPlayer.lua
-- 对局回放播放器：逐步播放记录的操作

local Board = require("scripts.santorinai.Board")

local ReplayPlayer = {}

function ReplayPlayer.new(recorder)
    local rp = {
        recorder = recorder,
        board = Board.new(2),
        currentStep = 0,
        totalSteps = #recorder.steps,
        isPlaying = false,
        playbackSpeed = 1.0,     -- 秒/步
        timer = 0,
        isFinished = false,
    }
    setmetatable(rp, { __index = ReplayPlayer })
    return rp
end

-- 前进一步
function ReplayPlayer:stepForward()
    if self.currentStep >= self.totalSteps then
        self.isFinished = true
        return false
    end

    self.currentStep = self.currentStep + 1
    local step = self.recorder.steps[self.currentStep]

    if step.type == "place" then
        self.board:placePawn(step.pawn, step.position)
    elseif step.type == "move" then
        self.board:playMove(step.pawn, step.to, step.build)
    elseif step.type == "win" then
        self.isFinished = true
    end

    return true
end

-- 后退一步（通过从头重放到 currentStep - 1）
function ReplayPlayer:stepBackward()
    if self.currentStep <= 0 then return false end

    local targetStep = self.currentStep - 1
    self:reset()
    for _ = 1, targetStep do
        self:stepForward()
    end
    self.isFinished = false
    return true
end

-- 重置到开头
function ReplayPlayer:reset()
    self.board = Board.new(2)
    self.currentStep = 0
    self.isFinished = false
    self.timer = 0
end

-- 跳转到指定步骤
function ReplayPlayer:jumpToStep(targetStep)
    self:reset()
    targetStep = math.max(0, math.min(targetStep, self.totalSteps))
    for _ = 1, targetStep do
        self:stepForward()
    end
    self.isFinished = (self.currentStep >= self.totalSteps)
end

-- 自动播放更新（每帧调用）
function ReplayPlayer:update(dt)
    if not self.isPlaying or self.isFinished then return end

    self.timer = self.timer + dt
    if self.timer >= self.playbackSpeed then
        self.timer = self.timer - self.playbackSpeed
        self:stepForward()
    end
end

-- 播放/暂停
function ReplayPlayer:togglePlay()
    self.isPlaying = not self.isPlaying
end

-- 获取当前步骤信息
function ReplayPlayer:getCurrentStepInfo()
    if self.currentStep < 1 then
        return { type = "start", description = "对局开始" }
    end
    local step = self.recorder.steps[self.currentStep]
    if step.type == "place" then
        return {
            type = "place",
            description = string.format("玩家%d 放置棋子%d 到 (%d,%d)",
                step.player, step.pawn, step.position[1], step.position[2])
        }
    elseif step.type == "move" then
        return {
            type = "move",
            description = string.format("玩家%d 棋子%d: (%d,%d)→(%d,%d), 建造(%d,%d)",
                step.player, step.pawn,
                step.from[1], step.from[2],
                step.to[1], step.to[2],
                step.build[1], step.build[2])
        }
    elseif step.type == "win" then
        return {
            type = "win",
            description = string.format("玩家%d 获胜！(%s)",
                step.player, step.reason or "")
        }
    end
    return { type = "unknown", description = "" }
end

return ReplayPlayer
```

### 3.4 回放 UI 集成

```lua
-- 在 NanoVGRender 事件中绘制回放控制条
function drawReplayControls(vg, replayPlayer, x, y, w)
    local rp = replayPlayer
    local h = 60

    -- 背景条
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 8)
    nvgFillColor(vg, nvgRGBA(30, 30, 50, 220))
    nvgFill(vg)

    -- 进度条
    local barX = x + 80
    local barW = w - 160
    local barY = y + 10
    local barH = 8
    local progress = rp.totalSteps > 0 and (rp.currentStep / rp.totalSteps) or 0

    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 4)
    nvgFillColor(vg, nvgRGBA(60, 60, 80, 255))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW * progress, barH, 4)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgFill(vg)

    -- 步骤计数
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_TOP)
    nvgText(vg, x + w * 0.5, barY + barH + 4,
        string.format("%d / %d", rp.currentStep, rp.totalSteps))

    -- 当前步骤描述
    local info = rp:getCurrentStepInfo()
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + w * 0.5, y + 35, info.description)

    -- 控制按钮提示
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(150, 150, 170, 200))
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
    nvgText(vg, x + 10, y + h - 18,
        "[←] 后退  [→] 前进  [Space] 播放/暂停  [Home] 重置")
end

-- 键盘控制（在 HandleKeyDown 中调用）
function handleReplayKeys(key, replayPlayer)
    if key == KEY_RIGHT then
        replayPlayer.isPlaying = false
        replayPlayer:stepForward()
    elseif key == KEY_LEFT then
        replayPlayer.isPlaying = false
        replayPlayer:stepBackward()
    elseif key == KEY_SPACE then
        replayPlayer:togglePlay()
    elseif key == KEY_HOME then
        replayPlayer:reset()
    elseif key == KEY_PAGEUP then
        replayPlayer.playbackSpeed = math.max(0.1, replayPlayer.playbackSpeed - 0.2)
    elseif key == KEY_PAGEDOWN then
        replayPlayer.playbackSpeed = replayPlayer.playbackSpeed + 0.2
    end
end
```

### 3.5 使用流程

```lua
-- 1. 对局时录制
local Recorder = require("scripts.santorinai.Recorder")
local recorder = Recorder.new()
recorder:setPlayers("Human", "BasicAI")

-- 每次放置棋子后
recorder:recordPlace(playerNum, pawnNum, position, Recorder.snapshotBoard(board))

-- 每次移动+建造后
recorder:recordMove(playerNum, pawnNum, fromPos, toPos, buildPos, Recorder.snapshotBoard(board))

-- 对局结束
recorder:recordWin(winnerNum, "reached_level_3")
recorder:saveToFile("replays/game001.json")

-- 2. 回放时加载
local ReplayPlayer = require("scripts.santorinai.ReplayPlayer")
local savedRecorder = Recorder.loadFromFile("replays/game001.json")
local replayPlayer = ReplayPlayer.new(savedRecorder)

-- 在 HandleUpdate 中
replayPlayer:update(dt)

-- 在 HandleNanoVGRender 中
Display.drawBoard(vg, replayPlayer.board, ox, oy, tileSize)
drawReplayControls(vg, replayPlayer, 50, h - 80, w - 100)
```

---

## 四、UrhoX 引擎合规要点总结

本文档所有代码遵循以下引擎核心规则：

| 规则编号 | 要点 | 本文档中的体现 |
|---------|------|---------------|
| #0 | 长度单位是米 | 棋盘可视化使用像素坐标（2D NanoVG），不涉及 3D 米制 |
| #3 | eventData 访问 | `eventData["Key"]:GetInt()`、`eventData["Button"]:GetInt()` |
| #4 | 数组索引从 1 | 棋盘 `grid[1..5][1..5]`，所有循环 `for i = 1, n` |
| #6 | NanoVGRender 事件 | 所有 NanoVG 绘制在 `HandleNanoVGRender` 中 |
| #7 | 字体只创建一次 | `nvgCreateFont` 在 `Start()` 中调用，不在渲染循环 |
| #0.8 | 分辨率 | 使用 `graphics:GetWidth()/GetDPR()` 获取逻辑分辨率 |
| #9 | 输入枚举 | `MOUSEB_LEFT`、`KEY_R`、`KEY_ESCAPE`、`KEY_SPACE` 等 |
| #12 | 枚举不猜数字 | 无任何硬编码按键数字 |
| 文件存储 | File API | Recorder 使用 `File:new()` 替代 `io` 库 |
