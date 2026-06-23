------------------------------------------------------------
-- battle/BattleVFX.lua
-- 视觉/音效更新：子弹/飘字/移动点 / 工程治疗 / 战斗机计时 /
--   燃烧粒子 / 爆炸粒子 / 击中火花 / 冲击波环 / 受击闪白 /
--   拦截舰引擎音 / Boss警告计时 / 屏幕震动 / 低血闪烁
-- 从 BattleScene.Update 提取（粒子/特效更新段）
------------------------------------------------------------
local Audio       = require("game.AudioManager")
local BattleUtils = require("game.battle.BattleUtils")

local BattleVFX = {}

--- 视觉/音效每帧更新
---@param dt number 帧时间步
---@param ctx table BattleContext 共享状态
function BattleVFX.Update(dt, ctx)
    local playerFleet = ctx.playerFleet
    local enemyFleet  = ctx.enemyFleet

    -- === 更新子弹 ===
    for i = #ctx.projectiles, 1, -1 do
        local p = ctx.projectiles[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(ctx.projectiles, i) end
    end

    -- === 更新飘字 ===
    for i = #ctx.floatTexts, 1, -1 do
        local ft = ctx.floatTexts[i]
        ft.y    = ft.y + ft.vy * dt
        ft.life = ft.life - dt
        if ft.life <= 0 then table.remove(ctx.floatTexts, i) end
    end

    -- === 移动目标点自动消失（2 秒后淡出）===
    if ctx.moveTarget then
        ctx.moveTargetTimer = ctx.moveTargetTimer + dt
        if ctx.moveTargetTimer > 2.0 then
            ctx.moveTarget      = nil
            ctx.moveTargetTimer = 0
        end
    end

    -- === P1-1 被动：ENGINEER治疗 + CARRIER战斗机计时 ===
    -- ENGINEER: 战场维修 — 每ENGINEER_HEAL_INTERVAL秒为最低HP友舰回复
    local hasEngineer = false
    for _, ps in ipairs(playerFleet) do
        if ps.stype == "ENGINEER" then hasEngineer = true; break end
    end
    if hasEngineer and #playerFleet > 0 then
        ctx.engineerHealTimer = ctx.engineerHealTimer + dt
        if ctx.engineerHealTimer >= ctx.ENGINEER_HEAL_INTERVAL then
            ctx.engineerHealTimer = 0
            -- 找最低血量友舰
            local weakest, minHP = nil, math.huge
            for _, ps in ipairs(playerFleet) do
                if ps.health < minHP then weakest = ps; minHP = ps.health end
            end
            if weakest and weakest.health < weakest.maxHealth then
                -- P2-3 CIRCLE: 圆环阵修复加成(+50%)
                local healMult = (ctx.FORMATION_CONFIG[ctx.currentFormation] or {}).engineerHealMult or 1.0
                local healAmt = math.floor(ctx.ENGINEER_HEAL_AMOUNT * healMult)
                weakest.health = math.min(weakest.maxHealth, weakest.health + healAmt)
                weakest.hitFlash = -0.5  -- 负值可视为"治疗光"（绿闪），drawShips时已忽略负值不会报错
                ctx.floatTexts[#ctx.floatTexts+1] = {
                    x=weakest.x, y=weakest.y - 18,
                    text="+" .. healAmt .. (healMult > 1.0 and "⭕" or ""),
                    life=1.0, maxLife=1.0, vy=-28, team="heal"
                }
                print("[P1-1 ENGINEER] 治疗 +" .. healAmt .. " → " .. weakest.stype)
            end
        end
    end
    -- CARRIER: 战斗机群 — 倒计时，到期时移除临时战斗机
    for i = #playerFleet, 1, -1 do
        local ps = playerFleet[i]
        if ps.isFighter then
            ps.fighterLife = ps.fighterLife - dt
            if ps.fighterLife <= 0 then
                BattleUtils.spawnExplosion(ctx, ps)   -- 小爆炸特效表示撤退
                table.remove(playerFleet, i)
                print("[P1-1 CARRIER] 临时战斗机解散")
            end
        end
    end

    -- === 燃烧粒子：为低血量舰船生成火花 ===
    ctx.fireTimer = ctx.fireTimer + dt
    if ctx.fireTimer >= 0.05 then  -- 每 50ms 生成一批粒子
        ctx.fireTimer = 0
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
                        ctx.fireParticles[#ctx.fireParticles+1] = {
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
        spawnFire(playerFleet)
        spawnFire(enemyFleet)
    end
    -- 更新/清理粒子
    local i = 1
    while i <= #ctx.fireParticles do
        local p = ctx.fireParticles[i]
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.vy   = p.vy + 40 * dt   -- 轻微重力
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(ctx.fireParticles, i)
        else
            i = i + 1
        end
    end

    -- === 更新爆炸粒子 ===
    local ei = 1
    while ei <= #ctx.explParticles do
        local ep = ctx.explParticles[ei]
        ep.x    = ep.x + ep.vx * dt
        ep.y    = ep.y + ep.vy * dt
        ep.vx   = ep.vx * (1 - dt * 3)   -- 阻力衰减
        ep.vy   = ep.vy * (1 - dt * 3) + 20 * dt  -- 轻微重力
        ep.life = ep.life - dt
        if ep.life <= 0 then
            table.remove(ctx.explParticles, ei)
        else
            ei = ei + 1
        end
    end

    -- === 更新击中火花 ===
    local si = 1
    while si <= #ctx.hitSparks do
        local sp = ctx.hitSparks[si]
        sp.x    = sp.x + sp.vx * dt
        sp.y    = sp.y + sp.vy * dt
        sp.vx   = sp.vx * (1 - dt * 6)
        sp.vy   = sp.vy * (1 - dt * 6) + 30 * dt
        sp.life = sp.life - dt
        if sp.life <= 0 then table.remove(ctx.hitSparks, si)
        else si = si + 1 end
    end

    -- === 更新冲击波环 ===
    local ri = 1
    while ri <= #ctx.shockRings do
        local ring = ctx.shockRings[ri]
        ring.life   = ring.life - dt
        -- 半径随时间扩张
        local frac  = 1 - ring.life / ring.maxLife
        ring.radius = ring.maxRadius * frac
        if ring.life <= 0 then table.remove(ctx.shockRings, ri)
        else ri = ri + 1 end
    end

    -- === 衰减受击闪白 ===
    local flashDecay = dt * 8   -- 0.125 秒内衰减到 0
    for _, s in ipairs(playerFleet) do
        if s.hitFlash > 0 then s.hitFlash = math.max(0, s.hitFlash - flashDecay) end
    end
    for _, s in ipairs(enemyFleet) do
        if s.hitFlash > 0 then s.hitFlash = math.max(0, s.hitFlash - flashDecay) end
    end

    -- === INTERCEPTOR 引擎音效（节流 0.6s，有拦截舰高速移动时触发）===
    ctx.interceptorEngineTimer = math.max(0, ctx.interceptorEngineTimer - dt)
    if ctx.interceptorEngineTimer <= 0 then
        local hasMoving = false
        for _, s in ipairs(playerFleet) do
            if s.stype == "INTERCEPTOR" and s.target and (s.vx ~= 0 or s.vy ~= 0) then
                hasMoving = true; break
            end
        end
        if not hasMoving then
            for _, s in ipairs(enemyFleet) do
                if s.stype == "INTERCEPTOR" and (s.vx ~= 0 or s.vy ~= 0) then
                    hasMoving = true; break
                end
            end
        end
        if hasMoving then
            Audio.Play(Audio.SFX.INTERCEPTOR_ENGINE)
            ctx.interceptorEngineTimer = 0.6   -- 0.6s 冷却，避免连续叠放
        end
    end

    -- === 更新 Boss 警告计时 ===
    if ctx.bossWarningTimer > 0 then
        ctx.bossWarningTimer = ctx.bossWarningTimer - dt
    end

    -- === 更新屏幕震动 ===
    if ctx.SK.timer > 0 then
        ctx.SK.timer = ctx.SK.timer - dt
        local frac  = ctx.SK.timer / math.max(0.001, ctx.SK.dur)
        local str   = ctx.SK.strength * frac
        ctx.SK.offX  = (math.random() * 2 - 1) * str
        ctx.SK.offY  = (math.random() * 2 - 1) * str
        if ctx.SK.timer <= 0 then
            ctx.SK.offX, ctx.SK.offY = 0, 0
        end
    end

    -- P3-2 V2.0: 低血闪烁计时器（周期 0.5s 循环）
    ctx.hpBlinkTimer = (ctx.hpBlinkTimer + dt) % 0.5
end

return BattleVFX
