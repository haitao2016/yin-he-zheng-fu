---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-- ============================================================================
-- network/ClientBattle.lua  -- 银河征服 战斗/波次/结算/远征/探索/DDA
-- 从 Client.lua 拆分而来（P3-1b）
-- ============================================================================

local Sys         = require("game.Systems")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local Campaign    = require("game.CampaignSystem")
local Commander   = require("game.CommanderSystem")
local GalaxyScene = require("game.GalaxyScene")
local GameUI      = require("game.GameUI")
local LegacySystem= require("game.LegacySystem")
local NemesisSystem = require("game.NemesisSystem")

local M = {}  -- 模块公开接口
local S = {}  -- 共享状态（由 M.Init 注入）

-- ============================================================================
-- EXPLORER 舰探索任务模板（20条）
-- ============================================================================
local MAX_EXPLORER_TASKS = 3

local EXPLORER_TASK_TEMPLATES = {
    { label="扫描异常信号",  minDur=30, maxDur=45,
      rewards={ {res="minerals",amt=300}, {res="esource",amt=200} },
      expGain=60,  icon="📡", eventType="scan" },
    { label="探测矿脉地层",  minDur=40, maxDur=60,
      rewards={ {res="minerals",amt=500}, {res="crystal",amt=80} },
      expGain=80,  icon="⛏", eventType="mining" },
    { label="回收遗落飞船",  minDur=25, maxDur=40,
      rewards={ {res="esource",amt=350} },
      expGain=50,  icon="🛸", eventType="salvage" },
    { label="侦察海盗据点",  minDur=35, maxDur=50,
      rewards={ {res="credits",amt=150} },
      expGain=100, icon="🔍", pirateIntel=true, eventType="intel" },
    { label="测绘深空星云",  minDur=50, maxDur=75,
      rewards={ {res="nuclear",amt=120}, {res="crystal",amt=60} },
      expGain=120, icon="🌌", eventType="survey" },
    { label="捕获宇宙物质",  minDur=20, maxDur=35,
      rewards={ {res="esource",amt=200}, {res="minerals",amt=150} },
      expGain=40,  icon="✨" },
    { label="破译古代信标",  minDur=60, maxDur=90,
      rewards={ {res="credits",amt=400}, {res="crystal",amt=100} },
      expGain=150, icon="📜" },
    { label="援救漂流舱",    minDur=15, maxDur=25,
      rewards={ {res="minerals",amt=200}, {res="esource",amt=100} },
      expGain=30,  icon="🆘" },
    { label="测试新型推进器", minDur=45, maxDur=65,
      rewards={ {res="nuclear",amt=200}, {res="credits",amt=100} },
      expGain=90,  icon="🚀" },
    { label="追踪中子脉冲",  minDur=55, maxDur=80,
      rewards={ {res="nuclear",amt=150}, {res="esource",amt=150} },
      expGain=110, icon="⚡" },
    { label="采集暗物质云",  minDur=70, maxDur=100,
      rewards={ {res="crystal",amt=200}, {res="esource",amt=300} },
      expGain=180, icon="🌀" },
    { label="勘察宜居行星",  minDur=40, maxDur=60,
      rewards={ {res="minerals",amt=400}, {res="credits",amt=200} },
      expGain=100, icon="🌍" },
    { label="清除太空碎片",  minDur=20, maxDur=30,
      rewards={ {res="minerals",amt=250}, {res="credits",amt=80} },
      expGain=45,  icon="🗑" },
    { label="监听通讯频道",  minDur=30, maxDur=45,
      rewards={ {res="credits",amt=250} },
      expGain=80,  icon="📻", pirateIntel=true },
    { label="修复中继卫星",  minDur=35, maxDur=55,
      rewards={ {res="esource",amt=300}, {res="credits",amt=150} },
      expGain=90,  icon="🛰" },
    { label="猎杀游荡无人机", minDur=25, maxDur=40,
      rewards={ {res="nuclear",amt=80},  {res="credits",amt=180} },
      expGain=70,  icon="🤖" },
    { label="提取恒星风能",  minDur=50, maxDur=70,
      rewards={ {res="esource",amt=450} },
      expGain=120, icon="☀" },
    { label="解析虫洞坐标",  minDur=75, maxDur=110,
      rewards={ {res="crystal",amt=150}, {res="nuclear",amt=180}, {res="credits",amt=300} },
      expGain=200, icon="🕳" },
    { label="回传量子探测数据", minDur=65, maxDur=90,
      rewards={ {res="esource",amt=250}, {res="crystal",amt=80} },
      expGain=140, icon="🔭" },
    { label="突袭补给卫星",  minDur=30, maxDur=50,
      rewards={ {res="minerals",amt=600}, {res="nuclear",amt=100} },
      expGain=110, icon="💥", pirateIntel=true },
}

-- ============================================================================
-- P2-1: 无尽模式强化卡牌池（30张）
-- ============================================================================
M.ENDLESS_CARD_POOL = {
    -- 战斗类（6张）
    { key="dmg_up_sm",    rarity="common", icon="⚔",  label="火力强化 I",
      desc="舰队攻击力+15%",
      effect={ shipDmgMult=0.15 } },
    { key="dmg_up_lg",    rarity="rare",   icon="⚔",  label="火力强化 II",
      desc="舰队攻击力+30%，击杀时有10%概率双倍伤害",
      effect={ shipDmgMult=0.30 } },
    { key="hp_up_sm",     rarity="common", icon="🛡",  label="装甲加固 I",
      desc="所有舰船生命值+20%",
      effect={ shipHealthMult=0.20 } },
    { key="hp_up_lg",     rarity="rare",   icon="🛡",  label="装甲加固 II",
      desc="所有舰船生命值+40%，旗舰额外+10%",
      effect={ shipHealthMult=0.40 } },
    { key="aoe_up",       rarity="rare",   icon="💥",  label="爆破扩散",
      desc="AOE武器爆炸范围+40%",
      effect={ aoeRadiusMult=0.40 } },
    { key="double_edge",  rarity="epic",   icon="⚡",  label="双刃战术",
      desc="攻击力+50%，舰船生命值-15%，高风险高回报",
      effect={ shipDmgMult=0.50, shipHealthMult=-0.15 } },

    -- 生产类（5张）
    { key="prod_metal",   rarity="common", icon="⛏",  label="矿脉开采协议",
      desc="矿产采集速率+25%",
      effect={ miningRateMult=0.25 } },
    { key="prod_energy",  rarity="common", icon="⚡",  label="能源超频",
      desc="能源生产速率+25%",
      effect={ energyRateMult=0.25 } },
    { key="prod_nuclear", rarity="rare",   icon="☢",  label="核融合炉",
      desc="核能生产速率+40%，储量上限+200",
      effect={ nuclearRateMult=0.40, nuclearCapBonus=200 } },
    { key="prod_all",     rarity="epic",   icon="🌟",  label="全面增产",
      desc="所有资源生产速率+20%",
      effect={ miningRateMult=0.20, energyRateMult=0.20, nuclearRateMult=0.20 } },
    { key="shipyard_up",  rarity="rare",   icon="🚢",  label="快速造舰",
      desc="造舰速度+35%",
      effect={ shipyardSpeedMult=0.35 } },

    -- 战略类（4张）
    { key="fleet_cap",    rarity="rare",   icon="🛸",  label="编队扩编",
      desc="最大编队数量+2",
      effect={ fleetCapBonus=2 } },
    { key="repair_field", rarity="common", icon="🔧",  label="战场维修",
      desc="战斗中舰船每波开始前恢复15%生命值",
      effect={ waveRepairPct=0.15 } },
    { key="intel_net",    rarity="common", icon="📡",  label="情报网络",
      desc="海盗基地情报获取速度+50%，探索任务时长-20%",
      effect={ explorerDurMult=-0.20, intelRateMult=0.50 } },
    { key="quantum_leap", rarity="epic",   icon="🌀",  label="量子跃迁",
      desc="所有生产+30%，攻击+20%，生命值+20%，史诗级全面强化",
      effect={ miningRateMult=0.30, energyRateMult=0.30, nuclearRateMult=0.30,
               shipDmgMult=0.20, shipHealthMult=0.20 } },

    -- P2-1 V2.0: 15张史诗扩展卡
    { key="void_blade",    rarity="epic", icon="🌑", label="虚空刃",
      desc="攻击力+60%，但舰船HP-20%；极限输出流核心",
      effect={ shipDmgMult=0.60, shipHealthMult=-0.20 } },
    { key="titan_shield",  rarity="epic", icon="🛡", label="泰坦护盾",
      desc="舰船HP+60%，每波维修+10%，铁壁防守必备",
      effect={ shipHealthMult=0.60, waveRepairPct=0.10 } },
    { key="chain_reaction",rarity="epic", icon="⚛", label="链式反应",
      desc="AOE+60%，攻击+25%，核能产率+20%，爆炸覆盖极广",
      effect={ aoeRadiusMult=0.60, shipDmgMult=0.25, nuclearRateMult=0.20 } },
    { key="berserker",     rarity="epic", icon="🔥", label="狂战士",
      desc="攻击+80%，HP-30%，造舰速度+40%，疯狂进攻流",
      effect={ shipDmgMult=0.80, shipHealthMult=-0.30, shipyardSpeedMult=0.40 } },
    { key="phoenix_fire",  rarity="epic", icon="🦅", label="浴火凤凰",
      desc="每波维修+25%，攻击+30%，生命+30%，涅槃重生",
      effect={ waveRepairPct=0.25, shipDmgMult=0.30, shipHealthMult=0.30 } },
    { key="dyson_ring",    rarity="epic", icon="☀", label="戴森环",
      desc="能源产率+80%，核能储量+400，能源帝国核心",
      effect={ energyRateMult=0.80, nuclearCapBonus=400 } },
    { key="crystal_lattice",rarity="epic",icon="💎",label="晶格结构",
      desc="所有资源+35%，晶石产率额外+20%，完美平衡",
      effect={ miningRateMult=0.35, energyRateMult=0.35, nuclearRateMult=0.35 } },
    { key="mega_shipyard", rarity="epic", icon="🏭", label="巨型船坞",
      desc="造舰速度+70%，编队+3，快速成军之道",
      effect={ shipyardSpeedMult=0.70, fleetCapBonus=3 } },
    { key="stellar_forge", rarity="epic", icon="⭐", label="恒星熔炉",
      desc="矿石+50%，核能+50%，攻击+20%，工业军事双强",
      effect={ miningRateMult=0.50, nuclearRateMult=0.50, shipDmgMult=0.20 } },
    { key="armada",        rarity="epic", icon="🚀", label="无敌舰队",
      desc="编队+5，攻击+20%，生命+20%，钢铁洪流",
      effect={ fleetCapBonus=5, shipDmgMult=0.20, shipHealthMult=0.20 } },
    { key="war_economy",   rarity="epic", icon="💰", label="战争经济",
      desc="所有资源+25%，攻击+25%，造舰+25%，全能强化",
      effect={ miningRateMult=0.25, energyRateMult=0.25, nuclearRateMult=0.25,
               shipDmgMult=0.25, shipyardSpeedMult=0.25 } },
    { key="singularity",   rarity="epic", icon="🌌", label="奇点突破",
      desc="所有加成×1.2叠加（对已有卡效果额外+20%）",
      effect={ shipDmgMult=0.20, shipHealthMult=0.20, miningRateMult=0.20,
               energyRateMult=0.20, nuclearRateMult=0.20, shipyardSpeedMult=0.20 } },
    { key="logistics_net", rarity="epic", icon="📦", label="后勤网络",
      desc="造舰+50%，维修+20%，探索时长-40%，后勤为王",
      effect={ shipyardSpeedMult=0.50, waveRepairPct=0.20, explorerDurMult=-0.40 } },
    { key="apex_predator", rarity="epic", icon="👑", label="顶点掠食者",
      desc="攻击+45%，AOE+45%，每波维修+15%，猎手之巅",
      effect={ shipDmgMult=0.45, aoeRadiusMult=0.45, waveRepairPct=0.15 } },
    { key="omega_protocol",rarity="epic", icon="Ω",  label="Ω协议",
      desc="全属性+40%，最终形态，无尽的终极传说卡",
      effect={ shipDmgMult=0.40, shipHealthMult=0.40, miningRateMult=0.40,
               energyRateMult=0.40, nuclearRateMult=0.40, shipyardSpeedMult=0.40,
               fleetCapBonus=2, waveRepairPct=0.10 } },
}

-- ============================================================================
-- 模块初始化（依赖注入）
-- ============================================================================
--- @param state table 共享状态引用表
--- 必须包含的字段:
---   vg, rm, rs, spq, fm, pirateAI, player, endlessRound, endlessCardBonuses,
---   hiddenStats, dda, piratesKilled, battleStatsCache, endGameTriggered,
---   isEndlessMode, isCampaignMode, leagueMode, endlessStreakBuff,
---   explorerTasks, explorerTaskSeq, pirateAttackInfo, totalPlayTime,
---   lastExpedition, difficulty, RES_LABELS, TECHS, evBonus,
---   markBaseEffectsDirty, saveGame, softReset, totalResearch
---   switchSceneFn, checkStageGoalsFn
function M.Init(state)
    S = state
end

-- ============================================================================
-- 无尽选卡
-- ============================================================================

--- 从 ENDLESS_CARD_POOL 随机不重复抽取 count 张卡
--- P2-1 V2.0: 每5轮起必保至少1张史诗卡
function M.DrawEndlessCards(count)
    local pool  = {}
    for _, c in ipairs(M.ENDLESS_CARD_POOL) do pool[#pool+1] = c end
    -- Fisher-Yates 洗牌
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local result = {}
    for i = 1, math.min(count, #pool) do result[#result+1] = pool[i] end

    -- P2-1 V2.0: 第5轮起，若抽出结果中无史诗卡，则强制换入一张
    if S.endlessRound >= 5 then
        local hasEpic = false
        for _, c in ipairs(result) do
            if c.rarity == "epic" then hasEpic = true; break end
        end
        if not hasEpic then
            local epics = {}
            for _, c in ipairs(M.ENDLESS_CARD_POOL) do
                if c.rarity == "epic" then epics[#epics+1] = c end
            end
            if #epics > 0 then
                result[#result] = epics[math.random(1, #epics)]
            end
        end
    end
    return result
end

--- 将选中卡牌的 effect 累加到 endlessCardBonuses_，然后触发重算
function M.ApplyEndlessCard(cardKey)
    local chosen = nil
    for _, c in ipairs(M.ENDLESS_CARD_POOL) do
        if c.key == cardKey then chosen = c; break end
    end
    if not chosen then return end

    local eff = chosen.effect
    local cb  = S.endlessCardBonuses
    for field, delta in pairs(eff) do
        cb[field] = (cb[field] or 0) + delta
    end

    -- 重新计算基地模块效果（将会在末尾叠加卡牌加成）
    S.markBaseEffectsDirty()

    -- P2-3: 隐藏成就 — 无尽选卡统计
    S.hiddenStats.totalCardsChosen = S.hiddenStats.totalCardsChosen + 1
    Achievement.Check("endless_card", {
        totalCardsChosen = S.hiddenStats.totalCardsChosen,
        lastCardRarity   = chosen.rarity,
    })

    GameUI.Notify(string.format("✅ 已获得「%s」！", chosen.label), "success")
    Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
end

-- ============================================================================
-- DDA（动态难度调整）
-- ============================================================================

--- 应用 DDA 调整值到战斗参数
function M.DdaApply()
    -- DDA 当前不做主动调整（被动通过 dda_.hpAdj 在 BattleScene 中使用）
end

--- 战斗结束后评估 DDA
function M.DdaEvaluateBattle(isWin, lossRatio)
    local dda = S.dda
    -- 滚动窗口记录（最近 5 场）
    dda.recentResults[#dda.recentResults + 1] = { win = isWin, lr = lossRatio }
    if #dda.recentResults > 5 then table.remove(dda.recentResults, 1) end

    -- 统计连续失败次数
    local consecLoss = 0
    for i = #dda.recentResults, 1, -1 do
        if not dda.recentResults[i].win then consecLoss = consecLoss + 1
        else break end
    end

    -- 调整规则：连续失败 ≥2 时降低敌方 HP（每次 ×1.4 叠加）
    if consecLoss >= 2 then
        local adj = -0.05 * consecLoss * 1.4
        dda.hpAdj = math.max(-0.4, (dda.hpAdj or 0) + adj)
        dda.adjustCount = (dda.adjustCount or 0) + 1
    elseif isWin and lossRatio < 0.2 then
        -- 大胜且几乎无损：稍微恢复 DDA（难度回升）
        dda.hpAdj = math.min(0, (dda.hpAdj or 0) + 0.03)
    end
end

--- 周期性 DDA 检查（HP 阈值微调）
function M.DdaPeriodicCheck()
    local dda = S.dda
    -- 检查基地 HP 占比：若 < 30%，稍微降低下一波难度
    local base = GalaxyScene.GetBase()
    if base and base.maxHp and base.maxHp > 0 then
        local hpRatio = (base.hp or base.maxHp) / base.maxHp
        if hpRatio < 0.3 then
            dda.hpAdj = math.max(-0.4, (dda.hpAdj or 0) - 0.02)
            dda.adjustCount = (dda.adjustCount or 0) + 1
        end
    end
end

-- ============================================================================
-- 探索任务
-- ============================================================================

--- 派遣 EXPLORER 舰执行任务
function M.StartExplorerTask()
    -- 检查当前运行中的任务数
    local running = 0
    for _, t in ipairs(S.explorerTasks) do
        if not t.done then running = running + 1 end
    end
    if running >= MAX_EXPLORER_TASKS then
        GameUI.Notify("探索舰已全部出动（最多"..MAX_EXPLORER_TASKS.."队）", "warn")
        return false
    end

    -- 随机选模板
    local tmpl = EXPLORER_TASK_TEMPLATES[math.random(1, #EXPLORER_TASK_TEMPLATES)]
    -- 任务时长: 受 explorerDurMult 影响
    local durMult = 1.0 + (S.endlessCardBonuses.explorerDurMult or 0)
    durMult = math.max(0.3, durMult)  -- 最低 30% 时长
    local dur = math.random(tmpl.minDur, tmpl.maxDur) * durMult

    -- 目标星球（随机选一个殖民地附近）
    local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
    local targetName = "未知区域"
    if #planets > 0 then
        targetName = planets[math.random(1, #planets)].name or "未知区域"
    end

    S.explorerTaskSeq = S.explorerTaskSeq + 1
    local task = {
        id         = S.explorerTaskSeq,
        label      = tmpl.label,
        targetName = targetName,
        duration   = dur,
        elapsed    = 0,
        reward     = tmpl.rewards,
        expGain    = tmpl.expGain or 50,
        icon       = tmpl.icon or "🛸",
        eventType  = tmpl.eventType,
        pirateIntel= tmpl.pirateIntel or false,
        done       = false,
    }
    S.explorerTasks[#S.explorerTasks + 1] = task
    GameUI.Notify(task.icon .. " 探索舰出发: " .. task.label .. " → " .. targetName, "info")
    Audio.Play(Audio.SFX.FLEET_LAUNCH)
    return true
end

--- 每帧更新探索任务进度
function M.UpdateExplorerTasks(dt)
    for _, task in ipairs(S.explorerTasks) do
        if not task.done then
            task.elapsed = task.elapsed + dt
            if task.elapsed >= task.duration then
                task.done = true
                -- 发放奖励
                for _, r in ipairs(task.reward) do
                    S.rm:add(r.res, r.amt)
                end
                -- 经验值
                if S.player and S.player.addExp then
                    S.player:addExp(task.expGain)
                end
                -- 海盗情报
                if task.pirateIntel and S.pirateAI then
                    S.pirateAI:addIntel(15 * (1 + (S.endlessCardBonuses.intelRateMult or 0)))
                end
                -- 通知
                local rewardStr = ""
                for _, r in ipairs(task.reward) do
                    local label = (S.RES_LABELS and S.RES_LABELS[r.res]) or r.res
                    rewardStr = rewardStr .. label .. "+" .. r.amt .. " "
                end
                GameUI.Notify(task.icon .. " 探索完成: " .. task.label .. " → " .. rewardStr, "success")
                Audio.Play(Audio.SFX.RESEARCH_COMPLETE)

                -- P2-3: 隐藏成就 — 探索任务完成统计
                S.hiddenStats.explorerTasksDone = (S.hiddenStats.explorerTasksDone or 0) + 1
                Achievement.Check("explorer", {
                    totalDone = S.hiddenStats.explorerTasksDone,
                    eventType = task.eventType,
                })
            end
        end
    end

    -- 清理已完成且确认的任务（保留最多 5 条历史）
    local kept = {}
    local doneCount = 0
    for i = #S.explorerTasks, 1, -1 do
        local t = S.explorerTasks[i]
        if t.done then
            doneCount = doneCount + 1
            if doneCount <= 5 then kept[#kept+1] = t end
        else
            kept[#kept+1] = t
        end
    end
    -- 反转 kept 恢复顺序
    local reversed = {}
    for i = #kept, 1, -1 do reversed[#reversed+1] = kept[i] end
    S.explorerTasks = reversed
end

-- ============================================================================
-- 无尽模式回合
-- ============================================================================

--- 开始新的无尽回合（AI 威胁升级、基地再生、攻击加速）
function M.DoStartEndlessRound()
    if not S.pirateAI then return end
    -- AI 威胁逐轮升级
    local threatInc = 0.12 + S.endlessRound * 0.03
    S.pirateAI:scaleThreat(1 + threatInc)
    -- 基地再生
    local base = GalaxyScene.GetBase()
    if base then
        local regenPct = math.max(0.05, 0.20 - S.endlessRound * 0.01)
        base.hp = math.min(base.maxHp, base.hp + math.floor(base.maxHp * regenPct))
    end
    -- 攻击间隔加速（每轮缩短 5%，最低 40% 基础间隔）
    local speedup = math.max(0.40, 1.0 - S.endlessRound * 0.05)
    S.pirateAI:setAttackIntervalMult(speedup)
    -- 恢复 AI
    S.pirateAI.paused = false
end

--- 无尽模式下一轮：连胜检测、卡牌抽选、里程碑奖励
function M.StartEndlessNextRound()
    -- 连胜检测：当前回合 killRate ≥ 0.8 视为连胜
    local stats = S.battleStatsCache or {}
    local killRate = 0
    if stats.enemiesKilled and stats.enemiesTotal and stats.enemiesTotal > 0 then
        killRate = stats.enemiesKilled / stats.enemiesTotal
    end
    if killRate >= 0.8 then
        S.endlessWinStreak = (S.endlessWinStreak or 0) + 1
    else
        S.endlessWinStreak = 0
        S.endlessStreakBuff = false
    end
    -- 连胜 3+ 触发连胜狂潮 buff（资源产出 ×1.5）
    if (S.endlessWinStreak or 0) >= 3 and not S.endlessStreakBuff then
        S.endlessStreakBuff = true
        GameUI.Notify("🔥 连胜狂潮！资源产出×1.5！", "legendary")
        S.markBaseEffectsDirty()
    end

    -- 回合递增
    S.endlessRound = S.endlessRound + 1

    -- 提交无尽排行榜
    if S.clientCloud and S.clientCloud.submitScore then
        S.clientCloud:submitScore("endless_wave", S.endlessRound)
    end

    -- 每轮 +1 零件
    if S.fm then S.fm:addSalvage(1) end

    -- 里程碑（每 10 轮）
    local isMilestone = (S.endlessRound % 10 == 0)
    if isMilestone then
        -- 奖励资源
        S.rm:add("metal",   500 * (S.endlessRound / 10))
        S.rm:add("nuclear", 100 * (S.endlessRound / 10))
        GameUI.Notify(string.format("🏆 无尽里程碑 %d 轮！奖励已发放！", S.endlessRound), "legendary")
        Audio.Play(Audio.SFX.ACHIEVEMENT)
        -- 20轮起：里程碑附带传说级 buff
        if S.endlessRound >= 20 then
            local buffCards = {"omega_protocol", "phoenix_fire", "war_economy"}
            local pick = buffCards[math.random(1, #buffCards)]
            M.ApplyEndlessCard(pick)
            GameUI.Notify("✨ 传说加持: " .. pick, "legendary")
        end
    end

    -- 抽牌（里程碑时全史诗）
    local cardCount = 3
    local cards = M.DrawEndlessCards(cardCount)
    if isMilestone then
        -- 里程碑全部替换为史诗
        local epics = {}
        for _, c in ipairs(M.ENDLESS_CARD_POOL) do
            if c.rarity == "epic" then epics[#epics+1] = c end
        end
        for i = 1, #cards do
            cards[i] = epics[math.random(1, #epics)]
        end
    end

    -- 暂停 pirateAI，等待玩家选卡
    if S.pirateAI then S.pirateAI.paused = true end

    -- 显示选卡 UI
    GameUI.ShowCardDraft(cards, function(chosenKey)
        M.ApplyEndlessCard(chosenKey)
        M.DoStartEndlessRound()
    end)
end

-- ============================================================================
-- 胜败判定
-- ============================================================================

--- 检查胜利条件（所有海盗基地被摧毁）
function M.CheckVictory()
    if S.endGameTriggered then return end
    local bases = S.pirateAI and S.pirateAI:getBases() or {}
    local allDestroyed = true
    for _, b in ipairs(bases) do
        if b.hp > 0 then allDestroyed = false; break end
    end
    if not allDestroyed then return end

    -- 胜利！
    if S.isCampaignMode then
        Campaign.OnMissionComplete(S.difficulty)
    end
    if S.isEndlessMode then
        -- 无尽模式不直接结束，进入下一轮
        M.StartEndlessNextRound()
        return
    end
    M.TriggerEndGame("win")
end

--- 检查失败条件（基地 HP ≤ 0）
function M.CheckDefeat()
    if S.endGameTriggered then return end
    local base = GalaxyScene.GetBase()
    if not base then return end
    if base.hp > 0 then return end
    M.TriggerEndGame("lose")
end

-- ============================================================================
-- 场景切换
-- ============================================================================

--- 切换场景（galaxy/battle）
function M.SwitchScene(name)
    S.currentScene = name
    if name == "galaxy" then
        Audio.PlayBGM(Audio.BGM.GALAXY_MAIN)
        Audio.ResetBGMPitch()
    elseif name == "battle" then
        Audio.PlayBGM(Audio.BGM.BATTLE_THEME)
    end
end

--- 获取玩家可攻击目标列表
function M.GetPlayerTargets()
    local targets = {}
    -- 殖民地：使用行星在星系中的世界坐标（轨道坐标）
    local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
    for _, p in ipairs(planets) do
        if p.colonized then
            local wx = p.system and (p.system.x + math.cos(p.angle) * p.orbitRadius) or 0
            local wy = p.system and (p.system.y + math.sin(p.angle) * p.orbitRadius) or 0
            targets[#targets+1] = { x = wx, y = wy, name = p.name }
        end
    end
    -- 星航基地（已展开时才是目标）
    local base = GalaxyScene.GetBase()
    if base and base.colonized then
        targets[#targets+1] = { x = base.x or 0, y = base.y or 0, name = "主基地" }
    end
    return targets
end

-- ============================================================================
-- 海盗攻击处理
-- ============================================================================

--- 海盗攻击回调
function M.OnPirateAttack(pirateLevel, baseId, targetName)
    local BattleScene = require("game.BattleScene")

    -- P2-3: 教学提示（首次被攻击）
    local TutorialSystem = require("game.ui.TutorialSystem")
    TutorialSystem.Trigger("first_pirate_attack")

    -- P1-2: STELLAR_FORTRESS 额外防御效果
    local fortressBonus = 0
    if S.rm and S.rm.baseBonus and S.rm.baseBonus.hasStellarFortress then
        fortressBonus = 0.3  -- 敌方伤害 -30%
    end

    S.pirateAttackInfo = {
        baseId  = baseId,
        level   = pirateLevel,
        siege   = false,
    }

    BattleScene.Init({
        vg           = S.vg,
        notifyFn     = GameUI.Notify,
        player       = S.player,
        rm           = S.rm,
        rs           = S.rs,
        spq          = S.spq,
        moduleMap    = S.rm.baseBonus,
        startWave    = pirateLevel,
        fortressBonus= fortressBonus,
        leagueAttackMult = S.leagueMode and require("game.LeagueSystem").GetWeekModifier().attackMult or 1.0,
        endlessRound = S.isEndlessMode and S.endlessRound or 0,
        onBattleEnd = function(result)
            -- 快照战斗统计
            S.battleStatsCache = BattleScene.GetStats and BattleScene.GetStats() or {}
            -- P2-3: 隐藏成就 — 集火击杀统计
            if S.battleStatsCache.focusKillCount and S.battleStatsCache.focusKillCount > 0 then
                S.hiddenStats.focusKills = S.hiddenStats.focusKills + S.battleStatsCache.focusKillCount
                if S.battleStatsCache.focusBossKill then S.hiddenStats.focusBossKill = true end
                Achievement.Check("focus_kill", {
                    focusKills    = S.hiddenStats.focusKills,
                    focusBossKill = S.hiddenStats.focusBossKill,
                })
            end
            S.hiddenStats.totalShipsLostCampaign = S.hiddenStats.totalShipsLostCampaign
                + (S.battleStatsCache.shipsLost or 0)
            if result == "win" then
                Audio.Play(Audio.SFX.VICTORY)
                S.piratesKilled = S.piratesKilled + 1
                Achievement.Check("pirate_kill", { piratesKilled = S.piratesKilled })
                -- P2-3: 隐藏成就 — 战斗结果检查
                Achievement.Check("battle_result", {
                    victory   = true,
                    shipsLost = S.battleStatsCache.shipsLost or 0,
                    overkillMax = S.battleStatsCache.overkillMax or 0,
                    ddaLevel  = S.dda.adjustCount,
                    totalShipsLostCampaign = S.hiddenStats.totalShipsLostCampaign,
                    chainCount    = S.battleStatsCache.chainCount or 0,
                    reinforceWin  = S.battleStatsCache.reinforceWin or false,
                })
                -- P1-1: 残骸零件奖励（防守：2~4）
                local salvageGain = math.random(2, 4)
                if S.fm then S.fm:addSalvage(salvageGain) end
                -- P1-2 V2.5: Boss 战斗掉落变异舰船（防守，10%概率）
                if S.battleStatsCache.bossKilled then
                    local MSys = require("game.MutantShipSystem")
                    local drop = MSys.TryBossDrop(0.10)
                    if drop then
                        GameUI.Notify("⚡ 获得变异舰船: " .. MSys.GetDisplayName(drop), "legendary")
                        Achievement.Check("mutant_ship", {
                            totalOwned    = #MSys.GetInventory(),
                            uniqueAffixes = MSys.CountUniqueAffixes(),
                        })
                    end
                end
                -- 削弱海盗基地
                if S.pirateAI and S.pirateAttackInfo then
                    S.pirateAI:weakenBase(S.pirateAttackInfo.baseId)
                end
                -- P2-2: 阶段目标检查
                if S.checkStageGoalsFn then S.checkStageGoalsFn() end
                M.CheckVictory()
            elseif result == "retreat" then
                -- 撤退：5% 资源惩罚
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                local penalty = 0.05
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = S.rm.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then S.rm:add(res, -loss) end
                end
                GameUI.Notify("战略撤退！资源轻微损失(5%)", "warn")
            else
                -- 失败：15% 资源惩罚（防御/护盾减免）
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                local penalty = 0.15
                local defMit = math.min(0.10, (S.rm.baseBonus.defense or 0) / 1000)
                local shieldMit = math.min(0.05, (S.rm.baseBonus.shield or 0) / 2000)
                penalty = math.max(0.03, penalty - defMit - shieldMit)
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = S.rm.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then S.rm:add(res, -loss) end
                end
                -- 海盗增强
                if S.pirateAI and S.pirateAttackInfo then
                    S.pirateAI:strengthenBase(S.pirateAttackInfo.baseId)
                end
                GameUI.Notify("防守失败！资源损失" .. math.floor(penalty*100) .. "%", "error")
                M.CheckDefeat()
            end
            -- DDA 评估
            do
                local dealt = S.battleStatsCache.dmgDealt or 0
                local taken = S.battleStatsCache.dmgTaken or 0
                local lr = dealt > 0 and (taken / dealt) or (taken > 0 and 1.0 or 0.0)
                M.DdaEvaluateBattle(result == "win", lr)
            end
            S.pirateAttackInfo = nil
            M.SwitchScene("galaxy")
            S.saveGame()
        end,
    })

    -- 将所有编队舰船加入战斗
    if S.fm then
        for fid, fl in pairs(S.fm.fleets) do
            for _, entry in ipairs(fl.ships) do
                for _ = 1, entry.count do
                    BattleScene.AddProductionShip(entry.shipType)
                end
            end
        end
    end

    M.SwitchScene("battle")
    Audio.Play(Audio.SFX.BATTLE_START)
    GameUI.Notify(string.format("⚠️ 海盗(Lv%d)进攻 %s！", pirateLevel, targetName or "基地"), "error")
end

-- ============================================================================
-- 远征/突袭
-- ============================================================================

--- 计算编队战力
function M.CalcFleetPower(fleetId)
    if not S.fm then return 0 end
    local fl = S.fm.fleets[fleetId]
    if not fl then return 0 end
    local power = 0
    for _, entry in ipairs(fl.ships) do
        local shipDef = Sys.GetShipDef and Sys.GetShipDef(entry.shipType)
        local hp  = shipDef and shipDef.hp  or 100
        local atk = shipDef and shipDef.atk or 10
        power = power + hp * entry.count * (atk / 10)
    end
    return power
end

--- 计算海盗基地威胁值
function M.CalcBaseThreat(baseLevel)
    return 80 + baseLevel * 120
end

--- 发起远征
function M.LaunchExpedition(fleetId, baseId)
    if not S.fm or not S.pirateAI then return false, "系统未初始化" end
    local fl = S.fm.fleets[fleetId]
    if not fl then return false, "编队不存在" end
    if #fl.ships == 0 then return false, "编队无舰船" end

    local base = S.pirateAI:getBase(baseId)
    if not base then return false, "目标不存在" end

    -- 计算距离和时长
    local playerBase = GalaxyScene.GetBase()
    local dist = 100  -- 默认距离
    if playerBase and playerBase.pos and base.pos then
        local dx = (base.pos.x or 0) - (playerBase.pos.x or 0)
        local dz = (base.pos.z or 0) - (playerBase.pos.z or 0)
        dist = math.sqrt(dx*dx + dz*dz)
    end
    local speedMult = (S.rm and S.rm.baseBonus and S.rm.baseBonus.fleetSpeedMult) or 1.0
    local duration = math.max(10, dist / (2.0 * speedMult))

    local exp = {
        fleetId  = fleetId,
        baseId   = baseId,
        duration = duration,
        elapsed  = 0,
        power    = M.CalcFleetPower(fleetId),
        threat   = M.CalcBaseThreat(base.level),
    }
    S.lastExpedition = exp
    GameUI.Notify(string.format("🚀 编队出征！预计%.0f秒到达", duration), "info")
    Audio.Play(Audio.SFX.FLEET_LAUNCH)
    return true
end

--- 远征结算
function M.SettleExpedition(exp)
    if not exp then return end
    local hitRate = exp.power / math.max(1, exp.threat)
    if hitRate > 0.75 then
        -- 大胜
        GameUI.Notify("远征大胜！海盗基地严重受损！", "success")
        Audio.Play(Audio.SFX.VICTORY)
        if S.pirateAI then
            S.pirateAI:weakenBase(exp.baseId)
            S.pirateAI:weakenBase(exp.baseId)
        end
        -- 奖励
        S.rm:add("credits", 300)
        if S.fm then S.fm:addSalvage(math.random(3, 6)) end
    elseif hitRate >= 0.40 then
        -- 小胜
        GameUI.Notify("远征成功！略有斩获。", "info")
        if S.pirateAI then S.pirateAI:weakenBase(exp.baseId) end
        S.rm:add("credits", 100)
        if S.fm then S.fm:addSalvage(math.random(1, 3)) end
    else
        -- 失败
        GameUI.Notify("远征失败！舰队损失惨重...", "error")
        Audio.Play(Audio.SFX.BATTLE_LOSE)
        -- 编队损失 30%
        local fl = S.fm and S.fm.fleets[exp.fleetId]
        if fl then
            local toRemove = {}
            for _, entry in ipairs(fl.ships) do
                local loss = math.max(1, math.floor(entry.count * 0.3))
                for _ = 1, loss do toRemove[#toRemove+1] = entry.shipType end
            end
            for _, st in ipairs(toRemove) do S.fm:removeShip(exp.fleetId, st) end
            GalaxyScene.InvalidateFleetColor(exp.fleetId)
            GameUI.RefreshFleetPanel(S.fm, exp.fleetId)
        end
    end
    S.lastExpedition = nil
    S.saveGame()
end

-- ============================================================================
-- 编队突袭（onFleetSiegeBase）
-- ============================================================================

--- 玩家主动突袭海盗基地
function M.OnFleetSiegeBase(fleetId, baseId)
    local BattleScene = require("game.BattleScene")
    if not S.pirateAI then return end
    local base = S.pirateAI:getBase(baseId)
    if not base then
        GameUI.Notify("目标基地不存在", "error")
        return
    end

    S.pirateAttackInfo = {
        baseId  = baseId,
        fleetId = fleetId,
        level   = base.level,
        siege   = true,
    }

    -- 收集突袭编队的模块配置
    local raidModuleMap = S.rm and S.rm.baseBonus or {}
    local raidMutantMap = nil
    local MSys = require("game.MutantShipSystem")
    if MSys.GetEquippedForFleet then
        raidMutantMap = MSys.GetEquippedForFleet(fleetId)
    end
    local raidCmdBonus = Commander.GetFleetBonus(fleetId)

    BattleScene.Init({
        vg           = S.vg,
        notifyFn     = GameUI.Notify,
        player       = S.player,
        rm           = S.rm,
        rs           = S.rs,
        spq          = S.spq,
        moduleMap    = raidModuleMap,
        mutantMap    = raidMutantMap,
        startWave    = base.level,
        leagueAttackMult = S.leagueMode and require("game.LeagueSystem").GetWeekModifier().attackMult or 1.0,
        endlessRound = S.isEndlessMode and S.endlessRound or 0,
        commanderBonus   = raidCmdBonus,
        commanderFleetId = fleetId,
        onBattleEnd = function(result)
            -- 快照战斗统计
            S.battleStatsCache = BattleScene.GetStats and BattleScene.GetStats() or {}
            -- P2-3: 隐藏成就 — 集火击杀统计累计（突袭战斗）
            if S.battleStatsCache.focusKillCount and S.battleStatsCache.focusKillCount > 0 then
                S.hiddenStats.focusKills = S.hiddenStats.focusKills + S.battleStatsCache.focusKillCount
                if S.battleStatsCache.focusBossKill then S.hiddenStats.focusBossKill = true end
                Achievement.Check("focus_kill", {
                    focusKills    = S.hiddenStats.focusKills,
                    focusBossKill = S.hiddenStats.focusBossKill,
                })
            end
            S.hiddenStats.totalShipsLostCampaign = S.hiddenStats.totalShipsLostCampaign
                + (S.battleStatsCache.shipsLost or 0)
            if result == "win" then
                Audio.Play(Audio.SFX.VICTORY)
                S.piratesKilled = S.piratesKilled + 1
                Achievement.Check("pirate_kill", { piratesKilled = S.piratesKilled })
                -- P2-3: 隐藏成就 — 战斗结果检查（突袭）
                Achievement.Check("battle_result", {
                    victory   = true,
                    shipsLost = S.battleStatsCache.shipsLost or 0,
                    overkillMax = S.battleStatsCache.overkillMax or 0,
                    ddaLevel  = S.dda.adjustCount,
                    totalShipsLostCampaign = S.hiddenStats.totalShipsLostCampaign,
                    chainCount    = S.battleStatsCache.chainCount or 0,
                    reinforceWin  = S.battleStatsCache.reinforceWin or false,
                })
                -- P1-3 V2.4: 突袭指挥官战斗经验
                local raidFleetId = S.pirateAttackInfo and S.pirateAttackInfo.fleetId or nil
                if raidFleetId then
                    Commander.OnBattleEnd(raidFleetId,
                        S.battleStatsCache.kills or 0, S.battleStatsCache.wavesCleared or 0)
                end
                -- P1-1: 残骸零件奖励（突袭：3~6）
                local salvageGain = math.random(3, 6)
                -- P1-3 V2.4: 指挥官"战场回收"加成
                if raidFleetId then
                    local salvageMult = Commander.GetSalvageMult(raidFleetId)
                    salvageGain = math.floor(salvageGain * salvageMult)
                end
                if S.fm then S.fm:addSalvage(salvageGain) end
                -- P1-2 V2.5: Boss 战斗掉落变异舰船（突袭，15%概率）
                if S.battleStatsCache.bossKilled then
                    local MSys2 = require("game.MutantShipSystem")
                    local drop = MSys2.TryBossDrop(0.15)
                    if drop then
                        GameUI.Notify("⚡ 获得变异舰船: " .. MSys2.GetDisplayName(drop), "legendary")
                        Achievement.Check("mutant_ship", {
                            totalOwned    = #MSys2.GetInventory(),
                            uniqueAffixes = MSys2.CountUniqueAffixes(),
                        })
                    end
                end
                -- 突袭胜利：双倍削弱
                if S.pirateAI and S.pirateAttackInfo then
                    S.pirateAI:weakenBase(S.pirateAttackInfo.baseId)
                    S.pirateAI:weakenBase(S.pirateAttackInfo.baseId)
                end
                GameUI.Notify("突袭成功！海盗基地受到重创！(+🔩×"..salvageGain..")", "success")
                M.CheckVictory()
            elseif result == "retreat" then
                -- P1-2: 战略撤退 — 5% 资源惩罚
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                local penalty = 0.05
                local lostParts = {}
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = S.rm.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then
                        S.rm:add(res, -loss)
                        lostParts[#lostParts+1] = (S.RES_LABELS and S.RES_LABELS[res] or res) .. "-" .. loss
                    end
                end
                -- 撤退时舰队仅损失 10%
                if S.pirateAttackInfo and S.pirateAttackInfo.fleetId and S.fm then
                    local fid = S.pirateAttackInfo.fleetId
                    local fl  = S.fm.fleets[fid]
                    if fl then
                        local toRemove = {}
                        for _, entry in ipairs(fl.ships) do
                            local loss = math.floor(entry.count * 0.1)
                            for _ = 1, loss do
                                toRemove[#toRemove+1] = entry.shipType
                            end
                        end
                        for _, st in ipairs(toRemove) do
                            S.fm:removeShip(fid, st)
                        end
                        GalaxyScene.InvalidateFleetColor(fid)
                        GameUI.RefreshFleetPanel(S.fm, fid)
                    end
                end
                local lostStr = #lostParts > 0
                    and ("轻微损失(5%): " .. table.concat(lostParts, " "))
                    or "无资源损失"
                GameUI.Notify("战略撤退成功！" .. lostStr, "warn")
            else
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                -- 突袭失败：该编队损失约 50% 舰船
                if S.pirateAttackInfo and S.pirateAttackInfo.fleetId and S.fm then
                    local fid = S.pirateAttackInfo.fleetId
                    local fl  = S.fm.fleets[fid]
                    if fl then
                        local toRemove = {}
                        for _, entry in ipairs(fl.ships) do
                            local loss = math.max(1, math.floor(entry.count * 0.5))
                            for _ = 1, loss do
                                toRemove[#toRemove+1] = entry.shipType
                            end
                        end
                        for _, st in ipairs(toRemove) do
                            S.fm:removeShip(fid, st)
                        end
                        GalaxyScene.InvalidateFleetColor(fid)
                        GameUI.RefreshFleetPanel(S.fm, fid)
                    end
                end
                GameUI.Notify("突袭失败！舰队损失惨重！", "error")
            end
            -- P3-3: DDA 战斗后评估（突袭战斗）
            do
                local dealt = S.battleStatsCache.dmgDealt or 0
                local taken = S.battleStatsCache.dmgTaken or 0
                local lr = dealt > 0 and (taken / dealt) or (taken > 0 and 1.0 or 0.0)
                M.DdaEvaluateBattle(result == "win", lr)
            end
            S.pirateAttackInfo = nil
            M.SwitchScene("galaxy")
            S.saveGame()
        end,
    })

    -- 将该编队的舰船加入战斗（突袭只用派出的编队）
    if S.fm then
        local fl = S.fm.fleets[fleetId]
        if fl then
            for _, entry in ipairs(fl.ships) do
                for _ = 1, entry.count do
                    BattleScene.AddProductionShip(entry.shipType)
                end
            end
        end
    end

    M.SwitchScene("battle")
    Audio.Play(Audio.SFX.BATTLE_START)
    GameUI.Notify(string.format("突袭海盗基地 Lv%d！进入战斗！", base.level), "error")
end

-- ============================================================================
-- 结算触发
-- ============================================================================

--- 触发结算界面（只触发一次）
function M.TriggerEndGame(gameType)
    if S.endGameTriggered then return end
    S.endGameTriggered = true

    -- 收集统计数据
    local colonized = 0
    local colPlanets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
    for _, p in ipairs(colPlanets) do
        if p.colonized then colonized = colonized + 1 end
    end

    -- P3-3: 星级评分计算（1-3星）
    local dmgDealt   = S.battleStatsCache.dmgDealt  or 0
    local dmgTaken   = S.battleStatsCache.dmgTaken  or 0
    local playMin    = (S.totalPlayTime or 0) / 60
    local lossRatio  = (dmgDealt > 0) and (dmgTaken / dmgDealt) or 1.0
    local stars = 1
    if playMin <= 8   then stars = stars + 1 end
    if lossRatio <= 0.4 then stars = stars + 1 end
    if gameType ~= "win" then stars = 1 end
    local mvpShip = S.battleStatsCache.bestSurvivor

    local stats = {
        playTime      = S.totalPlayTime,
        colonized     = colonized,
        piratesKilled = S.piratesKilled,
        level         = (S.player and S.player.level) or 1,
        rank          = (S.player and S.player.rank)  or "指挥官",
        dmgDealt      = dmgDealt,
        dmgTaken      = dmgTaken,
        enemiesKilled = S.battleStatsCache.enemiesKilled or 0,
        wavesCleared  = S.battleStatsCache.wavesCleared  or 0,
        bestSurvivor  = S.battleStatsCache.bestSurvivor,
        stars         = stars,
        mvpShip       = mvpShip,
        totalResearch = S.totalResearch,
        totalColonized = colonized,
        chainCount    = S.battleStatsCache.chainCount or 0,
        reinforceWin  = S.battleStatsCache.reinforceWin or false,
    }

    -- 暂停海盗 AI
    if S.pirateAI then S.pirateAI.paused = true end

    -- 计算得分
    local starMult = (stars == 3) and 1.6 or (stars == 2) and 1.3 or 1.0
    local scoreVal = math.floor((colonized * 100
                   + S.piratesKilled * 50
                   - math.floor((S.totalPlayTime or 0) / 60))
                   * starMult)
    scoreVal = math.max(0, scoreVal)

    -- 提交排行榜（仅比历史最好更高时）
    if S.clientCloud and S.clientCloud.submitScore then
        S.clientCloud:submitScore("galaxy_conquest", scoreVal, { onlyIfBetter = true })
    end

    -- P2-2: 战役模式结算
    if S.isCampaignMode and gameType == "win" then
        Campaign.OnMissionScore(scoreVal, stars)
    end

    -- 战绩统计
    local career = S.career or {}
    career.totalGames  = (career.totalGames or 0) + 1
    if gameType == "win" then career.totalWins = (career.totalWins or 0) + 1 end
    career.bestWave    = math.max(career.bestWave or 0, S.battleStatsCache.wavesCleared or 0)
    career.totalKills  = (career.totalKills or 0) + (S.battleStatsCache.enemiesKilled or 0)
    career.totalColonies = (career.totalColonies or 0) + colonized
    career.playtime    = (career.playtime or 0) + (S.totalPlayTime or 0)
    if mvpShip then career.bestMvpShip = mvpShip end
    -- 连胜/连败
    if gameType == "win" then
        career.curStreak = (career.curStreak or 0) + 1
        career.maxStreak = math.max(career.maxStreak or 0, career.curStreak)
    else
        career.curStreak = 0
    end
    -- 难度最高记录
    local diffOrder = { easy=1, normal=2, hard=3, custom=4 }
    local curDiffIdx = diffOrder[S.difficulty] or 2
    career.bestDiff = math.max(career.bestDiff or 0, curDiffIdx)
    -- 最近 10 局胜率
    career.recentWins = career.recentWins or {}
    career.recentWins[#career.recentWins+1] = (gameType == "win") and 1 or 0
    if #career.recentWins > 10 then table.remove(career.recentWins, 1) end
    -- 击杀舰种统计
    career.shipKills = career.shipKills or {}
    if S.battleStatsCache.killsByType then
        for st, cnt in pairs(S.battleStatsCache.killsByType) do
            career.shipKills[st] = (career.shipKills[st] or 0) + cnt
        end
    end
    S.career = career

    -- 文明进化点
    local civPts = math.floor(scoreVal / 50)
    if S.player and S.player.addCivPoints then
        S.player:addCivPoints(civPts)
    end

    -- P2-1: 每日挑战连胜
    if S.dailyChallenge and gameType == "win" then
        local today = os.date("%Y-%m-%d")
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
        -- 允许 1 小时容差
        if S.dailyChallenge.lastDate == today then
            -- 同一天再次胜利不计
        elseif S.dailyChallenge.lastDate == yesterday
            or (os.time() - (S.dailyChallenge.lastTime or 0)) < 3600 + 86400 then
            S.dailyChallenge.streak = (S.dailyChallenge.streak or 0) + 1
            S.dailyChallenge.lastDate = today
            S.dailyChallenge.lastTime = os.time()
        else
            S.dailyChallenge.streak = 1
            S.dailyChallenge.lastDate = today
            S.dailyChallenge.lastTime = os.time()
        end
    end

    -- 联赛模式
    if S.leagueMode then
        local LeagueSystem = require("game.LeagueSystem")
        LeagueSystem.SubmitGame(scoreVal, gameType == "win", stars)
    end

    -- P1-3 V2.5: 文明遗产
    LegacySystem.AwardEndOfGame(gameType, scoreVal, stars, S.totalPlayTime or 0)

    -- 保存战绩
    if S.saveCareer then S.saveCareer() end

    -- 云端额外同步（≤500B）
    if S.clientCloud and S.clientCloud.setExtra then
        local extra = {
            lastGame = gameType,
            stars    = stars,
            score    = scoreVal,
            diff     = S.difficulty,
        }
        local ok, json = pcall(require("cjson").encode, extra)
        if ok and #json <= 500 then
            S.clientCloud:setExtra(json)
        end
    end

    -- 战斗回放注入
    local BattleReplaySystem = require("game.BattleReplaySystem")
    if BattleReplaySystem.HasReplay and BattleReplaySystem.HasReplay() then
        stats.hasReplay = true
        stats.replayId  = BattleReplaySystem.GetLatestId()
    end

    -- 显示结算面板（scoreVal 并入 stats）
    stats.score = scoreVal
    GameUI.ShowEndGame(gameType, stats, function()
        -- 结算面板关闭后：softReset
        if S.softReset then S.softReset() end
    end)
end

-- ============================================================================
-- 模块公开常量
-- ============================================================================
M.MAX_EXPLORER_TASKS = MAX_EXPLORER_TASKS

return M
