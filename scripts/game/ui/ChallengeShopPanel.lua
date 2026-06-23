---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
ChallengeShopPanel.lua - 挑战积分商店面板
V2.7 P2-2
]]

local ChallengeShopPanel = {}

function ChallengeShopPanel.open()
    local CS = require("game.systems.ChallengeSystem")
    local rm = UICommon and UICommon.rm
    local points = playerState.challengePoints or 0
    
    local panel = {
        visible = true,
        w = 420, h = 350,
    }
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(30, 25, 50, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 150, 100, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 255))
        nvgText(vg, cx, cy - ph/2 + 30, "🎫 挑战积分商店")
        
        -- 积分显示
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(255, 220, 150, 255))
        nvgText(vg, cx, cy - ph/2 + 55, "当前积分: " .. points)
        
        -- 商品列表
        local yStart = cy - ph/2 + 80
        for i, item in ipairs(CHALLENGE_SHOP) do
            local rowY = yStart + (i - 1) * 50
            
            local canBuy = points >= item.cost
            
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - pw/2 + 15, rowY, pw - 30, 42, 6)
            nvgFillColor(vg, canBuy and nvgRGBA(50, 60, 80, 200) or nvgRGBA(40, 40, 50, 150))
            nvgFill(vg)
            
            -- 图标
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cx - pw/2 + 25, rowY + 21, item.icon)
            
            -- 名称和描述
            nvgFontSize(vg, 12)
            nvgFillColor(vg, canBuy and nvgRGBA(255, 255, 255, 255) or nvgRGBA(150, 150, 150, 200))
            nvgText(vg, cx - pw/2 + 50, rowY + 14, item.name)
            
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
            nvgText(vg, cx - pw/2 + 50, rowY + 28, item.desc)
            
            -- 价格
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, canBuy and nvgRGBA(255, 200, 100, 255) or nvgRGBA(150, 100, 100, 200))
            nvgText(vg, cx + pw/2 - 25, rowY + 21, item.cost .. " 积分")
            
            -- 购买按钮
            if canBuy then
                addHit(cx - pw/2 + 15, rowY, pw - 30, 42, function()
                    local ok, msg = CS.purchaseShopItem(item.id, playerState, rm, notifyFn)
                    notifyFn(msg, ok and "success" or "warning")
                    points = playerState.challengePoints or 0
                end)
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

return ChallengeShopPanel