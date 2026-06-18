---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/ui/SeasonShopPanel.lua -- 赛季商店面板
-- V2.8 P0-4 UI
-- ============================================================================

local SeasonShopPanel = {}

local panel = nil

-- ============================================================================
-- 面板打开/关闭
-- ============================================================================

function SeasonShopPanel.open()
    local SS = require("game.systems.SeasonSystem")

    panel = {
        visible = true,
        tab = "REWARDS",
        w = 500,
        h = 450,
    }

    return panel
end

function SeasonShopPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

-- ============================================================================
-- 面板绘制
-- ============================================================================

function SeasonShopPanel.draw(vg)
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
    nvgStrokeColor(vg, nvgRGBA(100, 140, 200, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题栏
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 50, 12)
    nvgRect(vg, px, py + 25, pw, 25)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 240))
    nvgFill(vg)

    -- 赛季信息
    local SS = require("game.systems.SeasonSystem")
    local seasonState = SS.getSeasonState()

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 25, seasonState.seasonName or "赛季商店")

    -- 积分显示
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, cx, py + 42, "赛季积分: " .. seasonState.playerPoints)

    -- 关闭按钮
    local closeBtn = { x = px + pw - 35, y = py + 12, w = 22, h = 22 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        SeasonShopPanel.close()
    end)

    -- 标签页
    local tabs = { { id = "REWARDS", name = "积分奖励" }, { id = "TASKS", name = "赛季任务" }, { id = "EXCLUSIVE", name = "限定物品" } }
    local tabY = py + 60
    local tabW = 90
    local totalTabW = #tabs * (tabW + 5) - 5
    local tabStartX = cx - totalTabW / 2

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

    -- 内容
    local contentY = py + 100
    local contentH = ph - 115

    if panel.tab == "REWARDS" then
        SeasonShopPanel.drawRewards(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "TASKS" then
        SeasonShopPanel.drawTasks(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "EXCLUSIVE" then
        SeasonShopPanel.drawExclusive(vg, px + 15, contentY, pw - 30, contentH)
    end
end

-- ============================================================================
-- 积分奖励
-- ============================================================================

function SeasonShopPanel.drawRewards(vg, x, y, w, h)
    local SS = require("game.systems.SeasonSystem")
    local seasonState = SS.getSeasonState()
    local claimedMilestones = SS.getClaimedMilestones()
    local currentPoints = seasonState.playerPoints

    local rowH = 50

    for i, milestone in ipairs(SEASON_POINT_REWARDS) do
        local rowY = y + (i - 1) * (rowH + 5)
        if rowY + rowH > y + h then break end

        local isUnlocked = currentPoints >= milestone.points
        local isClaimed = claimedMilestones[milestone.points]
        local canClaim = isUnlocked and not isClaimed

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, rowY, w, rowH, 6)
        if isClaimed then
            nvgFillColor(vg, nvgRGBA(30, 60, 40, 200))
            nvgStrokeColor(vg, nvgRGBA(100, 200, 100, 150))
        elseif isUnlocked then
            nvgFillColor(vg, nvgRGBA(40, 60, 80, 200))
            nvgStrokeColor(vg, nvgRGBA(100, 150, 220, 150))
        else
            nvgFillColor(vg, nvgRGBA(30, 35, 50, 180))
            nvgStrokeColor(vg, nvgRGBA(60, 70, 100, 100))
        end
        nvgFill(vg)
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 进度指示
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)

        if isClaimed then
            nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
            nvgText(vg, x + 15, rowY + 18, "✓ " .. milestone.points .. " 积分")
        else
            nvgFillColor(vg, isUnlocked and nvgRGBA(100, 200, 255, 255) or nvgRGBA(150, 150, 180, 255))
            nvgText(vg, x + 15, rowY + 18, milestone.points .. " 积分")
        end

        -- 奖励内容
        nvgFontSize(vg, 11)
        local rewardText = SeasonShopPanel.formatReward(milestone.reward)
        nvgFillColor(vg, isUnlocked and nvgRGBA(200, 200, 220, 255) or nvgRGBA(130, 130, 150, 255))
        nvgText(vg, x + 100, rowY + 18, rewardText)

        -- 领取按钮
        if canClaim then
            local btnX, btnY = x + w - 70, rowY + rowH / 2 - 12
            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX, btnY, 60, 24, 4)
            nvgFillColor(vg, nvgRGBA(80, 180, 80, 220))
            nvgFill(vg)
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, btnX + 30, btnY + 12, "领取")
            addHit(btnX, btnY, 60, 24, function()
                SeasonShopPanel.claimReward(milestone)
            end)
        elseif isClaimed then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.RIGHT)
            nvgFillColor(vg, nvgRGBA(100, 255, 100, 200))
            nvgText(vg, x + w - 15, rowY + rowH / 2, "已领取")
        end
    end
end

function SeasonShopPanel.formatReward(reward)
    if not reward then return "" end
    local parts = {}
    if reward.blueCrystal then table.insert(parts, "蓝晶×" .. reward.blueCrystal) end
    if reward.purpleCrystal then table.insert(parts, "紫晶×" .. reward.purpleCrystal) end
    if reward.rainbowCrystal then table.insert(parts, "虹晶×" .. reward.rainbowCrystal) end
    if reward.credits then table.insert(parts, "星币×" .. reward.credits) end
    if reward.skin then table.insert(parts, reward.skin) end
    if reward.frame then table.insert(parts, reward.frame) end
    if reward.title then table.insert(parts, reward.title) end
    return table.concat(parts, ", ")
end

function SeasonShopPanel.claimReward(milestone)
    local SS = require("game.systems.SeasonSystem")

    -- 发放奖励
    local reward = milestone.reward
    if reward then
        if reward.blueCrystal then
            local RM = require("game.systems.ResourceManager")
            if RM and RM.addRare then RM:addRare("blueCrystal", reward.blueCrystal) end
        end
        if reward.purpleCrystal then
            local RM = require("game.systems.ResourceManager")
            if RM and RM.addRare then RM:addRare("purpleCrystal", reward.purpleCrystal) end
        end
        if reward.rainbowCrystal then
            local RM = require("game.systems.ResourceManager")
            if RM and RM.addRare then RM:addRare("rainbowCrystal", reward.rainbowCrystal) end
        end
        if reward.credits and playerState then
            playerState.credits = (playerState.credits or 0) + reward.credits
        end
    end

    if NotifyPanel then
        NotifyPanel.push({
            type = "SUCCESS",
            title = "奖励领取",
            message = "获得: " .. SeasonShopPanel.formatReward(reward),
        })
    end
end

-- ============================================================================
-- 赛季任务
-- ============================================================================

function SeasonShopPanel.drawTasks(vg, x, y, w, h)
    local SS = require("game.systems.SeasonSystem")

    -- 分类筛选
    local categories = { "ALL", "BATTLE", "PROGRESS", "WEEKLY" }
    local filterW = 70
    local filterY = y

    for i, cat in ipairs(categories) do
        local fx = x + (i - 1) * (filterW + 5)
        local selected = (panel.taskFilter or "ALL") == cat

        nvgBeginPath(vg)
        nvgRoundedRect(vg, fx, filterY, filterW, 24, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(35, 45, 65, 200))
        nvgFill(vg)

        local catName = cat == "ALL" and "全部" or cat == "BATTLE" and "战斗"
                    or cat == "PROGRESS" and "进度" or cat == "WEEKLY" and "周任务"
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, fx + filterW / 2, filterY + 12, catName)

        addHit(fx, filterY, filterW, 24, function()
            panel.taskFilter = cat
        end)
    end

    -- 任务列表
    local tasks = SS.getTasks(panel.taskFilter or "ALL")
    local taskY = y + 35
    local taskH = 55

    for i, task in ipairs(tasks) do
        local rowY = taskY + (i - 1) * (taskH + 3)
        if rowY + taskH > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, rowY, w, taskH, 5)
        if task.completed then
            nvgFillColor(vg, nvgRGBA(30, 60, 40, 200))
        else
            nvgFillColor(vg, nvgRGBA(30, 40, 60, 180))
        end
        nvgFill(vg)

        -- 任务描述
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, task.completed and nvgRGBA(100, 255, 100, 255) or nvgRGBA(220, 220, 240, 255))
        nvgText(vg, x + 15, rowY + 18, task.desc)

        -- 进度条
        local progress = task.target > 0 and task.progress / task.target or 0
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 15, rowY + 30, w - 30, 10, 3)
        nvgFillColor(vg, nvgRGBA(40, 50, 70, 200))
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 15, rowY + 30, (w - 30) * math.min(1, progress), 10, 3)
        nvgFillColor(vg, task.completed and nvgRGBA(80, 200, 80, 220) or nvgRGBA(80, 140, 220, 220))
        nvgFill(vg)

        -- 进度文字
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 20, rowY + 38, task.progress .. "/" .. task.target)

        -- 奖励
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        nvgText(vg, x + w - 15, rowY + 40, "+" .. task.reward.points .. "积分")
    end
end

-- ============================================================================
-- 限定物品
-- ============================================================================

function SeasonShopPanel.drawExclusive(vg, x, y, w, h)
    local SS = require("game.systems.SeasonSystem")
    local season = SS.getCurrentSeason()

    if not season or not season.exclusiveRewards then
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + w / 2, y + h / 2, "暂无限定物品")
        return
    end

    local rowH = 60

    for i, reward in ipairs(season.exclusiveRewards) do
        local rowY = y + (i - 1) * (rowH + 8)
        if rowY + rowH > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, rowY, w, rowH, 6)
        nvgFillColor(vg, nvgRGBA(35, 45, 70, 200))
        nvgFill(vg)

        -- 稀有度边框
        local borderColor = reward.rarity == "LEGENDARY" and nvgRGBA(255, 200, 50, 200)
                       or reward.rarity == "EPIC" and nvgRGBA(180, 100, 200, 200)
                       or nvgRGBA(100, 150, 220, 150)
        nvgStrokeColor(vg, borderColor)
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

        -- 物品名称
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, borderColor)
        nvgText(vg, x + 15, rowY + 22, reward.name)

        -- 稀有度
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 15, rowY + 42, reward.rarity)

        -- 类型
        nvgText(vg, x + 100, rowY + 42, reward.type)

        -- 赛季标记
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(200, 180, 100, 200))
        nvgText(vg, x + w - 15, rowY + rowH / 2, season.shortName)
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return SeasonShopPanel
