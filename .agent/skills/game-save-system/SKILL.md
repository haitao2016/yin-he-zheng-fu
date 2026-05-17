---
name: game-save-system
description: |
  UrhoX Lua 游戏存档系统生成器。根据用户游戏的状态变量自动生成完整的存档/读档模块，
  支持本地多槽位存档、自动保存、存档校验、云端同步（clientCloud）。
  覆盖从"单机存档"到"云存档排行榜"的完整数据持久化需求。

  Use when users need to (1) 为游戏添加存档/读档功能,
  (2) 实现多存档槽位管理,
  (3) 添加自动保存（auto-save）机制,
  (4) 将本地存档同步到云端,
  (5) 实现存档数据校验与损坏恢复,
  (6) 用户说"存档""保存""读档""加载进度""save""load",
  (7) 用户说"自动保存""auto save""存档槽""save slot",
  (8) 用户说"云存档""云同步""cloud save"。

  MUST trigger when:
    - 用户要求添加存档/读档功能
    - 用户需要保存和恢复游戏进度
    - 用户提到存档相关的任何需求

  trigger-keywords:
    - 存档
    - 读档
    - 保存进度
    - 加载进度
    - 存档槽
    - 自动保存
    - save
    - load
    - save slot
    - auto save
    - cloud save
    - 云存档
    - 云同步
    - 游戏进度
    - 存档系统
license: MIT
compatibility: "UrhoX engine (Lua 5.4). 使用 File/FileSystem 进行本地存储，cjson 进行 JSON 编解码，clientCloud 进行云端同步。兼容所有 UrhoX 脚手架类型（2D, 3D, NanoVG）。无外部网络依赖。"
metadata:
  version: "1.0.0"
  author: "UrhoX Dev Team"
  tags: ["save", "load", "persistence", "cloud", "storage", "game-progress", "urhox"]
---

# Game Save System - UrhoX Lua 游戏存档系统生成器

## 身份

你是一位 UrhoX Lua 游戏存档系统专家。你的工作是根据用户游戏的具体状态变量，**自动生成**完整的存档/读档模块代码，并确保在不同平台上的可靠性。

---

## 核心工作流程

```
用户描述游戏 / AI 分析现有代码
  |
  v
识别需要持久化的游戏状态
  |
  v
选择存档方案（本地 / 云端 / 混合）
  |
  v
生成 SaveManager 模块代码
  |
  v
集成到用户的 main.lua
  |
  v
测试验证
```

### 第一步：识别游戏状态

扫描用户代码，识别以下类型的持久化数据：

| 数据类别 | 示例 | 存储方式 |
|---------|------|---------|
| **核心进度** | 关卡、等级、经验值 | 必须存档 |
| **资源数值** | 金币、宝石、体力 | 必须存档 |
| **物品清单** | 背包、装备、技能 | 必须存档 |
| **设置偏好** | 音量、难度、语言 | 必须存档 |
| **临时状态** | 当前位置、血量、BUFF | 可选存档 |
| **统计数据** | 游戏时长、击杀数 | 可选存档 |

### 第二步：选择存档方案

| 方案 | 适用场景 | 技术栈 |
|------|---------|--------|
| **方案 A：纯本地** | 单机游戏、离线游戏 | File + cjson |
| **方案 B：纯云端** | 需要跨设备同步 | clientCloud |
| **方案 C：混合模式** | 本地缓存 + 云端同步 | File + clientCloud |

> **平台注意**：WASM 平台本地存储在刷新后会丢失，必须使用云端方案。
> **服务端注意**：Server 模式完全屏蔽文件读写，存档逻辑只能放客户端。

### 第三步：生成代码

根据用户选择的方案，生成对应的 `SaveManager.lua` 模块。

---

## 方案 A：本地存档模块

适用于单机游戏。支持多槽位、自动保存、数据校验。

### SaveManager.lua（本地版）

```lua
-- scripts/SaveManager.lua
-- UrhoX 本地存档管理器：多槽位 + 自动保存 + 数据校验
local SaveManager = {}

-- ─── 配置 ───────────────────────────────────────────────────────────────────
local CONFIG = {
    saveDir       = "saves",           -- 存档目录
    maxSlots      = 3,                 -- 最大槽位数
    autoSaveSlot  = 0,                 -- 自动保存使用的槽位（0 = 专用自动存档）
    autoSaveInterval = 60.0,           -- 自动保存间隔（秒）
    version       = 1,                 -- 存档版本号（用于版本迁移）
}

local autoSaveTimer_ = 0.0
local currentSlot_   = 1
local isDirty_       = false  -- 数据是否有未保存的变更

-- ─── 默认游戏状态（用户需根据自己的游戏修改） ────────────────────────────────
local defaultState = {
    -- 核心进度
    level         = 1,
    experience    = 0,
    -- 资源
    coins         = 0,
    gems          = 0,
    -- 物品
    inventory     = {},
    equipment     = {},
    -- 设置
    settings      = {
        musicVolume = 0.8,
        sfxVolume   = 1.0,
        difficulty  = "normal",
    },
    -- 统计
    stats         = {
        playTime    = 0,
        deaths      = 0,
        enemiesKilled = 0,
    },
}

-- 当前游戏状态（运行时使用）
local gameState = {}

-- ─── 工具函数 ────────────────────────────────────────────────────────────────

-- 深拷贝表
local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- 简单校验和（检测数据损坏）
local function calcChecksum(str)
    local sum = 0
    for i = 1, #str do
        sum = (sum + string.byte(str, i) * i) % 65521
    end
    return sum
end

-- ─── 初始化 ──────────────────────────────────────────────────────────────────
--- 初始化存档系统
--- @param customDefaults table|nil 自定义默认状态（合并到 defaultState）
--- @param config table|nil 自定义配置（合并到 CONFIG）
function SaveManager.Init(customDefaults, config)
    -- 合并自定义配置
    if config then
        for k, v in pairs(config) do
            CONFIG[k] = v
        end
    end
    -- 合并自定义默认状态
    if customDefaults then
        for k, v in pairs(customDefaults) do
            defaultState[k] = v
        end
    end
    -- 创建存档目录
    fileSystem:CreateDir(CONFIG.saveDir)
    -- 初始化为默认状态
    gameState = deepCopy(defaultState)
    isDirty_ = false
    print("[SaveManager] 初始化完成，最大槽位: " .. CONFIG.maxSlots)
end

-- ─── 获取/设置游戏状态 ───────────────────────────────────────────────────────
--- 获取当前游戏状态（只读引用，修改请用 Set）
--- @return table
function SaveManager.GetState()
    return gameState
end

--- 设置游戏状态字段
--- @param key string 字段名（支持点号路径如 "settings.musicVolume"）
--- @param value any 值
function SaveManager.Set(key, value)
    local keys = {}
    for part in string.gmatch(key, "[^%.]+") do
        table.insert(keys, part)
    end
    local target = gameState
    for i = 1, #keys - 1 do
        if type(target[keys[i]]) ~= "table" then
            target[keys[i]] = {}
        end
        target = target[keys[i]]
    end
    target[keys[#keys]] = value
    isDirty_ = true
end

--- 获取游戏状态字段
--- @param key string 字段名（支持点号路径）
--- @param fallback any 默认值
--- @return any
function SaveManager.Get(key, fallback)
    local keys = {}
    for part in string.gmatch(key, "[^%.]+") do
        table.insert(keys, part)
    end
    local target = gameState
    for i = 1, #keys do
        if type(target) ~= "table" then return fallback end
        target = target[keys[i]]
    end
    if target == nil then return fallback end
    return target
end

-- ─── 存档操作 ────────────────────────────────────────────────────────────────

--- 获取存档文件路径
--- @param slot number 槽位号
--- @return string
local function getSlotPath(slot)
    if slot == 0 then
        return CONFIG.saveDir .. "/autosave.json"
    end
    return CONFIG.saveDir .. "/slot" .. slot .. ".json"
end

--- 保存到指定槽位
--- @param slot number 槽位号（1~maxSlots，0 为自动存档）
--- @return boolean 是否成功
function SaveManager.Save(slot)
    slot = slot or currentSlot_
    if slot < 0 or slot > CONFIG.maxSlots then
        print("[SaveManager] 无效槽位: " .. slot)
        return false
    end

    local saveData = {
        version   = CONFIG.version,
        timestamp = os.time(),
        dateStr   = os.date("%Y-%m-%d %H:%M:%S"),
        slot      = slot,
        state     = gameState,
    }

    local jsonStr = cjson.encode(saveData)
    saveData.checksum = calcChecksum(jsonStr)
    jsonStr = cjson.encode(saveData)

    local path = getSlotPath(slot)
    local file = File(path, FILE_WRITE)
    if not file:IsOpen() then
        print("[SaveManager] 无法写入: " .. path)
        return false
    end
    file:WriteString(jsonStr)
    file:Close()

    isDirty_ = false
    currentSlot_ = slot
    print("[SaveManager] 已保存到槽位 " .. slot .. " (" .. path .. ")")
    return true
end

--- 从指定槽位读取
--- @param slot number 槽位号
--- @return boolean 是否成功
function SaveManager.Load(slot)
    slot = slot or currentSlot_
    local path = getSlotPath(slot)

    if not fileSystem:FileExists(path) then
        print("[SaveManager] 存档不存在: " .. path)
        return false
    end

    local file = File(path, FILE_READ)
    if not file:IsOpen() then
        print("[SaveManager] 无法读取: " .. path)
        return false
    end
    local jsonStr = file:ReadString()
    file:Close()

    local ok, saveData = pcall(cjson.decode, jsonStr)
    if not ok or type(saveData) ~= "table" then
        print("[SaveManager] 存档数据损坏: " .. path)
        return false
    end

    -- 校验和验证
    local storedChecksum = saveData.checksum
    if storedChecksum then
        saveData.checksum = nil
        local verifyStr = cjson.encode(saveData)
        local computed = calcChecksum(verifyStr)
        saveData.checksum = storedChecksum
        if computed ~= storedChecksum then
            print("[SaveManager] 校验和不匹配，存档可能已损坏: " .. path)
        end
    end

    -- 版本迁移
    if saveData.version and saveData.version < CONFIG.version then
        saveData.state = SaveManager.Migrate(saveData.state, saveData.version, CONFIG.version)
    end

    -- 合并到当前状态（保留默认值中新增的字段）
    gameState = deepCopy(defaultState)
    if saveData.state then
        for k, v in pairs(saveData.state) do
            if type(v) == "table" and type(gameState[k]) == "table" then
                for k2, v2 in pairs(v) do
                    gameState[k][k2] = v2
                end
            else
                gameState[k] = v
            end
        end
    end

    isDirty_ = false
    currentSlot_ = slot
    print("[SaveManager] 已从槽位 " .. slot .. " 加载")
    return true
end

--- 删除指定槽位的存档
--- @param slot number 槽位号
--- @return boolean
function SaveManager.Delete(slot)
    local path = getSlotPath(slot)
    if fileSystem:FileExists(path) then
        local file = File(path, FILE_WRITE)
        if file:IsOpen() then
            file:WriteString("")
            file:Close()
            print("[SaveManager] 已删除槽位 " .. slot)
            return true
        end
    end
    return false
end

--- 重置为默认状态（不删除存档文件）
function SaveManager.Reset()
    gameState = deepCopy(defaultState)
    isDirty_ = true
    print("[SaveManager] 已重置为默认状态")
end

-- ─── 槽位信息 ────────────────────────────────────────────────────────────────

--- 获取所有存档槽位的摘要信息
--- @return table[] 每个槽位的 { slot, exists, dateStr, level, playTime }
function SaveManager.GetSlotInfoList()
    local list = {}
    for slot = 1, CONFIG.maxSlots do
        local info = { slot = slot, exists = false }
        local path = getSlotPath(slot)
        if fileSystem:FileExists(path) then
            local file = File(path, FILE_READ)
            if file:IsOpen() then
                local ok2, data = pcall(cjson.decode, file:ReadString())
                file:Close()
                if ok2 and data and data.state then
                    info.exists   = true
                    info.dateStr  = data.dateStr or "未知时间"
                    info.level    = data.state.level or 1
                    info.playTime = (data.state.stats and data.state.stats.playTime) or 0
                end
            end
        end
        table.insert(list, info)
    end
    return list
end

--- 检查指定槽位是否有存档
--- @param slot number
--- @return boolean
function SaveManager.HasSave(slot)
    local path = getSlotPath(slot)
    if not fileSystem:FileExists(path) then return false end
    local file = File(path, FILE_READ)
    if not file:IsOpen() then return false end
    local content = file:ReadString()
    file:Close()
    return #content > 2
end

-- ─── 自动保存 ────────────────────────────────────────────────────────────────

--- 在 Update 中调用，处理自动保存计时
--- @param dt number 时间步长（秒）
function SaveManager.Update(dt)
    if CONFIG.autoSaveInterval <= 0 then return end

    -- 累计游戏时长
    if gameState.stats then
        gameState.stats.playTime = (gameState.stats.playTime or 0) + dt
    end

    autoSaveTimer_ = autoSaveTimer_ + dt
    if autoSaveTimer_ >= CONFIG.autoSaveInterval and isDirty_ then
        autoSaveTimer_ = 0
        SaveManager.Save(CONFIG.autoSaveSlot)
        print("[SaveManager] 自动保存完成")
    end
end

--- 标记数据已变更（触发下一次自动保存）
function SaveManager.MarkDirty()
    isDirty_ = true
end

--- 手动触发自动保存（不等待计时器）
function SaveManager.AutoSaveNow()
    SaveManager.Save(CONFIG.autoSaveSlot)
    autoSaveTimer_ = 0
end

-- ─── 版本迁移 ────────────────────────────────────────────────────────────────

--- 存档版本迁移（用户根据需要重写此函数）
--- @param state table 旧版本的游戏状态
--- @param fromVer number 旧版本号
--- @param toVer number 新版本号
--- @return table 迁移后的状态
function SaveManager.Migrate(state, fromVer, toVer)
    print("[SaveManager] 迁移存档: v" .. fromVer .. " -> v" .. toVer)
    -- 示例：从 v1 迁移到 v2（新增 gems 字段）
    -- if fromVer < 2 then
    --     state.gems = state.gems or 0
    -- end
    return state
end

-- ─── 当前状态 ────────────────────────────────────────────────────────────────

function SaveManager.GetCurrentSlot() return currentSlot_ end
function SaveManager.IsDirty() return isDirty_ end

return SaveManager
```

---

## 方案 B：云端存档模块

适用于需要跨设备同步的游戏。使用 `clientCloud` API。

> **前提**：`clientCloud` 仅限客户端（Standalone / Client 模式）使用。

### CloudSaveManager.lua（云端版）

```lua
-- scripts/CloudSaveManager.lua
-- UrhoX 云存档管理器：基于 clientCloud API
local CloudSaveManager = {}

-- ─── 配置 ────────────────────────────────────────────────────────────────────
local KEYS = {
    progress   = "game_progress",     -- 复杂数据 -> values（Set）
    highScore  = "high_score",        -- 整数 -> iscores（SetInt，可排行榜）
    coins      = "coins",             -- 整数 -> iscores（可增量 Add）
    playCount  = "play_count",        -- 整数 -> iscores
}

-- 本地缓存
local cachedState = {
    progress  = {},
    highScore = 0,
    coins     = 0,
    playCount = 0,
}

local isLoaded_ = false

-- ─── 初始化（从云端拉取） ────────────────────────────────────────────────────
--- 初始化云存档，从服务器拉取最新数据
--- @param callback function|nil 加载完成回调 function(success)
function CloudSaveManager.Init(callback)
    clientCloud:BatchGet()
        :Key(KEYS.progress)
        :Key(KEYS.highScore)
        :Key(KEYS.coins)
        :Key(KEYS.playCount)
        :Fetch({
            ok = function(values, iscores)
                if values[KEYS.progress] then
                    cachedState.progress = values[KEYS.progress]
                end
                cachedState.highScore = iscores[KEYS.highScore] or 0
                cachedState.coins     = iscores[KEYS.coins] or 0
                cachedState.playCount = iscores[KEYS.playCount] or 0

                isLoaded_ = true
                print("[CloudSave] 云端数据已加载")
                if callback then callback(true) end
            end,
            error = function(code, reason)
                print("[CloudSave] 加载失败: " .. tostring(reason))
                isLoaded_ = true
                if callback then callback(false) end
            end
        })
end

-- ─── 保存到云端 ──────────────────────────────────────────────────────────────
--- 批量保存所有数据到云端
--- @param callback function|nil 完成回调 function(success)
function CloudSaveManager.SaveAll(callback)
    clientCloud:BatchSet()
        :Set(KEYS.progress, cachedState.progress)
        :SetInt(KEYS.highScore, cachedState.highScore)
        :SetInt(KEYS.coins, cachedState.coins)
        :SetInt(KEYS.playCount, cachedState.playCount)
        :Save("游戏存档", {
            ok = function()
                print("[CloudSave] 云端保存成功")
                if callback then callback(true) end
            end,
            error = function(code, reason)
                print("[CloudSave] 保存失败: " .. tostring(reason))
                if callback then callback(false) end
            end
        })
end

-- ─── 便捷方法 ────────────────────────────────────────────────────────────────

--- 更新最高分（仅当新分数更高时保存）
function CloudSaveManager.UpdateHighScore(newScore)
    if newScore > cachedState.highScore then
        cachedState.highScore = newScore
        clientCloud:SetInt(KEYS.highScore, newScore, {
            ok = function() print("[CloudSave] 新纪录: " .. newScore) end
        })
    end
end

--- 增减金币
function CloudSaveManager.AddCoins(delta)
    cachedState.coins = cachedState.coins + delta
    clientCloud:Add(KEYS.coins, delta, {
        ok = function() print("[CloudSave] 金币变动: " .. delta) end,
        error = function(code, reason)
            print("[CloudSave] 金币操作失败: " .. tostring(reason))
            cachedState.coins = cachedState.coins - delta
        end
    })
end

--- 增加游戏次数
function CloudSaveManager.IncrementPlayCount()
    cachedState.playCount = cachedState.playCount + 1
    clientCloud:Add(KEYS.playCount, 1)
end

--- 保存复杂进度数据
function CloudSaveManager.SaveProgress(progressTable)
    cachedState.progress = progressTable
    clientCloud:Set(KEYS.progress, progressTable, {
        ok = function() print("[CloudSave] 进度已保存") end
    })
end

-- ─── 读取接口 ────────────────────────────────────────────────────────────────

function CloudSaveManager.GetHighScore() return cachedState.highScore end
function CloudSaveManager.GetCoins() return cachedState.coins end
function CloudSaveManager.GetPlayCount() return cachedState.playCount end
function CloudSaveManager.GetProgress() return cachedState.progress end
function CloudSaveManager.IsLoaded() return isLoaded_ end

return CloudSaveManager
```

---

## 方案 C：混合存档（本地 + 云端）

对于同时需要离线可用和跨设备同步的游戏，组合使用方案 A 和 B：

```lua
-- scripts/main.lua 中的混合存档策略
local SaveManager      = require "SaveManager"
local CloudSaveManager = require "CloudSaveManager"

function Start()
    -- 1. 先初始化本地存档（立即可用）
    SaveManager.Init({
        level = 1, coins = 0, highScore = 0,
    })

    -- 2. 尝试加载本地最新存档
    if SaveManager.HasSave(1) then
        SaveManager.Load(1)
    end

    -- 3. 异步拉取云端数据，取较新的
    CloudSaveManager.Init(function(success)
        if success then
            local localState = SaveManager.GetState()
            local cloudCoins = CloudSaveManager.GetCoins()
            if cloudCoins > (localState.coins or 0) then
                SaveManager.Set("coins", cloudCoins)
            end
            local cloudScore = CloudSaveManager.GetHighScore()
            if cloudScore > (localState.highScore or 0) then
                SaveManager.Set("highScore", cloudScore)
            end
            print("[混合存档] 云端数据已合并")
        end
    end)

    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    SaveManager.Update(dt)
end

-- 游戏关键节点触发同步
function OnLevelComplete(level, score, coinsEarned)
    SaveManager.Set("level", level)
    SaveManager.Set("coins", SaveManager.Get("coins", 0) + coinsEarned)
    SaveManager.Save(1)

    CloudSaveManager.UpdateHighScore(score)
    CloudSaveManager.AddCoins(coinsEarned)
    CloudSaveManager.SaveProgress({ level = level })
end
```

---

## 集成指南

### 最小集成（5 行代码）

```lua
local SaveManager = require "SaveManager"

function Start()
    SaveManager.Init()                       -- 1. 初始化
    SaveManager.Load(1)                      -- 2. 尝试加载
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    SaveManager.Update(dt)                   -- 3. 自动保存计时
end

-- 游戏中使用
SaveManager.Set("level", 5)                  -- 4. 修改状态
SaveManager.Save(1)                          -- 5. 手动保存
```

### 存档选择界面（配合 UI 组件）

```lua
local UI = require("urhox-libs/UI")

function ShowSaveSlotUI()
    local slots = SaveManager.GetSlotInfoList()
    local children = {}

    for _, info in ipairs(slots) do
        local label
        if info.exists then
            local mins = math.floor((info.playTime or 0) / 60)
            label = string.format("槽位 %d | Lv.%d | %s | %d分钟",
                info.slot, info.level, info.dateStr, mins)
        else
            label = string.format("槽位 %d | 空", info.slot)
        end

        table.insert(children, UI.Button {
            text = label,
            width = "90%",
            marginBottom = 8,
            onClick = function(self)
                if info.exists then
                    SaveManager.Load(info.slot)
                    print("已加载槽位 " .. info.slot)
                else
                    SaveManager.Save(info.slot)
                    print("已保存到槽位 " .. info.slot)
                end
            end,
        })
    end

    local panel = UI.Panel {
        width = 400, height = "80%",
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        padding = 16,
        backgroundColor = "#000000CC",
        children = {
            UI.Label { text = "存档管理", fontSize = 24, color = "#FFFFFF", marginBottom = 16 },
            table.unpack(children)
        }
    }
    UI.SetRoot(panel)
end
```

---

## 关键技术规则

以下规则全部来源于引擎文档，不引入额外约束：

| 规则 | 来源 | 说明 |
|------|------|------|
| 使用 `File` 而非 `io` | `recipes/file-storage.md` | `io` 库已被沙箱移除 |
| 使用 `cjson` 编解码 JSON | `recipes/json.md` | 全局变量，无需 require |
| 相对路径存储 | `recipes/file-storage.md` | 引擎自动提供项目+用户隔离 |
| WASM 本地存储会丢失 | `recipes/file-storage.md` | 刷新页面后数据丢失 |
| Server 模式无文件读写 | `recipes/file-storage.md` | 存档逻辑只能放客户端 |
| `clientCloud` 仅限客户端 | `recipes/client-cloud-score.md` | Standalone / Client 模式 |
| `Set` -> values（复杂数据） | `recipes/client-cloud-score.md` | 不可排行榜 |
| `SetInt/Add` -> iscores（整数） | `recipes/client-cloud-score.md` | 可排行榜排序 |
| `pcall` 包裹 JSON 解码 | `recipes/json.md` | 防止损坏数据导致崩溃 |
| Lua 数组索引从 1 开始 | CLAUDE.md 规则 #4 | `for i = 1, #list do` |
| `table.unpack` 放末尾 | CLAUDE.md 规则 #4.5 | 否则只展开第一个元素 |

---

## 自定义指南

### 如何添加新的存档字段

```lua
-- 1. 在 defaultState 中添加新字段
local defaultState = {
    level = 1,
    coins = 0,
    newField = "默认值",   -- 新增
}

-- 2. 如果是版本升级，更新 CONFIG.version 和 Migrate 函数
CONFIG.version = 2

function SaveManager.Migrate(state, fromVer, toVer)
    if fromVer < 2 then
        state.newField = state.newField or "默认值"
    end
    return state
end
```

### 如何切换自动保存间隔

```lua
SaveManager.Init(nil, {
    autoSaveInterval = 30,  -- 30 秒自动保存
    maxSlots = 5,           -- 5 个槽位
})
```

### 如何禁用自动保存

```lua
SaveManager.Init(nil, {
    autoSaveInterval = 0,  -- 禁用自动保存
})
```

---

## 与引擎核心规则的关系

本 Skill 的所有技术方案均来源于引擎文档，不引入额外约束：

| Skill 功能 | 对应引擎文档 |
|-----------|-------------|
| 本地文件读写 | `engine-docs/recipes/file-storage.md` |
| JSON 编解码 | `engine-docs/recipes/json.md` |
| 云端存储 | `engine-docs/recipes/client-cloud-score.md` |
| UI 存档界面 | `engine-docs/recipes/ui.md` |
| 代码存放路径 | CLAUDE.md 规则 #1 |
| 资源路径引用 | CLAUDE.md 规则 #1.5 |

本 Skill 不会修改引擎代码、不访问外部网络、不执行危险操作。
