-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function dist2(x1,y1,x2,y2)
    local dx,dy = x2-x1, y2-y1
    return math.sqrt(dx*dx+dy*dy)
end
