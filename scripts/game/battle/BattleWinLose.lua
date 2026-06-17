------------------------------------------------------------
-- battle/BattleWinLose.lua
-- 胜负处理：
--   UpdateGuard — 已结束状态(win/lose)的每帧更新 + 烟花（提前返回守卫）
--   Detect      — 战斗中检测舰队覆灭/全歼，状态转移 + 资源奖励 + 星级 + 技能卡
-- 从 BattleScene.Update 提取
------------------------------------------------------------
local Audio              = require("game.AudioManager")
local BattleReplaySystem = require("game.BattleReplaySystem")
local BattleSkills       = require("game.BattleSkills")
local NemesisSystem      = require("game.NemesisSystem")
local Achievement        = require("game.AchievementSystem")
local FormationEditor    = require("game.ui.FormationEditor")
local BattleUtils        = require("game.battle.BattleUtils")

local BattleWinLose = {}

--- 已结束状态守卫：在 Update 开头调用
---@param dt number
---@param ctx table BattleContext
---@return boolean handled 若为 true，调用方应提前 return（跳过战斗逻辑）
---@return boolean startNext 若为 true，调用方应在 pull 状态后调用 StartNextWave
function BattleWinLose.UpdateGuard(dt, ctx)
    if ctx.state == "lose" then
        ctx.stateTimer = ctx.stateTimer + dt
        if ctx.stateTimer > 3.0 and ctx.onBattleEnd and not ctx.battleEndFired then
            ctx.battleEndFired = true
            ctx.onBattleEnd("lose")
        end
        return true, false, false
    end

    -- P1-6: Boss 预警阶段倒计时
    if ctx.state == "bossWarning" then
        ctx.stateTimer = ctx.stateTimer + dt
        ctx.bossWarningTimer = ctx.bossWarningTimer - dt
        -- 支持 SPACE 键跳过预警
        if not ctx.prepSkipped and input:GetKeyPress(KEY_SPACE) then
            ctx.prepSkipped = true
            ctx.bossWarningTimer = 0
        end
        if ctx.bossWarningTimer <= 0 then
            ctx.bossWarningActive = false
            return true, false, true  -- handled=true, startNext=false, startBoss=true
        end
        return true, false, false
    end

    if ctx.state == "win" then
        -- 显示倒计时后自动进入下一波
        ctx.waveGapTimer = ctx.waveGapTimer + dt
        ctx.stateTimer   = ctx.stateTimer + dt  -- P1-1: 驱动战报摘要淡入淡出
        ctx.starAnim     = ctx.starAnim + dt   -- P3-3: 驱动星星依次亮起动画
        -- P2-3: SPACE键跳过备战期
        if not ctx.prepSkipped and input:GetKeyPress(KEY_SPACE) then
            ctx.prepSkipped = true
            ctx.waveGapTimer = ctx.WAVE_GAP  -- 立即触发下一波
        end
        local startNext = (ctx.waveGapTimer >= ctx.WAVE_GAP)
        -- 烟花粒子：周期性发射
        ctx.fwLaunchTimer = ctx.fwLaunchTimer - dt
        if ctx.fwLaunchTimer <= 0 then
            ctx.fwLaunchTimer = 0.22 + math.random() * 0.18
            -- 随机颜色
            local hue = math.random()
            local r = math.floor(128 + 127 * math.abs(math.sin(hue * math.pi * 2)))
            local g = math.floor(128 + 127 * math.abs(math.sin((hue + 0.33) * math.pi * 2)))
            local b = math.floor(128 + 127 * math.abs(math.sin((hue + 0.66) * math.pi * 2)))
            local cx = ctx.screenW * (0.15 + math.random() * 0.7)
            local cy = ctx.screenH * (0.1 + math.random() * 0.4)
            -- 爆炸碎片（18 粒）
            for _ = 1, 18 do
                local angle = math.random() * math.pi * 2
                local spd   = 55 + math.random() * 95
                ctx.fwParticles[#ctx.fwParticles+1] = {
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
        while i <= #ctx.fwParticles do
            local p = ctx.fwParticles[i]
            p.x    = p.x + p.vx * dt
            p.y    = p.y + p.vy * dt
            p.vy   = p.vy + 60 * dt   -- 重力
            p.life = p.life - dt
            if p.life <= 0 then
                ctx.fwParticles[i] = ctx.fwParticles[#ctx.fwParticles]
                ctx.fwParticles[#ctx.fwParticles] = nil
            else
                i = i + 1
            end
        end
        return true, startNext, false
    end

    return false, false, false
end

--- 战斗中胜负检测与结算：在 Update 末尾调用
---@param dt number
---@param ctx table BattleContext
function BattleWinLose.Detect(dt, ctx)
    local playerFleet = ctx.playerFleet
    local enemyFleet  = ctx.enemyFleet
    local battleStats = ctx.battleStats

    -- === 判断胜负 ===
    if #playerFleet == 0 and ctx.state == "fighting" then
        ctx.state = "lose"
        ctx.stateTimer = 0
        -- P3-1: 停止录制并计算精彩时刻
        BattleReplaySystem.StopRecording()
        if ctx.notifyFn then ctx.notifyFn("舰队覆灭！战斗失败", "error") end
        if ctx.player then ctx.player.battles = (ctx.player.battles or 0) + 1 end
        -- P1-2: 宿敌战败处理
        if ctx.nemesisActive then
            ctx.nemesisResult = NemesisSystem.OnPlayerLose()
            ctx.nemesisResultTimer = ctx.NEMESIS_RESULT_DUR
            ctx.nemesisActive = false
        end
        print("[Battle] Wave " .. ctx.waveNum .. " 失败")
    elseif #enemyFleet == 0 and ctx.state == "fighting" then
        ctx.state = "win"
        ctx.stateTimer = 0
        ctx.waveGapTimer = 0
        ctx.formationLocked = false  -- P2-3: 备战期解锁阵型切换
        battleStats.wavesCleared = battleStats.wavesCleared + 1
        -- P2-2b: 战斗日志 — 波次通关摘要
        BattleUtils.logBattleEvent(ctx, string.format("第 %d 波通关 — 击杀 %d | 损失 %d | 最高连击 %d",
            ctx.waveNum, ctx.waveKills, ctx.waveShipsLost, ctx.waveMaxCombo))
        -- P3-1: 波次清空事件 + 停止录制（最终失败时由 lose 分支触发 Stop）
        BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.WAVE_CLEAR, {
            wave = ctx.waveNum, survivors = #playerFleet,
        })
        BattleReplaySystem.StopRecording()
        -- P3-3: 计算本波星级评分（基于存活率）
        do
            local survivors  = #playerFleet
            local initCount  = math.max(1, ctx.initialPlayerCount)
            local ratio      = survivors / initCount
            if ratio >= 0.75 then
                ctx.currentWaveStar = 3  -- 精英：≥75% 存活
            elseif ratio >= 0.40 then
                ctx.currentWaveStar = 2  -- 良好：≥40% 存活
            else
                ctx.currentWaveStar = 1  -- 惨胜：< 40% 存活
            end
            ctx.starAnim = 0   -- 重置动画计时器，触发星星依次亮起
        end
        -- 记录存活最久舰型（以 maxHealth 作代理指标）
        if #playerFleet > 0 then
            local best = playerFleet[1]
            for _, s in ipairs(playerFleet) do
                if s.health > best.health then best = s end
            end
            battleStats.bestSurvivor = best.stype
        end
        -- 波次胜利资源奖励（随波次递增）
        local mReward = 150 + ctx.waveNum * 80   -- 调优：基础 100→150，每波系数 50→80
        local eReward = 80  + ctx.waveNum * 40   -- 新增：能源奖励（减少精炼瓶颈）
        local cReward = 15  + ctx.waveNum * 8    -- 调优：基础 10→15，每波系数 5→8
        if ctx.rm then
            ctx.rm:add("metal",   mReward)
            ctx.rm:add("esource", eReward)
            ctx.rm:add("nuclear", cReward)
        end
        if ctx.notifyFn then
            ctx.notifyFn(string.format("第 %d 波胜利！金属+%d  能源+%d  核能+%d",
                ctx.waveNum, mReward, eReward, cReward), "success")
        end
        -- P1-1: 保存本波摘要快照（在重置连击前捕获 waveMaxCombo）
        -- P3-2: 计算本波 MVP（最高伤害玩家舰）
        local mvp = nil
        local mvpDmg = 0
        for _, ps in ipairs(playerFleet) do
            if ps.statDmg > mvpDmg then
                mvpDmg = ps.statDmg
                mvp = { stype = ps.stype, dmg = ps.statDmg, kills = ps.statKills }
            end
        end
        ctx.waveSummary = {
            wave     = ctx.waveNum,
            kills    = ctx.waveKills,
            maxCombo = ctx.waveMaxCombo,
            dmg      = math.floor(ctx.waveDmgDealt),
            lost     = ctx.waveShipsLost,
            mReward  = mReward,
            eReward  = eReward,
            cReward  = cReward,
            stars    = ctx.currentWaveStar,
            mvp      = mvp,   -- P3-2: {stype, dmg, kills} 或 nil
        }
        -- 重置连击（新波次重新积累）
        ctx.comboCount = 0
        ctx.comboTimer = 0
        if ctx.player then
            ctx.player.battles = (ctx.player.battles or 0) + 1
            ctx.player.wins    = (ctx.player.wins or 0) + 1
            ctx.player:addExp(200 + ctx.waveNum * 100)
        end
        print("[Battle] Wave " .. ctx.waveNum .. " 胜利  奖励: 金属+" .. mReward .. " 核能+" .. cReward)
        -- P2-2: 夹击模式成就检查（本波为夹击波次且胜利）
        if ctx.isPincerWave and not ctx.pincerDefended then
            ctx.pincerDefended = true
            Achievement.Check("pincer_wave", { defended = true })
            print("[Pincer] 成功防守夹击波次 Wave " .. ctx.waveNum)
        end
        -- P1-2: 宿敌胜利处理（记录玩家战术 + 结算）
        if ctx.nemesisActive then
            NemesisSystem.RecordPlayerTactics(playerFleet)
            ctx.nemesisResult = NemesisSystem.OnPlayerWin()
            ctx.nemesisResultTimer = ctx.NEMESIS_RESULT_DUR
            ctx.nemesisActive = false
            Audio.SetBGMPitch(1.0)  -- 恢复正常音调
            Achievement.Check("nemesis_defeated", { captain = NemesisSystem.GetActiveCaptain() })
            print("[Nemesis] 宿敌被击败！进化等级将提升")
        end
        -- P2-1 V2.5: 自定义阵型胜利计数 + 成就检查
        if ctx.currentFormation == "custom" then
            FormationEditor.AddCustomWin()
            Achievement.Check("custom_formation_win", {
                customFormationWins = FormationEditor.GetCustomWins(),
            })
        end
        -- P2-2: 每 3 波发放 1 个技能点，触发升级弹窗
        if ctx.waveNum % 3 == 0 then
            BattleSkills.AddPoint()
            -- 生成 2 张可选升级卡（随机选非满级技能）
            local candidates = {}
            for skillN = 1, 6 do
                if BattleSkills.GetLevel(skillN) < 3 then
                    candidates[#candidates+1] = skillN
                end
            end
            if #candidates >= 2 then
                -- 随机打乱，取前 2
                for ci = #candidates, 2, -1 do
                    local j = math.random(1, ci)
                    candidates[ci], candidates[j] = candidates[j], candidates[ci]
                end
                ctx.skillUpgradeCards = { candidates[1], candidates[2] }
            elseif #candidates == 1 then
                ctx.skillUpgradeCards = { candidates[1] }
            end
        end
    end
end

return BattleWinLose
