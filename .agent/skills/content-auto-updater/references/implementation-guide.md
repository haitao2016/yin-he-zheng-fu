# 游戏内容自动更新系统 — 实现指南

> 本文件提供完整的模块设计、实现步骤和 UI 构建细节。

---

## 目录

1. [系统架构](#1-系统架构)
2. [版本管理模块](#2-版本管理模块)
3. [资源清单模块](#3-资源清单模块)
4. [下载管理模块](#4-下载管理模块)
5. [更新 UI 模块](#5-更新-ui-模块)
6. [变更摘要模块](#6-变更摘要模块)
7. [强制更新策略](#7-强制更新策略)
8. [集成入口](#8-集成入口)
9. [调试与测试](#9-调试与测试)
10. [边玩边下策略](#10-边玩边下策略)

---

## 1. 系统架构

### 模块划分

```
scripts/
├── main.lua              # 游戏入口
├── UpdateManager.lua      # 更新管理器（协调者）
├── VersionManager.lua     # 版本管理（云端/本地）
├── ResourceManifest.lua   # 资源清单（版本→资源映射）
└── UpdateUI.lua           # 更新界面
```

### 依赖关系

```
main.lua
  └── UpdateManager.lua（协调者）
        ├── VersionManager.lua（版本检查）
        ├── ResourceManifest.lua（资源清单）
        └── UpdateUI.lua（进度界面）
              └── urhox-libs/UI（UI 组件库）
```

### 更新状态机

```
[IDLE] → [CHECKING] → [COMPARING] → [DOWNLOADING] → [VERIFYING] → [DONE]
                 ↓           ↓              ↓              ↓
              [ERROR]    [UP_TO_DATE]   [DOWNLOAD_FAIL]  [VERIFY_FAIL]
                 ↓           ↓              ↓              ↓
              [RETRY]   [ENTER_GAME]    [RETRY]        [RETRY]
```

---

## 2. 版本管理模块

### VersionManager.lua

```lua
local cjson = require("cjson")

local VersionManager = {}

-- 云端版本键名
local CLOUD_VERSION_KEY = "game_version"
-- 本地版本文件
local LOCAL_VERSION_FILE = "update_info.json"

--- 读取本地版本号
---@return number
function VersionManager.GetLocalVersion()
    if not fileSystem:FileExists(LOCAL_VERSION_FILE) then
        return 1
    end
    local file = File(LOCAL_VERSION_FILE, FILE_READ)
    local content = file:ReadLine()
    file:Close()
    if not content or content == "" then
        return 1
    end
    local ok, data = pcall(cjson.decode, content)
    if ok and data and data.version then
        return data.version
    end
    return 1
end

--- 保存本地版本号
---@param version number
function VersionManager.SaveLocalVersion(version)
    local file = File(LOCAL_VERSION_FILE, FILE_WRITE)
    file:WriteLine(cjson.encode({
        version = version,
        updatedAt = os.time(),
    }))
    file:Close()
end

--- 查询云端版本号（异步）
---@param callback fun(success: boolean, version: number)
function VersionManager.GetCloudVersion(callback)
    clientCloud:GetScore(CLOUD_VERSION_KEY, function(success, value)
        if success and value then
            callback(true, value)
        else
            callback(false, 0)
        end
    end)
end

--- 检查是否需要更新（异步）
---@param callback fun(needUpdate: boolean, localVer: number, cloudVer: number)
function VersionManager.CheckUpdate(callback)
    local localVer = VersionManager.GetLocalVersion()
    VersionManager.GetCloudVersion(function(success, cloudVer)
        if success then
            callback(cloudVer > localVer, localVer, cloudVer)
        else
            -- 网络失败，跳过更新
            callback(false, localVer, localVer)
        end
    end)
end

return VersionManager
```

### 版本号设计要点

| 要点 | 说明 |
|------|------|
| 使用整数版本号 | clientCloud 存储数值类型，整数便于比较 |
| 单调递增 | 每次发布版本 +1，不回退 |
| 云端更新由服务端执行 | 开发者通过 serverCloud 更新版本号 |
| 本地用 File 持久化 | 不要用 `io.open`（沙箱环境不可用） |

---

## 3. 资源清单模块

### ResourceManifest.lua

```lua
local ResourceManifest = {}

--- 版本→资源映射表
--- 每个版本只列出该版本新增/变更的资源
local MANIFEST = {
    [2] = {
        changelog = "新增第2关卡",
        resources = {
            "Textures/Levels/Level2/bg.png",
            "Textures/Levels/Level2/tileset.png",
            "Models/Levels/Level2/terrain.mdl",
            "Sounds/Levels/Level2/bgm.ogg",
        },
    },
    [3] = {
        changelog = "新增Boss战 + 新武器",
        resources = {
            "Models/Boss.mdl",
            "Textures/Boss_diffuse.png",
            "Sounds/boss_bgm.ogg",
            "Models/Weapons/Sword2.mdl",
        },
    },
    -- 后续版本在此追加...
}

--- 获取 fromVer+1 到 toVer 的所有待更新资源
---@param fromVer number 当前本地版本
---@param toVer number 目标云端版本
---@return string[] resources 需要下载的资源路径列表
---@return string[] changelogs 变更日志列表
function ResourceManifest.GetPendingResources(fromVer, toVer)
    local resources = {}
    local changelogs = {}
    local seen = {}  -- 去重

    for ver = fromVer + 1, toVer do
        local entry = MANIFEST[ver]
        if entry then
            changelogs[#changelogs + 1] = string.format("v%d: %s", ver, entry.changelog)
            for _, path in ipairs(entry.resources) do
                if not seen[path] then
                    seen[path] = true
                    resources[#resources + 1] = path
                end
            end
        end
    end

    return resources, changelogs
end

--- 过滤已缓存的资源，返回真正需要下载的列表
---@param resources string[]
---@return string[] needDownload
---@return number cachedCount
function ResourceManifest.FilterCached(resources)
    local needDownload = {}
    local cachedCount = 0

    for _, path in ipairs(resources) do
        if cache:IsResourceCached(path) then
            cachedCount = cachedCount + 1
        else
            needDownload[#needDownload + 1] = path
        end
    end

    return needDownload, cachedCount
end

return ResourceManifest
```

### 清单设计要点

| 要点 | 说明 |
|------|------|
| 增量式清单 | 每个版本只列出变更资源，不是全量列表 |
| 自动去重 | 同一资源在多个版本中出现时只下载一次 |
| 先过滤后下载 | 使用 `IsResourceCached` 跳过已有资源 |
| changelog 字段 | 每个版本附带变更说明，用于摘要报告 |

---

## 4. 下载管理模块

### 下载核心逻辑

```lua
--- 执行批量下载
---@param resources string[] 资源路径列表
---@param onProgress fun(current: number, total: number, path: string)
---@param onComplete fun(success: boolean, failedCount: number)
local function DownloadResources(resources, onProgress, onComplete)
    if #resources == 0 then
        onComplete(true, 0)
        return
    end

    cache:DownloadResources(
        resources,
        -- 进度回调
        function(current, total, path, success)
            onProgress(current, total, path)
        end,
        -- 完成回调
        function(successCount, totalCount)
            local failedCount = totalCount - successCount
            onComplete(failedCount == 0, failedCount)
        end
    )
end
```

### 重试机制

```lua
local MAX_RETRIES = 3

--- 带重试的下载
---@param resources string[]
---@param onProgress fun(current: number, total: number, path: string)
---@param onComplete fun(success: boolean)
---@param retryCount? number
local function DownloadWithRetry(resources, onProgress, onComplete, retryCount)
    retryCount = retryCount or 0

    DownloadResources(resources, onProgress, function(success, failedCount)
        if success then
            onComplete(true)
        elseif retryCount < MAX_RETRIES then
            -- 重新过滤，只重试失败的
            local stillNeeded = {}
            for _, path in ipairs(resources) do
                if not cache:IsResourceCached(path) then
                    stillNeeded[#stillNeeded + 1] = path
                end
            end
            DownloadWithRetry(stillNeeded, onProgress, onComplete, retryCount + 1)
        else
            onComplete(false)
        end
    end)
end
```

---

## 5. 更新 UI 模块

### UpdateUI.lua

```lua
local UI = require("urhox-libs/UI")

local UpdateUI = {}

---@type table UI 引用
local refs_ = {}

--- 创建更新界面
---@param options {onSkip?: function, onRetry?: function}
---@return table root UI 根节点
function UpdateUI.Create(options)
    refs_.statusLabel = UI.Label {
        text = "正在检查更新...",
        fontSize = 18, color = "#FFFFFF",
        marginBottom = 12,
    }

    refs_.progressBar = UI.ProgressBar {
        value = 0, max = 100,
        width = "100%", height = 20,
        marginBottom = 8,
    }

    refs_.fileLabel = UI.Label {
        text = "",
        fontSize = 14, color = "#AAAAAA",
        marginBottom = 16,
    }

    refs_.percentLabel = UI.Label {
        text = "0%",
        fontSize = 16, color = "#FFFFFF",
        marginBottom = 12,
    }

    -- 更新日志区域
    refs_.logPanel = UI.Panel {
        width = "100%", maxHeight = 120,
        backgroundColor = "#00000066",
        borderRadius = 8,
        padding = 8,
        marginBottom = 16,
        children = {},
    }

    -- 按钮区域
    local buttons = {}
    if options.onSkip then
        buttons[#buttons + 1] = UI.Button {
            text = "跳过更新",
            variant = "ghost",
            width = 120, height = 40,
            marginRight = 12,
            onClick = function(self) options.onSkip() end,
        }
    end
    refs_.retryButton = UI.Button {
        text = "重试",
        variant = "outline",
        width = 120, height = 40,
        visible = false,
        onClick = function(self)
            if options.onRetry then options.onRetry() end
        end,
    }
    buttons[#buttons + 1] = refs_.retryButton

    refs_.buttonPanel = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        children = buttons,
    }

    refs_.root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#0a0a1aF0",
        children = {
            UI.Panel {
                width = 400, padding = 32,
                backgroundColor = "#1a1a2eEE",
                borderRadius = 16,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "游戏更新",
                        fontSize = 28, color = "#FFFFFF",
                        marginBottom = 24,
                    },
                    refs_.statusLabel,
                    refs_.progressBar,
                    refs_.percentLabel,
                    refs_.fileLabel,
                    refs_.logPanel,
                    refs_.buttonPanel,
                },
            },
        },
    }

    return refs_.root
end

--- 更新状态文字
function UpdateUI.SetStatus(text)
    if refs_.statusLabel then refs_.statusLabel:setText(text) end
end

--- 更新进度
function UpdateUI.SetProgress(percent, fileName)
    if refs_.progressBar then refs_.progressBar:setValue(percent) end
    if refs_.percentLabel then refs_.percentLabel:setText(percent .. "%") end
    if refs_.fileLabel and fileName then
        refs_.fileLabel:setText("下载: " .. fileName)
    end
end

--- 添加日志条目
function UpdateUI.AddLog(text)
    if refs_.logPanel then
        local label = UI.Label { text = text, fontSize = 12, color = "#88FF88", marginBottom = 2 }
        refs_.logPanel:addChild(label)
    end
end

--- 显示重试按钮
function UpdateUI.ShowRetry()
    if refs_.retryButton then refs_.retryButton:setVisible(true) end
end

--- 隐藏更新界面
function UpdateUI.Hide()
    if refs_.root then
        UI.RemoveRoot(refs_.root)
        refs_ = {}
    end
end

return UpdateUI
```

---

## 6. 变更摘要模块

更新完成后展示本次更新的内容摘要：

```lua
--- 创建变更摘要面板
---@param changelogs string[] 变更日志列表
---@param resourceCount number 已下载资源数
---@param onContinue function 点击"进入游戏"的回调
local function CreateSummaryPanel(changelogs, resourceCount, onContinue)
    local logItems = {}
    for _, log in ipairs(changelogs) do
        logItems[#logItems + 1] = UI.Label {
            text = "  " .. log,
            fontSize = 14, color = "#CCCCCC",
            marginBottom = 4,
        }
    end

    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#0a0a1aF0",
        children = {
            UI.Panel {
                width = 400, padding = 28,
                backgroundColor = "#1a1a2eEE",
                borderRadius = 14,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "更新完成",
                        fontSize = 28, color = "#66FF66",
                        marginBottom = 16,
                    },
                    UI.Label {
                        text = string.format("已下载 %d 个资源", resourceCount),
                        fontSize = 16, color = "#AAAAAA",
                        marginBottom = 16,
                    },
                    UI.Panel {
                        width = "100%",
                        backgroundColor = "#00000066",
                        borderRadius = 8,
                        padding = 12,
                        marginBottom = 20,
                        children = logItems,
                    },
                    UI.Button {
                        text = "进入游戏",
                        variant = "primary",
                        width = "100%", height = 48,
                        onClick = function(self) onContinue() end,
                    },
                },
            },
        },
    }
end
```

---

## 7. 强制更新策略

对于破坏性更新（数据格式变更、协议升级），阻止旧版本进入游戏：

```lua
--- 强制更新检查
---@param localVer number
---@param minRequired number 最低要求版本
---@return boolean
local function IsForceUpdateRequired(localVer, minRequired)
    return localVer < minRequired
end
```

在强制更新模式下：
- 隐藏"跳过"按钮
- 下载失败后只显示"重试"
- 不允许进入游戏

---

## 8. 集成入口

### main.lua 标准集成

```lua
require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")
local UpdateManager = require("UpdateManager")

function Start()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 启动更新检查
    UpdateManager.Init(function(success)
        if success then
            -- 更新完成或已是最新，进入游戏
            StartGame()
        end
    end)
end

function StartGame()
    -- 正常的游戏初始化逻辑
end
```

---

## 9. 调试与测试

### 模拟更新场景

```lua
-- 开发环境中测试更新流程：
-- 1. 手动设置本地版本为旧版
VersionManager.SaveLocalVersion(1)

-- 2. 通过服务端设置云端版本
-- serverCloud:SetScore("game_version", 3)

-- 3. 启用 DWP 模拟模式
cache:SimulateDWP(true)  -- 模拟远程加载延迟

-- 4. 重启游戏，观察更新流程
```

### 日志输出

在关键节点添加日志：

```lua
print("[Update] Local version: " .. localVer)
print("[Update] Cloud version: " .. cloudVer)
print("[Update] Resources to download: " .. #resources)
print("[Update] Download progress: " .. current .. "/" .. total)
print("[Update] Download complete, success=" .. tostring(success))
```

---

## 10. 边玩边下策略

对于不需要阻断式更新的场景，支持进入游戏后后台更新：

```lua
--- 后台静默更新（不显示进度 UI）
function UpdateManager.BackgroundUpdate()
    VersionManager.CheckUpdate(function(needUpdate, localVer, cloudVer)
        if not needUpdate then return end

        local resources, changelogs = ResourceManifest.GetPendingResources(localVer, cloudVer)
        local needDownload = ResourceManifest.FilterCached(resources)

        if #needDownload == 0 then
            VersionManager.SaveLocalVersion(cloudVer)
            return
        end

        -- 静默下载，不阻断游戏
        cache:DownloadResources(
            needDownload,
            function(current, total, path, success)
                -- 仅输出日志，不更新 UI
                print(string.format("[BgUpdate] %d/%d %s", current, total, path))
            end,
            function(successCount, totalCount)
                if successCount == totalCount then
                    VersionManager.SaveLocalVersion(cloudVer)
                    print("[BgUpdate] Complete\!")
                end
            end
        )
    end)
end
```

此模式适合：
- 非关键资源的更新（新皮肤、新装饰）
- 用户体验优先的场景（不希望启动时等待）
- 与 DWP 自动模式配合使用
