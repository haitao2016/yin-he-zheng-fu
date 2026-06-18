------------------------------------------------------------
-- battle/BattleDeath.lua
-- 死亡清理：爆炸/音效/震动 / 击杀归属 / 连击 / Boss奖励 / 连锁反应
-- 从 BattleScene.Update 提取（清理死亡舰船段 + 连锁反应段）
------------------------------------------------------------
local Audio              = require("game.AudioManager")
local BattleReplaySystem = require("game.BattleReplaySystem")
local BattleUtils        = require("game.battle.BattleUtils")

local BattleDeath = {}

--- 死亡清理与连锁反应更新
---@param dt number 帧时间步
---@param ctx table BattleContext 共享状态
---@param makeShip function 造舰工厂（fission 副本用）
function BattleDeath.Update(dt, ctx, makeShip)
    local playerFleet = ctx.playerFleet
    local enemyFleet  = ctx.enemyFleet
    local battleStats = ctx.battleStats

    -- === 清理死亡舰船（爆炸粒子 + 音效 + 震动）===
    for i = #playerFleet, 1, -1 do
        if playerFleet[i].health <= 0 then
            local ship = playerFleet[i]
            local st   = ship.stype
            local sfx  = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            BattleUtils.spawnExplosion(ctx, ship)
            ctx.waveShipsLost      = ctx.waveShipsLost + 1  -- P1-1: 本波损失舰船
            battleStats.shipsLost  = battleStats.shipsLost + 1  -- P2-3
            -- P3-1: 回放事件 - 己方舰船损失
            BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.SHIP_LOST, {
                shipId = ship._replayId, stype = ship.stype, x = ship.x, y = ship.y,
            })
            -- P2-2b: 战斗日志 — 己方舰船损失
            BattleUtils.logBattleEvent(ctx, string.format("%s 损失一艘%s", ctx.fleetName, BattleUtils.shipTypeName(ctx, ship.stype)))
            -- P1-2 V2.5: fission 词缀 — 死亡时生成2艘微型副本
            if ship.mutantAffixes then
                for _, aKey in ipairs(ship.mutantAffixes) do
                    if aKey == "fission" then
                        for fi = 1, 2 do
                            local clone = makeShip(ship.stype, ship.x + (fi * 20 - 30), ship.y + math.random(-15, 15), "player")
                            clone.maxHealth = math.floor(ship.maxHealth * 0.4)
                            clone.health    = clone.maxHealth
                            clone.dmg       = ship.dmg * 0.4
                            clone.speed     = ship.speed * 1.2
                            clone.scale     = (ship.scale or 1.0) * 0.6
                            clone.isFighter = true
                            clone.fighterLife = 8.0  -- 存活8秒
                            clone.mutantAffixes = nil  -- 副本不继承变异
                            playerFleet[#playerFleet + 1] = clone
                        end
                        break
                    end
                end
            end
            table.remove(playerFleet, i)
        end
    end
    -- P1-3: 收集本帧击杀位置，用于连锁判定
    local frameDeadPositions = {}
    for i = #enemyFleet, 1, -1 do
        if enemyFleet[i].health <= 0 then
            frameDeadPositions[#frameDeadPositions+1] = { x = enemyFleet[i].x, y = enemyFleet[i].y }
        end
    end

    for i = #enemyFleet, 1, -1 do
        if enemyFleet[i].health <= 0 then
            local ship = enemyFleet[i]
            local st   = ship.stype
            local sfx  = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            BattleUtils.spawnExplosion(ctx, ship)
            battleStats.enemiesKilled = battleStats.enemiesKilled + 1
            ctx.waveKills     = ctx.waveKills + 1       -- P1-1: 本波击杀累计
            ctx.waveKillTotal = ctx.waveKillTotal + 1   -- P2-1: 全场击杀累计
            -- P3-1: 回放事件 - 击杀敌舰
            do
                local evType = ship.isBoss and BattleReplaySystem.EVENT.BOSS_KILL or BattleReplaySystem.EVENT.KILL
                local killerId = ship.lastHitter and ship.lastHitter._replayId or nil
                BattleReplaySystem.RecordEvent(evType, {
                    shipId = ship._replayId, stype = ship.stype,
                    x = ship.x, y = ship.y, killerId = killerId, isBoss = ship.isBoss,
                })
                if killerId then
                    BattleReplaySystem.AddShipKill(killerId)
                end
            end
            -- P2-3: 过度击杀统计（超出血量的伤害比例）
            if ship.maxHealth and ship.maxHealth > 0 and ship.health < 0 then
                local overkillRatio = (-ship.health) / ship.maxHealth
                if overkillRatio > battleStats.overkillMax then
                    battleStats.overkillMax = overkillRatio
                end
            end
            -- P2-3: 集火击杀统计 (overkillMax 由攻击时追踪，focusBossKill 在此处)
            if ctx.focusTarget == ship then
                ctx.focusTarget = nil
                if ship.isBoss then battleStats.focusBossKill = true end
                -- 集火击杀通知（供 Client.lua 读取后触发成就）
                if battleStats.focusKillCount then
                    battleStats.focusKillCount = battleStats.focusKillCount + 1
                else
                    battleStats.focusKillCount = 1
                end
            end
            -- P3-2: 击杀归属到最后一次打这艘敌舰的玩家舰
            if ship.lastHitter then
                ship.lastHitter.statKills = ship.lastHitter.statKills + 1
                -- P1-1 模块: killHeal — 击杀时回复最大生命%
                local hitter = ship.lastHitter
                if hitter.moduleEffect and hitter.moduleEffect.type == "killHeal" then
                    local heal = math.floor(hitter.maxHealth * hitter.moduleEffect.value)
                    hitter.health = math.min(hitter.maxHealth, hitter.health + heal)
                end
                -- P1-2 V2.5: vampiric 词缀 — 击杀回复5%最大HP
                if hitter.mutantAffixes then
                    for _, aKey in ipairs(hitter.mutantAffixes) do
                        if aKey == "vampiric" then
                            local vHeal = math.floor(hitter.maxHealth * 0.05)
                            hitter.health = math.min(hitter.maxHealth, hitter.health + vHeal)
                        end
                    end
                end
            end
            -- === 连击系统 ===
            ctx.comboCount = ctx.comboCount + 1
            ctx.comboTimer = 0          -- 重置重置倒计时
            ctx.comboDisplayTimer = 2.0 -- 显示2秒
            if ctx.comboCount > ctx.waveMaxCombo then ctx.waveMaxCombo = ctx.comboCount end  -- P1-1
            -- P3-1: 更新全场最高连击 + 回放连击追踪
            if not battleStats.maxCombo or ctx.comboCount > battleStats.maxCombo then
                battleStats.maxCombo = ctx.comboCount
            end
            if ctx.comboCount >= 3 then
                BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.COMBO, {
                    count = ctx.comboCount, x = ship.x, y = ship.y,
                })
            end
            -- P2-2b: 战斗日志 — 高连击
            if ctx.comboCount == 5 or ctx.comboCount == 10 or ctx.comboCount == 20 then
                BattleUtils.logBattleEvent(ctx, string.format("%s 达成 %d 连击！", ctx.fleetName, ctx.comboCount))
            end
            if ship.lastHitter and ship.lastHitter._replayId then
                BattleReplaySystem.UpdateShipCombo(ship.lastHitter._replayId, ctx.comboCount)
            end
            local lv = BattleUtils.getComboLevel(ctx)
            if lv then
                -- P2-2: 连击飘字（击杀位置上方），credits 奖励在连击结束时统一结算
                ctx.floatTexts[#ctx.floatTexts+1] = {
                    x=ship.x, y=ship.y - 30,
                    text=string.format("x%d %s", ctx.comboCount, lv.label),
                    life=1.2, maxLife=1.2, vy=-22, team="combo"
                }
            elseif ctx.comboCount >= 2 then
                ctx.floatTexts[#ctx.floatTexts+1] = {
                    x=ship.x, y=ship.y - 26,
                    text=string.format("x%d", ctx.comboCount),
                    life=0.9, maxLife=0.9, vy=-18, team="combo"
                }
            end
            -- Boss 击败：额外奖励 + 多次爆炸 + 屏幕震动
            if ship.isBoss and not ctx.bossDefeated then
                ctx.bossDefeated = true
                -- 额外爆炸特效（3次；里程碑 Boss 额外更多）
                local explodeCount = ship.isMilestoneBoss and 6 or 3
                for _ = 1, explodeCount do BattleUtils.spawnExplosion(ctx, ship) end
                -- 强烈屏幕震动
                ctx.SK.strength = ship.isMilestoneBoss and 20 or 12
                ctx.SK.dur      = ship.isMilestoneBoss and 0.8 or 0.5
                ctx.SK.timer    = ctx.SK.dur
                -- P2-2b: 战斗日志 — Boss 击破
                BattleUtils.logBattleEvent(ctx, string.format("%s 击破第 %d 波旗舰Boss！", ctx.fleetName, ctx.waveNum))
                -- P3-2: 全屏闪光 + BOSS DESTROYED 横幅
                ctx.bossFlashAlpha = 220
                ctx.bossFlashTimer = ctx.BOSS_BANNER_DUR
                -- P2-3: 里程碑 Boss 特效
                if ship.isMilestoneBoss then
                    ctx.milestoneRound       = ctx.endlessRound
                    ctx.milestoneFlashAlpha  = 255
                    ctx.milestoneBannerTimer = ctx.MILESTONE_BANNER_DUR
                    -- 彩色烟花爆炸：在屏幕多处生成彩色粒子
                    local colors = {
                        {255, 80,  80 },  -- 红
                        {255, 200, 50 },  -- 金
                        { 80, 255, 120},  -- 绿
                        { 80, 180, 255},  -- 蓝
                        {255, 100, 255},  -- 紫
                        {255, 255, 100},  -- 黄
                    }
                    for ci = 1, 6 do
                        local cx = ctx.screenW * (0.15 + 0.14 * ci)
                        local cy = ctx.screenH * (0.25 + math.random() * 0.35)
                        local col = colors[((ci - 1) % #colors) + 1]
                        for _ = 1, 18 do
                            local angle = math.random() * math.pi * 2
                            local spd   = 90 + math.random() * 80
                            ctx.fwParticles[#ctx.fwParticles+1] = {
                                x = cx, y = cy,
                                vx = math.cos(angle) * spd,
                                vy = math.sin(angle) * spd,
                                life = 1.0 + math.random() * 0.8,
                                maxLife = 1.8,
                                r = col[1], g = col[2], b = col[3],
                                tail = false,
                            }
                        end
                    end
                    -- 里程碑专属资源奖励（更丰厚）
                    local nucBonus     = 150 + ctx.endlessRound * 30
                    local crystalBonus = 80  + ctx.endlessRound * 15
                    local metalBonus   = 100 + ctx.endlessRound * 20
                    if ctx.rm then
                        ctx.rm:add("nuclear", nucBonus)
                        ctx.rm:add("crystal", crystalBonus)
                        ctx.rm:add("metal",   metalBonus)
                    end
                    if ctx.notifyFn then
                        ctx.notifyFn(string.format(
                            "🏆 里程碑通关！第%d层  核能+%d  水晶+%d  金属+%d",
                            ctx.endlessRound, nucBonus, crystalBonus, metalBonus), "success")
                    end
                    print(string.format("[P2-3] 里程碑Boss击败！层=%d  核能+%d 水晶+%d 金属+%d",
                        ctx.endlessRound, nucBonus, crystalBonus, metalBonus))
                else
                    -- 普通 Boss 奖励
                    local nucBonus    = 80  + ctx.waveNum * 20
                    local crystalBonus= 30  + ctx.waveNum * 10
                    if ctx.rm then
                        ctx.rm:add("nuclear", nucBonus)
                        ctx.rm:add("crystal", crystalBonus)
                    end
                    if ctx.notifyFn then
                        ctx.notifyFn(string.format("⚔️ BOSS已击败！核能+%d  水晶+%d", nucBonus, crystalBonus), "success")
                    end
                    print(string.format("[Boss] Wave%d Boss击败  核能+%d 水晶+%d", ctx.waveNum, nucBonus, crystalBonus))
                end
                -- P3-3: Boss击败 — 播放胜利fanfare + 恢复BGM正常音调
                Audio.PlayBGM(Audio.BGM.VICTORY_FANFARE, 0.8, false)
                Audio.ResetBGMPitch()
            end
            -- P2-1: 增援舰击杀追踪
            if enemyFleet[i].isReinforce and ctx.RF.spawned and not ctx.RF.defeated then
                ctx.RF.remain = ctx.RF.remain - 1
                if ctx.RF.remain <= 0 then
                    ctx.RF.defeated = true
                    battleStats.reinforceWin = true
                    -- 逆境奖励：30% 额外星币
                    local bonus = math.max(5, math.floor(ctx.waveNum * 8 * 0.30))
                    if ctx.rm then ctx.rm:add("credits", bonus) end
                    ctx.floatTexts[#ctx.floatTexts+1] = {
                        x = ctx.screenW * 0.5, y = ctx.screenH * 0.42,
                        text = string.format("逆境奋战！+%d 星币", bonus),
                        life = 2.2, maxLife = 2.2, vy = -18, team = "reinforce_bonus"
                    }
                    if ctx.notifyFn then ctx.notifyFn(string.format("🏆 全歼增援！逆境奖励 +%d 星币", bonus), "success") end
                    print(string.format("[P2-1] 全歼增援  bonus=%d", bonus))
                end
            end
            -- P1-1 INTERCEPTOR: 超音速穿越 — 击杀后20%概率立刻再次攻击
            if ship.lastHitter and ship.lastHitter.stype == "INTERCEPTOR"
               and math.random() < 0.20 then
                ship.lastHitter.lastShot = 1.0 / ship.lastHitter.shotRate  -- 重置为可立即攻击
                ctx.floatTexts[#ctx.floatTexts+1] = {
                    x=ship.lastHitter.x, y=ship.lastHitter.y - 18,
                    text="超音速！", life=0.8, maxLife=0.8,
                    vy=-26, team="intercept"
                }
            end
            -- P1-1 EXPLORER: 标记目标死亡时清除标记
            if ctx.explorerMarkTarget == ship then
                ctx.explorerMarkTarget = nil
            end
            table.remove(enemyFleet, i)
        end
    end

    -- === P1-3: 连锁反应 ===
    if #frameDeadPositions >= ctx.CHAIN_MIN_KILLS then
        -- 对存活敌舰施加 AOE 伤害（每艘只受一次，非递归）
        for _, survivor in ipairs(enemyFleet) do
            for _, dp in ipairs(frameDeadPositions) do
                local dx = survivor.x - dp.x
                local dy = survivor.y - dp.y
                if dx*dx + dy*dy <= ctx.CHAIN_RADIUS*ctx.CHAIN_RADIUS then
                    local aoe = math.floor((survivor.maxHealth or 50) * ctx.CHAIN_AOE_PCT)
                    survivor.health = survivor.health - aoe
                    -- 显示 AOE 伤害数字
                    ctx.floatTexts[#ctx.floatTexts+1] = {
                        x=survivor.x + math.random(-8,8),
                        y=survivor.y - 20,
                        text=tostring(aoe),
                        life=0.9, maxLife=0.9, vy=-20, team="chain_dmg"
                    }
                    break  -- 每艘存活敌舰只受一次 AOE
                end
            end
        end
        -- 累计连锁次数
        ctx.chainCount = ctx.chainCount + 1
        battleStats.chainCount = battleStats.chainCount + 1
        -- P3-1: 回放事件 - 连锁反应
        BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.CHAIN, {
            count = #frameDeadPositions, chainTotal = battleStats.chainCount,
        })
        -- 计算爆炸质心，用于飘字位置
        local cx, cy = 0, 0
        for _, dp in ipairs(frameDeadPositions) do
            cx = cx + dp.x
            cy = cy + dp.y
        end
        cx = cx / #frameDeadPositions
        cy = cy / #frameDeadPositions
        -- CHAIN 飘字（橙色大字）
        ctx.floatTexts[#ctx.floatTexts+1] = {
            x=cx, y=cy - 45,
            text=string.format("CHAIN ×%d", #frameDeadPositions),
            life=1.6, maxLife=1.6, vy=-28, team="chain"
        }
        -- 冲击波扩散环（橙色）
        for _, dp in ipairs(frameDeadPositions) do
            ctx.shockRings[#ctx.shockRings+1] = {
                x=dp.x, y=dp.y,
                radius=12, maxRadius=ctx.CHAIN_RADIUS,
                life=0.5, maxLife=0.5,
                r=255, g=160, b=40, width=2
            }
        end
        -- 轻微屏幕震动
        if 5 > ctx.SK.strength or ctx.SK.timer <= 0 then
            ctx.SK.strength = 5
            ctx.SK.dur      = 0.3
            ctx.SK.timer    = 0.3
        end
        print(string.format("[Chain] ×%d 击杀触发连锁  AOE半径=%d  本场连锁=%d",
            #frameDeadPositions, ctx.CHAIN_RADIUS, ctx.chainCount))
    end
end

return BattleDeath
