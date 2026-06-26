---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/PerformanceOptimizer.lua
-- V3.0 P3-3: 性能优化系统
-- 懒加载/纹理图集/触控优化
-- ============================================================================

local PerformanceOptimizer = {}

-- ============================================================================
-- 模块加载状态
-- ============================================================================

local ModuleLoadState = {
    -- 模块名 -> { loaded = bool, loadTime = timestamp, size = bytes }
    modules = {},
}

-- 定义可懒加载的模块
LAZY_LOAD_MODULES = {
    -- { name = "模块路径", trigger = "触发条件", priority = 优先级 }
    { name = "game.BlueprintSystem", trigger = "blueprint", priority = 50,
      desc = "战术蓝图系统" },
    { name = "game.MutantShipSystem", trigger = "mutant", priority = 40,
      desc = "变异舰船系统" },
    { name = "game.LegacySystem", trigger = "legacy", priority = 60,
      desc = "文明遗产系统" },
    { name = "game.FormationEditor", trigger = "formation", priority = 45,
      desc = "阵型编辑器" },
    { name = "game.ReplayPlayer", trigger = "replay", priority = 30,
      desc = "回放播放器" },
    { name = "game.SeasonSystem", trigger = "season", priority = 55,
      desc = "赛季系统" },
    { name = "game.FriendSystem", trigger = "friend", priority = 35,
      desc = "好友系统" },
    { name = "game.GuildSystem", trigger = "guild", priority = 55,
      desc = "公会系统" },
}

-- 预加载模块（游戏启动时加载）
ESSENTIAL_MODULES = {
    "game.constants.GameConstants",
    "game.constants.TechConstants",
    "game.constants.ShipConstants",
    "game.constants.BattleConstants",
    "game.constants.MapConstants",
    "game.constants.AchievementConstants",
    "game.BattleSkills",
    "game.GalaxyEvents",
    "game.StarWeather",
}

-- ============================================================================
-- 懒加载系统
-- ============================================================================

--- 预加载核心模块
function PerformanceOptimizer.preloadEssentialModules()
    local startTime = os.clock()
    
    for _, moduleName in ipairs(ESSENTIAL_MODULES) do
        local ok, result = pcall(require, moduleName)
        if ok then
            ModuleLoadState.modules[moduleName] = {
                loaded = true,
                loadTime = os.clock() - startTime,
                size = 0,  -- 估算
            }
        else
            print("[PerformanceOptimizer] 预加载失败: " .. moduleName)
        end
    end
    
    local totalTime = os.clock() - startTime
    print(string.format("[PerformanceOptimizer] 核心模块预加载完成，耗时: %.2fms", totalTime * 1000))
    
    return totalTime
end

--- 懒加载模块
function PerformanceOptimizer.lazyLoad(moduleName, triggerHint)
    -- 检查是否已加载
    if ModuleLoadState.modules[moduleName] and ModuleLoadState.modules[moduleName].loaded then
        return true
    end
    
    -- 执行懒加载
    local startTime = os.clock()
    local ok, result = pcall(require, moduleName)
    local loadTime = os.clock() - startTime
    
    if ok then
        ModuleLoadState.modules[moduleName] = {
            loaded = true,
            loadTime = loadTime,
            triggerHint = triggerHint,
            loadTimestamp = os.time(),
        }
        
        print(string.format("[PerformanceOptimizer] 懒加载模块 %s 完成，耗时: %.2fms", 
            moduleName, loadTime * 1000))
        
        return true, result
    else
        print("[PerformanceOptimizer] 懒加载失败: " .. moduleName .. " - " .. tostring(result))
        return false
    end
end

--- 预加载模块（基于触发条件）
function PerformanceOptimizer.preloadByTrigger(trigger)
    local preloaded = {}
    
    -- 按优先级排序
    local sorted = {}
    for _, mod in ipairs(LAZY_LOAD_MODULES) do
        if mod.trigger == trigger then
            table.insert(sorted, mod)
        end
    end
    table.sort(sorted, function(a, b) return a.priority > b.priority end)
    
    -- 加载匹配模块
    for _, mod in ipairs(sorted) do
        local ok, _ = PerformanceOptimizer.lazyLoad(mod.name, trigger)
        if ok then
            table.insert(preloaded, mod.name)
        end
    end
    
    return preloaded
end

--- 检查模块是否已加载
function PerformanceOptimizer.isLoaded(moduleName)
    return ModuleLoadState.modules[moduleName] ~= nil 
        and ModuleLoadState.modules[moduleName].loaded
end

--- 获取模块加载统计
function PerformanceOptimizer.getLoadStats()
    local stats = {
        totalModules = 0,
        loadedModules = 0,
        totalLoadTime = 0,
        slowestModule = nil,
        slowestTime = 0,
    }
    
    for name, state in pairs(ModuleLoadState.modules) do
        stats.totalModules = stats.totalModules + 1
        if state.loaded then
            stats.loadedModules = stats.loadedModules + 1
            stats.totalLoadTime = stats.totalLoadTime + (state.loadTime or 0)
            if (state.loadTime or 0) > stats.slowestTime then
                stats.slowestTime = state.loadTime or 0
                stats.slowestModule = name
            end
        end
    end
    
    return stats
end

-- ============================================================================
-- 纹理图集管理
-- ============================================================================

local TextureAtlas = {
    atlases = {},        -- { atlasName -> { textures = {}, refCount = 0 } }
    lastBindTime = {},   -- { atlasName -> timestamp }
}

--- 注册纹理图集
function PerformanceOptimizer.registerAtlas(atlasName, textures)
    if not TextureAtlas.atlases[atlasName] then
        TextureAtlas.atlases[atlasName] = {
            textures = textures or {},
            refCount = 0,
        }
    end
end

--- 绑定图集（增加引用计数）
function PerformanceOptimizer.bindAtlas(atlasName)
    if TextureAtlas.atlases[atlasName] then
        TextureAtlas.atlases[atlasName].refCount = 
            TextureAtlas.atlases[atlasName].refCount + 1
        TextureAtlas.lastBindTime[atlasName] = os.clock()
        return true
    end
    return false
end

--- 解绑图集（减少引用计数，计数为0时卸载）
function PerformanceOptimizer.unbindAtlas(atlasName)
    if TextureAtlas.atlases[atlasName] then
        TextureAtlas.atlases[atlasName].refCount = 
            math.max(0, TextureAtlas.atlases[atlasName].refCount - 1)
        return true
    end
    return false
end

--- 获取活跃图集（按最近使用排序）
function PerformanceOptimizer.getActiveAtlases(limit)
    local sorted = {}
    for name, _ in pairs(TextureAtlas.atlases) do
        table.insert(sorted, {
            name = name,
            lastBind = TextureAtlas.lastBindTime[name] or 0,
        })
    end
    
    table.sort(sorted, function(a, b) return a.lastBind > b.lastBind end)
    
    local result = {}
    for i, entry in ipairs(sorted) do
        if limit and i > limit then break end
        table.insert(result, entry.name)
    end
    
    return result
end

--- 卸载未使用的图集
function PerformanceOptimizer.unloadUnusedAtlases()
    local unloaded = {}
    
    for name, atlas in pairs(TextureAtlas.atlases) do
        if atlas.refCount == 0 then
            -- 可以在这里添加实际的纹理卸载逻辑
            table.insert(unloaded, name)
        end
    end
    
    return unloaded
end

--- 获取纹理图集统计
function PerformanceOptimizer.getAtlasStats()
    local stats = {
        totalAtlases = 0,
        activeAtlases = 0,
        totalTextures = 0,
        highRefCount = {},
    }
    
    for name, atlas in pairs(TextureAtlas.atlases) do
        stats.totalAtlases = stats.totalAtlases + 1
        stats.totalTextures = stats.totalTextures + #atlas.textures
        
        if atlas.refCount > 0 then
            stats.activeAtlases = stats.activeAtlases + 1
        end
        
        if atlas.refCount > 5 then
            table.insert(stats.highRefCount, { name = name, ref = atlas.refCount })
        end
    end
    
    return stats
end

-- ============================================================================
-- 触控优化
-- ============================================================================

local TouchOptimization = {
    touchSettings = {
        pinchZoomSensitivity = 1.0,
        panSpeed = 1.0,
        doubleTapInterval = 300,     -- 双击间隔(ms)
        longPressDuration = 500,     -- 长按持续时间(ms)
        swipeThreshold = 50,         -- 滑动阈值(px)
    },
    gestureState = {
        isPinching = false,
        isPanning = false,
        lastTapTime = 0,
        lastTapPos = nil,
    },
}

--- 获取触控设置
function PerformanceOptimizer.getTouchSettings()
    return TouchOptimization.touchSettings
end

--- 更新触控设置
function PerformanceOptimizer.updateTouchSettings(settings)
    for key, value in pairs(settings) do
        if TouchOptimization.touchSettings[key] ~= nil then
            TouchOptimization.touchSettings[key] = value
        end
    end
end

--- 检测双击
function PerformanceOptimizer.detectDoubleTap(touchPos)
    local now = os.time()
    local interval = TouchOptimization.touchSettings.doubleTapInterval
    
    if TouchOptimization.gestureState.lastTapPos 
        and TouchOptimization.gestureState.lastTapTime > 0 then
        
        local timeDiff = (now * 1000) - TouchOptimization.gestureState.lastTapTime
        local posDiff = math.sqrt(
            (touchPos.x - TouchOptimization.gestureState.lastTapPos.x)^2 +
            (touchPos.y - TouchOptimization.gestureState.lastTapPos.y)^2
        )
        
        if timeDiff <= interval and posDiff <= 20 then
            -- 双击确认
            TouchOptimization.gestureState.lastTapTime = 0
            TouchOptimization.gestureState.lastTapPos = nil
            return true
        end
    end
    
    -- 记录单击
    TouchOptimization.gestureState.lastTapTime = now * 1000
    TouchOptimization.gestureState.lastTapPos = touchPos
    
    return false
end

--- 检测滑动手势
function PerformanceOptimizer.detectSwipe(startPos, endPos)
    local threshold = TouchOptimization.touchSettings.swipeThreshold
    local dx = endPos.x - startPos.x
    local dy = endPos.y - startPos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < threshold then
        return nil  -- 不是滑动
    end
    
    -- 确定滑动方向
    local angle = math.atan2(dy, dx) * 180 / math.pi
    
    if angle > -45 and angle <= 45 then
        return "RIGHT"
    elseif angle > 45 and angle <= 135 then
        return "DOWN"
    elseif angle > -135 and angle <= -45 then
        return "UP"
    else
        return "LEFT"
    end
end

--- 计算捏合缩放
function PerformanceOptimizer.calculatePinchZoom(initialDistance, currentDistance)
    if initialDistance <= 0 then return 1.0 end
    
    local scale = currentDistance / initialDistance
    local sensitivity = TouchOptimization.touchSettings.pinchZoomSensitivity
    
    return 1.0 + (scale - 1.0) * sensitivity
end

-- ============================================================================
-- 帧率优化
-- ============================================================================

local FrameRateOptimizer = {
    targetFPS = 60,
    adaptiveQuality = true,
    frameTimeHistory = {},
    maxHistorySize = 60,
    qualityLevels = {
        { fps = 60, particleMultiplier = 1.0, shadowQuality = "HIGH" },
        { fps = 30, particleMultiplier = 0.5, shadowQuality = "MEDIUM" },
        { fps = 15, particleMultiplier = 0.25, shadowQuality = "LOW" },
    },
}

--- 设置目标帧率
function PerformanceOptimizer.setTargetFPS(fps)
    FrameRateOptimizer.targetFPS = fps
end

--- 获取当前帧率质量等级
function PerformanceOptimizer.getQualityLevel()
    if not FrameRateOptimizer.adaptiveQuality then
        return FrameRateOptimizer.qualityLevels[1]  -- 最高质量
    end
    
    -- 计算平均帧时间
    local history = FrameRateOptimizer.frameTimeHistory
    if #history == 0 then
        return FrameRateOptimizer.qualityLevels[1]
    end
    
    local total = 0
    for _, frameTime in ipairs(history) do
        total = total + frameTime
    end
    local avgFrameTime = total / #history
    local avgFPS = 1.0 / avgFrameTime
    
    -- 根据帧率选择质量等级
    for i, level in ipairs(FrameRateOptimizer.qualityLevels) do
        if avgFPS >= level.fps then
            return level
        end
    end
    
    return FrameRateOptimizer.qualityLevels[#FrameRateOptimizer.qualityLevels]
end

--- 记录帧时间
function PerformanceOptimizer.recordFrameTime(frameTime)
    table.insert(FrameRateOptimizer.frameTimeHistory, frameTime)
    
    -- 限制历史大小
    while #FrameRateOptimizer.frameTimeHistory > FrameRateOptimizer.maxHistorySize do
        table.remove(FrameRateOptimizer.frameTimeHistory, 1)
    end
end

--- 获取帧率统计
function PerformanceOptimizer.getFrameRateStats()
    local history = FrameRateOptimizer.frameTimeHistory
    
    if #history == 0 then
        return { current = 0, average = 0, min = 0, max = 0, quality = nil }
    end
    
    local total = 0
    local min = math.huge
    local max = 0
    
    for _, frameTime in ipairs(history) do
        total = total + frameTime
        min = math.min(min, frameTime)
        max = math.max(max, frameTime)
    end
    
    local avg = total / #history
    
    return {
        current = frameTime ~= nil and (1.0 / frameTime) or 0,
        average = 1.0 / avg,
        min = 1.0 / max,  -- 反转以获取 FPS
        max = 1.0 / min,
        quality = PerformanceOptimizer.getQualityLevel(),
        historySize = #history,
    }
end

--- 启用/禁用自适应质量
function PerformanceOptimizer.setAdaptiveQuality(enabled)
    FrameRateOptimizer.adaptiveQuality = enabled
end

-- ============================================================================
-- 内存优化
-- ============================================================================

local MemoryOptimizer = {
    garbageCollectionThreshold = 50 * 1024 * 1024,  -- 50MB 触发 GC
    lastGCTime = 0,
    gcInterval = 300,  -- 5分钟 GC 间隔
}

--- 触发垃圾回收
function PerformanceOptimizer.forceGarbageCollection()
    collectgarbage("collect")
    MemoryOptimizer.lastGCTime = os.time()
    
    local mem = collectgarbage("count")
    print(string.format("[PerformanceOptimizer] GC 完成，当前内存: %.2f MB", mem))
    
    return mem
end

--- 检查是否需要 GC
function PerformanceOptimizer.checkGarbageCollection()
    local now = os.time()
    
    -- 检查时间间隔
    if now - MemoryOptimizer.lastGCTime < MemoryOptimizer.gcInterval then
        return false
    end
    
    -- 检查内存使用
    local mem = collectgarbage("count")
    if mem * 1024 < MemoryOptimizer.garbageCollectionThreshold then
        return false
    end
    
    -- 执行 GC
    PerformanceOptimizer.forceGarbageCollection()
    return true
end

--- 获取内存统计
function PerformanceOptimizer.getMemoryStats()
    local mem = collectgarbage("count")
    
    return {
        currentMB = mem,
        thresholdMB = MemoryOptimizer.garbageCollectionThreshold / (1024 * 1024),
        lastGCTime = MemoryOptimizer.lastGCTime,
        needsGC = mem * 1024 >= MemoryOptimizer.garbageCollectionThreshold,
    }
end

-- ============================================================================
-- 性能报告
-- ============================================================================

--- 生成性能报告
function PerformanceOptimizer.generateReport()
    local loadStats = PerformanceOptimizer.getLoadStats()
    local atlasStats = PerformanceOptimizer.getAtlasStats()
    local frameStats = PerformanceOptimizer.getFrameRateStats()
    local memoryStats = PerformanceOptimizer.getMemoryStats()
    
    local report = {
        timestamp = os.time(),
        moduleLoading = loadStats,
        textureAtlases = atlasStats,
        frameRate = frameStats,
        memory = memoryStats,
        touchSettings = TouchOptimization.touchSettings,
    }
    
    return report
end

--- 打印性能报告
function PerformanceOptimizer.printReport()
    local report = PerformanceOptimizer.generateReport()
    
    print("=== 性能报告 ===")
    print(string.format("模块加载: %d/%d 已加载, 总耗时: %.2fms",
        report.moduleLoading.loadedModules, 
        report.moduleLoading.totalModules,
        report.moduleLoading.totalLoadTime * 1000))
    
    if report.moduleLoading.slowestModule then
        print(string.format("最慢模块: %s (%.2fms)",
            report.moduleLoading.slowestModule,
            report.moduleLoading.slowestTime * 1000))
    end
    
    print(string.format("纹理图集: %d 个, 活跃: %d, 纹理总数: %d",
        report.textureAtlases.totalAtlases,
        report.textureAtlases.activeAtlases,
        report.textureAtlases.totalTextures))
    
    print(string.format("帧率: 当前 %.1f FPS, 平均 %.1f FPS, 范围 %.1f-%.1f",
        report.frameRate.current,
        report.frameRate.average,
        report.frameRate.min,
        report.frameRate.max))
    
    print(string.format("内存: %.2f MB / %.2f MB (阈值)",
        report.memory.currentMB,
        report.memory.thresholdMB))
    
    print("===============")
end

-- ============================================================================
-- 导出
-- ============================================================================

return PerformanceOptimizer
