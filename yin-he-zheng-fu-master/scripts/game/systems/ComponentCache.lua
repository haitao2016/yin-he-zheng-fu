-- ============================================================================
-- game/systems/ComponentCache.lua  -- 组件缓存系统
-- ============================================================================

local M = {}

local caches = {}

function M.CreateCache(cacheName, getFunc, ttlSeconds)
    caches[cacheName] = {
        data = {},
        getFunc = getFunc,
        ttl = ttlSeconds or 60,
        timestamps = {},
        hits = 0,
        misses = 0,
    }
end

function M.Get(cacheName, key)
    local cache = caches[cacheName]
    if not cache then
        error("ComponentCache: cache not found: " .. cacheName)
    end
    
    local now = os.time()
    local entry = cache.data[key]
    
    if entry then
        local age = now - (cache.timestamps[key] or now)
        if age < cache.ttl then
            cache.hits = cache.hits + 1
            return entry
        end
    end
    
    cache.misses = cache.misses + 1
    local result = cache.getFunc(key)
    cache.data[key] = result
    cache.timestamps[key] = now
    return result
end

function M.Set(cacheName, key, value)
    local cache = caches[cacheName]
    if not cache then
        error("ComponentCache: cache not found: " .. cacheName)
    end
    
    cache.data[key] = value
    cache.timestamps[key] = os.time()
end

function M.Invalidate(cacheName, key)
    local cache = caches[cacheName]
    if cache then
        cache.data[key] = nil
        cache.timestamps[key] = nil
    end
end

function M.InvalidateAll(cacheName)
    local cache = caches[cacheName]
    if cache then
        cache.data = {}
        cache.timestamps = {}
    end
end

function M.ClearAll()
    caches = {}
end

function M.GetStats(cacheName)
    local cache = caches[cacheName]
    if not cache then return nil end
    
    local total = cache.hits + cache.misses
    local hitRate = total > 0 and (cache.hits / total * 100) or 0
    
    return {
        name = cacheName,
        entries = #cache.data,
        hits = cache.hits,
        misses = cache.misses,
        hitRate = hitRate,
        ttl = cache.ttl,
    }
end

function M.GetAllStats()
    local stats = {}
    for name, cache in pairs(caches) do
        table.insert(stats, M.GetStats(name))
    end
    return stats
end

function M.Prune(cacheName)
    local cache = caches[cacheName]
    if not cache then return end
    
    local now = os.time()
    local pruned = 0
    
    for key, timestamp in pairs(cache.timestamps) do
        if now - timestamp >= cache.ttl then
            cache.data[key] = nil
            cache.timestamps[key] = nil
            pruned = pruned + 1
        end
    end
    
    return pruned
end

function M.PruneAll()
    local totalPruned = 0
    for name, _ in pairs(caches) do
        totalPruned = totalPruned + M.Prune(name)
    end
    return totalPruned
end

return M