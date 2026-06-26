---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-----------------------------------------------------------------------
-- ClientDataManager.lua — 存档 / 读档 / 生涯战绩 / 跨版本兼容
-- 职责:
--   * saveGame / saveCareer: 序列化到本地文件
--   * restoreGame: 从 json 字符串复原各子系统状态
--   * onGameReady: 检测本地存档并加载 / 新游戏初始化
--   * base-module-effects: 基地模块效果脏标记与重算
--   * level-up / stage-goals: 升级奖励与阶段性目标
--   * evolution-bonus: 传承节点加成聚合
--
-- Host 上下文约定（与 ClientGameLoop.lua 一致）:
--   * Table 直接引用: rm_ bs_ bbs_ rs_ ms_ bm_ spq_ fm_ dda_
--       player_ hiddenStats_ evBonus_ battleStatsCache_
--       careerStats_ endlessCardBonuses_ explorerTasks_
--       lastExpedition_ PLANET_UPGRADE_COSTS DIFFICULTY_CONFIGS
--       GP_ TL customDiff_ pirateAttackInfo_
--       evolutionUnlocked_ EVOLUTION_TREE_ AD_BONUS todayChallenge_
--   * Scalar 读写: 与 ClientGameLoop.lua 相同
--   * 函数回调: saveGame saveCareer softReset markBaseEffectsDirty
--       handleLevelUp applyBaseModuleEffects checkStageGoals
--       showRewardAd getAdCount getRemainingTime getDpr getScreenSize
-----------------------------------------------------------------------
local cjson = require("cjson")
local GalaxyScene = require("game.GalaxyScene")
local GameUI      = require("game.GameUI")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local ClientSave  = require("network.ClientSave")
local ClientGalaxy = require("network.ClientGalaxy")

local M = {}

local H_ = nil

---@param host table
function M.init(host)
    H_ = host
end

local function H() return H_ end

local function accessTbl(key)
    local h = H()
    if not h then return nil end
    return rawget(h, key)
end

---@return table @已解锁节点聚合加成配置表
function M.buildEvolutionBonus()
    local h = H()
    local tree = accessTbl("EVOLUTION_TREE_") or {}
    local unlocked = accessTbl("evolutionUnlocked_") or {}
    local cfg = {}
    for _, node in ipairs(tree) do
        if unlocked[node.id] and type(node.apply) == "function" then
            node.apply(cfg)
        end
    end
    return cfg
end

function M.markBaseEffectsDirty()
    local h = H()
    if not h then return end
    h.baseEffectsDirty_ = true
end

function M.applyBaseModuleEffects()
    local h = H()
    if not h then return end
    if not h.baseEffectsDirty_ then return end
    h.baseEffectsDirty_ = false
    local rm_ = h.rm_
    local fm_ = h.fm_
    local base = GalaxyScene.GetBase()
    local oldEsource = (rm_.baseBonus and rm_.baseBonus.esource) or 0
    local oldEnergy  = (rm_.baseBonus and rm_.baseBonus.energy)  or 0
    rm_.rates.energy  = (rm_.rates.energy  or 0) - oldEnergy
    rm_.rates.esource = (rm_.rates.esource or 0) - oldEsource
    local oldTechPopDelta = (rm_.baseBonus and rm_.baseBonus.techPopRateDelta) or 0
    rm_.rates.population = (rm_.rates.population or 0) - oldTechPopDelta
    local BASE_CAPS = { metal = 99999, esource = 99999, nuclear = 9999, credits = 9999999 }
    for res, cap in pairs(BASE_CAPS) do rm_.caps[res] = cap end
    rm_.caps.minerals = 9999
    rm_.caps.energy   = 9999
    rm_.caps.crystal  = 2000
    rm_.baseBonus = {
        energy = 0, esource = 0,
        defense = 0, shield = 0, shieldBonus = 0, defenseBonus = 0,
        researchMult = 1.0, buildMult = 1.0, shipyardMult = 1.0,
        fleetSpeedMult = 1.0, hasWarpGate = false, hasWarpGatePrime = false,
        warpGatePrimeCooldown = (rm_.baseBonus and rm_.baseBonus.warpGatePrimeCooldown) or 0,
        hasStellarFortress = false, tradeHubLevel = 0,
    }
    if not base or not base.colonized then
        rm_.refineryMult = 0
        return
    end
    local refineryMult = 0
    for _, b in ipairs(base.buildings) do
        local lvl = b.level or 1
        if b.key == "ENERGY_CORE" then
            refineryMult = refineryMult + 0.5 * lvl
        elseif b.key == "SOLAR_ARRAY" then
            rm_.baseBonus.esource = rm_.baseBonus.esource + 3 * lvl
        elseif b.key == "MINERAL_SILO" then
            local mult = 2 ^ lvl
            rm_.caps.minerals = rm_.caps.minerals * mult
            rm_.caps.energy   = rm_.caps.energy   * mult
            rm_.caps.crystal  = rm_.caps.crystal  * mult
        elseif b.key == "MATERIAL_DEPOT" then
            local mult = 2 ^ lvl
            rm_.caps.metal   = rm_.caps.metal   * mult
            rm_.caps.esource = rm_.caps.esource * mult
            rm_.caps.nuclear = rm_.caps.nuclear * mult
        elseif b.key == "REFINERY" then
            refineryMult = 1.0 + 0.5 * (lvl - 1)
        elseif b.key == "COMMAND_CENTER" then
            rm_.baseBonus.defense = rm_.baseBonus.defense + 50 * lvl
        elseif b.key == "BASE_SHIELD" then
            rm_.baseBonus.shield = rm_.baseBonus.shield + 200 * lvl
        elseif b.key == "RESEARCH_CENTER" then
            rm_.baseBonus.researchMult = rm_.baseBonus.researchMult * (1.2 ^ lvl)
        elseif b.key == "BUILD_CENTER" then
            rm_.baseBonus.buildMult = math.max(0.25, rm_.baseBonus.buildMult * (0.75 ^ lvl))
        elseif b.key == "SHIPYARD" then
            rm_.baseBonus.shipyardMult = rm_.baseBonus.shipyardMult * (1.5 ^ lvl)
        elseif b.key == "WARP_GATE" then
            rm_.baseBonus.hasWarpGate = true
            rm_.baseBonus.fleetSpeedMult = rm_.baseBonus.fleetSpeedMult * (2.0 ^ lvl)
        elseif b.key == "PARTICLE_ACCELERATOR" then
            rm_.baseBonus.researchMult = rm_.baseBonus.researchMult * (2.5 ^ lvl)
            rm_.baseBonus.particleAccelRefineMult = (2.5 ^ lvl)
        elseif b.key == "WARP_GATE_PRIME" then
            rm_.baseBonus.hasWarpGatePrime = true
        elseif b.key == "STELLAR_FORTRESS" then
            rm_.baseBonus.hasStellarFortress = true
        elseif b.key == "TRADE_HUB" then
            rm_.baseBonus.tradeHubLevel = rm_.baseBonus.tradeHubLevel + lvl
        end
    end
    local rs_ = h.rs_
    local techBonus = rm_.baseBonus
    if rs_ and rs_.unlocked then
        for id, _ in pairs(rs_.unlocked) do
            local td = TECHS[id]
            if td and td.bonus then
                local b = td.bonus
                if b.fleetSpeedMult then
                    techBonus.fleetSpeedMult = techBonus.fleetSpeedMult * b.fleetSpeedMult
                end
                if b.shieldBonus then
                    techBonus.shieldBonus  = (techBonus.shieldBonus  or 0) + b.shieldBonus
                    techBonus.defenseBonus = (techBonus.defenseBonus or 0) + (b.defenseBonus or 0)
                end
                if b.shipHealthMult then
                    techBonus.shipHealthMult = (techBonus.shipHealthMult or 1.0) * b.shipHealthMult
                end
                if b.shipDmgMult then
                    techBonus.shipDmgMult = (techBonus.shipDmgMult or 1.0) * b.shipDmgMult
                end
                if b.globalRefineMult then
                    techBonus.globalRefineMult = (techBonus.globalRefineMult or 1.0) * b.globalRefineMult
                end
                if b.refineMult == "crystal" then
                    techBonus.crystalRefineMult = (techBonus.crystalRefineMult or 1.0) * (b.val or 1.0)
                end
                if b.colonyPopMult then
                    techBonus.colonyPopMult = (techBonus.colonyPopMult or 1.0) * b.colonyPopMult
                end
                if b.coreUpgradeCostMult then
                    techBonus.coreUpgradeCostMult = (techBonus.coreUpgradeCostMult or 1.0) * b.coreUpgradeCostMult
                end
                if b.researchSpeedMult then
                    techBonus.researchSpeedMult = (techBonus.researchSpeedMult or 1.0) * b.researchSpeedMult
                end
            end
        end
    end
    local popBonus = math.min(3, math.floor((rm_.resources.population or 0) / 100))
    fm_:setMaxFleets(5 + 0 + popBonus)
    local evBonus = h.evBonus_ or {}
    if evBonus._challengeLessFleet then
        local cur = fm_:getMaxFleets()
        fm_:setMaxFleets(math.max(1, cur - 2))
    end
    rm_.rates.esource = (rm_.rates.esource or 0) + rm_.baseBonus.esource
    local coreLevel = (base and base.coreLevel) or 1
    if coreLevel >= 2 then
        local coreRefineMult = 0.3
        refineryMult = math.max(refineryMult, coreRefineMult)
    end
    rm_.refineryMult = refineryMult
    if rm_.baseBonus.particleAccelRefineMult then
        rm_.refineryMult = rm_.refineryMult * 1.5
    end
    if rm_.baseBonus.hasStellarFortress then
        rm_.baseBonus.defense = rm_.baseBonus.defense * 2
    end
    if rm_.baseBonus.esourceMult and rm_.baseBonus.esourceMult > 1.0 then
        rm_.refineryMult = rm_.refineryMult * rm_.baseBonus.esourceMult
    end
    local colPopMult = techBonus.colonyPopMult or 1.0
    if colPopMult ~= 1.0 then
        local baseRate  = rm_.rates.population or 0
        local techDelta = baseRate * (colPopMult - 1.0)
        rm_.rates.population       = baseRate + techDelta
        techBonus.techPopRateDelta = techDelta
    else
        techBonus.techPopRateDelta = 0
    end
    local cbs = accessTbl("endlessCardBonuses_") or {}
    if cbs.shipDmgMult    ~= 0 then rm_.baseBonus.shipDmgMult    = (rm_.baseBonus.shipDmgMult    or 1.0) * (1 + cbs.shipDmgMult)    end
    if cbs.shipHealthMult ~= 0 then rm_.baseBonus.shipHealthMult = (rm_.baseBonus.shipHealthMult or 1.0) * (1 + cbs.shipHealthMult) end
    if cbs.aoeRadiusMult  ~= 0 then rm_.baseBonus.aoeRadiusMult  = (rm_.baseBonus.aoeRadiusMult  or 1.0) * (1 + cbs.aoeRadiusMult)  end
    if cbs.shipyardSpeedMult ~= 0 then rm_.baseBonus.shipyardMult = rm_.baseBonus.shipyardMult * (1 + cbs.shipyardSpeedMult) end
    if cbs.fleetCapBonus ~= 0 then
        local cur = fm_:getMaxFleets() or 5
        fm_:setMaxFleets(cur + cbs.fleetCapBonus)
    end
    if cbs.nuclearCapBonus ~= 0 then
        rm_.caps.nuclear = (rm_.caps.nuclear or 9999) + cbs.nuclearCapBonus
    end
    local streakMult = 1.0
    rm_.baseBonus.cardMiningMult  = (1 + (cbs.miningRateMult  or 0)) * streakMult
    rm_.baseBonus.cardEnergyMult  = (1 + (cbs.energyRateMult  or 0)) * streakMult
    rm_.baseBonus.cardNuclearMult = (1 + (cbs.nuclearRateMult or 0)) * streakMult
    rm_.baseBonus.waveRepairPct   = cbs.waveRepairPct   or 0
    rm_.baseBonus.explorerDurMult = cbs.explorerDurMult or 0
    rm_.baseBonus.intelRateMult   = cbs.intelRateMult   or 0
    if evBonus._challengeSlotMinus1 then rm_.baseBonus.challengeSlotMinus1 = true end
    if evBonus._challengeBestMarket then rm_.baseBonus.challengeBestMarket = true end
    if evBonus._challengeFastBuild then
        rm_.baseBonus.buildMult = rm_.baseBonus.buildMult * (1.0 / 1.5)
    end
    local MegastructureSystem = require("game.MegastructureSystem")
    local megaBonus = MegastructureSystem.CalcBonuses()
    if megaBonus.esourceRate > 0 then
        rm_.baseBonus.energy = rm_.baseBonus.energy + megaBonus.esourceRate
    end
    if megaBonus.researchMult > 0 then
        rm_.baseBonus.researchMult = rm_.baseBonus.researchMult + megaBonus.researchMult
    end
    if megaBonus.fleetSpeedMult > 0 then
        rm_.baseBonus.fleetSpeedMult = rm_.baseBonus.fleetSpeedMult + megaBonus.fleetSpeedMult
    end
    if megaBonus.instantWarp then
        rm_.baseBonus.hasWarpGatePrime = true
    end
    if megaBonus.defense > 0 then
        rm_.baseBonus.defense = rm_.baseBonus.defense + megaBonus.defense
    end
    if megaBonus.shield > 0 then
        rm_.baseBonus.shield = rm_.baseBonus.shield + megaBonus.shield
    end
    if megaBonus.defenseMult > 0 then
        rm_.baseBonus.defenseBonus = (rm_.baseBonus.defenseBonus or 0) + megaBonus.defenseMult
    end
end

---@param leveled boolean
---@param newLevel number
---@param newRank string
---@param rewards table
function M.handleLevelUp(leveled, newLevel, newRank, rewards)
    if not leveled then return end
    local h = H()
    Audio.Play(Audio.SFX.LEVELUP)
    h.rm_:add("metal",   rewards.metal)
    h.rm_:add("esource", rewards.esource)
    h.rm_:add("nuclear", rewards.nuclear)
    local isMilestone = (newLevel % 5 == 0)
    local tag = isMilestone and "里程碑晋升" or "晋升"
    GameUI.Notify(
        tag .. " Lv." .. newLevel .. " [" .. newRank .. "]  奖励: 金属+" ..
        rewards.metal .. " 能源+" .. rewards.esource .. " 核能+" .. rewards.nuclear,
        isMilestone and "success" or "info")
end

function M.checkStageGoals()
    if not STAGE_GOALS then return end
    local h = H()
    local BattleScene = require("game.BattleScene")
    local battleStats = BattleScene and BattleScene.GetStats and BattleScene.GetStats() or {}
    local gameState = {
        profile        = h.player_,
        base           = GalaxyScene.GetBase(),
        rs             = h.rs_,
        rm             = h.rm_,
        totalShipsBuilt    = (accessTbl("GP_") or {}).totalShipsBuilt or 0,
        shipTypeBuilt      = (accessTbl("GP_") or {}).shipTypeBuilt or {},
        totalEnemiesKilled = battleStats.enemiesKilled or 0,
        totalWavesCleared  = battleStats.wavesCleared  or 0,
        endlessRound       = h.endlessRound_ or 0,
        colonizedPlanets   = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {},
        piratesKilled      = h.piratesKilled_ or 0,
    }
    local GP_ = accessTbl("GP_") or {}
    for _, goal in ipairs(STAGE_GOALS) do
        if not (GP_.completedGoals and GP_.completedGoals[goal.id]) then
            local ok, checkResult = pcall(goal.check, gameState)
            if ok and checkResult then
                if not GP_.completedGoals then GP_.completedGoals = {} end
                GP_.completedGoals[goal.id] = true
                local rewardStr = ""
                if goal.reward then
                    local parts = {}
                    for res, amt in pairs(goal.reward) do
                        h.rm_:add(res, amt)
                        local label = RES_LABELS and RES_LABELS[res] or res
                        parts[#parts+1] = label .. "+" .. amt
                    end
                    rewardStr = " 奖励: " .. table.concat(parts, " ")
                end
                GameUI.Notify("✓ 目标达成: " .. goal.title .. rewardStr, "success")
                print("[Goal] 完成: " .. goal.id)
                GameUI.SetCompletedGoals(GP_.completedGoals)
            end
        end
    end
end

---@return table @save data snapshot
function M.buildSaveData()
    local h = H()
    return ClientSave.BuildSaveData({
        rm = h.rm_, rs = h.rs_, player = h.player_, spq = h.spq_, fm = h.fm_,
        pirateAI = h.pirateAI_, ds = h.ds_, bm = h.bm_, GP = accessTbl("GP_"),
        difficulty = h.difficulty_, playerName = h.playerName_,
        totalResearch = h.totalResearch_,
    })
end

---@param slot number|nil @存档槽位（当前单机仅槽 1，保留扩展 API）
function M.saveData(slot)
    local h = H()
    ClientSave.SaveGame({
        rm = h.rm_, rs = h.rs_, player = h.player_, spq = h.spq_, fm = h.fm_,
        pirateAI = h.pirateAI_, ds = h.ds_, bm = h.bm_, GP = accessTbl("GP_"),
        difficulty = h.difficulty_, playerName = h.playerName_,
        totalResearch = h.totalResearch_,
    })
end

function M.saveCareer()
    local h = H()
    ClientSave.SaveCareer({
        careerStats       = accessTbl("careerStats_"),
        evolutionPoints   = h.evolutionPoints_,
        evolutionUnlocked = accessTbl("evolutionUnlocked_"),
        challengeStreak   = h.challengeStreak_,
        lastChallengeDate = h.lastChallengeDate_,
    })
end

---@param jsonStr string
function M.loadData(jsonStr)
    local h = H()
    local restored = ClientSave.RestoreGame(jsonStr, {
        rm = h.rm_, rs = h.rs_, player = h.player_, spq = h.spq_, fm = h.fm_,
        pirateAI = h.pirateAI_, ds = h.ds_, bm = h.bm_, GP = accessTbl("GP_"),
        DIFFICULTY_CONFIGS = accessTbl("DIFFICULTY_CONFIGS"),
        callbacks = {
            markBaseEffectsDirty    = function() M.markBaseEffectsDirty() end,
            applyBaseModuleEffects  = function() M.applyBaseModuleEffects() end,
            reapplyAllPlanetBonuses = function() ClientGalaxy.ReapplyAllPlanetBonuses() end,
        },
    })
    if restored then
        if restored.difficulty       then h.difficulty_       = restored.difficulty end
        if restored.difficultyChosen then h.difficultyChosen_ = restored.difficultyChosen end
        if restored.playerName       then h.playerName_       = restored.playerName end
        if restored.totalResearch    then h.totalResearch_    = restored.totalResearch end
    end
    local MSysRestore = require("game.MutantShipSystem")
    MSysRestore.Init()
    local FERestore = require("game.ui.FormationEditor")
    FERestore.Init()
    local BPRestore = require("game.BlueprintSystem")
    BPRestore.Init()
    return restored ~= nil
end

function M.onGameReady()
    local h = H()
    if h.skipSaveLoad_ then
        h.skipSaveLoad_ = false
        local NemesisSystem = require("game.NemesisSystem")
        NemesisSystem.Init()
        local MutantShip = require("game.MutantShipSystem")
        MutantShip.Init()
        local AnomSys = require("game.AnomalySystem")
        AnomSys.Init()
        local SW = require("game.StarWeather")
        SW.Init()
        local QuestBoard = require("game.QuestBoard")
        QuestBoard.Reset()
        local MegastructureSystem = require("game.MegastructureSystem")
        MegastructureSystem.Reset()
        local Commander = require("game.CommanderSystem")
        Commander.Recruit("academy")
        local starter = Commander.GetAll()[1]
        if starter then Commander.AssignToFleet(starter.id, 1) end
        local GalactopediaSystem = require("game.GalactopediaSystem")
        GalactopediaSystem.Init()
        local FE = require("game.ui.FormationEditor")
        FE.Init()
        local BPNew = require("game.BlueprintSystem")
        BPNew.Init()
        print("[Client] 新游戏：跳过存档加载，宿敌/异象/天气/任务板系统已初始化")
        return
    end
    if fileSystem:FileExists("galaxy_save.json") then
        local file = File("galaxy_save.json", FILE_READ)
        if file:IsOpen() then
            local jsonStr = file:ReadString()
            file:Close()
            M.loadData(jsonStr)
            return
        end
    end
    print("[Client] 无本地存档，新游戏开始")
end

---@return table @统计聚合（生涯战绩 + 当前局关键指标）
function M.getStats()
    local h = H()
    local career = accessTbl("careerStats_") or {}
    local GP_ = accessTbl("GP_") or {}
    return {
        totalGames    = career.totalGames    or 0,
        totalWins     = career.totalWins     or 0,
        bestWave      = career.bestWave      or 0,
        totalKills    = career.totalKills    or 0,
        totalColonies = career.totalColonies or 0,
        bestMvpShip   = career.bestMvpShip   or "",
        playtime      = career.playtime      or 0,
        bestDiff      = career.bestDiff      or "",
        curStreak     = career.curStreak     or 0,
        maxStreak     = career.maxStreak     or 0,
        shipKills     = career.shipKills     or {},
        recentWins    = career.recentWins    or {},
        sessionPlaytime = h.totalPlayTime_   or 0,
        sessionResearch = h.totalResearch_   or 0,
        sessionShipsBuilt = GP_.totalShipsBuilt or 0,
        evolutionPoints = h.evolutionPoints_ or 0,
    }
end

---@return table @玩家当前状态快照
function M.getPlayerState()
    local h = H()
    return {
        name       = h.playerName_ or "指挥官",
        profile    = h.player_ and {
            exp     = h.player_.exp or 0,
            level   = h.player_.level or 1,
            rank    = h.player_.rank or "新兵",
        } or nil,
        difficulty = h.difficulty_,
        scene      = h.currentScene_,
        endless    = h.isEndlessMode_,
        league     = h.leagueMode_,
        playtime   = h.totalPlayTime_ or 0,
        remaining  = (function()
            local TL = accessTbl("TL")
            if not TL then return 0 end
            return math.max(0, (TL.BASE_LIMIT or 7200) + (TL.extraTime or 0) - (TL.playTime or 0))
        end)(),
    }
end

function M.reset()
    local h = H()
    local rm_ = h.rm_
    local diffInitRes = (accessTbl("DIFFICULTY_CONFIGS") or {})[h.difficulty_] and
        accessTbl("DIFFICULTY_CONFIGS")[h.difficulty_].initRes
    if h.difficulty_ == "custom" then
        local cd = accessTbl("customDiff_") or {}
        if cd.initResBonus ~= 0 then
            diffInitRes = {
                metal   = math.floor(cd.initResBonus * 0.50),
                esource = math.floor(cd.initResBonus * 0.35),
                nuclear = math.floor(cd.initResBonus * 0.15),
            }
        end
    end
    if diffInitRes then
        for res, delta in pairs(diffInitRes) do
            rm_.resources[res] = math.max(0, (rm_.resources[res] or 0) + delta)
        end
    end
    local evBonus = M.buildEvolutionBonus()
    h.evBonus_ = evBonus
    if evBonus._eco1 then
        rm_.resources.metal = (rm_.resources.metal or 0) + 200
    end
    if evBonus._eco2 then
        rm_.rates = rm_.rates or {}
        rm_.evolutionEsourceBonus = 0.15
    end
    if evBonus._eco4 then
        rm_._heritageFirstBuildFree = true
    end
    local LegacySystem = require("game.LegacySystem")
    local legacyBonus = LegacySystem.GetBonuses()
    if legacyBonus.resourceBonus > 0 then
        for res, val in pairs(rm_.resources) do
            rm_.resources[res] = math.floor(val * (1 + legacyBonus.resourceBonus))
        end
    end
    if legacyBonus.buildSpeedBonus > 0 then
        rm_._legacyBuildSpeedBonus = legacyBonus.buildSpeedBonus
    end
    if legacyBonus.blackMarketDiscount > 0 then
        rm_._legacyMarketDiscount = legacyBonus.blackMarketDiscount
    end
    if legacyBonus.extraFleets > 0 then
        h.evBonus_._legacyExtraFleets = legacyBonus.extraFleets
    end
    if legacyBonus.extraModSlot > 0 then
        h.evBonus_._legacyExtraModSlot = legacyBonus.extraModSlot
    end
    if legacyBonus.skillCdReduction > 0 then
        h.evBonus_._legacySkillCdReduction = legacyBonus.skillCdReduction
    end
    if legacyBonus.commanderStartLevel > 1 then
        h.evBonus_._legacyCommanderStartLv = legacyBonus.commanderStartLevel
    end
    if legacyBonus.bossDmgBonus > 0 then
        h.evBonus_._legacyBossDmgBonus = legacyBonus.bossDmgBonus
    end
    if legacyBonus.factionFavorBonus > 0 then
        h.evBonus_._legacyFactionFavor = legacyBonus.factionFavorBonus
    end
    if legacyBonus.colonizeSpeedBonus > 0 then
        rm_._legacyColonizeSpeedBonus = legacyBonus.colonizeSpeedBonus
    end
    if legacyBonus.megaPhaseReduction > 0 then
        h.evBonus_._legacyMegaPhaseReduction = legacyBonus.megaPhaseReduction
    end
    h.evBonus_._legacyBonuses = legacyBonus

    h.adBonusApplied_ = false
    if h.adBonusNext_ then
        h.adBonusNext_ = false
        h.adBonusApplied_ = true
        local AD_BONUS = accessTbl("AD_BONUS") or { metal = 300, esource = 150, nuclear = 80 }
        for res, bonus in pairs(AD_BONUS) do
            rm_.resources[res] = (rm_.resources[res] or 0) + bonus
        end
    end
    if h.todayChallenge_ then
        local ch = h.todayChallenge_
        if ch._initBonus then
            for res, delta in pairs(ch._initBonus) do
                rm_.resources[res] = (rm_.resources[res] or 0) + delta
            end
        end
        if ch._noCapital    then h.evBonus_._challengeNoCapital    = true end
        if ch._slotMinus1   then h.evBonus_._challengeSlotMinus1   = true end
        if ch._slowResearch then h.evBonus_._challengeSlowResearch = true end
        if ch._noMarket     then h.evBonus_._challengeNoMarket     = true end
        if ch._lessFleet    then h.evBonus_._challengeLessFleet    = true end
        if ch._bestMarket   then h.evBonus_._challengeBestMarket   = true end
        if ch._fastBuildBoost then h.evBonus_._challengeFastBuild  = true end
        if ch._delayFirstWave then h.evBonus_._challengeDelayWave  = ch._delayFirstWave end
        if ch._freeTier2Tech  then h.evBonus_._challengeFreeTech   = true end
    end
    h.currentScene_ = "galaxy"
    h.selectedPlanet_ = nil
    h.activeFleetId_ = 1
    h.explorerColonizeMode_ = false
    h.refreshTimer_ = 0
    h.lastShownRemaining_ = -1
    h.baseEffectsDirty_ = true
    h.endGameTriggered_ = false
    h.piratesKilled_ = 0
    h.battleStatsCache_ = {}
    h.totalResearch_ = 0
    local GP_ = accessTbl("GP_") or {}
    GP_.totalShipsBuilt = 0
    GP_.resMilestoneTimer = 0
    GP_.resWarnTimer = 0
    GP_.lowResWarnSent = {}
    GP_.prodSampleTimer = 0
    GP_.planetProdHistory = {}
    h.pirateAttackInfo_ = nil
    h.pirateWarnPlayed_ = false
    local TL = accessTbl("TL") or {}
    TL.playTime = 0
    h.totalPlayTime_ = 0
    TL.extraTime = 0
    TL.timeoutTriggered = false
    h.saveTimer_ = 0
    ClientSave.ResetProgress()
    local hidden = accessTbl("hiddenStats_") or {}
    hidden.totalShipsLostCampaign = 0
    hidden.focusKills = 0
    hidden.focusBossKill = false
    hidden.totalCardsChosen = 0
    hidden.totalExplored = 0
    hidden.exploreTypesFound = {}
    local dda_ = accessTbl("dda_") or {}
    dda_.recentResults = {}
    dda_.evalTimer = 0
    dda_.adjustCount = 0
    if GalaxyScene.ClearGarrisons then GalaxyScene.ClearGarrisons() end
    h.isEndlessMode_ = false
    h.endlessRound_ = 0
    local cbs = accessTbl("endlessCardBonuses_") or {}
    for k in pairs(cbs) do cbs[k] = 0 end
    GameUI.SetEndlessRound(0)
    local ext = accessTbl("explorerTasks_") or {}
    for k in pairs(ext) do ext[k] = nil end
    h.explorerTaskSeq_ = 0
    GameUI.RefreshExplorerTasks({})
    h.difficultyChosen_ = false
    h.mainMenuActive_ = true
    h.mainMenuHover_ = nil
    h.hasSave_ = fileSystem:FileExists("galaxy_save.json")
    h.dailyChallengeMode_ = false
    h.todayChallenge_ = nil
    h.leagueMode_ = false
    GameUI.SetLeagueHud(nil)
    h.campaignMode_ = false
    h.campaignFirstColonize_ = false
    h.campaignVictoryPending_ = false
    h.campaignResetTimer_ = 0
    local Campaign = require("game.CampaignSystem")
    Campaign.Abort()
end

return M
