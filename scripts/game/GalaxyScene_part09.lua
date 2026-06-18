-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function generateFixedStarSystems(fixedDefs)
    starSystems_ = {}
    for i, def in ipairs(fixedDefs) do
        local stype = STAR_TYPE_MAP[def.type] or "G-Type"
        local name  = SYSTEM_PREFIXES[((i-1) % #SYSTEM_PREFIXES) + 1] .. " "
                    .. SYSTEM_SUFFIXES[((i-1) % #SYSTEM_SUFFIXES) + 1]
                    .. "-" .. i
        local sys = {
            id=i, name=name, type=stype, x=def.x, y=def.y,
            radius = 14 + (i % 3) * 4,
            resBonus = 1.0,
            color  = STAR_COLORS[stype],
            planets= {},
        }
        local pCount = def.planets or 3
        for pi = 1, pCount do
            local ptype = PLANET_TYPES[((i + pi - 1) % #PLANET_TYPES) + 1]
            local baseColor = PLANET_TYPE_COLORS[ptype] or PLANET_COLORS[((pi-1) % #PLANET_COLORS) + 1]
            local pc = {
                math.max(0, math.min(255, baseColor[1] + (pi * 7) % 15 - 7)),
                math.max(0, math.min(255, baseColor[2] + (pi * 11) % 15 - 7)),
                math.max(0, math.min(255, baseColor[3] + (pi * 13) % 15 - 7)),
            }
            sys.planets[pi] = {
                id=pi, system=sys,
                name      = name:sub(1,6) .. "-" .. string.char(96+pi),
                orbitRadius = 45 + (pi-1) * 32,
                angle       = (pi * 1.2) % (math.pi * 2),
                orbitSpeed  = (0.3 + (pi * 0.1)) * 0.2,
                size        = 6 + pi * 2,
                color       = pc,
                colorHL = { math.min(255,pc[1]+80), math.min(255,pc[2]+80), math.min(255,pc[3]+80) },
                colorSH = { math.max(0,pc[1]-40),   math.max(0,pc[2]-40),   math.max(0,pc[3]-40)  },
                ptype       = ptype,
                colonized   = false,
                owner       = nil,
                buildings   = {},
                constructing= nil,
                _sx = nil, _sy = nil,
                satellites  = {},
            }
        end
        starSystems_[i] = sys
    end
    -- 填充平铺缓存
    allPlanets_       = {}
    colonizedPlanets_ = {}
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            allPlanets_[#allPlanets_+1] = p
        end
    end
    deepSpaceSystems_ = {}  -- 战役无深空星系
    print(string.format("[GalaxyScene] 固定星图生成: %d 星系, %d 行星", #starSystems_, #allPlanets_))
end
