-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function generateStarSystems()
    starSystems_ = {}

    -- P2-2: 按变体设定基础参数
    local numStars, spread, resBonus
    if mapVariant_ == "DENSE" then
        numStars = 70       -- 星系数 × 1.4
        spread   = 2800     -- 分布半径 × 0.7（4000 × 0.7 = 2800）
        resBonus = 1.3      -- 资源产出加成
    elseif mapVariant_ == "SPARSE" then
        numStars = 35       -- 星系数 × 0.7
        spread   = 6000     -- 分布半径 × 1.5（4000 × 1.5 = 6000）
        resBonus = 1.0
    else                    -- NORMAL / BIPOLAR 共用基础参数
        numStars = 50
        spread   = 4000
        resBonus = 1.0
    end

    for i = 1, numStars do
        local stype = randItem(STAR_TYPES)
        local name  = SYSTEM_PREFIXES[math.random(1,#SYSTEM_PREFIXES)] .. " "
                    .. SYSTEM_SUFFIXES[math.random(1,#SYSTEM_SUFFIXES)]
                    .. "-" .. i

        -- P2-2: BIPOLAR 模式——星系分布在左右两簇，中间 ±600 范围稀少
        local x, y
        if mapVariant_ == "BIPOLAR" then
            local side = (math.random() < 0.5) and -1 or 1
            -- 左/右簇：x 中心在 ±1200，散布 ±800；y 分布全范围
            x = side * (1000 + math.random() * 800) + (math.random() - 0.5) * 400
            y = (math.random() - 0.5) * 4000
        else
            x = (math.random() - 0.5) * spread
            y = (math.random() - 0.5) * spread
        end

        local sys   = {
            id=i, name=name, type=stype, x=x, y=y,
            radius = 12 + math.random() * 8,
            resBonus = resBonus,  -- P2-2: 资源加成倍率
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
                -- P3-3: 卫星视觉装饰（0-2颗随机卫星）
                satellites  = (function()
                    local MOON_COLORS = {
                        Terran        = {180, 190, 170},   -- 灰绿
                        Desert        = {210, 175, 110},   -- 沙黄
                        Oceanic       = {130, 160, 220},   -- 蓝灰
                        Volcanic      = {190, 100,  70},   -- 暗橙
                        Barren        = {155, 145, 135},   -- 冷灰
                        ["Gas Giant"] = {190, 165, 230},   -- 淡紫
                    }
                    local moonColor = MOON_COLORS[ptype] or {160, 160, 160}
                    local count = math.random(0, 2)
                    local moons = {}
                    for mi = 1, count do
                        local orbitR = (pi == nil and 1 or pi) * 0  -- 仅用 size 派生
                        orbitR = (5 + math.random() * 6) + (mi - 1) * 5  -- 内层 5-11, 外层 +5
                        moons[mi] = {
                            orbitR  = orbitR,                            -- 相对行星半径的轨道半径（世界单位=px/zoom）
                            angle0  = math.random() * math.pi * 2,      -- 初始角度
                            period  = 15 + math.random() * 25,          -- 公转周期（秒）
                            radius  = 2 + math.random() * 2,            -- 卫星半径（屏幕 px）
                            color   = {
                                math.max(0, math.min(255, moonColor[1] + math.random(-20, 20))),
                                math.max(0, math.min(255, moonColor[2] + math.random(-20, 20))),
                                math.max(0, math.min(255, moonColor[3] + math.random(-20, 20))),
                            },
                        }
                    end
                    return moons
                end)(),
            }
        end
        starSystems_[i] = sys
    end
