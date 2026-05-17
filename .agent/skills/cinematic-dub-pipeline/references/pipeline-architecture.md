# 管线架构设计 — Linly-Dubbing → UrhoX 映射详解

> 本文档详细说明 Linly-Dubbing 7 阶段管线如何映射为 UrhoX Lua 游戏引擎的过场配音系统。

---

## 1. Linly-Dubbing 原始管线

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│ 1.视频输入 │→│ 2.人声分离 │→│ 3.语音识别 │→│ 4.文本翻译 │
│ (上传/URL)│  │(UVR5/     │  │(FunASR/   │  │(GPT/Qwen)│
│           │  │ Demucs)   │  │ WhisperX) │  │          │
└──────────┘   └──────────┘   └──────────┘   └──────────┘
                                                    ↓
┌──────────┐   ┌──────────┐   ┌──────────┐
│ 7.视频合成 │←│ 6.唇形同步 │←│ 5.语音合成 │
│(ffmpeg)   │  │(Linly-    │  │(CosyVoice/│
│           │  │ Talker)   │  │ XTTS)     │
└──────────┘   └──────────┘   └──────────┘
```

### 各阶段技术详情

| 阶段 | 工具 | 输入 | 输出 |
|------|------|------|------|
| 1. 视频输入 | yt-dlp / 本地上传 | URL/文件 | .mp4 视频 |
| 2. 人声分离 | UVR5 / Demucs | 混合音频 | 人声 + 伴奏 |
| 3. 语音识别 | FunASR / WhisperX | 人声音频 | 带时间戳的文本 |
| 4. 文本翻译 | GPT-4 / Qwen | 源语言文本 | 目标语言文本 |
| 5. 语音合成 | CosyVoice / XTTS / GPT-SoVITS | 翻译文本 + 参考音频 | 合成语音 |
| 6. 唇形同步 | Linly-Talker | 合成语音 + 视频 | 嘴型同步视频 |
| 7. 视频合成 | ffmpeg | 音频 + 视频 + 字幕 | 最终视频 |

---

## 2. UrhoX 游戏管线映射

### 关键差异

| 维度 | Linly-Dubbing | UrhoX 游戏管线 |
|------|--------------|---------------|
| **输入源** | 已有视频 | 编写剧本 JSON |
| **ASR 需求** | 必须（从音频提取文本）| 不需要（文本已知）|
| **运行时** | 离线批处理 | 实时渲染播放 |
| **输出** | .mp4 文件 | 引擎内实时过场 |
| **唇形同步** | 神经网络 | 正弦波权重动画 |
| **字幕** | ffmpeg 烧录 | UI 组件实时渲染 |

### 映射后的管线

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 1. 剧本编写   │→│ 2. 角色声音设计│→│ 3. 多语言翻译  │
│ (JSON 格式)  │  │(ElevenLabs   │  │(AI 辅助 /    │
│              │  │ audition)    │  │ i18n 框架)   │
└──────────────┘   └──────────────┘   └──────────────┘
                                            ↓
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 6. 过场播放   │←│ 5. 字幕时间轴  │←│ 4. 语音合成   │
│(VideoPlayer  │  │(Timeline +   │  │(ElevenLabs   │
│ + UI 叠加)   │  │ SubtitleUI)  │  │ text_to_     │
│              │  │              │  │ dialogue)    │
└──────────────┘   └──────────────┘   └──────────────┘
```

---

## 3. 阶段详解

### 3.1 阶段 1: 剧本编写 (替代 ASR)

**为什么不需要 ASR**：
游戏过场动画的对白是预先编写的，不需要从音频中识别。
直接以 JSON 格式编写剧本，每句台词标注角色、时长、情绪。

**剧本 JSON Schema**:

```json
{
  "$schema": "剧本格式定义",
  "required": ["id", "scenes"],
  "properties": {
    "id": { "type": "string", "description": "剧本唯一标识" },
    "title": { "type": "string" },
    "scenes": {
      "type": "array",
      "items": {
        "required": ["id", "lines"],
        "properties": {
          "id": { "type": "string" },
          "background": { "type": "string", "description": "视频/图片路径" },
          "bgm": { "type": "string", "description": "BGM 音频路径" },
          "bgmVolume": { "type": "number", "default": 0.3 },
          "lines": {
            "type": "array",
            "items": {
              "required": ["id", "character", "text"],
              "properties": {
                "id": { "type": "string" },
                "character": { "type": "string" },
                "text": { "type": "string" },
                "duration": { "type": "number", "default": 3.0 },
                "emotion": { "type": "string", "default": "neutral" },
                "subtitle": { "type": "boolean", "default": true },
                "pause_after": { "type": "number", "default": 0 }
              }
            }
          }
        }
      }
    }
  }
}
```

### 3.2 阶段 2: 角色声音设计 (替代音频克隆)

**Linly-Dubbing 方式**: 从视频中提取原始说话人声音，用 CosyVoice/XTTS 克隆音色。

**UrhoX 游戏方式**: 使用 ElevenLabs Voice Design API 创建定制语音。

ElevenLabs 六维度描述规范：
1. **年龄/性别**: "Young adult male in his 20s"
2. **音色**: "warm, magnetic, slightly husky"
3. **语速**: "moderate pace, with occasional pauses"
4. **情绪**: "determined but gentle"
5. **风格**: "professional Chinese voice actor, anime protagonist style"
6. **质量**: "studio-quality recording"

### 3.3 阶段 3: 多语言翻译

两种翻译策略对比：

| 策略 | 适用场景 | 优势 | 劣势 |
|------|---------|------|------|
| 直接翻译 | 小型项目 (< 50 句) | 精确控制每句翻译 | 人工成本高 |
| i18n 框架 | 大型项目 (50+ 句) | 自动提取/替换 | 初始配置复杂 |

### 3.4 阶段 4: 语音合成

ElevenLabs `text_to_dialogue` 调用参数：

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `character_name` | 角色名（须已设计声音） | characters.json 中的 key |
| `text` | 台词文本（支持情绪标签） | `[sighs] 又是一个...` |
| `language_code` | 语言代码 | `cmn` / `en` / `ja` |
| `stability` | 稳定性（越低越有表现力）| 0.3~0.7 按情绪调整 |
| `output_name` | 输出文件名 | `{script_id}_{line_id}` |

情绪标签参考（嵌入台词文本中）：

```
[laughing]    笑声      [sad]        悲伤
[excited]     兴奋      [angry]      愤怒
[whispering]  低语      [shouting]   呐喊
[sighs]       叹气      [gasps]      倒吸气
[nervous]     紧张      [sarcastic]  讽刺
```

### 3.5 阶段 5: 字幕时间轴

时间轴计算公式：

```
entry[i].startTime = SUM(entry[1..i-1].duration + entry[1..i-1].pause_after)
entry[i].endTime   = entry[i].startTime + entry[i].duration
```

淡入淡出算法：

```
alpha(t) =
  t - startTime < fadeIn   → (t - startTime) / fadeIn
  endTime - t < fadeOut    → (endTime - t) / fadeOut
  otherwise                → 1.0
```

### 3.6 阶段 6: 过场播放

两种播放模式的选择树：

```
需要播放过场？
├── 有预渲染视频？
│   ├── 是 → Video.VideoPlayer + 字幕 UI 叠加
│   └── 否 → 引擎内 3D 实时过场
│       ├── 有角色模型？
│       │   ├── 是 → LipSyncDriver 驱动嘴型
│       │   └── 否 → 纯字幕 + 语音
│       └── 需要相机运镜？
│           ├── 是 → SplinePath 插值相机路径
│           └── 否 → 固定相机
└── 否 → 不使用本 Skill
```

---

## 4. 数据流总览

```
characters.json ──────────────────────┐
                                      ↓
                          audition_voices (MCP)
                                      ↓
                          confirm_character_voice (MCP)
                                      ↓
act1_opening.json ──→ ScriptManager ──→ SubtitleTimeline
                          ↓                    ↓
                    text_to_dialogue (MCP)     timeline.entries[]
                          ↓                    ↓
                    assets/Voices/cmn/    CutscenePlayer
                          ↓                    ↓
                    AudioMixer.PlayVoice  SubtitleUI.render
                          ↓                    ↓
                    LipSyncDriver        字幕淡入淡出
                          ↓
                    角色嘴型动画

翻译版剧本:
act1_opening.json ──→ AI 翻译 ──→ en/act1_opening.json
                                       ↓
                              text_to_dialogue (lang="en")
                                       ↓
                              assets/Voices/en/
```

---

## 5. 扩展点

### 5.1 自定义音频后处理

如需对合成语音添加效果（回声、混响）：

```lua
-- 使用 SoundSource 的 3D 空间效果模拟回声
local voiceSource3D = node:CreateComponent("SoundSource3D")
voiceSource3D.nearDistance = 1.0
voiceSource3D.farDistance = 50.0
-- 距离衰减自动模拟空间感
```

### 5.2 过场事件系统

扩展剧本 JSON 支持触发游戏事件：

```json
{
  "id": "line_050",
  "character": "hero",
  "text": "看！那边有什么！",
  "events": [
    { "type": "camera_shake", "intensity": 0.5, "duration": 1.0 },
    { "type": "particle", "effect": "explosion", "position": [10, 0, 5] },
    { "type": "game_flag", "key": "seen_explosion", "value": true }
  ]
}
```

### 5.3 语音缓存策略

```lua
-- 预加载策略
local function PreloadSceneVoices(timeline, startIdx, count)
    for i = startIdx, math.min(startIdx + count - 1, #timeline.entries) do
        local entry = timeline.entries[i]
        if entry.audioFile then
            cache:GetResource("Sound", entry.audioFile)
        end
    end
end

-- 在进入新场景时预加载接下来 10 句的语音
PreloadSceneVoices(timeline, currentIndex, 10)
```
