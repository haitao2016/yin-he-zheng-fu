-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
    planet.colonized     = true
    planet.owner         = "player"
    planet.level         = 1              -- P1-2: 新殖民星球初始 Lv.1
    planet.colonizeTime  = routeAnimT_   -- P3-2: 记录殖民时刻，驱动地貌动画
    colonizedPlanets_[#colonizedPlanets_+1] = planet   -- 维护殖民缓存
    local leveled, newLevel, newRank, rewards
    if player_ then
        player_.colonized = (player_.colonized or 0) + 1
        leveled, newLevel, newRank, rewards = player_:addExp(100)
    end
    if bs_ then
        bs_:build("MINE", planet)
    end
    -- P3-1: 触发殖民涟漪动画（保存行星引用，渲染时用 _sx/_sy）
    colonyRipples_[#colonyRipples_+1] = {
        planet = planet,
        t      = 0,
        dur    = 2.8,
    }
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
    -- P3-1: 信号按钮点击检测（仅基地展开后）
    if seedShip_.state == "deployed" then
        local BW  = 44              -- 按钮宽高
        local PAD = 8               -- 按钮与屏幕右边缘/底部的间距
        local btnX = screenW_ - BW - PAD
        local btnY = screenH_ - BW - PAD - 50   -- 避开小地图

        -- 点击 📡 主按钮：切换面板展开/收起
        if mx >= btnX and mx <= btnX+BW and my >= btnY and my <= btnY+BW then
            signalOpen_ = not signalOpen_
            return
        end

        -- 面板展开时：检测各信号条目点击
        if signalOpen_ then
            local ITEM_H  = 40
            local PANEL_W = 180
            local panelX  = screenW_ - PANEL_W - PAD
            local panelY  = btnY - #QUICK_SIGNALS * ITEM_H - 8

            if mx >= panelX and mx <= panelX + PANEL_W
               and my >= panelY and my <= btnY - 8 then
                local idx = math.floor((my - panelY) / ITEM_H) + 1
                if idx >= 1 and idx <= #QUICK_SIGNALS then
                    local sig = QUICK_SIGNALS[idx]
                    local cd  = signalCooldowns_[idx]
                    if not cd or cd <= 0 then
                        -- 发送信号：添加横幅 + 设置 CD
                        signalCooldowns_[idx] = SIGNAL_CD
                        local Client = require("network.Client")
                        local playerName = Client.GetPlayerName and Client.GetPlayerName() or "指挥官"
                        signalBanners_[#signalBanners_+1] = {
                            text  = playerName .. "：" .. sig.icon .. " " .. sig.text,
                            alpha = 255,
                            timer = 0,
                            color = sig.color,
                        }
                        if notifyFn_ then
                            notifyFn_("信号已发送：" .. sig.text, "info")
                        end
                    end
                    signalOpen_ = false  -- 选择后收起面板
                end
                return
            end

            -- 点击面板外：收起面板
            signalOpen_ = false
        end
    end

    -- 种子飞船未展开时：点击地图空白处设置移动目标
    if seedShip_.state == "moving" then
        local wx, wy = s2w(mx, my)
        seedClickTarget_ = { x = wx, y = wy }
        return
    end

    -- 检测随机事件节点点击（基地展开后）
    if seedShip_.state == "deployed" then
        for _, ev in ipairs(GalaxyEvents.GetList()) do
            if not ev.claimed then
                local esx, esy = w2s(ev.x, ev.y)
                if dist2(mx, my, esx, esy) < 22 then
                    ev.claimed = true
                    if onGalaxyEvent_ then
                        onGalaxyEvent_(ev)
                    end
                    return
                end
            end
        end
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
                -- P3-3 V2.0: 双击检测 → 平滑居中到该行星
                local now = totalTime_
                local ddx = mx - lastClickX_
                local ddy = my - lastClickY_
                local isDouble = (now - lastClickTime_) < DOUBLE_CLICK_DT
                    and math.sqrt(ddx*ddx + ddy*ddy) < DOUBLE_CLICK_R
                if isDouble then
                    -- 计算目标相机位置（将行星世界坐标居中）
                    local pw = sys.x + math.cos(p.angle) * p.orbitRadius
                    local ph = sys.y + math.sin(p.angle) * p.orbitRadius
                    local cx = screenW_ / 2
                    local cy = screenH_ / 2
                    local targetCX = cx - pw
                    local targetCY = cy - ph
                    camPanAnim_ = { sx=camera_.x, sy=camera_.y,
                                    tx=targetCX,   ty=targetCY,
                                    t=0, dur=0.3 }
                    camVel_.x = 0
                    camVel_.y = 0
                    lastClickTime_ = 0  -- 重置，防止三击再次触发
                else
                    lastClickTime_ = now
                    lastClickX_    = mx
                    lastClickY_    = my
                end
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
    pirateAI_        = opts.pirateAI
    onGalaxyEvent_   = opts.onGalaxyEvent
    -- P1-3: 联赛修正器
    leagueMod_       = opts.leagueMod   -- nil if not league mode
    if leagueMod_ and rm_ then
        rm_.leagueResMult = leagueMod_.resMult or 1.0
    end
    -- P2-2: 战役模式使用 CAMPAIGN 变体（固定地图），普通模式随机选择
    if opts.campaign then
        mapVariant_ = "CAMPAIGN"
    else
        mapVariant_ = MAP_VARIANT_POOL[math.random(1, #MAP_VARIANT_POOL)]
    end

    -- P3-2: 初始化天气系统
    StarWeather.Init()
    -- 初始化随机事件系统（30~60s 后首次生成；战役模式禁用随机事件）
    GalaxyEvents.Reset()
    if not opts.campaign then
        -- P1-2 V2.0: 注入殖民星球列表提供者（灾害事件需要）
        GalaxyEvents.SetPlanetProvider(function()
            return allPlanets_
        end)
    end
    -- 加载所有游戏纹理
    local f = NVG_IMAGE_PREMULTIPLIED
    asteroidImgs_["minerals"] = nvgCreateImage(vg_, "image/asteroid_minerals_20260511190702.png", f)
    asteroidImgs_["energy"]   = nvgCreateImage(vg_, "image/asteroid_energy_20260511190703.png",   f)
    asteroidImgs_["crystal"]  = nvgCreateImage(vg_, "image/asteroid_crystal_20260511190707.png",  f)
    imgSeedShip_    = nvgCreateImage(vg_, "image/ship_seed_20260511190720.png",       f)
    imgBaseStation_ = nvgCreateImage(vg_, "image/base_station_20260511190708.png",    f)
    generateBgStars()
    -- P2-2: 战役模式使用固定星图（跳过种子生成器）
    if opts.campaign and opts.campaign.fixedStars then
        generateFixedStarSystems(opts.campaign.fixedStars)
        currentSeed_  = nil
        currentShape_ = nil
        specialPlanets_ = {}
    else
        -- P1-1: 种子驱动程序化生成
        local seed = opts.seed
        if not seed and opts.leagueSeed then
            -- 联赛模式：从数字种子派生6字符种子码
            seed = GalaxyGenerator.NumberToSeed(opts.leagueSeed % (36^6))
        end
        if not seed then
            seed = GalaxyGenerator.RandomSeed()
        end
        local result = GalaxyGenerator.Generate(seed)
        -- 写入模块级状态
        starSystems_      = result.starSystems
        deepSpaceSystems_ = result.deepSpaceSystems
        currentSeed_      = seed
        currentShape_     = result.shape
        specialPlanets_   = result.specialPlanets
        -- 填充平铺缓存
        allPlanets_       = result.allPlanets
        colonizedPlanets_ = {}
        -- 设置 mapVariant_ 以兼容海盗基地生成等下游逻辑
        mapVariant_ = "NORMAL"
        print(string.format("[GalaxyScene] Seed=%s Shape=%s Stars=%d DS=%d Planets=%d Special=%d",
            seed, result.shape, #starSystems_, #deepSpaceSystems_, #allPlanets_, #specialPlanets_))
    end
    generateAsteroids()
    -- 生成海盗基地
    if pirateAI_ then
        if opts.campaign and opts.campaign.fixedPirateBases then
            -- P2-2: 战役模式使用固定海盗基地位置
            pirateAI_:generateFixedBases(opts.campaign.fixedPirateBases)
        else
            pirateAI_:generateBases(2000, mapVariant_ == "BIPOLAR" and { bipolar=true } or nil)
        end
    end
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- 种子飞船位置：战役模式使用固定位置，普通模式随机
    if opts.campaign and opts.campaign.seedPos then
        seedShip_.x = opts.campaign.seedPos.x
        seedShip_.y = opts.campaign.seedPos.y
    else
        seedShip_.x = (math.random() - 0.5) * 3000
        seedShip_.y = (math.random() - 0.5) * 3000
    end
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

    -- P2-2: 开局通知星图变体
    local VARIANT_LABELS = {
        NORMAL   = { text="星图类型：标准星域",   color="info"    },
        DENSE    = { text="星图类型：密集星团 — 星系富集，资源丰厚", color="success" },
        SPARSE   = { text="星图类型：稀疏星野 — 星系稀疏，探索漫长", color="warn"    },
        BIPOLAR  = { text="星图类型：双极星域 — 两簇对立，中线险峻", color="danger"  },
        CAMPAIGN = { text="⚔ 战役模式 — 固定星图，按指示完成任务", color="info"    },
    }
    local vl = VARIANT_LABELS[mapVariant_] or VARIANT_LABELS.NORMAL
    if notifyFn_ then
        notifyFn_(vl.text, vl.color)
    end

    print("[GalaxyScene] 初始化完成, 星图变体: " .. mapVariant_
        .. ", 恒星系数: " .. #starSystems_
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

--- P1-3: 选中指定星球（帝国面板跳转用）
function GalaxyScene.SelectPlanet(planet)
    if planet then selectedPlanet_ = planet end
end

--- P2-2: 获取当前星图变体字符串（"NORMAL"/"DENSE"/"SPARSE"/"BIPOLAR"）
function GalaxyScene.GetMapVariant()
    return mapVariant_
end

-- P1-1: 种子系统公开 API
function GalaxyScene.GetSeed()
    return currentSeed_
end

function GalaxyScene.GetGalaxyShape()
    return currentShape_
end

function GalaxyScene.GetSpecialPlanets()
    return specialPlanets_
end

-- P2-1: 殖民优先标记 API
function GalaxyScene.TogglePriority(planet)
    if not planet or planet.colonized or planet.isBase then return end
    local id = planet.id
    if priorityPlanetIds_[id] then
        priorityPlanetIds_[id] = nil
    else
        priorityPlanetIds_[id] = true
    end
end

function GalaxyScene.IsPriority(planet)
    if not planet then return false end
    return priorityPlanetIds_[planet.id] == true
end

function GalaxyScene.GetPriorityPlanetCount()
    local n = 0
    for _ in pairs(priorityPlanetIds_) do n = n + 1 end
    return n
end

--- P1-2 WARP_GATE_PRIME: 将所有玩家编队瞬移至目标星球坐标
---@param targetPlanet table  星球对象（需有 x, y 字段）
---@return boolean  是否成功（有编队且坐标有效）
function GalaxyScene.WarpFleetToPlanet(targetPlanet)
    if not targetPlanet or not targetPlanet.x or not targetPlanet.y then
        return false
    end
    local wx, wy = targetPlanet.x, targetPlanet.y
    local count  = 0
    for fleetId, obj in pairs(fleetObjs_) do
        -- 仅瞬移玩家编队（非海盗）
        if fm_ and fm_.fleets[fleetId] then
            local spread = count * 18
            local ang    = (count * 2.4)  -- 按黄金角散布，避免重叠
            obj.x       = wx + math.cos(ang) * spread
            obj.y       = wy + math.sin(ang) * spread
            obj.targetX = nil
            obj.targetY = nil
            count = count + 1
        end
    end
    print("[GalaxyScene] WARP_GATE_PRIME: " .. count .. " 支编队瞬移至 " .. (targetPlanet.name or "?"))
    return count > 0
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
    -- P3-2: 应用星图天气速度修正
    local weatherMod = StarWeather.GetSpeedMod()
    return base * mult * weatherMod
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
    screenW_, screenH_ = UICommon.getVirtualSize()
    totalTime_      = totalTime_ + dt
    deepSpaceAnimT_ = deepSpaceAnimT_ + dt
    routeAnimT_     = routeAnimT_ + dt

    -- P3-2: 动态星图天气更新
    StarWeather.Update(dt)

    -- P3-3 V2.0: 相机惯性衰减（松手后滑动，速度×0.88/帧 直到 < 0.5px/frame 停止）
    if not isDragging_ and (camVel_.x ~= 0 or camVel_.y ~= 0) then
        -- camPanAnim_ 运行时不叠加惯性（避免动画被打断）
        if not camPanAnim_ then
            camera_.x = camera_.x + camVel_.x * dt
            camera_.y = camera_.y + camVel_.y * dt
        end
        local decay = 0.88
        camVel_.x = camVel_.x * decay
        camVel_.y = camVel_.y * decay
        -- 速度足够小时清零
        if math.abs(camVel_.x) < 0.5 and math.abs(camVel_.y) < 0.5 then
            camVel_.x = 0
            camVel_.y = 0
        end
    end

    -- P3-3 V2.0: 弹性缩放（超出边界时以 spring 系数 0.18 弹回）
    if zoom_ < ZOOM_MIN then
        zoom_ = zoom_ + (ZOOM_MIN - zoom_) * 0.18
        if zoom_ >= ZOOM_MIN - 0.005 then zoom_ = ZOOM_MIN end
    elseif zoom_ > ZOOM_MAX then
        zoom_ = zoom_ + (ZOOM_MAX - zoom_) * 0.18
        if zoom_ <= ZOOM_MAX + 0.005 then zoom_ = ZOOM_MAX end
    end

    -- P3-3 V2.0: 双击居中平滑动画（0.3s ease-out）
    if camPanAnim_ then
        local a = camPanAnim_
        a.t = a.t + dt
        local progress = math.min(1, a.t / a.dur)
        -- ease-out cubic
        local p = 1 - (1 - progress)^3
        camera_.x = a.sx + (a.tx - a.sx) * p
        camera_.y = a.sy + (a.ty - a.sy) * p
        if progress >= 1 then
            camera_.x = a.tx
            camera_.y = a.ty
            camPanAnim_ = nil
        end
    end
    -- P3-1: 推进殖民涟漪动画并清理结束项
    if #colonyRipples_ > 0 then
        local alive = {}
        for _, r in ipairs(colonyRipples_) do
            r.t = r.t + dt
            if r.t < r.dur then
                alive[#alive+1] = r
            end
        end
        colonyRipples_ = alive
    end
    -- P3-1: 更新信号 CD
    for i, cd in pairs(signalCooldowns_) do
        signalCooldowns_[i] = cd - dt
        if signalCooldowns_[i] <= 0 then
            signalCooldowns_[i] = nil
        end
    end
    -- P3-1: 更新横幅动画（淡出并清理过期横幅）
    if #signalBanners_ > 0 then
        local alive = {}
        for _, b in ipairs(signalBanners_) do
            b.timer = b.timer + dt
            if b.timer < BANNER_DUR then
                -- 淡出：最后 BANNER_FADE 秒渐隐
                local fadeStart = BANNER_DUR - BANNER_FADE
                if b.timer > fadeStart then
                    b.alpha = math.floor(255 * (1 - (b.timer - fadeStart) / BANNER_FADE))
                else
                    b.alpha = 255
                end
                alive[#alive+1] = b
            end
        end
        signalBanners_ = alive
    end
    updateSeedShip(dt)
    updatePlanets(dt)
    updateHover()
    updateFleets(dt)
    -- 海盗 AI 更新
    if pirateAI_ then pirateAI_:update(dt) end
    -- 随机事件更新
    GalaxyEvents.Update(dt, seedShip_.colonized, seedShip_.x, seedShip_.y)
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


function GalaxyScene.Render()
    if #bgStars_ == 0 then return end  -- Init 尚未完成，跳过渲染

    -- 同步局部状态到共享状态表 GS（子模块读取）
    GS.vg              = vg_
    GS.screenW         = screenW_
    GS.screenH         = screenH_
    GS.camera          = camera_
    GS.zoom            = zoom_
    GS.totalTime       = totalTime_
    GS.deepSpaceAnimT  = deepSpaceAnimT_
    GS.routeAnimT      = routeAnimT_
    GS.bgStars         = bgStars_
    GS.starSystems     = starSystems_
    GS.deepSpaceSystems = deepSpaceSystems_
    GS.allPlanets      = allPlanets_
    GS.colonizedPlanets = colonizedPlanets_
    GS.priorityPlanetIds = priorityPlanetIds_
    GS.garrisonedFleets = garrisonedFleets_
    GS.colonyRipples   = colonyRipples_
    GS.specialPlanets  = specialPlanets_
    GS.fleetObjs       = fleetObjs_
    GS.asteroids       = asteroids_
    GS.expeditionPaths = expeditionPaths_
    GS.selectedPlanet  = selectedPlanet_
    GS.hoveredPlanet   = hoveredPlanet_
    GS.hoveredAsteroid = hoveredAsteroid_
    GS.selectedFleetId = selectedFleetId_
    GS.mouseX          = mouseX_
    GS.mouseY          = mouseY_
    GS.fm              = fm_
    GS.player          = player_
    GS.bs              = bs_
    GS.rm              = rm_
    GS.pirateAI        = pirateAI_
    GS.seedShip        = seedShip_
    GS.signalOpen      = signalOpen_
    GS.signalCooldowns = signalCooldowns_
    GS.signalBanners   = signalBanners_
    GS.asteroidImgs    = asteroidImgs_
    GS.imgSeedShip     = imgSeedShip_
    GS.imgBaseStation  = imgBaseStation_
    GS.diploRelData    = diploRelData_
    GS.fleetColorCache = fleetColorCache_
    GS.mapVariant      = mapVariant_
    GS.currentSeed     = currentSeed_
    GS.currentShape    = currentShape_

    GalaxyRender.Draw()
end

-- ============================================================================
-- 输入处理（由 main.lua 调用）
-- ============================================================================
function GalaxyScene.OnMouseDown(mx, my)
    isDragging_ = true
    dragStart_  = { x=mx, y=my }
    camAtDrag_  = { x=camera_.x, y=camera_.y }
    dragDist_   = 0
    -- P3-3 V2.0: 开始新拖拽时清除惯性速度和居中动画
    camVel_.x   = 0
    camVel_.y   = 0
    camPanAnim_ = nil
    dragLastX_  = mx
    dragLastY_  = my
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
    -- P3-3 V2.0: 采样当前帧速度（屏幕像素/秒 → 世界单位/秒）
    local frameVx = (mx - dragLastX_) / zoom_
    local frameVy = (my - dragLastY_) / zoom_
    -- 低通滤波混合（避免单帧抖动）
    camVel_.x = camVel_.x * 0.4 + frameVx * 0.6 * 60   -- *60 换算到 /秒
    camVel_.y = camVel_.y * 0.4 + frameVy * 0.6 * 60
    dragLastX_ = mx
    dragLastY_ = my
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
        -- P3-3 V2.0: 短点击时清除惯性（避免误滑动）
        camVel_.x = 0
        camVel_.y = 0
        -- 判断是否点击在小地图区域内
        local mmx, mmy, mmw, mmh = minimapRect()
        if mx >= mmx and mx <= mmx+mmw and my >= mmy and my <= mmy+mmh then
            teleportToMinimap(mx, my)
        else
            handleClick(mx, my)
        end
    end
    -- P3-3 V2.0: 拖拽结束后惯性速度已在 OnMouseMove 中采样，自然保留
end

--- 鼠标滚轮缩放（delta > 0 = 放大, < 0 = 缩小）
--- 以鼠标位置为缩放中心
function GalaxyScene.OnMouseWheel(mx, my, delta)
    local oldZoom = zoom_
    -- P3-3 V2.0: 允许 10% 超出弹性区间，Update 中弹回
    local softMin = ZOOM_MIN * 0.90
    local softMax = ZOOM_MAX * 1.10
    zoom_ = math.max(softMin, math.min(softMax, zoom_ + delta * 0.12))
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
        -- P3-3 V2.0: 捏合开始时清除惯性
        camVel_.x   = 0
        camVel_.y   = 0
    else
        -- 第一根手指：初始化单指拖拽
        isDragging_ = true
        dragStart_  = { x = lx, y = ly }
        camAtDrag_  = { x = camera_.x, y = camera_.y }
        dragDist_   = 0
        pinchDist_  = nil
        -- P3-3 V2.0: 触摸开始清除惯性和居中动画
        camVel_.x   = 0
        camVel_.y   = 0
        camPanAnim_ = nil
        dragLastX_  = lx
        dragLastY_  = ly
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
            -- P3-3 V2.0: 允许弹性超出
            zoom_ = math.max(ZOOM_MIN * 0.90, math.min(ZOOM_MAX * 1.10, zoom_ * scale))
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
        -- P3-3 V2.0: 采样速度
        local frameVx = (lx - dragLastX_) / zoom_
        local frameVy = (ly - dragLastY_) / zoom_
        camVel_.x = camVel_.x * 0.4 + frameVx * 0.6 * 60
        camVel_.y = camVel_.y * 0.4 + frameVy * 0.6 * 60
        dragLastX_ = lx
        dragLastY_ = ly
    end
end

function GalaxyScene.OnTouchEnd(id, x, y)
    local dpr = graphics:GetDPR()
    local lx, ly = x / dpr, y / dpr

    -- 单指短点击（未捏合）→ 触发 handleClick
    if touchCount() == 1 and isDragging_ and dragDist_ < 8 then
        -- P3-3 V2.0: 短点击时清除惯性（避免误触发滑动）
        camVel_.x = 0
        camVel_.y = 0
        handleClick(lx, ly)
    end
    -- P3-3 V2.0: 非点击松手时惯性已通过速度采样自动保留

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
            -- P3-3 V2.0: 剩余手指接管时重置速度采样基准
            dragLastX_  = t.x
            dragLastY_  = t.y
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
                        spec        = b.spec,  -- P2-3
                    }
                end
                local appliedTechs = {}
                for techId, _ in pairs(p.appliedTechs or {}) do
                    appliedTechs[#appliedTechs + 1] = techId
                end
                planets[#planets + 1] = {
                    id           = p.id,
                    colonized    = true,
                    level        = p.level or 1,   -- P1-2: 星球等级
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
                        key = b.key, name = b.name, level = b.level, currentProd = prod,
                        spec = b.spec,  -- P2-3
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
    -- P2-1: 优先标记列表
    local priorityIds = {}
    for id, _ in pairs(priorityPlanetIds_) do
        priorityIds[#priorityIds + 1] = id
    end
    return { planets = planets, base = base, deepPlanets = deepPlanets, fleets = fleets,
             priorityIds = priorityIds,
             seed = currentSeed_, shape = currentShape_ }  -- P1-1: 保存种子
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
                p.level        = pd.level or 1   -- P1-2: 旧存档兼容，默认 Lv.1
                p.buildings    = {}
                p.appliedTechs = {}
                -- 恢复建筑
                for _, bd in ipairs(pd.buildings or {}) do
                    local bld = {
                        key         = bd.key,
                        name        = bd.name,
                        level       = bd.level,
                        currentProd = {},
                        spec        = bd.spec,  -- P2-3
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
                    local bld = { key = bd.key, name = bd.name, level = bd.level, currentProd = {}, spec = bd.spec }  -- P2-3
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

    -- P2-1: 恢复优先标记
    priorityPlanetIds_ = {}
    if data.priorityIds then
        for _, id in ipairs(data.priorityIds) do
            priorityPlanetIds_[id] = true
        end
    end
end

--- 释放纹理句柄（softReset 前调用，避免重复 Init 泄漏图片）
--- P3-1: 外部触发显示信号横幅（供 Client.lua 接收到其他玩家信号时调用）
function GalaxyScene.ShowSignalBanner(senderName, sigIcon, sigText, sigColor)
    signalBanners_[#signalBanners_+1] = {
        text  = (senderName or "指挥官") .. "：" .. (sigIcon or "") .. " " .. (sigText or ""),
        alpha = 255,
        timer = 0,
        color = sigColor or {80, 180, 255},
    }
end

-- ============================================================================
-- P2-1: 舰队驻守星球系统 API
-- ============================================================================

--- 将指定编队驻守到目标星球
---@param fleetId number 编队ID
---@param planet table 目标星球（必须已殖民）
---@return boolean, string
function GalaxyScene.GarrisonFleet(fleetId, planet)
    if not planet or not planet.colonized then
        return false, "目标星球尚未殖民"
    end
    -- 解除旧驻守（同一编队只能驻守一处）
    garrisonedFleets_[fleetId] = planet
    return true, ""
end

--- 召回驻守编队（取消驻守）
---@param fleetId number 编队ID
function GalaxyScene.RecallGarrison(fleetId)
    garrisonedFleets_[fleetId] = nil
end

--- 查询编队是否正在驻守某星球
---@param fleetId number 编队ID
---@return table|nil  驻守的星球，或 nil
function GalaxyScene.GetGarrisonedPlanet(fleetId)
    return garrisonedFleets_[fleetId]
end

--- 查询星球上的驻守编队 ID（第一支）
---@param planet table
---@return number|nil
function GalaxyScene.GetGarrisonFleetId(planet)
    for fid, gp in pairs(garrisonedFleets_) do
        if gp == planet then return fid end
    end
    return nil
end

--- 返回全部驻守关系（只读副本）：{ {fleetId, planet} }
function GalaxyScene.GetAllGarrisons()
    local result = {}
    for fid, gp in pairs(garrisonedFleets_) do
        result[#result + 1] = { fleetId = fid, planet = gp }
    end
    return result
end

--- softReset 时清除所有驻守关系
function GalaxyScene.ClearGarrisons()
    garrisonedFleets_ = {}
    diploRelData_ = nil
end

-- ============================================================================
-- P1-2: 远征系统公开 API
-- ============================================================================

--- 设置当前远征列表（由 Client.lua 每帧同步）
---@param exps table[] 远征数据数组
function GalaxyScene.SetExpeditions(exps)
    expeditionPaths_ = exps or {}
end

--- P1-1: 设置外交关系数据（由 Client.lua 周期同步）
---@param rels table[] 关系列表 [{fk1, fk2, rel}]
---@param agreements table 协议数据 {alliances, blockades, intelShares}
function GalaxyScene.SetDiploRelations(rels, agreements)
    diploRelData_ = { rels = rels or {}, agreements = agreements or {} }
end

--- 获取编队速度（公开包装，供 Client.lua 计算远征时间）
---@param fleetId number
---@return number 速度值
function GalaxyScene.GetFleetSpeed(fleetId)
    return getFleetSpeed(fleetId)
end

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
