-- ============================================================================
-- game/GalaxyScene.lua  -- 银河地图场景（渲染 + 逻辑）
-- ============================================================================

require "game.Systems"   -- 加载全局常量 SHIP_TYPES, SHIP_COSTS 等
local GalaxyScene = {}

-- PirateAI 引用（由 Init 注入）
local pirateAI_ = nil
local PIRATE_FLEET_SPEED = 55  -- 与 PirateAI.lua 保持一致，用于 ETA 计算

-- ============================================================================
-- 数据常量
-- ============================================================================
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
-- 按星球类型分配特征颜色，使视觉上可区分星球类型
local PLANET_TYPE_COLORS = {
    Terran        = {70,  160, 85 },   -- 绿色 = 宜居陆地
    Desert        = {200, 145, 55 },   -- 橙褐 = 荒漠
    Oceanic       = {40,  110, 210},   -- 深蓝 = 海洋
    Volcanic      = {185, 55,  40 },   -- 暗红 = 火山
    Barren        = {125, 115, 105},   -- 灰褐 = 荒芜
    ["Gas Giant"] = {155, 95,  210},   -- 紫色 = 气态巨星
}
local PLANET_TYPES  = {"Terran","Desert","Oceanic","Volcanic","Barren","Gas Giant"}
local SYSTEM_PREFIXES = {"Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta",
    "Iota","Kappa","Lambda","Mu","Nova","Psi","Omega"}
local SYSTEM_SUFFIXES = {"Centauri","Sirius","Vega","Lyra","Aquila","Crux","Ara","Corona",
    "Draco","Lupus","Orion","Proxima","Rigel","Antares","Polaris"}

-- 小地图常量
local MINIMAP_W   = 160
local MINIMAP_H   = 120
local MINIMAP_PAD = 10   -- 距右下角留白
local MINIMAP_WORLD_RANGE = 2100  -- 世界坐标半径（约 ±2000）

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_              = nil
local screenW_         = 800
local screenH_         = 600
local asteroidImgs_    = {}  -- { minerals=h, energy=h, crystal=h }
local imgSeedShip_     = -1  -- 种子飞船纹理句柄
local imgBaseStation_  = -1  -- 基地站纹理句柄

local starSystems_      = {}
local deepSpaceSystems_ = {}  -- 深空星系（曲速闸门解锁后可访问）
local allPlanets_       = {}  -- 缓存所有行星的平铺列表，generateStarSystems 时填充
local deepSpaceAnimT_   = 0   -- 深空脉冲动画计时器
local bgStars_         = {}
local camera_          = { x=0, y=0 }
local zoom_            = 1.0   -- 缩放比例
local isDragging_      = false
local dragStart_       = { x=0, y=0 }
local camAtDrag_       = { x=0, y=0 }
local dragDist_        = 0   -- 本次拖拽累计距离（像素）
local selectedPlanet_  = nil
local hoveredPlanet_   = nil   -- 当前鼠标悬停的行星
local hoveredAsteroid_ = nil   -- 当前鼠标悬停的小行星
local mouseX_          = 0
local mouseY_          = 0
local notifyFn_        = nil   -- 由 main.lua 注入的通知函数
local onPlanetSelect_  = nil   -- 回调：选中/取消选中行星
local onFleetSelect_             = nil   -- 回调：选中编队（传 fleetId 或 nil）
local onFleetContactPlanet_      = nil   -- 回调：编队（含探索舰）到达未殖民行星(fleetId, planet)
local onFleetContactPirateBase_  = nil   -- 回调：编队到达海盗基地坐标(fleetId, baseId)
local onFleetMove_               = nil   -- 回调：玩家发出编队移动指令
local bs_              = nil   -- BuildingSystem 引用（由 main.lua 注入）
local player_          = nil   -- PlayerProfile 引用
local rm_              = nil   -- ResourceManager 引用（挖矿产出）
local fm_              = nil   -- FleetManager 引用（由 Client.lua 注入）
local fleetColorCache_    = {}   -- [fleetId] = {r,g,b}，编队组成变化时失效
local colonizedPlanets_   = {}   -- 已殖民行星列表缓存，殖民事件时追加
-- ============================================================================
-- 编队地图对象（每个非空编队在地图上有坐标和移动状态）
-- ============================================================================
-- fleetObjs_[fleetId] = { x, y, targetX, targetY, angle, pulse, selected }
local fleetObjs_       = {}
local selectedFleetId_ = nil   -- 当前地图上选中的编队 id（nil=无）

-- 小行星
local asteroids_       = {}

-- 触摸状态（双指捏合缩放 + 单指拖拽）
local touches_         = {}   -- [touchID] = { x, y }（逻辑像素）
local pinchDist_       = nil  -- 上一帧双指间距



-- ============================================================================
-- 工具
-- ============================================================================
local function dist2(x1,y1,x2,y2)
    local dx,dy = x2-x1, y2-y1
    return math.sqrt(dx*dx+dy*dy)
end

local function randItem(t)
    return t[math.random(1,#t)]
end

local function nvgColor(c, a)
    return nvgRGBA(c[1], c[2], c[3], a or 255)
end

-- 世界坐标 → 屏幕坐标（带缩放）
local function w2s(wx, wy)
    local cx = screenW_ / 2
    local cy = screenH_ / 2
    return (wx + camera_.x - cx) * zoom_ + cx,
           (wy + camera_.y - cy) * zoom_ + cy
end

-- 屏幕坐标 → 世界坐标（带缩放）
local function s2w(sx, sy)
    local cx = screenW_ / 2
    local cy = screenH_ / 2
    return (sx - cx) / zoom_ - camera_.x + cx,
           (sy - cy) / zoom_ - camera_.y + cy
end

-- ============================================================================
-- 场景生成
-- ============================================================================
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

local function generateStarSystems()
    starSystems_ = {}
    for i = 1, 50 do
        local stype = randItem(STAR_TYPES)
        local name  = SYSTEM_PREFIXES[math.random(1,#SYSTEM_PREFIXES)] .. " "
                    .. SYSTEM_SUFFIXES[math.random(1,#SYSTEM_SUFFIXES)]
                    .. "-" .. i
        local x     = (math.random() - 0.5) * 4000
        local y     = (math.random() - 0.5) * 4000
        local sys   = {
            id=i, name=name, type=stype, x=x, y=y,
            radius = 12 + math.random() * 8,
            color  = STAR_COLORS[stype],
            planets= {},
        }
        local pCount = 2 + math.random(0, 5)
        for pi = 1, pCount do
            local ptype = randItem(PLANET_TYPES)
            -- 优先使用类型特征色，带随机微调（±15）使同类行星间有细微差异
            local baseColor = PLANET_TYPE_COLORS[ptype] or PLANET_COLORS[math.random(1,#PLANET_COLORS)]
            local pc = {
                math.max(0, math.min(255, baseColor[1] + math.random(-15, 15))),
                math.max(0, math.min(255, baseColor[2] + math.random(-15, 15))),
                math.max(0, math.min(255, baseColor[3] + math.random(-15, 15))),
            }
            sys.planets[pi] = {
                id=pi, system=sys,
                name      = name:sub(1,6) .. "-" .. string.char(96+pi),
                orbitRadius = 45 + (pi-1) * 32,
                angle       = math.random() * math.pi * 2,
                orbitSpeed  = (0.3 + math.random() * 0.5) * 0.2,
                size        = 5 + math.random() * 8,
                color       = pc,
                -- 预计算径向渐变高光/阴影颜色，避免每帧 math.min/max
                colorHL = { math.min(255,pc[1]+80), math.min(255,pc[2]+80), math.min(255,pc[3]+80) },
                colorSH = { math.max(0,pc[1]-40),   math.max(0,pc[2]-40),   math.max(0,pc[3]-40)  },
                ptype       = ptype,
                colonized   = false,
                owner       = nil,
                buildings   = {},
                constructing= nil,
                -- 屏幕坐标缓存（每帧渲染时更新，供点击检测用）
                _sx = nil, _sy = nil,
            }
        end
        starSystems_[i] = sys
    end

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

-- ============================================================================
-- 种子飞船（游戏起始阶段）
-- ============================================================================
local SEED_SPEED      = 300   -- 世界坐标/秒（未展开时移动速度）
local SEED_DEPLOY_DUR = 2.5   -- 展开动画时长（秒）

-- seedShip_.state:
--   "moving"    - 可移动，未展开
--   "deploying" - 展开动画播放中（不可操控）
--   "deployed"  - 展开完毕，位置固定，游戏正式开始
local seedShip_ = {
    x = 0, y = 0,        -- 世界坐标（Init 时随机设置）
    state = "moving",
    timer = 0,           -- 展开动画计时器
    angle = -math.pi/2,  -- 飞船朝向（弧度）
    pulse = 0,           -- 光晕脉冲计时器
    onDeploy = nil,      -- 展开完成回调（由 Client.lua 注入）
    -- === 基地模块建造（展开后作为可建造实体，兼容 renderPlanetPanel）===
    name        = "星航基地",
    ptype       = "基地",
    size        = 8,
    colonized   = false,      -- 展开后置为 true，解锁 canBuild
    buildings   = {},
    constructing= nil,
    coreLevel   = 1,          -- 基地核心等级（1~7），控制模块解锁
    color       = {80, 200, 255},
    isBase      = true,       -- 标记：这是基地而非行星
}

-- 键盘按下状态（由 GalaxyScene.OnKeyDown/Up 维护）
local keyDown_ = { up=false, down=false, left=false, right=false }

-- 点击移动目标（世界坐标）；nil = 无点击目标
local seedClickTarget_ = nil   -- { x, y }

-- ============================================================================
-- 编队采矿参数
-- ============================================================================
local FLEET_MINE_RANGE    = 30    -- 编队靠近多少距离开始采矿（世界坐标）
local FLEET_MINE_INTERVAL = 2.0   -- 每次采矿间隔（秒）

--- 计算编队中 ENGINEER 船的总数
local function countEngineersInFleet(fleetId)
    if not fm_ then return 0 end
    local fl = fm_.fleets[fleetId]
    if not fl then return 0 end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "ENGINEER" then return e.count end
    end
    return 0
end

--- 检查编队中是否含有探索舰
local function fleetHasExplorer(fleetId)
    if not fm_ then return false end
    local fl = fm_.fleets[fleetId]
    if not fl then return false end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "EXPLORER" and e.count > 0 then return true end
    end
    return false
end

--- 找到离坐标最近的未殖民行星（仅检查距离阈值内）
local PLANET_CONTACT_DIST = 80
local function findNearbyUncolonizedPlanet(wx, wy)
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            if not p.colonized and not p.isBase then
                local px = sys.x + math.cos(p.angle) * p.orbitRadius
                local py = sys.y + math.sin(p.angle) * p.orbitRadius
                if dist2(wx, wy, px, py) < PLANET_CONTACT_DIST then
                    return p
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- 渲染
-- ============================================================================
local function drawBackground()
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 6, 18, 255))
    nvgFill(vg_)

    -- 背景星点（视差 x0.08）
    for _, s in ipairs(bgStars_) do
        local sx = (s.x + camera_.x * 0.08) % (screenW_ + 100) - 50
        local sy = (s.y + camera_.y * 0.08) % (screenH_ + 100) - 50
        nvgBeginPath(vg_)
        nvgCircle(vg_, sx, sy, s.size * zoom_)
        nvgFillColor(vg_, nvgRGBA(255, 255, 255, math.floor(s.op or 100)))
        nvgFill(vg_)
    end
end

local function drawOrbitRing(sx, sy, radius)
    nvgBeginPath(vg_)
    nvgCircle(vg_, sx, sy, radius * zoom_)
    nvgStrokeColor(vg_, nvgRGBA(255, 255, 255, 15))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)
end

local function drawPlanet(sys, planet, sx, sy)
    local px = sx + math.cos(planet.angle) * planet.orbitRadius * zoom_
    local py = sy + math.sin(planet.angle) * planet.orbitRadius * zoom_

    -- 缓存屏幕坐标
    planet._sx = px
    planet._sy = py

    local ps = planet.size * zoom_

    -- 行星光晕（殖民后更亮）
    if planet.colonized then
        local glow = nvgRadialGradient(vg_, px, py, ps, ps*2.5,
            nvgRGBA(0,200,100,80), nvgRGBA(0,200,100,0))
        nvgBeginPath(vg_)
        nvgCircle(vg_, px, py, ps*2.5)
        nvgFillPaint(vg_, glow)
        nvgFill(vg_)
    end

    -- Hover 高亮
    if planet == hoveredPlanet_ and planet ~= selectedPlanet_ then
        nvgBeginPath(vg_)
        nvgCircle(vg_, px, py, ps + 4 * zoom_)
        nvgStrokeColor(vg_, nvgRGBA(200, 200, 255, 120))
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)
    end

    -- 行星本体（径向渐变，颜色已在生成时预算，无需每帧 min/max）
    local hl   = planet.colorHL
    local sh   = planet.colorSH
    local grad = nvgRadialGradient(vg_,
        px - ps*0.35, py - ps*0.35, ps*0.15, ps*1.2,
        nvgRGBA(hl[1], hl[2], hl[3], 255),
        nvgRGBA(sh[1], sh[2], sh[3], 255))
    nvgBeginPath(vg_)
    nvgCircle(vg_, px, py, ps)
    nvgFillPaint(vg_, grad)
    nvgFill(vg_)

    -- 殖民旗帜指示点
    if planet.colonized then
        nvgBeginPath(vg_)
        nvgCircle(vg_, px, py - ps - 5 * zoom_, 3 * zoom_)
        nvgFillColor(vg_, nvgRGBA(50, 255, 100, 220))
        nvgFill(vg_)
    end

    -- 缩放足够大时显示行星名
    if zoom_ >= 1.4 then
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, math.max(8, 9 * zoom_))
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(200, 220, 255, 160))
        nvgText(vg_, px, py + ps + 2, planet.name)
    end

    -- 选中高亮圆环
    if planet == selectedPlanet_ then
        nvgBeginPath(vg_)
        nvgCircle(vg_, px, py, ps + 5 * zoom_)
        nvgStrokeColor(vg_, nvgRGBA(255, 220, 50, 200))
        nvgStrokeWidth(vg_, 2)
        nvgStroke(vg_)
        nvgBeginPath(vg_)
        nvgCircle(vg_, px, py, ps + 9 * zoom_)
        nvgStrokeColor(vg_, nvgRGBA(255, 220, 50, 80))
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
    end
end

local function drawStarSystem(sys)
    local sx, sy = w2s(sys.x, sys.y)
    -- 视锥剔除（粗略）
    local maxRadius = (45 + 5 * 32 + 20) * zoom_
    if sx < -maxRadius or sx > screenW_ + maxRadius
    or sy < -maxRadius or sy > screenH_ + maxRadius then
        for _, p in ipairs(sys.planets) do p._sx=nil; p._sy=nil end
        return
    end

    -- 轨道圆
    for _, p in ipairs(sys.planets) do
        drawOrbitRing(sx, sy, p.orbitRadius)
    end

    -- 恒星光晕
    local c    = sys.color
    local sr   = sys.radius * zoom_
    local glow = nvgRadialGradient(vg_, sx, sy, 0, sr * 2.5,
        nvgRGBA(c[1],c[2],c[3], 160), nvgRGBA(c[1],c[2],c[3], 0))
    nvgBeginPath(vg_)
    nvgCircle(vg_, sx, sy, sr * 2.5)
    nvgFillPaint(vg_, glow)
    nvgFill(vg_)

    -- 恒星本体
    nvgBeginPath(vg_)
    nvgCircle(vg_, sx, sy, sr)
    nvgFillColor(vg_, nvgColor(c, 255))
    nvgFill(vg_)

    -- 行星
    for _, p in ipairs(sys.planets) do
        drawPlanet(sys, p, sx, sy)
    end

    -- 恒星名称
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, math.max(8, 10 * zoom_))
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg_, nvgRGBA(200, 200, 220, 140))
    nvgText(vg_, sx, sy + sr + 4, sys.name)
end

--- 渲染深空星系（曲速闸门未解锁时显示锁定状态，解锁后显示蓝紫色高亮）
local function drawDeepSpaceSystem(sys, animT)
    local sx, sy = w2s(sys.x, sys.y)
    local maxRadius = (50 + 6 * 36 + 20) * zoom_
    if sx < -maxRadius or sx > screenW_ + maxRadius
    or sy < -maxRadius or sy > screenH_ + maxRadius then
        for _, p in ipairs(sys.planets) do p._sx=nil; p._sy=nil end
        return
    end

    local hasGate = rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGate
    local pulse   = 0.5 + 0.5 * math.sin(animT * 2.5 + sys.id * 0.7)

    if not hasGate then
        -- 锁定状态：灰色虚线轮廓 + 问号
        local sr = sys.radius * zoom_
        nvgBeginPath(vg_)
        nvgCircle(vg_, sx, sy, sr * 1.8)
        nvgStrokeColor(vg_, nvgRGBA(80, 80, 120, 80))
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
        nvgBeginPath(vg_)
        nvgCircle(vg_, sx, sy, sr)
        nvgFillColor(vg_, nvgRGBA(40, 40, 60, 180))
        nvgFill(vg_)
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, math.max(9, 11 * zoom_))
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(80, 80, 140, 160))
        nvgText(vg_, sx, sy, "?")
        if zoom_ >= 0.9 then
            nvgFontSize(vg_, math.max(7, 8 * zoom_))
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg_, nvgRGBA(80, 80, 140, 100))
            nvgText(vg_, sx, sy + sr + 3, "需要曲速闸门")
        end
        return
    end

    -- 解锁状态：蓝紫色脉冲光晕
    local sr   = sys.radius * zoom_
    local gAlpha = math.floor(80 + 60 * pulse)
    local glowPaint = nvgRadialGradient(vg_, sx, sy, 0, sr * 3.5,
        nvgRGBA(120, 60, 255, gAlpha), nvgRGBA(120, 60, 255, 0))
    nvgBeginPath(vg_)
    nvgCircle(vg_, sx, sy, sr * 3.5)
    nvgFillPaint(vg_, glowPaint)
    nvgFill(vg_)

    -- 轨道圆（蓝紫色）
    for _, p in ipairs(sys.planets) do
        nvgBeginPath(vg_)
        nvgCircle(vg_, sx, sy, p.orbitRadius * zoom_)
        nvgStrokeColor(vg_, nvgRGBA(100, 60, 200, 20))
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
    end

    -- 恒星本体（蓝紫色）
    nvgBeginPath(vg_)
    nvgCircle(vg_, sx, sy, sr)
    nvgFillColor(vg_, nvgRGBA(120, 60, 255, 220))
    nvgFill(vg_)
    -- 脉冲外环
    nvgBeginPath(vg_)
    nvgCircle(vg_, sx, sy, sr + 4 * zoom_ * pulse)
    nvgStrokeColor(vg_, nvgRGBA(160, 100, 255, math.floor(180 * pulse)))
    nvgStrokeWidth(vg_, 1.5)
    nvgStroke(vg_)

    -- ⚡ 标记
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, math.max(10, 12 * zoom_))
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(200, 160, 255, 220))
    nvgText(vg_, sx, sy, "⚡")

    -- 行星
    for _, p in ipairs(sys.planets) do
        drawPlanet(sys, p, sx, sy)
    end

    -- 系统名称
    if zoom_ >= 0.7 then
        nvgFontSize(vg_, math.max(8, 9 * zoom_))
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(180, 140, 255, 180))
        nvgText(vg_, sx, sy + sr + 4, "⚡" .. sys.name)
    end
end

-- ============================================================================
-- Hover Tooltip 渲染
-- ============================================================================
-- 通用 tooltip 绘制：lines[1] 为标题，其余为正文；titleColor 可选
local function drawTooltipBox(cx, cy, lines, titleColor, borderColor)
    titleColor  = titleColor  or {255, 220, 80}
    borderColor = borderColor or {100, 160, 255}
    local tw = 170
    local th = 14 * #lines + 12
    local tx = cx + 14
    local ty = cy - th / 2
    if tx + tw > screenW_ - 10 then tx = cx - tw - 14 end
    if ty < 60 then ty = 60 end
    if ty + th > screenH_ - 10 then ty = screenH_ - th - 10 end

    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, tx, ty, tw, th, 5)
    nvgFillColor(vg_, nvgRGBA(5, 10, 22, 235))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], 160))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    for i, line in ipairs(lines) do
        local ly = ty + 6 + (i-1) * 14
        if i == 1 then
            nvgFontSize(vg_, 12)
            nvgFillColor(vg_, nvgRGBA(titleColor[1], titleColor[2], titleColor[3], 255))
        else
            nvgFontSize(vg_, 10)
            nvgFillColor(vg_, nvgRGBA(180, 210, 255, 200))
        end
        nvgText(vg_, tx + 7, ly, line)
    end
end

local function drawTooltip(planet)
    if not planet then return end
    local px, py = planet._sx, planet._sy
    if not px then return end

    local lines = {}
    lines[1] = planet.name
    lines[2] = planet.ptype .. " 行星"
    if planet.colonized then
        local bCnt = #planet.buildings
        lines[#lines+1] = "已探索  ·  建筑: " .. bCnt .. " 座"
        -- 列出前 3 座建筑名称
        for i = 1, math.min(3, bCnt) do
            local b = planet.buildings[i]
            local bInfo = BUILDINGS[b.key]
            local bName = bInfo and bInfo.name or b.key
            local lvlStr = (b.level and b.level > 1) and (" Lv"..b.level) or ""
            lines[#lines+1] = "  · " .. bName .. lvlStr
        end
        if bCnt > 3 then
            lines[#lines+1] = "  … 共 " .. bCnt .. " 座"
        end
        if planet.constructing then
            local job = planet.constructing
            local pct = math.floor((job.progress or 0) * 100)
            local jInfo = BUILDINGS[job.key]
            lines[#lines+1] = "建造中: " .. (jInfo and jInfo.name or job.key) .. " " .. pct .. "%"
        end
    else
        lines[#lines+1] = "未探索  ·  点击探索"
    end

    drawTooltipBox(px, py, lines, {255,220,80}, {100,160,255})
end

local function drawAsteroidTooltip(a)
    if not a then return end
    local sx, sy = w2s(a.x, a.y)
    local cfg    = ASTEROID_TYPES[a.atype]
    local szCfg  = a.sizeKey and ASTEROID_SIZES[a.sizeKey]
    local hpPct  = math.floor((a.hp / a.maxHP) * 100)
    local c      = cfg.color

    local lines = {}
    lines[1] = (szCfg and szCfg.label or "") .. cfg.label .. "小行星"
    lines[2] = "资源: " .. cfg.label
    lines[3] = "产出: " .. math.floor(a.yield) .. " /次"
    lines[4] = string.format("耐久: %d / %d  (%d%%)", a.hp, a.maxHP, hpPct)
    -- 密度：按 yield*hpPct 换算成视觉直观的百分比（以大型满血为100%）
    local densityMax = 90  -- ASTEROID_SIZES.large.yieldMax
    local density = math.min(100, math.floor(a.yield / densityMax * hpPct))
    lines[5] = "矿石密度: " .. density .. "%"

    drawTooltipBox(sx, sy, lines, {c[1]+60, c[2]+60, c[3]+60}, {c[1], c[2], c[3]})
end

-- ============================================================================
-- 海盗进攻预警 HUD
-- ============================================================================
local function drawPirateWarningHUD()
    if not pirateAI_ or #pirateAI_.fleets == 0 then return end

    local fleets = pirateAI_.fleets
    local count  = #fleets
    local w      = 240
    local h      = 22 + count * 20 + 8
    local px     = screenW_ - w - 12
    local py     = 120  -- 顶部偏下，避免遮住其他 HUD

    -- 面板背景
    local bg = nvgLinearGradient(vg_, px, py, px, py + h,
        nvgRGBA(120, 10, 10, 200), nvgRGBA(60, 0, 0, 180))
    nvgBeginPath(vg_); nvgRoundedRect(vg_, px, py, w, h, 6)
    nvgFillPaint(vg_, bg); nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(220, 60, 60, 200))
    nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 13)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(255, 80, 80, 255))
    nvgText(vg_, px + w/2, py + 12, "⚠ 海盗来袭")

    -- 每条舰队信息
    for i, fl in ipairs(fleets) do
        local iy = py + 22 + (i-1) * 20

        -- 计算距离目标的剩余路程
        local dx  = fl.targetX - fl.x
        local dy  = fl.targetY - fl.y
        local rem = math.sqrt(dx*dx + dy*dy)
        local eta = rem / PIRATE_FLEET_SPEED  -- 估计剩余秒数

        -- 进度条：已走距离 / 总距离（粗略估算：以基地到目标总距离为基准）
        -- 用 eta 来做百分比（最大假设 300 秒全程）
        local progress = math.max(0.05, math.min(0.95, 1 - eta / 300))

        -- 底部进度条轨道
        local barX = px + 10
        local barW = w - 20
        nvgBeginPath(vg_); nvgRect(vg_, barX, iy + 8, barW, 4)
        nvgFillColor(vg_, nvgRGBA(60, 0, 0, 160)); nvgFill(vg_)
        -- 进度
        nvgBeginPath(vg_); nvgRect(vg_, barX, iy + 8, barW * progress, 4)
        local r = math.floor(200 + progress * 55)
        nvgFillColor(vg_, nvgRGBA(r, 60, 40, 220)); nvgFill(vg_)

        -- 文字
        nvgFontSize(vg_, 11)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(255, 180, 140, 230))
        local etaStr = eta > 0 and string.format("~%ds", math.ceil(eta)) or "即将到达!"
        nvgText(vg_, barX, iy + 3,
            string.format("Lv%d → %s  %s", fl.pirateLevel, fl.targetName, etaStr))
    end
end

-- ============================================================================
-- 小地图渲染
-- ============================================================================
local function drawMinimap()
    local mx = screenW_  - MINIMAP_W - MINIMAP_PAD
    local my = screenH_  - MINIMAP_H - MINIMAP_PAD

    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, mx, my, MINIMAP_W, MINIMAP_H, 4)
    nvgFillColor(vg_, nvgRGBA(0, 6, 18, 200))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(68, 100, 200, 120))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg_, nvgRGBA(100, 160, 255, 160))
    nvgText(vg_, mx + 4, my + 2, "星区总览")

    -- 缩放因子：世界 ±MINIMAP_WORLD_RANGE → minimap 像素
    local scaleX = (MINIMAP_W - 8)  / (MINIMAP_WORLD_RANGE * 2)
    local scaleY = (MINIMAP_H - 14) / (MINIMAP_WORLD_RANGE * 2)
    local offX   = mx + 4 + (MINIMAP_W - 8)  / 2
    local offY   = my + 12 + (MINIMAP_H - 14) / 2

    -- 绘制恒星系（白点，殖民系显绿）
    for _, sys in ipairs(starSystems_) do
        local bx = offX + sys.x * scaleX
        local by = offY + sys.y * scaleY
        -- 检查该系统是否有殖民行星
        local hasColony = false
        for _, p in ipairs(sys.planets) do
            if p.colonized then hasColony = true; break end
        end
        nvgBeginPath(vg_)
        nvgCircle(vg_, bx, by, hasColony and 2.5 or 1.2)
        if hasColony then
            nvgFillColor(vg_, nvgRGBA(50, 220, 100, 220))
        else
            nvgFillColor(vg_, nvgRGBA(180, 180, 200, 100))
        end
        nvgFill(vg_)
    end

    -- 基地（种子飞船）标记
    local ss = seedShip_
    local sbx = offX + ss.x * scaleX
    local sby = offY + ss.y * scaleY
    if ss.state == "deployed" or ss.colonized then
        -- 展开后：绿色脉冲圆圈高亮
        local pulse = 0.6 + 0.4 * math.abs(math.sin(ss.pulse or 0))
        -- 外圈发光
        local baseGlow = nvgRadialGradient(vg_, sbx, sby, 4, 10,
            nvgRGBA(0, 220, 120, math.floor(120 * pulse)),
            nvgRGBA(0, 220, 120, 0))
        nvgBeginPath(vg_); nvgCircle(vg_, sbx, sby, 10)
        nvgFillPaint(vg_, baseGlow); nvgFill(vg_)
        -- 外圆环（脉冲）
        nvgBeginPath(vg_); nvgCircle(vg_, sbx, sby, 5 * pulse)
        nvgStrokeColor(vg_, nvgRGBA(0, 255, 140, math.floor(220 * pulse)))
        nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)
        -- 实心核心点
        nvgBeginPath(vg_); nvgCircle(vg_, sbx, sby, 3)
        nvgFillColor(vg_, nvgRGBA(0, 255, 140, 255)); nvgFill(vg_)
        -- 四条短对角线（十字准星）
        local cs = 5
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, sbx - cs, sby); nvgLineTo(vg_, sbx - 2, sby)
        nvgMoveTo(vg_, sbx + 2, sby); nvgLineTo(vg_, sbx + cs, sby)
        nvgMoveTo(vg_, sbx, sby - cs); nvgLineTo(vg_, sbx, sby - 2)
        nvgMoveTo(vg_, sbx, sby + 2); nvgLineTo(vg_, sbx, sby + cs)
        nvgStrokeColor(vg_, nvgRGBA(0, 255, 140, 200))
        nvgStrokeWidth(vg_, 1); nvgStroke(vg_)
        -- 标签
        nvgFontFace(vg_, "sans"); nvgFontSize(vg_, 8)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(0, 255, 140, 200))
        nvgText(vg_, sbx, sby + 6, "基地")
    else
        -- 未展开：蓝色小三角形（飞船方向指示）
        nvgSave(vg_)
        nvgTranslate(vg_, sbx, sby)
        nvgRotate(vg_, ss.angle)
        nvgBeginPath(vg_)
        nvgMoveTo(vg_,  4, 0); nvgLineTo(vg_, -2.5, -2); nvgLineTo(vg_, -2.5, 2)
        nvgClosePath(vg_)
        nvgFillColor(vg_, nvgRGBA(80, 180, 255, 220)); nvgFill(vg_)
        nvgRestore(vg_)
    end

    -- 视口矩形（当前屏幕可见区域）
    local cx = screenW_ / 2
    local cy = screenH_ / 2
    -- 当前屏幕左上角在世界中的位置
    local wLeft  = (0  - cx) / zoom_ - camera_.x + cx
    local wTop   = (60 - cy) / zoom_ - camera_.y + cy
    local wRight = (screenW_ - cx) / zoom_ - camera_.x + cx
    local wBot   = (screenH_ - cy) / zoom_ - camera_.y + cy

    local vx1 = offX + wLeft  * scaleX
    local vy1 = offY + wTop   * scaleY
    local vx2 = offX + wRight * scaleX
    local vy2 = offY + wBot   * scaleY

    nvgBeginPath(vg_)
    nvgRect(vg_, vx1, vy1, vx2-vx1, vy2-vy1)
    nvgStrokeColor(vg_, nvgRGBA(255, 220, 50, 160))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    -- 深空星系（小地图紫色点，锁定时极暗）
    local hasGateMap = rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGate
    for _, sys in ipairs(deepSpaceSystems_) do
        local bx = offX + sys.x * scaleX
        local by = offY + sys.y * scaleY
        nvgBeginPath(vg_)
        nvgCircle(vg_, bx, by, 1.5)
        if hasGateMap then
            -- 已解锁：亮紫色
            local hasColonyDS = false
            for _, p in ipairs(sys.planets) do
                if p.colonized then hasColonyDS = true; break end
            end
            nvgFillColor(vg_, hasColonyDS and nvgRGBA(200, 100, 255, 220) or nvgRGBA(140, 80, 255, 180))
        else
            -- 未解锁：极暗紫灰色
            nvgFillColor(vg_, nvgRGBA(60, 40, 100, 60))
        end
        nvgFill(vg_)
    end

    -- 海盗基地和舰队（小地图标注）
    if pirateAI_ then pirateAI_:renderMinimap(vg_, offX, offY, scaleX, scaleY) end

    -- 缩放比例标注
    nvgFontSize(vg_, 8)
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg_, nvgRGBA(130, 150, 200, 150))
    nvgText(vg_, mx + MINIMAP_W - 3, my + MINIMAP_H - 2,
        string.format("x%.1f | 滚轮缩放", zoom_))
end

-- drawTitleBar 已移至 GameUI.RenderSceneTitle，此处删除避免重叠

-- ============================================================================
-- 逻辑更新
-- ============================================================================
local function updatePlanets(dt)
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            p.angle = p.angle + p.orbitSpeed * dt
        end
    end
    -- 深空行星轨道（慢速，0.6× 标准速度）
    for _, sys in ipairs(deepSpaceSystems_) do
        for _, p in ipairs(sys.planets) do
            p.angle = p.angle + p.orbitSpeed * dt * 0.6
        end
    end
end

local function updateHover()
    hoveredPlanet_   = nil
    hoveredAsteroid_ = nil
    -- 先检测行星（优先级高）
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            if p._sx and dist2(mouseX_, mouseY_, p._sx, p._sy) < (p.size * zoom_ + 10) then
                hoveredPlanet_ = p
                return
            end
        end
    end
    -- 深空行星（仅解锁后可 hover）
    local hasGate = rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGate
    if hasGate then
        for _, sys in ipairs(deepSpaceSystems_) do
            for _, p in ipairs(sys.planets) do
                if p._sx and dist2(mouseX_, mouseY_, p._sx, p._sy) < (p.size * zoom_ + 10) then
                    hoveredPlanet_ = p
                    return
                end
            end
        end
    end
    -- 再检测小行星
    for _, a in ipairs(asteroids_) do
        if a.hp and a.hp > 0 then
            local sx, sy = w2s(a.x, a.y)
            local r = a.size * zoom_ + 6
            if dist2(mouseX_, mouseY_, sx, sy) < r then
                hoveredAsteroid_ = a
                return
            end
        end
    end
end

-- ============================================================================
-- 点击检测
-- ============================================================================
--- 执行殖民（由 GameUI 殖民按钮回调触发，已通过费用检验）
--- 返回升级数据（level, rank, rewards）供调用方处理奖励通知
function GalaxyScene.Colonize(planet)
    if not planet or planet.colonized then return end
    planet.colonized = true
    planet.owner     = "player"
    colonizedPlanets_[#colonizedPlanets_+1] = planet   -- 维护殖民缓存
    local leveled, newLevel, newRank, rewards
    if player_ then
        player_.colonized = (player_.colonized or 0) + 1
        leveled, newLevel, newRank, rewards = player_:addExp(100)
    end
    if bs_ then
        bs_:build("MINE", planet)
    end
    print("[Galaxy] 殖民: " .. planet.name)
    return leveled, newLevel, newRank, rewards
end

-- 尝试点击小行星，返回是否命中
local tryClickFleet        -- 前向声明（定义在编队模块区域）
local getOrCreateFleetObj  -- 前向声明（定义在编队模块区域）

local function tryClickAsteroid(mx, my)
    for _, a in ipairs(asteroids_) do
        if a.hp > 0 then
            local sx, sy = w2s(a.x, a.y)
            local r = (a.size + 8) * zoom_   -- 点击容差
            if dist2(mx, my, sx, sy) < r then
                -- 有选中编队且编队含工程舰 → 指派该编队前往采矿
                if selectedFleetId_ then
                    local engCount = countEngineersInFleet(selectedFleetId_)
                    if engCount > 0 then
                        local obj = getOrCreateFleetObj(selectedFleetId_)
                        obj.targetX      = a.x
                        obj.targetY      = a.y
                        obj.miningTarget = a
                        obj.mineTimer    = 0
                        if notifyFn_ then
                            local cfg   = ASTEROID_TYPES[a.atype]
                            local szLbl = a.sizeKey and ASTEROID_SIZES[a.sizeKey] and ASTEROID_SIZES[a.sizeKey].label or ""
                            notifyFn_("编队→" .. szLbl .. cfg.label .. "小行星（" .. engCount .. " 艘工程舰）", "success")
                        end
                    else
                        if notifyFn_ then
                            notifyFn_("编队无工程舰，无法采矿", "warning")
                        end
                    end
                else
                    if notifyFn_ then
                        notifyFn_("请先选中含工程舰的编队，再点击小行星", "info")
                    end
                end
                return true
            end
        end
    end
    return false
end

local function handleClick(mx, my)
    -- 种子飞船未展开时：点击地图空白处设置移动目标
    if seedShip_.state == "moving" then
        local wx, wy = s2w(mx, my)
        seedClickTarget_ = { x = wx, y = wy }
        return
    end

    -- 优先检测小行星点击（挖矿船指派）
    if tryClickAsteroid(mx, my) then return end

    -- 检测编队图标点击
    if tryClickFleet(mx, my) then return end

    -- 检测海盗基地点击
    if pirateAI_ then
        for _, base in ipairs(pirateAI_.bases) do
            if base.active then
                local bsx, bsy = w2s(base.x, base.y)
                if dist2(mx, my, bsx, bsy) < 30 then
                    if selectedFleetId_ then
                        -- 有选中编队：派编队前往突袭
                        local obj = fleetObjs_[selectedFleetId_]
                        if obj then
                            obj.targetX          = base.x
                            obj.targetY          = base.y
                            obj.pirateBaseTarget = base.id
                        end
                        if notifyFn_ then
                            notifyFn_(string.format(
                                "编队 #%d 前往突袭海盗基地 Lv%d", selectedFleetId_, base.level), "info")
                        end
                    else
                        -- 无编队选中：显示基地情报
                        if notifyFn_ then
                            local atStr = base.attackTimer > 0
                                and string.format("%ds后进攻", math.ceil(base.attackTimer))
                                or  "出击中!"
                            notifyFn_(string.format(
                                "海盗基地 #%d  等级:%d  HP:%d/%d  %s",
                                base.id, base.level, base.hp, base.maxHp, atStr), "info")
                        end
                    end
                    return
                end
            end
        end
    end

    -- 检测基地点击（已展开的种子飞船）
    if seedShip_.state == "deployed" then
        local bsx, bsy = w2s(seedShip_.x, seedShip_.y)
        if dist2(mx, my, bsx, bsy) < 28 then
            selectedFleetId_ = nil  -- 点击基地时取消编队选中
            selectedPlanet_ = seedShip_
            if onPlanetSelect_ then onPlanetSelect_(seedShip_) end
            return
        end
    end

    -- 检测行星点击
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            if p._sx and dist2(mx, my, p._sx, p._sy) < (p.size * zoom_ + 12) then
                -- M4: 无论编队是否选中，都先显示行星信息
                selectedPlanet_ = p
                if onPlanetSelect_ then onPlanetSelect_(p) end
                -- 若同时有选中编队：额外将编队移动到该行星轨道附近
                if selectedFleetId_ then
                    local obj = fleetObjs_[selectedFleetId_]
                    if obj then
                        local wx = sys.x + math.cos(p.angle) * p.orbitRadius
                        local wy = sys.y + math.sin(p.angle) * p.orbitRadius
                        obj.targetX = wx + (math.random()-0.5)*40
                        obj.targetY = wy + (math.random()-0.5)*40
                        if onFleetMove_ then onFleetMove_() end
                    end
                end
                return
            end
        end
    end
    -- 深空行星点击（仅解锁后可交互）
    do
        local hasGate = rm_ and rm_.baseBonus and rm_.baseBonus.hasWarpGate
        if hasGate then
            for _, sys in ipairs(deepSpaceSystems_) do
                for _, p in ipairs(sys.planets) do
                    if p._sx and dist2(mx, my, p._sx, p._sy) < (p.size * zoom_ + 12) then
                        selectedPlanet_ = p
                        if onPlanetSelect_ then onPlanetSelect_(p) end
                        if selectedFleetId_ then
                            local obj = fleetObjs_[selectedFleetId_]
                            if obj then
                                local wx = sys.x + math.cos(p.angle) * p.orbitRadius
                                local wy = sys.y + math.sin(p.angle) * p.orbitRadius
                                obj.targetX = wx + (math.random()-0.5)*40
                                obj.targetY = wy + (math.random()-0.5)*40
                                if onFleetMove_ then onFleetMove_() end
                            end
                        end
                        return
                    end
                end
            end
        end
    end

    -- 点空地：若有选中编队则设置编队移动目标，否则取消行星选中
    if selectedFleetId_ then
        local obj = fleetObjs_[selectedFleetId_]
        if obj then
            local wx, wy = s2w(mx, my)
            obj.targetX = wx
            obj.targetY = wy
            if onFleetMove_ then onFleetMove_() end
        end
        return
    end
    selectedPlanet_ = nil
    if onPlanetSelect_ then onPlanetSelect_(nil) end
end

-- ============================================================================
-- 公共接口
-- ============================================================================
function GalaxyScene.Init(opts)
    vg_           = opts.vg
    bs_           = opts.bs
    rm_           = opts.rm
    fm_           = opts.fm
    player_       = opts.player
    notifyFn_     = opts.notifyFn
    onPlanetSelect_       = opts.onPlanetSelect
    onFleetSelect_            = opts.onFleetSelect
    onFleetContactPlanet_     = opts.onFleetContactPlanet
    onFleetContactPirateBase_ = opts.onFleetContactPirateBase
    onFleetMove_              = opts.onFleetMove
    -- 海盗 AI（可选）
    pirateAI_     = opts.pirateAI
    -- 加载所有游戏纹理
    local f = NVG_IMAGE_PREMULTIPLIED
    asteroidImgs_["minerals"] = nvgCreateImage(vg_, "image/asteroid_minerals_20260511190702.png", f)
    asteroidImgs_["energy"]   = nvgCreateImage(vg_, "image/asteroid_energy_20260511190703.png",   f)
    asteroidImgs_["crystal"]  = nvgCreateImage(vg_, "image/asteroid_crystal_20260511190707.png",  f)
    imgSeedShip_    = nvgCreateImage(vg_, "image/ship_seed_20260511190720.png",       f)
    imgBaseStation_ = nvgCreateImage(vg_, "image/base_station_20260511190708.png",    f)
    generateBgStars()
    generateStarSystems()
    generateAsteroids()
    -- 生成海盗基地（世界半径 2000）
    if pirateAI_ then pirateAI_:generateBases(2000) end
    local dpr = graphics:GetDPR()
    screenW_  = graphics:GetWidth()  / dpr
    screenH_  = graphics:GetHeight() / dpr

    -- 种子飞船：随机落点（世界坐标 ±1500 范围）
    seedShip_.x       = (math.random() - 0.5) * 3000
    seedShip_.y       = (math.random() - 0.5) * 3000
    seedShip_.state   = "moving"
    seedShip_.timer   = 0
    seedShip_.angle   = -math.pi / 2
    seedShip_.pulse   = 0
    seedShip_.onDeploy = opts.onSeedDeploy  -- 可选回调

    -- 相机初始跟随飞船
    camera_.x = screenW_ / 2 - seedShip_.x
    camera_.y = screenH_ / 2 - seedShip_.y
    zoom_     = 1.0

    -- 编队地图对象：初始出现在基地旁边（若未展开则在种子飞船附近）
    fleetObjs_       = {}
    selectedFleetId_ = nil

    print("[GalaxyScene] 初始化完成, 恒星系数: " .. #starSystems_
        .. ", 小行星: " .. #asteroids_
        .. string.format(", 种子飞船落点(%.0f, %.0f)", seedShip_.x, seedShip_.y))
end



--- 获取所有行星列表（动态，包含新殖民的行星）
function GalaxyScene.GetAllPlanets()
    return allPlanets_   -- 直接返回缓存引用，零 table 分配
end

--- 获取已殖民行星列表（缓存，Colonize/LoadSaveData 时维护）
function GalaxyScene.GetColonizedPlanets()
    return colonizedPlanets_
end

function GalaxyScene.GetSelected()
    return selectedPlanet_
end

local function drawAsteroids()
    for _, a in ipairs(asteroids_) do
        if a.hp <= 0 then goto continue end
        local sx, sy = w2s(a.x, a.y)
        -- 视锥裁剪
        if sx < -20 or sx > screenW_+20 or sy < -20 or sy > screenH_+20 then
            goto continue
        end
        local r  = a.size * zoom_
        local cfg = ASTEROID_TYPES[a.atype]
        local c  = cfg.color
        -- 耐久度影响透明度
        local hpPct = a.hp / a.maxHP
        local alpha = math.floor(120 + 100 * hpPct)
        -- 旋转渲染小行星图片
        nvgSave(vg_)
        nvgTranslate(vg_, sx, sy)
        nvgRotate(vg_, a.angle)
        local imgH = asteroidImgs_[a.atype]
        if imgH and imgH >= 0 then
            local half = r * 1.4
            nvgGlobalAlpha(vg_, alpha / 255)
            local paint = nvgImagePattern(vg_, -half, -half, half*2, half*2, 0, imgH, 1.0)
            nvgBeginPath(vg_); nvgRect(vg_, -half, -half, half*2, half*2)
            nvgFillPaint(vg_, paint); nvgFill(vg_)
            nvgGlobalAlpha(vg_, 1.0)
        else
            -- 回退：六边形
            nvgBeginPath(vg_)
            for k = 0, 5 do
                local theta = k * math.pi / 3
                local jitter = 1 + (k % 2) * 0.3
                local px2 = math.cos(theta) * r * jitter
                local py2 = math.sin(theta) * r * jitter
                if k == 0 then nvgMoveTo(vg_, px2, py2) else nvgLineTo(vg_, px2, py2) end
            end
            nvgClosePath(vg_)
            nvgFillColor(vg_, nvgRGBA(c[1], c[2], c[3], alpha))
            nvgFill(vg_)
        end
        nvgRestore(vg_)
        -- 选中编队的采矿目标高亮（脉冲圆环）
        local selMining = selectedFleetId_ and fleetObjs_[selectedFleetId_]
            and fleetObjs_[selectedFleetId_].miningTarget
        if a == selMining then
            nvgBeginPath(vg_)
            nvgCircle(vg_, sx, sy, r * 1.6)
            nvgStrokeColor(vg_, nvgRGBA(255, 255, 80, 180))
            nvgStrokeWidth(vg_, 1.5)
            nvgStroke(vg_)
        end
        -- 大型小行星额外光晕（强调珍贵）
        if a.sizeKey == "large" then
            nvgBeginPath(vg_)
            nvgCircle(vg_, sx, sy, r * 1.5)
            nvgStrokeColor(vg_, nvgRGBA(c[1], c[2], c[3], 50))
            nvgStrokeWidth(vg_, 2)
            nvgStroke(vg_)
        end
        -- 缩放足够大时显示资源标签（含尺寸前缀）
        if zoom_ > 0.9 then
            local szCfg   = ASTEROID_SIZES[a.sizeKey or "medium"]
            local sizeLabel = szCfg and szCfg.label or ""
            nvgFontFace(vg_, "sans")
            nvgFontSize(vg_, 9 * zoom_)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg_, nvgRGBA(c[1], c[2], c[3], 200))
            nvgText(vg_, sx, sy + r + 2, sizeLabel .. cfg.label)
        end
        ::continue::
    end
end

-- ============================================================================
-- 编队地图对象管理
-- ============================================================================
local FLEET_ARRIVE_RADIUS = 25   -- 编队到达判定半径（世界坐标）
local FLEET_ICON_RADIUS   = 14   -- 编队图标点击半径（屏幕像素）

--- 获取或创建编队地图对象（懒初始化）
getOrCreateFleetObj = function(fleetId)
    if fleetObjs_[fleetId] then return fleetObjs_[fleetId] end
    -- 按编队编号均匀分布在基地外围，避免堆叠
    local maxF   = fm_ and fm_.maxFleets or 4
    local angle  = (fleetId - 1) / maxF * math.pi * 2
    local radius = 220 + math.random() * 60   -- 距基地 220~280
    local bx = seedShip_.x + math.cos(angle) * radius
    local by = seedShip_.y + math.sin(angle) * radius
    fleetObjs_[fleetId] = {
        x       = bx,
        y       = by,
        targetX = nil,
        targetY = nil,
        angle   = angle + math.pi,   -- 朝向基地
        pulse   = math.random() * math.pi * 2,
    }
    return fleetObjs_[fleetId]
end

--- 获取编队最慢舰船速度（决定移动速度）
local function getFleetSpeed(fleetId)
    if not fm_ then return 80 end
    local fl = fm_.fleets[fleetId]
    if not fl or #fl.ships == 0 then return 80 end
    local minSpeed = 9999
    for _, entry in ipairs(fl.ships) do
        local st = SHIP_TYPES[entry.shipType]
        if st and st.speed and st.speed < minSpeed then
            minSpeed = st.speed
        end
    end
    local base = minSpeed < 9999 and minSpeed or 80
    -- 应用曲速引擎科技 / 曲速闸门模块的速度加成
    local mult = (rm_ and rm_.baseBonus and rm_.baseBonus.fleetSpeedMult) or 1.0
    return base * mult
end

--- 更新所有编队地图对象（每帧调用）
local function updateFleets(dt)
    if not fm_ then return end
    for i = 1, fm_.maxFleets do
        local fl = fm_.fleets[i]
        if fl and #fl.ships > 0 then
            local obj = getOrCreateFleetObj(i)
            obj.pulse = obj.pulse + dt

            if obj.targetX then
                local dx  = obj.targetX - obj.x
                local dy  = obj.targetY - obj.y
                local d   = math.sqrt(dx*dx + dy*dy)
                if d <= FLEET_ARRIVE_RADIUS then
                    obj.x       = obj.targetX
                    obj.y       = obj.targetY
                    obj.targetX = nil
                    obj.targetY = nil

                    -- 到达目标：检查海盗基地突袭
                    if obj.pirateBaseTarget and onFleetContactPirateBase_ then
                        local bid = obj.pirateBaseTarget
                        obj.pirateBaseTarget = nil
                        onFleetContactPirateBase_(i, bid)
                        goto nextFleetObj
                    end

                    -- 到达目标：检查采矿任务
                    if obj.miningTarget and obj.miningTarget.hp > 0 then
                        local engCount = countEngineersInFleet(i)
                        if engCount == 0 then
                            obj.miningTarget = nil  -- 工程舰已不在编队，取消任务
                        end
                        -- 采矿本身在下方 mineTimer 分支处理
                    end

                    -- 到达目标：检查附近未殖民行星（探索舰触发殖民）
                    if fleetHasExplorer(i) and onFleetContactPlanet_ then
                        local planet = findNearbyUncolonizedPlanet(obj.x, obj.y)
                        if planet then
                            onFleetContactPlanet_(i, planet)
                        end
                    end
                else
                    local spd = getFleetSpeed(i)
                    obj.angle = math.atan(dy, dx)
                    obj.x = obj.x + (dx/d) * spd * dt
                    obj.y = obj.y + (dy/d) * spd * dt
                end
            end

            -- 待采小行星重生检测：若上次采矿目标已复活 → 自动再次出发
            if obj.pendingAsteroid and obj.pendingAsteroid.hp > 0
                and countEngineersInFleet(i) > 0 then
                local pa = obj.pendingAsteroid
                obj.pendingAsteroid = nil
                obj.miningTarget    = pa
                obj.mineTimer       = 0
                obj.targetX         = pa.x
                obj.targetY         = pa.y
                if notifyFn_ then
                    local cfg   = ASTEROID_TYPES[pa.atype]
                    local szLbl = pa.sizeKey and ASTEROID_SIZES[pa.sizeKey] and ASTEROID_SIZES[pa.sizeKey].label or ""
                    notifyFn_("编队 " .. i .. " 重返 " .. szLbl .. cfg.label .. "小行星", "info")
                end
            end

            -- 编队静止时采矿（在采矿目标附近）
            if not obj.targetX and obj.miningTarget then
                local a = obj.miningTarget
                if a.hp <= 0 then
                    obj.pendingAsteroid = a     -- 记住，等待重生后自动返回
                    obj.miningTarget    = nil
                    if seedShip_.state == "deployed" then
                        -- 返回停靠位置：距基地 220~280 单位，按编队 id 均匀分布角度
                        local maxF  = fm_ and fm_.maxFleets or 4
                        local ang   = (i - 1) / maxF * math.pi * 2
                        local rad   = 220 + math.random() * 60
                        obj.targetX = seedShip_.x + math.cos(ang) * rad
                        obj.targetY = seedShip_.y + math.sin(ang) * rad
                        if notifyFn_ then
                            notifyFn_("编队 " .. i .. " 资源采尽，返回星航基地", "info")
                        end
                    end
                else
                    local distToAsteroid = math.sqrt((obj.x - a.x)^2 + (obj.y - a.y)^2)
                    if distToAsteroid <= FLEET_MINE_RANGE * 2 then
                        obj.mineTimer = (obj.mineTimer or 0) + dt
                        if obj.mineTimer >= FLEET_MINE_INTERVAL then
                            obj.mineTimer = 0
                            local engCount = countEngineersInFleet(i)
                            if engCount > 0 and rm_ then
                                -- 每次采矿产出 = 该小行星固定产出 × 工程舰数，每采一次耗1点HP
                                local yield = a.yield * engCount
                                local dmg   = 1
                                rm_:add(a.atype, yield)
                                a.hp = math.max(0, a.hp - dmg)
                                print(string.format("[Fleet%d] 采矿 +%.1f %s, 小行星HP %d/%d",
                                    i, yield, a.atype, a.hp, a.maxHP))
                                -- 本轮击尽：标记耗尽，下一帧检测到 hp==0 时触发返航
                            else
                                obj.miningTarget = nil
                            end
                        end
                    end
                end
            end

            -- 自动寻矿：编队含工程舰且完全空闲 → 自动前往最近小行星
            -- 条件：无移动目标 / 无采矿目标 / 无待机小行星 / 含工程舰
            if not obj.targetX and not obj.miningTarget and not obj.pendingAsteroid
                and countEngineersInFleet(i) > 0 then
                local nearest, nearestD = nil, math.huge
                for _, a in ipairs(asteroids_) do
                    if a.hp > 0 then
                        local d = (obj.x - a.x)^2 + (obj.y - a.y)^2
                        if d < nearestD then nearestD = d; nearest = a end
                    end
                end
                if nearest then
                    obj.targetX      = nearest.x
                    obj.targetY      = nearest.y
                    obj.miningTarget = nearest
                    obj.mineTimer    = 0
                    if notifyFn_ then
                        local cfg   = ASTEROID_TYPES[nearest.atype]
                        local szLbl = nearest.sizeKey and ASTEROID_SIZES[nearest.sizeKey] and ASTEROID_SIZES[nearest.sizeKey].label or ""
                        notifyFn_("编队 " .. i .. " 自动前往 " .. szLbl .. cfg.label .. " 小行星", "info")
                    end
                end
            end
            ::nextFleetObj::
        end
    end
end

--- 失效单个编队的颜色缓存（编队组成变化时调用）
local function invalidateFleetColor(fleetId)
    fleetColorCache_[fleetId] = nil
end

--- 获取编队主色（带缓存，编队组成不变时复用上一帧结果）
local function getFleetColor(fleetId)
    if fleetColorCache_[fleetId] then return fleetColorCache_[fleetId] end
    if not fm_ then return {180,210,255} end
    local fl = fm_.fleets[fleetId]
    if not fl or #fl.ships == 0 then return {180,210,255} end
    local best, bestCount = fl.ships[1], 0
    for _, e in ipairs(fl.ships) do
        if e.count > bestCount then best = e; bestCount = e.count end
    end
    local st = SHIP_TYPES[best.shipType]
    local color = (st and st.color) or {180,210,255}
    fleetColorCache_[fleetId] = color
    return color
end

--- 渲染所有编队地图对象
local function drawFleets()
    if not fm_ then return end
    for i = 1, fm_.maxFleets do
        local fl = fm_.fleets[i]
        if not fl or #fl.ships == 0 then goto nextFleet end
        local obj = fleetObjs_[i]
        if not obj then goto nextFleet end

        local sx, sy = w2s(obj.x, obj.y)
        -- 视锥裁剪
        if sx < -30 or sx > screenW_+30 or sy < -30 or sy > screenH_+30 then
            goto nextFleet
        end

        local isSelected = (selectedFleetId_ == i)
        local pulse      = math.abs(math.sin(obj.pulse * 2)) * 0.4 + 0.6
        local c          = getFleetColor(i)
        local r          = (isSelected and 11 or 9) * zoom_

        -- 移动目标虚线
        if obj.targetX then
            local tx, ty = w2s(obj.targetX, obj.targetY)
            local tlen = math.sqrt((tx-sx)^2+(ty-sy)^2)
            if tlen > 1 then
                local nx, ny = (tx-sx)/tlen, (ty-sy)/tlen
                local pos, drawing = 0, true
                nvgBeginPath(vg_)
                while pos < tlen do
                    local ex = math.min(pos + (drawing and 8 or 5), tlen)
                    if drawing then
                        nvgMoveTo(vg_, sx+nx*pos, sy+ny*pos)
                        nvgLineTo(vg_, sx+nx*ex,  sy+ny*ex)
                    end
                    pos = ex; drawing = not drawing
                end
                nvgStrokeColor(vg_, nvgRGBA(c[1],c[2],c[3], 90))
                nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

                -- 目标十字
                local cr = 6 * zoom_ * pulse
                nvgBeginPath(vg_); nvgCircle(vg_, tx, ty, cr)
                nvgStrokeColor(vg_, nvgRGBA(c[1],c[2],c[3], math.floor(160*pulse)))
                nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)
            end
        end

        -- 选中光圈
        if isSelected then
            local selR = r * 2.2 * pulse
            local glow = nvgRadialGradient(vg_, sx, sy, r, selR,
                nvgRGBA(c[1],c[2],c[3], 80), nvgRGBA(c[1],c[2],c[3], 0))
            nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, selR)
            nvgFillPaint(vg_, glow); nvgFill(vg_)

            nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, r * 1.5)
            nvgStrokeColor(vg_, nvgRGBA(c[1],c[2],c[3], math.floor(180*pulse)))
            nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
        end

        -- 引擎尾焰（移动中）
        if obj.targetX then
            local tailX = sx - math.cos(obj.angle) * r * 1.4
            local tailY = sy - math.sin(obj.angle) * r * 1.4
            local flameG = nvgLinearGradient(vg_, sx, sy, tailX, tailY,
                nvgRGBA(c[1],c[2],c[3], 200), nvgRGBA(c[1],c[2],c[3], 0))
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, tailX + math.cos(obj.angle+math.pi/2)*3*zoom_,
                           tailY + math.sin(obj.angle+math.pi/2)*3*zoom_)
            nvgLineTo(vg_, sx, sy)
            nvgLineTo(vg_, tailX - math.cos(obj.angle+math.pi/2)*3*zoom_,
                           tailY - math.sin(obj.angle+math.pi/2)*3*zoom_)
            nvgClosePath(vg_)
            nvgFillPaint(vg_, flameG); nvgFill(vg_)
        end

        -- 船体（箭头形）
        nvgSave(vg_)
        nvgTranslate(vg_, sx, sy)
        nvgRotate(vg_, obj.angle)
        nvgBeginPath(vg_)
        nvgMoveTo(vg_,  r*1.2, 0)
        nvgLineTo(vg_, -r*0.8,  r*0.6)
        nvgLineTo(vg_, -r*0.4, 0)
        nvgLineTo(vg_, -r*0.8, -r*0.6)
        nvgClosePath(vg_)
        nvgFillColor(vg_, nvgRGBA(c[1],c[2],c[3], math.floor(200 + pulse*50)))
        nvgFill(vg_)
        -- 描边
        nvgStrokeColor(vg_, nvgRGBA(255,255,255, isSelected and 180 or 100))
        nvgStrokeWidth(vg_, isSelected and 1.5 or 1.0); nvgStroke(vg_)
        nvgRestore(vg_)

        -- 采矿光束（编队静止且有采矿目标时）
        if not obj.targetX and obj.miningTarget and obj.miningTarget.hp > 0 then
            local a  = obj.miningTarget
            local tx, ty = w2s(a.x, a.y)
            local mineBeamPulse = math.abs(math.sin((obj.mineTimer or 0) * math.pi / FLEET_MINE_INTERVAL))
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, sx, sy)
            nvgLineTo(vg_, tx, ty)
            nvgStrokeColor(vg_, nvgRGBA(255, 220, 80, math.floor(200 * mineBeamPulse)))
            nvgStrokeWidth(vg_, 2.0 * zoom_)
            nvgStroke(vg_)
        end

        -- 编队标签 + 舰船数
        local totalShips = 0
        for _, e in ipairs(fl.ships) do totalShips = totalShips + e.count end
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, math.max(8, 10 * zoom_))
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg_, nvgRGBA(c[1],c[2],c[3], 220))
        nvgText(vg_, sx, sy + r + 3, "编队" .. i .. " ×" .. totalShips)

        ::nextFleet::
    end
end

--- 尝试点击编队图标，返回是否命中（命中时设置选中状态）
tryClickFleet = function(mx, my)
    if not fm_ then return false end
    local hitR = FLEET_ICON_RADIUS / zoom_  -- 世界坐标命中半径
    local wx, wy = s2w(mx, my)
    for i = 1, fm_.maxFleets do
        local fl = fm_.fleets[i]
        if fl and #fl.ships > 0 then
            local obj = fleetObjs_[i]
            if obj then
                local d = dist2(wx, wy, obj.x, obj.y)
                if d < hitR * zoom_ * 2 then
                    -- 命中：切换选中
                    if selectedFleetId_ == i then
                        selectedFleetId_ = nil
                        if onFleetSelect_ then onFleetSelect_(nil) end
                    else
                        selectedFleetId_ = i
                        if onFleetSelect_ then onFleetSelect_(i) end
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- 种子飞船逻辑更新
-- ============================================================================
-- 点击目标到达判定半径（世界坐标）
local SEED_ARRIVE_RADIUS = 20

local function updateSeedShip(dt)
    local ss = seedShip_
    ss.pulse = ss.pulse + dt

    if ss.state == "moving" then
        local dx, dy = 0, 0

        -- 优先：WASD / 方向键（键盘输入会覆盖点击目标）
        local hasKey = keyDown_.up or keyDown_.down or keyDown_.left or keyDown_.right
        if hasKey then
            -- 键盘输入时取消点击目标
            seedClickTarget_ = nil
            if keyDown_.up    then dy = dy - 1 end
            if keyDown_.down  then dy = dy + 1 end
            if keyDown_.left  then dx = dx - 1 end
            if keyDown_.right then dx = dx + 1 end
        elseif seedClickTarget_ then
            -- 点击目标寻路
            local tx, ty = seedClickTarget_.x, seedClickTarget_.y
            local tdx, tdy = tx - ss.x, ty - ss.y
            local d = math.sqrt(tdx*tdx + tdy*tdy)
            if d <= SEED_ARRIVE_RADIUS then
                -- 到达目标点
                seedClickTarget_ = nil
            else
                dx, dy = tdx / d, tdy / d
            end
        end

        if dx ~= 0 or dy ~= 0 then
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 0 then dx, dy = dx/len, dy/len end
            dx, dy = dx * SEED_SPEED, dy * SEED_SPEED
            ss.x = ss.x + dx * dt
            ss.y = ss.y + dy * dt
            ss.angle = math.atan(dy, dx)
        end

        -- 相机跟随飞船（平滑插值）
        local targetCamX = screenW_ / 2 - ss.x
        local targetCamY = screenH_ / 2 - ss.y
        camera_.x = camera_.x + (targetCamX - camera_.x) * math.min(1, dt * 5)
        camera_.y = camera_.y + (targetCamY - camera_.y) * math.min(1, dt * 5)

    elseif ss.state == "deploying" then
        ss.timer = ss.timer + dt
        if ss.timer >= SEED_DEPLOY_DUR then
            ss.state = "deployed"
            ss.timer = SEED_DEPLOY_DUR
            print("[SeedShip] 展开完成，基地坐标: " ..
                string.format("(%.0f, %.0f)", ss.x, ss.y))
            if ss.onDeploy then
                -- 基地展开：解锁模块建造（colonized=true 让 canBuild 通过）
                ss.colonized = true
                -- 将基地设为当前选中对象，使 GetSelected() 返回基地
                selectedPlanet_ = ss
                ss.onDeploy(ss.x, ss.y, ss)
            end
        end
    end
    -- deployed 状态：飞船固定，不更新位置和相机
end

function GalaxyScene.Update(dt)
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth()  / dpr
    screenH_ = graphics:GetHeight() / dpr
    deepSpaceAnimT_ = deepSpaceAnimT_ + dt
    updateSeedShip(dt)
    updatePlanets(dt)
    updateHover()
    updateFleets(dt)
    -- 海盗 AI 更新
    if pirateAI_ then pirateAI_:update(dt) end
    -- 耗尽的小行星定期重生
    for _, a in ipairs(asteroids_) do
        if a.hp <= 0 then
            a.respawnTimer = (a.respawnTimer or 0) + dt
            if a.respawnTimer >= 60 then  -- 60秒重生
                a.hp = a.maxHP
                a.respawnTimer = 0
            end
        else
            a.angle = a.angle + a.rotSpd * dt
        end
    end
end

-- ============================================================================
-- 种子飞船渲染
-- ============================================================================
local function drawSeedShip()
    local ss = seedShip_
    local sx, sy = w2s(ss.x, ss.y)

    -- 点击移动目标：虚线路径 + 目标光标
    if seedClickTarget_ and ss.state == "moving" then
        local tx, ty = w2s(seedClickTarget_.x, seedClickTarget_.y)
        -- 虚线连线
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, sx, sy)
        nvgLineTo(vg_, tx, ty)
        nvgStrokeColor(vg_, nvgRGBA(80, 200, 255, 100))
        nvgStrokeWidth(vg_, 1)
        -- 用短线段模拟虚线
        local segLen = 10
        local gapLen = 6
        local tlen = math.sqrt((tx-sx)*(tx-sx) + (ty-sy)*(ty-sy))
        if tlen > 1 then
            local nx, ny = (tx-sx)/tlen, (ty-sy)/tlen
            local pos = 0
            local drawing = true
            nvgBeginPath(vg_)
            while pos < tlen do
                local ex = math.min(pos + (drawing and segLen or gapLen), tlen)
                if drawing then
                    nvgMoveTo(vg_, sx + nx*pos, sy + ny*pos)
                    nvgLineTo(vg_, sx + nx*ex,  sy + ny*ex)
                end
                pos = ex
                drawing = not drawing
            end
            nvgStrokeColor(vg_, nvgRGBA(80, 200, 255, 110))
            nvgStrokeWidth(vg_, 1)
            nvgStroke(vg_)
        end

        -- 目标光标（脉冲十字圆）
        local pulse = math.abs(math.sin(ss.pulse * 3)) * 0.4 + 0.6
        local cr = 8 * zoom_ * pulse
        nvgBeginPath(vg_)
        nvgCircle(vg_, tx, ty, cr)
        nvgStrokeColor(vg_, nvgRGBA(80, 220, 255, math.floor(180 * pulse)))
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)
        -- 十字线
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, tx - cr * 1.4, ty); nvgLineTo(vg_, tx - cr * 0.5, ty)
        nvgMoveTo(vg_, tx + cr * 0.5, ty); nvgLineTo(vg_, tx + cr * 1.4, ty)
        nvgMoveTo(vg_, tx, ty - cr * 1.4); nvgLineTo(vg_, tx, ty - cr * 0.5)
        nvgMoveTo(vg_, tx, ty + cr * 0.5); nvgLineTo(vg_, tx, ty + cr * 1.4)
        nvgStrokeColor(vg_, nvgRGBA(80, 220, 255, math.floor(200 * pulse)))
        nvgStrokeWidth(vg_, 1.2)
        nvgStroke(vg_)
    end

    local t   = ss.timer
    local pct = (ss.state == "deploying") and math.min(1, t / SEED_DEPLOY_DUR) or
                (ss.state == "deployed")  and 1 or 0
    local pulse = math.abs(math.sin(ss.pulse * 2)) * 0.5 + 0.5  -- 0.5~1.0

    -- 展开状态：基地光圈（deployed 后显示）
    if ss.state == "deployed" then
        local baseR = (60 + pulse * 8) * zoom_
        local glow = nvgRadialGradient(vg_, sx, sy, baseR * 0.3, baseR,
            nvgRGBA(0, 200, 120, 60), nvgRGBA(0, 200, 120, 0))
        nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, baseR)
        nvgFillPaint(vg_, glow); nvgFill(vg_)

        nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, baseR)
        nvgStrokeColor(vg_, nvgRGBA(0, 220, 130, math.floor(80 + pulse * 60)))
        nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
    end

    -- 展开动画：扩散光环
    if ss.state == "deploying" then
        for i = 1, 3 do
            local ringPct = math.max(0, pct - (i-1) * 0.15)
            local ringR   = ringPct * 80 * zoom_
            nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, ringR)
            nvgStrokeColor(vg_, nvgRGBA(100, 220, 255,
                math.floor((1 - ringPct) * 180)))
            nvgStrokeWidth(vg_, 2 - ringPct); nvgStroke(vg_)
        end
    end

    -- 移动时：引擎尾焰
    if ss.state == "moving" then
        local moving = keyDown_.up or keyDown_.down or keyDown_.left or keyDown_.right
        if moving then
            local tailX = sx - math.cos(ss.angle) * 14 * zoom_
            local tailY = sy - math.sin(ss.angle) * 14 * zoom_
            local flameGrad = nvgLinearGradient(vg_, sx, sy, tailX, tailY,
                nvgRGBA(100, 180, 255, 220), nvgRGBA(60, 120, 255, 0))
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, tailX + math.cos(ss.angle + math.pi/2) * 4 * zoom_,
                           tailY + math.sin(ss.angle + math.pi/2) * 4 * zoom_)
            nvgLineTo(vg_, sx, sy)
            nvgLineTo(vg_, tailX - math.cos(ss.angle + math.pi/2) * 4 * zoom_,
                           tailY - math.sin(ss.angle + math.pi/2) * 4 * zoom_)
            nvgClosePath(vg_)
            nvgFillPaint(vg_, flameGrad); nvgFill(vg_)
        end
    end

    -- 飞船本体（展开进度影响尺寸）
    local bodyScale = (ss.state == "deploying") and (1 + pct * 0.4) or 1
    local r = 10 * zoom_ * bodyScale
    local ang = ss.angle
    -- 外发光（保留程序化效果）
    local glowR = r * 1.8 * pulse
    local shipGlow = nvgRadialGradient(vg_, sx, sy, r * 0.5, glowR,
        nvgRGBA(80, 180, 255, 80), nvgRGBA(80, 180, 255, 0))
    nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, glowR)
    nvgFillPaint(vg_, shipGlow); nvgFill(vg_)

    -- 飞船/基地纹理渲染
    nvgSave(vg_)
    nvgTranslate(vg_, sx, sy)
    nvgRotate(vg_, ang)
    local half = r * 1.4
    local shipAlpha = (ss.state == "deploying") and (200 + pct * 55) or 255
    nvgGlobalAlpha(vg_, shipAlpha / 255)
    if ss.state == "deployed" and imgBaseStation_ and imgBaseStation_ >= 0 then
        -- 展开后显示基地站图片（不旋转，基地是固定的）
        nvgRotate(vg_, -ang)  -- 取消旋转，基地固定朝向
        local bHalf = (60 + pulse * 4) * zoom_ * 0.7
        local paint = nvgImagePattern(vg_, -bHalf, -bHalf, bHalf*2, bHalf*2, 0, imgBaseStation_, 1.0)
        nvgBeginPath(vg_); nvgRect(vg_, -bHalf, -bHalf, bHalf*2, bHalf*2)
        nvgFillPaint(vg_, paint); nvgFill(vg_)
    elseif imgSeedShip_ and imgSeedShip_ >= 0 then
        -- 移动/展开中：种子飞船图片（跟随旋转角度）
        local paint = nvgImagePattern(vg_, -half, -half, half*2, half*2, 0, imgSeedShip_, 1.0)
        nvgBeginPath(vg_); nvgRect(vg_, -half, -half, half*2, half*2)
        nvgFillPaint(vg_, paint); nvgFill(vg_)
    else
        -- 回退：六角形体
        nvgBeginPath(vg_)
        for i = 0, 5 do
            local theta = i * math.pi / 3
            if i == 0 then nvgMoveTo(vg_, math.cos(theta)*r, math.sin(theta)*r)
            else nvgLineTo(vg_, math.cos(theta)*r, math.sin(theta)*r) end
        end
        nvgClosePath(vg_)
        if ss.state == "deployed" then nvgFillColor(vg_, nvgRGBA(0,200,120,240))
        else nvgFillColor(vg_, nvgRGBA(80,160,255, math.floor(shipAlpha))) end
        nvgFill(vg_)
    end
    nvgGlobalAlpha(vg_, 1.0)
    nvgRestore(vg_)

    -- 中心点（仅飞船移动时显示）
    if ss.state ~= "deployed" then
        nvgBeginPath(vg_); nvgCircle(vg_, sx, sy, 2.5 * zoom_)
        nvgFillColor(vg_, nvgRGBA(255, 255, 255, 200)); nvgFill(vg_)
    end

    -- 标签
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, math.max(9, 11 * zoom_))
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if ss.state == "deployed" then
        nvgFillColor(vg_, nvgRGBA(0, 220, 130, 220))
        nvgText(vg_, sx, sy + r + 4, "[ 星航基地 ]")
    elseif ss.state == "deploying" then
        nvgFillColor(vg_, nvgRGBA(100, 220, 255, 200))
        nvgText(vg_, sx, sy + r * bodyScale + 4,
            string.format("展开中 %d%%", math.floor(pct * 100)))
    else
        nvgFillColor(vg_, nvgRGBA(140, 190, 255, 180))
        nvgText(vg_, sx, sy + r + 4, "种子飞船")
    end
end

-- 绘制小行星资源总量面板（小地图上方）
local function drawAsteroidSummary()
    -- 统计：各资源类型 × 各尺寸 的数量和储量
    -- sizeCnt[atype][sizeKey] = count
    -- sizeTot[atype][sizeKey] = total_yield
    local sizeCnt = {}
    local sizeTot = {}
    for _, atype in ipairs(ASTEROID_TYPE_ORDER) do
        sizeCnt[atype] = { small=0, medium=0, large=0 }
        sizeTot[atype] = { small=0, medium=0, large=0 }
    end
    for _, a in ipairs(asteroids_) do
        if a.hp > 0 and a.sizeKey then
            sizeCnt[a.atype][a.sizeKey] = sizeCnt[a.atype][a.sizeKey] + 1
            sizeTot[a.atype][a.sizeKey] = sizeTot[a.atype][a.sizeKey]
                + a.yield * (a.hp / a.maxHP)
        end
    end

    -- 面板尺寸：3 资源行 × 3 尺寸小格 + 标题
    local panW  = MINIMAP_W
    local rowH  = 38   -- 每种资源类型占的高度
    local panH  = 14 + 3 * rowH
    local px    = screenW_ - panW - MINIMAP_PAD
    local py    = screenH_ - MINIMAP_H - MINIMAP_PAD - panH - 6

    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, panW, panH, 4)
    nvgFillColor(vg_, nvgRGBA(0, 6, 18, 210))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(68, 100, 200, 100))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg_, nvgRGBA(100, 160, 255, 160))
    nvgText(vg_, px + 4, py + 3, "小行星资源")

    -- 每种资源类型：一行标题 + 三格尺寸数据
    local typeRows = {
        { atype="minerals", label="矿石",  color=ASTEROID_TYPES.minerals.color },
        { atype="energy",   label="能量块", color=ASTEROID_TYPES.energy.color   },
        { atype="crystal",  label="水晶",  color=ASTEROID_TYPES.crystal.color  },
    }
    -- 尺寸格颜色（微型暗/中型中/大型亮）
    local sizeColors = {
        small  = { 160, 160, 160 },
        medium = { 220, 220, 100 },
        large  = { 100, 255, 160 },
    }

    for j, row in ipairs(typeRows) do
        local c  = row.color
        local ry = py + 14 + (j - 1) * rowH

        -- 资源类型标签
        nvgFontSize(vg_, 9)
        nvgFillColor(vg_, nvgRGBA(c[1], c[2], c[3], 220))
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(vg_, px + 5, ry + 1, row.label)

        -- 三档尺寸小格（横向排列）
        local cellW = (panW - 8) / 3
        for k, sizeKey in ipairs(ASTEROID_SIZE_ORDER) do
            local szCfg = ASTEROID_SIZES[sizeKey]
            local sc    = sizeColors[sizeKey]
            local cx    = px + 4 + (k - 1) * cellW
            local cy    = ry + 12

            -- 格子背景
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, cx, cy, cellW - 2, rowH - 14, 2)
            nvgFillColor(vg_, nvgRGBA(sc[1], sc[2], sc[3], 20))
            nvgFill(vg_)

            -- 尺寸名
            nvgFontSize(vg_, 8)
            nvgFillColor(vg_, nvgRGBA(sc[1], sc[2], sc[3], 180))
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgText(vg_, cx + cellW/2 - 1, cy + 1, szCfg.label)

            -- 颗数
            local cnt = sizeCnt[row.atype][sizeKey]
            nvgFontSize(vg_, 9)
            nvgFillColor(vg_, nvgRGBA(sc[1], sc[2], sc[3], 220))
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgText(vg_, cx + cellW/2 - 1, cy + 10, cnt .. "颗")
        end
    end
end

function GalaxyScene.Render()
    if #bgStars_ == 0 then return end  -- Init 尚未完成，跳过渲染
    drawBackground()
    drawAsteroids()
    -- 深空星系（渲染在普通星系之前，避免遮挡普通行星）
    for _, sys in ipairs(deepSpaceSystems_) do
        drawDeepSpaceSystem(sys, deepSpaceAnimT_)
    end
    for _, sys in ipairs(starSystems_) do
        drawStarSystem(sys)
    end
    drawFleets()
    -- 渲染海盗基地和舰队
    if pirateAI_ then pirateAI_:render(vg_, w2s, zoom_) end
    drawSeedShip()
    drawAsteroidSummary()
    drawMinimap()
    -- 海盗进攻预警 HUD（有海盗舰队在途时显示）
    if pirateAI_ and #pirateAI_.fleets > 0 then
        drawPirateWarningHUD()
    end
    -- Tooltip 最后画（浮于所有内容之上）
    drawTooltip(hoveredPlanet_)
    drawAsteroidTooltip(hoveredAsteroid_)
end

-- ============================================================================
-- 输入处理（由 main.lua 调用）
-- ============================================================================
function GalaxyScene.OnMouseDown(mx, my)
    isDragging_ = true
    dragStart_  = { x=mx, y=my }
    camAtDrag_  = { x=camera_.x, y=camera_.y }
    dragDist_   = 0
end

function GalaxyScene.OnMouseMove(mx, my)
    mouseX_ = mx
    mouseY_ = my
    if not isDragging_ then return end
    local dx = mx - dragStart_.x
    local dy = my - dragStart_.y
    camera_.x  = camAtDrag_.x + dx / zoom_
    camera_.y  = camAtDrag_.y + dy / zoom_
    dragDist_  = math.sqrt(dx*dx + dy*dy)
end

-- 小地图区域判断（返回小地图左上角坐标和宽高）
local function minimapRect()
    local mx = screenW_  - MINIMAP_W - MINIMAP_PAD
    local my = screenH_  - MINIMAP_H - MINIMAP_PAD
    return mx, my, MINIMAP_W, MINIMAP_H
end

-- 将小地图像素坐标换算到世界坐标，并传送相机
local function teleportToMinimap(px, py)
    local mmx, mmy, mmw, mmh = minimapRect()
    local scaleX = (mmw - 8)  / (MINIMAP_WORLD_RANGE * 2)
    local scaleY = (mmh - 14) / (MINIMAP_WORLD_RANGE * 2)
    local offX   = mmx + 4 + (mmw - 8)  / 2
    local offY   = mmy + 12 + (mmh - 14) / 2
    -- 小地图像素 → 世界坐标
    local wx = (px - offX) / scaleX
    local wy = (py - offY) / scaleY
    -- 相机设置（负号：相机偏移与世界坐标方向相反）
    camera_.x = -wx + screenW_  / 2
    camera_.y = -wy + screenH_  / 2
    if notifyFn_ then
        notifyFn_(string.format("传送至 (%.0f, %.0f)", wx, wy), "info")
    end
end

function GalaxyScene.OnMouseUp(mx, my)
    if not isDragging_ then return end
    isDragging_ = false
    if dragDist_ < 8 then
        -- 判断是否点击在小地图区域内
        local mmx, mmy, mmw, mmh = minimapRect()
        if mx >= mmx and mx <= mmx+mmw and my >= mmy and my <= mmy+mmh then
            teleportToMinimap(mx, my)
        else
            handleClick(mx, my)
        end
    end
end

--- 鼠标滚轮缩放（delta > 0 = 放大, < 0 = 缩小）
--- 以鼠标位置为缩放中心
function GalaxyScene.OnMouseWheel(mx, my, delta)
    local oldZoom = zoom_
    zoom_ = math.max(0.3, math.min(4.0, zoom_ + delta * 0.12))
    -- 调整 camera 以保持鼠标下方的世界坐标不变
    local cx = screenW_ / 2
    local cy = screenH_ / 2
    -- 鼠标相对中心的偏移在世界空间里的变化
    local dWx = (mx - cx) * (1/oldZoom - 1/zoom_)
    local dWy = (my - cy) * (1/oldZoom - 1/zoom_)
    camera_.x = camera_.x - dWx
    camera_.y = camera_.y - dWy
end

-- ============================================================================
-- 触摸输入接口（双指捏合缩放 + 单指拖拽）
-- ============================================================================

-- 辅助：统计当前触点数
local function touchCount()
    local n = 0
    for _ in pairs(touches_) do n = n + 1 end
    return n
end

-- 辅助：获取双指中点和间距
local function pinchInfo()
    local pts = {}
    for _, t in pairs(touches_) do pts[#pts + 1] = t end
    if #pts < 2 then return nil end
    local dx   = pts[2].x - pts[1].x
    local dy   = pts[2].y - pts[1].y
    local dist = math.sqrt(dx * dx + dy * dy)
    local midX = (pts[1].x + pts[2].x) * 0.5
    local midY = (pts[1].y + pts[2].y) * 0.5
    return dist, midX, midY
end

function GalaxyScene.OnTouchBegin(id, x, y)
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr
    touches_[id] = { x = lx, y = ly }

    if touchCount() >= 2 then
        -- 第二根手指落下：进入捏合模式，停止单指拖拽
        isDragging_ = false
        pinchDist_  = pinchInfo()
    else
        -- 第一根手指：初始化单指拖拽
        isDragging_ = true
        dragStart_  = { x = lx, y = ly }
        camAtDrag_  = { x = camera_.x, y = camera_.y }
        dragDist_   = 0
        pinchDist_  = nil
    end
end

function GalaxyScene.OnTouchMove(id, x, y)
    if not touches_[id] then return end
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr
    touches_[id] = { x = lx, y = ly }

    local n = touchCount()
    if n >= 2 then
        -- 双指捏合缩放
        isDragging_ = false
        local newDist, midX, midY = pinchInfo()
        if pinchDist_ and pinchDist_ > 1 and newDist then
            local scale   = newDist / pinchDist_
            local oldZoom = zoom_
            zoom_ = math.max(0.3, math.min(4.0, zoom_ * scale))
            -- 以双指中点为缩放中心
            local cx  = screenW_ / 2
            local cy  = screenH_ / 2
            local dWx = (midX - cx) * (1 / oldZoom - 1 / zoom_)
            local dWy = (midY - cy) * (1 / oldZoom - 1 / zoom_)
            camera_.x = camera_.x - dWx
            camera_.y = camera_.y - dWy
        end
        pinchDist_ = newDist
    elseif n == 1 and isDragging_ then
        -- 单指拖拽平移
        local dx = lx - dragStart_.x
        local dy = ly - dragStart_.y
        camera_.x = camAtDrag_.x + dx / zoom_
        camera_.y = camAtDrag_.y + dy / zoom_
        dragDist_  = math.sqrt(dx * dx + dy * dy)
    end
end

function GalaxyScene.OnTouchEnd(id, x, y)
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr

    -- 单指短点击（未捏合）→ 触发 handleClick
    if touchCount() == 1 and isDragging_ and dragDist_ < 8 then
        handleClick(lx, ly)
    end

    touches_[id] = nil
    pinchDist_   = nil

    local remaining = touchCount()
    if remaining == 0 then
        isDragging_ = false
    elseif remaining == 1 then
        -- 抬起一根手指后，剩余手指重新初始化单指拖拽
        for _, t in pairs(touches_) do
            isDragging_ = true
            dragStart_  = { x = t.x, y = t.y }
            camAtDrag_  = { x = camera_.x, y = camera_.y }
            dragDist_   = 0
            break
        end
    end
end

-- ============================================================================
-- 种子飞船输入接口 & 查询接口
-- ============================================================================

--- 键盘按下（由 Client.lua 转发）
function GalaxyScene.OnKeyDown(key)
    if key == KEY_W or key == KEY_UP    then keyDown_.up    = true end
    if key == KEY_S or key == KEY_DOWN  then keyDown_.down  = true end
    if key == KEY_A or key == KEY_LEFT  then keyDown_.left  = true end
    if key == KEY_D or key == KEY_RIGHT then keyDown_.right = true end

    -- 空格键：触发展开（仅 moving 状态有效）
    if key == KEY_SPACE and seedShip_.state == "moving" then
        seedShip_.state = "deploying"
        seedShip_.timer = 0
        -- 展开时停止移动，清除按键状态
        keyDown_.up    = false
        keyDown_.down  = false
        keyDown_.left  = false
        keyDown_.right = false
        print("[SeedShip] 开始展开...")
    end
end

--- 键盘抬起（由 Client.lua 转发）
function GalaxyScene.OnKeyUp(key)
    if key == KEY_W or key == KEY_UP    then keyDown_.up    = false end
    if key == KEY_S or key == KEY_DOWN  then keyDown_.down  = false end
    if key == KEY_A or key == KEY_LEFT  then keyDown_.left  = false end
    if key == KEY_D or key == KEY_RIGHT then keyDown_.right = false end
end

--- 返回种子飞船是否已展开完毕
function GalaxyScene.IsDeployed()
    return seedShip_.state == "deployed"
end

--- 返回当前飞船状态（"moving" / "deploying" / "deployed"）
function GalaxyScene.GetSeedState()
    return seedShip_.state
end

--- 返回基地对象（展开后可用于建造模块，兼容 planet 接口）
function GalaxyScene.GetBase()
    return seedShip_
end

--- 外部同步选中编队（UI 面板点击编队 tab 后调用）
--- 只设置地图内部状态，不触发 onFleetSelect_ 回调（避免循环）
--- 传 nil 则取消地图上的编队选中
function GalaxyScene.SelectFleet(fleetId)
    selectedFleetId_ = fleetId
end

--- 返回当前地图上选中的编队 id（nil=无）
function GalaxyScene.GetSelectedFleetId()
    return selectedFleetId_
end

--- 失效指定编队的颜色缓存（Client.lua 在舰船移动/建造完成后调用）
function GalaxyScene.InvalidateFleetColor(fleetId)
    invalidateFleetColor(fleetId)
end



-- ============================================================================
-- 云存档：序列化 / 反序列化
-- ============================================================================

--- 导出所有需要持久化的星图数据（行星 + 基地状态）
function GalaxyScene.GetSaveData()
    -- 行星存档
    local planets = {}
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            if p.colonized then
                local buildings = {}
                for _, b in ipairs(p.buildings) do
                    local prod = {}
                    for res, v in pairs(b.currentProd or {}) do
                        prod[res] = v
                    end
                    buildings[#buildings + 1] = {
                        key         = b.key,
                        name        = b.name,
                        level       = b.level,
                        currentProd = prod,
                    }
                end
                local appliedTechs = {}
                for techId, _ in pairs(p.appliedTechs or {}) do
                    appliedTechs[#appliedTechs + 1] = techId
                end
                planets[#planets + 1] = {
                    id           = p.id,
                    colonized    = true,
                    buildings    = buildings,
                    appliedTechs = appliedTechs,
                    constructing = p.constructing and {
                        key       = p.constructing.key,
                        remaining = p.constructing.remaining,
                        totalTime = p.constructing.totalTime,
                        level     = p.constructing.level,
                        isUpgrade = p.constructing.isUpgrade,
                        targetIdx = p.constructing.targetIdx,
                    } or nil,
                }
            end
        end
    end
    -- 基地存档
    local base = nil
    if seedShip_.colonized then
        local baseBuildings = {}
        for _, b in ipairs(seedShip_.buildings) do
            baseBuildings[#baseBuildings + 1] = { key = b.key, name = b.name, level = b.level }
        end
        base = {
            colonized    = true,
            x            = seedShip_.x,
            y            = seedShip_.y,
            coreLevel    = seedShip_.coreLevel or 1,
            buildings    = baseBuildings,
            constructing = seedShip_.constructing and {
                key           = seedShip_.constructing.key,
                remaining     = seedShip_.constructing.remaining,
                totalTime     = seedShip_.constructing.totalTime,
                level         = seedShip_.constructing.level,
                isUpgrade     = seedShip_.constructing.isUpgrade,
                targetIdx     = seedShip_.constructing.targetIdx,
                isCoreUpgrade = seedShip_.constructing.isCoreUpgrade,
            } or nil,
        }
    end
    -- 深空行星存档（仅保存已殖民的）
    local deepPlanets = {}
    for _, sys in ipairs(deepSpaceSystems_) do
        for _, p in ipairs(sys.planets) do
            if p.colonized then
                local buildings = {}
                for _, b in ipairs(p.buildings) do
                    local prod = {}
                    for res, v in pairs(b.currentProd or {}) do prod[res] = v end
                    buildings[#buildings + 1] = {
                        key = b.key, name = b.name, level = b.level, currentProd = prod
                    }
                end
                deepPlanets[#deepPlanets + 1] = {
                    id        = p.id,
                    colonized = true,
                    buildings = buildings,
                }
            end
        end
    end
    -- 编队位置存档（保存当前地图位置，避免重载后复位）
    local fleets = {}
    for fleetId, obj in pairs(fleetObjs_) do
        fleets[#fleets + 1] = {
            id      = fleetId,
            x       = math.floor(obj.x + 0.5),
            y       = math.floor(obj.y + 0.5),
            targetX = obj.targetX and math.floor(obj.targetX + 0.5) or nil,
            targetY = obj.targetY and math.floor(obj.targetY + 0.5) or nil,
            angle   = obj.angle or 0,
        }
    end
    return { planets = planets, base = base, deepPlanets = deepPlanets, fleets = fleets }
end

--- 从存档恢复星图数据，并重建资源产出速率
--- rm: ResourceManager 实例，用于重建 rates
function GalaxyScene.LoadSaveData(data, rm)
    if not data then return end

    -- 建立 id → planet 映射
    local planetMap = {}
    for _, sys in ipairs(starSystems_) do
        for _, p in ipairs(sys.planets) do
            planetMap[p.id] = p
        end
    end

    -- 恢复行星
    if data.planets then
        -- 先重置所有产出速率（避免叠加）
        -- 原矿基础速率保留（精炼厂再转化）；精炼资源速率从0起算由模块效果叠加
        if rm then
            rm.rates = { minerals=2, energy=5, crystal=0.5,
                         metal=0, esource=0, nuclear=0,
                         population=0.1, credits=0 }
        end
        for _, pd in ipairs(data.planets) do
            local p = planetMap[pd.id]
            if p then
                p.colonized    = true
                p.owner        = "player"
                p.buildings    = {}
                p.appliedTechs = {}
                -- 恢复建筑
                for _, bd in ipairs(pd.buildings or {}) do
                    local bld = {
                        key         = bd.key,
                        name        = bd.name,
                        level       = bd.level,
                        currentProd = {},
                    }
                    for res, v in pairs(bd.currentProd or {}) do
                        bld.currentProd[res] = v
                        -- 重建产出速率
                        if rm then
                            rm.rates[res] = (rm.rates[res] or 0) + v
                        end
                    end
                    p.buildings[#p.buildings + 1] = bld
                end
                -- 恢复 appliedTechs
                for _, techId in ipairs(pd.appliedTechs or {}) do
                    p.appliedTechs[techId] = true
                end
                -- 恢复建造队列
                if pd.constructing then
                    p.constructing = {
                        key       = pd.constructing.key,
                        remaining = pd.constructing.remaining,
                        totalTime = pd.constructing.totalTime,
                        progress  = 1.0 - (pd.constructing.remaining / math.max(1, pd.constructing.totalTime)),
                        level     = pd.constructing.level,
                        isUpgrade = pd.constructing.isUpgrade,
                        targetIdx = pd.constructing.targetIdx,
                    }
                end
            end
        end
    end

    -- 恢复基地
    if data.base and data.base.colonized then
        seedShip_.colonized  = true
        seedShip_.state      = "deployed"
        seedShip_.x          = data.base.x or seedShip_.x
        seedShip_.y          = data.base.y or seedShip_.y
        seedShip_.coreLevel  = data.base.coreLevel or 1
        seedShip_.buildings  = {}
        for _, bd in ipairs(data.base.buildings or {}) do
            seedShip_.buildings[#seedShip_.buildings + 1] = {
                key = bd.key, name = bd.name, level = bd.level
            }
        end
        if data.base.constructing then
            local c = data.base.constructing
            seedShip_.constructing = {
                key           = c.key,
                remaining     = c.remaining,
                totalTime     = c.totalTime,
                progress      = 1.0 - (c.remaining / math.max(1, c.totalTime)),
                level         = c.level,
                isUpgrade     = c.isUpgrade,
                targetIdx     = c.targetIdx,
                isCoreUpgrade = c.isCoreUpgrade,
            }
        end
    end

    -- 恢复深空行星（建立 id → planet 映射）
    if data.deepPlanets and #data.deepPlanets > 0 then
        local dsMap = {}
        for _, sys in ipairs(deepSpaceSystems_) do
            for _, p in ipairs(sys.planets) do
                dsMap[p.id] = p
            end
        end
        for _, pd in ipairs(data.deepPlanets) do
            local p = dsMap[pd.id]
            if p then
                p.colonized = true
                p.owner     = "player"
                p.buildings = {}
                for _, bd in ipairs(pd.buildings or {}) do
                    local bld = { key = bd.key, name = bd.name, level = bd.level, currentProd = {} }
                    for res, v in pairs(bd.currentProd or {}) do
                        bld.currentProd[res] = v
                        if rm then rm.rates[res] = (rm.rates[res] or 0) + v end
                    end
                    p.buildings[#p.buildings + 1] = bld
                end
            end
        end
    end

    -- 存档加载完毕后重建殖民缓存（generateStarSystems 已初始化 allPlanets_）
    colonizedPlanets_ = {}
    for _, p in ipairs(allPlanets_) do
        if p.colonized then
            colonizedPlanets_[#colonizedPlanets_+1] = p
        end
    end

    -- 恢复编队地图位置（覆盖懒初始化的随机位置）
    if data.fleets then
        for _, fd in ipairs(data.fleets) do
            local obj = getOrCreateFleetObj(fd.id)
            obj.x       = fd.x or obj.x
            obj.y       = fd.y or obj.y
            obj.targetX = fd.targetX
            obj.targetY = fd.targetY
            obj.angle   = fd.angle or obj.angle
        end
    end
end

--- 释放纹理句柄（softReset 前调用，避免重复 Init 泄漏图片）
function GalaxyScene.Shutdown()
    if not vg_ then return end
    if asteroidImgs_ then
        for _, h in pairs(asteroidImgs_) do
            if h and h >= 0 then nvgDeleteImage(vg_, h) end
        end
        asteroidImgs_ = {}
    end
    if imgSeedShip_    and imgSeedShip_    >= 0 then nvgDeleteImage(vg_, imgSeedShip_);    imgSeedShip_    = -1 end
    if imgBaseStation_ and imgBaseStation_ >= 0 then nvgDeleteImage(vg_, imgBaseStation_); imgBaseStation_ = -1 end
    print("[GalaxyScene] Shutdown 完成")
end

return GalaxyScene
