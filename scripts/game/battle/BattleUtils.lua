------------------------------------------------------------
-- battle/BattleUtils.lua
-- 战场公用工具函数（多个子模块共享）
------------------------------------------------------------

local Audio = require("game.AudioManager")

local BattleUtils = {}

--- 两点间距离的平方（避免 sqrt）
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function BattleUtils.dist2(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
end

--- 限定值范围
---@param v number
---@param lo number
---@param hi number
---@return number
function BattleUtils.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- 寻找最近目标舰
--- 注意：第二返回值是【真实距离】(已 sqrt)，与 ship.range 直接可比
---@param ship table 源舰船
---@param fleet table[] 目标舰队
---@param skipStealth? boolean 是否跳过隐身目标（P1-1 隐匿模块：stealthTimer>0）
---@return table|nil best
---@return number dist 真实距离（fleet 为空时为 math.huge）
function BattleUtils.findNearest(ship, fleet, skipStealth)
    local best, bestD = nil, math.huge
    for _, s in ipairs(fleet) do
        -- P1-1: 隐匿模块 — 敌方寻目标时跳过隐匿中的玩家舰
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = BattleUtils.dist2(ship.x, ship.y, s.x, s.y)
            if d < bestD then
                best, bestD = s, d
            end
        end
    end
    return best, math.sqrt(bestD)
end

--- 生成击中火花粒子
---@param ctx table BattleContext
---@param x number
---@param y number
---@param dmg number
---@param team string "player"|"enemy"
function BattleUtils.spawnHitSparks(ctx, x, y, dmg, team)
    local count = dmg >= 80 and 6 or (dmg >= 30 and 4 or 2)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 40 + math.random() * 60
        local r, g, b
        if team == "player" then
            r, g, b = 255, 100 + math.random(80), 40
        else
            r, g, b = 100 + math.random(80), 200 + math.random(55), 255
        end
        ctx.hitSparks[#ctx.hitSparks + 1] = {
            x = x + (math.random() - 0.5) * 6,
            y = y + (math.random() - 0.5) * 6,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.2 + math.random() * 0.15,
            maxLife = 0.35,
            r = r, g = g, b = b,
            size = 1.5 + math.random() * 1.5,
        }
    end
end

--- 生成冲击波环
---@param ctx table BattleContext
---@param x number
---@param y number
---@param maxR number
---@param dur number
---@param r number
---@param g number
---@param b number
function BattleUtils.spawnShockRing(ctx, x, y, maxR, dur, r, g, b)
    ctx.shockRings[#ctx.shockRings + 1] = {
        x = x, y = y,
        radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur,
        r = r, g = g, b = b, width = 2,
    }
end

--- 生成爆炸粒子 + 屏幕震动
---@param ctx table BattleContext
---@param ship table
function BattleUtils.spawnExplosion(ctx, ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life  = isBig and 0.7 or 0.45

    -- 核心白光闪
    ctx.explParticles[#ctx.explParticles + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12,
        ptype = "flash"
    }
    -- 碎片
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local spd   = speed * (0.5 + math.random() * 0.8)
        local r, g, b
        if ship.team == "player" then
            r, g, b = 80 + math.random(60), 160 + math.random(60), 255
        else
            r, g, b = 255, 80 + math.random(80), math.random(40)
        end
        ctx.explParticles[#ctx.explParticles + 1] = {
            x    = ship.x + (math.random() - 0.5) * 8,
            y    = ship.y + (math.random() - 0.5) * 8,
            vx   = math.cos(angle) * spd,
            vy   = math.sin(angle) * spd,
            life = life * (0.6 + math.random() * 0.6),
            maxLife = life,
            r = r, g = g, b = b,
            size = isBig and (3 + math.random() * 4) or (1.5 + math.random() * 2),
            ptype = "shard"
        }
    end
    -- 屏幕震动（叠加，取较大值）
    local str = isBig and 6.0 or 2.5
    local dur = isBig and 0.28 or 0.14
    if str > ctx.SK.strength or ctx.SK.timer <= 0 then
        ctx.SK.strength = str
        ctx.SK.dur      = dur
        ctx.SK.timer    = dur
    end
end

--- 舰型中文名（取自全局 SHIP_TYPES.name，与 BattleScene 原行为一致）
---@param stype string
---@return string
function BattleUtils.shipTypeName(stype)
    local cfg = SHIP_TYPES and SHIP_TYPES[stype]
    return cfg and cfg.name or stype
end

--- 记录战斗日志
---@param ctx table BattleContext
---@param text string
function BattleUtils.logBattleEvent(ctx, text)
    ctx.battleLog[#ctx.battleLog + 1] = {
        wave = ctx.waveNum,
        text = text,
    }
    if #ctx.battleLog > ctx.BATTLE_LOG_MAX then
        table.remove(ctx.battleLog, 1)
    end
end

--- 获取当前连击等级（COMBO_LEVELS 按 min 从高到低排列，返回首个达标项=最高等级）
---@param ctx table BattleContext
---@return table|nil {min, mult, label}
function BattleUtils.getComboLevel(ctx)
    if not ctx.COMBO_LEVELS then return nil end
    for _, lv in ipairs(ctx.COMBO_LEVELS) do
        if ctx.comboCount >= lv.min then return lv end
    end
    return nil
end

--- 生成爆炸粒子 + 屏幕震动（完整版本）
---@param ctx table BattleContext
---@param ship table
---@param explParticles table[] 爆炸粒子数组
---@param SK table 屏幕震动状态
function BattleUtils.spawnExplosionFull(ctx, ship, explParticles, SK)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life  = isBig and 0.7 or 0.45

    -- 核心白光闪
    explParticles[#explParticles + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12,
        ptype = "flash"
    }
    -- 碎片
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local spd   = speed * (0.5 + math.random() * 0.8)
        local r, g, b
        if ship.team == "player" then
            r, g, b = 80 + math.random(60), 160 + math.random(60), 255
        else
            r, g, b = 255, 80 + math.random(80), math.random(40)
        end
        explParticles[#explParticles + 1] = {
            x    = ship.x + (math.random() - 0.5) * 8,
            y    = ship.y + (math.random() - 0.5) * 8,
            vx   = math.cos(angle) * spd,
            vy   = math.sin(angle) * spd,
            life = life * (0.6 + math.random() * 0.6),
            maxLife = life,
            r = r, g = g, b = b,
            size = isBig and (3 + math.random() * 4) or (1.5 + math.random() * 2),
            ptype = "shard"
        }
    end
    -- 屏幕震动（叠加，取较大值）
    local str = isBig and 6.0 or 2.5
    local dur = isBig and 0.28 or 0.14
    if str > SK.strength or SK.timer <= 0 then
        SK.strength = str
        SK.dur      = dur
        SK.timer    = dur
    end
end

--- 简化版爆炸（用于已持有 isBig 判断的情况）
---@param ctx table BattleContext
---@param ship table
---@param isBig boolean
function BattleUtils.spawnExplosionSimple(ctx, ship, isBig, explParticles, SK)
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life  = isBig and 0.7 or 0.45

    -- 核心白光闪
    explParticles[#explParticles + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255, size = isBig and 22 or 12,
        ptype = "flash"
    }
    -- 碎片
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local spd   = speed * (0.5 + math.random() * 0.8)
        local r, g, b
        if ship.team == "player" then
            r, g, b = 80 + math.random(60), 160 + math.random(60), 255
        else
            r, g, b = 255, 80 + math.random(80), math.random(40)
        end
        explParticles[#explParticles + 1] = {
            x    = ship.x + (math.random() - 0.5) * 8,
            y    = ship.y + (math.random() - 0.5) * 8,
            vx   = math.cos(angle) * spd,
            vy   = math.sin(angle) * spd,
            life = life * (0.6 + math.random() * 0.6),
            maxLife = life,
            r = r, g = g, b = b,
            size = isBig and (3 + math.random() * 4) or (1.5 + math.random() * 2),
            ptype = "shard"
        }
    end
    -- 屏幕震动
    local str = isBig and 6.0 or 2.5
    local dur = isBig and 0.28 or 0.14
    if str > SK.strength or SK.timer <= 0 then
        SK.strength = str
        SK.dur      = dur
        SK.timer    = dur
    end
end

return BattleUtils
