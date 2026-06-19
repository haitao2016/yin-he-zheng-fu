---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/InvestmentOverviewPanel.lua -- 投资总览面板
-- V3.3
-- ============================================================================

local InvestmentOverviewPanel = {}

local panel = nil
local playerStateRef = nil

local INVESTMENT_OPTIONS = {
    {
        id = "MINING_BOOST",
        name = "矿业投资",
        desc = "提升该星球矿产产出",
        cost = { metal = 500, esource = 200 },
        duration = 3600,
        effect = { mineralMult = 1.5 },
        tier = 1,
    },
    {
        id = "ENERGY_BOOST",
        name = "能源投资",
        desc = "提升该星球能源产出",
        cost = { metal = 400, esource = 300 },
        duration = 3600,
        effect = { energyMult = 1.5 },
        tier = 1,
    },
    {
        id = "RESEARCH_BOOST",
        name = "科研投资",
        desc = "提升该星球科研速度",
        cost = { metal = 600, esource = 400, nuclear = 100 },
        duration = 7200,
        effect = { researchMult = 2.0 },
        tier = 2,
    },
    {
        id = "TRADE_BOOST",
        name = "贸易投资",
        desc = "提升贸易路线收益",
        cost = { metal = 800, esource = 500 },
        duration = 3600,
        effect = { tradeMult = 1.3 },
        tier = 2,
    },
    {
        id = "DEFENSE_BOOST",
        name = "防御投资",
        desc = "提升该星球防御能力",
        cost = { metal = 1000, esource = 600, nuclear = 200 },
        duration = 7200,
        effect = { defenseMult = 1.5, turretCount = 2 },
        tier = 2,
    },
    {
        id = "CRYSTAL_MINING",
        name = "晶体矿脉开采",
        desc = "持续产出稀有蓝水晶",
        cost = { metal = 1500, nuclear = 300, blueCrystal = 2 },
        duration = 5400,
        effect = { crystalYield = 1.8, blueCrystalPerHour = 3 },
        tier = 3,
    },
    {
        id = "GALACTIC_TRADE_HUB",
        name = "银河贸易枢纽",
        desc = "顶级投资：全局贸易收益 +30%",
        cost = { metal = 5000, esource = 3000, purpleCrystal = 5 },
        duration = 14400,
        effect = { tradeMult = 1.3, globalResourceMult = 1.1 },
        tier = 4,
    },
}

local DEMO_PLANETS = {
    { id = "P_AURORA", name = "曙光星",   desc = "矿业基地" },
    { id = "P_NOVA",   name = "新星市",   desc = "能源枢纽" },
    { id = "P_TITAN",  name = "泰坦堡",   desc = "重工业中心" },
    { id = "P_LYRA",   name = "天琴座站", desc = "科研前哨" },
    { id = "P_VEGA",   name = "织女星港", desc = "贸易口岸" },
}

local RESOURCE_NAMES = {
    metal = "金属",
    esource = "能源晶体",
    nuclear = "核燃料",
    blueCrystal = "蓝晶石",
    purpleCrystal = "紫晶石",
    rainbowCrystal = "彩虹晶",
}

local EFFECT_LABELS = {
    mineralMult = "矿产产出倍率",
    energyMult = "能源产出倍率",
    researchMult = "科研速度倍率",
    tradeMult = "贸易收益倍率",
    defenseMult = "防御能力倍率",
    turretCount = "新增炮塔数量",
    crystalYield = "晶体产出倍率",
    blueCrystalPerHour = "蓝晶石/小时",
    purpleCrystalPerHour = "紫晶石/小时",
    rainbowCrystalPerHour = "彩虹晶/小时",
    globalResourceMult = "全局资源倍率",
}

---@param vg userdata
---@param sw number
---@param sh number
function InvestmentOverviewPanel.init(vg, sw, sh)
    InvestmentOverviewPanel.vg = vg
    InvestmentOverviewPanel.sw = sw or 800
    InvestmentOverviewPanel.sh = sh or 600
end

---@param playerState table
---@return table
function InvestmentOverviewPanel.open(playerState)
    playerStateRef = playerState
    panel = {
        visible = true,
        w = 780,
        h = 540,
        selectedPlanet = "P_AURORA",
        selectedInvestmentIndex = 0,
        newInvestmentTypeIndex = 1,
        newInvestmentPlanetIndex = 1,
        planetActiveCache = {},
    }
    return panel
end

function InvestmentOverviewPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

---@return boolean
function InvestmentOverviewPanel.isOpen()
    return panel ~= nil and panel.visible == true
end

---@param planetId string
function InvestmentOverviewPanel.selectPlanet(planetId)
    if not panel then return end
    panel.selectedPlanet = planetId
    panel.selectedInvestmentIndex = 0
end

---@param index number
function InvestmentOverviewPanel.selectInvestment(index)
    if not panel then return end
    panel.selectedInvestmentIndex = index or 0
end

---@return boolean ok
---@return string message
function InvestmentOverviewPanel.cancelInvestment()
    if not panel then return false, "面板未打开" end
    if panel.selectedInvestmentIndex <= 0 then
        return false, "请先选择一项投资"
    end
    local planet = InvestmentOverviewPanel.getPlanetById(panel.selectedPlanet)
    local activeList = InvestmentOverviewPanel.getPlanetActiveInvestments(planet and planet.id or panel.selectedPlanet)
    if panel.selectedInvestmentIndex > #activeList then
        return false, "投资序号越界"
    end
    local idx = panel.selectedInvestmentIndex
    table.remove(activeList, idx)
    if playerStateRef and playerStateRef.planetInvestments then
        local pid = planet and planet.id or panel.selectedPlanet
        if playerStateRef.planetInvestments[pid] then
            table.remove(playerStateRef.planetInvestments[pid], idx)
        end
    end
    panel.selectedInvestmentIndex = 0
    return true, "投资已取消，资源部分返还"
end

---@return table
function InvestmentOverviewPanel.getOverviewStats()
    local stats = {
        totalInvestments = 0,
        activePlanets = 0,
        aggregatedEffects = {},
        highestTier = 0,
        nextExpiringName = nil,
        nextExpiringAt = nil,
        totalCost = {},
    }
    local planets = InvestmentOverviewPanel.getPlanets()
    for _, p in ipairs(planets) do
        local list = InvestmentOverviewPanel.getPlanetActiveInvestments(p.id)
        if #list > 0 then
            stats.activePlanets = stats.activePlanets + 1
        end
        for _, inv in ipairs(list) do
            stats.totalInvestments = stats.totalInvestments + 1
            local opt = InvestmentOverviewPanel.getOptionById(inv.id)
            if opt and opt.tier and opt.tier > stats.highestTier then
                stats.highestTier = opt.tier
            end
            if inv.effects then
                for k, v in pairs(inv.effects) do
                    if type(v) == "number" then
                        if string.find(k, "Mult") or string.find(k, "Bonus") then
                            stats.aggregatedEffects[k] = (stats.aggregatedEffects[k] or 1.0) * v
                        else
                            stats.aggregatedEffects[k] = (stats.aggregatedEffects[k] or 0) + v
                        end
                    end
                end
            end
            if inv.remaining and (stats.nextExpiringAt == nil or inv.remaining < stats.nextExpiringAt) then
                stats.nextExpiringAt = inv.remaining
                stats.nextExpiringName = inv.name
            end
            if opt and opt.cost then
                for k, v in pairs(opt.cost) do
                    stats.totalCost[k] = (stats.totalCost[k] or 0) + v
                end
            end
        end
    end
    return stats
end

---@return table
function InvestmentOverviewPanel.getPlanets()
    local ok, backend = pcall(require, "game.systems.InvestmentSystem")
    if ok and backend and backend.getPlanets then
        local list = backend.getPlanets()
        if list and #list > 0 then return list end
    end
    return DEMO_PLANETS
end

---@param planetId string
---@return table|nil
function InvestmentOverviewPanel.getPlanetById(planetId)
    for _, p in ipairs(InvestmentOverviewPanel.getPlanets()) do
        if p.id == planetId then return p end
    end
    return nil
end

---@param optionId string
---@return table|nil
function InvestmentOverviewPanel.getOptionById(optionId)
    for _, opt in ipairs(INVESTMENT_OPTIONS) do
        if opt.id == optionId then return opt end
    end
    return nil
end

---@param planetId string
---@return table
function InvestmentOverviewPanel.getPlanetActiveInvestments(planetId)
    if playerStateRef and playerStateRef.planetInvestments and playerStateRef.planetInvestments[planetId] then
        local list = playerStateRef.planetInvestments[planetId]
        local now = os.time()
        local active = {}
        for _, inv in ipairs(list) do
            local endTime = inv.endTime or (inv.startTime or now) + (inv.duration or 3600)
            local remaining = math.max(0, endTime - now)
            if remaining > 0 then
                table.insert(active, {
                    id = inv.id,
                    name = inv.name or (InvestmentOverviewPanel.getOptionById(inv.id) and InvestmentOverviewPanel.getOptionById(inv.id).name) or inv.id,
                    remaining = remaining,
                    duration = inv.duration or 3600,
                    startTime = inv.startTime or now,
                    endTime = endTime,
                    effects = inv.effects or (InvestmentOverviewPanel.getOptionById(inv.id) and InvestmentOverviewPanel.getOptionById(inv.id).effect) or {},
                    cost = inv.cost or {},
                })
            end
        end
        return active
    end
    local ok, backend = pcall(require, "game.systems.InvestmentSystem")
    if ok and backend and backend.getActiveInvestments then
        local list = backend.getActiveInvestments(planetId, playerStateRef)
        if list and #list > 0 then
            local result = {}
            for _, inv in ipairs(list) do
                table.insert(result, {
                    id = inv.id,
                    name = inv.name,
                    remaining = inv.remaining or 0,
                    duration = inv.duration or 3600,
                    effects = inv.effects or {},
                    cost = inv.cost or {},
                })
            end
            return result
        end
    end
    local seeded = (string.byte(planetId or "?", 1) or 0) % 3
    if seeded == 0 then return {} end
    local demo = {}
    local now = os.time()
    for i = 1, seeded do
        local opt = INVESTMENT_OPTIONS[((i - 1) * 2) % #INVESTMENT_OPTIONS + 1]
        table.insert(demo, {
            id = opt.id,
            name = opt.name,
            remaining = math.floor(opt.duration * (0.3 + (i * 0.2))),
            duration = opt.duration,
            startTime = now - (opt.duration - math.floor(opt.duration * (0.3 + (i * 0.2)))),
            endTime = now + math.floor(opt.duration * (0.3 + (i * 0.2))),
            effects = opt.effect,
            cost = opt.cost,
        })
    end
    return demo
end

---@param dt number
function InvestmentOverviewPanel.render(dt)
    local vg = InvestmentOverviewPanel.vg or _G.BS and _G.BS.vg or nil
    if not vg then return end
    InvestmentOverviewPanel.draw(vg)
end

---@param x number
---@param y number
function InvestmentOverviewPanel.handleClick(x, y)
    if not panel or not panel.visible then return end
    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or InvestmentOverviewPanel.sw) / 2, (BS and BS.screenH or InvestmentOverviewPanel.sh) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2
    if x >= px and x <= px + pw and y >= py and y <= py + ph then
        local closeX = px + pw - 35
        local closeY = py + 12
        if math.abs(x - closeX) <= 14 and math.abs(y - closeY) <= 14 then
            InvestmentOverviewPanel.close()
            return
        end
    end
end

---@param vg userdata
function InvestmentOverviewPanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or InvestmentOverviewPanel.sw) / 2, (BS and BS.screenH or InvestmentOverviewPanel.sh) / 2
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
    nvgText(vg, cx, py + 30, "投资总览")

    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        InvestmentOverviewPanel.close()
    end)

    local summaryY = py + 55
    InvestmentOverviewPanel.drawSummary(vg, px + 15, summaryY, pw - 30, 70)

    local contentY = summaryY + 80
    local contentH = ph - (contentY - py) - 100

    local listW = (pw - 30 - 10) * 0.42
    InvestmentOverviewPanel.drawPlanetList(vg, px + 15, contentY, listW, contentH)

    local detailX = px + 15 + listW + 10
    local detailW = pw - 30 - listW - 10
    InvestmentOverviewPanel.drawInvestmentDetail(vg, detailX, contentY, detailW, contentH)

    InvestmentOverviewPanel.drawBottomBar(vg, px + 15, py + ph - 90, pw - 30, 80)
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function InvestmentOverviewPanel.drawSummary(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 170, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    local stats = InvestmentOverviewPanel.getOverviewStats()

    local statW = (w - 20) / 4
    local statItems = {
        { label = "投资总数",     value = tostring(stats.totalInvestments), color = nvgRGBA(255, 220, 140, 255) },
        { label = "活跃星球",     value = tostring(stats.activePlanets), color = nvgRGBA(140, 220, 255, 255) },
        { label = "最高等级",     value = "T" .. tostring(stats.highestTier), color = nvgRGBA(230, 180, 255, 255) },
        { label = "即将到期",     value = stats.nextExpiringName or "(无)", color = nvgRGBA(255, 180, 180, 255) },
    }

    for i, item in ipairs(statItems) do
        local sx = x + 5 + (i - 1) * statW
        local sy = y + 12

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(180, 200, 230, 240))
        nvgText(vg, sx + 8, sy, item.label)

        nvgFontSize(vg, 16)
        nvgFillColor(vg, item.color)
        local val = item.value
        if #val > 12 then val = string.sub(val, 1, 10) .. ".." end
        nvgText(vg, sx + 8, sy + 22, val)
    end

    local effectY = y + h - 30
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
    nvgText(vg, x + 10, effectY, "加成系数:")

    local ex = x + 70
    local eCount = 0
    for k, v in pairs(stats.aggregatedEffects) do
        if eCount >= 5 then break end
        local label = EFFECT_LABELS[k] or k
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(160, 190, 220, 240))
        nvgText(vg, ex, effectY - 6, label)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 255))
        local fmt = type(v) == "number" and (v >= 10 and string.format("+%.0f", v - (string.find(k, "Mult") and 1 or 0)) or string.format("x%.2f", v)) or tostring(v)
        nvgText(vg, ex, effectY + 8, fmt)
        ex = ex + 110
        eCount = eCount + 1
    end
    if eCount == 0 then
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(150, 170, 200, 200))
        nvgText(vg, ex, effectY, "(暂无投资加成)")
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function InvestmentOverviewPanel.drawPlanetList(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(150, 200, 255, 255))
    nvgText(vg, x + 12, y + 18, "🪐 星球投资列表")

    local planets = InvestmentOverviewPanel.getPlanets()
    local itemY = y + 30
    local itemH = 54
    local itemGap = 5
    for i, planet in ipairs(planets) do
        local ry = itemY + (i - 1) * (itemH + itemGap)
        if ry + itemH > y + h - 8 then break end
        local isSelected = panel.selectedPlanet == planet.id
        local activeList = InvestmentOverviewPanel.getPlanetActiveInvestments(planet.id)
        local activeCount = #activeList

        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 8, ry, w - 16, itemH, 5)
        nvgFillColor(vg, isSelected and nvgRGBA(55, 95, 155, 230) or nvgRGBA(28, 38, 60, 220))
        nvgFill(vg)
        nvgStrokeColor(vg, isSelected and nvgRGBA(120, 180, 255, 200) or nvgRGBA(70, 100, 150, 100))
        nvgStroke(vg)

        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(240, 245, 255, 255))
        nvgText(vg, x + 18, ry + 14, planet.name)

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(170, 190, 220, 230))
        nvgText(vg, x + 18, ry + 28, planet.desc or "")

        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, activeCount > 0 and nvgRGBA(255, 220, 140, 255) or nvgRGBA(150, 170, 200, 220))
        nvgText(vg, x + w - 18, ry + 14, tostring(activeCount) .. " 项活跃")

        if activeCount > 0 then
            local nearestRemaining = nil
            for _, inv in ipairs(activeList) do
                if nearestRemaining == nil or inv.remaining < nearestRemaining then
                    nearestRemaining = inv.remaining
                end
            end
            nvgFillColor(vg, nvgRGBA(180, 220, 180, 240))
            nvgText(vg, x + w - 18, ry + 28, "最近: " .. InvestmentOverviewPanel.formatDuration(nearestRemaining))
        else
            nvgFillColor(vg, nvgRGBA(150, 170, 200, 200))
            nvgText(vg, x + w - 18, ry + 28, "(无投资)")
        end

        if activeCount > 0 then
            local barX = x + 18
            local barY = ry + 38
            local barW = w - 36
            local barH = 6
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW, barH, 2)
            nvgFillColor(vg, nvgRGBA(40, 55, 85, 255))
            nvgFill(vg)
            local totalSeg = barW / math.max(1, activeCount)
            for idx, inv in ipairs(activeList) do
                local sx = barX + (idx - 1) * totalSeg
                local progress = 1 - (inv.remaining / math.max(1, inv.duration))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, sx, barY, totalSeg - 2, barH, 2)
                nvgFillColor(vg, nvgRGBA(60, 80, 120, 200))
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, sx, barY, math.max(2, (totalSeg - 2) * math.min(1, progress)), barH, 2)
                nvgFillColor(vg, nvgRGBA(100, 200, 140, 240))
                nvgFill(vg)
            end
        end

        addHit(x + 8, ry, w - 16, itemH, function()
            InvestmentOverviewPanel.selectPlanet(planet.id)
        end)
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function InvestmentOverviewPanel.drawInvestmentDetail(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(20, 28, 48, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStroke(vg)

    local planet = InvestmentOverviewPanel.getPlanetById(panel.selectedPlanet) or { id = panel.selectedPlanet, name = "未知星球", desc = "" }
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(150, 200, 255, 255))
    nvgText(vg, x + 12, y + 18, "📋 " .. (planet.name or "") .. " - 投资详情")

    local activeList = InvestmentOverviewPanel.getPlanetActiveInvestments(panel.selectedPlanet)

    local listAreaY = y + 32
    local listAreaH = math.min(#activeList * 42 + 4, h - 180)
    if #activeList == 0 then
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 170, 200, 220))
        nvgText(vg, x + w / 2, listAreaY + 30, "该星球暂无活跃投资")
    else
        local itemH = 36
        for i, inv in ipairs(activeList) do
            local ry = listAreaY + 4 + (i - 1) * (itemH + 2)
            if ry + itemH > listAreaY + listAreaH then break end
            local isSel = panel.selectedInvestmentIndex == i
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x + 10, ry, w - 20, itemH, 4)
            nvgFillColor(vg, isSel and nvgRGBA(70, 120, 180, 230) or nvgRGBA(30, 45, 70, 220))
            nvgFill(vg)
            nvgStrokeColor(vg, isSel and nvgRGBA(140, 200, 255, 200) or nvgRGBA(70, 100, 140, 100))
            nvgStroke(vg)

            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.LEFT)
            nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
            nvgText(vg, x + 20, ry + 12, inv.name or "(未命名)")

            local progress = 1 - (inv.remaining / math.max(1, inv.duration))
            local barX = x + 20
            local barY = ry + 18
            local barW = w - 180
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW, 6, 2)
            nvgFillColor(vg, nvgRGBA(40, 55, 85, 255))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW * math.min(1, progress), 6, 2)
            nvgFillColor(vg, nvgRGBA(100, 200, 150, 240))
            nvgFill(vg)

            nvgTextAlign(vg, NVG_ALIGN.RIGHT)
            nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
            nvgText(vg, x + w - 20, ry + 12, "剩余 " .. InvestmentOverviewPanel.formatDuration(inv.remaining))

            addHit(x + 10, ry, w - 20, itemH, function()
                InvestmentOverviewPanel.selectInvestment(i)
            end)
        end
    end

    local detailY = listAreaY + listAreaH + 10
    local detailH = y + h - detailY - 10
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x + 10, detailY, w - 20, detailH, 5)
    nvgFillColor(vg, nvgRGBA(25, 35, 60, 230))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 100, 140, 120))
    nvgStroke(vg)

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 210, 240, 240))
    nvgText(vg, x + 22, detailY + 14, "💼 选中投资详情")

    if panel.selectedInvestmentIndex > 0 and activeList[panel.selectedInvestmentIndex] then
        local inv = activeList[panel.selectedInvestmentIndex]
        local opt = InvestmentOverviewPanel.getOptionById(inv.id)

        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(255, 240, 180, 255))
        nvgText(vg, x + 22, detailY + 34, inv.name or "(未命名)")

        if opt and opt.desc then
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(180, 200, 230, 220))
            nvgText(vg, x + 22, detailY + 50, opt.desc)
        end

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
        nvgText(vg, x + 22, detailY + 66, "剩余时间: " .. InvestmentOverviewPanel.formatDuration(inv.remaining))
        nvgText(vg, x + 22, detailY + 80, "总时长: " .. InvestmentOverviewPanel.formatDuration(inv.duration))

        local effectY = detailY + 96
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(150, 220, 200, 240))
        nvgText(vg, x + 22, effectY, "效果:")

        if inv.effects then
            local j = 1
            for k, v in pairs(inv.effects) do
                local label = EFFECT_LABELS[k] or k
                local ey = effectY + 14 + (j - 1) * 14
                if ey > detailY + detailH - 24 then break end
                nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN.LEFT)
                nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
                nvgText(vg, x + 32, ey, "  · " .. label)
                nvgTextAlign(vg, NVG_ALIGN.RIGHT)
                nvgFillColor(vg, nvgRGBA(255, 220, 140, 255))
                local fmt = type(v) == "number" and (string.find(k, "Mult") and string.format("x%.2f", v) or (v >= 10 and string.format("+%.0f", v) or string.format("+%.2f", v))) or tostring(v)
                nvgText(vg, x + w - 30, ey, fmt)
                j = j + 1
            end
        end

        local cancelY = detailY + detailH - 32
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + w - 160, cancelY, 140, 26, 4)
        nvgFillColor(vg, nvgRGBA(180, 70, 90, 230))
        nvgFill(vg)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 240, 240, 255))
        nvgText(vg, x + w - 90, cancelY + 13, "✖ 取消此项投资")
        addHit(x + w - 160, cancelY, 140, 26, function()
            InvestmentOverviewPanel.cancelInvestment()
        end)

        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(220, 180, 180, 220))
        local refundStr = ""
        if opt and opt.cost then
            local ratio = math.max(0.3, inv.remaining / math.max(1, inv.duration))
            local parts = {}
            for k, v in pairs(opt.cost) do
                table.insert(parts, (RESOURCE_NAMES[k] or k) .. "≈" .. tostring(math.floor(v * ratio)))
            end
            refundStr = "返还: " .. table.concat(parts, ", ")
        end
        if #refundStr > 58 then refundStr = string.sub(refundStr, 1, 56) .. ".." end
        nvgText(vg, x + w - 22, cancelY - 6, refundStr)
    else
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 170, 200, 220))
        nvgText(vg, x + w / 2, detailY + detailH / 2, "点击上方投资项查看详情并可取消")
    end
end

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function InvestmentOverviewPanel.drawBottomBar(vg, x, y, w, h)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 110, 160, 120))
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 255))
    nvgText(vg, x + 15, y + 18, "➕ 新建投资")

    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
    nvgText(vg, x + 15, y + 38, "类型:")
    nvgText(vg, x + 220, y + 38, "目标星球:")

    local typeBtnY = y + 44
    local typeBtnW = 150
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x + 15, typeBtnY, typeBtnW, 24, 4)
    nvgFillColor(vg, nvgRGBA(50, 80, 130, 230))
    nvgFill(vg)
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
    local curOpt = INVESTMENT_OPTIONS[panel.newInvestmentTypeIndex] or INVESTMENT_OPTIONS[1]
    nvgText(vg, x + 15 + typeBtnW / 2, typeBtnY + 12, "T" .. tostring(curOpt.tier) .. " " .. (curOpt.name or ""))
    addHit(x + 15, typeBtnY, typeBtnW, 24, function()
        panel.newInvestmentTypeIndex = (panel.newInvestmentTypeIndex % #INVESTMENT_OPTIONS) + 1
    end)

    local planetBtnY = y + 44
    local planetBtnW = 150
    local planets = InvestmentOverviewPanel.getPlanets()
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x + 220, planetBtnY, planetBtnW, 24, 4)
    nvgFillColor(vg, nvgRGBA(50, 80, 130, 230))
    nvgFill(vg)
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
    local curPlanet = planets[panel.newInvestmentPlanetIndex] or planets[1]
    nvgText(vg, x + 220 + planetBtnW / 2, planetBtnY + 12, curPlanet.name or "")
    addHit(x + 220, planetBtnY, planetBtnW, 24, function()
        panel.newInvestmentPlanetIndex = (panel.newInvestmentPlanetIndex % math.max(1, #planets)) + 1
    end)

    local costX = x + 390
    local costY = y + 38
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
    nvgText(vg, costX, costY, "所需资源:")
    local costStr = ""
    if curOpt and curOpt.cost then
        local j = 1
        for k, v in pairs(curOpt.cost) do
            if j > 3 then break end
            costStr = costStr .. (RESOURCE_NAMES[k] or k) .. " x" .. tostring(v) .. "  "
            j = j + 1
        end
    end
    nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
    nvgText(vg, costX, costY + 20, costStr ~= "" and costStr or "(无)")

    local addBtnY = y + 44
    local addBtnW = 120
    local addBtnX = x + w - addBtnW - 15
    nvgBeginPath(vg)
    nvgRoundedRect(vg, addBtnX, addBtnY, addBtnW, 24, 4)
    nvgFillColor(vg, nvgRGBA(80, 140, 90, 230))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(240, 255, 230, 255))
    nvgText(vg, addBtnX + addBtnW / 2, addBtnY + 12, "✔ 启动投资")
    addHit(addBtnX, addBtnY, addBtnW, 24, function()
        local targetPlanetId = (planets[panel.newInvestmentPlanetIndex] or {}).id or panel.selectedPlanet
        local opt = INVESTMENT_OPTIONS[panel.newInvestmentTypeIndex]
        if not opt then return end
        if not playerStateRef then playerStateRef = {} end
        playerStateRef.planetInvestments = playerStateRef.planetInvestments or {}
        playerStateRef.planetInvestments[targetPlanetId] = playerStateRef.planetInvestments[targetPlanetId] or {}
        local now = os.time()
        table.insert(playerStateRef.planetInvestments[targetPlanetId], {
            id = opt.id,
            name = opt.name,
            startTime = now,
            endTime = now + opt.duration,
            duration = opt.duration,
            effects = opt.effect,
            cost = opt.cost,
        })
        panel.selectedPlanet = targetPlanetId
        panel.selectedInvestmentIndex = 0
    end)
end

---@param seconds number
---@return string
function InvestmentOverviewPanel.formatDuration(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    if seconds >= 3600 then
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        return string.format("%dh%02dm", h, m)
    end
    if seconds >= 60 then
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%dm%02ds", m, s)
    end
    return tostring(math.floor(seconds)) .. "s"
end

return InvestmentOverviewPanel
