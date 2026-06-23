---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/BattleStatsPanel.lua -- 战斗统计报告面板
-- V3.3 M2
-- ============================================================================

local BattleStatsPanel = {}

local panel = nil
local playerStateRef = nil
local cachedSummary = nil

---打开战斗统计面板
---@param playerState table 玩家状态引用
---@param battleSummary table|nil 战斗汇总数据（nil 则从系统取）
---@return table
function BattleStatsPanel.open(playerState, battleSummary)
    playerStateRef = playerState
    cachedSummary = battleSummary or BattleStatsPanel.fetchBattleSummary()
    panel = {
        visible = true,
        w = 640,
        h = 500,
        tab = "OVERVIEW",
    }
    return panel
end

---关闭面板
function BattleStatsPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

---面板是否打开
---@return boolean
function BattleStatsPanel.isOpen()
    return panel ~= nil and panel.visible == true
end

---主渲染入口
function BattleStatsPanel.render()
    local vg = _G.BS and _G.BS.vg or nil
    if not vg then return end
    BattleStatsPanel.draw(vg)
end

---获取六维度雷达图数据（攻击/防御/生存/支援/机动/协同）
---@return table
function BattleStatsPanel.getRadarData()
    local s = cachedSummary or BattleStatsPanel.fetchBattleSummary()
    local maxRef = {
        attack = 10000,
        defense = 5000,
        survival = 300,
        support = 2000,
        mobility = 120,
        synergy = 100,
    }
    local raw = {
        attack   = s.damageDealt       or 0,
        defense  = s.damageBlocked     or 0,
        survival = s.survivalTime      or 0,
        support  = s.supportValue      or 0,
        mobility = s.maneuverCount     or 0,
        synergy  = s.synergyBonus      or 0,
    }
    local norm = {}
    for k, v in pairs(raw) do
        norm[k] = math.max(0, math.min(1, v / (maxRef[k] or 1)))
    end
    return {
        labels = { "攻击", "防御", "生存", "支援", "机动", "协同" },
        keys   = { "attack", "defense", "survival", "support", "mobility", "synergy" },
        raw    = raw,
        normalized = norm,
    }
end

---按舰种统计伤害分布
---@return table
function BattleStatsPanel.getDamageDistribution()
    local s = cachedSummary or BattleStatsPanel.fetchBattleSummary()
    if s.damageByShipClass and type(s.damageByShipClass) == "table" and next(s.damageByShipClass) ~= nil then
        local total = 0
        for _, v in pairs(s.damageByShipClass) do total = total + v end
        local list = {}
        for k, v in pairs(s.damageByShipClass) do
            list[#list + 1] = { class = k, damage = v, ratio = total > 0 and v / total or 0 }
        end
        table.sort(list, function(a, b) return a.damage > b.damage end)
        return list
    end
    return BattleStatsPanel.getMockDamageDistribution()
end

---分段时间轴统计（前30秒/中期/尾声）
---@return table
function BattleStatsPanel.getTimelineStats()
    local s = cachedSummary or BattleStatsPanel.fetchBattleSummary()
    if s.timeline and type(s.timeline) == "table" and #s.timeline >= 3 then
        return {
            { phase = "前30秒",  label = "开场",   damage = s.timeline[1].damage or 0, kills = s.timeline[1].kills or 0, color = nvgRGBA(100, 180, 255, 255) },
            { phase = "中期",    label = "交战",   damage = s.timeline[2].damage or 0, kills = s.timeline[2].kills or 0, color = nvgRGBA(255, 200, 100, 255) },
            { phase = "尾声",    label = "收尾",   damage = s.timeline[3].damage or 0, kills = s.timeline[3].kills or 0, color = nvgRGBA(230, 100, 140, 255) },
        }
    end
    local totalD = s.damageDealt or 3200
    local totalK = s.kills or 8
    return {
        { phase = "前30秒", label = "开场", damage = math.floor(totalD * 0.2), kills = math.floor(totalK * 0.2), color = nvgRGBA(100, 180, 255, 255) },
        { phase = "中期",   label = "交战", damage = math.floor(totalD * 0.55), kills = math.floor(totalK * 0.55), color = nvgRGBA(255, 200, 100, 255) },
        { phase = "尾声",   label = "收尾", damage = math.floor(totalD * 0.25), kills = math.floor(totalK * 0.25), color = nvgRGBA(230, 100, 140, 255) },
    }
end

---MVP 舰船信息
---@return table
function BattleStatsPanel.getMVP()
    local s = cachedSummary or BattleStatsPanel.fetchBattleSummary()
    if s.mvp and type(s.mvp) == "table" then
        return s.mvp
    end
    return BattleStatsPanel.getMockMVP()
end

---文字版摘要
---@return string
function BattleStatsPanel.getSummaryText()
    local s = cachedSummary or BattleStatsPanel.fetchBattleSummary()
    local result = (s.result == "VICTORY" or s.result == "WIN") and "胜利" or "失败"
    local lines = {}
    lines[#lines + 1] = string.format("战斗结果: %s", result)
    lines[#lines + 1] = string.format("战斗时长: %s", BattleStatsPanel.formatTime(s.duration or 0))
    lines[#lines + 1] = string.format("总伤害: %d", s.damageDealt or 0)
    lines[#lines + 1] = string.format("承伤: %d", s.damageTaken or 0)
    lines[#lines + 1] = string.format("击杀: %d", s.kills or 0)
    lines[#lines + 1] = string.format("损失: %d", s.losses or 0)
    lines[#lines + 1] = string.format("命中率: %.1f%%", (s.hitRate or 0.72) * 100)
    lines[#lines + 1] = string.format("暴击率: %.1f%%", (s.critRate or 0.18) * 100)
    return table.concat(lines, "\n")
end

-- ============================================================================
-- 内部辅助
-- ============================================================================

function BattleStatsPanel.fetchBattleSummary()
    local ok, BST = pcall(require, "game.systems.BattleStatsTracker")
    if ok and BST and BST.getLastBattleSummary then
        local data = BST.getLastBattleSummary()
        if data then return data end
    end
    return BattleStatsPanel.getMockSummary()
end

function BattleStatsPanel.getMockSummary()
    return {
        result = "VICTORY",
        duration = 146,
        damageDealt = 8420,
        damageTaken = 3120,
        damageBlocked = 1680,
        kills = 12,
        losses = 2,
        hitRate = 0.78,
        critRate = 0.22,
        survivalTime = 142,
        supportValue = 1240,
        maneuverCount = 96,
        synergyBonus = 72,
    }
end

function BattleStatsPanel.getMockDamageDistribution()
    return {
        { class = "战列舰", damage = 3240, ratio = 0.385 },
        { class = "巡洋舰", damage = 2180, ratio = 0.259 },
        { class = "驱逐舰", damage = 1560, ratio = 0.185 },
        { class = "护卫舰", damage =  840, ratio = 0.100 },
        { class = "航母",   damage =  600, ratio = 0.071 },
    }
end

function BattleStatsPanel.getMockMVP()
    return {
        name = "战列舰·烈焰",
        shipClass = "战列舰",
        damage = 3240,
        kills = 5,
        survivalSeconds = 146,
        score = 9640,
    }
end

function BattleStatsPanel.formatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

-- ============================================================================
-- 绘制主流程
-- ============================================================================

---@param vg userdata
function BattleStatsPanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or 800) / 2, (BS and BS.screenH or 600) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 245))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 200, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题栏
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 45, 12)
    nvgRect(vg, px, py + 20, pw, 25)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 240))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "战斗统计报告")

    -- 关闭按钮
    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        BattleStatsPanel.close()
    end)

    -- Tab 切换
    local tabs = {
        { id = "OVERVIEW", name = "概览" },
        { id = "RADAR",    name = "雷达图" },
        { id = "DAMAGE",   name = "伤害分布" },
        { id = "TIMELINE", name = "时间轴" },
        { id = "MVP",      name = "MVP" },
    }
    local tabY = py + 55
    local tabW = 90
    local tabStartX = px + 15

    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * (tabW + 5)
        local selected = panel.tab == tab.id

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW, 26, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(35, 45, 65, 200))
        nvgFill(vg)

        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, tx + tabW / 2, tabY + 13, tab.name)

        addHit(tx, tabY, tabW, 26, function() panel.tab = tab.id end)
    end

    local contentY = py + 95
    local contentH = ph - 110

    -- 内容分区
    if panel.tab == "OVERVIEW" then
        BattleStatsPanel.drawOverview(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "RADAR" then
        BattleStatsPanel.drawRadar(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "DAMAGE" then
        BattleStatsPanel.drawDamageBar(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "TIMELINE" then
        BattleStatsPanel.drawTimeline(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "MVP" then
        BattleStatsPanel.drawMVP(vg, px + 15, contentY, pw - 30, contentH)
    end
end

---绘制概览（伤害/承伤/击杀/命中率等数字）
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleStatsPanel.drawOverview(vg, x, y, w, h)
    local s = cachedSummary or BattleStatsPanel.fetchBattleSummary()

    -- 顶部战斗结果大标签
    local isWin = (s.result == "VICTORY" or s.result == "WIN")
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, 50, 6)
    nvgFillColor(vg, isWin and nvgRGBA(60, 140, 80, 200) or nvgRGBA(180, 60, 80, 200))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + 20, y + 25, isWin and "🏆 战斗胜利" or "💀 战斗失败")

    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 230, 250, 255))
    nvgText(vg, x + w - 20, y + 25, "时长 " .. BattleStatsPanel.formatTime(s.duration or 0))

    -- 数字卡片网格（2行 x 4列）
    local cards = {
        { label = "总伤害",    value = string.format("%d", s.damageDealt or 0),   color = nvgRGBA(255, 140, 100, 255) },
        { label = "承伤",      value = string.format("%d", s.damageTaken or 0),   color = nvgRGBA(255, 100, 130, 255) },
        { label = "格挡",      value = string.format("%d", s.damageBlocked or 0), color = nvgRGBA(120, 200, 255, 255) },
        { label = "击杀",      value = string.format("%d", s.kills or 0),          color = nvgRGBA(255, 220, 100, 255) },
        { label = "损失",      value = string.format("%d", s.losses or 0),         color = nvgRGBA(200, 140, 255, 255) },
        { label = "命中率",    value = string.format("%.1f%%", (s.hitRate or 0) * 100),  color = nvgRGBA(120, 255, 180, 255) },
        { label = "暴击率",    value = string.format("%.1f%%", (s.critRate or 0) * 100), color = nvgRGBA(255, 180, 80, 255) },
        { label = "存活时间",  value = BattleStatsPanel.formatTime(s.survivalTime or 0), color = nvgRGBA(160, 240, 200, 255) },
    }

    local gridY = y + 60
    local cols = 4
    local rows = 2
    local cGap = 8
    local cardW = (w - cGap * (cols - 1)) / cols
    local cardH = (h - 70 - cGap) / rows

    for i, c in ipairs(cards) do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        local cx = x + col * (cardW + cGap)
        local cy = gridY + row * (cardH + cGap)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, cardW, cardH, 6)
        nvgFillColor(vg, nvgRGBA(25, 35, 55, 220))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(70, 100, 150, 120))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(160, 180, 210, 255))
        nvgText(vg, cx + cardW / 2, cy + 18, c.label)

        nvgFontSize(vg, 18)
        nvgFillColor(vg, c.color)
        nvgText(vg, cx + cardW / 2, cy + cardH / 2 + 8, c.value)
    end
end

---绘制六维雷达图
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleStatsPanel.drawRadar(vg, x, y, w, h)
    local data = BattleStatsPanel.getRadarData()

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, x, y + 16, "六维能力雷达图")

    -- 雷达图区域（左侧），右侧显示数值
    local radarSize = math.min(h - 30, w * 0.55)
    local cx = x + radarSize / 2 + 10
    local cy = y + radarSize / 2 + 30
    local radius = radarSize / 2 - 20

    -- 五圈网格
    for ring = 1, 5 do
        local r = radius * ring / 5
        nvgBeginPath(vg)
        for i = 1, #data.keys do
            local angle = -math.pi / 2 + (i - 1) * (math.pi * 2 / #data.keys)
            local px = cx + math.cos(angle) * r
            local py = cy + math.sin(angle) * r
            if i == 1 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
        end
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(25, 40, 70, ring == 5 and 80 or 20))
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 100))
        nvgStrokeWidth(vg, 1)
        if ring == 5 then nvgFill(vg) end
        nvgStroke(vg)
    end

    -- 放射线 + 标签
    for i, key in ipairs(data.keys) do
        local angle = -math.pi / 2 + (i - 1) * (math.pi * 2 / #data.keys)
        local ex = cx + math.cos(angle) * radius
        local ey = cy + math.sin(angle) * radius

        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy)
        nvgLineTo(vg, ex, ey)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 80))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        local labelR = radius + 18
        local lx = cx + math.cos(angle) * labelR
        local ly = cy + math.sin(angle) * labelR
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, 255))
        nvgText(vg, lx, ly, data.labels[i])
    end

    -- 数据多边形
    nvgBeginPath(vg)
    for i, key in ipairs(data.keys) do
        local angle = -math.pi / 2 + (i - 1) * (math.pi * 2 / #data.keys)
        local val = data.normalized[key] or 0
        local r = radius * val
        local px = cx + math.cos(angle) * r
        local py = cy + math.sin(angle) * r
        if i == 1 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 120))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 200, 255, 240))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 数据点
    for i, key in ipairs(data.keys) do
        local angle = -math.pi / 2 + (i - 1) * (math.pi * 2 / #data.keys)
        local val = data.normalized[key] or 0
        local r = radius * val
        local px = cx + math.cos(angle) * r
        local py = cy + math.sin(angle) * r
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, 3)
        nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
        nvgFill(vg)
    end

    -- 右侧数值表
    local tableX = x + radarSize + 40
    local tableY = y + 30
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, tableX, tableY, "数值明细")

    for i, key in ipairs(data.keys) do
        local ry = tableY + 24 + (i - 1) * 24
        local raw = data.raw[key] or 0
        local pct = math.floor((data.normalized[key] or 0) * 100)

        -- 背景条
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tableX, ry, 170, 18, 4)
        nvgFillColor(vg, nvgRGBA(30, 40, 65, 220))
        nvgFill(vg)

        -- 进度条
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tableX, ry, 170 * pct / 100, 18, 4)
        nvgFillColor(vg, nvgRGBA(100, 180, 255, 200))
        nvgFill(vg)

        -- 标签
        nvgFillColor(vg, nvgRGBA(230, 240, 255, 255))
        nvgFontSize(vg, 10)
        nvgText(vg, tableX + 6, ry + 13, data.labels[i])

        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 230, 150, 255))
        nvgText(vg, tableX + 164, ry + 13, tostring(math.floor(raw)))
    end
end

---绘制舰种伤害柱状图
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleStatsPanel.drawDamageBar(vg, x, y, w, h)
    local dist = BattleStatsPanel.getDamageDistribution()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, x, y + 16, "按舰种伤害分布")

    local total = 0
    for _, d in ipairs(dist) do total = total + d.damage end
    local barAreaX = x
    local barAreaY = y + 35
    local barAreaH = h - 50
    local barW = math.min(60, (w - 40 * #dist) / #dist)
    local gap = 40

    local maxVal = 0
    for _, d in ipairs(dist) do if d.damage > maxVal then maxVal = d.damage end end

    local classColors = {
        ["战列舰"] = nvgRGBA(255, 120, 100, 240),
        ["巡洋舰"] = nvgRGBA(255, 180, 100, 240),
        ["驱逐舰"] = nvgRGBA(140, 220, 160, 240),
        ["护卫舰"] = nvgRGBA(140, 200, 255, 240),
        ["航母"]   = nvgRGBA(200, 140, 255, 240),
    }

    local totalW = #dist * barW + (#dist - 1) * gap
    local startX = barAreaX + (w - totalW) / 2

    for i, d in ipairs(dist) do
        local bx = startX + (i - 1) * (barW + gap)
        local ratio = maxVal > 0 and d.damage / maxVal or 0
        local barH = math.floor(barAreaH * 0.85 * ratio)
        local by = barAreaY + barAreaH - barH

        local c = classColors[d.class] or nvgRGBA(150, 180, 220, 240)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, barW, barH, 4)
        nvgFillColor(vg, c)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 100))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 数值
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, bx + barW / 2, by - 4, tostring(d.damage))

        -- 百分比
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(200, 220, 240, 255))
        nvgText(vg, bx + barW / 2, by - 18, string.format("%.1f%%", d.ratio * 100))

        -- 标签（底部）
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(220, 230, 250, 255))
        nvgText(vg, bx + barW / 2, barAreaY + barAreaH + 16, d.class)
    end
end

---绘制时间轴分段统计
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleStatsPanel.drawTimeline(vg, x, y, w, h)
    local phases = BattleStatsPanel.getTimelineStats()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, x, y + 16, "战斗分段时间轴（伤害/击杀）")

    -- 上：伤害分段柱；下：击杀分段柱
    local chartY = y + 40
    local chartH = h - 60
    local dmgH = chartH / 2 - 10
    local killH = chartH / 2 - 10

    -- 伤害部分
    local maxDmg = 0
    for _, p in ipairs(phases) do if p.damage > maxDmg then maxDmg = p.damage end end
    local totalDmg = 0
    for _, p in ipairs(phases) do totalDmg = totalDmg + p.damage end

    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(255, 180, 120, 255))
    nvgText(vg, x, chartY - 4, "伤害输出")

    local phaseW = (w - 20 - 40 * #phases) / #phases
    local phaseGap = 40
    local startX = x + 10 + (phaseGap) / 2

    for i, p in ipairs(phases) do
        local bx = startX + (i - 1) * (phaseW + phaseGap)
        local ratio = maxDmg > 0 and p.damage / maxDmg or 0
        local bh = math.floor(dmgH * ratio)
        local by = chartY + dmgH - bh

        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, phaseW, bh, 3)
        nvgFillColor(vg, p.color)
        nvgFill(vg)

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, bx + phaseW / 2, by - 3, tostring(p.damage))

        nvgFillColor(vg, nvgRGBA(200, 220, 240, 220))
        nvgText(vg, bx + phaseW / 2, by - 14, string.format("%.0f%%", p.damage / (totalDmg > 0 and totalDmg or 1) * 100))
    end

    -- 击杀部分
    local killY = chartY + dmgH + 25
    local maxKill = 0
    for _, p in ipairs(phases) do if p.kills > maxKill then maxKill = p.kills end end
    local totalKill = 0
    for _, p in ipairs(phases) do totalKill = totalKill + p.kills end

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 120, 220, 255))
    nvgText(vg, x, killY - 4, "击杀数量")

    for i, p in ipairs(phases) do
        local bx = startX + (i - 1) * (phaseW + phaseGap)
        local ratio = maxKill > 0 and p.kills / maxKill or 0
        local bh = math.floor(killH * ratio)
        local by = killY + killH - bh

        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, phaseW, bh, 3)
        nvgFillColor(vg, nvgRGBA(200, 120, 220, 200))
        nvgFill(vg)

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, bx + phaseW / 2, by - 3, tostring(p.kills))
    end

    -- 阶段标签
    local labelY = killY + killH + 16
    for i, p in ipairs(phases) do
        local bx = startX + (i - 1) * (phaseW + phaseGap)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(230, 235, 250, 255))
        nvgText(vg, bx + phaseW / 2, labelY, p.label)
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(160, 180, 210, 255))
        nvgText(vg, bx + phaseW / 2, labelY + 14, p.phase)
    end
end

---绘制 MVP 舰船卡片
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
function BattleStatsPanel.drawMVP(vg, x, y, w, h)
    local mvp = BattleStatsPanel.getMVP()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, x, y + 16, "🏅 MVP 舰船")

    -- MVP 大卡片
    local cardX = x + 10
    local cardY = y + 30
    local cardW = w - 20
    local cardH = 120

    nvgBeginPath(vg)
    nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 8)
    nvgFillColor(vg, nvgRGBA(90, 70, 30, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 220, 120, 220))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 左侧 MVP 徽章
    nvgFontSize(vg, 42)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 140, 255))
    nvgText(vg, cardX + 50, cardY + cardH / 2, "MVP")

    -- 中部名称和类型
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(255, 245, 210, 255))
    nvgText(vg, cardX + 100, cardY + 32, mvp.name or "—")

    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(220, 220, 180, 255))
    nvgText(vg, cardX + 100, cardY + 52, "类型: " .. (mvp.shipClass or "—"))
    nvgText(vg, cardX + 100, cardY + 70, "存活: " .. BattleStatsPanel.formatTime(mvp.survivalSeconds or 0))

    -- 右侧得分和数据
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(220, 200, 150, 255))
    nvgText(vg, cardX + cardW - 20, cardY + 22, "综合得分")

    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(255, 230, 140, 255))
    nvgText(vg, cardX + cardW - 20, cardY + 52, tostring(mvp.score or 0))

    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(255, 180, 140, 255))
    nvgText(vg, cardX + cardW - 20, cardY + 78, "伤害 " .. tostring(mvp.damage or 0))
    nvgFillColor(vg, nvgRGBA(255, 140, 180, 255))
    nvgText(vg, cardX + cardW - 20, cardY + 96, "击杀 " .. tostring(mvp.kills or 0))

    -- 摘要文本
    local sumY = cardY + cardH + 20
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 210, 230, 255))
    nvgText(vg, x, sumY, "文字摘要")

    local linesY = sumY + 18
    local summary = BattleStatsPanel.getSummaryText()
    local i = 1
    for line in string.gmatch(summary, "([^\n]+)") do
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
        nvgText(vg, x + 10, linesY + (i - 1) * 20, line)
        i = i + 1
    end
end

return BattleStatsPanel
