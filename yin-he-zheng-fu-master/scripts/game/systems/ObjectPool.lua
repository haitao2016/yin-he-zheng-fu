-- ============================================================================
-- game/systems/ObjectPool.lua  -- 对象池系统
-- ============================================================================

local M = {}

local pools = {}

function M.CreatePool(poolName, createFunc, resetFunc, maxSize)
    pools[poolName] = {
        objects = {},
        createFunc = createFunc,
        resetFunc = resetFunc,
        maxSize = maxSize or 100,
        created = 0,
        reused = 0,
        borrowed = 0,
    }
end

function M.Get(poolName)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    if #pool.objects > 0 then
        local obj = table.remove(pool.objects)
        pool.borrowed = pool.borrowed + 1
        if pool.resetFunc then
            pool.resetFunc(obj)
        end
        pool.reused = pool.reused + 1
        return obj
    end
    
    pool.created = pool.created + 1
    pool.borrowed = pool.borrowed + 1
    return pool.createFunc()
end

function M.GetBatch(poolName, count)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    local result = {}
    for i = 1, count do
        if #pool.objects > 0 then
            local obj = table.remove(pool.objects)
            pool.borrowed = pool.borrowed + 1
            if pool.resetFunc then
                pool.resetFunc(obj)
            end
            pool.reused = pool.reused + 1
            result[i] = obj
        else
            pool.created = pool.created + 1
            pool.borrowed = pool.borrowed + 1
            result[i] = pool.createFunc()
        end
    end
    return result
end

function M.Return(poolName, obj)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    pool.borrowed = pool.borrowed - 1
    if #pool.objects < pool.maxSize then
        table.insert(pool.objects, obj)
    end
end

function M.ReturnBatch(poolName, objs)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    for _, obj in ipairs(objs) do
        pool.borrowed = pool.borrowed - 1
        if #pool.objects < pool.maxSize then
            table.insert(pool.objects, obj)
        end
    end
end

function M.ReturnAll(poolName, objList)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    local toRemove = {}
    for i = #objList, 1, -1 do
        local obj = objList[i]
        pool.borrowed = pool.borrowed - 1
        if #pool.objects < pool.maxSize then
            table.insert(pool.objects, obj)
        end
        table.remove(objList, i)
    end
end

function M.ReturnFiltered(poolName, objList, filterFunc)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    for i = #objList, 1, -1 do
        local obj = objList[i]
        if filterFunc(obj) then
            pool.borrowed = pool.borrowed - 1
            if #pool.objects < pool.maxSize then
                table.insert(pool.objects, obj)
            end
            table.remove(objList, i)
        end
    end
end

function M.Clear(poolName)
    local pool = pools[poolName]
    if pool then
        pool.objects = {}
        pool.created = 0
        pool.reused = 0
        pool.borrowed = 0
    end
end

function M.ClearAll()
    pools = {}
end

function M.GetStats(poolName)
    local pool = pools[poolName]
    if not pool then return nil end
    
    return {
        name = poolName,
        available = #pool.objects,
        created = pool.created,
        reused = pool.reused,
        borrowed = pool.borrowed,
        maxSize = pool.maxSize,
        hitRate = pool.created > 0 and (pool.reused / pool.created) * 100 or 0,
    }
end

function M.GetAllStats()
    local stats = {}
    for name, pool in pairs(pools) do
        table.insert(stats, M.GetStats(name))
    end
    table.sort(stats, function(a, b) return a.name < b.name end)
    return stats
end

function M.Prewarm(poolName, count)
    local pool = pools[poolName]
    if not pool then
        error("ObjectPool: pool not found: " .. poolName)
    end
    
    for i = 1, count do
        if #pool.objects < pool.maxSize then
            local obj = pool.createFunc()
            table.insert(pool.objects, obj)
            pool.created = pool.created + 1
        end
    end
end

function M.PrewarmAll(baseCount)
    baseCount = baseCount or 10
    for name, pool in pairs(pools) do
        M.Prewarm(name, baseCount)
    end
end

function M.SetMaxSize(poolName, maxSize)
    local pool = pools[poolName]
    if pool then
        pool.maxSize = maxSize
        while #pool.objects > maxSize do
            table.remove(pool.objects)
        end
    end
end

function M.HasPool(poolName)
    return pools[poolName] ~= nil
end

function M.GetPoolCount()
    local count = 0
    for _ in pairs(pools) do
        count = count + 1
    end
    return count
end

return M