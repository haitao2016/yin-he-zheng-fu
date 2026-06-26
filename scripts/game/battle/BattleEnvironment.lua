---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/battle/BattleEnvironment.lua -- 战斗环境效果系统
-- V1.6 P1-2: 战斗环境效果
-- ============================================================================

local BattleEnvironment = {}

-- ============================================================================
-- 环境类型定义
-- ============================================================================

BATTLE_ENVIRONMENTS = {
    {
        id = "ASTEROID_FIELD",
        name = "小行星带",
        desc = "密集的小行星群，舰船移动速度降低，但可利用小行星掩护",
        effects = {
            speedMult = 0.7,          -- 移动速度降低 30%
            coverBonus = 0.2,         -- 小行星掩护增加 20% 防御
            collisionDamage = 5,      -- 碰撞小行星造成 5 点伤害
        },
        visual = {
            asteroidCount = 30,       -- 小行星数量
            asteroidSizeRange = { 10, 40 },
            bgColor = { 20, 25, 35 },
        },
        duration = 0,                 -- 持续型环境（整个波次）
        probability = 0.15,
        icon = "env_asteroid",
    },
    {
        id = "NEBULA",
        name = "星云区",
        desc = "浓密的星云遮蔽视野，隐形效果增强，但传感器精度下降",
        effects = {
            stealthBonus = 0.5,       -- 隐形效果增强 50%
            sensorPenalty = 0.3,      -- 传感器精度降低 30%
            visibilityRange = 200,    -- 可见范围限制
        },
        visual = {
            nebulaColor = { 80, 40, 120 },
            nebulaAlpha = 0.4,
            bgColor = { 15, 20, 30 },
        },
        duration = 0,
        probability = 0.12,
        icon = "env_nebula",
    },
    {
        id = "SOLAR_STORM",
        name = "太阳风暴",
        desc = "强烈的太阳辐射干扰电子设备，护盾效果降低",
        effects = {
            shieldPenalty = 0.4,      -- 护盾效果降低 40%
            energyRegenMult = 0.8,    -- 能量回复降低 20%
            empChance = 0.05,         -- 5% 概率触发 EMP
        },
        visual = {
            stormColor = { 255, 200, 100 },
            stormIntensity = 0.6,
            bgColor = { 30, 25, 20 },
        },
        duration = 60,                -- 60 秒后结束
        probability = 0.08,
        icon = "env_storm",
    },
    {
        id = "GRAVITY_WELL",
        name = "重力井",
        desc = "异常重力场影响舰船轨迹，大型舰船受影响更大",
        effects = {
            gravityPull = 0.3,        -- 重力牵引强度
            largeShipPenalty = 0.4,   -- 大型舰船额外减速 40%
            projectileCurve = 0.2,    -- 弹道弯曲 20%
        },
        visual = {
            wellColor = { 100, 50, 150 },
            wellRadius = 150,
            bgColor = { 15, 15, 25 },
        },
        duration = 0,
        probability = 0.10,
        icon = "env_gravity",
    },
    {
        id = "DEBRIS_FIELD",
        name = "残骸区",
        desc = "战斗残骸区域，可回收资源但存在危险碎片",
        effects = {
            salvageBonus = 0.3,       -- 资源回收增加 30%
            debrisDamage = 3,         -- 碎片碰撞伤害 3
            debrisCount = 20,         -- 碎片数量
        },
        visual = {
            debrisColor = { 80, 80, 90 },
            debrisSizeRange = { 5, 20 },
            bgColor = { 20, 20, 25 },
        },
        duration = 0,
        probability = 0.12,
        icon = "env_debris",
    },
    {
        id = "ION_STORM",
        name = "离子风暴",
        desc = "离子风暴干扰能量系统，武器效率波动",
        effects = {
            weaponEfficiencyVar = 0.2, -- 武器效率波动 ±20%
            energyCostMult = 1.2,      -- 能量消耗增加 20%
            ionFlashChance = 0.1,      -- 10% 概率离子闪光
        },
        visual = {
            ionColor = { 150, 200, 255 },
            ionFlashAlpha = 0.3,
            bgColor = { 20, 30, 40 },
        },
        duration = 45,
        probability = 0.08,
        icon = "env_ion",
    },
    {
        id = "WARP_ZONE",
        name = "曲速区",
        desc = "曲速能量残留，舰船移动速度提升但定位不稳定",
        effects = {
            speedBonus = 0.3,         -- 移动速度增加 30%
            positionDrift = 10,       -- 位置漂移 ±10 像素
            warpFlashChance = 0.05,   -- 5% 概率曲速闪光
        },
        visual = {
            warpColor = { 100, 180, 255 },
            warpAlpha = 0.2,
            bgColor = { 15, 25, 35 },
        },
        duration = 30,
        probability = 0.06,
        icon = "env_warp",
    },
    {
        id = "CRYSTAL_FIELD",
        name = "晶体区",
        desc = "稀有晶体矿场，能量回复增强但存在晶体爆炸风险",
        effects = {
            energyRegenBonus = 0.5,   -- 能量回复增加 50%
            crystalExplosionChance = 0.02, -- 2% 概率晶体爆炸
            crystalBonus = 20,        -- 晶体奖励增加
        },
        visual = {
            crystalColor = { 200, 150, 255 },
            crystalCount = 15,
            bgColor = { 25, 20, 35 },
        },
        duration = 0,
        probability = 0.05,
        icon = "env_crystal",
        tier = 2,
    },
    -- V3.2 P1-5 新增：高级、更复杂的环境
    {
        id = "BLACK_HOLE_EDGE",
        name = "黑洞边缘",
        desc = "引力异常强，舰船不断被拉向中心，时间流速缓慢",
        effects = {
            gravityPull = 0.6,
            timeDilation = 0.8,
            projectileCurve = 0.5,
            energyCostMult = 1.3,
        },
        visual = {
            coreColor = { 0, 0, 20 },
            accretionColor = { 255, 200, 100 },
            bgColor = { 10, 5, 15 },
        },
        duration = 45,
        probability = 0.03,
        icon = "env_blackhole",
        tier = 3,
    },
    {
        id = "PLASMA_CLOUD",
        name = "等离子云",
        desc = "高温等离子云，持续能量伤害但能量武器获得加成",
        effects = {
            heatDamagePerSec = 2,
            energyWeaponBonus = 0.4,
            shieldMult = 0.6,
            visibilityRange = 150,
        },
        visual = {
            plasmaColor = { 255, 100, 100 },
            plasmaAlpha = 0.35,
            bgColor = { 35, 15, 10 },
        },
        duration = 60,
        probability = 0.06,
        icon = "env_plasma",
        tier = 3,
    },
    {
        id = "ELECTRONIC_WARFARE",
        name = "电子战区域",
        desc = "强烈干扰信号，技能冷却增加，但击杀获得额外能量",
        effects = {
            cooldownMult = 1.5,
            killEnergyBonus = 30,
            weaponAccuracyPenalty = 0.15,
        },
        visual = {
            staticColor = { 120, 200, 255 },
            bgColor = { 20, 30, 40 },
        },
        duration = 50,
        probability = 0.05,
        icon = "env_ewarfare",
        tier = 3,
    },
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local EnvState = {
    currentEnv = nil,
    envTimer = 0,
    envObjects = {},
    envParticles = {},
    envAnnounceTimer = 0,
    envAnnounceAlpha = 0,
}

-- ============================================================================
-- 环境选择
-- ============================================================================

-- 随机选择环境
function BattleEnvironment.selectRandomEnvironment(waveNum)
    -- 波次越高，出现环境的概率越大
    local baseProb = 0.1 + (waveNum or 1) * 0.02
    baseProb = math.min(baseProb, 0.4)  -- 最大 40%

    if math.random() > baseProb then
        return nil  -- 无环境
    end

    -- 按概率随机选择
    local candidates = {}
    for _, env in ipairs(BATTLE_ENVIRONMENTS) do
        table.insert(candidates, { env = env, weight = env.probability })
    end

    local totalWeight = 0
    for _, c in ipairs(candidates) do
        totalWeight = totalWeight + c.weight
    end

    local roll = math.random() * totalWeight
    local accumulated = 0

    for _, c in ipairs(candidates) do
        accumulated = accumulated + c.weight
        if roll <= accumulated then
            return c.env
        end
    end

    return nil
end

-- 强制指定环境
function BattleEnvironment.setEnvironment(envId)
    for _, env in ipairs(BATTLE_ENVIRONMENTS) do
        if env.id == envId then
            EnvState.currentEnv = env
            EnvState.envTimer = env.duration or 0
            EnvState.envAnnounceTimer = 2.5
            EnvState.envAnnounceAlpha = 1.0
            BattleEnvironment.generateEnvObjects(env)
            return true
        end
    end
    return false
end

-- ============================================================================
-- 环境对象生成
-- ============================================================================

-- 生成环境对象（小行星、碎片等）
function BattleEnvironment.generateEnvObjects(env)
    EnvState.envObjects = {}

    if env.id == "ASTEROID_FIELD" then
        for i = 1, env.visual.asteroidCount do
            table.insert(EnvState.envObjects, {
                type = "asteroid",
                x = math.random(50, 750),
                y = math.random(50, 550),
                size = math.random(env.visual.asteroidSizeRange[1], env.visual.asteroidSizeRange[2]),
                vx = math.random(-10, 10),
                vy = math.random(-10, 10),
                rotation = math.random() * math.pi * 2,
                rotSpeed = math.random(-0.5, 0.5),
            })
        end

    elseif env.id == "DEBRIS_FIELD" then
        for i = 1, env.effects.debrisCount do
            table.insert(EnvState.envObjects, {
                type = "debris",
                x = math.random(50, 750),
                y = math.random(50, 550),
                size = math.random(env.visual.debrisSizeRange[1], env.visual.debrisSizeRange[2]),
                vx = math.random(-5, 5),
                vy = math.random(-5, 5),
                rotation = math.random() * math.pi * 2,
                salvage = math.random(5, 15),
            })
        end

    elseif env.id == "CRYSTAL_FIELD" then
        for i = 1, env.visual.crystalCount do
            table.insert(EnvState.envObjects, {
                type = "crystal",
                x = math.random(50, 750),
                y = math.random(50, 550),
                size = math.random(15, 30),
                glow = 0.5 + math.random() * 0.5,
                pulsePhase = math.random() * math.pi * 2,
            })
        end
    end
end

-- ============================================================================
-- 环境效果应用
-- ============================================================================

-- 获取当前环境效果
function BattleEnvironment.getCurrentEffects()
    if not EnvState.currentEnv then
        return {}
    end
    return EnvState.currentEnv.effects
end

-- 获取速度修正
function BattleEnvironment.getSpeedMult(ship)
    local effects = BattleEnvironment.getCurrentEffects()
    local mult = 1.0

    if effects.speedMult then
        mult = mult * effects.speedMult
    end
    if effects.speedBonus then
        mult = mult * (1 + effects.speedBonus)
    end
    if effects.largeShipPenalty and ship and ship.sizeCategory and ship.sizeCategory >= 3 then
        mult = mult * (1 - effects.largeShipPenalty)
    end

    return mult
end

-- 获取护盾修正
function BattleEnvironment.getShieldMult()
    local effects = BattleEnvironment.getCurrentEffects()
    if effects.shieldPenalty then
        return 1 - effects.shieldPenalty
    end
    return 1.0
end

-- 获取隐形修正
function BattleEnvironment.getStealthMult()
    local effects = BattleEnvironment.getCurrentEffects()
    if effects.stealthBonus then
        return 1 + effects.stealthBonus
    end
    return 1.0
end

-- 获取能量回复修正
function BattleEnvironment.getEnergyRegenMult()
    local effects = BattleEnvironment.getCurrentEffects()
    local mult = 1.0

    if effects.energyRegenMult then
        mult = mult * effects.energyRegenMult
    end
    if effects.energyRegenBonus then
        mult = mult * (1 + effects.energyRegenBonus)
    end

    return mult
end

-- 获取武器效率波动
function BattleEnvironment.getWeaponEfficiency()
    local effects = BattleEnvironment.getCurrentEffects()
    if effects.weaponEfficiencyVar then
        local variance = effects.weaponEfficiencyVar
        return 1.0 + (math.random() * 2 - 1) * variance
    end
    return 1.0
end

-- 获取掩护加成
function BattleEnvironment.getCoverBonus(ship)
    local effects = BattleEnvironment.getCurrentEffects()
    if effects.coverBonus then
        -- 检查舰船是否靠近小行星
        for _, obj in ipairs(EnvState.envObjects) do
            if obj.type == "asteroid" then
                local dx = (ship.x or 0) - obj.x
                local dy = (ship.y or 0) - obj.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < obj.size + 30 then
                    return effects.coverBonus
                end
            end
        end
    end
    return 0
end

-- ============================================================================
-- 环境碰撞检测
-- ============================================================================

-- 检查舰船与环境对象碰撞
function BattleEnvironment.checkCollisions(ship)
    local effects = BattleEnvironment.getCurrentEffects()
    local damage = 0

    for _, obj in ipairs(EnvState.envObjects) do
        local dx = (ship.x or 0) - obj.x
        local dy = (ship.y or 0) - obj.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < (ship.size or 20) + obj.size then
            if obj.type == "asteroid" and effects.collisionDamage then
                damage = damage + effects.collisionDamage
                -- 反弹小行星
                obj.vx = -obj.vx + math.random(-5, 5)
                obj.vy = -obj.vy + math.random(-5, 5)
            elseif obj.type == "debris" and effects.debrisDamage then
                damage = damage + effects.debrisDamage
            elseif obj.type == "crystal" then
                -- 晶体爆炸检查
                if effects.crystalExplosionChance and math.random() < effects.crystalExplosionChance then
                    damage = damage + 30  -- 晶体爆炸伤害
                    obj.exploding = true
                end
            end
        end
    end

    return damage
end

-- ============================================================================
-- 环境更新
-- ============================================================================

-- 更新环境状态
function BattleEnvironment.update(dt, ctx)
    if not EnvState.currentEnv then return end

    -- 更新计时器
    if EnvState.envTimer > 0 then
        EnvState.envTimer = EnvState.envTimer - dt
        if EnvState.envTimer <= 0 then
            BattleEnvironment.clearEnvironment()
            return
        end
    end

    -- 更新公告动画
    if EnvState.envAnnounceTimer > 0 then
        EnvState.envAnnounceTimer = EnvState.envAnnounceTimer - dt
        EnvState.envAnnounceAlpha = math.max(0, EnvState.envAnnounceTimer / 2.5)
    end

    -- 更新环境对象
    for _, obj in ipairs(EnvState.envObjects) do
        if obj.vx then
            obj.x = obj.x + obj.vx * dt
            obj.y = obj.y + obj.vy * dt
            -- 边界反弹
            if obj.x < 50 or obj.x > 750 then obj.vx = -obj.vx end
            if obj.y < 50 or obj.y > 550 then obj.vy = -obj.vy end
        end
        if obj.rotSpeed then
            obj.rotation = obj.rotation + obj.rotSpeed * dt
        end
        if obj.pulsePhase then
            obj.pulsePhase = obj.pulsePhase + dt * 2
        end
        if obj.exploding then
            obj.explosionTimer = (obj.explosionTimer or 0.5) - dt
            if obj.explosionTimer <= 0 then
                obj.destroyed = true
            end
        end
    end

    -- 移除已销毁对象
    local toRemove = {}
    for i, obj in ipairs(EnvState.envObjects) do
        if obj.destroyed then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(EnvState.envObjects, toRemove[i])
    end

    -- 生成环境粒子
    BattleEnvironment.updateParticles(dt)
end

-- 更新环境粒子
function BattleEnvironment.updateParticles(dt)
    -- 根据环境类型生成特定粒子
    local env = EnvState.currentEnv
    if not env then return end

    if env.id == "SOLAR_STORM" then
        -- 太阳风暴粒子
        if math.random() < 0.1 then
            table.insert(EnvState.envParticles, {
                x = math.random(0, 800),
                y = 0,
                vx = math.random(-20, 20),
                vy = math.random(100, 200),
                life = 2,
                maxLife = 2,
                r = 255, g = 200, b = 100,
                size = math.random(2, 5),
            })
        end

    elseif env.id == "ION_STORM" then
        -- 离子闪光
        if math.random() < 0.05 then
            table.insert(EnvState.envParticles, {
                x = math.random(0, 800),
                y = math.random(0, 600),
                flash = true,
                life = 0.3,
                maxLife = 0.3,
                r = 150, g = 200, b = 255,
                size = math.random(50, 100),
            })
        end

    elseif env.id == "NEBULA" then
        -- 星云漂浮粒子
        if math.random() < 0.05 then
            table.insert(EnvState.envParticles, {
                x = math.random(0, 800),
                y = math.random(0, 600),
                vx = math.random(-10, 10),
                vy = math.random(-10, 10),
                life = 5,
                maxLife = 5,
                r = 80, g = 40, b = 120,
                size = math.random(20, 50),
                alpha = 0.3,
            })
        end
    end

    -- 更新粒子
    for i, p in ipairs(EnvState.envParticles) do
        p.life = p.life - dt
        if p.vx then
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end

    -- 移除过期粒子
    local toRemove = {}
    for i, p in ipairs(EnvState.envParticles) do
        if p.life <= 0 then
            table.insert(toRemove, i)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(EnvState.envParticles, toRemove[i])
    end
end

-- 清除环境
function BattleEnvironment.clearEnvironment()
    EnvState.currentEnv = nil
    EnvState.envTimer = 0
    EnvState.envObjects = {}
    EnvState.envParticles = {}
end

-- ============================================================================
-- V3.2 P1-5 新增：环境情报预览 & 历史记录 & 强化工具
-- ============================================================================

-- 环境历史记录
local envHistory = {}
local function pushToHistory(env)
    if not env then return end
    table.insert(envHistory, 1, {
        id = env.id,
        name = env.name,
        time = os.time(),
    })
    while #envHistory > 10 do table.remove(envHistory) end
end

-- 覆盖：在 setEnvironment 里记录历史
local originalSetEnvironment = BattleEnvironment.setEnvironment
function BattleEnvironment.setEnvironment(envId)
    local ok = originalSetEnvironment(envId)
    if ok and EnvState.currentEnv then
        pushToHistory(EnvState.currentEnv)
    end
    return ok
end

-- 获取所有环境列表（供 UI 面板使用）
function BattleEnvironment.getAllEnvironments()
    local result = {}
    for _, env in ipairs(BATTLE_ENVIRONMENTS) do
        table.insert(result, {
            id = env.id,
            name = env.name,
            desc = env.desc,
            icon = env.icon,
            probability = env.probability,
            duration = env.duration,
            tier = env.tier or 1,
            effects = env.effects,
        })
    end
    return result
end

-- 获取环境历史记录
function BattleEnvironment.getHistory()
    return envHistory
end

-- 评估某舰船/舰队在当前环境的表现评分（0 ~ 1）
function BattleEnvironment.evaluateFleetCompatibility(fleetList)
    local effects = BattleEnvironment.getCurrentEffects()
    if not next(effects) then
        return 1.0, { summary = "无环境影响" }
    end

    local score = 1.0
    local detail = {}

    if effects.speedMult then
        score = score * effects.speedMult
        table.insert(detail, { k = "速度", v = math.floor(effects.speedMult * 100) .. "%" })
    end
    if effects.shieldPenalty then
        score = score * (1 - effects.shieldPenalty)
        table.insert(detail, { k = "护盾", v = "-" .. math.floor(effects.shieldPenalty * 100) .. "%" })
    end
    if effects.energyRegenMult or effects.energyRegenBonus then
        local mult = (effects.energyRegenMult or 1) * (1 + (effects.energyRegenBonus or 0))
        score = score * mult
        table.insert(detail, { k = "能量", v = math.floor(mult * 100) .. "%" })
    end
    if effects.stealthBonus then
        score = score * (1 + effects.stealthBonus * 0.5)
        table.insert(detail, { k = "隐形", v = "+" .. math.floor(effects.stealthBonus * 100) .. "%" })
    end
    if effects.gravityPull and effects.gravityPull > 0.4 then
        score = score * 0.85
        table.insert(detail, { k = "强引力", v = "危险" })
    end
    if effects.energyWeaponBonus then
        score = score * (1 + effects.energyWeaponBonus * 0.5)
        table.insert(detail, { k = "能量武器", v = "+" .. math.floor(effects.energyWeaponBonus * 100) .. "%" })
    end

    return math.max(0.1, math.min(1.5, score)), detail
end

-- 环境状态详情（用于 HUD 显示）
function BattleEnvironment.getEnvironmentHudInfo()
    local env = EnvState.currentEnv
    if not env then return nil end
    return {
        id = env.id,
        name = env.name,
        desc = env.desc,
        icon = env.icon,
        timer = EnvState.envTimer > 0 and EnvState.envTimer or nil,
        objectsCount = #EnvState.envObjects,
        particlesCount = #EnvState.envParticles,
        effects = env.effects,
        tier = env.tier or 1,
    }
end

-- 每帧的持续环境伤害（等离子云灼热等）
function BattleEnvironment.getEnvironmentalDamage(dt)
    local effects = BattleEnvironment.getCurrentEffects()
    local dmg = 0
    if effects.heatDamagePerSec then
        dmg = dmg + effects.heatDamagePerSec * dt
    end
    return dmg
end

-- 击杀能量奖励（电子战区域等）
function BattleEnvironment.getKillEnergyBonus()
    local effects = BattleEnvironment.getCurrentEffects()
    return effects.killEnergyBonus or 0
end

-- 技能冷却倍率
function BattleEnvironment.getCooldownMultiplier()
    local effects = BattleEnvironment.getCurrentEffects()
    return effects.cooldownMult or 1.0
end

-- ============================================================================
-- 环境渲染
-- ============================================================================

-- 渲染环境
function BattleEnvironment.draw(vg, ctx)
    if not EnvState.currentEnv then return end

    local env = EnvState.currentEnv

    -- 渲染背景色
    if env.visual and env.visual.bgColor then
        local bg = env.visual.bgColor
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, ctx.screenW or 800, ctx.screenH or 600)
        nvgFillColor(vg, nvgRGBA(bg[1], bg[2], bg[3], 50))
        nvgFill(vg)
    end

    -- 渲染环境对象
    for _, obj in ipairs(EnvState.envObjects) do
        if obj.type == "asteroid" then
            BattleEnvironment.drawAsteroid(vg, obj, env)
        elseif obj.type == "debris" then
            BattleEnvironment.drawDebris(vg, obj, env)
        elseif obj.type == "crystal" then
            BattleEnvironment.drawCrystal(vg, obj, env)
        end
    end

    -- 渲染粒子
    for _, p in ipairs(EnvState.envParticles) do
        if p.flash then
            -- 闪光效果
            nvgBeginPath(vg)
            nvgCircle(vg, p.x, p.y, p.size)
            nvgFillColor(vg, nvgRGBA(p.r, p.g, p.b, math.floor(255 * p.life / p.maxLife * 0.5)))
            nvgFill(vg)
        else
            nvgBeginPath(vg)
            nvgCircle(vg, p.x, p.y, p.size)
            local alpha = p.alpha or (p.life / p.maxLife)
            nvgFillColor(vg, nvgRGBA(p.r, p.g, p.b, math.floor(255 * alpha)))
            nvgFill(vg)
        end
    end

    -- 渲染公告
    if EnvState.envAnnounceAlpha > 0 then
        BattleEnvironment.drawAnnouncement(vg, env, ctx)
    end
end

-- 渲染小行星
function BattleEnvironment.drawAsteroid(vg, obj, env)
    nvgSave(vg)
    nvgTranslate(vg, obj.x, obj.y)
    nvgRotate(vg, obj.rotation or 0)

    nvgBeginPath(vg)
    -- 不规则多边形小行星
    local points = 6
    for i = 0, points - 1 do
        local angle = i * (2 * math.pi / points)
        local r = obj.size * (0.8 + 0.2 * math.sin(angle * 3))
        local px = math.cos(angle) * r
        local py = math.sin(angle) * r
        if i == 0 then nvgMoveTo(vg, px, py)
        else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(80, 80, 90, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 60, 70, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgRestore(vg)
end

-- 渲染残骸
function BattleEnvironment.drawDebris(vg, obj, env)
    nvgSave(vg)
    nvgTranslate(vg, obj.x, obj.y)
    nvgRotate(vg, obj.rotation or 0)

    nvgBeginPath(vg)
    nvgRect(vg, -obj.size / 2, -obj.size / 2, obj.size, obj.size)
    local color = env.visual.debrisColor
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 180))
    nvgFill(vg)

    nvgRestore(vg)
end

-- 渲染晶体
function BattleEnvironment.drawCrystal(vg, obj, env)
    local glow = obj.glow * (0.5 + 0.5 * math.sin(obj.pulsePhase or 0))
    local color = env.visual.crystalColor

    -- 光晕
    nvgBeginPath(vg)
    nvgCircle(vg, obj.x, obj.y, obj.size * 1.5)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], math.floor(50 * glow)))
    nvgFill(vg)

    -- 晶体主体
    nvgBeginPath(vg)
    nvgMoveTo(vg, obj.x, obj.y - obj.size)
    nvgLineTo(vg, obj.x + obj.size * 0.5, obj.y)
    nvgLineTo(vg, obj.x, obj.y + obj.size * 0.5)
    nvgLineTo(vg, obj.x - obj.size * 0.5, obj.y)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], math.floor(200 * glow)))
    nvgFill(vg)

    -- 爆炸效果
    if obj.exploding then
        local expAlpha = (obj.explosionTimer or 0.5) * 2
        nvgBeginPath(vg)
        nvgCircle(vg, obj.x, obj.y, obj.size * 3 * (1 - expAlpha))
        nvgFillColor(vg, nvgRGBA(255, 200, 100, math.floor(200 * expAlpha)))
        nvgFill(vg)
    end
end

-- 渲染环境公告
function BattleEnvironment.drawAnnouncement(vg, env, ctx)
    local alpha = EnvState.envAnnounceAlpha
    local screenW = ctx.screenW or 800
    local screenH = ctx.screenH or 600

    -- 公告背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, screenH / 2 - 40, screenW, 80)
    nvgFillColor(vg, nvgRGBA(20, 30, 50, math.floor(200 * alpha)))
    nvgFill(vg)

    -- 环境名称
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, math.floor(255 * alpha)))
    nvgText(vg, screenW / 2, screenH / 2 - 15, "⚠ " .. env.name)

    -- 环境描述
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, math.floor(200 * alpha)))
    nvgText(vg, screenW / 2, screenH / 2 + 15, env.desc)
end

-- ============================================================================
-- 查询接口
-- ============================================================================

-- 获取当前环境
function BattleEnvironment.getCurrentEnvironment()
    return EnvState.currentEnv
end

-- 获取环境名称
function BattleEnvironment.getEnvironmentName()
    if EnvState.currentEnv then
        return EnvState.currentEnv.name
    end
    return "普通"
end

-- 检查是否有活跃环境
function BattleEnvironment.hasActiveEnvironment()
    return EnvState.currentEnv ~= nil
end

-- ============================================================================
-- 导出
-- ============================================================================

return BattleEnvironment