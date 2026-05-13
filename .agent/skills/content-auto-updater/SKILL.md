---
name: content-auto-updater
description: >-
  UrhoX Lua 游戏内容自动更新系统实现指南。提供版本检查（clientCloud 云变量）、
  资源增量下载（DWP API）、更新进度 UI（UrhoX UI 组件）、更新日志展示的完整方案。
  Use when users need to (1) 实现游戏启动时自动检查更新, (2) 增量下载新版本资源（贴图/模型/音频/关卡）,
  (3) 显示下载进度条和更新日志, (4) 版本号管理与云端同步,
  (5) 强制更新拦截（版本过低禁止进入游戏）, (6) 用户说"自动更新"、"热更新"、"版本检查"、"资源下载"、"增量更新",
  (7) auto update, version check, resource download, patch system,
  (8) 边玩边下的更新策略, (9) 更新完成后的变更摘要报告。
---

# 游戏内容自动更新系统

> **用途**：在游戏启动时自动检查版本、增量下载新资源、显示更新进度、生成变更摘要。

---

## 触发条件

- 用户需要实现游戏启动时的自动版本检查
- 用户需要增量下载新版本资源（贴图、模型、音频、关卡数据）
- 用户需要显示下载进度条和更新日志
- 用户需要强制更新拦截（版本过低时阻止进入游戏）
- 用户提到"自动更新"、"版本检查"、"资源下载"、"增量更新"、"patch"

### SKIP when

- 仅需开发时热重载 → 使用现有 `auto-updater` skill（touch trigger 机制）
- 仅需边玩边下的透明加载 → 直接使用 DWP 自动模式（无需版本管理）
- 仅需云端存档/排行榜 → 使用 `clientCloud` API

---

## 核心架构

### 更新流程（四步）

```
游戏启动
  ↓
步骤 1: 版本检查
  读取本地版本 → 查询云端版本（clientCloud）→ 比较
  ↓
步骤 2: 资源清单对比
  获取更新资源列表 → 过滤已缓存资源
  ↓
步骤 3: 增量下载
  调用 cache:DownloadResources() → 显示进度 UI
  ↓
步骤 4: 验证与报告
  校验下载结果 → 更新本地版本号 → 显示变更摘要 → 进入游戏
```

### 技术选型

| 功能 | UrhoX API | 说明 |
|------|-----------|------|
| 版本存储 | `clientCloud:GetScore` / `SetScore` | 云变量存储版本号 |
| 资源下载 | `cache:DownloadResources()` | 批量下载 + 进度回调 |
| 资源检查 | `cache:IsResourceCached()` | 检查资源是否已在本地 |
| 本地存储 | `File` + `cjson` | 保存本地版本号和更新日志 |
| 进度 UI | `urhox-libs/UI` | Panel/ProgressBar/Label 组件 |
| 事件监听 | `SubscribeToEvent` | 监听 `ResourceDownloaded` 事件 |

---

## 核心规则

### 规则 1: 版本号使用整数

版本号用整数存储在 clientCloud 中，方便数值比较：

```lua
-- 云端版本号（由开发者通过服务端更新）
-- 键名: "game_version"
-- 值: 整数（如 1, 2, 3... 每次发布递增）

-- 本地版本号保存在文件中
local localVersion = LoadLocalVersion()  -- 从 "update_info.json" 读取

clientCloud:GetScore("game_version", function(success, cloudVersion)
    if success and cloudVersion > localVersion then
        -- 需要更新
        StartUpdate(localVersion, cloudVersion)
    else
        -- 已是最新，直接进入游戏
        EnterGame()
    end
end)
```

### 规则 2: 资源清单按版本组织

将每个版本的新增/变更资源列表硬编码为 Lua table 或存储在配置文件中：

```lua
local VERSION_RESOURCES = {
    [2] = {
        changelog = "新增第2关卡",
        resources = {
            "Textures/Levels/Level2/bg.png",
            "Models/Levels/Level2/terrain.mdl",
        },
    },
    [3] = {
        changelog = "新增Boss战",
        resources = {
            "Models/Boss.mdl",
            "Textures/Boss_diffuse.png",
            "Sounds/boss_bgm.ogg",
        },
    },
}
```

### 规则 3: 使用 DWP 手动下载 API

增量下载必须使用 `cache:DownloadResources()` 的进度回调模式：

```lua
cache:DownloadResources(
    resourceList,
    function(current, total, path, success)
        -- 更新进度条
        local percent = math.floor(current / total * 100)
        UpdateProgressUI(percent, path)
    end,
    function(successCount, totalCount)
        if successCount == totalCount then
            OnUpdateComplete()
        else
            OnUpdateFailed(totalCount - successCount)
        end
    end
)
```

### 规则 4: 本地版本号用 File 持久化

```lua
local cjson = require("cjson")

local function SaveLocalVersion(version)
    local file = File("update_info.json", FILE_WRITE)
    file:WriteLine(cjson.encode({ version = version }))
    file:Close()
end

local function LoadLocalVersion()
    if not fileSystem:FileExists("update_info.json") then
        return 1  -- 默认版本
    end
    local file = File("update_info.json", FILE_READ)
    local content = file:ReadLine()
    file:Close()
    local data = cjson.decode(content)
    return data.version or 1
end
```

### 规则 5: 强制更新使用最低版本阈值

```lua
local MIN_REQUIRED_VERSION = 2  -- 低于此版本必须更新

local function CheckForceUpdate(localVer)
    if localVer < MIN_REQUIRED_VERSION then
        ShowForceUpdateUI()  -- 禁止跳过
        return true
    end
    return false
end
```

---

## 标准流程

### 1. 创建更新管理器模块

```lua
-- scripts/UpdateManager.lua
local UpdateManager = {}

function UpdateManager.Init(onComplete)
    -- 读取本地版本 → 查询云端 → 对比 → 下载 → 验证
end

function UpdateManager.GetPendingResources(fromVer, toVer)
    -- 合并 fromVer+1 到 toVer 的所有资源列表
end

function UpdateManager.StartDownload(resources, progressCb, completeCb)
    -- 过滤已缓存 → 调用 cache:DownloadResources()
end

return UpdateManager
```

### 2. 创建更新 UI

使用 `urhox-libs/UI` 组件构建更新界面：
- 版本信息标签
- 进度条（ProgressBar）
- 当前下载文件名
- 更新日志列表
- "跳过" / "重试" 按钮

### 3. 集成到游戏入口

```lua
function Start()
    UI.Init({ ... })
    local UpdateManager = require("UpdateManager")
    UpdateManager.Init(function(success)
        if success then
            EnterGame()  -- 更新完成或已是最新
        end
    end)
end
```

---

## 常见错误

| 错误 | 正确做法 | 原因 |
|------|---------|------|
| 用 `io.open` 保存版本号 | 用 `File` 对象 | UrhoX 沙箱环境无 `io` 库 |
| 版本号用字符串 "1.2.3" | 用整数 1, 2, 3 | clientCloud 存储数值类型，整数便于比较 |
| 在 Update 循环中轮询版本 | 仅在 Start 时查询一次 | 避免频繁网络请求 |
| 下载失败直接崩溃 | 提供重试按钮和降级方案 | 网络不可靠，需要容错 |
| 手动拼 HTTP 请求 | 用 `cache:DownloadResources()` | 客户端无 HTTP 库，使用引擎内置 API |
| 跳过资源缓存检查直接下载 | 先用 `IsResourceCached` 过滤 | 避免重复下载已有资源 |

---

## 检查清单

- [ ] 版本号使用整数并存储在 clientCloud
- [ ] 本地版本号通过 `File` 持久化（非 `io` 库）
- [ ] 资源下载使用 `cache:DownloadResources()` 的回调模式
- [ ] 下载前用 `cache:IsResourceCached()` 过滤已有资源
- [ ] 更新 UI 使用 `urhox-libs/UI` 组件（非原生 UI）
- [ ] 网络失败提供重试机制
- [ ] 强制更新场景阻止用户跳过
- [ ] 更新完成后保存新版本号到本地
- [ ] 更新日志展示本次变更内容

---

## 与其他功能的关系

| 功能 | 关系 | 说明 |
|------|------|------|
| DWP 自动加载 | 互补 | DWP 处理透明的资源缺失；本系统处理有版本概念的主动更新 |
| auto-updater skill | 完全不同 | auto-updater 是开发时热重载；本系统是发布后的内容更新 |
| clientCloud | 依赖 | 使用 clientCloud 存储和查询版本号 |
| UI 组件库 | 依赖 | 使用 UI 组件构建更新进度界面 |

---

## 参考文件

| 文件 | 内容 | 何时阅读 |
|------|------|---------|
| `references/implementation-guide.md` | 完整实现步骤、模块设计、UI 构建细节 | 需要编写完整更新系统时 |
| `references/example.lua` | 可直接运行的完整更新系统示例 | 需要快速集成更新功能时 |

### 引擎文档参考

- 资源下载 API → `engine-docs/recipes/download-while-playing.md`
- 云变量 API → `engine-docs/recipes/client-cloud-score.md`
- 本地文件读写 → `engine-docs/recipes/file-storage.md`
- UI 组件库 → `engine-docs/recipes/ui.md`
