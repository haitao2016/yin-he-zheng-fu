-- ============================================================================
-- network/ClientSave.lua  -- 游戏存档 / 读档逻辑
-- 负责：BuildSaveData, SaveGame, SaveCareer, RestoreGame
-- 不负责：状态变量声明（仍在 Client.lua），softReset 调用 ResetProgress() 重置锁
-- ============================================================================
local ClientSave = {}

local GalaxyScene         = require("game.GalaxyScene")
local GameUI              = require("game.GameUI")
local Achievement         = require("game.AchievementSystem")
local GalaxyEvents        = require("game.GalaxyEvents")
local NemesisSystem       = require("game.NemesisSystem")
local MegastructureSystem = require("game.MegastructureSystem")
local Campaign            = require("game.CampaignSystem")
local Commander           = require("game.CommanderSystem")
local QuestBoard          = require("game.QuestBoard")
local FormationEditor     = require("game.ui.FormationEditor")
local ModuleRegistry      = require("game.ModuleRegistry")

-- 防止重复提交的模块级锁（softReset 时调用 ResetProgress() 清除）
local saveInProgress_ = false

-- ============================================================================
-- BuildSaveData
-- 序列化当前游戏状态为 JSON 字符串
-- state = { rm, rs, player, spq, fm, pirateAI, ds, bm, GP,
--           difficulty, playerName, totalResearch }
-- ============================================================================
function ClientSave.BuildSaveData(state)
    local galaxyData = GalaxyScene.GetSaveData()
    local saveData = {
        version   = 1,
        difficulty = state.difficulty,                    -- 保存当前难度，继续游戏时恢复
        resources = state.rm:serialize().resources,
        research  = state.rs:serialize(),
        player    = state.player:serialize(),
        shipQueue = state.spq:serialize(),
        fleet     = state.fm:serialize(),
        planets   = galaxyData.planets,
        base      = galaxyData.base,
        galaxySeed  = galaxyData.seed,   -- P1-1: 星系种子码
        galaxyShape = galaxyData.shape,  -- P1-1: 星系形态
        pirate       = state.pirateAI and state.pirateAI:serialize() or nil,
        tutorial     = GameUI.TutorialSerialize(),        -- 教程完成进度
        achievements = Achievement.GetUnlocked(),         -- 已解锁成就列表
        playerName    = state.playerName,                 -- P1-1: 玩家昵称
        totalShipsBuilt = state.GP.totalShipsBuilt,       -- 累计造船数（阶段目标用）
        shipTypeBuilt   = state.GP.shipTypeBuilt,         -- 各舰型造船数
        completedGoals  = state.GP.completedGoals,        -- 已完成目标 id 集合（防止重复奖励）
        totalResearch   = state.totalResearch,            -- 累计科技数（成就用）
        -- P1-3: 链式事件状态
        galaxyEvents = GalaxyEvents.Serialize(),
        -- P1-1: 外交系统状态
        diplomacy    = state.ds and state.ds:serialize() or nil,
        -- P1-2: 宿敌系统状态
        nemesis      = NemesisSystem.Serialize(),
        -- P2-1: 星域异象系统状态
        anomaly      = require("game.AnomalySystem").Serialize(),
        -- P3-2: 动态星图天气状态
        weather      = require("game.StarWeather").Serialize(),
        -- P2-2: 黑市走私网络状态
        blackMarket  = state.bm:serialize(),
        -- P2-2 V2.4: 巨构工程状态
        megastructures = MegastructureSystem.Serialize(),
        -- P2-1 V2.5: 自定义阵型槽
        formationSlots = FormationEditor.GetSlots(),
        -- V3.0: 扩展模块统一序列化
        v3modules = ModuleRegistry.SerializeAll(),
    }
    return cjson.encode(saveData)
end

-- ============================================================================
-- SaveGame
-- 将当前游戏状态保存到本地文件
-- state: 同 BuildSaveData
-- ============================================================================
function ClientSave.SaveGame(state)
    if saveInProgress_ then return end
    saveInProgress_ = true
    -- H3: 用 pcall 包裹，任何异常都不会导致 saveInProgress_ 永久锁死
    local ok, err = pcall(function()
        local jsonStr = ClientSave.BuildSaveData(state)
        local file = File("galaxy_save.json", FILE_WRITE)
        if file:IsOpen() then
            file:WriteString(jsonStr)
            file:Close()
        end
    end)
    saveInProgress_ = false   -- 无论成败都清除，防止锁死
    if not ok then
        print("[Save] 存档失败: " .. tostring(err))
    end
end

-- ============================================================================
-- SaveCareer
-- P2-2: 跨局战绩保存（战役胜利时调用）
-- state = { careerStats, evolutionPoints, evolutionUnlocked,
--           challengeStreak, lastChallengeDate }
-- ============================================================================
function ClientSave.SaveCareer(state)
    local ok2, err2 = pcall(function()
        local cFile = File("galaxy_career.json", FILE_WRITE)
        if cFile:IsOpen() then
            local saveData = {}
            for k, v in pairs(state.careerStats) do saveData[k] = v end
            saveData.redeemed = Achievement.GetRedeemed()
            saveData.evolutionPoints = state.evolutionPoints
            local unlockedList = {}
            for nid in pairs(state.evolutionUnlocked) do
                unlockedList[#unlockedList + 1] = nid
            end
            saveData.evolutionUnlocked = unlockedList
            saveData.challengeStreak   = state.challengeStreak
            saveData.lastChallengeDate = state.lastChallengeDate
            -- P2-2: 战役进度
            saveData.campaign = Campaign.GetSaveData()
            -- P1-3 V2.4: 指挥官数据
            saveData.commanders = Commander.Serialize()
            -- P2-1 V2.4: 任务板数据
            saveData.questBoard = QuestBoard.Serialize()
            cFile:WriteString(cjson.encode(saveData))
            cFile:Close()
            print("[Career] 战绩已保存（含战役/指挥官）")
        end
    end)
    if not ok2 then print("[Career] 战绩保存失败: " .. tostring(err2)) end
end

-- ============================================================================
-- RestoreGame
-- 从存档 JSON 字符串恢复游戏状态
-- state = { rm, rs, player, spq, fm, pirateAI, ds, bm, GP,
--           DIFFICULTY_CONFIGS,
--           callbacks = { markBaseEffectsDirty,
--                         applyBaseModuleEffects,
--                         reapplyAllPlanetBonuses } }
-- returns: { difficulty, difficultyChosen, playerName, totalResearch }
--          or nil（新玩家 / 存档损坏时）
-- ============================================================================
function ClientSave.RestoreGame(jsonStr, state)
    if not jsonStr or jsonStr == "" then
        print("[Client] 新玩家，使用初始状态")
        return nil
    end
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or not data then
        print("[Client] 存档解析失败，使用初始状态")
        return nil
    end
    print("[Client] 恢复存档 v" .. (data.version or 0))

    local restored = {}

    -- 恢复难度设置（老存档无此字段则保持 normal）
    if data.difficulty and state.DIFFICULTY_CONFIGS[data.difficulty] then
        restored.difficulty       = data.difficulty
        restored.difficultyChosen = true
        print("[Client] 恢复难度: " .. data.difficulty)
    end

    -- P1-1: 恢复玩家昵称
    if type(data.playerName) == "string" and #data.playerName > 0 then
        restored.playerName = data.playerName
        print("[Client] 恢复昵称: " .. data.playerName)
    end

    -- 先恢复星图（会重建行星 buildings），然后恢复资源（保留存档值）
    GalaxyScene.LoadSaveData({ planets = data.planets, base = data.base }, state.rm)
    state.callbacks.markBaseEffectsDirty()
    state.callbacks.applyBaseModuleEffects()   -- 恢复基地模块对 rates/caps 的效果
    state.rm:deserialize({ resources = data.resources })
    state.rs:deserialize(data.research)
    state.player:deserialize(data.player)

    -- 造船队列恢复（需要行星引用）
    local planetLookup = {}
    for _, p in ipairs(GalaxyScene.GetAllPlanets()) do
        planetLookup[p.id] = p
    end
    state.spq:deserialize(data.shipQueue, function(id) return planetLookup[id] end)
    state.fm:deserialize(data.fleet)

    -- 恢复海盗AI状态
    if state.pirateAI and data.pirate then
        state.pirateAI:deserialize(data.pirate)
    end

    -- 恢复教程完成进度（已完成则不再弹窗）
    if data.tutorial then
        GameUI.TutorialDeserialize(data.tutorial)
    end

    -- 恢复成就已解锁列表
    if data.achievements then
        Achievement.SetUnlocked(data.achievements)
        GameUI.SetAchievements(Achievement.GetAll(), Achievement.GetTotal())
    end

    -- 恢复阶段目标进度（防止重复奖励 / 成就计数归零）
    state.GP.totalShipsBuilt = data.totalShipsBuilt or 0
    restored.totalResearch   = data.totalResearch   or 0
    state.GP.shipTypeBuilt   = type(data.shipTypeBuilt) == "table" and data.shipTypeBuilt or {}
    if type(data.completedGoals) == "table" then
        state.GP.completedGoals = data.completedGoals
    end

    -- P1-3: 恢复链式事件队列
    if data.galaxyEvents then
        GalaxyEvents.Deserialize(data.galaxyEvents)
    end

    -- P1-1: 恢复外交系统状态（需在行星数据恢复后执行，以同步 neutralFaction 字段）
    if state.ds and data.diplomacy then
        state.ds:deserialize(data.diplomacy, GalaxyScene.GetAllPlanets())
        print("[Client] 外交系统已恢复")
    end

    -- P1-2: 恢复宿敌系统状态
    if data.nemesis then
        NemesisSystem.Deserialize(data.nemesis)
        print("[Client] 宿敌系统已恢复")
    end

    -- P2-1: 恢复星域异象系统状态
    if data.anomaly then
        local AnomSys = require("game.AnomalySystem")
        AnomSys.Deserialize(data.anomaly)
        print("[Client] 星域异象系统已恢复")
    end

    -- P3-2: 恢复动态星图天气状态
    if data.weather then
        local SW = require("game.StarWeather")
        SW.Deserialize(data.weather)
        print("[Client] 动态星图天气已恢复")
    end

    -- P2-2: 恢复黑市走私网络状态
    if data.blackMarket then
        state.bm:deserialize(data.blackMarket)
        print("[Client] 黑市走私网络已恢复")
    end

    -- P2-1 V2.4: 恢复任务板状态
    if data.questBoard then
        QuestBoard.Deserialize(data.questBoard)
        print("[Client] 任务板已恢复")
    end

    -- P2-2 V2.4: 恢复巨构工程状态
    if data.megastructures then
        MegastructureSystem.Deserialize(data.megastructures)
        print("[Client] 巨构工程已恢复")
    end
    -- P2-1 V2.5: 恢复自定义阵型槽
    if data.formationSlots then
        FormationEditor.LoadSlots(data.formationSlots)
        print("[Client] 自定义阵型已恢复")
    end
    -- V3.0: 扩展模块统一反序列化
    if data.v3modules then
        ModuleRegistry.DeserializeAll(data.v3modules)
        print("[Client] V3.0 扩展模块已恢复")
    end

    -- H2 修复：读档后重新应用所有殖民行星的类型加成（之前只恢复了基地模块效果）
    state.callbacks.reapplyAllPlanetBonuses()

    -- 同步 UI 状态
    if GalaxyScene.IsDeployed() then
        GameUI.SetDeployed(true)
        local base = GalaxyScene.GetBase()
        if base then GameUI.RefreshPlanetPanel(base) end
    end
    GameUI.RefreshTechPanel()
    GameUI.RefreshResourceBar()
    GameUI.Notify("存档已恢复", "success")

    return restored
end

-- ============================================================================
-- ResetProgress
-- softReset 时调用，清除 saveInProgress_ 锁（防止跨局死锁）
-- ============================================================================
function ClientSave.ResetProgress()
    saveInProgress_ = false
end

return ClientSave
