-- ============================================================================
-- game/BattleScene.lua  -- 战术战斗场景
-- ============================================================================

local Audio    = require("game.AudioManager")
local UICommon = require("game.ui.UICommon")

local BattleScene = {}

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_           = nil
local screenW_      = 800
local screenH_      = 600

-- 舰船纹理（NanoVG image handles）
local shipImages_   = {}  -- { SCOUT=handle, FRIGATE=handle, DESTROYER=handle, MINER=handle }

local playerFleet_  = {}
local enemyFleet_   = {}
local projectiles_  = {}   -- {x,y,tx,ty,team,life}
local floatTexts_   = {}   -- {x,y,text,life,maxLife,vy,team}
local moveTarget_   = nil  -- 玩家舰队移动目标点
local moveTargetTimer_ = 0 -- 移动目标点自动消失计时

local state_        = "fighting"  -- "fighting" | "win" | "lose"
local stateTimer_   = 0
local battleEndFired_ = false  -- 防止 onBattleEnd_ 被每帧重复触发
local shootSfxTimer_ = 0       -- 射击音效节流（避免同帧多舰齐射时音效叠加爆音）
local loseBtn1_     = nil      -- M2: 战败"重新战斗"按钮区域
local loseBtn2_     = nil      -- M2: 战败"返回星图"按钮区域
local notifyFn_     = nil
local onBattleEnd_  = nil  -- 回调：战斗结束
local player_       = nil
local rm_           = nil  -- ResourceManager 引用（用于波次奖励）
local rs_           = nil  -- ResearchSystem 引用（技能解锁判断）
local spq_          = nil  -- ShipProductionQueue 引用

-- ============================================================================
-- 主动技能系统
-- ============================================================================
local SKILL1_CD       = 30   -- 全体集火：冷却时间（秒）
local SKILL1_DUR      = 5    -- 全体集火：持续时间（秒）
local SKILL2_CD       = 60   -- 紧急修复：冷却时间（秒）
local CARRIER_DRONE_CD= 15   -- CARRIER 无人机自动召唤间隔（秒）

local skill1CD_       = 0    -- 全体集火：剩余冷却
local skill1Active_   = 0    -- 全体集火：激活剩余秒数（>0 表示激活中）
local skill2CD_       = 0    -- 紧急修复：剩余冷却
local carrierDroneCD_ = 0    -- CARRIER 无人机召唤计时
local skillBtn1_      = nil  -- 技能按钮1 点击区域
local skillBtn2_      = nil  -- 技能按钮2 点击区域

-- 波次系统
local waveNum_      = 1     -- 当前波次
local WAVE_GAP      = 3.0   -- 胜利后等待下一波的秒数
local waveGapTimer_ = 0     -- 倒计时

-- 新生产出的舰船临时存储（等待加入战场）
local pendingShips_ = {}

-- 燃烧粒子系统（低血量舰船火焰效果）
local fireParticles_ = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,size}
local fireTimer_     = 0   -- 粒子生成节流

-- 爆炸粒子系统（舰船被摧毁时的碎片爆炸）
local explParticles_ = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,size,type}

-- 屏幕震动系统
local shakeTimer_    = 0   -- 震动剩余时间
local shakeDur_      = 0   -- 震动总时长
local shakeStrength_ = 0   -- 震动强度（像素）
local shakeOffX_     = 0   -- 当前帧震动偏移 X
local shakeOffY_     = 0   -- 当前帧震动偏移 Y

-- 烟花粒子系统（波次胜利特效）
local fwParticles_   = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,tail}
local fwLaunchTimer_ = 0   -- 下次发射烟花的倒计时

-- INTERCEPTOR 引擎音效节流
local interceptorEngineTimer_ = 0   -- 距离下次允许播放的冷却（秒）

-- ============================================================================
-- 舰船工厂
-- ============================================================================
local function makeShip(stype, x, y, team)
    local cfg = SHIP_TYPES[stype]
    -- S1 HULL_ALLOY / ADVANCED_WEAPONS: 玩家舰队应用科技加成
    local hm = 1.0
    local dm = 1.0
    if team == "player" and rm_ and rm_.baseBonus then
        hm = rm_.baseBonus.shipHealthMult or 1.0
        dm = rm_.baseBonus.shipDmgMult    or 1.0
    end
    local hp = math.floor(cfg.health * hm)
    return {
        x        = x,      y=y,
        vx       = 0,      vy=0,
        team     = team,
        stype    = stype,
        speed    = cfg.speed,
        health   = hp,
        maxHealth= hp,
        range    = cfg.range,
        dmg      = cfg.dmg * dm,
        color    = cfg.color,
        lastShot = 0,
        shotRate  = cfg.shotRate or 1.0,
        aoeRadius = cfg.aoeRadius or 0,  -- 溅射半径，0 表示单体攻击
        target    = nil,
        attackTarget = nil,
        hitFlash  = 0,   -- 受击闪白强度（1.0=刚受击，0=正常）
    }
end

-- ============================================================================
-- 波次配置（波次越高敌舰越强）
-- ============================================================================
local function buildEnemyWave(wave)
    local fleet = {}
    local battleH = screenH_ - 88
    -- 基础敌舰数 = 2 + wave，上限随波次提高
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
    for i = 1, count do
        local stype
        local roll = math.random()
        if wave <= 1 then
            stype = roll < 0.7 and "SCOUT" or "FRIGATE"
        elseif wave <= 3 then
            stype = roll < 0.4 and "SCOUT" or (roll < 0.8 and "FRIGATE" or "DESTROYER")
        elseif wave <= 5 then
            stype = roll < 0.2 and "SCOUT" or (roll < 0.6 and "FRIGATE" or "DESTROYER")
        elseif wave <= 9 then
            -- 波次 6-9：战列舰 + 开始混入拦截舰群
            if roll < 0.15 then
                stype = "BATTLECRUISER"
            elseif roll < 0.40 then
                stype = "INTERCEPTOR"  -- 廉价快速，成群出现
            elseif roll < 0.70 then
                stype = "DESTROYER"
            else
                stype = "FRIGATE"
            end
        else
            -- 波次 10+：母舰时代，拦截舰大量出现
            if roll < 0.10 then
                stype = "BATTLECRUISER"
            elseif roll < 0.45 then
                stype = "INTERCEPTOR"
            elseif roll < 0.65 then
                stype = "DESTROYER"
            else
                stype = "FRIGATE"
            end
        end
        local x = screenW_ - 100 - math.random() * 100
        local y = 88 + battleH * 0.05 + math.random() * battleH * 0.9
        fleet[#fleet+1] = makeShip(stype, x, y, "enemy")
    end
    -- 波次 8+：额外添加 1 艘敌方战列舰作为 Boss 级旗舰
    if wave >= 8 then
        local x = screenW_ - 60 - math.random() * 40
        local y = 88 + battleH * 0.3 + math.random() * battleH * 0.4
        fleet[#fleet+1] = makeShip("BATTLECRUISER", x, y, "enemy")
    end
    -- 波次 10+：额外派遣 1 艘敌方母舰压阵
    if wave >= 10 then
        local x = screenW_ - 50 - math.random() * 30
        local y = 88 + battleH * 0.35 + math.random() * battleH * 0.3
        fleet[#fleet+1] = makeShip("CARRIER", x, y, "enemy")
    end
    return fleet
end

-- ============================================================================
-- 波次预报：纯预测，无随机，返回下一波的舰型组成
-- ============================================================================
-- 返回格式: { total=N, groups={ {stype, name, count, isBoss} } }
local function getNextWavePreview(wave)
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
    -- 各舰型期望比例（与 buildEnemyWave 概率一致）
    local distrib
    if wave <= 1 then
        distrib = { {s="SCOUT",0.70},{s="FRIGATE",0.30} }
    elseif wave <= 3 then
        distrib = { {s="SCOUT",0.40},{s="FRIGATE",0.40},{s="DESTROYER",0.20} }
    elseif wave <= 5 then
        distrib = { {s="SCOUT",0.20},{s="FRIGATE",0.20},{s="DESTROYER",0.60} }
    elseif wave <= 9 then
        distrib = { {s="BATTLECRUISER",0.15},{s="INTERCEPTOR",0.25},{s="DESTROYER",0.30},{s="FRIGATE",0.30} }
    else
        distrib = { {s="BATTLECRUISER",0.10},{s="INTERCEPTOR",0.35},{s="DESTROYER",0.20},{s="FRIGATE",0.35} }
    end
    local groups = {}
    for _, d in ipairs(distrib) do
        local est = math.max(1, math.floor(count * d[2] + 0.5))
        local cfg = SHIP_TYPES[d.s]
        groups[#groups+1] = { stype=d.s, name=(cfg and cfg.name or d.s), count=est }
    end
    -- Boss 单位（固定额外出现）
    if wave >= 8 then
        groups[#groups+1] = { stype="BATTLECRUISER", name="旗舰", count=1, isBoss=true }
    end
    if wave >= 10 then
        groups[#groups+1] = { stype="CARRIER", name="母舰", count=1, isBoss=true }
    end
    return { total=count, groups=groups }
end

-- ============================================================================
-- 初始化战场
-- ============================================================================
function BattleScene.Init(opts)
    vg_          = opts.vg
    notifyFn_    = opts.notifyFn
    onBattleEnd_ = opts.onBattleEnd
    player_      = opts.player
    rm_          = opts.rm
    rs_          = opts.rs
    spq_         = opts.spq
    pendingShips_= {}
    -- 海盗进攻时从指定波次开始（pirateLevel 1~5 对应 wave 1~5）
    waveNum_     = math.max(1, opts.startWave or 1)

    -- 加载舰船纹理
    local imageFlags = NVG_IMAGE_PREMULTIPLIED
    shipImages_["SCOUT"]         = nvgCreateImage(vg_, "image/ship_scout_20260511185829.png",         imageFlags)
    shipImages_["FRIGATE"]       = nvgCreateImage(vg_, "image/ship_frigate_20260511185830.png",       imageFlags)
    shipImages_["DESTROYER"]     = nvgCreateImage(vg_, "image/ship_destroyer_20260511185818.png",     imageFlags)
    shipImages_["BATTLECRUISER"] = nvgCreateImage(vg_, "image/ship_battlecruiser_20260512164935.png", imageFlags)
    shipImages_["MINER"]         = nvgCreateImage(vg_, "image/ship_miner_20260511185819.png",         imageFlags)
    shipImages_["ENGINEER"]      = nvgCreateImage(vg_, "image/ship_engineer_20260512071656.png",      imageFlags)
    shipImages_["EXPLORER"]      = nvgCreateImage(vg_, "image/ship_explorer_20260512071647.png",      imageFlags)
    shipImages_["CARRIER"]       = nvgCreateImage(vg_, "image/ship_carrier_20260513074052.png",       imageFlags)
    shipImages_["INTERCEPTOR"]   = nvgCreateImage(vg_, "image/ship_interceptor_20260513074045.png",   imageFlags)
    print("[BattleScene] 舰船纹理加载完成")

    BattleScene.Reset()
    print("[BattleScene] 初始化完成")
end

function BattleScene.Reset()
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- 基础玩家舰队
    local midY = (screenH_ + 88) / 2   -- 战场中线（排除顶部标题区）
    playerFleet_ = {
        makeShip("FRIGATE",  100, midY,      "player"),
        makeShip("SCOUT",    120, midY - 55, "player"),
        makeShip("SCOUT",    120, midY + 55, "player"),
    }
    -- 加入已生产的舰船
    for _, ps in ipairs(pendingShips_) do
        local x = 80 + math.random() * 60
        local y = screenH_*0.2 + math.random() * screenH_*0.6
        playerFleet_[#playerFleet_+1] = makeShip(ps, x, y, "player")
    end
    pendingShips_    = {}
    -- 根据波次生成敌方舰队
    enemyFleet_      = buildEnemyWave(waveNum_)
    projectiles_     = {}
    floatTexts_      = {}
    fireParticles_   = {}
    fireTimer_       = 0
    explParticles_   = {}
    shakeTimer_      = 0
    shakeStrength_   = 0
    shakeOffX_       = 0
    shakeOffY_       = 0
    fwParticles_            = {}
    fwLaunchTimer_          = 0
    interceptorEngineTimer_ = 0
    moveTarget_             = nil
    moveTargetTimer_ = 0
    state_           = "fighting"
    stateTimer_      = 0
    battleEndFired_  = false
    waveGapTimer_    = 0
    -- 技能状态重置（跨波次保留冷却，不重置）
    skill1Active_    = 0
    carrierDroneCD_  = CARRIER_DRONE_CD  -- 进入战场后立刻开始倒计时
    print("[BattleScene] 重置 Wave " .. waveNum_ .. "  我方: " .. #playerFleet_ .. "  敌方: " .. #enemyFleet_)
end

--- 从 ShipProductionQueue 获取新生产的舰船
function BattleScene.AddProductionShip(shipType)
    pendingShips_[#pendingShips_+1] = shipType
end

--- 手动开始新波次（保留我方存活舰船）
function BattleScene.StartNextWave()
    waveNum_ = waveNum_ + 1
    -- 保留存活玩家舰船
    local survivors = playerFleet_
    screenW_, screenH_ = UICommon.getVirtualSize()
    playerFleet_ = survivors
    -- 加入排队新舰
    for _, ps in ipairs(pendingShips_) do
        local x = 80 + math.random() * 60
        local y = screenH_*0.2 + math.random() * screenH_*0.6
        playerFleet_[#playerFleet_+1] = makeShip(ps, x, y, "player")
    end
    pendingShips_     = {}
    enemyFleet_       = buildEnemyWave(waveNum_)
    projectiles_      = {}
    floatTexts_       = {}
    moveTarget_       = nil
    moveTargetTimer_  = 0
    state_            = "fighting"
    stateTimer_       = 0
    battleEndFired_   = false
    waveGapTimer_     = 0
    Audio.Play(Audio.SFX.WAVE_INCOMING)
    if notifyFn_ then notifyFn_("第 " .. waveNum_ .. " 波敌军来袭！", "warn") end
    print("[BattleScene] Wave " .. waveNum_ .. " 开始  敌方: " .. #enemyFleet_)
end

-- ============================================================================
-- 工具
-- ============================================================================
local function dist2(x1,y1,x2,y2)
    local dx,dy = x2-x1, y2-y1
    return math.sqrt(dx*dx+dy*dy)
end

local function clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        local d = dist2(ship.x, ship.y, s.x, s.y)
        if d < bd then best=s; bd=d end
    end
    return best, bd
end

-- ============================================================================
-- 逻辑更新
-- ============================================================================
function BattleScene.Update(dt)
    shootSfxTimer_ = math.max(0, shootSfxTimer_ - dt)
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- === 主动技能计时 ===
    if state_ == "fighting" then
        skill1CD_      = math.max(0, skill1CD_      - dt)
        skill2CD_      = math.max(0, skill2CD_      - dt)
        -- 全体集火激活倒计时
        if skill1Active_ > 0 then
            skill1Active_ = skill1Active_ - dt
            if skill1Active_ <= 0 then
                skill1Active_ = 0
                if notifyFn_ then notifyFn_("集火结束", "info") end
            end
        end
        -- CARRIER 无人机自动召唤
        local hasCarrier = false
        for _, s in ipairs(playerFleet_) do
            if s.stype == "CARRIER" then hasCarrier = true; break end
        end
        if hasCarrier then
            carrierDroneCD_ = carrierDroneCD_ - dt
            if carrierDroneCD_ <= 0 then
                carrierDroneCD_ = CARRIER_DRONE_CD
                -- 召唤 2 架 SCOUT 无人机加入玩家舰队
                for k = 1, 2 do
                    local mx = 60 + math.random() * 80
                    local my = screenH_*0.2 + math.random() * screenH_*0.6
                    playerFleet_[#playerFleet_+1] = makeShip("SCOUT", mx, my, "player")
                end
                floatTexts_[#floatTexts_+1] = {
                    x=screenW_/2, y=screenH_*0.4,
                    text="CARRIER 召唤 2 架无人机", life=1.8, maxLife=1.8,
                    vy=-22, team="enemy"  -- 绿色飘字
                }
                if notifyFn_ then notifyFn_("CARRIER 召唤无人机！", "info") end
            end
        end
    end

    if state_ == "lose" then
        stateTimer_ = stateTimer_ + dt
        if stateTimer_ > 3.0 and onBattleEnd_ and not battleEndFired_ then
            battleEndFired_ = true
            onBattleEnd_("lose")
        end
        return
    end

    if state_ == "win" then
        -- 显示倒计时后自动进入下一波
        waveGapTimer_ = waveGapTimer_ + dt
        if waveGapTimer_ >= WAVE_GAP then
            BattleScene.StartNextWave()
        end
        -- 烟花粒子：周期性发射
        fwLaunchTimer_ = fwLaunchTimer_ - dt
        if fwLaunchTimer_ <= 0 then
            fwLaunchTimer_ = 0.22 + math.random() * 0.18
            -- 随机颜色
            local hue = math.random()
            local r = math.floor(128 + 127 * math.abs(math.sin(hue * math.pi * 2)))
            local g = math.floor(128 + 127 * math.abs(math.sin((hue + 0.33) * math.pi * 2)))
            local b = math.floor(128 + 127 * math.abs(math.sin((hue + 0.66) * math.pi * 2)))
            local cx = screenW_ * (0.15 + math.random() * 0.7)
            local cy = screenH_ * (0.1 + math.random() * 0.4)
            -- 爆炸碎片（18 粒）
            for _ = 1, 18 do
                local angle = math.random() * math.pi * 2
                local spd   = 55 + math.random() * 95
                fwParticles_[#fwParticles_+1] = {
                    x = cx, y = cy,
                    vx = math.cos(angle) * spd,
                    vy = math.sin(angle) * spd - 40,   -- 轻微上飘偏向
                    life = 0.7 + math.random() * 0.5,
                    maxLife = 1.2,
                    r = r, g = g, b = b,
                }
            end
        end
        -- 更新烟花粒子
        local i = 1
        while i <= #fwParticles_ do
            local p = fwParticles_[i]
            p.x    = p.x + p.vx * dt
            p.y    = p.y + p.vy * dt
            p.vy   = p.vy + 60 * dt   -- 重力
            p.life = p.life - dt
            if p.life <= 0 then
                fwParticles_[i] = fwParticles_[#fwParticles_]
                fwParticles_[#fwParticles_] = nil
            else
                i = i + 1
            end
        end
        return
    end

    -- === 玩家舰队 ===
    for _, ship in ipairs(playerFleet_) do
        if ship.target then
            local dx = ship.target.x - ship.x
            local dy = ship.target.y - ship.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if d > 4 then
                local spd = ship.speed * dt
                ship.x = ship.x + dx/d * spd
                ship.y = ship.y + dy/d * spd
                ship.vx = dx/d; ship.vy = dy/d
            else
                ship.target = nil
                ship.vx=0; ship.vy=0
            end
        end
        ship.x = clamp(ship.x, 10, screenW_-10)
        ship.y = clamp(ship.y, 88, screenH_-10)

        if #enemyFleet_ > 0 then
            local nearest, nd = findNearest(ship, enemyFleet_)
            if nearest and nd < ship.range then
                ship.lastShot = ship.lastShot + dt
                if ship.lastShot >= 1.0 / ship.shotRate then
                    ship.lastShot = 0
                    -- 全体集火：激活时伤害翻倍
                    local focusMult = (skill1Active_ > 0) and 2.0 or 1.0
                    local actualDmg = math.floor(ship.dmg * focusMult)
                    -- 主目标伤害
                    nearest.health = nearest.health - actualDmg
                    nearest.hitFlash = 1.0
                    -- 战列舰 AOE：对主目标周围所有敌舰造成 50% 溅射伤害
                    if ship.aoeRadius > 0 then
                        local aoeDmg = math.floor(actualDmg * 0.5)
                        for _, splash in ipairs(enemyFleet_) do
                            if splash ~= nearest then
                                local sx = splash.x - nearest.x
                                local sy = splash.y - nearest.y
                                if sx*sx + sy*sy <= ship.aoeRadius * ship.aoeRadius then
                                    splash.health = splash.health - aoeDmg
                                    floatTexts_[#floatTexts_+1] = {
                                        x=splash.x + math.random(-4,4), y=splash.y - 14,
                                        text="-"..aoeDmg, life=0.7, maxLife=0.7,
                                        vy=-28, team="enemy"
                                    }
                                end
                            end
                        end
                    end
                    projectiles_[#projectiles_+1] = {
                        x=ship.x, y=ship.y,
                        tx=nearest.x, ty=nearest.y,
                        team="player", life=0.15,
                        isBig = (ship.stype == "BATTLECRUISER")
                    }
                    if shootSfxTimer_ <= 0 then
                        local sfx
                        if ship.stype == "CARRIER" then
                            sfx = Audio.SFX.CARRIER_ATTACK
                        elseif ship.stype == "BATTLECRUISER" or ship.stype == "DESTROYER" then
                            sfx = Audio.SFX.SHOOT_MISSILE
                        else
                            sfx = Audio.SFX.SHOOT_LASER
                        end
                        Audio.Play(sfx, 0.5)
                        shootSfxTimer_ = 0.12
                    end
                    -- 飘字：敌舰受到伤害（集火时显示实际伤害）
                    local dmgText = (focusMult > 1.0)
                        and ("-" .. actualDmg .. "!")
                        or  ("-" .. actualDmg)
                    floatTexts_[#floatTexts_+1] = {
                        x=nearest.x + math.random(-6,6),
                        y=nearest.y - 16,
                        text=dmgText,
                        life=0.9, maxLife=0.9,
                        vy=-38,
                        team="enemy"
                    }
                end
            end
        end
    end

    -- === 敌方 AI ===
    for _, es in ipairs(enemyFleet_) do
        if #playerFleet_ > 0 then
            local target, td = findNearest(es, playerFleet_)
            if target then
                if td > es.range * 0.8 then
                    local dx = target.x - es.x
                    local dy = target.y - es.y
                    local d  = math.sqrt(dx*dx+dy*dy)
                    if d > 4 then
                        local spd = es.speed * dt
                        es.x = es.x + dx/d * spd
                        es.y = es.y + dy/d * spd
                        es.vx = dx/d; es.vy = dy/d
                    end
                end
                if td < es.range then
                    es.lastShot = es.lastShot + dt
                    if es.lastShot >= 1.0 / es.shotRate then
                        es.lastShot = 0
                        -- 主目标伤害
                        target.health = target.health - es.dmg
                        target.hitFlash = 1.0
                        -- 敌方战列舰 AOE
                        if es.aoeRadius > 0 then
                            local aoeDmg = math.floor(es.dmg * 0.5)
                            for _, splash in ipairs(playerFleet_) do
                                if splash ~= target then
                                    local sx = splash.x - target.x
                                    local sy = splash.y - target.y
                                    if sx*sx + sy*sy <= es.aoeRadius * es.aoeRadius then
                                        splash.health = splash.health - aoeDmg
                                        floatTexts_[#floatTexts_+1] = {
                                            x=splash.x + math.random(-4,4), y=splash.y - 14,
                                            text="-"..aoeDmg, life=0.7, maxLife=0.7,
                                            vy=-28, team="player"
                                        }
                                    end
                                end
                            end
                        end
                        projectiles_[#projectiles_+1] = {
                            x=es.x, y=es.y,
                            tx=target.x, ty=target.y,
                            team="enemy", life=0.15,
                            isBig = (es.stype == "BATTLECRUISER")
                        }
                        -- 飘字：我方舰船受到伤害（橙色）
                        floatTexts_[#floatTexts_+1] = {
                            x=target.x + math.random(-6,6),
                            y=target.y - 16,
                            text="-" .. es.dmg,
                            life=0.9, maxLife=0.9,
                            vy=-38,
                            team="player"
                        }
                    end
                end
            end
        end
        es.x = clamp(es.x, 10, screenW_-10)
        es.y = clamp(es.y, 88, screenH_-10)
    end

    -- === 辅助：生成爆炸粒子 + 屏幕震动 ===
    local function spawnExplosion(ship)
        local st  = ship.stype
        local isBig = (st == "BATTLECRUISER" or st == "DESTROYER"
                       or st == "CARRIER")
        local count  = isBig and 22 or 10
        local speed  = isBig and 90 or 50
        local life   = isBig and 0.7 or 0.45
        -- 核心白光闪
        explParticles_[#explParticles_+1] = {
            x=ship.x, y=ship.y, vx=0, vy=0,
            life=0.18, maxLife=0.18,
            r=255, g=255, b=255, size=isBig and 22 or 12,
            ptype="flash"
        }
        -- 碎片
        for _ = 1, count do
            local angle = math.random() * math.pi * 2
            local spd   = speed * (0.5 + math.random() * 0.8)
            local r, g, b
            if ship.team == "player" then
                r, g, b = 80+math.random(60), 160+math.random(60), 255
            else
                r, g, b = 255, 80+math.random(80), math.random(40)
            end
            explParticles_[#explParticles_+1] = {
                x    = ship.x + (math.random()-0.5) * 8,
                y    = ship.y + (math.random()-0.5) * 8,
                vx   = math.cos(angle) * spd,
                vy   = math.sin(angle) * spd,
                life = life * (0.6 + math.random() * 0.6),
                maxLife = life,
                r=r, g=g, b=b,
                size = isBig and (3 + math.random()*4) or (1.5 + math.random()*2),
                ptype="shard"
            }
        end
        -- 屏幕震动（叠加，取较大值）
        local str = isBig and 6.0 or 2.5
        local dur = isBig and 0.28 or 0.14
        if str > shakeStrength_ or shakeTimer_ <= 0 then
            shakeStrength_ = str
            shakeDur_      = dur
            shakeTimer_    = dur
        end
    end

    -- === 清理死亡舰船（爆炸粒子 + 音效 + 震动）===
    for i = #playerFleet_, 1, -1 do
        if playerFleet_[i].health <= 0 then
            local ship = playerFleet_[i]
            local st   = ship.stype
            local sfx  = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            spawnExplosion(ship)
            table.remove(playerFleet_, i)
        end
    end
    for i = #enemyFleet_, 1, -1 do
        if enemyFleet_[i].health <= 0 then
            local ship = enemyFleet_[i]
            local st   = ship.stype
            local sfx  = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            spawnExplosion(ship)
            table.remove(enemyFleet_, i)
        end
    end

    -- === 更新子弹 ===
    for i = #projectiles_, 1, -1 do
        local p = projectiles_[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(projectiles_, i) end
    end

    -- === 更新飘字 ===
    for i = #floatTexts_, 1, -1 do
        local ft = floatTexts_[i]
        ft.y    = ft.y + ft.vy * dt
        ft.life = ft.life - dt
        if ft.life <= 0 then table.remove(floatTexts_, i) end
    end

    -- === 移动目标点自动消失（2 秒后淡出）===
    if moveTarget_ then
        moveTargetTimer_ = moveTargetTimer_ + dt
        if moveTargetTimer_ > 2.0 then
            moveTarget_      = nil
            moveTargetTimer_ = 0
        end
    end

    -- === 燃烧粒子：为低血量舰船生成火花 ===
    fireTimer_ = fireTimer_ + dt
    if fireTimer_ >= 0.05 then  -- 每 50ms 生成一批粒子
        fireTimer_ = 0
        local function spawnFire(fleet)
            for _, s in ipairs(fleet) do
                local hp = s.health / s.maxHealth
                if hp < 0.35 then
                    -- 血量越低，粒子越多越红
                    local count = hp < 0.15 and 3 or 1
                    for _ = 1, count do
                        local angle = math.random() * math.pi * 2
                        local speed = 15 + math.random() * 25
                        local r = hp < 0.15 and 255 or 220
                        local g = math.floor(hp * 300)
                        fireParticles_[#fireParticles_+1] = {
                            x    = s.x + (math.random()-0.5) * 10,
                            y    = s.y + (math.random()-0.5) * 10,
                            vx   = math.cos(angle) * speed,
                            vy   = math.sin(angle) * speed - 20,  -- 向上偏移
                            life = 0.4 + math.random() * 0.3,
                            maxLife = 0.7,
                            r    = r,
                            g    = math.max(0, math.min(255, g)),
                            size = 2 + math.random() * 2,
                        }
                    end
                end
            end
        end
        spawnFire(playerFleet_)
        spawnFire(enemyFleet_)
    end
    -- 更新/清理粒子
    local i = 1
    while i <= #fireParticles_ do
        local p = fireParticles_[i]
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.vy   = p.vy + 40 * dt   -- 轻微重力
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(fireParticles_, i)
        else
            i = i + 1
        end
    end

    -- === 更新爆炸粒子 ===
    local ei = 1
    while ei <= #explParticles_ do
        local ep = explParticles_[ei]
        ep.x    = ep.x + ep.vx * dt
        ep.y    = ep.y + ep.vy * dt
        ep.vx   = ep.vx * (1 - dt * 3)   -- 阻力衰减
        ep.vy   = ep.vy * (1 - dt * 3) + 20 * dt  -- 轻微重力
        ep.life = ep.life - dt
        if ep.life <= 0 then
            table.remove(explParticles_, ei)
        else
            ei = ei + 1
        end
    end

    -- === 衰减受击闪白 ===
    local flashDecay = dt * 8   -- 0.125 秒内衰减到 0
    for _, s in ipairs(playerFleet_) do
        if s.hitFlash > 0 then s.hitFlash = math.max(0, s.hitFlash - flashDecay) end
    end
    for _, s in ipairs(enemyFleet_) do
        if s.hitFlash > 0 then s.hitFlash = math.max(0, s.hitFlash - flashDecay) end
    end

    -- === INTERCEPTOR 引擎音效（节流 0.6s，有拦截舰高速移动时触发）===
    interceptorEngineTimer_ = math.max(0, interceptorEngineTimer_ - dt)
    if interceptorEngineTimer_ <= 0 then
        local hasMoving = false
        for _, s in ipairs(playerFleet_) do
            if s.stype == "INTERCEPTOR" and s.target and (s.vx ~= 0 or s.vy ~= 0) then
                hasMoving = true; break
            end
        end
        if not hasMoving then
            for _, s in ipairs(enemyFleet_) do
                if s.stype == "INTERCEPTOR" and (s.vx ~= 0 or s.vy ~= 0) then
                    hasMoving = true; break
                end
            end
        end
        if hasMoving then
            Audio.Play(Audio.SFX.INTERCEPTOR_ENGINE)
            interceptorEngineTimer_ = 0.6   -- 0.6s 冷却，避免连续叠放
        end
    end

    -- === 更新屏幕震动 ===
    if shakeTimer_ > 0 then
        shakeTimer_ = shakeTimer_ - dt
        local frac  = shakeTimer_ / math.max(0.001, shakeDur_)
        local str   = shakeStrength_ * frac
        shakeOffX_  = (math.random() * 2 - 1) * str
        shakeOffY_  = (math.random() * 2 - 1) * str
        if shakeTimer_ <= 0 then
            shakeOffX_, shakeOffY_ = 0, 0
        end
    end

    -- === 判断胜负 ===
    if #playerFleet_ == 0 and state_ == "fighting" then
        state_ = "lose"
        stateTimer_ = 0
        if notifyFn_ then notifyFn_("舰队覆灭！战斗失败", "error") end
        if player_ then player_.battles = (player_.battles or 0) + 1 end
        print("[Battle] Wave " .. waveNum_ .. " 失败")
    elseif #enemyFleet_ == 0 and state_ == "fighting" then
        state_ = "win"
        stateTimer_ = 0
        waveGapTimer_ = 0
        -- 波次胜利资源奖励（随波次递增）
        local mReward = 150 + waveNum_ * 80   -- 调优：基础 100→150，每波系数 50→80
        local eReward = 80  + waveNum_ * 40   -- 新增：能源奖励（减少精炼瓶颈）
        local cReward = 15  + waveNum_ * 8    -- 调优：基础 10→15，每波系数 5→8
        if rm_ then
            rm_:add("metal",   mReward)
            rm_:add("esource", eReward)
            rm_:add("nuclear", cReward)
        end
        if notifyFn_ then
            notifyFn_(string.format("第 %d 波胜利！金属+%d  能源+%d  核能+%d",
                waveNum_, mReward, eReward, cReward), "success")
        end
        if player_ then
            player_.battles = (player_.battles or 0) + 1
            player_.wins    = (player_.wins or 0) + 1
            player_:addExp(200 + waveNum_ * 100)
        end
        print("[Battle] Wave " .. waveNum_ .. " 胜利  奖励: 金属+" .. mReward .. " 核能+" .. cReward)
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================
local function drawGrid()
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0, 5, 16, 255))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(50,100,200, 20))
    nvgStrokeWidth(vg_, 1)
    local step = 60
    for x = 0, screenW_, step do
        nvgBeginPath(vg_); nvgMoveTo(vg_,x,0); nvgLineTo(vg_,x,screenH_); nvgStroke(vg_)
    end
    for y = 0, screenH_, step do
        nvgBeginPath(vg_); nvgMoveTo(vg_,0,y); nvgLineTo(vg_,screenW_,y); nvgStroke(vg_)
    end
end

local SHIP_LABEL = {
    SCOUT        = "侦察",
    FRIGATE      = "护卫",
    DESTROYER    = "驱逐",
    BATTLECRUISER= "战列",
    MINER        = "采矿",
    ENGINEER     = "工程",
    EXPLORER     = "探索",
}

local function drawShip(ship)
    -- 血条背景
    nvgBeginPath(vg_)
    nvgRect(vg_, ship.x-12, ship.y-16, 24, 4)
    nvgFillColor(vg_, nvgRGBA(100,0,0, 200))
    nvgFill(vg_)
    -- 血条前景
    local hp = math.max(0, ship.health / ship.maxHealth)
    nvgBeginPath(vg_)
    nvgRect(vg_, ship.x-12, ship.y-16, math.floor(24*hp), 4)
    local hpR = math.floor(255*(1-hp))
    local hpG = math.floor(255*hp)
    nvgFillColor(vg_, nvgRGBA(hpR, hpG, 0, 220))
    nvgFill(vg_)

    -- 舰船图片渲染
    nvgSave(vg_)
    nvgTranslate(vg_, ship.x, ship.y)
    local angle = 0
    if math.abs(ship.vx) > 0.01 or math.abs(ship.vy) > 0.01 then
        angle = math.atan(ship.vy, ship.vx)
    elseif ship.team == "enemy" then
        angle = math.pi
    end
    nvgRotate(vg_, angle)

    local scale = 1.0
    if ship.stype == "SCOUT"         then scale = 0.85 end
    if ship.stype == "DESTROYER"     then scale = 1.4  end
    if ship.stype == "BATTLECRUISER" then scale = 1.8  end
    if ship.stype == "MINER"         then scale = 1.1  end
    if ship.stype == "ENGINEER"      then scale = 1.0  end
    if ship.stype == "EXPLORER"      then scale = 1.0  end
    if ship.stype == "CARRIER"       then scale = 2.5  end
    if ship.stype == "INTERCEPTOR"   then scale = 0.75 end

    local imgHandle = shipImages_[ship.stype]
    if imgHandle and imgHandle >= 0 then
        -- 用 nvgImagePattern 渲染纹理
        local half = 18 * scale
        -- 敌方舰船叠加红色调
        if ship.team == "enemy" then
            nvgGlobalAlpha(vg_, 0.85)
        end
        local paint = nvgImagePattern(vg_, -half, -half, half*2, half*2, 0, imgHandle, 1.0)
        nvgBeginPath(vg_)
        nvgRect(vg_, -half, -half, half*2, half*2)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 敌方叠加半透明红色蒙版
        if ship.team == "enemy" then
            nvgBeginPath(vg_)
            nvgRect(vg_, -half, -half, half*2, half*2)
            nvgFillColor(vg_, nvgRGBA(200, 30, 30, 80))
            nvgFill(vg_)
            nvgGlobalAlpha(vg_, 1.0)
        end
    else
        -- 纹理未加载时回退到三角形
        local c = ship.color
        if ship.team == "enemy" then c = {255,60,60} end
        nvgBeginPath(vg_)
        nvgMoveTo(vg_,  12*scale,  0)
        nvgLineTo(vg_, -8*scale,  -8*scale)
        nvgLineTo(vg_, -5*scale,   0)
        nvgLineTo(vg_, -8*scale,   8*scale)
        nvgClosePath(vg_)
        nvgFillColor(vg_, nvgRGBA(c[1],c[2],c[3], 230))
        nvgFill(vg_)
    end

    -- 受击闪白叠加（transform 空间内，与舰船同步）
    if ship.hitFlash and ship.hitFlash > 0 then
        local flashAlpha = math.floor(ship.hitFlash * 200)
        local half = 18 * scale + 2
        nvgBeginPath(vg_)
        nvgRect(vg_, -half, -half, half*2, half*2)
        nvgFillColor(vg_, nvgRGBA(255, 255, 255, flashAlpha))
        nvgFill(vg_)
    end

    nvgRestore(vg_)

    -- 舰船类型标签（血条上方）
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    if ship.team == "player" then
        nvgFillColor(vg_, nvgRGBA(120, 200, 255, 180))
    else
        nvgFillColor(vg_, nvgRGBA(255, 120, 120, 180))
    end
    nvgText(vg_, ship.x, ship.y - 17, SHIP_LABEL[ship.stype] or ship.stype)
end

local function drawProjectile(p)
    if p.isBig then
        -- 战列舰主炮：粗线 + 圆形弹头
        local alpha = math.floor(p.life * 1200)
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, p.x, p.y)
        nvgLineTo(vg_, p.tx, p.ty)
        if p.team == "player" then
            nvgStrokeColor(vg_, nvgRGBA(200,120,255, alpha))
        else
            nvgStrokeColor(vg_, nvgRGBA(255,140,40, alpha))
        end
        nvgStrokeWidth(vg_, 5)
        nvgStroke(vg_)
        -- 弹头圆点
        nvgBeginPath(vg_)
        nvgCircle(vg_, p.tx, p.ty, 5)
        if p.team == "player" then
            nvgFillColor(vg_, nvgRGBA(240,180,255, alpha))
        else
            nvgFillColor(vg_, nvgRGBA(255,200,80, alpha))
        end
        nvgFill(vg_)
    else
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, p.x, p.y)
        nvgLineTo(vg_, p.tx, p.ty)
        if p.team == "player" then
            nvgStrokeColor(vg_, nvgRGBA(100,200,255, math.floor(p.life*1200)))
        else
            nvgStrokeColor(vg_, nvgRGBA(255,80,80, math.floor(p.life*1200)))
        end
        nvgStrokeWidth(vg_, 2)
        nvgStroke(vg_)
    end
end

local function drawFloatTexts()
    if #floatTexts_ == 0 then return end
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(floatTexts_) do
        local alpha = math.floor((ft.life / ft.maxLife) * 255)
        local size  = 11 + math.floor((1 - ft.life / ft.maxLife) * 3)  -- 略微放大
        nvgFontSize(vg_, size)
        -- 敌方受击=绿色（我方打出）；我方受击=橙色（敌方打出）
        if ft.team == "enemy" then
            nvgFillColor(vg_, nvgRGBA(80, 255, 120, alpha))
        else
            nvgFillColor(vg_, nvgRGBA(255, 160, 50, alpha))
        end
        nvgText(vg_, ft.x, ft.y, ft.text)
    end
end

local function drawMoveTarget()
    if not moveTarget_ then return end
    nvgBeginPath(vg_)
    nvgCircle(vg_, moveTarget_.x, moveTarget_.y, 10)
    nvgStrokeColor(vg_, nvgRGBA(50,220,120,200))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)
    nvgBeginPath(vg_)
    nvgCircle(vg_, moveTarget_.x, moveTarget_.y, 5)
    nvgFillColor(vg_, nvgRGBA(50,220,120,150))
    nvgFill(vg_)
end

-- drawTitleBar 已移至 GameUI.RenderSceneTitle，此处删除避免重叠

--- 渲染燃烧粒子（低血量舰船火焰特效）
local function drawFireParticles()
    if #fireParticles_ == 0 then return end
    for _, p in ipairs(fireParticles_) do
        local alpha = math.floor(255 * (p.life / p.maxLife))
        local size  = p.size * (p.life / p.maxLife)  -- 随生命周期缩小
        nvgBeginPath(vg_)
        nvgCircle(vg_, p.x, p.y, math.max(0.5, size))
        nvgFillColor(vg_, nvgRGBA(p.r, p.g, 0, alpha))
        nvgFill(vg_)
    end
end

--- 渲染爆炸粒子（舰船被摧毁时的闪光+碎片）
local function drawExplParticles()
    if #explParticles_ == 0 then return end
    for _, ep in ipairs(explParticles_) do
        local frac  = ep.life / ep.maxLife
        local alpha = math.floor(frac * 255)
        if ep.ptype == "flash" then
            -- 扩张白光圆，淡出
            local r = ep.size * (2 - frac)
            nvgBeginPath(vg_)
            nvgCircle(vg_, ep.x, ep.y, math.max(0.5, r))
            nvgFillColor(vg_, nvgRGBA(ep.r, ep.g, ep.b, alpha))
            nvgFill(vg_)
        else
            -- 碎片：小点，收缩+淡出
            local sz = ep.size * frac
            nvgBeginPath(vg_)
            nvgCircle(vg_, ep.x, ep.y, math.max(0.5, sz))
            nvgFillColor(vg_, nvgRGBA(ep.r, ep.g, ep.b, alpha))
            nvgFill(vg_)
        end
    end
end

--- 战斗中顶部波次信息 HUD
local function drawWaveHUD()
    if state_ ~= "fighting" then return end
    local cx = screenW_ / 2
    -- 背景胶囊
    local hw, hh = 110, 22
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - hw, 6, hw * 2, hh, 8)
    nvgFillColor(vg_, nvgRGBA(10, 15, 35, 200))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - hw, 6, hw * 2, hh, 8)
    nvgStrokeColor(vg_, nvgRGBA(60, 120, 255, 120))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)
    -- 波次文字
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 12)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(100, 180, 255, 220))
    nvgText(vg_, cx - hw + 10, 6 + hh/2, string.format("第 %d 波", waveNum_))
    -- 我方/敌方数量
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(80, 220, 120, 220))
    nvgText(vg_, cx, 6 + hh/2,
        string.format("我方 %d  ·  敌方 %d", #playerFleet_, #enemyFleet_))
    -- 右侧波次进度点
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(200, 150, 255, 200))
    nvgText(vg_, cx + hw - 10, 6 + hh/2, string.format("W%d", waveNum_))
end

--- 绘制底部技能栏（全体集火 + 紧急修复）
local function drawSkillBar()
    if state_ ~= "fighting" then return end

    local btnW, btnH = 80, 42
    local gap        = 12
    local totalW     = btnW * 2 + gap
    local bx1        = screenW_ / 2 - totalW / 2
    local bx2        = bx1 + btnW + gap
    local by         = screenH_ - btnH - 8

    -- 检查紧急修复是否解锁（需要 NANO_REPAIR 科技）
    local hasNanoRepair = rs_ and rs_.unlocked and rs_.unlocked["NANO_REPAIR"]

    -- 辅助函数：绘制单个技能按钮
    local function drawBtn(bx, label, subLabel, cd, maxCd, active, locked)
        -- 背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, btnW, btnH, 7)
        if locked then
            nvgFillColor(vg_, nvgRGBA(30, 30, 40, 160))
        elseif active then
            nvgFillColor(vg_, nvgRGBA(255, 200, 50, 200))
        elseif cd > 0 then
            nvgFillColor(vg_, nvgRGBA(20, 25, 50, 180))
        else
            nvgFillColor(vg_, nvgRGBA(30, 60, 120, 210))
        end
        nvgFill(vg_)

        -- 边框
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, btnW, btnH, 7)
        if active then
            nvgStrokeColor(vg_, nvgRGBA(255, 230, 80, 255))
        elseif locked then
            nvgStrokeColor(vg_, nvgRGBA(80, 80, 100, 120))
        else
            nvgStrokeColor(vg_, nvgRGBA(60, 120, 220, 180))
        end
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)

        -- 冷却遮罩（从上到下）
        if cd > 0 and not locked then
            local ratio = cd / maxCd
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, bx, by, btnW, btnH * ratio, 7)
            nvgFillColor(vg_, nvgRGBA(0, 0, 0, 120))
            nvgFill(vg_)
        end

        -- 技能名称
        nvgFontFace(vg_, "sans")
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if locked then
            nvgFillColor(vg_, nvgRGBA(100, 100, 130, 160))
        elseif active then
            nvgFillColor(vg_, nvgRGBA(30, 20, 0, 255))
        else
            nvgFillColor(vg_, nvgRGBA(200, 230, 255, 230))
        end
        nvgFontSize(vg_, 13)
        nvgText(vg_, bx + btnW/2, by + btnH/2 - 8, label)

        -- 副标签（冷却秒数 / "激活中" / "未解锁"）
        nvgFontSize(vg_, 10)
        if locked then
            nvgFillColor(vg_, nvgRGBA(120, 120, 160, 150))
            nvgText(vg_, bx + btnW/2, by + btnH/2 + 8, "需 NANO_REPAIR")
        elseif active then
            nvgFillColor(vg_, nvgRGBA(50, 30, 0, 220))
            nvgText(vg_, bx + btnW/2, by + btnH/2 + 8, string.format("激活 %.1fs", skill1Active_))
        elseif cd > 0 then
            nvgFillColor(vg_, nvgRGBA(150, 180, 220, 180))
            nvgText(vg_, bx + btnW/2, by + btnH/2 + 8, string.format("CD %.0fs", cd))
        else
            nvgFillColor(vg_, nvgRGBA(100, 220, 140, 200))
            nvgText(vg_, bx + btnW/2, by + btnH/2 + 8, subLabel)
        end
    end

    -- 技能1：全体集火
    drawBtn(bx1, "全体集火", "30s CD", skill1CD_, SKILL1_CD, skill1Active_ > 0, false)
    -- 技能2：紧急修复
    drawBtn(bx2, "紧急修复", "60s CD", skill2CD_, SKILL2_CD, false, not hasNanoRepair)

    -- 记录点击区域
    skillBtn1_ = { x=bx1, y=by, w=btnW, h=btnH }
    skillBtn2_ = { x=bx2, y=by, w=btnW, h=btnH }
end

--- 渲染烟花粒子（波次胜利特效，在 StateOverlay 之前渲染）
local function drawFireworks()
    if #fwParticles_ == 0 then return end
    for _, p in ipairs(fwParticles_) do
        local frac  = p.life / p.maxLife
        local alpha = math.floor(frac * 220)
        local sz    = math.max(0.8, 3.5 * frac)
        nvgBeginPath(vg_)
        nvgCircle(vg_, p.x, p.y, sz)
        nvgFillColor(vg_, nvgRGBA(p.r, p.g, p.b, alpha))
        nvgFill(vg_)
    end
end

local function drawStateOverlay()
    if state_ == "fighting" then return end

    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0,0,0,140))
    nvgFill(vg_)

    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 48)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if state_ == "win" then
        nvgFillColor(vg_, nvgRGBA(50,255,100,255))
        nvgText(vg_, screenW_/2, screenH_/2 - 20, "胜 利")
        -- 倒计时进度条
        local gap = WAVE_GAP
        local pct = math.min(1, waveGapTimer_ / gap)
        local barW = 200
        local bx = screenW_/2 - barW/2
        local by = screenH_/2 + 20
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, barW, 10, 5)
        nvgFillColor(vg_, nvgRGBA(30,30,30,180))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, barW * pct, 10, 5)
        nvgFillColor(vg_, nvgRGBA(50,220,100,200))
        nvgFill(vg_)
        nvgFontSize(vg_, 14)
        nvgFillColor(vg_, nvgRGBA(200,255,200,220))
        nvgText(vg_, screenW_/2, by + 28,
            string.format("%.1f 秒后进入第 %d 波", math.max(0, gap - waveGapTimer_), waveNum_+1))

        -- ── 波次预报面板 ──────────────────────────────────────────────────
        local forecast = getNextWavePreview(waveNum_ + 1)
        if forecast and #forecast.groups > 0 then
            -- 面板尺寸
            local panW  = math.min(screenW_ - 40, 320)
            local itemH = 22
            local padV  = 10
            local titleH = 18
            local panH  = titleH + padV + #forecast.groups * itemH + padV
            local panX  = screenW_ / 2 - panW / 2
            local panY  = by + 50

            -- 面板背景
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, panX, panY, panW, panH, 8)
            nvgFillColor(vg_, nvgRGBA(5, 15, 30, 210))
            nvgFill(vg_)
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, panX + 0.5, panY + 0.5, panW - 1, panH - 1, 8)
            nvgStrokeColor(vg_, nvgRGBA(60, 140, 255, 100))
            nvgStrokeWidth(vg_, 1)
            nvgStroke(vg_)

            -- 标题行
            nvgFontSize(vg_, 11)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(120, 180, 255, 200))
            nvgText(vg_, screenW_ / 2, panY + titleH / 2 + 2,
                string.format("— 第 %d 波 预报（共约 %d 艘）—", waveNum_ + 1, forecast.total))

            -- 分隔线
            local sepY = panY + titleH + 2
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, panX + 12, sepY)
            nvgLineTo(vg_, panX + panW - 12, sepY)
            nvgStrokeColor(vg_, nvgRGBA(60, 100, 180, 80))
            nvgStrokeWidth(vg_, 0.5)
            nvgStroke(vg_)

            -- 舰型条目
            local rowY = sepY + padV
            -- 颜色映射
            local SHIP_COLOR = {
                SCOUT         = {r=100, g=180, b=255},
                FRIGATE       = {r=80,  g=220, b=140},
                DESTROYER     = {r=255, g=180, b=80 },
                BATTLECRUISER = {r=255, g=100, b=80 },
                INTERCEPTOR   = {r=200, g=100, b=255},
                CARRIER       = {r=255, g=60,  b=60 },
            }

            for _, grp in ipairs(forecast.groups) do
                local clr = SHIP_COLOR[grp.stype] or {r=200,g=200,b=200}
                local isBoss = grp.isBoss == true

                -- 左侧色块圆点
                local dotX = panX + 18
                nvgBeginPath(vg_)
                nvgCircle(vg_, dotX, rowY + itemH / 2, 4)
                nvgFillColor(vg_, nvgRGBA(clr.r, clr.g, clr.b, isBoss and 255 or 200))
                nvgFill(vg_)
                if isBoss then
                    nvgBeginPath(vg_)
                    nvgCircle(vg_, dotX, rowY + itemH / 2, 5)
                    nvgStrokeColor(vg_, nvgRGBA(255, 200, 60, 220))
                    nvgStrokeWidth(vg_, 1)
                    nvgStroke(vg_)
                end

                -- 舰型名称
                nvgFontSize(vg_, 11)
                nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if isBoss then
                    nvgFillColor(vg_, nvgRGBA(255, 200, 60, 240))
                else
                    nvgFillColor(vg_, nvgRGBA(clr.r, clr.g, clr.b, 220))
                end
                local label = isBoss and ("★ " .. grp.name) or grp.name
                nvgText(vg_, dotX + 12, rowY + itemH / 2, label)

                -- 右侧数量条 + 数字
                local barMaxW = panW * 0.35
                local barFrac = math.min(1, grp.count / math.max(1, forecast.total))
                local barFillW = math.max(4, math.floor(barMaxW * barFrac))
                local barX = panX + panW - 14 - barMaxW
                local barY = rowY + itemH / 2 - 4
                -- 底轨
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, barX, barY, barMaxW, 8, 3)
                nvgFillColor(vg_, nvgRGBA(20, 30, 50, 180))
                nvgFill(vg_)
                -- 填充
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, barX, barY, barFillW, 8, 3)
                nvgFillColor(vg_, nvgRGBA(clr.r, clr.g, clr.b, isBoss and 220 or 160))
                nvgFill(vg_)
                -- 数量数字
                nvgFontSize(vg_, 10)
                nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg_, nvgRGBA(200, 220, 255, 200))
                nvgText(vg_, panX + panW - 8, rowY + itemH / 2,
                    string.format("×%d", grp.count))

                rowY = rowY + itemH
            end
        end
        -- ── 波次预报结束 ──────────────────────────────────────────────────
    else
        nvgFillColor(vg_, nvgRGBA(255,50,50,255))
        nvgText(vg_, screenW_/2, screenH_/2 - 10, "战 败")

        -- M2: 添加触屏可点击按钮（同时保留键盘提示）
        local btnW, btnH = 130, 36
        local gap        = 20
        local totalW     = btnW * 2 + gap
        local bx1        = screenW_/2 - totalW/2
        local bx2        = bx1 + btnW + gap
        local by         = screenH_/2 + 28

        -- 按钮底色
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx1, by, btnW, btnH, 6)
        nvgFillColor(vg_, nvgRGBA(60,140,255,220))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx2, by, btnW, btnH, 6)
        nvgFillColor(vg_, nvgRGBA(80,80,80,200))
        nvgFill(vg_)

        -- 按钮文字
        nvgFontSize(vg_, 15)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(255,255,255,240))
        nvgText(vg_, bx1 + btnW/2, by + btnH/2, "[2] 重新战斗")
        nvgText(vg_, bx2 + btnW/2, by + btnH/2, "[1] 返回星图")

        -- 记录按钮区域供 OnClick 使用
        loseBtn1_ = { x=bx1, y=by, w=btnW, h=btnH }
        loseBtn2_ = { x=bx2, y=by, w=btnW, h=btnH }
    end
end

function BattleScene.Render()
    -- 屏幕震动偏移（战场内容整体平移，HUD/UI 不跟随震动）
    local shaking = shakeOffX_ ~= 0 or shakeOffY_ ~= 0
    if shaking then
        nvgSave(vg_)
        nvgTranslate(vg_, shakeOffX_, shakeOffY_)
    end

    drawGrid()
    for _, p in ipairs(projectiles_) do drawProjectile(p) end
    drawFireParticles()                -- 燃烧粒子在舰船下方渲染
    drawExplParticles()                -- 爆炸碎片粒子
    for _, s in ipairs(playerFleet_) do drawShip(s) end
    for _, s in ipairs(enemyFleet_)  do drawShip(s) end
    drawMoveTarget()
    drawFloatTexts()                   -- 飘字在舰船上方渲染

    if shaking then nvgRestore(vg_) end

    drawWaveHUD()                      -- 波次信息 HUD（最上层，不随震动）
    drawSkillBar()                     -- 底部技能栏
    drawFireworks()                    -- 烟花粒子（胜利特效，在 overlay 下方）
    drawStateOverlay()
end

-- ============================================================================
-- 状态查询
-- ============================================================================
function BattleScene.GetState()       return state_ end
function BattleScene.GetWave()        return waveNum_ end
function BattleScene.GetPlayerCount() return #playerFleet_ end
function BattleScene.GetEnemyCount()  return #enemyFleet_ end

-- ============================================================================
-- 输入（由 main.lua 调用）
-- ============================================================================
function BattleScene.OnClick(mx, my)
    -- M2: 战败画面触屏按钮处理
    if state_ == "lose" then
        local function inBtn(b)
            return b and mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h
        end
        if inBtn(loseBtn1_) then
            -- 重新战斗：重置战场
            BattleScene.Reset()
            return
        elseif inBtn(loseBtn2_) then
            -- 返回星图：触发战败回调
            if onBattleEnd_ and not battleEndFired_ then
                battleEndFired_ = true
                onBattleEnd_("lose")
            end
            return
        end
        return  -- 战败时屏蔽其他区域点击
    end
    if state_ ~= "fighting" then return end

    -- 技能按钮点击判断
    local function inBtn(b)
        return b and mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h
    end
    if inBtn(skillBtn1_) then
        -- 全体集火
        if skill1Active_ > 0 then
            -- 已激活中，忽略
        elseif skill1CD_ > 0 then
            if notifyFn_ then notifyFn_(string.format("集火冷却中 %.0fs", skill1CD_), "warn") end
        else
            skill1Active_ = SKILL1_DUR
            skill1CD_     = SKILL1_CD
            if notifyFn_ then notifyFn_("全体集火！伤害翻倍 " .. SKILL1_DUR .. "s", "success") end
        end
        return
    end
    if inBtn(skillBtn2_) then
        -- 紧急修复
        local hasNanoRepair = rs_ and rs_.unlocked and rs_.unlocked["NANO_REPAIR"]
        if not hasNanoRepair then
            if notifyFn_ then notifyFn_("需研究 纳米修复 科技", "warn") end
        elseif skill2CD_ > 0 then
            if notifyFn_ then notifyFn_(string.format("修复冷却中 %.0fs", skill2CD_), "warn") end
        else
            skill2CD_ = SKILL2_CD
            local healed = 0
            for _, s in ipairs(playerFleet_) do
                local gain = math.floor(s.maxHealth * 0.20)
                s.health   = math.min(s.maxHealth, s.health + gain)
                healed     = healed + gain
            end
            if notifyFn_ then notifyFn_(string.format("紧急修复！+%.0f HP", healed), "success") end
            floatTexts_[#floatTexts_+1] = {
                x=screenW_/2, y=screenH_*0.5,
                text=string.format("+%d HP 修复", healed), life=1.5, maxLife=1.5,
                vy=-28, team="player"  -- 橙色飘字（我方）
            }
        end
        return
    end

    -- 普通点击：移动指令
    for i, s in ipairs(playerFleet_) do
        local spread = (#playerFleet_ > 1) and (i - (#playerFleet_+1)/2) * 28 or 0
        s.target = { x=mx, y=my + spread }
    end
    moveTarget_ = { x=mx, y=my }
end

return BattleScene
