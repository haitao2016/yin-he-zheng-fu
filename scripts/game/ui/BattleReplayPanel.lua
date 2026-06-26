---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/BattleReplayPanel.lua -- 战斗回放控制面板
-- V3.3 M2
-- ============================================================================

local BattleReplayPanel = {}

local panel = nil
local playerStateRef = nil
local playbackSpeed = 1.0
local SPEED_OPTIONS = { 0.5, 1, 2, 4 }

---打开战斗回放面板
---@param playerState table 玩家状态引用
---@param replayList table 回放列表
---@return table
function BattleReplayPanel.open(playerState, replayList)
    playerStateRef = playerState
    panel = {
        visible = true,
        w = 620,
        h = 460,
        tab = "LIST",
        replayList = replayList or BattleReplayPanel.getReplayList(),
        selectedReplayId = nil,
        currentFrame = 1,
        playing = false,
        speed = 1.0,
        scrollY = 0,
    }
    playbackSpeed = 1.0
    return panel
end

---关闭面板
function BattleReplayPanel.close()
    if panel then
        panel.visible = false
        panel.playing = false
        panel = nil
    end
end

---面板是否打开
---@return boolean
function BattleReplayPanel.isOpen()
    return panel ~= nil and panel.visible == true
end

---切换播放速度（循环切换 0.5/1/2/4）
---@param speed number
function BattleReplayPanel.setSpeed(speed)
    if not panel then return end
    for _, v in ipairs(SPEED_OPTIONS) do
        if math.abs(v - speed) < 0.01 then
            panel.speed = v
            playbackSpeed = v
            return
        end
    end
end

---跳到下一帧
function BattleReplayPanel.nextFrame()
    if not panel or not panel.replayList then return end
    local replay = BattleReplayPanel.getCurrentReplay()
    if not replay then return end
    panel.currentFrame = math.min(panel.currentFrame + 1, replay.totalFrames or #(replay.frames or {}) or 1)
end

---跳到上一帧
function BattleReplayPanel.prevFrame()
    if not panel then return end
    panel.currentFrame = math.max(panel.currentFrame - 1, 1)
end

---跳转到指定帧索引
---@param index number
function BattleReplayPanel.seekTo(index)
    if not panel then return end
    local replay = BattleReplayPanel.getCurrentReplay()
    if not replay then return end
    local total = replay.totalFrames or #(replay.frames or {}) or 1
    panel.currentFrame = math.max(1, math.min(index, total))
end

---处理用户输入（键盘/手柄）
---@param action string
function BattleReplayPanel.handleInput(action)
    if not panel or not panel.visible then return end
    if action == "SPACE" then
        panel.playing = not panel.playing
    elseif action == "RIGHT" then
        BattleReplayPanel.nextFrame()
    elseif action == "LEFT" then
        BattleReplayPanel.prevFrame()
    elseif action == "UP" then
        local idx = 1
        for i, v in ipairs(SPEED_OPTIONS) do
            if math.abs(v - panel.speed) < 0.01 then idx = i end
        end
        local nextIdx = math.min(#SPEED_OPTIONS, idx + 1)
        BattleReplayPanel.setSpeed(SPEED_OPTIONS[nextIdx])
    elseif action == "DOWN" then
        local idx = 1
        for i, v in ipairs(SPEED_OPTIONS) do
            if math.abs(v - panel.speed) < 0.01 then idx = i end
        end
        local prevIdx = math.max(1, idx - 1)
        BattleReplayPanel.setSpeed(SPEED_OPTIONS[prevIdx])
    elseif action == "ESCAPE" then
        BattleReplayPanel.close()
    end
end

---获取回放列表（对接 BattleReplayPlayer.lua）
---@return table
function BattleReplayPanel.getReplayList()
    local ok, BRP = pcall(require, "game.systems.BattleReplayPlayer")
    if ok and BRP and BRP.getReplayList then
        return BRP.getReplayList() or {}
    end
    return BattleReplayPanel.getMockReplayList()
end

---获取指定回放详情
---@param replayId string|number
---@return table
function BattleReplayPanel.getReplay(replayId)
    local ok, BRP = pcall(require, "game.systems.BattleReplayPlayer")
    if ok and BRP and BRP.getReplay then
        return BRP.getReplay(replayId)
    end
    return { id = replayId, name = "回放 #" .. tostring(replayId), totalFrames = 120, frames = {} }
end

---获取播放状态
---@return table
function BattleReplayPanel.getPlaybackState()
    local ok, BRP = pcall(require, "game.systems.BattleReplayPlayer")
    if ok and BRP and BRP.getPlaybackState then
        return BRP.getPlaybackState() or {}
    end
    return { playing = panel and panel.playing or false, frame = panel and panel.currentFrame or 1 }
end

---导出当前回放到 JSON
---@param replayId string|number
---@return string
function BattleReplayPanel.exportReplay(replayId)
    local replay = BattleReplayPanel.getReplay(replayId)
    if not replay then return "{}" end
    local data = {
        version = "1.0",
        replayId = replay.id,
        name = replay.name,
        timestamp = replay.timestamp or os.time(),
        duration = replay.duration or 0,
        totalFrames = replay.totalFrames or #(replay.frames or {}),
        battleType = replay.battleType or "UNKNOWN",
        result = replay.result or "UNKNOWN",
        fleet = replay.fleet or {},
        keyFrames = replay.keyFrames or {},
    }
    return BattleReplayPanel.toJSON(data)
end

---返回当前视图状态（供外部检查）
---@return table
function BattleReplayPanel.getCurrentView()
    if not panel then return { visible = false } end
    local replay = BattleReplayPanel.getCurrentReplay()
    return {
        visible = true,
        tab = panel.tab,
        speed = panel.speed,
        playing = panel.playing,
        currentFrame = panel.currentFrame,
        totalFrames = replay and (replay.totalFrames or #(replay.frames or {})) or 0,
        selectedReplayId = panel.selectedReplayId,
    }
end

-- ============================================================================
-- 内部辅助方法
-- ============================================================================

function BattleReplayPanel.getCurrentReplay()
    if not panel then return nil end
    if panel.selectedReplayId ~= nil then
        for _, r in ipairs(panel.replayList) do
            if r.id == panel.selectedReplayId then return r end
        end
    end
    return nil
end

function BattleReplayPanel.getMockReplayList()
    local list = {}
    for i = 1, 8 do
        list[i] = {
            id = i,
            name = string.format("战斗回放 #%04d", 1000 + i),
            battleType = (i % 3 == 0) and "BOSS" or (i % 2 == 0) and "ARENA" or "NORMAL",
            duration = 60 + i * 15,
            totalFrames = 120 + i * 30,
            result = (i % 4 == 0) and "DEFEAT" or "VICTORY",
            timestamp = os.time() - i * 3600,
            shipsCount = 4 + (i % 5),
        }
    end
    return list
end

function BattleReplayPanel.toJSON(data)
    if type(data) == "nil" then return "null" end
    if type(data) == "boolean" then return data and "true" or "false" end
    if type(data) == "number" then return tostring(data) end
    if type(data) == "string" then
        local s = data:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
        return '"' .. s .. '"'
    end
    if type(data) == "table" then
        local isArray = true
        local count = 0
        for k, _ in pairs(data) do
            if type(k) ~= "number" or k ~= count + 1 then isArray = false end
            count = count + 1
        end
        if isArray then
            local parts = {}
            for _, v in ipairs(data) do parts[#parts + 1] = BattleReplayPanel.toJSON(v) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(data) do parts[#parts + 1] = '"' .. tostring(k) .. '":' .. BattleReplayPanel.toJSON(v) end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function BattleReplayPanel.formatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

function BattleReplayPanel.formatDateTime(timestamp)
    if not timestamp then return "-" end
    return os.date("%m-%d %H:%M", timestamp)
end

-- ============================================================================
-- 主渲染入口
-- ============================================================================

function BattleReplayPanel.render()
    local vg = _G.BS and _G.BS.vg or nil
    if not vg then return end
    BattleReplayPanel.draw(vg)
end

---主绘制
---@param vg userdata
function BattleReplayPanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or 800) / 2, (BS and BS.screenH or 600) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2

    -- 主背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 245))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 200, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题栏
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 45, 12)
    nvgRect(vg, px, py + 20, pw, 25)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 240))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "战斗回放")

    -- 状态条（标题栏下方）
    local statusY = py + 50
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px + 10, statusY, pw - 20, 28, 4)
    nvgFillColor(vg, nvgRGBA(22, 30, 50, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 90, 140, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    local statusColor = panel.playing and nvgRGBA(100, 255, 140, 255) or nvgRGBA(200, 200, 220, 255)
    nvgFillColor(vg, statusColor)
    nvgText(vg, px + 20, statusY + 14, panel.playing and "▶ 播放中" or "⏸ 已暂停")

    nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
    local total = panel.replayList and #panel.replayList or 0
    nvgText(vg, px + 110, statusY + 14, "共 " .. tostring(total) .. " 个回放")

    nvgFillColor(vg, nvgRGBA(255, 200, 100, 255))
    nvgText(vg, px + 230, statusY + 14, string.format("速度: %.1fx", panel.speed))

    if panel.selectedReplayId ~= nil then
        local cur = BattleReplayPanel.getCurrentReplay()
        if cur then
            nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
            nvgText(vg, px + 330, statusY + 14, "当前: " .. (cur.name or "-"))
        end
    end

    -- 关闭按钮
    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        BattleReplayPanel.close()
    end)

    local contentY = statusY + 38
    local contentH = ph - (contentY - py) - 90

    -- 中部：回放列表 + 详情
    if panel.tab == "LIST" then
        BattleReplayPanel.drawList(vg, px + 15, contentY, (pw - 30) * 0.55 - 5, contentH)
        BattleReplayPanel.drawDetail(vg, px + 15 + (pw - 30) * 0.55 + 5, contentY, (pw - 30) * 0.45 - 5, contentH)
    else
        BattleReplayPanel.drawPlayer(vg, px + 15, contentY, pw - 30, contentH)
    end

    -- 底部控制面板
    local controlY = contentY + contentH + 10
    BattleReplayPanel.drawControls(vg, px + 15, controlY, pw - 30, 70)
end

---绘制回放列表
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleReplayPanel.drawList(vg, x, y, w, h)
    -- 列表标题
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, 24, 4)
    nvgFillColor(vg, nvgRGBA(30, 40, 65, 230))
    nvgFill(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 200, 255, 255))
    nvgText(vg, x + 10, y + 12, "📼 回放列表")

    local itemY = y + 28
    local itemH = 48
    local itemGap = 5

    if not panel.replayList or #panel.replayList == 0 then
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w / 2, y + h / 2, "暂无回放记录")
        return
    end

    for i, replay in ipairs(panel.replayList) do
        local ry = itemY + (i - 1) * (itemH + itemGap) - panel.scrollY
        if ry + itemH < y + 28 then goto continue end
        if ry > y + h then break end

        local isSelected = panel.selectedReplayId == replay.id

        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, ry, w, itemH, 5)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(60, 100, 170, 230))
            nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 200))
        else
            nvgFillColor(vg, nvgRGBA(25, 35, 55, 210))
            nvgStrokeColor(vg, nvgRGBA(70, 90, 130, 100))
        end
        nvgFill(vg)
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 类型标记色
        local typeColor = nvgRGBA(100, 180, 255, 255)
        if replay.battleType == "BOSS" then typeColor = nvgRGBA(255, 100, 150, 255)
        elseif replay.battleType == "ARENA" then typeColor = nvgRGBA(255, 200, 80, 255)
        end

        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 6, ry + 6, 6, itemH - 12, 2)
        nvgFillColor(vg, typeColor)
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(230, 235, 250, 255))
        nvgText(vg, x + 20, ry + 16, replay.name or ("回放 #" .. tostring(replay.id)))

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
        nvgText(vg, x + 20, ry + 30, string.format("%s  %s  %d帧",
            BattleReplayPanel.formatDateTime(replay.timestamp),
            BattleReplayPanel.formatTime(replay.duration),
            replay.totalFrames or 0))

        -- 结果标签
        local resultColor = replay.result == "VICTORY" and nvgRGBA(100, 230, 140, 255) or nvgRGBA(230, 100, 100, 255)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, resultColor)
        nvgText(vg, x + w - 10, ry + 16, replay.result == "VICTORY" and "胜利" or "失败")

        nvgFillColor(vg, typeColor)
        nvgText(vg, x + w - 10, ry + 30, replay.battleType)

        addHit(x, ry, w, itemH, function()
            panel.selectedReplayId = replay.id
            panel.currentFrame = 1
            panel.playing = false
        end)
        ::continue::
    end

    -- 滚动条
    local totalListH = #(panel.replayList or {}) * (itemH + itemGap)
    if totalListH > (h - 28) then
        local sbH = math.max(20, (h - 28) * (h - 28) / totalListH)
        local sbY = y + 28 + (h - 28 - sbH) * (panel.scrollY / math.max(1, totalListH - (h - 28)))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + w - 4, sbY, 3, sbH, 2)
        nvgFillColor(vg, nvgRGBA(120, 160, 220, 180))
        nvgFill(vg)
    end
end

---绘制选中回放详情
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleReplayPanel.drawDetail(vg, x, y, w, h)
    -- 标题
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, 24, 4)
    nvgFillColor(vg, nvgRGBA(30, 40, 65, 230))
    nvgFill(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 200, 255, 255))
    nvgText(vg, x + 10, y + 12, "📋 回放详情")

    local detailX, detailY = x + 10, y + 34
    local detailW = w - 20

    local current = BattleReplayPanel.getCurrentReplay()
    if not current then
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w / 2, y + h / 2, "请选择一个回放")
        return
    end

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(230, 235, 250, 255))
    nvgText(vg, detailX, detailY, current.name)

    -- 信息行
    local info = {
        { "类型", current.battleType, nvgRGBA(150, 200, 255, 255) },
        { "时长", BattleReplayPanel.formatTime(current.duration), nvgRGBA(200, 220, 255, 255) },
        { "帧数", tostring(current.totalFrames or 0), nvgRGBA(200, 220, 255, 255) },
        { "结果", current.result == "VICTORY" and "胜利" or "失败",
            current.result == "VICTORY" and nvgRGBA(100, 230, 140, 255) or nvgRGBA(230, 100, 100, 255) },
        { "时间", BattleReplayPanel.formatDateTime(current.timestamp), nvgRGBA(180, 180, 200, 255) },
        { "舰队", tostring(current.shipsCount or 0) .. " 艘", nvgRGBA(255, 200, 120, 255) },
    }

    nvgFontSize(vg, 11)
    for i, row in ipairs(info) do
        local ry = detailY + 22 + (i - 1) * 22
        if ry > y + h - 100 then break end
        nvgFillColor(vg, nvgRGBA(150, 170, 200, 255))
        nvgText(vg, detailX, ry, row[1])
        nvgFillColor(vg, row[3])
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgText(vg, detailX + detailW, ry, row[2])
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
    end

    -- 关键帧列表（简易）
    local kfY = detailY + 22 + #info * 22 + 10
    if kfY < y + h - 40 then
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(200, 180, 120, 255))
        nvgText(vg, detailX, kfY, "关键帧跳转")

        local kfs = current.keyFrames or {
            { frame = 1, label = "开始" },
            { frame = math.floor((current.totalFrames or 100) * 0.3), label = "战斗中" },
            { frame = math.floor((current.totalFrames or 100) * 0.6), label = "高潮" },
            { frame = current.totalFrames or 100, label = "结束" },
        }

        local kfRowY = kfY + 16
        local kfBtnW = (detailW - 10) / #kfs
        for i, kf in ipairs(kfs) do
            local bx = detailX + (i - 1) * (kfBtnW + 3)
            local by = kfRowY
            local bh = 26
            local bw = kfBtnW - 3

            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, by, bw, bh, 4)
            nvgFillColor(vg, nvgRGBA(45, 55, 85, 230))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(120, 150, 200, 150))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.CENTER)
            nvgFillColor(vg, nvgRGBA(200, 210, 230, 255))
            nvgText(vg, bx + bw / 2, by + 11, kf.label)
            nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
            nvgText(vg, bx + bw / 2, by + 22, "帧 " .. tostring(kf.frame))

            addHit(bx, by, bw, bh, function()
                panel.currentFrame = kf.frame
                panel.tab = "PLAYER"
            end)
        end
    end

    -- 导出按钮
    local expX = detailX
    local expY = y + h - 34
    local expW = detailW
    local expH = 28
    nvgBeginPath(vg)
    nvgRoundedRect(vg, expX, expY, expW, expH, 4)
    nvgFillColor(vg, nvgRGBA(80, 120, 70, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(130, 200, 120, 200))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 255, 200, 255))
    nvgText(vg, expX + expW / 2, expY + expH / 2, "⬇ 导出 JSON")

    addHit(expX, expY, expW, expH, function()
        local json = BattleReplayPanel.exportReplay(panel.selectedReplayId)
        if NotifyPanel then
            NotifyPanel.push({
                type = "INFO",
                title = "回放已导出",
                message = string.format("回放 #%s 已导出（%d字符）", tostring(panel.selectedReplayId), #json),
            })
        end
    end)
end

---绘制播放视图
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleReplayPanel.drawPlayer(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(18, 26, 45, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 100, 150, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local current = BattleReplayPanel.getCurrentReplay()
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(220, 230, 250, 255))
    nvgText(vg, x + w / 2, y + 30, current and current.name or "无选中回放")

    local totalFrames = current and (current.totalFrames or 100) or 100
    local curSec = current and (current.duration or 120) * (panel.currentFrame / totalFrames) or 0
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
    nvgText(vg, x + w / 2, y + 50,
        string.format("帧 %d / %d   时间 %s  速度 %.1fx",
            panel.currentFrame, totalFrames,
            BattleReplayPanel.formatTime(curSec),
            panel.speed))

    -- 播放状态
    nvgFontSize(vg, 36)
    nvgFillColor(vg, panel.playing and nvgRGBA(100, 230, 140, 220) or nvgRGBA(230, 180, 100, 220))
    nvgText(vg, x + w / 2, y + h / 2 + 20, panel.playing and "▶" or "⏸")

    -- 返回列表按钮
    local backX = x + w - 90
    local backY = y + 8
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, backY, 80, 24, 4)
    nvgFillColor(vg, nvgRGBA(60, 80, 130, 230))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 230, 250, 255))
    nvgText(vg, backX + 40, backY + 12, "← 列表")
    addHit(backX, backY, 80, 24, function() panel.tab = "LIST" end)
end

---绘制底部控制面板（进度条 + 速度切换 + 逐帧 + 播放）
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleReplayPanel.drawControls(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(22, 30, 50, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 110, 160, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 进度条
    local barX = x + 15
    local barY = y + 12
    local barW = w - 30
    local barH = 10

    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(35, 50, 80, 240))
    nvgFill(vg)

    local current = BattleReplayPanel.getCurrentReplay()
    local total = current and (current.totalFrames or 100) or 100
    local progress = math.max(0, math.min(1, panel.currentFrame / total))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW * progress, barH, 3)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 240))
    nvgFill(vg)

    addHit(barX, barY - 6, barW, barH + 12, function()
        if _G.BS and _G.BS.mouseX and _G.BS.mouseY then
            local mx = _G.BS.mouseX
            local localX = mx - barX
            local p = math.max(0, math.min(1, localX / barW))
            panel.currentFrame = math.floor(p * total) + 1
        end
    end)

    -- 帧标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
    nvgText(vg, barX, barY - 3, string.format("帧 %d / %d", panel.currentFrame, total))
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    local curSec = current and (current.duration or 120) * progress or 0
    local totSec = current and (current.duration or 120) or 0
    nvgText(vg, barX + barW, barY - 3, string.format("%s / %s",
        BattleReplayPanel.formatTime(curSec),
        BattleReplayPanel.formatTime(totSec)))

    -- 播放/暂停 + 逐帧 + 速度 按钮行
    local btnY = y + 32
    local btnH = 28
    local totalBtnW = 30 + 4 + 70 + 4 + 70 + 4 + 200 + 4 + 80
    local startX = x + (w - totalBtnW) / 2

    -- 播放/暂停
    local bx = startX
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, btnY, 30, btnH, 4)
    nvgFillColor(vg, panel.playing and nvgRGBA(150, 80, 80, 230) or nvgRGBA(80, 130, 80, 230))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, bx + 15, btnY + btnH / 2, panel.playing and "⏸" or "▶")
    addHit(bx, btnY, 30, btnH, function()
        panel.playing = not panel.playing
    end)

    -- 上一帧
    bx = startX + 30 + 4
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, btnY, 70, btnH, 4)
    nvgFillColor(vg, nvgRGBA(60, 90, 140, 230))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(220, 230, 250, 255))
    nvgText(vg, bx + 35, btnY + btnH / 2, "◀ 上一帧")
    addHit(bx, btnY, 70, btnH, function()
        BattleReplayPanel.prevFrame()
        panel.playing = false
    end)

    -- 下一帧
    bx = bx + 70 + 4
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, btnY, 70, btnH, 4)
    nvgFillColor(vg, nvgRGBA(60, 90, 140, 230))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(220, 230, 250, 255))
    nvgText(vg, bx + 35, btnY + btnH / 2, "下一帧 ▶")
    addHit(bx, btnY, 70, btnH, function()
        BattleReplayPanel.nextFrame()
        panel.playing = false
    end)

    -- 速度切换（四个选项）
    bx = bx + 70 + 4
    local speedBtnW = (200 - 4 * 3) / 4
    for i, sp in ipairs(SPEED_OPTIONS) do
        local sx = bx + (i - 1) * (speedBtnW + 4)
        local isActive = math.abs(panel.speed - sp) < 0.01
        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx, btnY, speedBtnW, btnH, 4)
        nvgFillColor(vg, isActive and nvgRGBA(80, 140, 200, 240) or nvgRGBA(40, 60, 95, 230))
        nvgFill(vg)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(255, 255, 255, 255) or nvgRGBA(180, 200, 230, 255))
        nvgText(vg, sx + speedBtnW / 2, btnY + btnH / 2, string.format("%.1fx", sp))
        addHit(sx, btnY, speedBtnW, btnH, function()
            BattleReplayPanel.setSpeed(sp)
        end)
    end

    -- 播放视图切换
    bx = bx + 200 + 4
    local playerActive = panel.tab == "PLAYER"
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, btnY, 80, btnH, 4)
    nvgFillColor(vg, playerActive and nvgRGBA(150, 100, 150, 230) or nvgRGBA(60, 80, 130, 230))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 235, 250, 255))
    nvgText(vg, bx + 40, btnY + btnH / 2, playerActive and "列表" or "播放视图")
    addHit(bx, btnY, 80, btnH, function()
        panel.tab = (panel.tab == "PLAYER") and "LIST" or "PLAYER"
    end)
end

return BattleReplayPanel
