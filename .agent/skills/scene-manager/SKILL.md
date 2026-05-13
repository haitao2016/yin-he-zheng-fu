---
name: scene-manager
description: "UrhoX Lua game scene/state manager for multi-screen games (main menu, gameplay, pause, game over). Use when users need to (1) design game state flow menu to game to pause to results, (2) implement NanoVG fade transitions, (3) pass data between scenes, (4) split a large file into scene modules, (5) user says scene management, game flow, multi-state game."
---

# Scene Manager for UrhoX

Manages multiple game states via Enter/Exit/Update/Render/OnClick interface with NanoVG fade.

## SceneManager Module (scripts/SceneManager.lua)

Copy this file to your project:

    local SceneManager = {}
    local scenes_    = {}
    local current_   = nil
    local pending_   = nil
    local fadeAlpha_ = 0
    local fadeDir_   = 0
    local FADE_SPD   = 1 / 0.25

    function SceneManager.Register(name, scene)
        scenes_[name] = scene
    end

    function SceneManager.GoTo(name, data)
        if fadeDir_ ~= 0 then return end
        pending_ = { name = name, data = data }
        fadeDir_ = 1;  fadeAlpha_ = 0
    end

    function SceneManager.GoToImmediate(name, data)
        if current_ and current_.Exit then current_.Exit() end
        current_ = scenes_[name]
        if current_ and current_.Enter then current_.Enter(data) end
    end

    function SceneManager.Update(dt)
        if fadeDir_ ~= 0 then
            fadeAlpha_ = fadeAlpha_ + fadeDir_ * FADE_SPD * dt
            if fadeDir_ == 1 and fadeAlpha_ >= 1 then
                fadeAlpha_ = 1
                if current_ and current_.Exit  then current_.Exit() end
                current_   = scenes_[pending_.name]
                if current_ and current_.Enter then current_.Enter(pending_.data) end
                pending_   = nil
                fadeDir_   = -1
            elseif fadeDir_ == -1 and fadeAlpha_ <= 0 then
                fadeAlpha_ = 0;  fadeDir_ = 0
            end
        end
        if current_ and current_.Update then current_.Update(dt) end
    end

    function SceneManager.Render(vg, w, h)
        if current_ and current_.Render then current_.Render(vg, w, h) end
        if fadeAlpha_ > 0 then
            nvgBeginPath(vg);  nvgRect(vg, 0, 0, w, h)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(fadeAlpha_ * 255)))
            nvgFill(vg)
        end
    end

    function SceneManager.OnClick(mx, my)
        if fadeDir_ ~= 0 then return end
        if current_ and current_.OnClick then current_.OnClick(mx, my) end
    end

    return SceneManager

## main.lua Integration

    local SceneManager = require "SceneManager"
    local MenuScene    = require "scenes.MenuScene"
    local GameScene    = require "scenes.GameScene"
    local vg_, w_, h_

    function Start()
        SceneManager.Register("menu", MenuScene)
        SceneManager.Register("game", GameScene)
        vg_ = nvgCreate(1)
        nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")
        local dpr = graphics:GetDPR()
        w_ = graphics:GetWidth()  / dpr
        h_ = graphics:GetHeight() / dpr
        SceneManager.GoToImmediate("menu")
        SubscribeToEvent("Update",          "HandleUpdate")
        SubscribeToEvent("NanoVGRender",    "HandleNVG")
        SubscribeToEvent("MouseButtonDown", "HandleClick")
    end

    function HandleUpdate(_, ed)
        SceneManager.Update(ed:GetFloat("TimeStep"))
    end

    function HandleNVG()
        nvgBeginFrame(vg_, w_, h_, graphics:GetDPR())
        SceneManager.Render(vg_, w_, h_)
        nvgEndFrame(vg_)
    end

    function HandleClick(_, ed)
        if ed:GetInt("Button") == MOUSEB_LEFT then
            local dpr = graphics:GetDPR()
            SceneManager.OnClick(ed:GetInt("X") / dpr, ed:GetInt("Y") / dpr)
        end
    end

## Scene Interface

| Method | Called when | Args |
|--------|-------------|------|
| Enter(data) | Switching into scene | data from previous scene |
| Exit() | Switching away | none |
| Update(dt) | Every frame | delta time in seconds |
| Render(vg, w, h) | NanoVGRender event | vg handle + logical screen size |
| OnClick(mx, my) | Mouse/touch click | logical pixel coords |

All methods optional.

## Typical State Flow

    GoToImmediate("menu")
          |
     [MenuScene] --start--> GoTo("game", {level=1})
          ^                         |
          |                    [GameScene]
     GoTo("menu")           ESC -> GoTo("pause", {score, level})
          |                               |
     [GameOverScene] <-GoTo("gameover")  [PauseScene]
                                         click -> GoTo("game", data)

## Key Rules

- Never call GoTo inside Exit() - it will be ignored. Set a flag in Exit, check it next Update.
- Create NanoVG font once in Start(), never inside scene Enter().
- Divide mouse X/Y by DPR: MouseButtonDown coords are physical pixels.
- Mobile: replace MouseButtonDown with TouchBegin event.

## Scene Templates

See references/scene-templates.md for ready-to-copy MenuScene, GameScene,
PauseScene, and GameOverScene implementations.
