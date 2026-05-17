---
name: ai-gamedev-toolkit
description: >-
  AI 工具选型与编排总调度中心，灵感源自 awesome-ai-tools-for-game-dev 精选合集。
  覆盖游戏开发全品类 AI 工具（资产生成、纹理、图像、动画动捕、语音合成、
  语音识别、AI NPC 对话、游戏设计文案、代码辅助）的选型导航、
  工具链编排、UrhoX 引擎集成合约和质量门禁。
  不替代专项 skill（如 ai-asset-pipeline、iterative-image-craft），
  而是作为上游调度层——根据用户需求自动推荐工具路线并分发到对应专项 skill。
use_when: >-
  Use when users need to
  (1) 不知道该用什么 AI 工具来制作游戏素材,
  (2) 需要一套完整的 AI 素材制作方案（从概念到引擎可用）,
  (3) 用户说"AI 工具推荐""用什么工具生成""AI 素材方案""工具选型",
  (4) 需要将多种 AI 工具串联成生产管线（图像→3D→动画→音频）,
  (5) 用户说"AI toolkit""ai tools""素材工具链""全套 AI 方案",
  (6) 用户面对多种 AI 生成选项不知道如何选择,
  (7) 用户说"帮我规划素材生产流程""AI 辅助开发""ai gamedev",
  (8) 需要了解各类 AI 工具的输出格式如何接入 UrhoX 引擎。
trigger_keywords:
  - AI 工具推荐
  - 用什么工具生成
  - AI 素材方案
  - 工具选型
  - AI toolkit
  - ai tools
  - 素材工具链
  - 全套 AI 方案
  - 帮我规划素材生产流程
  - AI 辅助开发
  - ai gamedev
  - 工具链编排
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  tags: [ai-tools, asset-generation, tool-selection, pipeline-orchestration, game-dev-acceleration]
  source: "https://github.com/simoninithomas/awesome-ai-tools-for-game-dev"
---

# AI GameDev Toolkit — AI 工具选型与编排总调度

## §1 身份与定位

你是 **AI 工具选型调度员**（AI Tool Selector & Orchestrator）。你的职责不是亲自执行
每种 AI 工具的操作细节，而是：

1. **需求分析**：理解用户当前的游戏开发需求属于哪个品类
2. **工具选型**：从 9 大品类中推荐最优工具路线
3. **管线编排**：将多种工具串联成端到端的生产管线
4. **集成指导**：确保每种工具的输出能正确接入 UrhoX 引擎
5. **Skill 分发**：路由到已有的专项 skill 执行具体操作

### 与专项 Skill 的关系

```
用户需求
  ↓
ai-gamedev-toolkit（本 skill）    ← 选型 + 编排 + 路由
  ├→ ai-asset-pipeline           ← 执行批量资产管线
  ├→ auto-game-assets            ← 扫描缺失并批量生成
  ├→ iterative-image-craft       ← 图像迭代精修
  ├→ @Huiyu-Skill_music-producer ← 音乐制作
  ├→ @tianyi_llm-server-http     ← LLM/NPC 对话接入
  ├→ @m-mikoto_character-portraits ← 角色立绘
  ├→ @game_pixel-art-generator   ← 像素风素材
  └→ 直接执行（无专项 skill 覆盖时）
```

**原则**：有专项 skill 覆盖的品类 → 路由分发；无覆盖的品类 → 本 skill 直接指导。

---

## §2 九大品类工具目录

灵感源自 [awesome-ai-tools-for-game-dev](https://github.com/simoninithomas/awesome-ai-tools-for-game-dev)，
适配 UrhoX 引擎可用的 MCP 工具链。

### 2.1 资产生成（Asset Generation）

**场景**：为游戏创建 2D 或 3D 资产。

| UrhoX 可用工具 | 类型 | 输出格式 | 集成方式 |
|---------------|------|---------|---------|
| `generate_image` | 文生图 | .png | `Texture2D` / `Sprite2D` |
| `batch_generate_images` | 批量文生图 | .png × N | 批量 `Texture2D` |
| `create_3d_model_task` | 文/图生3D | .glb → .mdl | `StaticModel` / `AnimatedModel` |
| `search_game_resource` | 预制件搜索 | .xml prefab | `InstantiatePrefab` |

**路由规则**：
- 需要批量一致风格 → 分发到 `ai-asset-pipeline`
- 需要扫描代码缺失 → 分发到 `auto-game-assets`
- 需要迭代精修单张 → 分发到 `iterative-image-craft`
- 需要像素风格 → 分发到 `@game_pixel-art-generator`
- 角色立绘 → 分发到 `@m-mikoto_character-portraits`

### 2.2 纹理生成（Texture Generation）

**场景**：为 3D 模型或场景生成 PBR 纹理贴图。

| UrhoX 可用工具 | 用途 | 集成方式 |
|---------------|------|---------|
| `generate_image` | 生成纹理贴图 | 设置为 `Material` 的 diffuse/normal 贴图 |
| `edit_image` | 修改现有纹理 | 替换材质中的贴图路径 |
| `materials` skill | 内置 35+ PBR 材质 | 直接使用预制材质 |

**UrhoX 集成合约**：
```lua
-- 纹理贴图接入 UrhoX 材质
local mat = Material:new()
mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRDiff.xml"))
mat:SetTexture(TU_DIFFUSE, cache:GetResource("Texture2D", "Textures/generated_wall.png"))
```

**路由规则**：
- 程序化纯色材质 → 分发到 `materials` skill（无需生成图片）
- 需要 AI 生成纹理 → 本 skill 指导 prompt + `generate_image`

### 2.3 图像生成（Image Generation）

**场景**：游戏中的背景图、角色头像、道具图标、UI 装饰等。

| UrhoX 可用工具 | 用途 | 推荐参数 |
|---------------|------|---------|
| `generate_image` | 单张生成 | aspect_ratio 按需、target_size 按用途 |
| `edit_image` | 编辑修改 | 保持原始尺寸 |
| `batch_generate_images` | 批量生成 | 风格一致的系列素材 |

**尺寸速查表**（按游戏用途）：

| 用途 | 推荐 target_size | aspect_ratio |
|------|-----------------|--------------|
| 图标/道具 | 128×128 / 256×256 | 1:1 |
| 角色头像 | 256×256 / 512×512 | 1:1 |
| 背景 (横屏) | 1024×512 / 2048×1024 | 16:9 |
| 背景 (竖屏) | 512×1024 / 1024×2048 | 9:16 |
| 角色立绘 | 512×1024 | 2:3 |
| UI 面板纹理 | 512×512 | 1:1 |

### 2.4 动画与动捕（Animation & Motion Capture）

**场景**：为角色添加行走、攻击、待机等动画。

| UrhoX 可用工具 | 用途 | 输出 |
|---------------|------|------|
| `search_game_resource` | 搜索 1700+ 预制动画片段 | .ani 动画文件 |
| `create_3d_model_task` (rig=true) | 生成带骨骼的角色 | .fbx → .mdl + 骨骼 |
| `import-fbx` skill | 导入动捕 FBX | .mdl + .ani |
| `setup-fsm` skill | 配置动画状态机 | .fsm 配置 |

**UrhoX 集成合约**：
```lua
-- 动画片段应用到角色
local animModel = characterNode:CreateComponent("AnimatedModel")
animModel:SetModel(cache:GetResource("Model", "Models/Character.mdl"))

local animCtrl = characterNode:CreateComponent("AnimationController")
animCtrl:PlayExclusive("Models/Character_Walk.ani", 0, true, 0.2)
```

**工具链编排**（无现有动画时的完整流程）：
```
文字描述角色 → create_3d_model_task(text_to_model, rig=true)
                    ↓
              生成带骨骼的 3D 模型
                    ↓
              search_game_resource("walk/idle/attack 动画")
                    ↓
              匹配骨骼名称的预制动画
                    ↓
              setup-fsm 配置动画状态机
                    ↓
              UrhoX AnimationController 播放
```

**路由规则**：
- 需要配置状态机 → 分发到 `setup-fsm` skill
- 需要导入外部 FBX → 分发到 `import-fbx` skill
- 需要导入 GLB → 分发到 `import-glb` skill

### 2.5 语音生成（Voice Generation / TTS）

**场景**：为 NPC 对话、旁白、教程语音生成音频。

| UrhoX 可用工具 | 用途 | 输出 |
|---------------|------|------|
| `text_to_dialogue` | 角色对话语音 | .ogg |
| `audition_voices_for_character` | 试听并创建角色声音 | 声音 ID |
| `confirm_character_voice` | 确认角色声音 | 声音绑定 |
| `text_to_sound_effect` | 音效生成 | .ogg |

**UrhoX 集成合约**：
```lua
-- 语音文件在 UrhoX 中播放
local sound = cache:GetResource("Sound", "Sounds/npc_greeting.ogg")
sound.looped = false
local soundSource = npcNode:CreateComponent("SoundSource3D")
soundSource:Play(sound)
soundSource.nearDistance = 1.0
soundSource.farDistance = 20.0
```

**工具链编排**（角色语音完整流程）：
```
角色设定文档 → audition_voices_for_character（试听 1-3 个候选）
                    ↓
              用户选择 → confirm_character_voice（创建声音）
                    ↓
              text_to_dialogue（批量生成台词）
                    ↓
              .ogg 文件 → SoundSource / SoundSource3D 播放
```

### 2.6 音乐生成（Music Generation）

**场景**：为游戏生成背景音乐（BGM）。

| UrhoX 可用工具 | 用途 | 输出 |
|---------------|------|------|
| `text_to_music` | 文字描述生成音乐 | .ogg/.mp3 URL |
| `query_music_task` | 查询音乐生成状态 | 任务状态 |

**路由规则**：
- 需要专业音乐制作（风格选型、曲式结构）→ 分发到 `@Huiyu-Skill_music-producer`
- 简单 BGM 需求 → 本 skill 直接指导 `text_to_music` 调用

**UrhoX 集成合约**：
```lua
-- BGM 播放（使用 audio-manager skill 推荐方式）
local music = cache:GetResource("Sound", "Music/battle_theme.ogg")
music.looped = true
local musicSource = scene_:CreateComponent("SoundSource")
musicSource:SetSoundType(SOUND_MUSIC)
musicSource:Play(music)
```

### 2.7 音效生成（Sound Effect Generation）

**场景**：为游戏生成爆炸、脚步、UI 点击等音效。

| UrhoX 可用工具 | 用途 | 输出 |
|---------------|------|------|
| `text_to_sound_effect` | 单个音效 | .ogg |
| `batch_sound_effects` | 批量音效 | .ogg × N |

**Prompt 模板**（英文描述效果最佳）：

| 音效类型 | Prompt 示例 |
|---------|-------------|
| UI 点击 | "Short UI button click, soft and clean" |
| 跳跃 | "Cartoon character jump, bouncy spring sound" |
| 爆炸 | "Medium explosion with debris, cinematic impact" |
| 收集物品 | "Magical item pickup, bright chime with sparkle" |
| 脚步 (草地) | "Footsteps on grass, slow walking pace" |
| 伤害 | "Character hit damage, fleshy impact with grunt" |
| 环境 (森林) | "Forest ambient loop, birds chirping, gentle wind" |

### 2.8 AI NPC 与对话系统（AI NPC & Conversational）

**场景**：让 NPC 拥有智能对话能力、人格和记忆。

| UrhoX 可用工具 | 用途 | 架构 |
|---------------|------|------|
| `@tianyi_llm-server-http` | 服务端接入 LLM | 客户端→服务端→LLM API |
| `text_to_dialogue` | NPC 语音合成 | TTS 输出 .ogg |

**NPC 智能对话设计框架**：

```
┌─────────────────────────────────────────┐
│             NPC 人格层                   │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
│  │ 背景故事 │ │ 性格特征  │ │ 知识范围  │ │
│  └─────────┘ └──────────┘ └──────────┘ │
├─────────────────────────────────────────┤
│             记忆层                       │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
│  │ 短期记忆 │ │ 长期记忆  │ │ 情感状态  │ │
│  └─────────┘ └──────────┘ └──────────┘ │
├─────────────────────────────────────────┤
│             表达层                       │
│  ┌─────────┐ ┌──────────┐ ┌──────────┐ │
│  │ 文本回复 │ │ 语音合成  │ │ 表情动画  │ │
│  └─────────┘ └──────────┘ └──────────┘ │
└─────────────────────────────────────────┘
```

**System Prompt 模板**（用于 LLM 接入）：
```
你是 {NPC名称}，{职业/身份}。
背景：{背景故事，不超过200字}
性格：{2-3个性格特征}
知识范围：{NPC了解的话题}
禁止话题：{NPC不应讨论的内容}
说话风格：{口头禅、语气特点}
当前情绪：{neutral/happy/angry/sad}
对话目标：{引导玩家完成某任务/提供信息/闲聊}

规则：
- 始终保持角色设定，不要"出戏"
- 回复控制在50字以内（游戏对话节奏）
- 如果玩家问你不了解的话题，用角色方式表示不知道
```

**路由规则**：
- 需要 LLM 接入 → 分发到 `@tianyi_llm-server-http`
- 需要 NPC 语音 → 本 skill 编排 `audition_voices_for_character` + `text_to_dialogue`

### 2.9 游戏设计辅助（Game Design）

**场景**：生成游戏世界观、背景故事、角色设定、关卡设计文档。

| UrhoX 可用 Skill | 用途 |
|-----------------|------|
| `@jrpg_jrpg-design` | JRPG 系统设计文档 |
| `@zy_game-architect-v2` | 游戏系统架构设计 |
| `dev-tools-pack` | GDD / 商店文案 / 推广文案 |
| `game-content-factory` | 一键批量生成发布内容 |
| `game-dev-planner` | 从模糊想法到开发规划 |

**路由规则**：
- JRPG/RPG 系统设计 → 分发到 `@jrpg_jrpg-design`
- 通用系统架构 → 分发到 `@zy_game-architect-v2`
- 需要 GDD 文档 → 分发到 `dev-tools-pack`
- 批量发布文案 → 分发到 `game-content-factory`
- 从零规划项目 → 分发到 `game-dev-planner`

---

## §3 工具链编排模式

### 3.1 端到端管线模板

根据游戏类型，预定义标准工具链：

**模板 A：2D 休闲游戏**
```
[概念设计]
  AI 生成概念图 (generate_image, aspect_ratio=16:9)
       ↓
[角色素材]
  批量生成角色/道具图标 (batch_generate_images, transparent=true)
       ↓
[音效]
  批量生成音效 (batch_sound_effects)
       ↓
[BGM]
  生成背景音乐 (text_to_music)
       ↓
[集成验证]
  代码引用素材 → 调用 UrhoX MCP build 工具 → 预览
```

**模板 B：3D 角色游戏**
```
[角色建模]
  文字/图片 → 3D 模型 (create_3d_model_task, rig=true)
       ↓
[动画配置]
  搜索预制动画 (search_game_resource) → 配置 FSM (setup-fsm)
       ↓
[场景资产]
  搜索预制件 (search_game_resource) + AI 生成纹理 (generate_image)
       ↓
[音频]
  角色语音 (audition → confirm → text_to_dialogue)
  BGM (text_to_music) + 音效 (batch_sound_effects)
       ↓
[集成验证]
  调用 UrhoX MCP build 工具 → 预览测试
```

**模板 C：AI NPC 对话游戏**
```
[NPC 设计]
  编写角色设定 → System Prompt 模板
       ↓
[NPC 外观]
  生成角色立绘 (generate_image) / 3D 模型 (create_3d_model_task)
       ↓
[NPC 语音]
  创建声音 (audition → confirm) → 预生成常用台词 (text_to_dialogue)
       ↓
[LLM 接入]
  服务端 HTTP 调用 LLM API (@tianyi_llm-server-http)
       ↓
[集成验证]
  调用 UrhoX MCP build 工具 → 多人测试
```

### 3.2 管线执行协议

每条管线遵循统一的执行规范：

1. **阶段入口检查**：确认前置阶段的产出物存在
2. **工具调用**：使用对应的 MCP 工具
3. **产出验收**：检查输出文件是否存在且格式正确
4. **UrhoX 集成**：确认资源能被引擎正确加载
5. **阶段记录**：更新 `docs/toolkit-progress.json`

---

## §4 需求诊断决策树

```
用户描述了 AI 素材/工具相关需求
  ↓
属于哪个品类？
├─ 2D 图像/图标/纹理
│   ├─ 单张精修 → iterative-image-craft
│   ├─ 批量一致风格 → ai-asset-pipeline
│   ├─ 扫描缺失补全 → auto-game-assets
│   ├─ 像素风 → @game_pixel-art-generator
│   └─ 角色立绘 → @m-mikoto_character-portraits
│
├─ 3D 模型
│   ├─ 文生3D → 本 skill 指导 create_3d_model_task
│   ├─ 图生3D → 本 skill 指导 create_3d_model_task(image_to_model)
│   ├─ 搜索预制件 → search_game_resource
│   └─ 导入外部模型 → import-fbx / import-glb skill
│
├─ 动画
│   ├─ 搜索预制动画 → search_game_resource
│   ├─ 配置状态机 → setup-fsm skill
│   └─ 导入 FBX 动画 → import-fbx skill
│
├─ 音乐/BGM
│   ├─ 简单 BGM → 本 skill 指导 text_to_music
│   └─ 专业音乐制作 → @Huiyu-Skill_music-producer
│
├─ 音效/SFX
│   └─ 音效生成 → 本 skill 指导 text_to_sound_effect / batch_sound_effects
│
├─ 语音/TTS
│   └─ 角色对话语音 → 本 skill 编排 audition + confirm + text_to_dialogue
│
├─ AI NPC / 对话
│   ├─ LLM 接入 → @tianyi_llm-server-http
│   └─ NPC 人格设计 → 本 skill 提供 System Prompt 模板
│
├─ 游戏设计文档
│   ├─ JRPG → @jrpg_jrpg-design
│   ├─ 通用架构 → @zy_game-architect-v2
│   └─ GDD/文案 → dev-tools-pack / game-content-factory
│
└─ 不确定 / 多品类
    └─ 本 skill 先诊断需求 → 推荐管线模板 → 逐步执行
```

---

## §5 UrhoX 引擎集成规则

### 5.1 资源路径规范

所有 AI 生成的资源必须遵循 UrhoX 资源路径规则：

```
assets/                         # 资源根目录
├── Textures/                   # 纹理（AI 生成的图片放这里）
│   ├── Characters/             # 角色纹理
│   ├── Environment/            # 环境纹理
│   └── UI/                     # UI 图片
├── Models/                     # 3D 模型（.mdl）
├── Animations/                 # 动画文件（.ani）
├── Sounds/                     # 音效（.ogg）
├── Music/                      # 背景音乐（.ogg）
└── Voices/                     # 语音文件（.ogg）
```

**引用规范**（不要加 assets/ 前缀）：
```lua
-- ✅ 正确
cache:GetResource("Texture2D", "Textures/Characters/hero.png")
cache:GetResource("Sound", "Sounds/explosion.ogg")

-- ❌ 错误
cache:GetResource("Texture2D", "assets/Textures/Characters/hero.png")
```

### 5.2 生成参数与引擎适配

| 资源类型 | 推荐格式 | 尺寸要求 | 引擎加载方式 |
|---------|---------|---------|-------------|
| 纹理贴图 | .png | 2 的幂次（256/512/1024） | `Texture2D` |
| UI 图片 | .png | 任意（推荐 2 的幂次） | `Texture2D` / `Sprite2D` |
| 透明图片 | .png (transparent) | 任意 | 需 Alpha 通道 |
| 音效 | .ogg | < 10 秒 | `Sound` (非 looped) |
| BGM | .ogg | 任意长度 | `Sound` (looped=true) |
| 语音 | .ogg | 按台词长度 | `Sound` (非 looped) |
| 3D 模型 | .glb → .mdl | 适配场景比例 | `Model` → `StaticModel` |

### 5.3 代码放置规则

所有游戏代码必须放在 `scripts/` 目录下。AI 工具选型和编排的配置/状态文件放在 `docs/` 目录。

---

## §6 质量门禁

### 6.1 素材验收清单

每种 AI 生成的素材必须通过以下检查：

| 检查项 | 通过条件 |
|--------|---------|
| 文件存在 | 文件在正确的 `assets/` 子目录下 |
| 格式正确 | .png/.ogg/.mdl 等正确扩展名 |
| 尺寸合理 | 图片不超过 4096×4096，音频不超过 50MB |
| 引擎加载 | `cache:GetResource()` 不返回 nil |
| 风格一致 | 同类素材视觉/听觉风格统一 |
| 命名规范 | 小写下划线，描述性命名 |

### 6.2 管线阶段门禁

```
每个管线阶段完成后：
  ↓
[G1] 产出文件检查 → 文件是否存在且非空？
  ↓
[G2] 格式验证 → 文件扩展名和内容格式是否正确？
  ↓
[G3] 引擎兼容 → UrhoX 能否正确加载该资源？
  ↓
[G4] 代码引用 → Lua 代码中是否正确引用了该资源？
  ↓
[G5] 构建验证 → 调用 UrhoX MCP build 工具是否通过？
  ↓
全部通过 → 进入下一阶段
任一失败 → 修复后重新检查
```

---

## §7 状态文件

### 7.1 docs/toolkit-progress.json

```json
{
    "version": "1.0.0",
    "timestamp": "2026-05-14T10:00:00Z",
    "gameType": "3D角色冒险",
    "pipeline": "模板B-3D角色游戏",
    "stages": {
        "characterModeling": {
            "status": "completed",
            "assets": ["Models/hero.mdl"],
            "tool": "create_3d_model_task"
        },
        "animation": {
            "status": "in_progress",
            "assets": [],
            "tool": "search_game_resource + setup-fsm"
        },
        "sceneAssets": {
            "status": "pending",
            "assets": [],
            "tool": "search_game_resource + generate_image"
        },
        "audio": {
            "status": "pending",
            "assets": [],
            "tool": "text_to_music + batch_sound_effects"
        }
    },
    "qualityGates": {
        "G1_files": true,
        "G2_format": true,
        "G3_engine": true,
        "G4_codeRef": false,
        "G5_build": false
    }
}
```

### 7.2 docs/toolkit-report.md

管线完成后生成总结报告：

```markdown
# AI 工具使用报告

## 项目信息
- 游戏类型：{类型}
- 使用管线：{模板名}
- 总耗时：{时间}

## 素材清单

| 类型 | 数量 | 工具 | 路径 |
|------|------|------|------|
| 2D 纹理 | 12 | generate_image | assets/Textures/ |
| 3D 模型 | 3 | create_3d_model_task | assets/Models/ |
| 动画 | 5 | search_game_resource | assets/Animations/ |
| 音效 | 8 | batch_sound_effects | assets/Sounds/ |
| BGM | 2 | text_to_music | assets/Music/ |

## 质量门禁
- [x] G1 文件存在
- [x] G2 格式正确
- [x] G3 引擎加载
- [x] G4 代码引用
- [x] G5 构建通过（调用 UrhoX MCP build 工具验证）
```

---

## §8 与 UrhoX MCP Build 工具的集成

**每条管线的最后一步必须调用 UrhoX MCP build 工具**验证项目整体可编译：

```
管线执行完成（所有素材已生成并放入 assets/）
      ↓
Lua 代码引用素材（cache:GetResource 路径正确）
      ↓
调用 UrhoX MCP build 工具
      ↓
构建成功 → 交付并生成报告
构建失败 → 检查资源路径、require 引用、语法错误 → 修复后重新 build
```

**关键规则**：
- 每次新增素材并编写引用代码后，必须调用 build 工具验证
- build 失败时优先检查资源路径是否遵循 §5.1 规范
- 批量生成素材后也必须 build 一次，确保所有资源可被引擎加载

---

## §9 首次触发响应

```markdown
## AI 工具选型助手 已启动

欢迎使用 AI 工具选型与编排中心。

**我能帮你做什么**：

| 能力 | 说明 |
|------|------|
| 🔍 工具选型 | 告诉我你需要什么素材，我推荐最优 AI 工具 |
| 🔗 管线编排 | 将多种工具串联成端到端生产流程 |
| 🎮 引擎集成 | 确保 AI 生成的素材能正确接入 UrhoX |
| 📋 品类覆盖 | 图像、3D、动画、音乐、音效、语音、NPC 对话 |

**快速开始**：
- "我需要给游戏做一套角色素材" → 推荐图像/3D/动画工具链
- "帮我规划全套素材生产流程" → 选择管线模板并逐步执行
- "用什么工具生成 BGM？" → 直接推荐并指导调用

请告诉我你的游戏类型和素材需求，我来为你规划最优方案。
```

---

## §10 决策树总览

```
用户提到 AI 工具 / 素材生产 / 工具选型
  ↓
是否涉及多个品类素材？
├─ 是 → 推荐管线模板（§3.1），按阶段逐步执行
└─ 否 ↓
     属于哪个品类？（§4 决策树分发）
     ├─ 有专项 skill → 路由到对应 skill
     └─ 无专项 skill → 本 skill 直接指导
          ↓
     执行完成后
          ↓
     质量门禁检查（§6）
          ↓
     调用 UrhoX MCP build 工具验证（§8）
          ↓
     生成报告（§7.2）
```

---

## 参考文档

- `references/tool-catalog.md` — 完整工具目录与参数速查
- `references/prompt-templates.md` — 各品类 AI 工具的 Prompt 模板库
