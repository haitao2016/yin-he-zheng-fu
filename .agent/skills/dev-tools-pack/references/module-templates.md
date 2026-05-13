# Game Module Templates — 常用游戏子系统模板

按需阅读：当用户需要特定类型的游戏模块时，参考对应模板生成代码。

## 目录

1. [对象池（Object Pool）](#对象池)
2. [事件总线（Event Bus）](#事件总线)
3. [状态管理器（State Manager）](#状态管理器)
4. [存档系统（Save System）](#存档系统)
5. [物品/背包系统（Inventory）](#背包系统)
6. [对话系统（Dialogue）](#对话系统)
7. [计时器管理器（Timer Manager）](#计时器管理器)

---

## 对象池

高频创建/销毁对象（子弹、粒子、敌人）时使用，避免 GC 压力。

```lua
-- scripts/Systems/ObjectPool.lua
local M = {}

---@type table<string, Node[]>
local pools_ = {}
---@type Scene
local scene_ = nil

function M.Init(scene)
    scene_ = scene
    pools_ = {}
end

--- 获取对象（优先从池中取，否则新建）
---@param tag string 对象标签
---@param createFn fun(scene: Scene): Node 创建函数
---@return Node
function M.Get(tag, createFn)
    local pool = pools_[tag]
    if pool and #pool > 0 then
        local node = table.remove(pool)
        node.enabled = true
        return node
    end
    return createFn(scene_)
end

--- 归还对象到池中
---@param tag string
---@param node Node
function M.Release(tag, node)
    node.enabled = false
    if not pools_[tag] then pools_[tag] = {} end
    table.insert(pools_[tag], node)
end

--- 预热池（提前创建 N 个对象）
---@param tag string
---@param count number
---@param createFn fun(scene: Scene): Node
function M.Warmup(tag, count, createFn)
    for i = 1, count do
        local node = createFn(scene_)
        M.Release(tag, node)
    end
end

function M.Cleanup()
    for tag, pool in pairs(pools_) do
        for _, node in ipairs(pool) do
            node:Remove()
        end
    end
    pools_ = {}
    scene_ = nil
end

return M
```

---

## 事件总线

模块间解耦通信，避免直接依赖。

```lua
-- scripts/Systems/EventBus.lua
local M = {}

---@type table<string, fun(...)[]>
local listeners_ = {}

--- 订阅事件
---@param event string
---@param callback fun(...)
---@return fun() unsubscribe 取消订阅函数
function M.On(event, callback)
    if not listeners_[event] then listeners_[event] = {} end
    table.insert(listeners_[event], callback)
    return function()
        M.Off(event, callback)
    end
end

--- 取消订阅
---@param event string
---@param callback fun(...)
function M.Off(event, callback)
    local cbs = listeners_[event]
    if not cbs then return end
    for i = #cbs, 1, -1 do
        if cbs[i] == callback then
            table.remove(cbs, i)
            break
        end
    end
end

--- 触发事件
---@param event string
---@param ... any
function M.Emit(event, ...)
    local cbs = listeners_[event]
    if not cbs then return end
    for _, cb in ipairs(cbs) do
        cb(...)
    end
end

function M.Cleanup()
    listeners_ = {}
end

return M
```

---

## 状态管理器

游戏全局状态（菜单、游戏中、暂停、结算）切换管理。

```lua
-- scripts/Systems/StateManager.lua
local M = {}

---@type string
local current_ = "none"
---@type table<string, { enter?: fun(), exit?: fun(), update?: fun(dt: number) }>
local states_ = {}

--- 注册状态
---@param name string
---@param handlers table
function M.Register(name, handlers)
    states_[name] = handlers
end

--- 切换状态
---@param name string
function M.Switch(name)
    if not states_[name] then
        log:Write(LOG_WARNING, "[StateManager] Unknown state: " .. name)
        return
    end
    local prev = states_[current_]
    if prev and prev.exit then prev.exit() end
    current_ = name
    local next_ = states_[current_]
    if next_ and next_.enter then next_.enter() end
end

--- 当前状态名
---@return string
function M.Current() return current_ end

--- 每帧更新当前状态
---@param dt number
function M.Update(dt)
    local s = states_[current_]
    if s and s.update then s.update(dt) end
end

function M.Cleanup()
    local s = states_[current_]
    if s and s.exit then s.exit() end
    states_ = {}
    current_ = "none"
end

return M
```

---

## 存档系统

使用引擎沙箱文件 API 实现本地存档。

```lua
-- scripts/Systems/SaveSystem.lua
local cjson = require("cjson")
local M = {}

local SAVE_FILE = "save.json"

--- 保存数据
---@param data table
---@return boolean
function M.Save(data)
    local jsonStr = cjson.encode(data)
    local file = File:new(SAVE_FILE, FILE_WRITE)
    if not file then
        log:Write(LOG_ERROR, "[SaveSystem] Cannot open file for writing")
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    return true
end

--- 加载数据
---@return table|nil
function M.Load()
    if not fileSystem:FileExists(SAVE_FILE) then
        return nil
    end
    local file = File:new(SAVE_FILE, FILE_READ)
    if not file then return nil end
    local jsonStr = file:ReadString()
    file:Close()
    if jsonStr == "" then return nil end
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] JSON parse error: " .. tostring(data))
        return nil
    end
    return data
end

--- 删除存档
function M.Delete()
    if fileSystem:FileExists(SAVE_FILE) then
        fileSystem:Delete(SAVE_FILE)
    end
end

--- 存档是否存在
---@return boolean
function M.Exists()
    return fileSystem:FileExists(SAVE_FILE)
end

return M
```

---

## 背包系统

简单的物品管理，支持添加、移除、查找、容量限制。

```lua
-- scripts/Systems/Inventory.lua
local M = {}

---@class InventoryItem
---@field id string
---@field name string
---@field count number
---@field maxStack number

local CONFIG = {
    maxSlots = 20,
}

---@type InventoryItem[]
local items_ = {}

function M.Init(opts)
    opts = opts or {}
    if opts.maxSlots then CONFIG.maxSlots = opts.maxSlots end
    items_ = {}
end

--- 添加物品
---@param id string
---@param name string
---@param count? number
---@param maxStack? number
---@return boolean success
function M.Add(id, name, count, maxStack)
    count = count or 1
    maxStack = maxStack or 99
    -- 尝试堆叠到已有槽位
    for _, item in ipairs(items_) do
        if item.id == id and item.count < item.maxStack then
            local space = item.maxStack - item.count
            local add = math.min(count, space)
            item.count = item.count + add
            count = count - add
            if count <= 0 then return true end
        end
    end
    -- 创建新槽位
    while count > 0 and #items_ < CONFIG.maxSlots do
        local add = math.min(count, maxStack)
        table.insert(items_, { id = id, name = name, count = add, maxStack = maxStack })
        count = count - add
    end
    return count <= 0
end

--- 移除物品
---@param id string
---@param count? number
---@return boolean success
function M.Remove(id, count)
    count = count or 1
    for i = #items_, 1, -1 do
        if items_[i].id == id then
            local remove = math.min(count, items_[i].count)
            items_[i].count = items_[i].count - remove
            count = count - remove
            if items_[i].count <= 0 then table.remove(items_, i) end
            if count <= 0 then return true end
        end
    end
    return count <= 0
end

--- 查询物品数量
---@param id string
---@return number
function M.Count(id)
    local total = 0
    for _, item in ipairs(items_) do
        if item.id == id then total = total + item.count end
    end
    return total
end

--- 获取全部物品
---@return InventoryItem[]
function M.GetAll()
    return items_
end

function M.Cleanup()
    items_ = {}
end

return M
```

---

## 对话系统

简单的分支对话系统，支持 NPC 对话树和选项选择。

```lua
-- scripts/Systems/DialogueManager.lua
local M = {}

---@class DialogueNode
---@field speaker string
---@field text string
---@field choices? { text: string, next: string }[]
---@field next? string
---@field onEnter? fun()

---@type table<string, DialogueNode>
local dialogues_ = {}
---@type string|nil
local currentId_ = nil
---@type fun(node: DialogueNode)|nil
local onNodeChange_ = nil

function M.Init(opts)
    opts = opts or {}
    dialogues_ = {}
    currentId_ = nil
    onNodeChange_ = opts.onNodeChange
end

--- 加载对话数据
---@param data table<string, DialogueNode>
function M.LoadDialogue(data)
    for id, node in pairs(data) do
        dialogues_[id] = node
    end
end

--- 开始对话
---@param startId string
function M.Start(startId)
    currentId_ = startId
    local node = dialogues_[currentId_]
    if node then
        if node.onEnter then node.onEnter() end
        if onNodeChange_ then onNodeChange_(node) end
    end
end

--- 前进到下一节点
---@param choiceIndex? number 选项索引（从 1 开始）
function M.Advance(choiceIndex)
    local node = dialogues_[currentId_]
    if not node then return end
    local nextId
    if node.choices and choiceIndex then
        local choice = node.choices[choiceIndex]  -- Lua 数组从 1 开始
        if choice then nextId = choice.next end
    else
        nextId = node.next
    end
    if nextId then
        currentId_ = nextId
        local next_ = dialogues_[currentId_]
        if next_ then
            if next_.onEnter then next_.onEnter() end
            if onNodeChange_ then onNodeChange_(next_) end
        end
    else
        currentId_ = nil  -- 对话结束
        if onNodeChange_ then onNodeChange_(nil) end
    end
end

--- 获取当前节点
---@return DialogueNode|nil
function M.Current()
    if not currentId_ then return nil end
    return dialogues_[currentId_]
end

--- 是否在对话中
---@return boolean
function M.IsActive()
    return currentId_ ~= nil
end

function M.Cleanup()
    dialogues_ = {}
    currentId_ = nil
    onNodeChange_ = nil
end

return M
```

---

## 计时器管理器

管理游戏内延迟调用和周期性任务。

```lua
-- scripts/Systems/TimerManager.lua
local M = {}

---@class TimerEntry
---@field id number
---@field remaining number
---@field interval number
---@field callback fun()
---@field repeating boolean

---@type TimerEntry[]
local timers_ = {}
local nextId_ = 1

--- 延迟执行（一次性）
---@param delay number 秒
---@param callback fun()
---@return number timerId
function M.After(delay, callback)
    local id = nextId_; nextId_ = nextId_ + 1
    table.insert(timers_, {
        id = id, remaining = delay, interval = delay,
        callback = callback, repeating = false,
    })
    return id
end

--- 周期执行
---@param interval number 秒
---@param callback fun()
---@return number timerId
function M.Every(interval, callback)
    local id = nextId_; nextId_ = nextId_ + 1
    table.insert(timers_, {
        id = id, remaining = interval, interval = interval,
        callback = callback, repeating = true,
    })
    return id
end

--- 取消计时器
---@param timerId number
function M.Cancel(timerId)
    for i = #timers_, 1, -1 do
        if timers_[i].id == timerId then
            table.remove(timers_, i)
            return
        end
    end
end

--- 每帧调用
---@param dt number
function M.Update(dt)
    for i = #timers_, 1, -1 do
        local t = timers_[i]
        t.remaining = t.remaining - dt
        if t.remaining <= 0 then
            t.callback()
            if t.repeating then
                t.remaining = t.remaining + t.interval
            else
                table.remove(timers_, i)
            end
        end
    end
end

function M.Cleanup()
    timers_ = {}
    nextId_ = 1
end

return M
```
