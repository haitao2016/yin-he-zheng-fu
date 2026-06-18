-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


    -- ---- 深空星系（曲速闸门解锁后可访问）----
    deepSpaceSystems_ = {}
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
            type    = "neutron",   -- 深空恒星类型
            x=x, y=y,
            radius  = 14,
            color   = {100, 60, 255},   -- 蓝紫色
            planets = {},
            deepSpace = true,    -- 标记为深空
        }
        -- 深空行星数量更多、更大
        local pCount = 3 + math.random(0, 3)
        for pi = 1, pCount do
            local pc = PLANET_COLORS[math.random(1,#PLANET_COLORS)]
            sys.planets[pi] = {
                id=pi, system=sys,
                name        = sys.name:sub(1,4) .. "-" .. string.char(96+pi),
                orbitRadius = 50 + (pi-1) * 36,
                angle       = math.random() * math.pi * 2,
                orbitSpeed  = (0.2 + math.random() * 0.4) * 0.2,
                size        = 8 + math.random() * 10,   -- 更大的行星
                color       = pc,
                colorHL = { math.min(255,pc[1]+80), math.min(255,pc[2]+80), math.min(255,pc[3]+80) },
                colorSH = { math.max(0,pc[1]-40),   math.max(0,pc[2]-40),   math.max(0,pc[3]-40)  },
                ptype       = randItem(PLANET_TYPES),
                colonized   = false,
                owner       = nil,
                buildings   = {},
                constructing= nil,
                resMultiplier = 2.0,   -- 深空资源翻倍
                _sx = nil, _sy = nil,
                deepSpace   = true,
            }
        end
        deepSpaceSystems_[i] = sys
    end

    -- 填充平铺缓存（后续 GetAllPlanets 直接返回此引用，零分配）
    allPlanets_       = {}
    colonizedPlanets_ = {}   -- 新地图无已殖民行星
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            allPlanets_[#allPlanets_+1] = p
            if p.colonized then
                colonizedPlanets_[#colonizedPlanets_+1] = p
            end
        end
    end
    -- 深空行星也加入总列表（但不计入初始殖民缓存）
    for _, sys in ipairs(deepSpaceSystems_) do
        for _, p in ipairs(sys.planets) do
            allPlanets_[#allPlanets_+1] = p
        end
    end
end

-- 小行星类型配置（三种资源类型）
local ASTEROID_TYPES = {
    minerals = { label="矿石",  color={180,140,90},  res="minerals" },
    energy   = { label="能量块", color={80,220,255}, res="energy"   },
    crystal  = { label="水晶",  color={200,120,255}, res="crystal"  },
}
local ASTEROID_TYPE_ORDER = {"minerals","energy","crystal"}

-- 小行星尺寸分级配置
local ASTEROID_SIZES = {
    small  = { label="微型", sizeMin=3,  sizeMax=6,  hpBase=8,  yieldMin=5,  yieldMax=12 },
    medium = { label="中型", sizeMin=7,  sizeMax=11, hpBase=20, yieldMin=18, yieldMax=35 },
    large  = { label="大型", sizeMin=12, sizeMax=18, hpBase=45, yieldMin=50, yieldMax=90 },
}
local ASTEROID_SIZE_ORDER = {"small","medium","large"}

