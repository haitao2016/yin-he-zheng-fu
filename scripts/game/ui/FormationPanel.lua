---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/FormationPanel.lua -- 阵型选择面板
-- V2.8 P1-5 UI
-- ============================================================================

local FormationPanel = {}

local panel = nil

function FormationPanel.open()
    panel = {
        visible = true,
        w = 400,
        h = 350,
    }
    return panel
end

function FormationPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

function FormationPanel.draw(vg)
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

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "阵型选择")

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
        FormationPanel.close()
    end)

    -- 阵型列表
    local FS = require("game.systems.FormationSystem")
    local formations = FS.getAllFormations()
    local current = FS.getCurrentFormation()

    local listX = px + 15
    local listY = py + 55
    local itemW = pw - 30
    local itemH = 60
    local itemGap = 8

    for i, formation in ipairs(formations) do
        local itemY = listY + (i - 1) * (itemH + itemGap)
        local isSelected = current and current.id == formation.id

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, listX, itemY, itemW, itemH, 6)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(50, 80, 150, 220))
            nvgStrokeColor(vg, nvgRGBA(100, 160, 255, 200))
        elseif formation.unlocked then
            nvgFillColor(vg, nvgRGBA(35, 45, 70, 200))
            nvgStrokeColor(vg, nvgRGBA(80, 100, 150, 100))
        else
            nvgFillColor(vg, nvgRGBA(25, 30, 45, 180))
            nvgStrokeColor(vg, nvgRGBA(60, 60, 80, 80))
        end
        nvgFill(vg)
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 名称
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, isSelected and nvgRGBA(100, 200, 255, 255)
                     or formation.unlocked and nvgRGBA(220, 220, 240, 255)
                     or nvgRGBA(120, 120, 140, 255))
        nvgText(vg, listX + 15, itemY + 20, formation.name)

        -- 效果描述
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        local effectText = ""
        if formation.effect then
            if formation.effect.dmgBonus then effectText = effectText .. "伤害+" .. math.floor(formation.effect.dmgBonus * 100) .. "% " end
            if formation.effect.defenseBonus then effectText = effectText .. "防御+" .. math.floor(formation.effect.defenseBonus * 100) .. "% " end
            if formation.effect.speedBonus then effectText = effectText .. "速度+" .. math.floor(formation.effect.speedBonus * 100) .. "% " end
            if formation.effect.aoeReduction then effectText = effectText .. "AOE减伤" .. math.floor(formation.effect.aoeReduction * 100) .. "% " end
        end
        if effectText == "" then effectText = formation.desc end
        nvgText(vg, listX + 15, itemY + 38, effectText)

        -- 选中标记
        if isSelected then
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN.RIGHT)
            nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
            nvgText(vg, listX + itemW - 15, itemY + itemH / 2, "✓ 已选择")
        elseif not formation.unlocked then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN.RIGHT)
            nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
            nvgText(vg, listX + itemW - 15, itemY + itemH / 2, "未解锁")
        end

        -- 点击选择
        if formation.unlocked then
            addHit(listX, itemY, itemW, itemH, function()
                FS.selectFormation(formation.id)
            end)
        end
    end
end

return FormationPanel
