-- ============================================================================
-- game/AudioManager.lua  -- 银河征服 音频管理器
-- BGM / SFX / 音量控制 / 淡入淡出
-- ============================================================================
local AudioManager = {}

-- ─── 内部状态 ────────────────────────────────────────────────────────────────
---@type Scene
local scene_          = nil
---@type Node
local bgmNode_        = nil
---@type SoundSource
local bgmSource_      = nil
---@type Node
local bgmFadeNode_    = nil
---@type SoundSource
local bgmFadeSource_  = nil

local bgmVolume_  = 0.7
local sfxVolume_  = 1.0
local masterMute_ = false
local fadeTimer_  = 0.0
local fadeDur_    = 0.0
local isFading_   = false

-- ─── BGM 路径常量 ────────────────────────────────────────────────────────────
local BGM = {
    GALAXY_MAIN      = "audio/bgm/galaxy_main.ogg",
    BATTLE_THEME     = "audio/bgm/battle_theme.ogg",
    VICTORY_FANFARE  = "audio/bgm/victory_fanfare.ogg",
}
AudioManager.BGM = BGM

-- ─── 音效路径常量 ─────────────────────────────────────────────────────────────
local SFX = {
    -- UI
    BTN_CLICK        = "audio/sfx/btn_click.ogg",
    BTN_CONFIRM      = "audio/sfx/btn_confirm.ogg",
    -- 建造 / 研发
    BUILD_START      = "audio/sfx/build_start.ogg",
    BUILD_COMPLETE   = "audio/sfx/build_complete.ogg",
    RESEARCH_START   = "audio/sfx/research_start.ogg",
    RESEARCH_COMPLETE= "audio/sfx/research_complete.ogg",
    -- 星球 / 编队
    COLONIZE_SUCCESS = "audio/sfx/colonize_success.ogg",
    FLEET_DEPLOY     = "audio/sfx/fleet_deploy.ogg",
    FLEET_MOVE       = "audio/sfx/fleet_move.ogg",
    -- 战斗
    BATTLE_START     = "audio/sfx/battle_start.ogg",
    BATTLE_WIN       = "audio/sfx/battle_win.ogg",
    BATTLE_LOSE      = "audio/sfx/battle_lose.ogg",
    SHOOT_LASER      = "audio/sfx/shoot_laser.ogg",
    SHOOT_MISSILE    = "audio/sfx/shoot_missile.ogg",
    EXPLOSION_SMALL  = "audio/sfx/explosion_small.ogg",
    EXPLOSION_BIG    = "audio/sfx/explosion_big.ogg",
    WAVE_INCOMING    = "audio/sfx/wave_incoming.ogg",
    -- 玩家成长
    LEVELUP          = "audio/sfx/levelup.ogg",
    -- 海盗
    PIRATE_WARNING   = "audio/sfx/pirate_warning.ogg",
    -- 市场
    MARKET_TRADE     = "audio/sfx/market_trade.ogg",
    -- 通知
    NOTIFY_INFO      = "audio/sfx/notify_info.ogg",
    NOTIFY_SUCCESS   = "audio/sfx/notify_success.ogg",
    NOTIFY_WARN      = "audio/sfx/notify_warn.ogg",
    NOTIFY_ERROR     = "audio/sfx/notify_error.ogg",
    -- 胜利
    VICTORY          = "audio/sfx/victory_sfx.ogg",
}
AudioManager.SFX = SFX

-- ─── 初始化 ──────────────────────────────────────────────────────────────────
function AudioManager.Init(scene)
    scene_ = scene

    bgmNode_      = scene_:CreateChild("BGMNode")
    bgmSource_    = bgmNode_:CreateComponent("SoundSource")
    bgmSource_.soundType = "Music"
    bgmSource_.gain      = bgmVolume_

    bgmFadeNode_   = scene_:CreateChild("BGMFadeNode")
    bgmFadeSource_ = bgmFadeNode_:CreateComponent("SoundSource")
    bgmFadeSource_.soundType = "Music"
    bgmFadeSource_.gain      = 0.0

    local listenerNode = scene_:CreateChild("AudioListener")
    listenerNode:CreateComponent("SoundListener")
    audio.listener = listenerNode:GetComponent("SoundListener")

    audio:SetMasterGain("Music",  bgmVolume_)
    audio:SetMasterGain("Effect", sfxVolume_)
end

-- ─── BGM ─────────────────────────────────────────────────────────────────────
function AudioManager.PlayBGM(path, dur, looped)
    if not bgmSource_ then return end
    dur    = dur    or 0
    looped = (looped ~= false)  -- 默认循环，传 false 则单次播放
    local snd = cache:GetResource("Sound", path)
    if not snd then print("[Audio] BGM 未找到: " .. tostring(path)); return end
    snd.looped = looped
    if dur > 0 and bgmSource_:IsPlaying() then
        bgmFadeSource_:Play(snd)
        bgmFadeSource_.gain = 0.0
        fadeDur_   = dur
        fadeTimer_ = 0.0
        isFading_  = true
    else
        bgmSource_:Play(snd)
        bgmSource_.gain = masterMute_ and 0.0 or bgmVolume_
    end
end

function AudioManager.StopBGM()
    if bgmSource_ then bgmSource_:Stop() end
    if bgmFadeSource_ then bgmFadeSource_:Stop() end
    isFading_ = false
end

-- ─── SFX ─────────────────────────────────────────────────────────────────────
function AudioManager.Play(path, gain)
    if not scene_ then return end
    gain = (gain or 1.0) * sfxVolume_ * (masterMute_ and 0.0 or 1.0)
    if gain <= 0 then return end
    local snd = cache:GetResource("Sound", path)
    if not snd then print("[Audio] SFX 未找到: " .. tostring(path)); return end
    local node = scene_:CreateChild("SFX")
    local src  = node:CreateComponent("SoundSource")
    src.soundType      = "Effect"
    src.gain           = gain
    src.autoRemoveMode = REMOVE_NODE
    src:Play(snd)
end

-- ─── 通知音效（按类型自动匹配） ─────────────────────────────────────────────
function AudioManager.PlayNotify(ntype)
    local t = ntype or "info"
    if     t == "success" then AudioManager.Play(SFX.NOTIFY_SUCCESS)
    elseif t == "error"   then AudioManager.Play(SFX.NOTIFY_ERROR)
    elseif t == "warn" or t == "warning" then AudioManager.Play(SFX.NOTIFY_WARN)
    else                       AudioManager.Play(SFX.NOTIFY_INFO) end
end

-- ─── 音量控制 ────────────────────────────────────────────────────────────────
function AudioManager.SetBGMVolume(v)
    bgmVolume_ = math.max(0, math.min(1, v))
    audio:SetMasterGain("Music", masterMute_ and 0.0 or bgmVolume_)
end

function AudioManager.SetSFXVolume(v)
    sfxVolume_ = math.max(0, math.min(1, v))
    audio:SetMasterGain("Effect", masterMute_ and 0.0 or sfxVolume_)
end

function AudioManager.SetMute(mute)
    masterMute_ = mute
    audio:SetMasterGain("Music",  mute and 0.0 or bgmVolume_)
    audio:SetMasterGain("Effect", mute and 0.0 or sfxVolume_)
end

-- ─── 暂停 / 恢复 ──────────────────────────────────────────────────────────────
function AudioManager.PauseAll()
    audio:PauseSoundType("Music")
    audio:PauseSoundType("Effect")
end

function AudioManager.ResumeAll()
    audio:ResumeSoundType("Music")
    audio:ResumeSoundType("Effect")
end

-- ─── Update（每帧调用，驱动淡入淡出） ────────────────────────────────────────
function AudioManager.Update(dt)
    if not isFading_ then return end
    fadeTimer_ = fadeTimer_ + dt
    local t   = math.min(fadeTimer_ / fadeDur_, 1.0)
    local vol = masterMute_ and 0.0 or bgmVolume_
    bgmSource_.gain     = vol * (1.0 - t)
    bgmFadeSource_.gain = vol * t
    if t >= 1.0 then
        bgmSource_:Stop()
        bgmNode_,     bgmFadeNode_     = bgmFadeNode_,     bgmNode_
        bgmSource_,   bgmFadeSource_   = bgmFadeSource_,   bgmSource_
        bgmSource_.gain     = vol
        bgmFadeSource_.gain = 0.0
        isFading_ = false
    end
end

return AudioManager
