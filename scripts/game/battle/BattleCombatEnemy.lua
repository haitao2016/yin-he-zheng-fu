------------------------------------------------------------
-- battle/BattleCombatEnemy.lua
-- 敌方 AI 战斗：移动 / 索敌 / 伤害结算 / 阵型机制 / 反弹
-- 从 BattleScene.Update 提取（敌方 AI 段）
------------------------------------------------------------
local BattleSkills = require("game.BattleSkills")
local BattleUtils  = require("game.battle.BattleUtils")

local BattleCombatEnemy = {}

--- 敌方 AI 战斗更新
---@param dt number 帧时间步
---@param ctx table BattleContext 共享状态
function BattleCombatEnemy.Update(dt, ctx)
    local clamp       = BattleUtils.clamp
    local findNearest = BattleUtils.findNearest
    local enemyFleet  = ctx.enemyFleet
    local playerFleet = ctx.playerFleet
    local battleStats = ctx.battleStats

    -- === 敌方 AI ===
    -- P1-2: 星云环境降低敌方射程
    local envEnemyRangeMult = ctx.currentEnv.enemyRangeMult or 1.0
    for _, es in ipairs(enemyFleet) do
        es.age = (es.age or 0) + dt  -- P2-1: 时间累积（用于增援舰脉冲动画）
        -- P1-1 模块: slow/mark 计时器递减
        if es.slowTimer and es.slowTimer > 0 then
            es.slowTimer = es.slowTimer - dt
        end
        if es.markTimer and es.markTimer > 0 then
            es.markTimer = es.markTimer - dt
        end
        if #playerFleet > 0 then
            local target, td = findNearest(es, playerFleet, true)  -- P1-1: skipStealth
            if target then
                -- EMP冲击：敌方移速降低（Lv3 更强，最低降至 12.5%）
                local empMult = BattleSkills.IsActive(3) and math.max(0.05, 0.25 / BattleSkills.GetEffectMult(3)) or 1.0
                -- P1-1 模块: slow — 减速效果
                local slowMult = (es.slowTimer and es.slowTimer > 0) and (1.0 - (es.slowValue or 0)) or 1.0
                local effectiveRange = es.range * envEnemyRangeMult
                if td > effectiveRange * 0.8 then
                    local dx = target.x - es.x
                    local dy = target.y - es.y
                    local d  = math.sqrt(dx*dx+dy*dy)
                    if d > 4 then
                        local spd = es.speed * dt * empMult * slowMult
                        es.x = es.x + dx/d * spd
                        es.y = es.y + dy/d * spd
                        es.vx = dx/d; es.vy = dy/d
                    end
                end
                -- 护盾强化：我方受伤减少（Lv3 最高减至 25%）
                local shieldMult = BattleSkills.IsActive(4) and math.max(0.1, 0.5 / BattleSkills.GetEffectMult(4)) or 1.0
                -- P1-3 V2.4: 指挥官"紧急护盾"无敌
                if ctx.cmdSkillActive and ctx.cmdSkillDef and ctx.cmdSkillDef.effectKey == "invuln" then
                    shieldMult = 0
                end
                if td < effectiveRange then
                    -- EMP同时降低敌方射速（倍率复用 empMult）
                    es.lastShot = es.lastShot + dt * empMult
                    if es.lastShot >= 1.0 / (es.shotRate or 1.0) then
                        es.lastShot = 0
                        -- 主目标伤害（护盾强化时减半）
                        local actualEsDmg = math.floor(es.dmg * shieldMult)
                        -- P2-1: 星云屏蔽首轮伤害减免（敌方首次攻击后清除）
                        if es.firstStrikeMult and es.firstStrikeMult ~= 1.0 then
                            actualEsDmg = math.floor(actualEsDmg * es.firstStrikeMult)
                            es.firstStrikeMult = nil
                        end
                        -- P1-2 V2.5: guardian 词缀 — 半径80内有守护者盟友时减伤15%
                        for _, ps in ipairs(playerFleet) do
                            if ps ~= target and ps.health > 0 and ps.mutantAffixes then
                                for _, aKey in ipairs(ps.mutantAffixes) do
                                    if aKey == "guardian" then
                                        local gx = ps.x - target.x
                                        local gy = ps.y - target.y
                                        if gx*gx + gy*gy <= 80*80 then
                                            actualEsDmg = math.floor(actualEsDmg * 0.85)
                                            goto guardian_applied
                                        end
                                    end
                                end
                            end
                        end
                        ::guardian_applied::
                        -- P1-1 BATTLECRUISER: 重甲要塞 — 10%概率完全格挡一次伤害
                        local isBlocked = false
                        if target.stype == "BATTLECRUISER" and math.random() < ctx.BATTLECRUISER_BLOCK then
                            isBlocked = true
                            ctx.floatTexts[#ctx.floatTexts+1] = {
                                x=target.x, y=target.y - 22,
                                text="格挡！", life=0.9, maxLife=0.9,
                                vy=-30, team="block"
                            }
                        end
                        if not isBlocked then
                            -- P2-3 WEDGE: 后排舰船30%概率闪避（受击概率-30%）
                            if ctx.currentFormation == "wedge" and target.isFrontRow == false then
                                if math.random() < 0.30 then
                                    ctx.floatTexts[#ctx.floatTexts+1] = {
                                        x=target.x, y=target.y - 18,
                                        text="闪避！", life=0.8, maxLife=0.8,
                                        vy=-26, team="dodge"
                                    }
                                    goto skip_enemy_hit
                                end
                            end
                            -- P2-3 阵型战斗机制：伤害分配
                            local selfDmg = actualEsDmg  -- 默认：全部伤害由目标承受
                            if ctx.currentFormation == "circle" and #playerFleet > 1 then
                                -- CIRCLE: 伤害均摊 — 全队平分该次伤害
                                local shareEach = math.floor(actualEsDmg / #playerFleet)
                                local remainder = actualEsDmg - shareEach * #playerFleet
                                for _, ps in ipairs(playerFleet) do
                                    local dmgHere = shareEach
                                    if ps == target then dmgHere = dmgHere + remainder end
                                    ps.health = ps.health - dmgHere
                                    if ps ~= target then ps.hitFlash = 0.3 end
                                end
                                target.hitFlash = 1.0
                                battleStats.dmgTaken = battleStats.dmgTaken + actualEsDmg
                                selfDmg = actualEsDmg  -- reflect 基于总伤害
                            else
                                -- P1-1 FRIGATE: 协同护卫 — HP>50%时将20%伤害转移给最近友舰
                                local sharedDmg = 0
                                -- P2-3 SCATTER: 散兵阵禁用协同护卫
                                local frigateShareEnabled = not (ctx.FORMATION_CONFIG[ctx.currentFormation] or {}).disableFrigateShare
                                if frigateShareEnabled and target.stype == "FRIGATE" and target.health > target.maxHealth * 0.5
                                   and #playerFleet > 1 then
                                    local ally = findNearest(target, playerFleet)
                                    if ally and ally ~= target then
                                        sharedDmg = math.floor(actualEsDmg * ctx.FRIGATE_SHARE_RATIO)
                                        ally.health = ally.health - sharedDmg
                                        ally.hitFlash = 0.6
                                        battleStats.dmgTaken = battleStats.dmgTaken + sharedDmg
                                        BattleUtils.spawnHitSparks(ctx, ally.x, ally.y, sharedDmg, "player")
                                    end
                                end
                                selfDmg = actualEsDmg - sharedDmg
                                target.health = target.health - selfDmg
                                target.hitFlash = 1.0
                                battleStats.dmgTaken = battleStats.dmgTaken + selfDmg
                            end
                            -- P1-1 模块: reflect — 受击时概率反弹伤害
                            if target.moduleEffect and target.moduleEffect.type == "reflect" then
                                if math.random() < target.moduleEffect.chance then
                                    local reflectDmg = math.floor(selfDmg * target.moduleEffect.ratio)
                                    es.health = es.health - reflectDmg
                                    es.hitFlash = 1.0
                                    battleStats.dmgDealt = battleStats.dmgDealt + reflectDmg
                                    target.statDmg = (target.statDmg or 0) + reflectDmg
                                    BattleUtils.spawnHitSparks(ctx, es.x, es.y, reflectDmg, "enemy")
                                    ctx.floatTexts[#ctx.floatTexts+1] = {
                                        x=es.x, y=es.y - 16,
                                        text="反弹!"..reflectDmg,
                                        life=0.9, maxLife=0.9, vy=-28, team="reflect"
                                    }
                                end
                            end
                        end
                        -- 敌方命中玩家：橙红火花
                        if not isBlocked then
                            BattleUtils.spawnHitSparks(ctx, target.x, target.y, actualEsDmg, "player")
                        end
                        -- 敌方战列舰 AOE（P2-3 SCATTER: AOE伤害减半）
                        if es.aoeRadius > 0 then
                            local aoeMult = (ctx.FORMATION_CONFIG[ctx.currentFormation] or {}).aoeDmgMult or 1.0
                            local aoeDmg = math.floor(es.dmg * 0.5 * aoeMult)
                            BattleUtils.spawnShockRing(ctx, target.x, target.y,
                                es.aoeRadius, 0.30, 255, 120, 40)
                            for _, splash in ipairs(playerFleet) do
                                if splash ~= target then
                                    local sx = splash.x - target.x
                                    local sy = splash.y - target.y
                                    if sx*sx + sy*sy <= es.aoeRadius * es.aoeRadius then
                                        splash.health = splash.health - aoeDmg
                                        battleStats.dmgTaken = battleStats.dmgTaken + aoeDmg
                                        BattleUtils.spawnHitSparks(ctx, splash.x, splash.y, aoeDmg, "player")
                                        ctx.floatTexts[#ctx.floatTexts+1] = {
                                            x=splash.x + math.random(-4,4), y=splash.y - 14,
                                            text="-"..aoeDmg, life=0.7, maxLife=0.7,
                                            vy=-28, team="player"
                                        }
                                    end
                                end
                            end
                        end
                        ctx.projectiles[#ctx.projectiles+1] = {
                            x=es.x, y=es.y,
                            tx=target.x, ty=target.y,
                            team="enemy", life=0.15,
                            isBig = (es.stype == "BATTLECRUISER")
                        }
                        -- 飘字：我方舰船受到伤害（护盾强化时显示减伤；格挡时不显示）
                        if not isBlocked then
                        -- P3-1: 护盾吸收用蓝色 team="shield"，普通伤害按量级分级
                        local isShielded = shieldMult < 1.0
                        local dmgLabel = isShielded
                            and ("🛡-" .. actualEsDmg)
                            or  ("-" .. actualEsDmg)
                        local pLife = actualEsDmg >= 100 and 1.5 or (actualEsDmg >= 20 and 1.2 or 0.8)
                        local pVy   = actualEsDmg >= 100 and -50 or (actualEsDmg >= 20 and -40 or -32)
                        ctx.floatTexts[#ctx.floatTexts+1] = {
                            x=target.x + math.random(-6,6),
                            y=target.y - 16,
                            text=dmgLabel,
                            life=pLife, maxLife=pLife,
                            vy=pVy,
                            team= isShielded and "shield" or "player"
                        }
                        end  -- isBlocked guard
                        ::skip_enemy_hit::
                    end
                end
            end
        end
        es.x = clamp(es.x, 10, ctx.screenW-10)
        es.y = clamp(es.y, 88, ctx.screenH-10)
    end
end

return BattleCombatEnemy
