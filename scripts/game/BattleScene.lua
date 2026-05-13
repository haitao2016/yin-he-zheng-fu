-- ============================================================================
-- game/BattleScene.lua  -- 战术战斗场景
-- ============================================================================

local Audio = require("game.AudioManager")

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
local spq_          = nil  -- ShipProductionQueue 引用

-- 波次系统
local waveNum_      = 1     -- 当前波次
local WAVE_GAP      = 3.0   -- 胜利后等待下一波的秒数
local waveGapTimer_ = 0     -- 倒计时

-- 新生产出的舰船临时存储（等待加入战场）
local pendingShips_ = {}

-- 燃烧粒子系统（低血量舰船火焰效果）
local fireParticles_ = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,size}
local fireTimer_     = 0   -- 粒子生成节流

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
    }
end

-- ============================================================================
-- 波次配置（波次越高敌舰越强）
-- ============================================================================
local function buildEnemyWave(wave)
    local fleet = {}
    -- 基础敌舰数 = 2 + wave，类型随波次提升
    local count = math.min(2 + wave, 8)
    for i = 1, count do
        local stype
        local roll = math.random()
        if wave <= 1 then
            stype = roll < 0.7 and "SCOUT" or "FRIGATE"
        elseif wave <= 3 then
            stype = roll < 0.4 and "SCOUT" or (roll < 0.8 and "FRIGATE" or "DESTROYER")
        elseif wave <= 5 then
            stype = roll < 0.2 and "SCOUT" or (roll < 0.6 and "FRIGATE" or "DESTROYER")
        else
            -- 波次 6+：战列舰登场（20% 概率单舰，其余驱逐/护卫）
            stype = roll < 0.2 and "BATTLECRUISER"
                 or (roll < 0.55 and "DESTROYER" or "FRIGATE")
        end
        local x = screenW_ - 100 - math.random() * 100
        -- 敌方出生在战场区域（y=88 以下）
        local battleH = screenH_ - 88
        local y = 88 + battleH * 0.05 + math.random() * battleH * 0.9
        fleet[#fleet+1] = makeShip(stype, x, y, "enemy")
    end
    -- 波次 8+：额外添加 1 艘敌方战列舰作为 Boss 级旗舰
    if wave >= 8 then
        local x = screenW_ - 60 - math.random() * 40
        local battleH = screenH_ - 88
        local y = 88 + battleH * 0.3 + math.random() * battleH * 0.4
        fleet[#fleet+1] = makeShip("BATTLECRUISER", x, y, "enemy")
    end
    return fleet
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
    print("[BattleScene] 舰船纹理加载完成")

    BattleScene.Reset()
    print("[BattleScene] 初始化完成")
end

function BattleScene.Reset()
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth()  / dpr
    screenH_ = graphics:GetHeight() / dpr

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
    moveTarget_      = nil
    moveTargetTimer_ = 0
    state_           = "fighting"
    stateTimer_      = 0
    battleEndFired_  = false
    waveGapTimer_    = 0
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
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth()  / dpr
    screenH_ = graphics:GetHeight() / dpr
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
    local dpr = graphics:GetDPR()
    screenW_ = graphics:GetWidth()  / dpr
    screenH_ = graphics:GetHeight() / dpr

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
                    -- 主目标伤害
                    nearest.health = nearest.health - ship.dmg
                    -- 战列舰 AOE：对主目标周围所有敌舰造成 50% 溅射伤害
                    if ship.aoeRadius > 0 then
                        local aoeDmg = math.floor(ship.dmg * 0.5)
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
                        local sfx = (ship.stype == "BATTLECRUISER" or ship.stype == "DESTROYER")
                            and Audio.SFX.SHOOT_MISSILE or Audio.SFX.SHOOT_LASER
                        Audio.Play(sfx, 0.5)
                        shootSfxTimer_ = 0.12
                    end
                    -- 飘字：敌舰受到伤害（红色）
                    floatTexts_[#floatTexts_+1] = {
                        x=nearest.x + math.random(-6,6),
                        y=nearest.y - 16,
                        text="-" .. ship.dmg,
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

    -- === 清理死亡舰船（播放爆炸音效）===
    for i = #playerFleet_, 1, -1 do
        if playerFleet_[i].health <= 0 then
            local st = playerFleet_[i].stype
            local sfx = (st == "BATTLECRUISER" or st == "DESTROYER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            table.remove(playerFleet_, i)
        end
    end
    for i = #enemyFleet_,  1, -1 do
        if enemyFleet_[i].health  <= 0 then
            local st = enemyFleet_[i].stype
            local sfx = (st == "BATTLECRUISER" or st == "DESTROYER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            table.remove(enemyFleet_,  i)
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
    drawGrid()
    for _, p in ipairs(projectiles_) do drawProjectile(p) end
    drawFireParticles()                -- 燃烧粒子在舰船下方渲染（透视感）
    for _, s in ipairs(playerFleet_) do drawShip(s) end
    for _, s in ipairs(enemyFleet_)  do drawShip(s) end
    drawMoveTarget()
    drawFloatTexts()                   -- 飘字在舰船上方渲染
    drawWaveHUD()                      -- 波次信息 HUD（最上层，不被舰船遮挡）
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
    for i, s in ipairs(playerFleet_) do
        local spread = (#playerFleet_ > 1) and (i - (#playerFleet_+1)/2) * 28 or 0
        s.target = { x=mx, y=my + spread }
    end
    moveTarget_ = { x=mx, y=my }
end

return BattleScene
