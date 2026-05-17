---
name: smart-audio-pipeline
version: "1.0.0"
description: |
  游戏智能音频分层管线——将 Linly-Dubbing 的音频分析与处理工作流
  映射为 UrhoX Lua 游戏引擎的音频资产管理系统。
  覆盖：音频分层拆解 → 说话人识别与时间轴标注 → 角色声音档案 →
  多轨混音与音量曲线 → 对白定位回放 → 音频本地化变体管理。
  与 cinematic-dub-pipeline（正向配音管线：剧本→语音→字幕→播放）互补，
  本 Skill 聚焦音频资产的"逆向分析 + 分层管理 + 智能混音"。
  Use when: users need to
  (1) 将混合音频拆分为人声/BGM/音效独立轨道,
  (2) 识别多角色对白并生成说话人时间轴,
  (3) 建立角色声音档案用于语音克隆或一致性管理,
  (4) 实现多轨音频混音与音量包络曲线,
  (5) 管理同一对白的多语言音频变体,
  (6) 从现有音频素材中提取对白文本和时间戳,
  (7) 构建"分析→分层→混音→回放"的音频资产管线。
author: "UrhoX Skill Builder"
source: "https://github.com/Kedreamix/Linly-Dubbing"
tags:
  - audio
  - separation
  - diarization
  - voice-profile
  - mixing
  - localization
  - soundtrack
  - layer
  - speaker
  - dialogue
  - voice-clone
  - bgm
  - sfx
triggers:
  - 音频分层
  - 音频分离
  - 人声分离
  - 说话人识别
  - 声音档案
  - 语音克隆档案
  - 多轨混音
  - 音量曲线
  - 音频本地化
  - 对白提取
  - smart audio
  - audio layer
  - audio separation
  - speaker diarization
  - voice profile
  - multi-track mixing
  - audio localization
  - dialogue extraction
  - audio pipeline
  - soundtrack management
---

# Smart Audio Pipeline — 游戏智能音频分层管线

> **灵感来源**: [Kedreamix/Linly-Dubbing](https://github.com/Kedreamix/Linly-Dubbing)
>
> 将 Linly-Dubbing 的音频分析与处理能力（UVR5/Demucs 音频分离、
> pyannote 说话人分离、CosyVoice/GPT-SoVITS 语音克隆、
> WhisperX ASR 时间戳对齐、多轨背景音乐保留）
> 映射为 UrhoX Lua 游戏引擎的音频资产管理系统。

---

## §1 Use When — 触发条件

### 触发场景

| 场景 | 典型表述 |
|------|---------|
| 音频分层拆解 | "把混合音频拆成人声和BGM"、"分离音效"、"audio separation" |
| 说话人识别 | "识别谁在说话"、"多角色对白标注"、"speaker diarization" |
| 声音档案管理 | "建立角色声音档案"、"管理语音风格"、"voice profile" |
| 多轨混音 | "音量曲线"、"淡入淡出混音"、"多轨叠加"、"multi-track mixing" |
| 音频本地化 | "同一对白多语言版本"、"音频本地化管理"、"audio localization" |
| 对白提取 | "从音频提取对白文本"、"语音转文字加时间戳" |
| 音频管线 | "音频资产管线"、"智能音频处理"、"audio pipeline" |

### 不触发场景（使用其他工具）

| 场景 | 应使用 |
|------|--------|
| 剧本→语音→字幕→过场播放 | `cinematic-dub-pipeline` skill |
| 单纯播放音效/BGM | `audio-manager` skill |
| AI 音乐作曲 | `@Huiyu-Skill_music-producer` skill |
| 仅 UI 文本翻译 | `i18n-translation` recipe |
| 生成音效（爆炸、脚步等） | `text_to_sound_effect` MCP 工具 |
| 生成角色对白音频 | `text_to_dialogue` MCP 工具 |

### 与 cinematic-dub-pipeline 的关系

```
cinematic-dub-pipeline（正向管线）:
  剧本 → 翻译 → 语音合成 → 字幕时间轴 → 过场播放
  ↑ 生产新内容

smart-audio-pipeline（本 Skill，逆向+管理管线）:
  混合音频 → 分层拆解 → 说话人标注 → 声音档案 → 多轨混音 → 回放
  ↑ 分析/管理已有内容

两者互补：本 Skill 的分析结果可作为 cinematic-dub-pipeline 的输入。
```

---

## §2 概念映射 — Linly-Dubbing → Smart Audio Pipeline

| # | Linly-Dubbing 组件 | 原始用途 | G.A.P. 映射 | UrhoX 实现 |
|---|-------------------|---------|------------|-----------|
| 1 | UVR5 / Demucs | 人声伴奏分离 | AudioLayerSplitter | 音频轨道元数据分层管理 |
| 2 | pyannote Speaker Diarization | 说话人识别 | SpeakerTimeline | 对白时间轴 + 角色标注 |
| 3 | CosyVoice / GPT-SoVITS | 语音克隆 | VoiceProfileRegistry | 角色声音档案注册表 |
| 4 | WhisperX / FunASR | ASR + 时间戳 | DialogueExtractor | 对白文本提取与时间对齐 |
| 5 | Edge TTS / XTTS | 文本转语音 | 调用引擎 TTS API | `text_to_dialogue` MCP 工具 |
| 6 | 背景音乐保留 | BGM + 新人声混合 | TrackMixer | 多轨音量包络混音器 |
| 7 | ffmpeg 音频处理 | 格式转换/裁剪 | AudioSegmenter | Lua 音频片段管理 |
| 8 | SRT 字幕导出 | 字幕文件 | SubtitleExporter | JSON 时间轴导出 |
| 9 | 多语言翻译 | 文本翻译 | LocaleVariantManager | 多语言音频变体管理 |
| 10 | WebUI 参数面板 | 用户配置界面 | 引擎 UI 组件 | `urhox-libs/UI` 控制面板 |
| 11 | yt-dlp 视频下载 | 获取源视频 | AssetImporter | 资源导入注册 |
| 12 | 质量校验 | 对齐验证 | QualityChecker | 时间轴完整性校验 |

---

## §3 核心模块架构

```
┌─────────────────────────────────────────────────────┐
│                  Smart Audio Pipeline                │
├──────────┬──────────┬──────────┬─────────────────────┤
│ Module A │ Module B │ Module C │     Module D        │
│ Audio    │ Speaker  │ Voice    │   Track             │
│ Layer    │ Timeline │ Profile  │   Mixer             │
│ Splitter │          │ Registry │                     │
├──────────┼──────────┼──────────┼─────────────────────┤
│ 音频分层  │ 说话人   │ 声音档案  │ 多轨混音            │
│ 元数据   │ 时间轴   │ 注册表   │ 音量包络            │
├──────────┴──────────┴──────────┴─────────────────────┤
│              Module E: Locale Variant Manager        │
│              多语言音频变体管理                         │
├──────────────────────────────────────────────────────┤
│              Module F: Pipeline Orchestrator          │
│              管线编排器（串联所有模块）                   │
└──────────────────────────────────────────────────────┘
```

---

## §3.1 Module A — AudioLayerSplitter 音频分层管理器

> **灵感**: Linly-Dubbing 使用 UVR5 / Demucs 将混合音频分离为人声与伴奏。
> 在 UrhoX 中，我们将音频资源按轨道类型进行元数据标注和独立管理。

### 数据格式: `audio-layers-v1`

```json
{
  "format": "audio-layers-v1",
  "source": "Sounds/Scene01_Mixed.ogg",
  "layers": [
    {
      "id": "voice_main",
      "type": "voice",
      "file": "Sounds/Scene01/voice_main.ogg",
      "speaker": "hero",
      "volume": 1.0,
      "pan": 0.0,
      "segments": [
        { "start": 0.0, "end": 2.5, "label": "greeting" },
        { "start": 4.0, "end": 7.2, "label": "exposition" }
      ]
    },
    {
      "id": "voice_npc",
      "type": "voice",
      "file": "Sounds/Scene01/voice_npc.ogg",
      "speaker": "merchant",
      "volume": 0.9,
      "pan": 0.3,
      "segments": [
        { "start": 2.8, "end": 3.8, "label": "response" }
      ]
    },
    {
      "id": "bgm",
      "type": "music",
      "file": "Sounds/Scene01/bgm_tavern.ogg",
      "volume": 0.4,
      "loop": true,
      "fade_in": 1.0,
      "fade_out": 2.0
    },
    {
      "id": "ambience",
      "type": "sfx",
      "file": "Sounds/Scene01/amb_crowd.ogg",
      "volume": 0.3,
      "loop": true,
      "spatial": false
    },
    {
      "id": "sfx_door",
      "type": "sfx",
      "file": "Sounds/Scene01/sfx_door.ogg",
      "volume": 0.8,
      "spatial": true,
      "position": [3.0, 0.0, 5.0],
      "segments": [
        { "start": 3.5, "end": 4.0, "label": "door_open" }
      ]
    }
  ]
}
```

### Lua 模块: `scripts/audio/AudioLayerSplitter.lua`

```lua
-- AudioLayerSplitter: 音频分层管理器
-- 灵感来源: Linly-Dubbing UVR5/Demucs 音频分离

local json = require("cjson")

local AudioLayerSplitter = {}

--- 从 JSON 文件加载音频分层配置
---@param path string 分层配置文件路径
---@return table|nil layerConfig 分层配置表
function AudioLayerSplitter.Load(path)
    local file = cache:GetFile(path)
    if not file then
        log:Error("AudioLayerSplitter: Cannot load " .. path)
        return nil
    end

    local content = file:ReadString()
    file:Close()

    local ok, config = pcall(json.decode, content)
    if not ok then
        log:Error("AudioLayerSplitter: JSON parse error in " .. path)
        return nil
    end

    if config.format ~= "audio-layers-v1" then
        log:Error("AudioLayerSplitter: Unknown format " .. tostring(config.format))
        return nil
    end

    log:Info("AudioLayerSplitter: Loaded " .. #config.layers .. " layers from " .. path)
    return config
end

--- 按类型过滤轨道
---@param config table 分层配置
---@param layerType string 轨道类型 ("voice"|"music"|"sfx")
---@return table layers 匹配的轨道列表
function AudioLayerSplitter.GetLayersByType(config, layerType)
    local result = {}
    for i = 1, #config.layers do
        if config.layers[i].type == layerType then
            result[#result + 1] = config.layers[i]
        end
    end
    return result
end

--- 按说话人过滤语音轨道
---@param config table 分层配置
---@param speakerName string 说话人名称
---@return table layers 该说话人的语音轨道
function AudioLayerSplitter.GetLayersBySpeaker(config, speakerName)
    local result = {}
    for i = 1, #config.layers do
        local layer = config.layers[i]
        if layer.type == "voice" and layer.speaker == speakerName then
            result[#result + 1] = layer
        end
    end
    return result
end

--- 获取所有说话人名称
---@param config table 分层配置
---@return table speakers 说话人名称列表
function AudioLayerSplitter.GetAllSpeakers(config)
    local seen = {}
    local result = {}
    for i = 1, #config.layers do
        local layer = config.layers[i]
        if layer.type == "voice" and layer.speaker and not seen[layer.speaker] then
            seen[layer.speaker] = true
            result[#result + 1] = layer.speaker
        end
    end
    return result
end

--- 获取场景总时长（所有轨道的最大结束时间）
---@param config table 分层配置
---@return number duration 总时长（秒）
function AudioLayerSplitter.GetTotalDuration(config)
    local maxEnd = 0
    for i = 1, #config.layers do
        local layer = config.layers[i]
        if layer.segments then
            for j = 1, #layer.segments do
                if layer.segments[j]["end"] > maxEnd then
                    maxEnd = layer.segments[j]["end"]
                end
            end
        end
    end
    return maxEnd
end

--- 获取指定时间点正在播放的所有轨道
---@param config table 分层配置
---@param time number 查询时间点（秒）
---@return table activeLayers 当前活跃轨道
function AudioLayerSplitter.GetActiveLayersAt(config, time)
    local result = {}
    for i = 1, #config.layers do
        local layer = config.layers[i]
        if layer.loop then
            -- 循环轨道始终活跃
            result[#result + 1] = layer
        elseif layer.segments then
            for j = 1, #layer.segments do
                local seg = layer.segments[j]
                if time >= seg.start and time <= seg["end"] then
                    result[#result + 1] = layer
                    break
                end
            end
        end
    end
    return result
end

--- 验证分层配置完整性
---@param config table 分层配置
---@return boolean valid, string|nil error
function AudioLayerSplitter.Validate(config)
    if not config.layers or #config.layers == 0 then
        return false, "No layers defined"
    end

    local ids = {}
    for i = 1, #config.layers do
        local layer = config.layers[i]
        if not layer.id then
            return false, "Layer " .. i .. " missing id"
        end
        if ids[layer.id] then
            return false, "Duplicate layer id: " .. layer.id
        end
        ids[layer.id] = true

        if not layer.type then
            return false, "Layer " .. layer.id .. " missing type"
        end
        if not layer.file then
            return false, "Layer " .. layer.id .. " missing file"
        end
    end

    return true, nil
end

return AudioLayerSplitter
```

---

## §3.2 Module B — SpeakerTimeline 说话人时间轴

> **灵感**: Linly-Dubbing 使用 pyannote Speaker Diarization 识别
> 混合音频中的不同说话人，并生成带时间标注的说话人段落。
> 在 UrhoX 中，我们用结构化 JSON 管理多角色对白时间轴。

### 数据格式: `speaker-timeline-v1`

```json
{
  "format": "speaker-timeline-v1",
  "scene_id": "scene_01_tavern",
  "total_duration": 15.5,
  "speakers": {
    "hero": { "display_name": "勇者", "color": "#4FC3F7" },
    "merchant": { "display_name": "商人", "color": "#FFB74D" },
    "narrator": { "display_name": "旁白", "color": "#E0E0E0" }
  },
  "segments": [
    {
      "id": "seg_001",
      "speaker": "narrator",
      "start": 0.0,
      "end": 2.0,
      "text": "勇者推开酒馆的门，走了进去。",
      "emotion": "neutral",
      "audio_file": "Sounds/Scene01/seg_001.ogg"
    },
    {
      "id": "seg_002",
      "speaker": "merchant",
      "start": 2.5,
      "end": 4.0,
      "text": "欢迎光临！需要什么？",
      "emotion": "cheerful",
      "audio_file": "Sounds/Scene01/seg_002.ogg"
    },
    {
      "id": "seg_003",
      "speaker": "hero",
      "start": 4.5,
      "end": 7.0,
      "text": "我需要一把好剑，和一些药水。",
      "emotion": "determined",
      "audio_file": "Sounds/Scene01/seg_003.ogg"
    },
    {
      "id": "seg_004",
      "speaker": "merchant",
      "start": 7.5,
      "end": 10.0,
      "text": "好剑啊……你看看这把，千年寒铁锻造的。",
      "emotion": "proud",
      "audio_file": "Sounds/Scene01/seg_004.ogg"
    },
    {
      "id": "seg_005",
      "speaker": "hero",
      "start": 10.5,
      "end": 12.0,
      "text": "多少钱？",
      "emotion": "cautious",
      "audio_file": "Sounds/Scene01/seg_005.ogg"
    }
  ]
}
```

### Lua 模块: `scripts/audio/SpeakerTimeline.lua`

```lua
-- SpeakerTimeline: 说话人时间轴管理器
-- 灵感来源: Linly-Dubbing pyannote Speaker Diarization

local json = require("cjson")

local SpeakerTimeline = {}

--- 加载说话人时间轴
---@param path string 时间轴 JSON 文件路径
---@return table|nil timeline 时间轴数据
function SpeakerTimeline.Load(path)
    local file = cache:GetFile(path)
    if not file then
        log:Error("SpeakerTimeline: Cannot load " .. path)
        return nil
    end

    local content = file:ReadString()
    file:Close()

    local ok, timeline = pcall(json.decode, content)
    if not ok then
        log:Error("SpeakerTimeline: JSON parse error in " .. path)
        return nil
    end

    if timeline.format ~= "speaker-timeline-v1" then
        log:Error("SpeakerTimeline: Unknown format " .. tostring(timeline.format))
        return nil
    end

    -- 按开始时间排序片段
    table.sort(timeline.segments, function(a, b)
        return a.start < b.start
    end)

    log:Info("SpeakerTimeline: Loaded " .. #timeline.segments .. " segments")
    return timeline
end

--- 获取指定时间点的当前说话片段
---@param timeline table 时间轴数据
---@param time number 当前时间（秒）
---@return table|nil segment 当前片段，nil 表示无人说话
function SpeakerTimeline.GetCurrentSegment(timeline, time)
    for i = 1, #timeline.segments do
        local seg = timeline.segments[i]
        if time >= seg.start and time <= seg["end"] then
            return seg
        end
    end
    return nil
end

--- 获取下一个即将播放的片段
---@param timeline table 时间轴数据
---@param time number 当前时间（秒）
---@return table|nil segment 下一个片段
---@return number|nil delay 距离下一个片段的秒数
function SpeakerTimeline.GetNextSegment(timeline, time)
    for i = 1, #timeline.segments do
        local seg = timeline.segments[i]
        if seg.start > time then
            return seg, seg.start - time
        end
    end
    return nil, nil
end

--- 获取指定说话人的所有片段
---@param timeline table 时间轴数据
---@param speakerName string 说话人名称
---@return table segments 该说话人的片段列表
function SpeakerTimeline.GetSegmentsBySpeaker(timeline, speakerName)
    local result = {}
    for i = 1, #timeline.segments do
        if timeline.segments[i].speaker == speakerName then
            result[#result + 1] = timeline.segments[i]
        end
    end
    return result
end

--- 获取指定情绪的所有片段
---@param timeline table 时间轴数据
---@param emotion string 情绪标签
---@return table segments 匹配情绪的片段列表
function SpeakerTimeline.GetSegmentsByEmotion(timeline, emotion)
    local result = {}
    for i = 1, #timeline.segments do
        if timeline.segments[i].emotion == emotion then
            result[#result + 1] = timeline.segments[i]
        end
    end
    return result
end

--- 获取说话人统计信息
---@param timeline table 时间轴数据
---@return table stats 每个说话人的统计 { name, segments, total_duration }
function SpeakerTimeline.GetSpeakerStats(timeline)
    local stats = {}
    for i = 1, #timeline.segments do
        local seg = timeline.segments[i]
        local name = seg.speaker
        if not stats[name] then
            stats[name] = { name = name, segment_count = 0, total_duration = 0 }
        end
        stats[name].segment_count = stats[name].segment_count + 1
        stats[name].total_duration = stats[name].total_duration + (seg["end"] - seg.start)
    end

    local result = {}
    for _, s in pairs(stats) do
        result[#result + 1] = s
    end
    table.sort(result, function(a, b)
        return a.total_duration > b.total_duration
    end)
    return result
end

--- 检测片段之间的间隙（静默期）
---@param timeline table 时间轴数据
---@param minGap number 最小间隙阈值（秒）
---@return table gaps 间隙列表 { start, end, duration }
function SpeakerTimeline.FindGaps(timeline, minGap)
    minGap = minGap or 0.5
    local gaps = {}
    for i = 1, #timeline.segments - 1 do
        local currentEnd = timeline.segments[i]["end"]
        local nextStart = timeline.segments[i + 1].start
        local gap = nextStart - currentEnd
        if gap >= minGap then
            gaps[#gaps + 1] = {
                start = currentEnd,
                ["end"] = nextStart,
                duration = gap
            }
        end
    end
    return gaps
end

--- 验证时间轴完整性
---@param timeline table 时间轴数据
---@return boolean valid, table|nil errors
function SpeakerTimeline.Validate(timeline)
    local errors = {}

    if not timeline.segments or #timeline.segments == 0 then
        errors[#errors + 1] = "No segments defined"
        return false, errors
    end

    local ids = {}
    for i = 1, #timeline.segments do
        local seg = timeline.segments[i]

        -- 检查必要字段
        if not seg.id then
            errors[#errors + 1] = "Segment " .. i .. " missing id"
        elseif ids[seg.id] then
            errors[#errors + 1] = "Duplicate segment id: " .. seg.id
        else
            ids[seg.id] = true
        end

        if not seg.speaker then
            errors[#errors + 1] = "Segment " .. tostring(seg.id) .. " missing speaker"
        end

        -- 检查时间有效性
        if seg.start >= seg["end"] then
            errors[#errors + 1] = "Segment " .. tostring(seg.id) .. " start >= end"
        end

        -- 检查说话人是否在注册表中
        if seg.speaker and timeline.speakers and not timeline.speakers[seg.speaker] then
            errors[#errors + 1] = "Segment " .. tostring(seg.id) .. " unknown speaker: " .. seg.speaker
        end
    end

    -- 检查时间重叠（同一说话人的片段不应重叠）
    for i = 1, #timeline.segments - 1 do
        for j = i + 1, #timeline.segments do
            local a = timeline.segments[i]
            local b = timeline.segments[j]
            if a.speaker == b.speaker then
                if a.start < b["end"] and b.start < a["end"] then
                    errors[#errors + 1] = "Overlapping: " ..
                        tostring(a.id) .. " and " .. tostring(b.id)
                end
            end
        end
    end

    return #errors == 0, #errors > 0 and errors or nil
end

return SpeakerTimeline
```

---

## §3.3 Module C — VoiceProfileRegistry 角色声音档案注册表

> **灵感**: Linly-Dubbing 使用 CosyVoice / GPT-SoVITS 进行语音克隆，
> 只需 3-10 秒原始音频即可创建声音档案。在 UrhoX 中，我们建立
> 结构化的角色声音档案注册表，用于管理 ElevenLabs 语音和一致性控制。

### 数据格式: `voice-profiles-v1`

```json
{
  "format": "voice-profiles-v1",
  "profiles": {
    "hero": {
      "display_name": "勇者·艾尔",
      "gender": "male",
      "age_range": "20-30",
      "voice_engine": "elevenlabs",
      "voice_id": "hero_voice_001",
      "description": "Young adult male, warm and determined tone, moderate pace",
      "default_stability": 0.6,
      "default_similarity": 0.8,
      "emotion_presets": {
        "neutral": { "stability": 0.7, "style": 0.3 },
        "angry": { "stability": 0.3, "style": 0.8 },
        "sad": { "stability": 0.8, "style": 0.5 },
        "excited": { "stability": 0.4, "style": 0.7 },
        "whisper": { "stability": 0.9, "style": 0.2 }
      },
      "sample_audio": "Sounds/VoiceSamples/hero_sample.ogg",
      "locale_variants": {
        "zh": { "voice_id": "hero_zh_001" },
        "en": { "voice_id": "hero_en_001" },
        "ja": { "voice_id": "hero_ja_001" }
      },
      "tags": ["protagonist", "warrior"]
    },
    "merchant": {
      "display_name": "商人·巴尔",
      "gender": "male",
      "age_range": "40-50",
      "voice_engine": "elevenlabs",
      "voice_id": "merchant_voice_001",
      "description": "Middle-aged male, raspy and enthusiastic, fast-paced",
      "default_stability": 0.5,
      "default_similarity": 0.75,
      "emotion_presets": {
        "neutral": { "stability": 0.6, "style": 0.4 },
        "cheerful": { "stability": 0.4, "style": 0.7 },
        "suspicious": { "stability": 0.7, "style": 0.6 }
      },
      "sample_audio": "Sounds/VoiceSamples/merchant_sample.ogg",
      "locale_variants": {
        "zh": { "voice_id": "merchant_zh_001" },
        "en": { "voice_id": "merchant_en_001" }
      },
      "tags": ["npc", "shop"]
    }
  }
}
```

### Lua 模块: `scripts/audio/VoiceProfileRegistry.lua`

```lua
-- VoiceProfileRegistry: 角色声音档案注册表
-- 灵感来源: Linly-Dubbing CosyVoice/GPT-SoVITS 语音克隆

local json = require("cjson")

local VoiceProfileRegistry = {}

--- 加载声音档案注册表
---@param path string 档案 JSON 文件路径
---@return table|nil registry 注册表数据
function VoiceProfileRegistry.Load(path)
    local file = cache:GetFile(path)
    if not file then
        log:Error("VoiceProfileRegistry: Cannot load " .. path)
        return nil
    end

    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(json.decode, content)
    if not ok then
        log:Error("VoiceProfileRegistry: JSON parse error in " .. path)
        return nil
    end

    if data.format ~= "voice-profiles-v1" then
        log:Error("VoiceProfileRegistry: Unknown format " .. tostring(data.format))
        return nil
    end

    local count = 0
    for _ in pairs(data.profiles) do count = count + 1 end
    log:Info("VoiceProfileRegistry: Loaded " .. count .. " voice profiles")
    return data
end

--- 获取角色的声音档案
---@param registry table 注册表数据
---@param characterName string 角色标识符
---@return table|nil profile 声音档案
function VoiceProfileRegistry.GetProfile(registry, characterName)
    return registry.profiles[characterName]
end

--- 获取角色的情绪预设参数
---@param registry table 注册表数据
---@param characterName string 角色标识符
---@param emotion string 情绪名称
---@return table|nil preset 情绪参数 { stability, style, ... }
function VoiceProfileRegistry.GetEmotionPreset(registry, characterName, emotion)
    local profile = registry.profiles[characterName]
    if not profile then return nil end
    if not profile.emotion_presets then return nil end
    return profile.emotion_presets[emotion]
end

--- 获取角色的本地化语音 ID
---@param registry table 注册表数据
---@param characterName string 角色标识符
---@param locale string 语言代码 ("zh", "en", "ja" 等)
---@return string|nil voiceId 该语言的语音 ID
function VoiceProfileRegistry.GetLocaleVoiceId(registry, characterName, locale)
    local profile = registry.profiles[characterName]
    if not profile then return nil end
    if profile.locale_variants and profile.locale_variants[locale] then
        return profile.locale_variants[locale].voice_id
    end
    -- 回退到默认 voice_id
    return profile.voice_id
end

--- 按标签搜索角色
---@param registry table 注册表数据
---@param tag string 标签
---@return table profiles 匹配的角色列表 { name, profile }
function VoiceProfileRegistry.FindByTag(registry, tag)
    local result = {}
    for name, profile in pairs(registry.profiles) do
        if profile.tags then
            for i = 1, #profile.tags do
                if profile.tags[i] == tag then
                    result[#result + 1] = { name = name, profile = profile }
                    break
                end
            end
        end
    end
    return result
end

--- 生成 ElevenLabs TTS 调用参数
---@param registry table 注册表数据
---@param characterName string 角色标识符
---@param text string 对白文本
---@param emotion string|nil 情绪（可选）
---@param locale string|nil 语言（可选）
---@return table|nil params TTS 参数表
function VoiceProfileRegistry.BuildTTSParams(registry, characterName, text, emotion, locale)
    local profile = registry.profiles[characterName]
    if not profile then
        log:Error("VoiceProfileRegistry: Unknown character: " .. characterName)
        return nil
    end

    local voiceId = locale
        and VoiceProfileRegistry.GetLocaleVoiceId(registry, characterName, locale)
        or profile.voice_id

    local stability = profile.default_stability or 0.5

    if emotion and profile.emotion_presets and profile.emotion_presets[emotion] then
        local preset = profile.emotion_presets[emotion]
        stability = preset.stability or stability
    end

    return {
        character_name = characterName,
        text = text,
        voice_id = voiceId,
        stability = stability,
    }
end

--- 列出所有已注册角色
---@param registry table 注册表数据
---@return table names 角色名称列表
function VoiceProfileRegistry.ListCharacters(registry)
    local result = {}
    for name, _ in pairs(registry.profiles) do
        result[#result + 1] = name
    end
    table.sort(result)
    return result
end

return VoiceProfileRegistry
```

---

## §3.4 Module D — TrackMixer 多轨混音器

> **灵感**: Linly-Dubbing 在替换人声后保留原始背景音乐，
> 通过 UVR5 分离并重新混合音轨。在 UrhoX 中，
> 我们实现基于时间轴的多轨音频混音器，支持音量包络曲线。

### Lua 模块: `scripts/audio/TrackMixer.lua`

```lua
-- TrackMixer: 多轨混音与音量包络管理器
-- 灵感来源: Linly-Dubbing BGM 保留与多轨混合

local TrackMixer = {}

---@class TrackState
---@field id string 轨道 ID
---@field layer table 轨道配置
---@field soundSource SoundSource|SoundSource3D 音频源组件
---@field baseVolume number 基础音量
---@field currentVolume number 当前音量
---@field fadeTarget number|nil 淡变目标音量
---@field fadeSpeed number|nil 淡变速度
---@field ducking boolean 是否被压低
---@field duckVolume number 压低时的音量比例

--- 创建混音器实例
---@param scene Scene 场景
---@return table mixer 混音器实例
function TrackMixer.Create(scene)
    local mixer = {
        scene_ = scene,
        tracks_ = {},           -- id → TrackState
        masterVolume_ = 1.0,
        duckAmount_ = 0.3,      -- 语音播放时 BGM 压低到 30%
        duckRecoverSpeed_ = 2.0 -- 恢复速度
    }

    setmetatable(mixer, { __index = TrackMixer })
    return mixer
end

--- 添加一条音轨
---@param self table 混音器实例
---@param layer table 轨道配置（来自 AudioLayerSplitter）
---@return boolean success
function TrackMixer.AddTrack(self, layer)
    if self.tracks_[layer.id] then
        log:Warning("TrackMixer: Track already exists: " .. layer.id)
        return false
    end

    local node = self.scene_:CreateChild("AudioTrack_" .. layer.id)
    local soundSource

    if layer.spatial and layer.position then
        soundSource = node:CreateComponent("SoundSource3D")
        node.position = Vector3(
            layer.position[1] or 0,
            layer.position[2] or 0,
            layer.position[3] or 0
        )
        soundSource.nearDistance = 1.0
        soundSource.farDistance = 50.0
    else
        soundSource = node:CreateComponent("SoundSource")
    end

    local volume = layer.volume or 1.0
    soundSource.gain = volume * self.masterVolume_

    if layer.type == "music" then
        soundSource.soundType = SOUND_MUSIC
    elseif layer.type == "voice" then
        soundSource.soundType = SOUND_VOICE
    else
        soundSource.soundType = SOUND_EFFECT
    end

    self.tracks_[layer.id] = {
        id = layer.id,
        layer = layer,
        soundSource = soundSource,
        node = node,
        baseVolume = volume,
        currentVolume = volume,
        fadeTarget = nil,
        fadeSpeed = nil,
        ducking = false,
        duckVolume = 1.0
    }

    log:Info("TrackMixer: Added track " .. layer.id .. " (" .. layer.type .. ")")
    return true
end

--- 播放指定轨道
---@param self table 混音器实例
---@param trackId string 轨道 ID
---@param looping boolean|nil 是否循环
function TrackMixer.Play(self, trackId, looping)
    local track = self.tracks_[trackId]
    if not track then
        log:Error("TrackMixer: Unknown track: " .. trackId)
        return
    end

    local sound = cache:GetResource("Sound", track.layer.file)
    if not sound then
        log:Error("TrackMixer: Cannot load sound: " .. track.layer.file)
        return
    end

    if looping == nil then
        looping = track.layer.loop or false
    end
    sound.looped = looping
    track.soundSource:Play(sound)

    -- 淡入效果
    if track.layer.fade_in and track.layer.fade_in > 0 then
        track.soundSource.gain = 0
        track.currentVolume = 0
        TrackMixer.FadeTo(self, trackId, track.baseVolume, track.layer.fade_in)
    end
end

--- 停止指定轨道
---@param self table 混音器实例
---@param trackId string 轨道 ID
---@param fadeOut number|nil 淡出时长（秒），nil 表示立即停止
function TrackMixer.Stop(self, trackId, fadeOut)
    local track = self.tracks_[trackId]
    if not track then return end

    if fadeOut and fadeOut > 0 then
        track.fadeTarget = 0
        track.fadeSpeed = track.currentVolume / fadeOut
        track.stopAfterFade = true
    else
        track.soundSource:Stop()
    end
end

--- 淡变到目标音量
---@param self table 混音器实例
---@param trackId string 轨道 ID
---@param targetVolume number 目标音量 (0.0-1.0)
---@param duration number 过渡时长（秒）
function TrackMixer.FadeTo(self, trackId, targetVolume, duration)
    local track = self.tracks_[trackId]
    if not track then return end

    if duration <= 0 then
        track.currentVolume = targetVolume
        track.soundSource.gain = targetVolume * self.masterVolume_ * track.duckVolume
        return
    end

    track.fadeTarget = targetVolume
    track.fadeSpeed = math.abs(targetVolume - track.currentVolume) / duration
end

--- 语音闪避（Voice Ducking）：当语音播放时压低 BGM
---@param self table 混音器实例
---@param voiceActive boolean 语音是否正在播放
function TrackMixer.SetVoiceDucking(self, voiceActive)
    for _, track in pairs(self.tracks_) do
        if track.layer.type == "music" or track.layer.type == "sfx" then
            if voiceActive and not track.ducking then
                track.ducking = true
                track.duckVolume = self.duckAmount_
            elseif not voiceActive and track.ducking then
                track.ducking = false
                -- duckVolume 会在 Update 中渐进恢复
            end
        end
    end
end

--- 设置主音量
---@param self table 混音器实例
---@param volume number 主音量 (0.0-1.0)
function TrackMixer.SetMasterVolume(self, volume)
    self.masterVolume_ = math.max(0, math.min(1, volume))
end

--- 每帧更新（处理淡变和闪避恢复）
---@param self table 混音器实例
---@param dt number 帧间隔（秒）
function TrackMixer.Update(self, dt)
    for _, track in pairs(self.tracks_) do
        -- 处理音量淡变
        if track.fadeTarget then
            if track.currentVolume < track.fadeTarget then
                track.currentVolume = math.min(
                    track.currentVolume + track.fadeSpeed * dt,
                    track.fadeTarget
                )
            else
                track.currentVolume = math.max(
                    track.currentVolume - track.fadeSpeed * dt,
                    track.fadeTarget
                )
            end

            if math.abs(track.currentVolume - track.fadeTarget) < 0.001 then
                track.currentVolume = track.fadeTarget
                track.fadeTarget = nil
                if track.stopAfterFade then
                    track.soundSource:Stop()
                    track.stopAfterFade = false
                end
            end
        end

        -- 处理闪避恢复
        if not track.ducking and track.duckVolume < 1.0 then
            track.duckVolume = math.min(
                track.duckVolume + self.duckRecoverSpeed_ * dt,
                1.0
            )
        end

        -- 应用最终音量
        track.soundSource.gain = track.currentVolume * self.masterVolume_ * track.duckVolume
    end
end

--- 获取所有轨道状态（用于调试 UI）
---@param self table 混音器实例
---@return table trackStates 轨道状态列表
function TrackMixer.GetTrackStates(self)
    local result = {}
    for id, track in pairs(self.tracks_) do
        result[#result + 1] = {
            id = id,
            type = track.layer.type,
            volume = track.currentVolume,
            ducking = track.ducking,
            duckVolume = track.duckVolume,
            playing = track.soundSource.playing
        }
    end
    return result
end

return TrackMixer
```

---

## §3.5 Module E — LocaleVariantManager 多语言音频变体管理

> **灵感**: Linly-Dubbing 的核心功能是将视频从一种语言翻译配音到另一种语言。
> 在 UrhoX 中，我们管理同一对白在不同语言下的音频文件变体。

### Lua 模块: `scripts/audio/LocaleVariantManager.lua`

```lua
-- LocaleVariantManager: 多语言音频变体管理器
-- 灵感来源: Linly-Dubbing 多语言翻译与配音

local json = require("cjson")

local LocaleVariantManager = {}

--- 创建变体管理器实例
---@param defaultLocale string 默认语言代码
---@return table manager 管理器实例
function LocaleVariantManager.Create(defaultLocale)
    local manager = {
        currentLocale_ = defaultLocale or "zh",
        variants_ = {},     -- segmentId → { locale → audioFile }
        fallbackLocale_ = defaultLocale or "zh"
    }
    setmetatable(manager, { __index = LocaleVariantManager })
    return manager
end

--- 注册一个对白的多语言变体
---@param self table 管理器实例
---@param segmentId string 对白片段 ID
---@param locale string 语言代码
---@param audioFile string 音频文件路径
function LocaleVariantManager.Register(self, segmentId, locale, audioFile)
    if not self.variants_[segmentId] then
        self.variants_[segmentId] = {}
    end
    self.variants_[segmentId][locale] = audioFile
end

--- 批量从 JSON 加载变体映射
---@param self table 管理器实例
---@param path string JSON 文件路径
---@return boolean success
function LocaleVariantManager.LoadFromFile(self, path)
    local file = cache:GetFile(path)
    if not file then
        log:Error("LocaleVariantManager: Cannot load " .. path)
        return false
    end

    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(json.decode, content)
    if not ok then
        log:Error("LocaleVariantManager: JSON parse error in " .. path)
        return false
    end

    -- 格式: { "seg_001": { "zh": "path.ogg", "en": "path.ogg" }, ... }
    for segId, locales in pairs(data) do
        for locale, audioFile in pairs(locales) do
            LocaleVariantManager.Register(self, segId, locale, audioFile)
        end
    end

    local count = 0
    for _ in pairs(self.variants_) do count = count + 1 end
    log:Info("LocaleVariantManager: Loaded variants for " .. count .. " segments")
    return true
end

--- 获取当前语言下的音频文件路径
---@param self table 管理器实例
---@param segmentId string 对白片段 ID
---@return string|nil audioFile 音频文件路径
function LocaleVariantManager.GetAudioFile(self, segmentId)
    local variants = self.variants_[segmentId]
    if not variants then return nil end

    -- 优先当前语言
    if variants[self.currentLocale_] then
        return variants[self.currentLocale_]
    end

    -- 回退到默认语言
    if variants[self.fallbackLocale_] then
        log:Warning("LocaleVariantManager: Fallback to " ..
            self.fallbackLocale_ .. " for " .. segmentId)
        return variants[self.fallbackLocale_]
    end

    -- 返回任意可用语言
    for _, audioFile in pairs(variants) do
        return audioFile
    end

    return nil
end

--- 切换当前语言
---@param self table 管理器实例
---@param locale string 新语言代码
function LocaleVariantManager.SetLocale(self, locale)
    self.currentLocale_ = locale
    log:Info("LocaleVariantManager: Switched to locale: " .. locale)
end

--- 获取指定片段的所有可用语言
---@param self table 管理器实例
---@param segmentId string 对白片段 ID
---@return table locales 可用语言列表
function LocaleVariantManager.GetAvailableLocales(self, segmentId)
    local variants = self.variants_[segmentId]
    if not variants then return {} end

    local result = {}
    for locale, _ in pairs(variants) do
        result[#result + 1] = locale
    end
    table.sort(result)
    return result
end

--- 检查本地化覆盖率
---@param self table 管理器实例
---@param locale string 目标语言
---@return number coverage 覆盖率 (0.0-1.0)
---@return table missing 缺失的片段 ID 列表
function LocaleVariantManager.CheckCoverage(self, locale)
    local total = 0
    local covered = 0
    local missing = {}

    for segId, variants in pairs(self.variants_) do
        total = total + 1
        if variants[locale] then
            covered = covered + 1
        else
            missing[#missing + 1] = segId
        end
    end

    if total == 0 then return 1.0, {} end
    return covered / total, missing
end

return LocaleVariantManager
```

---

## §3.6 Module F — PipelineOrchestrator 管线编排器

> **灵感**: Linly-Dubbing 的完整工作流将 ASR → 翻译 → TTS → 混音
> 串联为自动化管线。在 UrhoX 中，编排器将以上所有模块串联为可配置的处理流程。

### Lua 模块: `scripts/audio/PipelineOrchestrator.lua`

```lua
-- PipelineOrchestrator: 智能音频管线编排器
-- 灵感来源: Linly-Dubbing 端到端自动化管线

local AudioLayerSplitter = require("scripts/audio/AudioLayerSplitter")
local SpeakerTimeline = require("scripts/audio/SpeakerTimeline")
local VoiceProfileRegistry = require("scripts/audio/VoiceProfileRegistry")
local TrackMixer = require("scripts/audio/TrackMixer")
local LocaleVariantManager = require("scripts/audio/LocaleVariantManager")

local PipelineOrchestrator = {}

---@class PipelineConfig
---@field layers_path string 音频分层配置路径
---@field timeline_path string 说话人时间轴路径
---@field profiles_path string 声音档案路径
---@field variants_path string|nil 多语言变体路径（可选）
---@field default_locale string 默认语言
---@field auto_duck boolean 是否自动执行语音闪避

--- 创建管线实例
---@param scene Scene 场景
---@param config PipelineConfig 管线配置
---@return table|nil pipeline 管线实例
function PipelineOrchestrator.Create(scene, config)
    -- 加载各模块数据
    local layers = AudioLayerSplitter.Load(config.layers_path)
    if not layers then return nil end

    local timeline = SpeakerTimeline.Load(config.timeline_path)
    if not timeline then return nil end

    local profiles = VoiceProfileRegistry.Load(config.profiles_path)
    if not profiles then return nil end

    -- 验证数据完整性
    local layersOk, layersErr = AudioLayerSplitter.Validate(layers)
    if not layersOk then
        log:Error("PipelineOrchestrator: Layer validation failed - " .. layersErr)
        return nil
    end

    local timelineOk, timelineErrs = SpeakerTimeline.Validate(timeline)
    if not timelineOk then
        for i = 1, #timelineErrs do
            log:Error("PipelineOrchestrator: Timeline error - " .. timelineErrs[i])
        end
        return nil
    end

    -- 创建混音器
    local mixer = TrackMixer.Create(scene)

    -- 添加所有轨道到混音器
    for i = 1, #layers.layers do
        mixer:AddTrack(layers.layers[i])
    end

    -- 创建本地化管理器
    local localeManager = LocaleVariantManager.Create(config.default_locale or "zh")
    if config.variants_path then
        localeManager:LoadFromFile(config.variants_path)
    end

    local pipeline = {
        scene_ = scene,
        layers_ = layers,
        timeline_ = timeline,
        profiles_ = profiles,
        mixer_ = mixer,
        localeManager_ = localeManager,
        config_ = config,

        -- 回放状态
        playing_ = false,
        playbackTime_ = 0,
        currentSegment_ = nil,
        lastSegmentId_ = nil,
    }

    setmetatable(pipeline, { __index = PipelineOrchestrator })
    log:Info("PipelineOrchestrator: Pipeline created successfully")
    return pipeline
end

--- 开始回放
---@param self table 管线实例
function PipelineOrchestrator.StartPlayback(self)
    self.playing_ = true
    self.playbackTime_ = 0
    self.currentSegment_ = nil
    self.lastSegmentId_ = nil

    -- 播放所有循环轨道（BGM、环境音）
    for i = 1, #self.layers_.layers do
        local layer = self.layers_.layers[i]
        if layer.loop then
            self.mixer_:Play(layer.id, true)
        end
    end

    log:Info("PipelineOrchestrator: Playback started")
end

--- 暂停回放
---@param self table 管线实例
function PipelineOrchestrator.PausePlayback(self)
    self.playing_ = false
end

--- 恢复回放
---@param self table 管线实例
function PipelineOrchestrator.ResumePlayback(self)
    self.playing_ = true
end

--- 停止回放
---@param self table 管线实例
function PipelineOrchestrator.StopPlayback(self)
    self.playing_ = false
    self.playbackTime_ = 0
    self.currentSegment_ = nil
    self.lastSegmentId_ = nil

    -- 停止所有轨道
    for id, _ in pairs(self.mixer_.tracks_) do
        self.mixer_:Stop(id, 0.5)
    end
end

--- 每帧更新
---@param self table 管线实例
---@param dt number 帧间隔（秒）
---@return table|nil currentSegment 当前正在播放的对白片段
function PipelineOrchestrator.Update(self, dt)
    if not self.playing_ then return nil end

    self.playbackTime_ = self.playbackTime_ + dt

    -- 获取当前对白片段
    local segment = SpeakerTimeline.GetCurrentSegment(self.timeline_, self.playbackTime_)

    -- 新片段开始播放
    if segment and segment.id ~= self.lastSegmentId_ then
        self.currentSegment_ = segment
        self.lastSegmentId_ = segment.id

        -- 获取当前语言的音频文件
        local audioFile = self.localeManager_:GetAudioFile(segment.id)
        if not audioFile then
            audioFile = segment.audio_file  -- 回退到时间轴中的默认音频
        end

        -- 播放对白音频
        if audioFile then
            local voiceLayerId = "voice_" .. segment.speaker
            -- 查找或创建语音轨道
            if not self.mixer_.tracks_[voiceLayerId] then
                self.mixer_:AddTrack({
                    id = voiceLayerId,
                    type = "voice",
                    file = audioFile,
                    volume = 1.0,
                    speaker = segment.speaker
                })
            end
            -- 更新音频文件并播放
            self.mixer_.tracks_[voiceLayerId].layer.file = audioFile
            self.mixer_:Play(voiceLayerId, false)
        end

        -- 语音闪避
        if self.config_.auto_duck then
            self.mixer_:SetVoiceDucking(true)
        end

        log:Info("PipelineOrchestrator: Playing " .. segment.id ..
            " [" .. segment.speaker .. "] " .. (segment.text or ""))
    end

    -- 当前片段结束
    if self.currentSegment_ and self.playbackTime_ > self.currentSegment_["end"] then
        if self.config_.auto_duck then
            self.mixer_:SetVoiceDucking(false)
        end
        self.currentSegment_ = nil
    end

    -- 检查回放是否结束
    local totalDuration = AudioLayerSplitter.GetTotalDuration(self.layers_)
    if self.playbackTime_ > totalDuration + 1.0 then
        PipelineOrchestrator.StopPlayback(self)
        log:Info("PipelineOrchestrator: Playback finished")
    end

    -- 更新混音器
    self.mixer_:Update(dt)

    return self.currentSegment_
end

--- 切换语言（运行时）
---@param self table 管线实例
---@param locale string 新语言代码
function PipelineOrchestrator.SwitchLocale(self, locale)
    self.localeManager_:SetLocale(locale)
    log:Info("PipelineOrchestrator: Locale switched to " .. locale)
end

--- 获取当前管线状态（用于调试 UI）
---@param self table 管线实例
---@return table pipelineState 管线状态
function PipelineOrchestrator.GetState(self)
    return {
        playing = self.playing_,
        time = self.playbackTime_,
        locale = self.localeManager_.currentLocale_,
        current_segment = self.currentSegment_,
        tracks = self.mixer_:GetTrackStates()
    }
end

--- 导出时间轴为 JSON（用于持久化或调试）
---@param self table 管线实例
---@return string jsonString JSON 字符串
function PipelineOrchestrator.ExportTimelineJSON(self)
    return json.encode(self.timeline_)
end

return PipelineOrchestrator
```

---

## §4 完整集成示例

### `scripts/main.lua` — 游戏入口

```lua
-- main.lua: 智能音频管线集成示例
-- 展示如何将所有音频模块串联为完整的场景对白系统

require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")
local PipelineOrchestrator = require("scripts/audio/PipelineOrchestrator")

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local pipeline_ = nil
local subtitleText_ = nil

function Start()
    SampleStart()

    -- 创建简单 3D 场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-100, -100, -100), Vector3(100, 100, 100))
    zone.ambientColor = Color(0.3, 0.3, 0.4)

    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    cameraNode_.position = Vector3(0, 5, -10)
    cameraNode_:LookAt(Vector3(0, 2, 0))

    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- 创建音频管线
    pipeline_ = PipelineOrchestrator.Create(scene_, {
        layers_path = "data/scene01_layers.json",
        timeline_path = "data/scene01_timeline.json",
        profiles_path = "data/voice_profiles.json",
        variants_path = "data/locale_variants.json",
        default_locale = "zh",
        auto_duck = true
    })

    if pipeline_ then
        log:Info("Audio pipeline created successfully")
    else
        log:Error("Failed to create audio pipeline")
        return
    end

    -- 创建 UI
    SetupUI()

    SubscribeToEvent("Update", "HandleUpdate")
end

function SetupUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    local root = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "flex-end",
        children = {
            -- 控制面板
            UI.Panel {
                flexDirection = "row", padding = 10, gap = 8,
                justifyContent = "center",
                children = {
                    UI.Button {
                        text = "Play", variant = "primary",
                        onClick = function()
                            if pipeline_ then pipeline_:StartPlayback() end
                        end
                    },
                    UI.Button {
                        text = "Pause",
                        onClick = function()
                            if pipeline_ then pipeline_:PausePlayback() end
                        end
                    },
                    UI.Button {
                        text = "Stop",
                        onClick = function()
                            if pipeline_ then pipeline_:StopPlayback() end
                        end
                    },
                    UI.Button {
                        text = "EN",
                        onClick = function()
                            if pipeline_ then pipeline_:SwitchLocale("en") end
                        end
                    },
                    UI.Button {
                        text = "ZH",
                        onClick = function()
                            if pipeline_ then pipeline_:SwitchLocale("zh") end
                        end
                    },
                }
            },
            -- 字幕区域
            UI.Panel {
                width = "100%", height = 80,
                justifyContent = "center", alignItems = "center",
                backgroundColor = "#000000AA",
                children = {
                    UI.Label {
                        id = "subtitle",
                        text = "",
                        fontSize = 20,
                        color = "#FFFFFF"
                    }
                }
            }
        }
    }
    UI.SetRoot(root)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    if pipeline_ then
        local segment = pipeline_:Update(dt)

        -- 更新字幕
        local subtitleLabel = UI.FindById("subtitle")
        if subtitleLabel then
            if segment and segment.text then
                local speakerInfo = pipeline_.timeline_.speakers[segment.speaker]
                local displayName = speakerInfo and speakerInfo.display_name or segment.speaker
                subtitleLabel:SetText("[" .. displayName .. "] " .. segment.text)
            else
                subtitleLabel:SetText("")
            end
        end
    end
end
```

---

## §5 数据文件组织

### 推荐目录结构

```
scripts/
├── main.lua                          # 游戏入口
├── audio/                            # 音频管线模块
│   ├── AudioLayerSplitter.lua        # 音频分层管理器
│   ├── SpeakerTimeline.lua           # 说话人时间轴
│   ├── VoiceProfileRegistry.lua      # 声音档案注册表
│   ├── TrackMixer.lua                # 多轨混音器
│   ├── LocaleVariantManager.lua      # 多语言变体管理
│   └── PipelineOrchestrator.lua      # 管线编排器
├── data/                             # 音频配置数据
│   ├── scene01_layers.json           # 场景 1 分层配置
│   ├── scene01_timeline.json         # 场景 1 说话人时间轴
│   ├── voice_profiles.json           # 角色声音档案
│   └── locale_variants.json          # 多语言音频映射
assets/
├── Sounds/
│   ├── Scene01/                      # 场景 1 分轨音频
│   │   ├── voice_main.ogg            # 主角语音轨
│   │   ├── voice_npc.ogg             # NPC 语音轨
│   │   ├── bgm_tavern.ogg            # 背景音乐轨
│   │   ├── amb_crowd.ogg             # 环境音轨
│   │   └── sfx_door.ogg              # 音效轨
│   ├── Scene01_en/                   # 场景 1 英文语音
│   │   ├── seg_001.ogg
│   │   └── ...
│   └── VoiceSamples/                 # 角色声音样本
│       ├── hero_sample.ogg
│       └── merchant_sample.ogg
```

---

## §6 高级功能

### 6.1 音频分析可视化

```lua
-- 在调试面板中显示音频轨道状态
function DrawAudioDebugPanel(pipeline)
    local pipelineState = pipeline:GetState()

    -- 显示当前回放时间
    print(string.format("Time: %.1fs | Locale: %s | Playing: %s",
        pipelineState.time,
        pipelineState.locale,
        tostring(pipelineState.playing)))

    -- 显示各轨道音量
    for i = 1, #pipelineState.tracks do
        local track = pipelineState.tracks[i]
        local bar = string.rep("█", math.floor(track.volume * 20))
        print(string.format("  [%s] %s %.0f%% %s",
            track.type,
            track.id,
            track.volume * 100,
            bar))
    end
end
```

### 6.2 与 cinematic-dub-pipeline 协作

```lua
-- 本 Skill 的分析结果可以导入 cinematic-dub-pipeline

-- 1. 用 AudioLayerSplitter 分析现有混合音频
local layers = AudioLayerSplitter.Load("data/existing_cutscene_layers.json")

-- 2. 用 SpeakerTimeline 标注说话人
local timeline = SpeakerTimeline.Load("data/existing_cutscene_timeline.json")

-- 3. 用 VoiceProfileRegistry 建立声音档案
local profiles = VoiceProfileRegistry.Load("data/voice_profiles.json")

-- 4. 将分析结果传递给 cinematic-dub-pipeline 进行重新配音
-- （由 cinematic-dub-pipeline 处理：翻译 → TTS → 字幕 → 合成）
```

### 6.3 动态音量曲线

```lua
-- 根据游戏事件动态调整音轨音量
function OnBattleStart()
    mixer:FadeTo("bgm", 0.2, 1.5)          -- BGM 压低
    mixer:FadeTo("ambience", 0.1, 1.0)     -- 环境音压低
end

function OnBattleEnd()
    mixer:FadeTo("bgm", 0.6, 2.0)          -- BGM 恢复
    mixer:FadeTo("ambience", 0.3, 1.5)     -- 环境音恢复
end

function OnDialogueStart()
    mixer:SetVoiceDucking(true)             -- 自动压低非语音轨道
end

function OnDialogueEnd()
    mixer:SetVoiceDucking(false)            -- 恢复
end
```

---

## §7 与 Linly-Dubbing 的对比

| 维度 | Linly-Dubbing | Smart Audio Pipeline |
|------|--------------|---------------------|
| 运行环境 | Python + CUDA | UrhoX Lua 运行时 |
| 音频分离 | UVR5/Demucs 实时分离 | 预处理后的分轨元数据管理 |
| 说话人识别 | pyannote 自动识别 | 预标注的说话人时间轴 |
| 语音克隆 | CosyVoice/GPT-SoVITS | ElevenLabs Voice Design API |
| ASR | WhisperX/FunASR | 预提取的对白文本 + 时间戳 |
| 翻译 | Qwen/GPT API | 预翻译的多语言文本 |
| TTS | Edge TTS/XTTS/CosyVoice | ElevenLabs text_to_dialogue |
| 混音 | ffmpeg | Lua TrackMixer（运行时多轨管理） |
| 唇形同步 | Linly-Talker 数字人 | 引擎动画系统（见 cinematic-dub-pipeline） |
| 字幕 | SRT 文件导出 | UI 组件实时渲染 |
| 部署 | 本地 GPU 服务器 | 游戏客户端内嵌 |

**核心差异**: Linly-Dubbing 是**离线处理工具**（重计算、高精度），
Smart Audio Pipeline 是**运行时管理系统**（轻量、实时、游戏内集成）。
Linly-Dubbing 的分析结果（分轨音频、说话人标注、时间戳）可作为本 Skill 的输入数据。

---

## §8 状态持久化

### 保存和恢复管线状态

```lua
local json = require("cjson")

--- 保存管线状态到文件
---@param pipeline table 管线实例
---@param savePath string 存档路径
function SavePipelineState(pipeline, savePath)
    local pipelineState = pipeline:GetState()

    local saveData = {
        format = "audio-state-v1",
        timestamp = os.clock(),
        playback_time = pipelineState.time,
        locale = pipelineState.locale,
        playing = pipelineState.playing,
        track_volumes = {}
    }

    for i = 1, #pipelineState.tracks do
        local track = pipelineState.tracks[i]
        saveData.track_volumes[track.id] = track.volume
    end

    local saveFile = File:new(savePath, FILE_WRITE)
    if saveFile then
        saveFile:WriteString(json.encode(saveData))
        saveFile:Close()
        log:Info("Pipeline state saved to " .. savePath)
    end
end

--- 从文件恢复管线状态
---@param pipeline table 管线实例
---@param savePath string 存档路径
function LoadPipelineState(pipeline, savePath)
    local file = File:new(savePath, FILE_READ)
    if not file then
        log:Warning("No saved state found at " .. savePath)
        return
    end

    local content = file:ReadString()
    file:Close()

    local ok, saveData = pcall(json.decode, content)
    if not ok then
        log:Error("Failed to parse saved state")
        return
    end

    if saveData.format ~= "audio-state-v1" then
        log:Error("Unknown save format: " .. tostring(saveData.format))
        return
    end

    -- 恢复语言
    pipeline:SwitchLocale(saveData.locale)

    -- 恢复轨道音量
    if saveData.track_volumes then
        for trackId, volume in pairs(saveData.track_volumes) do
            pipeline.mixer_:FadeTo(trackId, volume, 0)
        end
    end

    log:Info("Pipeline state restored from " .. savePath)
end
```

---

## §9 规则与约束

### 引擎规则遵守清单

| 规则 | 状态 | 说明 |
|------|------|------|
| 代码存放在 `scripts/` 目录 | 遵守 | 所有 Lua 模块在 `scripts/audio/` |
| 使用 UrhoX MCP 构建工具 | 遵守 | 每次修改后调用 build |
| 不使用 `graphics:SetModel` 以外的 SetMode | 遵守 | 纯音频管线，不涉及渲染设置 |
| 不写入 dist 目录 | 遵守 | 仅操作 `scripts/` 和 `assets/` |
| 不使用 Lua 原生文件库 | 遵守 | 使用 `cache:GetFile()` 和 `File` API |
| 不使用系统命令执行 | 遵守 | 纯 Lua 实现 |
| JSON 使用 cjson | 遵守 | `require("cjson")` |
| UI 使用新系统 | 遵守 | `urhox-libs/UI` 组件 |
| 数组索引从 1 开始 | 遵守 | 所有循环 `for i = 1, #arr do` |
| 单位为米 | 遵守 | 3D 空间音频位置使用米制单位 |
| 存档使用 File API | 遵守 | `File:new(path, FILE_WRITE/FILE_READ)` |

---

## §10 FAQ

### Q1: 与 cinematic-dub-pipeline 有什么区别？

**cinematic-dub-pipeline** 是「正向创作管线」：
- 从剧本开始 → 翻译 → 语音合成 → 字幕 → 过场播放
- 聚焦于**生产新的配音内容**

**smart-audio-pipeline** 是「逆向分析+运行时管理管线」：
- 从已有音频开始 → 分层管理 → 说话人标注 → 混音控制 → 多语言切换
- 聚焦于**管理已有音频资产**和**运行时音频控制**

两者互补：smart-audio-pipeline 的分析结果可作为 cinematic-dub-pipeline 的输入。

### Q2: 音频分离是在游戏运行时实时执行的吗？

不是。音频分离（类比 UVR5/Demucs）是在**资产预处理阶段**完成的。
本 Skill 管理的是**已分离好的音频轨道**的运行时播放和控制。
预处理工具可使用外部工具（如 Demucs Python 脚本）将混合音频分割为独立轨道，
然后将分轨结果导入 `audio-layers-v1` 格式的 JSON 配置。

### Q3: 如何为新角色创建声音档案？

1. 在 `voice-profiles-v1` JSON 中添加新角色条目
2. 使用 `audition_voices_for_character` MCP 工具生成候选语音
3. 使用 `confirm_character_voice` MCP 工具确认最终语音
4. 将语音 ID 填入档案的 `voice_id` 字段
5. 如需多语言，为每种语言创建独立的语音并填入 `locale_variants`

### Q4: 如何处理很长的过场对白（超过 50 个片段）？

建议按场景/章节拆分为多个时间轴文件：
```
scripts/data/
├── chapter1_scene01_timeline.json    # 第 1 章第 1 幕
├── chapter1_scene02_timeline.json    # 第 1 章第 2 幕
├── chapter2_scene01_timeline.json    # 第 2 章第 1 幕
```
在管线编排器中按需加载当前场景的时间轴。

### Q5: 如何调试音频播放问题？

1. 调用 `pipeline:GetState()` 查看所有轨道状态
2. 检查 `SpeakerTimeline.Validate()` 是否报告错误
3. 检查 `AudioLayerSplitter.Validate()` 是否有缺失文件
4. 使用 `LocaleVariantManager.CheckCoverage()` 检查本地化覆盖率
5. 在控制台查看 `log:Info/Warning/Error` 输出

---

## §11 参考文档

| 文档 | 路径 | 说明 |
|------|------|------|
| Linly-Dubbing 概念映射 | `references/linly-dubbing-mapping.md` | Linly-Dubbing 各模块到游戏音频管理的映射 |
| 音频分层管理指南 | `references/audio-layer-guide.md` | 音频分层、分轨策略与数据格式详解 |
| 声音档案系统指南 | `references/voice-profile-guide.md` | 角色声音档案、情绪预设与本地化管理 |
