---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
EndlessPanel.lua - 无尽模式选择面板
V2.7 P0-2
]]

local EndlessPanel = {}

local panel_ = nil

function EndlessPanel.Show()
    local panel = {
        visible = true,
        w = 400, h = 320,
    }
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 面板背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(20, 20, 40, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 100, 200, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 100, 200, 255))
        nvgText(vg, cx, cy - ph/2 + 35, "∞ 无尽挑战")
        
        -- 模式选项
        local modes = {
            { key = "CLASSIC", name = "经典无尽", desc = "难度线性递增，适合长期挑战", color = nvgRGBA(100, 200, 255, 255) },
            { key = "SURVIVAL", name = "生存模式", desc = "难度指数递增，更具挑战性", color = nvgRGBA(255, 150, 100, 255) },
            { key = "SPEEDRUN", name = "速通模式", desc = "10分钟内到达波次50", color = nvgRGBA(255, 255, 100, 255) },
        }
        
        local yStart = cy - ph/2 + 70
        local btnH = 55
        for i, mode in ipairs(modes) do
            local by = yStart + (i - 1) * (btnH + 10)
            local bx = cx - pw/2 + 20
            local bw = pw - 40
            
            local hover = (BS and BS.cursorX or 0) >= bx and (BS and BS.cursorX or 0) <= bx + bw
                      and (BS and BS.cursorY or 0) >= by and (BS and BS.cursorY or 0) <= by + btnH
            
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, by, bw, btnH, 8)
            nvgFillColor(vg, hover and nvgRGBA(60, 40, 80, 220) or nvgRGBA(40, 30, 50, 180))
            nvgFill(vg)
            nvgStrokeColor(vg, mode.color)
            nvgStrokeWidth(vg, hover and 2 or 1)
            nvgStroke(vg)
            
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, mode.color)
            nvgText(vg, bx + 15, by + 20, mode.name)
            
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
            nvgText(vg, bx + 15, by + 38, mode.desc)
            
            -- 难度指示
            local diffText = ""
            if mode.key == "CLASSIC" then
                diffText = "难度: +8%/波"
            elseif mode.key == "SURVIVAL" then
                diffText = "难度: ×1.1/波"
            else
                diffText = "限时: 10分钟"
            end
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
            nvgText(vg, bx + bw - 80, by + 38, diffText)
            
            addHit(bx, by, bw, btnH, function()
                -- 开始无尽模式
                BattleScene.StartEndlessMode(mode.key)
                panel.visible = false
                -- 开始战斗
                if GameUI and GameUI.StartBattle then
                    GameUI.StartBattle()
                end
            end)
        end
        
        -- 历史记录显示
        local recordY = cy + ph/2 - 45
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2 + 20, recordY, pw - 40, 30, 6)
        nvgFillColor(vg, nvgRGBA(50, 40, 60, 180)); nvgFill(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        local record = BS and BS.endlessRecord or 0
        nvgText(vg, cx - pw/2 + 30, recordY + 15, "🏆 历史最高: " .. record .. " 波")
        
        -- 关闭按钮
        local closeBtnX, closeBtnY = cx + pw/2 - 50, cy - ph/2 + 10
        nvgBeginPath(vg)
        nvgCircle(vg, closeBtnX, closeBtnY, 12)
        nvgFillColor(vg, nvgRGBA(80, 80, 100, 200)); nvgFill(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, closeBtnX, closeBtnY, "×")
        addHit(closeBtnX - 12, closeBtnY - 12, 24, 24, function()
            panel.visible = false
        end)
    end
    
    panel_ = panel
    registerOverlay("endlessMode", function(vg) 
        if panel_ and panel_.visible then
            panel_.draw(vg)
        end
    end)
end

return EndlessPanel