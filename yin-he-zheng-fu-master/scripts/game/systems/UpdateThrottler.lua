-- ============================================================================
-- game/systems/UpdateThrottler.lua  -- 更新节流系统
-- ============================================================================

local M = {}

local throttlers = {}

function M.CreateThrottler(name, intervalMs, skipMode)
    throttlers[name] = {
        interval = intervalMs / 1000,
        skipMode = skipMode or "drop",
        lastTime = 0,
        pending = nil,
        callCount = 0,
        skipCount = 0,
    }
end

function M.Throttle(name, func, ...)
    local t = throttlers[name]
    if not t then
        error("UpdateThrottler: throttler not found: " .. name)
    end
    
    local now = os.clock()
    local delta = now - t.lastTime
    
    if delta >= t.interval then
        t.lastTime = now
        t.callCount = t.callCount + 1
        func(...)
        if t.pending then
            local pendingArgs = t.pending
            t.pending = nil
            return M.Throttle(name, func, table.unpack(pendingArgs))
        end
        return true
    else
        t.skipCount = t.skipCount + 1
        if t.skipMode == "queue" and not t.pending then
            t.pending = { ... }
        end
        return false
    end
end

function M.Update(name, dt, func, ...)
    local t = throttlers[name]
    if not t then
        error("UpdateThrottler: throttler not found: " .. name)
    end
    
    t.lastTime = t.lastTime - dt
    
    if t.lastTime <= 0 then
        t.lastTime = t.interval
        t.callCount = t.callCount + 1
        func(...)
        return true
    end
    
    t.skipCount = t.skipCount + 1
    return false
end

function M.GetStats(name)
    local t = throttlers[name]
    if not t then return nil end
    
    local total = t.callCount + t.skipCount
    local skipRate = total > 0 and (t.skipCount / total * 100) or 0
    
    return {
        name = name,
        interval = t.interval,
        skipMode = t.skipMode,
        callCount = t.callCount,
        skipCount = t.skipCount,
        skipRate = skipRate,
    }
end

function M.GetAllStats()
    local stats = {}
    for name, t in pairs(throttlers) do
        table.insert(stats, M.GetStats(name))
    end
    return stats
end

function M.Reset(name)
    local t = throttlers[name]
    if t then
        t.lastTime = 0
        t.pending = nil
        t.callCount = 0
        t.skipCount = 0
    end
end

function M.ResetAll()
    for name, t in pairs(throttlers) do
        M.Reset(name)
    end
end

function M.ClearAll()
    throttlers = {}
end

function M.TimeSlice(durationMs, tasks)
    local duration = durationMs / 1000
    local startTime = os.clock()
    local completed = {}
    
    for i, task in ipairs(tasks) do
        if os.clock() - startTime >= duration then
            break
        end
        
        local ok, result = pcall(task.func, table.unpack(task.args or {}))
        table.insert(completed, {
            index = i,
            name = task.name,
            success = ok,
            result = result,
        })
    end
    
    return completed
end

return M