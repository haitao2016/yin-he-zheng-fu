---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
BattleReplayPlayer.lua - 战斗回放播放器（V3.2 P0-1）

功能：
1. 帧级战斗数据记录（敌双方的每一个关键动作
2. 多速度播放（0.5x/1x/2x/4x）
3. 暂停/播放控制
4. 关键帧标记（击杀/技能/阵型切换/撤退）
5. 回放列表管理（最近 10 场）
6. 导出功能（结构化 JSON）
7. 回放元数据（持续时间/MVP/胜负/难度）
]]

local BattleReplayPlayer = {}

-- ============================================================================
-- 状态
-- ============================================================================

local MAX_REPLAY_HISTORY = 10  -- 最近 10 场战斗回放

local replayList = {}  -- 当前回放列表（10 场）
local currentReplay = nil  -- 当前正在构建的回放
local playbackState = nil  -- 播放状态

-- ============================================================================
-- 帧类型定义
-- ============================================================================

BattleReplayPlayer.FRAME_TYPES = {
    FRAME_START = "FRAME_START",
    FRAME_KILL = "KILL",
    FRAME_SKILL_USE = "SKILL_USE",
    FRAME_COMMAND = "COMMAND",
    FRAME_FORMATION = "FORMATION",
    FRAME_RETREAT = "RETREAT",
    FRAME_SHIP_HIT = "SHIP_HIT",
    FRAME_SHIP_MOVE = "SHIP_MOVE",
    FRAME_BOSS_SPAWN = "BOSS_SPAWN",
    FRAME_WAVE_COMPLETE = "WAVE_COMPLETE",
    FRAME_BATTLE_END = "BATTLE_END",
}

-- 播放速度选项
BattleReplayPlayer.SPEED_OPTIONS = {
    0.5,  -- 慢放
    1.0,  -- 正常
    2.0,  -- 2倍速
    4.0,  -- 4倍速
}

-- ============================================================================
-- 录制控制
-- ============================================================================

-- 开始录制新战斗
function BattleReplayPlayer.startRecording(opts)
    opts = opts or {}
    currentReplay = {
        id = os.time() .. "_" .. tostring(math.floor(os.clock() * 1000000)),
        startTime = os.time(),
        gameVersion = "3.2.0",
        difficulty = opts.difficulty or "normal",
        waveCount = 0,
        enemyFleet = {
            enemyCount = opts.enemyCount or 0,
            totalEnemyPower = 0,
        },
        playerFleet = {
            fleetSize = opts.fleetSize or 0,
            totalPlayerPower = 0,
        },
        frames = {},  -- 帧列表
        keyframes = {},  -- 关键帧索引（指向 frames 中的 key
        totalFrames = 0,
        battleDuration = 0,
        result = nil,
        metadata = {
            mvpShip = nil,
            totalDamageDealt = 0,
            totalDamageTaken = 0,
            perfectWaves = 0,
            skillUseCount = 0,
            enemyKilled = 0,
            shipsLost = 0,
        },
    }
    return currentReplay
end

-- 停止录制
function BattleReplayPlayer.stopRecording(result, opts)
    if not currentReplay then return end

    opts = opts or {}
    currentReplay.battleEnd = true
    currentReplay.endTime = os.time()
    currentReplay.battleDuration = os.difftime(currentReplay.endTime, currentReplay.startTime)
    
    -- 计算 MVP（简化版：伤害最高的舰种
    if opts.mvpShip then currentReplay.metadata.mvpShip = opts.mvpShip end
    currentReplay.metadata.totalDamageDealt = opts.damageDealt or 0
    currentReplay.metadata.totalDamageTaken = opts.damageTaken or 0
    currentReplay.metadata.enemyKilled = opts.enemyKilled or 0
    currentReplay.metadata.shipsLost = opts.shipsLost or 0
    currentReplay.metadata.perfectWaves = opts.perfectWaves or 0
    currentReplay.metadata.skillUseCount = opts.skillUseCount or 0
    currentReplay.metadata.victory = opts.victory or false
    currentReplay.totalFrames = #currentReplay.frames
    currentReplay.result = opts.victory and "胜利" or "失败"
    currentReplay.summary = opts.summary or ("战斗结束 - " .. currentReplay.result)
    
    -- 将此回放添加到列表（限制为 10 场，删除最旧的）
    table.insert(replayList, 1, currentReplay)
    while #replayList > MAX_REPLAY_HISTORY do
        table.remove(replayList)
    end
    
    local saved = currentReplay
    currentReplay = nil
    return saved
end

-- 录制一帧
function BattleReplayPlayer.recordFrame(frameType, data)
    if not currentReplay then return end
    
    local frameIdx = #currentReplay.frames + 1
    local frame = {
        frameType = frameType,
        timestamp = os.clock(),
        data = data or {},
        frameIdx = frameIdx,
    }
    
    table.insert(currentReplay.frames, frame)
    
    -- 关键帧自动索引
    if frameType ~= "FRAME_START" and frameType ~= "SHIP_HIT" and frameType ~= "SHIP_MOVE" then
        table.insert(currentReplay.keyframes, {
            frameType = frameType,
            frameIdx = frameIdx,
            description = data and (data.description or frameType) or frameType,
            timestamp = frame.timestamp,
        })
    end
    return frame
end

-- 便捷方法：记录击杀
function BattleReplayPlayer.recordKill(killedShip, killer, damage)
    return BattleReplayPlayer.recordFrame("KILL", {
        killed = killedShip,
        killer = killer,
        damage = damage or 0,
        description = killer and (tostring(killer) .. " → 击杀 " .. tostring(killedShip)) or "击杀"
    })
end

-- 便捷方法：记录技能使用
function BattleReplayPlayer.recordSkillUse(skillName, ship, effect)
    return BattleReplayPlayer.recordFrame("SKILL_USE", {
        skillName = skillName,
        ship = ship,
        effect = effect,
        description = skillName .. " - " .. tostring(ship)
    })
end

-- 便捷方法：记录战斗指令
function BattleReplayPlayer.recordCommand(commandType, target)
    return BattleReplayPlayer.recordFrame("COMMAND", {
        command = commandType,
        target = target,
        description = "指令: " .. tostring(commandType),
    })
end

-- 便捷方法：记录波次完成
function BattleReplayPlayer.recordWaveComplete(waveNum, isPerfect)
    return BattleReplayPlayer.recordFrame("WAVE_COMPLETE", {
        waveNum = waveNum,
        isPerfect = not not isPerfect,
        description = "波次 " .. waveNum .. " 完成" .. (isPerfect and " (完美)" or ""),
    })
end

-- 便捷方法：记录 Boss 生成
function BattleReplayPlayer.recordBossSpawn(bossData)
    return BattleReplayPlayer.recordFrame("BOSS_SPAWN", {
        bossData = bossData,
        description = "BOSS 生成",
    })
end

-- ============================================================================
-- 回放播放控制
-- ============================================================================

-- 加载指定索引开始播放指定回放
function BattleReplayPlayer.playReplay(replayId)
    local replay
    if type(replayId) == "number" then
        replay = replayList[replayId]
    else
        replay = replayId
    end
    
    if not replay then return nil, "未找到回放" end
    
    playbackState = {
        replay = replay,
        currentFrame = 1,
        speed = 1.0,
        isPaused = false,
        lastFrameTime = os.clock(),
        elapsedTime = 0,
        seeking = false,
    }
    return playbackState
end

-- 停止播放
function BattleReplayPlayer.stopPlayback()
    playbackState = nil
end

-- 暂停/恢复
function BattleReplayPlayer.togglePause()
    if not playbackState then return end
    playbackState.isPaused = not playbackState.isPaused
    return playbackState.isPaused
end

function BattleReplayPlayer.pause()
    if not playbackState then return end
    playbackState.isPaused = true
    return true
end

function BattleReplayPlayer.resume()
    if not playbackState then return end
    playbackState.isPaused = false
    return true
end

-- 设置播放速度
function BattleReplayPlayer.setSpeed(speed)
    if not playbackState then return end
    playbackState.speed = speed or 1.0
end

function BattleReplayPlayer.nextSpeed()
    if not playbackState then return end
    local speeds = BattleReplayPlayer.SPEED_OPTIONS
    local curIdx = 1
    for i, s in ipairs(speeds) do
        if math.abs(playbackState.speed - s) < 0.01 then curIdx = i break end
    end
    curIdx = curIdx % #speeds + 1
    playbackState.speed = speeds[curIdx]
    return playbackState.speed
end

-- 跳转至指定帧
function BattleReplayPlayer.seekToFrame(frameIdx)
    if not playbackState or not playbackState.replay then return end
    frameIdx = math.max(1, math.min(frameIdx, #playbackState.replay.frames))
    playbackState.currentFrame = frameIdx
    playbackState.seeking = true
end

-- 跳转至下一个关键帧
function BattleReplayPlayer.seekToNextKeyframe()
    if not playbackState or not playbackState.replay then return end
    local cur = playbackState.currentFrame
    for _, kf in ipairs(playbackState.replay.keyframes) do
        if kf.frameIdx > cur then
            playbackState.currentFrame = kf.frameIdx
            return kf
        end
    end
    return nil
end

-- 跳转至上一个关键帧
function BattleReplayPlayer.seekToPrevKeyframe()
    if not playbackState or not playbackState.replay then return end
    local cur = playbackState.currentFrame
    for i = #playbackState.replay.keyframes, 1, -1 do
        local kf = playbackState.replay.keyframes[i]
        if kf.frameIdx < cur then
            playbackState.currentFrame = kf.frameIdx
            return kf
        end
    end
    return nil
end

-- 每帧更新：推进播放进度
function BattleReplayPlayer.updatePlayback(dt)
    if not playbackState or not playbackState.replay or playbackState.isPaused then return nil end
    
    local frames = playbackState.replay.frames
    local dtAdjusted = dt * playbackState.speed
    
    -- 推进帧计数器（简化版：以固定速率推进）
    playbackState.elapsedTime = playbackState.elapsedTime + dtAdjusted
    
    -- 计算当前应该到达哪一帧
    local targetFrame = math.floor(playbackState.elapsedTime * 30 + 1)  -- 30fps
    local targetFrame = math.min(targetFrame, #frames)
    
    -- 批量处理当前帧到目标帧之间的所有帧
    local eventsThisUpdate = {}
    for i = playbackState.currentFrame, targetFrame do
        local frame = frames[i]
        if frame then
            table.insert(eventsThisUpdate, frame)
        end
    end
    
    playbackState.currentFrame = math.min(targetFrame, #frames)
    
    -- 判断是否结束
    local isEnded = playbackState.currentFrame >= #frames
    
    return {
        events = eventsThisUpdate,
        currentFrame = playbackState.currentFrame,
        totalFrames = #frames,
        isEnded = isEnded,
        speed = playbackState.speed,
        isPaused = playbackState.isPaused,
        isSeeking = playbackState.seeking,
        elapsed = playbackState.elapsedTime,
    }
end

-- 取得播放状态（用于 UI 显示）
function BattleReplayPlayer.getPlaybackInfo()
    if not playbackState or not playbackState.replay then return nil end
    local r = playbackState.replay
    return {
        id = r.id,
        currentFrame = playbackState.currentFrame,
        totalFrames = #r.frames,
        speed = playbackState.speed,
        isPaused = playbackState.isPaused,
        elapsed = playbackState.elapsedTime,
        keyframeCount = #r.keyframes,
        totalDuration = r.battleDuration,
        result = r.result,
        difficulty = r.difficulty,
        metadata = r.metadata,
        elapsedPercent = #r.frames > 0 and playbackState.currentFrame / #r.frames or 0,
    }
end

-- ============================================================================
-- 回放列表与导出
-- ============================================================================

-- 获取所有回放列表
function BattleReplayPlayer.getReplayList()
    local result = {}
    for i, replay in ipairs(replayList) do
        table.insert(result, {
            index = i,
            id = replay.id,
            startTime = replay.startTime,
            duration = replay.battleDuration,
            result = replay.result,
            difficulty = replay.difficulty,
            enemyCount = replay.enemyFleet.enemyCount,
            enemyPower = replay.enemyFleet.totalEnemyPower,
            fleetSize = replay.playerFleet.fleetSize,
            totalDamage = replay.metadata.totalDamageDealt,
            enemyKilled = replay.metadata.enemyKilled,
            perfectWaves = replay.metadata.perfectWaves,
            mvpShip = replay.metadata.mvpShip,
            waveCount = replay.waveCount,
            totalFrames = #replay.frames,
        })
    end
    return result
end

-- 获取指定索引的回放摘要
function BattleReplayPlayer.getReplaySummary(idx)
    local replay = replayList[idx]
    if not replay then return nil end
    return {
        id = replay.id,
        startTime = replay.startTime,
        duration = replay.battleDuration,
        result = replay.result,
        enemyFleet = replay.enemyFleet,
        playerFleet = replay.playerFleet,
        waveCount = replay.waveCount,
        totalFrames = #replay.frames,
        keyframeCount = #replay.keyframes,
        metadata = replay.metadata,
        summary = replay.summary,
        gameVersion = replay.gameVersion,
    }
end

-- 导出回放为 JSON
function BattleReplayPlayer.exportReplay(idx)
    local replay = replayList[idx]
    if not replay then return nil end
    
    local function serialize(obj)
        if type(obj) ~= "table" then return tostring(obj) end
        local parts = {}
        for k, v in pairs(obj) do
            table.insert(parts, '"' .. tostring(k) .. '":' .. serialize(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    
    return serialize(replay)
end

-- 导出所有回放摘要
function BattleReplayPlayer.exportAllSummaries()
    local result = {}
    for i, replay in ipairs(replayList) do
        table.insert(result, {
            index = i,
            startTime = replay.startTime,
            duration = replay.battleDuration,
            result = replay.result,
            difficulty = replay.difficulty,
            mvpShip = replay.metadata.mvpShip,
            totalDamage = replay.metadata.totalDamageDealt,
        })
    end
    return result
end

-- 清理回放列表
function BattleReplayPlayer.clearReplays()
    replayList = {}
end

-- 删除单个回放
function BattleReplayPlayer.deleteReplay(idx)
    if idx >= 1 and idx <= #replayList then
        table.remove(replayList, idx)
        return true
    end
    return false
end

-- ============================================================================
-- 便捷：获取录制统计
-- ============================================================================

function BattleReplayPlayer.getRecordingStats()
    if not currentReplay then return nil end
    return {
        id = currentReplay.id,
        frameCount = #currentReplay.frames,
        keyframeCount = #currentReplay.keyframes,
        elapsed = os.difftime(os.time(), currentReplay.startTime),
        waveCount = currentReplay.waveCount,
        enemyKilled = currentReplay.metadata.enemyKilled,
    }
end

-- 是否正在录制中
function BattleReplayPlayer.isRecording()
    return currentReplay ~= nil
end

-- 是否正在播放中
function BattleReplayPlayer.isPlaying()
    return playbackState ~= nil
end

return BattleReplayPlayer
