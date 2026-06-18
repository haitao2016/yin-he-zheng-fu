-- Auto-split from ReplayPlayer.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function renderEventPopups(vg, mapX, mapY, mapW, mapH, ease)
    nvgFontFace(vg, "sans")
    for i = #eventPopups_, 1, -1 do
        local popup = eventPopups_[i]
        local alpha = popup.alpha * ease
        if alpha <= 0 then
            table.remove(eventPopups_, i)
        else
            local py = mapY + mapH - 30 - (i - 1) * 20
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 背景
            local tw = nvgTextBounds(vg, 0, 0, popup.text) + 16
            nvgBeginPath(vg)
            nvgRoundedRect(vg, mapX + mapW / 2 - tw / 2, py - 9, tw, 18, 4)
            nvgFillColor(vg, nvgRGBA(10, 20, 40, math.floor(180 * alpha)))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(160 * alpha)))
            nvgStrokeWidth(vg, 0.8)
            nvgStroke(vg)
            -- 文字
            nvgFillColor(vg, nvgRGBA(255, 230, 120, math.floor(240 * alpha)))
            nvgText(vg, mapX + mapW / 2, py, popup.text)
        end
    end
end
