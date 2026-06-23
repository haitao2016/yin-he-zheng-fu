-- ============================================================================
-- game/galaxy/GalaxySceneGeneration.lua  -- 星图生成模块
-- ============================================================================

local GS = require("game.galaxy.GalaxyState")

local M = {}

-- 数据常量
local STAR_TYPES  = {"G-Type","Red Dwarf","Blue Giant","White Dwarf"}
local STAR_COLORS = {
    ["G-Type"]    = {255,240,80},
    ["Red Dwarf"] = {255,90,30},
    ["Blue Giant"]= {80,160,255},
    ["White Dwarf"]={240,240,255},
}
local PLANET_COLORS = {
    {58,123,213},{238,156,167},{186,104,200},{77,182,172},
    {129,199,132},{255,241,118},{255,138,101},{160,100,200},
}
local PLANET_TYPE_COLORS = {
    Terran        = {70,  160, 85 },
    Desert        = {200, 145, 55 },
    Oceanic       = {40,  110, 210},
    Volcanic      = {185, 55,  40 },
    Barren        = {125, 115, 105},
    ["Gas Giant"] = {155, 95,  210},
}
local PLANET_TYPES  = {"Terran","Desert","Oceanic","Volcanic","Barren","Gas Giant"}
local SYSTEM_PREFIXES = {"Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta",
    "Iota","Kappa","Lambda","Mu","Nova","Psi","Omega"}
local SYSTEM_SUFFIXES = {"Centauri","Sirius","Vega","Lyra","Aquila","Crux","Ara","Corona",
    "Draco","Lupus","Orion","Proxima","Rigel","Antares","Polaris"}

-- 小行星类型配置
local ASTEROID_TYPES = {
    minerals = { label="矿石",  color={180,140,90},  res="minerals" },
    energy   = { label="能量块", color={80,220,255}, res="energy"   },
    crystal  = { label="水晶",  color={200,120,255}, res="crystal"  },
}
local ASTEROID_TYPE_ORDER = {"minerals","energy","crystal"}

local ASTEROID_SIZES = {
    small  = { label="微型", sizeMin=3,  sizeMax=6,  hpBase=8,  yieldMin=5,  yieldMax=12 },
    medium = { label="中型", sizeMin=7,  sizeMax=11, hpBase=20, yieldMin=18, yieldMax=35 },
    large  = { label="大型", sizeMin=12, sizeMax=18, hpBase=45, yieldMin=50, yieldMax=90 },
}
local ASTEROID_SIZE_ORDER = {"small","medium","large"}

local function randItem(t)
    return t[math.random(1,#t)]
end

-- P2-2: 固定星系生成（战役模式专用）
local STAR_TYPE_MAP = { G="G-Type", K="Red Dwarf", M="Red Dwarf", F="Blue Giant" }

function M.generateFixedStarSystems(fixedDefs)
    local starSystems = {}
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
        starSystems[i] = sys
    end
    
    local allPlanets = {}
    local colonizedPlanets = {}
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            allPlanets[#allPlanets+1] = p
        end
    end
    
    print(string.format("[GalaxyScene] 固定星图生成: %d 星系, %d 行星", #starSystems, #allPlanets))
    
    return {
        starSystems = starSystems,
        deepSpaceSystems = {},
        allPlanets = allPlanets,
        colonizedPlanets = colonizedPlanets
    }
end

function M.generateStarSystems(mapVariant)
    local starSystems = {}
    
    local numStars, spread, resBonus
    if mapVariant == "DENSE" then
        numStars = 70
        spread   = 2800
        resBonus = 1.3
    elseif mapVariant == "SPARSE" then
        numStars = 35
        spread   = 6000
        resBonus = 1.0
    else
        numStars = 50
        spread   = 4000
        resBonus = 1.0
    end

    for i = 1, numStars do
        local stype = randItem(STAR_TYPES)
        local name  = SYSTEM_PREFIXES[math.random(1,#SYSTEM_PREFIXES)] .. " "
                    .. SYSTEM_SUFFIXES[math.random(1,#SYSTEM_SUFFIXES)]
                    .. "-" .. i

        local x, y
        if mapVariant == "BIPOLAR" then
            local side = (math.random() < 0.5) and -1 or 1
            x = side * (1000 + math.random() * 800) + (math.random() - 0.5) * 400
            y = (math.random() - 0.5) * 4000
        else
            x = (math.random() - 0.5) * spread
            y = (math.random() - 0.5) * spread
        end

        local sys   = {
            id=i, name=name, type=stype, x=x, y=y,
            radius = 12 + math.random() * 8,
            resBonus = resBonus,
            color  = STAR_COLORS[stype],
            planets= {},
        }
        local pCount = 2 + math.random(0, 5)
        for pi = 1, pCount do
            local ptype = randItem(PLANET_TYPES)
            local baseColor = PLANET_TYPE_COLORS[ptype] or PLANET_COLORS[math.random(1,#PLANET_COLORS)]
            local pc = {
                math.max(0, math.min(255, baseColor[1] + math.random(-15, 15))),
                math.max(0, math.min(255, baseColor[2] + math.random(-15, 15))),
                math.max(0, math.min(255, baseColor[3] + math.random(-15, 15))),
            }
            
            local MOON_COLORS = {
                Terran        = {180, 190, 170},
                Desert        = {210, 175, 110},
                Oceanic       = {130, 160, 220},
                Volcanic      = {190, 100,  70},
                Barren        = {155, 145, 135},
                ["Gas Giant"] = {190, 165, 230},
            }
            local moonColor = MOON_COLORS[ptype] or {160, 160, 160}
            local count = math.random(0, 2)
            local moons = {}
            for mi = 1, count do
                local orbitR = (5 + math.random() * 6) + (mi - 1) * 5
                moons[mi] = {
                    orbitR  = orbitR,
                    angle0  = math.random() * math.pi * 2,
                    period  = 15 + math.random() * 25,
                    radius  = 2 + math.random() * 2,
                    color   = {
                        math.max(0, math.min(255, moonColor[1] + math.random(-20, 20))),
                        math.max(0, math.min(255, moonColor[2] + math.random(-20, 20))),
                        math.max(0, math.min(255, moonColor[3] + math.random(-20, 20))),
                    },
                }
            end
            
            sys.planets[pi] = {
                id=pi, system=sys,
                name      = name:sub(1,6) .. "-" .. string.char(96+pi),
                orbitRadius = 45 + (pi-1) * 32,
                angle       = math.random() * math.pi * 2,
                orbitSpeed  = (0.3 + math.random() * 0.5) * 0.2,
                size        = 5 + math.random() * 8,
                color       = pc,
                colorHL = { math.min(255,pc[1]+80), math.min(255,pc[2]+80), math.min(255,pc[3]+80) },
                colorSH = { math.max(0,pc[1]-40),   math.max(0,pc[2]-40),   math.max(0,pc[3]-40)  },
                ptype       = ptype,
                colonized   = false,
                owner       = nil,
                buildings   = {},
                constructing= nil,
                _sx = nil, _sy = nil,
                satellites  = moons,
            }
        end
        starSystems[i] = sys
    end

    local deepSpaceSystems = {}
    local dsNames = {
        "奥利加深渊","塔尔苟虚空","幽冥星丛","裂隙边疆",
        "黑曜星域","残骸星场","异火星轨","深渊之眼",
    }
    local dsAngles = {}
    for i = 1, 8 do dsAngles[i] = (i - 1) / 8 * math.pi * 2 end
    for i = 1, 8 do
        local angle = dsAngles[i] + (math.random() - 0.5) * 0.4
        local dist  = 2200 + math.random() * 600
        local x     = math.cos(angle) * dist
        local y     = math.sin(angle) * dist
        local sys   = {
            id      = 1000 + i,
            name    = dsNames[i],
            type    = "neutron",
            x=x, y=y,
            radius  = 14,
            color   = {100, 60, 255},
            planets = {},
            deepSpace = true,
        }
        local pCount = 3 + math.random(0, 3)
        for pi = 1, pCount do
            local pc = PLANET_COLORS[math.random(1,#PLANET_COLORS)]
            sys.planets[pi] = {
                id=pi, system=sys,
                name        = sys.name:sub(1,4) .. "-" .. string.char(96+pi),
                orbitRadius = 50 + (pi-1) * 36,
                angle       = math.random() * math.pi * 2,
                orbitSpeed  = (0.2 + math.random() * 0.4) * 0.2,
                size        = 8 + math.random() * 10,
                color       = pc,
                colorHL = { math.min(255,pc[1]+80), math.min(255,pc[2]+80), math.min(255,pc[3]+80) },
                colorSH = { math.max(0,pc[1]-40),   math.max(0,pc[2]-40),   math.max(0,pc[3]-40)  },
                ptype       = randItem(PLANET_TYPES),
                colonized   = false,
                owner       = nil,
                buildings   = {},
                constructing= nil,
                resMultiplier = 2.0,
                _sx = nil, _sy = nil,
                deepSpace   = true,
            }
        end
        deepSpaceSystems[i] = sys
    end

    local allPlanets = {}
    local colonizedPlanets = {}
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            allPlanets[#allPlanets+1] = p
            if p.colonized then
                colonizedPlanets[#colonizedPlanets+1] = p
            end
        end
    end
    for _, sys in ipairs(deepSpaceSystems) do
        for _, p in ipairs(sys.planets) do
            allPlanets[#allPlanets+1] = p
        end
    end
    
    return {
        starSystems = starSystems,
        deepSpaceSystems = deepSpaceSystems,
        allPlanets = allPlanets,
        colonizedPlanets = colonizedPlanets
    }
end

function M.generateAsteroids()
    local asteroids = {}
    math.randomseed(54321)
    local sizeCounts = { small=30, medium=20, large=10 }
    for _, atype in ipairs(ASTEROID_TYPE_ORDER) do
        for _, sizeKey in ipairs(ASTEROID_SIZE_ORDER) do
            local cfg    = ASTEROID_TYPES[atype]
            local szCfg  = ASTEROID_SIZES[sizeKey]
            for _ = 1, sizeCounts[sizeKey] do
                local sz = szCfg.sizeMin + math.random() * (szCfg.sizeMax - szCfg.sizeMin)
                local y  = szCfg.yieldMin + math.random() * (szCfg.yieldMax - szCfg.yieldMin)
                asteroids[#asteroids+1] = {
                    x        = (math.random() - 0.5) * 4200,
                    y        = (math.random() - 0.5) * 4200,
                    atype    = atype,
                    sizeKey  = sizeKey,
                    size     = sz,
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
    return asteroids
end

function M.generateBgStars()
    local bgStars = {}
    math.randomseed(12345)
    for i = 1, 600 do
        bgStars[i] = {
            x    = math.random(0, 6000),
            y    = math.random(0, 6000),
            size = math.random() * 1.5 + 0.3,
            op   = math.random() * 180 + 50,
        }
    end
    math.randomseed(os.time())
    return bgStars
end

return M