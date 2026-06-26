--[[
MarketPanel.lua - 市场交易面板
V2.7 P1-4
]]

local MarketPanel = {}

function MarketPanel.open()
    local MS = require("game.systems.MarketSystem")
    if playerState then MS.init(playerState) end
    
    local panel = {
        visible = true,
        w = 380, h = 340,
    }
    
    function panel.draw(vg)
        local cx, cy = (BS and BS.screenW or 800)/2, (BS and BS.screenH or 600)/2
        local pw, ph = panel.w, panel.h
        
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - pw/2, cy - ph/2, pw, ph, 12)
        nvgFillColor(vg, nvgRGBA(25, 30, 50, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 150, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        
        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(100, 255, 150, 255))
        nvgText(vg, cx, cy - ph/2 + 30, "📊 星际市场")
        
        -- 市场信息
        local marketInfo = MS.getMarketInfo(playerState)
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
        nvgText(vg, cx, cy - ph/2 + 50, "下次价格更新: " .. (marketInfo.nextUpdateIn or 0) .. "s")
        
        -- 资源列表
        local y = cy - ph/2 + 75
        local resources = {"metal", "esource", "nuclear", "blueCrystal", "purpleCrystal"}
        
        for i, res in ipairs(resources) do
            local price = marketInfo.prices and marketInfo.prices[res] or 1
            local basePrice = MS.MARKET_CONFIG.basePrice[res]
            local priceChange = price / basePrice
            
            local rowY = y + (i - 1) * 38
            
            -- 行背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - pw/2 + 15, rowY, pw - 30, 32, 4)
            nvgFillColor(vg, nvgRGBA(40, 50, 70, 180)); nvgFill(vg)
            
            -- 资源名
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cx - pw/2 + 25, rowY + 16, MS.RESOURCE_NAMES[res] or res)
            
            -- 价格（红涨绿跌）
            local priceColor = priceChange > 1.0 and nvgRGBA(255, 100, 100, 255) 
                             or priceChange < 1.0 and nvgRGBA(100, 255, 100, 255)
                             or nvgRGBA(200, 200, 200, 255)
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, priceColor)
            nvgText(vg, cx, rowY + 16, tostring(price) .. " 金属")
            
            -- 交易按钮
            local buyX = cx + pw/2 - 90
            nvgBeginPath(vg)
            nvgRoundedRect(vg, buyX, rowY + 4, 30, 24, 4)
            nvgFillColor(vg, nvgRGBA(80, 150, 80, 200)); nvgFill(vg)
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, buyX + 15, rowY + 16, "买")
            
            addHit(buyX, rowY + 4, 30, 24, function()
                local rm = UICommon and UICommon.rm
                local ok, msg = MS.buy(playerState, res, 10, rm)
                notifyFn(msg, ok and "success" or "warning")
            end)
            
            local sellX = cx + pw/2 - 50
            nvgBeginPath(vg)
            nvgRoundedRect(vg, sellX, rowY + 4, 30, 24, 4)
            nvgFillColor(vg, nvgRGBA(150, 80, 80, 200)); nvgFill(vg)
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, sellX + 15, rowY + 16, "卖")
            
            addHit(sellX, rowY + 4, 30, 24, function()
                local rm = UICommon and UICommon.rm
                local ok, msg = MS.sell(playerState, res, 10, rm)
                notifyFn(msg, ok and "success" or "warning")
            end)
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

return MarketPanel