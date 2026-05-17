# 音频层管理与数据格式详解

> 本文档详细说明 AudioLayerSplitter 模块的音频层概念、分离策略、数据格式规范，
> 以及如何在 UrhoX Lua 游戏中有效管理多层音频资产。

---

## 1. 音频层概念

### 1.1 什么是音频层

在专业音频制作中，一段完整的音频由多个**层**（Layer）叠加而成：

```
完整音频
├── 人声层（Vocal）     → 角色对白、旁白
├── 音乐层（BGM）       → 背景音乐
├── 音效层（SFX）       → 脚步声、门声、爆炸声
└── 环境层（Ambient）   → 风声、雨声、人群嘈杂声
```

**游戏中的应用**：
- 独立控制每层的音量（例如：降低 BGM 音量以突出对白）
- 替换某一层（例如：多语言对白替换人声层）
- 混合/移除某些层（例如：关闭环境音以节省性能）

### 1.2 分离工具概述

Smart Audio Pipeline 的层概念源自 Linly-Dubbing 使用的 AI 音频分离工具：

| 工具 | 分离能力 | 适用场景 |
|------|---------|---------|
| UVR5 | 人声 / 伴奏（2轨） | 简单场景，快速分离 |
| Demucs (Meta) | 人声 / 鼓 / 贝斯 / 其他（4轨） | 精细音乐分离 |
| Demucs v4 htdemucs_6s | 人声 / 鼓 / 贝斯 / 吉他 / 钢琴 / 其他（6轨） | 最精细分离 |

**重要**：这些工具在**引擎外**运行，游戏中只管理分离后的结果。

---

## 2. audio-layers-v1 数据格式

### 2.1 完整格式规范

```json
{
  "format": "audio-layers-v1",
  "version": "1.0.0",
  "scene": "cutscene_01",
  "description": "第一章开场过场动画音频层",
  "totalDuration": 45.0,
  "sampleRate": 44100,
  "layers": [
    {
      "id": "layer_vocal",
      "name": "人声对白",
      "type": "vocal",
      "audioFile": "Audio/Layers/scene01_vocal.ogg",
      "startTime": 0.0,
      "endTime": 45.0,
      "defaultVolume": 1.0,
      "speakers": ["hero", "mentor"],
      "priority": 10,
      "tags": ["dialogue", "main"],
      "fadeIn": 0.0,
      "fadeOut": 0.5
    },
    {
      "id": "layer_bgm",
      "name": "背景音乐",
      "type": "bgm",
      "audioFile": "Audio/Layers/scene01_bgm.ogg",
      "startTime": 0.0,
      "endTime": 45.0,
      "defaultVolume": 0.6,
      "speakers": [],
      "priority": 5,
      "tags": ["music", "orchestral"],
      "fadeIn": 2.0,
      "fadeOut": 3.0
    },
    {
      "id": "layer_sfx",
      "name": "音效",
      "type": "sfx",
      "audioFile": "Audio/Layers/scene01_sfx.ogg",
      "startTime": 2.0,
      "endTime": 40.0,
      "defaultVolume": 0.8,
      "speakers": [],
      "priority": 7,
      "tags": ["effects", "combat"],
      "fadeIn": 0.0,
      "fadeOut": 0.0
    },
    {
      "id": "layer_ambient",
      "name": "环境音",
      "type": "ambient",
      "audioFile": "Audio/Layers/scene01_ambient.ogg",
      "startTime": 0.0,
      "endTime": 45.0,
      "defaultVolume": 0.3,
      "speakers": [],
      "priority": 1,
      "tags": ["environment", "forest"],
      "fadeIn": 3.0,
      "fadeOut": 3.0,
      "loop": true
    }
  ],
  "mixPresets": {
    "default": {
      "layer_vocal": 1.0,
      "layer_bgm": 0.6,
      "layer_sfx": 0.8,
      "layer_ambient": 0.3
    },
    "dialogue_focus": {
      "layer_vocal": 1.0,
      "layer_bgm": 0.2,
      "layer_sfx": 0.4,
      "layer_ambient": 0.1
    },
    "music_focus": {
      "layer_vocal": 0.0,
      "layer_bgm": 1.0,
      "layer_sfx": 0.5,
      "layer_ambient": 0.4
    }
  }
}
```

### 2.2 字段说明

#### 顶层字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `format` | string | 是 | 固定值 `"audio-layers-v1"` |
| `version` | string | 是 | 数据版本号 |
| `scene` | string | 是 | 所属场景标识 |
| `description` | string | 否 | 描述信息 |
| `totalDuration` | number | 是 | 总时长（秒） |
| `sampleRate` | number | 否 | 采样率（默认 44100） |
| `layers` | array | 是 | 音频层列表 |
| `mixPresets` | object | 否 | 混音预设 |

#### 层字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | 是 | 层唯一标识 |
| `name` | string | 是 | 显示名称 |
| `type` | string | 是 | 层类型：`vocal`, `bgm`, `sfx`, `ambient` |
| `audioFile` | string | 是 | OGG 音频文件路径（相对于资源根） |
| `startTime` | number | 是 | 开始时间（秒） |
| `endTime` | number | 是 | 结束时间（秒） |
| `defaultVolume` | number | 是 | 默认音量 (0.0 ~ 1.0) |
| `speakers` | array | 否 | 关联的说话人列表 |
| `priority` | number | 否 | 优先级（数值越大越重要） |
| `tags` | array | 否 | 标签列表，用于筛选 |
| `fadeIn` | number | 否 | 淡入时长（秒） |
| `fadeOut` | number | 否 | 淡出时长（秒） |
| `loop` | boolean | 否 | 是否循环播放 |

---

## 3. 分离策略

### 3.1 过场动画音频

过场动画通常需要最精细的分离：

```
原始过场动画音频
├── 人声层 → 可替换为多语言配音
├── 音乐层 → 保持不变，Voice Ducking 控制音量
├── 音效层 → 保持不变
└── 环境层 → 保持不变
```

**推荐工具**：UVR5（人声/伴奏分离）+ 手动标注音效

### 3.2 游戏关卡音频

关卡音频通常分层较简单：

```
关卡音频
├── BGM → 循环播放
└── 环境音 → 循环播放，可独立控制
```

**推荐方式**：直接准备独立的音频文件，无需 AI 分离

### 3.3 交互式对白

交互式对白（如 NPC 对话）通常每句独立录制：

```
NPC 对话
├── 每句话一个音频文件
├── SpeakerTimeline 管理播放顺序
└── VoiceProfileRegistry 管理声音一致性
```

**推荐方式**：直接录制/生成独立对白文件

---

## 4. Lua 接口使用详解

### 4.1 加载层数据

```lua
local AudioLayerSplitter = require("scripts.audio.AudioLayerSplitter")

-- 从 JSON 文件加载
local splitter = AudioLayerSplitter.new()
local success, err = splitter:Load("Audio/Config/scene01_layers.json")
if not success then
    log:Write(LOG_ERROR, "加载音频层失败: " .. err)
    return
end
```

### 4.2 按类型筛选

```lua
-- 获取所有人声层
local vocalLayers = splitter:GetLayersByType("vocal")
for _, layer in ipairs(vocalLayers) do
    log:Write(LOG_INFO, "人声层: " .. layer.name .. " → " .. layer.audioFile)
end

-- 获取所有 BGM 层
local bgmLayers = splitter:GetLayersByType("bgm")
```

### 4.3 按说话人筛选

```lua
-- 获取包含特定说话人的层
local heroLayers = splitter:GetLayersBySpeaker("hero")
```

### 4.4 获取当前时间的活跃层

```lua
-- 在 Update 中，获取当前时间点的所有活跃层
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    currentTime = currentTime + dt

    local activeLayers = splitter:GetActiveLayersAtTime(currentTime)
    for _, layer in ipairs(activeLayers) do
        -- 更新音量、触发播放等
    end
end
```

### 4.5 混音预设切换

```lua
-- 加载后，可以通过 mixPresets 快速切换混音方案
local layerData = splitter:GetData()
local preset = layerData.mixPresets.dialogue_focus

for layerId, volume in pairs(preset) do
    local layer = splitter:GetLayerById(layerId)
    if layer then
        -- 设置音量（通过 TrackMixer 实现）
        trackMixer:SetTrackVolume(layerId, volume)
    end
end
```

---

## 5. 与 TrackMixer 协作

AudioLayerSplitter 提供层的**元数据**，TrackMixer 负责实际**播放和混音**：

```lua
-- 1. 加载层元数据
local splitter = AudioLayerSplitter.new()
splitter:Load("Audio/Config/scene01_layers.json")

-- 2. 根据元数据创建混音轨道
local mixer = TrackMixer.new(scene)
for _, layer in ipairs(splitter:GetAllLayers()) do
    mixer:CreateTrack(layer.id, {
        audioFile = layer.audioFile,
        volume = layer.defaultVolume,
        loop = layer.loop or false,
        fadeIn = layer.fadeIn or 0,
        fadeOut = layer.fadeOut or 0,
    })
end

-- 3. 启用 Voice Ducking
mixer:EnableVoiceDucking({
    voiceTrackId = "layer_vocal",
    bgmTrackId = "layer_bgm",
    duckVolume = 0.2,
    fadeTime = 0.5,
})

-- 4. 播放所有轨道
mixer:PlayAll()
```

---

## 6. 资源文件组织

### 6.1 推荐目录结构

```
assets/
└── Audio/
    ├── Config/                     # 配置文件
    │   ├── scene01_layers.json     # 场景1音频层定义
    │   └── scene02_layers.json     # 场景2音频层定义
    ├── Layers/                     # 分离后的音频层
    │   ├── scene01_vocal.ogg
    │   ├── scene01_bgm.ogg
    │   ├── scene01_sfx.ogg
    │   └── scene01_ambient.ogg
    └── Dialogue/                   # 独立对白文件
        ├── hero_line001.ogg
        ├── hero_line002.ogg
        └── villain_line001.ogg
```

### 6.2 文件命名规范

| 规则 | 示例 | 说明 |
|------|------|------|
| `{scene}_{type}.ogg` | `scene01_vocal.ogg` | 场景音频层 |
| `{speaker}_line{N}.ogg` | `hero_line001.ogg` | 角色对白 |
| `{scene}_{type}_{locale}.ogg` | `scene01_vocal_en.ogg` | 多语言变体 |
| `{scene}_layers.json` | `scene01_layers.json` | 层配置文件 |

---

## 7. 性能建议

### 7.1 音频格式

| 格式 | 推荐用途 | 说明 |
|------|---------|------|
| OGG Vorbis | 所有游戏音频 | UrhoX 默认支持，压缩率好 |
| WAV | 开发阶段中间产物 | 无损，但文件过大 |

### 7.2 加载策略

```lua
-- 短音效：预加载到内存
cache:GetResource("Sound", "Audio/Dialogue/hero_line001.ogg")

-- 长音频（BGM/环境音）：流式播放
local soundSource = node:CreateComponent("SoundSource")
local sound = cache:GetResource("Sound", "Audio/Layers/scene01_bgm.ogg")
sound.looped = true
soundSource:Play(sound)
```

### 7.3 内存管理

- 过场动画结束后，释放不再需要的音频层资源
- 使用 `cache:ReleaseResource()` 主动释放
- 环境音和 BGM 可以跨场景复用，不需要每次重新加载

---

## 8. 常见问题

### Q: 分离后的音频质量下降怎么办？

A: AI 分离不是完美的，可能会有残留或伪影。建议：
1. 使用最新版本的 Demucs (htdemucs_ft) 获取最佳质量
2. 对关键对白，优先使用原始单独录制的音频
3. 分离仅作为 BGM/环境音分层的辅助手段

### Q: 需要多少层？

A: 取决于游戏需求：
- **最简方案**：人声 + BGM（2 层）
- **标准方案**：人声 + BGM + 音效 + 环境音（4 层）
- **精细方案**：多角色人声分轨 + BGM + 多类型音效 + 环境音（6+ 层）

### Q: 运行时能动态添加层吗？

A: 可以。LayerSplitter 的 JSON 数据加载后是可修改的 Lua table，
也可以在运行时通过 TrackMixer 动态创建新轨道。

---

*本文档版本: 1.0*
*适用 Skill: smart-audio-pipeline*
