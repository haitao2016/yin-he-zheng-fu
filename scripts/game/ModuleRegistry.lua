-- ============================================================================
-- game/ModuleRegistry.lua — V3.0 扩展模块统一注册与生命周期管理
-- 所有从 Trae 分支提取的独立子系统在此注册，通过标准钩子接入主线。
-- ============================================================================
local ModuleRegistry = {}

-- 已注册模块列表
local modules_ = {}

-- 注册格式: { name, module, hasInit, hasUpdate, hasSerialize, hasRender }
local function reg(name, path, opts)
    opts = opts or {}
    local ok, mod = pcall(require, path)
    if not ok then
        print(string.format("[ModuleRegistry] ⚠️ 加载失败: %s (%s)", name, tostring(mod)))
        return
    end
    modules_[#modules_ + 1] = {
        name        = name,
        mod         = mod,
        hasInit     = type(mod.init or mod.Init) == "function",
        hasUpdate   = type(mod.update or mod.Update) == "function",
        hasSerialize = type(mod.serialize or mod.Serialize) == "function",
        hasDeserialize = type(mod.deserialize or mod.Deserialize) == "function",
        hasRender   = type(mod.render or mod.Render) == "function",
        category    = opts.category or "misc",
    }
    print(string.format("[ModuleRegistry] ✅ %s", name))
end

-- ============================================================================
-- 注册所有 V3.0 扩展模块
-- ============================================================================
function ModuleRegistry.RegisterAll()
    print("[ModuleRegistry] === 开始注册 V3.0 扩展模块 ===")

    -- 基础设施
    reg("I18n",              "game.i18n.I18nSystem",           { category = "infra" })
    reg("Accessibility",     "game.systems.AccessibilitySystem", { category = "infra" })
    reg("SaveSlot",          "game.systems.SaveSlotSystem",    { category = "infra" })
    reg("GamepadSupport",    "game.ui.GamepadSupport",         { category = "infra" })
    reg("TutorialV3",        "game.systems.TutorialV3System",  { category = "infra" })

    -- 常量模块（纯数据，无生命周期）
    reg("ShipConstants",     "game.constants.ShipConstants",       { category = "data" })
    reg("TechConstants",     "game.constants.TechConstants",       { category = "data" })
    reg("BuildingConstants", "game.constants.BuildingConstants",   { category = "data" })
    reg("CampaignConstants", "game.constants.CampaignConstants",   { category = "data" })
    reg("CommanderConstants", "game.constants.CommanderConstants", { category = "data" })
    reg("AchievementConstants", "game.constants.AchievementConstants", { category = "data" })
    reg("GalaxyEventConstants", "game.constants.GalaxyEventConstants", { category = "data" })
    reg("GuildConstants",    "game.constants.GuildConstants",      { category = "data" })
    reg("SeasonConstants",   "game.constants.SeasonConstants",     { category = "data" })

    -- AI 与难度
    reg("AIDifficulty",      "game.systems.AIDifficultySystem",   { category = "gameplay" })

    -- 战斗扩展
    reg("BattleEnvironment", "game.battle.BattleEnvironment",     { category = "battle" })
    reg("BattleCommand",     "game.systems.BattleCommandSystem",  { category = "battle" })
    reg("SynergyAttack",     "game.systems.SynergyAttackSystem",  { category = "battle" })
    reg("BattleStatsTracker","game.systems.BattleStatsTracker",   { category = "battle" })
    reg("RoguelikeCard",     "game.systems.RoguelikeCardSystem",  { category = "battle" })

    -- 舰船深度
    reg("ShipSpecialization","game.systems.ShipSpecializationSystem", { category = "ship" })
    reg("ShipStar",          "game.systems.ShipStarSystem",       { category = "ship" })
    reg("ShipSkin",          "game.systems.ShipSkinSystem",       { category = "ship" })
    reg("ShipEnhancement",   "game.systems.ShipEnhancementSystem",{ category = "ship" })
    reg("Flagship",          "game.systems.FlagshipSystem",       { category = "ship" })
    reg("NewShipTypes",      "game.NewShipTypes",                 { category = "ship" })

    -- 经济
    reg("Investment",        "game.systems.InvestmentSystem",     { category = "economy" })
    reg("Merchant",          "game.systems.MerchantSystem",       { category = "economy" })
    reg("Trade",             "game.systems.TradeSystem",          { category = "economy" })

    -- 内容 & 进度
    reg("CampaignV3",        "game.systems.CampaignSystem",      { category = "content" })
    reg("NewCampaignChapters","game.NewCampaignChapters",         { category = "content" })
    reg("Challenge",         "game.systems.ChallengeSystem",      { category = "content" })
    reg("CharacterStory",    "game.systems.CharacterStorySystem", { category = "content" })
    reg("HiddenAchievement", "game.systems.HiddenAchievementSystem", { category = "content" })
    reg("AchievementChain",  "game.systems.AchievementChainSystem",  { category = "content" })
    reg("GalaxyEventV3",     "game.systems.GalaxyEventSystem",    { category = "content" })
    reg("StarMapVariant",    "game.systems.StarMapVariantSystem",  { category = "content" })

    -- 社交
    reg("Guild",             "game.systems.GuildSystem",          { category = "social" })
    reg("Friend",            "game.systems.FriendSystem",         { category = "social" })
    reg("Spectator",         "game.systems.SpectatorSystem",      { category = "social" })
    reg("Leaderboard",       "game.systems.LeaderboardSystem",    { category = "social" })

    -- 赛季
    reg("Season",            "game.systems.SeasonSystem",         { category = "season" })
    reg("SeasonExpansion",   "game.systems.SeasonExpansionSystem",{ category = "season" })

    -- 养成/成长
    reg("PlayerStats",       "game.systems.PlayerStatsSystem",    { category = "progress" })
    reg("Formation",         "game.systems.FormationSystem",      { category = "progress" })
    reg("CommanderV3",       "game.systems.CommanderSystem",      { category = "progress" })

    -- 平台集成
    reg("Steam",             "game.systems.SteamIntegration",     { category = "platform" })

    -- 新成就系统（V3 版本，与 game.AchievementSystem 共存）
    reg("AchievementV3",     "game.systems.AchievementSystem",   { category = "progress" })

    -- UI 面板（按需渲染，不需要 Init/Update）
    reg("GuildPanel",        "game.ui.GuildPanel",               { category = "ui" })
    reg("FriendPanel",       "game.ui.FriendPanel",              { category = "ui" })
    reg("CampaignPanel",     "game.ui.CampaignPanel",            { category = "ui" })
    reg("CommanderPanel",    "game.ui.CommanderPanel",            { category = "ui" })
    reg("SeasonShopPanel",   "game.ui.SeasonShopPanel",          { category = "ui" })
    reg("CareerStatsPanel",  "game.ui.CareerStatsPanel",         { category = "ui" })
    reg("ChallengePanel",    "game.ui.ChallengePanel",           { category = "ui" })
    reg("ChallengeShopPanel","game.ui.ChallengeShopPanel",       { category = "ui" })
    reg("BossRushPanel",     "game.ui.BossRushPanel",            { category = "ui" })
    reg("EndlessPanel",      "game.ui.EndlessPanel",             { category = "ui" })
    reg("FormationPanel",    "game.ui.FormationPanel",           { category = "ui" })
    reg("LeaderboardPanel",  "game.ui.LeaderboardPanel",         { category = "ui" })
    reg("MarketPanel",       "game.ui.MarketPanel",              { category = "ui" })
    reg("ShipDetailPanel",   "game.ui.ShipDetailPanel",          { category = "ui" })

    print(string.format("[ModuleRegistry] === 注册完成: %d 个模块 ===", #modules_))
end

-- ============================================================================
-- 生命周期钩子
-- ============================================================================

--- 初始化所有模块（在游戏开局时调用一次）
---@param state table  共享状态引用
function ModuleRegistry.InitAll(state)
    for _, entry in ipairs(modules_) do
        if entry.hasInit then
            local initFn = entry.mod.init or entry.mod.Init
            local ok, err = pcall(initFn, state)
            if not ok then
                print(string.format("[ModuleRegistry] ❌ Init 失败: %s — %s", entry.name, tostring(err)))
            end
        end
    end
end

--- 每帧更新（在主 Update 末尾调用）
---@param dt number
---@param state table
function ModuleRegistry.UpdateAll(dt, state)
    for _, entry in ipairs(modules_) do
        if entry.hasUpdate then
            local updateFn = entry.mod.update or entry.mod.Update
            local ok, err = pcall(updateFn, dt, state)
            if not ok then
                print(string.format("[ModuleRegistry] ❌ Update 失败: %s — %s", entry.name, tostring(err)))
                entry.hasUpdate = false  -- 禁用该模块的 Update 避免每帧报错
            end
        end
    end
end

--- 序列化所有模块状态（存档时调用）
---@return table  { moduleName = serializedData, ... }
function ModuleRegistry.SerializeAll()
    local result = {}
    for _, entry in ipairs(modules_) do
        if entry.hasSerialize then
            local serFn = entry.mod.serialize or entry.mod.Serialize
            local ok, data = pcall(serFn)
            if ok and data ~= nil then
                result[entry.name] = data
            end
        end
    end
    return result
end

--- 反序列化所有模块状态（读档时调用）
---@param allData table  { moduleName = serializedData, ... }
function ModuleRegistry.DeserializeAll(allData)
    if not allData then return end
    for _, entry in ipairs(modules_) do
        if entry.hasDeserialize and allData[entry.name] then
            local desFn = entry.mod.deserialize or entry.mod.Deserialize
            local ok, err = pcall(desFn, allData[entry.name])
            if not ok then
                print(string.format("[ModuleRegistry] ❌ Deserialize 失败: %s — %s", entry.name, tostring(err)))
            end
        end
    end
end

--- 获取指定模块的引用（供其他系统按需访问）
---@param name string
---@return table|nil
function ModuleRegistry.Get(name)
    for _, entry in ipairs(modules_) do
        if entry.name == name then return entry.mod end
    end
    return nil
end

--- 获取所有已注册模块列表
function ModuleRegistry.GetAll()
    return modules_
end

--- 获取指定分类的模块
function ModuleRegistry.GetByCategory(category)
    local result = {}
    for _, entry in ipairs(modules_) do
        if entry.category == category then
            result[#result + 1] = entry
        end
    end
    return result
end

return ModuleRegistry
