---
name: game-environment-toolkit
description: |
  游戏环境供应工具包（Game Environment Toolkit, G.E.T.）。
  灵感源自 GitLab Environment Toolkit 的 Terraform + Ansible 双阶段基础设施即代码理念，
  将"基础设施供应 → 配置管理"的工业级工作流映射为 UrhoX 游戏的
  "场景供应 → 玩法配置"两阶段关卡构建体系。
  提供参考架构蓝图（Reference Architecture Blueprints）、
  动态实体清单（Dynamic Entity Inventory）、
  环境配置变量（Environment Config Variables）和
  多环境分层发布（Multi-Environment Layered Deploy）四大模块，
  让 AI 按声明式配置批量生成可复现、可扩展、可版本化的游戏关卡。

triggers:
  - 场景供应
  - 环境配置
  - 关卡蓝图
  - 参考架构
  - 基础设施即代码
  - 两阶段构建
  - 环境变量
  - 动态清单
  - 批量关卡
  - 场景模板
  - environment toolkit
  - scene provisioning
  - level blueprint
  - reference architecture
  - infrastructure as code
  - provision and configure
  - game environment

Use when: |
  (1) 用户需要按统一架构批量生成多个关卡/场景,
  (2) 用户说"场景供应""环境配置""关卡蓝图""参考架构",
  (3) 用户需要两阶段工作流：先搭建场景基础设施再配置玩法逻辑,
  (4) 用户需要声明式配置驱动场景生成（类似 IaC 理念）,
  (5) 用户需要环境变量/配置管理系统来控制关卡参数,
  (6) 用户说"environment toolkit""scene provisioning""level blueprint",
  (7) 用户需要跨平台/多分辨率场景适配方案,
  (8) 用户需要动态实体注册和清单管理。
---

# Game Environment Toolkit (G.E.T.)

> **从 GitLab Environment Toolkit 到游戏关卡供应工具包**
>
> 像管理云基础设施一样管理你的游戏关卡——
> 声明式蓝图、两阶段构建、配置驱动、可版本化复现。

---

## 1. 概念映射：GET → 游戏开发

| GitLab Environment Toolkit | Game Environment Toolkit | 说明 |
|----------------------------|--------------------------|------|
| **Terraform** (基础设施供应) | **Scene Provisioner** (场景供应器) | 创建地形、天空、光照、物理世界等场景基础设施 |
| **Ansible** (配置管理) | **Gameplay Configurator** (玩法配置器) | 配置敌人波次、道具分布、触发器、NPC 行为 |
| **Reference Architecture** (参考架构) | **Scene Blueprint** (场景蓝图) | 预定义的关卡架构模板（开放世界、竞技场、线性关卡等） |
| **vars.yml** (环境变量) | **env-config.json** (环境配置) | 控制关卡参数的声明式配置文件 |
| **Dynamic Inventory** (动态清单) | **Entity Registry** (实体注册表) | 通过标签追踪场景中每个实体的角色和状态 |
| **Multi-cloud** (GCP/AWS/Azure) | **Multi-target** (移动/PC/多分辨率) | 同一蓝图适配不同目标平台和分辨率 |
| **Geo multi-site** (多站点部署) | **Multi-level deploy** (多关卡部署) | 从同一蓝图批量生成系列关卡变体 |
| **Provisioning → Configuration** | **Provision → Configure** | 两阶段工作流：先建基础设施，再配置逻辑 |
| **Terraform modules** (可复用模块) | **Provision Modules** (供应模块) | 可复用的场景组件（光照方案、地形生成器、天空盒等） |
| **Ansible roles/playbooks** | **Config Playbooks** (配置剧本) | 可复用的玩法配置方案（敌人 AI、道具系统、得分规则） |
| **Cloud services** (托管服务) | **Engine services** (引擎服务) | 物理、音频、粒子等引擎提供的底层服务 |
| **SSL/TLS** (安全层) | **Save encryption** (存档安全) | 关卡状态存档的安全持久化 |

---

## 2. 设计原则

### 2.1 从 GET 继承的核心理念

1. **Opinionated by design（有立场的设计）**
   - 每种场景类型只提供一种推荐架构，降低选择焦虑
   - 遵循 UrhoX 引擎最佳实践，不提供反模式选项

2. **Two-phase workflow（两阶段工作流）**
   - **Phase 1: Provision** — 搭建场景基础设施（地形、光照、天空、物理边界）
   - **Phase 2: Configure** — 配置玩法逻辑（敌人、道具、触发器、得分规则）
   - 两阶段解耦，允许同一基础设施搭配不同玩法

3. **Declarative over imperative（声明式优于命令式）**
   - 用 JSON 蓝图描述"我要什么"，而非"怎么做"
   - AI 解析蓝图后自动执行供应和配置

4. **Reference Architecture driven（参考架构驱动）**
   - 提供经过验证的场景架构模板
   - 开发者选择架构 → 填写参数 → 自动生成

5. **Shared Responsibility Model（共享责任模型）**
   - 工具包负责：场景结构、组件编排、配置注入
   - 开发者负责：游戏创意、美术资源、玩法调优

---

## 3. 四大核心模块

```
┌────────────────────────────────────────────────────────┐
│                Game Environment Toolkit                 │
├──────────────┬──────────────┬───────────┬──────────────┤
│  Blueprint   │  Provisioner │ Configuror│   Registry   │
│  场景蓝图     │  场景供应器   │ 玩法配置器 │  实体注册表   │
├──────────────┼──────────────┼───────────┼──────────────┤
│ JSON 架构定义 │ 地形/光照/   │ 敌人/道具/ │ 标签追踪/    │
│ 参考模板选择  │ 天空/物理/   │ 触发器/    │ 状态查询/    │
│ 参数覆写     │ 边界/相机    │ NPC/得分   │ 批量操作     │
└──────────────┴──────────────┴───────────┴──────────────┘
         ↓               ↓              ↓            ↓
    env-config.json  Provision()   Configure()  GetByTag()
```

### 3.1 Module A: Scene Blueprint (场景蓝图)

**灵感：GET 的 Reference Architecture**

场景蓝图是一个 JSON 文件，声明了关卡的完整架构——基础设施层和玩法层分离定义。

#### 蓝图格式：`scene-blueprint-v1`

```json
{
  "format": "scene-blueprint-v1",
  "meta": {
    "name": "forest-arena-01",
    "blueprint": "arena",
    "description": "森林竞技场 - 第一关",
    "version": "1.0.0",
    "target": ["mobile", "pc"]
  },
  "provision": {
    "terrain": {
      "type": "heightmap",
      "size": [100, 100],
      "material": "grass-dirt-blend",
      "heightmap_source": "generate",
      "params": { "octaves": 4, "amplitude": 8.0, "frequency": 0.02 }
    },
    "skybox": {
      "type": "procedural",
      "preset": "sunset",
      "params": { "sun_angle": 30, "cloud_density": 0.6 }
    },
    "lighting": {
      "preset": "outdoor-warm",
      "directional": {
        "direction": [-0.5, -1.0, -0.3],
        "color": [1.0, 0.95, 0.8],
        "intensity": 1.2
      },
      "ambient": { "color": [0.3, 0.35, 0.4], "intensity": 0.5 }
    },
    "physics": {
      "gravity": [0, -9.81, 0],
      "boundaries": {
        "type": "box",
        "min": [-50, -10, -50],
        "max": [50, 50, 50]
      }
    },
    "camera": {
      "type": "third-person",
      "offset": [0, 1.7, 0],
      "distance": 5.0,
      "fov": 45
    },
    "zones": [
      { "name": "spawn-area", "bounds": { "center": [0, 0, 0], "radius": 5 }, "tags": ["safe", "spawn"] },
      { "name": "combat-zone", "bounds": { "center": [0, 0, 30], "radius": 20 }, "tags": ["combat", "main"] },
      { "name": "loot-cave", "bounds": { "center": [25, -2, 40], "radius": 8 }, "tags": ["loot", "secret"] }
    ]
  },
  "configure": {
    "enemies": {
      "waves": [
        {
          "id": "wave-1",
          "trigger": "zone-enter:combat-zone",
          "spawn_zone": "combat-zone",
          "units": [
            { "type": "goblin", "count": 5, "level": 1 },
            { "type": "wolf", "count": 2, "level": 1 }
          ],
          "interval_sec": 2.0,
          "on_clear": "wave-2"
        },
        {
          "id": "wave-2",
          "trigger": "on-clear:wave-1",
          "spawn_zone": "combat-zone",
          "units": [
            { "type": "goblin", "count": 8, "level": 2 },
            { "type": "orc-chief", "count": 1, "level": 3 }
          ],
          "interval_sec": 1.5,
          "on_clear": "level-complete"
        }
      ]
    },
    "collectibles": [
      { "type": "health-potion", "zone": "combat-zone", "count": 3, "respawn_sec": 30 },
      { "type": "gold-chest", "zone": "loot-cave", "count": 1, "respawn_sec": -1 }
    ],
    "triggers": [
      { "name": "boss-music", "event": "zone-enter:combat-zone", "action": "play-bgm", "params": { "track": "battle-theme" } },
      { "name": "victory", "event": "on-clear:wave-2", "action": "show-ui", "params": { "panel": "victory-screen" } }
    ],
    "scoring": {
      "goblin_kill": 10,
      "wolf_kill": 25,
      "orc_chief_kill": 100,
      "health_potion_collect": 5,
      "gold_chest_collect": 50,
      "time_bonus": { "threshold_sec": 120, "bonus": 200 }
    },
    "npc": [
      {
        "id": "guide-npc",
        "type": "friendly",
        "position": [2, 0, 0],
        "zone": "spawn-area",
        "dialogue": ["欢迎来到森林竞技场！", "前方有敌人出没，小心！"],
        "tags": ["guide", "tutorial"]
      }
    ]
  },
  "env_overrides": {
    "difficulty": {
      "easy":   { "configure.enemies.waves[0].units[0].count": 3, "configure.scoring.time_bonus.threshold_sec": 180 },
      "normal": {},
      "hard":   { "configure.enemies.waves[0].units[0].count": 8, "configure.enemies.waves[1].units[1].count": 2 }
    },
    "platform": {
      "mobile": { "provision.terrain.size": [60, 60], "provision.camera.distance": 7.0 },
      "pc":     { "provision.terrain.size": [120, 120], "provision.lighting.directional.intensity": 1.5 }
    }
  }
}
```

#### 蓝图加载与验证

```lua
-- scripts/get/BlueprintLoader.lua
local cjson = require("cjson")

local BlueprintLoader = {}

--- 从 JSON 文件加载蓝图
---@param path string 相对路径，如 "data/levels/forest-arena-01.json"
---@return table|nil blueprint 解析后的蓝图表
---@return string|nil error 错误信息
function BlueprintLoader.Load(path)
    local file = File:new(path, FILE_READ)
    if not file or not file:IsOpen() then
        return nil, "无法打开蓝图文件: " .. path
    end

    local content = file:ReadString()
    file:Close()

    local ok, bp = pcall(cjson.decode, content)
    if not ok then
        return nil, "JSON 解析失败: " .. tostring(bp)
    end

    -- 格式验证
    if bp.format ~= "scene-blueprint-v1" then
        return nil, "不支持的蓝图格式: " .. tostring(bp.format)
    end

    -- 必填字段检查
    if not bp.provision then
        return nil, "蓝图缺少 provision 段"
    end
    if not bp.configure then
        return nil, "蓝图缺少 configure 段"
    end

    log:Write(LOG_INFO, "[G.E.T.] 蓝图加载成功: " .. (bp.meta and bp.meta.name or "unnamed"))
    return bp, nil
end

--- 应用环境覆写
---@param blueprint table 蓝图表
---@param env_key string 覆写类别 ("difficulty", "platform" 等)
---@param env_value string 覆写值 ("easy", "mobile" 等)
---@return table blueprint 修改后的蓝图
function BlueprintLoader.ApplyOverrides(blueprint, env_key, env_value)
    local overrides = blueprint.env_overrides
    if not overrides or not overrides[env_key] then
        log:Write(LOG_WARNING, "[G.E.T.] 无覆写配置: " .. env_key)
        return blueprint
    end

    local patches = overrides[env_key][env_value]
    if not patches then
        log:Write(LOG_WARNING, "[G.E.T.] 无覆写值: " .. env_key .. "." .. env_value)
        return blueprint
    end

    for path, value in pairs(patches) do
        BlueprintLoader._SetNestedValue(blueprint, path, value)
        log:Write(LOG_INFO, "[G.E.T.] 覆写: " .. path .. " = " .. tostring(value))
    end

    return blueprint
end

--- 内部：按路径设置嵌套值
function BlueprintLoader._SetNestedValue(tbl, path, value)
    local keys = {}
    for segment in path:gmatch("[^%.]+") do
        -- 处理数组索引 [n]
        local name, idx = segment:match("^(%w+)%[(%d+)%]$")
        if name then
            table.insert(keys, name)
            table.insert(keys, tonumber(idx) + 1)  -- Lua 1-based
        else
            table.insert(keys, segment)
        end
    end

    local current = tbl
    for i = 1, #keys - 1 do
        local k = keys[i]
        if current[k] == nil then return end
        current = current[k]
    end
    current[keys[#keys]] = value
end

return BlueprintLoader
```

---

### 3.2 Module B: Scene Provisioner (场景供应器)

**灵感：GET 的 Terraform 阶段**

场景供应器读取蓝图的 `provision` 段，创建场景基础设施。

```lua
-- scripts/get/SceneProvisioner.lua

local SceneProvisioner = {}

--- 执行供应阶段
---@param scene Scene 目标场景
---@param provision table 蓝图的 provision 段
---@return table inventory 供应清单（所有创建的节点及标签）
function SceneProvisioner.Execute(scene, provision)
    local inventory = {
        nodes = {},      -- { name = node }
        tags = {},       -- { tag = { node1, node2, ... } }
        zones = {},      -- { zoneName = { center, radius, tags } }
        stats = {
            nodes_created = 0,
            components_created = 0,
            phase = "provision",
            started_at = os.clock()
        }
    }

    log:Write(LOG_INFO, "[G.E.T.] ═══ Phase 1: PROVISION 开始 ═══")

    -- Step 1: 物理世界
    if provision.physics then
        SceneProvisioner._ProvisionPhysics(scene, provision.physics, inventory)
    end

    -- Step 2: 天空盒
    if provision.skybox then
        SceneProvisioner._ProvisionSkybox(scene, provision.skybox, inventory)
    end

    -- Step 3: 光照
    if provision.lighting then
        SceneProvisioner._ProvisionLighting(scene, provision.lighting, inventory)
    end

    -- Step 4: 地形
    if provision.terrain then
        SceneProvisioner._ProvisionTerrain(scene, provision.terrain, inventory)
    end

    -- Step 5: 相机
    if provision.camera then
        SceneProvisioner._ProvisionCamera(scene, provision.camera, inventory)
    end

    -- Step 6: 区域定义
    if provision.zones then
        for _, zone in ipairs(provision.zones) do
            SceneProvisioner._ProvisionZone(scene, zone, inventory)
        end
    end

    inventory.stats.completed_at = os.clock()
    inventory.stats.duration = inventory.stats.completed_at - inventory.stats.started_at

    log:Write(LOG_INFO, string.format(
        "[G.E.T.] ═══ Phase 1: PROVISION 完成 ═══ 节点: %d, 组件: %d, 耗时: %.3fs",
        inventory.stats.nodes_created,
        inventory.stats.components_created,
        inventory.stats.duration
    ))

    return inventory
end

--- 供应物理世界
function SceneProvisioner._ProvisionPhysics(scene, config, inventory)
    scene:CreateComponent("PhysicsWorld")
    inventory.stats.components_created = inventory.stats.components_created + 1

    if config.gravity then
        local pw = scene:GetComponent("PhysicsWorld")
        pw.gravity = Vector3(config.gravity[1], config.gravity[2], config.gravity[3])
    end

    -- 物理边界（不可见碰撞墙）
    if config.boundaries and config.boundaries.type == "box" then
        local min = config.boundaries.min
        local max = config.boundaries.max
        SceneProvisioner._CreateBoundaryWall(scene, "boundary-floor",
            Vector3((min[1]+max[1])/2, min[2], (min[3]+max[3])/2),
            Vector3(max[1]-min[1], 1, max[3]-min[3]),
            inventory)
    end

    SceneProvisioner._RegisterNode(inventory, "physics-world", scene, {"system", "physics"})
    log:Write(LOG_INFO, "[G.E.T.] 物理世界已供应")
end

--- 供应天空盒
function SceneProvisioner._ProvisionSkybox(scene, config, inventory)
    local skyNode = scene:CreateChild("sky")
    local skybox = skyNode:CreateComponent("Skybox")
    skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    if config.preset then
        -- 使用预设材质
        local materialPath = "Materials/Skybox-" .. config.preset .. ".xml"
        local mat = cache:GetResource("Material", materialPath)
        if mat then
            skybox:SetMaterial(mat)
        else
            log:Write(LOG_WARNING, "[G.E.T.] 天空盒预设未找到: " .. materialPath)
        end
    end

    inventory.stats.nodes_created = inventory.stats.nodes_created + 1
    inventory.stats.components_created = inventory.stats.components_created + 1
    SceneProvisioner._RegisterNode(inventory, "sky", skyNode, {"visual", "skybox"})
    log:Write(LOG_INFO, "[G.E.T.] 天空盒已供应: " .. (config.preset or "default"))
end

--- 供应光照
function SceneProvisioner._ProvisionLighting(scene, config, inventory)
    -- Zone（环境光 + 雾效）
    local zoneNode = scene:CreateChild("zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))

    if config.ambient then
        local c = config.ambient.color
        zone.ambientColor = Color(c[1], c[2], c[3]) * (config.ambient.intensity or 1.0)
    end

    -- 方向光
    if config.directional then
        local lightNode = scene:CreateChild("directional-light")
        local d = config.directional.direction
        lightNode.direction = Vector3(d[1], d[2], d[3])

        local light = lightNode:CreateComponent("Light")
        light.lightType = LIGHT_DIRECTIONAL
        light.castShadows = true

        local c = config.directional.color
        light.color = Color(c[1], c[2], c[3])
        light.brightness = config.directional.intensity or 1.0

        inventory.stats.nodes_created = inventory.stats.nodes_created + 1
        inventory.stats.components_created = inventory.stats.components_created + 1
        SceneProvisioner._RegisterNode(inventory, "directional-light", lightNode, {"visual", "light"})
    end

    inventory.stats.nodes_created = inventory.stats.nodes_created + 1
    inventory.stats.components_created = inventory.stats.components_created + 1
    SceneProvisioner._RegisterNode(inventory, "zone", zoneNode, {"visual", "zone"})
    log:Write(LOG_INFO, "[G.E.T.] 光照已供应")
end

--- 供应地形（简化：使用平面 + 缩放模拟）
function SceneProvisioner._ProvisionTerrain(scene, config, inventory)
    local terrainNode = scene:CreateChild("terrain")
    local size = config.size or {100, 100}

    local model = terrainNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
    terrainNode.scale = Vector3(size[1], 1, size[2])
    terrainNode.position = Vector3(0, 0, 0)

    -- 碰撞体
    local body = terrainNode:CreateComponent("RigidBody")
    body.mass = 0  -- 静态
    local shape = terrainNode:CreateComponent("CollisionShape")
    shape:SetBox(Vector3(1, 0.1, 1))  -- Plane 模型的归一化尺寸

    -- 材质（如果指定了类型）
    if config.material then
        local matNode = Material:new()
        matNode:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        matNode:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.5, 0.2, 1.0)))
        matNode:SetShaderParameter("Roughness", Variant(0.8))
        model:SetMaterial(matNode)
    end

    inventory.stats.nodes_created = inventory.stats.nodes_created + 1
    inventory.stats.components_created = inventory.stats.components_created + 3
    SceneProvisioner._RegisterNode(inventory, "terrain", terrainNode, {"visual", "terrain", "ground"})
    log:Write(LOG_INFO, string.format("[G.E.T.] 地形已供应: %dx%d", size[1], size[2]))
end

--- 供应相机
function SceneProvisioner._ProvisionCamera(scene, config, inventory)
    local cameraNode = scene:CreateChild("camera")

    local camera = cameraNode:CreateComponent("Camera")
    camera.fov = config.fov or 45

    if config.type == "third-person" then
        -- 第三人称相机：记录参数，运行时由 ThirdPersonCamera 库驱动
        cameraNode:SetVar("cam_type", Variant("third-person"))
        cameraNode:SetVar("cam_distance", Variant(config.distance or 5.0))
        if config.offset then
            cameraNode:SetVar("cam_offset_x", Variant(config.offset[1] or 0))
            cameraNode:SetVar("cam_offset_y", Variant(config.offset[2] or 1.7))
            cameraNode:SetVar("cam_offset_z", Variant(config.offset[3] or 0))
        end
    elseif config.type == "fps" then
        cameraNode:SetVar("cam_type", Variant("fps"))
        cameraNode.position = Vector3(0, 1.7, 0)
    else
        -- 自由相机
        cameraNode:SetVar("cam_type", Variant("free"))
        cameraNode.position = Vector3(0, 10, -20)
        cameraNode:LookAt(Vector3(0, 0, 0))
    end

    inventory.stats.nodes_created = inventory.stats.nodes_created + 1
    inventory.stats.components_created = inventory.stats.components_created + 1
    SceneProvisioner._RegisterNode(inventory, "camera", cameraNode, {"system", "camera"})
    log:Write(LOG_INFO, "[G.E.T.] 相机已供应: " .. (config.type or "free"))
end

--- 供应区域
function SceneProvisioner._ProvisionZone(scene, zone, inventory)
    local zoneNode = scene:CreateChild(zone.name)
    local c = zone.bounds.center
    zoneNode.position = Vector3(c[1], c[2], c[3])

    -- 存储区域元数据
    zoneNode:SetVar("zone_radius", Variant(zone.bounds.radius or 10))
    zoneNode:SetVar("zone_name", Variant(zone.name))

    -- 注册到清单
    inventory.zones[zone.name] = {
        node = zoneNode,
        center = Vector3(c[1], c[2], c[3]),
        radius = zone.bounds.radius,
        tags = zone.tags or {}
    }

    if zone.tags then
        for _, tag in ipairs(zone.tags) do
            SceneProvisioner._AddTag(inventory, tag, zoneNode)
        end
    end

    inventory.stats.nodes_created = inventory.stats.nodes_created + 1
    SceneProvisioner._RegisterNode(inventory, zone.name, zoneNode, zone.tags or {})
    log:Write(LOG_INFO, "[G.E.T.] 区域已供应: " .. zone.name)
end

--- 创建边界墙
function SceneProvisioner._CreateBoundaryWall(scene, name, pos, size, inventory)
    local wallNode = scene:CreateChild(name)
    wallNode.position = pos
    local body = wallNode:CreateComponent("RigidBody")
    body.mass = 0
    local shape = wallNode:CreateComponent("CollisionShape")
    shape:SetBox(size)
    inventory.stats.nodes_created = inventory.stats.nodes_created + 1
    inventory.stats.components_created = inventory.stats.components_created + 2
    SceneProvisioner._RegisterNode(inventory, name, wallNode, {"system", "boundary"})
end

--- 注册节点到清单
function SceneProvisioner._RegisterNode(inventory, name, node, tags)
    inventory.nodes[name] = node
    if tags then
        for _, tag in ipairs(tags) do
            SceneProvisioner._AddTag(inventory, tag, node)
        end
    end
end

--- 添加标签
function SceneProvisioner._AddTag(inventory, tag, node)
    if not inventory.tags[tag] then
        inventory.tags[tag] = {}
    end
    table.insert(inventory.tags[tag], node)
end

return SceneProvisioner
```

---

### 3.3 Module C: Gameplay Configurator (玩法配置器)

**灵感：GET 的 Ansible 阶段**

玩法配置器读取蓝图的 `configure` 段，在已供应的场景上配置游戏逻辑。

```lua
-- scripts/get/GameplayConfigurator.lua

local GameplayConfigurator = {}

--- 执行配置阶段
---@param scene Scene 已供应的场景
---@param configure table 蓝图的 configure 段
---@param inventory table 供应阶段的清单
---@return table state 配置后的游戏状态
function GameplayConfigurator.Execute(scene, configure, inventory)
    local state = {
        enemies = { waves = {}, active_wave = nil, total_killed = 0 },
        collectibles = {},
        triggers = {},
        scoring = configure.scoring or {},
        npcs = {},
        stats = {
            phase = "configure",
            started_at = os.clock(),
            entities_configured = 0
        }
    }

    log:Write(LOG_INFO, "[G.E.T.] ═══ Phase 2: CONFIGURE 开始 ═══")

    -- Step 1: 配置敌人波次
    if configure.enemies and configure.enemies.waves then
        GameplayConfigurator._ConfigureWaves(scene, configure.enemies.waves, inventory, state)
    end

    -- Step 2: 配置可收集物品
    if configure.collectibles then
        GameplayConfigurator._ConfigureCollectibles(scene, configure.collectibles, inventory, state)
    end

    -- Step 3: 配置触发器
    if configure.triggers then
        GameplayConfigurator._ConfigureTriggers(configure.triggers, inventory, state)
    end

    -- Step 4: 配置 NPC
    if configure.npc then
        GameplayConfigurator._ConfigureNPCs(scene, configure.npc, inventory, state)
    end

    state.stats.completed_at = os.clock()
    state.stats.duration = state.stats.completed_at - state.stats.started_at

    log:Write(LOG_INFO, string.format(
        "[G.E.T.] ═══ Phase 2: CONFIGURE 完成 ═══ 实体: %d, 耗时: %.3fs",
        state.stats.entities_configured,
        state.stats.duration
    ))

    return state
end

--- 配置敌人波次（注册元数据，实际生成延迟到触发时）
function GameplayConfigurator._ConfigureWaves(scene, waves, inventory, state)
    for i, wave in ipairs(waves) do
        state.enemies.waves[wave.id] = {
            index = i,
            config = wave,
            status = "pending",   -- pending → active → cleared
            spawned = {},
            killed_count = 0,
            total_count = 0
        }

        -- 计算总数
        for _, unit in ipairs(wave.units) do
            state.enemies.waves[wave.id].total_count =
                state.enemies.waves[wave.id].total_count + unit.count
        end

        state.stats.entities_configured = state.stats.entities_configured + 1
        log:Write(LOG_INFO, string.format(
            "[G.E.T.] 波次已配置: %s (%d 种单位, 共 %d 个)",
            wave.id, #wave.units, state.enemies.waves[wave.id].total_count
        ))
    end
end

--- 配置可收集物品（在指定区域随机放置）
function GameplayConfigurator._ConfigureCollectibles(scene, collectibles, inventory, state)
    for _, item in ipairs(collectibles) do
        local zone = inventory.zones[item.zone]
        if not zone then
            log:Write(LOG_WARNING, "[G.E.T.] 区域未找到: " .. item.zone)
            goto continue_collectible
        end

        for j = 1, item.count do
            local angle = math.random() * math.pi * 2
            local dist = math.random() * zone.radius * 0.8
            local x = zone.center.x + math.cos(angle) * dist
            local z = zone.center.z + math.sin(angle) * dist

            local itemNode = scene:CreateChild(item.type .. "-" .. j)
            itemNode.position = Vector3(x, zone.center.y + 0.5, z)
            itemNode:SetVar("item_type", Variant(item.type))
            itemNode:SetVar("respawn_sec", Variant(item.respawn_sec or -1))

            table.insert(state.collectibles, {
                node = itemNode,
                type = item.type,
                collected = false,
                respawn_sec = item.respawn_sec
            })
            state.stats.entities_configured = state.stats.entities_configured + 1
        end

        log:Write(LOG_INFO, string.format(
            "[G.E.T.] 收集物已配置: %s x%d @ %s", item.type, item.count, item.zone
        ))

        ::continue_collectible::
    end
end

--- 配置触发器（事件绑定）
function GameplayConfigurator._ConfigureTriggers(triggers, inventory, state)
    for _, trigger in ipairs(triggers) do
        state.triggers[trigger.name] = {
            config = trigger,
            fired = false
        }
        state.stats.entities_configured = state.stats.entities_configured + 1
        log:Write(LOG_INFO, "[G.E.T.] 触发器已配置: " .. trigger.name .. " -> " .. trigger.action)
    end
end

--- 配置 NPC
function GameplayConfigurator._ConfigureNPCs(scene, npcs, inventory, state)
    for _, npc in ipairs(npcs) do
        local npcNode = scene:CreateChild(npc.id)
        local pos = npc.position
        npcNode.position = Vector3(pos[1], pos[2], pos[3])
        npcNode:SetVar("npc_type", Variant(npc.type or "friendly"))
        npcNode:SetVar("npc_id", Variant(npc.id))

        -- 存储对话数据
        if npc.dialogue then
            for di, line in ipairs(npc.dialogue) do
                npcNode:SetVar("dialogue_" .. di, Variant(line))
            end
            npcNode:SetVar("dialogue_count", Variant(#npc.dialogue))
        end

        state.npcs[npc.id] = {
            node = npcNode,
            config = npc,
            dialogue_index = 1
        }
        state.stats.entities_configured = state.stats.entities_configured + 1
        log:Write(LOG_INFO, "[G.E.T.] NPC 已配置: " .. npc.id)
    end
end

return GameplayConfigurator
```

---

### 3.4 Module D: Entity Registry (实体注册表)

**灵感：GET 的 Dynamic Inventory + Ansible Tags**

实体注册表提供按标签查询、批量操作和状态追踪能力。

```lua
-- scripts/get/EntityRegistry.lua

local EntityRegistry = {}

--- 按标签查询节点
---@param inventory table 供应清单
---@param tag string 标签名
---@return table nodes 匹配的节点列表
function EntityRegistry.GetByTag(inventory, tag)
    return inventory.tags[tag] or {}
end

--- 按多标签交集查询
---@param inventory table 供应清单
---@param tags table 标签列表
---@return table nodes 同时包含所有标签的节点
function EntityRegistry.GetByAllTags(inventory, tags)
    if #tags == 0 then return {} end

    local first = EntityRegistry.GetByTag(inventory, tags[1])
    if #tags == 1 then return first end

    local result = {}
    for _, node in ipairs(first) do
        local has_all = true
        for i = 2, #tags do
            local found = false
            for _, n in ipairs(EntityRegistry.GetByTag(inventory, tags[i])) do
                if n == node then found = true; break end
            end
            if not found then has_all = false; break end
        end
        if has_all then table.insert(result, node) end
    end
    return result
end

--- 检查节点是否在区域内
---@param position Vector3 位置
---@param zone table 区域信息 { center, radius }
---@return boolean
function EntityRegistry.IsInZone(position, zone)
    local dx = position.x - zone.center.x
    local dz = position.z - zone.center.z
    return (dx * dx + dz * dz) <= (zone.radius * zone.radius)
end

--- 获取区域内所有注册节点
---@param inventory table 供应清单
---@param zoneName string 区域名
---@return table nodes 区域内的节点列表
function EntityRegistry.GetNodesInZone(inventory, zoneName)
    local zone = inventory.zones[zoneName]
    if not zone then return {} end

    local result = {}
    for name, node in pairs(inventory.nodes) do
        if EntityRegistry.IsInZone(node.position, zone) then
            table.insert(result, { name = name, node = node })
        end
    end
    return result
end

--- 统计信息
---@param inventory table 供应清单
---@return table stats 统计数据
function EntityRegistry.GetStats(inventory)
    local tag_count = 0
    for _ in pairs(inventory.tags) do tag_count = tag_count + 1 end

    local node_count = 0
    for _ in pairs(inventory.nodes) do node_count = node_count + 1 end

    local zone_count = 0
    for _ in pairs(inventory.zones) do zone_count = zone_count + 1 end

    return {
        total_nodes = node_count,
        total_tags = tag_count,
        total_zones = zone_count,
        provision_stats = inventory.stats
    }
end

--- 序列化清单摘要到 JSON（用于存档）
---@param inventory table 供应清单
---@return string json JSON 字符串
function EntityRegistry.SerializeSummary(inventory)
    local cjson = require("cjson")
    local summary = {
        nodes = {},
        zones = {},
        stats = inventory.stats
    }

    for name, node in pairs(inventory.nodes) do
        summary.nodes[name] = {
            position = { node.position.x, node.position.y, node.position.z }
        }
    end

    for name, zone in pairs(inventory.zones) do
        summary.zones[name] = {
            center = { zone.center.x, zone.center.y, zone.center.z },
            radius = zone.radius,
            tags = zone.tags
        }
    end

    return cjson.encode(summary)
end

return EntityRegistry
```

---

## 4. 两阶段工作流：完整执行流程

**灵感：GET 的 Provisioning → Configuration 双阶段**

```
┌─────────────────────────────────────────────────────────────────┐
│                    G.E.T. 两阶段工作流                           │
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │  加载蓝图      │ ──→ │  Phase 1:     │ ──→ │  Phase 2:     │   │
│  │  BlueprintLoad│     │  PROVISION   │     │  CONFIGURE   │   │
│  │  + 覆写应用    │     │  场景基础设施  │     │  玩法逻辑     │   │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│         ↓                    ↓                    ↓              │
│    env-config.json      inventory             game state        │
│    (声明式输入)         (供应清单)            (运行时状态)        │
└─────────────────────────────────────────────────────────────────┘
```

### 4.1 主入口整合

```lua
-- scripts/main.lua
-- Game Environment Toolkit 主入口

local BlueprintLoader = require("get.BlueprintLoader")
local SceneProvisioner = require("get.SceneProvisioner")
local GameplayConfigurator = require("get.GameplayConfigurator")
local EntityRegistry = require("get.EntityRegistry")

require "LuaScripts/Utilities/Sample"

--- 全局变量
---@type Scene
local scene_ = nil
---@type table
local inventory_ = nil
---@type table
local gameState_ = nil

function Start()
    -- 1. 加载蓝图
    local blueprint, err = BlueprintLoader.Load("data/levels/forest-arena-01.json")
    if not blueprint then
        log:Write(LOG_ERROR, "[G.E.T.] 蓝图加载失败: " .. err)
        return
    end

    -- 2. 应用环境覆写
    blueprint = BlueprintLoader.ApplyOverrides(blueprint, "difficulty", "normal")

    -- 检测平台并应用对应覆写
    local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")
    local platform = PlatformUtils.IsMobilePlatform() and "mobile" or "pc"
    blueprint = BlueprintLoader.ApplyOverrides(blueprint, "platform", platform)

    -- 3. 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    -- 4. Phase 1: PROVISION（场景基础设施）
    inventory_ = SceneProvisioner.Execute(scene_, blueprint.provision)

    -- 5. Phase 2: CONFIGURE（玩法逻辑）
    gameState_ = GameplayConfigurator.Execute(scene_, blueprint.configure, inventory_)

    -- 6. 设置视口
    local cameraNode = inventory_.nodes["camera"]
    if cameraNode then
        renderer:SetViewport(0, Viewport:new(scene_, cameraNode:GetComponent("Camera")))
    end

    -- 7. 输出清单统计
    local stats = EntityRegistry.GetStats(inventory_)
    log:Write(LOG_INFO, string.format(
        "[G.E.T.] 环境就绪 — 节点: %d, 标签: %d, 区域: %d",
        stats.total_nodes, stats.total_tags, stats.total_zones
    ))

    -- 8. 注册更新事件
    SubscribeToEvent("Update", "HandleUpdate")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 运行时逻辑：触发器检测、波次管理等
    -- 基于 gameState_ 和 inventory_ 驱动游戏循环
end
```

---

## 5. 参考架构蓝图库

**灵感：GET 的 Reference Architecture (1k-50k users)**

G.E.T. 提供 6 种预定义参考架构，覆盖常见游戏类型：

| 架构 ID | 类型 | 适用场景 | 复杂度 |
|---------|------|---------|--------|
| `arena` | 竞技场 | 波次生存、Boss 战 | 中等 |
| `open-world` | 开放世界 | 沙盒探索、RPG | 高 |
| `linear` | 线性关卡 | 平台跳跃、跑酷 | 低 |
| `hub-spoke` | 中心辐射 | 城镇 + 副本、任务中心 | 中等 |
| `procedural` | 随机生成 | Roguelike、无限跑酷 | 高 |
| `multiplayer` | 多人对战 | 竞速、对战、合作 | 高 |

### 5.1 架构选择决策树

```
你的游戏是什么类型？
│
├─ 战斗为核心？
│   ├─ 固定区域？ ──→ arena（竞技场）
│   └─ 自由探索？ ──→ open-world（开放世界）
│
├─ 关卡推进为核心？
│   ├─ 线性流程？ ──→ linear（线性关卡）
│   └─ 中心 + 分支？ ──→ hub-spoke（中心辐射）
│
├─ 随机性为核心？ ──→ procedural（随机生成）
│
└─ 多人交互为核心？ ──→ multiplayer（多人对战）
```

---

## 6. 环境配置变量系统

**灵感：GET 的 vars.yml**

### 6.1 配置文件格式：`env-config-v1`

```json
{
  "format": "env-config-v1",
  "version": "1.0.0",
  "environments": {
    "dev": {
      "debug_mode": true,
      "show_zones": true,
      "show_spawn_points": true,
      "enemy_ai_enabled": false,
      "god_mode": true,
      "time_scale": 1.0
    },
    "staging": {
      "debug_mode": true,
      "show_zones": false,
      "enemy_ai_enabled": true,
      "god_mode": false,
      "time_scale": 1.0
    },
    "production": {
      "debug_mode": false,
      "show_zones": false,
      "show_spawn_points": false,
      "enemy_ai_enabled": true,
      "god_mode": false,
      "time_scale": 1.0
    }
  },
  "current": "dev"
}
```

### 6.2 配置加载器

```lua
-- scripts/get/EnvConfig.lua
local cjson = require("cjson")

local EnvConfig = {}

---@type table 当前环境配置
local _config = {}
---@type string 当前环境名
local _env_name = "production"

--- 加载环境配置文件
---@param path string 配置文件路径
---@param env string|nil 指定环境（不指定则用 current 字段）
function EnvConfig.Load(path, env)
    local file = File:new(path, FILE_READ)
    if not file or not file:IsOpen() then
        log:Write(LOG_WARNING, "[G.E.T.] 环境配置未找到: " .. path .. "，使用默认值")
        _config = {}
        _env_name = "default"
        return
    end

    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then
        log:Write(LOG_ERROR, "[G.E.T.] 环境配置解析失败: " .. tostring(data))
        return
    end

    _env_name = env or data.current or "production"

    if data.environments and data.environments[_env_name] then
        _config = data.environments[_env_name]
    else
        _config = {}
    end

    log:Write(LOG_INFO, "[G.E.T.] 环境配置已加载: " .. _env_name)
end

--- 获取配置值
---@param key string 配置键
---@param default any 默认值
---@return any
function EnvConfig.Get(key, default)
    if _config[key] ~= nil then
        return _config[key]
    end
    return default
end

--- 获取当前环境名
---@return string
function EnvConfig.GetEnvName()
    return _env_name
end

--- 检查是否为调试环境
---@return boolean
function EnvConfig.IsDebug()
    return _config.debug_mode == true
end

return EnvConfig
```

---

## 7. 多关卡批量生成

**灵感：GET 的 Geo multi-site deployment**

### 7.1 关卡系列生成器

从一个基础蓝图，通过参数覆写批量生成关卡变体：

```json
{
  "format": "level-series-v1",
  "base_blueprint": "data/levels/base-arena.json",
  "series": [
    {
      "output": "data/levels/arena-01-forest.json",
      "overrides": {
        "meta.name": "forest-arena",
        "provision.skybox.preset": "sunset",
        "provision.terrain.material": "grass",
        "configure.enemies.waves[0].units[0].count": 5,
        "configure.enemies.waves[0].units[0].level": 1
      }
    },
    {
      "output": "data/levels/arena-02-desert.json",
      "overrides": {
        "meta.name": "desert-arena",
        "provision.skybox.preset": "noon-clear",
        "provision.terrain.material": "sand",
        "configure.enemies.waves[0].units[0].count": 8,
        "configure.enemies.waves[0].units[0].level": 2
      }
    },
    {
      "output": "data/levels/arena-03-ice.json",
      "overrides": {
        "meta.name": "ice-arena",
        "provision.skybox.preset": "overcast",
        "provision.terrain.material": "snow",
        "configure.enemies.waves[0].units[0].count": 12,
        "configure.enemies.waves[0].units[0].level": 3
      }
    }
  ]
}
```

### 7.2 批量生成模块

```lua
-- scripts/get/LevelSeriesGenerator.lua
local cjson = require("cjson")
local BlueprintLoader = require("get.BlueprintLoader")

local LevelSeriesGenerator = {}

--- 从系列配置批量生成关卡蓝图文件
---@param seriesPath string 系列配置文件路径
---@return number count 生成的关卡数
---@return string[]|nil errors 错误列表
function LevelSeriesGenerator.Generate(seriesPath)
    -- 加载系列配置
    local file = File:new(seriesPath, FILE_READ)
    if not file or not file:IsOpen() then
        return 0, {"无法打开系列配置: " .. seriesPath}
    end
    local content = file:ReadString()
    file:Close()

    local ok, series = pcall(cjson.decode, content)
    if not ok then return 0, {"JSON 解析失败"} end

    -- 加载基础蓝图
    local baseBP, err = BlueprintLoader.Load(series.base_blueprint)
    if not baseBP then return 0, {"基础蓝图加载失败: " .. err} end

    local count = 0
    local errors = {}

    for i, levelDef in ipairs(series.series) do
        -- 深拷贝基础蓝图
        local bp = cjson.decode(cjson.encode(baseBP))

        -- 应用覆写
        for path, value in pairs(levelDef.overrides) do
            BlueprintLoader._SetNestedValue(bp, path, value)
        end

        -- 写入文件
        local outFile = File:new(levelDef.output, FILE_WRITE)
        if outFile and outFile:IsOpen() then
            outFile:WriteString(cjson.encode(bp))
            outFile:Close()
            count = count + 1
            log:Write(LOG_INFO, string.format(
                "[G.E.T.] 关卡 %d/%d 已生成: %s", i, #series.series, levelDef.output
            ))
        else
            table.insert(errors, "无法写入: " .. levelDef.output)
        end
    end

    return count, #errors > 0 and errors or nil
end

return LevelSeriesGenerator
```

---

## 8. 状态持久化与存档

**灵感：GET 的 Terraform state**

### 8.1 环境状态快照

```lua
-- scripts/get/StateManager.lua
local cjson = require("cjson")

local StateManager = {}

--- 保存环境状态快照
---@param inventory table 供应清单
---@param gameState table 游戏状态
---@param savePath string 存档路径，如 "saves/env-state.json"
function StateManager.Save(inventory, gameState, savePath)
    local snapshot = {
        format = "env-state-v1",
        timestamp = os.time(),
        provision = {
            stats = inventory.stats,
            zone_count = 0,
            node_count = 0
        },
        configure = {
            scoring = gameState.scoring,
            wave_status = {},
            collectibles_status = {}
        }
    }

    -- 统计供应数据
    for _ in pairs(inventory.zones) do
        snapshot.provision.zone_count = snapshot.provision.zone_count + 1
    end
    for _ in pairs(inventory.nodes) do
        snapshot.provision.node_count = snapshot.provision.node_count + 1
    end

    -- 波次状态
    for id, wave in pairs(gameState.enemies.waves) do
        snapshot.configure.wave_status[id] = {
            status = wave.status,
            killed = wave.killed_count,
            total = wave.total_count
        }
    end

    -- 收集物状态
    for i, item in ipairs(gameState.collectibles) do
        snapshot.configure.collectibles_status[i] = {
            type = item.type,
            collected = item.collected
        }
    end

    local file = File:new(savePath, FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString(cjson.encode(snapshot))
        file:Close()
        log:Write(LOG_INFO, "[G.E.T.] 状态已保存: " .. savePath)
    else
        log:Write(LOG_ERROR, "[G.E.T.] 状态保存失败: " .. savePath)
    end
end

--- 加载环境状态快照
---@param savePath string 存档路径
---@return table|nil snapshot
function StateManager.Load(savePath)
    local file = File:new(savePath, FILE_READ)
    if not file or not file:IsOpen() then
        return nil
    end
    local content = file:ReadString()
    file:Close()

    local ok, snapshot = pcall(cjson.decode, content)
    if not ok then return nil end

    if snapshot.format ~= "env-state-v1" then
        log:Write(LOG_WARNING, "[G.E.T.] 不支持的状态格式: " .. tostring(snapshot.format))
        return nil
    end

    log:Write(LOG_INFO, "[G.E.T.] 状态已恢复: " .. savePath)
    return snapshot
end

return StateManager
```

---

## 9. 完整工作流示例

### 9.1 从零到可玩关卡的 AI 工作流

```
用户: "帮我用竞技场架构做一个森林关卡"

AI 执行流程:
│
├─ Step 1: 选择参考架构
│   └─ 选择 "arena" 蓝图模板
│
├─ Step 2: 填充蓝图参数
│   ├─ provision.terrain → 森林地形（草地材质、起伏地形）
│   ├─ provision.skybox → 日落天空
│   ├─ provision.lighting → 暖色户外光照
│   ├─ provision.zones → 出生区/战斗区/宝藏洞
│   ├─ configure.enemies → 哥布林 + 狼 + Boss
│   ├─ configure.collectibles → 血瓶 + 金箱
│   └─ configure.scoring → 击杀得分 + 时间奖励
│
├─ Step 3: 写入蓝图 JSON
│   └─ → scripts/data/levels/forest-arena-01.json
│
├─ Step 4: 生成 Lua 入口文件
│   └─ → scripts/main.lua（调用 G.E.T. 模块）
│
├─ Step 5: 生成 G.E.T. 模块文件
│   ├─ → scripts/get/BlueprintLoader.lua
│   ├─ → scripts/get/SceneProvisioner.lua
│   ├─ → scripts/get/GameplayConfigurator.lua
│   ├─ → scripts/get/EntityRegistry.lua
│   ├─ → scripts/get/EnvConfig.lua
│   └─ → scripts/get/StateManager.lua
│
├─ Step 6: 生成环境配置
│   └─ → scripts/data/env-config.json
│
├─ Step 7: 生成游戏资源（如需要）
│   ├─ 使用 search_game_resource 查找预制体
│   ├─ 使用 generate_image 生成贴图
│   └─ 使用 text_to_sound_effect 生成音效
│
└─ Step 8: 调用 build 工具构建项目
```

### 9.2 多关卡批量生成工作流

```
用户: "用同一个竞技场蓝图生成 3 关，难度递增"

AI 执行流程:
│
├─ Step 1: 创建基础蓝图
│   └─ → scripts/data/levels/base-arena.json
│
├─ Step 2: 创建关卡系列配置
│   └─ → scripts/data/levels/arena-series.json
│   └─ 定义 3 个变体（森林/沙漠/冰原，递增难度）
│
├─ Step 3: 运行批量生成
│   └─ LevelSeriesGenerator.Generate("data/levels/arena-series.json")
│
├─ Step 4: 生成关卡选择 UI
│   └─ 使用 urhox-libs/UI 创建关卡选择界面
│
└─ Step 5: 调用 build 工具构建
```

---

## 10. 项目文件组织

```
scripts/
├── main.lua                          # 入口文件
├── get/                              # G.E.T. 核心模块
│   ├── BlueprintLoader.lua           # 蓝图加载与验证
│   ├── SceneProvisioner.lua          # Phase 1: 场景供应
│   ├── GameplayConfigurator.lua      # Phase 2: 玩法配置
│   ├── EntityRegistry.lua            # 实体注册与查询
│   ├── EnvConfig.lua                 # 环境配置变量
│   ├── StateManager.lua              # 状态持久化
│   └── LevelSeriesGenerator.lua      # 批量关卡生成
└── data/
    ├── env-config.json               # 环境配置（dev/staging/prod）
    └── levels/
        ├── forest-arena-01.json      # 关卡蓝图
        ├── base-arena.json           # 基础蓝图（模板）
        └── arena-series.json         # 关卡系列配置
```

---

## 11. 数据格式速查

| 格式名 | 用途 | 关键字段 |
|--------|------|---------|
| `scene-blueprint-v1` | 关卡蓝图 | `provision` + `configure` + `env_overrides` |
| `env-config-v1` | 环境配置 | `environments` + `current` |
| `level-series-v1` | 批量关卡 | `base_blueprint` + `series[].overrides` |
| `env-state-v1` | 状态存档 | `provision` + `configure` + `timestamp` |

---

## 12. 引擎规则合规

| 规则 | 本 Skill 遵守方式 |
|------|------------------|
| 代码放 scripts/ | ✅ 所有模块放在 `scripts/get/`，数据放在 `scripts/data/` |
| 不写入 dist 目录 | ✅ 所有产出写入 `scripts/` 和 `assets/` |
| 使用 MCP 工具 | ✅ 资源生成通过 MCP 工具，代码变更后调用 build |
| 构建后预览 | ✅ 每次代码变更后必须调用 build 工具 |
| JSON 持久化 | ✅ 蓝图/配置/状态/关卡全部 JSON 格式 |
| 资源路径规范 | ✅ 使用相对路径引用资源 |
| Lua 数组从 1 | ✅ 覆写路径中 `[n]` 转换时 +1 为 Lua 1-based |
| UI 使用新系统 | ✅ 如需 UI 使用 `urhox-libs/UI` |
| 不使用 Lua 原生文件库 | ✅ 文件操作使用 `File` 类和 `FILE_READ`/`FILE_WRITE` 枚举 |
| 枚举不猜数字 | ✅ 使用 `FILE_READ`、`LOG_INFO` 等枚举常量 |

---

## 13. FAQ

### Q1：与 procedural-generation skill 有什么区别？
**A**: procedural-generation 是算法驱动的（噪声函数、WFC、L-system），G.E.T. 是声明式配置驱动的（JSON 蓝图 → 两阶段构建）。两者可组合使用——G.E.T. 的蓝图可以引用 procedural-generation 的算法来生成地形。

### Q2：与 auto-workflow skill 有什么区别？
**A**: auto-workflow 关注减少样板代码（脚手架、模板），G.E.T. 关注关卡架构和玩法配置的声明式管理。auto-workflow 是"帮你写代码"，G.E.T. 是"帮你设计关卡"。

### Q3：蓝图中的 env_overrides 和 EnvConfig 有什么关系？
**A**: `env_overrides` 是蓝图级别的参数覆写（难度、平台适配），在加载蓝图时应用一次。`EnvConfig` 是运行时环境变量（调试模式、上帝模式），在游戏运行中动态读取。

### Q4：如何扩展自定义的供应模块？
**A**: 在 `SceneProvisioner` 中添加新的 `_Provision*` 方法，对应蓝图 `provision` 段中的新字段。遵循 GET 的 Custom Config 理念——标准模块覆盖 80% 场景，自定义扩展覆盖剩余 20%。

### Q5：批量生成的关卡如何管理版本？
**A**: 每个蓝图有 `meta.version` 字段，关卡系列配置中可追踪版本号。状态存档包含 `timestamp`，支持通过 JSON 文件进行版本化管理。

---

## 14. 参考文档

| 文档 | 路径 | 内容 |
|------|------|------|
| GET 概念映射 | `references/get-concept-mapping.md` | GitLab Environment Toolkit 到游戏开发的完整概念映射 |
| 参考架构蓝图库 | `references/reference-architectures.md` | 6 种预定义场景架构的完整蓝图模板 |
| 环境配置指南 | `references/env-config-guide.md` | 环境变量、覆写策略和多平台适配详解 |
