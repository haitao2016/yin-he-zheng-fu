---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/SpectatorSystem.lua -- 观战系统
-- V2.8 P2-2
-- ============================================================================

local SpectatorSystem = {}

-- ============================================================================
-- 观战状态
-- ============================================================================

local SpectatorState = {
    isSpectating = false,
    spectatingPlayerId = nil,
    spectatingBattleId = nil,
    replayBuffer = {},
    cameraMode = "AUTO",  -- AUTO, FREE, FOLLOW
}

-- ============================================================================
-- 观战功能
-- ============================================================================

-- 申请观战
function SpectatorSystem.requestSpectate(playerId, battleId)
    -- 模拟申请观战
    if NotifyPanel then
        NotifyPanel.push({
            type = "INFO",
            title = "观战请求",
            message = "已向 " .. playerId .. " 发送观战请求",
        })
    end
    return true, "观战请求已发送"
end

-- 开始观战
function SpectatorSystem.startSpectating(playerId, battleId)
    SpectatorState.isSpectating = true
    SpectatorState.spectatingPlayerId = playerId
    SpectatorState.spectatingBattleId = battleId
    SpectatorState.replayBuffer = {}

    return true, "开始观战"
end

-- 停止观战
function SpectatorSystem.stopSpectating()
    SpectatorState.isSpectating = false
    SpectatorState.spectatingPlayerId = nil
    SpectatorState.spectatingBattleId = nil

    return true, "已停止观战"
end

-- 是否正在观战
function SpectatorSystem.isSpectating()
    return SpectatorState.isSpectating
end

-- 获取观战中的战斗ID
function SpectatorSystem.getSpectatingBattleId()
    return SpectatorState.spectatingBattleId
end

-- ============================================================================
-- 回放录制
-- ============================================================================

-- 录制战斗帧
function SpectatorSystem.recordFrame(frameData)
    table.insert(SpectatorState.replayBuffer, {
        timestamp = os.time(),
        frame = frameData,
    })

    -- 限制缓冲区大小
    if #SpectatorState.replayBuffer > 10000 then
        table.remove(SpectatorState.replayBuffer, 1)
    end
end

-- 获取回放数据
function SpectatorSystem.getReplayBuffer()
    return SpectatorState.replayBuffer
end

-- 保存回放到文件
function SpectatorSystem.saveReplay(battleId, filename)
    local replay = {
        id = battleId,
        timestamp = os.time(),
        frames = SpectatorState.replayBuffer,
    }
    -- 实际保存逻辑
    return true, replay
end

-- 加载回放
function SpectatorSystem.loadReplay(replayId)
    -- 模拟加载
    return {
        id = replayId,
        frames = {},
    }
end

-- ============================================================================
-- 观战UI控制
-- ============================================================================

-- 设置摄像机模式
function SpectatorSystem.setCameraMode(mode)
    if mode == "AUTO" or mode == "FREE" or mode == "FOLLOW" then
        SpectatorState.cameraMode = mode
        return true
    end
    return false, "无效的摄像机模式"
end

-- 获取摄像机模式
function SpectatorSystem.getCameraMode()
    return SpectatorState.cameraMode
end

-- 获取可用的观战列表
function SpectatorSystem.getSpectatableMatches()
    -- 模拟返回可用的观战列表
    return {
        {
            battleId = "BATTLE_001",
            playerName = "星际指挥官",
            wave = 25,
            timestamp = os.time(),
        },
        {
            battleId = "BATTLE_002",
            playerName = "银河征服者",
            wave = 40,
            timestamp = os.time(),
        },
    }
end

-- ============================================================================
-- 导出
-- ============================================================================

return SpectatorSystem
