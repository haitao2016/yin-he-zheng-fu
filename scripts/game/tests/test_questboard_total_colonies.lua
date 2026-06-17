-- ============================================================================
-- test_questboard_total_colonies.lua
-- 目标：验证 QuestBoard "total_colonies" 任务条件能正确检测已殖民星球数。
-- 回归：原实现依赖不存在的 rm.colonizedCount → 任务永不可完成。
--
-- 运行：在含 Lua 的环境下，在 /workspace/scripts 目录中执行：
--   lua game/tests/test_questboard_total_colonies.lua
-- 所有断言通过后输出 "ALL TESTS PASSED"。
-- ============================================================================

local function assertEq(a, b, msg)
    if a ~= b then
        error(string.format("FAIL: %s (expected %s, got %s)",
            tostring(msg or "assertion"), tostring(b), tostring(a)), 2)
    end
end

-- --- stub: game.GalaxyScene -------------------------------------------------
local fakeGalaxyPlanets = {}
_G.package.loaded["game.GalaxyScene"] = {
    GetColonizedPlanets = function() return fakeGalaxyPlanets end,
}

-- --- 静默加载 QuestBoard 所需的兄弟模块（仅需提供 table）-------------------
for _, mod in ipairs({
    "game.AchievementSystem",
    "game.AudioManager",
    "game.BattleScene",
    "game.CampaignSystem",
    "game.CommanderSystem",
    "game.GameConstants",
    "game.GameUI",
    "game.GalaxyEvents",
    "game.GalaxyGenerator",
    "game.GalaxyScene",
    "game.MegastructureSystem",
    "game.MutantShipSystem",
    "game.NemesisSystem",
    "game.PirateAI",
    "game.QuestBoard",
    "game.StarWeather",
    "game.Systems",
    "game.systems.ResourceManager",
    "game.systems.DiplomacySystem",
    "game.systems.FleetManager",
    "game.systems.PlayerProfile",
    "game.ui.AchievementPanel",
    "game.ui.FleetPanel",
    "game.ui.GalaxyPanels",
    "game.ui.NotifyPanel",
    "game.ui.Overlays",
    "game.ui.SettingsPanel",
    "game.ui.TechPanel",
    "game.ui.TimeoutPanel",
    "game.ui.TopBar",
    "game.ui.TutorialSystem",
    "game.ui.UICommon",
    "game.galaxy.RenderStarmap",
    "game.galaxy.RenderFleets",
    "game.galaxy.GalaxyState",
    "game.battle.RenderHUD",
    "game.battle.RenderEntities",
    "network.Client",
    "network.ClientBattle",
    "network.ClientGalaxy",
    "network.ClientSave",
    "network.ClientSetup",
}) do
    if not _G.package.loaded[mod] then
        _G.package.loaded[mod] = {}
    end
end

-- --- 被测模块 ---------------------------------------------------------------
local QuestBoard = require("game.QuestBoard")

-- --- 辅助：通过 Deserialize 间接注入任务 -----------------------------------
local function injectQuest(quest)
    QuestBoard.Deserialize({
        quests = { quest },
        nextId = quest.id + 1,
        spawnTimer = 9999,
        stats = {},
    })
end

-- --- 用例 -------------------------------------------------------------------
local testsRun = 0

-- 1) rm.colonizedCount 不存在：旧实现恒为 0，任务永不完成。
--    新实现应读取 GalaxyScene.GetColonizedPlanets()。
do
    QuestBoard.Reset()
    fakeGalaxyPlanets = {}
    local q = { id = 1, cond = "total_colonies", target = 3, progress = 0, timer = 999 }
    injectQuest(q)
    local rm = { resources = { metal = 0, esource = 0 } }  -- rm.colonizedCount == nil
    local completed = QuestBoard.Update(1, rm, nil, nil)
    assertEq(completed, nil, "无殖民星球时 total_colonies 不应完成")
    testsRun = testsRun + 1
end

-- 2) 殖民数达到目标：任务应完成。
do
    QuestBoard.Reset()
    local q = { id = 2, cond = "total_colonies", target = 3, progress = 0, timer = 999 }
    injectQuest(q)
    fakeGalaxyPlanets = { { name = "A" }, { name = "B" }, { name = "C" } }
    local rm = { resources = { metal = 0, esource = 0 } }
    local completed = QuestBoard.Update(1, rm, nil, nil)
    assertEq(completed and completed.cond, "total_colonies",
        "殖民 3 颗星球后 total_colonies 应完成")
    testsRun = testsRun + 1
end

-- 3) 殖民数 < 目标：不应完成。
do
    QuestBoard.Reset()
    local q = { id = 3, cond = "total_colonies", target = 5, progress = 0, timer = 999 }
    injectQuest(q)
    fakeGalaxyPlanets = { {}, {}, {} }
    local rm = { resources = {} }
    local completed = QuestBoard.Update(1, rm, nil, nil)
    assertEq(completed, nil, "殖民数 < 目标时不应完成")
    testsRun = testsRun + 1
end

-- 4) 其他任务类型（have_metal）作为参考：确保修复没有破坏其他条件。
do
    QuestBoard.Reset()
    local q = { id = 4, cond = "have_metal", target = 500, progress = 0, timer = 999 }
    injectQuest(q)
    local rm = { resources = { metal = 500, esource = 0 } }
    local completed = QuestBoard.Update(1, rm, nil, nil)
    assertEq(completed and completed.cond, "have_metal", "have_metal 条件应继续正常工作")
    testsRun = testsRun + 1
end

print(string.format("ALL %d TESTS PASSED", testsRun))
