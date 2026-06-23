-- ============================================================================
-- test/TestObjectPool.lua  -- ObjectPool 单元测试
-- ============================================================================

local TestFramework = require("test.TestFramework")
local ObjectPool = require("game.systems.ObjectPool")

TestFramework.StartSuite("ObjectPool Tests")

TestFramework.Test("CreatePool should create a pool", function()
    ObjectPool.CreatePool("test_pool", function() return { value = 0 } end, function(obj) obj.value = 0 end, 10)
    local stats = ObjectPool.GetStats("test_pool")
    TestFramework.AssertNotNil(stats)
    TestFramework.AssertEqual("test_pool", stats.name)
    TestFramework.AssertEqual(10, stats.maxSize)
    ObjectPool.Clear("test_pool")
end)

TestFramework.Test("Get should create object when pool is empty", function()
    ObjectPool.CreatePool("test_pool2", function() return { id = math.random() } end, nil, 5)
    local obj = ObjectPool.Get("test_pool2")
    TestFramework.AssertNotNil(obj)
    TestFramework.AssertNotNil(obj.id)
    local stats = ObjectPool.GetStats("test_pool2")
    TestFramework.AssertEqual(1, stats.created)
    ObjectPool.Clear("test_pool2")
end)

TestFramework.Test("Get should reuse objects from pool", function()
    ObjectPool.CreatePool("test_pool3", function() return { val = 1 } end, function(obj) obj.val = 0 end, 3)
    
    local obj1 = ObjectPool.Get("test_pool3")
    obj1.val = 42
    ObjectPool.Return("test_pool3", obj1)
    
    local obj2 = ObjectPool.Get("test_pool3")
    TestFramework.AssertEqual(0, obj2.val)
    TestFramework.AssertEqual(obj1, obj2)
    
    local stats = ObjectPool.GetStats("test_pool3")
    TestFramework.AssertEqual(1, stats.reused)
    ObjectPool.Clear("test_pool3")
end)

TestFramework.Test("Return should not exceed maxSize", function()
    ObjectPool.CreatePool("test_pool4", function() return {} end, nil, 2)
    
    local obj1 = ObjectPool.Get("test_pool4")
    local obj2 = ObjectPool.Get("test_pool4")
    local obj3 = ObjectPool.Get("test_pool4")
    
    ObjectPool.Return("test_pool4", obj1)
    ObjectPool.Return("test_pool4", obj2)
    ObjectPool.Return("test_pool4", obj3)
    
    local stats = ObjectPool.GetStats("test_pool4")
    TestFramework.AssertEqual(2, stats.available)
    ObjectPool.Clear("test_pool4")
end)

TestFramework.Test("Prewarm should preallocate objects", function()
    ObjectPool.CreatePool("test_pool5", function() return { warmed = true } end, nil, 10)
    ObjectPool.Prewarm("test_pool5", 5)
    
    local stats = ObjectPool.GetStats("test_pool5")
    TestFramework.AssertEqual(5, stats.created)
    TestFramework.AssertEqual(5, stats.available)
    
    local obj = ObjectPool.Get("test_pool5")
    TestFramework.AssertEqual(true, obj.warmed)
    TestFramework.AssertEqual(1, stats.reused)
    ObjectPool.Clear("test_pool5")
end)

TestFramework.Test("GetBatch should get multiple objects", function()
    ObjectPool.CreatePool("test_pool6", function() return { idx = 0 } end, nil, 10)
    local objs = ObjectPool.GetBatch("test_pool6", 3)
    
    TestFramework.AssertEqual(3, #objs)
    for i, obj in ipairs(objs) do
        TestFramework.AssertNotNil(obj)
    end
    
    local stats = ObjectPool.GetStats("test_pool6")
    TestFramework.AssertEqual(3, stats.created)
    ObjectPool.Clear("test_pool6")
end)

TestFramework.Test("Clear should empty the pool", function()
    ObjectPool.CreatePool("test_pool7", function() return {} end, nil, 5)
    ObjectPool.Prewarm("test_pool7", 3)
    
    local stats = ObjectPool.GetStats("test_pool7")
    TestFramework.AssertEqual(3, stats.available)
    
    ObjectPool.Clear("test_pool7")
    stats = ObjectPool.GetStats("test_pool7")
    TestFramework.AssertEqual(0, stats.available)
    TestFramework.AssertEqual(0, stats.created)
end)

TestFramework.Test("HasPool should return correct status", function()
    ObjectPool.CreatePool("test_pool8", function() return {} end, nil, 5)
    TestFramework.AssertTrue(ObjectPool.HasPool("test_pool8"))
    TestFramework.AssertFalse(ObjectPool.HasPool("non_existent_pool"))
    ObjectPool.Clear("test_pool8")
end)

TestFramework.EndSuite()