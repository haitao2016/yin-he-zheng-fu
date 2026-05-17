-- ============================================================================
-- game/ui/SettingsPanel.lua  -- 游戏设置面板（BGM/SFX滑块 + 静音开关）
-- ============================================================================
local UICommon = require "game.ui.UICommon"
local Audio    = require "game.Systems"  -- Audio 由 GameUI 通过 SetAudio 注入

local SettingsPanel = {}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local visible_          = false
local bgmVol_           = 0.7
local sfxVol_           = 1.0
local mute_             = false

-- 滑块拖拽状态
local dragSlider_       = nil              -- "bgm" | "sfx" | nil
local dragCtx_          = { trackX = 0, trackW = 1 }
local touchId_          = nil              -- 触摸拖拽时的 touch ID
local sliderRects_      = {}               -- {key={trackX,trackW,trackY}} 每帧更新

local SETTINGS_FILE     = "galaxy_settings.json"

-- Audio 模块引用（由 GameUI.Init 通过 SettingsPanel.SetAudio 注入）
local Audio_            = nil

-- ── 持久化 ───────────────────────────────────────────────────────────────────
local function saveSettings()
    local cjson = require "cjson"
    local data = cjson.encode({
        bgmVolume = bgmVol_,
        sfxVolume = sfxVol_,
        mute      = mute_,
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

    -- 面板尺寸和位置（居中）
    local pw, ph = 340, 280
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
