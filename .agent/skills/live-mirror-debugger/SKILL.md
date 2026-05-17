---
name: live-mirror-debugger
description: >-
  UrhoX 游戏线上环境镜像调试系统，灵感源自 mirrord（本地进程镜像远程 K8s 环境）。
  将线上/测试环境的运行状态（云变量、玩家数据、网络事件、配置、调试反馈）
  镜像到本地开发环境，实现"不发布新版本即可在本地调试线上问题"。
  覆盖五大镜像通道：数据镜像（云变量快照）、流量镜像（网络事件回放）、
  配置镜像（远程配置同步）、反馈镜像（线上 Bug 报告拉取）、
  环境镜像（运行模式/平台状态复现），以及镜像数据的本地注入与还原机制。
  不替代 game-debugging（专注代码级 Bug 排查）或 multiplayer-game（专注联网架构设计），
  而是作为"线上到本地"的桥梁——让开发者在本地精确复现线上状态进行调试。
use_when: >-
  Use when users need to
  (1) 在本地调试线上/测试服才能复现的 Bug,
  (2) 需要把线上玩家的云变量/存档数据拉到本地分析,
  (3) 用户说"线上 Bug""本地复现""镜像线上环境""同步线上数据",
  (4) 需要回放线上玩家的操作序列或网络事件来定位问题,
  (5) 用户说"mirrord""mirror debug""环境镜像""线上调试",
  (6) 需要将线上的运行配置和设备信息同步到本地开发环境,
  (7) 用户说"拉取反馈""查看线上日志""线上崩溃""远程调试",
  (8) 需要在不发布新版本的情况下验证 Bug 修复是否有效。
trigger_keywords:
  - 线上 Bug
  - 本地复现
  - 镜像线上环境
  - 同步线上数据
  - mirrord
  - mirror debug
  - 环境镜像
  - 线上调试
  - 拉取反馈
  - 线上日志
  - 线上崩溃
  - 远程调试
  - 镜像调试
  - 复现问题
  - 线上数据
  - 云变量调试
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  source: "https://github.com/metalbear-co/mirrord"
  tags: [debugging, mirroring, live-environment, cloud-variables, remote-debug, traffic-replay]
---

# Live Mirror Debugger — 线上环境镜像调试系统

## §1 身份与定位

你是 **线上环境镜像调试员**（Live Environment Mirror Debugger）。你的职责是帮助开发者
将线上/测试环境的运行状态"镜像"到本地开发环境，实现精确复现和快速调试。

### 核心理念（源自 mirrord）

mirrord 的核心思想是：**在本地运行进程，但镜像远程环境的上下文**——流量、文件、
环境变量——让开发者无需部署就能在真实环境中调试。

本 Skill 将这一理念适配到 UrhoX 游戏开发：

```
mirrord 概念                    UrhoX 适配
─────────────────────────────────────────────────────
镜像入站流量（K8s Pod）    →    镜像线上玩家操作/网络事件
镜像出站流量               →    通过线上云变量 API 读写数据
镜像文件读写               →    镜像线上配置/存档快照
镜像环境变量               →    镜像运行时配置/设备/平台信息
不部署即可调试             →    不发布新版本即可本地复现线上 Bug
```

### 与现有 Skill 的关系

```
live-mirror-debugger（本 Skill）
│
│  上游：获取线上环境数据
│  ├── get_debug_feedbacks     — 拉取线上玩家反馈/日志/截图
│  ├── clientCloud / serverCloud — 读取线上云变量快照
│  └── .project/settings.json  — 读取运行时配置
│
│  下游：注入本地环境后调试
│  ├→ game-debugging           — 代码级 Bug 排查（本 Skill 提供数据，它提供方法）
│  ├→ multiplayer-game         — 联网架构参考（本 Skill 处理联网环境的镜像）
│  └→ device-adaptation-bug-fixer — 设备适配问题（本 Skill 提供设备信息复现）
```

---

## §2 五大镜像通道

### 2.1 数据镜像（Data Mirror）— 云变量快照

**对应 mirrord 的：文件读写镜像 + 环境变量镜像**

将线上玩家的云变量数据拉取到本地，用于复现数据相关 Bug。

#### 客户端云变量快照

```lua
-- scripts/debug/DataMirror.lua
local DataMirror = {}

--- 从线上拉取指定玩家的云变量快照
--- @param keys string[] 要拉取的云变量 key 列表
--- @param onComplete function 回调函数(snapshot)
function DataMirror.FetchSnapshot(keys, onComplete)
    local snapshot = {}
    local pending = #keys
    
    local batch = clientCloud:BatchGet()
    for _, key in ipairs(keys) do
        batch:Key(key)
    end
    batch:Fetch({
        onSuccess = function(results)
            for _, key in ipairs(keys) do
                snapshot[key] = results[key]
            end
            log:Write(LOG_INFO, "[DataMirror] Snapshot fetched: " .. #keys .. " keys")
            if onComplete then onComplete(snapshot) end
        end,
        onError = function(err)
            log:Write(LOG_ERROR, "[DataMirror] Fetch failed: " .. tostring(err))
        end
    })
end

--- 将快照保存为本地 JSON 文件（用于离线分析）
--- @param snapshot table 云变量快照
--- @param filename string 保存路径（如 "debug/snapshot_20260514.json"）
function DataMirror.SaveLocal(snapshot, filename)
    local cjson = require("cjson")
    local json = cjson.encode(snapshot)
    
    local file = File:new(filename, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
        log:Write(LOG_INFO, "[DataMirror] Snapshot saved: " .. filename)
    else
        log:Write(LOG_ERROR, "[DataMirror] Cannot write: " .. filename)
    end
end

--- 从本地 JSON 加载快照
--- @param filename string JSON 文件路径
--- @return table|nil snapshot
function DataMirror.LoadLocal(filename)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_READ)
    if file:IsOpen() then
        local json = file:ReadString()
        file:Close()
        local snapshot = cjson.decode(json)
        log:Write(LOG_INFO, "[DataMirror] Snapshot loaded: " .. filename)
        return snapshot
    end
    log:Write(LOG_WARNING, "[DataMirror] File not found: " .. filename)
    return nil
end

return DataMirror
```

#### 服务端云变量快照（联网游戏）

```lua
-- scripts/debug/ServerDataMirror.lua（服务端脚本）
local ServerDataMirror = {}

--- 拉取指定用户的全量云变量（服务端权限）
--- @param userId string 目标用户 ID
--- @param keys string[] 要拉取的 key 列表
--- @param onComplete function 回调函数(snapshot)
function ServerDataMirror.FetchUserData(userId, keys, onComplete)
    local batch = serverCloud:BatchGet(userId)
    for _, key in ipairs(keys) do
        batch:Key(key)
    end
    batch:Fetch({
        onSuccess = function(results)
            log:Write(LOG_INFO, "[ServerDataMirror] User " .. userId .. " data fetched")
            if onComplete then onComplete(results) end
        end,
        onError = function(err)
            log:Write(LOG_ERROR, "[ServerDataMirror] Fetch failed: " .. tostring(err))
        end
    })
end

return ServerDataMirror
```

### 2.2 流量镜像（Traffic Mirror）— 网络事件回放

**对应 mirrord 的：入站/出站流量镜像**

录制和回放线上玩家的操作序列，用于复现操作相关 Bug。

#### 操作录制器

```lua
-- scripts/debug/TrafficMirror.lua
local TrafficMirror = {}

local recording = false
local eventLog = {}
local startTime = 0

--- 开始录制玩家操作
function TrafficMirror.StartRecording()
    recording = true
    eventLog = {}
    startTime = time.elapsedTime
    log:Write(LOG_INFO, "[TrafficMirror] Recording started")
end

--- 记录一个操作事件（在 HandleUpdate 中调用）
--- @param eventName string 事件名称
--- @param data table 事件数据
function TrafficMirror.RecordEvent(eventName, data)
    if not recording then return end
    
    table.insert(eventLog, {
        t = time.elapsedTime - startTime,
        event = eventName,
        data = data,
    })
end

--- 停止录制并返回事件日志
--- @return table[] eventLog
function TrafficMirror.StopRecording()
    recording = false
    log:Write(LOG_INFO, "[TrafficMirror] Recording stopped: " .. #eventLog .. " events")
    return eventLog
end

--- 将事件日志保存到本地
--- @param filename string 保存路径
function TrafficMirror.SaveLog(filename)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(eventLog))
        file:Close()
        log:Write(LOG_INFO, "[TrafficMirror] Log saved: " .. filename)
    end
end

--- 加载并回放事件日志
--- @param filename string 日志文件路径
--- @param handler function 事件处理函数(eventName, data)
--- @return table replayer 回放控制器
function TrafficMirror.LoadAndReplay(filename, handler)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[TrafficMirror] Cannot open: " .. filename)
        return nil
    end
    
    local events = cjson.decode(file:ReadString())
    file:Close()
    
    local replayer = {
        events = events,
        index = 1,
        elapsed = 0,
        playing = true,
        handler = handler,
    }
    
    --- 每帧调用，驱动回放
    function replayer:Update(dt)
        if not self.playing then return end
        self.elapsed = self.elapsed + dt
        
        while self.index <= #self.events do
            local ev = self.events[self.index]
            if ev.t <= self.elapsed then
                self.handler(ev.event, ev.data)
                self.index = self.index + 1
            else
                break
            end
        end
        
        if self.index > #self.events then
            self.playing = false
            log:Write(LOG_INFO, "[TrafficMirror] Replay finished: " .. #self.events .. " events")
        end
    end
    
    log:Write(LOG_INFO, "[TrafficMirror] Replay loaded: " .. #events .. " events")
    return replayer
end

--- 记录标准输入状态快照（键盘+鼠标+触摸）
--- @return table inputSnapshot
function TrafficMirror.CaptureInputSnapshot()
    return {
        mouseX = input.mousePosition.x,
        mouseY = input.mousePosition.y,
        mouseLeft = input:GetMouseButtonDown(MOUSEB_LEFT),
        mouseRight = input:GetMouseButtonDown(MOUSEB_RIGHT),
        space = input:GetKeyDown(KEY_SPACE),
        w = input:GetKeyDown(KEY_W),
        a = input:GetKeyDown(KEY_A),
        s = input:GetKeyDown(KEY_S),
        d = input:GetKeyDown(KEY_D),
        touchCount = input.numTouches,
    }
end

return TrafficMirror
```

### 2.3 配置镜像（Config Mirror）— 远程配置同步

**对应 mirrord 的：环境变量镜像**

将线上的运行时配置镜像到本地，确保本地调试环境与线上一致。

```lua
-- scripts/debug/ConfigMirror.lua
local ConfigMirror = {}

--- 读取线上运行配置快照
--- @return table config
function ConfigMirror.CaptureRuntimeConfig()
    local config = {
        -- 屏幕信息
        screen = {
            physicalWidth = graphics:GetWidth(),
            physicalHeight = graphics:GetHeight(),
            dpr = graphics:GetDPR(),
            logicalWidth = graphics:GetWidth() / graphics:GetDPR(),
            logicalHeight = graphics:GetHeight() / graphics:GetDPR(),
        },
        -- 平台信息
        platform = {
            name = GetPlatform(),
            isMobile = GetPlatform() == "Android" or GetPlatform() == "iOS",
            isWeb = GetPlatform() == "Web",
        },
        -- 输入模式
        input = {
            hasTouchscreen = input.touchEmulation or input.numTouches > 0,
            mouseMode = input.mouseMode,
        },
        -- 时间戳
        capturedAt = os.date("%Y-%m-%d %H:%M:%S"),
    }
    
    log:Write(LOG_INFO, "[ConfigMirror] Runtime config captured")
    return config
end

--- 保存配置快照到本地
--- @param config table 配置数据
--- @param filename string 保存路径（如 "debug/config_mirror.json"）
function ConfigMirror.SaveConfig(config, filename)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(config))
        file:Close()
        log:Write(LOG_INFO, "[ConfigMirror] Config saved: " .. filename)
    end
end

--- 加载配置快照并生成差异报告
--- @param filename string 线上配置文件路径
--- @return table diff 差异列表
function ConfigMirror.CompareWithLocal(filename)
    local cjson = require("cjson")
    local file = File:new(filename, FILE_READ)
    if not file:IsOpen() then return nil end
    
    local remoteConfig = cjson.decode(file:ReadString())
    file:Close()
    
    local localConfig = ConfigMirror.CaptureRuntimeConfig()
    local diffs = {}
    
    -- 对比屏幕配置
    if remoteConfig.screen then
        local rs = remoteConfig.screen
        local ls = localConfig.screen
        if rs.physicalWidth ~= ls.physicalWidth or rs.physicalHeight ~= ls.physicalHeight then
            table.insert(diffs, {
                category = "screen",
                field = "resolution",
                remote = rs.physicalWidth .. "x" .. rs.physicalHeight,
                localVal = ls.physicalWidth .. "x" .. ls.physicalHeight,
            })
        end
        if rs.dpr ~= ls.dpr then
            table.insert(diffs, {
                category = "screen",
                field = "dpr",
                remote = rs.dpr,
                localVal = ls.dpr,
            })
        end
    end
    
    -- 对比平台
    if remoteConfig.platform and remoteConfig.platform.name ~= localConfig.platform.name then
        table.insert(diffs, {
            category = "platform",
            field = "name",
            remote = remoteConfig.platform.name,
            localVal = localConfig.platform.name,
        })
    end
    
    log:Write(LOG_INFO, "[ConfigMirror] Diff found: " .. #diffs .. " differences")
    return diffs
end

return ConfigMirror
```

### 2.4 反馈镜像（Feedback Mirror）— 线上 Bug 报告拉取

**对应 mirrord 的：连接远程 Pod 进行实时调试**

通过 UrhoX MCP `get_debug_feedbacks` 工具拉取线上玩家提交的调试反馈，
包括日志文件、截图、设备信息等，自动整理到本地调试目录。

#### MCP 工具调用流程

```
步骤 1: 调用 get_debug_feedbacks 工具
        ↓
        拉取反馈列表（默认未处理的）
        ↓
步骤 2: 自动下载到 logs/feed_back/
        ├── summary.json        ← 反馈汇总
        ├── feedback_10001/
        │   ├── info.json       ← 设备信息、版本号
        │   ├── description.txt ← 玩家描述
        │   ├── logs/           ← 运行时日志
        │   └── screenshots/    ← 截图
        └── feedback_10002/
            └── ...
        ↓
步骤 3: 分析反馈 → 提取复现条件
        ↓
步骤 4: 构建镜像环境 → 本地复现
```

#### 反馈分析与复现条件提取

```lua
-- scripts/debug/FeedbackMirror.lua
local FeedbackMirror = {}

--- 从反馈 info.json 提取复现条件
--- @param infoPath string info.json 路径
--- @return table conditions 复现条件
function FeedbackMirror.ExtractConditions(infoPath)
    local cjson = require("cjson")
    local file = File:new(infoPath, FILE_READ)
    if not file:IsOpen() then return nil end
    
    local info = cjson.decode(file:ReadString())
    file:Close()
    
    return {
        deviceModel = info.device_model or "unknown",
        osVersion = info.os_version or "unknown",
        appVersion = info.app_version or "unknown",
        screenSize = info.screen_size or "unknown",
        dpr = info.dpr or 1,
        platform = info.platform or "unknown",
        timestamp = info.timestamp or "unknown",
    }
end

--- 打印复现条件摘要（用于调试日志）
--- @param conditions table 复现条件
function FeedbackMirror.PrintConditions(conditions)
    log:Write(LOG_INFO, "=== Mirror Target Conditions ===")
    log:Write(LOG_INFO, "  Device:    " .. conditions.deviceModel)
    log:Write(LOG_INFO, "  OS:        " .. conditions.osVersion)
    log:Write(LOG_INFO, "  Version:   " .. conditions.appVersion)
    log:Write(LOG_INFO, "  Screen:    " .. conditions.screenSize)
    log:Write(LOG_INFO, "  DPR:       " .. tostring(conditions.dpr))
    log:Write(LOG_INFO, "  Platform:  " .. conditions.platform)
    log:Write(LOG_INFO, "================================")
end

return FeedbackMirror
```

### 2.5 环境镜像（Environment Mirror）— 运行模式复现

**对应 mirrord 的：Pod 环境完整镜像**

将线上的运行模式（单机/多人）、多人配置等完整复现到本地。

```lua
-- scripts/debug/EnvMirror.lua
local EnvMirror = {}

--- 读取项目运行时配置
--- @return table envConfig
function EnvMirror.ReadProjectSettings()
    local cjson = require("cjson")
    local file = File:new(".project/settings.json", FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_WARNING, "[EnvMirror] .project/settings.json not found")
        return { multiplayer = { enabled = false } }
    end
    
    local settings = cjson.decode(file:ReadString())
    file:Close()
    
    local runtime = settings["@runtime"] or {}
    return {
        multiplayer = runtime.multiplayer or { enabled = false },
    }
end

--- 判断当前是否为多人模式
--- @return boolean
function EnvMirror.IsMultiplayerMode()
    local env = EnvMirror.ReadProjectSettings()
    return env.multiplayer.enabled == true
end

--- 生成环境差异报告
--- @param remoteEnv table 线上环境配置
--- @return string report 差异报告文本
function EnvMirror.GenerateDiffReport(remoteEnv)
    local localEnv = EnvMirror.ReadProjectSettings()
    local lines = { "=== Environment Diff Report ===" }
    
    -- 多人模式对比
    local remoteMP = remoteEnv.multiplayer or {}
    local localMP = localEnv.multiplayer or {}
    
    if remoteMP.enabled ~= localMP.enabled then
        table.insert(lines, "[MISMATCH] multiplayer.enabled: remote="
            .. tostring(remoteMP.enabled) .. " local=" .. tostring(localMP.enabled))
    end
    
    if remoteMP.max_players ~= localMP.max_players then
        table.insert(lines, "[MISMATCH] multiplayer.max_players: remote="
            .. tostring(remoteMP.max_players) .. " local=" .. tostring(localMP.max_players))
    end
    
    if #lines == 1 then
        table.insert(lines, "[OK] All environment settings match")
    end
    
    table.insert(lines, "================================")
    local report = table.concat(lines, "\n")
    log:Write(LOG_INFO, report)
    return report
end

return EnvMirror
```

---

## §3 镜像调试完整工作流

### 3.1 标准流程

```
┌─────────────────────────────────────────────────────────────┐
│                    线上环境镜像调试流程                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ① 触发：收到线上 Bug 报告 / 玩家反馈                         │
│     ↓                                                       │
│  ② 拉取反馈（Feedback Mirror）                               │
│     调用 get_debug_feedbacks 工具                            │
│     → 获取日志、截图、设备信息                                │
│     ↓                                                       │
│  ③ 分析复现条件                                              │
│     从 info.json 提取设备型号、分辨率、DPR、平台等             │
│     ↓                                                       │
│  ④ 数据镜像（Data Mirror）                                   │
│     拉取该玩家的云变量快照到本地                               │
│     ↓                                                       │
│  ⑤ 配置镜像（Config Mirror）                                 │
│     对比线上与本地的运行配置差异                               │
│     ↓                                                       │
│  ⑥ 环境镜像（Environment Mirror）                            │
│     确保本地运行模式与线上一致                                 │
│     ↓                                                       │
│  ⑦ 本地复现                                                  │
│     注入镜像数据 → 启动游戏 → 复现 Bug                        │
│     ↓                                                       │
│  ⑧ 修复验证                                                  │
│     修改代码 → 调用 UrhoX MCP build 工具 → 验证修复           │
│     ↓                                                       │
│  ⑨ 清理镜像数据                                              │
│     删除本地调试快照文件，恢复默认配置                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 快速镜像调试（单次命令）

当用户说"帮我看看线上这个 Bug"时，按以下顺序执行：

```
1. 调用 get_debug_feedbacks 拉取最新反馈
2. 读取 logs/feed_back/summary.json 获取反馈列表
3. 选择最新的未处理反馈
4. 读取 feedback_XXXXX/info.json 提取设备信息
5. 读取 feedback_XXXXX/description.txt 获取问题描述
6. 读取 feedback_XXXXX/logs/ 下的运行时日志
7. 查看 feedback_XXXXX/screenshots/ 下的截图
8. 综合分析 → 提供诊断报告和修复建议
9. 修复代码后 → 调用 UrhoX MCP build 工具验证
```

---

## §4 诊断决策树

```
用户说"线上 Bug" / "复现问题" / "线上数据异常"
│
├─ 有具体反馈 ID？
│  ├─ 是 → 直接读取 logs/feed_back/feedback_XXXXX/
│  └─ 否 → 调用 get_debug_feedbacks 拉取最新反馈
│
├─ Bug 类型判断
│  ├─ 数据异常（积分错误、排行榜异常、存档丢失）
│  │  └→ 数据镜像：拉取云变量快照 → 对比预期值
│  │
│  ├─ UI/显示异常（布局错乱、文字溢出、控件消失）
│  │  └→ 配置镜像：提取分辨率/DPR/平台 → 对比差异
│  │
│  ├─ 操作异常（点击无响应、移动卡顿、技能失效）
│  │  └→ 流量镜像：分析输入日志 → 构建回放脚本
│  │
│  ├─ 联网异常（同步失败、掉线、延迟）
│  │  └→ 环境镜像：检查多人配置 → 对比本地与线上
│  │
│  └─ 崩溃/闪退
│     └→ 全通道镜像：拉取日志 + 设备信息 → 分析崩溃栈
│
└─ 复现后
   ├─ 可复现 → 修复代码 → 调用 UrhoX MCP build 工具 → 验证
   └─ 不可复现 → 增加日志点 → 发布观察版本 → 等待下次反馈
```

---

## §5 镜像数据注入模式

### 5.1 云变量注入（本地模拟线上数据）

```lua
-- scripts/debug/Injector.lua
local Injector = {}

--- 将快照数据注入到游戏运行时变量中
--- @param snapshot table 云变量快照 { key1 = value1, key2 = value2 }
--- @param gameState table 游戏状态表（引用传递，直接修改）
function Injector.InjectCloudData(snapshot, gameState)
    for key, value in pairs(snapshot) do
        gameState[key] = value
        log:Write(LOG_DEBUG, "[Injector] Injected: " .. key .. " = " .. tostring(value))
    end
    log:Write(LOG_INFO, "[Injector] Cloud data injected: " .. #snapshot .. " keys")
end

--- 生成模拟用的云变量覆盖层
--- 返回一个代理表，优先读取快照数据，fallback 到真实云变量
--- @param snapshot table 快照数据
--- @return table proxy 代理访问层
function Injector.CreateCloudProxy(snapshot)
    local proxy = {}
    
    function proxy:Get(key, events)
        if snapshot[key] ~= nil then
            log:Write(LOG_DEBUG, "[Injector] Proxy hit: " .. key)
            -- 模拟异步回调
            if events and events.onSuccess then
                events.onSuccess(snapshot[key])
            end
            return
        end
        -- Fallback 到真实云变量
        clientCloud:Get(key, events)
    end
    
    return proxy
end

return Injector
```

### 5.2 输入回放注入

```lua
-- 在 HandleUpdate 中使用回放器
local TrafficMirror = require("debug.TrafficMirror")
local replayer = nil

function StartReplay(logFile)
    replayer = TrafficMirror.LoadAndReplay(logFile, function(eventName, data)
        -- 将回放事件注入到游戏逻辑
        if eventName == "input" then
            -- 模拟输入状态
            HandleReplayedInput(data)
        elseif eventName == "game_event" then
            -- 触发游戏事件
            HandleReplayedGameEvent(data)
        end
    end)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- 如果有回放器在运行，驱动回放
    if replayer and replayer.playing then
        replayer:Update(dt)
    end
    
    -- 正常游戏逻辑...
end
```

---

## §6 UrhoX 引擎集成规则

### 6.1 文件存储规范

所有镜像数据文件使用 `File` API 存储在沙箱内：

```lua
-- ✅ 正确：使用相对路径，File API 自动处理沙箱
local file = File:new("debug/snapshot.json", FILE_WRITE)

-- ❌ 错误：不要使用绝对路径
-- local file = File:new("/tmp/snapshot.json", FILE_WRITE)

-- ❌ 错误：io 库已被移除
-- ❌ 错误：标准 Lua 的 io 库已被引擎沙箱移除，不可使用
```

### 6.2 代码存放位置

```
scripts/
├── main.lua                    # 游戏入口
├── debug/                      # 调试镜像模块（本 Skill 生成）
│   ├── DataMirror.lua          # 数据镜像
│   ├── TrafficMirror.lua       # 流量镜像
│   ├── ConfigMirror.lua        # 配置镜像
│   ├── FeedbackMirror.lua      # 反馈镜像
│   ├── EnvMirror.lua           # 环境镜像
│   └── Injector.lua            # 数据注入
└── Network/                    # 联网模块（如有）
    ├── Server.lua
    └── Client.lua
```

### 6.3 分辨率适配注意

本地调试时，如需模拟线上设备的分辨率和 DPR：

```lua
-- 读取线上设备的分辨率信息（从镜像配置中）
local remoteConfig = ConfigMirror.LoadConfig("debug/config_mirror.json")
local remoteDPR = remoteConfig.screen.dpr
local remoteLogicalW = remoteConfig.screen.logicalWidth
local remoteLogicalH = remoteConfig.screen.logicalHeight

-- 在本地获取实际值进行对比
local localW = graphics:GetWidth()
local localH = graphics:GetHeight()
local localDPR = graphics:GetDPR()

-- 计算缩放差异（用于调试 UI 布局问题）
local scaleRatio = remoteDPR / localDPR
log:Write(LOG_INFO, "Scale ratio (remote/local DPR): " .. scaleRatio)
```

> ⚠️ 屏幕信息获取：不要调用已禁用的模式设置 API。使用 `graphics:GetWidth()`、
> `graphics:GetHeight()`、`graphics:GetDPR()` 获取屏幕信息。

### 6.4 JSON 编解码

所有镜像数据的序列化/反序列化使用 `cjson`：

```lua
local cjson = require("cjson")

-- 序列化
local jsonStr = cjson.encode({ score = 1000, level = 5 })

-- 反序列化
local data = cjson.decode(jsonStr)
```

### 6.5 事件数据访问

遵循 UrhoX 事件数据访问规范：

```lua
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- 或更高效的方式：
    -- local dt = eventData:GetFloat("TimeStep")
end
```

---

## §7 质量门禁

### G1 镜像数据完整性

- 云变量快照必须包含所有请求的 key
- 配置快照必须包含 screen、platform、input 三个维度
- 事件日志每条记录必须包含 t（时间戳）、event（事件名）、data（数据）

### G2 文件存储合规

- 所有文件使用 `File` API 操作（不使用 `io.*`）
- 路径使用相对路径（如 `"debug/snapshot.json"`）
- JSON 编解码使用 `cjson`

### G3 引擎兼容性

- 不调用已禁用的屏幕模式设置 API
- 使用 `graphics:GetWidth()`/`graphics:GetHeight()`/`graphics:GetDPR()` 获取屏幕信息
- 鼠标按钮使用枚举值（`MOUSEB_LEFT` 等）
- 数组索引从 1 开始

### G4 代码规范

- 调试模块放在 `scripts/debug/` 目录
- 所有模块函数添加 `---@param` 类型标注
- 日志使用 `log:Write()` 并标注模块前缀（如 `[DataMirror]`）
- 每个模块返回 table（`return ModuleName`）

### G5 构建验证

- 每次修改代码后必须调用 UrhoX MCP build 工具验证
- 确保所有 `require` 路径正确
- 确保不引入语法错误

---

## §8 状态文件

镜像调试过程会产生以下状态文件，存储在沙箱中：

| 文件 | 用途 | 格式 |
|------|------|------|
| `debug/snapshot_{timestamp}.json` | 云变量快照 | JSON |
| `debug/traffic_{timestamp}.json` | 操作事件日志 | JSON |
| `debug/config_mirror.json` | 运行时配置快照 | JSON |
| `debug/env_diff_report.txt` | 环境差异报告 | 纯文本 |
| `logs/feed_back/summary.json` | 反馈汇总（MCP 生成） | JSON |

---

## §9 构建验证集成

镜像调试模块编写完成后，**必须调用 UrhoX MCP build 工具**验证整体项目可编译：

```
镜像模块编写 → 代码检查 → 调用 UrhoX MCP build 工具
                                    ↓
                            构建通过 → 开始调试
                            构建失败 → 修复后重新 build
```

**关键规则**：
- 每次新增或修改 `scripts/debug/` 下的模块后，必须调用 UrhoX MCP build 工具
- build 失败时，检查 `require` 路径是否正确（如 `require("debug.DataMirror")`）
- 确保 `cjson` 依赖可用（引擎内置，无需额外安装）

---

## §10 首次触发响应模板

当本 Skill 被触发时，按以下模板响应：

```
我来帮你进行线上环境镜像调试。

当前项目运行模式：[读取 .project/settings.json 判断单机/多人]

请告诉我：
1. Bug 的表现是什么？（数据异常/UI 错乱/操作失效/崩溃）
2. 是否有具体的反馈 ID 或玩家投诉？
3. Bug 在什么设备/平台上出现？

我会按以下流程帮你排查：
① 拉取线上反馈 → ② 提取复现条件 → ③ 镜像数据到本地
→ ④ 本地复现 → ⑤ 定位修复 → ⑥ build 验证
```

---

## 参考文档

- `references/mirror-modules.md` — 镜像模块 API 速查与使用示例
