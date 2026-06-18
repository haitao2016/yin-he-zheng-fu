-- Auto-split from RenderStarmap.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function drawOrbitRing(sx, sy, radius)
    local vg = GS.vg
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, radius * GS.zoom)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 15))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
end
