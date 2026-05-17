# 声音档案与情绪预设管理指南

> 本文档详细说明 VoiceProfileRegistry 模块的声音档案概念、情绪预设系统、
> 多语言 Voice ID 管理，以及如何在 UrhoX Lua 游戏中构建一致的角色声音体系。

---

## 1. 声音档案概念

### 1.1 什么是声音档案

声音档案（Voice Profile）是一个角色的**声音身份描述**，包含：

- **基础信息**：角色名称、性别、年龄段、声音描述
- **TTS 参数**：AI 语音合成的 Voice ID、pitch、speed 等
- **情绪预设**：不同情绪状态下的参数调整
- **多语言映射**：每种语言对应的 Voice ID

**来源映射**：
Linly-Dubbing 中的 CosyVoice/GPT-SoVITS 声音克隆功能，
能从短音频样本中提取声音特征并生成新语音。
Smart Audio Pipeline 将这一能力抽象为可管理的声音档案系统。

### 1.2 游戏开发中的应用

```
角色设计文档
├── 视觉设计 → 角色立绘/模型
├── 性格设计 → 对白风格/语气
└── 声音设计 → 声音档案（VoiceProfile）
    ├── 声音特征描述
    ├── 情绪预设（calm/angry/excited...）
    ├── 多语言版本
    └── TTS 参数（用于 AI 生成新对白）
```

---

## 2. voice-profiles-v1 数据格式

### 2.1 完整格式规范

```json
{
  "format": "voice-profiles-v1",
  "version": "1.0.0",
  "profiles": [
    {
      "characterId": "hero",
      "characterName": "亚瑟",
      "gender": "male",
      "ageGroup": "young_adult",
      "description": "温暖而坚定的男声，略带沙哑，充满正义感",
      "sampleAudio": "Audio/Samples/hero_sample.ogg",
      "defaultParams": {
        "voiceId": "cosyvoice-hero-v1",
        "pitch": 0.0,
        "speed": 1.0,
        "volume": 1.0,
        "breathiness": 0.1,
        "warmth": 0.7
      },
      "emotionPresets": {
        "calm": {
          "pitch": 0.0,
          "speed": 0.95,
          "volume": 0.85,
          "breathiness": 0.15,
          "warmth": 0.8,
          "description": "平静、沉稳的语气"
        },
        "angry": {
          "pitch": 0.2,
          "speed": 1.15,
          "volume": 1.0,
          "breathiness": 0.05,
          "warmth": 0.3,
          "description": "愤怒、激昂的语气"
        },
        "excited": {
          "pitch": 0.15,
          "speed": 1.1,
          "volume": 0.95,
          "breathiness": 0.1,
          "warmth": 0.6,
          "description": "兴奋、激动的语气"
        },
        "sad": {
          "pitch": -0.1,
          "speed": 0.85,
          "volume": 0.7,
          "breathiness": 0.2,
          "warmth": 0.5,
          "description": "悲伤、低沉的语气"
        },
        "whisper": {
          "pitch": -0.05,
          "speed": 0.8,
          "volume": 0.4,
          "breathiness": 0.4,
          "warmth": 0.6,
          "description": "低语、私密的语气"
        }
      },
      "localeVoiceIds": {
        "zh": "cosyvoice-hero-zh-v1",
        "en": "elevenlabs-hero-en-v1",
        "ja": "voicevox-hero-ja-v1",
        "ko": "cosyvoice-hero-ko-v1"
      },
      "tags": ["protagonist", "warrior", "noble"]
    },
    {
      "characterId": "villain",
      "characterName": "莫德雷德",
      "gender": "male",
      "ageGroup": "middle_aged",
      "description": "低沉而阴冷的男声，带有威胁感，语速偏慢",
      "sampleAudio": "Audio/Samples/villain_sample.ogg",
      "defaultParams": {
        "voiceId": "cosyvoice-villain-v1",
        "pitch": -0.15,
        "speed": 0.9,
        "volume": 0.9,
        "breathiness": 0.05,
        "warmth": 0.2
      },
      "emotionPresets": {
        "calm": {
          "pitch": -0.2,
          "speed": 0.85,
          "volume": 0.8,
          "breathiness": 0.1,
          "warmth": 0.15,
          "description": "冰冷、不动声色的威压"
        },
        "angry": {
          "pitch": 0.1,
          "speed": 1.2,
          "volume": 1.0,
          "breathiness": 0.0,
          "warmth": 0.0,
          "description": "暴怒、声嘶力竭"
        },
        "mocking": {
          "pitch": 0.05,
          "speed": 1.05,
          "volume": 0.85,
          "breathiness": 0.1,
          "warmth": 0.1,
          "description": "嘲讽、轻蔑的语气"
        }
      },
      "localeVoiceIds": {
        "zh": "cosyvoice-villain-zh-v1",
        "en": "elevenlabs-villain-en-v1"
      },
      "tags": ["antagonist", "dark", "menacing"]
    },
    {
      "characterId": "companion",
      "characterName": "艾莉",
      "gender": "female",
      "ageGroup": "young_adult",
      "description": "清亮活泼的女声，充满好奇心和活力",
      "sampleAudio": "Audio/Samples/companion_sample.ogg",
      "defaultParams": {
        "voiceId": "cosyvoice-companion-v1",
        "pitch": 0.1,
        "speed": 1.05,
        "volume": 0.9,
        "breathiness": 0.15,
        "warmth": 0.8
      },
      "emotionPresets": {
        "calm": {
          "pitch": 0.05,
          "speed": 1.0,
          "volume": 0.85,
          "breathiness": 0.1,
          "warmth": 0.85,
          "description": "温柔、平和的语气"
        },
        "excited": {
          "pitch": 0.25,
          "speed": 1.2,
          "volume": 1.0,
          "breathiness": 0.15,
          "warmth": 0.9,
          "description": "兴奋、欢快的语气"
        },
        "worried": {
          "pitch": 0.1,
          "speed": 1.1,
          "volume": 0.75,
          "breathiness": 0.25,
          "warmth": 0.6,
          "description": "担忧、焦虑的语气"
        }
      },
      "localeVoiceIds": {
        "zh": "cosyvoice-companion-zh-v1",
        "en": "elevenlabs-companion-en-v1",
        "ja": "voicevox-companion-ja-v1"
      },
      "tags": ["companion", "cheerful", "curious"]
    }
  ]
}
```

### 2.2 字段说明

#### 角色档案字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `characterId` | string | 是 | 角色唯一标识 |
| `characterName` | string | 是 | 角色显示名称 |
| `gender` | string | 是 | 性别：`male`, `female`, `other` |
| `ageGroup` | string | 是 | 年龄段：`child`, `teenager`, `young_adult`, `middle_aged`, `elderly` |
| `description` | string | 是 | 声音特征描述（自然语言） |
| `sampleAudio` | string | 否 | 参考音频文件路径 |
| `defaultParams` | object | 是 | 默认语音参数 |
| `emotionPresets` | object | 否 | 情绪预设字典 |
| `localeVoiceIds` | object | 否 | 多语言 Voice ID 映射 |
| `tags` | array | 否 | 标签列表，用于搜索和分类 |

#### 语音参数字段

| 字段 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `voiceId` | string | - | AI TTS 引擎的声音标识 |
| `pitch` | number | -1.0 ~ 1.0 | 音高偏移（0 = 原始） |
| `speed` | number | 0.5 ~ 2.0 | 语速倍率（1.0 = 原始） |
| `volume` | number | 0.0 ~ 1.0 | 音量 |
| `breathiness` | number | 0.0 ~ 1.0 | 气息感 |
| `warmth` | number | 0.0 ~ 1.0 | 温暖度（影响音色） |

---

## 3. 情绪预设系统

### 3.1 预设情绪列表

Smart Audio Pipeline 推荐以下标准情绪预设：

| 情绪 | 英文键 | 典型参数调整 | 适用场景 |
|------|--------|-------------|---------|
| 平静 | `calm` | speed↓ volume↓ warmth↑ | 日常对话、旁白 |
| 愤怒 | `angry` | pitch↑ speed↑ volume↑ warmth↓ | 战斗、冲突 |
| 兴奋 | `excited` | pitch↑ speed↑ breathiness↑ | 发现、胜利 |
| 悲伤 | `sad` | pitch↓ speed↓ volume↓ | 剧情转折、离别 |
| 恐惧 | `fear` | pitch↑ speed↑ volume↓ breathiness↑ | 恐怖场景 |
| 低语 | `whisper` | pitch↓ speed↓ volume↓ breathiness↑ | 潜行、密谈 |
| 嘲讽 | `mocking` | pitch↑ speed↑ warmth↓ | 反派对话 |
| 坚定 | `determined` | speed→ volume↑ warmth→ | 决战、誓言 |

### 3.2 在游戏中使用情绪预设

```lua
local VoiceProfileRegistry = require("scripts.audio.VoiceProfileRegistry")

local registry = VoiceProfileRegistry.new()
registry:Load("Audio/Config/voice_profiles.json")

-- 获取角色在特定情绪下的参数
local angryPreset = registry:GetEmotionPreset("hero", "angry")
if angryPreset then
    -- angryPreset 包含 pitch, speed, volume 等调整后的参数
    log:Write(LOG_INFO, "愤怒预设 - pitch: " .. angryPreset.pitch
        .. ", speed: " .. angryPreset.speed)
end

-- 构建 TTS 参数（用于与 cinematic-dub-pipeline 协作）
local ttsParams = registry:BuildTTSParams("hero", "angry", "zh")
-- ttsParams = { voiceId = "cosyvoice-hero-zh-v1", pitch = 0.2, speed = 1.15, ... }
```

### 3.3 情绪过渡

在过场动画中，角色情绪可能在一段对白中变化。
可以通过 SpeakerTimeline 的 segment emotion 字段控制：

```json
{
  "segments": [
    { "id": "seg_01", "speaker": "hero", "emotion": "calm", "text": "一切都结束了..." },
    { "id": "seg_02", "speaker": "hero", "emotion": "angry", "text": "不！我绝不允许！" },
    { "id": "seg_03", "speaker": "hero", "emotion": "determined", "text": "这一次，我一定会守护到底。" }
  ]
}
```

游戏运行时，PipelineOrchestrator 会根据当前 segment 的 emotion 字段，
自动从 VoiceProfileRegistry 查找对应的情绪预设参数。

---

## 4. 多语言 Voice ID 管理

### 4.1 为什么需要多语言 Voice ID

不同 TTS 引擎对不同语言的支持程度不同：

| TTS 引擎 | 中文 | 英文 | 日文 | 韩文 | 说明 |
|----------|------|------|------|------|------|
| CosyVoice | 优秀 | 良好 | 一般 | 良好 | 阿里开源，中文最佳 |
| ElevenLabs | 良好 | 优秀 | 良好 | 良好 | 英文最佳，付费 |
| VOICEVOX | 无 | 无 | 优秀 | 无 | 日文专用，免费 |
| GPT-SoVITS | 优秀 | 良好 | 良好 | 一般 | 开源，声音克隆强 |
| Edge TTS | 良好 | 良好 | 良好 | 良好 | 微软免费，质量中等 |

因此，同一个角色在不同语言下可能使用不同 TTS 引擎的 Voice ID。

### 4.2 locale Voice ID 配置

```json
{
  "localeVoiceIds": {
    "zh": "cosyvoice-hero-zh-v1",
    "en": "elevenlabs-hero-en-v1",
    "ja": "voicevox-hero-ja-v1",
    "ko": "cosyvoice-hero-ko-v1"
  }
}
```

### 4.3 在游戏中获取 Voice ID

```lua
-- 获取当前语言的 Voice ID
local currentLocale = "zh"  -- 从游戏设置获取
local voiceId = registry:GetLocaleVoiceId("hero", currentLocale)

if voiceId then
    log:Write(LOG_INFO, "hero 的 " .. currentLocale .. " Voice ID: " .. voiceId)
else
    -- 回退到默认 Voice ID
    local profile = registry:GetProfile("hero")
    voiceId = profile.defaultParams.voiceId
    log:Write(LOG_WARNING, "未找到 " .. currentLocale .. " Voice ID，使用默认")
end
```

### 4.4 与 LocaleVariantManager 协作

VoiceProfileRegistry 管理**声音元数据**（Voice ID、参数），
LocaleVariantManager 管理**已生成的音频文件**：

```lua
-- VoiceProfileRegistry: 告诉你"用什么声音生成"
local voiceId = registry:GetLocaleVoiceId("hero", "en")
-- 结果: "elevenlabs-hero-en-v1"

-- LocaleVariantManager: 告诉你"已生成的音频在哪"
local audioFile = localeManager:GetAudioForLocale("seg_001", "en")
-- 结果: "Audio/Dialogue/en/hero_line001.ogg"
```

---

## 5. 标签搜索系统

### 5.1 标签用途

标签用于在大型项目中快速查找和分组角色：

```lua
-- 查找所有反派角色的声音档案
local villains = registry:FindProfilesByTag("antagonist")

-- 查找所有女性角色
local females = registry:FindProfilesByTag("female")

-- 查找特定类型的角色
local warriors = registry:FindProfilesByTag("warrior")
```

### 5.2 推荐标签体系

| 类别 | 标签示例 |
|------|---------|
| 角色定位 | `protagonist`, `antagonist`, `companion`, `npc`, `narrator` |
| 性别相关 | `male`, `female` |
| 性格特征 | `cheerful`, `serious`, `mysterious`, `noble`, `menacing` |
| 声音特征 | `deep`, `high_pitched`, `raspy`, `smooth`, `childlike` |
| 游戏功能 | `combat_voice`, `shop_npc`, `quest_giver`, `boss` |

---

## 6. 与引擎 TTS 工具集成

### 6.1 与 audition_voices_for_character 配合

UrhoX 的 `audition_voices_for_character` 工具可以为角色创建 AI 语音。
VoiceProfileRegistry 可以记录生成的 Voice ID：

```lua
-- 开发流程：
-- 1. 使用 audition_voices_for_character 试听并选择声音
-- 2. 使用 confirm_character_voice 确认声音
-- 3. 将返回的 Voice ID 记录到 voice-profiles-v1 JSON 中
-- 4. 游戏运行时通过 VoiceProfileRegistry 查询
```

### 6.2 与 text_to_dialogue 配合

```lua
-- 使用 VoiceProfileRegistry 获取角色的情绪参数，
-- 然后传递给 text_to_dialogue 工具生成对白音频。
-- 注意：text_to_dialogue 使用 ElevenLabs 引擎，
-- 需要确保对应语言的 Voice ID 已在 localeVoiceIds 中配置。
```

---

## 7. 数据文件组织

### 7.1 推荐结构

```
assets/
└── Audio/
    ├── Config/
    │   └── voice_profiles.json     # 所有角色的声音档案
    ├── Samples/                     # 声音参考样本
    │   ├── hero_sample.ogg
    │   ├── villain_sample.ogg
    │   └── companion_sample.ogg
    └── Dialogue/                    # 生成的对白音频
        ├── zh/                      # 中文对白
        │   ├── hero_line001.ogg
        │   └── hero_line002.ogg
        ├── en/                      # 英文对白
        │   ├── hero_line001.ogg
        │   └── hero_line002.ogg
        └── ja/                      # 日文对白
            └── hero_line001.ogg
```

### 7.2 单文件 vs 多文件

| 方案 | 适用场景 | 说明 |
|------|---------|------|
| 单文件 `voice_profiles.json` | 角色 < 20 个 | 管理简单 |
| 多文件（每角色一个） | 角色 > 20 个 | 按角色独立加载 |

多文件方案：
```
assets/Audio/Config/profiles/
├── hero.json
├── villain.json
└── companion.json
```

---

## 8. 最佳实践

### 8.1 声音一致性

- 同一角色在所有语言版本中应保持相似的音色特征
- 使用 `description` 字段记录声音特征，作为选择/创建 Voice ID 的参考
- 定期对比不同语言版本的音频，确保一致性

### 8.2 情绪预设设计

- 每个角色至少定义 `calm` 和一个"高强度"情绪（如 `angry` 或 `excited`）
- 反派角色考虑添加 `mocking` 和 `menacing` 预设
- 对白密集的角色需要更多预设以避免语气单调

### 8.3 性能考虑

- VoiceProfileRegistry 的 JSON 数据通常很小（几 KB），加载一次即可
- 声音样本文件仅用于开发参考，不需要在发布版中包含
- 运行时只需要 Voice ID 和参数，不需要加载样本音频

---

## 9. 常见问题

### Q: Voice ID 从哪里来？

A: Voice ID 来自 AI TTS 引擎：
1. **ElevenLabs**: 通过 `audition_voices_for_character` 工具创建
2. **CosyVoice**: 使用声音克隆功能生成，返回模型 ID
3. **GPT-SoVITS**: 训练模型后获得模型路径
4. **Edge TTS**: 使用微软预设声音名称（如 `zh-CN-XiaoxiaoNeural`）

### Q: 情绪预设的参数怎么调？

A: 建议从标准值开始微调：
1. 参考 §3.1 的推荐参数方向
2. 生成试听音频，反复调整
3. 记录最终参数到 JSON
4. 不同角色的同一情绪可以有不同的参数（反派的"愤怒"和主角的"愤怒"不同）

### Q: 支持自定义情绪吗？

A: 支持。`emotionPresets` 是一个字典，键名可以自定义：
```json
{
  "emotionPresets": {
    "battle_cry": { "pitch": 0.3, "speed": 1.3, "volume": 1.0 },
    "inner_monologue": { "pitch": -0.1, "speed": 0.8, "volume": 0.5 }
  }
}
```

### Q: 没有多语言需求，还需要 localeVoiceIds 吗？

A: 不需要。如果只有单语言版本，省略 `localeVoiceIds` 字段即可。
系统会自动使用 `defaultParams.voiceId`。

---

*本文档版本: 1.0*
*适用 Skill: smart-audio-pipeline*
