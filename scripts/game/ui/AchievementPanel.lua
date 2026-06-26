--[[
AchievementPanel.lua - 成就面板 UI
V2.7 P1-2
]]

local AchievementPanel = {}

function AchievementPanel.open()
    local AS = require("game.systems.AchievementSystem")
    local stats = AS.getStats(playerState)
    
    local panel = {
        visible = true,
        selectedCategory = nil,
        w = 500, h = 400,
    }
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(25, 25, 45, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(100, 220, 255, 255))
        nvgText(vg, cx, cy - ph/2 + 30, "🏆 成就")
        
        -- 进度
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(200, 200, 220, 220))
        nvgText(vg, cx, cy - ph/2 + 50, stats.unlocked .. "/" .. stats.total .. " (" .. stats.percentage .. "%)")
        
        -- 分类标签
        local categories = AS.CATEGORIES
        local tabY = cy - ph/2 + 65
        local tabW = 60
        local tabStartX = cx - (#categories * (tabW + 5)) / 2
        
        for i, cat in ipairs(categories) do
            local tx = tabStartX + (i - 1) * (tabW + 5)
            local selected = (panel.selectedCategory == cat.id)
            
            nvgBeginPath(vg)
            nvgRoundedRect(vg, tx, tabY, tabW, 25, 4)
            nvgFillColor(vg, selected and nvgRGBA(60, 120, 180, 200) or nvgRGBA(40, 40, 60, 180))
            nvgFill(vg)
            
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, tx + tabW/2, tabY + 12, cat.icon .. " " .. cat.name)
            
            addHit(tx, tabY, tabW, 25, function()
                panel.selectedCategory = cat.id
            end)
        end
        
        -- 显示"全部"
        local allTabX = tabStartX + #categories * (tabW + 5)
        local allSelected = (panel.selectedCategory == nil)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, allTabX, tabY, 40, 25, 4)
        nvgFillColor(vg, allSelected and nvgRGBA(60, 120, 180, 200) or nvgRGBA(40, 40, 60, 180))
        nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, allTabX + 20, tabY + 12, "全部")
        addHit(allTabX, tabY, 40, 25, function()
            panel.selectedCategory = nil
        end)
        
        -- 成就列表
        local progress = AS.getProgress(playerState)
        local yStart = cy - ph/2 + 100
        local row = 0
        
        for _, ach in ipairs(AS.ACHIEVEMENTS) do
            local data = progress[ach.id]
            if not panel.selectedCategory or data.category == panel.selectedCategory then
                local ry = yStart + row * 45
                row = row + 1
                
                if row > 6 then break end  -- 最多显示 6 个
                
                local alpha = data.unlocked and 255 or (data.meetsCondition and 200 or 100)
                local bgR, bgG, bgB = data.unlocked and 60 or (data.meetsCondition and 50 or 40),
                                       data.unlocked and 80 or (data.meetsCondition and 50 or 40),
                                       data.unlocked and 120 or (data.meetsCondition and 80 or 60)
                
                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx - pw/2 + 20, ry, pw - 40, 40, 6)
                nvgFillColor(vg, nvgRGBA(bgR, bgG, bgB, alpha)); nvgFill(vg)
                
                if data.unlocked then
                    nvgStrokeColor(vg, nvgRGBA(100, 255, 100, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                elseif data.meetsCondition then
                    nvgStrokeColor(vg, nvgRGBA(255, 200, 100, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end
                
                -- 图标
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
                nvgFillColor(vg, data.unlocked and nvgRGBA(255, 220, 100, 255) or nvgRGBA(150, 150, 150, 200))
                nvgText(vg, cx - pw/2 + 30, ry + 20, data.icon)
                
                -- 名称和描述
                nvgFontSize(vg, 12)
                nvgFillColor(vg, data.unlocked and nvgRGBA(255, 255, 255, 255) or nvgRGBA(180, 180, 180, 200))
                nvgText(vg, cx - pw/2 + 55, ry + 14, data.name)
                
                nvgFontSize(vg, 10)
                nvgFillColor(vg, nvgRGBA(160, 160, 180, 200))
                nvgText(vg, cx - pw/2 + 55, ry + 28, data.desc)
                
                -- 奖励
                if data.reward then
                    local rewardStr = ""
                    for res, amount in pairs(data.reward) do
                        rewardStr = rewardStr .. amount .. res .. " "
                    end
                    nvgFontSize(vg, 9)
                    nvgFillColor(vg, nvgRGBA(255, 220, 100, 200))
                    nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
                    nvgText(vg, cx + pw/2 - 30, ry + 20, rewardStr)
                end
                
                -- 已解锁标记
                if data.unlocked then
                    nvgFontSize(vg, 14)
                    nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
                    nvgText(vg, cx + pw/2 - 25, ry + 20, "✓")
                end
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

return AchievementPanel
