local DebugConsoleSystem = {}

local SYSTEM_VERSION = "3.2.0"
local SYSTEM_NAME = "DebugConsoleSystem"

local LOG_LEVEL = {
    NONE = 0,
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
}

DebugConsoleSystem.FILTER_NONE = LOG_LEVEL.NONE
DebugConsoleSystem.FILTER_ERROR = LOG_LEVEL.ERROR
DebugConsoleSystem.FILTER_WARN = LOG_LEVEL.WARN
DebugConsoleSystem.FILTER_INFO = LOG_LEVEL.INFO
DebugConsoleSystem.FILTER_DEBUG = LOG_LEVEL.DEBUG

local currentFilterLevel = LOG_LEVEL.DEBUG
local debugMode = false
local consoleOpen = false
local MAX_LOG_HISTORY = 2000
local MAX_CONSOLE_LINES = 500

local logHistory = {}
local consoleLines = {}
local eventListeners = {}
local commandRegistry = {}
local stateSnapshots = {}
local callCounters = {}
local startTime = os.clock()

local consoleState = {
    inputBuffer = "",
    history = {},
    historyIndex = 0,
    scrollOffset = 0,
    autoScroll = true,
    showTimestamp = true,
    showLevelTag = true,
    showModuleTag = true,
    colorByLevel = true,
}

local perfStats = {
    frameCount = 0,
    frameTimeAccum = 0,
    frameTimeMin = math.huge,
    frameTimeMax = 0,
    lastFrameTime = os.clock(),
    memorySamples = {},
    memorySampleMax = 120,
    loadTimes = {},
}

local function formatTimestamp()
    local t = os.time()
    local date = os.date("*t", t)
    return string.format("%04d-%02d-%02d %02d:%02d:%02d",
        date.year, date.month, date.day, date.hour, date.min, date.sec)
end

local function formatClock()
    local secs = os.clock() - startTime
    return string.format("%08.3f", secs)
end

local function getLevelTag(level)
    if level == LOG_LEVEL.ERROR then return "ERROR" end
    if level == LOG_LEVEL.WARN then return "WARN" end
    if level == LOG_LEVEL.INFO then return "INFO" end
    if level == LOG_LEVEL.DEBUG then return "DEBUG" end
    return "UNKNOWN"
end

local function getLevelColor(level)
    if level == LOG_LEVEL.ERROR then return "#ff5c5c" end
    if level == LOG_LEVEL.WARN then return "#ffb84d" end
    if level == LOG_LEVEL.INFO then return "#6ecff6" end
    if level == LOG_LEVEL.DEBUG then return "#a0a0a0" end
    return "#ffffff"
end

local function traceback(skip)
    skip = skip or 3
    local tb = {}
    local level = skip
    while true do
        local info = debug.getinfo(level, "Sln")
        if not info then break end
        if info.what ~= "C" then
            local src = info.short_src or "?"
            local line = info.currentline or 0
            local name = info.name or "<anonymous>"
            table.insert(tb, string.format("  at %s:%d (%s)", src, line, name))
        else
            table.insert(tb, string.format("  at [C]: %s", info.name or "?"))
        end
        level = level + 1
        if level > skip + 20 then break end
    end
    return table.concat(tb, "\n")
end

local function deepCopy(value, seen)
    seen = seen or {}
    if value == nil then return nil end
    if type(value) ~= "table" then return value end
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[deepCopy(k, seen)] = deepCopy(v, seen)
    end
    return copy
end

local function serializeValue(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 8 then return "<deep>" end
    if value == nil then return "nil" end
    local t = type(value)
    if t == "string" then return string.format("%q", value) end
    if t == "number" or t == "boolean" then return tostring(value) end
    if t == "table" then
        if seen[value] then return "<circular>" end
        seen[value] = true
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 30 then
                table.insert(parts, "...")
                break
            end
            local ks = type(k) == "number" and tostring(k) or tostring(k)
            table.insert(parts, ks .. "=" .. serializeValue(v, depth + 1, seen))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if t == "function" then return "<function>" end
    if t == "thread" then return "<thread>" end
    if t == "userdata" then return "<userdata>" end
    return tostring(value)
end

local function writeLog(entry)
    table.insert(logHistory, entry)
    while #logHistory > MAX_LOG_HISTORY do
        table.remove(logHistory, 1)
    end
end

local function writeConsole(entry)
    table.insert(consoleLines, entry)
    while #consoleLines > MAX_CONSOLE_LINES do
        table.remove(consoleLines, 1)
    end
end

local function composeLogLine(level, moduleName, message)
    local parts = {}
    if consoleState.showTimestamp then
        table.insert(parts, "[" .. formatTimestamp() .. "]")
    end
    if consoleState.showLevelTag then
        table.insert(parts, "[" .. getLevelTag(level) .. "]")
    end
    if consoleState.showModuleTag and moduleName then
        table.insert(parts, "[" .. tostring(moduleName) .. "]")
    end
    table.insert(parts, tostring(message))
    return table.concat(parts, " ")
end

local function buildEntry(level, moduleName, message, extra)
    return {
        level = level,
        module = moduleName or SYSTEM_NAME,
        message = tostring(message),
        timestamp = os.time(),
        clock = os.clock() - startTime,
        timestampStr = formatTimestamp(),
        clockStr = formatClock(),
        extra = extra,
        line = composeLogLine(level, moduleName, message),
    }
end

local function shouldLog(level)
    return level <= currentFilterLevel and level > LOG_LEVEL.NONE
end

local function rawPrint(level, moduleName, message, extra)
    callCounters["log:" .. getLevelTag(level)] = (callCounters["log:" .. getLevelTag(level)] or 0) + 1
    local entry = buildEntry(level, moduleName, message, extra)
    if shouldLog(level) then
        writeLog(entry)
        writeConsole(entry)
        if level == LOG_LEVEL.ERROR or level == LOG_LEVEL.WARN then
            if extra and extra.traceback then
                print(entry.line)
                print(extra.traceback)
            else
                print(entry.line)
            end
        else
            print(entry.line)
        end
    end
    return entry
end

---@param moduleName string
---@param message any
---@return table
function DebugConsoleSystem.logInfo(moduleName, message)
    return rawPrint(LOG_LEVEL.INFO, moduleName, message, nil)
end

---@param moduleName string
---@param message any
---@return table
function DebugConsoleSystem.logWarn(moduleName, message)
    return rawPrint(LOG_LEVEL.WARN, moduleName, message, { traceback = traceback(3) })
end

---@param moduleName string
---@param message any
---@return table
function DebugConsoleSystem.logError(moduleName, message)
    return rawPrint(LOG_LEVEL.ERROR, moduleName, message, { traceback = traceback(3) })
end

---@param moduleName string
---@param message any
---@return table
function DebugConsoleSystem.logDebug(moduleName, message)
    return rawPrint(LOG_LEVEL.DEBUG, moduleName, message, nil)
end

---@param level number
---@return nil
function DebugConsoleSystem.setFilterLevel(level)
    if level and type(level) == "number" and level >= LOG_LEVEL.NONE and level <= LOG_LEVEL.DEBUG then
        currentFilterLevel = level
    end
end

---@return number
function DebugConsoleSystem.getFilterLevel()
    return currentFilterLevel
end

---@param limit number
---@param minLevel number
---@return table
function DebugConsoleSystem.getLogHistory(limit, minLevel)
    local result = {}
    local min = minLevel or LOG_LEVEL.NONE
    for i = 1, #logHistory do
        local entry = logHistory[i]
        if entry.level >= min then
            table.insert(result, entry)
        end
    end
    if limit and limit > 0 and #result > limit then
        local startIdx = #result - limit + 1
        local trimmed = {}
        for i = startIdx, #result do
            table.insert(trimmed, result[i])
        end
        return trimmed
    end
    return result
end

---@return nil
function DebugConsoleSystem.clearLogHistory()
    logHistory = {}
end

---@return boolean
function DebugConsoleSystem.flushToDisk()
    if #logHistory == 0 then return false end
    local ok, result = pcall(function()
        local lines = {}
        table.insert(lines, "===== DebugConsoleSystem Log Dump =====")
        table.insert(lines, "System: " .. SYSTEM_NAME .. " v" .. SYSTEM_VERSION)
        table.insert(lines, "Generated: " .. formatTimestamp())
        table.insert(lines, "Total entries: " .. tostring(#logHistory))
        table.insert(lines, "========================================")
        for _, entry in ipairs(logHistory) do
            table.insert(lines, entry.line)
            if entry.extra and entry.extra.traceback then
                table.insert(lines, entry.extra.traceback)
            end
        end
        local content = table.concat(lines, "\n")
        local fileName = "debug_console_" .. os.date("%Y%m%d_%H%M%S") .. ".log"
        if io and io.open then
            local f, err = io.open(fileName, "w")
            if f then
                f:write(content)
                f:close()
                return true, fileName
            else
                return false, err or "io.open failed"
            end
        end
        return true, fileName
    end)
    if not ok then
        DebugConsoleSystem.logWarn(SYSTEM_NAME, "flushToDisk failed: " .. tostring(result))
        return false
    end
    return true
end

---@return nil
function DebugConsoleSystem.toggle()
    consoleOpen = not consoleOpen
    DebugConsoleSystem.logDebug(SYSTEM_NAME, "Console toggled: " .. tostring(consoleOpen))
end

---@return boolean
function DebugConsoleSystem.isOpen()
    return consoleOpen
end

---@param message any
---@return nil
function DebugConsoleSystem.print(message)
    local entry = buildEntry(LOG_LEVEL.INFO, "CONSOLE", tostring(message), nil)
    writeConsole(entry)
end

---@param moduleName string
---@param message any
---@return nil
function DebugConsoleSystem.log(moduleName, message)
    DebugConsoleSystem.logInfo(moduleName, message)
end

---@return nil
function DebugConsoleSystem.clear()
    consoleLines = {}
end

---@return table
function DebugConsoleSystem.getConsoleLines(limit)
    if not limit or limit <= 0 or limit >= #consoleLines then
        local out = {}
        for i = 1, #consoleLines do
            out[i] = consoleLines[i]
        end
        return out
    end
    local out = {}
    local startIdx = #consoleLines - limit + 1
    if startIdx < 1 then startIdx = 1 end
    for i = startIdx, #consoleLines do
        table.insert(out, consoleLines[i])
    end
    return out
end

---@return table
function DebugConsoleSystem.getConsoleState()
    return {
        open = consoleOpen,
        inputBuffer = consoleState.inputBuffer,
        history = consoleState.history,
        scrollOffset = consoleState.scrollOffset,
        autoScroll = consoleState.autoScroll,
        showTimestamp = consoleState.showTimestamp,
        showLevelTag = consoleState.showLevelTag,
        showModuleTag = consoleState.showModuleTag,
        colorByLevel = consoleState.colorByLevel,
        totalLines = #consoleLines,
    }
end

---@param key string
---@param value any
---@return nil
function DebugConsoleSystem.setConsoleOption(key, value)
    if consoleState[key] ~= nil then
        consoleState[key] = value
    end
end

---@param label string
---@return table
function DebugConsoleSystem.snapshotState(label)
    local snap = {
        label = label or ("snapshot_" .. tostring(#stateSnapshots + 1)),
        timestamp = os.time(),
        clock = os.clock() - startTime,
        memory = collectgarbage and collectgarbage("count") or 0,
        logCount = #logHistory,
        consoleCount = #consoleLines,
        filterLevel = currentFilterLevel,
        debugMode = debugMode,
        perf = deepCopy(perfStats),
    }
    table.insert(stateSnapshots, snap)
    DebugConsoleSystem.logDebug(SYSTEM_NAME, "State snapshot saved: " .. snap.label)
    return snap
end

---@param index number
---@return table
function DebugConsoleSystem.restoreState(index)
    if #stateSnapshots == 0 then return nil end
    local idx = index or #stateSnapshots
    if idx < 1 then idx = 1 end
    if idx > #stateSnapshots then idx = #stateSnapshots end
    local snap = stateSnapshots[idx]
    if not snap then return nil end
    if snap.filterLevel then
        currentFilterLevel = snap.filterLevel
    end
    if snap.debugMode ~= nil then
        debugMode = snap.debugMode
    end
    DebugConsoleSystem.logInfo(SYSTEM_NAME, "State restored from snapshot: " .. snap.label)
    return snap
end

---@return table
function DebugConsoleSystem.getSnapshots()
    local out = {}
    for i, s in ipairs(stateSnapshots) do
        table.insert(out, {
            index = i,
            label = s.label,
            timestamp = s.timestamp,
            clock = s.clock,
            memory = s.memory,
        })
    end
    return out
end

---@param frameTime number
---@return nil
function DebugConsoleSystem.recordFrame(frameTime)
    perfStats.frameCount = perfStats.frameCount + 1
    local ft = frameTime or 0
    if ft <= 0 then
        local now = os.clock()
        ft = now - perfStats.lastFrameTime
        perfStats.lastFrameTime = now
    end
    perfStats.frameTimeAccum = perfStats.frameTimeAccum + ft
    if ft < perfStats.frameTimeMin then perfStats.frameTimeMin = ft end
    if ft > perfStats.frameTimeMax then perfStats.frameTimeMax = ft end
    if perfStats.frameCount % 10 == 0 then
        local mem = collectgarbage and collectgarbage("count") or 0
        table.insert(perfStats.memorySamples, { t = os.clock() - startTime, mem = mem })
        while #perfStats.memorySamples > perfStats.memorySampleMax do
            table.remove(perfStats.memorySamples, 1)
        end
    end
end

---@param key string
---@param seconds number
---@return nil
function DebugConsoleSystem.recordLoadTime(key, seconds)
    perfStats.loadTimes[key] = {
        time = seconds,
        timestamp = os.time(),
    }
    callCounters["load:" .. key] = (callCounters["load:" .. key] or 0) + 1
end

---@param key string
---@return nil
function DebugConsoleSystem.incrementCounter(key)
    callCounters[key] = (callCounters[key] or 0) + 1
end

---@return table
function DebugConsoleSystem.getPerfStats()
    local avgFrame = 0
    if perfStats.frameCount > 0 then
        avgFrame = perfStats.frameTimeAccum / perfStats.frameCount
    end
    local fps = 0
    if avgFrame > 0 then fps = 1.0 / avgFrame end
    local memCurrent = 0
    local memPeak = 0
    if collectgarbage then
        memCurrent = collectgarbage("count")
    end
    for _, sample in ipairs(perfStats.memorySamples) do
        if sample.mem > memPeak then memPeak = sample.mem end
    end
    if memCurrent > memPeak then memPeak = memCurrent end
    local totalLoad = 0
    local slowestKey = nil
    local slowestTime = 0
    for k, v in pairs(perfStats.loadTimes) do
        totalLoad = totalLoad + 1
        if v.time > slowestTime then
            slowestTime = v.time
            slowestKey = k
        end
    end
    local countersSnapshot = {}
    for k, v in pairs(callCounters) do
        countersSnapshot[k] = v
    end
    return {
        fps = fps,
        avgFrameTime = avgFrame,
        frameCount = perfStats.frameCount,
        frameTimeMin = perfStats.frameTimeMin == math.huge and 0 or perfStats.frameTimeMin,
        frameTimeMax = perfStats.frameTimeMax,
        memoryKB = memCurrent,
        memoryPeakKB = memPeak,
        memorySamples = #perfStats.memorySamples,
        totalLoadEntries = totalLoad,
        slowestLoadKey = slowestKey,
        slowestLoadTime = slowestTime,
        uptimeSeconds = os.clock() - startTime,
        counters = countersSnapshot,
        loadTimes = deepCopy(perfStats.loadTimes),
    }
end

---@return nil
function DebugConsoleSystem.resetPerfStats()
    perfStats.frameCount = 0
    perfStats.frameTimeAccum = 0
    perfStats.frameTimeMin = math.huge
    perfStats.frameTimeMax = 0
    perfStats.lastFrameTime = os.clock()
    perfStats.memorySamples = {}
    perfStats.loadTimes = {}
end

---@param command string
---@param args table
---@return string, boolean
local function cmdHelp(command, args)
    local lines = { "Available commands:" }
    local names = {}
    for name in pairs(commandRegistry) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local cmd = commandRegistry[name]
        table.insert(lines, "  /" .. name .. " - " .. (cmd.description or ""))
    end
    return table.concat(lines, "\n"), true
end

---@param command string
---@param args table
---@return string, boolean
local function cmdList(command, args)
    local lines = { "System state:" }
    table.insert(lines, "  system: " .. SYSTEM_NAME)
    table.insert(lines, "  version: " .. SYSTEM_VERSION)
    table.insert(lines, "  debugMode: " .. tostring(debugMode))
    table.insert(lines, "  filterLevel: " .. getLevelTag(currentFilterLevel))
    table.insert(lines, "  logEntries: " .. tostring(#logHistory))
    table.insert(lines, "  consoleLines: " .. tostring(#consoleLines))
    table.insert(lines, "  snapshots: " .. tostring(#stateSnapshots))
    table.insert(lines, "  uptime: " .. string.format("%.2fs", os.clock() - startTime))
    return table.concat(lines, "\n"), true
end

---@param command string
---@param args table
---@return string, boolean
local function cmdGive(command, args)
    local item = args[1] or "gold"
    local amount = tonumber(args[2]) or 100
    DebugConsoleSystem.fire("debug:give", { item = item, amount = amount })
    return string.format("Give event fired: %s x %d", item, amount), true
end

---@param command string
---@param args table
---@return string, boolean
local function cmdKill(command, args)
    DebugConsoleSystem.fire("debug:kill", { target = args[1] or "enemy" })
    return "Kill event fired", true
end

---@param command string
---@param args table
---@return string, boolean
local function cmdReset(command, args)
    DebugConsoleSystem.fire("debug:reset", { scope = args[1] or "all" })
    DebugConsoleSystem.clearLogHistory()
    DebugConsoleSystem.clear()
    DebugConsoleSystem.resetPerfStats()
    return "Reset performed (logs, console, perf)", true
end

---@param command string
---@param args table
---@return string, boolean
local function cmdSkip(command, args)
    local count = tonumber(args[1]) or 1
    DebugConsoleSystem.fire("debug:skip", { count = count })
    return "Skip event fired: " .. tostring(count), true
end

---@param command string
---@param args table
---@return string, boolean
local function cmdSpeed(command, args)
    local factor = tonumber(args[1])
    if not factor then
        return "Usage: /speed <factor>", false
    end
    if factor <= 0 then factor = 0.1 end
    if factor > 10 then factor = 10 end
    DebugConsoleSystem.fire("debug:speed", { factor = factor })
    return "Speed set to " .. string.format("%.1fx", factor), true
end

---@param name string
---@param handler function
---@param description string
---@return nil
function DebugConsoleSystem.registerCommand(name, handler, description)
    if not name or type(handler) ~= "function" then return end
    commandRegistry[name] = {
        handler = handler,
        description = description or "",
    }
    callCounters["cmd:" .. name] = callCounters["cmd:" .. name] or 0
end

---@param input string
---@return string, boolean
function DebugConsoleSystem.executeCommand(input)
    if not input then return "", false end
    local trimmed = string.gsub(input, "^%s+", "")
    trimmed = string.gsub(trimmed, "%s+$", "")
    if trimmed == "" then return "", false end
    local isCommand = string.sub(trimmed, 1, 1) == "/"
    local commandName
    local argsStr
    if isCommand then
        local rest = string.sub(trimmed, 2)
        local spaceIdx = string.find(rest, "%s")
        if spaceIdx then
            commandName = string.sub(rest, 1, spaceIdx - 1)
            argsStr = string.sub(rest, spaceIdx + 1)
        else
            commandName = rest
            argsStr = ""
        end
    else
        DebugConsoleSystem.print(trimmed)
        return trimmed, true
    end
    local args = {}
    if argsStr and argsStr ~= "" then
        for part in string.gmatch(argsStr, "%S+") do
            table.insert(args, part)
        end
    end
    if not commandName or commandName == "" then
        return "Empty command", false
    end
    callCounters["cmd:" .. commandName] = (callCounters["cmd:" .. commandName] or 0) + 1
    local cmd = commandRegistry[commandName]
    local result
    local success
    if cmd then
        local ok, r1, r2 = pcall(cmd.handler, commandName, args)
        if ok then
            result = r1
            success = not not r2
            if success == nil then success = true end
        else
            result = "Command error: " .. tostring(r1)
            success = false
        end
    else
        result = "Unknown command: /" .. commandName .. " (try /help)"
        success = false
    end
    if result and result ~= "" then
        local entry = buildEntry(success and LOG_LEVEL.INFO or LOG_LEVEL.WARN,
            "CMD:" .. commandName, tostring(result), nil)
        writeConsole(entry)
        writeLog(entry)
    end
    return result, success
end

---@param event string
---@param listener function
---@return nil
function DebugConsoleSystem.on(event, listener)
    if not event or type(listener) ~= "function" then return end
    if not eventListeners[event] then
        eventListeners[event] = {}
    end
    table.insert(eventListeners[event], listener)
end

---@param event string
---@param listener function
---@return boolean
function DebugConsoleSystem.off(event, listener)
    if not event or not eventListeners[event] then return false end
    for i = #eventListeners[event], 1, -1 do
        if eventListeners[event][i] == listener then
            table.remove(eventListeners[event], i)
            return true
        end
    end
    return false
end

---@param event string
---@param data any
---@return number
function DebugConsoleSystem.fire(event, data)
    if not event then return 0 end
    callCounters["event:" .. event] = (callCounters["event:" .. event] or 0) + 1
    if not eventListeners[event] then return 0 end
    local count = 0
    local listenersCopy = {}
    for i, fn in ipairs(eventListeners[event]) do
        listenersCopy[i] = fn
    end
    for _, fn in ipairs(listenersCopy) do
        local ok, err = pcall(fn, data)
        if ok then
            count = count + 1
        else
            DebugConsoleSystem.logWarn(SYSTEM_NAME, "Listener error for " .. event .. ": " .. tostring(err))
        end
    end
    return count
end

---@param enabled boolean
---@return nil
function DebugConsoleSystem.setDebugMode(enabled)
    debugMode = not not enabled
    DebugConsoleSystem.logInfo(SYSTEM_NAME, "Debug mode: " .. tostring(debugMode))
end

---@return boolean
function DebugConsoleSystem.isDebugMode()
    return debugMode
end

---@return string
function DebugConsoleSystem.getSystem()
    return SYSTEM_NAME
end

---@return string
function DebugConsoleSystem.getVersion()
    return SYSTEM_VERSION
end

---@return table
function DebugConsoleSystem.getInfo()
    return {
        name = SYSTEM_NAME,
        version = SYSTEM_VERSION,
        uptime = os.clock() - startTime,
        debugMode = debugMode,
        filterLevel = currentFilterLevel,
        logCount = #logHistory,
        consoleCount = #consoleLines,
        snapshotCount = #stateSnapshots,
        open = consoleOpen,
    }
end

---@param value any
---@return string
function DebugConsoleSystem.dump(value)
    return serializeValue(value, 0, {})
end

DebugConsoleSystem.registerCommand("help", cmdHelp, "Show available commands")
DebugConsoleSystem.registerCommand("list", cmdList, "List system state")
DebugConsoleSystem.registerCommand("give", cmdGive, "Give resource /give <item> <amount>")
DebugConsoleSystem.registerCommand("kill", cmdKill, "Fire kill event /kill [target]")
DebugConsoleSystem.registerCommand("reset", cmdReset, "Reset console state /reset [scope]")
DebugConsoleSystem.registerCommand("skip", cmdSkip, "Skip forward /skip [count]")
DebugConsoleSystem.registerCommand("speed", cmdSpeed, "Set speed factor /speed <factor>")

DebugConsoleSystem.logInfo(SYSTEM_NAME, "Initialized. Version " .. SYSTEM_VERSION)

return DebugConsoleSystem
