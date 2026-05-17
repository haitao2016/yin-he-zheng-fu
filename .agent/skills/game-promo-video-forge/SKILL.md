---
name: game-promo-video-forge
description: |
  游戏宣传短视频自动化锻造管线——将 MoneyPrinterPlus 的"关键词→文案→配音→
  素材→字幕→合成→发布"全流程映射为 UrhoX 游戏引擎可用的端到端宣传视频生产系统。
  覆盖：游戏分析→宣传脚本→分镜规划→截图采集→旁白配音→BGM 生成→
  视频合成→字幕叠加→多版本输出→物料上传。

  灵感来源：ddean2009/MoneyPrinterPlus（https://github.com/ddean2009/MoneyPrinterPlus）
  —— AI 短视频批量生成工具，支持文案生成、语音合成、素材匹配、字幕叠加、
  视频混剪、30+ 转场特效、批量输出。

  本 Skill 将其核心管线理念适配为游戏开发场景：不是通用短视频，
  而是专注于游戏宣传片/预告片/Gameplay Demo 的自动化生产。

  与现有 Skill 的区别：
  - cinematic-dub-pipeline：游戏过场动画的多语言配音系统（游戏内播放）
  - game-content-factory：发布文案（GDD、商店描述、更新公告）的文字生成
  - auto-game-assets：缺失游戏资源的扫描与 AI 补全
  - 本 Skill：游戏宣传短视频的完整生产管线（从脚本到成品视频文件）

Use when:
  - (1) 用户需要为游戏制作宣传视频/预告片/Gameplay Demo
  - (2) 用户说"做个宣传视频""生成游戏预告""制作 Trailer"
  - (3) 用户需要批量生成不同风格/时长的宣传短视频
  - (4) 用户有游戏截图想制作成宣传视频
  - (5) 用户说"promo video""trailer""gameplay video""短视频"
  - (6) 用户需要为 TapTap 发布准备游戏演示视频
  - (7) 用户说"一键生成宣传片""批量生成视频""视频工厂"
  - (8) 用户需要给游戏视频配旁白/解说/字幕

SKIP when:
  - 游戏内过场动画配音（使用 cinematic-dub-pipeline）
  - 纯文字发布材料（使用 game-content-factory）
  - 游戏图标/截图/宣传图等静态素材（使用 generate_game_material）
  - 游戏内视频播放功能（使用 VideoPlayer/VideoScreen3D）
  - 纯音乐/BGM 生成（使用 text_to_music）

trigger-keywords:
  - 宣传视频
  - 预告片
  - Trailer
  - Gameplay Demo
  - 游戏短视频
  - promo video
  - 视频生成
  - 批量视频
  - 游戏宣传
  - 视频工厂
  - 一键生成视频
  - demo video
  - 视频混剪
  - 游戏录像
---

# Game Promo Video Forge — 游戏宣传短视频自动化锻造管线

> 灵感来源：[MoneyPrinterPlus](https://github.com/ddean2009/MoneyPrinterPlus)
> —— AI 短视频批量生成工具
>
> 将"关键词→文案→配音→素材→合成→发布"管线适配为游戏宣传视频生产系统。

---

## 目录

1. [概念映射](#1-概念映射)
2. [管线总览](#2-管线总览)
3. [Phase 1：游戏分析与脚本生成](#3-phase-1游戏分析与脚本生成)
4. [Phase 2：素材采集与准备](#4-phase-2素材采集与准备)
5. [Phase 3：配音与 BGM 生成](#5-phase-3配音与-bgm-生成)
6. [Phase 4：视频合成](#6-phase-4视频合成)
7. [Phase 5：字幕与文案叠加](#7-phase-5字幕与文案叠加)
8. [Phase 6：多版本输出](#8-phase-6多版本输出)
9. [Phase 7：物料上传与发布](#9-phase-7物料上传与发布)
10. [批量生产模式](#10-批量生产模式)
11. [脚本数据格式](#11-脚本数据格式)
12. [Lua 集成模块](#12-lua-集成模块)
13. [完整工作流示例](#13-完整工作流示例)
14. [引擎规则合规](#14-引擎规则合规)
15. [FAQ](#15-faq)
16. [参考文档](#16-参考文档)

---

## 1. 概念映射

### MoneyPrinterPlus → UrhoX 游戏宣传视频

| MoneyPrinterPlus 概念 | UrhoX 适配方案 | 使用的 MCP 工具 |
|----------------------|---------------|----------------|
| 关键词输入 | 游戏代码分析 + 用户描述 | AI 分析 `scripts/` 源码 |
| LLM 生成文案 | AI 生成宣传脚本（分镜+旁白） | Claude 直接生成 |
| Pexels/Pixabay 素材库 | 游戏截图 + AI 生成图片 | `generate_image` / `batch_generate_images` |
| 语音合成（Azure/阿里云） | 旁白配音 | `text_to_dialogue` / `audition_voices_for_character` |
| 背景音乐 | BGM 生成 | `text_to_music` |
| FFmpeg 视频合成 | AI 视频生成 | `create_video_task` / `query_video_task` |
| 字幕叠加 | 视频提示词内嵌文案 | `create_video_task` prompt |
| 30+ 转场特效 | AI 视频自然过渡 | `create_video_task` multi_modal_reference |
| 批量混剪 | 多版本视频批量生成 | 循环调用 `create_video_task` |
| 自动发布 | 物料上传 TapTap | `upload_game_material` / `publish_to_taptap` |

### 设计原则

| 原则 | 说明 |
|------|------|
| **构建时生产** | 视频在开发/发布阶段生成，不在游戏运行时 |
| **MCP 工具驱动** | 所有 AI 能力通过引擎内置 MCP 工具调用 |
| **数据持久化** | 脚本/配置保存为 JSON，支持反复调整 |
| **可追溯** | 每一步中间产物都有明确路径和格式 |
| **批量化** | 支持一次生产多个版本的宣传视频 |

---

## 2. 管线总览

```
┌─────────────────────────────────────────────────────────────┐
│                 Game Promo Video Forge                       │
│                                                             │
│  Phase 1        Phase 2        Phase 3        Phase 4       │
│  ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐       │
│  │ 游戏 │ ──→  │ 素材 │ ──→  │ 配音 │ ──→  │ 视频 │       │
│  │ 分析 │      │ 采集 │      │ BGM  │      │ 合成 │       │
│  └──────┘      └──────┘      └──────┘      └──────┘       │
│      │              │             │             │           │
│      ▼              ▼             ▼             ▼           │
│  宣传脚本       截图序列       配音文件      视频片段       │
│  (JSON)        (PNG/JPG)     (OGG/WAV)     (MP4)          │
│                                                             │
│  Phase 5        Phase 6        Phase 7                      │
│  ┌──────┐      ┌──────┐      ┌──────┐                     │
│  │ 字幕 │ ──→  │ 多版 │ ──→  │ 上传 │                     │
│  │ 叠加 │      │ 本   │      │ 发布 │                     │
│  └──────┘      └──────┘      └──────┘                     │
│      │              │             │                         │
│      ▼              ▼             ▼                         │
│  带字幕视频     横屏/竖屏     TapTap 物料                  │
│  (MP4)         多尺寸版本    project.json                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Phase 1：游戏分析与脚本生成

### 3.1 游戏分析

AI 分析 `scripts/` 目录的游戏代码，提取核心信息：

```
分析维度：
├── 游戏类型（RPG/射击/平台跳跃/策略/休闲）
├── 核心玩法（战斗/建造/解谜/竞速）
├── 视觉风格（3D PBR/2D 像素/NanoVG 矢量/卡通）
├── 关键特性（多人/AI NPC/物理引擎/开放世界）
└── 目标受众（硬核/休闲/全年龄）
```

### 3.2 宣传脚本格式

AI 生成的宣传脚本以 JSON 格式保存到 `scripts/data/promo/` 目录：

```json
{
  "$schema": "promo-script-v1",
  "id": "promo_trailer_main",
  "title": "游戏名称 — 官方预告片",
  "version": "1.0",
  "target_duration": 30,
  "orientation": "landscape",
  "style": "epic",
  "scenes": [
    {
      "scene_id": "s01_opening",
      "duration": 5,
      "type": "title_card",
      "visual": {
        "description": "黑幕渐入，游戏 Logo 从粒子中凝聚而成",
        "source": "generated",
        "prompt": "游戏Logo在黑暗中以金色粒子凝聚成型，史诗感，电影级光影"
      },
      "narration": {
        "text": "",
        "emotion": "none"
      },
      "text_overlay": {
        "content": "一个被遗忘的世界，等待你的探索",
        "position": "center",
        "style": "fade_in"
      },
      "bgm_mood": "suspense_building",
      "transition_to_next": "dissolve"
    },
    {
      "scene_id": "s02_gameplay_1",
      "duration": 6,
      "type": "gameplay",
      "visual": {
        "description": "展示角色在开阔地图中奔跑，视角跟随",
        "source": "screenshot",
        "screenshot_index": 0
      },
      "narration": {
        "text": "踏入无尽的荒原，每一步都充满未知",
        "emotion": "mysterious"
      },
      "text_overlay": {
        "content": "",
        "position": "bottom",
        "style": "none"
      },
      "bgm_mood": "adventure_rising",
      "transition_to_next": "swipe_left"
    },
    {
      "scene_id": "s03_gameplay_2",
      "duration": 6,
      "type": "gameplay",
      "visual": {
        "description": "激烈的战斗场景，特效绚丽",
        "source": "screenshot",
        "screenshot_index": 1
      },
      "narration": {
        "text": "面对强敌，用你的智慧和勇气战胜一切",
        "emotion": "excited"
      },
      "text_overlay": {
        "content": "实时战斗系统",
        "position": "top_right",
        "style": "slide_in"
      },
      "bgm_mood": "battle_climax",
      "transition_to_next": "zoom_in"
    },
    {
      "scene_id": "s04_features",
      "duration": 6,
      "type": "feature_showcase",
      "visual": {
        "description": "快速切换多个游戏特性画面",
        "source": "montage",
        "screenshot_indices": [2, 3, 4]
      },
      "narration": {
        "text": "丰富的装备系统，自由的角色养成，无限的可能",
        "emotion": "enthusiastic"
      },
      "text_overlay": {
        "content": "",
        "position": "bottom",
        "style": "none"
      },
      "bgm_mood": "upbeat_energy",
      "transition_to_next": "flash"
    },
    {
      "scene_id": "s05_ending",
      "duration": 7,
      "type": "call_to_action",
      "visual": {
        "description": "游戏 Logo + 下载二维码 + 平台标志",
        "source": "generated",
        "prompt": "游戏Logo居中，底部TapTap标志，深色背景，简洁大气"
      },
      "narration": {
        "text": "现在就加入，开启你的冒险之旅",
        "emotion": "warm"
      },
      "text_overlay": {
        "content": "立即下载",
        "position": "bottom_center",
        "style": "pulse"
      },
      "bgm_mood": "triumphant_ending",
      "transition_to_next": "fade_out"
    }
  ],
  "bgm": {
    "style": "orchestral, cinematic, epic, game trailer",
    "tempo": "builds from slow to fast, climax at 70%, gentle ending"
  },
  "narrator": {
    "voice_type": "male_deep_confident",
    "language": "cmn",
    "six_dimension_prompt": "Young adult male in his late 20s, deep and magnetic voice, confident and authoritative tone, measured pacing with dramatic pauses, cinematic trailer style narration, studio-quality recording."
  }
}
```

### 3.3 脚本风格模板

| 风格 | 时长 | 适用 | 典型结构 |
|------|------|------|---------|
| `epic` | 30-60s | RPG/动作/开放世界 | 黑幕开场→世界观→战斗→特性→CTA |
| `fast_cut` | 15-30s | 休闲/竞技/跑酷 | 快节奏画面切换→核心玩法→CTA |
| `story` | 30-60s | 剧情/冒险/视觉小说 | 角色独白→情节预告→悬念→CTA |
| `gameplay` | 15-45s | 全类型 | 纯游戏画面+字幕说明→CTA |
| `teaser` | 10-15s | 首曝/预热 | Logo→一个画面→日期→CTA |
| `update` | 15-30s | 版本更新 | 新内容列表→展示→下载 |

### 3.4 脚本生成指令

AI 生成脚本时的标准指令：

```
根据以下游戏信息生成宣传视频脚本（promo-script-v1 JSON 格式）：

游戏名称：{GAME_NAME}
游戏类型：{GAME_GENRE}
核心玩法：{CORE_GAMEPLAY}
视觉风格：{VISUAL_STYLE}
可用截图数量：{SCREENSHOT_COUNT}
目标时长：{TARGET_DURATION}秒
视频风格：{VIDEO_STYLE}
目标平台：TapTap
屏幕方向：{ORIENTATION}（landscape/portrait）

要求：
1. scenes 数量根据时长自动调整（每场景 4-8 秒）
2. 旁白文案简洁有力，每句不超过 20 字
3. visual.prompt 使用中文，描述要生动具体
4. 第一个场景必须是 title_card 或强视觉冲击
5. 最后一个场景必须是 call_to_action
6. bgm_mood 在场景间有变化和递进
7. 如果有截图，优先使用截图（source: screenshot）
8. 没有截图的场景使用 AI 生成（source: generated）
```

---

## 4. Phase 2：素材采集与准备

### 4.1 截图采集

游戏截图是宣传视频的核心素材。获取方式：

**方式 A：用户手动截图（推荐）**

用户在游戏预览窗口使用"截图插入对话"功能，获取真实游戏画面。

**方式 B：现有截图复用**

从 `game_material/` 目录读取已有截图：

```lua
-- 扫描已有截图
local screenshots = {}
local materialDir = "game_material"
-- 读取 .project/project.json 中的 assets.screenshots
```

### 4.2 AI 图片生成

对于缺少截图的场景（Logo、概念图等），使用 `generate_image` 生成：

```
-- 调用 MCP generate_image
工具：generate_image
参数：
  prompt: "{scene.visual.prompt}"
  name: "{scene.scene_id}"
  target_size: "1344x768"       -- 横屏 16:9
  aspect_ratio: "16:9"
```

竖屏视频使用 `9:16` 比例：

```
  target_size: "768x1344"
  aspect_ratio: "9:16"
```

### 4.3 素材清单生成

AI 汇总每个场景的素材来源，生成素材清单：

```json
{
  "asset_manifest": [
    {
      "scene_id": "s01_opening",
      "type": "generated",
      "status": "pending",
      "path": null
    },
    {
      "scene_id": "s02_gameplay_1",
      "type": "screenshot",
      "status": "ready",
      "path": "game_material/screenshot_01.png"
    }
  ]
}
```

### 4.4 角色形象资产上传

如果视频中包含游戏角色形象，需要先上传到素材库避免深度伪造检测：

```
-- 调用 MCP upload_asset
工具：upload_asset
参数：
  image: "game_material/character_front.png"
  name: "游戏主角正面"

-- 返回 asset_uri（如 "asset://asset-xxx"）
-- 后续在 create_video_task 中使用此 URI
```

---

## 5. Phase 3：配音与 BGM 生成

### 5.1 旁白配音流程

**Step 1：创建旁白角色声音**

```
-- 调用 MCP audition_voices_for_character
工具：audition_voices_for_character
参数：
  character_name: "narrator"
  character_description: "{script.narrator.six_dimension_prompt}"
  audition_line: "{将所有 narration.text 拼接为试音台词，至少 100 字}"
```

**Step 2：确认声音选择**

```
-- 用户选择后调用
工具：confirm_character_voice
参数：
  character_name: "narrator"
  selected_index: {用户选择的编号}
```

**Step 3：批量生成旁白**

```
-- 调用 MCP text_to_dialogue
工具：text_to_dialogue
参数：
  inputs: [
    {
      "character_name": "narrator",
      "text": "{scene.narration.text，加入情感标签}"
    }
    -- 每个有旁白的场景一条
  ]
  language_code: "cmn"
  stability: 0.6
  output_name: "promo_narration"
```

### 5.2 旁白情感标签映射

根据脚本中的 `narration.emotion` 字段映射 ElevenLabs 情感标签：

| emotion 值 | 对应标签 | 示例 |
|------------|---------|------|
| `mysterious` | `[softly]` `[whispering]` | `[softly] 踏入无尽的荒原...` |
| `excited` | `[excited]` `[enthusiastic]` | `[excited] 面对强敌！` |
| `warm` | `[softly]` | `[softly] 现在就加入...` |
| `dramatic` | `[pause]` + 强调 | `[pause] 命运... 由你书写` |
| `humorous` | `[chuckling]` | `[chuckling] 谁说勇者不能搞笑？` |
| `epic` | `[shouting]` | `[shouting] 为了荣耀！` |
| `none` | （无标签） | 纯文本 |

### 5.3 BGM 生成

```
-- 调用 MCP text_to_music
工具：text_to_music
参数：
  prompt: "Game trailer background music. {script.bgm.style}. {script.bgm.tempo}."
  customMode: true
  style: "{script.bgm.style}"
  title: "{script.title} BGM"
  instrumental: true
  model: "V4_5"
```

### 5.4 音效生成（可选）

为转场、Logo 出现等添加音效：

```
-- 调用 MCP text_to_sound_effect
工具：text_to_sound_effect
参数：
  text: "Epic cinematic logo reveal sound, deep bass impact with shimmering high end"
  duration_seconds: 3
  output_name: "logo_reveal_sfx"
```

常用音效清单：

| 场景 | 英文描述 | 时长 |
|------|---------|------|
| Logo 出现 | `cinematic logo reveal, deep bass impact` | 2-3s |
| 转场 Whoosh | `fast whoosh transition sound effect` | 0.5-1s |
| 文字弹出 | `UI text pop up notification, bright click` | 0.3-0.5s |
| 战斗高潮 | `epic battle climax orchestral hit` | 1-2s |
| 结尾定格 | `cinematic ending impact, reverb tail` | 2-3s |

---

## 6. Phase 4：视频合成

### 6.1 单场景视频生成

每个场景单独生成一个视频片段：

**方式 A：从首帧图片生成**

```
-- 调用 MCP create_video_task
工具：create_video_task
参数：
  mode: "first_frame"
  prompt: "{scene.visual.description}，电影级运镜，{transition_hint}"
  images: [
    { "url": "{scene_image_path}" }
  ]
  duration: {scene.duration}
  ratio: "16:9"
  resolution: "720p"
  generate_audio: false
```

**方式 B：纯文本生成（无截图时）**

```
工具：create_video_task
参数：
  mode: "text_to_video"
  prompt: "{scene.visual.prompt}，游戏宣传片风格，电影级画面"
  duration: {scene.duration}
  ratio: "16:9"
  resolution: "720p"
  generate_audio: false
```

**方式 C：首尾帧控制（精确转场）**

```
工具：create_video_task
参数：
  mode: "first_last_frame"
  prompt: "从场景A流畅过渡到场景B，电影级运镜"
  images: [
    { "url": "{current_scene_image}" },
    { "url": "{next_scene_image}" }
  ]
  duration: {scene.duration}
  ratio: "16:9"
```

### 6.2 查询视频任务

```
-- 至少等 120 秒后查询
工具：query_video_task
参数：
  task_id: "{返回的 task_id}"
```

### 6.3 场景间转场策略

将 MoneyPrinterPlus 的转场特效映射为 Seedance 视频生成提示词：

| 脚本转场 | 视频 prompt 提示 |
|---------|-----------------|
| `dissolve` | "画面缓慢溶解过渡到下一个场景" |
| `fade_out` | "画面逐渐变暗淡出至黑色" |
| `swipe_left` | "画面向左推移切换" |
| `zoom_in` | "镜头快速推进，画面放大" |
| `flash` | "白色闪光后切换到新画面" |
| `glitch` | "数码故障效果闪烁后切换" |
| `slide_up` | "画面从下向上滑入新场景" |
| `none` | "直接切换，无过渡" |

### 6.4 使用 multi_modal_reference 模式

当需要保持角色/风格一致性时，使用多模态参考：

```
工具：create_video_task
参数：
  mode: "multi_modal_reference"
  prompt: "{场景描述}，保持角色形象和画面风格一致"
  images: [
    { "url": "asset://{asset_id}", "role": "reference_image" },
    { "url": "{scene_screenshot}", "role": "reference_image" }
  ]
  duration: {scene.duration}
  ratio: "16:9"
```

---

## 7. Phase 5：字幕与文案叠加

### 7.1 视频内嵌文案

Seedance 视频生成时，可通过 prompt 描述文案位置：

```
prompt 追加：
"画面底部居中显示白色字幕文字：'{text_overlay.content}'，
 字体清晰，有半透明黑色背景条"
```

### 7.2 字幕时间轴数据

为后期处理保留字幕时间轴（JSON 格式）：

```json
{
  "$schema": "subtitle-timeline-v1",
  "video_id": "promo_trailer_main",
  "language": "zh-CN",
  "entries": [
    {
      "start": 0.0,
      "end": 5.0,
      "text": "一个被遗忘的世界，等待你的探索",
      "style": "title",
      "position": "center"
    },
    {
      "start": 5.0,
      "end": 11.0,
      "text": "踏入无尽的荒原，每一步都充满未知",
      "style": "narration",
      "position": "bottom"
    }
  ]
}
```

### 7.3 多语言字幕

利用引擎 i18n 框架生成多语言字幕版本：

```
-- 调用 MCP i18n_extract
工具：i18n_extract
参数：
  scriptsPath: "scripts"
```

字幕文本标记为可翻译：

```lua
-- scripts/data/promo/subtitles.lua
local M = {}

M.entries = {
    { start = 0.0, fin = 5.0,  text = _("一个被遗忘的世界，等待你的探索") },
    { start = 5.0, fin = 11.0, text = _("踏入无尽的荒原，每一步都充满未知") },
}

return M
```

---

## 8. Phase 6：多版本输出

### 8.1 版本矩阵

一份脚本可生成多个版本的视频：

| 版本 | 比例 | 尺寸 | 用途 |
|------|------|------|------|
| 横屏完整版 | 16:9 | 1344×768 | TapTap 页面、B站 |
| 竖屏版 | 9:16 | 768×1344 | 抖音、小红书 |
| 方形版 | 1:1 | 1024×1024 | 朋友圈、微博 |
| 横屏短版 | 16:9 | 1344×768 | 15s 精华版 |

### 8.2 竖屏版适配

横屏素材转竖屏时的处理策略：

```
1. 重新生成竖屏比例的场景图片（aspect_ratio: "9:16"）
2. 调整 text_overlay 位置适配竖屏布局
3. 旁白/BGM 复用（音频不需要重新生成）
4. 重新生成视频片段（ratio: "9:16"）
```

### 8.3 短版本裁剪

从完整脚本提取关键场景生成短版本：

```json
{
  "short_version": {
    "source_script": "promo_trailer_main",
    "target_duration": 15,
    "selected_scenes": ["s01_opening", "s03_gameplay_2", "s05_ending"],
    "speed_multiplier": 1.2
  }
}
```

---

## 9. Phase 7：物料上传与发布

### 9.1 Gameplay Demo 视频上传

将最终视频设置为游戏演示视频：

**Step 1：更新 project.json**

```json
{
  "taptap_publish": {
    "gameplay_demo_video_source": "./game_material/promo_trailer.mp4"
  }
}
```

**Step 2：上传宣传图**

```
-- 如果视频中的某一帧适合作为宣传图
工具：upload_game_material
参数：
  type: "PROMO"
  file_path: "game_material/promo_keyframe.png"
```

### 9.2 方形封面生成

为竖屏游戏视频生成方形封面：

```
工具：generate_game_material
参数：
  game_name: "{游戏名称}"
  material_type: "SQUARE_PROMO"
  images: ["game_material/screenshot_best.png"]
```

### 9.3 发布检查清单

上传前验证：

```
□ 视频文件存在且可播放
□ 视频时长在 10-60s 范围内
□ project.json 中 gameplay_demo_video_source 已设置
□ 宣传图已上传（PROMO 类型）
□ 至少 3 张截图已上传
□ 游戏图标已上传
□ 构建已完成（调用 build 工具）
```

---

## 10. 批量生产模式

### 10.1 批量脚本矩阵

类似 MoneyPrinterPlus 的批量混剪，一次生成多个版本：

```json
{
  "batch_config": {
    "base_script": "promo_trailer_main",
    "variants": [
      {
        "variant_id": "v1_epic",
        "style": "epic",
        "target_duration": 30,
        "orientation": "landscape",
        "bgm_style": "orchestral, cinematic, epic"
      },
      {
        "variant_id": "v2_fast",
        "style": "fast_cut",
        "target_duration": 15,
        "orientation": "portrait",
        "bgm_style": "electronic, upbeat, energetic"
      },
      {
        "variant_id": "v3_story",
        "style": "story",
        "target_duration": 45,
        "orientation": "landscape",
        "bgm_style": "piano, emotional, cinematic"
      }
    ]
  }
}
```

### 10.2 批量执行流程

```
1. 加载 batch_config
2. 对每个 variant：
   a. 根据 style 模板调整脚本结构
   b. 生成/复用素材（相同截图可跨版本复用）
   c. 生成 BGM（不同风格需要重新生成）
   d. 生成视频片段（不同比例需要重新生成）
   e. 保存产物到 game_material/promo/{variant_id}/
3. 汇总生成报告
```

### 10.3 素材复用策略

| 素材类型 | 跨版本复用 | 说明 |
|---------|-----------|------|
| 游戏截图 | ✅ 可复用 | 同一截图裁剪为不同比例 |
| AI 生成图 | ❌ 需重新生成 | 不同比例需要重新生成 |
| 旁白配音 | ✅ 可复用 | 同一文案的配音通用 |
| BGM | ❌ 需重新生成 | 不同风格需要不同 BGM |
| 视频片段 | ❌ 需重新生成 | 不同比例/时长需要重新生成 |
| 音效 | ✅ 可复用 | 转场/Logo 音效通用 |

---

## 11. 脚本数据格式

### 11.1 Lua 数据表转换

JSON 脚本转换为 Lua 数据表，方便游戏内引用（如"关于"页面播放预告片）：

```lua
-- scripts/data/promo/trailer_main.lua
-- 由 game-promo-video-forge 生成

local M = {}

M.id = "promo_trailer_main"
M.title = "冒险之旅 — 官方预告片"
M.version = "1.0"
M.target_duration = 30
M.orientation = "landscape"
M.style = "epic"

M.scenes = {
    {
        scene_id = "s01_opening",
        duration = 5,
        type = "title_card",
        visual = {
            description = "黑幕渐入，游戏Logo从粒子中凝聚而成",
            source = "generated",
        },
        narration = { text = "", emotion = "none" },
        text_overlay = {
            content = "一个被遗忘的世界，等待你的探索",
            position = "center",
        },
        bgm_mood = "suspense_building",
    },
    -- ... 更多场景
}

M.bgm = {
    style = "orchestral, cinematic, epic, game trailer",
    tempo = "builds from slow to fast, climax at 70%, gentle ending",
}

M.narrator = {
    voice_type = "male_deep_confident",
    language = "cmn",
}

return M
```

### 11.2 状态持久化

视频生成的进度和中间产物路径保存为 JSON：

```json
{
  "$schema": "promo-state-v1",
  "script_id": "promo_trailer_main",
  "status": "in_progress",
  "completed_phases": ["script", "assets", "narration", "bgm"],
  "current_phase": "video_synthesis",
  "assets": {
    "screenshots": [
      "game_material/screenshot_01.png",
      "game_material/screenshot_02.png"
    ],
    "generated_images": [
      "game_material/promo/s01_opening.png",
      "game_material/promo/s05_ending.png"
    ],
    "narration_audio": "assets/Sounds/promo_narration.ogg",
    "bgm_audio": "assets/Music/promo_bgm.ogg",
    "sfx": [
      "assets/Sounds/logo_reveal_sfx.ogg",
      "assets/Sounds/transition_whoosh.ogg"
    ]
  },
  "video_tasks": [
    {
      "scene_id": "s01_opening",
      "task_id": "task_abc123",
      "status": "success",
      "video_path": "game_material/promo/clips/s01_opening.mp4"
    },
    {
      "scene_id": "s02_gameplay_1",
      "task_id": "task_def456",
      "status": "running",
      "video_path": null
    }
  ],
  "final_video": null,
  "updated_at": "2026-05-15T12:00:00Z"
}
```

---

## 12. Lua 集成模块

### 12.1 PromoVideoPlayer — 游戏内预告片播放

在游戏中播放生成的宣传视频（如"关于"页面、首次启动）：

```lua
-- scripts/systems/PromoVideoPlayer.lua

local UI = require("urhox-libs/UI")

local PromoVideoPlayer = {}

--- 创建预告片播放面板
---@param videoUrl string 视频 URL 或本地路径
---@param options table|nil 可选配置
---@return table panel UI 面板
function PromoVideoPlayer.CreatePanel(videoUrl, options)
    options = options or {}
    local width = options.width or "100%"
    local height = options.height or "100%"

    local panel = UI.Panel {
        width = width,
        height = height,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = "#000000",
        children = {
            UI.Video {
                src = videoUrl,
                width = "100%",
                height = "100%",
                autoPlay = options.autoPlay ~= false,
                loop = options.loop or false,
                controls = options.controls ~= false,
            },
        },
    }

    return panel
end

--- 创建带关闭按钮的全屏播放器
---@param videoUrl string
---@param onClose function 关闭回调
---@return table overlay
function PromoVideoPlayer.CreateFullscreen(videoUrl, onClose)
    local overlay = UI.Panel {
        position = "absolute",
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = "rgba(0,0,0,0.9)",
        children = {
            UI.Video {
                src = videoUrl,
                width = "90%",
                height = "80%",
                autoPlay = true,
                controls = true,
            },
            UI.Button {
                text = "关闭",
                position = "absolute",
                top = 20,
                right = 20,
                variant = "ghost",
                textColor = "#FFFFFF",
                onClick = function()
                    if onClose then onClose() end
                end,
            },
        },
    }

    return overlay
end

return PromoVideoPlayer
```

### 12.2 PromoScriptLoader — 脚本加载器

```lua
-- scripts/systems/PromoScriptLoader.lua

local cjson = require("cjson")

local PromoScriptLoader = {}

--- 从 Lua data table 加载脚本
---@param path string require 路径
---@return table script 脚本数据
function PromoScriptLoader.LoadLua(path)
    local ok, data = pcall(require, path)
    if not ok then
        log:Error("PromoScriptLoader: Failed to load " .. path)
        return nil
    end
    return data
end

--- 从 JSON 文件加载脚本
---@param filePath string 文件路径
---@return table|nil script 脚本数据
function PromoScriptLoader.LoadJSON(filePath)
    local file = File:new(filePath, FILE_READ)
    if file == nil then
        log:Error("PromoScriptLoader: File not found: " .. filePath)
        return nil
    end
    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then
        log:Error("PromoScriptLoader: JSON parse error: " .. tostring(data))
        return nil
    end
    return data
end

--- 验证脚本完整性
---@param script table
---@return boolean valid
---@return string[] errors
function PromoScriptLoader.Validate(script)
    local errors = {}

    if not script.id then
        table.insert(errors, "Missing 'id' field")
    end
    if not script.scenes or #script.scenes == 0 then
        table.insert(errors, "Missing or empty 'scenes' array")
    end
    if script.scenes then
        for i, scene in ipairs(script.scenes) do
            if not scene.scene_id then
                table.insert(errors, "Scene " .. i .. ": missing 'scene_id'")
            end
            if not scene.duration or scene.duration <= 0 then
                table.insert(errors, "Scene " .. i .. ": invalid 'duration'")
            end
            if not scene.visual then
                table.insert(errors, "Scene " .. i .. ": missing 'visual'")
            end
        end
    end
    if not script.bgm then
        table.insert(errors, "Missing 'bgm' configuration")
    end

    return #errors == 0, errors
end

--- 计算总时长
---@param script table
---@return number totalDuration
function PromoScriptLoader.GetTotalDuration(script)
    local total = 0
    if script.scenes then
        for _, scene in ipairs(script.scenes) do
            total = total + (scene.duration or 0)
        end
    end
    return total
end

--- 提取所有旁白文本
---@param script table
---@return table[] narrations {scene_id, text, emotion}
function PromoScriptLoader.ExtractNarrations(script)
    local narrations = {}
    if script.scenes then
        for _, scene in ipairs(script.scenes) do
            if scene.narration and scene.narration.text
                and scene.narration.text ~= "" then
                table.insert(narrations, {
                    scene_id = scene.scene_id,
                    text = scene.narration.text,
                    emotion = scene.narration.emotion or "none",
                })
            end
        end
    end
    return narrations
end

--- 提取截图引用
---@param script table
---@return number[] indices 截图索引列表（1-based）
function PromoScriptLoader.ExtractScreenshotIndices(script)
    local indices = {}
    local seen = {}
    if script.scenes then
        for _, scene in ipairs(script.scenes) do
            if scene.visual and scene.visual.source == "screenshot" then
                local idx = (scene.visual.screenshot_index or 0) + 1
                if not seen[idx] then
                    table.insert(indices, idx)
                    seen[idx] = true
                end
            end
            if scene.visual and scene.visual.source == "montage"
                and scene.visual.screenshot_indices then
                for _, rawIdx in ipairs(scene.visual.screenshot_indices) do
                    local idx = rawIdx + 1
                    if not seen[idx] then
                        table.insert(indices, idx)
                        seen[idx] = true
                    end
                end
            end
        end
    end
    table.sort(indices)
    return indices
end

return PromoScriptLoader
```

---

## 13. 完整工作流示例

### 13.1 端到端示例：为 RPG 游戏生成宣传预告片

以下展示完整的 7 阶段工作流：

**前提条件**：
- 游戏代码已在 `scripts/` 目录
- 用户已截取至少 3 张游戏截图
- 项目已构建成功

**Step 1 — 游戏分析与脚本生成**

AI 分析 `scripts/` 代码，识别出：
- 游戏类型：3D RPG
- 核心玩法：探索、战斗、装备系统
- 视觉风格：3D PBR + 卡通渲染

AI 生成 promo-script-v1 JSON 脚本（5 个场景，总时长 30s，epic 风格）。

保存到 `scripts/data/promo/trailer_main.lua`。

**Step 2 — 素材采集**

```
场景 1 (title_card)：AI 生成 Logo 图 → generate_image
场景 2 (gameplay)：使用截图 #1
场景 3 (gameplay)：使用截图 #2
场景 4 (feature_showcase)：使用截图 #3 + AI 生成补充图
场景 5 (call_to_action)：AI 生成结尾图 → generate_image
```

**Step 3 — 配音与 BGM**

```
1. audition_voices_for_character → 创建旁白声音（3 个候选）
2. confirm_character_voice → 用户确认
3. text_to_dialogue → 批量生成 3 段旁白
4. text_to_music → 生成史诗风 BGM
5. text_to_sound_effect → 生成 Logo 音效
```

**Step 4 — 视频合成**

```
每个场景调用 create_video_task：
- s01：first_frame 模式（Logo 图 → 粒子凝聚动画）
- s02：first_frame 模式（截图 #1 → 角色奔跑动画）
- s03：first_frame 模式（截图 #2 → 战斗动画）
- s04：multi_modal_reference（多截图参考 → 特性蒙太奇）
- s05：first_frame 模式（结尾图 → Logo 定格）

每个任务间隔至少 120s 查询状态。
```

**Step 5 — 字幕**

视频 prompt 中嵌入字幕文案。
保存字幕时间轴 JSON 供后续使用。

**Step 6 — 多版本**

```
已生成：横屏 30s 完整版
追加生成：
- 竖屏 30s 版（9:16 重新生成视频片段）
- 横屏 15s 短版（选取 s01 + s03 + s05）
```

**Step 7 — 上传发布**

```
1. 保存视频到 game_material/promo_trailer.mp4
2. 更新 project.json 中 gameplay_demo_video_source
3. upload_game_material → 上传宣传图
4. 调用 build 工具确保构建包含新资源
5. publish_to_taptap → 发布到 TapTap
```

---

## 14. 引擎规则合规

| 规则 | 本 Skill 遵守方式 |
|------|------------------|
| 代码放 scripts/ | ✅ 所有 Lua 模块和数据文件放在 `scripts/` |
| 不写入 dist 目录 | ✅ 产出写入 `game_material/` 和 `scripts/data/` |
| 使用 MCP 工具 | ✅ 全部 AI 能力通过 MCP 工具调用 |
| 构建后预览 | ✅ 每次代码变更后调用 build 工具 |
| JSON 持久化 | ✅ 脚本/状态/字幕全部 JSON 格式保存 |
| 资源路径规范 | ✅ 使用相对路径引用资源 |
| Lua 数组从 1 | ✅ 截图索引 +1 转换为 Lua 1-based |
| UI 使用新系统 | ✅ PromoVideoPlayer 使用 `urhox-libs/UI` |
| 不使用 Lua 原生文件库 | ✅ 文件操作使用 `File` 类 |
| 枚举不猜数字 | ✅ 使用 `FILE_READ` 等枚举常量 |

---

## 15. FAQ

### Q1：MoneyPrinterPlus 支持 30+ 转场特效，这里怎么实现？

Seedance 视频生成不支持传统的 FFmpeg 转场滤镜。替代方案：
1. **first_last_frame 模式**：提供当前场景末帧和下一场景首帧，让 AI 自动生成过渡
2. **prompt 描述**：在 prompt 中描述转场效果（"画面溶解过渡""镜头快速推进"）
3. **return_last_frame**：设为 true 获取尾帧，用作下一段的首帧，实现连续过渡

### Q2：视频片段如何拼接成完整视频？

当前方案：
1. 使用 `first_last_frame` 模式让场景自然过渡
2. 或生成一个长视频（将所有场景描述合并为一个 prompt）
3. 最终视频通过 `gameplay_demo_video_source` 直接引用

后续如果引擎支持视频拼接，可以直接使用。

### Q3：旁白和 BGM 如何与视频同步？

1. 旁白时长由 TTS 自动生成，控制文案长度来匹配场景时长
2. BGM 作为完整背景音，不需要精确同步
3. Seedance 的 `generate_audio: true` 可以生成与视频匹配的音频
4. 也可通过 `reference_audio` 让视频生成时参考 BGM 节奏

### Q4：批量生成视频的并发限制？

Seedance API 有并发限制。建议：
1. 同时提交不超过 3 个视频任务
2. 每个任务至少等 120s 再查询
3. 使用状态文件（promo-state-v1）跟踪每个任务的进度
4. 失败的任务可以单独重试

### Q5：竖屏视频和横屏视频需要不同的素材吗？

是的。关键区别：
- 图片比例不同（16:9 vs 9:16），需要重新生成 AI 图或裁剪截图
- 文案位置不同（竖屏文案通常在底部 1/3）
- 视频 ratio 参数不同
- 旁白和 BGM 可以复用

### Q6：生成的视频有水印吗？

取决于 Seedance API 的当前策略。生成后应检查视频质量。

### Q7：可以用游戏内录屏代替截图吗？

可以。如果有游戏录屏视频文件，可以：
1. 作为 `reference_video` 传入 `create_video_task`
2. 直接作为宣传视频的素材片段
3. 视频文件放在 `game_material/` 目录

---

## 16. 参考文档

- `references/moneyprinter-mapping.md` — MoneyPrinterPlus 功能到 UrhoX 的完整映射表
- `references/video-production-recipes.md` — 各类游戏的视频制作配方（RPG/休闲/射击等）
- `references/prompt-engineering-guide.md` — Seedance 视频生成的 prompt 优化指南
