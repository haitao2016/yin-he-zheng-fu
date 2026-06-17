-- ============================================================================
-- game/BattleReplaySystem.lua  -- P3-1: 战斗回放与精彩时刻系统
-- ============================================================================
-- 功能：
--   1. 战斗帧录制（每隔 RECORD_INTERVAL 秒快照舰船位置/HP/护盾/状态）
--   2. 关键事件记录（击杀、Boss击败、连击、暴击、技能释放、舰船损失）
--   3. MVP 计算（基于伤害、击杀、存活的综合评分）
--   4. 回放数据供 EndGamePanel / ReplayViewer 使用
-- ============================================================================

local BattleReplaySystem = {}

-- ── 常量 ──────────────────────────────────────────────────────────────────────
local RECORD_INTERVAL   = 0.25   -- 每 0.25 秒记录一帧快照
local MAX_FRAMES        = 1200   -- 最多记录 300 秒（1200 帧 × 0.25s）
local MAX_EVENTS        = 500    -- 最多记录 500 个关键事件
local HIGHLIGHT_WINDOW  = 3.0    -- 精彩时刻窗口：事件前后 3 秒

-- ── 事件类型常量 ──────────────────────────────────────────────────────────────
BattleReplaySystem.EVENT = {
    KILL         = "kill",          -- 击杀敌舰
    BOSS_KILL    = "boss_kill",     -- Boss 击败
    SHIP_LOST    = "ship_lost",     -- 我方损失
    COMBO        = "combo",         -- 连击达成（≥5 连）
    OVERKILL     = "overkill",      -- 过度击杀（≥150%）
    SKILL_USE    = "skill_use",     -- 技能释放
    WAVE_CLEAR   = "wave_clear",    -- 波次通关
    CHAIN        = "chain",         -- 连锁反应
    CRIT_BURST   = "crit_burst",    -- 瞬间爆发（单帧高伤害）
    NEMESIS_KILL = "nemesis_kill",  -- 宿敌击败
}

-- ── 私有状态 ──────────────────────────────────────────────────────────────────
local recording_    = false      -- 是否正在录制
local frames_       = {}         -- 帧快照列表 [{time, playerShips, enemyShips}]
local events_       = {}         -- 关键事件列表 [{time, type, data}]
local timer_        = 0          -- 累计时间
local lastRecord_   = 0          -- 上次快照时间
local shipTracker_  = {}         -- 舰船累计统计 {[shipId] = {dmg, kills, surviveTime}}
local nextShipId_   = 1          -- 舰船唯一ID分配器
local highlights_   = {}         -- 精彩时刻列表（战斗结束后计算）
local mvpResult_    = nil        -- MVP 结果缓存

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 开始录制（在 BattleScene.Reset() 后调用）
function BattleReplaySystem.StartRecording()
    recording_   = true
    frames_      = {}
    events_      = {}
    timer_       = 0
    lastRecord_  = 0
    shipTracker_ = {}
    nextShipId_  = 1
    highlights_  = {}
    mvpResult_   = nil
    print("[P3-1 Replay] 录制开始")
end

--- 停止录制（战斗结束时调用）
function BattleReplaySystem.StopRecording()
    if not recording_ then return end
    recording_ = false
    -- 计算精彩时刻和 MVP
    BattleReplaySystem._computeHighlights()
    BattleReplaySystem._computeMVP()
    print(string.format("[P3-1 Replay] 录制结束: %d帧, %d事件, %d精彩时刻",
        #frames_, #events_, #highlights_))
end

--- 每帧调用：记录快照（由 BattleScene.Update 调用）
---@param dt number         帧间隔
---@param playerFleet table 玩家舰队数组
---@param enemyFleet table  敌方舰队数组
function BattleReplaySystem.RecordFrame(dt, playerFleet, enemyFleet)
    if not recording_ then return end
    timer_ = timer_ + dt

    -- 更新舰船存活时间统计
    for _, ship in ipairs(playerFleet) do
        if ship._replayId then
            local tr = shipTracker_[ship._replayId]
            if tr then tr.surviveTime = timer_ end
        end
    end

    -- 按间隔快照
    if timer_ - lastRecord_ < RECORD_INTERVAL then return end
    if #frames_ >= MAX_FRAMES then return end
    lastRecord_ = timer_

    -- 快照玩家舰队
    local pSnap = {}
    for _, ship in ipairs(playerFleet) do
        pSnap[#pSnap + 1] = {
            id   = ship._replayId or 0,
            x    = math.floor(ship.x),
            y    = math.floor(ship.y),
            hp   = ship.health,
            maxHp= ship.maxHealth,
            sh   = ship.shield or 0,
            type = ship.stype,
        }
    end

    -- 快照敌方舰队
    local eSnap = {}
    for _, ship in ipairs(enemyFleet) do
        eSnap[#eSnap + 1] = {
            x    = math.floor(ship.x),
            y    = math.floor(ship.y),
            hp   = ship.health,
            maxHp= ship.maxHealth,
            sh   = ship.shield or 0,
            type = ship.stype,
            boss = ship.isBoss or false,
        }
    end

    frames_[#frames_ + 1] = {
        t  = timer_,
        p  = pSnap,
        e  = eSnap,
    }
end

--- 注册一艘玩家舰（在 makeShip 后调用），返回分配的 replayId
---@param ship table
---@return number replayId
function BattleReplaySystem.RegisterShip(ship)
    if not recording_ then return 0 end
    local id = nextShipId_
    nextShipId_ = nextShipId_ + 1
    ship._replayId = id
    shipTracker_[id] = {
        stype      = ship.stype,
        dmg        = 0,
        kills      = 0,
        surviveTime= 0,
        maxCombo   = 0,
    }
    return id
end

--- 记录关键事件
---@param eventType string  事件类型（使用 BattleReplaySystem.EVENT 常量）
---@param data table        事件附带数据
function BattleReplaySystem.RecordEvent(eventType, data)
    if not recording_ then return end
    if #events_ >= MAX_EVENTS then return end
    events_[#events_ + 1] = {
        t    = timer_,
        type = eventType,
        data = data or {},
    }
end

--- 累计舰船伤害统计
---@param replayId number
---@param dmg number
function BattleReplaySystem.AddShipDamage(replayId, dmg)
    if not recording_ then return end
    local tr = shipTracker_[replayId]
    if tr then tr.dmg = tr.dmg + dmg end
end

--- 累计舰船击杀统计
---@param replayId number
function BattleReplaySystem.AddShipKill(replayId)
    if not recording_ then return end
    local tr = shipTracker_[replayId]
    if tr then tr.kills = tr.kills + 1 end
end

--- 更新舰船最高连击
---@param replayId number
---@param combo number
function BattleReplaySystem.UpdateShipCombo(replayId, combo)
    if not recording_ then return end
    local tr = shipTracker_[replayId]
    if tr and combo > tr.maxCombo then tr.maxCombo = combo end
end

-- ============================================================================
-- 查询 API（战斗结束后使用）
-- ============================================================================

--- 获取回放帧数据
---@return table[] frames
function BattleReplaySystem.GetFrames()
    return frames_
end

--- 获取事件列表
---@return table[] events
function BattleReplaySystem.GetEvents()
    return events_
end

--- 获取精彩时刻列表（按精彩度排序）
---@return table[] highlights  [{startTime, endTime, peakTime, score, type, desc}]
function BattleReplaySystem.GetHighlights()
    return highlights_
end

--- 获取 MVP 结果
---@return table|nil  {shipId, stype, score, dmg, kills, surviveTime, reason}
function BattleReplaySystem.GetMVP()
    return mvpResult_
end

--- 获取录制时长
---@return number seconds
function BattleReplaySystem.GetDuration()
    return timer_
end

--- 获取指定时间点的帧（用于回放定位）
---@param time number
---@return table|nil frame
function BattleReplaySystem.GetFrameAt(time)
    if #frames_ == 0 then return nil end
    -- 二分查找最接近的帧
    local lo, hi = 1, #frames_
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if frames_[mid].t < time then
            lo = mid + 1
        else
            hi = mid
        end
    end
    return frames_[lo]
end

--- 获取指定时间范围内的事件
---@param startT number
---@param endT number
---@return table[] events
function BattleReplaySystem.GetEventsInRange(startT, endT)
    local result = {}
    for _, ev in ipairs(events_) do
        if ev.t >= startT and ev.t <= endT then
            result[#result + 1] = ev
        end
    end
    return result
end

--- 获取舰船统计追踪数据
---@return table shipTracker
function BattleReplaySystem.GetShipTracker()
    return shipTracker_
end

--- 是否正在录制
---@return boolean
function BattleReplaySystem.IsRecording()
    return recording_
end

-- ============================================================================
-- 内部方法
-- ============================================================================

--- 计算精彩时刻（按事件密度和重要性评分）
function BattleReplaySystem._computeHighlights()
    highlights_ = {}

    -- 事件权重
    local WEIGHTS = {
        [BattleReplaySystem.EVENT.BOSS_KILL]    = 10,
        [BattleReplaySystem.EVENT.NEMESIS_KILL] = 12,
        [BattleReplaySystem.EVENT.COMBO]        = 6,
        [BattleReplaySystem.EVENT.OVERKILL]     = 4,
        [BattleReplaySystem.EVENT.CHAIN]        = 5,
        [BattleReplaySystem.EVENT.CRIT_BURST]   = 7,
        [BattleReplaySystem.EVENT.WAVE_CLEAR]   = 3,
        [BattleReplaySystem.EVENT.KILL]         = 1,
        [BattleReplaySystem.EVENT.SHIP_LOST]    = 3,
        [BattleReplaySystem.EVENT.SKILL_USE]    = 2,
    }

    -- 滑动窗口计算事件密度
    if #events_ == 0 then return end

    -- 以每个高权重事件为锚点，评估其前后 HIGHLIGHT_WINDOW 内的总分
    local scored = {}
    for i, ev in ipairs(events_) do
        local w = WEIGHTS[ev.type] or 1
        if w >= 4 then  -- 只以高权重事件为锚点
            local startT = math.max(0, ev.t - HIGHLIGHT_WINDOW)
            local endT   = ev.t + HIGHLIGHT_WINDOW
            local score  = 0
            for _, ev2 in ipairs(events_) do
                if ev2.t >= startT and ev2.t <= endT then
                    score = score + (WEIGHTS[ev2.type] or 1)
                end
            end
            scored[#scored + 1] = {
                startTime = startT,
                endTime   = endT,
                peakTime  = ev.t,
                score     = score,
                type      = ev.type,
                desc      = BattleReplaySystem._describeEvent(ev),
                anchorIdx = i,
            }
        end
    end

    -- 按分数降序排列
    table.sort(scored, function(a, b) return a.score > b.score end)

    -- 去重：如果两个精彩时刻时间重叠过多（>50%），保留高分的
    local selected = {}
    for _, h in ipairs(scored) do
        local overlap = false
        for _, sel in ipairs(selected) do
            local oStart = math.max(h.startTime, sel.startTime)
            local oEnd   = math.min(h.endTime, sel.endTime)
            if oEnd > oStart then
                local overlapRatio = (oEnd - oStart) / (HIGHLIGHT_WINDOW * 2)
                if overlapRatio > 0.5 then
                    overlap = true
                    break
                end
            end
        end
        if not overlap then
            selected[#selected + 1] = h
            if #selected >= 5 then break end  -- 最多 5 个精彩时刻
        end
    end

    highlights_ = selected
end

--- 计算 MVP（综合评分）
function BattleReplaySystem._computeMVP()
    mvpResult_ = nil
    if not shipTracker_ then return end

    local best     = nil
    local bestScore= 0

    for id, tr in pairs(shipTracker_) do
        -- 综合评分：伤害×1 + 击杀×200 + 存活时间×5 + 连击×50
        local score = (tr.dmg or 0) * 1.0
                    + (tr.kills or 0) * 200
                    + (tr.surviveTime or 0) * 5
                    + (tr.maxCombo or 0) * 50

        if score > bestScore then
            bestScore = score
            best = {
                shipId      = id,
                stype       = tr.stype,
                score       = score,
                dmg         = tr.dmg,
                kills       = tr.kills,
                surviveTime = tr.surviveTime,
                maxCombo    = tr.maxCombo,
            }
        end
    end

    if best then
        -- 确定 MVP 原因
        local reason = "综合表现最佳"
        if best.kills > 0 and best.kills >= (best.dmg / 500) then
            reason = "击杀之王"
        elseif best.dmg > 5000 then
            reason = "伤害之王"
        elseif best.surviveTime > timer_ * 0.9 then
            reason = "坚韧不屈"
        end
        best.reason = reason
        mvpResult_ = best
        print(string.format("[P3-1 Replay] MVP: %s (评分%.0f, 伤害%d, 击杀%d, 存活%.1fs)",
            best.stype, best.score, best.dmg, best.kills, best.surviveTime))
    end
end

--- 生成事件描述文本
---@param ev table
---@return string
function BattleReplaySystem._describeEvent(ev)
    local E = BattleReplaySystem.EVENT
    local d = ev.data or {}
    if ev.type == E.BOSS_KILL then
        return "Boss 击败！"
    elseif ev.type == E.NEMESIS_KILL then
        return "宿敌歼灭！"
    elseif ev.type == E.COMBO then
        return string.format("%d连击！", d.count or 0)
    elseif ev.type == E.OVERKILL then
        return string.format("过度击杀 %.0f%%！", (d.ratio or 0) * 100)
    elseif ev.type == E.CHAIN then
        return "连锁反应！"
    elseif ev.type == E.CRIT_BURST then
        return string.format("瞬间爆发 %d 伤害！", d.dmg or 0)
    elseif ev.type == E.WAVE_CLEAR then
        return string.format("第 %d 波通关", d.wave or 0)
    elseif ev.type == E.SHIP_LOST then
        return string.format("%s 阵亡", d.stype or "舰船")
    elseif ev.type == E.SKILL_USE then
        return string.format("释放技能: %s", d.name or "")
    else
        return "击杀敌舰"
    end
end

return BattleReplaySystem
