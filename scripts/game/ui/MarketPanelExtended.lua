---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/MarketPanelExtended.lua -- 扩展市场交易面板
-- V3.3
-- ============================================================================

local MarketPanelExtended = {}

local panel = nil
local playerStateRef = nil

local RESOURCE_LIST = {
    "metal", "esource", "nuclear", "blueCrystal", "purpleCrystal", "rainbowCrystal",
}

local RESOURCE_NAMES = {
    metal = "金属",
    esource = "能源晶体",
    nuclear = "核燃料",
    blueCrystal = "蓝晶石",
    purpleCrystal = "紫晶石",
    rainbowCrystal = "彩虹晶",
}

local BASE_PRICES = {
    metal = 1,
    esource = 2,
    nuclear = 5,
    blueCrystal = 50,
    purpleCrystal = 200,
    rainbowCrystal = 1000,
}

---@param vg userdata
---@param sw number
---@param sh number
function MarketPanelExtended.init(vg, sw, sh)
    MarketPanelExtended.vg = vg
    MarketPanelExtended.sw = sw or 800
    MarketPanelExtended.sh = sh or 600
end

---@param playerState table
---@param rm table
---@return table
function MarketPanelExtended.open(playerState, rm)
    playerStateRef = playerState
    panel = {
        visible = true,
        w = 780,
        h = 560,
        selectedResource = "metal",
        buyAmount = 10,
        sellAmount = 10,
        tab = "PRICE",
        rm = rm,
    }
    MarketPanelExtended.ensureMarketState()
    return panel
end

function MarketPanelExtended.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

---@return boolean
function MarketPanelExtended.isOpen()
    return panel ~= nil and panel.visible == true
end

function MarketPanelExtended.ensureMarketState()
    if not playerStateRef then return end
    playerStateRef.marketPrices = playerStateRef.marketPrices or MarketPanelExtended.getDemoPrices()
    playerStateRef.marketPriceHistory = playerStateRef.marketPriceHistory or {}
    playerStateRef.marketEvents = playerStateRef.marketEvents or {}
    playerStateRef.dailyTradeStats = playerStateRef.dailyTradeStats or { date = os.date("%Y-%m-%d"), totalBought = 0, totalSold = 0 }
    for _, res in ipairs(RESOURCE_LIST) do
        playerStateRef.marketPriceHistory[res] = playerStateRef.marketPriceHistory[res] or { playerStateRef.marketPrices[res] or BASE_PRICES[res] }
    end
end

---@return table
function MarketPanelExtended.getDemoPrices()
    local result = {}
    for res, base in pairs(BASE_PRICES) do
        result[res] = base * (0.85 + math.random() * 0.3)
    end
    return result
end

---@param resource string
---@param amount number
---@param rm table
---@return boolean ok
---@return string message
function MarketPanelExtended.buy(resource, amount, rm)
    if not playerStateRef then return false, "玩家状态未初始化" end
    local ok, MS = pcall(require, "game.systems.MarketSystem")
    if ok and MS and MS.buy then
        return MS.buy(playerStateRef, resource, amount, rm)
    end
    local price = (playerStateRef.marketPrices and playerStateRef.marketPrices[resource]) or BASE_PRICES[resource] or 1
    local totalCost = math.floor(price * amount)
    local limit = 5000
    local used = (playerStateRef.dailyTradeStats and playerStateRef.dailyTradeStats.totalBought) or 0
    if used + totalCost > limit then
        return false, "今日交易限额不足（限额 " .. limit .. " 金属）"
    end
    playerStateRef.marketPrices = playerStateRef.marketPrices or {}
    playerStateRef.marketPrices[resource] = price
    playerStateRef.dailyTradeStats.totalBought = used + totalCost
    return true, "购买成功！花费 " .. totalCost .. " 金属，获得 " .. amount .. " " .. (RESOURCE_NAMES[resource] or resource)
end

---@param resource string
---@param amount number
---@param rm table
---@return boolean ok
---@return string message
function MarketPanelExtended.sell(resource, amount, rm)
    if not playerStateRef then return false, "玩家状态未初始化" end
    local ok, MS = pcall(require, "game.systems.MarketSystem")
    if ok and MS and MS.sell then
        return MS.sell(playerStateRef, resource, amount, rm)
    end
    local price = (playerStateRef.marketPrices and playerStateRef.marketPrices[resource]) or BASE_PRICES[resource] or 1
    local sellPrice = math.floor(price * amount * 0.9)
    playerStateRef.marketPrices = playerStateRef.marketPrices or {}
    playerStateRef.marketPrices[resource] = price
    playerStateRef.dailyTradeStats = playerStateRef.dailyTradeStats or { totalSold = 0 }
    playerStateRef.dailyTradeStats.totalSold = (playerStateRef.dailyTradeStats.totalSold or 0) + sellPrice
    return true, "出售成功！出售 " .. amount .. " " .. (RESOURCE_NAMES[resource] or resource) .. "，获得 " .. sellPrice .. " 金属"
end

function MarketPanelExtended.refreshPrices()
    if not playerStateRef then return end
    local ok, MS = pcall(require, "game.systems.MarketSystem")
    if ok and MS and MS.updateMarket then
        MS.updateMarket(playerStateRef)
        return
    end
    MarketPanelExtended.ensureMarketState()
    for res, base in pairs(BASE_PRICES) do
        local current = playerStateRef.marketPrices[res] or base
        local change = 1 + (math.random() - 0.5) * 0.15
        local newPrice = math.max(base * 0.5, math.min(base * 2.0, current * change))
        newPrice = math.floor(newPrice * 100) / 100
        playerStateRef.marketPrices[res] = newPrice
        local history = playerStateRef.marketPriceHistory[res] or {}
        table.insert(history, newPrice)
        while #history > 20 do table.remove(history, 1) end
        playerStateRef.marketPriceHistory[res] = history
    end
end

---@param dt number
function MarketPanelExtended.render(dt)
    local vg = MarketPanelExtended.vg or _G.BS and _G.BS.vg or nil
    if not vg then return end
    MarketPanelExtended.draw(vg)
end

---@param x number
---@param y number
function MarketPanelExtended.handleClick(x, y)
    if not panel or not panel.visible then return end
    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or MarketPanelExtended.sw) / 2, (BS and BS.screenH or MarketPanelExtended.sh) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2
    if x >= px and x <= px + pw and y >= py and y <= py + ph then
        local closeX = px + pw - 35
        local closeY = py + 12
        if math.abs(x - closeX) <= 14 and math.abs(y - closeY) <= 14 then
            MarketPanelExtended.close()
            return
        end
    end
end

---@param vg userdata
function MarketPanelExtended.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or MarketPanelExtended.sw) / 2, (BS and BS.screenH or MarketPanelExtended.sh) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 245))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 200, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 45, 12)
    nvgRect(vg, px, py + 20, pw, 25)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 240))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "扩展市场交易")

    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        MarketPanelExtended.close()
    end)

    local tabY = py + 55
    local tabs = {
        { id = "PRICE", name = "价格表" },
        { id = "TREND", name = "价格趋势" },
        { id = "EVENT", name = "市场事件" },
    }
    local tabStartX = px + 15
    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * 100
        local selected = panel.tab == tab.id
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, 90, 26, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(35, 45, 65, 200))
        nvgFill(vg)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, tx + 45, tabY + 13, tab.name)
        addHit(tx, tabY, 90, 26, function() panel.tab = tab.id end)
    end

    local refreshX = px + pw - 130
    nvgBeginPath(vg)
    nvgRoundedRect(vg, refreshX, tabY, 115, 26, 4)
    nvgFillColor(vg, nvgRGBA(50, 80, 130, 220))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
    nvgText(vg, refreshX + 57, tabY + 13, "↻ 刷新价格")
    addHit(refreshX, tabY, 115, 26, function()
        MarketPanelExtended.refreshPrices()
    end)

    local contentY = py + 95
    local contentH = ph - 170

    if panel.tab == "PRICE" then
        MarketPanelExtended.drawPriceTable(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "TREND" then
        MarketPanelExtended.drawTrendChart(vg, px + 15, contentY, pw - 30, contentH)
    else
        MarketPanelExtended.drawEvents(vg, px + 15, contentY, pw - 30, contentH)
    end

    MarketPanelExtended.drawTradeArea(vg, px + 15, contentY + contentH + 10, pw - 30, 55)
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function MarketPanelExtended.drawPriceTable(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 100, 150, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local headerY = y + 10
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
    nvgText(vg, x + 12, headerY + 10, "资源")
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgText(vg, x + w * 0.28, headerY + 10, "当前价格")
    nvgText(vg, x + w * 0.48, headerY + 10, "今日变化")
    nvgText(vg, x + w * 0.68, headerY + 10, "供需指示")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
    nvgText(vg, x + w - 12, headerY + 10, "类型")

    nvgBeginPath(vg)
    nvgMoveTo(vg, x + 10, headerY + 22)
    nvgLineTo(vg, x + w - 10, headerY + 22)
    nvgStrokeColor(vg, nvgRGBA(80, 110, 160, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local rowH = 34
    for i, res in ipairs(RESOURCE_LIST) do
        local ry = headerY + 28 + (i - 1) * rowH
        if ry + rowH > y + h - 10 then break end
        local isSelected = panel.selectedResource == res

        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 8, ry, w - 16, rowH - 4, 4)
        nvgFillColor(vg, isSelected and nvgRGBA(50, 85, 140, 230) or nvgRGBA(28, 38, 60, 220))
        nvgFill(vg)

        local price = playerStateRef and playerStateRef.marketPrices and playerStateRef.marketPrices[res] or BASE_PRICES[res]
        local base = BASE_PRICES[res] or 1
        local changePct = ((price - base) / base) * 100
        local history = playerStateRef and playerStateRef.marketPriceHistory and playerStateRef.marketPriceHistory[res] or { price }
        local first = history[1] or price
        local last = history[#history] or price
        local trendChange = first > 0 and ((last - first) / first) * 100 or 0

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
        nvgText(vg, x + 18, ry + (rowH - 4) / 2, RESOURCE_NAMES[res] or res)

        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
        nvgText(vg, x + w * 0.28, ry + (rowH - 4) / 2, string.format("%.2f", price))

        local changeColor = changePct >= 0 and nvgRGBA(255, 120, 120, 255) or nvgRGBA(120, 230, 140, 255)
        nvgFillColor(vg, changeColor)
        nvgText(vg, x + w * 0.48, ry + (rowH - 4) / 2, string.format("%+.1f%%", changePct))

        local barX = x + w * 0.58
        local barW = w * 0.20
        local supplyRatio = math.max(0, math.min(2, 1 + trendChange / 30))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, ry + (rowH - 4) / 2 - 4, barW, 8, 2)
        nvgFillColor(vg, nvgRGBA(40, 55, 85, 255))
        nvgFill(vg)
        local fillW = barW * math.min(1, supplyRatio / 2)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, ry + (rowH - 4) / 2 - 4, fillW, 8, 2)
        nvgFillColor(vg, supplyRatio < 0.7 and nvgRGBA(255, 120, 120, 230) or supplyRatio > 1.5 and nvgRGBA(120, 200, 255, 230) or nvgRGBA(120, 220, 140, 230))
        nvgFill(vg)

        nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
        local isRare = res == "blueCrystal" or res == "purpleCrystal" or res == "rainbowCrystal"
        nvgFillColor(vg, isRare and nvgRGBA(230, 180, 255, 255) or nvgRGBA(200, 220, 240, 255))
        nvgText(vg, x + w - 12, ry + (rowH - 4) / 2, isRare and "稀有" or "基础")

        addHit(x + 8, ry, w - 16, rowH - 4, function()
            panel.selectedResource = res
        end)
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function MarketPanelExtended.drawTrendChart(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 100, 150, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local res = panel.selectedResource
    local history = playerStateRef and playerStateRef.marketPriceHistory and playerStateRef.marketPriceHistory[res] or {}
    if #history == 0 then history = { BASE_PRICES[res] or 1 } end

    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 255))
    nvgText(vg, x + 15, y + 22, "📈 价格趋势 - " .. (RESOURCE_NAMES[res] or res))

    local currentPrice = history[#history]
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, x + w - 15, y + 22, "当前 " .. string.format("%.2f", currentPrice))

    local chartX = x + 50
    local chartY = y + 50
    local chartW = w - 80
    local chartH = h - 80
    local minVal = math.huge
    local maxVal = -math.huge
    for _, v in ipairs(history) do
        if v < minVal then minVal = v end
        if v > maxVal then maxVal = v end
    end
    if maxVal - minVal < 0.01 then
        minVal = minVal * 0.9
        maxVal = maxVal * 1.1
    end

    nvgBeginPath(vg)
    nvgRoundedRect(vg, chartX, chartY, chartW, chartH, 4)
    nvgFillColor(vg, nvgRGBA(25, 35, 58, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 90, 140, 100))
    nvgStroke(vg)

    for g = 0, 4 do
        local gy = chartY + chartH * g / 4
        nvgBeginPath(vg)
        nvgMoveTo(vg, chartX, gy)
        nvgLineTo(vg, chartX + chartW, gy)
        nvgStrokeColor(vg, nvgRGBA(60, 90, 140, 60))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
        local gval = maxVal - (maxVal - minVal) * g / 4
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(150, 180, 220, 200))
        nvgText(vg, chartX - 6, gy, string.format("%.2f", gval))
    end

    nvgBeginPath(vg)
    nvgMoveTo(vg, chartX + 5, chartY + chartH - 5 - ((history[1] - minVal) / (maxVal - minVal)) * (chartH - 10))
    for i = 2, #history do
        local px = chartX + 5 + (i - 1) * (chartW - 10) / math.max(1, #history - 1)
        local py = chartY + chartH - 5 - ((history[i] - minVal) / (maxVal - minVal)) * (chartH - 10)
        nvgLineTo(vg, px, py)
    end
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 240))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    for i, v in ipairs(history) do
        local px = chartX + 5 + (i - 1) * (chartW - 10) / math.max(1, #history - 1)
        local py = chartY + chartH - 5 - ((v - minVal) / (maxVal - minVal)) * (chartH - 10)
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, 3)
        nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
        nvgFill(vg)
    end

    local resColors = {
        metal = nvgRGBA(200, 200, 220, 255),
        esource = nvgRGBA(255, 220, 100, 255),
        nuclear = nvgRGBA(255, 140, 100, 255),
        blueCrystal = nvgRGBA(120, 200, 255, 255),
        purpleCrystal = nvgRGBA(220, 140, 255, 255),
        rainbowCrystal = nvgRGBA(255, 200, 180, 255),
    }
    local legendY = y + h - 22
    local legendColW = (w - 30) / 6
    for i, r in ipairs(RESOURCE_LIST) do
        local lx = x + 15 + (i - 1) * legendColW
        local c = resColors[r] or nvgRGBA(200, 200, 220, 255)
        nvgBeginPath(vg)
        nvgCircle(vg, lx, legendY, 4)
        nvgFillColor(vg, c)
        nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
        nvgText(vg, lx + 8, legendY, RESOURCE_NAMES[r] or r)
        addHit(lx - 8, legendY - 8, legendColW - 6, 16, function()
            panel.selectedResource = r
        end)
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function MarketPanelExtended.drawEvents(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 100, 150, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local events = playerStateRef and playerStateRef.marketEvents or {}
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(255, 180, 120, 255))
    nvgText(vg, x + 15, y + 22, "⚡ 活跃市场事件（" .. tostring(#events) .. "）")

    if #events == 0 then
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 170, 200, 240))
        nvgText(vg, x + w / 2, y + h / 2, "当前无特殊市场事件，价格平稳")
        return
    end

    local evY = y + 40
    local evH = 50
    for i, ev in ipairs(events) do
        local ry = evY + (i - 1) * (evH + 5)
        if ry + evH > y + h - 10 then break end
        local isShortage = ev.priceMult and ev.priceMult > 1
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 12, ry, w - 24, evH, 4)
        nvgFillColor(vg, isShortage and nvgRGBA(90, 40, 50, 220) or nvgRGBA(40, 70, 90, 220))
        nvgFill(vg)
        nvgStrokeColor(vg, isShortage and nvgRGBA(255, 140, 140, 180) or nvgRGBA(120, 200, 255, 180))
        nvgStroke(vg)

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, isShortage and nvgRGBA(255, 200, 180, 255) or nvgRGBA(180, 220, 255, 255))
        nvgText(vg, x + 22, ry + 14, (isShortage and "📉 " or "📈 ") .. (ev.name or "市场事件"))

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
        nvgText(vg, x + 22, ry + 30, ev.desc or "")

        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, isShortage and nvgRGBA(255, 180, 140, 255) or nvgRGBA(140, 220, 180, 255))
        local multStr = ev.priceMult and string.format("价格 x%.1f", ev.priceMult) or ""
        nvgText(vg, x + w - 22, ry + 14, multStr)

        local affected = ev.affectedResources or {}
        local affStr = ""
        for j, r in ipairs(affected) do
            affStr = affStr .. (RESOURCE_NAMES[r] or r) .. (j < #affected and ", " or "")
        end
        if affStr ~= "" then
            nvgFillColor(vg, nvgRGBA(255, 220, 160, 220))
            nvgText(vg, x + w - 22, ry + 30, "影响: " .. affStr)
        end
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function MarketPanelExtended.drawTradeArea(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 140))
    nvgStroke(vg)

    local res = panel.selectedResource
    local price = playerStateRef and playerStateRef.marketPrices and playerStateRef.marketPrices[res] or BASE_PRICES[res] or 1
    local used = playerStateRef and playerStateRef.dailyTradeStats and (playerStateRef.dailyTradeStats.totalBought or 0) or 0
    local limit = 5000

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 220, 240, 255))
    nvgText(vg, x + 12, y + h / 2, "选中: " .. (RESOURCE_NAMES[res] or res))

    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, x + 140, y + h / 2, string.format("单价 %.2f", price))

    local limitX = x + 255
    local limitBarW = 130
    nvgBeginPath(vg)
    nvgRoundedRect(vg, limitX, y + h / 2 - 6, limitBarW, 12, 3)
    nvgFillColor(vg, nvgRGBA(40, 55, 85, 240))
    nvgFill(vg)
    local limitFill = math.min(limitBarW, limitBarW * (used / limit))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, limitX, y + h / 2 - 6, limitFill, 12, 3)
    nvgFillColor(vg, used > limit * 0.8 and nvgRGBA(255, 140, 120, 240) or nvgRGBA(120, 200, 140, 240))
    nvgFill(vg)
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
    nvgText(vg, limitX + limitBarW / 2, y + h / 2, string.format("限额 %d/%d", used, limit))

    local amountX = limitX + limitBarW + 15
    local amountLbl = "数量 " .. tostring(panel.buyAmount)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 230, 250, 255))
    nvgText(vg, amountX, y + h / 2, amountLbl)

    local btnW = 26
    local btnGap = 4
    local btnStartX = amountX + 50
    for i, step in ipairs({ -10, -1, 1, 10 }) do
        local bx = btnStartX + (i - 1) * (btnW + btnGap)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, y + h / 2 - 12, btnW, 24, 3)
        nvgFillColor(vg, nvgRGBA(50, 70, 110, 230))
        nvgFill(vg)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(240, 245, 255, 255))
        nvgText(vg, bx + btnW / 2, y + h / 2, (step > 0 and "+" or "") .. tostring(step))
        addHit(bx, y + h / 2 - 12, btnW, 24, function()
            panel.buyAmount = math.max(1, panel.buyAmount + step)
            panel.sellAmount = panel.buyAmount
        end)
    end

    local buyX = btnStartX + 4 * (btnW + btnGap) + 10
    nvgBeginPath(vg)
    nvgRoundedRect(vg, buyX, y + 8, 90, h - 16, 4)
    nvgFillColor(vg, nvgRGBA(80, 140, 80, 230))
    nvgFill(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(240, 255, 230, 255))
    nvgText(vg, buyX + 45, y + h / 2, "买入 " .. tostring(panel.buyAmount))
    addHit(buyX, y + 8, 90, h - 16, function()
        MarketPanelExtended.buy(panel.selectedResource, panel.buyAmount, panel.rm)
    end)

    local sellX = buyX + 90 + 8
    nvgBeginPath(vg)
    nvgRoundedRect(vg, sellX, y + 8, 90, h - 16, 4)
    nvgFillColor(vg, nvgRGBA(160, 80, 90, 230))
    nvgFill(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 230, 255))
    nvgText(vg, sellX + 45, y + h / 2, "卖出 " .. tostring(panel.sellAmount))
    addHit(sellX, y + 8, 90, h - 16, function()
        MarketPanelExtended.sell(panel.selectedResource, panel.sellAmount, panel.rm)
    end)
end

return MarketPanelExtended
