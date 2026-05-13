# Scene Templates for UrhoX Scene Manager

Ready-to-copy templates for the four standard game scenes.
Each file lives under scripts/scenes/<Name>Scene.lua.

---

## MenuScene

    -- scripts/scenes/MenuScene.lua
    local MenuScene = {}
    local SM        = require "SceneManager"

    local btnStart_ = { x=0, y=0, w=200, h=50 }

    function MenuScene.Render(vg, w, h)
        -- Background
        nvgBeginPath(vg);  nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(15, 15, 30, 255));  nvgFill(vg)

        -- Title
        nvgFontFace(vg, "sans");  nvgFontSize(vg, 48)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        nvgText(vg, w/2, h/3, "MY GAME")

        -- Start button
        local bx, by = w/2 - 100, h/2 - 25
        btnStart_ = { x=bx, y=by, w=200, h=50 }
        nvgBeginPath(vg);  nvgRoundedRect(vg, bx, by, 200, 50, 8)
        nvgFillColor(vg, nvgRGBA(60, 140, 255, 220));  nvgFill(vg)
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, w/2, by + 25, "Start Game")
    end

    function MenuScene.OnClick(mx, my)
        local b = btnStart_
        if mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h then
            SM.GoTo("game", { level = 1 })
        end
    end

    return MenuScene

---

## GameScene

    -- scripts/scenes/GameScene.lua
    local GameScene = {}
    local SM        = require "SceneManager"

    local score_ = 0
    local level_ = 1

    function GameScene.Enter(data)
        score_ = 0
        level_ = data and data.level or 1
    end

    function GameScene.Exit()
        print("[GameScene] final score: " .. score_)
    end

    function GameScene.Update(dt)
        -- game logic here...

        -- ESC to pause
        if input:GetKeyPress(KEY_ESCAPE) then
            SM.GoTo("pause", { score = score_, level = level_ })
        end
    end

    function GameScene.Render(vg, w, h)
        -- Background
        nvgBeginPath(vg);  nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(20, 30, 20, 255));  nvgFill(vg)

        -- HUD
        nvgFontFace(vg, "sans");  nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
        nvgText(vg, 16, 16, "Level " .. level_ .. "   Score: " .. score_)
    end

    return GameScene

---

## PauseScene

    -- scripts/scenes/PauseScene.lua
    local PauseScene = {}
    local SM         = require "SceneManager"

    local savedData_ = {}

    function PauseScene.Enter(data)
        savedData_ = data or {}
    end

    function PauseScene.Render(vg, w, h)
        -- Semi-transparent overlay (renders on top of whatever was last drawn)
        nvgBeginPath(vg);  nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 150));  nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        nvgFontSize(vg, 36)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, w/2, h/2 - 40, "PAUSED")

        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
        nvgText(vg, w/2, h/2 + 10, "Score: " .. (savedData_.score or 0))
        nvgText(vg, w/2, h/2 + 40, "Click anywhere to resume")
    end

    function PauseScene.OnClick()
        SM.GoTo("game", savedData_)
    end

    return PauseScene

---

## GameOverScene

    -- scripts/scenes/GameOverScene.lua
    local GameOverScene = {}
    local SM            = require "SceneManager"

    local finalScore_ = 0
    local btnY_       = 0

    function GameOverScene.Enter(data)
        finalScore_ = data and data.score or 0
    end

    function GameOverScene.Render(vg, w, h)
        nvgBeginPath(vg);  nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(30, 10, 10, 255));  nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        nvgFontSize(vg, 48)
        nvgFillColor(vg, nvgRGBA(255, 80, 80, 255))
        nvgText(vg, w/2, h/3, "GAME OVER")

        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(220, 220, 100, 255))
        nvgText(vg, w/2, h/2, "Final Score: " .. finalScore_)

        -- Menu button
        btnY_ = h * 0.65
        nvgBeginPath(vg)
        nvgRoundedRect(vg, w/2 - 100, btnY_ - 22, 200, 44, 8)
        nvgFillColor(vg, nvgRGBA(80, 80, 80, 200));  nvgFill(vg)
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgText(vg, w/2, btnY_ + 2, "Back to Menu")
    end

    function GameOverScene.OnClick(mx, my)
        local halfW = graphics:GetWidth() / graphics:GetDPR() / 2
        if math.abs(mx - halfW) < 100 and math.abs(my - btnY_) < 22 then
            SM.GoTo("menu")
        end
    end

    return GameOverScene

---

## File Layout

    scripts/
    ├── main.lua
    ├── SceneManager.lua
    └── scenes/
        ├── MenuScene.lua
        ├── GameScene.lua
        ├── PauseScene.lua
        └── GameOverScene.lua
