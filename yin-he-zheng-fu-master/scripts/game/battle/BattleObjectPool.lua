-- ============================================================================
-- game/battle/BattleObjectPool.lua  -- 战斗对象池管理器
-- ============================================================================

local ObjectPool = require("game.systems.ObjectPool")

local M = {}

local POOL_NAMES = {
    PROJECTILE = "battle_projectile",
    FLOAT_TEXT = "battle_float_text",
    FIRE_PARTICLE = "battle_fire_particle",
    EXPLOSION_PARTICLE = "battle_explosion_particle",
    HIT_SPARK = "battle_hit_spark",
    SHOCK_RING = "battle_shock_ring",
    FIREWORKS_PARTICLE = "battle_fireworks_particle",
    ENV_PARTICLE = "battle_env_particle",
}
M.POOL_NAMES = POOL_NAMES

local function createProjectile()
    return {
        x = 0, y = 0, tx = 0, ty = 0,
        vx = 0, vy = 0,
        team = nil,
        life = 0, maxLife = 0,
        dmg = 0,
        aoeRadius = 0,
        stype = nil,
        color = {255, 255, 255},
    }
end

local function resetProjectile(p)
    p.x = 0; p.y = 0; p.tx = 0; p.ty = 0
    p.vx = 0; p.vy = 0
    p.team = nil
    p.life = 0; p.maxLife = 0
    p.dmg = 0
    p.aoeRadius = 0
    p.stype = nil
    p.color[1] = 255; p.color[2] = 255; p.color[3] = 255
end

local function createFloatText()
    return {
        x = 0, y = 0,
        text = "",
        life = 0, maxLife = 0,
        vy = 0,
        team = nil,
        color = {255, 255, 255, 255},
    }
end

local function resetFloatText(ft)
    ft.x = 0; ft.y = 0
    ft.text = ""
    ft.life = 0; ft.maxLife = 0
    ft.vy = 0
    ft.team = nil
    ft.color[1] = 255; ft.color[2] = 255; ft.color[3] = 255; ft.color[4] = 255
end

local function createFireParticle()
    return {
        x = 0, y = 0,
        vx = 0, vy = 0,
        life = 0, maxLife = 0,
        r = 255, g = 128, b = 0,
        size = 0,
    }
end

local function resetFireParticle(fp)
    fp.x = 0; fp.y = 0
    fp.vx = 0; fp.vy = 0
    fp.life = 0; fp.maxLife = 0
    fp.r = 255; fp.g = 128; fp.b = 0
    fp.size = 0
end

local function createExplosionParticle()
    return {
        x = 0, y = 0,
        vx = 0, vy = 0,
        life = 0, maxLife = 0,
        r = 255, g = 255, b = 255,
        size = 0,
        ptype = nil,
    }
end

local function resetExplosionParticle(ep)
    ep.x = 0; ep.y = 0
    ep.vx = 0; ep.vy = 0
    ep.life = 0; ep.maxLife = 0
    ep.r = 255; ep.g = 255; ep.b = 255
    ep.size = 0
    ep.ptype = nil
end

local function createHitSpark()
    return {
        x = 0, y = 0,
        vx = 0, vy = 0,
        life = 0, maxLife = 0,
        r = 255, g = 255, b = 255,
    }
end

local function resetHitSpark(hs)
    hs.x = 0; hs.y = 0
    hs.vx = 0; hs.vy = 0
    hs.life = 0; hs.maxLife = 0
    hs.r = 255; hs.g = 255; hs.b = 255
end

local function createShockRing()
    return {
        x = 0, y = 0,
        radius = 0, maxRadius = 0,
        life = 0, maxLife = 0,
        r = 255, g = 255, b = 255,
        width = 0,
    }
end

local function resetShockRing(sr)
    sr.x = 0; sr.y = 0
    sr.radius = 0; sr.maxRadius = 0
    sr.life = 0; sr.maxLife = 0
    sr.r = 255; sr.g = 255; sr.b = 255
    sr.width = 0
end

local function createFireworksParticle()
    return {
        x = 0, y = 0,
        vx = 0, vy = 0,
        life = 0, maxLife = 0,
        r = 255, g = 255, b = 255,
        tail = false,
    }
end

local function resetFireworksParticle(fwp)
    fwp.x = 0; fwp.y = 0
    fwp.vx = 0; fwp.vy = 0
    fwp.life = 0; fwp.maxLife = 0
    fwp.r = 255; fwp.g = 255; fwp.b = 255
    fwp.tail = false
end

local function createEnvParticle()
    return {
        x = 0, y = 0,
        vx = 0, vy = 0,
        life = 0, maxLife = 0,
        r = 0, g = 0, b = 0,
        size = 0,
        alpha = 1,
    }
end

local function resetEnvParticle(ep)
    ep.x = 0; ep.y = 0
    ep.vx = 0; ep.vy = 0
    ep.life = 0; ep.maxLife = 0
    ep.r = 0; ep.g = 0; ep.b = 0
    ep.size = 0
    ep.alpha = 1
end

function M.Init()
    ObjectPool.CreatePool(POOL_NAMES.PROJECTILE, createProjectile, resetProjectile, 50)
    ObjectPool.CreatePool(POOL_NAMES.FLOAT_TEXT, createFloatText, resetFloatText, 30)
    ObjectPool.CreatePool(POOL_NAMES.FIRE_PARTICLE, createFireParticle, resetFireParticle, 40)
    ObjectPool.CreatePool(POOL_NAMES.EXPLOSION_PARTICLE, createExplosionParticle, resetExplosionParticle, 60)
    ObjectPool.CreatePool(POOL_NAMES.HIT_SPARK, createHitSpark, resetHitSpark, 80)
    ObjectPool.CreatePool(POOL_NAMES.SHOCK_RING, createShockRing, resetShockRing, 10)
    ObjectPool.CreatePool(POOL_NAMES.FIREWORKS_PARTICLE, createFireworksParticle, resetFireworksParticle, 50)
    ObjectPool.CreatePool(POOL_NAMES.ENV_PARTICLE, createEnvParticle, resetEnvParticle, 100)
    
    ObjectPool.Prewarm(POOL_NAMES.PROJECTILE, 20)
    ObjectPool.Prewarm(POOL_NAMES.FLOAT_TEXT, 10)
    ObjectPool.Prewarm(POOL_NAMES.HIT_SPARK, 30)
    ObjectPool.Prewarm(POOL_NAMES.EXPLOSION_PARTICLE, 20)
end

function M.GetProjectile()
    return ObjectPool.Get(POOL_NAMES.PROJECTILE)
end

function M.ReturnProjectile(p)
    ObjectPool.Return(POOL_NAMES.PROJECTILE, p)
end

function M.ReturnProjectiles(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.PROJECTILE, list, function(p)
        return p.life <= 0
    end)
end

function M.GetFloatText()
    return ObjectPool.Get(POOL_NAMES.FLOAT_TEXT)
end

function M.ReturnFloatText(ft)
    ObjectPool.Return(POOL_NAMES.FLOAT_TEXT, ft)
end

function M.ReturnFloatTexts(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.FLOAT_TEXT, list, function(ft)
        return ft.life <= 0
    end)
end

function M.GetFireParticle()
    return ObjectPool.Get(POOL_NAMES.FIRE_PARTICLE)
end

function M.ReturnFireParticle(fp)
    ObjectPool.Return(POOL_NAMES.FIRE_PARTICLE, fp)
end

function M.ReturnFireParticles(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.FIRE_PARTICLE, list, function(fp)
        return fp.life <= 0
    end)
end

function M.GetExplosionParticle()
    return ObjectPool.Get(POOL_NAMES.EXPLOSION_PARTICLE)
end

function M.ReturnExplosionParticle(ep)
    ObjectPool.Return(POOL_NAMES.EXPLOSION_PARTICLE, ep)
end

function M.ReturnExplosionParticles(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.EXPLOSION_PARTICLE, list, function(ep)
        return ep.life <= 0
    end)
end

function M.GetHitSpark()
    return ObjectPool.Get(POOL_NAMES.HIT_SPARK)
end

function M.ReturnHitSpark(hs)
    ObjectPool.Return(POOL_NAMES.HIT_SPARK, hs)
end

function M.ReturnHitSparks(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.HIT_SPARK, list, function(hs)
        return hs.life <= 0
    end)
end

function M.GetShockRing()
    return ObjectPool.Get(POOL_NAMES.SHOCK_RING)
end

function M.ReturnShockRing(sr)
    ObjectPool.Return(POOL_NAMES.SHOCK_RING, sr)
end

function M.ReturnShockRings(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.SHOCK_RING, list, function(sr)
        return sr.life <= 0
    end)
end

function M.GetFireworksParticle()
    return ObjectPool.Get(POOL_NAMES.FIREWORKS_PARTICLE)
end

function M.ReturnFireworksParticle(fwp)
    ObjectPool.Return(POOL_NAMES.FIREWORKS_PARTICLE, fwp)
end

function M.ReturnFireworksParticles(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.FIREWORKS_PARTICLE, list, function(fwp)
        return fwp.life <= 0
    end)
end

function M.GetEnvParticle()
    return ObjectPool.Get(POOL_NAMES.ENV_PARTICLE)
end

function M.ReturnEnvParticle(ep)
    ObjectPool.Return(POOL_NAMES.ENV_PARTICLE, ep)
end

function M.ReturnEnvParticles(list)
    ObjectPool.ReturnFiltered(POOL_NAMES.ENV_PARTICLE, list, function(ep)
        return ep.life <= 0
    end)
end

function M.Reset()
    ObjectPool.Clear(POOL_NAMES.PROJECTILE)
    ObjectPool.Clear(POOL_NAMES.FLOAT_TEXT)
    ObjectPool.Clear(POOL_NAMES.FIRE_PARTICLE)
    ObjectPool.Clear(POOL_NAMES.EXPLOSION_PARTICLE)
    ObjectPool.Clear(POOL_NAMES.HIT_SPARK)
    ObjectPool.Clear(POOL_NAMES.SHOCK_RING)
    ObjectPool.Clear(POOL_NAMES.FIREWORKS_PARTICLE)
    ObjectPool.Clear(POOL_NAMES.ENV_PARTICLE)
    
    ObjectPool.Prewarm(POOL_NAMES.PROJECTILE, 20)
    ObjectPool.Prewarm(POOL_NAMES.FLOAT_TEXT, 10)
    ObjectPool.Prewarm(POOL_NAMES.HIT_SPARK, 30)
    ObjectPool.Prewarm(POOL_NAMES.EXPLOSION_PARTICLE, 20)
end

function M.GetStats()
    return ObjectPool.GetAllStats()
end

function M.PrintStats()
    local stats = M.GetStats()
    print("[BattleObjectPool] Statistics:")
    for _, s in ipairs(stats) do
        print(string.format("  %-25s | Avail:%3d | Created:%4d | Reused:%4d | Borrowed:%3d | HitRate:%.1f%%",
            s.name, s.available, s.created, s.reused, s.borrowed, s.hitRate))
    end
end

return M