------------------------------------------------------------
-- battle/BattleAIWaveGen.lua
-- 波次生成：工厂函数 / 敌舰生成 / 宿敌波次 / 波次预览
------------------------------------------------------------

local BattleAIWaveGen = {}
local NemesisSystem = require("game.NemesisSystem")

local BOSS_WAVE_INTERVAL = 5

local makeShip_
local playerFleet_
local enemyFleet_
local floatTexts_
local SHIP_TYPES_
local vars_

--- 初始化：接收共享表引用
function BattleAIWaveGen.Init(refs)
    makeShip_    = refs.makeShip
    playerFleet_ = refs.playerFleet
    enemyFleet_  = refs.enemyFleet
    floatTexts_  = refs.floatTexts
    SHIP_TYPES_  = refs.SHIP_TYPES
end

function BattleAIWaveGen.SyncVarsIn(v)
    vars_ = v
end

function BattleAIWaveGen.GetVarsOut()
    return vars_
end

--- 创建 Boss 舰船
function BattleAIWaveGen.MakeBossShip(baseType, x, y)
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
function BattleAIWaveGen.MakeNemesisShip(captainId, baseType, x, y, evoConfig)
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

--- 构建宿敌波次
function BattleAIWaveGen.BuildNemesisWave(captainId)
    local fleet = {}
    local capInfo = NemesisSystem.GetActiveCaptain()
    if not capInfo then return fleet end

    local screenW = vars_.screenW
    local screenH = vars_.screenH
    local evoConfig = NemesisSystem.GetEvolutionConfig(capInfo.level)
    local fleetTypes = NemesisSystem.BuildNemesisFleet(captainId, screenW, screenH)

    for i, stype in ipairs(fleetTypes) do
        local x = screenW - 60 - math.random() * 80
        local y = screenH * 0.1 + math.random() * screenH * 0.8
        local ship = makeShip_(stype, x, y, "enemy")
        local followerHpM  = 1.0 + (evoConfig.hpMult - 1.0) * 0.5
        local followerDmgM = 1.0 + (evoConfig.dmgMult - 1.0) * 0.5
        ship.health    = math.floor(ship.maxHealth * followerHpM)
        ship.maxHealth = ship.health
        ship.dmg       = math.floor(ship.dmg * followerDmgM)
        ship.isNemesisFollower = true
        if capInfo.color then
            ship.color = {
                math.floor(capInfo.color[1] * 0.6),
                math.floor(capInfo.color[2] * 0.6),
                math.floor(capInfo.color[3] * 0.6),
            }
        end
        fleet[#fleet + 1] = ship
    end

    local flagX = screenW - 40
    local flagY = screenH * 0.5
    local flagType = capInfo.id == "VIKTOR" and "BATTLECRUISER"
        or capInfo.id == "SELINA" and "INTERCEPTOR" or "CARRIER"
    local flagship = BattleAIWaveGen.MakeNemesisShip(captainId, flagType, flagX, flagY, evoConfig)
    fleet[#fleet + 1] = flagship

    return fleet
end

--- 构建敌方波次
function BattleAIWaveGen.BuildEnemyWave(wave)
    local screenW = vars_.screenW
    local screenH = vars_.screenH
    local fleet = {}
    local battleH = screenH - 88

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
            if roll < 0.15 then stype = "BATTLECRUISER"
            elseif roll < 0.40 then stype = "INTERCEPTOR"
            elseif roll < 0.70 then stype = "DESTROYER"
            else stype = "FRIGATE" end
        else
            if roll < 0.10 then stype = "BATTLECRUISER"
            elseif roll < 0.45 then stype = "INTERCEPTOR"
            elseif roll < 0.65 then stype = "DESTROYER"
            else stype = "FRIGATE" end
        end
        local x = screenW - 100 - math.random() * 100
        local y
        if vars_.isPincerWave then
            local topZone = battleH * 0.30
            local bottomBase = battleH * 0.70
            if i % 2 == 1 then y = 88 + math.random() * topZone
            else y = 88 + bottomBase + math.random() * (battleH - bottomBase) end
        else
            y = 88 + battleH * 0.05 + math.random() * battleH * 0.9
        end
        fleet[#fleet + 1] = makeShip_(stype, x, y, "enemy")
    end
    if wave >= 8 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        local x = screenW - 60 - math.random() * 40
        local y = 88 + battleH * 0.3 + math.random() * battleH * 0.4
        fleet[#fleet + 1] = makeShip_("BATTLECRUISER", x, y, "enemy")
    end
    if wave >= 10 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        local x = screenW - 50 - math.random() * 30
        local y = 88 + battleH * 0.35 + math.random() * battleH * 0.3
        fleet[#fleet + 1] = makeShip_("CARRIER", x, y, "enemy")
    end
    if wave % BOSS_WAVE_INTERVAL == 0 then
        local bossType = wave >= 10 and "CARRIER" or "BATTLECRUISER"
        local bx = screenW - 60 - math.random() * 30
        local by = 88 + battleH * 0.4 + math.random() * battleH * 0.2
        fleet[#fleet + 1] = BattleAIWaveGen.MakeBossShip(bossType, bx, by)
    end
    return fleet
end

--- 获取下一波预览信息
function BattleAIWaveGen.GetNextWavePreview(wave)
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
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

return BattleAIWaveGen
