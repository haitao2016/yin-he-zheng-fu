# MoneyPrinterPlus → UrhoX 游戏宣传视频 完整映射表

> 本文档将 [MoneyPrinterPlus](https://github.com/ddean2009/MoneyPrinterPlus) 的每一项功能
> 精确映射到 UrhoX 引擎的 MCP 工具和工作流。
> 供 AI 在执行 game-promo-video-forge 管线时快速查找对应关系。

---

## 1. 管线阶段映射

| # | MoneyPrinterPlus 阶段 | UrhoX 对应阶段 | MCP 工具 / 方法 | 输出位置 |
|---|----------------------|---------------|----------------|---------|
| 1 | 关键词/主题输入 | 游戏分析（读 `scripts/` 源码） | Claude 代码分析 | — |
| 2 | LLM 生成文案 | AI 生成宣传脚本（promo-script-v1 JSON） | Claude 直接生成 | `scripts/data/promo/*.json` |
| 3 | TTS 语音合成（Azure/阿里云/GPT-SoVITS） | 旁白配音 | `audition_voices_for_character` → `confirm_character_voice` → `text_to_dialogue` | `assets/Sounds/promo_*.ogg` |
| 4 | Pexels/Pixabay 素材搜索 | 游戏截图 + AI 生成图片 | `generate_image` / `batch_generate_images` | `game_material/promo/` |
| 5 | BGM/背景音乐 | BGM 生成 | `text_to_music` | `assets/Music/promo_bgm.ogg` |
| 6 | FFmpeg 视频合成 + 30+ 转场 | AI 视频生成（Seedance） | `create_video_task` / `query_video_task` | `game_material/promo/clips/` |
| 7 | SRT 字幕叠加 | 视频 prompt 内嵌文案 | `create_video_task` prompt 参数 | 嵌入视频 |
| 8 | 批量混剪/多版本输出 | 循环生成不同参数视频 | 多次 `create_video_task` | `game_material/promo/final/` |
| 9 | 自动发布（YouTube/抖音/TikTok） | TapTap 物料上传 | `upload_game_material` / `publish_to_taptap` | `.project/project.json` |

---

## 2. 功能对比详表

### 2.1 文案生成

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 输入 | 关键词/主题 | 游戏 `scripts/` 源码 + 用户描述 |
| 引擎 | OpenAI/Moonshot/通义千问/DeepSeek | Claude（内置 AI） |
| 输出格式 | 纯文本文案 | 结构化 promo-script-v1 JSON |
| 分镜 | 无内置分镜 | 自动生成分镜（scenes 数组） |
| 持久化 | 无 | JSON 保存到 `scripts/data/promo/` |

### 2.2 语音合成（TTS）

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 提供商 | Azure/阿里云/GPT-SoVITS/ChatTTS | ElevenLabs（引擎内置） |
| 声音选择 | 预设声音列表 | AI 声音设计（六维度 prompt） |
| 情绪标签 | 有限支持 | `[laughing]` `[excited]` `[sad]` 等丰富标签 |
| 多角色 | 支持 | 支持（每角色独立 voice mapping） |
| 格式 | MP3/WAV | OGG（引擎标准） |
| 构建集成 | 无 | 音频放 `assets/Sounds/` 通过构建打包 |

**情绪标签映射**：

| MoneyPrinterPlus 情绪 | UrhoX text_to_dialogue 标签 |
|----------------------|---------------------------|
| 平静 / neutral | 无标签（默认） |
| 兴奋 / excited | `[excited]` / `[enthusiastic]` |
| 严肃 / serious | `stability: 0.8`（高稳定性） |
| 悲伤 / sad | `[sad]` / `[crying]` |
| 紧张 / tense | `[nervous]` / `[anxious]` |
| 欢快 / cheerful | `[laughing]` / `[chuckling]` |
| 低语 / whisper | `[whispering]` / `[softly]` |
| 呐喊 / shout | `[shouting]` / `[yelling]` |

### 2.3 视频素材

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 来源 | Pexels/Pixabay（通用素材库） | 游戏截图（真实画面）+ AI 生成（`generate_image`） |
| 类型 | 视频片段 | 静态图片 → AI 动态化（Seedance） |
| 匹配 | 关键词搜索 | 语义匹配（AI 分析游戏内容） |
| 版权 | CC0 公共领域 | 自有游戏素材（无版权风险） |
| 截图工具 | 无 | 引擎预览窗口"截图插入对话"功能 |

### 2.4 字幕处理

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 格式 | SRT 文件 | subtitle-timeline-v1 JSON |
| 叠加方式 | FFmpeg 硬编码 | 视频 prompt 描述（AI 生成时嵌入） |
| 位置控制 | 固定位置 | prompt 自然语言描述位置 |
| 样式 | 字体/颜色/大小 | AI 自然渲染 |
| 多语言 | 支持 | 通过不同 prompt 生成多语言版本 |

### 2.5 转场特效

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 实现 | FFmpeg 滤镜（30+ 种） | AI 视频生成自然过渡 |
| 类型 | 淡入淡出/滑动/缩放/翻转等 | prompt 描述 + `first_last_frame` 模式衔接 |
| 控制 | 精确参数 | 自然语言引导 |
| 质量 | 固定模板 | AI 理解场景生成匹配转场 |

### 2.6 批量生产

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 机制 | 并行调用 FFmpeg | 循环调用 `create_video_task` |
| 状态管理 | 内存中 | promo-state-v1 JSON 持久化保存 |
| 失败重试 | 有 | 按 scene_id 重试（读 state JSON 存档） |
| 并发 | 多线程 | 建议 ≤3 并发（API 限制） |
| 变体 | 不同文案/素材组合 | 不同 prompt/orientation/style |

### 2.7 发布

| 维度 | MoneyPrinterPlus | UrhoX game-promo-video-forge |
|------|-----------------|------------------------------|
| 平台 | YouTube/抖音/TikTok/视频号/快手 | TapTap |
| 方式 | Selenium 自动化 | MCP `upload_game_material` API |
| 配置 | Web UI 填写 | `.project/project.json` |
| 元数据 | 标题/描述/标签 | title/description/category |

---

## 3. 技术栈对比

| 层 | MoneyPrinterPlus | game-promo-video-forge |
|----|-----------------|------------------------|
| 语言 | Python 3.10+ | Lua 5.4 (UrhoX) |
| UI | Streamlit | UrhoX UI 组件（`scripts/` 中编写） |
| 视频处理 | FFmpeg + MoviePy | Seedance AI (MCP `create_video_task`) |
| 音频处理 | pydub | ElevenLabs (MCP `text_to_dialogue`) |
| 图像处理 | Pillow | AI 生成 (MCP `generate_image`) |
| 部署 | Docker / 本地 | 构建打包 → TapTap 发布 |
| 状态存储 | SQLite / 文件 | JSON (`scripts/data/promo/` 持久化存档) |

---

## 4. 能力差异说明

### UrhoX 方案的优势

| 优势 | 说明 |
|------|------|
| **无版权风险** | 使用自己的游戏截图，不依赖第三方素材库 |
| **AI 原生视频** | Seedance 直接生成视频，而非拼接素材 |
| **游戏深度集成** | 分析 `scripts/` 游戏代码自动提取宣传要点 |
| **一站式发布** | 从脚本到 TapTap 上架全自动 |
| **构建管线集成** | 资源通过引擎构建系统统一管理 |

### MoneyPrinterPlus 的优势

| 优势 | UrhoX 替代方案 |
|------|---------------|
| 30+ 精确转场特效 | AI 自然过渡（风格不同，非劣势） |
| 多平台同时发布 | 仅支持 TapTap（游戏开发专用） |
| 实时预览编辑 | 分步生成 + PromoVideoPlayer 回放 |
| SRT 精确时间轴 | prompt 语义控制（足够宣传片场景） |

---

## 5. 快速查找索引

> 我需要做 X，应该用什么 MCP 工具？

| 我需要… | MCP 工具 | 关键参数 |
|---------|---------|---------|
| 生成宣传文案 | Claude 直接生成 | 输出 promo-script-v1 JSON |
| 制作开场 Logo 动画 | `generate_image` → `create_video_task` | mode=`first_frame`, prompt 描述动画 |
| 给截图加运镜 | `create_video_task` | mode=`first_frame`, prompt 描述运镜 |
| 录旁白配音 | `audition_voices_for_character` → `text_to_dialogue` | 六维度 voice prompt |
| 生成 BGM | `text_to_music` | style + prompt 描述风格 |
| 生成音效 | `text_to_sound_effect` | text 描述音效（英文） |
| 截图之间加转场 | `create_video_task` | mode=`first_last_frame`（首尾帧） |
| 批量生成视频 | 循环 `create_video_task` | 用 promo-state-v1 JSON 跟踪状态 |
| 上传到 TapTap | `upload_game_material` | type=`PROMO`/`SCREENSHOT` |
| 正式发布 | `publish_to_taptap` | 需要 `.project/project.json` 配置 |
| 生成 AI 图片素材 | `generate_image` / `batch_generate_images` | prompt + target_size |
| 查询视频任务状态 | `query_video_task` | task_id（间隔 ≥120s） |
| 上传角色形象供视频使用 | `upload_asset` | 返回 asset_uri 用于 `create_video_task` |

---

## 6. 文件组织规范

```
scripts/
├── data/
│   └── promo/
│       ├── trailer_main.json          # promo-script-v1 宣传脚本
│       ├── trailer_teaser.json        # 另一个脚本变体
│       └── state.json                 # promo-state-v1 生产状态（持久化存档）
├── systems/
│   ├── PromoVideoPlayer.lua           # 游戏内视频播放模块
│   └── PromoScriptLoader.lua          # 脚本加载与验证模块
└── main.lua                           # 入口文件

assets/
├── Sounds/
│   └── promo_narration.ogg            # 旁白配音
└── Music/
    └── promo_bgm.ogg                  # BGM

game_material/
└── promo/
    ├── s01_opening.png                # AI 生成的场景图
    ├── clips/
    │   ├── s01_opening.mp4            # 合成的视频片段
    │   └── s02_gameplay.mp4
    └── final/
        ├── trailer_landscape.mp4      # 横屏最终版
        └── trailer_portrait.mp4       # 竖屏最终版
```

> **构建规则**：`scripts/` 和 `assets/` 目录的内容通过引擎构建系统打包。
> `game_material/` 用于发布物料上传，不参与游戏运行时构建。
