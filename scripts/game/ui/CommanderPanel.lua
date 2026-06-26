---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/CommanderPanel.lua -- 指挥官选择面板
-- V2.8 P0-5 + P1-8 UI
-- ============================================================================

local CommanderPanel = {}

local panel = nil

function CommanderPanel.open()
    panel = {
        visible = true,
        tab = "COMMANDERS",
        w = 550,
        h = 420,
    }
    return panel
end

function CommanderPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

function CommanderPanel.draw(vg)
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
    nvgText(vg, cx, py + 30, "指挥官")

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
        CommanderPanel.close()
    end)

    -- 标签
    local tabs = { { id = "COMMANDERS", name = "指挥官" }, { id = "RECRUIT", name = "招募" } }
    local tabY = py + 55
    local tabW = 80
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

    if panel.tab == "COMMANDERS" then
        CommanderPanel.drawCommanders(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "RECRUIT" then
        CommanderPanel.drawRecruit(vg, px + 15, contentY, pw - 30, contentH)
    end
end

function CommanderPanel.drawCommanders(vg, x, y, w, h)
    local CS = require("game.systems.CommanderSystem")
    local commanders = CS.getAllCommanders()
    local current = CS.getCurrentCommander()

    local itemW = w
    local itemH = 80
    local itemGap = 8

    for i, cmd in ipairs(commanders) do
        local itemY = y + (i - 1) * (itemH + itemGap)
        if itemY + itemH > y + h then break end

        local isSelected = current and current.id == cmd.id
        local rarityColor = cmd.rarity == "LEGENDARY" and nvgRGBA(255, 200, 50, 255)
                       or cmd.rarity == "EPIC" and nvgRGBA(180, 100, 200, 255)
                       or cmd.rarity == "RARE" and nvgRGBA(100, 150, 220, 255)
                       or nvgRGBA(150, 150, 170, 255)

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, itemY, itemW, itemH, 6)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(50, 80, 140, 220))
            nvgStrokeColor(vg, nvgRGBA(100, 160, 255, 200))
        elseif cmd.unlocked then
            nvgFillColor(vg, nvgRGBA(35, 45, 70, 200))
            nvgStrokeColor(vg, nvgRGBA(80, 100, 150, 100))
        else
            nvgFillColor(vg, nvgRGBA(25, 30, 45, 180))
            nvgStrokeColor(vg, nvgRGBA(60, 60, 80, 80))
        end
        nvgFill(vg)
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 稀有度标记
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 8, itemY + 8, 8, itemH - 16, 2)
        nvgFillColor(vg, rarityColor)
        nvgFill(vg)

        -- 名称和称号
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, cmd.unlocked and nvgRGBA(255, 255, 255, 255) or nvgRGBA(120, 120, 140, 255))
        nvgText(vg, x + 25, itemY + 20, cmd.name)
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 25, itemY + 35, cmd.title)

        -- 稀有度
        nvgFontSize(vg, 10)
        nvgFillColor(vg, rarityColor)
        nvgText(vg, x + 25, itemY + 50, cmd.rarity)

        -- 阵营
        nvgText(vg, x + 90, itemY + 50, cmd.faction)

        -- 技能预览
        if cmd.unlocked then
            local skills = CS.getSkills()
            if #skills > 0 then
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(180, 200, 220, 200))
                local skillText = ""
                for j, skill in ipairs(skills) do
                    if j <= 2 then
                        skillText = skillText .. skill.name .. " "
                    end
                end
                nvgText(vg, x + 25, itemY + 65, skillText)
            end
        end

        -- 选中/选择按钮
        if cmd.unlocked then
            local btnX, btnY = x + w - 70, itemY + itemH / 2 - 12
            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX, btnY, 60, 24, 4)
            nvgFillColor(vg, isSelected and nvgRGBA(80, 150, 80, 220) or nvgRGBA(60, 100, 180, 220))
            nvgFill(vg)
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, btnX + 30, btnY + 12, isSelected and "已选择" or "选择")
            addHit(btnX, btnY, 60, 24, function()
                CS.selectCommander(cmd.id)
            end)
        else
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.RIGHT)
            nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
            nvgText(vg, x + w - 15, itemY + itemH / 2, "未解锁")
        end
    end
end

function CommanderPanel.drawRecruit(vg, x, y, w, h)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 20, "指挥官招募")

    -- 免费指挥官
    local recruitY = y + 50
    local btnW, btnH = 150, 80

    -- 免费招募
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, recruitY, btnW, btnH, 8)
    nvgFillColor(vg, nvgRGBA(40, 80, 120, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + btnW / 2, recruitY + 30, "免费指挥官")
    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 200))
    nvgText(vg, x + btnW / 2, recruitY + 50, "初始指挥官")

    addHit(x, recruitY, btnW, btnH, function()
        CommanderPanel.doFreeRecruit()
    end)

    -- 高级招募
    local btn2X = x + btnW + 10
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btn2X, recruitY, btnW, btnH, 8)
    nvgFillColor(vg, nvgRGBA(80, 60, 120, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, btn2X + btnW / 2, recruitY + 30, "高级招募")
    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(200, 180, 220, 200))
    nvgText(vg, btn2X + btnW / 2, recruitY + 50, "500 蓝晶")
    addHit(btn2X, recruitY, btnW, btnH, function()
        CommanderPanel.doPremiumRecruit("PREMIUM")
    end)

    -- 高级+招募
    local btn3X = x + (btnW + 10) * 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btn3X, recruitY, btnW, btnH, 8)
    nvgFillColor(vg, nvgRGBA(100, 60, 80, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 50, 150))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(255, 200, 50, 255))
    nvgText(vg, btn3X + btnW / 2, recruitY + 30, "高级+招募")
    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(220, 180, 200, 200))
    nvgText(vg, btn3X + btnW / 2, recruitY + 50, "10 虹晶")
    addHit(btn3X, recruitY, btnW, btnH, function()
        CommanderPanel.doPremiumRecruit("PREMIUM_PLUS")
    end)

    -- 保底说明
    nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgText(vg, x, y + 160, "高级招募保底稀有，高级+招募保底史诗")
end

function CommanderPanel.doFreeRecruit()
    local CS = require("game.systems.CommanderSystem")
    -- 免费获得一个指挥官（如果是新玩家）
    if NotifyPanel then
        NotifyPanel.push({
            type = "INFO",
            title = "提示",
            message = "初始指挥官已免费解锁",
        })
    end
end

function CommanderPanel.doPremiumRecruit(recruitType)
    local CS = require("game.systems.CommanderSystem")
    local success, msg, cmdId = CS.premiumRecruit(recruitType)

    if NotifyPanel then
        NotifyPanel.push({
            type = success and "SUCCESS" or "ERROR",
            title = success and "招募成功" or "招募失败",
            message = msg,
        })
    end
end

return CommanderPanel
