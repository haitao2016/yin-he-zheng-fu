-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function getComboLevel()
    for _, lv in ipairs(COMBO_LEVELS) do
        if comboCount_ >= lv.min then return lv end
    end
    return nil
end

-- ============================================================================
-- 战斗统计（每场战斗累计，通过 BattleScene.GetStats() 导出）
-- ============================================================================
local battleStats_ = {
    dmgDealt     = 0,   -- 我方造成总伤害
    dmgTaken     = 0,   -- 我方承受总伤害
    enemiesKilled= 0,   -- 击落敌舰数量
    wavesCleared = 0,   -- 通关波次数
    bestSurvivor = nil, -- 存活最久的舰型（最大 survivedWaves 的舰型）
    -- P2-3: 隐藏成就统计
    shipsLost     = 0,   -- 本场战斗我方损失舰船数
    overkillMax   = 0,   -- 单目标最大过度击杀倍率（dmg / maxHealth）
    focusBossKill = false,-- 是否用集火指令击毁 BOSS
    focusKillCount= 0,   -- 集火击杀数
    chainCount    = 0,   -- P1-3: 连锁反应触发次数
    reinforceWin  = false, -- P2-1: 本场是否全歼增援
}

-- ============================================================================
-- P2-2b: 战斗日志（记录关键事件，最多 30 条）
-- ============================================================================
local BATTLE_LOG_MAX = 30
local battleLog_ = {}        -- { {wave=N, text="..."}, ... }
local fleetName_ = "舰队"   -- 由 Init(opts.fleetName) 传入

--- 添加一条战斗日志（FIFO，超过上限移除最旧条目）
local function logBattleEvent(text)
    battleLog_[#battleLog_ + 1] = { wave = waveNum_, text = text }
    if #battleLog_ > BATTLE_LOG_MAX then
        table.remove(battleLog_, 1)
    end
end

-- ============================================================================
-- 舰船工厂
-- ============================================================================
local function makeShip(stype, x, y, team)
    local cfg = SHIP_TYPES[stype]
    -- S1 HULL_ALLOY / ADVANCED_WEAPONS: 玩家舰队应用科技加成
    local hm = 1.0
    local dm = 1.0
    if team == "player" and rm_ and rm_.baseBonus then
        hm = rm_.baseBonus.shipHealthMult or 1.0
        dm = rm_.baseBonus.shipDmgMult    or 1.0
    end
    -- P1-3 V2.4: 指挥官被动加成（叠加）
    if team == "player" and commanderBonus_ then
        hm = hm * (1.0 + (commanderBonus_.healthMult or 0))
        dm = dm * (1.0 + (commanderBonus_.dmgMult or 0))
    end
    local hp = math.floor(cfg.health * hm)
    local ship = {
        x        = x,      y=y,
        vx       = 0,      vy=0,
        team     = team,
        stype    = stype,
        speed    = cfg.speed,
        health   = hp,
        maxHealth= hp,
        range    = cfg.range,
        dmg      = cfg.dmg * dm,
        color    = cfg.color,
        lastShot = 0,
        -- P1-1 INTERCEPTOR: 超音速穿越 — 玩家拦截舰攻速+30%
        shotRate  = (cfg.shotRate or 1.0) * (team == "player" and stype == "INTERCEPTOR" and INTERCEPTOR_SPD_MULT or 1.0),
        -- P1-1 NOVA_CANNON: 玩家舰队 AOE 半径受科技加成（敌方不受影响）
        aoeRadius = (cfg.aoeRadius or 0) * (team == "player" and (rm_ and rm_.baseBonus and rm_.baseBonus.aoeRadiusMult or 1.0) or 1.0),
        target    = nil,
        attackTarget = nil,
        hitFlash  = 0,   -- 受击闪白强度（1.0=刚受击，0=正常）
        isBoss    = false,  -- 是否为Boss舰
        shield    = 0,      -- 护盾当前值（Boss专用）
        maxShield = 0,      -- 护盾最大值（Boss专用）
        -- P3-2: 单舰 MVP 统计字段
        statDmg   = 0,      -- 本波造成伤害（玩家舰）/ 被谁最后打（用于归属击杀）
        statKills = 0,      -- 本波击杀数（玩家舰）
        lastHitter= nil,    -- 最后一次打我的玩家舰（敌舰专用，用于击杀归属）
        -- P1-1: 被动能力专用字段
        pierceCounter = 0,  -- DESTROYER穿甲弹计数
        isFighter    = false, -- CARRIER临时战斗机标志
        fighterLife  = 0,   -- 战斗机剩余存活时间
        -- P1-1: 改装模块字段
        moduleKey    = nil,  -- 装备的模块key
        moduleEffect = nil,  -- 缓存的 effect 表引用
        burnTargets  = nil,  -- 灼烧目标列表 {target, remaining}
        stealthTimer = 0,    -- 隐匿剩余时间
        pulseCount   = 0,    -- 脉冲过载攻击计数
        -- P1-2 V2.5: 变异词缀字段
        mutantAffixes    = nil,  -- affix key列表 (string[])
        mutantStealthCd  = 0,    -- 隐形词缀冷却计时器
        mutantStealthOn  = 0,    -- 隐形词缀激活计时器
        mutantUnstableCd = 0,    -- 不稳定词缀冷却计时器
        mutantUnstableOn = 0,    -- 不稳定词缀失控计时器
        mutantBerserkActive = false, -- 狂暴是否激活
    }
    -- P1-1: 玩家舰船应用改装模块属性
    if team == "player" and moduleMap_[stype] then
        local mKey = moduleMap_[stype]
        local mDef = SHIP_MODULES[mKey]
        if mDef then
            ship.moduleKey    = mKey
            ship.moduleEffect = mDef.effect
            local eff = mDef.effect
            -- 属性型模块：在创建时直接修改数值
            if eff.type == "hpMult" then
                ship.maxHealth = math.floor(ship.maxHealth * eff.value)
                ship.health    = ship.maxHealth
            elseif eff.type == "shield" then
                ship.shield    = math.floor(ship.maxHealth * eff.value)
                ship.maxShield = ship.shield
            elseif eff.type == "speedMult" then
                ship.speed = ship.speed * eff.value
            elseif eff.type == "shotRateMult" then
                ship.shotRate = ship.shotRate * eff.value
            elseif eff.type == "dmgUp" then
                ship.dmg      = ship.dmg * eff.dmgMult
                ship.shotRate = ship.shotRate * (eff.rateMult or 1.0)
            elseif eff.type == "stealth" then
                ship.stealthTimer = eff.duration
            end
        end
    end
    -- P1-2 V2.5: 玩家舰船应用变异词缀属性
    if team == "player" and mutantMap_[stype] then
        local mutantData = mutantMap_[stype]
        local affixKeys = mutantData.affixes
        if affixKeys and #affixKeys > 0 then
            ship.mutantAffixes = affixKeys
            -- 应用属性型词缀 (fragile/sluggish/overcharge 的数值修改)
            local MutantShip = require("game.MutantShipSystem")
            MutantShip.ApplyAffixStats(ship, affixKeys)
        end
    end
    return ship
end

-- ============================================================================
-- P3-1a: 同步标量状态到 BattleAI
-- ============================================================================
local function syncAIVars()
    BattleAI.SyncVarsIn({
        screenW          = screenW_,
        screenH          = screenH_,
        endlessRound     = endlessRound_,
        isPincerWave     = isPincerWave_,
        currentFormation = currentFormation_,
        waveNum          = waveNum_,
        scoutAuraApplied = scoutAuraApplied_,
        explorerMarkTarget = explorerMarkTarget_,
        engineerHealTimer  = engineerHealTimer_,
        comboCount       = comboCount_,
        battleLog        = battleLog_,
    })
end
