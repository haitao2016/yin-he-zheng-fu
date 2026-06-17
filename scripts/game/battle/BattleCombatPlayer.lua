------------------------------------------------------------
-- battle/BattleCombatPlayer.lua
-- 玩家舰队战斗：移动 / 集火 / 模块效果 / 变异词缀 / 伤害结算
-- 从 BattleScene.Update 提取（玩家舰队段）
------------------------------------------------------------
local Audio              = require("game.AudioManager")
local BattleReplaySystem = require("game.BattleReplaySystem")
local BattleSkills       = require("game.BattleSkills")
local BattleUtils        = require("game.battle.BattleUtils")

local BattleCombatPlayer = {}

--- 玩家舰队战斗更新
---@param dt number 帧时间步
---@param ctx table BattleContext 共享状态
function BattleCombatPlayer.Update(dt, ctx)
    local clamp       = BattleUtils.clamp
    local findNearest = BattleUtils.findNearest
    local dist2       = BattleUtils.dist2
    local playerFleet = ctx.playerFleet
    local enemyFleet  = ctx.enemyFleet
    local battleStats = ctx.battleStats

    -- === 玩家舰队 ===
    -- 相位加速：激活时移速×(2.5 * effectMult)，Lv3 最高 ×5.0
    local phaseMult = BattleSkills.IsActive(5) and (2.5 * BattleSkills.GetEffectMult(5)) or 1.0
    for _, ship in ipairs(playerFleet) do
        -- P1-1 模块: stealth 计时器递减
        if ship.stealthTimer and ship.stealthTimer > 0 then
            ship.stealthTimer = ship.stealthTimer - dt
        end
        -- P1-1 模块: emergencyHeal — 生命<阈值时每秒回复
        if ship.moduleEffect and ship.moduleEffect.type == "emergencyHeal" then
            if ship.health > 0 and ship.health < ship.maxHealth * ship.moduleEffect.threshold then
                local heal = math.floor(ship.maxHealth * ship.moduleEffect.healRate * dt)
                ship.health = math.min(ship.maxHealth, ship.health + heal)
            end
        end
        -- P1-2 V2.5: 变异词缀运行时效果
        if ship.mutantAffixes and ship.health > 0 then
            for _, aKey in ipairs(ship.mutantAffixes) do
                if aKey == "regen" then
                    -- 再生：每秒回复1%最大HP
                    local heal = math.floor(ship.maxHealth * 0.01 * dt)
                    ship.health = math.min(ship.maxHealth, ship.health + heal)
                elseif aKey == "overcharge" then
                    -- 过载：持续扣HP(0.5%/秒)
                    local selfDmg = math.floor(ship.maxHealth * 0.005 * dt)
                    ship.health = math.max(1, ship.health - selfDmg)
                elseif aKey == "berserk" then
                    -- 狂暴：HP<30%时攻击×2（仅首次激活）
                    if ship.health < ship.maxHealth * 0.30 then
                        if not ship.mutantBerserkActive then
                            ship.mutantBerserkActive = true
                            ship.dmg = ship.dmg * 2.0
                        end
                    end
                elseif aKey == "stealth" then
                    -- 隐形：每20s隐身3s
                    if ship.mutantStealthOn > 0 then
                        ship.mutantStealthOn = ship.mutantStealthOn - dt
                        ship.stealthTimer = math.max(ship.stealthTimer, ship.mutantStealthOn)
                    else
                        ship.mutantStealthCd = ship.mutantStealthCd + dt
                        if ship.mutantStealthCd >= 20.0 then
                            ship.mutantStealthCd = 0
                            ship.mutantStealthOn = 3.0
                            ship.stealthTimer = 3.0
                        end
                    end
                elseif aKey == "unstable" then
                    -- 不稳定：每30s随机失控2s（停止攻击，随机移动）
                    if ship.mutantUnstableOn > 0 then
                        ship.mutantUnstableOn = ship.mutantUnstableOn - dt
                        ship.target = nil  -- 清除目标使其不攻击
                    else
                        ship.mutantUnstableCd = ship.mutantUnstableCd + dt
                        if ship.mutantUnstableCd >= 30.0 then
                            ship.mutantUnstableCd = 0
                            ship.mutantUnstableOn = 2.0
                        end
                    end
                end
            end
        end
        -- P1-1 模块: burn DOT — 对灼烧目标施加每秒伤害
        if ship.burnTargets then
            for i = #ship.burnTargets, 1, -1 do
                local bt = ship.burnTargets[i]
                if bt.target.health <= 0 then
                    table.remove(ship.burnTargets, i)
                else
                    bt.remaining = bt.remaining - dt
                    local burnDmg = math.floor(bt.target.maxHealth * ship.moduleEffect.dps * dt)
                    if burnDmg > 0 then
                        bt.target.health = bt.target.health - burnDmg
                        battleStats.dmgDealt = battleStats.dmgDealt + burnDmg
                        ship.statDmg = ship.statDmg + burnDmg
                        if ship._replayId then BattleReplaySystem.AddShipDamage(ship._replayId, burnDmg) end
                    end
                    if bt.remaining <= 0 then
                        table.remove(ship.burnTargets, i)
                    end
                end
            end
        end
        if ship.target and ship.target.health > 0 then
            local dx = ship.target.x - ship.x
            local dy = ship.target.y - ship.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if d > 4 then
                local spd = ship.speed * dt * phaseMult
                ship.x = ship.x + dx/d * spd
                ship.y = ship.y + dy/d * spd
                ship.vx = dx/d; ship.vy = dy/d
            else
                ship.target = nil
                ship.vx=0; ship.vy=0
            end
        else
            ship.target = nil
            ship.vx=0; ship.vy=0
        end
        ship.x = clamp(ship.x, 10, ctx.screenW-10)
        ship.y = clamp(ship.y, 88, ctx.screenH-10)

        if #enemyFleet > 0 then
            -- P2-2: 集火指令 — 优先攻击指定目标，目标死亡时自动恢复 findNearest
            local nearest, nd
            if ctx.focusTarget and ctx.focusTarget.health > 0 then
                nearest = ctx.focusTarget
                nd = math.sqrt(dist2(ship.x, ship.y, ctx.focusTarget.x, ctx.focusTarget.y))  -- 真实距离，与 ship.range 可比
            else
                if ctx.focusTarget then ctx.focusTarget = nil end  -- 目标已死，清除
                nearest, nd = findNearest(ship, enemyFleet)
            end
            if nearest and nd < ship.range then
                ship.lastShot = ship.lastShot + dt
                if ship.lastShot >= 1.0 / (ship.shotRate or 1.0) then
                    ship.lastShot = 0
                    -- 全体集火：激活时伤害×(1+effectMult)，Lv3 最高 ×3.0
                    local focusMult = BattleSkills.IsActive(1) and (1.0 + BattleSkills.GetEffectMult(1)) or 1.0
                    -- P1-3 V2.4: 指挥官"精准打击"技能增伤
                    local cmdMult = (ctx.cmdSkillActive and ctx.cmdSkillDef and ctx.cmdSkillDef.effectKey == "dmg")
                        and ctx.cmdSkillDef.effectMult or 1.0
                    local actualDmg = math.floor(ship.dmg * focusMult * cmdMult)
                    -- P2-1: 星云屏蔽首轮伤害减免（首次攻击后清除）
                    if ship.firstStrikeMult and ship.firstStrikeMult ~= 1.0 then
                        actualDmg = math.floor(actualDmg * ship.firstStrikeMult)
                        ship.firstStrikeMult = nil
                    end
                    -- P1-1 模块: markEnemy — 被标记敌人受伤增加
                    if nearest.markTimer and nearest.markTimer > 0 then
                        actualDmg = math.floor(actualDmg * (1.0 + nearest.markValue))
                    end
                    -- P1-1 DESTROYER: 穿甲弹 — 每N次攻击触发一次，伤害×2且无视护盾
                    local isPierce = false
                    if ship.stype == "DESTROYER" then
                        ship.pierceCounter = ship.pierceCounter + 1
                        if ship.pierceCounter >= ctx.DESTROYER_PIERCE_COUNT then
                            ship.pierceCounter = 0
                            isPierce = true
                            actualDmg = actualDmg * 2
                        end
                    end
                    -- P1-1 模块: pulseOverload — 每N次攻击触发双倍伤害
                    if ship.moduleEffect and ship.moduleEffect.type == "pulseOverload" then
                        ship.pulseCount = ship.pulseCount + 1
                        if ship.pulseCount >= ship.moduleEffect.interval then
                            ship.pulseCount = 0
                            actualDmg = math.floor(actualDmg * ship.moduleEffect.mult)
                        end
                    end
                    -- P1-1 模块: pierceShield — 攻击无视部分护盾
                    local moduleBypassShield = false
                    if ship.moduleEffect and ship.moduleEffect.type == "pierceShield" then
                        moduleBypassShield = true
                        -- 无视 value% 护盾：减少被吸收的量
                    end
                    -- 主目标伤害（Boss 护盾优先吸收；穿甲弹无视护盾）
                    if not isPierce and nearest.isBoss and nearest.shield > 0 then
                        local shieldAbsorbRate = ctx.currentEnv.shieldAbsorb or 1.0
                        -- P1-1: pierceShield 减少护盾吸收率
                        if moduleBypassShield then
                            shieldAbsorbRate = shieldAbsorbRate * (1.0 - ship.moduleEffect.value)
                        end
                        local absorbed = math.floor(math.min(nearest.shield, actualDmg) * shieldAbsorbRate)
                        nearest.shield = math.max(0, nearest.shield - absorbed)
                        actualDmg = actualDmg - absorbed
                    end
                    nearest.health = nearest.health - actualDmg
                    nearest.hitFlash = 1.0
                    battleStats.dmgDealt = battleStats.dmgDealt + actualDmg
                    ctx.waveDmgDealt = ctx.waveDmgDealt + actualDmg  -- P1-1
                    -- P3-2: 追踪单舰伤害 + 击杀归属
                    ship.statDmg = ship.statDmg + actualDmg
                    nearest.lastHitter = ship
                    -- P3-1: 回放系统伤害追踪
                    if ship._replayId then
                        BattleReplaySystem.AddShipDamage(ship._replayId, actualDmg)
                    end
                    -- P1-1 模块: burn — 攻击附带灼烧DOT
                    if ship.moduleEffect and ship.moduleEffect.type == "burn" then
                        if not ship.burnTargets then ship.burnTargets = {} end
                        -- 刷新或新增灼烧
                        local found = false
                        for _, bt in ipairs(ship.burnTargets) do
                            if bt.target == nearest then
                                bt.remaining = ship.moduleEffect.duration
                                found = true
                                break
                            end
                        end
                        if not found then
                            ship.burnTargets[#ship.burnTargets+1] = {
                                target = nearest, remaining = ship.moduleEffect.duration
                            }
                        end
                    end
                    -- P1-1 模块: slow — 减速命中目标
                    if ship.moduleEffect and ship.moduleEffect.type == "slow" then
                        nearest.slowTimer = ship.moduleEffect.duration
                        nearest.slowValue = ship.moduleEffect.value
                    end
                    -- P1-1 模块: markEnemy — 标记敌人使其受伤增加
                    if ship.moduleEffect and ship.moduleEffect.type == "markEnemy" then
                        nearest.markTimer = ship.moduleEffect.duration
                        nearest.markValue = ship.moduleEffect.value
                    end
                    -- P1-2 V2.5: shock 词缀 — 攻击附带范围溅射(30%伤害,半径40)
                    if ship.mutantAffixes then
                        for _, aKey in ipairs(ship.mutantAffixes) do
                            if aKey == "shock" then
                                local splashDmg = math.floor(actualDmg * 0.3)
                                if splashDmg > 0 then
                                    for _, e in ipairs(enemyFleet) do
                                        if e ~= nearest and e.health > 0 then
                                            local sdx = e.x - nearest.x
                                            local sdy = e.y - nearest.y
                                            if sdx*sdx + sdy*sdy <= 40*40 then
                                                e.health = e.health - splashDmg
                                                e.hitFlash = 0.5
                                                battleStats.dmgDealt = battleStats.dmgDealt + splashDmg
                                                ship.statDmg = ship.statDmg + splashDmg
                                            end
                                        end
                                    end
                                end
                                break
                            end
                        end
                    end
                    -- 击中特效：火花 + 大伤害冲击波环
                    BattleUtils.spawnHitSparks(ctx, nearest.x, nearest.y, actualDmg, "enemy")
                    if actualDmg >= 30 or ship.stype == "BATTLECRUISER" or ship.stype == "DESTROYER" then
                        BattleUtils.spawnShockRing(ctx, nearest.x, nearest.y,
                            math.max(18, actualDmg * 0.6), 0.22, 80, 200, 255)
                    end
                    -- 战列舰 AOE：对主目标周围所有敌舰造成 50% 溅射伤害
                    if ship.aoeRadius > 0 then
                        local aoeDmg = math.floor(actualDmg * 0.5)
                        -- AOE 冲击波（以目标为中心的大环）
                        BattleUtils.spawnShockRing(ctx, nearest.x, nearest.y,
                            ship.aoeRadius, 0.35, 80, 220, 255)
                        for _, splash in ipairs(enemyFleet) do
                            if splash ~= nearest then
                                local sx = splash.x - nearest.x
                                local sy = splash.y - nearest.y
                                if sx*sx + sy*sy <= ship.aoeRadius * ship.aoeRadius then
                                    splash.health = splash.health - aoeDmg
                                    battleStats.dmgDealt = battleStats.dmgDealt + aoeDmg
                                    -- P3-2: AOE 伤害也归属到该舰
                                    ship.statDmg = ship.statDmg + aoeDmg
                                    splash.lastHitter = ship
                                    if ship._replayId then BattleReplaySystem.AddShipDamage(ship._replayId, aoeDmg) end
                                    BattleUtils.spawnHitSparks(ctx, splash.x, splash.y, aoeDmg, "enemy")
                                    ctx.floatTexts[#ctx.floatTexts+1] = {
                                        x=splash.x + math.random(-4,4), y=splash.y - 14,
                                        text="-"..aoeDmg, life=0.7, maxLife=0.7,
                                        vy=-28, team="enemy"
                                    }
                                end
                            end
                        end
                    end
                    ctx.projectiles[#ctx.projectiles+1] = {
                        x=ship.x, y=ship.y,
                        tx=nearest.x, ty=nearest.y,
                        team="player", life=0.15,
                        isBig = (ship.stype == "BATTLECRUISER")
                    }
                    if ctx.shootSfxTimer <= 0 then
                        local sfx
                        if ship.stype == "CARRIER" then
                            sfx = Audio.SFX.CARRIER_ATTACK
                        elseif ship.stype == "BATTLECRUISER" or ship.stype == "DESTROYER" then
                            sfx = Audio.SFX.SHOOT_MISSILE
                        else
                            sfx = Audio.SFX.SHOOT_LASER
                        end
                        Audio.Play(sfx, 0.5)
                        ctx.shootSfxTimer = 0.12
                    end
                    -- 飘字：敌舰受到伤害（集火时显示实际伤害）
                    -- P3-2: 暴击判断（伤害 ≥ 目标满血量的30%）
                    local isCrit = actualDmg >= nearest.maxHealth * 0.3
                    local dmgText = isCrit
                        and ("-" .. actualDmg .. "!!")
                        or ((focusMult > 1.0)
                            and ("-" .. actualDmg .. "!")
                            or  ("-" .. actualDmg))
                    -- P3-1: 伤害数字精细化 — 按量级分寿命/速度
                    local ftLife = isCrit and 1.5 or (actualDmg >= 100 and 1.5 or (actualDmg >= 20 and 1.2 or 0.8))
                    local ftVy   = isCrit and -55 or (actualDmg >= 100 and -50 or (actualDmg >= 20 and -40 or -32))
                    ctx.floatTexts[#ctx.floatTexts+1] = {
                        x=nearest.x + math.random(-6,6),
                        y=nearest.y - 16,
                        text=dmgText,
                        life = ftLife,
                        maxLife = ftLife,
                        vy = ftVy,
                        team="enemy",
                        isCrit = isCrit,
                    }
                    -- P1-1 DESTROYER: 穿甲弹触发时额外飘字
                    if isPierce then
                        ctx.floatTexts[#ctx.floatTexts+1] = {
                            x=nearest.x, y=nearest.y - 32,
                            text="穿甲！", life=1.0, maxLife=1.0,
                            vy=-22, team="pierce"
                        }
                    end
                end
            end
        end
    end
end

return BattleCombatPlayer
