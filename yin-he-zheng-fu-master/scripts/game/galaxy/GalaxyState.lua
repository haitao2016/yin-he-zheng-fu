-- ============================================================================
-- game/galaxy/GalaxyState.lua  — 银河场景共享状态表
-- GalaxyScene 每帧写入，Render 子模块读取
-- ============================================================================

local GS = {}

-- ============================================================================
-- 数据常量
-- ============================================================================
GS.STAR_TYPES  = {"G-Type","Red Dwarf","Blue Giant","White Dwarf"}
GS.STAR_COLORS = {
    ["G-Type"]    = {255,240,80},
    ["Red Dwarf"] = {255,90,30},
    ["Blue Giant"]= {80,160,255},
    ["White Dwarf"]={240,240,255},
}
GS.PLANET_COLORS = {
    {58,123,213},{238,156,167},{186,104,200},{77,182,172},
    {129,199,132},{255,241,118},{255,138,101},{160,100,200},
}
GS.PLANET_TYPE_COLORS = {
    Terran        = {70,  160, 85 },
    Desert        = {200, 145, 55 },
    Oceanic       = {40,  110, 210},
    Volcanic      = {185, 55,  40 },
    Barren        = {125, 115, 105},
    ["Gas Giant"] = {155, 95,  210},
}
GS.PLANET_TYPES  = {"Terran","Desert","Oceanic","Volcanic","Barren","Gas Giant"}

-- 小地图常量
GS.MINIMAP_W           = 160
GS.MINIMAP_H           = 120
GS.MINIMAP_PAD         = 10
GS.MINIMAP_WORLD_RANGE = 2100

-- 信号系统常量
GS.QUICK_SIGNALS = {
    { icon="⚔️",  text="集火攻击！",   color={255,80,80}   },
    { icon="🛡️",  text="注意防守！",   color={80,160,255}  },
    { icon="🔍",  text="侦察行动！",   color={180,255,100} },
    { icon="🚀",  text="全速前进！",   color={255,200,50}  },
    { icon="💠",  text="集结此处！",   color={140,80,255}  },
    { icon="🏭",  text="建设优先！",   color={80,220,180}  },
    { icon="⚡",  text="紧急情况！",   color={255,160,40}  },
    { icon="✅",  text="行动完毕！",   color={80,255,120}  },
}
GS.SIGNAL_CD    = 15.0
GS.BANNER_DUR   = 5.0
GS.BANNER_FADE  = 1.0

-- 小行星常量
GS.ASTEROID_TYPES = {
    minerals = { label="矿石",  color={180,140,90},  res="minerals" },
    energy   = { label="能量块", color={80,220,255}, res="energy"   },
    crystal  = { label="水晶",  color={200,120,255}, res="crystal"  },
}
GS.ASTEROID_TYPE_ORDER = {"minerals","energy","crystal"}
GS.ASTEROID_SIZES = {
    small  = { label="微型", sizeMin=3,  sizeMax=6,  hpBase=8,  yieldMin=5,  yieldMax=12 },
    medium = { label="中型", sizeMin=7,  sizeMax=11, hpBase=20, yieldMin=18, yieldMax=35 },
    large  = { label="大型", sizeMin=12, sizeMax=18, hpBase=45, yieldMin=50, yieldMax=90 },
}
GS.ASTEROID_SIZE_ORDER = {"small","medium","large"}

-- 海盗舰队速度（ETA 计算用）
GS.PIRATE_FLEET_SPEED = 55

-- 种子飞船常量
GS.SEED_DEPLOY_DUR = 2.5

-- 编队采矿常量
GS.FLEET_MINE_INTERVAL = 2.0

-- 缩放限制
GS.ZOOM_MIN = 0.3
GS.ZOOM_MAX = 4.0

-- ============================================================================
-- 运行时状态（由 GalaxyScene 每帧同步）
-- ============================================================================
GS.vg       = nil
GS.screenW  = 800
GS.screenH  = 600

-- 相机
GS.camera   = { x=0, y=0 }
GS.zoom     = 1.0

-- 时间
GS.totalTime      = 0
GS.deepSpaceAnimT = 0
GS.routeAnimT     = 0

-- 数据列表
GS.bgStars           = {}
GS.starSystems       = {}
GS.deepSpaceSystems  = {}
GS.allPlanets        = {}
GS.colonizedPlanets  = {}
GS.priorityPlanetIds = {}
GS.garrisonedFleets  = {}
GS.colonyRipples     = {}
GS.specialPlanets    = {}
GS.fleetObjs         = {}
GS.asteroids         = {}
GS.expeditionPaths   = {}

-- 选中/悬停
GS.selectedPlanet    = nil
GS.hoveredPlanet     = nil
GS.hoveredAsteroid   = nil
GS.selectedFleetId   = nil
GS.mouseX            = 0
GS.mouseY            = 0

-- 外部引用
GS.fm                = nil   -- FleetManager
GS.player            = nil   -- PlayerProfile
GS.bs                = nil   -- BuildingSystem
GS.rm                = nil   -- ResourceManager
GS.pirateAI          = nil   -- PirateAI 引用
GS.seedShip          = nil   -- 种子飞船对象

-- 种子飞船输入
GS.seedClickTarget   = nil   -- { x, y } 点击移动目标
GS.keyDown           = { up=false, down=false, left=false, right=false }

-- 信号系统状态
GS.signalOpen        = false
GS.signalCooldowns   = {}
GS.signalBanners     = {}

-- 纹理句柄
GS.asteroidImgs      = {}
GS.imgSeedShip       = -1
GS.imgBaseStation    = -1

-- 外交
GS.diploRelData      = nil

-- 编队颜色缓存
GS.fleetColorCache   = {}

-- 地图变体
GS.mapVariant        = "NORMAL"

-- 种子码/形态（drawSeedLabel 使用）
GS.currentSeed       = nil   ---@type string|nil
GS.currentShape      = nil   ---@type string|nil

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 世界坐标 → 屏幕坐标
function GS.w2s(wx, wy)
    local cx = GS.screenW / 2
    local cy = GS.screenH / 2
    return (wx + GS.camera.x - cx) * GS.zoom + cx,
           (wy + GS.camera.y - cy) * GS.zoom + cy
end

--- 屏幕坐标 → 世界坐标
function GS.s2w(sx, sy)
    local cx = GS.screenW / 2
    local cy = GS.screenH / 2
    return (sx - cx) / GS.zoom - GS.camera.x + cx,
           (sy - cy) / GS.zoom - GS.camera.y + cy
end

--- 颜色数组→NanoVG RGBA
function GS.nvgColor(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or 255)
end

--- 两点距离
function GS.dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- 基于 seed 的轻量伪随机（LCG）
function GS.seededRand(seed, n)
    local s = (seed * 1664525 + 1013904223) % (2^32)
    return (s % n) + 1
end
function GS.seededRandF(seed)
    return ((seed * 1664525 + 1013904223) % (2^32)) / (2^32)
end

--- 获取编队主色（带缓存）
function GS.getFleetColor(fleetId)
    if GS.fleetColorCache[fleetId] then return GS.fleetColorCache[fleetId] end
    if not GS.fm then return {180,210,255} end
    local fl = GS.fm.fleets[fleetId]
    if not fl or #fl.ships == 0 then return {180,210,255} end
    local best, bestCount = fl.ships[1], 0
    for _, e in ipairs(fl.ships) do
        if e.count > bestCount then best = e; bestCount = e.count end
    end
    local st = SHIP_TYPES[best.shipType]
    local color = (st and st.color) or {180,210,255}
    GS.fleetColorCache[fleetId] = color
    return color
end

return GS
