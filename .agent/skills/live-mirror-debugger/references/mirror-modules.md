# 镜像模块 API 速查与使用示例

> 本文档是 `live-mirror-debugger` Skill 的参考手册，
> 提供各镜像模块的 API 速查和集成使用示例。

---

## 1. DataMirror — 数据镜像模块

### API 速查

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `FetchSnapshot(keys, onComplete)` | `keys`: string[], `onComplete`: function | void | 从线上拉取云变量快照 |
| `SaveLocal(snapshot, filename)` | `snapshot`: table, `filename`: string | void | 保存快照到本地 JSON |
| `LoadLocal(filename)` | `filename`: string | table 或 nil | 从本地加载快照 |

### 使用示例

```lua
local DataMirror = require("debug.DataMirror")

-- 拉取线上数据
DataMirror.FetchSnapshot({"score", "level", "items", "gold"}, function(snapshot)
    -- 保存到本地
    DataMirror.SaveLocal(snapshot, "debug/player_snapshot.json")
    
    -- 分析数据
    log:Write(LOG_INFO, "Score: " .. tostring(snapshot.score))
    log:Write(LOG_INFO, "Level: " .. tostring(snapshot.level))
end)

-- 离线加载快照
local snapshot = DataMirror.LoadLocal("debug/player_snapshot.json")
if snapshot then
    log:Write(LOG_INFO, "Loaded snapshot with " .. tostring(snapshot.score) .. " score")
end
```

### clientCloud BatchGet 参考

```lua
-- 批量读取多个 key
local batch = clientCloud:BatchGet()
batch:Key("score")
batch:Key("level")
batch:Key("gold")
batch:Fetch({
    onSuccess = function(results)
        -- results 包含所有请求的 key-value
    end,
    onError = function(err)
        log:Write(LOG_ERROR, "BatchGet failed: " .. tostring(err))
    end
})
```

### serverCloud BatchGet 参考（服务端）

```lua
-- 服务端可拉取任意用户数据
local batch = serverCloud:BatchGet(targetUserId)
batch:Key("score")
batch:Key("level")
batch:Fetch({
    onSuccess = function(results)
        -- results 包含目标用户的数据
    end,
    onError = function(err)
        log:Write(LOG_ERROR, "Server BatchGet failed: " .. tostring(err))
    end
})
```

---

## 2. TrafficMirror — 流量镜像模块

### API 速查

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `StartRecording()` | 无 | void | 开始录制操作事件 |
| `RecordEvent(eventName, data)` | `eventName`: string, `data`: table | void | 记录单个事件 |
| `StopRecording()` | 无 | table[] | 停止录制并返回事件日志 |
| `SaveLog(filename)` | `filename`: string | void | 保存事件日志到本地 |
| `LoadAndReplay(filename, handler)` | `filename`: string, `handler`: function | table (replayer) | 加载并创建回放器 |
| `CaptureInputSnapshot()` | 无 | table | 捕获当前帧的输入状态 |

### 录制使用示例

```lua
local TrafficMirror = require("debug.TrafficMirror")

-- 开始录制
TrafficMirror.StartRecording()

-- 在 HandleUpdate 中每帧记录输入状态
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- 记录输入快照
    local inputSnapshot = TrafficMirror.CaptureInputSnapshot()
    TrafficMirror.RecordEvent("input", inputSnapshot)
    
    -- 记录自定义游戏事件
    if playerJumped then
        TrafficMirror.RecordEvent("game_event", { type = "jump", height = jumpHeight })
    end
end

-- 停止录制并保存
local events = TrafficMirror.StopRecording()
TrafficMirror.SaveLog("debug/traffic_replay.json")
```

### 回放使用示例

```lua
local TrafficMirror = require("debug.TrafficMirror")

local replayer = TrafficMirror.LoadAndReplay("debug/traffic_replay.json",
    function(eventName, data)
        if eventName == "input" then
            -- 将回放的输入注入游戏
            log:Write(LOG_DEBUG, "Replayed input: mouseX=" .. data.mouseX)
        elseif eventName == "game_event" then
            log:Write(LOG_DEBUG, "Replayed event: " .. data.type)
        end
    end
)

-- 在 HandleUpdate 中驱动回放
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if replayer and replayer.playing then
        replayer:Update(dt)
    end
end
```

---

## 3. ConfigMirror — 配置镜像模块

### API 速查

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `CaptureRuntimeConfig()` | 无 | table | 捕获当前运行时配置 |
| `SaveConfig(config, filename)` | `config`: table, `filename`: string | void | 保存配置到本地 |
| `CompareWithLocal(filename)` | `filename`: string | table[] (diffs) | 对比远程与本地配置差异 |

### 配置快照格式

```lua
{
    screen = {
        physicalWidth = 2340,    -- 物理分辨率宽
        physicalHeight = 1080,   -- 物理分辨率高
        dpr = 3.0,               -- 设备像素比
        logicalWidth = 780,      -- 逻辑分辨率宽
        logicalHeight = 360,     -- 逻辑分辨率高
    },
    platform = {
        name = "Android",        -- 平台名称
        isMobile = true,
        isWeb = false,
    },
    input = {
        hasTouchscreen = true,
        mouseMode = 0,           -- MM_ABSOLUTE
    },
    capturedAt = "2026-05-14 10:30:00",
}
```

### 差异对比示例

```lua
local ConfigMirror = require("debug.ConfigMirror")

-- 捕获本地配置
local localConfig = ConfigMirror.CaptureRuntimeConfig()
ConfigMirror.SaveConfig(localConfig, "debug/local_config.json")

-- 对比线上配置（从反馈中获取）
local diffs = ConfigMirror.CompareWithLocal("debug/remote_config.json")
if diffs then
    for _, diff in ipairs(diffs) do
        log:Write(LOG_WARNING, "[" .. diff.category .. "." .. diff.field .. "] "
            .. "remote=" .. tostring(diff.remote)
            .. " local=" .. tostring(diff.localVal))
    end
end
```

---

## 4. FeedbackMirror — 反馈镜像模块

### API 速查

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `ExtractConditions(infoPath)` | `infoPath`: string | table 或 nil | 从 info.json 提取复现条件 |
| `PrintConditions(conditions)` | `conditions`: table | void | 打印复现条件摘要 |

### MCP 工具调用参考

通过 UrhoX MCP `get_debug_feedbacks` 工具拉取线上反馈：

```
工具: get_debug_feedbacks
参数:
  - limit: 5              # 拉取最近 5 条
  - fetch_and_mark_processed: true  # 拉取未处理的并标记

返回目录结构:
  logs/feed_back/
  ├── summary.json
  └── feedback_XXXXX/
      ├── info.json        ← FeedbackMirror.ExtractConditions 读取此文件
      ├── description.txt
      ├── logs/
      └── screenshots/
```

### 使用示例

```lua
local FeedbackMirror = require("debug.FeedbackMirror")

-- 从拉取的反馈中提取复现条件
local conditions = FeedbackMirror.ExtractConditions("debug/feedback_info.json")
if conditions then
    FeedbackMirror.PrintConditions(conditions)
    -- 输出:
    -- === Mirror Target Conditions ===
    --   Device:    Xiaomi 14
    --   OS:        Android 14
    --   Version:   1.2.3
    --   Screen:    2340x1080
    --   DPR:       3
    --   Platform:  Android
    -- ================================
end
```

---

## 5. EnvMirror — 环境镜像模块

### API 速查

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `ReadProjectSettings()` | 无 | table | 读取项目运行时配置 |
| `IsMultiplayerMode()` | 无 | boolean | 判断当前是否多人模式 |
| `GenerateDiffReport(remoteEnv)` | `remoteEnv`: table | string | 生成环境差异报告 |

### 使用示例

```lua
local EnvMirror = require("debug.EnvMirror")

-- 检查运行模式
if EnvMirror.IsMultiplayerMode() then
    log:Write(LOG_INFO, "当前为多人模式，需检查服务端日志")
else
    log:Write(LOG_INFO, "当前为单机模式")
end

-- 生成差异报告
local remoteEnv = {
    multiplayer = { enabled = true, max_players = 8 }
}
local report = EnvMirror.GenerateDiffReport(remoteEnv)
-- 输出差异（如本地是单机但线上是多人）
```

---

## 6. Injector — 数据注入模块

### API 速查

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `InjectCloudData(snapshot, gameState)` | `snapshot`: table, `gameState`: table | void | 将快照注入游戏状态 |
| `CreateCloudProxy(snapshot)` | `snapshot`: table | table (proxy) | 创建云变量代理层 |

### 注入使用示例

```lua
local Injector = require("debug.Injector")
local DataMirror = require("debug.DataMirror")

-- 加载线上快照
local snapshot = DataMirror.LoadLocal("debug/player_snapshot.json")

-- 方式 1：直接注入到游戏状态表
local gameState = { score = 0, level = 1, gold = 0 }
Injector.InjectCloudData(snapshot, gameState)
-- gameState 现在包含线上玩家的数据

-- 方式 2：创建代理层（透明替换）
local cloudProxy = Injector.CreateCloudProxy(snapshot)
-- 使用 cloudProxy:Get(key, events) 代替 clientCloud:Get(key, events)
-- 快照中有的 key 直接返回，没有的 fallback 到真实云变量
```

---

## 7. 完整调试会话示例

将所有模块串联的完整调试会话：

```lua
-- scripts/debug/MirrorSession.lua
local DataMirror = require("debug.DataMirror")
local ConfigMirror = require("debug.ConfigMirror")
local EnvMirror = require("debug.EnvMirror")
local FeedbackMirror = require("debug.FeedbackMirror")
local Injector = require("debug.Injector")

local MirrorSession = {}

--- 启动完整镜像调试会话
--- @param feedbackId string 反馈 ID（如 "10001"）
--- @param cloudKeys string[] 要镜像的云变量 key 列表
function MirrorSession.Start(feedbackId, cloudKeys)
    log:Write(LOG_INFO, "=== Mirror Debug Session Started ===")
    
    -- 1. 读取反馈信息
    local infoPath = "debug/feedback_" .. feedbackId .. "_info.json"
    local conditions = FeedbackMirror.ExtractConditions(infoPath)
    if conditions then
        FeedbackMirror.PrintConditions(conditions)
    end
    
    -- 2. 配置对比
    local diffs = ConfigMirror.CompareWithLocal("debug/remote_config.json")
    if diffs and #diffs > 0 then
        log:Write(LOG_WARNING, "Found " .. #diffs .. " config differences\!")
    end
    
    -- 3. 环境检查
    local envReport = EnvMirror.GenerateDiffReport({
        multiplayer = { enabled = conditions and conditions.multiplayer or false }
    })
    
    -- 4. 数据镜像
    DataMirror.FetchSnapshot(cloudKeys, function(snapshot)
        DataMirror.SaveLocal(snapshot, "debug/session_snapshot.json")
        log:Write(LOG_INFO, "=== Mirror Session Ready ===")
        log:Write(LOG_INFO, "Data mirrored, ready for local debugging")
    end)
end

return MirrorSession
```

---

## 8. 常见场景速查

| 场景 | 使用模块 | 关键步骤 |
|------|---------|---------|
| 线上积分异常 | DataMirror + Injector | 拉取快照 → 注入本地 → 对比逻辑 |
| 特定设备 UI 错乱 | ConfigMirror + FeedbackMirror | 提取设备信息 → 对比 DPR/分辨率差异 |
| 操作序列导致崩溃 | TrafficMirror | 录制操作 → 回放复现 → 定位帧 |
| 联网同步失败 | EnvMirror + DataMirror | 检查多人配置 → 对比服务端数据 |
| 玩家反馈闪退 | FeedbackMirror（MCP 工具） | 拉取日志 → 分析崩溃栈 → 本地复现 |
