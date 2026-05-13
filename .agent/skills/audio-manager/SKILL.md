---
name: audio-manager
description: "UrhoX Lua audio management for games: BGM playback, SFX one-shot, volume control, music crossfade, and spatial 3D audio. Use when users need to (1) play background music (BGM) or switch tracks, (2) play sound effects (SFX/one-shot), (3) adjust master/music/sfx volume, (4) implement smooth BGM crossfade, (5) add 3D positional audio to enemies/objects, (6) pause/resume audio on game pause, (7) mute/unmute audio, (8) user says 'add sound', 'play music', 'audio system', 'sound effects', 'BGM'."
license: MIT
compatibility: "UrhoX engine (Lua 5.4). Requires audio files in assets/Sounds/ (OGG recommended). Uses SoundSource, SoundSource3D, Audio subsystem. No network access required. Compatible with all UrhoX scaffold types (2D, 3D, NanoVG)."
metadata:
  version: "1.0.0"
  author: "UrhoX Dev Team"
  tags: ["audio", "bgm", "sfx", "music", "sound", "urho3d", "urhox"]
---

# Audio Manager for UrhoX

Centralized audio module covering BGM, SFX, volume control, crossfade, and 3D spatial audio.

## AudioManager Module (scripts/AudioManager.lua)

Copy this to your project:

```lua
-- scripts/AudioManager.lua
-- UrhoX 音频管理器：BGM + SFX + 音量控制 + 3D 空间音频
local AudioManager = {}

-- ─── 内部状态 ───────────────────────────────────────────────────────────────
local scene_          = nil   ---@type Scene
local bgmNode_        = nil   ---@type Node
local bgmSource_      = nil   ---@type SoundSource
local bgmFadeNode_    = nil   ---@type Node   -- 交叉淡入淡出用的第二路
local bgmFadeSource_  = nil   ---@type SoundSource
local listenerNode_   = nil   ---@type Node

local bgmVolume_   = 1.0
local sfxVolume_   = 1.0
local masterMute_  = false
local fadeTimer_   = 0.0
local fadeDur_     = 0.0
local isFading_    = false

-- ─── 初始化 ─────────────────────────────────────────────────────────────────
-- @param scene  Scene 对象（用于创建节点）
-- @param opts   可选配置表 { bgmVolume, sfxVolume }
function AudioManager.Init(scene, opts)
    opts = opts or {}
    scene_       = scene
    bgmVolume_   = opts.bgmVolume or 1.0
    sfxVolume_   = opts.sfxVolume or 1.0

    -- BGM 主轨道节点
    bgmNode_      = scene_:CreateChild("BGMNode")
    bgmSource_    = bgmNode_:CreateComponent("SoundSource")
    bgmSource_.soundType = "Music"
    bgmSource_.gain      = bgmVolume_

    -- BGM 淡入淡出备用节点
    bgmFadeNode_   = scene_:CreateChild("BGMFadeNode")
    bgmFadeSource_ = bgmFadeNode_:CreateComponent("SoundSource")
    bgmFadeSource_.soundType = "Music"
    bgmFadeSource_.gain      = 0.0

    -- SoundListener（3D 音频用，绑定到相机节点效果更好）
    listenerNode_ = scene_:CreateChild("AudioListener")
    listenerNode_:CreateComponent("SoundListener")
    audio.listener = listenerNode_:GetComponent("SoundListener")

    -- 初始化全局音量
    audio:SetMasterGain("Music",  bgmVolume_)
    audio:SetMasterGain("Effect", sfxVolume_)
end

-- ─── BGM 播放 ────────────────────────────────────────────────────────────────
-- 立即切换 BGM（无淡入淡出）
-- @param path  资源路径，如 "Sounds/bgm_main.ogg"
function AudioManager.PlayBGM(path)
    if not bgmSource_ then return end
    local snd = cache:GetResource("Sound", path)
    if not snd then
        print("[AudioManager] BGM 未找到: " .. tostring(path))
        return
    end
    snd.looped = true
    bgmSource_:Play(snd)
    bgmSource_.gain = masterMute_ and 0.0 or bgmVolume_
end

-- 淡入淡出切换 BGM
-- @param path   新 BGM 路径
-- @param dur    淡入淡出时长（秒），默认 1.0
function AudioManager.CrossfadeBGM(path, dur)
    if not bgmSource_ then return end
    dur = dur or 1.0
    local snd = cache:GetResource("Sound", path)
    if not snd then
        print("[AudioManager] CrossfadeBGM 资源未找到: " .. tostring(path))
        return
    end
    snd.looped = true
    -- 新轨从 0 音量开始播放
    bgmFadeSource_:Play(snd)
    bgmFadeSource_.gain = 0.0
    fadeDur_   = dur
    fadeTimer_ = 0.0
    isFading_  = true
end

-- 停止 BGM
function AudioManager.StopBGM()
    if bgmSource_ then bgmSource_:Stop() end
end

-- ─── SFX 播放 ────────────────────────────────────────────────────────────────
-- 在场景中播放一次性音效（one-shot），自动回收
-- @param path    资源路径，如 "Sounds/jump.ogg"
-- @param gain    音量 0.0~1.0，默认 1.0
function AudioManager.PlaySFX(path, gain)
    if not scene_ then return end
    gain = (gain or 1.0) * sfxVolume_ * (masterMute_ and 0.0 or 1.0)
    local snd = cache:GetResource("Sound", path)
    if not snd then
        print("[AudioManager] SFX 未找到: " .. tostring(path))
        return
    end
    local node = scene_:CreateChild("SFX_OneShot")
    local src  = node:CreateComponent("SoundSource")
    src.soundType      = "Effect"
    src.gain           = gain
    src.autoRemoveMode = REMOVE_COMPONENT  -- 播完自动销毁
    src:Play(snd)
end

-- ─── 音量控制 ─────────────────────────────────────────────────────────────────
function AudioManager.SetBGMVolume(v)
    bgmVolume_ = math.max(0, math.min(1, v))
    audio:SetMasterGain("Music", bgmVolume_)
    if bgmSource_ then bgmSource_.gain = masterMute_ and 0.0 or bgmVolume_ end
end

function AudioManager.SetSFXVolume(v)
    sfxVolume_ = math.max(0, math.min(1, v))
    audio:SetMasterGain("Effect", sfxVolume_)
end

function AudioManager.SetMute(mute)
    masterMute_ = mute
    audio:SetMasterGain("Music",  mute and 0.0 or bgmVolume_)
    audio:SetMasterGain("Effect", mute and 0.0 or sfxVolume_)
end

function AudioManager.IsMuted() return masterMute_ end
function AudioManager.GetBGMVolume() return bgmVolume_ end
function AudioManager.GetSFXVolume() return sfxVolume_ end

-- ─── 暂停/恢复 ────────────────────────────────────────────────────────────────
function AudioManager.PauseAll()
    audio:PauseSoundType("Music")
    audio:PauseSoundType("Effect")
end

function AudioManager.ResumeAll()
    audio:ResumeSoundType("Music")
    audio:ResumeSoundType("Effect")
end

-- ─── Update（必须每帧调用） ───────────────────────────────────────────────────
-- @param dt  时间步长（秒）
function AudioManager.Update(dt)
    if not isFading_ then return end
    fadeTimer_ = fadeTimer_ + dt
    local t = math.min(fadeTimer_ / fadeDur_, 1.0)
    -- 旧轨淡出，新轨淡入
    local newVol = masterMute_ and 0.0 or bgmVolume_
    bgmSource_.gain     = newVol * (1.0 - t)
    bgmFadeSource_.gain = newVol * t
    if t >= 1.0 then
        -- 交换：fade 节点成为主轨
        bgmSource_:Stop()
        bgmSource_.gain     = newVol
        -- 交换节点引用
        bgmNode_,     bgmFadeNode_     = bgmFadeNode_,     bgmNode_
        bgmSource_,   bgmFadeSource_   = bgmFadeSource_,   bgmSource_
        bgmFadeSource_.gain = 0.0
        isFading_ = false
    end
end

-- ─── 3D 空间音效 ─────────────────────────────────────────────────────────────
-- 将 SoundListener 绑定到相机节点（在 PostUpdate 中调用更准确）
-- @param cameraNode  相机所在 Node
function AudioManager.UpdateListenerPosition(cameraNode)
    if listenerNode_ and cameraNode then
        listenerNode_.worldPosition = cameraNode.worldPosition
        listenerNode_.worldRotation = cameraNode.worldRotation
    end
end

-- 给节点添加 3D 音效组件
-- @param node       声源节点
-- @param path       音效路径
-- @param nearDist   近距离（无衰减），默认 2.0 米
-- @param farDist    远距离（完全衰减），默认 20.0 米
-- @param looped     是否循环，默认 false
-- @return SoundSource3D
function AudioManager.AddSpatialSound(node, path, nearDist, farDist, looped)
    local snd = cache:GetResource("Sound", path)
    if not snd then
        print("[AudioManager] 空间音效未找到: " .. tostring(path))
        return nil
    end
    snd.looped = looped or false
    local src = node:CreateComponent("SoundSource3D")
    src.soundType = "Effect"
    src.gain      = sfxVolume_
    src:SetDistanceAttenuation(nearDist or 2.0, farDist or 20.0, 2.0)
    src:Play(snd)
    return src
end

return AudioManager
```

## Integration

### main.lua

```lua
local AudioManager = require "AudioManager"

function Start()
    local scene = Scene()
    -- ... 场景初始化 ...
    AudioManager.Init(scene, { bgmVolume = 0.8, sfxVolume = 1.0 })
    AudioManager.PlayBGM("Sounds/bgm_menu.ogg")
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    AudioManager.Update(dt)   -- ← 必须每帧调用（淡入淡出需要）
end
```

### Pause/Resume

```lua
-- 游戏暂停
AudioManager.PauseAll()

-- 游戏恢复
AudioManager.ResumeAll()
```

### BGM 切换（淡入淡出）

```lua
-- 无缝切换，1.5 秒淡入淡出
AudioManager.CrossfadeBGM("Sounds/bgm_battle.ogg", 1.5)
```

## Key Rules

1. `soundType` 必须设置为 `"Music"` 或 `"Effect"`，否则 `SetMasterGain` 无法分类控制
2. `autoRemoveMode = REMOVE_COMPONENT` 让 one-shot 音效播完自动清理，避免内存泄漏
3. 音频文件统一放 `assets/Sounds/`，引用时写 `"Sounds/xxx.ogg"`（不加 `assets/` 前缀）
4. OGG Vorbis 格式推荐：压缩率高，引擎原生支持，WAV 仅用于极短音效

## Spatial Audio Quick Setup

```lua
-- 3D 游戏：每帧更新 Listener 位置（PostUpdate 事件中）
SubscribeToEvent("PostUpdate", function(_, ed)
    AudioManager.UpdateListenerPosition(cameraNode)
end)

-- 给敌人添加环境音
AudioManager.AddSpatialSound(enemyNode, "Sounds/enemy_ambient.ogg",
    2.0,   -- nearDistance
    15.0,  -- farDistance
    true   -- looped
)
```

## References

- Full API details → `engine-docs/api/audio.md`
