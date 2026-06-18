-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function generateBgStars()
    bgStars_ = {}
    math.randomseed(12345)
    for i = 1, 600 do
        bgStars_[i] = {
            x    = math.random(0, 6000),
            y    = math.random(0, 6000),
            size = math.random() * 1.5 + 0.3,
            op   = math.random() * 180 + 50,
        }
    end
    math.randomseed(os.time())
end
