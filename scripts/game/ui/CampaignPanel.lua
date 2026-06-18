---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/ui/CampaignPanel.lua -- 战役模式面板
-- V2.8 P0-1 UI
-- ============================================================================

local CampaignPanel = {}

local panel = nil
local selectedChapter = nil
local selectedStage = nil

-- ============================================================================
-- 面板打开/关闭
-- ============================================================================

function CampaignPanel.open()
    local CS = require("game.systems.CampaignSystem")

    panel = {
        visible = true,
        scrollY = 0,
        w = 600,
        h = 450,
        selectedChapter = nil,
        selectedStage = nil,
        tab = "CHAPTERS",  -- CHAPTERS | STAGES | STORY
    }

    return panel
end

function CampaignPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

-- ============================================================================
-- 面板绘制
-- ============================================================================

function CampaignPanel.draw(vg)
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

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "战役模式")

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
        CampaignPanel.close()
    end)

    -- 标签页
    local tabs = { { id = "CHAPTERS", name = "章节" }, { id = "STAGES", name = "关卡" }, { id = "STORY", name = "剧情" } }
    local tabY = py + 55
    local tabW = 80
    local tabStartX = px + 20

    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * (tabW + 5)
        local selected = panel.tab == tab.id

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW, 28, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(35, 45, 65, 200))
        nvgFill(vg)

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, tx + tabW / 2, tabY + 14, tab.name)

        addHit(tx, tabY, tabW, 28, function()
            panel.tab = tab.id
        end)
    end

    -- 内容区域
    local contentY = py + 95
    local contentH = ph - 110

    if panel.tab == "CHAPTERS" then
        CampaignPanel.drawChapters(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "STAGES" then
        CampaignPanel.drawStages(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "STORY" then
        CampaignPanel.drawStory(vg, px + 15, contentY, pw - 30, contentH)
    end
end

-- ============================================================================
-- 章节列表
-- ============================================================================

function CampaignPanel.drawChapters(vg, x, y, w, h)
    local CS = require("game.systems.CampaignSystem")
    local chapters = CS.getChapters()
    local progress = CS.getProgress()

    local rowH = 80
    local totalH = #chapters * (rowH + 10)

    panel.scrollY = math.max(0, math.min(panel.scrollY, math.max(0, totalH - h)))

    -- 滚动区域
    for i, chapter in ipairs(chapters) do
        local rowY = y - panel.scrollY + (i - 1) * (rowH + 10)
        if rowY + rowH > y and rowY < y + h then
            CampaignPanel.drawChapterRow(vg, x, rowY, w, rowH, chapter, progress)
        end
    end

    -- 滚动条
    if totalH > h then
        local scrollH = h * h / totalH
        local scrollY = y + (panel.scrollY / (totalH - h)) * (h - scrollH)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + w - 10, scrollY, 8, scrollH, 4)
        nvgFillColor(vg, nvgRGBA(80, 100, 140, 200))
        nvgFill(vg)
    end
end

function CampaignPanel.drawChapterRow(vg, x, y, w, h, chapter, progress)
    local completedCount = 0
    for _, stage in ipairs(chapter.stages) do
        if progress.completedStages[stage.id] then
            completedCount = completedCount + 1
        end
    end
    local totalStages = #chapter.stages
    local isComplete = completedCount >= totalStages
    local unlockWave = chapter.requiredWave or 0

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 8)
    nvgFillColor(vg, isComplete and nvgRGBA(30, 60, 40, 220) or nvgRGBA(30, 40, 60, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, isComplete and nvgRGBA(100, 200, 100, 150) or nvgRGBA(80, 100, 150, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 完成标记
    if isComplete then
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
        nvgText(vg, x + 10, y + 30, "✓")
    end

    -- 章节名称
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + 45, y + 25, chapter.name)

    -- 进度
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
    nvgText(vg, x + 45, y + 45, string.format("进度: %d/%d 关卡", completedCount, totalStages))

    -- 解锁条件
    nvgFillColor(vg, nvgRGBA(150, 150, 180, 255))
    nvgText(vg, x + 45, y + 62, string.format("解锁条件: 波次 %d+", unlockWave))

    -- 点击选择章节
    addHit(x, y, w, h, function()
        panel.selectedChapter = chapter.id
        panel.tab = "STAGES"
    end)
end

-- ============================================================================
-- 关卡列表
-- ============================================================================

function CampaignPanel.drawStages(vg, x, y, w, h)
    local CS = require("game.systems.CampaignSystem")

    if not panel.selectedChapter then
        -- 提示选择章节
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w / 2, y + h / 2, "请先选择一个章节")
        return
    end

    local chapter = nil
    for _, ch in ipairs(CAMPAIGN_CHAPTERS) do
        if ch.id == panel.selectedChapter then
            chapter = ch
            break
        end
    end

    if not chapter then return end

    local progress = CS.getProgress()
    local currentWave = playerState and playerState.currentWave or 0

    -- 章节标题
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 255, 255))
    nvgText(vg, x, y, chapter.name)

    local stageY = y + 25
    local stageH = 70

    for i, stage in ipairs(chapter.stages) do
        local rowY = stageY + (i - 1) * (stageH + 8)
        if rowY + stageH <= y + h then
            CampaignPanel.drawStageRow(vg, x, rowY, w, stageH, stage, progress, currentWave)
        end
    end
end

function CampaignPanel.drawStageRow(vg, x, y, w, h, stage, progress, currentWave)
    local completed = progress.completedStages[stage.id]
    local unlocked = currentWave >= stage.unlockWave
    local difficulty = STAGE_DIFFICULTY[stage.difficulty]

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 6)
    if completed then
        nvgFillColor(vg, nvgRGBA(30, 60, 40, 200))
        nvgStrokeColor(vg, nvgRGBA(100, 200, 100, 150))
    elseif unlocked then
        nvgFillColor(vg, nvgRGBA(35, 45, 70, 200))
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 120))
    else
        nvgFillColor(vg, nvgRGBA(25, 30, 45, 180))
        nvgStrokeColor(vg, nvgRGBA(60, 60, 80, 80))
    end
    nvgFill(vg)
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 关卡名称
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, completed and nvgRGBA(100, 255, 100, 255) or unlocked and nvgRGBA(255, 255, 255, 255) or nvgRGBA(120, 120, 140, 255))
    nvgText(vg, x + 15, y + 22, stage.name)

    -- 难度标签
    local diffColor = difficulty == STAGE_DIFFICULTY.EASY and nvgRGBA(100, 200, 100, 255)
                  or difficulty == STAGE_DIFFICULTY.MEDIUM and nvgRGBA(200, 200, 100, 255)
                  or difficulty == STAGE_DIFFICULTY.HARD and nvgRGBA(200, 100, 100, 255)
                  or nvgRGBA(180, 100, 200, 255)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, diffColor)
    nvgText(vg, x + 15, y + 40, difficulty.name)

    -- 目标类型
    local objective = STAGE_OBJECTIVES[stage.objective]
    nvgFillColor(vg, nvgRGBA(150, 150, 180, 255))
    nvgText(vg, x + 80, y + 40, objective.name)

    -- 奖励预览
    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(180, 180, 100, 255))
    local rewardStr = ""
    if stage.rewards.blueCrystal then rewardStr = rewardStr .. "蓝晶×" .. stage.rewards.blueCrystal .. " " end
    if stage.rewards.purpleCrystal then rewardStr = rewardStr .. "紫晶×" .. stage.rewards.purpleCrystal .. " " end
    if stage.rewards.credits then rewardStr = rewardStr .. "星币×" .. stage.rewards.credits .. " " end
    nvgText(vg, x + 15, y + 58, rewardStr)

    -- 开始按钮
    if unlocked then
        local btnX, btnY = x + w - 70, y + h / 2 - 12
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, btnY, 60, 24, 4)
        nvgFillColor(vg, completed and nvgRGBA(80, 150, 80, 220) or nvgRGBA(60, 100, 180, 220))
        nvgFill(vg)

        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, btnX + 30, btnY + 12, completed and "重玩" or "开始")

        addHit(btnX, btnY, 60, 24, function()
            CampaignPanel.startStage(stage.id)
        end)
    else
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w - 15, y + h / 2 + 4, "需波次 " .. stage.unlockWave .. "+")
    end
end

-- 开始关卡
function CampaignPanel.startStage(stageId)
    local CS = require("game.systems.CampaignSystem")
    local success, msg = CS.startStage(stageId, playerState)

    if success then
        CampaignPanel.close()
        -- 切换到战斗场景
        if SceneManager then
            SceneManager.switchTo("battle")
        end
    else
        if NotifyPanel then
            NotifyPanel.push({
                type = "ERROR",
                title = "无法开始",
                message = msg,
            })
        end
    end
end

-- ============================================================================
-- 剧情回顾
-- ============================================================================

function CampaignPanel.drawStory(vg, x, y, w, h)
    local CS = require("game.systems.CampaignSystem")
    local progress = CS.getProgress()

    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
    nvgText(vg, x, y + 20, "已完成 " .. #(progress.completedChapters or {}) .. "/" .. progress.totalChapters .. " 章节")

    -- 显示已解锁的剧情对话
    local dialogueY = y + 50
    local count = 0

    for key, _ in pairs(CAMPAIGN_DIALOGUE) do
        if CS.hasSeenDialogue(key) then
            local dialogue = CAMPAIGN_DIALOGUE[key]
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
            nvgText(vg, x, dialogueY + count * 20, "[" .. dialogue.speaker .. "] " .. dialogue.text)
            count = count + 1
            if count > 15 then break end
        end
    end

    if count == 0 then
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w / 2, y + h / 2, "完成战役关卡解锁剧情回顾")
    end
end

-- ============================================================================
-- 对话框覆盖层
-- ============================================================================

local DialogueOverlay = {}

function DialogueOverlay.show(dialogue)
    if not dialogue then return end

    local overlay = {
        visible = true,
        dialogue = dialogue,
        alpha = 0,
    }

    _G.DialogueOverlayInstance = overlay
end

function DialogueOverlay.draw(vg)
    local overlay = _G.DialogueOverlayInstance
    if not overlay or not overlay.visible then return end

    local BS = _G.BS
    local screenW = BS and BS.screenW or 800
    local screenH = BS and BS.screenH or 600

    -- 淡入效果
    overlay.alpha = math.min(1, overlay.alpha + 0.05)

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(overlay.alpha * 150)))
    nvgFill(vg)

    -- 对话框
    local dlgW, dlgH = 500, 150
    local dlgX, dlgY = (screenW - dlgW) / 2, screenH - dlgH - 50

    nvgBeginPath(vg)
    nvgRoundedRect(vg, dlgX, dlgY, dlgW, dlgH, 10)
    nvgFillColor(vg, nvgRGBA(20, 25, 40, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 200, 200))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 说话者
    local d = overlay.dialogue
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 180, 100, 255))
    nvgText(vg, dlgX + 20, dlgY + 25, d.speaker .. (d.speakerTitle and (" - " .. d.speakerTitle) or ""))

    -- 对话内容
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    -- 简单文本渲染（可扩展为多行）
    local text = d.text
    if #text > 40 then
        text = text:sub(1, 40) .. "..."
    end
    nvgText(vg, dlgX + 20, dlgY + 55, text)

    -- 点击继续
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.RIGHT)
    nvgFillColor(vg, nvgRGBA(150, 150, 170, 200))
    nvgText(vg, dlgX + dlgW - 20, dlgY + dlgH - 20, "点击继续...")

    addHit(0, 0, screenW, screenH, function()
        _G.DialogueOverlayInstance = nil
    end)
end

_G.DialogueOverlay = DialogueOverlay

-- ============================================================================
-- 导出
-- ============================================================================

return CampaignPanel
