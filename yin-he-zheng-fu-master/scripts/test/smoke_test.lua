-- ============================================================================
-- smoke_test.lua  -- 冒烟测试脚本
-- ============================================================================

local M = {}

local testResults = {}
local currentTest = nil

function M.Start()
    print("[SmokeTest] 开始冒烟测试...")
    testResults = {}
    currentTest = 1
    
    M.RunNextTest()
end

function M.RunNextTest()
    local tests = {
        { name = "开局展开基地", fn = M.TestDeploy },
        { name = "点击星球", fn = M.TestPlanetClick },
        { name = "点击编队", fn = M.TestFleetClick },
        { name = "殖民行星", fn = M.TestColonize },
        { name = "建造建筑", fn = M.TestBuild },
        { name = "研究科技", fn = M.TestResearch },
        { name = "派队作战", fn = M.TestBattle },
        { name = "战斗结算", fn = M.TestBattleResult },
        { name = "再来一局", fn = M.TestRestart },
        { name = "存读档", fn = M.TestSaveLoad },
        { name = "战役模式", fn = M.TestCampaign },
        { name = "文明遗产", fn = M.TestLegacy },
    }
    
    if currentTest > #tests then
        M.PrintResults()
        return
    end
    
    local test = tests[currentTest]
    print(string.format("[SmokeTest] [%d/%d] 测试: %s", currentTest, #tests, test.name))
    
    local success, err = pcall(test.fn)
    
    table.insert(testResults, {
        name = test.name,
        success = success,
        error = err
    })
    
    currentTest = currentTest + 1
    M.RunNextTest()
end

function M.TestDeploy()
    local GalaxyScene = require("game.GalaxyScene")
    assert(GalaxyScene, "GalaxyScene 加载失败")
    assert(GalaxyScene.GetBase, "GetBase 方法不存在")
    assert(GalaxyScene.IsDeployed, "IsDeployed 方法不存在")
    print("  ✓ GalaxyScene 模块正常")
end

function M.TestPlanetClick()
    local GameUI = require("game.GameUI")
    assert(GameUI, "GameUI 加载失败")
    assert(GameUI.RefreshPlanetPanel, "RefreshPlanetPanel 方法不存在")
    print("  ✓ GameUI.RefreshPlanetPanel 存在")
end

function M.TestFleetClick()
    local GameUI = require("game.GameUI")
    assert(GameUI.RefreshFleetPanel, "RefreshFleetPanel 方法不存在")
    assert(GameUI.SetMapSelectedFleet, "SetMapSelectedFleet 方法不存在")
    print("  ✓ GameUI 编队相关方法存在")
end

function M.TestColonize()
    local ClientGalaxy = require("network.ClientGalaxy")
    assert(ClientGalaxy.DoColonize, "DoColonize 方法不存在")
    print("  ✓ ClientGalaxy.DoColonize 存在")
end

function M.TestBuild()
    local BuildingSystem = require("game.systems.BuildingSystem")
    assert(BuildingSystem, "BuildingSystem 加载失败")
    print("  ✓ BuildingSystem 模块正常")
end

function M.TestResearch()
    local ResearchSystem = require("game.systems.ResearchSystem")
    assert(ResearchSystem, "ResearchSystem 加载失败")
    assert(ResearchSystem.CanResearch, "CanResearch 方法不存在")
    print("  ✓ ResearchSystem 模块正常")
end

function M.TestBattle()
    local ClientBattle = require("network.ClientBattle")
    assert(ClientBattle.OnFleetSiegeBase, "OnFleetSiegeBase 方法不存在")
    print("  ✓ ClientBattle.OnFleetSiegeBase 存在")
end

function M.TestBattleResult()
    local GameUI = require("game.GameUI")
    assert(GameUI.ShowEndGame, "ShowEndGame 方法不存在")
    print("  ✓ GameUI.ShowEndGame 存在")
end

function M.TestRestart()
    local GalaxyScene = require("game.GalaxyScene")
    assert(GalaxyScene.Reset, "Reset 方法不存在")
    print("  ✓ GalaxyScene.Reset 存在")
end

function M.TestSaveLoad()
    local ClientSave = require("network.ClientSave")
    assert(ClientSave.SaveGame, "SaveGame 方法不存在")
    assert(ClientSave.LoadGame, "LoadGame 方法不存在")
    print("  ✓ ClientSave 模块正常")
end

function M.TestCampaign()
    local CampaignSystem = require("game.CampaignSystem")
    assert(CampaignSystem.CompleteLevel, "CompleteLevel 方法不存在")
    print("  ✓ CampaignSystem.CompleteLevel 存在")
end

function M.TestLegacy()
    local LegacySystem = require("game.LegacySystem")
    assert(LegacySystem.AwardEndOfGame, "AwardEndOfGame 方法不存在")
    print("  ✓ LegacySystem.AwardEndOfGame 存在")
end

function M.PrintResults()
    print("\n[SmokeTest] 测试结果汇总:")
    print("══════════════════════════════════")
    
    local passed = 0
    local failed = 0
    
    for i, result in ipairs(testResults) do
        local status = result.success and "✓ PASS" or "✗ FAIL"
        print(string.format("  %d. %s - %s", i, result.name, status))
        
        if not result.success then
            print(string.format("     错误: %s", result.error))
            failed = failed + 1
        else
            passed = passed + 1
        end
    end
    
    print("\n" .. string.format("通过: %d / 失败: %d", passed, failed))
    
    if failed == 0 then
        print("✓ 所有测试通过！")
    else
        print("✗ 部分测试失败，请检查相关模块")
    end
end

function M.GetResults()
    return testResults
end

return M