# SantorinAI — 模块完整实现

> 本文档包含所有核心模块的完整 Lua 实现代码。
> 所有坐标使用 **1-based 索引**（1-5），遵循 Lua 惯例。

---

## 1. Pawn.lua — 棋子数据结构

```lua
-- santorinai/Pawn.lua
local Pawn = {}
Pawn.__index = Pawn

--- 创建棋子
---@param number number 棋子全局编号 (1-4)
---@param order number 玩家内编号 (1 或 2)
---@param playerNumber number 所属玩家 (1 或 2)
---@return table
function Pawn.new(number, order, playerNumber)
    local self = setmetatable({}, Pawn)
    self.number = number          -- 全局编号 1-4
    self.order = order            -- 玩家内编号 1 或 2
    self.playerNumber = playerNumber
    self.pos = {nil, nil}         -- {x, y}，nil 表示未放置
    return self
end

--- 移动棋子
---@param newPos table {x, y}
function Pawn:move(newPos)
    self.pos = {newPos[1], newPos[2]}
end

--- 棋子是否已放置
---@return boolean
function Pawn:isPlaced()
    return self.pos[1] ~= nil and self.pos[2] ~= nil
end

--- 深拷贝
---@return table
function Pawn:copy()
    local p = Pawn.new(self.number, self.order, self.playerNumber)
    p.pos = {self.pos[1], self.pos[2]}
    return p
end

--- 字符串表示
function Pawn:__tostring()
    local posStr = self:isPlaced()
        and ("(" .. self.pos[1] .. "," .. self.pos[2] .. ")")
        or "(unplaced)"
    return "Pawn#" .. self.order .. " P" .. self.playerNumber .. " " .. posStr
end

return Pawn
```

---

## 2. Board.lua — 棋盘状态与规则引擎

```lua
-- santorinai/Board.lua
local Pawn = require("santorinai.Pawn")

local Board = {}
Board.__index = Board
Board.BOARD_SIZE = 5

--- 创建棋盘
---@param numberOfPlayers number 玩家数量 (2)
---@return table
function Board.new(numberOfPlayers)
    local self = setmetatable({}, Board)
    numberOfPlayers = numberOfPlayers or 2
    self.nbPlayers = numberOfPlayers
    self.nbPawns = numberOfPlayers * 2
    self.boardSize = Board.BOARD_SIZE

    -- 创建棋子: 2 人模式 → P1 拥有棋子 1,3; P2 拥有棋子 2,4
    self.pawns = {}
    for i = 1, self.nbPawns do
        local playerNum = ((i - 1) % numberOfPlayers) + 1
        local order = math.floor((i - 1) / numberOfPlayers) + 1
        self.pawns[i] = Pawn.new(i, order, playerNum)
    end

    -- 初始化 5×5 网格 (1-based, 值 0-4)
    self.grid = {}
    for x = 1, self.boardSize do
        self.grid[x] = {}
        for y = 1, self.boardSize do
            self.grid[x][y] = 0
        end
    end

    self.winnerPlayerNumber = nil
    self.turnNumber = 1
    self.playerTurn = 1

    return self
end

--- 检查位置是否在棋盘内
---@param pos table {x, y}
---@return boolean
function Board:isWithinBoard(pos)
    local x, y = pos[1], pos[2]
    return x ~= nil and y ~= nil
        and x >= 1 and x <= self.boardSize
        and y >= 1 and y <= self.boardSize
end

--- 检查两个位置是否相邻
---@param pos1 table {x, y}
---@param pos2 table {x, y}
---@return boolean
function Board:isAdjacent(pos1, pos2)
    local dx = math.abs(pos1[1] - pos2[1])
    local dy = math.abs(pos1[2] - pos2[2])
    return dx <= 1 and dy <= 1 and (dx + dy > 0)
end

--- 检查位置上是否有棋子
---@param pos table {x, y}
---@return boolean
function Board:isPawnOnPosition(pos)
    for _, pawn in ipairs(self.pawns) do
        if pawn:isPlaced() and pawn.pos[1] == pos[1] and pawn.pos[2] == pos[2] then
            return true
        end
    end
    return false
end

--- 检查移动是否合法
---@param startPos table {x, y}
---@param endPos table {x, y}
---@return boolean, string
function Board:isMovePossible(startPos, endPos)
    if not self:isWithinBoard(startPos) then
        return false, "Cannot move from outside the board."
    end
    if not self:isWithinBoard(endPos) then
        return false, "Cannot move outside the board."
    end
    if startPos[1] == endPos[1] and startPos[2] == endPos[2] then
        return false, "Cannot move to the same position."
    end
    local startLevel = self.grid[startPos[1]][startPos[2]]
    local endLevel = self.grid[endPos[1]][endPos[2]]
    if endLevel == 4 then
        return false, "Cannot move onto a domed tower."
    end
    if endLevel - startLevel > 1 then
        return false, "Cannot climb more than one level."
    end
    if not self:isAdjacent(startPos, endPos) then
        return false, "Position is not adjacent."
    end
    if self:isPawnOnPosition(endPos) then
        return false, "Position is occupied by another pawn."
    end
    return true, "Move is valid."
end

--- 检查建造是否合法
---@param builderPos table {x, y}
---@param buildPos table {x, y}
---@return boolean, string
function Board:isBuildPossible(builderPos, buildPos)
    if not self:isWithinBoard(builderPos) then
        return false, "Cannot build from outside the board."
    end
    if not self:isWithinBoard(buildPos) then
        return false, "Cannot build outside the board."
    end
    if builderPos[1] == buildPos[1] and builderPos[2] == buildPos[2] then
        return false, "Cannot build where you are standing."
    end
    if self.grid[buildPos[1]][buildPos[2]] == 4 then
        return false, "Cannot build on a domed tower."
    end
    if not self:isAdjacent(builderPos, buildPos) then
        return false, "Build position is not adjacent."
    end
    if self:isPawnOnPosition(buildPos) then
        return false, "Cannot build on another pawn."
    end
    return true, "Build is valid."
end

--- 获取玩家的棋子列表
---@param playerNumber number
---@return table
function Board:getPlayerPawns(playerNumber)
    local result = {}
    for _, pawn in ipairs(self.pawns) do
        if pawn.playerNumber == playerNumber then
            result[#result + 1] = pawn
        end
    end
    return result
end

--- 获取当前玩家的第 N 枚棋子
---@param pawnNumber number 1 或 2
---@return table|nil
function Board:getPlayingPawn(pawnNumber)
    if pawnNumber < 1 or pawnNumber > 2 then return nil end
    local playerPawns = self:getPlayerPawns(self.playerTurn)
    return playerPawns[pawnNumber]
end

--- 获取玩家第一个未放置的棋子
---@param playerNumber number
---@return table|nil
function Board:getFirstUnplacedPawn(playerNumber)
    for _, pawn in ipairs(self.pawns) do
        if pawn.playerNumber == playerNumber and not pawn:isPlaced() then
            return pawn
        end
    end
    return nil
end

--- 获取棋子可移动位置列表
---@param pawn table Pawn
---@return table 位置列表 {{x,y}, ...}
function Board:getPossibleMovementPositions(pawn)
    local moves = {}
    if not pawn:isPlaced() then
        -- 未放置: 所有非封顶、无棋子的位置
        for x = 1, self.boardSize do
            for y = 1, self.boardSize do
                if self.grid[x][y] ~= 4 and not self:isPawnOnPosition({x, y}) then
                    moves[#moves + 1] = {x, y}
                end
            end
        end
        return moves
    end
    -- 已放置: 检查周围 8 格
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx, ny = pawn.pos[1] + dx, pawn.pos[2] + dy
                local ok, _ = self:isMovePossible(pawn.pos, {nx, ny})
                if ok then
                    moves[#moves + 1] = {nx, ny}
                end
            end
        end
    end
    return moves
end

--- 获取棋子可建造位置列表
---@param pawn table Pawn (假设已移动到新位置)
---@return table 位置列表 {{x,y}, ...}
function Board:getPossibleBuildingPositions(pawn)
    if not pawn:isPlaced() then return {} end
    local builds = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local bx, by = pawn.pos[1] + dx, pawn.pos[2] + dy
                local ok, _ = self:isBuildPossible(pawn.pos, {bx, by})
                if ok then
                    builds[#builds + 1] = {bx, by}
                end
            end
        end
    end
    return builds
end

--- 获取棋子所有合法 移动+建造 组合
---@param pawn table Pawn
---@return table {{movePos, buildPos}, ...}
function Board:getPossibleMovementAndBuildingPositions(pawn)
    if not pawn:isPlaced() then
        local spawns = self:getPossibleMovementPositions(pawn)
        local result = {}
        for _, pos in ipairs(spawns) do
            result[#result + 1] = {pos, nil}
        end
        return result
    end

    local result = {}
    local origPos = {pawn.pos[1], pawn.pos[2]}
    local moves = self:getPossibleMovementPositions(pawn)

    for _, movePos in ipairs(moves) do
        pawn:move(movePos)
        local builds = self:getPossibleBuildingPositions(pawn)
        for _, buildPos in ipairs(builds) do
            result[#result + 1] = {movePos, buildPos}
        end
    end

    -- 恢复原位
    pawn:move(origPos)
    return result
end

--- 放置棋子
---@param position table {x, y}
---@return boolean, string
function Board:placePawn(position)
    if self:isGameOver() then
        return false, "Game is over."
    end
    local pawn = self:getFirstUnplacedPawn(self.playerTurn)
    if not pawn then
        return false, "All pawns already placed."
    end
    if not self:isWithinBoard(position) then
        return false, "Position is outside the board."
    end
    if self:isPawnOnPosition(position) then
        return false, "Position is occupied."
    end
    pawn:move(position)
    self:nextTurn()
    return true, "Pawn placed."
end

--- 执行一步棋 (选棋子 → 移动 → 建造)
---@param pawnNumber number 棋子编号 (1 或 2)
---@param movePos table {x, y} 移动目标
---@param buildPos table {x, y} 建造目标
---@return boolean, string
function Board:playMove(pawnNumber, movePos, buildPos)
    if type(pawnNumber) ~= "number" or pawnNumber < 1 or pawnNumber > 2 then
        return false, "Invalid pawn number (must be 1 or 2)."
    end
    local unplaced = self:getFirstUnplacedPawn(self.playerTurn)
    if unplaced then
        return false, "Not all pawns have been placed yet."
    end
    local pawn = self:getPlayingPawn(pawnNumber)
    if self:isGameOver() then
        return false, "Game is over."
    end

    -- 检查棋子是否能移动
    local possibleMoves = self:getPossibleMovementPositions(pawn)
    if #possibleMoves == 0 then
        return false, "Selected pawn is stuck."
    end

    -- 验证移动
    if not self:isWithinBoard(movePos) then
        return false, "Move position is outside the board."
    end
    local moveOk, moveReason = self:isMovePossible(pawn.pos, movePos)
    if not moveOk then
        return false, moveReason
    end

    -- 执行移动
    local initialPos = {pawn.pos[1], pawn.pos[2]}
    pawn:move(movePos)

    -- 检查胜利: 登顶 level 3
    if self.grid[pawn.pos[1]][pawn.pos[2]] == 3 then
        self.winnerPlayerNumber = pawn.playerNumber
        return true, "Pawn reached the top of a tower\!"
    end

    -- 验证建造
    if not self:isWithinBoard(buildPos) then
        pawn:move(initialPos)
        return false, "Build position is outside the board."
    end
    local buildOk, buildReason = self:isBuildPossible(pawn.pos, buildPos)
    if not buildOk then
        pawn:move(initialPos)
        return false, buildReason
    end

    -- 执行建造
    self.grid[buildPos[1]][buildPos[2]] = self.grid[buildPos[1]][buildPos[2]] + 1

    -- 检查是否所有人都被困住
    if self:isEveryoneStuck() then
        self.winnerPlayerNumber = pawn.playerNumber
        return true, "No one can move, game over."
    end

    -- 切换回合
    self:nextTurn()

    -- 检查下一个玩家是否被困
    local nextPawns = self:getPlayerPawns(self.playerTurn)
    local nextStuck = true
    for _, p in ipairs(nextPawns) do
        if #self:getPossibleMovementPositions(p) > 0 then
            nextStuck = false
            break
        end
    end
    if nextStuck then
        self.winnerPlayerNumber = pawn.playerNumber
        return true, "Next player is stuck, game over."
    end

    return true, "Move played."
end

--- 游戏是否结束
---@return boolean
function Board:isGameOver()
    return self.winnerPlayerNumber ~= nil or self:isEveryoneStuck()
end

--- 所有棋子是否被困住
---@return boolean
function Board:isEveryoneStuck()
    for _, pawn in ipairs(self.pawns) do
        if #self:getPossibleMovementPositions(pawn) > 0 then
            return false
        end
    end
    return true
end

--- 切换回合
function Board:nextTurn()
    self.playerTurn = self.playerTurn + 1
    if self.playerTurn > self.nbPlayers then
        self.playerTurn = 1
    end
    self.turnNumber = self.turnNumber + 1
end

--- 深拷贝棋盘
---@return table
function Board:copy()
    local b = Board.new(self.nbPlayers)
    for x = 1, self.boardSize do
        for y = 1, self.boardSize do
            b.grid[x][y] = self.grid[x][y]
        end
    end
    b.pawns = {}
    for i, pawn in ipairs(self.pawns) do
        b.pawns[i] = pawn:copy()
    end
    b.turnNumber = self.turnNumber
    b.playerTurn = self.playerTurn
    b.winnerPlayerNumber = self.winnerPlayerNumber
    return b
end

return Board
```

---

## 3. Player.lua — AI 玩家抽象接口

```lua
-- santorinai/Player.lua
local Player = {}
Player.__index = Player

--- 创建玩家基类 (不直接使用，通过 extend 派生)
---@param playerNumber number 玩家编号 (1 或 2)
---@return table
function Player.new(playerNumber)
    local self = setmetatable({}, Player)
    self.playerNumber = playerNumber
    return self
end

--- 派生子类
---@param className string 玩家名称
---@return table 子类表
function Player.extend(className)
    local SubClass = setmetatable({}, { __index = Player })
    SubClass.__index = SubClass
    SubClass._name = className

    function SubClass.new(playerNumber)
        local self = setmetatable({}, SubClass)
        self.playerNumber = playerNumber
        return self
    end

    return SubClass
end

--- 返回玩家名称 (子类必须覆盖)
---@return string
function Player:name()
    return self._name or "UnnamedPlayer"
end

--- 放置棋子 (子类必须覆盖)
---@param board table Board
---@param pawn table Pawn
---@return table {x, y}
function Player:placePawn(board, pawn)
    error("Player:placePawn() must be overridden")
end

--- 执行一步棋 (子类必须覆盖)
---@param board table Board
---@return number, table, table  pawnNumber, movePos, buildPos
function Player:playMove(board)
    error("Player:playMove() must be overridden")
end

return Player
```

---

## 4. Tester.lua — 对局运行器与统计

```lua
-- santorinai/Tester.lua
local Board = require("santorinai.Board")

local Tester = {}
Tester.__index = Tester

--- 创建测试器
---@return table
function Tester.new()
    local self = setmetatable({}, Tester)
    self.verboseLevel = 1  -- 0=静默, 1=每局, 2=每步
    self.lastBoard = nil   -- 保留最后一局棋盘
    return self
end

--- 运行 1v1 批量对局
---@param player1 table Player
---@param player2 table Player
---@param nbGames number 对局数量
---@return table {wins={}, winTypes={}}
function Tester:play1v1(player1, player2, nbGames)
    nbGames = nbGames or 1
    local NB_PLAYERS = 2
    local players = { player1, player2 }
    local names = { player1:name(), player2:name() }

    local wins = { [names[1]] = 0, [names[2]] = 0 }
    local winTypes = { [names[1]] = {}, [names[2]] = {} }

    for gameNb = 1, nbGames do
        if self.verboseLevel >= 1 then
            log:Write(LOG_INFO, "SantorinAI: Game " .. gameNb)
        end

        local board = Board.new(NB_PLAYERS)
        local gameAborted = false

        -- 放置阶段: 4 枚棋子轮流放置
        for i = 1, board.nbPawns do
            local playerIdx = ((i - 1) % NB_PLAYERS) + 1
            local player = players[playerIdx]
            local boardCopy = board:copy()
            local pawn = board.pawns[i]
            local pawnCopy = boardCopy.pawns[i]

            local ok, err = pcall(function()
                local pos = player:placePawn(boardCopy, pawnCopy)
                local success, reason = board:placePawn(pos)
                if not success then
                    local otherIdx = (playerIdx % NB_PLAYERS) + 1
                    wins[names[otherIdx]] = wins[names[otherIdx]] + 1
                    self:registerWinType(winTypes[names[playerIdx]],
                        "Invalid placement: " .. reason)
                    gameAborted = true
                end
            end)
            if not ok then
                local otherIdx = (playerIdx % NB_PLAYERS) + 1
                wins[names[otherIdx]] = wins[names[otherIdx]] + 1
                self:registerWinType(winTypes[names[playerIdx]],
                    "Error in placePawn: " .. tostring(err))
                gameAborted = true
            end
            if gameAborted then break end
        end

        -- 对局阶段
        if not gameAborted then
            while not board:isGameOver() do
                local playerIdx = board.playerTurn
                local player = players[playerIdx]
                local boardCopy = board:copy()

                local ok, err = pcall(function()
                    local pawnNum, movePos, buildPos = player:playMove(boardCopy)
                    local success, reason = board:playMove(pawnNum, movePos, buildPos)
                    if not success then
                        local otherIdx = (playerIdx % NB_PLAYERS) + 1
                        wins[names[otherIdx]] = wins[names[otherIdx]] + 1
                        self:registerWinType(winTypes[names[playerIdx]],
                            "Invalid move: " .. reason)
                        gameAborted = true
                    else
                        if self.verboseLevel >= 2 then
                            log:Write(LOG_INFO, "SantorinAI: " .. names[playerIdx]
                                .. " pawn" .. pawnNum
                                .. " move(" .. movePos[1] .. "," .. movePos[2] .. ")"
                                .. " build(" .. buildPos[1] .. "," .. buildPos[2] .. ")")
                        end
                    end
                end)
                if not ok then
                    local otherIdx = (playerIdx % NB_PLAYERS) + 1
                    wins[names[otherIdx]] = wins[names[otherIdx]] + 1
                    self:registerWinType(winTypes[names[playerIdx]],
                        "Error in playMove: " .. tostring(err))
                    gameAborted = true
                end
                if gameAborted then break end
            end
        end

        -- 记录胜者
        if not gameAborted and board.winnerPlayerNumber then
            local winnerName = names[board.winnerPlayerNumber]
            wins[winnerName] = wins[winnerName] + 1
        end

        self.lastBoard = board
    end

    -- 输出汇总
    if self.verboseLevel >= 1 then
        log:Write(LOG_INFO, "SantorinAI Results:")
        for _, name in ipairs(names) do
            local pct = nbGames > 0
                and string.format("%.1f%%", wins[name] / nbGames * 100)
                or "0%"
            log:Write(LOG_INFO, "  " .. name .. ": " .. wins[name]
                .. " wins (" .. pct .. ")")
        end
    end

    return { wins = wins, winTypes = winTypes }
end

--- 记录胜负类型
---@param dic table 类型计数字典
---@param msg string 类型描述
function Tester:registerWinType(dic, msg)
    dic[msg] = (dic[msg] or 0) + 1
end

return Tester
```

---

## 5. Display.lua — NanoVG 等距可视化

```lua
-- santorinai/Display.lua
local Display = {}

-- 玩家棋子颜色
local PAWN_COLORS = {
    [1] = { 220, 80, 80 },    -- 红色
    [2] = { 80, 120, 220 },   -- 蓝色
}

-- 塔层颜色 (从底到顶)
local LEVEL_COLORS = {
    [0] = { 200, 200, 200 },  -- 空地 - 浅灰
    [1] = { 240, 240, 240 },  -- 一层 - 白灰
    [2] = { 210, 210, 210 },  -- 二层 - 中灰
    [3] = { 180, 180, 180 },  -- 三层 - 深灰
    [4] = { 60, 100, 200 },   -- 封顶 - 蓝色圆顶
}

--- 绘制等距方块
local function drawIsoCube(vg, cx, cy, size, height, r, g, b)
    local hw = size * 0.5   -- 半宽
    local hh = size * 0.25  -- 半高 (等距比例)

    -- 顶面
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - hh)
    nvgLineTo(vg, cx + hw, cy)
    nvgLineTo(vg, cx, cy + hh)
    nvgLineTo(vg, cx - hw, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(40, 40, 40, 180))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    if height > 0 then
        -- 左侧面
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - hw, cy)
        nvgLineTo(vg, cx, cy + hh)
        nvgLineTo(vg, cx, cy + hh + height)
        nvgLineTo(vg, cx - hw, cy + height)
        nvgClosePath(vg)
        local dr = math.max(0, r - 40)
        local dg = math.max(0, g - 40)
        local db = math.max(0, b - 40)
        nvgFillColor(vg, nvgRGBA(dr, dg, db, 255))
        nvgFill(vg)
        nvgStroke(vg)

        -- 右侧面
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + hw, cy)
        nvgLineTo(vg, cx, cy + hh)
        nvgLineTo(vg, cx, cy + hh + height)
        nvgLineTo(vg, cx + hw, cy + height)
        nvgClosePath(vg)
        local lr = math.max(0, r - 20)
        local lg = math.max(0, g - 20)
        local lb = math.max(0, b - 20)
        nvgFillColor(vg, nvgRGBA(lr, lg, lb, 255))
        nvgFill(vg)
        nvgStroke(vg)
    end
end

--- 绘制棋子 (椭圆)
local function drawPawn(vg, cx, cy, radius, r, g, b, number)
    -- 阴影
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + radius * 0.8, radius * 0.7, radius * 0.25)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80))
    nvgFill(vg)

    -- 棋子主体
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy, radius * 0.6, radius)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(30, 30, 30, 200))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 编号
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, radius * 1.0)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, cx, cy, tostring(number))
end

--- 绘制完整棋盘
---@param vg userdata NanoVG 上下文
---@param board table Board 实例
---@param ox number 左上角 X 偏移
---@param oy number 左上角 Y 偏移
---@param tileSize number 每格大小
function Display.drawBoard(vg, board, ox, oy, tileSize)
    local bs = board.boardSize
    local levelH = tileSize * 0.15  -- 每层高度

    -- 从后到前绘制 (等距排序)
    for row = 1, bs do
        for col = 1, bs do
            local level = board.grid[col][row]

            -- 等距坐标转换
            local cx = ox + (col - row) * tileSize * 0.5 + bs * tileSize * 0.25
            local cy = oy + (col + row) * tileSize * 0.25

            -- 绘制底座
            drawIsoCube(vg, cx, cy, tileSize * 0.8, levelH * 0.5,
                200, 200, 200)

            -- 绘制塔层
            local stackY = cy
            for lv = 1, math.min(level, 4) do
                stackY = stackY - levelH
                local c = LEVEL_COLORS[lv] or { 150, 150, 150 }
                local shrink = lv * 0.06
                drawIsoCube(vg, cx, stackY, tileSize * (0.7 - shrink),
                    levelH, c[1], c[2], c[3])
            end

            -- 绘制棋子
            for _, pawn in ipairs(board.pawns) do
                if pawn:isPlaced() and pawn.pos[1] == col and pawn.pos[2] == row then
                    local pLevel = board.grid[col][row]
                    local py = cy - pLevel * levelH - tileSize * 0.2
                    local pc = PAWN_COLORS[pawn.playerNumber] or { 150, 150, 150 }
                    drawPawn(vg, cx, py, tileSize * 0.22,
                        pc[1], pc[2], pc[3], pawn.order)
                end
            end
        end
    end
end

--- 绘制统计面板
---@param vg userdata NanoVG 上下文
---@param results table tester:play1v1 返回的结果
---@param x number 左上角 X
---@param y number 左上角 Y
function Display.drawStats(vg, results, x, y)
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    -- 标题
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x, y, "Match Results")
    y = y + 30

    -- 各玩家胜场
    nvgFontSize(vg, 18)
    local totalGames = 0
    for _, w in pairs(results.wins) do totalGames = totalGames + w end

    for name, w in pairs(results.wins) do
        local pct = totalGames > 0
            and string.format("%.1f%%", w / totalGames * 100)
            or "0%"
        nvgFillColor(vg, nvgRGBA(200, 220, 255, 255))
        nvgText(vg, x, y, name .. ": " .. w .. " wins (" .. pct .. ")")
        y = y + 24
    end

    -- 胜负类型
    y = y + 10
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(180, 180, 180, 255))
    for name, types in pairs(results.winTypes) do
        for reason, count in pairs(types) do
            nvgText(vg, x + 10, y, name .. " - " .. reason .. ": " .. count)
            y = y + 20
        end
    end
end

return Display
```

---

## 6. 内置 AI 玩家

### 6.1 RandomPlayer.lua — 随机策略

```lua
-- santorinai/players/RandomPlayer.lua
local Player = require("santorinai.Player")

local RandomPlayer = Player.extend("Randy Random")

function RandomPlayer:placePawn(board, pawn)
    local positions = board:getPossibleMovementPositions(pawn)
    return positions[math.random(#positions)]
end

function RandomPlayer:playMove(board)
    local allMoves = {}
    local pawns = board:getPlayerPawns(self.playerNumber)
    for _, pawn in ipairs(pawns) do
        local combos = board:getPossibleMovementAndBuildingPositions(pawn)
        for _, combo in ipairs(combos) do
            allMoves[#allMoves + 1] = { pawn.order, combo[1], combo[2] }
        end
    end
    local chosen = allMoves[math.random(#allMoves)]
    return chosen[1], chosen[2], chosen[3]
end

return RandomPlayer
```

### 6.2 FirstChoicePlayer.lua — 首选策略

```lua
-- santorinai/players/FirstChoicePlayer.lua
local Player = require("santorinai.Player")

local FirstChoicePlayer = Player.extend("Firsty First")

function FirstChoicePlayer:placePawn(board, pawn)
    local positions = board:getPossibleMovementPositions(pawn)
    return positions[1]
end

function FirstChoicePlayer:playMove(board)
    local pawns = board:getPlayerPawns(self.playerNumber)
    local pawn = pawns[1]
    local moves = board:getPossibleMovementPositions(pawn)
    if #moves == 0 then
        return pawn.order, nil, nil
    end
    local movePos = moves[1]

    -- 模拟移动获取建造位置
    local origPos = { pawn.pos[1], pawn.pos[2] }
    pawn:move(movePos)
    local builds = board:getPossibleBuildingPositions(pawn)
    pawn:move(origPos)

    if #builds == 0 then
        return pawn.order, movePos, nil
    end
    return pawn.order, movePos, builds[1]
end

return FirstChoicePlayer
```

### 6.3 BasicPlayer.lua — 启发式策略

```lua
-- santorinai/players/BasicPlayer.lua
local Player = require("santorinai.Player")

local BasicPlayer = Player.extend("Extra BaThick\!")

--- 获取对手的棋子列表
local function getOpponentPawns(board, myPlayerNumber)
    local result = {}
    for _, pawn in ipairs(board.pawns) do
        if pawn.playerNumber ~= myPlayerNumber then
            result[#result + 1] = pawn
        end
    end
    return result
end

--- 获取对手的必胜位置 (level 3 可移动到的格子)
local function getWinningMoves(board, pawn)
    local result = {}
    local moves = board:getPossibleMovementPositions(pawn)
    for _, pos in ipairs(moves) do
        if board.grid[pos[1]][pos[2]] == 3 then
            result[#result + 1] = pos
        end
    end
    return result
end

function BasicPlayer:placePawn(board, pawn)
    local positions = board:getPossibleMovementPositions(pawn)

    -- 第二枚棋子: 尽量靠近第一枚
    local allyPawns = board:getPlayerPawns(self.playerNumber)
    for _, ally in ipairs(allyPawns) do
        if ally.number ~= pawn.number and ally:isPlaced() then
            for _, pos in ipairs(positions) do
                if board:isAdjacent(pos, ally.pos) then
                    return pos
                end
            end
        end
    end
    return positions[math.random(#positions)]
end

function BasicPlayer:playMove(board)
    local pawns = board:getPlayerPawns(self.playerNumber)
    local bestSpot, bestPawnIdx, bestLevel = nil, nil, -999

    for idx, pawn in ipairs(pawns) do
        if not pawn:isPlaced() then
            error("Pawn not placed yet")
        end

        local moves = board:getPossibleMovementPositions(pawn)
        local curLevel = board.grid[pawn.pos[1]][pawn.pos[2]]

        for _, pos in ipairs(moves) do
            local posLevel = board.grid[pos[1]][pos[2]]

            -- 优先: 登顶即胜
            if posLevel == 3 then
                return pawn.order, pos, {0, 0}  -- build 无所谓
            end

            -- 爬高评分
            if posLevel > bestLevel then
                bestSpot = pos
                bestPawnIdx = idx
                bestLevel = posLevel
            end
        end

        -- 检查: 阻止对手登顶
        local enemies = getOpponentPawns(board, self.playerNumber)
        for _, enemy in ipairs(enemies) do
            local winMoves = getWinningMoves(board, enemy)
            for _, wm in ipairs(winMoves) do
                for _, myPos in ipairs(moves) do
                    if board:isAdjacent(wm, myPos) then
                        return pawn.order, myPos, wm
                    end
                end
            end
        end
    end

    -- 选择最佳爬高位置
    if bestSpot and bestPawnIdx then
        local pawn = pawns[bestPawnIdx]
        local origPos = { pawn.pos[1], pawn.pos[2] }
        pawn:move(bestSpot)
        local builds = board:getPossibleBuildingPositions(pawn)
        pawn:move(origPos)
        local buildChoice = #builds > 0
            and builds[math.random(#builds)]
            or bestSpot
        return pawn.order, bestSpot, buildChoice
    end

    -- 兜底: 随机
    local pawn = pawns[math.random(#pawns)]
    local combos = board:getPossibleMovementAndBuildingPositions(pawn)
    if #combos > 0 then
        local chosen = combos[math.random(#combos)]
        return pawn.order, chosen[1], chosen[2]
    end
    return pawn.order, nil, nil
end

return BasicPlayer
```
