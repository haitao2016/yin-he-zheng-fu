---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
ChallengePanel.lua - 每日挑战 UI 面板
V2.7 P0-3
]]

local ChallengePanel = {}

function ChallengePanel.open()
    local CS = require("game.systems.ChallengeSystem")
    local challenge = CS.getDailyChallenge()
    
    local panel = {
        visible = true,
        w = 420, h = 350,
    }
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 面板背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(20, 20, 40, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(100, 220, 255, 255))
        nvgText(vg, cx, cy - ph/2 + 35, "📅 每日挑战")
        
        -- 日期
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
        nvgText(vg, cx, cy - ph/2 + 55, challenge.date)
        
        -- 挑战列表
        local yStart = cy - ph/2 + 80
        for i, ch in ipairs(challenge.challenges) do
            local by = yStart + (i - 1) * 60
            
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - pw/2 + 20, by, pw - 40, 50, 8)
            nvgFillColor(vg, nvgRGBA(40, 60, 80, 180)); nvgFill(vg)
            if challenge.completed then
                nvgStrokeColor(vg, nvgRGBA(100, 255, 100, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
            end
            
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cx - pw/2 + 35, by + 25, ch.icon or "⭐")
            
            nvgFontSize(vg, 13)
            nvgFillColor(vg, challenge.completed and nvgRGBA(100, 255, 100, 255) or nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cx - pw/2 + 65, by + 18, ch.desc or ch.type)
            
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
            nvgText(vg, cx - pw/2 + 65, by + 35, "奖励: " .. ch.reward .. " 积分")
            
            if challenge.completed then
                nvgFontSize(vg, 14)
                nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
                nvgText(vg, cx + pw/2 - 40, by + 25, "✓")
            end
        end
        
        -- 积分显示
        local rm = UICommon and UICommon.rm
        local points = CS.getChallengePoints(rm)
        local yBottom = cy + ph/2 - 60
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2 + 20, yBottom, pw - 40, 35, 6)
        nvgFillColor(vg, nvgRGBA(60, 40, 80, 200)); nvgFill(vg)
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 255))
        nvgText(vg, cx - pw/2 + 35, yBottom + 17, "🎫 挑战积分: " .. points)
        
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
    
    return panel
end

return ChallengePanel