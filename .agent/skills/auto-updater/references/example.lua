-- =============================================================================
-- Auto-Updater 完整示例
-- 功能：启动时检查云端版本 → 增量下载资源 → 显示更新日志 → 进入游戏
-- 复制到 scripts/main.lua 即可运行
-- =============================================================================

local UI = require("urhox-libs/UI")
local cjson = require("cjson")

-- ===== 配置（根据项目需求修改） =====
local Config = {
    -- 云变量键名
    versionKey    = "content_version",
    minVersionKey = "min_version",
    changelogKey  = "update_changelog",
    resourcesKey  = "update_resources",

    -- 重试策略
    maxRetries   = 3,
    retryDelay   = 2.0,

    -- 定时检查（运行时后台轮询）
    scheduledCheck = {
        enabled      = true,   -- 是否开启运行时定时检查
        interval     = 300,    -- 检查间隔秒（默认 5 分钟，最低 30）
        initialDelay = 60,     -- 首次检查延迟秒（默认 1 分钟）
    },

    -- 行为
    showChangelog = true,
    allowOffline  = true,
}

-- ===== 状态 =====
local localVer = 0
local cloudVer = 0
local updateInfo = {}

---@type UIWidget
local progressBar_ = nil
---@type UIWidget
local statusLabel_ = nil
---@type UIWidget
local root_ = nil

---@type table|nil
local checker_ = nil

-- ===== 工具函数 =====

--- 格式化字节数为可读字符串
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

--- 安全延迟调用（不会影响其他 Update 订阅）
---@param seconds number
---@param callback function
local delayQueue_ = {}
local function delayCall(seconds, callback)
    table.insert(delayQueue_, { remaining = seconds, fn = callback })
end

-- ===== 本地版本缓存 =====

local VERSION_FILE = "update_state.json"

---@return number
local function readLocalVersion()
    if not fileSystem:FileExists(VERSION_FILE) then return 0 end
    local f = File(VERSION_FILE, FILE_READ)
    if not f:IsOpen() then return 0 end
    local content = f:ReadString()
    f:Close()
    local ok, data = pcall(cjson.decode, content)
    return (ok and type(data) == "table") and (data.version or 0) or 0
end

---@param ver number
local function saveLocalVersion(ver)
    local f = File(VERSION_FILE, FILE_WRITE)
    if f:IsOpen() then
        f:WriteString(cjson.encode({ version = ver, timestamp = os.time() }))
        f:Close()
    end
end

-- ===== UI 构建 =====

local function initUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })
end

local function showUpdateScreen()
    statusLabel_ = UI.Label {
        text = "检查更新中...",
        fontSize = 16,
        color = { 200, 200, 200, 255 },
    }
    progressBar_ = UI.ProgressBar {
        value = 0,
        width = 320,
        height = 16,
    }

    root_ = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        flexDirection = "column",
        backgroundColor = { 25, 25, 35, 255 },
        children = {
            UI.Label {
                text = "游戏更新",
                fontSize = 28,
                color = { 255, 255, 255, 255 },
            },
            UI.Spacer { height = 24 },
            progressBar_,
            UI.Spacer { height = 12 },
            statusLabel_,
        },
    }
    UI.SetRoot(root_)
end

local function showForceUpdateScreen(curVer, minVer)
    root_ = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        flexDirection = "column",
        backgroundColor = { 25, 25, 35, 255 },
        children = {
            UI.Label {
                text = "需要更新",
                fontSize = 32,
                color = { 255, 80, 80, 255 },
            },
            UI.Spacer { height = 16 },
            UI.Label {
                text = string.format("当前版本 v%d 已过期，最低要求 v%d", curVer, minVer),
                fontSize = 16,
                color = { 180, 180, 180, 255 },
            },
            UI.Spacer { height = 24 },
            UI.Button {
                text = "立即更新",
                variant = "primary",
                onClick = function(self)
                    showUpdateScreen()
                    startResourceDownload()
                end,
            },
        },
    }
    UI.SetRoot(root_)
end

local function showChangelog(changelogJson, onContinue)
    local ok, entries = pcall(cjson.decode, changelogJson)
    if not ok or type(entries) ~= "table" or #entries == 0 then
        onContinue()
        return
    end

    local logChildren = {}
    for _, entry in ipairs(entries) do
        table.insert(logChildren, UI.Label {
            text = entry.title or ("v" .. (entry.version or "?")),
            fontSize = 18,
            color = { 100, 200, 255, 255 },
        })
        table.insert(logChildren, UI.Spacer { height = 4 })
        if entry.items then
            for _, item in ipairs(entry.items) do
                table.insert(logChildren, UI.Label {
                    text = "  · " .. item,
                    fontSize = 14,
                    color = { 210, 210, 210, 255 },
                })
            end
        end
        table.insert(logChildren, UI.Spacer { height = 10 })
    end

    table.insert(logChildren, UI.Spacer { height = 16 })
    table.insert(logChildren, UI.Button {
        text = "进入游戏",
        variant = "primary",
        onClick = function(self) onContinue() end,
    })

    root_ = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 15, 15, 25, 240 },
        children = {
            UI.Panel {
                width = 380, maxHeight = 480,
                padding = 20,
                backgroundColor = { 35, 35, 50, 255 },
                borderRadius = 10,
                flexDirection = "column",
                children = {
                    UI.Label {
                        text = "更新内容",
                        fontSize = 24,
                        color = { 255, 255, 255, 255 },
                    },
                    UI.Spacer { height = 12 },
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
    UI.SetRoot(root_)
end

-- ===== 运行时定时检查器（内联实现） =====

--- 创建定时版本检查器实例
---@param config table { interval, initialDelay, versionKey, onNewVersion }
---@return table checker
local function createScheduledChecker(config)
    local self = {
        interval      = math.max(30, config.interval or 300),
        initialDelay  = math.max(5, config.initialDelay or 60),
        versionKey    = config.versionKey or "content_version",
        onNewVersion  = config.onNewVersion or function() end,
        elapsed_      = 0,
        enabled_      = true,
        checking_     = false,
        knownVer_     = 0,
        firstCheck_   = true,
        consecutiveFails_ = 0,
    }

    function self:Update(dt)
        if not self.enabled_ or self.checking_ then return end
        self.elapsed_ = self.elapsed_ + dt
        local threshold = self.firstCheck_ and self.initialDelay or self:GetEffectiveInterval()
        if self.elapsed_ < threshold then return end
        self.elapsed_ = 0
        self.firstCheck_ = false
        self:Check()
    end

    function self:GetEffectiveInterval()
        if self.consecutiveFails_ <= 0 then return self.interval end
        local backoff = self.interval * (2 ^ math.min(self.consecutiveFails_, 5))
        return math.min(backoff, 1800)
    end

    function self:Check()
        if self.checking_ then return end
        self.checking_ = true
        print("[ScheduledChecker] Checking cloud version...")

        clientCloud:Get(self.versionKey, {
            ok = function(values, iscores)
                self.checking_ = false
                self.consecutiveFails_ = 0
                local ver = iscores[self.versionKey] or 0
                if ver > self.knownVer_ then
                    self.knownVer_ = ver
                    self.onNewVersion(ver)
                end
            end,
            error = function(code, reason)
                self.checking_ = false
                self.consecutiveFails_ = self.consecutiveFails_ + 1
                print(string.format("[ScheduledChecker] Failed (backoff x%d): %s",
                    self.consecutiveFails_, reason))
            end,
        })
    end

    function self:SetEnabled(enabled)
        self.enabled_ = enabled
        if enabled then self.elapsed_ = 0 end
    end

    function self:SetKnownVersion(ver)
        self.knownVer_ = ver
    end

    function self:Pause()  self.enabled_ = false end
    function self:Resume() self.enabled_ = true; self.elapsed_ = 0 end

    return self
end

--- 显示非侵入式更新 Toast（屏幕右上角）
---@param parentRoot UIWidget 当前 UI 根节点
---@param newVer number 新版本号
---@param onUpdate function 用户点击"更新"时的回调
local function showUpdateToast(parentRoot, newVer, onUpdate)
    ---@type UIWidget
    local toast = nil

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
                text = string.format("发现新版本 v%d", newVer),
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

-- ===== 核心流程 =====

--- 带重试的版本检查
---@param onResult function(info, err)
local function checkVersionWithRetry(onResult)
    local attempt = 0

    local function tryCheck()
        attempt = attempt + 1
        statusLabel_:Set({ text = string.format("检查更新中（%d/%d）...", attempt, Config.maxRetries) })

        clientCloud:BatchGet()
            :Key(Config.versionKey)
            :Key(Config.minVersionKey)
            :Key(Config.changelogKey)
            :Fetch({
                ok = function(values, iscores)
                    onResult({
                        cloudVer  = iscores[Config.versionKey] or 0,
                        minVer    = iscores[Config.minVersionKey] or 0,
                        changelog = values[Config.changelogKey] or "[]",
                    })
                end,
                error = function(code, reason)
                    print(string.format("[AutoUpdater] Check failed (attempt %d): %s", attempt, reason))
                    if attempt >= Config.maxRetries then
                        onResult(nil, reason)
                    else
                        delayCall(Config.retryDelay, tryCheck)
                    end
                end,
            })
    end

    tryCheck()
end

--- 下载资源
function startResourceDownload()
    -- 从云变量获取资源列表，或使用预定义列表
    clientCloud:Get(Config.resourcesKey, {
        ok = function(values, iscores)
            local ok, resourceList = pcall(cjson.decode, values[Config.resourcesKey] or "[]")
            if not ok or #resourceList == 0 then
                -- 无资源列表，直接标记完成
                saveLocalVersion(cloudVer)
                enterGame()
                return
            end

            local startTime = os.clock()
            local totalBytes = 0

            cache:DownloadResources(resourceList,
                function(success, failedCount)
                    local elapsed = os.clock() - startTime

                    if success then
                        saveLocalVersion(cloudVer)

                        -- 打印更新摘要
                        print("========== 更新摘要 ==========")
                        print(string.format("版本: v%d → v%d", localVer, cloudVer))
                        print(string.format("资源数: %d 个文件", #resourceList))
                        print(string.format("下载量: %s", formatBytes(totalBytes)))
                        print(string.format("耗时: %.1f 秒", elapsed))
                        print("==============================")

                        statusLabel_:Set({ text = "更新完成！" })
                        delayCall(0.5, function()
                            if Config.showChangelog and updateInfo.changelog then
                                showChangelog(updateInfo.changelog, enterGame)
                            else
                                enterGame()
                            end
                        end)
                    else
                        statusLabel_:Set({
                            text = string.format("更新失败（%d 个资源未下载）", failedCount),
                        })
                    end
                end,
                function(completed, total, downloadedBytes, totalBytesAll)
                    totalBytes = totalBytesAll
                    local pct = total > 0 and completed / total or 0
                    progressBar_:Set({ value = pct })
                    statusLabel_:Set({
                        text = string.format("下载中 %d/%d (%s)",
                            completed, total, formatBytes(downloadedBytes)),
                    })
                end
            )
        end,
        error = function(code, reason)
            print("[AutoUpdater] Failed to get resource list:", reason)
            statusLabel_:Set({ text = "获取资源列表失败" })
        end,
    })
end

--- 进入游戏主场景
function enterGame()
    print("[AutoUpdater] Entering game...")
    -- 清理更新 UI
    CreateGameScene()

    -- 启动运行时定时检查
    local sc = Config.scheduledCheck
    if sc and sc.enabled then
        checker_ = createScheduledChecker({
            interval     = sc.interval,
            initialDelay = sc.initialDelay,
            versionKey   = Config.versionKey,
            onNewVersion = function(newVer)
                print(string.format("[ScheduledChecker] New version v%d found\!", newVer))
                if root_ then
                    showUpdateToast(root_, newVer, function()
                        -- 停止定时检查，开始下载
                        if checker_ then checker_:SetEnabled(false) end
                        showUpdateScreen()
                        cloudVer = newVer
                        startResourceDownload()
                    end)
                end
            end,
        })
        -- 设置已知版本，避免重复通知启动时已处理的版本
        checker_:SetKnownVersion(cloudVer)
        print(string.format("[ScheduledChecker] Started (interval=%ds, delay=%ds)",
            sc.interval, sc.initialDelay))
    end
end

-- ===== 游戏场景（占位，替换为实际游戏逻辑） =====

function CreateGameScene()
    root_ = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 40, 80, 60, 255 },
        children = {
            UI.Label {
                text = string.format("游戏已加载（v%d）", cloudVer),
                fontSize = 24,
                color = { 255, 255, 255, 255 },
            },
        },
    }
    UI.SetRoot(root_)
end

-- ===== 引擎入口 =====

function Start()
    initUI()
    showUpdateScreen()

    localVer = readLocalVersion()

    checkVersionWithRetry(function(info, err)
        if not info then
            if Config.allowOffline then
                statusLabel_:Set({ text = "网络不可用，使用本地版本" })
                delayCall(1.5, enterGame)
            else
                statusLabel_:Set({ text = "网络不可用，无法启动游戏" })
            end
            return
        end

        updateInfo = info
        cloudVer = info.cloudVer

        -- 强制更新检查
        if localVer < info.minVer then
            showForceUpdateScreen(localVer, info.minVer)
            return
        end

        -- 增量更新
        if info.cloudVer > localVer then
            statusLabel_:Set({ text = "发现新版本，准备下载..." })
            delayCall(0.5, startResourceDownload)
        else
            statusLabel_:Set({ text = "已是最新版本" })
            delayCall(1.0, enterGame)
        end
    end)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 处理延迟调用队列
    local i = 1
    while i <= #delayQueue_ do
        local item = delayQueue_[i]
        item.remaining = item.remaining - dt
        if item.remaining <= 0 then
            table.remove(delayQueue_, i)
            item.fn()
        else
            i = i + 1
        end
    end

    -- 运行时定时检查
    if checker_ then
        checker_:Update(dt)
    end
end

SubscribeToEvent("Update", "HandleUpdate")
