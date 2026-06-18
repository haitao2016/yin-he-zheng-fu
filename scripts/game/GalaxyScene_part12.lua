-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function generateAsteroids()
    asteroids_ = {}
    math.randomseed(54321)
    -- 每种资源类型：微型30颗、中型20颗、大型10颗（共60颗/类型，总180颗）
    local sizeCounts = { small=30, medium=20, large=10 }
    for _, atype in ipairs(ASTEROID_TYPE_ORDER) do
        for _, sizeKey in ipairs(ASTEROID_SIZE_ORDER) do
            local cfg    = ASTEROID_TYPES[atype]
            local szCfg  = ASTEROID_SIZES[sizeKey]
            for _ = 1, sizeCounts[sizeKey] do
                local sz = szCfg.sizeMin + math.random() * (szCfg.sizeMax - szCfg.sizeMin)
                local y  = szCfg.yieldMin + math.random() * (szCfg.yieldMax - szCfg.yieldMin)
                asteroids_[#asteroids_+1] = {
                    x        = (math.random() - 0.5) * 4200,
                    y        = (math.random() - 0.5) * 4200,
                    atype    = atype,
                    sizeKey  = sizeKey,          -- "small"/"medium"/"large"
                    size     = sz,               -- 世界半径（渲染用）
                    yield    = y,
                    hp       = szCfg.hpBase,
                    maxHP    = szCfg.hpBase,
                    angle    = math.random() * math.pi * 2,
                    rotSpd   = (math.random() - 0.5) * 0.8,
                }
            end
        end
    end
    math.randomseed(os.time())
end
