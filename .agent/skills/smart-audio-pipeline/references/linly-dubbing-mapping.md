# Linly-Dubbing → Smart Audio Pipeline 映射指南

> 本文档详细说明 Linly-Dubbing 各模块如何映射到 Smart Audio Pipeline 的游戏音频管理概念。

---

## 1. 映射总览

Linly-Dubbing 是一个端到端的 AI 视频配音管线，包含语音识别、翻译、语音合成、唇形同步等环节。
Smart Audio Pipeline 将其中**音频分析、说话人识别、声音特征管理**等能力提取出来，
映射为游戏开发中的**音频资产管理、多轨混音、多语言音频变体**等实用功能。

### 1.1 整体关系图

```
Linly-Dubbing（AI 配音工具）        Smart Audio Pipeline（游戏音频管理）
┌─────────────────────┐            ┌──────────────────────────┐
│  UVR5 / Demucs      │ ──映射──▶ │  AudioLayerSplitter      │
│  (音频分离)          │            │  (音频层元数据管理)       │
├─────────────────────┤            ├──────────────────────────┤
│  pyannote            │ ──映射──▶ │  SpeakerTimeline         │
│  (说话人识别)        │            │  (说话人时间轴)           │
├─────────────────────┤            ├──────────────────────────┤
│  CosyVoice/SoVITS   │ ──映射──▶ │  VoiceProfileRegistry    │
│  (声音克隆)          │            │  (声音档案注册表)         │
├─────────────────────┤            ├──────────────────────────┤
│  WhisperX/FunASR     │ ──映射──▶ │  DialogueExtractor       │
│  (语音识别 ASR)      │            │  (对白文本提取,预处理)    │
├─────────────────────┤            ├──────────────────────────┤
│  BGM 保留策略         │ ──映射──▶ │  TrackMixer              │
│  (背景音乐保持)      │            │  (多轨混音,Voice Ducking) │
├─────────────────────┤            ├──────────────────────────┤
│  多语言配音输出       │ ──映射──▶ │  LocaleVariantManager    │
│  (中/英/日/韩)       │            │  (多语言音频变体管理)     │
└─────────────────────┘            └──────────────────────────┘
```

---

## 2. 逐模块映射详解

### 2.1 UVR5/Demucs → AudioLayerSplitter

**Linly-Dubbing 中的作用**：
- UVR5（Ultimate Vocal Remover v5）和 Demucs 用于将音频分离为人声、背景音乐、环境音等独立轨道
- 这是配音流程的第一步：提取原始人声后才能替换为新语言的配音

**Smart Audio Pipeline 的映射**：
- `AudioLayerSplitter` 不执行实际的 AI 音频分离（引擎端无此能力）
- 而是管理**预分离的音频层元数据**：开发者预先用工具分离好音频，导入引擎后用此模块管理

**映射方式**：

| Linly-Dubbing | Smart Audio Pipeline | 说明 |
|---------------|---------------------|------|
| 执行音频分离 | 读取预分离结果 | 分离在引擎外完成 |
| 输出 vocal.wav, bgm.wav | 管理 OGG 资源引用 | 引擎使用 OGG 格式 |
| 实时处理 | 元数据驱动 | JSON 描述层结构 |
| 单次处理 | 运行时查询 | 支持按类型/时间筛选 |

**典型工作流**：
```
1. 开发者在 PC 上用 UVR5/Demucs 分离音频
2. 导出 vocal.ogg、bgm.ogg、sfx.ogg 到 assets/audio/layers/
3. 编写 audio-layers.json 描述每层的元数据
4. 游戏运行时 AudioLayerSplitter 加载 JSON，提供查询/筛选接口
```

### 2.2 pyannote → SpeakerTimeline

**Linly-Dubbing 中的作用**：
- pyannote.audio 执行说话人分割（Speaker Diarization）
- 识别音频中"谁在什么时间说话"，输出时间戳 + 说话人标签
- 用于多角色场景：区分不同角色的对白，分别进行翻译和配音

**Smart Audio Pipeline 的映射**：
- `SpeakerTimeline` 管理预标注的说话人时间轴数据
- 每个时间段关联角色名、情绪标签、对白文本

**映射方式**：

| Linly-Dubbing | Smart Audio Pipeline | 说明 |
|---------------|---------------------|------|
| 自动识别说话人 | 手动/预标注说话人 | 游戏对白通常已知说话人 |
| 输出 RTTM 格式 | 使用 JSON 格式 | `speaker-timeline-v1` |
| 按簇聚类 speaker_0, speaker_1 | 按角色名 hero, villain | 游戏角色已命名 |
| 处理未知音频 | 管理已知对白 | 过场动画剧本已确定 |

**游戏开发应用场景**：
```lua
-- 过场动画中，根据时间轴触发不同角色的对白
local segment = speakerTimeline:GetCurrentSegment(currentTime)
if segment then
    -- 显示该角色的字幕
    subtitleUI:Show(segment.speaker, segment.text)
    -- 播放该角色的语音
    audioPlayer:Play(segment.audioFile)
end
```

### 2.3 CosyVoice/GPT-SoVITS → VoiceProfileRegistry

**Linly-Dubbing 中的作用**：
- CosyVoice 和 GPT-SoVITS 支持声音克隆：从短样本音频中提取声音特征
- 用于生成与原始说话人音色相似的多语言配音
- 保持角色声音一致性

**Smart Audio Pipeline 的映射**：
- `VoiceProfileRegistry` 管理角色的声音档案
- 存储每个角色的音色参数、情绪预设、多语言 TTS Voice ID

**映射方式**：

| Linly-Dubbing | Smart Audio Pipeline | 说明 |
|---------------|---------------------|------|
| 从样本提取声纹 | 记录 TTS Voice ID | ID 来自 AI 生成工具 |
| 实时声音克隆 | 预生成 + 运行时播放 | 语音在引擎外预生成 |
| 单一配置 | 多情绪预设 | calm/angry/excited 等 |
| 单语言 | 多语言映射 | 每个角色多语言 Voice ID |

**游戏开发应用场景**：
```lua
-- 获取角色在当前语言下的声音参数
local profile = voiceRegistry:GetProfile("hero")
local voiceId = voiceRegistry:GetLocaleVoiceId("hero", currentLocale)
local emotionPreset = voiceRegistry:GetEmotionPreset("hero", "angry")

-- 用于 TTS 生成（通过 cinematic-dub-pipeline 协作）
-- 或用于运行时音效参数调节
```

### 2.4 WhisperX/FunASR → DialogueExtractor（预处理概念）

**Linly-Dubbing 中的作用**：
- WhisperX 和 FunASR 执行带时间戳的语音识别（ASR）
- 输出精确到词级别的时间戳，用于后续翻译和字幕生成
- 支持多语言识别

**Smart Audio Pipeline 的映射**：
- 这一环节主要体现在 `SpeakerTimeline` 的 `text` 字段
- ASR 的输出作为预处理数据，直接嵌入 `speaker-timeline-v1` JSON
- 游戏场景中，对白文本通常在剧本编写阶段已确定，不需要运行时 ASR

**特殊场景**：
- 如果游戏需要从**已有录音**中提取文本（如采访素材做游戏），
  可以在引擎外使用 WhisperX 预处理，然后将结果导入 SpeakerTimeline

### 2.5 BGM 保留 → TrackMixer

**Linly-Dubbing 中的作用**：
- 配音替换人声后，需要保留原始的背景音乐
- 通过音频分离（UVR5）提取 BGM，替换人声后再混合回去
- 确保配音后的视频保持原始的音乐氛围

**Smart Audio Pipeline 的映射**：
- `TrackMixer` 实现多轨混音和 Voice Ducking（语音闪避）
- 当对白播放时，自动降低 BGM 音量；对白结束后恢复

**映射方式**：

| Linly-Dubbing | Smart Audio Pipeline | 说明 |
|---------------|---------------------|------|
| 分离后重新混合 | 实时多轨混音 | 运行时动态控制 |
| 固定混音比例 | 动态 Voice Ducking | 自动音量包络 |
| 后期处理 | 实时处理 | 每帧更新音量 |
| 输出文件 | 引擎音频播放 | 使用 SoundSource3D |

### 2.6 多语言配音 → LocaleVariantManager

**Linly-Dubbing 中的作用**：
- 支持将视频从一种语言配音到另一种语言
- 目前支持中文、英文、日文、韩文等
- 每种语言生成独立的配音音轨

**Smart Audio Pipeline 的映射**：
- `LocaleVariantManager` 管理同一对白在不同语言下的音频文件
- 运行时根据用户选择的语言，自动加载对应的音频变体

**映射方式**：

| Linly-Dubbing | Smart Audio Pipeline | 说明 |
|---------------|---------------------|------|
| 翻译 + TTS 生成 | 管理预生成的多语言音频 | 生成在引擎外完成 |
| 按语言输出视频 | 按语言切换音频 | 运行时动态切换 |
| 字幕翻译 | 对白文本多语言 | timeline 中存储翻译 |

---

## 3. 工作流对比

### 3.1 Linly-Dubbing 工作流（线性处理）

```
输入视频 → 音频分离 → ASR 识别 → 说话人分割 → 翻译 → TTS 合成 → 唇形同步 → 视频合成 → 输出
```

### 3.2 Smart Audio Pipeline 工作流（资产管理 + 运行时播放）

```
预处理阶段（引擎外）：
  原始音频 → UVR5 分离 → 导出 OGG 层文件
  录音/剧本 → 标注说话人 → 编写 timeline JSON
  角色设定 → 声音采样 → 记录 Voice ID → 编写 profiles JSON
  多语言录音 → 导出各语言 OGG → 编写 variants JSON

运行时阶段（引擎内）：
  加载元数据 → 创建 Pipeline → 播放控制 → Voice Ducking → 字幕同步
```

### 3.3 与 cinematic-dub-pipeline 的协作

```
cinematic-dub-pipeline（正向创作）：
  编写剧本 → AI 合成语音 → 生成字幕 → 播放过场动画

smart-audio-pipeline（逆向分析 + 管理）：
  已有音频 → 分层管理 → 说话人识别 → 多轨混音 → 多语言切换

协作场景：
  1. 用 cinematic-dub-pipeline 创作过场动画配音
  2. 用 smart-audio-pipeline 管理生成的音频资产
  3. VoiceProfileRegistry 为两个 skill 提供统一的声音档案
```

---

## 4. 数据格式对照

### 4.1 Linly-Dubbing 输出格式 → Smart Audio Pipeline 输入格式

| Linly-Dubbing 输出 | 格式 | S.A.P. 对应 | 转换方式 |
|-------------------|------|------------|---------|
| UVR5 分离结果 | WAV 文件 | `audio-layers-v1` JSON + OGG 文件 | 转码 + 编写元数据 |
| pyannote RTTM | RTTM 文本 | `speaker-timeline-v1` JSON | 格式转换脚本 |
| WhisperX 字幕 | SRT/JSON | timeline 的 text 字段 | 合并到 timeline |
| CosyVoice Voice ID | 配置参数 | `voice-profiles-v1` JSON | 记录到档案 |
| 多语言音频 | WAV 文件 | locale variants OGG + 注册 | 转码 + 注册 |

### 4.2 转换示例：RTTM → speaker-timeline-v1

**Linly-Dubbing 的 RTTM 输出**：
```
SPEAKER audio_001 1 0.500 2.300 <NA> <NA> speaker_0 <NA> <NA>
SPEAKER audio_001 1 3.100 1.800 <NA> <NA> speaker_1 <NA> <NA>
SPEAKER audio_001 1 5.500 3.200 <NA> <NA> speaker_0 <NA> <NA>
```

**转换为 speaker-timeline-v1**：
```json
{
  "format": "speaker-timeline-v1",
  "segments": [
    {
      "id": "seg_001",
      "speaker": "hero",
      "startTime": 0.5,
      "endTime": 2.8,
      "text": "（从 ASR 结果填入）",
      "emotion": "neutral",
      "audioFile": "Audio/Dialogue/scene1_seg001.ogg"
    },
    {
      "id": "seg_002",
      "speaker": "villain",
      "startTime": 3.1,
      "endTime": 4.9,
      "text": "（从 ASR 结果填入）",
      "emotion": "angry",
      "audioFile": "Audio/Dialogue/scene1_seg002.ogg"
    }
  ]
}
```

---

## 5. 常见问题

### Q: 为什么不在引擎内直接执行音频分离？

A: 音频分离依赖大型 AI 模型（UVR5 需要 GPU + 数百 MB 权重），
不适合在游戏运行时执行。游戏开发的最佳实践是：
预处理阶段使用专业工具完成，运行时只管理和播放结果。

### Q: 游戏对白已有剧本，还需要 ASR 吗？

A: 大多数情况不需要。ASR 主要用于：
1. 从已有录音素材中提取文本（如真人配音素材）
2. 从参考视频中提取台词用于改编
这些都在引擎外预处理完成。

### Q: VoiceProfileRegistry 和 cinematic-dub-pipeline 的关系？

A: VoiceProfileRegistry 存储角色的声音元数据（Voice ID、情绪预设等），
cinematic-dub-pipeline 的 VoiceSynthesizer 可以引用这些数据来合成语音。
两者通过共享 JSON 数据格式协作。

---

*本文档版本: 1.0*
*适用 Skill: smart-audio-pipeline*
