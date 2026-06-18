--- BattleAI.lua
--- 战斗 AI 逻辑模块：工厂函数、波次生成、阵型应用、战斗循环（玩家/敌方/死亡/被动）
--- 从 BattleScene.lua 提取，通过 BattleState (BS) 共享状态。
--- BattleScene 调用前同步 BS，BattleAI 读写 BS 中的表引用（原地修改），
--- 标量变化通过返回值告知 BattleScene 回写。

local BS = require("game.battle.BattleState")
local Audio = require("game.AudioManager")
local BattleSkills = require("game.BattleSkills")
local Systems = require("game.Systems")
local SHIP_TYPES = Systems.SHIP_TYPES
local NemesisSystem = require("game.NemesisSystem")
local BattleReplaySystem = require("game.BattleReplaySystem")
local Commander = require("game.CommanderSystem")
local FormationEditor = require("game.ui.FormationEditor")
local BattleUtils = require("game.battle.BattleUtils")

local BattleAI = {}

-- ============================================================================
-- 常量
-- ============================================================================
local BOSS_WAVE_INTERVAL    = 5
local CHAIN_RADIUS          = 80
local CHAIN_AOE_PCT         = 0.20
local CHAIN_MIN_KILLS       = 3
local ENGINEER_HEAL_INTERVAL= 30.0
local ENGINEER_HEAL_AMOUNT  = 10
local CARRIER_FIGHTER_LIFE  = 5.0
local DESTROYER_PIERCE_COUNT= 5
local INTERCEPTOR_SPD_MULT  = 1.30
local FRIGATE_SHARE_RATIO   = 0.20
local BATTLECRUISER_BLOCK   = 0.10
local COMBO_RESET_TIME      = 5.0
local BOSS_BANNER_DUR       = 2.5
local MILESTONE_BANNER_DUR  = 4.0

local BATTLE_ENVIRONMENTS = {
    NONE     = { enemyRangeMult = 1.0, shieldAbsorb = 1.0, asteroidDamage = 0, particleType = "none" },
    NEBULA   = { enemyRangeMult = 0.75, shieldAbsorb = 1.0, asteroidDamage = 0, particleType = "nebula" },
    ASTEROID = { enemyRangeMult = 1.0, shieldAbsorb = 1.0, asteroidDamage = 12, asteroidInterval = 2.0, particleType = "asteroid" },
    MAGSTOR  = { enemyRangeMult = 1.0, shieldAbsorb = 0.60, asteroidDamage = 0, particleType = "magstor" },
}
local ENV_POOL = { "NONE", "NONE", "NEBULA", "ASTEROID", "MAGSTOR" }

-- ============================================================================
-- 模块内部引用（由 Init 注入）
-- ============================================================================
local makeShip_         -- 工厂函数引用（BattleScene 提供）
local playerFleet_      -- table 引用（BattleScene 的 playerFleet_）
local enemyFleet_       -- table 引用
local projectiles_      -- table 引用
local floatTexts_       -- table 引用
local explParticles_    -- table 引用
local hitSparks_        -- table 引用
local shockRings_       -- table 引用
local fwParticles_      -- table 引用
local SK_               -- table 引用 (screen shake)
local RF_               -- table 引用 (reinforcement)
local battleStats_      -- table 引用
local FORMATION_CONFIG  -- table 引用
local COMBO_LEVELS      -- table 引用
local rm_               -- table 引用 (研究管理器 baseBonus)
local SHIP_TYPES_ = SHIP_TYPES  -- table 引用 (舰船类型配置表，默认取模块级 Systems.SHIP_TYPES)

-- 标量状态（每帧从 BattleScene 同步进来，修改后回写）
local vars_ = {}

-- ============================================================================
-- Init: 接收 BattleScene 传入的所有表引用和可变标量
-- ============================================================================
---@param refs table 包含所有表引用
function BattleAI.Init(refs)
    makeShip_        = refs.makeShip
    playerFleet_     = refs.playerFleet
    enemyFleet_      = refs.enemyFleet
    projectiles_     = refs.projectiles
    floatTexts_      = refs.floatTexts
    explParticles_   = refs.explParticles
    hitSparks_       = refs.hitSparks
    shockRings_      = refs.shockRings
    fwParticles_     = refs.fwParticles
    SK_              = refs.SK
    RF_              = refs.RF
    battleStats_     = refs.battleStats
    FORMATION_CONFIG = refs.FORMATION_CONFIG
    COMBO_LEVELS     = refs.COMBO_LEVELS
    rm_              = refs.rm
    SHIP_TYPES_      = refs.SHIP_TYPES
end

--- 轻量级刷新表引用（Reset/StartNextWave 后调用）
---@param refs table 包含需更新的表引用
function BattleAI.SyncRefs(refs)
    if refs.playerFleet  then playerFleet_  = refs.playerFleet  end
    if refs.enemyFleet   then enemyFleet_   = refs.enemyFleet   end
    if refs.projectiles  then projectiles_  = refs.projectiles  end
    if refs.floatTexts   then floatTexts_   = refs.floatTexts   end
    if refs.explParticles then explParticles_ = refs.explParticles end
    if refs.hitSparks    then hitSparks_    = refs.hitSparks    end
    if refs.shockRings   then shockRings_   = refs.shockRings   end
    if refs.fwParticles  then fwParticles_  = refs.fwParticles  end
end

--- 每帧同步标量状态（BattleScene → BattleAI）
---@param v table 标量表
function BattleAI.SyncVarsIn(v)
    vars_ = v
end

--- 返回 BattleAI 修改后的标量（BattleAI → BattleScene）
---@return table
function BattleAI.GetVarsOut()
    return vars_
end

-- ============================================================================
-- 辅助函数
-- ============================================================================
local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        if skipStealth and s.stealthTimer and s.stealthTimer > 0 then
            -- skip
        else
            local d = dist2(ship.x, ship.y, s.x, s.y)
            if d < bd then best = s; bd = d end
        end
    end
    return best, bd
end

local function getComboLevel()
    for _, lv in ipairs(COMBO_LEVELS) do
        if vars_.comboCount >= lv.min then return lv end
    end
    return nil
end

local function logBattleEvent(text)
    if vars_.battleLog then
        vars_.battleLog[#vars_.battleLog + 1] = {
            turn = vars_.waveNum or 1,
            time = os.clock(),
            text = text,
        }
        -- 限制最大条目
        if #vars_.battleLog > 200 then
            table.remove(vars_.battleLog, 1)
        end
    end
end

--- 生成爆炸粒子 + 屏幕震动
local function spawnExplosion(ship)
    local st = ship.stype
    local isBig = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
    local count = isBig and 22 or 10
    local speed = isBig and 90 or 50
    local life = isBig and 0.7 or 0.45
    -- 核心白闪
    explParticles_[#explParticles_ + 1] = {
        x = ship.x, y = ship.y, vx = 0, vy = 0,
        life = 0.18, maxLife = 0.18,
        r = 255, g = 255, b = 255,
        size = isBig and 22 or 12, ptype = "flash"
    }
    -- 碎片（根据队伍选择颜色）
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.3 + math.random() * 0.9)
        local r, g, b
        if ship.team == "player" then
            r, g, b = 80 + math.random(60), 160 + math.random(60), 255  -- 蓝色系（玩家）
        else
            r, g, b = 255, 80 + math.random(80), math.random(40)  -- 红色系（敌人）
        end
        explParticles_[#explParticles_ + 1] = {
            x = ship.x + (math.random() - 0.5) * 6,
            y = ship.y + (math.random() - 0.5) * 6,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
            life = life * (0.5 + math.random() * 0.6),
            maxLife = life,
            r = r, g = g, b = b,
            size = 2 + math.random() * (isBig and 4 or 2),
        }
    end
    -- 屏幕震动
    local str = isBig and 6.0 or 2.5
    local dur = isBig and 0.28 or 0.14
    if str > SK_.strength or SK_.timer <= 0 then
        SK_.strength = str
        SK_.dur = dur
        SK_.timer = dur
    end
end

--- 生成击中火花
local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local speed = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r, g, b = 100 + math.random(80), 200 + math.random(55), 255
    else
        r, g, b = 255, 120 + math.random(80), math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.4 + math.random() * 0.8)
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random() - 0.5) * 4,
            y = y + (math.random() - 0.5) * 4,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
            life = 0.18 + math.random() * 0.14,
            maxLife = 0.32,
            r = r, g = g, b = b,
        }
    end
end

--- 生成冲击波光环
local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y,
        radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur,
        r = r, g = g, b = b,
        width = math.max(1.5, maxR * 0.08),
    }
end

-- ============================================================================
-- 工厂函数
-- ============================================================================

--- 创建 Boss 舰船
function BattleAI.MakeBossShip(baseType, x, y)
    local ship = makeShip_(baseType, x, y, "enemy")
    ship.isBoss = true
    local isMilestoneBoss = (vars_.endlessRound > 0) and (vars_.endlessRound % 10 == 0)
    ship.isMilestoneBoss = isMilestoneBoss
    if isMilestoneBoss then
        ship.health = ship.maxHealth * 5
        ship.maxHealth = ship.maxHealth * 5
        ship.dmg = ship.dmg * 2
        ship.speed = ship.speed * 0.65
        ship.scale = 1.8
        ship.color = { 220, 30, 30 }
        ship.glowColor = { 255, 0, 0 }
    else
        ship.health = ship.maxHealth * 4
        ship.maxHealth = ship.maxHealth * 4
        ship.dmg = ship.dmg * 2
        ship.speed = ship.speed * 0.8
        ship.color = { 255, 200, 50 }
    end
    local shieldVal = math.floor(ship.maxHealth * 0.5)
    ship.shield = shieldVal
    ship.maxShield = shieldVal
    return ship
end

--- 创建宿敌舰船
function BattleAI.MakeNemesisShip(captainId, baseType, x, y, evoConfig)
    local ship = makeShip_(baseType, x, y, "enemy")
    ship.isBoss = true
    ship.isNemesis = true
    ship.nemesisCaptain = captainId
    local hpM = evoConfig.hpMult or 1.0
    local dmgM = evoConfig.dmgMult or 1.0
    ship.health = math.floor(ship.maxHealth * hpM * 3.5)
    ship.maxHealth = ship.health
    ship.dmg = math.floor(ship.dmg * dmgM * 1.8)
    ship.speed = ship.speed * 0.75
    local shieldVal = math.floor(ship.maxHealth * 0.4)
    ship.shield = shieldVal
    ship.maxShield = shieldVal
    local capInfo = NemesisSystem.GetActiveCaptain()
    if capInfo then
        ship.color = capInfo.color
        ship.glowColor = capInfo.color
    end
    ship.scale = 1.5
    return ship
end

--- 构建宿敌波次（与 BattleScene 原始逻辑完全一致）
function BattleAI.BuildNemesisWave(captainId)
    local fleet = {}
    local capInfo = NemesisSystem.GetActiveCaptain()
    if not capInfo then return fleet end

    local screenW = vars_.screenW
    local screenH = vars_.screenH
    local evoConfig = NemesisSystem.GetEvolutionConfig(capInfo.level)
    local fleetTypes = NemesisSystem.BuildNemesisFleet(captainId, screenW, screenH)

    -- 生成普通随从舰船（应用进化加成）
    for i, stype in ipairs(fleetTypes) do
        local x = screenW - 60 - math.random() * 80
        local y = screenH * 0.1 + math.random() * screenH * 0.8
        local ship = makeShip_(stype, x, y, "enemy")
        -- 随从也享受进化HP/DMG加成（减半）
        local followerHpM  = 1.0 + (evoConfig.hpMult - 1.0) * 0.5
        local followerDmgM = 1.0 + (evoConfig.dmgMult - 1.0) * 0.5
        ship.health    = math.floor(ship.maxHealth * followerHpM)
        ship.maxHealth = ship.health
        ship.dmg       = math.floor(ship.dmg * followerDmgM)
        ship.isNemesisFollower = true
        -- 随从使用船长色调（偏暗）
        if capInfo.color then
            ship.color = {
                math.floor(capInfo.color[1] * 0.6),
                math.floor(capInfo.color[2] * 0.6),
                math.floor(capInfo.color[3] * 0.6),
            }
        end
        fleet[#fleet + 1] = ship
    end

    -- 生成宿敌旗舰（放在舰队最后，位于右侧中央）
    local flagX = screenW - 40
    local flagY = screenH * 0.5
    local flagType = capInfo.id == "VIKTOR" and "BATTLECRUISER"
        or capInfo.id == "SELINA" and "INTERCEPTOR" or "CARRIER"
    local flagship = BattleAI.MakeNemesisShip(captainId, flagType, flagX, flagY, evoConfig)
    fleet[#fleet + 1] = flagship

    return fleet
end

-- ============================================================================
-- 波次生成
-- ============================================================================

--- 构建敌方波次（与 BattleScene 完全一致的概率表 + 夹击逻辑）
function BattleAI.BuildEnemyWave(wave)
    local screenW = vars_.screenW
    local screenH = vars_.screenH
    local fleet = {}
    local battleH = screenH - 88

    -- 基础敌舰数 = 2 + wave，上限随波次提高
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
    for i = 1, count do
        local stype
        local roll = math.random()
        if wave <= 1 then
            stype = roll < 0.7 and "SCOUT" or "FRIGATE"
        elseif wave <= 3 then
            stype = roll < 0.4 and "SCOUT" or (roll < 0.8 and "FRIGATE" or "DESTROYER")
        elseif wave <= 5 then
            stype = roll < 0.2 and "SCOUT" or (roll < 0.6 and "FRIGATE" or "DESTROYER")
        elseif wave <= 9 then
            if roll < 0.15 then
                stype = "BATTLECRUISER"
            elseif roll < 0.40 then
                stype = "INTERCEPTOR"
            elseif roll < 0.70 then
                stype = "DESTROYER"
            else
                stype = "FRIGATE"
            end
        else
            if roll < 0.10 then
                stype = "BATTLECRUISER"
            elseif roll < 0.45 then
                stype = "INTERCEPTOR"
            elseif roll < 0.65 then
                stype = "DESTROYER"
            else
                stype = "FRIGATE"
            end
        end
        -- 夹击模式：上下两个入口交替分配
        local x = screenW - 100 - math.random() * 100
        local y
        if vars_.isPincerWave then
            local topZone    = battleH * 0.30
            local bottomBase = battleH * 0.70
            if i % 2 == 1 then
                y = 88 + math.random() * topZone
            else
                y = 88 + bottomBase + math.random() * (battleH - bottomBase)
            end
        else
            y = 88 + battleH * 0.05 + math.random() * battleH * 0.9
        end
        fleet[#fleet + 1] = makeShip_(stype, x, y, "enemy")
    end
    -- 波次 8+（非Boss波）：额外添加 1 艘敌方战列舰
    if wave >= 8 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        local x = screenW - 60 - math.random() * 40
        local y = 88 + battleH * 0.3 + math.random() * battleH * 0.4
        fleet[#fleet + 1] = makeShip_("BATTLECRUISER", x, y, "enemy")
    end
    -- 波次 10+（非Boss波）：额外派遣 1 艘敌方母舰压阵
    if wave >= 10 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        local x = screenW - 50 - math.random() * 30
        local y = 88 + battleH * 0.35 + math.random() * battleH * 0.3
        fleet[#fleet + 1] = makeShip_("CARRIER", x, y, "enemy")
    end
    -- Boss波次：生成强化旗舰 Boss
    if wave % BOSS_WAVE_INTERVAL == 0 then
        local bossType = wave >= 10 and "CARRIER" or "BATTLECRUISER"
        local bx = screenW - 60 - math.random() * 30
        local by = 88 + battleH * 0.4 + math.random() * battleH * 0.2
        fleet[#fleet + 1] = BattleAI.MakeBossShip(bossType, bx, by)
    end
    return fleet
end

--- 获取下一波预览信息（纯预测，无随机，返回下一波的舰型组成）
--- @return { total:number, groups:table[], isBossWave:boolean }
function BattleAI.GetNextWavePreview(wave)
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
    -- 各舰型期望比例（与 BuildEnemyWave 概率一致）
    local distrib
    if wave <= 1 then
        distrib = { {s="SCOUT",prob=0.70},{s="FRIGATE",prob=0.30} }
    elseif wave <= 3 then
        distrib = { {s="SCOUT",prob=0.40},{s="FRIGATE",prob=0.40},{s="DESTROYER",prob=0.20} }
    elseif wave <= 5 then
        distrib = { {s="SCOUT",prob=0.20},{s="FRIGATE",prob=0.20},{s="DESTROYER",prob=0.60} }
    elseif wave <= 9 then
        distrib = { {s="BATTLECRUISER",prob=0.15},{s="INTERCEPTOR",prob=0.25},{s="DESTROYER",prob=0.30},{s="FRIGATE",prob=0.30} }
    else
        distrib = { {s="BATTLECRUISER",prob=0.10},{s="INTERCEPTOR",prob=0.35},{s="DESTROYER",prob=0.20},{s="FRIGATE",prob=0.35} }
    end
    local groups = {}
    for _, d in ipairs(distrib) do
        local est = math.max(1, math.floor(count * d.prob + 0.5))
        local cfg = SHIP_TYPES_[d.s]
        groups[#groups + 1] = { stype = d.s, name = (cfg and cfg.name or d.s), count = est }
    end
    -- Boss波预告
    if wave % BOSS_WAVE_INTERVAL == 0 then
        local bossType = wave >= 10 and "CARRIER" or "BATTLECRUISER"
        local bossName = bossType == "CARRIER" and "旗舰BOSS·母舰" or "旗舰BOSS·战列"
        groups[#groups + 1] = { stype = bossType, name = bossName, count = 1, isBoss = true }
    elseif wave >= 8 then
        groups[#groups + 1] = { stype = "BATTLECRUISER", name = "旗舰", count = 1, isBoss = true }
    end
    if wave >= 10 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        groups[#groups + 1] = { stype = "CARRIER", name = "母舰", count = 1, isBoss = true }
    end
    return { total = count, groups = groups, isBossWave = (wave % BOSS_WAVE_INTERVAL == 0) }
end

-- ============================================================================
-- 被动与阵型
-- ============================================================================

--- 应用波次开始被动技能（与 BattleScene 完全一致）
function BattleAI.ApplyWaveStartPassives()
    local screenW = vars_.screenW
    local screenH = vars_.screenH

    -- === SCOUT: 先敌洞察 — 施加敌方全体攻击力-10% ===
    vars_.scoutAuraApplied = false
    local hasScout = false
    for _, ps in ipairs(playerFleet_) do
        if ps.stype == "SCOUT" then hasScout = true; break end
    end
    if hasScout and #enemyFleet_ > 0 then
        vars_.scoutAuraApplied = true
        for _, es in ipairs(enemyFleet_) do
            es.dmg = math.max(1, math.floor(es.dmg * 0.90))
        end
        floatTexts_[#floatTexts_ + 1] = {
            x = screenW * 0.55, y = screenH * 0.30,
            text = "侦察压制！敌方攻击-10%",
            life = 2.0, maxLife = 2.0, vy = -14, team = "passive_scout"
        }
        print("[P1-1 SCOUT] 先敌洞察施加，敌方攻击力-10%")
    end

    -- === EXPLORER: 图绘先行 — 标记敌方HP最高目标 ===
    vars_.explorerMarkTarget = nil
    local hasExplorer = false
    for _, ps in ipairs(playerFleet_) do
        if ps.stype == "EXPLORER" then hasExplorer = true; break end
    end
    if hasExplorer and #enemyFleet_ > 0 then
        local best, bestHP = nil, -1
        for _, es in ipairs(enemyFleet_) do
            if es.health > bestHP then best = es; bestHP = es.health end
        end
        vars_.explorerMarkTarget = best
        floatTexts_[#floatTexts_ + 1] = {
            x = best.x, y = best.y - 30,
            text = "\xF0\x9F\x8E\xAF集火目标",
            life = 2.0, maxLife = 2.0, vy = -16, team = "passive_explorer"
        }
        print("[P1-1 EXPLORER] 图绘先行标记敌方最高HP目标")
    end

    -- === CARRIER: 舰载机群 — 生成2架临时战斗机 ===
    local hasCarrier = false
    for _, ps in ipairs(playerFleet_) do
        if ps.stype == "CARRIER" then hasCarrier = true; break end
    end
    if hasCarrier then
        local midY = (screenH + 88) / 2
        for k = 1, 2 do
            local fx  = 80 + math.random() * 40
            local fy  = midY + (k == 1 and -35 or 35) + math.random(-10, 10)
            local fighter = makeShip_("SCOUT", fx, fy, "player")
            fighter.dmg       = math.floor(fighter.dmg * 1.8)
            fighter.health    = math.floor(fighter.maxHealth * 0.4)
            fighter.maxHealth = fighter.health
            fighter.isFighter = true
            fighter.fighterLife = CARRIER_FIGHTER_LIFE
            playerFleet_[#playerFleet_ + 1] = fighter
        end
        floatTexts_[#floatTexts_ + 1] = {
            x = screenW * 0.2, y = screenH * 0.28,
            text = "舰载机出击！",
            life = 1.8, maxLife = 1.8, vy = -16, team = "passive_carrier"
        }
        print("[P1-1 CARRIER] 舰载机群：生成2架临时战斗机")
    end

    -- === ENGINEER: 战场维修 — 重置回复计时 ===
    vars_.engineerHealTimer = 0

    -- === 改装模块 — allyDmgAura（同编队友军+伤害）===
    local auraMult = 0
    for _, ps in ipairs(playerFleet_) do
        if ps.moduleEffect and ps.moduleEffect.type == "allyDmgAura" then
            auraMult = auraMult + ps.moduleEffect.value
        end
    end
    if auraMult > 0 then
        for _, ps in ipairs(playerFleet_) do
            ps.dmg = math.floor(ps.dmg * (1.0 + auraMult))
        end
        floatTexts_[#floatTexts_ + 1] = {
            x = screenW * 0.2, y = screenH * 0.35,
            text = string.format("改装增幅！全队攻击+%d%%", math.floor(auraMult * 100)),
            life = 2.0, maxLife = 2.0, vy = -14, team = "passive_module"
        }
    end
end

--- 应用阵型位置和属性（与 BattleScene 完全一致）
function BattleAI.ApplyFormationPositions(fleet)
    local formation = vars_.currentFormation or "wedge"
    local fc = FORMATION_CONFIG[formation]
    if not fc then return end

    local screenW = vars_.screenW
    local screenH = vars_.screenH
    local midY = (screenH + 88) / 2
    local count = #fleet
    if count == 0 then return end

    if formation == "circle" then
        -- 圆环阵型：围成一圈（椭圆稍扁）
        local cx = fc.posX + 20
        local cy = midY
        local radius = math.min(120, 30 + count * 8)
        for i, ship in ipairs(fleet) do
            local angle = (i - 1) / count * math.pi * 2 - math.pi / 2
            ship.x = cx + math.cos(angle) * radius
            ship.y = cy + math.sin(angle) * radius * 0.7
            ship.y = math.max(92, math.min(screenH - 12, ship.y))
        end
    elseif formation == "wedge" then
        -- 锋矢阵型：V字形，领头舰在最前
        local tipX = fc.posX + fc.posXSpread
        for i, ship in ipairs(fleet) do
            local row = math.floor((i - 1) / 2)
            local side = ((i - 1) % 2 == 0) and 1 or -1
            if i == 1 then
                ship.x = tipX
                ship.y = midY
            else
                ship.x = tipX - row * 22 - 15
                ship.y = midY + side * (row + 1) * 28
            end
            ship.y = math.max(92, math.min(screenH - 12, ship.y))
        end
        -- 标记前排/后排（前半为前排）
        local half = math.ceil(count / 2)
        for i, ship in ipairs(fleet) do
            ship.isFrontRow = (i <= half)
        end
    elseif formation == "scatter" then
        -- 散兵阵型：大范围分散
        for i, ship in ipairs(fleet) do
            local t = count > 1 and (i - 1) / (count - 1) or 0.5
            ship.x = fc.posX + math.random(-fc.posXSpread, fc.posXSpread)
            ship.y = midY + fc.posYBase + (t - 0.5) * fc.posYSpread * 2
            ship.y = math.max(92, math.min(screenH - 12, ship.y))
        end
    elseif formation == "custom" then
        -- 自定义阵型：从阵型编辑器读取网格坐标
        local slotData = FormationEditor.GetFirstSavedSlot()
        if slotData and #slotData > 0 then
            for i, ship in ipairs(fleet) do
                local cell = slotData[((i - 1) % #slotData) + 1]
                local px, py = FormationEditor.GridToPixel(cell.r, cell.c, screenW, screenH)
                local dupIdx = math.floor((i - 1) / #slotData)
                ship.x = px + dupIdx * 12
                ship.y = py + dupIdx * 8
                ship.y = math.max(92, math.min(screenH - 12, ship.y))
            end
        else
            -- 无保存数据时回退到冲锋阵排列
            for i, ship in ipairs(fleet) do
                local t = count > 1 and (i - 1) / (count - 1) or 0.5
                ship.x = fc.posX + math.random(-fc.posXSpread, fc.posXSpread)
                ship.y = midY + fc.posYBase + (t - 0.5) * fc.posYSpread * 2
                ship.y = math.max(92, math.min(screenH - 12, ship.y))
            end
        end
    else
        -- 冲锋阵型（默认）：紧凑向前
        for i, ship in ipairs(fleet) do
            local t = count > 1 and (i - 1) / (count - 1) or 0.5
            ship.x = fc.posX + math.random(-fc.posXSpread, fc.posXSpread)
            ship.y = midY + fc.posYBase + (t - 0.5) * fc.posYSpread * 2
            ship.y = math.max(92, math.min(screenH - 12, ship.y))
        end
    end

    -- 叠加属性倍率（基于 SHIP_TYPES + rm_ 基础值，避免多次叠加）
    for _, ship in ipairs(fleet) do
        local cfg = SHIP_TYPES_[ship.stype]
        if not cfg then goto continue end
        local hm = (rm_ and rm_.baseBonus and rm_.baseBonus.shipHealthMult) or 1.0
        local dm = (rm_ and rm_.baseBonus and rm_.baseBonus.shipDmgMult)    or 1.0
        local baseHP  = math.floor(cfg.health * hm)
        local baseDMG = cfg.dmg * dm
        local baseSpd = cfg.speed
        local baseShotRate = cfg.shotRate or 1.0

        ship.speed    = baseSpd * fc.speedMult
        ship.dmg      = baseDMG * fc.dmgMult
        ship.shotRate = baseShotRate * fc.shotRateMult
        -- 锋矢阵：前排攻击+20%
        if formation == "wedge" and ship.isFrontRow then
            ship.dmg = ship.dmg * 1.20
        end
        -- 血量：先按 healthMult 调整最大值，再按比例折算当前血量
        local newMax = math.floor(baseHP * fc.healthMult)
        local ratio  = ship.maxHealth > 0 and (ship.health / ship.maxHealth) or 1.0
        ship.maxHealth = newMax
        ship.health    = math.max(1, math.floor(newMax * ratio))
        ::continue::
    end
end

-- ============================================================================
-- 战斗循环：玩家舰队更新
-- ============================================================================
function BattleAI.UpdatePlayerFleet(dt)
    local phaseMult = BattleSkills.IsActive(5) and (2.5 * BattleSkills.GetEffectMult(5)) or 1.0
    local screenW = vars_.screenW
    local screenH = vars_.screenH

    for _, ship in ipairs(playerFleet_) do
        -- 模块效果：隐匿计时
        if ship.stealthTimer and ship.stealthTimer > 0 then
            ship.stealthTimer = ship.stealthTimer - dt
        end
        -- 模块效果：紧急维修（血量 <20% 时触发一次）
        if ship.modules and ship.modules.emergencyHeal and not ship.emergencyUsed then
            if ship.health < ship.maxHealth * 0.2 then
                ship.health = math.min(ship.maxHealth, ship.health + math.floor(ship.maxHealth * 0.3))
                ship.emergencyUsed = true
                ship.hitFlash = -0.5
                floatTexts_[#floatTexts_ + 1] = {
                    x = ship.x, y = ship.y - 20,
                    text = "紧急维修!", life = 1.2, maxLife = 1.2, vy = -25, team = "heal"
                }
            end
        end

        -- 变异词缀运行时效果
        if ship.affixes then
            -- regen: 每秒回复 1% maxHP
            if ship.affixes.regen then
                ship.health = math.min(ship.maxHealth, ship.health + ship.maxHealth * 0.01 * dt)
            end
            -- overcharge: 每秒消耗 0.5% HP，换取额外伤害（在射击时已 ×1.5）
            if ship.affixes.overcharge then
                ship.health = ship.health - ship.maxHealth * 0.005 * dt
                if ship.health < 1 then ship.health = 1 end
            end
            -- berserk: 血量 <30% 时伤害×2
            -- (应用在射击段)
            -- stealth: 3s 隐匿 / 20s 循环
            if ship.affixes.stealth then
                ship.stealthCycle = (ship.stealthCycle or 0) + dt
                if ship.stealthCycle >= 20.0 then
                    ship.stealthCycle = 0
                    ship.stealthTimer = 3.0
                end
            end
            -- unstable: 2s 锁定 / 30s 循环（锁定期间不能射击）
            if ship.affixes.unstable then
                ship.unstableCycle = (ship.unstableCycle or 0) + dt
                if ship.unstableCycle >= 30.0 then
                    ship.unstableCycle = 0
                    ship.unstableLock = 2.0
                end
                if ship.unstableLock and ship.unstableLock > 0 then
                    ship.unstableLock = ship.unstableLock - dt
                end
            end
        end

        -- 燃烧 DOT 处理
        if ship.burnTimer and ship.burnTimer > 0 then
            ship.burnTimer = ship.burnTimer - dt
            ship.burnTick = (ship.burnTick or 0) + dt
            if ship.burnTick >= 0.5 then
                ship.burnTick = 0
                local burnDmg = ship.burnDmg or 5
                ship.health = ship.health - burnDmg
                battleStats_.dmgDealt = battleStats_.dmgDealt + burnDmg
                BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.DMG, {
                    src = "burn", tgt = ship.stype, dmg = burnDmg
                })
            end
        end

        -- 移动
        if ship.target then
            local tx, ty = ship.target.x, ship.target.y
            local range = ship.range or 180
            local d = dist2(ship.x, ship.y, tx, ty)
            if d > range then
                local dx, dy = tx - ship.x, ty - ship.y
                local len = math.max(0.001, d)
                local moveSpd = ship.speed * phaseMult
                ship.x = ship.x + (dx / len) * moveSpd * dt
                ship.y = ship.y + (dy / len) * moveSpd * dt
            end
        elseif vars_.moveTarget then
            -- 移向指定目标点
            local tx, ty = vars_.moveTarget.x, vars_.moveTarget.y
            local d = dist2(ship.x, ship.y, tx, ty)
            if d > 15 then
                local dx, dy = tx - ship.x, ty - ship.y
                local len = math.max(0.001, d)
                local moveSpd = ship.speed * phaseMult
                ship.x = ship.x + (dx / len) * moveSpd * dt
                ship.y = ship.y + (dy / len) * moveSpd * dt
            end
        end
        -- 限制在屏幕内
        ship.x = clamp(ship.x, 20, screenW - 20)
        ship.y = clamp(ship.y, 100, screenH - 20)

        -- 寻找目标
        if vars_.focusTarget and vars_.focusTarget.health and vars_.focusTarget.health > 0 then
            ship.target = vars_.focusTarget
        else
            ship.target = findNearest(ship, enemyFleet_, false)
        end

        -- 射击
        if ship.target and ship.target.health > 0 then
            local d = dist2(ship.x, ship.y, ship.target.x, ship.target.y)
            local range = ship.range or 180
            if d <= range then
                ship.lastShot = (ship.lastShot or 0) + dt
                -- unstable 锁定检查
                local locked = ship.unstableLock and ship.unstableLock > 0
                if not locked and ship.lastShot >= (1.0 / ship.shotRate) then
                    ship.lastShot = 0
                    local target = ship.target
                    local dmg = ship.dmg

                    -- 集火倍率
                    local focusMult = 1.0
                    if vars_.focusTarget == target then focusMult = 1.3 end

                    -- 指挥官加成
                    local cmdMult = 1.0
                    if vars_.cmdSkillActive and vars_.cmdSkillDef then
                        cmdMult = vars_.cmdSkillDef.dmgMult or 1.0
                    end

                    -- 先发制人（首次攻击 +50%）
                    local firstStrike = 1.0
                    if not ship.hasAttacked then
                        ship.hasAttacked = true
                        firstStrike = 1.5
                    end

                    -- EXPLORER 标记加成 (+30%)
                    local markMult = 1.0
                    if target.marked then markMult = 1.3 end

                    -- Berserk 变异 (血量 <30% 时 ×2)
                    local berserkMult = 1.0
                    if ship.affixes and ship.affixes.berserk and ship.health < ship.maxHealth * 0.3 then
                        berserkMult = 2.0
                    end

                    -- 最终伤害
                    dmg = math.floor(dmg * focusMult * cmdMult * firstStrike * markMult * berserkMult)

                    -- DESTROYER 穿甲弹（每 DESTROYER_PIERCE_COUNT 次射击）
                    local isPierce = false
                    if ship.stype == "DESTROYER" then
                        ship.shotCount = (ship.shotCount or 0) + 1
                        if ship.shotCount % DESTROYER_PIERCE_COUNT == 0 then
                            isPierce = true
                        end
                    end

                    -- pulseOverload 模块
                    if ship.modules and ship.modules.pulseOverload then
                        ship.pulseCount = (ship.pulseCount or 0) + 1
                        if ship.pulseCount % 4 == 0 then
                            isPierce = true
                        end
                    end

                    -- 应用伤害
                    local actualDmg = dmg
                    if target.shield and target.shield > 0 and not isPierce then
                        local absorbed = math.min(target.shield, dmg)
                        target.shield = target.shield - absorbed
                        actualDmg = dmg - absorbed
                    end
                    target.health = target.health - actualDmg
                    target.hitFlash = 1.0
                    battleStats_.dmgDealt = battleStats_.dmgDealt + dmg

                    -- shock 变异溅射（30% 伤害，半径 40）
                    if ship.affixes and ship.affixes.shock then
                        local splashDmg = math.floor(dmg * 0.3)
                        for _, es in ipairs(enemyFleet_) do
                            if es ~= target then
                                local sd = dist2(target.x, target.y, es.x, es.y)
                                if sd <= 40 then
                                    es.health = es.health - splashDmg
                                    es.hitFlash = 0.5
                                end
                            end
                        end
                    end

                    -- 特效
                    spawnHitSparks(target.x, target.y, dmg, "enemy")
                    if dmg >= 30 then
                        spawnShockRing(target.x, target.y, 25, 0.3, 100, 200, 255)
                    end

                    -- BATTLECRUISER AOE
                    if ship.stype == "BATTLECRUISER" and ship.aoeRadius then
                        local aoeDmg = math.floor(dmg * 0.5)
                        for _, es in ipairs(enemyFleet_) do
                            if es ~= target then
                                local ad = dist2(target.x, target.y, es.x, es.y)
                                if ad <= ship.aoeRadius then
                                    es.health = es.health - aoeDmg
                                    es.hitFlash = 0.6
                                end
                            end
                        end
                    end

                    -- 投射物
                    projectiles_[#projectiles_ + 1] = {
                        x = ship.x, y = ship.y,
                        tx = target.x, ty = target.y,
                        life = 0.15, team = "player"
                    }

                    -- 音效（节流）
                    if vars_.shootSfxTimer <= 0 then
                        if ship.stype == "CARRIER" then
                            Audio.Play(Audio.SFX.CARRIER_BARRAGE)
                        elseif ship.stype == "DESTROYER" or ship.stype == "BATTLECRUISER" then
                            Audio.Play(Audio.SFX.MISSILE_LAUNCH)
                        else
                            Audio.Play(Audio.SFX.LASER_FIRE)
                        end
                        vars_.shootSfxTimer = 0.08
                    end

                    -- 飘字
                    local isCrit = (dmg >= target.maxHealth * 0.30)
                    floatTexts_[#floatTexts_ + 1] = {
                        x = target.x + (math.random() - 0.5) * 16,
                        y = target.y - 15,
                        text = tostring(dmg) .. (isCrit and "!" or ""),
                        life = 0.9, maxLife = 0.9, vy = -30,
                        team = isCrit and "crit" or "player"
                    }
                    if isPierce then
                        floatTexts_[#floatTexts_ + 1] = {
                            x = target.x, y = target.y - 30,
                            text = "穿甲!", life = 0.7, maxLife = 0.7, vy = -22, team = "pierce"
                        }
                    end

                    -- 回放
                    BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.DMG, {
                        src = ship.stype, tgt = target.stype, dmg = dmg,
                        pierce = isPierce, crit = isCrit
                    })
                end
            end
        end
    end
end

-- ============================================================================
-- 战斗循环：敌方舰队更新
-- ============================================================================
function BattleAI.UpdateEnemyFleet(dt)
    local screenW = vars_.screenW
    local screenH = vars_.screenH
    local currentEnv = vars_.currentEnv or BATTLE_ENVIRONMENTS.NONE
    local envEnemyRangeMult = currentEnv.enemyRangeMult or 1.0
    local formation = vars_.currentFormation or "wedge"

    for _, ship in ipairs(enemyFleet_) do
        ship.age = (ship.age or 0) + dt
        -- slow/mark 计时
        if ship.slowTimer and ship.slowTimer > 0 then ship.slowTimer = ship.slowTimer - dt end
        if ship.markTimer and ship.markTimer > 0 then
            ship.markTimer = ship.markTimer - dt
            if ship.markTimer <= 0 then ship.marked = false end
        end

        -- 寻找目标（跳过隐匿的玩家舰）
        local target, tDist = findNearest(ship, playerFleet_, true)
        ship.target = target
        if not target then goto continue_enemy end

        -- 移动（受 EMP / slow 影响）
        local moveSpd = ship.speed
        if ship.slowTimer and ship.slowTimer > 0 then moveSpd = moveSpd * 0.5 end
        if ship.empTimer and ship.empTimer > 0 then
            ship.empTimer = ship.empTimer - dt
            moveSpd = 0
        end

        local range = (ship.range or 150) * envEnemyRangeMult
        if tDist > range and moveSpd > 0 then
            local dx, dy = target.x - ship.x, target.y - ship.y
            local len = math.max(0.001, tDist)
            ship.x = ship.x + (dx / len) * moveSpd * dt
            ship.y = ship.y + (dy / len) * moveSpd * dt
        end

        -- 屏幕边界
        ship.x = clamp(ship.x, 20, screenW - 20)
        ship.y = clamp(ship.y, 100, screenH - 20)

        -- 护盾技能
        local shieldMult = 1.0
        if ship.shieldSkill and ship.age >= (ship.shieldSkill.cd or 999) then
            ship.shieldSkill.active = true
            shieldMult = 0.5  -- 受到 50% 伤害
        end
        -- 无敌技能
        if ship.invulnSkill and ship.age >= (ship.invulnSkill.cd or 999) then
            if not ship.invulnUsed then
                ship.invulnUsed = true
                ship.invulnTimer = ship.invulnSkill.dur or 2.0
            end
        end
        if ship.invulnTimer and ship.invulnTimer > 0 then
            ship.invulnTimer = ship.invulnTimer - dt
            shieldMult = 0
        end

        -- 射击
        if tDist <= range then
            ship.lastShot = (ship.lastShot or 0) + dt
            if ship.lastShot >= (1.0 / ship.shotRate) then
                ship.lastShot = 0
                local dmg = ship.dmg
                -- 联赛攻击力修正
                dmg = math.floor(dmg * (vars_.leagueAttackMult or 1.0))

                -- Guardian 词缀：半径 80 内的 Boss 为附近敌舰减伤 15%
                local guardianReduction = 1.0
                for _, ally in ipairs(enemyFleet_) do
                    if ally ~= ship and ally.affixes and ally.affixes.guardian then
                        if dist2(ship.x, ship.y, ally.x, ally.y) <= 80 then
                            guardianReduction = 0.85
                            goto guardian_applied
                        end
                    end
                end
                ::guardian_applied::

                -- BATTLECRUISER 格挡（10% 减伤）
                local blockReduction = 1.0
                if formation == "wedge" or formation == "charge" then
                    for _, ps in ipairs(playerFleet_) do
                        if ps.stype == "BATTLECRUISER" then
                            blockReduction = 1.0 - BATTLECRUISER_BLOCK
                            break
                        end
                    end
                end

                -- 楔形阵后排闪避（30%）
                local dodged = false
                if formation == "wedge" then
                    -- 攻击目标的索引 > count/2 视为后排
                    for idx, ps in ipairs(playerFleet_) do
                        if ps == target and idx > #playerFleet_ / 2 then
                            if math.random() < 0.30 then
                                dodged = true
                                floatTexts_[#floatTexts_ + 1] = {
                                    x = target.x, y = target.y - 18,
                                    text = "闪避!", life = 0.7, maxLife = 0.7,
                                    vy = -26, team = "dodge"
                                }
                            end
                            break
                        end
                    end
                end

                if dodged then goto skip_enemy_hit end

                -- 最终伤害（对玩家）
                local finalDmg = math.floor(dmg * guardianReduction * blockReduction)

                -- CIRCLE 阵伤害分摊
                if formation == "circle" and #playerFleet_ > 1 then
                    local shareDmg = math.floor(finalDmg / #playerFleet_)
                    for _, ps in ipairs(playerFleet_) do
                        ps.health = ps.health - shareDmg
                        ps.hitFlash = 0.6
                    end
                    battleStats_.dmgTaken = battleStats_.dmgTaken + finalDmg
                else
                    -- FRIGATE 合作防御（20% 分担，HP>50% 的护卫舰帮忙扛）
                    local frigateShare = 0
                    if formation ~= "scatter" then
                        for _, ps in ipairs(playerFleet_) do
                            if ps ~= target and ps.stype == "FRIGATE"
                               and ps.health > ps.maxHealth * 0.5 then
                                frigateShare = math.floor(finalDmg * FRIGATE_SHARE_RATIO)
                                ps.health = ps.health - frigateShare
                                ps.hitFlash = 0.4
                                break
                            end
                        end
                    end
                    local actualToTarget = finalDmg - frigateShare
                    -- 护盾吸收
                    if target.shield and target.shield > 0 then
                        local absorbed = math.min(target.shield, actualToTarget)
                        target.shield = target.shield - absorbed
                        actualToTarget = actualToTarget - absorbed
                    end
                    target.health = target.health - actualToTarget
                    target.hitFlash = 1.0
                    battleStats_.dmgTaken = battleStats_.dmgTaken + finalDmg
                end

                -- 反射模块
                if target.modules and target.modules.reflect then
                    if math.random() < 0.20 then
                        local reflectDmg = math.floor(finalDmg * 0.4)
                        ship.health = ship.health - reflectDmg
                        ship.hitFlash = 0.8
                        floatTexts_[#floatTexts_ + 1] = {
                            x = ship.x, y = ship.y - 15,
                            text = "反射!" .. reflectDmg, life = 0.8, maxLife = 0.8,
                            vy = -22, team = "reflect"
                        }
                    end
                end

                -- AOE（scatter 阵减 AOE）
                if ship.aoeRadius then
                    local aoeMult = 1.0
                    if formation == "scatter" then aoeMult = (ship.aoeDmgMult or 0.5) end
                    local aoeDmg = math.floor(dmg * 0.4 * aoeMult)
                    for _, ps in ipairs(playerFleet_) do
                        if ps ~= target then
                            local ad = dist2(target.x, target.y, ps.x, ps.y)
                            if ad <= ship.aoeRadius then
                                ps.health = ps.health - aoeDmg
                                ps.hitFlash = 0.5
                            end
                        end
                    end
                end

                -- 投射物
                projectiles_[#projectiles_ + 1] = {
                    x = ship.x, y = ship.y,
                    tx = target.x, ty = target.y,
                    life = 0.15, team = "enemy"
                }

                -- 飘字
                floatTexts_[#floatTexts_ + 1] = {
                    x = target.x + (math.random() - 0.5) * 12,
                    y = target.y - 12,
                    text = tostring(finalDmg),
                    life = 0.8, maxLife = 0.8, vy = -25, team = "enemy"
                }

                ::skip_enemy_hit::
            end
        end

        ::continue_enemy::
    end
end

-- ============================================================================
-- 战斗循环：死亡处理
-- ============================================================================

--- 处理玩家和敌方死亡，返回修改后标量
function BattleAI.ProcessDeaths(dt)
    local screenW = vars_.screenW
    local screenH = vars_.screenH

    -- === 玩家舰队死亡 ===
    for i = #playerFleet_, 1, -1 do
        local ship = playerFleet_[i]
        if ship.health <= 0 then
            Audio.Play(Audio.SFX.EXPLOSION_SMALL)
            spawnExplosion(ship)
            vars_.waveShipsLost = vars_.waveShipsLost + 1
            battleStats_.shipsLost = battleStats_.shipsLost + 1
            -- 回放
            BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.SHIP_LOST, {
                stype = ship.stype, wave = vars_.waveNum
            })
            -- 战斗日志
            logBattleEvent((SHIP_TYPES_[ship.stype] and SHIP_TYPES_[ship.stype].name or ship.stype) .. " 被击毁")
            -- fission 变异：分裂为 2 个小型克隆
            if ship.affixes and ship.affixes.fission and not ship.isFissionClone then
                for ci = 1, 2 do
                    local clone = makeShip_(ship.stype, ship.x + (ci == 1 and -15 or 15), ship.y, "player")
                    clone.health = math.floor(ship.maxHealth * 0.4)
                    clone.maxHealth = clone.health
                    clone.dmg = math.floor(ship.dmg * 0.4)
                    clone.speed = ship.speed * 1.2
                    clone.scale = 0.6
                    clone.isFighter = true
                    clone.fighterLife = 8.0
                    clone.isFissionClone = true
                    playerFleet_[#playerFleet_ + 1] = clone
                end
                floatTexts_[#floatTexts_ + 1] = {
                    x = ship.x, y = ship.y - 20,
                    text = "裂变!", life = 1.0, maxLife = 1.0, vy = -28, team = "fission"
                }
            end
            table.remove(playerFleet_, i)
        end
    end

    -- === 敌方舰队死亡 ===
    local frameDeadPositions = {}
    for i = #enemyFleet_, 1, -1 do
        local ship = enemyFleet_[i]
        if ship.health <= 0 then
            frameDeadPositions[#frameDeadPositions + 1] = { x = ship.x, y = ship.y }
            -- 音效
            if ship.isBoss then
                Audio.Play(Audio.SFX.EXPLOSION_LARGE)
            else
                Audio.Play(Audio.SFX.EXPLOSION_SMALL)
            end
            spawnExplosion(ship)
            battleStats_.enemiesKilled = battleStats_.enemiesKilled + 1
            vars_.waveKills = vars_.waveKills + 1
            vars_.waveKillTotal = vars_.waveKillTotal + 1

            -- 回放
            if ship.isBoss then
                BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.BOSS_KILL, {
                    stype = ship.stype, wave = vars_.waveNum
                })
            else
                BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.KILL, {
                    stype = ship.stype
                })
            end

            -- Overkill 统计
            local overkill = math.abs(ship.health)
            if overkill > battleStats_.overkillMax then
                battleStats_.overkillMax = overkill
            end

            -- 集火击杀追踪
            if vars_.focusTarget == ship then
                vars_.focusTarget = nil
                battleStats_.focusKillCount = battleStats_.focusKillCount + 1
                if ship.isBoss then battleStats_.focusBossKill = true end
            end

            -- lastHitter 统计
            if ship.lastHitter then
                ship.lastHitter.statKills = (ship.lastHitter.statKills or 0) + 1
                -- killHeal 模块：击杀回复 8% maxHP
                if ship.lastHitter.modules and ship.lastHitter.modules.killHeal then
                    local heal = math.floor(ship.lastHitter.maxHealth * 0.08)
                    ship.lastHitter.health = math.min(ship.lastHitter.maxHealth, ship.lastHitter.health + heal)
                end
                -- vampiric 词缀：击杀回复 5% maxHP
                if ship.lastHitter.affixes and ship.lastHitter.affixes.vampiric then
                    local heal = math.floor(ship.lastHitter.maxHealth * 0.05)
                    ship.lastHitter.health = math.min(ship.lastHitter.maxHealth, ship.lastHitter.health + heal)
                end
            end

            -- 连击系统
            vars_.comboCount = vars_.comboCount + 1
            vars_.comboTimer = 0
            vars_.comboDisplayTimer = 2.0
            if vars_.comboCount > vars_.waveMaxCombo then
                vars_.waveMaxCombo = vars_.comboCount
            end
            if vars_.comboCount > battleStats_.maxCombo then
                battleStats_.maxCombo = vars_.comboCount
            end
            -- 回放 + 日志（在里程碑连击时）
            if vars_.comboCount == 5 or vars_.comboCount == 10 or vars_.comboCount == 20 then
                BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.COMBO, {
                    count = vars_.comboCount
                })
                logBattleEvent(string.format("连击 ×%d!", vars_.comboCount))
            end
            -- 连击飘字
            local cl = getComboLevel()
            if cl then
                floatTexts_[#floatTexts_ + 1] = {
                    x = ship.x, y = ship.y - 35,
                    text = cl.label .. " ×" .. vars_.comboCount,
                    life = 1.2, maxLife = 1.2, vy = -20, team = "combo"
                }
            end

            -- Boss 击败处理
            if ship.isBoss then
                -- 额外爆炸
                for _ = 1, 5 do
                    local bx = ship.x + (math.random() - 0.5) * 40
                    local by = ship.y + (math.random() - 0.5) * 40
                    local fakeShip = { x = bx, y = by, stype = "DESTROYER" }
                    spawnExplosion(fakeShip)
                end
                -- 强屏幕震动
                SK_.strength = 10
                SK_.dur = 0.5
                SK_.timer = 0.5
                -- 日志
                logBattleEvent("⚔️ BOSS " .. (SHIP_TYPES_[ship.stype] and SHIP_TYPES_[ship.stype].name or ship.stype) .. " 击败！")
                -- 全屏闪光
                vars_.bossFlashAlpha = 220
                vars_.bossFlashTimer = BOSS_BANNER_DUR
                -- 里程碑 Boss 特效
                if ship.isMilestoneBoss then
                    vars_.milestoneRound = vars_.endlessRound
                    vars_.milestoneFlashAlpha = 255
                    vars_.milestoneBannerTimer = MILESTONE_BANNER_DUR
                    -- 彩色烟花
                    local colors = {
                        { 255, 80, 80 }, { 255, 200, 50 }, { 80, 255, 120 },
                        { 80, 180, 255 }, { 255, 100, 255 }, { 255, 255, 100 },
                    }
                    for ci = 1, 6 do
                        local cx = screenW * (0.15 + 0.14 * ci)
                        local cy = screenH * (0.25 + math.random() * 0.35)
                        local col = colors[((ci - 1) % #colors) + 1]
                        for _ = 1, 18 do
                            local angle = math.random() * math.pi * 2
                            local spd = 90 + math.random() * 80
                            fwParticles_[#fwParticles_ + 1] = {
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
                    -- 里程碑奖励
                    local nucBonus = 150 + vars_.endlessRound * 30
                    local crystalBonus = 80 + vars_.endlessRound * 15
                    local metalBonus = 100 + vars_.endlessRound * 20
                    if vars_.rm then
                        vars_.rm:add("nuclear", nucBonus)
                        vars_.rm:add("crystal", crystalBonus)
                        vars_.rm:add("metal", metalBonus)
                    end
                    if vars_.notifyFn then
                        vars_.notifyFn(string.format(
                            "里程碑通关！第%d层  核能+%d  水晶+%d  金属+%d",
                            vars_.endlessRound, nucBonus, crystalBonus, metalBonus), "success")
                    end
                else
                    -- 普通 Boss 奖励
                    local nucBonus = 80 + vars_.waveNum * 20
                    local crystalBonus = 30 + vars_.waveNum * 10
                    if vars_.rm then
                        vars_.rm:add("nuclear", nucBonus)
                        vars_.rm:add("crystal", crystalBonus)
                    end
                    if vars_.notifyFn then
                        vars_.notifyFn(string.format("BOSS已击败！核能+%d  水晶+%d", nucBonus, crystalBonus), "success")
                    end
                end
                -- 胜利音效
                Audio.PlayBGM(Audio.BGM.VICTORY_FANFARE, 0.8, false)
                Audio.ResetBGMPitch()
            end

            -- 增援舰击杀追踪
            if ship.isReinforce and RF_.spawned and not RF_.defeated then
                RF_.remain = RF_.remain - 1
                if RF_.remain <= 0 then
                    RF_.defeated = true
                    battleStats_.reinforceWin = true
                    local bonus = math.max(5, math.floor(vars_.waveNum * 8 * 0.30))
                    if vars_.rm then vars_.rm:add("credits", bonus) end
                    floatTexts_[#floatTexts_ + 1] = {
                        x = screenW * 0.5, y = screenH * 0.42,
                        text = string.format("逆境奋战！+%d 星币", bonus),
                        life = 2.2, maxLife = 2.2, vy = -18, team = "reinforce_bonus"
                    }
                    if vars_.notifyFn then
                        vars_.notifyFn(string.format("全歼增援！逆境奖励 +%d 星币", bonus), "success")
                    end
                end
            end

            -- INTERCEPTOR 超音速穿越
            if ship.lastHitter and ship.lastHitter.stype == "INTERCEPTOR" and math.random() < 0.20 then
                ship.lastHitter.lastShot = 1.0 / ship.lastHitter.shotRate
                floatTexts_[#floatTexts_ + 1] = {
                    x = ship.lastHitter.x, y = ship.lastHitter.y - 18,
                    text = "超音速！", life = 0.8, maxLife = 0.8, vy = -26, team = "intercept"
                }
            end

            -- EXPLORER 标记清除
            if vars_.explorerMarkTarget == ship then
                vars_.explorerMarkTarget = nil
            end

            table.remove(enemyFleet_, i)
        end
    end

    -- === 连锁反应 ===
    if #frameDeadPositions >= CHAIN_MIN_KILLS then
        for _, survivor in ipairs(enemyFleet_) do
            for _, dp in ipairs(frameDeadPositions) do
                local dx = survivor.x - dp.x
                local dy = survivor.y - dp.y
                if dx * dx + dy * dy <= CHAIN_RADIUS * CHAIN_RADIUS then
                    local aoe = math.floor((survivor.maxHealth or 50) * CHAIN_AOE_PCT)
                    survivor.health = survivor.health - aoe
                    floatTexts_[#floatTexts_ + 1] = {
                        x = survivor.x + math.random(-8, 8),
                        y = survivor.y - 20,
                        text = tostring(aoe),
                        life = 0.9, maxLife = 0.9, vy = -20, team = "chain_dmg"
                    }
                    break
                end
            end
        end
        vars_.chainCount = (vars_.chainCount or 0) + 1
        battleStats_.chainCount = (battleStats_.chainCount or 0) + 1
        BattleReplaySystem.RecordEvent(BattleReplaySystem.EVENT.CHAIN, {
            count = #frameDeadPositions, chainTotal = battleStats_.chainCount,
        })
        -- 质心飘字
        local cx, cy = 0, 0
        for _, dp in ipairs(frameDeadPositions) do cx = cx + dp.x; cy = cy + dp.y end
        cx = cx / #frameDeadPositions
        cy = cy / #frameDeadPositions
        floatTexts_[#floatTexts_ + 1] = {
            x = cx, y = cy - 45,
            text = string.format("CHAIN ×%d", #frameDeadPositions),
            life = 1.6, maxLife = 1.6, vy = -28, team = "chain"
        }
        -- 冲击波
        for _, dp in ipairs(frameDeadPositions) do
            spawnShockRing(dp.x, dp.y, CHAIN_RADIUS, 0.5, 255, 160, 40)
        end
        -- 屏幕震动
        if 5 > SK_.strength or SK_.timer <= 0 then
            SK_.strength = 5; SK_.dur = 0.3; SK_.timer = 0.3
        end
    end
end

-- ============================================================================
-- 战斗循环：被动更新（ENGINEER治疗、CARRIER战斗机、连击衰减）
-- ============================================================================
function BattleAI.UpdatePassives(dt)
    -- 连击计时器
    if vars_.comboCount > 0 then
        vars_.comboTimer = vars_.comboTimer + dt
        if vars_.comboTimer >= COMBO_RESET_TIME then
            vars_.comboCount = 0
            vars_.comboTimer = 0
        end
    end
    if vars_.comboDisplayTimer > 0 then
        vars_.comboDisplayTimer = vars_.comboDisplayTimer - dt
    end

    -- ENGINEER 治疗
    local hasEngineer = false
    for _, ps in ipairs(playerFleet_) do
        if ps.stype == "ENGINEER" then hasEngineer = true; break end
    end
    if hasEngineer and #playerFleet_ > 0 then
        vars_.engineerHealTimer = vars_.engineerHealTimer + dt
        if vars_.engineerHealTimer >= ENGINEER_HEAL_INTERVAL then
            vars_.engineerHealTimer = 0
            local weakest, minHP = nil, math.huge
            for _, ps in ipairs(playerFleet_) do
                if ps.health < minHP then weakest = ps; minHP = ps.health end
            end
            if weakest and weakest.health < weakest.maxHealth then
                local formation = vars_.currentFormation or "wedge"
                local healMult = (FORMATION_CONFIG[formation] or {}).engineerHealMult or 1.0
                local healAmt = math.floor(ENGINEER_HEAL_AMOUNT * healMult)
                weakest.health = math.min(weakest.maxHealth, weakest.health + healAmt)
                weakest.hitFlash = -0.5
                floatTexts_[#floatTexts_ + 1] = {
                    x = weakest.x, y = weakest.y - 18,
                    text = "+" .. healAmt .. (healMult > 1.0 and "" or ""),
                    life = 1.0, maxLife = 1.0, vy = -28, team = "heal"
                }
            end
        end
    end

    -- CARRIER 战斗机过期
    for i = #playerFleet_, 1, -1 do
        local ps = playerFleet_[i]
        if ps.isFighter then
            ps.fighterLife = ps.fighterLife - dt
            if ps.fighterLife <= 0 then
                spawnExplosion(ps)
                table.remove(playerFleet_, i)
            end
        end
    end
end

-- ============================================================================
-- 导出常量（供 BattleScene 引用，避免重复定义）
-- ============================================================================
BattleAI.BOSS_WAVE_INTERVAL    = BOSS_WAVE_INTERVAL
BattleAI.BATTLE_ENVIRONMENTS   = BATTLE_ENVIRONMENTS
BattleAI.ENV_POOL              = ENV_POOL
BattleAI.CARRIER_FIGHTER_LIFE  = CARRIER_FIGHTER_LIFE
BattleAI.ENGINEER_HEAL_INTERVAL = ENGINEER_HEAL_INTERVAL
BattleAI.COMBO_RESET_TIME      = COMBO_RESET_TIME
BattleAI.BOSS_BANNER_DUR       = BOSS_BANNER_DUR
BattleAI.MILESTONE_BANNER_DUR  = MILESTONE_BANNER_DUR

return BattleAI
