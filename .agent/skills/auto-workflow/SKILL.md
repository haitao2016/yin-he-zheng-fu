---
name: auto-workflow
description: >-
  UrhoX Lua 游戏开发自动化工作流引擎。识别开发过程中的重复性代码模式，
  主动生成可复用的自动化方案，消除手动样板代码。覆盖六大自动化领域：
  项目初始化（脚手架定制 + 模式路由）、场景搭建（物理/灯光/地形一键配置）、
  UI 接线（Init + 主题 + 常用面板代码生成）、配置提取（魔法数字 → GameConfig）、
  模块化拆分（大文件自动拆分为模块结构）、构建检查（资源引用验证 + 缺失检测）。
  Use when users need to (1) 快速初始化新游戏项目并生成定制化脚手架,
  (2) 一键搭建 3D 场景（地面/灯光/相机/天空盒）,
  (3) 自动生成 UI 初始化代码和常用面板模板（菜单/HUD/暂停/设置）,
  (4) 把代码中的硬编码数值提取为配置文件,
  (5) 将超长单文件自动拆分为模块化结构,
  (6) 构建前检查资源引用完整性和代码规范,
  (7) 用户说"自动化"、"减少重复"、"生成样板代码"、"一键搭建"、"代码生成",
  (8) automate, reduce boilerplate, codegen, scaffold, one-click setup,
  (9) 用户反复手动写类似的初始化/配置/UI 代码时主动建议自动化,
  (10) 检测到用户在多个文件中重复相同模式时主动提议抽象为可复用模块。
---

# Auto-Workflow — UrhoX Lua 游戏开发自动化工作流

> 核心理念：**观察重复 → 抽象模式 → 自动化构建**
>
> 不是"回答问题"，而是"看到重复 → 立刻构建自动化"。
>
> - 六大自动化模式详解 → `references/workflow-patterns.md`
> - 代码生成模板集 → `references/codegen-templates.md`

---

## 工作方法论（六步循环）

```
1. 观察  ─ 用户在重复做什么？（初始化/场景搭建/UI接线/配置/...）
2. 抽象  ─ 这个任务的通用模式是什么？（输入参数/输出代码/变化点）
3. 设计  ─ 怎么自动完成？（模板 + 参数化 + 智能默认值）
4. 生成  ─ 输出可直接运行的代码（写入 scripts/，遵循引擎规则）
5. 验证  ─ 构建检查 + 资源完整性校验
6. 迭代  ─ 根据用户反馈优化模板参数
```

**主动触发原则**：当检测到以下信号时，不等用户请求，主动建议自动化：
- 用户在两个以上文件中写了结构相似的代码
- 用户手动写了超过 20 行的初始化样板代码
- 代码中出现 5 个以上未命名的魔法数字
- 单文件超过 1000 行且无模块拆分

---

## 六大自动化领域

### 1. 项目初始化自动化

根据用户需求生成定制化脚手架，而非让用户手动选择和修改模板。

**输入**：游戏类型、视角、物理需求、网络模式、UI 需求
**输出**：完整的 `scripts/main.lua`（或多文件结构）

```
用户需求 → 分析
  ↓
选择基础脚手架（scaffold-2d / 2d-physics / 3d-scene / 3d-character）
  ↓
注入定制化代码：
  ├─ 物理配置（重力、碰撞层）
  ├─ 相机模式（FPS/TPS/自由/正交）
  ├─ 输入方案（键鼠/触屏/手柄）
  ├─ 网络模式路由（读取 settings.json）
  └─ UI 初始化（字体/主题/根面板）
  ↓
写入 scripts/ → 调用 build
```

**网络模式路由**（读取 `.project/settings.json`）：

```lua
-- 自动生成的模式路由代码
local cjson = require("cjson")
local settingsPath = ".project/settings.json"

local function detectGameMode()
    if not fileSystem:FileExists(settingsPath) then return "standalone" end
    local f = File(settingsPath, FILE_READ)
    if not f:IsOpen() then return "standalone" end
    local ok, settings = pcall(cjson.decode, f:ReadString())
    f:Close()
    if not ok then return "standalone" end
    local mp = settings["@runtime"] and settings["@runtime"].multiplayer
    if mp and mp.enabled then return "multiplayer" end
    return "standalone"
end
```

> 详见 → `references/workflow-patterns.md` § 项目初始化

### 2. 场景搭建自动化

一键生成完整的 3D 场景基础设施，消除每次手动创建 Octree/PhysicsWorld/灯光的重复。

**输入**：场景类型（室外/室内/地下城）、光照预设、地面材质
**输出**：`CreateScene()` 函数代码

```lua
-- 自动生成示例：室外场景
local function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    local physicsWorld = scene_:CreateComponent("PhysicsWorld")
    physicsWorld.gravity = Vector3(0, -9.81, 0)

    -- 灯光
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.castShadows = true
    light.shadowIntensity = 0.5

    -- 地面
    local floorNode = scene_:CreateChild("Floor")
    floorNode.scale = Vector3(50, 1, 50)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Box.mdl")
    -- 材质由 materials skill 提供

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 5, -10)
    cameraNode_:LookAt(Vector3.ZERO)
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 300.0

    renderer:SetViewport(0, Viewport:new(scene_, camera))
end
```

> 详见 → `references/codegen-templates.md` § 场景模板

### 3. UI 接线自动化

生成 UI 初始化 + 常用面板的完整代码，消除重复的 `UI.Init` + 布局样板。

**预置面板模板**：

| 模板 | 内容 | 典型用途 |
|------|------|---------|
| **主菜单** | 标题 + 开始/设置/退出按钮 | 游戏入口 |
| **HUD** | 血量条 + 分数 + 计时器 | 游戏内界面 |
| **暂停菜单** | 继续/重启/返回主菜单 | 暂停时覆盖 |
| **设置面板** | 音量滑块 + 灵敏度 + 分辨率 | 选项页 |
| **游戏结束** | 结果 + 分数 + 重玩按钮 | 结算界面 |
| **排行榜** | 名次 + 昵称 + 分数列表 | 竞技排名 |

```lua
-- 自动生成：主菜单面板
local function createMainMenu(callbacks)
    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        flexDirection = "column",
        backgroundColor = { 20, 20, 30, 255 },
        children = {
            UI.Label { text = callbacks.title or "游戏标题",
                       fontSize = 36, color = {255,255,255,255} },
            UI.Spacer { height = 40 },
            UI.Button { text = "开始游戏", variant = "primary",
                        width = 200,
                        onClick = function(self) callbacks.onStart() end },
            UI.Spacer { height = 16 },
            UI.Button { text = "设置", width = 200,
                        onClick = function(self) callbacks.onSettings() end },
            UI.Spacer { height = 16 },
            UI.Button { text = "退出", width = 200,
                        onClick = function(self) callbacks.onQuit() end },
        },
    }
end
```

> 详见 → `references/codegen-templates.md` § UI 模板

### 4. 配置提取自动化

扫描代码中的硬编码数值（魔法数字），提取为结构化配置文件。

**流程**：

```
扫描 scripts/*.lua
  ↓
识别魔法数字（数值字面量 + 上下文）
  ↓
按类别分组（玩家/物理/相机/UI/关卡）
  ↓
生成 scripts/GameConfig.lua
  ↓
替换原代码中的字面量为配置引用
```

**生成的配置文件格式**：

```lua
-- scripts/GameConfig.lua（自动生成）
local GameConfig = {
    Player = {
        moveSpeed    = 5.0,    -- 移动速度 (m/s)
        jumpForce    = 7.0,    -- 跳跃力度 (m/s)
        maxHealth    = 100,    -- 最大生命值
    },
    Camera = {
        distance     = 5.0,    -- 跟随距离 (m)
        height       = 1.7,    -- 偏移高度 (m)
        fov          = 45.0,   -- 视场角 (度)
    },
    Physics = {
        gravity      = -9.81,  -- 重力加速度 (m/s²)
    },
}
return GameConfig
```

> 详见 → `references/workflow-patterns.md` § 配置提取

### 5. 模块化拆分自动化

当单文件超过 1000 行时，自动分析代码结构并拆分为多模块。

**拆分策略**：

| 代码区域 | 目标模块 | 说明 |
|---------|---------|------|
| 配置常量 | `GameConfig.lua` | 所有可调参数 |
| 场景创建 | `SceneSetup.lua` | CreateScene + 灯光 + 地形 |
| 玩家逻辑 | `Player.lua` | 移动/跳跃/生命/动画 |
| 敌人/AI | `Enemy.lua` | 生成/行为/死亡 |
| UI 面板 | `GameUI.lua` | HUD/菜单/结算 |
| 输入处理 | `InputHandler.lua` | 键鼠/触屏/手柄 |
| 主入口 | `main.lua` | Start + require 各模块 |

**拆分后的 main.lua 结构**：

```lua
-- scripts/main.lua（拆分后）
local GameConfig   = require("GameConfig")
local SceneSetup   = require("SceneSetup")
local Player       = require("Player")
local GameUI       = require("GameUI")
local InputHandler = require("InputHandler")

function Start()
    SceneSetup.Init(scene_)
    Player.Init(scene_, GameConfig.Player)
    GameUI.Init()
    InputHandler.Init()
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    InputHandler.Update(dt)
    Player.Update(dt)
    GameUI.Update(dt)
end
SubscribeToEvent("Update", "HandleUpdate")
```

> 详见 → `references/workflow-patterns.md` § 模块化拆分

### 6. 构建检查自动化

在调用 build 之前，预扫描代码质量和资源完整性。

**检查清单**：

```
代码检查：
  ├─ [ ] 数组索引是否从 1 开始（非 0）
  ├─ [ ] eventData 访问是否使用 :GetInt/:GetFloat
  ├─ [ ] 鼠标按钮是否用 MOUSEB_LEFT 而非数字
  ├─ [ ] 是否有禁止 API（io.open, os.execute, http）
  ├─ [ ] 类型标注是否完整（nil 赋值变量有 @type）
  └─ [ ] 单文件是否超过 1500 行

资源检查：
  ├─ [ ] 代码中引用的资源路径是否存在
  ├─ [ ] 是否有无前缀的正确路径（不含 assets/）
  ├─ [ ] 贴图/模型/音频文件是否在 assets/ 下
  └─ [ ] 字体文件是否存在（UI.Init 引用的字体）

结构检查：
  ├─ [ ] main.lua 是否包含 Start() 函数
  ├─ [ ] require 路径是否正确
  └─ [ ] 多人模式路由是否与 settings.json 一致
```

> 详见 → `references/workflow-patterns.md` § 构建检查

---

## 使用流程

### 场景 A：新项目启动

```
用户: "帮我做一个 3D 跑酷游戏"
  ↓
1. 选择脚手架: scaffold-3d-character
2. 注入定制: 无限跑道 + 障碍物 + 收集物
3. 生成 UI: HUD（分数+距离） + 主菜单 + 游戏结束
4. 生成配置: GameConfig.lua（速度/难度曲线）
5. 构建检查 → build
```

### 场景 B：已有项目优化

```
检测到: main.lua 超过 1200 行
  ↓
1. 分析代码结构 → 识别可拆分模块
2. 提议拆分方案 → 用户确认
3. 执行拆分 → 生成模块文件 + 更新 main.lua
4. 提取魔法数字 → 生成 GameConfig.lua
5. 构建检查 → build
```

### 场景 C：重复模式检测

```
检测到: 用户第二次手动写 UI.Init + 菜单面板
  ↓
主动建议: "检测到你在重复写菜单面板代码，
          我可以生成一个可复用的 MenuBuilder 模块，
          之后只需传入回调即可创建菜单。要我生成吗？"
```

---

## 与其他 Skill 的协作边界

| Skill | 职责 | auto-workflow 的关系 |
|-------|------|---------------------|
| `game-creation-workflow` | 整体流程编排（需求→设计→实现→交付） | 本 skill 在"实现"阶段提供代码自动化 |
| `auto-game-assets` | 扫描代码、填补缺失资源 | 本 skill 生成代码，该 skill 生成资源 |
| `game-cog` | 概念→统一风格资源包 | 互不重叠，领域不同 |
| `ai-asset-pipeline` | 资源管线架构设计 | 互不重叠，领域不同 |
| `materials` | PBR 材质选择指南 | 本 skill 场景搭建时调用其材质建议 |
| `setup-fsm` | 动画状态机配置 | 本 skill 项目初始化时可联动 FSM 配置 |

---

## 参考文件

| 文件 | 内容 | 何时阅读 |
|------|------|---------|
| `references/workflow-patterns.md` | 六大领域的详细实现模式、判断逻辑、边界条件 | 需要深入理解自动化策略时 |
| `references/codegen-templates.md` | 可直接使用的代码生成模板集（场景/UI/配置/模块） | 需要生成具体代码时 |
