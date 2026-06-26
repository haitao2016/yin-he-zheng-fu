-- ============================================================================
-- game/GalaxyGenerator.lua  -- 程序化星系生成器（种子驱动）
-- ============================================================================
-- 根据 6 字符字母数字种子确定性地生成星系布局。
-- 保证 same seed → same map，生成结束后恢复随机状态。
-- ============================================================================

---@class GalaxyGenerator
local GalaxyGenerator = {}

-- ============================================================================
-- 内部常量（与 GalaxyScene.lua 保持一致）
-- ============================================================================
local STAR_TYPES = { "G-Type", "Red Dwarf", "Blue Giant", "White Dwarf" }
local STAR_COLORS = {
    ["G-Type"]     = {255, 240, 80 },
    ["Red Dwarf"]  = {255, 90,  30 },
    ["Blue Giant"] = {80,  160, 255},
    ["White Dwarf"]= {240, 240, 255},
}
local PLANET_TYPES = { "Terran", "Desert", "Oceanic", "Volcanic", "Barren", "Gas Giant" }
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
local MOON_COLORS = {
    Terran        = {180, 190, 170},
    Desert        = {210, 175, 110},
    Oceanic       = {130, 160, 220},
    Volcanic      = {190, 100,  70},
    Barren        = {155, 145, 135},
    ["Gas Giant"] = {190, 165, 230},
}
local PREFIXES = {
    "Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta",
    "Iota","Kappa","Lambda","Mu","Nova","Psi","Omega",
}
local SUFFIXES = {
    "Centauri","Sirius","Vega","Lyra","Aquila","Crux","Ara","Corona",
    "Draco","Lupus","Orion","Proxima","Rigel","Antares","Polaris",
}
local DS_NAMES = {
    "奥利加深渊","塔尔苟虚空","幽冥星丛","裂隙边疆",
    "黑曜星域","残骸星场","异火星轨","深渊之眼",
}

-- 种子字母表（大写 A-Z + 数字 0-9，共 36 字符）
local SEED_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local SEED_BASE  = #SEED_CHARS   -- 36
local SEED_LEN   = 6

-- ============================================================================
-- 辅助函数（使用 math.random，调用方负责设置随机种子）
-- ============================================================================

---从列表中随机选取一项
---@param t table
---@return any
local function randItem(t)
    return t[math.random(1, #t)]
end

---限制数值在 [lo, hi] 区间
---@param v number
---@param lo number
---@param hi number
---@return number
local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

---从基础颜色生成带随机微调的颜色表
---@param base number[]
---@param jitter integer
---@return number[]
local function jitterColor(base, jitter)
    return {
        clamp(base[1] + math.random(-jitter, jitter), 0, 255),
        clamp(base[2] + math.random(-jitter, jitter), 0, 255),
        clamp(base[3] + math.random(-jitter, jitter), 0, 255),
    }
end

---生成行星的卫星列表（0-2 颗）
---@param ptype string  行星类型
---@param pi integer    行星序号（用于偏移量）
---@return table
local function buildSatellites(ptype, pi)
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
                clamp(moonColor[1] + math.random(-20, 20), 0, 255),
                clamp(moonColor[2] + math.random(-20, 20), 0, 255),
                clamp(moonColor[3] + math.random(-20, 20), 0, 255),
            },
        }
    end
    return moons
end

---构建单颗行星记录
---@param sys table       所属星系（back-reference）
---@param pi integer      行星序号（1-based）
---@param sysName string  星系名（用于行星命名）
---@param deepSpace boolean|nil
---@return table
local function buildPlanet(sys, pi, sysName, deepSpace)
    local ptype     = randItem(PLANET_TYPES)
    local baseColor = PLANET_TYPE_COLORS[ptype] or PLANET_COLORS[math.random(1, #PLANET_COLORS)]
    local pc        = jitterColor(baseColor, 15)
    local sizeMin   = deepSpace and 8 or 5
    local sizeRange = deepSpace and 10 or 8
    return {
        id          = pi,
        system      = sys,
        name        = sysName:sub(1, 6) .. "-" .. string.char(96 + pi),
        orbitRadius = 45 + (pi - 1) * 32,
        angle       = math.random() * math.pi * 2,
        orbitSpeed  = (0.3 + math.random() * 0.5) * 0.2,
        size        = sizeMin + math.random() * sizeRange,
        color       = pc,
        colorHL     = { math.min(255, pc[1]+80), math.min(255, pc[2]+80), math.min(255, pc[3]+80) },
        colorSH     = { math.max(0,   pc[1]-40), math.max(0,   pc[2]-40), math.max(0,   pc[3]-40) },
        ptype       = ptype,
        colonized   = false,
        owner       = nil,
        buildings   = {},
        constructing= nil,
        _sx         = nil,
        _sy         = nil,
        satellites  = buildSatellites(ptype, pi),
        -- 特殊行星字段（默认 nil，由特殊行星逻辑填充）
        special     = nil,
        binaryPair  = nil,
        stormTimer  = nil,
        salvageWaves= nil,
        deepSpace   = deepSpace or nil,
        resMultiplier = deepSpace and 2.0 or nil,
    }
end

---构建一个星系记录
---@param id integer
---@param name string
---@param x number
---@param y number
---@param pCount integer
---@param deepSpace boolean|nil
---@return table
local function buildSystem(id, name, x, y, pCount, deepSpace)
    local stype = deepSpace and "neutron" or randItem(STAR_TYPES)
    local color = deepSpace and {100, 60, 255} or STAR_COLORS[stype]
    local sys = {
        id      = id,
        name    = name,
        type    = stype,
        x       = x,
        y       = y,
        radius  = deepSpace and 14 or (12 + math.random() * 8),
        color   = color,
        planets = {},
        deepSpace = deepSpace or nil,
    }
    for pi = 1, pCount do
        sys.planets[pi] = buildPlanet(sys, pi, name, deepSpace)
    end
    return sys
end

-- ============================================================================
-- 形状生成策略（每种形状决定星系数量和坐标）
-- ============================================================================

---生成 SPIRAL（螺旋星系）坐标列表
---@return number[][]   {{x,y}, ...}
local function shapeSPIRAL()
    local golden = math.pi * (3 - math.sqrt(5))  -- 黄金角 ≈ 2.399 rad
    local arms   = 2
    local perArm = 4  -- 每臂 3-4 个，总 6-8
    local coords = {}
    for arm = 0, arms - 1 do
        local armOffset = arm * math.pi
        for i = 1, perArm do
            local t    = i / perArm                 -- 0..1
            local dist = 600 + t * 1800             -- 600-2400
            local ang  = armOffset + i * golden * 2 + (math.random() - 0.5) * 0.5
            coords[#coords + 1] = {
                math.cos(ang) * dist + (math.random() - 0.5) * 200,
                math.sin(ang) * dist + (math.random() - 0.5) * 200,
            }
        end
    end
    return coords
end

---生成 CLUSTER（星团）坐标列表
---@return number[][]
local function shapeCLUSTER()
    local coords = {}
    for _ = 1, 10 do
        -- Box-Muller 近似：密集分布在中心 1500 半径内
        local r   = math.sqrt(-2 * math.log(math.max(1e-6, math.random()))) * 700
        local ang = math.random() * math.pi * 2
        coords[#coords + 1] = { math.cos(ang) * r, math.sin(ang) * r }
    end
    return coords
end

---生成 CORRIDOR（虚空走廊）坐标列表
---@return number[][]
local function shapeCORRIDOR()
    local coords = {}
    local step = 1200
    for i = 0, 3 do
        local x = (i - 1.5) * step
        local y = (math.random() - 0.5) * 400
        coords[#coords + 1] = { x, y }
    end
    return coords
end

---生成 TWIN（双子星系）坐标列表
---@return number[][]
local function shapeTWIN()
    local coords = {}
    -- 左侧 4 个
    for _ = 1, 4 do
        coords[#coords + 1] = {
            -1200 + (math.random() - 0.5) * 600,
             (math.random() - 0.5) * 1200,
        }
    end
    -- 右侧 4 个
    for _ = 1, 4 do
        coords[#coords + 1] = {
            1200 + (math.random() - 0.5) * 600,
            (math.random() - 0.5) * 1200,
        }
    end
    -- 中间跳跃点（1 个）
    coords[#coords + 1] = { (math.random() - 0.5) * 300, (math.random() - 0.5) * 300 }
    return coords
end

---生成 RING（环形星系）坐标列表
---@return number[][]
local function shapeRING()
    local coords = {}
    local ringR  = 1500
    local n      = 8
    for i = 0, n - 1 do
        local ang = (i / n) * math.pi * 2 + (math.random() - 0.5) * 0.3
        coords[#coords + 1] = {
            math.cos(ang) * ringR + (math.random() - 0.5) * 200,
            math.sin(ang) * ringR + (math.random() - 0.5) * 200,
        }
    end
    -- 中心高价值核心恒星
    coords[#coords + 1] = { (math.random() - 0.5) * 200, (math.random() - 0.5) * 200 }
    return coords
end

-- 形状分发表
local SHAPE_BUILDERS = {
    SPIRAL   = shapeSPIRAL,
    CLUSTER  = shapeCLUSTER,
    CORRIDOR = shapeCORRIDOR,
    TWIN     = shapeTWIN,
    RING     = shapeRING,
}
-- 每种形状对应的行星数量范围 {min, max}
local PLANET_RANGES = {
    SPIRAL   = {3, 5},
    CLUSTER  = {2, 4},
    CORRIDOR = {4, 6},
    TWIN     = {3, 5},
    RING     = {3, 5},
}

-- P2-P2-2: 随机星图可玩变体参数
-- 变体类型：紧凑（COMPACT）、标准（STANDARD）、松散（SPARSE）
M.MAP_VARIANTS = {
    COMPACT = {
        name = "紧凑星域",
        desc = "星系密集，战斗频繁，资源丰富但危险",
        -- 星系间距缩小
        systemSpacingMult = 0.6,
        -- 星系内行星数量增加
        planetCountMult = 1.3,
        -- 稀有资源点概率提升
        rareNodeChance = 0.25,
        -- 特殊事件（海盗、探索点）频率提升
        eventFrequencyMult = 1.4,
        -- 初始敌人数量
        initialEnemyCount = 3,
        -- 星系数
        systemCountRange = {6, 10},
    },
    STANDARD = {
        name = "标准星域",
        desc = "平衡的星系布局，适合大多数玩家",
        systemSpacingMult = 1.0,
        planetCountMult = 1.0,
        rareNodeChance = 0.15,
        eventFrequencyMult = 1.0,
        initialEnemyCount = 2,
        systemCountRange = {8, 12},
    },
    SPARSE = {
        name = "松散星域",
        desc = "星系稀疏，节奏缓慢，适合探索型玩家",
        systemSpacingMult = 1.5,
        planetCountMult = 0.8,
        rareNodeChance = 0.20,
        eventFrequencyMult = 0.7,
        initialEnemyCount = 1,
        systemCountRange = {5, 8},
    },
}

-- 变体列表（用于 UI 显示）
M.MAP_VARIANT_KEYS = { "COMPACT", "STANDARD", "SPARSE" }

---根据变体类型和种子获取变体参数
---@param variantKey string
---@return table
function GalaxyGenerator.GetVariantParams(variantKey)
    return M.MAP_VARIANTS[variantKey] or M.MAP_VARIANTS.STANDARD
end

---获取变体列表（用于 UI 显示）
---@return table
function GalaxyGenerator.GetVariantList()
    local list = {}
    for _, key in ipairs(M.MAP_VARIANT_KEYS) do
        local v = M.MAP_VARIANTS[key]
        list[#list + 1] = { key = key, name = v.name, desc = v.desc }
    end
    return list
end

-- ============================================================================
-- 公开 API
-- ============================================================================

---将 6 字符种子字符串转为数值
---@param seedStr string
---@return integer
function GalaxyGenerator.SeedToNumber(seedStr)
    seedStr = seedStr:upper()
    local n = 0
    for i = 1, SEED_LEN do
        local ch  = seedStr:sub(i, i)
        local idx = SEED_CHARS:find(ch, 1, true) or 1
        n = n * SEED_BASE + (idx - 1)
    end
    return n
end

---将数值转为 6 字符种子字符串
---@param num integer
---@return string
function GalaxyGenerator.NumberToSeed(num)
    local chars = {}
    local n = num
    for i = SEED_LEN, 1, -1 do
        local rem = n % SEED_BASE
        chars[i]  = SEED_CHARS:sub(rem + 1, rem + 1)
        n = math.floor(n / SEED_BASE)
    end
    return table.concat(chars)
end

---生成随机 6 字符种子
---@return string
function GalaxyGenerator.RandomSeed()
    local chars = {}
    for i = 1, SEED_LEN do
        chars[i] = SEED_CHARS:sub(math.random(1, SEED_BASE), math.random(1, SEED_BASE))
        -- 确保每次取同一个字符（sub 两端相同）
        local idx = math.random(1, SEED_BASE)
        chars[i]  = SEED_CHARS:sub(idx, idx)
    end
    return table.concat(chars)
end

---由种子决定星系形状
---@param seedStr string
---@return string  shape  one of "SPIRAL"|"CLUSTER"|"CORRIDOR"|"TWIN"|"RING"
function GalaxyGenerator.GetShape(seedStr)
    local n      = GalaxyGenerator.SeedToNumber(seedStr)
    local shapes = { "SPIRAL", "CLUSTER", "CORRIDOR", "TWIN", "RING" }
    -- 使用种子高位 bit 决定形状（避免与坐标生成的 RNG 状态耦合）
    local idx = (n % #shapes) + 1
    return shapes[idx] --[[@as string]]
end

---主生成函数
---@param seedStr string         6 字符种子
---@param opts table|nil         可选参数（variantKey: string, 使用变体参数）
---@return table  { starSystems, deepSpaceSystems, allPlanets, shape, specialPlanets }
function GalaxyGenerator.Generate(seedStr, opts)
    opts = opts or {}
    local variantKey = opts.variantKey or "STANDARD"
    local variant = M.MAP_VARIANTS[variantKey] or M.MAP_VARIANTS.STANDARD

    -- 1. 种子转数值并播种 RNG
    local seedNum = GalaxyGenerator.SeedToNumber(seedStr)
    math.randomseed(seedNum)

    local shape = GalaxyGenerator.GetShape(seedStr)

    -- 2. 生成主星系坐标
    local coordFn  = SHAPE_BUILDERS[shape]
    local coords   = coordFn()
    local pRange   = PLANET_RANGES[shape]

    -- P2-P2-2: 使用变体参数调整星系数量
    local sysCountRange = variant.systemCountRange or {8, 12}
    local sysCount = sysCountRange[1] + math.random(0, sysCountRange[2] - sysCountRange[1])
    local starSystems = {}

    for i, coord in ipairs(coords) do
        if i > sysCount then break end  -- 限制星系数量
        -- P2-P2-2: 使用变体参数调整行星数量
        local basePCount = pRange[1] + math.random(0, pRange[2] - pRange[1])
        local pCount = math.floor(basePCount * variant.planetCountMult + 0.5)
        pCount = math.max(1, pCount)
        local name   = PREFIXES[math.random(1, #PREFIXES)] .. " "
                     .. SUFFIXES[math.random(1, #SUFFIXES)]
                     .. "-" .. i
        starSystems[i] = buildSystem(i, name, coord[1], coord[2], pCount, false)
    end

    -- 3. 生成深空星系（外环，radius 2200+）
    local deepSpaceSystems = {}
    -- P2-P2-2: 使用变体参数调整深空星系数量
    local dsCountBase = variant.eventFrequencyMult >= 1.0 and 4 or 3
    local dsCount = dsCountBase + math.random(0, 3)
    for i = 1, dsCount do
        local ang  = ((i - 1) / dsCount) * math.pi * 2 + (math.random() - 0.5) * 0.4
        -- P2-P2-2: 使用变体参数调整深空星系间距
        local dist = 2200 + math.random() * 600
        if variantKey == "COMPACT" then
            dist = 2000 + math.random() * 400
        elseif variantKey == "SPARSE" then
            dist = 2600 + math.random() * 800
        end
        local x    = math.cos(ang) * dist
        local y    = math.sin(ang) * dist
        local dsName = DS_NAMES[i] or ("深渊-" .. i)
        local pCount = 3 + math.random(0, 3)
        deepSpaceSystems[i] = buildSystem(1000 + i, dsName, x, y, pCount, true)
    end

    -- 4. 平铺所有行星（与 GalaxyScene 逻辑一致）
    local allPlanets = {}
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            allPlanets[#allPlanets + 1] = p
        end
    end
    for _, sys in ipairs(deepSpaceSystems) do
        for _, p in ipairs(sys.planets) do
            allPlanets[#allPlanets + 1] = p
        end
    end

    -- 5. 特殊行星分配（仅在主星系行星中分配）
    ---@type table[]
    local specialPlanets = {}
    local deadCount, stormCount, binaryCount = 0, 0, 0
    local MAX_DEAD, MAX_STORM, MAX_BINARY = 2, 2, 1

    -- 遍历主星系行星，用种子 RNG 决定特殊类型
    -- 先收集主星系行星（深空行星不分配特殊类型）
    local mainPlanets = {}
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            mainPlanets[#mainPlanets + 1] = p
        end
    end

    -- 第一遍：Dead World 和 Storm World
    for _, p in ipairs(mainPlanets) do
        local roll = math.random()
        if roll < 0.10 and deadCount < MAX_DEAD then
            p.special      = "DEAD"
            p.salvageWaves = 0
            -- Dead World 不可殖民，覆盖颜色为暗灰
            p.color   = {80, 80, 80}
            p.colorHL = {140, 140, 140}
            p.colorSH = {40,  40,  40}
            specialPlanets[#specialPlanets + 1] = { planet = p, type = "DEAD" }
            deadCount = deadCount + 1
        elseif roll < 0.18 and stormCount < MAX_STORM then
            p.special     = "STORM"
            p.stormTimer  = 0
            specialPlanets[#specialPlanets + 1] = { planet = p, type = "STORM" }
            stormCount = stormCount + 1
        end
    end

    -- 第二遍：Binary World（需要配对）
    if binaryCount < MAX_BINARY and #mainPlanets >= 2 then
        -- 从未分配特殊类型的行星中随机选取两颗同星系行星配对
        for _, sys in ipairs(starSystems) do
            if binaryCount >= MAX_BINARY then break end
            -- 找出该星系中没有特殊类型的行星
            local candidates = {}
            for _, p in ipairs(sys.planets) do
                if not p.special then
                    candidates[#candidates + 1] = p
                end
            end
            if #candidates >= 2 and math.random() < 0.05 then
                local a = candidates[1]
                local b = candidates[2]
                a.special    = "BINARY"
                b.special    = "BINARY"
                a.binaryPair = b
                b.binaryPair = a
                specialPlanets[#specialPlanets + 1] = { planet = a, type = "BINARY" }
                specialPlanets[#specialPlanets + 1] = { planet = b, type = "BINARY" }
                binaryCount = binaryCount + 1
            end
        end
    end

    -- 6. 恢复随机种子（使用当前时间，避免影响游戏其他随机逻辑）
    math.randomseed(os.time())

    return {
        starSystems      = starSystems,
        deepSpaceSystems = deepSpaceSystems,
        allPlanets       = allPlanets,
        shape            = shape,
        specialPlanets   = specialPlanets,
    }
end

return GalaxyGenerator
