# Auto-Workflow 自动化模式详解

> 六大自动化领域的详细实现模式、判断逻辑、边界条件和最佳实践。

## 目录

1. [项目初始化自动化](#1-项目初始化自动化)
2. [场景搭建自动化](#2-场景搭建自动化)
3. [UI 接线自动化](#3-ui-接线自动化)
4. [配置提取自动化](#4-配置提取自动化)
5. [模块化拆分自动化](#5-模块化拆分自动化)
6. [构建检查自动化](#6-构建检查自动化)
7. [主动触发判断矩阵](#7-主动触发判断矩阵)

---

## 1. 项目初始化自动化

### 决策树：脚手架选择

```
用户需求分析
  ├─ 2D 游戏？
  │   ├─ 需要物理碰撞？ → scaffold-2d-physics.lua
  │   └─ 纯渲染/NanoVG？ → scaffold-2d.lua
  ├─ 3D 游戏？
  │   ├─ 有可控角色？ → scaffold-3d-character.lua
  │   └─ 场景展示/编辑器？ → scaffold-3d-scene.lua
  └─ 不确定 → 询问"游戏中有可控角色吗？"
```

### 定制化注入清单

在复制脚手架后，根据需求自动注入以下代码块：

| 需求 | 注入内容 | 注入位置 |
|------|---------|---------|
| FPS/TPS 视角 | `input.mouseMode = MM_RELATIVE` | `Start()` |
| 第三人称相机 | `ThirdPersonCamera.Create()` 初始化 | `Start()` + `HandlePostUpdate()` |
| 2D 物理 | Box2D 碰撞层 + 地面检测 | `Start()` + `HandlePhysicsBeginContact2D()` |
| 3D 物理 | PhysicsWorld + 碰撞事件订阅 | `Start()` + `HandleNodeCollision()` |
| UI HUD | `UI.Init()` + HUD 面板 | `Start()` |
| 云存档 | `clientCloud` 读写封装 | 独立模块或内联 |
| 多人网络 | 模式路由 + Client/Server/Standalone | `main.lua` 入口 |

### 多人模式路由生成

读取 `.project/settings.json` 的 `@runtime.multiplayer.enabled` 来决定路由：

```lua
-- 自动生成的 main.lua 入口（多人项目）
local cjson = require("cjson")

local function readSettings()
    local path = ".project/settings.json"
    if not fileSystem:FileExists(path) then return {} end
    local f = File(path, FILE_READ)
    if not f:IsOpen() then return {} end
    local ok, data = pcall(cjson.decode, f:ReadString())
    f:Close()
    return ok and data or {}
end

local function isMultiplayerEnabled()
    local settings = readSettings()
    local mp = settings["@runtime"] and settings["@runtime"].multiplayer
    return mp and mp.enabled == true
end

function Start()
    if IsServerMode() then
        require("network.Server")
    elseif isMultiplayerEnabled() then
        require("network.Client")
    else
        require("network.Standalone")
    end
end
```

### 初始化时机选择

| 项目阶段 | 建议操作 |
|---------|---------|
| 全新项目 | 完整脚手架 + 定制注入 |
| 已有代码需要加新功能 | 仅注入缺失的代码块 |
| 从示例修改 | 保留示例结构，仅替换游戏逻辑 |

---

## 2. 场景搭建自动化

### 场景类型预设

| 预设 | 灯光 | 地面 | 天空 | 重力 | 适用 |
|------|------|------|------|------|------|
| **室外白天** | 方向光 + 环境光 | 大地面(50m) | 天空盒 | -9.81 | 跑酷/射击/运动 |
| **室外夜间** | 月光(弱) + 点光源 | 大地面 | 暗天空盒 | -9.81 | 恐怖/潜行 |
| **室内** | 点光源 × N | 房间地板 | 无 | -9.81 | 密室/解谜 |
| **地下城** | 火把点光源 | 石板地 | 无 | -9.81 | RPG/冒险 |
| **太空** | 无 / 弱环境光 | 无 | 星空盒 | 0 | 太空模拟 |
| **2D 平台** | 无方向光 | 无 | 背景色 | (0, -20, 0) | 平台跳跃 |

### 灯光配置模式

```lua
-- 室外白天预设
local function setupOutdoorDaylight(scene)
    -- 主方向光（太阳）
    local sunNode = scene:CreateChild("Sun")
    sunNode.direction = Vector3(0.6, -1.0, 0.8)
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    sun.color = Color(1.0, 0.95, 0.9)
    sun.castShadows = true
    sun.shadowIntensity = 0.5
    sun.shadowCascade = CascadeParameters(10.0, 30.0, 80.0, 200.0, 0.8)

    -- 环境光（填充阴影）
    local ambientNode = scene:CreateChild("Ambient")
    local ambient = ambientNode:CreateComponent("Light")
    ambient.lightType = LIGHT_DIRECTIONAL
    ambient.color = Color(0.3, 0.35, 0.4)
    ambient.castShadows = false
end

-- 室内点光源预设
local function setupIndoorLights(scene, positions)
    for i, pos in ipairs(positions) do
        local lightNode = scene:CreateChild("Light_" .. i)
        lightNode.position = pos
        local light = lightNode:CreateComponent("Light")
        light.lightType = LIGHT_POINT
        light.range = 8.0
        light.color = Color(1.0, 0.9, 0.7)
        light.castShadows = true
    end
end
```

### 地面生成

```lua
-- 标准地面（可配置尺寸和材质）
local function createGround(scene, size, materialPath)
    local node = scene:CreateChild("Ground")
    node.position = Vector3(0, 0, 0)
    node.scale = Vector3(size, 1.0, size)

    local model = node:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")
    if materialPath then
        model.material = cache:GetResource("Material", materialPath)
    end

    -- 物理碰撞体
    local body = node:CreateComponent("RigidBody")
    body.mass = 0  -- 静态
    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)  -- Box.mdl 原始尺寸 1x1x1，scale 已缩放

    return node
end
```

---

## 3. UI 接线自动化

### UI 初始化标准模式

所有使用 UI 的项目都需要以下初始化代码：

```lua
local UI = require("urhox-libs/UI")

local function initUI()
    UI.Init({
        fonts = {
            {
                family = "sans",
                weights = {
                    normal = "Fonts/MiSans-Regular.ttf",
                    -- bold = "Fonts/MiSans-Bold.ttf",  -- 可选
                },
            },
        },
        scale = UI.Scale.DEFAULT,
    })
end
```

### 面板生成策略

根据游戏类型自动选择需要的面板组合：

| 游戏类型 | 必要面板 | 可选面板 |
|---------|---------|---------|
| 休闲/街机 | 主菜单 + HUD + 游戏结束 | 设置 |
| RPG | 主菜单 + HUD + 暂停 + 设置 | 背包/对话 |
| 竞技/排行 | 主菜单 + HUD + 游戏结束 + 排行榜 | 设置 |
| 模拟经营 | 主菜单 + HUD + 设置 | 统计面板 |

### 面板切换状态管理

```lua
-- 自动生成的面板管理器
local PanelManager = {}
local currentPanel_ = nil
local panels_ = {}

function PanelManager.Register(name, builder)
    panels_[name] = builder
end

function PanelManager.Show(name, params)
    if panels_[name] then
        currentPanel_ = name
        local panel = panels_[name](params)
        UI.SetRoot(panel)
    end
end

function PanelManager.Current()
    return currentPanel_
end

return PanelManager
```

### 通用 HUD 生成器参数

```lua
-- HUD 配置格式
local hudConfig = {
    -- 左上角
    topLeft = {
        { type = "health", maxValue = 100, color = {255, 80, 80, 255} },
        { type = "mana",   maxValue = 50,  color = {80, 120, 255, 255} },
    },
    -- 右上角
    topRight = {
        { type = "score", label = "分数", format = "%06d" },
    },
    -- 底部居中
    bottomCenter = {
        { type = "timer", format = "%02d:%02d" },
    },
}
```

---

## 4. 配置提取自动化

### 魔法数字识别规则

**扫描目标**：`scripts/` 下所有 `.lua` 文件中的数值字面量。

**分类规则**：

| 上下文关键词 | 分类 | 配置命名 |
|-------------|------|---------|
| `speed`, `velocity`, `move` | Player | `moveSpeed` |
| `jump`, `force`, `impulse` | Player | `jumpForce` |
| `health`, `hp`, `life`, `damage` | Player | `maxHealth` / `damage` |
| `gravity` | Physics | `gravity` |
| `distance`, `offset`, `fov` | Camera | 对应属性名 |
| `fontSize`, `padding`, `margin` | UI | 对应属性名 |
| `spawnRate`, `interval`, `cooldown` | Gameplay | 对应属性名 |
| `scale`, `size`, `width`, `height` | Visual | 对应属性名 |

**排除规则**（不提取以下数值）：

- 数组索引（`array[1]`, `for i = 1, n`）
- 数学常量（`0`, `1`, `-1`, `0.5`, `2`）
- 颜色分量（`{ 255, 0, 0, 255 }`，整组提取而非单值）
- 向量构造（`Vector3(0, 1, 0)` 是方向常量，不提取）
- API 枚举参数

### 配置文件生成格式

```lua
--- scripts/GameConfig.lua
--- 自动从代码中提取的游戏配置
--- 修改此文件可调整游戏参数，无需改动逻辑代码
local GameConfig = {

    --- 玩家相关
    Player = {
        moveSpeed    = 5.0,    -- 移动速度 (m/s)
        jumpForce    = 7.0,    -- 跳跃初速度 (m/s)
        maxHealth    = 100,    -- 最大生命值
        dashDistance  = 3.0,   -- 冲刺距离 (m)
    },

    --- 相机
    Camera = {
        distance     = 5.0,    -- 跟随距离 (m)
        height       = 1.7,    -- 偏移高度 (m)
        fov          = 45.0,   -- 视场角 (°)
        sensitivity  = 0.1,    -- 鼠标灵敏度
    },

    --- 物理
    Physics = {
        gravity      = -9.81,  -- 重力加速度 (m/s²)
    },

    --- 关卡
    Level = {
        spawnInterval = 2.0,   -- 敌人生成间隔 (s)
        maxEnemies   = 20,     -- 最大敌人数量
    },
}

return GameConfig
```

### 代码替换示例

```lua
-- 替换前（硬编码）
node.position = node.position + moveDir * 5.0 * dt
body:ApplyImpulse(Vector3(0, 7.0, 0))

-- 替换后（引用配置）
local Config = require("GameConfig")
node.position = node.position + moveDir * Config.Player.moveSpeed * dt
body:ApplyImpulse(Vector3(0, Config.Player.jumpForce, 0))
```

---

## 5. 模块化拆分自动化

### 触发条件

| 条件 | 阈值 | 动作 |
|------|------|------|
| 单文件行数 | > 1000 行 | 建议拆分 |
| 单文件行数 | > 1500 行 | **必须拆分** |
| 函数数量 | > 15 个顶层函数 | 建议按职责分组 |
| 全局变量 | > 10 个文件级变量 | 建议封装为模块 |

### 拆分分析步骤

```
1. 统计文件行数和函数列表
2. 识别功能区域（通过注释、空行分隔、函数命名前缀）
3. 分析依赖关系（哪些函数互相调用）
4. 构建依赖图 → 识别低耦合的可分离模块
5. 提议拆分方案 → 用户确认
6. 执行拆分 → 创建模块文件 + 更新入口
```

### 模块封装规范

每个拆分出的模块遵循统一格式：

```lua
--- scripts/Player.lua
--- 玩家控制模块：移动、跳跃、生命管理

local Player = {}

-- 模块内部状态
---@type Node
local playerNode_ = nil
local health_ = 100

--- 初始化
---@param scene Scene
---@param config table 来自 GameConfig.Player
function Player.Init(scene, config)
    playerNode_ = scene:CreateChild("Player")
    health_ = config.maxHealth or 100
    -- ... 创建模型、物理组件等
end

--- 每帧更新
---@param dt number
function Player.Update(dt)
    -- ... 移动、输入处理等
end

--- 获取玩家节点
---@return Node
function Player.GetNode()
    return playerNode_
end

return Player
```

### 入口文件模式

拆分后的 `main.lua` 保持简洁的编排职责：

```lua
-- scripts/main.lua
-- 游戏入口：初始化各模块 + 事件分发

local GameConfig = require("GameConfig")
local SceneSetup = require("SceneSetup")
local Player     = require("Player")
local EnemyMgr   = require("EnemyManager")
local GameUI     = require("GameUI")

---@type Scene
local scene_ = nil

function Start()
    scene_ = Scene()
    SceneSetup.Init(scene_, GameConfig)
    Player.Init(scene_, GameConfig.Player)
    EnemyMgr.Init(scene_, GameConfig.Level)
    GameUI.Init(GameConfig)

    SubscribeToEvent("Update", "HandleUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    Player.Update(dt)
    EnemyMgr.Update(dt)
    GameUI.Update(dt)
end
```

---

## 6. 构建检查自动化

### 代码规范检查项

| 检查项 | 检测方法 | 严重度 |
|--------|---------|-------|
| 数组索引从 0 开始 | 匹配 `[0]` 模式 | ERROR |
| 使用禁止 API | 匹配 `io\.`, `os.execute`, `os.remove` | ERROR |
| 鼠标按钮用数字 | 匹配 `button == 0` / `button ~= 0` | WARNING |
| 缺少 Start() 函数 | 入口文件扫描 | ERROR |
| eventData 直接索引 | 匹配 `eventData.` 但无 `:Get` | WARNING |
| 单文件超长 | 行数统计 | WARNING(>1000) / ERROR(>1500) |
| 未标注类型的 nil 赋值 | 匹配 `local \w+ = nil` 无 `@type` | INFO |

### 资源引用检查

扫描所有 `.lua` 文件中的 `cache:GetResource` 和 `require` 调用：

```lua
-- 需要检查的资源引用模式
cache:GetResource("Model", "Models/Box.mdl")         -- 内置模型，不检查
cache:GetResource("Texture2D", "Textures/player.png") -- 检查 assets/Textures/player.png
cache:GetResource("Material", "Materials/MyMat.xml")  -- 检查 assets/Materials/MyMat.xml
cache:GetResource("Sound", "Sounds/jump.ogg")         -- 检查 assets/Sounds/jump.ogg
```

**内置资源白名单**（不需要检查）：
- `Models/Box.mdl`, `Models/Sphere.mdl`, `Models/Cylinder.mdl`, `Models/Cone.mdl`, `Models/Torus.mdl`, `Models/Plane.mdl`, `Models/Mushroom.mdl`
- `Fonts/MiSans-Regular.ttf`
- `Techniques/PBR/*.xml`, `Techniques/NoTexture*.xml`

### 检查输出格式

```
========== 构建前检查报告 ==========

✅ 代码检查
  - 入口文件 main.lua 包含 Start()
  - 数组索引规范 ✓
  - 无禁止 API ✓

⚠️ 警告 (2)
  - main.lua:45  鼠标按钮判断使用数字 0，建议改为 MOUSEB_LEFT
  - main.lua:892 文件接近 1000 行，建议考虑模块化拆分

❌ 错误 (1)
  - main.lua:67  资源 "Textures/hero.png" 在 assets/ 中不存在

====================================
```

---

## 7. 主动触发判断矩阵

何时**不等用户请求，主动建议自动化**：

| 检测信号 | 建议动作 | 措辞模板 |
|---------|---------|---------|
| 同一个 `UI.Init` 代码块出现 2+ 次 | 提取为共享模块 | "检测到重复的 UI 初始化代码，我可以抽取为一个共享的 initUI() 函数" |
| 5+ 个硬编码数值 | 生成 GameConfig.lua | "代码中有多个硬编码数值，建议提取到 GameConfig.lua 便于调参" |
| 单文件超过 1000 行 | 提议模块化拆分 | "main.lua 已超过 1000 行，建议拆分为多模块结构以提高可维护性" |
| 手动写 > 20 行场景搭建 | 提供场景预设 | "这些场景搭建代码可以用预设模板一键生成，要我帮你简化吗？" |
| 连续创建 3+ 个 UI 面板 | 提供面板管理器 | "检测到多个面板切换逻辑，我可以生成一个 PanelManager 来统一管理" |
| require 路径写错 | 纠正并解释规则 | "require 路径应该从 scripts/ 的下一级开始，不需要加 scripts/ 前缀" |
| 重复的事件订阅模式 | 合并为事件分发器 | "多个事件处理函数可以合并到统一的分发器中" |

### 不应主动触发的场景

| 场景 | 原因 |
|------|------|
| 用户正在探索/实验 | 过早自动化会打断思路 |
| 代码量很小（< 200 行） | 过度工程化 |
| 用户明确说"先快速实现" | 尊重用户意图 |
| 一次性脚本/Demo | 无复用需求 |
