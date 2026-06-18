---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
ShipDetailPanel.lua - 舰船详情面板
V2.7 P1-3/5
舰船专精和旗舰选项
]]

local ShipDetailPanel = {}

-- 舰船详情面板绘制（包含专精树和旗舰选项）
function ShipDetailPanel.drawShipDetailPanel(panel, ship, playerState, addHit, notifyFn, BS)
    if not ship then return end
    
    local SS = require("game.systems.ShipSpecializationSystem")
    local FS = require("game.systems.FlagshipSystem")
    
    -- 专精树标题
    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 13)
    nvgTextAlign(BS.vg, NVG_ALIGN.LEFT)
    nvgFillColor(BS.vg, nvgRGBA(255, 220, 100, 255))
    nvgText(BS.vg, panel.x + 15, panel.y + 200, "⚡ 舰船专精")
    
    local specs = SS.getSpecializations(ship.stype)
    local unlocked = SS.getUnlockedSpec(ship)
    
    if #specs == 0 then
        nvgFontSize(BS.vg, 10)
        nvgFillColor(BS.vg, nvgRGBA(150, 150, 150, 200))
        nvgText(BS.vg, panel.x + 15, panel.y + 220, "该舰船类型无专精树")
    else
        -- 专精节点
        local y = panel.y + 225
        for _, spec in ipairs(specs) do
            local isUnlocked = unlocked[spec.id]
            local canUnlock = SS.canUnlockSpec(ship, spec.id)
            
            -- 节点背景
            local bgColor = isUnlocked and nvgRGBA(60, 100, 60, 200) 
                           or canUnlock and nvgRGBA(80, 60, 60, 200)
                           or nvgRGBA(40, 40, 50, 180)
            nvgBeginPath(BS.vg)
            nvgRoundedRect(BS.vg, panel.x + 15, y, panel.w - 30, 35, 4)
            nvgFillColor(BS.vg, bgColor); nvgFill(BS.vg)
            
            if isUnlocked then
                nvgStrokeColor(BS.vg, nvgRGBA(100, 255, 100, 150)); nvgStrokeWidth(BS.vg, 1); nvgStroke(BS.vg)
            end
            
            -- 名称和描述
            nvgFontSize(BS.vg, 11)
            nvgFillColor(BS.vg, isUnlocked and nvgRGBA(255, 255, 255, 255) or nvgRGBA(180, 180, 180, 200))
            nvgText(BS.vg, panel.x + 25, y + 12, spec.name)
            
            nvgFontSize(BS.vg, 9)
            nvgFillColor(BS.vg, nvgRGBA(160, 160, 180, 200))
            nvgText(BS.vg, panel.x + 25, y + 25, spec.desc)
            
            -- 费用
            local costStr = ""
            for res, amount in pairs(spec.cost) do
                costStr = costStr .. amount .. res .. " "
            end
            nvgFontSize(BS.vg, 9)
            nvgTextAlign(BS.vg, NVG_ALIGN.RIGHT)
            nvgFillColor(BS.vg, isUnlocked and nvgRGBA(100, 255, 100, 200) or nvgRGBA(255, 200, 100, 200))
            nvgText(BS.vg, panel.x + panel.w - 25, y + 18, isUnlocked and "已解锁 ✓" or costStr)
            
            -- 点击解锁
            if not isUnlocked and canUnlock then
                addHit(panel.x + 15, y, panel.w - 30, 35, function()
                    local ok, msg = SS.unlockSpec(ship, spec.id, playerState)
                    if ok then
                        notifyFn(msg, "success")
                    else
                        notifyFn(msg, "warning")
                    end
                end)
            end
            
            y = y + 40
        end
        
        -- 旗舰设置
        y = y + 10
        nvgFontSize(BS.vg, 13)
        nvgFillColor(BS.vg, nvgRGBA(255, 200, 100, 255))
        nvgText(BS.vg, panel.x + 15, y, "🏴 旗舰设置")
        
        y = y + 20
        local btnW, btnH = panel.w - 30, 30
        local isFlagship = playerState.flagshipId == ship.id
        local flagshipColor = isFlagship and nvgRGBA(200, 180, 50, 220) or nvgRGBA(80, 80, 100, 200)
        local flagshipStroke = isFlagship and nvgRGBA(255, 220, 100, 200) or nvgRGBA(100, 100, 150, 150)
        
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, panel.x + 15, y, btnW, btnH, 6)
        nvgFillColor(BS.vg, flagshipColor); nvgFill(BS.vg)
        nvgStrokeColor(BS.vg, flagshipStroke); nvgStrokeWidth(BS.vg, isFlagship and 2 or 1); nvgStroke(BS.vg)
        
        nvgFontSize(BS.vg, 12)
        nvgTextAlign(BS.vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(255, 255, 255, 255))
        nvgText(BS.vg, panel.x + 15 + btnW/2, y + btnH/2, 
                isFlagship and "🏴 取消旗舰" or "🏴 设置为旗舰")
        
        addHit(panel.x + 15, y, btnW, btnH, function()
            if isFlagship then
                FS.clearFlagship(playerState)
                ship.isFlagship = nil
                notifyFn("已取消旗舰", "info")
            else
                FS.setFlagship(ship, playerState)
                notifyFn("旗舰设置成功！", "success")
            end
        end)
        
        -- 旗舰加成说明
        if isFlagship then
            y = y + 40
            nvgFontSize(BS.vg, 10)
            nvgFillColor(BS.vg, nvgRGBA(200, 200, 220, 220))
            nvgTextAlign(BS.vg, NVG_ALIGN.LEFT)
            nvgText(BS.vg, panel.x + 15, y, "旗舰加成:")
            y = y + 15
            
            local bonus = FS.FLAGSHIP_BONUS.base
            local typeBonus = FS.FLAGSHIP_BONUS[ship.stype]
            
            nvgText(BS.vg, panel.x + 15, y, "• 生命 +20%")
            nvgText(BS.vg, panel.x + 15, y + 12, "• 攻击 +15%")
            nvgText(BS.vg, panel.x + 15, y + 24, "• 鼓舞友军 +10%")
            
            if typeBonus then
                if typeBonus.speedMult then nvgText(BS.vg, panel.x + 15, y + 36, "• 速度 +25%") end
                if typeBonus.aoeDmgMult then nvgText(BS.vg, panel.x + 15, y + 36, "• AOE 伤害 +20%") end
                if typeBonus.healMult then nvgText(BS.vg, panel.x + 15, y + 36, "• 治疗 +40%") end
            end
        end
    end
end

return ShipDetailPanel
