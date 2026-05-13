# Auto-Updater 详细实现指南

> 本文档包含 8 种实现模式的完整代码，覆盖从版本检查到错误处理的全流程。

## 目录

1. [云端版本检查](#1-云端版本检查)
2. [本地版本缓存](#2-本地版本缓存)
3. [强制更新拦截](#3-强制更新拦截)
4. [更新日志展示](#4-更新日志展示)
5. [关卡/场景预加载](#5-关卡场景预加载)
6. [更新摘要报告](#6-更新摘要报告)
7. [错误处理与重试](#7-错误处理与重试)
8. [配置模式](#8-配置模式)
9. [常见陷阱](#9-常见陷阱)
10. [运行时定时检查](#10-运行时定时检查)

---

## 1. 云端版本检查

使用 `clientCloud` 的 `iscores` 表存储版本号（整数，可排序）。

### 单键版本检查

```lua
local function checkSingleVersion(onResult)
    clientCloud:Get("content_version", {
        ok = function(values, iscores)
            local cloudVer = iscores.content_version or 0
            onResult(cloudVer)
        end,
        error = function(code, reason)
            print("[AutoUpdater] Version check failed:", code, reason)
            onResult(nil, reason)
        end,
    })
end
```

### 多键批量检查（推荐）

同时获取版本号、最低版本、更新日志：

```lua
local function checkVersionBatch(onResult)
    clientCloud:BatchGet()
        :Key("content_version")      -- 当前最新版本
        :Key("min_version")          -- 最低允许版本
        :Key("update_changelog")     -- 更新日志（JSON 字符串）
        :Fetch({
            ok = function(values, iscores)
                onResult({
                    cloudVer  = iscores.content_version or 0,
                    minVer    = iscores.min_version or 0,
                    changelog = values.update_changelog or "[]",
                })
            end,
            error = function(code, reason)
                print("[AutoUpdater] Batch check failed:", code, reason)
                onResult(nil, reason)
            end,
        })
end
```

### 发布新版本时设置云变量

开发者在发布更新时调用（通常在管理工具或服务端脚本中）：

```lua
local cjson = require("cjson")

clientCloud:BatchSet()
    :SetInt("content_version", 3)
    :SetInt("min_version", 2)  -- 低于 v2 必须强制更新
    :Set("update_changelog", cjson.encode({
        { version = 3, title = "v1.3 冬季更新", items = {
            "新增冰雪关卡 x3",
            "新增圣诞角色皮肤",
            "修复掉线重连问题",
        }},
    }))
    :Save("发布 v1.3 更新", {
        ok = function() print("Version published") end,
        error = function(code, reason) print("Publish failed:", reason) end,
    })
```

---

## 2. 本地版本缓存

使用 `File` API 在本地缓存版本号，减少不必要的云端查询。

```lua
local cjson = require("cjson")

local VERSION_FILE = "update_state.json"

--- 读取本地缓存版本
---@return number version 本地版本号，无缓存返回 0
---@return number|nil timestamp 上次更新时间戳
local function readLocalVersion()
    if not fileSystem:FileExists(VERSION_FILE) then
        return 0, nil
    end
    local f = File(VERSION_FILE, FILE_READ)
    if not f:IsOpen() then return 0, nil end
    local content = f:ReadString()
    f:Close()
    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then return 0, nil end
    return data.version or 0, data.timestamp
end

--- 保存版本号到本地
---@param ver number 版本号
local function saveLocalVersion(ver)
    local f = File(VERSION_FILE, FILE_WRITE)
    if not f:IsOpen() then
        print("[AutoUpdater] Failed to save local version")
        return
    end
    f:WriteString(cjson.encode({
        version = ver,
        timestamp = os.time(),
    }))
    f:Close()
end
```

> **注意**: WASM 平台刷新页面后本地文件丢失。关键版本数据应以 `clientCloud` 为准，
> 本地缓存仅用于减少启动时的网络请求（命中缓存则跳过云端查询）。

---

## 3. 强制更新拦截

当版本低于 `min_version` 时，禁止进入游戏：

```lua
local UI = require("urhox-libs/UI")

local function showForceUpdateScreen(localVer, minVer)
    local root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 20, 20, 20, 255 },
        children = {
            UI.Label {
                text = "需要更新",
                fontSize = 32, color = { 255, 80, 80, 255 },
            },
            UI.Spacer { height = 16 },
            UI.Label {
                text = string.format(
                    "当前版本 v%d 已过期，最低要求 v%d",
                    localVer, minVer
                ),
                fontSize = 16, color = { 200, 200, 200, 255 },
            },
            UI.Spacer { height = 24 },
            UI.Button {
                text = "立即更新",
                variant = "primary",
                onClick = function(self)
                    -- 切换到更新下载界面
                    startResourceDownload()
                end,
            },
        },
    }
    UI.SetRoot(root)
end

--- 版本检查入口（含强制更新判断）
local function checkAndUpdate(onReady)
    local localVer = readLocalVersion()

    checkVersionBatch(function(info, err)
        if not info then
            -- 网络失败，允许使用本地版本进入
            print("[AutoUpdater] Cloud unavailable, using local version")
            onReady()
            return
        end

        -- 强制更新检查
        if localVer < info.minVer then
            showForceUpdateScreen(localVer, info.minVer)
            return  -- 阻断，不调用 onReady
        end

        -- 增量更新检查
        if info.cloudVer > localVer then
            startDownload(info, onReady)
        else
            onReady()
        end
    end)
end
```

---

## 4. 更新日志展示

下载完成后显示变更摘要：

```lua
local cjson = require("cjson")

local function showChangelog(changelogJson, onContinue)
    local ok, entries = pcall(cjson.decode, changelogJson)
    if not ok or type(entries) ~= "table" then
        onContinue()
        return
    end

    -- 构建日志子节点
    local logChildren = {}
    for _, entry in ipairs(entries) do
        -- 版本标题
        table.insert(logChildren, UI.Label {
            text = entry.title or ("v" .. (entry.version or "?")),
            fontSize = 20,
            color = { 100, 200, 255, 255 },
        })
        table.insert(logChildren, UI.Spacer { height = 6 })

        -- 变更条目
        if entry.items then
            for _, item in ipairs(entry.items) do
                table.insert(logChildren, UI.Label {
                    text = "  · " .. item,
                    fontSize = 14,
                    color = { 220, 220, 220, 255 },
                })
            end
        end
        table.insert(logChildren, UI.Spacer { height = 12 })
    end

    -- 添加继续按钮
    table.insert(logChildren, UI.Spacer { height = 16 })
    table.insert(logChildren, UI.Button {
        text = "进入游戏",
        variant = "primary",
        onClick = function(self) onContinue() end,
    })

    local root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 20, 20, 30, 240 },
        children = {
            UI.Panel {
                width = 400, maxHeight = 500,
                padding = 24,
                backgroundColor = { 40, 40, 50, 255 },
                borderRadius = 12,
                flexDirection = "column",
                children = {
                    UI.Label {
                        text = "更新内容",
                        fontSize = 24,
                        color = { 255, 255, 255, 255 },
                    },
                    UI.Spacer { height = 16 },
                    UI.ScrollView {
                        width = "100%",
                        flexGrow = 1,
                        flexShrink = 1,
                        children = logChildren,
                    },
                },
            },
        },
    }
    UI.SetRoot(root)
end
```

---

## 5. 关卡/场景预加载

在进入特定关卡前，预加载该关卡的所有依赖资源：

```lua
--- 预加载关卡资源
---@param prefabPath string 关卡 prefab 路径
---@param onReady function 预加载完成回调
---@param onProgress function|nil 进度回调 (completed, total)
local function preloadLevel(prefabPath, onReady, onProgress)
    -- 获取 prefab 的所有递归依赖
    local refs = cache:GetResRefs(prefabPath, true)

    if not refs or #refs == 0 then
        onReady()
        return
    end

    -- 过滤出未下载的资源
    local needDownload = {}
    for _, ref in ipairs(refs) do
        if not cache:Exists(ref) then
            table.insert(needDownload, ref)
        end
    end

    if #needDownload == 0 then
        onReady()
        return
    end

    cache:DownloadResources(needDownload,
        function(success, failedCount)
            if success then
                onReady()
            else
                print(string.format("[Preload] Failed: %d resources", failedCount))
                onReady()  -- 仍然尝试进入（DWP 占位符兜底）
            end
        end,
        function(completed, total, downloadedBytes, totalBytes)
            if onProgress then
                onProgress(completed, total)
            end
        end
    )
end

-- 使用示例
preloadLevel("Levels/World2/Stage1.prefab",
    function()
        print("Level ready, entering...")
        loadLevelScene("Levels/World2/Stage1.prefab")
    end,
    function(completed, total)
        updateLoadingUI(completed / total)
    end
)
```

---

## 6. 更新摘要报告

更新完成后生成摘要（灵感来源于 clawhub auto-updater 的报告机制）：

```lua
--- 生成更新摘要
---@param updateInfo table { cloudVer, localVer, resourceCount, totalBytes, elapsed }
---@return string 格式化的摘要文本
local function generateUpdateSummary(updateInfo)
    local lines = {
        "========== 更新摘要 ==========",
        string.format("版本: v%d → v%d", updateInfo.localVer, updateInfo.cloudVer),
        string.format("资源数: %d 个文件", updateInfo.resourceCount or 0),
        string.format("下载量: %s", formatBytes(updateInfo.totalBytes or 0)),
        string.format("耗时: %.1f 秒", updateInfo.elapsed or 0),
        "==============================",
    }
    return table.concat(lines, "\n")
end

--- 格式化字节数
---@param bytes number
---@return string
local function formatBytes(bytes)
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    else
        return string.format("%.1f MB", bytes / (1024 * 1024))
    end
end
```

---

## 7. 错误处理与重试

网络请求可能失败，实现带重试的版本检查：

```lua
--- 带重试的版本检查
---@param maxRetries number 最大重试次数
---@param retryDelay number 重试间隔（秒）
---@param onResult function(info, err) 结果回调
local function checkVersionWithRetry(maxRetries, retryDelay, onResult)
    local attempt = 0

    local function tryCheck()
        attempt = attempt + 1
        print(string.format("[AutoUpdater] Version check attempt %d/%d", attempt, maxRetries))

        checkVersionBatch(function(info, err)
            if info then
                onResult(info, nil)
                return
            end

            if attempt >= maxRetries then
                print("[AutoUpdater] All retries exhausted")
                onResult(nil, err or "Max retries reached")
                return
            end

            -- 延迟重试（使用引擎定时器，不要用 while 循环）
            delayCall(retryDelay, tryCheck)
        end)
    end

    tryCheck()
end

--- 延迟执行（基于引擎事件，不阻塞主线程）
---@param seconds number 延迟秒数
---@param callback function 回调函数
local function delayCall(seconds, callback)
    local elapsed = 0
    local eventName = "AutoUpdater_Delay_" .. tostring(os.clock())

    SubscribeToEvent(eventName, function() end)  -- 占位

    SubscribeToEvent("Update", function(eventType, eventData)
        elapsed = elapsed + eventData["TimeStep"]:GetFloat()
        if elapsed >= seconds then
            UnsubscribeFromEvent("Update")  -- 注意：会取消所有 Update 订阅
            callback()
        end
    end)
end
```

> **更安全的延迟方案**：为避免 `UnsubscribeFromEvent("Update")` 取消其他 Update 订阅，
> 推荐用标志位控制：

```lua
local function delayCallSafe(seconds, callback)
    local elapsed = 0
    local done = false

    -- 复用已有的 HandleUpdate，添加延迟逻辑
    local originalUpdate = HandleUpdate
    HandleUpdate = function(eventType, eventData)
        if originalUpdate then originalUpdate(eventType, eventData) end
        if done then return end
        elapsed = elapsed + eventData["TimeStep"]:GetFloat()
        if elapsed >= seconds then
            done = true
            callback()
        end
    end
end
```

---

## 8. 配置模式

将更新行为参数化，便于不同项目复用：

```lua
local UpdateConfig = {
    -- 云变量键名
    keys = {
        version     = "content_version",
        minVersion  = "min_version",
        changelog   = "update_changelog",
        resources   = "update_resources",
    },

    -- 重试策略
    retry = {
        maxAttempts  = 3,
        delaySeconds = 2.0,
    },

    -- UI 配置
    ui = {
        backgroundColor = { 30, 30, 30, 255 },
        accentColor     = { 100, 200, 255, 255 },
        titleFontSize   = 28,
        bodyFontSize    = 16,
        progressWidth   = 300,
        progressHeight  = 20,
    },

    -- 行为选项
    behavior = {
        -- "force": 必须更新才能进入
        -- "background": 后台下载，不阻断
        -- "prompt": 询问用户是否更新
        updateMode = "force",

        -- 是否显示更新日志
        showChangelog = true,

        -- 网络失败时是否允许进入游戏
        allowOffline = true,
    },
}
```

---

## 9. 常见陷阱

| 陷阱 | 原因 | 正确做法 |
|------|------|---------|
| 用 `while` 循环等待下载完成 | 阻塞主线程，导致画面卡死 | 使用回调 (`onComplete`, `onProgress`) |
| 用 `io.open` 读写文件 | `io` 库已被沙箱移除 | 使用 `File(path, mode)` |
| 用 HTTP 请求获取版本号 | 客户端无 HTTP 能力 | 使用 `clientCloud:Get()` |
| 在 WASM 上依赖本地文件持久化 | 刷新页面后数据丢失 | 关键数据用 `clientCloud`，本地仅缓存 |
| `cache:Exists(uri)` 后直接 `GetResource` | Exists 仅检查本地，不下载 | 用 `GetResourceAsync` 或先 `DownloadResource` |
| 在 `onProgress` 中做重计算 | 高频回调，影响帧率 | 仅更新 UI，避免复杂逻辑 |
| `UnsubscribeFromEvent("Update")` | 取消**所有** Update 订阅 | 用标志位控制，不要取消全局事件 |
| 版本号用字符串比较 | "10" < "9"（字典序） | 用 `iscores`（整数）存储版本号 |

---

## 10. 运行时定时检查

游戏运行期间按可配置间隔后台轮询云端版本，发现新版本时弹出非侵入式通知。
灵感源自 [clawhub auto-updater](https://clawhub.ai/pntrivedy/auto-updater-1-0-0) 的 cron 定时机制，
适配为 UrhoX HandleUpdate + dt 累加方案（引擎无 cron/setTimeout）。

### 10.1 ScheduledChecker 完整实现

```lua
--- scripts/ScheduledChecker.lua
--- 运行时定时版本检查器
--- 用法：在 HandleUpdate 中每帧调用 checker:Update(dt)
local cjson = require("cjson")

local ScheduledChecker = {}

---@class ScheduledCheckerConfig
---@field interval number      检查间隔秒数（默认 300）
---@field initialDelay number  首次检查延迟秒数（默认 60）
---@field versionKey string    云变量版本键名（默认 "content_version"）
---@field onNewVersion function(newVer: number, checkCount: number)  发现新版本回调
---@field onCheckStart function|nil  开始检查时回调（可选，用于 debug）
---@field onCheckEnd function|nil    检查结束时回调（可选）

--- 创建定时检查器实例
---@param config ScheduledCheckerConfig
---@return table checker
function ScheduledChecker.Create(config)
    local self = {
        -- 配置
        interval      = math.max(30, config.interval or 300),
        initialDelay  = math.max(5, config.initialDelay or 60),
        versionKey    = config.versionKey or "content_version",
        onNewVersion  = config.onNewVersion or function() end,
        onCheckStart  = config.onCheckStart,
        onCheckEnd    = config.onCheckEnd,

        -- 内部状态
        elapsed_      = 0,       -- 累计计时器
        enabled_      = true,    -- 是否启用
        checking_     = false,   -- 防止并发请求
        knownVer_     = 0,       -- 已通知的最高版本
        checkCount_   = 0,       -- 累计检查次数
        firstCheck_   = true,    -- 是否为首次检查
        lastCheckTime_ = 0,      -- 上次检查的 os.time()
        consecutiveFails_ = 0,   -- 连续失败次数（用于退避）
    }

    --- 每帧调用
    ---@param dt number 帧间隔秒数
    function self:Update(dt)
        if not self.enabled_ or self.checking_ then return end

        self.elapsed_ = self.elapsed_ + dt
        local threshold = self.firstCheck_ and self.initialDelay or self:GetEffectiveInterval()

        if self.elapsed_ < threshold then return end

        self.elapsed_ = 0
        self.firstCheck_ = false
        self:Check()
    end

    --- 计算有效间隔（含退避策略）
    ---@return number
    function self:GetEffectiveInterval()
        if self.consecutiveFails_ <= 0 then
            return self.interval
        end
        -- 指数退避：失败后间隔翻倍，最大 30 分钟
        local backoff = self.interval * (2 ^ math.min(self.consecutiveFails_, 5))
        return math.min(backoff, 1800)
    end

    --- 手动触发一次检查
    function self:Check()
        if self.checking_ then return end
        self.checking_ = true
        self.checkCount_ = self.checkCount_ + 1
        self.lastCheckTime_ = os.time()

        if self.onCheckStart then
            self.onCheckStart(self.checkCount_)
        end

        clientCloud:Get(self.versionKey, {
            ok = function(values, iscores)
                self.checking_ = false
                self.consecutiveFails_ = 0  -- 成功则重置退避
                local cloudVer = iscores[self.versionKey] or 0

                if self.onCheckEnd then
                    self.onCheckEnd(true, cloudVer)
                end

                -- 仅在版本高于已通知版本时触发回调
                if cloudVer > self.knownVer_ then
                    self.knownVer_ = cloudVer
                    self.onNewVersion(cloudVer, self.checkCount_)
                end
            end,
            error = function(code, reason)
                self.checking_ = false
                self.consecutiveFails_ = self.consecutiveFails_ + 1
                print(string.format(
                    "[ScheduledChecker] Check #%d failed (consecutive: %d): %s",
                    self.checkCount_, self.consecutiveFails_, reason
                ))
                if self.onCheckEnd then
                    self.onCheckEnd(false, nil)
                end
            end,
        })
    end

    --- 暂停定时检查（游戏暂停、设置界面等场景）
    function self:Pause()
        self.enabled_ = false
    end

    --- 恢复定时检查
    function self:Resume()
        self.enabled_ = true
        self.elapsed_ = 0  -- 重新开始计时
    end

    --- 启用/禁用
    ---@param enabled boolean
    function self:SetEnabled(enabled)
        self.enabled_ = enabled
        if enabled then self.elapsed_ = 0 end
    end

    --- 修改检查间隔
    ---@param seconds number 新间隔（最低 30 秒）
    function self:SetInterval(seconds)
        self.interval = math.max(30, seconds)
    end

    --- 设置已知版本（避免启动时重复通知 Start() 已处理的版本）
    ---@param ver number
    function self:SetKnownVersion(ver)
        self.knownVer_ = ver
    end

    --- 获取统计信息
    ---@return table
    function self:GetStats()
        return {
            checkCount        = self.checkCount_,
            lastCheckTime     = self.lastCheckTime_,
            consecutiveFails  = self.consecutiveFails_,
            effectiveInterval = self:GetEffectiveInterval(),
            enabled           = self.enabled_,
            knownVer          = self.knownVer_,
        }
    end

    return self
end

return ScheduledChecker
```

### 10.2 非侵入式 Toast 通知

发现新版本时在屏幕角落弹出横幅，不打断游戏：

```lua
local UI = require("urhox-libs/UI")

--- 显示更新 Toast（3 秒后自动消失，或用户手动关闭）
---@param parentRoot UIWidget 当前 UI 根节点
---@param newVer number 新版本号
---@param onUpdate function 用户点击"更新"时的回调
local function showUpdateToast(parentRoot, newVer, onUpdate)
    ---@type UIWidget
    local toast = nil
    local autoHideElapsed = 0
    local AUTO_HIDE_SECONDS = 8

    toast = UI.Panel {
        position = "absolute",
        top = 12, right = 12,
        width = 260, padding = 10,
        backgroundColor = { 30, 110, 200, 230 },
        borderRadius = 8,
        flexDirection = "column",
        gap = 6,
        children = {
            UI.Label {
                text = string.format("新版本 v%d 可用", newVer),
                fontSize = 14,
                color = { 255, 255, 255, 255 },
            },
            UI.Panel {
                flexDirection = "row",
                gap = 8,
                justifyContent = "flex-end",
                children = {
                    UI.Button {
                        text = "立即更新",
                        variant = "primary",
                        onClick = function(self)
                            toast:Remove()
                            onUpdate()
                        end,
                    },
                    UI.Button {
                        text = "稍后",
                        variant = "text",
                        onClick = function(self)
                            toast:Remove()
                        end,
                    },
                },
            },
        },
    }

    parentRoot:AddChild(toast)
end
```

### 10.3 与启动检查的协作

定时检查器应在 `Start()` 的启动检查**完成后**创建，并设置 `knownVer_` 为启动时的版本，
避免重复通知：

```lua
local ScheduledChecker = require("ScheduledChecker")

local checker_ = nil
local currentVer_ = 0

function Start()
    -- ... UI 初始化 ...

    -- 启动时版本检查（模式 A/B/C）
    checkVersionWithRetry(function(info, err)
        if info then
            currentVer_ = info.cloudVer
        else
            currentVer_ = readLocalVersion()
        end

        -- 进入游戏后启动定时检查
        enterGame()

        -- ★ 创建定时检查器，设置已知版本
        checker_ = ScheduledChecker.Create({
            interval     = 300,
            initialDelay = 60,
            versionKey   = "content_version",
            onNewVersion = function(newVer, checkCount)
                print(string.format("[AutoUpdater] 定时检查 #%d 发现新版本 v%d", checkCount, newVer))
                showUpdateToast(uiRoot_, newVer, function()
                    checker_:SetEnabled(false)
                    startResourceDownload()
                end)
            end,
        })
        checker_:SetKnownVersion(currentVer_)  -- ★ 关键：避免重复通知
    end)
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 定时检查器计时
    if checker_ then
        checker_:Update(dt)
    end

    -- ... 其他游戏逻辑 ...
end
```

### 10.4 暂停/恢复场景

游戏暂停、切到设置界面时应暂停检查，恢复后继续：

```lua
-- 打开暂停菜单
function onPauseGame()
    if checker_ then checker_:Pause() end
    showPauseMenu()
end

-- 关闭暂停菜单
function onResumeGame()
    if checker_ then checker_:Resume() end
end

-- 网络断开时暂停（避免堆积无效请求）
function onNetworkDisconnected()
    if checker_ then checker_:Pause() end
end

function onNetworkReconnected()
    if checker_ then
        checker_:Resume()
        checker_:Check()  -- 恢复后立即检查一次
    end
end
```

### 10.5 配置模式整合

将定时检查参数纳入统一配置：

```lua
local UpdateConfig = {
    -- ... 已有配置 ...

    -- 定时检查配置（新增）
    scheduledCheck = {
        enabled       = true,   -- 是否开启运行时定时检查
        interval      = 300,    -- 检查间隔（秒），最低 30
        initialDelay  = 60,     -- 首次检查延迟（秒）
        showToast     = true,   -- 是否显示 Toast 通知
        autoHide      = 8,      -- Toast 自动消失时间（秒），0 = 不自动消失
        pauseOnMenu   = true,   -- 打开菜单时暂停检查
    },
}
```

### 10.6 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 启动和定时同时通知同一版本 | 未设置 `knownVer_` | 启动检查后调用 `SetKnownVersion()` |
| 网络失败后频繁重试 | 无退避策略 | 已内置指数退避，最大 30 分钟 |
| 游戏暂停仍在请求 | 未暂停检查器 | 暂停时调用 `checker:Pause()` |
| 同一版本重复通知 | `knownVer_` 未更新 | 模块内部已处理 |
| 检查间隔设太短 | 云端请求限流 | `SetInterval` 强制最低 30 秒 |
| `while true` 阻塞画面 | 不能用循环等待 | 已用 HandleUpdate + dt 替代 |
