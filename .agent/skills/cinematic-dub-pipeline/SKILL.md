---
name: cinematic-dub-pipeline
version: "1.0.0"
description: |
  游戏过场动画多语言配音管线——将 Linly-Dubbing 的 AI 视频翻译配音工作流
  映射为 UrhoX Lua 游戏引擎可用的端到端过场配音系统。
  覆盖：剧本管理 → 多角色语音合成 → 字幕时间轴 → 视频/3D 过场集成 → 多语言切换。
  Use when users need to
  (1) 为游戏过场动画/CG 添加多语言配音,
  (2) 实现对话系统的语音合成管线,
  (3) 创建带字幕时间轴的过场动画系统,
  (4) 批量生成多角色多语言的对话语音,
  (5) 为已有视频过场添加本地化配音和字幕,
  (6) 构建"剧本 → 语音 → 字幕 → 播放"的完整流水线。
author: "UrhoX Skill Builder"
source: "https://github.com/Kedreamix/Linly-Dubbing"
tags:
  - dubbing
  - voice
  - cutscene
  - subtitle
  - localization
  - tts
  - dialogue
  - cinematic
  - video
  - i18n
triggers:
  - 过场配音
  - 配音管线
  - 多语言配音
  - 过场动画语音
  - cutscene dubbing
  - cinematic voice
  - dialogue pipeline
  - 视频配音
  - 字幕时间轴
  - 语音合成管线
  - 本地化配音
  - dub pipeline
  - 对话系统语音
  - voice pipeline
---

# Cinematic Dub Pipeline — 游戏过场动画多语言配音管线

> **灵感来源**: [Kedreamix/Linly-Dubbing](https://github.com/Kedreamix/Linly-Dubbing)
>
> 将 Linly-Dubbing 的 AI 视频翻译配音工作流（ASR → 翻译 → TTS → 唇形同步 → 合成）
> 映射为 UrhoX Lua 游戏引擎的过场动画配音系统，利用引擎已有的
> ElevenLabs TTS、视频播放、UI 字幕组件和 i18n 框架，实现端到端的多语言配音管线。

---

## §1 Use When — 触发条件

### 触发场景

| 场景 | 典型表述 |
|------|---------|
| 过场动画配音 | "给我的过场动画加配音"、"cutscene voice"、"CG 配音" |
| 多语言对话系统 | "对话系统要有语音"、"多语言语音切换"、"voice dialogue" |
| 字幕时间轴 | "字幕和语音同步"、"subtitle timeline"、"字幕系统" |
| 批量语音生成 | "批量生成对话音频"、"一次生成所有对话语音" |
| 视频本地化 | "给视频加多语言配音"、"视频配音本地化" |
| 完整管线 | "从剧本到播放的完整流水线"、"配音管线" |

### 不触发场景

| 场景 | 应使用 |
|------|--------|
| 单纯播放音效/BGM | `audio-manager` skill |
| AI 音乐生成 | `@Huiyu-Skill_music-producer` skill |
| 仅 UI 文本翻译 | `i18n-translation` recipe |
| NPC 实时 AI 对话 | `gaia-npc-ai` skill |
| 仅视频播放（无配音） | `engine-docs/recipes/video.md` |

---

## §2 概念映射 — Linly-Dubbing → UrhoX

### 原始管线 vs 游戏管线

```
Linly-Dubbing 原始管线:
  视频输入 → UVR5人声分离 → WhisperX语音识别 → LLM翻译 → CosyVoice语音合成 → 唇形同步 → 视频合成

UrhoX 游戏管线 (本 Skill):
  剧本编写 → 角色声音设计 → 多语言翻译 → ElevenLabs语音合成 → 字幕时间轴 → 过场播放器集成
```

### 模块映射表

| Linly-Dubbing 模块 | 游戏管线模块 | UrhoX 实现 |
|-------------------|-------------|-----------|
| ASR (FunASR/WhisperX) | **ScriptManager** | 剧本 JSON 管理（游戏不需要从音频识别，直接编写剧本） |
| 翻译 (GPT/Qwen) | **ScriptTranslator** | 离线翻译 + i18n 框架集成 |
| TTS (CosyVoice/XTTS) | **VoiceSynthesizer** | ElevenLabs MCP 工具（`audition_voices` → `confirm_voice` → `text_to_dialogue`） |
| 音频分离 (UVR5/Demucs) | **AudioMixer** | Lua 音轨分层管理（BGM/Voice/SFX 分开控制） |
| 唇形同步 (Linly-Talker) | **LipSyncDriver** | 基于音频时长的嘴型动画权重驱动（AnimationController blend） |
| 视频合成 | **CutscenePlayer** | VideoPlayer Widget + UI 字幕叠加 / 3D 过场引擎 |
| 字幕生成 | **SubtitleTimeline** | 时间轴数据结构 + UI.Label 渲染 |

### 设计决策

| 决策点 | Linly-Dubbing 方案 | 本 Skill 方案 | 理由 |
|--------|-------------------|-------------|------|
| 语音来源 | 从视频提取 (ASR) | 从剧本编写 | 游戏文本已知，无需语音识别 |
| TTS 引擎 | CosyVoice/XTTS/GPT-SoVITS | ElevenLabs (引擎内置) | MCP 工具已就绪，零部署 |
| 翻译引擎 | GPT/Qwen API | 离线翻译 + i18n extract | 构建时翻译，运行时查表 |
| 唇形同步 | Linly-Talker 神经网络 | 音频振幅/音素映射 blend | 纯 Lua，无外部依赖 |
| 视频合成 | ffmpeg 合并 | VideoPlayer + UI 叠加 | 引擎原生支持 |
| 输出格式 | .mp4 视频文件 | 运行时实时渲染 | 游戏过场是实时的 |

---

## §3 ScriptManager — 剧本管理模块

### 剧本 JSON 格式

```
scripts/cutscenes/
├── act1_opening.json       # 第一幕：开场
├── act2_battle.json        # 第二幕：战斗
├── characters.json         # 角色声音配置
└── ...
```

**单个剧本文件** (`act1_opening.json`):

```json
{
  "id": "act1_opening",
  "title": "序章：黎明前的黑暗",
  "scenes": [
    {
      "id": "scene_01",
      "background": "videos/opening_bg.mp4",
      "bgm": "Sounds/bgm_tension.ogg",
      "bgmVolume": 0.3,
      "lines": [
        {
          "id": "line_001",
          "character": "narrator",
          "text": "在那个被遗忘的时代，世界正处于崩溃的边缘。",
          "duration": 4.5,
          "emotion": "serious",
          "subtitle": true,
          "pause_after": 0.5
        },
        {
          "id": "line_002",
          "character": "hero",
          "text": "[sighs] 又是一个不眠之夜……明天，一切都会不同的。",
          "duration": 5.0,
          "emotion": "melancholy",
          "subtitle": true,
          "pause_after": 1.0
        },
        {
          "id": "line_003",
          "character": "mentor",
          "text": "年轻人，真正的力量，来自于你愿意守护的东西。",
          "duration": 4.0,
          "emotion": "wise",
          "subtitle": true
        }
      ]
    }
  ]
}
```

**角色声音配置** (`characters.json`):

```json
{
  "characters": {
    "narrator": {
      "display_name": "旁白",
      "voice_description": "Middle-aged male, deep and gravelly, slow and deliberate, storyteller quality. Studio-quality recording.",
      "color": "#CCCCCC",
      "style": "narrator"
    },
    "hero": {
      "display_name": "艾伦",
      "voice_description": "Young adult male in his 20s, warm and slightly husky tone, moderate pace, determined but tired. Studio-quality recording.",
      "color": "#4FC3F7",
      "style": "protagonist"
    },
    "mentor": {
      "display_name": "老者",
      "voice_description": "Elderly wise man in his 70s, voice deep and gravelly, speaking slowly with dramatic pauses, mysterious and calm tone. Studio-quality recording.",
      "color": "#FFD54F",
      "style": "elder"
    }
  }
}
```

### ScriptManager Lua 模块

```lua
-- scripts/cutscene/ScriptManager.lua
local cjson = require("cjson")

local ScriptManager = {}

--- 加载剧本文件
---@param path string 剧本路径（相对于资源根）
---@return table|nil script 剧本数据
function ScriptManager.Load(path)
    local file = File:new(path, FILE_READ)
    if not file or not file:IsOpen() then
        log:Error("[ScriptManager] Cannot open: " .. path)
        return nil
    end
    local content = file:ReadString()
    file:Close()
    file:delete()
    local ok, data = pcall(cjson.decode, content)
    if not ok then
        log:Error("[ScriptManager] JSON parse error: " .. tostring(data))
        return nil
    end
    log:Info("[ScriptManager] Loaded script: " .. (data.id or path))
    return data
end

--- 加载角色配置
---@param path string
---@return table|nil characters
function ScriptManager.LoadCharacters(path)
    local data = ScriptManager.Load(path)
    if data and data.characters then
        return data.characters
    end
    return nil
end

--- 获取剧本所有台词（扁平列表）
---@param script table
---@return table[] lines
function ScriptManager.GetAllLines(script)
    local lines = {}
    for _, scene in ipairs(script.scenes or {}) do
        for _, line in ipairs(scene.lines or {}) do
            line._scene_id = scene.id
            lines[#lines + 1] = line
        end
    end
    return lines
end

--- 获取剧本涉及的所有角色名
---@param script table
---@return string[]
function ScriptManager.GetCharacterNames(script)
    local seen = {}
    local names = {}
    for _, scene in ipairs(script.scenes or {}) do
        for _, line in ipairs(scene.lines or {}) do
            if not seen[line.character] then
                seen[line.character] = true
                names[#names + 1] = line.character
            end
        end
    end
    return names
end

--- 统计剧本信息
---@param script table
---@return table stats
function ScriptManager.GetStats(script)
    local lines = ScriptManager.GetAllLines(script)
    local totalDuration = 0
    local charCounts = {}
    for _, line in ipairs(lines) do
        totalDuration = totalDuration + (line.duration or 3.0) + (line.pause_after or 0)
        charCounts[line.character] = (charCounts[line.character] or 0) + 1
    end
    return {
        total_lines = #lines,
        total_duration = totalDuration,
        scene_count = #(script.scenes or {}),
        character_line_counts = charCounts,
    }
end

return ScriptManager
```

---

## §4 VoiceSynthesizer — 语音合成模块

### 概述

本模块封装 UrhoX 引擎内置的 ElevenLabs MCP 工具，实现"角色声音试听 → 确认 → 批量台词合成"三阶段工作流。

### 三阶段工作流

```
阶段 1: 声音设计 (一次性)
  ┌─────────────────────────────────────────┐
  │ 读取 characters.json                     │
  │ → 对每个角色调用 audition_voices_for_character │
  │ → 用户试听并选择                           │
  │ → 调用 confirm_character_voice 确认        │
  └─────────────────────────────────────────┘

阶段 2: 批量合成 (每个剧本执行一次)
  ┌─────────────────────────────────────────┐
  │ 读取剧本 JSON                            │
  │ → 收集所有台词                            │
  │ → 按角色分组                              │
  │ → 调用 text_to_dialogue 批量合成          │
  │ → 生成 .ogg 音频文件到 assets/Voices/     │
  └─────────────────────────────────────────┘

阶段 3: 多语言合成 (按语言重复阶段 2)
  ┌─────────────────────────────────────────┐
  │ 读取翻译后的剧本 JSON                     │
  │ → 使用相同角色声音                        │
  │ → 指定目标语言代码                        │
  │ → 输出到 assets/Voices/{lang}/           │
  └─────────────────────────────────────────┘
```

### 音频文件命名规范

```
assets/Voices/
├── cmn/                           # 中文（默认）
│   ├── act1_opening_line_001.ogg
│   ├── act1_opening_line_002.ogg
│   └── ...
├── en/                            # 英文
│   ├── act1_opening_line_001.ogg
│   └── ...
└── ja/                            # 日文
    ├── act1_opening_line_001.ogg
    └── ...
```

### AI 工作流指令

**阶段 1 — 声音设计** (AI 执行)：

```
对于 characters.json 中的每个角色：

1. 读取角色的 voice_description
2. 从剧本中选取一句 >= 100 字符的代表性台词作为 audition_line
3. 调用 audition_voices_for_character:
   - character_name: 角色 ID (如 "hero")
   - character_description: voice_description 的值
   - audition_line: 选取的台词
   - candidate_count: 3
4. 展示候选语音给用户
5. 用户选择后调用 confirm_character_voice

注意：
- audition_line 必须 >= 100 字符（API 要求）
- 语音描述必须用英文（ElevenLabs 要求）
- 每个 confirm 消耗 1 个 Voice Slot
```

**阶段 2 — 批量合成** (AI 执行)：

```
对于剧本中的每句台词：

1. 构建 text_to_dialogue 调用：
   inputs: [
     { character_name: "hero", text: "[sighs] 又是一个不眠之夜……" },
     { character_name: "mentor", text: "年轻人，真正的力量……" }
   ]
   language_code: "cmn"  # 中文
   stability: 根据 emotion 调整 (dramatic=0.3, normal=0.5, formal=0.7)
   output_name: "act1_opening_line_001"

2. 合成结果保存到 assets/Voices/cmn/

3. 记录每条台词实际音频时长（用于字幕时间轴）
```

### 稳定性参数与情绪映射

```lua
-- scripts/cutscene/VoiceConfig.lua
local VoiceConfig = {}

--- 情绪 → stability 映射
VoiceConfig.EMOTION_STABILITY = {
    serious   = 0.6,
    melancholy = 0.4,
    wise      = 0.65,
    angry     = 0.3,
    excited   = 0.35,
    calm      = 0.7,
    nervous   = 0.4,
    comedic   = 0.45,
    dramatic  = 0.3,
    neutral   = 0.5,
}

--- 语言代码表
VoiceConfig.LANGUAGES = {
    cmn = "中文",
    en  = "English",
    ja  = "日本語",
    ko  = "한국어",
    es  = "Español",
    fr  = "Français",
    de  = "Deutsch",
}

--- 获取稳定性值
---@param emotion string
---@return number
function VoiceConfig.GetStability(emotion)
    return VoiceConfig.EMOTION_STABILITY[emotion] or 0.5
end

return VoiceConfig
```

---

## §5 ScriptTranslator — 多语言翻译模块

### 概述

映射 Linly-Dubbing 的 LLM 翻译层。游戏场景下采用离线翻译 + i18n 框架集成，
而非运行时调用 LLM API。

### 翻译工作流

```
1. 编写源语言剧本 (scripts/cutscenes/act1_opening.json)
   ↓
2. AI 辅助翻译
   ├── 方式 A: AI 直接生成翻译版剧本 JSON
   │   → scripts/cutscenes/en/act1_opening.json
   │   → scripts/cutscenes/ja/act1_opening.json
   │
   └── 方式 B: 使用 i18n_extract MCP 工具 (推荐量产)
       → 提取所有 text 字段为翻译键
       → 生成 .pending.json 翻译文件
       → 翻译后构建时自动替换
   ↓
3. 翻译后的台词送入 VoiceSynthesizer 合成对应语言的语音
```

### 方式 A — 直接翻译剧本 (小规模项目推荐)

AI 执行步骤：

```
1. 读取源语言剧本 JSON
2. 对每个 line.text 翻译为目标语言
3. 保持 line.id 不变（用于关联音频文件）
4. 调整 line.duration（不同语言语速不同）
5. 输出翻译后的 JSON 到 scripts/cutscenes/{lang}/ 目录
```

翻译后剧本示例：

```json
{
  "id": "act1_opening",
  "lang": "en",
  "scenes": [
    {
      "id": "scene_01",
      "lines": [
        {
          "id": "line_001",
          "character": "narrator",
          "text": "In that forgotten age, the world was on the brink of collapse.",
          "duration": 4.5,
          "emotion": "serious",
          "subtitle": true,
          "pause_after": 0.5
        }
      ]
    }
  ]
}
```

### 方式 B — i18n 框架集成 (大型项目推荐)

```lua
-- 在 .project/i18n.json 中启用
-- {
--   "enabled": true,
--   "source_lang": "zh",
--   "target_langs": ["en", "ja", "ko"]
-- }

-- 调用 i18n_extract MCP 工具扫描剧本文件
-- AI 执行: mcp__sce-urhox__i18n_extract({ scriptsPath: "scripts" })
```

---

## §6 SubtitleTimeline — 字幕时间轴模块

### 概述

映射 Linly-Dubbing 的字幕生成与时间戳对齐功能。
在游戏引擎中实现精确的字幕显示控制，支持淡入淡出、多行、说话人标识。

### 时间轴数据结构

```lua
-- scripts/cutscene/SubtitleTimeline.lua
local SubtitleTimeline = {}

--- 从剧本构建时间轴
---@param script table 剧本数据
---@return table timeline
function SubtitleTimeline.Build(script)
    local timeline = {
        entries = {},
        totalDuration = 0,
    }
    local currentTime = 0

    for _, scene in ipairs(script.scenes or {}) do
        for _, line in ipairs(scene.lines or {}) do
            local duration = line.duration or 3.0
            local pauseAfter = line.pause_after or 0

            local entry = {
                id = line.id,
                character = line.character,
                text = line.text,
                startTime = currentTime,
                endTime = currentTime + duration,
                duration = duration,
                fadeIn = 0.2,
                fadeOut = 0.3,
                emotion = line.emotion,
                showSubtitle = (line.subtitle ~= false),
                audioFile = nil,  -- 由 VoiceSynthesizer 填充
            }

            timeline.entries[#timeline.entries + 1] = entry
            currentTime = currentTime + duration + pauseAfter
        end
    end

    timeline.totalDuration = currentTime
    return timeline
end

--- 查找当前时间对应的字幕条目
---@param timeline table
---@param time number 当前播放时间
---@return table|nil entry
function SubtitleTimeline.GetCurrent(timeline, time)
    for _, entry in ipairs(timeline.entries) do
        if time >= entry.startTime and time < entry.endTime then
            return entry
        end
    end
    return nil
end

--- 计算字幕透明度（含淡入淡出）
---@param entry table
---@param time number
---@return number alpha 0.0~1.0
function SubtitleTimeline.GetAlpha(entry, time)
    local elapsed = time - entry.startTime
    local remaining = entry.endTime - time

    if elapsed < entry.fadeIn then
        return elapsed / entry.fadeIn
    elseif remaining < entry.fadeOut then
        return remaining / entry.fadeOut
    else
        return 1.0
    end
end

--- 绑定音频文件路径到时间轴
---@param timeline table
---@param lang string 语言代码
---@param scriptId string 剧本 ID
function SubtitleTimeline.BindAudio(timeline, lang, scriptId)
    for _, entry in ipairs(timeline.entries) do
        entry.audioFile = "Voices/" .. lang .. "/" .. scriptId .. "_" .. entry.id .. ".ogg"
    end
end

--- 序列化时间轴为 JSON（调试/缓存）
---@param timeline table
---@return string
function SubtitleTimeline.ToJSON(timeline)
    local cjson = require("cjson")
    return cjson.encode(timeline)
end

--- 从 JSON 反序列化
---@param jsonStr string
---@return table
function SubtitleTimeline.FromJSON(jsonStr)
    local cjson = require("cjson")
    return cjson.decode(jsonStr)
end

--- 保存时间轴到文件
---@param timeline table
---@param path string
function SubtitleTimeline.Save(timeline, path)
    local file = File:new(path, FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString(SubtitleTimeline.ToJSON(timeline))
        file:Close()
        file:delete()
        log:Info("[SubtitleTimeline] Saved: " .. path)
    end
end

--- 从文件加载时间轴
---@param path string
---@return table|nil
function SubtitleTimeline.LoadFromFile(path)
    local file = File:new(path, FILE_READ)
    if not file or not file:IsOpen() then return nil end
    local content = file:ReadString()
    file:Close()
    file:delete()
    return SubtitleTimeline.FromJSON(content)
end

return SubtitleTimeline
```

---

## §7 AudioMixer — 音轨分层管理模块

### 概述

映射 Linly-Dubbing 的 UVR5/Demucs 音频分离功能。
游戏场景下不需要分离已有音频，而是从源头分层管理三条音轨：BGM、Voice、SFX。

### 音轨架构

```
  ┌─────────────────────────────────────────┐
  │            AudioMixer                    │
  │  ┌───────────┬──────────┬────────────┐  │
  │  │  BGM 轨   │ Voice 轨 │   SFX 轨   │  │
  │  │ (持续播放) │(台词驱动) │ (事件触发) │  │
  │  │ Volume:0.3│Volume:1.0│ Volume:0.8 │  │
  │  └───────────┴──────────┴────────────┘  │
  └─────────────────────────────────────────┘
```

### AudioMixer Lua 模块

```lua
-- scripts/cutscene/AudioMixer.lua
local AudioMixer = {}

---@type Scene
local scene_ = nil
---@type Node
local bgmNode_ = nil
---@type Node
local voiceNode_ = nil
---@type SoundSource
local bgmSource_ = nil
---@type SoundSource
local voiceSource_ = nil

local volumes_ = {
    master = 1.0,
    bgm    = 0.3,
    voice  = 1.0,
    sfx    = 0.8,
}

--- 初始化音频混合器
---@param scene Scene
function AudioMixer.Init(scene)
    scene_ = scene
    bgmNode_ = scene_:CreateChild("BGM")
    voiceNode_ = scene_:CreateChild("Voice")

    bgmSource_ = bgmNode_:CreateComponent("SoundSource")
    bgmSource_.soundType = SOUND_MUSIC

    voiceSource_ = voiceNode_:CreateComponent("SoundSource")
    voiceSource_.soundType = SOUND_VOICE
end

--- 播放 BGM
---@param path string 音频资源路径
---@param fadeIn number|nil 淡入时长（秒）
function AudioMixer.PlayBGM(path, fadeIn)
    local sound = cache:GetResource("Sound", path)
    if not sound then
        log:Error("[AudioMixer] BGM not found: " .. path)
        return
    end
    sound.looped = true
    bgmSource_:Play(sound)
    bgmSource_.gain = fadeIn and 0 or (volumes_.bgm * volumes_.master)
end

--- 播放台词音频
---@param path string 音频资源路径
---@param onFinished function|nil 播放完成回调
---@return number duration 音频时长（秒）
function AudioMixer.PlayVoice(path, onFinished)
    local sound = cache:GetResource("Sound", path)
    if not sound then
        log:Warning("[AudioMixer] Voice not found: " .. path)
        return 0
    end
    voiceSource_:Play(sound)
    voiceSource_.gain = volumes_.voice * volumes_.master

    -- 压低 BGM 音量 (ducking)
    bgmSource_.gain = volumes_.bgm * volumes_.master * 0.4

    return sound.length
end

--- 停止台词并恢复 BGM 音量
function AudioMixer.StopVoice()
    voiceSource_:Stop()
    bgmSource_.gain = volumes_.bgm * volumes_.master
end

--- 设置音轨音量
---@param track string "master"|"bgm"|"voice"|"sfx"
---@param volume number 0.0~1.0
function AudioMixer.SetVolume(track, volume)
    volumes_[track] = math.max(0, math.min(1, volume))
    -- 实时更新
    if bgmSource_ then
        bgmSource_.gain = volumes_.bgm * volumes_.master
    end
    if voiceSource_ and not voiceSource_:IsPlaying() then
        voiceSource_.gain = volumes_.voice * volumes_.master
    end
end

--- 台词是否正在播放
---@return boolean
function AudioMixer.IsVoicePlaying()
    return voiceSource_ ~= nil and voiceSource_:IsPlaying()
end

--- 清理
function AudioMixer.Cleanup()
    if bgmNode_ then bgmNode_:Remove() end
    if voiceNode_ then voiceNode_:Remove() end
    bgmNode_ = nil
    voiceNode_ = nil
    bgmSource_ = nil
    voiceSource_ = nil
end

return AudioMixer
```

---

## §8 LipSyncDriver — 简易唇形同步模块

### 概述

映射 Linly-Dubbing 的 Linly-Talker 唇形同步功能。
由于游戏引擎中不运行神经网络，采用基于音频时长的权重动画驱动方案：
按台词时长在 idle 与 talk 动画之间混合，实现嘴型开合效果。

### LipSyncDriver Lua 模块

```lua
-- scripts/cutscene/LipSyncDriver.lua
local LipSyncDriver = {}

---@class LipSyncState
---@field node Node
---@field animCtrl AnimationController
---@field isTalking boolean
---@field talkTimer number
---@field talkDuration number
---@field blendWeight number

---@type table<string, LipSyncState>
local states_ = {}

--- 注册一个角色节点（须已挂载 AnimationController + 动画）
---@param characterId string 角色 ID
---@param node Node 角色根节点
---@param idleAnim string idle 动画路径
---@param talkAnim string talk/嘴型动画路径
function LipSyncDriver.Register(characterId, node, idleAnim, talkAnim)
    local animCtrl = node:GetComponent("AnimationController")
    if not animCtrl then
        log:Error("[LipSyncDriver] No AnimationController on: " .. characterId)
        return
    end

    -- 设置 idle 动画为基础层
    animCtrl:PlayExclusive(idleAnim, 0, true, 0.3)

    -- 预加载 talk 动画到高层
    animCtrl:Play(talkAnim, 1, true, 0.0)
    animCtrl:SetWeight(talkAnim, 0.0)

    states_[characterId] = {
        node = node,
        animCtrl = animCtrl,
        idleAnim = idleAnim,
        talkAnim = talkAnim,
        isTalking = false,
        talkTimer = 0,
        talkDuration = 0,
        blendWeight = 0,
    }
    log:Info("[LipSyncDriver] Registered: " .. characterId)
end

--- 开始说话（嘴型动画混入）
---@param characterId string
---@param duration number 台词时长
function LipSyncDriver.StartTalk(characterId, duration)
    local state = states_[characterId]
    if not state then return end
    state.isTalking = true
    state.talkTimer = 0
    state.talkDuration = duration
end

--- 停止说话（嘴型动画混出）
---@param characterId string
function LipSyncDriver.StopTalk(characterId)
    local state = states_[characterId]
    if not state then return end
    state.isTalking = false
end

--- 每帧更新（在 HandleUpdate 中调用）
---@param dt number
function LipSyncDriver.Update(dt)
    for id, state in pairs(states_) do
        if state.isTalking then
            state.talkTimer = state.talkTimer + dt
            -- 简易嘴型节奏：用正弦波模拟开合
            local freq = 6.0  -- 每秒开合 6 次
            local raw = math.abs(math.sin(state.talkTimer * freq * math.pi))
            -- 平滑混入
            state.blendWeight = state.blendWeight + (raw - state.blendWeight) * math.min(1, dt * 12)

            if state.talkTimer >= state.talkDuration then
                state.isTalking = false
            end
        else
            -- 平滑混出
            state.blendWeight = state.blendWeight * (1 - math.min(1, dt * 8))
            if state.blendWeight < 0.01 then
                state.blendWeight = 0
            end
        end

        -- 应用混合权重
        state.animCtrl:SetWeight(state.talkAnim, state.blendWeight)
    end
end

--- 清理
function LipSyncDriver.Cleanup()
    states_ = {}
end

return LipSyncDriver
```

---

## §9 CutscenePlayer — 过场播放器（完整集成）

### 概述

将所有模块整合为统一的过场播放器，支持：
- 视频背景 + UI 字幕叠加模式
- 3D 场景 + 角色动画模式
- BGM 自动压低（ducking）
- 台词自动推进 / 手动跳过
- 多语言热切换

### CutscenePlayer Lua 模块

```lua
-- scripts/cutscene/CutscenePlayer.lua
local ScriptManager    = require("cutscene.ScriptManager")
local SubtitleTimeline = require("cutscene.SubtitleTimeline")
local AudioMixer       = require("cutscene.AudioMixer")
local LipSyncDriver    = require("cutscene.LipSyncDriver")
local VoiceConfig      = require("cutscene.VoiceConfig")

local UI    = require("urhox-libs/UI")
local Video = require("urhox-libs/Video")

local CutscenePlayer = {}

---@class CutsceneState
---@field script table
---@field timeline table
---@field characters table
---@field lang string
---@field currentIndex number
---@field playTime number
---@field isPlaying boolean
---@field isPaused boolean
---@field autoAdvance boolean
---@field onComplete function|nil

local state_ = nil

--- 字幕 UI 节点引用
local subtitleLabel_ = nil
local speakerLabel_  = nil
local skipButton_    = nil
local rootPanel_     = nil

--- 初始化过场播放器
---@param scene Scene
---@param config table { lang, autoAdvance, onComplete }
function CutscenePlayer.Init(scene, config)
    config = config or {}
    AudioMixer.Init(scene)

    state_ = {
        script = nil,
        timeline = nil,
        characters = nil,
        lang = config.lang or "cmn",
        currentIndex = 0,
        playTime = 0,
        isPlaying = false,
        isPaused = false,
        autoAdvance = config.autoAdvance ~= false,
        onComplete = config.onComplete,
    }
end

--- 加载并开始播放剧本
---@param scriptPath string 剧本 JSON 路径
---@param charsPath string 角色配置 JSON 路径
function CutscenePlayer.Play(scriptPath, charsPath)
    -- 加载剧本
    state_.script = ScriptManager.Load(scriptPath)
    if not state_.script then
        log:Error("[CutscenePlayer] Failed to load script")
        return
    end

    -- 加载角色配置
    state_.characters = ScriptManager.LoadCharacters(charsPath)

    -- 构建时间轴
    state_.timeline = SubtitleTimeline.Build(state_.script)
    SubtitleTimeline.BindAudio(state_.timeline, state_.lang, state_.script.id)

    -- 初始化状态
    state_.currentIndex = 0
    state_.playTime = 0
    state_.isPlaying = true

    -- 创建字幕 UI
    CutscenePlayer._CreateSubtitleUI()

    -- 播放第一个场景的 BGM
    local firstScene = state_.script.scenes[1]
    if firstScene and firstScene.bgm then
        AudioMixer.PlayBGM(firstScene.bgm)
    end

    -- 推进到第一句
    CutscenePlayer._AdvanceLine()

    log:Info("[CutscenePlayer] Playing: " .. state_.script.id)
end

--- 创建字幕 UI 层
function CutscenePlayer._CreateSubtitleUI()
    speakerLabel_ = UI.Label {
        text = "",
        fontSize = 18,
        color = "#FFD54F",
        marginBottom = 4,
    }

    subtitleLabel_ = UI.Label {
        text = "",
        fontSize = 22,
        color = "#FFFFFF",
        textAlign = "center",
        maxWidth = 800,
    }

    skipButton_ = UI.Button {
        text = "跳过 ▶",
        variant = "ghost",
        size = "sm",
        onClick = function()
            CutscenePlayer._AdvanceLine()
        end,
    }

    rootPanel_ = UI.Panel {
        width = "100%",
        height = "100%",
        position = "absolute",
        justifyContent = "flex-end",
        alignItems = "center",
        paddingBottom = 60,
        children = {
            UI.Panel {
                backgroundColor = "rgba(0,0,0,0.65)",
                borderRadius = 12,
                paddingX = 32,
                paddingY = 16,
                alignItems = "center",
                children = {
                    speakerLabel_,
                    subtitleLabel_,
                    UI.Panel {
                        marginTop = 8,
                        children = { skipButton_ },
                    },
                },
            },
        },
    }
end

--- 获取字幕根面板（供外部挂载到 UI 树）
---@return table
function CutscenePlayer.GetSubtitlePanel()
    return rootPanel_
end

--- 推进到下一句台词
function CutscenePlayer._AdvanceLine()
    if not state_ or not state_.isPlaying then return end

    state_.currentIndex = state_.currentIndex + 1
    local entries = state_.timeline.entries

    if state_.currentIndex > #entries then
        CutscenePlayer.Stop()
        return
    end

    local entry = entries[state_.currentIndex]

    -- 更新字幕
    if entry.showSubtitle and subtitleLabel_ then
        local charConfig = state_.characters and state_.characters[entry.character]
        local displayName = charConfig and charConfig.display_name or entry.character

        UI.Update(speakerLabel_, { text = displayName })
        if charConfig and charConfig.color then
            UI.Update(speakerLabel_, { color = charConfig.color })
        end
        UI.Update(subtitleLabel_, { text = entry.text })
    end

    -- 播放语音
    if entry.audioFile then
        local duration = AudioMixer.PlayVoice(entry.audioFile)
        -- 通知唇形同步
        LipSyncDriver.StartTalk(entry.character, duration > 0 and duration or entry.duration)
    end

    -- 设置推进定时器
    state_.playTime = 0
end

--- 每帧更新（在 HandleUpdate 中调用）
---@param dt number
function CutscenePlayer.Update(dt)
    if not state_ or not state_.isPlaying or state_.isPaused then return end

    state_.playTime = state_.playTime + dt
    LipSyncDriver.Update(dt)

    -- 自动推进
    if state_.autoAdvance then
        local entries = state_.timeline.entries
        local entry = entries[state_.currentIndex]
        if entry then
            local totalDur = entry.duration + (entry.pause_after or 0)
            if state_.playTime >= totalDur then
                -- 停止当前唇形
                LipSyncDriver.StopTalk(entry.character)
                AudioMixer.StopVoice()
                CutscenePlayer._AdvanceLine()
            end
        end
    end
end

--- 切换语言
---@param lang string 语言代码
function CutscenePlayer.SetLanguage(lang)
    if not state_ then return end
    state_.lang = lang

    -- 重新绑定音频路径
    if state_.timeline and state_.script then
        SubtitleTimeline.BindAudio(state_.timeline, lang, state_.script.id)
    end

    -- 加载对应语言的翻译剧本（如果存在）
    local translatedPath = "cutscenes/" .. lang .. "/" .. state_.script.id .. ".json"
    local translated = ScriptManager.Load(translatedPath)
    if translated then
        -- 更新时间轴中的文本
        local origEntries = state_.timeline.entries
        local transLines = ScriptManager.GetAllLines(translated)
        for i, entry in ipairs(origEntries) do
            if transLines[i] then
                entry.text = transLines[i].text
            end
        end
    end

    log:Info("[CutscenePlayer] Language switched to: " .. lang)
end

--- 暂停
function CutscenePlayer.Pause()
    if state_ then state_.isPaused = true end
end

--- 恢复
function CutscenePlayer.Resume()
    if state_ then state_.isPaused = false end
end

--- 停止并清理
function CutscenePlayer.Stop()
    if not state_ then return end
    state_.isPlaying = false
    AudioMixer.StopVoice()
    LipSyncDriver.Cleanup()

    if state_.onComplete then
        state_.onComplete()
    end

    log:Info("[CutscenePlayer] Cutscene completed")
end

--- 是否正在播放
---@return boolean
function CutscenePlayer.IsPlaying()
    return state_ ~= nil and state_.isPlaying
end

return CutscenePlayer
```

---

## §10 完整集成示例

### main.lua — 过场动画游戏入口

```lua
-- scripts/main.lua
-- 过场动画配音系统完整示例
require "LuaScripts/Utilities/Sample"

local UI    = require("urhox-libs/UI")
local Video = require("urhox-libs/Video")
local CutscenePlayer = require("cutscene.CutscenePlayer")

---@type Scene
local scene_ = nil

function Start()
    -- 初始化 UI
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 初始化过场播放器
    CutscenePlayer.Init(scene_, {
        lang = "cmn",
        autoAdvance = true,
        onComplete = function()
            log:Info("[Main] Cutscene finished\! Transitioning to gameplay...")
            ShowMainMenu()
        end,
    })

    -- 构建 UI
    local videoPanel = Video.VideoPlayer {
        src = "videos/opening_bg.mp4",
        width = "100%", height = "100%",
        autoPlay = true,
        loop = true,
        objectFit = "cover",
    }

    local root = UI.Panel {
        width = "100%", height = "100%",
        children = {
            videoPanel,
            CutscenePlayer.GetSubtitlePanel(),
        },
    }
    UI.SetRoot(root)

    -- 开始播放剧本
    CutscenePlayer.Play("cutscenes/act1_opening.json", "cutscenes/characters.json")

    -- 注册更新事件
    SubscribeToEvent("Update", HandleUpdate)

    log:Info("[Main] Cutscene system started")
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    CutscenePlayer.Update(dt)

    -- ESC 跳过整个过场
    if input:GetKeyPress(KEY_ESCAPE) then
        CutscenePlayer.Stop()
    end
end

function ShowMainMenu()
    log:Info("[Main] Showing main menu...")
    -- 这里切换到主菜单场景
end

function Stop()
    log:Info("[Main] Application stopping")
end
```

---

## §11 批量语音合成工作流

### AI 执行指令（完整生产流程）

```
=== 批量配音生产流程 ===

输入:
  - scripts/cutscenes/characters.json (角色定义)
  - scripts/cutscenes/*.json (所有剧本)
  - 目标语言: ["cmn", "en", "ja"]

步骤 1: 角色声音设计
  FOR EACH character IN characters.json:
    1. 调用 audition_voices_for_character
    2. 展示 3 个候选给用户
    3. 用户选择后调用 confirm_character_voice
  END

步骤 2: 批量合成 (每个语言)
  FOR EACH lang IN ["cmn", "en", "ja"]:
    FOR EACH script IN cutscenes/*.json:
      1. 收集所有 lines
      2. 如果 lang \!= "cmn", 加载翻译版 cutscenes/{lang}/{script_id}.json
      3. 构建 text_to_dialogue 调用:
         inputs: [
           { character_name: "hero", text: line.text },
           ...
         ]
         language_code: lang
         stability: VoiceConfig.GetStability(line.emotion)
         output_name: "{script_id}_{line_id}"
      4. 生成的 .ogg 移动到 assets/Voices/{lang}/
    END
  END

步骤 3: 验证
  - 检查 assets/Voices/ 目录结构
  - 统计生成文件数量
  - 报告缺失/失败的台词

步骤 4: 构建
  - 调用 build 工具将 assets/ 打入构建包
```

---

## §12 视频过场模式 vs 3D 过场模式

### 模式选择

| 模式 | 适用场景 | 技术方案 |
|------|---------|---------|
| **视频过场** | 预渲染 CG、实拍片段、2D 动画 | `Video.VideoPlayer` + 字幕 UI 叠加 |
| **3D 实时过场** | 引擎内角色演出、可交互过场 | 3D 场景 + 角色动画 + LipSyncDriver |
| **混合模式** | 视频背景 + 3D 角色叠加 | VideoPlayer + 3D Viewport 分层 |

### 视频过场集成

```lua
-- 视频过场：VideoPlayer + 字幕叠加
local Video = require("urhox-libs/Video")
local UI    = require("urhox-libs/UI")

local root = UI.Panel {
    width = "100%", height = "100%",
    children = {
        Video.VideoPlayer {
            src = "videos/act1_cinematic.mp4",
            width = "100%", height = "100%",
            autoPlay = true,
            objectFit = "contain",
            onEnded = function(self)
                CutscenePlayer.Stop()
            end,
        },
        CutscenePlayer.GetSubtitlePanel(),
    },
}
UI.SetRoot(root)
```

### 3D 实时过场集成

```lua
-- 3D 过场：场景 + 角色 + LipSync
local LipSyncDriver = require("cutscene.LipSyncDriver")

-- 设置角色
local heroNode = scene_:CreateChild("Hero")
local heroModel = heroNode:CreateComponent("AnimatedModel")
heroModel:SetModel(cache:GetResource("Model", "Models/Hero.mdl"))
heroModel:SetMaterial(cache:GetResource("Material", "Materials/Hero.xml"))

local heroAnim = heroNode:CreateComponent("AnimationController")
LipSyncDriver.Register("hero", heroNode,
    "Models/Hero_Idle.ani",
    "Models/Hero_Talk.ani")

-- 在 CutscenePlayer 播放时自动驱动 LipSyncDriver
```

---

## §13 过场状态持久化

### 存档集成

```lua
-- scripts/cutscene/CutsceneSaveData.lua
local cjson = require("cjson")

local CutsceneSaveData = {}

--- 保存过场进度
---@param scriptId string
---@param lineIndex number
---@param lang string
function CutsceneSaveData.Save(scriptId, lineIndex, lang)
    local data = {
        script_id = scriptId,
        line_index = lineIndex,
        lang = lang,
        timestamp = os.time(),
    }
    local file = File:new("cutscene_progress.json", FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString(cjson.encode(data))
        file:Close()
        file:delete()
        log:Info("[CutsceneSave] Progress saved at line " .. lineIndex)
    end
end

--- 加载过场进度
---@return table|nil
function CutsceneSaveData.Load()
    local file = File:new("cutscene_progress.json", FILE_READ)
    if not file or not file:IsOpen() then return nil end
    local content = file:ReadString()
    file:Close()
    file:delete()
    local ok, data = pcall(cjson.decode, content)
    if ok then
        log:Info("[CutsceneSave] Progress loaded: line " .. data.line_index)
        return data
    end
    return nil
end

--- 清除进度（过场播放完毕后）
function CutsceneSaveData.Clear()
    local file = File:new("cutscene_progress.json", FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString("{}")
        file:Close()
        file:delete()
    end
end

--- 检查是否有未完成的过场
---@return boolean
function CutsceneSaveData.HasProgress()
    local data = CutsceneSaveData.Load()
    return data ~= nil and data.script_id ~= nil and data.line_index ~= nil
end

return CutsceneSaveData
```

---

## §14 规则与约束

### 引擎规则遵从表

| 规则 | 状态 | 说明 |
|------|------|------|
| 代码放 `scripts/` | ✅ | 所有模块在 `scripts/cutscene/` |
| 资源放 `assets/` | ✅ | 语音 `assets/Voices/`，视频 `assets/videos/` |
| File API（非 io 库）| ✅ | 全部使用 `File:new()` |
| JSON 用 cjson | ✅ | `require("cjson")` |
| 数组索引从 1 开始 | ✅ | 所有 `ipairs` / `for i=1,#t` |
| 使用枚举常量 | ✅ | `KEY_ESCAPE`, `SOUND_MUSIC`, `SOUND_VOICE`, `FILE_READ`, `FILE_WRITE` |
| NanoVG 用 NanoVGRender 事件 | ✅ | 字幕使用 UI 组件，不用 raw NanoVG |
| UI 使用 urhox-libs/UI | ✅ | 字幕面板使用 UI.Panel / UI.Label / UI.Button |
| 修改后必须构建 | ✅ | 完成代码后调用 build 工具 |

### 性能预算

| 指标 | 建议值 | 说明 |
|------|--------|------|
| 单剧本台词数 | ≤ 200 | 超过时拆分为多个剧本文件 |
| 字幕更新频率 | 每句一次 | 不是每帧更新文本内容 |
| 音频预加载 | 当前场景 | 按场景预加载，非一次全加载 |
| LipSync 更新 | 每帧 | `math.sin` 计算开销极低 |

### 目录结构总览

```
scripts/
├── main.lua                        # 游戏入口
└── cutscene/
    ├── ScriptManager.lua           # 剧本加载/解析
    ├── SubtitleTimeline.lua        # 字幕时间轴
    ├── AudioMixer.lua              # 音轨分层管理
    ├── LipSyncDriver.lua           # 唇形同步驱动
    ├── VoiceConfig.lua             # 语音配置
    ├── CutscenePlayer.lua          # 过场播放器（集成）
    ├── CutsceneSaveData.lua        # 进度存档
    └── cutscenes/
        ├── characters.json         # 角色声音定义
        ├── act1_opening.json       # 剧本 - 中文（源语言）
        ├── en/
        │   └── act1_opening.json   # 剧本 - 英文翻译
        └── ja/
            └── act1_opening.json   # 剧本 - 日文翻译

assets/
├── Voices/
│   ├── cmn/                        # 中文语音
│   │   ├── act1_opening_line_001.ogg
│   │   └── ...
│   ├── en/                         # 英文语音
│   └── ja/                         # 日文语音
├── videos/
│   └── opening_bg.mp4              # 视频背景
└── Sounds/
    └── bgm_tension.ogg             # BGM
```

---

## §15 FAQ

**Q1: 如何添加新角色？**

在 `characters.json` 中添加新角色条目，包含 `voice_description`（英文），
然后执行阶段 1 声音设计流程（`audition_voices_for_character` → `confirm_character_voice`）。

**Q2: 支持哪些语言？**

ElevenLabs 支持 29 种语言，常用代码：
`cmn`（中文）、`en`（英文）、`ja`（日文）、`ko`（韩文）、`es`（西班牙文）、`fr`（法文）、`de`（德文）。

**Q3: 如何跳过特定台词的配音？**

在剧本 JSON 中不设置 `character` 字段或将其设为 `null`，该台词将只显示字幕不播放语音。

**Q4: 如何实现分支对话？**

扩展剧本 JSON 格式，在 `line` 中添加 `choices` 数组：

```json
{
  "id": "line_010",
  "character": "npc",
  "text": "你要去哪里？",
  "choices": [
    { "text": "去森林", "jump_to": "line_020" },
    { "text": "回城镇", "jump_to": "line_030" }
  ]
}
```

修改 `CutscenePlayer._AdvanceLine()` 检查 choices 并显示选项按钮。

**Q5: 语音文件太大怎么办？**

- 使用 OGG 格式（默认），比 WAV 小 5-10 倍
- 按章节拆分剧本，只预加载当前章节语音
- 结合 DWP（边玩边下）按需下载语音包

**Q6: 可以不用 ElevenLabs 吗？**

本管线围绕引擎内置的 ElevenLabs MCP 工具设计。如果使用外部 TTS 工具：
1. 在外部生成 .ogg 文件
2. 按命名规范放入 `assets/Voices/{lang}/`
3. 管线的播放/字幕/唇形同步部分仍然可用

**Q7: 如何与 i18n 资源变体配合？**

语音文件支持 i18n 资源变体命名：
- `act1_line_001.ogg` → 默认语言
- `act1_line_001@en.ogg` → 英文
- `act1_line_001@ja.ogg` → 日文

引擎会根据运行时语言自动路由到正确的文件。

---

## §16 参考文档

- [references/pipeline-architecture.md](references/pipeline-architecture.md) — 管线架构设计、Linly-Dubbing 全模块映射详解
- [references/voice-design-guide.md](references/voice-design-guide.md) — ElevenLabs 角色声音设计完整指南
- [references/game-recipes.md](references/game-recipes.md) — 6 个过场配音实战方案
