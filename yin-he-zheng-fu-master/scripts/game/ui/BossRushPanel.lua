---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
BossRushPanel.lua - Boss Rush 模式选择面板
P1-1
]]

local BossRushPanel = {}

local panel_ = nil

function BossRushPanel.Show()
    local panel = {
        visible = true,
        w = 400, h = 320,
    }
    
    local selectedCount = 5
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 面板背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(30, 20, 50, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 80, 80, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 100, 100, 255))
        nvgText(vg, cx, cy - ph/2 + 35, "💀 Boss Rush 挑战")
        
        -- 说明
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(200, 180, 180, 200))
        nvgText(vg, cx, cy - ph/2 + 60, "连续挑战多个 Boss，考验阵容搭配！")
        
        -- Boss 数量选择
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgText(vg, cx - pw/2 + 40, cy - ph/2 + 95, "选择 Boss 数量:")
        
        local counts = { 3, 5, 7 }
        local btnW, btnH = 70, 35
        local startX = cx - (#counts * (btnW + 15)) / 2
        
        for i, count in ipairs(counts) do
            local bx = startX + (i - 1) * (btnW + 15)
            local by = cy - ph/2 + 110
            
            local selected = (selectedCount == count)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, by, btnW, btnH, 6)
            nvgFillColor(vg, selected and nvgRGBA(150, 50, 50, 220) or nvgRGBA(60, 40, 60, 200))
            nvgFill(vg)
            nvgStrokeColor(vg, selected and nvgRGBA(255, 100, 100, 200) or nvgRGBA(100, 80, 100, 150))
            nvgStrokeWidth(vg, selected and 2 or 1); nvgStroke(vg)
            
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, bx + btnW/2, by + btnH/2, count .. " 个")
            
            addHit(bx, by, btnW, btnH, function()
                selectedCount = count
            end)
        end
        
        -- 奖励预览
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgText(vg, cx, cy + 20, "每击败 1 Boss: +30 蓝晶石")
        nvgText(vg, cx, cy + 35, "完成挑战: +50 紫晶石 | 完美通关: +100 紫晶石+10 彩虹晶")
        
        -- 开始按钮
        local startY = cy + ph/2 - 60
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - 80, startY, 160, 40, 8)
        nvgFillColor(vg, nvgRGBA(180, 60, 60, 220)); nvgFill(vg)
        nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, cx, startY + 20, "开始挑战 💀")
        
        addHit(cx - 80, startY, 160, 40, function()
            panel.visible = false
            -- 开始 Boss Rush
            if BattleScene and BattleScene.StartBossRush then
                BattleScene.StartBossRush(selectedCount)
            end
            -- 开始战斗
            if GameUI and GameUI.StartBattle then
                GameUI.StartBattle()
            end
        end)
        
        -- 关闭按钮
        local closeX, closeY = cx + pw/2 - 30, cy - ph/2 + 10
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
    
    panel_ = panel
    registerOverlay("bossRush", function(vg) 
        if panel_ and panel_.visible then
            panel_.draw(vg)
        end
    end)
end

return BossRushPanel
