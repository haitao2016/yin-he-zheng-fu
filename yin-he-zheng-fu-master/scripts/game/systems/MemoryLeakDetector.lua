-- ============================================================================
-- game/systems/MemoryLeakDetector.lua  -- 内存泄漏检测系统
-- 提供对象引用追踪、泄漏检测和报告功能
-- ============================================================================

local MemoryLeakDetector = {}

-- ============================================================================
-- 配置参数
-- ============================================================================

local CONFIG = {
    enabled = true,
    trackInterval = 5,        -- 检测间隔(秒)
    warningThreshold = 1000,   -- 警告阈值(对象数)
    criticalThreshold = 5000, -- 严重阈值(对象数)
    maxHistorySize = 60,      -- 最大历史记录数
    reportInterval = 60,      -- 报告间隔(秒)
}

-- ============================================================================
-- 追踪数据
-- ============================================================================

local trackedObjects = {}     -- { objId -> { type, created, lastUsed, refs } }
local objectTypes = {}       -- { type -> { count, totalCreated, totalDestroyed } }
local history = {}           -- 历史记录
local lastReportTime = 0
local objectIdCounter = 0

-- ============================================================================
-- 核心功能
-- ============================================================================

function MemoryLeakDetector.init()
    trackedObjects = {}
    objectTypes = {}
    history = {}
    lastReportTime = 0
    objectIdCounter = 0
    print("[MemoryLeakDetector] 初始化完成")
end

function MemoryLeakDetector.enable(enabled)
    CONFIG.enabled = enabled
    print("[MemoryLeakDetector] " .. (enabled and "已启用" or "已禁用"))
end

function MemoryLeakDetector.isEnabled()
    return CONFIG.enabled
end

-- 生成唯一ID
local function generateId()
    objectIdCounter = objectIdCounter + 1
    return "obj_" .. objectIdCounter .. "_" .. os.time()
end

-- 注册对象
function MemoryLeakDetector.track(obj, objType, context)
    if not CONFIG.enabled then return nil end
    
    local objId = generateId()
    trackedObjects[objId] = {
        id = objId,
        type = objType,
        created = os.time(),
        lastUsed = os.time(),
        context = context or "unknown",
        refs = 1,
        _obj = obj,
    }
    
    if not objectTypes[objType] then
        objectTypes[objType] = {
            count = 0,
            totalCreated = 0,
            totalDestroyed = 0,
        }
    end
    
    objectTypes[objType].count = objectTypes[objType].count + 1
    objectTypes[objType].totalCreated = objectTypes[objType].totalCreated + 1
    
    return objId
end

-- 增加引用计数
function MemoryLeakDetector.retain(objId)
    if not CONFIG.enabled then return end
    
    local objData = trackedObjects[objId]
    if objData then
        objData.refs = objData.refs + 1
        objData.lastUsed = os.time()
    end
end

-- 减少引用计数
function MemoryLeakDetector.release(objId)
    if not CONFIG.enabled then return end
    
    local objData = trackedObjects[objId]
    if objData then
        objData.refs = objData.refs - 1
        objData.lastUsed = os.time()
        
        if objData.refs <= 0 then
            MemoryLeakDetector.destroy(objId)
        end
    end
end

-- 销毁对象
function MemoryLeakDetector.destroy(objId)
    if not CONFIG.enabled then return end
    
    local objData = trackedObjects[objId]
    if objData then
        local objType = objData.type
        
        -- 更新类型统计
        if objectTypes[objType] then
            objectTypes[objType].count = math.max(0, objectTypes[objType].count - 1)
            objectTypes[objType].totalDestroyed = objectTypes[objType].totalDestroyed + 1
        end
        
        -- 移除追踪
        trackedObjects[objId] = nil
    end
end

-- 更新对象使用时间
function MemoryLeakDetector.touch(objId)
    if not CONFIG.enabled then return end
    
    local objData = trackedObjects[objId]
    if objData then
        objData.lastUsed = os.time()
    end
end

-- 批量清理长时间未使用的对象
function MemoryLeakDetector.cleanupUnused(maxAgeSeconds)
    if not CONFIG.enabled then return 0 end
    
    maxAgeSeconds = maxAgeSeconds or 300
    local now = os.time()
    local cleaned = 0
    
    for objId, objData in pairs(trackedObjects) do
        if now - objData.lastUsed > maxAgeSeconds then
            MemoryLeakDetector.destroy(objId)
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        print(string.format("[MemoryLeakDetector] 清理了 %d 个长时间未使用的对象", cleaned))
    end
    
    return cleaned
end

-- ============================================================================
-- 检测功能
-- ============================================================================

function MemoryLeakDetector.detectLeaks()
    if not CONFIG.enabled then return {} end
    
    local leaks = {}
    local now = os.time()
    
    for objId, objData in pairs(trackedObjects) do
        -- 检测长时间未使用的对象
        local age = now - objData.lastUsed
        if age > 120 then  -- 超过2分钟未使用
            table.insert(leaks, {
                id = objId,
                type = objData.type,
                age = age,
                context = objData.context,
                refs = objData.refs,
                reason = "长时间未使用",
            })
        end
        
        -- 检测异常高引用计数
        if objData.refs > 10 then
            table.insert(leaks, {
                id = objId,
                type = objData.type,
                age = age,
                context = objData.context,
                refs = objData.refs,
                reason = "引用计数过高",
            })
        end
    end
    
    table.sort(leaks, function(a, b) return a.age > b.age end)
    
    return leaks
end

function MemoryLeakDetector.checkThresholds()
    if not CONFIG.enabled then return nil end
    
    local totalObjects = MemoryLeakDetector.getTotalObjectCount()
    
    if totalObjects >= CONFIG.criticalThreshold then
        return {
            level = "critical",
            message = string.format("对象数量达到临界值: %d", totalObjects),
            count = totalObjects,
        }
    elseif totalObjects >= CONFIG.warningThreshold then
        return {
            level = "warning",
            message = string.format("对象数量达到警告阈值: %d", totalObjects),
            count = totalObjects,
        }
    end
    
    return nil
end

-- ============================================================================
-- 统计功能
-- ============================================================================

function MemoryLeakDetector.getTotalObjectCount()
    local count = 0
    for _ in pairs(trackedObjects) do
        count = count + 1
    end
    return count
end

function MemoryLeakDetector.getObjectTypeStats()
    local stats = {}
    for objType, data in pairs(objectTypes) do
        table.insert(stats, {
            type = objType,
            count = data.count,
            totalCreated = data.totalCreated,
            totalDestroyed = data.totalDestroyed,
            leakRate = data.totalCreated > 0 and 
                ((data.totalCreated - data.totalDestroyed) / data.totalCreated) * 100 or 0,
        })
    end
    table.sort(stats, function(a, b) return a.count > b.count end)
    return stats
end

function MemoryLeakDetector.getLeakStats()
    local leaks = MemoryLeakDetector.detectLeaks()
    local typeStats = MemoryLeakDetector.getObjectTypeStats()
    
    return {
        totalObjects = MemoryLeakDetector.getTotalObjectCount(),
        objectTypes = #objectTypes,
        detectedLeaks = #leaks,
        typeBreakdown = typeStats,
    }
end

-- ============================================================================
-- 报告功能
-- ============================================================================

function MemoryLeakDetector.generateReport()
    local stats = MemoryLeakDetector.getLeakStats()
    local leaks = MemoryLeakDetector.detectLeaks()
    local threshold = MemoryLeakDetector.checkThresholds()
    
    return {
        timestamp = os.time(),
        enabled = CONFIG.enabled,
        stats = stats,
        leaks = leaks,
        thresholdAlert = threshold,
        config = {
            warningThreshold = CONFIG.warningThreshold,
            criticalThreshold = CONFIG.criticalThreshold,
            trackInterval = CONFIG.trackInterval,
        },
    }
end

function MemoryLeakDetector.printReport()
    local report = MemoryLeakDetector.generateReport()
    
    print("=== 内存泄漏检测报告 ===")
    print(string.format("检测时间: %s", os.date("%Y-%m-%d %H:%M:%S", report.timestamp)))
    print(string.format("检测状态: %s", report.enabled and "已启用" or "已禁用"))
    print(string.format("追踪对象总数: %d", report.stats.totalObjects))
    print(string.format("对象类型数: %d", report.stats.objectTypes))
    print(string.format("检测到潜在泄漏: %d", report.stats.detectedLeaks))
    
    if report.thresholdAlert then
        print(string.format("[%s] %s", 
            report.thresholdAlert.level == "critical" and "CRITICAL" or "WARNING",
            report.thresholdAlert.message))
    end
    
    print("\n对象类型分布:")
    for i, typeStat in ipairs(report.stats.typeBreakdown) do
        if i <= 10 then
            print(string.format("  %s: %d 个 (创建: %d, 销毁: %d, 泄漏率: %.1f%%)",
                typeStat.type, typeStat.count, typeStat.totalCreated, 
                typeStat.totalDestroyed, typeStat.leakRate))
        end
    end
    
    if #report.leaks > 0 then
        print("\n潜在泄漏对象:")
        for i, leak in ipairs(report.leaks) do
            if i <= 5 then
                print(string.format("  [%s] %s - %ds未使用, 引用:%d, 上下文:%s",
                    leak.id, leak.type, leak.age, leak.refs, leak.context))
            end
        end
    end
    
    print("=======================")
end

function MemoryLeakDetector.autoReport()
    local now = os.time()
    if now - lastReportTime >= CONFIG.reportInterval then
        MemoryLeakDetector.printReport()
        lastReportTime = now
    end
end

-- ============================================================================
-- 定期检查
-- ============================================================================

function MemoryLeakDetector.update(deltaTime)
    if not CONFIG.enabled then return end
    
    MemoryLeakDetector.autoReport()
end

-- ============================================================================
-- 调试工具
-- ============================================================================

function MemoryLeakDetector.dumpAllObjects()
    if not CONFIG.enabled then return {} end
    
    local result = {}
    for objId, objData in pairs(trackedObjects) do
        table.insert(result, {
            id = objId,
            type = objData.type,
            age = os.time() - objData.created,
            idleTime = os.time() - objData.lastUsed,
            refs = objData.refs,
            context = objData.context,
        })
    end
    table.sort(result, function(a, b) return a.idleTime > b.idleTime end)
    return result
end

function MemoryLeakDetector.findObjectsByType(objType)
    local result = {}
    for objId, objData in pairs(trackedObjects) do
        if objData.type == objType then
            table.insert(result, objData)
        end
    end
    return result
end

-- ============================================================================
-- 导出
-- ============================================================================

return MemoryLeakDetector