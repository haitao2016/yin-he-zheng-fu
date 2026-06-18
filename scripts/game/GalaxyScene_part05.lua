-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function s2w(sx, sy)
    local cx = screenW_ / 2
    local cy = screenH_ / 2
    return (sx - cx) / zoom_ - camera_.x + cx,
           (sy - cy) / zoom_ - camera_.y + cy
end
