---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/CareerStatsPanel.lua -- 生涯战绩面板
-- V1.6 P2-1
-- ============================================================================

local CareerStatsPanel = {}

local panel = nil

function CareerStatsPanel.open()
    panel = {
        visible = true,
        tab = "OVERVIEW",
        w = 500,
        h = 420,
    }
    return panel
end

function CareerStatsPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

function CareerStatsPanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or 800) / 2, (BS and BS.screenH or 600) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2

    -- 背景
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
    nvgText(vg, cx, py + 30, "生涯战绩")

    -- 关闭
    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        CareerStatsPanel.close()
    end)

    -- 标签
    local tabs = { { id = "OVERVIEW", name = "总览" }, { id = "BATTLE", name = "战斗" }, { id = "ECONOMY", name = "经济" }, { id = "RECORDS", name = "记录" } }
    local tabY = py + 55
    local tabW = 70
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

        addHit(tx, tabY, tabW, 26, function()
            panel.tab = tab.id
        end)
    end

    local contentY = py + 95
    local contentH = ph - 110

    if panel.tab == "OVERVIEW" then
        CareerStatsPanel.drawOverview(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "BATTLE" then
        CareerStatsPanel.drawBattle(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "ECONOMY" then
        CareerStatsPanel.drawEconomy(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "RECORDS" then
        CareerStatsPanel.drawRecords(vg, px + 15, contentY, pw - 30, contentH)
    end
end

-- 总览
function CareerStatsPanel.drawOverview(vg, x, y, w, h)
    local stats = playerState and playerState.careerStats or CareerStatsPanel.getDefaultStats()

    nvgFontFace(vg, "sans")

    -- 总战斗次数
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 20, "总战斗次数:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
    nvgText(vg, x + w, y + 20, tostring(stats.totalBattles or 0))

    -- 胜率
    local winRate = stats.totalBattles > 0 and (stats.victories / stats.totalBattles * 100) or 0
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 45, "胜率:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, winRate >= 50 and nvgRGBA(100, 255, 100, 255) or nvgRGBA(255, 100, 100, 255))
    nvgText(vg, x + w, y + 45, string.format("%.1f%%", winRate))

    -- 最高波次
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 70, "最高波次:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(255, 200, 100, 255))
    nvgText(vg, x + w, y + 70, tostring(stats.highestWave or 0))

    -- Boss击杀
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 95, "Boss击杀:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(200, 150, 255, 255))
    nvgText(vg, x + w, y + 95, tostring(stats.bossKills or 0))

    -- 总击杀
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 120, "总击杀敌舰:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + w, y + 120, tostring(stats.totalKills or 0))

    -- 总星币收入
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 145, "总星币收入:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, x + w, y + 145, tostring(stats.totalCreditsEarned or 0))

    -- 游戏时长
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 170, "游戏时长:")
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
    local hours = math.floor((stats.playTime or 0) / 3600)
    local mins = math.floor((stats.playTime or 0) % 3600 / 60)
    nvgText(vg, x + w, y + 170, string.format("%d小时%d分钟", hours, mins))
end

-- 战斗统计
function CareerStatsPanel.drawBattle(vg, x, y, w, h)
    local stats = playerState and playerState.careerStats or CareerStatsPanel.getDefaultStats()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)

    local rowY = y
    local rowH = 28

    local battleStats = {
        { label = "总战斗次数", value = stats.totalBattles or 0 },
        { label = "胜利次数", value = stats.victories or 0 },
        { label = "失败次数", value = stats.defeats or 0 },
        { label = "最高波次", value = stats.highestWave or 0 },
        { label = "Boss击杀", value = stats.bossKills or 0 },
        { label = "超级Boss击杀", value = stats.superBossKills or 0 },
        { label = "总击杀敌舰", value = stats.totalKills or 0 },
        { label = "舰船损失", value = stats.shipsLost or 0 },
        { label = "战役关卡完成", value = stats.campaignStages or 0 },
    }

    for i, stat in ipairs(battleStats) do
        local ry = rowY + (i - 1) * rowH
        if ry + rowH > y + h then break end

        nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
        nvgText(vg, x, ry + 15, stat.label)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + w, ry + 15, tostring(stat.value))
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
    end
end

-- 经济统计
function CareerStatsPanel.drawEconomy(vg, x, y, w, h)
    local stats = playerState and playerState.careerStats or CareerStatsPanel.getDefaultStats()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)

    local rowY = y
    local rowH = 28

    local economyStats = {
        { label = "总星币收入", value = stats.totalCreditsEarned or 0 },
        { label = "总星币支出", value = stats.totalCreditsSpent or 0 },
        { label = "总金属采集", value = stats.totalMetalCollected or 0 },
        { label = "总晶体采集", value = stats.totalCrystalCollected or 0 },
        { label = "舰船建造数量", value = stats.shipsBuilt or 0 },
        { label = "建筑建造数量", value = stats.buildingsBuilt or 0 },
        { label = "科技研究数量", value = stats.techsResearched or 0 },
        { label = "交易次数", value = stats.tradesCompleted or 0 },
    }

    for i, stat in ipairs(economyStats) do
        local ry = rowY + (i - 1) * rowH
        if ry + rowH > y + h then break end

        nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
        nvgText(vg, x, ry + 15, stat.label)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        nvgText(vg, x + w, ry + 15, tostring(stat.value))
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
    end
end

-- 记录
function CareerStatsPanel.drawRecords(vg, x, y, w, h)
    local stats = playerState and playerState.careerStats or CareerStatsPanel.getDefaultStats()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, x, y + 15, "🏆 个人记录")

    nvgFontSize(vg, 12)
    local records = {
        { label = "最快波次20", value = stats.fastestWave20 or "N/A", unit = "秒" },
        { label = "最快波次50", value = stats.fastestWave50 or "N/A", unit = "秒" },
        { label = "单场最高击杀", value = stats.highestKillsInBattle or 0, unit = "" },
        { label = "单场最高收入", value = stats.highestCreditsInBattle or 0, unit = "星币" },
        { label = "最长存活时间", value = stats.longestSurvivalTime or 0, unit = "秒" },
        { label = "最大舰队规模", value = stats.largestFleetSize or 0, unit = "艘" },
    }

    local recordY = y + 40
    for i, record in ipairs(records) do
        local ry = recordY + (i - 1) * 25
        if ry + 25 > y + h then break end

        nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
        nvgText(vg, x, ry + 12, record.label)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 255))
        local valueText = record.value == "N/A" and "N/A" or tostring(record.value) .. record.unit
        nvgText(vg, x + w, ry + 12, valueText)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
    end
end

-- 默认统计数据
function CareerStatsPanel.getDefaultStats()
    return {
        totalBattles = 0,
        victories = 0,
        defeats = 0,
        highestWave = 0,
        bossKills = 0,
        superBossKills = 0,
        totalKills = 0,
        shipsLost = 0,
        campaignStages = 0,
        totalCreditsEarned = 0,
        totalCreditsSpent = 0,
        totalMetalCollected = 0,
        totalCrystalCollected = 0,
        shipsBuilt = 0,
        buildingsBuilt = 0,
        techsResearched = 0,
        tradesCompleted = 0,
        playTime = 0,
        fastestWave20 = "N/A",
        fastestWave50 = "N/A",
        highestKillsInBattle = 0,
        highestCreditsInBattle = 0,
        longestSurvivalTime = 0,
        largestFleetSize = 0,
    }
end

-- 更新统计数据（供其他系统调用）
function CareerStatsPanel.updateStats(statName, value)
    if not playerState then return end
    playerState.careerStats = playerState.careerStats or CareerStatsPanel.getDefaultStats()
    playerState.careerStats[statName] = value
end

function CareerStatsPanel.addStats(statName, increment)
    if not playerState then return end
    playerState.careerStats = playerState.careerStats or CareerStatsPanel.getDefaultStats()
    playerState.careerStats[statName] = (playerState.careerStats[statName] or 0) + increment
end

return CareerStatsPanel