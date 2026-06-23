---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
LeaderboardPanel.lua - 排行榜面板
V2.7 P2-1
]]

local LeaderboardPanel = {}

function LeaderboardPanel.open(selectedType)
    local LS = require("game.systems.LeaderboardSystem")
    selectedType = selectedType or "ENDLESS"
    
    local panel = {
        visible = true,
        selectedType = selectedType,
        w = 400, h = 380,
    }
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(20, 25, 40, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
        nvgText(vg, cx, cy - ph/2 + 30, "🏆 排行榜")
        
        -- 类型选择
        local types = {"ENDLESS", "BOSS_RUSH", "SPEEDRUN", "TOTAL_SCORE"}
        local tabY = cy - ph/2 + 50
        local tabW = 70
        local tabStartX = cx - (#types * (tabW + 5)) / 2
        
        for i, t in ipairs(types) do
            local tx = tabStartX + (i - 1) * (tabW + 5)
            local selected = (panel.selectedType == t)
            local typeDef = LS.BOARD_TYPES[t]
            
            nvgBeginPath(vg)
            nvgRoundedRect(vg, tx, tabY, tabW, 25, 4)
            nvgFillColor(vg, selected and nvgRGBA(60, 120, 180, 200) or nvgRGBA(40, 50, 70, 180))
            nvgFill(vg)
            
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, tx + tabW/2, tabY + 12, typeDef.icon .. " " .. typeDef.name)
            
            addHit(tx, tabY, tabW, 25, function()
                panel.selectedType = t
            end)
        end
        
        -- 排行榜列表
        local board = LS.getBoard(panel.selectedType, playerState)
        local yStart = cy - ph/2 + 85
        
        if #board == 0 then
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(150, 150, 170, 200))
            nvgTextAlign(vg, NVG_ALIGN.CENTER)
            nvgText(vg, cx, yStart + 50, "暂无记录")
        else
            for i, entry in ipairs(board) do
                if i > 10 then break end
                
                local rowY = yStart + (i - 1) * 28
                
                -- 排名背景
                local rankColor = i == 1 and nvgRGBA(200, 150, 50, 200)
                               or i == 2 and nvgRGBA(150, 150, 150, 200)
                               or i == 3 and nvgRGBA(150, 100, 50, 200)
                               or nvgRGBA(40, 50, 70, 180)
                
                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx - pw/2 + 20, rowY, pw - 40, 24, 4)
                nvgFillColor(vg, rankColor); nvgFill(vg)
                
                -- 排名
                nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
                local rankIcon = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or "#" .. i
                nvgText(vg, cx - pw/2 + 30, rowY + 12, rankIcon)
                
                -- 名称
                nvgText(vg, cx - pw/2 + 60, rowY + 12, entry.name)
                
                -- 分数
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
                nvgText(vg, cx + pw/2 - 30, rowY + 12, tostring(entry.score))
            end
        end
        
        -- 关闭按钮
        local closeX, closeY = cx + pw/2 - 25, cy - ph/2 + 10
        nvgBeginPath(vg)
        nvgCircle(vg, closeX, closeY, 12)
        nvgFillColor(vg, nvgRGBA(80, 80, 100, 200)); nvgFill(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, closeX, closeY, "×")
        addHit(closeX - 12, closeY - 12, 24, 24, function()
            panel.visible = false
        end)
    end
    
    return panel
end

return LeaderboardPanel