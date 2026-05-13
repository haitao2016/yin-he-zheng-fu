---
name: auto-updater
description: >-
  UrhoX Lua 游戏内容自动更新系统实现指南。提供版本检查（clientCloud 云变量）、
  资源增量下载（DWP API）、更新进度 UI（UrhoX UI 组件）、更新日志展示的完整方案。
  Use when users need to (1) 实现游戏启动时自动检查更新,
  (2) 增量下载新版本资源（贴图/模型/音频/关卡）,
  (3) 显示下载进度条和更新日志,
  (4) 版本号管理与云端同步,
  (5) 强制更新拦截（版本过低禁止进入游戏）,
  (6) 用户说"自动更新"、"热更新"、"版本检查"、"资源下载"、"增量更新",
  (7) auto update, version check, resource download, patch system,
  (8) 边玩边下的更新策略, (9) 更新完成后的变更摘要报告,
  (10) 运行时定时检查更新、后台轮询版本、游戏内自动检测新版本,
  (11) 用户说"定时检查"、"定期检查"、"scheduled check"、"periodic update"。
---

# Auto-Updater — UrhoX Lua 游戏内容自动更新系统

> 在游戏启动时检查云端版本、增量下载新资源、展示更新进度与变更日志。
>
> - 完整实现模式 → `references/implementation-guide.md`
> - 可运行示例 → `references/example.lua`

---

## 架构总览

```
┌─────────────┐    clientCloud     ┌──────────────┐
│  Game Start  │ ──── Get() ────▶  │  Cloud Store  │
│  (Client)    │ ◀── version ────  │  (iscores)    │
└──────┬──────┘                    └──────────────┘
       │
       │ compare localVer vs cloudVer
       │
  ┌────▼────┐  YES   ┌────────────────────┐
  │ Need     │──────▶│  Download Resources │
  │ Update?  │       │  (DWP batch API)    │
  └────┬────┘       └─────────┬──────────┘
       │ NO                    │ progress callback
       │                      ▼
       │              ┌────────────────┐
       │              │  Update UI      │
       │              │  (ProgressBar)  │
       │              └────────┬───────┘
       │                       │ complete
       ▼                       ▼
  ┌──────────────────────────────┐
  │       Enter Game Scene        │
  └──────────────────────────────┘
```

---

## 核心概念

### 1. 版本追踪

使用 `clientCloud` 存储版本号（iscores 表，整数，可排序）：

```lua
-- 写入版本号（发布新版本时由开发者设置）
clientCloud:SetInt("content_version", 2, {
    ok = function() print("Version saved") end,
    error = function(code, reason) print("Error:", reason) end,
})

-- 读取版本号（游戏启动时检查）
clientCloud:Get("content_version", {
    ok = function(values, iscores)
        local cloudVer = iscores.content_version or 0
        -- 与本地版本比较
    end,
})
```

本地版本缓存使用 `File` API（注意 WASM 刷新会丢失）：

```lua
local function readLocalVersion()
    if not fileSystem:FileExists("update_state.json") then return 0 end
    local f = File("update_state.json", FILE_READ)
    if not f:IsOpen() then return 0 end
    local ok, data = pcall(cjson.decode, f:ReadString())
    f:Close()
    return ok and data.version or 0
end

local function saveLocalVersion(ver)
    local f = File("update_state.json", FILE_WRITE)
    if f:IsOpen() then
        f:WriteString(cjson.encode({ version = ver, timestamp = os.time() }))
        f:Close()
    end
end
```

### 2. 资源下载模式

| 模式 | API | 适用场景 |
|------|-----|---------|
| **批量预下载** | `cache:DownloadResources(refs, onComplete, onProgress)` | 启动时下载全部新资源 |
| **单资源异步** | `cache:GetResourceAsync(type, uri, callback)` | 边玩边下，按需加载 |
| **全局观察** | `cache:ObserveDownloads(onProgress, onComplete)` | 监控所有下载进度 |

### 3. 更新流程模式

**模式 A: 启动强制更新（推荐）**
- 启动时检查版本 → 有更新则显示进度界面 → 下载完成进入游戏
- 适用于：版本间资源变化较大，需要完整下载

**模式 B: 后台静默更新**
- 启动时检查版本 → 直接进入游戏 → 后台下载新资源
- 适用于：增量较小，DWP 热替换即可

**模式 C: 强制更新拦截**
- 启动时检查最低版本 → 低于阈值禁止进入 → 必须更新后才能游戏
- 适用于：包含破坏性变更的大版本

**模式 D: 运行时定时检查（灵感源自 clawhub auto-updater cron 机制）**
- 游戏运行期间按可配置间隔（默认 300 秒）后台轮询云端版本
- 发现新版本时弹出非侵入式通知（Toast），玩家自主决定是否更新
- 适用于：长时间运行的游戏（MMO、沙盒、挂机类），玩家可能连续玩数小时
- 关键约束：不使用 while 循环或 cron，基于 HandleUpdate 累计 dt 计时

---

## 实现骨架（约 70 行）

```lua
local UI = require("urhox-libs/UI")
local cjson = require("cjson")

-- ===== 配置 =====
local UPDATE_KEY = "content_version"    -- 云变量键名
local RESOURCE_LIST_KEY = "update_resources"  -- 资源列表键名

-- ===== 状态 =====
local localVer = 0
local cloudVer = 0
---@type UIWidget
local progressBar = nil
---@type UIWidget
local statusLabel = nil

-- ===== 版本检查 =====
local function checkVersion(onResult)
    localVer = readLocalVersion()  -- 见上方 readLocalVersion
    clientCloud:Get(UPDATE_KEY, {
        ok = function(values, iscores)
            cloudVer = iscores[UPDATE_KEY] or 0
            onResult(cloudVer > localVer)
        end,
        error = function(code, reason)
            print("[AutoUpdater] Cloud check failed:", reason)
            onResult(false)  -- 失败时跳过更新
        end,
    })
end

-- ===== 资源下载 =====
local function downloadResources(resourceRefs, onDone)
    cache:DownloadResources(resourceRefs,
        function(success, failedCount)
            if success then
                saveLocalVersion(cloudVer)
                statusLabel:Set({ text = "更新完成！" })
            else
                statusLabel:Set({ text = string.format("更新失败（%d 个资源）", failedCount) })
            end
            onDone(success)
        end,
        function(completed, total, downloadedBytes, totalBytes)
            local pct = total > 0 and completed / total or 0
            progressBar:Set({ value = pct })
            statusLabel:Set({ text = string.format("下载中 %d/%d", completed, total) })
        end
    )
end

-- ===== 更新界面 =====
local function showUpdateScreen()
    UI.Init({
        fonts = {{ family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }},
        scale = UI.Scale.DEFAULT,
    })

    statusLabel = UI.Label { text = "检查更新中...", fontSize = 18, color = {255,255,255,255} }
    progressBar = UI.ProgressBar { value = 0, width = 300, height = 20 }

    local root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 30, 30, 30, 255 },
        children = {
            UI.Label { text = "游戏更新", fontSize = 28, color = {255,255,255,255} },
            UI.Spacer { height = 20 },
            progressBar,
            UI.Spacer { height = 10 },
            statusLabel,
        }
    }
    UI.SetRoot(root)
end
```

---

## 运行时定时检查（模式 D 实现骨架）

基于 HandleUpdate 的 dt 累加实现定时轮询，不依赖 cron 或 while 循环。

### 核心模块：ScheduledChecker

```lua
--- scripts/ScheduledChecker.lua
local cjson = require("cjson")

local ScheduledChecker = {}

--- 创建定时检查器
---@param config table 配置项
---@return table checker 检查器实例
function ScheduledChecker.Create(config)
    local checker = {
        -- 配置（秒）
        interval      = config.interval or 300,     -- 检查间隔，默认 5 分钟
        initialDelay  = config.initialDelay or 60,   -- 首次检查延迟，默认 1 分钟
        versionKey    = config.versionKey or "content_version",
        onNewVersion  = config.onNewVersion or function() end,

        -- 内部状态
        elapsed_      = 0,
        enabled_      = true,
        checking_     = false,  -- 防止并发请求
        knownVer_     = 0,      -- 已知的最新版本（避免重复通知）
        checkCount_   = 0,      -- 检查次数统计
        firstCheck_   = true,   -- 是否首次检查（使用 initialDelay）
    }

    --- 每帧调用（在 HandleUpdate 中调用）
    ---@param dt number 帧间隔
    function checker:Update(dt)
        if not self.enabled_ or self.checking_ then return end

        self.elapsed_ = self.elapsed_ + dt
        local threshold = self.firstCheck_ and self.initialDelay or self.interval

        if self.elapsed_ < threshold then return end
        self.elapsed_ = 0
        self.firstCheck_ = false
        self:Check()
    end

    --- 手动触发一次检查
    function checker:Check()
        if self.checking_ then return end
        self.checking_ = true
        self.checkCount_ = self.checkCount_ + 1

        clientCloud:Get(self.versionKey, {
            ok = function(values, iscores)
                self.checking_ = false
                local cloudVer = iscores[self.versionKey] or 0

                if cloudVer > self.knownVer_ then
                    self.knownVer_ = cloudVer
                    self.onNewVersion(cloudVer, self.checkCount_)
                end
            end,
            error = function(code, reason)
                self.checking_ = false
                print("[ScheduledChecker] Check failed:", reason)
            end,
        })
    end

    --- 暂停/恢复
    function checker:SetEnabled(enabled)
        self.enabled_ = enabled
        if enabled then self.elapsed_ = 0 end
    end

    --- 修改检查间隔
    function checker:SetInterval(seconds)
        self.interval = math.max(30, seconds)  -- 最低 30 秒
    end

    return checker
end

return ScheduledChecker
```

### 集成方式

```lua
local ScheduledChecker = require("ScheduledChecker")

local checker_ = nil

function Start()
    -- ... 启动时的常规版本检查 ...

    -- 创建定时检查器（游戏进入主场景后启动）
    checker_ = ScheduledChecker.Create({
        interval     = 300,   -- 每 5 分钟检查一次
        initialDelay = 60,    -- 启动后 1 分钟首次检查
        versionKey   = "content_version",
        onNewVersion = function(newVer, checkCount)
            showUpdateToast(newVer)
        end,
    })
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 定时检查器计时
    if checker_ then
        checker_:Update(dt)
    end
end

--- 非侵入式更新通知（Toast 风格）
function showUpdateToast(newVer)
    -- 使用 UI 组件显示顶部横幅
    local toast = UI.Panel {
        position = "absolute",
        top = 10, right = 10,
        width = 280, padding = 12,
        backgroundColor = { 40, 120, 200, 230 },
        borderRadius = 8,
        flexDirection = "row",
        alignItems = "center",
        children = {
            UI.Label {
                text = string.format("发现新版本 v%d", newVer),
                fontSize = 14, color = { 255, 255, 255, 255 },
                flexGrow = 1,
            },
            UI.Button {
                text = "更新",
                variant = "primary",
                onClick = function(self)
                    checker_:SetEnabled(false)  -- 停止检查
                    startResourceDownload()     -- 开始下载
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
    }
    -- 添加到当前 UI 根节点
end
```

### 定时策略选择

| 场景 | interval | initialDelay | 说明 |
|------|----------|-------------|------|
| MMO/长时间在线 | 300 (5分钟) | 60 | 频繁检查，及时推送 |
| 休闲/单局制 | 600 (10分钟) | 120 | 适度检查，不干扰 |
| 挂机/放置类 | 900 (15分钟) | 180 | 低频检查，省流量 |
| 暂停时停止 | — | — | `checker:SetEnabled(false/true)` |

### 注意事项

| 要点 | 说明 |
|------|------|
| **不用 while/cron** | UrhoX 无 cron，用 HandleUpdate + dt 累加 |
| **防并发** | `checking_` 标志防止上次请求未返回时重复发起 |
| **防重复通知** | `knownVer_` 记录已通知版本，同一版本只通知一次 |
| **最低间隔 30 秒** | 防止过于频繁的云端请求 |
| **暂停场景** | 游戏暂停、设置界面打开时应 `SetEnabled(false)` |
| **网络失败静默** | 定时检查失败只打日志，不弹 UI，不影响游戏 |


## API 速查

| API | 用途 | 注意事项 |
|-----|------|---------|
| `clientCloud:Get(key, events)` | 读取云端版本号 | 回调异步，不可阻塞 |
| `clientCloud:SetInt(key, val, events)` | 写入版本号 | 仅整数，iscores 表 |
| `cache:DownloadResources(refs, onComplete, onProgress)` | 批量下载资源 | refs 为 URI 数组 |
| `cache:GetResourceAsync(type, uri, cb)` | 单资源异步加载 | 加载完后回调 |
| `cache:ObserveDownloads(onProgress, onComplete)` | 全局下载观察 | 自动或手动停止 |
| `cache:GetDownloadState(uri)` | 查询下载状态 | 返回枚举值 |
| `cache:Exists(uri)` | 检查资源是否本地存在 | 不触发下载 |
| `cache:GetResRefs(uri, includeSelf)` | 获取递归依赖列表 | 用于依赖预加载 |
| `File(path, mode)` | 本地文件读写 | WASM 刷新丢数据 |
| `UI.ProgressBar` | 进度条控件 | value 范围 0-1 |

---

## 约束（UrhoX 特有）

| 约束 | 说明 | 替代方案 |
|------|------|---------|
| 客户端无 HTTP 请求 | 不可使用 `http.get()` | 用 `clientCloud` API |
| `io` 库不存在 | 沙箱已移除 | 用 `File` API |
| WASM 本地文件刷新丢失 | 内存文件系统 | 关键数据用 `clientCloud` |
| 无轮询循环 | 不可 `while true` 等待 | 用回调模式 |
| 服务端文件操作禁用 | File/FileSystem 返回 nil | 存档逻辑放客户端 |

---

## 参考文件

| 文件 | 内容 | 何时阅读 |
|------|------|---------|
| `references/implementation-guide.md` | 8 种详细实现模式、错误处理、重试、配置 | 需要完整实现时 |
| `references/example.lua` | 可运行的完整示例（约 300 行） | 快速开始时直接复制到 scripts/ |
