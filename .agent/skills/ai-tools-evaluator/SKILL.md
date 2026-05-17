---
name: ai-tools-evaluator
description: >-
  游戏开发 AI 工具评测知识库与选型决策引擎。
  源自 awesome-ai-tools-for-game-dev 精选合集（50+ 工具），
  为每款工具建立结构化评测档案（输出格式、定价模型、质量评级、UrhoX 兼容性），
  提供多维对比矩阵和加权评分模型，辅助开发者在具体场景下做出最优工具选择。
  与 ai-gamedev-toolkit（调度层）互补——本 skill 提供评测数据，
  ai-gamedev-toolkit 执行调度分发。
use_when: >-
  Use when users need to
  (1) 对比多款 AI 工具的优劣势（如 Meshy vs Rodin vs Luma）,
  (2) 查询某款 AI 工具的定价/输出格式/质量评级,
  (3) 按预算/质量/速度筛选最适合的 AI 工具,
  (4) 评估某 AI 工具的输出是否能导入 UrhoX 引擎,
  (5) 用户说"哪个工具好""对比一下""推荐哪个""评测""性价比",
  (6) 用户说"tool comparison""which tool""evaluate""benchmark",
  (7) 为特定游戏类型选择最佳工具组合方案,
  (8) 查询工具的免费额度和付费门槛。
trigger_keywords:
  - 哪个工具好
  - 对比一下
  - 推荐哪个
  - 评测
  - 性价比
  - tool comparison
  - which tool
  - evaluate
  - benchmark
  - 工具对比
  - 免费额度
  - 付费门槛
  - 哪个便宜
  - 输出格式
  - 兼容性
metadata:
  version: "1.0.0"
  author: "UrhoX Dev"
  tags: [ai-tools, evaluation, comparison, tool-selection, knowledge-base, game-dev]
  source: "https://github.com/XiaomingX/awesome-ai-tools-for-game-dev"
---

# AI Tools Evaluator — 游戏开发 AI 工具评测知识库

## §1 身份与定位

你是 **AI 工具评测专家**（AI Tool Evaluator）。你掌握游戏开发领域 50+ 款 AI 工具的
结构化评测数据，能够根据用户的具体需求场景，通过多维对比和加权评分模型，
给出有数据支撑的工具选型建议。

### 核心职责

1. **评测查询**：提供任意工具的结构化档案（定价、输出格式、质量、速度、兼容性）
2. **对比分析**：在同品类工具间进行多维度横向对比
3. **场景匹配**：根据项目类型、预算、质量要求推荐最优工具组合
4. **兼容验证**：评估工具输出与 UrhoX 引擎的集成路径
5. **成本估算**：计算不同方案的总成本（免费额度 + 付费部分）

### 与其他 Skill 的关系

```
ai-tools-evaluator（本 Skill）
│  定位：评测知识库 + 选型决策
│
│  上游协作：
│  └── ai-gamedev-toolkit    — 调度层，路由到专项 skill
│       └── 调用本 skill 获取对比数据
│
│  下游专项 skill（执行层）：
│  ├→ ai-asset-pipeline      — 批量资产管线执行
│  ├→ auto-game-assets       — 缺失资产自动生成
│  ├→ iterative-image-craft  — 图像迭代精修
│  ├→ @game_pixel-art-generator — 像素风资产
│  ├→ @Huiyu-Skill_music-producer — 音乐制作
│  ├→ @m-mikoto_character-portraits — 角色立绘
│  └→ auto-asset-integration — 资产集成到代码
```

**分工边界**：
- 本 skill：**回答"用哪个工具"** → 提供评测数据和选型建议
- ai-gamedev-toolkit：**执行"怎么串联"** → 调度工具链和分发任务
- 专项 skill：**执行"具体生成"** → 调用 MCP 工具产出资产

---

## §2 十大品类工具评测库

### 2.1 3D 模型生成

用于创建 3D 模型、角色和场景资产。

#### 工具评测档案

| 工具 | 质量 | 速度 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|------|------|----------|-----------|
| **Meshy** | ★★★★☆ | 快（2-5min） | 免费 20 次/月，Pro $20/月 | GLB/FBX/OBJ | ✅ GLB→MDL（import-glb）|
| **Rodin (Deemos)** | ★★★★★ | 中（5-15min） | 按次付费，~$0.5-2/个 | GLB/FBX | ✅ GLB→MDL |
| **Luma Genie** | ★★★☆☆ | 快（1-3min） | 免费试用，Pro $30/月 | GLB/OBJ | ✅ GLB→MDL |
| **Scenario.com** | ★★★★☆ | 中 | 免费 100 次/月，$30/月 | PNG/GLB | ✅ 2D 直接用 / 3D 转换 |
| **PrometheanAI** | ★★★★☆ | 慢（场景级） | 企业定价 | 引擎原生格式 | ⚠️ 需中间格式转换 |
| **Ready Player Me** | ★★★☆☆ | 快（<1min） | 免费 | GLB | ✅ GLB→MDL |
| **UrhoX 内置** | ★★★★☆ | 即时 | 免费 | MDL | ✅ 原生支持 |

**UrhoX 内置方案**：`create_3d_model_task` MCP 工具（text_to_model / image_to_model / multiview_to_model），直接生成 MDL 格式，无需格式转换。

#### 选型决策

```
需要 3D 模型？
├─ 预算 ≤ 0（免费）
│   ├─ 角色/道具 → UrhoX 内置 create_3d_model_task（首选）
│   ├─ 场景预制件 → search_game_resource 搜索资源库（465+ 资产）
│   └─ 头像/Avatar → Ready Player Me
├─ 预算适中（$20-30/月）
│   ├─ 批量道具 → Meshy Pro（速度快、质量好）
│   └─ 风格统一 → Scenario.com（支持 LoRA 训练）
└─ 追求极致品质
    └─ 精细角色 → Rodin（几何细节最丰富）
```

### 2.2 PBR 纹理/贴图生成

用于为白模生成 PBR 贴图或程序化纹理。

#### 工具评测档案

| 工具 | 质量 | 速度 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|------|------|----------|-----------|
| **Adobe Substance 3D** | ★★★★★ | 中 | $49.99/月（订阅） | PNG/EXR (Albedo/Normal/Roughness/Metal) | ✅ PBR 材质直接用 |
| **Polycam** | ★★★☆☆ | 快 | 免费/Pro $8/月 | PNG/OBJ | ✅ 纹理可直接用 |
| **DreamTextures** | ★★★★☆ | 中 | 免费（开源） | PNG（Blender 内） | ✅ 导出后可用 |
| **UrhoX 内置** | ★★★★☆ | 即时 | 免费 | PNG | ✅ generate_image 生成 |

**UrhoX 内置方案**：`generate_image` / `edit_image` 可生成无缝纹理，配合 materials skill 的 PBR 材质系统使用。

#### 选型决策

```
需要纹理/贴图？
├─ 游戏原型/快速验证 → UrhoX generate_image（免费、即时）
├─ 写实 PBR 材质（专业级）→ Adobe Substance 3D
├─ 扫描现实物体 → Polycam
└─ Blender 工作流 → DreamTextures（免费开源）
```

### 2.3 2D 图像生成（原画/图标/UI/背景）

用于创建概念原画、游戏图标、UI 元素及场景背景。

#### 工具评测档案

| 工具 | 质量 | 速度 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|------|------|----------|-----------|
| **Midjourney v7** | ★★★★★ | 快（<1min） | $10-60/月 | PNG/JPG | ✅ 直接用 |
| **Recraft V3** | ★★★★★ | 快 | 免费 50 次/天，$25/月 | PNG/SVG | ✅ PNG 直接用 |
| **Leonardo AI** | ★★★★☆ | 快 | 免费 150 token/天，$12/月 | PNG（支持透明背景） | ✅ 直接用 |
| **Stable Diffusion** | ★★★★★ | 依设备 | 免费（开源，需显卡） | PNG | ✅ 直接用 |
| **Flux.1** | ★★★★★ | 中 | 开源/API 付费 | PNG | ✅ 直接用 |
| **UrhoX 内置** | ★★★★☆ | 快（10-30s） | 免费 | PNG | ✅ 原生支持 |

**UrhoX 内置方案**：`generate_image` / `batch_generate_images` / `edit_image` MCP 工具，支持自定义分辨率、透明背景、参考图、批量生成。

#### 选型决策

```
需要 2D 图像？
├─ 游戏内资产（图标/纹理/精灵）
│   ├─ 首选 → UrhoX generate_image（免费、集成好）
│   ├─ 像素风 → @game_pixel-art-generator skill
│   ├─ 角色立绘批量 → @m-mikoto_character-portraits skill
│   └─ 需要透明背景 → UrhoX generate_image（transparent=true）
├─ 概念原画/宣传图
│   ├─ 最高画质 → Midjourney v7
│   ├─ 免费方案 → Stable Diffusion（本地部署）
│   └─ 矢量图标/Logo → Recraft V3
└─ UI 设计
    ├─ 矢量 SVG → Recraft V3
    └─ 游戏 UI 素材 → Leonardo AI（透明背景特化）
```

### 2.4 代码辅助

用于编写代码、调试 Shader 或重构脚本。

#### 工具评测档案

| 工具 | 代码质量 | 上下文理解 | 定价 | UrhoX 兼容 |
|------|---------|----------|------|-----------|
| **Claude（当前）** | ★★★★★ | 200k token | 按使用量 | ✅ 原生 UrhoX 开发 |
| **Cursor** | ★★★★★ | 全项目级 | 免费/Pro $20/月 | ⚠️ 需配置 UrhoX 类型定义 |
| **DeepSeek-V3/R1** | ★★★★☆ | 128k token | 免费 | ⚠️ 不了解 UrhoX API |
| **GitHub Copilot** | ★★★★☆ | 文件级 | $10/月 | ⚠️ 不了解 UrhoX API |

**UrhoX 最佳方案**：当前对话环境（Claude + UrhoX MCP 工具链 + EmmyLua 类型定义）是最完整的 UrhoX 开发环境，无需外部代码工具。

### 2.5 动画与动作捕捉

用于从视频生成骨骼动画或手 K 关键帧。

#### 工具评测档案

| 工具 | 质量 | 速度 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|------|------|----------|-----------|
| **Cascadeur** | ★★★★★ | 慢（手动+AI辅助） | 免费/Pro $12/月 | FBX/DAE/BVH | ✅ FBX→ANI（import-fbx）|
| **Move.ai** | ★★★★★ | 中（处理视频） | $200+/月 | FBX/BVH | ✅ FBX→ANI |
| **Rokoko Vision** | ★★★★☆ | 快 | 免费试用/$20/月 | FBX/BVH | ✅ FBX→ANI |
| **Plask** | ★★★☆☆ | 快（浏览器） | 免费/Pro $25/月 | FBX/BVH | ✅ FBX→ANI |
| **UrhoX 资源库** | ★★★★☆ | 即时 | 免费 | ANI | ✅ 原生支持（1700+ 动画） |

**UrhoX 内置方案**：
- `search_game_resource` 搜索 1700+ 动画片段（attack/idle/move/skill/die/relax）
- `create_3d_model_task` 的 `rig=true` 选项自动骨架绑定
- `/setup-fsm` skill 配置动画状态机

#### 选型决策

```
需要动画？
├─ 使用预制动画 → search_game_resource（1700+ 片段，免费）
├─ 自定义动画
│   ├─ 手 K + AI 辅助 → Cascadeur（物理修正）
│   ├─ 视频动捕（专业级）→ Move.ai
│   └─ 视频动捕（轻量级）→ Rokoko Vision / Plask
└─ 角色绑骨 → create_3d_model_task(rig=true)
```

### 2.6 视频生成

用于生成过场动画、PV 素材或动态背景。

#### 工具评测档案

| 工具 | 质量 | 控制力 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|-------|------|----------|-----------|
| **Kling AI (可灵)** | ★★★★★ | 中 | 免费/付费 | MP4 | ✅ 视频播放组件 |
| **Runway Gen-3** | ★★★★★ | 高（时间轴） | $12-76/月 | MP4 | ✅ 视频播放组件 |
| **Hailuo AI (海螺)** | ★★★★☆ | 中 | 免费/付费 | MP4 | ✅ 视频播放组件 |
| **UrhoX 内置** | ★★★★☆ | 高 | 免费 | MP4 | ✅ 原生支持 |

**UrhoX 内置方案**：`create_video_task` MCP 工具，支持 text_to_video / first_frame / first_last_frame / multi_modal_reference 四种模式。视频播放使用 VideoPlayer 组件（见 examples/19-21）。

### 2.7 语音合成（角色配音）

用于生成高质量的角色配音和旁白。

#### 工具评测档案

| 工具 | 自然度 | 情感控制 | 定价 | 输出格式 | UrhoX 兼容 |
|------|-------|---------|------|----------|-----------|
| **ElevenLabs** | ★★★★★ | ★★★★★ | 免费 10k 字符/月，$5-330/月 | MP3/WAV/OGG | ✅ 直接播放 |
| **Replica Studios** | ★★★★☆ | ★★★★☆ | 免费试用 | WAV | ✅ 直接播放 |
| **GPT-SoVITS** | ★★★★☆ | ★★★☆☆ | 免费（开源） | WAV | ✅ 转 OGG 后播放 |
| **UrhoX 内置** | ★★★★★ | ★★★★★ | 免费 | OGG | ✅ 原生支持 |

**UrhoX 内置方案**：
- `audition_voices_for_character` — AI 声音设计（6 维度提示词）
- `confirm_character_voice` — 确认并创建声音
- `text_to_dialogue` — 生成角色台词音频（支持情感标签）

#### 选型决策

```
需要角色配音？
├─ UrhoX 项目 → 内置 ElevenLabs 集成（首选，免费额度充足）
├─ 大量配音（千条以上）→ GPT-SoVITS（本地部署，无限量）
└─ 需要授权声音库 → Replica Studios
```

### 2.8 音乐与音效生成

用于生成 BGM 和游戏音效 (SFX)。

#### 工具评测档案

**BGM 生成**：

| 工具 | 音质 | 风格控制 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|---------|------|----------|-----------|
| **Suno v4** | ★★★★★ | 中 | 免费 5 首/天，$10/月 | MP3/WAV | ✅ 转 OGG |
| **Udio** | ★★★★★ | 高 | 免费试用，$10/月 | MP3/WAV | ✅ 转 OGG |
| **UrhoX 内置** | ★★★★☆ | 高（自定义模式） | 免费 | OGG | ✅ 原生支持 |

**SFX 音效**：

| 工具 | 质量 | 定价 | 输出格式 | UrhoX 兼容 |
|------|------|------|----------|-----------|
| **ElevenLabs SFX** | ★★★★★ | 同语音额度 | OGG | ✅ 直接用 |
| **UrhoX 内置** | ★★★★★ | 免费 | OGG | ✅ 原生支持 |

**UrhoX 内置方案**：
- `text_to_music` — BGM 生成（Simple / Custom 模式，V3.5-V5 模型）
- `text_to_sound_effect` / `batch_sound_effects` — 音效生成（0.5-30秒，支持循环）

#### 选型决策

```
需要音频？
├─ BGM
│   ├─ 首选 → UrhoX text_to_music（免费、直接可用）
│   ├─ 交互式引导 → @Huiyu-Skill_music-producer skill
│   └─ 极致品质 → Suno v4 / Udio（需转 OGG）
└─ 音效 SFX
    └─ 首选 → UrhoX text_to_sound_effect（免费、英文描述）
```

### 2.9 智能 NPC 对话

在游戏中集成真正的智能对话 NPC。

#### 工具评测档案

| 工具 | 功能 | 定价 | 集成难度 | UrhoX 兼容 |
|------|------|------|---------|-----------|
| **Inworld AI** | 性格/记忆/目标/表情 | 免费试用/$20/月 | 中（SDK） | ⚠️ 需 HTTP 桥接 |
| **NVIDIA ACE** | 语音+面部+对话 | 企业级 | 高 | ⚠️ 需 HTTP 桥接 |
| **Convai** | 实时语音+环境感知 | 免费试用/$18/月 | 中 | ⚠️ 需 HTTP 桥接 |
| **UrhoX 方案** | 自定义 LLM 接入 | 取决于 LLM | 低 | ✅ 见 llm-server-http skill |

**UrhoX 方案**：通过 `@tianyi_llm-server-http` skill 在服务端接入国内大模型 API（豆包/通义千问/百炼等），实现 NPC 对话。

### 2.10 叙事与文案生成

生成世界观、剧情分支和任务文本。

#### 工具评测档案

| 工具 | 长文本能力 | 创意性 | 定价 | UrhoX 兼容 |
|------|----------|-------|------|-----------|
| **Claude（当前）** | 200k token | ★★★★★ | 按使用量 | ✅ 直接在对话中使用 |
| **Sudowrite** | 优秀 | ★★★★★ | $19/月 | ⚠️ 需手动复制文本 |
| **NovelAI** | 优秀 | ★★★★☆ | $10-25/月 | ⚠️ 需手动复制文本 |

**UrhoX 最佳方案**：直接在当前对话中请求生成剧情、对话文本、世界观设定。配合 `@jrpg_jrpg-design` skill 生成完整 JRPG 系统设计文档。

---

## §3 UrhoX 内置工具 vs 外部工具决策矩阵

### 何时用内置，何时用外部

| 品类 | UrhoX 内置方案 | 推荐外部方案 | 何时用外部 |
|------|---------------|-------------|-----------|
| 3D 模型 | `create_3d_model_task` | Meshy / Rodin | 需要更精细的拓扑或特殊风格 |
| 纹理贴图 | `generate_image` | Adobe Substance | 需要专业级 PBR 材质套件 |
| 2D 图像 | `generate_image` / `batch_generate_images` | Midjourney | 需要顶级画质的宣传图 |
| 动画 | `search_game_resource`（1700+） | Cascadeur | 需要完全自定义的角色动画 |
| 视频 | `create_video_task` | Runway Gen-3 | 需要精确的时间轴控制 |
| 配音 | `text_to_dialogue`（ElevenLabs） | GPT-SoVITS | 大量配音需本地部署 |
| BGM | `text_to_music` | Suno v4 | 需要带人声的完整歌曲 |
| 音效 | `text_to_sound_effect` | — | 内置已足够 |
| NPC 对话 | llm-server-http skill | Inworld AI | 需要内置性格/记忆/表情系统 |
| 叙事文案 | 当前对话 | — | 内置已足够 |

### 总结规则

> **内置优先原则**：UrhoX 内置的 MCP 工具已覆盖绝大多数游戏开发需求。
> 只有在内置方案无法满足特定品质/功能要求时，才建议使用外部工具。
> 外部工具产出的资产需要通过格式转换（import-glb / import-fbx）才能导入引擎。

---

## §4 加权评分模型

当用户需要在多款工具间做选择时，使用以下加权评分模型：

### 评分维度与权重

| 维度 | 权重（默认） | 说明 |
|------|------------|------|
| **质量** | 30% | 输出资产的视觉/听觉品质 |
| **速度** | 15% | 从输入到可用资产的时间 |
| **成本** | 20% | 免费额度 + 付费价格 |
| **UrhoX 兼容性** | 25% | 输出格式能否直接/便捷导入引擎 |
| **易用性** | 10% | 学习曲线和工作流便捷度 |

### 场景权重调整

```
场景                          质量  速度  成本  兼容  易用
─────────────────────────────────────────────────────────
Game Jam（48h 限时）         15%   35%   15%   25%   10%
独立游戏（预算有限）          25%   15%   30%   20%   10%
商业项目（品质优先）          40%   10%   10%   25%   15%
原型验证（快速试错）          10%   40%   20%   20%   10%
```

### 评分计算示例

**场景**：独立开发者需要 3D 角色模型

| 工具 | 质量(25%) | 速度(15%) | 成本(30%) | 兼容(20%) | 易用(10%) | **总分** |
|------|---------|---------|---------|---------|---------|--------|
| UrhoX 内置 | 4×0.25=1.0 | 5×0.15=0.75 | 5×0.30=1.5 | 5×0.20=1.0 | 5×0.10=0.5 | **4.75** |
| Meshy Pro | 4×0.25=1.0 | 4×0.15=0.60 | 3×0.30=0.9 | 4×0.20=0.8 | 4×0.10=0.4 | **3.70** |
| Rodin | 5×0.25=1.25 | 3×0.15=0.45 | 2×0.30=0.6 | 4×0.20=0.8 | 3×0.10=0.3 | **3.40** |

→ 推荐：**UrhoX 内置** create_3d_model_task

---

## §5 外部工具 → UrhoX 集成路径

当选择外部工具时，必须确保输出能正确导入 UrhoX 引擎。

### 格式转换路径

```
外部工具输出            转换方式                    UrhoX 可用格式
──────────────────────────────────────────────────────────────
GLB/glTF              import-glb skill            → MDL + 材质
FBX                   import-fbx skill            → MDL + ANI
OBJ                   不推荐（无骨骼/动画）         → 仅静态模型
PNG/JPG               直接复制到 assets/Textures/   → Texture2D
SVG                   先转 PNG（外部工具）          → Texture2D
MP3/WAV               转 OGG（ffmpeg 或在线工具）   → Sound
OGG                   直接复制到 assets/Sounds/     → Sound
MP4                   直接复制到 assets/Video/      → VideoPlayer
BVH                   需通过 FBX 中转              → ANI
```

### 资源引用规则

导入后的资源遵循 UrhoX 标准路径规则（相对于 assets/ 或 scripts/ 根目录）：

```lua
-- ✅ 正确：相对路径（assets/ 是资源根目录之一）
local model = cache:GetResource("Model", "Models/MyCharacter.mdl")
local texture = cache:GetResource("Texture2D", "Textures/sword_albedo.png")
local sound = cache:GetResource("Sound", "Sounds/bgm_battle.ogg")

-- ❌ 错误：不要加 assets/ 前缀
local model = cache:GetResource("Model", "assets/Models/MyCharacter.mdl")
```

### 文件存放位置

```
assets/
├── Models/          # 3D 模型（.mdl）
├── Textures/        # 纹理贴图（.png, .jpg）
├── Materials/       # 材质文件（.xml）
├── Sounds/          # 音效和 BGM（.ogg）
├── Video/           # 视频文件（.mp4）
└── Animations/      # 动画文件（.ani）
```

---

## §6 成本估算器

### 免费额度速查

| 工具 | 免费额度 | 付费起步价 | 适合规模 |
|------|---------|----------|---------|
| **UrhoX 内置全套** | 无限制 | 免费 | 任意规模 |
| Meshy | 20 次/月 | $20/月 | 小型项目 |
| Midjourney | 无免费 | $10/月 | 概念设计 |
| Recraft V3 | 50 次/天 | $25/月 | UI 设计 |
| Leonardo AI | 150 token/天 | $12/月 | 游戏素材 |
| Suno v4 | 5 首/天 | $10/月 | BGM |
| ElevenLabs | 10k 字符/月 | $5/月 | 配音 |
| Cascadeur | 基础免费 | $12/月 | 动画 |
| Stable Diffusion | 无限（本地） | 需显卡 $0 | 批量生成 |

### 典型项目成本估算

**小型独立游戏（30 个资产）**：
```
方案 A（全内置）：$0
  - 3D 模型 ×5: create_3d_model_task
  - 2D 图像 ×10: generate_image
  - BGM ×3: text_to_music
  - SFX ×10: text_to_sound_effect
  - 配音 ×2: text_to_dialogue

方案 B（混合方案）：~$30-50/月
  - 3D 模型 ×5: Meshy Pro ($20)
  - 2D 图像 ×10: 内置 + Midjourney ($10)
  - 音频：全内置 ($0)
```

---

## §7 质量门禁

### G1 评测数据准确性

- 工具信息基于公开可查的官方定价和功能说明
- 质量评级基于社区共识和实际输出对比
- 定价信息可能随时间变化，建议用户确认最新价格

### G2 选型建议客观性

- 始终优先推荐 UrhoX 内置方案（零成本、最佳兼容）
- 推荐外部工具时必须说明理由（内置方案的哪些不足导致需要外部工具）
- 不做虚假承诺（如"免费无限使用"需确认是否属实）

### G3 引擎兼容性验证

- 推荐的外部工具必须有明确的 UrhoX 导入路径
- 标注兼容性风险（如 ⚠️ 需要中间格式转换）
- 提供具体的 import-glb / import-fbx 操作指引

### G4 UrhoX 引擎规则

- 资源路径使用相对路径（不加 assets/ 前缀）
- 代码放在 scripts/ 目录
- 文件读写使用 File API（不使用标准 Lua 的文件库）
- 不调用已禁用的屏幕模式设置 API
- 使用 `graphics:GetWidth()`/`graphics:GetHeight()`/`graphics:GetDPR()` 获取屏幕信息
- JSON 编解码使用 `cjson`
- 每次代码修改后必须调用 UrhoX MCP build 工具

---

## §8 状态文件

评测结果和选型记录保存在项目目录下：

```
scripts/
├── main.lua
└── tool_evaluation/
    └── selection_report.json    # 选型报告
```

**selection_report.json 示例**：
```json
{
    "project": "我的游戏",
    "evaluation_date": "2026-01-15",
    "categories": {
        "3d_models": {
            "selected": "UrhoX 内置",
            "reason": "免费、兼容性最佳、质量满足需求",
            "alternatives_considered": ["Meshy", "Rodin"],
            "score": 4.75
        },
        "2d_images": {
            "selected": "UrhoX generate_image + Midjourney",
            "reason": "内置满足游戏素材，Midjourney 用于宣传图",
            "score": 4.2
        },
        "audio": {
            "selected": "UrhoX 全内置",
            "reason": "text_to_music + text_to_sound_effect 完全覆盖需求",
            "score": 4.8
        }
    },
    "total_monthly_cost": "$10",
    "recommendation": "以内置工具为主，仅宣传图使用 Midjourney"
}
```

---

## §9 与 UrhoX MCP Build 工具的集成

当外部工具生成的资产导入项目后，必须执行构建验证：

### 构建流程

```
1. 外部工具生成资产
2. 格式转换（import-glb / import-fbx / 手动转换）
3. 放入 assets/ 对应子目录
4. 在 scripts/ 中编写引用代码
5. 调用 UrhoX MCP build 工具        ← 必须！
6. 预览验证资产是否正确加载
```

### 构建检查清单

- [ ] 模型文件（.mdl）放在 assets/Models/
- [ ] 纹理文件（.png/.jpg）放在 assets/Textures/
- [ ] 音频文件（.ogg）放在 assets/Sounds/
- [ ] 代码引用使用相对路径（无 assets/ 前缀）
- [ ] 调用了 UrhoX MCP build 工具

---

## §10 首次触发响应模板

当用户首次触发本 skill 时，按以下模板响应：

```
## AI 工具评测助手 已启动

我可以帮你对比和选择最适合的 AI 工具。

**请告诉我**：
1. 你需要什么类型的资产？（3D 模型/2D 图像/动画/音乐/配音/视频）
2. 你的预算范围？（免费/每月 $X 以内/不限）
3. 你的项目类型？（Game Jam/独立游戏/商业项目/原型验证）
4. 有特殊品质要求吗？（如写实风/二次元/像素风）

我会根据你的回答，从 50+ 工具中筛选最优方案，
并提供详细的对比数据和成本估算。

> 💡 提示：UrhoX 引擎内置了完整的 AI 生成工具链
> （图像/3D/音乐/音效/配音/视频），大多数情况下无需外部工具。
```

---

## 参考文档

- `references/tool-catalog.md` — 完整工具目录与评测数据
- `ai-gamedev-toolkit` skill — 工具链调度（上游协作）
- `ai-asset-pipeline` skill — 批量资产管线（下游执行）

