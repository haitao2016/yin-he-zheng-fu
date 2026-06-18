-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function w2s(wx, wy)
    local cx = screenW_ / 2
    local cy = screenH_ / 2
    return (wx + camera_.x - cx) * zoom_ + cx,
           (wy + camera_.y - cy) * zoom_ + cy
end
