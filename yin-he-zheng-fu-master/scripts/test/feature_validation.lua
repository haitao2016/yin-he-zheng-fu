-- ============================================================================
-- feature_validation.lua  -- V2.5 新功能验证测试
-- ============================================================================

local M = {}

local results = {}

function M.ValidateAll()
    print("[FeatureValidation] 开始 V2.5 新功能验证...")
    results = {}
    
    local features = {
        { name = "星系生成器", fn = M.TestGalaxyGenerator },
        { name = "变异舰船系统", fn = M.TestMutantShipSystem },
        { name = "文明遗产系统", fn = M.TestLegacySystem },
        { name = "阵型编辑器", fn = M.TestFormationEditor },
        { name = "战役新章节", fn = M.TestNewCampaignChapters },
        { name = "无尽模式", fn = M.TestEndlessMode },
    }
    
    for i, feature in ipairs(features) do
        print(string.format("[FeatureValidation] [%d/%d] 验证: %s", i, #features, feature.name))
        
        local success, err = pcall(feature.fn)
        
        table.insert(results, {
            name = feature.name,
            success = success,
            error = err
        })
    end
    
    M.PrintResults()
end

function M.TestGalaxyGenerator()
    local GalaxyGenerator = require("game.GalaxyGenerator")
    assert(GalaxyGenerator, "GalaxyGenerator 加载失败")
    assert(GalaxyGenerator.GenerateFromSeed, "GenerateFromSeed 方法不存在")
    assert(GalaxyGenerator.GenerateStarSystem, "GenerateStarSystem 方法不存在")
    assert(GalaxyGenerator.GeneratePlanet, "GeneratePlanet 方法不存在")
    
    local testSeed = "ABC123"
    local galaxy = GalaxyGenerator.GenerateFromSeed(testSeed)
    assert(galaxy, "星系生成失败")
    assert(galaxy.starSystems, "星系统列表为空")
    assert(#galaxy.starSystems > 0, "未生成任何星系")
    
    print("  ✓ 星系生成器模块正常")
    print(string.format("  ✓ 生成了 %d 个星系系统", #galaxy.starSystems))
end

function M.TestMutantShipSystem()
    local MutantShipSystem = require("game.MutantShipSystem")
    assert(MutantShipSystem, "MutantShipSystem 加载失败")
    assert(MutantShipSystem.Generate, "Generate 方法不存在")
    assert(MutantShipSystem.GetAll, "GetAll 方法不存在")
    assert(MutantShipSystem.ApplyAffixes, "ApplyAffixes 方法不存在")
    
    local mutant = MutantShipSystem.Generate("FRIGATE", "boss")
    assert(mutant, "变异舰船生成失败")
    assert(mutant.id, "缺少舰船ID")
    assert(mutant.baseType, "缺少基础类型")
    assert(mutant.affixes, "缺少词缀列表")
    
    print("  ✓ 变异舰船系统模块正常")
    print(string.format("  ✓ 生成变异舰船: %s + %d 个词缀", mutant.baseType, #mutant.affixes))
end

function M.TestLegacySystem()
    local LegacySystem = require("game.LegacySystem")
    assert(LegacySystem, "LegacySystem 加载失败")
    assert(LegacySystem.GetBonuses, "GetBonuses 方法不存在")
    assert(LegacySystem.Upgrade, "Upgrade 方法不存在")
    assert(LegacySystem.AwardEndOfGame, "AwardEndOfGame 方法不存在")
    
    local bonuses = LegacySystem.GetBonuses()
    assert(bonuses, "获取遗产加成失败")
    
    print("  ✓ 文明遗产系统模块正常")
end

function M.TestFormationEditor()
    local FormationEditor = require("game.ui.FormationEditor")
    assert(FormationEditor, "FormationEditor 加载失败")
    assert(FormationEditor.Open, "Open 方法不存在")
    assert(FormationEditor.Close, "Close 方法不存在")
    assert(FormationEditor.SaveSlot, "SaveSlot 方法不存在")
    assert(FormationEditor.GetSlots, "GetSlots 方法不存在")
    
    local slots = FormationEditor.GetSlots()
    assert(slots, "获取阵型槽位失败")
    
    print("  ✓ 阵型编辑器模块正常")
end

function M.TestNewCampaignChapters()
    local NewCampaignChapters = require("game.NewCampaignChapters")
    assert(NewCampaignChapters, "NewCampaignChapters 加载失败")
    assert(NewCampaignChapters.chapters, "缺少章节列表")
    
    local chapters = NewCampaignChapters.chapters
    assert(#chapters == 3, string.format("期望 3 个新章节，实际 %d 个", #chapters))
    
    print("  ✓ 战役新章节模块正常")
    for _, chapter in ipairs(chapters) do
        print(string.format("    - %s (%d 关)", chapter.name, #chapter.levels))
    end
end

function M.TestEndlessMode()
    local EndlessPanel = require("game.ui.EndlessPanel")
    assert(EndlessPanel, "EndlessPanel 加载失败")
    assert(EndlessPanel.Render, "Render 方法不存在")
    
    print("  ✓ 无尽模式模块正常")
end

function M.PrintResults()
    print("\n[FeatureValidation] 功能验证结果汇总:")
    print("══════════════════════════════════")
    
    local passed = 0
    local failed = 0
    
    for i, result in ipairs(results) do
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
        print("✓ 所有 V2.5 新功能验证通过！")
    else
        print("✗ 部分功能验证失败，请检查相关模块")
    end
end

function M.GetResults()
    return results
end

return M