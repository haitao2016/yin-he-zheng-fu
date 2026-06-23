---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/TradeRoutePanel.lua -- 贸易航线派遣与结算面板
-- V3.3
-- ============================================================================

local TradeRoutePanel = {}

local panel = nil
local playerStateRef = nil
local activeMissionRef = nil

local DEMO_ROUTES = {
    {
        id = "COASTAL_RUN",
        name = "沿岸航线",
        desc = "短途低风险，适合新手",
        travelTime = 30,
        riskLevel = 1,
        minFleetPower = 100,
        baseRewards = { metal = 200, esource = 50 },
        rareChance = 0.05,
        unlockWave = 0,
    },
    {
        id = "MERCHANT_LANE",
        name = "商人航道",
        desc = "中等距离，常规贸易路线",
        travelTime = 90,
        riskLevel = 2,
        minFleetPower = 300,
        baseRewards = { metal = 500, esource = 200, nuclear = 30 },
        rareChance = 0.15,
        unlockWave = 10,
    },
    {
        id = "DEEP_SPACE",
        name = "深空贸易线",
        desc = "危险但收益丰厚，适合有经验的指挥官",
        travelTime = 180,
        riskLevel = 4,
        minFleetPower = 800,
        baseRewards = { metal = 1500, esource = 600, nuclear = 150 },
        rareChance = 0.35,
        unlockWave = 30,
    },
    {
        id = "PIRATE_BORDER",
        name = "海盗边境线",
        desc = "高风险高回报，可能触发战斗",
        travelTime = 240,
        riskLevel = 5,
        minFleetPower = 1500,
        baseRewards = { metal = 3000, esource = 1200, nuclear = 400 },
        rareChance = 0.55,
        encounterChance = 0.4,
        unlockWave = 50,
    },
}

local RESOURCE_NAMES = {
    metal = "金属",
    esource = "能源晶体",
    nuclear = "核燃料",
    blueCrystal = "蓝晶石",
    purpleCrystal = "紫晶石",
    rainbowCrystal = "彩虹晶",
}

---@param vg userdata
---@param sw number
---@param sh number
function TradeRoutePanel.init(vg, sw, sh)
    TradeRoutePanel.vg = vg
    TradeRoutePanel.sw = sw or 800
    TradeRoutePanel.sh = sh or 600
end

---@param playerState table
---@return table
function TradeRoutePanel.open(playerState)
    playerStateRef = playerState
    panel = {
        visible = true,
        w = 760,
        h = 520,
        selectedRouteId = "COASTAL_RUN",
        fleetPower = 500,
        useExtraSupply = false,
        history = TradeRoutePanel.getDemoHistory(),
    }
    return panel
end

function TradeRoutePanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

---@return boolean
function TradeRoutePanel.isOpen()
    return panel ~= nil and panel.visible == true
end

---@param routeId string
function TradeRoutePanel.selectRoute(routeId)
    if not panel then return end
    panel.selectedRouteId = routeId
end

---@param power number
---@return boolean ok
---@return string message
function TradeRoutePanel.dispatchFleet(power)
    if not panel then return false, "面板未打开" end
    local route = TradeRoutePanel.getRouteById(panel.selectedRouteId)
    if not route then return false, "航线不存在" end
    local p = power or panel.fleetPower or 0
    if p < route.minFleetPower then
        return false, "舰队战力不足（需要 " .. tostring(route.minFleetPower) .. "）"
    end

    local ok, TRS = pcall(require, "game.systems.TradeRouteSystem")
    if ok and TRS and TRS.sendFleet then
        local s, msg = TRS.sendFleet(route.id, p)
        if s then
            activeMissionRef = TRS.getActiveMission and TRS.getActiveMission() or nil
        end
        return s, msg
    end

    activeMissionRef = {
        routeId = route.id,
        routeName = route.name,
        totalTime = route.travelTime,
        elapsed = 0,
        remaining = route.travelTime,
        progress = 0,
        riskLevel = route.riskLevel,
        power = p,
        startAt = os.time(),
        useSupply = panel.useExtraSupply,
    }
    return true, "舰队已出发：" .. route.name
end

---@return boolean ok
---@return string message
function TradeRoutePanel.recallMission()
    if not panel then return false, "面板未打开" end
    local ok, TRS = pcall(require, "game.systems.TradeRouteSystem")
    if ok and TRS and TRS.cancelMission then
        local s, msg = TRS.cancelMission()
        if s then activeMissionRef = nil end
        return s, msg
    end
    if activeMissionRef then
        table.insert(panel.history, 1, {
            routeName = activeMissionRef.routeName,
            rewards = {},
            recalled = true,
            completedAt = os.time(),
        })
        activeMissionRef = nil
        return true, "舰队已召回"
    end
    return false, "无进行中的任务"
end

---@return table|nil
function TradeRoutePanel.getActiveMission()
    local ok, TRS = pcall(require, "game.systems.TradeRouteSystem")
    if ok and TRS and TRS.getActiveMission then
        local m = TRS.getActiveMission()
        if m then return m end
    end
    return activeMissionRef
end

---@return table
function TradeRoutePanel.getAllRoutes()
    local ok, TRS = pcall(require, "game.systems.TradeRouteSystem")
    if ok and TRS and TRS.getAllRoutes then
        local list = TRS.getAllRoutes()
        if list and #list > 0 then return list end
    end
    return DEMO_ROUTES
end

---@param routeId string
---@return table|nil
function TradeRoutePanel.getRouteById(routeId)
    for _, r in ipairs(TradeRoutePanel.getAllRoutes()) do
        if r.id == routeId then return r end
    end
    return nil
end

---@return table
function TradeRoutePanel.getDemoHistory()
    local list = {}
    for i = 1, 5 do
        table.insert(list, {
            routeName = DEMO_ROUTES[(i % #DEMO_ROUTES) + 1].name,
            rewards = { metal = 200 + i * 50, esource = 80 + i * 20 },
            completedAt = os.time() - i * 600,
        })
    end
    return list
end

---@param dt number
function TradeRoutePanel.render(dt)
    local vg = TradeRoutePanel.vg or _G.BS and _G.BS.vg or nil
    if not vg then return end
    TradeRoutePanel.draw(vg)
end

---@param x number
---@param y number
function TradeRoutePanel.handleClick(x, y)
    if not panel or not panel.visible then return end
    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or TradeRoutePanel.sw) / 2, (BS and BS.screenH or TradeRoutePanel.sh) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2
    if x >= px and x <= px + pw and y >= py and y <= py + ph then
        local closeX = px + pw - 35
        local closeY = py + 12
        if math.abs(x - closeX) <= 14 and math.abs(y - closeY) <= 14 then
            TradeRoutePanel.close()
            return
        end
    end
end

---@param vg userdata
function TradeRoutePanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or TradeRoutePanel.sw) / 2, (BS and BS.screenH or TradeRoutePanel.sh) / 2
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
    nvgText(vg, cx, py + 30, "贸易航线派遣")

    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        TradeRoutePanel.close()
    end)

    TradeRoutePanel.drawStatusBar(vg, px + 15, py + 55, pw - 30, 70)

    local listX = px + 15
    local listY = py + 135
    local listW = (pw - 30) * 0.48
    local listH = ph - 240
    TradeRoutePanel.drawRouteList(vg, listX, listY, listW, listH)

    local cfgX = listX + listW + 10
    local cfgW = pw - 30 - listW - 10
    TradeRoutePanel.drawDispatchConfig(vg, cfgX, listY, cfgW, listH)

    TradeRoutePanel.drawBottomBar(vg, px + 15, py + ph - 85, pw - 30, 70)
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function TradeRoutePanel.drawStatusBar(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local mission = TradeRoutePanel.getActiveMission()
    nvgFontFace(vg, "sans")
    if mission then
        local elapsed = mission.elapsed or (os.time() - (mission.startAt or os.time()))
        local total = mission.totalTime or 1
        local progress = math.min(1, elapsed / total)
        local remaining = math.max(0, total - elapsed)

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(120, 220, 180, 255))
        nvgText(vg, x + 15, y + 18, "🚀 航行中: " .. (mission.routeName or "未知航线"))

        nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
        nvgText(vg, x + 15, y + 38, "已用时间: " .. TradeRoutePanel.formatTime(elapsed) .. " / 剩余: " .. TradeRoutePanel.formatTime(remaining))

        local barX = x + 15
        local barY = y + 46
        local barW = w - 150
        local barH = 10
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 3)
        nvgFillColor(vg, nvgRGBA(40, 55, 85, 255))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * progress, barH, 3)
        nvgFillColor(vg, nvgRGBA(100, 220, 160, 240))
        nvgFill(vg)

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, barX + barW / 2, barY + 9, string.format("%.1f%%", progress * 100))

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 180, 120, 240))
        nvgText(vg, x + w - 15, y + 18, "战力投入: " .. tostring(mission.power or "?"))
        nvgFillColor(vg, nvgRGBA(230, 180, 230, 240))
        nvgText(vg, x + w - 15, y + 38, "风险等级: " .. string.rep("★", mission.riskLevel or 1))
    else
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 255))
        nvgText(vg, x + 15, y + h / 2, "⏸ 当前无进行中的任务 - 请从左侧列表选择航线并派遣舰队")
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function TradeRoutePanel.drawRouteList(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStroke(vg)

    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(150, 200, 255, 255))
    nvgText(vg, x + 12, y + 18, "🧭 可用航线")

    local routes = TradeRoutePanel.getAllRoutes()
    local itemY = y + 30
    local itemH = 72
    local itemGap = 6
    for i, route in ipairs(routes) do
        local ry = itemY + (i - 1) * (itemH + itemGap)
        if ry + itemH > y + h - 8 then break end
        local isSelected = panel.selectedRouteId == route.id
        local riskColor = nvgRGBA(140, 220, 140, 255)
        if route.riskLevel >= 3 then riskColor = nvgRGBA(255, 200, 120, 255) end
        if route.riskLevel >= 4 then riskColor = nvgRGBA(255, 140, 140, 255) end

        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 8, ry, w - 16, itemH, 5)
        nvgFillColor(vg, isSelected and nvgRGBA(55, 95, 155, 230) or nvgRGBA(28, 38, 60, 220))
        nvgFill(vg)
        nvgStrokeColor(vg, isSelected and nvgRGBA(120, 180, 255, 200) or nvgRGBA(70, 100, 150, 100))
        nvgStroke(vg)

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(240, 245, 255, 255))
        nvgText(vg, x + 18, ry + 14, route.name)

        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(170, 190, 220, 240))
        nvgText(vg, x + 18, ry + 30, route.desc or "")

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
        nvgText(vg, x + 18, ry + 48, "时长: " .. TradeRoutePanel.formatTime(route.travelTime))
        nvgText(vg, x + 130, ry + 48, "最小战力: " .. tostring(route.minFleetPower))

        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, riskColor)
        nvgText(vg, x + w - 18, ry + 14, "风险 " .. string.rep("★", route.riskLevel or 1))

        local rewardText = ""
        if route.baseRewards then
            local j = 1
            for k, v in pairs(route.baseRewards) do
                if j > 2 then break end
                rewardText = rewardText .. (RESOURCE_NAMES[k] or k) .. " x" .. tostring(v) .. "  "
                j = j + 1
            end
        end
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
        nvgText(vg, x + w - 18, ry + 48, rewardText)

        if route.rareChance and route.rareChance > 0 then
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBA(230, 180, 255, 240))
            nvgTextAlign(vg, NVG_ALIGN.LEFT)
            nvgText(vg, x + 18, ry + 62, "稀有几率: " .. string.format("%.0f%%", route.rareChance * 100))
        end

        addHit(x + 8, ry, w - 16, itemH, function()
            TradeRoutePanel.selectRoute(route.id)
        end)
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function TradeRoutePanel.drawDispatchConfig(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStroke(vg)

    local route = TradeRoutePanel.getRouteById(panel.selectedRouteId) or DEMO_ROUTES[1]
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(150, 200, 255, 255))
    nvgText(vg, x + 12, y + 18, "⚙️ 派遣配置: " .. (route.name or ""))

    local sectionY = y + 38
    local labelW = 140

    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
    nvgText(vg, x + 15, sectionY, "舰队战力:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, x + labelW, sectionY, tostring(panel.fleetPower))

    local barX = x + labelW + 8
    local barY = sectionY - 10
    local barW = w - labelW - 30
    local barH = 10
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(40, 55, 85, 255))
    nvgFill(vg)
    local powerRatio = math.min(1, panel.fleetPower / (route.minFleetPower * 3 or 1))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW * powerRatio, barH, 3)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 240))
    nvgFill(vg)

    local pwrBtns = { 100, 300, 500, 1000, 2000 }
    local btnY = sectionY + 10
    local btnW = (w - 30 - 4 * 4) / 5
    for i, pw in ipairs(pwrBtns) do
        local bx = x + 15 + (i - 1) * (btnW + 4)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, btnY, btnW, 22, 3)
        nvgFillColor(vg, panel.fleetPower == pw and nvgRGBA(60, 110, 180, 230) or nvgRGBA(40, 55, 85, 230))
        nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
        nvgText(vg, bx + btnW / 2, btnY + 11, "+" .. tostring(pw))
        addHit(bx, btnY, btnW, 22, function()
            panel.fleetPower = pw
        end)
    end

    local supplyY = btnY + 34
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
    nvgText(vg, x + 15, supplyY, "额外补给:")

    local cbX = x + labelW - 8
    local cbY = supplyY - 10
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbX, cbY, 20, 20, 4)
    nvgFillColor(vg, panel.useExtraSupply and nvgRGBA(80, 160, 100, 240) or nvgRGBA(50, 70, 100, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 160, 210, 180))
    nvgStroke(vg)
    if panel.useExtraSupply then
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, cbX + 10, cbY + 10, "✓")
    end
    addHit(cbX, cbY, 20, 20, function()
        panel.useExtraSupply = not panel.useExtraSupply
    end)

    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 220))
    nvgText(vg, cbX + 28, supplyY, "(提升收益并降低风险)")

    local estY = supplyY + 30
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 220, 140, 255))
    nvgText(vg, x + 15, estY, "📊 预估收益 / 风险")

    local powerFactor = math.min(2.0, 1.0 + (panel.fleetPower - route.minFleetPower) / (route.minFleetPower * 2 + 1))
    local supplyBoost = panel.useExtraSupply and 1.2 or 1.0
    local totalMult = powerFactor * supplyBoost

    local estY2 = estY + 18
    local rewardsList = {}
    if route.baseRewards then
        for k, v in pairs(route.baseRewards) do
            table.insert(rewardsList, { name = RESOURCE_NAMES[k] or k, val = math.floor(v * totalMult) })
        end
    end

    nvgFontSize(vg, 11)
    for i, r in ipairs(rewardsList) do
        if i > 3 then break end
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
        nvgText(vg, x + 25, estY2 + (i - 1) * 16, r.name .. ":")
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 255))
        nvgText(vg, x + w - 20, estY2 + (i - 1) * 16, "≈ " .. tostring(r.val))
    end

    local estRiskY = estY2 + 3 * 16 + 4
    local riskReduction = panel.useExtraSupply and 0.5 or 1.0
    local effectiveRisk = math.max(1, math.ceil((route.riskLevel or 1) * riskReduction))
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 240, 240))
    nvgText(vg, x + 15, estRiskY, "预估风险等级: ")
    nvgFillColor(vg, effectiveRisk >= 4 and nvgRGBA(255, 140, 140, 255) or effectiveRisk >= 3 and nvgRGBA(255, 200, 120, 255) or nvgRGBA(140, 220, 140, 255))
    nvgText(vg, x + 120, estRiskY, string.rep("★", effectiveRisk))

    local ok, TRS = pcall(require, "game.systems.TradeRouteSystem")
    local busy = ok and TRS and TRS.isBusy and TRS.isBusy() or (activeMissionRef ~= nil)

    local dispatchY = y + h - 42
    local hasEnough = panel.fleetPower >= route.minFleetPower
    local canDispatch = not busy and hasEnough

    local recallW = w * 0.28
    local recallX = x + w - recallW - 15
    if busy then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, recallX, dispatchY, recallW, 32, 4)
        nvgFillColor(vg, nvgRGBA(180, 80, 90, 230))
        nvgFill(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 240, 240, 255))
        nvgText(vg, recallX + recallW / 2, dispatchY + 16, "↩ 召回舰队")
        addHit(recallX, dispatchY, recallW, 32, function()
            TradeRoutePanel.recallMission()
        end)
    end

    local dispatchW = busy and (w - recallW - 40) or (w - 30)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x + 15, dispatchY, dispatchW, 32, 4)
    nvgFillColor(vg, canDispatch and nvgRGBA(80, 140, 90, 230) or nvgRGBA(80, 80, 100, 220))
    nvgFill(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(240, 255, 230, 255))
    local msg = ""
    if busy then
        msg = "舰队已在航行中..."
    elseif not hasEnough then
        msg = "战力不足 (需 " .. tostring(route.minFleetPower) .. ")"
    else
        msg = "🚀 派遣舰队 - 预计用时 " .. TradeRoutePanel.formatTime(route.travelTime)
    end
    nvgText(vg, x + 15 + dispatchW / 2, dispatchY + 16, msg)
    if canDispatch then
        addHit(x + 15, dispatchY, dispatchW, 32, function()
            TradeRoutePanel.dispatchFleet(panel.fleetPower)
        end)
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function TradeRoutePanel.drawBottomBar(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 255))
    nvgText(vg, x + 15, y + 16, "📜 最近任务记录")

    local history = panel.history or {}
    if #history == 0 then
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 170, 200, 220))
        nvgText(vg, x + w / 2, y + 40, "暂无记录")
        return
    end

    local itemW = (w - 30 - 4 * 9) / 5
    for i = 1, math.min(5, #history) do
        local hx = x + 15 + (i - 1) * (itemW + 9)
        local hy = y + 28
        local hh = h - 36
        local entry = history[i]

        nvgBeginPath(vg)
        nvgRoundedRect(vg, hx, hy, itemW, hh, 4)
        nvgFillColor(vg, nvgRGBA(30, 45, 70, 230))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 170, 120))
        nvgStroke(vg)

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(230, 240, 255, 240))
        nvgText(vg, hx + itemW / 2, hy + 12, entry.routeName or "?")

        if entry.recalled then
            nvgFillColor(vg, nvgRGBA(255, 180, 140, 240))
            nvgText(vg, hx + itemW / 2, hy + 26, "(已召回)")
        else
            local line = 26
            if entry.rewards then
                local j = 0
                for k, v in pairs(entry.rewards) do
                    if j >= 2 then break end
                    nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
                    nvgText(vg, hx + itemW / 2, hy + line, (RESOURCE_NAMES[k] or k) .. " x" .. tostring(v))
                    line = line + 12
                    j = j + 1
                end
            end
        end

        nvgFontSize(vg, 8)
        nvgFillColor(vg, nvgRGBA(150, 180, 210, 200))
        nvgText(vg, hx + itemW / 2, hy + hh - 6, TradeRoutePanel.formatDate(entry.completedAt or os.time()))
    end
end

---@param seconds number
---@return string
function TradeRoutePanel.formatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    if seconds >= 60 then
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%02d:%02d", m, s)
    end
    return tostring(math.floor(seconds)) .. "s"
end

---@param ts number
---@return string
function TradeRoutePanel.formatDate(ts)
    return os.date("%m-%d %H:%M", ts or os.time())
end

return TradeRoutePanel
