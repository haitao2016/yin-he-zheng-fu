-- ============================================================================
-- game/ui/SettingsPanel.lua  -- 游戏设置面板（音频 + 画质 + 色觉辅助 + FPS）
-- P3-3 V2.4: 性能优化与辅助功能
-- ============================================================================
local UICommon        = require "game.ui.UICommon"
local Audio           = require "game.Systems"  -- Audio 由 GameUI 通过 SetAudio 注入
local TutorialSystem  = require "game.ui.TutorialSystem"

local SettingsPanel = {}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local visible_          = false
local bgmVol_           = 0.7
local sfxVol_           = 1.0
local mute_             = false

-- P3-3: 画质档位 1=低 2=中 3=高
local qualityLevel_     = 2
-- P3-3: 色觉辅助模式 "normal" | "protanopia" | "tritanopia"
local colorblindMode_   = "normal"
-- P3-3: FPS 显示开关
local showFPS_          = false
-- P3-3: 自动暂停（切后台暂停）
local autoPause_        = true
-- P3-3: 新手引导开关
local tutorialEnabled_  = true
-- P3-3: FPS 计算
local fpsFrames_        = 0
local fpsTimer_         = 0
local fpsDisplay_       = 0

-- 滑块拖拽状态
local dragSlider_       = nil              -- "bgm" | "sfx" | nil
local dragCtx_          = { trackX = 0, trackW = 1 }
local touchId_          = nil              -- 触摸拖拽时的 touch ID
local sliderRects_      = {}               -- {key={trackX,trackW,trackY}} 每帧更新

local SETTINGS_FILE     = "galaxy_settings.json"

-- Audio 模块引用（由 GameUI.Init 通过 SettingsPanel.SetAudio 注入）
local Audio_            = nil

-- P3-3: 画质档位名称
local QUALITY_NAMES     = { "低", "中", "高" }
-- P3-3: 色觉模式名称
local COLORBLIND_NAMES  = { normal = "正常", protanopia = "红绿色盲", tritanopia = "蓝黄色盲" }
local COLORBLIND_MODES  = { "normal", "protanopia", "tritanopia" }

-- ── 持久化 ───────────────────────────────────────────────────────────────────
local function saveSettings()
    local cjson = require "cjson"
    local data = cjson.encode({
        bgmVolume        = bgmVol_,
        sfxVolume        = sfxVol_,
        mute             = mute_,
        qualityLevel     = qualityLevel_,
        colorblindMode   = colorblindMode_,
        showFPS          = showFPS_,
        autoPause        = autoPause_,
        tutorialEnabled  = tutorialEnabled_,
    })
    local f = File(SETTINGS_FILE, FILE_WRITE)
    if f:IsOpen() then f:WriteString(data); f:Close() end
end

local function loadSettings()
    if not fileSystem:FileExists(SETTINGS_FILE) then return end
    local f = File(SETTINGS_FILE, FILE_READ)
    if not f:IsOpen() then return end
    local raw = f:ReadString(); f:Close()
    local ok, data = pcall(require("cjson").decode, raw)
    if not ok or type(data) ~= "table" then return end
    bgmVol_ = tonumber(data.bgmVolume) or bgmVol_
    sfxVol_ = tonumber(data.sfxVolume) or sfxVol_
    mute_   = data.mute == true
    qualityLevel_   = math.max(1, math.min(3, tonumber(data.qualityLevel) or 2))
    colorblindMode_ = data.colorblindMode or "normal"
    showFPS_        = data.showFPS == true
    autoPause_      = data.autoPause ~= false  -- 默认开启
    tutorialEnabled_ = data.tutorialEnabled ~= false  -- 默认开启
    TutorialSystem.SetEnabled(tutorialEnabled_)
    if Audio_ then
        Audio_.SetBGMVolume(bgmVol_)
        Audio_.SetSFXVolume(sfxVol_)
        Audio_.SetMute(mute_)
    end
end

-- ── 渲染 ─────────────────────────────────────────────────────────────────────
local function render()
    if not visible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local cursorX = UICommon.cursorX
    local addHit  = UICommon.addHit

    -- 处理滑块拖拽（鼠标按住 或 手指正在拖拽）
    if dragSlider_ then
        if input:GetMouseButtonDown(MOUSEB_LEFT) or touchId_ ~= nil then
            local newVal = math.max(0, math.min(1,
                (cursorX - dragCtx_.trackX) / dragCtx_.trackW))
            if dragSlider_ == "bgm" then
                bgmVol_ = newVal
                if Audio_ then Audio_.SetBGMVolume(newVal) end
            elseif dragSlider_ == "sfx" then
                sfxVol_ = newVal
                if Audio_ then Audio_.SetSFXVolume(newVal) end
            end
        else
            saveSettings()
            dragSlider_ = nil
        end
    end

    -- 全屏半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)
    addHit(0, 0, screenW, screenH, function()
        visible_ = false
    end)

    -- 面板尺寸和位置（居中）— P3-3 加高以容纳新设置（含教程开关）
    local pw, ph = 360, 530
    local px = (screenW - pw) / 2
    local py = (screenH - ph) / 2

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(8, 12, 30, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    addHit(px, py, pw, ph, function() end)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
    nvgText(vg, px + pw / 2, py + 24, "⚙  游戏设置")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 40)
    nvgLineTo(vg, px + pw - 16, py + 40)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, 80))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 辅助：绘制带标签的水平滑块
    local function drawSlider(label, val, sx, sy, sw, sh, key)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
        nvgText(vg, sx, sy + sh / 2, label)

        local pctStr = string.format("%d%%", math.floor(val * 100))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 180, 255, 200))
        nvgText(vg, sx + sw, sy + sh / 2, pctStr)

        local trackX = sx + 70
        local trackW = sw - 70 - 36
        local trackY = sy + sh / 2
        sliderRects_[key] = { trackX = trackX, trackW = trackW, trackY = trackY }

        nvgBeginPath(vg)
        nvgRoundedRect(vg, trackX, trackY - 3, trackW, 6, 3)
        nvgFillColor(vg, nvgRGBA(30, 50, 90, 200)); nvgFill(vg)

        local fillW = trackW * val
        if fillW > 1 then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, trackX, trackY - 3, fillW, 6, 3)
            nvgFillColor(vg, nvgRGBA(60, 160, 255, 220)); nvgFill(vg)
        end

        local thumbX   = trackX + fillW
        local isDragging = (dragSlider_ == key)
        nvgBeginPath(vg); nvgCircle(vg, thumbX, trackY, isDragging and 9 or 7)
        nvgFillColor(vg, isDragging and nvgRGBA(180, 230, 255, 255) or nvgRGBA(120, 200, 255, 255))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 230, 255, 220))
        nvgStrokeWidth(vg, isDragging and 2 or 1.5); nvgStroke(vg)

        addHit(trackX - 8, trackY - 12, trackW + 16, 24, function()
            local newVal = math.max(0, math.min(1, (cursorX - trackX) / trackW))
            if key == "bgm" then
                bgmVol_ = newVal
                if Audio_ then Audio_.SetBGMVolume(newVal) end
            elseif key == "sfx" then
                sfxVol_ = newVal
                if Audio_ then Audio_.SetSFXVolume(newVal) end
            end
            dragSlider_ = key
            dragCtx_.trackX = trackX
            dragCtx_.trackW = trackW
        end)
    end

    local rowH  = 40
    local slotX = px + 16
    local slotW = pw - 32
    local row1Y = py + 52
    drawSlider("BGM 音乐", bgmVol_, slotX, row1Y, slotW, rowH, "bgm")

    local row2Y = row1Y + rowH + 8
    drawSlider("SFX 音效", sfxVol_, slotX, row2Y, slotW, rowH, "sfx")

    -- 静音开关
    local row3Y  = row2Y + rowH + 12
    local togW, togH = 52, 26
    local togX   = px + pw - 16 - togW
    local togY   = row3Y + 4

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
    nvgText(vg, slotX, togY + togH / 2, "全局静音")

    nvgBeginPath(vg)
    nvgRoundedRect(vg, togX, togY, togW, togH, togH / 2)
    nvgFillColor(vg, mute_ and nvgRGBA(60,160,255,200) or nvgRGBA(30,50,90,200))
    nvgFill(vg)
    nvgStrokeColor(vg, mute_ and nvgRGBA(100,200,255,180) or nvgRGBA(60,100,180,100))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local dotX = mute_ and (togX + togW - togH/2 - 2) or (togX + togH/2 + 2)
    nvgBeginPath(vg); nvgCircle(vg, dotX, togY + togH/2, togH/2 - 3)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, 255)); nvgFill(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, mute_ and nvgRGBA(255,255,255,200) or nvgRGBA(100,140,200,180))
    nvgText(vg, togX + togW/2, togY + togH/2, mute_ and "ON" or "OFF")
    addHit(togX, togY, togW, togH, function()
        mute_ = not mute_
        if Audio_ then Audio_.SetMute(mute_) end
        saveSettings()
    end)

    -- ── P3-3: 分隔线（音频区域与性能/辅助区域之间）──
    local sepY1 = row3Y + togH + 12
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, sepY1)
    nvgLineTo(vg, px + pw - 16, sepY1)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, 60))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ── P3-3: 画质档位（低/中/高三按钮）──
    local qRow = sepY1 + 10
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
    nvgText(vg, slotX, qRow + 14, "画质档位")

    local qBtnW = 56
    local qBtnH = 26
    local qStartX = px + pw - 16 - qBtnW * 3 - 8
    for i = 1, 3 do
        local bx = qStartX + (i - 1) * (qBtnW + 4)
        local isActive = (qualityLevel_ == i)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, qRow + 2, qBtnW, qBtnH, 5)
        if isActive then
            nvgFillColor(vg, nvgRGBA(40, 120, 220, 220))
        else
            nvgFillColor(vg, nvgRGBA(20, 40, 80, 180))
        end
        nvgFill(vg)
        nvgStrokeColor(vg, isActive and nvgRGBA(80, 180, 255, 200) or nvgRGBA(50, 90, 160, 120))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(220, 245, 255, 255) or nvgRGBA(120, 160, 200, 200))
        nvgText(vg, bx + qBtnW / 2, qRow + 2 + qBtnH / 2, QUALITY_NAMES[i])
        addHit(bx, qRow + 2, qBtnW, qBtnH, function()
            qualityLevel_ = i
            saveSettings()
        end)
    end

    -- ── P3-3: 色觉辅助模式（三按钮循环）──
    local cbRow = qRow + qBtnH + 14
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
    nvgText(vg, slotX, cbRow + 14, "色觉辅助")

    local cbBtnW = 72
    local cbBtnH = 26
    local cbStartX = px + pw - 16 - cbBtnW
    -- 当前模式按钮（点击切换到下一个模式）
    local curModeIdx = 1
    for idx, m in ipairs(COLORBLIND_MODES) do
        if m == colorblindMode_ then curModeIdx = idx; break end
    end
    local displayName = COLORBLIND_NAMES[colorblindMode_] or "正常"
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbStartX, cbRow + 2, cbBtnW, cbBtnH, 5)
    local isCbActive = (colorblindMode_ ~= "normal")
    nvgFillColor(vg, isCbActive and nvgRGBA(120, 80, 20, 200) or nvgRGBA(20, 40, 80, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, isCbActive and nvgRGBA(255, 180, 60, 180) or nvgRGBA(50, 90, 160, 120))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, isCbActive and nvgRGBA(255, 220, 120, 255) or nvgRGBA(140, 180, 220, 200))
    nvgText(vg, cbStartX + cbBtnW / 2, cbRow + 2 + cbBtnH / 2, displayName)
    addHit(cbStartX, cbRow + 2, cbBtnW, cbBtnH, function()
        local nextIdx = (curModeIdx % #COLORBLIND_MODES) + 1
        colorblindMode_ = COLORBLIND_MODES[nextIdx]
        saveSettings()
    end)

    -- ── P3-3: FPS 显示开关 ──
    local fpsRow = cbRow + cbBtnH + 14
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
    nvgText(vg, slotX, fpsRow + 14, "显示 FPS")

    local fTogW, fTogH = 52, 26
    local fTogX = px + pw - 16 - fTogW
    local fTogY = fpsRow + 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, fTogX, fTogY, fTogW, fTogH, fTogH / 2)
    nvgFillColor(vg, showFPS_ and nvgRGBA(40,160,80,200) or nvgRGBA(30,50,90,200))
    nvgFill(vg)
    nvgStrokeColor(vg, showFPS_ and nvgRGBA(80,220,120,180) or nvgRGBA(60,100,180,100))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local fDotX = showFPS_ and (fTogX + fTogW - fTogH/2 - 2) or (fTogX + fTogH/2 + 2)
    nvgBeginPath(vg); nvgCircle(vg, fDotX, fTogY + fTogH/2, fTogH/2 - 3)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, 255)); nvgFill(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, showFPS_ and nvgRGBA(255,255,255,200) or nvgRGBA(100,140,200,180))
    nvgText(vg, fTogX + fTogW/2, fTogY + fTogH/2, showFPS_ and "ON" or "OFF")
    addHit(fTogX, fTogY, fTogW, fTogH, function()
        showFPS_ = not showFPS_
        saveSettings()
    end)

    -- ── P3-3: 自动暂停开关 ──
    local apRow = fpsRow + fTogH + 14
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
    nvgText(vg, slotX, apRow + 14, "切后台自动暂停")

    local apTogW, apTogH = 52, 26
    local apTogX = px + pw - 16 - apTogW
    local apTogY = apRow + 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, apTogX, apTogY, apTogW, apTogH, apTogH / 2)
    nvgFillColor(vg, autoPause_ and nvgRGBA(40,160,80,200) or nvgRGBA(30,50,90,200))
    nvgFill(vg)
    nvgStrokeColor(vg, autoPause_ and nvgRGBA(80,220,120,180) or nvgRGBA(60,100,180,100))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local apDotX = autoPause_ and (apTogX + apTogW - apTogH/2 - 2) or (apTogX + apTogH/2 + 2)
    nvgBeginPath(vg); nvgCircle(vg, apDotX, apTogY + apTogH/2, apTogH/2 - 3)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, 255)); nvgFill(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, autoPause_ and nvgRGBA(255,255,255,200) or nvgRGBA(100,140,200,180))
    nvgText(vg, apTogX + apTogW/2, apTogY + apTogH/2, autoPause_ and "ON" or "OFF")
    addHit(apTogX, apTogY, apTogW, apTogH, function()
        autoPause_ = not autoPause_
        saveSettings()
    end)

    -- ── P3-3: 新手引导开关 + 重置 ──
    local tutRow = apRow + apTogH + 14
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
    nvgText(vg, slotX, tutRow + 14, "新手引导")

    -- 重置按钮（小型）
    local rstW, rstH = 40, 22
    local rstX = px + pw - 16 - togW - 8 - rstW
    local rstY = tutRow + 4
    nvgBeginPath(vg)
    nvgRoundedRect(vg, rstX, rstY, rstW, rstH, 4)
    nvgFillColor(vg, nvgRGBA(80, 40, 20, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 140, 60, 140))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 180, 100, 220))
    nvgText(vg, rstX + rstW / 2, rstY + rstH / 2, "重置")
    addHit(rstX, rstY, rstW, rstH, function()
        TutorialSystem.Reset()
        tutorialEnabled_ = true
        TutorialSystem.SetEnabled(true)
        saveSettings()
    end)

    -- 教程开关 toggle
    local tTogW, tTogH = 52, 26
    local tTogX = px + pw - 16 - tTogW
    local tTogY = tutRow + 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, tTogX, tTogY, tTogW, tTogH, tTogH / 2)
    nvgFillColor(vg, tutorialEnabled_ and nvgRGBA(40,160,80,200) or nvgRGBA(30,50,90,200))
    nvgFill(vg)
    nvgStrokeColor(vg, tutorialEnabled_ and nvgRGBA(80,220,120,180) or nvgRGBA(60,100,180,100))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local tDotX = tutorialEnabled_ and (tTogX + tTogW - tTogH/2 - 2) or (tTogX + tTogH/2 + 2)
    nvgBeginPath(vg); nvgCircle(vg, tDotX, tTogY + tTogH/2, tTogH/2 - 3)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, 255)); nvgFill(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, tutorialEnabled_ and nvgRGBA(255,255,255,200) or nvgRGBA(100,140,200,180))
    nvgText(vg, tTogX + tTogW/2, tTogY + tTogH/2, tutorialEnabled_ and "ON" or "OFF")
    addHit(tTogX, tTogY, tTogW, tTogH, function()
        tutorialEnabled_ = not tutorialEnabled_
        TutorialSystem.SetEnabled(tutorialEnabled_)
        saveSettings()
    end)

    -- 分隔线（按钮上方）
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + ph - 48)
    nvgLineTo(vg, px + pw - 16, py + ph - 48)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, 60))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 关闭按钮
    local cbw, cbh = 120, 32
    local cbx = px + (pw - cbw) / 2
    local cby = py + ph - cbh - 10
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbx, cby, cbw, cbh, 7)
    nvgFillColor(vg, nvgRGBA(20, 60, 140, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 160))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 240))
    nvgText(vg, cbx + cbw / 2, cby + cbh / 2, "关闭")
    addHit(cbx, cby, cbw, cbh, function()
        visible_ = false
    end)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 注入 Audio 模块（由 GameUI.Init 调用）
function SettingsPanel.SetAudio(audioModule)
    Audio_ = audioModule
end

--- 从磁盘加载设置（初始化时调用）
function SettingsPanel.Load()
    loadSettings()
end

--- 显示设置面板
function SettingsPanel.Show()
    visible_ = true
end

--- 隐藏设置面板
function SettingsPanel.Hide()
    visible_ = false
end

--- 是否当前可见
function SettingsPanel.IsVisible()
    return visible_
end

--- 切换显示状态
function SettingsPanel.Toggle()
    visible_ = not visible_
end

--- 渲染（每帧调用）
function SettingsPanel.Render()
    render()
end

--- 获取滑块区域（供 OnTouchBegin 命中检测）
function SettingsPanel.GetSliderRects()
    return sliderRects_
end

--- 获取当前音量值（供外部读取）
function SettingsPanel.GetVolumes()
    return bgmVol_, sfxVol_, mute_
end

-- ── P3-3 公开 API ────────────────────────────────────────────────────────────

--- 获取画质档位 1=低 2=中 3=高
function SettingsPanel.GetQualityLevel()
    return qualityLevel_
end

--- 获取色觉辅助模式 "normal" | "protanopia" | "tritanopia"
function SettingsPanel.GetColorblindMode()
    return colorblindMode_
end

--- FPS 是否显示
function SettingsPanel.IsFPSVisible()
    return showFPS_
end

--- P3-3: 自动暂停是否开启
function SettingsPanel.GetAutoPause()
    return autoPause_
end

--- 每帧更新 FPS 计数器（由 GameUI.Update 调用）
function SettingsPanel.UpdateFPS(dt)
    fpsFrames_ = fpsFrames_ + 1
    fpsTimer_  = fpsTimer_ + dt
    if fpsTimer_ >= 0.5 then
        fpsDisplay_ = math.floor(fpsFrames_ / fpsTimer_ + 0.5)
        fpsFrames_  = 0
        fpsTimer_   = 0
    end
end

--- 渲染 FPS 计数器（在主 HUD 上方绘制，面板外调用）
function SettingsPanel.RenderFPS()
    if not showFPS_ then return end
    local vg = UICommon.vg
    local screenW = UICommon.screenW
    -- 右上角显示 FPS
    local txt = string.format("FPS: %d", fpsDisplay_)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    -- 阴影
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
    nvgText(vg, screenW - 9, 9, txt)
    -- 前景
    local color
    if fpsDisplay_ >= 55 then
        color = nvgRGBA(80, 220, 120, 240)
    elseif fpsDisplay_ >= 30 then
        color = nvgRGBA(240, 200, 60, 240)
    else
        color = nvgRGBA(255, 80, 80, 240)
    end
    nvgFillColor(vg, color)
    nvgText(vg, screenW - 10, 8, txt)
end

--- 色觉辅助颜色变换（供需要适配色觉的模块调用）
--- @param r number 0-255
--- @param g number 0-255
--- @param b number 0-255
--- @param a number|nil 0-255 (默认255)
--- @return number, number, number, number
function SettingsPanel.TransformColor(r, g, b, a)
    a = a or 255
    if colorblindMode_ == "normal" then
        return r, g, b, a
    elseif colorblindMode_ == "protanopia" then
        -- 红绿色盲模拟：增强蓝黄通道对比，降低红绿区分
        local nr = 0.567 * r + 0.433 * g
        local ng = 0.558 * r + 0.442 * g
        local nb = 0.242 * g + 0.758 * b
        return math.min(255, math.floor(nr)), math.min(255, math.floor(ng)), math.min(255, math.floor(nb)), a
    elseif colorblindMode_ == "tritanopia" then
        -- 蓝黄色盲模拟：增强红绿通道对比，降低蓝黄区分
        local nr = 0.95 * r + 0.05 * g
        local ng = 0.433 * g + 0.567 * b
        local nb = 0.475 * g + 0.525 * b
        return math.min(255, math.floor(nr)), math.min(255, math.floor(ng)), math.min(255, math.floor(nb)), a
    end
    return r, g, b, a
end

--- 画质缩放因子（低=0.5, 中=1.0, 高=1.5）— 用于粒子/星星数量等
function SettingsPanel.GetQualityScale()
    local scales = { 0.5, 1.0, 1.5 }
    return scales[qualityLevel_] or 1.0
end

--- 触摸按下时处理滑块命中（由 GameUI.OnTouchBegin 委托调用）
--- 返回 true 表示已消费事件
function SettingsPanel.OnTouchBegin(id, mx, my)
    if not visible_ then return false end
    for key, rect in pairs(sliderRects_) do
        if mx >= rect.trackX - 8 and mx <= rect.trackX + rect.trackW + 8
           and my >= rect.trackY - 12 and my <= rect.trackY + 12 then
            touchId_           = id
            dragSlider_        = key
            dragCtx_.trackX    = rect.trackX
            dragCtx_.trackW    = rect.trackW
            UICommon.cursorX   = mx
            return true
        end
    end
    return false
end

--- 触摸移动时跟随滑块（由 GameUI.OnTouchMove 委托调用）
--- 返回 true 表示已消费事件
function SettingsPanel.OnTouchMove(id, mx)
    if touchId_ == id then
        UICommon.cursorX = mx
        return true
    end
    return false
end

--- 触摸结束时保存设置（由 GameUI.OnTouchEnd 委托调用）
--- 返回 true 表示已消费事件
function SettingsPanel.OnTouchEnd(id)
    if touchId_ == id then
        touchId_    = nil
        dragSlider_ = nil
        saveSettings()
        return true
    end
    return false
end

return SettingsPanel
