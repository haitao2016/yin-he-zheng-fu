------------------------------------------------------------
-- battle/BattleTimers.lua
-- 每帧计时器递减、背景星空、环境粒子、连击衰减、
-- 增援系统、自适应音乐、指挥官技能、要塞回复
------------------------------------------------------------

local Audio             = require("game.AudioManager")
local BattleReplaySystem = require("game.BattleReplaySystem")
local BattleSkills      = require("game.BattleSkills")
local Commander         = require("game.CommanderSystem")
local UICommon          = require("game.ui.UICommon")
local BattleUtils       = require("game.battle.BattleUtils")

local BattleTimers = {}

------------------------------------------------------------
--- 计时器/背景/环境/增援 每帧更新
---@param dt number 帧增量
---@param ctx table BattleContext
---@param makeShip function 造舰工厂
------------------------------------------------------------
function BattleTimers.Update(dt, ctx, makeShip)
    ctx.shootSfxTimer = math.max(0, ctx.shootSfxTimer - dt)
    ctx.screenW, ctx.screenH = UICommon.getVirtualSize()

    -- === 增援冷却倒计时 ===
    if ctx.reinforceCooldown > 0 then
        ctx.reinforceCooldown = math.max(0, ctx.reinforceCooldown - dt)
    end

    -- === 背景星星视差滚动 + 闪烁 ===
    ctx.bgScrollX = ctx.bgScrollX + ctx.BG_SCROLL_VX * dt
    ctx.bgScrollY = ctx.bgScrollY + ctx.BG_SCROLL_VY * dt
    for _, s in ipairs(ctx.bgStars) do
        s.twinklePhase = s.twinklePhase + s.twinkleSpeed * dt
    end

    -- === 全屏闪光衰减 + Boss 横幅倒计时 ===
    if ctx.bossFlashAlpha > 0 then
        ctx.bossFlashAlpha = math.max(0, ctx.bossFlashAlpha - dt * 280)
    end
    if ctx.bossFlashTimer > 0 then
        ctx.bossFlashTimer = ctx.bossFlashTimer - dt
    end
    -- 里程碑 Boss 闪光衰减 + 横幅倒计时
    if ctx.milestoneFlashAlpha > 0 then
        ctx.milestoneFlashAlpha = math.max(0, ctx.milestoneFlashAlpha - dt * 180)
    end
    if ctx.milestoneBannerTimer > 0 then
        ctx.milestoneBannerTimer = ctx.milestoneBannerTimer - dt
    end

    -- === 夹击公告倒计时 ===
    if ctx.pincerAnnounceTimer > 0 then
        ctx.pincerAnnounceTimer = math.max(0, ctx.pincerAnnounceTimer - dt)
    end

    -- === 宿敌公告/结算倒计时 ===
    if ctx.nemesisAnnounceTimer > 0 then
        ctx.nemesisAnnounceTimer = ctx.nemesisAnnounceTimer - dt
    end
    if ctx.nemesisResultTimer > 0 then
        ctx.nemesisResultTimer = ctx.nemesisResultTimer - dt
    end
    -- 异象通知倒计时
    if ctx.anomalyNotifyTimer > 0 then
        ctx.anomalyNotifyTimer = ctx.anomalyNotifyTimer - dt
        if ctx.anomalyNotifyTimer <= 0 then ctx.anomalyNotify = nil end
    end

    -- === 指挥官技能冷却 & 激活 ===
    Commander.Update(dt)
    if ctx.cmdSkillActive then
        ctx.cmdSkillTimer = ctx.cmdSkillTimer - dt
        if ctx.cmdSkillTimer <= 0 then
            ctx.cmdSkillActive = false
            ctx.cmdSkillDef    = nil
            if ctx.notifyFn then ctx.notifyFn("指挥官技能效果结束", "info") end
        end
    end
    if ctx.state == "fighting" and not ctx.cmdSkillActive and ctx.commanderFleetId then
        if input:GetKeyPress(KEY_Q) then
            local ok, skillDef = Commander.ActivateSkill(ctx.commanderFleetId)
            if ok and skillDef then
                if skillDef.duration > 0 then
                    ctx.cmdSkillActive = true
                    ctx.cmdSkillTimer  = skillDef.duration
                    ctx.cmdSkillDef    = skillDef
                    if ctx.notifyFn then ctx.notifyFn(string.format("⚡ %s 发动!", skillDef.name), "success") end
                    BattleUtils.logBattleEvent(ctx, string.format("指挥官发动「%s」", skillDef.name))
                else
                    if ctx.notifyFn then ctx.notifyFn(string.format("⚡ %s 生效!", skillDef.name), "success") end
                end
            elseif not ok then
                if ctx.notifyFn then ctx.notifyFn("指挥官技能冷却中", "info") end
            end
        end
    end

    -- === 战斗回放帧录制 ===
    if ctx.state == "fighting" then
        BattleReplaySystem.RecordFrame(dt, ctx.playerFleet, ctx.enemyFleet)
    end

    -- === 战斗环境更新（公告渐出）===
    if ctx.envAnnounceTimer > 0 then
        ctx.envAnnounceTimer = ctx.envAnnounceTimer - dt
        if ctx.envAnnounceTimer < 0.5 then
            ctx.envAnnounceAlpha = math.floor(ctx.envAnnounceTimer / 0.5 * 255)
        else
            ctx.envAnnounceAlpha = 255
        end
    end

    -- === 环境粒子生成与更新 ===
    BattleTimers._updateEnvParticles(dt, ctx)

    -- === 连击计时更新（超时结算 credits 奖励）===
    BattleTimers._updateCombo(dt, ctx)

    -- === 主动技能计时 ===
    if ctx.state == "fighting" then
        BattleSkills.Update(dt, {
            state       = ctx.state,
            rs          = ctx.rs,
            notifyFn    = ctx.notifyFn,
            playerFleet = ctx.playerFleet,
            floatTexts  = ctx.floatTexts,
            screenW     = ctx.screenW,
            screenH     = ctx.screenH,
            makeShip    = makeShip,
        })
        -- FORTRESS_PROTOCOL: 每10s为玩家舰队回复 shieldRegenPct 的 HP
        if ctx.rm and ctx.rm.baseBonus and ctx.rm.baseBonus.shieldRegenPct then
            ctx.fortressRegenTimer = ctx.fortressRegenTimer + dt
            if ctx.fortressRegenTimer >= 10.0 then
                ctx.fortressRegenTimer = ctx.fortressRegenTimer - 10.0
                local regen = ctx.rm.baseBonus.shieldRegenPct
                for _, ship in ipairs(ctx.playerFleet) do
                    if ship.health > 0 then
                        local heal = math.max(1, math.floor(ship.maxHealth * regen))
                        ship.health = math.min(ship.maxHealth, ship.health + heal)
                    end
                end
            end
        end
    end

    -- === 自适应音乐强度 ===
    if ctx.state == "fighting" and ctx.RF.startEnemyCnt > 0 then
        local ratio = #ctx.enemyFleet / ctx.RF.startEnemyCnt
        if ratio > 1.3 then
            Audio.SetAdaptivePitchTarget(1.05)
        elseif ratio <= 0.5 then
            Audio.SetAdaptivePitchTarget(1.0)
        end
    end

    -- === 增援触发检测 ===
    if ctx.state == "fighting" and ctx.RF.pending and not ctx.RF.spawned then
        local halfCount = math.floor(ctx.RF.startEnemyCnt * 0.5)
        if #ctx.enemyFleet <= halfCount and ctx.RF.startEnemyCnt > 0 then
            ctx.RF.pending = false
            ctx.RF.warning = ctx.RF.WARN_DUR
            if ctx.notifyFn then ctx.notifyFn("⚠️ 海盗援军正在赶来！", "error") end
        end
    end

    -- === 增援预警倒计时 + 生成 ===
    if ctx.state == "fighting" and ctx.RF.warning and ctx.RF.warning > 0 then
        ctx.RF.warning = ctx.RF.warning - dt
        if ctx.RF.warning <= 0 and not ctx.RF.spawned then
            ctx.RF.spawned = true
            local count = 2 + math.random(0, 1)
            ctx.RF.remain = count
            for _ = 1, count do
                local ey = ctx.screenH * 0.15 + math.random() * ctx.screenH * 0.70
                local ship = makeShip("FRIGATE", ctx.screenW + 30, ey, "enemy")
                ship.isReinforce = true
                ship.glowR = 255; ship.glowG = 60; ship.glowB = 60
                ctx.enemyFleet[#ctx.enemyFleet + 1] = ship
            end
            if ctx.notifyFn then ctx.notifyFn(string.format("🚨 %d 艘海盗援舰入场！", count), "error") end
        end
    end
end

------------------------------------------------------------
--- 环境粒子子更新（内部）
------------------------------------------------------------
function BattleTimers._updateEnvParticles(dt, ctx)
    local env = ctx.currentEnv
    if not env then return end
    local pt = env.particleType
    if pt == "none" then return end

    -- 生成粒子
    local spawnCount = 0
    if pt == "nebula" then spawnCount = 3
    elseif pt == "asteroid" then spawnCount = 2
    elseif pt == "magstor" then spawnCount = 2 end

    local screenW, screenH = ctx.screenW, ctx.screenH
    for _ = 1, spawnCount do
        local pr, pg, pb = env.pR, env.pG, env.pB
        local p = {}
        if pt == "nebula" then
            p.x      = math.random() * screenW
            p.y      = math.random() * screenH
            p.vx     = (math.random() - 0.5) * 8
            p.vy     = (math.random() - 0.5) * 6
            p.size   = 20 + math.random() * 50
            p.life   = 4.0 + math.random() * 3.0
            p.maxLife = p.life
            p.r      = pr + math.random(-20, 20)
            p.g      = pg + math.random(-10, 10)
            p.b      = pb + math.random(-20, 20)
            p.maxA   = 30 + math.random(20)
        elseif pt == "asteroid" then
            p.x      = screenW + 10
            p.y      = 88 + math.random() * (screenH - 88)
            p.vx     = -(60 + math.random() * 80)
            p.vy     = (math.random() - 0.5) * 20
            p.size   = 2 + math.random() * 5
            p.life   = 2.0 + math.random() * 1.5
            p.maxLife = p.life
            p.r      = pr + math.random(-20, 20)
            p.g      = pg + math.random(-15, 15)
            p.b      = pb + math.random(-15, 15)
            p.maxA   = 160 + math.random(60)
        elseif pt == "magstor" then
            p.x      = math.random() * screenW
            p.y      = screenH + 10
            p.vx     = (math.random() - 0.5) * 30
            p.vy     = -(80 + math.random() * 120)
            p.size   = 1.0 + math.random() * 1.5
            p.len    = 8 + math.random() * 20
            p.life   = 0.4 + math.random() * 0.4
            p.maxLife = p.life
            p.r      = pr + math.random(-10, 40)
            p.g      = pg + math.random(-20, 20)
            p.b      = pb + math.random(-10, 10)
            p.maxA   = 180 + math.random(60)
        end
        p.r = math.max(0, math.min(255, p.r))
        p.g = math.max(0, math.min(255, p.g))
        p.b = math.max(0, math.min(255, p.b))
        ctx.envParticles[#ctx.envParticles + 1] = p
    end

    -- 更新 + 清理粒子
    local pi = 1
    while pi <= #ctx.envParticles do
        local p = ctx.envParticles[pi]
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(ctx.envParticles, pi)
        else
            pi = pi + 1
        end
    end

    -- 小行星带：周期性碎片伤害
    if pt == "asteroid" and ctx.state == "fighting" then
        ctx.envAsteroidTimer = ctx.envAsteroidTimer - dt
        if ctx.envAsteroidTimer <= 0 then
            ctx.envAsteroidTimer = env.asteroidInterval or 2.0
            local allShips = {}
            for _, s in ipairs(ctx.playerFleet) do allShips[#allShips + 1] = { s = s, team = "player" } end
            for _, s in ipairs(ctx.enemyFleet)  do allShips[#allShips + 1] = { s = s, team = "enemy" } end
            if #allShips > 0 then
                local target = allShips[math.random(#allShips)]
                local dmg = env.asteroidDamage
                target.s.health = target.s.health - dmg
                target.s.hitFlash = 0.6
                BattleUtils.spawnHitSparks(ctx, target.s.x, target.s.y, dmg, target.team)
                ctx.floatTexts[#ctx.floatTexts + 1] = {
                    x = target.s.x, y = target.s.y - 20,
                    text = "☄-" .. dmg,
                    life = 1.0, maxLife = 1.0,
                    vy = -28, team = target.team,
                }
            end
        end
    end
end

------------------------------------------------------------
--- 连击计时更新（内部）
------------------------------------------------------------
function BattleTimers._updateCombo(dt, ctx)
    if ctx.comboCount > 0 then
        ctx.comboTimer = ctx.comboTimer + dt
        if ctx.comboTimer >= ctx.COMBO_RESET_TIME then
            -- 连击结束：≥3连击才给予 credits 奖励
            if ctx.comboCount >= 3 and ctx.rm then
                local credits = ctx.comboCount * 20
                ctx.rm:add("credits", credits)
                ctx.floatTexts[#ctx.floatTexts + 1] = {
                    x = ctx.screenW * 0.5,
                    y = ctx.screenH * 0.38,
                    text = string.format("连击奖励 +%d 星币！", credits),
                    life = 2.0, maxLife = 2.0, vy = -16, team = "combo_reward",
                }
            end
            ctx.comboCount = 0
            ctx.comboTimer = 0
        end
    end
    if ctx.comboDisplayTimer > 0 then
        ctx.comboDisplayTimer = math.max(0, ctx.comboDisplayTimer - dt)
    end
end

return BattleTimers
