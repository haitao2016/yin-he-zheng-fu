-- Auto-split from RenderStarmap.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function M.drawBackground()
    local vg = GS.vg
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, GS.screenW, GS.screenH)
    nvgFillColor(vg, nvgRGBA(0, 6, 18, 255))
    nvgFill(vg)

    -- 背景星点（视差 x0.08）
    for _, s in ipairs(GS.bgStars) do
        local sx = (s.x + GS.camera.x * 0.08) % (GS.screenW + 100) - 50
        local sy = (s.y + GS.camera.y * 0.08) % (GS.screenH + 100) - 50
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, s.size * GS.zoom)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(s.op or 100)))
        nvgFill(vg)
    end
end
