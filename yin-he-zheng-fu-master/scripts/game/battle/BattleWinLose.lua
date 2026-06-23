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

local ANIMATION_STATES = {
    IDLE = "idle",
    ENTRY = "entry",
    CELEBRATION = "celebration",
    STATS = "stats",
    REWARD = "reward",
    EXIT = "exit",
}

local function createVictoryEntryAnim(ctx)
    ctx.entryAnim = {
        state = ANIMATION_STATES.ENTRY,
        timer = 0,
        duration = 1.5,
        screenFlash = 0,
        textScale = 0,
        textAlpha = 0,
    }
end

local function createDefeatEntryAnim(ctx)
    ctx.entryAnim = {
        state = ANIMATION_STATES.ENTRY,
        timer = 0,
        duration = 2.0,
        screenFlash = 255,
        shakeIntensity = 15,
        textScale = 0,
        textAlpha = 0,
    }
end

local function updateEntryAnimation(dt, ctx)
    if not ctx.entryAnim then return end
    
    ctx.entryAnim.timer = ctx.entryAnim.timer + dt
    local progress = ctx.entryAnim.timer / ctx.entryAnim.duration
    
    if ctx.state == "win" then
        ctx.entryAnim.screenFlash = math.floor(255 * (1 - progress))
        ctx.entryAnim.textScale = progress * 1.2
        ctx.entryAnim.textAlpha = math.floor(255 * math.min(1, progress * 1.5))
        
        if progress >= 0.3 and not ctx.entryAnim.soundPlayed then
            Audio.Play(Audio.SFX.VICTORY)
            ctx.entryAnim.soundPlayed = true
        end
    else
        ctx.entryAnim.shakeIntensity = 15 * (1 - progress)
        ctx.entryAnim.textScale = progress
        ctx.entryAnim.textAlpha = math.floor(255 * math.min(1, progress * 1.2))
        
        if progress >= 0.2 and not ctx.entryAnim.soundPlayed then
            Audio.Play(Audio.SFX.DEFEAT)
            ctx.entryAnim.soundPlayed = true
        end
    end
    
    if progress >= 1 then
        ctx.entryAnim.state = ANIMATION_STATES.CELEBRATION
        ctx.entryAnim.timer = 0
    end
end

local function updateCelebrationAnimation(dt, ctx)
    if not ctx.entryAnim then return end
    if ctx.entryAnim.state ~= ANIMATION_STATES.CELEBRATION then return end
    
    ctx.entryAnim.timer = ctx.entryAnim.timer + dt
    
    if ctx.state == "win" then
        ctx.fwLaunchTimer = ctx.fwLaunchTimer - dt
        if ctx.fwLaunchTimer <= 0 then
            ctx.fwLaunchTimer = 0.15 + math.random() * 0.15
            local hue = math.random()
            local r = math.floor(128 + 127 * math.abs(math.sin(hue * math.pi * 2)))
            local g = math.floor(128 + 127 * math.abs(math.sin((hue + 0.33) * math.pi * 2)))
            local b = math.floor(128 + 127 * math.abs(math.sin((hue + 0.66) * math.pi * 2)))
            local cx = ctx.screenW * (0.15 + math.random() * 0.7)
            local cy = ctx.screenH * (0.1 + math.random() * 0.4)
            
            for _ = 1, 24 do
                local angle = math.random() * math.pi * 2
                local spd = 60 + math.random() * 100
                ctx.fwParticles[#ctx.fwParticles+1] = {
                    x = cx, y = cy,
                    vx = math.cos(angle) * spd,
                    vy = math.sin(angle) * spd - 30,
                    life = 0.8 + math.random() * 0.6,
                    maxLife = 1.4,
                    r = r, g = g, b = b,
                    type = "victory",
                }
            end
        end
        
        local starGlowTimer = (ctx.entryAnim.timer * 3) % 1
        ctx.starGlow = math.sin(starGlowTimer * math.pi) * 50 + 205
        
        if ctx.entryAnim.timer >= 2.0 then
            ctx.entryAnim.state = ANIMATION_STATES.STATS
            ctx.entryAnim.timer = 0
        end
    else
        if ctx.entryAnim.timer >= 1.5 then
            ctx.entryAnim.state = ANIMATION_STATS
            ctx.entryAnim.timer = 0
        end
    end
end

local function updateStatsAnimation(dt, ctx)
    if not ctx.entryAnim then return end
    if ctx.entryAnim.state ~= ANIMATION_STATES.STATS then return end
    
    ctx.entryAnim.timer = ctx.entryAnim.timer + dt
    local progress = ctx.entryAnim.timer / 1.0
    
    if progress >= 1 then
        ctx.entryAnim.state = ANIMATION_STATES.REWARD
        ctx.entryAnim.timer = 0
    end
end

local function updateRewardAnimation(dt, ctx)
    if not ctx.entryAnim then return end
    if ctx.entryAnim.state ~= ANIMATION_STATES.REWARD then return end
    
    ctx.entryAnim.timer = ctx.entryAnim.timer + dt
    local progress = ctx.entryAnim.timer / 1.5
    
    if progress >= 1 then
        ctx.entryAnim.state = ANIMATION_STATES.EXIT
        ctx.entryAnim.timer = 0
    end
end

--- 已结束状态守卫：在 Update 开头调用
---@param dt number
---@param ctx table BattleContext
---@return boolean handled 若为 true，调用方应提前 return（跳过战斗逻辑）
---@return boolean startNext 若为 true，调用方应在 pull 状态后调用 StartNextWave
function BattleWinLose.UpdateGuard(dt, ctx)
    if ctx.state == "lose" then
        if not ctx.entryAnim then
            createDefeatEntryAnim(ctx)
        end
        
        updateEntryAnimation(dt, ctx)
        updateCelebrationAnimation(dt, ctx)
        updateStatsAnimation(dt, ctx)
        updateRewardAnimation(dt, ctx)
        
        ctx.stateTimer = ctx.stateTimer + dt
        if ctx.stateTimer > 3.0 and ctx.onBattleEnd and not ctx.battleEndFired then
            ctx.battleEndFired = true
            ctx.onBattleEnd("lose")
        end
        return true, false
    end

    if ctx.state == "win" then
        if not ctx.entryAnim then
            createVictoryEntryAnim(ctx)
        end
        
        updateEntryAnimation(dt, ctx)
        updateCelebrationAnimation(dt, ctx)
        updateStatsAnimation(dt, ctx)
        updateRewardAnimation(dt, ctx)
        
        ctx.waveGapTimer = ctx.waveGapTimer + dt
        ctx.stateTimer = ctx.stateTimer + dt
        ctx.starAnim = ctx.starAnim + dt
        
        if not ctx.prepSkipped and input and input.GetKeyPress and input:GetKeyPress(KEY_SPACE) then
            ctx.prepSkipped = true
            ctx.waveGapTimer = ctx.WAVE_GAP
        end
        
        local startNext = (ctx.waveGapTimer >= ctx.WAVE_GAP)
        
        local i = 1
        while i <= #ctx.fwParticles do
            local p = ctx.fwParticles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 60 * dt
            p.life = p.life - dt
            if p.life <= 0 then
                ctx.fwParticles[i] = ctx.fwParticles[#ctx.fwParticles]
                ctx.fwParticles[#ctx.fwParticles] = nil
            else
                i = i + 1
            end
        end
        
        return true, startNext
    end

    return false, false
end

--- 战斗中胜负检测与结算：在 Update 末尾调用
---@param dt number
---@param ctx table BattleContext
function BattleWinLose.Detect(dt, ctx)
    local playerFleet = ctx.playerFleet
    local enemyFleet  = ctx.enemyFleet
    local battleStats = ctx.battleStats

    if #playerFleet == 0 and ctx.state == "fighting" then
        ctx.state = "lose"
        ctx.stateTimer = 0
        BattleReplaySystem.StopRecording()
        if ctx.notifyFn then ctx.notifyFn("舰队覆灭！战斗失败", "error") end
        if ctx.player then ctx.player.battles = (ctx.player.battles or 0) + 1 end
        
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
        ctx.formationLocked = false
        battleStats.wavesCleared = battleStats.wavesCleared + 1
        
        BattleUtils.logBattleEvent(ctx, string.format("第 %d 波通关 — 击杀 %d | 损失 %d | 最高连击 %d",
            ctx.waveNum, ctx.waveKills, ctx.waveShipsLost, ctx.waveMaxCombo))
        
        BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.WAVE_CLEAR, {
            wave = ctx.waveNum, survivors = #playerFleet,
        })
        BattleReplaySystem.StopRecording()
        
        do
            local survivors = #playerFleet
            local initCount = math.max(1, ctx.initialPlayerCount)
            local ratio = survivors / initCount
            if ratio >= 0.75 then
                ctx.currentWaveStar = 3
            elseif ratio >= 0.40 then
                ctx.currentWaveStar = 2
            else
                ctx.currentWaveStar = 1
            end
            ctx.starAnim = 0
        end
        
        if #playerFleet > 0 then
            local best = playerFleet[1]
            for _, s in ipairs(playerFleet) do
                if s.health > best.health then best = s end
            end
            battleStats.bestSurvivor = best.stype
        end
        
        local mReward = 150 + ctx.waveNum * 80
        local eReward = 80 + ctx.waveNum * 40
        local cReward = 15 + ctx.waveNum * 8
        if ctx.rm then
            ctx.rm:add("metal", mReward)
            ctx.rm:add("esource", eReward)
            ctx.rm:add("nuclear", cReward)
        end
        if ctx.notifyFn then
            ctx.notifyFn(string.format("第 %d 波胜利！金属+%d  能源+%d  核能+%d",
                ctx.waveNum, mReward, eReward, cReward), "success")
        end
        
        local mvp = nil
        local mvpDmg = 0
        for _, ps in ipairs(playerFleet) do
            if ps.statDmg > mvpDmg then
                mvpDmg = ps.statDmg
                mvp = { stype = ps.stype, dmg = ps.statDmg, kills = ps.statKills }
            end
        end
        
        ctx.waveSummary = {
            wave = ctx.waveNum,
            kills = ctx.waveKills,
            maxCombo = ctx.waveMaxCombo,
            dmg = math.floor(ctx.waveDmgDealt),
            lost = ctx.waveShipsLost,
            mReward = mReward,
            eReward = eReward,
            cReward = cReward,
            stars = ctx.currentWaveStar,
            mvp = mvp,
            avgHitRate = battleStats.totalHits > 0 and 
                math.floor((battleStats.totalHits / battleStats.totalShots) * 100) or 0,
            overkill = battleStats.overkillMax,
            focusKills = battleStats.focusKillCount,
        }
        
        ctx.comboCount = 0
        ctx.comboTimer = 0
        if ctx.player then
            ctx.player.battles = (ctx.player.battles or 0) + 1
            ctx.player.wins = (ctx.player.wins or 0) + 1
            ctx.player:addExp(200 + ctx.waveNum * 100)
        end
        print("[Battle] Wave " .. ctx.waveNum .. " 胜利  奖励: 金属+" .. mReward .. " 核能+" .. cReward)
        
        if ctx.isPincerWave and not ctx.pincerDefended then
            ctx.pincerDefended = true
            Achievement.Check("pincer_wave", { defended = true })
            print("[Pincer] 成功防守夹击波次 Wave " .. ctx.waveNum)
        end
        
        if ctx.nemesisActive then
            NemesisSystem.RecordPlayerTactics(playerFleet)
            ctx.nemesisResult = NemesisSystem.OnPlayerWin()
            ctx.nemesisResultTimer = ctx.NEMESIS_RESULT_DUR
            ctx.nemesisActive = false
            Audio.SetBGMPitch(1.0)
            Achievement.Check("nemesis_defeated", { captain = NemesisSystem.GetActiveCaptain() })
            print("[Nemesis] 宿敌被击败！进化等级将提升")
        end
        
        if ctx.currentFormation == "custom" then
            FormationEditor.AddCustomWin()
            Achievement.Check("custom_formation_win", {
                customFormationWins = FormationEditor.GetCustomWins(),
            })
        end
        
        if ctx.waveNum % 3 == 0 then
            BattleSkills.AddPoint()
            local candidates = {}
            for skillN = 1, 6 do
                if BattleSkills.GetLevel(skillN) < 3 then
                    candidates[#candidates+1] = skillN
                end
            end
            if #candidates >= 2 then
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

function BattleWinLose.GetAnimationState(ctx)
    if not ctx.entryAnim then return ANIMATION_STATES.IDLE end
    return ctx.entryAnim.state
end

function BattleWinLose.GetAnimationProgress(ctx)
    if not ctx.entryAnim then return 0 end
    return ctx.entryAnim.timer / (ctx.entryAnim.duration or 1)
end

return BattleWinLose