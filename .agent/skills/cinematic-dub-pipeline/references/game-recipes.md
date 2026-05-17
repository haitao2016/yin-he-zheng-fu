# 过场配音实战方案

> 6 个完整的游戏过场配音集成方案，可直接用于 UrhoX Lua 项目。

---

## 方案 1: RPG 开场 CG — 视频背景 + 配音字幕

**场景**: 游戏启动后播放一段预渲染 CG 视频，上面叠加配音和字幕。

### 剧本示例

```json
{
  "id": "rpg_prologue",
  "title": "序章：传说的开始",
  "scenes": [
    {
      "id": "scene_01",
      "background": "videos/prologue_cg.mp4",
      "bgm": "Sounds/bgm_epic_intro.ogg",
      "bgmVolume": 0.25,
      "lines": [
        {
          "id": "line_001",
          "character": "narrator",
          "text": "千年之前，五位贤者以生命为代价封印了混沌之源。",
          "duration": 5.0,
          "emotion": "serious",
          "subtitle": true,
          "pause_after": 1.0
        },
        {
          "id": "line_002",
          "character": "narrator",
          "text": "然而封印终有破碎之日，世界再次陷入黑暗的阴影。",
          "duration": 4.5,
          "emotion": "dramatic",
          "subtitle": true,
          "pause_after": 0.8
        },
        {
          "id": "line_003",
          "character": "hero",
          "text": "如果命运选择了我……那我就不会逃避。",
          "duration": 4.0,
          "emotion": "melancholy",
          "subtitle": true,
          "pause_after": 2.0
        }
      ]
    }
  ]
}
```

### 集成代码

```lua
-- scripts/main.lua
require "LuaScripts/Utilities/Sample"
local UI    = require("urhox-libs/UI")
local Video = require("urhox-libs/Video")
local CutscenePlayer = require("cutscene.CutscenePlayer")

local scene_ = nil

function Start()
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    scene_ = Scene()
    scene_:CreateComponent("Octree")

    CutscenePlayer.Init(scene_, {
        lang = "cmn",
        autoAdvance = true,
        onComplete = function()
            log:Info("Prologue finished -> Title screen")
        end,
    })

    local root = UI.Panel {
        width = "100%", height = "100%",
        children = {
            Video.VideoPlayer {
                src = "videos/prologue_cg.mp4",
                width = "100%", height = "100%",
                autoPlay = true,
                objectFit = "contain",
            },
            CutscenePlayer.GetSubtitlePanel(),
        },
    }
    UI.SetRoot(root)

    CutscenePlayer.Play("cutscenes/rpg_prologue.json", "cutscenes/characters.json")
    SubscribeToEvent("Update", HandleUpdate)
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    CutscenePlayer.Update(dt)
    if input:GetKeyPress(KEY_ESCAPE) then
        CutscenePlayer.Stop()
    end
end

function Stop() end
```

---

## 方案 2: 视觉小说对话系统

**场景**: 全屏背景 + 底部对话框 + 角色立绘 + 语音播放。

### 剧本格式扩展

```json
{
  "id": "vn_chapter1",
  "scenes": [
    {
      "id": "school_gate",
      "background": "Textures/bg_school_gate.png",
      "lines": [
        {
          "id": "line_001",
          "character": "protagonist",
          "text": "今天的天气真好，适合散步。",
          "duration": 3.0,
          "portrait": "left",
          "portrait_image": "Textures/char_protagonist_smile.png"
        },
        {
          "id": "line_002",
          "character": "heroine",
          "text": "嗯！我们去公园吧！",
          "duration": 2.5,
          "portrait": "right",
          "portrait_image": "Textures/char_heroine_happy.png",
          "emotion": "excited"
        }
      ]
    }
  ]
}
```

### 对话框 UI

```lua
-- scripts/vn/DialogueBox.lua
local UI = require("urhox-libs/UI")

local DialogueBox = {}

function DialogueBox.Create(config)
    local speakerLabel = UI.Label {
        text = "",
        fontSize = 20,
        color = "#FFD54F",
        fontWeight = "bold",
    }

    local textLabel = UI.Label {
        text = "",
        fontSize = 18,
        color = "#FFFFFF",
        maxWidth = 700,
        lineHeight = 1.6,
    }

    local box = UI.Panel {
        width = "100%",
        position = "absolute",
        bottom = 0,
        backgroundColor = "rgba(0,0,0,0.75)",
        paddingX = 40,
        paddingY = 24,
        children = {
            speakerLabel,
            UI.Panel { height = 8 },
            textLabel,
        },
    }

    return {
        root = box,
        setSpeaker = function(name, color)
            UI.Update(speakerLabel, { text = name, color = color or "#FFD54F" })
        end,
        setText = function(text)
            UI.Update(textLabel, { text = text })
        end,
        clear = function()
            UI.Update(speakerLabel, { text = "" })
            UI.Update(textLabel, { text = "" })
        end,
    }
end

return DialogueBox
```

---

## 方案 3: 3D 实时过场 — 角色动画 + 唇形同步

**场景**: 引擎内 3D 角色实时演出，配合语音和唇形动画。

### 角色设置

```lua
-- scripts/cutscene3d/SceneSetup.lua
local LipSyncDriver = require("cutscene.LipSyncDriver")

local SceneSetup = {}

function SceneSetup.CreateCharacter(scene, config)
    local node = scene:CreateChild(config.id)
    node.position = config.position or Vector3(0, 0, 0)
    node.rotation = Quaternion(config.yaw or 0, Vector3.UP)

    local model = node:CreateComponent("AnimatedModel")
    model:SetModel(cache:GetResource("Model", config.modelPath))
    model:SetMaterial(cache:GetResource("Material", config.materialPath))

    local animCtrl = node:CreateComponent("AnimationController")

    -- 注册到唇形同步驱动
    if config.talkAnim then
        LipSyncDriver.Register(config.id, node, config.idleAnim, config.talkAnim)
    end

    return node
end

--- 创建过场摄像机
function SceneSetup.CreateCamera(scene, position, lookAt)
    local cameraNode = scene:CreateChild("CutsceneCamera")
    cameraNode.position = position
    cameraNode:LookAt(lookAt)

    local camera = cameraNode:CreateComponent("Camera")
    camera.fov = 35.0
    camera.nearClip = 0.1
    camera.farClip = 100.0

    return cameraNode, camera
end

return SceneSetup
```

### 摄像机运镜

```lua
-- scripts/cutscene3d/CameraDirector.lua
local CameraDirector = {}

---@class CameraShot
---@field position Vector3
---@field lookAt Vector3
---@field duration number
---@field fov number|nil
---@field easing string|nil

local shots_ = {}
local currentShot_ = 0
local shotTimer_ = 0
---@type Node
local cameraNode_ = nil

function CameraDirector.Init(cameraNode)
    cameraNode_ = cameraNode
end

function CameraDirector.AddShot(shot)
    shots_[#shots_ + 1] = shot
end

function CameraDirector.Play()
    currentShot_ = 1
    shotTimer_ = 0
    CameraDirector._ApplyShot(shots_[1])
end

function CameraDirector._ApplyShot(shot)
    if not shot or not cameraNode_ then return end
    cameraNode_.position = shot.position
    cameraNode_:LookAt(shot.lookAt)
    local camera = cameraNode_:GetComponent("Camera")
    if camera and shot.fov then
        camera.fov = shot.fov
    end
end

function CameraDirector.Update(dt)
    if currentShot_ < 1 or currentShot_ > #shots_ then return end

    shotTimer_ = shotTimer_ + dt
    local shot = shots_[currentShot_]

    if shotTimer_ >= shot.duration then
        currentShot_ = currentShot_ + 1
        shotTimer_ = 0
        if currentShot_ <= #shots_ then
            CameraDirector._ApplyShot(shots_[currentShot_])
        end
    else
        -- 在两个镜头之间平滑插值
        if currentShot_ < #shots_ then
            local nextShot = shots_[currentShot_ + 1]
            local t = shotTimer_ / shot.duration
            -- 平滑步进
            t = t * t * (3 - 2 * t)
            local pos = shot.position:Lerp(nextShot.position, t)
            cameraNode_.position = pos
            local lookAt = shot.lookAt:Lerp(nextShot.lookAt, t)
            cameraNode_:LookAt(lookAt)
        end
    end
end

return CameraDirector
```

---

## 方案 4: 多语言语言选择菜单

**场景**: 游戏设置中的语言切换，实时更换配音和字幕语言。

### 语言选择 UI

```lua
-- scripts/ui/LanguageSelector.lua
local UI = require("urhox-libs/UI")
local CutscenePlayer = require("cutscene.CutscenePlayer")

local LanguageSelector = {}

local LANGUAGES = {
    { code = "cmn", name = "中文", flag = "CN" },
    { code = "en",  name = "English", flag = "US" },
    { code = "ja",  name = "日本語", flag = "JP" },
    { code = "ko",  name = "한국어", flag = "KR" },
}

function LanguageSelector.Create(currentLang, onSelect)
    local buttons = {}
    for _, lang in ipairs(LANGUAGES) do
        local isActive = (lang.code == currentLang)
        buttons[#buttons + 1] = UI.Button {
            text = lang.flag .. " " .. lang.name,
            variant = isActive and "primary" or "outline",
            size = "sm",
            marginRight = 8,
            marginBottom = 8,
            onClick = function()
                if onSelect then onSelect(lang.code) end
                CutscenePlayer.SetLanguage(lang.code)
            end,
        }
    end

    return UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        children = buttons,
    }
end

return LanguageSelector
```

---

## 方案 5: 过场跳过与快进

**场景**: 玩家可以跳过整个过场或快进单句台词。

### 跳过控制器

```lua
-- scripts/cutscene/SkipController.lua
local UI = require("urhox-libs/UI")

local SkipController = {}

local holdTimer_ = 0
local HOLD_DURATION = 1.5  -- 长按 1.5 秒跳过
local progressBar_ = nil
local isHolding_ = false

function SkipController.Create(onSkip)
    local hintLabel = UI.Label {
        text = "长按 ESC 跳过",
        fontSize = 14,
        color = "rgba(255,255,255,0.5)",
    }

    progressBar_ = UI.Panel {
        width = 0,
        height = 3,
        backgroundColor = "#FF5722",
    }

    local root = UI.Panel {
        position = "absolute",
        top = 20,
        right = 20,
        alignItems = "flex-end",
        children = {
            hintLabel,
            UI.Panel {
                width = 120,
                height = 3,
                backgroundColor = "rgba(255,255,255,0.2)",
                marginTop = 4,
                children = { progressBar_ },
            },
        },
    }

    return {
        root = root,
        update = function(dt)
            if input:GetKeyDown(KEY_ESCAPE) then
                holdTimer_ = holdTimer_ + dt
                isHolding_ = true
                local progress = math.min(holdTimer_ / HOLD_DURATION, 1.0)
                UI.Update(progressBar_, { width = math.floor(120 * progress) })
                if holdTimer_ >= HOLD_DURATION then
                    holdTimer_ = 0
                    if onSkip then onSkip() end
                end
            else
                if isHolding_ then
                    holdTimer_ = 0
                    isHolding_ = false
                    UI.Update(progressBar_, { width = 0 })
                end
            end
        end,
    }
end

return SkipController
```

---

## 方案 6: 配音质量验证工具

**场景**: 开发阶段用于验证所有台词是否已生成语音文件，以及时长是否匹配。

### 验证脚本

```lua
-- scripts/tools/VoiceValidator.lua
local ScriptManager    = require("cutscene.ScriptManager")
local SubtitleTimeline = require("cutscene.SubtitleTimeline")
local cjson            = require("cjson")

local VoiceValidator = {}

--- 验证单个剧本的语音文件完整性
---@param scriptPath string
---@param lang string
---@return table report
function VoiceValidator.Validate(scriptPath, lang)
    local script = ScriptManager.Load(scriptPath)
    if not script then
        return { success = false, error = "Cannot load script" }
    end

    local timeline = SubtitleTimeline.Build(script)
    SubtitleTimeline.BindAudio(timeline, lang, script.id)

    local report = {
        script_id = script.id,
        lang = lang,
        total = #timeline.entries,
        found = 0,
        missing = {},
        duration_mismatches = {},
    }

    for _, entry in ipairs(timeline.entries) do
        if entry.audioFile then
            local sound = cache:GetResource("Sound", entry.audioFile)
            if sound then
                report.found = report.found + 1
                -- 检查时长偏差
                local actualDur = sound.length
                local expectedDur = entry.duration
                local diff = math.abs(actualDur - expectedDur)
                if diff > 1.5 then  -- 超过 1.5 秒视为偏差
                    report.duration_mismatches[#report.duration_mismatches + 1] = {
                        line_id = entry.id,
                        expected = expectedDur,
                        actual = actualDur,
                        diff = diff,
                    }
                end
            else
                report.missing[#report.missing + 1] = {
                    line_id = entry.id,
                    expected_path = entry.audioFile,
                }
            end
        end
    end

    report.success = (#report.missing == 0)
    report.coverage = string.format("%.1f%%", (report.found / report.total) * 100)

    return report
end

--- 输出验证报告
---@param report table
function VoiceValidator.PrintReport(report)
    log:Info("=== Voice Validation Report ===")
    log:Info("Script: " .. report.script_id)
    log:Info("Language: " .. report.lang)
    log:Info("Coverage: " .. report.coverage .. " (" .. report.found .. "/" .. report.total .. ")")

    if #report.missing > 0 then
        log:Warning("Missing files:")
        for _, m in ipairs(report.missing) do
            log:Warning("  - " .. m.line_id .. ": " .. m.expected_path)
        end
    end

    if #report.duration_mismatches > 0 then
        log:Warning("Duration mismatches (>1.5s):")
        for _, dm in ipairs(report.duration_mismatches) do
            log:Warning(string.format("  - %s: expected %.1fs, actual %.1fs (diff %.1fs)",
                dm.line_id, dm.expected, dm.actual, dm.diff))
        end
    end

    if report.success then
        log:Info("Result: ALL PASS")
    else
        log:Warning("Result: ISSUES FOUND")
    end
end

--- 保存报告到文件
---@param report table
---@param path string
function VoiceValidator.SaveReport(report, path)
    local file = File:new(path, FILE_WRITE)
    if file and file:IsOpen() then
        file:WriteString(cjson.encode(report))
        file:Close()
        file:delete()
        log:Info("[VoiceValidator] Report saved: " .. path)
    end
end

return VoiceValidator
```

---

## 工具: 剧本统计器

```lua
-- scripts/tools/ScriptStats.lua
local ScriptManager = require("cutscene.ScriptManager")

local function PrintStats(scriptPath)
    local script = ScriptManager.Load(scriptPath)
    if not script then return end

    local stats = ScriptManager.GetStats(script)

    log:Info("=== Script Stats: " .. script.id .. " ===")
    log:Info("Scenes: " .. stats.scene_count)
    log:Info("Total lines: " .. stats.total_lines)
    log:Info("Total duration: " .. string.format("%.1f", stats.total_duration) .. "s")
    log:Info("Character breakdown:")
    for char, count in pairs(stats.character_line_counts) do
        log:Info("  " .. char .. ": " .. count .. " lines")
    end
end

return PrintStats
```

---

## 构建与部署检查清单

完成配音管线后，执行以下检查：

- [ ] 所有剧本 JSON 格式正确（无 parse 错误）
- [ ] 每个角色都已完成声音设计（confirm_character_voice）
- [ ] 每种目标语言的语音文件已生成完毕
- [ ] 语音文件按 `assets/Voices/{lang}/` 结构组织
- [ ] 翻译版剧本按 `scripts/cutscenes/{lang}/` 结构组织
- [ ] VoiceValidator 验证报告全部通过
- [ ] 调用 build 工具构建项目
- [ ] 在预览中播放完整过场验证效果
