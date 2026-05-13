# 代码生成模板集

> 本文件提供 auto-workflow 六大自动化领域的**即用代码模板**。
> AI 应根据用户需求选择对应模板，填充参数后输出完整可运行代码。

---

## 目录

1. [场景搭建模板](#1-场景搭建模板)
2. [UI 面板模板](#2-ui-面板模板)
3. [GameConfig 配置模板](#3-gameconfig-配置模板)
4. [模块化拆分模板](#4-模块化拆分模板)
5. [入口文件模板](#5-入口文件模板)
6. [构建检查模板](#6-构建检查模板)

---

## 1. 场景搭建模板

### 1.1 室外场景（阳光 + 地面 + 天空盒）

```lua
--- 创建室外 3D 场景
---@param scene Scene
---@param options? {groundSize?: number, sunYaw?: number, sunPitch?: number, ambient?: Color, fog?: boolean}
local function CreateOutdoorScene(scene, options)
    local opt = options or {}
    local groundSize = opt.groundSize or 100
    local sunYaw = opt.sunYaw or 60
    local sunPitch = opt.sunPitch or -45
    local ambient = opt.ambient or Color(0.3, 0.3, 0.35)
    local fog = opt.fog ~= false

    -- 物理世界
    local pw = scene:CreateComponent("PhysicsWorld")

    -- 天空盒
    local skyNode = scene:CreateChild("Sky")
    local skybox = skyNode:CreateComponent("Skybox")
    skybox.model = cache:GetResource("Model", "Models/Box.mdl")
    skybox.material = cache:GetResource("Material", "Materials/Skybox.xml")

    -- 环境光
    local zoneNode = scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = ambient
    if fog then
        zone.fogColor = Color(0.6, 0.7, 0.8)
        zone.fogStart = groundSize * 0.5
        zone.fogEnd = groundSize * 1.5
    end

    -- 平行光（太阳）
    local lightNode = scene:CreateChild("Sun")
    lightNode.rotation = Quaternion(sunPitch, sunYaw, 0)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(1.0, 0.95, 0.85)
    light.brightness = 1.2
    light.castShadows = true
    light.shadowCascade = CascadeParameters(10.0, 30.0, 80.0, 0, 0.8)

    -- 地面
    local groundNode = scene:CreateChild("Ground")
    groundNode.scale = Vector3(groundSize, 1, groundSize)
    local groundModel = groundNode:CreateComponent("StaticModel")
    groundModel.model = cache:GetResource("Model", "Models/Plane.mdl")
    -- 程序化地面材质
    local groundMat = Material:new()
    groundMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    groundMat:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.5, 0.25)))
    groundMat:SetShaderParameter("MatRoughness", Variant(0.85))
    groundModel.material = groundMat

    local groundBody = groundNode:CreateComponent("RigidBody")
    groundBody.mass = 0
    local groundShape = groundNode:CreateComponent("CollisionShape")
    groundShape:SetBox(Vector3(1, 0, 1))

    return {
        zone = zone,
        sun = lightNode,
        ground = groundNode,
    }
end
```

### 1.2 室内场景（点光源 + 封闭空间）

```lua
--- 创建室内 3D 场景
---@param scene Scene
---@param options? {roomSize?: Vector3, lightCount?: number, ambient?: Color}
local function CreateIndoorScene(scene, options)
    local opt = options or {}
    local roomSize = opt.roomSize or Vector3(20, 5, 20)
    local lightCount = opt.lightCount or 4
    local ambient = opt.ambient or Color(0.15, 0.15, 0.18)

    scene:CreateComponent("PhysicsWorld")

    -- 环境光
    local zoneNode = scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-500, -500, -500), Vector3(500, 500, 500))
    zone.ambientColor = ambient

    -- 地板
    local floorNode = scene:CreateChild("Floor")
    floorNode.scale = Vector3(roomSize.x, 1, roomSize.z)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Plane.mdl")
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.6, 0.55, 0.5)))
    floorMat:SetShaderParameter("MatRoughness", Variant(0.7))
    floorModel.material = floorMat

    local floorBody = floorNode:CreateComponent("RigidBody")
    floorBody.mass = 0
    local floorShape = floorNode:CreateComponent("CollisionShape")
    floorShape:SetBox(Vector3(1, 0, 1))

    -- 顶部点光源（均匀分布）
    local lights = {}
    local cols = math.ceil(math.sqrt(lightCount))
    local rows = math.ceil(lightCount / cols)
    for i = 1, lightCount do
        local row = math.ceil(i / cols)
        local col = ((i - 1) % cols) + 1
        local x = (col / (cols + 1) - 0.5) * roomSize.x
        local z = (row / (rows + 1) - 0.5) * roomSize.z
        local lNode = scene:CreateChild("PointLight_" .. i)
        lNode.position = Vector3(x, roomSize.y * 0.9, z)
        local l = lNode:CreateComponent("Light")
        l.lightType = LIGHT_POINT
        l.range = roomSize.y * 2.5
        l.color = Color(1.0, 0.95, 0.85)
        l.brightness = 1.5
        l.castShadows = true
        lights[i] = lNode
    end

    return { zone = zone, floor = floorNode, lights = lights }
end
```

### 1.3 2D 场景（正交相机 + 物理世界）

```lua
--- 创建 2D 场景
---@param scene Scene
---@param options? {orthoSize?: number, gravity?: Vector2, bgColor?: Color}
local function Create2DScene(scene, options)
    local opt = options or {}
    local orthoSize = opt.orthoSize or 10
    local gravity = opt.gravity or Vector2(0, -9.81)
    local bgColor = opt.bgColor or Color(0.1, 0.1, 0.15)

    local pw2d = scene:CreateComponent("PhysicsWorld2D")
    pw2d.gravity = gravity

    -- 正交相机
    local camNode = scene:CreateChild("Camera")
    camNode.position = Vector3(0, 0, -10)
    local camera = camNode:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = orthoSize

    renderer:SetViewport(0, Viewport:new(scene, camera))
    renderer.defaultZone.fogColor = bgColor

    return { camera = camera, cameraNode = camNode }
end
```

---

## 2. UI 面板模板

### 2.1 UI 初始化标准模板

```lua
local UI = require("urhox-libs/UI")

--- 初始化 UI 系统（每个项目调用一次）
local function InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })
end
```

### 2.2 主菜单面板

```lua
--- 创建主菜单面板
---@param options {title: string, onStart: function, onSettings?: function, onQuit?: function}
local function CreateMainMenu(options)
    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#000000CC",
        children = {
            UI.Panel {
                width = 360, padding = 32,
                backgroundColor = "#1a1a2eF0",
                borderRadius = 16,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = options.title,
                        fontSize = 36,
                        fontWeight = "bold",
                        color = "#FFFFFF",
                        marginBottom = 40,
                    },
                    UI.Button {
                        text = "开始游戏",
                        variant = "primary",
                        width = "100%",
                        height = 48,
                        marginBottom = 12,
                        onClick = function(self) options.onStart() end,
                    },
                    options.onSettings and UI.Button {
                        text = "设置",
                        variant = "outline",
                        width = "100%",
                        height = 48,
                        marginBottom = 12,
                        onClick = function(self) options.onSettings() end,
                    } or nil,
                    options.onQuit and UI.Button {
                        text = "退出",
                        variant = "ghost",
                        width = "100%",
                        height = 48,
                        onClick = function(self) options.onQuit() end,
                    } or nil,
                },
            },
        },
    }
end
```

### 2.3 游戏 HUD 面板

```lua
--- 创建游戏 HUD
---@param config {score?: boolean, hp?: boolean, timer?: boolean, coins?: boolean}
---@return table refs 引用表，用于更新值
local function CreateGameHUD(config)
    local refs = {}
    local topItems = {}

    -- 生命值
    if config.hp ~= false then
        refs.hpLabel = UI.Label { text = "HP: 100", fontSize = 18, color = "#FF4444" }
        topItems[#topItems + 1] = refs.hpLabel
    end

    -- 分数
    if config.score ~= false then
        refs.scoreLabel = UI.Label { text = "分数: 0", fontSize = 18, color = "#FFFFFF" }
        topItems[#topItems + 1] = refs.scoreLabel
    end

    -- 金币
    if config.coins then
        refs.coinsLabel = UI.Label { text = "金币: 0", fontSize = 18, color = "#FFD700" }
        topItems[#topItems + 1] = refs.coinsLabel
    end

    -- 计时器
    if config.timer then
        refs.timerLabel = UI.Label { text = "00:00", fontSize = 18, color = "#AAAAFF" }
        topItems[#topItems + 1] = refs.timerLabel
    end

    refs.root = UI.Panel {
        width = "100%", padding = 12,
        flexDirection = "row",
        justifyContent = "space-between",
        position = "absolute", top = 0, left = 0,
        children = topItems,
    }

    -- 更新方法
    function refs:setHP(v) if self.hpLabel then self.hpLabel:setText("HP: " .. v) end end
    function refs:setScore(v) if self.scoreLabel then self.scoreLabel:setText("分数: " .. v) end end
    function refs:setCoins(v) if self.coinsLabel then self.coinsLabel:setText("金币: " .. v) end end
    function refs:setTimer(sec)
        if self.timerLabel then
            self.timerLabel:setText(string.format("%02d:%02d", math.floor(sec / 60), math.floor(sec % 60)))
        end
    end

    return refs
end
```

### 2.4 暂停菜单面板

```lua
--- 创建暂停菜单
---@param options {onResume: function, onRestart: function, onMainMenu: function}
local function CreatePauseMenu(options)
    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#00000099",
        children = {
            UI.Panel {
                width = 300, padding = 24,
                backgroundColor = "#222233EE",
                borderRadius = 12,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "暂停",
                        fontSize = 28, color = "#FFFFFF",
                        marginBottom = 24,
                    },
                    UI.Button {
                        text = "继续游戏",
                        variant = "primary",
                        width = "100%", height = 44,
                        marginBottom = 10,
                        onClick = function(self) options.onResume() end,
                    },
                    UI.Button {
                        text = "重新开始",
                        variant = "outline",
                        width = "100%", height = 44,
                        marginBottom = 10,
                        onClick = function(self) options.onRestart() end,
                    },
                    UI.Button {
                        text = "返回主菜单",
                        variant = "ghost",
                        width = "100%", height = 44,
                        onClick = function(self) options.onMainMenu() end,
                    },
                },
            },
        },
    }
end
```

### 2.5 游戏结束面板

```lua
--- 创建游戏结束面板
---@param options {title?: string, score: number, bestScore?: number, onRestart: function, onMainMenu: function}
local function CreateGameOverPanel(options)
    local title = options.title or "游戏结束"
    local children = {
        UI.Label { text = title, fontSize = 32, color = "#FF6666", marginBottom = 16 },
        UI.Label { text = "分数: " .. options.score, fontSize = 22, color = "#FFFFFF", marginBottom = 8 },
    }
    if options.bestScore then
        children[#children + 1] = UI.Label {
            text = "最高分: " .. options.bestScore,
            fontSize = 18, color = "#FFD700", marginBottom = 24,
        }
    else
        children[#children + 1] = UI.Spacer { height = 16 }
    end
    children[#children + 1] = UI.Button {
        text = "再来一局", variant = "primary", width = "100%", height = 44, marginBottom = 10,
        onClick = function(self) options.onRestart() end,
    }
    children[#children + 1] = UI.Button {
        text = "主菜单", variant = "outline", width = "100%", height = 44,
        onClick = function(self) options.onMainMenu() end,
    }

    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#000000BB",
        children = {
            UI.Panel {
                width = 320, padding = 28,
                backgroundColor = "#1a1a2eF0",
                borderRadius = 14,
                alignItems = "center",
                children = children,
            },
        },
    }
end
```

### 2.6 设置面板

```lua
--- 创建设置面板
---@param options {volumes?: boolean, onClose: function, onVolumeChange?: function}
local function CreateSettingsPanel(options)
    local children = {
        UI.Label { text = "设置", fontSize = 28, color = "#FFFFFF", marginBottom = 20 },
    }

    if options.volumes ~= false then
        -- 音乐音量
        children[#children + 1] = UI.Label { text = "音乐音量", fontSize = 16, color = "#AAAAAA", marginBottom = 4 }
        children[#children + 1] = UI.Slider {
            value = 80, min = 0, max = 100,
            width = "100%", marginBottom = 16,
            onChange = function(self, v)
                if options.onVolumeChange then options.onVolumeChange("music", v / 100) end
            end,
        }
        -- 音效音量
        children[#children + 1] = UI.Label { text = "音效音量", fontSize = 16, color = "#AAAAAA", marginBottom = 4 }
        children[#children + 1] = UI.Slider {
            value = 80, min = 0, max = 100,
            width = "100%", marginBottom = 20,
            onChange = function(self, v)
                if options.onVolumeChange then options.onVolumeChange("sfx", v / 100) end
            end,
        }
    end

    children[#children + 1] = UI.Button {
        text = "返回", variant = "outline", width = "100%", height = 44,
        onClick = function(self) options.onClose() end,
    }

    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = "#00000099",
        children = {
            UI.Panel {
                width = 340, padding = 24,
                backgroundColor = "#222233EE",
                borderRadius = 12,
                alignItems = "center",
                children = children,
            },
        },
    }
end
```

---

## 3. GameConfig 配置模板

### 3.1 标准 GameConfig 格式

```lua
-----------------------------------------------------------
-- GameConfig.lua — 游戏全局配置
-- 由 auto-workflow 从代码中提取的魔法数字生成
-- 修改此文件即可调整游戏参数，无需改动逻辑代码
-----------------------------------------------------------
local GameConfig = {}

-- ── 玩家 ────────────────────────────────────
GameConfig.Player = {
    moveSpeed       = 5.0,      -- 移动速度 (米/秒)
    jumpForce       = 7.0,      -- 跳跃初速度 (米/秒)
    maxHP           = 100,      -- 最大生命值
    invincibleTime  = 1.5,      -- 受伤后无敌时间 (秒)
}

-- ── 敌人 ────────────────────────────────────
GameConfig.Enemy = {
    spawnInterval   = 3.0,      -- 生成间隔 (秒)
    moveSpeed       = 2.5,      -- 移动速度 (米/秒)
    damage          = 10,       -- 伤害值
    detectionRange  = 8.0,      -- 检测范围 (米)
}

-- ── 关卡 ────────────────────────────────────
GameConfig.Level = {
    timeLimit       = 120,      -- 时间限制 (秒)
    coinValue       = 10,       -- 金币价值
    difficultyScale = 1.0,      -- 难度系数
}

-- ── 物理 ────────────────────────────────────
GameConfig.Physics = {
    gravity         = -9.81,    -- 重力加速度 (米/秒²)
    friction        = 0.3,      -- 摩擦系数
    restitution     = 0.2,      -- 弹性系数
}

-- ── 视觉 ────────────────────────────────────
GameConfig.Visual = {
    cameraDistance   = 10.0,    -- 相机距离 (米)
    cameraFOV        = 45.0,    -- 视野角度 (度)
    particleCount   = 20,       -- 粒子数量
}

return GameConfig
```

### 3.2 代码替换示例

替换前（散布魔法数字）：

```lua
-- ❌ 替换前
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if input:GetKeyDown(KEY_W) then
        charNode:Translate(Vector3.FORWARD * 5.0 * dt)   -- 5.0 是什么？
    end
    if hp <= 0 then
        spawnTimer = spawnTimer - dt
        if spawnTimer <= 0 then
            spawnTimer = 3.0                               -- 3.0 是什么？
            SpawnEnemy()
        end
    end
end
```

替换后（引用 GameConfig）：

```lua
-- ✅ 替换后
local GC = require("GameConfig")

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if input:GetKeyDown(KEY_W) then
        charNode:Translate(Vector3.FORWARD * GC.Player.moveSpeed * dt)
    end
    if hp <= 0 then
        spawnTimer = spawnTimer - dt
        if spawnTimer <= 0 then
            spawnTimer = GC.Enemy.spawnInterval
            SpawnEnemy()
        end
    end
end
```

---

## 4. 模块化拆分模板

### 4.1 标准模块格式

```lua
-----------------------------------------------------------
-- modules/EnemyManager.lua — 敌人管理模块
-----------------------------------------------------------
local GC = require("GameConfig")

local EnemyManager = {}

---@type Node[]
local enemies_ = {}
---@type Scene
local scene_ = nil

--- 初始化模块（在 Start() 或 CreateGameContent() 中调用）
---@param scene Scene
function EnemyManager.Init(scene)
    scene_ = scene
    enemies_ = {}
end

--- 每帧更新（在 HandleUpdate 中调用）
---@param dt number
function EnemyManager.Update(dt)
    for i = #enemies_, 1, -1 do
        local e = enemies_[i]
        if not e.alive then
            e.node:Remove()
            table.remove(enemies_, i)
        else
            EnemyManager.UpdateSingle(e, dt)
        end
    end
end

--- 生成一个敌人
---@param position Vector3
---@return table enemy
function EnemyManager.Spawn(position)
    local node = scene_:CreateChild("Enemy")
    node.position = position
    local model = node:CreateComponent("StaticModel")
    model.model = cache:GetResource("Model", "Models/Box.mdl")
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.2, 0.2)))
    model.material = mat

    local enemy = { node = node, alive = true, hp = GC.Enemy.maxHP or 50 }
    enemies_[#enemies_ + 1] = enemy
    return enemy
end

--- 更新单个敌人
---@param e table
---@param dt number
function EnemyManager.UpdateSingle(e, dt)
    -- 具体 AI 逻辑
end

--- 获取所有存活敌人
---@return table[]
function EnemyManager.GetAlive()
    local alive = {}
    for _, e in ipairs(enemies_) do
        if e.alive then alive[#alive + 1] = e end
    end
    return alive
end

--- 清理所有敌人
function EnemyManager.Clear()
    for _, e in ipairs(enemies_) do
        if e.node then e.node:Remove() end
    end
    enemies_ = {}
end

return EnemyManager
```

### 4.2 面板管理器模板

```lua
-----------------------------------------------------------
-- modules/PanelManager.lua — UI 面板状态管理
-----------------------------------------------------------
local UI = require("urhox-libs/UI")

local PanelManager = {}

---@type table<string, table>
local panels_ = {}
---@type string|nil
local currentPanel_ = nil

--- 注册面板
---@param name string
---@param createFn function 创建函数，返回 UI 节点
function PanelManager.Register(name, createFn)
    panels_[name] = { create = createFn, instance = nil }
end

--- 显示指定面板（隐藏当前面板）
---@param name string
function PanelManager.Show(name)
    -- 隐藏当前
    if currentPanel_ and panels_[currentPanel_] and panels_[currentPanel_].instance then
        UI.RemoveRoot(panels_[currentPanel_].instance)
        panels_[currentPanel_].instance = nil
    end
    -- 创建并显示新面板
    local p = panels_[name]
    if p then
        p.instance = p.create()
        UI.SetRoot(p.instance)
        currentPanel_ = name
    end
end

--- 隐藏当前面板
function PanelManager.HideCurrent()
    if currentPanel_ and panels_[currentPanel_] and panels_[currentPanel_].instance then
        UI.RemoveRoot(panels_[currentPanel_].instance)
        panels_[currentPanel_].instance = nil
        currentPanel_ = nil
    end
end

--- 获取当前面板名
---@return string|nil
function PanelManager.GetCurrent()
    return currentPanel_
end

return PanelManager
```

---

## 5. 入口文件模板

### 5.1 单机游戏入口

```lua
-----------------------------------------------------------
-- main.lua — 单机游戏入口
-----------------------------------------------------------
require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")
local GC = require("GameConfig")

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil

function Start()
    -- UI 初始化
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    CreateGameContent()

    -- 订阅更新
    SubscribeToEvent("Update", "HandleUpdate")
end

function CreateGameContent()
    -- TODO: 填充游戏内容
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- TODO: 每帧更新
end
```

### 5.2 多人游戏入口（客户端）

```lua
-----------------------------------------------------------
-- client_main.lua — 多人游戏客户端入口
-----------------------------------------------------------
require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")
local GC = require("GameConfig")

---@type Scene
local scene_ = nil

function Start()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 等待服务器准备就绪
    SubscribeToEvent("ServerReady", "HandleServerReady")
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleServerReady(eventType, eventData)
    -- 服务器已就绪，开始创建客户端内容
    CreateClientContent()
end

function CreateClientContent()
    -- TODO: 客户端场景与 UI
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- TODO: 客户端每帧更新
end
```

### 5.3 多人游戏入口（服务端）

```lua
-----------------------------------------------------------
-- server_main.lua — 多人游戏服务端入口
-----------------------------------------------------------
local GC = require("GameConfig")

---@type Scene
local scene_ = nil

function Start()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    CreateServerContent()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
end

function CreateServerContent()
    -- TODO: 服务端场景初始化（权威状态）
end

function HandleClientConnected(eventType, eventData)
    -- TODO: 玩家加入处理
end

function HandleClientDisconnected(eventType, eventData)
    -- TODO: 玩家离开处理
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- TODO: 服务端每帧更新（物理、AI、同步）
end
```

---

## 6. 构建检查模板

### 6.1 资源引用检查逻辑

```lua
-- 构建前资源引用检查（AI 辅助逻辑，非运行时代码）
-- AI 在构建前应执行以下检查步骤：

-- 步骤 1: 扫描 scripts/ 中所有 .lua 文件
-- 步骤 2: 提取 cache:GetResource(...) 调用的资源路径
-- 步骤 3: 对比 assets/ 目录中实际存在的文件
-- 步骤 4: 排除引擎内置资源（白名单如下）

local BUILTIN_RESOURCES = {
    -- 模型
    "Models/Box.mdl", "Models/Sphere.mdl", "Models/Plane.mdl",
    "Models/Cylinder.mdl", "Models/Cone.mdl", "Models/Torus.mdl",
    -- 材质
    "Materials/Skybox.xml",
    -- Technique
    "Techniques/PBR/PBRNoTexture.xml",
    "Techniques/PBR/PBRNoTextureAlpha.xml",
    "Techniques/NoTextureUnlit.xml",
    -- 字体
    "Fonts/MiSans-Regular.ttf",
    -- 脚本
    "LuaScripts/Utilities/Sample.lua",
}

-- 步骤 5: 报告缺失资源列表
-- 格式: [类型] 路径 (引用位置)
-- 示例:
--   [Texture2D] Textures/player.png (main.lua:42)
--   [Sound] Sounds/jump.ogg (PlayerController.lua:88)
```

### 6.2 代码规范检查项

```
AI 在构建前应检查的代码规范：

□ 数组索引从 1 开始（非 0）
□ eventData 使用 :GetInt() / :GetFloat() 访问
□ 鼠标按钮使用 MOUSEB_LEFT 枚举（非数字）
□ 键盘按键使用 KEY_* 枚举
□ 程序化材质使用 PBRNoTexture 系列 Technique
□ 碰撞体与 RigidBody 在同一节点
□ require 路径正确（urhox-libs 用点号，scripts 用引号）
□ 不使用 io 库（用 File 替代）
□ 不调用 graphics:SetMode()
□ NanoVG 渲染在 NanoVGRender 事件中
□ NanoVG 字体只创建一次（不在渲染循环中）
□ 单文件不超过 1500 行
```

---

## 使用说明

1. **场景模板** → 在 `CreateGameContent()` 中调用对应的 `Create*Scene()` 函数
2. **UI 模板** → 先调用 `InitUI()`，再按需创建各面板
3. **GameConfig** → 从代码提取魔法数字后生成，放在 `scripts/GameConfig.lua`
4. **模块模板** → 拆分大文件时，按此格式封装 Init/Update/return
5. **入口模板** → 根据 `.project/settings.json` 的 `multiplayer.enabled` 选择单机或多人版本
6. **构建检查** → 每次构建前由 AI 执行资源和规范检查
