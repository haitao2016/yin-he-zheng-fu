-- ============================================================
-- 游戏内容自动更新系统 — 完整示例
-- ============================================================
-- 本文件将 VersionManager / ResourceManifest / UpdateUI / UpdateManager
-- 合并到单文件中，可直接复制到 scripts/main.lua 运行。
-- 实际项目建议拆分为多个模块（见 implementation-guide.md §1）。
--
-- 更新流程：
--   游戏启动 → 版本检查(clientCloud) → 资源清单对比 → 增量下载(DWP)
--   → 验证 → 变更摘要 → 进入游戏
--
-- 目录:
--   1. 配置区域 .................. Config 表
--   2. 资源清单 .................. MANIFEST 表
--   3. 版本管理 .................. VersionManager
--   4. 资源清单模块 .............. ResourceManifest
--   5. 更新 UI ................... CreateUpdateUI / SetStatus / SetProgress
--   6. 变更摘要面板 .............. ShowSummary
--   7. 下载管理 .................. DownloadResources / DownloadWithRetry
--   8. 更新管理器 ................ StartUpdateFlow
--   9. 延迟执行工具 .............. DelayedExecute
--  10. 游戏入口 .................. Start / EnterGame / HandleUpdate / Stop
-- ============================================================

require "LuaScripts/Utilities/Sample"
local UI = require("urhox-libs/UI")
local cjson = require("cjson")

-- ========================
--  配置区域（按项目修改）
-- ========================

local Config = {
    --- 云端版本键名（clientCloud score key）
    CLOUD_VERSION_KEY = "game_version",
    --- 本地版本文件名（沙箱内相对路径）
    LOCAL_VERSION_FILE = "update_info.json",
    --- 最低要求版本（低于此版本强制更新，不可跳过）
    MIN_REQUIRED_VERSION = 1,
    --- 下载失败最大重试次数
    MAX_RETRIES = 3,
}

-- ========================
--  资源清单（按版本增量维护）
-- ========================
-- 每个版本只列出该版本新增/变更的资源。
-- 发布新版本时在末尾追加条目即可。

local MANIFEST = {
    [2] = {
        changelog = "新增第2关卡和背景音乐",
        resources = {
            "Textures/Levels/Level2/bg.png",
            "Textures/Levels/Level2/tileset.png",
            "Models/Levels/Level2/terrain.mdl",
            "Sounds/Levels/Level2/bgm.ogg",
        },
    },
    [3] = {
        changelog = "新增Boss战和火焰剑武器",
        resources = {
            "Models/Boss/boss.mdl",
            "Textures/Boss/diffuse.png",
            "Sounds/Boss/battle_bgm.ogg",
            "Models/Weapons/fire_sword.mdl",
        },
    },
    -- 后续版本在此追加:
    -- [4] = { changelog = "...", resources = { ... } },
}

-- ========================
--  版本管理
-- ========================

local VersionManager = {}

--- 读取本地版本号
---@return number
function VersionManager.GetLocalVersion()
    if not fileSystem:FileExists(Config.LOCAL_VERSION_FILE) then
        return 1
    end
    local file = File(Config.LOCAL_VERSION_FILE, FILE_READ)
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
    local file = File(Config.LOCAL_VERSION_FILE, FILE_WRITE)
    file:WriteLine(cjson.encode({
        version = version,
        updatedAt = os.time(),
    }))
    file:Close()
    print("[Update] 本地版本已保存: " .. version)
end

--- 查询云端版本号（异步）
---@param callback fun(success: boolean, version: number)
function VersionManager.GetCloudVersion(callback)
    clientCloud:GetScore(Config.CLOUD_VERSION_KEY, function(success, value)
        if success and value then
            callback(true, value)
        else
            print("[Update] 云端版本查询失败，跳过更新")
            callback(false, 0)
        end
    end)
end

--- 检查是否需要更新（异步）
---@param callback fun(needUpdate: boolean, localVer: number, cloudVer: number)
function VersionManager.CheckUpdate(callback)
    local localVer = VersionManager.GetLocalVersion()
    print("[Update] 本地版本: " .. localVer)

    VersionManager.GetCloudVersion(function(success, cloudVer)
        if success then
            print("[Update] 云端版本: " .. cloudVer)
            callback(cloudVer > localVer, localVer, cloudVer)
        else
            callback(false, localVer, localVer)
        end
    end)
end

-- ========================
--  资源清单
-- ========================

local ResourceManifest = {}

--- 获取 fromVer+1 到 toVer 的所有待更新资源
---@param fromVer number 当前本地版本
---@param toVer number 目标云端版本
---@return string[] resources 需要下载的资源路径列表
---@return string[] changelogs 变更日志列表
function ResourceManifest.GetPendingResources(fromVer, toVer)
    local resources = {}
    local changelogs = {}
    local seen = {}

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

--- 过滤已缓存的资源
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

-- ========================
--  更新 UI
-- ========================

---@type table 保存 UI 组件引用
local uiRefs = {}

--- 创建更新界面
---@param options {forceUpdate?: boolean, onRetry?: function, onSkip?: function}
local function CreateUpdateUI(options)
    uiRefs.statusLabel = UI.Label {
        text = "正在检查更新...",
        fontSize = 18, color = "#FFFFFF",
        marginBottom = 12,
    }

    uiRefs.progressBar = UI.ProgressBar {
        value = 0, max = 100,
        width = "100%", height = 20,
        marginBottom = 8,
    }

    uiRefs.percentLabel = UI.Label {
        text = "0%",
        fontSize = 16, color = "#FFFFFF",
        marginBottom = 12,
    }

    uiRefs.fileLabel = UI.Label {
        text = "",
        fontSize = 14, color = "#AAAAAA",
        marginBottom = 16,
    }

    uiRefs.logPanel = UI.Panel {
        width = "100%", maxHeight = 120,
        backgroundColor = "#00000066",
        borderRadius = 8,
        padding = 8,
        marginBottom = 16,
        children = {},
    }

    -- 按钮
    local buttons = {}
    if not options.forceUpdate and options.onSkip then
        buttons[#buttons + 1] = UI.Button {
            text = "跳过更新",
            variant = "ghost",
            width = 120, height = 40,
            marginRight = 12,
            onClick = function(self) options.onSkip() end,
        }
    end

    uiRefs.retryButton = UI.Button {
        text = "重试",
        variant = "outline",
        width = 120, height = 40,
        visible = false,
        onClick = function(self)
            if options.onRetry then options.onRetry() end
        end,
    }
    buttons[#buttons + 1] = uiRefs.retryButton

    local root = UI.Panel {
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
                    uiRefs.statusLabel,
                    uiRefs.progressBar,
                    uiRefs.percentLabel,
                    uiRefs.fileLabel,
                    uiRefs.logPanel,
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        children = buttons,
                    },
                },
            },
        },
    }

    UI.SetRoot(root)
    uiRefs.root = root
end

local function SetStatus(text)
    if uiRefs.statusLabel then uiRefs.statusLabel:setText(text) end
end

local function SetProgress(percent, fileName)
    if uiRefs.progressBar then uiRefs.progressBar:setValue(percent) end
    if uiRefs.percentLabel then uiRefs.percentLabel:setText(percent .. "%") end
    if uiRefs.fileLabel and fileName then
        uiRefs.fileLabel:setText("下载: " .. fileName)
    end
end

local function AddLog(text)
    if uiRefs.logPanel then
        local label = UI.Label { text = text, fontSize = 12, color = "#88FF88", marginBottom = 2 }
        uiRefs.logPanel:addChild(label)
    end
end

local function ShowRetry()
    if uiRefs.retryButton then uiRefs.retryButton:setVisible(true) end
end

local function HideUpdateUI()
    if uiRefs.root then
        UI.RemoveRoot(uiRefs.root)
        uiRefs = {}
    end
end

-- ========================
--  变更摘要面板
-- ========================

--- 展示更新完成后的变更摘要
---@param changelogs string[]
---@param resourceCount number
---@param onContinue function
local function ShowSummary(changelogs, resourceCount, onContinue)
    HideUpdateUI()

    local logItems = {}
    for _, log in ipairs(changelogs) do
        logItems[#logItems + 1] = UI.Label {
            text = "  " .. log,
            fontSize = 14, color = "#CCCCCC",
            marginBottom = 4,
        }
    end

    local summaryRoot = UI.Panel {
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
                        onClick = function(self)
                            UI.RemoveRoot(summaryRoot)
                            onContinue()
                        end,
                    },
                },
            },
        },
    }

    UI.SetRoot(summaryRoot)
end

-- ========================
--  下载管理（含重试）
-- ========================

--- 执行批量下载
---@param resources string[]
---@param onProgress fun(current: number, total: number, path: string)
---@param onComplete fun(success: boolean, failedCount: number)
local function DownloadResources(resources, onProgress, onComplete)
    if #resources == 0 then
        onComplete(true, 0)
        return
    end

    cache:DownloadResources(
        resources,
        function(current, total, path, success)
            onProgress(current, total, path)
        end,
        function(successCount, totalCount)
            local failedCount = totalCount - successCount
            onComplete(failedCount == 0, failedCount)
        end
    )
end

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
        elseif retryCount < Config.MAX_RETRIES then
            local stillNeeded = {}
            for _, path in ipairs(resources) do
                if not cache:IsResourceCached(path) then
                    stillNeeded[#stillNeeded + 1] = path
                end
            end
            print(string.format("[Update] 重试 (%d/%d)，剩余 %d 个",
                retryCount + 1, Config.MAX_RETRIES, #stillNeeded))
            DownloadWithRetry(stillNeeded, onProgress, onComplete, retryCount + 1)
        else
            onComplete(false)
        end
    end)
end

-- ========================
--  更新管理器（核心协调）
-- ========================

--- 启动更新流程
---@param onFinished fun(success: boolean) 更新完成回调
local function StartUpdateFlow(onFinished)
    -- 步骤 1: 检查版本
    SetStatus("正在检查版本...")
    AddLog("连接云端服务器...")

    VersionManager.CheckUpdate(function(needUpdate, localVer, cloudVer)
        if not needUpdate then
            AddLog("当前已是最新版本 v" .. localVer)
            SetStatus("已是最新版本")
            -- 短暂展示后进入游戏
            DelayedExecute(1.0, function()
                HideUpdateUI()
                onFinished(true)
            end)
            return
        end

        AddLog(string.format("发现新版本: v%d → v%d", localVer, cloudVer))

        -- 检查是否需要强制更新
        local forceUpdate = localVer < Config.MIN_REQUIRED_VERSION
        if forceUpdate then
            AddLog("版本过低，需要强制更新")
        end

        -- 步骤 2: 获取资源清单
        SetStatus("正在分析更新内容...")
        local allResources, changelogs = ResourceManifest.GetPendingResources(localVer, cloudVer)
        local needDownload, cachedCount = ResourceManifest.FilterCached(allResources)

        if cachedCount > 0 then
            AddLog(string.format("已缓存 %d 个资源，跳过下载", cachedCount))
        end

        if #needDownload == 0 then
            -- 所有资源已缓存，直接完成
            VersionManager.SaveLocalVersion(cloudVer)
            AddLog("所有资源已存在，更新完成")
            ShowSummary(changelogs, 0, function()
                onFinished(true)
            end)
            return
        end

        AddLog(string.format("需要下载 %d 个资源", #needDownload))

        -- 步骤 3: 下载资源
        SetStatus("正在下载资源...")
        local totalDownload = #needDownload

        DownloadWithRetry(
            needDownload,
            -- 进度回调
            function(current, total, path)
                local percent = math.floor(current / total * 100)
                SetProgress(percent, path)
                print(string.format("[Update] 下载 %d/%d: %s", current, total, path))
            end,
            -- 完成回调
            function(success)
                if success then
                    -- 步骤 4: 验证并保存
                    SetStatus("正在验证资源...")
                    VersionManager.SaveLocalVersion(cloudVer)
                    AddLog("更新完成\!")
                    print("[Update] 更新成功，版本: " .. cloudVer)

                    ShowSummary(changelogs, totalDownload, function()
                        onFinished(true)
                    end)
                else
                    SetStatus("下载失败，请检查网络")
                    AddLog("部分资源下载失败")
                    ShowRetry()
                    -- 不调用 onFinished，等待用户重试
                end
            end
        )
    end)
end

-- ========================
--  延迟执行工具
-- ========================

---@type {time: number, callback: function}[]
local delayedTasks = {}

--- 延迟执行（在 Update 中驱动）
---@param delay number 秒
---@param callback function
function DelayedExecute(delay, callback)
    delayedTasks[#delayedTasks + 1] = {
        time = delay,
        callback = callback,
    }
end

-- ========================
--  游戏入口
-- ========================

function Start()
    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 判断是否强制更新
    local localVer = VersionManager.GetLocalVersion()
    local forceUpdate = localVer < Config.MIN_REQUIRED_VERSION

    -- 创建更新 UI
    CreateUpdateUI({
        forceUpdate = forceUpdate,
        onRetry = function()
            -- 重试时隐藏重试按钮并重新开始
            if uiRefs.retryButton then uiRefs.retryButton:setVisible(false) end
            StartUpdateFlow(EnterGame)
        end,
        onSkip = function()
            -- 非强制更新可跳过
            print("[Update] 用户跳过更新")
            HideUpdateUI()
            EnterGame(true)
        end,
    })

    -- 启动更新流程
    StartUpdateFlow(EnterGame)
end

--- 进入游戏主逻辑
---@param success? boolean
function EnterGame(success)
    HideUpdateUI()
    print("[Game] 进入游戏\!")

    -- ========================================
    -- 以下是你的游戏初始化代码，替换此占位逻辑
    -- ========================================

    local root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#1a1a2e",
        children = {
            UI.Label {
                text = "游戏已加载",
                fontSize = 32, color = "#FFFFFF",
                marginBottom = 12,
            },
            UI.Label {
                text = "当前版本: v" .. VersionManager.GetLocalVersion(),
                fontSize = 18, color = "#AAAAAA",
            },
        },
    }
    UI.SetRoot(root)
end

--- Update 事件 — 驱动延迟执行
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 处理延迟任务
    local i = 1
    while i <= #delayedTasks do
        local task = delayedTasks[i]
        task.time = task.time - dt
        if task.time <= 0 then
            task.callback()
            table.remove(delayedTasks, i)
        else
            i = i + 1
        end
    end
end

function Stop()
    HideUpdateUI()
end
