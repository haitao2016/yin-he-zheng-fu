-- ============================================================================
-- game/ui/UICacheManager.lua  -- UI组件缓存管理器
-- ============================================================================

local M = {}

local caches = {}

local DEFAULT_CACHE_SIZE = 50
local DEFAULT_TTL = 300

function M.CreateCache(cacheName, ttl, maxSize)
    caches[cacheName] = {
        items = {},
        ttl = ttl or DEFAULT_TTL,
        maxSize = maxSize or DEFAULT_CACHE_SIZE,
        hits = 0,
        misses = 0,
        evictions = 0,
    }
end

function M.Get(cacheName, key)
    local cache = caches[cacheName]
    if not cache then
        error("UICacheManager: cache not found: " .. cacheName)
    end
    
    local item = cache.items[key]
    if item then
        if os.time() < item.expireTime then
            cache.hits = cache.hits + 1
            item.lastAccess = os.time()
            return item.value
        else
            cache.items[key] = nil
        end
    end
    
    cache.misses = cache.misses + 1
    return nil
end

function M.Set(cacheName, key, value, customTTL)
    local cache = caches[cacheName]
    if not cache then
        error("UICacheManager: cache not found: " .. cacheName)
    end
    
    while #cache.items >= cache.maxSize do
        local oldestKey, oldestTime = nil, math.huge
        for k, v in pairs(cache.items) do
            if v.lastAccess < oldestTime then
                oldestKey = k
                oldestTime = v.lastAccess
            end
        end
        if oldestKey then
            cache.items[oldestKey] = nil
            cache.evictions = cache.evictions + 1
        else
            break
        end
    end
    
    local ttl = customTTL or cache.ttl
    cache.items[key] = {
        value = value,
        expireTime = os.time() + ttl,
        lastAccess = os.time(),
    }
end

function M.Has(cacheName, key)
    local cache = caches[cacheName]
    if not cache then return false end
    
    local item = cache.items[key]
    if item and os.time() < item.expireTime then
        return true
    end
    return false
end

function M.Delete(cacheName, key)
    local cache = caches[cacheName]
    if cache then
        cache.items[key] = nil
    end
end

function M.Clear(cacheName)
    local cache = caches[cacheName]
    if cache then
        cache.items = {}
        cache.hits = 0
        cache.misses = 0
        cache.evictions = 0
    end
end

function M.ClearAll()
    caches = {}
end

function M.GetStats(cacheName)
    local cache = caches[cacheName]
    if not cache then return nil end
    
    local total = cache.hits + cache.misses
    local hitRate = total > 0 and (cache.hits / total) * 100 or 0
    
    return {
        name = cacheName,
        size = #cache.items,
        maxSize = cache.maxSize,
        hits = cache.hits,
        misses = cache.misses,
        evictions = cache.evictions,
        hitRate = hitRate,
    }
end

function M.GetAllStats()
    local stats = {}
    for name, cache in pairs(caches) do
        table.insert(stats, M.GetStats(name))
    end
    table.sort(stats, function(a, b) return a.name < b.name end)
    return stats
end

function M.PrintStats()
    local stats = M.GetAllStats()
    print("[UICacheManager] Statistics:")
    for _, s in ipairs(stats) do
        print(string.format("  %-20s | Size:%3d/%3d | Hits:%4d | Misses:%4d | Evictions:%3d | HitRate:%.1f%%",
            s.name, s.size, s.maxSize, s.hits, s.misses, s.evictions, s.hitRate))
    end
end

function M.InitDefaultCaches()
    M.CreateCache("texture_cache", 600, 100)
    M.CreateCache("font_cache", 300, 50)
    M.CreateCache("panel_layout_cache", 120, 30)
    M.CreateCache("tooltip_cache", 60, 20)
    M.CreateCache("icon_cache", 600, 200)
    M.CreateCache("text_render_cache", 30, 100)
    M.CreateCache("data_formatter_cache", 60, 50)
end

function M.PurgeExpired(cacheName)
    local cache = caches[cacheName]
    if not cache then return end
    
    local now = os.time()
    local expired = {}
    for key, item in pairs(cache.items) do
        if now >= item.expireTime then
            table.insert(expired, key)
        end
    end
    
    for _, key in ipairs(expired) do
        cache.items[key] = nil
    end
    
    return #expired
end

function M.PurgeAllExpired()
    local totalExpired = 0
    for name in pairs(caches) do
        totalExpired = totalExpired + M.PurgeExpired(name)
    end
    return totalExpired
end

return