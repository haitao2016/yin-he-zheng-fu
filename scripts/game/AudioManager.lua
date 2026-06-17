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

-- P3-3: 音效限声（防止同类音效堆积破音）
local MAX_CONCURRENT_SFX = 3                -- 同类音效最大并发数
local sfxSlots_ = {}                        -- { [path] = { {node,src}, ... } }

-- P3-3: 自适应音乐强度
local adaptivePitch_     = 1.0              -- 当前自适应 pitch 值
local adaptiveTarget_    = 1.0              -- 目标 pitch
local ADAPTIVE_LERP      = 2.0             -- 每秒趋近速度

-- P3-3: 胜利静音间隔
local silenceTimer_      = 0.0              -- >0 时静音倒计时
local silenceCallback_   = nil              -- 静音结束后回调

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
    DEFEAT_STRINGS   = "audio/sfx/defeat_strings.ogg",
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
    -- 新舰种专属
    CARRIER_ATTACK   = "audio/sfx/carrier_attack.ogg",
    INTERCEPTOR_ENGINE = "audio/sfx/interceptor_engine.ogg",
    -- 成就
    ACHIEVEMENT_UNLOCK = "audio/sfx/achievement_unlock.ogg",
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

-- ─── SFX（P3-3: 限声机制 — 同类音效最多 MAX_CONCURRENT_SFX 条并发） ────────
function AudioManager.Play(path, gain)
    if not scene_ then return end
    gain = (gain or 1.0) * sfxVolume_ * (masterMute_ and 0.0 or 1.0)
    if gain <= 0 then return end
    local snd = cache:GetResource("Sound", path)
    if not snd then print("[Audio] SFX 未找到: " .. tostring(path)); return end

    -- P3-3: 限声 — 清理已停止的 slot，超出时停止最老的一条
    local slots = sfxSlots_[path]
    if not slots then slots = {}; sfxSlots_[path] = slots end
    -- 清理已结束的
    local j = 1
    for i = 1, #slots do
        local entry = slots[i]
        if entry.src and entry.src:IsPlaying() then
            slots[j] = entry; j = j + 1
        end
    end
    for i = j, #slots do slots[i] = nil end
    -- 超出并发上限 → 停止最早的
    while #slots >= MAX_CONCURRENT_SFX do
        local oldest = table.remove(slots, 1)
        if oldest.src then oldest.src:Stop() end
        if oldest.node then oldest.node:Remove() end
    end

    local node = scene_:CreateChild("SFX")
    local src  = node:CreateComponent("SoundSource")
    src.soundType      = "Effect"
    src.gain           = gain
    src.autoRemoveMode = REMOVE_NODE
    src:Play(snd)
    slots[#slots + 1] = { node = node, src = src }
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

-- ─── P3-3: BGM 音调（pitch）控制 ────────────────────────────────────────────
--- 设置当前播放中 BGM 的音调（1.0=正常，1.05=升5%）
--- SoundSource.frequency 属性以倍率控制播放速度（≈音调），默认 1.0
function AudioManager.SetBGMPitch(pitch)
    if bgmSource_     then bgmSource_.frequency     = pitch end
    if bgmFadeSource_ then bgmFadeSource_.frequency = pitch end
end

--- 恢复 BGM 音调为正常值
function AudioManager.ResetBGMPitch()
    if bgmSource_     then bgmSource_.frequency     = 1.0 end
    if bgmFadeSource_ then bgmFadeSource_.frequency = 1.0 end
    adaptivePitch_  = 1.0
    adaptiveTarget_ = 1.0
end

-- ─── P3-3: 自适应音乐强度 ───────────────────────────────────────────────────
--- 设置自适应 pitch 目标（平滑过渡）
function AudioManager.SetAdaptivePitchTarget(target)
    adaptiveTarget_ = math.max(0.9, math.min(1.1, target))
end

--- 获取当前自适应 pitch
function AudioManager.GetAdaptivePitch()
    return adaptivePitch_
end

-- ─── P3-3: 戏剧性静音间隔 ───────────────────────────────────────────────────
--- 静音一段时间后执行回调（用于胜利 fanfare 前的戏剧暂停）
function AudioManager.SilenceThen(duration, callback)
    silenceTimer_    = duration
    silenceCallback_ = callback
    -- 立即静音当前 BGM
    if bgmSource_     then bgmSource_.gain     = 0.0 end
    if bgmFadeSource_ then bgmFadeSource_.gain = 0.0 end
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

-- ─── Update（每帧调用，驱动淡入淡出 + 自适应pitch + 静音计时器） ─────────────
function AudioManager.Update(dt)
    -- 淡入淡出
    if isFading_ then
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

    -- P3-3: 自适应 pitch 平滑过渡
    if adaptivePitch_ ~= adaptiveTarget_ then
        local diff = adaptiveTarget_ - adaptivePitch_
        local step = ADAPTIVE_LERP * dt
        if math.abs(diff) <= step then
            adaptivePitch_ = adaptiveTarget_
        else
            adaptivePitch_ = adaptivePitch_ + (diff > 0 and step or -step)
        end
        if bgmSource_     then bgmSource_.frequency     = adaptivePitch_ end
        if bgmFadeSource_ then bgmFadeSource_.frequency = adaptivePitch_ end
    end

    -- P3-3: 戏剧性静音计时器
    if silenceTimer_ > 0 then
        silenceTimer_ = silenceTimer_ - dt
        if silenceTimer_ <= 0 then
            silenceTimer_ = 0
            if silenceCallback_ then
                silenceCallback_()
                silenceCallback_ = nil
            end
        end
    end
end

return AudioManager
